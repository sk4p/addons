-----------------------------------------------------------------------------------------------
-- Client Lua Script for BetterQuestLog
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

-- octanepenguin on reddit/r/wildstar

require "Window"
require "Quest"
require "QuestLib"
require "QuestCategory"
require "Unit"
require "Episode"
require "GameLib"
require "Money"
require "GroupLib"

local BetterQuestLog = {}
local lastSelected = nil
local groupMembers = {}
local activeQuests = {} --table of only active quests (populated when generated)
local needsRedraw = false
local isDebugMode = false
local isSoloMode = false

local log = {}

---------------
-- Logging (not using GeminiLogging)
function log:error(msg)
	--Print('[ERROR] '..msg)
end
function log:warn(msg)
	--Print('[WARNING] '..msg)
end
function log:debug(msg)
	--Print('[DEBUG] '..msg)
end
function log:info(msg)
	--Print('[INFO] '..msg)
end

--[[ Quest States, For Reference:
	QuestState_Unknown);
	QuestState_Accepted);	-- 1
	QuestState_Achieved);	-- 2
	QuestState_Completed);	-- 3
	QuestState_Botched);	-- 4
	QuestState_Mentioned); 	-- 5
	QuestState_Abandoned);	-- 6
	QuestState_Ignored);	-- 7
]]--

function BetterQuestLog:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

	o.arLeftTreeMap = {}

    return o
end

function BetterQuestLog:Init()
    Apollo.RegisterAddon(self)
end

-- Constants
local ktConToUI =
{
	{ "CRB_Basekit:kitFixedProgBar_1", "ff9aaea3", Apollo.GetString("QuestLog_Trivial") },
	{ "CRB_Basekit:kitFixedProgBar_2", "ff37ff00", Apollo.GetString("QuestLog_Easy") },
	{ "CRB_Basekit:kitFixedProgBar_3", "ff46ffff", Apollo.GetString("QuestLog_Simple") },
	{ "CRB_Basekit:kitFixedProgBar_4", "ff3052fc", Apollo.GetString("QuestLog_Standard") },
	{ "CRB_Basekit:kitFixedProgBar_5", "ffffffff", Apollo.GetString("QuestLog_Average") },
	{ "CRB_Basekit:kitFixedProgBar_6", "ffffd400", Apollo.GetString("QuestLog_Moderate") },
	{ "CRB_Basekit:kitFixedProgBar_7", "ffff6a00", Apollo.GetString("QuestLog_Tough") },
	{ "CRB_Basekit:kitFixedProgBar_8", "ffff0000", Apollo.GetString("QuestLog_Hard") },
	{ "CRB_Basekit:kitFixedProgBar_9", "fffb00ff", Apollo.GetString("QuestLog_Impossible") }
}

local ktConToUINoAlpha =
{
	{ "CRB_Basekit:kitFixedProgBar_1", "9aaea3", Apollo.GetString("QuestLog_Trivial") },
	{ "CRB_Basekit:kitFixedProgBar_2", "37ff00", Apollo.GetString("QuestLog_Easy") },
	{ "CRB_Basekit:kitFixedProgBar_3", "46ffff", Apollo.GetString("QuestLog_Simple") },
	{ "CRB_Basekit:kitFixedProgBar_4", "3052fc", Apollo.GetString("QuestLog_Standard") },
	{ "CRB_Basekit:kitFixedProgBar_5", "ffffff", Apollo.GetString("QuestLog_Average") },
	{ "CRB_Basekit:kitFixedProgBar_6", "ffd400", Apollo.GetString("QuestLog_Moderate") },
	{ "CRB_Basekit:kitFixedProgBar_7", "ff6a00", Apollo.GetString("QuestLog_Tough") },
	{ "CRB_Basekit:kitFixedProgBar_8", "ff0000", Apollo.GetString("QuestLog_Hard") },
	{ "CRB_Basekit:kitFixedProgBar_9", "fb00ff", Apollo.GetString("QuestLog_Impossible") }
}

local ktValidCallButtonStats =
{
	[Quest.QuestState_Ignored] 			= true,
	[Quest.QuestState_Achieved] 		= true,
	[Quest.QuestState_Abandoned] 		= true,
	[Quest.QuestState_Botched] 			= true,
	[Quest.QuestState_Mentioned] 		= true,
}

local kcrSelectedColor = ApolloColor.new("ffffeea4")
local kcrDeselectedColor = ApolloColor.new("ffa0a0a0")
local kcrHoloColorBright = ApolloColor.new("ff31fcf6")
local kcrHoloColorDim = ApolloColor.new("ff2f94ac")

local karEvalColors =
{
	[Item.CodeEnumItemQuality.Inferior] 			= ApolloColor.new("ItemQuality_Inferior"),
	[Item.CodeEnumItemQuality.Average] 			= ApolloColor.new("ItemQuality_Average"),
	[Item.CodeEnumItemQuality.Good] 			= ApolloColor.new("ItemQuality_Good"),
	[Item.CodeEnumItemQuality.Excellent] 			= ApolloColor.new("ItemQuality_Excellent"),
	[Item.CodeEnumItemQuality.Superb] 			= ApolloColor.new("ItemQuality_Superb"),
	[Item.CodeEnumItemQuality.Legendary] 			= ApolloColor.new("ItemQuality_Legendary"),
	[Item.CodeEnumItemQuality.Artifact]		 	= ApolloColor.new("ItemQuality_Artifact"),
}

function BetterQuestLog:OnLoad()
	self.isDebugMode = false
	self.isSoloMode = false

	self.xmlDoc = XmlDoc.CreateFromFile("BetterQuestLog.xml") -- BetterQuestLog will always be kept in memory, so save parsing it over and over
	
	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", 	"OnInterfaceMenuListHasLoaded", self)	-- for codex entry at the bottom left
	Apollo.RegisterEventHandler("ShowQuestLog", 	 			"Initialize", self)
	Apollo.RegisterEventHandler("ShowQuestLog",		 			"CheckIfNeedsRedraw", self)
	Apollo.RegisterEventHandler("Dialog_QuestShare", 	 		"OnDialog_QuestShare", self)
	Apollo.RegisterEventHandler("Group_Join",		 			"OnGroupJoin", self) 			-- for broadcasting upon joining a group
	Apollo.RegisterEventHandler("Group_Remove",		 			"OnGroupRemove", self)			-- ( name, reason )
	Apollo.RegisterEventHandler("Group_Left",		 			"OnGroupLeft", self)			-- ( reason )
	Apollo.RegisterEventHandler("Group_MemberPromoted",			"OnMemberPromotion", self)		-- whenever someone is promoted we need to update our bql channel
	Apollo.RegisterTimerHandler("ShareTimeout", 	 	 		"OnShareTimeout", self)
	Apollo.RegisterTimerHandler("OnLoadFinishedTimer",	 		"BetterQuestLogLoaded", self)
	Apollo.RegisterTimerHandler("ReRequestBroadcast", 	 		"RequestGroupBroadcast", self)
	Apollo.RegisterEventHandler("GenericEvent_ShowQuestLog",	"OnQuestLinkClicked", self)		-- probably happens under other circumstances that I'm not aware of
	
	-- these game events cause reloading group data (got this from OneJob)
	--	self:RegisterBucketEvent(
	--		{
	--			"Group_Updated", 
	--			"Group_Join", --done
	--			"Group_Left",  --done
	--			"Group_Remove",  --done
	--			"Group_MemberFlagsChanged"
	--		}, 5, "OnPartyChange")  --Whenever our party changes, change our BQL channel and rebroadcast

	self.nQuestCountMax = QuestLib.GetMaxCount() -- we need this here for... something, figure it out --FIXME
	
	-- added a timer so that my broadcasting will work appropriately being called from OnLoad(thanks packetdancer!)
	-- we needed to wait for onload to finish
	Apollo.CreateTimer("OnLoadFinishedTimer", 3, false)
	Apollo.StartTimer("OnLoadFinishedTimer")
end

function BetterQuestLog:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "BetterQuestLog", {"ToggleQuestLog", "Codex", "Icon_Windows32_UI_CRB_InterfaceMenu_QuestLog"})
end

function BetterQuestLog:OnQuestLinkClicked(quest)
	if not self.wndMain then
		log:debug("could not find main window for linked quest")
		return
	end
	
	log:debug("showing linked quest")
	
	self.wndMain:FindChild("RightSide"):Show(true)
	self.wndMain:FindChild("RightSide"):SetVScrollPos(0)
	self.wndMain:FindChild("RightSide"):RecalculateContentExtents()
	self.wndMain:FindChild("RightSide"):SetData(quest)
	self:RedrawEverything()
end

-- whenever a member of our group is promoted, we update the channel we're communicating on
function BetterQuestLog:OnMemberPromotion()
	log:info("OnMemberPromotion")
	self:JoinBQLChannel()
end

function BetterQuestLog:OnPartyChange()
	log:info("OnPartyChange called")
	self:ObtainGroupMembers() 		-- obtain our current group members (rebuilds the groupMembers table)
	self:JoinBQLChannel(); 			-- join the appropriate bql channel
	self:RequestGroupBroadcast(); 	-- request and
	self:BroadcastActiveQuests();	-- broadcast active quests
end

-- Joins a channel particular to the current group leader
function BetterQuestLog:JoinBQLChannel()
	log:info("JoinBQLChannel called")
	local leader =	self:GetGroupLeader()
	
	if self.isSoloMode then
		local playerName = GameLib.GetPlayerUnit():GetName()
		log:debug("Joining channel for " .. playerName)
		self.bqlChannel = ICCommLib.JoinChannel(playerName.."BQLChannel", "OnBQLMessage", self)
	elseif leader then
		log:debug("Joing channel for " .. leader.strCharacterName)
		self.bqlChannel = ICCommLib.JoinChannel(leader.strCharacterName.."BQLChannel", "OnBQLMessage", self)
	else
		log:debug("bqlChannel set to nil")
		self.bqlChannel = nil
	end
end

function BetterQuestLog:GetGroupLeader()
	local partySize = GroupLib.GetMemberCount()
	for idx = 1, partySize do
		local member = GroupLib.GetGroupMember(idx)
		if member.bIsLeader then
			return member
		end
	end	
	return nil
end

