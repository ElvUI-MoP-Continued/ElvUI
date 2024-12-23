﻿local E, L, V, P, G = unpack(select(2, ...))
local M = E:GetModule("Misc")

local pairs, unpack, ipairs, next, tonumber = pairs, unpack, ipairs, next, tonumber
local tinsert = table.insert

local ChatEdit_InsertLink = ChatEdit_InsertLink
local CreateFrame = CreateFrame
local CursorOnUpdate = CursorOnUpdate
local DressUpItemLink = DressUpItemLink
local GameTooltip_ShowCompareItem = GameTooltip_ShowCompareItem
local GetLootRollItemInfo = GetLootRollItemInfo
local GetLootRollItemLink = GetLootRollItemLink
local GetLootRollTimeLeft = GetLootRollTimeLeft
local IsControlKeyDown = IsControlKeyDown
local IsModifiedClick = IsModifiedClick
local IsShiftKeyDown = IsShiftKeyDown
local ResetCursor = ResetCursor
local RollOnLoot = RollOnLoot
local SetDesaturation = SetDesaturation
local ShowInspectCursor = ShowInspectCursor

local C_LootHistory_GetItem = C_LootHistory.GetItem
local C_LootHistory_GetPlayerInfo = C_LootHistory.GetPlayerInfo

local GREED, NEED, PASS = GREED, NEED, PASS
local ITEM_QUALITY_COLORS = ITEM_QUALITY_COLORS
local MAX_PLAYER_LEVEL = MAX_PLAYER_LEVEL
local ROLL_DISENCHANT = ROLL_DISENCHANT
local PRIEST_COLOR = RAID_CLASS_COLORS.PRIEST

local cancelled_rolls = {}
local cachedRolls = {}
local completedRolls = {}

local pos = "TOP"
local FRAME_WIDTH, FRAME_HEIGHT = 328, 28

M.RollBars = {}

local function ClickRoll(frame)
	RollOnLoot(frame.parent.rollID, frame.rolltype)
end

local function HideTip() GameTooltip:Hide() end
local function HideTip2() GameTooltip:Hide() ResetCursor() end

local rolltypes = {[1] = "need", [2] = "greed", [3] = "disenchant", [0] = "pass"}

local function SetTip(frame)
	local lineAdded

	GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
	GameTooltip:SetText(frame.tiptext)

	if frame:IsEnabled() == 0 then
		GameTooltip:AddLine("|cffff3333"..L["Can't Roll"])
	end

	local rolls = frame.parent.rolls[frame.rolltype]

	if rolls then
		for _, infoTable in next, rolls do
			local playerName, className = unpack(infoTable)
			local classColor = E:ClassColor(className) or PRIEST_COLOR

			if not lineAdded then
				GameTooltip:AddLine(' ')
				lineAdded = true
			end

			GameTooltip:AddLine(playerName, classColor.r, classColor.g, classColor.b)
		end
	end

	GameTooltip:Show()
end

local function SetItemTip(frame)
	if not frame.link then return end

	GameTooltip:SetOwner(frame, "ANCHOR_TOPLEFT")
	GameTooltip:SetHyperlink(frame.link)

	if IsShiftKeyDown() then
		GameTooltip_ShowCompareItem()
	end
	if IsModifiedClick("DRESSUP") then
		ShowInspectCursor()
	else
		ResetCursor()
	end
end

local function ItemOnUpdate(self)
	if IsShiftKeyDown() then
		GameTooltip_ShowCompareItem()
	end
	CursorOnUpdate(self)
end

local function LootClick(frame)
	if IsControlKeyDown() then
		DressUpItemLink(frame.link)
	elseif IsShiftKeyDown() then
		ChatEdit_InsertLink(frame.link)
	end
end

local function OnEvent(frame, _, rollID)
	cancelled_rolls[rollID] = true
	if frame.rollID ~= rollID then return end

	frame.rollID = nil
	frame.time = nil
	frame:Hide()
end

