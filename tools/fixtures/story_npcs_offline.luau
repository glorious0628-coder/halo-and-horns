-- StoryNpcs (게임성 개발 1, 빛 마을 점검 #22 / #25 / #30): runs the real Config.luau and StoryNpcs.luau
-- (tools/test_story_npcs.py) on doubles: CollectionService "StoryNpc" models with a Head and a Talk prompt, the HUD's
-- quest rows, Instance.new recording. Inputs: CONFIG_SOURCE, NPC_SOURCE. Every check is named and counted.
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
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local function vec(x, y, z) return { X = x or 0, Y = y or 0, Z = z or 0 } end
local base = { Vector3 = { new = vec, zero = vec() }, Vector2 = { new = vec }, Color3 = { new = vec, fromRGB = vec, fromHSV = vec },
	BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), UDim2 = { fromOffset = function(x, y) return { x, y } end,
	fromScale = function(x, y) return { x, y } end, new = function() return {} end }, UDim = ctor("UDim"), NumberRange = ctor("NumberRange"),
	NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"),
	ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"), CFrame = ctor("CFrame"), TweenInfo = ctor("TweenInfo"), Font = ctor("Font"),
	Enum = enum }
local cfgEnv = setmetatable(table.clone(base), { __index = getfenv() })
cfgEnv.workspace = { GetServerTimeNow = function() return 1790000000 end }
local cf = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cf, cfgEnv)
local Config = cf()

local WORKSPACE = { Name = "Workspace" }
local made = {}
local function obj(c, name, parent)
	local o = { ClassName = c, Name = name or c, Children = {}, Attrs = {} }
	function o.IsA(self, k) return k == self.ClassName or (k == "BasePart" and self.ClassName == "Part") end
	function o.GetAttribute(self, k) return self.Attrs[k] end
	function o.FindFirstChild(self, n) for _, ch in self.Children do if ch.Name == n then return ch end end return nil end
	function o.FindFirstChildWhichIsA(self, k) for _, ch in self.Children do if ch:IsA(k) then return ch end end return nil end
	function o.GetDescendants(self)
		local out = {}
		for _, ch in self.Children do
			table.insert(out, ch)
			for _, d in ch:GetDescendants() do table.insert(out, d) end
		end
		return out
	end
	function o.IsDescendantOf(self, anc)
		local p = rawget(self, "Parent")
		while p do if p == anc then return true end p = rawget(p, "Parent") end
		return false
	end
	setmetatable(o, { __newindex = function(t, k, v)
		rawset(t, k, v)
		if k == "Parent" and type(v) == "table" and v.Children then table.insert(v.Children, t) end
	end })
	if parent then o.Parent = parent end
	return o
end
local function npc(id)
	local m = obj("Model", "Npc_" .. id, WORKSPACE)
	m.Attrs.NpcId = id
	obj("Part", "Head", m)
	local root = obj("Part", "HumanoidRootPart", m)
	local p = obj("ProximityPrompt", "Talk", root)
	p.Attrs.StoryNpcId = id
	p.Enabled = true
	local other = obj("ProximityPrompt", "Other", root) -- not a story prompt: never touched
	other.Enabled = true
	return m, p, other
end
local TAGGED = {}
local ROWS = {}
local env = setmetatable(table.clone(base), { __index = getfenv() })
env.workspace = WORKSPACE
env.game = { GetService = function(_, n)
	if n == "CollectionService" then return { GetTagged = function(_, tag) return tag == "StoryNpc" and TAGGED or {} end } end
	if n == "ReplicatedStorage" then return { WaitForChild = function() return { WaitForChild = function(_, m) return m end } end } end
	return {}
end }
env.require = function(m) if m == "Config" then return Config end return { Warn = function(...) print("WARN", ...) end } end
env.Instance = { new = function(c) local o = obj(c) table.insert(made, o) return o end }
env.typeof = function(v) if type(v) == "table" and v.ClassName then return "Instance" end return typeof(v) end
env.task = { spawn = function() end, wait = function() end }
local f = assert(loadstring(NPC_SOURCE, "=StoryNpcs"))
setfenv(f, env)
local SN = f()
SN.Init({ HUD = { QuestEntries = function() return ROWS end }, UIKit = { Theme = {} } })

local function markOf(m)
	for _, ch in m.Children do if ch.ClassName == "BillboardGui" then return ch end end
	return nil
end

-- pure
local c = SN.Called({ { Story = { Id = "H1", Npc = "Bright" } }, { Story = { Id = "H5" } }, { Id = "daily" }, { Story = { Npc = "" } } })
check(c.Bright == true and next(c, "Bright") == nil, "Called: only the rows that talk through an NPC", c.Bright)

local bright, bp, bOther = npc("Bright")
local gleam, gp = npc("Gleam")
TAGGED = { bright, gleam }
ROWS = {}
SN.Refresh()
check(markOf(bright) and markOf(bright).Enabled == false and bp.Enabled == false and gp.Enabled == false,
	"no row talks through them: no '!' and no Talk prompt (nothing to say)")
check(bOther.Enabled == true, "a prompt that is not a story Talk prompt is never touched")
ROWS = { { Story = { Id = "H1", St = 1, Panel = true, Npc = "Bright" } } }
SN.Refresh()
local mk = markOf(bright)
check(mk and mk.Enabled == true and bp.Enabled == true, "a row talks through Bright: her '!' and her Talk prompt show", mk and mk.Enabled)
check(markOf(gleam).Enabled == false and gp.Enabled == false, "... Sir Gleam stays quiet")
local label = mk and mk.Children[1]
check(mk and mk.Adornee == bright:FindFirstChild("Head") and mk.MaxDistance <= 100 and label and label.Text == "!"
	and mk.StudsOffsetWorldSpace and mk.StudsOffsetWorldSpace.Y >= 2,
	"the '!' floats over her head, near players only")
SN.Refresh()
local count = 0
for _, ch in bright.Children do if ch.ClassName == "BillboardGui" then count += 1 end end
check(count == 1, "one '!' per NPC however many passes", count)
ROWS = { { Story = { Id = "H1", St = 2, Panel = true, Npc = "Gleam" } } }
SN.Refresh()
check(mk.Enabled == false and bp.Enabled == false and markOf(gleam).Enabled == true and gp.Enabled == true,
	"the row moves on to Sir Gleam: Bright's '!' / prompt go, his come")
bright.Parent = nil
ROWS = { { Story = { Npc = "Bright" } } }
SN.Refresh()
check(mk.Enabled == false, "an NPC out of the world is left alone")

print(("STORY_NPCS_SUMMARY checks=%d failed=%d"):format(checks, failed))
