"""l10n_export.py : list the English texts the SERVER sends (게임성 개발 3, 2026-10-10, SPEC A23-111 Korean mode).

Loads the CURRENT src/ReplicatedStorage/Shared/Config.luau with the installed official Luau CLI (build/luau_cli_0_741, through
tools/fixtures/dev2_kit.luau: no Studio, network or Roblox API) and walks every table of it. Each player-facing English
string becomes one row of docs/l10n/strings_server_en.json:

    { "key": "Config.Text.PotionBought", "en": "Bought %s potion x%d!", "where": "Config.Text",
      "args": ["%s", "%d"], "max": 22 }

key   = the path of the string in Config (Config.StoryQuests.Defs.KO1.Steps.2.Text; list entries are numbered from 1). This is
        the key game dev 1's UIKit.Tx / TextKo.luau and the server's L10n.Text use (docs/design/l10n_server_2026-10-10.md).
args  = the format tokens in the order they appear (%s %d %.1f {1} {Auto} ...): a Korean line must keep exactly these.
max   = a rough width in characters the Korean line may take (the English length x 1.3, at least 8): the reviewer's budget.
A string is player-facing when it looks like words: its leaf key is one of TEXT_KEYS, or it has a space, or it ends with
.!?:…; ids (SlimeMeadow, rbxassetid://..., colour names, file names) and keys of ART_KEYS are skipped. --all lists every
string with a letter (for the reviewer to cross-check the filter), --roots limits the walk to some top-level Config tables.

Usage: py tools/l10n_export.py [--all] [--roots Text,StoryQuests,...] [--out docs/l10n/strings_server_en.json] [--stats]
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "tools/fixtures/dev2_kit.luau"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
LUAU = ROOT / "build/luau_cli_0_741/luau.exe"
DEFAULT_OUT = ROOT / "docs/l10n/strings_server_en.json"

# leaf keys that hold words for the player
TEXT_KEYS = {
    "Text", "Title", "Name", "Short", "ShortName", "Label", "Desc", "Description", "Start", "Finish", "Clue", "Help", "Tip", "Toast",
    "Hint", "Say", "Speak", "Line", "Lines", "Reply", "ActionText", "ObjectText", "Header", "Footer", "Body", "Caption", "Message",
    "Msg", "Notice", "Reason", "Bubble", "Bark", "Greeting", "Question", "Answer", "Option", "Prompt", "Intro", "Outro", "Summary",
    "AltText", "NameText", "Verb", "Unit", "Rank", "Subtitle", "Tooltip", "Empty", "Done", "Claim", "Reward", "Unlocked", "Good",
    "Evil", "Lean", "Placeholder", "Button", "Cta", "Sign", "Banner",
}
# keys whose strings are art / sound / ids even if they have spaces or capitals
ART_KEYS = {
    "Id", "Icon", "Art", "Image", "Sound", "Anim", "Animation", "Model", "Material", "Font", "Color", "Colour", "Mesh", "Texture",
    "Tag", "Attr", "Remote", "Zone", "Kind", "Class", "Faction", "Slot", "Key", "Source", "Spot", "Guide", "Npc", "Panel", "Type",
    "Event", "Pick", "Potion", "Item", "Style", "Shape", "Folder", "Path", "File", "Prefix", "Suffix", "Format", "Pattern", "Name_", "Action", "Mode",
}
FORMAT = re.compile(r"%[-+ #0]*\d*(?:\.\d+)?[sdfgxXcq]|%%|\{[A-Za-z0-9_]+\}")

WALKER = r'''
local SUITE_MARK = "L10N"
local C = execute("Config", CONFIG_SOURCE, nativeEnv())
local seen, rows = {}, {}
local function keyOf(k)
	if type(k) == "number" then return tostring(math.floor(k)) end
	return tostring(k)
end
local function walk(t, path, depth)
	if seen[t] or depth > 12 then return end
	seen[t] = true
	local keys = {}
	for k in t do table.insert(keys, k) end
	table.sort(keys, function(a, b)
		local na, nb = type(a) == "number", type(b) == "number"
		if na and nb then return a < b end
		if na ~= nb then return na end
		return tostring(a) < tostring(b)
	end)
	for _, k in keys do
		local v = t[k]
		local p = path .. "." .. keyOf(k)
		if type(v) == "string" then
			table.insert(rows, { p, v })
		elseif type(v) == "table" then
			walk(v, p, depth + 1)
		end
	end
end
for _, root in ROOTS do
	local t = C[root]
	if type(t) == "table" then walk(t, "Config." .. root, 1)
	elseif type(t) == "string" then table.insert(rows, { "Config." .. root, t }) end
end
for _, r in rows do
	local v = string.gsub(r[2], "\\", "\\\\")
	v = string.gsub(v, "\n", "\\n")
	print("L10N_ROW\t" .. r[1] .. "\t" .. v)
end
print("L10N_DONE", #rows)
'''


def literal(value: str) -> str:
    eq = "===="
    while "]" + eq + "]" in value:
        eq += "="
    return "[" + eq + "[" + value + "]" + eq + "]"


def top_level_roots(source: str) -> list[str]:
    roots: list[str] = []
    for m in re.finditer(r"^Config\.([A-Za-z_][A-Za-z0-9_]*)\s*=", source, re.M):
        if m.group(1) not in roots:
            roots.append(m.group(1))
    return roots


def run_walker(roots: list[str]) -> list[tuple[str, str]]:
    if not LUAU.is_file():
        raise SystemExit(f"Luau CLI missing: {LUAU} (this tool never downloads anything)")
    source = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    kit = KIT.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    roots_lua = "{ " + ", ".join(json.dumps(r) for r in roots) + " }"
    text = f"local CONFIG_SOURCE = {literal(source)}\nlocal ROOTS = {roots_lua}\n{kit}\n{WALKER}"
    with tempfile.TemporaryDirectory(prefix="l10n_") as tmp:
        path = Path(tmp) / "export.luau"
        path.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(LUAU), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=300)
    if proc.returncode != 0 or "L10N_DONE" not in proc.stdout:
        raise SystemExit("walker failed:\n" + proc.stderr[-2000:] + proc.stdout[-500:])
    rows = []
    for line in proc.stdout.splitlines():
        if line.startswith("L10N_ROW\t"):
            _, key, value = line.split("\t", 2)
            rows.append((key, value.replace("\\n", "\n").replace("\\\\", "\\")))
    return rows


def looks_like_words(key: str, value: str) -> bool:
    leaf = key.rsplit(".", 1)[-1]
    parent = key.rsplit(".", 2)[-2] if key.count(".") >= 2 else ""
    if not re.search(r"[A-Za-z]{2}", FORMAT.sub("", value)):
        return False
    if value.startswith(("rbxasset", "http", "Enum.", "KeyCode.", "Key.")) or re.fullmatch(r"[\w./:\-]+\.(png|jpg|wav|mp3|ogg|luau|json)", value):
        return False
    if leaf in ART_KEYS:
        return False
    # one CamelCase / snake_case / numbered token = an id (FirstKO, SlimeMeadow, Npc_Bright, Enh70), not words
    if re.fullmatch(r"[A-Za-z0-9_]+", value) and re.search(r"[a-z][A-Z]|[A-Za-z][0-9]|_", value):
        return False
    if leaf in TEXT_KEYS or parent in TEXT_KEYS:
        return True
    if " " in value.strip() and not re.fullmatch(r"[A-Z][A-Za-z]+( [A-Z][A-Za-z]+)+", value) or re.search(r"[.!?:…]$", value):
        return True
    return bool(re.fullmatch(r"[A-Z][a-z]+( [A-Za-z']+)*", value)) and leaf in ("Name", "Short", "Title", "Label")


def row_for(key: str, value: str) -> dict:
    args = FORMAT.findall(value)
    letters = len(FORMAT.sub("", value))
    return {"key": key, "en": value, "where": ".".join(key.split(".")[:2]), "args": args, "max": max(8, int(letters * 1.3) + 2 * len(args))}


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description=__doc__.split("Usage")[0])
    ap.add_argument("--all", action="store_true", help="every string with a letter, not only the ones that look like words")
    ap.add_argument("--roots", default="", help="comma list of top-level Config tables (default: all)")
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--stats", action="store_true", help="print the count per top-level table and write nothing")
    args = ap.parse_args()
    source = CONFIG.read_text(encoding="utf-8-sig")
    roots = [r for r in args.roots.split(",") if r] or top_level_roots(source)
    rows = run_walker(roots)
    picked = [(k, v) for k, v in rows if re.search(r"[A-Za-z]", v) and (args.all or looks_like_words(k, v))]
    # the old English twins (Label / LabelEn, kept for the day the game had two languages: UIKit.Tx reads key .. "En"): when the
    # twin says the same words as its base key, only the base key is listed
    by_key = dict(picked)
    picked = [(k, v) for k, v in picked if not (k.endswith("En") and by_key.get(k[:-2]) == v)]
    if args.stats:
        count: dict[str, int] = {}
        for k, _ in picked:
            count[k.split(".")[1]] = count.get(k.split(".")[1], 0) + 1
        for name, n in sorted(count.items(), key=lambda kv: -kv[1]):
            print(f"{n:6d}  Config.{name}")
        print(f"{len(picked):6d}  total ({len(rows)} strings walked)")
        return 0
    out = [row_for(k, v) for k, v in picked]
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"{len(out)} strings -> {args.out.relative_to(ROOT) if args.out.is_relative_to(ROOT) else args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
