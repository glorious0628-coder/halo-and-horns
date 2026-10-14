"""l10n_format_keys.py : the Config sentences with %s / %d / %.1f ... and their Roblox-table form (최종 검수 10/14).

Roblox's automatic translation matches whole DRAWN sentences: "Next: Lv 5 · first skill" is a new sentence for every
number, so lines with numbers or names stayed English. The fix: such a sentence goes through the translation table by
KEY (UIKit.Tr(key, ...) -> Translator:FormatByKey(key, { args })), and the table's Source for that key is the Roblox
placeholder form of the English format: "Next: %s" -> "Next: {1}", "Lv %d · %s" -> "Lv {1} · {2}", "100%%" -> "100%".

Walks the CURRENT Config.luau with tools/l10n_export.py's walker (the same keys: the Config path, list entries numbered from
1, the "...En" twins dropped) and keeps the player-facing strings that have at least one format token. Writes:
  <out>.json : { "count": n, "keys": [ { "key", "en", "roblox", "args": ["%s", "%d", ...], "n" } ] }
  <out>.csv  : Key,Context,Example,Source (Source = the Roblox form) - ready for the localization table upload
A {Name}-style token already in a string stays as it is (it is Roblox form already); %% becomes %.

Usage: py tools/l10n_format_keys.py [--out build/l10n/format_keys] [--stats]
"""
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import l10n_export as E  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
SPEC = re.compile(r"%%|%[-+ #0]*\d*(?:\.\d+)?[sdifgxXcq]")


def roblox_form(fmt: str) -> tuple[str, list[str]]:
    """'Lv %d · %s (100%%)' -> ('Lv {1} · {2} (100%)', ['%d', '%s'])"""
    args: list[str] = []

    def sub(m: re.Match) -> str:
        if m.group(0) == "%%":
            return "%"
        args.append(m.group(0))
        return "{" + str(len(args)) + "}"

    return SPEC.sub(sub, fmt), args


def rows() -> list[dict]:
    source = E.CONFIG.read_text(encoding="utf-8-sig")
    walked = E.run_walker(E.top_level_roots(source))
    # a format token + a space + words = a sentence for the player even under an id-like key (GoalChips.Text.Zone)
    def sentence(v: str) -> bool:
        return bool(SPEC.search(v)) and " " in v.strip() and re.search(r"[A-Za-z]{2}", SPEC.sub("", v)) is not None \
            and not v.startswith(("rbxasset", "http"))
    picked = [(k, v) for k, v in walked if re.search(r"[A-Za-z]", v) and (E.looks_like_words(k, v) or sentence(v))]
    by_key = dict(picked)
    picked = [(k, v) for k, v in picked if not (k.endswith("En") and by_key.get(k[:-2]) == v)]
    out = []
    for key, en in picked:
        form, args = roblox_form(en)
        if args:
            out.append({"key": key, "en": en, "roblox": form, "args": args, "n": len(args)})
    return out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description=__doc__.split("Usage")[0])
    ap.add_argument("--out", type=Path, default=ROOT / "build/l10n/format_keys")
    ap.add_argument("--stats", action="store_true")
    a = ap.parse_args()
    out = rows()
    if a.stats:
        count: dict[str, int] = {}
        for r in out:
            top = r["key"].split(".")[1]
            count[top] = count.get(top, 0) + 1
        for name, n in sorted(count.items(), key=lambda kv: -kv[1]):
            print(f"{n:5d}  Config.{name}")
        print(f"{len(out):5d}  total")
        return 0
    base = a.out.with_suffix("") if a.out.suffix in (".json", ".csv") else a.out
    base.parent.mkdir(parents=True, exist_ok=True)
    base.with_suffix(".json").write_text(json.dumps({"count": len(out), "keys": out}, ensure_ascii=False, indent=1) + "\n",
                                         encoding="utf-8")
    with base.with_suffix(".csv").open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow(["Key", "Context", "Example", "Source"])
        for r in out:
            w.writerow([r["key"], "", r["en"], r["roblox"]])
    print(f"{len(out)} format sentences -> {base.with_suffix('.json')} + .csv")
    return 0


if __name__ == "__main__":
    sys.exit(main())
