-- MonsterMotion.luau : plays Tripo-made monster clips (Idle / Walk / Slash / Hurt / Fall) on rigged monster visuals by
-- writing Bone.Transform every frame on this client only. The clips are data modules made by
-- tools/glb_anim_to_luau.py in ReplicatedStorage.MonsterAnims ("<MonsterKind>_<Clip>"), so no Roblox animation asset
-- upload is needed. Only monsters near the camera move. Unrigged monsters keep Fx's procedural wobble.
--   moving -> Walk (loop, played as fast as the monster really walks; Run at its chase pace), still -> Idle (loop)
--   with one LookAround now and then, attack -> Slash once, HurtSeq bump -> Hurt once, dying (anchored root) -> Fall
--   once, faster, and hold the last frame (Leaving = Idle). Changes cross-fade over BLEND seconds.
-- Monster motion review 2026-10-06 (docs/design/monster_motion_survey_2026-10-06.md 4-1): every attack restarts Slash
-- (it used to freeze on its last frame when two attacks came back to back); Slash starts at the wind-up (WindupAt) and
-- skips its first part so the clip's fastest frame (HitTime) lands on the impact (wind-up end) instead of ~1.1 s after
-- the damage; loops start at each monster's own phase and speed (a group never moves in step).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)

local MonsterMotion = {}
local C = nil

local M = {
	Range = 130, -- studs from the camera
	Blend = 0.15,
	HurtMax = 0.6, -- a hit reaction never plays longer than this
	FallRate = 1.8, -- the fall plays this much faster (the server keeps the body ~1.1 s: MonsterService DEATH)
	FallImpactAt = 0.5, -- s after death when the fall's fastest frame (hitting the ground) shows
	WalkRate = { Min = 0.45, Max = 1.5 }, -- Walk / Run speed = real flat speed / the kind's chase Speed, clamped
	RunAbove = 0.75, -- at this share of the chase Speed or more it runs (Run clip, ab7e7a5); a wander walks at half
	LookEvery = { 6, 12 }, -- s between two LookAround clips of a standing monster (its own rhythm)
	Jitter = 0.08, -- each monster's loops run +-8% faster / slower
	SlashFresh = 1.2, -- s: an AttackSeq this soon after a seen wind-up belongs to that wind-up (no restart)
	Clips = { "Idle", "Walk", "Run", "LookAround", "Slash", "Hurt", "Fall" },
	Cache = {}, -- ["Goblin_Walk"] = clip table | false
	State = {}, -- [model] = per-monster state
}

