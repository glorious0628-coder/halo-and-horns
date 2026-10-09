"""Invite offline check (SPEC A23-79 #3: [Invite a friend] + "Your friend joined! [Go to friend]").

Runs the CURRENT src/StarterPlayer/StarterPlayerScripts/Invite.luau in tools/fixtures/invite_offline.luau with the
installed official Luau CLI (build/luau_cli_0_741): SocialService / Players / the Humanoid / Panels / UIKit / the
Remotes folder / os.clock are small doubles. Static: ClientMain loads Invite; no invite reward anywhere in it (A23-68).
Mutations: in-memory copies with one rule broken each; each must make a check fail. Status "passed" only when the
fixture passes, the static checks pass AND every mutation was applied and caught.
Report: docs/art/verification_2026-10-08/offline_invite_2026-10-08.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
INVITE = SCRIPTS / "Invite.luau"
CLIENT_MAIN = SCRIPTS / "ClientMain.client.luau"
FIXTURE = ROOT / "tools/fixtures/invite_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-08/offline_invite_2026-10-08.json"

MUTATIONS = [
    ("the invite shows while knocked out", "\tif not LocalPlayer or knockedOut() then return false end\n",
     "\tif not LocalPlayer then return false end\n"),
    ("the invite right after a failed scroll", "\tif os.clock() - S.FailAt < T.FailCalm then return false end\n", ""),
    ("the invite inside the Shop", "\t\tif ok and id == T.ShopWindow then return false end\n", ""),
    ("no LaunchData (the server cannot tell who invited)", "\t\toptions.LaunchData = tostring(LocalPlayer.UserId)\n", ""),
    ("Roblox's 'no invites' ignored", "\tif not okCan or can ~= true then return false end\n", "\tif not okCan then return false end\n"),
    ("every newcomer is a friend", "\tif not ok or friend ~= true or player.Parent ~= Players or S.Seen[player.UserId] then return end\n",
     "\tif not ok or player.Parent ~= Players or S.Seen[player.UserId] then return end\n"),
    ("the friend line repeats", "\tS.Seen[player.UserId] = true\n", ""),
    ("a scroll that worked hides it too", 'if kind == "Enhance" and type(data) == "table" and data.Success == false then',
     'if kind == "Enhance" and type(data) == "table" then'),
    ("Go to friend fires for a friend who left", "\tif typeof(player) ~= \"Instance\" or not player:IsA(\"Player\") or player.Parent ~= Players then return false end\n",
     "\tif typeof(player) ~= \"Instance\" or not player:IsA(\"Player\") then return false end\n"),
    ("Go to friend without the UserId", "\tlocal ok = pcall(remote.FireServer, remote, player.UserId)\n",
     "\tlocal ok = pcall(remote.FireServer, remote)\n"),
    ("the plain line under the friend card too", "\tif Invite.DefaultLine ~= true then return end\n", ""),
    ("no InvitePrompt count", "\tif ok and source ~= nil then metric(\"InvitePrompt\", source) end\n", ""),
    ("InvitePrompt counted when nothing opened", "\tif ok and source ~= nil then metric(\"InvitePrompt\", source) end\n",
     "\tif source ~= nil then metric(\"InvitePrompt\", source) end\n"),
    ("InviteSeen every time", "\tS.Shown[source] = true\n", ""),
    ("InviteSent with nobody picked", " or #recipientIds < 1 then return nil end\n", " then return nil end\n"),
    ("someone else's invite window counted", "\tif player ~= LocalPlayer or type(recipientIds)", "\tif type(recipientIds)"),
    ("InviteSent over 50", "\tlocal n = math.min(#recipientIds, 50)\n", "\tlocal n = #recipientIds\n"),
    ("the closed window not watched", "\t\t\tpcall(Invite.Closed, player, recipientIds)\n", ""),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(src: str, name: str):
    path = ROOT / f"build/invite_offline{name}.luau"
    path.write_text("local INVITE_SOURCE = " + lua_str(src) + "\n" + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"INVITE_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    src = INVITE.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(src, "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    rows = []
    for name, old, new in MUTATIONS:
        applied = src.count(old) == 1
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run(src.replace(old, new), "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    cm = CLIENT_MAIN.read_text(encoding="utf-8-sig")
    order = re.search(r"local ORDER = \{([^}]*)\}", cm)
    names = re.findall(r'"([A-Za-z]+)"', order[1]) if order else []
    code = "\n".join(line.split("--", 1)[0] for line in src.splitlines())
    static = [
        ("ClientMain loads Invite", "Invite" in names),
        ("no invite reward in the client (A23-68)", not re.search(r"Reward|Gold|Gems|Stars", code)),
    ]
    for name, good in static:
        print(("STATIC_OK " if good else "STATIC_FAILURE ") + name)
    passed = ok and all(r["applied"] and r["caught"] for r in rows) and all(g for _, g in static)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "static": [{"check": n, "ok": g} for n, g in static],
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in (INVITE, CLIENT_MAIN)},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "limitations": "Doubles instead of SocialService: Roblox's invite window (and whether a friend's join "
                             "carries the LaunchData) is a Studio / live check with two accounts; the buttons' places are "
                             "이미지 개발's layout."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")


if __name__ == "__main__":
    main()
