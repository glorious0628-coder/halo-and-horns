"""l10n_client_scan.py : find player-facing English strings hard-coded in client modules (not in Config) so they can be
sent to the cloud localization table (and later moved into central tables, AGENTS 'never hard-coded').

  py tools/l10n_client_scan.py [--out build/l10n/client_strings.csv]

Heuristic: string literals on lines like `Text = "..."` / `Label = "..."` / `Title = ...` / `ActionText` / `Placeholder...`,
plus every literal inside a table opened as `TXT = {`, `local TXT = {`, `TEXT = {`, `WORDS = {` ... until the closing `}`.
Skips ids (rbxasset, CamelCase without spaces, ALL_CAPS, snake_case), format strings (%s %d { ), empty / no-letter strings.
Output CSV: Key,Context,Example,Source (Key = client.<file>.<line>). Review the list before uploading.
"""
import argparse
import csv
import glob
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KV = re.compile(r'\b(Text|Label|Title|Caption|Placeholder|PlaceholderText|ActionText|ObjectText|Hint|Tip|Toast|Desc|Short|Sub|Line\d?)\s*=\s*"((?:[^"\\]|\\.)*)"')
TBL = re.compile(r'^\s*(?:local\s+)?(TXT\w*|TEXT\w*|WORDS|LABELS|STR|COPY|LINES)\s*=\s*\{')
LIT = re.compile(r'"((?:[^"\\]|\\.)*)"')
SKIP = re.compile(r'rbxasset|^[A-Z][a-z]+(?:[A-Z][a-z0-9]*)+$|^[a-z_0-9]+$|^\d|^[A-Z_0-9]+$|%[-0-9.]*[sdifx]|[{}]|\\n|\\t|^\s*$|^[^A-Za-z]*$|^(Enum|Head|Body|Face|Left|Right|Top|Bottom|Center)$')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="build/l10n/client_strings.csv")
    a = ap.parse_args()
    out = {}
    for f in sorted(glob.glob(str(ROOT / "src/StarterPlayer/**/*.luau"), recursive=True)):
        lines = open(f, encoding="utf-8").read().split("\n")
        depth = 0
        for i, line in enumerate(lines, 1):
            s = line.split("--")[0]
            cands = []
            if depth == 0 and TBL.search(s):
                depth = 1
                cands += LIT.findall(s.split("{", 1)[1])
            elif depth > 0:
                cands += LIT.findall(s)
                depth += s.count("{") - s.count("}")
                if depth <= 0:
                    depth = 0
            cands += [m.group(2) for m in KV.finditer(s)]
            for c in cands:
                c = c.strip()
                if len(c) < 2 or SKIP.search(c):
                    continue
                if " " not in c and not (c[0].isupper() and len(c) >= 3):
                    continue
                out.setdefault(c, f"client.{os.path.basename(f)[:-5]}.{i}")
    os.makedirs(ROOT / "build/l10n", exist_ok=True)
    with open(ROOT / a.out, "w", encoding="utf-8-sig", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["Key", "Context", "Example", "Source"])
        for c, k in out.items():
            w.writerow([k, "", "", c])
    print(f"{len(out)} strings -> {a.out}")
    for c, k in list(out.items())[:40]:
        print(f"  {k:40s} {c[:70]}")


if __name__ == "__main__":
    main()
