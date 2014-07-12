-----------------------------------------------------------------------------------------------
-- Client Lua Script for Jabbithole
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "GameLib"
require "Apollo"
require "Spell"
require "Unit"
require "PublicEventsLib"
require "ChallengesLib"
require "PlayerPathLib"
require "PathMission"

-----------------------------------------------------------------------------------------------
-- Jabbithole Module Definition
-----------------------------------------------------------------------------------------------
local Jabbithole = {} 
local VERSION = "0"
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
 
local droppedItems = {}
local unitCache = {}
local justLootedCache = {}
local inventoryCache = {}
local tVitals = Unit.GetVitalTable()
local creatureLocationCached = {}
local containerCache = {}
local reverseContainerCache = {}
local teachesCache = {}
local reverseTeachesCache = {}
local salvageCache = {}
local reverseSalvageCache = {}
local lastDatacube = nil
local bVeteranMode = false
local deprecates = 5

local KEY_ITEMS="items"
local KEY_ITEM_PROF_REQ="itempr"
local KEY_ITEM_SLOT="itemsl"
local KEY_ITEM_TYPE="itemtp"
local KEY_ITEM_FAMILY="itemf"
local KEY_ITEM_CATEGORY="itemcat"
local KEY_QUEST_CATEGORY="questc"
local KEY_QUEST_EPISODE="queste"
local KEY_QUESTS="quest"
local KEY_ZONES="zone"
local KEY_CREATURES="npc"
local KEY_TITLES="titles2"
local KEY_SPELLS="spells"
local KEY_CREATURE_SPELL="npcspell"
local KEY_VENDOR_ITEM="vnditem"
local KEY_VENDOR_SPELL="vndspl"
local KEY_PUBLIC_EVENT="pe"
local KEY_CHALLENGE="chg"
local KEY_PATH_EPISODE="pathe"
local KEY_PATH_MISSION="pathm"
local KEY_TRADESKILL="trades"
local KEY_TRADESKILL_TALENT="tradet"
local KEY_SCHEMATIC="sch"
local KEY_DATACUBE="dc"
local KEY_ATTRIBUTE="attr"
local KEY_FACTION="rep"
local KEY_HOUSE_PLOTS="plot"
local KEY_HOUSE_DECORTYPE="decort"
local KEY_HOUSE_DECOR="decor"

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function Jabbithole:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

	self.tSavedData={}
	self.tSavedData["v"]=0

    -- initialize variables here

    return o
end

function Jabbithole:Init()
    Apollo.RegisterAddon(self)
end

function Jabbithole:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Jabbithole.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end 

function Jabbithole:OnDocumentReady()
--	Print("Jabbithole:OnDocumentReady()")
    -- Register handlers for events, slash commands and timer, etc.
    -- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)

	if GameLib.GetPlayerUnit() then
		self:OnCharacterCreated()
	end

	Apollo.RegisterTimerHandler("DelayedInitTimer", "OnDelayedInitTimer", self)
	Apollo.CreateTimer("DelayedInitTimer", 0.1, false)
	--Apollo.StopTimer("DelayedInitTimer")
	
	Apollo.RegisterEventHandler("CharacterCreated","OnCharacterCreated", self)
	Apollo.RegisterEventHandler("Dialog_ShowState", "OnDialog_ShowState", self)
	--probably not necessary
	--Apollo.RegisterEventHandler("QuestObjectiveUpdated", "OnQuestObjectiveUpdated", self)
	Apollo.RegisterEventHandler("SubZoneChanged","OnSubZoneChanged", self)
	Apollo.RegisterEventHandler("PlayerPathMissionUnlocked","OnSubZoneChanged", self)
	Apollo.RegisterEventHandler("UnitCreated", "OnUnitCreated", self)
	Apollo.RegisterEventHandler("UnitDestroyed", "OnUnitDestroyed", self)
	Apollo.RegisterEventHandler("LootedItem","OnLootedItem", self)
	Apollo.RegisterEventHandler("PlayerTitleUpdate","OnPlayerTitleUpdate", self)
	Apollo.RegisterEventHandler("TargetUnitChanged","OnTargetUnitChanged", self)
	Apollo.RegisterEventHandler("CombatLogDamage","OnCombatLogDamage", self)
	Apollo.RegisterEventHandler("VendorItemsUpdated","OnVendorItemsUpdated", self)
	Apollo.RegisterEventHandler("InvokeVendorWindow","OnInvokeVendorWindow", self)
	Apollo.RegisterEventHandler("ItemModified", "OnItemModified", self)
	Apollo.RegisterEventHandler("PublicEventStart", "OnPublicEventStart", self)
	Apollo.RegisterEventHandler("ChallengeActivate", "OnChallengeActivate", self)
	Apollo.RegisterEventHandler("ChallengeRewardListReady", "OnChallengeRewardListReady", self)
	Apollo.RegisterEventHandler("ItemRemoved","OnItemRemoved", self)
	Apollo.RegisterEventHandler("CraftingSchematicLearned", "OnCraftingSchematicLearned", self)
	Apollo.RegisterEventHandler("DatacubeUpdated", "OnDatacubeUpdated", self)
	Apollo.RegisterEventHandler("PublicEventInitiateVote", 	"OnPublicEventInitiateVote", self)
	Apollo.RegisterEventHandler("PlayerPathMissionUnlocked", "OnPlayerPathMissionUnlocked", self)
	Apollo.RegisterEventHandler("PlayerPathMissionDeactivate", "OnPlayerPathMissionDeactivate", self)
	Apollo.RegisterEventHandler("HousingVendorListRecieved", "OnHousingPlugItemsUpdated", self)
	Apollo.RegisterEventHandler("ItemSentToCrate", "OnItemSentToCrate", self)
	--TODO remove from live
	--Apollo.RegisterEventHandler("DragDropSysBegin", "OnSystemBeginDragDrop", self)
	--Apollo.RegisterEventHandler("PlayerEquippedItemChanged", "OnPlayerEquippedItemChanged", self)
		
	Apollo.RegisterSlashCommand("jh", "OnJabbitholeOn", self)
		
    -- load our forms
--    self.wndMain = Apollo.LoadForm("Jabbithole.xml", "JabbitholeForm", nil, self)
--    self.wndMain:Show(false)
end

function Jabbithole:AddItemProfRequirement(data)
	if data then
		if self.tSavedData[KEY_ITEM_PROF_REQ] == nil then
			self.tSavedData[KEY_ITEM_PROF_REQ]={}
		end
		if self.tSavedData[KEY_ITEM_PROF_REQ][data.nId] ~= data.strName then
			self.tSavedData[KEY_ITEM_PROF_REQ][data.nId]=data.strName
		end
		return data.nId
	end
	return -1
end

function Jabbithole:AddItemAttribute(id)
	if self.tSavedData[KEY_ATTRIBUTE] == nil then
		self.tSavedData[KEY_ATTRIBUTE]={}
	end
	local name = Item.GetPropertyName(id)
	if name then
		if self.tSavedData[KEY_ATTRIBUTE][id] ~= name then
			self.tSavedData[KEY_ATTRIBUTE][id]=name
		end
	end
end


function Jabbithole:AddItemSlot(id,name)
	if id and name then
		if self.tSavedData[KEY_ITEM_SLOT] == nil then
			self.tSavedData[KEY_ITEM_SLOT]={}
		end
		if self.tSavedData[KEY_ITEM_SLOT][id] ~= name then
			self.tSavedData[KEY_ITEM_SLOT][id]=name
		end
		return id
	end
	return -1
end

function Jabbithole:AddItemType(id,name)
	if id and name then
		if self.tSavedData[KEY_ITEM_TYPE] == nil then
			self.tSavedData[KEY_ITEM_TYPE]={}
		end
		if self.tSavedData[KEY_ITEM_TYPE][id] ~= name then
			self.tSavedData[KEY_ITEM_TYPE][id]=name
		end
		return id
	end
	return -1
end

function Jabbithole:AddItemFamily(id,name)
	if id and name then
		if self.tSavedData[KEY_ITEM_FAMILY] == nil then
			self.tSavedData[KEY_ITEM_FAMILY]={}
		end
		if self.tSavedData[KEY_ITEM_FAMILY][id] ~= name then
			self.tSavedData[KEY_ITEM_FAMILY][id]=name
		end
		return id
	end
	return -1
end

function Jabbithole:AddItemCategory(id,name)
	if id and name then
		if self.tSavedData[KEY_ITEM_CATEGORY] == nil then
			self.tSavedData[KEY_ITEM_CATEGORY]={}
		end
		if self.tSavedData[KEY_ITEM_CATEGORY][id] ~= name then
			self.tSavedData[KEY_ITEM_CATEGORY][id]=name
		end
		return id
	end
	return -1
end

function Jabbithole:AddVendorItem(unit,item)
	if unit and unit:IsValid() and item then
		if self.tSavedData[KEY_VENDOR_ITEM] == nil then
			self.tSavedData[KEY_VENDOR_ITEM]={}
		end
		local vid=self:MakeCreatureId(unit)

		if self.tSavedData[KEY_VENDOR_ITEM][vid] == nil then
			self.tSavedData[KEY_VENDOR_ITEM][vid]={}
		end
		local key = item.itemData:GetChatLinkString()
		if self.tSavedData[KEY_VENDOR_ITEM][vid][key] == nil then
			self.tSavedData[KEY_VENDOR_ITEM][vid][key]={}
		end
		local specitem="-"
		if item.bIsSpecial then
			specitem="+"
		end
		self.tSavedData[KEY_VENDOR_ITEM][vid][key]=specitem.."/"..item.nStockCount.."/"..item.nStackSize.."/"..item.tPriceInfo.nAmount1.."/"..item.tPriceInfo.eCurrencyType1.."/"..item.tPriceInfo.nAmount2.."/"..item.tPriceInfo.eCurrencyType2
		if item.idPrereq > 0 then
			local tPrereqInfo = GameLib.GetPlayerUnit():GetPrereqInfo(item.idPrereq)
			if tPrereqInfo and tPrereqInfo.text then
				self.tSavedData[KEY_VENDOR_ITEM][vid][key]=self.tSavedData[KEY_VENDOR_ITEM][vid][key].."/"..tPrereqInfo.strText
			end
		end			
	end
end

function Jabbithole:AddVendorSpell(unit,item)
	if unit and unit:IsValid() and item then
		if self.tSavedData[KEY_VENDOR_SPELL] == nil then
			self.tSavedData[KEY_VENDOR_SPELL]={}
		end
		local vid=self:MakeCreatureId(unit)

		if self.tSavedData[KEY_VENDOR_SPELL][vid] == nil then
			self.tSavedData[KEY_VENDOR_SPELL][vid]={}
		end
		self:AddSpell(item.splData)
		local key = item.splData:GetId()
		if self.tSavedData[KEY_VENDOR_SPELL][vid][key] == nil then
			self.tSavedData[KEY_VENDOR_SPELL][vid][key]={}
		end
		local specitem="-"
		if item.bIsSpecial then
			specitem="+"
		end
		self.tSavedData[KEY_VENDOR_SPELL][vid][key]=specitem.."/"..item.nStockCount.."/"..item.nStackSize.."/"..item.tPriceInfo.nAmount1.."/"..item.tPriceInfo.eCurrencyType1.."/"..item.tPriceInfo.nAmount2.."/"..item.tPriceInfo.eCurrencyType2
		if item.idPrereq > 0 then
			local tPrereqInfo = GameLib.GetPlayerUnit():GetPrereqInfo(item.idPrereq)
			if tPrereqInfo and tPrereqInfo.text then
				self.tSavedData[KEY_VENDOR_SPELL][vid][key]=self.tSavedData[KEY_VENDOR_SPELL][vid][key].."/"..tPrereqInfo.strText
			end
		end			
	end
end

function Jabbithole:AddItem(item, questId, unit, bSaveSide)
	if item then
		if self.tSavedData[KEY_ITEMS] == nil then
			self.tSavedData[KEY_ITEMS]={}
		end
		local id=item:GetChatLinkString()

		if self.tSavedData[KEY_ITEMS][id] == nil then

			-- is there an other key here than tPrimary?			
			local info=item:GetDetailedInfo().tPrimary
			self.tSavedData[KEY_ITEMS][id]={}

			if item:GetGivenQuest() then
				local q=item:GetGivenQuest()
				self:AddQuest(q,nil,nil, bSaveSide)
				self.tSavedData[KEY_ITEMS][id]["quest"]=q:GetId()
			end
			
			self.tSavedData[KEY_ITEMS][id]["name"]=info.strName
			self.tSavedData[KEY_ITEMS][id]["id"]=item:GetItemId()
			
			self.tSavedData[KEY_ITEMS][id]["icon"]=item:GetIcon()
			self.tSavedData[KEY_ITEMS][id]["drops"]={}
			self.tSavedData[KEY_ITEMS][id]["binds"]=0
			if info.tBind then
				if info.tBind.bOnEquip then
					self.tSavedData[KEY_ITEMS][id]["binds"]=1
				end
				if info.tBind.bOnPickup then
					self.tSavedData[KEY_ITEMS][id]["binds"]=2
				end
			end
			self.tSavedData[KEY_ITEMS][id]["salv"]=(info.bSalvagable==true)
			self.tSavedData[KEY_ITEMS][id]["q"]=info.eQuality
			self.tSavedData[KEY_ITEMS][id]["pwr"]=item:GetItemPower()
			self.tSavedData[KEY_ITEMS][id]["flav"]=info.strFlavor
			if info.tDurability then
				self.tSavedData[KEY_ITEMS][id]["dura"]=info.tDurability.nMax
			end
			if info.tStack then
				self.tSavedData[KEY_ITEMS][id]["stck"]=info.tStack.nMaxCount
			end
			if info.tCharge then
				if info.tCharge.nMaxCount then
					self.tSavedData[KEY_ITEMS][id]["chgs"]=info.tCharge.nMaxCount
				end
			end
			self.tSavedData[KEY_ITEMS][id]["rqlvl"]=0
			if info.tLevelRequirement then
				self.tSavedData[KEY_ITEMS][id]["rqlvl"]=info.tLevelRequirement.nLevelRequired
			end
			self.tSavedData[KEY_ITEMS][id]["rqprof"]=0
			if info.tProfRequirement then
				self.tSavedData[KEY_ITEMS][id]["rqprof"]=self:AddItemProfRequirement(info.tProfRequirement)				
			end
