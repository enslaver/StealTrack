local _, addon = ...

addon.Auras = {}

local HELPFUL_AURA_QUERY = "HELPFUL"
local HELPFUL_AURA_FILTER = "HELPFUL|INCLUDE_NAME_PLATE_ONLY"
local HOSTILE_AURA_STICKY_SECONDS = 0.75
local GetMatchingNameplateUnitToken

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

local function CloneTrackedAura(aura)
    if type(aura) ~= "table" then
        return nil
    end

    local copy = {}

    for key, value in pairs(aura) do
        copy[key] = value
    end

    return copy
end

local function GetHostileAuraMemoryKey(unitToken)
    return GetMatchingNameplateUnitToken(unitToken) or unitToken
end

local function RememberHostileAuras(unitToken, displayAura, stealableAura)
    local memoryKey = GetHostileAuraMemoryKey(unitToken)

    if not memoryKey then
        return
    end

    addon.hostileAuraMemory = addon.hostileAuraMemory or {}
    addon.hostileAuraMemory[memoryKey] = {
        displayAura = CloneTrackedAura(displayAura),
        expiresAt = GetTime() + HOSTILE_AURA_STICKY_SECONDS,
        stealableAura = CloneTrackedAura(stealableAura),
    }
end

local function GetRememberedHostileAuras(unitToken)
    local memoryKey = GetHostileAuraMemoryKey(unitToken)
    local memory = addon.hostileAuraMemory and memoryKey and addon.hostileAuraMemory[memoryKey] or nil

    if not memory then
        return nil, nil
    end

    if type(memory.expiresAt) == "number" and GetTime() > memory.expiresAt then
        addon.hostileAuraMemory[memoryKey] = nil
        return nil, nil
    end

    return CloneTrackedAura(memory.displayAura), CloneTrackedAura(memory.stealableAura)
end

local function GetAuraQueryUnitToken(unitToken)
    local nameplateUnitToken = GetMatchingNameplateUnitToken(unitToken)

    if nameplateUnitToken then
        return nameplateUnitToken
    end

    return unitToken
end

local function GetHelpfulAuras(unitToken)
    local queryUnitToken = GetAuraQueryUnitToken(unitToken)

    if C_UnitAuras.GetUnitAuras then
        return C_UnitAuras.GetUnitAuras(queryUnitToken, HELPFUL_AURA_QUERY) or {}
    end

    local helpfulAuras = {}
    local index = 1

    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex(queryUnitToken, index, HELPFUL_AURA_QUERY)
        if not aura then
            break
        end

        if not IsAuraSecret(queryUnitToken, index, HELPFUL_AURA_QUERY) then
            table.insert(helpfulAuras, aura)
        end

        index = index + 1
    end

    return helpfulAuras
end

function GetMatchingNameplateUnitToken(unitToken)
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then
        return nil
    end

    if addon.Units and addon.Units.IsArenaUnit and addon.Units:IsArenaUnit(unitToken) then
        return nil
    end

    local ok, nameplate = pcall(C_NamePlate.GetNamePlateForUnit, unitToken)
    if not ok then
        return nil
    end

    local nameplateUnitToken = nameplate and (nameplate.unitToken or (nameplate.GetUnit and nameplate:GetUnit()))

    if nameplateUnitToken then
        return nameplateUnitToken, nameplate
    end

    return nil
end

local function GetNameplateAurasFrame(unitToken)
    local nameplateUnitToken, nameplate = GetMatchingNameplateUnitToken(unitToken)
    local unitFrame = nameplate and nameplate.UnitFrame

    if not nameplateUnitToken or not unitFrame or not unitFrame.AurasFrame then
        return nil, nil
    end

    return nameplateUnitToken, unitFrame.AurasFrame
end

local function BuildVisibleAuraFromFrame(auraItemFrame, fallbackIndex)
    if not auraItemFrame or not auraItemFrame.Icon then
        return nil
    end

    local icon = auraItemFrame.Icon.GetTexture and auraItemFrame.Icon:GetTexture() or nil
    local spellId = auraItemFrame.spellID
    local auraName = nil

    if spellId and C_Spell and C_Spell.GetSpellName then
        auraName = C_Spell.GetSpellName(spellId)
    end

    return {
        auraInstanceID = auraItemFrame.auraInstanceID,
        icon = icon,
        name = auraName,
        scanIndex = auraItemFrame.layoutIndex or fallbackIndex,
        spellId = spellId,
        source = "nameplate-frame",
    }
