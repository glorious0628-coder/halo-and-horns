-- StoryNpcs.luau (게임성 개발 1; 빛 마을 점검 #22 / #25 / #30, server = 게임성 개발 3's TownNpcs,
-- docs/design/town_npcs_server_2026-10-10.md): the client side of the town's story NPC bodies (Bright, Sir Gleam: tag
-- Config.StoryQuests.NpcTag, attribute NpcId, a "Talk" ProximityPrompt with attribute StoryNpcId that the server opens).
--   A small gold "!" floats over an NPC while one of my quest rows (HUD.QuestEntries: the quest window's More rows too)
--   is a talk step through her (Story.Npc - the server sends it only while the step is not waiting for [Claim]); her
--   Talk prompt shows only then (Enabled set on this client only), so a press never lands on "nothing to say".
--   The townsfolk (tag TownFolk) get nothing here. The marker / the row tap that lead to her are QuestTarget / HUD.
-- No new art: a text "!" in the UIKit font with a dark outline (round, never rays).
-- A23-199: an NPC with a request (attribute StoryOffers) gets the "!" too; a Pickup step's thing lies at its spot.
-- Public API: StoryNpcs.Init(C), StoryNpcs.Start(), StoryNpcs.Called(entries) -> { [npcId] = true } (pure),
-- StoryNpcs.Offers(text) / StoryNpcs.Pickups(entries, faction) (pure), StoryNpcs.DrawPickups(list), StoryNpcs.OnPickup(prompt),
-- StoryNpcs.OnPrompt(prompt) -> bool (a Talk prompt press: Panels.ExpectStory), StoryNpcs.Refresh() (one pass now),
-- StoryNpcs.Mark(model) -> its one "!" BillboardGui (made once, reused).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local StoryNpcs = {}
local C = nil
local TAG = "StoryNpcs"

local T = {
	Every = 0.5, -- s between passes (quest rows and NPCs change rarely)
	MarkText = "!",
	MarkSize = 40, -- px (the billboard is MarkSize x MarkSize)
	MarkLift = 2.4, -- studs over the head
	MarkDistance = 90, -- studs: the "!" shows within this distance
	Gold = Color3.fromRGB(255, 214, 72),
	-- 퀘스트 바이블 §15 P1 ② (10/15): '!' = something to start / do here, '?' = something to hand in here (wins over
	-- '!'); the main story's mark is gold with a star behind it (told apart by shape too, not by colour alone), the
	-- others white
	White = Color3.fromRGB(245, 245, 250), Done = "?", StarArt = "Star", StarScale = 1.25,
}
-- 검수 10/10 (main Play: seven "!" stacked under Bright): the mark is found ON the model (its child StoryNpcMark), never
-- in a weak table - a weak-keyed Instance entry is dropped once Lua holds no reference, so every pass made a new one
local S = { Started = false }

-- the NPC ids my rows talk through (pure: entries = HUD quest rows). 10/16 (user: "할리 만나기부터 안 됨" - no Talk
-- prompt on Hallie): the first mission's row names its guide / teacher as GuideNpc (QuestService: step 0 = the side's
-- guide, the Teacher step = the teacher), not as Story.Npc - those are called too, or their Talk prompt stays off
function StoryNpcs.Called(entries)
	local out = {}
	for _, e in type(entries) == "table" and entries or {} do
		local st = type(e) == "table" and e.Story or nil
		if type(st) == "table" and type(st.Npc) == "string" and st.Npc ~= "" then out[st.Npc] = true end
		if type(e) == "table" and type(e.GuideNpc) == "string" and e.GuideNpc ~= "" then out[e.GuideNpc] = true end
	end
	return out
end

-- A23-199 (개발 2 quest_offer_server_2026-10-15): the NPCs that have a request for me (attribute StoryOffers = their ids,
-- comma separated, "" = none) -> { [npcId] = true } (pure)
function StoryNpcs.Offers(text)
	local out = {}
	if type(text) ~= "string" then return out end
	for id in string.gmatch(text, "[^,%s]+") do out[id] = true end
	return out
end

-- A23-199 (pure): my rows' open Pickup steps -> { { Id, Spot, Pos, Radius } } (the step of each Story row, my side's
-- override first; the spot from Config.StoryQuests.Landmarks)
function StoryNpcs.Pickups(entries, faction)
	local sq = type(Config.StoryQuests) == "table" and Config.StoryQuests or {}
	local defs = type(sq.Defs) == "table" and sq.Defs or {}
	local marks = type(sq.Landmarks) == "table" and sq.Landmarks or {}
	local out, seen = {}, {}
	for _, e in type(entries) == "table" and entries or {} do
		local st = type(e) == "table" and e.Story or nil
		local def = type(st) == "table" and type(st.Id) == "string" and defs[st.Id] or nil
		local step = type(def) == "table" and type(def.Steps) == "table" and def.Steps[tonumber(st.St) or 0] or nil
		if type(step) == "table" then
			local over = type(faction) == "string" and step[faction] or nil
			local obj = (type(over) == "table" and type(over.Obj) == "table" and over.Obj) or step.Obj
			if type(obj) == "table" and obj.Type == "Pickup" and type(obj.Spot) == "string" and typeof(marks[obj.Spot]) == "Vector3"
				and not seen[st.Id] then
				seen[st.Id] = true
				table.insert(out, { Id = st.Id, Spot = obj.Spot, Pos = marks[obj.Spot], Radius = tonumber(obj.Radius) or 8 })
			end
		end
	end
	return out
end

