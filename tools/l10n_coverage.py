"""l10n_coverage.py : which player words have no Korean in the cloud table, and which Korean looks wrong (최종 검수 10/14,
user: "아직 번역 안 된 것도 많고 이상하게 번역된 것도 많음").

Collects every English sentence a player can see, the way the game looks it up:
  * Config (the l10n_export walker, every table: Text, ClientText, Help, StoryQuests, Monsters, Items, Skills ...) and the
    client modules' registered word tables (l10n_format_keys.picked_rows: the keys UIKit.Tx / UIKit.Tr use). A sentence
    with a format token (%s %d ...) is drawn through FormatByKey, so it is matched BY KEY with its Roblox form ({1} {2});
    the rest are matched by their text (Roblox's automatic translation matches the drawn text), else by key.
  * build/l10n/format_keys.csv (the uploaded format sentences; keys not found above are added, matched by key).
  * words still written in client modules (l10n_client_hardcoded.findings; 0 today), matched by text.
Reads the experience's cloud localization table through Open Cloud (ROBLOX_OPENCLOUD_KEY in .env, never printed; read
only) and writes, under --out-dir (default build/l10n):
  missing_ko.csv : Key,Source             - no Korean for it in the table (no entry, or an entry without ko)
  suspect_ko.csv : Key,Source,Ko,Reason,Translator - Korean there but: empty / english (the English as is, or no Hangul) /
                   mixed (an English lower-case word of 3+ letters left in) / numbers (a number of the source
                   missing) / placeholders ({n} or %s tokens differ) / stale (the table's
                   source for this key is not today's English). Placeholders = {1}, {Name}, <side>, %s. Debug tags
                   ("[UIKit] ..."), Config paths and lone CamelCase names are not player words (skipped).
  auto_ko.csv    : Key,Source,Ko          - passed the checks but Roblox's automatic translation wrote it (worth a read)
  table_entries.json : the table as read (for --table-json next time, offline)
Prints counts only.

Usage: py tools/l10n_coverage.py [--out-dir build/l10n] [--table-json build/l10n/table_entries.json] [--locale ko]
       [--format-csv build/l10n/format_keys.csv] [--no-client-scan]
"""
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import quote

sys.path.insert(0, str(Path(__file__).resolve().parent))

ROOT = Path(__file__).resolve().parents[1]
FORMAT_CSV = ROOT / "build/l10n/format_keys.csv"
HANGUL = re.compile(r"[가-힣ㄱ-ㆎ]")
LATIN = re.compile(r"[A-Za-z]")
PLACE = re.compile(r"\{\d+\}|\{[A-Za-z]\w*\}|<[a-z]\w*>|%[-+#0]*\d*(?:\.\d+)?[sdifgxXcq]")
# not player words: a debug print tag, a Config path, one CamelCase class / id name
NOT_WORDS = re.compile(r"^\[\w+\]|Config\.|^[A-Z][a-z]+(?:[A-Z][a-z0-9]*)+$")
DIGITS = re.compile(r"\d+")
LOWER_WORD = re.compile(r"(?<![A-Za-z])[a-z]{3,}(?![A-Za-z])")


# ------------------------------------------------------------------ what a player sees
def collect(client_scan: bool = True, format_csv: Path = FORMAT_CSV) -> list[dict]:
    """[{key, source, by}] - by = "key" (FormatByKey) or "text" (automatic translation of the drawn text)"""
    import l10n_format_keys as F

    out: dict[str, dict] = {}
    for key, en in F.picked_rows():
        form, args = F.roblox_form(en)
        if key not in out:
            out[key] = {"key": key, "source": form if args else en, "by": "key" if args else "text"}
    if format_csv.is_file():
        with format_csv.open(encoding="utf-8-sig") as f:
            for r in csv.DictReader(f):
                k, src = (r.get("Key") or "").strip(), (r.get("Source") or "").strip()
                if k and src and k not in out:
                    out[k] = {"key": k, "source": src, "by": "key"}
    if client_scan:
        import l10n_client_hardcoded as CH

        seen = {r["source"] for r in out.values()}
        for path, line, lit in CH.findings():
            k = f"client.{path.rsplit('/', 1)[-1].split('.')[0]}.{line}"
            if lit not in seen and k not in out:
                seen.add(lit)
                out[k] = {"key": k, "source": lit, "by": "text"}
    return list(out.values())


# ------------------------------------------------------------------ the cloud table
def api_key() -> str:
    paths = [ROOT / ".env"]
    try:  # a worktree: the main checkout's .env
        common = subprocess.run(["git", "rev-parse", "--git-common-dir"], cwd=ROOT, capture_output=True, text=True,
                                timeout=30).stdout.strip()
        if common:
            paths.append((ROOT / common).resolve().parent / ".env")
    except (OSError, subprocess.SubprocessError):
        pass
    for p in paths:
        if p.is_file():
            for line in p.read_text(encoding="utf-8").splitlines():
                if line.startswith("ROBLOX_OPENCLOUD_KEY="):
                    return line.split("=", 1)[1].strip()
    sys.exit("no ROBLOX_OPENCLOUD_KEY in .env")


def fetch_table() -> list[dict]:
    import l10n_upload as U

    U.key = api_key  # the same Open Cloud calls, the key found from a worktree too (never printed)
    s, info = U.call("POST", f"{U.BASE}/autolocalization/games/{U.GAME_ID}/autolocalizationtable")
    if s != 200:
        sys.exit(f"table lookup failed: HTTP {s}")
    tid = info["autoLocalizationTableId"]
    entries, cursor = [], ""
    for _ in range(1000):
        url = f"{U.BASE}/localization-table/tables/{tid}/entries?gameId={U.GAME_ID}"
        if cursor:
            url += "&cursor=" + quote(cursor)
        s, res = U.call("GET", url)
        if s != 200:
            sys.exit(f"entries read failed: HTTP {s} after {len(entries)}")
        entries += res.get("data") or []
        cursor = res.get("nextPageCursor") or ""
        if not cursor:
            break
    return entries


