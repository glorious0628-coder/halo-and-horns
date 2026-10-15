"""NPC head marks (퀘스트 바이블 §15 P1 ②, 10/15), offline.

Runs the CURRENT StoryNpcs.Marks in the official Luau CLI on small Config doubles: a step through an NPC = "!"; her step
that finishes the quest (its last step, or a Deliver) = "?"; "?" wins over "!"; the main story's mark is Main (gold +
star: told apart by shape, not colour alone); a request (StoryOffers) = side "!"; a skill waiting at the teacher = main
"!". Static: the drawn mark follows it (sign, gold/white, star only for main). Each mutation must make a check fail.

Usage: py tools/test_npc_marks.py
"""
from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
NPC = ROOT / "src/StarterPlayer/StarterPlayerScripts/StoryNpcs.luau"
LUAU = ROOT / "build/luau_cli_0_741/luau.exe"
if not LUAU.exists():
    LUAU = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"

PURE = r"""
local Color3 = { fromRGB = function(r, g, b) return { r, g, b } end }
local Vector2 = { new = function() return {} end }
local T = { MarkText = "!", Done = "?" }
local Config = { StoryQuests = { Defs = {
	A = { Steps = { { Npc = "Bright" }, { Npc = "Bright" } } },
	B = { Steps = { { Npc = "Tiny", Obj = { Type = "Deliver" } }, { Obj = { Type = "Kill" } } } },
	C = { Steps = { { Npc = "Otto" }, { Obj = { Type = "Kill" } }, { Npc = "Otto" } } },
} } }
local StoryNpcs = {}
__FUNC__
local fails = 0
local function check(name, ok, detail)
	print((ok and "CHECK_OK " or "CHECK_FAIL ") .. name .. (ok and "" or (" :: " .. tostring(detail))))
	if not ok then fails += 1 end
end
local function row(id, st, npc, kind) return { Kind = kind or "Sub", Story = { Id = id, St = st, Npc = npc } } end
local m = StoryNpcs.Marks({ row("C", 1, "Otto") }, {}, nil)
check("a step through her = !", m.Otto.Text == "!" and m.Otto.Main == false, m.Otto and m.Otto.Text)
m = StoryNpcs.Marks({ row("C", 3, "Otto") }, {}, nil)
check("her step that ends the quest = ?", m.Otto.Text == "?")
m = StoryNpcs.Marks({ row("B", 1, "Tiny") }, {}, nil)
check("a Deliver to her = ?", m.Tiny.Text == "?")
m = StoryNpcs.Marks({ row("C", 1, "Otto"), row("C", 3, "Otto") }, {}, nil)
check("? wins over !", m.Otto.Text == "?")
m = StoryNpcs.Marks({ row("C", 3, "Otto"), row("C", 1, "Otto") }, {}, nil)
check("? stays when a ! row comes after", m.Otto.Text == "?")
m = StoryNpcs.Marks({ row("A", 1, "Bright", "Main") }, {}, nil)
check("the main story's mark is Main", m.Bright.Main == true and m.Bright.Text == "!")
m = StoryNpcs.Marks({}, { Tiny = true }, nil)
check("a request = side !", m.Tiny.Text == "!" and m.Tiny.Main == false)
m = StoryNpcs.Marks({}, {}, "Gleam")
check("a skill at the teacher = main !", m.Gleam.Main == true and m.Gleam.Text == "!")
m = StoryNpcs.Marks({ { Kind = "Daily" }, row("A", 1, "") }, {}, nil)
check("rows without an NPC: no mark", next(m) == nil)
print(fails == 0 and "MARKS_PURE_OK" or "MARKS_PURE_FAILED")
"""


def block(src: str, name: str) -> str:
    m = re.search(r"^function " + re.escape(name) + r"\(.*?^end\n", src, re.S | re.M)
    return m.group(0) if m else ""


def run(src: str) -> tuple[bool, str]:
    fn = block(src, "StoryNpcs.Marks")
    if not fn:
        return False, "Marks missing"
    with tempfile.TemporaryDirectory() as d:
        f = Path(d) / "m.luau"
        f.write_text(PURE.replace("__FUNC__", fn), encoding="utf-8")
        r = subprocess.run([str(LUAU), str(f)], capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = r.stdout + r.stderr
    paint = block(src, "StoryNpcs.Paint")
    statics = [
        ("the drawn mark follows it: sign, gold for main / white, the star only for main",
         "if label.Text ~= mark.Text then label.Text = mark.Text end" in paint and "local col = mark.Main and T.Gold or T.White" in paint
         and "if star then star.Visible = mark.Main == true end" in paint),
        ("the star is approved art, behind the sign", "ui.ArtImage(T.StarArt, { Name = \"Star\"," in src and "label.ZIndex = 2" in src),
        ("every shown mark is painted", "if on then StoryNpcs.Paint(bb, marks[id] or { Text = T.MarkText, Main = false }) end" in src),
    ]
    for name, ok in statics:
        out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + name
    return "MARKS_PURE_OK" in out and all(ok for _, ok in statics), out


MUTATIONS = [
    ("never ?", "\t\tif done then m.Text = T.Done end\n", ""),
    ("! wins back over ?", "\t\tif done then m.Text = T.Done end\n", "\t\tm.Text = done and T.Done or T.MarkText\n"),
    ("Deliver not a hand-in", ' or (type(obj) == "table" and obj.Type == "Deliver")', ""),
    ("main not told", 'put(st.Npc, done, e.Kind == "Main")', "put(st.Npc, done, false)"),
    ("a request is main", "for id in type(offers) == \"table\" and offers or {} do put(id, false, false) end",
     "for id in type(offers) == \"table\" and offers or {} do put(id, false, true) end"),
    ("the star on side marks too", "if star then star.Visible = mark.Main == true end", "if star then star.Visible = true end"),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    src = NPC.read_text(encoding="utf-8")
    good, out = run(src)
    print(out.strip())
    caught = 0
    for name, old, new in MUTATIONS:
        if src.count(old) != 1:
            print(f"MUTATION NOT_APPLIED {name} (matched {src.count(old)})")
            continue
        bad, _ = run(src.replace(old, new))
        caught += 0 if bad else 1
        print(("MUTATION caught  " if not bad else "MUTATION MISSED ") + name)
    passed = good and caught == len(MUTATIONS)
    print(f"Status: {'passed' if passed else 'failed'} (mutations {caught}/{len(MUTATIONS)})")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
