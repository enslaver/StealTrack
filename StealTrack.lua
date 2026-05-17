local addonName, addon = ...

addon.EventFrame = CreateFrame("Frame")
addon.unitStates = {}

local trackedEvents = {
    "PLAYER_ENTERING_WORLD",
    "PLAYER_TARGET_CHANGED",
    "PLAYER_FOCUS_CHANGED",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_SPECIALIZATION_CHANGED",
    "SPELLS_CHANGED",
    "UNIT_AURA",
    "ARENA_OPPONENT_UPDATE",
    "ZONE_CHANGED_NEW_AREA",
}

local function Trim(text)
    return (text or ""):match("^%s*(.-)%s*$")
end

local function NormalizeLineEndings(text)
    return (text or ""):gsub("|n", "\n"):gsub("\r\n", "\n"):gsub("\r", "\n")
end

local function MergeDefaults(target, defaults)
    target = target or {}

    for key, value in pairs(defaults) do
        if type(value) == "table" then
            target[key] = MergeDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end

    return target
end

local function CloneTable(source)
    local copy = {}

    for key, value in pairs(source or {}) do
        if type(value) == "table" then
            copy[key] = CloneTable(value)
        else
            copy[key] = value
        end
    end

    return copy
end

function addon:GetSpellstealName()
    if self.spellstealName then
        return self.spellstealName
    end

    if C_Spell and C_Spell.GetSpellName then
        self.spellstealName = C_Spell.GetSpellName(self.Constants.SPELLSTEAL_SPELL_ID)
    end

    return self.spellstealName
end

function addon:GetSpellstealTexture()
    if self.spellstealTexture then
        return self.spellstealTexture
    end

    if C_Spell and C_Spell.GetSpellTexture then
        self.spellstealTexture = C_Spell.GetSpellTexture(self.Constants.SPELLSTEAL_SPELL_ID)
    end

    return self.spellstealTexture
end

function addon:IsMage()
    return select(2, UnitClass("player")) == "MAGE"
end

function addon:PlayerCanSpellsteal()
    if not self:IsMage() then
        return false
    end

    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(self.Constants.SPELLSTEAL_SPELL_ID)
    end

    return IsPlayerSpell(self.Constants.SPELLSTEAL_SPELL_ID)
end

function addon:BuildUnitState(unitToken)
    local spellKnown = self:PlayerCanSpellsteal()
    local exists = UnitExists(unitToken)
    local isEnemy = exists and UnitCanAttack("player", unitToken) or false
    local aura
    local isPriorityAura = false

    if spellKnown and self.Units:IsValidEnemyUnit(unitToken) then
        aura = self.Auras:GetDisplayAura(unitToken)
        if aura and aura.name and self:IsPriorityAuraName(aura.name) then
            isPriorityAura = true
        end
    end

    return {
        aura = aura,
        exists = exists,
        hasStealableAura = aura ~= nil,
        inRange = aura and self.Range:IsSpellstealInRange(unitToken) or false,
        isPriorityAura = isPriorityAura,
        isEnemy = isEnemy,
        label = self.Units:GetDisplayName(unitToken),
        spellKnown = spellKnown,
        spellTexture = self:GetSpellstealTexture(),
        unitName = exists and UnitName(unitToken) or nil,
        unitToken = unitToken,
    }
end

function addon:IsPriorityAuraName(auraName)
    return auraName ~= nil and self.db ~= nil and self.db.priorityAuraNames ~= nil and self.db.priorityAuraNames[auraName] == true
end

function addon:GetPriorityAuraNamesText()
    local names = {}

    for auraName in pairs(self.db.priorityAuraNames or {}) do
        table.insert(names, auraName)
    end

    table.sort(names)
    return table.concat(names, "\n")
end

function addon:SetPriorityAuraNamesFromText(text)
    local updatedNames = {}
    local normalizedText = NormalizeLineEndings(text)

    for line in string.gmatch(normalizedText .. "\n", "(.-)\n") do
        local auraName = Trim(line)
        if auraName ~= "" then
            updatedNames[auraName] = true
        end
    end

    self.db.priorityAuraNames = updatedNames
    if type(StealTrackDB) == "table" then
        StealTrackDB.priorityAuraNames = updatedNames
    end
    self:RefreshAll()
end

function addon:ResetPriorityAuraNames()
    self.db.priorityAuraNames = CloneTable(self.Constants.DEFAULTS.priorityAuraNames)
    self:RefreshAll()
end

function addon:RefreshAll()
    if not self.initialized then
        return
    end

    for _, unitToken in self.Units:IterateTrackedUnits() do
        self.unitStates[unitToken] = self:BuildUnitState(unitToken)
    end

    self.UI.TrackerFrame:Update(self.unitStates)
    if self.UI.Settings.panel and self.UI.Settings.panel:IsVisible() then
        self.UI.Settings.panel.Refresh()
    end
end

function addon:RefreshUnit(unitToken)
    if not self.initialized then
        return
    end

    self.unitStates[unitToken] = self:BuildUnitState(unitToken)
    self.UI.TrackerFrame:Update(self.unitStates)
end

function addon:ApplyLayout()
    if InCombatLockdown() then
        self.layoutPending = true
        return
    end

    self.layoutPending = false
    self.UI.TrackerFrame:ApplyLayout()
    self.UI.TrackerFrame:RefreshLockState()