function BetterQuestLog:BetterQuestLogLoaded()	
	log:debug("BetterQuestLogLoaded called")
	
	--local Rover = Apollo.GetAddon("Rover")
    --Rover:AddWatch("groupMembers", self.groupMembers)

	if GameLib.GetPlayerUnit() == nil or GameLib.GetPlayerUnit():GetName() == nil then
		log:debug("GameLib.GetPlayer wasn't ready... waiting 3 seconds")
		Apollo.CreateTimer("OnLoadFinishedTimer", 3, false)
		Apollo.StartTimer("OnLoadFinishedtimer")
	else
		log:debug("BetterQuestLog Loaded")
		self:JoinBQLChannel()		

		self:CreateActiveQuestsTable() -- not really happy with this atm
		self:ObtainGroupMembers()
		if self.isDebugMode or GroupLib.InGroup() or GroupLib.InRaid() then
			self:BroadcastActiveQuests()
			self:RequestGroupBroadcast()
		end
	end
end

function BetterQuestLog:CheckIfNeedsRedraw()
	if self.needsRedraw then
		self:RedrawEverything()
		self.needsRedraw = false
	end
end

-- adds a player with the player name to our groupMember table if they don't exist already
function BetterQuestLog:AddGroupMember(playerName)	
	-- initialize if it didn't exist already for some reason?? (ideally i'd like to avoid this)
	if self.groupMembers == nil then
		log:debug("Group member did not have table destination, adding groupMembers table")
		self.groupMembers = {}
	end
	
	if playerName ~= GameLib.GetPlayerUnit():GetName() or self.isDebugMode then	
		if self.groupMembers[playerName] == nil then
			log:debug("AddGroupMember - " .. playerName)
			-- if they didn't, create them
			self.groupMembers[playerName] = {}
			self.groupMembers[playerName].quests = {}
			self.groupMembers[playerName].strPlayerName = playerName
		end
	end
end

-- populate our group members table
function BetterQuestLog:ObtainGroupMembers()
	log:debug("ObtainGroupMembers")
	self.groupMembers = {}
	local nGroupMemberCount = GroupLib.GetMemberCount()
	if nGroupMemberCount < 2 and not self.isDebugMode then
		log:debug("Not in a group and not in debug mode so aborted group members table creation.")
		return
	end
	
	if self.isSoloMode then
		self:AddGroupMember(GameLib.GetPlayerUnit():GetName())
	else
		for i=1, nGroupMemberCount do
			self:AddGroupMember(GroupLib.GetGroupMember(i).strCharacterName)
		end	
	end
end

-- creates our active quest table, I feel like there should be a better way of obtaining this, maybe look into?
function BetterQuestLog:CreateActiveQuestsTable()
	-- here we simply iterate through every quest in the game <maybe?> and check if it's completed, horrible right? I'm not even
	-- sure that's what happens exactly..
	self.activeQuests = {} -- make sure nothing old is in here for when we repopulate it
	for key, qcCategory in pairs(QuestLib.GetKnownCategories()) do
		for key, epiEpisode in pairs(qcCategory:GetEpisodes()) do
			for key, queQuest in pairs(epiEpisode:GetAllQuests(qcCategory:GetId())) do
				local eState = queQuest:GetState()	
				if eState ~= Quest.QuestState_Completed and eState ~= Quest.QuestState_Abandoned and eState ~= Quest.QuestState_Ignored and eState ~= Quest.QuestState_Botched then
					self.activeQuests[queQuest:GetTitle()] = queQuest
				end
			end
		end
	end
end

function BetterQuestLog:UpdateActiveQuestTable(queTarget)
	local qTitle = queTarget:GetTitle()
	if self.activeQuests[qTitle] ~= nil then
		local eState = queTarget:GetState()
		if eState ~= Quest.QuestState_Completed and eState ~= Quest.QuestState_Abandoned and eState ~= Quest.QuestState_Ignored and eState ~= Quest.QuestState_Botched then
			-- we consider this "active" for our purposes
			self.activeQuests[qTitle] = queTarget
		else
			-- otherwise remove it from this table
			self.activeQuests[qTitle] = nil
		end
	elseif eState ~= Quest.QuestState_Completed and eState ~= Quest.QuestState_Abandoned and eState ~= Quest.QuestState_Ignored and eState ~= Quest.QuestState_Botched then
		-- just handle the add since this key was nil
		self.activeQuests[qTitle] = queTarget
	end
end

-- determines if the bql message was from one of my group members
function BetterQuestLog:IsGroupMemberMessage(tMsg)
	if self.isDebugMode then
		return true
	end

	if not GroupLib.InGroup() and not GroupLib.InRaid() then
		return false -- that was easy, I have no group
	end
		
	-- as we iterate through our group members, as soon as we hit one match, we know it's a group message
	-- and that's all we care about here
	local nGroupMemberCount = GroupLib.GetMemberCount()
	if nGroupMemberCount > 1 then
		for idx = 1, nGroupMemberCount do
			local tMemberInfo = GroupLib.GetGroupMember(idx)
			if tMemberInfo.strCharacterName == tMsg.strPlayerName then
				return true
			end
		end
	end
	
	return false
end

-- tMsg = { strEventName, strPlayerName, strQuestId, eQuestState}
function BetterQuestLog:OnBQLMessage(channel, tMsg)
	-- two things happen here, i can receive an update, or i can receive a request for a full broadcast
	-- either way, neither matter if i'm not in a group
	
	--debug
	if self.isDebugMode then
		if self.recCount == nil then
			self.recCount = 0
		end
	
		if self.bqlRec == nil then
			self.bqlRec = {}
		end
	
		self.bqlRec[self.recCount] = tMsg
		self.recCount = self.recCount + 1
	end
			
	local nGroupMemberCount = GroupLib.GetMemberCount()
	if nGroupMemberCount < 2 and not self.isDebugMode then
		return
	end
	
	-- now that i know i'm in a group, let's start by making sure that the event name exists and is included
	if type(tMsg.strEventName) ~= "string" then
		-- if not let's just let this one go, nothing should cause this to happen atm besides my own stupidity
		-- but carbine likes doing this so let's follow thier standards for future work in case something gets
		-- added that we didn't plan on
		eventNameNotAString()
		return
	end
	
	-- check if this message was for me to broadcast
	local myName = GameLib.GetPlayerUnit():GetName()	
	if tMsg.strEventName == "RequestBroadcast" and tMsg.strPlayerName == myName then
		-- it was, share with the world my quest log
		--this part confirmed working appropriately
		self:BroadcastActiveQuests()
	--if the message wasn't a request for broadcast it was a QuestUpdated from someone else..
	--check that they're in my group and update if so
	elseif tMsg.strEventName == "QuestUpdated" and self:IsGroupMemberMessage(tMsg) then 
		self:AddGroupMember(tMsg.strPlayerName) -- won't add if it already exists
		-- store the information we received in our table (overwriting any previous)
		self.groupMembers[tMsg.strPlayerName].quests[tMsg.strQuestId] = tMsg.eQuestState
		-- todo: handle the drawing of the update wherever we actually draw, not here
		
		-- we updated so flag us for a redraw
		-- using a timer so that if the quest log is open, it will still update after a couple seconds
		-- this is so that we don't have to call a RedrawEverything for EVERY SINGLE update message we receive
		-- so in the case that we receive 50 updates in 5 seconds I'd expect the timer to keep resetting  to
		-- 2 seconds each time we got an update and then after the last one, the 2 sec would run out and it would
		-- update
		Apollo.StopTimer("RedrawFromUpdate")
		Apollo.CreateTimer("RedrawFromUpdate", 2, false) -- create a 2 second timer for live updating
		Apollo.StartTimer("RedrawFromUpdate")
		self.needsRedraw = true
	--else -- NO! don't do this!
		--NOPE() -- will create a hilarious stack trace if reached --WAS REALLY REALLY BAD - PREVENTS EVERYONE FROM USING THIS PROPERLY
	end
end

-- redraws the quest log LIVE as the result of an update
function BetterQuestLog:OnRedrawFromUpdate()
	-- note, no need for redraw if we're not even initialized yet
	if self.wndMain and self.wndMain:IsValid() and self.needsRedraw then
		self:RedrawEverything()
		self.needsRedraw = false
	end
end

-- counts the # of instances of a quest id in our groupMembers table
function BetterQuestLog:CountInstancesOfQuestId(queId)
	local num = 0
	if self.groupMembers == nil then
		return 0
	end	
	for key, member in pairs(self.groupMembers) do
		local eQuestState = member.quests[queId]
		if eQuestState ~= nil then --this quest existed in the player's log
			if eQuestState ~= Quest.QuestState_Ignored and eQuestState ~= Quest.QuestState_Abandoned and eQuestState ~= Quest.QuestState_Completed then
				num = num + 1
			end
		end
	end
	return num
end

function BetterQuestLog:Initialize()
	if (self.wndMain and self.wndMain:IsValid()) or not g_wndProgressLog then
		return
	end
	
	--Apollo.RegisterEventHandler("EpisodeStateChanged", 			"DestroyAndRedraw", self) -- Not sure if this can be made stricter
	Apollo.RegisterEventHandler("EpisodeStateChanged",			"RedrawEverything", self)
	Apollo.RegisterEventHandler("QuestStateChanged", 			"OnQuestStateChanged", self) -- Routes to OnDestroyQuestObject if completed/botched
	Apollo.RegisterEventHandler("QuestObjectiveUpdated", 			"OnQuestObjectiveUpdated", self)
	Apollo.RegisterEventHandler("GenericEvent_ShowQuestLog", 		"OnGenericEvent_ShowQuestLog", self)
	Apollo.RegisterTimerHandler("RedrawQuestLogInOneSec", 			"DestroyAndRedraw", self) -- TODO Remove if possible
	Apollo.RegisterTimerHandler("RedrawFromUpdate",			 	"OnRedrawFromUpdate", self)

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "BetterQuestLogForm", g_wndProgressLog:FindChild("ContentWnd_1"), self)

	-- Variables
	self.wndLastBottomLevelBtnSelection = nil -- Just for button pressed state faking of text color

	-- Default states
	self.wndMain:FindChild("LeftSideFilterBtnShowActive"):SetCheck(true)
	self.wndMain:FindChild("ShowLevelCheckboxBtn"):SetCheck(false)
	self.wndMain:FindChild("QuestAbandonPopoutBtn"):AttachWindow(self.wndMain:FindChild("QuestAbandonConfirm"))
	--self.wndMain:FindChild("QuestInfoMoreInfoToggleBtn"):AttachWindow(self.wndMain:FindChild("QuestInfoMoreInfoTextBG"))
	--self.wndMain:FindChild("EpisodeSummaryExpandBtn"):AttachWindow(self.wndMain:FindChild("EpisodeSummaryPopoutTextBG"))

	-- Measure Windows
	local wndMeasure = Apollo.LoadForm(self.xmlDoc, "PreviousTopLevelItem", nil, self)
	self.knTopLevelHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	wndMeasure = Apollo.LoadForm(self.xmlDoc, "MiddleLevelItem", nil, self)
	self.knMiddleLevelHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	wndMeasure = Apollo.LoadForm(self.xmlDoc, "BottomLevelItem", nil, self)
	self.knBottomLevelHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	wndMeasure = Apollo.LoadForm(self.xmlDoc, "ObjectivesItem", nil, self)
	self.knObjectivesItemHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	self.knRewardRecListHeight = self.wndMain:FindChild("QuestInfoRewardRecFrame"):GetHeight()
	self.knRewardChoListHeight = self.wndMain:FindChild("QuestInfoRewardChoFrame"):GetHeight()
