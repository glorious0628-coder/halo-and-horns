"""Small screen batch (최종 검수 10/14, gameplay plan 2-C #9), offline.

1. Cutscene skip: nothing new - the opening already has Skip (Intro, Enter too), the craft ring has [Skip]; there is no
   faction-change scene and the enhance result is instant (checked statically below).
2. Outlaw chip (A23-23): the HUD danger chip after Bully, shown while the attribute Outlaw is true, with the ranking's
   own line Config.Ranking.Text.OutlawChip; the chip row redraws on Outlaw.
3. 28-day name frame (A23-77, Config.Attendance.Milestones { Days = 28, Border = "Days28" }): NameTagPrefs.BorderOf(days)
   = the highest Border milestone reached; the approved ribbon Config.UIArt "Ribbon" .. Border right of the name on every
   player's tag (a 1 s sweep, AttendDays). There is no frame art yet: the ribbon is the mark.
4. Win card (A23-79 #3): Invite.GooseWin(Fx GooseEnd, my faction, my position) and Invite.WarWin(old round end, now,
   WarBlessing, my faction, WarMode) decide; Invite.WinCard(source) = approved PanelCard + BtnSecondary [Invite a friend]
   (Invite.Prompt(source), Invite.Seen(source)) for Config.WinCard.Seconds, only while Invite.CanShow().
5. Crown Pit (A23-90, ART_DIRECTION 2.4): MiniMap.PitOf(zone) = its PvPArea; the minimap and the world map draw it in the
   extreme colour; MiniMap.PitPosts(area, step) = the edge points; this client puts thin red posts on the ground there.
Extracted and run: the pure functions with doubles. Static: the call sites. Mutations: each must make a check fail.
Report: docs/art/verification_2026-10-14/offline_small_ui_2026-10-14.json (do not commit)
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"HUD": SPS / "HUD.luau", "MINI": SPS / "MiniMap.luau", "WORLD": SPS / "WorldMap.luau", "TAGS": SPS / "NameTagPrefs.luau",
         "INV": SPS / "Invite.luau", "CFG": ROOT / "src/ReplicatedStorage/Shared/Config.luau", "INTRO": SPS / "Intro.luau",
         "CRAFT": SPS / "CraftView.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-14/offline_small_ui_2026-10-14.json"
CUTS = {
    "PIT": ("MINI", "function MiniMap.PitOf(z)", "\n-- the posts in the world"),
    "BORDER": ("TAGS", "function NameTagPrefs.BorderOf(days)", "\n-- one tag's ribbon"),
    "WIN": ("INV", "-- (pure) the goose game's end", "\n-- the win card: the win line"),
}

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local V3 = {}
V3.__index = V3
V3.__sub = function(a, b) return V3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
function V3.new(x, y, z)
	local v = setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
	v.Magnitude = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	return v
end
local function typeofD(v)
	if getmetatable(v) == V3 then return "Vector3" end
	return type(v)
end
local Config = {
	Attendance = { Milestones = { { Days = 7, Title = "Regular" }, { Days = 14 }, { Days = 28, Border = "Days28" },
		{ Days = 50, Title = "SuperRegular" }, { Days = 60, Border = "Days60" } } },
	WinCard = { Seconds = 8, GooseRange = 120 },
}
local function load(src, env)
	local f = assert(loadstring(src, "=Part"))
	setfenv(f, setmetatable(env, { __index = getfenv() }))
	f()
end
local MiniMap, NameTagPrefs, Invite = {}, {}, {}
load(PIT, { MiniMap = MiniMap, typeof = typeofD, Vector3 = V3 })
load(BORDER, { NameTagPrefs = NameTagPrefs, Config = Config })
load(WIN, { Invite = Invite, Config = Config, typeof = typeofD, T = { Card = { RoundGrace = 3 } } })

-- 5. the Crown Pit
local ruins = { PvPArea = { Name = "Crown Pit", Center = V3.new(1660, 0, 0), Size = V3.new(200, 0, 240) } }
local pit = MiniMap.PitOf(ruins)
check(pit and pit.Center.X == 1660 and pit.Size.Z == 240, "a zone's PvPArea is its pit")
check(MiniMap.PitOf({}) == nil and MiniMap.PitOf({ PvPArea = { Center = 1, Size = V3.new(1, 0, 1) } }) == nil
	and MiniMap.PitOf({ PvPArea = { Center = V3.new(0, 0, 0), Size = V3.new(0, 0, 10) } }) == nil and MiniMap.PitOf(nil) == nil,
	"no / odd / flat area: no pit")
local posts = MiniMap.PitPosts(pit, 12)
local minX, maxX, minZ, maxZ, onEdge = math.huge, -math.huge, math.huge, -math.huge, true
local seen = {}
local dup = false
for _, p in posts do
	minX, maxX = math.min(minX, p[1]), math.max(maxX, p[1])
	minZ, maxZ = math.min(minZ, p[2]), math.max(maxZ, p[2])
	local onX = math.abs(p[1] - 1560) < 1e-6 or math.abs(p[1] - 1760) < 1e-6
	local onZ = math.abs(p[2] + 120) < 1e-6 or math.abs(p[2] - 120) < 1e-6
	if not (onX or onZ) then onEdge = false end
	local key = p[1] .. ":" .. p[2]
	if seen[key] then dup = true end
	seen[key] = true
end
check(#posts == 2 * math.ceil(200 / 12) + 2 * math.ceil(240 / 12), "a post every 12 studs around (the corners once)", #posts)
check(onEdge and minX == 1560 and maxX < 1760 + 1e-6 and minZ == -120 and maxZ <= 120 and not dup,
	"every post on the edge, all four sides, no post twice", string.format("%s %s %s %s", minX, maxX, minZ, maxZ))
check(seen["1560:-120"] and seen["1760:-120"] and seen["1760:120"] and seen["1560:120"], "all four corners")
check(#MiniMap.PitPosts(nil, 12) == 0 and #MiniMap.PitPosts(pit, 1) == #MiniMap.PitPosts(pit, 4), "no area: none; a step under 4 = 4")

-- 3. the 28-day border
check(NameTagPrefs.BorderOf(27) == nil and NameTagPrefs.BorderOf(28) == "Days28" and NameTagPrefs.BorderOf(55) == "Days28"
	and NameTagPrefs.BorderOf(60) == "Days60" and NameTagPrefs.BorderOf(nil) == nil and NameTagPrefs.BorderOf("x") == nil,
	"the highest border milestone reached (titles do not count)")

-- 4. the win card's triggers
local here = V3.new(10, 0, 10)
check(Invite.GooseWin({ Winner = "Halo", Pos = V3.new(0, 0, 0) }, "Halo", here) == "GooseWin", "my side won the goose, near: GooseWin")
check(Invite.GooseWin({ Winner = "Horns", Pos = V3.new(0, 0, 0) }, "Halo", here) == nil, "the other side won: nothing")
check(Invite.GooseWin({ Winner = "Tie", Pos = V3.new(0, 0, 0) }, "Halo", here) == nil, "a tie: nothing")
check(Invite.GooseWin({ Winner = "Halo", Pos = V3.new(500, 0, 0) }, "Halo", here) == nil, "far from the goose: nothing")
check(Invite.GooseWin({ Winner = "Neutral", Pos = V3.new(0, 0, 0) }, "Neutral", here) == nil
	and Invite.GooseWin({ Winner = "Halo" }, "Halo", here) == nil and Invite.GooseWin(nil, "Halo", here) == nil,
	"artisans / no position / no data: nothing")
check(Invite.WarWin(1000, 1000.5, "Horns", "Horns", "Normal") == "WarWin", "a round ended with my side's crown: WarWin")
check(Invite.WarWin(1000, 1000.5, "Halo", "Horns", "Normal") == nil, "the other side's crown: nothing")
check(Invite.WarWin(1600, 1000, "Horns", "Horns", "Normal") == nil, "the end moved while still in the future (switch off): nothing")
check(Invite.WarWin(1000, 1000.5, "Horns", "Horns", "Idle") == nil, "an idle round (nobody fought): nothing")
check(Invite.WarWin(nil, 1000, "Horns", "Horns", "Normal") == nil and Invite.WarWin(0, 1000, "Horns", "Horns", "Normal") == nil,
	"no old end (the first value): nothing")
print(("SMALL_UI_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("HUD", "no outlaw chip in the row", '"Bully", "Outlaw", "Wanted"', '"Bully", "Wanted"'),
    ("HUD", "the outlaw chip never shows", 'setChip(ui.chip.Outlaw, attr("Outlaw", false) == true and', 'setChip(ui.chip.Outlaw, false and'),
    ("HUD", "no redraw on Outlaw", '"KaijuState", "Faction", "Outlaw" }, refreshChips)', '"KaijuState", "Faction" }, refreshChips)'),
    ("MINI", "the pit has no area check", "if a.Size.X < 1 or a.Size.Z < 1 then return nil end\n", ""),
    ("MINI", "posts skip a side", "\tside(x0, z1, x0, z0)\n", ""),
    ("MINI", "a corner twice", "for i = 0, n - 1 do", "for i = 0, n do"),
    ("MINI", "the pit not on the minimap", 'Name = "Pit_" .. z.Id,\n\t\t\t\tBackgroundColor3 = COL.Extreme,', 'Name = "Pit_" .. z.Id,\n\t\t\t\tBackgroundColor3 = COL.Safe,'),
    ("MINI", "no posts in the world", "local ok, missing = pcall(MiniMap.BuildPitEdges)", "local ok, missing = true, 0"),
    ("WORLD", "the pit not on the world map", "\t\tlocal a = z.Pit\n\t\tif a then\n\t\t\trect(", "\t\tlocal a = nil\n\t\tif a then\n\t\t\trect("),
    ("TAGS", "a title milestone counts as a border", 'if d and type(m.Border) == "string" and d <= days', "if d and d <= days"),
    ("TAGS", "the lowest border wins", "and d > bestDays then best, bestDays = m.Border, d end", "and bestDays < 0 then best, bestDays = m.Border, d end"),
    ("TAGS", "the border one day early", "d <= days and d > bestDays", "d <= days + 1 and d > bestDays"),
    ("TAGS", "no sweep", "local ok, err = pcall(NameTagPrefs.FitBorders)", "local ok, err = true, nil"),
    ("INV", "the other side's goose win", "or data.Winner ~= faction then return nil end", "then return nil end"),
    ("INV", "the goose from anywhere", "if (data.Pos - myPos).Magnitude > (tonumber(cfg.GooseRange) or 120) then return nil end\n", ""),
    ("INV", "the switch-off push counts", "or oldEndsAt > now + T.Card.RoundGrace then return nil end", "then return nil end"),
    ("INV", "an idle round counts", "or blessing ~= faction or mode == \"Idle\" then", "or blessing ~= faction then"),
    ("INV", "the war never shows the card", "if source then pcall(Invite.WinCard, source) end", ""),
    ("INV", "the goose never shows the card", "if source then Invite.WinCard(source) end", ""),
    ("INV", "the card near a KO / the Shop", "\tif not Invite.CanShow() then return nil end\n\tif S.Card", "\tif S.Card"),
    ("INV", "the button prompts without its source", "task.spawn(Invite.Prompt, source)", "task.spawn(Invite.Prompt)"),
    ("INV", "the card not counted", "\tInvite.Seen(source)\n\ttask.delay", "\ttask.delay"),
    ("CFG", "the win card text gone", 'GooseWin = "You won the goose game!"', 'GooseWinX = "You won the goose game!"'),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def cut(text: str, start: str, end: str) -> str:
    a = text.find(start)
    if a < 0:
        return ""
    b = text.find(end, a)
    return text[a:b] if b >= 0 else ""


def statics(src: dict) -> list[tuple[str, bool]]:
    h, mini, world, tags, inv, cfg = src["HUD"], src["MINI"], src["WORLD"], src["TAGS"], src["INV"], src["CFG"]
    return [
        ("1. the opening has Skip (button + Enter) and the craft ring [Skip]; nothing else long",
         "Intro.SkipText" in src["INTRO"] and "HHC_IntroSkip" in src["INTRO"] and "Skip = \"Skip\"" in src["CRAFT"]),
        ("2. HUD: the Outlaw chip after Bully with the ranking's own line, redrawn on Outlaw",
         '"Bully", "Outlaw", "Wanted"' in h and 'setChip(ui.chip.Outlaw, attr("Outlaw", false) == true and type(rk.OutlawChip) == "string", rk.OutlawChip, Theme.Bad)' in h
         and '"KaijuState", "Faction", "Outlaw" }, refreshChips)' in h and re.search(r'OutlawChip = "Outlaw:', cfg) is not None),
        ("3. the ribbon art of the 28-day border is approved (Config.UIArt RibbonDays28) and swept onto every tag",
         re.search(r"RibbonDays28 = \{ Id = \"rbxassetid://\d+\"", cfg) is not None and '{ Days = 28, Border = "Days28" }' in cfg
         and "local ok, err = pcall(NameTagPrefs.FitBorders)" in tags and 'Art = "Ribbon"' in tags),
        ("4. the win card: approved PanelCard + BtnSecondary, Config.WinCard words, Seen / Prompt with its source",
         'k.ArtFrame("PanelCard"' in inv and 'k.ArtTextButton("BtnSecondary"' in inv and "Invite.Seen(source)" in inv
         and "task.spawn(Invite.Prompt, source)" in inv and "Config.WinCard = { Seconds = 8" in cfg
         and 'gs:GetAttributeChangedSignal("WarRoundEndsAt")' in inv and 'if kind == "GooseEnd" then' in inv
         and "if source then pcall(Invite.WinCard, source) end" in inv and "if source then Invite.WinCard(source) end" in inv
         and "\tif not Invite.CanShow() then return nil end\n\tif S.Card" in inv and "\tInvite.Seen(source)\n\ttask.delay" in inv
         and re.search(r'Text = \{ GooseWin = "[^"]+", WarWin = "[^"]+", Invite = "Invite a friend" \}', cfg) is not None),
        ("5. the Crown Pit on both maps in the extreme colour + the posts",
         'Name = "Pit_" .. z.Id,\n\t\t\t\tBackgroundColor3 = COL.Extreme,' in mini and "Pit = MiniMap.PitOf(z)," in mini
         and "\t\tlocal a = z.Pit\n\t\tif a then\n\t\t\trect(" in world and "stroke(COL.Extreme, 2.5, 0.05)" in world
         and "local ok, missing = pcall(MiniMap.BuildPitEdges)" in mini),
    ]


def run(src: dict) -> tuple[int, int, str]:
    head = "".join(f"local {k} = " + lua_str(cut(src[f], a, b)) + "\n" for k, (f, a, b) in CUTS.items())
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "small_ui.luau"
        p.write_text(head + FIXTURE, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"SMALL_UI_SUMMARY checks=(\d+) failed=(\d+)", out)
    st = statics(src)
    out += "".join(("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + n for n, ok in st)
    return (int(m[1]) if m else 0) + len(st), (int(m[2]) if m else 1) + sum(1 for _, ok in st if not ok), out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    found = all(cut(src[f], a, b) for f, a, b in CUTS.values())
    checks, failed, out = run(src)
    print(out.strip())
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
    ok = found and failed == 0 and checks > 5 and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Extracted")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