--			self.tSavedData[KEY_ITEMS][id]["eflvl"]=item:GetEffectiveLevel() removed from API
			self.tSavedData[KEY_ITEMS][id]["uniq"]=item:IsUnique()
			
			if info.tUnique and info.tUnique.bEquipped then
				self.tSavedData[KEY_ITEMS][id]["uniqeq"]=true
			end
			
			self.tSavedData[KEY_ITEMS][id]["equip"]=item:IsEquippable()
			self.tSavedData[KEY_ITEMS][id]["comm"]=item:IsCommodity()
			self.tSavedData[KEY_ITEMS][id]["data"]=item:isData()
			self.tSavedData[KEY_ITEMS][id]["inst"]=item:isInstance()
			self.tSavedData[KEY_ITEMS][id]["tssid"]=item:GetTradeskillSchematicId()
			
			self.tSavedData[KEY_ITEMS][id]["wpdmgmx"]=item:GetWeaponDamageMax()
			self.tSavedData[KEY_ITEMS][id]["wpdmgmn"]=item:GetWeaponDamageMin()
			self.tSavedData[KEY_ITEMS][id]["wppw"]=item:GetWeaponPower()
			self.tSavedData[KEY_ITEMS][id]["wpspd"]=item:GetWeaponSpeed()
			self.tSavedData[KEY_ITEMS][id]["blevel"]=item:GetPowerLevel()
			self.tSavedData[KEY_ITEMS][id]["deco"]=item:GetHousingDecorInfoId()
--			self.tSavedData[KEY_ITEMS][id]["link"]=item:GetChatLinkString()
--			self.tSavedData[KEY_ITEMS][id]["cons"]=(item:GetConsumable()~=nil) removed from API

			--category item:GetDetailedInfo item:GetItemCategory item:GetItemCategoryName 3 Heavy Armor
			--family item:GetDetailedInfo item:GetItemFamily item:GetItemFamilyName 1 Armor
			--type item:GetDetailedInfo item:GetItemType item:GetItemTypeName 15 Armor - Heavy - Chest
			--slot item:GetSlot item:GetSlotName 0 Chest
			self.tSavedData[KEY_ITEMS][id]["cat"]=self:AddItemCategory(info.eCategory, item:GetItemCategoryName ())
			self.tSavedData[KEY_ITEMS][id]["fam"]=self:AddItemFamily(info.eFamily, item:GetItemFamilyName ())
			self.tSavedData[KEY_ITEMS][id]["typ"]=self:AddItemType(info.eType, item:GetItemTypeName ())
			self.tSavedData[KEY_ITEMS][id]["slot"]=-1
			if item:GetSlot() then
				self.tSavedData[KEY_ITEMS][id]["slot"]=self:AddItemSlot(item:GetSlot (), item:GetSlotName ())
			end
			
			if info.arSpells then
				self.tSavedData[KEY_ITEMS][id]["spls"]={}
				for idx = 1, #info.arSpells do
					self.tSavedData[KEY_ITEMS][id]["spls"][idx]={}
					self.tSavedData[KEY_ITEMS][id]["spls"][idx]["id"]=self:AddSpell(info.arSpells[idx].splData)
					self.tSavedData[KEY_ITEMS][id]["spls"][idx]["name"]=info.arSpells[idx].strName
					if info.arSpells[idx].bActivate == true then
						self.tSavedData[KEY_ITEMS][id]["spls"][idx]["use"]=1
					end
					if info.arSpells[idx].bOnEquip== true then
						self.tSavedData[KEY_ITEMS][id]["spls"][idx]["equ"]=1
					end
					if info.arSpells[idx].bProc == true then
						self.tSavedData[KEY_ITEMS][id]["spls"][idx]["prc"]=1
					end
				end
			end
						
			--sold for item:GetDetailedInfo
			--Money.CodeEnumCurrencyType
			if info.tCost and info.tCost.arMonSell then
				self.tSavedData[KEY_ITEMS][id]["sold4"]=info.tCost.arMonSell[1]:GetAmount()
				self.tSavedData[KEY_ITEMS][id]["soldc"]=info.tCost.arMonSell[1]:GetMoneyType()
			end

			--imbuements
			if info.arImbuements then
				self.tSavedData[KEY_ITEMS][id]["imbue2"]={}
				for key, imb in pairs(info.arImbuements) do
					if imb.queImbuement then
						self:AddQuest(imb.queImbuement,nil,nil,bSaveSide)
						self.tSavedData[KEY_ITEMS][id]["imbue2"][key]={}
						self.tSavedData[KEY_ITEMS][id]["imbue2"][key]["i"]=imb.queImbuement:GetId()
						self.tSavedData[KEY_ITEMS][id]["imbue2"][key]["n"]=imb.strName
						self.tSavedData[KEY_ITEMS][id]["imbue2"][key]["o"]=imb.strObjective
						self.tSavedData[KEY_ITEMS][id]["imbue2"][key]["s"]=imb.strSpecial
						self.tSavedData[KEY_ITEMS][id]["imbue2"][key]["a"]=imb.bActive
						self.tSavedData[KEY_ITEMS][id]["imbue2"][key]["c"]=imb.bComplete
						self.tSavedData[KEY_ITEMS][id]["imbue2"][key]["at"]=imb.eProperty
						self.tSavedData[KEY_ITEMS][id]["imbue2"][key]["v"]=imb.nValue
					end
				end				
			end
						
			--primary innate stats item:GetDetailedInfo
			if info.arInnateProperties then
				self.tSavedData[KEY_ITEMS][id]["stati"]={}
				for key, prop in pairs(info.arInnateProperties) do
					self.tSavedData[KEY_ITEMS][id]["stati"][prop.eProperty.."/"..prop.nSortOrder.."/"..prop.nValue]=1
					self:AddItemAttribute(prop.eProperty)
				end
			end
			--primary budget stats item:GetDetailedInfo
			--primary budget derived item:GetDetailedInfo
			self.tSavedData[KEY_ITEMS][id]["statvar"]={}
			local statsKey=""
			if info.arBudgetBasedProperties then
				for idx, prop in pairs(info.arBudgetBasedProperties) do
					if idx>1 then
						statsKey = statsKey.."#"
					end
					statsKey = statsKey..prop.eProperty.."/"..prop.nSortOrder.."/"..prop.nValue
					self:AddItemAttribute(prop.eProperty)
				end
			end
			statsKey = statsKey .. "%"			
			--sigils, name,type item:GetDetailedInfo + item:GetSigils
			--TODO: multi-sigil items?
			if info.tSigils then
				if info.tSigils.arSigils then
					for idx = 1, #info.tSigils.arSigils do
						if idx>1 then
							statsKey = statsKey.."#"
						end
						statsKey = statsKey..info.tSigils.arSigils[idx].eElement
					end
				end
				if info.tSigils.nMaximum then
					self.tSavedData[KEY_ITEMS][id]["sigmax"]=info.tSigils.nMaximum 
				end
				if info.tSigils.nMinimum then
					self.tSavedData[KEY_ITEMS][id]["sigmin"]=info.tSigils.nMinimum 
				end
			end
			if statsKey ~= "" and statsKey ~= "%" then
				self.tSavedData[KEY_ITEMS][id]["statvar"][statsKey]=1
			end

			if info.arRandomProperties then
				self.tSavedData[KEY_ITEMS][id]["statrc"]=#info.arRandomProperties
			end
						
			-- item:GetRequiredClass {} NEEDS DATA
			--race req item:GetRequiredRace - nil NEEDS DATA
			
			if info.tDurability then
				self.tSavedData[KEY_ITEMS][id]["dura"]=info.tDurability.nMax
				if info.tDurability.nCurrent == nil then
					-- no current durability most likely means it is in vendor inventory
					-- info.arRandomProperties shall list the random properties
					-- item:isInstance() shall be false
					-- might be useful for something
				end
			end
			
			self.tSavedData[KEY_ITEMS][id]["tsreq"]={}
			for idx, ts in pairs(info.arTradeskillReqs or {}) do
				self.tSavedData[KEY_ITEMS][id]["tsreq"][ts.strName]=ts.eTier
			end
			self.tSavedData[KEY_ITEMS][id]["classreq"]=""
			for idx, cls in pairs(item:GetRequiredClass() or {}) do
				if idx>1 then
					self.tSavedData[KEY_ITEMS][id]["classreq"]=self.tSavedData[KEY_ITEMS][id]["classreq"]..","
				end
				self.tSavedData[KEY_ITEMS][id]["classreq"]=self.tSavedData[KEY_ITEMS][id]["classreq"]..cls.idClassReq
			end
			
		
		else
			local info=item:GetDetailedInfo().tPrimary

			self.tSavedData[KEY_ITEMS][id]["blevel"]=item:GetPowerLevel()
			self.tSavedData[KEY_ITEMS][id]["deco"]=item:GetHousingDecorInfoId()

			-- update due to typo in previous versions
			self.tSavedData[KEY_ITEMS][id]["tsreq"]={}
			for idx, ts in pairs(info.arTradeskillReqs or {}) do
				self.tSavedData[KEY_ITEMS][id]["tsreq"][ts.strName]=ts.eTier
			end
						
			-- if spells changed, for example after an imbuement
			if info.arSpells then
				if self.tSavedData[KEY_ITEMS][id]["spls"]==nil then
					self.tSavedData[KEY_ITEMS][id]["spls"]={}
				end
				for idx = 1, #info.arSpells do
					self.tSavedData[KEY_ITEMS][id]["spls"][idx]={}
					self.tSavedData[KEY_ITEMS][id]["spls"][idx]["id"]=self:AddSpell(info.arSpells[idx].splData)
					self.tSavedData[KEY_ITEMS][id]["spls"][idx]["name"]=info.arSpells[idx].strName
					if info.arSpells[idx].bActivate == true then
						self.tSavedData[KEY_ITEMS][id]["spls"][idx]["use"]=1
					end
					if info.arSpells[idx].bOnEquip== true then
						self.tSavedData[KEY_ITEMS][id]["spls"][idx]["equ"]=1
					end
					if info.arSpells[idx].bProc == true then
						self.tSavedData[KEY_ITEMS][id]["spls"][idx]["prc"]=1
					end
				end
			end

			--imbuements
			if info.arImbuements then
				self.tSavedData[KEY_ITEMS][id]["imbue2"]={}
				for key, imb in pairs(info.arImbuements) do
					if imb.queImbuement then
						self:AddQuest(imb.queImbuement,nil,nil,bSaveSide)
						self.tSavedData[KEY_ITEMS][id]["imbue2"][key]={}
						self.tSavedData[KEY_ITEMS][id]["imbue2"][key]["i"]=imb.queImbuement:GetId()
						self.tSavedData[KEY_ITEMS][id]["imbue2"][key]["n"]=imb.strName
						self.tSavedData[KEY_ITEMS][id]["imbue2"][key]["o"]=imb.strObjective
						self.tSavedData[KEY_ITEMS][id]["imbue2"][key]["s"]=imb.strSpecial
						self.tSavedData[KEY_ITEMS][id]["imbue2"][key]["a"]=imb.bActive
						self.tSavedData[KEY_ITEMS][id]["imbue2"][key]["c"]=imb.bComplete
						self.tSavedData[KEY_ITEMS][id]["imbue2"][key]["at"]=imb.eProperty
						self.tSavedData[KEY_ITEMS][id]["imbue2"][key]["v"]=imb.nValue
					end
				end				
			end
								
		end
		if unit then
			unitid = self:MakeCreatureId(unit)

			if self.tSavedData[KEY_ITEMS][id]["drops"][unitid] == nil then
				self.tSavedData[KEY_ITEMS][id]["drops"][unitid]=1
			else
				self.tSavedData[KEY_ITEMS][id]["drops"][unitid]=self.tSavedData[KEY_ITEMS][id]["drops"][unitid]+1
			end
		end
	end
end