-- s into a clip where its bones turn fastest (the swing's contact), measured once per clip
function M.HitTime(clip)
	if clip.HitTime then return clip.HitTime end
	local best, bestI = -1, 0
	for i = 0, clip.Frames - 2 do
		local sum = 0
		for _, entry in clip.Bones do
			local r = entry.r
			local dot = r[i * 4 + 1] * r[i * 4 + 5] + r[i * 4 + 2] * r[i * 4 + 6] + r[i * 4 + 3] * r[i * 4 + 7]
				+ r[i * 4 + 4] * r[i * 4 + 8]
			sum += 2 * math.acos(math.min(1, math.abs(dot)))
		end
		if sum > best then best, bestI = sum, i end
	end
	clip.HitTime = (bestI + 0.5) / (clip.Fps or 15)
	return clip.HitTime
end

-- the wind-up length of a monster (attribute WindupTime, else Config.HitReact.MonsterWindup)
function M.Windup(model)
	local v = model:GetAttribute("WindupTime")
	if type(v) == "number" and v > 0 then return v end
	local react = Config.HitReact
	return type(react) == "table" and tonumber(react.MonsterWindup) or 0.28
end

local function clipFor(kind, name)
	local key = kind .. "_" .. name
	local cached = M.Cache[key]
	if cached ~= nil then return cached or nil end
	local folder = ReplicatedStorage:FindFirstChild("MonsterAnims")
	local mod = folder and folder:FindFirstChild(key)
	local ok, data = false, nil
	if mod and mod:IsA("ModuleScript") then ok, data = pcall(require, mod) end
	if ok and type(data) == "table" and type(data.Bones) == "table" and (data.Frames or 0) > 1 then
		data.Length = (data.Frames - 1) / (data.Fps or 15)
		M.Cache[key] = data
		return data
	end
	M.Cache[key] = false
	return nil
end

-- pose of one bone in a clip at time t (seconds), interpolated between frames
local function pose(clip, entry, t, scale)
	local fps = clip.Fps or 15
	local last = clip.Frames - 1
	local x = math.clamp(t * fps, 0, last)
	local i = math.floor(x)
	local u = x - i
	local j = math.min(i + 1, last)
	local r = entry.r
	local a = CFrame.new(0, 0, 0, r[i * 4 + 1], r[i * 4 + 2], r[i * 4 + 3], r[i * 4 + 4])
	local b = CFrame.new(0, 0, 0, r[j * 4 + 1], r[j * 4 + 2], r[j * 4 + 3], r[j * 4 + 4])
	local cf = a:Lerp(b, u)
	local p = entry.p
	if p then
		local pa = Vector3.new(p[i * 3 + 1], p[i * 3 + 2], p[i * 3 + 3])
		local pb = Vector3.new(p[j * 3 + 1], p[j * 3 + 2], p[j * 3 + 3])
		cf = CFrame.new(pa:Lerp(pb, u) * scale) * cf
	end
	return cf
end

-- a new attack: Slash restarts at clip time `from` (token bump = restart even when Slash is already playing)
local function startSlash(st, clip, from)
	st.SlashToken += 1
	st.SlashFrom = math.clamp(from, 0, clip.Length)
	st.AttackUntil = os.clock() + (clip.Length - st.SlashFrom)
end

local function track(model)
	local kind = model:GetAttribute("MonsterKind")
	local visual = model:FindFirstChild("CustomVisual")
	if type(kind) ~= "string" or not visual then return false end
	if not clipFor(kind, "Idle") and not clipFor(kind, "Walk") then return false end
	local bones = {}
	for _, d in visual:GetDescendants() do
		if d:IsA("Bone") then bones[d.Name] = d end
	end
	if next(bones) == nil then return false end
	local okScale, scale = pcall(visual.GetScale, visual)
	local def = Config.MonsterTypes and Config.MonsterTypes[kind]
	local st = {
		Kind = kind, Bones = bones, Scale = (okScale and type(scale) == "number") and scale or 1,
		Root = model:FindFirstChild("HumanoidRootPart"), Clip = nil, T = 0, Once = false,
		From = nil, BlendT = 0, AttackUntil = 0, HurtUntil = 0, Active = false, Model = model,
		Speed = def and tonumber(def.Speed) or 12, -- the kind's chase speed (the Walk clip's natural pace)
		Phase = math.random(), Rate = 1 + (math.random() * 2 - 1) * M.Jitter, -- own loop phase / speed
		SlashToken = 0, SlashFrom = 0, PlayToken = nil, SlashSeenAt = -math.huge,
		LookUntil = 0, Looks = 0,
	}
	st.LookAt = os.clock() + 2 + 6 * st.Phase -- the first LookAround: 2-8 s after it shows up (own rhythm)
	-- the wind-up starts the swing so that its fastest frame meets the impact (wind-up end)
	model:GetAttributeChangedSignal("WindupAt"):Connect(function()
		local c = clipFor(kind, "Slash")
		local v = model:GetAttribute("WindupAt")
		if not c or type(v) ~= "number" or v <= 0 then return end
		local okNow, serverNow = pcall(function() return workspace:GetServerTimeNow() end)
		local elapsed = (okNow and type(serverNow) == "number") and math.max(0, serverNow - v) or 0
		local toImpact = math.max(0, M.Windup(model) - elapsed)
		startSlash(st, c, M.HitTime(c) - toImpact)
		st.SlashSeenAt = os.clock()
	end)
	-- the impact: a swing already started by its wind-up goes on; otherwise (wind-up missed) show the follow-through
	model:GetAttributeChangedSignal("AttackSeq"):Connect(function()
		local c = clipFor(kind, "Slash")
		if not c or os.clock() - st.SlashSeenAt <= M.SlashFresh then return end
		startSlash(st, c, M.HitTime(c))
	end)
	model:GetAttributeChangedSignal("HurtSeq"):Connect(function()
		local c = clipFor(kind, "Hurt")
		if c then st.HurtUntil = os.clock() + math.min(M.HurtMax, c.Length) end
	end)
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then M.State[model] = nil end
	end)
	M.State[model] = st
	return st
end

-- the current pose of every animated bone (used as the "from" side of a cross-fade)
local function snapshot(st)
	local snap = {}
	for name, bone in st.Bones do snap[name] = bone.Transform end
	return snap
end

-- switches clip (cross-fade); `token` restarts the same clip when it changed; loops start at the monster's own phase
local function play(st, name, once, clip, token, from)
	if st.Clip == name and st.PlayToken == token then return end
	st.From = snapshot(st)
	st.BlendT = 0
	st.Clip = name
	st.T = from or (once and 0 or st.Phase * clip.Length)
	st.Once = once
	st.PlayToken = token
