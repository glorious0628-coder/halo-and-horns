-- ③-2 망치질 고리 화면 (게임성 개발 4, 2026-10-12): runs the real Config.luau, CraftMini.luau and CraftView.luau
-- (tools/test_craft_view.py) on doubles: a recording Instance tree, the craft remotes, UserInputService.JumpRequest, a Humanoid, RunService,
-- a server clock the test moves. Inputs: CONFIG_SOURCE, MINI_SOURCE, VIEW_SOURCE.
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
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vmt) end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local base = { Vector3 = { new = vec, zero = vec(0, 0, 0) }, Vector2 = { new = vec },
	Color3 = { new = vec, fromRGB = vec, fromHSV = vec }, BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"),
	UDim2 = ctor("UDim2"), UDim = ctor("UDim"), NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"),
	ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"),
	ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"), CFrame = ctor("CFrame"), TweenInfo = ctor("TweenInfo"),
	Font = ctor("Font"), Enum = enum }
local cfgEnv = setmetatable(table.clone(base), { __index = getfenv() })
cfgEnv.workspace = { GetServerTimeNow = function() return 1790000000 end }
local cf = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cf, cfgEnv)
local Config = cf()
local CraftMini = assert(loadstring(MINI_SOURCE, "=CraftMini"))()

-- an Instance tree double
local omt = {}
local function signal()
	local s = { Fns = {} }
	function s:Connect(f)
		table.insert(self.Fns, f)
		local rec = { Live = true }
		function rec:Disconnect() self.Live = false end
		rec.Fn = f
		self.Recs = self.Recs or {}
		table.insert(self.Recs, rec)
		return rec
	end
	function s:Fire(...)
		for k, f in self.Fns do
			local rec = self.Recs and self.Recs[k]
			if not rec or rec.Live then f(...) end
		end
	end
	return s
end
local function newObj(class, props)
	local o = setmetatable({ __p = { ClassName = class, Name = class, Children = {}, Visible = true } }, omt)
	for k, v in props or {} do o[k] = v end
	return o
end
omt.__index = function(o, k)
	local p = rawget(o, "__p")
	local m = {
		GetChildren = function(self) return table.clone(rawget(self, "__p").Children) end,
		FindFirstChild = function(self, name)
			for _, ch in rawget(self, "__p").Children do if ch.Name == name then return ch end end
			return nil
		end,
		IsA = function(self, c) return rawget(self, "__p").ClassName == c end,
		Destroy = function(self)
			local pp = rawget(self, "__p")
			if pp.Parent then
				local kids = rawget(pp.Parent, "__p").Children
				local i = table.find(kids, self)
				if i then table.remove(kids, i) end
			end
			pp.Parent, pp.Destroyed = nil, true
		end,
	}
	if m[k] then return m[k] end
	if k == "Activated" or k == "OnClientEvent" then
		p[k] = p[k] or signal()
		return p[k]
	end
	return p[k]
end
omt.__newindex = function(o, k, v)
	local p = rawget(o, "__p")
	if k == "Parent" then
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
local function find(root, name)
	local function walk(x)
		for _, ch in rawget(x, "__p").Children do
			if ch.Name == name then return ch end
			local f = walk(ch)
			if f then return f end
		end
		return nil
	end
	return walk(root)
end

local NOW = 5000
local CLOCK = 100
local fired = {}
local remotes = newObj("Folder", { Name = "Remotes" })
for _, n in { "CraftStrike", "CraftFinish", "CraftSession", "CraftResult" } do
	local r = newObj("RemoteEvent", { Name = n })
	r.FireServer = function(self, ...) table.insert(fired, { self.Name, ... }) end
	r.Parent = remotes
