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

local function BuildTrackedAura(aura, index)
    return {
        applications = TryGetAuraField(aura, "applications"),
        auraInstanceID = TryGetAuraField(aura, "auraInstanceID"),
        duration = TryGetAuraField(aura, "duration"),
        expirationTime = TryGetAuraField(aura, "expirationTime"),
        icon = TryGetAuraField(aura, "icon"),
        name = TryGetAuraField(aura, "name"),
        scanIndex = index,
        spellId = TryGetAuraField(aura, "spellId"),
    }
end

local function IsNewerAura(candidateAura, currentAura)
    if not candidateAura then
        return false
    end

    if not currentAura then
        return true
    end

    if type(candidateAura.auraInstanceID) == "number" and type(currentAura.auraInstanceID) == "number" and candidateAura.auraInstanceID ~= currentAura.auraInstanceID then
        return candidateAura.auraInstanceID > currentAura.auraInstanceID
    end

    if type(candidateAura.expirationTime) == "number" and type(currentAura.expirationTime) == "number" and candidateAura.expirationTime ~= currentAura.expirationTime then
        return candidateAura.expirationTime > currentAura.expirationTime
    end

    return (candidateAura.scanIndex or 0) > (currentAura.scanIndex or 0)
end

function addon.Auras:GetDisplayAura(unitToken)
    if not UnitExists(unitToken) then
        return nil, nil
    end

    local index = 1
    local newestHelpfulAura
    local newestPriorityAura
    local newestStealableAura

    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex(unitToken, index, "HELPFUL")
        if not aura then
            break
        end

        if not IsAuraSecret(unitToken, index, "HELPFUL") then
            local isStealable = TryGetAuraField(aura, "isStealable")
            local trackedAura = BuildTrackedAura(aura, index)

            if IsNewerAura(trackedAura, newestHelpfulAura) then
                newestHelpfulAura = trackedAura
            end

            if trackedAura.name and addon.IsPriorityAuraName and addon:IsPriorityAuraName(trackedAura.name) and IsNewerAura(trackedAura, newestPriorityAura) then
                newestPriorityAura = trackedAura
            end

            if isStealable == true then
                if IsNewerAura(trackedAura, newestStealableAura) then
                    newestStealableAura = trackedAura
                end
            end
        end

        index = index + 1
    end

    return newestPriorityAura or newestHelpfulAura, newestStealableAura
end