--	self.knMoreInfoHeight = self.wndMain:FindChild("QuestInfoMoreInfoFrame"):GetHeight()
	self.knMoreInfoHeight = self.wndMain:FindChild("QuestInfoMoreInfoText"):GetHeight()
	
	self.knEpisodeInfoHeight = self.wndMain:FindChild("EpisodeInfo"):GetHeight()
	
	--self:DestroyAndRedraw()
	self:RedrawEverything()
end

function BetterQuestLog:OnGenericEvent_ShowQuestLog(queTarget)
	if not self.wndMain or not self.wndMain:IsValid() then
		self:Initialize()
	end
	
	self.wndMain:FindChild("LeftSideFilterBtnShowActive"):SetCheck(true)
	self.wndMain:FindChild("LeftSideFilterBtnShowHidden"):SetCheck(false)
	self.wndMain:FindChild("LeftSideFilterBtnShowFinished"):SetCheck(false)	
	self.wndMain:FindChild("LeftSideScroll"):DestroyChildren()
	self:RedrawEverything()
	
	local qcTop = queTarget:GetCategory()
	--local epiMid = queTarget:GetEpisode()
	
	local strCategoryKey = "C"..qcTop:GetId()
	local wndCategory = self.wndMain:FindChild("LeftSideScroll"):FindChildByUserData(strCategoryKey)
	if wndCategory then
		wndCategory:FindChild("PreviousTopLevelBtn"):SetCheck(true)
		self:RedrawLeftTree()
		--local strEpisodeKey = strCategoryKey.."E"..epiMid:GetId()
		--local wndMiddle = wndTop:FindChild("PreviousTopLevelItems"):FindChildByUserData(strEpisodeKey)
		--if wndMiddle then
		--self:RedrawLeftTree()
		--local strQuestKey = strEpisodeKey.."Q"..queTarget:GetId()
		strQuestKey = "Q"..queTarget:GetId()
		--local wndBot = wndMiddle:FindChild("MiddleLevelItems"):FindChildByUserData(strQuestKey)
		
		wndQuest = wndCategory:FindChild("PreviousTopLevelItems"):FindChildByUserData(strQuestKey)
		--local bAllFiltersParsed = false
		--while not wndQuest and not bAllFiltersParsed do
--			if self.wndMain:FindChild("LeftSideFilterBtnShowActive"):IsChecked() then
				--self.wndMain:FindChild("LeftSideFilterBtnShowActive"):SetCheck(false) -- check next filter
				--self.wndMain:FindChild("LeftSideFilterBtnShowFinished"):SetCheck(true)
				--self:RedrawLeftTree()
			--elseif self.wndMain:FindChild("LeftSideFilterBtnShowFinished"):IsChecked() then
--				self.wndMain:FindChild("LeftSideFilterBtnShowFinished"):SetCheck(false) -- check next filter
				--self.wndMain:FindChild("LeftSideFilterBtnShowHidden"):SetCheck(true)
				--self:RedrawLeftTree()
			--else
--				bAllFiltersParsed = true
			--end
			--wndQuest = wndCategory:FindChild("PreviousTopLevelItems"):FindChildByUserData(strQuestKey)
		--end
		--TOOOOOO SLOOOOWWW
		
		--wndCategory:FindChild("PreviousTopLevelBtn"):SetText(wndQuest)
		
		if wndQuest then
			local wndTop = wndQuest:FindChild("TopLevelBtn")
			self:CheckTrackedToggle(wndTop, wndTop)
		else
			--quest didn't exist in the user's quest log so just show it in the right side
			self:DrawRightSide(queTarget)
			self:ResizeRight()
		end
	else
		self:DrawRightSide(queTarget)
		self:ResizeRight()
	end
end

function BetterQuestLog:DestroyAndRedraw() -- TODO, remove as much as possible that calls this
	self.wndMain:FindChild("LeftSideScroll"):DestroyChildren()
	--self:RedrawEverything()

	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:FindChild("LeftSideScroll"):DestroyChildren()
		self.arLeftTreeMap = {}
	end

	self:RedrawLeftTree()

	-- Show first in Quest Log (on second thought, this is aggravating since top item could be just tradeskills)
	--local wndCategory = self.wndMain:FindChild("LeftSideScroll"):GetChildren()[1]
	--if wndCategory then
		--wndCategory :FindChild("PreviousTopLevelBtn"):SetCheck(true)
		--self:RedrawLeftTree()
--		
		--local wndTop = wndCategory:FindChild("PreviousTopLevelItems"):GetChildren()[1]
		--if wndTop then
--			self:CheckTrackedToggle(wndTop, wndTop, 0)
		--end
		--doShowQuestLog = true
	--end

	self:RedrawEverything()
	--self.wndMain:FindChild("RightSide"):Show(doShowQuestLog) --If nothing selected hide right side
end

function BetterQuestLog:RedrawFromUI()
	self:RedrawEverything()
end

function BetterQuestLog:RedrawEverything()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	self:RedrawLeftTree()
	local bLeftSideHasResults = #self.wndMain:FindChild("LeftSideScroll"):GetChildren() ~= 0
	self.wndMain:FindChild("LeftSideScroll"):SetText(bLeftSideHasResults and "" or Apollo.GetString("QuestLog_NoResults"))
	--self.wndMain:FindChild("QuestInfoControls"):Show(bLeftSideHasResults)
	--self.wndMain:FindChild("RightSide"):Show(bLeftSideHasResults)

	if self.wndMain:FindChild("RightSide"):IsShown() and self.wndMain:FindChild("RightSide"):GetData() then
		self:DrawRightSide(self.wndMain:FindChild("RightSide"):GetData())
	end

	self:ResizeRight()
end

function BetterQuestLog:RedrawLeftTree()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local nQuestCount = QuestLib.GetCount()
	local strColor = "ff2f94ac"
	if nQuestCount + 3 >=  self.nQuestCountMax then
		strColor = "ffff0000"
	elseif nQuestCount + 10 >= self.nQuestCountMax then
		strColor = "ffffb62e"
	end
	
	local filterShowActive = self.wndMain:FindChild("LeftSideFilterBtnShowActive")
	
	local strActiveQuests = string.format("<T TextColor=\"%s\">%s</T>", strColor, nQuestCount)
	strActiveQuests = String_GetWeaselString(Apollo.GetString("QuestLog_ActiveQuests"), strActiveQuests, self.nQuestCountMax)
	self.wndMain:FindChild("QuestLogCountText"):SetAML(string.format("<P Font=\"CRB_InterfaceSmall_O\" Align=\"Center\" TextColor=\"ff2f94ac\">%s</P>", strActiveQuests))
	
	local bFilteringFinished = self:IsFilteringAsFinished()
	for key, qcCategory in pairs(QuestLib.GetKnownCategories()) do
		local strCategoryKey = "C"..qcCategory:GetId()
		local wndCategory = self:FactoryProduce(self.wndMain:FindChild("LeftSideScroll"), "PreviousTopLevelItem", strCategoryKey)
		wndCategory:FindChild("PreviousTopLevelBtnText"):SetText(qcCategory:GetTitle())
		-- iterate through this categories "episodes"
		for key, epiEpisode in pairs(qcCategory:GetEpisodes()) do
			local nMax, nProgress = epiEpisode:GetProgress()
			-- store the status of whether or not we've completed this <?> quest (NOT SURE WHAT THIS IMPLIES YET)
			local bHasCompletedQuest = false
			for key, queQuest in pairs(epiEpisode:GetAllQuests(qcCategory:GetId())) do -- Note there's also GetVisible/GetTracked
				self:AddQuestToLog(wndCategory, queQuest)
			end			
		end
		
		if #wndCategory:FindChild("PreviousTopLevelItems"):GetChildren() == 0 then -- Todo Refactor
			wndCategory:Destroy()
		end
	end	
	self:ResizeTree()
end

