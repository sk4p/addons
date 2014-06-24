-----------------------------------------------------------------------------------------------
-- Client Lua Script for Generalist
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "GameLib"
require "PlayerPathLib"
require "Item"
require "Money"
 
-----------------------------------------------------------------------------------------------
-- Generalist Module Definition
-----------------------------------------------------------------------------------------------
local Generalist = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------

-- local kcrSelectedText = ApolloColor.new("UI_BtnTextHoloPressedFlyby")
local kcrEnabledColor = ApolloColor.new("UI_BtnTextHoloNormal")
local kcrDisabledColor = ApolloColor.new("Disabled")

local altTooltip = "<P Font=\"CRB_InterfaceSmall\" TextColor=\"white\">%s</P>"

-- Costume slots, from the Character UI
--
local genSlotFromId = -- string name, then id, then button art
{
	[0]  = "ChestSlot",
	[1]  = "LegsSlot",
	[2]  = "HeadSlot",
	[3]  = "ShoulderSlot",
	[4]  = "FeetSlot",
	[5]  = "HandsSlot",
	[6]  = "ToolSlot",
	[7]  = "AttachmentSlot",
	[8]  = "SupportSlot",
	[10] = "ImplantSlot",
	[11] = "GadgetSlot",
	[15] = "ShieldSlot",	
	[16] = "WeaponSlot",				
}

local altClassToIcon =
{
	[GameLib.CodeEnumClass.Warrior] 		= "IconSprites:Icon_Windows_UI_CRB_Warrior",
	[GameLib.CodeEnumClass.Engineer] 		= "IconSprites:Icon_Windows_UI_CRB_Engineer",
	[GameLib.CodeEnumClass.Esper] 			= "IconSprites:Icon_Windows_UI_CRB_Esper",
	[GameLib.CodeEnumClass.Medic] 			= "IconSprites:Icon_Windows_UI_CRB_Medic",
	[GameLib.CodeEnumClass.Stalker] 		= "IconSprites:Icon_Windows_UI_CRB_Stalker",
	[GameLib.CodeEnumClass.Spellslinger] 	= "IconSprites:Icon_Windows_UI_CRB_Spellslinger",
}

local altClassToString =
{
	[GameLib.CodeEnumClass.Warrior] 		= "Warrior",
	[GameLib.CodeEnumClass.Engineer] 		= "Engineer",
	[GameLib.CodeEnumClass.Esper] 			= "Esper",
	[GameLib.CodeEnumClass.Medic] 			= "Medic",
	[GameLib.CodeEnumClass.Stalker] 		= "Stalker",
	[GameLib.CodeEnumClass.Spellslinger] 	= "Spellslinger",
}

local altPathToIcon = {
	[PlayerPathLib.PlayerPathType_Explorer] = "CRB_PlayerPathSprites:spr_Path_Explorer_Stretch",
	[PlayerPathLib.PlayerPathType_Soldier] = "CRB_PlayerPathSprites:spr_Path_Soldier_Stretch",
	[PlayerPathLib.PlayerPathType_Settler] = "CRB_PlayerPathSprites:spr_Path_Settler_Stretch",
	[PlayerPathLib.PlayerPathType_Scientist] = "CRB_PlayerPathSprites:spr_Path_Scientist_Stretch",
}
local altPathToString = {
	[PlayerPathLib.PlayerPathType_Explorer] = Apollo.GetString("PlayerPathExplorer"),
	[PlayerPathLib.PlayerPathType_Soldier] = Apollo.GetString("PlayerPathSoldier"),
	[PlayerPathLib.PlayerPathType_Settler] = Apollo.GetString("PlayerPathSettler"),
	[PlayerPathLib.PlayerPathType_Scientist] = Apollo.GetString("PlayerPathScientist"),
}

-- Lifted from Carbine's Inventory addon
local karCurrency =  	-- Alt currency table; re-indexing the enums so they don't have to be in sequence code-side (and removing cash)
{						-- To add a new currency just add an entry to the table; the UI will do the rest. Idx == 1 will be the default one shown
	{eType = Money.CodeEnumCurrencyType.Renown, 			strTitle = Apollo.GetString("CRB_Renown"), 				strDescription = Apollo.GetString("CRB_Renown_Desc")},
	{eType = Money.CodeEnumCurrencyType.ElderGems, 			strTitle = Apollo.GetString("CRB_Elder_Gems"), 			strDescription = Apollo.GetString("CRB_Elder_Gems_Desc")},
	{eType = Money.CodeEnumCurrencyType.Prestige, 			strTitle = Apollo.GetString("CRB_Prestige"), 			strDescription = Apollo.GetString("CRB_Prestige_Desc")},
	{eType = Money.CodeEnumCurrencyType.CraftingVouchers, 	strTitle = Apollo.GetString("CRB_Crafting_Vouchers"), 	strDescription = Apollo.GetString("CRB_Crafting_Voucher_Desc")}
}

local origItemToolTipForm = nil

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function Generalist:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here
	o.tItems = {} -- keep track of all the list items
	o.altData = {}
	-- o.wndSelectedListItem = nil -- keep track of which list item is currently selected
	
    return o
end

function Generalist:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- unit or package names depended on go here
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end

