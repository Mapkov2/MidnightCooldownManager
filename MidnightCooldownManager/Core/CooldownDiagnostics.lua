local AddonName = "MidnightCooldownManager"
local CDM = _G[AddonName]

local function PrintLine(label, value)
    CDM.Print(label .. ": " .. tostring(value))
end

local function PrintSmokeLine(status, label, value)
    CDM.Print("smoke " .. status .. " " .. label .. ": " .. tostring(value))
end

local function PrintPerfLine(label, value)
    CDM.Print("perf " .. label .. ": " .. tostring(value))
end

local function CountKeys(t)
    if type(t) ~= "table" then return 0 end
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

local function GetScriptProfileValue()
    if not GetCVar then return nil end
    local ok, value = pcall(GetCVar, "scriptProfile")
    if ok then return value end
    return nil
end

local function ReadAddonCPUUsage()
    if not (UpdateAddOnCPUUsage and GetAddOnCPUUsage) then
        return nil, "api_missing"
    end

    pcall(UpdateAddOnCPUUsage)

    local ok, value = pcall(GetAddOnCPUUsage, AddonName)
    if not ok then
        return nil, value or "read_failed"
    end
    return value, nil
end

local lastPerfSnapshot = nil

local function NumberDelta(current, previous)
    if type(current) ~= "number" or type(previous) ~= "number" then
        return "n/a"
    end
    return current - previous
end

local function RatePerSecond(delta, seconds)
    if type(delta) ~= "number" or type(seconds) ~= "number" or seconds <= 0 then
        return "n/a"
    end
    return string.format("%.3f/s", delta / seconds)
end

local function BuildPerfSnapshot(cpu, compat, resources)
    return {
        time = GetTime and GetTime() or nil,
        cpu = type(cpu) == "number" and cpu or nil,
        resourceUpdates = resources.updateCount,
        resourceFullRefreshes = resources.fullRefreshes,
        maxPowerFastUpdates = resources.maxPowerFastUpdates,
        maxPowerLayoutRefreshes = resources.maxPowerLayoutRefreshes,
        classLoadSkips = resources.classLoadSkips,
        powerLoadSkips = resources.powerLoadSkips,
        hpLoadSkips = resources.hpLoadSkips,
        powerPercentReads = resources.powerPercentReads,
        healthPercentReads = resources.healthPercentReads,
        compatHits = compat.hits,
        compatMisses = compat.misses,
        compatApiCalls = compat.apiCalls,
        compatApiErrors = compat.apiErrors,
    }
end

local function SmokeCheck(result, condition, label, passValue, failValue, warnOnly)
    if condition then
        PrintSmokeLine("PASS", label, passValue or "ok")
        return
    end

    if warnOnly then
        result.warnings = result.warnings + 1
        PrintSmokeLine("WARN", label, failValue or "check")
    else
        result.failures = result.failures + 1
        PrintSmokeLine("FAIL", label, failValue or "failed")
    end
end

local function IsInterface120000(value)
    return tostring(value or "") == "120000"
end

local function NormalizeInterfaceVersion(value)
    if value == nil then return nil end
    local text = tostring(value)
    if text == "" then return nil end
    return text
end

local function GetAddonMetadataValue(field)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local ok, value = pcall(C_AddOns.GetAddOnMetadata, AddonName, field)
        if ok then return value end
    end
    if GetAddOnMetadata then
        local ok, value = pcall(GetAddOnMetadata, AddonName, field)
        if ok then return value end
    end
    return nil
end

local function GetAddonInterfaceVersionValue()
    if C_AddOns and C_AddOns.GetAddOnInterfaceVersion then
        local ok, value = pcall(C_AddOns.GetAddOnInterfaceVersion, AddonName)
        value = NormalizeInterfaceVersion(value)
        if ok and value then
            return value, "C_AddOns.GetAddOnInterfaceVersion"
        end
    end

    local value = NormalizeInterfaceVersion(GetAddonMetadataValue("Interface"))
    if value then
        return value, "metadata"
    end

    return nil, "unavailable"
end