end

local function GetVisibleNameplateBuffAuras(unitToken)
    local _, aurasFrame = GetNameplateAurasFrame(unitToken)
    local buffListFrame = aurasFrame and aurasFrame.BuffListFrame
    local visibleAuras = {}

    if not buffListFrame then
        return visibleAuras
    end

    for index, auraItemFrame in ipairs({ buffListFrame:GetChildren() }) do
        if auraItemFrame and auraItemFrame:IsShown() then
            local aura = BuildVisibleAuraFromFrame(auraItemFrame, index)

            if aura and aura.icon then
                table.insert(visibleAuras, aura)
            end
        end
    end

    table.sort(visibleAuras, function(a, b)
        return (a.scanIndex or 0) < (b.scanIndex or 0)
    end)

    return visibleAuras
end

local function IsSpellstealableAura(unitToken, aura)
    local function IsAuraFlagSet(fieldName)
        local ok, isSet = pcall(function()
            return aura[fieldName] and true or false
        end)

        return ok and isSet == true
    end

    local function IsAuraMagicDispelType()
        local ok, isMagic = pcall(function()
            local dispelType = aura.dispelName or aura.dispelType

            if dispelType == nil then
                return false
            end

            if _G.DISPEL_TYPE_MAGIC and dispelType == _G.DISPEL_TYPE_MAGIC then
                return true
            end

            return dispelType == "Magic"
        end)

        return ok and isMagic == true
    end

    if not aura then
        return false
    end

    if not (addon.Units and addon.Units.IsHostileUnit and addon.Units:IsHostileUnit(unitToken)) then
        return false
    end

    if IsAuraFlagSet("isStealable") then
        return true
    end

    if IsAuraFlagSet("canStealOrPurge") then
        return true
    end

    if IsAuraFlagSet("canActivePlayerDispel") then
        return true
    end

    return IsAuraMagicDispelType()
end

local function TryCompareAuraNumbers(candidateValue, currentValue)
    if type(candidateValue) ~= "number" or type(currentValue) ~= "number" then
        return nil
    end

    local ok, areDifferent, isGreater = pcall(function()
        return candidateValue ~= currentValue, candidateValue > currentValue
    end)

    if not ok or not areDifferent then
        return nil
    end

    return isGreater == true
end

local function IsNewerAura(candidateAura, currentAura)
    if not candidateAura then
        return false
    end

    if not currentAura then
        return true
    end

    local isNewerByInstance = TryCompareAuraNumbers(candidateAura.auraInstanceID, currentAura.auraInstanceID)
    if isNewerByInstance ~= nil then
        return isNewerByInstance
    end

    local isNewerByExpiration = TryCompareAuraNumbers(candidateAura.expirationTime, currentAura.expirationTime)
    if isNewerByExpiration ~= nil then
        return isNewerByExpiration
    end

    return (candidateAura.scanIndex or 0) > (currentAura.scanIndex or 0)
end

local function GetNameplateAuraFallback(unitToken)
    local nameplateUnitToken, aurasFrame = GetNameplateAurasFrame(unitToken)
    local buffList = aurasFrame and aurasFrame.buffList
    local fallbackHelpfulAura
    local fallbackPriorityAura
    local fallbackStealableAura
    local fallbackIndex = 0

    if not nameplateUnitToken or not buffList or type(buffList.Iterate) ~= "function" then
        return nil, nil, nil
    end

    buffList:Iterate(function(_, aura)
        if not aura then
            return
        end

        fallbackIndex = fallbackIndex + 1

        local trackedAura = BuildTrackedAura(aura, fallbackIndex)
        local isStealable = addon.Units and addon.Units.IsHostileUnit and addon.Units:IsHostileUnit(unitToken) or IsSpellstealableAura(unitToken, aura)

        if IsNewerAura(trackedAura, fallbackHelpfulAura) then
            fallbackHelpfulAura = trackedAura
        end

        if addon.IsPriorityAura and addon:IsPriorityAura(trackedAura) and IsNewerAura(trackedAura, fallbackPriorityAura) then
            fallbackPriorityAura = trackedAura
        end

        if isStealable and IsNewerAura(trackedAura, fallbackStealableAura) then
            fallbackStealableAura = trackedAura
        end
    end)

    return fallbackHelpfulAura, fallbackPriorityAura, fallbackStealableAura
