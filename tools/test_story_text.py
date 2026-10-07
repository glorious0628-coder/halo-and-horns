"""Quality item 14 (docs/design/quality_ideas_2026-10-06.md §1 ⑭): story text checker, offline.

Loads Config.luau from --src with the installed official Luau CLI (build/luau_cli_0_741/luau.exe) in a stub engine
environment (Vector3 / Color3 / Enum ... doubles, nothing else), walks every table and string, and checks the player
text with Python. Comments are never read as text (only values that exist in the loaded Config are checked); a small
Luau lexer maps each value back to its source line. No Studio, network, DataStore or Roblox API calls; src/ is only read.

Checks (each finding = level, rule, Config path, source line, the text):
  1. hangul           Hangul in any Config string (error), except Config.UIArt (baked card-text expectations) and the
                      language's own name (Settings.Text.Options.ko / koEn). Other src/*.luau string literals with
                      Hangul: error, unless they are text matchers (string.find/match/gsub), developer logs
                      (warn/print/error/assert) or the NicknameService word lists (info).
  2. length           an in-game line (story page line, toast, banter, quest row): > 14 words warn, > 18 error.
                      Each "\n" part is one line; a leading "Speaker:" name is not counted; {Token} and %s = 1 word.
     length-bark      Config.Barks lines: > 8 words warn (lines_pack §2).
  3. banned-*         kids 8-12 / satire rules: gore and swear words (error); die/dead/kill (error, warn when the line
                      is about a monster: prefer "beat" / "defeat"); romance words (error); scary / insult words (warn);
                      real brands, countries, religions, politicians (warn); money pressure (free!, sale, hurry,
                      limited, buy now ...: error next to a shop / price / gold line, else warn).
  4. glossary-case    names from docs/design/glossary_en_2026-10-06.md (all-capitalized multi-word names, plus a few
                      unmistakable single names such as Forge / Crossroads / Hallie) used with another capitalization
                      (warn). ALL-CAPS emphasis is allowed.
  5. linesby-default  every LinesBy table needs a Default (error); LinesBy.From must name a story quest (warn).
  6. format-*         %d / %s placeholders:
                      format-stray   a placeholder in a line the game shows raw (story pages, Start / Finish / Clue /
                                     Say, choice labels, quest titles, Welcome, banter, barks) = error; the one
                                     exception is Config.Halloween.Banter.Days[9].GhostKing (exactly one %d,
                                     lines_pack §4).
                      format-step    a story step Text against StoryQuestService.rowFor (Trials 1, Level 1, Near+Stay
                                     2, OwnIron 1, Count <= 2, anything else 0 because it is shown raw).
                      format-callsite string.format(<Config path>, ...) found in src/: placeholder count must equal
                                     the argument count (too few args = error, extra args = warn).
                      format-doc     counts the design docs fix (Banter.Format 2, Day 9 GhostKing 1, Board Goal 2,
                                     Tutorial.QuestText 1).
                      format-twin    X and XEn must hold the same placeholders (error).
                      format-percent a lone % in a format string makes string.format throw (error); a "%%" in a raw
                                     line shows two percent signs (warn).
  7. pronoun          Bright, Smokey, Hallie, Kit = she; Tiny, Magpie, Otto, Fizzby = he: a line naming one of them
                      (not as the speaker prefix) with only the other gender's pronouns (warn).
  8. Neutral / Guild / Artisan paths and the Neutral-only story quests (N1, N2) are hidden in the beta (A23-57): their
     findings are reported as info (levelIfShown keeps the real level) and never fail the run.
  9. plural-*         one / many (검수 2026-10-07, 'You were away for 1 days'): a count phrase = the words after a
                      number up to the first plural count noun (PLURAL_NOUNS, max 3 words: 'days', 'basic hits',
                      'Wanted players').
                      plural-one      a lone 1 before a count phrase in a Config text ('1 days', also lines Config
                                      formats while it loads) = error.
                      plural-word     '%d <count phrase>' in a Config format text whose phrase is not a key of
                                      Config.PluralWords (Config.Plural could not say '1 day') = error.
                      plural-callsite string.format(<Config path>, ...) of such a text not wrapped in Plural(...)
                                      (Config.Plural / an alias) = error; a dynamic Config.X[key] site = info.
                      plural-literal  a '%d <count phrase>' literal in other src/*.luau code (client text tables):
                                      warn while a string.format of its key in that file is not wrapped in
                                      Plural(...), error when the phrase is not in Config.PluralWords.
 10. shortname-*      ShortName (검수 2026-10-07: the phone HUD quest row shows it instead of a cut-off line).
                      shortname-length  a ShortName / HintShort / Tutorial.ShortNames text longer than 14 characters
                                        (%d counts as 2 digits; a %s is not allowed: its length is unknown) = error.
                      shortname-missing a story quest, daily / extra quest template, board job, first-mission row
                                        (Tutorial.ShortNames) or the Job Board hint row without one = error.

Scope of checks 2-7: Config.StoryQuests, Config.Tutorial (Welcome, Text, GuideText, QuestText), Config.Halloween
(Banter, Text), Config.Barks.Lines, Config.Text, Config.Story, Config.StoryLines, Config.Board, and every other table named
Text inside Config (ids such as Type / Kind / Zone / Guide / Npc / Spot / Speaker are skipped).

Self-test: 10 mutations are appended to an in-memory copy of Config (Hangul line, 20-word toast, LinesBy without
Default, stray %d in a story line, a gore word, a glossary name in lower case, '1 days', a count text whose noun is
not in Config.PluralWords, a 16-character ShortName, a story quest without ShortName); each must produce its own new
finding. Prints "mutations caught N/N"; the status is "passed" only with no error findings and every mutation caught,
"passed-no-mutations" when there are no errors but the self-test was skipped or missed one, else "failed".

Usage: py tools/test_story_text.py [--src path/to/src] [--out report.json] [--no-mutations] [--luau luau.exe]
Exit code: 1 when any error-level finding (or Config does not load), else 0.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MARK = "STORYTEXT"
CONFIG_REL = Path("ReplicatedStorage/Shared/Config.luau")
GLOSSARY = ROOT / "docs/design/glossary_en_2026-10-06.md"

HANGUL_RE = re.compile(r"[ᄀ-ᇿ㄰-㆏가-힣]")
IDENT_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*\Z")

# ------------------------------------------------------------------------------------------------ Luau lexer
_ESC = {"n": b"\n", "t": b"\t", "r": b"\r", "a": b"\a", "b": b"\b", "f": b"\f", "v": b"\v", "\\": b"\\",
        '"': b'"', "'": b"'", "\n": b"\n", "`": b"`", "{": b"{"}
_OPS = ("...", "..=", "//=", "..", "==", "~=", "<=", ">=", "//", "+=", "-=", "*=", "/=", "%=", "^=", "->", "::")
_NUM_RE = re.compile(r"0[xX][0-9a-fA-F_]+|0[bB][01_]+|(?:\d[\d_]*(?:\.[\d_]*)?|\.\d[\d_]*)(?:[eE][+-]?\d+)?")
_NAME_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
_LONG_RE = re.compile(r"\[(=*)\[")


class Tok:
    __slots__ = ("kind", "val", "line")

    def __init__(self, kind: str, val, line: int):
        self.kind, self.val, self.line = kind, val, line

    def __repr__(self) -> str:
        return f"Tok({self.kind},{self.val!r},{self.line})"


def lex(text: str) -> list[Tok]:
    """Tokens of a Luau source: name / num / str (decoded value) / istr (backtick) / op. Comments are dropped."""
    out: list[Tok] = []
    i, n, line = 0, len(text), 1
    while i < n:
        c = text[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if c in " \t\r\f\v":
            i += 1
            continue
        if text.startswith("--", i):
            m = _LONG_RE.match(text, i + 2)
            if m:
                close = "]" + m.group(1) + "]"
                end = text.find(close, m.end())
                end = n if end < 0 else end + len(close)
            else:
                end = text.find("\n", i)
                end = n if end < 0 else end
            line += text.count("\n", i, end)
            i = end
            continue
        if c == "[":
            m = _LONG_RE.match(text, i)
            if m:
                close = "]" + m.group(1) + "]"
                start = m.end()
                end = text.find(close, start)
                end = n if end < 0 else end
                body = text[start:end]
                if body.startswith("\r\n"):
                    body = body[2:]
                elif body.startswith("\n"):
                    body = body[1:]
                out.append(Tok("str", body, line))
                line += text.count("\n", i, end)
                i = end + len(close)
                continue
        if c in "\"'":
            j, buf, start_line = i + 1, bytearray(), line
            while j < n and text[j] != c and text[j] != "\n":
                ch = text[j]
                if ch == "\\" and j + 1 < n:
                    d = text[j + 1]
                    if d in _ESC:
                        buf += _ESC[d]
                        if d == "\n":
                            line += 1
                        j += 2
                    elif d == "x":
                        try:
                            buf.append(int(text[j + 2:j + 4], 16))
                        except ValueError:
                            pass
                        j += 4
                    elif d == "z":
                        j += 2
                        while j < n and text[j] in " \t\r\n\f\v":
                            if text[j] == "\n":
                                line += 1
                            j += 1
                    elif d == "u" and j + 2 < n and text[j + 2] == "{":
                        k = text.find("}", j)
                        try:
                            buf += chr(int(text[j + 3:k], 16)).encode("utf-8")
                        except ValueError:
                            pass
                        j = k + 1
                    elif d.isdigit():
                        m = re.match(r"\d{1,3}", text[j + 1:j + 4])
                        buf.append(int(m.group(0)) & 255)
                        j += 1 + len(m.group(0))
                    else:
                        buf += d.encode("utf-8")
                        j += 2
                else:
                    buf += ch.encode("utf-8")
                    j += 1
            out.append(Tok("str", buf.decode("utf-8", errors="replace"), start_line))
            i = j + 1
            continue
        if c == "`":
            j, parts, start_line = i + 1, [], line
            while j < n and text[j] != "`":
                ch = text[j]
                if ch == "\\" and j + 1 < n:
                    parts.append(_ESC.get(text[j + 1], text[j + 1].encode()).decode("utf-8", "replace"))
                    j += 2
                    continue
                if ch == "{":
                    depth = 1
                    j += 1
                    while j < n and depth:
                        if text[j] == "{":
                            depth += 1
                        elif text[j] == "}":
                            depth -= 1
                        elif text[j] == "\n":
                            line += 1
                        j += 1
                    parts.append("{}")
                    continue
                if ch == "\n":
                    line += 1
                parts.append(ch)
                j += 1
            out.append(Tok("istr", "".join(parts), start_line))
            i = j + 1
            continue
        if c.isdigit() or (c == "." and i + 1 < n and text[i + 1].isdigit()):
            m = _NUM_RE.match(text, i)
            out.append(Tok("num", m.group(0), line))
            i = m.end()
            continue
        m = _NAME_RE.match(text, i)
        if m:
            out.append(Tok("name", m.group(0), line))
            i = m.end()
            continue
        for op in _OPS:
            if text.startswith(op, i):
                out.append(Tok("op", op, line))
                i += len(op)
                break
        else:
            out.append(Tok("op", c, line))
            i += 1
    return out


def is_op(tok: Tok | None, val: str) -> bool:
    return tok is not None and tok.kind == "op" and tok.val == val


def chain_back(tokens: list[Tok], end: int) -> list[str]:
    """Names of a dotted chain that ends at tokens[end] (inclusive), e.g. Config . A . B -> [Config, A, B]."""
    names: list[str] = []
    k = end
    while k >= 0 and tokens[k].kind == "name":
        names.insert(0, tokens[k].val)
        if k >= 2 and is_op(tokens[k - 1], ".") and tokens[k - 2].kind == "name":
            k -= 2
            continue
        break
    return names


# ------------------------------------------------------------------------------------------------ Config loading (Luau)
HARNESS = r"""
local vmt = {}
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, __kind = "Vector3" }, vmt) end
local function num(v) return type(v) == "number" and v or 0 end
vmt.__add = function(a, b) return vec(num(a.X) + num(b.X), num(a.Y) + num(b.Y), num(a.Z) + num(b.Z)) end
vmt.__sub = function(a, b) return vec(num(a.X) - num(b.X), num(a.Y) - num(b.Y), num(a.Z) - num(b.Z)) end
vmt.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	return vec(a.X * num(b.X), a.Y * num(b.Y), a.Z * num(b.Z))
end
vmt.__div = function(a, b) if type(b) == "number" then return vec(a.X / b, a.Y / b, a.Z / b) end return a end
vmt.__unm = function(a) return vec(-a.X, -a.Y, -a.Z) end
vmt.__index = function(v, key)
	if key == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if key == "Unit" then return v end
	return nil