local function FormatIndexEntry(entry)
    if not entry then
        return "no entry"
    end

    local categoryName = CDM.GetCooldownViewerCategoryName and CDM:GetCooldownViewerCategoryName(entry.category) or tostring(entry.category or "nil")
    local sourceCategoryName = CDM.GetCooldownViewerCategoryName and CDM:GetCooldownViewerCategoryName(entry.sourceCategory) or tostring(entry.sourceCategory or "nil")
    return string.format(
        "cdID=%s spell=%s display=%s override=%s tooltip=%s spellCat=%s equip=%s spellBacked=%s itemBacked=%s cat=%s sourceCat=%s invis=%s",
        tostring(entry.cooldownID or "nil"),
        tostring(entry.spellID or "nil"),
        tostring(entry.displaySpellID or "nil"),
        tostring(entry.overrideSpellID or "nil"),
        tostring(entry.overrideTooltipSpellID or "nil"),
        tostring(entry.spellCategoryID or "nil"),
        tostring(entry.equipSlot or "nil"),
        entry.isSpellBacked and "yes" or "no",
        entry.isItemBacked and "yes" or "no",
        categoryName,
        sourceCategoryName,
        entry.isInvisible and "yes" or "no"
    )
end

local function FormatRecord(record)
    if not record then
        return "no record"
    end

    return string.format(
        "cdID=%s spell=%s base=%s item=%s spellCat=%s equip=%s display=%s spellBacked=%s itemBacked=%s source=%s cat=%s gen=%s custom=%s invis=%s",
        tostring(record.cooldownID or "nil"),
        tostring(record.spellID or "nil"),
        tostring(record.baseSpellID or "nil"),
        tostring(record.itemID or "nil"),
        tostring(record.spellCategoryID or "nil"),
        tostring(record.equipSlot or "nil"),
        tostring(record.displaySpellID or "nil"),
        record.isSpellBacked and "yes" or "no",
        record.isItemBacked and "yes" or "no",
        tostring(record.source or "nil"),
        tostring(record.category or "nil"),
        tostring(record.cacheGeneration or "nil"),
        record.rawCustom and "yes" or "no",
        record.isInvisible and "yes" or "no"
    )
end