-- 퀘스트 바이블 §15 P1 ② (pure): each NPC's mark from my rows and requests -> { [npcId] = { Text = "!" | "?", Main } }.
-- A row through her whose open step finishes the quest there (its last step, or a Deliver) = "?"; any other step
-- through her = "!"; a request for me (StoryOffers) = "!"; a skill waiting at the teacher = "!" (main: it is the growth
-- path). "?" wins over "!", Main over side
function StoryNpcs.Marks(entries, offers, teacher)
	local defs = type(Config.StoryQuests) == "table" and type(Config.StoryQuests.Defs) == "table" and Config.StoryQuests.Defs or {}
	local out = {}
	local function put(id, done, main)
		if type(id) ~= "string" or id == "" then return end
		local m = out[id] or { Text = T.MarkText, Main = false }
		if done then m.Text = T.Done end
		if main then m.Main = true end
		out[id] = m
	end
	for _, e in type(entries) == "table" and entries or {} do
		local st = type(e) == "table" and e.Story or nil
		if type(st) == "table" and type(st.Npc) == "string" and st.Npc ~= "" then
			local def = type(st.Id) == "string" and defs[st.Id] or nil
			local steps = type(def) == "table" and type(def.Steps) == "table" and def.Steps or {}
			local n = tonumber(st.St) or 0
			local step = steps[n]
			local obj = type(step) == "table" and step.Obj or nil
			local done = (n >= #steps and #steps > 0) or (type(obj) == "table" and obj.Type == "Deliver")
			put(st.Npc, done, e.Kind == "Main")
		end
	end
	for id in type(offers) == "table" and offers or {} do put(id, false, false) end
	if type(teacher) == "string" then put(teacher, false, true) end
	return out
end

-- the mark's look: its sign, gold + star for the main story, white otherwise
function StoryNpcs.Paint(bb, mark)
	local label = bb and bb:FindFirstChild("Mark")
	if not (label and mark) then return end
	if label.Text ~= mark.Text then label.Text = mark.Text end
	local col = mark.Main and T.Gold or T.White
	if label.TextColor3 ~= col then label.TextColor3 = col end
	local star = bb:FindFirstChild("Star")
	if star then star.Visible = mark.Main == true end
end

-- the model's one "!" (made once; extra copies from older passes are removed)
function StoryNpcs.Mark(model)
	local bb = nil
	for _, ch in model:GetChildren() do
		if ch.Name == "StoryNpcMark" and ch:IsA("BillboardGui") then
			if bb then ch:Destroy() else bb = ch end
		end
	end
	local head = model:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		head = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	end
	if bb then
		-- 검수 10/10 (API review ②): the body may be rebuilt (a new head): the "!" follows the head it has now
		if head and bb.Adornee ~= head then bb.Adornee = head end
		return bb
	end
	if not head then return nil end
	bb = Instance.new("BillboardGui")
	bb.Name = "StoryNpcMark"
	bb.Adornee = head
	bb.Size = UDim2.fromOffset(T.MarkSize, T.MarkSize)
	bb.StudsOffsetWorldSpace = Vector3.new(0, T.MarkLift, 0)
	bb.MaxDistance = T.MarkDistance
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	bb.Enabled = false
	local label = Instance.new("TextLabel")
	label.Name = "Mark"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	local ui = C and C.UIKit
	local theme = type(ui) == "table" and ui.Theme or nil
	label.Font = (type(theme) == "table" and typeof(theme.TitleFont) == "EnumItem" and theme.TitleFont)
		or (type(theme) == "table" and typeof(theme.Font) == "EnumItem" and theme.Font) or Enum.Font.GothamBlack
	label.Text = T.MarkText
	label.TextScaled = true
	label.TextColor3 = T.Gold
	label.TextStrokeTransparency = 0.2
	label.ZIndex = 2
	label.Parent = bb
	-- the main story's star behind the sign (approved art "Star"; none = the gold sign alone)
	local star = type(ui) == "table" and type(ui.ArtImage) == "function" and ui.ArtImage(T.StarArt, { Name = "Star",
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(T.StarScale, T.StarScale),
		ImageColor3 = T.Gold, ImageTransparency = 0.25, ZIndex = 1, Visible = false }) or nil
	if star then star.Parent = bb end
	bb.Parent = model
	return bb
end

-- A23-199: the things to pick up of my open Pickup steps, only while that step is open: a small box on the ground at
-- the spot, a soft light and round sparkles (no rays), a "Pick up" prompt -> StoryAction(Id, "Pickup"); a step that
-- closed takes its box away. Client-only parts in workspace.StoryPickups (no collision, no query)
-- Brush = studs: walking this close picks it up without a press (최종 검수 10/15, the textbook: "줍기는 스쳐도 성공"; the
-- server still checks its own Radius), Again = s before the same thing is asked for again
T.Pickup = { Folder = "StoryPickups", Size = Vector3.new(1.4, 0.9, 1.1), Lift = 0.45, Range = 9, Hold = 0, Brush = 5, Again = 1.5,
	Color = Color3.fromRGB(196, 140, 84), Lid = Color3.fromRGB(235, 95, 85), Light = Color3.fromRGB(255, 225, 150) }

local function groundAt(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	local folder = workspace:FindFirstChild(T.Pickup.Folder)
	if folder then table.insert(ignore, folder) end
	local me = game:GetService("Players").LocalPlayer
	if me and me.Character then table.insert(ignore, me.Character) end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(Vector3.new(pos.X, pos.Y + 200, pos.Z), Vector3.new(0, -400, 0), params)
	return hit and hit.Position.Y or pos.Y
end

------------------------------------------------------------------ quest P1 world (게임성 개발 2 contract, screen part 3~6)
-- docs/design/quest_p1_server_contract_2026-10-15.md: the dummy of a Practice step (it wobbles when a swing lands near
-- it), the borrowed practice tool in a bare hand (player attribute PracticeTool), the town lamp of M1_4, the pose spot of
-- an Emote step with its two buttons, and the scenes (Fx StoryScene) with the ones that stay (attribute StoryFlags).
-- All client-only parts in workspace.StoryProps: no collision, no query, no art, round glows only (no rays).
T.World = {
	Folder = "StoryProps",
	Dummy = { Post = Color3.fromRGB(122, 84, 52), Body = Color3.fromRGB(214, 178, 120), Band = Color3.fromRGB(196, 62, 58),
		Height = 4.4, Wobble = 14, Time = 0.45, Pad = 1.5 },
	Tool = { Name = "HH_PracticeTool", Size = Vector3.new(0.28, 2.8, 0.28), Color = Color3.fromRGB(176, 128, 78),
		Grip = { 0, -0.15, -1.25, -90 } }, -- the stick from the hand: x, y, z (studs), the tip forward (degrees about X)
	Ring = { Size = 7, Color = Color3.fromRGB(255, 214, 72), Alpha = 0.45 },
	Lamp = { Height = 6.5, Pole = Color3.fromRGB(70, 66, 74), Glass = Color3.fromRGB(235, 232, 220),
		Common = Color3.fromRGB(255, 214, 120), Mine = Color3.fromRGB(196, 150, 255), Range = 18 },
	Emote = { Gui = "StoryEmoteGui", W = 150, H = 54, Gap = 14, Lift = 214 },
	Hop = { Height = 1.2, Time = 0.32 },
	Crown = { Name = "HH_PaperCrown", Color = Color3.fromRGB(250, 236, 190), Size = Vector3.new(1.3, 0.45, 1.3) },
	Band = { Name = "HH_Band", Color = Color3.fromRGB(255, 120, 150) },
	MyLight = { Name = "HH_MyLight", Size = 0.5, Offset = Vector3.new(1.6, 2.2, 0) },
	-- who reacts in each scene (the anchored town bodies hop; Value = the pick), the lamp NPC by side
	Who = { Bag = "Folk1", Prank = "Tiny", Class = "Tiny", Smith = "Tiny", Alch = "Tiny", Tame = "Tiny", Crown = "Smokey",
		Band = "Bright" },
	LampNpc = { Halo = "Bright", Horns = "Smokey", Neutral = "Tiny" },
	LampSpot = { Halo = "LampH", Horns = "LampR", Neutral = "LampN" },
}
local WS = { Tools = {}, Dummies = {}, EmoteFor = nil, Busy = {}, Brushed = {} }

-- (pure) my rows' open steps that happen at a place -> { { Id, Type, Spot, Pos, Radius, Allowed } }: Pickup / Practice /
-- Emote (Obj.Spot) and the lamp of a step that leads to a Lamp* spot (Obj.Spot or Guide); my side's override first
function StoryNpcs.Spots(entries, faction)
	local sq = type(Config.StoryQuests) == "table" and Config.StoryQuests or {}
	local defs = type(sq.Defs) == "table" and sq.Defs or {}
	local marks = type(sq.Landmarks) == "table" and sq.Landmarks or {}
	local out, seen = {}, {}
	for _, e in type(entries) == "table" and entries or {} do
		local st = type(e) == "table" and e.Story or nil
		local def = type(st) == "table" and type(st.Id) == "string" and defs[st.Id] or nil
		local step = type(def) == "table" and type(def.Steps) == "table" and def.Steps[tonumber(st.St) or 0] or nil
		if type(step) == "table" and not seen[st.Id] then
			local over = type(faction) == "string" and step[faction] or nil
			over = type(over) == "table" and over or {}
			local obj = (type(over.Obj) == "table" and over.Obj) or step.Obj
			obj = type(obj) == "table" and obj or {}
			local t = obj.Type
			local key = obj.Spot
			if t ~= "Pickup" and t ~= "Practice" and t ~= "Emote" then
				local g = over.Guide or step.Guide
				local lamp = (type(key) == "string" and key) or (type(g) == "string" and g) or ""
				if string.sub(lamp, 1, 4) == "Lamp" then t, key = "Lamp", lamp else t = nil end
			end
			if t and type(key) == "string" and typeof(marks[key]) == "Vector3" then
				seen[st.Id] = true
				table.insert(out, { Id = st.Id, Type = t, Spot = key, Pos = marks[key],
					Radius = tonumber(obj.Radius) or (t == "Emote" and 10 or 8), Allowed = type(obj.Allowed) == "table" and obj.Allowed or nil })
			end
		end
	end
	return out
end

-- (pure) the attribute StoryFlags "Crown=Paper,Lamp=Mine" -> { Crown = "Paper", Lamp = "Mine" }
function StoryNpcs.FlagsOf(text)
	local out = {}
	if type(text) ~= "string" then return out end
	for k, v in string.gmatch(text, "([%w_]+)=([%w_]+)") do out[k] = v end
	return out
end

-- (pure) the Pickup step I brush past (within Brush of its spot, never farther than its Radius), else nil
function StoryNpcs.BrushPickup(spots, pos)
	if typeof(pos) ~= "Vector3" then return nil end
	for _, s in type(spots) == "table" and spots or {} do
		if s.Type == "Pickup" and Util.FlatDistance(pos, s.Pos) <= math.min(T.Pickup.Brush, s.Radius) then return s end
	end
	return nil
end

-- (pure) the Emote step whose spot I stand at, else nil
function StoryNpcs.EmoteAt(spots, pos)
	if typeof(pos) ~= "Vector3" then return nil end
	for _, s in type(spots) == "table" and spots or {} do
		if s.Type == "Emote" and Util.FlatDistance(pos, s.Pos) <= s.Radius then return s end
	end
	return nil
end

-- (pure) the emote names an Emote step takes, in a fixed order (wave = Good first)
function StoryNpcs.EmoteNames(spot)
	local out = {}
	for name in type(spot) == "table" and type(spot.Allowed) == "table" and spot.Allowed or {} do table.insert(out, name) end
	table.sort(out, function(a, b) return (spot.Allowed[a] == "Good" and 0 or 1) < (spot.Allowed[b] == "Good" and 0 or 1)
		or ((spot.Allowed[a] == "Good") == (spot.Allowed[b] == "Good") and a < b) end)
	return out
end

local function bare(p)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	return p
end

local function block(name, size, color, cf, parent, shape)
	local p = bare(Instance.new("Part"))
	p.Name, p.Size, p.Color, p.Material, p.CFrame = name, size, color, Enum.Material.SmoothPlastic, cf
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end

local function sparkle(parent, color, rate)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Sparkle"
	e.Color = ColorSequence.new(color)
	e.LightEmission, e.Rate = 0.8, rate or 6
	e.Lifetime = NumberRange.new(0.6, 1.1)
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	e.Parent = parent
	return e
end

local function burst(at, color, n)
	if typeof(at) ~= "Vector3" then return end
	local folder = workspace:FindFirstChild(T.World.Folder) or workspace
	local p = block("Burst", Vector3.new(0.2, 0.2, 0.2), color, CFrame.new(at), folder)
	p.Transparency = 1
	local e = sparkle(p, color, 0)
	e.Speed = NumberRange.new(2, 5)
	e:Emit(n or 18)
	game:GetService("Debris"):AddItem(p, 2)
end

local function propFolder()
	local f = workspace:FindFirstChild(T.World.Folder)
	if not f then
		f = Instance.new("Folder")
		f.Name = T.World.Folder
		f.Parent = workspace
	end
	return f
end

-- the practice dummy: a post, a straw body with a red band, a round head; its base is its pivot (it wobbles about it)
local function makeDummy(s)
	local D = T.World.Dummy
	local m = Instance.new("Model")
	local y = groundAt(s.Pos)
	local base = CFrame.new(s.Pos.X, y, s.Pos.Z)
	local post = block("Post", Vector3.new(0.35, D.Height, 0.35), D.Post, base * CFrame.new(0, D.Height / 2, 0), m)
	block("Body", Vector3.new(1.6, 2, 0.9), D.Body, base * CFrame.new(0, D.Height * 0.62, 0), m)
	block("Band", Vector3.new(1.65, 0.3, 0.95), D.Band, base * CFrame.new(0, D.Height * 0.62, 0), m)
	block("Arms", Vector3.new(3, 0.35, 0.35), D.Post, base * CFrame.new(0, D.Height * 0.72, 0), m)
	block("Head", Vector3.new(1.1, 1.1, 1.1), D.Body, base * CFrame.new(0, D.Height + 0.45, 0), m, Enum.PartType.Ball)
	m.PrimaryPart = post
	m:SetAttribute("Base", base)
	return m
end

-- one wobble: tipped away and back, about its base (the Swing Fx's contact moment)
function StoryNpcs.Wobble(m)
	if WS.Busy[m] or not (m and m.Parent) then return false end
	local base = m:GetAttribute("Base")
	if typeof(base) ~= "CFrame" then return false end
	WS.Busy[m] = true
	local pivot = m:GetPivot()
	local rel = base:Inverse() * pivot
	local D = T.World.Dummy
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < D.Time and m.Parent do
			local k = (os.clock() - t0) / D.Time
			local a = math.sin(k * math.pi * 3) * (1 - k) * math.rad(D.Wobble)
			m:PivotTo(base * CFrame.Angles(a, 0, a * 0.4) * rel)
			task.wait()
		end
		if m.Parent then m:PivotTo(pivot) end
		WS.Busy[m] = nil
	end)
	return true
end

-- the town lamp: a pole and a round glass; lit = a warm (Common) or my own violet (Mine) light
local function makeLamp(s)
	local L = T.World.Lamp
	local m = Instance.new("Model")
	local base = CFrame.new(s.Pos.X, groundAt(s.Pos), s.Pos.Z)
	block("Pole", Vector3.new(0.4, L.Height, 0.4), L.Pole, base * CFrame.new(0, L.Height / 2, 0), m)
	local glass = block("Glass", Vector3.new(1.4, 1.4, 1.4), L.Glass, base * CFrame.new(0, L.Height + 0.5, 0), m, Enum.PartType.Ball)
	glass.Material = Enum.Material.Glass
	glass.Transparency = 0.2
	local light = Instance.new("PointLight")
	light.Name = "Light"
	light.Range, light.Brightness, light.Enabled = L.Range, 1.6, false
	light.Parent = glass
	m.PrimaryPart = glass
	return m
end

local function lightLamp(m, value)
	local glass = m and m:FindFirstChild("Glass")
	local light = glass and glass:FindFirstChild("Light")
	if not light then return end
	local L = T.World.Lamp
	local col = value == "Mine" and L.Mine or value == "Common" and L.Common or nil
	light.Enabled = col ~= nil
	if col then
		light.Color = col
		glass.Color = col
		glass.Material = Enum.Material.Neon
	end
end

-- the pose spot: a soft gold ring on the ground (round, never rays)
local function makeRing(s)
	local R = T.World.Ring
	local m = Instance.new("Model")
	local disc = block("Ring", Vector3.new(0.15, R.Size, R.Size), R.Color,
		CFrame.new(s.Pos.X, groundAt(s.Pos) + 0.08, s.Pos.Z) * CFrame.Angles(0, 0, math.rad(90)), m, Enum.PartType.Cylinder)
	disc.Material, disc.Transparency = Enum.Material.Neon, R.Alpha
	sparkle(disc, R.Color, 3)
	m.PrimaryPart = disc
	return m
end

local MAKE = { Practice = makeDummy, Lamp = makeLamp, Emote = makeRing }

-- the props follow my open steps (made once per step and kind, removed when it closes); my side's lamp stays while the
-- Lamp flag is set (it keeps its light)
function StoryNpcs.DrawProps(spots, flags, faction)
	local want = {}
	for _, s in type(spots) == "table" and spots or {} do
		if MAKE[s.Type] then want[s.Id .. ":" .. s.Type] = s end
	end
	local lampKey = T.World.LampSpot[faction or ""]
	local marks = type(Config.StoryQuests.Landmarks) == "table" and Config.StoryQuests.Landmarks or {}
	if flags and flags.Lamp and lampKey and typeof(marks[lampKey]) == "Vector3" and not want["Lamp:Lamp"] then
		local own = false
		for _, s in want do if s.Type == "Lamp" then own = true end end
		if not own then want["Lamp:Lamp"] = { Id = "Lamp", Type = "Lamp", Spot = lampKey, Pos = marks[lampKey] } end
	end
	local folder = workspace:FindFirstChild(T.World.Folder)
	if next(want) == nil and not folder then return 0 end
	folder = folder or propFolder()
	for _, m in folder:GetChildren() do
		local key = m:GetAttribute("PropKey")
		if key ~= nil then
			if not want[key] then m:Destroy() else want[key] = false end
		end
	end
	for key, s in want do
		if s then
			local m = MAKE[s.Type](s)
			m.Name = "Prop_" .. key
			m:SetAttribute("PropKey", key)
			m:SetAttribute("PropType", s.Type)
			m.Parent = folder
		end
	end
	local n = 0
	for _, m in folder:GetChildren() do
		if m:GetAttribute("PropType") == "Lamp" then lightLamp(m, flags and flags.Lamp) end
		if m:GetAttribute("PropKey") ~= nil then n += 1 end
	end
	return n
end

-- the Swing Fx (anyone's): a swing whose reach touches a dummy makes it wobble at the contact moment
function StoryNpcs.OnSwing(data)
	local folder = workspace:FindFirstChild(T.World.Folder)
	if not folder or type(data) ~= "table" or typeof(data.Pos) ~= "Vector3" then return 0 end
	local reach = (tonumber(data.Radius) or 4) + T.World.Dummy.Pad
	local n = 0
	for _, m in folder:GetChildren() do
		local base = m:GetAttribute("Base")
		if m:GetAttribute("PropType") == "Practice" and typeof(base) == "CFrame" and Util.FlatDistance(data.Pos, base.Position) <= reach then
			n += 1
			task.delay(math.max(0, tonumber(data.ContactDelay) or 0.1), function() StoryNpcs.Wobble(m) end)
		end
	end
	return n
end

-- the borrowed practice tool: a wooden stick in the right hand of each player whose PracticeTool is set and who holds
-- no weapon (A23-34: bare-handed); taken away when it is cleared
function StoryNpcs.DrawTools()
	local TL = T.World.Tool
	local n = 0
	for _, p in game:GetService("Players"):GetPlayers() do
		local char = p.Character
		local id = p:GetAttribute("PracticeTool")
		local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
		local old = char and char:FindFirstChild(TL.Name)
		local want = type(id) == "string" and id ~= "" and hand ~= nil and char:FindFirstChildOfClass("Tool") == nil
		if not want then
			if old then old:Destroy() end
		elseif not old then
			local stick = Instance.new("Part")
			stick.Name, stick.Size, stick.Color, stick.Material = TL.Name, TL.Size, TL.Color, Enum.Material.Wood
			stick.Anchored, stick.CanCollide, stick.CanQuery, stick.CanTouch, stick.Massless = false, false, false, false, true
			local g = TL.Grip
			stick.CFrame = hand.CFrame * CFrame.new(g[1], g[2], g[3]) * CFrame.Angles(math.rad(g[4]), 0, 0)
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = hand, stick
			weld.Parent = stick
			stick.Parent = char
			n += 1
		else
			n += 1
		end
	end
	return n
end

-- the emote buttons of the Emote step I stand at (two art buttons over the skill row; my side's look by the pick:
-- wave = Good, cheer = Evil). A press plays the free Roblox emote and tells the server the name.
local function emoteGui()
	local me = game:GetService("Players").LocalPlayer
	local pg = me and me:FindFirstChildOfClass("PlayerGui")
	if not pg then return nil end
	local gui = pg:FindFirstChild(T.World.Emote.Gui)
	if gui then return gui end
	gui = Instance.new("ScreenGui")
	gui.Name = T.World.Emote.Gui
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = pg
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.Position = UDim2.new(0.5, 0, 1, -T.World.Emote.Lift)
	row.Size = UDim2.fromOffset(T.World.Emote.W * 2 + T.World.Emote.Gap, T.World.Emote.H)
	row.Parent = gui
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, T.World.Emote.Gap)
	list.Parent = row
	return gui
end

function StoryNpcs.PlayEmote(name)
	local me = game:GetService("Players").LocalPlayer
	local animate = me and me.Character and me.Character:FindFirstChild("Animate")
	local play = animate and animate:FindFirstChild("PlayEmote")
	if play and play:IsA("BindableFunction") then
		local ok, done = pcall(function() return play:Invoke(name) end)
		return ok and done == true
	end
	return false
end

function StoryNpcs.SendEmote(id, name)
	if WS.SentAt and os.clock() - WS.SentAt < 1 then return false end
	WS.SentAt = os.clock()
	pcall(StoryNpcs.PlayEmote, name)
	local ok, remote = pcall(function() return game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):FindFirstChild("StoryAction") end)
	if ok and remote then remote:FireServer(id, "Emote", name) end
	return true
end

function StoryNpcs.DrawEmote(spot)
	local key = spot and (spot.Id .. "|" .. table.concat(StoryNpcs.EmoteNames(spot), ",")) or nil
	if key == WS.EmoteFor then return key ~= nil end
	WS.EmoteFor = key
	local gui = emoteGui()
	if not gui then return false end
	local row = gui:FindFirstChild("Row")
	for _, ch in row:GetChildren() do
		if ch:IsA("GuiButton") then ch:Destroy() end
	end
	gui.Enabled = spot ~= nil
	if not spot then return false end
	local ui = C and C.UIKit
	local words = type(Config.StoryQuests.Text) == "table" and Config.StoryQuests.Text or {}
	for i, name in StoryNpcs.EmoteNames(spot) do
		local text = words["Emote" .. string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)] or name
		local art = spot.Allowed[name] == "Good" and "BtnKind" or "BtnSneaky"
		local props = { Name = "Emote_" .. name, Text = text, TextSize = 20, LayoutOrder = i,
			Size = UDim2.fromOffset(T.World.Emote.W, T.World.Emote.H) }
		local b = nil
		if type(ui) == "table" and type(ui.ArtTextButton) == "function" then
			b = ui.ArtTextButton(art, props, function() StoryNpcs.SendEmote(spot.Id, name) end)
		else
			b = Instance.new("TextButton")
			for k, v in props do b[k] = v end
			b.Activated:Connect(function() StoryNpcs.SendEmote(spot.Id, name) end)
		end
		b.Parent = row
	end
	return true
