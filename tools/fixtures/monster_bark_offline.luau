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
local uploaded = { BarkBubble = true } -- the art ids the UIKit double can draw
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
		fromScale = function(x, y) return { Kind = "Scale", X = x, Y = y } end },
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
check(bb and bb:FindFirstChild("Art") and bb:FindFirstChild("Art").ClassName == "ImageLabel", "the BarkBubble art draws the bubble")
local rect = Config.UIArt.Parts.BarkBubble.TextRect
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
-- 7. A23-74 (user 2026-10-07 "not cute"): small round bubbles, the width follows the letters, max 2 lines
check(bb and bb.Size.Kind == "Offset" and bb.Size.X >= 150 and bb.Size.X <= 172 and bb.Size.Y >= 40 and bb.Size.Y <= 46,
	"a short line: a small bubble (150-172 x 40-46 px)", bb and (bb.Size.X .. "x" .. bb.Size.Y))
local function wOf(text) local w = B.SizeFor(text) return w end
check(wOf("Blub?") <= wOf("Team Boo, go!") and wOf("Team Boo, go!") <= wOf("Squish! My stem!") and wOf("Squish! My stem!") <= 172
	and wOf("Team Boo, go!") > wOf("Blub?"), "a longer one-line bark gets a wider bubble (<= 172 px)",
	wOf("Blub?") .. "/" .. wOf("Team Boo, go!") .. "/" .. wOf("Squish! My stem!"))
check(wOf("Blub… blub…") == wOf("Blub. blub."), "the width counts letters, not bytes (… is one letter)", wOf("Blub… blub…"))
advance(0.5)
m4.Attrs.Bark, m4.Attrs.BarkAt = "Wobbly... so wobbly... blub.", W.Now
B.Check(m4, root4, bar4, me)
local b4 = bubbleOf(root4)
check(b4 and b4.Size.Y == B.H2 and b4.Size.X >= B.W2 and b4.Size.X <= B.W2Max and B.H2 > B.H,
	"a long line gets the two-line bubble", b4 and (b4.Size.X .. "x" .. b4.Size.Y))
