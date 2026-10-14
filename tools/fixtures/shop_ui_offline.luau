-- Offline checks for ShopUI.luau (plan 10/13 §1-A #6: the Sticker / Bubble Pack cards, the words from Config.PassInfo,
-- [Buy] following the live switch PassSales, a locked sticker's { Focus = kind }) with the real Config.luau and Util.luau.
-- The runner (tools/test_shop_ui.py) prepends CONFIG_SOURCE, UTIL_SOURCE and SHOP_SOURCE. Roblox is replaced by small
-- doubles: Instance-like tables, a Panels double (Register), a window kit double (Button / Paint / SetEnabled / Toast /
-- Text), UIKit art doubles, MarketplaceService recording the prompts, GameState's attributes and the player's.
local checks, failed = 0, 0
local function check(name, ok, detail)
	checks += 1
	if not ok then
		failed += 1
		print(("CHECK_FAIL %s :: %s"):format(name, tostring(detail or "")))
	end
end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local function signal()
	local s = { Fns = {} }
	function s:Connect(f) table.insert(self.Fns, f) return { Disconnect = function() end } end
	function s:Fire(...) for _, f in table.clone(self.Fns) do f(...) end end
	return s
end
local imt = {}
imt.__index = function(self, k)
	local m = rawget(imt, "methods")[k]
	if m then return m end
	if k == "Activated" then local s = signal() rawset(self, k, s) return s end
	return nil
end
imt.methods = {
	FindFirstChild = function(self, n, deep)
		for _, c in self.Children do
			if c.Name == n then return c end
			if deep then local f = c:FindFirstChild(n, true) if f then return f end end
		end
		return nil
	end,
	FindFirstChildOfClass = function(self, cl)
		for _, c in self.Children do if c.ClassName == cl then return c end end
		return nil
	end,
	SetAttribute = function(self, k, v) rawset(self, "Attr_" .. k, v) end,
	IsA = function(self, cl) return self.ClassName == cl end,
}
imt.__newindex = function(self, k, v)
	if k == "Parent" then
		local old = rawget(self, "Parent")
		if old then
			local i = table.find(old.Children, self)
			if i then table.remove(old.Children, i) end
		end
		rawset(self, "Parent", v)
		if type(v) == "table" and v.Children then table.insert(v.Children, self) end
		return
	end
	rawset(self, k, v)
end
local function inst(class)
	return setmetatable({ ClassName = class, Name = class, Children = {}, Visible = true }, imt)
end
local function texts(root, out)
	out = out or {}
	for _, c in root.Children do
		if c.ClassName == "TextLabel" or c.ClassName == "TextButton" then table.insert(out, tostring(c.Text)) end
		texts(c, out)
	end
	return out
end

local CLOCK = 100
local cfgEnv = setmetatable({
	game = { GetService = function() return setmetatable({}, { __index = function() return function() return nil end end }) end },
	Vector3 = ctor("Vector3"), Vector2 = ctor("Vector2"), UDim2 = ctor("UDim2"), UDim = ctor("UDim"),
	Color3 = { new = function(...) return { ... } end, fromRGB = function(...) return { ... } end, fromHSV = function() return {} end },
	BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), NumberRange = ctor("NumberRange"),
	NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"),
	ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"), CFrame = ctor("CFrame"), Font = ctor("Font"),
	TweenInfo = { new = function(...) return { ... } end }, Enum = enum, Instance = { new = function() return {} end },
	typeof = function(v) return type(v) end, warn = function() end,
}, { __index = getfenv() })
local cfn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cfn, cfgEnv)
local Config = cfn()
local ufn = assert(loadstring(UTIL_SOURCE, "=Util"))
setfenv(ufn, setmetatable({ game = cfgEnv.game, warn = function() end, Random = { new = function() return {} end } },
	{ __index = getfenv() }))
local Util = ufn()
-- the passes the user made (test ids)
Config.GamePasses.XP2.Id, Config.GamePasses.Stickers.Id, Config.GamePasses.Bubbles.Id = 1001, 1004, 1005
Config.GamePasses.Gold2.Id = 0 -- 10/14: Config holds the real pass ids now; this card plays the pass not sold yet
Config.Looks.HaloIce.PassId = 2001

local ATTR = { Faction = "Halo", PassVIP = true, LooksOwned = "" }
local LP = { UserId = 7 }
function LP:GetAttribute(k) return ATTR[k] end
local GS = { Attrs = {} }
function GS:GetAttribute(k) return self.Attrs[k] end
local PROMPTS, TOASTS, METRICS = {}, {}, {}
local REGISTERED = {}
local function artId(name)
	local part = Config.UIArt and Config.UIArt.Parts and Config.UIArt.Parts[name]
	return type(part) == "table" and type(part.Id) == "string" and part.Id ~= "" and part.Id or nil
