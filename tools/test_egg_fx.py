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

-- PURE --

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

print("CHECKS " .. checks .. " FAILED " .. failed)
'''


def pure_block(src: str) -> str | None:
    a = src.find("----------------------------------------------------------------- pure helpers")
    b = src.find("----------------------------------------------------------------- world pieces")
    return src[a:b] if 0 <= a < b else None


def run_pure(src: dict) -> tuple[int, int, list[str]]:
    block = pure_block(src["EGG"])
    if block is None:
        return 1, 1, ["CHECK_FAIL EggFx pure helpers block found"]
    code = HARNESS.replace("-- PURE --", block)
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
    branch = hud.split("if type(eggFx) == \"table\" and type(eggFx.On) == \"function\" and eggFx.On() then", 1)
    branch = branch[1].split("\t\t\treturn\n", 1)[0] if len(branch) == 2 else ""
    look = re.search(r"Config\.GooseEggFx = \{(.*?)\n\}", cfg, re.S)
    text = re.search(r"Text = \{([^}]*)\}", look.group(1)) if look else None
    return [
        ("ClientMain loads EggFx (its fixed ORDER list)", bool(order) and '"EggFx"' in order.group(1), ""),
        ("EggFx: only in Config.Goose.Mode \"Eggs\"", 'Config.Goose.Mode == "Eggs"' in egg and "if not EggFx.On() then return end" in egg, ""),
        ("EggFx: the server egg part is hidden, a local copy is drawn", "part.LocalTransparencyModifier = 1" in egg
         and "workspace.Effects.GooseEggs" in egg and 'c.Name == "GooseEggs"' in egg, ""),
        ("EggFx: no PointLight / Highlight / Beam (design: no per-egg lights, no rays)",
         not re.search(r'Instance\.new\("(PointLight|Highlight|Beam|SpotLight|SurfaceLight)"\)', egg), ""),
        ("EggFx: no remote of its own (no FireServer / InvokeServer)", "FireServer" not in egg and "InvokeServer" not in egg, ""),
        ("EggFx: a removed ground egg waits GoneWait s for an EggReturn before a 'picked' pop",
         "task.delay(num(lookCfg().GoneWait, 0.25)" in egg and "if gone.Returned then return end" in egg
         and "gone.Returned = true" in egg, ""),
        ("EggFx: the pickup preview hides at once and shows again after PredictHold s",
         "S.Hidden[rec.Id] = now" in egg and "now - hidAt > num(lk.PredictHold, 0.6)" in egg, ""),
        ("EggFx: a preview the server turned down is not retried for RetryAfter s (no flicker)",
         "S.Denied[rec.Id] = now" in egg and "if not hidAt and not denied and rec.Id ~= nil" in egg
         and "Moved = walking" in egg, ""),
        ("EggFx: unanswered previews take their slots (no 4th egg in one frame)",
         "if rec.Id ~= nil and S.Hidden[rec.Id] then carry += slotsOf(rec.Kind) end" in egg
         and "S.PreviewAt = os.clock()\n\t\t\tcarry += slotsOf(rec.Kind)" in egg, ""),
        ("EggFx: '+N' only for my own delivery", "if data.UserId ~= LocalPlayer.UserId then return end" in egg, ""),
        ("EventHUD: the Eggs bar comes from EggFx.Bar, the line under it hidden, no explanation text",
         "eggFx.Bar(" in branch and "setVisible(ui.TugSub, false)" in branch and "TXT.EggCoop" in branch
         and "Hint" not in branch and "MyCount" not in branch, ""),
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
        ("WorldMap: the nest (Halo home) and the egg cart (Horns home) in Eggs mode",
         'landmark("EggCart", GLYPH.Cart, COL.Cart, homes.Horns, TXT.Cart, 18)' in mp
         and 'landmark("Nest", GLYPH.Nest, COL.Nest, homes.Halo, TXT.Nest, 18)' in mp, ""),
        ("Config.GooseEggFx: kinds with sizes, a see-through egg I cannot pick, only the !/Zzz/+N marks",
         bool(look) and all(re.search(k + r" = \{ Size = [\d.]+", look.group(1)) for k in ("Gold", "Bouncy", "Big", "Crown"))
         and bool(re.search(r"NoPickAlpha = 0\.[3-8]", look.group(1))) and bool(text)
         and sorted(re.findall(r"(\w+) = ", text.group(1))) == ["Alert", "Nap", "Plus"], ""),
        ("Config.Audio.Sounds: the 7 egg sounds", all(re.search(r"\n\t\t" + s + r" = \{ File = \"" + s + '"', cfg) for s in sounds), ""),
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
    ("EGG", "a 'picked' pop without waiting for a return", "if gone.Returned then return end", ""),
    ("EGG", "'+N' for everyone's delivery", "if data.UserId ~= LocalPlayer.UserId then return end", ""),
    ("HUD", "the explanation line under the bar again", "if type(eggFx) == \"table\" and type(eggFx.On) == \"function\" and eggFx.On() then\n\t\t\tsetVisible(ui.TugSub, false)",
     "if type(eggFx) == \"table\" and type(eggFx.On) == \"function\" and eggFx.On() then\n\t\t\tsetVisible(ui.TugSub, true)"),
    ("AUDIO", "the 3-2-1 for the goose hitters in Eggs mode",
     'tickFor("Goose", gs:GetAttribute("GooseActive") == true and picked, num(eggEnd, 0), t)',
     'tickFor("Goose", gs:GetAttribute("GooseActive") == true and S.GooseHit, num(eggEnd, 0), t)'),
    ("AUDIO", "everyone hears every delivery", "if not mine and (d == nil or d > T.EggRange) then return out end", ""),
    ("QT", "carrying eggs points at the goose", 'num(LocalPlayer:GetAttribute("EggCarry"), 0) <= 0', 'num(LocalPlayer:GetAttribute("EggCarry"), 0) >= 0'),
    ("MAP", "no egg cart on the map", 'landmark("EggCart", GLYPH.Cart, COL.Cart, homes.Horns, TXT.Cart, 18)', "local _ = nil"),
    ("QM", "the marker ignores my eggs", "local ok, home = pcall(egg.HomeTarget)", "local ok, home = false, nil"),
    ("EGG", "the marker points home with empty hands", 'if num(LocalPlayer:GetAttribute("EggCarry"), 0) <= 0 then return nil end', ""),
    ("MAIN", "EggFx never loaded", '"FountainFx", "EggFx", ', '"FountainFx", '),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    n, failed, lines = run(src)
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