function CDM:RunCooldownSmokeDiagnostic()
    local result = { failures = 0, warnings = 0 }
    local diag = self:GetCooldownDiagnostics()
    local compat = diag.compat or {}
    local index = diag.index or {}
    local record = diag.record or {}
    local resources = diag.resources or {}
    local wowVersion, wowBuild, wowDate, wowInterface = GetBuildInfo()
    local addonVersion = GetAddonMetadataValue("Version") or "unknown"
    local tocInterface, tocInterfaceSource = GetAddonInterfaceVersionValue()
    tocInterface = tocInterface or "unknown"

    CDM.Print("Cooldown PTR smoke diagnostic")
    PrintSmokeLine("INFO", "addonVersion", addonVersion)
    PrintSmokeLine("INFO", "tocInterface", tocInterface)
    PrintSmokeLine("INFO", "tocInterfaceSource", tocInterfaceSource or "unknown")
    PrintSmokeLine("INFO", "wowVersion", tostring(wowVersion or "unknown") .. " build=" .. tostring(wowBuild or "unknown") .. " date=" .. tostring(wowDate or "unknown"))
    PrintSmokeLine("INFO", "wowInterface", wowInterface or "unknown")
    PrintSmokeLine("INFO", "specID", diag.specID or "none")
    SmokeCheck(result, IsInterface120000(tocInterface), "tocInterface120000", tocInterface, tocInterface)
    SmokeCheck(result, diag.dataReady == true, "dataReady", "true", "false")
    SmokeCheck(result, compat.hasCooldownInfoAPI == true, "cooldownInfoAPI", "available", "missing")
    SmokeCheck(result, compat.hasCategorySetAPI == true, "categorySetAPI", "available", "missing")
    SmokeCheck(result, compat.hasGroupBuffItemsAPI == true, "groupBuffItemsAPI", "available", "missing", true)
    SmokeCheck(result, (compat.apiErrors or 0) == 0, "compatApiErrors", "0", compat.apiErrors or 0)
    SmokeCheck(result, (index.totalCooldowns or 0) > 0, "indexCooldowns", index.totalCooldowns or 0, "0")
    SmokeCheck(result, index.compatGeneration == compat.generation, "indexGeneration", index.compatGeneration or "nil", "compat=" .. tostring(compat.generation or "nil") .. " index=" .. tostring(index.compatGeneration or "nil"), true)
    SmokeCheck(result, type(self.GetFrameCooldownRecord) == "function" and record.generation ~= nil, "recordLayer", "generation=" .. tostring(record.generation), "missing")
    SmokeCheck(result, type(self.GetCooldownViewerFrame) == "function", "viewerFrameCompat", "available", "missing")
    SmokeCheck(result, type(self.ForEachActiveFrame) == "function", "activeFrameIterator", "available", "missing")
    SmokeCheck(result, type(self.InstallCooldownViewerAcquireCallback) == "function", "acquireHookCompat", "available", "missing")
    SmokeCheck(result, type(self.InstallCooldownItemLifecycleCallbacks) == "function", "itemLifecycleCompat", "available", "missing")
    SmokeCheck(result, type(self.RegisterCooldownViewerSettingsCallback) == "function", "settingsEventCompat", "available", "missing")
    SmokeCheck(result, type(self.GetResourceDiagnostics) == "function", "resourceRuntime", "available", "missing")
    if type(self.GetResourceDiagnostics) == "function" then
        SmokeCheck(result, resources.initialized == true, "resourceInitialized", "true", "false")
        SmokeCheck(result, resources.hasPowerBar == true, "resourcePowerBar", "available", "missing")
        SmokeCheck(result, resources.hpBarDefaultEnabled == false, "resourceHPDefaultOff", "true", "false")
        PrintSmokeLine("INFO", "resources", "mode=" .. tostring(resources.mode or "none") ..
            " token=" .. tostring(resources.powerToken or "none") ..
            " max=" .. tostring(resources.maxPower or 0) ..
            " class=" .. tostring(resources.classEnabled))
        PrintSmokeLine("INFO", "playerPower", "enabled=" .. tostring(resources.powerBarEnabled) ..
            " shown=" .. tostring(resources.powerBarShown) ..
            " type=" .. tostring(resources.playerPowerType or "nil") ..
            " token=" .. tostring(resources.playerPowerToken or "nil") ..
            " maxReady=" .. tostring(resources.playerPowerMaxReady) ..
            " maxSecret=" .. tostring(resources.playerPowerMaxSecret) ..
            " text=" .. tostring(resources.playerPowerTextMode or "nil") ..
            " smoothConfig=" .. tostring(resources.playerPowerSmoothConfig) ..
            " smooth=" .. tostring(resources.playerPowerSmooth) ..
            " smoothAPI=" .. tostring(resources.playerPowerSmoothAPI) ..
            " pctMode=" .. tostring(resources.playerPowerPercentMode or "nil"))
        PrintSmokeLine("INFO", "resourceHPPercent", "pctMode=" .. tostring(resources.playerHealthPercentMode or "nil"))
        PrintSmokeLine("INFO", "resourceLoadNeeds", "combat=" .. tostring(resources.loadNeedCombat) ..
            " target=" .. tostring(resources.loadNeedTarget) ..
            " group=" .. tostring(resources.loadNeedGroup) ..
            " instance=" .. tostring(resources.loadNeedInstance) ..
            " resting=" .. tostring(resources.loadNeedResting) ..
            " aura=" .. tostring(resources.loadNeedAura) ..
            " mount=" .. tostring(resources.loadNeedMount) ..
            " vehicle=" .. tostring(resources.loadNeedVehicle))
        PrintSmokeLine("INFO", "resourceEvents", "bound=" .. tostring(resources.boundRuntimeEvents or "nil") ..
            " frequentPower=" .. tostring(resources.unitPowerFrequentBound) ..
            " unitAura=" .. tostring(resources.unitAuraBound) ..
            " displayPower=" .. tostring(resources.displayPowerEventBound) ..
            " spec=" .. tostring(resources.specEventBound) ..
            " shapeshift=" .. tostring(resources.shapeshiftEventBound) ..
            " mount=" .. tostring(resources.mountEventBound) ..
            " vehicle=" .. tostring(resources.vehicleEventBound))
        PrintSmokeLine("INFO", "resourceEventList", resources.boundRuntimeEventList or "none")

        local expectedFrequentPower = resources.powerBarEnabled == true and resources.playerPowerSmoothConfig == true
        SmokeCheck(result, resources.unitPowerFrequentBound == expectedFrequentPower, "resourceFrequentPowerBinding",
            tostring(resources.unitPowerFrequentBound), "bound=" .. tostring(resources.unitPowerFrequentBound) .. " expected=" .. tostring(expectedFrequentPower), true)
        local expectedAura = resources.resourceAuraMode == true or resources.loadNeedAura == true
        SmokeCheck(result, resources.unitAuraBound == expectedAura, "resourceAuraBinding",
            tostring(resources.unitAuraBound), "bound=" .. tostring(resources.unitAuraBound) .. " expected=" .. tostring(expectedAura), true)
        local expectedDisplayPower = resources.classEnabled == true or resources.powerBarEnabled == true
        SmokeCheck(result, resources.displayPowerEventBound == expectedDisplayPower, "resourceDisplayPowerBinding",
            tostring(resources.displayPowerEventBound), "bound=" .. tostring(resources.displayPowerEventBound) .. " expected=" .. tostring(expectedDisplayPower), true)
        SmokeCheck(result, resources.specEventBound == (resources.classEnabled == true), "resourceSpecBinding",
            tostring(resources.specEventBound), "bound=" .. tostring(resources.specEventBound) .. " expected=" .. tostring(resources.classEnabled == true), true)
        SmokeCheck(result, resources.shapeshiftEventBound == (resources.classEnabled == true), "resourceShapeshiftBinding",
            tostring(resources.shapeshiftEventBound), "bound=" .. tostring(resources.shapeshiftEventBound) .. " expected=" .. tostring(resources.classEnabled == true), true)
        SmokeCheck(result, resources.vehicleEventBound == (resources.loadNeedVehicle == true), "resourceVehicleBinding",
            tostring(resources.vehicleEventBound), "bound=" .. tostring(resources.vehicleEventBound) .. " expected=" .. tostring(resources.loadNeedVehicle == true), true)
    end

    local viewers = self.CONST and self.CONST.ALL_VIEWER_NAMES or {}
    local viewerCount = 0
    local activeTotal = 0
    local recordTotal = 0

    for _, viewerName in ipairs(viewers) do
        viewerCount = viewerCount + 1
        local viewer = self:GetCooldownViewerFrame(viewerName)
        SmokeCheck(result, viewer ~= nil, "viewer:" .. viewerName, "found", "missing")

        local active = 0
        local withRecord = 0
        if viewer and self.ForEachActiveFrame then
            self:ForEachActiveFrame({ viewerName }, function(frame)
                active = active + 1
                if self.GetFrameCooldownRecord and self:GetFrameCooldownRecord(frame) then
                    withRecord = withRecord + 1
                end
            end)
        end
        activeTotal = activeTotal + active
        recordTotal = recordTotal + withRecord
        PrintSmokeLine("INFO", "viewerFrames:" .. viewerName, "active=" .. active .. " records=" .. withRecord)
    end

    SmokeCheck(result, viewerCount > 0, "viewerCatalog", viewerCount, "0")
    SmokeCheck(result, activeTotal > 0, "activeViewerFrames", activeTotal, "0", true)
    SmokeCheck(result, activeTotal == 0 or recordTotal > 0, "activeFrameRecords", recordTotal, "0")
    PrintSmokeLine("INFO", "groups", "buff=" .. CountKeys(self.BuffGroupSets and self.BuffGroupSets.grouped) ..
        " bar=" .. CountKeys(self.BarGroupSets and self.BarGroupSets.grouped) ..
        " cooldown=" .. CountKeys(self.CooldownGroupSets and self.CooldownGroupSets.grouped))

    local status = result.failures == 0 and "PASS" or "FAIL"
    PrintSmokeLine(status, "summary", "failures=" .. result.failures .. " warnings=" .. result.warnings)
    return result.failures == 0, result