end
local function withProps(o, props)
	for k, v in props do if k ~= "Parent" then o[k] = v end end
	if props.Parent then o.Parent = props.Parent end
	return o
end
local C = {
	UIKit = {
		ArtId = artId,
		ArtImage = function(name, props)
			if not artId(name) then return nil end
			local img = inst("ImageLabel")
			img.Art = name
			return withProps(img, props or {})
		end,
		ArtFrame = function(name, props) local f = inst("ImageLabel") f.Art = name return withProps(f, props or {}) end,
		ButtonFeel = function() end,
		StyledLabel = function(props) local l = inst("TextLabel") return withProps(l, props) end,
	},
	Panels = { Register = function(id, opts) REGISTERED[id] = opts return true end },
	ComeBack = { Metric = function(id, arg) table.insert(METRICS, { id, arg }) end },
}
local MPS = { PromptGamePassPurchase = function(_, player, id) table.insert(PROMPTS, id) end }
local env = setmetatable({
	game = { GetService = function(_, n)
		if n == "Players" then return { LocalPlayer = LP } end
		if n == "ReplicatedStorage" then
			return { WaitForChild = function() return { WaitForChild = function(_, m) return { __module = m } end } end,
				FindFirstChild = function(_, n2) if n2 == "GameState" then return GS end return nil end }
		end
		if n == "MarketplaceService" then return MPS end
		if n == "RunService" then return { IsStudio = function() return false end } end
		return {}
	end },
	Vector2 = { new = function(x, y) return { X = x, Y = y } end },
	UDim2 = { new = function(a, b, c, d) return { a, b, c, d } end, fromScale = function(x, y) return { x, 0, y, 0 } end,
		fromOffset = function(x, y) return { 0, x, 0, y } end },
	UDim = { new = function(a, b) return { a, b } end },
	Color3 = cfgEnv.Color3,
	Enum = enum,
	Instance = { new = inst },
	os = { clock = function() return CLOCK end, time = os.time, date = os.date },
	task = { spawn = function() end, defer = function() end, delay = function() end, wait = function() end },
	workspace = { DescendantAdded = signal(), GetDescendants = function() return {} end },
	require = function(m)
		if m.__module == "Config" then return Config end
		if m.__module == "Util" then return Util end
		if m.__module == "Net" then return { Names = { "SetLook" } } end
		return {}
	end,
}, { __index = getfenv() })
local fn = assert(loadstring(SHOP_SOURCE, "=ShopUI"))
setfenv(fn, env)
local Shop = fn()
Shop.Init(C)

local W = REGISTERED.Shop
check("the Shop window is registered with its Config title", W ~= nil and W.Title == Config.PassInfo.Screen.Title, W and W.Title)
local ENABLED = {}
local order = 0
local kit = {
	Palette = { Button = "btn", Buy = "buy", Free = "free", Row = "row" }, Theme = { Bg = "bg", Gold = "gold", SubText = "sub" },
	NextOrder = function() order += 1 return order end,
	Paint = function(b, color) b.Painted = color end,
	SetEnabled = function(b, on) ENABLED[b] = on end,
	Toast = function(text) table.insert(TOASTS, text) end,
	Fire = function() end,
	Text = function(parent, text) local l = inst("TextLabel") l.Text = text l.Parent = parent return l end,
	Button = function(parent, text, color, size, onTap)
		local b = inst("TextButton")
		b.Text = text
		b.Parent = parent
		b.Activated:Connect(onTap)
		return b
	end,
}
local function build(arg)
	local root = inst("Frame")
	local update = W.Build(root, kit, arg)
	return root, update
end
local root, update = build(nil)
CLOCK += 1 -- past the window's open guard (L.Guard)
local cards = root:FindFirstChild("Passes")
local kinds = {}
for _, c in cards and cards.Children or {} do
	local k = type(c.Name) == "string" and c.Name:match("^Pass(%w+)$")
	if k then table.insert(kinds, k) end
end
check("six pass cards: 2x XP, 2x Gold, VIP, Sticker Pack, Bubble Pack, Private Server", table.concat(kinds, ",")
	== "XP2,Gold2,VIP,Stickers,Bubbles,PrivateServer", table.concat(kinds, ","))