function Jabbithole:AddSpell(splSource)
	if splSource then
		if self.tSavedData[KEY_SPELLS] == nil then
			self.tSavedData[KEY_SPELLS]={}
		end
		local id=splSource:GetId()
		if self.tSavedData[KEY_SPELLS][id] == nil then
			self.tSavedData[KEY_SPELLS][id]={}
			self.tSavedData[KEY_SPELLS][id]["name"]=splSource:GetName()
			self.tSavedData[KEY_SPELLS][id]["flav"]=nlFix(splSource:GetFlavor())

			local fCastTime
			local strCastInfo = splSource:GetCastInfoString()
			local eCastMethod = splSource:GetCastMethod()
			local tChannelData = splSource:GetChannelData()

			if strCastInfo and strCastInfo ~= "" then
				fCastTime = splSource:GetCastTimeOverride()
			else
				if eCastMethod == Spell.CodeEnumCastMethod.Channeled or eCastMethod == Spell.CodeEnumCastMethod.ChanneledField then
					fCastTime = tChannelData["fMaxTime"]
				elseif eCastMethod == Spell.CodeEnumCastMethod.PressHold or eCastMethod == Spell.CodeEnumCastMethod.ChargeRelease then
					fCastTime = splSource:GetThresholdTime()
				else
					fCastTime = splSource:GetCastTime()
				end
		
				if eCastMethod == Spell.CodeEnumCastMethod.Normal or eCastMethod == Spell.CodeEnumCastMethod.Multiphase or eCastMethod == Spell.CodeEnumCastMethod.Aura then
					if fCastTime == 0 then
						strCastInfo = Apollo.GetString("Tooltip_Instant")
					else
						strCastInfo = String_GetWeaselString(Apollo.GetString("Tooltip_CastTime"), tostring(strRound(fCastTime, 2)))
					end
				elseif eCastMethod == Spell.CodeEnumCastMethod.Channeled or eCastMethod == Spell.CodeEnumCastMethod.ChanneledField then
					strCastInfo = String_GetWeaselString(Apollo.GetString("Tooltip_ChannelTime"), tostring(strRound(fCastTime, 2)))
				elseif eCastMethod == Spell.CodeEnumCastMethod.PressHold then
					strCastInfo = String_GetWeaselString(Apollo.GetString("Tooltip_HoldTime"), tostring(strRound(fCastTime, 2)))
				elseif eCastMethod == Spell.CodeEnumCastMethod.ClientSideInteraction then
					strCastInfo = Apollo.GetString("Tooltip_CSI")
				elseif eCastMethod == Spell.CodeEnumCastMethod.RapidTap then
					if fCastTime == 0 then
						strCastInfo = Apollo.GetString("Tooltips_InstantMultiTap")
					else
						strCastInfo = String_GetWeaselString(Apollo.GetString("Tooltips_CastThenMultiTap"), tostring(strRound(fCastTime, 2)))
					end
				elseif eCastMethod == Spell.CodeEnumCastMethod.ChargeRelease then
					strCastInfo = String_GetWeaselString(Apollo.GetString("Tooltips_ChargeTime"), tostring(strRound(fCastTime, 2)))
				else
					strCastInfo = Apollo.GetString("Tooltips_UnknownCastMethod")
				end
			end
			
			self.tSavedData[KEY_SPELLS][id]["castinfo"]=strCastInfo 
			
			-- Range
			
			self.tSavedData[KEY_SPELLS][id]["rmin"]=splSource:GetMinimumRange()
			self.tSavedData[KEY_SPELLS][id]["rmax"]=splSource:GetMaximumRange()
	
			local strCost = ""
			local tResource
		    local tCosts = splSource:GetCasterInnateCosts()
		
			if #tCosts == 0 then
				tCosts = splSource:GetCasterInnateRequirements()
			end
		
			for idx = 1, #tCosts do
				if strCost ~= "" then
					strCost = strCost .. Apollo.GetString("Tooltips_And")
				end
		
				tResource = tVitals[tCosts[idx]["eVital"]]
				if not tResource then
					tResource = {}
					tResource.strName = String_GetWeaselString(Apollo.GetString("Tooltips_UnknownVital"), tCosts[idx]["eVital"])
				end
		
				strCost = strCost .. tCosts[idx]["nValue"] .. " " .. tResource.strName
		
				if eCastMethod == Spell.CodeEnumCastMethod.Channeled then
					strCost = strCost .. Apollo.GetString("Tooltips_ChanneledCost")
				elseif eCastMethod == Spell.CodeEnumCastMethod.ChargeRelease then
					strCost = strCost .. Apollo.GetString("Tooltips_Charges")
				end
			end
	
			self.tSavedData[KEY_SPELLS][id]["castcost"]=strCost 
		
			-- Targeting
			if splSource:IsFreeformTarget() then
				self.tSavedData[KEY_SPELLS][id]["target"]=Apollo.GetString("Tooltips_Freeform")
			elseif splSource:IsSelfSpell() then
				self.tSavedData[KEY_SPELLS][id]["target"]=Apollo.GetString("Tooltips_Self")
			else
				self.tSavedData[KEY_SPELLS][id]["target"]=Apollo.GetString("Tooltips_Targeted")
			end
							
			-- Cooldown / Recharge
		    local fCooldownTime = splSource:GetCooldownTime()
		
			if fCooldownTime == 0 then
			    local tCharges = splSource:GetAbilityCharges()
				if tCharges then
					fCooldownTime = tCharges.fRechargeTime
				end
		
				if fCooldownTime == 0 then
					self.tSavedData[KEY_SPELLS][id]["cd"]=Apollo.GetString("Tooltips_NoCooldown")
				elseif fCooldownTime < 60 then
					self.tSavedData[KEY_SPELLS][id]["cd"]=String_GetWeaselString(Apollo.GetString("Tooltips_RechargeSeconds"), strRound(fCooldownTime, 0))
				else
					self.tSavedData[KEY_SPELLS][id]["cd"]=String_GetWeaselString(Apollo.GetString("Tooltips_RechargeMin"), strRound(fCooldownTime / 60, 1))
			    end
			elseif fCooldownTime < 60 then
				self.tSavedData[KEY_SPELLS][id]["cd"]=String_GetWeaselString(Apollo.GetString("Tooltips_SecondsCooldown"), strRound(fCooldownTime, 0))
			else
				self.tSavedData[KEY_SPELLS][id]["cd"]=String_GetWeaselString(Apollo.GetString("Tooltips_MinCooldown"), strRound(fCooldownTime / 60, 1))
		    end
		
			-- Mobility
		
			if (eCastMethod == Spell.CodeEnumCastMethod.Normal or eCastMethod == Spell.CodeEnumCastMethod.RapidTap or eCastMethod == Spell.CodeEnumCastMethod.Multiphase) and fCastTime == 0 then
				self.tSavedData[KEY_SPELLS][id]["mob"]=""
			else
				if splSource:IsMovingInterrupted() then
					self.tSavedData[KEY_SPELLS][id]["mob"]=Apollo.GetString("Tooltips_Stationary")
				else
					self.tSavedData[KEY_SPELLS][id]["mob"]=Apollo.GetString("Tooltips_Mobile")
				end
			end

			self.tSavedData[KEY_SPELLS][id]["tier"]=splSource:GetTier()			
			self.tSavedData[KEY_SPELLS][id]["icon"]=splSource:GetIcon()			
			self.tSavedData[KEY_SPELLS][id]["cls"]=splSource:GetClass()			
			self.tSavedData[KEY_SPELLS][id]["cp"]=splSource:GetClassPower()			
			self.tSavedData[KEY_SPELLS][id]["cm"]=splSource:GetCombatMode()			
			self.tSavedData[KEY_SPELLS][id]["sch"]=splSource:GetSchool()		
			self.tSavedData[KEY_SPELLS][id]["ta"]=splSource:GetTargetAngle()		
			self.tSavedData[KEY_SPELLS][id]["rqlvl"]=splSource:GetRequiredLevel()		
			self.tSavedData[KEY_SPELLS][id]["tb"]=nlFix(splSource:GetLasBonusEachTierDesc())
		end
		return id
	end
end

function Jabbithole:AddQuestCategory(cat)
	if cat then
		if self.tSavedData[KEY_QUEST_CATEGORY] == nil then
			self.tSavedData[KEY_QUEST_CATEGORY]={}
		end
		local id=cat:GetId()
		if self.tSavedData[KEY_QUEST_CATEGORY][id] == nil then
			self.tSavedData[KEY_QUEST_CATEGORY][id]=cat:GetTitle()
		end
		return id
	end
	return -1
end

function Jabbithole:AddQuestEpisode(epi)
	if epi then
		if self.tSavedData[KEY_QUEST_EPISODE] == nil then
			self.tSavedData[KEY_QUEST_EPISODE]={}
		end
		local id=epi:GetId()
		if self.tSavedData[KEY_QUEST_EPISODE][id] == nil then
			self.tSavedData[KEY_QUEST_EPISODE][id]=epi:GetTitle()
		end
		return id
	end
	return -1
end

function Jabbithole:AddQuest(quest,srcUnit,srcComm,bSaveSide)
	if quest then
		if self.tSavedData[KEY_QUESTS] == nil then
			self.tSavedData[KEY_QUESTS]={}
		end
		local id=quest:GetId()
		if self.tSavedData[KEY_QUESTS][id] == nil then
			self.tSavedData[KEY_QUESTS][id]={}
			self.tSavedData[KEY_QUESTS][id]["name"]=quest:GetTitle()
			self.tSavedData[KEY_QUESTS][id]["summary"]=quest:GetSummary()
			self.tSavedData[KEY_QUESTS][id]["xp"]=quest:CalcRewardXP()
			self.tSavedData[KEY_QUESTS][id]["minlevel"]=quest:GetMinLevel()
			self.tSavedData[KEY_QUESTS][id]["level"]=quest:GetConLevel()
			self.tSavedData[KEY_QUESTS][id]["share"]=quest:CanShare()
			self.tSavedData[KEY_QUESTS][id]["abandon"]=quest:CanAbandon()
			self.tSavedData[KEY_QUESTS][id]["difficulty"]=quest:GetColoredDifficulty()
--			self.tSavedData[KEY_QUESTS][id]["zone"]=self.tZone.id
			self.tSavedData[KEY_QUESTS][id]["npc"]=nil
			self.tSavedData[KEY_QUESTS][id]["posx"]=nil
			self.tSavedData[KEY_QUESTS][id]["posy"]=nil
			self.tSavedData[KEY_QUESTS][id]["callzone"]={}
			self.tSavedData[KEY_QUESTS][id]["start"]={}
			self.tSavedData[KEY_QUESTS][id]["finish"]={}
			
			if quest:GetCategory() then
				self.tSavedData[KEY_QUESTS][id]["category"]=self:AddQuestCategory(quest:GetCategory())
			end

			if quest:GetEpisode() then
				self.tSavedData[KEY_QUESTS][id]["episode"]=self:AddQuestEpisode(quest:GetEpisode())
			end
	
			self.tSavedData[KEY_QUESTS][id]["objectives"]={}
			if quest:GetObjectiveCount()>0 then
				for idx=0, quest:GetObjectiveCount()-1 do
					self.tSavedData[KEY_QUESTS][id]["objectives"][idx]=quest:GetObjectiveDescription(idx)
				end
			end

			if bSaveSide then
				if self.tPlayerFaction == Unit.CodeEnumFaction.DominionPlayer then
					self.tSavedData[KEY_QUESTS][id]["side_d"]=true
				end
				if self.tPlayerFaction == Unit.CodeEnumFaction.ExilesPlayer then
					self.tSavedData[KEY_QUESTS][id]["side_e"]=true
				end
			end
							
			fixItems = {}
			optItems = {}
			fixCash = {}
			optCash = {}
			fixRep = {}
			optRep = {}
			fixTradeskill = {}
			optTradeskill = {}
			
			local rewards = quest:GetRewardData()
			
			--if tGivenRewards and #tGivenRewards > 0 then
				for key, tCurrReward in ipairs(rewards.arFixedRewards or {}) do
					if tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_Item then
						self:AddItem(tCurrReward.itemReward, id, nil, bSaveSide)
						fixItems [tCurrReward.idReward] = tCurrReward.nAmount.."/"..tCurrReward.itemReward:GetChatLinkString()
					end
					if tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_Money then
						if tCurrReward.eCurrencyType or tCurrReward.idObject then
							if tCurrReward.eCurrencyType then
								fixCash[tCurrReward.idReward] = tCurrReward.nAmount.."/"..tCurrReward.eCurrencyType
							else
								fixCash[tCurrReward.idReward] = tCurrReward.nAmount.."/"..tCurrReward.idObject 
							end
						end
					end
					if tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_TradeSkillXp then
						fixTradeskill [tCurrReward.idReward] = tCurrReward.nXP.."/"..tCurrReward.idObject.."/"..tCurrReward.strTradeskill
					end
					if tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_Reputation then
						fixRep [tCurrReward.idObject] = tCurrReward.nAmount.."/"..tCurrReward.strFactionName
					end
				end
			--end
	
			--if tChoiceRewards and #tChoiceRewards > 0 then
				for key, tCurrReward in ipairs(rewards.arRewardChoices or {}) do
					if tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_Item then
						self:AddItem(tCurrReward.itemReward, id, nil, bSaveSide)
						optItems [tCurrReward.idReward] = tCurrReward.nAmount.."/"..tCurrReward.itemReward:GetChatLinkString()
					end
					if tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_Money then
						if tCurrReward.eCurrencyType or tCurrReward.idObject then
							if tCurrReward.eCurrencyType then
								optCash[tCurrReward.idReward] = tCurrReward.nAmount.."/"..tCurrReward.eCurrencyType
							else
								optCash[tCurrReward.idReward] = tCurrReward.nAmount.."/"..tCurrReward.idObject 
							end
						end
					end
					if tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_TradeSkillXp then
						optTradeskill [tCurrReward.idReward] = tCurrReward.nXP.."/"..tCurrReward.idObject.."/"..tCurrReward.strTradeskill
					end
					if tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_Reputation then
						optRep [tCurrReward.idObject] = tCurrReward.nAmount.."/"..tCurrReward.strFactionName
					end
				end
			--end
				
			self.tSavedData[KEY_QUESTS][id]["fixItems"]=fixItems
			self.tSavedData[KEY_QUESTS][id]["optItems"]=optItems
			self.tSavedData[KEY_QUESTS][id]["fixCash"]=fixCash
			self.tSavedData[KEY_QUESTS][id]["optCash"]=optCash
			self.tSavedData[KEY_QUESTS][id]["fixTradeskill"]=fixTradeskill
			self.tSavedData[KEY_QUESTS][id]["optTradeskill"]=optTradeskill
			self.tSavedData[KEY_QUESTS][id]["fixRep"]=fixRep
			self.tSavedData[KEY_QUESTS][id]["optRep"]=optRep
		else
			if self.tSavedData[KEY_QUESTS][id]["fixItems"] == nil then
				self.tSavedData[KEY_QUESTS][id]["fixItems"]={}
			end
			if self.tSavedData[KEY_QUESTS][id]["optItems"] == nil then
				self.tSavedData[KEY_QUESTS][id]["optItems"]={}
			end
			if self.tSavedData[KEY_QUESTS][id]["fixCash"] == nil then
				self.tSavedData[KEY_QUESTS][id]["fixCash"]={}
			end
			if self.tSavedData[KEY_QUESTS][id]["optCash"] == nil then
				self.tSavedData[KEY_QUESTS][id]["optCash"]={}
			end
			if self.tSavedData[KEY_QUESTS][id]["fixTradeskill"] == nil then
				self.tSavedData[KEY_QUESTS][id]["fixTradeskill"]={}
			end
			if self.tSavedData[KEY_QUESTS][id]["optTradeskill"] == nil then
				self.tSavedData[KEY_QUESTS][id]["optTradeskill"]={}
			end
			if self.tSavedData[KEY_QUESTS][id]["fixRep"] == nil then
				self.tSavedData[KEY_QUESTS][id]["fixRep"]={}
			end
			if self.tSavedData[KEY_QUESTS][id]["optRep"] == nil then
				self.tSavedData[KEY_QUESTS][id]["optRep"]={}
			end
		
