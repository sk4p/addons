-----------------------------------------------------------------------------------------------
-- Client Lua Script for ItemPreviewImproved2
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "GameLib"
require "Item"
 
-----------------------------------------------------------------------------------------------
-- ItemPreviewImproved Module Definition
-----------------------------------------------------------------------------------------------
local ItemPreviewImproved = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
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

local ktTimeRemaining =
{
	[ItemAuction.CodeEnumAuctionRemaining.Expiring]		= Apollo.GetString("MarketplaceAuction_Expiring"),
	[ItemAuction.CodeEnumAuctionRemaining.LessThanHour]	= Apollo.GetString("MarketplaceAuction_LessThanHour"),
	[ItemAuction.CodeEnumAuctionRemaining.Short]		= Apollo.GetString("MarketplaceAuction_Short"),
	[ItemAuction.CodeEnumAuctionRemaining.Long]			= Apollo.GetString("MarketplaceAuction_Long"),
	--[ItemAuction.CodeEnumAuctionRemaining.Very_Long]	= Apollo.GetString("MarketplaceAuction_VeryLong") -- Uses string weasel to stick a number in
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

-- Supported Tradeskills Schematics Addons
local suppSchematics =
{
	"Hephaestus"
}

-- Supported Tradeskills Techtree Addons
local suppTechtree =
{
	"Tradeskills",
	"CRBTradeskills"
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
    Apollo.RegisterAddon(self)
end

function ItemPreviewImproved:OnSave(eLevel)
	
	if (eLevel ~= GameLib.CodeEnumAddonSaveLevel.Account) then 
		return 
	end 

	local l,t,r,b = self.wndMain:GetAnchorOffsets()
	
	return {
		tPosition_Main = { l = l, t = t, r = r, b = b },
	}
	
end

function ItemPreviewImproved:OnRestore(eLevel,tSavedData) 
	
	if (eLevel ~= GameLib.CodeEnumAddonSaveLevel.Account) then 
		return 
	end 
	
	local tPosMain = tSavedData.tPosition_Main
	local tPosTooltip = tSavedData.tPosition_Tooltip
	
	if tPosMain ~= nil then 
		self.wndMain:SetAnchorOffsets(tPosMain.l, tPosMain.t, tPosMain.r, tPosMain.b)
	end
	
	--if tPosTooltip ~= nil then 
	--	wndChatItemToolTip:SetAnchorOffsets(tPosMain.l, tPosMain.t, tPosMain.r, tPosMain.b)
	--end 
	
end 
 

 

-----------------------------------------------------------------------------------------------
-- ItemPreviewImproved OnLoad
-----------------------------------------------------------------------------------------------
function ItemPreviewImproved:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("ItemPreviewImproved.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "ItemPreviewImprovedForm", "TooltipStratum", self)
	self.alreadyLoadedCostume = {}
	playerunit = GameLib.GetPlayerUnit()
	self.wndMain:FindChild("PreviewWindow"):SetCostume(playerunit)
	self.wndMain:FindChild("PreviewInformation"):Show(false)
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
    	Apollo.RegisterTimerHandler("EventThresholdTimer", "ItemPreviewFormOpenCallback", self)
		Apollo.RegisterTimerHandler("UpdateCostume", "UpdateCostume", self)
    	Apollo.CreateTimer("EventThresholdTimer", 0.01, false)
		Apollo.CreateTimer("UpdateCostume", 0.2, false)

		-- Do additional Addon initialization here	
		--[[
			AUCTIONHOUSE
						]]--
						
		AuctionHouseAddon = Apollo.GetAddon("MarketplaceAuction")
		
		if AuctionHouseAddon == nil then
			ChatSystemLib.PostOnChannel(2,"ItemPreviewImproved: Could not load any supported Auctionhouse addon! \nPlease contact the author of the addon via Curse!")
		else
	
		AuctionHouseAddon.BuildListItem = function (luaCaller, aucCurr, wndParent, bBuyTab)
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
			TRADESKILL TECH TREE
						]]--
		for key,val in pairs(suppTechtree) do
			TechtreeAddon = Apollo.GetAddon(val)
		
			if TechtreeAddon ~= nil then
				break
			end
		end
		
		if TechtreeAddon == nil then
			ChatSystemLib.PostOnChannel(2,"ItemPreviewImproved: Could not load any supported Tradeskill addon! \nPlease contact the author of the addon via Curse!")
		else
		
		fTradeskillHelperBuildItemToolTip = TechtreeAddon.HelperBuildItemTooltip
		TechtreeAddon.HelperBuildItemTooltip = TradeskillHelperBuildItemTooltipHook
		
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
			fHelperBuildItemToolTip = DialogAddon.HelperBuildItemTooltip
			DialogAddon.HelperBuildItemTooltip = HelperBuildItemTooltipHook
		
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
		
			fHelperBuildRewardsRec = QuestLogAddon.HelperBuildRewardsRec
			QuestLogAddon.HelperBuildRewardsRec = HelperBuildRewardsRecHook
			
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
		
		ChatAddon.OnNodeClick = function (luaCaller, wndHandler, wndControl, strNode, tAttributes, eMouseButton)
			-- can only report players who are not yourself, which matches who we want this menu for.
			if strNode == "Source" and eMouseButton == GameLib.CodeEnumInputMouse.Right and tAttributes.CharacterName and tAttributes.nReportId then
				Event_FireGenericEvent("GenericEvent_NewContextMenuPlayer", wndHandler, tAttributes.CharacterName, nil, tAttributes.nReportId)
				return true
			end

			if strNode == "Link" then
	
				-- note, tAttributes.nLinkIndex is a string value, instead of the int we passed in because it was saved
				-- 	out as xml text then read back in.
				local nIndex = tonumber(tAttributes.strIndex)

				if ChatAddon.tLinks[nIndex] and
					( ChatAddon.tLinks[nIndex].uItem or ChatAddon.tLinks[nIndex].uQuest or ChatAddon.tLinks[nIndex].uArchiveArticle ) then
	
					if Apollo.IsShiftKeyDown() then
	
						local wndEdit = ChatAddon.HelperGetCurrentEditbox(luaCaller)
	
						-- pump link to the chat line
						if wndEdit then
							ChatAddon.HelperAppendLink(luaCaller,wndEdit,ChatAddon.tLinks[nIndex])
						end
					else
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

					
						local bWindowExists = false
						for idx, wndCur in pairs(ChatAddon.twndItemLinkTooltips or {}) do
							if wndCur:GetData() == ChatAddon.tLinks[nIndex].uItem then
								bWindowExists = true
								break
							end
						end
				
						if bWindowExists == false then
						
							-- Change some functionality because BetterChatLog isn't up to date with Tooltips
							if ChatAddonName == "BetterChatLog" or ChatAddonName == "FixedChatLog" then
							
								itemCurr = ChatAddon.tLinks[nIndex].uItem
								wndControl:SetTooltipDoc(nil)

								local itemEquipped = itemCurr:GetEquippedItemForItemType()
								Tooltip.GetItemTooltipForm(Chataddon, wndHandler, itemCurr, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
							else
								local wndChatItemToolTip = Apollo.LoadForm(ChatAddonXML, "TooltipWindow", nil, ChatAddon)
								wndChatItemToolTip:SetData(ChatAddon.tLinks[nIndex].uItem)
						
								table.insert(ChatAddon.twndItemLinkTooltips, wndChatItemToolTip)
							
								local itemEquipped = ChatAddon.tLinks[nIndex].uItem:GetEquippedItemForItemType()
												
								local wndLink = Tooltip.GetItemTooltipForm(ChatAddon, wndControl, ChatAddon.tLinks[nIndex].uItem, {bPermanent = true, wndParent = wndChatItemToolTip, bSelling = false, bNotEquipped = true})
						
								local nLeftWnd, nTopWnd, nRightWnd, nBottomWnd = wndChatItemToolTip:GetAnchorOffsets()
								local nLeft, nTop, nRight, nBottom = wndLink:GetAnchorOffsets()
						
								wndChatItemToolTip:SetAnchorOffsets(nLeftWnd, nTopWnd, nLeftWnd + nRight + 15, nBottom + 75)
						
								if itemEquipped then
									wndChatItemToolTip:SetTooltipDoc(nil)
									Tooltip.GetItemTooltipForm(ChatAddon, wndChatItemToolTip, itemEquipped, {bPrimary = true, bSelling = false, bNotEquipped = false})
								end
							end
							end
					
					elseif ChatAddon.tLinks[nIndex].uQuest then
						Event_FireGenericEvent("ShowQuestLog", wndHandler:GetData()) -- Codex (todo: deprecate this)
						Event_FireGenericEvent("GenericEvent_ShowQuestLog", ChatAddon.tLinks[nIndex].uQuest)
					elseif ChatAddon.tLinks[nIndex].uArchiveArticle then
						Event_FireGenericEvent("HudAlert_ToggleLoreWindow")
						Event_FireGenericEvent("GenericEvent_ShowGalacticArchive", ChatAddon.tLinks[nIndex].uArchiveArticle)
					end
				end
			end
		end

		return false
	end
end
end


-----------------------------------------------------------------------------------------------
-- ItemPreviewImproved Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

function ItemPreviewImproved:UpdateCostume()
	self.wndMain:FindChild("PreviewWindow"):SetCostume(GameLib.GetPlayerUnit())
	for key,val in pairs(currPreviewedItems) do
		self.wndMain:FindChild("PreviewWindow"):SetItem(val)
	end
end 

function TradeskillHelperBuildItemTooltipHook(luaCaller, wndArg, item)
	fTradeskillHelperBuildItemToolTip(luaCaller, wndArg, item)
	wndArg:AddEventHandler("MouseButtonUp", "OnMouseButtonUp")
	wndArg:SetData(item)
end

function HelperBuildRewardsRecHook(luaCaller, wndReward, tRewardData, bReceived)
	fHelperBuildRewardsRec(luaCaller, wndReward, tRewardData, bReceived)
	wndReward:AddEventHandler("MouseButtonUp", "OnMouseButtonUp")
	wndReward:SetData(tRewardData.itemReward)
end

function HelperBuildItemTooltipHook(luaCaller, wndArg, item)
	fHelperBuildItemToolTip(luaCaller, wndArg, item)
	wndArg:AddEventHandler("MouseButtonUp", "OnMouseButtonUp")
	wndArg:SetData(item)
end

function ItemPreviewImproved:DelayTimer()
       Apollo.StartTimer("EventThresholdTimer")
end
 
function ItemPreviewImproved:ItemPreviewFormOpenCallback()
        local wndImpSalv = Apollo.FindWindowByName("ItemPreviewForm")
        if wndImpSalv and wndImpSalv:IsShown() then
               wndImpSalv:Show(false)
			   wndImpSalv:Destroy()
        end
end

function ItemPreviewImproved:OnShowItemInDressingRoom(item)
self:DelayTimer()

	if item == nil or not self:HelperValidateSlot(item) then
		return
	end
	
	if playerunit == nil or playerunit ~= GameLib.GetPlayerUnit() then
		self.wndMain:FindChild("PreviewWindow"):SetCostume(GameLib.GetPlayerUnit())
		playerunit = GameLib.GetPlayerUnit()
	end
	
	local nWndLeft, nWndTop, nWndRight, nWndBottom = self.wndMain:GetRect()
	local nWndWidth = nWndRight - nWndLeft
	local nWndHeight = nWndBottom - nWndTop
	self.wndMain:SetSizingMinimum(nWndWidth - 10, nWndHeight - 10)
	self.wndMain:FindChild("PreviewWindow"):SetItem(item)

	
	if self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end


	-- set item name;
	--local strLabel = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"UI_TextHoloBody\" Align=\"Center\">%s</T>", Apollo.GetString("Inventory_ItemPreviewLabel"))
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

	self.wndMain:Show(true)
	
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
	--self.wndMain:FindChild("PreviewWindow"):SetCostume(nil)
	
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
	self.wndMain:FindChild("PreviewWindow"):ToggleLeftSpin(true)
end

function ItemPreviewImproved:OnRotateRightCancel()
	self.wndMain:FindChild("PreviewWindow"):ToggleLeftSpin(false)
end

function ItemPreviewImproved:OnRotateLeft()
	self.wndMain:FindChild("PreviewWindow"):ToggleRightSpin(true)
end

function ItemPreviewImproved:OnRotateLeftCancel()
	self.wndMain:FindChild("PreviewWindow"):ToggleRightSpin(false)
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
end

function ItemPreviewImproved:CostumeSelectionWindowHide()
	self.wndCostumeSelectionList:Show(false)
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

	self.wndMain:FindChild("Middle:BGArt_HeaderFrame:SelectCostumeWindowToggle"):SetCheck(false)
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
		self.wndMain:FindChild("PreviewWindow"):SetCostume(nil)
		Apollo.StartTimer("UpdateCostume")
end

-----------------------------------------------------------------------------------------------
-- ItemPreviewImproved Instance
-----------------------------------------------------------------------------------------------
local ItemPreviewImprovedInst = ItemPreviewImproved:new()
ItemPreviewImprovedInst:Init()
