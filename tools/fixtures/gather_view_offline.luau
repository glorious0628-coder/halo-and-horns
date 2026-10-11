-- ② 채집 화면 (게임성 개발 4, 2026-10-12): runs the real Config.luau, L10n.luau and GatherView.luau (tools/test_gather_view.py)
-- on doubles: a workspace with Map.GatherNodes (Models, a ProximityPrompt with ActionKey / ObjectKey, parts, a sparkle, a
-- light), the GatherState remote, a TextKo with one Korean entry, a UIKit language double. Inputs: CONFIG_SOURCE,
-- L10N_SOURCE, VIEW_SOURCE. The gather words come from Config.Gather.Text / Config.Loot.Items when the server branch has
-- them, else this fixture adds the contract's (gather_server_2026-10-11.md §1 / §6). Every check is named.
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
local fn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(fn, cfgEnv)
local Config = fn()
-- the contract's words when this branch's Config does not have them yet (the server branch adds them)
Config.Gather = Config.Gather or {}
Config.Gather.Text = Config.Gather.Text or { Pick = "Pick", Mine = "Mine" }
Config.Loot.Items.Herb = Config.Loot.Items.Herb or { Kind = "Material", Name = "Meadow Herb", Sell = 1 }
Config.Loot.Items.CopperOre = Config.Loot.Items.CopperOre or { Kind = "Material", Name = "Copper Ore", Sell = 2 }

------------------------------------------------------------------ an Instance tree double
local CLASS = {
	Model = {}, Folder = {}, Part = { BasePart = true }, MeshPart = { BasePart = true }, ProximityPrompt = {},
	ParticleEmitter = {}, PointLight = { Light = true }, RemoteEvent = {},
}
local omt = {}
local function newObj(class, name, props)
	local o = setmetatable({ __p = { ClassName = class, Name = name or class, Children = {}, Attr = {} } }, omt)
	for k, v in props or {} do o[k] = v end
	return o
end
local function signal()
	local s = { Fns = {} }
	function s:Connect(f) table.insert(self.Fns, f) return { Disconnect = function() end } end
	function s:Fire(...) for _, f in self.Fns do f(...) end end
	return s
end
omt.__index = function(o, k)
	local p = rawget(o, "__p")
	local m = {
		GetChildren = function(self) return table.clone(rawget(self, "__p").Children) end,
		GetDescendants = function(self)
			local out = {}
			local function walk(x)
				for _, ch in rawget(x, "__p").Children do
					table.insert(out, ch)
					walk(ch)
				end
			end
			walk(self)
			return out
		end,
		FindFirstChild = function(self, name, rec)
			for _, ch in rawget(self, "__p").Children do
				if ch.Name == name then return ch end
				if rec then
					local f = ch:FindFirstChild(name, true)
					if f then return f end
				end
			end
			return nil
		end,
		WaitForChild = function(self, name) return self:FindFirstChild(name) end,
		IsA = function(self, c)
			local cls = rawget(self, "__p").ClassName
			return cls == c or (CLASS[cls] ~= nil and CLASS[cls][c] == true)
		end,
		GetAttribute = function(self, k) return rawget(self, "__p").Attr[k] end,
		SetAttribute = function(self, k, v) rawget(self, "__p").Attr[k] = v end,
	}
	if m[k] then return m[k] end
	if k == "ChildAdded" then
		p.ChildAdded = p.ChildAdded or signal()
		return p.ChildAdded
	end
	if k == "OnClientEvent" then
		p.OnClientEvent = p.OnClientEvent or signal()
		return p.OnClientEvent
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
		if v then
			table.insert(rawget(v, "__p").Children, o)
			local added = rawget(v, "__p").ChildAdded
			if added then added:Fire(o) end
		end
		return
	end
	p[k] = v
end

local function node(id, kind, actionKey, objectKey)
	local m = newObj("Model", "Node_" .. id)
	m:SetAttribute("GatherId", id)
	m:SetAttribute("GatherKind", kind)
	local body = newObj("Part", "Body", { LocalTransparencyModifier = 0 })
	body.Parent = m
	local leaf = newObj("MeshPart", "Leaf", { LocalTransparencyModifier = 0 })
	leaf.Parent = body
	local prompt = newObj("ProximityPrompt", "GatherPrompt", { Enabled = true, ActionText = "", ObjectText = "", HoldDuration = 1.5 })
	prompt:SetAttribute("ActionKey", actionKey)
	prompt:SetAttribute("ObjectKey", objectKey)
	prompt.Parent = body
	local spark = newObj("ParticleEmitter", "Sparkle", { Enabled = true })
	spark.Parent = body
	local off = newObj("ParticleEmitter", "Dust", { Enabled = false }) -- an emitter that was off stays off
	off.Parent = body
	local light = newObj("PointLight", "Glow", { Enabled = true })
	light.Parent = body
	return m
