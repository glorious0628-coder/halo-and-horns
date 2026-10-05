-- MonsterMotion.luau : plays Tripo-made monster clips (Idle / Walk / Slash / Hurt / Fall) on rigged monster visuals by
-- writing Bone.Transform every frame on this client only. The clips are data modules made by
-- tools/glb_anim_to_luau.py in ReplicatedStorage.MonsterAnims ("<MonsterKind>_<Clip>"), so no Roblox animation asset
-- upload is needed. Only monsters near the camera move. Unrigged monsters keep Fx's procedural wobble.
--   moving -> Walk (loop), still -> Idle (loop), AttackSeq bump -> Slash once, HurtSeq bump -> Hurt once,
--   dying (anchored root) -> Fall once and hold the last frame. Changes cross-fade over BLEND seconds.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MonsterMotion = {}
local C = nil

local M = {
	Range = 130, -- studs from the camera
	Blend = 0.15,
	HurtMax = 0.6, -- a hit reaction never plays longer than this
	Clips = { "Idle", "Walk", "Slash", "Hurt", "Fall" },
	Cache = {}, -- ["Goblin_Walk"] = clip table | false
	State = {}, -- [model] = per-monster state
}

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
	local st = {
		Kind = kind, Bones = bones, Scale = (okScale and type(scale) == "number") and scale or 1,
		Root = model:FindFirstChild("HumanoidRootPart"), Clip = nil, T = 0, Once = false,
		From = nil, BlendT = 0, AttackUntil = 0, HurtUntil = 0, Active = false,
	}
	model:GetAttributeChangedSignal("AttackSeq"):Connect(function()
		local c = clipFor(kind, "Slash")
		if c then st.AttackUntil = os.clock() + c.Length end
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

local function play(st, name, once)
	if st.Clip == name then return end
	st.From = snapshot(st)
	st.BlendT = 0
	st.Clip = name
	st.T = 0
	st.Once = once
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
			if st == false then M.State[model] = false end
		end
		if st and st.Root and st.Root.Parent then
			if (st.Root.Position - camPos).Magnitude > M.Range then
				rest(st)
			else
				st.Active = true
				-- choose the clip
				local want, once = "Idle", false
				local v = st.Root.AssemblyLinearVelocity
				if st.Root.Anchored then
					want, once = "Fall", true
				elseif now < st.AttackUntil then
					want, once = "Slash", true
				elseif now < st.HurtUntil then
					want, once = "Hurt", true
				elseif v.X * v.X + v.Z * v.Z > 2.25 then
					want = "Walk"
				end
				if not clipFor(st.Kind, want) then want, once = "Idle", false end
				local clip = clipFor(st.Kind, want)
				if clip then
					play(st, want, once)
					st.T += dt
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
