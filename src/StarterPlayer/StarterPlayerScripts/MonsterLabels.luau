-- MonsterLabels.luau : which monster name / HP bars this client shows (review of devlog 12, 2026-10-06: ghost packs and
-- slime crowds stacked their name tags into each other and over the quest lines). MonsterService builds one
-- "MonsterBar" BillboardGui per monster (name + Bar/Fill); the server never hides them, this client does:
--   * the name tag shows for the nearest MAX_NAMES monsters within NAME_RANGE studs of me, for any monster hurt in the
--     last HURT_SECONDS (the one I am fighting), and for event bosses (the kings) while in their bar range;
--   * the HP bar under it shows only while the monster was hurt in the last HURT_SECONDS (bosses: always);
--   * a pack crowding one spot shows one name: a same-kind monster within CLUSTER studs of a shown name keeps only its
--     bar (2026-10-06: three ghost minions on top of me stacked "똘마니 유령" three times), and so does one whose name
--     would land on a shown same-kind name on screen (NameW x NameH px apart; 2026-10-07 photos: two "Shard Slime" tags
--     one behind the other were 6 studs apart but drawn over each other);
--   * a dying monster (anchored root, A23-74) shows neither (the server turned its bar off).
-- Hurt = its Fill bar got shorter (server bar updates replicate). Local only: Enabled / Visible never replicate.
-- Monster barks (lines_pack 2, dev2 BarkService): the server writes Bark (the line) then BarkAt (server time) on the
-- monster model; every new BarkAt (the same line again too) shows Bark in a speech bubble over the head for
-- Config.Barks.Show s, only within Config.Barks.MaxDistance studs; no player names, chat settings do not matter. Its
-- tail (bottom-left) sits at the head. A bark already old when its monster streams in is not shown.
-- A23-74 (user 2026-10-07 "슬라임이 말하는 말풍선이 하나도 안 귀여움" / "몬스터마다 다른 말풍선 그려야지" / "말풍선 가로로
-- 길쭉한 거 말고"): fixed-size round bubbles (the lines are one sound word now, B.SizeOf), never a wide pill. The art:
-- the monster's own "BarkBubble<Kind>" (round, Fit, ~104 px wide), else its family's (Config.Barks.BubbleFamily /
-- BubbleArt), else a round white code bubble with a tail dot - never the shared 9-slice BarkBubble (512 x 190: drawn
-- small its body stays ~2.4 : 1, the wide pill the user turned down; the HUD hint bubble keeps it). The line
-- wraps to up to 2 lines in the game's Head font; a jelly pop-in from the tail, a slow float while shown and a quick
-- shrink + fade at the end (all off with UIKit.ReducedMotion). Every tween of a bubble stops when it is destroyed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local MonsterLabels = {}
local LocalPlayer = Players.LocalPlayer

local T = { Tick = 0.2, NameRange = 30, MaxNames = 5, HurtSeconds = 4, Cluster = 5, NameW = 135, NameH = 24 }
local S = { Started = false, Fill = {}, HurtAt = {} } -- [BillboardGui] = last Fill scale / os.clock() of the last drop
local C = nil
-- bubble: At[model] = the last BarkAt seen (false = none yet); a newer bark replaces the bubble (B.Make)
local B = { At = setmetatable({}, { __mode = "k" }),
	-- A23-74 (user 2026-10-07 "말풍선 가로로 길쭉한 거 말고"): fixed px, never per letter. A monster's own art (no Slice):
	-- ArtW wide, height = ArtW x its Size H / W (ArtAspect without a Size) within ArtHMin..ArtHMax (the 12 uploaded
	-- bubbles, 512 x 298-445, all fit inside: 61-90 px, so Fit never letterboxes and the TextRect lines up). The code
	-- bubble: CodeW x CodeH (was a 150-214 x 44-64 pill)
	ArtW = 104, ArtAspect = 0.75, ArtHMin = 60, ArtHMax = 104, CodeW = 96, CodeH = 70,
	Lift = 1.1, Text = Color3.fromRGB(28, 36, 82), TextMin = 12, TextMax = 26, LineHeight = 0.9,
	-- text box (fractions of the bubble) of a monster art without a TextRect / of the code bubble
	RoundRect = { 0.16, 0.12, 0.68, 0.6 }, CodeRect = { 0.1, 0.12, 0.8, 0.76 },
	-- the code bubble (no art): fully round, a thin soft rim, a small round tail dot (Tail px) under its bottom left
	Rim = Color3.fromRGB(92, 108, 178), RimThick = 1.5, RimFade = 0.25, Tail = 12,
	-- motion: UIScale From -> 1 (Back, Grow s) while the art's Size goes Stretch -> 1 x 1 (Elastic, Wobble s) from the
	-- tail corner = squash & stretch; a Bob studs float (BobTime s each way); the last Out s shrink to OutScale + fade
	From = 0.3, Grow = 0.34, Stretch = { 0.78, 1.22 }, Wobble = 0.42, Bob = 0.12, BobTime = 0.8, Out = 0.18, OutScale = 0.25 }

local function myPos()
	local ch = LocalPlayer.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	if root then return root.Position end
	local cam = workspace.CurrentCamera
	return cam and cam.Focus.Position or nil
end

-- 검수 10/09 (system review ④): the shown name tag in its danger colour (Config.MonsterDangerLook: dev2's
-- Config.MonsterDanger(myLevel, monsterLevel) band; a monster of unknown level stays white; a golden one keeps the gold)
function S.Danger(r)
	local model = r.Model
	if not model or model:GetAttribute("Golden") == true then return end
	local D = Config.MonsterDangerLook
	local lp = Players.LocalPlayer
	local myLv = lp and type(lp.GetAttribute) == "function" and lp:GetAttribute("Level") or nil
	local monLv = D.LevelOf(r.Kind, model:GetAttribute("Level"))
	local color = (monLv and myLv) and D.Colors[D.Tier(myLv, monLv)] or D.Colors.Even
	if r.Name.TextColor3 ~= color then r.Name.TextColor3 = color end
end

local function kindOf(model)
	local kind = model:GetAttribute("MonsterKind") or model.Name
	return type(kind) == "string" and kind or model.Name
end

local function isBoss(kind)
	local def = Config.MonsterTypes[kind]
	return type(def) == "table" and def.Boss == true
end

-- A23-74 (user 2026-10-07 "몬스터마다 다른 말풍선 그려야지" / "말풍선 가로로 길쭉한 거 말고"): the round bubble art keys
-- to try for a monster kind, in order: its own "BarkBubble<Kind>", then its family's (Config.Barks.BubbleFamily ->
-- BubbleArt; a kind not listed uses its Config.QuestKind's family) - each only while its Id is uploaded (not "") and it
-- is a round drawing (no Slice). Never the shared 9-slice BarkBubble: an empty list = the round code bubble (B.Make)
function B.ArtKeys(kind)
	local cfg = Config.Barks or {}
	local arts = type(cfg.BubbleArt) == "table" and cfg.BubbleArt or {}
	local fams = type(cfg.BubbleFamily) == "table" and cfg.BubbleFamily or {}
	local parts = Config.UIArt and Config.UIArt.Parts or {}
	local keys = {}
	local function add(key)
		local def = type(key) == "string" and parts[key] or nil
		if type(def) == "table" and type(def.Id) == "string" and def.Id ~= "" and typeof(def.Slice) ~= "Rect"
			and not table.find(keys, key) then
			table.insert(keys, key)
		end
	end
	if type(kind) == "string" then
		local fam = fams[kind]
		if fam == nil and type(Config.QuestKind) == "function" then
			local ok, q = pcall(Config.QuestKind, kind)
			fam = ok and type(q) == "string" and fams[q] or nil
		end
		add("BarkBubble" .. kind)
		add(fam and arts[fam])
	end
	return keys
end

-- the first art key tried for a kind (test aid): nil = the round code bubble (none of its round art uploaded)
function B.ArtKey(kind)
	return B.ArtKeys(kind)[1]
end

-- A23-74 (user 2026-10-07 "가로로 길쭉한 거 말고"): bubble px for the art drawn (its Config.UIArt.Parts entry; nil = the
-- code bubble) - a fixed size, the line never stretches it. A monster's round art keeps its drawn shape (Size H / W).
function B.SizeOf(def)
	if type(def) ~= "table" then return B.CodeW, B.CodeH end
	local ok, w, h = pcall(function() return def.Size.X, def.Size.Y end)
	local aspect = (ok and type(w) == "number" and type(h) == "number" and w > 0 and h > 0) and h / w or B.ArtAspect
	return B.ArtW, math.clamp(math.floor(B.ArtW * aspect + 0.5), B.ArtHMin, B.ArtHMax)
end

-- the code bubble's round look: a fully round corner + the thin soft rim; both fade at the end (fades)
local function roundLook(frame, fades)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0) -- A23-74: fully round
	corner.Parent = frame
	local rim = Instance.new("UIStroke")
	rim.Color = B.Rim
	rim.Thickness = B.RimThick
	rim.Transparency = B.RimFade
	rim.Parent = frame
	table.insert(fades, { frame, { BackgroundTransparency = 1 } })
	table.insert(fades, { rim, { Transparency = 1 } })
