"""② 채집 G 꾹 화면 (게임성 개발 4, 2026-10-12; SPEC A23-119 / A23-127 / A23-133 / A23-130, contract 개발 3
origin/dev3-gather docs/design/gather_server_2026-10-11.md §7), offline.

Runs, in the official Luau CLI, the CURRENT Config.luau, L10n.luau and GatherView.luau in tools/fixtures/gather_view_offline.luau
(a workspace with Map.GatherNodes, the GatherState remote, a TextKo / UIKit language double). Checks: GatherState is bound at
Init; the prompt's ActionText / ObjectText come from its ActionKey / ObjectKey (Pick / Mine + the item name; Korean for a
Korean reader, a stale Korean line falls back to English, an unknown key is no word - never the key itself); nodes already
there when the folder appears and nodes added later get their words and rest; a node resting for me (Ready time in the
future) has its prompt off, its parts faded (LocalTransparencyModifier), its sparkle / light out; it comes back when the
time passes (an emitter that was off stays off); the words follow a language change; a removed node is forgotten; the
state keeps string ids with real times only (at most MaxIds), a bad payload is ignored. Static: ClientMain loads
GatherView; it sends no remote; no English word is written in it. Mutations: each must be caught.

Usage: py tools/test_gather_view.py
Report: docs/art/verification_2026-10-12/offline_gather_view_2026-10-12.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = {"VIEW": ROOT / "src/StarterPlayer/StarterPlayerScripts/GatherView.luau",
         "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
         "L10N": ROOT / "src/ReplicatedStorage/Shared/L10n.luau",
         "MAIN": ROOT / "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau"}
FIXTURE = ROOT / "tools/fixtures/gather_view_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-12/offline_gather_view_2026-10-12.json"

MUTATIONS = [
    ("VIEW", "the key itself shown as a word", "if not ok or type(s) ~= \"string\" or s == key then return \"\" end",
     "if not ok or type(s) ~= \"string\" then return \"\" end"),
    ("VIEW", "no object word", "\tif object ~= \"\" and p.ObjectText ~= object then p.ObjectText = object end\n", ""),
    ("VIEW", "always English", "local action, object = GatherView.Words(p:GetAttribute(G.ActionKey), p:GetAttribute(G.ObjectKey), lang())",
     "local action, object = GatherView.Words(p:GetAttribute(G.ActionKey), p:GetAttribute(G.ObjectKey), \"en\")"),
    ("VIEW", "rest never ends", "\treturn type(at) == \"number\" and at > t\n", "\treturn type(at) == \"number\"\n"),
    ("VIEW", "a resting prompt stays on", "\tif p then p.Enabled = not resting end\n", ""),
    ("VIEW", "no fade", "\t\t\td.LocalTransparencyModifier = resting and G.Fade or 0\n", ""),
    ("VIEW", "sparkles stay on", "\t\t\t\td.Enabled = false\n", ""),
    ("VIEW", "an emitter that was off comes back on", "\t\t\t\td.Enabled = S.Lit[d]\n", "\t\t\t\td.Enabled = true\n"),
    ("VIEW", "the poll never brings a node back", "\t\telseif not GatherView.Resting(S.Ready, id, t) then\n", "\t\telseif false then\n"),
    ("VIEW", "nodes added later are skipped", "\t\t\tlocal ok, err = pcall(applyNode, m)\n\t\t\tif not ok then Util.Warn(TAG, \"node: \" .. tostring(err)) end\n\t\tend)",
     "\t\tend)"),
    ("VIEW", "a late folder is never found", "\t\tif ch.Name == G.Folder then watchFolder(ch) end\n", ""),
    ("VIEW", "the language change is ignored", "\t\tui.LangChanged:Connect(function() GatherView.Refresh() end)\n", ""),
    ("VIEW", "bad ids kept", "if type(id) == \"string\" and #id <= 64 and t then", "if t then"),
    ("VIEW", "no cap on entries", "\t\t\tif n >= G.MaxIds then break end\n", ""),
    ("VIEW", "bound only at Start", "\tbind() -- before any Start", "\t-- before any Start"),
    ("MAIN", "the view is never loaded", "\"CharacterUI\", \"GatherView\",", "\"CharacterUI\","),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def static(src: dict) -> list[tuple[str, bool]]:
    order = re.search(r"local ORDER = \{([^}]*)\}", src["MAIN"])
    names = re.findall(r'"(\w+)"', order.group(1)) if order else []
    code = "\n".join(l for l in src["VIEW"].splitlines() if not l.strip().startswith("--"))
    return [
        ("ClientMain loads GatherView (after UIKit, before Audio)", "GatherView" in names and "UIKit" in names
         and names.index("GatherView") > names.index("UIKit")),
        ("GatherView sends no remote (display only)", "FireServer" not in code and "InvokeServer" not in code),
        ("no English word written in GatherView (all words come from keys)",
         re.search(r'"(Pick|Mine|Hold|Herb|Ore)[^"]*"', code) is None),
    ]


def run(src: dict) -> tuple[int, int, str]:
    text = ("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal L10N_SOURCE = " + lua_str(src["L10N"])
            + "\nlocal VIEW_SOURCE = " + lua_str(src["VIEW"]) + "\n" + FIXTURE.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "gather_view.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"GATHER_VIEW_SUMMARY checks=(\d+) failed=(\d+)", out)
    failed = int(m[2]) if m else 1
    st = static(src)
    for name, ok in st:
        out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + name
        failed += 0 if ok else 1
    return (int(m[1]) if m else 0) + len(st), failed, out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    checks, failed, out = run(src)
    print(out.strip())
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
    status = "passed" if failed == 0 and checks > 0 and all(m["caught"] for m in muts) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
