"""Roblox chat lines in English offline test (ChatText.luau, A23-48; 검수 2026-10-07: the team line showed in the
player's Roblox language). The place runs the legacy chat: its server modules send keyed lines
("{RBX_LOCALIZATION_KEY}key{RBX_LOCALIZATION_DEFAULT}English...") that each client translates. ChatText keeps only the
English text; the team-change line becomes Config.ChatText.Joined ("You joined the Horn Legion!") in the team colour in
the general channel (none for the auto-assigned team); Team / System lines move to the general channel (their tag is
translated too); the Team / System welcome lines are dropped; it hooks only on the legacy chat, existing and later
channels / speakers, and only warns when the ChatService is missing. Static: Main loads ChatText; Announce rewrites the
TextChatService team line (Metadata Roblox.Team.Success.NowInTeam) with Config.ChatText.
Runs the real ChatText.luau + Config.luau in tools/fixtures/chat_text_offline.luau.
Status "passed" only when the fixture passes, the static checks pass AND every mutation was applied and caught.
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


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(config: str, chat: str, name: str):
    path = ROOT / f"build/chat_text_offline{name}.luau"
    path.write_text("local CONFIG_SOURCE = " + lua_str(config) + "\nlocal CHAT_SOURCE = " + lua_str(chat) + "\n"
                    + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"CHAT_TEXT_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def static_checks(main: str, announce: str, config: str):
    init = re.search(r"local INIT_ORDER = \{(.*?)\}", main, re.S)
    start = re.search(r"local START_ORDER = \{(.*?)\}", main, re.S)
    rows = [
        ("Main loads ChatText (INIT_ORDER)", bool(init and '"ChatText"' in init[1])),
        ("Main starts ChatText before PlayerService (START_ORDER)",
         bool(start and '"ChatText"' in start[1] and start[1].index('"ChatText"') < start[1].index('"PlayerService"'))),
        ("Announce rewrites the TextChatService team line",
         'message.Metadata == "Roblox.Team.Success.NowInTeam"' in announce
         and "string.format(Config.ChatText.Joined, team.Name)" in announce
         and "TextChatService.OnIncomingMessage = A.Incoming" in announce
         and "TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then" in announce),
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
    static = static_checks(MAIN.read_text(encoding="utf-8-sig").replace("\r\n", "\n"),
                           ANNOUNCE.read_text(encoding="utf-8-sig").replace("\r\n", "\n"), config)
    for name, good in static:
        print(("STATIC_OK " if good else "STATIC_FAILURE ") + name)
    passed = ok and all(r["applied"] and r["caught"] for r in rows) and all(g for _, g in static)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "static": [{"check": n, "ok": g} for n, g in static],
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in (CONFIG, CHAT, MAIN, ANNOUNCE)},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "contract": __doc__.split("Status")[0].strip(),
              "limitations": "The doubles copy the legacy chat's shapes (Studio ExtraContent ServerChat/Speaker.lua, "
                             "ChatChannel.lua, ChatLocalization.lua); what a Korean-language client finally shows is a "
                             "Studio check (team pick, chat window)."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")


if __name__ == "__main__":
    main()
