"""(was scratchpad loc5_up.py, 10/16) Upload es/fr/ja/zh-hans/zh-hant from build/l10n/loc/out_<loc>_*.csv (Id,Text) using entries.json identifiers.
Batches 40 entries per PATCH (all 5 locales per entry); failed ones retried one by one with key/source fallbacks.
usage: py loc5_up.py [--dry]"""
import sys, csv, json, glob, time
sys.path.insert(0, "C:/Users/glori/Documents/Roblox/Game/tools")
from l10n_upload import BASE, GAME_ID, call

ROOT = "C:/Users/glori/Documents/Roblox/Game/build/l10n/loc/"
LOCS = ["es", "fr", "ja", "zh-hans", "zh-hant"]
dry = "--dry" in sys.argv
ents = {e["Id"]: e for e in json.load(open(ROOT + "entries.json", encoding="utf-8"))}
tr = {}
for loc in LOCS:
    for f in sorted(glob.glob(ROOT + f"out_{loc}_*.csv")):
        for r in csv.DictReader(open(f, encoding="utf-8-sig")):
            t = (r["Text"] or "").strip()
            if t:
                tr.setdefault(int(r["Id"]), {})[loc] = t

s, info = call("POST", f"{BASE}/autolocalization/games/{GAME_ID}/autolocalizationtable")
tid = info["autoLocalizationTableId"]
table, cursor = [], ""
while True:
    url = f"{BASE}/localization-table/tables/{tid}/entries?gameId={GAME_ID}" + (f"&cursor={cursor}" if cursor else "")
    s, res = call("GET", url)
    if s != 200:
        sys.exit(f"read failed {s}")
    table += res.get("data") or []
    cursor = res.get("nextPageCursor") or ""
    if not cursor:
        break
bykey = {e["identifier"]["key"]: e["identifier"] for e in table if e["identifier"].get("key")}
bysrc = {}
for e in table:
    bysrc.setdefault(e["identifier"]["source"], e["identifier"])
print("table entries", len(table), "to upload", len(tr))


def ident(e):
    k, src = e["key"], e["source"]
    if k and k in bykey:
        return bykey[k]
    if src in bysrc:
        return bysrc[src]
    return {"key": k, "context": e.get("context") or "", "source": src}


def entry(idt, locs):
    return {"identifier": {"key": idt.get("key"), "context": idt.get("context") or "", "source": idt["source"]},
            "metadata": {"example": ""},
            "translations": [{"locale": l, "translationText": t} for l, t in locs.items()]}


ids = sorted(tr)
ok = fail = 0
failed = []
for i in range(0, len(ids), 40):
    chunk = ids[i:i + 40]
    body = [entry(ident(ents[x]), tr[x]) for x in chunk]
    if dry:
        continue
    s, res = call("PATCH", f"{BASE}/localization-table/tables/{tid}?gameId={GAME_ID}", {"name": None, "entries": body})
    bad = res.get("failedEntriesAndTranslations") or [] if isinstance(res, dict) else []
    if s != 200:
        failed += chunk
        print("batch fail", s, str(res)[:200])
    else:
        badsrc, unknown = set(), False
        for b in bad:
            b = b or {}
            idt = b.get("identifier") or (b.get("entry") or {}).get("identifier")
            if idt and idt.get("source") is not None:
                badsrc.add(idt["source"])
            else:
                unknown = True
                print("odd failure", json.dumps(b, ensure_ascii=False)[:300])
        for x in chunk:
            if unknown or ents[x]["source"] in badsrc:
                failed.append(x)
            else:
                ok += 1
    time.sleep(0.3)
# retry one by one
for x in failed:
    e = ents[x]
    tries = [ident(e), {"key": e["key"], "context": "", "source": e["source"]}, {"key": e["key"], "context": e["key"], "source": e["source"]}]
    done = False
    for idt in tries:
        s, res = call("PATCH", f"{BASE}/localization-table/tables/{tid}?gameId={GAME_ID}", {"name": None, "entries": [entry(idt, tr[x])]})
        if s == 200 and not (res or {}).get("failedEntriesAndTranslations"):
            done = True
            break
    ok += done
    if not done:
        fail += 1
        print("FAIL", x, e["key"])
    time.sleep(0.2)
print(f"ok {ok} fail {fail} dry {dry}")
