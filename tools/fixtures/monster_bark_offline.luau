-- Offline checks for the monster bark bubble (MonsterLabels, lines_pack 2 / dev2 BarkService contract): the real
-- MonsterLabels.luau + Config.luau with small doubles; MonsterLabels.Bark.Check runs per monster per tick.
-- Inputs: CONFIG_SOURCE, LABELS_SOURCE. No Studio / Roblox API calls.
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if not ok then
		failed += 1
		print("CHECK_FAIL " .. name .. " :: " .. tostring(detail))
	end
end
local vmt = {}
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, __kind = "Vector3" }, vmt) end
vmt.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
vmt.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vmt.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
vmt.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	return nil
end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })

-- instances: properties, Children, Parent, FindFirstChild, Destroy, IsA
local imt = {}
imt.__index = {
	FindFirstChild = function(self, n)
		for _, ch in self.Children do if ch.Name == n then return ch end end
		return nil
	end,
	IsA = function(self, c) return self.ClassName == c end,
	Destroy = function(self)
		-- Destroying fires for the instance and its descendants first (the bubble's tween cleanup listens to it)
		local function fire(node)
			for _, fn in node.DestroyingFns do fn() end
			for _, ch in node.Children do fire(ch) end
		end
		fire(self)
		local p = rawget(self, "Parent")
		if p then
			for i, ch in p.Children do if ch == self then table.remove(p.Children, i) break end end
		end
		rawset(self, "Parent", nil)
		rawset(self, "Destroyed", true)
	end,
	GetAttribute = function(self, k) return self.Attrs[k] end,
}
imt.__newindex = function(self, k, v)
	if k == "Parent" then
		local old = rawget(self, "Parent")
		if old then for i, ch in old.Children do if ch == self then table.remove(old.Children, i) break end end end
		rawset(self, "Parent", v)
		if v then table.insert(v.Children, self) end
		return
	end
	rawset(self, k, v)
end
local function inst(class, name)
	local o = setmetatable({ ClassName = class, Name = name or class, Children = {}, Attrs = {}, DestroyingFns = {} }, imt)
	rawset(o, "Destroying", { Connect = function(_, fn) table.insert(o.DestroyingFns, fn) return { Disconnect = function() end } end })
	return o
end

local W = { Now = 1000, Timers = {} }
local function advance(dt)
	W.Now += dt
	local due = {}
	for i = #W.Timers, 1, -1 do
		if W.Timers[i].At <= W.Now then table.insert(due, table.remove(W.Timers, i)) end
	end
	table.sort(due, function(a, b) return a.At < b.At end)
	for _, t in due do t.Fn() end
end
local kitArt = true
-- the art ids the UIKit double can draw: the shared 9-slice BarkBubble is drawable on purpose (A23-74: barks must never
-- ask for it); section 0 adds the 12 real BarkBubble<Kind> keys
local uploaded = { BarkBubble = true }
local artAsked = {} -- names ArtImage was asked for, in order
local reducedMotion = false
local fontCalls = {}
local kit = {
	ArtImage = function(name, props)
		table.insert(artAsked, name)
		if not kitArt or not uploaded[name] then return nil end
		local img = inst("ImageLabel", props.Name)
		img.Size = props.Size
		img.ArtKey = name
		img.AskedScaleType = props.ScaleType -- A23-74: a monster's round art asks for Fit
		return img
	end,
	ApplyFont = function(label, weight, role) table.insert(fontCalls, { Label = label, Weight = weight, Role = role }) return label end,
	ReducedMotion = function() return reducedMotion end,
	Theme = { FontFace = nil },
}
-- every tween made: Inst / Info (TweenInfo double: Args) / Goal / Played / Cancelled
local tweens = {}
local services = {
	Players = { LocalPlayer = { Character = nil } },
	ReplicatedStorage = { WaitForChild = function() return { WaitForChild = function(_, n) return { __module = n } end } end },
	TweenService = { Create = function(_, target, info, goal)
		local tw = { Inst = target, Info = info, Goal = goal, Played = false, Cancelled = false }
		tw.Play = function() tw.Played = true end
		tw.Cancel = function() tw.Cancelled = true end
		table.insert(tweens, tw)
		return tw
	end },
}
local env = setmetatable({
	game = { GetService = function(_, n) return assert(services[n], n) end },
	workspace = { GetServerTimeNow = function() return W.Now end, FindFirstChild = function() return nil end, CurrentCamera = nil },
	Vector3 = { new = vec }, Vector2 = { new = function(x, y) return { X = x, Y = y } end },
	UDim2 = { fromOffset = function(x, y) return { Kind = "Offset", X = x, Y = y } end,
		fromScale = function(x, y) return { Kind = "Scale", X = x, Y = y } end,
		new = function(xs, xo, ys, yo) return { Kind = "New", XS = xs, XO = xo, YS = ys, YO = yo } end },
	UDim = { new = function(a, b) return { a, b } end },
	Color3 = { new = function(r, g, b) return { R = r, G = g, B = b } end, fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end,
		fromHSV = function() return {} end },
	BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), NumberRange = ctor("NumberRange"),
	NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"),
	ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"), CFrame = ctor("CFrame"), Font = ctor("Font"),
	TweenInfo = { new = function(...) return { Args = { ... } } end }, Enum = enum,
	Instance = { new = function(class) return inst(class) end },
	typeof = function(v) return type(v) == "table" and rawget(v, "__kind") or type(v) end,
	task = { delay = function(t, fn) table.insert(W.Timers, { At = W.Now + t, Fn = fn }) end, spawn = function() end, wait = function() end },
	warn = function(...) print("WARN", ...) end, print = function() end,
	require = function(m) return m.__config end,
}, { __index = getfenv() })
local cfn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cfn, env)
local Config = cfn()
env.require = function() return Config end
local lfn = assert(loadstring(LABELS_SOURCE, "=MonsterLabels"))
setfenv(lfn, env)
local ML = lfn()
ML.Init({ UIKit = kit })
local B = ML.Bark
check(type(B) == "table" and type(B.Check) == "function", "MonsterLabels exposes the bark check (test aid)")

