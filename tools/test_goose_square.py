"""A23-141 the Goose Square (게임성 개발 2, 2026-10-12), offline.

docs/design/goose_square_contract_2026-10-12.md (§6 = the server) and docs/design/goose_square_skeleton_2026-10-12.md:
GooseSquare.luau's space (the place's workspace.GooseSquare model: <Mark>Pos attributes or parts, the Floor = the area;
none -> the plain stand-in built once at Config.Goose.SquareSpace.Center + Offsets), Join gates (GooseActive, ready, a
side, alive, not the kaiju, no grudge sack, no PvP hit within FightSeconds), the remote GooseSquare("Join" | "Leave")
(one string argument, RateLimits.GooseSquare, a refusal = game dev 1's Config.Goose.Square.Text line or nothing), auto
combat paused (the attribute) and restored from the save, every leave path (the eggs back first, moved back only when
alive and not going elsewhere), the way back (the Join spot unless PvP / under the kill height / inside / its zone gone ->
the own town start), ReturnAll, the tick (falls, far moves, GooseJoinBlock on a change, BlockEvery) and Inside. Runs the
CURRENT Config, Util and GooseSquare with the installed official Luau CLI (GooseSquare.World replaced by doubles).
Static checks read the wiring the offline run cannot reach (GooseService, GooseEggs' geometry, PvP / Zone / Player /
Skill / Combat / CharacterVisuals / MapBuilder / StoryQuest / Health / Net). Mutations run on in-memory copies only.

Usage: py tools/test_goose_square.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-12/offline_dev2_goose_square_2026-10-12.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "SQUARE_SOURCE": SSS / "GooseSquare.luau",
}
C, Q = "CONFIG_SOURCE", "SQUARE_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    # --- the space
    ("space: built every time", Q, "\tlocal m = W.Model()\n\tif not m or not W.HasFloor(m) then\n", "\tlocal m = nil\n\tif not m then\n"),
    ("space: a floorless model kept as it is", Q, "\tif not m or not W.HasFloor(m) then\n", "\tif not m then\n"),
    ("space: a see-through floor counts", Q, "if d:IsA(\"BasePart\") and d.CanCollide and d.Transparency < 1 then", "if d:IsA(\"BasePart\") then"),
    ("join: a gone square not rebuilt", Q, "\tif not W.HasFloor(W.Model()) then GooseSquare.Ensure() end", "\tlocal _ = 0"),
    ("space: the model's attributes ignored", Q, "\tif typeof(a) == \"Vector3\" then return a end\n", ""),
    ("space: no offset for a missing mark", Q, "\t\tif typeof(s[name]) ~= \"Vector3\" then s[name] = c + off end\n", ""),
    ("space: the Floor is not the area", Q, "\t\ts.AreaCF, s.AreaSize = floor.CFrame, floor.Size\n", ""),
    ("config: the nest south", C, "Nest = Vector3.new(0, 0, -37), Cart = Vector3.new(0, 0, 37),", "Nest = Vector3.new(0, 0, 37), Cart = Vector3.new(0, 0, -37),"),
    ("config: back after 10 s", C, "\tReturnAfter = 4,", "\tReturnAfter = 10,"),
    ("config: no rate limit value", C, "Config.RateLimits.GooseSquare = 1 --", "Config.RateLimits.GooseSquare = 0 --"),
    # --- Inside
    ("inside: no margin", Q, "return math.abs(rel.X) <= s.AreaSize.X / 2 + SP.Margin and math.abs(rel.Z) <= s.AreaSize.Z / 2 + SP.Margin",
     "return math.abs(rel.X) <= s.AreaSize.X / 2 and math.abs(rel.Z) <= s.AreaSize.Z / 2"),
    ("inside: no fall rule", Q, "\t\tand rel.Y >= top - SP.FallBelow\n", "\n"),
    # --- Join
    ("join: open with no goose", Q, "\tif not (H.IsActive and H.IsActive()) then return false, \"Closed\" end\n", ""),
    ("join: twice", Q, "\tif Q.In[p] or not W.Ready(p) then return false, nil end\n", "\tif not W.Ready(p) then return false, nil end\n"),
    ("join: no side joins", Q, "\tif f ~= \"Halo\" and f ~= \"Horns\" and f ~= \"Neutral\" then return false, nil end\n", ""),
    ("join: artisans refused", Q, "\tif f ~= \"Halo\" and f ~= \"Horns\" and f ~= \"Neutral\" then return false, nil end\n",
     "\tif f ~= \"Halo\" and f ~= \"Horns\" then return false, nil end\n"),
    ("join: the dead join", Q, "\tif not W.Alive(p) then return \"Dead\" end\n", ""),
    ("join: the kaiju joins", Q, "\tif W.KaijuState(p) ~= \"None\" then return \"Monster\" end\n", ""),
    ("join: a queued / siren kaiju joins", Q, "\tif W.KaijuState(p) ~= \"None\" then return \"Monster\" end\n",
     "\tif W.KaijuState(p) == \"Active\" then return \"Monster\" end\n"),
    ("join: wanted stars ignored", Q, "if W.InCombat(p) or W.Stars(p) >= Config.PvP.NoTravelStars then return \"PvP\" end",
     "if W.InCombat(p) then return \"PvP\" end"),
    ("way back: a wanted player goes home", Q, "\tif W.Stars(p) >= Config.PvP.NoTravelStars then\n\t\treturn typeof(cf) == \"CFrame\" and cf or W.CrossroadsCF()\n\tend\n", ""),
    ("tick: an Active kaiju stays inside", Q, "\t\telseif W.KaijuState(p) == \"Active\" then\n\t\t\ttable.insert(out, { p, \"Moved\" })\n", ""),
    ("tick: no safety net", Q, "\t\t\tGooseSquare.ReturnAll(\"End\")\n", ""),
    ("tick: the safety net at once", Q, "if W.Clock() - Q.IdleSince > SP.ReturnAfter + 3 then", "if true then"),
    ("join: a sack joins", Q, "\tif W.Sack(p) then return \"Grudge\" end\n", ""),
    ("join: fights ignored", Q, "if W.InCombat(p) or W.Stars(p) >= Config.PvP.NoTravelStars then return \"PvP\" end",
     "if W.Stars(p) >= Config.PvP.NoTravelStars then return \"PvP\" end"),
    ("join: Horns land at the Halo spawn", Q, "(f == \"Horns\" and s.SpawnHorns)", "(f == \"Horns\" and s.SpawnHalo)"),
    ("join: no attribute", Q, "\tQ.In[p] = true\n\tQ.Joins += 1\n\tW.SetAttr(p, attrIn(), true)\n", "\tQ.In[p] = true\n\tQ.Joins += 1\n"),
    ("join: not moved", Q, "\tW.Pivot(p, spawnFor(p))\n\treturn true, nil\n", "\treturn true, nil\n"),
    ("join: auto combat keeps running", Q, "\t\tW.SetAttr(p, \"AutoCombatEnabled\", false) -- the attribute only", "\t\tlocal _ = 0 --"),
    ("join: joins not counted", Q, "\tQ.Joins += 1\n", ""),
    # --- the remote
    ("remote: any argument count", Q, "\tif select(\"#\", ...) ~= 1 then return end\n", ""),
    ("remote: no rate limit", Q, "\tif not Util.RateLimit(p, \"GooseSquare\", Config.RateLimits.GooseSquare or 1) then return end\n", ""),
    ("remote: a refusal toast is back", Q, "\tGooseSquare.Join(p) -- A23-191", "\tlocal _, k = GooseSquare.Join(p); if k then W.Notify(p, tostring(k)) end -- A23-191"),
    ("count: CountIn counts everyone", Q, "\t\tif W.Faction(p) == faction then n += 1 end\n", "\t\tn += 1\n"),
    # --- leave / the way back
    ("leave: eggs never go back", Q, "\t\tlocal ok, err = pcall(H.OnLeave, p, reason)\n", "\t\tlocal ok, err = true, nil\n"),
    ("leave: attribute stays on", Q, "\t\tW.SetAttr(p, attrIn(), false)\n", ""),
    ("leave: auto combat never restored", Q, "\t\tif Q.Auto[p] then W.SetAttr(p, \"AutoCombatEnabled\", W.SavedAuto(p)) end\n", ""),
    ("leave: the dead are moved", Q, "local stay = reason == \"Death\" or reason == \"Left\"", "local stay = reason == \"Left\""),
    ("leave: a traveller pulled back", Q, "or reason == \"Travel\" or reason == \"Moved\"", "or reason == \"Moved\""),
    ("leave: never moved back", Q, "\tif not stay and p.Parent and W.Alive(p) then W.Pivot(p, back) end\n", ""),
    ("way back: PvP spots kept", Q, "and not GooseSquare.Inside(pos) and not W.PvPAt(pos) then", "and not GooseSquare.Inside(pos) then"),
    ("way back: kill height ignored", Q, "if zoneOk and pos.Y > W.KillY() + SP.KillHeightPad and", "if zoneOk and"),
    ("way back: inside kept", Q, "and not GooseSquare.Inside(pos) and not W.PvPAt(pos)", "and not W.PvPAt(pos)"),
    ("way back: the zone not checked", Q, "local zoneOk = b.Zone == nil or (type(zone) == \"table\" and zone.Id == b.Zone)", "local zoneOk = true"),
    # --- return all / tick
    ("return all: nobody", Q, "\tfor _, p in list do GooseSquare.Leave(p, reason or \"End\") end\n", ""),
    ("tick: falls ignored", Q, "\t\t\tif cf and not GooseSquare.Inside(cf.Position) then\n", "\t\t\tif false then\n"),
    ("tick: far away moved back", Q, "table.insert(out, { p, far and \"Moved\" or \"Fall\" })", "table.insert(out, { p, \"Fall\" })"),
    ("tick: leavers kept", Q, "\t\t\ttable.insert(out, { p, \"Left\" })\n", ""),
    ("tick: no throttle", Q, "\tif clock < Q.NextBlock then return end\n", ""),
    ("tick: block written every time", Q, "\t\tif Q.Block[p] ~= b then\n", "\t\tif true then\n"),
    ("tick: members get their block", Q, "\t\tlocal b = Q.In[p] and \"\" or GooseSquare.BlockOf(p)\n", "\t\tlocal b = GooseSquare.BlockOf(p)\n"),
]


def static() -> tuple[int, list[str]]:
    count, failures = 0, []

    def check(ok: bool, name: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(name)

    config = read(SHARED / "Config.luau")
    check("function Config.InGooseSquare(p)" in config and "Config.Goose.Square.Attr or \"InGooseSquare\"" in config,
          "Config.InGooseSquare reads game dev 1's attribute name (InGooseSquare by default)")
    sq_code = strip_comments(read(SSS / "GooseSquare.luau"))
    check(config.count("Config.Goose.Square = {") == 1 and "Config.Goose.Square =" not in sq_code
          and 'type(Config.Goose.Square) == "table" and Config.Goose.Square or {}' in sq_code,
          "Config.Goose.Square (the client table) is defined once (game dev 1); GooseSquare only reads it")
    net = read(SHARED / "Net.luau")
    check('"GooseSquare", -- A23-141' in net, "Net registers the GooseSquare remote")
    goose = read(SSS / "GooseService.luau")
    check('require(script.Parent:FindFirstChild("GooseSquare"))' in goose and "local function squareOn()" in goose,
          "GooseService requires GooseSquare (not a Main list module) and has squareOn")
    start = function_block(goose, "local function start()")
    check(start.find("pcall(setEggGeometry)") >= 0 and start.find("pcall(setEggGeometry)") < start.find("pcall(GooseEggs.Begin"),
          "start: the square's geometry is set before GooseEggs.Begin")
    geo = function_block(goose, "local function setEggGeometry()")
    check("Center = sp.GooseSpot, Home = { Halo = sp.Nest, Horns = sp.Cart }" in geo and "Members = GooseSquare.Members" in geo
          and "Square = true" in geo and "GooseEggs.SetGeometry(nil)" in geo,
          "setEggGeometry: centre = GooseSpot, homes = Nest / Cart, the spawns avoided, members only (or the Config ring)")
    fin = function_block(goose, "local function finishEggs()")
    check("task.delay(math.max(0, tonumber(SQS.ReturnAfter) or 4)" in fin and 'pcall(GooseSquare.ReturnAll, "End")' in fin
          and "info.Joins = GooseSquare.TakeJoins()" in fin, "finishEggs: everyone goes back ReturnAfter s after the result; info.Joins")
    tick = function_block(goose, "local function tick()")
    check("pcall(GooseSquare.Tick, now)" in tick, "tick runs GooseSquare.Tick")
    init = function_block(goose, "function GooseService.Init(")
    check('pcall(GooseSquare.Leave, player, "Left")' in init and 'pcall(GooseSquare.Leave, player, "Death")' in init
          and 'pcall(GooseSquare.Leave, player, "Faction")' in init and "IsActive = function() return active == true and squareOn() end" in init
          and "GooseEggs.ReturnEggs(p, reason == \"Death\" and \"Death\" or \"Leave\")" in init,
          "Init: leaving / death / a faction change leave the square; Join only while a goose is on; the eggs go back")
    st = function_block(goose, "function GooseService.Start()")
    check("Net.Get(remote).OnServerEvent:Connect" in st and "GooseSquare.OnRemote(player, ...)" in st and "pcall(GooseSquare.Ensure)" in st,
          "Start: the space is ensured and the remote is connected")
    check("function GooseService.LeaveSquare(player, reason)" in goose, "GooseService.LeaveSquare (ZoneService's teleports)")
    eggs = read(SSS / "GooseEggs.luau")
    check("for _, p in (GEO.Members and GEO.Members() or W.Players()) do" in eggs and "if GEO.Square then return true end" in eggs
          and "function GooseEggs.SetGeometry(g)" in eggs and "E.Center" not in strip_comments(eggs).replace("Center = E.Center", "")
          .replace("g.Center or E.Center", ""),
          "GooseEggs: only the square's members play, the walls replace the ring edge, every centre / home reads GEO")
    pvp = read(SSS / "PvPService.luau")
    can = function_block(pvp, "function PvPService.CanAttack(")
    check("Config.InGooseSquare(attacker) or Config.InGooseSquare(victim)" in can and 'return false, "SafeZone"' in can,
          "PvPService.CanAttack: nobody in the square hits or is hit")
    zone = read(SSS / "ZoneService.luau")
    tp = function_block(zone, "local function teleport(player, zoneId)")
    check('pcall(gs.LeaveSquare, player, "Travel")' in tp and tp.find("LeaveSquare") < tp.find("PivotTo"),
          "ZoneService teleport: out of the square first")
    player = read(SSS / "PlayerService.luau")
    ws = function_block(player, "function PlayerService.ComputeWalkSpeed(player)")
    check(ws.find('player:GetAttribute("EggPlaza") == true') >= 0 and ws.find("EggPlaza") < ws.find("local kaiju")
          and 'return Config.GooseEggSpeed(player:GetAttribute("EggCarry"))' in ws,
          "ComputeWalkSpeed: the plaza speed returns first (the old return line untouched)")
    skill = read(SSS / "SkillService.luau")
    check('(tonumber(player:GetAttribute("EggCarry")) or 0) > 0 then return nil, "TooHeavy" end' in skill, "Hop refused while carrying eggs")
    combat = read(SSS / "CombatService.luau")
    check('if Config.Goose.Mode ~= "Tug" or not PVP_FACTIONS[faction(player)] then' in combat, "CombatService: the goose is a target in Tug only")
    fin = function_block(goose, "local function finishEggs()")
    check(fin.find("task.delay(math.max(0, tonumber(SQS.ReturnAfter) or 4)") >= 0
          and fin.find("task.delay(math.max(0, tonumber(SQS.ReturnAfter) or 4)") < fin.find("pcall(GooseEggs.Finish"),
          "finishEggs: the square's return is scheduled before anything that can fail")
    vis = read(SSS / "CharacterVisuals.luau")
    check('EggCarry = { "EggStack" }' in vis and '"EggStack",\n}' in vis and "EggStack = buildEggStack," in vis
          and 'joint.Name = "EggJoint"' in vis and "Instance.new(\"Motor6D\")" in function_block(vis, "local function buildEggStack("),
          "CharacterVisuals: EggStack follows EggCarry, one Motor6D EggJoint")
    mapb = read(SSS / "MapBuilder.luau")
    check('{ Name = "GoosePerch", Build = buildGoosePerch, Tug = true }' in mapb and 'if def.Tug and Config.Goose.Mode ~= "Tug" then' in mapb,
          "MapBuilder: the Crossroads perch only in Tug mode")
    story = read(SSS / "StoryQuestService.luau")
    check('and (f == "Halo" or f == "Horns") and Config.Goose.Mode == "Tug" then' in story, "StoryQuest: the first-goose +1 only in Tug mode")
    health = read(SSS / "HealthService.luau")
    check('"Joins", "Delivered", "ScoreGap", "DropFails", "CheatLogs"' in function_block(health, "function HealthService.OnGooseFinished("),
          "HealthService records joins / deliveries / the gap / drop fails / cheat logs")
    return count, failures


SUITE = Suite(
    mark="SQUARE",
    fixture=ROOT / "tools/fixtures/goose_square_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-12/offline_dev2_goose_square_2026-10-12.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-141 (user 10/12): the egg hunt runs in the Goose Square (workspace.GooseSquare: the image team's model - "
             "<Mark>Pos attributes or parts GooseSpot / Nest / Cart / SpawnHalo / SpawnHorns / SpawnNeutral, Floor = the "
             "area; none -> a plain floor + walls + marks built once at Config.Goose.SquareSpace.Center (6000, 200, 6000) + "
             "Offsets). Remote GooseSquare('Join' | 'Leave'), one string argument, RateLimits.GooseSquare 1. Join: a goose "
             "is on, ready, Halo / Horns / Neutral, alive ('Dead'), not the kaiju ('Monster'), no grudge sack ('Grudge'), no "
             "PvP hit dealt / taken within 10 s ('PvP'); a refusal = Config.Goose.Square.Text[key] once (game dev 1's table; "
             "missing = no line). Joined: the spot + its zone remembered, auto combat paused (attribute only), moved to the "
             "side's spawn (within SpawnSpread, 3.5 up), InGooseSquare true. Leave (Button / Faction: moved back; Death / Left "
             "/ Travel / Moved: not moved): the eggs go back first, InGooseSquare false, auto combat = the save. The way "
             "back = the Join spot unless a PvP spot, under kill height + 50, inside the square or not the zone it was "
             "pressed in -> the own town start. ReturnAll at the round's end (ReturnAfter 4 s). Tick: off the floor -> Fall "
             "(moved back), > 300 studs away -> Moved, gone -> Left; GooseJoinBlock '' | Dead | Monster | Grudge | PvP for "
             "every ready player ('' inside), written on a change, every BlockEvery s.",
    limitations="The real PivotTo / ZoneService.MarkTeleported / Ground.Cast and the built parts' look are Studio's (a Play "
                "check by 메인 반영 1); GooseEggs' square geometry is checked statically here (its rules: tools/test_golden_egg.py).",
)

if __name__ == "__main__":
    run(SUITE)
