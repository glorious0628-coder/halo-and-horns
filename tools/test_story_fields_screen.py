"""A23-208 story fields - the screen part (게임성 개발 1; contract docs/design/quest_data_contract_2026-10-15.md §3-2,
server = 개발 2 dev2-story-fields).

Runs, in the official Luau CLI (build/luau_cli_0_741), the CURRENT pure parts cut out of the sources with a small quest
fixture: StoryNpcs.StepFor (my side's table over the step), StoryNpcs.SceneNpc (who plays a Scene: the step whose Scene
it is, else the last step's Npc, else the asker), StoryNpcs.AskerOf (the next asker: Offer.Npc by side, else the first
step's Npc), Panels STORY.WithNext (the last card ends with Next.Line; other steps and the step's own list untouched)
and STORY.Before (Offer.Before, a side table = mine, else All).
Static: Fx StoryScene Find / Scene reach StoryNpcs.Find / PlayScene; the Find bubble = the approved BarkBubble over the
step's NPC head (else its Guide / Obj.Spot place), 4 s, 18 px words in its text box, never a toast; a Scene only plays a
Config.StoryQuests.SceneKeys key, moves the NPC on this client and sparkles round; the Offer window's first line is the
italic Before (18 px) over her talk; the Story card shows WithNext's lines and, after a hook, asks StoryNpcs.ExpectNext;
StoryNpcs.Refresh hops the asker once when her "!" shows. Mutations: in-memory copies with one rule broken each; each
must be caught.

Usage: py tools/test_story_fields_screen.py
Report: docs/art/verification_2026-10-15/offline_story_fields_screen_2026-10-15.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CLIENT = ROOT / "src/StarterPlayer/StarterPlayerScripts"
NPCS = CLIENT / "StoryNpcs.luau"
PANELS = CLIENT / "Panels.luau"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-15/offline_story_fields_screen_2026-10-15.json"

NPC_FNS = ["StepFor", "SceneNpc", "AskerOf", "StepEnds", "EndLines", "SpeakerOf"]
PANEL_FNS = ["WithNext", "Before"]

FIXTURE = r'''
local checks, failed = 0, 0
local function check(name, ok, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local DEFS = {
	Q = { Offer = { Npc = { Halo = "Gleam", Horns = "Smokey", Neutral = "Otto" }, Before = "The cart wobbles.",
			Lines = { All = { "Gleam: Help?" } } },
		Steps = {
			{ Guide = "HaloBridge", Find = "A sock!", Obj = { Type = "Near", Spot = "HaloBridge" },
				Horns = { Find = "A stolen sock!", Guide = "HornsBridge" } },
			{ Npc = "Otto", Scene = "Nod", Obj = { Type = "Deliver" } },
			{ Npc = "Bright", Panel = true, Lines = { All = { "Bright: Thanks!", "Bright: Bye!" } }, Scene = "Wave",
				Obj = { Type = "Talk" } },
		},
		Next = { Id = "R", Line = "Bright: Oh! My ribbon..." } },
	R = { Steps = { { Npc = "Tiny", Obj = { Type = "Talk" } } } }, -- no Offer: the first step's Npc asks
	S = { Speaker = "Rose", Steps = { { Guide = "Pond", Obj = { Type = "Near" } } } }, -- nobody at a step
	B = { Offer = { Npc = "Bright", Before = { Halo = "Halo side line", Horns = "Horns side line" }, Lines = {} },
		Steps = { { Npc = "Bright", Obj = { Type = "Talk" } } } },
	-- 10/15: a hook per side (a pack's Variants[id].Next) and a situation line by my own results (BeforeBy)
	V = { Offer = { Npc = "Bright", Before = "Plain line", BeforeBy = { Flag = "Lamp", Mine = "You lit your own lamp.",
			Default = "First time here." }, Lines = {} },
		Steps = { { Npc = "Bright", Obj = { Type = "Talk" }, Lines = { All = { "Bright: Hi." } } } },
		Next = { Halo = { Id = "R", Line = "Bright: Halo next" }, Horns = { Id = "S", Line = "Smokey: Horns next" } } },
}
-- ch1 data (개발 2 10/15): a non-card step with closing words (Deliver) and a last non-card step (Learn) + a hook
DEFS.D = { Steps = {
		{ Guide = "Meadow", Obj = { Type = "Kill" } },
		{ Npc = "Folk1", Obj = { Type = "Deliver" }, Lines = { Halo = { "Neighbor: Wait! I need a free hand to wave!" },
			Horns = { "Tiny: Ha! The snack is mine." } } },
		{ Npc = "Gleam", Obj = { Type = "Learn" }, Lines = { All = { "Sir Gleam: They'll wave when they see you now." } } },
	},
	Next = { Halo = { Id = "R", Line = "Sir Gleam: Bright wants that dust." } } }
local env = { StoryNpcs = {}, STORY = {}, Config = { StoryQuests = { Defs = DEFS, Speakers = { Tiny = "Tiny", Gleam = "Sir Gleam" } } } }
setmetatable(env, { __index = getfenv() })
for _, src in SOURCES do
	local f = assert(loadstring(src, "=cut"))
	setfenv(f, env)
	f()
end
local N, ST = env.StoryNpcs, env.STORY
local s1 = N.StepFor("Q", 1, "Halo")
check("StepFor: the base step for a side without its table", s1 and s1.Find == "A sock!" and s1.Guide == "HaloBridge")
local h1 = N.StepFor("Q", 1, "Horns")
check("StepFor: my side's table over the base fields", h1 and h1.Find == "A stolen sock!" and h1.Guide == "HornsBridge"
	and h1.Obj and h1.Obj.Type == "Near")
check("StepFor: the base step itself is not changed", DEFS.Q.Steps[1].Find == "A sock!")
check("StepFor: a step number as text (the Fx Value)", (N.StepFor("Q", "2", "Halo") or {}).Npc == "Otto")
check("StepFor: no quest / no step = nil", N.StepFor("Nope", 1, "Halo") == nil and N.StepFor("Q", 9, "Halo") == nil)
check("SceneNpc: the step whose Scene it is", N.SceneNpc("Q", "Nod", "Halo") == "Otto")
check("SceneNpc: the last step's Scene", N.SceneNpc("Q", "Wave", "Halo") == "Bright")
check("SceneNpc: an unknown scene -> the last step's Npc", N.SceneNpc("Q", "Spin", "Halo") == "Bright")
check("SceneNpc: no step Npc -> the Speaker", N.SceneNpc("S", "Hop", "Halo") == "Rose")
check("AskerOf: Offer.Npc by side", N.AskerOf("Q", "Horns") == "Smokey" and N.AskerOf("Q", "Neutral") == "Otto")
check("AskerOf: no Offer -> the first step's Npc", N.AskerOf("R", "Halo") == "Tiny")
check("AskerOf: no quest = nil", N.AskerOf("Nope", "Halo") == nil)
local own = DEFS.Q.Steps[3].Lines.All
local last = ST.WithNext(own, DEFS.Q, 3, "Halo")
check("WithNext: the last card ends with Next.Line", #last == 3 and last[3] == "Bright: Oh! My ribbon...", #last)
check("WithNext: the step's own lines untouched", #own == 2)
check("WithNext: not on an earlier step", #ST.WithNext(own, DEFS.Q, 2, "Halo") == 2)
check("WithNext: a step number as text", #ST.WithNext(own, DEFS.Q, "3", "Halo") == 3)
check("WithNext: no Next = the same lines", ST.WithNext(own, DEFS.R, 1, "Halo") == own)
local vl = DEFS.V.Steps[1].Lines.All
check("WithNext: my side's hook (Config.QuestNext)", ST.WithNext(vl, DEFS.V, 1, "Horns")[2] == "Smokey: Horns next"
	and ST.WithNext(vl, DEFS.V, 1, "Halo")[2] == "Bright: Halo next")
check("WithNext: a side without a hook = no line", #ST.WithNext(vl, DEFS.V, 1, "Neutral") == 1)
check("Before: the plain line", ST.Before(DEFS.Q, "Halo", "") == "The cart wobbles.")
check("Before: a side table = mine", ST.Before(DEFS.B, "Halo", "") == "Halo side line" and ST.Before(DEFS.B, "Horns", nil) == "Horns side line")
check("Before: BeforeBy by my own flag (StoryFlags text)", ST.Before(DEFS.V, "Halo", "Crown=Paper,Lamp=Mine") == "You lit your own lamp.")
check("Before: BeforeBy without the flag = its Default", ST.Before(DEFS.V, "Halo", "Crown=Paper") == "First time here.")
check("Before: none = nil", ST.Before(DEFS.R, "Halo", "") == nil)
local function count(id) return #(DEFS[id] and DEFS[id].Steps or {}) end
local function keys(list) local o = {} for _, e in list do table.insert(o, e.Id .. ":" .. e.St) end return table.concat(o, ",") end
check("StepEnds: the first pass only remembers", #N.StepEnds(nil, { D = { St = 2 } }, count) == 0)
check("StepEnds: a step moved on = that step ended", keys(N.StepEnds({ D = { St = 2 } }, { D = { St = 3 } }, count)) == "D:2")
check("StepEnds: two steps at once = both", keys(N.StepEnds({ D = { St = 1 } }, { D = { St = 3 } }, count)) == "D:1,D:2")
check("StepEnds: waits for [Claim] = the rest to the last ended", keys(N.StepEnds({ D = { St = 3 } }, { D = { St = 3, Done = true } }, count)) == "D:3")
check("StepEnds: left the list after its last step = it ended", keys(N.StepEnds({ D = { St = 3 } }, {}, count)) == "D:3")
check("StepEnds: left the list mid-way = nothing", #N.StepEnds({ D = { St = 2 } }, {}, count) == 0)
check("StepEnds: already done = nothing again", #N.StepEnds({ D = { St = 3, Done = true } }, { D = { St = 3, Done = true } }, count) == 0)
local l2 = N.EndLines("D", 2, "Halo")
check("EndLines: a non-card step's words for my side", #l2 == 1 and l2[1] == "Neighbor: Wait! I need a free hand to wave!")
check("EndLines: the other side's words", N.EndLines("D", 2, "Horns")[1] == "Tiny: Ha! The snack is mine.")
local l3, nx = N.EndLines("D", 3, "Halo")
check("EndLines: the last step + the hook (my side)", #l3 == 2 and l3[2] == "Sir Gleam: Bright wants that dust." and nx and nx.Id == "R")
check("EndLines: a side without a hook = the words only", #N.EndLines("D", 3, "Horns") == 1)
check("EndLines: a card step says nothing here (its card does)", #N.EndLines("Q", 3, "Halo") == 0)
local who, words = N.SpeakerOf("Sir Gleam: They'll wave.", "Folk1")
check("SpeakerOf: the speaker's name -> that NPC, words without the name", who == "Gleam" and words == "They'll wave.")
who, words = N.SpeakerOf("Neighbor: Wait!", "Folk1")
check("SpeakerOf: an unknown name -> the step's Npc", who == "Folk1" and words == "Wait!")
who, words = N.SpeakerOf("Neighbor: Wait!", nil)
check("SpeakerOf: no NPC (On = Self) -> me, the whole line", who == nil and words == "Neighbor: Wait!")
print(("STORY_SCREEN_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

STATIC = [
    ("NPCS", "Fx StoryScene Find / Scene (with the Fx St) reach StoryNpcs.Find / PlayScene", [
        '\telseif key == "Find" then -- A23-208', "\t\treturn StoryNpcs.Find(data.Id, data.St or value, me and me:GetAttribute(\"Faction\"))\n",
        "\t\treturn StoryNpcs.PlayScene(data.Id, value, me and me:GetAttribute(\"Faction\"), data.St)\n"]),
    ("NPCS", "On = \"Self\": the bubble over my head, the Scene on my avatar (emote / jump / sparkle)", [
        "\tif step.On == \"Self\" then -- 10/15: my own words, over my head\n",
        "\tlocal mine = type(step) == \"table\" and step.On == \"Self\"\n",
        "\t\t\tpcall(StoryNpcs.PlayEmote, T.Story.SelfEmote[scene])\n"]),
    ("NPCS", "Find bubble: 4 s, 18 px, the approved BarkBubble at its aspect, its text box", [
        "\tFind = { Seconds = 4, W = 280, Aspect = 512 / 190, TextPx = 18,",
        '\t\tframe = UIKit.ArtFrame("BarkBubble", { Name = "Bubble", Size = UDim2.fromScale(1, 1) },',
        "\tif type(art) == \"table\" and type(art.TextRect) == \"table\" and #art.TextRect == 4 then rect = art.TextRect end\n",
        "\ttask.delay(tonumber(seconds) or F.Seconds, function()\n"]),
    ("NPCS", "Find: over the step NPC's head, else its Guide / Obj.Spot place", [
        "\tif head and head:IsA(\"BasePart\") then return StoryNpcs.Bubble(head, text) ~= nil end\n",
        "\tfor _, key in { step.Guide, obj.Spot } do\n"]),
    ("NPCS", "Scene: SceneKeys only, the NPC moves (client) + a round sparkle", [
        "\tif type(scene) ~= \"string\" or not (type(SK) == \"table\" and SK[scene]) then return false end\n",
        "\t\t\t\tm:PivotTo(home * StoryNpcs.MoveOffset(scene, (os.clock() - t0) / M.Time))\n",
        "\tburst(head and head.Position + Vector3.new(0, 1.5, 0) or home.Position, T.Gold, scene == \"Sparkle\" and 26 or 16)\n"]),
    ("NPCS", "every SceneKeys key has a move", ["\t\tHop = {", "\t\tCheer = {", "\t\tClap = {", "\t\tLaugh = {", "\t\tBow = {",
        "\t\tNod = {", "\t\tHug = {", "\t\tWave = {", "\t\tSpin = {", "\t\tSparkle = {"]),
    ("NPCS", "Refresh: the next asker hops once when her \"!\" shows", [
        "\t\telseif nx and called[nx.Npc] and StoryNpcs.Body(nx.Npc) then\n\t\t\tS.Next = nil\n\t\t\tStoryNpcs.Hop(nx.Npc, 1)\n"]),
    ("PANELS", "Offer window: the italic Before line (18 px) before her talk", [
        "\tlocal before = STORY.Before(def, myFaction(), attr(\"StoryFlags\", \"\"))\n",
        '\t\tlocal b = addText(parent, before, { Name = "OfferBefore", Size = 18, Color = theme.SubText })\n',
        "\t\tb.FontFace = Font.new(face.Family, face.Weight, Enum.FontStyle.Italic)\n"]),
    ("PANELS", "Story card: WithNext's lines; after a hook StoryNpcs.ExpectNext", [
        "\tlocal lines = STORY.WithNext(STORY.Lines(step, f, arg.Var), def, arg.St, f)",
        "\t\t\tpcall(npcs.ExpectNext, nx.Id)\n"]),
    ("NPCS", "Refresh: ended non-card steps speak (one bubble after another, Talk.Seconds)", [
        "\t\tif type(entries) == \"table\" and #entries > 0 then pcall(StoryNpcs.WatchSteps, entries, me:GetAttribute(\"Faction\")) end\n",
        "\t\t\tif head and head:IsA(\"BasePart\") then pcall(StoryNpcs.Bubble, head, words, T.Story.Talk.Seconds) end\n",
        "\t\tif nx and type(nx.Id) == \"string\" then pcall(StoryNpcs.ExpectNext, nx.Id) end\n"]),
    ("CONFIG", "the SceneKeys list (dev2)", ["Config.StoryQuests.SceneKeys = { Wave = true, Hop = true, Laugh = true, Bow = true, Cheer = true, Nod = true, Sparkle = true,"]),
]
MUTATIONS = [
    ("NPCS", "my side's table ignored", "\tif type(over) ~= \"table\" then return step, def end\n", "\tif true then return step, def end\n"),
    ("NPCS", "a Scene by the first step", "\tfor i = n, 1, -1 do\n", "\tfor i = 1, n do\n"),
    ("NPCS", "the asker ignores Offer.Npc", "\tif type(who) == \"string\" and who ~= \"\" then return who end\n", ""),
    ("PANELS", "the hook on every step", "or tonumber(st) ~= n or n == 0 then return lines end", "or n == 0 then return lines end"),
    ("PANELS", "the hook written into the step's own lines", "\tlocal out = table.clone(lines)\n\ttable.insert(out, nx.Line)\n",
     "\tlocal out = lines\n\ttable.insert(out, nx.Line)\n"),
    ("PANELS", "Before ignores my flags", "and Config.QuestBefore(def, f, flags) or nil", "and Config.QuestBefore(def, f, {}) or nil"),
    ("PANELS", "the hook ignores my side", "Config.QuestNext(def, f) or nil\n\tlocal n =", "Config.QuestNext(def, \"Halo\") or nil\n\tlocal n ="),
    ("NPCS", "On = Self ignored by the Scene", "\tlocal mine = type(step) == \"table\" and step.On == \"Self\"\n", "\tlocal mine = false\n"),
    ("NPCS", "the bubble stays forever", "\ttask.delay(tonumber(seconds) or F.Seconds, function()\n", "\ttask.delay(math.huge or F.Seconds, function()\n"),
    ("NPCS", "any scene word plays", "\tif type(scene) ~= \"string\" or not (type(SK) == \"table\" and SK[scene]) then return false end\n",
     "\tif type(scene) ~= \"string\" then return false end\n"),
    ("NPCS", "the next asker never hops", "\t\t\tStoryNpcs.Hop(nx.Npc, 1)\n", ""),
    ("NPCS", "a card step speaks twice", "\tif type(step) ~= \"table\" or step.Panel == true then return {}, nil end\n",
     "\tif type(step) ~= \"table\" then return {}, nil end\n"),
    ("NPCS", "a quest leaving mid-way speaks", "elseif n == nil and not p.Done and from >= last and last > 0 then",
     "elseif n == nil and not p.Done then"),
    ("NPCS", "the speaker's name kept over the speaker", "if shown == name then return id, words end", "if shown == name then return id, line end"),
    ("PANELS", "no Before line", '\t\tlocal b = addText(parent, before, { Name = "OfferBefore", Size = 18, Color = theme.SubText })\n',
     '\t\tlocal b = Instance.new("TextLabel")\n'),
]


def cut(src: str, table: str, name: str) -> str:
    m = re.search(r"\nfunction " + table + r"\." + name + r"\(.*?\nend\n", src, re.S)
    return m[0] if m else ""


def run(files: dict[str, str]) -> tuple[int, int, str]:
    srcs = ([cut(files["NPCS"], "StoryNpcs", n) for n in NPC_FNS] + [cut(files["PANELS"], "STORY", n) for n in PANEL_FNS]
            + [cut(files["CONFIG"], "Config", n) for n in ("QuestNext", "QuestBefore")])
    failed = sum(1 for s in srcs if not s)
    lua = "local SOURCES = {\n" + "".join(f"[==========[{s}]==========],\n" for s in srcs if s) + "}\n" + FIXTURE
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "story_screen.luau"
        p.write_text(lua, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
    out = proc.stdout + proc.stderr
    mm = re.search(r"STORY_SCREEN_SUMMARY checks=(\d+) failed=(\d+)", out)
    failed += int(mm[2]) if mm else 1
    for fk, name, needles in STATIC:
        ok = all(files[fk].count(n) == 1 for n in needles)
        out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + name
        failed += 0 if ok else 1
    return (int(mm[1]) if mm else 0) + len(STATIC), failed, out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    files = {"NPCS": NPCS.read_text(encoding="utf-8"), "PANELS": PANELS.read_text(encoding="utf-8"),
             "CONFIG": CONFIG.read_text(encoding="utf-8")}
    checks, failed, out = run(files)
    print(out.strip())
    muts = []
    for fk, name, old, new in MUTATIONS:
        hits = files[fk].count(old)
        caught = False
        if hits == 1:
            copy = dict(files)
            copy[fk] = files[fk].replace(old, new)
            caught = run(copy)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    status = "passed" if failed == 0 and checks > 0 and all(m["caught"] for m in muts) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