-- 0. A23-74: the 12 uploaded round bubbles in the real Config (270b9c3e): an rbxassetid Id, Size (PNG px), TextRect, no
-- Slice. Drawn ArtW x (ArtW x H / W) with no clamp (Fit fills the box, so the TextRect lines up), a round box (at most
-- 1.8 : 1, never the 2.4 : 1 pill), and a text box with room for 2 lines at TextMin (one sound word, at most 2 lines)
local parts = Config.UIArt.Parts
local real = {} -- [key] = { Id, Size, TextRect } as uploaded
-- A23-84: the King Slime boss (2026-10-09) has no bubble art of its own yet (image gen 2 -> image dev): it uses its
-- family's slime bubble until then (checked below); the others each have their own
local PENDING_ART = { CaptainClatter = "BarkBubbleSkeleton" } -- SlimeKing art uploaded 2026-10-09 (98179139339766) -- + J Captain Clatter
local kindCount, badArt, tight = 0, {}, {}
for kind in Config.MonsterTypes do
	kindCount += 1
	if PENDING_ART[kind] then continue end
	local key = "BarkBubble" .. kind
	local p = parts[key]
	local r = type(p) == "table" and p.TextRect or nil
	if type(p) == "table" and type(p.Id) == "string" and string.match(p.Id, "^rbxassetid://%d+$") ~= nil and p.Slice == nil
		and type(p.Size) == "table" and type(p.Size.X) == "number" and p.Size.X > 0 and type(p.Size.Y) == "number" and p.Size.Y > 0
		and type(r) == "table" and #r == 4 and r[1] >= 0 and r[2] >= 0 and r[1] + r[3] <= 1 and r[2] + r[4] <= 1 then
		real[key] = { Id = p.Id, Size = p.Size, TextRect = r }
		uploaded[key] = true
		local w, h = B.SizeOf(p)
		if w ~= B.ArtW or math.abs(h - B.ArtW * p.Size.Y / p.Size.X) > 0.5 or w / h > 1.8 then
			table.insert(badArt, kind .. " " .. w .. "x" .. h)
		end
		if r[4] * h < 2 * B.TextMin * B.LineHeight or r[3] * w < 40 then table.insert(tight, kind) end
	else
		table.insert(badArt, kind)
	end
end
check(kindCount == 14 and #badArt == 0, "all 12 BarkBubble<Kind> (+ the King Slime, Captain Clatter pending) uploaded (Id, Size, TextRect, no Slice), drawn in their own round "
	.. "shape (ArtW wide, height from Size, no clamp, at most 1.8 : 1)", kindCount .. " " .. table.concat(badArt, ","))