local function StatusUpdate(frame)
	if not frame.parent.rollID then return end

	local t = GetLootRollTimeLeft(frame.parent.rollID)
	local perc = t / frame.parent.time
	frame.spark:Point("CENTER", frame, "LEFT", perc * frame:GetWidth(), 0)
	frame:SetValue(t)

	if t > 1000000000 then
		frame:GetParent():Hide()
	end
end

local function CreateRollButton(parent, ntex, ptex, htex, rolltype, tiptext, ...)
	local f = CreateFrame('Button', format('$parent_%sButton', tiptext), parent)

	f:Point(...)
	f:Size(FRAME_HEIGHT - 4)
	f:SetNormalTexture(ntex)

	if ptex then f:SetPushedTexture(ptex) end

	f:SetHighlightTexture(htex)

	f.rolltype = rolltype
	f.parent = parent
	f.tiptext = tiptext

	f:SetScript("OnEnter", SetTip)
	f:SetScript("OnLeave", HideTip)
	f:SetScript("OnClick", ClickRoll)

	f:SetMotionScriptsWhileDisabled(true)

	-- local txt = f:CreateFontString(nil, "ARTWORK")

	-- txt:FontTemplate(nil, nil, "OUTLINE")
	-- txt:Point("CENTER", 0, rolltype == 2 and 1 or rolltype == 0 and -1 or 0)

	f.text = f:CreateFontString(nil, 'ARTWORK')
	f.text:FontTemplate(nil, nil, 'OUTLINE')
	f.text:SetPoint('BOTTOMRIGHT', 2, -2)

	return f, f.text
end

