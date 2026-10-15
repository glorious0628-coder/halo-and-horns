"""l10n_client_hardcoded.py : player words still hard-coded in client screen modules (최종 검수 10/14, AGENTS 'never
hard-coded'). Every player word belongs in a central table (Config ...; the client screens' own words in
Config.ClientText.<Module>), where the localization export finds it.

Looks in src/StarterPlayer/**/*.luau (comments stripped) for string literals that read as words for the player:
  (a) `Key = "..."` with a text key (Text, Title, Label, Caption, Placeholder(Text), ActionText, ObjectText, Hint, Tip,
      Toast, Desc, Short, Line, Body, Header, Footer, Sub, Message, Button)
  (b) any literal inside a top-level word table (`local TXT = {`, `local T = {`, TEXT / WORDS / LABELS ...).
A literal reads as words when it has 2+ letters and a lower-case letter, and is not an id (CamelCase / snake_case / a
path / rbxasset). ALLOW lists what is known and accepted (module -> literals; "*" = the whole module, pending a move).
Usage: py tools/l10n_client_hardcoded.py   (prints the findings; exit 1 when there are any) - tools/test_english.py runs it.
"""
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
CLIENT = ROOT / "src/StarterPlayer"
TEXT_KEYS = ("Text|Title|Label|Caption|Placeholder|PlaceholderText|ActionText|ObjectText|Hint|Tip|Toast|Desc|Short|Line|"
             "Body|Header|Footer|Sub|Message|Button")
KV = re.compile(r'\b(?:' + TEXT_KEYS + r')\s*=\s*"((?:[^"\\]|\\.)*)"')
TBL = re.compile(r'^(?:local\s+)?(TXT\w*|TEXT\w*|T|WORDS|LABELS|STR|COPY|LINES)\s*=\s*\{', re.M)
LIT = re.compile(r'"((?:[^"\\]|\\.)*)"')
# 최종 검수 10/15 ("번역 안 된 것들 싹 다"): a literal written straight into a label's Text ("MAX", "Gear") is drawn as is
SET = re.compile(r'\.(?:Text|PlaceholderText)\s*=\s*"((?:[^"\\]|\\.)*)"')
# known and accepted: module -> literals ("*" = the whole module: its word table moves after a pending branch merges)
ALLOW: dict[str, set[str]] = {
    "UIKit": {"Halo & Horns 0123"},  # the font preload's probe text (never shown)
    "FactionPicker": {"Artisan"},  # NEUTRAL_FALLBACK: only when Config.Factions.Neutral is missing
    "Panels": {"Artisan"},  # the same fallback
    "Fx": {"Ouch!"},
    "HUD": {"MAX"},  # the XP bar at the top level (10/15: reads the same in Korean games; 개발 1 may move it to a table)  # the code-drawn sticker while its art id is empty; inside MOTION (the attack-clip tables tests hash)
}
# the values of these keys are ids (actions, sounds, class / flag names), not words
ID_LISTS = {"Action", "Reuse", "Flag", "Aliases"}
FORMAT = re.compile(r"%[-+ #0]*\d*(?:\.\d+)?[sdifgxXcq]|%%")
PREVIEW = re.compile(r"^T\.Preview = \{.*?^\}", re.M | re.S)  # QuestBook's Studio preview rows (never in a game)


def strip_comments(s: str) -> str:
    s = re.sub(r"--\[(=*)\[.*?\]\1\]", "", s, flags=re.S)
    out = []
    for line in s.split("\n"):
        i, q = 0, None
        while i < len(line):
            c = line[i]
            if q:
                if c == "\\":
                    i += 2
                    continue
                if c == q:
                    q = None
            elif c in "\"'":
                q = c
            elif line.startswith("--", i):
                line = line[:i]
                break
            i += 1
        out.append(line)
    return "\n".join(out)


