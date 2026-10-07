"""A23-74 (user 2026-10-07 "그리고 점점 합쳐지겠다 야"): monsters keep a natural distance, offline.

No monster part collides (TECH_SPEC: CanCollide = false; players walk through monsters on purpose), and every chaser used
to MoveTo the player's exact position, so a Shard Slime, a King Slime and a Pumpkin Slime ended up inside each other
and the player. MonsterService now spaces them (SEP): a chaser walks to its own slot on a ring around its target
(r + 1 + 1, at most AttackRange - 0.5; one player's chasers are spread so neighbours stand rA + rB apart; a full ring
moves out to AttackRange - 0.5 so more can attack, the rest wait on further rings outside reach, each just outside the
bodies of the ring before; the ring is centred 0.25 s ahead of a walking player, at most 4 studs), in reach it stands
for its swing and steps on to its slot between swings (AutoRotate off while in reach: FACE turns it), and after every
AI tick the end points of the coming walks (MoveTo point at WalkSpeed) are pushed apart in up to 3 rounds where two
bodies would overlap (rA + rB) or a body would be inside a player (where the player will be): each push is played as a
slide over the next tick at most 8 studs/s (the smaller one moves more, a boss never; never into water, past the zone
inset or through a wall, half step tried; a walking monster's MoveTo point moves along). Neighbours come from an 8-stud
grid (not every pair). New monsters, bosses from SpawnEvent too, spawn at least rA + rB + 1.5 from living ones (else the
first crowded point: the slides clear it).

Review 2026-10-07 (fix/a2374-separation2): a player walking at 3 / 5 / 8 studs/s with 4 Shard Slimes + 2 King Slimes
used to keep chasers overlapping 1-3 studs behind them; the probe now asserts a mean deepest overlap per AI tick under
0.3 studs (full bodies, monster pairs and the player body), 30 slimes on one player settle without overlap (10 in
reach), and a boss spawned on a monster keeps the clearance.

Cuts the SEP table and functions, insideZone and findInfo from the CURRENT MonsterService (with the CURRENT Config), the
real pickSpawnPoint (the test_tutorial_spawn cut) and the real MonsterService.SpawnEvent, runs them on
tools/fixtures/dev2_kit.luau doubles with tools/fixtures/monster_spacing_offline.luau and the installed official Luau
CLI, and reads the AI wiring (aiStep, attack, steer, personalStep, aiTick, Heartbeat, spawnMonster) as source text. No
Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies of the sources only.

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


def const(mon: str, pattern: str) -> str:
    found = re.search(pattern, mon, re.M)
    if not found:
        raise ValueError(f"MonsterService constant {pattern!r} missing; update the test extractor.")
    return found.group(0)


def bindings(sources: dict[str, str]) -> dict[str, str]:
    mon = sources[M]
    consts = [const(mon, p) for p in (r"^local PERSONAL_FOLLOW_RADIUS = .*$", r"^local ZONE_MOVE_INSET = .*$")]
    sep = between(mon, "local SEP = {\n", "\n}\n") + "\n}\n"
    return {
        "CONFIG_SOURCE": sources["CONFIG_SOURCE"],
        "MONSTER_SOURCE": mon,
        "SPACING_EXTRACT": (
            "local Config, Util, H = ...\n"
            "local MC = Config.Monsters\n"
            "local records, workspace = H.records, H.workspace\n"
            "local groundPoint, getShoveParams = H.groundPoint, H.getShoveParams\n"
            + "\n".join(consts) + "\n"
            + sep
            + function_block(mon, "local function insideZone(")
            + function_block(mon, "local function findInfo(")
            + function_block(mon, "function SEP.RadiusOf(")
            + function_block(mon, "function SEP.Clear(")
            + between(mon, "------------------------------------------------------------------ A23-74 spacing",
                      "local function personalStep(")
            + "return SEP\n"),
        "SPAWN_EXTRACT": spawn_bindings(sources)["SPAWN_EXTRACT"],
        # review 2026-10-07: the real SpawnEvent (bosses) with the real SEP.Clear over the test world's records
        "EVENT_EXTRACT": (
            "local Config, Util, MonsterService, H = ...\n"
            "local records = H.records\n"
            "local groundPoint, pickSpawnPoint, spawnMonster, warnThrottled = H.groundPoint, H.pickSpawnPoint, "
            "H.spawnMonster, H.warnThrottled\n"
            + const(mon, r"^local SPAWN_TRIES = .*$") + "\n"
            + sep
            + function_block(mon, "function SEP.RadiusOf(")
            + function_block(mon, "function SEP.Clear(")
            + function_block(mon, "function MonsterService.SpawnEvent(")
            + "return MonsterService\n"),
    }


MUTATIONS = [
    # contract numbers
    ("overlap factor 0.9 again", M, "\tOverlap = 1, -- review", "\tOverlap = 0.9, -- review"),
    ("slides at the old 3 studs/s", M, "\tSpeed = 8, -- review", "\tSpeed = 3, -- review"),
    ("slides 4x faster", M, "\tSpeed = 8, -- review", "\tSpeed = 32, -- review"),
    ("one push round", M, "\tPasses = 3, -- push", "\tPasses = 1, -- push"),
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
     "local x, z = cx + math.cos(angle) * ring, cz + math.sin(angle) * ring", "local x, z = p.X, p.Z"),
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
    # rings (review: capacity measured in reach, any number of rings)
    ("full inner ring never widens", M,
     "\t\t\t\tfor _, e in ring do e.R = MC.AttackRange - SEP.RingInside end\n", ""),
    ("no waiting rings", M, "\t\twhile #ring > 1 and SEP.Need(ring) > tau do", "\t\twhile false do"),
    ("only one waiting ring", M, "\t\twhile #ring > 1 and SEP.Need(ring) > tau do", "\t\twhile inner and #ring > 1 and SEP.Need(ring) > tau do"),
    ("waiting ring ignores the ring before", M, "\t\t\tfor _, e in ring do e.R = edge + SEP.RingGap + e.Rad end\n",
     "\t\t\tfor _, e in ring do e.R += 2 * e.Rad + SEP.RingGap end\n"),
    ("ring edge not tracked", M, "\t\t\tedge = math.max(edge, e.R + e.Rad)\n", ""),
    ("the closest do not keep the ring", M,
     "\t\tif a.D ~= b.D then return a.D < b.D end\n\t\treturn a.Id < b.Id\n\tend)\n\tlocal tau",
     "\t\tif a.D ~= b.D then return a.D > b.D end\n\t\treturn a.Id < b.Id\n\tend)\n\tlocal tau"),
    ("far personal monsters chase", M,
     "\t\tif rec.Owner ~= nil and d > PERSONAL_FOLLOW_RADIUS then continue end -- a personal monster too far: it stands\n", ""),
    ("returning monsters get slots", M, "local target = rec.Owner or (not rec._returning and rec._target or nil)",
     "local target = rec.Owner or rec._target"),
    ("dying monsters in the grid", M, "\t\tif root and root.Parent and not root.Anchored then\n\t\t\trec._sepPos = root.Position",
     "\t\tif root and root.Parent then\n\t\t\trec._sepPos = root.Position"),
    # lead (review: slots move with a walking player)
    ("no lead", M, "\tLead = 0.25, -- s", "\tLead = 0, -- s"),
    ("lead not capped", M, "local k = lead > SEP.LeadMax and SEP.LeadMax / lead or 1", "local k = 1"),
    ("goal ignores the lead", M, "\tlocal cx, cz = SEP.Ahead(info)\n", "\tlocal cx, cz = p.X, p.Z\n"),
    ("body push ignores the lead", M, "local ax, az = SEP.Ahead(info) -- the body", "local ax, az = info.Pos.X, info.Pos.Z -- the body"),
    # in reach (review: step on to the slot between swings)
    ("stands still in reach", M,
     "\tif slot == nil or rec._windup ~= nil or now >= rec._nextAttackAt then return nil end",
     "\tdo return nil end"),
    ("walks during its wind-up", M,
     "\tif slot == nil or rec._windup ~= nil or now >= rec._nextAttackAt then return nil end",
     "\tif slot == nil or now >= rec._nextAttackAt then return nil end"),
    ("walks when a wind-up starts", M,
     "\tif slot == nil or rec._windup ~= nil or now >= rec._nextAttackAt then return nil end",
     "\tif slot == nil or rec._windup ~= nil then return nil end"),
    ("no settle", M, "\tif Util.FlatDistance(pos, slot) <= SEP.Settle then return nil end\n", ""),
    ("steps into the player body", M,
     "\tif dx * dx + dz * dz < ((rec._radius or SEP.Radius.Slime) + SEP.PlayerRadius) ^ 2 then return nil end\n", ""),
    ("in-reach body check where the player stands now", M,
     "\tlocal ax, az = SEP.Ahead(info)\n\tlocal dx, dz = slot.X - ax, slot.Z - az\n",
     "\tlocal ax, az = info.Pos.X, info.Pos.Z\n\tlocal dx, dz = slot.X - ax, slot.Z - az\n"),
    ("attack() ignores ReachGoal", M, "\tlocal walk = SEP.ReachGoal(rec, now, rec.Root.Position, slot, info)\n",
     "\tlocal walk = nil\n"),
    ("attack() not marked in reach", M, "\trec._inReach = true\n", ""),
    ("AutoRotate never off", M, "\tlocal want = rec._inReach ~= true\n", "\tlocal want = true\n"),
    ("in-reach mark never cleared", M, "\trec._inReach = nil\n\tif hum and hum.Parent", "\tif hum and hum.Parent"),
    ("no Rotate after a step", M, "\t\t\tok, err = pcall(SEP.Rotate, rec) -- A23-74", "\t\t\tok, err = true, nil -- A23-74"),
    ("aiStep: attack without a slot", M, "attack(rec, best, now, clampToZone(zone, SEP.Goal(rec, best)))", "attack(rec, best, now, nil)"),
    ("personalStep: attack without a slot", M, "attack(rec, info, now, SEP.Goal(rec, info))", "attack(rec, info, now, nil)"),
    # walk prediction (review: push where the bodies will be)
    ("no walk prediction", M, "\t\tlocal at = SEP.Walk(rec)\n", "\t\tlocal at = rec._sepPos\n"),
    ("walk ignores WalkSpeed", M, "local step = math.min(d, (tonumber(hum.WalkSpeed) or 0) * MC.AIInterval)", "local step = d"),
    ("last tick's walk kept", M, "\t\t\trec._walkTo = nil -- this tick's step", "\t\t\t-- this tick's step"),
    ("MoveTo point not moved along", M, "\t\t\t\t\t\t\trec.Humanoid:MoveTo(rec._walkTo)\n", ""),
    ("MoveTo point moved into water", M,
     "if goal ~= nil and rec.Humanoid and SEP.CanSlide(rec, Vector3.new(goal.X, pos.Y, goal.Z), step) then",
     "if goal ~= nil and rec.Humanoid then"),
    ("steer() hides its walk", M, "\trec._walkTo = dest -- A23-74: SEP.Walk\n", ""),
    ("attack() hides its step", M, "\t\trec._walkTo = walk\n", ""),
    ("personal walk hides its goal", M, "rec._walkTo = SEP.Goal(rec, info) -- A23-74", "rec._walkTo = nil -- A23-74"),
    # slide apart
    ("equal shares (big ones move as much)", M, "local wa = fa and 0 or (fb and 1 or rb / (ra + rb))",
     "local wa = fa and 0 or (fb and 1 or 0.5)"),
    ("a boss slides", M, "local fa, fb = SEP.Fixed(a), SEP.Fixed(b)", "local fa, fb = false, false"),
    ("players do not push", M, "\t\tfor _, info in plist do\n\t\t\tlocal ax, az", "\t\tfor _, info in {} do\n\t\t\tlocal ax, az"),
    ("players push a boss", M, "if d >= need or math.abs(pr.Y - y) >= 8 or SEP.Fixed(rec) then return false end",
     "if d >= need or math.abs(pr.Y - y) >= 8 then return false end"),
    ("pairs counted twice", M, "if b.Id > a.Id and SEP.Pair(a, b) then moved = true end",
     "if b.Id ~= a.Id and SEP.Pair(a, b) then moved = true end"),
    ("own cell only", M,
     "\t\t\tlocal pa = from[a]\n\t\t\tlocal cx, cz = math.floor(pa.X / cellSize), math.floor(pa.Z / cellSize)\n"
     "\t\t\tfor ox = -1, 1 do\n\t\t\t\tfor oz = -1, 1 do",
     "\t\t\tlocal pa = from[a]\n\t\t\tlocal cx, cz = math.floor(pa.X / cellSize), math.floor(pa.Z / cellSize)\n"
     "\t\t\tfor ox = 0, 0 do\n\t\t\t\tfor oz = 0, 0 do"),
    ("same spot never separates", M, "\t\tdx, dz, o = math.cos(ang), math.sin(ang), need\n", "\t\tdx, dz, o = 0, 0, need\n"),
    ("no speed cap", M, "local k = math.min(1, SEP.Speed * MC.AIInterval / m)", "local k = 1"),
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
    ("boss spawns on a monster", M, "\t\t\t\tif SEP.Clear(g, body) then\n", "\t\t\t\tif true then\n"),
    ("crowded boss spawn lost", M, "\t\tpos = pos or crowded\n", ""),
    # wiring
    ("aiStep chases the player's position", M, "local goal = clampToZone(zone, SEP.Goal(rec, best))",
     "local goal = clampToZone(zone, best.Pos)"),
    ("waiting monsters do not face the player", M,
     "\t\t\tif Util.FlatDistance(pos, goal) <= 1 then\n\t\t\t\tFACE.Active[rec] = { Target = best.Player, Until = now + FACE.Keep }\n\t\t\tend\n",
     ""),
    ("no player velocity", M, "\t\t\t\t\tVel = root.AssemblyLinearVelocity })", "\t\t\t\t\tVel = nil })"),
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
    check("pcall(SEP.Begin, list, plist)" in tick and "pcall(SEP.Resolve, plist)" in tick and "pcall(SEP.Rotate, rec)" in tick,
          "aiTick wraps the spacing passes in pcall")
    check(mon.count("A23-74") >= 12, "the spacing code cites A23-74 (user 2026-10-07)")
    sep = between(mon, "------------------------------------------------------------------ A23-74 spacing", "local function personalStep(")
    check("SEP.Pair(a, b, push)" not in sep and "push[rec]" not in sep, "Resolve keeps no stale push table (end points move)")
    return count, failures


SUITE = Suite(
    mark="MONSTER_SPACING",
    fixture=ROOT / "tools/fixtures/monster_spacing_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-07/offline_monster_spacing_2026-10-07.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-74 (user 2026-10-07 \"점점 합쳐지겠다\"): body radius = 1.5 x Scale (Slime shape) / 1.25 x Scale "
             "(Humanoid); a chaser's goal is its slot on a ring r + 1 + 1 (<= AttackRange - 0.5) around its target, "
             "centred 0.25 s ahead of a walking player (at most 4 studs); slots of one player's chasers spread (order "
             "kept, least movement) so ring neighbours stand rA + rB apart; when they do not fit, the inner ring moves "
             "out to AttackRange - 0.5 (10 Shard Slimes in reach) and the rest wait on further rings outside reach, each "
             "RingGap outside the bodies of the ring before (30 slimes: 10 + 18 + 2); a slot on water falls back to the "
             "player's position. In reach a monster stands for its swing (pending wind-up or cooldown up), within 0.5 of "
             "its slot or when the slot is inside the player body, else it steps on to its slot (AutoRotate off while in "
             "reach). After every AI tick the end points of the coming walks (_walkTo at WalkSpeed) are pushed apart in "
             "up to 3 rounds where bodies would overlap (rA + rB, the smaller one moving more, a boss never) or a body "
             "would be inside a player (r + 1 around where the player will be); each push becomes a slide over that tick "
             "at most 8 studs/s, never into water / past the zone move inset / through a wall (half step tried), and a "
             "walking monster's MoveTo point moves along; pushes under 0.05 are ignored; neighbours come from an 8-stud "
             "grid; a new monster spawns at least rA + rB + 1.5 from every living one, else the first crowded ground "
             "point; SpawnEvent (bosses) keeps the same clearance within its radius, else its spot (the slides clear "
             "it). Review probe: walking 3 / 5 / 8 studs/s with 4 Shard + 2 King Slimes, mean deepest overlap per AI "
             "tick < 0.3 studs. Monster parts stay CanCollide = false.",
    limitations="Roots, Humanoids (MoveTo / WalkSpeed / AutoRotate), the ground ray, walls, Random and the player list "
                "are doubles; the simulations use a stand-in for aiStep / attack (walk at Def.Speed x the NATURAL ramp, "
                "a wind-up of MonsterWindup s, a Humanoid that stops once it reached its MoveTo point) around the real "
                "SEP passes. Real Humanoid MoveTo / AutoRotate behaviour, replication smoothness of the server slides, "
                "the FACE turn while stepping sideways and the Tripo mesh footprints are only checkable in Studio Play "
                "(game dev 1). SEP.Need sorting ties by id (like Spread) is asserted but has no mutation: Luau's "
                "table.sort happens to order the test ties the same way with an angle-only comparator.",
)

if __name__ == "__main__":
    run(SUITE)
