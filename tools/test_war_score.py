"""Crown war scores as whole numbers (SPEC A23-198, user 10/15: '0.02' cut in the bar's circle), offline.

Runs the CURRENT HUD.ScoreText in the official Luau CLI: whole numbers only, at most 4 characters (999 / 1.2K / 12K /
1.2M) so the score circle never cuts them; the bar and the war window both use it (fmtScore). Each mutation must fail.

Usage: py tools/test_war_score.py
"""
from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HUD = ROOT / "src/StarterPlayer/StarterPlayerScripts/HUD.luau"
LUAU = ROOT / "build/luau_cli_0_741/luau.exe"
if not LUAU.exists():
    LUAU = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"

PURE = r"""
local HUD = {}
__FUNC__
local fails = 0
local function check(name, ok, detail)
	print((ok and "CHECK_OK " or "CHECK_FAIL ") .. name .. (ok and "" or (" :: " .. tostring(detail))))
	if not ok then fails += 1 end
end
local S = HUD.ScoreText
check("0.02 -> 0 (no decimals)", S(0.02) == "0", S(0.02))
check("12.7 -> 12", S(12.7) == "12", S(12.7))
check("999 stays", S(999) == "999", S(999))
check("1000 -> 1K", S(1000) == "1K", S(1000))
check("1250 -> 1.2K (down, never up)", S(1250) == "1.2K", S(1250))
check("12345 -> 12K", S(12345) == "12K", S(12345))
check("1999 -> 1.9K (never 2K)", S(1999) == "1.9K", S(1999))
check("999999 -> 999K", S(999999) == "999K", S(999999))
check("2500000 -> 2.5M", S(2500000) == "2.5M", S(2500000))
check("negative / nil -> 0", S(-3) == "0" and S(nil) == "0")
local long = 0
for _, v in { 0, 7, 99, 999, 1000, 1999, 9999, 10000, 99999, 123456, 999999, 1000000, 9999999, 12345678 } do
	long = math.max(long, #S(v))
end
check("never more than 4 characters", long <= 4, long)
print(fails == 0 and "WAR_SCORE_OK" or "WAR_SCORE_FAILED")
"""


def block(src: str, name: str) -> str:
    m = re.search(r"^function " + re.escape(name) + r"\(.*?^end\n", src, re.S | re.M)
    return m.group(0) if m else ""


def run(src: str) -> tuple[bool, str]:
    fn = block(src, "HUD.ScoreText")
    if not fn or "local function fmtScore(v) return HUD.ScoreText(v) end" not in src:
        return False, "ScoreText / fmtScore missing"
    with tempfile.TemporaryDirectory() as d:
        f = Path(d) / "ws.luau"
        f.write_text(PURE.replace("__FUNC__", fn), encoding="utf-8")
        r = subprocess.run([str(LUAU), str(f)], capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = r.stdout + r.stderr
    return "WAR_SCORE_OK" in out, out


MUTATIONS = [
    ("two decimals again", "v = math.max(0, math.floor(tonumber(v) or 0))", "v = math.max(0, tonumber(v) or 0)"),
    ("thousands in full", "if v < 1000000 then return short(v / 1000, \"K\") end", "if v < 1000000 then return tostring(v) end"),
    ("rounded up", "math.floor(n * 10) / 10", "n"),
    ("the bar not using it", "local function fmtScore(v) return HUD.ScoreText(v) end", "local function fmtScore(v) return tostring(v) end"),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    src = HUD.read_text(encoding="utf-8")
    good, out = run(src)
    print(out.strip())
    caught = 0
    for name, old, new in MUTATIONS:
        if old not in src:
            print("MUTATION NOT_APPLIED " + name)
            continue
        bad, _ = run(src.replace(old, new, 1))
        print(("MUTATION caught  " if not bad else "MUTATION MISSED ") + name)
        caught += 0 if bad else 1
    passed = good and caught == len(MUTATIONS)
    print(f"Status: {'passed' if passed else 'failed'} (mutations {caught}/{len(MUTATIONS)})")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