-----------------------------------------------------------------------------------------------
-- Generalist OnLoad
-----------------------------------------------------------------------------------------------
function Generalist:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("Generalist.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
	
	-- load our version info
	self.version = XmlDoc.CreateFromFile("toc.xml"):ToTable().Version
		
	-- init hook for tooltips
	local TT = Apollo.GetAddon("ToolTips")
	
	-- Preserve the original callbacks call
	local origCreateCallNames = TT.CreateCallNames
	
	-- And then create  new callbacks
	TT.CreateCallNames = function(luaCaller)
	
		-- First, call the orignal function to create the original callbacks
		origCreateCallNames(luaCaller)
		
		-- Save the original form
		origItemToolTipForm = Tooltip.GetItemTooltipForm
		
		-- Now create a new callback function for the item form
		Tooltip.GetItemTooltipForm = function(luaCaller, wndControl, item, bStuff, nCount)
			return self.ItemToolTip(luaCaller,wndControl,item,bStuff,nCount)
		end
		
	end
		
end

-----------------------------------------------------------------------------------------------
-- Generalist OnDocLoaded
-----------------------------------------------------------------------------------------------
function Generalist:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	
		-- Set up the main window
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "GeneralistForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end	
				
		-- item list window
		self.charList = self.wndMain:FindChild("CharList")
		
		-- keep the main window hidden for now
	    self.wndMain:Show(false, true)
	
		-- put the version number in the title bar
		self.wndMain:FindChild("Backing"):FindChild("Title"):SetText("Generalist v" .. self.version)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register the slash command
		Apollo.RegisterSlashCommand("gen", "OnGeneralistOn", self)
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		
		-- Update my info on logout
		Apollo.RegisterEventHandler("LogOut", "UpdateCurrentCharacter", self)
		
		-- Get ourselves into the Interface menu
		Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
		Apollo.RegisterEventHandler("ToggleGeneralist", "OnGeneralistOn", self)
		
		-- Update my inventory when I loot stuff
		Apollo.RegisterEventHandler("LootedItem", "GetCharInventory", self)
		Apollo.RegisterEventHandler("LootedMoney", "GetCharCash", self)
		
		-- Or when other "item" events happen
		Apollo.RegisterEventHandler("ItemAdded", "GetCharInventory", self)
		Apollo.RegisterEventHandler("ItemRemoved", "GetCharInventory", self)
		Apollo.RegisterEventHandler("ItemModified", "GetCharInventory", self)
		
		-- Update my level if I ding
		Apollo.RegisterEventHandler("PlayerLevelChange", "GetCharLevel", self)

		-- Register a timer until we can load player info
		self.timer = ApolloTimer.Create(2, true, "OnTimer", self)
		
		-- And register for the event of changing worlds so we can restart the timer
		Apollo.RegisterEventHandler("ChangeWorld", "OnChangeWorld", self)
		
	end
end

---------------------------------------------------------------------------------------------------
-- Timer function.  Used to keep trying to get the player unit on load
-- until GameLib has caught up and we have it.
---------------------------------------------------------------------------------------------------

function Generalist:OnTimer()

	-- Get the current character's name
	local unitPlayer = GameLib.GetPlayerUnit()

	-- Return if nil, because GameLib isn't ready.
	if unitPlayer == nil then
		return
	end
	
	-- If we didn't return, that means we got the player, and it's time to
	-- update their info and switch the timer off.
	--
	self.timer = nil
	self:UpdateCurrentCharacter()
	
end

---------------------------------------------------------------------------------------------------
-- Timer when we change worlds
---------------------------------------------------------------------------------------------------

function Generalist:OnChangeWorld()
	-- Restart the timer until we can load player info
	self.timer = ApolloTimer.Create(2, true, "OnTimer", self)	
end

---------------------------------------------------------------------------------------------------
-- Add us to interface menu
---------------------------------------------------------------------------------------------------

function Generalist:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "Generalist", 
		{"ToggleGeneralist", "", "ChatLogSprites:CombatLogSaveLogBtnNormal"})
end

-----------------------------------------------------------------------------------------------
-- Main slash command (or clicking us in the interface window)
-----------------------------------------------------------------------------------------------

-- on SlashCommand "/gen"
function Generalist:OnGeneralistOn()

	-- show the window
	self.wndMain:Invoke()

	-- populate the character list
	self:PopulateCharList()
		
end

-----------------------------------------------------------------------------------------------
-- Close window button functions.  These don't get simpler.
-----------------------------------------------------------------------------------------------

function Generalist:OnCancel()
	self.wndMain:Show(false,true)
end

function Generalist:OnDetailClose()
	-- Close the detail window
	self.wndDetail:Show(false,true)
end

function Generalist:OnSearchClose()
	-- Close the search window
	self.wndSearch:Show(false,true)
end

-----------------------------------------------------------------------------------------------
-- Populate list of characters
-----------------------------------------------------------------------------------------------

function Generalist:PopulateCharList()
	-- make sure the list is empty to start with
	self:DestroyCharList()
	
	-- next, add the current character to the table, and/or update its data
	self:UpdateCurrentCharacter()
	
	-- Get the current character's faction
	local factID = GameLib.GetPlayerUnit():GetFaction()
	
	-- Build list of characters of this faction
	local a = {}
    	for name in pairs(self.altData) do
		-- Only add characters of this faction to the list
		if self.altData[name].faction == factID then
			table.insert(a, name)
		end
	end
	
	-- Sort the list (alphabetically)
    table.sort(a)
	
	-- Now loop through the table of data and add all characters to the list item
	local totalCash = 0
	local totalLevel = 0
	local cc
	local name
	for counter, name in ipairs(a) do
		self:AddCharToList(name,counter)
		
		-- Add this character's money to the total
		if self.altData[name].cash ~= nil then
			totalCash = totalCash + self.altData[name].cash
		end
		
		-- And level
		totalLevel = totalLevel + self.altData[name].level
		
		cc = counter
	end
	
	-- Now, add the total cash entry
	cc = cc+1
	local wnd = Apollo.LoadForm(self.xmlDoc, "CharListEntry", self.charList, self)
	self.tItems[cc] = wnd
	wnd:FindChild("CharGold"):SetAmount(totalCash,true)
	wnd:FindChild("CharLevel"):SetText(totalLevel)
	wnd:FindChild("CharName"):SetText("[Total]")
	wnd:FindChild("CharClass"):Show(false)
	wnd:FindChild("CharPath"):Show(false)
				
	-- now all the item are added, call ArrangeChildrenVert to list out the list items vertically
	self.charList:ArrangeChildrenVert()
end

-- clear the item list
function Generalist:DestroyCharList()
	-- destroy all the wnd inside the list
	for idx,wnd in ipairs(self.tItems) do
		wnd:Destroy()
	end

	-- clear the list item array
	self.tItems = {}
	self.wndSelectedListItem = nil
end

