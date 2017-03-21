local bossGUID = nil
local BHB_BarAnimationDelay = 1 -- in seconds
local BHB_BarAnimationUpdateInterval = 0 -- in seconds
local BHB_BarAnimationPixelsPerSecond = 200

function BHB_initOptionsFrame()
	-- Main options panel
	local panel = CreateFrame("Frame", "BHB_optionsPanel")
	panel.name = "BossHealthBar"

	-- Details panel
	local text = panel:CreateFontString("BHB_titleText", "ARTWORK", "GameFontNormalLarge")
	text:SetText("BossHealthBar Options")
	text:SetPoint("TOPLEFT", 20, -20)

	-- Pixels per second settings
	local ppsPanel = CreateFrame("Frame", "BHB_ppsPanel", panel)
	ppsPanel:SetPoint("TOPLEFT", panel, 40, -50)
	ppsPanel:SetSize(500, 200)

	local ppsTitle = ppsPanel:CreateFontString("BHB_ppsTitleText", "ARTWORK", "GameFontNormal")
	ppsTitle:SetText("Animation Pixels Per Second (Yellow bar)")
	ppsTitle:SetPoint("TOPLEFT", ppsPanel)

	local ppsSlider = CreateFrame("Slider", "BHB_ppsSlider", ppsPanel, "OptionsSliderTemplate")
	ppsSlider.name = "Boss Health Bar"
	ppsSlider:SetWidth(200)
	ppsSlider:SetHeight(20)
	ppsSlider:SetOrientation('HORIZONTAL')
	ppsSlider:SetMinMaxValues(0, 1000)
	ppsSlider:SetValue(BHB_BarAnimationPixelsPerSecond)
	ppsSlider:SetPoint("TOPLEFT", ppsTitle, 0, -30)
	_G[ppsSlider:GetName() .. 'Low']:SetText('1')
	_G[ppsSlider:GetName() .. 'High']:SetText('1000')

	local ppsSliderBox = CreateFrame("EditBox", "BHB_ppsSliderBox", ppsPanel, "InputBoxTemplate")
	ppsSliderBox:SetAutoFocus(false)
	ppsSliderBox:SetMultiLine(false)
	ppsSliderBox:SetNumeric(true)
	ppsSliderBox:SetNumber(floor(ppsSlider:GetValue()))
	ppsSliderBox:SetSize(40, 20)
	ppsSliderBox:SetMaxLetters(4)
	ppsSliderBox:SetCursorPosition(0)
	ppsSliderBox:SetPoint("LEFT", ppsSlider, 220, 0)

	InterfaceOptions_AddCategory(panel)
end

function BHB_initBossHealthFrameYellow()
	BHB_BossHealthFrameYellow:RegisterEvent("PLAYER_TARGET_CHANGED")
	BHB_BossHealthBarYellow:SetMinMaxValues(0,100)
	BHB_BossHealthFrameYellow:Hide()
end

-- Initialize boss health frame
function BHB_initBossHealthFrame()
	BHB_BossHealthFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
	BHB_BossHealthFrame:RegisterEvent("UNIT_HEALTH_FREQUENT")
	BHB_BossHealthFrame:RegisterEvent("UNIT_MAXHEALTH")
	BHB_BossHealthFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	BHB_BossHealthFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
	BHB_BossHealthFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	BHB_BossHealthBar:SetMinMaxValues(0,100)
	BHB_BossHealthFrame:Hide()
end

function BHB_bossEventHandler(self, event, ...)
	if event == "PLAYER_TARGET_CHANGED" then
		if UnitExists("target") and UnitCanAttack("player","target") then
			local bosses = BHB_getBosses()
			if (next(bosses) ~= nil and bosses[UnitGUID("target")]) or next(bosses) == nil then -- boss exists, targeting a boss || no bosses
				BHB_updateBossHealthBars()
			end
		end
	elseif event == "UNIT_MAXHEALTH" or event == "UNIT_HEALTH_FREQUENT" then
		BHB_setBossHealth(BHB_getUpdatedBossHealth())
	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" and IsInGroup() then
		local timestamp, etype, hideCaster, sourceGUID, sourceName, sourceFlags, sourceFlags2, destGUID, destName, destFlags, destFlags2 = select(1, ...)
		if etype == "SPELL_DAMAGE" and destGUID == bossGUID then
			BHB_setBossHealth(BHB_getUpdatedBossHealth())
		end
	end
