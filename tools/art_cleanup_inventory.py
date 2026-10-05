"""Dry inventory of the art folders. It never deletes and never rewrites the cleanup record.

  py tools/art_cleanup_inventory.py   -> prints counts and writes build/art_inventory_dry.json (build/ is git-ignored)

History: the one-time old-art cleanup (AGENTS 2026-10-05 decision) ran on 2026-10-06 with this tool;
its record is docs/art/art_cleanup_2026-10-06.json and it is never rewritten.
--delete was removed on 2026-10-06 (reviewer item 7): new Firefly art is not in Config/MaterialService
until it is uploaded, so this tool would have listed it as "unused" and deleted it. Firefly art must never
be deleted by this tool. An old image that a Firefly replacement has replaced is deleted by hand, one at a
time, as AGENTS.md "Art workflow" step 7 says.

Listing rules: active = an image whose Roblox ID (art/ui/asset_ids.json) is used in src/ (Config.UIArt, ...)
or in a MaterialService variant of build/GoodEvil.rbxlx, plus its art/out source with the same stem.
Any file that is not in the 2026-10-06 record (new since the cleanup, e.g. Firefly art) is listed as
"keep_new_since_cleanup" and is never a candidate. Kept out of scope: art/models, art/fonts, docs/.
"""
import json, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
RECORD = "docs/art/art_cleanup_2026-10-06.json"
OUT = "build/art_inventory_dry.json"

if any(a.startswith("--delete") for a in sys.argv[1:]):
    sys.exit("--delete is disabled: the old-art cleanup already ran on 2026-10-06 (record: " + RECORD + ").\n"
             "Firefly art must never be deleted by this tool. Delete a replaced old image by hand "
             "(AGENTS.md Art workflow step 7). Nothing was deleted.")
if any(a.startswith("--force") for a in sys.argv[1:]):
    sys.exit("--force is disabled: " + RECORD + " is the history record of the 2026-10-06 cleanup and is never "
             "rewritten. Run without arguments for a dry listing in " + OUT + ".")
if len(sys.argv) > 1:
    sys.exit(__doc__)

IMG = (".png", ".jpg", ".jpeg", ".webp")
REVEALING = {f"UIP_Char{n}.png" for n in ("HaloArcher", "HornsArcher", "HornsMage", "HornsWarrior")}
EXPERIENCE_PAGE = {"GameIcon", "Thumbnail_Kaiju"}  # experience icon/thumbnail sources, not in Config

used = set()
for dp, _, fs in os.walk("src"):
    for f in fs:
        if f.endswith(".luau"):
            used |= set(re.findall(r"rbxassetid://(\d+)", open(os.path.join(dp, f), encoding="utf-8").read()))
if os.path.exists("build/GoodEvil.rbxlx"):
    place = open("build/GoodEvil.rbxlx", encoding="utf-8", errors="replace").read()
    for m in re.finditer(r'<Item class="MaterialVariant".*?</Item>', place, re.S):
        used |= set(re.findall(r"rbxassetid://(\d+)", m.group(0)))
else:
    print("warning: build/GoodEvil.rbxlx missing; MaterialService IDs not counted as active")

ids = json.load(open("art/ui/asset_ids.json", encoding="utf-8"))
active_keys = {k for k, v in ids.items() if isinstance(v, str) and v.rsplit("/", 1)[-1] in used}
tracked = set(subprocess.run(["git", "ls-files", "art"], capture_output=True, text=True).stdout.split("\n"))
recorded = set()
if os.path.exists(RECORD):
    recorded = {r["file"] for r in json.load(open(RECORD, encoding="utf-8")).get("files", [])}
else:
    print("warning: " + RECORD + " missing; every file is listed as keep_new_since_cleanup")

rows = []
def add(path, action, reason):
    path = path.replace("\\", "/")
    if path not in recorded:
        action, reason = "keep_new_since_cleanup", "not in the 2026-10-06 cleanup record (new art, e.g. Firefly): never a candidate"
    rows.append({"file": path, "tracked": path in tracked, "action": action, "reason": reason})

for top in ("art/ui", "art/out", "art/test"):
    for dp, _, fs in os.walk(top):
        for f in sorted(fs):
            p = os.path.join(dp, f).replace("\\", "/")
            stem, ext = os.path.splitext(f)
            if "/v1" in p:
                add(p, "unused_old", "art/out/v1 (old/rejected/revealing) still on disk"); continue
            if f in REVEALING:
                add(p, "unused_old", "byte copy of a revealing image (Hard rule 1) still on disk"); continue
            base = stem
            if ext.lower() not in IMG:
                # sidecar: follows its image (same stem prefix)
                img = next((os.path.join(dp, stem + e) for e in IMG if os.path.exists(os.path.join(dp, stem + e))), None)
                if img is None and top != "art/ui":
                    base = re.sub(r"(\.qa|\.codex|\.prompt)$", "", stem)
                    img = next((os.path.join(dp, base + e) for e in IMG if os.path.exists(os.path.join(dp, base + e))), None)
                if top == "art/ui" or img is None:
                    add(p, "keep", "metadata/non-image"); continue
            if base in active_keys:
                add(p, "keep_until_replaced", f"active in game ({ids[base]})"); continue
            if base in EXPERIENCE_PAGE:
                add(p, "keep_until_replaced", "experience page icon/thumbnail source"); continue
            add(p, "unused_old", "old file not used in the game: review by hand, this tool never deletes")

actions = ("unused_old", "keep_until_replaced", "keep", "keep_new_since_cleanup")
out = {"kind": "dry inventory (no deletion; the cleanup record is " + RECORD + ")",
       "active_ids": len(used), "active_keys": sorted(active_keys),
       "counts": {a: sum(1 for r in rows if r["action"] == a) for a in actions},
       "files": rows}
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8") as fh:
    json.dump(out, fh, ensure_ascii=False, indent=1)
    fh.write("\n")
print(json.dumps(out["counts"]))
missing = sorted(k for k in active_keys if not os.path.exists(f"art/ui/{k}.png"))
print("active keys without art/ui file:", missing)
print("listing written to " + OUT + "; nothing deleted")