-- 
-- Add alt's entry into the item list at a particular index
--
function Generalist:AddCharToList(name,i)
	-- load the window item for the list item
	local wnd = Apollo.LoadForm(self.xmlDoc, "CharListEntry", self.charList, self)
	
	-- keep track of the window item created
	self.tItems[i] = wnd
	
	local entry = self.altData[name]

	-- give it a piece of data to refer to 
	local wndItemText = wnd:FindChild("CharName")

	if wndItemText then -- make sure the text wnd exist
	
		-- Character's Name
		wndItemText:SetText(name) -- set the item wnd's text to alt's name
		--wndItemText:SetTextColor(kcrNormalText)
		
		-- Character's Level
		wnd:FindChild("CharLevel"):SetText(tostring(entry.level))
		
		-- Character's Class, as icon with tooltip
		wnd:FindChild("CharClass"):SetSprite(altClassToIcon[entry.class])
		if altClassToString[entry.class] ~= nil then
			wnd:FindChild("CharClass"):SetTooltip(string.format(altTooltip, altClassToString[entry.class]))
		end
			
		-- Character's Gold
		if entry.cash ~= nil then
			wnd:FindChild("CharGold"):SetAmount(entry.cash, true)
		else
			wnd:FindChild("CharGold"):Show(false)
		end
		
		-- Character's zone
		wnd:FindChild("CharZone"):SetText(entry.zone)
		
		-- Character's Path
		wnd:FindChild("CharPath"):SetSprite(altPathToIcon[entry.path])
		if altPathToString[entry.path] ~= nil then
			wnd:FindChild("CharPath"):SetTooltip(string.format(altTooltip, altPathToString[entry.path]))
		end
		
	end
	wnd:SetData(i)
end

-----------------------------------------------------------------------------------------------
-- Add the current character to the data structure and update their info
-----------------------------------------------------------------------------------------------
function Generalist:UpdateCurrentCharacter()

	-- Get the current character's name
	local unitPlayer = GameLib.GetPlayerUnit()

	if unitPlayer == nil then
		return
	end
	
	local myName = unitPlayer:GetName()
	
	-- Is there an entry for this player in the table?
	-- Add an empty entry if not.
	--
	if self.altData[myName] == nil then
		self.altData[myName] = {}
	end
	
	-- Now update the entry.  First, the basics.
	--
	self.altData[myName].faction = unitPlayer:GetFaction()
	self.altData[myName].class   = unitPlayer:GetClassId()
	self.altData[myName].path    = PlayerPathLib.GetPlayerPathType()
	self.altData[myName].zone    = GetCurrentZoneName()
	
	-- Update the character's level
	self:GetCharLevel()

	-- Update the character's cash
	self:GetCharCash()
	
	-- Update the character's list of unlocked AMPs.
	self:GetUnlockedAmps()
	
	-- Update the character's list of known tradeskills and schematics
	self:GetTradeskills()
	
	-- Update the character's equipped gear
	self:GetCharEquipment()
	
	-- Update the character's inventory
	self:GetCharInventory()
	
	-- Currency
	self:GetCharCurrency()
	
	
end

-----------------------------------------------------------------------------------------------
-- Functions for storing particular parts of the current character's data
-----------------------------------------------------------------------------------------------

function Generalist:GetCharLevel()

	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer == nil then return end
	local myName = unitPlayer:GetName()
	if self.altData[myName] == nil then self.altData[myName] = {} end
	self.altData[myName].level = unitPlayer:GetLevel()
		
end

function Generalist:GetCharCash()

	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer == nil then return end
	local myName = unitPlayer:GetName()
	if self.altData[myName] == nil then self.altData[myName] = {} end
	self.altData[myName].cash = GameLib.GetPlayerCurrency():GetAmount()
		
end

function Generalist:GetCharInventory()

	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer == nil then return end
	local myName = unitPlayer:GetName()
	if self.altData[myName] == nil then self.altData[myName] = {} end
	
	-- Hash for storing our complete inventory
	local myInv = {}
	
	-- Inventory hash format will be:
	-- {
	--   itemDbIdNumber = {name, count, location},
	--   anotherItemDbIdNumber = {name, count, location},
	-- }
	
	-- Get the big inventory hash, and loop through it.
	--
	local inv = GameLib.GetPlayerUnit():GetInventoryItems()
	for _,invBag in ipairs(inv) do
		-- Get the DB ID# of the item
		local id = invBag.itemInBag:GetItemId()
		local name = invBag.itemInBag:GetName()
		
		-- Have we encountered any of this item yet?
		if myInv[id] == nil then
			-- Nope, it's new.  Put it in the hash.
			myInv[id] = {}
			myInv[id].location = 1
			myInv[id].name = name
			myInv[id].count = invBag.itemInBag:GetStackCount()
		else
			-- Nope, we already saw another stack of it.  Add this one to it.
			myInv[id].count = myInv[id].count + invBag.itemInBag:GetStackCount()
		end	
	end -- of loop through inventory bags
	
	-- The tradeskill bag structure is much more complicated,
	-- having categories.
	--
	local supply = GameLib.GetPlayerUnit():GetSupplySatchelItems()
		for category,contents in pairs(supply) do
	
		-- Now loop through the items in the category.
		for _,thing in ipairs(contents) do
			-- The ID of the thing
			local id = thing.itemMaterial:GetItemId()
			local name = thing.itemMaterial:GetName()
						
			-- Now it's a similar song-and-dance to the bit where
			-- we looped through the inventory bags, but we use a 
			-- different variable.  
			
			-- Have we encountered any of this item yet?
			if myInv[id] == nil then
				-- Nope, it's new.  Put it in the hash.
				myInv[id] = {}
				myInv[id].location = 2
				myInv[id].name = name
				myInv[id].count = thing.nCount
			else
				-- Nope, we already saw another stack of it.  Add this one to it.
				myInv[id].count = myInv[id].count + thing.nCount
				myInv[id].location = bit32.bor(2,myInv[id].location)
			end	
		
		end -- of loop through things in a supply category
	
	end -- of loop through supply categories
	
	-- Now we have to get equipment as well!
	local eq = GameLib.GetPlayerUnit():GetEquippedItems()
	for key, itemEquipped in pairs(eq) do
		-- the item's ID
		local id = itemEquipped:GetItemId()
		local name = itemEquipped:GetName()
		
		if myInv[id] == nil then
			-- Nope, it's new.  Put it in the hash.
			myInv[id] = {}
			myInv[id].location = 4
			myInv[id].name = name
			myInv[id].count = 1
		else
			-- We already saw a stack of it.  Add this one to it.
			myInv[id].count = myInv[id].count + 1
			myInv[id].location = bit32.bor(4,myInv[id].location)
		end	
		
	end
	
	-- Finally, set our data
	self.altData[myName].inventory = myInv
	
end

