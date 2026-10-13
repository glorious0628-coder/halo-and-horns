"""ChoiceCardUI offline check (gameplay_plan 2026-10-13 2-A #3: the shared choice card window + the afterglow).

Runs the CURRENT src/StarterPlayer/StarterPlayerScripts/ChoiceCardUI.luau with the CURRENT Config.luau and Util.luau in
tools/fixtures/choice_card_ui_offline.luau with the official Luau CLI (build/luau_cli_0_741): Panels, the window kit,
Net, PauseCard, Fx and the players are small doubles. Covers: the pure lines (reward / score / hints), the finisher card
(timed: opens at once, its Config.Finisher.Cards words, countdown, one pick -> FinisherPick (id, Help|Tickle), locked
until the end, closes on its end or when time is up), the ChoiceCard card (saved: waits for a calm screen - no fight,
not busy, no other window, not dead -, closed by hand comes back after Screen.Later s, CardAction (id, Good|Evil), a pick
without an answer unlocks after Wait), a timed card over a saved one holds it back and gives it back, broken payloads,
and the afterglow (gold sparkles / purple smoke at the feet, replaced, ends after Seconds, the Config switch).
Static: ClientMain loads it after Panels / PauseCard / Fx; the Panels kit hands out the approved choice button; the
remotes exist; nothing is sold near the card (A23-79); English words; built-in particle textures only (no ray art).
Mutations: in-memory copies with one rule broken each; each must make a check fail.
Report: docs/art/verification_2026-10-14/offline_choice_card_ui_2026-10-14.json (do not commit)
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
MODULE = SCRIPTS / "ChoiceCardUI.luau"
PANELS = SCRIPTS / "Panels.luau"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
UTIL = ROOT / "src/ReplicatedStorage/Shared/Util.luau"
NET = ROOT / "src/ReplicatedStorage/Shared/Net.luau"
CLIENT_MAIN = SCRIPTS / "ClientMain.client.luau"
FIXTURE = ROOT / "tools/fixtures/choice_card_ui_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-14/offline_choice_card_ui_2026-10-14.json"

MUTATIONS = [
    ("the item count dropped", "fmt(sc.Item, math.max(1, int(r.N, 1)), itemName(item))", "fmt(sc.Item, 1, itemName(item))"),
    ("the gold part forgotten", "\tif int(r.Gold) > 0 then table.insert(parts, fmt(sc.Gold, bigNum(int(r.Gold)))) end\n", ""),
    ("a minus shown as a plus", "return score > 0 and fmt(t.Score, name, score) or fmt(t.ScoreDown, name, -score)",
     "return fmt(t.Score, name, score)"),
    ("the save key 'Infamy' shown (A23-166)", "local name = type(names[stat]) == \"string\" and names[stat] or stat",
     "local name = stat"),
    ("the Full hint missing", "\tif hint == \"Full\" then return t.HintFull or \"\" end\n", ""),
    ("the finisher's sides swapped", 'Good = option(p.Help, words.Help, "Good", "Help"), Evil = option(p.Tickle, words.Tickle, "Evil", "Tickle")',
     'Good = option(p.Help, words.Help, "Good", "Tickle"), Evil = option(p.Tickle, words.Tickle, "Evil", "Help")'),
    ("a finisher with no timer", "Stat = p.Stat, Ends = (now or 0) + math.max(1, secs), Seconds = secs,", "Stat = p.Stat, Ends = nil, Seconds = secs,"),
    ("the card's own title ignored", "Title = (type(p.Title) == \"string\" and p.Title ~= \"\") and p.Title or screen().Title or \"\",",
     "Title = screen().Title or \"\","),
    ("a saved card over a fight", "\tif ctx.Fight or ctx.Busy or ctx.Window ~= nil then return false end\n",
     "\tif ctx.Busy or ctx.Window ~= nil then return false end\n"),
    ("a saved card over another window", "\tif ctx.Fight or ctx.Busy or ctx.Window ~= nil then return false end\n",
     "\tif ctx.Fight or ctx.Busy then return false end\n"),
    ("a card while dead", "\tif ctx.Dead then return false end\n", ""),
    ("closed by hand comes back at once", "\t\tS.LaterUntil = os.clock() + math.max(1, int(screen().Later, 30))\n", ""),
    ("pick spam", "\tif os.clock() - S.SentAt < L.Wait then return end\n", ""),
    ("a pick after the time", "\tif card.Ends and os.clock() > card.Ends then return end\n", ""),
    ("the buttons never lock", "\tS.SentAt = os.clock()\n\tlock(true)\n", "\tS.SentAt = os.clock()\n"),
    ("the time-up keeps the window", "\t\tif p and windowOpen() == L.Window then pcall(p.Close) end\n", ""),
    ("any end closes any card", "\tif not card or card.Src ~= src or card.Id ~= id then return end\n", "\tif not card then return end\n"),
    ("a saved card lost under a timed one", "\tif old and not old.Ends and card.Ends and old.Src ~= card.Src then\n\t\tS.Held = old\n",
     "\tif false then\n\t\tS.Held = old\n"),
    ("a held card kept after its end", "\tif held and held.Src == src and held.Id == id then S.Held = nil return end\n", ""),
    ("the countdown stands still", "\tif VIEW.Count then VIEW.Count.Text = fmt(screen().Seconds, math.ceil(left)) end\n", ""),
    ("the glow at the hips", "att.Position = Vector3.new(0, -(root.Size.Y / 2 + math.max(0, hum.HipHeight)) + 0.2, 0)",
     "att.Position = Vector3.new(0, 0, 0)"),
    ("two glows at once", "\tstopGlow(payload.UserId)\n\tlocal att = Instance.new(\"Attachment\")",
     "\tlocal att = Instance.new(\"Attachment\")"),
    ("the glow never ends", "\t\tif S.Glows[payload.UserId] == entry then stopGlow(payload.UserId) end\n", ""),
    ("the Afterglow switch ignored", "if type(A) ~= \"table\" or A.Enabled ~= true or type(payload) ~= \"table\" then return end",
     "if type(A) ~= \"table\" or type(payload) ~= \"table\" then return end"),
    ("evil glows gold", 'Evil = { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = Color3.fromRGB(150, 92, 205),',
     'Evil = { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = Color3.fromRGB(255, 214, 90),'),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(src: str, config: str, util: str, name: str):
    path = ROOT / f"build/choice_card_ui_offline{name}.luau"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("local CONFIG_SOURCE = " + lua_str(config) + "\nlocal UTIL_SOURCE = " + lua_str(util)
                    + "\nlocal UI_SOURCE = " + lua_str(src) + "\n" + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"CHOICE_CARD_UI_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    src = MODULE.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    config = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    util = UTIL.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(src, config, util, "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    rows = []
    for name, old, new in MUTATIONS:
        applied = src.count(old) == 1
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run(src.replace(old, new), config, util, "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    cm = CLIENT_MAIN.read_text(encoding="utf-8-sig")
    order = re.search(r"local ORDER = \{([^}]*)\}", cm)
    names = re.findall(r'"([A-Za-z]+)"', order[1]) if order else []
    code = "\n".join(line.split("--", 1)[0] for line in src.splitlines())
    panels = PANELS.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    net = NET.read_text(encoding="utf-8-sig")
    screen = re.search(r"\nConfig\.ChoiceCard\.Screen = \{(.*?)\n\}\n", config, re.S)
    words = "\n".join(ln.split("--", 1)[0] for ln in screen[1].splitlines()) if screen else ""
    textures = re.findall(r'Texture = "([^"]+)"', src)
    static = [
        ("ClientMain loads ChoiceCardUI after Panels, PauseCard and Fx", "ChoiceCardUI" in names
         and all(n in names and names.index("ChoiceCardUI") > names.index(n) for n in ("Panels", "PauseCard", "Fx"))),
        ("the Panels kit hands out the story pick's approved button", "ChoiceButton = STORY.ChoiceButton," in panels),
        ("the remotes exist (Net)", all(f'"{r}"' in net for r in ("CardAction", "FinisherPick"))),
        ("nothing is sold near the card (A23-79)", not re.search(r"MarketplaceService|Prompt[A-Za-z]*Purchase|ShopUI|\"Shop\"", code)),
        ("the window's words are English (A23-48)", bool(words) and not re.search(r"[가-힣]", words)),
        ("built-in particle textures only (round sparkles / smoke, no ray art)", textures == [
            "rbxasset://textures/particles/sparkles_main.dds", "rbxasset://textures/particles/smoke_main.dds"]),
        ("the finisher's words stay Config.Finisher.Cards (no copy in the module)", "Help it hop home" not in src),
    ]
    for name, good in static:
        print(("STATIC_OK " if good else "STATIC_FAILURE ") + name)
    passed = ok and all(r["applied"] and r["caught"] for r in rows) and all(g for _, g in static)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "static": [{"check": n, "ok": g} for n, g in static],
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in (MODULE, CONFIG, UTIL, PANELS, CLIENT_MAIN)},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "limitations": "Doubles instead of Panels / UIKit / particles: how the window and the glow look on PC and "
                             "phone is a Studio photo check (메인 반영 1, after the merge). The servers' side is "
                             "tools/test_choice_card.py and the finisher tests."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (checks {checks}, mutations {report['mutations']['caught']}/{report['mutations']['total']})")


if __name__ == "__main__":
    main()
