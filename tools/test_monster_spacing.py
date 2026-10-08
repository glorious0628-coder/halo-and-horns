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

Review 2026-10-08 (검수, two more): (1) monsters crowded on a zone's move line (ZONE_MOVE_INSET inside the zone edge)
never came apart: SEP.CanSlide refused a whole slide whose end crossed the line, also its part along the line, and the
ring slots of a player near the edge were all clamped onto the line. Now SEP.Fit / SEP.Add keep only the part of a slide
that stays inside the line (checked from where the body stands and where its walk ends), the other monster of a pair
takes the dropped part, a body pinned on the line leaves a player body along it, and SEP.Surround counts only the part
of each ring inside the line (SEP.Arc / SEP.RingArc / SEP.SpreadArc: fewer fit, the rest wait on the next ring).
(2) With two players standing together, a monster between them took the nearest every tick and swapped target and
ring slot back and forth; SEP.Pick keeps a target 2 s and then only gives it up for a player 3 studs closer. Review
2026-10-08 (2nd round): but never a target out of reach while another player is in reach (pushed off its slot into the
other player's body, a King Slime stood in that player's reach and swung at nobody; with players under 3 studs apart the
margin can never be met). Review 2026-10-08 (3rd round): that reach rule bypassed the hold, so in a crowd (12 Shard + 4
King Slimes) a monster shoved across the reach edge went A -> B -> A every 0.5 s; the hold now comes first (idle at most
2 s). Cutting each player's rings by the other players' bodies was tried and dropped (in groups of 3-4 players it left
most chasers out of reach). A crowd probe (16 runs of 40 s, two players 2 / 4 studs apart) asserts: no switch within
2 s, A -> B -> A at most 20% of the old rule's, idle at most the hold, swings >= 90% and about the old rule's pile
(mean deepest overlap <= 1.25x). Review 2026-10-08 (merge): a taunt that just ran out (SKL-3) gives a free pick (the
nearest, as main had it). Edge rework after the adversarial pass: SEP.Arc lays the cuts out from an uncovered point
(a cut across 0 hid another), a ring with no room starts the next one outside its clamped slot (zone corners, a running
player), a player with a personal monster among its chasers keeps whole rings, the slide limit also counts the MoveTo
point and a followed MoveTo point keeps room for the rest of the slide (a walk that got there early still slid past
the line), and SEP.Body tries the other side and, in a corner, the other line.

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
    consts = [const(mon, p) for p in (r"^local PERSONAL_FOLLOW_RADIUS = .*$", r"^local ZONE_MOVE_INSET = .*$",
                                       r"^local OUT_Y = .*$")]
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
            + function_block(mon, "local function clampToZone(")
            + function_block(mon, "local function findInfo(")
            + function_block(mon, "local function targetable(")
            + function_block(mon, "function SEP.RadiusOf(")
            + function_block(mon, "function SEP.Clear(")
            + between(mon, "------------------------------------------------------------------ A23-74 spacing",
                      "local function personalStep(")
            # review 2026-10-08: the real zone clamp of aiStep for the stand-in chase at the zone edge
            + "return SEP, clampToZone\n"),
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
    ("no waiting rings", M, "\t\twhile #ring > 1 and not SEP.Fits(ring, arc) do", "\t\twhile false do"),
    ("only one waiting ring", M, "\t\twhile #ring > 1 and not SEP.Fits(ring, arc) do",
     "\t\twhile inner and #ring > 1 and not SEP.Fits(ring, arc) do"),
    ("waiting ring ignores the ring before", M, "\t\t\tfor _, e in ring do e.R = edge + SEP.RingGap + e.Rad end\n",
     "\t\t\tfor _, e in ring do e.R += 2 * e.Rad + SEP.RingGap end\n"),
    ("ring edge not tracked", M, "\t\t\tedge = math.max(edge, r + e.Rad)\n", ""),
    ("the closest do not keep the ring", M,
     "\t\tif a.D ~= b.D then return a.D < b.D end\n\t\treturn a.Id < b.Id\n\tend)\n\tlocal cx, cz",
     "\t\tif a.D ~= b.D then return a.D > b.D end\n\t\treturn a.Id < b.Id\n\tend)\n\tlocal cx, cz"),
    ("far personal monsters chase", M,
     "\t\tif rec.Owner ~= nil and d > PERSONAL_FOLLOW_RADIUS then continue end -- a personal monster too far: it stands\n", ""),
    ("returning monsters get slots", M, "local target = rec.Owner or (not rec._returning and rec._target or nil)",
     "local target = rec.Owner or rec._target"),
    ("dying monsters in the grid", M, "\t\tif root and root.Parent and not root.Anchored then\n\t\t\trec._sepPos = root.Position",
     "\t\tif root and root.Parent then\n\t\t\trec._sepPos = root.Position"),
    # lead (review: slots move with a walking player)
    ("no lead", M, "\tLead = 0.25, -- s", "\tLead = 0, -- s"),
    ("lead not capped", M, "local k = lead > SEP.LeadMax and SEP.LeadMax / lead or 1", "local k = 1"),
    ("goal ignores the lead", M, "\tlocal cx, cz = SEP.Ahead(info)\n\tlocal x, z", "\tlocal cx, cz = p.X, p.Z\n\tlocal x, z"),
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
    ("MoveTo point moved into water / past the line", M,
     "local follow = goal ~= nil and rec.Humanoid and SEP.Fit(rec, Vector3.new(goal.X, pos.Y, goal.Z), step, step)",
     "local follow = goal ~= nil and rec.Humanoid and step"),
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
     "\t\t\tlocal pa = a._sepFrom\n\t\t\tlocal cx, cz = math.floor(pa.X / cellSize), math.floor(pa.Z / cellSize)\n"
     "\t\t\tfor ox = -1, 1 do\n\t\t\t\tfor oz = -1, 1 do",
     "\t\t\tlocal pa = a._sepFrom\n\t\t\tlocal cx, cz = math.floor(pa.X / cellSize), math.floor(pa.Z / cellSize)\n"
     "\t\t\tfor ox = 0, 0 do\n\t\t\t\tfor oz = 0, 0 do"),
    ("same spot never separates", M, "\t\tdx, dz, o = math.cos(ang), math.sin(ang), need\n", "\t\tdx, dz, o = 0, 0, need\n"),
    ("no speed cap", M, "local k = math.min(1, SEP.Speed * MC.AIInterval / m)", "local k = 1"),
    ("jitter on tiny overlaps", M, "if m >= SEP.MinPush and rec.Alive", "if m > 0 and rec.Alive"),
    ("slides teleported monsters", M, "if Util.FlatDistance(pos, rec._sepPos) <= 1 then -- not teleported home this tick",
     "if true then"),
    ("no half step", M, "for _, part in { 1, 0.5 } do", "for _, part in { 1 } do"),
    ("slides into water", M, "\tif not g and not noHit then return nil end\n\tif workspace:Raycast", "\tif workspace:Raycast"),
    ("slides through walls", M,
     "\tif workspace:Raycast(pos, delta * ((m + 0.5) / m), getShoveParams()) ~= nil then return nil end\n", ""),
    ("a zone monster out of its zone slides", M, "\tif rec.Owner == nil and here ~= rec.ZoneId then return nil end\n", ""),
    # zone edge (review 2026-10-08: along the move line, never across it)
    ("slide check ignores the move line", M, "\tlocal box = SEP.Box(rec, pos)\n", "\tlocal box = nil\n"),
    ("slide check refuses the whole slide at the line (old)", M,
     "\t\tdelta = Vector3.new(math.max(box.X0, math.min(box.X1, x)) - pos.X, delta.Y,\n",
     "\t\tdo return nil end\n\t\tdelta = Vector3.new(math.max(box.X0, math.min(box.X1, x)) - pos.X, delta.Y,\n"),
    ("slide check: a body past the line can never slide", M, "\tlocal box = SEP.Box(rec, pos)\n", "\tlocal box = SEP.Box(rec)\n"),
    ("followed MoveTo point keeps no room for the rest of the slide", M,
     "SEP.Fit(rec, Vector3.new(goal.X, pos.Y, goal.Z), step, step)", "SEP.Fit(rec, Vector3.new(goal.X, pos.Y, goal.Z), step)"),
    ("room past the end on the wrong side", M, "box.X0, box.X1 = box.X0 - math.min(0, after.X), box.X1 - math.max(0, after.X)",
     "box.X0, box.X1 = box.X0 + math.min(0, after.X), box.X1 + math.max(0, after.X)"),
    ("push rounds ignore the move line", M, "\tlocal box = rec._sepBox\n\tif box then\n", "\tlocal box = rec._sepBox\n\tif false then\n"),
    ("move line checked from the start only", M,
     "\t\tlocal cx = math.clamp(sx, box.X0 - math.min(q.X, goal.X), box.X1 - math.max(q.X, goal.X))\n"
     "\t\tlocal cz = math.clamp(sz, box.Z0 - math.min(q.Z, goal.Z), box.Z1 - math.max(q.Z, goal.Z))\n",
     "\t\tlocal cx = math.clamp(sx, box.X0 - q.X, box.X1 - q.X)\n"
     "\t\tlocal cz = math.clamp(sz, box.Z0 - q.Z, box.Z1 - q.Z)\n"),
    ("move line not checked at the MoveTo point", M, "\t\tlocal goal = rec._walkTo or q\n", "\t\tlocal goal = from\n"),
    ("box not grown to the MoveTo point", M, "rec._sepBox = SEP.Box(rec, rec._sepPos, rec._walkTo or rec._sepPos)",
     "rec._sepBox = SEP.Box(rec, rec._sepPos, at)"),
    ("no box in the push rounds", M, "rec._sepBox = SEP.Box(rec, rec._sepPos, rec._walkTo or rec._sepPos)", "rec._sepBox = nil"),
    ("a pinned one's part is lost", M, "local sx, sz = SEP.Add(b, -dx * o * wb - rx, -dz * o * wb - rz)",
     "local sx, sz = SEP.Add(b, -dx * o * wb, -dz * o * wb)"),
    ("a pinned second one's part is lost", M, "\t\tif not fa and (sx ~= 0 or sz ~= 0) then SEP.Add(a, -sx, -sz) end\n", ""),
    ("pinned in a player body: stays", M, "\tif rx == 0 and rz == 0 then return true end\n\tlocal at", "\tdo return true end\n\tlocal at"),
    ("pinned in a player body: only its own side", M, "\tfor _, s in { side, -side } do\n", "\tfor _, s in { side } do\n"),
    ("pinned in a player body: along the pinned line", M, "\tlocal alongZ = rx ~= 0 -- pinned", "\tlocal alongZ = rx == 0 -- pinned"),
    ("a blocked try is kept", M, "\t\tSEP.Add(rec, ux - mx, uz - mz) -- that way is blocked too", "\t\t-- that way is blocked too"),
    ("rings never cut by the move line", M, "if rec.Owner ~= nil then personal = true else box = box or SEP.Box(rec) end",
     "if rec.Owner ~= nil then personal = true end"),
    ("a personal monster's rings cut by the move line", M, "\tif personal then box = nil end\n", ""),
    ("rings cut around the player, not where it will be", M,
     "\tlocal cx, cz = SEP.Ahead(info)\n\tlocal known = {}", "\tlocal cx, cz = p.X, p.Z\n\tlocal known = {}"),
    ("next ring starts at the no-room member's ring", M, "\t\t\tif arc == false then -- no room inside the line",
     "\t\t\tif false then -- no room inside the line"),
    ("arc: a ring inside is cut anyway", M, "\tif r <= dx1 and r <= dx0 and r <= dz1 and r <= dz0 then return nil end\n", ""),
    ("arc: laid out from a covered point", M, "\t\tif not covered then\n", "\t\tif true then\n"),
    ("arc: a ring with no room counts as room", M, "\t\tif dist <= -r then return false end\n", "\t\tif dist <= -r then return nil end\n"),
    ("arc: the first free piece ignored", M, "\t\tif c.S > reach and (a0 == nil or c.S - reach > a1 - a0) then a0, a1 = reach, c.S end\n",
     "\t\tif c.S > reach and a0 ~= nil and c.S - reach > a1 - a0 then a0, a1 = reach, c.S end\n"),
    ("ring arc: the last member's only", M, "a0, a1 = math.max(a0, arc.A0 + shift), math.min(a1, arc.A1 + shift)",
     "a0, a1 = arc.A0 + shift, arc.A1 + shift"),
    ("ring arc: one member without room ignored", M, "\t\tif arc == false then return false end\n\t\tif arc then",
     "\t\tif arc == false then continue end\n\t\tif arc then"),
    ("fits where there is no room", M, "\tif arc == false then return false end\n\tlocal run", "\tif arc == false then return true end\n\tlocal run"),
    ("long arc ends may touch", M, "\t\tif short > 0 then a0, a1 = a0 + short / 2, a1 - short / 2 end\n", ""),
    ("spread not kept inside the arc", M, "\t\te.A = math.max(a0 + before, math.min(a1 - (total - before), e.A))\n", ""),
    ("arc rings spread on the whole ring", M, "\t\telseif arc then\n\t\t\tSEP.SpreadArc(ring, arc)", "\t\telseif arc then\n\t\t\tSEP.Spread(ring)"),
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
    # target hold (review 2026-10-08: two players side by side)
    ("no target hold time", M, "\t\tand (now < (rec._targetAt or -math.huge) + SEP.TargetHold\n", "\t\tand (false\n"),
    ("no target margin", M, "\t\t\tor (bestD > curD - SEP.TargetMargin and (", "\t\t\tor (false and ("),
    # review 2026-10-08: after the hold a target out of reach never beats a player in reach
    ("held target out of reach beats one in reach", M, "(curD <= MC.AttackRange or bestD > MC.AttackRange))) then",
     "(true))) then"),
    ("a target out of reach always dropped", M, "(curD <= MC.AttackRange or bestD > MC.AttackRange))) then",
     "(curD <= MC.AttackRange))) then"),
    ("in reach of both: still switches", M, "(curD <= MC.AttackRange or bestD > MC.AttackRange))) then",
     "(bestD > MC.AttackRange))) then"),
    # review 2026-10-08 (3rd round): the hold comes first (the 2nd round's reach rule bypassed it: A -> B -> A in 0.5 s)
    ("reach rule ahead of the hold (2nd round)", M,
     "\t\tand (now < (rec._targetAt or -math.huge) + SEP.TargetHold\n"
     "\t\t\tor (bestD > curD - SEP.TargetMargin and (curD <= MC.AttackRange or bestD > MC.AttackRange))) then\n",
     "\t\tand (now < (rec._targetAt or -math.huge) + SEP.TargetHold or bestD > curD - SEP.TargetMargin)\n"
     "\t\tand (curD <= MC.AttackRange or bestD > MC.AttackRange) then\n"),
    ("always the nearest (old rule)", M, "\tif not free and cur ~= nil and best ~= cur\n", "\tif false then\n"),
    ("a taunt's end keeps the hold", M, "\tif not free and cur ~= nil and best ~= cur\n", "\tif cur ~= nil and best ~= cur\n"),
    ("aiStep never picks free after a taunt", M,
     "\t\tlocal free = rec._tauntUntil ~= nil and now >= rec._tauntUntil and rec._target == rec._tauntBy\n",
     "\t\tlocal free = false\n"),
    ("a stamp on every pick", M,
     "\tif best then\n\t\tif rec._target ~= best.Player then\n\t\t\trec._chaseStuck = 0\n"
     "\t\t\trec._targetAt = now -- SEP.Pick holds a new target TargetHold s\n",
     "\tif best then\n\t\trec._targetAt = now -- SEP.Pick holds a new target TargetHold s\n"
     "\t\tif rec._target ~= best.Player then\n\t\t\trec._chaseStuck = 0\n"),
    ("hold 0 s", M, "\tTargetHold = 2, -- s", "\tTargetHold = 0, -- s"),
    ("margin 1 stud", M, "\tTargetMargin = 3, -- studs", "\tTargetMargin = 1, -- studs"),
    ("a target past AggroRadius kept", M, "\t\t\tif d <= MC.AggroRadius then\n\t\t\t\tif bestD == nil", "\t\t\tif true then\n\t\t\t\tif bestD == nil"),
    ("pick ignores targetable", M, "\t\tif targetable(rec, info) then\n\t\t\tlocal d = Util.FlatDistance(pos, info.Pos)\n\t\t\tif d <= MC.AggroRadius then",
     "\t\tif true then\n\t\t\tlocal d = Util.FlatDistance(pos, info.Pos)\n\t\t\tif d <= MC.AggroRadius then"),
    ("aiStep picks the nearest itself", M, "\t\tbest, bestD = SEP.Pick(rec, plist, pos, now, free)\n",
     "\t\tfor _, info in plist do\n\t\t\tif targetable(rec, info) then\n\t\t\t\tlocal d = Util.FlatDistance(pos, info.Pos)\n"
     "\t\t\t\tif d <= MC.AggroRadius and (bestD == nil or d < bestD) then best, bestD = info, d end\n\t\t\tend\n\t\tend\n"),
    ("new target not stamped", M, "\t\t\trec._targetAt = now -- SEP.Pick holds a new target TargetHold s\n", ""),
    # wiring
    ("a wander's last studs hide their point", M, "\t\tif rec._goal then rec._walkTo = rec._goal end\n", ""),
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
    check("SEP.CanSlide" not in mon and "math.clamp(" not in function_block(mon, "function SEP.SpreadArc("),
          "review 2026-10-08: slides go through SEP.Fit (the old all-or-nothing CanSlide is gone); SpreadArc never "
          "calls math.clamp (it throws when min > max)")
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
             "tick < 0.3 studs. Review 2026-10-08: a zone monster's slide keeps its part along the zone's move line "
             "(ZONE_MOVE_INSET inside the zone edge) and drops only the part crossing it, checked all the way from where "
             "the body stands to its MoveTo point; the other monster of a pair takes the dropped part; a body pinned on "
             "the line leaves a player body along it (the other side when its own is blocked); a MoveTo point moved "
             "along a slide stays inside the line with room for the rest of the slide; a player's rings count only their "
             "arc inside the line (around where the player will be), fewer fit and the rest wait on the next ring, so no "
             "slot needs clamping (a player 3 studs past the line: 6 chasers, none touching, old clamped slots 2.6 studs "
             "inside each other); a ring with no room keeps its closest one and the next ring starts outside where "
             "aiStep clamps it (zone corners, a running player); a player with a personal monster among its chasers "
             "keeps whole rings; a zone monster keeps its target 2 s (never switching again sooner), then switches only "
             "to a player 3 studs closer, or when its target is out of AttackRange and another player is in reach (idle "
             "in the other player's reach at most those 2 s); right after a taunt (SKL-3) the nearest one, no hold. Two "
             "players 2 / 4 studs apart, standing or walking together: with 4 Shard + 2 King Slimes no switch within 2 s "
             "and at most half the old rule's switches; with a crowd of 12 Shard + 4 King Slimes (16 runs of 40 s) "
             "monsters still change target now and then (switches about 20% and A -> B -> A about 14% of the "
             "nearest-every-tick rule's, none within 2 s), swing >= 90% as often and pile up about as much (mean "
             "deepest overlap <= 1.25x the old rule's). "
             "Monster parts stay CanCollide = false.",
    limitations="Roots, Humanoids (MoveTo / WalkSpeed / AutoRotate), the ground ray, walls, Random and the player list "
                "are doubles; the simulations use a stand-in for aiStep / attack (walk at Def.Speed x the NATURAL ramp, "
                "a wind-up of MonsterWindup s, a Humanoid that stops once it reached its MoveTo point) around the real "
                "SEP passes (with aiStep's real zone clamp, and the real SEP.Pick for several players). Real Humanoid "
                "MoveTo / AutoRotate behaviour, replication smoothness of the server slides, "
                "the FACE turn while stepping sideways and the Tripo mesh footprints are only checkable in Studio Play "
                "(game dev 1). SEP.Need sorting ties by id (like Spread) is asserted but has no mutation: Luau's "
                "table.sort happens to order the test ties the same way with an angle-only comparator. Review "
                "2026-10-08: each player's rings know neither the other players' bodies nor their chasers' slots "
                "(cutting them by the bodies left most chasers of a 3-4 player group out of reach), so a slot can lie "
                "inside another player and around players 2 studs apart the two inner rings overlap: the body push "
                "and the slides take that, and in a crowd a monster may change target about every few seconds (never "
                "within 2 s). A zone's chasers are assumed to share the player's zone (targetable); the rings take the "
                "first zone chaser's rect. SEP.Arc keeps only the longest free piece when a narrow zone cuts a ring "
                "twice (no game zone is that narrow). Final adversarial recheck (minor, left): with a personal monster "
                "among a player's chasers the zone chasers get whole rings and pile on the move line again (personal "
                "monsters have no spawner in the game yet); SEP.Body in a corner always tries the z line first (out "
                "within 4 ticks, sometimes the long way round); the crowd swing bar holds on the 16-run total, single "
                "runs with players 2 studs apart get 60-87% of the old rule's swings; players standing within ~1 stud "
                "of each other: about 3% fewer swings than the reach-first order (the hold comes first); a taunt that "
                "runs out while the monster targets someone else stays recorded until the next pick of the taunter.",
)

if __name__ == "__main__":
    run(SUITE)