end

local function rest(st)
	if not st.Active then return end
	st.Active = false
	for _, bone in st.Bones do bone.Transform = CFrame.identity end
	st.Clip = nil
end

local function step(dt)
	local cam = workspace.CurrentCamera
	local folder = workspace:FindFirstChild("Monsters")
	if not cam or not folder then return end
	local camPos = cam.CFrame.Position
	local now = os.clock()
	for _, model in folder:GetChildren() do
		local st = M.State[model]
		if st == nil and model:IsA("Model") then
			st = track(model)
			if st == false then
				M.State[model] = false
				-- review C-7: an untrackable model (no clips) is forgotten when it leaves, so the table never grows
				model.AncestryChanged:Connect(function(_, parent)
					if parent == nil then M.State[model] = nil end
				end)
			end
		end
		if st and st.Root and st.Root.Parent then
			if (st.Root.Position - camPos).Magnitude > M.Range then
				rest(st)
			else
				st.Active = true
				-- choose the clip and how fast it runs
				local want, once, rate = "Idle", false, st.Rate
				local v = st.Root.AssemblyLinearVelocity
				local flat2 = v.X * v.X + v.Z * v.Z
				if st.Root.Anchored then
					-- dying: fall (faster); an event monster going home (Leaving) floats away calmly instead
					if model:GetAttribute("Leaving") == true then
						want = "Idle"
					else
						want, once, rate = "Fall", true, M.FallRate
					end
				elseif now < st.AttackUntil then
					want, once, rate = "Slash", true, 1
					st.LookUntil = 0
				elseif now < st.HurtUntil then
					want, once, rate = "Hurt", true, 1
					st.LookUntil = 0
				elseif flat2 > 2.25 then
					st.LookUntil = 0
					local ratio = math.sqrt(flat2) / math.max(st.Speed, 1)
					want = (ratio >= M.RunAbove and clipFor(st.Kind, "Run")) and "Run" or "Walk" -- chase runs, wander walks
					rate = st.Rate * math.clamp(ratio, M.WalkRate.Min, M.WalkRate.Max)
				else
					-- standing: now and then one LookAround (two head turns), then Idle again
					if now >= st.LookAt then
						local look = clipFor(st.Kind, "LookAround")
						if look then st.LookUntil = now + look.Length / st.Rate end
						st.Looks += 1
						st.LookAt = now + (look and look.Length or 0) + M.LookEvery[1]
							+ (M.LookEvery[2] - M.LookEvery[1]) * ((st.Phase + st.Looks * 0.618) % 1)
					end
					if now < st.LookUntil then want, once = "LookAround", true end
				end
				if not clipFor(st.Kind, want) then want, once, rate = "Idle", false, st.Rate end
				local clip = clipFor(st.Kind, want)
				if clip then
					if want == "Slash" then
						play(st, want, once, clip, st.SlashToken, st.SlashFrom)
					elseif want == "Fall" then
						-- skip the start so the body hits the ground FallImpactAt s after death, before the fade
						play(st, want, once, clip, nil, math.max(0, M.HitTime(clip) - M.FallImpactAt * M.FallRate))
					else
						play(st, want, once, clip, nil, nil)
					end
					st.T += dt * rate
					local t = st.T
					if once then t = math.min(t, clip.Length) else t = t % math.max(clip.Length, 0.05) end
					st.BlendT += dt
					local w = math.clamp(st.BlendT / M.Blend, 0, 1)
					for name, bone in st.Bones do
						local entry = clip.Bones[name]
						local target = entry and pose(clip, entry, t, st.Scale) or CFrame.identity
						if w < 1 and st.From and st.From[name] then
							target = st.From[name]:Lerp(target, w)
						end
						bone.Transform = target
					end
				end
			end
		end
	end
end

-- read-only view for the offline test (tools/test_monster_motion.py): clip choice, clip time, slash restarts
MonsterMotion.Debug = M

-- Fx's procedural wobble skips monsters this module animates
function MonsterMotion.IsRigged(model)
	local st = M.State[model]
	return st ~= nil and st ~= false
end

function MonsterMotion.Init(c)
	C = c
end

function MonsterMotion.Start()
	RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(step, dt)
		if not ok and not M.Warned then
			M.Warned = true
			warn("[MonsterMotion] " .. tostring(err))
		end
	end)
	print("[MonsterMotion] started")
end

return MonsterMotion