function Generalist:GetCharCurrency()

	-- If possible, get my name.
	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer == nil then return end
	local myName = unitPlayer:GetName()
	if self.altData[myName] == nil then self.altData[myName] = {} end
	
	-- The table to store currency.
	local currency = {}

	-- Loop through currencies
	for idx = 1, #karCurrency do
		
		local tData = karCurrency[idx]
		local cType = tData.eType
		
		local theAmount = GameLib.GetPlayerCurrency(tData.eType):GetAmount()
		
		if theAmount ~= nil then
			currency[cType] = theAmount
		end

	end -- of loop through currencies
	
	self.altData[myName].currency = currency

end

function Generalist:GetUnlockedAmps()

	-- If possible, get my name.
	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer == nil then return end
	local myName = unitPlayer:GetName()
	if self.altData[myName] == nil then self.altData[myName] = {} end
	
	-- Get AMPs
	local amps = AbilityBook.GetEldanAugmentationData(AbilityBook.GetCurrentSpec()).tAugments
	if amps == nil then return end
	
	-- Loop through and save the ones which have an item which unlocks them.
	local unlocked = {}
	for _,ampEntry in ipairs(amps) do
		if ampEntry.nItemIdUnlock ~= 0 then
			if ampEntry.bUnlocked == true then
				table.insert(unlocked, ampEntry)
			end
		end
	end
	
	-- And store in the main table.
	self.altData[myName].unlocked = unlocked
end

function Generalist:GetTradeskills()

	-- If possible, get my name.
	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer == nil then return end
	local myName = unitPlayer:GetName()
	if self.altData[myName] == nil then self.altData[myName] = {} end
	
	-- Schematics table
	if self.altData[myName].schematics == nil then
		self.altData[myName].schematics = {}
	end

	-- Table of active/inactive skills
	local activityTable = {}
	
	-- Table of skill tiers
	local tierTable = {}
			
	-- Table of all my tradeskills
	local ts = {}
	
	-- Get my tradeskills and loop through them
	local tsk = CraftingLib:GetKnownTradeskills()
	
	-- Loop over the list
	for _,tSkill in ipairs(tsk) do
	
		local id = tSkill.eId	

		-- Add skill to table
		table.insert(ts, tSkill)
		
		-- Is the skill active?
		local isActive = CraftingLib.GetTradeskillInfo(id).bIsActive
		activityTable[id] = isActive
		
		-- Tier?
		tierTable[id] = CraftingLib.GetTradeskillInfo(id).eTier
			
		-- Is this skill still active?
		if isActive == true then
	
			-- Schematics for this skill
			local skillSchem = CraftingLib.GetSchematicList(id)
		
			-- Sort them by their name
			table.sort(skillSchem, function(a,b)
				if a.strName ~= nil and b.strName ~= nil then
					return a.strName < b.strName
				else
					return 0
				end
			end)
			
			-- Add list of schematics 
			self.altData[myName].schematics[id] = skillSchem
				
			
		else -- skill is not active
			if self.altData[myName].schematics[tSkill.eId] ~= nil then
			
			end

			
		end -- whether tradeskill is active
		
	end
	
	-- And store the list
	self.altData[myName].tradeSkills = ts
	
	-- Store activity table
	self.altData[myName].skillActive = activityTable
	
	-- Store tier table
	self.altData[myName].skillTier = tierTable
	
end

function Generalist:GetCharEquipment()

	-- If possible, get my name.
	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer == nil then return end
	local myName = unitPlayer:GetName()
	if self.altData[myName] == nil then self.altData[myName] = {} end

	local eq = unitPlayer:GetEquippedItems()
	local equipment = {}
	self.altData[myName].fullItem = {}
	for key, itemEquipped in pairs(eq) do
		equipment[itemEquipped:GetSlot()] = itemEquipped:GetItemId()
		self.altData[myName].fullItem[itemEquipped:GetSlot()] = itemEquipped
	end 
	self.altData[myName].equipment = equipment
end

-----------------------------------------------------------------------------------------------
-- Generate a Chat Link
-----------------------------------------------------------------------------------------------
function Generalist:OnGenerateItemLink(wndHandler,wndControl)
    -- make sure the wndControl is valid
    if wndHandler ~= wndControl then
        return
    end

	local tItem
	
	if wndHandler:GetData() ~= nil then
		tItem = Item.GetDataFromId(wndHandler:GetData())
	end
	
	-- the item in question is now "tItem", and all we have to do is fire the event
	Event_FireGenericEvent("ItemLink", tItem)
	
end

-----------------------------------------------------------------------------------------------
-- Activating the Detail window
-----------------------------------------------------------------------------------------------
function Generalist:OnCharacterSelected(wndHandler, wndControl)
    -- make sure the wndControl is valid
    if wndHandler ~= wndControl then
        return
    end
  
	-- But is the search window open?
	if self.wndSearch ~= nil and self.wndSearch:IsShown() then
		return
	end
	
    -- Who was picked?
	local wndItemText = wndControl:FindChild("CharName")
	local charName = wndItemText:GetText()
	
	-- If we picked the empty one (total cash row), bail out
	if charName == "[Total]" then
		return
	end

	-- Set up everything in the detail window
	self:PopulateDetailWindow(charName)

	-- And now display the window
	self.wndDetail:Invoke()
	
	-- Flag that the detail window is open by setting detailOpen to the char
	self.detailOpen = charName

end