end

function CDM:RunCooldownPerfDiagnostic(mode)
    mode = type(mode) == "string" and mode:lower() or nil
    if mode == "reset" or mode == "clear" then
        lastPerfSnapshot = nil
        CDM.Print("Cooldown performance diagnostic baseline reset")
        return
    end

    local diag = self:GetCooldownDiagnostics()
    local compat = diag.compat or {}
    local index = diag.index or {}
    local resources = diag.resources or {}
    local cpu, cpuError = ReadAddonCPUUsage()
    local scriptProfile = GetScriptProfileValue()
    local snapshot = BuildPerfSnapshot(cpu, compat, resources)
    local previous = lastPerfSnapshot

    CDM.Print("Cooldown performance diagnostic")
    PrintPerfLine("scriptProfile", scriptProfile or "unknown")
    if cpu ~= nil then
        PrintPerfLine("addonCPU", cpu)
    else
        PrintPerfLine("addonCPU", cpuError or "unavailable")
    end
    PrintPerfLine("resourcesInitialized", resources.initialized == true)
    PrintPerfLine("resourceMode", tostring(resources.mode or "none"))
    PrintPerfLine("resourceToken", tostring(resources.powerToken or "none"))
    PrintPerfLine("resourceUpdates", resources.updateCount or 0)
    PrintPerfLine("resourceFullRefreshes", resources.fullRefreshes or 0)
    PrintPerfLine("resourceMaxPower", "fast=" .. tostring(resources.maxPowerFastUpdates or 0) ..
        " layoutRefresh=" .. tostring(resources.maxPowerLayoutRefreshes or 0))
    PrintPerfLine("resourceLoadSkips", "class=" .. tostring(resources.classLoadSkips or 0) ..
        " power=" .. tostring(resources.powerLoadSkips or 0) ..
        " hp=" .. tostring(resources.hpLoadSkips or 0))
    PrintPerfLine("resourceTickActive", resources.tickActive == true)
    PrintPerfLine("resourceBoundEvents", resources.boundRuntimeEvents or 0)
    PrintPerfLine("resourceEventList", resources.boundRuntimeEventList or "none")
    PrintPerfLine("resourceFrequentPowerBound", resources.unitPowerFrequentBound == true)
    PrintPerfLine("resourceUnitAuraBound", resources.unitAuraBound == true)
    PrintPerfLine("resourceDisplayPowerBound", resources.displayPowerEventBound == true)
    PrintPerfLine("resourceSpecEventsBound", resources.specEventBound == true)
    PrintPerfLine("resourceShapeshiftEventBound", resources.shapeshiftEventBound == true)
    PrintPerfLine("resourceAuraMode", resources.resourceAuraMode == true)
    PrintPerfLine("resourceMountEventBound", resources.mountEventBound == true)
    PrintPerfLine("resourceVehicleEventBound", resources.vehicleEventBound == true)
    PrintPerfLine("resourcePercentReaders", "power=" .. tostring(resources.playerPowerPercentMode or "nil") ..
        " hp=" .. tostring(resources.playerHealthPercentMode or "nil") ..
        " powerReads=" .. tostring(resources.powerPercentReads or 0) ..
        " hpReads=" .. tostring(resources.healthPercentReads or 0))
    PrintPerfLine("powerBar", "enabled=" .. tostring(resources.powerBarEnabled) ..
        " shown=" .. tostring(resources.powerBarShown) ..
        " smooth=" .. tostring(resources.playerPowerSmooth))
    PrintPerfLine("hpBar", "shown=" .. tostring(resources.hpBarShown) ..
        " defaultEnabled=" .. tostring(resources.hpBarDefaultEnabled))
    PrintPerfLine("compatCache", "hits=" .. tostring(compat.hits or 0) ..
        " misses=" .. tostring(compat.misses or 0) ..
        " apiCalls=" .. tostring(compat.apiCalls or 0) ..
        " errors=" .. tostring(compat.apiErrors or 0))
    PrintPerfLine("index", "cooldowns=" .. tostring(index.totalCooldowns or 0) ..
        " generation=" .. tostring(index.generation or "n/a") ..
        " compatGeneration=" .. tostring(index.compatGeneration or "n/a"))

    if previous then
        local secondsDelta = NumberDelta(snapshot.time, previous.time)
        local cpuDelta = NumberDelta(snapshot.cpu, previous.cpu)
        local resourceUpdatesDelta = NumberDelta(snapshot.resourceUpdates, previous.resourceUpdates)
        local resourceFullRefreshesDelta = NumberDelta(snapshot.resourceFullRefreshes, previous.resourceFullRefreshes)
        local maxPowerFastUpdatesDelta = NumberDelta(snapshot.maxPowerFastUpdates, previous.maxPowerFastUpdates)
        local maxPowerLayoutRefreshesDelta = NumberDelta(snapshot.maxPowerLayoutRefreshes, previous.maxPowerLayoutRefreshes)
        local classLoadSkipsDelta = NumberDelta(snapshot.classLoadSkips, previous.classLoadSkips)
        local powerLoadSkipsDelta = NumberDelta(snapshot.powerLoadSkips, previous.powerLoadSkips)
        local hpLoadSkipsDelta = NumberDelta(snapshot.hpLoadSkips, previous.hpLoadSkips)
        local powerPercentReadsDelta = NumberDelta(snapshot.powerPercentReads, previous.powerPercentReads)
        local healthPercentReadsDelta = NumberDelta(snapshot.healthPercentReads, previous.healthPercentReads)
        local compatHitsDelta = NumberDelta(snapshot.compatHits, previous.compatHits)
        local compatMissesDelta = NumberDelta(snapshot.compatMisses, previous.compatMisses)
        local compatApiCallsDelta = NumberDelta(snapshot.compatApiCalls, previous.compatApiCalls)
        local compatApiErrorsDelta = NumberDelta(snapshot.compatApiErrors, previous.compatApiErrors)

        PrintPerfLine("deltaSeconds", secondsDelta)
        PrintPerfLine("addonCPUDelta", cpuDelta)
        PrintPerfLine("addonCPUPerSecond", RatePerSecond(cpuDelta, secondsDelta))
        PrintPerfLine("resourceUpdatesDelta", resourceUpdatesDelta)
        PrintPerfLine("resourceUpdatesPerSecond", RatePerSecond(resourceUpdatesDelta, secondsDelta))
        PrintPerfLine("resourceFullRefreshesDelta", resourceFullRefreshesDelta)
        PrintPerfLine("resourceFullRefreshesPerSecond", RatePerSecond(resourceFullRefreshesDelta, secondsDelta))
        PrintPerfLine("resourceMaxPowerFastDelta", maxPowerFastUpdatesDelta)
        PrintPerfLine("resourceMaxPowerFastPerSecond", RatePerSecond(maxPowerFastUpdatesDelta, secondsDelta))
        PrintPerfLine("resourceMaxPowerLayoutRefreshDelta", maxPowerLayoutRefreshesDelta)
        PrintPerfLine("resourceMaxPowerLayoutRefreshPerSecond", RatePerSecond(maxPowerLayoutRefreshesDelta, secondsDelta))
        PrintPerfLine("resourceClassLoadSkipsDelta", classLoadSkipsDelta)
        PrintPerfLine("resourceClassLoadSkipsPerSecond", RatePerSecond(classLoadSkipsDelta, secondsDelta))
        PrintPerfLine("resourcePowerLoadSkipsDelta", powerLoadSkipsDelta)
        PrintPerfLine("resourcePowerLoadSkipsPerSecond", RatePerSecond(powerLoadSkipsDelta, secondsDelta))
        PrintPerfLine("resourceHPLoadSkipsDelta", hpLoadSkipsDelta)
        PrintPerfLine("resourceHPLoadSkipsPerSecond", RatePerSecond(hpLoadSkipsDelta, secondsDelta))
        PrintPerfLine("powerPercentReadsDelta", powerPercentReadsDelta)
        PrintPerfLine("powerPercentReadsPerSecond", RatePerSecond(powerPercentReadsDelta, secondsDelta))
        PrintPerfLine("healthPercentReadsDelta", healthPercentReadsDelta)
        PrintPerfLine("healthPercentReadsPerSecond", RatePerSecond(healthPercentReadsDelta, secondsDelta))
        PrintPerfLine("compatHitsDelta", compatHitsDelta)
        PrintPerfLine("compatHitsPerSecond", RatePerSecond(compatHitsDelta, secondsDelta))
        PrintPerfLine("compatMissesDelta", compatMissesDelta)
        PrintPerfLine("compatMissesPerSecond", RatePerSecond(compatMissesDelta, secondsDelta))
        PrintPerfLine("compatApiCallsDelta", compatApiCallsDelta)
        PrintPerfLine("compatApiCallsPerSecond", RatePerSecond(compatApiCallsDelta, secondsDelta))
        PrintPerfLine("compatApiErrorsDelta", compatApiErrorsDelta)
    else
        PrintPerfLine("delta", "baseline_set")
    end

    lastPerfSnapshot = snapshot
