-----------------------------------------------------------------------------------------------
-- Client Lua Script for ItemPreviewImproved2
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "GameLib"
require "HousingLib"
require "Item"
 
-----------------------------------------------------------------------------------------------
-- ItemPreviewImproved Module Definition
-----------------------------------------------------------------------------------------------
local ItemPreviewImproved = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
local kcrDoubleMarkerOff 		= ApolloColor.new("UI_BtnTextHoloNormal")
local kcrDoubleMarkerHighlight 	= ApolloColor.new("UI_BtnTextHoloFlyby")
local kcrDoubleMarkerSelected 	= ApolloColor.new("UI_BtnTextRedNormal")

local karCostumeSlotNames = -- string name, then id, then button art
{
	{"Weapon", 		GameLib.CodeEnumItemSlots.Weapon,	"CharacterWindowSprites:btn_Armor_HandsNormal", 20},
	{"Head", 		GameLib.CodeEnumItemSlots.Head, 	"CharacterWindowSprites:btnCh_Armor_Head", 		3},
	{"Shoulder", 	GameLib.CodeEnumItemSlots.Shoulder,	"CharacterWindowSprites:btnCh_Armor_Shoulder", 	4},
	{"Chest", 		GameLib.CodeEnumItemSlots.Chest, 	"CharacterWindowSprites:btnCh_Armor_Chest", 	1},
	{"Hands", 		GameLib.CodeEnumItemSlots.Hands, 	"CharacterWindowSprites:btnCh_Armor_Hands", 	6},
	{"Legs", 		GameLib.CodeEnumItemSlots.Legs, 	"CharacterWindowSprites:btnCh_Armor_Legs", 		2},
	{"Feet", 		GameLib.CodeEnumItemSlots.Feet, 	"CharacterWindowSprites:btnCh_Armor_Feet", 		5},
}


local knNumCostumes = 10

local currPreviewedItems =
{
	["Weapon"] = nil,
	["Head"] = nil,
	["Shoulder"] = nil,
	["Chest"] = nil,
	["Hands"] = nil,
	["Legs"] = nil,
	["Feet"] = nil

}

local ktVisibleSlots = 
{
	2,
	3,
	0,
	5,
	1,
	4,
	16
}

-- Supported AuctionHouse Addons
local suppAuctionHouse =
{
	"MarketplaceAuction",
	"EZAuction"
}


-- Supported Challenge Reward Addons
local suppChallenges =
{
	"ChallengeRewardPanel"
}

-- Supported Vendor Addons
local suppVendors =
{
	"Vendor",
	"LilVendor"
}
-- Supported Roll Addons
local suppRolls =
{
	"NeedVsGreed",
	"LootRollEnhanced"
}

-- Supported Dialog Addons
local suppDialogs = 
{
	"Dialog",
	"ClassicQuestDialog",
	"InstantQuestAccept",
	"QuickDialog",
	"UnitedDialogs",
	"Erns_Speedy_Quest"

}

-- Supported Tradeskills Techtree Addons
local suppTechtree =
{
	"Tradeskills",
	"CRBTradeskills"
}

-- Supported Tradeskills Schematics Addons
local suppSchematics =
{
	"TradeskillSchematics",
}

-- Supported Questlog Addons
local suppQuestlogs =
{
	"QuestLog",
	"BetterQuestLog"
}

-- Supported Chat Addons
local suppChats =
{
	[1] = 	{
			["name"] = "ChatLog",
			["xml"] = "ChatLog.xml"
			},
	[2] = 	{
			["name"] = "BetterChatLog",
			["xml"] = "BetterChatLog.xml"
			},
	[3] = 	{
			["name"] = "ChatFixed",
			["xml"] = "ChatFixed.xml"
			},
	[4] = 	{
			["name"] = "ImprovedChatLog",
			["xml"] = "ImprovedChatLog.xml"
			},
	[5] = 	{
			["name"] = "FixedChatLog",
			["xml"] = "FixedChatLog.xml"
			}	
}

local knSaveVersion
local kstrAuctionOrderDuration = MarketplaceLib.kItemAuctionListTimeDays
local kcrDefaultOptionColor = ApolloColor.new("white")
local kcrHighlightOptionColor = ApolloColor.new(110/255, 255/255, 72/255, 1.0)
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function ItemPreviewImproved:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function ItemPreviewImproved:Init()
    Apollo.RegisterAddon(self, nil, nil, {"Gemini:Hook-1.0", "Lib:ApolloFixes-1.0"})
end

function ItemPreviewImproved:OnSave(eLevel)
	
	if (eLevel ~= GameLib.CodeEnumAddonSaveLevel.Account) then 
		return 
	end 

	local l,t,r,b = self.wndMain:GetAnchorOffsets()
	local l2,t2,r2,b2 = self.wndMount:GetAnchorOffsets()
	local l3,t3,r3,b3 = self.wndFABkit:GetAnchorOffsets() 
	
	if saveData == true then
		return {
		tPosition_Main = { l = l, t = t, r = r, b = b },
		tPosition_Mount = { l = l2, t = t2, r = r2, b = b2 },
		tPosition_FABkit = { l = l3, t = t3, r = r3, b = b3 },
		tData_FABkits = ktFABkits,
		tData_LightMode = lightMode,
		tData_NormalAnchor = { nl = nl, nt = nt, nr = nr, nb = nb }
	}
	else
		return {
		tPosition_Main = { l = l, t = t, r = r, b = b },
		tPosition_Mount = { l = l2, t = t2, r = r2, b = b2 },
		tPosition_FABkit = { l = l3, t = t3, r = r3, b = b3 },
		tData_FABkits = tDataFABkits,
		tData_LightMode = lightMode,
		tData_NormalAnchor = { nl = nl, nt = nt, nr = nr, nb = nb }
	}	
	end
	
end