function M:CreateRollFrame()
	local frame = CreateFrame("Frame", nil, E.UIParent)
	frame:Size(FRAME_WIDTH, FRAME_HEIGHT)
	frame:SetTemplate()
	frame:SetScript("OnEvent", OnEvent)
	frame:SetFrameStrata("MEDIUM")
	frame:SetFrameLevel(10)
	frame:RegisterEvent("CANCEL_LOOT_ROLL")
	frame:Hide()

	local button = CreateFrame("Button", nil, frame)
	button:Point("RIGHT", frame, "LEFT", -(E.Spacing*3), 0)
	button:Size(FRAME_HEIGHT - (E.Border * 2))
	button:CreateBackdrop()
	button:SetScript("OnEnter", SetItemTip)
	button:SetScript("OnLeave", HideTip2)
	button:SetScript("OnUpdate", ItemOnUpdate)
	button:SetScript("OnClick", LootClick)
	frame.button = button

	button.icon = button:CreateTexture(nil, "OVERLAY")
	button.icon:SetAllPoints()
	button.icon:SetTexCoord(unpack(E.TexCoords))

	if E.private.general.ilvlDisplay then
		button.ilvl = button:CreateFontString(nil, 'OVERLAY')
		button.ilvl:SetPoint('BOTTOM', button, 'BOTTOM', 0, 0)
		button.ilvl:FontTemplate(nil, nil, 'OUTLINE')
	end

	local tfade = frame:CreateTexture(nil, "BORDER")
	tfade:Point("TOPLEFT", frame, "TOPLEFT", 4, 0)
	tfade:Point("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 0)
	tfade:SetTexture([[Interface\ChatFrame\ChatFrameBackground]])
	tfade:SetBlendMode("ADD")
	tfade:SetGradientAlpha("VERTICAL", 0.1, 0.1, 0.1, 0, 0.1, 0.1, 0.1, 0)

	local status = CreateFrame("StatusBar", nil, frame)
	status:SetInside()
	status:SetScript("OnUpdate", StatusUpdate)
	status:SetFrameLevel(status:GetFrameLevel() - 1)
	status:SetStatusBarTexture(E.media.normTex)
	E:RegisterStatusBar(status)
	status:SetStatusBarColor(0.8, 0.8, 0.8, 0.9)
	status.parent = frame
	frame.status = status

	status.bg = status:CreateTexture(nil, "BACKGROUND")
	status.bg:SetAlpha(0.1)
	status.bg:SetAllPoints()
	status.bg:SetDrawLayer("BACKGROUND", 2)
	local spark = frame:CreateTexture(nil, "OVERLAY")
	spark:Size(14, FRAME_HEIGHT)
	spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
	spark:SetBlendMode("ADD")
	status.spark = spark

	local need, needtext = CreateRollButton(frame, [[Interface\Buttons\UI-GroupLoot-Dice-Up]], [[Interface\Buttons\UI-GroupLoot-Dice-Highlight]], [[Interface\Buttons\UI-GroupLoot-Dice-Down]], 1, NEED, "LEFT", frame.button, "RIGHT", 5, -1)
	local greed, greedtext = CreateRollButton(frame, [[Interface\Buttons\UI-GroupLoot-Coin-Up]], [[Interface\Buttons\UI-GroupLoot-Coin-Highlight]], [[Interface\Buttons\UI-GroupLoot-Coin-Down]], 2, GREED, "LEFT", need, "RIGHT", 0, -1)
	local de, detext
	de, detext = CreateRollButton(frame, [[Interface\Buttons\UI-GroupLoot-DE-Up]], [[Interface\Buttons\UI-GroupLoot-DE-Highlight]], [[Interface\Buttons\UI-GroupLoot-DE-Down]], 3, ROLL_DISENCHANT, "LEFT", greed, "RIGHT", 0, -1)
	local pass, passtext = CreateRollButton(frame, [[Interface\Buttons\UI-GroupLoot-Pass-Up]], nil, [[Interface\Buttons\UI-GroupLoot-Pass-Down]], 0, PASS, "LEFT", de or greed, "RIGHT", 0, 2)
	frame.needbutt, frame.greedbutt, frame.disenchantbutt = need, greed, de
	frame.need, frame.greed, frame.pass, frame.disenchant = needtext, greedtext, passtext, detext

	local bind = frame:CreateFontString(nil, "ARTWORK")
	bind:Point("LEFT", pass, "RIGHT", 3, 1)
	bind:FontTemplate(nil, nil, "OUTLINE")
	frame.fsbind = bind

	local loot = frame:CreateFontString(nil, "ARTWORK")
	loot:FontTemplate(nil, nil, "OUTLINE")
	loot:Point("LEFT", bind, "RIGHT", 0, 0)
	loot:Point("RIGHT", frame, "RIGHT", -5, 0)
	loot:Size(200, 10)
	loot:SetJustifyH("LEFT")
	frame.fsloot = loot

	frame.rolls = {}

	return frame
end

local function GetFrame()
	for _, f in ipairs(M.RollBars) do
		if not f.rollID then
			return f
		end
	end

	local f = M:CreateRollFrame()
	if pos == "TOP" then
		f:Point("TOP", next(M.RollBars) and M.RollBars[#M.RollBars] or AlertFrameHolder, "BOTTOM", 0, -4)
	else
		f:Point("BOTTOM", next(M.RollBars) and M.RollBars[#M.RollBars] or AlertFrameHolder, "TOP", 0, 4)
	end

	tinsert(M.RollBars, f)

	return f
end

function M:START_LOOT_ROLL(_, rollID, time)
	if cancelled_rolls[rollID] then return end

	local link = GetLootRollItemLink(rollID)
	local texture, name, _, quality, bop, canNeed, canGreed, canDisenchant = GetLootRollItemInfo(rollID)
	local _, _, _, itemLevel, _, _, _, _, _, _, _, itemClassID, _, bindType = GetItemInfo(link)
	local color = ITEM_QUALITY_COLORS[quality]

	local f = GetFrame()

	wipe(f.rolls)

	f.rollID = rollID
	f.time = time
	for i in pairs(f.rolls) do f.rolls[i] = nil end
	f.need:SetText(0)
	f.greed:SetText(0)
	f.pass:SetText(0)
	f.disenchant:SetText(0)

	f.button.icon:SetTexture(texture)
	f.button.link = link

	if E.private.general.ilvlDisplay then
		f.button.ilvl:SetText(itemLevel)
	end

	if canNeed then f.needbutt:Enable() else f.needbutt:Disable() end
	if canGreed then f.greedbutt:Enable() else f.greedbutt:Disable() end
	if canDisenchant then f.disenchantbutt:Enable() else f.disenchantbutt:Disable() end

	SetDesaturation(f.needbutt:GetNormalTexture(), not canNeed)
	SetDesaturation(f.greedbutt:GetNormalTexture(), not canGreed)
	SetDesaturation(f.disenchantbutt:GetNormalTexture(), not canDisenchant)

	if canNeed then f.needbutt:SetAlpha(1) else f.needbutt:SetAlpha(0.2) end
	if canGreed then f.greedbutt:SetAlpha(1) else f.greedbutt:SetAlpha(0.2) end
	if canDisenchant then f.disenchantbutt:SetAlpha(1) else f.disenchantbutt:SetAlpha(0.2) end

	f.fsbind:SetText(bop and L["BoP"] or L["BoE"])
	f.fsbind:SetVertexColor(bop and 1 or 0.3, bop and 0.3 or 1, bop and 0.1 or 0.3)

	f.fsloot:SetText(name)
	f.status:SetStatusBarColor(color.r, color.g, color.b, 0.7)
	f.status.bg:SetTexture(color.r, color.g, color.b)

	f.status:SetMinMaxValues(0, time)
	f.status:SetValue(time)

	f:Point("CENTER", WorldFrame, "CENTER")
	f:Show()

	AlertFrame_FixAnchors()

	-- Add cached roll info, if any
	for rollID, rollTable in pairs(cachedRolls) do
		if f.rollID == rollID then -- rollID matches cached rollid
			for rollerName, rollerInfo in pairs(rollTable) do
				local rollType, class = rollerInfo[1], rollerInfo[2]
				if not f.rolls[rollType] then f.rolls[rollType] = {} end
				tinsert(f.rolls[rollType], { rollerName, class })
				f[rolltypes[rollType]]:SetText(tonumber(f[rolltypes[rollType]]:GetText()) + 1)
			end

			completedRolls[rollID] = true
			break
		end
	end

	if E.db.general.autoRoll and E.mylevel == MAX_PLAYER_LEVEL and quality == 2 and not bop then
		if canDisenchant then
			RollOnLoot(rollID, 3)
		else
			RollOnLoot(rollID, 2)
		end
	end
end

function M:LOOT_HISTORY_ROLL_CHANGED(_, itemIdx, playerIdx)
	local rollID = C_LootHistory_GetItem(itemIdx)
	local name, class, rollType = C_LootHistory_GetPlayerInfo(itemIdx, playerIdx)

	local rollIsHidden = true
	if name and rollType then
		for _, f in ipairs(M.RollBars) do
			if f.rollID == rollID then
				if not f.rolls[rollType] then f.rolls[rollType] = {} end
				--f.rolls[name] = {rollType, class}
				tinsert(f.rolls[rollType], { name, class })
				f[rolltypes[rollType]]:SetText(tonumber(f[rolltypes[rollType]]:GetText()) + 1)
				rollIsHidden = false
				break
			end
		end

		--History changed for a loot roll that hasn't popped up for the player yet, so cache it for later
		if rollIsHidden then
			cachedRolls[rollID] = cachedRolls[rollID] or {}
			if not cachedRolls[rollID][name] then
				cachedRolls[rollID][name] = {rollType, class}
			end
		end
	end
end

function M:LOOT_HISTORY_ROLL_COMPLETE()
	--Remove completed rolls from cache
	for rollID in pairs(completedRolls) do
		cachedRolls[rollID] = nil
		completedRolls[rollID] = nil
	end
end
M.LOOT_ROLLS_COMPLETE = M.LOOT_HISTORY_ROLL_COMPLETE

function M:LoadLootRoll()
	if not E.private.general.lootRoll then return end

	self:RegisterEvent("LOOT_HISTORY_ROLL_CHANGED")
	self:RegisterEvent("LOOT_HISTORY_ROLL_COMPLETE")
	self:RegisterEvent("START_LOOT_ROLL")
	self:RegisterEvent("LOOT_ROLLS_COMPLETE")

	UIParent:UnregisterEvent("START_LOOT_ROLL")
	UIParent:UnregisterEvent("CANCEL_LOOT_ROLL")
end