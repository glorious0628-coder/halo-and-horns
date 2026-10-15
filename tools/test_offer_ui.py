"""Quest requests and pick-ups on screen (A23-199, server contract docs/design/quest_offer_server_2026-10-15.md), offline.

Runs the CURRENT StoryNpcs.Offers and Panels STORY.OfferView in the official Luau CLI on small Config doubles:
the attribute StoryOffers ("Tiny,Bright") -> the NPCs with a request; her name from Config.StoryQuests.Speakers and
my side's lines (else All). Static: those NPCs get the "!" and their Talk prompt; the Offer window pages her lines like
a story talk and ends with [Sure!] / [Not now] -> StoryAction(Id, "Accept" / "Decline"); its title is "Name · Title";
an open Pickup step (my side's override first) puts a box with a soft light, round sparkles and a "Pick up" prompt at
its Landmarks spot, only while that step is open, and the prompt sends StoryAction(Id, "Pickup"). Each mutation must
make a check fail.

Usage: py tools/test_offer_ui.py
"""
from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"NPC": SPS / "StoryNpcs.luau", "PANELS": SPS / "Panels.luau", "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau"}
LUAU = ROOT / "build/luau_cli_0_741/luau.exe"
if not LUAU.exists():
    LUAU = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"

PURE = r"""
local Config = { StoryQuests = { Speakers = { Tiny = "Tiny", Bright = "Bright" } } }
local StoryNpcs, STORY = {}, {}
__FUNCS__
local fails = 0
local function check(name, ok, detail)
	print((ok and "CHECK_OK " or "CHECK_FAIL ") .. name .. (ok and "" or (" :: " .. tostring(detail))))
	if not ok then fails += 1 end
end
local o = StoryNpcs.Offers("Bright,Tiny")
check("StoryOffers 'Bright,Tiny' -> both", o.Bright == true and o.Tiny == true)
check("'' and nil -> nobody", next(StoryNpcs.Offers("")) == nil and next(StoryNpcs.Offers(nil)) == nil)
check("spaces are no id", next(StoryNpcs.Offers(" , ")) == nil)
local def = { Title = "Lost Lunch", Offer = { Npc = "Tiny", Lines = { All = { "Help me?" }, Halo = { "Knight, help me?" } } } }
local v = STORY.OfferView(def, nil, "Halo")
check("her name and my side's lines", v.Name == "Tiny" and v.Lines[1] == "Knight, help me?" and v.Title == "Lost Lunch", v.Name)
v = STORY.OfferView(def, nil, "Horns")
check("no lines for my side -> All", v.Lines[1] == "Help me?")
v = STORY.OfferView(def, "Bright", "Horns")
check("the payload's Npc first", v.Npc == "Bright" and v.Name == "Bright")
v = STORY.OfferView({ Offer = { Npc = "Nobody" } }, nil, "Halo")
check("an unknown speaker: her id, no lines, never an error", v.Name == "Nobody" and #v.Lines == 0)
print(fails == 0 and "OFFER_PURE_OK" or "OFFER_PURE_FAILED")
"""


def block(src: str, name: str) -> str:
    m = re.search(r"^function " + re.escape(name) + r"\(.*?^end\n", src, re.S | re.M)
    return m.group(0) if m else ""


def statics(s: dict) -> list[tuple[str, bool]]:
    npc, pan, cfg = s["NPC"], s["PANELS"], s["CONFIG"]
    offer = pan[pan.find("BUILDERS.Offer = function(parent)"):]
    offer = offer[:offer.find("\nend\n")]
    pick = block(npc, "StoryNpcs.Pickups")
    return [
        ("an NPC with a request gets the '!' and her Talk prompt",
         'for id in StoryNpcs.Offers(me:GetAttribute("StoryOffers")) do called[id] = true end' in npc),
        ("the Offer window: her lines page by page, [Sure!] / [Not now] on the last page",
         'TYPE.Show(typing, line, tostring(v.Lines[page] or ""), v.Npc, page)' in offer
         and "TXT.OfferAccept" in offer and "TXT.OfferDecline" in offer and "\t\tfor _, b in { yes, no } do\n\t\t\tb.Visible = last()" in offer),
        ("Accept / Decline go to the server", 'answer("Accept")' in offer and 'answer("Decline")' in offer
         and 'fire("StoryAction", arg.Id, what)' in offer),
        ("its title is 'Name · Title' and its icon the story one", 'if currentId == "Offer" then titleLabel.Text = STORY.OfferTitle() end' in pan
         and 'Offer = "IconNews"' in pan),
        ("the words are in Config", 'OfferAccept = "Sure!", OfferDecline = "Not now", Pickup = "Pick up",' in cfg),
        ("a Pickup step: my side's override first, the Landmarks spot",
         'obj.Type == "Pickup"' in pick and "type(over) == \"table\" and type(over.Obj) == \"table\" and over.Obj" in pick
         and "marks[obj.Spot]" in pick),
        ("boxes follow the open steps (a closed step's box goes)", "if not want[id] then m:Destroy() else want[id] = nil end" in npc
         and "pcall(StoryNpcs.DrawPickups, StoryNpcs.Pickups(entries, me:GetAttribute(\"Faction\")))" in npc),
        ("the box: light, round sparkles, a Pick up prompt", 'Instance.new("PointLight")' in npc and 'spark.Name = "Sparkle"' in npc
         and 'prompt:SetAttribute("StoryPickup", p.Id)' in npc),
        ("the prompt sends StoryAction(Id, 'Pickup')", 'remote:FireServer(id, "Pickup")' in npc
         and "if not StoryNpcs.OnPickup(prompt) then StoryNpcs.OnPrompt(prompt) end" in npc),
    ]


MUTATIONS = [
    ("NPC", "requests get no '!'", '\t\tfor id in StoryNpcs.Offers(me:GetAttribute("StoryOffers")) do called[id] = true end\n', ""),
    ("NPC", "a space is an id", '"[^,%s]+"', '"[^,]+"'),
    ("NPC", "a closed step keeps its box", "if not want[id] then m:Destroy() else want[id] = nil end", "want[id] = nil"),
    ("NPC", "the override ignored", "(type(over) == \"table\" and type(over.Obj) == \"table\" and over.Obj) or step.Obj", "step.Obj"),
    ("NPC", "the pickup never sent", 'if ok and remote then remote:FireServer(id, "Pickup") end', ""),
    ("PANELS", "accept never sent", 'if last() then answer("Accept") end', ""),
    ("PANELS", "the buttons from the first page", "\t\tfor _, b in { yes, no } do\n\t\t\tb.Visible = last()", "\t\tfor _, b in { yes, no } do\n\t\t\tb.Visible = true"),
    ("PANELS", "All before my side", "(type(src[f]) == \"table\" and src[f]) or (type(src.All) == \"table\" and src.All) or {}",
     "(type(src.All) == \"table\" and src.All) or {}"),
    ("PANELS", "the payload's Npc ignored", "local who = (type(npc) == \"string\" and npc ~= \"\") and npc or offer.Npc", "local who = offer.Npc"),
]


def run(src: dict) -> tuple[bool, list, str]:
    funcs = block(src["NPC"], "StoryNpcs.Offers") + block(src["PANELS"], "STORY.OfferView")
    with tempfile.TemporaryDirectory() as d:
        f = Path(d) / "offer.luau"
        f.write_text(PURE.replace("__FUNCS__", funcs), encoding="utf-8")
        r = subprocess.run([str(LUAU), str(f)], capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = r.stdout + r.stderr
    st = statics(src)
    return "OFFER_PURE_OK" in out and all(g for _, g in st), st, out


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
