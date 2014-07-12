-----------------------------------------------------------------------------------------------
-- Fixup buggy Costumes UI events.
-----------------------------------------------------------------------------------------------
require "Apollo"
require "GameLib"

local CostumesFix = {}

function CostumesFix:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function CostumesFix:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		"Costumes"
	}
	Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end

-- Fixed up functions
function CostumesFix:OnCostumeSlotBtn(wndHandler, wndControl, eMouseButton, nPosX, nPosY, bDoubleClick)
	if wndHandler ~= wndControl then
		return false
	end

	if eMouseButton == GameLib.CodeEnumInputMouse.Right	then
		GameLib.SetCostumeItem(self.nCurrentCostume, wndControl:GetData(), -1)
		-- self:Reset() -- Triggered by the above action
	end
end

function CostumesFix:OnCostumeSlotDragDrop(wndHandler, wndControl, nX, nY, wndSource, strType, nValue)
	if wndHandler ~= wndControl then
		return false
	end

	GameLib.SetCostumeItem(self.nCurrentCostume, wndControl:GetData(), nValue)
	-- self:Reset() -- Triggered by the above action
end

function CostumesFix:OnRemoveSlotBtn(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return false
	end

	GameLib.SetCostumeItem(self.nCurrentCostume, wndControl:GetData(), -1)
	-- self:Reset() -- Triggered by the above action
end

function CostumesFix:OnLoad()
	local tCostumes = Apollo.GetAddon("Costumes")
	if tCostumes ~= nil then
		tCostumes.OnCostumeSlotBtn = CostumesFix.OnCostumeSlotBtn
		tCostumes.OnCostumeSlotDragDrop = CostumesFix.OnCostumeSlotDragDrop
		tCostumes.OnRemoveSlotBtn = CostumesFix.OnRemoveSlotBtn
	end
end

local CostumesFixInstance = CostumesFix:new()
CostumesFixInstance:Init()