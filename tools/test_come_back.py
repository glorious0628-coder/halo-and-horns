"""ComeBack offline check (SPEC A23-79, 게임성 개발 3's contract: c->s "ClientMetric" with the server's argument rules,
the notification opt-in moment (#5) and the My Way line (#2)).

Runs the CURRENT src/StarterPlayer/StarterPlayerScripts/ComeBack.luau with the CURRENT Config.luau in
tools/fixtures/come_back_offline.luau with the installed official Luau CLI (build/luau_cli_0_741): the player, the
Remotes folder, ExperienceNotificationService, MarketplaceService, the Fx remote, PauseCard and UIKit are small doubles;
os.clock is a number task.wait moves. Static: ClientMain loads ComeBack after PauseCard; PauseCard / Invite / Panels call
it; the words are English; no purchase prompt in it. Mutations: in-memory copies with one rule broken each; each must make
a check fail. Status "passed" only when the fixture passes, the static checks pass AND every mutation was applied and
caught. Report: docs/art/verification_2026-10-08/offline_come_back_2026-10-08.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
MODULE = SCRIPTS / "ComeBack.luau"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
CLIENT_MAIN = SCRIPTS / "ClientMain.client.luau"
FIXTURE = ROOT / "tools/fixtures/come_back_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-08/offline_come_back_2026-10-08.json"

MUTATIONS = [
    ("'None' takes an argument", "\tif rule == \"None\" then return arg == nil end\n", "\tif rule == \"None\" then return true end\n"),
    ("a count above 50", " and arg >= 1 and arg <= 50 end\n", " and arg >= 1 end\n"),
    ("any invite source", "\tif rule == \"Source\" then return type(arg) == \"string\" and table.find(A.InviteSources or {}, arg) ~= nil end\n",
     "\tif rule == \"Source\" then return type(arg) == \"string\" end\n"),
    ("any pass id", "\t\treturn type(arg) == \"string\" and #arg <= 32 and (table.find(A.PassIds or {}, arg) ~= nil\n",
     "\t\treturn type(arg) == \"string\" or (table.find(A.PassIds or {}, arg) ~= nil\n"),
    ("unknown ids sent", "\tif rule == nil or not ComeBack.ArgOk(rule, arg) then return false end\n", "\tif false then return false end\n"),
    ("no rate limit", "\tif S.SentAt[id] and now - S.SentAt[id] < gap then return false end\n", ""),
    ("an argument sent with 'None'", "\tif arg == nil then\n\t\tok, err = pcall(remote.FireServer, remote, id)\n",
     "\tif false then\n\t\tok, err = pcall(remote.FireServer, remote, id)\n"),
    ("the opt-in in the first 10 minutes", "\tif played < cfg(\"MinPlaySeconds\", 600) or not ComeBack.Calm() then return false end\n",
     "\tif not ComeBack.Calm() then return false end\n"),
    ("the opt-in right after a KO / a failed scroll / a purchase", "\tfor _, at in { S.KOAt, S.FailAt, S.BuyAt } do\n",
     "\tfor _, at in {} do\n"),
    ("the opt-in while knocked out", "\treturn hum ~= nil and hum.Health > 0\n", "\treturn true\n"),
    ("a failed scroll ignored", "\t\tS.FailAt = os.clock()\n", ""),
    ("a PurchasePrompt ignored", "\tif id == \"PurchasePrompt\" then S.BuyAt = now end\n", ""),
    ("a finished purchase window ignored", "\t\t\tif player == LocalPlayer then ComeBack.Bought() end\n", ""),
    ("anyone's purchase counts", "\t\t\tif player == LocalPlayer then ComeBack.Bought() end\n", "\t\t\tComeBack.Bought()\n"),
    ("the opt-in twice a session", "\tS.OptInAsked = true -- one moment a session (the server sends at most one too)\n", ""),
    ("no wait for a calm screen", "\t\tuntil not screenBusy() and ComeBack.Calm()\n", "\t\tuntil true\n"),
    ("a pause card waiting is ignored", "\tfor _, name in { \"IsOpen\", \"Waiting\", \"Busy\" } do\n", "\tfor _, name in { \"IsOpen\", \"Busy\" } do\n"),
    ("a stale moment kept for 15 minutes", "\tWaitMax = 90, -- s the opt-in moment may wait for a calm screen\n", "\tWaitMax = 900,\n"),
    ("'cannot' not reported", "\t\tComeBack.Metric(\"OptIn\", \"cannot\")\n", ""),
    ("'shown' before the window closed", "\tif closed then ComeBack.Metric(\"OptIn\", \"shown\") end\n", "\tComeBack.Metric(\"OptIn\", \"shown\")\n"),
    ("an erroring check counts as 'cannot'", "\tif not okCan then\n\t\tUtil.Warn(TAG, \"CanPromptOptInAsync failed: \" .. tostring(can))\n\t\treturn\n\tend\n", ""),
    ("Fx OptInMoment ignored", "\t\tComeBack.OptIn(type(data) == \"table\" and data.Why or nil)\n", ""),
    ("My Way speaks at the join", "\tif first or name == \"\" or name == before then return nil end\n",
     "\tif name == \"\" or name == before then return nil end\n"),
    ("My Way speaks for no name", "\tif first or name == \"\" or name == before then return nil end\n",
     "\tif first or name == before then return nil end\n"),
    ("My Way repeats the same name", "\tif first or name == \"\" or name == before then return nil end\n", "\tif first or name == \"\" then return nil end\n"),
    ("My Way line for 5 s", "\tMyWaySeconds = 2,\n", "\tMyWaySeconds = 5,\n"),
    ("a name there at the start counts as new", "\tif LocalPlayer:GetAttribute(\"MyWay\") ~= nil then ComeBack.OnMyWay(LocalPlayer:GetAttribute(\"MyWay\")) end\n", ""),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(src: str, config: str, name: str):
    path = ROOT / f"build/come_back_offline{name}.luau"
    path.write_text("local CONFIG_SOURCE = " + lua_str(config) + "\nlocal COMEBACK_SOURCE = " + lua_str(src) + "\n"
                    + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"COME_BACK_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    src = MODULE.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    config = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(src, config, "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    rows = []
    for name, old, new in MUTATIONS:
        applied = src.count(old) == 1
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run(src.replace(old, new), config, "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    cm = CLIENT_MAIN.read_text(encoding="utf-8-sig")
    order = re.search(r"local ORDER = \{([^}]*)\}", cm)
    names = re.findall(r'"([A-Za-z]+)"', order[1]) if order else []
    code = "\n".join(line.split("--", 1)[0] for line in src.splitlines())
    words = re.search(r"\tText = \{(.*?)\},", src, re.S)
    pause = (SCRIPTS / "PauseCard.luau").read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    invite = (SCRIPTS / "Invite.luau").read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    panels = (SCRIPTS / "Panels.luau").read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    static = [
        ("ClientMain loads ComeBack after PauseCard", "ComeBack" in names and "PauseCard" in names
         and names.index("ComeBack") > names.index("PauseCard")),
        ("the words are English (A23-48)", bool(words) and not re.search(r"[가-힣]", words[1])),
        ("no purchase prompt in it (A23-79)", not re.search(r"PromptGamePassPurchase\(|PromptProductPurchase\(|PromptPurchase\(", code)),
        ("the daily pause card hands its OptIn to ComeBack after closing; [Go] on welcome back counts",
         'if card.OptIn then task.defer(comeBack, "OptIn", "Daily") end' in pause
         and 'if id == "Go" and card.Kind == "Back" then comeBack("Metric", "WelcomeBackGo") end' in pause),
        ("Invite counts the seen button, the opened window and the friends picked",
         'metric("InviteSeen", source)' in invite and 'metric("InvitePrompt", source)' in invite and 'metric("InviteSent", n)' in invite),
        ("every Shop opening counts (ShopOpen)", 'if id == "Shop" and C and type(C.ComeBack) == "table" then pcall(C.ComeBack.Metric, "ShopOpen") end' in panels),
    ]
    for name, good in static:
        print(("STATIC_OK " if good else "STATIC_FAILURE ") + name)
    passed = ok and all(r["applied"] and r["caught"] for r in rows) and all(g for _, g in static)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "static": [{"check": n, "ok": g} for n, g in static],
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in (MODULE, CONFIG, CLIENT_MAIN)},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "limitations": "Doubles instead of ExperienceNotificationService: Roblox's own opt-in window shows only in a "
                             "published game for 13+ accounts (Studio cannot show it), so 'shown' needs a live check; "
                             "the server's side (the asked list, the once rule) is tools/test_return.py. The Shop's "
                             "PassView / PurchasePrompt calls belong to 이미지 개발's ShopUI (ComeBack.Metric is ready)."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")


if __name__ == "__main__":
    main()