local _, longH = B.SizeFor("A visitor! Bow! Or wobble. Either works.")
check(longH == B.H2 and wOf("A visitor! Bow! Or wobble. Either works.") == B.W2Max, "the longest lines stop at W2Max x H2 (two lines)")
-- the round Head font (UIKit.ApplyFont ExtraBold / Head = the HUD bubble's Button face); Fredoka One without UIKit
local fc = fontCalls[#fontCalls]
check(fc and fc.Label == lineOf(root4) and fc.Weight == "FontWeight.ExtraBold" and fc.Role == "Head",
	"the line uses the game's Head face (ExtraBold)")
local lineMax = lineOf(root4) and lineOf(root4):FindFirstChild("UITextSizeConstraint")
check(lineMax and lineMax.MaxTextSize == B.TextMax and B.TextMax > 18, "the text may grow bigger than before (MaxTextSize > 18)")
local applyFont = kit.ApplyFont
kit.ApplyFont = nil
advance(0.5)
m4.Attrs.Bark, m4.Attrs.BarkAt = "Blub?", W.Now
B.Check(m4, root4, bar4, me)
check(lineOf(root4) and lineOf(root4).Font == "Font.FredokaOne", "without UIKit.ApplyFont: Fredoka One (never GothamBold)",
	lineOf(root4) and lineOf(root4).Font)
kit.ApplyFont = applyFont

-- 8. per-family bubble art keys (Config.Barks.BubbleFamily / BubbleArt), used only once uploaded
local parts = Config.UIArt.Parts
check(parts.BarkBubbleSlime and parts.BarkBubbleSlime.Id == "" and parts.BarkBubblePumpkin and parts.BarkBubblePumpkin.Id == ""
	and parts.BarkBubbleGhost and parts.BarkBubbleGhost.Id == "", "the three family keys exist, not uploaded yet (Id \"\")")
check(B.ArtKey("Slime") == "BarkBubble" and B.ArtKey("GhostKing") == "BarkBubble" and B.ArtKey(nil) == "BarkBubble",
	"not uploaded: every family falls back to BarkBubble", B.ArtKey("Slime"))
parts.BarkBubbleSlime.Id = "rbxassetid://1"
check(B.ArtKey("Slime") == "BarkBubbleSlime" and B.ArtKey("BigSlime") == "BarkBubbleSlime", "slimes and the King Slime: the slime bubble")
check(B.ArtKey("PumpkinSlime") == "BarkBubble", "the pumpkin family is its own (not the slime bubble), BarkBubble until uploaded",
	B.ArtKey("PumpkinSlime"))
check(B.ArtKey("Goblin") == "BarkBubble" and B.ArtKey("BatGoblin") == "BarkBubble" and B.ArtKey("Skeleton") == "BarkBubble",
	"goblins / skeletons: the default bubble")
Config.MonsterTypes.TestJelly = { QuestAs = "Slime" }
check(B.ArtKey("TestJelly") == "BarkBubbleSlime", "a kind not listed uses its QuestKind's family", B.ArtKey("TestJelly"))
Config.MonsterTypes.TestJelly = nil
parts.BarkBubblePumpkin.Id = "rbxassetid://2"
parts.BarkBubbleGhost.Id = "rbxassetid://3"
check(B.ArtKey("PumpkinSlime") == "BarkBubblePumpkin" and B.ArtKey("PumpkinKing") == "BarkBubblePumpkin"
	and B.ArtKey("GhostMinion") == "BarkBubbleGhost" and B.ArtKey("LittleGhost") == "BarkBubbleGhost"
	and B.ArtKey("GhostKing") == "BarkBubbleGhost", "pumpkins and ghosts get their own bubbles once uploaded")
-- the bubble draws the family art with its own TextRect; art UIKit cannot draw -> BarkBubble
uploaded.BarkBubbleSlime = true
parts.BarkBubbleSlime.TextRect = { 0.1, 0.2, 0.8, 0.5 }
advance(0.5)
m4.Attrs.Bark, m4.Attrs.BarkAt = "Blub!", W.Now
B.Check(m4, root4, bar4, me)
local art6 = bubbleOf(root4) and bubbleOf(root4):FindFirstChild("Art")
local line6 = lineOf(root4)
check(art6 and art6.ArtKey == "BarkBubbleSlime" and line6 and line6.Position.X == 0.1 and line6.Position.Y == 0.2
	and line6.Size.X == 0.8 and line6.Size.Y == 0.5, "a slime draws the slime bubble with its TextRect", art6 and art6.ArtKey)
uploaded.BarkBubbleSlime = nil
advance(0.5)
m4.Attrs.Bark, m4.Attrs.BarkAt = "Blub!", W.Now
B.Check(m4, root4, bar4, me)
art6 = bubbleOf(root4) and bubbleOf(root4):FindFirstChild("Art")
check(art6 and art6.ArtKey == "BarkBubble", "the family art fails to draw -> BarkBubble", art6 and art6.ArtKey)
parts.BarkBubbleSlime.Id, parts.BarkBubblePumpkin.Id, parts.BarkBubbleGhost.Id = "", "", ""
parts.BarkBubbleSlime.TextRect = nil

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

-- 10. the code fallback: a white pill with a thin soft rim, text in PillRect, and it fades too
kitArt = false
advance(0.5)
m4.Attrs.Bark, m4.Attrs.BarkAt = "Blub!", W.Now
B.Check(m4, root4, bar4, me)
local b5 = bubbleOf(root4)
local art5 = b5 and b5:FindFirstChild("Art")
local corner5 = art5 and art5:FindFirstChild("UICorner")
local rim5 = art5 and art5:FindFirstChild("UIStroke")
check(art5 and art5.ClassName == "Frame" and rim5 and corner5 and art5:FindFirstChild("Line"),
	"without the art: a white rounded box with a rim (code fallback)")
check(corner5 and corner5.CornerRadius[1] == 0.5 and corner5.CornerRadius[2] == 0, "the fallback is a pill (fully round)")
check(rim5 and rim5.Thickness < 2 and rim5.Transparency > 0, "the fallback rim is softer (thinner, see-through)")
local line5 = lineOf(root4)
check(line5 and line5.Position.X == B.PillRect[1] and line5.Size.Y == B.PillRect[4], "the fallback text sits in PillRect")
advance(Config.Barks.Show - B.Out + 0.01)
local rimFade, bgFade = false, false
for _, tw in tweensOf(rim5) do if tw.Goal.Transparency == 1 then rimFade = true end end
for _, tw in tweensOf(art5) do if tw.Goal.BackgroundTransparency == 1 then bgFade = true end end
check(rimFade and bgFade, "the fallback pill and its rim fade out too")
print("MONSTER_BARK_SUMMARY checks=" .. checks .. " failed=" .. failed)