def index(entries: list[dict], locale: str = "ko") -> tuple[dict, dict]:
    """(by_key {key: row}, by_source {source: row}); row = {source, ko (None = none), translator}. For a source in
    several entries, one with a translation wins."""
    by_key: dict[str, dict] = {}
    by_source: dict[str, dict] = {}
    for e in entries:
        ident = e.get("identifier") or {}
        src = ident.get("source") or ""
        ko, who = None, ""
        for t in e.get("translations") or []:
            if t.get("locale") == locale:
                ko = t.get("translationText")
                who = ((t.get("translator") or {}).get("agentType")) or ""
        row = {"source": src, "ko": ko, "translator": who}
        k = ident.get("key") or ""
        if k and (k not in by_key or by_key[k]["ko"] is None):
            by_key[k] = row
        if src and (src not in by_source or by_source[src]["ko"] is None):
            by_source[src] = row
    return by_key, by_source


# ------------------------------------------------------------------ judging one line
def problems(source: str, ko: str) -> list[str]:
    """why a Korean line looks wrong ([] = fine)"""
    if ko is None or not ko.strip():
        return ["empty"]
    reasons = []
    bare_src, bare = PLACE.sub("", source), PLACE.sub("", ko)
    # English words = a lower-case word of 3+ letters ("HP ×1.0", "Lv {1}", "VIP", "Zzz" may stay as they are)
    has_words = LOWER_WORD.search(bare_src) is not None
    if has_words and (ko.strip() == source.strip() or not HANGUL.search(ko)):
        reasons.append("english")
    elif LOWER_WORD.search(bare):
        reasons.append("mixed")
    # a number of the source lost in the Korean (Korean may add some: "five" -> 5, "Top 3" -> "1~3등")
    have = DIGITS.findall(bare)
    for d in DIGITS.findall(bare_src):
        if d in have:
            have.remove(d)
        else:
            reasons.append("numbers")
            break
    if sorted(PLACE.findall(source)) != sorted(PLACE.findall(ko)):
        reasons.append("placeholders")
    return reasons


def judge(row: dict, by_key: dict, by_source: dict) -> tuple[str, dict | None, list[str]]:
    """("missing" | "suspect" | "ok", the table row used, reasons)"""
    src = row["source"]
    hit = None
    if row["by"] == "key":
        hit = by_key.get(row["key"])
        if hit is None or hit["ko"] is None:
            hit = by_source.get(src) if by_source.get(src, {}).get("ko") is not None else hit
    else:
        hit = by_source.get(src)
        if hit is None or hit["ko"] is None:
            k = by_key.get(row["key"])
            hit = k if k is not None and k["ko"] is not None else hit
    if hit is None or hit["ko"] is None:
        return "missing", hit, []
    reasons = problems(src, hit["ko"])
    if hit["source"] != src:
        reasons.append("stale")
    return ("suspect" if reasons else "ok"), hit, reasons


def write_csv(path: Path, header: list[str], rows: list[list[str]]):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description=__doc__.split("Usage")[0])
    ap.add_argument("--out-dir", type=Path, default=ROOT / "build/l10n")
    ap.add_argument("--table-json", type=Path, default=None, help="read this saved table instead of the cloud")
    ap.add_argument("--locale", default="ko")
    ap.add_argument("--format-csv", type=Path, default=FORMAT_CSV)
    ap.add_argument("--no-client-scan", action="store_true")
    a = ap.parse_args()
    rows = collect(client_scan=not a.no_client_scan, format_csv=a.format_csv)
    if a.table_json:
        entries = json.loads(a.table_json.read_text(encoding="utf-8"))
    else:
        entries = fetch_table()
        a.out_dir.mkdir(parents=True, exist_ok=True)
        (a.out_dir / "table_entries.json").write_text(json.dumps(entries, ensure_ascii=False) + "\n", encoding="utf-8")
    by_key, by_source = index(entries, a.locale)
    missing, suspect, auto, count = [], [], [], {"ok": 0, "missing": 0, "suspect": 0}
    why: dict[str, int] = {}
    rows = [r for r in rows if not NOT_WORDS.search(r["source"])]
    for r in rows:
        verdict, hit, reasons = judge(r, by_key, by_source)
        count[verdict] += 1
        if verdict == "missing":
            missing.append([r["key"], r["source"]])
        elif verdict == "ok" and hit["translator"] == "Automation":
            auto.append([r["key"], r["source"], hit["ko"]])
        if verdict == "suspect":
            suspect.append([r["key"], r["source"], hit["ko"], ";".join(reasons), hit["translator"]])
            for x in reasons:
                why[x] = why.get(x, 0) + 1
    write_csv(a.out_dir / f"missing_{a.locale}.csv", ["Key", "Source"], missing)
    write_csv(a.out_dir / f"suspect_{a.locale}.csv", ["Key", "Source", "Ko", "Reason", "Translator"], suspect)
    write_csv(a.out_dir / f"auto_{a.locale}.csv", ["Key", "Source", "Ko"], auto)
    print(f"strings {len(rows)}  table entries {len(entries)}  ok {count['ok']}  missing {count['missing']}  "
          f"suspect {count['suspect']}  ({', '.join(f'{k} {v}' for k, v in sorted(why.items()))})  ok-but-automatic {len(auto)}")
    print(f"-> {a.out_dir / f'missing_{a.locale}.csv'} + suspect_{a.locale}.csv")
    return 0


if __name__ == "__main__":
    sys.exit(main())
