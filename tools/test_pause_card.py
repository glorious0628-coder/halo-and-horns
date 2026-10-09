"""PauseCard offline check (SPEC A23-79 #1: the pause card "Saved! Next time: ..." and "Welcome back! Next: ... [Go]").

Runs the CURRENT src/StarterPlayer/StarterPlayerScripts/PauseCard.luau in tools/fixtures/pause_card_offline.luau with
the installed official Luau CLI (build/luau_cli_0_741): the player, the Fx remote, Remotes.Travel, Heartbeat, os.clock,
task, UIKit, Panels and the pickers are small doubles. Static: ClientMain loads PauseCard; no purchase prompt and no
MarketplaceService in it (no purchase button near the pause card, A23-79); no number in its words (no clock, no
countdown). Mutations: in-memory copies with one rule broken each; each must make a check fail. Status "passed" only when
the fixture passes, the static checks pass AND every mutation was applied and caught.
Report: docs/art/verification_2026-10-08/offline_pause_card_2026-10-08.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
CARD = SCRIPTS / "PauseCard.luau"
CLIENT_MAIN = SCRIPTS / "ClientMain.client.luau"
FIXTURE = ROOT / "tools/fixtures/pause_card_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-08/offline_pause_card_2026-10-08.json"

MUTATIONS = [
    ("a card over an open window", "\tif isOpen(C and C.Panels) then return true end\n", ""),
    ("a card on the KO screen", "\tif not hum or hum.Health <= 0 then return true end\n", "\tif not hum then return true end\n"),
    ("a card in the middle of a fight", "\tif os.clock() - S.HurtAt < T.HurtCalm then return true end\n", ""),
    ("a card over a reward popup", "\t\t\t\tif kit.Gui:FindFirstChild(name) then return true end\n", ""),
    ("a card during the first steps", "\t\t\tif ok and hold then return true end\n", ""),
    ("a card before the data loaded", 'if not LocalPlayer or LocalPlayer:GetAttribute("DataLoaded") ~= true then return true end',
     "if not LocalPlayer then return true end"),
    ("a stale card still shows", "\tif os.clock() - card.At > T.WaitMax then\n", "\tif false then\n"),
    ("two cards at once", "\tif not card or PauseCard.IsOpen() then return end\n", "\tif not card then return end\n"),
    ("the waiting card never comes", "\t\ttask.defer(PauseCard.Tick) -- a card that waited for this one\n", ""),
    ("[Go] goes nowhere", "\t\tif id == \"Go\" and card.Zone then travel(card.Zone) end\n", ""),
    ("another player's card shows", "\tif type(data) == \"table\" and data.UserId ~= nil and LocalPlayer and data.UserId ~= LocalPlayer.UserId then return end\n", ""),
    ("the two buttons look different", "\t\tkit.ArtTextButton(\"BtnConfirm\", {\n",
     "\t\tkit.ArtTextButton(i == 1 and \"BtnConfirm\" or \"BtnSecondary\", {\n"),
    ("no metrics signal", "\t\tPauseCard.Shown:Fire(card.Kind, id, card.Why)\n", ""),
    ("a long goal is not cut", "\tif n and n > max then\n", "\tif false then\n"),
    ("brackets kept in the goal", 'local s = string.gsub(string.gsub(text, "[<>]", ""), "%s+", " ")',
     'local s = string.gsub(text, "%s+", " ")'),
    ("the backdrop does not close", "\toverlay.Activated:Connect(function() pick(\"Backdrop\") end)\n", ""),
    # A23-81 the tip card
    ("a tip's [Go] opens nothing", "\t\tif id == \"Go\" and card.Window then openWindow(card.Window, card.WindowArg) end\n", ""),
    ("a tip without words shows", "\t\tif not text then return false end\n", ""),
    ("a tip's window loses its tab", "\treturn (pcall(panels.Open, id, arg))\n", "\treturn (pcall(panels.Open, id))\n"),
    ("a tip always has [Go]",
     "\t\tcard.Buttons = go and { { Id = \"Go\", Text = clean(go.Text, T.NextMax) or T.Text.Go }, { Id = \"OK\", Text = T.Text.OK } }\n",
     "\t\tcard.Buttons = { { Id = \"Go\", Text = T.Text.Go }, { Id = \"OK\", Text = T.Text.OK } }\n"),
    # A23-79 게임성 개발 3's contract
    ("no tomorrow line", "\t\tif tomorrow then card.Body ..= \"\\n\" .. string.format(T.Text.PauseTomorrow, tomorrow) end\n", ""),
    ("tomorrow's line not cut", "\t\tlocal tomorrow = clean(data.Tomorrow, T.TomorrowMax)\n", "\t\tlocal tomorrow = clean(data.Tomorrow, 999)\n"),
    ("the OptIn flag ignored", "\t\tif card.OptIn then task.defer(comeBack, \"OptIn\", \"Daily\") end -- after the card, never over it\n", ""),
    ("any OptIn value counts", "\t\tcard.OptIn = data.OptIn == true\n", "\t\tcard.OptIn = data.OptIn ~= nil and data.OptIn ~= false\n"),
    ("WelcomeBackGo never counted", "\t\tif id == \"Go\" and card.Kind == \"Back\" then comeBack(\"Metric\", \"WelcomeBackGo\") end\n", ""),
    ("every [Go] counted as WelcomeBackGo", "\t\tif id == \"Go\" and card.Kind == \"Back\" then comeBack(", "\t\tif id == \"Go\" then comeBack("),
    ("Waiting always false", "\treturn S.Pending ~= nil\n", "\treturn false\n"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(src: str, name: str):
    path = ROOT / f"build/pause_card_offline{name}.luau"
    path.write_text("local CARD_SOURCE = " + lua_str(src) + "\n" + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"PAUSE_CARD_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    src = CARD.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
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
    words = re.search(r"\tText = \{(.*?)\n\t\},", src, re.S)
    static = [
        ("ClientMain loads PauseCard", "PauseCard" in names),
        ("no purchase prompt near the pause card (A23-79)",
         not re.search(r"PromptGamePassPurchase|PromptProductPurchase|MarketplaceService", code)),
        ("no number in the card's words (no clock, no countdown)", bool(words) and not re.search(r"\d", words[1])),
    ]
    for name, good in static:
        print(("STATIC_OK " if good else "STATIC_FAILURE ") + name)
    passed = ok and all(r["applied"] and r["caught"] for r in rows) and all(g for _, g in static)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "static": [{"check": n, "ok": g} for n, g in static],
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in (CARD, CLIENT_MAIN)},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "limitations": "Doubles instead of the engine: the card's look on PC and phone (DialogBox plate, button art) "
                             "and the server's PauseCard / WelcomeBack Fx (게임성 개발 2, not built yet) are Studio checks."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")


if __name__ == "__main__":
    main()