end

function addon:SavePosition()
    if not self.TrackerFrame then
        return
    end

    local point, _, relativePoint, x, y = self.TrackerFrame:GetPoint(1)
    self.db.point = point
    self.db.relativePoint = relativePoint
    self.db.x = x
    self.db.y = y
end

function addon:SetLocked(locked)
    self.db.locked = locked and true or false
    self.UI.TrackerFrame:RefreshLockState()
end

function addon:SetScale(scale)
    self.db.scale = tonumber(string.format("%.2f", scale))
    self:ApplyLayout()
end

function addon:SetButtonSize(buttonSize)
    self.db.buttonSize = math.floor(buttonSize + 0.5)
    self:ApplyLayout()
end

function addon:SetSpacing(spacing)
    self.db.spacing = math.floor(spacing + 0.5)
    self:ApplyLayout()
end

function addon:SetOrientation(orientation)
    if orientation ~= "VERTICAL" then
        orientation = "HORIZONTAL"
    end

    self.db.orientation = orientation
    self:ApplyLayout()
end

function addon:SetHideArenaTargetsOutsideArena(hideArenaTargets)
    self.db.hideArenaTargetsOutsideArena = hideArenaTargets and true or false
    self:ApplyLayout()
    self:RefreshAll()
end

function addon:ResetPosition()
    self.db.point = self.Constants.DEFAULTS.point
    self.db.relativePoint = self.Constants.DEFAULTS.relativePoint
    self.db.x = self.Constants.DEFAULTS.x
    self.db.y = self.Constants.DEFAULTS.y
    self:ApplyLayout()
end

function addon:OpenSettings()
    if Settings and Settings.OpenToCategory and self.settingsCategory then
        local function TryOpen(target)
            if target == nil then
                return false
            end

            return pcall(Settings.OpenToCategory, target)
        end

        if TryOpen(self.settingsCategory) then
            return
        end

        if self.settingsCategory.GetID and TryOpen(self.settingsCategory:GetID()) then
            return
        end

        if TryOpen(self.settingsCategoryID) then
            return
        end

        if TryOpen(self.UI.Settings.panel) then
            return
        end
    end

    if InterfaceOptionsFrame_OpenToCategory and self.UI.Settings.panel then
        InterfaceOptionsFrame_OpenToCategory(self.UI.Settings.panel)
        InterfaceOptionsFrame_OpenToCategory(self.UI.Settings.panel)
    end
end

function addon:RegisterGameplayEvents()
    for _, eventName in ipairs(trackedEvents) do
        self.EventFrame:RegisterEvent(eventName)
    end
end

function addon:RegisterSlashCommands()
    SLASH_STEALTRACK1 = "/stealtrack"
    SLASH_STEALTRACK2 = "/st"
    SlashCmdList.STEALTRACK = function(message)
        local command = (message or ""):lower():match("^%s*(.-)%s*$")

        if command == "lock" then
            self:SetLocked(not self.db.locked)
            print(string.format("StealTrack: frame %s.", self.db.locked and "locked" or "unlocked"))
            return
        end

        if command == "reset" then
            self:ResetPosition()
            print("StealTrack: frame position reset.")
            return
        end

        if command == "settings" then
            self:OpenSettings()
            return
        end

        print("StealTrack commands: /st lock, /st reset, /st settings")
    end
end

function addon:Initialize()
    self.db = MergeDefaults(StealTrackDB, self.Constants.DEFAULTS)
    StealTrackDB = self.db
    self:GetSpellstealName()
    self:GetSpellstealTexture()
    self.TrackerFrame = self.UI.TrackerFrame:Create()
    self.UI.Settings:Register()
    self:RegisterSlashCommands()
    self:RegisterGameplayEvents()
    self.initialized = true
    self.EventFrame:SetScript("OnUpdate", function(_, elapsed)
        addon.elapsedSinceRefresh = (addon.elapsedSinceRefresh or 0) + elapsed
        if addon.elapsedSinceRefresh >= addon.Constants.REFRESH_INTERVAL_SECONDS then
            addon.elapsedSinceRefresh = 0
            addon:RefreshAll()
        end
    end)
    self:ApplyLayout()
    self:RefreshAll()
end

local function OnEvent(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddonName = ...
        if loadedAddonName ~= addonName then
            return
        end

        addon.EventFrame:UnregisterEvent("ADDON_LOADED")
        addon:Initialize()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        addon:ApplyLayout()
    end

    if event == "UNIT_AURA" then
        local unitToken = ...
        if addon.Units:IsTrackedUnit(unitToken) then
            addon:RefreshUnit(unitToken)
        end
        return
    end

    if event == "ARENA_OPPONENT_UPDATE" then
        local unitToken = ...
        addon:ApplyLayout()
        if unitToken and addon.Units:IsTrackedUnit(unitToken) then
            addon:RefreshUnit(unitToken)
            return
        end
    end

    if event == "PLAYER_REGEN_ENABLED" and addon.layoutPending then
        addon:ApplyLayout()
    end

    addon:RefreshAll()
end

addon.EventFrame:SetScript("OnEvent", OnEvent)
addon.EventFrame:RegisterEvent("ADDON_LOADED")