-----------------------------------------------------------------------------------------------
-- Populating the Detail window
-----------------------------------------------------------------------------------------------
function Generalist:PopulateDetailWindow(charName)

	-- Set up the details window
	if self.wndDetail == nil then
		self.wndDetail = Apollo.LoadForm(self.xmlDoc, "DetailForm", self.wndMain, self)
	end
	
	if self.wndDetail == nil then
		Apollo.AddAddonErrorText(self, "Could not load the details window for some reason.")
		return
	end
	self.wndDetail:Show(false, true)
	
	-- Its panes
	self.wndAmps = self.wndDetail:FindChild("AmpTrades")
	self.wndEquip = self.wndDetail:FindChild("Equipment")
	
	-- The entry for the chosen character
	local entry = self.altData[charName]

	-- Set title to the character's name
	self.wndDetail:FindChild("Backing"):FindChild("Title"):SetText(charName)
	
	-- Character's Level
	self.wndDetail:FindChild("PlayerLevel"):SetText("Level " .. tostring(entry.level))
			
	-- Character's Class, as icon with tooltip
	self.wndDetail:FindChild("PlayerClass"):SetSprite(altClassToIcon[entry.class])
	if altClassToString[entry.class] ~= nil then
		self.wndDetail:FindChild("PlayerClass"):SetTooltip(string.format(altTooltip, altClassToString[entry.class]))
	end
			
	-- Character's Gold
	if entry.cash ~= nil then
		self.wndDetail:FindChild("PlayerGold"):SetAmount(entry.cash, true)
	else
		self.wndDetail:FindChild("PlayerGold"):Show(false)
	end
		
	-- Character's Path
	self.wndDetail:FindChild("PlayerPath"):SetSprite(altPathToIcon[entry.path])
	if altPathToString[entry.path] ~= nil then
		self.wndDetail:FindChild("PlayerPath"):SetTooltip(string.format(altTooltip, altPathToString[entry.path]))
	end
	
	-- Tab set
	local tabSet = self.wndDetail:FindChild("DetailTabs")
	
	local unlockText = ""
	
	-- Tradeskill Picker
	self.wndAmps:FindChild("TradeskillPickerList"):DestroyChildren()
	self.wndAmps:FindChild("AmpTradeButton"):AttachWindow(self.wndDetail:FindChild("TradeskillPickerListFrame"))
	
	-- First, sneak AMPs into this list
	local wndAmpEntry = Apollo.LoadForm(self.xmlDoc, "TradeskillBtn", 
		self.wndAmps:FindChild("TradeskillPickerList"), self)
	wndAmpEntry:SetData('amps')
	wndAmpEntry:SetText('AMPs Unlocked')
	
	-- Next, sneak currencies in
	local wndCurrency = Apollo.LoadForm(self.xmlDoc, "TradeskillBtn", 
		self.wndAmps:FindChild("TradeskillPickerList"), self)
	wndCurrency:SetData('currency')
	wndCurrency:SetText('Currencies')	
	
	-- Finally, do the tradeskills
	if entry.tradeSkills ~= nil and table.getn(entry.tradeSkills) > 0 then
		for i,skill in ipairs (entry.tradeSkills) do
			local wndCurr = Apollo.LoadForm(self.xmlDoc, "TradeskillBtn", 
				self.wndDetail:FindChild("TradeskillPickerList"), self)
				
			-- Set the button's data and text to the skill's eId/strName
			wndCurr:SetData(skill.eId)
			
			-- Append "Inactive" if the skill is not active
			local skillTitle = skill.strName
			if entry.skillActive[skill.eId] == false then
				wndCurr:SetText(skillTitle .. " (Inactive) ")
				wndCurr:SetTextColor(kcrDisabledColor)
			else
				wndCurr:SetText(skillTitle)
				wndCurr:SetTextColor(kcrEnabledColor)
			end
		end
	end
	
	self.wndAmps:FindChild("TradeskillPickerList"):ArrangeChildrenVert()
	--self.wndAmps:FindChild("TradeskillPickerList"):SetHeightToContentHeight()
	
	-- Character's equipment

	for key, id in pairs(entry.equipment) do
	
		local itemData = Item.GetDataFromId(id)
		
		if genSlotFromId[key] ~= nil then
		
			-- Name of the slot control
			local slot = self.wndEquip:FindChild(genSlotFromId[key])
			
			-- Set the icon
			slot:SetSprite(itemData:GetIcon())
			
			-- Set the data for the slot control so we can get links
			slot:SetData(id)
			
			-- Clear the tooltip
			slot:SetTooltipDoc(nil)
			
			-- And generate the tooltip
			Tooltip.GetItemTooltipForm(self, slot, itemData, {bPrimary = true, bSelling = false})
					
		end
		
	end -- of loop through equipment
	
end

---------------------------------------------------------------------------------------------------
-- Open the Search Form
---------------------------------------------------------------------------------------------------

function Generalist:OpenSearch( wndHandler, wndControl, eMouseButton )
	
	-- Is a detail window already open?  If so, no search.
	if self.wndDetail ~= nil and self.wndDetail:IsShown() then
		return
	end
		
	-- Set up the search window if it doesn't exist
	if self.wndSearch == nil then
		self.wndSearch = Apollo.LoadForm(self.xmlDoc, "SearchForm", self.wndMain, self)
	end
	
	-- But if it STILL doesn't exist, we need to complain.
	if self.wndSearch == nil then
		Apollo.AddAddonErrorText(self, "Could not load the search window for some reason.")
		return
	end
	
	-- Hidden for the moment
	self.wndSearch:Show(false, true)
	
	-- And now display the window
	self.wndSearch:Invoke()
	
end

-----------------------------------------------------------------------------------------------
-- Saving and loading our data
-----------------------------------------------------------------------------------------------
function Generalist:OnSave(eLevel)
    -- Only save at the Realm level
    if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Realm then
        return nil
    end

	-- Simply return the table we've been using!
	return self.altData
end

function Generalist:OnRestore(eLevel, tData)
    -- Only restore at the Realm level
    if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Realm then
        return nil
    end
	
	-- And load this into our data structure
	self.altData = tData
	
	-- Loop through each character and add empty tables
	-- for backwards compatibility.
	for charName in pairs(self.altData) do
		self:EnsureBackwardsCompatibility(charName)
	end
	
end

---------------------------------------------------------------------------------------------------
-- Ensure backwards compatibility by adding empty arrays.
---------------------------------------------------------------------------------------------------

function Generalist:EnsureBackwardsCompatibility(myName)

	-- Schematics table
	if self.altData[myName].schematics == nil then
		self.altData[myName].schematics = {}
	end
	
	-- Tradeskills table
	if self.altData[myName].tradeSkills == nil then
		self.altData[myName].tradeSkills = {}
	end
	
	-- Table of skill active/not active
	if self.altData[myName].skillActive == nil then
		self.altData[myName].skillActive = {}
	end
	
	-- Table of skill tiers
	if self.altData[myName].skillTier == nil then
		self.altData[myName].skillTier = {}
	end
	
	-- Equipment
	if self.altData[myName].equipment == nil then
		self.altData[myName].equipment = {}
	end
	
	-- Inventory
	if self.altData[myName].inventory == nil then
		self.altData[myName].inventory = {}
	end
	
	-- Unlocked
	if self.altData[myName].inventory == nil then
		self.altData[myName].inventory = {}
	end
	
	-- Currency
	if self.altData[myName].currency == nil then
		self.altData[myName].currency = {}
	end
	
	-- Zone
	if self.altData[myName].zone == nil then
		self.altData[myName].zone = '(Unknown location)'
	end
	