end

local NOW = 1000
local workspaceObj = newObj("Folder", "Workspace")
workspaceObj.GetServerTimeNow = function() return NOW end
local map = newObj("Folder", "Map")
map.Parent = workspaceObj
local folder = newObj("Folder", "GatherNodes")
local remotes = newObj("Folder", "Remotes")
local stateRemote = newObj("RemoteEvent", "GatherState")
stateRemote.Parent = remotes

local KO = {}
local shared = { WaitForChild = function(_, n) return n end }
local RS = { WaitForChild = function(_, n) if n == "Remotes" then return remotes end return shared end,
	FindFirstChild = function(_, n) if n == "Remotes" then return remotes end return nil end }
local attrs = { Lang = "en" }
local player = { GetAttribute = function(_, k) return attrs[k] end, LocaleId = "en-us" }
local Util = { Warn = function(...) print("WARN", ...) end, Now = function() return NOW end }
local game = { GetService = function(_, n)
	if n == "Players" then return { LocalPlayer = player } end
	if n == "ReplicatedStorage" then return RS end
	if n == "RunService" then return { IsStudio = function() return false end, IsClient = function() return true end } end
	return nil
end }

-- the real L10n on the real Config (+ a TextKo double)
local lenv = setmetatable(table.clone(base), { __index = getfenv() })
lenv.game = game
lenv.script = { Parent = { WaitForChild = function(_, n)
	if n == "Config" then return "Config" end
	return "TextKo"
end } }
lenv.require = function(n)
	if n == "Config" then return Config end
	if n == "TextKo" then return KO end
	return nil
end
local lf = assert(loadstring(L10N_SOURCE, "=L10n"))
setfenv(lf, lenv)
local L10n = lf()

local spawned = {}
local env = setmetatable(table.clone(base), { __index = getfenv() })
env.game = game
env.workspace = workspaceObj
env.typeof = function(v) if type(v) == "table" and rawget(v, "__p") then return "Instance" end return type(v) end
env.require = function(n)
	if n == "Util" then return Util end
	if n == "L10n" then return L10n end
	if n == "Config" then return Config end
	return nil
end
env.task = { spawn = function(f, ...) table.insert(spawned, f) end, defer = function(f, ...) f(...) end, wait = function() end }
local vf = assert(loadstring(VIEW_SOURCE, "=GatherView"))
setfenv(vf, env)
local GatherView = vf()

