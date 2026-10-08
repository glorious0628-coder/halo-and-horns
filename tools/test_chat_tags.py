"""ChatTags offline check (SPEC A23-75 the VIP pass: a gold [VIP] before a VIP's name in the chat).

Runs the CURRENT src/StarterPlayer/StarterPlayerScripts/ChatTags.luau in tools/fixtures/chat_tags_offline.luau with the
installed official Luau CLI (build/luau_cli_0_741): Players / player attributes / TextChatMessageProperties are small
doubles. Static: ClientMain loads ChatTags after Announce, Announce (the one owner of TextChatService.OnIncomingMessage)
hands non-team lines to C.ChatTags.Incoming, nothing else sets the callback.
Mutations: in-memory copies with one rule broken each; each must make a check fail. Status "passed" only when the
fixture passes, the static checks pass AND every mutation was applied and caught.
Report: docs/art/verification_2026-10-08/offline_chat_tags_2026-10-08.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
TAGS = SCRIPTS / "ChatTags.luau"
ANNOUNCE = SCRIPTS / "Announce.luau"
CLIENT_MAIN = SCRIPTS / "ClientMain.client.luau"
FIXTURE = ROOT / "tools/fixtures/chat_tags_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-08/offline_chat_tags_2026-10-08.json"

MUTATIONS = [
    ("everyone is tagged VIP", "\tif player:GetAttribute(T.Attr) ~= true then return nil end\n", ""),
    ("the tag goes after the name",
     "\treturn string.format('<font color=\"%s\">[%s]</font> %s', T.Color, T.Tag, type(prefixText) == \"string\" and prefixText or \"\")\n",
     "\treturn (type(prefixText) == \"string\" and prefixText or \"\") .. string.format(' <font color=\"%s\">[%s]</font>', T.Color, T.Tag)\n"),
    ("system lines are tagged too", "\tif not source then return nil end\n", "\tif not source then source = { UserId = 1 } end\n"),
    ("the wrong attribute", 'Attr = "PassVIP",', 'Attr = "VIP",'),
    ("the prefix is not set", "\tprops.PrefixText = prefix\n", ""),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(tags: str, name: str):
    path = ROOT / f"build/chat_tags_offline{name}.luau"
    path.write_text("local TAGS_SOURCE = " + lua_str(tags) + "\n" + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"CHAT_TAGS_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    tags = TAGS.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(tags, "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    rows = []
    for name, old, new in MUTATIONS:
        applied = tags.count(old) == 1
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run(tags.replace(old, new), "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    cm = CLIENT_MAIN.read_text(encoding="utf-8-sig")
    order = re.search(r"local ORDER = \{([^}]*)\}", cm)
    names = re.findall(r'"([A-Za-z]+)"', order[1]) if order else []
    announce = ANNOUNCE.read_text(encoding="utf-8-sig")
    incoming = announce[announce.find("function A.Incoming"):announce.find("function A.HookTeamLine")]
    setters = [p.relative_to(ROOT).as_posix() for p in SCRIPTS.rglob("*.luau")
               if re.search(r"OnIncomingMessage\s*=", p.read_text(encoding="utf-8-sig"))]
    static = [
        ("ClientMain loads ChatTags after Announce", "ChatTags" in names and "Announce" in names
         and names.index("Announce") < names.index("ChatTags")),
        ("Announce hands the non-team lines to C.ChatTags.Incoming", "ChatTags" in incoming and "Incoming" in incoming),
        ("only Announce sets TextChatService.OnIncomingMessage", setters == ["src/StarterPlayer/StarterPlayerScripts/Announce.luau"]),
    ]
    for name, good in static:
        print(("STATIC_OK " if good else "STATIC_FAILURE ") + name)
    passed = ok and all(r["applied"] and r["caught"] for r in rows) and all(g for _, g in static)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "static": [{"check": n, "ok": g} for n, g in static],
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in (TAGS, ANNOUNCE, CLIENT_MAIN)},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "limitations": "Doubles instead of TextChatService: how the tag looks in the real chat window (and on phones) "
                             "is a Studio check with a VIP test player."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")


if __name__ == "__main__":
    main()