function BetterQuestLog:AddQuestToLog(wndCategory, queQuest)	
	local eState = queQuest:GetState()
	
	-- only add this quest to our left tree if it matches a filter
	if (self:IsFilteringAsActive() and eState ~= Quest.QuestState_Completed and not queQuest:IsIgnored() and eState ~= Quest.QuestState_Abandoned)
	or (self:IsFilteringAsFinished() and eState == Quest.QuestState_Completed)
	or (self:IsFilteringAsHidden() and (queQuest:IsIgnored() or eState == Quest.QuestState_Abandoned)) then
		--local strQuestKey = "C"..qcCategory:GetId().."E"..epiEpisode:GetId().."Q"..queQuest:GetId() --old id format
		local strQuestKey = "Q"..queQuest:GetId()
		
		-- TODO: this would be a MUCH better way to fill our activeQuests table...
		--if self:IsFilteringAsActive() then 
			--activeQuests[strQuestKey] = queQuest 
		--end
		
		local wndTop = self:FactoryProduce(wndCategory:FindChild("PreviousTopLevelItems"), "TopLevelItem", strQuestKey)
		wndTop:FindChild("TopLevelBtn"):SetData(queQuest)
		
		-- change our title quest color
		self.problemQuest = queQuest
		local nDifficulty = queQuest:GetColoredDifficulty()
		self.ktConToUIDebug = ktConToUI
		local tConData = ktConToUI[nDifficulty]
		
		-- Not sure why it's possible for the GetColoredDifficulty() to fail but it does when players
		-- are zoning in and out of housing, it's something with a Quest update event firing for individual quests
		-- apparently before the getter functions are ready (at least for difficulty)
		if tConData ~= nil then
			wndTop:FindChild("TopLevelBtnText"):SetTextColor(tConData[2])
		end

		-- TODO: incorporate that cool progress bar somehow in the new look and feel? hmmmm sounds smexy
		--wndTop:FindChild("TopLevelProgBar"):SetMax(nMax)
		--wndTop:FindChild("TopLevelProgBar"):SetProgress(nProgress)

		-- store the bottom level icon sprite and whether or not it has a call associated with it
		local strBottomLevelIconSprite = ""
		local bHasCall = queQuest:GetContactInfo()
	
		-- set the icon based on the enum state of the quest
		local statusText = "" --fixme: localize
		if eState == Quest.QuestState_Botched then
			statusText = "(Botched)"
		elseif eState == Quest.QuestState_Abandoned or eState == Quest.QuestState_Mentioned then
			statusText = "(Abandoned)"
		elseif eState == Quest.QuestState_Achieved and bHasCall then
			bHasCompletedQuest = true
			statusText = "(Call)"
		elseif (eState == Quest.QuestState_Achieved or eState == Quest.QuestState_Completed)and not bHasCall then
			bHasCompletedQuest = true
			statusText = "(Complete)"
		end	
			
		if queQuest:IsTracked() then
			--strBottomLevelIconSprite = "CRB_Basekit:kitIcon_Holo_HazardProximity"
			strBottomLevelIconSprite = "CRB_Basekit:kitIcon_Holo_Checkmark"
		end

		-- resize the button text if it's too long. WARNING: must be the same font that's used in the XML to work
		--if Apollo.GetTextWidth("CRB_InterfaceMedium", queQuest:GetTitle()) > wndTop:FindChild("TopLevelBtnText"):GetWidth() then
		--	local nLeft, nTop, nRight, nBottom = wndTop:GetAnchorOffsets()
		--	wndTop:SetAnchorOffsets(nLeft, nTop, nRight, nTop + (self.knTopLevelHeight * 1.5)) -- our resize code that happens later will account for this
		--end
		local spacer = "..."
		local textWidth = Apollo.GetTextWidth("CRB_InterfaceMedium", queQuest:GetTitle())
		local title = queQuest:GetTitle()
		local totalText = nil
		local queLvlText = nil
		
		local wndShowLevelBtn = self.wndMain:FindChild("ShowLevelCheckboxBtn")
		
		local count = self:CountInstancesOfQuestId(queQuest:GetId())
		
		if wndShowLevelBtn:IsChecked() then
			queLvlText = "["..queQuest:GetConLevel().."]"
			
			if count > 0 then
				totalText = "(" .. count .. ") "..queLvlText .. " " .. title .. " " .. statusText
			else
				totalText = queLvlText .. " " ..  title .. " " .. statusText
			end
		else
			if count > 0 then
				totalText = "(" .. count .. ") " .. title .. " " .. statusText
			else
				totalText = title .. " " .. statusText
			end
		end
		
		--keep shortening until it fits, admittedly lazy and expensive approach to sizing
		--TODO: refactor
		while Apollo.GetTextWidth("CRB_InterfaceMedium", totalText) > wndTop:FindChild("TopLevelBtnText"):GetWidth() do
			title = string.sub(title, 0, string.len(title)-1)
			if wndShowLevelBtn:IsChecked() then
				if count > 0 then
					totalText = "(" .. count .. ") ".. queLvlText .. " " .. title .. spacer .. " " .. statusText
				else
					totalText = queLvlText .. " " .. title .. spacer .. " " .. statusText
				end
			else
				if count > 0 then
					totalText = "(" .. count .. ") " .. title .. " " .. statusText
				else
					totalText = title .. " " .. statusText
				end
			end
		end
		
		wndTop:FindChild("TopLevelBtnText"):SetText(totalText)

		-- if the quest button is checked, change it's text color to indicate that it is selected
		if wndTop:FindChild("TopLevelBtn"):IsChecked() then
			wndTop:FindChild("TopLevelBtnText"):SetTextColor(kcrSelectedColor)
		--else
			--wndTop:FindChild("TopLevelBtnText"):SetTextColor(kcrDeselectedColor)
		end

		
		
		wndTop:FindChild("TopLevelBtnIcon"):SetSprite(strBottomLevelIconSprite)
	
		-- Set the appropriate sprite icon and tooltip for middle level
		--if bFilteringFinished or bHasCompletedQuest then
		--	wndTop:FindChild("TopLevelIcon"):SetSprite("CRB_Basekit:kitIcon_Holo_Checkbox")
		--	wndTop:FindChild("TopLevelIcon"):SetTooltip(bHasCompletedQuest and Apollo.GetString("QuestLog_CanTurnIn") or "")
		--else
		--	wndTop:FindChild("TopLevelIcon"):SetSprite("CRB_Basekit:kitIcon_Holo_Exclamation")
		--	wndTop:FindChild("TopLevelIcon"):SetTooltip(Apollo.GetString("QuestLog_MoreQuestsToComplete"))
		--end
	end
end

function BetterQuestLog:ResizeTree()
	for key, wndCategory in pairs(self.wndMain:FindChild("LeftSideScroll"):GetChildren()) do
		if not wndCategory:FindChild("PreviousTopLevelBtn"):IsChecked() then
			wndCategory:FindChild("PreviousTopLevelItems"):DestroyChildren()
		end
		
		local function SortByDifficulty(a, b)
			local aData = a:FindChild("TopLevelBtn"):GetData()
			local bData = b:FindChild("TopLevelBtn"):GetData()
			--a:FindChild("TopLevelBtnText"):SetText(aData:GetColoredDifficulty() .. " < " .. bData:GetTitle())
			--b:FindChild("TopLevelBtnText"):SetText(bData:GetColoredDifficulty() .. " > " .. aData:GetTitle())
			
			if aData:GetConLevel() ~= bData:GetConLevel() then
				return bData:GetConLevel() > aData:GetConLevel()
			else
				return bData:GetTitle() > aData:GetTitle()
			end
			
			--return (b:FindChild("TopLevelBtn"):GetData():GetColoredDifficulty()) > (a:FindChild("TopLevelBtn"):GetData():GetColoredDifficulty())
		end
		--wndCategory:FindChild("PreviousTopLevelItem"):SetSprite(wndCategory:FindChild("PreviousTopLevelBtn"):IsChecked() and "kitInnerFrame_MetalGold_FrameBright2" or "kitInnerFrame_MetalGold_FrameDull")

		--local nItemHeights = wndCategory:FindChild("PreviousTopLevelItems"):ArrangeChildrenVert(0, function(a,b) return a:GetData() > b:GetData() end) -- Tasks to bottom
		local nItemHeights = wndCategory:FindChild("PreviousTopLevelItems"):ArrangeChildrenVert(0, SortByDifficulty)
		local nLeft, nTop, nRight, nBottom = wndCategory:GetAnchorOffsets()
		wndCategory:SetAnchorOffsets(nLeft, nTop, nRight, nTop + self.knTopLevelHeight + nItemHeights)

		self.wndMain:FindChild("LeftSideScroll"):ArrangeChildrenVert(0)
		self.wndMain:FindChild("LeftSideScroll"):RecalculateContentExtents()
	end
end

