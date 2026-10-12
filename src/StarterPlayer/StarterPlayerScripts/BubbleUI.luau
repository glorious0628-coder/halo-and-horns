-- BubbleUI.luau : A23-144 chat bubble skins, the client side (게임성 개발 1; the server is 게임성 개발 2's
-- MonetizationService SetBubble / BubbleOn). Every player's chat bubble shows the skin of their BubbleOn attribute (a
-- Config.Bubbles.Order key; "" = their side's free one, Config.Bubbles.Free) to everyone: TextChatService.OnBubbleAdded
-- (this module owns that one callback - the place says LegacyChatService but Chat.IsAutoMigrated runs the new chat, see
-- Announce.HookTeamLine) returns a BubbleChatMessageProperties with the skin's art (Config.UIArt.Parts[key], a 9-slice
-- ImageLabel child) or, until the art is uploaded, its colours (LOOK: background, text, a soft gradient, round corners).
-- The chat text itself stays Roblox's (filtered); only the look changes. The picker row lives in the sticker picker
-- (StickerUI, key P): my side's free bubble + the 6 pack ones (Config.Bubbles.Order minus the other sides' free ones),
-- the one I wear framed, a pack one locked without PassBubbles (a press opens the Shop). A press sends SetBubble(key)
-- (my side's free one = ""), at most every Config.RateLimits.SetBubble s. No words (A23-130). Pure: Rows, LookOf, Props.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local BubbleUI = {}
local C = nil
local TAG = "BubbleUI"
local LocalPlayer = Players.LocalPlayer

-- the code look of a skin until its art is uploaded (최종 검수 10/13: colours, no invented art): Bg, Text, Grad = the
-- gradient's two ends (top -> bottom)
local LOOK = {
	BubbleHalo = { Bg = Color3.fromRGB(255, 255, 255), Text = Color3.fromRGB(40, 44, 70), Grad = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 236, 190) } },
	BubbleHorns = { Bg = Color3.fromRGB(110, 24, 34), Text = Color3.fromRGB(255, 236, 230), Grad = { Color3.fromRGB(140, 34, 44), Color3.fromRGB(80, 14, 24) } },
	BubbleArtisan = { Bg = Color3.fromRGB(128, 86, 50), Text = Color3.fromRGB(255, 244, 222), Grad = { Color3.fromRGB(150, 104, 62), Color3.fromRGB(104, 68, 38) } },
	BubblePixel = { Bg = Color3.fromRGB(30, 34, 40), Text = Color3.fromRGB(150, 255, 150), Grad = { Color3.fromRGB(40, 46, 54), Color3.fromRGB(20, 22, 28) } },
	BubbleDonut = { Bg = Color3.fromRGB(255, 190, 215), Text = Color3.fromRGB(110, 40, 70), Grad = { Color3.fromRGB(255, 214, 230), Color3.fromRGB(240, 160, 196) } },
	BubbleNight = { Bg = Color3.fromRGB(30, 36, 80), Text = Color3.fromRGB(230, 236, 255), Grad = { Color3.fromRGB(48, 56, 120), Color3.fromRGB(20, 24, 56) } },
	BubbleCloud = { Bg = Color3.fromRGB(220, 240, 255), Text = Color3.fromRGB(40, 70, 110), Grad = { Color3.fromRGB(240, 250, 255), Color3.fromRGB(196, 226, 255) } },
	BubbleFlower = { Bg = Color3.fromRGB(226, 248, 214), Text = Color3.fromRGB(70, 100, 50), Grad = { Color3.fromRGB(240, 255, 232), Color3.fromRGB(255, 214, 230) } },
	BubbleCrown = { Bg = Color3.fromRGB(255, 214, 110), Text = Color3.fromRGB(90, 60, 10), Grad = { Color3.fromRGB(255, 232, 150), Color3.fromRGB(230, 170, 60) } },
}
local L = {
	Remote = "SetBubble",
	Corner = 0.35, -- UICorner scale (the code look)
	GapPad = 0.1, -- s over the server's rate limit
	Slice = Rect.new(64, 64, 448, 448), -- the 9-slice centre of a 512 art bubble (image dev's parts)
}
local S = { LastAt = -math.huge }

---------------------------------------------------------------------------------------------------- pure
local function passAttr()
	local p = type(Config.GamePasses) == "table" and Config.GamePasses.Bubbles
	return type(p) == "table" and p.Attr or "PassBubbles"
end

-- the skin a player shows: their BubbleOn when it is a skin, else their side's free one (nil = none: Roblox's own)
function BubbleUI.SkinOf(bubbleOn, faction)
	if type(Config.IsBubble) == "function" and Config.IsBubble(bubbleOn) then return bubbleOn end
	local free = type(Config.Bubbles) == "table" and Config.Bubbles.Free[faction] or nil
	return type(free) == "string" and free or nil
