require "Apollo"
require "Window"

local cGreen = CColor.new(0, 1, 0, 1) 
local cAqua = CColor.new(50/255,250/255,244/255,1)

local ChaChing = {}

function ChaChing:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    -- initialize variables here

    return o
end

function ChaChing:Init()
    local bHasConfigureFunction = false
    local strConfigureButtonText = ""
    local tDependencies = {  "MarketplaceCommodity", }
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end

function ChaChing:OnLoad()
	Apollo.GetPackage("Gemini:Hook-1.0").tPackage:Embed(self)
	ChaChing.MPC = Apollo.GetAddon("MarketplaceCommodity")
	if ChaChing.MPC then
		self:RawHook(ChaChing.MPC,"OnCommodityInfoResults")
	end
end

local CXRAKE = (100-MarketplaceLib.kCommodityAuctionRake)/100

local function getItemDetails(i)
	local di = Item.GetDataFromId(i):GetDetailedInfo().tPrimary
	local dx = {
		s=di.tCost.arMonSell[1]:GetAmount(),
		n=di.strName
		}
	return dx
end

function ChaChing:OnCommodityInfoResults(luaCaller, nItemId, tStats, tOrders)
	self.hooks[ChaChing.MPC].OnCommodityInfoResults(luaCaller, nItemId, tStats, tOrders)
	local wndMC = ChaChing.MPC.wndMain
	if wndMC and wndMC:FindChild("HeaderSellNowBtn") and wndMC:FindChild("HeaderSellNowBtn"):IsChecked() then
		local pS, pE = pcall(getItemDetails, nItemId)
		if pS then
			local wndMatch = wndMC:FindChild("MainScrollContainer"):FindChild(nItemId)
			if wndMatch then
				local buyamt = wndMatch:FindChild("ListSubtitlePriceLeft"):GetAmount()
				local vndamt = pE.s
				local wListName = wndMatch:FindChild("ListName")				
				if (buyamt * CXRAKE) > vndamt then
					wListName:SetTextColor(cGreen)
				else
					wListName:SetTextColor(cAqua)
				end
			end
		end
	end
end

local ChaChingInst = ChaChing:new()
ChaChingInst:Init()
