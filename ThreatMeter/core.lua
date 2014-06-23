-----------------------------------------------------------------------------------------------
-- Client Lua Script for ThreatMeter
-- @author daihenka
-----------------------------------------------------------------------------------------------
 
require "Apollo"
require "Window"
require "GameLib"
require "GroupLib"
require "Sound"
require "MatchingGame"
 

-----------------------------------------------------------------------------------------------
-- ThreatMeter Module Definitions
-----------------------------------------------------------------------------------------------
local ADDON_NAME     = "ThreatMeter"
local CONFIG_VERSION = 1

local ThreatMeter = Apollo.GetAddon(ADDON_NAME)
local DaiUtil     = Apollo.GetPackage("DaiUtil-1.0").tPackage

-----------------------------------------------------------------------------------------------
-- Constants and Local Variables
-----------------------------------------------------------------------------------------------
local setmetatable, select, unpack, pairs, ipairs = setmetatable, select, unpack, pairs, ipairs
local ostime = os.time
local tremove, tinsert, tsort = table.remove, table.insert, table.sort
local strformat = string.format

-- Obtained from GameLib.GetCurrentClassInnateAbilitySpell():GetId()
local ktTankStances = {
	[47881] = true, -- Engineer provocation mode
	[32596] = true, -- Warrior bulwalk stance
	[46074] = true, -- Stalker suit mode: evasive
}

local function InTankStance()
	local innateSpell = GameLib.GetCurrentClassInnateAbilitySpell()
	return (innateSpell and ktTankStances[innateSpell:GetId()])
end

-- Convert large numbers into compact variations
-- @param nArg the value to compact
-- @return (string) The compact version of the number
local function FormatBigNumber(nArg, nPrecision)
  if type(nArg) == "string" then
    nArg = tonumber(nArg)
  end
  
	nPrecision = nPrecision or 1
	
	-- Turns 99999 into 99k and 90000 into 90k
	if nArg < 1000 then
		return nArg
	elseif nArg < 1000000 then
		return string.format("%."..nPrecision.."fk", nArg/1000)
	elseif nArg < 1000000000 then
		return string.format("%."..nPrecision.."fm", nArg/1000000)
	else
		return string.format("%."..nPrecision.."fg", nArg/1000000000)
	end
end


-----------------------------------------------------------------------------------------------
-- Core Addon Functions
-----------------------------------------------------------------------------------------------
function ThreatMeter:OnInitialize()
  -- slash commands
  Apollo.RegisterSlashCommand("threat",      "OnSlashCmd", self)
  Apollo.RegisterSlashCommand("threatmeter", "OnSlashCmd", self)
  
  -- Register handlers for events
  Apollo.RegisterEventHandler("TargetedByUnit",           "OnTargetedByUnit",           self)
  Apollo.RegisterEventHandler("UnTargetedByUnit",         "OnUntargetedByUnit",         self)
  Apollo.RegisterEventHandler("TargetThreatListUpdated",  "OnTargetThreatListUpdated",  self)
  Apollo.RegisterEventHandler("UnitEnteredCombat",        "OnUnitEnteredCombat",        self)
  
  self.tItems                = {}
  self.tDisplayOrder         = {}
  self.bInCombat             = false
  self.tOverallThreat        = {}
  self.tThreatStore          = {}
  self.tThreatStoreTime      = {}
  self.tThreatPerSecond      = {}
  self.tGroupData            = {}
  self.LastMobId             = nil
  self.fLastThreatPct        = 0
  
  self.wndMain    = self:CreateMainWindow()
  self.wndWarning = self:CreateWarningWindow()
  self.wndItemList = self.wndMain:FindChild("ItemList")
  
  Apollo.LoadSprites("ColorPickerSprites.xml", "ColorPickerSprites")
end

function ThreatMeter:OnEnable()
  self.bInCombat = GameLib.GetPlayerUnit():IsInCombat()
end

function ThreatMeter:OnConfigure()
	self:ShowOptionsWindow()
end

