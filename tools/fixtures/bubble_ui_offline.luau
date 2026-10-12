-- A23-144 chat bubble skins (BubbleUI, 게임성 개발 1, 2026-10-13): runs the real Config.luau, BubbleUI.luau and
-- StickerUI.luau (tools/test_bubble_ui.py) on doubles: Players (attributes), TextChatService (OnBubbleAdded), a recording
-- Instance tree, UIKit art doubles, Net (SetBubble), Keybinds, Panels. Inputs: CONFIG_SOURCE, BUBBLE_SOURCE, STICKER_SOURCE.
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then
		print("CHECK_OK " .. name)
	else
		failed += 1
		print("CHECK_FAIL " .. name .. " :: " .. tostring(detail))
	end
end

local vmt = {}
vmt.__index = vmt
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vmt) end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local function ud(sx, ox, sy, oy) return { X = { Scale = sx or 0, Offset = ox or 0 }, Y = { Scale = sy or 0, Offset = oy or 0 } } end
local UDim2 = {
	new = function(sx, ox, sy, oy) return ud(sx, ox, sy, oy) end,
	fromOffset = function(x, y) return ud(0, x, 0, y) end,
	fromScale = function(x, y) return ud(x, 0, y, 0) end,
}
local base = { Vector3 = { new = vec, zero = vec(0, 0, 0) }, Vector2 = { new = vec },
	Color3 = { new = vec, fromRGB = vec, fromHSV = vec }, BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"),
	UDim2 = UDim2, UDim = ctor("UDim"), NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"),
	ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"),
	ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"), CFrame = ctor("CFrame"), TweenInfo = ctor("TweenInfo"),
	Font = ctor("Font"), Enum = enum }
local cfgEnv = setmetatable(table.clone(base), { __index = getfenv() })
cfgEnv.workspace = { GetServerTimeNow = function() return 1790000000 end }
local fn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(fn, cfgEnv)
local Config = fn()

------------------------------------------------------------------ an Instance tree double
local omt = {}
local function newObj(class, props)
	local o = setmetatable({ __p = { ClassName = class, Name = class, Children = {}, ZIndex = 1, CanvasPosition = vec(0, 0),
		AbsoluteSize = vec(0, 0) } }, omt)
	for k, v in props or {} do o[k] = v end
	return o
end
local ISA = {
	TextButton = { GuiButton = true, GuiObject = true }, ImageButton = { GuiButton = true, GuiObject = true },
	TextLabel = { GuiObject = true }, ImageLabel = { GuiObject = true }, Frame = { GuiObject = true },
	ScrollingFrame = { GuiObject = true },
}
omt.__index = function(o, k)
	local methods = {
		GetChildren = function(self) return table.clone(rawget(self, "__p").Children) end,
		Destroy = function(self)
			local p = rawget(self, "__p")
			if p.Parent then
				local kids = rawget(p.Parent, "__p").Children
				local i = table.find(kids, self)
				if i then table.remove(kids, i) end
			end
			p.Parent = nil
			p.Destroyed = true
		end,
		IsA = function(self, c)
			local cls = rawget(self, "__p").ClassName
			return cls == c or (ISA[cls] ~= nil and ISA[cls][c] == true)
		end,
		FindFirstChild = function(self, name)
			for _, ch in rawget(self, "__p").Children do if ch.Name == name then return ch end end
			return nil
		end,
		FindFirstChildOfClass = function(self, c)
			for _, ch in rawget(self, "__p").Children do if ch.ClassName == c then return ch end end
			return nil
		end,
	}
	if methods[k] then return methods[k] end
	return rawget(o, "__p")[k]
end
omt.__newindex = function(o, k, v)
	local p = rawget(o, "__p")
	if k == "Parent" then
		if p.Destroyed and v ~= nil then error("The Parent property of " .. tostring(p.Name) .. " is locked") end
		if p.Parent then
			local kids = rawget(p.Parent, "__p").Children
			local i = table.find(kids, o)
			if i then table.remove(kids, i) end
		end
		p.Parent = v
		if v then table.insert(rawget(v, "__p").Children, o) end
		return
	end
	p[k] = v