end

-- a town body by NpcId (the StoryNpc tag)
function StoryNpcs.Body(id)
	local tag = type(Config.StoryQuests) == "table" and Config.StoryQuests.NpcTag or "StoryNpc"
	local ok, list = pcall(function() return game:GetService("CollectionService"):GetTagged(tag) end)
	if not ok then return nil end
	for _, m in list do
		if typeof(m) == "Instance" and m:IsA("Model") and m:GetAttribute("NpcId") == id and m:IsDescendantOf(workspace) then return m end
	end
	-- 10/16 (first mission story): a town body that is no quest NPC (Otto at the Forge) by its TownNpcs id
	local okT, town = pcall(function() return game:GetService("CollectionService"):GetTagged("NPC") end)
	for _, m in okT and town or {} do
		if typeof(m) == "Instance" and m:IsA("Model") and m:GetAttribute("HHC_TownNpc") == id and m:IsDescendantOf(workspace) then
			return m
		end
	end
	return nil
end

-- an anchored town body hops (n times) with a round burst over its head; lunge = a step forward and back (the demo swing)
function StoryNpcs.Hop(id, n, lunge)
	local m = StoryNpcs.Body(id)
	if not m or WS.Busy[m] then return false end
	WS.Busy[m] = true
	local home = m:GetPivot()
	local H = T.World.Hop
	task.spawn(function()
		for _ = 1, math.max(1, n or 1) do
			local t0 = os.clock()
			while os.clock() - t0 < H.Time and m.Parent do
				local k = (os.clock() - t0) / H.Time
				local off = lunge and CFrame.new(0, 0, -math.sin(k * math.pi) * 1.5) or CFrame.new(0, math.sin(k * math.pi) * H.Height, 0)
				m:PivotTo(home * off)
				task.wait()
			end
		end
		if m.Parent then m:PivotTo(home) end
		WS.Busy[m] = nil
	end)
	local head = m:FindFirstChild("Head")
	burst(head and head.Position + Vector3.new(0, 1.5, 0) or home.Position, T.Gold, 14)
	return true