end
local pmt = {}
local function proxy(name) return setmetatable({ __kind = name }, pmt) end
pmt.__index = function(p, k) return proxy(rawget(p, "__kind") .. "." .. tostring(k)) end
pmt.__call = function(p) return proxy(rawget(p, "__kind") .. "()") end
for _, m in { "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm", "__idiv" } do
	pmt[m] = function() return proxy("op") end
end
pmt.__tostring = function(p) return rawget(p, "__kind") end
pmt.__concat = function(a, b) return tostring(a) .. tostring(b) end
pmt.__len = function() return 0 end
pmt.__lt = function() return false end
pmt.__le = function() return false end
local env = { Vector3 = { new = vec, zero = vec(0, 0, 0), one = vec(1, 1, 1) }, Vector2 = { new = vec, zero = vec(0, 0, 0) },
	Color3 = { new = vec, fromRGB = vec, fromHSV = vec, fromHex = function() return vec(0, 0, 0) end } }
local real = getfenv()
setmetatable(env, { __index = function(_, k)
	local v = real[k]
	if v ~= nil then return v end
	if type(k) == "string" and string.match(k, "^%u") then return proxy(k) end
	return nil
end })

local function enc(v)
	local t = type(v)
	if t == "string" then
		return '"' .. (string.gsub(v, '[%c"\\]', function(c)
			return ({ ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\t"] = "\\t", ["\r"] = "\\r" })[c]
				or string.format("\\u%04x", string.byte(c))
		end)) .. '"'
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then return "null" end
		if v == math.floor(v) and math.abs(v) < 2 ^ 53 then return string.format("%d", v) end
		return string.format("%.17g", v)
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "table" then
		local parts = {}
		for i = 1, #v do parts[i] = enc(v[i]) end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	return "null"
end

local fn, err = loadstring(CONFIG_SOURCE, "=Config")
if not fn then print(MARK .. "_LOADERR " .. tostring(err)) return end
setfenv(fn, env)
local ok, Config = pcall(fn)
if not ok or type(Config) ~= "table" then print(MARK .. "_LOADERR " .. tostring(Config)) return end

local seen = {}
local count = 0
local function keysOf(t)
	local nums, strs = {}, {}
	for k in t do
		if type(k) == "number" then table.insert(nums, k) elseif type(k) == "string" then table.insert(strs, k) end
	end
	table.sort(nums)
	table.sort(strs)
	for _, k in strs do table.insert(nums, k) end
	return nums
end
local function walk(v, path)
	local t = type(v)
	count += 1
	if t == "string" then
		print(MARK .. '_E {"p":' .. enc(path) .. ',"s":' .. enc(v) .. "}")
	elseif t == "number" or t == "boolean" then
		print(MARK .. '_E {"p":' .. enc(path) .. ',"n":' .. enc(v) .. "}")
	elseif t == "function" then
		print(MARK .. '_E {"p":' .. enc(path) .. ',"f":1}')
	elseif t == "table" then
		if rawget(v, "__kind") ~= nil then
			print(MARK .. '_E {"p":' .. enc(path) .. ',"u":1}')
			return
		end
		if seen[v] then
			print(MARK .. '_E {"p":' .. enc(path) .. ',"r":' .. enc(seen[v]) .. "}")
			return
		end
		seen[v] = path
		local keys = keysOf(v)
		print(MARK .. '_E {"p":' .. enc(path) .. ',"t":' .. enc(keys) .. "}")
		for _, k in keys do
			local p = table.clone(path)
			table.insert(p, k)
			walk(v[k], p)
		end
	end
end
walk(Config, {})
print(MARK .. "_DONE entries=" .. count)
"""


def long_literal(value: str) -> str:
    eq = "=" * 4
    while "]" + eq + "]" in value:
        eq += "="
    return "[" + eq + "[\n" + value + "]" + eq + "]"


class Ref:
    __slots__ = ("path",)

    def __init__(self, path: tuple):
        self.path = path


def load_config(luau: Path, source: str, workdir: Path, name: str) -> tuple[dict | None, str]:
    """Runs Config in the stub environment; returns (tree, error). Tables are dicts, shared tables are Ref."""
    harness = (f"local CONFIG_SOURCE = {long_literal(source)}\nlocal MARK = \"{MARK}\"\n" + HARNESS)
    path = workdir / f"{name}.luau"
    path.write_text(harness, encoding="utf-8")
    proc = subprocess.run([str(luau), str(path)], capture_output=True, timeout=300)
    stdout = proc.stdout.decode("utf-8", errors="replace")
    root: dict = {}
    done = False
    for line in stdout.splitlines():
        if line.startswith(MARK + "_LOADERR "):
            return None, line[len(MARK) + 9:]
        if line.startswith(MARK + "_DONE"):
            done = True
        if not line.startswith(MARK + "_E "):
            continue
        entry = json.loads(line[len(MARK) + 3:])
        p = tuple(entry["p"])
        if "t" in entry:
            value = {}
        elif "s" in entry:
            value = entry["s"]
        elif "n" in entry:
            value = entry["n"]
        elif "r" in entry:
            value = Ref(tuple(entry["r"]))
        else:
            value = None  # function / engine double
        if not p:
            root = value
            continue
        parent = root
        for k in p[:-1]:
            parent = parent[k]
        parent[p[-1]] = value
    if not done:
        err = proc.stderr.decode("utf-8", errors="replace").strip() or stdout[-1500:]
        return None, "Config walk did not finish: " + err[-1500:]
    return root, ""


def get(tree, path: tuple):
    cur = tree
    for k in path:
        if isinstance(cur, Ref):
            cur = get(tree, cur.path)
        if not isinstance(cur, dict) or k not in cur:
            return None
        cur = cur[k]
    if isinstance(cur, Ref):
        cur = get(tree, cur.path)
    return cur


def fmt_path(path: tuple) -> str:
    out = "Config"
    for k in path:
        if isinstance(k, (int, float)):
            out += f"[{k:g}]" if isinstance(k, float) else f"[{k}]"
        elif IDENT_RE.match(k):
            out += "." + k
        else:
            out += "[" + json.dumps(k, ensure_ascii=False) + "]"
    return out


def leaves(node, path: tuple = ()):
    """(path, string) for every string reachable without following shared-table references."""
    if isinstance(node, str):
        yield path, node
    elif isinstance(node, dict):
        for k, v in node.items():
            if isinstance(v, Ref):
                continue
            yield from leaves(v, path + (k,))


# ------------------------------------------------------------------------------------------------ source line mapping
class LineMap:
    """Maps a Config value back to the line of its literal, using the keys of the enclosing table constructors."""

    def __init__(self, source: str):
        self.tokens = lex(source)
        self.by_value: dict[str, list[tuple[int, tuple]]] = {}
        self.prefixes: list[tuple[str, int, tuple]] = []
        self.used: set[tuple[int, tuple]] = set()
        stack: list[tuple[str, list, bool]] = []
        toks = self.tokens
        for idx, t in enumerate(toks):
            if t.kind == "op" and t.val in ("{", "(", "["):
                keys, absolute = ([], False)
                if t.val == "{":
                    keys, absolute = self._keys_before(idx, not any(f[0] == "{" for f in stack))
                stack.append((t.val, keys, absolute))
            elif t.kind == "op" and t.val in ("}", ")", "]"):
                want = {"}": "{", ")": "(", "]": "["}[t.val]
                while stack:
                    if stack.pop()[0] == want:
                        break
            elif t.kind == "str":
                ctx: list = []
                for typ, keys, absolute in stack:
                    if typ != "{":
                        continue
                    ctx = list(keys) if absolute else ctx + list(keys)
                own, absolute = self._own_key(idx, not any(f[0] == "{" for f in stack))
                ctx = list(own) if absolute else ctx + list(own)
                entry = (t.line, tuple(ctx))
                self.by_value.setdefault(t.val, []).append(entry)
                if len(t.val) >= 8:
                    self.prefixes.append((t.val, t.line, tuple(ctx)))

    def _keys_before(self, idx: int, top: bool) -> tuple[list, bool]:
        toks = self.tokens
        if idx >= 2 and is_op(toks[idx - 1], "="):
            prev = toks[idx - 2]
            if prev.kind == "name":
                chain = chain_back(toks, idx - 2)
                if chain and chain[0] == "Config" and top:
                    return chain[1:], True
                if len(chain) == 1:
                    return chain, False
                return [], False
            if is_op(prev, "]") and idx >= 4 and toks[idx - 3].kind == "str":
                return [toks[idx - 3].val], False
        return [], False

    def _own_key(self, idx: int, top: bool) -> tuple[list, bool]:
        return self._keys_before(idx, top)

    def line_of(self, path: tuple, value: str) -> int | None:
        want = tuple(k for k in path if isinstance(k, str))
        cands = self.by_value.get(value)
        if not cands:
            best = None
            for lit, line, ctx in self.prefixes:  # a value joined with .. at load: its first literal piece
                if value.startswith(lit):
                    score = self._score(ctx, want)
                    if best is None or score > best[0]:
                        best = (score, line)
            return best[1] if best else None

        def rank(c):
            return (self._score(c[1], want), c not in self.used)

        best = max(cands, key=rank)
        self.used.add(best)
        return best[0]

    @staticmethod
    def _score(ctx: tuple, want: tuple) -> int:
        if ctx == want:
            return 1000
        s = 0
        while s < len(ctx) and s < len(want) and ctx[-1 - s] == want[-1 - s]:
            s += 1
        return s


# ------------------------------------------------------------------------------------------------ rules data
SCOPE_ROOTS = [("StoryQuests",), ("Tutorial", "Welcome"), ("Tutorial", "Text"), ("Tutorial", "GuideText"),
               ("Tutorial", "QuestText"), ("Halloween", "Banter"), ("Halloween", "Text"), ("Barks", "Lines"),
               ("Text",), ("Story",), ("StoryLines",), ("Board",)]
SKIP_SUBTREES = {"UIArt", "Requires", "Landmarks", "Main", "Subs", "Boards", "SpawnSpots", "Bosses", "SafeIds",
                 "Factions", "SkipChapters"}
ID_KEYS = {"Type", "Key", "Zone", "Guide", "Npc", "Spot", "Pick", "From", "Item", "Potion", "Unlock", "Show", "Near",
           "Speaker", "Is", "Source", "Id", "Unit", "Big", "Arrival", "Camp", "Gate", "BonusItem", "HintAfter",
           "HintBoard", "Icon", "IconBand", "Season", "King", "Var", "NpcTag", "QuestId", "GuideZone", "Monster",
           "Sound", "SoundId", "Image", "Font", "Anim", "Model", "Tag", "Attribute", "Event", "QuestAs"}
HANGUL_EXEMPT = {("Settings", "Text", "Options", "ko"), ("Settings", "Text", "Options", "koEn")}
FORMAT_EXEMPT = {("Halloween", "Banter", "Days", 9, "GhostKing"): 1}  # lines_pack §4: the only %d in a line
DOC_COUNTS = {("Halloween", "Banter", "Format"): 2, ("Halloween", "Banter", "Days", 9, "GhostKing"): 1,
              ("Tutorial", "QuestText"): 1}
RAW_KEYS = {"Title", "Start", "Finish", "Clue", "Say", "Label", "Lines", "LinesBy", "Name"}

GENDER = {"Bright": "f", "Smokey": "f", "Hallie": "f", "Kit": "f", "Tiny": "m", "Magpie": "m", "Otto": "m",
          "Fizzby": "m"}
PRONOUNS = {"f": re.compile(r"\b(she|her|hers|herself)\b", re.I), "m": re.compile(r"\b(he|him|his|himself)\b", re.I)}
SINGLE_TERMS = {"Forge", "Crossroads", "Hallie", "Magpie", "Otto", "Fizzby", "Smokey", "Kaiju", "Archangel",
                "Berserker", "Warlord"}
CONNECTORS = {"of", "the", "&", "a", "an", "and"}

MONSTER_WORDS = re.compile(r"\b(slimes?|goblins?|skeletons?|ghosts?|monsters?|brutes?|kings?|bats?|pumpkins?|kaiju|"
                           r"boss(es)?|minions?|knights? of bone|zombies?)\b", re.I)
SHOP_CONTEXT = re.compile(r"shop|potion|weapon|forge|blacksmith|merchant|product|ticket|greeting|price|buy|sell",
                          re.I)
SHOP_TEXT = re.compile(r"\b(gold|robux|buy|price|shop|potion|ticket|sale)\b", re.I)

# 9. one / many: plural count nouns a number stands before ('1 days' is wrong, '1 gold' is fine: gold is no count noun)
PLURAL_NOUNS = {"days", "times", "minutes", "seconds", "hours", "weeks", "hits", "kills", "monsters", "slimes",
                "goblins", "skeletons", "ghosts", "pumpkins", "bats", "brutes", "kings", "bosses", "players", "people",
                "quests", "materials", "items", "stars", "points", "coins", "potions", "scrolls", "steps", "levels",
                "friends", "rounds", "wins", "jobs", "knights", "arrows", "pets", "gems", "shards", "enemies",
                "trials", "sacks", "goals", "tries", "chances", "rebirths"}
COUNT_WORDS_RE = re.compile(r"[A-Za-z']+(?: [A-Za-z']+){0,2}")
ONE_RE = re.compile(r"(?<![\d.,/])1 (?=[A-Za-z])")
DSPEC_RE = re.compile(r"(?<!/)%[-+ #0]*\d*[di] (?=[A-Za-z])")  # not the max of '%d/%d players'


# 10. ShortName: the phone quest row's name
SHORT_MAX = 14
SHORT_NEEDS = [(("StoryQuests", "Defs"), "story quest"), (("Quests", "Templates"), "daily / extra quest template"),
               (("Board", "Jobs"), "board job")]
TUT_SHORT_KEYS = ("Welcome", "Travel", "Quest", "Forge", "IronLevel", "IronGold", "Zone")


def count_phrase(after: str) -> str | None:
    """the words right after a number up to the first plural count noun (max 3 words): 'days', 'Wanted players'"""
    m = COUNT_WORDS_RE.match(after)
    if not m:
        return None
    words = m.group(0).split(" ")
    for i, w in enumerate(words):
        if w.lower() in PLURAL_NOUNS:
            return " ".join(words[:i + 1])
    return None


def count_templates(text: str) -> list[str]:
    """the count phrases after each '%d ' in a format text"""
    return [ph for m in DSPEC_RE.finditer(text) if (ph := count_phrase(text[m.end():]))]


def call_start(toks: list, i: int) -> int:
    """index of the first token of the callee chain ending at toks[i] (a.b.c -> index of a)"""
    while i >= 2 and is_op(toks[i - 1], ".") and toks[i - 2].kind == "name":
        i -= 2
    return i


def plural_wrapped(toks: list, i: int) -> bool:
    """the call starting at toks[i] (string.format / a format helper) is the first argument of Plural(...)"""
    return i >= 2 and is_op(toks[i - 1], "(") and toks[i - 2].kind == "name" and toks[i - 2].val == "Plural"


def _w(words: str) -> re.Pattern:
    return re.compile(r"\b(" + words + r")\b", re.I)


BANNED = [
    # (rule, level, regex, note)
    ("banned-gore", "error", _w(r"blood|bloody|bleed|bleeds|bleeding|gore|gory|guts|corpses?|murder\w*|behead\w*|"
                                r"decapitat\w*|stab|stabs|stabbed|stabbing|torture\w*|suicide|slaughter\w*|guns?"),
     "gore / violence word"),
    ("banned-swear", "error", _w(r"hell|damn|damned|crap|shit|bitch|bastard|wtf|omfg"), "swear word"),
    ("banned-romance", "error", re.compile(r"\b(kiss|kisses|kissed|kissing|boyfriends?|girlfriends?|romance|romantic|"
                                           r"sweethearts?|flirt\w*|dating|a date|on a date|date night|a crush|"
                                           r"crush on|crushing on)\b", re.I), "romance word (kids 8-12, M5_7 rule)"),
    ("banned-romance", "warn", _w(r"marry|married|marries|wedding|love letter"), "romance-ish word"),
    ("banned-scary", "warn", _w(r"scary|scared|scare|scares|terrifying|terrified|terror|horror|nightmares?|creepy|"
                                r"spooky"), "scary word (keep it light)"),
    ("banned-insult", "warn", _w(r"stupid|idiot|idiots|dumb|shut up|hate|hates|hated|loser|losers|ugly|fatty"),
     "insult word"),
    ("banned-real", "warn", _w(r"roblox|robux|minecraft|fortnite|youtube|tiktok|disney|pok[eé]mon|nintendo|mario|"
                               r"apple|iphone|google|mcdonald'?s|coca-cola|pepsi|starbucks|nike|lego|marvel|batman|"
                               r"america|american|usa|korea|japan|china|russia|mexico|canada|france|germany|england|"
                               r"india|brazil|ukraine|israel|iran|god|gods|jesus|christ|allah|buddha|bible|quran|"
                               r"koran|church|mosque|christian|muslim|jewish|hindu|satan|lucifer|trump|biden|obama|"
                               r"putin|xi jinping|kim jong"), "real brand / place / religion / person"),
]
DEATH_RE = _w(r"die|dies|died|dying|dead|death|deaths|kill|kills|killed|killing|killer|killers")
MONEY_RE = re.compile(r"((?<!is )(?<!are )(?<!be )(?<!now )\bfree\s*!|\bsale\b|\bon sale\b|\bhurry\b|\blimited\b|\bbuy now\b|"
                      r"\blast chance\b|\btoday only\b|\bonly today\b|\bdiscount\w*\b|\d+\s*%\s*off\b|"
                      r"\bdon'?t miss\b|\bbefore it'?s gone\b)", re.I)
MONEY_CAPS_RE = re.compile(r"\bFREE\b")  # shouting FREE; a plain "free" is a verb or a fact ("free the road")
SPEC_RE = re.compile(r"%(%|[-+ #0]*\d*(?:\.\d+)?[cdiouxXeEfgGqsaA])")


def specs(text: str) -> tuple[list[str], bool, bool]:
    """(conversion chars, has lone %, has %%) of a string.format template."""
    out, lone, escaped = [], False, False
    i = 0
    while True:
        i = text.find("%", i)
        if i < 0:
            break
        m = SPEC_RE.match(text, i)
        if not m:
            lone = True
            i += 1
            continue
        if m.group(1) == "%":
            escaped = True
        else:
            out.append(m.group(1)[-1])
        i = m.end()
    return out, lone, escaped


def word_count(segment: str, speakers: set[str]) -> int:
    body = segment.strip()
    m = re.match(r"^([A-Z][\w'.]*(?: [A-Z&][\w'.]*){0,2}):\s", body)
    if m and m.group(1) in speakers:
        body = body[m.end():]
    return sum(1 for tok in body.split() if re.search(r"[A-Za-z0-9%{]", tok))


def glossary_terms(path: Path) -> list[str]:
    if not path.is_file():
        return []
    terms: set[str] = set()
    for row in path.read_text(encoding="utf-8").splitlines():
        if not row.startswith("|"):
            continue
        cells = [c.strip() for c in row.strip().strip("|").split("|")]
        if len(cells) < 2 or set(cells[1]) <= set("-: ") or cells[1] == "English":
            continue
        chunks = [cells[1].replace("**", "")]
        if len(cells) > 2:
            chunks += re.findall(r"\*\*(.+?)\*\*", cells[2])
        for chunk in chunks:
            for part in re.split(r"\s*/\s*|\s*·\s*", chunk):
                part = re.sub(r"\(.*?\)", "", part).replace(" N%", "").strip()
                if not part or HANGUL_RE.search(part) or not re.search(r"[A-Za-z]", part):
                    continue
                words = part.split()
                if len(words) == 1:
                    if part in SINGLE_TERMS:
                        terms.add(part)
                    continue
                if all(w in CONNECTORS or w[0].isupper() or not w[0].isalpha() for w in words):
                    terms.add(part)
    return sorted(terms, key=lambda s: (-len(s), s))


# ------------------------------------------------------------------------------------------------ the checker
class Checker:
    def __init__(self, src: Path, glossary: list[str]):
        self.src = src
        self.glossary = [(t, re.compile(r"(?<![A-Za-z])(" + r"\s+".join(re.escape(w) for w in t.split())
                                       + r")(?:s|es)?(?![A-Za-z])", re.I)) for t in glossary]
        self.files: dict[str, list[Tok]] = {}
        for p in sorted(src.rglob("*.luau")):
            rel = p.relative_to(src).as_posix()
            if p.relative_to(src) == CONFIG_REL:
                continue
            self.files[rel] = lex(p.read_text(encoding="utf-8-sig").replace("\r\n", "\n"))
        self.callsites = self._format_callsites()

    # ---------------------------------------------------------------- string.format call sites in src/
    def _format_callsites(self) -> list[dict]:
        sites = []
        for rel, toks in self.files.items():
            alias: dict[str, tuple | None] = {}
            for i, t in enumerate(toks):
                if t.kind == "name" and t.val == "local" and i + 3 < len(toks) and toks[i + 1].kind == "name" \
                        and is_op(toks[i + 2], "="):
                    name = toks[i + 1].val
                    nxt = toks[i + 3]
                    target = None
                    if nxt.kind == "name" and nxt.val == "require" and is_op(toks[i + 4] if i + 4 < len(toks) else None, "("):
                        k, inner = i + 5, []
                        while k < len(toks) and not is_op(toks[k], ")"):
                            inner.append(toks[k].val)
                            k += 1
                        if "Config" in inner or '"Config"' in inner:
                            target = ()
                    elif nxt.kind == "name":
                        k, chain = i + 3, [nxt.val]
                        while k + 2 < len(toks) and is_op(toks[k + 1], ".") and toks[k + 2].kind == "name":
                            chain.append(toks[k + 2].val)
                            k += 2
                        after = toks[k + 1] if k + 1 < len(toks) else None
                        if not (after and after.kind == "op" and after.val in (".", "[", "(", ":")):
                            head = chain[0]
                            if head == "Config" and "Config" not in alias:
                                target = tuple(chain[1:])
                            elif head in alias and alias[head] is not None:
                                target = alias[head] + tuple(chain[1:])
                    if target is not None:
                        alias[name] = target if name not in alias or alias[name] == target else None
            if "Config" not in alias:
                alias["Config"] = ()
            for i, t in enumerate(toks):
                start = None
                wrapped = False
                if t.kind == "name" and t.val == "string" and i + 3 < len(toks) and is_op(toks[i + 1], ".") \
                        and toks[i + 2].val == "format" and is_op(toks[i + 3], "("):
                    if i >= 2 and is_op(toks[i - 1], "(") and toks[i - 2].val == "pcall":
                        continue  # pcall(string.format, ...) handled below
                    start = i + 4
                    wrapped = plural_wrapped(toks, i)
                elif t.kind == "name" and t.val == "pcall" and i + 5 < len(toks) and is_op(toks[i + 1], "(") \
                        and toks[i + 2].val == "string" and toks[i + 4].val == "format" and is_op(toks[i + 5], ","):
                    start = i + 6
                if start is None or start >= len(toks) or toks[start].kind != "name":
                    continue
                head = toks[start].val
                if head not in alias or alias[head] is None:
                    continue
                path, k, dynamic = list(alias[head]), start, False
                while True:
                    if k + 2 < len(toks) and is_op(toks[k + 1], ".") and toks[k + 2].kind == "name":
                        path.append(toks[k + 2].val)
                        k += 2
                    elif k + 3 < len(toks) and is_op(toks[k + 1], "[") and toks[k + 2].kind == "str" \
                            and is_op(toks[k + 3], "]"):
                        path.append(toks[k + 2].val)
                        k += 3
                    elif k + 1 < len(toks) and is_op(toks[k + 1], "[") and not dynamic:
                        depth, k = 0, k + 1
                        while k < len(toks):
                            if is_op(toks[k], "["):
                                depth += 1
                            elif is_op(toks[k], "]"):
                                depth -= 1
                                if depth == 0:
                                    break
                            k += 1
                        dynamic = True
                    else:
                        break
                nxt = toks[k + 1] if k + 1 < len(toks) else None
                if not (nxt and nxt.kind == "op" and nxt.val in (",", ")")) or not path:
                    continue
                # count the remaining arguments up to the closing parenthesis
                args, depth, j, last_start, variadic = 0, 0, k + 1, None, False
                if is_op(nxt, ","):
                    args, last_start = 1, k + 2
                    j = k + 2
                    while j < len(toks):
                        tj = toks[j]
                        if tj.kind == "op" and tj.val in ("(", "{", "["):
                            depth += 1
                        elif tj.kind == "op" and tj.val in (")", "}", "]"):
                            if depth == 0:
                                break
                            depth -= 1
                        elif is_op(tj, ",") and depth == 0:
                            args += 1
                            last_start = j + 1
                        j += 1
                    last = toks[last_start:j] if last_start is not None else []
                    if last and (is_op(last[0], "...") or any(x.val in ("unpack",) for x in last[:3])):
                        variadic = True
                sites.append({"file": rel, "line": t.line, "path": tuple(path), "dynamic": dynamic, "args": args,
                              "variadic": variadic, "wrapped": wrapped})
        return sites

    # ---------------------------------------------------------------- one run over a loaded Config
    def run(self, tree: dict, source: str) -> list[dict]:
        findings: list[dict] = []
        lm = LineMap(source)
        line_cache: dict[tuple, int | None] = {}

        def line_of(path, value):
            if path not in line_cache:
                line_cache[path] = lm.line_of(path, value)
            return line_cache[path]

        defs = get(tree, ("StoryQuests", "Defs")) or {}
        hidden_defs = {d for d, v in defs.items() if isinstance(v, dict) and isinstance(v.get("Factions"), dict)
                       and set(v["Factions"]) == {"Neutral"}}

        def hidden(path) -> bool:
            for k in path:
                if isinstance(k, str) and re.search(r"Neutral|Guild|Artisan", k):
                    return True
            return len(path) > 2 and path[:2] == ("StoryQuests", "Defs") and path[2] in hidden_defs

        def add(level, rule, path, text, detail, line="auto", file=None):
            f = {"level": level, "rule": rule, "path": fmt_path(path) if isinstance(path, tuple) else path,
                 "file": file or ("src/" + CONFIG_REL.as_posix()), "line": None, "text": text[:240],
                 "detail": detail}
            if line == "auto" and isinstance(path, tuple):
                full = get(tree, path)
                f["line"] = line_of(path, full) if isinstance(full, str) else None
            elif line != "auto":
                f["line"] = line
            if isinstance(path, tuple) and hidden(path) and level in ("error", "warn"):
                f["levelIfShown"] = level
                f["level"] = "info"
                f["detail"] += " (Neutral / Guild text: hidden in the beta, A23-57)"
            findings.append(f)

        # speakers for the word count (a "Name:" prefix is not counted)
        speakers = {"Brute", "Goblin", "Shard", "Guide", "Pumpkin King", "Ghost King", "Fountain Shard",
                    "Crown Shard", "Sir Gleam", "Rascal Rex"} | set(GENDER)
        for p, s in leaves(get(tree, ("StoryQuests", "Speakers")) or {}):
            speakers.add(s)
        for p, s in leaves(get(tree, ("Tutorial", "Welcome")) or {}):
            if p and p[-1] == "Name":
                speakers.add(s)
        for kind, mt in (get(tree, ("MonsterTypes",)) or {}).items():
            if isinstance(mt, dict):
                for key in ("Name", "Short"):
                    if isinstance(mt.get(key), str):
                        speakers.add(mt[key])

        # ---- 1. Hangul in Config
        for path, s in leaves(tree):
            if path[:1] == ("UIArt",) or path in HANGUL_EXEMPT:
                continue
            if HANGUL_RE.search(s):
                add("error", "hangul", path, s, "Hangul in a Config string (the game shows English only, A23-48)")
        # Hangul in other src/ literals (and Config literals that are not values, e.g. inside functions)
        values = {s for _, s in leaves(tree)}
        for t in lm.tokens:
            if t.kind in ("str", "istr") and HANGUL_RE.search(t.val) and t.val not in values:
                add("error", "hangul", f"Config.luau:{t.line}", t.val, "Hangul literal inside Config code",
                    line=t.line)

        # ---- scope for checks 2-7
        scoped: list[tuple[tuple, str]] = []
        for root in SCOPE_ROOTS:
            node = get(tree, root)
            if isinstance(node, str):
                scoped.append((root, node))
            elif isinstance(node, dict):
                scoped += [(root + p, s) for p, s in leaves(node)]
        covered = {p for p, _ in scoped}
        for path, s in leaves(tree):  # every other table named Text
            if path in covered or path[:1] == ("UIArt",):
                continue
            if any(k == "Text" for k in path[:-1] if isinstance(k, str)):
                scoped.append((path, s))

        def is_id(path) -> bool:
            for i, k in enumerate(path):
                if not isinstance(k, str):
                    continue
                if k in SKIP_SUBTREES:
                    return True
                if k in ID_KEYS and i == len(path) - 1:
                    return True
                if k == "Kind" and "Jobs" not in path:  # a quest / item kind id (Board job Kind = a button text)
                    return True
                if k == "Obj" and i == len(path) - 2 and path[-1] in ("Type", "Kind", "Key"):
                    return True
            return False

        def en_copy(path, value) -> bool:
            """an XEn twin holding the same text as X (test_english keeps them equal): checked once, on X"""
            for i in range(len(path) - 1, -1, -1):
                k = path[i]
                if isinstance(k, str) and k.endswith("En") and len(k) > 2:
                    if get(tree, path[:i] + (k[:-2],) + path[i + 1:]) == value:
                        return True
            return False

        texts = [(p, s) for p, s in scoped if not is_id(p) and not en_copy(p, s)]

        def is_raw(path) -> bool:
            """shown as it is (never through string.format)"""
            if path[:1] in (("Barks",), ("StoryLines",)):
                return True
            if path[:2] == ("Halloween", "Banter") and path[-1] != "Format":
                return True
            if path[:2] == ("Tutorial", "Welcome") or path[:2] == ("StoryQuests", "Speakers"):
                return True
            if path[:2] == ("StoryQuests", "Defs"):
                if any(isinstance(k, str) and k in RAW_KEYS for k in path[3:]):
                    return True
                if len(path) >= 2 and path[-2] == "Neutral" and path[-1] in ("A", "B"):
                    return True
            if path[:2] == ("Board", "Jobs") and any(k in ("Kind", "Sneaky") for k in path if isinstance(k, str)):
                return True
            return False

        # ---- 2-4, 7 per line
        for path, s in texts:
            bark = path[:1] == ("Barks",)
            for seg in s.split("\n"):
                if not seg.strip():
                    continue
                n = word_count(seg, speakers)
                if n > 18:
                    add("error", "length", path, seg, f"{n} words (> 18)")
                elif n > 14:
                    add("warn", "length", path, seg, f"{n} words (> 14)")
                elif bark and n > 8:
                    add("warn", "length-bark", path, seg, f"bark {n} words (> 8)")
                for rule, level, rx, note in BANNED:
                    m = rx.search(seg)
                    if m:
                        add(level, rule, path, seg, f"'{m.group(0)}': {note}")
                m = DEATH_RE.search(seg)
                if m:
                    if MONSTER_WORDS.search(seg):
                        add("warn", "banned-death", path, seg,
                            f"'{m.group(0)}' about a monster: prefer 'beat' / 'defeat'")
                    else:
                        add("error", "banned-death", path, seg, f"'{m.group(0)}' (die / dead / kill about people)")
                m = MONEY_RE.search(seg) or MONEY_CAPS_RE.search(seg)
                if m:
                    shop = bool(SHOP_CONTEXT.search(fmt_path(path)) or SHOP_TEXT.search(seg))
                    add("error" if shop else "warn", "banned-money", path, seg,
                        f"'{m.group(0)}': money pressure" + (" next to a shop / price line" if shop else ""))
                for term, rx in self.glossary:
                    for gm in rx.finditer(seg):
                        got = gm.group(1)
                        if got != term and not got.isupper() and re.sub(r"\s+", " ", got) != term:
                            add("warn", "glossary-case", path, seg, f"'{got}' -> '{term}' (glossary_en)")
                # pronouns: names in the body (not the speaker prefix)
                body = seg
                pm = re.match(r"^([A-Z][\w'.]*(?: [A-Z&][\w'.]*){0,2}):\s", seg.strip())
                if pm and pm.group(1) in speakers:
                    body = seg.strip()[pm.end():]
                named = {g for name, g in GENDER.items() if re.search(r"\b" + name + r"\b", body)}
                if len(named) == 1:
                    g = named.pop()
                    other = "m" if g == "f" else "f"
                    if PRONOUNS[other].search(body) and not PRONOUNS[g].search(body):
                        who = [name for name in GENDER if GENDER[name] == g and re.search(r"\b" + name + r"\b", body)]
                        add("warn", "pronoun", path, seg,
                            f"{', '.join(who)} = {'she/her' if g == 'f' else 'he/him'}, the line says "
                            f"'{PRONOUNS[other].search(body).group(0)}'")

        # ---- 5. LinesBy
        def walk_tables(node, path=()):
            if isinstance(node, dict):
                yield path, node
                for k, v in node.items():
                    if isinstance(v, dict):
                        yield from walk_tables(v, path + (k,))

        for path, node in walk_tables(tree):
            if path and path[-1] == "LinesBy":
                if node.get("Default") is None:
                    add("error", "linesby-default", path, "LinesBy keys: " + ", ".join(map(str, node)),
                        "LinesBy without Default (old saves have no picks: story_depth E2)",
                        line=self._table_line(lm, path))
                src_id = node.get("From")
                if isinstance(src_id, str) and src_id not in defs:
                    add("warn", "linesby-from", path, f"From = {src_id}", "LinesBy.From is not a story quest id",
                        line=self._table_line(lm, path))

        # ---- 6. placeholders
        text_paths = {p for p, _ in texts}
        for path, s in texts:
            conv, lone, escaped = specs(s)
            raw = is_raw(path)
            if raw:
                allowed = FORMAT_EXEMPT.get(path)
                if allowed is not None:
                    if len(conv) != allowed:
                        add("error", "format-stray", path, s, f"{len(conv)} placeholders, the doc allows {allowed}")
                elif conv:
                    add("error", "format-stray", path, s, f"'%{conv[0]}' in a line shown as it is (never formatted)")
                if escaped and allowed is None:
                    add("warn", "format-percent", path, s, "'%%' in a raw line shows two percent signs")
            elif lone and conv:
                add("error", "format-percent", path, s, "a lone '%' in a format string: string.format throws")
        for path, want in DOC_COUNTS.items():
            s = get(tree, path)
            if isinstance(s, str) and len(specs(s)[0]) != want:
                add("error", "format-doc", path, s, f"{len(specs(s)[0])} placeholders, the design doc says {want}")
        jobs = get(tree, ("Board", "Jobs"))
        if isinstance(jobs, dict):
            for idx, job in jobs.items():
                if isinstance(job, dict) and isinstance(job.get("Goal"), str):
                    n = len(specs(job["Goal"])[0])
                    if n != 2:
                        add("error", "format-doc", ("Board", "Jobs", idx, "Goal"), job["Goal"],
                            f"{n} placeholders, Board Goal takes %d/%d (Config comment)")
        # story step Text against StoryQuestService.rowFor
        for did, d in defs.items():
            if not isinstance(d, dict) or not isinstance(d.get("Steps"), dict):
                continue
            for si, step in d["Steps"].items():
                if not isinstance(step, dict):
                    continue
                variants = [((), step)]
                for fac in ("Halo", "Horns", "Neutral"):
                    if isinstance(step.get(fac), dict):
                        variants.append(((fac,), step[fac]))
                for suffix, var in variants:
                    text = var.get("Text") if isinstance(var.get("Text"), str) else (
                        step.get("Text") if suffix else None)
                    if not isinstance(text, str):
                        continue
                    if suffix and not isinstance(var.get("Text"), str):
                        continue  # the override keeps the base text: checked with the base step
                    obj = var.get("Obj") if isinstance(var.get("Obj"), dict) else (step.get("Obj") or {})
                    n = len(specs(text)[0])
                    path = ("StoryQuests", "Defs", did, "Steps", si) + suffix + ("Text",)
                    typ, stay = obj.get("Type"), obj.get("Stay")
                    if typ == "Trials":
                        want, hard = 1, "string.format(text, done): more than 1 throws"
                    elif typ == "Level":
                        want, hard = 1, "string.format(text, level): more than 1 throws"
                    elif typ == "Near" and isinstance(stay, (int, float)) and stay > 0:
                        want, hard = 2, "pcall(format, text, progress, stay): more than 2 shows '%d' raw"
                    elif obj.get("Key") == "OwnIron":
                        want, hard = 1, "string.format(text, gold): more than 1 throws"
                    elif obj.get("Count") is not None:
                        want, hard = 2, "pcall(format, text, progress, count): more than 2 shows '%d' raw"
                    else:
                        want, hard = 0, "this step type shows the text as it is"
                    if n > want:
                        add("error", "format-step", path, text, f"{n} placeholders; {hard}")
                    elif n < want and typ in ("Trials", "Level") or (n < want and obj.get("Key") == "OwnIron"):
                        add("warn", "format-step", path, text, f"{n} placeholders, the row passes {want}")
                    elif n < want and want == 2 and n == 0 and isinstance(obj.get("Count"), (int, float)) \
                            and obj.get("Count", 0) > 1:
                        add("info", "format-step", path, text, "no %d/%d: the row text shows no progress numbers")
        # X / XEn twins
        for path, node in walk_tables(tree):
            if path[:1] == ("UIArt",):
                continue
            for k, v in node.items():
                if isinstance(k, str) and isinstance(v, str) and isinstance(node.get(k + "En"), str):
                    a, b = specs(v)[0], specs(node[k + "En"])[0]
                    if a != b:
                        add("error", "format-twin", path + (k + "En",), node[k + "En"],
                            f"{k}En has placeholders {b}, {k} has {a}")
        # call sites
        for site in self.callsites:
            node = get(tree, site["path"])
            targets = []
            if site["dynamic"] and isinstance(node, dict):
                targets = [(site["path"] + (k,), v) for k, v in node.items() if isinstance(v, str)]
            elif isinstance(node, str) and not site["dynamic"]:
                targets = [(site["path"], node)]
            for path, s in targets:
                n = len(specs(s)[0])
                where = f"{site['file']}:{site['line']} passes {site['args']}"
                if site["dynamic"]:  # Config.X[key]: which keys reach this call is unknown
                    if n != site["args"] and not site["variadic"]:
                        add("info", "format-callsite", path, s,
                            f"{n} placeholders; {where} for some key of {fmt_path(site['path'])} (dynamic, unverified)")
                elif site["variadic"]:
                    if n < site["args"] - 1:
                        add("warn", "format-callsite", path, s, f"{n} placeholders; {where}+ (variadic)")
                elif n > site["args"]:
                    add("error", "format-callsite", path, s, f"{n} placeholders but {where}: string.format throws")
                elif n < site["args"]:
                    add("warn", "format-callsite", path, s, f"{n} placeholders but {where}: extra values not shown")
        # ---- 9. one / many (검수 2026-10-07)
        plural_words = get(tree, ("PluralWords",))
        plural_words = plural_words if isinstance(plural_words, dict) else {}
        for path, s in texts:
            for m in ONE_RE.finditer(s):
                ph = count_phrase(s[m.end():])
                if ph:
                    one = plural_words.get(ph)
                    add("error", "plural-one", path, s,
                        f"'1 {ph}': say '1 {one}'" if one else f"'1 {ph}': use the singular after 1")
            if is_raw(path):
                continue
            for ph in count_templates(s):
                if ph not in plural_words:
                    add("error", "plural-word", path, s, f"'%d {ph}' but Config.PluralWords has no '{ph}': "
                        f"Config.Plural cannot say '1 <singular>' (add {ph!r} = its singular)")
        for site in self.callsites:
            if site["wrapped"]:
                continue
            node = get(tree, site["path"])
            if site["dynamic"] and isinstance(node, dict):
                for k, v in node.items():
                    if isinstance(v, str) and count_templates(v):
                        add("info", "plural-callsite", site["path"] + (k,), v,
                            f"{site['file']}:{site['line']} formats {fmt_path(site['path'])}[key] without "
                            "Config.Plural (dynamic, unverified)")
            elif isinstance(node, str) and not site["dynamic"] and count_templates(node):
                add("error", "plural-callsite", site["path"], node,
                    f"{site['file']}:{site['line']}: wrap it: Config.Plural(string.format(...)) "
                    f"('{count_templates(node)[0]}' after a 1)")
        for rel, toks in self.files.items():
            stack: list[tuple[str, int]] = []  # (callee, index of its first token) per open parenthesis
            for i, t in enumerate(toks):
                if t.kind == "op" and t.val == "(":
                    named = i and toks[i - 1].kind == "name"
                    stack.append((".".join(chain_back(toks, i - 1)) if named else "",
                                  call_start(toks, i - 1) if named else i))
                    continue
                if t.kind == "op" and t.val == ")":
                    if stack:
                        stack.pop()
                    continue
                if t.kind != "str" or not count_templates(t.val):
                    continue
                if any(c.split(".")[-1] in ("warn", "print", "error", "assert", "find", "match", "gmatch", "gsub")
                       for c, _ in stack):
                    continue  # developer logs and text matchers never reach the screen as counts
                inline = bool(stack) and stack[-1][0] == "string.format" and is_op(toks[i - 1], "(")
                key = toks[i - 2].val if i >= 2 and is_op(toks[i - 1], "=") and toks[i - 2].kind == "name" else None
                if not inline and not key:
                    continue  # not a format string here (a table-field text or string.format("...", n) is)
                phrases = count_templates(t.val)
                missing = [ph for ph in phrases if ph not in plural_words]
                where = {"file": "src/" + rel, "line": t.line, "text": t.val[:240]}
                if missing:
                    findings.append({"level": "error", "rule": "plural-literal", "path": f"{rel}:{t.line}", **where,
                                     "detail": f"'%d {missing[0]}' is not in Config.PluralWords"})
                if inline:
                    if not plural_wrapped(toks, stack[-1][1]):
                        findings.append({"level": "warn", "rule": "plural-literal", "path": f"{rel}:{t.line}", **where,
                                         "detail": f"string.format(\"...\") without Config.Plural ('1 {phrases[0]}')"})
                    continue
                uses = []  # string.format(<x>.key, ...) in this file: wrapped or not
                for j in range(len(toks) - 5):
                    if toks[j].val == "string" and is_op(toks[j + 1], ".") and toks[j + 2].val == "format" \
                            and is_op(toks[j + 3], "("):
                        k = j + 4
                        while k + 2 < len(toks) and toks[k].kind == "name" and is_op(toks[k + 1], "."):
                            k += 2
                        if key and toks[k].kind == "name" and toks[k].val == key and k > j + 4:
                            uses.append((toks[j].line, plural_wrapped(toks, j)))
                bare = [ln for ln, ok in uses if not ok]
                if bare or not uses:
                    findings.append({"level": "warn", "rule": "plural-literal", "path": f"{rel}:{t.line}", **where,
                                     "detail": ("formatted without Config.Plural at line " + ", ".join(map(str, bare))
                                                if bare else "no string.format(<table>." + str(key) + ") found: "
                                                "wrap the formatted line in Config.Plural(...)")
                                     + f" ('1 {phrases[0]}')"})
        # ---- 10. ShortName (검수 2026-10-07)
        for path, s in leaves(tree):
            if not path or not (path[-1] in ("ShortName", "HintShort") or (len(path) >= 2 and path[-2] == "ShortNames")):
                continue
            shown = re.sub(r"%[-+ #0]*\d*[di]", "10", s)
            if "%s" in s:
                add("error", "shortname-length", path, s, "'%s' in a ShortName: its length on the row is unknown")
            elif len(shown) > SHORT_MAX:
                add("error", "shortname-length", path, s,
                    f"{len(shown)} characters (> {SHORT_MAX}): the phone quest row cuts it")
        for root, what in SHORT_NEEDS:
            node = get(tree, root)
            if not isinstance(node, dict):
                continue
            for k, v in node.items():
                if isinstance(v, dict) and not isinstance(v.get("ShortName"), str):
                    label = v.get("Title") or v.get("Goal") or v.get("Text") or v.get("Id") or k
                    add("error", "shortname-missing", root + (k,), str(label), f"{what} without ShortName",
                        line=self._table_line(lm, root + (k,)))
        tut = get(tree, ("Tutorial", "ShortNames"))
        for key in TUT_SHORT_KEYS:
            if not (isinstance(tut, dict) and isinstance(tut.get(key), str)):
                add("error", "shortname-missing", ("Tutorial", "ShortNames", key), key,
                    "first-mission row (QuestService.tutorialEntry) without ShortName", line=None)
        btext = get(tree, ("Board", "Text"))
        if isinstance(btext, dict) and isinstance(btext.get("Hint"), str) and not isinstance(btext.get("HintShort"), str):
            add("error", "shortname-missing", ("Board", "Text", "HintShort"), btext["Hint"],
                "the Job Board hint row without HintShort", line=None)
        # ---- Hangul in other src files
        for rel, toks in self.files.items():
            stack: list[str] = []
            for i, t in enumerate(toks):
                if t.kind == "op" and t.val == "(":
                    callee = ".".join(chain_back(toks, i - 1)) if i and toks[i - 1].kind == "name" else ""
                    stack.append(callee)
                elif t.kind == "op" and t.val == ")":
                    if stack:
                        stack.pop()
                elif t.kind in ("str", "istr") and HANGUL_RE.search(t.val):
                    callee = stack[-1] if stack else ""
                    leaf = callee.split(".")[-1]
                    if rel.endswith("NicknameService.luau"):
                        level, why = "info", "NicknameService word list (never shown)"
                    elif leaf in ("find", "match", "gmatch", "gsub", "split"):
                        level, why = "info", f"text matcher {callee}() (never shown)"
                    elif leaf in ("warn", "print", "error", "assert") or callee.endswith(".log"):
                        level, why = "info", f"developer log {callee}() (Output window only)"
                    else:
                        level, why = "error", "Hangul literal in code (may reach the screen)"
                    findings.append({"level": level, "rule": "hangul", "path": f"{rel}:{t.line}",
                                     "file": "src/" + rel, "line": t.line, "text": t.val[:240], "detail": why})
        # drop duplicates (same rule, path, text)
        seen, out = set(), []
        for f in findings:
            key = (f["rule"], f["path"], f["text"], f["detail"])
            if key not in seen:
                seen.add(key)
                out.append(f)
        return out

    @staticmethod
    def _table_line(lm: LineMap, path: tuple) -> int | None:
        """line of the first literal inside the table at `path` (by context keys)"""
        want = tuple(k for k in path if isinstance(k, str))
        best = None
        for value, entries in lm.by_value.items():
            for line, ctx in entries:
                if ctx[:len(want)] == want:
                    if best is None or line < best:
                        best = line
        return best


# ------------------------------------------------------------------------------------------------ mutations
MUTATIONS = [
    ("a Hangul story line", "hangul", ("Story", "MutHangul"),
     'Config.Story.MutHangul = "왕관 조각을 찾아요"'),
    ("a 20-word toast", "length", ("Text", "MutLong"),
     'Config.Text.MutLong = "This toast line is far too long because it keeps going and going for many more words today"'),
    ("a LinesBy without Default", "linesby-default", ("StoryQuests", "Defs", "MutNoDefault", "Steps", 1, "LinesBy"),
     'Config.StoryQuests.Defs.MutNoDefault = { Kind = "Sub", Title = "Mutant Talk", Steps = { { Text = "Talk", '
     'Panel = true, Obj = { Type = "Talk" }, Lines = { All = { "Hi there." } }, LinesBy = { From = "M2_3", '
     'Good = { All = { "You gave it back." } } } } } }'),
    ("a stray %d in a story page line", "format-stray",
     ("StoryQuests", "Defs", "MutStray", "Steps", 1, "Lines", "All", 1),
     'Config.StoryQuests.Defs.MutStray = { Kind = "Sub", Title = "Mutant Count", Steps = { { Text = "Talk", '
     'Panel = true, Obj = { Type = "Talk" }, Lines = { All = { "You beat %d slimes today!" } } } } }'),
    ("a gore word in a toast", "banned-gore", ("Text", "MutBanned"),
     'Config.Text.MutBanned = "There is blood on the meadow path."'),
    ("a glossary name in lower case", "glossary-case", ("Text", "MutCase"),
     'Config.Text.MutCase = "Welcome to the haunted hollow!"'),
    ("'1 days' in a toast", "plural-one", ("Text", "MutOneDays"),
     'Config.Text.MutOneDays = "Welcome back! You were away for 1 days."'),
    ("a count text whose noun Config.Plural does not know", "plural-word", ("Text", "MutCount"),
     'Config.Text.MutCount = "Find %d stars in the meadow"'),
    ("a 16-character ShortName", "shortname-length", ("StoryQuests", "Defs", "MutShort", "ShortName"),
     'Config.StoryQuests.Defs.MutShort = { Kind = "Sub", Title = "Mutant Name", ShortName = "A very long name", '
     'Steps = { { Text = "Talk", Obj = { Type = "Talk" } } } }'),
    ("a story quest without ShortName", "shortname-missing", ("StoryQuests", "Defs", "MutNoShort"),
     'Config.StoryQuests.Defs.MutNoShort = { Kind = "Sub", Title = "Mutant Two", '
     'Steps = { { Text = "Talk", Obj = { Type = "Talk" } } } }'),
]


def mutate(source: str, statement: str) -> str:
    at = source.rfind("\nreturn Config")
    if at < 0:
        raise ValueError("Config.luau has no final 'return Config'")
    return source[:at] + "\n" + statement + "\n" + source[at:]


# ------------------------------------------------------------------------------------------------ main
def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--src", type=Path, default=ROOT / "src")
    ap.add_argument("--out", type=Path, default=None)
    ap.add_argument("--luau", type=Path, default=ROOT / "build/luau_cli_0_741/luau.exe")
    ap.add_argument("--glossary", type=Path, default=GLOSSARY)
    ap.add_argument("--no-mutations", action="store_true")
    ap.add_argument("--show", type=int, default=40, help="findings printed per level (errors and warns)")
    args = ap.parse_args()
    src = args.src.resolve()
    config_path = src / CONFIG_REL
    if not config_path.is_file():
        print(f"Config not found: {config_path}", file=sys.stderr)
        return 1
    if not args.luau.is_file():
        print("Installed Luau CLI missing (build/luau_cli_0_741/luau.exe); this test never downloads tools.",
              file=sys.stderr)
        return 1
    raw = config_path.read_bytes()
    source = raw.decode("utf-8-sig").replace("\r\n", "\n")
    terms = glossary_terms(args.glossary)
    checker = Checker(src, terms)

    with tempfile.TemporaryDirectory(prefix="story_text_") as tmp:
        work = Path(tmp)
        tree, err = load_config(args.luau, source, work, "main")
        if tree is None:
            print(f"{MARK}_FAILED Config did not load: {err}")
            if args.out:
                args.out.parent.mkdir(parents=True, exist_ok=True)
                args.out.write_text(json.dumps({"status": "failed", "error": err}, indent=2) + "\n",
                                    encoding="utf-8")
            return 1
        findings = checker.run(tree, source)
        base_keys = {(f["rule"], f["path"]) for f in findings}
        mutations: list[dict] = []
        if not args.no_mutations:
            def work_one(index_mut):
                index, (name, rule, mpath, statement) = index_mut
                msrc = mutate(source, statement)
                mtree, merr = load_config(args.luau, msrc, work, f"mutant_{index:02d}")
                if mtree is None:
                    return {"mutation": name, "caught": False, "note": "mutant Config did not load: " + merr[:300]}
                new = [f for f in checker.run(mtree, msrc) if (f["rule"], f["path"]) not in base_keys]
                hit = [f for f in new if f["rule"] == rule and f["path"].startswith(fmt_path(mpath))]
                return {"mutation": name, "rule": rule, "path": fmt_path(mpath), "caught": bool(hit),
                        "newFindings": [f"{f['level']} {f['rule']} {f['path']}" for f in new][:6]}

            with ThreadPoolExecutor(max_workers=6) as pool:
                mutations = list(pool.map(work_one, enumerate(MUTATIONS)))

    after = config_path.read_bytes()
    counts = {lvl: sum(1 for f in findings if f["level"] == lvl) for lvl in ("error", "warn", "info")}
    by_rule: dict[str, dict[str, int]] = {}
    for f in findings:
        by_rule.setdefault(f["rule"], {}).setdefault(f["level"], 0)
        by_rule[f["rule"]][f["level"]] += 1
    caught = sum(1 for m in mutations if m["caught"])
    all_caught = bool(mutations) and caught == len(mutations)
    if counts["error"]:
        status = "failed"
    elif all_caught and not args.no_mutations:
        status = "passed"
    else:
        status = "passed-no-mutations"
    order = {"error": 0, "warn": 1, "info": 2}
    findings.sort(key=lambda f: (order[f["level"]], f["rule"], f["file"], f["line"] or 0))
    report = {
        "status": status,
        "src": str(src),
        "configSHA256": hashlib.sha256(raw).hexdigest(),
        "configChangedDuringRun": after != raw,
        "counts": counts,
        "byRule": by_rule,
        "glossaryTerms": len(terms),
        "formatCallSites": len(checker.callsites),
        "mutations": {"total": len(MUTATIONS), "caught": caught, "skipped": bool(args.no_mutations),
                      "results": mutations},
        "findings": findings,
        "studioCalls": 0, "apiCalls": 0,
        "limitations": (
            "Only text that exists as a value of the loaded Config is checked for checks 2-7 (plus Hangul in every "
            "src/*.luau literal). Lines written straight into client/server code (HUD, Panels, MapBuilder ...) are "
            "not checked for length, words, glossary or pronouns. Word lists are small and English-only; meaning "
            "is not understood (e.g. 'kill' about a person vs a monster is guessed from monster words on the same "
            "line, pronouns are matched per line, so a 'he' about someone else next to 'Bright' is a false warn). "
            "string.format call sites are found only for string.format(<Config path or local alias>, ...) and "
            "pcall(string.format, ...); helpers that format indirectly are not followed. The step-Text contract "
            "mirrors StoryQuestService.rowFor by hand."),
    }
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    for lvl in ("error", "warn"):
        shown = [f for f in findings if f["level"] == lvl]
        for f in shown[:args.show]:
            loc = f"{f['file']}:{f['line']}" if f["line"] else f["file"]
            print(f"{lvl.upper():5} {f['rule']:16} {f['path']}  ({loc})\n      {f['text']!r}\n      -> {f['detail']}")
        if len(shown) > args.show:
            print(f"... {len(shown) - args.show} more {lvl} findings (see --out)")
    print("BY RULE " + json.dumps(by_rule, sort_keys=True))
    for m in mutations:
        print(f"MUTATION {'caught' if m['caught'] else 'MISSED'} {m['mutation']}"
              + ("" if m["caught"] else f" :: {m.get('note') or m.get('newFindings')}"))
    if args.no_mutations:
        print("mutations skipped (--no-mutations)")
    else:
        print(f"mutations caught {caught}/{len(MUTATIONS)}")
    print(f"{MARK} errors={counts['error']} warns={counts['warn']} info={counts['info']} "
          f"Studio/API calls=0 status={status}")
    print(status)
    return 1 if counts["error"] else 0


if __name__ == "__main__":
    sys.exit(main())