end

function CDM:PrintCooldownIndexSamples()
    if not self.ForEachCooldownIndexEntry then return end

    CDM.Print("Cooldown index samples")
    local categoryCounts = {}
    self:ForEachCooldownIndexEntry(function(_, entry)
        local category = entry and entry.category or "nil"
        local count = (categoryCounts[category] or 0) + 1
        categoryCounts[category] = count
        if count <= 3 then
            local categoryName = self.GetCooldownViewerCategoryName and self:GetCooldownViewerCategoryName(category) or tostring(category)
            CDM.Print("index[" .. categoryName .. ":" .. count .. "] " .. FormatIndexEntry(entry))
        end
    end)
end

local function PrintGroupSet(label, sets)
    if type(sets) ~= "table" then
        PrintLine(label, "missing")
        return
    end

    CDM.Print(string.format(
        "%s: spellGroups=%d cooldownIDGroups=%d",
        label,
        CountKeys(sets.grouped),
        CountKeys(sets.cooldownIDGrouped)
    ))
end

function CDM:PrintCooldownGroupDiagnostics()
    CDM.Print("Cooldown group diagnostics")
    PrintGroupSet("buffGroups", self.BuffGroupSets)
    PrintGroupSet("barGroups", self.BarGroupSets)
    PrintGroupSet("cooldownGroups", self.CooldownGroupSets)
    PrintLine("auraOverlayCooldowns", CountKeys(self._auraOverlayEnabled))
    PrintLine("readyGlowCooldowns", CountKeys(self._readyGlowCooldownIDs))
