"""황금 알 줍기, the client side (게임성 개발 1, SPEC A23-131 / A23-134), offline.

Runs, in the official Luau CLI, the CURRENT EggFx.luau pure helpers (cut from the source between the "pure helpers" and
"world pieces" markers) with fake Vector3s: Arc (an egg flies from From to its spot over FlyTime s before LandAt along a
parabola whose peak is clamp(distance x k, min, max); at / after LandAt it rests on its spot; without From it is
already down), CanPick (the pickup preview: landed, EggCan, moved lately, flat <= PickRadius and height <= PickHeight; a 3-slot egg
only with empty hands, else carry + slots <= MaxSlots), Wobble (0 inside WobbleFrom, 1 at RingRadius; 0 before
IdleWobble s standing, 1 at IdleReturn; the larger), HomeOf (Config.Goose.Egg.Home by faction, none for None),
TickEnd (the crown egg's overtime when it runs, else the event's end), Bar (Versus: the Knights' fill share, both
points rounded to whole numbers; co-op: "ours / goal" and that share; the seconds left up to the overtime). Static:
ClientMain loads EggFx; EggFx hides the server egg part (LocalTransparencyModifier) and draws no PointLight / Highlight /
Beam, fires no remote, waits GoneWait for an EggReturn before a "picked" pop; EventHUD's Eggs branch draws the bar from
EggFx.Bar and hides the line under it; Audio plays the deliveries / tags (EggDeliver / EggTag, stand-ins until the
files) and counts the last 3-2-1 from EggFx.TickFor; QuestMarker points home while I carry eggs; QuestTarget points carrying eggs home, empty hands at the goose;
WorldMap shows the nest and the egg cart; Config.GooseEggFx and the 7 egg sounds exist. Mutations: each must be caught.

Usage: py tools/test_egg_fx.py
Report: docs/art/verification_2026-10-11/offline_egg_fx_2026-10-11.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"EGG": SPS / "EggFx.luau", "MAIN": SPS / "ClientMain.client.luau", "HUD": SPS / "EventHUD.luau",
         "AUDIO": SPS / "Audio.luau", "QT": SPS / "QuestTarget.luau", "MAP": SPS / "WorldMap.luau", "QM": SPS / "QuestMarker.luau",
         "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-11/offline_egg_fx_2026-10-11.json"

HARNESS = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local V3 = {}
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end
V3.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Lerp" then return function(a, b, t) return vec(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t) end end
	return nil
end
local Vector3 = { new = vec, zero = vec(0, 0, 0) }
local function typeof(v) if getmetatable(v) == V3 then return "Vector3" end return type(v) end
local EggFx = {}
local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default
end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end

-- A23-141 stubs: my player's attributes, GameState, the Remotes folder (the GooseSquare remote may be missing), workspace
local attrs = { InGooseSquare = true }
local LocalPlayer = { GetAttribute = function(_, k) return attrs[k] end }
local Config = { Goose = { Mode = "Eggs", Square = { Remote = "GooseSquare", Attr = "InGooseSquare", Block = "GooseJoinBlock" },
	Egg = { Home = { Halo = vec(-30, 0, -30), Horns = vec(-30, 0, 30) } } }, RateLimits = {} }
local gsAttrs = { GooseActive = true }
local fired = {}
local remoteOn = true
local remotes = {}
local remote = { Name = "GooseSquare", Parent = remotes, IsA = function(_, c) return c == "RemoteEvent" end,
	FireServer = function(_, w) table.insert(fired, w) end }
remotes.FindFirstChild = function(_, n) if remoteOn and n == "GooseSquare" then return remote end return nil end
local gsFolder = { GetAttribute = function(_, k) return gsAttrs[k] end }
local ReplicatedStorage = { FindFirstChild = function(_, n)
	if n == "Remotes" then return remotes elseif n == "GameState" then return gsFolder end
	return nil
end }
local S = { SquareIn = false }
local fades = 0
function EggFx.Fade() fades += 1 end
local function serverNow() return 1000 end
local function eggCfg() return Config.Goose.Egg end
local sqAttrs, nestPart, squareModel = {}, nil, nil
local workspace = { FindFirstChild = function(_, n) if n == "GooseSquare" then return squareModel end return nil end }

-- PURE --
-- HOMES --

local NOW = 1000
-- Arc
local from, to = vec(0, 10, 0), vec(10, 0, 0)
local arc = { 0.35, 1.5, 6 }
local p0, l0 = EggFx.Arc(from, to, NOW + 0.7, 0.7, NOW, arc)
check(not l0 and near(p0.X, 0) and near(p0.Y, 10), "Arc: the flight starts at From (FlyTime s before LandAt)", p0 and p0.X)
local pe, le = EggFx.Arc(from, to, NOW, 0.7, NOW, arc)
check(le and near(pe.X, 10) and near(pe.Y, 0), "Arc: at LandAt it rests on its spot", pe and pe.Y)
local pl, ll = EggFx.Arc(from, to, NOW - 5, 0.7, NOW, arc)
check(ll and near(pl.X, 10), "Arc: after LandAt it stays on its spot", pl and pl.X)
local pm = EggFx.Arc(from, to, NOW + 0.35, 0.7, NOW, arc)
local dist = math.sqrt(10 * 10 + 10 * 10)
local peak = math.clamp(dist * 0.35, 1.5, 6)
check(near(pm.X, 5, 1e-6) and near(pm.Y, 5 + peak, 1e-6), "Arc: the middle of the flight is the parabola's peak over the line",
	pm and pm.Y)
local pf = EggFx.Arc(vec(0, 0, 0), vec(100, 0, 0), NOW + 0.35, 0.7, NOW, arc)
check(near(pf.Y, 6, 1e-6), "Arc: a long flight's peak is capped (6)", pf and pf.Y)
local pn, ln = EggFx.Arc(nil, to, NOW + 0.35, 0.7, NOW, arc)
check(ln and near(pn.X, 10), "Arc: no From (an egg already down) = on its spot", pn and pn.X)
local pb = EggFx.Arc(from, to, NOW + 3, 0.7, NOW, arc)
check(near(pb.X, 0) and near(pb.Y, 10), "Arc: before its flight starts it waits at From", pb and pb.X)

-- CanPick
local cfg = { Kinds = { Gold = { Slots = 1 }, Bouncy = { Slots = 1 }, Big = { Slots = 3 }, Crown = { Slots = 3 } },
	MaxSlots = 3, PickRadius = 4.5, PickHeight = 6 }
local egg = { Pos = vec(0, 0, 0), LandAt = NOW - 1, Kind = "Gold" }
local me = { Pos = vec(3, 2, 3), Can = true, Carry = 0 }
check(EggFx.CanPick(egg, me, cfg, NOW) == true, "CanPick: a landed gold egg within 4.5 flat / 6 high, empty hands")
check(EggFx.CanPick({ Pos = egg.Pos, LandAt = NOW + 0.2, Kind = "Gold" }, me, cfg, NOW) == false, "CanPick: not while it flies")
check(EggFx.CanPick(egg, { Pos = me.Pos, Can = false, Carry = 0 }, cfg, NOW) == false, "CanPick: not when EggCan is false")
check(EggFx.CanPick(egg, { Pos = me.Pos, Can = true, Carry = 0, Moved = false }, cfg, NOW) == false,
	"CanPick: not while I stand still (the server's away rule)")
check(EggFx.CanPick(egg, { Pos = vec(4.6, 0, 0), Can = true, Carry = 0 }, cfg, NOW) == false, "CanPick: not 4.6 studs away (flat)")
check(EggFx.CanPick(egg, { Pos = vec(1, 6.2, 0), Can = true, Carry = 0 }, cfg, NOW) == false, "CanPick: not 6.2 studs above it")
check(EggFx.CanPick(egg, { Pos = vec(4.4, 5.9, 0), Can = true, Carry = 2 }, cfg, NOW) == true, "CanPick: the 3rd slot is free")
check(EggFx.CanPick(egg, { Pos = me.Pos, Can = true, Carry = 3 }, cfg, NOW) == false, "CanPick: not with 3 slots full")
local big = { Pos = vec(0, 0, 0), LandAt = NOW - 1, Kind = "Big" }
check(EggFx.CanPick(big, { Pos = me.Pos, Can = true, Carry = 0 }, cfg, NOW) == true, "CanPick: a big egg with empty hands")
check(EggFx.CanPick(big, { Pos = me.Pos, Can = true, Carry = 1 }, cfg, NOW) == false, "CanPick: a big egg only with empty hands")
check(EggFx.CanPick({ Pos = vec(0, 0, 0), LandAt = NOW - 1, Kind = "Crown" }, { Pos = me.Pos, Can = true, Carry = 1 }, cfg, NOW) == false,
	"CanPick: the crown egg only with empty hands")

-- Wobble
local wc = { WobbleFrom = 45, RingRadius = 54, IdleWobble = 7, IdleReturn = 10 }
check(EggFx.Wobble(40, 0, wc) == 0, "Wobble: still inside 45 studs and walking", EggFx.Wobble(40, 0, wc))
check(near(EggFx.Wobble(49.5, 0, wc), 0.5), "Wobble: half way from 45 to the ring edge 54", EggFx.Wobble(49.5, 0, wc))
check(EggFx.Wobble(60, 0, wc) == 1, "Wobble: full at / past the ring edge", EggFx.Wobble(60, 0, wc))
check(EggFx.Wobble(10, 6.9, wc) == 0 and near(EggFx.Wobble(10, 8.5, wc), 0.5) and EggFx.Wobble(10, 10, wc) == 1,
	"Wobble: from 7 s standing still to the 10 s return", EggFx.Wobble(10, 8.5, wc))
check(EggFx.Wobble(49.5, 9.4, wc) >= 0.79, "Wobble: the larger of the two", EggFx.Wobble(49.5, 9.4, wc))

-- HomeOf
local hc = { Home = { Halo = vec(-30, 0, -30), Horns = vec(-30, 0, 30) } }
check(EggFx.HomeOf("Halo", hc).Z == -30 and EggFx.HomeOf("Horns", hc).Z == 30, "HomeOf: the nest (-z) / the cart (+z)")
check(EggFx.HomeOf("None", hc) == nil and EggFx.HomeOf("Neutral", hc) == nil and EggFx.HomeOf("Halo", {}) == nil,
	"HomeOf: no home for None / a side without one")

-- TickEnd
local e1, o1 = EggFx.TickEnd(NOW + 10, NOW + 15, NOW)
local e2, o2 = EggFx.TickEnd(NOW + 10, 0, NOW)
local e3, o3 = EggFx.TickEnd(NOW + 10, NOW - 1, NOW)
check(e1 == NOW + 15 and o1 and e2 == NOW + 10 and not o2 and e3 == NOW + 10 and not o3,
	"TickEnd: the crown egg's overtime while it runs, else the event's end")

-- Bar
local b = EggFx.Bar({ Rescue = 30, Poach = 10, EndsAt = NOW + 42, Mode = "Versus" }, NOW)
check(not b.Coop and b.Left == 30 and b.Right == 10 and near(b.Fill, 0.75) and near(b.Seconds, 42) and not b.Overtime,
	"Bar: Versus = the Knights' share of the points, both sides, the seconds left", b.Fill)
local b0 = EggFx.Bar({ Rescue = 0, Poach = 0, EndsAt = NOW + 60 }, NOW)
check(near(b0.Fill, 0.5), "Bar: 0 : 0 = half and half", b0.Fill)
local br = EggFx.Bar({ Rescue = 12.6, Poach = 7.4, EndsAt = NOW + 5 }, NOW)
check(br.Left == 13 and br.Right == 7, "Bar: whole numbers on the bar", br.Left)
local bc = EggFx.Bar({ Rescue = 0, Poach = 50, EndsAt = NOW + 5, Mode = "Coop", CoopSide = "Horns", CoopTarget = 160 }, NOW)
check(bc.Coop and bc.Side == "Horns" and bc.Left == 50 and bc.Right == 160 and near(bc.Fill, 50 / 160),
	"Bar: co-op = our points / the goal and that share", bc.Fill)
local bo = EggFx.Bar({ Rescue = 1, Poach = 1, EndsAt = NOW - 1, OvertimeUntil = NOW + 6 }, NOW)
check(bo.Overtime and near(bo.Seconds, 6), "Bar: the crown egg's overtime = its seconds", bo.Seconds)
local be = EggFx.Bar({ Rescue = 1, Poach = 1, EndsAt = NOW - 3 }, NOW)
check(be.Seconds == 0, "Bar: never below 0 s", be.Seconds)

-- A23-141 Goose Square ------------------------------------------------------------------------------
local function press(word, t) return EggFx.SquarePress(word, t) end
local function setSquare(inside, active, block, hasRemote)
	attrs.InGooseSquare = inside
	attrs.GooseJoinBlock = block
	gsAttrs.GooseActive = active
	remote.Parent = hasRemote and remotes or nil
	remoteOn = hasRemote
	S.SquareRemote = nil
	S.SquareAt = nil
	fired = {}
end

-- Here: the Eggs mode AND my InGooseSquare
attrs.InGooseSquare = true
check(EggFx.Here() == true, "Here: the Eggs mode and I am in the square")
attrs.InGooseSquare = false
check(EggFx.Here() == false, "Here: the Eggs mode but outside the square = not here")
attrs.InGooseSquare = true
Config.Goose.Mode = "Tug"
check(EggFx.Here() == false and EggFx.Inside() == true, "Here: inside the square but not the Eggs mode = not here")
Config.Goose.Mode = "Eggs"
attrs.InGooseSquare = nil
check(EggFx.Here() == false, "Here: no InGooseSquare attribute = not here")
attrs.InGooseSquare = true

-- SquareButton table
local function btn(ctx) return EggFx.SquareButton(ctx) end
check(btn({ Active = false, Inside = false, Block = "", HasRemote = true }) == nil, "SquareButton: no open event = hidden")
local after = btn({ Active = false, Inside = true, HasRemote = true })
check(after ~= nil and after.Word == "Leave" and after.Dim == false,
	"SquareButton (개발 2 10/13): inside after the round = Leave still (a way out before / without the trip home)", after and after.Word)
check(btn(nil) == nil and btn({}) == nil, "SquareButton: no context = hidden")
Config.Goose.Mode = "Tug"
check(btn({ Active = true, Inside = false, Block = "", HasRemote = true }) == nil, "SquareButton: not the Eggs mode = hidden")
Config.Goose.Mode = "Eggs"
local j = btn({ Active = true, Inside = false, Block = "", HasRemote = true })
check(j ~= nil and j.Word == "Join" and j.Dim == false, "SquareButton: open event, outside, no block = Join bright", j and j.Dim)
local j2 = btn({ Active = true, Inside = false, Block = nil, HasRemote = true })
check(j2 ~= nil and j2.Word == "Join" and j2.Dim == false, "SquareButton: no GooseJoinBlock attribute = Join bright (the server refuses by Notify)")
for _, blk in { "Dead", "Monster", "Grudge", "PvP" } do
	local d = btn({ Active = true, Inside = false, Block = blk, HasRemote = true })
	check(d ~= nil and d.Word == "Join" and d.Dim == true, "SquareButton: Join dimmed by Block " .. blk, d and d.Dim)
end
local l = btn({ Active = true, Inside = true, Block = "PvP", HasRemote = true })
check(l ~= nil and l.Word == "Leave" and l.Dim == false, "SquareButton: inside = Leave, never dimmed by a block", l and l.Dim)
local nj = btn({ Active = true, Inside = false, Block = "", HasRemote = false })
local nl = btn({ Active = true, Inside = true, Block = "", HasRemote = false })
check(nj.Word == "Join" and nj.Dim == true and nl.Word == "Leave" and nl.Dim == true, "SquareButton: no remote = both dimmed")

-- SquareCtx reads the world
setSquare(false, true, "Monster", true)
local cx = EggFx.SquareCtx()
check(cx.Active == true and cx.Inside == false and cx.Block == "Monster" and cx.HasRemote == true, "SquareCtx: event, outside, block, remote")
setSquare(true, false, nil, false)
cx = EggFx.SquareCtx()
check(cx.Active == false and cx.Inside == true and cx.Block == nil and cx.HasRemote == false, "SquareCtx: no event, inside, no remote")

-- SquarePress: once, rate-gapped, nothing while dimmed / hidden
setSquare(false, true, "", true)
check(press("Join", 100) == true and #fired == 1 and fired[1] == "Join", "SquarePress: Join fires the remote once with 'Join'", #fired)
check(press("Join", 100.5) == false and #fired == 1, "SquarePress: a second press within 1 s is dropped", #fired)
check(press("Join", 101.1) == true and #fired == 2, "SquarePress: after the gap it fires again", #fired)
Config.RateLimits.GooseSquare = 2
check(press("Join", 102.5) == false and #fired == 2 and press("Join", 103.2) == true and #fired == 3,
	"SquarePress: Config.RateLimits.GooseSquare sets the gap when present", #fired)
Config.RateLimits.GooseSquare = nil
setSquare(false, true, "Dead", true)
check(press("Join", 500) == false and #fired == 0, "SquarePress: a dimmed Join (blocked) fires nothing", #fired)
setSquare(false, true, "", true)
check(press("Leave", 500) == false and #fired == 0, "SquarePress: Leave while outside fires nothing", #fired)
check(press("Dance", 500) == false and press(nil, 500) == false and #fired == 0, "SquarePress: only 'Join' / 'Leave'", #fired)
setSquare(true, true, "PvP", true)
check(press("Join", 600) == false and #fired == 0, "SquarePress: Join while inside fires nothing", #fired)
check(press("Leave", 600) == true and #fired == 1 and fired[1] == "Leave", "SquarePress: Leave inside fires 'Leave' (a block does not stop it)", #fired)
setSquare(false, true, "", false)
check(press("Join", 700) == false and #fired == 0, "SquarePress: no remote (not made yet) = dimmed, nothing fires", #fired)
setSquare(false, false, "", true)
check(press("Join", 800) == false and #fired == 0, "SquarePress: no open event fires nothing", #fired)
setSquare(false, true, "", true)
remoteOn = true
check(EggFx.SquareRemote() == remote, "SquareRemote: found without waiting once it exists")

-- the screen fade: once per change of InGooseSquare, not on a repeat
attrs.InGooseSquare = false
S.SquareIn = false
fades = 0
check(EggFx.SquareChanged() == false and fades == 0, "SquareChanged: the same value (outside -> outside) = no fade", fades)
attrs.InGooseSquare = true
check(EggFx.SquareChanged() == true and fades == 1, "SquareChanged: outside -> inside = one fade", fades)
check(EggFx.SquareChanged() == false and fades == 1, "SquareChanged: inside again = no second fade", fades)
attrs.InGooseSquare = false
check(EggFx.SquareChanged() == true and fades == 2, "SquareChanged: inside -> outside = a fade too", fades)
check(EggFx.SquareChanged() == false and fades == 2, "SquareChanged: outside again = none", fades)

-- the egg screens are off outside the square: Bar / TickFor / HomeTarget / Homes
local barArgs = { Rescue = 3, Poach = 1, EndsAt = NOW + 20 }
attrs.InGooseSquare = false
check(EggFx.Bar(barArgs, NOW) == nil, "Bar: nil outside the Goose Square (no egg bar in the real plaza)")
attrs.InGooseSquare = true
check(EggFx.Bar(barArgs, NOW) ~= nil, "Bar: drawn inside the square")
Config.Goose.Mode = "Tug"
check(EggFx.Bar(barArgs, NOW) == nil, "Bar: nil when it is not the Eggs mode")
Config.Goose.Mode = "Eggs"

local tickGs = { GetAttribute = function(_, k) if k == "GooseEndsAt" then return 1030 end return nil end }
S.Picked = true
attrs.InGooseSquare = false
check(EggFx.TickFor(tickGs) == nil, "TickFor: nil outside the square (no 3-2-1 there)")
attrs.InGooseSquare = true
local pk, pe = EggFx.TickFor(tickGs)
check(pk == true and pe == 1030, "TickFor: inside = (picked, the end)", pe)

attrs.Faction, attrs.EggCarry = "Halo", 2
gsAttrs.GooseActive = true
attrs.InGooseSquare = false
check(EggFx.Homes() == nil and EggFx.HomeFor("Halo") == nil and EggFx.HomeTarget() == nil,
	"Homes / HomeFor / HomeTarget: nil outside the square")
attrs.InGooseSquare = true
local h0 = EggFx.Homes()
check(h0.Halo.Z == -30 and h0.Horns.Z == 30, "Homes: no workspace.GooseSquare = Config.Goose.Egg.Home")
local ht = EggFx.HomeTarget()
check(ht ~= nil and ht.Z == -30 and near(ht.Y, 3), "HomeTarget: carrying eggs inside = my home, 3 studs up", ht and ht.Y)
attrs.EggCarry = 0
check(EggFx.HomeTarget() == nil, "HomeTarget: empty hands = nil")
attrs.EggCarry = 2
gsAttrs.GooseActive = false
check(EggFx.HomeTarget() == nil, "HomeTarget: no open event = nil")
gsAttrs.GooseActive = true
nestPart = { IsA = function(_, c) return c == "BasePart" end, Position = vec(5, 0, 7) }
squareModel = { FindFirstChild = function(_, n) if n == "Nest" then return nestPart end return nil end,
	GetAttribute = function(_, k) return sqAttrs[k] end }
sqAttrs.CartPos = vec(9, 0, 11)
local h1 = EggFx.Homes()
check(h1.Halo.X == 5 and h1.Halo.Z == 7, "Homes: workspace.GooseSquare's Nest part before Config.Goose.Egg.Home", h1.Halo.X)
check(h1.Horns.X == 9 and h1.Horns.Z == 11, "Homes: its CartPos attribute before Config.Goose.Egg.Home", h1.Horns.X)
local ht1 = EggFx.HomeTarget()
check(ht1.X == 5 and ht1.Z == 7, "HomeTarget: the square's own nest", ht1 and ht1.X)
squareModel = { FindFirstChild = function() return nil end, GetAttribute = function() return nil end }
local h2 = EggFx.Homes()
check(h2.Halo.Z == -30 and h2.Horns.Z == 30, "Homes: a square without Nest / Cart = Config.Goose.Egg.Home")
-- 게임성 개발 2 10/12 (the skeleton doc): the egg ring's middle = the square's GooseSpot
check(EggFx.Center().X == 0 and EggFx.Center().Z == 0, "Center: a square without GooseSpot = Config.Goose.Egg.Center (or 0)")
local spotPart = { IsA = function(_, c) return c == "BasePart" end, Position = vec(6000, 200, 6000) }
squareModel = { FindFirstChild = function(_, n) if n == "GooseSpot" then return spotPart end return nil end,
	GetAttribute = function() return nil end }
check(EggFx.Center().X == 6000 and EggFx.Center().Y == 200, "Center: the square's GooseSpot part", EggFx.Center().X)
squareModel = { FindFirstChild = function() return nil end,
	GetAttribute = function(_, k) if k == "GooseSpotPos" then return vec(1, 2, 3) end return nil end }
check(EggFx.Center().Z == 3, "Center: its GooseSpotPos attribute", EggFx.Center().Z)
squareModel = nil
check(EggFx.Center().X == 0, "Center: no square = Config.Goose.Egg.Center (or 0)")

print("CHECKS " .. checks .. " FAILED " .. failed)
'''


def pure_block(src: str) -> str | None:
    a = src.find("----------------------------------------------------------------- pure helpers")
    b = src.find("----------------------------------------------------------------- world pieces")
    return src[a:b] if 0 <= a < b else None


def homes_block(src: str) -> str | None:
    """A23-141: Homes / HomeFor / HomeTarget / TickFor (between the Step and the one-off events), run with stubs."""
    a = src.find("-- the nest (Halo) and the cart (Horns) points")
    b = src.find("----------------------------------------------------------------- one-off events")
    return src[a:b] if 0 <= a < b else None


def run_pure(src: dict) -> tuple[int, int, list[str]]:
    block = pure_block(src["EGG"])
    homes = homes_block(src["EGG"])
    if block is None or homes is None:
        return 1, 1, ["CHECK_FAIL EggFx pure helpers block found"]
    code = HARNESS.replace("-- PURE --", block).replace("-- HOMES --", homes)
    with tempfile.TemporaryDirectory() as d:
        f = Path(d) / "egg_fx_offline.luau"
        f.write_text(code, encoding="utf-8")
        r = subprocess.run([str(BINARY), str(f)], capture_output=True, text=True, encoding="utf-8", errors="replace")
    lines = [ln for ln in r.stdout.splitlines() if ln.startswith("CHECK_")]
    m = re.search(r"CHECKS (\d+) FAILED (\d+)", r.stdout)
    if not m or r.returncode != 0:
        return len(lines) + 1, sum(ln.startswith("CHECK_FAIL") for ln in lines) + 1, lines + [
            "CHECK_FAIL the Luau run finished :: " + (r.stderr.strip()[-300:] or r.stdout.strip()[-300:])]
    return int(m[1]), int(m[2]), lines


def statics(src: dict) -> list[tuple[str, bool, str]]:
    egg, hud, audio, qt, mp, cfg = src["EGG"], src["HUD"], src["AUDIO"], src["QT"], src["MAP"], src["CONFIG"]
    order = re.search(r"local ORDER = \{([^}]*)\}", src["MAIN"])
    sounds = ("EggPlop", "EggPickup", "EggDeliverHalo", "EggDeliverHorns", "EggBoing", "CrownEgg", "GooseSnore")
    branch = hud.split("\t\tif eggMode then\n", 1)
    branch = branch[1].split("\n\t\t\treturn\n", 1)[0] if len(branch) == 2 else ""
    square = re.search(r"Config\.Goose\.Square = \{(.*?)\n\t\}", cfg, re.S)
    sq = square.group(1) if square else ""
    chip = hud.split("if eggMode and type(eggFx.Here) == \"function\" and not eggFx.Here() then", 1)
    chip = chip[1].split("\n\t\t\treturn\n", 1)[0] if len(chip) == 2 else ""
    look = re.search(r"Config\.GooseEggFx = \{(.*?)\n\}", cfg, re.S)
    text = re.search(r"Text = \{([^}]*)\}", look.group(1)) if look else None
    return [
        ("ClientMain loads EggFx (its fixed ORDER list)", bool(order) and '"EggFx"' in order.group(1), ""),
        ("EggFx: only in Config.Goose.Mode \"Eggs\"", 'Config.Goose.Mode == "Eggs"' in egg and "if not EggFx.On() then return end" in egg, ""),
        ("EggFx: the server egg part is hidden, a local copy is drawn", "part.LocalTransparencyModifier = 1" in egg
         and "workspace.Effects.GooseEggs" in egg and 'c.Name == "GooseEggs"' in egg, ""),
        ("EggFx: no PointLight / Highlight / Beam (design: no per-egg lights, no rays)",
         not re.search(r'Instance\.new\("(PointLight|Highlight|Beam|SpotLight|SurfaceLight)"\)', egg), ""),
        # A23-141: the one remote EggFx fires is GooseSquare's Join / Leave (looked up without waiting); nothing else
        ("EggFx: the only remote is the GooseSquare press (one FireServer, no InvokeServer, no remote created)",
         egg.count("FireServer") == 1 and "pcall(function() remote:FireServer(word) end)" in egg and "InvokeServer" not in egg
         and 'Instance.new("RemoteEvent")' not in egg and "Net.Get(" not in egg.replace('Net.Get("Fx")', ""), ""),
        ("EggFx: HomeTarget / Homes check EggFx.Here() themselves (two gates: the marker and the homes)",
         "function EggFx.HomeTarget()\n\tif not EggFx.Here() then return nil end\n" in egg
         and "function EggFx.Homes()\n\tif not EggFx.Here() then return nil end\n" in egg, ""),
        ("EggFx: the GooseSquare remote is found without waiting (FindFirstChild, never WaitForChild)",
         'folder:FindFirstChild(squareName("Remote", "GooseSquare"))' in egg and 'WaitForChild("GooseSquare"' not in egg
         and 'ReplicatedStorage:FindFirstChild("Remotes")' in egg, ""),
        ("EggFx: the screen fade = a full-screen black Frame in a ScreenGui with IgnoreGuiInset, In then Out, then off, one at a time, no text",
         "gui.IgnoreGuiInset = true" in egg and "f.Size = UDim2.fromScale(1, 1)" in egg and "f.BackgroundColor3 = Color3.new(0, 0, 0)" in egg
         and "{ BackgroundTransparency = 0 }" in egg and "{ BackgroundTransparency = 1 }" in egg
         and "\t\t\tgui.Enabled = false\n\t\t\tS.FadeTween = nil\n" in egg
         and "if S.FadeTween then S.FadeTween:Cancel() end" in egg and "if S.FadeId ~= id then return end" in egg
         and "num(fade.In, 0.25)" in egg and "num(fade.Out, 0.35)" in egg
         and not re.search(r'Instance\.new\("(TextLabel|TextButton|ImageLabel)"\)', egg.split("local function fadeFrame()", 1)[-1].split("function EggFx.Init", 1)[0]), ""),
        ("EggFx: the fade starts from the InGooseSquare signal, the state read at Start (no fade for where I already am)",
         "S.SquareIn = EggFx.Inside()" in egg and 'GetAttributeChangedSignal(squareName("Attr", "InGooseSquare"))' in egg
         and "pcall(EggFx.SquareChanged)" in egg, ""),
        ("EggFx: outside the Goose Square the egg screens are off (Step -> stepAway, no sounds, no pops, no Fx)",
         "if not EggFx.Here() then\n\t\tstepAway()\n\t\treturn\n\tend" in egg
         and "if not EggFx.Here() then return end -- no egg sound outside the Goose Square" in egg
         and "if not EggFx.Here() or (not anyDistance and not near(pos, num(lookCfg().SparkleRange, 60))) then return end" in egg
         and "if not EggFx.Here() or type(data) ~= \"table\" then return end" in egg
         and "EggFx.HomeFor(side)" in egg, ""),
        ("Config.Goose.Square: Remote / Attr / Block / Fade / Text exactly as the contract (A23-141)",
         bool(square) and 'Remote = "GooseSquare"' in sq and 'Attr = "InGooseSquare"' in sq and 'Block = "GooseJoinBlock"' in sq
         and "Fade = { In = 0.25, Out = 0.35 }" in sq and 'Join = "Join"' in sq and 'Leave = "Leave"' in sq
         and "PvP = \"You can't join during a fight.\"" in sq and 'Closed = "The goose is gone."' in sq
         and sq.count("You can't join right now.") == 3 and 'if type(Config.Goose) == "table" then\n\tConfig.Goose.Square = {' in cfg, ""),
        ("EventHUD: outside the square the chip shows only the goose time (+ Join), no egg bar; the bar's nil is handled",
         "SQ.Out = true" in chip and "setVisible(ui.Tug, false)" in chip and "eggFx.TickEnd(" in chip and "setVisible(ui.GooseChip, true)" in chip
         and "if not b then" in branch, ""),
        ("EventHUD: the Join / Leave button = UIKit.ArtButton Chip (code fallback), words from Config.Goose.Square.Text through UIKit.Tx, "
         "dimmed = Disabled (no text), press -> EggFx.SquarePress",
         'pcall(kit.ArtButton, "Chip", props, SQ.press, { CornerRadius = UDim.new(0.5, 0) })' in hud and "pcall(kit.Tx, t, key)" in hud
         and "Config.Goose.Square" in hud and "e.SquareButton(e.SquareCtx())" in hud and "pcall(e.SquarePress, SQ.Word)" in hud
         and 'btn:SetAttribute("Disabled", dim)' in hud and "local dim = want.Dim == true" in hud
         and 'local home = (want.Word == "Leave" and ui.Tug.Visible) and ui.Tug or ui.GooseChip' in hud
         and "elseif inside then\n\t\t\tsetVisible(ui.GooseChip, true)\n\t\t\tsetText(ui.GooseChipText, \"\")" in hud
         and "\tupdateGoose(now)\n\tSQ.update()\n" in hud and "SQ.build()\n\n\t-- kaiju chip" in hud
         and "V2.GooseIn = SQ.Out and 0 or" in hud, ""),
        ("최종 검수 10/12 (goose_square photos): the A23-68 rookie fold never hides the event strip while I am inside the Goose "
         "Square (its Leave and egg bar stay; outside, the fold still waits for the first Claim)",
         "\tlocal folded = V2.Fold() and not V2.InSquare()\n" in hud and "function V2.InSquare()" in hud
         and "local ok, inside = pcall(e.Inside)\n\treturn ok and inside == true" in hud, ""),
        ("A23-221 ⑥: the event strip (goose chip, [Join]) waits for the first story quest too (HUD.EventsWait, else RookieFold)",
         'local fn = type(hud.EventsWait) == "function" and hud.EventsWait or hud.RookieFold' in hud, ""),
        ("QuestTarget: the goose / nest / cart target only inside the Goose Square (else none), the square's own homes first",
         "if not inSquare then return nil end" in qt and "eggFx.HomeFor(myFaction())" in qt and "QuestTarget.Reg = registry" in qt, ""),
        ("WorldMap: the nest / cart landmarks and the goose marker only while EggFx.Here (EggFx.Homes), none drawn at build",
         "refreshEggLandmarks() -- A23-141: the nest / the cart while I am in the square" in mp
         and "e.Homes()" in mp and "e.Here() == true" in mp and "gsAttr(\"GooseActive\", false) == true and gooseHere then" in mp
         and 'landmark("Nest", GLYPH.Nest, COL.Nest, pos, TXT.Nest, 18)' in mp and "COL.Nest, homes.Halo" not in mp, ""),
        ("Audio: the Eggs mode outside the square has no 3-2-1 (TickFor nil must not fall back to the tug's hitters)",
         'elseif type(eggFx) == "table" and type(eggFx.On) == "function" and eggFx.On() then\n\t\t\ttickFor("Goose", false, 0, t)' in audio, ""),
        ("EggFx: a repeating error warns once per WarnGap s (게임성 검수 10/11), never a bare warn per frame",
         "if now - (S.Warned[msg] or -math.huge) < num(lookCfg().WarnGap, 10) then return end" in egg
         and "if not ok then warnThrottled(tostring(err)) end" in egg and egg.count("warn(") == 1, ""),
        ("EggFx: a removed ground egg waits GoneWait s for an EggReturn before a 'picked' pop",
         "task.delay(num(lookCfg().GoneWait, 0.25)" in egg and "if gone.Returned then return end" in egg
         and "gone.Returned = true" in egg, ""),
        ("최종 검수 10/11: an egg I picked without a preview (near me, my EggCarry rose within MineWindow) gets no "
         "'someone picked it' pop / sound - only my own pickup sound",
         "local reach = num(eggCfg().PickRadius, 4.5) + num(lookCfg().MineSlack, 1)" in egg
         and "if gone.Near and math.abs(S.MineAt - gone.At) <= num(lookCfg().MineWindow, 0.5) then return end" in egg
         and "S.MineAt = os.clock()" in egg, ""),
        # 최종 검수 10/12: an egg picked in passing (removed after I walked on) is still mine; a previewed pickup sets
        # no MineAt (someone else's egg beside me keeps its pop)
        ("최종 검수 10/12: 'near' also counts where I walked the last MoveWindow s (S.Trail)",
         "local near = root ~= nil and within(root.Position)" in egg and "for _, s in S.Trail do" in egg
         and "near = within(s.Pos)" in egg and "Near = near }" in egg, ""),
        ("최종 검수 10/12: MineAt only for a pickup without a preview; 개발 2 ⑤ 10/14: the pickup sound with the server's yes",
         re.search(r"if os\.clock\(\) - \(S\.PreviewAt or -math\.huge\) > 1 then\n(?:\t+--[^\n]*\n)*\t+S\.MineAt = os\.clock\(\)\n", egg)
         is not None and egg.count("S.MineAt = os.clock()") == 1
         and 'play("EggPickup", { Speed = num(steps[math.clamp(carry, 1, #steps)], 1) }, "Loot")' in egg
         and egg.count('play("EggPickup"') == 1, ""),
        ("EggFx: the pickup preview hides at once and shows again after PredictHold s",
         "S.Hidden[rec.Id] = now" in egg and "now - hidAt > num(lk.PredictHold, 0.6)" in egg, ""),
        ("EggFx: a preview the server turned down is not retried for RetryAfter s (no flicker)",
         "S.Denied[rec.Id] = now" in egg and "if not hidAt and not denied and rec.Id ~= nil" in egg
         and "Moved = walking" in egg, ""),
        ("EggFx: unanswered previews take their slots (no 4th egg in one frame)",
         "if rec.Id ~= nil and S.Hidden[rec.Id] then carry += slotsOf(rec.Kind) end" in egg
         and "carry += slotsOf(rec.Kind)\n\t\tend\n\tend\nend" in egg, ""),
        ("EggFx: '+N' only for my own delivery", "if data.UserId ~= LocalPlayer.UserId then return end" in egg, ""),
        ("EventHUD: the Eggs bar comes from EggFx.Bar, the line under it hidden, no explanation text",
         "eggFx.Bar(" in branch and "TugSub" not in hud and "SQ.DrawEggBar(b, " in branch
         and '"EggCoop"' in hud and "Hint" not in branch and "MyCount" not in branch, ""),
        ("EventHUD: the overtime clock gold with the approved crown", 'Art.image("Crown"' in hud and "b.Overtime and GOLD" in hud, ""),
        ("Audio: deliveries / tags (my side's sound, others within EggRange, stand-ins)",
         'kind == "EggDeliver" or kind == "EggTag"' in audio and "d > T.EggRange" in audio
         and '"EggDeliverHorns" or "EggDeliverHalo"' in audio and '"GoldPickup"' in audio, ""),
        ("Audio: the last 3-2-1 from EggFx.TickFor in Eggs mode (the pickers, the overtime end)",
         "picked, eggEnd = eggFx.TickFor(gs)" in audio
         and 'tickFor("Goose", gs:GetAttribute("GooseActive") == true and picked, num(eggEnd, 0), t)' in audio, ""),
        ("QuestTarget: carrying eggs -> my home, empty hands -> the goose (Eggs mode)",
         'if goose.Mode == "Eggs" then' in qt and 'num(LocalPlayer:GetAttribute("EggCarry"), 0) <= 0' in qt
         and "egg.Home[myFaction()]" in qt, ""),
        ("QuestMarker: while I carry eggs the marker points at my home (EggFx.HomeTarget), whatever row is pinned",
         "local ok, home = pcall(egg.HomeTarget)" in src["QM"] and 'Tag = "EggHome"' in src["QM"]
         and 'if num(LocalPlayer:GetAttribute("EggCarry"), 0) <= 0 then return nil end' in egg, ""),
        ("WorldMap: the nest (Halo home) and the egg cart (Horns home) in Eggs mode (A23-141: drawn while in the square)",
         'landmark("EggCart", GLYPH.Cart, COL.Cart, pos, TXT.Cart, 18)' in mp
         and 'landmark("Nest", GLYPH.Nest, COL.Nest, pos, TXT.Nest, 18)' in mp, ""),
        ("Config.GooseEggFx: kinds with sizes, a see-through egg I cannot pick, only the !/Zzz/+N marks",
         bool(look) and all(re.search(k + r" = \{ Size = [\d.]+", look.group(1)) for k in ("Gold", "Bouncy", "Big", "Crown"))
         and bool(re.search(r"NoPickAlpha = 0\.[3-8]", look.group(1))) and bool(text)
         and sorted(re.findall(r"(\w+) = ", text.group(1))) == ["Alert", "Nap", "Plus"], ""),
        ("Config.Audio.Sounds: the 7 egg sounds", all(re.search(r"\n\t\t" + s + r" = \{ File = \"" + s + '"', cfg) for s in sounds), ""),
        # 게임성 개발 2 10/12 (the skeleton doc): the goose's fallback spot, the ring dots and the wobble all centre on the
        # square's GooseSpot (EggFx.Center), never on the old plaza fountain's Config.Goose.Egg.Center directly
        ("A23-141: the goose spot, the ring and the wobble centre on EggFx.Center (the square's GooseSpot)",
         "\treturn EggFx.Center() + Vector3.new(0, 4, 0), g" in egg and egg.count("\tlocal center = EggFx.Center()\n") == 0
         and "typeof(cfg.Center) == \"Vector3\" and cfg.Center" not in egg, ""),
    ]


def run(src: dict):
    n, failed, lines = run_pure(src)
    st = statics(src)
    lines += [("CHECK_OK " if ok else "CHECK_FAIL ") + name + (f" :: {d}" if d else "") for name, ok, d in st]
    return n + len(st), failed + sum(0 if ok else 1 for _, ok, _ in st), lines


MUTATIONS = [
    ("EGG", "the arc upside down", "+ Vector3.new(0, 4 * peak * k * (1 - k), 0)", "- Vector3.new(0, 4 * peak * k * (1 - k), 0)"),
    ("EGG", "no peak cap", "local peak = math.clamp((to - from).Magnitude * num(arc[1], 0.35), num(arc[2], 1.5), num(arc[3], 6))",
     "local peak = (to - from).Magnitude * num(arc[1], 0.35)"),
    ("EGG", "picked while it flies", "if now < num(egg.LandAt, 0) then return false end", ""),
    ("EGG", "a big egg on top of others", "\t\tif carry > 0 then return false end\n", ""),
    ("EGG", "a 4th egg", "elseif carry + slots > max then", "elseif carry + slots > max + 1 then"),
    ("EGG", "the height ignored", "and math.abs(d.Y) <= num(cfg.PickHeight, 6)", ""),
    ("EGG", "picked while standing still", "me.Can ~= true or me.Moved == false then return false end", "me.Can ~= true then return false end"),
    ("EGG", "a turned-down preview retried at once", "if not hidAt and not denied and rec.Id ~= nil", "if not hidAt and rec.Id ~= nil"),
    ("EGG", "two previews in one frame overfill the slots", "\t\t\tcarry += slotsOf(rec.Kind)\n", ""),
    ("EGG", "the wobble the smaller", "return math.max(a, b)", "return math.min(a, b)"),
    ("EGG", "the overtime ignored", "if ot > now then return ot, true end", ""),
    ("EGG", "the fill from the Horn Legion", "out.Fill = (halo + horns) > 0 and halo / (halo + horns) or 0.5",
     "out.Fill = (halo + horns) > 0 and horns / (halo + horns) or 0.5"),
    ("EGG", "fractions on the bar", "local halo = math.max(0, math.floor(num(a.Rescue, 0) + 0.5))", "local halo = math.max(0, num(a.Rescue, 0))"),
    ("EGG", "a point light on the crown egg", "local glow\n", "local glow\n\tInstance.new(\"PointLight\").Parent = v\n"),
    ("EGG", "the server part left showing", "part.LocalTransparencyModifier = 1", "part.LocalTransparencyModifier = 0"),
    ("EGG", "a frame error warns every frame", "if not ok then warnThrottled(tostring(err)) end",
     'if not ok then warn("[EggFx] " .. tostring(err)) end'),
    ("EGG", "a 'picked' pop without waiting for a return", "if gone.Returned then return end", ""),
    ("EGG", "an egg picked in passing pops as someone else's (only my spot now counts)", "\t\t\tnear = within(s.Pos)\n", ""),
    ("EGG", "a previewed pickup hides others' pops too (MineAt for every pickup)",
     "\t\tif os.clock() - (S.PreviewAt or -math.huge) > 1 then\n",
     "\t\tS.MineAt = os.clock()\n\t\tif os.clock() - (S.PreviewAt or -math.huge) > 1 then\n"),
    ("EGG", "my own pickup also pops as someone else's (the sound twice)",
     "if gone.Near and math.abs(S.MineAt - gone.At) <= num(lookCfg().MineWindow, 0.5) then return end -- mine", ""),
    ("EGG", "'+N' for everyone's delivery", "if data.UserId ~= LocalPlayer.UserId then return end", ""),
    ("HUD", "the explanation line under the bar again", "\t\tif eggMode then\n",
     "\t\tif eggMode then\n\t\t\tsetVisible(ui.TugSub, true)\n"),
    ("AUDIO", "the 3-2-1 for the goose hitters in Eggs mode",
     'tickFor("Goose", gs:GetAttribute("GooseActive") == true and picked, num(eggEnd, 0), t)',
     'tickFor("Goose", gs:GetAttribute("GooseActive") == true and S.GooseHit, num(eggEnd, 0), t)'),
    ("AUDIO", "everyone hears every delivery", "if not mine and (d == nil or d > T.EggRange) then return out end", ""),
    ("QT", "carrying eggs points at the goose", 'num(LocalPlayer:GetAttribute("EggCarry"), 0) <= 0', 'num(LocalPlayer:GetAttribute("EggCarry"), 0) >= 0'),
    ("MAP", "no egg cart on the map", 'landmark("EggCart", GLYPH.Cart, COL.Cart, pos, TXT.Cart, 18)', "local _ = nil"),
    ("QM", "the marker ignores my eggs", "local ok, home = pcall(egg.HomeTarget)", "local ok, home = false, nil"),
    ("EGG", "the marker points home with empty hands", 'if num(LocalPlayer:GetAttribute("EggCarry"), 0) <= 0 then return nil end', ""),
    ("MAIN", "EggFx never loaded", '"FountainFx", "EggFx", ', '"FountainFx", '),
    # A23-141 Goose Square
    ("EGG", "Here() ignores InGooseSquare", "return EggFx.On() and EggFx.Inside()", "return EggFx.On()"),
    ("EGG", "Here() ignores the Eggs mode", "return EggFx.On() and EggFx.Inside()", "return EggFx.Inside()"),
    ("EGG", "the button shows without an open event", "\tif ctx.Active ~= true or not EggFx.On() then return nil end\n",
     "\tif not EggFx.On() then return nil end\n"),
    ("EGG", "the button shows outside the Eggs mode", "\tif ctx.Active ~= true or not EggFx.On() then return nil end\n",
     "\tif ctx.Active ~= true then return nil end\n"),
    ("EGG", "a blocked Join stays bright", "Dim = noRemote or (type(ctx.Block) == \"string\" and ctx.Block ~= \"\") }", "Dim = noRemote }"),
    ("EGG", "Leave dimmed by a block", "return { Word = \"Leave\", Dim = noRemote }",
     "return { Word = \"Leave\", Dim = noRemote or (type(ctx.Block) == \"string\" and ctx.Block ~= \"\") }"),
    ("EGG", "no remote does not dim", "local noRemote = ctx.HasRemote ~= true", "local noRemote = false"),
    ("EGG", "a dimmed press still fires", "if not b or b.Dim or b.Word ~= word then return false end", "if not b or b.Word ~= word then return false end"),
    ("EGG", "a press of the other word fires", "if not b or b.Dim or b.Word ~= word then return false end", "if not b or b.Dim then return false end"),
    ("EGG", "no rate gap between presses", "if now - (S.SquareAt or -math.huge) < gap then return false end", ""),
    ("EGG", "a press fires twice", "pcall(function() remote:FireServer(word) end)", "pcall(function() remote:FireServer(word) remote:FireServer(word) end)"),
    ("EGG", "the remote is waited for", "folder:FindFirstChild(squareName(\"Remote\", \"GooseSquare\"))", "folder:WaitForChild(squareName(\"Remote\", \"GooseSquare\"))"),
    ("EGG", "the fade repeats for the same value", "if (S.SquareIn == true) == inside then return false end", ""),
    ("EGG", "no fade on a change", "pcall(EggFx.Fade)", "local _ = nil"),
    ("EGG", "the egg bar outside the square", "function EggFx.Bar(a, now)\n\tif not EggFx.Here() then return nil end\n", "function EggFx.Bar(a, now)\n"),
    ("EGG", "the 3-2-1 outside the square", "if not EggFx.Here() or not gs then return nil end", "if not gs then return nil end"),
    ("EGG", "the home marker outside the square", "function EggFx.HomeTarget()\n\tif not EggFx.Here() then return nil end\n", "function EggFx.HomeTarget()\n"),
    ("EGG", "homes outside the square", "function EggFx.Homes()\n\tif not EggFx.Here() then return nil end\n", "function EggFx.Homes()\n"),
    ("EGG", "the square's own nest / cart ignored",
     "return { Halo = read(\"Nest\", \"NestPos\") or cfgHome.Halo, Horns = read(\"Cart\", \"CartPos\") or cfgHome.Horns }",
     "return { Halo = cfgHome.Halo, Horns = cfgHome.Horns }"),
    ("EGG", "the egg play runs outside the square", "if not EggFx.Here() then\n\t\tstepAway()\n\t\treturn\n\tend", ""),
    ("EGG", "egg sounds outside the square", "\tif not EggFx.Here() then return end -- no egg sound outside the Goose Square\n", ""),
    ("EGG", "egg pops outside the square", "if not EggFx.Here() or (not anyDistance and not near(pos, num(lookCfg().SparkleRange, 60))) then return end",
     "if not anyDistance and not near(pos, num(lookCfg().SparkleRange, 60)) then return end"),
    ("EGG", "egg Fx outside the square", "if not EggFx.Here() or type(data) ~= \"table\" then return end", "if type(data) ~= \"table\" then return end"),
    ("EGG", "the fade never ends", "\t\t\tgui.Enabled = false\n\t\t\tS.FadeTween = nil\n", ""),
    ("EGG", "a new fade does not restart the old one", "if S.FadeTween then S.FadeTween:Cancel() end", ""),
    ("CONFIG", "the remote renamed", "Remote = \"GooseSquare\",", "Remote = \"Goose\","),
    ("CONFIG", "the fade is slower", "Fade = { In = 0.25, Out = 0.35 },", "Fade = { In = 1, Out = 1 },"),
    ("HUD", "the egg bar outside the square", "if eggMode and type(eggFx.Here) == \"function\" and not eggFx.Here() then", "if false then"),
    ("HUD", "Join always bright", "local dim = want.Dim == true", "local dim = false"),
    ("HUD", "Leave on the chip", "local home = (want.Word == \"Leave\" and ui.Tug.Visible) and ui.Tug or ui.GooseChip", "local home = ui.GooseChip"),
    ("HUD", "Leave on a hidden bar after the round", "local home = (want.Word == \"Leave\" and ui.Tug.Visible) and ui.Tug or ui.GooseChip",
     "local home = want.Word == \"Leave\" and ui.Tug or ui.GooseChip"),
    ("HUD", "the chip hides after the round while I am inside", "\t\telseif inside then\n\t\t\tsetVisible(ui.GooseChip, true)\n", "\t\telseif false then\n\t\t\tsetVisible(ui.GooseChip, true)\n"),
    ("EGG", "Leave hidden after the round", "\tif ctx.Inside == true then return { Word = \"Leave\", Dim = noRemote } end\n\tif ctx.Active ~= true or not EggFx.On() then return nil end\n",
     "\tif ctx.Active ~= true or not EggFx.On() then return nil end\n\tif ctx.Inside == true then return { Word = \"Leave\", Dim = noRemote } end\n"),
    ("HUD", "no button update", "\tupdateGoose(now)\n\tSQ.update()\n", "\tupdateGoose(now)\n"),
    ("HUD", "a rookie inside the square loses Leave (folded)", "\tlocal folded = V2.Fold() and not V2.InSquare()\n", "\tlocal folded = V2.Fold()\n"),
    ("HUD", "the square check never true", "\treturn ok and inside == true\nend", "\treturn false\nend"),
    ("QT", "the goose target in the real plaza", "\t\tif not inSquare then return nil end\n", ""),
    ("MAP", "the goose marker in the real plaza", "if gsAttr(\"GooseActive\", false) == true and gooseHere then",
     "if gsAttr(\"GooseActive\", false) == true then"),
    ("EGG", "the egg ring stays on the old plaza (no GooseSpot)", "local spot = sq:FindFirstChild(\"GooseSpot\", true)",
     "local spot = sq:FindFirstChild(\"Center\", true)"),
    ("EGG", "the ring / goose / wobble ignore the square's middle", "\treturn EggFx.Center() + Vector3.new(0, 4, 0), g",
     "\treturn Vector3.new(0, 4, 0), g"),
    ("MAP", "the nest never leaves the map", "\trefreshEggLandmarks() -- A23-141: the nest / the cart while I am in the square\n", ""),
    ("AUDIO", "the tug's 3-2-1 outside the square",
     "elseif type(eggFx) == \"table\" and type(eggFx.On) == \"function\" and eggFx.On() then\n\t\t\ttickFor(\"Goose\", false, 0, t)",
     "elseif false then\n\t\t\ttickFor(\"Goose\", false, 0, t)"),
]


def compile_check() -> tuple[int, int, list[str]]:
    """A23-141: every file this test reads (except ClientMain / QuestMarker, unchanged) still compiles (luau-compile --null)."""
    compiler = BINARY.with_name("luau-compile" + BINARY.suffix)
    if not compiler.exists():
        return 1, 1, ["CHECK_FAIL luau-compile found next to the Luau CLI"]
    lines, bad = [], 0
    for key in ("EGG", "HUD", "AUDIO", "QT", "MAP", "CONFIG"):
        r = subprocess.run([str(compiler), "--null", str(FILES[key])], capture_output=True, text=True, encoding="utf-8",
                           errors="replace")
        ok = r.returncode == 0
        bad += 0 if ok else 1
        lines.append(("CHECK_OK " if ok else "CHECK_FAIL ") + f"compiles: {FILES[key].name}" + ("" if ok else " :: " + (r.stderr or r.stdout).strip()[:300]))
    return len(lines), bad, lines


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    n, failed, lines = run(src)
    cn, cbad, clines = compile_check()
    n, failed, lines = n + cn, failed + cbad, lines + clines
    print("\n".join(lines))
    muts = []
    for key, name, old, new in MUTATIONS:
        hits = src[key].count(old)
        caught = False
        if hits == 1:
            m = dict(src)
            m[key] = src[key].replace(old, new)
            caught = run(m)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    status = "passed" if failed == 0 and n > 0 and all(m["caught"] for m in muts) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": n, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {n}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
