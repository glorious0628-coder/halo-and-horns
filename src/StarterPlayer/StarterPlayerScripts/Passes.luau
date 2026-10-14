-- Passes.luau (게임성 개발 1, SPEC A23-75 "산 뒤 알림"): right after I buy something in this session, the moment the server
-- turns it on - my PassXP2 / PassGold2 / PassVIP attribute (PromptGamePassPurchaseFinished + UserOwnsGamePassAsync on the
-- server, 게임성 개발 2) or a longer LooksOwned (a bought look) - one thank-you line says what it does. Only within
-- BoughtWindow s of a finished purchase of mine (MarketplaceService ...PurchaseFinished, wasPurchased = true): the
-- join-time ownership check that flips a flag late never speaks, and neither does a save. A purchase window closed without
-- buying says nothing (no pressure, A23-75 "강요·속임수 유도 없음"). The HUD chips ('2x XP' / '2x Gold') and the Shop window
-- are 이미지 개발's (HUD L.Fold, ShopUI.luau). Presentation only: the server owns every pass.
-- Public API: Passes.Init(C), Passes.Start(), Passes.LineFor(attr) -> the thank-you text or nil, Passes.Bought(purchased)
-- (a purchase window finished), Passes.OnAttr(attr, prev, value) -> the line shown or nil (the offline test drives them).
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Passes = {}
local C = nil

local T = {
	ToastSeconds = 6,
	BoughtWindow = 30, -- s after my finished purchase: the server's flag turning on gets its thank-you line
	-- the server's flags (dev2) -> the thank-you line (game text: English only, A23-48; short and easy)
	Lines = Config.ClientText.PassesLines, -- the words: Config.ClientText.PassesLines (moved 10/14)
	Looks = "LooksOwned", -- the server's bought-look list (a string that grows)
	LookLine = Config.ClientText.PassesLines.Look,
}
local S = { BoughtAt = -math.huge }

local LocalPlayer = Players.LocalPlayer

function Passes.LineFor(attr)
	return T.Lines[attr]
end

-- a purchase window of mine finished (wasPurchased = the player really bought)
function Passes.Bought(purchased)
	if purchased == true then S.BoughtAt = os.clock() end
end

local function show(text)
	local kit = C and C.UIKit
	if type(kit) == "table" and type(kit.Toast) == "function" then pcall(kit.Toast, text, "good", T.ToastSeconds) end
end

-- one attribute change: a flag that turned on right after my purchase -> its line
function Passes.OnAttr(attr, prev, value)
	if os.clock() - S.BoughtAt > T.BoughtWindow then return nil end
	local line = nil
	if T.Lines[attr] then
		if value == true and prev ~= true then line = T.Lines[attr] end
	elseif attr == T.Looks then
		local before = type(prev) == "string" and prev or ""
		if type(value) == "string" and #value > #before then line = T.LookLine end
	end
	if line then
		S.BoughtAt = -math.huge -- one purchase, one thank-you
		show(line)
	end
	return line
end

local function watch(attr)
	local last = LocalPlayer:GetAttribute(attr)
	LocalPlayer:GetAttributeChangedSignal(attr):Connect(function()
		local prev = last
		last = LocalPlayer:GetAttribute(attr)
		pcall(Passes.OnAttr, attr, prev, last)
	end)
end

function Passes.Init(registry)
	C = registry
end

function Passes.Start()
	if not LocalPlayer then return end
	for attr in T.Lines do watch(attr) end
	watch(T.Looks)
	pcall(function()
		MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, _, purchased)
			if player == LocalPlayer then Passes.Bought(purchased) end
		end)
		MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _, purchased)
			if userId == LocalPlayer.UserId then Passes.Bought(purchased) end
		end)
	end)
end

return Passes