end

local function GetNameplateListAuras(unitToken)
    local _, aurasFrame = GetNameplateAurasFrame(unitToken)
    local buffList = aurasFrame and aurasFrame.buffList
    local trackedAuras = {}
    local fallbackIndex = 0

    if not buffList or type(buffList.Iterate) ~= "function" then
        return trackedAuras
    end

    buffList:Iterate(function(_, aura)
        if not aura then
            return
        end

        fallbackIndex = fallbackIndex + 1

        local trackedAura = BuildTrackedAura(aura, fallbackIndex)
        if trackedAura.icon or trackedAura.spellId or trackedAura.name then
            table.insert(trackedAuras, trackedAura)
        end
    end)

    return trackedAuras
end

local function GetCachedNameplateAuras(unitToken)
    local nameplateUnitToken = GetMatchingNameplateUnitToken(unitToken)
    local cache = addon.nameplateAuraCache and nameplateUnitToken and addon.nameplateAuraCache[nameplateUnitToken]
    local helpfulAuras = {}

    if not cache or not cache.byInstanceID then
        return helpfulAuras
    end

    for _, aura in pairs(cache.byInstanceID) do
        table.insert(helpfulAuras, aura)
    end

    return helpfulAuras
end

local function GetDebugAuraLabel(aura)
    if type(aura) ~= "table" then
        return nil
    end

    local spellId = TryGetAuraField(aura, "spellId") or TryGetAuraField(aura, "spellID")
    if type(spellId) == "number" then
        return "spell:" .. spellId
    end

    local auraInstanceID = TryGetAuraField(aura, "auraInstanceID")
    if type(auraInstanceID) == "number" then
        return "aura:" .. auraInstanceID
    end

    local source = TryGetAuraField(aura, "source")
    if type(source) == "string" and source ~= "" then
        return source
    end

    return "set"
end

function addon.Auras:GetDebugSnapshot(unitToken)
    local isHostile = addon.Units and addon.Units.IsHostileUnit and addon.Units:IsHostileUnit(unitToken)
    local queryUnitToken = GetAuraQueryUnitToken(unitToken)
    local nameplateUnitToken = GetMatchingNameplateUnitToken(unitToken)
    local helpfulAuras = UnitExists(unitToken) and GetHelpfulAuras(unitToken) or {}
    local cachedHelpfulAuras = GetCachedNameplateAuras(unitToken)
    local nameplateListAuras = GetNameplateListAuras(unitToken)
    local visibleNameplateAuras = GetVisibleNameplateBuffAuras(unitToken)
    local sampleAuras = {}
    local stealableCount = 0

    if isHostile then
        local debugAuras = #visibleNameplateAuras > 0 and visibleNameplateAuras or nameplateListAuras

        if #debugAuras == 0 then
            debugAuras = cachedHelpfulAuras
        end

        stealableCount = #debugAuras

        for index, aura in ipairs(debugAuras) do
            if index <= 8 then
                table.insert(sampleAuras, "tracked")
            end
        end
    else
        for index, aura in ipairs(helpfulAuras) do
            local isStealable = IsSpellstealableAura(unitToken, aura)

            if isStealable then
                stealableCount = stealableCount + 1
            end

            if index <= 8 then
                table.insert(sampleAuras, isStealable and "tracked*" or "tracked")
            end
        end
    end

    local displayAura, stealableAura = self:GetDisplayAura(unitToken)

    return {
        displayAuraName = GetDebugAuraLabel(displayAura),
        cachedHelpfulCount = #cachedHelpfulAuras,
        helpfulCount = #helpfulAuras,
        nameplateListCount = #nameplateListAuras,
        nameplateUnitToken = nameplateUnitToken,
        queryUnitToken = queryUnitToken,
        visibleNameplateCount = #visibleNameplateAuras,
        sampleAuras = sampleAuras,
        stealableAuraName = GetDebugAuraLabel(stealableAura),
        stealableCount = stealableCount,
        unitToken = unitToken,
    }
end

