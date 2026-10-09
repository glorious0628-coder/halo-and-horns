"""BB1 key map (Keybinds) and BB2 saved settings (SettingsService / Settings), run offline.

Runs the CURRENT Config, Util, Net, DataService, SettingsService, Keybinds and Settings sources (injected into
tools/fixtures/keys_settings_offline.luau) with the installed official Luau CLI (build/luau_cli_0_741). No Studio,
network, DataStore or Roblox API calls. Every check is named and collected. Review B5: the key-hint code of HUD
(L.QuestText), WorldMap (ShowsKeys / HintText / the BindKey and Open hint blocks) and Intro (TXT / SkipText) is cut from
the current text and run against the real Keybinds on six devices; static checks cover the rest of the client wiring.
A mutation step then breaks in-memory copies of the sources (never src/), runs them from a temporary directory (offline
run + static checks on the mutated text) and counts how many mutations the checks catch.

Usage: py tools/test_keys_settings.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/offline_keys_settings_2026-10-06.json
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tools/fixtures/keys_settings_offline.luau"
OUT = ROOT / "docs/art/verification_2026-10-06/offline_keys_settings_2026-10-06.json"
PLAYER_SCRIPTS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {
    "CONFIG_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
    "UTIL_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Util.luau",
    "NET_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Net.luau",
    "DATA_SOURCE": ROOT / "src/ServerScriptService/DataService.luau",
    "SERVICE_SOURCE": ROOT / "src/ServerScriptService/SettingsService.luau",
    "KEYBINDS_SOURCE": PLAYER_SCRIPTS / "Keybinds.luau",
    "SETTINGS_SOURCE": PLAYER_SCRIPTS / "Settings.luau",
}
STATIC_ONLY = {
    "CLIENT_MAIN": PLAYER_SCRIPTS / "ClientMain.client.luau",
    "SERVER_MAIN": ROOT / "src/ServerScriptService/Main.server.luau",
    "HUD": PLAYER_SCRIPTS / "HUD.luau",
    "VITALS": PLAYER_SCRIPTS / "VitalsUI.luau",
    "GHOST": PLAYER_SCRIPTS / "GrudgeGhost.luau",
    "WORLD_MAP": PLAYER_SCRIPTS / "WorldMap.luau",
    "PANELS": PLAYER_SCRIPTS / "Panels.luau",
    "STORY": ROOT / "src/ServerScriptService/StoryQuestService.luau",
    "INTRO": PLAYER_SCRIPTS / "Intro.luau",
}
ALL_SOURCES = {**FILES, **STATIC_ONLY}
# review B5 (2026-10-06): a key-hint decision may not test these device flags; it asks Keybinds.ShowsKeys()
DEVICE_FLAGS = re.compile(r"\b(TouchEnabled|MouseEnabled)\b")

# (name, source key, exact text, replacement): each must match exactly once in the current (LF-normalized) source
MUTATIONS = [
    ("KeyMap: an explicit key already taken is kept", "CONFIG_SOURCE",
     'if v ~= "" and not taken[v] then', 'if v ~= "" then'),
    ("KeyMap: a default-only collision is not reported", "CONFIG_SOURCE",
     "table.insert(collisions, def.Id)", "local _ = def.Id"),
    ("KeyMap: a non-live action keeps its saved key", "CONFIG_SOURCE",
     "if live(def) and explicit(def) then", "if explicit(def) then"),
    ("Flag ignored (the Z skill is always live)", "CONFIG_SOURCE",
     "\treturn node == true", "\treturn true"),
    ("Reserved letters become usable", "CONFIG_SOURCE",
     "if not KB.ReservedSet[n] then KB.AllowedSet[n] = true end", "KB.AllowedSet[n] = true"),
    ("Sfx not snapped to the 0.1 step", "CONFIG_SOURCE",
     "v = def.Min + math.floor((v - def.Min) / def.Step + 0.5) * def.Step", "v = v"),
    ("enum settings accept any string", "CONFIG_SOURCE",
     'if type(v) ~= "string" or not table.find(def.Options, v) then v = d end', 'if type(v) ~= "string" then v = d end'),
    ("saved keys keep entries equal to the default", "CONFIG_SOURCE",
     'if type(v) == "string" and Config.KeyAllowedFor(a.Id, v) and v ~= a.Key then',
     'if type(v) == "string" and Config.KeyAllowedFor(a.Id, v) then'),
    ("two actions may save the same key", "CONFIG_SOURCE",
     'if used[v] then v = if a.NoClear then nil else "" else used[v] = true end', "used[v] = true"),
    ("Interact may be saved on any usable key", "CONFIG_SOURCE",
     'if def.KeySet == "Prompt" then return KB.PromptSet[name] == true end', ""),
    ("Interact may be cleared", "CONFIG_SOURCE",
     'if name == "" then return def.NoClear ~= true end', 'if name == "" then return true end'),
    ("KeyMap leaves Interact empty", "CONFIG_SOURCE",
     "if def.NoClear and live(def) and map[def.Id] == \"\" and def.Key ~= \"\" then", "if false then"),
    ("unknown top-level settings are kept", "CONFIG_SOURCE",
     "local out = { V = ST.Version, Keys = {} }", "local out = table.clone(src); out.V = ST.Version; out.Keys = {}"),
    # A23-78 (settings V2): the old key-hint value is dropped once
    ("A23-78: an old save keeps its key hints on", "CONFIG_SOURCE",
     '\t\tif key == "KeyBadges" and before2 then v = d end\n', ""),
    ("A23-78: V2 picks are dropped too", "CONFIG_SOURCE",
     "local before2 = not (type(src.V) == \"number\" and src.V == src.V and src.V >= 2)", "local before2 = true"),
    ("A23-78: a NaN V counts as new", "CONFIG_SOURCE",
     "local before2 = not (type(src.V) == \"number\" and src.V == src.V and src.V >= 2)",
     "local before2 = type(src.V) == \"number\" and src.V < 2"),
    ("A23-91: the version stays 3", "CONFIG_SOURCE", "\tVersion = 4,\n\tMaxBlobKeys", "\tVersion = 3,\n\tMaxBlobKeys"),
    # A23-65 (settings V3): an old Follow camera becomes Free once
    ("A23-65: an old save keeps Follow", "CONFIG_SOURCE",
     '\t\tif key == "Cam" and before4 then v = d end\n', ""),
    ("A23-65: V3 picks are dropped too", "CONFIG_SOURCE",
     "local before4 = not (type(src.V) == \"number\" and src.V == src.V and src.V >= 4)", "local before4 = true"),
    ("A23-65: the V2 check is reused for the camera", "CONFIG_SOURCE",
     "local before4 = not (type(src.V) == \"number\" and src.V == src.V and src.V >= 4)",
     "local before4 = not (type(src.V) == \"number\" and src.V == src.V and src.V >= 3)"),
    ("A23-65: a NaN V counts as new", "CONFIG_SOURCE",
     "local before4 = not (type(src.V) == \"number\" and src.V == src.V and src.V >= 4)",
     "local before4 = type(src.V) == \"number\" and src.V < 4"),
    ("A23-91: the default blob stays V3", "CONFIG_SOURCE", "\t\tSettings = { V = 4,", "\t\tSettings = { V = 3,"),
    ("A23-91: the default camera stays Free", "CONFIG_SOURCE", '\t\t\tCam = "Follow", PvPCards = false },', '\t\t\tCam = "Free", PvPCards = false },'),
    ("A23-78: every setting of an old save is reset", "CONFIG_SOURCE",
     '\t\tif key == "KeyBadges" and before2 then v = d end\n', "\t\tif before2 then v = d end\n"),
    ("old saves are not sanitized on load", "DATA_SOURCE",
     "d.Settings = Config.SanitizeSettings(d.Settings)", "d.Settings = d.Settings"),
    ("SetSettings accepts two arguments", "SERVICE_SOURCE",
     "if n > 1 then return end", "if n > 2 then return end"),
    ("SetSettings accepts 17 top-level keys", "SERVICE_SOURCE",
     "if count > (Config.Settings.MaxBlobKeys or 16) then return end",
     "if count > (Config.Settings.MaxBlobKeys or 16) + 1 then return end"),
    ("Seq is not clamped", "SERVICE_SOURCE",
     "seq = math.clamp(math.floor(s), 0, MAX_SEQ)", "seq = s"),
    ("SetSettings works before PlayerReady", "SERVICE_SOURCE",
     "if not S.PlayerService.IsReady(player) then return end", ""),
    ("SetSettings is not rate-limited", "SERVICE_SOURCE",
     'if not Util.RateLimit(player, "SetSettings", Config.RateLimits.SetSettings or 1) then return end', ""),
    ("the echo goes to every client", "SERVICE_SOURCE",
     'Net.Get("Settings"):FireClient(player, ', 'Net.Get("Settings"):FireAllClients('),
    ("the blob is saved without SanitizeSettings", "SERVICE_SOURCE",
     "\t\tdata.Settings = Config.SanitizeSettings(blob)\n", "\t\tdata.Settings = blob\n"),
    ("no push on PlayerReady", "SERVICE_SOURCE",
     "local ok, err = pcall(function() send(player, 0, SettingsService.Get(player)) end)", "local ok, err = true, nil"),
    ("SetLocal does not swap (the holder keeps its key)", "KEYBINDS_SOURCE",
     "if holder and holder ~= action then sparse[holder] = old end", ""),
    ("touch-only devices see key labels", "KEYBINDS_SOURCE",
     "if touchOnly() then return en and def.ButtonEn or def.Button end", ""),
    ("every pad button is wired", "KEYBINDS_SOURCE",
     'if live[def.Id] and KB.PadWired[def.Id] and def.Pad ~= "" then', 'if live[def.Id] and def.Pad ~= "" then'),
    ("the client sends without waiting for the rate-limit slot", "SETTINGS_SOURCE",
     "local wait = ST.LastSent + interval() - os.clock()", "local wait = 0"),
    ("older echoes are applied", "SETTINGS_SOURCE",
     "if seq ~= seq or seq < ST.Seq then return end", "if seq ~= seq then return end"),
    ("an echo overwrites changes not yet sent", "SETTINGS_SOURCE",
     "for k in ST.Dirty do value[k] = Util.DeepCopy(ST.Local[k]) end", ""),
    ("a blob the server drops is never sent again", "SETTINGS_SOURCE",
     "if ST.InFlight ~= flight then return end", "do return end"),
    ("an echo does not end the in-flight wait (needless resends)", "SETTINGS_SOURCE",
     "if ST.InFlight and seq >= ST.InFlight.Seq then", "if false then"),
    ("an unanswered blob is resent forever", "SETTINGS_SOURCE",
     "if ST.Resends >= ST.MaxResends then return end", ""),
    ("SetLocal keeps a non-live action's saved entry on the new key", "KEYBINDS_SOURCE",
     'if not K.Live[id] and v ~= "" and (v == key or (holder and holder ~= action and v == old)) then sparse[id] = nil end',
     ""),
    ("SetLocal keeps a non-live action's saved entry on the swapped holder's new key", "KEYBINDS_SOURCE",
     "(v == key or (holder and holder ~= action and v == old))", "(v == key)"),
    # review B5 (2026-10-06): one key-hint rule, Keybinds.ShowsKeys() (= KeyboardEnabled)
    ("B5: touchOnly back to 'TouchEnabled and not KeyboardEnabled' (a gamepad shows keys)", "KEYBINDS_SOURCE",
     "\treturn not Keybinds.ShowsKeys()", "\treturn UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled"),
    ("B5: HUD L.QuestText back to the IS_TOUCH test", "HUD",
     "pcall(kb.Fill, text, type(kb.ShowsKeys) == \"function\" and kb.ShowsKeys() == true)",
     "pcall(kb.Fill, text, not (IS_TOUCH and not UserInputService.KeyboardEnabled))"),
    ("B5: WorldMap.Open hint back to 'TouchEnabled and not MouseEnabled'", "WORLD_MAP",
     "\t\thintLabel.Text = WorldMap.ShowsKeys() and WorldMap.HintText() or TXT.HintTouch",
     "\t\tlocal touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled\n"
     "\t\thintLabel.Text = touchOnly and TXT.HintTouch or WorldMap.HintText()"),
    ("B5: WorldMap.BindKey hint back to the MouseEnabled test", "WORLD_MAP",
     "if hintLabel and WorldMap.ShowsKeys() then",
     "if hintLabel and not (UserInputService.TouchEnabled and not UserInputService.MouseEnabled) then"),
    ("B5: WorldMap.ShowsKeys ignores Keybinds (= not TouchEnabled)", "WORLD_MAP",
     'if type(kb) == "table" and type(kb.ShowsKeys) == "function" then return kb.ShowsKeys() == true end\n'
     "\treturn UserInputService.KeyboardEnabled == true",
     "return not UserInputService.TouchEnabled"),
    ("B5: Intro TXT.SkipKey back to the TouchEnabled test", "INTRO",
     'SkipKey = " (Enter)",', 'SkipKey = UserInputService.TouchEnabled and "" or " (Enter)",'),
    ("B5: Intro.SkipText decides with TouchEnabled", "INTRO",
     "then shows = kb.ShowsKeys() == true end", "then shows = not UserInputService.TouchEnabled end"),
    # review of 27246d1: Interact always keeps a key the default ProximityPrompt draws
    ("SetLocal: no swap guard (Interact can be handed a key it cannot hold or none)", "KEYBINDS_SOURCE",
     '\tif holder and holder ~= action and not Config.KeyAllowedFor(holder, old) then return false, "NotAllowed" end\n', ""),
    ("Capture: no refusal of keys the action cannot hold (no toast, straight to SetLocal)", "KEYBINDS_SOURCE",
     "\telseif not Config.KeyAllowedFor(cap.Action, name) then\n"
     '\t\ttoast(text("NotAllowed"), "bad", 3)\n'
     '\t\tKeybinds.EndCapture("NotAllowed", name)\n', ""),
    # user 2026-10-08 (MMO keys): Soon window keys, the bag's Alt window, the I / O camera zoom sink
    ("Soon window keys stay dead until their windows exist", "KEYBINDS_SOURCE",
     'if def.Group ~= "Window" or def.Soon == true then', 'if def.Group ~= "Window" then'),
    ("the Alt window does not make the bag key live", "KEYBINDS_SOURCE",
     "\t\t\t\tif not (ok and has) and def.Alt then ok, has = pcall(panels.Has, def.Alt) end\n", ""),
    ("WindowFor ignores the Alt window", "KEYBINDS_SOURCE",
     "\t\tif not (okW and hasW) and okA and hasA then return def.Alt end\n", ""),
    ("the Alt window beats the real one", "KEYBINDS_SOURCE",
     "if not (okW and hasW) and okA and hasA then return def.Alt end", "if okA and hasA then return def.Alt end"),
    ("no camera key sink", "KEYBINDS_SOURCE", "\tsinkCameraKeys()\n\ttoastCollisions()\n", "\ttoastCollisions()\n"),
    ("the sink is never lifted", "KEYBINDS_SOURCE",
     "\tpcall(function() ContextActionService:UnbindAction(K.SinkAction) end)\n", ""),
    ("every camera key sunk, held or not", "KEYBINDS_SOURCE",
     "\t\tif K.ByKey[name] then\n\t\t\ttable.insert(codes, Enum.KeyCode[name])\n",
     "\t\tif true then\n\t\t\ttable.insert(codes, Enum.KeyCode[name])\n"),
    ("an unbuilt window key does nothing again", "HUD", "\t\tL.WindowSoon(action)\n\t\treturn true\n", "\t\treturn true\n"),
    ("Q does not fold the quest list out", "HUD",
     'if inputAllowed() and not throttled("questKey", 0.25) then toggleQuests() end', "if false then end"),
    ("an unbuilt window key skips its tile", "HUD", "\t\tif def.Key == action then\n\t\t\tL.TileTap(def)\n",
     "\t\tif def.Key == action then\n"),
    # 10/08 Play check: the real I key opened nothing (a CAS-sunk key reaches UserInputService as processed)
    ("the sink swallows the key (HUD never sees it)", "KEYBINDS_SOURCE", "\t\tKeybinds.Began:Fire(input, false)\n", ""),
    ("a sunk key comes twice", "KEYBINDS_SOURCE",
     "\t\tif sunk(input) then return end\n\t\tKeybinds.Began:Fire(input, gameProcessed)\n",
     "\t\tKeybinds.Began:Fire(input, gameProcessed)\n"),
    ("the sink takes I while typing", "KEYBINDS_SOURCE",
     "\tif UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end\n", ""),
]


def literal(value: str) -> str:
    eq = "===="
    while "]" + eq + "]" in value:
        eq += "="
    return "[" + eq + "[" + value + "]" + eq + "]"


def make_harness(texts: dict[str, str]) -> str:
    """texts: every ALL_SOURCES key -> current (or mutated) LF text. The FILES sources run whole; the B5 key-hint code of
    HUD / WorldMap / Intro is cut out (hint_snippets) and run by the fixture as SNIPPETS against the real Keybinds."""
    head = "\n".join(f"local {key} = {literal(texts[key])}" for key in FILES)
    snippets = hint_snippets(texts)
    head += "\nlocal SNIPPETS = {\n" + "".join(f"\t{k} = {literal(v)},\n" for k, v in snippets.items()) + "}"
    return head + "\n" + FIXTURE.read_text(encoding="utf-8")


def run_harness(binary: Path, harness_text: str, directory: Path, name: str) -> dict:
    path = directory / name
    path.write_text(harness_text, encoding="utf-8")
    proc = subprocess.run([str(binary), str(path)], cwd=ROOT, capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=600)
    result = None
    for line in proc.stdout.splitlines():
        if line.startswith("KEYS_SETTINGS_RESULT_JSON "):
            result = json.loads(line[len("KEYS_SETTINGS_RESULT_JSON "):])
    return {"returncode": proc.returncode, "stdout": proc.stdout, "stderr": proc.stderr, "result": result}


def failing_keys(result: dict | None) -> set[str]:
    if not result:
        return set()
    return {f"{n['Group']} :: {n['Name']}" for n in result.get("Named", []) if n.get("Fail", 0) > 0}


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")


def lua_list(text: str, name: str) -> list[str]:
    match = re.search(r"local " + name + r"\s*=\s*\{(.*?)\n?\}", text, re.S)
    return re.findall(r'"([^"]+)"', match.group(1)) if match else []


def function_body(text: str, header: str) -> str:
    start = text.find(header)
    if start < 0:
        return ""
    end = text.find("\nend\n", start)
    return text[start:end if end > 0 else len(text)]


def whole_function(text: str, header: str) -> str:
    body = function_body(text, header)
    return body + "\nend\n" if body else ""


def hint_block(body: str) -> str:
    """The one-tab 'if hintLabel … end' block of a WorldMap function body ('' when missing)."""
    match = re.search(r"\n(\tif hintLabel\b[^\n]*\n(?:\t\t[^\n]*\n)*?\tend)(?=\n)", body + "\n")
    return match.group(1) if match else ""


def intro_txt(text: str) -> str:
    match = re.search(r"\nlocal TXT = \{\n.*?\n\}\n", text, re.S)
    return match.group(0).strip("\n") if match else ""


def hint_snippets(texts: dict[str, str]) -> dict[str, str]:
    """Review B5 key-hint code cut from the CURRENT HUD / WorldMap / Intro text as runnable chunks ('' when not found)."""
    hud, wmap, intro = texts["HUD"], texts["WORLD_MAP"], texts["INTRO"]
    quest = whole_function(hud, "function L.QuestText(")
    shows = whole_function(wmap, "function WorldMap.ShowsKeys(")
    hint = whole_function(wmap, "function WorldMap.HintText(")
    bind = hint_block(function_body(wmap, "function WorldMap.BindKey("))
    opened = hint_block(function_body(wmap, "function WorldMap.Open("))
    txt = intro_txt(intro)
    skip = whole_function(intro, "function Intro.SkipText(")
    return {
        "HudQuestText": "local L = {}\n" + quest + "return L\n" if quest else "",
        "WorldMapFns": "local WorldMap = {}\n" + shows + hint + "return WorldMap\n" if shows and hint else "",
        "WorldMapBindHint": "return function(hintLabel)\n" + bind + "\nend\n" if bind else "",
        "WorldMapOpenHint": "return function(hintLabel)\n" + opened + "\nend\n" if opened else "",
        "IntroTxt": txt + "\nreturn TXT\n" if txt else "",
        "IntroSkipText": "local Intro = {}\n" + skip + "return Intro\n" if skip else "",
    }


def static_checks(over: dict[str, str] | None = None) -> tuple[int, list[str]]:
    """Client / server wiring the offline modules cannot reach (HUD, VitalsUI, GrudgeGhost, WorldMap, Intro, load order).
    over: ALL_SOURCES key -> text used instead of the file (the mutation step passes mutated text here)."""
    over = over or {}
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    def text_of(key: str) -> str:
        return over[key] if key in over else read(ALL_SOURCES[key])

    by_path = {ALL_SOURCES[k].resolve(): v for k, v in over.items()}

    # BB1 acceptance: 'Enum.KeyCode.' only in Keybinds, Intro (Return / KeypadEnter / ButtonA), WorldMap (ButtonB / Escape)
    # and PlayerListUI (Tab: Config.Keybinds Reserved = Roblox's own player-list key; A23-26 replaces Roblox's list with
    # ours on the same, non-rebindable key); Panels (ButtonB: BB13 "the pad's B closes every Panels window", like WorldMap);
    # CameraFollow (Thumbstick2: A23-65 reads the right stick only to pause the follow turn while the player turns the
    # camera by hand - it binds nothing; Left / Right / Comma / Period: review A23-74 (user 2026-10-07) reads Roblox's own
    # keyboard camera-turn keys - already Config.Keybinds Reserved - the same way, binds nothing)
    allowed_codes = {"Intro.luau": {"Return", "KeypadEnter", "ButtonA"}, "WorldMap.luau": {"ButtonB", "Escape"},
                     "PlayerListUI.luau": {"Tab"}, "Panels.luau": {"ButtonB"},
                     "CameraFollow.luau": {"Thumbstick2", "Left", "Right", "Comma", "Period"}}
    for path in sorted((ROOT / "src/StarterPlayer").rglob("*.luau")):
        codes = set(re.findall(r"Enum\.KeyCode\.(\w+)", by_path.get(path.resolve()) or read(path)))
        if not codes or path.name == "Keybinds.luau":
            continue
        extra = codes - allowed_codes.get(path.name, set())
        check(not extra, f"{path.relative_to(ROOT).as_posix()} has no fixed Enum.KeyCode outside BB1's list ({sorted(extra)})")

    order = lua_list(text_of("CLIENT_MAIN"), "ORDER")
    pos = {name: i for i, name in enumerate(order)}
    check("Keybinds" in pos and "Settings" in pos and "UIKit" in pos,
          "ClientMain ORDER lists Settings and Keybinds")
    if "Keybinds" in pos and "Settings" in pos and "UIKit" in pos:
        check(pos["UIKit"] < pos["Keybinds"] and pos["Settings"] < pos["Keybinds"],
              "ClientMain: Keybinds after UIKit and Settings (Keybinds.Init reads the saved keys)")
        later = [n for n in ("Fx", "VitalsUI", "HUD", "Panels", "WorldMap", "GrudgeGhost") if n in pos]
        check(all(pos["Keybinds"] < pos[n] for n in later),
              "ClientMain: Keybinds before Fx, VitalsUI, HUD, Panels, WorldMap and GrudgeGhost")
    server = text_of("SERVER_MAIN")
    init, start = lua_list(server, "INIT_ORDER"), lua_list(server, "START_ORDER")
    check("SettingsService" in init and "AnnounceService" in init
          and init.index("SettingsService") == init.index("AnnounceService") + 1,
          "Main INIT_ORDER: SettingsService right after AnnounceService")
    check("SettingsService" in start and start[-1:] == ["PlayerService"]
          and start.index("SettingsService") < start.index("PlayerService"),
          "Main START_ORDER: SettingsService before PlayerService, PlayerService last")

    hud = text_of("HUD")
    began = function_body(hud, "local function onInputBegan")
    check("IsCapturing()" in began and "GetFocusedTextBox" in began and "gameProcessed" in began,
          "HUD onInputBegan: nothing while capturing, typing in a TextBox or gameProcessed")
    check("ActionFor(input)" in began and began.find("L.WindowKey(action)") >= 0
          and began.find("L.WindowKey(action)") < began.find("inputAllowed()"),
          "HUD: input through Keybinds.ActionFor; window and menu keys run before inputAllowed()")
    window = function_body(hud, "function L.WindowKey")
    check("CurrentId()" in window and "panels.Close, true" in window and "panels.Open, target" in window and "Has(target)" in window,
          "HUD L.WindowKey: same window key closes, another switches")
    # user 2026-10-08: a window key whose window is not built yet answers like its HUD tile; Q folds the quest list
    check("L.WindowSoon(action)" in window, "HUD L.WindowKey: an unregistered window answers through L.WindowSoon")
    soon = function_body(hud, "function L.WindowSoon")
    check('action == "Journal"' in soon and "toggleQuests()" in soon and "L.TileTap(def)" in soon
          and "def.Key == action" in soon and "TXT.TileSoon" in soon,
          "HUD L.WindowSoon: Q (Journal) = the HUD quest list, a tile's key = that tile, else 'Coming soon!'")
    check("kb.Changed:Connect(L.RefreshKeys)" in hud and "KeyBadges" in hud,
          "HUD key badges follow Keybinds.Changed and Settings.KeyBadges")
    vitals = text_of("VITALS")
    check('action == "PotionHP"' in vitals and 'action == "PotionMP"' in vitals and "ActionFor(input)" in vitals
          and "IsCapturing()" in vitals, "VitalsUI potions use Keybinds.ActionFor (and stop while capturing)")
    vkeys = function_body(vitals, "function VitalsUI.RefreshKeys")
    check("kb.Label" in vkeys and "kb.KeyName" in vkeys and '"KeyBadges"' in vkeys and "key.Visible" in vkeys
          and "Text = tostring(i)" not in vitals,
          "VitalsUI potion badges show Keybinds.Label, hide when unbound or Settings.KeyBadges is off")
    check("keys.Changed:Connect(VitalsUI.RefreshKeys)" in vitals and "st.Changed:Connect(VitalsUI.RefreshKeys)" in vitals,
          "VitalsUI potion badges redraw on Keybinds.Changed and Settings.Changed")
    ghost = text_of("GHOST")
    check('ActionFor(input) == "GhostHold"' in ghost and "IsCapturing()" in ghost and "GetFocusedTextBox" in ghost,
          "GrudgeGhost holds with ActionFor('GhostHold') (T), not G")
    wmap = text_of("WORLD_MAP")
    check('kb.Get("Map")' in wmap and "UnbindAction(ACTION_TOGGLE)" in wmap and "kb.Changed:Connect" in wmap
          and "{Map} / Esc" in wmap, "WorldMap binds Get('Map'), rebinds on Changed, hint '{Map} / Esc: 닫기'")
    panels = text_of("PANELS")
    check("function Panels.CurrentId()" in panels and "Panels.IsRegistered = Panels.Has" in panels,
          "Panels.CurrentId and Panels.IsRegistered exist")
    story = text_of("STORY")
    check("Config.FillKeys(" in story and "Config.KeyMap(" in story,
          "StoryQuestService fills {Auto} in toasts from Config.KeyMap(data.Settings.Keys)")
    row = function_body(story, "local function rowFor")
    check(row != "" and "keyText(" not in row,
          "StoryQuestService quest rows keep the raw {Auto} token (the client fills it per device)")
    parse = function_body(hud, "local function parseQuests")
    qtext = function_body(hud, "function L.QuestText")
    check("L.QuestText(" in parse and "kb.Fill" in qtext and "kb.ShowsKeys()" in qtext,
          "HUD fills quest row key tokens (keys shown: current key, no keyboard: button name)")
    check(re.search(r"kb\.Changed:Connect\(function\(\)[^\n]*\n\s*if questState\.Started then refreshQuests\(\) end", hud)
          is not None, "HUD redraws the quest rows on Keybinds.Changed")

    # review B5 (2026-10-06): the ONE rule for key badges / key hints is Keybinds.ShowsKeys() (= KeyboardEnabled == true).
    # No key-hint decision below may test TouchEnabled / MouseEnabled (the fixture's key-hints-one-rule group runs them).
    kbsrc = text_of("KEYBINDS_SOURCE")
    touch_fn = function_body(kbsrc, "local function touchOnly()")
    shows_fn = function_body(kbsrc, "function Keybinds.ShowsKeys()")
    check(touch_fn != "" and "Keybinds.ShowsKeys()" in touch_fn and "UserInputService.KeyboardEnabled == true" in shows_fn
          and not DEVICE_FLAGS.search(kbsrc),
          "B5 one rule: Keybinds touchOnly() goes through Keybinds.ShowsKeys() (= KeyboardEnabled); Keybinds.luau reads "
          "no TouchEnabled / MouseEnabled")
    check(qtext != "" and "kb.ShowsKeys()" in qtext
          and not re.search(r"\b(TouchEnabled|MouseEnabled|KeyboardEnabled|IS_TOUCH)\b", qtext),
          "B5 one rule: HUD L.QuestText decides keyOnly with kb.ShowsKeys() (no TouchEnabled / MouseEnabled / IS_TOUCH)")
    bind_hint = hint_block(function_body(wmap, "function WorldMap.BindKey("))
    open_hint = hint_block(function_body(wmap, "function WorldMap.Open("))
    wm_shows = function_body(wmap, "function WorldMap.ShowsKeys(")
    check(bind_hint != "" and open_hint != "" and "WorldMap.ShowsKeys()" in bind_hint and "WorldMap.ShowsKeys()" in open_hint
          and not DEVICE_FLAGS.search(bind_hint) and not DEVICE_FLAGS.search(open_hint)
          and len(re.findall(r"hintLabel\.Text\s*=", wmap))
          == len(re.findall(r"hintLabel\.Text\s*=", bind_hint + open_hint)),
          "B5 one rule: WorldMap map hint (BindKey and Open, the only hintLabel.Text sites) goes through "
          "WorldMap.ShowsKeys() (no TouchEnabled / MouseEnabled)")
    check(wm_shows != "" and "kb.ShowsKeys()" in wm_shows and not DEVICE_FLAGS.search(wm_shows),
          "B5 one rule: WorldMap.ShowsKeys uses Keybinds.ShowsKeys (KeyboardEnabled before Keybinds is up; no TouchEnabled "
          "/ MouseEnabled)")
    intro = text_of("INTRO")
    skip_fn = function_body(intro, "function Intro.SkipText(")
    txt = intro_txt(intro)
    skip_key = re.search(r"^\s*SkipKey\s*=[^\n]*", txt, re.M)
    check(skip_fn != "" and "kb.ShowsKeys()" in skip_fn and not DEVICE_FLAGS.search(skip_fn)
          and skip_key is not None and not DEVICE_FLAGS.search(skip_key.group(0))
          and "TXT.SkipKey" not in intro.replace(skip_fn, "")
          and len(re.findall(r"Intro\.SkipText\(\)", intro.replace(skip_fn, ""))) >= 2,
          "B5 one rule: Intro skip text goes through Intro.SkipText() / Keybinds.ShowsKeys (TXT.SkipKey and SkipText test "
          "no TouchEnabled / MouseEnabled; TXT.SkipKey used only there; both skip buttons use Intro.SkipText())")
    return count, failures


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
    # every source is read once: the run, the static checks and every mutant use these same bytes
    raw = {key: path.read_bytes() for key, path in ALL_SOURCES.items()}
    sources = {key: value.decode("utf-8-sig").replace("\r\n", "\n") for key, value in raw.items()}
    fixture_raw = FIXTURE.read_bytes()

    compiled = subprocess.run([str(compiler), *(str(p) for p in FILES.values()), str(FIXTURE)], cwd=ROOT,
                              stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True,
                              encoding="utf-8", errors="replace", timeout=120)
    static_count, static_failures = static_checks(sources)

    def rel(key: str) -> str:
        return ALL_SOURCES[key].relative_to(ROOT).as_posix()

    with tempfile.TemporaryDirectory(prefix="keys_settings_offline_") as tmp:
        tmpdir = Path(tmp)
        main_run = run_harness(binary, make_harness(sources), tmpdir, "keys_settings_main.luau")
        result = main_run["result"]
        baseline = failing_keys(result)
        mutations = []
        if not args.no_mutations:
            jobs = []
            for name, key, old, new in MUTATIONS:
                hits = sources[key].count(old)
                if hits != 1:
                    mutations.append({"mutation": name, "file": rel(key), "applied": False,
                                      "caught": False, "note": f"pattern matched {hits} times; update MUTATIONS"})
                    continue
                mutated = dict(sources)
                mutated[key] = sources[key].replace(old, new, 1)
                jobs.append((name, key, mutated))

            def work(index_job):
                # a mutant is caught by new failing offline checks (or a crash) or by new failing static checks
                index, (name, key, mutated) = index_job
                out = run_harness(binary, make_harness(mutated), tmpdir, f"keys_settings_mutant_{index:02d}.luau")
                new_fail = sorted(failing_keys(out["result"]) - baseline)
                new_static = sorted(set(static_checks(mutated)[1]) - set(static_failures))
                crashed = out["result"] is None
                return {"mutation": name, "file": rel(key), "applied": True,
                        "caught": crashed or bool(new_fail) or bool(new_static), "crashed": crashed,
                        "newFailingChecks": new_fail[:6], "newFailingCount": len(new_fail),
                        "newFailingStatic": new_static}

            with ThreadPoolExecutor(max_workers=6) as pool:
                mutations.extend(pool.map(work, enumerate(jobs)))

    changed = [rel(key) for key, p in ALL_SOURCES.items() if p.read_bytes() != raw[key]]
    if FIXTURE.read_bytes() != fixture_raw:
        changed.append(FIXTURE.relative_to(ROOT).as_posix())
    marker = re.search(r"KEYS_SETTINGS_OFFLINE_OK checks=(\d+) Studio/API calls=0", main_run["stdout"])
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
        "mutations": {"total": len(MUTATIONS), "applied": applied, "caught": caught, "results": mutations},
        "compileOk": compiled.returncode == 0,
        "compileErrors": compiled.stderr.strip(),
        "runtimeError": None if result else (main_run["stderr"].strip() or main_run["stdout"].strip())[-2000:],
        "sourceSHA256": {rel(key): hashlib.sha256(raw[key]).hexdigest() for key in ALL_SOURCES},
        "fixtureSHA256": hashlib.sha256(fixture_raw).hexdigest(),
        "sourcesChangedDuringRun": changed,
        "studioCalls": 0, "apiCalls": 0,
        "contract": "docs/design/beta_basics_2026-10-05.md BB1 + BB2 (A23-21: PC keyboard keys only, fixed pad layout, "
                    "button names on touch-only devices): 18 actions (BB1 + SKL-1 SkillX) with the default keys / pad buttons, Reserved and "
                    "Allowed key sets, KeyMap collision rule (explicit first in Actions order, a taken explicit key -> '', "
                    "a live default-only action whose default is taken -> '' and reported once per session, non-live "
                    "actions hold no key, never wipe all keys), KeyLabel, SanitizeSettings (unknown keys dropped, sparse "
                    "Keys, Sfx clamp + 0.1 step, finite numbers, bools, enums), DataService fills Settings without a "
                    "Version bump, SettingsService (<= 1 argument, <= 16 top-level keys, Seq clamped 0..2^31, ready + 1 s "
                    "rate limit, dropped calls answered with nothing, owner-only echo, push on PlayerReady), Keybinds "
                    "(Get / ActionFor / Label / PadFor / SetLocal swap / Clear / Reset / Apply / Changed / Collisions / "
                    "Capture / Dispatch / prompts) and the Settings client (pull at Start, one pending blob at max(now, "
                    "lastSent + 1.05 s), Flush through the same slot, older echoes ignored, unsent changes kept, a blob "
                    "the server drops without an answer re-sent through the same slot, at most 5 times in a row). "
                    "Review fixes 2026-10-06: a non-live action's stale saved key never blanks a live action in SetLocal; "
                    "potion badges, quest-row key tokens and the in-flight resend are checked (static / offline). "
                    "Review B5 2026-10-06: the one key-hint rule is Keybinds.ShowsKeys() (= KeyboardEnabled == true): "
                    "Keybinds touchOnly / Label / Fill / the collision toast, HUD L.QuestText, WorldMap.ShowsKeys and both "
                    "map-hint sites, Intro TXT.SkipKey / Intro.SkipText run on six devices (desktop, touch laptop, keyboard "
                    "tablet: keys; phone, mouse tablet without keyboard, gamepad: no keys) and test no TouchEnabled / "
                    "MouseEnabled (static). Review of 27246d1: Interact always keeps a key the default ProximityPrompt draws "
                    "(SetLocal swap guard: no swap hands Interact CapsLock / KeypadOne / Minus / none; capture refuses "
                    "CapsLock / KeypadOne / empty for Interact with a NotAllowed toast and accepts G).",
        "limitations": "Offline doubles: virtual clock for os.clock / task.delay, cached EnumItems, remotes with a fixed "
                       "or scripted latency, DataStore table, Panels.Has from a registered-window set, UIKit.Toast recorder. "
                       "HUD / VitalsUI / GrudgeGhost / WorldMap / Panels / StoryQuestService wiring is only checked "
                       "statically, except the B5 key-hint code (HUD L.QuestText, WorldMap.ShowsKeys / HintText / the "
                       "BindKey and Open hint blocks, Intro TXT / SkipText), which is cut from the current source text and "
                       "run against the real Keybinds with a UserInputService double (KeyboardEnabled / TouchEnabled / "
                       "MouseEnabled); the rest of those modules does not run. Not certified here: real key presses in Studio, which non-letter keys Roblox swallows, "
                       "whether ProximityPrompt accepts a changed KeyboardKeyCode, real DataStore saves across rejoins, "
                       "multiple clients.",
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if compiled.returncode:
        print(compiled.stderr, end="")
    for line in main_run["stdout"].splitlines():
        if line.startswith("CHECK_FAIL") or line.startswith("KEYS_SETTINGS_OFFLINE"):
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
    for f in report["findings"]:
        print(f"FINDING [{f.get('Group')}] {f.get('Text')}")
    print(f"Named checks: {len(named) - len(failing)} passed, {len(failing)} failing; "
          f"assertions {report['checks'] - report['failedChecks']}/{report['checks']}")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if ok else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(f"Keys / settings offline check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