check(#tight == 0, "every uploaded bubble's TextRect fits 2 lines at TextMin and is at least 40 px wide", table.concat(tight, ","))
local ownNow = {}
for kind in Config.MonsterTypes do
	local keys = B.ArtKeys(kind)
	if keys[1] ~= (PENDING_ART[kind] or ("BarkBubble" .. kind)) or table.find(keys, "BarkBubble") then table.insert(ownNow, kind) end
end
check(#ownNow == 0, "as uploaded: every monster kind draws its own bubble first, never the shared BarkBubble", table.concat(ownNow, ","))

local function monster(pos)
	local m = inst("Model", "Slime")
	local root = inst("Part", "HumanoidRootPart")
	root.Position = pos
	root.Parent = m
	local bar = inst("BillboardGui", "MonsterBar")
	bar.StudsOffset = vec(0, 3.2, 0)
	bar.Parent = root
	return m, root, bar
end
local me = vec(0, 3, 0)
local function bubbleOf(root) return root:FindFirstChild("BarkBubble") end
local function lineOf(root)
	local bb = bubbleOf(root)
	local art = bb and bb:FindFirstChild("Art")
	return art and art:FindFirstChild("Line")
end

-- 1. a new bark near me: one bubble over the head, the line, size / offset / range
local m, root, bar = monster(vec(10, 3, 0))
B.Check(m, root, bar, me)
check(bubbleOf(root) == nil, "no bark yet -> no bubble")
m.Attrs.Bark, m.Attrs.BarkAt = "Blub?", W.Now
B.Check(m, root, bar, me)
local bb = bubbleOf(root)
check(bb ~= nil and lineOf(root) and lineOf(root).Text == "Blub?", "a new BarkAt shows Bark in a bubble over the head", bb and lineOf(root) and lineOf(root).Text)
check(bb and bb.MaxDistance == Config.Barks.MaxDistance and bb.SizeOffset.X == 0.5 and bb.SizeOffset.Y == 0.5
	and math.abs(bb.StudsOffset.Y - (3.2 + 1.1)) < 1e-6 and bb.AlwaysOnTop == false,
	"bubble: MaxDistance from Config.Barks, tail corner at the head (SizeOffset 0.5), above the name tag",
	bb and tostring(bb.MaxDistance))
check(bb and bb:FindFirstChild("Art") and bb:FindFirstChild("Art").ClassName == "ImageLabel", "the slime's own art draws the bubble")
check(bb and bb:FindFirstChild("Art") and bb:FindFirstChild("Art").ArtKey == "BarkBubbleSlime"
	and bb:FindFirstChild("Art").AskedScaleType == "ScaleType.Fit", "a slime draws its uploaded BarkBubbleSlime with Fit (not 9-sliced)",
	bb and bb:FindFirstChild("Art") and tostring(bb:FindFirstChild("Art").ArtKey))
local rect = Config.UIArt.Parts.BarkBubbleSlime.TextRect
local line = lineOf(root)
check(line and line.Position.X == rect[1] and line.Position.Y == rect[2] and line.Size.X == rect[3] and line.Size.Y == rect[4]
	and line.TextWrapped and line.TextScaled, "the line sits in the art's TextRect, wrapped and scaled")
-- 2. the same BarkAt again: nothing new
B.Check(m, root, bar, me)
check(bubbleOf(root) == bb and not bb.Destroyed, "the same BarkAt on the next tick: no new bubble")
-- 3. the same line with a new BarkAt: a new bubble (the server bumps BarkAt even for the same words)
advance(1)
m.Attrs.BarkAt = W.Now
B.Check(m, root, bar, me)
local bb2 = bubbleOf(root)
local count = 0
for _, ch in root.Children do if ch.Name == "BarkBubble" then count += 1 end end
check(bb2 ~= nil and bb2 ~= bb and bb.Destroyed == true and count == 1, "the same line with a new BarkAt shows again (one bubble)", count)
-- 4. the older timer never removes the newer bubble; the newer one goes after Show seconds
advance(Config.Barks.Show - 1 + 0.01)
check(bubbleOf(root) == bb2, "the first bubble's timer leaves the newer bubble")
advance(1)
check(bubbleOf(root) == nil, "the bubble goes after Config.Barks.Show seconds")
-- 5. an old bark when a monster streams in: not shown
local m2, root2, bar2 = monster(vec(5, 3, 0))
m2.Attrs.Bark, m2.Attrs.BarkAt = "Grr!", W.Now - Config.Barks.Show - 1
B.Check(m2, root2, bar2, me)
check(bubbleOf(root2) == nil, "a bark already old when the monster streams in is not shown")
m2.Attrs.BarkAt = W.Now
B.Check(m2, root2, bar2, me)
check(bubbleOf(root2) ~= nil, "its next bark shows")
-- 6. too far / switched off / empty line
local m3, root3, bar3 = monster(vec(Config.Barks.MaxDistance + 5, 3, 0))
B.Check(m3, root3, bar3, me)
m3.Attrs.Bark, m3.Attrs.BarkAt = "Far away", W.Now
B.Check(m3, root3, bar3, me)
check(bubbleOf(root3) == nil, "a monster farther than Config.Barks.MaxDistance: no bubble")
local m4, root4, bar4 = monster(vec(8, 3, 0))
B.Check(m4, root4, bar4, me)
Config.Barks.Enabled = false
m4.Attrs.Bark, m4.Attrs.BarkAt = "Off", W.Now
B.Check(m4, root4, bar4, me)
check(bubbleOf(root4) == nil, "Config.Barks.Enabled = false: no bubble")
Config.Barks.Enabled = true
advance(0.5)
m4.Attrs.Bark, m4.Attrs.BarkAt = "", W.Now
B.Check(m4, root4, bar4, me)
check(bubbleOf(root4) == nil, "an empty line: no bubble")
-- 7. A23-74 (user 2026-10-07 "not cute" / "말풍선 가로로 길쭉한 거 말고"): fixed-size round bubbles, never a wide pill
local slimeSize = Config.UIArt.Parts.BarkBubbleSlime.Size
check(bb and bb.Size.Kind == "Offset" and bb.Size.X == B.ArtW and bb.Size.Y == math.floor(B.ArtW * slimeSize.Y / slimeSize.X + 0.5)
	and bb.Size.X / bb.Size.Y <= 1.5, "the slime's bubble: a fixed ArtW wide, height from its art (512 x 415 -> 104 x 84, round)",
	bb and (bb.Size.X .. "x" .. bb.Size.Y))
advance(0.5)
m4.Attrs.Bark, m4.Attrs.BarkAt = "Wobbly... so wobbly... blub.", W.Now
B.Check(m4, root4, bar4, me)
local b4 = bubbleOf(root4)
check(b4 and b4.Size.X == bb.Size.X and b4.Size.Y == bb.Size.Y, "a longer line keeps the same fixed size (no width per letter)",
	b4 and (b4.Size.X .. "x" .. b4.Size.Y))
check(B.SizeFor == nil and type(B.SizeOf) == "function", "no per-letter sizing left (B.SizeFor gone, B.SizeOf per art)")
-- the line wraps (at most 2 lines: one sound word) and scales between TextMin and TextMax
local l4 = lineOf(root4)
local c4 = l4 and l4:FindFirstChild("UITextSizeConstraint")
check(l4 and l4.TextWrapped == true and l4.TextScaled == true and l4.LineHeight == B.LineHeight and B.LineHeight <= 1
	and c4 and c4.MaxTextSize == B.TextMax and c4.MinTextSize == B.TextMin and B.TextMin >= 10 and B.TextMin < B.TextMax,
	"the line wraps and scales between TextMin and TextMax", l4 and tostring(l4.LineHeight))
check(B.TextMax > 18, "the text may grow bigger than before (MaxTextSize > 18)", B.TextMax)
-- the round Head font (UIKit.ApplyFont ExtraBold / Head = the HUD bubble's Button face); Fredoka One without UIKit
local fc = fontCalls[#fontCalls]
check(fc and fc.Label == lineOf(root4) and fc.Weight == "FontWeight.ExtraBold" and fc.Role == "Head",
	"the line uses the game's Head face (ExtraBold)")
local applyFont = kit.ApplyFont
kit.ApplyFont = nil
advance(0.5)
m4.Attrs.Bark, m4.Attrs.BarkAt = "Blub?", W.Now
B.Check(m4, root4, bar4, me)
check(lineOf(root4) and lineOf(root4).Font == "Font.FredokaOne", "without UIKit.ApplyFont: Fredoka One (never GothamBold)",
	lineOf(root4) and lineOf(root4).Font)
kit.ApplyFont = applyFont

-- 8. A23-74 (user 2026-10-07 "몬스터마다 다른 말풍선 그려야지" / "말풍선 가로로 길쭉한 거 말고"): BarkBubble<Kind> -> its
-- family's -> the round code bubble; never the shared 9-slice BarkBubble (512 x 190: at 112 x 60 its body is ~2.4 : 1)
check(parts.BarkBubblePumpkin == nil and parts.BarkBubbleGhost == nil, "no family-only keys left (BarkBubblePumpkin / BarkBubbleGhost)")
local badFam = {}
for kind, fam in Config.Barks.BubbleFamily do
	if Config.MonsterTypes[kind] == nil or type(Config.Barks.BubbleArt[fam]) ~= "string" then table.insert(badFam, kind) end
end
for fam, key in Config.Barks.BubbleArt do
	local ownKind = string.sub(key, 11)
	if string.sub(key, 1, 10) ~= "BarkBubble" or Config.MonsterTypes[ownKind] == nil or Config.Barks.BubbleFamily[ownKind] ~= fam then
		table.insert(badFam, fam)
	end
end
check(#badFam == 0 and Config.Barks.BubbleArt.Default == nil,
	"every family points at one of its own monsters' keys; no Default (the shared BarkBubble is not a bark fallback)",
	table.concat(badFam, ","))
-- before the upload (Id ""): no art key at all -> the round code bubble
for key in real do parts[key].Id = "" end
check(B.ArtKey("Slime") == nil and B.ArtKey("GhostKing") == nil and B.ArtKey(nil) == nil and #B.ArtKeys("Slime") == 0
	and #B.ArtKeys(nil) == 0, "nothing uploaded: no art key for any kind (the round code bubble), never BarkBubble",
	tostring(B.ArtKey("Slime")))
-- the review finding: UIKit could draw the shared BarkBubble, but a kind without its own / family art never asks for it
local mN, rootN, barN = monster(vec(9, 3, 0))
B.Check(mN, rootN, barN, me)
advance(0.5)
mN.Attrs.Bark, mN.Attrs.BarkAt = "Blub?", W.Now
local askedN = #artAsked
B.Check(mN, rootN, barN, me)
local bN = bubbleOf(rootN)
local artN = bN and bN:FindFirstChild("Art")
local cornerN = artN and artN:FindFirstChild("UICorner")
check(kitArt and uploaded.BarkBubble == true and #artAsked == askedN and artN and artN.ClassName == "Frame"
	and bN.Size.X == B.CodeW and bN.Size.Y == B.CodeH and cornerN and cornerN.CornerRadius[1] == 0.5 and artN:FindFirstChild("Tail") ~= nil,
	"no round art uploaded: the round code bubble (CodeW x CodeH, fully round, tail dot), the shared BarkBubble never asked",
	artN and (artN.ClassName .. " " .. bN.Size.X .. "x" .. bN.Size.Y .. " asked " .. (#artAsked - askedN)))
-- a 9-sliced key is skipped even when a family names it
Config.Barks.BubbleArt.Slime = "BarkBubble"
check(#B.ArtKeys("BigSlime") == 0 and #B.ArtKeys("Slime") == 0, "a 9-sliced key (the shared BarkBubble) is never a bark bubble, "
	.. "even when a family names it", table.concat(B.ArtKeys("BigSlime"), ","))
Config.Barks.BubbleArt.Slime = "BarkBubbleSlime"
parts.BarkBubbleSlime.Id = "rbxassetid://1"
check(B.ArtKey("Slime") == "BarkBubbleSlime", "the slime's own bubble once uploaded", B.ArtKey("Slime"))
local keys = B.ArtKeys("BigSlime")
check(keys[1] == "BarkBubbleSlime" and #keys == 1,
	"the King Slime borrows the slime bubble (its family) until its own is up", table.concat(keys, ","))
parts.BarkBubbleBigSlime.Id = "rbxassetid://2"
keys = B.ArtKeys("BigSlime")
check(keys[1] == "BarkBubbleBigSlime" and keys[2] == "BarkBubbleSlime" and #keys == 2,
	"order: its own -> its family's (no BarkBubble after them)", table.concat(keys, ","))
check(B.ArtKey("PumpkinSlime") == nil and B.ArtKey("Goblin") == nil and B.ArtKey("Skeleton") == nil,
	"a pumpkin slime never borrows the slime bubble (its own family); goblins / skeletons: the code bubble", B.ArtKey("PumpkinSlime"))
Config.MonsterTypes.TestJelly = { QuestAs = "Slime" }
check(B.ArtKey("TestJelly") == "BarkBubbleSlime", "a kind not listed uses its QuestKind's family", B.ArtKey("TestJelly"))
Config.MonsterTypes.TestJelly = nil
parts.BarkBubbleSlime.Id, parts.BarkBubbleBigSlime.Id = "", ""
-- family fallbacks while only the base monsters are drawn
parts.BarkBubbleGoblin.Id, parts.BarkBubbleSkeleton.Id = "rbxassetid://3", "rbxassetid://4"
parts.BarkBubbleGhostMinion.Id, parts.BarkBubblePumpkinSlime.Id = "rbxassetid://5", "rbxassetid://6"
check(B.ArtKey("GoblinBrute") == "BarkBubbleGoblin" and B.ArtKey("BatGoblin") == "BarkBubbleGoblin"
	and B.ArtKey("SkeletonKnight") == "BarkBubbleSkeleton" and B.ArtKey("GhostKing") == "BarkBubbleGhostMinion"
	and B.ArtKey("LittleGhost") == "BarkBubbleGhostMinion" and B.ArtKey("PumpkinKing") == "BarkBubblePumpkinSlime",
	"family fallbacks: brute / bat -> goblin, knight -> skeleton, ghosts -> ghost minion, pumpkin king -> pumpkin slime")
parts.BarkBubbleGoblin.Id, parts.BarkBubbleSkeleton.Id, parts.BarkBubbleGhostMinion.Id, parts.BarkBubblePumpkinSlime.Id = "", "", "", ""

-- drawing a monster's own round art: fixed ~104 px wide, height from its Size, ScaleType Fit, its TextRect
parts.BarkBubbleSlime.Id = "rbxassetid://1"
parts.BarkBubbleSlime.Size = env.Vector2.new(640, 512)
parts.BarkBubbleSlime.TextRect = { 0.1, 0.2, 0.8, 0.5 }
advance(0.5)
m4.Attrs.Bark, m4.Attrs.BarkAt = "Blub!", W.Now
B.Check(m4, root4, bar4, me)
local b6 = bubbleOf(root4)
local art6 = b6 and b6:FindFirstChild("Art")
local line6 = lineOf(root4)
check(art6 and art6.ArtKey == "BarkBubbleSlime" and art6.AskedScaleType == "ScaleType.Fit",
	"a slime draws its own bubble with ScaleType Fit (not 9-sliced)", art6 and (tostring(art6.ArtKey) .. " " .. tostring(art6.AskedScaleType)))
check(b6 and b6.Size.Kind == "Offset" and b6.Size.X == B.ArtW and B.ArtW >= 96 and B.ArtW <= 110 and b6.Size.Y == math.floor(B.ArtW * 0.8 + 0.5),
	"its own bubble: a fixed ~104 px wide, height from its Size (640 x 512 -> 4 : 5)", b6 and (b6.Size.X .. "x" .. b6.Size.Y))
check(line6 and line6.Position.X == 0.1 and line6.Position.Y == 0.2 and line6.Size.X == 0.8 and line6.Size.Y == 0.5
	and line6.TextWrapped and line6.TextScaled, "the line sits in its own TextRect, wrapped and scaled")
advance(0.5)
m4.Attrs.Bark, m4.Attrs.BarkAt = "Blub… blub… blub… blub…", W.Now
B.Check(m4, root4, bar4, me)
b6 = bubbleOf(root4)
check(b6 and b6.Size.X == B.ArtW and b6.Size.Y == math.floor(B.ArtW * 0.8 + 0.5), "a longer line: its own bubble keeps its size",
	b6 and (b6.Size.X .. "x" .. b6.Size.Y))
local sw, sh = B.SizeOf({ Id = "x" })
check(sw == B.ArtW and sh == math.floor(B.ArtW * B.ArtAspect + 0.5) and B.ArtAspect >= 0.6 and B.ArtAspect <= 0.85,
	"no Size: ArtAspect (a round 1.2-1.6 : 1 bubble)", sw .. "x" .. sh)
sw, sh = B.SizeOf({ Id = "x", Size = env.Vector2.new(1000, 200) })
check(sw == B.ArtW and sh == B.ArtHMin and B.ArtHMin >= 56, "a very wide Size: still ~104 px wide, height clamped (never a pill)", sw .. "x" .. sh)
sw, sh = B.SizeOf({ Id = "x", Size = env.Vector2.new(200, 1000) })
check(sw == B.ArtW and sh == B.ArtHMax and B.ArtHMax <= 110, "a very tall Size: height clamped to ArtHMax", sw .. "x" .. sh)
parts.BarkBubbleSlime.TextRect = nil
advance(0.5)
m4.Attrs.Bark, m4.Attrs.BarkAt = "Boing!", W.Now
B.Check(m4, root4, bar4, me)
line6 = lineOf(root4)
check(line6 and line6.Position.X == B.RoundRect[1] and line6.Position.Y == B.RoundRect[2] and line6.Size.X == B.RoundRect[3]
	and line6.Size.Y == B.RoundRect[4], "its own art without a TextRect: the line in RoundRect")
-- a King Slime: its own art cannot draw -> the slime's (family) -> the round code bubble (never BarkBubble)
local mk, rootK, barK = monster(vec(7, 3, 0))
mk.Attrs.MonsterKind = "BigSlime"
B.Check(mk, rootK, barK, me)
parts.BarkBubbleBigSlime.Id = "rbxassetid://2" -- uploaded in Config, but UIKit cannot draw it (the double)
uploaded.BarkBubbleBigSlime = nil
advance(0.5)
mk.Attrs.Bark, mk.Attrs.BarkAt = "BLOOP!", W.Now
local asked0 = #artAsked
B.Check(mk, rootK, barK, me)
local artK = bubbleOf(rootK) and bubbleOf(rootK):FindFirstChild("Art")
check(artK and artK.ArtKey == "BarkBubbleSlime" and artAsked[asked0 + 1] == "BarkBubbleBigSlime" and artAsked[asked0 + 2] == "BarkBubbleSlime",
	"the King Slime's own art fails to draw -> the slime bubble (tried in order)", artK and artK.ArtKey)
uploaded.BarkBubbleSlime = nil
advance(0.5)
mk.Attrs.Bark, mk.Attrs.BarkAt = "SPLOOSH!", W.Now
asked0 = #artAsked
B.Check(mk, rootK, barK, me)
local bK = bubbleOf(rootK)
artK = bK and bK:FindFirstChild("Art")
check(artK and artK.ClassName == "Frame" and bK.Size.X == B.CodeW and bK.Size.Y == B.CodeH and #artAsked == asked0 + 2
	and artAsked[asked0 + 2] == "BarkBubbleSlime", "neither draws -> the round code bubble (BarkBubble never tried)",
	artK and (artK.ClassName .. " " .. tostring(artAsked[#artAsked])))
-- back to the uploaded Config (all 12 drawable)
for key, r in real do
	parts[key].Id, parts[key].Size, parts[key].TextRect = r.Id, r.Size, r.TextRect
	uploaded[key] = true
end
advance(Config.Barks.Show + 0.01)

-- 9. motion: jelly pop from the tail corner, a float while shown, shrink + fade at the end, every tween cancelled
local function tweensOf(target)
	local out = {}
	for _, tw in tweens do if tw.Inst == target then table.insert(out, tw) end end
	return out
end
local m7, root7, bar7 = monster(vec(6, 3, 0))
B.Check(m7, root7, bar7, me)
advance(0.5)
m7.Attrs.Bark, m7.Attrs.BarkAt = "Blub?", W.Now
B.Check(m7, root7, bar7, me)
local b7 = bubbleOf(root7)
local art7 = b7 and b7:FindFirstChild("Art")
local pop7 = art7 and art7:FindFirstChild("Pop")
check(art7 and art7.AnchorPoint.X == 0 and art7.AnchorPoint.Y == 1 and art7.Position.X == 0 and art7.Position.Y == 1,
	"the art grows out of the tail corner (bottom left)")
check(pop7 and pop7.ClassName == "UIScale" and pop7.Scale == B.From and B.From < 0.6, "it pops in from small (UIScale From)")
local popT = tweensOf(pop7)[1]
check(popT and popT.Played and popT.Goal.Scale == 1 and popT.Info.Args[2] == "EasingStyle.Back"
	and popT.Info.Args[1] >= 0.25 and popT.Info.Args[1] <= 0.5, "pop: Back overshoot to 1 in about 0.35 s")
local jellyT = tweensOf(art7)[1]
check(art7 and art7.Size.X == B.Stretch[1] and art7.Size.Y == B.Stretch[2] and B.Stretch[1] < 1 and B.Stretch[2] > 1
	and jellyT and jellyT.Played and jellyT.Goal.Size.X == 1 and jellyT.Goal.Size.Y == 1
	and jellyT.Info.Args[2] == "EasingStyle.Elastic", "squash & stretch: tall-narrow -> 1 x 1 with an elastic wobble")
local bobT = tweensOf(b7)[1]
check(bobT and bobT.Played and bobT.Info.Args[4] == -1 and bobT.Info.Args[5] == true and bobT.Goal.StudsOffset
	and math.abs(bobT.Goal.StudsOffset.Y - (b7.StudsOffset.Y + B.Bob)) < 1e-6 and B.Bob > 0 and B.Bob <= 0.3,
	"a gentle float up and down while shown (looping StudsOffset tween)")
local line7 = lineOf(root7)
advance(Config.Barks.Show - B.Out - 0.05)
check(#tweensOf(line7) == 0, "no fade before the last B.Out seconds")
advance(0.1)
local fadeT = tweensOf(line7)[1]
local shrinkT = tweensOf(pop7)[2]
check(bubbleOf(root7) == b7 and fadeT and fadeT.Goal.TextTransparency == 1 and shrinkT and shrinkT.Goal.Scale == B.OutScale
	and B.OutScale < 1, "at the end it shrinks and fades instead of vanishing")
local artFade = false
for _, tw in tweensOf(art7) do if tw.Goal.ImageTransparency == 1 then artFade = true end end
check(artFade, "the art image fades too")
advance(B.Out)
check(bubbleOf(root7) == nil, "the bubble goes after Config.Barks.Show seconds (with the fade)")
local allCancelled = true
for _, target in { b7, art7, pop7, line7 } do
	for _, tw in tweensOf(target) do if not tw.Cancelled then allCancelled = false end end
end
check(allCancelled and bobT.Cancelled, "every tween of a destroyed bubble is cancelled (the float loop stops)")
-- a newer bark replaces a bubble mid-float: the old one's tweens stop, its fade never starts
advance(0.5)
m7.Attrs.Bark, m7.Attrs.BarkAt = "Blub!", W.Now
B.Check(m7, root7, bar7, me)
local b8 = bubbleOf(root7)
local line8 = lineOf(root7)
local bob8 = tweensOf(b8)[1]
advance(0.5)
m7.Attrs.Bark, m7.Attrs.BarkAt = "Bloop! Rude.", W.Now
B.Check(m7, root7, bar7, me)
check(b8.Destroyed and bob8 and bob8.Cancelled, "a replaced bubble's float stops")
advance(Config.Barks.Show - 0.5 - B.Out + 0.01)
check(line8 and #tweensOf(line8) == 0, "a replaced bubble never fades (its timer sees it gone)")
advance(1)
check(bubbleOf(root7) == nil, "the newer bubble still goes on time")
-- reduced motion: no pop, no float, no fade - it shows and goes
reducedMotion = true
advance(0.5)
local n0 = #tweens
m7.Attrs.Bark, m7.Attrs.BarkAt = "Blub?", W.Now
B.Check(m7, root7, bar7, me)
local b9 = bubbleOf(root7)
local art9 = b9 and b9:FindFirstChild("Art")
check(b9 and art9 and art9:FindFirstChild("Pop") == nil and art9.Size.X == 1 and art9.Size.Y == 1 and #tweens == n0,
	"UIKit.ReducedMotion: no pop, no wobble, no float", #tweens - n0)
advance(Config.Barks.Show + 0.01)
check(bubbleOf(root7) == nil and #tweens == n0, "reduced motion: no fade either, the bubble just goes")
reducedMotion = false

-- 10. the code fallback (A23-74): a round compact white bubble (about 96 x 70, not a long pill) with a thin soft rim and
-- a small round tail dot under its bottom left, the line in CodeRect, and it all fades too
kitArt = false
advance(0.5)
m4.Attrs.Bark, m4.Attrs.BarkAt = "Blub!", W.Now
B.Check(m4, root4, bar4, me)
local b5 = bubbleOf(root4)
local art5 = b5 and b5:FindFirstChild("Art")
local corner5 = art5 and art5:FindFirstChild("UICorner")
local rim5 = art5 and art5:FindFirstChild("UIStroke")
check(art5 and art5.ClassName == "Frame" and rim5 and corner5 and art5:FindFirstChild("Line") and art5.BackgroundColor3
	and art5.BackgroundColor3.R == 1 and art5.BackgroundColor3.G == 1 and art5.BackgroundColor3.B == 1,
	"without the art: a white round box with a rim (code fallback)")
check(b5 and b5.Size.Kind == "Offset" and b5.Size.X == B.CodeW and b5.Size.Y == B.CodeH and B.CodeW >= 88 and B.CodeW <= 104
	and B.CodeH >= 62 and B.CodeH <= 78, "the code bubble is round and compact (about 96 x 70 px), not a long pill",
	b5 and (b5.Size.X .. "x" .. b5.Size.Y))
check(corner5 and corner5.CornerRadius[1] == 0.5 and corner5.CornerRadius[2] == 0, "the code bubble's corner is fully round")
check(rim5 and rim5.Thickness < 2 and rim5.Transparency > 0, "the code bubble's rim is soft (thin, see-through)")
local tail5 = art5 and art5:FindFirstChild("Tail")
local tailCorner = tail5 and tail5:FindFirstChild("UICorner")
check(tail5 and tail5.ClassName == "Frame" and tail5.Size.Kind == "Offset" and tail5.Size.X == B.Tail and tail5.Size.Y == B.Tail
	and B.Tail <= 16 and tail5.Position.Kind == "New" and tail5.Position.XS == 0 and tail5.Position.YS == 1 and tail5.Position.XO <= 8
	and tailCorner and tailCorner.CornerRadius[1] == 0.5 and tail5:FindFirstChild("UIStroke"),
	"a small round tail dot (<= 16 px, rimmed) under the bottom left")
local line5 = lineOf(root4)
check(line5 and line5.Position.X == B.CodeRect[1] and line5.Position.Y == B.CodeRect[2] and line5.Size.X == B.CodeRect[3]
	and line5.Size.Y == B.CodeRect[4] and line5.TextWrapped and line5.TextScaled, "the code bubble's line sits in CodeRect, wrapped")
advance(0.5)
m4.Attrs.Bark, m4.Attrs.BarkAt = "Blub… blub… blub… blub…", W.Now
B.Check(m4, root4, bar4, me)
b5 = bubbleOf(root4)
art5 = b5 and b5:FindFirstChild("Art")
rim5 = art5 and art5:FindFirstChild("UIStroke")
tail5 = art5 and art5:FindFirstChild("Tail")
check(b5 and b5.Size.X == B.CodeW and b5.Size.Y == B.CodeH, "a longer line: the code bubble keeps its size")
advance(Config.Barks.Show - B.Out + 0.01)
local function fadesTo(target, prop)
	for _, tw in tweensOf(target) do if tw.Goal[prop] == 1 then return true end end
	return false
end
check(fadesTo(rim5, "Transparency") and fadesTo(art5, "BackgroundTransparency"), "the code bubble and its rim fade out too")
check(tail5 and fadesTo(tail5, "BackgroundTransparency") and fadesTo(tail5:FindFirstChild("UIStroke"), "Transparency"),
	"the tail dot and its rim fade out too")
-- A23-74 (user 2026-10-07 "말풍선 가로로 길쭉한 거 말고"): in the whole run no bark ever asked UIKit for the shared wide BarkBubble
check(#artAsked > 0 and table.find(artAsked, "BarkBubble") == nil, "no bark ever asks for the shared 9-slice BarkBubble",
	#artAsked .. " asks")
print("MONSTER_BARK_SUMMARY checks=" .. checks .. " failed=" .. failed)