-----------------------------------------------------------------------------------------------
-- ThreatMeter Settings
-----------------------------------------------------------------------------------------------
--- Addon save configuration event handler
-- @param eLevel addon save level
-- @return table with configuration data to save
function ThreatMeter:OnSaveSettings(eLevel)
  if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then
    return
  end
	
  local tData = DaiUtil.TableCopy(self.db)
  tData.Version = CONFIG_VERSION
  tData.tAnchorOffsets = {self.wndMain:GetAnchorOffsets()}
  
  DaiUtil.SerializeColors(tData)
  
  return tData
end



--- Addon restore configuration event handler
-- @param eLevel addon save level
-- @param tData saved addon configuration data
function ThreatMeter:OnRestoreSettings(eLevel, tData)
  if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then
    return
  end
  
  if (tData.Version or 0) < CONFIG_VERSION then
    -- discard old versions of the config as they are incompatible
    return
  end
  
  DaiUtil.DeserializeColors(tData)

  if type(tData.tAnchorOffsets) == "table" and #tData.tAnchorOffsets == 4 then
    self.wndMain:SetAnchorOffsets(unpack(tData.tAnchorOffsets))
    tData.tAnchorOffsets = nil
  end

  -- merge the settings with the defaults
  DaiUtil.TableMerge(self.db, tData)
end


-----------------------------------------------------------------------------------------------
-- ThreatMeter Slash Commands
-----------------------------------------------------------------------------------------------
--- General slash command handler
-- @param cmd
-- @param args
function ThreatMeter:OnSlashCmd(cmd, args)
  if args:lower() == "options" then
    self:ShowOptionsWindow()
  else
		self.wndMain:Show(true) -- show the window
	end
end


-----------------------------------------------------------------------------------------------
-- ThreatMeter Visibility
-----------------------------------------------------------------------------------------------

function ThreatMeter:OnClose( wndHandler, wndControl, eMouseButton )
	self.wndMain:Show(false)
end

function ThreatMeter:UpdateVisibility()
  local bShow = self:ShouldShow()
  if not bShow then
    self:Warn(false)
  end
  
  self.wndMain:Show(bShow)
end

function ThreatMeter:ShouldShow()
  if self.db.bHideWhenNotInCombat and not self.bInCombat then 
    return false 
  end

  local bInGroup = GroupLib.InGroup() and GroupLib.GetGroupMaxSize() <= 5
  local bInRaid  = GroupLib.InGroup() and GroupLib.GetGroupMaxSize() > 5
  local bHasPet  = #GameLib.GetPlayerPets() > 0

  local bShow = (self.db.bShowWhenHavePet and bHasPet) or
                (self.db.bShowWhenInGroup and bInGroup) or
                (self.db.bShowWhenInRaid and bInRaid) or
                (self.db.bShowWhenAlone and not bInGroup and not bInRaid and not bHasPet)
				
	-- check if we are in instanced PvP
	if self.db.bHideWhenInPvP and MatchingGame.IsInPVPGame() then 
    bShow = false 
  end
  
	return bShow
end

-----------------------------------------------------------------------------------------------
-- ThreatMeter Warnings
-----------------------------------------------------------------------------------------------

function ThreatMeter:Warn(bShow)
  if bShow then
    if self.db.bWarningUseSound then
      Sound.Play(self.db.nWarningSoundId)
    end
    if self.db.bWarningUseMessage then
      self.wndWarning:Show(bShow)
    end  
  else
    self.wndWarning:Show(bShow)
  end
end

-- Determines if there is a need to show the high threat warning.
-- Show warning when the player breach the warning threshold and
-- the player is not the only one of the threat table.
-- Also check if player is in a tank stance and if the disable tank
-- warning is on.
function ThreatMeter:UpdateWarningStatus(nMyThreat, nTopThreat)
	local fMyThreatPct = nMyThreat / nTopThreat * 100
  
	if (fMyThreatPct < self.db.fWarningThreshold) or (self.db.bWarningTankDisable and InTankStance()) then
    self:Warn(false)
	elseif self.fLastThreatPct < self.db.fWarningThreshold and self:ShouldShow() and #self.tItems > 1 then
    self:Warn(true)
	end
	self.fLastThreatPct = fMyThreatPct
end

