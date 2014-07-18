-----------------------------------------------------------------------------------------------
-- Client Lua Script for SimpleQuestTracker
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "GameLib"
 
-----------------------------------------------------------------------------------------------
-- SimpleQuestTracker Module Definition
-----------------------------------------------------------------------------------------------
local SimpleQuestTracker = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999

-----------------------------------------------------------------------------------------------
-- Variables
-----------------------------------------------------------------------------------------------
local SimpleMode = true
local SimpleQuestTracker_loc = SimpleQuestTracker_loc_enUS
local CarbineQuestTracker = {}
local CarbineRedrawAll = nil
local CarbineDrawEpisodeQuests = nil
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function SimpleQuestTracker:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function SimpleQuestTracker:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		"QuestTracker"
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)

	local strCancel = Apollo.GetString(1)
	-- German
	if strCancel == "Abbrechen" then 
		SimpleQuestTracker_loc = SimpleQuestTracker_loc_deDE
	end

	-- French
	if strCancel == "Annuler" then
		SimpleQuestTracker_loc = SimpleQuestTracker_loc_frFR
	end

	-- Other fall back on English
	-- Already set as default
end

--------------------------------------------------------------------------------------------
-- SimpleQuestTracker OnLoad
-----------------------------------------------------------------------------------------------
function SimpleQuestTracker:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("SimpleQuestTracker.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- SimpleQuestTracker OnDocLoaded
-----------------------------------------------------------------------------------------------
function SimpleQuestTracker:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "SimpleQuestTrackerForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
	    self.wndMain:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("sqt", "OnSlashCommand", self)

		-- Do additional Addon initialization here
		CarbineQuestTracker = Apollo.GetAddon("QuestTracker")
		CarbineRedrawAll = CarbineQuestTracker["RedrawAll"]
		CarbineDrawEpisodeQuests = CarbineQuestTracker["DrawEpisodeQuests"]
		assert(CarbineRedrawAll, "Carbine original QuestTracker:RedrawAll function not found")
		assert(CarbineDrawEpisodeQuests, "Carbine original QuestTracker:CarbineDrawEpisodeQuests function not found")
		self:SetMode()
	end
end

-----------------------------------------------------------------------------------------------
-- SimpleQuestTracker Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

function SimpleQuestTracker:OnSlashCommand(cmd, args)
	SimpleMode = not SimpleMode
	self:SetMode()
end

function SimpleQuestTracker:SetMode()
	if SimpleMode then
		CarbineQuestTracker["RedrawAll"]=self["RedrawAll"]
		CarbineQuestTracker["DrawEpisodeQuests"]=self["DrawEpisodeQuests"]
	else
		CarbineQuestTracker["RedrawAll"]=CarbineRedrawAll
		CarbineQuestTracker["DrawEpisodeQuests"]=CarbineDrawEpisodeQuests
	end
	
	-- If the window already exists we need to clear out Carbine's episodes and start over.
	if nil ~= CarbineQuestTracker.wndMain then
		CarbineQuestTracker:DestroyAndRedraw()
	end
end

function SimpleQuestTracker:RedrawAll()
	Apollo.StopTimer("QuestTrackerRedrawTimer")
	self.bRedrawQueued = false
	
	-- Remove previously tracked quests that are out of the current zone
	for idx1, wndEpGroup in pairs(self.wndMain:FindChild("QuestTrackerScroll"):GetChildren()) do
		if wndEpGroup:GetName() == "EpisodeGroupItem" then
			for idx2, wndEp in pairs(wndEpGroup:FindChild("EpisodeGroupContainer"):GetChildren()) do
				if wndEp:GetName() == "EpisodeItem" then
					for idx3, wndQuest in pairs(wndEp:FindChild("EpisodeQuestContainer"):GetChildren()) do
						if wndQuest:GetName() == "QuestItem" then
							local queQuest = wndQuest:GetData()
							local epiEpisode = queQuest:GetEpisode()
							if (epiEpisode.IsRegionalStory or epiEpisode.IsZoneStory) and not GameLib.IsInWorldZone(queQuest:GetEpisode():GetZoneId()) then
								self:QueueQuestForDestroy(queQuest)
							end
						end
					end
				elseif wndEp:GetName() == "QuestItem" then
					local queQuest = wndEp:GetData()
					local epiEpisode = queQuest:GetEpisode()
					if (epiEpisode.IsRegionalStory or epiEpisode.IsZoneStory) and not GameLib.IsInWorldZone(queQuest:GetEpisode():GetZoneId()) then
						self:QueueQuestForDestroy(queQuest)
					end
				end
			end
		end
	end
	
	self:HelperFindAndDestroyQuests()
	
	if #self.tZombiePublicEvents > 0 then
		self:DrawPublicEpisodes()
	elseif #PublicEvent.GetActiveEvents() > 0 then
		self:DrawPublicEpisodes()
	elseif self.wndMain:FindChild("QuestTrackerScroll"):FindChildByUserData(kstrPublicEventMarker) then
		-- Safety (should rarely fire): If we're out of events and the window is still around, switch views.
		self.bDrawDungeonScreenOnly = false
		self.bDrawPvPScreenOnly = false
		self:DestroyAndRedraw()
		return
	end

	if not self.bDrawPvPScreenOnly and not self.bDrawDungeonScreenOnly then
		local wndEpisodeGroup

		self.nQuestCounting = 0
		
		-- Begin modified region
		-- Always use the same Episode wnd so just go ahead and create it once here instead of attempting to make a new one for every episode
		wndEpisodeGroup = self:FactoryProduce(self.wndMain:FindChild("QuestTrackerScroll"), "EpisodeGroupItem", "4EGTask")
		wndEpisodeGroup:FindChild("EpisodeGroupTitle"):SetText(SimpleQuestTracker_loc.ActiveQuests)
		
		for idx, epiEpisode in pairs(QuestLib.GetTrackedEpisodes(self.bQuestTrackerByDistance)) do
			local drawEpisode = false;  -- use a boolean in place of checking if an object was created since we are no longer creating objects here
			if epiEpisode:IsWorldStory() then
				drawEpisode = true;
			elseif epiEpisode:IsZoneStory() then
				if GameLib.IsInWorldZone(epiEpisode:GetZoneId()) then
					drawEpisode = true;
				end
			elseif epiEpisode:IsRegionalStory() then
				if GameLib.IsInWorldZone(epiEpisode:GetZoneId()) then
					drawEpisode = true;
				else
					for nIdx, queQuest in pairs(epiEpisode:GetTrackedQuests(0, self.bQuestTrackerByDistance)) do
					end
				end
			else -- task
				drawEpisode = true;
			end

			if drawEpisode then
				self:DrawEpisodeQuests(epiEpisode, wndEpisodeGroup:FindChild("EpisodeGroupContainer"))
			end
		end		
		-- End modified region

		wndEpisodeGroup = self.wndMain:FindChild("QuestTrackerScroll"):FindChildByUserData("1EGWorld")
		if wndEpisodeGroup ~= nil and wndEpisodeGroup:IsValid() and next(wndEpisodeGroup:FindChild("EpisodeGroupContainer"):GetChildren()) == nil then
			wndEpisodeGroup:Destroy()
		end
		wndEpisodeGroup = self.wndMain:FindChild("QuestTrackerScroll"):FindChildByUserData("2EGZone")
		if wndEpisodeGroup ~= nil and wndEpisodeGroup:IsValid() and next(wndEpisodeGroup:FindChild("EpisodeGroupContainer"):GetChildren()) == nil then
			wndEpisodeGroup:Destroy()
		end
		wndEpisodeGroup = self.wndMain:FindChild("QuestTrackerScroll"):FindChildByUserData("3EGRegional")
		if wndEpisodeGroup ~= nil and wndEpisodeGroup:IsValid() and next(wndEpisodeGroup:FindChild("EpisodeGroupContainer"):GetChildren()) == nil then
			wndEpisodeGroup:Destroy()
		end
		wndEpisodeGroup = self.wndMain:FindChild("QuestTrackerScroll"):FindChildByUserData("4EGTask")
		if wndEpisodeGroup ~= nil and wndEpisodeGroup:IsValid() and next(wndEpisodeGroup:FindChild("EpisodeGroupContainer"):GetChildren()) == nil then
			wndEpisodeGroup:Destroy()
		end
	end
	
	self:ResizeEpisodes()
end

function SimpleQuestTracker:DrawEpisodeQuests(epiEpisode, wndContainer)
	local myself = GameLib.GetPlayerUnit();
	if myself ~= nil then
		local playerPosition = myself:GetPosition();
	
		for nIdx, queQuest in pairs(epiEpisode:GetTrackedQuests(0, self.bQuestTrackerByDistance)) do
			self.nQuestCounting = self.nQuestCounting + 1 -- TODO replace with nIdx or something eventually
			self:DrawQuest(self.nQuestCounting, queQuest, wndContainer)
			-- Begin modified region:
			-- Calculate distance and store in the quest's tracker wnd object
			-- for each map marker of this quest, claculate the approximate distance from the player  Note this is not the actual distance, just enough math to sort them mostly right quickly.
			-- if no markers, than the distance is -1, and the quest will display on top of the tracker in the order received from the QuestLib
			local distance = 9999999999;
			for idx, mapRegion in ipairs(queQuest:GetMapRegions()) do
				local deltaX = mapRegion.tIndicator.x - playerPosition.x;
				local deltaY = mapRegion.tIndicator.y - playerPosition.y;
				local deltaZ = mapRegion.tIndicator.z - playerPosition.z;
				local curDistance = (deltaX * deltaX) + (deltaY * deltaY) + (deltaZ * deltaZ);
				-- only care about the minimum distance value
				if distance == 9999999999 or curDistance < distance then
					distance = curDistance;
				end
			end
			
			local wndQuest = self:FactoryProduce(wndContainer, "QuestItem", queQuest);
			wndQuest:FindChild("QuestNumber"):SetData(distance);
			-- End Modified region
		end

		-- Inline Sort Method
		local function SortQuestTrackerScroll(a, b)
			if not a or not b or not a:FindChild("QuestNumber") or not b:FindChild("QuestNumber") then return true end
			-- Begin modified region
			-- if distance data is stored for the quests in question, sort by distance, else sort by carbnie quest number as the function originally does
			if nil ~= a:FindChild("QuestNumber"):GetData() and nil ~= b:FindChild("QuestNumber"):GetData() then
				-- Sort by distance
				return (a:FindChild("QuestNumber"):GetData() or 0.0) < (b:FindChild("QuestNumber"):GetData() or 0.0)
			else
				-- Sort by Carbine calculated quest numbers
				return (tonumber(a:FindChild("QuestNumber"):GetText()) or 0) < (tonumber(b:FindChild("QuestNumber"):GetText()) or 0)
			end
			-- End modified region
		end

		wndContainer:ArrangeChildrenVert(0, SortQuestTrackerScroll)
	end
end

-----------------------------------------------------------------------------------------------
-- SimpleQuestTracker Instance
-----------------------------------------------------------------------------------------------
local SimpleQuestTrackerInst = SimpleQuestTracker:new()
SimpleQuestTrackerInst:Init()