end
local attrSig = {}
local attrs = { Class = "Warrior", Faction = "Halo" }
local jumpOn = true -- the Humanoid's Jumping state
local hum = { SetStateEnabled = function(_, st, on) if st == "HumanoidStateType.Jumping" then jumpOn = on end end }
local player = {
	Character = { FindFirstChildOfClass = function(_, c) if c == "Humanoid" then return hum end return nil end },
	GetAttribute = function(_, k) return attrs[k] end,
	SetAttribute = function(_, k, v) attrs[k] = v; if attrSig[k] then attrSig[k]:Fire() end end,
	GetAttributeChangedSignal = function(_, k) attrSig[k] = attrSig[k] or signal() return attrSig[k] end,
}
local UIS = { JumpRequest = signal() }
local function liveJumps()
	local n = 0
	for _, r in UIS.JumpRequest.Recs or {} do if r.Live then n += 1 end end
	return n
end
local stepped = signal()
local studio = true
local shared = { WaitForChild = function(_, n) return n end }
local RS = { WaitForChild = function(_, n) if n == "Remotes" then return remotes end return shared end,
	FindFirstChild = function(_, n) if n == "Remotes" then return remotes end return nil end }
local game = { GetService = function(_, n)
	if n == "Players" then return { LocalPlayer = player } end
	if n == "ReplicatedStorage" then return RS end
	if n == "RunService" then return { RenderStepped = stepped, IsStudio = function() return studio end } end
	if n == "UserInputService" then return UIS end
	return nil
end }
local sounds, shakes = {}, 0
local gui = newObj("ScreenGui", { Name = "MainGui" })
local UIKit = {
	Gui = gui,
	StyleText = function(l, s) l.Style = s end,
	Tx = function(t, key, ...)
		local s = t[key .. "En"] or t[key]
		if type(s) ~= "string" then return "" end
		if select("#", ...) > 0 then return string.format(s, ...) end
		return s
	end,
	ArtTextButton = function(part, props, onClick)
		local b = newObj("TextButton", { Name = props.Name, Text = props.Text, Part = part })
		b.Activated:Connect(onClick)
		return b
	end,
}
local Fx = { PlaySound = function(n) table.insert(sounds, n) end, Shake = function() shakes += 1 end }
local env = setmetatable(table.clone(base), { __index = getfenv() })
env.game = game
env.workspace = { GetServerTimeNow = function() return NOW end }
env.os = setmetatable({ clock = function() return CLOCK end }, { __index = os })
env.task = { spawn = function() end, defer = function(f, ...) f(...) end }
env.typeof = function(v) if type(v) == "table" and rawget(v, "__p") then return "Instance" end return type(v) end
env.Instance = { new = function(c) return newObj(c) end }
env.require = function(n)
	if n == "Config" then return Config end
	if n == "CraftMini" then return CraftMini end
	if n == "Util" then return { Warn = function(...) print("WARN", ...) end, Now = function() return NOW end } end
	if n == "L10n" then return { Register = function(_, t) return t end } end
	return nil
end
local vf = assert(loadstring(VIEW_SOURCE, "=CraftView"))
setfenv(vf, env)
local View = vf()
local panelsOpen, panelsClosed = true, 0
local Panels = { IsOpen = function() return panelsOpen end, Close = function() panelsOpen = false; panelsClosed += 1 end }
View.Init({ UIKit = UIKit, Fx = Fx, Panels = Panels })
View.Start()

