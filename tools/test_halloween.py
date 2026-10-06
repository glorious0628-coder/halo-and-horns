"""Halloween season (Config.Halloween, 2026-10-06): run the current sources offline.

Runs the CURRENT Config, Net, Util, DataService, QuestService, StoryQuestService, LootService, AnnounceService,
HalloweenService, Main.server.luau and the client Announce module, plus chunks cut from MonsterService (event spawn /
kill / contributor payout / regular pool + GlobalCap split / golden roll / death pop and leave fade), EventHUD (the
Pumpkin King pill and its placement beside HUD's columns), Fx (WOBBLE float, leaving king without the splat) and
Panels (drop list loop), and the BatGoblin / Goblin MonsterAnims clip modules. Everything is injected into
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
    ("pumpkin slimes take 2 slime slots (meadow density changes)", "CONFIG_SOURCE",
     "Takes = { Slime = 3 }", "Takes = { Slime = 2 }"),
    ("seasonal kinds counted with the season off", "CONFIG_SOURCE",
     "out[kind] = Config.MonsterActive(kind, seasonOn) and math.max(0, math.floor(tonumber(def.Count) or 0)) or 0",
     "out[kind] = math.max(0, math.floor(tonumber(def.Count) or 0))"),
    ("seasonal slice not taken from the base kind's growth", "CONFIG_SOURCE",
     "out[base] = math.max(0, out[base] - p)", "out[base] = math.max(0, out[base])"),
    ("QuestKind ignores QuestAs", "CONFIG_SOURCE", "\t\treturn def.QuestAs\n", "\t\treturn kind\n"),
    ("season flag ignored (always on)", "CONFIG_SOURCE",
     "return type(s) == \"table\" and s.Enabled == true", "return type(s) == \"table\""),
    ("pumpkin slime loses the slime jackpot", "CONFIG_SOURCE",
     "Monsters = { Slime = true, PumpkinSlime = true }", "Monsters = { Slime = true }"),
    ("Pumpkin King HP tripled", "CONFIG_SOURCE", "HP = 9000,", "HP = 27000,"),
    ("killWeight counts a seasonal kind by its own XP", "QUEST_SOURCE", "\tkind = Config.QuestKind(kind)\n", ""),
    ("story kill objectives ignore QuestKind", "STORY_SOURCE",
     "Config.QuestKind(info.Kind) ~= obj.Kind", "info.Kind ~= obj.Kind"),
    ("first king without the 6-minute delay", "HALLOWEEN_SOURCE",
     "(Util.Now() + math.max(0, num(H.FirstDelay, 360)))", "(Util.Now())"),
    ("next king 10 min after an appearance", "HALLOWEEN_SOURCE",
     "if appear(now) then\n\t\tK.NextAt = now + interval", "if appear(now) then\n\t\tK.NextAt = now + interval / 2"),
    ("king never leaves after its lifetime", "HALLOWEEN_SOURCE", "elseif now >= K.EndsAt then", "elseif false then"),
    ("a lost king is reported as defeated", "HALLOWEEN_SOURCE", "finish(num(rec.HP, 1) <= 0)", "finish(true)"),
    ("HalloweenService ignores Config.Halloween.Enabled", "HALLOWEEN_SOURCE",
     "local function seasonOn()\n\treturn H.Enabled == true", "local function seasonOn()\n\treturn true"),
    ("leaving king stays in the world", "HALLOWEEN_SOURCE",
     "local ok, err = pcall(svc.RemoveEvent, rec, true, true)", "local ok, err = true, nil"),
    ("leaving king squashes like a kill", "HALLOWEEN_SOURCE",
     "pcall(svc.RemoveEvent, rec, true, true)", "pcall(svc.RemoveEvent, rec, true)"),
    ("leave fade shrinks the king", "MONSTER_SOURCE",
     "local goal = leaving and { Transparency = 1 } or { Size = d.Size * 0.2, Transparency = 1 }",
     "local goal = { Size = d.Size * 0.2, Transparency = 1 }"),
    ("Leaving set after the anchor", "MONSTER_SOURCE",
     "\tif leaving then model:SetAttribute(\"Leaving\", true) end", "\tif false then end"),
    ("leaving slime still splats", "FX_SOURCE",
     "\n\t\t\t\tand model:GetAttribute(\"Leaving\") ~= true then", " then"),
    ("ghosts counted inside the GlobalCap", "CONFIG_SOURCE",
     "return type(def) == \"table\" and def.Season ~= nil and type(def.Takes) ~= \"table\"", "return false"),
    ("takers get their own cap share", "CONFIG_SOURCE",
     "if type(only) == \"string\" and Config.MonsterTypes[only] ~= nil then return only end", ""),
    ("ghosts wait for room under the cap", "MONSTER_SOURCE",
     "while have < target and (outside or total < GLOBAL_CAP) and", "while have < target and total < GLOBAL_CAP and"),
    ("pill measured from the screen edge (ignores HUD's left column)", "EVENTHUD_SOURCE",
     "local room = x0 - gap - math.max(gap, num(hl.LeftX))", "local room = x0 - gap - gap"),
    ("right slot ignores the kaiju pill", "EVENTHUD_SOURCE",
     "local kaiju = (ui.KaijuChip and ui.KaijuChip.Visible) and (KAIJU_CHIP_W + gap) or 0", "local kaiju = 0"),
    ("right slot ignores HUD's button cluster", "EVENTHUD_SOURCE",
     "if room >= L.KingMinW and not blocked then", "if room >= L.KingMinW then"),
    ("pill under the chips leaves the personal line in place", "EVENTHUD_SOURCE",
     "\tKING.setBelow(below)\nend", "\tKING.setBelow(false)\nend"),
    ("Broadcast also sends non-event keys", "ANNOUNCE_SOURCE",
     "if type(A.Events) ~= \"table\" or A.Events[key] == nil then return end", ""),
    ("English twin ignored on the client", "ANNOUNCE_CLIENT_SOURCE",
     "local en = A.English() and text[msg.Key .. \"En\"]", "local en = false"),
    ("PumpkinKing debug key routed nowhere", "MAIN_SOURCE", "return S.HalloweenService.DebugSpawn()", "return \"ok\""),
    ("king pays only the last 15 s of hitters", "MONSTER_SOURCE",
     "local window = tonumber(def.ContributorWindow) or MC.ContributorWindow", "local window = MC.ContributorWindow"),
    ("defeated king respawns", "MONSTER_SOURCE",
     "elseif not rec.Event then\n\t\tscheduleRespawn(rec.Kind)", "else\n\t\tscheduleRespawn(rec.Kind)"),
    ("event king and ghosts counted toward the global cap", "MONSTER_SOURCE",
     "if rec.Alive and rec.Owner == nil and not rec.Event and not Config.MonsterOutsideCap(rec.Kind) then n += 1 end",
     "if rec.Alive and rec.Owner == nil then n += 1 end"),
    ("ghost walks on the floor (Float ignored)", "FX_SOURCE",
     "Float = (float and float > 0 and def.Shape ~= \"Slime\") and float or nil,", "Float = nil,"),
    ("HUD shows the countdown while the king is here", "EVENTHUD_SOURCE",
     "if gsAttr(\"PumpkinKingActive\", false) == true then", "if false then"),
    ("bat goblin slash loops", "CLIP_BatGoblin_Slash", "Loop = false", "Loop = true"),
    ("GameState defaults miss the king attributes", "NET_SOURCE",
     "PumpkinKingNextAt = 0, PumpkinKingActive = false, PumpkinKingEndsAt = 0,", "PumpkinKingNextAt = 0,"),
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
        "local spawnMonster, playersPerZone, warnThrottled = H.spawnMonster, H.playersPerZone, H.warnThrottled\n"
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
        "local Config, Util, H = ...\nlocal C = H.C\nlocal ui = H.ui\nlocal IS_TOUCH = H.IsTouch == true\nlocal guiScale = nil\n"
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
    check('local key = kind .. "_" .. name' in motion and 'Clips = { "Idle", "Walk", "Slash", "Hurt", "Fall" }' in motion,
          "MonsterMotion loads ReplicatedStorage.MonsterAnims['<Kind>_<Clip>'] for the five clips (BatGoblin_* are found by kind id)")
    hud = FILES["EVENTHUD_SOURCE"].read_text(encoding="utf-8").replace("\r\n", "\n")
    upd = re.search(r"\nlocal function update\(\)\n(.*?)\nend\n", hud, re.S)
    check(upd is not None and "KING.update(now)" in upd.group(1), "EventHUD update() refreshes the Pumpkin King pill every tick")
    lay = re.search(r"\nlayout = function\(\)\n(.*?)\nend\n", hud, re.S)
    check(lay is not None and "if KING.Below then personalY += L.PillH + L.StripGap end" in lay.group(1)
          and "tostring(KING.Below)" in lay.group(1),
          "EventHUD layout(): the touch personal line moves one row down while the king pill sits under the chips")
    hud_main = STATIC_ONLY["HUD"].read_text(encoding="utf-8").replace("\r\n", "\n")
    hl = re.search(r"\n\tHUD\.Layout = \{\n(.*?)\n\t\}\n", hud_main, re.S)
    check(hl is not None and "LeftX = leftX," in hl.group(1) and "RightX = rightX," in hl.group(1),
          "HUD.Layout publishes LeftX / RightX (the free top band beside the player card / luck panel)")
    check("local leftX = 12 + leftBlockW + 8" in hud_main,
          "HUD's LeftX is the right edge of the card + quest column (+ 8)")
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
        "status": "passed" if ok else "failed",
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
        "contract": "Halloween season (lead design 2026-10-06, numbers provisional): Config.Halloween.Enabled gates every "
                    "seasonal kind, the slot takeover, the Pumpkin King schedule and its HUD line. PumpkinSlime (meadow, 3 of "
                    "the 12 slime slots, counts as Slime), LittleGhost (woods, +3, Float 1.5, counts as itself), BatGoblin "
                    "(woods, 3 of the goblin slots, counts as Goblin, rigged: Tripo clips 32/36/31/16/46 frames at 15 fps), "
                    "PumpkinKing (Count 0, Boss, never golden, never respawns): first 6 min after server start, then every "
                    "20 min from the previous appearance, near the meadow center, leaves after 5 min with a friendly line; "
                    "appear / defeat / leave lines go to every client without a name (AnnounceService.Broadcast, Korean + "
                    "English twin); rewards only through MonsterService's kill path, one MonsterKilled per contributor "
                    "(ContributorWindow 120 s for the king); GameState PumpkinKingNextAt / Active / EndsAt; Candy material "
                    "(sell 5) and the four drop tables; the slime jackpot also on pumpkin slimes; quests / tutorial / story "
                    "objectives count Config.QuestKind; Studio-only DebugCommand 'PumpkinKing'.",
        "limitations": "Offline doubles: Roblox Instances, a seeded / scripted Random, DataStore table, flat-ground stand-in "
                       "for MonsterService.groundPoint, MonsterService.spawnMonster replaced by a record maker that uses the "
                       "real golden roll, CFrame algebra limited to Z rolls. Studio models, real Weld rendering, MonsterMotion "
                       "playback, phone layouts and multiplayer timing are not certified here.",
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
