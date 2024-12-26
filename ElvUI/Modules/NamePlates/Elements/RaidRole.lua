local E, L, V, P, G = unpack(select(2, ...))
local NP = E:GetModule("NamePlates")

function NP:Update_RaidRole(frame)
	if not frame.UnitType == "FRIENDLY_PLAYER" then return end

	local db = self.db.units[frame.UnitType].raidRole
	local icon = frame.RaidRole

	if self.Healers[frame.UnitName] or self.Tanks[frame.UnitName] then
		icon:ClearAllPoints()
		if frame.Health:IsShown() then
			icon:SetPoint("RIGHT", frame.Health, "LEFT", -6, 0)
		else
			icon:SetPoint("BOTTOM", frame.Name, "TOP", 0, 3)
		end

		if self.Healers[frame.UnitName] then
			icon:SetTexture(E.Media.Textures.Healer)
			icon:SetShown(db.enable and db.markHealers)
		elseif self.Tanks[frame.UnitName] then
			icon:SetTexture(E.Media.Textures.Tank)
			icon:SetShown(db.enable and db.markTanks)
		end
	else
		icon:Hide()
	end
end

function NP:Construct_RaidRole(frame)
	local db = self.db.units["FRIENDLY_PLAYER"].raidRole
	local texture = frame:CreateTexture(nil, "OVERLAY")

	texture:SetPoint("RIGHT", frame.Health, "LEFT", -6, 0)
	texture:SetSize(db.size, db.size)

	texture:Hide()

	return texture
end