local all = table.concat(texts(root), "|")
check("the names come from Config.GamePasses", all:find("Sticker Pack", 1, true) and all:find("Bubble Pack", 1, true)
	and all:find(Config.PassInfo.Screen.PrivateName, 1, true), all:sub(1, 120))
check("the lines come from Config.PassInfo", all:find(Config.PassInfo.Stickers.Line, 1, true)
	and all:find(Config.PassInfo.Bubbles.Line, 1, true) and all:find(Config.PassInfo.VIP.Line, 1, true))
check("no VIP emote promised (not built)", not all:lower():find("emote", 1, true))
check("the private server card says rewards are halved there (A23-90)", all:find(Config.PrivateServer.Text, 1, true) ~= nil)
local function cap(kind)
	local card = cards:FindFirstChild("Pass" .. kind)
	for _, ch in card and card.Children or {} do if ch.ClassName == "TextButton" then return ch end end
	return nil
end
check("a pass with an id: '199 R$' on, gold", cap("XP2").Text == "199 R$" and ENABLED[cap("XP2")] == true and cap("XP2").Painted == "buy",
	cap("XP2").Text)
check("the Sticker / Bubble Pack: '99 R$'", cap("Stickers").Text == "99 R$" and cap("Bubbles").Text == "99 R$")
check("a pass without an id: 'Coming soon', off", cap("Gold2").Text == "Coming soon" and ENABLED[cap("Gold2")] == false)
check("an owned pass: 'Owned'", cap("VIP").Text == "Owned")
cap("Stickers").Activated:Fire()
check("[Buy] asks Roblox for the Sticker Pack's id", PROMPTS[#PROMPTS] == 1004, PROMPTS[#PROMPTS])
-- the live switch off
GS.Attrs.SwitchPassSales = false
update()
check("PassSales off: every not-owned [Buy] reads 'Not on sale', off", cap("XP2").Text == Config.PassInfo.Screen.Off
	and ENABLED[cap("XP2")] == false and cap("Bubbles").Text == Config.PassInfo.Screen.Off and cap("VIP").Text == "Owned",
	cap("XP2").Text)
local before = #PROMPTS
cap("XP2").Activated:Fire()
check("... a press asks Roblox nothing and says why", #PROMPTS == before and TOASTS[#TOASTS] == Config.PassInfo.Screen.OffToast,
	TOASTS[#TOASTS])
check("... the private server card stays the game-page info", cap("PrivateServer").Text == string.format(Config.PassInfo.Screen.MonthF, "100"))
local look = root:FindFirstChild("Looks")
local ice = look and look:FindFirstChild("LookHaloIce")
local iceCap = nil
for _, ch in ice and ice.Children or {} do if ch.ClassName == "TextButton" then iceCap = ch end end
check("... a look with an id reads 'Not on sale' too", iceCap and iceCap.Text == Config.PassInfo.Screen.Off and ENABLED[iceCap] == false,
	iceCap and iceCap.Text)
before = #PROMPTS
if iceCap then iceCap.Activated:Fire() end
check("... and asks nothing", #PROMPTS == before)
GS.Attrs.SwitchPassSales = true
update()
check("PassSales back on: the prices return", cap("XP2").Text == "199 R$" and ENABLED[cap("XP2")] == true)
if iceCap then iceCap.Activated:Fire() end
check("... and a look's [Buy] asks Roblox for its pass", PROMPTS[#PROMPTS] == 2001, PROMPTS[#PROMPTS])
GS.Attrs.SwitchPassSales = nil
update()
check("no switch sent yet = on", cap("XP2").Text == "199 R$")
-- a locked sticker / bubble opens the Shop on its pass
root = build({ Focus = "Bubbles" })
cards = root:FindFirstChild("Passes")
local rim = cards:FindFirstChild("PassBubbles"):FindFirstChild("Focus")
check("{ Focus = 'Bubbles' }: the Bubble Pack card wears the gold rim, no other", rim and rim.ClassName == "UIStroke"
	and cards:FindFirstChild("PassStickers"):FindFirstChild("Focus") == nil and cards:FindFirstChild("PassXP2"):FindFirstChild("Focus") == nil)
root = build(nil)
cards = root:FindFirstChild("Passes")
local none = true
for _, c in cards.Children do if c.FindFirstChild and c:FindFirstChild("Focus") then none = false end end
check("opened from the menu: no rim", none)

print(("SHOP_UI_SUMMARY checks=%d failed=%d"):format(checks, failed))
if failed == 0 then print("SHOP_UI_OFFLINE_OK") end