end

-- the looks that stay from my flags: the paper crown on my head (Crown=Paper), Bright's band (Band=Show), my own small
-- light by my shoulder (Lamp=Mine); the lamp itself is DrawProps'
function StoryNpcs.ApplyFlags(flags)
	flags = type(flags) == "table" and flags or {}
	local me = game:GetService("Players").LocalPlayer
	local char = me and me.Character
	local head = char and char:FindFirstChild("Head")
	local WC, WB, WL = T.World.Crown, T.World.Band, T.World.MyLight
	if head then
		local crown = char:FindFirstChild(WC.Name)
		if flags.Crown == "Paper" and not crown then
			crown = Instance.new("Part")
			crown.Name, crown.Size, crown.Color, crown.Material = WC.Name, WC.Size, WC.Color, Enum.Material.SmoothPlastic
			crown.Shape = Enum.PartType.Cylinder
			crown.Anchored, crown.CanCollide, crown.CanQuery, crown.CanTouch, crown.Massless = false, false, false, false, true
			crown.CFrame = head.CFrame * CFrame.new(0, head.Size.Y / 2 + WC.Size.X / 2 - 0.1, 0) * CFrame.Angles(0, 0, math.rad(90))
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = head, crown
			w.Parent = crown
			crown.Parent = char
		elseif flags.Crown ~= "Paper" and crown then
			crown:Destroy()
		end
		local orb = char:FindFirstChild(WL.Name)
		if flags.Lamp == "Mine" and not orb then
			orb = Instance.new("Part")
			orb.Name, orb.Shape, orb.Size, orb.Color = WL.Name, Enum.PartType.Ball, Vector3.one * WL.Size, T.World.Lamp.Mine
			orb.Material, orb.Transparency = Enum.Material.Neon, 0.15
			orb.Anchored, orb.CanCollide, orb.CanQuery, orb.CanTouch, orb.Massless = false, false, false, false, true
			orb.CFrame = head.CFrame * CFrame.new(WL.Offset)
			local light = Instance.new("PointLight")
			light.Color, light.Range, light.Brightness = T.World.Lamp.Mine, 8, 1
			light.Parent = orb
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = head, orb
			w.Parent = orb
			orb.Parent = char
		elseif flags.Lamp ~= "Mine" and orb then
			orb:Destroy()
		end
	end
	local bright = StoryNpcs.Body(T.World.Who.Band)
	local hand = bright and (bright:FindFirstChild("LeftHand") or bright:FindFirstChild("Left Arm"))
	if hand then
		local band = bright:FindFirstChild(WB.Name)
		if flags.Band == "Show" and not band then
			band = block(WB.Name, Vector3.new(hand.Size.X + 0.12, 0.25, hand.Size.Z + 0.12), WB.Color, hand.CFrame * CFrame.new(0, hand.Size.Y * 0.3, 0), bright)
			band.Material = Enum.Material.Neon
		elseif flags.Band ~= "Show" and band then
			band:Destroy()
		end
	end