end

---------------------------------------------------------------------------------------------------
-- TradeskillBtn Functions
---------------------------------------------------------------------------------------------------

function Generalist:OnAmpTradePicked( wndHandler, wndControl, eMouseButton )

	-- Close the popup menu
	self.wndAmps:FindChild("TradeskillPickerListFrame"):Show(false)
	
	-- Entry for the character in question
	local entry = self.altData[self.detailOpen]
	
	-- What skill did they pick?
	local pickedSkill = wndHandler:GetData()
	-- Print( "picked skill: " ..  pickedSkill )
	
	-- This is where we'll put the output, either AMPs or schematics.
	local recipeList = {}
	local recipeText = ""
	
	-- Change the text of the menu button itself to whatever they picked
	self.wndAmps:FindChild("AmpTradeButton"):SetText(wndHandler:GetText())
	
	-- Empty the recipe list item
	local recList = self.wndAmps:FindChild("RecipeList")
	recList:DestroyChildren()
	
	-- Did they want to see unlocked AMPs?
	if pickedSkill == 'amps' then

		if table.getn(entry.unlocked) > 0 then
		
			local unlocked = entry.unlocked

			-- Sort them
			table.sort(unlocked, function(a,b) 
				if a.strTitle ~= nil and b.strTitle ~= nil then
					return a.strTitle < b.strTitle
				else
					return 0
				end
			end)
			
			-- Now loop through
			for _,amp in ipairs(unlocked) do

				-- Create an entry as a child of the list container
				local wnd = Apollo.LoadForm(self.xmlDoc, "SchematicKnown", recList, self)
				wnd:FindChild("ItemName"):SetText(amp.strTitle)

				-- And the icon
				local itemData = Item.GetDataFromId(amp.nItemIdUnlock)
				local icon = wnd:FindChild("ItemIcon")
				icon:SetSprite(itemData:GetIcon())
				
				-- And clickability
				wnd:SetData(amp.nItemIdUnlock)
					
				-- And its tooltip
				icon:SetTooltipDoc(nil)
				Tooltip.GetItemTooltipForm(self, icon, itemData, {bPrimary = true, bSelling = false})
				
			end -- of loop through amps	
			
		else -- no amps unlocked
			local wnd = Apollo.LoadForm(self.xmlDoc, "NoSchematicKnown", recList, self)
			wnd:SetText("(No AMPs unlocked)")
		end
		
	elseif pickedSkill == 'currency' then -- currencies
	
		-- Loop through currencies
		for idx = 1, #karCurrency do
		
			local tData = karCurrency[idx]
			local cType = tData.eType
			
			-- Do we have a currency of this type?
			if entry.currency ~= nil and entry.currency[cType] ~= nil then
			
				-- Make a new item in the list
				local wnd = Apollo.LoadForm(self.xmlDoc, "AltCurrency", recList, self)
			
				-- Set this item to that type of currency
				wnd:FindChild("AltCurrencyAmount"):SetMoneySystem(tData.eType)
			
				-- Set its title accordingly
				wnd:FindChild("AltCurrencyName"):SetText(tData.strTitle)
			
				-- And set the correct value
				wnd:FindChild("AltCurrencyAmount"):SetAmount(entry.currency[cType], true)
			
				-- wnd:FindChild("PickerEntryBtn"):SetData(idx)
				-- wnd:FindChild("PickerEntryBtn"):SetCheck(idx == 1)
				-- wnd:FindChild("PickerEntryBtn"):SetTooltip(tData.strDescription)
				
			end -- if we have this type of currency
		
		end
	
	else -- schematics rather than amps
	
		-- get the schematics for the desired tradeskill
		local schematics

		if entry.schematics[pickedSkill] ~= nil then
			 schematics = entry.schematics[pickedSkill]
		end
	
		-- Any schematics?
		if schematics ~= nil and table.getn(schematics) > 0 then
		
			-- Sort them
			table.sort(schematics, function(a,b) return a.strName < b.strName end)
			
			-- Now loop through them
			for _,recipe in ipairs(schematics) do
				local sid = recipe.nSchematicId
				local name = recipe.strName
				local itemId = CraftingLib.GetSchematicInfo(sid).itemOutput:GetItemId()
	
				-- Create an entry as a child of the list container
				local wnd = Apollo.LoadForm(self.xmlDoc, "SchematicKnown", recList, self)
				wnd:FindChild("ItemName"):SetText(name)

				-- And the icon
				local itemData = Item.GetDataFromId(itemId)
				local icon = wnd:FindChild("ItemIcon")
				icon:SetSprite(itemData:GetIcon())
				
				-- And clickability
				wnd:SetData(itemId)
							
				-- Set color based on enabledness of skill
				if entry.skillActive[pickedSkill] == false then
					wnd:FindChild("ItemName"):SetTextColor(kcrDisabledColor)
				else
					wnd:FindChild("ItemName"):SetTextColor(kcrEnabledColor)
				end
					
				-- And its tooltip
				icon:SetTooltipDoc(nil)
				local compare = itemData:GetEquippedItemForItemType()
				Tooltip.GetItemTooltipForm(self, icon, itemData,
					{bPrimary = true, bSelling = false, itemCompare = compare})
			end -- of loop through schematics in this skill
		else -- there are no schematics in this skill
			-- Create an empty entry
			local wnd = Apollo.LoadForm(self.xmlDoc, "NoSchematicKnown", recList, self)
		end -- of what to do if there are schematics in this skill
	end -- of if amps/crafting block
	
	-- And now arrange them in the list
	recList:ArrangeChildrenVert()
	
end

---------------------------------------------------------------------------------------------------
-- The Search Function
---------------------------------------------------------------------------------------------------

