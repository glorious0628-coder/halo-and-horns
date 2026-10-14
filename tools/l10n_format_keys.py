"""l10n_format_keys.py : the sentences with %s / %d / %.1f ... and their Roblox-table form (최종 검수 10/14).

Roblox's automatic translation matches whole DRAWN sentences: "Next: Lv 5 · first skill" is a new sentence for every
number, so lines with numbers or names stayed English. The fix: such a sentence goes through the translation table by
KEY (UIKit.Tr(key, ...) -> Translator:FormatByKey(key, { args })), and the table's Source for that key is the Roblox
placeholder form of the English format: "Next: %s" -> "Next: {1}", "Lv %d · %s" -> "Lv {1} · {2}", "100%%" -> "100%".

Two sources, the keys exactly as UIKit.Tx / UIKit.Tr look them up (L10n.PathOf):
  * Config: walked with tools/l10n_export.py's walker (the Config path, list entries numbered from 1, "...En" twins
    dropped) - "Config.GoalChips.Text.Next".
  * the client modules' registered word tables (L10n.Register("<path>", <table>) in src/StarterPlayer): their literal
    table in the module ("HUD.TXT.WarHorns", "PauseCard.T.Text.BackNext"); a table that is a Config.ClientText one keeps
    the registered path too (its Config rows are renamed to it).
Only player-facing strings with at least one format token. A token is %, flags [-+#0] (no space: "70% gives" is words,
not a format), width, .precision, one of sdifgxXcq; %% becomes %. Writes:
  <out>.json : { "count": n, "keys": [ { "key", "en", "roblox", "args": ["%s", "%d", ...], "n" } ] }
  <out>.csv  : Key,Context,Example,Source (Source = the Roblox form) - ready for the localization table upload

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
CLIENT = ROOT / "src/StarterPlayer"
SPEC = re.compile(r"%%|%[-+#0]*\d*(?:\.\d+)?[sdifgxXcq]")
REGISTER = re.compile(r'L10n\.Register\("([\w.]+)",\s*([\w.]+)\)')


def roblox_form(fmt: str) -> tuple[str, list[str]]:
    """'Lv %d · %s (100%%)' -> ('Lv {1} · {2} (100%)', ['%d', '%s'])"""
    args: list[str] = []

    def sub(m: re.Match) -> str:
        if m.group(0) == "%%":
            return "%"
        args.append(m.group(0))
        return "{" + str(len(args)) + "}"

    return SPEC.sub(sub, fmt), args


def sentence(v: str) -> bool:
    """a format token + a space + words = a sentence for the player even under an id-like key (GoalChips.Text.Zone)"""
    return bool(SPEC.search(v)) and " " in v.strip() and re.search(r"[A-Za-z]{2}", SPEC.sub("", v)) is not None \
        and not v.startswith(("rbxasset", "http"))


# ------------------------------------------------------------------ the modules' literal word tables
class Lua:
    """a forgiving reader of a Lua table literal: string / number / nested-table values (anything else is skipped)"""
    ESC = {"n": "\n", "t": "\t", '"': '"', "'": "'", "\\": "\\", "r": "\r"}

    def __init__(self, s: str, i: int):
        self.s, self.i = s, i

    def ws(self):
        s = self.s
        while self.i < len(s):
            if s[self.i].isspace():
                self.i += 1
            elif s.startswith("--[[", self.i):
                self.i = s.index("]]", self.i) + 2
            elif s.startswith("--", self.i):
                j = s.find("\n", self.i)
                self.i = len(s) if j < 0 else j
            else:
                break

    def string(self) -> str:
        q = self.s[self.i]
        self.i += 1
        out = []
        while self.s[self.i] != q:
            c = self.s[self.i]
            if c == "\\":
                n = self.s[self.i + 1]
                if n == "u" and self.s[self.i + 2] == "{":
                    j = self.s.index("}", self.i)
                    out.append(chr(int(self.s[self.i + 3:j], 16)))
                    self.i = j + 1
                    continue
                out.append(self.ESC.get(n, n))
                self.i += 2
                continue
            out.append(c)
            self.i += 1
        self.i += 1
        return "".join(out)

    def skip_value(self):
        depth = 0
        while self.i < len(self.s):
            c = self.s[self.i]
            if c in "\"'":
                self.string()
                continue
            if c in "({[":
                depth += 1
            elif c in ")}]":
                if depth == 0:
                    return
                depth -= 1
            elif c in ",;" and depth == 0:
                return
            self.i += 1

    def table(self) -> dict:
        assert self.s[self.i] == "{"
        self.i += 1
        out, n = {}, 0
        while True:
            self.ws()
            if self.s[self.i] == "}":
                self.i += 1
                return out
            key = None
            m = re.match(r"([A-Za-z_]\w*)\s*=(?!=)", self.s[self.i:])
            if m:
                key = m.group(1)
                self.i += m.end()
                self.ws()
            elif self.s[self.i] == "[":
                j = self.s.index("]", self.i)
                raw = self.s[self.i + 1:j].strip()
                key = raw.strip("\"'") if raw[:1] in "\"'" else raw
                self.i = self.s.index("=", j) + 1
                self.ws()
            else:
                n += 1
                key = str(n)
            c = self.s[self.i]
            start = self.i
            if c in "\"'":
                v = self.string()
                self.ws()
                if self.s[self.i] not in ",;}":  # an expression that starts with a string ("a" .. x): not a literal
                    self.i = start
                    self.skip_value()
                else:
                    out[key] = v
            elif c == "{":
                out[key] = self.table()
            else:
                self.skip_value()
            self.ws()
            if self.s[self.i] in ",;":
                self.i += 1


def flat(t: dict, path: str, out: list[tuple[str, str]]):
    for k, v in t.items():
        if isinstance(v, dict):
            flat(v, f"{path}.{k}", out)
        elif isinstance(v, str):
            out.append((f"{path}.{k}", v))


def module_rows() -> tuple[list[tuple[str, str]], dict[str, str]]:
    """(key, text) of every registered module word table + {Config.ClientText.X: registered path} for moved tables"""
    rows, renames = [], {}
    for f in sorted(CLIENT.rglob("*.luau")):
        s = f.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
        for path, expr in REGISTER.findall(s):
            parts = expr.split(".")
            m = re.search(rf"^local {re.escape(parts[0])} = ", s, re.M)
            if not m:
                continue
            rest = s[m.end():]
            cm = re.match(r"(Config\.ClientText\.\w+)", rest)
            if cm and len(parts) == 1:
                renames[cm.group(1)] = path
                continue
            if not rest.startswith("{"):
                continue
            try:
                t = Lua(s, m.end()).table()
            except (AssertionError, IndexError, ValueError):
                continue
            for p in parts[1:]:
                t = t.get(p) if isinstance(t, dict) else None
            if isinstance(t, dict):
                flat(t, path, rows)
            else:  # a nested field the table reads from Config (T.Text = Config.ClientText.X)
                fm = re.search(rf"\b{re.escape(parts[-1])} = (Config\.ClientText\.\w+)", rest[:4000]) if len(parts) > 1 else None
                if fm:
                    renames[fm.group(1)] = path
    return rows, renames


def rows() -> list[dict]:
    source = E.CONFIG.read_text(encoding="utf-8-sig")
    walked = E.run_walker(E.top_level_roots(source))
    mod_rows, renames = module_rows()
    renamed = []
    for k, v in walked:
        for old, new in renames.items():
            if k == old or k.startswith(old + "."):
                k = new + k[len(old):]
                break
        renamed.append((k, v))
    picked = [(k, v) for k, v in renamed if re.search(r"[A-Za-z]", v) and (E.looks_like_words(k, v) or sentence(v))]
    picked += [(k, v) for k, v in mod_rows if re.search(r"[A-Za-z]", v) and (E.looks_like_words(k, v) or sentence(v))]
    by_key = dict(picked)
    picked = [(k, v) for k, v in picked if not (k.endswith("En") and by_key.get(k[:-2]) == v)]
    out, seen = [], set()
    for key, en in picked:
        if key in seen:
            continue
        seen.add(key)
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
            top = ".".join(r["key"].split(".")[:2])
            count[top] = count.get(top, 0) + 1
        for name, n in sorted(count.items(), key=lambda kv: -kv[1]):
            print(f"{n:5d}  {name}")
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