end

function BHB_updateBossHealthBars()
	bossGUID = UnitGUID("target")
	BHB_BossNameString:SetText(UnitName("target"))
	local tempBossHealth, tempBossHealthMax = BHB_getUpdatedBossHealth()
	BHB_setBossHealth(tempBossHealth, tempBossHealthMax)
	--if BHB_BossHealthBarYellow:GetValue() < BHB_BossHealthBar:GetValue() then
		BHB_BossHealthBarYellow:SetValue((tempBossHealth/tempBossHealthMax)*100)
	--end
end

function BHB_formatHealth(hp)
	if hp > 10000 then
		return math.floor(hp/1000) .. "k"
	end
	return hp
end

function BHB_formatPower(p)
	if p > 10000 then
		return math.floor(p/1000) .. "k"
	end
	return p
end

function BHB_getBosses()
	local bosses = {}
	for i=1,5 do
		if UnitExists("boss" .. i) then
			bosses[UnitGUID("boss" .. i)] = "boss" .. i
		end
	end
	return bosses
end

function BHB_setBossHealth(bossHp, bossHpMax)
	-- Ghetto checking for NaN
	if bossHp ~= bossHp or bossHpMax ~= bossHpMax then
		BHB_BossHealthFrame:Hide()
		BHB_BossHealthFrameYellow:Hide()
	elseif bossHp == 0 then
		BHB_BossHealthBar:SetValue(0)
		BHB_BossHealthString:SetText("0%")
		BHB_BossHealthFrame:Hide()
		BHB_BossHealthFrameYellow:Hide()
	else
		local healthPercent = (bossHp/bossHpMax)*100
		BHB_BossHealthBar:SetValue(healthPercent)
		BHB_BossHealthString:SetText(string.format("%i", healthPercent) .. "%")
		BHB_BossHealthFrame:Show()
		BHB_BossHealthFrameYellow:Show()
	end
end

function BHB_animateBossHealthBarYellow(self, elapsed)
	if BHB_BossHealthBar:GetValue() < BHB_BossHealthBarYellow:GetValue() then
		if self.TimeSinceLastUpdate < BHB_BarAnimationDelay then
			self.TimeSinceLastUpdate = self.TimeSinceLastUpdate + elapsed
		else
			BHB_BossHealthBarYellow:SetValue(
				BHB_BossHealthBarYellow:GetValue() - BHB_getScaledAnimationIncrement(
					BHB_BossHealthBar, elapsed
				)
			)
		end
	else
		self.TimeSinceLastUpdate = 0
	end
end

function BHB_getScaledAnimationIncrement(bar, elapsed)
	local minValue, maxValue = bar:GetMinMaxValues()
	local incPixelRatio = (elapsed * BHB_BarAnimationPixelsPerSecond) / bar:GetWidth()
	local scaledIncrement = incPixelRatio * maxValue
	return scaledIncrement
end

function BHB_getUpdatedBossHealth()
	if UnitExists("target") and UnitGUID("target") == bossGUID then
		return UnitHealth("target"), UnitHealthMax("target")
	end
	for k,_ in pairs(BHB_groupTargetingBoss()) do
		return UnitHealth(k .. "target"), UnitHealthMax(k .. "target")
	end
	return 0,0
end

function BHB_groupTargetingBoss()
	local playersTargeting = {}
	if IsInGroup() then
		for i=1,GetNumGroupMembers() do
			local c = "party" .. i
			if IsInRaid() then
				c = "raid" .. i
			end
			if BHB_isUnitTargetingBoss(c) then
				--table.insert(playersTargeting, c)
				playersTargeting[c] = true
			end
		end
	end
	return playersTargeting
end

function BHB_isGroupTargetingBoss()
	local target = false
	if IsInGroup() then
		for i=1,GetNumGroupMembers() do
			local c = "party" .. i
			if IsInRaid() then
				c = "raid" .. i
			end
			if BHB_isUnitTargetingBoss(c) then
				return true
			end
		end
	end
	return false
end

function BHB_isUnitTargetingBoss(unit)
	local unitTarget = unit .. "target"
	if UnitExists(unit) and UnitExists(unitTarget) and UnitGUID(unitTarget) == bossGUID then
		return true
	end
	return false
end
