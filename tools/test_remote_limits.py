"""Every client -> server remote is rate-limited (게시 준비 운영 ③, 게임성 개발 2, 2026-10-15), static.

Finds every `OnServerEvent:Connect(` in src/ServerScriptService, resolves its handler (an inline function, a named function, or
the functions a wrapper call names, e.g. guard("CraftStart", onStart)), and MarketService's HANDLERS table entry by entry, then
looks for `Util.RateLimit(` in the handler and in the functions it calls (same file two levels, plus Module.Func of another
server module, e.g. GooseSquare.OnRemote). Every `Config.RateLimits.Key` a RateLimit call names must exist (no silent fallback
to a hard-coded number), and every client -> server name in Net.Names must have a server handler. No Studio, no Luau run.

Usage: py tools/test_remote_limits.py [--list] [--no-mutations]
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SSS = ROOT / "src/ServerScriptService"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
NET = ROOT / "src/ReplicatedStorage/Shared/Net.luau"
OPEN = {"function", "if", "do", "repeat"}
CLOSE = {"end", "until"}


def strip(text: str) -> str:
    """comments and string contents blanked (lengths and newlines kept)"""
    out, i, n = [], 0, len(text)
    while i < n:
        if text.startswith("--[[", i) or text.startswith("--[=[", i):
            close = "]]" if text.startswith("--[[", i) else "]=]"
            j = text.find(close, i)
            j = n if j < 0 else j + len(close)
            out.append(re.sub(r"[^\n]", " ", text[i:j]))
            i = j
        elif text.startswith("--", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
        elif text[i] in "\"'`":
            q, j = text[i], i + 1
            while j < n and text[j] != q and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
            j = min(j, n)
            out.append(q + " " * (j - i - 1) + (q if j < n else ""))
            i = j + 1
        elif text.startswith("[[", i):
            j = text.find("]]", i)
            j = n if j < 0 else j + 2
            out.append(re.sub(r"[^\n]", " ", text[i:j]))
            i = j
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


def block_end(code: str, start: int) -> int:
    """index just after the `end` closing the `function` keyword at `start` (stripped code)"""
    depth = 0
    for m in re.finditer(r"\b[A-Za-z_]\w*\b", code[start:]):
        w = m.group(0)
        if w in OPEN:
            depth += 1
        elif w in CLOSE:
            depth -= 1
            if depth == 0:
                return start + m.end()
    return len(code)


def paren_end(code: str, start: int) -> int:
    """index of the `)` closing the `(` just before `start`"""
    depth = 1
    for i in range(start, len(code)):
        if code[i] == "(":
            depth += 1
        elif code[i] == ")":
            depth -= 1
            if depth == 0:
                return i
    return len(code)


def functions(code: str) -> dict[str, tuple[int, int]]:
    """name -> (start, end): `local function n(` / `function A.n(` / `function A:n(` / `local n = function(`"""
    out: dict[str, tuple[int, int]] = {}
    for m in re.finditer(r"\b(?:local\s+)?function\s+([\w.:]+)\s*\(", code):
        name = re.split(r"[.:]", m.group(1))[-1]
        s = m.start() + m.group(0).index("function")
        out.setdefault(name, (s, block_end(code, s)))
    for m in re.finditer(r"\blocal\s+(\w+)\s*=\s*function\s*\(", code):
        s = m.start() + m.group(0).index("function")
        out.setdefault(m.group(1), (s, block_end(code, s)))
    return out


def chain(code: str, body: str, funcs: dict, depth: int = 2) -> str:
    """the body plus the bodies of same-file functions it names (depth levels)"""
    seen, texts, frontier = set(), [body], [body]
    for _ in range(depth):
        nxt = []
        for t in frontier:
            for name in set(re.findall(r"\b(\w+)\b", t)):
                if name in funcs and name not in seen:
                    seen.add(name)
                    s, e = funcs[name]
                    texts.append(code[s:e])
                    nxt.append(code[s:e])
        frontier = nxt
    return "\n".join(texts)


class Tree:
    """the server modules (stripped) — sources may be swapped for mutation runs"""

    def __init__(self, override: dict[str, str] | None = None):
        self.override = override or {}
        self.cache: dict[str, tuple[str, str, dict]] = {}

    def raw(self, path: Path) -> str:
        return self.override.get(path.name, None) or path.read_text(encoding="utf-8-sig")

    def file(self, name: str):
        if name not in self.cache:
            path = SSS / f"{name}.luau"
            raw = self.raw(path) if path.is_file() else ""
            code = strip(raw)
            self.cache[name] = (raw, code, functions(code))
        return self.cache[name]

    def deep(self, code: str, body: str, funcs: dict) -> str:
        text = chain(code, body, funcs)
        for mod, fn in set(re.findall(r"\b([A-Z]\w+)\.(\w+)\s*\(", text)):
            _, ocode, ofuncs = self.file(mod)
            if fn in ofuncs:
                s, e = ofuncs[fn]
                text += "\n" + chain(ocode, ocode[s:e], ofuncs)
        return text


def handlers(tree: Tree) -> list[dict]:
    rows = []
    for path in sorted(SSS.glob("*.luau")):
        raw, code, funcs = tree.file(path.stem)
        hm = re.search(r"\blocal\s+HANDLERS\s*=\s*\{", code)
        if hm:  # MarketService: one Connect loop over HANDLERS (name = function): each entry is its own remote
            depth, i = 1, hm.end()
            while i < len(code) and depth:
                depth += {"{": 1, "}": -1}.get(code[i], 0)
                i += 1
            for em in re.finditer(r"^\t(\w+)\s*=\s*function\s*\(", code[hm.end():i], re.M):
                s = hm.end() + em.start() + em.group(0).index("function")
                text = tree.deep(code, code[s:block_end(code, s)], funcs)
                rows.append({"file": path.name, "line": code.count("\n", 0, s) + 1, "remote": em.group(1),
                             "handler": "HANDLERS", "gate": "RateLimit(" in text})
        for m in re.finditer(r"OnServerEvent\s*:\s*Connect\s*\(", code):
            line = code.count("\n", 0, m.start()) + 1
            before = raw[max(0, m.start() - 120):m.start()]
            names = re.findall(r'Net\.Get\(\s*"(\w+)"\s*\)', before) or re.findall(r'"(\w+)"', before)
            arg = code[m.end():paren_end(code, m.end())]
            if hm and "pcall(fn" in arg:
                continue
            fm = re.match(r"\s*function\s*\(", arg)
            if fm:
                s = m.end() + arg.index("function")
                body, how = code[s:block_end(code, s)], "inline"
            else:  # a named handler, or a wrapper call such as guard("Name", onX): every same-file function it names
                found = [n for n in re.findall(r"\b(\w+)\b", arg) if n in funcs]
                body = "\n".join(code[funcs[n][0]:funcs[n][1]] for n in found)
                how = ",".join(found) or "?"
            text = tree.deep(code, body, funcs)
            rows.append({"file": path.name, "line": line, "remote": names[-1] if names else "?", "handler": how,
                         "gate": "RateLimit(" in text})
    return rows


def problems(tree: Tree) -> tuple[list[dict], list[str], int]:
    rows = handlers(tree)
    failures = [f"{r['file']}:{r['line']} {r['remote']} ({r['handler']}): no Util.RateLimit in the handler chain"
                for r in rows if not r["gate"]]
    cfg = strip(CONFIG.read_text(encoding="utf-8-sig"))
    keys = set(re.findall(r"^Config\.RateLimits\.(\w+)\s*=", cfg, re.M))
    block = re.search(r"^Config\.RateLimits\s*=\s*\{(.*?)^\}", cfg, re.M | re.S)
    if block:
        keys |= set(re.findall(r"\b(\w+)\s*=", block.group(1)))
    calls = 0
    for path in sorted(SSS.glob("*.luau")):
        src = tree.raw(path)
        for m in re.finditer(r'RateLimit\(\s*\w+\s*,\s*"(\w+)"\s*,([^\n]*)', src):
            calls += 1
            for ref in re.findall(r"Config\.RateLimits\.(\w+)", m.group(2)):
                if ref not in keys:
                    failures.append(f'{path.name}: Config.RateLimits.{ref} does not exist (RateLimit "{m.group(1)}")')
    raw_net = NET.read_text(encoding="utf-8-sig")
    c2s, section = set(), "c2s"
    for line in raw_net[raw_net.index("Net.Names"):].splitlines()[1:]:
        if line.strip().startswith("}"):
            break
        if "server -> client" in line:
            section = "s2c"
        elif "client -> server" in line:
            section = "c2s"
        if section == "c2s":
            c2s.update(re.findall(r'"(\w+)"', line.split("--")[0]))
    handled = {r["remote"] for r in rows}
    every = "\n".join(tree.raw(p) for p in SSS.glob("*.luau"))
    for name in sorted(c2s - handled):
        if f'"{name}"' not in every:
            failures.append(f"client -> server remote {name} has no server handler")
    return rows, failures, calls


MUTATIONS = [  # (file, old, new): each must make the check fail
    ("CraftService.luau", '\tif not Util.RateLimit(player, "CraftStrike", num(Config.RateLimits.CraftStrike, 0.15)) then return end\n', ""),
    ("ShopService.luau", "Util.RateLimit(", "Util.NoLimit("),
    ("ReviveService.luau", "Util.RateLimit(", "Util.NoLimit("),
    ("MarketService.luau", "if not Util.RateLimit(player, name, Config.RateLimits[name] or 1) then",
     "if false then"),
    ("GooseSquare.luau", "Util.RateLimit(", "Util.NoLimit("),
    ("QuestService.luau", '"IntroSeen", num(Config.RateLimits.IntroSeen', '"IntroSeen", num(Config.RateLimits.IntroSeenX'),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    rows, failures, calls = problems(Tree())
    if "--list" in sys.argv:
        for r in rows:
            print(f"{r['file']}:{r['line']}  {r['remote']:<20} {r['handler']:<28} {'limited' if r['gate'] else 'NO LIMIT'}")
    for f in failures:
        print("REMOTE_FAIL " + f)
    print(f"REMOTES handlers={len(rows)} limited={sum(1 for r in rows if r['gate'])} RateLimit calls={calls} "
          f"failures={len(failures)}")
    caught = 0
    if "--no-mutations" not in sys.argv:
        for fname, old, new in MUTATIONS:
            src = (SSS / fname).read_text(encoding="utf-8-sig")
            if old not in src:
                print(f"MUTATION NOT APPLIED {fname}: {old[:50]}")
                continue
            _, bad, _ = problems(Tree({fname: src.replace(old, new)}))
            hit = len(bad) > len(failures)
            caught += 1 if hit else 0
            print(("MUTATION caught  " if hit else "MUTATION MISSED ") + f"{fname}: {old[:50]}")
        print(f"MUTATIONS caught={caught}/{len(MUTATIONS)}")
    ok = not failures and ("--no-mutations" in sys.argv or caught == len(MUTATIONS))
    print(f"REMOTES {'passed' if ok else 'failed'}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