-----------------------------------------------------------------------------------------------
-- ThreatMeter Event Handlers
-----------------------------------------------------------------------------------------------

function ThreatMeter:OnTargetedByUnit()
  self:UpdateVisibility()
end

function ThreatMeter:OnUntargetedByUnit()
  self:UpdateVisibility()
end


function ThreatMeter:AddThreatUnit(tStore, unit, nThreatAmount)
	local color = self.db.crNotPlayer
	if unit and unit:GetId() and unit:IsValid() and not unit:IsDead() then
		local strName = unit:GetName()

		if GameLib.GetPlayerUnit() == unit then
			color = self.db.crPlayer
		elseif self.tGroupData[unit:GetId()] ~= nil then
			color = self.db.crGroupMember
		end
		
		if unit:GetUnitOwner() ~= nil then
			if GameLib.GetPlayerUnit() == unit:GetUnitOwner() then
				color = self.db.crPlayerPet
			end
      strName = strformat("%s (%s)", strName, unit:GetUnitOwner():GetName())
		end
		local data = { nId=unit:GetId(), luaUnit=unit, strName=strName, nAmount=nThreatAmount, cr=color }
		tinsert(tStore, data)
		return data
	end
end


function ThreatMeter:ValidateTargetThreatStore()
  local nTargetId = self:GetTargetId()
  if nTargetId ~= nil and nTargetId ~= self.nLastMobId then
    -- reset data store
    self.tThreatStore     = {}
    self.tThreatStoreTime = {}
    self.nLastMobId        = nTargetId
    self.fLastThreatPct    = 0
  end
end

function ThreatMeter:OnTargetThreatListUpdated(...)
	if select(1, ...) ~= nil then
		self:ValidateTargetThreatStore()

		local nTopThreat = select(2, ...)
		self:UpdateVisibility()
		self:UpdateGroupData()
		
		-- update threat data store
		local tThreat = {}
		for i=1, select('#', ...), 2 do
			local unitData = self:AddThreatUnit(tThreat, select(i, ...), select(i+1, ...))
			
			if unitData and unitData.luaUnit == GameLib.GetPlayerUnit() then
				self:UpdateWarningStatus(unitData.nAmount, nTopThreat)
			end
		end
		
		tinsert(self.tThreatStore, tThreat)
		tinsert(self.tThreatStoreTime, ostime())
		
		self:UpdateTPS()
		self:UpdateDisplay(tThreat)
	else
		self.wndMain:Show(false)
    self:Warn(false)
	end
end

function ThreatMeter:UpdateGroupData()
	self.tGroupData = {}
	for idx = 1, GroupLib.GetGroupMaxSize() do
		local tMember = GroupLib.GetUnitForGroupMember(idx)
		if tMember == nil then 
      break
    end
		self.tGroupData[tMember:GetId()] = true
	end
end

function ThreatMeter:UpdateTPS()
	local nStartTime = ostime() - self.db.nTPSWindow
	while self.tThreatStoreTime[2] and nStartTime > self.tThreatStoreTime[2] do
		self.tThreatStore[1] = nil
		tremove(self.tThreatStore, 1)
		tremove(self.tThreatStoreTime, 1)
	end
	
	local nDataSize = #self.tThreatStoreTime
	if nDataSize == 0 or nStartTime <= self.tThreatStoreTime[1] then
		-- we don't have enough data
		self.tThreatPerSecond = nil
		return
	end
	
	self.tThreatPerSecond = {}
	if nDataSize == 1 then
		for i = 1, #self.tThreatStore[1] do
			self.tThreatPerSecond[self.tThreatStore[1][i].nId] = 0
		end
		return
	end
	
	for i = 1, #self.tThreatStore[nDataSize] do
		local idx = self.tThreatStore[nDataSize][i].nId
		
		local nBaseThreat = self:GetThreatAmount(self.tThreatStore[1], idx)
		local nSecondThreat = self:GetThreatAmount(self.tThreatStore[2], idx)
		local nFinalThreat = self:GetThreatAmount(self.tThreatStore[nDataSize], idx)
		
		if nBaseThreat and nSecondThreat and nFinalThreat then
			local fRatio = (nStartTime - self.tThreatStoreTime[1]) / (self.tThreatStoreTime[2] - self.tThreatStoreTime[1])
			local startThreat = (nSecondThreat - nBaseThreat) * fRatio + nBaseThreat
			self.tThreatPerSecond[idx] = (nFinalThreat - startThreat) / self.db.nTPSWindow
		else
			self.tThreatPerSecond[idx] = 0
		end		
	end
