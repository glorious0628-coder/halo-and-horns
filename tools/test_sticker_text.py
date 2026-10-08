"""Pain sticker words on a blank bubble art (이미지 개발 10/08: the new EmoOuch art is an empty bubble; its words come from
Config.UIArt.Parts.EmoOuch.TextRect = { x, y, w, h }, fractions of the picture, like BarkBubble).

Extracts Feel.textRect from the CURRENT src/StarterPlayer/StarterPlayerScripts/Fx.luau and runs it with the installed
official Luau CLI (build/luau_cli_0_741) against a UIKit double: no TextRect -> nil; a square picture -> the box as given;
a wide / tall picture shown with Fit in the sticker's square -> the box moved into the picture's band. Static: in
Feel.sticker an art with a TextRect shows EMO_FALLBACK's words in that box (and fades them), an art without one hides
them, and the code-drawn fallback puts the words back in the middle. Mutations: in-memory copies with one rule broken
each; each must make a check fail. Status "passed" only when the checks pass AND every mutation was applied and caught.
Report: docs/art/verification_2026-10-08/offline_sticker_text_2026-10-08.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
FX = ROOT / "src/StarterPlayer/StarterPlayerScripts/Fx.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-08/offline_sticker_text_2026-10-08.json"

FIXTURE = r"""
local checks, failed = 0, 0
local function check(name, ok, detail)
	checks += 1
	if not ok then failed += 1; print(("CHECK_FAIL %s :: %s"):format(name, tostring(detail or ""))) end
end
local function v2(x, y) return { X = x, Y = y, __kind = "Vector2" } end
local PARTS = {
	EmoOuch = { Id = "rbxassetid://1", Size = v2(512, 512), TextRect = { 0.1, 0.2, 0.8, 0.4 } },
	EmoWide = { Id = "rbxassetid://2", Size = v2(512, 256), TextRect = { 0.1, 0.2, 0.8, 0.5 } },
	EmoTall = { Id = "rbxassetid://3", Size = v2(256, 512), TextRect = { 0, 0, 1, 0.5 } },
	EmoPlain = { Id = "rbxassetid://4", Size = v2(512, 512) },
	EmoBad = { Id = "rbxassetid://5", Size = v2(512, 512), TextRect = { 0.1, "x", 0.8, 0.4 } },
}
local C = { UIKit = { ArtPart = function(name) return PARTS[name] end } }
local Feel = {}
local typeof = function(v) return type(v) == "table" and rawget(v, "__kind") or type(v) end
FEEL_SOURCE
local function near(a, b) return math.abs(a - b) < 1e-6 end
local function same(r, want) return r ~= nil and near(r[1], want[1]) and near(r[2], want[2]) and near(r[3], want[3]) and near(r[4], want[4]) end
local function show(r) return r and string.format("%.3f %.3f %.3f %.3f", r[1], r[2], r[3], r[4]) or "nil" end
check("a square art: the box as given", same(Feel.textRect("EmoOuch"), { 0.1, 0.2, 0.8, 0.4 }), show(Feel.textRect("EmoOuch")))
-- 2:1 picture with Fit in a square: it fills the width, 0.5 of the height, from y 0.25
check("a wide art: the box moves into the picture's band", same(Feel.textRect("EmoWide"), { 0.1, 0.25 + 0.2 * 0.5, 0.8, 0.5 * 0.5 }),
	show(Feel.textRect("EmoWide")))
check("a tall art: the box moves into the picture's column", same(Feel.textRect("EmoTall"), { 0.25, 0, 0.5, 0.5 }), show(Feel.textRect("EmoTall")))
check("an art without a TextRect: nil (its own words, or none)", Feel.textRect("EmoPlain") == nil, show(Feel.textRect("EmoPlain")))
check("a broken TextRect: nil", Feel.textRect("EmoBad") == nil, show(Feel.textRect("EmoBad")))
check("an unknown art: nil", Feel.textRect("Nope") == nil, "")
print(("STICKER_TEXT_SUMMARY checks=%d failed=%d"):format(checks, failed))
"""

MUTATIONS = [
    ("the picture's shape ignored", "\tif aspect >= 1 then h = 1 / aspect else w = aspect end\n", ""),
    ("the box not moved into the band", "\treturn { ox + r[1] * w, oy + r[2] * h, r[3] * w, r[4] * h }\n",
     "\treturn { r[1] * w, r[2] * h, r[3] * w, r[4] * h }\n"),
    ("a broken TextRect still used",
     'if type(r) ~= "table" or type(r[1]) ~= "number" or type(r[2]) ~= "number" or type(r[3]) ~= "number" or type(r[4]) ~= "number" then',
     'if type(r) ~= "table" then'),
]
STATIC_MUTATIONS = [
    ("the words hidden on a TextRect art", "\t\te.Text.Visible = words ~= nil\n", "\t\te.Text.Visible = false\n"),
    ("the fallback words left where a TextRect put them",
     "\t\te.Text.Position = UDim2.fromScale(0.5, 0.5) -- a TextRect sticker may have moved it\n", ""),
    ("the TextRect words never fade",
     "\t\t\ttween(e.Text, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, fadeAt)\n\t\tend\n",
     "\t\tend\n"),
]


def lua_body(src: str) -> str:
    m = re.search(r"\nfunction Feel\.textRect\(name\)\n.*?\nend\n", src, re.S)
    return m[0] if m else ""


def run(src: str, name: str):
    body = lua_body(src)
    path = ROOT / f"build/sticker_text_offline{name}.luau"
    path.write_text(FIXTURE.replace("FEEL_SOURCE", body), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"STICKER_TEXT_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = bool(body) and result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def sticker_static(src: str):
    m = re.search(r"\nfunction Feel\.sticker\(.*?\nend\n", src, re.S)
    body = m[0] if m else ""
    return [
        ("an art with a TextRect shows EMO_FALLBACK's words in that box",
         "local rect = Feel.textRect(emo)" in body and "local words = rect and MOTION.EMO_FALLBACK[emo]" in body
         and "\t\te.Text.Visible = words ~= nil\n" in body
         and "e.Text.Position = UDim2.fromScale(rect[1] + rect[3] / 2, rect[2] + rect[4] / 2)" in body),
        ("the TextRect words fade with the art",
         "\t\t\ttween(e.Text, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Linear, "
         "Enum.EasingDirection.In, fadeAt)\n\t\tend\n" in body),
        ("the code fallback puts the words back in the middle",
         "\t\te.Text.Position = UDim2.fromScale(0.5, 0.5) -- a TextRect sticker may have moved it\n" in body),
    ]


def main():
    src = FX.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(src, "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    static = sticker_static(src)
    for name, good in static:
        print(("STATIC_OK " if good else "STATIC_FAILURE ") + name)
    rows = []
    for name, old, new in MUTATIONS:
        applied = src.count(old) == 1
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run(src.replace(old, new), "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    for name, old, new in STATIC_MUTATIONS:
        applied = src.count(old) == 1
        caught = applied and not all(g for _, g in sticker_static(src.replace(old, new)))
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": []})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    passed = ok and all(g for _, g in static) and all(r["applied"] and r["caught"] for r in rows)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "static": [{"check": n, "ok": g} for n, g in static],
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {FX.relative_to(ROOT).as_posix(): hashlib.sha256(FX.read_bytes()).hexdigest()},
              "studioCalls": 0,
              "limitations": "The extracted function and the sticker code's text only: the look on the real blank bubble "
                             "art is a Studio photo once 이미지 개발 sends its id and TextRect."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")


if __name__ == "__main__":
    main()