end

-- builds the bubble on root; returns it and its fade-out (nil with reduced motion: it just goes at the end). size =
-- { W, H } px for a longer line (A23-113 ⑥ TownReact: a town person's short sentence; nil = the bark sizes)
function B.Make(root, offsetY, text, kind, size)
	local old = root:FindFirstChild("BarkBubble")
	if old then old:Destroy() end
	local cfg = Config.Barks or {}
	local bb = Instance.new("BillboardGui")
	bb.Name = "BarkBubble"
	bb.SizeOffset = Vector2.new(0.5, 0.5) -- the bubble's bottom-left corner (its tail) at the attach point
	local base = Vector3.new(0.4, offsetY + B.Lift, 0)
	bb.StudsOffset = base
	bb.MaxDistance = tonumber(cfg.MaxDistance) or 60
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	bb.ClipsDescendants = false -- the pop overshoots the box for a moment
	local kit = C and C.UIKit
	local art, def = nil, nil
	if type(kit) == "table" and type(kit.ArtImage) == "function" then
		local parts = Config.UIArt and Config.UIArt.Parts or {}
		for _, key in B.ArtKeys(kind) do
			local d = type(parts[key]) == "table" and parts[key] or {}
			-- A23-74: a monster's round art keeps its drawn shape (Fit, never 9-sliced)
			local props = { Name = "Art", Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Fit }
			local ok, img = pcall(kit.ArtImage, key, props)
			if ok and img then
				art, def = img, d
				art.Parent = bb
				break
			end
		end
	end
	local fades = {} -- the code bubble's frames and rims: they fade at the end too
	if not art then
		art = Instance.new("Frame")
		art.Name = "Art"
		art.Size = UDim2.fromScale(1, 1)
		roundLook(art, fades)
		-- A23-74: a small round tail dot under the bottom left (a speech bubble, not a name plate)
		local tail = Instance.new("Frame")
		tail.Name = "Tail"
		tail.Size = UDim2.fromOffset(B.Tail, B.Tail)
		tail.Position = UDim2.new(0, 2, 1, 2)
		roundLook(tail, fades)
		tail.Parent = art
		art.Parent = bb
	end
	local w, h = B.SizeOf(def)
	if type(size) == "table" and tonumber(size[1]) and tonumber(size[2]) then w, h = tonumber(size[1]), tonumber(size[2]) end
	bb.Size = UDim2.fromOffset(w, h)
	art.AnchorPoint = Vector2.new(0, 1) -- scales out of the tail corner
	art.Position = UDim2.fromScale(0, 1)
	local label = Instance.new("TextLabel")
	label.Name = "Line"
	label.BackgroundTransparency = 1
	local rect = def and (type(def.TextRect) == "table" and def.TextRect or B.RoundRect) or B.CodeRect
	label.Position = UDim2.fromScale(rect[1], rect[2])
	label.Size = UDim2.fromScale(rect[3], rect[4])
	label.Text = text
	label.TextColor3 = B.Text
	-- A23-74: one sound word, at most 2 lines: wrapped and scaled between TextMin and TextMax
	label.TextWrapped = true
	label.TextScaled = true
	label.LineHeight = B.LineHeight
	-- the game's round Head face (Denk One, the HUD hint bubble's Button style); Fredoka One without UIKit
	local fontOk = type(kit) == "table" and type(kit.ApplyFont) == "function"
		and pcall(kit.ApplyFont, label, Enum.FontWeight.ExtraBold, "Head")
	if not fontOk then label.Font = Enum.Font.FredokaOne end
	local size = Instance.new("UITextSizeConstraint")
	size.MaxTextSize = B.TextMax
	size.MinTextSize = B.TextMin
	size.Parent = label
	label.Parent = art
	local reduced = type(kit) == "table" and type(kit.ReducedMotion) == "function" and kit.ReducedMotion()
	if reduced then
		bb.Parent = root
		return bb, nil
	end
	-- A23-74 motion: jelly pop from the tail corner + a slow float; every tween stops when the bubble is destroyed. A
	-- monster's own art is drawn with Fit, so its squash & stretch reads as an elastic boing without bending the drawing.
	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Scale = B.From
	pop.Parent = art
	art.Size = UDim2.fromScale(B.Stretch[1], B.Stretch[2])
	bb.Parent = root
	local tweens = {}
	local function play(inst, info, goal)
		local ok, tw = pcall(TweenService.Create, TweenService, inst, info, goal)
		if ok and tw then
			table.insert(tweens, tw)
			tw:Play()
		end
	end
	bb.Destroying:Connect(function()
		for _, tw in tweens do tw:Cancel() end
	end)
	play(pop, TweenInfo.new(B.Grow, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	play(art, TweenInfo.new(B.Wobble, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1, 1) })
	play(bb, TweenInfo.new(B.BobTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ StudsOffset = base + Vector3.new(0, B.Bob, 0) })
	-- the last B.Out s: shrink (Back In) and fade instead of vanishing
	local function fadeOut()
		if not bb.Parent then return end -- a newer bark already replaced it
		play(pop, TweenInfo.new(B.Out, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = B.OutScale })
		local quick = TweenInfo.new(B.Out, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		if art:IsA("ImageLabel") then play(art, quick, { ImageTransparency = 1 }) end
		play(label, quick, { TextTransparency = 1 })
		for _, f in fades do play(f[1], quick, f[2]) end
	end
	return bb, fadeOut
end

-- the bark check of one monster this tick (called with its MonsterBar's root part)
function B.Check(model, root, barBB, me)
	local at = model:GetAttribute("BarkAt")
	local prev = B.At[model]
	B.At[model] = at or false
	if prev == at then return end
	local cfg = Config.Barks or {}
	if cfg.Enabled == false or type(at) ~= "number" then return end
	if prev == nil and workspace:GetServerTimeNow() - at > (tonumber(cfg.Show) or 3) then return end -- old news
	local text = model:GetAttribute("Bark")
	if type(text) ~= "string" or text == "" then return end
	if me and (root.Position - me).Magnitude > (tonumber(cfg.MaxDistance) or 60) then return end
	local bubble, fadeOut = B.Make(root, barBB and barBB.StudsOffset.Y or 3, text, kindOf(model))
	local show = tonumber(cfg.Show) or 3
	if fadeOut then task.delay(math.max(0, show - B.Out), fadeOut) end
	task.delay(show, function()
		if bubble.Parent then bubble:Destroy() end -- a newer bark already replaced (destroyed) it otherwise
	end)
end

local function tick()
	local folder = workspace:FindFirstChild("Monsters")
	local me = myPos()
	if not folder or not me then return end
	local now = os.clock()
	local rows, seen = {}, {}
	for _, model in folder:GetChildren() do
		local bb = model:FindFirstChild("MonsterBar", true)
		local root = bb and bb.Parent
		if bb and bb:IsA("BillboardGui") and root and root:IsA("BasePart") and root.Anchored then
			-- A23-74 (user 2026-10-07 "왜 반투명한 애들이 생기냐고"): a dying / leaving monster (MonsterService deathPop
			-- anchors its root and turns its bar off) never gets its name tag / bar back from this pass, and takes no
			-- name slot from the living ones; a dead body with "Shard Slime" over it read as a living monster
			seen[bb] = true
			if bb.Enabled then bb.Enabled = false end
		elseif bb and bb:IsA("BillboardGui") and root and root:IsA("BasePart") then
			seen[bb] = true
			local back = bb:FindFirstChild("Bar")
			local fill = back and back:FindFirstChild("Fill")
			local scale = fill and fill.Size.X.Scale or 1
			local last = S.Fill[bb]
			if last and scale < last - 1e-4 then S.HurtAt[bb] = now end
			S.Fill[bb] = scale
			local d = (root.Position - me).Magnitude
			local hurt = S.HurtAt[bb] ~= nil and now - S.HurtAt[bb] <= T.HurtSeconds
			local kind = kindOf(model)
			table.insert(rows, { BB = bb, Back = back, Name = bb:FindFirstChild("NameLabel"), Model = model, D = d, Pos = root.Position,
				Kind = kind, Hurt = hurt, Boss = isBoss(kind) })
			B.Check(model, root, bb, me)
		end
	end
	table.sort(rows, function(a, b) return a.D < b.D end)
	local cam = workspace.CurrentCamera
	-- where a name tag lands on screen (px), nil when it is off screen / behind me
	local function screenOf(r)
		if r.Screen == nil then
			r.Screen = false
			if cam then
				local p, on = cam:WorldToViewportPoint(r.Pos + Vector3.new(0, r.BB.StudsOffset.Y, 0))
				if on and p.Z > 0 then r.Screen = p end
			end
		end
		return r.Screen or nil
	end
	local names, shown = 0, {}
	for _, r in rows do
		local near = r.D <= T.NameRange and names < T.MaxNames
		local name = near or r.Hurt or r.Boss
		if name and not r.Boss then
			for _, o in shown do
				if o.Kind == r.Kind then
					if (o.Pos - r.Pos).Magnitude < T.Cluster then
						name = false
						break
					end
					local a, b = screenOf(r), screenOf(o)
					if a and b and math.abs(a.X - b.X) < T.NameW and math.abs(a.Y - b.Y) < T.NameH then
						name = false
						break
					end
				end
			end
		end
		if name then
			table.insert(shown, r)
			if near then names += 1 end
		end
		local bar = r.Hurt or r.Boss
		local show = name or bar
		if r.BB.Enabled ~= show then r.BB.Enabled = show end
		if r.Name and r.Name.Visible ~= name then r.Name.Visible = name end
		if name and r.Name then S.Danger(r) end
		if r.Back and r.Back.Visible ~= bar then r.Back.Visible = bar end
	end
	-- forget bars of monsters that are gone
	for bb in S.Fill do
		if not seen[bb] then
			S.Fill[bb] = nil
			S.HurtAt[bb] = nil
		end
	end
end

function MonsterLabels.Init(registry)
	C = registry
end

-- test aids: the bark check / bubble builder (tools/test_monster_bark.py), one label pass (tools/test_monster_labels.py)
MonsterLabels.Bark = B
MonsterLabels.Tick = tick

function MonsterLabels.Start()
	if S.Started then return end
	S.Started = true
	task.spawn(function()
		while true do
			local ok, err = pcall(tick)
			if not ok then warn("[MonsterLabels] " .. tostring(err)) end
			task.wait(T.Tick)
		end
	end)
	print("[MonsterLabels] started")
end

return MonsterLabels
