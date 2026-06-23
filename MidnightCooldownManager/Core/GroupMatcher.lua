local AddonName = "MidnightCooldownManager"
local CDM = _G[AddonName]

local GroupMatcher = {}
CDM.GroupMatcher = GroupMatcher

local EMPTY_SET = {}
local frameCategoryCacheGeneration = 0
local diagnostics = {
    frameCacheInvalidations = 0,
    cooldownIDMatches = 0,
    candidateMatches = 0,
    misses = 0,
}

function GroupMatcher:InvalidateFrameCache()
    frameCategoryCacheGeneration = frameCategoryCacheGeneration + 1
    diagnostics.frameCacheInvalidations = diagnostics.frameCacheInvalidations + 1
end

function GroupMatcher:MatchCooldownInfo(info, spellToTarget, opts)
    if not info or not spellToTarget or not opts or not opts.validator then return nil end
    local validator = opts.validator
    local match

    if validator(info.overrideTooltipSpellID) then
        match = spellToTarget[info.overrideTooltipSpellID]
    end

    local hasDistinctOverride = false
    if not match then
        hasDistinctOverride = validator(info.overrideSpellID) and info.overrideSpellID ~= info.spellID
        if hasDistinctOverride then
            match = spellToTarget[info.overrideSpellID]
        end
        if not match then
            local baseEntry = spellToTarget[info.spellID]
            if baseEntry then
                local suppress = false
                if hasDistinctOverride and baseEntry.dotDefaultOnly and opts.isOverrideDot and not opts.isOverrideDot(info) then
                    suppress = true
                end
                if not suppress then
                    match = baseEntry
                end
            end
        end
    end

    if not match and info.linkedSpellIDs then
        for _, linkedID in ipairs(info.linkedSpellIDs) do
            if validator(linkedID) then
                match = spellToTarget[linkedID]
                if match then break end
            end
        end
    end

    if not match and opts.fallback then
        match = opts.fallback(info, spellToTarget)
    end

    return match
end

function GroupMatcher:MatchFrame(frame, cooldownIDGroupSet, spellGroupSet, cacheKey)
    if not frame then return nil, nil end

    local gen = frame.cdmCategoryCacheGen
    if gen ~= frameCategoryCacheGeneration then
        frame.cdmBuffCategorySpellID = nil
        frame.cdmBarGroupSpellID = nil
        frame.cdmCdGroupSpellID = nil
        frame.cdmCategoryCacheGen = frameCategoryCacheGeneration
    end

    local cached = frame[cacheKey]
    spellGroupSet = spellGroupSet or EMPTY_SET
    if cached and spellGroupSet[cached] then
        return cached, spellGroupSet[cached]
    end

    local record = CDM.GetFrameCooldownRecord and CDM:GetFrameCooldownRecord(frame)
    local cooldownID = record and record.cooldownID or (CDM.GetFrameCooldownID and CDM:GetFrameCooldownID(frame))
    cooldownIDGroupSet = cooldownIDGroupSet or EMPTY_SET
    if cooldownID then
        local entry = cooldownIDGroupSet[cooldownID]
        if entry then
            frame[cacheKey] = entry.storedID
            diagnostics.cooldownIDMatches = diagnostics.cooldownIDMatches + 1
            return entry.storedID, entry.groupIdx
        end
    end

    if CDM.ForEachFrameSpellCandidate then
        local matchedID
        local matchedGroup
        CDM:ForEachFrameSpellCandidate(frame, function(candidateID)
            local groupIdx = spellGroupSet[candidateID]
            if groupIdx then
                matchedID = candidateID
                matchedGroup = groupIdx
                return true
            end
        end)
        if matchedID then
            frame[cacheKey] = matchedID
            diagnostics.candidateMatches = diagnostics.candidateMatches + 1
            return matchedID, matchedGroup
        end
    end

    frame[cacheKey] = nil
    diagnostics.misses = diagnostics.misses + 1
    return nil, nil
end

function GroupMatcher:GetDiagnostics()
    return {
        frameCacheGeneration = frameCategoryCacheGeneration,
        frameCacheInvalidations = diagnostics.frameCacheInvalidations,
        cooldownIDMatches = diagnostics.cooldownIDMatches,
        candidateMatches = diagnostics.candidateMatches,
        misses = diagnostics.misses,
    }
end

function CDM:InvalidateFrameCategoryCache()
    GroupMatcher:InvalidateFrameCache()
end

function CDM:MatchCooldownInfoToGroup(info, spellToTarget, opts)
    return GroupMatcher:MatchCooldownInfo(info, spellToTarget, opts)
end

function CDM:MatchFrameCooldownGroup(frame, cooldownIDGroupSet, spellGroupSet, cacheKey)
    return GroupMatcher:MatchFrame(frame, cooldownIDGroupSet, spellGroupSet, cacheKey)
end

function CDM:GetGroupMatcherDiagnostics()
    return GroupMatcher:GetDiagnostics()
end
