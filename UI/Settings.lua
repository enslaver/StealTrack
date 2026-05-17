local _, addon = ...

addon.UI = addon.UI or {}
addon.UI.Settings = {}

local function CreateCheckbox(parent, text)
	local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	checkbox.Label = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	checkbox.Label:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
	checkbox.Label:SetText(text)
	return checkbox
end

local function CreateSlider(parent, name, title, minValue, maxValue, step)
	local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
	slider:SetOrientation("HORIZONTAL")
	slider:SetMinMaxValues(minValue, maxValue)
	slider:SetValueStep(step)
	slider:SetObeyStepOnDrag(true)
	slider.Title = title

	_G[name .. "Low"]:SetText(tostring(minValue))
	_G[name .. "High"]:SetText(tostring(maxValue))
	_G[name .. "Text"]:SetText(title)
	return slider
end

local function CreateButton(parent, width, text)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 24)
	button:SetText(text)
	return button
end

function addon.UI.Settings:Register()
	if self.panel then
		return
	end

	local panel = CreateFrame("Frame", "StealTrackSettingsPanel", UIParent)
	panel.name = "StealTrack"

	panel.Title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	panel.Title:SetPoint("TOPLEFT", 16, -16)
	panel.Title:SetText("StealTrack")

	panel.Subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	panel.Subtitle:SetPoint("TOPLEFT", panel.Title, "BOTTOMLEFT", 0, -8)
	panel.Subtitle:SetText("Configure layout for Spellsteal tracker buttons.")

	panel.LockCheckbox = CreateCheckbox(panel, "Lock tracker position")
	panel.LockCheckbox:SetPoint("TOPLEFT", panel.Subtitle, "BOTTOMLEFT", 0, -18)
	panel.LockCheckbox:SetChecked(addon.db.locked)
	panel.LockCheckbox:SetScript("OnClick", function(self)
		addon:SetLocked(self:GetChecked())
	end)

	panel.ScaleSlider = CreateSlider(panel, "StealTrackScaleSlider", "Scale", 0.7, 1.5, 0.05)
	panel.ScaleSlider:SetWidth(220)
	panel.ScaleSlider:SetPoint("TOPLEFT", panel.LockCheckbox, "BOTTOMLEFT", 0, -30)
	panel.ScaleSlider:SetValue(addon.db.scale)
	panel.ScaleSlider:SetScript("OnValueChanged", function(self, value)
		if panel.refreshing then
			return
		end

		addon:SetScale(value)
	end)

	panel.IconSizeSlider = CreateSlider(panel, "StealTrackSizeSlider", "Icon Size", 28, 64, 2)
	panel.IconSizeSlider:SetWidth(220)
	panel.IconSizeSlider:SetPoint("TOPLEFT", panel.ScaleSlider, "BOTTOMLEFT", 0, -36)
	panel.IconSizeSlider:SetValue(addon.db.buttonSize)
	panel.IconSizeSlider:SetScript("OnValueChanged", function(self, value)
		if panel.refreshing then
			return
		end

		addon:SetButtonSize(value)
	end)

	panel.SpacingSlider = CreateSlider(panel, "StealTrackSpacingSlider", "Spacing", 0, 20, 1)
	panel.SpacingSlider:SetWidth(220)
	panel.SpacingSlider:SetPoint("TOPLEFT", panel.IconSizeSlider, "BOTTOMLEFT", 0, -36)
	panel.SpacingSlider:SetValue(addon.db.spacing)
	panel.SpacingSlider:SetScript("OnValueChanged", function(self, value)
		if panel.refreshing then
			return
		end

		addon:SetSpacing(value)
	end)

	panel.VerticalCheckbox = CreateCheckbox(panel, "Vertical layout")
	panel.VerticalCheckbox:SetPoint("TOPLEFT", panel.SpacingSlider, "BOTTOMLEFT", 0, -26)
	panel.VerticalCheckbox:SetChecked(addon.db.orientation == "VERTICAL")
	panel.VerticalCheckbox:SetScript("OnClick", function(self)
		addon:SetOrientation(self:GetChecked() and "VERTICAL" or "HORIZONTAL")
	end)

	panel.HideArenaCheckbox = CreateCheckbox(panel, "Hide arena targets outside arenas")
	panel.HideArenaCheckbox:SetPoint("TOPLEFT", panel.VerticalCheckbox, "BOTTOMLEFT", 0, -14)
	panel.HideArenaCheckbox:SetChecked(addon.db.hideArenaTargetsOutsideArena)
	panel.HideArenaCheckbox:SetScript("OnClick", function(self)
		addon:SetHideArenaTargetsOutsideArena(self:GetChecked())
	end)

	panel.ResetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	panel.ResetButton:SetSize(140, 24)
	panel.ResetButton:SetPoint("TOPLEFT", panel.HideArenaCheckbox, "BOTTOMLEFT", 0, -20)
	panel.ResetButton:SetText("Reset Position")
	panel.ResetButton:SetScript("OnClick", function()
		addon:ResetPosition()
	end)

	panel.PriorityLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	panel.PriorityLabel:SetPoint("TOPLEFT", panel.ResetButton, "BOTTOMLEFT", 0, -24)
	panel.PriorityLabel:SetText("Priority highlight spells (one per line)")

	panel.PriorityHelp = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	panel.PriorityHelp:SetPoint("TOPLEFT", panel.PriorityLabel, "BOTTOMLEFT", 0, -4)
	panel.PriorityHelp:SetText("Add or remove spell names here, then click Apply.")

	panel.PriorityEditBox = CreateFrame("EditBox", nil, panel, "BackdropTemplate")
	panel.PriorityEditBox:SetAutoFocus(false)
	panel.PriorityEditBox:SetMultiLine(true)
	panel.PriorityEditBox:SetFontObject(ChatFontNormal)
	panel.PriorityEditBox:SetSize(260, 140)
	panel.PriorityEditBox:SetPoint("TOPLEFT", panel.PriorityHelp, "BOTTOMLEFT", 0, -8)
	panel.PriorityEditBox:SetTextInsets(6, 6, 6, 6)
	panel.PriorityEditBox:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
	})
	panel.PriorityEditBox:SetBackdropColor(0.03, 0.03, 0.04, 0.95)
	panel.PriorityEditBox:SetBackdropBorderColor(0.20, 0.20, 0.24, 1)
	panel.PriorityEditBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)

	panel.ApplyPriorityButton = CreateButton(panel, 90, "Apply")
	panel.ApplyPriorityButton:SetPoint("TOPLEFT", panel.PriorityEditBox, "BOTTOMLEFT", 0, -10)
	panel.ApplyPriorityButton:SetScript("OnClick", function()
		addon:SetPriorityAuraNamesFromText(panel.PriorityEditBox:GetText())
		panel.Refresh()
	end)

	panel.ResetPriorityButton = CreateButton(panel, 130, "Reset Defaults")
	panel.ResetPriorityButton:SetPoint("LEFT", panel.ApplyPriorityButton, "RIGHT", 8, 0)
	panel.ResetPriorityButton:SetScript("OnClick", function()
		addon:ResetPriorityAuraNames()
		panel.Refresh()
	end)

	panel.Refresh = function()
		local priorityText = addon:GetPriorityAuraNamesText()
		local currentFocus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() or nil
		panel.refreshing = true
		panel.LockCheckbox:SetChecked(addon.db.locked)
		panel.ScaleSlider:SetValue(addon.db.scale)
		panel.IconSizeSlider:SetValue(addon.db.buttonSize)
		panel.SpacingSlider:SetValue(addon.db.spacing)
		panel.VerticalCheckbox:SetChecked(addon.db.orientation == "VERTICAL")
		panel.HideArenaCheckbox:SetChecked(addon.db.hideArenaTargetsOutsideArena)
		if currentFocus ~= panel.PriorityEditBox and panel.PriorityEditBox:GetText() ~= priorityText then
			panel.PriorityEditBox:SetText(priorityText)
		end
		panel.refreshing = false
	end

	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		local category = Settings.RegisterCanvasLayoutCategory(panel, "StealTrack")
		Settings.RegisterAddOnCategory(category)
		addon.settingsCategory = category
		if category.GetID then
			addon.settingsCategoryID = category:GetID()
		end
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end

	self.panel = panel
end