end
local Instance = { new = function(c) return newObj(c) end }

local function descendants(root, out)
	out = out or {}
	for _, ch in rawget(root, "__p").Children do
		table.insert(out, ch)
		descendants(ch, out)
	end
	return out
end
local function find(root, name)
	for _, d in descendants(root) do if d.Name == name then return d end end
	return nil
end
local function findAll(root, pat)
	local out = {}
	for _, d in descendants(root) do
		if type(d.Name) == "string" and string.find(d.Name, pat) then table.insert(out, d) end
	end
	return out
end

------------------------------------------------------------------ doubles
local CLOCK = 100
local attrs = { Faction = "Halo", BubbleOn = "", PassBubbles = false, PassStickers = false }
local attrSig = {}
local function signal()
	local s = { fns = {} }
	function s.Connect(_, f) table.insert(s.fns, f) return { Disconnect = function() end } end
	function s.Fire(_, ...) for _, f in s.fns do f(...) end end
	return s
end
local pg = newObj("PlayerGui")
local player = { UserId = 7,
	GetAttribute = function(_, k) return attrs[k] end,
	FindFirstChildOfClass = function(_, c) if c == "PlayerGui" then return pg end return nil end,
	GetAttributeChangedSignal = function(_, k) attrSig[k] = attrSig[k] or signal() return attrSig[k] end }
local otherAttrs = { Faction = "Horns", BubbleOn = "" }
local other = { UserId = 9, GetAttribute = function(_, k) return otherAttrs[k] end }
local Players = { LocalPlayer = player, PlayerRemoving = signal(),
	GetPlayerByUserId = function(_, id) if id == 7 then return player elseif id == 9 then return other end return nil end }
local fired = {}
local remotes = { SetBubble = { FireServer = function(_, k) table.insert(fired, k) end },
	SendSticker = { FireServer = function() end }, Fx = { OnClientEvent = signal() } }
local Net = { Get = function(n) return remotes[n] end }
local Util = { Warn = function() end, IsAlive = function() return true end }
local TCS = {}
local shared = { WaitForChild = function(_, n) return n end }
local RS = { WaitForChild = function() return shared end }
local UIS = { GetFocusedTextBox = function() return nil end }
local TweenService = { Create = function() return { Play = function() end } end }
local game = { GetService = function(_, n)
	if n == "Players" then return Players elseif n == "ReplicatedStorage" then return RS elseif n == "TextChatService" then return TCS
	elseif n == "UserInputService" then return UIS elseif n == "TweenService" then return TweenService end
	return nil
end }
local mods = { Config = Config, Net = Net, Util = Util }
local function newEnv()
	local env = setmetatable(table.clone(base), { __index = getfenv() })
	env.game, env.Instance = game, Instance
	env.require = function(n) return mods[n] end
	env.os = setmetatable({ clock = function() return CLOCK end }, { __index = os })
	env.task = { spawn = function(f, ...) f(...) end, defer = function(f, ...) f(...) end, delay = function() end }
	env.Rect = { new = function(...) return { __kind = "Rect", Args = { ... } } end }
	env.ColorSequence = { new = function(a, b) return { __kind = "ColorSequence", A = a, B = b } end }
	return env
end

local gui = newObj("ScreenGui", { Name = "MainGui" })
local UIKit = { Gui = gui,
	ArtImage = function(name, props)
		local part = Config.UIArt.Parts[name]
		if not (part and type(part.Id) == "string" and part.Id ~= "") then return nil end
		local o = newObj("ImageLabel", { Image = name, ImageTransparency = 0 })
		for k, v in props or {} do if k ~= "Parent" then o[k] = v end end
		return o
	end,
	ArtFrame = function(name, props) local o = newObj("ImageLabel", { Image = name }) for k, v in props or {} do o[k] = v end return o end,
	ArtButton = function(name, props, onClick)
		local o = newObj("ImageButton", { Image = name, OnClick = onClick })
		for k, v in props or {} do o[k] = v end
		return o
	end,
}
local began = signal()
local opened = {}
local C = { UIKit = UIKit, Keybinds = { Began = began, IsCapturing = function() return false end, ActionFor = function(i) return i.Action end },
	Panels = { Open = function(id) table.insert(opened, id) return true end } }