function BetterQuestLog:ResizeRight()
	local nWidth, nHeight, nLeft, nTop, nRight, nBottom

	-- Objectives Content
	for key, wndObj in pairs(self.wndMain:FindChild("QuestInfoObjectivesList"):GetChildren()) do
		nWidth, nHeight = wndObj:FindChild("ObjectivesItemText"):SetHeightToContentHeight()
		nHeight = wndObj:FindChild("QuestProgressItem") and nHeight + wndObj:FindChild("QuestProgressItem"):GetHeight() or nHeight
		--if wndObj:FindChild("QuestProgressItem") ~= nil then
		--	nHeight = nHeight + wndObj:FindChild("QuestProgressItem"):GetHeight()
		--end

		nLeft, nTop, nRight, nBottom = wndObj:GetAnchorOffsets()
		wndObj:SetAnchorOffsets(nLeft, nTop, nRight, nTop + math.max(self.knObjectivesItemHeight, nHeight + 8)) -- TODO: Hardcoded formatting of text pad
	end

	-- Objectives Frame
	nHeight = self.wndMain:FindChild("QuestInfoObjectivesList"):ArrangeChildrenVert(0)
	nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("QuestInfoObjectivesFrame"):GetAnchorOffsets()
	self.wndMain:FindChild("QuestInfoObjectivesFrame"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + 30)
	self.wndMain:FindChild("QuestInfoObjectivesFrame"):Show(#self.wndMain:FindChild("QuestInfoObjectivesList"):GetChildren() > 0)

	-- Rewards Recevived
	nHeight = self.wndMain:FindChild("QuestInfoRewardRecList"):ArrangeChildrenVert(0)
	nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("QuestInfoRewardRecFrame"):GetAnchorOffsets()
	self.wndMain:FindChild("QuestInfoRewardRecFrame"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + self.knRewardRecListHeight)
	self.wndMain:FindChild("QuestInfoRewardRecFrame"):Show(#self.wndMain:FindChild("QuestInfoRewardRecList"):GetChildren() > 0)

	-- Rewards to Choose
	nHeight = self.wndMain:FindChild("QuestInfoRewardChoList"):ArrangeChildrenVert(0, function(a,b) return b:FindChild("RewardItemCantUse"):IsShown() end)
	nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("QuestInfoRewardChoFrame"):GetAnchorOffsets()
	self.wndMain:FindChild("QuestInfoRewardChoFrame"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + self.knRewardChoListHeight)
	self.wndMain:FindChild("QuestInfoRewardChoFrame"):Show(#self.wndMain:FindChild("QuestInfoRewardChoList"):GetChildren() > 0)

	-- More Info
	nHeight = 0
	--if self.wndMain:FindChild("QuestInfoMoreInfoToggleBtn"):IsChecked() then
		nWidth, nHeight = self.wndMain:FindChild("QuestInfoMoreInfoText"):SetHeightToContentHeight()
		--nHeight = nHeight + 32 --unneeded padding and should add padding as part of the GUI layout instead anyways IMO
--	end
	--nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("QuestInfoMoreInfoFrame"):GetAnchorOffsets()
	nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("QuestInfoMoreInfoText"):GetAnchorOffsets()

	--self.wndMain:FindChild("QuestInfoMoreInfoFrame"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + self.knMoreInfoHeight)
	self.wndMain:FindChild("QuestInfoMoreInfoText"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + self.knMoreInfoHeight)


	-- Episode Summary
	nHeight = 0
	--if self.wndMain:FindChild("EpisodeSummaryExpandBtn"):IsChecked() then
		nWidth, nHeight = self.wndMain:FindChild("EpisodeSummaryPopoutText"):SetHeightToContentHeight()
	--end
	nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("EpisodeInfo"):GetAnchorOffsets()
	if self.wndMain:FindChild("EpisodeInfo"):IsShown() then
		self.wndMain:FindChild("EpisodeInfo"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + self.knEpisodeInfoHeight)
	else
		self.wndMain:FindChild("EpisodeInfo"):SetAnchorOffsets(nLeft, nTop, nRight, nTop)
	end

	-- Resize
	local nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("QuestInfo"):GetAnchorOffsets()
	self.wndMain:FindChild("QuestInfo"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + self.wndMain:FindChild("QuestInfo"):ArrangeChildrenVert(0))

	if self.wndMain:FindChild("RightSide"):GetData() == nil then
		self.wndMain:FindChild("QuestInfoControls"):Show(false)
	else
		self.wndMain:FindChild("QuestInfoControls"):Show(true)
	end
	
	self.wndMain:FindChild("RightSide"):ArrangeChildrenVert(0)
	self.wndMain:FindChild("RightSide"):RecalculateContentExtents()
end

-----------------------------------------------------------------------------------------------
-- Draw Quest Info
-----------------------------------------------------------------------------------------------

function BetterQuestLog:HelperEpisodeSummaryText(strArgument, bShowCaps) -- TODO: Replace this entire thing with a real SmallCaps Font
	local function HelperFakeSmallCapsTrue(strFirstLetter, strRest)
		strFirstLetter = strFirstLetter:upper()
		strRest = string.len(strRest) == 0 and "<T TextColor=\"0\">.</T>" or strRest:upper()
		return string.format("<T Font=\"CRB_InterfaceLarge_B\" TextColor=\"0\">%s</T><T Font=\"CRB_InterfaceMedium_B\">%s </T>", strFirstLetter, strRest)
	end
	local function HelperFakeSmallCapsFalse(strFirstLetter, strRest)
		strFirstLetter = strFirstLetter:upper()
		strRest = string.len(strRest) == 0 and "<T TextColor=\"0\">.</T>" or strRest:upper()
		return string.format("<T Font=\"CRB_InterfaceLarge_B\">%s</T><T Font=\"CRB_InterfaceMedium_B\" TextColor=\"0\">%s </T>", strFirstLetter, strRest)
	end
	return strArgument:gsub("(%p*%a)([%p*%w\-_.'!]*)", bShowCaps and HelperFakeSmallCapsTrue or HelperFakeSmallCapsFalse)
end

function BetterQuestLog:DrawRightSide(queSelected)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local wndRight = self.wndMain:FindChild("RightSide")
	
	--self.wndMain:FindChild("QuestInfoControls"):Show(true)
	
	local eQuestState = queSelected:GetState()

	-- Text Summary
	local strQuestSummary = ""
	if eQuestState == Quest.QuestState_Completed and string.len(queSelected:GetCompletedSummary()) > 0 then
		strQuestSummary = queSelected:GetCompletedSummary()
	elseif string.len(queSelected:GetSummary()) > 0 then
		strQuestSummary = queSelected:GetSummary()
	end

	local nDifficulty = queSelected:GetColoredDifficulty() or 0
	if eQuestState == Quest.QuestState_Completed then
		--wndRight:FindChild("QuestInfoTitleIcon"):SetTooltip(Apollo.GetString("QuestLog_HasBeenCompleted"))
		--wndRight:FindChild("QuestInfoTitleIcon"):SetSprite("CRB_Basekit:kitIcon_Green_Checkmark")
		wndRight:FindChild("QuestInfoTitle"):SetText(String_GetWeaselString(Apollo.GetString("QuestLog_Completed"), queSelected:GetTitle()))
		wndRight:FindChild("QuestInfoTitle"):SetTextColor(ApolloColor.new("ff7fffb9"))
	else
		local tConData = ktConToUI[nDifficulty]
		if tConData then
			local strDifficulty = "<T Font=\"CRB_InterfaceMedium\" TextColor=\"" .. tConData[2] .. "\"> " .. tConData[3] .. "</T>"
			wndRight:FindChild("QuestInfoTitle"):SetText(queSelected:GetTitle())
		end
	end
	
	local tConData = ktConToUI[nDifficulty]
	if tConData then
		local strDifficulty = "<T Font=\"CRB_InterfaceMedium\" TextColor=\"" .. tConData[2] .. "\"> " .. tConData[3] .. "</T>"
		wndRight:FindChild("QuestInfoTitle"):SetText(queSelected:GetTitle())
		wndRight:FindChild("QuestInfoTitle"):SetTextColor(ApolloColor.new("white"))
	end
	
	wndRight:FindChild("QuestInfoDescriptionText"):SetAML("<P Font=\"CRB_InterfaceMedium\" TextColor=\"ff2f94ac\">"..strQuestSummary.."</P>")
	wndRight:FindChild("QuestInfoDescriptionText"):SetHeightToContentHeight()

	-- Episode Summary
	local epiParent = queSelected:GetEpisode()	
	
	-- it's possible that we can't get the episode if our player doesn't have the episode
	if epiParent ~= nil then
		local bIsTasks = epiParent:GetId() == 1
		local tEpisodeProgress = epiParent:GetProgress()
		local strEpisodeDesc = ""
		if not bIsTasks then
			if epiParent:GetState() == Episode.EpisodeState_Complete then
				strEpisodeDesc = epiParent:GetSummary()
			else
				strEpisodeDesc = epiParent:GetDesc()
			end
		end
		
		wndRight:FindChild("EpisodeSummaryTitle"):SetText(self:HelperEpisodeSummaryText(epiParent:GetTitle(), false))
		wndRight:FindChild("EpisodeSummaryTitle2"):SetText(self:HelperEpisodeSummaryText(epiParent:GetTitle(), true))
		wndRight:FindChild("EpisodeSummaryProgText"):SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ff31fcf6\" Align=\"Center\">"..
		"(<T Font=\"CRB_InterfaceSmall\" TextColor=\"ffffb62e\" Align=\"Center\">%s</T>/%s)</P>", tEpisodeProgress.nCompleted, tEpisodeProgress.nTotal))
		wndRight:FindChild("EpisodeSummaryPopoutText"):SetAML("<P Font=\"CRB_InterfaceMedium\" TextColor=\"ff2f94ac\">"..strEpisodeDesc.."</P>")
	else
		wndRight:FindChild("EpisodeSummaryTitle"):SetText("")
		wndRight:FindChild("EpisodeSummaryTitle2"):SetText("Someone Else's Episode")
		wndRight:FindChild("EpisodeSummaryProgText"):SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ff31fcf6\" Align=\"Center\">"..
		"(<T Font=\"CRB_InterfaceSmall\" TextColor=\"ffffb62e\" Align=\"Center\">%s</T>/%s)</P>", 0, 0))
		wndRight:FindChild("EpisodeSummaryPopoutText"):SetAML("<P Font=\"CRB_InterfaceMedium\" TextColor=\"ff2f94ac\">Could not get episode information due to this being a linked quest. If this quest was not linked, please let OctanePenguin know how you got to this point.</P>")
	end
		
	-- More Info
	local strMoreInfo = ""
	local tMoreInfoText = queSelected:GetMoreInfoText()
	
	-- this automatically opens our more info button if it exists
	--if #tMoreInfoText > 0 and not self.wndMain:FindChild("QuestInfoMoreInfoToggleBtn"):IsChecked() then
	--	self.wndMain:FindChild("QuestInfoMoreInfoToggleBtn"):SetCheck(true)
	--	self.wndMain:FindChild("QuestInfoMoreInfoToggleBtnText"):SetText(Apollo.GetString("QuestLog_ClosePlaybackLog"))
	--end
		
	if #tMoreInfoText > 0 then --and self.wndMain:FindChild("QuestInfoMoreInfoToggleBtn"):IsChecked() then
		wndRight:FindChild("QuestInfoMoreInfoText"):Show(true)
		for idx, tValues in pairs(tMoreInfoText) do
			if string.len(tValues.strSay) > 0 or string.len(tValues.strResponse) > 0 then
				strMoreInfo = strMoreInfo .. "<P Font=\"CRB_InterfaceMedium\" TextColor=\"ff2f94ac\">"..tValues.strSay.."</P>"
				strMoreInfo = strMoreInfo .. "<P Font=\"CRB_InterfaceMedium\" TextColor=\"ffffffff\">"..tValues.strResponse.."</P>"
				if idx ~= #tMoreInfoText then
					--strMoreInfo = strMoreInfo .. "<P TextColor=\"0\">.</P>"
				end
			end
		end
	else
		--wndRight:FindChild("QuestInfoMoreInfoToggleBtn"):SetCheck(false)
		--wndRight:FindChild("QuestInfoMoreInfoToggleBtnText"):SetText(Apollo.GetString("QuestLog_OpenPlaybackLog"))
		wndRight:FindChild("QuestInfoMoreInfoText"):Show(false)
	end
	wndRight:FindChild("QuestInfoMoreInfoText"):SetAML(strMoreInfo)
	wndRight:FindChild("QuestInfoMoreInfoText"):SetHeightToContentHeight()
	--wndRight:FindChild("QuestInfoMoreInfoFrame"):Show(#tMoreInfoText > 0)

	-- Objectives
	wndRight:FindChild("QuestInfoObjectivesList"):DestroyChildren()
	if eQuestState == Quest.QuestState_Achieved then
		local wndObj = Apollo.LoadForm(self.xmlDoc, "ObjectivesItem", wndRight:FindChild("QuestInfoObjectivesList"), self)
		local strAchieved = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"ffffffff\">%s</T>", queSelected:GetCompletionObjectiveText())
		wndObj:FindChild("ObjectivesItemText"):SetAML(strAchieved)
		wndRight:FindChild("QuestInfoObjectivesTitle"):SetText(Apollo.GetString("QuestLog_ReadyToTurnIn"))
	elseif eQuestState == Quest.QuestState_Completed then
		for key, tObjData in pairs(queSelected:GetVisibleObjectiveData()) do
			if tObjData.nCompleted < tObjData.nNeeded then
				local wndObj = Apollo.LoadForm(self.xmlDoc, "ObjectivesItem", wndRight:FindChild("QuestInfoObjectivesList"), self)
				wndObj:FindChild("ObjectivesItemText"):SetAML(self:HelperBuildObjectiveTitleString(queSelected, tObjData))
				self:HelperBuildObjectiveProgBar(queSelected, tObjData, wndObj, true)
				wndObj:FindChild("ObjectiveBullet"):SetSprite("CRB_Basekit:kitIcon_Holo_Checkmark")
				wndObj:FindChild("ObjectiveBullet"):SetBGColor("ffffff00")
			end
		end
		wndRight:FindChild("QuestInfoObjectivesTitle"):SetText(Apollo.GetString("QuestLog_CompletedObjectives"))
	elseif eQuestState ~= Quest.QuestState_Mentioned then
		for key, tObjData in pairs(queSelected:GetVisibleObjectiveData()) do
			if tObjData.nCompleted < tObjData.nNeeded then
				local wndObj = Apollo.LoadForm(self.xmlDoc, "ObjectivesItem", wndRight:FindChild("QuestInfoObjectivesList"), self)
				wndObj:FindChild("ObjectivesItemText"):SetAML(self:HelperBuildObjectiveTitleString(queSelected, tObjData))
				self:HelperBuildObjectiveProgBar(queSelected, tObjData, wndObj)
			end
		end
		wndRight:FindChild("QuestInfoObjectivesTitle"):SetText(Apollo.GetString("QuestLog_Objectives"))
	end

	-- Rewards Received
	local tRewardInfo = queSelected:GetRewardData()
	wndRight:FindChild("QuestInfoRewardRecList"):DestroyChildren()
	for key, tReward in pairs(tRewardInfo.arFixedRewards) do
		local wndReward = Apollo.LoadForm(self.xmlDoc, "RewardItem", wndRight:FindChild("QuestInfoRewardRecList"), self)
		self:HelperBuildRewardsRec(wndReward, tReward, true)
	end

	-- Rewards To Choose
	wndRight:FindChild("QuestInfoRewardChoList"):DestroyChildren()
	for key, tReward in pairs(tRewardInfo.arRewardChoices) do
		local wndReward = Apollo.LoadForm(self.xmlDoc, "RewardItem", wndRight:FindChild("QuestInfoRewardChoList"), self)
		self:HelperBuildRewardsRec(wndReward, tReward, false)
	end

	-- Special reward formatting for finished quests
	if eQuestState == Quest.QuestState_Completed then

		wndRight:FindChild("QuestInfoRewardRecTitle"):SetText(Apollo.GetString("QuestLog_YouReceived"))
		wndRight:FindChild("QuestInfoRewardChoTitle"):SetText(Apollo.GetString("QuestLog_YouChoseFrom"))
	else
		wndRight:FindChild("QuestInfoRewardRecTitle"):SetText(Apollo.GetString("QuestLog_WillReceive"))
		wndRight:FindChild("QuestInfoRewardChoTitle"):SetText(Apollo.GetString("QuestLog_CanChooseOne"))
	end

	-- Call Button
	if queSelected:GetContactInfo() and ktValidCallButtonStats[eQuestState] then
		local tContactInfo = queSelected:GetContactInfo()

		wndRight:FindChild("QuestInfoCallFrame"):Show(true)
		wndRight:FindChild("QuestInfoCostumeWindow"):SetCostumeToCreatureId(tContactInfo.idUnit)
		wndRight:FindChild("QuestInfoCallFrameText"):SetAML("<P Font=\"CRB_HeaderLarge\" TextColor=\"ff7fffb9\">" .. Apollo.GetString("QuestLog_ContactNPC") .. "</P><P Font=\"CRB_HeaderLarge\">" .. tContactInfo.strName .. "</P>")
	else
		wndRight:FindChild("QuestInfoCallFrame"):Show(false)
	end

	-- Bottom Buttons (outside of Scroll)
	--self.wndMain:FindChild("QuestInfoControlsHideBtn"):Show(eQuestState == Quest.QuestState_Abandoned or eQuestState == Quest.QuestState_Mentioned)
	self.wndMain:FindChild("QuestInfoControlButtons"):Show(eQuestState == Quest.QuestState_Accepted or eQuestState == Quest.QuestState_Achieved or eQuestState == Quest.QuestState_Botched)
	if eQuestState ~= Quest.QuestState_Abandoned then
		local bCanShare = queSelected:CanShare()
		local bIsTracked = queSelected:IsTracked()
		self.wndMain:FindChild("QuestAbandonPopoutBtn"):Enable(queSelected:CanAbandon())
		self.wndMain:FindChild("QuestInfoControlsBGShare"):Show(bCanShare)
		self.wndMain:FindChild("QuestInfoControlsBGShare"):SetTooltip(bCanShare and Apollo.GetString("QuestLog_ShareQuest") or String_GetWeaselString(Apollo.GetString("QuestLog_ShareNotPossible"), Apollo.GetString("QuestLog_ShareQuest")))
		self.wndMain:FindChild("QuestTrackBtn"):Enable(eQuestState ~= Quest.QuestState_Botched)
		self.wndMain:FindChild("QuestTrackBtn"):SetText(bIsTracked and Apollo.GetString("QuestLog_Untrack") or Apollo.GetString("QuestLog_Track"))
		self.wndMain:FindChild("QuestTrackBtn"):SetTooltip(bIsTracked and Apollo.GetString("QuestLog_RemoveFromTracker") or Apollo.GetString("QuestLog_AddToTracker"))
	end
	self.wndMain:FindChild("QuestInfoControlButtons"):ArrangeChildrenHorz(1)

	-- Hide Pop Out CloseOnExternalClick windows
	self.wndMain:FindChild("QuestAbandonConfirm"):Show(false)