local sessionR = find(remotes, "CraftSession")
local resultR = find(remotes, "CraftResult")
check(#sessionR.OnClientEvent.Fns == 1 and #resultR.OnClientEvent.Fns == 1, "CraftSession and CraftResult are bound at Init")

-- 1. a server session opens the ring screen
local START = NOW + 0.8
sessionR.OnClientEvent:Fire({ Id = 7, Recipe = "W3", Strikes = 5, Ring = 1.2, Rest = 0.35, StartAt = START })
check(View.IsOpen() and find(gui, "CraftRing") ~= nil, "a CraftSession opens the ring screen")
check(panelsClosed == 1 and not panelsOpen, "the open window (the craft window) closes under the ring screen (UiSandbox 10/12)")
check(jumpOn == false, "jumping is off while the ring is open (Space / A / the jump button never jump)")
check(liveJumps() == 1, "the jump request is listened to (it is the strike; no fixed key, BB1)")
local root = find(gui, "CraftRing")
check(root.ClassName == "TextButton" and root.Size ~= nil, "the screen itself is the button (clicks / taps never reach the HUD)")
-- 2. presses
fired = {}
NOW = START - 0.5
check(View.Press(NOW) == nil and #fired == 0, "a press before the first ring does nothing")
local T1 = CraftMini.Target(START, 1)
check(View.Press(T1 + 0.04) == "Perfect", "a press 40 ms after the touch = Perfect", "")
check(#fired == 1 and fired[1][1] == "CraftStrike" and fired[1][2] == 7 and fired[1][3] == 1 and fired[1][4] == 40,
	"CraftStrike(Id, 1, 40) goes out", fired[1] and table.concat({ tostring(fired[1][2]), tostring(fired[1][3]), tostring(fired[1][4]) }, ","))
check(View.Press(T1 + 0.1) == nil and #fired == 1, "one strike per ring")
check(find(root, "Dot1").BackgroundColor3 == View._T.V.Colors.Perfect and find(root, "Grade").Text == "Perfect",
	"dot 1 turns Perfect, the word pops")
check(sounds[#sounds] == "HammerPerfect" and shakes == 1, "Perfect: its sound + a small shake")
-- (the jump request strikes the live ring: tested on a fresh session below)
-- the rest between rings
check(View.Press(CraftMini.Closes(START, 1) + 0.05) == nil, "a press in the rest is ignored")
-- ring 2 nobody presses -> Miss when it closes
View.Step(CraftMini.Closes(START, 2) + 0.01)
check(View._T.S.Grades[2] == "Miss" and #fired == 1, "a ring nobody pressed turns Miss (no strike sent)")
-- ring 3 late
local T3 = CraftMini.Target(START, 3)
check(View.Press(T3 + 0.2) == "Good" and fired[#fired][3] == 3 and fired[#fired][4] == 200, "200 ms late = Good, CraftStrike(Id, 3, 200)")
-- ring 4 pressed the moment it appears (1.2 s early): a Miss here, nothing sent (the server refuses |ms| > 400)
local sentBefore = #fired
check(View.Press(CraftMini.Appear(START, 4) + 0.05) == "Miss" and #fired == sentBefore, "a press far too early = Miss, not sent", #fired - sentBefore)
-- the ring's size follows the schedule
local T5a = CraftMini.Appear(START, 5)
View.Step(T5a + 0.6)
local ring = find(root, "Ring")
check(ring.Visible and math.abs(ring.Size.Args[1] - 120 * 1.8) < 0.01, "half way: the ring is 1.8x the target", ring.Size.Args[1])
View.Step(CraftMini.Target(START, 5))
check(math.abs(find(root, "Ring").Size.Args[1] - 120) < 0.01, "at the touch: the ring is the target's size")
-- the end: Finish once
View.Step(CraftMini.Ends(START) + 0.01)
local finishes = 0
for _, f in fired do if f[1] == "CraftFinish" then finishes += 1 end end
check(finishes == 1, "after the last ring: CraftFinish(Id) once", finishes)
View.Step(CraftMini.Ends(START) + 0.2)
finishes = 0
for _, f in fired do if f[1] == "CraftFinish" then finishes += 1 end end
check(finishes == 1, "never twice", finishes)
find(root, "Skip").Activated:Fire() -- Skip pressed while waiting for the result
finishes = 0
for _, f in fired do if f[1] == "CraftFinish" then finishes += 1 end end
check(finishes == 1, "Skip after the end sends no second Finish", finishes)
check(fired[#fired][2] == 7 and #fired[#fired] == 2, "CraftFinish carries the Id only")
-- 3. the result
resultR.OnClientEvent:Fire({ Id = 99, Plus = 2, Kind = "Weapon", Tier = 3 })
check(find(root, "Result").Text == "", "a result for another session is ignored")
resultR.OnClientEvent:Fire({ Id = 7, Plus = 1, Kind = "Weapon", Tier = 3, Grades = {} })
check(find(root, "Result").Text == "+1 " .. Config.WeaponName(3, "Warrior", "Halo"), "the one result line", find(root, "Result").Text)
check(find(root, "Skip").Visible == false and sounds[#sounds] == "CraftDone", "Skip hides, the done sound")
check(find(root, "Bless") and find(root, "Bless").Text == "", "no Blessed line on a plain craft")
CLOCK += 2
View.Step(NOW)
check(not View.IsOpen() and root.Destroyed and jumpOn == true and liveJumps() == 0, "it closes after the result (jumping back on)")
-- 4. Skip online = Finish now
fired = {}
CLOCK += 1
NOW = 6000
sessionR.OnClientEvent:Fire({ Id = 8, StartAt = NOW + 0.8 })
find(find(gui, "CraftRing"), "Skip").Activated:Fire()
check(#fired == 1 and fired[1][1] == "CraftFinish" and fired[1][2] == 8, "Skip = CraftFinish now (+0 on the server)")
check(View.IsOpen(), "it waits for the result")
CLOCK += 7
View.Step(NOW + 1)
check(not View.IsOpen(), "no result: it closes after a few seconds (the server finishes it anyway)")
-- 5. Studio practice: no server, graded here
fired = {}
NOW = 7000
player:SetAttribute("CraftPractice", true)
check(View.IsOpen() and attrs.CraftPractice == nil, "Studio: CraftPractice opens a local session (the flag clears)")
local PS = NOW + CraftMini.T.Lead
for i = 1, 5 do View.Press(CraftMini.Target(PS, i) + 0.04) end
View.Step(CraftMini.Ends(PS) + 0.01)
check(#fired == 0, "practice sends nothing")
local pr = find(find(gui, "CraftRing"), "Result")
check(pr and pr.Text == "+2", "practice: 5 Perfect = +2 shown", pr and pr.Text)
CLOCK += 2
View.Step(NOW)
check(not View.IsOpen(), "practice closes too")
NOW = 8000
player:SetAttribute("CraftPractice", true)
find(find(gui, "CraftRing"), "Skip").Activated:Fire()
check(not View.IsOpen(), "practice Skip just closes")
-- 6. a click on the screen is a press
NOW = 9000
sessionR.OnClientEvent:Fire({ Id = 9, StartAt = NOW - CraftMini.T.Ring + 0.03 }) -- ring 1 touches 30 ms from now
find(gui, "CraftRing").Activated:Fire()
check(View._T.S.Grades[1] ~= nil and fired[#fired][1] == "CraftStrike", "a click / tap on the screen is the strike", View._T.S.Grades[1])
View.Close()
check(jumpOn == true and liveJumps() == 0, "Close turns jumping back on and stops listening")
-- the jump key is a strike (once per press: a held key repeats its request)
NOW = 9500
fired = {}
sessionR.OnClientEvent:Fire({ Id = 10, StartAt = NOW - CraftMini.T.Ring + 0.02 })
UIS.JumpRequest:Fire()
UIS.JumpRequest:Fire()
local strikes = 0
for _, f in fired do if f[1] == "CraftStrike" then strikes += 1 end end
check(View._T.S.Grades[1] ~= nil and strikes == 1, "a jump request is one strike (repeats within 0.2 s ignored)", strikes)
-- the key still held when ring 2 appears (its request repeats within 0.2 s): ring 2 is not struck by it
NOW = CraftMini.Appear(NOW - CraftMini.T.Ring + 0.02, 2) + 0.05
UIS.JumpRequest:Fire()
check(View._T.S.Grades[2] == nil, "a held jump key does not strike the next ring as it appears", View._T.S.Grades[2])
View.Close()
UIS.JumpRequest:Fire()
check(#fired == 1, "after Close a jump request does nothing", #fired)

-- 7. the approved art once its keys exist (디자인 검수 10/12): CraftTarget + CraftIngot inside it + CraftRing
check(find(gui, "Target") == nil, "")
UIKit.ArtImage = function(name, props)
	local o = newObj("ImageLabel", { Image = name })
	for k, v in props do if k ~= "Parent" then o[k] = v end end
	return o
end
NOW = 10000
player:SetAttribute("CraftPractice", true)
local scr = find(gui, "CraftRing")
check(find(scr, "Target").Image == "CraftTarget" and find(find(scr, "Target"), "Ingot").Image == "CraftIngot"
	and find(scr, "Ring").Image == "CraftRing", "with the art: target, ingot on it, ring = the approved images")
View.Step(CraftMini.Appear(NOW + CraftMini.T.Lead, 1) + 0.6)
check(find(scr, "Ring").Visible and math.abs(find(scr, "Ring").Size.Args[1] - 120 * 1.8) < 0.01, "the art ring shrinks the same way")
View.Close()
UIKit.ArtImage = nil
-- a tamer's summon (개발 3 dev3-tamer CraftResult.Pet = { Uid, Species, Spd }): the pet and the speed it was born with
NOW = 11000
sessionR.OnClientEvent:Fire({ Id = 12, StartAt = NOW + 0.8 })
resultR.OnClientEvent:Fire({ Id = 12, Plus = 2, Kind = "Pet", Grades = {}, Pet = { Uid = "P9", Species = "BabySlime", Spd = 9 } })
local petLine = find(find(gui, "CraftRing"), "Result")
check(petLine and petLine.Text == "Baby Slime +9% speed", "a summon: \"Baby Slime +9% speed\" (not \"+2\")", petLine and petLine.Text)
View.Close()
NOW = 11500
sessionR.OnClientEvent:Fire({ Id = 13, StartAt = NOW + 0.8 })
resultR.OnClientEvent:Fire({ Id = 13, Plus = 1, Kind = "Pet", Grades = {}, Pet = { Uid = "P10", Species = "Dragon", Spd = 6 } })
petLine = find(find(gui, "CraftRing"), "Result")
check(petLine and petLine.Text == "Dragon +6% speed", "a species the client does not know: its id, still one line", petLine and petLine.Text)
View.Close()
-- A23-219: a blessed Enhance Scroll craft (CraftResult.Blessed): the gold Blessed Scroll line under the result, held longer
NOW = 12000
sessionR.OnClientEvent:Fire({ Id = 14, StartAt = NOW + 0.8 })
resultR.OnClientEvent:Fire({ Id = 14, Plus = 1, Kind = "Item", Item = "Enh70", Grades = {}, Blessed = true })
local blessLine = find(find(gui, "CraftRing"), "Bless")
local firstLine = find(find(gui, "CraftRing"), "Result")
check(firstLine and firstLine.Text == "+1 Blessed Scroll 70%", "game play r8: a blessed craft's first line names the Blessed Scroll",
	firstLine and firstLine.Text)
check(blessLine and blessLine.Text == "A Blessed Scroll! (70%: +2)", "a blessed craft: the Blessed Scroll line (%% read as %)",
	blessLine and blessLine.Text)
CLOCK += 2
View.Step(NOW)
check(View.IsOpen(), "a blessed result stays past the plain 1.6 s")
CLOCK += 1
View.Step(NOW)
check(not View.IsOpen(), "and closes after 2.8 s")

print(string.format("CRAFT_VIEW_SUMMARY checks=%d failed=%d", checks, failed))
