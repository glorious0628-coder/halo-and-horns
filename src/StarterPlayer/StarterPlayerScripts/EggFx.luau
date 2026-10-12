-- EggFx.luau : A23-131 / A23-134 황금 알 줍기, the client side (게임성 개발 1; the server is 게임성 개발 2's GooseEggs).
-- Contract: docs/design/golden_egg_contract_2026-10-11.md (design docs/design/golden_egg_2026-10-11.md). The server keeps
-- one anchored part per ground egg in workspace.Effects.GooseEggs (CFrame = where it lands; attributes Id, Kind, Points,
-- From, LandAt) and sends no remote per egg. This module draws, for every such part, a local copy (the server part is
-- hidden with LocalTransparencyModifier) that flies from From to its spot by LandAt with a round shadow under it, then
-- rests (the bouncy egg bobs, the big egg breathes, the crown egg turns inside a round soft glow) and sparkles near the
-- camera; an egg I cannot pick (my EggCan false) shows see-through. Walking onto a landed egg with room for it hides it
-- at once with a pop (the pickup PREVIEW; it shows again if the server still has it PredictHold s later). Also: my own
-- home ring (only I see it, brighter while I carry eggs), the ring boundary as a circle of round dots, the goose's "!" /
-- "Zzz" from its Act attribute, the returned eggs flying back to the goose (Fx EggReturn), my delivery's "+N" and the
-- eggs flying into my home (Fx EggDeliver), a tag pop (Fx EggTag), the round shield of EggShield, my carried stack
-- wobbling near the ring edge / when I stand still (its EggJoint Motor6D's Transform) and confetti at the winner's home
-- (Fx GooseEnd). Sounds go through Audio (EggPlop / EggPickup / EggBoing / CrownEgg / GooseSnore, their stand-ins until
-- the files exist). No text but the "!" / "Zzz" / "+N" marks (Config.GooseEggFx.Text), no rays (the 10/07 rule).
-- Only in Config.Goose.Mode "Eggs"; the pure helpers (Arc, CanPick, Wobble, Bar, TickEnd, HomeOf) are tested offline
-- (tools/test_egg_fx.py).
-- A23-141 Goose Square (contract docs/design/goose_square_contract_2026-10-12.md): the egg play is in a separate square
-- off the map and only for players who pressed Join. Every screen above works only while EggFx.Here() (Eggs mode + my
-- InGooseSquare attribute); outside, they are off / return nil. This module also owns the Join / Leave button's data
-- (SquareButton / SquarePress: the one remote it fires, GooseSquare, looked up without waiting) and the short screen
-- fade when InGooseSquare changes (Fade). EventHUD draws the button.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Ground = require(Shared:WaitForChild("Ground"))

local EggFx = {}
local LocalPlayer = Players.LocalPlayer
local C = nil
local S = {
	Eggs = {}, -- [server part] = rec
	Hidden = {}, -- [egg Id] = server time the preview hid it
	Gone = {}, -- [{ To, Returned }] = true: removed ground eggs waiting GoneWait s for an EggReturn
	Denied = {}, -- [egg Id] = server time a preview came back (the server kept the egg): no new try for RetryAfter s
	Trail = {}, -- { { T, Pos } }: my root over the last MoveWindow s
	Folder = nil, Home = nil, Dots = {}, Icon = nil, Shields = {}, Flights = {},
	Picked = false, -- I picked an egg this event (the last 3-2-1 ticks are for the pickers)
	MineAt = -math.huge, -- os.clock() my EggCarry last rose
	Carry = 0, StillAt = nil, StillPos = nil, WasActive = false,
}

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default
end

local function serverNow()
	local ok, t = pcall(function() return workspace:GetServerTimeNow() end)
	return ok and t or os.clock()
end

-- the server's table (values: 게임성 개발 2) and this module's look (Config.GooseEggFx), read when used
local function eggCfg()
	local g = type(Config.Goose) == "table" and Config.Goose or {}
	return type(g.Egg) == "table" and g.Egg or {}
end

local function lookCfg()
	return type(Config.GooseEggFx) == "table" and Config.GooseEggFx or {}
end

----------------------------------------------------------------- pure helpers (tested offline)
function EggFx.On()
	return type(Config.Goose) == "table" and Config.Goose.Mode == "Eggs"
end

-- A23-141 Goose Square (contract docs/design/goose_square_contract_2026-10-12.md): the golden-egg play is in a separate
-- square off the map; only players who pressed Join are there (the server sets my InGooseSquare attribute). Every egg
-- screen below works only while EggFx.Here(). Names: Config.Goose.Square.
local function squareCfg()
	return type(Config.Goose) == "table" and type(Config.Goose.Square) == "table" and Config.Goose.Square or {}
end

local function squareName(key, default)
	local v = squareCfg()[key]
	return type(v) == "string" and v ~= "" and v or default
end

-- my InGooseSquare attribute (the server's; true = I am in the square)
function EggFx.Inside()
	return LocalPlayer:GetAttribute(squareName("Attr", "InGooseSquare")) == true
end

-- the egg screens' gate: the Eggs mode and I am in the square
function EggFx.Here()
	return EggFx.On() and EggFx.Inside()
end

-- the c->s RemoteEvent, looked up without waiting (it may not exist yet: nil = the button is dimmed and does nothing)
function EggFx.SquareRemote()
	local r = S.SquareRemote
	if r ~= nil and r.Parent ~= nil then return r end
	S.SquareRemote = nil
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local found = folder and folder:FindFirstChild(squareName("Remote", "GooseSquare"))
	if found ~= nil and found:IsA("RemoteEvent") then
		S.SquareRemote = found
		return found
	end
	return nil
end

-- what the button needs to know, read from the world now
function EggFx.SquareCtx()
	local gs = ReplicatedStorage:FindFirstChild("GameState")
	return { Active = gs ~= nil and gs:GetAttribute("GooseActive") == true, Inside = EggFx.Inside(),
		Block = LocalPlayer:GetAttribute(squareName("Block", "GooseJoinBlock")), HasRemote = EggFx.SquareRemote() ~= nil }
end

-- the Join / Leave button of the goose chip. ctx = { Active (the event is open), Inside, Block (my GooseJoinBlock), HasRemote }
-- -> nil (hidden: no event, or not the Eggs mode) | { Word = "Join" | "Leave", Dim }. Leave while I am inside (dimmed only
-- without the remote); Join otherwise, dimmed by a non-empty Block or without the remote (A23-130: a dimmed press says nothing)
function EggFx.SquareButton(ctx)
	if type(ctx) ~= "table" or ctx.Active ~= true or not EggFx.On() then return nil end
	local noRemote = ctx.HasRemote ~= true
	if ctx.Inside == true then return { Word = "Leave", Dim = noRemote } end
	return { Word = "Join", Dim = noRemote or (type(ctx.Block) == "string" and ctx.Block ~= "") }
end

-- a press: fires the remote once with "Join" / "Leave"; nothing while the button is dimmed / hidden / the other word, and
-- a second press within RateLimits.GooseSquare s (else 1) is dropped. now = os.clock() (a test passes its own)
function EggFx.SquarePress(word, now)
	if word ~= "Join" and word ~= "Leave" then return false end
	local b = EggFx.SquareButton(EggFx.SquareCtx())
	if not b or b.Dim or b.Word ~= word then return false end
	local remote = EggFx.SquareRemote()
	if not remote then return false end
	now = num(now, os.clock())
	local gap = num(type(Config.RateLimits) == "table" and Config.RateLimits.GooseSquare, 1)
	if now - (S.SquareAt or -math.huge) < gap then return false end
	S.SquareAt = now
	local ok = pcall(function() remote:FireServer(word) end)
	return ok
end

-- my InGooseSquare changed (either way): the short screen fade, once per change (the same value again = nothing)
function EggFx.SquareChanged()
	local inside = EggFx.Inside()
	if (S.SquareIn == true) == inside then return false end
	S.SquareIn = inside
	pcall(EggFx.Fade)
	return true
end
-- where a flying egg is at server time now: from -> to over the FlyTime s before landAt, a parabola whose peak is
-- clamp(distance x k, min, max) studs. -> position, landed (true once now >= landAt)
function EggFx.Arc(from, to, landAt, flyTime, now, arc)
	if typeof(to) ~= "Vector3" then return nil, true end
	if typeof(from) ~= "Vector3" or now >= landAt then return to, true end
	flyTime = math.max(num(flyTime, 0.7), 0.05)
	local k = math.clamp(1 - (landAt - now) / flyTime, 0, 1)
	arc = type(arc) == "table" and arc or {}
	local peak = math.clamp((to - from).Magnitude * num(arc[1], 0.35), num(arc[2], 1.5), num(arc[3], 6))
	return from:Lerp(to, k) + Vector3.new(0, 4 * peak * k * (1 - k), 0), false
end

-- can I pick this egg now (the preview; the server decides)? egg = { Pos, LandAt, Kind }, me = { Pos, Can, Carry,
-- Moved }, cfg = Config.Goose.Egg. A 3-slot egg (big / crown) only with empty hands, else carry + its slots <=
-- MaxSlots; flat distance <= PickRadius and height <= PickHeight; only once it has landed; Moved = false (I did not move
-- 1 stud in the last 0.5 s: the server's away rule) = no.
function EggFx.CanPick(egg, me, cfg, now)
	if type(egg) ~= "table" or type(me) ~= "table" or me.Can ~= true or me.Moved == false then return false end
	if typeof(egg.Pos) ~= "Vector3" or typeof(me.Pos) ~= "Vector3" then return false end
	if now < num(egg.LandAt, 0) then return false end
	cfg = type(cfg) == "table" and cfg or {}
	local kinds = type(cfg.Kinds) == "table" and cfg.Kinds or {}
	local def = type(kinds[egg.Kind]) == "table" and kinds[egg.Kind] or {}
	local slots, max = num(def.Slots, 1), num(cfg.MaxSlots, 3)
	local carry = math.max(0, num(me.Carry, 0))
	if slots >= max then
		if carry > 0 then return false end
	elseif carry + slots > max then
		return false
	end
	local d = me.Pos - egg.Pos
	return Vector3.new(d.X, 0, d.Z).Magnitude <= num(cfg.PickRadius, 4.5) and math.abs(d.Y) <= num(cfg.PickHeight, 6)
end

-- how hard my carried stack wobbles (0..1): from WobbleFrom studs off the ring centre up to RingRadius, and from
-- IdleWobble s standing still up to IdleReturn (the server takes the eggs back there); the larger of the two
function EggFx.Wobble(distance, stillFor, cfg)
	cfg = type(cfg) == "table" and cfg or {}
	local from, ring = num(cfg.WobbleFrom, 45), num(cfg.RingRadius, 54)
	local a = ring > from and math.clamp((num(distance, 0) - from) / (ring - from), 0, 1) or 0
	local i0, i1 = num(cfg.IdleWobble, 7), num(cfg.IdleReturn, 10)
	local b = i1 > i0 and math.clamp((num(stillFor, 0) - i0) / (i1 - i0), 0, 1) or 0
	return math.max(a, b)
end

-- my home point (Config.Goose.Egg.Home[faction]) or nil (no home: None, or the Guild without one)
function EggFx.HomeOf(faction, cfg)
	cfg = type(cfg) == "table" and cfg or {}
	local homes = type(cfg.Home) == "table" and cfg.Home or {}
	local h = type(faction) == "string" and homes[faction] or nil
	return typeof(h) == "Vector3" and h or nil
end

-- the end the last 3-2-1 counts to: the crown egg's overtime when it runs, else the event's end
function EggFx.TickEnd(endsAt, overtimeUntil, now)
	local ot = num(overtimeUntil, 0)
	if ot > now then return ot, true end
	return num(endsAt, 0), false
end

-- the top bar in Eggs mode (EventHUD draws it). a = { Rescue, Poach, EndsAt, OvertimeUntil, Mode, CoopSide,
-- CoopTarget }. -> { Coop, Side, Left, Right, Fill (0..1 of the Halo / co-op fill), Seconds, Overtime }; nil outside
-- the Goose Square (no egg bar in the real plaza)
function EggFx.Bar(a, now)
	if not EggFx.Here() then return nil end
	a = type(a) == "table" and a or {}
	local halo = math.max(0, math.floor(num(a.Rescue, 0) + 0.5))
	local horns = math.max(0, math.floor(num(a.Poach, 0) + 0.5))
	local endAt, over = EggFx.TickEnd(a.EndsAt, a.OvertimeUntil, now)
	local out = { Seconds = math.max(0, endAt - now), Overtime = over }
	if a.Mode == "Coop" and (a.CoopSide == "Halo" or a.CoopSide == "Horns") then
		local total = a.CoopSide == "Halo" and halo or horns
		local target = math.max(1, math.floor(num(a.CoopTarget, 1)))
		out.Coop, out.Side = true, a.CoopSide
		out.Left, out.Right = total, target
		out.Fill = math.clamp(total / target, 0, 1)
	else
		out.Coop = false
		out.Left, out.Right = halo, horns
		out.Fill = (halo + horns) > 0 and halo / (halo + horns) or 0.5
	end
	return out
end

----------------------------------------------------------------- world pieces
local function folder()
	if S.Folder and S.Folder.Parent then return S.Folder end
	local f = workspace:FindFirstChild("EggFxLocal")
	if not f then
		f = Instance.new("Folder")
		f.Name = "EggFxLocal"
		f.Parent = workspace
	end
	S.Folder = f
	return f
end

local function quiet(p)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	return p
end

local function ball(name, size, color, alpha, material)
	local p = quiet(Instance.new("Part"))
	p.Name = name
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(size, size, size)
	p.Color = color
	p.Material = material or Enum.Material.Neon
	p.Transparency = alpha
	p.Parent = folder()
	return p
end

local function disc(name, radius, color, alpha)
	local p = quiet(Instance.new("Part"))
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.1, radius * 2, radius * 2)
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency = alpha
	p.Parent = folder()
	return p
end

local FLAT = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder lying flat

local function groundY(pos)
	local hit = Ground.Cast(pos, 4, 40)
	return hit and hit.Position.Y or pos.Y
end

-- the look of a kind (Config.GooseEggFx.Kinds), with defaults
local function kindLook(kind)
	local kinds = type(lookCfg().Kinds) == "table" and lookCfg().Kinds or {}
	return type(kinds[kind]) == "table" and kinds[kind] or (type(kinds.Gold) == "table" and kinds.Gold or {})
end

-- the local copy of a server egg: its own look when it has one (a MeshPart / a part with a mesh), else a code egg
local function makeVisual(part, kind)
	local lk = kindLook(kind)
	local v
	local ok = pcall(function()
		local mesh = part:FindFirstChildOfClass("SpecialMesh")
		if part:IsA("MeshPart") or mesh then
			v = part:Clone()
			v:ClearAllChildren() -- the look stays on the part (MeshId / TextureID) + its mesh / surface; no welds, lights
			if mesh then mesh:Clone().Parent = v end
			local sa = part:FindFirstChildOfClass("SurfaceAppearance")
			if sa then sa:Clone().Parent = v end
		end
	end)
	if not ok or not v then
		local size = num(lk.Size, 1.2)
		v = Instance.new("Part")
		v.Size = Vector3.new(size, size * 1.3, size)
		v.Color = lk.Color or Color3.fromRGB(255, 205, 60)
		v.Material = Enum.Material.SmoothPlastic
		v.Reflectance = 0.15
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = v
	end
	quiet(v)
	v.Name = "Egg_" .. tostring(kind)
	v.Transparency = 0
	v.Parent = folder()
	local sp = Instance.new("ParticleEmitter") -- small round sparkles, only near the camera (Step turns it on)
	sp.Name = "Sparkle"
	sp.Rate = num(lk.Sparkle, 3)
	sp.Lifetime = NumberRange.new(0.5, 0.9)
	sp.Speed = NumberRange.new(0.5, 1.2)
	sp.SpreadAngle = Vector2.new(180, 180)
	sp.Size = NumberSequence.new(0.18, 0)
	sp.LightEmission = 1
	sp.Color = ColorSequence.new(Color3.fromRGB(255, 240, 180))
	sp.Enabled = false
	sp.Parent = v
	local glow
	if num(lk.Glow, 0) > 0 then -- the crown egg's round soft glow (no PointLight / Highlight: design 빠진 것 §성능)
		glow = ball("EggGlow", num(lk.Glow, 4), lk.Color or Color3.fromRGB(255, 235, 150), num(lk.GlowAlpha, 0.85))
	end
	return v, sp, glow
end

local function attr(part, name)
	local ok, v = pcall(function() return part:GetAttribute(name) end)
	return ok and v or nil
end

local function myRoot()
	local ch = LocalPlayer.Character
	return ch and ch:FindFirstChild("HumanoidRootPart") or nil
end

local function camPos()
	local cam = workspace.CurrentCamera
	return cam and cam.CFrame.Position or nil
end

local function near(pos, range)
	local c = camPos()
	return c ~= nil and typeof(pos) == "Vector3" and (c - pos).Magnitude <= range
end

local function play(event, opts, standIn)
	if not EggFx.Here() then return end -- no egg sound outside the Goose Square
	local audio = C and C.Audio
	if type(audio) ~= "table" or type(audio.Play) ~= "function" then return end
	local ok, played = pcall(audio.Play, event, opts)
	if (not ok or not played) and standIn then pcall(audio.Play, standIn, opts) end
end

-- another player's egg sound: only SoundRange studs near me
local function playNear(pos, event, standIn)
	local root = myRoot()
	if not root or typeof(pos) ~= "Vector3" then return end
	if (root.Position - pos).Magnitude > num(lookCfg().SoundRange, 30) then return end
	play(event, { Others = true }, standIn)
end

----------------------------------------------------------------- ground eggs
local function plan(rec)
	rec.Kind = attr(rec.Part, "Kind") or "Gold"
	rec.Id = attr(rec.Part, "Id")
	rec.From = attr(rec.Part, "From")
	rec.LandAt = num(attr(rec.Part, "LandAt"), 0)
	rec.To = rec.Part.Position
	rec.Rest = rec.Part.CFrame
	rec.Plopped = serverNow() >= rec.LandAt -- already down when I first saw it: no plop
	if typeof(rec.From) == "Vector3" and not rec.Plopped then
		local r = num(kindLook(rec.Kind).Size, 1.2) * 0.6
		if not rec.Shadow then rec.Shadow = disc("EggShadow", r, Color3.fromRGB(40, 30, 20), 1) end
		rec.Shadow.CFrame = CFrame.new(rec.To.X, groundY(rec.To) + 0.06, rec.To.Z) * FLAT
	end
end

local function addEgg(part)
	if not part:IsA("BasePart") or S.Eggs[part] then return end
	part.LocalTransparencyModifier = 1 -- the local copy draws it
	local rec = { Part = part }
	rec.Visual, rec.Sparkle, rec.Glow = makeVisual(part, attr(part, "Kind") or "Gold")
	plan(rec)
	rec.Conn = part:GetAttributeChangedSignal("LandAt"):Connect(function()
		local wasDown = rec.Plopped
		plan(rec)
		if wasDown and rec.Kind == "Bouncy" then playNear(rec.To, "EggBoing") end -- the bouncy egg hops away
	end)
	S.Eggs[part] = rec
	if rec.Kind == "Crown" and not rec.Plopped then play("CrownEgg", nil, "GooseHonk") end
end

local function dropVisual(rec)
	for _, inst in { rec.Visual, rec.Glow, rec.Shadow } do
		if inst then pcall(function() inst:Destroy() end) end
	end
	if rec.Conn then rec.Conn:Disconnect() end
end

-- a little burst of round sparkles at pos (a pickup by someone else, a tag)
local function pop(pos, color, count)
	if not EggFx.Here() or not near(pos, num(lookCfg().SparkleRange, 60)) then return end
	local p = quiet(Instance.new("Part"))
	p.Name = "EggPop"
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	p.CFrame = CFrame.new(pos)
	p.Parent = folder()
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.3, 0.6)
	e.Speed = NumberRange.new(4, 9)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(0.35, 0)
	e.LightEmission = 1
	e.Color = ColorSequence.new(color or Color3.fromRGB(255, 220, 90))
	e.Parent = p
	e:Emit(math.floor(num(count, 12)))
	task.delay(1, function() p:Destroy() end)
end

-- a ground egg gone: picked by someone else (a pop + their pickup sound near me) unless an EggReturn names its spot -
-- the remote and the removal can arrive in either order, so the pop waits GoneWait s (S.Gone) for a return
local function removeEgg(part)
	local rec = S.Eggs[part]
	if not rec then return end
	S.Eggs[part] = nil
	local hidAt = rec.Id ~= nil and S.Hidden[rec.Id] or nil
	if not hidAt and not rec.Returning and rec.Plopped then
		-- 최종 검수 10/11: an egg I picked without a preview (the server's PickRadius has +0.5) is mine, not "someone
		-- else's": it was within reach of me (MineSlack) and my EggCarry rose within MineWindow s of its removal
		-- (either order) - then my own pickup sound in Step is the only one. 최종 검수 10/12: "within reach" counts where I
		-- walked the last MoveWindow s too (S.Trail) - an egg picked in passing is removed after I walked on
		local root = myRoot()
		local reach = num(eggCfg().PickRadius, 4.5) + num(lookCfg().MineSlack, 1)
		local function within(p)
			return typeof(p) == "Vector3" and Vector3.new(p.X - rec.To.X, 0, p.Z - rec.To.Z).Magnitude <= reach
		end
		local near = root ~= nil and within(root.Position)
		for _, s in S.Trail do
			if near then break end
			near = within(s.Pos)
		end
		local gone = { To = rec.To, Returned = false, At = os.clock(), Near = near }
		S.Gone[gone] = true
		task.delay(num(lookCfg().GoneWait, 0.25), function()
			S.Gone[gone] = nil
			if gone.Returned then return end
			if gone.Near and math.abs(S.MineAt - gone.At) <= num(lookCfg().MineWindow, 0.5) then return end -- mine
			pop(gone.To + Vector3.new(0, 1, 0), nil, 10)
			playNear(gone.To, "EggPickup", "GoldPickup")
		end)
	end
	if rec.Id ~= nil then
		S.Hidden[rec.Id] = nil
		S.Denied[rec.Id] = nil
	end
	dropVisual(rec)
end

-- a small egg flying from a to b in time s (returns, deliveries), then gone
local function fly(a, b, time, color)
	if typeof(a) ~= "Vector3" or typeof(b) ~= "Vector3" then return end
	local v = ball("EggFlight", 0.9, color or Color3.fromRGB(255, 205, 60), 0, Enum.Material.SmoothPlastic)
	local t0 = serverNow()
	table.insert(S.Flights, { Part = v, From = a, To = b, LandAt = t0 + time, Time = time })
end

local function goosePos()
	local fx = workspace:FindFirstChild("Effects")
	local g = fx and fx:FindFirstChild("GoldenGoose")
	if g and g:IsA("Model") then
		local ok, cf = pcall(function() return g:GetPivot() end)
		if ok then return cf.Position, g end
	end
	local center = eggCfg().Center
	return (typeof(center) == "Vector3" and center or Vector3.zero) + Vector3.new(0, 4, 0), g
end

----------------------------------------------------------------- per frame
-- did I move MoveMin studs within the last MoveWindow s (the server only gives eggs to players who move)?
local function moved(now, me)
	if not me then return false end
	local trail = S.Trail
	table.insert(trail, { T = now, Pos = me })
	local window = num(lookCfg().MoveWindow, 0.5)
	while #trail > 2 and now - trail[2].T > window do table.remove(trail, 1) end
	return (me - trail[1].Pos).Magnitude >= num(lookCfg().MoveMin, 1)
end

local function stepEggs(now, me)
	local cfg, lk = eggCfg(), lookCfg()
	local can = LocalPlayer:GetAttribute("EggCan") == true
	local carry = num(LocalPlayer:GetAttribute("EggCarry"), 0)
	local walking = moved(now, me)
	local cam = camPos()
	local t = os.clock()
	-- previews the server has not answered yet already take their slots (no 4th egg in one frame)
	local kinds = type(cfg.Kinds) == "table" and cfg.Kinds or {}
	local function slotsOf(kind) return num(type(kinds[kind]) == "table" and kinds[kind].Slots, 1) end
	for _, rec in S.Eggs do
		if rec.Id ~= nil and S.Hidden[rec.Id] then carry += slotsOf(rec.Kind) end
	end
	for part, rec in S.Eggs do
		if not part.Parent then
			removeEgg(part)
			continue
		end
		local v = rec.Visual
		if not v or not v.Parent then continue end
		local hidAt = rec.Id ~= nil and S.Hidden[rec.Id] or nil
		if hidAt and now - hidAt > num(lk.PredictHold, 0.6) then -- the server kept it: show it again, no new try for a while
			S.Hidden[rec.Id] = nil
			S.Denied[rec.Id] = now
			hidAt = nil
		end
		local denied = rec.Id ~= nil and now - (S.Denied[rec.Id] or -math.huge) < num(lk.RetryAfter, 1.5)
		local pos, landed = EggFx.Arc(rec.From, rec.To, rec.LandAt, cfg.FlyTime, now, lk.ArcHeight)
		pos = pos or rec.To
		if landed and not rec.Plopped then
			rec.Plopped = true
			if rec.Shadow then rec.Shadow.Transparency = 1 end
			playNear(rec.To, "EggPlop", "CandyPlop")
		elseif not landed and rec.Shadow then
			local k = math.clamp(1 - (rec.LandAt - now) / math.max(num(cfg.FlyTime, 0.7), 0.05), 0, 1)
			rec.Shadow.Transparency = 0.9 - 0.4 * k
		end
		local cf = rec.Rest.Rotation + pos
		local lkk = kindLook(rec.Kind)
		if landed then
			if rec.Kind == "Bouncy" then
				cf += Vector3.new(0, math.abs(math.sin(t * 5 + (rec.Id or 0))) * 0.4, 0)
			elseif rec.Kind == "Crown" then
				cf *= CFrame.Angles(0, t * 1.5, 0)
			end
		end
		v.CFrame = cf
		if rec.Kind == "Big" and num(lkk.Breathe, 0) > 0 then
			local base = num(lkk.Size, 2.4)
			local s = base * (1 + math.sin(t * 3) * num(lkk.Breathe, 0.08))
			if not v:IsA("MeshPart") then v.Size = Vector3.new(s, s * 1.3, s) end
		end
		if rec.Glow then rec.Glow.CFrame = CFrame.new(pos) end
		local alpha = hidAt and 1 or (can and 0 or num(lk.NoPickAlpha, 0.6))
		if v.LocalTransparencyModifier ~= alpha then v.LocalTransparencyModifier = alpha end
		if rec.Glow then rec.Glow.LocalTransparencyModifier = hidAt and 1 or 0 end
		local sparkle = landed and not hidAt and cam ~= nil and (cam - pos).Magnitude <= num(lk.SparkleRange, 60)
		if rec.Sparkle and rec.Sparkle.Enabled ~= sparkle then rec.Sparkle.Enabled = sparkle end
		-- the pickup preview: hide it at once, pop, the pickup sound (its pitch rises with the eggs I hold)
		if not hidAt and not denied and rec.Id ~= nil and me and EggFx.CanPick({ Pos = rec.To, LandAt = rec.LandAt,
			Kind = rec.Kind }, { Pos = me, Can = can, Carry = carry, Moved = walking }, cfg, now) then
			S.Hidden[rec.Id] = now
			pop(pos + Vector3.new(0, 0.5, 0), nil, 14)
			local steps = type(lk.PickSpeed) == "table" and lk.PickSpeed or { 1, 1.12, 1.26 }
			play("EggPickup", { Speed = num(steps[math.clamp(carry + 1, 1, #steps)], 1) }, "GoldPickup")
			S.PreviewAt = os.clock()
			carry += slotsOf(rec.Kind)
		end
	end
end

local function stepFlights(now)
	for i = #S.Flights, 1, -1 do
		local f = S.Flights[i]
		local pos, landed = EggFx.Arc(f.From, f.To, f.LandAt, f.Time, now, lookCfg().ArcHeight)
		if landed or not f.Part.Parent then
			f.Part:Destroy()
			table.remove(S.Flights, i)
		else
			f.Part.CFrame = CFrame.new(pos)
		end
	end
end

local function homeColor(faction)
	local f = type(Config.Factions) == "table" and Config.Factions[faction] or nil
	return type(f) == "table" and typeof(f.Color) == "Color3" and f.Color or Color3.fromRGB(255, 215, 90)
end

-- my home ring (only I see it) and the ring boundary dots, while the event runs
local function stepRings(active)
	local cfg, lk = eggCfg(), lookCfg()
	local faction = LocalPlayer:GetAttribute("Faction")
	local home = active and LocalPlayer:GetAttribute("EggCan") == true and EggFx.HomeFor(faction) or nil
	if home then
		local r = num(cfg.HomeRadius, 8)
		local hl = type(lk.Home) == "table" and lk.Home or {}
		if not S.Home or not S.Home.Parent then
			S.Home = disc("MyEggHome", r, homeColor(faction), 1)
			S.Home.Material = Enum.Material.Neon
			S.HomeFaction = nil
		end
		if S.HomeFaction ~= faction or S.HomeAt ~= home then -- new, I changed sides at the altar, or the square's home moved
			S.Home.Color = homeColor(faction)
			S.Home.CFrame = CFrame.new(home.X, groundY(home) + num(hl.Height, 0.15), home.Z) * FLAT
			S.HomeFaction = faction
			S.HomeAt = home
		end
		local carrying = num(LocalPlayer:GetAttribute("EggCarry"), 0) > 0
		local pulse = carrying and (math.sin(os.clock() * 4) * 0.08) or 0
		S.Home.Transparency = (carrying and num(hl.CarryAlpha, 0.45) or num(hl.Alpha, 0.75)) + pulse
	elseif S.Home then
		S.Home:Destroy()
		S.Home = nil
	end
	local b = type(lk.Boundary) == "table" and lk.Boundary or {}
	local center = typeof(cfg.Center) == "Vector3" and cfg.Center or Vector3.zero
	local show = active and near(center, num(b.Range, 160) + num(cfg.RingRadius, 54))
	if show and #S.Dots == 0 then
		local n, r = math.max(8, math.floor(num(b.Dots, 48))), num(cfg.RingRadius, 54)
		for i = 1, n do
			local a = (i / n) * math.pi * 2
			local p = Vector3.new(center.X + math.cos(a) * r, 0, center.Z + math.sin(a) * r)
			local dot = ball("EggRingDot", num(b.Size, 0.7), Color3.fromRGB(255, 235, 160), num(b.Alpha, 0.35))
			dot.CFrame = CFrame.new(p.X, groundY(p + Vector3.new(0, 4, 0)) + 0.4, p.Z)
			table.insert(S.Dots, dot)
		end
	elseif not show and #S.Dots > 0 then
		for _, d in S.Dots do d:Destroy() end
		S.Dots = {}
	end
end

-- the goose's "!" (Alert / Chase) and "Zzz" (Nap) from its Act / ActUntil attributes
local function stepGooseIcon(now)
	local pos, goose = goosePos()
	local act = goose and goose:GetAttribute("Act") or nil
	if num(goose and goose:GetAttribute("ActUntil"), 0) < now then act = nil end
	local txt = type(lookCfg().Text) == "table" and lookCfg().Text or {}
	local mark = (act == "Alert" or act == "Chase") and txt.Alert or (act == "Nap" and txt.Nap) or nil
	if mark and goose then
		if not S.Icon or not S.Icon.Parent then
			local holder = quiet(Instance.new("Part"))
			holder.Name = "GooseMark"
			holder.Size = Vector3.new(0.2, 0.2, 0.2)
			holder.Transparency = 1
			holder.Parent = folder()
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromOffset(64, 64)
			gui.AlwaysOnTop = true
			gui.MaxDistance = 150
			gui.Parent = holder
			local label = Instance.new("TextLabel")
			label.Name = "Mark"
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(255, 225, 90)
			label.TextStrokeTransparency = 0.2
			label.Parent = gui
			S.Icon = holder
		end
		S.Icon.CFrame = CFrame.new(pos + Vector3.new(0, num(lookCfg().MarkHeight, 6), 0))
		local label = S.Icon:FindFirstChild("Mark", true)
		if label and label.Text ~= mark then label.Text = mark end
		if act ~= S.LastAct then -- a new act: its sound once (near the goose)
			if act == "Nap" then playNear(pos, "GooseSnore") elseif act == "Alert" then playNear(pos, "GooseHonk") end
		end
	elseif S.Icon then
		S.Icon:Destroy()
		S.Icon = nil
	end
	S.LastAct = act
end

-- the round shields of EggShield (the tag victim's few protected seconds)
local function stepShields(now)
	local lk = type(lookCfg().Shield) == "table" and lookCfg().Shield or {}
	for _, p in Players:GetPlayers() do
		local untilAt = num(p:GetAttribute("EggShield"), 0)
		local ch = p.Character
		local root = ch and ch:FindFirstChild("HumanoidRootPart")
		local on = untilAt > now and root ~= nil and near(root.Position, num(lk.Range, 100))
		local s = S.Shields[p]
		if on then
			if not s or not s.Parent then
				s = ball("EggShield", num(lk.Size, 6), Color3.fromRGB(255, 240, 190), num(lk.Alpha, 0.8))
				S.Shields[p] = s
			end
			s.CFrame = root.CFrame
		elseif s then
			s:Destroy()
			S.Shields[p] = nil
		end
	end
	for p, s in S.Shields do -- someone who left while shielded
		if not p.Parent then
			s:Destroy()
			S.Shields[p] = nil
		end
	end
end

-- my carried stack wobbles near the ring edge and when I stand still (CharacterVisuals EggStack's EggJoint Motor6D)
local function stepWobble(now, me)
	local carry = num(LocalPlayer:GetAttribute("EggCarry"), 0)
	local ch = LocalPlayer.Character
	local joint = ch and ch:FindFirstChild("EggJoint", true)
	if carry <= 0 or not me then
		S.StillAt, S.StillPos = nil, nil
		if joint and joint:IsA("Motor6D") then joint.Transform = CFrame.identity end
		return
	end
	if not S.StillPos or (me - S.StillPos).Magnitude > 1 then
		S.StillPos, S.StillAt = me, now
	end
	local cfg = eggCfg()
	local center = typeof(cfg.Center) == "Vector3" and cfg.Center or Vector3.zero
	local flat = Vector3.new(me.X - center.X, 0, me.Z - center.Z).Magnitude
	local amount = EggFx.Wobble(flat, now - (S.StillAt or now), cfg)
	if joint and joint:IsA("Motor6D") then
		local w = type(lookCfg().Wobble) == "table" and lookCfg().Wobble or {}
		local deg = math.rad(num(w.Max, 18)) * amount * math.sin(os.clock() * num(w.Speed, 14))
		joint.Transform = CFrame.Angles(0, 0, deg)
	end
end

-- outside the Goose Square (A23-141): none of the egg play shows - the local egg copies, flights, rings, the goose's mark,
-- the shields and my stack's wobble are off (cheap and guarded: runs every frame outside, only while there is anything)
local function stepAway()
	for _, rec in S.Eggs do
		local v = rec.Visual
		if v and v.LocalTransparencyModifier ~= 1 then v.LocalTransparencyModifier = 1 end
		if rec.Glow and rec.Glow.LocalTransparencyModifier ~= 1 then rec.Glow.LocalTransparencyModifier = 1 end
		if rec.Sparkle and rec.Sparkle.Enabled then rec.Sparkle.Enabled = false end
		if rec.Shadow and rec.Shadow.Transparency ~= 1 then rec.Shadow.Transparency = 1 end
	end
	for i = #S.Flights, 1, -1 do
		pcall(function() S.Flights[i].Part:Destroy() end)
		table.remove(S.Flights, i)
	end
	if S.Home then
		S.Home:Destroy()
		S.Home = nil
	end
	if #S.Dots > 0 then
		for _, d in S.Dots do d:Destroy() end
		S.Dots = {}
	end
	if S.Icon then
		S.Icon:Destroy()
		S.Icon = nil
	end
	for p, s in S.Shields do
		s:Destroy()
		S.Shields[p] = nil
	end
	if S.StillPos then -- my stack's wobble off
		local ch = LocalPlayer.Character
		local joint = ch and ch:FindFirstChild("EggJoint", true)
		if joint and joint:IsA("Motor6D") then joint.Transform = CFrame.identity end
		S.StillAt, S.StillPos = nil, nil
	end
	S.Carry = 0
end

function EggFx.Step()
	if not EggFx.On() then return end
	local now = serverNow()
	local gs = ReplicatedStorage:FindFirstChild("GameState")
	local active = gs ~= nil and gs:GetAttribute("GooseActive") == true
	if S.WasActive and not active then S.Picked = false end
	S.WasActive = active
	if not EggFx.Here() then
		stepAway()
		return
	end
	local root = myRoot()
	local me = root and root.Position or nil
	-- my EggCarry rose: I picked one (the last ticks are mine); the server's yes after a preview stays silent
	local carry = num(LocalPlayer:GetAttribute("EggCarry"), 0)
	if carry > S.Carry and active then
		S.Picked = true
		if os.clock() - (S.PreviewAt or -math.huge) > 1 then
			-- an egg I got without a preview: a ground egg gone near me right now was mine (removeEgg: no "someone picked
			-- it" pop). 최종 검수 10/12: not after a preview (that egg is hidden already) - or someone else's egg next to
			-- me in the same half second lost its pop
			S.MineAt = os.clock()
			play("EggPickup", nil, "GoldPickup")
		end
	end
	S.Carry = carry
	stepEggs(now, me)
	stepFlights(now)
	stepRings(active)
	stepGooseIcon(now)
	stepShields(now)
	stepWobble(now, me)
end

-- the nest (Halo) and the cart (Horns) points while I am in the square, else nil: workspace.GooseSquare's Nest / Cart
-- parts (or its NestPos / CartPos attributes) when it exists, before Config.Goose.Egg.Home
function EggFx.Homes()
	if not EggFx.Here() then return nil end
	local cfgHome = type(eggCfg().Home) == "table" and eggCfg().Home or {}
	local sq = workspace:FindFirstChild("GooseSquare")
	local function read(name, attrName)
		if not sq then return nil end
		local inst = sq:FindFirstChild(name, true)
		local ok, pos = pcall(function()
			if inst and inst:IsA("BasePart") then return inst.Position end
			if inst and inst:IsA("Model") then return inst:GetPivot().Position end
			return nil
		end)
		if ok and typeof(pos) == "Vector3" then return pos end
		local a = sq:GetAttribute(attrName)
		return typeof(a) == "Vector3" and a or nil
	end
	return { Halo = read("Nest", "NestPos") or cfgHome.Halo, Horns = read("Cart", "CartPos") or cfgHome.Horns }
end

-- my side's home point (HomeOf over Homes) or nil outside the square / without one
function EggFx.HomeFor(faction)
	local homes = EggFx.Homes()
	return homes and EggFx.HomeOf(faction, { Home = homes }) or nil
end

-- QuestMarker: while I carry eggs in the square, the marker points at my home (3 studs over it), else nil
function EggFx.HomeTarget()
	if not EggFx.Here() then return nil end
	local gs = ReplicatedStorage:FindFirstChild("GameState")
	if not gs or gs:GetAttribute("GooseActive") ~= true then return nil end
	if num(LocalPlayer:GetAttribute("EggCarry"), 0) <= 0 then return nil end
	local home = EggFx.HomeFor(LocalPlayer:GetAttribute("Faction"))
	return home and home + Vector3.new(0, 3, 0) or nil
end

-- Audio: the last 3-2-1 is for those who picked an egg this event; the crown egg's overtime moves its end. nil outside
-- the square (no egg count there)
function EggFx.TickFor(gs)
	if not EggFx.Here() or not gs then return nil end
	local endAt = EggFx.TickEnd(gs:GetAttribute("GooseEndsAt"), gs:GetAttribute("GooseOvertimeUntil"), serverNow())
	return S.Picked, endAt
end

----------------------------------------------------------------- one-off events (Net.Fx)
function EggFx.OnFx(kind, data)
	if not EggFx.Here() or type(data) ~= "table" then return end
	local lk = lookCfg()
	if kind == "EggReturn" then -- the eggs fly back to the goose
		local to = goosePos()
		local r = type(lk.Return) == "table" and lk.Return or {}
		for _, from in type(data.Froms) == "table" and data.Froms or {} do
			if typeof(from) == "Vector3" and near(from, num(r.Range, 160)) then fly(from, to, num(r.Time, 0.8)) end
			if typeof(from) == "Vector3" then -- a ground egg going back: no "someone picked it" pop (either order)
				for _, rec in S.Eggs do
					if (rec.To - from).Magnitude < 0.5 then rec.Returning = true end
				end
				for gone in S.Gone do
					if (gone.To - from).Magnitude < 0.5 then gone.Returned = true end
				end
			end
		end
	elseif kind == "EggDeliver" then
		if data.UserId ~= LocalPlayer.UserId then return end -- "+N" only for my own delivery (others: Audio, near)
		local home = typeof(data.Pos) == "Vector3" and data.Pos or nil
		if not home then return end
		local d = type(lk.Deliver) == "table" and lk.Deliver or {}
		local root = myRoot()
		if root then
			for i = 1, math.clamp(math.floor(num(data.N, 1)), 1, 3) do
				fly(root.Position + Vector3.new(0, 3 + i * 0.6, 0), home + Vector3.new(0, 0.5, 0), num(d.Time, 0.45))
			end
		end
		local txt = type(lk.Text) == "table" and lk.Text or {}
		local fx = C and C.Fx
		if type(fx) == "table" and type(fx.ShowNumber) == "function" then
			pcall(fx.ShowNumber, home + Vector3.new(0, num(d.Rise, 4), 0),
				string.format(txt.Plus or "+%d", math.floor(num(data.Points, 0))), Color3.fromRGB(255, 215, 90), 1.3, { Pop = true })
		end
		pop(home + Vector3.new(0, 1, 0), homeColor(data.Side), 20)
	elseif kind == "EggTag" then
		if typeof(data.Pos) == "Vector3" then pop(data.Pos + Vector3.new(0, 2, 0), Color3.fromRGB(255, 245, 210), 16) end
	elseif kind == "GooseEnd" then -- confetti over the winner's home
		local home = EggFx.HomeFor(data.Winner)
		if home and near(home, 200) then
			for _, col in { Color3.fromRGB(255, 215, 90), Color3.fromRGB(255, 255, 255), homeColor(data.Winner) } do
				pop(home + Vector3.new(0, 6, 0), col, 25)
			end
		end
	end
end

local function watchFolder(f)
	for _, p in f:GetChildren() do pcall(addEgg, p) end
	f.ChildAdded:Connect(function(p) pcall(addEgg, p) end)
	f.ChildRemoved:Connect(function(p) pcall(removeEgg, p) end)
end

-- A23-141: the short screen fade when my InGooseSquare changes (either way): a full-screen black Frame (IgnoreGuiInset)
-- goes opaque over Fade.In s, then clear over Fade.Out s, then the gui is off. One at a time: a new change restarts it
-- (the old tween is cancelled). No text.
local function fadeFrame()
	if S.FadeGui and S.FadeGui.Parent and S.FadeFrame then return S.FadeGui, S.FadeFrame end
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then return nil end
	local gui = Instance.new("ScreenGui")
	gui.Name = "GooseSquareFade"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.Enabled = false
	local f = Instance.new("Frame")
	f.Name = "Black"
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Active = false
	f.Parent = gui
	gui.Parent = pg
	S.FadeGui, S.FadeFrame = gui, f
	return gui, f
end

function EggFx.Fade()
	local fade = type(squareCfg().Fade) == "table" and squareCfg().Fade or {}
	local gui, frame = fadeFrame()
	if not gui then return end
	S.FadeId = (S.FadeId or 0) + 1
	local id = S.FadeId
	if S.FadeTween then S.FadeTween:Cancel() end
	gui.Enabled = true
	local t1 = TweenService:Create(frame, TweenInfo.new(math.max(0, num(fade.In, 0.25)), Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out), { BackgroundTransparency = 0 })
	S.FadeTween = t1
	t1.Completed:Connect(function()
		if S.FadeId ~= id then return end
		local t2 = TweenService:Create(frame, TweenInfo.new(math.max(0, num(fade.Out, 0.35)), Enum.EasingStyle.Quad,
			Enum.EasingDirection.In), { BackgroundTransparency = 1 })
		S.FadeTween = t2
		t2.Completed:Connect(function()
			if S.FadeId ~= id then return end
			gui.Enabled = false
			S.FadeTween = nil
		end)
		t2:Play()
	end)
	t1:Play()
end

function EggFx.Init(registry)
	C = registry
end

-- 게임성 검수 10/11: a repeating error (every frame) warns once per WarnGap s per message, not 60 times a second
local function warnThrottled(msg)
	local now = os.clock()
	S.Warned = S.Warned or {}
	if now - (S.Warned[msg] or -math.huge) < num(lookCfg().WarnGap, 10) then return end
	S.Warned[msg] = now
	warn("[EggFx] " .. msg)
end

function EggFx.Start()
	S.SquareIn = EggFx.Inside() -- where I already am: no fade for that
	LocalPlayer:GetAttributeChangedSignal(squareName("Attr", "InGooseSquare")):Connect(function()
		local ok, err = pcall(EggFx.SquareChanged)
		if not ok then warnThrottled("Square: " .. tostring(err)) end
	end)
	task.spawn(function()
		local effects = workspace:WaitForChild("Effects", 60)
		if not effects then return end
		local f = effects:FindFirstChild("GooseEggs")
		if f then watchFolder(f) end
		effects.ChildAdded:Connect(function(c)
			if c.Name == "GooseEggs" and c:IsA("Folder") then watchFolder(c) end
		end)
	end)
	task.spawn(function()
		local ok, err = pcall(function() Net.Get("Fx").OnClientEvent:Connect(function(kind, data)
			local fine, e = pcall(EggFx.OnFx, kind, data)
			if not fine then warnThrottled(tostring(kind) .. ": " .. tostring(e)) end
		end) end)
		if not ok then warnThrottled("Fx hook: " .. tostring(err)) end
	end)
	RunService.RenderStepped:Connect(function()
		local ok, err = pcall(EggFx.Step)
		if not ok then warnThrottled(tostring(err)) end
	end)
end

-- test aid: how many ground eggs are drawn, previews hidden
function EggFx.Live()
	local n, h = 0, 0
	for _ in S.Eggs do n += 1 end
	for _ in S.Hidden do h += 1 end
	return n, h
end

return EggFx