end

function CDM:PrintGroupBuffItemDiagnostics()
    CDM.Print("Group buff item diagnostics")
    if not self.ForEachGroupBuffItem then
        PrintLine("groupBuffItems", "api_missing")
        return
    end

    local count = 0
    self:ForEachGroupBuffItem(function(item)
        count = count + 1
        if count <= 5 then
            CDM.Print(string.format(
                "groupBuff[%d] spell=%s name=%s icon=%s known=%s flags=%s",
                count,
                tostring(item.spellID or "nil"),
                tostring(item.name or "nil"),
                tostring(item.iconID or "nil"),
                item.isKnown and "yes" or "no",
                tostring(item.flags or "nil")
            ))
        end
    end)
    PrintLine("groupBuffItems", count)
end

function CDM:GetCooldownDiagnostics()
    local compat = self.CooldownViewerCompat and self.CooldownViewerCompat:GetDiagnostics() or {}
    local record = self.GetCooldownRecordDiagnostics and self:GetCooldownRecordDiagnostics() or {}
    local index = self.GetCooldownIndexDiagnostics and self:GetCooldownIndexDiagnostics() or {}
    local matcher = self.GetGroupMatcherDiagnostics and self:GetGroupMatcherDiagnostics() or {}
    local resources = self.GetResourceDiagnostics and self:GetResourceDiagnostics() or {}
    return {
        compat = compat,
        record = record,
        index = index,
        matcher = matcher,
        resources = resources,
        specID = self.GetCurrentSpecID and self:GetCurrentSpecID() or nil,
        dataReady = self.IsCooldownViewerDataReady and self:IsCooldownViewerDataReady() or false,
    }
