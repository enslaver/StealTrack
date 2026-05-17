local _, addon = ...

addon.Range = {}

local function NormalizeRangeResult(inRange)
    return inRange == true or inRange == 1
end

function addon.Range:IsSpellstealInRange(unitToken)
    if not UnitExists(unitToken) then
        return false
    end

    if C_Spell and C_Spell.IsSpellInRange then
        return NormalizeRangeResult(C_Spell.IsSpellInRange(addon.Constants.SPELLSTEAL_SPELL_ID, unitToken))
    end

    if addon.GetSpellstealName then
        local spellName = addon:GetSpellstealName()
        if spellName then
            return IsSpellInRange(spellName, unitToken) == 1
        end
    end

    return false
end