end

-- the picker's bubble row for my side: my free one first, then the pack ones; { Key, Free, Locked, Worn }
function BubbleUI.Rows(faction, hasPass, wearing)
	local rows = {}
	local bubbles = type(Config.Bubbles) == "table" and Config.Bubbles or nil
	if not bubbles then return rows end
	local mine = bubbles.Free[faction]
	local worn = BubbleUI.SkinOf(wearing, faction)
	if type(mine) == "string" then table.insert(rows, { Key = mine, Free = true, Locked = false, Worn = worn == mine }) end
	for _, key in bubbles.Order do
		if Config.BubbleSide(key) == nil then
			table.insert(rows, { Key = key, Free = false, Locked = hasPass ~= true, Worn = worn == key })
		end
	end
	return rows
end

-- the look of a skin: { Art = Config.UIArt part with an id | nil, Bg, Text, Grad }
function BubbleUI.LookOf(key)
	local parts = type(Config.UIArt) == "table" and Config.UIArt.Parts or {}
	local part = parts[key]
	local art = (type(part) == "table" and type(part.Id) == "string" and part.Id ~= "") and part or nil
	local look = LOOK[key]
	if not look then return nil end
	return { Art = art, Bg = look.Bg, Text = look.Text, Grad = look.Grad }
end

-- the BubbleChatMessageProperties for a skin (nil = Roblox's default bubble)
function BubbleUI.Props(key)
	local look = key and BubbleUI.LookOf(key) or nil
	if not look then return nil end
	local props = Instance.new("BubbleChatMessageProperties")
	props.TextColor3 = look.Text
	if look.Art then
		props.BackgroundTransparency = 1
		local img = Instance.new("ImageLabel")
		img.Image = look.Art.Id
		img.ScaleType = Enum.ScaleType.Slice
		img.SliceCenter = L.Slice
		img.BackgroundTransparency = 1
		img.Parent = props
	else
		props.BackgroundColor3 = look.Bg
		props.BackgroundTransparency = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(L.Corner, 0)
		corner.Parent = props
		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new(look.Grad[1], look.Grad[2])
		grad.Rotation = 90
		grad.Parent = props
	end
	return props
end

---------------------------------------------------------------------------------------------------- the speaker's bubble
local function onBubble(message)
	local source = message and message.TextSource
	local uid = source and source.UserId
	local p = type(uid) == "number" and Players:GetPlayerByUserId(uid) or nil
	if not p then return nil end
	return BubbleUI.Props(BubbleUI.SkinOf(p:GetAttribute("BubbleOn"), p:GetAttribute("Faction")))
end

---------------------------------------------------------------------------------------------------- picking
function BubbleUI.HasPass()
	return LocalPlayer:GetAttribute(passAttr()) == true
end

function BubbleUI.MyRows()
	return BubbleUI.Rows(LocalPlayer:GetAttribute("Faction"), BubbleUI.HasPass(), LocalPlayer:GetAttribute("BubbleOn"))
end

-- a press on a bubble cell: SetBubble (my free one = ""), once per rate gap; false = nothing sent (locked / too soon)
function BubbleUI.Pick(key, now)
	local faction = LocalPlayer:GetAttribute("Faction")
	local row = nil
	for _, r in BubbleUI.Rows(faction, BubbleUI.HasPass(), LocalPlayer:GetAttribute("BubbleOn")) do
		if r.Key == key then row = r end
	end
	if not row or row.Locked or row.Worn then return false end
	now = tonumber(now) or os.clock()
	local gap = tonumber(type(Config.RateLimits) == "table" and Config.RateLimits.SetBubble) or 0.5
	if now - S.LastAt < gap + L.GapPad then return false end
	local send = row.Free and "" or key
	local ok = pcall(function() Net.Get(L.Remote):FireServer(send) end)
	if ok then S.LastAt = now end
	return ok
end

---------------------------------------------------------------------------------------------------- lifecycle
function BubbleUI.Init(registry)
	C = registry
	local ok, err = pcall(function() TextChatService.OnBubbleAdded = onBubble end)
	if not ok then Util.Warn(TAG, "OnBubbleAdded hookup failed: " .. tostring(err)) end
end

function BubbleUI.Start() end

-- offline tests
BubbleUI._T = { LOOK = LOOK, L = L, S = S, OnBubble = onBubble }

return BubbleUI
