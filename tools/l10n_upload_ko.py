"""l10n_upload_ko.py : push OUR Korean translations into the cloud table (A23-185; manual entries are not overwritten by
Roblox automatic translation).

  py tools/l10n_upload_ko.py --csv build/l10n/ko_14.csv [--map build/l10n/table_map.json] [--chunk 20] [--locale ko]

CSV columns Key,Source,Ko. If --map (source -> [key, context] as read from the table) knows the source, that key/context is
used so the translation lands on the existing entry; otherwise the CSV key creates the entry. Prints counts only.
"""
import argparse
import csv
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from l10n_upload import BASE, GAME_ID, call  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", required=True)
    ap.add_argument("--map", default="build/l10n/table_map.json")
    ap.add_argument("--chunk", type=int, default=20)
    ap.add_argument("--locale", default="ko")
    a = ap.parse_args()
    s, info = call("POST", f"{BASE}/autolocalization/games/{GAME_ID}/autolocalizationtable")
    if s != 200:
        sys.exit(f"table lookup failed {s}")
    tid = info["autoLocalizationTableId"]
    tmap = {}
    if (ROOT / a.map).exists():
        tmap = json.load(open(ROOT / a.map, encoding="utf-8"))
    entries, seen = [], set()
    for r in csv.DictReader(open(ROOT / a.csv, encoding="utf-8-sig")):
        src, ko = r["Source"].strip(), (r.get("Ko") or "").strip()
        if not src or not ko or ko == src or src in seen:
            continue
        seen.add(src)
        key, ctx = tmap.get(src, (r["Key"], ""))
        entries.append({"identifier": {"key": key, "context": ctx, "source": src}, "metadata": {"example": ""},
                        "translations": [{"locale": a.locale, "translationText": ko}]})
    print(f"sending {len(entries)} translations ({a.locale})")
    ok = fail = 0
    for i in range(0, len(entries), a.chunk):
        chunk = entries[i:i + a.chunk]
        s, res = call("PATCH", f"{BASE}/localization-table/tables/{tid}?gameId={GAME_ID}", {"name": None, "entries": chunk})
        if s != 200:
            print(f"chunk {i // a.chunk + 1}: HTTP {s} {str(res)[:160]}")
            fail += len(chunk)
            continue
        f = res.get("failedEntriesAndTranslations") or []
        ok += len(chunk) - len(f)
        fail += len(f)
        if f:
            print(f"chunk {i // a.chunk + 1}: failed {len(f)} e.g. {str(f[0].get('error'))[:120]}")
        time.sleep(0.8)
    print(f"done ok {ok} failed {fail}")


if __name__ == "__main__":
    main()
