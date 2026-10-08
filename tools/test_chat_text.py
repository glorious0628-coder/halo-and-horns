"""Roblox chat lines in English offline test (ChatText.luau, A23-48; 검수 2026-10-07: the team line showed in the
player's Roblox language). The place runs the legacy chat: its server modules send keyed lines
("{RBX_LOCALIZATION_KEY}key{RBX_LOCALIZATION_DEFAULT}English...") that each client translates. ChatText keeps only the
English text; the team-change line becomes Config.ChatText.Joined ("You joined the Horn Legion!") in the team colour in
the general channel (none for the auto-assigned team); Team / System lines move to the general channel (their tag is
translated too); the Team / System welcome lines are dropped; it hooks only on the legacy chat, existing and later
channels / speakers, and only warns when the ChatService is missing. Static: Main loads ChatText; Announce hooks the
TextChatService team line without reading ChatVersion.
Client (A23-74, user 2026-10-07: the Korean team line still showed): the main place reads ChatVersion =
LegacyChatService while Chat.IsAutoMigrated = true, so Roblox runs the new chat (TextChatService) anyway. Announce.Init
(before any module's Start) sets TextChatService.OnIncomingMessage whatever ChatVersion says; the team line (Metadata
Roblox.Team.Success.NowInTeam) becomes Config.ChatText in the team colour, escaped, without Hangul; every other message
comes back nil; a refused hookup only warns.
Runs the real ChatText.luau + Config.luau in tools/fixtures/chat_text_offline.luau and the real Announce.luau +
Config.luau in tools/fixtures/team_line_offline.luau.
Status "passed" only when both fixtures pass, the static checks pass AND every mutation was applied and caught.
Report: docs/art/verification_2026-10-07/offline_chat_text_2026-10-07.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
CHAT = ROOT / "src/ServerScriptService/ChatText.luau"
MAIN = ROOT / "src/ServerScriptService/Main.server.luau"
ANNOUNCE = ROOT / "src/StarterPlayer/StarterPlayerScripts/Announce.luau"
FIXTURE = ROOT / "tools/fixtures/chat_text_offline.luau"
CLIENT_FIXTURE = ROOT / "tools/fixtures/team_line_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-07/offline_chat_text_2026-10-07.json"

MUTATIONS = [
    ("the team line keeps Roblox's text", "\t\tif key == TEAM_LINE then\n", "\t\tif false then\n"),
    ("the team line stays in the Team channel", "return send(self, line, GENERAL, { ChatColor = color })",
     "return send(self, line, channelName, { ChatColor = color })"),
    ("no team colour", "return send(self, line, GENERAL, { ChatColor = color })", "return send(self, line, GENERAL, extraData)"),
    ("a line for the auto-assigned team", "if not team or team.AutoAssignable then return nil end", "if not team then return nil end"),
    ("Team / System lines keep their translated tag",
     "\t\tif type(channelName) == \"string\" and TAGGED[string.lower(channelName)] then channelName = GENERAL end\n", ""),
    ("other lines keep the key", "\t\treturn send(self, text, channelName, extraData)\n", "\t\treturn send(self, message, channelName, extraData)\n"),
    ("Team / System welcome lines stay", "\t\t\tif TAGGED[string.lower(tostring(self.Name))] then return \"\" end\n", ""),
    ("welcome lines keep the key", "return (ChatText.English(welcome(self, speaker)))", "return welcome(self, speaker)"),
    ("channel-wide lines keep the key", "return send(self, (ChatText.English(message)), extraData)", "return send(self, message, extraData)"),
    ("a speaker is wrapped twice", "if type(speaker) ~= \"table\" or speaker.HHC_English or", "if type(speaker) ~= \"table\" or"),
    ("speakers added later are missed", "\tchat.SpeakerAdded:Connect(function(name) ChatText.Speaker(chat:GetSpeaker(name)) end)\n", ""),
    ("channels added later are missed", "\tchat.ChannelAdded:Connect(function(name) ChatText.Channel(chat:GetChannel(name)) end)\n", ""),
    ("hooks on TextChatService too", "\tif not legacy then return end\n", ""),
    ("the parameter part stays in the text",
     "\tif paramStart then return string.sub(message, defEnd + 1, paramStart - 1), key end\n", ""),
]

# Announce.luau (client): each mutation is a list of (old, new) replacements, every old text must appear exactly once
CLIENT_MUTATIONS = [
    ("the hook waits for ChatVersion = TextChatService (the A23-74 bug)",
     [("pcall(function() TextChatService.OnIncomingMessage = A.Incoming end)",
       "pcall(function() if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then "
       "TextChatService.OnIncomingMessage = A.Incoming end end)")]),
    ("the hook is set in Start instead of Init",
     [("\tC = registry\n\tA.HookTeamLine()\n", "\tC = registry\n"),
      ('\tprint("[Announce] started")', '\tA.HookTeamLine()\n\tprint("[Announce] started")')]),
    ("the hook is never set", [("\tC = registry\n\tA.HookTeamLine()\n", "\tC = registry\n")]),
    # A23-75 (2026-10-08): the other lines go to C.ChatTags first (the VIP tag); without ChatTags they stay nil
    ("every message gets new properties",
     [('\t\treturn nil\n\tend\n\tlocal props = Instance.new("TextChatMessageProperties")',
       '\t\treturn Instance.new("TextChatMessageProperties")\n\tend\n\tlocal props = Instance.new("TextChatMessageProperties")')]),
    ("the team line keeps Roblox's text",
     [("props.Text = string.format('<font color=", "props.PrefixText = string.format('<font color=")]),
    ("the auto-assigned team gets a Joined line",
     [("if team and not team.AutoAssignable then text = string.format(Config.ChatText.Joined, team.Name) end",
       "if team then text = string.format(Config.ChatText.Joined, team.Name) end")]),
    ("no team colour", [("local color = team and team.TeamColor.Color or Color3.new(1, 1, 1)",
                         "local color = Color3.new(1, 1, 1)")]),
    ("the team name is not escaped", [("hex(color), escape(text))\n\treturn props", "hex(color), text)\n\treturn props")]),
    ("a refused hookup throws",
     [("local ok, err = pcall(function() TextChatService.OnIncomingMessage = A.Incoming end)",
       "TextChatService.OnIncomingMessage = A.Incoming\n\tlocal ok, err = true, nil")]),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run_fixture(fixture: Path, sources: dict, summary: str, name: str):
    path = ROOT / f"build/{fixture.stem}{name}.luau"
    head = "".join(f"local {var} = {lua_str(text)}\n" for var, text in sources.items())
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(head + fixture.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(summary + r" checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def run(config: str, chat: str, name: str):
    return run_fixture(FIXTURE, {"CONFIG_SOURCE": config, "CHAT_SOURCE": chat}, "CHAT_TEXT_SUMMARY", name)


def run_client(config: str, announce: str, name: str):
    return run_fixture(CLIENT_FIXTURE, {"CONFIG_SOURCE": config, "ANNOUNCE_SOURCE": announce}, "TEAM_LINE_SUMMARY", name)


def static_checks(main: str, announce: str, config: str):
    init = re.search(r"local INIT_ORDER = \{(.*?)\}", main, re.S)
    start = re.search(r"local START_ORDER = \{(.*?)\}", main, re.S)
    hook = re.search(r"\nfunction A\.HookTeamLine\(\)\n(.*?)\nend\n", announce, re.S)
    client_init = re.search(r"\nfunction Announce\.Init\(registry\)\n(.*?)\nend\n", announce, re.S)
    rows = [
        ("Main loads ChatText (INIT_ORDER)", bool(init and '"ChatText"' in init[1])),
        ("Main starts ChatText before PlayerService (START_ORDER)",
         bool(start and '"ChatText"' in start[1] and start[1].index('"ChatText"') < start[1].index('"PlayerService"'))),
        ("Announce hooks the TextChatService team line in Init, without reading ChatVersion (A23-74)",
         bool(hook and "TextChatService.OnIncomingMessage = A.Incoming" in hook[1] and "ChatVersion" not in hook[1])
         and bool(client_init and "A.HookTeamLine()" in client_init[1])
         and announce.count("TextChatService.OnIncomingMessage =") == 1
         and '"Roblox.Team.Success.NowInTeam"' in announce
         and "string.format(Config.ChatText.Joined, team.Name)" in announce),
        ("Config.ChatText lines are English (no Hangul)",
         bool(re.search(r"Config\.ChatText = \{(.*?)\n\}", config, re.S))
         and not re.search(r"[가-힣]", re.search(r"Config\.ChatText = \{(.*?)\n\}", config, re.S)[1].split("--")[0])),
    ]
    return rows


def main():
    config = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    chat = CHAT.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(config, chat, "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    rows = []
    for name, old, new in MUTATIONS:
        applied = chat.count(old) == 1
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run(config, chat.replace(old, new), "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    announce = ANNOUNCE.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    c_ok, c_checks, c_fails, c_result = run_client(config, announce, "")
    print(c_result.stdout, end="")
    print(c_result.stderr, end="")
    for name, pairs in CLIENT_MUTATIONS:
        mutated, applied = announce, True
        for old, new in pairs:
            applied = applied and mutated.count(old) == 1
            mutated = mutated.replace(old, new)
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run_client(config, mutated, "_mut")
            caught = not m_ok
        rows.append({"mutation": "client: " + name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: client: {name}")
    static = static_checks(MAIN.read_text(encoding="utf-8-sig").replace("\r\n", "\n"), announce, config)
    for name, good in static:
        print(("STATIC_OK " if good else "STATIC_FAILURE ") + name)
    passed = ok and c_ok and all(r["applied"] and r["caught"] for r in rows) and all(g for _, g in static)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "clientChecks": c_checks, "clientFailedChecks": c_fails,
              "static": [{"check": n, "ok": g} for n, g in static],
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in (CONFIG, CHAT, MAIN, ANNOUNCE)},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(),
              "clientFixtureSHA256": hashlib.sha256(CLIENT_FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "contract": __doc__.split("Status")[0].strip(),
              "limitations": "The doubles copy the legacy chat's shapes (Studio ExtraContent ServerChat/Speaker.lua, "
                             "ChatChannel.lua, ChatLocalization.lua) and a TextChatService that stores the "
                             "OnIncomingMessage callback; whether Roblox's new chat calls it for its team line and what "
                             "a Korean-language client finally shows is a Studio check (team pick, chat window)."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (checks {checks} + client {c_checks}, "
          f"mutations {report['mutations']['caught']}/{report['mutations']['total']})")


if __name__ == "__main__":
    main()
