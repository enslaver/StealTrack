local _, addon = ...

addon.Auras = {}

local function TryGetAuraField(aura, fieldName)
    local ok, value = pcall(function()
        return aura[fieldName]
    end)

    if ok then
        return value
    end

    return nil
end

local function IsAuraSecret(unitToken, index, filter)
    if not C_Secrets or not C_Secrets.ShouldUnitAuraIndexBeSecret then
        return false
    end

    local ok, isSecret = pcall(C_Secrets.ShouldUnitAuraIndexBeSecret, unitToken, index, filter)
    if ok then
        return isSecret == true
    end

    return false
end

function addon.Auras:GetFirstStealableAura(unitToken)
    if not UnitExists(unitToken) then
        return nil
    end

    local index = 1

    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex(unitToken, index, "HELPFUL")
        if not aura then
            break
        end

        if not IsAuraSecret(unitToken, index, "HELPFUL") then
            local isStealable = TryGetAuraField(aura, "isStealable")

            if isStealable == true then
                return {
                    applications = TryGetAuraField(aura, "applications"),
                    duration = TryGetAuraField(aura, "duration"),
                    expirationTime = TryGetAuraField(aura, "expirationTime"),
                    icon = TryGetAuraField(aura, "icon"),
                    name = TryGetAuraField(aura, "name"),
                    spellId = TryGetAuraField(aura, "spellId"),
                }
            end
        end

        index = index + 1
    end

    return nil
end