function Generalist:GeneralistSearchSubmitted( wndHandler, wndControl, eMouseButton )

	-- Okay, this is gross.
	-- First, clear previous search results.
	--
	local resList = self.wndSearch:FindChild("ResultList")
	resList:DestroyChildren()
	
	-- Get the current character's faction
	local factID = GameLib.GetPlayerUnit():GetFaction()
	
	-- Build list of characters of this faction
	local a = {}
    for name in pairs(self.altData) do
		-- Only add characters of this faction to the list
		if self.altData[name].faction == factID then
			table.insert(a, name)
		end
	end
	
	-- Sort the list to make results a little saner to read.
	table.sort(a)
	
	-- Get the string we're searching for, and lowercase it.
	local needle = string.lower(self.wndSearch:FindChild("SearchField"):GetText())
	
	-- Now loop through all the characters of this faction.
	--
	for _,charName in ipairs(a) do
	
		-- The alt's inventory
		local theInv = self.altData[charName].inventory
		
		-- Loop through the items
		--
		for id, info in pairs(theInv) do
		
			if string.find(string.lower(info.name),needle) ~= nil then
			
				-- We found it!  Create an entry as a child of the result list.
				local wnd = Apollo.LoadForm(self.xmlDoc, "SearchResult", resList, self)
				wnd:FindChild("ItemChar"):SetText(charName)
				wnd:FindChild("ItemName"):SetText(info.name)
				wnd:FindChild("ItemCount"):SetText(info.count)
					
				-- And the location
				if info.location == nil then
					wnd:FindChild("ItemPlace"):SetText("(Unknown)")
				else
					local locs = {}
					if bit32.band(4, info.location) == 4 then table.insert(locs,"Equipped") end
					if bit32.band(1, info.location) == 1 then table.insert(locs,"Inventory") end
					if bit32.band(2, info.location) == 2 then table.insert(locs,"Tradeskill") end
					local places = table.concat(locs,", ")
					wnd:FindChild("ItemPlace"):SetText(places)
				end
				
				-- And the icon
				local itemData = Item.GetDataFromId(id)
				local icon = wnd:FindChild("ItemIcon")
				icon:SetSprite(itemData:GetIcon())
					
				-- Important!  Set the data of the object to contain item ID.
				wnd:SetData(id)
					
				-- And its tooltip
				icon:SetTooltipDoc(nil)
				Tooltip.GetItemTooltipForm(self, icon, itemData, {bPrimary = true, bSelling = false})
			
			end -- of what to do if we find a match
		
		end -- of loop through items in the alt's inventory
	
	end -- of loop through alts
	
	-- now all the item are added, call ArrangeChildrenVert to list out the list items vertically
	resList:ArrangeChildrenVert()

end

---------------------------------------------------------------------------------------------------
-- Tooltip Hook
---------------------------------------------------------------------------------------------------

function Generalist:ItemToolTip(wndControl, item, bStuff, nCount)
	local this = Apollo.GetAddon("Generalist")
	
	wndControl:SetTooltipDoc(nil)
	local wndTooltip, wndTooltipComp = origItemToolTipForm(self,wndControl,item,bStuff,nCount)
	
	-- Add Generalist info about who has this thing.
	this:AddTooltipInfo(wndControl, wndTooltip, item)
	
	return wndTooltip, wndTooltipComp
	
end

