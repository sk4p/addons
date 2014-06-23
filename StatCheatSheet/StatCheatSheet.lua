-----------------------------------------------------------------------------------------------
-- Client Lua Script for StatCheatSheet
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- StatCheatSheet Module Definition
-----------------------------------------------------------------------------------------------
local StatCheatSheet = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function StatCheatSheet:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function StatCheatSheet:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- StatCheatSheet OnLoad
-----------------------------------------------------------------------------------------------
function StatCheatSheet:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("StatCheatSheet.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- StatCheatSheet OnDocLoaded
-----------------------------------------------------------------------------------------------
function StatCheatSheet:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "StatCheatSheetForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
	    self.wndMain:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("scs", "OnStatCheatSheetOn", self)

		-- The class buttons
		self.panel = self.wndMain:FindChild("ClassButtons")
		
		-- What class are we showing first?
		self.classForm = 'WarriorForm'
		self.wndMain:FindChild(self.classForm):Show(true,true)
		
		-- Do additional Addon initialization here
	end
end

-----------------------------------------------------------------------------------------------
-- StatCheatSheet Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on SlashCommand "/scs"
function StatCheatSheet:OnStatCheatSheetOn()
	self.wndMain:Invoke() -- show the window
end


-----------------------------------------------------------------------------------------------
-- StatCheatSheetForm Functions
-----------------------------------------------------------------------------------------------

-- when the Cancel button is clicked
function StatCheatSheet:OnCancel()
	self.wndMain:Close() -- hide the window
end

-- When a class button is clicked
function StatCheatSheet:ClassButton( wndHandler, wndControl, eMouseButton )
	if wndHandler ~= wndControl then
		return
	end
	
	-- Hide the previous form
	if self.classForm ~= nil then
		self.wndMain:FindChild(self.classForm):Show(false,true)
	end
	
	-- Get the form that we clicked
	form = wndControl:GetName()
	if form ~= nil then
		form = form .. "Form"
		self.classForm = form
		self.wndMain:FindChild(form):Show(true,true)
	end
	
end


-----------------------------------------------------------------------------------------------
-- StatCheatSheet Instance
-----------------------------------------------------------------------------------------------
local StatCheatSheetInst = StatCheatSheet:new()
StatCheatSheetInst:Init()
