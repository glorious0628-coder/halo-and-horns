"""l10n_upload.py : push the English source strings into the experience's cloud localization table (Open Cloud).

  py tools/l10n_upload.py [--csv build/l10n/halo_horns_strings_en.csv] [--chunk 100] [--dry]

Reads ROBLOX_OPENCLOUD_KEY from .env (never printed). Finds the auto-localization table of universe GAME_ID, then
PATCHes entries in chunks: identifier {key, context, source}, no translations (Roblox automatic translation fills them).
Prints only counts. Re-running is safe: same key+source = same entry.
"""
import argparse
import csv
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME_ID = 10769445522
BASE = "https://apis.roblox.com/legacy-localization-tables/v1"


def key():
    for line in (ROOT / ".env").read_text(encoding="utf-8").splitlines():
        if line.startswith("ROBLOX_OPENCLOUD_KEY="):
            return line.split("=", 1)[1].strip()
    sys.exit("no ROBLOX_OPENCLOUD_KEY in .env")


def call(method, url, body=None):
    data = json.dumps(body).encode("utf-8") if body is not None else (b"" if method == "POST" else None)
    req = urllib.request.Request(url, headers={"x-api-key": key(), "Content-Type": "application/json"}, method=method, data=data)
    for attempt in range(4):
        try:
            r = urllib.request.urlopen(req, timeout=120)
            return r.status, json.loads(r.read().decode("utf-8") or "{}")
        except urllib.error.HTTPError as e:
            txt = e.read().decode("utf-8", "replace")[:300]
            if e.code in (429, 500, 502, 503, 504) and attempt < 3:
                time.sleep(5 * (attempt + 1))
                continue
            return e.code, {"error": txt}
    return 0, {"error": "retries"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default="build/l10n/halo_horns_strings_en.csv")
    ap.add_argument("--chunk", type=int, default=100)
    ap.add_argument("--dry", action="store_true")
    a = ap.parse_args()
    s, info = call("POST", f"{BASE}/autolocalization/games/{GAME_ID}/autolocalizationtable")
    if s != 200:
        sys.exit(f"table lookup failed {s} {info}")
    tid = info["autoLocalizationTableId"]
    rows = list(csv.DictReader(open(ROOT / a.csv, encoding="utf-8-sig")))
    entries = [{"identifier": {"key": r["Key"], "context": r.get("Context", "") or "", "source": r["Source"]},
                "metadata": {"example": r.get("Example", "") or ""}, "translations": []}
               for r in rows if r.get("Source", "").strip()]
    print(f"table {tid[:8]}… entries to send {len(entries)} (dry={a.dry})")
    if a.dry:
        return
    ok = fail = 0
    for i in range(0, len(entries), a.chunk):
        chunk = entries[i:i + a.chunk]
        s, res = call("PATCH", f"{BASE}/localization-table/tables/{tid}?gameId={GAME_ID}", {"name": None, "entries": chunk})
        if s != 200:
            print(f"chunk {i // a.chunk + 1}: HTTP {s} {str(res)[:200]}")
            fail += len(chunk)
            continue
        f = res.get("failedEntriesAndTranslations") or []
        m = res.get("modifiedEntriesAndTranslations") or []
        ok += len(chunk) - len(f)
        fail += len(f)
        print(f"chunk {i // a.chunk + 1}: modified {len(m)} failed {len(f)}" + (f" e.g. {str(f[0])[:160]}" if f else ""))
        time.sleep(1.0)
    s, cnt = call("GET", f"{BASE}/localization-table/tables/{tid}/entry-count?gameId={GAME_ID}")
    print(f"done ok {ok} failed {fail}; table entryCount now {cnt.get('entryCount') if s == 200 else cnt}")


if __name__ == "__main__":
    main()