end

-- Fx StoryScene { Id, Key, Value }: the moment a pick is written (never a reward). Demo = the teacher's one swing.
function StoryNpcs.Scene(data)
	if type(data) ~= "table" or type(data.Key) ~= "string" then return false end
	local key, value = data.Key, data.Value
	local me = game:GetService("Players").LocalPlayer
	local root = me and me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	if key == "Demo" then
		return StoryNpcs.Hop(tostring(value or ""), 1, true)
	elseif key == "Help" then
		return StoryNpcs.Hop(T.World.Who[value] or "Tiny", value == "Bag" and 1 or 2)
	elseif key == "Crown" then
		if value == "Paper" then StoryNpcs.Hop(T.World.Who.Crown, 2) end -- Rose laughs at the paper crown
		if root then burst(root.Position + Vector3.new(0, 3, 0), T.Gold, 16) end
		return true
	elseif key == "Band" then
		return StoryNpcs.Hop(T.World.Who.Band, value == "Hide" and 1 or 2)
	elseif key == "Lamp" then
		local f = me and me:GetAttribute("Faction")
		local folder = workspace:FindFirstChild(T.World.Folder)
		for _, m in folder and folder:GetChildren() or {} do
			if m:GetAttribute("PropType") == "Lamp" then
				lightLamp(m, value)
				local glass = m:FindFirstChild("Glass")
				if glass then burst(glass.Position, value == "Mine" and T.World.Lamp.Mine or T.World.Lamp.Common, 22) end
			end
		end
		if value == "Common" then StoryNpcs.Hop("Folk1", 1) end -- the neighbours wave
		StoryNpcs.Hop(T.World.LampNpc[f or ""] or "Bright", 1)
		return true
	elseif key == "Find" and data.Id == "Tutorial" then -- the first mission (Config.Tutorial.Story, St = the step name)
		return StoryNpcs.TutorialFind(data.St or value, me and me:GetAttribute("Faction"))
	elseif key == "Scene" and data.Id == "Tutorial" then
		return StoryNpcs.TutorialScene(value, me and me:GetAttribute("Faction"), data.St)
	elseif key == "Find" then -- A23-208: what I find as a step starts (St / Value = the step number)
		return StoryNpcs.Find(data.Id, data.St or value, me and me:GetAttribute("Faction"))
	elseif key == "Scene" then -- A23-208: what the people do as step St is done (Value = a Config.StoryQuests.SceneKeys key)
		return StoryNpcs.PlayScene(data.Id, value, me and me:GetAttribute("Faction"), data.St)
	end
	return false
end

------------------------------------------------------------------ A23-208 story fields (screen part)
-- docs/design/quest_data_contract_2026-10-15.md §3-2 (개발 2 dev2-story-fields): a step's Find = a short bubble over that
-- step's NPC (no NPC: over its Guide place) for Find.Seconds, two lines at most - never a toast or a banner; a step's
-- Scene = that NPC's move + a round sparkle (no rays); Next = after the last card the next asker's "!" hops once, the
-- first time it shows. A step with On = "Self" (10/15: no NPC, e.g. a bag step) = the bubble over MY head and the Scene
-- on my own avatar (Wave / Cheer / Laugh = the avatar's emote, Hop = a jump, the rest = the round sparkle only). The Offer
-- window's Before line and the last card's Next.Line are Panels' (Config.QuestBefore / Config.QuestNext via STORY.Before /
-- STORY.WithNext). Bubble art = the approved 9-slice BarkBubble (512 x 190, tail bottom-left), kept at its aspect.
T.Story = {
	Find = { Seconds = 4, W = 280, Aspect = 512 / 190, TextPx = 18, Lift = 1.6, Spot = 3, Distance = 120, TailX = 0.068,
		MaxW = 380 },
	NextFor = 900, -- s the next asker's one hop waits for her "!"
	SelfEmote = { Wave = "wave", Cheer = "cheer", Laugh = "laugh" }, -- On = "Self": the avatar's own emotes
	-- each move: N times Time s; Off(k) = the offset from home at k = 0..1 (Hip = studs from the pivot down to the bend)
	Hip = 1,
	Moves = {
		Hop = { N = 1, Time = 0.32, Up = 1.2 },
		Cheer = { N = 2, Time = 0.3, Up = 1.5 },
		Clap = { N = 3, Time = 0.16, Up = 0.3 },
		Laugh = { N = 3, Time = 0.2, Up = 0.35, Lean = 8 },
		Bow = { N = 1, Time = 0.9, Lean = -30 },
		Nod = { N = 2, Time = 0.35, Lean = -12 },
		Hug = { N = 1, Time = 1, Lean = -10, Step = 0.8 },
		Wave = { N = 2, Time = 0.45, Roll = 10 },
		Spin = { N = 1, Time = 0.8, Turn = 360 },
		Sparkle = { N = 0, Time = 0 },
	},
}

-- (pure) step n of quest id for my side: the side table over the base fields (Config merges a pack's Variants the
-- same way) -> step, def
function StoryNpcs.StepFor(id, n, faction)
	local defs = type(Config.StoryQuests) == "table" and type(Config.StoryQuests.Defs) == "table" and Config.StoryQuests.Defs or {}
	local def = type(id) == "string" and defs[id] or nil
	local step = type(def) == "table" and type(def.Steps) == "table" and def.Steps[tonumber(n) or 0] or nil
	if type(step) ~= "table" then return nil, def end
	local over = type(faction) == "string" and step[faction] or nil
	if type(over) ~= "table" then return step, def end
	local out = table.clone(step)
	for k, v in over do out[k] = v end
	return out, def
end

-- (pure) who plays a Scene: the step of that quest whose Scene it is (the last one first), else the last step's Npc,
-- else the asker (Offer.Npc, by side) / the quest's Speaker
function StoryNpcs.SceneNpc(id, scene, faction)
	local _, def = StoryNpcs.StepFor(id, 1, faction)
	if type(def) ~= "table" then return nil end
	local n = type(def.Steps) == "table" and #def.Steps or 0
	local lastNpc = nil
	for i = n, 1, -1 do
		local step = StoryNpcs.StepFor(id, i, faction)
		if type(step) == "table" and type(step.Npc) == "string" then
			lastNpc = lastNpc or step.Npc
			if step.Scene == scene then return step.Npc end
		end
	end
	if lastNpc then return lastNpc end
	local who = type(def.Offer) == "table" and def.Offer.Npc or nil
	if type(who) == "table" then who = who[faction] or who.Neutral end
	if type(who) == "string" then return who end
	return type(def.Speaker) == "string" and def.Speaker or nil
end

-- (pure) the one who asks for quest id (her "!" hops after the hook to it): the Offer's Npc by side, else the first
-- step's Npc
function StoryNpcs.AskerOf(id, faction)
	local first, def = StoryNpcs.StepFor(id, 1, faction)
	local who = type(def) == "table" and type(def.Offer) == "table" and def.Offer.Npc or nil
	if type(who) == "table" then who = who[faction] or who.Neutral end
	if type(who) == "string" and who ~= "" then return who end
	return type(first) == "table" and type(first.Npc) == "string" and first.Npc or nil
end

