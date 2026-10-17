-- QuickSlots (게임성 개발 1, A23-109): runs the real Config.luau and QuickSlots.luau (tools/test_quick_slots.py) on doubles:
-- a LocalPlayer with attributes, ReplicatedStorage.Remotes (SetQuickSlot or none), the HUD's slot parts and OnQuickSlot,
-- Keybinds (Began, ActionFor, Label), VitalsUI.Request, UIKit.ArtId, Instance.new for the bag rows. Inputs: CONFIG_SOURCE,
-- QS_SOURCE. Every check is named and counted.
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
local function signal()
	local s = { Fns = {} }
	function s:Connect(fn) table.insert(self.Fns, fn) return { Disconnect = function() end } end
	function s:Fire(...) for _, fn in self.Fns do fn(...) end end
	return s
end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local function vec(x, y, z) return { X = x or 0, Y = y or 0, Z = z or 0 } end
local base = { Vector3 = { new = vec, zero = vec() }, Vector2 = { new = vec }, Color3 = { new = vec, fromRGB = vec, fromHSV = vec },
	BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), UDim2 = { fromOffset = function(x, y) return { X = x, Y = y } end,
	fromScale = function(x, y) return { X = x, Y = y } end, new = function(a, b, c, d) return { XS = a, XO = b, YS = c, YO = d } end },
	UDim = ctor("UDim"), NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"),
	NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"), ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"), CFrame = ctor("CFrame"),
	TweenInfo = ctor("TweenInfo"), Font = ctor("Font"), Enum = enum }
local cfgEnv = setmetatable(table.clone(base), { __index = getfenv() })
cfgEnv.workspace = { GetServerTimeNow = function() return 1790000000 end }
local cf = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cf, cfgEnv)
local Config = cf()

local NOW = 1000
local ATTR, ASIG = {}, {}
local PLAYER = {
	GetAttribute = function(_, k) return ATTR[k] end,
	GetAttributeChangedSignal = function(_, k) ASIG[k] = ASIG[k] or signal() return ASIG[k] end,
}
local function setAttr(k, v) ATTR[k] = v if ASIG[k] then ASIG[k]:Fire() end end
local FIRED = {}
local REMOTE = { IsA = function(_, c) return c == "RemoteEvent" end, FireServer = function(_, ...) table.insert(FIRED, { ... }) end }
local REMOTES = { Children = {} }
function REMOTES:FindFirstChild(n) return self.Children[n] end
local RS = { WaitForChild = function() return { WaitForChild = function(_, m) return m end } end,
	FindFirstChild = function(_, n) if n == "Remotes" then return REMOTES end return nil end }
local UIS = { InputBegan = signal(), GetFocusedTextBox = function() return nil end }
local made = {}
local function obj(c)
	local o = { ClassName = c, Children = {} }
	setmetatable(o, { __newindex = function(t, k, v)
		rawset(t, k, v)
		if k == "Parent" and type(v) == "table" and v.Children then table.insert(v.Children, t) end
	end })
	table.insert(made, o)
	return o
end
local env = setmetatable(table.clone(base), { __index = getfenv() })
env.game = { GetService = function(_, n)
	if n == "Players" then return { LocalPlayer = PLAYER } end
	if n == "ReplicatedStorage" then return RS end
	if n == "UserInputService" then return UIS end
	return {}
end }
env.require = function(m)
	if m == "Config" then return Config end
	return { Warn = function(...) print("WARN", ...) end, Now = function() return NOW end }
end
env.Instance = { new = obj }
env.typeof = function(v) if type(v) == "table" and v.ClassName then return "Instance" end return typeof(v) end
env.task = { spawn = function() end, wait = function() end }
local f = assert(loadstring(QS_SOURCE, "=QuickSlots"))
setfenv(f, env)
local QS = f()

local REQUESTS, HOOK, OPENED = {}, nil, nil
local function widgets()
	local out = {}
	for i = 1, 3 do
		local b = { Active = false, Attr = { Disabled = true } } -- VitalsUI switched its empty potion square off
		function b:GetAttribute(k) return self.Attr[k] end
		function b:SetAttribute(k, v) self.Attr[k] = v end
		out[i] = { Button = b, Icon = { Image = "x", ImageTransparency = 0 }, Count = { Text = "?" }, Key = { Text = "" },
			Cooldown = { Visible = true, Size = nil }, Status = { Visible = true } }
	end
	return out
end
local W = widgets()
local KEYS = { Began = signal(), ActionFor = function(input) return input.Action end, IsCapturing = function() return false end,
	Label = function(a) return ({ PotionHP = "1", PotionMP = "2", QuickSlot3 = "3" })[a] end }
