local _, addon = ...

addon.Units = {}

function addon.Units:IterateTrackedUnits()
    return ipairs(addon.Constants.TRACKED_UNITS)
end

function addon.Units:IsArenaUnit(unitToken)
    return type(unitToken) == "string" and unitToken:match("^arena%d+$") ~= nil
end

function addon.Units:IsArenaInstance()
    local _, instanceType = GetInstanceInfo()
    return instanceType == "arena"
end

function addon.Units:GetArenaOpponentCount()
    local count = 0
    local tokenCount = 0

    if type(GetNumArenaOpponentSpecs) == "function" then
        local specCount = GetNumArenaOpponentSpecs()
        if type(specCount) == "number" and specCount > count then
            count = specCount
        end
    end

    for index = 1, 5 do
        if UnitExists("arena" .. index) then
            tokenCount = tokenCount + 1
        end
    end

    if tokenCount > count then
        count = tokenCount
    end

    return count
end

function addon.Units:GetVisibleUnits()
    local visibleUnits = {}
    local hideArenaTargets = addon.db and addon.db.hideArenaTargetsOutsideArena
    local isArenaInstance = self:IsArenaInstance()
    local arenaOpponentCount = isArenaInstance and self:GetArenaOpponentCount() or 0

    for _, unitToken in self:IterateTrackedUnits() do
        local shouldShow = true

        if self:IsArenaUnit(unitToken) then
            local arenaIndex = tonumber(unitToken:match("arena(%d+)$")) or 0

            if hideArenaTargets and not isArenaInstance then
                shouldShow = false
            elseif isArenaInstance and arenaOpponentCount > 0 and arenaIndex > arenaOpponentCount then
                shouldShow = false
            end
        end

        if shouldShow then
            table.insert(visibleUnits, unitToken)
        end
    end

    return visibleUnits
end

function addon.Units:IsTrackedUnit(unitToken)
    for _, trackedUnit in self:IterateTrackedUnits() do
        if trackedUnit == unitToken then
            return true
        end
    end

    return false
end

function addon.Units:GetDisplayName(unitToken)
    if unitToken == "target" then
        return "Target"
    end

    if unitToken == "focus" then
        return "Focus"
    end

    if unitToken == "arena1" then
        return "Arena 1"
    end

    if unitToken == "arena2" then
        return "Arena 2"
    end

    if unitToken == "arena3" then
        return "Arena 3"
    end

    if unitToken == "arena4" then
        return "Arena 4"
    end

    if unitToken == "arena5" then
        return "Arena 5"
    end

    return unitToken:upper()
end

function addon.Units:IsValidEnemyUnit(unitToken)
    return UnitExists(unitToken)
        and not UnitIsDeadOrGhost(unitToken)
        and UnitCanAttack("player", unitToken)
        and UnitIsVisible(unitToken)
end