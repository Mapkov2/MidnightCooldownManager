local CDM = _G["MidnightCooldownManager"]
CDM.L = setmetatable({}, {
    __index = function(_, key) return key end,
})

function CDM:NewLocale(locale)
    if GetLocale() == locale then
        return self.L
    end
end