QS.Init({
	VitalsUI = { Request = function(kind) table.insert(REQUESTS, kind) return true end },
	Panels = { Open = function(id, arg) OPENED = { Id = id, Arg = arg } end },
	HUD = { QuickSlots = function() return W end, OnQuickSlot = function(fn) HOOK = fn end },
	Keybinds = KEYS,
	UIKit = { ArtId = function(k) return "rbxassetid://" .. k end },
})

local function show(t) return table.concat(t, ",") end
-- pure
check(show(QS.Parse(nil)) == ",,", "no saved slots: all empty (검수 10/10: the quest row says to put a potion in)", show(QS.Parse(nil)))
check(show(QS.Parse("MP,,HP")) == "MP,,HP", "a saved 'MP,,HP' reads as it is", show(QS.Parse("MP,,HP")))
check(show(QS.Parse("Bogus,HP")) == ",HP,", "an unknown item or a missing entry is empty", show(QS.Parse("Bogus,HP")))
-- what a slot shows
setAttr("QuickSlots", "MP,HP,")
ATTR.MPPotionCount, ATTR.MPPotionReadyAt, ATTR.HPPotionCount, ATTR.HPPotionReadyAt = 4, NOW + 5, 0, 0
check(show(QS.Get()) == "MP,HP,", "Get follows the server's attribute", show(QS.Get()))
local s1 = QS.Slot(1)
check(s1.Item == "MP" and s1.Count == 4 and s1.Left == 5 and s1.Length == Config.Vitals.PotionCooldown and s1.Ready == false,
	"slot 1 (MP): its count, 5 s of cooldown left of the potion cooldown, not ready", show({ s1.Item, s1.Count, s1.Left, s1.Length }))