function addon.Auras:GetDisplayAura(unitToken)
    if not UnitExists(unitToken) then
        return nil, nil
    end

    local isHostile = addon.Units and addon.Units.IsHostileUnit and addon.Units:IsHostileUnit(unitToken)
    local helpfulAuras = GetHelpfulAuras(unitToken)

    local fallbackHelpfulAura
    local fallbackPriorityAura
    local fallbackStealableAura
    local cachedIndex = 0
    local cachedHelpfulAuras = GetCachedNameplateAuras(unitToken)
    local nameplateListAuras = GetNameplateListAuras(unitToken)
    local visibleNameplateAuras = GetVisibleNameplateBuffAuras(unitToken)
    local newestHelpfulAura
    local newestPriorityAura
    local newestStealableAura

    for index, aura in ipairs(helpfulAuras) do
        local isStealable = IsSpellstealableAura(unitToken, aura)
        local trackedAura = BuildTrackedAura(aura, index)

        if IsNewerAura(trackedAura, newestHelpfulAura) then
            newestHelpfulAura = trackedAura
        end

        if addon.IsPriorityAura and addon:IsPriorityAura(trackedAura) and IsNewerAura(trackedAura, newestPriorityAura) then
            newestPriorityAura = trackedAura
        end

        if isStealable == true and IsNewerAura(trackedAura, newestStealableAura) then
            newestStealableAura = trackedAura
        end
    end

    if not isHostile then
        for _, aura in ipairs(cachedHelpfulAuras) do
            cachedIndex = cachedIndex + 1

            local isStealable = IsSpellstealableAura(unitToken, aura)
            local trackedAura = BuildTrackedAura(aura, #helpfulAuras + cachedIndex)

            if IsNewerAura(trackedAura, newestHelpfulAura) then
                newestHelpfulAura = trackedAura
            end

            if addon.IsPriorityAura and addon:IsPriorityAura(trackedAura) and IsNewerAura(trackedAura, newestPriorityAura) then
                newestPriorityAura = trackedAura
            end

            if isStealable == true and IsNewerAura(trackedAura, newestStealableAura) then
                newestStealableAura = trackedAura
            end
        end
    end

    for _, trackedAura in ipairs(visibleNameplateAuras) do
        if IsNewerAura(trackedAura, newestHelpfulAura) then
            newestHelpfulAura = trackedAura
        end

        if not isHostile and addon.IsPriorityAura and addon:IsPriorityAura(trackedAura) and IsNewerAura(trackedAura, newestPriorityAura) then
            newestPriorityAura = trackedAura
        end

        if IsNewerAura(trackedAura, newestStealableAura) then
            newestStealableAura = trackedAura
        end
    end

    if isHostile then
        for _, aura in ipairs(cachedHelpfulAuras) do
            cachedIndex = cachedIndex + 1

            local trackedAura = BuildTrackedAura(aura, cachedIndex)

            if IsNewerAura(trackedAura, newestHelpfulAura) then
                newestHelpfulAura = trackedAura
            end

            if IsNewerAura(trackedAura, newestStealableAura) then
                newestStealableAura = trackedAura
            end
        end

        for _, trackedAura in ipairs(nameplateListAuras) do
            if IsNewerAura(trackedAura, newestHelpfulAura) then
                newestHelpfulAura = trackedAura
            end

            if IsNewerAura(trackedAura, newestStealableAura) then
                newestStealableAura = trackedAura
            end
        end
    end

    if not isHostile then
        fallbackHelpfulAura, fallbackPriorityAura, fallbackStealableAura = GetNameplateAuraFallback(unitToken)

        if fallbackPriorityAura and IsNewerAura(fallbackPriorityAura, newestPriorityAura) then
            newestPriorityAura = fallbackPriorityAura
        end

        if not newestHelpfulAura and fallbackHelpfulAura then
            newestHelpfulAura = fallbackHelpfulAura
        end

        if not newestStealableAura and fallbackStealableAura then
            newestStealableAura = fallbackStealableAura
            if not newestPriorityAura and fallbackHelpfulAura then
                newestHelpfulAura = fallbackHelpfulAura
            end
        end
    end

    local displayAura = newestPriorityAura or newestHelpfulAura

    if isHostile then
        if displayAura or newestStealableAura then
            RememberHostileAuras(unitToken, displayAura, newestStealableAura)
        else
            displayAura, newestStealableAura = GetRememberedHostileAuras(unitToken)
        end
    end

    return displayAura, newestStealableAura
end