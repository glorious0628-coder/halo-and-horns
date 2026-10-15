"""Pinned quests on the HUD (퀘스트 바이블 §15 P1 ③, 최종 검수 10/15: PC = the main line + only what I pinned, at most 2,
none by default; phone = one line, my pin first; the one guide = the line I pick), offline.

Runs the CURRENT HUD.PinIndexes in the official Luau CLI (my pins' rows in pin order, a pin whose quest left is skipped)
and checks the wiring: Settings "Pins" (a List of at most 2 short keys, saved with the settings, sanitized by Config);
the quest window's Pin / Unpin on a quest row (never the main story; a third pin refuses); PC pin lines under the main
line that guide on a press; the phone's one line = my first pin. Each mutation must make a check fail.

Usage: py tools/test_quest_pins.py
"""
from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"HUD": SPS / "HUD.luau", "BOOK": SPS / "QuestBook.luau", "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau"}
LUAU = ROOT / "build/luau_cli_0_741/luau.exe"
if not LUAU.exists():
    LUAU = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"

PURE = r"""
local L, HUD = {}, {}
function L.EntryKey(e) return tostring(e.Id) .. "|" .. tostring(e.Slot) end
__FUNC__
local fails = 0
local function check(name, ok, detail)
	print((ok and "CHECK_OK " or "CHECK_FAIL ") .. name .. (ok and "" or (" :: " .. tostring(detail))))
	if not ok then fails += 1 end
end
local entries = { { Id = "story:M1", Kind = "Main" }, { Id = "Slime", Slot = 2 }, { Id = "story:S3" } }
local at = HUD.PinIndexes(entries, { "story:S3|nil", "Slime|2" })
check("my pins' rows in pin order", at[1] == 3 and at[2] == 2 and #at == 2, table.concat(at, ","))
at = HUD.PinIndexes(entries, { "gone|nil", "Slime|2" })
check("a pin whose quest left is skipped", #at == 1 and at[1] == 2)
check("no pins: nothing", #HUD.PinIndexes(entries, {}) == 0 and #HUD.PinIndexes(entries, nil) == 0)
print(fails == 0 and "PINS_PURE_OK" or "PINS_PURE_FAILED")
"""


def block(src: str, name: str) -> str:
    m = re.search(r"^function " + re.escape(name) + r"\(.*?^end\n", src, re.S | re.M)
    return m.group(0) if m else ""


def statics(s: dict) -> list[tuple[str, bool]]:
    hud, book, cfg = s["HUD"], s["BOOK"], s["CONFIG"]
    toggle = block(hud, "HUD.TogglePin")
    return [
        ("Pins: a saved List of at most 2 short keys", 'Pins = { Type = "List", Max = 2, Len = 64 },' in cfg
         and 'elseif def.Type == "List" then' in cfg and "if #list >= def.Max then break end" in cfg and "Pins = {} }" in cfg),
        ("a third pin refuses (nil), a pin twice unpins", "elseif #list >= L.PinMax then\n\t\treturn nil" in toggle
         and "table.remove(list, at)" in toggle and 'pcall(st.Set, "Pins", list)' in toggle),
        ("the quest window: Pin / Unpin on a quest row, never the main story",
         'local canPin = row.Kind == "Quest" and type(row.Entry) == "table" and row.Entry.Kind ~= "Main"' in book
         and 'hudCall("TogglePin", row.Entry)' in book and "pcall(ui.Refuse, b)" in book),
        ("PC: the pin lines under the main line, never the shown one, at most 2",
         "if i ~= shown and k < L.PinMax then" in hud and "tp[k].Label.Visible = true" in hud and "if not IS_TOUCH then\n\t\tfor i = 1, L.PinMax do" in hud),
        ("a pin line press guides there", "if e then HUD.QuestGo(e) end" in hud),
        ("phone: one line, my first pin", "if IS_TOUCH and pinAt[1] and not" in hud and "shown = pinAt[1]" in hud),
        ("a settings change redraws the lines", "C.Settings.Changed:Connect(function() if refreshQuests then pcall(refreshQuests) end end)" in hud),
        ("the words", 'Pin = "Pin", Unpin = "Unpin",' in cfg and 'QuestPinLine = "%s (%s/%s)",' in cfg),
    ]


MUTATIONS = [
    ("HUD", "three pins", "elseif #list >= L.PinMax then\n\t\treturn nil", "elseif #list >= 3 then\n\t\treturn nil"),
    ("HUD", "the shown line repeated", "if i ~= shown and k < L.PinMax then", "if k < L.PinMax then"),
    ("HUD", "the phone ignores pins", "\t\tshown = pinAt[1] -- a phone shows one line: my pin first\n", "\t\tshown = 1\n"),
    ("HUD", "a pin press does nothing", "if e then HUD.QuestGo(e) end", "local _ = e"),
    ("BOOK", "the main story pinned", 'and row.Entry.Kind ~= "Main"', ""),
    ("CONFIG", "a long list saved", "if #list >= def.Max then break end", "if #list >= 99 then break end"),
]


def run(src: dict) -> tuple[bool, list, str]:
    with tempfile.TemporaryDirectory() as d:
        f = Path(d) / "pins.luau"
        f.write_text(PURE.replace("__FUNC__", block(src["HUD"], "HUD.PinIndexes")), encoding="utf-8")
        r = subprocess.run([str(LUAU), str(f)], capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = r.stdout + r.stderr
    st = statics(src)
    return "PINS_PURE_OK" in out and all(g for _, g in st), st, out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    src = {k: p.read_text(encoding="utf-8") for k, p in FILES.items()}
    good, st, out = run(src)
    print(out.strip())
    for name, g in st:
        print(("STATIC_OK " if g else "STATIC_FAIL ") + name)
    caught = 0
    for key, name, old, new in MUTATIONS:
        if src[key].count(old) != 1:
            print(f"MUTATION NOT_APPLIED {name} (matched {src[key].count(old)})")
            continue
        m = dict(src)
        m[key] = src[key].replace(old, new)
        bad, _, _ = run(m)
        caught += 0 if bad else 1
        print(("MUTATION caught  " if not bad else "MUTATION MISSED ") + name)
    passed = good and caught == len(MUTATIONS)
    print(f"Status: {'passed' if passed else 'failed'} (statics {sum(g for _, g in st)}/{len(st)}, mutations {caught}/{len(MUTATIONS)})")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