--			Print("existing quest")
			if self.tPlayerFaction == Unit.CodeEnumFaction.DominionPlayer then
				self.tSavedData[KEY_QUESTS][id]["side_d"]=true
			end
			if self.tPlayerFaction == Unit.CodeEnumFaction.ExilesPlayer then
				self.tSavedData[KEY_QUESTS][id]["side_e"]=true
			end
			
--			Print(""..#quest:GetRewardData())
			
			-- update item rewards for filtered reward set (per class stuff)
			local rewards = quest:GetRewardData()

--			if tGivenRewards and #tGivenRewards > 0 then
				for key, tCurrReward in ipairs(rewards.arFixedRewards or {}) do
					if tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_Item then
--						Print("new item")
						self:AddItem(tCurrReward.itemReward, id, nil, bSaveSide)
						self.tSavedData[KEY_QUESTS][id]["fixItems"][tCurrReward.idReward] = tCurrReward.nAmount.."/"..tCurrReward.itemReward:GetChatLinkString()
					end
				end
--			end	
--			if tChoiceRewards and #tChoiceRewards > 0 then
				for key, tCurrReward in ipairs(rewards.arRewardChoices or {}) do
					if tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_Item then
--						Print("new item")
						self:AddItem(tCurrReward.itemReward, id, nil, bSaveSide)
						self.tSavedData[KEY_QUESTS][id]["optItems"][tCurrReward.idReward] = tCurrReward.nAmount.."/"..tCurrReward.itemReward:GetChatLinkString()
					end
				end
--			end
		end
		--merges
		if srcUnit and srcUnit:IsValid() then
			local starter=self:MakeCreatureId(srcUnit)

			if self.tSavedData[KEY_QUESTS][id]["start"]==nil then
				self.tSavedData[KEY_QUESTS][id]["start"]={}
			end
			if self.tSavedData[KEY_QUESTS][id]["start"][starter]==nil then
				self.tSavedData[KEY_QUESTS][id]["start"][starter]={}
			end
			
			self.tSavedData[KEY_QUESTS][id]["start"][starter][srcUnit:GetPosition().x.."/"..srcUnit:GetPosition().y.."/"..srcUnit:GetPosition().z]=1
			self:AddCreature(srcUnit)
		end
		if srcComm then
			if self.tSavedData[KEY_QUESTS][id]["callzone"]==nil then
				self.tSavedData[KEY_QUESTS][id]["callzone"]={}
			end
			if self.tSavedData[KEY_QUESTS][id]["callzone"][self.tZone.id]==nil then
				self.tSavedData[KEY_QUESTS][id]["callzone"][self.tZone.id]={}
			end
			if self.tPlayer == nil then
				self.tPlayer=GameLib.GetPlayerUnit()
			end
			self.tSavedData[KEY_QUESTS][id]["callzone"][self.tZone.id][self.tPlayer:GetPosition().x.."/"..self.tPlayer:GetPosition().y.."/"..self.tPlayer:GetPosition().z]=1
		end
	end
end

function Jabbithole:AddZone(zone)
	if zone then
		if self.tSavedData[KEY_ZONES] == nil then
			self.tSavedData[KEY_ZONES]={}
		end
		local id=zone.id
		if self.tSavedData[KEY_ZONES][id] == nil then
			self.tSavedData[KEY_ZONES][id]={}
			self.tSavedData[KEY_ZONES][id]["name"]=zone.strName
			self.tSavedData[KEY_ZONES][id]["map"]=zone.strFolder
			self.tSavedData[KEY_ZONES][id]["continent"]=zone.continentId
			self.tSavedData[KEY_ZONES][id]["bounds"]=zone.fNorth.."/"..zone.fEast.."/"..zone.fSouth.."/"..zone.fWest
		end
	end
end

function Jabbithole:AddCreatureSpellRelation(unit,spell)
	if unit and spell and not unit:IsACharacter() then
		if self.tSavedData[KEY_CREATURE_SPELL] == nil then
			self.tSavedData[KEY_CREATURE_SPELL]={}
		end
		local sid=spell:GetId()
		local cid=self:MakeCreatureId(unit)
		
		self.tSavedData[KEY_CREATURE_SPELL][sid.."/"..cid]=1
--		Print("Jabbithole:AddCreatureSpellRelation");
	end
end

function Jabbithole:MakeCreatureId(unit)
	local n=unit:GetName()
	if n==nil or n=="" then
		n="Name not specified"
	end
	ret=self.tZone.id.."/"..n
	if bVeteranMode then
		if unit:GetMaxHealth() then
			ret = ret .. "/v"
		else
			local ufac=unit:GetFacing()
			if ufac then
				if ufac.x==-0 and ufac.y==0 and ufac.z==-1 then
					ret = ret .. "/v"
				end
			end
		end
	end
	return ret
end

function Jabbithole:AddCreature(unit,checkForInvLooter)
	if unit and (not unit:IsACharacter()) and unit:IsValid() then
		if unit:GetUnitOwner() then
			if unit:GetUnitOwner():IsACharacter() then
				return
			end
		end
		if unit:GetType()=="Scanner" or unit:GetType()=="PinataLoot" then
			return
		end
	
		if self.tSavedData[KEY_CREATURES] == nil then
			self.tSavedData[KEY_CREATURES]={}
		end
		
		local id=self:MakeCreatureId(unit)
		
		local upos=unit:GetPosition()
		if self.tSavedData[KEY_CREATURES][id] == nil then
			self.tSavedData[KEY_CREATURES][id]={}
			self.tSavedData[KEY_CREATURES][id]["name"]=unit:GetName()
			self.tSavedData[KEY_CREATURES][id]["zone"]={}
			
			if self.tPlayerFaction == Unit.CodeEnumFaction.DominionPlayer then
				self.tSavedData[KEY_CREATURES][id]["dispd"]=unit:GetDispositionTo(self.tPlayer)
			end
			if self.tPlayerFaction == Unit.CodeEnumFaction.ExilesPlayer then
				self.tSavedData[KEY_CREATURES][id]["dispe"]=unit:GetDispositionTo(self.tPlayer)
			end
			self.tSavedData[KEY_CREATURES][id]["aff"]=unit:GetAffiliationName()
			self.tSavedData[KEY_CREATURES][id]["clsid"]=unit:GetClassId()
			self.tSavedData[KEY_CREATURES][id]["diff"]=unit:GetDifficulty()
			self.tSavedData[KEY_CREATURES][id]["eli"]=unit:GetEliteness()
			self.tSavedData[KEY_CREATURES][id]["fact"]=unit:GetFaction()
			self.tSavedData[KEY_CREATURES][id]["sh"]=unit:GetShieldCapacityMax()
			self.tSavedData[KEY_CREATURES][id]["nplc"]=unit:GetNameplateColor()
			self.tSavedData[KEY_CREATURES][id]["race"]=unit:GetRaceId()
			self.tSavedData[KEY_CREATURES][id]["type"]=unit:GetType()
			self.tSavedData[KEY_CREATURES][id]["rank"]=unit:GetRank()
			if unit:GetArchetype() then
				self.tSavedData[KEY_CREATURES][id]["at_id"]=unit:GetArchetype()["id"]
				self.tSavedData[KEY_CREATURES][id]["at_ic"]=unit:GetArchetype()["icon"]
			end
			self.tSavedData[KEY_CREATURES][id]["sex"]=unit:GetGender()
			
--initialized on demand, saves space
--[[			self.tSavedData[KEY_CREATURES][id]["q"]={}
			self.tSavedData[KEY_CREATURES][id]["pe"]={}
			self.tSavedData[KEY_CREATURES][id]["chg"]={}]]
			self.tSavedData[KEY_CREATURES][id]["lvlmin"]=unit:GetLevel()
			self.tSavedData[KEY_CREATURES][id]["lvlmax"]=unit:GetLevel()
			self.tSavedData[KEY_CREATURES][id]["hpmin"]=unit:GetMaxHealth()
			self.tSavedData[KEY_CREATURES][id]["hpmax"]=unit:GetMaxHealth()
		end
		
		-- merge stuff
		
--[[		local tMarkerInfoList = self:GetOrderedMarkerInfos(tMarkers)
		for nIdx, tMarkerInfo in ipairs(tMarkerInfoList) do
			local tInfo = self:GetDefaultUnitInfo()
			if tMarkerInfo.strIcon  then
			tInfo.strIcon = tMarkerInfo.strIcon
		end

		self.tSavedData[KEY_CREATURES][id]["mmm"]=unit:GetMiniMapMarker()]]
		
		if checkForInvLooter then
			local fac=unit:GetFacing()
			if fac then
				if fac.x==-0 and fac.y==0 and fac.z==-1 then
					self.tSavedData[KEY_CREATURES][id]["looter"]=1
				end
			end
		end
		
		--lvl and hp range
		if unit:GetLevel() then
			if self.tSavedData[KEY_CREATURES][id]["lvlmin"] then
				if tonumber(unit:GetLevel())<tonumber(self.tSavedData[KEY_CREATURES][id]["lvlmin"]) then
					self.tSavedData[KEY_CREATURES][id]["lvlmin"]=unit:GetLevel()
				end
			else
				self.tSavedData[KEY_CREATURES][id]["lvlmin"]=unit:GetLevel()
			end
			if self.tSavedData[KEY_CREATURES][id]["lvlmax"] then
				if tonumber(unit:GetLevel())>tonumber(self.tSavedData[KEY_CREATURES][id]["lvlmax"]) then
					self.tSavedData[KEY_CREATURES][id]["lvlmax"]=unit:GetLevel()
				end
			else
				self.tSavedData[KEY_CREATURES][id]["lvlmax"]=unit:GetLevel()
			end
		end
		if unit:GetMaxHealth() then
			if self.tSavedData[KEY_CREATURES][id]["hpmin"] then
				if tonumber(unit:GetMaxHealth())<tonumber(self.tSavedData[KEY_CREATURES][id]["hpmin"]) then
					self.tSavedData[KEY_CREATURES][id]["hpmin"]=unit:GetMaxHealth()
				end
			else
				self.tSavedData[KEY_CREATURES][id]["hpmin"]=unit:GetMaxHealth()
			end
			if self.tSavedData[KEY_CREATURES][id]["hpmax"] then
				if tonumber(unit:GetMaxHealth())>tonumber(self.tSavedData[KEY_CREATURES][id]["hpmax"]) then
					self.tSavedData[KEY_CREATURES][id]["hpmax"]=unit:GetMaxHealth()
				end
			else
				self.tSavedData[KEY_CREATURES][id]["hpmax"]=unit:GetMaxHealth()
			end
		end
		
		--location
		if self.tSavedData[KEY_CREATURES][id]["zone"][upos.x.."/"..upos.y.."/"..upos.z] == nil then
			if creatureLocationCached[unit:GetId()] == nil then
				self.tSavedData[KEY_CREATURES][id]["zone"][upos.x.."/"..upos.y.."/"..upos.z]=1
				creatureLocationCached[unit:GetId()]=1
			end
		end
		--keysets
--[[		local keyset=self.tSavedData[KEY_CREATURES][id]["as"]
		if keyset==nil then
			keyset=""
		end]]
		local as = unit:GetActivationState()
		lastDatacube = nil
		if as then
			if self.tSavedData[KEY_CREATURES][id]["as2"] == nil then
				self.tSavedData[KEY_CREATURES][id]["as2"]={}
			end
			for k,v in pairs(as) do
				self.tSavedData[KEY_CREATURES][id]["as2"][k]=1
--[[				if keyset ~= "" then
					keyset=keyset..","
				end
				keyset=keyset..k]]
				if k=="Datacube" then
					lastDatacube = id
				end
			end
		end
--		self.tSavedData[KEY_CREATURES][id]["as"]=keyset
		--rewardinfo
		local ri = unit:GetRewardInfo()
		if self.tSavedData[KEY_CREATURES][id]["q"]==nil then
			self.tSavedData[KEY_CREATURES][id]["q"]={}
		end
		if self.tSavedData[KEY_CREATURES][id]["pe"]==nil then
			self.tSavedData[KEY_CREATURES][id]["pe"]={}
		end
		if self.tSavedData[KEY_CREATURES][id]["chg"]==nil then
			self.tSavedData[KEY_CREATURES][id]["chg"]={}
		end
		if ri then
			for k,v in pairs(ri) do
				if v.strType=="Quest" then
					if self.tSavedData[KEY_CREATURES][id]["q"]==nil then
						self.tSavedData[KEY_CREATURES][id]["q"]={}
					end
					self.tSavedData[KEY_CREATURES][id]["q"][v.idQuest]=1
				end

				if v.strType=="PublicEvent" then
					if self.tSavedData[KEY_CREATURES][id]["pe"]==nil then
						self.tSavedData[KEY_CREATURES][id]["pe"]={}
					end
					local peo=v.peoObjective
					local pe=v.peoObjective:GetEvent()
					
					local peid=self:AddPublicEvent(pe)
					if peid ~= -1 then
--					local peid=self.tZone.id.."/"..pe:GetName()
						self.tSavedData[KEY_CREATURES][id]["pe"][peid]=1
						if self.tSavedData[KEY_PUBLIC_EVENT][peid]["realzone"]==nil then
							self.tSavedData[KEY_PUBLIC_EVENT][peid]["realzone"]=self.tZone.id
						else
							if self.tSavedData[KEY_PUBLIC_EVENT][peid]["realzone"] ~= self.tZone.id then
								self.tSavedData[KEY_PUBLIC_EVENT][peid]["realzone"] = -1
							end
						end
					end
				end
				
				if v.strType=="Challenge" then
					if self.tSavedData[KEY_CREATURES][id]["chg"]==nil then
						self.tSavedData[KEY_CREATURES][id]["chg"]={}
					end
					self.tSavedData[KEY_CREATURES][id]["chg"][v.idChallenge]=1
				end
				
				if v.strType=="Scientist" then
					self.tSavedData[KEY_CREATURES][id]["p_sci"]=true
					if v.pmMission then
						if self.tSavedData[KEY_CREATURES][id]["pathm"]==nil then
							self.tSavedData[KEY_CREATURES][id]["pathm"]={}
						end
						self.tSavedData[KEY_CREATURES][id]["pathm"][v.pmMission:GetId()]=1
						if self.tSavedData[KEY_PATH_MISSION][v.pmMission:GetId()] ~= nil then
							if self.tSavedData[KEY_PATH_MISSION][v.pmMission:GetId()]["rz"] == nil then
								self.tSavedData[KEY_PATH_MISSION][v.pmMission:GetId()]["rz"]=self.tZone.id
							else
								if self.tSavedData[KEY_PATH_MISSION][v.pmMission:GetId()]["rz"] ~= self.tZone.id then
									self.tSavedData[KEY_PATH_MISSION][v.pmMission:GetId()]["rz"] = -1
								end
							end
						end
					end
					if v.splReward then
						if self.tSavedData[KEY_CREATURES][id]["spell_sci"]==nil then
							self.tSavedData[KEY_CREATURES][id]["spell_sci"]={}
						end
						self:AddSpell(v.splReward)
						self.tSavedData[KEY_CREATURES][id]["spell_sci"][v.splReward:GetId()]=1
					end
				end
				if v.strType=="Soldier" then
					self.tSavedData[KEY_CREATURES][id]["p_sol"]=true
					if v.pmMission then
						if self.tSavedData[KEY_CREATURES][id]["pathm"]==nil then
							self.tSavedData[KEY_CREATURES][id]["pathm"]={}
						end
						self.tSavedData[KEY_CREATURES][id]["pathm"][v.pmMission:GetId()]=1
						if self.tSavedData[KEY_PATH_MISSION][v.pmMission:GetId()] ~= nil then
							if self.tSavedData[KEY_PATH_MISSION][v.pmMission:GetId()]["rz"] == nil then
								self.tSavedData[KEY_PATH_MISSION][v.pmMission:GetId()]["rz"]=self.tZone.id
							else
								if self.tSavedData[KEY_PATH_MISSION][v.pmMission:GetId()]["rz"] ~= self.tZone.id then
									self.tSavedData[KEY_PATH_MISSION][v.pmMission:GetId()]["rz"] = -1
								end
							end
						end
					end
				end
				if v.strType=="Settler" then
					self.tSavedData[KEY_CREATURES][id]["p_set"]=true
					if v.pmMission then
						if self.tSavedData[KEY_CREATURES][id]["pathm"]==nil then
							self.tSavedData[KEY_CREATURES][id]["pathm"]={}
						end
						self.tSavedData[KEY_CREATURES][id]["pathm"][v.pmMission:GetId()]=1
						if self.tSavedData[KEY_PATH_MISSION][v.pmMission:GetId()] ~= nil then
							if self.tSavedData[KEY_PATH_MISSION][v.pmMission:GetId()]["rz"] == nil then
								self.tSavedData[KEY_PATH_MISSION][v.pmMission:GetId()]["rz"]=self.tZone.id
							else
								if self.tSavedData[KEY_PATH_MISSION][v.pmMission:GetId()]["rz"] ~= self.tZone.id then
									self.tSavedData[KEY_PATH_MISSION][v.pmMission:GetId()]["rz"] = -1
								end
							end
						end
					end
				end
				if v.strType=="Explorer" then
					self.tSavedData[KEY_CREATURES][id]["p_exp"]=true
					if v.pmMission then
						if self.tSavedData[KEY_CREATURES][id]["pathm"]==nil then
							self.tSavedData[KEY_CREATURES][id]["pathm"]={}
						end
						self.tSavedData[KEY_CREATURES][id]["pathm"][v.pmMission:GetId()]=1
						if self.tSavedData[KEY_PATH_MISSION][v.pmMission:GetId()] ~= nil then
							if self.tSavedData[KEY_PATH_MISSION][v.pmMission:GetId()]["rz"] == nil then
								self.tSavedData[KEY_PATH_MISSION][v.pmMission:GetId()]["rz"]=self.tZone.id
							else
								if self.tSavedData[KEY_PATH_MISSION][v.pmMission:GetId()]["rz"] ~= self.tZone.id then
									self.tSavedData[KEY_PATH_MISSION][v.pmMission:GetId()]["rz"] = -1
								end
							end
						end
					end
				end
			end
		end
	end
end

function Jabbithole:AddTitle(title, category, full)
	if title and category then
		if self.tSavedData[KEY_TITLES] == nil then
			self.tSavedData[KEY_TITLES]={}
		end

		if self.tPlayer == nil then
			self.tPlayer = GameLib.GetPlayerUnit()
		end
		
		local key=title.."//"..category
		if self.tSavedData[KEY_TITLES][key] == nil then
			if self.tPlayer:GetName() ~= "" then
				--TODO "" names
				self.tSavedData[KEY_TITLES][key]={}
			end
		end

		if self.tSavedData[KEY_TITLES][key]~=nil then
			if self.tPlayer:GetName() ~= "" then
				local t,c = full:gsub(self.tPlayer:GetName(),"<name>")
				self.tSavedData[KEY_TITLES][key]["title"]=t
			end
			if self.tPlayerFaction == Unit.CodeEnumFaction.DominionPlayer then
				self.tSavedData[KEY_TITLES][key]["side_d"]=true
			end
			if self.tPlayerFaction == Unit.CodeEnumFaction.ExilesPlayer then
				self.tSavedData[KEY_TITLES][key]["side_e"]=true
			end
		end
		
	end
end

function Jabbithole:AddDatacube(id, isvolume, datacube)
	if datacube then
		if self.tSavedData[KEY_DATACUBE] == nil then
			self.tSavedData[KEY_DATACUBE]={}
		end
		
		if self.tSavedData[KEY_DATACUBE][id] == nil then
			self.tSavedData[KEY_DATACUBE][id]={}
			self.tSavedData[KEY_DATACUBE][id]["npc"]={}
		end
		self.tSavedData[KEY_DATACUBE][id]["dctype"]=datacube.eDatacubeType
		self.tSavedData[KEY_DATACUBE][id]["dcid"]=datacube.nDatacubeId
		self.tSavedData[KEY_DATACUBE][id]["volid"]=datacube.nVolumeId
		self.tSavedData[KEY_DATACUBE][id]["wzid"]=datacube.nWorldZoneId
		self.tSavedData[KEY_DATACUBE][id]["title"]=datacube.strTitle
		self.tSavedData[KEY_DATACUBE][id]["text"]=datacube.strText
		self.tSavedData[KEY_DATACUBE][id]["isvol"]="-"
		if isvolume then
			self.tSavedData[KEY_DATACUBE][id]["isvol"]="+"
		end
		if lastDatacube then
			self.tSavedData[KEY_DATACUBE][id]["npc"][lastDatacube]=1
			lastDatacube=nil
		end
	end
end

function Jabbithole:AddChallenge(chg)
	if chg then
		if self.tSavedData[KEY_CHALLENGE] == nil then
			self.tSavedData[KEY_CHALLENGE]={}
		end
		
		local id=chg:GetId()
		if self.tSavedData[KEY_CHALLENGE][id] == nil then
			self.tSavedData[KEY_CHALLENGE][id]={}
		end
		
		if self.tSavedData[KEY_CHALLENGE][id]["loc"]==nil then
			self.tSavedData[KEY_CHALLENGE][id]["loc"]={}
		end
		if self.tSavedData[KEY_CHALLENGE][id]["rew"]==nil then
			self.tSavedData[KEY_CHALLENGE][id]["rew"]={}
		end

		self.tSavedData[KEY_CHALLENGE][id]["zone"]=self.tZone.id
		self.tSavedData[KEY_CHALLENGE][id]["name"]=chg:GetName()
		self.tSavedData[KEY_CHALLENGE][id]["type"]=chg:GetType()
		self.tSavedData[KEY_CHALLENGE][id]["desc"]=chg:GetDescription()
		self.tSavedData[KEY_CHALLENGE][id]["timed"]=chg:IsTimeTiered()
		local goals=""
		for idx,goal in pairs(chg:GetAllTierCounts() or {}) do
			if idx>1 then
				goals=goals.."/"
			end
			goals=goals..goal.nGoalCount
		end
		self.tSavedData[KEY_CHALLENGE][id]["goals"]=goals

		--merge
		if self.tPlayerFaction == Unit.CodeEnumFaction.DominionPlayer then
			self.tSavedData[KEY_CHALLENGE][id]["side_d"]=true
		end
		if self.tPlayerFaction == Unit.CodeEnumFaction.ExilesPlayer then
			self.tSavedData[KEY_CHALLENGE][id]["side_e"]=true
		end
		
		loc = chg:GetMapLocation(chg)
		if loc then
			self.tSavedData[KEY_CHALLENGE][id]["loc"][loc.x.."/"..loc.y.."/"..loc.z]=1
		end
	end
end

function Jabbithole:AddChallengeReward(chgid, reward)
	if reward~=nil and reward.itemReward~=nil then
		local id=chgid
		if self.tSavedData[KEY_CHALLENGE][id] ~= nil then
			self:AddItem(reward.itemReward,-1,nil,true)
			self.tSavedData[KEY_CHALLENGE][id]["rew"][reward.nRewardId]=reward.nAmount.."/"..reward.itemReward:GetChatLinkString().."/"..reward.nChallengeTier
		end
	end
end

function Jabbithole:FindPublicEvent(e)
	local game_id=-1

	for idx,pe in pairs(PublicEventsLib.GetActivePublicEventList() or {}) do
		if pe then
			if pe:GetName()==e:GetName() then
				game_id=idx
			end
		end
	end

	return game_id
end

function Jabbithole:AddPublicEventMission(peid, name, desc)
	if self.tSavedData[KEY_PUBLIC_EVENT][peid]["miss"] == nil then
		self.tSavedData[KEY_PUBLIC_EVENT][peid]["miss"]={}
	end
	self.tSavedData[KEY_PUBLIC_EVENT][peid]["miss"][name]=desc
end

function Jabbithole:AddPublicEvent(e,updateRZ)
	local game_id=-1
	if self.bInitializedProperly then
	if e then
		if self.tSavedData[KEY_PUBLIC_EVENT] == nil then
			self.tSavedData[KEY_PUBLIC_EVENT]={}
		end
		
		game_id=self:FindPublicEvent(e)
		
		if game_id ~= -1 then
			local id=game_id
			if self.tSavedData[KEY_PUBLIC_EVENT][id] == nil then
				self.tSavedData[KEY_PUBLIC_EVENT][id]={}
--				self.tSavedData[KEY_PUBLIC_EVENT][id]["id"]=game_id
				self.tSavedData[KEY_PUBLIC_EVENT][id]["name"]=e:GetName()
				self.tSavedData[KEY_PUBLIC_EVENT][id]["type"]=e:GetEventType()
				self.tSavedData[KEY_PUBLIC_EVENT][id]["rtype"]=e:GetRewardType()
				self.tSavedData[KEY_PUBLIC_EVENT][id]["zone"]={}
				self.tSavedData[KEY_PUBLIC_EVENT][id]["loc"]={}
				self.tSavedData[KEY_PUBLIC_EVENT][id]["obj"]={}
				
				local p = e:GetParentEvent()
				if p then
					self.tSavedData[KEY_PUBLIC_EVENT][id]["p"]=self:AddPublicEvent(p)
				end
			end

			--merge
			
			if e:IsActive() then
				self.tSavedData[KEY_PUBLIC_EVENT][id]["zone"][self.tZone.id]=1
				if updateRZ then
					if self.tSavedData[KEY_PUBLIC_EVENT][id]["realzone"]==nil then
						self.tSavedData[KEY_PUBLIC_EVENT][id]["realzone"]=self.tZone.id
					else
						if self.tSavedData[KEY_PUBLIC_EVENT][id]["realzone"] ~= self.tZone.id then
							self.tSavedData[KEY_PUBLIC_EVENT][id]["realzone"] = -1
						end
					end
				end
			end
			
			if self.tPlayerFaction == Unit.CodeEnumFaction.DominionPlayer then
				self.tSavedData[KEY_PUBLIC_EVENT][id]["side_d"]=true
			end
			if self.tPlayerFaction == Unit.CodeEnumFaction.ExilesPlayer then
				self.tSavedData[KEY_PUBLIC_EVENT][id]["side_e"]=true
			end
				
			for idx,upos in pairs(e:GetLocations()) do
				self.tSavedData[KEY_PUBLIC_EVENT][id]["loc"][upos.x.."/"..upos.y.."/"..upos.z]=1
			end
			for idx,obj in pairs(e:GetObjectives()) do
				local v=obj:GetCategory().."//"..obj:GetObjectiveId().."//"
				if obj:GetObjectiveType() then
					v = v .. obj:GetObjectiveType()
				end
				self.tSavedData[KEY_PUBLIC_EVENT][id]["obj"][obj:GetDescription()]=v
				--local peop=obj:GetParentObjective() id or object?
			end
		end
			
	end
	end
	return game_id
end

function Jabbithole:AddPathEpisode(e)
	if self.bInitializedProperly then
	if e then
		if self.tSavedData[KEY_PATH_EPISODE] == nil then
			self.tSavedData[KEY_PATH_EPISODE]={}
		end

		local path=PlayerPathLib.GetPlayerPathType()
		local id=path.."/"..e:GetWorldZone()
		if self.tSavedData[KEY_PATH_EPISODE][id] == nil then
			self.tSavedData[KEY_PATH_EPISODE][id]={}
			self.tSavedData[KEY_PATH_EPISODE][id]["z"]={}
			self.tSavedData[KEY_PATH_EPISODE][id]["pm"]={}
		end
		if self.tSavedData[KEY_PATH_EPISODE][id]["rew"] == nil then
			self.tSavedData[KEY_PATH_EPISODE][id]["rew"]={}
		end
		self.tSavedData[KEY_PATH_EPISODE][id]["z"][self.tZone.id]=1
			
		self.tSavedData[KEY_PATH_EPISODE][id]["name"]=e:GetName()
		self.tSavedData[KEY_PATH_EPISODE][id]["sum"]=e:GetSummary()

		if self.tPlayerFaction == Unit.CodeEnumFaction.DominionPlayer then
			self.tSavedData[KEY_PATH_EPISODE][id]["side_d"]=true
		end
		if self.tPlayerFaction == Unit.CodeEnumFaction.ExilesPlayer then
			self.tSavedData[KEY_PATH_EPISODE][id]["side_e"]=true
		end

		for idx,reward in pairs(e:GetRewards() or {}) do
			if reward.eType == PlayerPathLib.PathRewardType_Item and reward.itemReward then
				self:AddItem(reward.itemReward ,-1,nil,true)
				self.tSavedData[KEY_PATH_EPISODE][id]["rew"][reward.itemReward:GetChatLinkString()]=reward.nCount
			end
		end
	
		for idx,miss in pairs(e:GetMissions() or {}) do
			if miss:GetName() ~= "" then
				self:AddPathMission(path,miss)
				self.tSavedData[KEY_PATH_EPISODE][id]["pm"][miss:GetId()]=1
			end
		end
	end
	end
end

function Jabbithole:AddPathMission(path,m,z)
	if m then
		if self.tSavedData[KEY_PATH_MISSION] == nil then
			self.tSavedData[KEY_PATH_MISSION]={}
		end
		if m:GetName() ~= "" then
			local id=m:GetId()
			if self.tSavedData[KEY_PATH_MISSION][id] == nil then
				self.tSavedData[KEY_PATH_MISSION][id]={}
				self.tSavedData[KEY_PATH_MISSION][id]["p"]=path
				self.tSavedData[KEY_PATH_MISSION][id]["done"]=m:GetCompletedString()
				self.tSavedData[KEY_PATH_MISSION][id]["name"]=m:GetName()
				self.tSavedData[KEY_PATH_MISSION][id]["needed"]=m:GetNumNeeded()
				self.tSavedData[KEY_PATH_MISSION][id]["xp"]=m:GetRewardXp()
				if m:GetSpell() then
					self.tSavedData[KEY_PATH_MISSION][id]["spell"]=m:GetSpell():GetId()
				end
				self.tSavedData[KEY_PATH_MISSION][id]["type"]=m:GetType()
				self.tSavedData[KEY_PATH_MISSION][id]["stype"]=m:GetSubType()
				self.tSavedData[KEY_PATH_MISSION][id]["sum"]=m:GetSummary()
				self.tSavedData[KEY_PATH_MISSION][id]["unl"]=m:GetUnlockString()
				self.tSavedData[KEY_PATH_MISSION][id]["loc"]={}
			end

			if self.tPlayerFaction == Unit.CodeEnumFaction.DominionPlayer then
				self.tSavedData[KEY_PATH_MISSION][id]["side_d"]=true
			end
			if self.tPlayerFaction == Unit.CodeEnumFaction.ExilesPlayer then
				self.tSavedData[KEY_PATH_MISSION][id]["side_e"]=true
			end
								
			for idx,loc in pairs(m:GetMapLocations() or {}) do
				self.tSavedData[KEY_PATH_MISSION][id]["loc"][loc.x.."/"..loc.y.."/"..loc.z]=1
			end
			
			if z then
				self.tSavedData[KEY_PATH_MISSION][id]["rz"]=self.tZone.id
			end
		end
	end
end

function Jabbithole:AddSchematic(id,tsid)
	if tsid and id then
		if self.tSavedData[KEY_SCHEMATIC] == nil then
			self.tSavedData[KEY_SCHEMATIC]={}
		end
		
		if self.tSavedData[KEY_SCHEMATIC][tsid]==nil then
			self.tSavedData[KEY_SCHEMATIC][tsid]={}
		end
		
		local sch=CraftingLib.GetSchematicInfo(id)
		if sch then
			if self.tSavedData[KEY_SCHEMATIC][tsid][id]==nil then
				self.tSavedData[KEY_SCHEMATIC][tsid][id]={}
			end
			self.tSavedData[KEY_SCHEMATIC][tsid][id]["tier"]=sch.eTier
			if sch.itemOutput then
				self:AddItem(sch.itemOutput,-1,nil,false)
				self.tSavedData[KEY_SCHEMATIC][tsid][id]["item"]=sch.itemOutput:GetChatLinkString()
			end
			self.tSavedData[KEY_SCHEMATIC][tsid][id]["xp"]=sch.nCraftXp.."/"..sch.nFailXp.."/"..sch.nLearnXp
			self.tSavedData[KEY_SCHEMATIC][tsid][id]["count"]=sch.nCreateCount.."/"..sch.nCritCount
			self.tSavedData[KEY_SCHEMATIC][tsid][id]["parent"]=sch.nParentSchematicId
			-- workaround attempt for missing parent schematics
			-- possible endless loop?
			if sch.nParentSchematicId ~= 0 and self.tSavedData[KEY_SCHEMATIC][tsid][sch.nParentSchematicId] == nil then
				self:AddSchematic(sch.nParentSchematicId,tsid)
			end
			self.tSavedData[KEY_SCHEMATIC][tsid][id]["maxadd"]=sch.nMaxAdditives
			self.tSavedData[KEY_SCHEMATIC][tsid][id]["maxcat"]=sch.nMaxCatalysts
			self.tSavedData[KEY_SCHEMATIC][tsid][id]["name"]=sch.strName
			
			if #sch.tMaterials > 0 then
				self.tSavedData[KEY_SCHEMATIC][tsid][id]["mats"]={}
				for idx,mat in pairs(sch.tMaterials or {}) do
					if mat.itemMaterial then
						self:AddItem(mat.itemMaterial,-1,nil,false)
						self.tSavedData[KEY_SCHEMATIC][tsid][id]["mats"][mat.itemMaterial:GetChatLinkString()]=mat.nAmount
					end
				end
			end
			if #sch.tSubRecipes > 0 then
				self.tSavedData[KEY_SCHEMATIC][tsid][id]["subs"]={}
				for idx,subrec in pairs(sch.tSubRecipes or {}) do
					self:AddSchematic(subrec.nSchematicId,tsid)
					self.tSavedData[KEY_SCHEMATIC][tsid][id]["subs"][subrec.nSchematicId]=1
				end
			end
			if #sch.tSockets > 0 then
				self.tSavedData[KEY_SCHEMATIC][tsid][id]["sock"]={}
				for idx,sock in pairs(sch.tSockets or {}) do
					local sd=""
					if sock.bIsChangeable then
						sd="+"
					else
						sd="-"
					end
					sd=sd.."/"..sock.eSocketType.."/"..sock.fRatio.."/"..sock.nParent.."/"
					if sock.itemDefaultChip ~= nil then
						self:AddItem(sock.itemDefaultChip,-1,nil,false)
						sd=sd..sock.itemDefaultChip:GetChatLinkString()
					end
					self.tSavedData[KEY_SCHEMATIC][tsid][id]["sock"][idx]=sd
				end
			end
		end
	end
end

function Jabbithole:AddTradeskillTalents(id)
	if id then
		if self.tSavedData[KEY_TRADESKILL_TALENT] == nil then
			self.tSavedData[KEY_TRADESKILL_TALENT]={}
		end
		
		if self.tSavedData[KEY_TRADESKILL_TALENT][id]==nil then
			self.tSavedData[KEY_TRADESKILL_TALENT][id]={}
		end
			
		local talents=CraftingLib.GetTradeskillTalents(id)
		if talents and #talents>0 then
			for idx,tier in pairs(talents) do
				self.tSavedData[KEY_TRADESKILL_TALENT][id][idx]={}
				self.tSavedData[KEY_TRADESKILL_TALENT][id][idx]["p"]=tier.nPointsRequired
				self.tSavedData[KEY_TRADESKILL_TALENT][id][idx]["t"]={}
				for idx2,talent in pairs(tier.tTalents or {}) do
					self.tSavedData[KEY_TRADESKILL_TALENT][id][idx]["t"][talent.nTalentId]={}
					self.tSavedData[KEY_TRADESKILL_TALENT][id][idx]["t"][talent.nTalentId]["n"]=talent.strName
					self.tSavedData[KEY_TRADESKILL_TALENT][id][idx]["t"][talent.nTalentId]["i"]=talent.strIcon
					self.tSavedData[KEY_TRADESKILL_TALENT][id][idx]["t"][talent.nTalentId]["t"]=talent.strTooltip
				end
			end
		end
	end
end

function Jabbithole:AddTradeskill(id,ts)
	if ts and id and ts.bIsActive then
		if self.tSavedData[KEY_TRADESKILL] == nil then
			self.tSavedData[KEY_TRADESKILL]={}
		end
		
		if self.tSavedData[KEY_TRADESKILL][id]==nil then
			self.tSavedData[KEY_TRADESKILL][id]={}
		end

		self.tSavedData[KEY_TRADESKILL][id]["hobby"]=ts.bIsHobby
		self.tSavedData[KEY_TRADESKILL][id]["harv"]=ts.bIsHarvesting
		self.tSavedData[KEY_TRADESKILL][id]["tmax"]=ts.nTierMax
		self.tSavedData[KEY_TRADESKILL][id]["desc"]=ts.strDescription
		self.tSavedData[KEY_TRADESKILL][id]["name"]=ts.strName
		-- TODO:
		-- tAxisNames??
		-- tTalentTiers??
		-- tXpTiers??
		
		local grps=AchievementsLib.GetTradeskillAchievementCategoryTree(id)
		if grps ~= nil then
			self.tSavedData[KEY_TRADESKILL][id]["agrpid"]=grps.nGroupId
			self.tSavedData[KEY_TRADESKILL][id]["agrpname"]=grps.strGroupName

			local side=nil
			if self.tPlayerFaction == Unit.CodeEnumFaction.DominionPlayer then
				side="dom"
			end
			if self.tPlayerFaction == Unit.CodeEnumFaction.ExilesPlayer then
				side="exi"
			end
			
			if side then
				local tiersidekey = "tiers"..side
				self.tSavedData[KEY_TRADESKILL][id][tiersidekey]={}
				
				for idx,tier in pairs(grps.tSubGroups or {}) do
					self.tSavedData[KEY_TRADESKILL][id][tiersidekey][idx]={}
					self.tSavedData[KEY_TRADESKILL][id][tiersidekey][idx]["agrpid"]=tier.nSubGroupId
					self.tSavedData[KEY_TRADESKILL][id][tiersidekey][idx]["agrpname"]=tier.strSubGroupName
					self.tSavedData[KEY_TRADESKILL][id][tiersidekey][idx]["tree"]={}
					local tree=AchievementsLib.GetTradeskillAchievementLayout(tier.nSubGroupId)
					for idx2,treenode in pairs(tree or {}) do
					
						--Print("XX: "..id.." "..tier.nSubGroupId.." "..idx2)
					
						self.tSavedData[KEY_TRADESKILL][id][tiersidekey][idx]["tree"][idx2]={}
						self.tSavedData[KEY_TRADESKILL][id][tiersidekey][idx]["tree"][idx2]["id"]=treenode:GetId()
						self.tSavedData[KEY_TRADESKILL][id][tiersidekey][idx]["tree"][idx2]["name"]=nlFix(treenode:GetName())
						self.tSavedData[KEY_TRADESKILL][id][tiersidekey][idx]["tree"][idx2]["desc"]=nlFix(treenode:GetDescription())
						self.tSavedData[KEY_TRADESKILL][id][tiersidekey][idx]["tree"][idx2]["num"]=treenode:GetNumNeeded()
						self.tSavedData[KEY_TRADESKILL][id][tiersidekey][idx]["tree"][idx2]["pts"]=treenode:GetPoints()
						self.tSavedData[KEY_TRADESKILL][id][tiersidekey][idx]["tree"][idx2]["ptxt"]=treenode:GetProgressText()
						local lo=treenode:GetTradeskillLayout()
						self.tSavedData[KEY_TRADESKILL][id][tiersidekey][idx]["tree"][idx2]["lox"]=lo.x
						self.tSavedData[KEY_TRADESKILL][id][tiersidekey][idx]["tree"][idx2]["loy"]=lo.y
						self.tSavedData[KEY_TRADESKILL][id][tiersidekey][idx]["tree"][idx2]["lop"]={}
						for idx3,par in pairs(lo.arParents or {}) do
							self.tSavedData[KEY_TRADESKILL][id][tiersidekey][idx]["tree"][idx2]["lop"][par.x.."/"..par.y]=1
						end
						local bo=treenode:GetTradeskillRewards()
						if bo ~= nil then
							self.tSavedData[KEY_TRADESKILL][id][tiersidekey][idx]["tree"][idx2]["rwtp"]=bo.nTalentPoints
							self.tSavedData[KEY_TRADESKILL][id][tiersidekey][idx]["tree"][idx2]["rwbon"]={}
							for idx3,bon in pairs(bo.arBonuses or {}) do
								self.tSavedData[KEY_TRADESKILL][id][tiersidekey][idx]["tree"][idx2]["rwbon"][idx3]=bon.strIcon.."//"..bon.strName.."//"..bon.strTooltip
							end
							self.tSavedData[KEY_TRADESKILL][id][tiersidekey][idx]["tree"][idx2]["rwsch"]={}
							for idx3,sch in pairs(bo.arSchematics or {}) do
								self:AddSchematic(sch.idSchematic, id)
								self.tSavedData[KEY_TRADESKILL][id][tiersidekey][idx]["tree"][idx2]["rwsch"][idx3]=sch.idSchematic
							end
						end
						local cl=treenode:GetChecklistItems()
						self.tSavedData[KEY_TRADESKILL][id][tiersidekey][idx]["tree"][idx2]["cl"]={}
						for idx3,cli in pairs(cl or {}) do
							if cli.idSchematic ~= nil then
								self:AddSchematic(cli.idSchematic, id)
								self.tSavedData[KEY_TRADESKILL][id][tiersidekey][idx]["tree"][idx2]["cl"][idx3]=cli.idSchematic.."//"..cli.strChecklistEntry
							else
								self.tSavedData[KEY_TRADESKILL][id][tiersidekey][idx]["tree"][idx2]["cl"][idx3]="//"..cli.strChecklistEntry
							end
						end
					end
				end
			end
					
		end
		
		local schs=nil
		if self.tSavedData[KEY_SCHEMATIC]==nil or self.tSavedData[KEY_SCHEMATIC][id]==nil then
			schs=CraftingLib.GetSchematicList(id,nil,nil,true)
		else
			schs=CraftingLib.GetSchematicList(id)
		end
		for idx,sch in pairs(schs or {}) do
			self:AddSchematic(sch.nSchematicId, id)
		end
		
		self:AddTradeskillTalents(id)
		Apollo.StartTimer("TradeskillScanner")
	end
end

function Jabbithole:OnTradeskillTimer()
--	Print("TST "..self.tradeskillIndex)
	if self.tradeskillIndex and self.tradeskillsToScan and self.tradeskillsToScan[self.tradeskillIndex] then
		local ts=self.tradeskillsToScan[self.tradeskillIndex]
		local tsi=CraftingLib.GetTradeskillInfo(ts.eId)
		self:AddTradeskill(ts.eId,tsi)
		self.tradeskillIndex = self.tradeskillIndex+1
	else
		self.tSavedData["lasttssave"]=os.time()
	end
end

function Jabbithole:AddTradeskills()
	if self.tSavedData["lasttssave"]==nil or self.tSavedData["lasttssave"]+86400<os.time() then
		self.tradeskillIndex=1
		self.tradeskillsToScan=CraftingLib.GetKnownTradeskills()
		Apollo.RegisterTimerHandler("TradeskillScanner", "OnTradeskillTimer", self)
		Apollo.CreateTimer("TradeskillScanner", 10, false)
		Apollo.StartTimer("TradeskillScanner")
	end
	
--	for idx,ts in pairs(CraftingLib.GetKnownTradeskills() or {}) do
--		local tsi=CraftingLib.GetTradeskillInfo(ts.eId)
--		self:AddTradeskill(ts.eId,tsi)
--	end
end

function Jabbithole:AddReputation(faction, label, group, side)
	if self.tSavedData[KEY_FACTION] == nil then
		self.tSavedData[KEY_FACTION]={}
	end
	
	local key = faction.."//"..group.."//"..label
	local xside = self.tSavedData[KEY_FACTION][key]
	if xside == nil then
		self.tSavedData[KEY_FACTION][key] = side
	else
		if xside + side == 1 then
			self.tSavedData[KEY_FACTION][key] = 2
		end
	end
end

function Jabbithole:AddReputations()
	local r=GameLib.GetReputationInfo()
	local groups={}
	local labels={}

	local side=-1	
	if self.tPlayerFaction == Unit.CodeEnumFaction.DominionPlayer then
		side=0
	end
	if self.tPlayerFaction == Unit.CodeEnumFaction.ExilesPlayer then
		side=1
	end

	if side ~= -1 then
		for idx,rep in pairs(r or {}) do
			if rep.bIsLabel == true and rep.strParent ~= "" then
				labels[rep.strName]=rep.strParent
			end
			if rep.bIsLabel == false and rep.strParent == "" then
				groups[rep.strName]=rep.strName
				self:AddReputation(rep.strName, "", "", side)
			end
		end
		for idx,rep in pairs(r or {}) do
			if rep.bIsLabel == false and rep.strParent ~= "" then
				if labels[rep.strParent] then
					if groups[labels[rep.strParent]] then
						self:AddReputation(rep.strName, rep.strParent, labels[rep.strParent], side)
					end
				else
					if groups[rep.strParent] then
						self:AddReputation(rep.strName, "", rep.strParent, side)
					else
						self:AddReputation(rep.strName, "", rep.strParent, side)
					end
				end
			end
		end
	end
end

function Jabbithole:AddHousingDecorType(dt)
	if self.tSavedData[KEY_HOUSE_DECORTYPE] == nil then
		self.tSavedData[KEY_HOUSE_DECORTYPE]={}
	end
	if dt then
		local id = dt.nId
		if self.tSavedData[KEY_HOUSE_DECORTYPE][id] == nil then
			self.tSavedData[KEY_HOUSE_DECORTYPE][id]={}
		end
		self.tSavedData[KEY_HOUSE_DECORTYPE][id]["id"] = id
		self.tSavedData[KEY_HOUSE_DECORTYPE][id]["name"] = dt.strName
	end
end

function Jabbithole:AddHousingDecor(deco)
	if self.tSavedData[KEY_HOUSE_DECOR] == nil then
		self.tSavedData[KEY_HOUSE_DECOR]={}
	end
	if deco then
		local id = deco.nId
		if self.tSavedData[KEY_HOUSE_DECOR][id] == nil then
			self.tSavedData[KEY_HOUSE_DECOR][id]={}
		end
		self.tSavedData[KEY_HOUSE_DECOR][id]["id"] = id
		self.tSavedData[KEY_HOUSE_DECOR][id]["name"] = deco.strName
		self.tSavedData[KEY_HOUSE_DECOR][id]["curr"] = deco.eCurrencyType
		self.tSavedData[KEY_HOUSE_DECOR][id]["etype"] = deco.eDecorType
		self.tSavedData[KEY_HOUSE_DECOR][id]["gcurr"] = deco.eGroupCurrencyType
		self.tSavedData[KEY_HOUSE_DECOR][id]["cost"] = deco.nCost
		if deco.splBuff then
			self:AddSpell(deco.splBuff)
			self.tSavedData[KEY_HOUSE_DECOR][id]["spl"] = deco.splBuff:GetId()
		end
	end
end

function Jabbithole:AddHousingDecorCrate(deco)
	if self.tSavedData[KEY_HOUSE_DECOR] == nil then
		self.tSavedData[KEY_HOUSE_DECOR]={}
	end
	if deco then
		local id = deco.nId
		if self.tSavedData[KEY_HOUSE_DECOR][id] == nil then
			self.tSavedData[KEY_HOUSE_DECOR][id]={}
		end
		self.tSavedData[KEY_HOUSE_DECOR][id]["id"] = id
		self.tSavedData[KEY_HOUSE_DECOR][id]["name"] = deco.strName
		self.tSavedData[KEY_HOUSE_DECOR][id]["etype"] = deco.eDecorType
		if deco.splBuff then
			self:AddSpell(deco.splBuff)
			self.tSavedData[KEY_HOUSE_DECOR][id]["spl"] = deco.splBuff:GetId()
		end
	end
end

function Jabbithole:AddHousingPlot(plot, parentId)
	if self.tSavedData[KEY_HOUSE_PLOTS] == nil then
		self.tSavedData[KEY_HOUSE_PLOTS]={}
	end
	if plot then
		local id = plot.nId
		if self.tSavedData[KEY_HOUSE_PLOTS][id] == nil then
			self.tSavedData[KEY_HOUSE_PLOTS][id]={}
		end
		self.tSavedData[KEY_HOUSE_PLOTS][id]["id"] = id
		self.tSavedData[KEY_HOUSE_PLOTS][id]["etype"] = plot.eType
		self.tSavedData[KEY_HOUSE_PLOTS][id]["parent"] = parentId
		self.tSavedData[KEY_HOUSE_PLOTS][id]["cost"] = plot.nCost
		self.tSavedData[KEY_HOUSE_PLOTS][id]["name"] = plot.strName
		self.tSavedData[KEY_HOUSE_PLOTS][id]["desc"] = plot.strTooltip
		self.tSavedData[KEY_HOUSE_PLOTS][id]["shots"] = {}
		for idx, shot in pairs(plot.tScreenshots or {}) do
			if shot.strSprite then
				self.tSavedData[KEY_HOUSE_PLOTS][id]["shots"][idx]=shot.strSprite
			end
		end
		self.tSavedData[KEY_HOUSE_PLOTS][id]["prereq"] = {}
		for idx, pre in pairs(plot.tPrerequisites or {}) do
			if pre.strTooltip then
				self.tSavedData[KEY_HOUSE_PLOTS][id]["prereq"][idx]=pre.strTooltip 
			end
		end
		self.tSavedData[KEY_HOUSE_PLOTS][id]["cost"] = {}
		for idx, cost in pairs(plot.tCostRequirements or {}) do
			self.tSavedData[KEY_HOUSE_PLOTS][id]["cost"][idx]={}
			self.tSavedData[KEY_HOUSE_PLOTS][id]["cost"][idx]["etype"]=cost.eType
			self.tSavedData[KEY_HOUSE_PLOTS][id]["cost"][idx]["amo"]=cost.nRequiredCost
			if cost.itemCostReq then
				self.tSavedData[KEY_HOUSE_PLOTS][id]["cost"][idx]["item"]=cost.itemCostReq:GetItemId()
				self:AddItem(cost.itemCostReq)
			end
		end
	end
end

function Jabbithole:SaveHousingStuff()
	if HousingLib.IsHousingWorld() then
		if not HousingLib.IsWarplotResidence() then
			if HousingLib.IsOnMyResidence() then
				HousingLib.RequestVendorList()
				local plots = HousingLib.GetPlotCount()
				for idx=1, plots do
					plot = HousingLib.GetPlot(idx)
					if plot and plot.bHasUpgrade then
						ups = HousingLib.GetPlugUpgradeList(idx)
						for idx2, plot2 in pairs(ups or {}) do
							self:AddHousingPlot(plot2, plot.nPlugItemId)
						end
					end
				end
				
				for idx, dt in pairs(HousingLib.GetDecorTypeList() or {}) do
					self:AddHousingDecorType(dt)
				end

				for idx, dc in pairs(HousingLib.GetDecorList() or {}) do
					self:AddHousingDecor(dc)
				end
				for idx, dc in pairs(HousingLib.GetDecorCrateList() or {}) do
					self:AddHousingDecorCrate(dc)
				end
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Jabbithole Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here


function Jabbithole:OnCharacterCreated()
--	Print("Jabbithole:OnCharacterCreated()")
	self:SetupInternals()
	Apollo.StartTimer("DelayedInitTimer")
end 

function Jabbithole:OnPlayerEquippedItemChanged(nEquippedSlot, uNewItem, uOldItem)
	self:SetupInternals()
	if uNewItem then
		self:AddItem(uNewItem,-1,nil,true)
	end
end

function Jabbithole:OnItemModified(uNewItem)
	self:SetupInternals()
	if uNewItem then
		self:AddItem(uNewItem,-1,nil,true)
	end
end

function Jabbithole:OnLootedItem(item, nCount)
	self:SetupInternals()
	if item and nCount>0 then
		if droppedItems[item:GetName()] then
			droppedItems[item:GetName()]=nil
			justLootedCache[item:GetChatLinkString()]=true
		else
			--everything else that is not a drop
			self:AddItem(item,-1,nil,true)
			
			local timeKey=math.floor(GameLib.GetGameTime())
			if containerCache[timeKey] == nil then
				containerCache[timeKey] = {}
			end
			if salvageCache[timeKey] == nil then
				salvageCache[timeKey] = {}
			end
			containerCache[timeKey][#containerCache[timeKey]+1]=item:GetChatLinkString()
			salvageCache[timeKey][#salvageCache[timeKey]+1]=item:GetChatLinkString()
			
			if reverseContainerCache[timeKey] ~= nil then
				if self.tSavedData[KEY_ITEMS][reverseContainerCache[timeKey]]["cont"] == nil then
					self.tSavedData[KEY_ITEMS][reverseContainerCache[timeKey]]["cont"]={}
				end
				if self.tSavedData[KEY_ITEMS][reverseContainerCache[timeKey]]["cont"][item:GetChatLinkString()] == nil then
					self.tSavedData[KEY_ITEMS][reverseContainerCache[timeKey]]["cont"][item:GetChatLinkString()]=1
				else
					self.tSavedData[KEY_ITEMS][reverseContainerCache[timeKey]]["cont"][item:GetChatLinkString()]=self.tSavedData[KEY_ITEMS][reverseContainerCache[timeKey]]["cont"][item:GetChatLinkString()]+1
				end
			end
			if reverseSalvageCache[timeKey] ~= nil then
				if self.tSavedData[KEY_ITEMS][reverseSalvageCache[timeKey]]["salv2"] == nil then
					self.tSavedData[KEY_ITEMS][reverseSalvageCache[timeKey]]["salv2"]={}
				end
				if self.tSavedData[KEY_ITEMS][reverseSalvageCache[timeKey]]["salv2"][item:GetChatLinkString()] == nil then
					self.tSavedData[KEY_ITEMS][reverseSalvageCache[timeKey]]["salv2"][item:GetChatLinkString()]=1
				else
					self.tSavedData[KEY_ITEMS][reverseSalvageCache[timeKey]]["salv2"][item:GetChatLinkString()]=self.tSavedData[KEY_ITEMS][reverseSalvageCache[timeKey]]["salv2"][item:GetChatLinkString()]+1
				end
			end
		end
	end
end

function Jabbithole:OnItemRemoved(item)
	self:SetupInternals()
	if item then
		self:AddItem(item, -1, nil,true)
		local timeKey=math.floor(GameLib.GetGameTime())
		if item:CanAutoSalvage() then
			reverseContainerCache[timeKey]=item:GetChatLinkString()
			if containerCache[timeKey] ~= nil then
				if self.tSavedData[KEY_ITEMS][item:GetChatLinkString()]["cont"] == nil then
					self.tSavedData[KEY_ITEMS][item:GetChatLinkString()]["cont"]={}
				end
				for idx,itmid in pairs(containerCache[timeKey] or {}) do
					if self.tSavedData[KEY_ITEMS][item:GetChatLinkString()]["cont"][itmid] == nil then
						self.tSavedData[KEY_ITEMS][item:GetChatLinkString()]["cont"][itmid]=1
					else
						self.tSavedData[KEY_ITEMS][item:GetChatLinkString()]["cont"][itmid]=self.tSavedData[KEY_ITEMS][item:GetChatLinkString()]["cont"][itmid]+1
					end
				end
			end
		else
			if item:CanSalvage() then
				reverseSalvageCache[timeKey]=item:GetChatLinkString()
				if salvageCache[timeKey] ~= nil then
					if self.tSavedData[KEY_ITEMS][item:GetChatLinkString()]["salv2"] == nil then
						self.tSavedData[KEY_ITEMS][item:GetChatLinkString()]["salv2"]={}
					end
					for idx,itmid in pairs(salvageCache[timeKey] or {}) do
						if self.tSavedData[KEY_ITEMS][item:GetChatLinkString()]["salv2"][itmid] == nil then
							self.tSavedData[KEY_ITEMS][item:GetChatLinkString()]["salv2"][itmid]=1
						else
							self.tSavedData[KEY_ITEMS][item:GetChatLinkString()]["salv2"][itmid]=self.tSavedData[KEY_ITEMS][item:GetChatLinkString()]["salv2"][itmid]+1
						end
					end
				end				
			else
				--recipes
				local di=item:GetDetailedInfo().tPrimary
				if di and di.tCharge then
					teachesCache[timeKey]=item:GetChatLinkString()
					if reverseTeachesCache[timeKey] ~= nil then
						if self.tSavedData[KEY_ITEMS][teachesCache[timeKey]]["teaches"] == nil then
							self.tSavedData[KEY_ITEMS][teachesCache[timeKey]]["teaches"]={}
						end
						self.tSavedData[KEY_ITEMS][teachesCache[timeKey]]["teaches"][reverseTeachesCache[timeKey]["id"]]=reverseTeachesCache[timeKey]["p"]
					end
				end
			end
		end
	end
end

function Jabbithole:OnCraftingSchematicLearned(profId, schId)
	self:SetupInternals()
	local timeKey=math.floor(GameLib.GetGameTime())
	if teachesCache[timeKey] ~= nil then
		if self.tSavedData[KEY_ITEMS][teachesCache[timeKey]]["teaches"] == nil then
			self.tSavedData[KEY_ITEMS][teachesCache[timeKey]]["teaches"]={}
		end
		self.tSavedData[KEY_ITEMS][teachesCache[timeKey]]["teaches"][schId]=profId
	end
	reverseTeachesCache[timeKey]={}
	reverseTeachesCache[timeKey]["id"]=schId
	reverseTeachesCache[timeKey]["p"]=profId
	self:AddSchematic(schId, profId)
end

function Jabbithole:OnUnitCreated(unit)
	self:SetupInternals()
	if unit and unit:IsValid() and not unit:IsACharacter() then
		if unit:GetType() == "PinataLoot" then
			droppedItems[unit:GetName()]=true
			local loot=unit:GetLoot()
			if loot then
				if loot.itemLoot then
					if loot.idOwner then
						if unitCache[loot.idOwner] then
							self:AddCreature(unitCache[loot.idOwner],true)
							self:AddItem(loot.itemLoot,-1,unitCache[loot.idOwner],true)
						end
					end
				end
			end
		else
			unitCache[unit:GetId()]=unit
		end
	end
end 

function Jabbithole:OnUnitDestroyed(unit)
	self:SetupInternals()
	if unit then
		if unit:GetType() == "PinataLoot" then
			local loot=unit:GetLoot()
			if loot then
				if loot.itemLoot then
-- save items looted by others too
--					if justLootedCache[loot.item:GetItemId()] then
					if loot.idOwner then
						if unitCache[loot.idOwner] then
							self:AddCreature(unitCache[loot.idOwner],true)
							self:AddItem(loot.itemLoot ,-1,unitCache[loot.idOwner],true)
						else
							self:AddItem(loot.itemLoot ,-1,nil,true)
						end
					else
						self:AddItem(loot.itemLoot ,-1,nil,true)
					end
				end
			end
		end
	end
end 

function Jabbithole:OnDialog_ShowState(eState, queCurrent)
	self:SetupInternals()
	if queCurrent then
		if eState == DialogSys.DialogState_QuestAccept or eState == DialogSys.DialogState_TopicChoice then
			local unitNpc = DialogSys.GetNPC()
			local unitComm = DialogSys.GetCommCreatureId()
			
			self:AddQuest(queCurrent, unitNpc, unitComm, true)		
		end
		if eState == DialogSys.DialogState_QuestComplete then
			if self.tSavedData[KEY_QUESTS] ~=nil then
				local unitNpc = DialogSys.GetNPC()
				local unitComm = DialogSys.GetCommCreatureId()
	
				local id=queCurrent:GetId()
				if self.tSavedData[KEY_QUESTS][id] ~= nil then
					if unitNpc and unitNpc:IsValid() then
						local npc=self:MakeCreatureId(unitNpc)

						if self.tSavedData[KEY_QUESTS][id]["finish"]==nil then
							self.tSavedData[KEY_QUESTS][id]["finish"]={}
						end
						if self.tSavedData[KEY_QUESTS][id]["finish"][npc]==nil then
							self.tSavedData[KEY_QUESTS][id]["finish"][npc]={}
						end
						
						self.tSavedData[KEY_QUESTS][id]["finish"][npc][unitNpc:GetPosition().x.."/"..unitNpc:GetPosition().y.."/"..unitNpc:GetPosition().z]=1
						self:AddCreature(unitNpc)
					end
					if unitComm then
						self.tSavedData[KEY_QUESTS][id]["callfinish"]=true
					end
				end
			end
		end
	end
end

function Jabbithole:SetupInternals()
	self.tPlayer = GameLib.GetPlayerUnit()
	if self.tPlayer ~= nil then
		self.tPlayerFaction = self.tPlayer:GetFaction()
	end
	self.tZone=GameLib.GetCurrentZoneMap()
	if self.tZone==nil then
		self.tZone={
			id=0,
			strName="unspecified",
			continentId=0,
			strFolder="",
			fNorth=0,
			fEast=0,
			fSouth=0,
			fWest=0
		}
	end
end

function Jabbithole:OnSystemBeginDragDrop(wndSource, strType, iData)
	self:SetupInternals()
	if strType == "DDBagItem" then
		local item=Item.GetItemFromInventoryLoc(iData)
		if item then
			self:AddItem(item,-1,nil,true)
		end
	end
end

function Jabbithole:OnSubZoneChanged(id,name)
	self:SetupInternals()
--	self:AddPathEpisode(PlayerPathLib.GetCurrentEpisode())

	self:AddZone(self.tZone)

	self:AddPathEpisode(PlayerPathLib.GetPathEpisodeForZone())
	
	local is = GameLib.GetInstanceSettings()
	if is then
		if is.eWorldDifficulty == GroupLib.Difficulty.Veteran then
			bVeteranMode = true
		else
			bVeteranMode = false
		end
	else
		bVeteranMode = false
	end
	
	unitCache = {}
	
	self:SaveHousingStuff()
end

function Jabbithole:OnCanVacuumChanged(bCanVacuum)
	self:SetupInternals()
	if not bCanVacuum then
		droppedItems = {}
		justLootedCache = {}	
	end
end


function Jabbithole:OnPlayerTitleUpdate()
	self:SetupInternals()
	local tTitles = CharacterTitle.GetAvailableTitles()
	for idx, titleCurr in pairs(tTitles) do
		self:AddTitle(titleCurr:GetTitle(), titleCurr:GetCategory(), titleCurr:GetForUnit())
	end
end

function Jabbithole:OnVendorItemsUpdated()
	self:SetupInternals()
	if self.vendorUnit then
		local items = self.vendorUnit:GetVendorItems()
		if items and #items>0 then
			for idx, item in pairs(items) do
				if item.itemData then
					self:AddItem(item.itemData,-1,nil,true)
					self:AddVendorItem(self.vendorUnit,item)
				end
				if item.splData then
					self:AddSpell(item.splData)
					self:AddVendorSpell(self.vendorUnit,item)
				end
			end
		end
	end
end
function Jabbithole:OnInvokeVendorWindow(unit)
	self:SetupInternals()
	if unit and unit:IsValid() then
		self:AddCreature(unit)
		self.vendorUnit=unit
	end
end

function Jabbithole:OnTargetUnitChanged(unit)
	self:SetupInternals()
	if unit then
		self:AddCreature(unit)
	end 
end

function Jabbithole:OnChallengeActivate(chg)
	self:SetupInternals()
	self:AddChallenge(chg)
end

function Jabbithole:OnChallengeRewardListReady(chgid,tier)
	self:SetupInternals()
	for idx,reward in pairs(ChallengesLib.GetRewardList(chgid) or {}) do
		self:AddChallengeReward(chgid,reward)
	end
end

function Jabbithole:OnPlayerPathMissionUnlocked(pm)
	self:SetupInternals()
	if pm then
		self:AddPathMission(PlayerPathLib.GetPlayerPathType(),pm,true)
	end
end

function Jabbithole:OnPlayerPathMissionDeactivate(pm)
	self:SetupInternals()
	if pm then
		self:AddPathMission(PlayerPathLib.GetPlayerPathType(),pm,true)
	end
end
	
function Jabbithole:OnPublicEventStart(pe)
	self:SetupInternals()
	if pe ~= nil and #pe:GetObjectives() > 0 then
		if pe:IsActive() then
			self:AddPublicEvent(pe)
		end
	end
end

function Jabbithole:OnPublicEventInitiateVote()
	self:SetupInternals()
	local tVoteData=PublicEvent.GetActiveVote()
	if tVoteData then
		local peid=-1
		for idx,e in pairs(PublicEvent.GetActiveEvents() or {}) do
			if e:GetEventType() ~= 11 then
				peid=self:FindPublicEvent(e)
			end
		end
		if peid ~= -1 then
			if self.tSavedData[KEY_PUBLIC_EVENT][peid]["realzone"]==nil then
				self.tSavedData[KEY_PUBLIC_EVENT][peid]["realzone"]=self.tZone.id
			else
				if self.tSavedData[KEY_PUBLIC_EVENT][peid]["realzone"] ~= self.tZone.id then
					self.tSavedData[KEY_PUBLIC_EVENT][peid]["realzone"] = -1
				end
			end
			for idx,opt in pairs(tVoteData.arOptions or {}) do
				self:AddPublicEventMission(peid, opt.strLabel, opt.strChoiceDescription)
			end
		end
	end
end

function Jabbithole:OnCombatLogDamage(tEventArgs)
	if tEventArgs.unitCaster then
		self:AddCreature(tEventArgs.unitCaster)
	end
	if tEventArgs.splCallingSpell then
		self:AddSpell(tEventArgs.splCallingSpell)
	end
	self:AddCreatureSpellRelation(tEventArgs.unitCaster, tEventArgs.splCallingSpell)
end

function Jabbithole:OnDatacubeUpdated(id, bIsVolume)
	self:SetupInternals()
	if not id then
		return
	end

	local tDatacube = DatacubeLib.GetLastUpdatedDatacube(id, bIsVolume)
	
	self:AddDatacube(id, bIsVolume, tDatacube)
end

function Jabbithole:OnHousingPlugItemsUpdated()
	for idx, plot in pairs(HousingLib.GetVendorList() or {}) do
		self:AddHousingPlot(plot)
	end
end

function Jabbithole:OnItemSentToCrate(itemSentToCrate, nCount)
	if itemSentToCrate and nCount>0 then
		self:AddItem(itemSentToCrate)
		self:SaveHousingStuff()
	end
end
	
function Jabbithole:OnJabbitholeOn()
--	self.wndMain:Show(true)
end

function Jabbithole:OnDelayedInitTimer()
--	Print("Jabbithole:OnDelayedInitTimer()")
	if not self.bInitializedProperly then
--		Print("Jabbithole is loading!")
		self:SetupInternals()
		self.bInitializedProperly = (self.tZone~=nil and self.tPlayer~=nil)
		Apollo.StartTimer("DelayedInitTimer")
	else
		Apollo.StopTimer("DelayedInitTimer")
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "Jabbithole is loaded, thanks for contributing!", "")
--		Print("Jabbithole is now loaded, thanks for contributing!")
		self:OnSubZoneChanged()
		self:OnPlayerTitleUpdate()
		self:AddTradeskills()
		self:AddReputations()
		self:SaveHousingStuff()
	end
end

function Jabbithole:OnRestore(eLevel, tData)
    if eLevel ~= GameLib.CodeEnumAddonSaveLevel.General then
        return nil
    end

    self.tSavedData = tData
	if self.tSavedData["deprecates"]~=deprecates then
		self.tSavedData={}
	end
	if self.tSavedData["l"]~=Apollo.GetString("CRB_Yes") then
		self.tSavedData={}
	end
	
--	self:OnDelayedInitTimer()
end

function Jabbithole:OnSave(eLevel)
    if eLevel ~= GameLib.CodeEnumAddonSaveLevel.General then
        return nil
    end
	
	self.tSavedData["v"]=self.tSavedData["v"]+1
	self.tSavedData["l"]=Apollo.GetString("CRB_Yes")
	self.tSavedData["vv"]=VERSION
	if self.tSavedData["firstdata"]==nil then
		self.tSavedData["firstdata"]=os.time()
	end
	self.tSavedData["lastdata"]=os.time()
	self.tSavedData["deprecates"]=deprecates
	
    return self.tSavedData 
end
-----------------------------------------------------------------------------------------------
-- JabbitholeForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function Jabbithole:OnOK()
--	self.wndMain:Show(false) -- hide the window
end

-- when the Cancel button is clicked
function Jabbithole:OnCancel()
--	self.wndMain:Show(false) -- hide the window
end

function nlFix(s)
	local ret=''
	local trash=0
	if s then
		ret,trash = s:gsub('\n','\\n')
	end
	return ret
end

-----------------------------------------------------------------------------------------------
-- Jabbithole Instance
-----------------------------------------------------------------------------------------------
local JabbitholeInst = Jabbithole:new()
JabbitholeInst:Init()
