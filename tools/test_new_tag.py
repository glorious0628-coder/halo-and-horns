"""One NEW! at a time (게임성 개발 1, 검수 2026-10-10: the war bar, its info line and the goose chip wore NEW! at once), offline.

Runs, in the official Luau CLI, the CURRENT UIKit.NewTag / UIKit.NextNewTag cut out of UIKit.luau in
tools/fixtures/new_tag_offline.luau (UIKit.ShowNewTag, which draws the tag, is a double). Checks: the first part gets its
tag at once; a part inside / around the tagged (or waiting) part gets none; a different part waits and gets its tag when
the one before goes (+ Gap); the queue drains in order and skips a part hidden by its turn; the same part again restarts.
Static: HUD and EventHUD still call UIKit.NewTag (never ShowNewTag). Mutations: each must be caught.

Usage: py tools/test_new_tag.py
Report: docs/art/verification_2026-10-10/offline_new_tag_2026-10-10.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
UIKIT = SPS / "UIKit.luau"
FIXTURE = ROOT / "tools/fixtures/new_tag_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-10/offline_new_tag_2026-10-10.json"
START = "function UIKit.NewTag(target, text)"
END = "function UIKit.ShowNewTag(target, text)"

MUTATIONS = [
    ("every call shows at once", "\tif busy and act ~= target then\n\t\ttable.insert", "\tif false then\n\t\ttable.insert"),
    ("the same thing gets a second tag", "\tif busy and act ~= target and same(act, target) then return nil end\n", ""),
    ("a waiting part queued twice", "\t\tif same(w.Target, target) then return nil end\n", ""),
    ("the queue never drains", "\t\t\ttask.delay(math.max(0, q.Until - now), UIKit.NextNewTag)\n", ""),
    ("no gap between tags", "now + (tonumber(cfg.Seconds) or 6) + (tonumber(cfg.Gap) or 0.4)", "now"),
    ("a hidden part still tagged", "\t\tif t.Parent ~= nil and t.Visible then\n", "\t\tif true then\n"),
    ("only the next one ever comes", "\tif #q.Queue > 0 then\n\t\tq.Draining = true\n", "\tif false then\n\t\tq.Draining = true\n"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def cut(src: str) -> str:
    a, b = src.find(START), src.find(END)
    if a < 0 or b < a:
        raise ValueError("UIKit.NewTag / ShowNewTag not found; update the extractor")
    return src[a:b]


def run(block: str) -> tuple[int, int, str]:
    text = "local NEWTAG_SOURCE = " + lua_str(block) + "\n" + FIXTURE.read_text(encoding="utf-8")
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "new_tag.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"NEW_TAG_SUMMARY checks=(\d+) failed=(\d+)", out)
    return (int(m[1]) if m else 0), (int(m[2]) if m else 1), out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = UIKIT.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    block = cut(src)
    checks, failed, out = run(block)
    print(out.strip())
    statics = []
    for name, file, text in [
        ("HUD tags through UIKit.NewTag (1안: not the war bar, the quest lines)", "HUD.luau", "pcall(UIKit.NewTag, ui.questLines)"),
        ("EventHUD tags through UIKit.NewTag", "EventHUD.luau", "pcall(kit.NewTag, chip)"),
        ("nobody calls ShowNewTag but the queue", None, None),
    ]:
        if file:
            ok = text in (SPS / file).read_text(encoding="utf-8-sig")
        else:
            ok = all("ShowNewTag" not in (SPS / f).read_text(encoding="utf-8-sig") for f in ("HUD.luau", "EventHUD.luau"))
        statics.append({"check": name, "ok": ok})
        print(("STATIC_OK  " if ok else "STATIC_FAIL ") + name)
    muts = []
    for name, old, new in MUTATIONS:
        hits = block.count(old)
        caught = hits == 1 and run(block.replace(old, new))[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    ok = failed == 0 and checks > 0 and all(s["ok"] for s in statics) and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "static": statics, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