end

function ThreatMeter:GetThreatAmount(t, nId)
	for i,v in ipairs(t) do
		if v.nId == nId then
			return v.nAmount
		end
	end
	return 0
end

function ThreatMeter:OnUnitEnteredCombat(unit, bInCombat)
	if unit and unit:IsThePlayer() then
    self.bInCombat = bInCombat
	end
end

-- Get the target's name
function ThreatMeter:GetTargetName()
	local unitTarget = GameLib.GetTargetUnit()
	if unitTarget then
		return unitTarget:GetName()
	end
	return "Unknown"
end

-- Get the target's id
function ThreatMeter:GetTargetId()
	local unitTarget = GameLib.GetTargetUnit()
	if unitTarget then
		return unitTarget:GetId()
	end
	return nil
end


function ThreatMeter:UpdateDisplay(tThreatMeter)
	if self.wndMain:IsVisible() then
		self:ResetDisplayOrder()
		self.wndMain:FindChild("TitleText"):SetText(self:GetTargetName())
		self:DisplayList(tThreatMeter)
	end
end

function ThreatMeter:CompareDisplay(index, text)
	if not self.tDisplayOrder[index] or (self.tDisplayOrder[index] and self.tDisplayOrder[index] ~= text) then
		self.tDisplayOrder[index] = text
		return true
	end
end

function ThreatMeter:DisplayList(tListing)
	tsort(tListing, function(a,b) return a.nAmount > b.nAmount end)
	
	local bArrange = false
	for k,tUnitData in ipairs(tListing) do
		if not self.tItems[k] then
			self:AddItem(k)
		end
		local wnd = self.tItems[k]
		if self:CompareDisplay(k, tUnitData.strName) then
			wnd.nameText:SetText(tUnitData.strName)
			wnd.progressBar:SetBarColor(tUnitData.cr)
			bArrange = true
		end

		-- tps value
		local strTps = "??"
		if self.tThreatPerSecond then
			strTps = strformat("%.2f", self.tThreatPerSecond[tUnitData.nId])
		end
		
		wnd.amountText:SetText(strformat("%s (%.0f)", FormatBigNumber(tUnitData.nAmount, self.db.bThreatTotalPrecision and 3 or 1), tUnitData.nAmount / tListing[1].nAmount * 100))
		wnd.tpsText:SetText(strTps)
		wnd.progressBar:SetProgress(tUnitData.nAmount / tListing[1].nAmount)		
	end
	
	-- trim
	if #self.tItems > #tListing then
		for i=#tListing+1, #self.tItems do
			self.tItems[i].wnd:Destroy()
			self.tItems[i] = nil
		end
	end
	
	-- rearrange
	if bArrange then
		self.wndItemList:ArrangeChildrenVert()
	end
end

function ThreatMeter:ResetDisplayOrder()
	self.tDisplayOrder = {}
end


function ThreatMeter:AddItem(i)
  -- load the window item for the list item
  local wnd = self:CreateItemWindow()

  -- keep track of the window item created
  local tItem = {}
  tItem.wnd          = wnd
  tItem.progressBar  = wnd:FindChild("ProgressBar")
  tItem.nameText     = wnd:FindChild("NameText")
  tItem.amountText   = wnd:FindChild("AmountText")
  tItem.tpsText      = wnd:FindChild("TpsText")

  tItem.progressBar:SetMax(1)
  tItem.progressBar:SetProgress(0)
  tItem.nameText:SetTextColor(self.db.crNormalText)

  self.tItems[i] = tItem

  wnd:SetData(i)

  return tItem
end

function ThreatMeter:DestroyItemList()
	for idx,wnd in ipairs(self.tItems) do
		wnd:Destroy()
	end
	
	self.tItems = {}
end