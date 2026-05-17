local _, addon = ...

addon.UI = addon.UI or {}
addon.UI.TrackerFrame = {}

function addon.UI.TrackerFrame:Create()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "StealTrackFrame", UIParent, "BackdropTemplate")
    frame:SetClampedToScreen(true)

    frame.Header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.Header:SetHeight(addon.Constants.HEADER_HEIGHT)
    frame.Header:SetPoint("TOPLEFT")
    frame.Header:SetPoint("TOPRIGHT")
    frame.Header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
    })
    frame.Header:SetBackdropColor(0.09, 0.10, 0.14, 0.85)
    frame.Header:EnableMouse(true)
    frame.Header:RegisterForDrag("LeftButton")
    frame.Header:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("SpellSteal Tracker")
        if addon.db and addon.db.locked then
            GameTooltip:AddLine("Left-drag is disabled while the tracker is locked.", 0.72, 0.72, 0.72, true)
        else
            GameTooltip:AddLine("Left-drag to move the tracker.", 1, 1, 1, true)
        end
        GameTooltip:AddLine("Right-click to open settings.", 0.35, 0.82, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Slash commands", 1, 0.82, 0.20)
        GameTooltip:AddLine("/st lock  - Toggle frame lock", 0.90, 0.90, 0.95, true)
        GameTooltip:AddLine("/st reset - Reset frame position", 0.90, 0.90, 0.95, true)
        GameTooltip:AddLine("/st settings - Open settings", 0.90, 0.90, 0.95, true)
        GameTooltip:AddLine("/stealtrack also works.", 0.72, 0.72, 0.72, true)
        GameTooltip:Show()
    end)
    frame.Header:SetScript("OnLeave", GameTooltip_Hide)
    frame.Header:SetScript("OnMouseUp", function(_, buttonName)
        if buttonName == "RightButton" then
            addon:OpenSettings()
        end
    end)
    frame.Header:SetScript("OnDragStart", function()
        if addon.db.locked or InCombatLockdown() then
            return
        end

        frame:StartMoving()
    end)
    frame.Header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        addon:SavePosition()
    end)

    frame.Title = frame.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.Title:SetPoint("LEFT", 6, 0)
    frame.Title:SetText("SpellSteal Tracker")

    frame.Content = CreateFrame("Frame", nil, frame)
    frame.Content:SetPoint("TOPLEFT", frame.Header, "BOTTOMLEFT", 0, -addon.Constants.FRAME_PADDING)

    frame.buttons = {}
    for _, unitToken in addon.Units:IterateTrackedUnits() do
        frame.buttons[unitToken] = addon.UI.Buttons:CreateButton(frame.Content, unitToken)
    end

    frame:SetMovable(true)
    self.frame = frame
    self:ApplyLayout()
    self:RefreshLockState()
    return frame
end

function addon.UI.TrackerFrame:ApplyLayout()
    if not self.frame or not addon.db then
        return
    end

    local buttonSize = addon.db.buttonSize
    local spacing = addon.db.spacing
    local visibleUnits = addon.Units:GetVisibleUnits()
    local buttonCount = #visibleUnits
    local horizontal = addon.db.orientation ~= "VERTICAL"
    local width
    local height
    local previousButton

    if buttonCount == 0 then
        width = buttonSize
        height = addon.Constants.HEADER_HEIGHT + buttonSize + addon.Constants.FRAME_PADDING
    elseif horizontal then
        width = (buttonCount * buttonSize) + ((buttonCount - 1) * spacing)
        height = addon.Constants.HEADER_HEIGHT + buttonSize + addon.Constants.FRAME_PADDING
    else
        width = buttonSize
        height = addon.Constants.HEADER_HEIGHT + (buttonCount * buttonSize) + ((buttonCount - 1) * spacing) + addon.Constants.FRAME_PADDING
    end

    self.frame:SetScale(addon.db.scale)
    self.frame:ClearAllPoints()
    self.frame:SetPoint(addon.db.point, UIParent, addon.db.relativePoint, addon.db.x, addon.db.y)
    self.frame:SetSize(width, height)
    self.frame.Header:SetWidth(width)
    self.frame.Content:SetSize(width, height - addon.Constants.HEADER_HEIGHT - addon.Constants.FRAME_PADDING)

    for _, unitToken in addon.Units:IterateTrackedUnits() do
        local button = self.frame.buttons[unitToken]
        button:Hide()
        button:ClearAllPoints()
        button:SetSize(buttonSize, buttonSize)
	end

	for _, unitToken in ipairs(visibleUnits) do
		local button = self.frame.buttons[unitToken]
		button:Show()

        if previousButton then
            if horizontal then
                button:SetPoint("LEFT", previousButton, "RIGHT", spacing, 0)
            else
                button:SetPoint("TOP", previousButton, "BOTTOM", 0, -spacing)
            end
        else
            button:SetPoint("TOPLEFT", self.frame.Content, "TOPLEFT", 0, 0)
        end

        previousButton = button
    end
end

function addon.UI.TrackerFrame:RefreshLockState()
    if not self.frame or not addon.db then
        return
    end

    if addon.db.locked then
        self.frame.Header:SetAlpha(0.32)
    else
        self.frame.Header:SetAlpha(0.90)
    end

    self.frame.Title:SetText("SpellSteal Tracker")
end

function addon.UI.TrackerFrame:Update(unitStates)
    if not self.frame then
        return
    end

    for _, unitToken in ipairs(addon.Units:GetVisibleUnits()) do
        addon.UI.Buttons:UpdateButton(self.frame.buttons[unitToken], unitStates[unitToken])
    end
end