local bf = assert(loadstring(BUBBLE_SOURCE, "=BubbleUI"))
setfenv(bf, newEnv())
local B = bf()
C.BubbleUI = B
B.Init(C)
B.Start()
local sf = assert(loadstring(STICKER_SOURCE, "=StickerUI"))
setfenv(sf, newEnv())
local St = sf()
St.Init(C)
St.Start()

------------------------------------------------------------------ 1. pure
check(type(TCS.OnBubbleAdded) == "function", "Init hooks TextChatService.OnBubbleAdded (this module owns the callback)")
check(B.SkinOf("", "Halo") == "BubbleHalo" and B.SkinOf("BubbleNight", "Horns") == "BubbleNight" and B.SkinOf("Nope", "Horns") == "BubbleHorns"
	and B.SkinOf("", "None") == nil, "SkinOf: BubbleOn when it is a skin, else my side's free one, none without a side")
local rows = B.Rows("Halo", false, "")
local keys, locked = {}, 0
for _, r in rows do
	table.insert(keys, r.Key)
	if r.Locked then locked += 1 end
end
check(table.concat(keys, ",") == "BubbleHalo,BubblePixel,BubbleDonut,BubbleNight,BubbleCloud,BubbleFlower,BubbleCrown" and locked == 6,
	"Rows (Halo, no pack): my free one first, the 6 pack ones locked, never the other sides' free ones", table.concat(keys, ","))
check(rows[1].Worn == true and rows[2].Worn == false, "Rows: '' wears my side's free one")
local open = 0
for _, r in B.Rows("Horns", true, "BubbleCrown") do
	if not r.Locked then open += 1 end
	if r.Key == "BubbleCrown" then check(r.Worn == true, "Rows: the worn pack skin is marked") end
end
check(open == 7 and B.Rows("Horns", true, "")[1].Key == "BubbleHorns", "Rows: the pack opens all; the Horns' free one first", open)
local look = B.LookOf("BubbleHorns")
check(look and look.Art == nil and look.Bg ~= nil and look.Text ~= nil and look.Grad and look.Grad[2] ~= nil,
	"LookOf: no art uploaded = the skin's colours (background, text, gradient)")
check(B.LookOf("Nope") == nil and B.Props(nil) == nil, "LookOf / Props: an unknown skin = Roblox's own bubble")
local props = B.Props("BubbleHorns")
check(props and props.ClassName == "BubbleChatMessageProperties" and props.BackgroundColor3 == look.Bg and props.TextColor3 == look.Text
	and props:FindFirstChildOfClass("UICorner") and props:FindFirstChildOfClass("UIGradient"),
	"Props (code look): the background / text colours, round corners, a gradient")
Config.UIArt.Parts.BubbleNight = { Id = "rbxassetid://123", Size = vec(512, 512) }
local artProps = B.Props("BubbleNight")
local img = artProps and artProps:FindFirstChildOfClass("ImageLabel")
check(img and img.Image == "rbxassetid://123" and img.ScaleType == "ScaleType.Slice" and artProps.BackgroundTransparency == 1,
	"Props (art uploaded): a 9-slice ImageLabel, the plain background hidden")
Config.UIArt.Parts.BubbleNight = nil

