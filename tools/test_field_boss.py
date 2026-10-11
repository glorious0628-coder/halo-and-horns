"""The field bosses (FieldBossService, 게임성 개발 2; started as the King Slime 2026-10-08), server side, offline.

content_beyond_10min_2026-10-08 FB + A23-84 / A23-85 (docs/design/king_slime_split_2026-10-08.md §3): per
Config.FieldBosses key one boss on the server, the first slot FirstDelay s after the start, then every Interval s from its
last appearance (a due slot waits for a ready hunter in its zone); it stays Lifetime s. Spot: the marked attribute
(KingSpawn) on workspace.Map > (Hill) MeadowTerrainStore HillTop moved 8 studs toward HillPathFoot > Spawn > a zone
spawn point. Defeat = Fx KingDefeat + Defeat line + Defeated signal; time up / lost = goes home + Leave line.
The old King Slime (BigSlime) is the Slime Prince; the finisher card belongs to the King Slime only.
A23-113 ⑦ (2026-10-11, docs/design/field_boss_crowd_2026-10-11.md): the boss HP follows the hunters at it.

Runs the CURRENT Config, Util and FieldBossService on tools/fixtures/dev2_kit.luau + tools/fixtures/field_boss_offline.luau
with the installed official Luau CLI (MonsterService / PlayerService / ZoneService / AnnounceService are doubles, except
MonsterService.SetEventMaxHP / DamageTotals, which run from the source). No Studio, network, DataStore or Roblox API
calls; mutations run on in-memory copies of the sources only.

Usage: py tools/test_field_boss.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-11/offline_dev2_field_boss_2026-10-11.json (was ..._2026-10-09.json)
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "NET_SOURCE": SHARED / "Net.luau",
    "MAIN_SOURCE": SSS / "Main.server.luau",
    "FIELDBOSS_SOURCE": SSS / "FieldBossService.luau",
    "MONSTER_SOURCE": SSS / "MonsterService.luau",
    "COMBAT_SOURCE": SSS / "CombatService.luau",
}
C, K, N, M = "CONFIG_SOURCE", "FIELDBOSS_SOURCE", "NET_SOURCE", "MAIN_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = {k: v for k, v in sources.items() if k not in ("MONSTER_SOURCE", "COMBAT_SOURCE")}
    mon = sources["MONSTER_SOURCE"]
    lim = re.search(r"^local GROUND_MIN_Y, GROUND_MAX_Y = .*$", mon, re.M)
    if not lim:
        raise ValueError("MonsterService GROUND_MIN_Y / GROUND_MAX_Y missing; update the test extractor.")
    # MonsterService's real groundPoint on a probe double (SetY(y): the ground there; nil = no hit)
    out["GROUND_EXTRACT"] = (
        "local Y = nil\n"
        "local function probeGround() if Y == nil then return nil, false end return Y, false end\n"
        "local function occupied() return false end\n"
        + lim.group(0) + "\n"
        + function_block(mon, "local function groundPoint(")
        + "\nreturn { SetY = function(y) Y = y end, Point = groundPoint }\n")
    # A23-92: MonsterService.HitPad with the real SEP.RadiusOf, and CombatService's target search text
    out["HITPAD_EXTRACT"] = (
        "local Config = ...\nlocal MonsterService = {}\nlocal SEP = { Radius = { Slime = 1.5, Humanoid = 1.25 } }\n"
        + function_block(mon, "function SEP.RadiusOf(")
        + function_block(mon, "function MonsterService.HitPad(")
        + "\nreturn { HitPad = MonsterService.HitPad, RadiusOf = SEP.RadiusOf }\n")
    # A23-113 ⑦: the crowd HP helpers, real (the bar is a counter)
    out["MONSTER_HP_EXTRACT"] = (
        "local MonsterService = {}\n"
        "local function updateBar(rec) rec._bars = (rec._bars or 0) + 1 end\n"
        + function_block(mon, "function MonsterService.SetEventMaxHP(")
        + function_block(mon, "function MonsterService.DamageTotals(")
        + "\nreturn MonsterService\n")
    # 검수 bosshp_verify 2026-10-11: the real DamageMonster + killRecord (the reward bar reads each hit's share, _share)
    out["KILL_EXTRACT"] = (
        "local records, Config, MC, MonsterService, factionOf, updateBar, deathPop, removePersonalRef, scheduleRespawn, "
        "warnThrottled, zoneIdOf, MOB3, markHurt = ...\n"
        + function_block(mon, "local function killRecord(")
        + function_block(mon, "function MonsterService.DamageMonster(")
        + "\nreturn { Kill = killRecord, Damage = MonsterService.DamageMonster }\n")
    out["COMBAT_NEAR_TEXT"] = function_block(sources["COMBAT_SOURCE"], "local function monstersNear(")
    out["MONSTER_QUERY_TEXT"] = function_block(mon, "function MonsterService.GetMonstersInRadius(")
    return out


MUTATIONS = [
    ("no hunter check", K, "\tif not hunterHere(key) then return end", ""),
    ("any zone counts", K, "if ok and z == zone then return true end", "if ok then return true end"),
    ("not-ready players count", K, "\t\tif S.PlayerService.IsReady(p) then\n", "\t\tif true then\n"),
    ("marked spot ignored", K, "\tif okS and marked then return marked, \"Marked\" end\n", ""),
    ("hill for every boss", K, "\tif c.Hill == true then\n", "\tif true then\n"),
    ("hill step ignored", K, "\treturn top + d.Unit * math.max(0, num(step, 8))", "\treturn top"),
    ("hill step goes away from the path", K, "\treturn top + d.Unit * math.max(0, num(step, 8))",
     "\treturn top - d.Unit * math.max(0, num(step, 8))"),
    ("hill step not flat", K, "local d = Vector3.new(foot.X - top.X, 0, foot.Z - top.Z)", "local d = foot - top"),
    ("radius lost", K, "{ Near = near, Radius = math.max(0, num(c.Radius, 2)),", "{ Near = near,"),
    ("never leaves", K, "\t\telseif now >= b.EndsAt then\n\t\t\tfinish(key, false)\n", "\t\telseif false then\n"),
    ("leaving with a splat", K, "pcall(svc.RemoveEvent, rec, true, true)", "pcall(svc.RemoveEvent, rec, true, false)"),
    ("a lost model counts as a defeat", K, "finish(key, num(rec.HP, 1) <= 0) -- a lost", "finish(key, true) -- a lost"),
    ("no defeat Fx", K, "local ok, err = pcall(Net.Fx, nil, \"KingDefeat\"", "local ok, err = true, nil --"),
    ("no Defeated signal", K, "\t\tFieldBossService.Defeated:Fire(key, rec.Kind, table.clone(ids), rec)\n", ""),
    ("Defeat and Leave swapped", K, "(defeated and \"Defeat\" or \"Leave\")", "(defeated and \"Leave\" or \"Defeat\")"),
    ("no Appear line", K, "\tannounce(key .. \"Appear\")\n", ""),
    ("next slot not set", K, "\t\tb.NextAt = now + math.max(60, num(c.Interval, 480))\n\telse", "\telse"),
    ("no retry delay", K, "b.NextAt = now + math.max(1, num(c.RetryDelay, 10))", "b.NextAt = now"),
    ("debug spawns twice", K, "\t\tif b.Rec.Alive then return \"already here\" end\n", ""),
    ("Active not published", K, "\tsetGame(key .. \"Active\", active)\n", ""),
    ("first slot at once", K, "(now + math.max(0, num(c.FirstDelay, 180)))", "(now)"),
    ("string ids in Contributors", K, "\t\t\tif type(id) == \"number\" then table.insert(ids, id) end",
     "\t\t\ttable.insert(ids, id)"),
    ("card back on the Prince", C, "\tKinds = { SlimeKing = true, CaptainClatter = true },",
     "\tKinds = { BigSlime = true, CaptainClatter = true },"),
    ("Prince renamed back", C, "BigSlime = { Name = \"Slime Prince\"", "BigSlime = { Name = \"King Slime\""),
    ("a mom line", C, "SlimeKingLeaveEn = \"King Slime: \\\"Hmph! Bedtime, kids!\\\"\"",
     "SlimeKingLeaveEn = \"King Slime: \\\"Hmph! Mom says bedtime!\\\"\""),
    ("King in the regular pool", C, "Zone = \"SlimeMeadow\", Count = 0, Boss = true,", "Zone = \"SlimeMeadow\", Count = 2, Boss = true,"),
    # 검수 2026-10-09: the shrine marker part, the hill's MaxY
    ("no marker part", K, "\t\tif part == nil and d:IsA(\"BasePart\") and (d.Name == attr or v == true) then part = d end\n", ""),
    ("any part is a marker", K, "(d.Name == attr or v == true) then part = d end", "(true) then part = d end"),
    ("no MaxY to SpawnEvent", K, "\t\tMaxY = c.MaxY })", "\t\tMaxY = nil })"),
    ("the King without MaxY", C, "\t\tMaxY = 40 }, -- the hill-top shrine", "\t\tMaxY = nil }, -- the hill-top shrine"),
    # A23-92: a big boss is reached at its body's edge
    ("no hit pad", "MONSTER_SOURCE", "\tif type(def) ~= \"table\" or def.Boss ~= true then return 0 end\n\treturn math.max(0,",
     "\tif true then return 0 end\n\treturn math.max(0,"),
    ("hit pad for every monster", "MONSTER_SOURCE", "\tif type(def) ~= \"table\" or def.Boss ~= true then return 0 end\n",
     "\tif type(def) ~= \"table\" then return 0 end\n"),
    ("the query ignores the pad", "MONSTER_SOURCE", "<= radius + MonsterService.HitPad(rec) then\n\t\t\t\ttable.insert(out, rec)",
     "<= radius then\n\t\t\t\ttable.insert(out, rec)"),
    ("combat ignores the pad", "COMBAT_SOURCE", "\t\t\t\tif d <= radius + pad then\n", "\t\t\t\tif d <= radius then\n"),
    ("the King as small as before", C, "Shape = \"Slime\", Scale = 3.2, Color = Color3.fromRGB(255, 140, 190) },",
     "Shape = \"Slime\", Scale = 2.5, Color = Color3.fromRGB(255, 140, 190) },"),
    ("not in Main START", M, "\"FinisherService\", \"FieldBossService\", -- 게임성 개발 2 (before",
     "\"FinisherService\", -- 게임성 개발 2 (before"),
    ("no Net default", N, "SlimeKingNextAt = 0, SlimeKingActive = false, SlimeKingEndsAt = 0,", ""),
    # J Captain Clatter extras
    ("war pool per player (stacks)", K, "local ok, err = pcall(S.WarService.AddPoints, player, war, war / n)",
     "local ok, err = pcall(S.WarService.AddPoints, player, war, war)"),
    ("sides never counted", K, "\t\t\tif type(f) == \"string\" then sides[f] = (sides[f] or 0) + 1 end\n", ""),
    ("no extras paid", K, "\t\tpayExtras(key, ids)\n", ""),
    ("no side share", K, "\t\t\tShare = shareOf(rec) })", "\t\t\tShare = nil })"),
    ("share sides swapped", K, "return { Halo = hp, Horns = 100 - hp }", "return { Halo = 100 - hp, Horns = hp }"),
    ("no war points", K, "\tif num(c.War) > 0 and S.WarService", "\tif false and S.WarService"),
    ("kills never counted", K, "\trow.Kills = math.max(0, math.floor(num(row.Kills))) + 1\n",
     "\trow.Kills = math.max(0, math.floor(num(row.Kills)))\n"),
    ("titles at any count", K, "if type(at) == \"number\" and row.Kills >= at then", "if type(at) == \"number\" then"),
    ("no weekly bank", K, "\t\trow.Owed = math.min(max, row.Owed + (week - row.Week))\n", "\t\trow.Owed = row.Owed\n"),
    ("first kill gives nothing", K, "\tif row.Week <= 0 then\n\t\trow.Owed = math.min(max, row.Owed + 1)\n",
     "\tif row.Week <= 0 then\n\t\trow.Owed = row.Owed\n"),
    ("a full bag loses the guarantee", K, "\tif num(got) < 1 then return end -- a full bag", "\tif false then return end -- a full bag"),
    ("broken save banks more", K, "\trow.Owed = math.min(max, row.Owed) -- a broken save", "\trow.Owed = row.Owed -- a broken save"),
    ("badge every kill", K, "\trow.Owed -= 1\n", ""),
    ("Clatter weekly 3", C, "\t\tWeekly = { Item = \"CaptainBadge\", N = 1, Max = 2 },", "\t\tWeekly = { Item = \"CaptainBadge\", N = 1, Max = 3 },"),
    ("Clatter every 10 min", C, "\tClatter = { Enabled = true, Kind = \"CaptainClatter\", FirstDelay = 300, Interval = 1200,",
     "\tClatter = { Enabled = true, Kind = \"CaptainClatter\", FirstDelay = 300, Interval = 600,"),
    ("Clatter card not the same size", C, "Tickle = { Gold = 300 },", "Tickle = { Gold = 400 },"),
    # A23-113 ⑦ crowd HP
    ("no crowd count", K, "\t\t\tCROWD.Tick(key, now)\n", ""),
    ("share not capped at 1", K, "math.min(1, recent / pace)", "recent / pace"),
    ("any damage counts 1", K, "sum += (c.ByDamage == false or pace <= 0) and 1 or math.min(1, recent / pace)", "sum += 1"),
    ("ByDamage = false ignored", K, "(c.ByDamage == false or pace <= 0) and 1", "(pace <= 0) and 1"),
    ("the window never moves", K, "\twhile #snaps > 1 and snaps[2].At <= now - window do table.remove(snaps, 1) end\n", ""),
    ("the window too short", K, "snaps[2].At <= now - window do", "snaps[2].At <= now - 2 do"),
    ("baseline = the newest snapshot", K, "\tlocal base = snaps[1]\n", "\tlocal base = snaps[#snaps]\n"),
    ("pace from the current MaxHP", K, "local rate = b.BaseHP / math.max(1, num(c.SoloSeconds, 120))",
     "local rate = b.Rec.MaxHP / math.max(1, num(c.SoloSeconds, 120))"),
    ("no rise floor (a burst counts whole)", K, "local pace = rate * math.max(rise, now - since)", "local pace = rate * math.max(0.01, now - since)"),
    ("a newcomer measured from the window start", K, "\t\t\t\t\tif num(snaps[i].D[p]) <= b0 then since = snaps[i].At end\n", ""),
    ("the first count after 2 s", K, "\tb.CrowdAt = now + math.max(0.5, num(crowd and crowd.Every, 2))", "\tb.CrowdAt = now + 2"),
    ("reward bar on raw damage", "MONSTER_SOURCE", "\t\t\tif shareOf(p) >= minFrac - 1e-9 then", "\t\t\tif (tonumber(rec._dmg[p]) or 0) >= minFrac * rec.MaxHP then"),
    ("side share on raw damage", "MONSTER_SOURCE", "sideDmg[f] += math.max(0, shareOf(p))", "sideDmg[f] += math.max(0, tonumber(rec._dmg[p]) or 0)"),
    ("no share kept", "MONSTER_SOURCE", "\t\t\trecord._share[player] = (record._share[player] or 0) + dealt / math.max(1, tonumber(record.MaxHP) or 1)\n", ""),
    ("share against the solo HP", "MONSTER_SOURCE", "dealt / math.max(1, tonumber(record.MaxHP) or 1)", "dealt / math.max(1, tonumber(record.Def.HP) or 1)"),
    ("no fallback without _share", "MONSTER_SOURCE", "\t\tif type(s) ~= \"number\" then s = (tonumber(rec._dmg[p]) or 0) / math.max(1, tonumber(rec.MaxHP) or 1) end\n",
     "\t\tif type(s) ~= \"number\" then s = 0 end\n"),
    ("SoloSeconds ignored", K, "math.max(1, num(c.SoloSeconds, 120))", "60"),
    ("radius ignored", K, "if r and Util.FlatDistance(r.Position, pos) <= radius then", "if r then"),
    ("the dead count", K, "S.PlayerService.IsReady(p) and Util.IsAlive(p)", "S.PlayerService.IsReady(p)"),
    ("not-ready hunters count", K, "S.PlayerService.IsReady(p) and Util.IsAlive(p)", "Util.IsAlive(p)"),
    ("gone players count", K, "if recent > 0 and p.Parent ~= nil and", "if recent > 0 and"),
    ("no hunter cap", K, "return math.clamp(math.floor(sum * 10 + 0.5) / 10, 1, math.max(1, num(c.Max, 10)))",
     "return math.max(1, math.floor(sum * 10 + 0.5) / 10)"),
    ("nobody = 0 hunters", K, "return math.clamp(math.floor(sum * 10 + 0.5) / 10, 1,",
     "return math.clamp(math.floor(sum * 10 + 0.5) / 10, 0,"),
    ("the kaiju's 15% hard-coded", K, "math.max(0, num(c.PerHunter, 0.5))", "0.15"),
    ("Every ignored (every 2 s)", K, "\tb.CrowdAt = now + math.max(0.5, num(c.Every, 2))\n\tb.Hunters", "\tb.CrowdAt = now + 2\n\tb.Hunters"),
    ("base from a doubled HP", K, "b.BaseHP, b.Hunters, b.Snaps = math.max(0, num(rec.MaxHP)), 1,",
     "b.BaseHP, b.Hunters, b.Snaps = math.max(0, num(rec.MaxHP)) * 2, 1,"),
    ("old snapshots kept for the next boss", K, "b.BaseHP, b.Hunters, b.Snaps = math.max(0, num(rec.MaxHP)), 1, { { At = now, D = {} } }",
     "b.BaseHP, b.Hunters = math.max(0, num(rec.MaxHP)), 1"),
    ("crowd off everywhere", K, "\tif own == false then return nil end\n", "\tif own ~= false then return nil end\n"),
    ("own crowd table ignored", K, "local c = type(own) == \"table\" and own or FB.Crowd", "local c = FB.Crowd"),
    ("HP fraction not kept", "MONSTER_SOURCE", "\trec.HP = math.max(1, math.floor(frac * maxHP + 0.5))\n",
     "\trec.HP = math.min(rec.HP, maxHP)\n"),
    ("HP may round to 0", "MONSTER_SOURCE", "\trec.HP = math.max(1, math.floor(frac * maxHP + 0.5))\n",
     "\trec.HP = math.floor(frac * maxHP + 0.5)\n"),
    ("HP always rounded up", "MONSTER_SOURCE", "\trec.HP = math.max(1, math.floor(frac * maxHP + 0.5))\n",
     "\trec.HP = math.max(1, math.ceil(frac * maxHP))\n"),
    ("no bar update", "MONSTER_SOURCE", "\trec.HP = math.max(1, math.floor(frac * maxHP + 0.5))\n\tupdateBar(rec)\n",
     "\trec.HP = math.max(1, math.floor(frac * maxHP + 0.5))\n"),
    ("any monster's MaxHP", "MONSTER_SOURCE",
     "\tif type(rec) ~= \"table\" or rec.Event ~= true or not rec.Alive then return false end\n\tif type(maxHP)",
     "\tif type(rec) ~= \"table\" or not rec.Alive then return false end\n\tif type(maxHP)"),
    ("bad MaxHP taken", "MONSTER_SOURCE", "maxHP ~= maxHP or maxHP <= 0 or maxHP == math.huge then return false end",
     "maxHP ~= maxHP then return false end"),
    ("totals = the live table", "MONSTER_SOURCE",
     "\tif type(rec) ~= \"table\" or type(rec._dmg) ~= \"table\" then return out end\n",
     "\tif type(rec) ~= \"table\" or type(rec._dmg) ~= \"table\" then return out end\n\tif true then return rec._dmg end\n"),
    ("zero damage in the totals", "MONSTER_SOURCE", "type(d) == \"number\" and d > 0 then out[p] = d end",
     "type(d) == \"number\" then out[p] = d end"),
    ("King HP 2000 (T1 / T2 mean)", C, "HP = 2600, Damage = 6, XP = 120", "HP = 2000, Damage = 6, XP = 120"),
    ("Clatter HP 9000 (T3+0)", C, "AnimFrom = \"SkeletonKnight\", HP = 20000,", "AnimFrom = \"SkeletonKnight\", HP = 9000,"),
    ("crowd +15%", C, "Crowd = { PerHunter = 0.5, Max = 10,", "Crowd = { PerHunter = 0.15, Max = 10,"),
    ("crowd window 60 s", C, "Radius = 50, Window = 15, Every = 0.5,", "Radius = 50, Window = 60, Every = 0.5,"),
    ("crowd every 2 s", C, "Window = 15, Every = 0.5, Rise = 2,", "Window = 15, Every = 2, Rise = 2,"),
    ("crowd rise 15 s", C, "Every = 0.5, Rise = 2, SoloSeconds = 120 },", "Every = 0.5, Rise = 15, SoloSeconds = 120 },"),
    ("solo pace 60 s", C, "Rise = 2, SoloSeconds = 120 },", "Rise = 2, SoloSeconds = 60 },"),
    ("retry King capped by the field King", C, "math.max(R.MinHP, tonumber(R.MaxHP) or 2500))", "math.max(R.MinHP, Config.MonsterTypes[FK.Kind].HP))"),
]


def static() -> tuple[int, list[str]]:
    count, failures = 0, []

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    king = read(SSS / "FieldBossService.luau")
    check("task.wait(" in king and "wait(" not in king.replace("task.wait(", ""), "task.wait only")
    check("<const>" not in king, "no <const>")
    for name in ("Spawn", "Interval", "Lifetime", "FirstDelay", "Attr", "Hill"):
        check(f"c.{name}" in king, f"reads Config.FieldBosses[key].{name}")
    check(not (SSS / "SlimeKingService.luau").exists(), "SlimeKingService.luau is gone (FieldBossService took it over)")
    everything = "".join(read(p) for p in (ROOT / "src").rglob("*.luau"))
    check("SlimeKingService" not in everything.replace("SlimeKingService 2026-10-08", ""),
          "nothing requires the old SlimeKingService")
    check("\"BigSlime\"" in read(SSS / "QuestService.luau") or "BigSlime" in everything,
          "the Slime Prince quests keep the BigSlime id")
    # A23-113 ⑦: only the field bosses change MaxHP; the first KO's personal King keeps its own numbers
    check("SetEventMaxHP" not in read(SSS / "FirstKOService.luau") and "SetEventMaxHP" not in read(SSS / "HalloweenService.luau"),
          "only FieldBossService sets a crowd MaxHP (not the first-KO King, not the Halloween kings)")
    check("CROWD.Tick(key, now)" in king and "S.MonsterService.SetEventMaxHP" in king and "svc.DamageTotals" in king,
          "FieldBossService counts hunters and sets the MaxHP through MonsterService")
    return count, failures


SUITE = Suite(
    mark="FIELDBOSS",
    fixture=ROOT / "tools/fixtures/field_boss_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-11/offline_dev2_field_boss_2026-10-11.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="Field bosses (Config.FieldBosses; the King Slime A23-84/85, king_slime_split §3): one of each on the "
             "server, first slot FirstDelay s after start, then every Interval s from its last appearance, a due slot "
             "waits for a ready hunter in its zone, stays Lifetime s; spot Attr on workspace.Map > (Hill) HillTop + 8 "
             "toward HillPathFoot (flat) > Spawn > a zone spawn point, Radius; no ground = retry in RetryDelay s; defeat "
             "= Fx KingDefeat { Key, Kind, Pos, Contributors (numbers) } to all + <Key>Defeat + Defeated(key, kind, ids, "
             "rec); time up / lost model = RemoveEvent(fade, leaving) + <Key>Leave; GameState <Key>Active / EndsAt / "
             "NextAt. King Slime: 180 / 480 / 300 s, KingSpawn, hill. BigSlime = Slime Prince; the card is SlimeKing's. "
             "A23-113 ⑦ crowd HP (+ 검수 bosshp_verify fixes): def HP = one hunter about 2 min (King 2600 Lv 5-8 T2, Clatter 20000 Lv25 T4, by the "
             "solo DPS model on the current Config); every 0.5 s hunters = the shares added up (in tenths, 1..10) of the "
             "ready, alive players within 50 studs: own damage over the last 15 s / one hunter's pace (def HP / 120 s) over "
             "the time since its first hit in the window (at least Rise 2 s: comes fast, fades slow, no on / off gain), at "
             "most 1 (ByDamage = false: 1 each); MaxHP = def HP x (1 + 0.5 x (hunters - 1)), the HP fraction kept "
             "(MonsterService.SetEventMaxHP: event monsters only, rounded, never below 1 HP; DamageTotals = a copy); a "
             "boss's own Crowd wins, false = off. The reward bar and the side share read each hit as a share of the MaxHP "
             "it had then (MonsterService _share; no _share = damage / MaxHP). The retry King's cap is Retry.MaxHP (2500).",
    limitations="MonsterService (SpawnEvent ground pick, kill payout, model borrow), PlayerService, ZoneService and "
                "AnnounceService are doubles; the client (boss chip, minimap icon) and the shrine placement are not here. "
                "The solo DPS model is an average (75% uptime, no perks / enhancement / pets); real fight times need play.",
)

if __name__ == "__main__":
    run(SUITE)