function Generalist:AddTooltipInfo(wndParent, wndTooltip, item)

	-- Make sure we actually have a tooltip to work with
	if wndTooltip == nil then return end
	
	local wndInv = Apollo.LoadForm(self.xmlDoc, "TooltipInventorySummary",
		wndTooltip:FindChild("Items"), self)
	local wndList = wndInv:FindChild("TooltipInventoryList")
		
	-- Now we loop through everyone's inventory to find matches.
	
	-- Get the current character's faction
	local factID = GameLib.GetPlayerUnit():GetFaction()
	
	-- Build list of characters of this faction
	local a = {}
    for name in pairs(self.altData) do
		-- Only add characters of this faction to the list
		if self.altData[name].faction == factID then
			table.insert(a, name)
		end
	end
	
	-- Sort the list to make results a little saner to read.
	table.sort(a)
	
	-- Get the item's ID
	local id = item:GetItemId()

	-- Count how many of the item we have across everyone
	local totalCount = 0
	
	-- And count how many alts had it.  If more than 1, report total.
	local totalAltsHave = 0
	
	-- Now loop through all the characters of this faction.
	--
	for _,charName in ipairs(a) do
	
		-- The alt's inventory
		local theInv = self.altData[charName].inventory
		
		-- Inventory might be nil (unlikely but possible)!
		-- But if the item'd ID	exists as a key, we've found it.
		if theInv[id] ~= nil then
		
			local invItem = Apollo.LoadForm(self.xmlDoc, "TooltipInventoryItem",
				wndList, self)
			local info = theInv[id]
			local itemString = charName .. ": " .. info.count
			
			-- And increase the number of alts who have, and the total.
			totalCount = totalCount + info.count
			totalAltsHave = totalAltsHave + 1
				
			-- And the location
			if info.location ~= nil then
				local locs = {}
				if bit32.band(4, info.location) == 4 then table.insert(locs,"Equipped") end
				if bit32.band(1, info.location) == 1 then table.insert(locs,"Inventory") end
				if bit32.band(2, info.location) == 2 then table.insert(locs,"Tradeskill") end
				local places = table.concat(locs,", ")
				itemString = itemString .. " (" .. places .. ")"
			end
			
			invItem:SetText("<T TextColor=\"UI_TextHoloBody\">" .. itemString .. "</T>")
			invItem:SetHeightToContentHeight()
			
		end -- of whether that alt has the item
		
	end -- of list through faction's alts	
	
	-- Did more than one alt have some?
	if totalAltsHave > 1 then
		local invItem = Apollo.LoadForm(self.xmlDoc, "TooltipInventoryItem",
			wndList, self)
		local itemString = "(Total: " .. totalCount .. ")"
		invItem:SetText("<T TextColor=\"UI_TextHoloBody\">" .. itemString .. "</T>")
		invItem:SetHeightToContentHeight()
	end
	
	-- Now is this item an AMP which someone might know?
	--
	--if string.find(item:GetItemTypeName()," AMP") ~= nil then
	if item:GetItemFamilyName() == 'AMP' then
		-- Loop through characters
		for _,charName in ipairs(a) do
			-- Loop through their amps
			local unlocked = self.altData[charName].unlocked
			for _,amp in ipairs(unlocked) do
				if amp.nItemIdUnlock == id then
					-- It's a match!
					local invItem = Apollo.LoadForm(self.xmlDoc,
						"TooltipInventoryItem", wndList, self)
					invItem:SetText("<T TextColor=\"UI_WindowTextRed\">Already unlocked by " .. charName .. "</T>")
					invItem:SetHeightToContentHeight()
				end -- whether they unlocked this one amp
			end -- loop through their amps	
		end -- loop through alts
	end -- if the tooltip is for an amp
	
	
	-- Now is this item a schematic which someone might know?
	--
	if item:GetItemFamilyName() == 'Schematic' then
	
		-- Get the name of the thing this schematic crafts
		local theSpell = item:GetActivateSpell()
		
		if theSpell ~= nil then
		
			local theName = theSpell:GetName()
			local theTier = theSpell:GetTradeskillRequirements().eTier
		
			-- Determine the skill associated with the schematic
			-- This is ugly and I would love a cleaner way to do it,
			-- but until I can get an API which tells me what the schematic's
			-- internal ID is from the pattern-item, this is likely 
			-- the best I can do.
			local theSkillName = theSpell:GetTradeskillRequirements().strName
		
			local theSkill = CraftingLib.CodeEnumTradeskill[theSkillName]
		
			-- Super gross hack, because of a flaw in the table, where skill #16 is
			-- named "Augmentor"
			if theSkillName == "Technologist" then theSkill = 16 end
		
			-- Now chop off the beginning of the spell's name.
			-- This is possibly the grossest bit.
			--
			local itemPos = string.find(theName, ": ")
			local itemCreated = ''
			
			-- If we found a colon, chop off everything up to and including it,
			-- and then any whitespace between the colon and name of the item.
			--
			if itemPos ~= nil then
				itemCreated = string.sub(theName, itemPos + 1)
				itemCreated = string.gsub(itemCreated, "^%s*", "")
			end
		
			-- Now if we got a name for this thing ...
			if itemCreated ~= '' then
			
				-- Print ("Found the item '" .. itemCreated .. "'")
				
				-- Loop through characters
				for _,charName in ipairs(a) do
		
					-- A few cleanups for sanity and backwards compatibility

					-- Their schematics
					local schematics = self.altData[charName].schematics[theSkill]
				
					-- Do they know any schematics of this skill?
					if schematics ~= nil then

						-- Did we find the item in this skill?
						local foundInSkill = 0
			
						-- Now loop through them
						for _,recipe in ipairs(schematics) do
							local name = recipe.strName
							--if theSkill == 16 then
							--	Print( "Checking '" .. name .. "' versus '" .. itemCreated .. "'" )
							--end
							if name == itemCreated then
								-- It's a match!
								foundInSkill = 1
								local invItem = Apollo.LoadForm(self.xmlDoc,
									"TooltipInventoryItem", wndList, self)
								invItem:SetText("<T TextColor=\"UI_WindowTextRed\">Already known by " .. charName .. "</T>")
								invItem:SetHeightToContentHeight()
							end -- whether they know this recipe
						end -- loop through recipes of this skill
					
						-- If we did not find it, AND the skill is active,
						-- we should see if this alt
						-- can learn the thing now or later.
						--
						if foundInSkill == 0 and 
							self.altData[charName].skillActive[theSkill] == true then
						
							-- Special backwards compatibility, for pre 0.5.1,
							-- to fill in tiers
							if self.altData[charName].skillTier[theSkill] == nil then
								self.altData[charName].skillTier[theSkill] = 1
							end
	
							-- Is the alt's tier in this skill equal to or greater than
							-- the item's tier?
							if self.altData[charName].skillTier[theSkill] >= theTier then
								local invItem = Apollo.LoadForm(self.xmlDoc,
									"TooltipInventoryItem", wndList, self)
								invItem:SetText("<T TextColor=\"green\">Can be learned by " .. charName .. "</T>")
								invItem:SetHeightToContentHeight()
							else
								local invItem = Apollo.LoadForm(self.xmlDoc,
									"TooltipInventoryItem", wndList, self)
								invItem:SetText("<T TextColor=\"yellow\">Will be learnable by " .. charName .. "</T>")
								invItem:SetHeightToContentHeight()
							end
						
						end -- if they did not already know it
					
					end -- whether they know any schematics	of this skill
			
				end -- loop through alts
				
			end -- did we find the name of the item created?
			
		end -- is there a spell we can parse?
		
	end -- if the tooltip is for a recipe
		
	-- Put our summary pane together and set its height
	local wndHeight = wndList:ArrangeChildrenVert()
	wndInv:SetAnchorOffsets(0, 0, 0, wndHeight)
	
	-- Rearrange the "items" in the tooltip to include the summary pane
	wndTooltip:FindChild("Items"):ArrangeChildrenVert()
	
	-- And resize to fit
	wndTooltip:Move(0, 0, wndTooltip:GetWidth(), wndTooltip:GetHeight()+wndHeight)
end

---------------------------------------------------------------------------------------------------
-- Functions for forgetting an alt
---------------------------------------------------------------------------------------------------

function Generalist:OnForgetButtonPushed( wndHandler, wndControl, eMouseButton )

	if wndHandler ~= wndControl then
		return
	end
	
	-- Confirmation dialog
	self.wndDetail:FindChild("ForgetConfirm"):Show(true)
	
end

function Generalist:OnForgetConfirmNo( wndHandler, wndControl, eMouseButton )

	if wndHandler ~= wndControl then
		return
	end
	
	self.wndDetail:FindChild("ForgetConfirm"):Show(false)
	
end

function Generalist:OnForgetConfirmYes( wndHandler, wndControl, eMouseButton )

	if wndHandler ~= wndControl then
		return
	end

	-- Name of the alt to forget
	local forgetName = self.detailOpen
	
	-- Hide the confirm dialog again
	self.wndDetail:FindChild("ForgetConfirm"):Show(false)
	
	-- Close the details window
	self.wndDetail:Show(false,true)
	self.detailOpen = false
	
	-- Forget the alt
	self.altData[forgetName] = nil
	
	-- Repopulate the character list
	self:PopulateCharList()
	
	-- and we're done!
	
end

-----------------------------------------------------------------------------------------------
-- Instantiation
-----------------------------------------------------------------------------------------------
local GeneralistInstance = Generalist:new()
GeneralistInstance:Init()