ID_KEY = re.compile(r"(Id|Ids|Remote|Window|Panel|Sound|Icon|Art|Attr|Tag|Gui|Kind|Source|Key|Mode|Style|Font|Part|Class|"
                    r"Faction|Zone|Slot|Event|Topic|Tile|Prompt|Anim|Folder|Model|Setting)$")


def words(s: str, key: str | None = None) -> bool:
    """a literal that reads as words for the player. One bare word counts only as the value of a non-id key (a list
    element or an Id / Remote / Window ... value is an id: "Journal", "Deny", "Mage")"""
    if s.startswith(("rbxasset", "http", "Enum.", "\\u{")) or "/" in s and " " not in s:
        return False
    bare = FORMAT.sub("", s)  # "%d:%02d", "%dm": a format with no words
    if len(re.findall(r"[A-Za-z]", bare)) < 2 or not re.search(r"[a-z]", bare):
        return False
    if re.fullmatch(r"[A-Za-z0-9_]+", s) and (re.search(r"[a-z][A-Z]|[A-Z]{2}|_|[A-Za-z][0-9]", s) or s.islower()):
        return False  # an id: CamelCase, XEnabled, snake_case, lowercase key, Npc1
    if re.fullmatch(r"[A-Za-z]+", s):  # one bare word
        return key is not None and not ID_KEY.search(key)
    return True


def table_end(s: str, start: int) -> int:
    depth, i, q = 0, start, None
    while i < len(s):
        c = s[i]
        if q:
            if c == "\\":
                i += 2
                continue
            if c == q:
                q = None
        elif c in "\"'":
            q = c
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return len(s)


def client_sources() -> dict[str, str]:
    """repo-relative path -> text of every client module"""
    return {f.relative_to(ROOT).as_posix(): f.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
            for f in sorted(CLIENT.rglob("*.luau"))}


def findings(texts: dict[str, str] | None = None) -> list[tuple[str, int, str]]:
    """texts: repo-relative path -> source (a test passes mutated copies); default = the files on disk"""
    out = []
    texts = client_sources() if texts is None else texts
    for path in sorted(texts):
        if not path.startswith("src/StarterPlayer/") or not path.endswith(".luau"):
            continue
        mod = path.rsplit("/", 1)[-1].split(".")[0]
        allow = ALLOW.get(mod, set())
        if "*" in allow:
            continue
        s = strip_comments(texts[path])
        s = PREVIEW.sub(lambda m: "\n" * m.group(0).count("\n"), s)
        seen = set()
        for m in KV.finditer(s):
            v = m.group(1)
            if words(v, "Text") and v not in allow:
                seen.add((s.count("\n", 0, m.start()) + 1, v))
        for m in SET.finditer(s):
            v = m.group(1)
            if (words(v, "Text") or re.fullmatch(r"[A-Z]{2,}[!?]?", v)) and v not in allow:
                seen.add((s.count("\n", 0, m.start()) + 1, v))
        for m in TBL.finditer(s):
            end = table_end(s, m.end() - 1)
            body = s[m.end() - 1:end]
            for lm in LIT.finditer(body):
                v = lm.group(1)
                km = re.search(r"([A-Za-z_][A-Za-z0-9_]*)\s*=\s*$", body[max(0, lm.start() - 60):lm.start()])
                outer = re.search(r"([A-Za-z_][A-Za-z0-9_]*)\s*=\s*\{[^{}]*$", body[:lm.start()])
                if outer and outer.group(1) in ID_LISTS:
                    continue
                if words(v, km.group(1) if km else None) and v not in allow:
                    seen.add((s.count("\n", 0, m.end() - 1 + lm.start()) + 1, v))
        out += [(path, ln, v) for ln, v in sorted(seen)]
    return out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    found = findings()
    for path, ln, v in found:
        print(f"{path}:{ln}: {v}")
    print(f"{len(found)} hard-coded player words in client modules (allowed: {', '.join(sorted(ALLOW))})")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
