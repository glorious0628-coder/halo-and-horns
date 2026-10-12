-- A23-143 chat stickers (StickerUI, 게임성 개발 1, 2026-10-13): runs the real Config.luau and the real StickerUI.luau
-- (tools/test_sticker_ui.py) on small doubles: Players (LocalPlayer attributes, other players' heads), a recording
-- Instance tree, UIKit art doubles, Net (the SendSticker remote, the Fx event), Keybinds, Panels, TweenService, task.
-- Inputs: CONFIG_SOURCE, UI_SOURCE. Every check is named.
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
local attrs = { PassStickers = false }
local attrSig = {}
local function signal()
	local s = { fns = {} }
	function s.Connect(_, f) table.insert(s.fns, f) return { Disconnect = function() end } end
	function s.Fire(_, ...) for _, f in s.fns do f(...) end end
	return s
end
local pg = newObj("PlayerGui")
local myHead = newObj("Part", { Name = "Head" })
local myChar = newObj("Model", { Name = "Me" })
myHead.Parent = myChar
local player = { UserId = 7, Character = myChar,
	GetAttribute = function(_, k) return attrs[k] end,
	FindFirstChildOfClass = function(_, c) if c == "PlayerGui" then return pg end return nil end,
	GetAttributeChangedSignal = function(_, k) attrSig[k] = attrSig[k] or signal() return attrSig[k] end }
local otherHead = newObj("Part", { Name = "Head" })
local otherChar = newObj("Model", { Name = "Other" })
otherHead.Parent = otherChar
local other = { UserId = 9, Character = otherChar }
local removing = signal()
local Players = { LocalPlayer = player, PlayerRemoving = removing,
	GetPlayerByUserId = function(_, id) if id == 7 then return player elseif id == 9 then return other end return nil end }
local fired, fx = {}, signal()
local remotes = { SendSticker = { FireServer = function(_, k) table.insert(fired, k) end }, Fx = { OnClientEvent = fx } }
local Net = { Get = function(n) return remotes[n] end }
local ALIVE = true
local Util = { Warn = function() end, IsAlive = function() return ALIVE end }
local tweens = 0
local TweenService = { Create = function() return { Play = function() tweens += 1 end } end }
local delays = {}
local shared = { WaitForChild = function(_, n) return n end }
local RS = { WaitForChild = function() return shared end }
local UIS = { GetFocusedTextBox = function() return nil end }
local game = { GetService = function(_, n)
	if n == "Players" then return Players elseif n == "ReplicatedStorage" then return RS elseif n == "TweenService" then return TweenService
	elseif n == "UserInputService" then return UIS end
	return nil
end }
local mods = { Config = Config, Net = Net, Util = Util }
local env = setmetatable(table.clone(base), { __index = getfenv() })
env.game, env.Instance = game, Instance
env.require = function(n) return mods[n] end
env.os = setmetatable({ clock = function() return CLOCK end }, { __index = os })
env.task = { spawn = function(f, ...) f(...) end, defer = function(f, ...) f(...) end,
	delay = function(t, f, ...) table.insert(delays, { T = t, F = f, A = { ... } }) end }
local function runDelays()
	while #delays > 0 do
		local d = table.remove(delays, 1)
		d.F(table.unpack(d.A))
	end
end

local gui = newObj("ScreenGui", { Name = "MainGui" })
local UIKit = { Gui = gui,
	ArtImage = function(name, props)
		if not Config.UIArt.Parts[name] then return nil end
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
local Keybinds = { Began = began, IsCapturing = function() return false end,
	ActionFor = function(input) return input.Action end }
local opened = {}
local Panels = { Open = function(id) table.insert(opened, id) return true end }
local C = { UIKit = UIKit, Keybinds = Keybinds, Panels = Panels }

local f = assert(loadstring(UI_SOURCE, "=StickerUI"))
setfenv(f, env)
local M = f()
M.Init(C)
M.Start()

------------------------------------------------------------------ 1. pure
local order = Config.Stickers.Order
local rows = M.Rows(false)
local free, locked = {}, 0
for _, r in rows do
	if r.Free then table.insert(free, r.Key) end
	if r.Locked then locked += 1 end
end
check(#rows == 18 and #order == 18, "Rows: the 18 stickers in Config.Stickers.Order", #rows)
check(table.concat(free, ",") == "EmoThumbsUp,EmoQuestion,EmoExclaim,EmoHelp,EmoThanks" and locked == 13,
	"Rows: 5 free (ThumbsUp / Question / Exclaim / Help / Thanks), 13 locked without the pass", table.concat(free, ","))
local opened2 = 0
for _, r in M.Rows(true) do if not r.Locked then opened2 += 1 end end
check(opened2 == 18, "Rows: the pass opens all 18", opened2)
check(M.CanSend("EmoThumbsUp", { Pass = false, Now = 10, Alive = true }) == true, "CanSend: a free one without the pass")
check(M.CanSend("EmoHeart", { Pass = false, Now = 10 }) == false and M.CanSend("EmoHeart", { Pass = true, Now = 10 }) == true,
	"CanSend: a pack one only with the pass")
check(M.CanSend("EmoOuch", { Pass = true, Now = 10 }) == false and M.CanSend("Hello", { Pass = true, Now = 10 }) == false,
	"CanSend: never a key outside the list (the monsters' pain stickers, words)")
check(M.CanSend("EmoThumbsUp", { Now = 10, LastAt = 9 }) == false and M.CanSend("EmoThumbsUp", { Now = 12.2, LastAt = 10 }) == true,
	"CanSend: at most every RateLimits.SendSticker s (+ a little)", Config.RateLimits.SendSticker)
check(M.CanSend("EmoThumbsUp", { Now = 10, Alive = false }) == false, "CanSend: not while dead")

------------------------------------------------------------------ 2. send
CLOCK = 100
check(M.Send("EmoHeart") == false and #fired == 0, "Send: a locked one sends nothing")
check(M.Send("EmoThumbsUp") == true and fired[1] == "EmoThumbsUp", "Send: a free one fires SendSticker(key) once", fired[1])
CLOCK = 101
check(M.Send("EmoQuestion") == false and #fired == 1, "Send: a second within the gap sends nothing", #fired)
CLOCK = 103
attrs.PassStickers = true
check(M.Send("EmoHeart") == true and fired[2] == "EmoHeart", "Send: the pass sends a pack one", fired[2])
attrs.PassStickers = false
ALIVE = false
CLOCK = 110
check(M.Send("EmoThumbsUp") == false and #fired == 2, "Send: nothing while dead")
ALIVE = true

------------------------------------------------------------------ 3. over the head (Fx "Sticker")
fx:Fire("Sticker", { UserId = 9, Key = "EmoCrown" })
local bb = find(pg, "PlayerSticker")
check(bb ~= nil and bb.Adornee == otherHead and find(bb, "Art") ~= nil and find(bb, "Art").Image == "EmoCrown",
	"Fx Sticker: that player's head gets the art over it", bb and bb.Adornee and bb.Adornee.Name)
fx:Fire("Sticker", { UserId = 9, Key = "EmoGG" })
local count = 0
for _, d in descendants(pg) do if d.Name == "PlayerSticker" then count += 1 end end
check(count == 1 and find(pg, "Art").Image == "EmoGG", "Fx Sticker: a new one replaces the old (one per player)", count)
fx:Fire("Sticker", { UserId = 9, Key = "EmoOuch" })
fx:Fire("Boom", { UserId = 9, Key = "EmoHeart" })
fx:Fire("Sticker", { UserId = "9", Key = "EmoHeart" })
check(find(pg, "Art").Image == "EmoGG", "Fx Sticker: other kinds, keys outside the list, a bad id are ignored")
runDelays()
check(find(pg, "PlayerSticker") == nil, "Fx Sticker: gone after Config.Stickers.Seconds (+ the fade)")
fx:Fire("Sticker", { UserId = 9, Key = "EmoHeart" })
removing:Fire(other)
check(find(pg, "PlayerSticker") == nil, "a leaving player's sticker goes with them")

------------------------------------------------------------------ 4. the picker
check(M.IsOpen() == false, "the picker starts closed")
began:Fire({ Action = "Stickers" }, false)
local picker = find(gui, "StickerPicker")
check(M.IsOpen() and picker ~= nil and picker.Visible == true and picker.Image == "PanelCard",
	"the Stickers key opens the picker (the PanelCard art)")
local cells = picker and findAll(picker, "^Sticker_Emo") or {}
check(#cells == 18 and cells[1].Image == "SlotCommon", "the picker: 18 SlotCommon cells", #cells)
local heart = picker and find(picker, "Sticker_EmoHeart")
local thumbs = picker and find(picker, "Sticker_EmoThumbsUp")
check(heart and thumbs and find(heart, "Lock").Visible == true and find(heart, "Art").ImageTransparency > 0
	and find(thumbs, "Lock").Visible == false and find(thumbs, "Art").ImageTransparency == 0,
	"the picker: a pack one dimmed with the lock, a free one bright")
if heart then heart.OnClick() end
check(M.IsOpen() == false and opened[#opened] == "Shop", "a locked one opens the Shop (the pass card) instead of sending", opened[#opened])
began:Fire({ Action = "Stickers" }, false)
CLOCK = 200
local before = #fired
if picker then find(picker, "Sticker_EmoThanks").OnClick() end
check(#fired == before + 1 and fired[#fired] == "EmoThanks" and M.IsOpen() == false, "an open one sends and closes the picker")
began:Fire({ Action = "Stickers" }, true)
check(M.IsOpen() == false, "a key the game already used (typing) does nothing")
attrs.PassStickers = false
began:Fire({ Action = "Stickers" }, false) -- open, still locked
attrs.PassStickers = true -- bought while it is open
if attrSig.PassStickers then attrSig.PassStickers:Fire() end
check(picker and find(find(picker, "Sticker_EmoHeart"), "Lock").Visible == false, "the pass bought: unlocked at once")
began:Fire({ Action = "Stickers" }, false)
check(M.IsOpen() == false, "the key again closes it")

print(("STICKER_UI_SUMMARY checks=%d failed=%d"):format(checks, failed))
