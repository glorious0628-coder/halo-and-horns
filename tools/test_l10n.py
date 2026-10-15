"""한국어 모드 L10n 중심 (게임성 개발 1, 2026-10-11; SPEC A23-111, contract docs/design/l10n_contract_2026-10-11.md
v4.1 §2-§6, §9 items 1 / 2 / 4 / 6 / 9), offline.

Runs, in the official Luau CLI, the CURRENT Config.luau, L10n.luau, TextKo.luau and Net.luau in
tools/fixtures/l10n_offline.luau (RunService Studio / client switch, Players.LocalPlayer attributes, a recording Notify
remote, require by name, a small fixture TextKo). Checks: keys, TextKo (ko + current En only), §9-1 / §9-2 / §9-4 audit
(real TextKo clean, fixture defects listed), Format rules 1-5, josa, Named, Msg (nested, Who/Hon, Hidden, Join),
LangOf, the Studio pseudo-locale, Net.NotifyKey / NotifyAllKey. Static: UIKit.Lang / LangChanged / Tx / Notify listener.
Mutations: each must be caught.

Usage: py tools/test_l10n.py
Report: docs/art/verification_2026-10-11/offline_l10n_2026-10-11.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = {"CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
         "L10N": ROOT / "src/ReplicatedStorage/Shared/L10n.luau",
         "TEXTKO": ROOT / "src/ReplicatedStorage/Shared/TextKo.luau",
         "NET": ROOT / "src/ReplicatedStorage/Shared/Net.luau",
         "UIKIT": ROOT / "src/StarterPlayer/StarterPlayerScripts/UIKit.luau"}
FIXTURE = ROOT / "tools/fixtures/l10n_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-11/offline_l10n_2026-10-11.json"

MUTATIONS = [
    ("L10N", "ko first missing", "\tif lang == \"ko\" then\n\t\tlocal e = textKo()[key]", "\tif false then\n\t\tlocal e = textKo()[key]"),
    ("L10N", "a stale translation passes", "e.Ko ~= \"\" and e.En == en then return e.Ko", "e.Ko ~= \"\" then return e.Ko"),
    ("L10N", "no leaf .. En fallback", "\tif v == nil then v = node[part .. \"En\"] end\n", ""),
    ("L10N", "array indexes ignored", "\t\tif n ~= nil then v = node[n] end\n", ""),
    ("L10N", "Args = {} formats", "local hasArgs = type(args) == \"table\" and #args > 0",
     "local hasArgs = type(args) == \"table\" and #args >= 0"),
    ("L10N", "Plural missing", "\tif english then out = Config.Plural(out) end\n", ""),
    ("L10N", "Plural on Korean templates", "\tif english then out = Config.Plural(out) end\n", "\tout = Config.Plural(out)\n"),
    ("L10N", "no English fallback", "\tif not english then\n\t\tok, out = pcall(fill, pseudo(en)",
     "\tif false then\n\t\tok, out = pcall(fill, pseudo(en)"),
    ("L10N", "double failure shows raw English",
     "\t\tif ok and type(out) == \"string\" then return out end\n\tend\n\treturn pseudo(key)\nend",
     "\t\tif ok and type(out) == \"string\" then return out end\n\tend\n\treturn pseudo(en or key)\nend"),
    ("L10N", "josa ignores the final consonant", "\treturn jong ~= 0 and entry[1] or entry[2]", "\treturn entry[1]"),
    ("L10N", "(으)로 without the ㄹ rule", "(jong == 0 or jong == 8)", "(jong == 0)"),
    ("L10N", "non-Hangul gets one form", "last > 0xD7A3 then return entry[3] end", "last > 0xD7A3 then return entry[2] end"),
    ("L10N", "{n} out of order", "\t\t\tv = vals[n]\n", "\t\t\tv = vals[#vals + 1 - n]\n"),
    ("L10N", "missing slot not empty", "\t\tif v == nil then return \"\" end\n\t\treturn string.format",
     "\t\tif v == nil then return \"?\" end\n\t\treturn string.format"),
    ("L10N", "%% not collapsed", "if conv == \"%\" then return \"%\" end", "if conv == \"%\" then return \"%%\" end"),
    ("L10N", "% in a slot value", "\t\tif escape then s = string.gsub(s, \"%%\", \"%%%%\") end\n", ""),
    ("L10N", "Hidden ignores the faction", "\t\tif id ~= \"None\" and type(f) == \"table\" then", "\t\tif false then"),
    ("L10N", "Join separator", "return table.concat(parts, L10n.Get(S.JoinKey, lang))", "return table.concat(parts, \", \")"),
    ("L10N", "Named ignored", "\t\t\tv = nvals[name]\n", "\t\t\tv = nil\n"),
    ("L10N", "Hon dropped", "(v.Hon == true and L10n.Get(S.HonorificKey, lang) or \"\")", "\"\""),
    ("L10N", "pseudo outside Studio", "\tif not S.Studio or s == \"\" then return s end", "\tif s == \"\" then return s end"),
    ("L10N", "LangOf ignores the locale", "string.lower(string.sub(loc, 1, 2)) == \"ko\"", "false"),
    ("L10N", "LangOf ignores the attribute", "if ok and (lang == \"ko\" or lang == \"en\") then return lang end", ""),
    ("NET", "NotifyKey sends no English copy", "Text = L10n.Msg({ Key = key, Args = args, Named = named }, \"en\") }", "Text = key }"),
    ("NET", "Studio lets an unknown key through", "\tif RunService:IsStudio() and (type(key)", "\tif false and (type(key)"),
    ("UIKIT", "the Notify listener ignores Key", "\t\t\tif payload.Key ~= nil then\n", "\t\t\tif false then\n"),
    ("UIKIT", "UIKit.Lang stays English", "\treturn UIKit.L10n.LangOf(LocalPlayer)\n", "\treturn \"en\"\n"),
    ("UIKIT", "Tx never uses L10n", "\t\tlocal path = UIKit.L10n.PathOf(t)\n", "\t\tlocal path = nil\n"),
    ("UIKIT", "LangChanged never fires", "\tme:GetAttributeChangedSignal(\"Lang\"):Connect(langCheck)\n", ""),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def fn_block(src: str, head: str) -> str:
    at = src.find(head)
    if at < 0:
        return ""
    end = src.find("\nend\n", at)
    return src[at:end + 5] if end >= 0 else src[at:]


def static(src: dict) -> list[tuple[str, bool]]:
    ui, net = src["UIKIT"], src["NET"]
    listener = ui[ui.find('local remote = Net.Get("Notify")'):]
    lang = fn_block(ui, "function UIKit.Lang()")
    tx = fn_block(ui, "function UIKit.Tx(t, key, ...)")
    return [
        ("UIKit keeps L10n in a field", 'UIKit.L10n = require(Shared:WaitForChild("L10n"))' in ui and "\nlocal L10n" not in ui),
        ("UIKit.LangChanged is a Util Signal", "UIKit.LangChanged = Util.Signal.new()" in ui),
        ("UIKit.Lang uses L10n.LangOf", "UIKit.L10n.LangOf(LocalPlayer)" in lang),
        # 최종 검수 10/14: with arguments a registered key goes through UIKit.Tr (the table by key; English = L10n.T)
        ("UIKit.Tx: registered tables go by key through UIKit.Tr (publish5: pieces without arguments too; falls back to L10n.T)",
         "UIKit.L10n.PathOf(t)" in tx
         and 'return UIKit.Tr(path .. "." .. key, ...) -- 10/14: by key (translated), with or without arguments' in tx
         and 'return UIKit.L10n.T(key, n > 0 and { ... } or nil, UIKit.Lang())' in ui),
        ("UIKit.Tx keeps the old path", 'local s = t[key .. "En"] or t[key]' in tx),
        ("LangChanged fires on the Lang attribute",
         'me:GetAttributeChangedSignal("Lang"):Connect(langCheck)' in ui and "UIKit.LangChanged:Fire(lang)" in ui),
        ("the Notify listener uses L10n.Msg when payload.Key",
         re.search(r"if payload\.Key ~= nil then\n\t+-- [^\n]*\n\t+local ok, s = pcall\(UIKit\.L10n\.Msg, payload, UIKit\.Lang\(\)\)",
                   listener) is not None and listener.find("payload.Key") < listener.find("UIKit.Toast(text")),
        # A23-191 (최종 검수 10/15): Notify / NotifyAll go through the gate (Net.NotifyText: only "bad" keeps its text)
        ("Net.Notify / NotifyAll through the A23-191 gate",
         "Net.Get(\"Notify\"):FireClient(player, { Text = t, Kind = kind, Duration = duration, Sound = sound })" in net
         and "Net.Get(\"Notify\"):FireAllClients({ Text = t, Kind = kind, Duration = duration, Sound = sound })" in net
         and net.count("local t = Net.NotifyText(text, kind, sound)") == 2),
        ("Net requires L10n lazily", "\nlocal L10n" not in net and 'require(script.Parent:WaitForChild("L10n"))' in net),
        ("L10n requires only Config (TextKo lazily)", set(re.findall(r'WaitForChild\("(\w+)"', src["L10N"])) == {"Config", "TextKo"}),
        ("TextKo.luau is the empty table", src["TEXTKO"].rstrip().endswith("return {}") and "tools/l10n_apply.py" in src["TEXTKO"]),
        ("no LocaleId in Config", "LocaleId" not in src["CONFIG"]),
    ]


def run(src: dict) -> tuple[int, int, str]:
    text = ("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal L10N_SOURCE = " + lua_str(src["L10N"])
            + "\nlocal TEXTKO_SOURCE = " + lua_str(src["TEXTKO"]) + "\nlocal NET_SOURCE = " + lua_str(src["NET"]) + "\n"
            + FIXTURE.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "l10n.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"L10N_SUMMARY checks=(\d+) failed=(\d+)", out)
    failed = int(m[2]) if m else 1
    st = static(src)
    for name, ok in st:
        out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + name
        failed += 0 if ok else 1
    return (int(m[1]) if m else 0) + len(st), failed, out


def compile_check() -> tuple[bool, str]:
    compiler = BINARY.with_name("luau-compile.exe")
    if not compiler.exists():
        return False, "luau-compile.exe missing"
    paths = [str(FILES[k]) for k in ("L10N", "TEXTKO", "NET", "UIKIT", "CONFIG")] + [str(FIXTURE)]
    proc = subprocess.run([str(compiler), *paths], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True,
                          encoding="utf-8", errors="replace", timeout=120)
    return proc.returncode == 0, proc.stderr.strip()


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    compiled, cerr = compile_check()
    print("COMPILE_OK" if compiled else "COMPILE_FAIL " + cerr)
    checks, failed, out = run(src)
    checks += 1
    failed += 0 if compiled else 1
    print(out.strip())
    stale = re.search(r"^STALE_REAL (.*)$", out, re.M)
    muts = []
    for key, name, old, new in MUTATIONS:
        hits = src[key].count(old)
        caught = False
        if hits == 1:
            m = dict(src)
            m[key] = src[key].replace(old, new)
            caught = run(m)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    status = "passed" if failed == 0 and checks > 0 and all(m["caught"] for m in muts) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "compiled": compiled, "mutations": muts,
                               "staleRealTextKo": stale[1].split(", ") if stale and stale[1].strip() else [],
                               "status": status, "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0},
                              indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