-- the Find bubble on adornee (a head or an attachment): BarkBubble art, the words inside its text box; one at a time
-- per adornee, gone after seconds (Find.Seconds); a line longer than 48 characters gets a wider bubble (up to MaxW)
function StoryNpcs.Bubble(adornee, text, seconds)
	local F = T.Story.Find
	local UIKit = C and C.UIKit
	local old = adornee:FindFirstChild("StoryFindBubble")
	if old then old:Destroy() end
	local w = math.min(F.MaxW, F.W + math.max(0, #text - 48) * 6)
	local h = math.floor(F.W / F.Aspect + 0.5)
	local bb = Instance.new("BillboardGui")
	bb.Name = "StoryFindBubble"
	bb.Adornee = adornee
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = F.Distance
	bb.Size = UDim2.fromOffset(w, h)
	bb.StudsOffset = Vector3.new(0, adornee:IsA("BasePart") and F.Lift or 0, 0)
	bb.SizeOffset = Vector2.new(0.5 - F.TailX, 0.5) -- the tail (bottom-left) sits on the head
	local frame
	if type(UIKit) == "table" and type(UIKit.ArtFrame) == "function" then
		frame = UIKit.ArtFrame("BarkBubble", { Name = "Bubble", Size = UDim2.fromScale(1, 1) },
			{ Color = Color3.new(1, 1, 1), CornerRadius = UDim.new(0.3, 0) })
	else
		frame = Instance.new("Frame")
		frame.Name, frame.Size, frame.BackgroundColor3 = "Bubble", UDim2.fromScale(1, 1), Color3.new(1, 1, 1)
	end
	frame.Parent = bb
	local rect = { 0.077, 0.181, 0.844, 0.448 }
	local art = type(Config.UIArt) == "table" and type(Config.UIArt.Parts) == "table" and Config.UIArt.Parts.BarkBubble or nil
	if type(art) == "table" and type(art.TextRect) == "table" and #art.TextRect == 4 then rect = art.TextRect end
	local props = { Name = "Words", Text = text, TextSize = F.TextPx, TextWrapped = true, ZIndex = 3,
		Position = UDim2.fromScale(rect[1], rect[2]), Size = UDim2.fromScale(rect[3], rect[4]),
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, Parent = frame }
	local label
	if type(UIKit) == "table" and type(UIKit.StyledLabel) == "function" then
		label = UIKit.StyledLabel(props, "Body", true)
	else
		label = Instance.new("TextLabel")
		for k, v in props do if k ~= "Parent" then label[k] = v end end
		label.BackgroundTransparency, label.Parent = 1, frame
	end
	label.TextSize = F.TextPx
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	local still = type(UIKit) == "table" and type(UIKit.ReducedMotion) == "function" and UIKit.ReducedMotion()
	if not still then
		scale.Scale = 0.6
		game:GetService("TweenService"):Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	bb.Parent = adornee
	task.delay(tonumber(seconds) or F.Seconds, function()
		if not bb.Parent then return end
		if not still then
			game:GetService("TweenService"):Create(scale, TweenInfo.new(0.15), { Scale = 0.7 }):Play()
			task.wait(0.15)
		end
		bb:Destroy()
	end)
	return bb
end

-- Fx StoryScene Find: the words of step n (Config, my side) over its NPC's head, else over its Guide / Obj.Spot place
function StoryNpcs.Find(id, n, faction)
	local step = StoryNpcs.StepFor(id, n, faction)
	local text = type(step) == "table" and step.Find or nil
	if type(text) ~= "string" or text == "" then return false end
	local body = type(step.Npc) == "string" and StoryNpcs.Body(step.Npc) or nil
	if step.On == "Self" then -- 10/15: my own words, over my head
		local me = game:GetService("Players").LocalPlayer
		body = me and me.Character or nil
	end
	local head = body and body:FindFirstChild("Head")
	if head and head:IsA("BasePart") then return StoryNpcs.Bubble(head, text) ~= nil end
	local qt = C and C.QuestTarget
	local obj = type(step.Obj) == "table" and step.Obj or {}
	local pos = nil
	for _, key in { step.Guide, obj.Spot } do
		if pos == nil and type(key) == "string" and type(qt) == "table" and type(qt.StorySpot) == "function" then
			local ok, p = pcall(qt.StorySpot, key)
			if ok and typeof(p) == "Vector3" then pos = p end
		end
	end
	if pos == nil then return false end
	local a = Instance.new("Attachment")
	a.Name = "HH_StoryFindSpot"
	a.Parent = workspace.Terrain
	a.WorldPosition = pos + Vector3.new(0, T.Story.Find.Spot, 0)
	game:GetService("Debris"):AddItem(a, T.Story.Find.Seconds + 1)
	return StoryNpcs.Bubble(a, text) ~= nil
end

-- (pure) a move's offset from home at k (0..1)
function StoryNpcs.MoveOffset(kind, k)
	local M = T.Story.Moves[kind]
	if type(M) ~= "table" then return CFrame.identity end
	local s = math.sin(k * math.pi)
	local cf = CFrame.new(0, (M.Up or 0) * s, -(M.Step or 0) * s)
	if M.Lean then
		local hip = CFrame.new(0, -T.Story.Hip, 0)
		cf = cf * hip * CFrame.Angles(math.rad(M.Lean) * s, 0, 0) * hip:Inverse()
	end
	if M.Roll then cf = cf * CFrame.Angles(0, 0, math.rad(M.Roll) * math.sin(k * math.pi * 2)) end
	if M.Turn then cf = cf * CFrame.Angles(0, math.rad(M.Turn) * (1 - math.cos(k * math.pi)) / 2, 0) end
	return cf
end

-- Fx StoryScene Scene: the NPC of step st (else StoryNpcs.SceneNpc) plays the move (anchored town bodies move on this
-- client only) + a round sparkle over her head; On = "Self" or no body near = my own avatar (emote / jump + sparkle)
function StoryNpcs.PlayScene(id, scene, faction, st)
	local SK = type(Config.StoryQuests) == "table" and Config.StoryQuests.SceneKeys or nil
	if type(scene) ~= "string" or not (type(SK) == "table" and SK[scene]) then return false end
	local step = st ~= nil and StoryNpcs.StepFor(id, st, faction) or nil
	local mine = type(step) == "table" and step.On == "Self"
	local npc = (type(step) == "table" and type(step.Npc) == "string" and step.Npc) or StoryNpcs.SceneNpc(id, scene, faction)
	local m = (not mine and type(npc) == "string") and StoryNpcs.Body(npc) or nil
	if not m then
		local me = game:GetService("Players").LocalPlayer
		local char = me and me.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then burst(root.Position + Vector3.new(0, 3, 0), T.Gold, 16) end
		if mine and T.Story.SelfEmote[scene] then
			pcall(StoryNpcs.PlayEmote, T.Story.SelfEmote[scene])
		elseif mine and scene == "Hop" then
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then hum.Jump = true end
		end
		return root ~= nil
	end
	return StoryNpcs.Move(m, scene)
end

-- body m plays the move scene (anchored town bodies move on this client only) + a round sparkle over its head
function StoryNpcs.Move(m, scene)
	local M = T.Story.Moves[scene] or T.Story.Moves.Sparkle
	local head = m:FindFirstChild("Head")
	local home = m:GetPivot()
	burst(head and head.Position + Vector3.new(0, 1.5, 0) or home.Position, T.Gold, scene == "Sparkle" and 26 or 16)
	if M.N <= 0 or WS.Busy[m] then return true end
	WS.Busy[m] = true
	task.spawn(function()
		for _ = 1, M.N do
			local t0 = os.clock()
			while os.clock() - t0 < M.Time and m.Parent do
				m:PivotTo(home * StoryNpcs.MoveOffset(scene, (os.clock() - t0) / M.Time))
				task.wait()
			end
		end
		if m.Parent then m:PivotTo(home) end
		WS.Busy[m] = nil
	end)
	return true
end

-- Panels' last card with a Next hook was answered: the asker of quest id hops once when her "!" shows (NextFor s)
function StoryNpcs.ExpectNext(id)
	local me = game:GetService("Players").LocalPlayer
	local npc = StoryNpcs.AskerOf(id, me and me:GetAttribute("Faction"))
	if type(npc) ~= "string" then return false end
	S.Next = { Npc = npc, Until = os.clock() + T.Story.NextFor }
	return true
end

-- 개발 2 ch1 data (10/15): a step that is NOT a card (Deliver / Learn / Emote ...) may still have closing words (Lines):
-- when it is done they show one by one as bubbles over whoever says them (Talk.Seconds each), and after a finished
-- quest's last such step its hook (Config.QuestNext Line) too, then the next asker's one hop. A card step's words stay in
-- Panels' card. Done = my quest row moved past the step, or waits for [Claim] / left the list after its last step.
T.Story.Talk = { Seconds = 3.5 }

-- (pure) the steps that just ended: prev / now = { [quest id] = { St, Done } } -> { { Id, St } } in order
function StoryNpcs.StepEnds(prev, now, stepCount)
	local out = {}
	if type(prev) ~= "table" then return out end
	for id, p in prev do
		local n = now[id]
		local last = tonumber(stepCount(id)) or 0
		local from = tonumber(p.St) or 0
		local to = nil
		if n and not p.Done then
			to = n.Done and last or (tonumber(n.St) or from) - 1
		elseif n == nil and not p.Done and from >= last and last > 0 then
			to = last -- a quest without [Claim] leaves the list after its last step
		end
		for st = from, to or (from - 1) do table.insert(out, { Id = id, St = st }) end
	end
	table.sort(out, function(a, b) return a.Id < b.Id or (a.Id == b.Id and a.St < b.St) end)
	return out
end

-- (pure) the words a non-card step closes with (my side's Lines, LinesBy's Default), + the hook after the last step
function StoryNpcs.EndLines(id, st, faction)
	local step, def = StoryNpcs.StepFor(id, st, faction)
	if type(step) ~= "table" or step.Panel == true then return {}, nil end
	local src = (type(step.LinesBy) == "table" and step.LinesBy.Default) or step.Lines
	local list = type(src) == "table" and (src[faction] or src.All) or nil
	local out = {}
	for _, l in type(list) == "table" and list or {} do
		if type(l) == "string" and l ~= "" then table.insert(out, l) end
	end
	local n = type(def) == "table" and type(def.Steps) == "table" and #def.Steps or 0
	local nx = (tonumber(st) == n and type(Config.QuestNext) == "function") and Config.QuestNext(def, faction) or nil
	if type(nx) == "table" and type(nx.Line) == "string" and nx.Line ~= "" then table.insert(out, nx.Line) end
	return out, nx
end

-- (pure) who says a line "Name: words": the NPC whose speaker name it is, else the step's Npc (On = "Self": me) ->
-- npc id or nil (= me), the words without the name when someone says them
function StoryNpcs.SpeakerOf(line, stepNpc)
	local name, words = string.match(line, "^([^:]+):%s*(.+)$")
	local names = type(Config.StoryQuests) == "table" and Config.StoryQuests.Speakers or {}
	if name then
		for id, shown in type(names) == "table" and names or {} do
			if shown == name then return id, words end
		end
		if type(stepNpc) == "string" then return stepNpc, words end
	end
	return stepNpc, (stepNpc and words) or line
end

-- the closing words of the steps that just ended, one bubble after another (a running queue)
function StoryNpcs.SayEnds(ends, faction)
	S.Talk = S.Talk or {}
	for _, e in ends do
		local step = StoryNpcs.StepFor(e.Id, e.St, faction)
		local lines, nx = StoryNpcs.EndLines(e.Id, e.St, faction)
		local npc = type(step) == "table" and step.On ~= "Self" and step.Npc or nil
		for _, l in lines do table.insert(S.Talk, { Line = l, Npc = npc }) end
		if nx and type(nx.Id) == "string" then pcall(StoryNpcs.ExpectNext, nx.Id) end
	end
	StoryNpcs.Say()
end

-- the bubble queue S.Talk ({ Line, Npc }), one after another (Talk.Seconds each); a running queue just grows
function StoryNpcs.Say()
	S.Talk = S.Talk or {}
	if S.Talking or #S.Talk == 0 then return end
	S.Talking = true
	task.spawn(function()
		while #S.Talk > 0 do
			local t = table.remove(S.Talk, 1)
			local id, words = StoryNpcs.SpeakerOf(t.Line, t.Npc)
			local body = type(id) == "string" and StoryNpcs.Body(id) or nil
			if not body then
				local me = game:GetService("Players").LocalPlayer
				body, words = me and me.Character, t.Line
			end
			local head = body and body:FindFirstChild("Head")
			if head and head:IsA("BasePart") then pcall(StoryNpcs.Bubble, head, words, T.Story.Talk.Seconds) end
			task.wait(T.Story.Talk.Seconds + 0.2)
		end
		S.Talking = false
	end)
end

------------------------------------------------------------------ A23-208 first mission (Config.Tutorial.Story)
-- QuestService fires Fx StoryScene { Id = "Tutorial", Key = "Find" / "Scene", Value, St = the step NAME }: Find = the
-- step's words over its NPC (Teacher = my side's teacher, Forge = Otto) as it starts; Scene = that NPC's move as it is
-- done. The Forge is the last step (A23-188): after Otto's move his Lines, then the hook to M1_1 (Next.Line, also his),
-- then the M1_1 asker's one hop when her "!" shows. The Before line sits in the guide's Welcome window (Panels)

-- (pure) the NpcId of first-mission step st for my side: Teacher = Config.Skills.Learn.Teachers, Forge = Otto
function StoryNpcs.TutorialNpc(st, faction)
	if st == "Forge" then return "Otto" end
	if st == "Teacher" then
		local L = type(Config.Skills) == "table" and Config.Skills.Learn or nil
		local id = type(L) == "table" and type(L.Teachers) == "table" and L.Teachers[faction] or nil
		return type(id) == "string" and id or nil
	end
	return nil
end

-- (pure) step st's story table (Config.Tutorial.Story.Steps[st]) and a field of it for my side
function StoryNpcs.TutorialField(st, field, faction)
	local story = type(Config.Tutorial) == "table" and Config.Tutorial.Story or nil
	local step = type(story) == "table" and type(story.Steps) == "table" and type(st) == "string" and story.Steps[st] or nil
	local v = type(step) == "table" and type(step[field]) == "table" and step[field][faction] or nil
	return v
end

-- (pure) what step st says when it is done (the Forge: Otto's Lines, then the hook to M1_1) -> lines, next { Id, Line }
function StoryNpcs.TutorialEnd(st, faction)
	local out = {}
	local lines = StoryNpcs.TutorialField(st, "Lines", faction)
	for _, l in type(lines) == "table" and lines or {} do
		if type(l) == "string" and l ~= "" then table.insert(out, l) end
	end
	local story = type(Config.Tutorial) == "table" and Config.Tutorial.Story or nil
	local nx = st == "Forge" and type(story) == "table" and type(story.Next) == "table" and story.Next[faction] or nil
	if type(nx) ~= "table" then return out, nil end
	if type(nx.Line) == "string" and nx.Line ~= "" then table.insert(out, nx.Line) end
	return out, nx
end

function StoryNpcs.TutorialFind(st, faction)
	local text = StoryNpcs.TutorialField(st, "Find", faction)
	local npc = StoryNpcs.TutorialNpc(st, faction)
	local body = type(text) == "string" and text ~= "" and npc and StoryNpcs.Body(npc) or nil
	local head = body and body:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then return false end
	return StoryNpcs.Bubble(head, text) ~= nil
end

function StoryNpcs.TutorialScene(scene, faction, st)
	local SK = type(Config.StoryQuests) == "table" and Config.StoryQuests.SceneKeys or nil
	local npc = StoryNpcs.TutorialNpc(st, faction)
	local m = npc and StoryNpcs.Body(npc) or nil
	local moved = false
	if m and type(scene) == "string" and type(SK) == "table" and SK[scene] then moved = StoryNpcs.Move(m, scene) end
	local lines, nx = StoryNpcs.TutorialEnd(st, faction)
	if #lines > 0 then
		S.Talk = S.Talk or {}
		-- Otto says them ("Otto: words" -> the words over his head; SpeakerOf maps his speaker name to another id)
		for _, l in lines do
			local words = string.match(l, "^[^:]+:%s*(.+)$")
			table.insert(S.Talk, { Line = words or l, Npc = npc })
		end
		StoryNpcs.Say()
	end
	if type(nx) == "table" and type(nx.Id) == "string" then pcall(StoryNpcs.ExpectNext, nx.Id) end
	return moved or #lines > 0
end

-- one pass: my story rows' steps -> the ended ones speak (the first pass after joining only remembers)
function StoryNpcs.WatchSteps(entries, faction)
	local now = {}
	for _, e in type(entries) == "table" and entries or {} do
		local st = type(e) == "table" and e.Story or nil
		if type(st) == "table" and type(st.Id) == "string" then
			now[st.Id] = { St = tonumber(st.St) or 0,
				Done = (tonumber(e.Progress) or 0) >= (tonumber(e.Target) or math.huge) and e.CanClaim == true }
		end
	end
	local ends = StoryNpcs.StepEnds(S.Steps, now, function(id)
		local _, def = StoryNpcs.StepFor(id, 1, faction)
		return type(def) == "table" and type(def.Steps) == "table" and #def.Steps or 0
	end)
	S.Steps = now
	if #ends > 0 then StoryNpcs.SayEnds(ends, faction) end
	return ends
end

-- one pass of the world pieces (Refresh calls it)
function StoryNpcs.RefreshWorld(entries, me)
	local spots = StoryNpcs.Spots(entries, me:GetAttribute("Faction"))
	local flags = StoryNpcs.FlagsOf(me:GetAttribute("StoryFlags"))
	pcall(StoryNpcs.DrawProps, spots, flags, me:GetAttribute("Faction"))
	pcall(StoryNpcs.DrawTools)
	pcall(StoryNpcs.ApplyFlags, flags)
	local root = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	pcall(StoryNpcs.DrawEmote, StoryNpcs.EmoteAt(spots, root and root.Position))
	-- walking over a thing to pick up takes it (once per Again s; the server checks the step and the distance)
	local brush = StoryNpcs.BrushPickup(spots, root and root.Position)
	if brush and os.clock() - (WS.Brushed[brush.Id] or -math.huge) >= T.Pickup.Again then
		WS.Brushed[brush.Id] = os.clock()
		local ok, remote = pcall(function() return game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):FindFirstChild("StoryAction") end)
		if ok and remote then remote:FireServer(brush.Id, "Pickup") end
	end
end

-- one pass: the "!" and the Talk prompt of each story NPC follow my rows
function StoryNpcs.Refresh()
	local hud = C and C.HUD
	local entries = nil
	if type(hud) == "table" and type(hud.QuestEntries) == "function" then
		local ok, list = pcall(hud.QuestEntries)
		if ok then entries = list end
	end
	local called = StoryNpcs.Called(entries)
	-- A23-193 (main Play 10/14: Sir Gleam's Talk prompt stayed off): the teacher of a ready skill is called too (server
	-- attributes SkillLearnReady > SkillSlots, SkillTeacher = the NpcId), so the "!" shows and the Talk press reaches
	-- SkillService.TryLearn
	local me = game:GetService("Players").LocalPlayer
	local marks = {}
	if me then
		local teacher = me:GetAttribute("SkillTeacher")
		local ready, slots = tonumber(me:GetAttribute("SkillLearnReady")) or 0, tonumber(me:GetAttribute("SkillSlots")) or 0
		if type(teacher) == "string" and teacher ~= "" and ready > slots then called[teacher] = true end
		-- A23-199: an NPC with a request for me shows the "!" and her Talk prompt (the press opens the Offer window)
		for id in StoryNpcs.Offers(me:GetAttribute("StoryOffers")) do called[id] = true end
		marks = StoryNpcs.Marks(entries, StoryNpcs.Offers(me:GetAttribute("StoryOffers")),
			(type(teacher) == "string" and teacher ~= "" and ready > slots) and teacher or nil)
		pcall(StoryNpcs.DrawPickups, StoryNpcs.Pickups(entries, me:GetAttribute("Faction")))
		pcall(StoryNpcs.RefreshWorld, entries, me) -- quest P1: dummies, practice tools, the lamp, the pose spot, saved looks
		-- ch1 data: a non-card step that ended says its closing words (an empty list = not loaded / between lists: wait)
		if type(entries) == "table" and #entries > 0 then pcall(StoryNpcs.WatchSteps, entries, me:GetAttribute("Faction")) end
		-- A23-208: the next asker's "!" shows after the hook to her quest: she hops once (waits while her body is away)
		local nx = S.Next
		if nx and os.clock() > nx.Until then
			S.Next = nil
		elseif nx and called[nx.Npc] and StoryNpcs.Body(nx.Npc) then
			S.Next = nil
			StoryNpcs.Hop(nx.Npc, 1)
		end
	end
	local tag = type(Config.StoryQuests) == "table" and Config.StoryQuests.NpcTag or "StoryNpc"
	local ok, list = pcall(function() return game:GetService("CollectionService"):GetTagged(tag) end)
	if not ok or type(list) ~= "table" then return end
	for _, model in list do
		if typeof(model) == "Instance" and model:IsDescendantOf(workspace) then
			local id = model:GetAttribute("NpcId")
			local on = type(id) == "string" and called[id] == true
			local bb = StoryNpcs.Mark(model)
			if bb then
				bb.Enabled = on
				if on then StoryNpcs.Paint(bb, marks[id] or { Text = T.MarkText, Main = false }) end
			end
			for _, d in model:GetDescendants() do
				if d:IsA("ProximityPrompt") and d:GetAttribute("StoryNpcId") ~= nil and d.Enabled ~= on then d.Enabled = on end
			end
		end
	end
end

local function makePickup(p)
	local P = T.Pickup
	local m = Instance.new("Model")
	m.Name = "Pickup_" .. p.Id
	m:SetAttribute("StoryId", p.Id)
	local y = groundAt(p.Pos) + P.Lift
	local box = Instance.new("Part")
	box.Name = "Box"
	box.Size, box.Color, box.Material = P.Size, P.Color, Enum.Material.SmoothPlastic
	box.CFrame = CFrame.new(p.Pos.X, y, p.Pos.Z)
	box.Anchored, box.CanCollide, box.CanQuery, box.CanTouch, box.CastShadow = true, false, false, false, false
	box.Parent = m
	local lid = Instance.new("Part")
	lid.Name = "Lid"
	lid.Size = Vector3.new(P.Size.X + 0.08, 0.22, P.Size.Z + 0.08)
	lid.Color, lid.Material = P.Lid, Enum.Material.SmoothPlastic
	lid.CFrame = box.CFrame * CFrame.new(0, P.Size.Y / 2 + 0.11, 0)
	lid.Anchored, lid.CanCollide, lid.CanQuery, lid.CanTouch, lid.CastShadow = true, false, false, false, false
	lid.Parent = m
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = P.Light, 8, 1.2
	light.Parent = box
	local spark = Instance.new("ParticleEmitter")
	spark.Name = "Sparkle"
	spark.Color = ColorSequence.new(P.Light)
	spark.LightEmission, spark.Rate = 0.8, 6
	spark.Lifetime = NumberRange.new(0.6, 1.1)
	spark.Speed = NumberRange.new(0.5, 1.5)
	spark.SpreadAngle = Vector2.new(180, 180)
	spark.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	spark.Parent = lid
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	local words = type(Config.StoryQuests.Text) == "table" and Config.StoryQuests.Text.Pickup or "Pick up"
	prompt.ActionText, prompt.ObjectText = words, ""
	prompt.MaxActivationDistance = math.min(P.Range, p.Radius + 1)
	prompt.HoldDuration = P.Hold
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("StoryPickup", p.Id)
	prompt.Parent = box
	m.PrimaryPart = box
	return m
end

-- the boxes follow the open Pickup steps (made once per step, removed when it closes)
function StoryNpcs.DrawPickups(list)
	local folder = workspace:FindFirstChild(T.Pickup.Folder)
	if #list == 0 and not folder then return 0 end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = T.Pickup.Folder
		folder.Parent = workspace
	end
	local want = {}
	for _, p in list do want[p.Id] = p end
	for _, m in folder:GetChildren() do
		local id = m:GetAttribute("StoryId")
		if not want[id] then m:Destroy() else want[id] = nil end
	end
	for _, p in want do makePickup(p).Parent = folder end
	return #folder:GetChildren()
end

-- a press on a box's prompt asks the server (it checks the step and the distance)
function StoryNpcs.OnPickup(prompt)
	local id = typeof(prompt) == "Instance" and prompt:GetAttribute("StoryPickup") or nil
	if type(id) ~= "string" then return false end
	local ok, remote = pcall(function() return game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):FindFirstChild("StoryAction") end)
	if ok and remote then remote:FireServer(id, "Pickup") end
	return true
