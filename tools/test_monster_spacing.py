"""A23-74 (user 2026-10-07 "그리고 점점 합쳐지겠다 야"): monsters keep a natural distance, offline.

No monster part collides (TECH_SPEC: CanCollide = false; players walk through monsters on purpose), and every chaser used
to MoveTo the player's exact position, so a Shard Slime, a King Slime and a Pumpkin Slime ended up inside each other
and the player. MonsterService now spaces them (SEP): a chaser walks to its own slot on a ring around its target
(r + 1 + 1, at most AttackRange - 0.5; one player's chasers are spread so neighbours stand rA + rB apart, the farthest
wait on an outer ring when the inner one is full), overlapping monsters (closer than (rA + rB) x 0.9) or a monster inside
a player body slide apart at most 3 studs/s over the next AI tick (the smaller one moves more, a boss never; never into
water, past the zone inset or through a wall), neighbours come from an 8-stud grid (not every pair), and new monsters
spawn at least rA + rB + 1.5 from living ones (else the first crowded point, so density never starves).

Cuts the SEP table and functions, insideZone and findInfo from the CURRENT MonsterService (with the CURRENT Config) and
the real pickSpawnPoint (the test_tutorial_spawn cut), runs them on tools/fixtures/dev2_kit.luau doubles with
tools/fixtures/monster_spacing_offline.luau and the installed official Luau CLI, and reads the AI wiring (aiStep,
personalStep, aiTick, Heartbeat, spawnMonster) as source text. No Studio, network, DataStore or Roblox API calls;
mutations run on in-memory copies of the sources only.

Usage: py tools/test_monster_spacing.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-07/offline_monster_spacing_2026-10-07.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, between, function_block, read, run
from test_tutorial_spawn import bindings as spawn_bindings

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "MONSTER_SOURCE": SSS / "MonsterService.luau",
}
M = "MONSTER_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    mon = sources[M]
    consts = []
    for pattern in (r"^local PERSONAL_FOLLOW_RADIUS = .*$", r"^local ZONE_MOVE_INSET = .*$"):
        found = re.search(pattern, mon, re.M)
        if not found:
            raise ValueError(f"MonsterService constant {pattern!r} missing; update the test extractor.")
        consts.append(found.group(0))
    return {
        "CONFIG_SOURCE": sources["CONFIG_SOURCE"],
        "MONSTER_SOURCE": mon,
        "SPACING_EXTRACT": (
            "local Config, Util, H = ...\n"
            "local MC = Config.Monsters\n"
            "local records, workspace = H.records, H.workspace\n"
            "local groundPoint, getShoveParams = H.groundPoint, H.getShoveParams\n"
            + "\n".join(consts) + "\n"
            + between(mon, "local SEP = {\n", "\n}\n") + "\n}\n"
            + function_block(mon, "local function insideZone(")
            + function_block(mon, "local function findInfo(")
            + function_block(mon, "function SEP.RadiusOf(")
            + function_block(mon, "function SEP.Clear(")
            + between(mon, "------------------------------------------------------------------ A23-74 spacing",
                      "local function personalStep(")
            + "return SEP\n"),
        "SPAWN_EXTRACT": spawn_bindings(sources)["SPAWN_EXTRACT"],
    }


MUTATIONS = [
    # contract numbers
    ("overlap factor 0.5", M, "\tOverlap = 0.9,\n", "\tOverlap = 0.5,\n"),
    ("slides 10x faster", M, "\tSpeed = 3,\n", "\tSpeed = 30,\n"),
    ("no spawn gap", M, "\tSpawnGap = 1.5,\n", "\tSpawnGap = 0,\n"),
    ("humanoid radius = slime's", M, "Radius = { Slime = 1.5, Humanoid = 1.25 },", "Radius = { Slime = 1.5, Humanoid = 1.5 },"),
    ("radius ignores Scale", M, "return (SEP.Radius[def.Shape] or SEP.Radius.Humanoid) * (tonumber(def.Scale) or 1)",
     "return (SEP.Radius[def.Shape] or SEP.Radius.Humanoid)"),
    # ring
    ("ring ignores the body", M, "return math.min(MC.AttackRange - SEP.RingInside, r + SEP.PlayerRadius + SEP.RingGap)",
     "return math.min(MC.AttackRange - SEP.RingInside, SEP.PlayerRadius + SEP.RingGap)"),
    ("ring not kept in reach", M, "return math.min(MC.AttackRange - SEP.RingInside, r + SEP.PlayerRadius + SEP.RingGap)",
     "return math.max(MC.AttackRange - SEP.RingInside, r + SEP.PlayerRadius + SEP.RingGap)"),
    ("goal = the player's position", M,
     "local x, z = p.X + math.cos(angle) * ring, p.Z + math.sin(angle) * ring", "local x, z = p.X, p.Z"),
    ("goal ignores its slot", M, "if slot and slot.Player == info.Player then", "if false then"),
    ("goal walks into water", M, "\tif noHit then return Vector3.new(x, p.Y, z) end\n\treturn p\nend",
     "\tdo return Vector3.new(x, p.Y, z) end\n\treturn p\nend"),
    # spread
    ("slots never spread", M, "\t\t\tif top.Sum / top.N - (prev.Sum / prev.N + line[prev.Last].Off) >= gap then break end",
     "\t\t\tif true then break end"),
    ("one pass only (seam left tight)", M, "\tfor _ = 1, n do\n\t\tlocal cut, most = n, -math.huge",
     "\tfor _ = 1, 1 do\n\t\tlocal cut, most = n, -math.huge"),
    ("cut at the first pair, not the widest", M, "if room > most then cut, most = i, room end", "if false then cut, most = i, room end"),
    ("gap ignores body size", M, "return 2 * math.asin(math.min(1, (a.Rad + b.Rad) / math.max(0.01, a.R + b.R)))",
     "return 2 * math.asin(math.min(1, 2 / math.max(0.01, a.R + b.R)))"),
    ("no outer ring", M, "while #inner > 1 and SEP.Need(inner) > 2 * math.pi do", "while false do"),
    ("outer ring not moved out", M, "\t\te.R += 2 * e.Rad + SEP.RingGap\n", ""),
    ("the closest do not keep the ring", M, "\t\tif a.D ~= b.D then return a.D < b.D end\n\t\treturn a.Id < b.Id\n\tend)\n\twhile",
     "\t\tif a.D ~= b.D then return a.D > b.D end\n\t\treturn a.Id < b.Id\n\tend)\n\twhile"),
    ("far personal monsters chase", M,
     "\t\tif rec.Owner ~= nil and d > PERSONAL_FOLLOW_RADIUS then continue end -- a personal monster too far: it stands\n", ""),
    ("returning monsters get slots", M, "local target = rec.Owner or (not rec._returning and rec._target or nil)",
     "local target = rec.Owner or rec._target"),
    ("dying monsters in the grid", M, "\t\tif root and root.Parent and not root.Anchored then\n\t\t\tlocal pos = root.Position\n\t\t\trec._sepPos = pos",
     "\t\tif root and root.Parent then\n\t\t\tlocal pos = root.Position\n\t\t\trec._sepPos = pos"),
    # slide apart
    ("equal shares (big ones move as much)", M, "local wa = fa and 0 or (fb and 1 or rb / (ra + rb))",
     "local wa = fa and 0 or (fb and 1 or 0.5)"),
    ("a boss slides", M, "local fa, fb = SEP.Fixed(a), SEP.Fixed(b)", "local fa, fb = false, false"),
    ("players do not push", M, "\tfor _, info in plist do\n\t\tlocal p = info.Pos\n\t\tlocal cx, cz",
     "\tfor _, info in {} do\n\t\tlocal p = info.Pos\n\t\tlocal cx, cz"),
    ("players push a boss", M, "if d < need and math.abs(pr.Y - p.Y) < 8 and not SEP.Fixed(rec) then",
     "if d < need and math.abs(pr.Y - p.Y) < 8 then"),
    ("pairs counted twice", M, "if b.Id > a.Id then SEP.Pair(a, b, push) end", "if b.Id ~= a.Id then SEP.Pair(a, b, push) end"),
    ("own cell only", M, "\tfor _, a in SEP.Live do\n\t\tlocal pa = a._sepPos\n\t\tlocal cx, cz = math.floor(pa.X / cellSize), math.floor(pa.Z / cellSize)\n\t\tfor ox = -1, 1 do\n\t\t\tfor oz = -1, 1 do",
     "\tfor _, a in SEP.Live do\n\t\tlocal pa = a._sepPos\n\t\tlocal cx, cz = math.floor(pa.X / cellSize), math.floor(pa.Z / cellSize)\n\t\tfor ox = 0, 0 do\n\t\t\tfor oz = 0, 0 do"),
    ("same spot never separates", M, "\t\tdx, dz, o = math.cos(ang), math.sin(ang), need\n", "\t\tdx, dz, o = 0, 0, need\n"),
    ("no speed cap", M, "local k = math.min(1, maxStep / m)", "local k = 1"),
    ("jitter on tiny overlaps", M, "if m >= SEP.MinPush and rec.Alive", "if m > 0 and rec.Alive"),
    ("slides teleported monsters", M, "if Util.FlatDistance(pos, rec._sepPos) <= 1 then -- not teleported home this tick",
     "if true then"),
    ("no half step", M, "for _, part in { 1, 0.5 } do", "for _, part in { 1 } do"),
    ("slides into water", M, "\tif not g and not noHit then return false end\n\tlocal m = delta.Magnitude", "\tlocal m = delta.Magnitude"),
    ("slides past the zone inset", M,
     "if here ~= rec.ZoneId or (zone and not insideZone(zone, dest, ZONE_MOVE_INSET)) then return false end",
     "if here ~= rec.ZoneId then return false end"),
    ("slides through walls", M, "return workspace:Raycast(pos, delta * ((m + 0.5) / m), getShoveParams()) == nil",
     "return true"),
    ("snaps instead of sliding", M, "local f = math.min(1 - p.Done, dt / p.Time)", "local f = 1 - p.Done"),
    ("dead monsters keep sliding", M, "\t\tif not rec.Alive or not root or not root.Parent or root.Anchored then\n\t\t\tSEP.Push[rec] = nil",
     "\t\tif not root or not root.Parent then\n\t\t\tSEP.Push[rec] = nil"),
    # spawn
    ("spawn on top of monsters", M, "\t\t\tif SEP.Clear(g, radius) then return g end\n", "\t\t\tdo return g end\n"),
    ("crowded spawns lost", M, "\tif crowded then return crowded end -- A23-74", "\tif false then return crowded end -- A23-74"),
    ("spawn ignores the other's size", M, "radius + (rec._radius or SEP.Radius.Slime) + SEP.SpawnGap", "radius + SEP.SpawnGap"),
    ("dead monsters block spawns", M, "local root = rec.Alive and rec.Root or nil\n\t\tif root and root.Parent\n",
     "local root = rec.Root\n\t\tif root and root.Parent\n"),
    # wiring
    ("aiStep chases the player's position", M, "local goal = clampToZone(zone, SEP.Goal(rec, best))",
     "local goal = clampToZone(zone, best.Pos)"),
    ("waiting monsters do not face the player", M,
     "\t\t\tif Util.FlatDistance(pos, goal) <= 1 then\n\t\t\t\tFACE.Active[rec] = { Target = best.Player, Until = now + FACE.Keep }\n\t\t\tend\n",
     ""),
    ("personal monsters walk into their owner", M, "rec.Humanoid:MoveTo(SEP.Goal(rec, info))", "rec.Humanoid:MoveTo(info.Pos)"),
    ("no Begin", M, "local okSep, errSep = pcall(SEP.Begin, list, plist)", "local okSep, errSep = true, nil"),
    ("no Resolve", M, "okSep, errSep = pcall(SEP.Resolve, plist)", "okSep, errSep = true, nil"),
    ("no Heartbeat slides", M, "local okSep, errSep = pcall(SEP.Step, dt) -- A23-74", "local okSep, errSep = true, nil -- A23-74"),
    ("records without a radius", M, "_radius = SEP.RadiusOf(def), -- A23-74", "_radius = nil, -- A23-74"),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    mon = read(SSS / "MonsterService.luau")
    check(mon.count("local SEP = {\n") == 1, "one SEP table")
    top_locals = len(re.findall(r"^local ", mon, re.M))
    check(top_locals < 190, f"MonsterService top-level locals stay under the 200 limit ({top_locals})")
    check("local x <const>" not in mon and not re.search(r"\b(wait|spawn|delay)\(", re.sub(r"task\.\w+\(", "", mon)),
          "Luau rules: no <const>, task.* only")
    tick = function_block(mon, "local function aiTick(")
    check("pcall(SEP.Begin, list, plist)" in tick and "pcall(SEP.Resolve, plist)" in tick,
          "aiTick wraps the spacing passes in pcall")
    check(mon.count("A23-74") >= 8, "the spacing code cites A23-74 (user 2026-10-07)")
    return count, failures


SUITE = Suite(
    mark="MONSTER_SPACING",
    fixture=ROOT / "tools/fixtures/monster_spacing_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-07/offline_monster_spacing_2026-10-07.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-74 (user 2026-10-07 \"점점 합쳐지겠다\"): body radius = 1.5 x Scale (Slime shape) / 1.25 x Scale "
             "(Humanoid); a chaser's goal is its slot on a ring r + 1 + 1 (<= AttackRange - 0.5) around its target, "
             "slots of one player's chasers spread (order kept, least movement) so ring neighbours stand rA + rB apart, "
             "the farthest move to an outer ring (+ 2r + 1, outside reach) when the inner one is full; a slot on water "
             "falls back to the player's position; monsters closer than (rA + rB) x 0.9 (or within (r + 1) x 0.9 of a "
             "player) slide apart at most 3 studs/s over one AI tick, the smaller one moving more, a boss never, never "
             "into water / past the zone move inset / through a wall (half step tried); overlaps under 0.05 are "
             "ignored; neighbours come from an 8-stud grid; a new monster spawns at least rA + rB + 1.5 from every "
             "living one, else the first crowded ground point. Monster parts stay CanCollide = false.",
    limitations="Roots, the ground ray, walls, Random and the player list are doubles; the chase simulation uses a "
                "stand-in for aiStep's walk (straight line at Def.Speed, stand in AttackRange) with the real SEP passes. "
                "Humanoid MoveTo, replication smoothness of the server slides and the Tripo mesh footprints are only "
                "checkable in Studio Play (game dev 1). SEP.Need sorting ties by id (like Spread) is asserted but has no "
                "mutation: Luau's table.sort happens to order the test ties the same way with an angle-only comparator.",
)

if __name__ == "__main__":
    run(SUITE)