local langSig = signal()
local lang = "en"
GatherView.Init({ UIKit = { Lang = function() return lang end, LangChanged = langSig } })
GatherView.Start()
check(#stateRemote.OnClientEvent.Fns == 1, "GatherState is bound at Init (the first state is never missed)")
-- the map watcher (spawned at Start): no folder yet -> waits for it
check(#spawned == 2, "Start spawns the map watcher and the poll", #spawned)
pcall(spawned[1]) -- the map watcher (the poll is GatherView.Tick, called by hand below)

------------------------------------------------------------------ 1. words
local a, o = GatherView.Words("Config.Gather.Text.Pick", "Config.Loot.Items.Herb.Name", "en")
check(a == "Pick" and o == "Meadow Herb", "the prompt words come from the keys (Pick + the item name)", a .. " / " .. o)
a, o = GatherView.Words("Config.Gather.Text.Nope", nil, "en")
check(a == "" and o == "", "an unknown / missing key is no word (never the key itself)", a .. "|" .. o)
KO["Config.Gather.Text.Pick"] = { Ko = "따기", En = "Pick" }
KO["Config.Loot.Items.Herb.Name"] = { Ko = "초원 약초", En = "Meadow Herb" }
a, o = GatherView.Words("Config.Gather.Text.Pick", "Config.Loot.Items.Herb.Name", "ko")
check(a == "따기" and o == "초원 약초", "Korean words for a Korean reader (A23-133 beta in both languages)", a .. " / " .. o)
KO["Config.Gather.Text.Pick"] = { Ko = "따기", En = "Pick it" }
a = GatherView.Words("Config.Gather.Text.Pick", nil, "ko")
check(a == "Pick", "a stale Korean line falls back to the English", a)
KO["Config.Gather.Text.Pick"] = { Ko = "따기", En = "Pick" }

------------------------------------------------------------------ 2. nodes
check(not GatherView.Resting({ A = NOW - 1 }, "A", NOW) and GatherView.Resting({ A = NOW + 5 }, "A", NOW)
	and not GatherView.Resting({}, "A", NOW), "rest = a ready time still in the future")
local n1 = node("SlimeMeadow:1", "HerbBush", "Config.Gather.Text.Pick", "Config.Loot.Items.Herb.Name")
local n2 = node("SlimeMeadow:2", "CopperRock", "Config.Gather.Text.Mine", "Config.Loot.Items.CopperOre.Name")
n1.Parent = folder
n2.Parent = folder
folder.Parent = map -- the folder arrives after Start: the map watcher picks it up
local p1 = n1:FindFirstChild("GatherPrompt", true)
local p2 = n2:FindFirstChild("GatherPrompt", true)
check(p1.ActionText == "Pick" and p1.ObjectText == "Meadow Herb" and p2.ActionText == "Mine" and p2.ObjectText == "Copper Ore",
	"nodes already there get their words when the folder appears", p1.ActionText .. " " .. p2.ActionText)
check(p1.Enabled and p2.Enabled, "no state yet: every node is ready")

-- 3. a state: node 1 rests for me
stateRemote.OnClientEvent:Fire({ Ready = { ["SlimeMeadow:1"] = NOW + 180, [5] = NOW + 9, ["SlimeMeadow:2"] = 0 / 0, Bad = "x" }, N = 3, Cap = 400 })
local body1 = n1:FindFirstChild("Body")
check(not p1.Enabled and p2.Enabled, "a resting node's prompt is off for me, the others stay on")
check(body1.LocalTransparencyModifier == GatherView._T.G.Fade and body1:FindFirstChild("Leaf").LocalTransparencyModifier == GatherView._T.G.Fade,
	"its parts fade (LocalTransparencyModifier, me only)", body1.LocalTransparencyModifier)
check(not body1:FindFirstChild("Sparkle").Enabled and not body1:FindFirstChild("Glow").Enabled, "its sparkle and light go out")
check(n2:FindFirstChild("Body").LocalTransparencyModifier == 0, "a ready node is not faded")
local S = GatherView._T.S
check(S.Ready["SlimeMeadow:1"] == NOW + 180 and S.Ready[5] == nil and S.Ready["SlimeMeadow:2"] == nil and S.Ready.Bad == nil,
	"the state keeps string ids with real times only")
check(S.N == 3 and S.Cap == 400, "today's count / cap kept")
-- 4. the time passes
NOW += 100
GatherView.Tick()
check(not p1.Enabled, "still resting before its time")
NOW += 81
GatherView.Tick()
check(p1.Enabled and body1.LocalTransparencyModifier == 0, "its time passed: back on and not faded")
check(body1:FindFirstChild("Sparkle").Enabled and body1:FindFirstChild("Glow").Enabled and not body1:FindFirstChild("Dust").Enabled,
	"the sparkle / light come back; an emitter that was off stays off")
-- 5. a node that streams in later while resting
stateRemote.OnClientEvent:Fire({ Ready = { ["SlimeMeadow:3"] = NOW + 60 }, N = 4, Cap = 400 })
local n3 = node("SlimeMeadow:3", "HerbBush", "Config.Gather.Text.Pick", "Config.Loot.Items.Herb.Name")
n3.Parent = folder
local p3 = n3:FindFirstChild("GatherPrompt", true)
check(p3.ActionText == "Pick" and not p3.Enabled, "a node added later gets its words and its rest")
-- 6. language change
lang = "ko"
langSig:Fire("ko")
check(p1.ActionText == "따기" and p1.ObjectText == "초원 약초", "the words change with my language", p1.ActionText)
lang = "en"
langSig:Fire("en")
check(p1.ActionText == "Pick", "and back")
-- 7. a removed node leaves no rest behind
n3.Parent = nil
GatherView.Tick()
check(S.Resting[n3] == nil, "a node that went away is forgotten")
-- 8. bad payloads
local okBad = pcall(GatherView.OnState, "x")
check(okBad and S.N == 4, "a non-table state is ignored")
local many = {}
for i = 1, 600 do many["Z:" .. i] = NOW + 10 end
GatherView.OnState({ Ready = many })
local cnt = 0
for _ in S.Ready do cnt += 1 end
check(cnt <= GatherView._T.G.MaxIds, "at most MaxIds ready entries", cnt)

print(string.format("GATHER_VIEW_SUMMARY checks=%d failed=%d", checks, failed))