end

-- 검수 10/10 (NPC review): a press on a story NPC's Talk prompt asked for this page, so the server's reply opens even
-- while Panels would make an auto-opened page wait (STORY.Busy) - like a tap on the quest row (Panels.ExpectStory)
function StoryNpcs.OnPrompt(prompt)
	local id = typeof(prompt) == "Instance" and prompt:GetAttribute("StoryNpcId") or nil
	if id == nil then return false end
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.ExpectStory) ~= "function" then return false end
	pcall(panels.ExpectStory, tostring(id))
	return true
end

function StoryNpcs.Init(registry)
	C = registry
end

function StoryNpcs.Start()
	if S.Started then return end
	S.Started = true
	task.spawn(function()
		while true do
			local ok, err = pcall(StoryNpcs.Refresh)
			if not ok then Util.Warn(TAG, "refresh failed: " .. tostring(err)) end
			task.wait(T.Every)
		end
	end)
	pcall(function()
		game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
			if not StoryNpcs.OnPickup(prompt) then StoryNpcs.OnPrompt(prompt) end
		end)
	end)
	-- quest P1: a swing near a dummy wobbles it; a scene plays the moment a pick is written
	pcall(function()
		Net.Get("Fx").OnClientEvent:Connect(function(kind, data)
			if kind == "Swing" then
				pcall(StoryNpcs.OnSwing, data)
			elseif kind == "StoryScene" then
				pcall(StoryNpcs.Scene, data)
				task.defer(function() pcall(StoryNpcs.Refresh) end)
			end
		end)
	end)
	-- a quest list change shows / hides at once (the pass above catches NPCs that arrive later)
	local hud = C and C.HUD
	if type(hud) == "table" and type(hud.QuestsChanged) == "table" and type(hud.QuestsChanged.Connect) == "function" then
		hud.QuestsChanged:Connect(function() pcall(StoryNpcs.Refresh) end)
	end
end

return StoryNpcs