end

function BetterQuestLog:OnTopLevelBtnCheck(wndHandler, wndControl)
	self:RedrawLeftTree()
end

function BetterQuestLog:OnMiddleLevelBtnCheck(wndHandler, wndControl)
	wndHandler:SetCheck(true)
	self:RedrawLeftTree()

	local wndBot = wndHandler:GetParent():FindChild("MiddleLevelItems"):GetChildren()[1] -- TODO hack
	if wndBot then
		wndBot:FindChild("BottomLevelBtn"):SetCheck(true)
		self:OnBottomLevelBtnCheck(wndBot:FindChild("BottomLevelBtn"), wndBot:FindChild("BottomLevelBtn"))
	end
end

-- converted to use top button
function BetterQuestLog:OnBottomLevelBtnCheck(wndHandler, wndControl) -- From Button or OnQuestObjectiveUpdated	
	wndHandler:SetCheck(true)
	local queQuest = wndHandler:GetData()
	local nDifficulty = queQuest:GetColoredDifficulty()
	local tConData = ktConToUINoAlpha[nDifficulty]
	
	-- Text Coloring
	if self.wndLastBottomLevelBtnSelection and self.wndLastBottomLevelBtnSelection:IsValid() then
		self.wndLastBottomLevelBtnSelection:FindChild("TopLevelBtnText"):SetTextColor("FF"..tConData[2])
	end
	
	--wndHandler:FindChild("TopLevelBtn"):SetBGColor(tConData[2])
	--wndHandler:FindChild("TopLevelBtn"):SetSprite("ActionSetBuilder_TEMP:spr_TEMP_ActionSetBarFrame_Stretch")]
	local myBg = wndHandler:GetParent():FindChild("BottomLevelQuestLinkBtn"):FindChild("ProgressBarBG")
	myBg:SetBGColor(ApolloColor.new("80"..tConData[2]))
	myBg:Show(true)
	wndHandler:FindChild("TopLevelBtnText"):SetTextColor(kcrSelectedColor)
	self.wndLastBottomLevelBtnSelection = wndHandler

	self.wndMain:FindChild("RightSide"):Show(true)
	self.wndMain:FindChild("RightSide"):SetVScrollPos(0)
	self.wndMain:FindChild("RightSide"):RecalculateContentExtents()
	self.wndMain:FindChild("RightSide"):SetData(wndHandler:GetData())
	self:RedrawEverything()
end

--function BetterQuestLog:OnBottomLevelBtnUncheck(wndHandler, wndControl)
--	wndHandler:FindChild("TopLevelBtn"):SetCheck(false)
    --local queQuest = wndHandler:FindChild("TopLevelBtn"):GetData()
	--local nDifficulty = queQuest:GetColoredDifficulty()
	--local tConData = ktConToUI[nDifficulty]
	--wndHandler:FindChild("TopLevelBtnText"):SetTextColor(tConData[2])
	
	-- Track this if the user was holding shift
	--if Apollo.IsShiftKeyDown() then
	--	BetterQuestLog:OnQuestTrackProgrammatically(wndHandler, wndControl)
	---end
	
	
	
	--self.wndMain:FindChild("QuestInfoControls"):Show(false)
	--self.wndMain:FindChild("RightSide"):Show(false)
	--self:RedrawEverything() -- Not Needed
--end

--function BetterQuestLog:OnBottomLevelBtnDown( wndHandler, wndControl, eMouseButton )
--	if eMouseButton == 1 and Apollo.IsShiftKeyDown() then
--		Event_FireGenericEvent("GenericEvent_QuestLink", wndControl:GetParent():FindChild("BottomLevelBtn"):GetData())
--	end
--end

-----------------------------------------------------------------------------------------------
-- Bottom Buttons and Quest Update Events
-----------------------------------------------------------------------------------------------

function BetterQuestLog:OnQuestTrackBtn(wndHandler, wndControl) -- QuestTrackBtn
	local queSelected = self.wndMain:FindChild("RightSide"):GetData()	
	local bNewTrackValue = not queSelected:IsTracked()
	queSelected:SetTracked(bNewTrackValue)
	self.wndMain:FindChild("QuestTrackBtn"):SetText(bNewTrackValue and Apollo.GetString("QuestLog_Untrack") or Apollo.GetString("QuestLog_Track")) 
	self.wndMain:FindChild("QuestTrackBtn"):SetTooltip(bNewTrackValue and Apollo.GetString("QuestLog_RemoveFromTracker") or Apollo.GetString("QuestLog_AddToTracker"))
	Event_FireGenericEvent("GenericEvent_QuestLog_TrackBtnClicked", queSelected)
	self:RedrawEverything() --lazy, I just want checkmarks to be redrawn, potentially could be optimized/removed instead of redrawing everything
end

function BetterQuestLog:OnQuestShareBtn(wndHandler, wndControl) -- QuestShareBtn
	local queSelected = self.wndMain:FindChild("RightSide"):GetData()
	queSelected:Share()
end

function BetterQuestLog:OnQuestCallBtn(wndHandler, wndControl) -- QuestCallBtn or QuestInfoCostumeWindow
	local queSelected = self.wndMain:FindChild("RightSide"):GetData()
	CommunicatorLib.CallContact(queSelected)
	Event_FireGenericEvent("ToggleCodex") -- Hide codex, not sure if we want this