function ItemPreviewImproved:OnRestore(eLevel,tSavedData) 
	
	if (eLevel ~= GameLib.CodeEnumAddonSaveLevel.Account) then 
		return 
	end 
	
	local tPosMain = tSavedData.tPosition_Main
	local tPosMount = tSavedData.tPosition_Mount
	local tPosFABkit = tSavedData.tPosition_FABkit
	local tDataFABkits = tSavedData.tData_FABkits
	local tDataLightMode = tSavedData.tData_LightMode
	local tDataNormalAnchor = tSavedData.tData_NormalAnchor
	
	if tPosMain ~= nil then 
		self.wndMain:SetAnchorOffsets(tPosMain.l, tPosMain.t, tPosMain.r, tPosMain.b)
	end
	
	if tPosMount ~= nil then 
		self.wndMount:SetAnchorOffsets(tPosMount.l, tPosMount.t, tPosMount.r, tPosMount.b)
	end 
	
	if tDataFABkits ~= nil then
		ktFABkits = tDataFABkits
	end
	
	if tPosFABkit ~= nil then
		self.wndFABkit:SetAnchorOffsets(tPosFABkit.l, tPosFABkit.t, tPosFABkit.r, tPosFABkit.b)
	end
	
	if tDataLightMode ~= nil then
		lightMode = tDataLightMode
	end
	
	if tDataNormalAnchor ~= nil then
		nl = tDataNormalAnchor.nl
		nr = tDataNormalAnchor.nr
		nt = tDataNormalAnchor.nt
		nb = tDataNormalAnchor.nb
	end
end 
 

 