end

function CDM:PrintCooldownFrameDiagnostics()
    local viewers = self.CONST and self.CONST.ALL_VIEWER_NAMES
    if not viewers then return end

    CDM.Print("Cooldown frame diagnostics")
    for _, viewerName in ipairs(viewers) do
        local active = 0
        local withRecord = 0
        local shown = 0
        local samples = 0

        if self.ForEachActiveFrame then
            self:ForEachActiveFrame({ viewerName }, function(frame)
                active = active + 1
                if frame:IsShown() then shown = shown + 1 end

                local record = self.GetFrameCooldownRecord and self:GetFrameCooldownRecord(frame)
                if record then
                    withRecord = withRecord + 1
                    if samples < 3 then
                        samples = samples + 1
                        CDM.Print(viewerName .. "[" .. samples .. "] " .. FormatRecord(record))
                    end
                end
            end)
        end

        CDM.Print(viewerName .. ": active=" .. active .. " shown=" .. shown .. " records=" .. withRecord)
    end
end

function CDM:PrintCooldownDiagnostics(mode)
    local diag = self:GetCooldownDiagnostics()
    local compat = diag.compat or {}
    local record = diag.record or {}
    local index = diag.index or {}
    local matcher = diag.matcher or {}

    CDM.Print("Cooldown diagnostics")
    PrintLine("specID", diag.specID or "none")
    PrintLine("dataReady", diag.dataReady and "true" or "false")
    PrintLine("compatGeneration", compat.generation or "n/a")
    PrintLine("compatInvalidations", compat.invalidations or 0)
    PrintLine("compatLastInvalidation", compat.lastInvalidationReason or "n/a")
    PrintLine("cooldownInfoAPI", compat.hasCooldownInfoAPI and "yes" or "no")
    PrintLine("categorySetAPI", compat.hasCategorySetAPI and "yes" or "no")
    PrintLine("groupBuffItemsAPI", compat.hasGroupBuffItemsAPI and "yes" or "no")
    PrintLine("compatCacheSize", compat.infoCacheSize or 0)
    PrintLine("compatHits", compat.hits or 0)
    PrintLine("compatMisses", compat.misses or 0)
    PrintLine("compatApiCalls", compat.apiCalls or 0)
    PrintLine("groupBuffApiCalls", compat.groupBuffApiCalls or 0)
    PrintLine("compatApiErrors", compat.apiErrors or 0)
    PrintLine("cooldownInfoErrors", compat.cooldownInfoErrors or 0)
    PrintLine("categorySetErrors", compat.categorySetErrors or 0)
    PrintLine("groupBuffErrors", compat.groupBuffErrors or 0)
    PrintLine("compatLastAPIError", compat.lastAPIError or "none")
    PrintLine("hiddenCategoryRemaps", compat.hiddenCategoryRemaps or 0)
    PrintLine("groupBuffCacheSize", compat.groupBuffItemsCacheSize or 0)
    PrintLine("recordGeneration", record.generation or "n/a")
    PrintLine("recordFrameInvalidations", record.frameInvalidations or 0)
    PrintLine("recordGenerationInvalidations", record.generationInvalidations or 0)
    PrintLine("recordFullInvalidations", record.fullInvalidations or 0)
    PrintLine("recordLastInvalidation", record.lastInvalidationReason or "n/a")
    PrintLine("indexGeneration", index.generation or "n/a")
    PrintLine("indexCompatGeneration", index.compatGeneration or "n/a")
    PrintLine("indexDirty", index.dirty and "true" or "false")
    PrintLine("indexCooldowns", index.totalCooldowns or 0)
    PrintLine("indexSpellKeys", index.totalSpellKeys or 0)
    PrintLine("indexDisplaySpellRecords", index.displaySpellRecords or 0)
    PrintLine("indexNonSpellRecords", index.nonSpellRecords or 0)
    PrintLine("indexSpellBackedRecords", index.spellBackedRecords or 0)
    PrintLine("indexItemBackedRecords", index.itemBackedRecords or 0)
    PrintLine("indexEquipSlotRecords", index.equipSlotRecords or 0)
    PrintLine("indexInvisibleRecords", index.invisibleRecords or 0)
    PrintLine("indexLastBuild", index.lastBuildReason or "n/a")
    PrintLine("matcherGeneration", matcher.frameCacheGeneration or "n/a")
    PrintLine("matcherInvalidations", matcher.frameCacheInvalidations or 0)
    PrintLine("matcherCooldownIDMatches", matcher.cooldownIDMatches or 0)
    PrintLine("matcherCandidateMatches", matcher.candidateMatches or 0)
    PrintLine("matcherMisses", matcher.misses or 0)

    if mode == "index" or mode == "all" then
        self:PrintCooldownIndexSamples()
    end
    if mode == "groups" or mode == "group" or mode == "all" then
        self:PrintCooldownGroupDiagnostics()
    end
    if mode == "groupbuffs" or mode == "groupbuff" or mode == "all" then
        self:PrintGroupBuffItemDiagnostics()
    end
    if mode == "frames" or mode == "frame" or mode == "records" or mode == "all" then
        self:PrintCooldownFrameDiagnostics()
    end
    if mode == "smoke" or mode == "ptr" then
        self:RunCooldownSmokeDiagnostic()
    end
    if mode == "perf" or mode == "cpu" then
        self:RunCooldownPerfDiagnostic()
    end
end
