"""Reward chip (게임성 개발 1, 게임성 검수 10/11: the merge photo showed the first mission's "+150 gold" as "★ +150..." over
an open card - the star read as no gold, the words cut), offline.

Runs, in the official Luau CLI, the CURRENT UIKit NOTIFY.FmtPattern / NOTIFY.CoinLine (cut from the source) with the
CURRENT Config formats: a reward toast with no icon of its own whose whole text is a gold-only format (Config.Tutorial
.Text.Claimed, Config.StoryQuests.Text.ChoiceGold: "+%s gold") becomes the approved coin (NOTIFY.CoinIcon = IconCoin)
and the number ("+150", "+1,250"); a longer line ("+150 gold +60 XP", "Lunch done! +150 gold"), another kind, a toast
that already has an icon stay as they are; a format with pattern characters still matches literally. Static: UIKit
.Toast converts before it queues or draws; the art capsule, once drawn, widens step by step up to the column while its
words do not fit (TextFits); CoinFormats reads both Config formats; IconCoin is an uploaded UIArt part. Mutations: each
must be caught. The look is a Studio photo (a card open, the first mission claimed).

Usage: py tools/test_reward_chip.py
Report: docs/art/verification_2026-10-11/offline_reward_chip_2026-10-11.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = {"UIKIT": ROOT / "src/StarterPlayer/StarterPlayerScripts/UIKit.luau",
         "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-11/offline_reward_chip_2026-10-11.json"

HARNESS = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local NOTIFY = { CoinIcon = "IconCoin" }
-- FUNCS --
local F = { FORMATS }
local function line(text, kind, icon)
	local t, i = NOTIFY.CoinLine(text, kind, icon, F)
	return tostring(t) .. "|" .. tostring(i)
end
check(line("+150 gold", "reward", nil) == "+150|IconCoin", "the first mission's +150 gold = the coin and +150", line("+150 gold", "reward", nil))
check(line("+1,250 gold", "reward", nil) == "+1,250|IconCoin", "thousands commas kept", line("+1,250 gold", "reward", nil))
check(line("+150 gold +60 XP", "reward", nil) == "+150 gold +60 XP|nil", "a longer line stays (gold and XP)", line("+150 gold +60 XP", "reward", nil))
check(line("Lunch done! +150 gold", "reward", nil) == "Lunch done! +150 gold|nil", "a sentence with gold stays", line("Lunch done! +150 gold", "reward", nil))
check(line("+150 gold", "info", nil) == "+150 gold|nil", "only reward toasts", line("+150 gold", "info", nil))
check(line("+150 gold", "reward", "Potion") == "+150 gold|Potion", "a toast with its own icon stays", line("+150 gold", "reward", "Potion"))
check(line("+150 gold", "reward", "") == "+150|IconCoin", "an empty icon counts as none", line("+150 gold", "reward", ""))
local p = NOTIFY.FmtPattern("(%s) gold.")
check(string.match("(12) gold.", p) == "12" and string.match("(12) goldX", p) == nil, "pattern characters in a format match literally", p)
print("CHECKS " .. checks .. " FAILED " .. failed)
'''


def funcs(src: str) -> str | None:
    out = []
    for name in ("NOTIFY.FmtPattern", "NOTIFY.CoinLine"):
        m = re.search(r"\nfunction " + re.escape(name) + r"\(.*?\nend\n", src, re.S)
        if not m:
            return None
        out.append(m.group(0))
    return "\n".join(out)


def formats(cfg: str) -> list[str]:
    tut = re.search(r"\nConfig\.Tutorial = \{.*?\n\tText = \{.*?\n\t\tClaimed = \"([^\"]*)\"", cfg, re.S)
    story = re.search(r"\n\t\tChoiceGold = \"([^\"]*)\"", cfg)
    return [m.group(1) for m in (tut, story) if m]


def run_pure(src: dict):
    body = funcs(src["UIKIT"])
    fm = formats(src["CONFIG"])
    if body is None or len(fm) != 2:
        return 1, 1, [f"CHECK_FAIL UIKit NOTIFY.FmtPattern / CoinLine and both Config formats readable :: {len(fm)}"]
    code = HARNESS.replace("-- FUNCS --", body).replace("FORMATS", ", ".join(json.dumps(f) for f in fm))
    with tempfile.TemporaryDirectory() as d:
        f = Path(d) / "reward_chip.luau"
        f.write_text(code, encoding="utf-8")
        r = subprocess.run([str(BINARY), str(f)], capture_output=True, text=True, encoding="utf-8", errors="replace")
    lines = [ln for ln in r.stdout.splitlines() if ln.startswith("CHECK_")]
    m = re.search(r"CHECKS (\d+) FAILED (\d+)", r.stdout)
    if not m or r.returncode != 0:
        return len(lines) + 1, sum(ln.startswith("CHECK_FAIL") for ln in lines) + 1, lines + [
            "CHECK_FAIL the Luau run finished :: " + (r.stderr.strip()[-300:] or r.stdout.strip()[-300:])]
    return int(m[1]), int(m[2]), lines


def statics(src: dict) -> list[tuple[str, bool]]:
    ui, cfg = src["UIKIT"], src["CONFIG"]
    toast = ui.split("function UIKit.Toast(", 1)[-1].split("\nend\n", 1)[0]
    art = ui.split("function NOTIFY.BuildArtToast(", 1)[-1].split("\nend\n", 1)[0]
    coin = re.search(r'\n\t\tIconCoin = \{ Id = "rbxassetid://\d+"', cfg)
    conv = toast.find("text, icon = NOTIFY.CoinLine(text, kind, icon)")
    return [
        ("UIKit.Toast turns a gold-only reward into the coin + number before it queues or draws",
         0 < conv < toast.find("if NOTIFY.OneAtATime and #toasts > 0 then") and conv < toast.find("NOTIFY.BuildArtToast(")),
        ("the art capsule widens step by step up to the column while its drawn words do not fit (TextFits)",
         "if t.Dead or not frame.Parent or label.TextFits then return end" in art
         and "frame.Size = UDim2.new(0, math.floor(math.min(col, cur + NOTIFY.FitStep)), 0, 0)" in art
         and "for _ = 1, NOTIFY.FitTries do" in art and "\tFitTries = 12, FitStep = 24,\n" in ui),
        ("CoinFormats reads Config.Tutorial.Text.Claimed and Config.StoryQuests.Text.ChoiceGold",
         "Config.Tutorial.Text" in ui and "Config.StoryQuests.Text" in ui and "tut.Claimed" in ui and "story.ChoiceGold" in ui),
        ("IconCoin is an uploaded UIArt part (the approved coin)", coin is not None and '\tCoinIcon = "IconCoin",\n' in ui),
    ]


def run(src: dict):
    n, failed, lines = run_pure(src)
    st = statics(src)
    lines += [("CHECK_OK " if ok else "CHECK_FAIL ") + name for name, ok in st]
    return n + len(st), failed + sum(0 if ok else 1 for _, ok in st), lines


MUTATIONS = [
    ("UIKIT", "no coin line", "\ttext, icon = NOTIFY.CoinLine(text, kind, icon) -- a gold-only reward: the coin + \"+N\"\n", ""),
    ("UIKIT", "a gold line inside a longer one matches", 'return "^" .. esc .. "$"', 'return "^" .. esc'),
    ("UIKIT", "pattern characters unescaped", 'local esc = string.gsub(fmt, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")',
     "local esc = fmt"),
    ("UIKIT", "every kind gets the coin", 'if kind ~= "reward" or (type(icon) == "string" and icon ~= "")',
     'if (type(icon) == "string" and icon ~= "")'),
    ("UIKIT", "the cut words never widen the capsule", "if t.Dead or not frame.Parent or label.TextFits then return end",
     "if true then return end"),
    ("CONFIG", "the coin art missing", '\t\tIconCoin = { Id = "rbxassetid://', '\t\tIconCoin_ = { Id = "rbxassetid://'),
    ("UIKIT", "the number kept with its word", 'if n then return "+" .. n, NOTIFY.CoinIcon end', "if n then return text, NOTIFY.CoinIcon end"),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    n, failed, lines = run(src)
    print("\n".join(lines))
    muts = []
    for key, name, old, new in MUTATIONS:
        hits = src[key].count(old)
        caught = False
        if hits == 1:
            m = dict(src)
            m[key] = src[key].replace(old, new)
            caught = run(m)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    status = "passed" if failed == 0 and n > 0 and all(m["caught"] for m in muts) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": n, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {n}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
