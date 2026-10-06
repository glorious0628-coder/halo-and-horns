"""Halloween season (Config.Halloween, 2026-10-06): run the current sources offline.

Runs the CURRENT Config, Net, Util, DataService, QuestService, StoryQuestService, LootService, AnnounceService,
HalloweenService, Main.server.luau and the client Announce module, plus chunks cut from MonsterService (event spawn /
kill / A23-27 contributor hits and damage + payout / regular pool + GlobalCap split + HW-13 season-end sweep / golden
roll / death pop and leave fade / targetable + landAttack: the A23-27 king safety rule), EventHUD (the Pumpkin King pill,
never narrower than its text, and its placement beside HUD's columns), Fx (WOBBLE float, grounded slime hop + Sink, blob
shadows and landing dust, leaving king without the splat) and Panels (drop list loop), and the BatGoblin / Goblin
MonsterAnims clip modules. Every Config copy reads a pinned server clock (Config.SeasonNow), so the A23-28 season end
(Config.Halloween.EndsAt) is checked at EndsAt - 1 / EndsAt / EndsAt + 1 without depending on the machine's date. Everything is injected into
tools/fixtures/halloween_offline.luau and run with the installed official Luau CLI (build/luau_cli_0_741). No Studio,
network, DataStore or Roblox API calls. Every check is named and collected. A mutation step then breaks in-memory copies
of the sources (never src/), runs them from a temporary directory and counts how many mutations the checks catch.
A static step regenerates the five BatGoblin clips from their GLB files with tools/glb_anim_to_luau.py (into a
temporary folder) and compares them byte for byte, and checks the GLB skeletons.

Usage: py tools/test_halloween.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/offline_halloween_2026-10-06.json
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import re
import struct
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tools/fixtures/halloween_offline.luau"
OUT = ROOT / "docs/art/verification_2026-10-06/offline_halloween_2026-10-06.json"
SSS = ROOT / "src/ServerScriptService"
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
ANIMS = ROOT / "src/ReplicatedStorage/MonsterAnims"
CLIP_NAMES = ("Idle", "Walk", "Slash", "Hurt", "Fall")
FILES = {
    "CONFIG_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
    "NET_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Net.luau",
    "UTIL_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Util.luau",
    "DATA_SOURCE": SSS / "DataService.luau",
    "QUEST_SOURCE": SSS / "QuestService.luau",
    "STORY_SOURCE": SSS / "StoryQuestService.luau",
    "LOOT_SOURCE": SSS / "LootService.luau",
    "ANNOUNCE_SOURCE": SSS / "AnnounceService.luau",
    "HALLOWEEN_SOURCE": SSS / "HalloweenService.luau",
    "MAIN_SOURCE": SSS / "Main.server.luau",
    "MONSTER_SOURCE": SSS / "MonsterService.luau",
    "ANNOUNCE_CLIENT_SOURCE": SPS / "Announce.luau",
    # only chunks of these are injected (make_harness); the whole files are hashed and mutated
    "EVENTHUD_SOURCE": SPS / "EventHUD.luau",
    "FX_SOURCE": SPS / "Fx.luau",
    "PANELS_SOURCE": SPS / "Panels.luau",
}
for _clip in CLIP_NAMES:
    FILES[f"CLIP_BatGoblin_{_clip}"] = ANIMS / f"BatGoblin_{_clip}.luau"
    FILES[f"CLIP_Goblin_{_clip}"] = ANIMS / f"Goblin_{_clip}.luau"
EXTRACTED_ONLY = ("EVENTHUD_SOURCE", "FX_SOURCE", "PANELS_SOURCE")
STATIC_ONLY = {
    "MONSTER_MOTION": SPS / "MonsterMotion.luau",
    "HUD": SPS / "HUD.luau",
    "CLIENT_MAIN": SPS / "ClientMain.client.luau",
    "CONVERTER": ROOT / "tools/glb_anim_to_luau.py",
}
# the five clips and the GLB part they were cut from (the same parts the Goblin clips use, 15 fps)
CLIP_ARGS = {
    "Idle": ["--loop", "--from", "0", "--to", "2.0667"],
    "Walk": ["--loop", "--from", "0", "--to", "2.3333"],
    "Slash": ["--from", "0.9", "--to", "2.9"],
    "Hurt": ["--from", "0", "--to", "1.0"],
    "Fall": ["--from", "0", "--to", "3.0"],
}
# files the Halloween change touched (line endings must stay one style per file)
EOL_FILES = [FILES[k] for k in ("CONFIG_SOURCE", "NET_SOURCE", "QUEST_SOURCE", "STORY_SOURCE", "ANNOUNCE_SOURCE",
                                "HALLOWEEN_SOURCE", "MAIN_SOURCE", "MONSTER_SOURCE", "ANNOUNCE_CLIENT_SOURCE",
                                "EVENTHUD_SOURCE", "FX_SOURCE", "PANELS_SOURCE")] + [ANIMS / f"BatGoblin_{c}.luau" for c in CLIP_NAMES] + [
    SPS / "HUD.luau"]

# (name, source key, exact text, replacement): each must match exactly once in the current (LF-normalized) source
MUTATIONS = [
    # A23-45 one family per field: pumpkins in the patch, ghosts in the hollow, bat goblins take 3 goblin slots (as goblins)
    ("a Halloween kind back in the meadow (PumpkinSlime Zone = SlimeMeadow)", "CONFIG_SOURCE",
     "Zone = \"PumpkinPatch\", Count = 10, QuestAs = \"Slime\",", "Zone = \"SlimeMeadow\", Count = 10, QuestAs = \"Slime\","),
    ("bat goblin stops taking goblin slots (woods density changes)", "CONFIG_SOURCE",
     "Count = 3, Takes = { Goblin = 3 }, QuestAs = \"Goblin\",", "Count = 3, QuestAs = \"Goblin\","),
    ("bat goblin counts as itself (QuestAs dropped)", "CONFIG_SOURCE",
     "Takes = { Goblin = 3 }, QuestAs = \"Goblin\",", "Takes = { Goblin = 3 },"),
    ("ghosts back in the pumpkin patch (LittleGhost Zone)", "CONFIG_SOURCE",
     "LittleGhost = { Name = \"Little Ghost\", Short = \"Little Ghost\", Zone = \"HauntedHollow\",",
     "LittleGhost = { Name = \"Little Ghost\", Short = \"Little Ghost\", Zone = \"PumpkinPatch\","),
    ("ghost king due with the pumpkin king (FirstDelay 360)", "CONFIG_SOURCE",
     "{ Kind = \"GhostKing\", Key = \"GhostKing\", FirstDelay = 960,", "{ Kind = \"GhostKing\", Key = \"GhostKing\", FirstDelay = 360,"),
    ("PumpkinPatch land detached from the meadow (MinZ 180)", "CONFIG_SOURCE",
     "MinX = 280, MaxX = 440, MinZ = 175,", "MinX = 280, MaxX = 440, MinZ = 180,"),
    ("PumpkinPatch exists with the season off (ZoneAt ignores Season)", "CONFIG_SOURCE",
     "(z.Season == nil or Config.SeasonOn(z.Season))", "true"),
    ("seasonal kinds counted with the season off", "CONFIG_SOURCE",
     "out[kind] = Config.MonsterActive(kind, seasonOn) and math.max(0, math.floor(tonumber(def.Count) or 0)) or 0",
     "out[kind] = math.max(0, math.floor(tonumber(def.Count) or 0))"),
    ("patch kinds counted inside the GlobalCap", "CONFIG_SOURCE",
     "return type(def) == \"table\" and def.Season ~= nil and type(def.Takes) ~= \"table\"", "return false"),
    ("generic Takes: slice not taken from the base kind's growth", "CONFIG_SOURCE",
     "out[base] = math.max(0, out[base] - p)", "out[base] = math.max(0, out[base])"),
    ("generic Takes: takers get their own cap share", "CONFIG_SOURCE",
     "if type(only) == \"string\" and Config.MonsterTypes[only] ~= nil then return only end", ""),
    ("QuestKind ignores QuestAs", "CONFIG_SOURCE", "\t\treturn def.QuestAs\n", "\t\treturn kind\n"),
    # A23-28 HW-13 season end by the server clock
    ("season flag ignored (Enabled)", "CONFIG_SOURCE",
     "if type(s) ~= \"table\" or s.Enabled ~= true then return false end", "if type(s) ~= \"table\" then return false end"),
    ("season never ends (EndsAt check dropped in Config.SeasonOn)", "CONFIG_SOURCE",
     "return type(s.EndsAt) ~= \"number\" or Config.SeasonNow() < s.EndsAt", "return true"),
    ("season still on at EndsAt (<=)", "CONFIG_SOURCE", "Config.SeasonNow() < s.EndsAt", "Config.SeasonNow() <= s.EndsAt"),
    ("SeasonNow ignores the server clock", "CONFIG_SOURCE",
     "local ok, t = pcall(function() return workspace:GetServerTimeNow() end)", "local ok, t = false, nil"),
    ("season end moved a day (EndsAt)", "CONFIG_SOURCE", "EndsAt = 1794150000,", "EndsAt = 1794236400,"),
    ("HalloweenService ignores the season (Enabled / EndsAt)", "HALLOWEEN_SOURCE",
     "local function seasonOn()\n\treturn Config.SeasonOn(\"Halloween\")", "local function seasonOn()\n\treturn true"),
    ("king stays after the season ends ('not on' dropped in tick)", "HALLOWEEN_SOURCE",
     "elseif now >= b.EndsAt or (not on and not b.Debug) then", "elseif now >= b.EndsAt then"),
    ("season end leaves the countdown up (NextAt not cleared)", "HALLOWEEN_SOURCE",
     "if not on and b.NextAt > 0 then", "if false then"),
    ("off-season debug king sent home at once (b.Debug never set)", "HALLOWEEN_SOURCE",
     "b.Debug = ok and not seasonOn() or nil", "b.Debug = nil"),
    ("patch sign stays after the season", "HALLOWEEN_SOURCE",
     "d.Transparency = on and (d:GetAttribute(\"ShownTransparency\") or 0) or 1",
     "d.Transparency = (d:GetAttribute(\"ShownTransparency\") or 0)"),
    ("season-end sweep dropped (reevaluate)", "MONSTER_SOURCE", "for _, rec in gone do despawn(rec, true, true) end", ""),
    ("season-end sweep splats (no leaving fade)", "MONSTER_SOURCE",
     "for _, rec in gone do despawn(rec, true, true) end", "for _, rec in gone do despawn(rec, true) end"),
    ("season-end sweep also takes the event king", "MONSTER_SOURCE",
     "if rec.Alive and rec.Owner == nil and not rec.Event and not Config.MonsterActive(rec.Kind) then",
     "if rec.Alive and rec.Owner == nil and not Config.MonsterActive(rec.Kind) then"),
    # the season, the slime jackpot, the king's numbers and rows (A23-27)
    ("pumpkin slime loses the slime jackpot", "CONFIG_SOURCE",
     "Monsters = { Slime = true, PumpkinSlime = true }", "Monsters = { Slime = true }"),
    ("Pumpkin King HP tripled", "CONFIG_SOURCE", "HP = 9000, Damage = 8, XP = 300, Gold = 150, Speed = 7, Shape = \"Slime\"",
     "HP = 27000, Damage = 8, XP = 300, Gold = 150, Speed = 7, Shape = \"Slime\""),
    ("king scroll row back to 0.5 (Enh70)", "CONFIG_SOURCE",
     "A23-27 rows)\n\t\t\t{ Item = \"Candy\", P = 1, N = 8 },\n\t\t\t{ Item = \"Enh70\", P = 0.25 }",
     "A23-27 rows)\n\t\t\t{ Item = \"Candy\", P = 1, N = 8 },\n\t\t\t{ Item = \"Enh70\", P = 0.5 }"),
    ("ghost king candy cut to 2 (its table = the pumpkin king's)", "CONFIG_SOURCE",
     "same size)\n\t\t\t{ Item = \"Candy\", P = 1, N = 8 },", "same size)\n\t\t\t{ Item = \"Candy\", P = 1, N = 2 },"),
    ("king weapon row pays 1 candy below MinLevel", "CONFIG_SOURCE",
     "BelowLevel instead\n\t\t\t{ Weapon = 4, P = 0.05, BelowLevel = { Item = \"Candy\", N = 3 } },",
     "BelowLevel instead\n\t\t\t{ Weapon = 4, P = 0.05, BelowLevel = { Item = \"Candy\", N = 1 } },"),
    ("king's RewardMinHits removed from Config", "CONFIG_SOURCE",
     "RewardMinHits = 3, RewardMinDamageFrac = 0.005, XPCapBelowLevel = 8,\n\t\tHP = 9000",
     "RewardMinDamageFrac = 0.005, XPCapBelowLevel = 8,\n\t\tHP = 9000"),
    ("king safe only below Lv4 (SafeBelowLevel)", "CONFIG_SOURCE", "SafeBelowLevel = 5,", "SafeBelowLevel = 4,"),
    ("king safety playtime 60 s (SafePlaySeconds)", "CONFIG_SOURCE", "SafePlaySeconds = 600,", "SafePlaySeconds = 60,"),
    ("patch sign names the season", "CONFIG_SOURCE",
     "PatchSign = \"↓ Pumpkin Patch · pumpkin monsters\"", "PatchSign = \"↓ Halloween Pumpkin Patch · pumpkin monsters\""),
    # quests / story count Config.QuestKind
    ("killWeight counts a seasonal kind by its own XP", "QUEST_SOURCE", "\tkind = Config.QuestKind(kind)\n", ""),
    ("first mission ignores QuestKind", "QUEST_SOURCE",
     "if cur >= TUT_TARGET or not TUTORIAL_KINDS[Config.QuestKind(info.Kind)] or info.Personal == true",
     "if cur >= TUT_TARGET or not TUTORIAL_KINDS[info.Kind] or info.Personal == true"),
    ("story kill objectives ignore QuestKind", "STORY_SOURCE",
     "Config.QuestKind(info.Kind) ~= obj.Kind", "info.Kind ~= obj.Kind"),
    # the Pumpkin King schedule / leave / announce
    ("first king without the 6-minute delay", "HALLOWEEN_SOURCE",
     "b.NextAt = on and (now + math.max(0, b.FirstDelay)) or 0", "b.NextAt = on and now or 0"),
    ("next king 10 min after an appearance", "HALLOWEEN_SOURCE",
     "if appear(b, now) then\n\t\tb.NextAt = now + b.Interval", "if appear(b, now) then\n\t\tb.NextAt = now + b.Interval / 2"),
    ("king never leaves after its lifetime", "HALLOWEEN_SOURCE",
     "elseif now >= b.EndsAt or (not on and not b.Debug) then", "elseif (not on and not b.Debug) then"),
    ("a lost king is reported as defeated", "HALLOWEEN_SOURCE", "finish(b, num(rec.HP, 1) <= 0)", "finish(b, true)"),
    ("only the first boss runs (Bosses list ignored)", "HALLOWEEN_SOURCE",
     "local list = type(H.Bosses) == \"table\" and H.Bosses or", "local list = false and H.Bosses or"),
    ("leaving king stays in the world", "HALLOWEEN_SOURCE",
     "local ok, err = pcall(svc.RemoveEvent, rec, true, true)", "local ok, err = true, nil"),
    ("leaving king squashes like a kill", "HALLOWEEN_SOURCE",
     "pcall(svc.RemoveEvent, rec, true, true)", "pcall(svc.RemoveEvent, rec, true)"),
    ("leave fade shrinks the king", "MONSTER_SOURCE",
     "local goal = leaving and { Transparency = 1 } or { Size = d.Size * 0.2, Transparency = 1 }",
     "local goal = { Size = d.Size * 0.2, Transparency = 1 }"),
    ("Leaving set after the anchor", "MONSTER_SOURCE",
     "\tif leaving then model:SetAttribute(\"Leaving\", true) end", "\tif false then end"),
    ("Broadcast also sends non-event keys", "ANNOUNCE_SOURCE",
     "if type(A.Events) ~= \"table\" or A.Events[key] == nil then return end", ""),
    # (A23-48: "English twin ignored on the client" dropped: the main and En event lines are the same English now, so
    # the client's twin pick is no longer observable)
    ("PumpkinKing debug key routed nowhere", "MAIN_SOURCE", "return S.HalloweenService.DebugSpawn(key)", "return \"ok\""),
    ("GameState defaults miss the ghost king attributes", "NET_SOURCE",
     "GhostKingNextAt = 0, GhostKingActive = false, GhostKingEndsAt = 0,", "GhostKingNextAt = 0,"),
    ("GameState defaults miss the king attributes", "NET_SOURCE",
     "PumpkinKingNextAt = 0, PumpkinKingActive = false, PumpkinKingEndsAt = 0,", "PumpkinKingNextAt = 0,"),
    # regular pool / cap (MonsterService)
    ("patch kinds wait for room under the cap", "MONSTER_SOURCE",
     "while have < target and (outside or total < GLOBAL_CAP) and", "while have < target and total < GLOBAL_CAP and"),
    ("event king and Halloween kinds counted toward the global cap", "MONSTER_SOURCE",
     "if rec.Alive and rec.Owner == nil and not rec.Event and not Config.MonsterOutsideCap(rec.Kind) then n += 1 end",
     "if rec.Alive and rec.Owner == nil then n += 1 end"),
    ("defeated king respawns", "MONSTER_SOURCE",
     "elseif not rec.Event then\n\t\tscheduleRespawn(rec.Kind)", "else\n\t\tscheduleRespawn(rec.Kind)"),
    # A23-27 rewards: own hits / damage, overkill excluded, the window
    ("king pays only the last 15 s of hitters", "MONSTER_SOURCE",
     "local window = tonumber(def.ContributorWindow) or MC.ContributorWindow", "local window = MC.ContributorWindow"),
    ("king pays one-hit contributors (RewardMinHits ignored)", "MONSTER_SOURCE",
     "local minHits = tonumber(def.RewardMinHits) or 0", "local minHits = 0"),
    ("king pays chip damage (RewardMinDamageFrac ignored)", "MONSTER_SOURCE",
     "local minDamage = (tonumber(def.RewardMinDamageFrac) or 0) * rec.MaxHP", "local minDamage = 0"),
    ("overkill counted as damage", "MONSTER_SOURCE", "math.min(amount, math.max(0, record.HP))", "amount"),
    ("hits not counted per hit", "MONSTER_SOURCE",
     "record._hits[player] = (record._hits[player] or 0) + 1", "record._hits[player] = 1"),
    ("3 hits not enough (> RewardMinHits)", "MONSTER_SOURCE", "(rec._hits[p] or 0) >= minHits", "(rec._hits[p] or 0) > minHits"),
    ("exactly 0.5% of MaxHP not enough (> minDamage)", "MONSTER_SOURCE",
     "(rec._dmg[p] or 0) >= minDamage", "(rec._dmg[p] or 0) > minDamage"),
    # A23-27 king safety (MonsterService targetable / landAttack)
    ("every monster spares new players (Boss check dropped)", "MONSTER_SOURCE",
     "if def and def.Boss and typeof(info.Player) == \"Instance\" then", "if def and typeof(info.Player) == \"Instance\" then"),
    ("king also spares Lv5 (<= SafeBelowLevel)", "MONSTER_SOURCE",
     "lv < (tonumber(H.SafeBelowLevel) or 0)", "lv <= (tonumber(H.SafeBelowLevel) or 0)"),
    ("king also spares a 600 s player (<= SafePlaySeconds)", "MONSTER_SOURCE",
     "played < (tonumber(H.SafePlaySeconds) or 0)", "played <= (tonumber(H.SafePlaySeconds) or 0)"),
    ("king ignores the playtime rule", "MONSTER_SOURCE", " or played < (tonumber(H.SafePlaySeconds) or 0)", ""),
    ("king spares the PvP Rookie shield again", "MONSTER_SOURCE",
     "if lv < (tonumber(H.SafeBelowLevel) or 0) or",
     "if info.Player:GetAttribute(\"Rookie\") == true or lv < (tonumber(H.SafeBelowLevel) or 0) or"),
    ("landAttack checks its target without the Player", "MONSTER_SOURCE",
     "local info = { Player = target, Pos = tpos,", "local info = { Pos = tpos,"),
    # monsters face their target (user 2026-10-06): smooth turn, +-30 deg hit cone, recheck, keep rules
    ("monsters snap to the target (no per-frame turn cap)", "MONSTER_SOURCE",
     "cur + math.clamp(diff, -stepMax, stepMax)", "cur + diff"),
    ("monsters turn the long way round", "MONSTER_SOURCE",
     "(math.atan2(-dir.X, -dir.Z) - cur + math.pi) % (2 * math.pi) - math.pi", "(math.atan2(-dir.X, -dir.Z) - cur)"),
    ("the hit lands while the target is behind (cone check dropped)", "MONSTER_SOURCE",
     "if FACE.Cos(root, tpos) < FACE.HitCos then", "if false then"),
    ("hit cone widened to +-60 deg", "MONSTER_SOURCE",
     "HitCos = math.cos(math.rad(30)),", "HitCos = math.cos(math.rad(60)),"),
    ("a slow turn always misses (no recheck)", "MONSTER_SOURCE",
     "if waited >= FACE.MaxExtra then return cancel() end", "do return cancel() end"),
    ("a turn that never comes waits forever (MaxExtra ignored)", "MONSTER_SOURCE",
     "if waited >= FACE.MaxExtra then return cancel() end", "if false then return cancel() end"),
    ("facing never ends after the last renewal", "MONSTER_SOURCE",
     "and (now < f.Until or rec._windup ~= nil)", "and true"),
    ("facing drops during the wind-up", "MONSTER_SOURCE",
     "and (now < f.Until or rec._windup ~= nil)", "and now < f.Until"),
    ("an anchored (dying) monster still turns", "MONSTER_SOURCE",
     "root ~= nil and root.Parent ~= nil and not root.Anchored", "root ~= nil and root.Parent ~= nil"),
    ("the wind-up stops renewing the facing (attack)", "MONSTER_SOURCE",
     "FACE.Active[rec] = { Target = info.Player, Until = os.clock() + FACE.Keep }", ""),
    ("turn speed halved (300 deg/s)", "MONSTER_SOURCE", "TurnRate = math.rad(600),", "TurnRate = math.rad(300),"),
    # monster naturalness (user 2026-10-06 "너무 경직된 느낌", survey 4-1): pace / ease-in / alert / look-around / body hold
    ("wander walks at the chase speed", "MONSTER_SOURCE", "WanderPace = 0.5,", "WanderPace = 1,"),
    ("no ease-in from standing", "MONSTER_SOURCE", "RampStart = 0.45,", "RampStart = 1,"),
    ("a wander never slows near its goal", "MONSTER_SOURCE",
     "arrive = math.clamp(Util.FlatDistance(root.Position, goal) / NATURAL.ArriveSlow, 0.5, 1)", "arrive = 1"),
    ("no alert pause before a chase", "MONSTER_SOURCE",
     "rec._alertUntil = now + NATURAL.AlertHold", "rec._alertUntil = now"),
    ("the alert repeats for the same player", "MONSTER_SOURCE",
     "if seen == nil or now - seen > NATURAL.AlertAgain then", "if true then"),
    ("the alert also stops a monster already in reach", "MONSTER_SOURCE",
     "if rec._target ~= info.Player and dist > MC.AttackRange then", "if rec._target ~= info.Player then"),
    ("the alert sends no AlertAt (no '!')", "MONSTER_SOURCE",
     "if rec.Model then rec.Model:SetAttribute(\"AlertAt\", workspace:GetServerTimeNow()) end", ""),
    ("a walking monster looks around", "MONSTER_SOURCE",
     "if v.X * v.X + v.Z * v.Z >= 0.25 or FACE.Active[rec] ~= nil or now < (rec._lookAt or 0) then return false end",
     "if FACE.Active[rec] ~= nil or now < (rec._lookAt or 0) then return false end"),
    ("a look-around ignores its slow rate", "MONSTER_SOURCE",
     "pcall(FACE.Turn, root, goal, math.min(dt, 0.1), f.Rate)", "pcall(FACE.Turn, root, goal, math.min(dt, 0.1))"),
    ("a player near an idle monster gets no glance", "MONSTER_SOURCE",
     "if Util.FlatDistance(pos, info.Pos) <= NATURAL.GlanceRange then", "if false then"),
    ("a killed monster vanishes at once again (0.4 s)", "MONSTER_SOURCE",
     "local DEATH_DESTROY = 1.15\n", "local DEATH_DESTROY = 0.4\n"),
    ("the body shrinks at once (no hold before the fade)", "MONSTER_SOURCE",
     "local hold = leaving and 0 or math.max(0, DEATH_DESTROY - DEATH_FADE - 0.1)", "local hold = 0"),
    # Fx WOBBLE: float, grounded slimes, blob shadows, dust (71c10bd / f965cd0)
    ("ghost walks on the floor (Float ignored)", "FX_SOURCE",
     "Float = (float and float > 0 and def.Shape ~= \"Slime\") and float or nil,", "Float = nil,"),
    ("leaving slime still splats", "FX_SOURCE",
     "\n\t\t\t\tand model:GetAttribute(\"Leaving\") ~= true then", " then"),
    ("slime hop not capped at HopMax", "FX_SOURCE",
     "local hopMax = math.min(st.H * WOBBLE.HopRatio, WOBBLE.HopMax)", "local hopMax = st.H * WOBBLE.HopRatio"),
    ("slime sits on the ground surface (no Sink)", "FX_SOURCE",
     "-(hop + (sy - 1) * half) + WOBBLE.Sink, 0)", "-(hop + (sy - 1) * half), 0)"),
    ("slime shadow does not shrink in the air", "FX_SOURCE",
     "WOBBLE.placeShadow(model, st.Root, st, pop * (hopMax > 0 and 1 - 0.35 * (hop / hopMax) or 1))",
     "WOBBLE.placeShadow(model, st.Root, st, pop)"),
    ("ghost shadow full size", "FX_SOURCE", "if faint then d *= 0.65 end", ""),
    ("ghost shadow not fainter", "FX_SOURCE",
     "Transparency = faint and math.min(0.95, ring[2] + 0.08) or ring[2],", "Transparency = ring[2],"),
    ("anchored (dying) monster keeps its shadow", "FX_SOURCE",
     "if sroot and not sroot.Anchored and not foreign and", "if sroot and not foreign and"),
    ("shadow ignores WOBBLE.Range", "FX_SOURCE", "and (sroot.Position - camPos).Magnitude <= WOBBLE.Range then", "then"),
    ("shadow kept after the model leaves", "FX_SOURCE",
     "WOBBLE.State[model] = nil\n\t\t\tWOBBLE.dropShadow(model)", "WOBBLE.State[model] = nil"),
    ("pop-in slime shadow measured at its first-frame size", "FX_SOURCE", "if st and st.Slime and st.Base then", "if false then"),
    ("foreign monster gets a shadow and dust", "FX_SOURCE",
     "local foreign = sroot ~= nil and Feel.isForeign(model)", "local foreign = false"),
    ("foreign slime puffs landing dust", "FX_SOURCE",
     "if lastS > 0 and s <= 0 and not foreign and", "if lastS > 0 and s <= 0 and"),
    # EventHUD Pumpkin King pill (f0e011a)
    ("HUD shows the countdown while the king is here", "EVENTHUD_SOURCE",
     "local k = active and keys[2] or keys[1]", "local k = keys[1]"),
    ("pill measured from the screen edge (ignores HUD's left column)", "EVENTHUD_SOURCE",
     "local room = x0 - gap - math.max(gap, num(hl.LeftX))", "local room = x0 - gap - gap"),
    ("right slot ignores the kaiju pill", "EVENTHUD_SOURCE",
     "local kaiju = (ui.KaijuChip and ui.KaijuChip.Visible) and (KAIJU_CHIP_W + gap) or 0", "local kaiju = 0"),
    ("right slot ignores HUD's button cluster", "EVENTHUD_SOURCE",
     "if room >= minW and not blocked then", "if room >= minW then"),
    ("pill squeezed below its text width (KING.need ignored)", "EVENTHUD_SOURCE",
     "local minW, maxW = math.max(L.KingMinW, need), math.max(L.KingW, need)", "local minW, maxW = L.KingMinW, L.KingW"),
    ("pill under the chips leaves the personal line in place", "EVENTHUD_SOURCE",
     "\tKING.setBelow(below)\nend", "\tKING.setBelow(false)\nend"),
    ("bat goblin slash loops", "CLIP_BatGoblin_Slash", "Loop = false", "Loop = true"),
]


def literal(value: str) -> str:
    eq = "===="
    while "]" + eq + "]" in value:
        eq += "="
    return "[" + eq + "[" + value + "]" + eq + "]"


def between(text: str, start: str, end: str) -> str:
    first = text.find(start)
    last = text.find(end, first + len(start)) if first >= 0 else -1
    if first < 0 or last < 0:
        raise ValueError(f"Source boundary changed: {start!r} / {end!r}; update the test extractor.")
    return text[first:last]


def function_block(text: str, start: str) -> str:
    """`start` up to and including the first top-level `end` line after it (a whole function)."""
    first = text.find(start)
    last = text.find("\nend\n", first) if first >= 0 else -1
    if first < 0 or last < 0:
        raise ValueError(f"Source boundary changed: {start!r}; update the test extractor.")
    return text[first:last + 5]


def make_harness(sources: dict[str, str]) -> str:
    bindings = {k: v for k, v in sources.items() if k not in EXTRACTED_ONLY and not k.startswith("CLIP_")}
    mon = sources["MONSTER_SOURCE"]
    counting = between(mon, "local function aliveCountOf(kind)", "local function playersPerZone()")
    # event spawn / removal, kill + contributor payout, damage (MonsterService.SpawnEvent / RemoveEvent / killRecord)
    bindings["MONSTER_EVENTS_SOURCE"] = (
        "local Config, Util, MC, MonsterService, H = ...\n"
        "local records, pending = H.records, H.pending\n"
        "local SPAWN_TRIES = H.SPAWN_TRIES\n"
        "local groundPoint, pickSpawnPoint, spawnMonster, warnThrottled = H.groundPoint, H.pickSpawnPoint, H.spawnMonster, H.warnThrottled\n"
        "local updateBar, deathPop, factionOf, removePersonalRef = H.updateBar, H.deathPop, H.factionOf, H.removePersonalRef\n"
        "local markHurt, zoneIdOf, scheduleRespawn = H.markHurt, H.zoneIdOf, H.scheduleRespawn\n"
        + counting
        + function_block(mon, "local function despawn(") + "\n"
        + between(mon, "local function killRecord(rec)", "-- A15: pain reaction for clients")
        + function_block(mon, "function MonsterService.DamageMonster(") + "\n"
        + between(mon, "------------------------------------------------------------------ event monsters",
                  "------------------------------------------------------------------ personal monsters")
        + "return { killRecord = killRecord, despawn = despawn, aliveCountOf = aliveCountOf, totalNonPersonal = totalNonPersonal }\n")
    per_pass = re.search(r"local MAX_SPAWNS_PER_KIND_PER_PASS = (\d+)", mon)
    if not per_pass:
        raise ValueError("MAX_SPAWNS_PER_KIND_PER_PASS missing; update the test extractor.")
    # the regular pool: GLOBAL_CAP, per-kind targets with the GLOBAL_CAP split, re-evaluation and the Start() spawn loop
    bindings["MONSTER_POOL_SOURCE"] = (
        "local Config, Util, MC, H = ...\n"
        "local DENSITY = Config.MonsterDensity or {}\n"
        "local records, pending = H.records, H.pending\n"
        f"local MAX_SPAWNS_PER_KIND_PER_PASS = {per_pass.group(1)}\n"
        "local spawnMonster, playersPerZone, warnThrottled, despawn = H.spawnMonster, H.playersPerZone, H.warnThrottled, H.despawn\n"
        + between(mon, "local GLOBAL_CAP\n", "\n------------------------------------------------------------------ helpers") + "\n"
        + counting
        + between(mon, "local function targetCount(", "------------------------------------------------------------------ public queries")
        + function_block(mon, "local function reevaluate()") + "\n"
        + "local function startSpawn()\n"
        + between(mon, "\tlocal total = 0\n\tlocal counts = Config.EffectiveMonsterCounts()", "\n\ttask.spawn(function()")
        + "\n\treturn total\nend\n"
        + "return { GLOBAL_CAP = GLOBAL_CAP, targetCount = targetCount, cappedTargets = cappedTargets, reevaluate = reevaluate,"
          " startSpawn = startSpawn, aliveCountOf = aliveCountOf, totalNonPersonal = totalNonPersonal }\n")
    # the real death pop (kill: shrink + burst; leaving: "Leaving" attribute, size kept, rise + fade)
    pop_consts = []
    for pattern in (r"^local DEATH_FADE = .*$", r"^local DEATH_DESTROY = .*$", r"^local VISUAL_ROOT_NAME = .*$", r"^local LEAVE = \{.*\}$"):
        m = re.search(pattern, mon, re.M)
        if not m:
            raise ValueError(f"MonsterService constant {pattern!r} missing; update the test extractor.")
        pop_consts.append(m.group(0))
    bindings["MONSTER_POP_SOURCE"] = (
        "local Config, MC, H = ...\n"
        "local TweenService, emitDeathParticles, task = H.TweenService, H.emitDeathParticles, H.task\n"
        + "\n".join(pop_consts) + "\n"
        + function_block(mon, "local function deathPop(") + "\n"
        + "return deathPop\n")
    # targeting (review 2026-10-06: a boss leaves rookies alone): the real targetable, FACE (user 2026-10-06: monsters
    # turn toward their target, hit only within +-30 deg), landAttack, findInfo and isPlayerInTown with their constants
    target_consts = []
    for pattern in (r"^local OUT_Y = .*$", r"^local ATTACK_SEQ_ATTR = .*$", r"^local HIT_REACT = .*$"):
        m = re.search(pattern, mon, re.M)
        if not m:
            raise ValueError(f"MonsterService constant {pattern!r} missing; update the test extractor.")
        target_consts.append(m.group(0))
    face = re.search(r"^local FACE = \{.*?Active = \{\} \}$", mon, re.M | re.S)
    if not face:
        raise ValueError("MonsterService FACE table missing; update the test extractor.")
    target_consts.append(face.group(0))
    natural = re.search(r"^local NATURAL = \{.*?GlanceRange = \d+ \}$", mon, re.M | re.S)
    if not natural:
        raise ValueError("MonsterService NATURAL table missing; update the test extractor.")
    target_consts.append(natural.group(0))
    bindings["MONSTER_TARGET_SOURCE"] = (
        "local Config, Util, MC, H = ...\n"
        "local records, warnThrottled, S = H.records, H.warnThrottled, H.S\n"
        + "\n".join(target_consts) + "\n"
        + between(mon, "local REACT = {", "\n}\n") + "\n}\n"
        + function_block(mon, "local function isPlayerInTown(") + "\n"
        + function_block(mon, "local function findInfo(") + "\n"
        + between(mon, "local function targetable(rec, info)", "-- in reach: stand still")
        + "return { targetable = targetable, landAttack = landAttack, findInfo = findInfo, OUT_Y = OUT_Y, FACE = FACE,"
          " NATURAL = NATURAL }\n")
    bindings["MONSTER_GOLDEN_SOURCE"] = (
        "local Config, Util, MC = ...\nreturn function(kind, opts)\n\tlocal def = Config.MonsterTypes[kind]\n"
        "\tif not def then return nil end\n\topts = opts or {}\n\tlocal owner = opts.Owner\n"
        + between(mon, "\tlocal golden\n", "\t-- point is ON the ground") + "\treturn golden\nend\n")
    hud = sources["EVENTHUD_SOURCE"]
    hud_lines = []
    for pattern in (r"^local KAIJU_CHIP_W = .*$", r"^local KING = \{.*\}$"):
        m = re.search(pattern, hud, re.M)
        if not m:
            raise ValueError(f"EventHUD line {pattern!r} missing; update the test extractor.")
        hud_lines.append(m.group(0))
    bindings["KING_HUD_SOURCE"] = (
        "local Config, Util, H = ...\nlocal C = H.C\nlocal ui = H.ui\nlocal IS_TOUCH = H.IsTouch == true\nlocal guiScale = H.guiScale\n"
        "local gameState = nil\nlocal ReplicatedStorage = H.RS\nlocal hudBottom, relayout = H.hudBottom, H.relayout\n"
        + "\n".join(hud_lines) + "\n"
        + between(hud, "local L = {", "\n}\n") + "\n}\n"
        + function_block(hud, "local function num(v)") + "\n"
        + function_block(hud, "local function safeFormat(") + "\n"
        + between(hud, "local function getGameState()", "local function myAttr(")
        + between(hud, "local function setText(label, text)", "local function uiToast(")
        + function_block(hud, "local function currentScale()") + "\n"
        + between(hud, "-- Halloween Pumpkin King line", "-- maxChars: cut longer names")
        + "return KING, L\n")
    fx = sources["FX_SOURCE"]
    bindings["WOBBLE_SOURCE"] = (
        "local Config, H = ...\nlocal C = H.C\nlocal MOTION = H.MOTION\nlocal TweenService = H.TweenService\n"
        "local visualJoint, monsterRoot, monsterSize = H.visualJoint, H.monsterRoot, H.monsterSize\n"
        "local makePart, groundY, burst, Feel = H.makePart, H.groundY, H.burst, H.Feel\n"
        + function_block(fx, "local function isSlimeModel(model)") + "\n"
        + between(fx, "local WOBBLE = {", "-- tweens VisualJoint.C0 through steps")
        + "return WOBBLE\n")
    bindings["PANELS_ITEMS_SOURCE"] = function_block(sources["PANELS_SOURCE"], "BUILDERS.Items = function(parent)")
    head = "\n".join(f"local {key} = {literal(value)}" for key, value in bindings.items())
    clips = ",\n".join(f"\t[\"{key[5:]}\"] = {literal(value)}" for key, value in sources.items() if key.startswith("CLIP_"))
    return head + "\nlocal CLIPS = {\n" + clips + "\n}\n" + FIXTURE.read_text(encoding="utf-8")


def run_harness(binary: Path, harness_text: str, directory: Path, name: str) -> dict:
    path = directory / name
    path.write_text(harness_text, encoding="utf-8")
    proc = subprocess.run([str(binary), str(path)], cwd=ROOT, capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=900)
    result = None
    for line in proc.stdout.splitlines():
        if line.startswith("HALLOWEEN_RESULT_JSON "):
            result = json.loads(line[len("HALLOWEEN_RESULT_JSON "):])
    return {"returncode": proc.returncode, "stdout": proc.stdout, "stderr": proc.stderr, "result": result}


def failing_keys(result: dict | None) -> set[str]:
    if not result:
        return set()
    return {f"{n['Group']} :: {n['Name']}" for n in result.get("Named", []) if n.get("Fail", 0) > 0}


def glb_json(path: Path) -> dict:
    data = path.read_bytes()
    length = struct.unpack("<I", data[12:16])[0]
    return json.loads(data[20:20 + length])


def joint_names(path: Path) -> list[str]:
    gltf = glb_json(path)
    nodes = gltf["nodes"]
    return [nodes[i].get("name", "") for i in gltf["skins"][0]["joints"]]


def static_checks() -> tuple[int, list[str], list[str]]:
    """Checks on files and GLBs that the Luau run cannot reach (never mutated)."""
    failures: list[str] = []
    notes: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    # 1. the five BatGoblin clips regenerate byte for byte from their GLBs with the documented parts (temp folder only)
    spec = importlib.util.spec_from_file_location("glb_anim_to_luau_offline", STATIC_ONLY["CONVERTER"])
    conv = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(conv)
    saved_argv = sys.argv
    with tempfile.TemporaryDirectory(prefix="halloween_clips_") as tmp:
        conv.OUT_DIR = tmp
        try:
            for clip in CLIP_NAMES:
                glb = ROOT / f"art/models/tripo/MonsterBatGoblin_{clip}.glb"
                check(glb.is_file(), f"art/models/tripo/MonsterBatGoblin_{clip}.glb exists")
                if not glb.is_file():
                    continue
                sys.argv = ["glb_anim_to_luau.py", str(glb), "BatGoblin", clip, *CLIP_ARGS[clip]]
                with contextlib.redirect_stdout(io.StringIO()):
                    conv.main()
                fresh = (Path(tmp) / f"BatGoblin_{clip}.luau").read_bytes()
                check(fresh == (ANIMS / f"BatGoblin_{clip}.luau").read_bytes(),
                      f"BatGoblin_{clip}.luau = glb_anim_to_luau.py output of MonsterBatGoblin_{clip}.glb {' '.join(CLIP_ARGS[clip])}")
        finally:
            sys.argv = saved_argv
    # 2. the BatGoblin rig has the Goblin skeleton (same 41 Tripo bone names, same order); every clip bone is on the rig
    bat_glb = ROOT / "art/models/tripo/MonsterBatGoblin_Idle.glb"
    gob_glb = ROOT / "art/models/tripo/MonsterGoblin_Idle.glb"
    bat_joints, gob_joints = joint_names(bat_glb), joint_names(gob_glb)
    check(bat_joints == gob_joints and len(bat_joints) == 41,
          f"BatGoblin GLB skeleton = Goblin GLB skeleton (41 joints, same names/order): {len(bat_joints)} vs {len(gob_joints)}")
    for clip in CLIP_NAMES:
        text = (ANIMS / f"BatGoblin_{clip}.luau").read_text(encoding="utf-8")
        bones = set(re.findall(r'\["([^"]+)"\] = \{ r =', text))
        check(bones and bones <= set(bat_joints), f"BatGoblin_{clip} bones are joints of the BatGoblin rig: {sorted(bones - set(bat_joints))}")
        check(text.startswith(f"-- generated by tools/glb_anim_to_luau.py from art/models/tripo/MonsterBatGoblin_{clip}.glb"),
              f"BatGoblin_{clip} header names its source GLB")
    # 3. one line-ending style per touched file
    for path in EOL_FILES:
        raw = path.read_bytes()
        crlf = raw.count(b"\r\n")
        lf = raw.count(b"\n") - crlf
        check(crlf == 0 or lf == 0, f"{path.relative_to(ROOT).as_posix()} keeps one line-ending style (CRLF {crlf}, LF {lf})")
    # 4. client wiring that the extracted chunks do not show
    motion = STATIC_ONLY["MONSTER_MOTION"].read_text(encoding="utf-8")
    check('local key = kind .. "_" .. name' in motion
          and 'Clips = { "Idle", "Walk", "Run", "LookAround", "Slash", "Hurt", "Fall" }' in motion,
          "MonsterMotion loads ReplicatedStorage.MonsterAnims['<Kind>_<Clip>'] for its clips, Run / LookAround included "
          "(BatGoblin_* are found by kind id; tools/test_monster_motion.py runs the playback rules)")
    hud = FILES["EVENTHUD_SOURCE"].read_text(encoding="utf-8").replace("\r\n", "\n")
    upd = re.search(r"\nlocal function update\(\)\n(.*?)\nend\n", hud, re.S)
    check(upd is not None and "KING.update(now)" in upd.group(1), "EventHUD update() refreshes the Pumpkin King pill every tick")
    lay = re.search(r"\nlayout = function\(\)\n(.*?)\nend\n", hud, re.S)
    check(lay is not None and "if KING.Below then personalY += L.PillH + L.StripGap end" in lay.group(1)
          and "tostring(KING.Below)" in lay.group(1),
          "EventHUD layout(): the touch personal line moves one row down while the king pill sits under the chips")
    hud_main = STATIC_ONLY["HUD"].read_text(encoding="utf-8").replace("\r\n", "\n")
    hl = re.search(r"\n\tHUD\.Layout = \{\n(.*?)\n\t\}\n", hud_main, re.S)
    check(hl is not None and re.search(r"LeftX = ", hl.group(1)) is not None
          and re.search(r"RightX = ", hl.group(1)) is not None,
          "HUD.Layout publishes LeftX / RightX (the free top band beside the player card / luck panel)")
    # A23-40 layout B: EventHUD's notify column and next-event line read HUD.Layout.Rects (notify, event)
    check(hl is not None and "Rects = R," in hl.group(1),
          "HUD.Layout publishes the HudLayout rects (EventHUD reads Rects.notify / Rects.event)")
    client_main = STATIC_ONLY["CLIENT_MAIN"].read_text(encoding="utf-8")
    check("HalloweenService" not in client_main, "HalloweenService is server-only (not in the client module list)")
    panels = FILES["PANELS_SOURCE"].read_text(encoding="utf-8")
    check('{ "Slime", "BigSlime", "Goblin", "GoblinBrute", "Skeleton", "SkeletonKnight" }' not in panels,
          "Panels has no hard-coded monster list left (the drop list follows Config.MonsterTypeOrder)")
    notes.append("Unchanged / static only: MonsterService.spawnMonster's model build, AI, name bar and Studio models; "
                 "EventHUD pill art and phone layout; Fx hover on a real Weld; MonsterMotion bone playback.")
    return count, failures, notes


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", type=Path, default=ROOT / "build/luau_cli_0_741/luau.exe")
    parser.add_argument("--no-mutations", action="store_true")
    args = parser.parse_args()
    binary = args.luau.resolve()
    compiler = binary.with_name("luau-compile" + binary.suffix)
    if not binary.is_file() or not compiler.is_file():
        print("Installed Luau CLI missing; this test never downloads tools.", file=sys.stderr)
        return 1
    raw = {key: path.read_bytes() for key, path in FILES.items()}
    sources = {key: value.decode("utf-8-sig").replace("\r\n", "\n") for key, value in raw.items()}
    fixture_raw = FIXTURE.read_bytes()

    compiled = subprocess.run([str(compiler), *(str(p) for p in FILES.values()), str(FIXTURE)], cwd=ROOT,
                              stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True,
                              encoding="utf-8", errors="replace", timeout=180)
    static_count, static_failures, static_notes = static_checks()

    with tempfile.TemporaryDirectory(prefix="halloween_offline_") as tmp:
        tmpdir = Path(tmp)
        main_run = run_harness(binary, make_harness(sources), tmpdir, "halloween_main.luau")
        result = main_run["result"]
        baseline = failing_keys(result)
        mutations = []
        if not args.no_mutations:
            jobs = []
            for name, key, old, new in MUTATIONS:
                hits = sources[key].count(old)
                if hits != 1:
                    mutations.append({"mutation": name, "file": FILES[key].relative_to(ROOT).as_posix(), "applied": False,
                                      "caught": False, "note": f"pattern matched {hits} times; update MUTATIONS"})
                    continue
                mutated = dict(sources)
                mutated[key] = sources[key].replace(old, new, 1)
                try:
                    jobs.append((name, key, make_harness(mutated)))
                except ValueError as error:
                    mutations.append({"mutation": name, "file": FILES[key].relative_to(ROOT).as_posix(), "applied": False,
                                      "caught": False, "note": f"extractor boundary broken: {error}"})

            def work(index_job):
                index, (name, key, text) = index_job
                out = run_harness(binary, text, tmpdir, f"halloween_mutant_{index:02d}.luau")
                new_fail = sorted(failing_keys(out["result"]) - baseline)
                crashed = out["result"] is None
                return {"mutation": name, "file": FILES[key].relative_to(ROOT).as_posix(), "applied": True,
                        "caught": crashed or bool(new_fail), "crashed": crashed,
                        "newFailingChecks": new_fail[:6], "newFailingCount": len(new_fail)}

            with ThreadPoolExecutor(max_workers=6) as pool:
                mutations.extend(pool.map(work, enumerate(jobs)))

    changed = [p.relative_to(ROOT).as_posix() for key, p in FILES.items() if p.read_bytes() != raw[key]]
    if FIXTURE.read_bytes() != fixture_raw:
        changed.append(FIXTURE.relative_to(ROOT).as_posix())
    marker = re.search(r"HALLOWEEN_OFFLINE_OK checks=(\d+) Studio/API calls=0", main_run["stdout"])
    named = result.get("Named", []) if result else []
    failing = [n for n in named if n.get("Fail", 0) > 0]
    caught = sum(1 for m in mutations if m.get("caught"))
    applied = sum(1 for m in mutations if m.get("applied"))
    ok = (compiled.returncode == 0 and main_run["returncode"] == 0 and marker is not None and not static_failures
          and not changed and all(m.get("applied") and m.get("caught") for m in mutations))
    report = {
        "status": ("passed-no-mutations" if args.no_mutations else "passed") if ok else "failed",
        "mutationsSkipped": args.no_mutations,
        "checks": result.get("Checks", 0) if result else 0,
        "failedChecks": result.get("Failed", 0) if result else 0,
        "namedChecks": len(named),
        "namedChecksFailing": len(failing),
        "failing": [{"group": n["Group"], "check": n["Name"], "failures": n["Fail"], "passes": n["Pass"],
                     "firstFailure": n.get("FirstFailure")} for n in failing],
        "named": [{"group": n["Group"], "check": n["Name"], "pass": n["Pass"], "fail": n["Fail"]} for n in named],
        "findings": result.get("Findings", []) if result else [],
        "staticChecks": static_count,
        "staticFailures": static_failures,
        "staticNotes": static_notes,
        "mutations": {"total": len(MUTATIONS), "applied": applied, "caught": caught, "results": mutations},
        "compileOk": compiled.returncode == 0,
        "compileErrors": compiled.stderr.strip(),
        "runtimeError": None if result else (main_run["stderr"].strip() or main_run["stdout"].strip())[-2000:],
        "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(raw[key]).hexdigest() for key, p in FILES.items()},
        "fixtureSHA256": hashlib.sha256(fixture_raw).hexdigest(),
        "sourcesChangedDuringRun": changed,
        "studioCalls": 0, "apiCalls": 0,
        "contract": "Halloween season (lead design 2026-10-06, numbers provisional; A23-27 / A23-28 / A23-30). "
                    "Config.Halloween.Enabled AND the server clock before EndsAt 1794150000 (2026-11-09 00:00 KST; "
                    "Config.SeasonOn via Config.SeasonNow = workspace:GetServerTimeNow, os.time fallback) gate every "
                    "seasonal kind, the PumpkinPatch zone, the Pumpkin King schedule, its HUD line and the patch road sign. "
                    "A23-30 zone family: Config.Zones.PumpkinPatch (Center 360,0,235, Size 160x120, MinLevel 1, no PvP, "
                    "Season Halloween; LandPumpkinPatch x 280..440 z 175..295 joined to LandMeadow) holds every Halloween "
                    "kind and only them: PumpkinSlime (Count 6, counts as Slime), LittleGhost (Count 4, HP 30, Float 1.5), "
                    "BatGoblin (Count 4, HP 45, counts as itself; rigged: Tripo clips 32/36/31/16/46 frames at 15 fps), "
                    "PumpkinKing (Count 0, Boss, never golden, never respawns); no Takes, so the meadow / woods / ruins keep "
                    "their counts and capped targets in season; the three regular kinds sit outside the GlobalCap on their "
                    "own targets; ZoneAt reads the patch as Outskirts off season. King: first 6 min after server start, then "
                    "every 20 min from the previous appearance, at a SpawnSpot in the patch's far half, leaves after 5 min "
                    "with a friendly line; appear / defeat / leave lines go to every client without a name "
                    "(AnnounceService.Broadcast, Korean + English twin). A23-27 safety: a Boss kind never targets or hits a "
                    "player with Level < SafeBelowLevel (5) or PlaytimeSeconds < SafePlaySeconds (600), whatever the faction "
                    "or the PvP Rookie flag; other kinds attack new players as usual. A23-27 rewards: MonsterService counts "
                    "each contributor's own hits and damage (overkill excluded) and pays the king only to contributors of "
                    "the last 120 s with >= 3 hits and >= 0.5% of MaxHP (45 of 9000), one MonsterKilled each; kinds without "
                    "RewardMinHits / RewardMinDamageFrac pay every contributor. King rows: Candy x8, Enh70 25%, Enh30 8%, "
                    "Enh10 2%, Move70 8%, HP / MP potions 50%, tier-4 weapon 5% (3 candies below its MinLevel). A23-28 "
                    "HW-13: at EndsAt no king appears, PumpkinKingNextAt goes to 0, a king still here goes home (leave "
                    "fade + leave line), MonsterService.reevaluate sends the regular Halloween monsters home, the sign "
                    "hides. GameState PumpkinKingNextAt / Active / EndsAt; Candy material (sell 5); the slime jackpot also "
                    "on pumpkin slimes; quests / tutorial / story objectives count Config.QuestKind; Studio-only "
                    "DebugCommand 'PumpkinKing'. Client: EventHUD king pill never narrower than its text (KING.need), "
                    "moving to the next slot or under the chips (Korean / English, UIScale 1 / 0.75); Fx WOBBLE ghost "
                    "float, slime hop <= min(0.15 x body, 0.6) with a 0.1 Sink, blob shadows (smaller in the air, 0.65 "
                    "and fainter under a floater, rest-size for pop-ins, removed when anchored / out of range / gone, "
                    "none and no dust for foreign personal monsters).",
        "limitations": "Offline doubles: Roblox Instances, a seeded / scripted Random, DataStore table, flat-ground stand-in "
                       "for MonsterService.groundPoint / pickSpawnPoint, MonsterService.spawnMonster replaced by a record "
                       "maker that uses the real golden roll and creates the same _contributors / _hits / _dmg tables, "
                       "MonsterService.despawn replaced by a recorder in the pool world (the real one runs in the king "
                       "worlds), CFrame algebra limited to Z rolls, EventHUD placement from logical numbers (no real GUI "
                       "layout), Fx makePart / groundY / burst / Feel.isForeign as recording doubles on flat ground. Studio "
                       "models and Terrain, MapBuilder's patch land / sign build, real Weld / shadow rendering, MonsterMotion "
                       "playback, real phone layouts, the live server clock crossing EndsAt and multiplayer timing are not "
                       "certified here.",
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if compiled.returncode:
        print(compiled.stderr, end="")
    for line in main_run["stdout"].splitlines():
        if line.startswith("CHECK_FAIL") or line.startswith("HALLOWEEN_OFFLINE") or line.startswith("FINDING"):
            print(line)
    if not result:
        print(main_run["stderr"], end="")
    for message in static_failures:
        print(f"STATIC_FAILURE {message}")
    print(f"STATIC checks={static_count} failed={len(static_failures)}")
    for m in mutations:
        print(f"MUTATION {'caught ' if m.get('caught') else 'MISSED'} {m['mutation']}"
              + ("" if m.get("applied") else f" ({m.get('note')})"))
    if mutations:
        print(f"MUTATIONS caught={caught}/{applied} (of {len(MUTATIONS)})")
    if args.no_mutations:
        print("MUTATIONS SKIPPED")
    print(f"Named checks: {len(named) - len(failing)} passed, {len(failing)} failing; "
          f"assertions {report['checks'] - report['failedChecks']}/{report['checks']}")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if ok else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(f"Halloween offline check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
