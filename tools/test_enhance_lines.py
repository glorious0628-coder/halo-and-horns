"""Enhance / transfer result lines (게임성 개발 1, 게임성 검수 10/12: the bag photo cut "Enhance success! Wooden Sword +0 →
+1 (attack…" at the notify column; A23-130 = the result only), offline.

Runs, in the official Luau CLI, string.format on the CURRENT Config.Loot.Text EnhanceOk / EnhanceFailDown /
EnhanceFailKeep / MoveOk with the arguments their callers pass (LootService: name, before, after, attack % before,
after; name, before, after; name, before; from name, left, to name, after - Panels' result line the same), for every
weapon name in Config.WeaponNames (the longest decides): each line formats, keeps the weapon's name and its new level,
and stays within MaxChars (a one-line toast around an open window holds about 44 at the PC column); the success / fail
lines carry no explanation (no "attack", no "safe"). Static: LootService and Panels still pass those arguments.
Mutations: each must be caught.

Usage: py tools/test_enhance_lines.py
Report: docs/art/verification_2026-10-12/offline_enhance_lines_2026-10-12.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = {"CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
         "LOOT": ROOT / "src/ServerScriptService/LootService.luau",
         "PANELS": ROOT / "src/StarterPlayer/StarterPlayerScripts/Panels.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-12/offline_enhance_lines_2026-10-12.json"
MAX_CHARS = 40
KEYS = ("EnhanceOk", "EnhanceFailDown", "EnhanceFailKeep", "MoveOk")


def texts(cfg: str) -> dict:
    out = {}
    for k in KEYS:
        m = re.search(r"\n\t\t" + k + r' = "((?:[^"\\]|\\.)*)"', cfg)
        if m:
            out[k] = m.group(1)
    return out


def names(cfg: str) -> list[str]:
    m = re.search(r"\nConfig\.WeaponNames = \{(.*?)\n\}", cfg, re.S)
    t = re.search(r"\nConfig\.WeaponNames\.Tamer = \{(.*?)\}\n", cfg, re.S)
    body = (m.group(1) if m else "") + (t.group(1) if t else "")
    return [n for n in re.findall(r'"([^"]+)"', body)]


HARNESS = r'''
local T = TEXTS
local NAMES = NAMELIST
local MAX = MAXCHARS
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local function len(s) return utf8.len(s) or #s end
local worst = { EnhanceOk = "", EnhanceFailDown = "", EnhanceFailKeep = "", MoveOk = "" }
local okAll, keepsAll = true, true
for _, n in NAMES do
	local lines = {
		EnhanceOk = { string.format(T.EnhanceOk, n, 9, 10, 290, 300), "+10" },
		EnhanceFailDown = { string.format(T.EnhanceFailDown, n, 10, 9), "+9" },
		EnhanceFailKeep = { string.format(T.EnhanceFailKeep, n, 10), "+10" },
		MoveOk = { string.format(T.MoveOk, "Goblin Thief's Golden Sword", 0, n, 10), "+10" },
	}
	for k, v in lines do
		if len(v[1]) > len(worst[k]) then worst[k] = v[1] end
		if not (string.find(v[1], n, 1, true) and string.find(v[1], v[2], 1, true)) then keepsAll = false end
	end
end
for k, s in worst do
	check(len(s) <= MAX, k .. ": the longest line fits one toast line (<= " .. MAX .. ")", len(s) .. " '" .. s .. "'")
end
check(keepsAll, "every line names the weapon and its new level", "")
check(not string.find(T.EnhanceOk .. T.EnhanceFailDown .. T.EnhanceFailKeep, "attack", 1, true)
	and not string.find(T.EnhanceFailDown, "safe", 1, true), "no explanation in the result lines (A23-130)", "")
print("CHECKS " .. checks .. " FAILED " .. failed)
'''


def lua_str(s: str) -> str:
    return json.dumps(s, ensure_ascii=False)


def run_pure(src: dict):
    t, n = texts(src["CONFIG"]), names(src["CONFIG"])
    if len(t) != len(KEYS) or len(n) < 20:
        return 1, 1, [f"CHECK_FAIL Config.Loot.Text lines and Config.WeaponNames readable :: {len(t)} / {len(n)}"]
    code = (HARNESS.replace("TEXTS", "{ " + ", ".join(f"{k} = {lua_str(v)}" for k, v in t.items()) + " }")
            .replace("NAMELIST", "{ " + ", ".join(lua_str(x) for x in n) + " }").replace("MAXCHARS", str(MAX_CHARS)))
    with tempfile.TemporaryDirectory() as d:
        f = Path(d) / "enhance_lines.luau"
        f.write_text(code, encoding="utf-8")
        r = subprocess.run([str(BINARY), str(f)], capture_output=True, text=True, encoding="utf-8", errors="replace")
    lines = [ln for ln in r.stdout.splitlines() if ln.startswith("CHECK_")]
    m = re.search(r"CHECKS (\d+) FAILED (\d+)", r.stdout)
    if not m or r.returncode != 0:
        return len(lines) + 1, sum(ln.startswith("CHECK_FAIL") for ln in lines) + 1, lines + [
            "CHECK_FAIL the Luau run finished :: " + (r.stderr.strip()[-300:] or r.stdout.strip()[-300:])]
    return int(m[1]), int(m[2]), lines


def statics(src: dict) -> list[tuple[str, bool]]:
    loot, panels = src["LOOT"], src["PANELS"]
    return [
        ("LootService still passes (name, before, after, attack %, attack %) / (name, before, after) / (name, before) / "
         "(from, left, to, after)", "string.format(TXT.EnhanceOk, name, before, after," in loot
         and "string.format(TXT.EnhanceFailDown, name, before, after)" in loot
         and "string.format(TXT.EnhanceFailKeep, name, before)" in loot
         and "string.format(TXT.MoveOk, fromName, data.WeaponEnhance[fromTier], toName, after)" in loot),
        ("Panels' result line passes the same", 'f("EnhanceOk", name, r.Before, r.After,' in panels
         and 'f("MoveOk", fromName, left, name, r.After)' in panels and 'f("EnhanceFailKeep", name, r.Before)' in panels),
    ]


def run(src: dict):
    n, failed, lines = run_pure(src)
    st = statics(src)
    lines += [("CHECK_OK " if ok else "CHECK_FAIL ") + name for name, ok in st]
    return n + len(st), failed + sum(0 if ok else 1 for _, ok in st), lines


MUTATIONS = [
    ("CONFIG", "the old long success line", 'EnhanceOk = "%s +%d → +%d!",', 'EnhanceOk = "Enhance success! %s +%d → +%d (attack %d%% → %d%%)",'),
    ("CONFIG", "the safety note back", 'EnhanceFailDown = "%s +%d → +%d",',
     'EnhanceFailDown = "Enhance failed… %s +%d → +%d (your weapon is safe)",'),
    ("CONFIG", "both names in the transfer line", 'MoveOk = "%.0s%.0s%s +%d!",', 'MoveOk = "Transfer success! %s +%d · %s +%d",'),
    ("CONFIG", "the new level lost", 'EnhanceOk = "%s +%d → +%d!",', 'EnhanceOk = "%s upgraded!",'),
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