check(QS.Slot(2).Count == 0 and QS.Slot(2).Ready == false and QS.Slot(3).Def == nil, "no HP potions: not ready; slot 3 empty", "")
-- using
check(QS.Use(1) == true and REQUESTS[1] == "MP", "using slot 1 asks VitalsUI for the MP potion (the server checks)", REQUESTS[1])
-- 세세한 게임성 #9: an empty slot's KEY opens the bag like its button when I hold a potion (slot 1's MP: 4)
check(QS.Use(3) == true and #REQUESTS == 1 and OPENED and OPENED.Id == "Bag" and OPENED.Arg.Tab == "Use",
	"#9 an empty slot's key (I hold potions): the bag on Use, nothing drunk", #REQUESTS)
OPENED = nil
QS.Start()
check(type(HOOK) == "function", "Start hooks the HUD's slot presses (HUD.OnQuickSlot)", "")
if HOOK then HOOK(3) end
check(OPENED and OPENED.Id == "Bag" and OPENED.Arg.Tab == "Use" and OPENED.Arg.Select == "P:HP" and #REQUESTS == 1,
	"game play r6: a press on an empty slot opens the bag on Use with the HP potion picked (nothing drunk)", OPENED and OPENED.Id)
OPENED = nil
if HOOK then HOOK(2) end
check(REQUESTS[2] == "HP", "a press on slot 2 uses its HP potion", REQUESTS[2])
KEYS.Began:Fire({ Action = "PotionHP" }, false)
check(REQUESTS[3] == "MP", "key 1 (action PotionHP) uses slot 1 - whatever it holds (MP here)", REQUESTS[3])
KEYS.Began:Fire({ Action = "QuickSlot3" }, false)
KEYS.Began:Fire({ Action = "PotionMP" }, true)
check(#REQUESTS == 3, "key 3 on an empty slot and a key the game took (chat) do nothing", #REQUESTS)
-- 검수 10/10: an empty slot 1 with HP potions in the bag - key 1 drinks nothing
setAttr("QuickSlots", ",HP,")
ATTR.HPPotionCount = 3
local before = #REQUESTS
KEYS.Began:Fire({ Action = "PotionHP" }, false)
check(#REQUESTS == before, "slot 1 empty, 3 HP potions held: key 1 drinks nothing", #REQUESTS - before)
setAttr("QuickSlots", "MP,HP,")
ATTR.HPPotionCount = 0
check(QS.OwnsKeys() == true, "VitalsUI leaves its potion keys to the quick slots while they run", "")
-- what the HUD's slots show
QS.Refresh()
check(W[1].Icon.Image == "rbxassetid://IconPotionMP" and W[1].Count.Text == "4" and W[1].Key.Text == "1",
	"slot 1 shows the MP icon, its count 4 and the key 1", show({ W[1].Icon.Image, W[1].Count.Text, W[1].Key.Text }))
check(W[1].Cooldown.Visible == true and W[1].Cooldown.Size and math.abs(W[1].Cooldown.Size.YS - 5 / Config.Vitals.PotionCooldown) < 1e-6,
	"its cooldown fills the part of the slot still waiting (from the bottom)", W[1].Cooldown.Size and W[1].Cooldown.Size.YS)
check(W[2].Icon.ImageTransparency == 0 and W[2].Count.Text == "0" and W[2].Count.TextColor3 ~= nil and W[1].Count.TextColor3 ~= W[2].Count.TextColor3,
	"game play r8: no HP potions - the icon stays clear, only the count 0 turns gray", W[2].Icon.ImageTransparency)
check(W[3].Icon.Image == "" and W[3].Count.Text == "" and W[3].Cooldown.Visible == false and W[3].Key.Text == "3",
	"an empty slot is blank (its key badge stays)", show({ W[3].Icon.Image, W[3].Count.Text }))
check(W[1].Status.Visible == false, "no status word over the slots", "")
check(W[2].Button.Active == true and W[2].Button.Attr.Disabled == false and W[3].Button.Active == true,
	"game play r8: every slot pressable again (VitalsUI's off switch undone; an empty slot opens the bag)", "")
-- putting items in slots
check(QS.Set(3, "MP") == true and show(QS.Get()) == ",HP,MP", "no server yet: MP into slot 3 moves it there (slot 1 empties)", show(QS.Get()))
check(QS.Set(4, "HP") == false and QS.Set(1, "Bogus") == false, "a slot outside 1-3 or an unknown item is refused", "")
REMOTES.Children.SetQuickSlot = REMOTE
check(QS.Set(1, "HP") == true and FIRED[1] and FIRED[1][1] == 1 and FIRED[1][2] == "HP" and show(QS.Get()) == "HP,,MP",
	"with the server: SetQuickSlot(1, 'HP') goes out and shows at once (HP swaps out of slot 2)", show(QS.Get()))
setAttr("QuickSlots", "HP,MP,")
check(show(QS.Get()) == "HP,MP,", "the server's answer (attribute) takes over", show(QS.Get()))
-- the bag's quick items rows
local parent = obj("Frame")
local KIT = { Font = "f", Theme = { Text = "t", Gold = "gold" }, Palette = { Button = "button", DarkText = "dark" },
	NextOrder = function() return 1 end, Rebuild = function() end,
	Button = function(p, text, color, size, onClick) local b = obj("TextButton") b.Text = text b.Color = color b.OnClick = onClick b.Parent = p return b end }
local n = QS.BagRows(parent, KIT)
local rows = parent.Children
check(n == 2 and #rows == 2 and rows[1].Name == "QuickItem_HP" and rows[2].Name == "QuickItem_MP", "the bag lists the two potions as quick items", n)
local function buttons(row) local out = {} for _, c in row.Children do if c.ClassName == "TextButton" then table.insert(out, c) end end return out end
local hpB, mpB = buttons(rows[1]), buttons(rows[2])
check(#hpB == 3 and hpB[1].Color == "gold" and hpB[2].Color == "button" and mpB[2].Color == "gold",
	"each row has [1] [2] [3]; the slot it is in is lit (HP 1, MP 2)", #hpB)
FIRED = {}
mpB[3].OnClick()
check(FIRED[1] and FIRED[1][1] == 3 and FIRED[1][2] == "MP", "a press on MP's [3] puts it in slot 3", FIRED[1] and show(FIRED[1]))
setAttr("QuickSlots", "HP,,MP")
FIRED = {}
local p2 = obj("Frame")
QS.BagRows(p2, KIT)
buttons(p2.Children[1])[1].OnClick()
check(FIRED[1] and FIRED[1][1] == 1 and FIRED[1][2] == "", "a press on the lit slot takes the item out (empty)", FIRED[1] and show(FIRED[1]))
-- 최종 검수 10/18: the rematch King fight - the potion slot shines once when my HP first goes under 40%
local king = {}
check(QS.KingWarnDue(king, nil, 39, 100) == true, "rematch King out, HP 39 / 100: the potion slot shines")
check(QS.KingWarnDue(king, nil, 40, 100) == false and QS.KingWarnDue(king, nil, 0, 100) == false,
	"HP 40 (not under 40%) or 0 (KO): nothing")
check(QS.KingWarnDue(king, king, 10, 100) == false, "once per King (that fight warned already)")
check(QS.KingWarnDue(nil, nil, 10, 100) == false and QS.KingWarnDue({}, king, 10, 100) == true,
	"no King: nothing; a new King (a new fight): again")
print(("QUICK_SLOTS_SUMMARY checks=%d failed=%d"):format(checks, failed))
