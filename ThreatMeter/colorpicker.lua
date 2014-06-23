-----------------------------------------------------------------------------------------------
-- ColorPicker
-- Requires DaiGUI-1.0
-- @author daihenka
-----------------------------------------------------------------------------------------------

local aAddon = Apollo.GetAddon("ThreatMeter")
local DaiGUI = Apollo.GetPackage("DaiGUI-1.0").tPackage

local function RGBToHex(r, g, b)
	return string.format("%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function ApolloColorToHex(ac)
	return RGBToHex(ac.r, ac.g, ac.b)
end

local function HexToApolloColor(strHex)
	return ApolloColor.new("ff" .. strHex)
end

local function CT(x) 
	return tostring(math.floor(x * 255 + 0.5))
end

local function ApolloColorToHSV(ac)
	local minVal = math.min(ac.r, ac.g, ac.b)
	local maxVal = math.max(ac.r, ac.g, ac.b)
	local delta = maxVal - minVal
	local h, s, v = 0, 0, maxVal
	if delta == 0 then
		h, s = 0, 0
	else
		s = delta / maxVal
		
		local delR = (((maxVal - ac.r) / 6) + (delta / 2)) / delta
		local delG = (((maxVal - ac.g) / 6) + (delta / 2)) / delta
		local delB = (((maxVal - ac.b) / 6) + (delta / 2)) / delta
		
		if ac.r == maxVal then
		  h = delB - delG
		elseif ac.g == maxVal then
		  h = (1 / 3) + delR - delB
		elseif ac.b == maxVal then
		  h = (2 / 3) + delG - delR
		end
		
		if h < 0 then
		  h = h + 1
		elseif h > 1 then
		  h = h - 1
		end
	end
	return h, s, v
end

local function HSVtoCColor(ch, cs, cv)
	ch = ch or 0
	cs = cs or 0
	cv = cv or 0

	local r, g, b = cv, cv, cv
	
	local i = math.floor(ch * 6)
	local f = ch * 6 - i
	local p = cv * (1 - cs)
	local q = cv * (1 - f * cs)
	local t = cv * (1 - (1 - f) * cs)
	local x = i % 6
	if x == 0 then
		r = cv
		g = t
		b = p
	elseif x == 1 then
		r = q
		g = cv
		b = p
	elseif x == 2 then
		r = p
		g = cv
		b = t
	elseif x == 3 then
		r = p
		g = q
		b = cv
	elseif x == 4 then
		r = t
		g = p
		b = cv
	elseif x == 5 then
		r = cv
		g = p
		b = q
	end
	return CColor.new(r, g, b, 1)
end


local DaiColorPicker = {
	bMapMouseDown = false,
	bBarMouseDown = false,
	fHue = 1,
	fSaturation = 1,
	fValue = 1,

	OnMapMouseMove = function(self, wndHandler, wndControl, x, y)
		if wndHandler ~= wndControl then return end
		if self.bMapMouseDown then
			self:UpdateMapColor(x, y)
		end
	end,
	OnMapMouseDown = function(self, wndHandler, wndControl, eButton, x, y)
		if wndHandler ~= wndControl then return end
		self:UpdateMapColor(x, y)
		self.bMapMouseDown = true
	end,
	OnMapMouseUp = function(self, wndHandler, wndControl, eButton, x, y)
		if wndHandler ~= wndControl then return end
		if self.bMapMouseDown then
			self:UpdateMapColor(x, y)
		end
		self.bMapMouseDown = false
	end,
	OnMapMouseExit = function(self, wndHandler, wndControl)
		if wndHandler ~= wndControl then return end
		self.bMapMouseDown = false
	end,
	
	-- Bar
	OnBarMouseMove = function(self, wndHandler, wndControl, x, y)
		if wndHandler ~= wndControl then return end
		if self.bBarMouseDown then
			self:UpdateBarColor(y)
		end
	end,
	OnBarMouseDown = function(self, wndHandler, wndControl, eButton, x, y)
		if wndHandler ~= wndControl then return end
		self:UpdateBarColor(y)
		self.bBarMouseDown = true
	end,
	OnBarMouseUp = function(self, wndHandler, wndControl, eButton, x, y)
		if wndHandler ~= wndControl then return end
		if self.bBarMouseDown then
			self:UpdateBarColor(y)
		end
		self.bBarMouseDown = false
	end,
	OnBarMouseExit = function(self, wndHandler, wndControl)
		if wndHandler ~= wndControl then return end
		self.bBarMouseDown = false
	end,
	
	OnOkBtn = function(self, wndHandler, wndControl)
		self.bNewColor = true
		self.wnd:Close()
	end,
	
	OnCloseBtn = function(self, wndHandler, wndControl)
		self.wnd:Close()
	end,
	
	OnClose = function(self, wndHandler, wndControl)
		if wndHandler ~= wndControl then return end
		if not self.bNewColor then
			self:SetCurrentColor(self.crInitial)
			self.bNewColor = true
		end
		
		-- fire callback here
		self:DoCallback()
	end,	
	
	OnHexChanged = function(self, wndHandler, wndControl, strHex)
		if strHex:len() ~= 6 then return end
		self:SetCurrentColor(HexToApolloColor(strHex))
		self:UpdateBarMap()	
	end,
	
	OnColorEdit = function(self)
		local redEdit = self.wnd:FindChild("RedEdit")
		local greenEdit = self.wnd:FindChild("GreenEdit")
		local blueEdit = self.wnd:FindChild("BlueEdit")
		local r = tonumber(redEdit:GetText())
		local g = tonumber(greenEdit:GetText())
		local b = tonumber(blueEdit:GetText())
		
		if (r and r >= 0 and r <= 255) and 
		   (g and g >= 0 and g <= 255) and 
		   (b and b >= 0 and b <= 255) then
		   
		   self:SetCurrentColor(ApolloColor.new({ r = r / 255, g = g / 255, b = b / 255, a = 1 }))
		   self:UpdateBarMap()	
		end
		
		redEdit:SetSel(redEdit:GetText():len(), -1)
		greenEdit:SetSel(greenEdit:GetText():len(), -1)
		blueEdit:SetSel(blueEdit:GetText():len(), -1)
	end,
	
	UpdateMapColor = function(self, x, y)
		self.wnd:FindChild("MapFrame:MapBG:Map:Pointer"):SetAnchorOffsets(x - 8, y - 8, x + 8, y+8)
		
		self.fSaturation = math.max(0, math.min(x / self.wnd:FindChild("MapFrame:MapBG:Map"):GetWidth(), 1))
		self.fValue = (1 - math.max(0, math.min(y / self.wnd:FindChild("MapFrame:MapBG:Map"):GetHeight(), 1)))
		self:SetCurrentColor(HSVtoCColor(self.fHue, self.fSaturation, self.fValue))
		self:UpdateCurrentColor()
	end,
	
	SetCurrentColor = function(self, crNew)
		if type(crNew) == "userdata" and type(getmetatable(crNew).IsSameColorAs) == "function" then
			self.crCurrent = crNew
		elseif type(crNew) == "userdata" then
			self.crCurrent = ApolloColor.new({ r = crNew.r, g = crNew.g, b = crNew.b, a = 1 })
		else
			self.crCurrent = ApolloColor.new(crNew)
		end
	end,
	
	UpdateBarColor = function(self, y)
		self.wnd:FindChild("BarFrame:Bar:Pointer"):SetAnchorOffsets(0, y-3, 0, y+4)
		
		self.fHue = (1 - math.max(0, math.min(y / self.wnd:FindChild("Bar"):GetHeight(), 1)))
		self.wnd:FindChild("MapBG"):SetBGColor(HSVtoCColor(self.fHue, 1, 1))
		self:SetCurrentColor(HSVtoCColor(self.fHue, self.fSaturation, self.fValue))
		self:UpdateCurrentColor()
	end,
	
	DoCallback = function(self)
		if type(self.fnCallback) == "function" then
			self.fnCallback(self.crCurrent, self.bNewColor)
		end
	end,
	
	UpdateCurrentColor = function(self)
		self.wnd:FindChild("PreviewContainer:Current"):SetBGColor(self.crCurrent)
		self.wnd:FindChild("HexEdit"):SetText(ApolloColorToHex(self.crCurrent))
		self.wnd:FindChild("RedEdit"):SetText(CT(self.crCurrent.r))
		self.wnd:FindChild("GreenEdit"):SetText(CT(self.crCurrent.g))
		self.wnd:FindChild("BlueEdit"):SetText(CT(self.crCurrent.b))
		self:DoCallback()
	end,
	
	UpdateBarMap = function(self)
		-- update from current color
		local mapX, mapY, barY = 0, 0, 0
		local h, s, v = ApolloColorToHSV(self.crCurrent)
		self.fHue, self.fSaturation, self.fValue = h, s, v
		
		mapX = s * self.wnd:FindChild("MapFrame:MapBG:Map"):GetWidth()
		mapY = (1 - v) * self.wnd:FindChild("MapFrame:MapBG:Map"):GetWidth()
		self.wnd:FindChild("MapBG"):SetBGColor(HSVtoCColor(h, 1, 1))
		self.wnd:FindChild("MapFrame:MapBG:Map:Pointer"):SetAnchorOffsets(mapX - 8, mapY - 8, mapX + 8, mapY + 8)
		
		barY = (1 - h) * self.wnd:FindChild("BarFrame:Bar"):GetHeight()
		self.wnd:FindChild("BarFrame:Bar:Pointer"):SetAnchorOffsets(0, barY - 3, 0, barY + 4)
		
		self:UpdateCurrentColor()
	end,
}

local tColorPickerFormDef = {
  AnchorCenter = { 475, 375 },
  RelativeToClient = true, 
  BGColor = "UI_WindowBGDefault", 
  TextColor = "UI_WindowTextDefault", 
  Name = "ColorPickerForm", 
  Picture = true, 
  SwallowMouseClicks = true, 
  Moveable = true, 
  Escapable = true, 
  Overlapped = true, 
  Sprite = "BK3:UI_BK3_Holo_Framing_2", 
  Visible = false,
  Children = {
    {
      AnchorOffsets = { 42, 72, 300, 330 },
      RelativeToClient = true, 
      BGColor = "darkgray", 
      Name = "MapFrame", 
      Sprite = "WhiteFill", 
      Picture = true, 
	  IgnoreMouse = true,
	  Children = {
		{
		  AnchorFill = 1,
		  RelativeToClient = true, 
		  BGColor = "ffffffff", 
		  Name = "MapBG", 
		  Sprite = "WhiteFill", 
		  Picture = true, 
		  IgnoreMouse = true,
		  Children = {
			{
			  AnchorFill = true,
			  RelativeToClient = true, 
			  BGColor = "UI_WindowBGDefault", 
			  TextColor = "UI_WindowTextDefault", 
			  Name = "Map", 
			  Sprite = "dgcpHueMap", 
			  Picture = true, 
			  --Overlapped = true, 
			  SwallowMouseClicks = true, 
			  Events = {
				MouseButtonDown = "OnMapMouseDown",
				MouseButtonUp = "OnMapMouseUp",
				MouseMove = "OnMapMouseMove",
				MouseExit = "OnMapMouseExit",
			  },
			  Children = {
				{
				  AnchorOffsets = { 10, 10, 26, 26 },
				  RelativeToClient = true, 
				  BGColor = "UI_WindowBGDefault", 
				  Sprite = "CRB_PlayerPathSprites:sprPP_ExpTargetIcon",
				  TextColor = "UI_WindowTextDefault", 
				  Name = "Pointer", 
				},
			  },
			},
		  },
		},
	  },
    },
    {
      AnchorOffsets = { 308, 72, 330, 330 },
      RelativeToClient = true, 
      BGColor = "darkgray", 
      Name = "BarFrame", 
      Sprite = "WhiteFill", 
      Picture = true, 
	  IgnoreMouse = true,
	  Children = {
		{
		  AnchorFill = 1,
		  RelativeToClient = true, 
		  BGColor = "UI_WindowBGDefault", 
		  TextColor = "UI_WindowTextDefault", 
		  Name = "Bar", 
		  Sprite = "dgcpHueBar", 
		  Overlapped = true, 
		  Picture = true, 
		  SwallowMouseClicks = true, 
		  Events = {
			MouseButtonDown = "OnBarMouseDown",
			MouseButtonUp = "OnBarMouseUp",
			MouseMove = "OnBarMouseMove",
			MouseExit = "OnBarMouseExit",
		  },
		  Children = {
			{
			  AnchorOffsets = { 0, 10, 0, 17 },
			  AnchorPoints = "HFILL",
			  RelativeToClient = true, 
			  BGColor = "UI_WindowBGDefault", 
			  TextColor = "UI_WindowTextDefault", 
			  Sprite = "dgcpBarPointer",
			  Name = "Pointer", 
			  IgnoreMouse = true, 
			  NoClip = true, 
			},
		  },
		},
      },
    },
	{
		Name = "PreviewContainer",
		AnchorOffsets = { 340, 72, 430, 94 },
		Sprite = "WhiteFill",
		BGColor = "darkgray",
		Children = {
			{
				Name = "Initial",
				AnchorPoints = { 0, 0, 0.5, 1 },
				AnchorOffsets = { 1, 1, 0, -1 },
				Sprite = "WhiteFill",
				BGColor = "green",
				Events = {
					MouseButtonDown = function(self, wndHandler, wndControl)
						if wndHandler ~= wndControl then return end
						self:SetCurrentColor(wndControl:GetBGColor())
						self:UpdateBarMap()
					end,
				},
			},
			{
				Name = "Current",
				AnchorPoints = { 0.5, 0, 1, 1 },
				AnchorOffsets = { 0, 1, -1, -1 },
				Sprite = "WhiteFill",
				BGColor = "yellow",
			},
		},
	},
	{
		AnchorOffsets = { 332, 105, 432, 330 },
--		Sprite = "BK3:UI_BK3_Holo_InsetSimple",
		Children = {
			{
				AnchorOffsets = { 5, 6, 80, 30 },
				Children = {
					{
						Text = "R",
						Font = "CRB_Button",
						TextColor = "UI_WindowTextDefault",
						DT_RIGHT = true,
						DT_VCENTER = true,
						AnchorPoints = { 0, 0, 0, 1 },
						AnchorOffsets = { 0, 4, 15, -4 },
					},
					{
						AnchorPoints = { 0, 0, 1, 1 },
						AnchorOffsets = { 25, 0, 0, 0 },
						Sprite = "HologramSprites:HoloFrame3",
						Children = {
							{
								Name = "RedEdit",
								Class = "EditBox",
								Font = "CRB_Button",
								Text = "255",
								DT_CENTER = true,
								DT_VCENTER = true,
								AnchorFill = 4,
								LoseFocusOnExternalClick = true,
								TabStop = true,
								Events = {
									EditBoxChanged = "OnColorEdit"
								},
							},
						},
					},
				},
			},
			{
				AnchorOffsets = { 5, 34, 80, 58 },
				Children = {
					{
						Text = "G",
						Font = "CRB_Button",
						TextColor = "UI_WindowTextDefault",
						DT_RIGHT = true,
						DT_VCENTER = true,
						AnchorPoints = { 0, 0, 0, 1 },
						AnchorOffsets = { 0, 4, 15, -4 },
					},
					{
						AnchorPoints = { 0, 0, 1, 1 },
						AnchorOffsets = { 25, 0, 0, 0 },
						Sprite = "HologramSprites:HoloFrame3",
						Children = {
							{
								Name = "GreenEdit",
								Class = "EditBox",
								Font = "CRB_Button",
								Text = "255",
								DT_CENTER = true,
								DT_VCENTER = true,
								AnchorFill = 4,
								LoseFocusOnExternalClick = true,
								TabStop = true,
								Events = {
									EditBoxChanged = "OnColorEdit"
								},
							},
						},
					},
				},
			},
			{
				AnchorOffsets = { 5, 62, 80, 86 },
				Children = {
					{
						Text = "B",
						Font = "CRB_Button",
						TextColor = "UI_WindowTextDefault",
						DT_RIGHT = true,
						DT_VCENTER = true,
						AnchorPoints = { 0, 0, 0, 1 },
						AnchorOffsets = { 0, 4, 15, -4 },
					},
					{
						AnchorPoints = { 0, 0, 1, 1 },
						AnchorOffsets = { 25, 0, 0, 0 },
						Sprite = "HologramSprites:HoloFrame3",
						Children = {
							{
								Name = "BlueEdit",
								Class = "EditBox",
								Font = "CRB_Button",
								Text = "255",
								DT_CENTER = true,
								DT_VCENTER = true,
								AnchorFill = 4,
								LoseFocusOnExternalClick = true,
								TabStop = true,
								Events = {
									EditBoxChanged = "OnColorEdit"
								},
							},
						},
					},
				},
			},
			{
				AnchorOffsets = { 5, 90, 100, 114 },
				Children = {
					{
						Text = "#",
						Font = "CRB_Button",
						TextColor = "UI_WindowTextDefault",
						DT_RIGHT = true,
						DT_VCENTER = true,
						AnchorPoints = { 0, 0, 0, 1 },
						AnchorOffsets = { 0, 4, 15, -4 },
					},
					{
						AnchorPoints = { 0, 0, 1, 1 },
						AnchorOffsets = { 25, 0, -10, 0 },
						Sprite = "HologramSprites:HoloFrame3",
						Children = {
							{
								Name = "HexEdit",
								Class = "EditBox",
								Font = "CRB_Button",
								Text = "ffffff",
								DT_CENTER = true,
								DT_VCENTER = true,
								AnchorFill = 4,
								LoseFocusOnExternalClick = true,
								TabStop = true,
								Events = {
									EditBoxChanged = "OnHexChanged",
								},
							},
						},
					},
				},
			},
		},
	},
	{
		Class = "Button",
		ButtonType = "PushButton",
		Base = "BK3:btnHolo_Blue_Med",
		Text = "OK",
		Font = "CRB_Button",
		DT_CENTER = true,
		DT_VCENTER = true,
		AnchorPoints = { 1, 1, 1, 1 },
		AnchorOffsets = { -147, -87, -37, -30 },
		Events = {
			ButtonSignal = "OnOkBtn",
		},
	},
	{
		Class = "Button",
		ButtonType = "PushButton",
		Base = "BK3:btnHolo_Close",
		AnchorPoints = { 1, 0, 1, 0 },
		AnchorOffsets = { -62, 32, -34, 62 },
		Events = {
			ButtonSignal = "OnCloseBtn",
		},
	},
	{
		AnchorPoints = { 0, 0, 1, 0 },
		AnchorOffsets = { 0, 32, 0, 70 },
		Text = "Color Picker",
		Font = "CRB_HeaderMedium_O",
		TextColor = "UI_TextHoloTitle",
		DT_CENTER = true,
		DT_VCENTER = true,
	},
  },
  Events = {
	WindowClosed = "OnClose",
  },
}

function DaiColorPicker.AdjustColor(initialColor, fnCallback)
	local o = {}
	setmetatable(o, DaiColorPicker)
    DaiColorPicker.__index = DaiColorPicker
	o.wnd = DaiGUI:Create(tColorPickerFormDef):GetInstance(o)
	o.bNewColor = false
	o.fnCallback = fnCallback
	o.crInitial = ApolloColor.new(initialColor)
	o:SetCurrentColor(ApolloColor.new(initialColor))
	o.wnd:FindChild("PreviewContainer:Initial"):SetBGColor(o.crInitial)
	o:UpdateBarMap()
	o.wnd:Show(true)
end

aAddon.DaiColorPicker = DaiColorPicker