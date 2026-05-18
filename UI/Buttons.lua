local _, addon = ...

addon.UI = addon.UI or {}
addon.UI.Buttons = {}

function addon.UI.Buttons:CreateButton(parent, unitToken)
    local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate,BackdropTemplate")
    button.unitToken = unitToken
    button:SetSize(addon.Constants.BUTTON_SIZE, addon.Constants.BUTTON_SIZE)
    button:RegisterForClicks("LeftButtonUp")
    button:SetAttribute("type", "spell")
    button:SetAttribute("spell", addon.Constants.SPELLSTEAL_SPELL_ID)
    button:SetAttribute("unit", unitToken)

    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
        insets = {
            left = 0,
            right = 0,
            top = 0,
            bottom = 0,
        },
    })

    button:SetBackdropColor(0, 0, 0, 0)
    button:SetBackdropBorderColor(0, 0, 0, 0)

    button.Visual = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    button.Visual:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    button.Visual:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    button.Visual:SetFrameStrata(button:GetFrameStrata())
    button.Visual:SetFrameLevel(button:GetFrameLevel() + 5)
    button.Visual:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
        insets = {
            left = 0,
            right = 0,
            top = 0,
            bottom = 0,
        },
    })
    button.Visual:SetBackdropColor(unpack(addon.Constants.COLORS.BACKDROP))
    button.Visual:SetBackdropBorderColor(unpack(addon.Constants.COLORS.INACTIVE))

    button.Icon = button.Visual:CreateTexture(nil, "ARTWORK")
    button.Icon:SetPoint("TOPLEFT", 2, -2)
    button.Icon:SetPoint("BOTTOMRIGHT", -2, 2)
    button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.IconGlow = button.Visual:CreateTexture(nil, "BACKGROUND")
    button.IconGlow:SetPoint("TOPLEFT", button.Icon, "TOPLEFT", -3, 3)
    button.IconGlow:SetPoint("BOTTOMRIGHT", button.Icon, "BOTTOMRIGHT", 3, -3)
    button.IconGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.IconGlow:SetBlendMode("ADD")
    button.IconGlow:Hide()

    button.IconPixelBorder = CreateFrame("Frame", nil, button.Visual, "BackdropTemplate")
    button.IconPixelBorder:SetPoint("TOPLEFT", button.Icon, "TOPLEFT", -1, 1)
    button.IconPixelBorder:SetPoint("BOTTOMRIGHT", button.Icon, "BOTTOMRIGHT", 1, -1)
    button.IconPixelBorder:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    button.IconPixelBorder:SetBackdropBorderColor(0, 0, 0, 0)

    button.IconGlowPulse = button:CreateAnimationGroup()
    button.IconGlowPulse:SetLooping("BOUNCE")
    button.IconGlowPulse.FadeOut = button.IconGlowPulse:CreateAnimation("Alpha")
    button.IconGlowPulse.FadeOut:SetOrder(1)
    button.IconGlowPulse.FadeOut:SetFromAlpha(0.65)
    button.IconGlowPulse.FadeOut:SetToAlpha(0.20)
    button.IconGlowPulse.FadeOut:SetDuration(0.65)
    button.IconGlowPulse.FadeIn = button.IconGlowPulse:CreateAnimation("Alpha")
    button.IconGlowPulse.FadeIn:SetOrder(2)
    button.IconGlowPulse.FadeIn:SetFromAlpha(0.20)
    button.IconGlowPulse.FadeIn:SetToAlpha(0.65)
    button.IconGlowPulse.FadeIn:SetDuration(0.65)

    button.RangeIndicator = button.Visual:CreateTexture(nil, "OVERLAY")
    button.RangeIndicator:SetPoint("TOPRIGHT", -2, -2)
    button.RangeIndicator:SetSize(8, 8)
    button.RangeIndicator:SetTexture("Interface\\Buttons\\WHITE8X8")

    button.Label = button.Visual:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.Label:SetPoint("BOTTOM", button.Visual, "BOTTOM", 0, 3)
    button.Label:SetJustifyH("CENTER")
    button.Label:SetShadowOffset(1, -1)

    button:SetScript("OnEnter", function(self)
        if not self.state then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.state.label)

        if self.state.unitName then
            GameTooltip:AddLine(self.state.unitName, 1, 1, 1)
        end

        if self.state.aura then
            GameTooltip:AddLine(self.state.aura.name, 0.35, 0.82, 1)
            if self.state.hasStealableAura and self.state.inRange then
                GameTooltip:AddLine("Spellsteal in range", 0.18, 0.95, 0.40)
            elseif self.state.hasStealableAura then
                GameTooltip:AddLine("Spellsteal out of range", 1, 0.72, 0.20)
            elseif self.state.exists and self.state.isEnemy then
                GameTooltip:AddLine("No stealable buff detected", 0.72, 0.72, 0.72)
            end
        elseif not self.state.spellKnown then
            GameTooltip:AddLine("Spellsteal unavailable", 1, 0.32, 0.32)
        elseif self.state.exists and self.state.isEnemy then
            GameTooltip:AddLine("No stealable buff detected", 0.72, 0.72, 0.72)
        else
            GameTooltip:AddLine("Unit unavailable", 0.72, 0.72, 0.72)
        end

        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    return button
end

function addon.UI.Buttons:UpdateButton(button, state)
    local colors = addon.Constants.COLORS
    local borderColor = colors.DISABLED
    local labelColor = colors.MUTED_LABEL
    local iconAlpha = 0.28
    local priorityColor = colors.PRIORITY
    local priorityGlowColor = colors.PRIORITY_GLOW

    button.state = state
    button.Label:SetText(state.label)

    if state.aura and state.aura.icon then
        button.Icon:SetTexture(state.aura.icon)
    else
        button.Icon:SetTexture(state.spellTexture)
    end

    button.Icon:SetDesaturated(not state.hasStealableAura)

    if state.spellKnown and state.hasStealableAura and state.inRange then
        borderColor = colors.ACTIVE
        labelColor = colors.LABEL
        iconAlpha = 1
    elseif state.spellKnown and state.hasStealableAura then
        borderColor = colors.OUT_OF_RANGE
        labelColor = colors.LABEL
        iconAlpha = 0.9
    elseif state.spellKnown and state.exists and state.isEnemy then
        borderColor = colors.INACTIVE
        iconAlpha = 0.42
    end

    button.Icon:SetAlpha(iconAlpha)
    button.Visual:SetBackdropBorderColor(unpack(borderColor))
    button.RangeIndicator:SetVertexColor(unpack(borderColor))
    button.Label:SetTextColor(unpack(labelColor))

    if state.isPriorityAura then
        button.IconPixelBorder:SetBackdropBorderColor(unpack(priorityColor))
        button.IconGlow:SetVertexColor(unpack(priorityGlowColor))
        button.IconGlow:Show()
        if not button.IconGlowPulse:IsPlaying() then
            button.IconGlowPulse:Play()
        end
    else
        button.IconPixelBorder:SetBackdropBorderColor(0, 0, 0, 0)
        if button.IconGlowPulse:IsPlaying() then
            button.IconGlowPulse:Stop()
        end
        button.IconGlow:Hide()
    end
end