end

function BetterQuestLog:OnQuestAbandonBtn(wndHandler, wndControl) -- QuestAbandonBtn
	local queSelected = self.wndMain:FindChild("RightSide"):GetData()
	queSelected:Abandon()
	self:OnDestroyQuestObject(queUpdated)
	--self:DestroyAndRedraw()
	self.wndMain:FindChild("RightSide"):Show(false)
	self.wndMain:FindChild("QuestInfoControls"):Show(false)
end

-- this button no longer exists in better quest log
function BetterQuestLog:OnQuestHideBtn(wndHandler, wndControl) -- QuestInfoControlsHideBtn
	local queSelected = self.wndMain:FindChild("RightSide"):GetData()
	queSelected:ToggleIgnored()
	self:OnDestroyQuestObject(queSelected)
	--self:DestroyAndRedraw()
	self.wndMain:FindChild("RightSide"):Show(false)
	self.wndMain:FindChild("QuestInfoControls"):Show(false)
	Apollo.CreateTimer("RedrawQuestLogInOneSec", 1, false) -- TODO TEMP HACK, since Quest:ToggleIgnored() takes a while
end

function BetterQuestLog:OnQuestAbandonPopoutClose(wndHandler, wndControl) -- QuestAbandonPopoutClose
	self.wndMain:FindChild("QuestAbandonConfirm"):Show(false)
end

function BetterQuestLog:OnQuestInfoMoreInfoToggleBtn(wndHandler, wndControl) -- QuestInfoMoreInfoToggleBtn
	if wndHandler:IsChecked() then
		wndHandler:FindChild("QuestInfoMoreInfoToggleBtnText"):SetText(Apollo.GetString("QuestLog_ClosePlaybackLog"))
	else
		wndHandler:FindChild("QuestInfoMoreInfoToggleBtnText"):SetText(Apollo.GetString("QuestLog_OpenPlaybackLog"))
	end
	self:RedrawEverything()
end

function BetterQuestLog:OnQuestInfoMoreInfoMouseEnter(wndHandler, wndControl) -- QuestInfoMoreInfoToggleBtnText
	wndHandler:SetTextColor(kcrHoloColorBright)
end

function BetterQuestLog:OnQuestInfoMoreInfoMouseExit(wndHandler, wndControl) -- QuestInfoMoreInfoToggleBtnText
	wndHandler:SetTextColor(kcrHoloColorDim)
end

-----------------------------------------------------------------------------------------------
-- State Updates
-----------------------------------------------------------------------------------------------

function BetterQuestLog:OnQuestStateChanged(queUpdated, eState)
	if type(eState) == "boolean" then
		-- CODE ERROR! This is Quest Track Changed.
		return
	end

	local queCurrent = self.wndMain:FindChild("RightSide"):GetData()
	
	if eState == Quest.QuestState_Abandoned or eState == Quest.QuestState_Completed then
		self:OnDestroyQuestObject(queUpdated)
		self:RedrawEverything() --added this so when it's abandoned it will redraw properly
		if queCurrent and queCurrent:GetId() == queUpdated:GetId() then
			self.wndMain:FindChild("RightSide"):Show(false)
			self.wndMain:FindChild("QuestInfoControls"):Show(false)
		end
	elseif eState == Quest.QuestState_Accepted or eState == Quest.QuestState_Achieved then
		self:OnDestroyQuestObject(queUpdated)
		--self:DestroyAndRedraw()
		self:RedrawEverything()
	else -- Botched, Mentioned, Ignored, Unknown
		self:RedrawEverything()
		if queCurrent and queCurrent:GetId() == queUpdated:GetId() then
			self.wndMain:FindChild("RightSide"):Show(false)
			self.wndMain:FindChild("QuestInfoControls"):Show(false)
		end
	end
	
	self:UpdateActiveQuestTable(queUpdated)
	
	-- only broadcast updates if we're in a group
	if self.isDebugMode then
		self:BroadcastUpdate(queUpdated)
	elseif GroupLib.InGroup() or GroupLib.InRaid() then
		self:BroadcastUpdate(queUpdated)
	end
end

function BetterQuestLog:BroadcastActiveQuests()
	if self.activeQuests == nil then
		self:CreateActiveQuestsTable()
	end
	
	if self.bqlChannel == nil then
		self:JoinBQLChannel() -- give it another shot...
		if self.bqlChannel == nil then
			-- our best wasn't good enough, bail since we can't find a channel (leader)
			return
		end
	end
	
	for key, quest in pairs(self.activeQuests) do
		self:BroadcastUpdate(quest)
	end
end

-- broadcasts to anyone listening for BQL that i have had a quest update
function BetterQuestLog:BroadcastUpdate(queUpdated)

	-- can't broadcast jack if we don't have a channel to broadcast to
	if self.bqlChannel == nil then
		return
	end

	local msg = {}
	msg.strPlayerName = GameLib.GetPlayerUnit():GetName() -- that's me
	msg.strEventName = "QuestUpdated" -- had a quest update
	msg.strQuestId = queUpdated:GetId() -- with the quest id of this
	msg.eQuestState = queUpdated:GetState() -- and here's my new state
	
	self.bqlChannel:SendMessage(msg) -- send it out!
	
	if self.isDebugMode then
		if self.sentCount == nil then
			self.sentCount = 0
		end
	
		if self.bqlSent == nil then
			self.bqlSent = {}
		end
	
		self.bqlSent[self.sentCount] = msg
		self.bqlSent[self.sentCount].questName = queUpdated:GetTitle()
		self.sentCount = self.sentCount + 1
	
		if self.isSoloMode then
			self:OnBQLMessage(nil, msg)
		end
	end
end

function BetterQuestLog:OnGroupLeft(reason) -- I left a group
	log:debug("OnGroupLeft called")
	self:OnPartyChange()
	self:RedrawEverything()
end

function BetterQuestLog:OnGroupRemove(name, reason) --a member in my group was removed
	log:debug("OnGroupRemove called")
	self:OnPartyChange()
	self:RedrawEverything()
end

-- Requests a broadcast of each group member's active quest log to populate our groupMembers table through OnBQLMessage
function BetterQuestLog:RequestGroupBroadcast()
	--FIXME: i'm able to call this in-game before it's initialized and it works, but it doesn't just work on it's own??? wtf
	log:debug("RequestGroupBroadcast")
	if self.bqlChannel == nil then
		log:debug("Was going to request broadcast but bqlChannel was nil, this is due to not finding a leader for the group")
		return
	end
	
	local nMembers = GroupLib.GetMemberCount()
	local myName = GameLib.GetPlayerUnit():GetName()
	
	if nMembers > 0 then
		local msg = {}
		msg.strEventName = "RequestBroadcast"
		for i=1,nMembers do
			msg.strPlayerName = GroupLib.GetGroupMember(i).strCharacterName
			--msg.strPlayerName = myName
			if msg.strPlayerName ~= myName then -- don't request a broadcast from myself
				local result = self.bqlChannel:SendMessage(msg)
				-- workaround for not being able to tell when i'm ready to send a message
				if result == false then
					log:debug("ReRequesting Broadcast")
					Apollo.CreateTimer("ReRequestBroadcast", 1, false)
					Apollo.StartTimer("ReRequestBroadcast")
					break
				end
				
				if self.sentCount == nil then
					self.sentCount = 0
				end
				
				if self.bqlSent == nil then
					self.bqlSent = {}
				end
				
				self.bqlSent[self.sentCount] = msg
				self.sentCount = self.sentCount + 1
				--self:OnBQLMessage(nil, msg)
			end			
		end
	end
end

function BetterQuestLog:OnGroupJoin()	
	log:debug("OnGroupJoin called")
	self:OnPartyChange()
	Apollo.CreateTimer("OnLoadFinishedTimer", 3, false)
	Apollo.StartTimer("OnLoadFinishedTimer")
	--self:BroadcastActiveQuests() -- I joined a group, broadcast my active quests
	--self:RequestGroupBroadcast() -- Request an update from the members of my group
end

function BetterQuestLog:OnQuestObjectiveUpdated(queUpdated)
	local queCurrent = self.wndMain:FindChild("RightSide"):GetData()
	
	-- only broadcast updates if we're in a group
	if GroupLib.InGroup() or GroupLib.InRaid() then
		self:BroadcastUpdate(queUpdated)
	end
	
	if queCurrent and queCurrent:GetId() == queUpdated:GetId() then
		if queCurrent:GetState() == Quest.QuestState_Achieved then
			self:OnDestroyQuestObject(queUpdated)
		end
		self:RedrawEverything() --redraw if we're looking at the quest that just updated
	elseif queCurrent and queCurrent:GetState() == Quest.QuestState_Achieved then
		self:OnDestroyQuestObject(queUpdated)
		self:RedrawEverything()
	end
end

-- Abandons the quest provided in the parameter by quest id "Q..target:GetId()" and then destroys the object housing it and redraws everything
function BetterQuestLog:OnDestroyQuestObject(queTarget) -- QuestStateChanged, QuestObjectiveUpdated
	if self.wndMain and self.wndMain:IsValid() and queTarget then
		local wndBot = self.wndMain:FindChild("LeftSideScroll"):FindChildByUserData("Q"..queTarget:GetId())
		if wndBot then
			wndBot:Destroy()
			self:RedrawEverything()
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Quest Sharing
-----------------------------------------------------------------------------------------------

function BetterQuestLog:OnDialog_QuestShare(queToShare, unitTarget)
	if self.wndShare == nil then
		self.wndShare = Apollo.LoadForm(self.xmlDoc, "ShareQuestNotice", nil, self)
	end
	self.wndShare:ToFront()
	self.wndShare:Show(true)
	self.wndShare:SetData(queToShare)
	self.wndShare:FindChild("NoticeText"):SetText(unitTarget:GetName() .. Apollo.GetString("CRB__wants_to_share_quest_") .. queToShare:GetTitle() .. Apollo.GetString("CRB__with_you"))

	Apollo.CreateTimer("ShareTimeout", Quest.kQuestShareAcceptTimeoutMs / 1000.0, false)
	Apollo.StartTimer("ShareTimeout")
end

function BetterQuestLog:OnShareCancel(wndHandler, wndControl)
	local queToShare = self.wndShare:GetData()
	if queToShare then
		queToShare:RejectShare()
	end
	if self.wndShare then
		self.wndShare:Destroy()
		self.wndShare = nil
	end
	Apollo.StopTimer("ShareTimeout")