------------------------------------------------------------------ 2. the speaker's bubble
local p9 = TCS.OnBubbleAdded({ TextSource = { UserId = 9 } })
check(p9 and p9.BackgroundColor3 == B.LookOf("BubbleHorns").Bg, "OnBubbleAdded: the speaker's skin (a Horns player, '' = the Horns free one)")
otherAttrs.BubbleOn = "BubbleCloud"
local pc = TCS.OnBubbleAdded({ TextSource = { UserId = 9 } })
check(pc and pc.BackgroundColor3 == B.LookOf("BubbleCloud").Bg, "OnBubbleAdded: their picked pack skin")
check(TCS.OnBubbleAdded({ TextSource = nil }) == nil and TCS.OnBubbleAdded({ TextSource = { UserId = 404 } }) == nil,
	"OnBubbleAdded: a system line / a gone player = Roblox's own bubble")

------------------------------------------------------------------ 3. picking
CLOCK = 100
check(B.Pick("BubbleNight") == false and #fired == 0, "Pick: a locked pack skin sends nothing")
check(B.Pick("BubbleHalo") == false and #fired == 0, "Pick: the one I wear sends nothing")
attrs.PassBubbles = true
check(B.Pick("BubbleNight") == true and fired[1] == "BubbleNight", "Pick: with the pack a skin is sent as its key", fired[1])
attrs.BubbleOn = "BubbleNight"
CLOCK = 100.3
check(B.Pick("BubbleCloud") == false and #fired == 1, "Pick: not twice within Config.RateLimits.SetBubble (+ a little)")
CLOCK = 101
check(B.Pick("BubbleHalo") == true and fired[2] == "", "Pick: back to my side's free one = SetBubble('')", fired[2])
attrs.BubbleOn = ""
attrs.PassBubbles = false

------------------------------------------------------------------ 4. the picker's bubble row (StickerUI)
began:Fire({ Action = "Stickers" }, false)
local picker = find(gui, "StickerPicker")
local halo = picker and find(picker, "Bubble_BubbleHalo")
local night = picker and find(picker, "Bubble_BubbleNight")
check(picker and #findAll(picker, "^Bubble_Bubble") == 7 and find(picker, "Bubble_BubbleHorns") == nil,
	"the picker: one bubble row of 7 (my free one + the pack's), no other side's", picker and #findAll(picker, "^Bubble_Bubble"))
check(halo and find(halo, "Worn") and find(halo, "Worn").Enabled == true and night and find(night, "Worn").Enabled == false,
	"the picker: the worn bubble is framed")
check(night and find(night, "Lock") and find(night, "Lock").Visible == true and find(halo, "Lock").Visible == false,
	"the picker: a pack bubble without the pack wears the lock")
check(night and find(night, "Art") and find(night, "Art").ClassName == "Frame" and find(night, "Art").BackgroundColor3 == B.LookOf("BubbleNight").Bg,
	"the picker: no art yet = a small bubble in the skin's colour")
if night then night.OnClick() end
check(opened[#opened] == "Shop" and #fired == 2, "the picker: a locked bubble opens the Shop, sends nothing")
began:Fire({ Action = "Stickers" }, false)
attrs.PassBubbles = true
if attrSig.PassBubbles then attrSig.PassBubbles:Fire() end
check(find(night, "Lock").Visible == false, "the picker: the pack bought = unlocked at once")
attrs.BubbleOn = "BubbleCloud" -- the server says I wear another one now (bought / picked elsewhere)
if attrSig.BubbleOn then attrSig.BubbleOn:Fire() end
check(find(halo, "Worn").Enabled == false and find(find(picker, "Bubble_BubbleCloud"), "Worn").Enabled == true,
	"the picker: the frame follows my BubbleOn at once")
attrs.BubbleOn = ""
if attrSig.BubbleOn then attrSig.BubbleOn:Fire() end
CLOCK = 120
night.OnClick()
check(fired[3] == "BubbleNight" and St.IsOpen() == false, "the picker: a bubble press sends SetBubble and closes", fired[3])

print(("BUBBLE_UI_SUMMARY checks=%d failed=%d"):format(checks, failed))