-----------------------------------------------------------------------------------------------
-- ItemPreviewImproved OnLoad
-----------------------------------------------------------------------------------------------
function ItemPreviewImproved:OnLoad()
    -- load our form file
	local GeminiHook = Apollo.GetPackage("Gemini:Hook-1.0").tPackage
	tAddonNames = Apollo.GetAddons()
	GeminiHook:Embed(self)
	self.xmlDoc = XmlDoc.CreateFromFile("ItemPreviewImproved.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "ItemPreviewImprovedForm", "TooltipStratum", self)
	self.wndMount = Apollo.LoadForm(self.xmlDoc, "ItemPreviewImprovedMountForm", "TooltipStratum", self)
	self.wndFABkit = Apollo.LoadForm(self.xmlDoc, "HousingPreview", nil, self)
	self.alreadyLoadedCostume = {}
	playerunit = GameLib.GetPlayerUnit()
	self.wndMain:FindChild("PreviewWindow"):SetCostume(playerunit)
	self.wndMain:FindChild("PreviewInformation"):Show(false)
	self.wndMount:FindChild("noMount"):Show(false)
	self.wndMount:FindChild("btnInformation"):Show(false)
	self.wndMount:FindChild("noMountInformation"):Show(false)
end

-----------------------------------------------------------------------------------------------
-- ItemPreviewImproved OnDocLoaded
-----------------------------------------------------------------------------------------------
function ItemPreviewImproved:OnDocLoaded()

	if self.xmlDoc == nil then
		return
	end
		
	self.wndMain:Show(false, true)
	

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterEventHandler("ShowItemInDressingRoom", "OnShowItemInDressingRoom", self)
   	    Apollo.RegisterEventHandler("ShowItemInDressingRoom", "DelayTimer", self)
		Apollo.RegisterEventHandler("AppearanceChanged", "OnAppearanceChanged", self)
		Apollo.RegisterEventHandler("GenericEvent_InitializeSchematicsTree", "OnSchematicsInitialize", self)
		Apollo.RegisterEventHandler("SubZoneChanged", "RequestFABKits", self)
		Apollo.RegisterEventHandler("HousingVendorListRecieved","UpdateFABKits", self)
    	Apollo.RegisterTimerHandler("EventThresholdTimer", "ItemPreviewFormOpenCallback", self)
		Apollo.RegisterTimerHandler("AppearanceChangedTimer", "UpdateCostume", self)
		Apollo.RegisterTimerHandler("SchematicsHook", "OnSchematicsHook", self)
    	Apollo.CreateTimer("EventThresholdTimer", 0.01, false)
		Apollo.CreateTimer("AppearanceChangedTimer", 0.1, false)
		Apollo.CreateTimer("SchematicsHook", 0.1, false)
		

		-- Do additional Addon initialization here
		
			
		--[[
			DATA INIT
						]]--
		saveData = false
		if lightMode then
			self.wndMain:FindChild("btnToggleLightMode"):SetCheck(lightMode)
		else
			lightMode = false
		end
		wndMainResized = false
				
		--[[
			CHALLENGE PREVIEW
						]]--
		for key,val in pairs(suppChallenges) do
			ChallengeAddon = Apollo.GetAddon(val)
		
			if ChallengeAddon ~= nil then
				break
			end
		end
		
		if ChallengeAddon == nil then
			ChatSystemLib.PostOnChannel(2,"ItemPreviewImproved: Could not load any supported NeedVsGreed (Roll) addon! \nPlease contact the author of the addon via Curse!")
		else
			self:RawHook(ChallengeAddon, "OnIconBlockerClick")
			self:PostHook(ChallengeAddon, "OnGenerateTooltip")
		end

				
		--[[
			ROLL PREVIEW
						]]--
		for key,val in pairs(suppRolls) do
			RollAddon = Apollo.GetAddon(val)
		
			if RollAddon ~= nil then
				break
			end
		end
		
		if RollAddon == nil then
			ChatSystemLib.PostOnChannel(2,"ItemPreviewImproved: Could not load any supported NeedVsGreed (Roll) addon! \nPlease contact the author of the addon via Curse!")
		else
			self:PostHook(RollAddon, "DrawLoot")
			
			RollAddon.OnMouseButtonUp = function (luaCaller, wndHandler, wndControl, eMouseButton)
		
				if Apollo.IsControlKeyDown() and eMouseButton == GameLib.CodeEnumInputMouse.Right then
					if wndHandler:GetData():GetHousingDecorInfoId() ~= nil and wndHandler:GetData():GetHousingDecorInfoId() ~= 0 then
								Event_FireGenericEvent("DecorPreviewOpen", wndHandler:GetData():GetHousingDecorInfoId())
								return
							else
								self:OnShowItemInDressingRoom(wndHandler:GetData())
								return
							end		
        		end
		end
		end
		
		
		--[[
			MOUNT / FABKIT PREVIEW
						]]--
						
		for key,val in pairs(suppVendors) do
			VendorAddon = Apollo.GetAddon(val)
		
			if VendorAddon ~= nil then
				break
			end
		end
		
		if VendorAddon == nil then
			ChatSystemLib.PostOnChannel(2,"ItemPreviewImproved: Could not load any supported Vendor addon! \nPlease contact the author of the addon via Curse!")
		else
			--self:PostHook(VendorAddon, "OnVendorListItemMouseDown")
			--self:RawHook(VendorAddon, "OnVendorListItemMouseDown")
			self:Hook(VendorAddon, "OnVendorListItemMouseDown")

		end
		
		--[[
			AUCTIONHOUSE
						]]--
						
		for key,val in pairs(suppAuctionHouse) do
			AuctionHouseAddon = Apollo.GetAddon(val)
			
			if val == "EZAuction" then
			
			else
				ktTimeRemaining =
				{
					[ItemAuction.CodeEnumAuctionRemaining.Expiring]		= Apollo.GetString("MarketplaceAuction_Expiring"),
					[ItemAuction.CodeEnumAuctionRemaining.LessThanHour]	= Apollo.GetString("MarketplaceAuction_LessThanHour"),
					[ItemAuction.CodeEnumAuctionRemaining.Short]		= Apollo.GetString("MarketplaceAuction_Short"),
					[ItemAuction.CodeEnumAuctionRemaining.Long]			= Apollo.GetString("MarketplaceAuction_Long"),
					--[ItemAuction.CodeEnumAuctionRemaining.Very_Long]	= Apollo.GetString("MarketplaceAuction_VeryLong") -- Uses string weasel to stick a number in
				}
			end
		
			if AuctionHouseAddon ~= nil then
				break
			end
		end
		
		if AuctionHouseAddon == nil then
			ChatSystemLib.PostOnChannel(2,"ItemPreviewImproved: Could not load any supported Auctionhouse addon! \nPlease contact the author of the addon via Curse!")
		else
			self:RawHook(AuctionHouseAddon, "BuildListItem")
			

		AuctionHouseAddon.OnMouseButtonUp = function (luaCaller, wndHandler, wndControl, eMouseButton)
			local aucCurr = wndHandler:GetData()
			local itemCurr = aucCurr:GetItem()
			if not itemCurr then
				return
			end
			if Apollo.IsControlKeyDown() and eMouseButton == GameLib.CodeEnumInputMouse.Right then
				if itemCurr:GetHousingDecorInfoId() ~= nil and itemCurr:GetHousingDecorInfoId() ~= 0 then
						Event_FireGenericEvent("DecorPreviewOpen", itemCurr:GetHousingDecorInfoId())
					else
						self:OnShowItemInDressingRoom(itemCurr)				
				end
			end
		end
		
		end

		--[[
			TRADESKILLS
						]]--
		
		
		for key,val in pairs(suppTechtree) do
			TechtreeAddon = Apollo.GetAddon(val)
		
			if TechtreeAddon ~= nil then
				break
			end
		end
		
		if TechtreeAddon == nil then
			ChatSystemLib.PostOnChannel(2,"ItemPreviewImproved: Could not load any supported Tradeskills addon! \nPlease contact the author of the addon via Curse!")
		else
		
		self:PostHook(TechtreeAddon, "HelperBuildItemTooltip")
		
		TechtreeAddon.OnMouseButtonUp = function (luaCaller, wndHandler, wndControl, eMouseButton)
		
				if Apollo.IsControlKeyDown() and eMouseButton == GameLib.CodeEnumInputMouse.Right then
					if wndHandler:GetData():GetHousingDecorInfoId() ~= nil and wndHandler:GetData():GetHousingDecorInfoId() ~= 0 then
						Event_FireGenericEvent("DecorPreviewOpen", wndHandler:GetData():GetHousingDecorInfoId())
						return
					else
						self:OnShowItemInDressingRoom(wndHandler:GetData())
						return
					end		
        		end
		end
				
		end

		
		--[[
			QUEST REWARD
						]]--
		for key,val in pairs(suppDialogs) do
			DialogAddon = Apollo.GetAddon(val)
		
			if DialogAddon ~= nil then
				break
			end
		end
	
		if DialogAddon == nil then
	
			ChatSystemLib.PostOnChannel(2,"ItemPreviewImproved: Could not load any supported Dialog addon! \nPlease contact the author of the addon via Curse!")
		else
			self:PostHook(DialogAddon, "HelperBuildItemTooltip")	
		
			DialogAddon.OnMouseButtonUp = function (luaCaller, wndHandler, wndControl, eMouseButton)

				if Apollo.IsControlKeyDown() and eMouseButton == GameLib.CodeEnumInputMouse.Right then
						self:OnShowItemInDressingRoom(wndHandler:GetData())
        		end
		
			end
		end
		
		--[[
			QuestLog
						]]--
		for key,val in pairs(suppQuestlogs) do
			QuestLogAddon = Apollo.GetAddon(val)
			
			if QuestLogAddon ~= nil then
				break
			end
		end
		
		if QuestLogAddon == nil then
		
		ChatSystemLib.PostOnChannel(2,"ItemPreviewImproved: Could not load any supported QuestLog addon! \nPlease contact the author of the addon via Curse!")	
		
		else
			
			self:PostHook(QuestLogAddon, "HelperBuildRewardsRec")
			
			QuestLogAddon.OnMouseButtonUp = function (luaCaller, wndHandler, wndControl, eMouseButton)
				if Apollo.IsControlKeyDown() and eMouseButton == GameLib.CodeEnumInputMouse.Right then
						self:OnShowItemInDressingRoom(wndHandler:GetData())
        		end
		
			end
		
		end
		--[[
			CHAT LINKS
						]]--
		
		for key,val in pairs(suppChats) do
			ChatAddon = Apollo.GetAddon(val["name"])
			
			if ChatAddon ~= nil then
				ChatAddonXML = val["xml"]
				ChatAddonName = val["name"]
				break
			end
		end
		
		if ChatAddon == nil then
			ChatSystemLib.PostOnChannel(2,"ItemPreviewImproved: Could not load any supported ChatLog addon! \nPlease contact the author of the addon via Curse!")
		else
			self:PostHook(ChatAddon, "OnNodeClick")
		end
end


-----------------------------------------------------------------------------------------------
-- ItemPreviewImproved Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here
function ItemPreviewImproved:DrawLoot(luaCaller, tCurrentElement, nItemsInQueue)
	RollAddon.wndMain:FindChild("GiantItemIcon"):AddEventHandler("MouseButtonUp", "OnMouseButtonUp")
	RollAddon.wndMain:FindChild("GiantItemIcon"):SetData(tCurrentElement.itemDrop)
	RollAddon.wndMain:FindChild("GiantItemIcon"):SetStyle("IgnoreMouse", false)
end

function ItemPreviewImproved:BuildListItem(luaCaller, aucCurr, wndParent, bBuyTab)
	local itemCurr = aucCurr:GetItem()
			local bIsOwnAuction = aucCurr:IsOwned()
			local nBuyoutPrice = aucCurr:GetBuyoutPrice():GetAmount()
			local nDefaultBid = math.max(aucCurr:GetMinBid():GetAmount(), aucCurr:GetCurrentBid():GetAmount())

			local strFormToLoad = "BuyNowItem"
			if nBuyoutPrice == 0 then
				strFormToLoad = "BidOnlyItem"
			elseif nDefaultBid >= nBuyoutPrice then
				strFormToLoad = "BuyOnlyItem"
			end

			local wnd = Apollo.LoadForm(AuctionHouseAddon.xmlDoc, strFormToLoad, wndParent, AuctionHouseAddon)
			wnd:SetData(aucCurr)
			wnd:FindChild("RowSelectBtn"):SetData(aucCurr)
			wnd:FindChild("RowSelectBtn"):AddEventHandler("MouseButtonUp", "OnMouseButtonUp")
			wnd:FindChild("RowSelectBtn"):Show(bBuyTab)
			wnd:FindChild("ListName"):SetText(itemCurr:GetName())
			wnd:FindChild("ListIcon"):SetSprite(itemCurr:GetIcon())
			wnd:FindChild("ListIcon"):SetText(aucCurr:GetCount() <= 1 and "" or aucCurr:GetCount())

			local eTimeRemaining = aucCurr:GetTimeRemainingEnum()
			if bIsOwnAuction then
				wnd:FindChild("ListExpires"):SetText(AuctionHouseAddon.HelperFormatTimeString(luaCaller, aucCurr:GetExpirationTime()))
				wnd:FindChild("ListExpiresIcon"):SetSprite("Market:UI_Auction_Icon_TimeGreen")
				wnd:FindChild("ListExpires"):SetTextColor(ApolloColor.new("UI_TextHoloTitle"))

			elseif eTimeRemaining == ItemAuction.CodeEnumAuctionRemaining.Very_Long then
				wnd:FindChild("ListExpires"):SetTextRaw(String_GetWeaselString(Apollo.GetString("MarketplaceAuction_VeryLong"), kstrAuctionOrderDuration))
				wnd:FindChild("ListExpires"):SetTextColor(ApolloColor.new("UI_TextHoloTitle"))
				wnd:FindChild("ListExpiresIcon"):Show("Market:UI_Auction_Icon_TimeGreen")

			else
				wnd:FindChild("ListExpires"):SetTextRaw(ktTimeRemaining[eTimeRemaining])
				wnd:FindChild("ListExpires"):SetTextColor(ApolloColor.new("xkcdDullRed"))
				wnd:FindChild("ListExpiresIcon"):Show("Market:UI_Auction_Icon_TimeRed")
			end
			wnd:FindChild("OwnAuctionLabel"):Show(bIsOwnAuction)
			wnd:FindChild("TopBidAuctionLabel"):Show(aucCurr:IsTopBidder())

			if wnd:FindChild("BidPrice") then
				wnd:FindChild("BidPrice"):SetAmount(nDefaultBid)
			end

			if wnd:FindChild("BuyNowPrice") then
				local bCanAffordBuyNow = AuctionHouseAddon.wndPlayerCashWindow:GetAmount() >= nBuyoutPrice
				wnd:FindChild("BuyNowPrice"):SetAmount(nBuyoutPrice)
				wnd:FindChild("BuyNowPrice"):SetTextColor(bCanAffordBuyNow and "UI_TextHoloTitle" or "UI_BtnTextRedNormal")
			end

end


function ItemPreviewImproved:RequestFABKits(num, zone)
	if num == 1136 then
		HousingLib.RequestVendorList()
	end
end

function ItemPreviewImproved:UpdateFABKits()
	ktNewFABKits = HousingLib.GetVendorList()
	ktFABkits = ktNewFABKits
	saveData = true
end

function ItemPreviewImproved:OnCloseFABkit( wndHandler, wndControl, eMouseButton )
	self.wndFABkit:Close()
end

function ItemPreviewImproved:ScreenshotLeft( wndHandler, wndControl, eMouseButton )
	local nNewSS = #self.tScreenshots
	if self.tScreenshots[self.nCurrSS-1] then
		nNewSS = self.nCurrSS-1
	end
	
	self.nCurrSS = nNewSS
	self.wndFABkit:FindChild("Picture"):SetSprite(self.tScreenshots[nNewSS].strSprite)
	self.wndFABkit:ToFront()
end

function ItemPreviewImproved:ScreenshotRight( wndHandler, wndControl, eMouseButton )
	local nNewSS = 1
	if self.tScreenshots[self.nCurrSS+1] then
		nNewSS = self.nCurrSS+1
	end
	
	self.nCurrSS = nNewSS
	self.wndFABkit:FindChild("Picture"):SetSprite(self.tScreenshots[nNewSS].strSprite)
	self.wndFABkit:ToFront()
end

function ItemPreviewImproved:OnSchematicsHook()
	for key,val in pairs(suppSchematics) do
		SchematicsAddon = Apollo.GetAddon(val)
		
		if SchematicsAddon ~= nil then
			break
		end
	end
	
	if SchematicsAddon ~= nil then
		if self:IsHooked(SchematicsAddon, "HelperBuildItemTooltip") == false then
			self:PostHook(SchematicsAddon, "HelperBuildItemTooltip")
				if SchematicsAddon.OnMouseButtonUp == nil then
					SchematicsAddon.OnMouseButtonUp = function (luaCaller, wndHandler, wndControl, eMouseButton)
						if Apollo.IsControlKeyDown() and eMouseButton == GameLib.CodeEnumInputMouse.Right then
							if wndHandler:GetData():GetHousingDecorInfoId() ~= nil and wndHandler:GetData():GetHousingDecorInfoId() ~= 0 then
								Event_FireGenericEvent("DecorPreviewOpen", wndHandler:GetData():GetHousingDecorInfoId())
								return
							else
								self:OnShowItemInDressingRoom(wndHandler:GetData())
								return
							end		
        				end
				end
		end
	end
	end
end 

function ItemPreviewImproved:OnIconBlockerClick(luaCaller, wndHandler, wndControl, eMouseButton)
	if wndHandler ~= wndControl then return end
	
	local bCanSelect = wndControl:GetData()
	local wndBtn = wndControl:GetParent():FindChild("ChallengeItemBtn")
	
	if Apollo.IsControlKeyDown() and eMouseButton == GameLib.CodeEnumInputMouse.Right then
		local item = wndControl:GetData()
		if item:GetHousingDecorInfoId() ~= nil and item:GetHousingDecorInfoId() ~= 0 then
			Event_FireGenericEvent("DecorPreviewOpen", item:GetHousingDecorInfoId())
			return
		else
			self:OnShowItemInDressingRoom(item)
			return
		end
	elseif not Apollo.IsControlKeyDown() and eMouseButton == GameLib.CodeEnumInputMouse.Left then
		ChallengeAddon:OnChallengeItemBtn(wndBtn, wndBtn)
	end
end

function ItemPreviewImproved:OnSchematicsInitialize()
	Apollo.StartTimer("SchematicsHook")
end

function ItemPreviewImproved:UpdateCostume()
	self.wndMain:FindChild("PreviewWindow"):SetCostume(GameLib.GetPlayerUnit())
	for key,val in pairs(currPreviewedItems) do
		self.wndMain:FindChild("PreviewWindow"):SetItem(val)
	end
end

function ItemPreviewImproved:OnAppearanceChanged()
	self.wndMain:FindChild("PreviewWindow"):SetCostume(nil)
	Apollo.StartTimer("AppearanceChangedTimer")
end

function ItemPreviewImproved:OnGenerateTooltip(luaCaller, wndControl, wndHandler, eType, Arg1, Arg2)
	if eType == Tooltip.TooltipGenerateType_ItemData then
		local itemReward = Arg1
		wndControl:GetParent():FindChild("LootIconBlocker"):SetData(itemReward)
	end
end

function ItemPreviewImproved:HelperBuildItemTooltip(luaCaller, wndArg, itemCurr, itemModData, tGlyphData)
	wndArg:AddEventHandler("MouseButtonUp", "OnMouseButtonUp")
	wndArg:SetData(itemCurr)
end

function ItemPreviewImproved:OnNodeClick(luaCaller, wndHandler, wndControl, strNode, tAttributes, eMouseButton)
	local nIndex = tonumber(tAttributes.strIndex)
	if strNode == "Link" then
		if ChatAddon.tLinks[nIndex].uItem then
			if Apollo.IsControlKeyDown() == true and eMouseButton == GameLib.CodeEnumInputMouse.Right then		
				if ChatAddon.tLinks[nIndex].uItem:GetHousingDecorInfoId() ~= nil and ChatAddon.tLinks[nIndex].uItem:GetHousingDecorInfoId() ~= 0 then
					Event_FireGenericEvent("DecorPreviewOpen", ChatAddon.tLinks[nIndex].uItem:GetHousingDecorInfoId())
					return
				else
					Event_FireGenericEvent("ShowItemInDressingRoom", ChatAddon.tLinks[nIndex].uItem)
					return
				end						
			end
		end
	end
end

function ItemPreviewImproved:OnVendorListItemMouseDown(luaCaller, wndHandler, wndControl, eMouseButton, nPosX, nPosY, bDoubleClick)
	if eMouseButton == GameLib.CodeEnumInputMouse.Right and Apollo.IsControlKeyDown() then
			if not wndHandler or not wndHandler:GetData() then return end
		    local tItemPreview = wndHandler:GetData()
		    if tItemPreview and tItemPreview.itemData then
		        local itemCurr = tItemPreview.itemData
		        local itemID = itemCurr:GetItemId()
				local itemName = itemCurr:GetName()
				local previewWindow = Apollo.FindWindowByName("ItemPreviewImprovedMountForm")

				for idx, val in pairs(tMounts) do
					if itemID == val["Item_ID"] then
						if val["Mount_ID"] ~= nil then
							if previewWindow:FindChild("noMount"):IsShown() then
								previewWindow:FindChild("noMount"):Show(false)
							end
							previewWindow:FindChild("MountPortrait"):SetCamera("Paperdoll")
							previewWindow:FindChild("MountPortrait"):SetCostumeToCreatureId(val["Mount_ID"])
							if val["Hoverboard_ID"] ~= 0 then
								previewWindow:FindChild("MountPortrait"):SetAttachment(PetCustomizationLib.HoverboardAttachmentPoint, val["Hoverboard_ID"])
							end
							
							if previewWindow:FindChild("btnInformation"):IsShown() then
								previewWindow:FindChild("btnInformation"):Show(false)
							end
						else
							previewWindow:FindChild("MountPortrait"):SetCostume(nil)
							previewWindow:FindChild("noMount"):Show(true)
							previewWindow:FindChild("btnInformation"):Show(true)
						end
						previewWindow:Show(true)
					end
				end
			end		
		end	
end

function ItemPreviewImproved:HelperBuildItemTooltip(luaCaller, wndArg, item)
	wndArg:AddEventHandler("MouseButtonUp", "OnMouseButtonUp")
	wndArg:SetData(item)
end

function ItemPreviewImproved:HelperBuildRewardsRec(luaCaller, wndReward, tRewardData, bReceived)
	wndReward:AddEventHandler("MouseButtonUp", "OnMouseButtonUp")
	wndReward:SetData(tRewardData.itemReward)
end

function ItemPreviewImproved:HelperBuildItemTooltip(luaCaller, wndArg, item)
	wndArg:AddEventHandler("MouseButtonUp", "OnMouseButtonUp")
	wndArg:SetData(item)
end

function ItemPreviewImproved:OnShowItemInDressingRoom(item)
	
	previewAddon = Apollo.GetAddon("ItemPreview")
		if previewAddon ~= nil then
			if previewAddon.wndMain and previewAddon.wndMain:IsShown() then
				previewAddon.wndMain:Show(false)
				previewAddon.wndMain:Destroy()
			end
		end
	
	if item == nil or not self:HelperValidateSlot(item) then
		return
	end
	
	if playerunit == nil then
		self.wndMain:FindChild("PreviewWindow"):SetCostume(GameLib.GetPlayerUnit())
		playerunit = GameLib.GetPlayerUnit()
	end
	
	self:SwitchMode(lightMode)
	
	self:SetSizingMinimum(lightMode)
	
	self.wndMain:FindChild("PreviewWindow"):SetItem(item)
	
	if self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end

	local strItem = item:GetName()
	
	if ktVisibleSlots[1] == item:GetSlot() then
		self.wndMain:FindChild("PreviewInformation"):FindChild("InfoHead"):FindChild("ItemLabelHead"):SetText(strItem)
		currPreviewedItems["Head"] = item
	elseif ktVisibleSlots[2] == item:GetSlot() then
		self.wndMain:FindChild("PreviewInformation"):FindChild("InfoShoulder"):FindChild("ItemLabelShoulder"):SetText(strItem)
		currPreviewedItems["Shoulder"] = item
	elseif ktVisibleSlots[3] == item:GetSlot() then
		self.wndMain:FindChild("PreviewInformation"):FindChild("InfoChest"):FindChild("ItemLabelChest"):SetText(strItem)
		currPreviewedItems["Chest"] = item
	elseif ktVisibleSlots[4] == item:GetSlot() then
		self.wndMain:FindChild("PreviewInformation"):FindChild("InfoHands"):FindChild("ItemLabelHands"):SetText(strItem)
		currPreviewedItems["Hands"] = item
	elseif ktVisibleSlots[5] == item:GetSlot() then
		self.wndMain:FindChild("PreviewInformation"):FindChild("InfoLegs"):FindChild("ItemLabelLegs"):SetText(strItem)
		currPreviewedItems["Legs"] = item
	elseif ktVisibleSlots[6] == item:GetSlot() then
		self.wndMain:FindChild("PreviewInformation"):FindChild("InfoFeet"):FindChild("ItemLabelFeet"):SetText(strItem)
		currPreviewedItems["Feet"] = item
	elseif ktVisibleSlots[7] == item:GetSlot() then
		self.wndMain:FindChild("PreviewInformation"):FindChild("InfoWeapon"):FindChild("ItemLabelWeapon"):SetText(strItem)
		currPreviewedItems["Weapon"] = item
	end

	-- set sheathed or not
	local eItemType = item:GetItemType()
	self.bSheathed = not self:HelperCheckForWeapon(eItemType)

	self.wndMain:FindChild("PreviewWindow"):SetSheathed(self.bSheathed)
	self:HelperFormatSheathButton(self.bSheathed)
	
	self.wndCostumeSelectionList = self.wndMain:FindChild("Middle:CostumeBtnHolder")
	self.wndCostumeSelectionList:Show(false)
	
	self.tCostumeBtns = {}
	self.nCostumeCount = GameLib.GetCostumeCount()

	for idx = 1, knNumCostumes do
		self.tCostumeBtns[idx] = self.wndCostumeSelectionList:FindChild("CostumeBtn"..idx)
		self.tCostumeBtns[idx]:SetData(idx)		
		self.tCostumeBtns[idx]:Show( idx <= self.nCostumeCount)
		
		if idx <= self.nCostumeCount then
			self.wndMain:FindChild("CostumeBtn" .. idx):SetCheck(false)
			self.wndMain:FindChild("CostumeBtn" .. idx):SetText(String_GetWeaselString(Apollo.GetString("Character_CostumeNum"), idx)) -- TODO: this will be a real name at some point
		end
	end
	self.nCurrentCostume = GameLib.GetCostumeIndex()
	local wndCurrentCostume = self.wndMain:FindChild("CostumeBtnHolder"):FindChild("CostumeBtn" .. self.nCurrentCostume)

	if self.nCurrentCostume > 0 and self.nCurrentCostume ~= nil then
		self.wndMain:FindChild("CostumeBtn" .. self.nCurrentCostume):SetCheck(true)
		local strName = wndCurrentCostume:GetText()
		self.wndMain:FindChild("SelectCostumeWindowToggle"):SetText(strName)
	else
		self.wndMain:FindChild("ClearCostumeBtn"):SetCheck(true)
		self.wndMain:FindChild("SelectCostumeWindowToggle"):SetText(Apollo.GetString("Character_CostumeSelectDefault"))
	end
	
	local nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("CostumeBtnHolder"):GetAnchorOffsets()
	self.wndMain:FindChild("CostumeBtnHolder"):SetAnchorOffsets(nLeft, nBottom - (75 + 28 * self.nCostumeCount), nRight, nBottom)
	
	self.wndMain:Show(true)
end

function ItemPreviewImproved:HelperCheckForWeapon(eItemType)
	local bIsWeapon = false

	if eItemType >= Item.CodeEnumItemType.WeaponMHPistols and eItemType <= Item.CodeEnumItemType.WeaponMHSword then
		bIsWeapon = true
	end

	return bIsWeapon
end

function ItemPreviewImproved:HelperFormatSheathButton(bSheathed)
	if bSheathed == true then
		self.wndMain:FindChild("SheathButton"):SetText(Apollo.GetString("Inventory_DrawWeapons"))
	else
		self.wndMain:FindChild("SheathButton"):SetText(Apollo.GetString("Inventory_Sheathe"))
	end
end

function ItemPreviewImproved:HelperValidateSlot(item)
	local bVisibleSlot = false
	local bRightClassOrProf = false
	if string.find(item:GetName(), "FABkit") or string.find(item:GetName(), "FABKit") then
				for key,tItemData in pairs(ktFABkits) do
					local strName = tItemData.strName
					
					if string.find(item:GetName(), "Biome") and string.find(tItemData.strName, "Biome: ")then
						strName = string.gsub(tItemData.strName, "Biome: ", "").. " Biome"
					end
					if strName.." FABkit" == item:GetName() and #tItemData.tScreenshots >= 1 then
						self.tScreenshots = tItemData.tScreenshots
						self.nCurrSS = 1
						self.wndFABkit:FindChild("Picture"):SetSprite(tItemData.tScreenshots[1].strSprite)
						self.wndFABkit:Show(true)
						if #tItemData.tRepairRequirements > 0 then
							if tItemData.tRepairRequirements[1].eType == 1 then
								self.wndFABkit:FindChild("Cost"):Show(true)
								self.wndFABkit:FindChild("Cost"):SetAmount(tItemData.tRepairRequirements[1].nRequiredCost)
							else
								self.wndFABkit:FindChild("Cost"):SetAmount(0)
							end
						else
							self.wndFABkit:FindChild("Cost"):SetAmount(0)
						end
						self.wndFABkit:FindChild("Description"):SetText(tItemData.strTooltip)
						self.wndFABkit:ToFront()
					end
				end
			end
	for idx, nSlot in pairs(ktVisibleSlots) do
		if item:GetSlot() and item:GetSlot() == nSlot then --item:GetSlot() and
			bRightClassOrProf = true
			bVisibleSlot = bRightClassOrProf
			break
		end

	end

	return bVisibleSlot
end


-----------------------------------------------------------------------------------------------
-- ItemPreviewImproved Form Functions
-----------------------------------------------------------------------------------------------

function ItemPreviewImproved:OnWindowClosed( wndHandler, wndControl )
	if self.wndMain ~= nil then
		self.wndMain:Close()
	end
end

function ItemPreviewImproved:OnToggleSheathButton( wndHandler, wndControl, eMouseButton )
	local bWeapon = wndControl:IsChecked()
	self.wndMain:FindChild("PreviewWindow"):SetSheathed(bWeapon)
end

function ItemPreviewImproved:OnCloseBtn( wndHandler, wndControl, eMouseButton )
	self.wndMain:Show(false)
end

function ItemPreviewImproved:OnInfo()
	if self.wndMain:FindChild("PreviewInformation"):IsShown() == true then
		self.wndMain:FindChild("PreviewInformation"):Show(false)
	else
		self.wndMain:FindChild("PreviewInformation"):Show(true)
	end
end

function ItemPreviewImproved:OnToggleSheathed( wndHandler, wndControl, eMouseButton )
	local bSheathed = not self.bSheathed
	self.wndMain:FindChild("PreviewWindow"):SetSheathed(bSheathed)
	self:HelperFormatSheathButton(bSheathed)

	self.bSheathed = bSheathed
end

function ItemPreviewImproved:OnRotateRight()
	if self.wndMain:IsShown() then
		self.wndMain:FindChild("PreviewWindow"):ToggleLeftSpin(true)
	else
		self.wndMount:FindChild("MountPortrait"):ToggleLeftSpin(true)
	end	
end

function ItemPreviewImproved:OnRotateRightCancel()
	if self.wndMain:IsShown() then
		self.wndMain:FindChild("PreviewWindow"):ToggleLeftSpin(false)
	else
		self.wndMount:FindChild("MountPortrait"):ToggleLeftSpin(false)
	end	
end

function ItemPreviewImproved:OnRotateLeft()
	if self.wndMain:IsShown() then
		self.wndMain:FindChild("PreviewWindow"):ToggleRightSpin(true)
	else
		self.wndMount:FindChild("MountPortrait"):ToggleRightSpin(true)
	end
end

function ItemPreviewImproved:OnRotateLeftCancel()
	if self.wndMain:IsShown() then
		self.wndMain:FindChild("PreviewWindow"):ToggleRightSpin(false)
	else
		self.wndMount:FindChild("MountPortrait"):ToggleRightSpin(false)
	end
end

function ItemPreviewImproved:OnReset()
	self.wndMain:FindChild("PreviewWindow"):SetCostume(GameLib.GetPlayerUnit())
	self.wndMain:FindChild("PreviewInformation"):FindChild("InfoHead"):FindChild("ItemLabelHead"):SetText("")
	self.wndMain:FindChild("PreviewInformation"):FindChild("InfoShoulder"):FindChild("ItemLabelShoulder"):SetText("")
	self.wndMain:FindChild("PreviewInformation"):FindChild("InfoChest"):FindChild("ItemLabelChest"):SetText("")
	self.wndMain:FindChild("PreviewInformation"):FindChild("InfoHands"):FindChild("ItemLabelHands"):SetText("")
	self.wndMain:FindChild("PreviewInformation"):FindChild("InfoLegs"):FindChild("ItemLabelLegs"):SetText("")
	self.wndMain:FindChild("PreviewInformation"):FindChild("InfoFeet"):FindChild("ItemLabelFeet"):SetText("")
	self.wndMain:FindChild("PreviewInformation"):FindChild("InfoWeapon"):FindChild("ItemLabelWeapon"):SetText("")
	for key,val in pairs(currPreviewedItems) do
		currPreviewedItems[key] = nil
	end	
end

function ItemPreviewImproved:OnPreviewLeft()
	local l, t, r, b = -322, -21, 25, 603
	self.wndMain:FindChild("PreviewInformation"):SetAnchorOffsets(l, t, r, b)
end

function ItemPreviewImproved:OnPreviewRight()

	local l, t, r, b = 324, -20, 671, 604
	self.wndMain:FindChild("PreviewInformation"):SetAnchorOffsets(l, t, r, b)

end

function ItemPreviewImproved:OnRemoveHead()
	self.wndMain:FindChild("PreviewWindow"):SetCostume(GameLib.GetPlayerUnit())
	for key,val in pairs(currPreviewedItems) do
		if key == "Head" then
			currPreviewedItems["Head"] = nil
			self.wndMain:FindChild("PreviewInformation"):FindChild("InfoHead"):FindChild("ItemLabelHead"):SetText("")
		else
			self.wndMain:FindChild("PreviewWindow"):SetItem(val)
		end
	end
end

function ItemPreviewImproved:OnRemoveShoulder()
	self.wndMain:FindChild("PreviewWindow"):SetCostume(GameLib.GetPlayerUnit())
	for key,val in pairs(currPreviewedItems) do
		if key == "Shoulder" then
			currPreviewedItems["Shoulder"] = nil
			self.wndMain:FindChild("PreviewInformation"):FindChild("InfoShoulder"):FindChild("ItemLabelShoulder"):SetText("")
		else
			self.wndMain:FindChild("PreviewWindow"):SetItem(val)
		end
	end
end

function ItemPreviewImproved:OnRemoveChest()
	self.wndMain:FindChild("PreviewWindow"):SetCostume(GameLib.GetPlayerUnit())
	for key,val in pairs(currPreviewedItems) do
		if key == "Chest" then
			currPreviewedItems["Chest"] = nil
			self.wndMain:FindChild("PreviewInformation"):FindChild("InfoChest"):FindChild("ItemLabelChest"):SetText("")
		else
			self.wndMain:FindChild("PreviewWindow"):SetItem(val)
		end
	end
end

function ItemPreviewImproved:OnRemoveHands()
	self.wndMain:FindChild("PreviewWindow"):SetCostume(GameLib.GetPlayerUnit())
	for key,val in pairs(currPreviewedItems) do
		if key == "Hands" then
			currPreviewedItems["Hands"] = nil
			self.wndMain:FindChild("PreviewInformation"):FindChild("InfoHands"):FindChild("ItemLabelHands"):SetText("")
		else
			self.wndMain:FindChild("PreviewWindow"):SetItem(val)
		end
	end
end

function ItemPreviewImproved:OnRemoveLegs()
	self.wndMain:FindChild("PreviewWindow"):SetCostume(GameLib.GetPlayerUnit())
	for key,val in pairs(currPreviewedItems) do
		if key == "Legs" then
			currPreviewedItems["Legs"] = nil
			self.wndMain:FindChild("PreviewInformation"):FindChild("InfoLegs"):FindChild("ItemLabelLegs"):SetText("")
		else
			self.wndMain:FindChild("PreviewWindow"):SetItem(val)
		end
	end
end

function ItemPreviewImproved:OnRemoveFeet()
	self.wndMain:FindChild("PreviewWindow"):SetCostume(GameLib.GetPlayerUnit())
	for key,val in pairs(currPreviewedItems) do
		if key == "Feet" then
			currPreviewedItems["Feet"] = nil
			self.wndMain:FindChild("PreviewInformation"):FindChild("InfoFeet"):FindChild("ItemLabelFeet"):SetText("")
		else
			self.wndMain:FindChild("PreviewWindow"):SetItem(val)
		end
	end
end

function ItemPreviewImproved:OnRemoveWeapon()
	self.wndMain:FindChild("PreviewWindow"):SetCostume(GameLib.GetPlayerUnit())
	for key,val in pairs(currPreviewedItems) do
		if key == "Weapon" then
			currPreviewedItems["Weapon"] = nil
			self.wndMain:FindChild("PreviewInformation"):FindChild("InfoWeapon"):FindChild("ItemLabelWeapon"):SetText("")
		else
			self.wndMain:FindChild("PreviewWindow"):SetItem(val)
		end
	end
end

function ItemPreviewImproved:CostumeSelectionWindowShow()
	self.wndCostumeSelectionList:Show(true)
	self.wndMain:FindChild("btnLock"):FindChild("bgArt"):Show(false)
	if lightMode == true then
		self.wndMain:FindChild("btnLightSheath"):FindChild("bgArt"):Show(false)
		self.wndMain:FindChild("btnLightReset"):FindChild("bgArt"):Show(false)
	end
end

function ItemPreviewImproved:CostumeSelectionWindowHide()
	self.wndCostumeSelectionList:Show(false)
	self.wndMain:FindChild("btnLock"):FindChild("bgArt"):Show(true)
	if lightMode == true then
		self.wndMain:FindChild("btnLightSheath"):FindChild("bgArt"):Show(true)
		self.wndMain:FindChild("btnLightReset"):FindChild("bgArt"):Show(true)
	end
end

function ItemPreviewImproved:OnCostumeBtnToggle(wndHandler, wndCtrl)
	if wndHandler ~= wndCtrl then
		return false
	end

	self.nCurrentCostume = nil

	local wndCostumeHolder = self.wndMain:FindChild("Middle:CostumeBtnHolder")
	for idx = 1, knNumCostumes do
		if wndCostumeHolder:FindChild("CostumeBtn"..idx):IsChecked() then
			self.nCurrentCostume = idx
		elseif wndCostumeHolder:FindChild("ClearCostumeBtn"):IsChecked() then
			self.nCurrentCostume = 0
		end
	end
	if self.wndMain:FindChild("SelectCostumeWindowToggle"):IsShown() then
		self.wndMain:FindChild("Middle:BGArt_HeaderFrame:SelectCostumeWindowToggle"):SetCheck(false)
	else
		self.wndMain:FindChild("btnLightCostumeToggle"):SetCheck(false)
	end
	self.wndCostumeSelectionList:Show(false)
	
	if self.nCurrentCostume > 0 and self.nCurrentCostume ~= nil then

		local wndCurrentCostume = wndCostumeHolder:FindChild("CostumeBtn" .. self.nCurrentCostume)
		local strName = wndCurrentCostume:GetText()
		self.wndMain:FindChild("SelectCostumeWindowToggle"):SetText(strName)
		GameLib.SetCostumeIndex(self.nCurrentCostume)
	else
		GameLib.SetCostumeIndex(self.nCurrentCostume)
		self.wndMain:FindChild("SelectCostumeWindowToggle"):SetText(Apollo.GetString("Character_CostumeSelectDefault"))
	end
	
	self.wndMain:FindChild("btnLock"):FindChild("bgArt"):Show(true)
	if lightMode == true then
		self.wndMain:FindChild("btnLightSheath"):FindChild("bgArt"):Show(true)
		self.wndMain:FindChild("btnLightReset"):FindChild("bgArt"):Show(true)
	end
end

function ItemPreviewImproved:OnCloseMountPreview()
	self.wndMount:Show(false)
end

function ItemPreviewImproved:OnLockOn()
	self.wndMain:SetStyle("Moveable", false)
	self.wndMain:SetStyle("Sizable", false)
end

function ItemPreviewImproved:OnLockOff()
	self.wndMain:SetStyle("Moveable", true)
	self.wndMain:SetStyle("Sizable", true)
end

function ItemPreviewImproved:LightModeOn()
	lightMode = true
	self:SwitchMode(lightMode)
	self:SetSizingMinimum(lightMode)
	nl, nt, nr, nb = self.wndMain:GetAnchorOffsets()
end

function ItemPreviewImproved:LightModeOff()
	lightMode = false
	self:SwitchMode(lightMode)
	self:SetSizingMinimum(lightMode)
	self.wndMain:SetAnchorOffsets(nl, nt, nr, nb)
end

function ItemPreviewImproved:SwitchMode(state)
	self.wndMain:FindChild("btnLightSheath"):Show(state)
	self.wndMain:FindChild("btnLightReset"):Show(state)
	self.wndMain:FindChild("btnLightCostumeToggle"):Show(state)
	self.wndMain:FindChild("SheathButton"):Show(not state)
	self.wndMain:FindChild("ResetButton"):Show(not state)
	self.wndMain:FindChild("SelectCostumeWindowToggle"):Show(not state)
end

function ItemPreviewImproved:SetSizingMinimum(state)
	if not state then
		local nWndLeft, nWndTop, nWndRight, nWndBottom = 462, 191, 811, 764
		local nWndWidth = nWndRight - nWndLeft
		local nWndHeight = nWndBottom - nWndTop
		self.wndMain:SetSizingMinimum(nWndWidth, nWndHeight)
	else
		self.wndMain:SetSizingMinimum(0, 0)
	end
end

function ItemPreviewImproved:ShowNoMountInfo()
	local output = "The mount you want to preview is currently \n not part of the mount table in ItemPreviewImproved!\n"
	output = output .. "To help the addon to get more mounts for preview install\n ItemPreviewImproved: MountTracker and follow the instructions!"
	self.wndMount:FindChild("noMountInformation"):FindChild("lblNoMountInformation"):SetText(output)
	if self.wndMount:FindChild("noMountInformation"):IsShown() then
		self.wndMount:FindChild("noMountInformation"):Show(false)
	else
		self.wndMount:FindChild("noMountInformation"):Show(true)
	end
end
-----------------------------------------------------------------------------------------------
-- ItemPreviewImproved Instance
-----------------------------------------------------------------------------------------------
local ItemPreviewImprovedInst = ItemPreviewImproved:new()
ItemPreviewImprovedInst:Init()