end

function BetterQuestLog:OnShareAccept(wndHandler, wndControl)
	local queToShare = self.wndShare:GetData()
	if queToShare then
		queToShare:AcceptShare()
	end
	if self.wndShare then
		self.wndShare:Destroy()
		self.wndShare = nil
	end
	Apollo.StopTimer("ShareTimeout")
end

function BetterQuestLog:OnShareTimeout()
	self:OnShareCancel()
end

-----------------------------------------------------------------------------------------------
-- Reward Building Helpers
-----------------------------------------------------------------------------------------------

function BetterQuestLog:HelperBuildRewardsRec(wndReward, tRewardData, bReceived)
	local strText = ""
	local strSprite = ""

	if tRewardData.eType == Quest.Quest2RewardType_Item then
		strText = tRewardData.itemReward:GetName()
		strSprite = tRewardData.itemReward:GetIcon()
		self:HelperBuildItemTooltip(wndReward, tRewardData.itemReward)
		wndReward:FindChild("RewardItemCantUse"):Show(self:HelperPrereqFailed(tRewardData.itemReward))
		wndReward:FindChild("RewardItemText"):SetTextColor(karEvalColors[tRewardData.itemReward:GetItemQuality()])
		wndReward:FindChild("RewardIcon"):SetText(tRewardData.nAmount > 1 and tRewardData.nAmount or "")
	elseif tRewardData.eType == Quest.Quest2RewardType_Reputation then
		strText = String_GetWeaselString(Apollo.GetString("Dialog_FactionRepReward"), tRewardData.nAmount, tRewardData.strFactionName)
		strSprite = "Icon_ItemMisc_UI_Item_Parchment"
		wndReward:SetTooltip(strText)
	elseif tRewardData.eType == Quest.Quest2RewardType_TradeSkillXp then
		strText = String_GetWeaselString(Apollo.GetString("Dialog_TradeskillXPReward"), tRewardData.nXP, tRewardData.strTradeskill)
		strSprite = "Icon_ItemMisc_tool_0001"
		wndReward:SetTooltip(strText)
	elseif tRewardData.eType == Quest.Quest2RewardType_Money then
		if tRewardData.eCurrencyType == Money.CodeEnumCurrencyType.Credits then
			local nInCopper = tRewardData.nAmount
			if nInCopper >= 1000000 then
				strText = String_GetWeaselString(Apollo.GetString("CRB_Platinum"), math.floor(nInCopper / 1000000))
			end
			if nInCopper >= 10000 then
				strText = String_GetWeaselString(Apollo.GetString("CRB_Gold"), math.floor(nInCopper % 1000000 / 10000))
			end
			if nInCopper >= 100 then
				strText = String_GetWeaselString(Apollo.GetString("CRB_Silver"), math.floor(nInCopper % 10000 / 100))
			end
			strText = strText .. " " .. String_GetWeaselString(Apollo.GetString("CRB_Copper"), math.floor(nInCopper % 100))
			strSprite = "ClientSprites:Icon_ItemMisc_bag_0001"
			wndReward:SetTooltip(strText)
		else
			local tDenomInfo = GameLib.GetPlayerCurrency(tRewardData.eCurrencyType):GetDenomInfo()
			if tDenomInfo ~= nil then
				strText = tRewardData.nAmount .. " " .. tDenomInfo[1].strName
				strSprite = "ClientSprites:Icon_ItemMisc_bag_0001"
				wndReward:SetTooltip(strText)
			end
		end
	end

	wndReward:FindChild("RewardIcon"):SetSprite(strSprite)
	wndReward:FindChild("RewardItemText"):SetText(strText)
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function BetterQuestLog:HelperBuildObjectiveTitleString(queQuest, tObjective, bIsTooltip)
	local strResult = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"ffffffff\">%s</T>", tObjective.strDescription)

	-- Prefix Optional or Progress if it hasn't been finished yet
	if tObjective.nCompleted < tObjective.nNeeded then
		if tObjective and not tObjective.bIsRequired then
			strResult = string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"ffffffff\">%s</T>%s", Apollo.GetString("QuestLog_Optional"), strResult)
		end

		if tObjective.nNeeded > 1 and queQuest:DisplayObjectiveProgressBar(tObjective.nIndex) then
			local nCompleted = queQuest:GetState() == Quest.QuestState_Completed and tObjective.nNeeded or tObjective.nCompleted
			local nPercentText = String_GetWeaselString(Apollo.GetString("CRB_Percent"), math.floor(nCompleted / tObjective.nNeeded * 100))
			strResult = string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"ffffffff\">%s </T>%s", nPercentText, strResult)
		elseif tObjective.nNeeded > 1 then
			local nCompleted = queQuest:GetState() == Quest.QuestState_Completed and tObjective.nNeeded or tObjective.nCompleted
			local nPercentText = String_GetWeaselString(Apollo.GetString("QuestTracker_ValueComplete"), nCompleted, tObjective.nNeeded)
			strResult = string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"ffffffff\">%s </T>%s", nPercentText, strResult)
		end
	end

	return strResult
end


function BetterQuestLog:HelperBuildObjectiveProgBar(queQuest, tObjective, wndObjective, bComplete)
	if tObjective.nNeeded > 1 and queQuest:DisplayObjectiveProgressBar(tObjective.index) then
		local wndObjectiveProg = self:FactoryProduce(wndObjective, "QuestProgressItem", "QuestProgressItem")
		local nCompleted = bComplete and tObjective.nNeeded or tObjective.nCompleted
		local nNeeded = tObjective.nNeeded
		wndObjectiveProg:FindChild("QuestProgressBar"):SetMax(nNeeded)
		wndObjectiveProg:FindChild("QuestProgressBar"):SetProgress(nCompleted)
		wndObjectiveProg:FindChild("QuestProgressBar"):EnableGlow(nCompleted > 0 and nCompleted ~= nNeeded)
	end
end

function BetterQuestLog:IsFilteringAsActive()
	return self.wndMain:FindChild("LeftSideFilterBtnShowActive"):IsChecked()
end

function BetterQuestLog:IsFilteringAsFinished()
	return self.wndMain:FindChild("LeftSideFilterBtnShowFinished"):IsChecked()
end

function BetterQuestLog:IsFilteringAsHidden()
	return self.wndMain:FindChild("LeftSideFilterBtnShowHidden"):IsChecked()
end

function BetterQuestLog:HelperPrereqFailed(tCurrItem)
	return tCurrItem and tCurrItem:IsEquippable() and not tCurrItem:CanEquip()
end

function BetterQuestLog:HelperPrefixTimeString(fTime, strAppend, strColorOverride)
	local fSeconds = fTime % 60
	local fMinutes = fTime / 60
	local strColor = "fffffc00"
	if strColorOverride then
		strColor = strColorOverride
	elseif fMinutes < 1 and fSeconds <= 30 then
		strColor = "ffff0000"
	end
	return string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"%s\">(%d:%.02d) </T>%s", strColor, fMinutes, fSeconds, strAppend)
end

function BetterQuestLog:HelperBuildItemTooltip(wndArg, item)
	wndArg:SetTooltipDoc(nil)
	wndArg:SetTooltipDocSecondary(nil)
	local itemEquipped = item:GetEquippedItemForItemType()
	Tooltip.GetItemTooltipForm(self, wndArg, item, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
end

function BetterQuestLog:FactoryProduce(wndParent, strFormName, strKey)
	local wnd = self.arLeftTreeMap[strKey]
	if not wnd or not wnd:IsValid() then
		wnd = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		wnd:SetData(strKey)
		self.arLeftTreeMap[strKey] = wnd
	end
	return wnd
end

---------------------------------------------------------------------------------------------------
-- TopLevelItem Functions
---------------------------------------------------------------------------------------------------

function BetterQuestLog:OnShowLevelChecked( wndHandler, wndControl, eMouseButton )
	self.wndMain:FindChild("ShowLevelCheckboxBtn"):SetCheck(true)
	self:RedrawLeftTree()
end

function BetterQuestLog:OnShowLevelUnchecked( wndHandler, wndControl, eMouseButton )
	self.wndMain:FindChild("ShowLevelCheckboxBtn"):SetCheck(false)
	self:RedrawLeftTree()
end

function BetterQuestLog:OnExpandChecked( wndHandler, wndControl, eMouseButton )
	for key, wndCategory in pairs(self.wndMain:FindChild("LeftSideScroll"):GetChildren()) do
		wndCategory:FindChild("PreviousTopLevelBtn"):SetCheck(true)
	end	
	self:RedrawLeftTree()
end

function BetterQuestLog:OnExpandUnchecked( wndHandler, wndControl, eMouseButton )
	for key, wndCategory in pairs(self.wndMain:FindChild("LeftSideScroll"):GetChildren()) do
		wndCategory:FindChild("PreviousTopLevelBtn"):SetCheck(false)
	end
	self:RedrawLeftTree()
end

function BetterQuestLog:CheckTrackedToggle( wndHandler, wndControl, eMouseButton )
	local wndTopBtn = wndHandler:GetParent():FindChild("TopLevelBtn")
	
	if eMouseButton == 1 and Apollo.IsShiftKeyDown() then
		Event_FireGenericEvent("GenericEvent_QuestLink", wndTopBtn:GetData())
	elseif Apollo.IsShiftKeyDown() then
		-- handle tracking
		local queSelected = wndTopBtn:GetData()
		local bNewTrackValue = not queSelected:IsTracked()
		queSelected:SetTracked(bNewTrackValue)
		Event_FireGenericEvent("GenericEvent_QuestLog_TrackBtnClicked", queSelected)
	elseif not wndTopBtn:IsChecked() then
	--if the button we selected was already checked, do NOT uncheck it if shift key was down
		-- if the button we selected is not checked, check it
		if lastSelected ~= nil then
			lastSelected:SetCheck(false)
			
			if lastSelected:GetParent() ~= nil and lastSelected:GetParent():FindChild("BottomLevelQuestLinkBtn") ~= nil then
				local lastBg = lastSelected:GetParent():FindChild("BottomLevelQuestLinkBtn"):FindChild("ProgressBarBG")
				lastBg:Show(false)
			end
		end
		lastSelected = wndTopBtn
		self:OnBottomLevelBtnCheck(wndTopBtn, wndTopBtn)
	end
	
	self:RedrawEverything()
end


local BetterQuestLogInst = BetterQuestLog:new()
BetterQuestLogInst:Init()