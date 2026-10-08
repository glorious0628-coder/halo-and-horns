"""Re-shoot the devlog clips as s40_* (촬영 편집, docs/devlog/reshoot_2026-10-07.md — the 2026-10-08 table: the new HUD,
weapon first, the Lost Lunchbox card, the first skill at Lv5, map v2).

  FILM_OK=1 STUDIO_NAME=FilmSet py tools/devlog_shots_s40.py [A] [C] [B]      (no letter = all, always run A -> C -> B)
  SKIP=s40_crossroads,s40_halo_town  ...                                       (leave these shots out)
  LUNCH=Good ... A                                                            (2nd fresh Play: only [Give it back])

A  the new player's first minutes in one Play (ServerStorage StudioFreshSave on = fresh in-memory data, nothing saved):
   faction pick -> the guide's mission card -> 'Off to the Forge!' -> the first weapon [Twig] + "Stronger!" -> the first
   hunt with the twig -> [Claim] + the Lost Lunchbox card ([One bite!]) -> Lv5 "New skill!" -> the world map
C  places and monsters with the HUD off (map v2 positions from Config.Zones at run time) + the baby slime prop
B  the strong knight (Lv30, T6 weapon, auto combat): the Pumpkin King fight, the meadow hunt (HUD on)

The remotes and the anvil prompt are the same as tools/play_weapon_first.py (game dev 1). Only after 검수 "전달함, 시작"
(FilmSet window + test Play, about 10 min for all) and after the doc's §0 (the day's place/ copied into build/FilmSet.rbxlx,
src synced from the clean origin/main worktree Game-film twice = 0 files). No mouse / keyboard: camera, character and
windows by Studio MCP code only."""
import math
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import devlog_film as D

KING = "(function() for _,m in workspace.Monsters:GetChildren() do if m:GetAttribute('MonsterKind')=='%s' then return m end end end)()"
MY_ROOT = "(game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild('HumanoidRootPart'))"
PICKER = "local mg=game.Players.LocalPlayer.PlayerGui:FindFirstChild('MainGui'); local f=mg and mg:FindFirstChild('FactionPicker'); return f and tostring(f.Visible) or 'none'"
MODAL = "local mg=game.Players.LocalPlayer.PlayerGui:FindFirstChild('MainGui'); local f=mg and mg:FindFirstChild('PanelsModal'); return f and tostring(f.Visible) or 'none'"
# from the end of A on: keep the story / guide window shut (it opens on its own for new quest steps) + no chat
HIDE_MODAL = r"""
local pg = game.Players.LocalPlayer:WaitForChild('PlayerGui')
_G.__filmHideModal = true
if not _G.__filmHideLoop then
	_G.__filmHideLoop = true
	task.spawn(function()
		local t = os.clock()
		while os.clock() - t < 1500 do
			if _G.__filmHideModal then
				local mg = pg:FindFirstChild('MainGui')
				local m = mg and mg:FindFirstChild('PanelsModal')
				if m and m.Visible then m.Visible = false end
			end
			task.wait(0.1)
		end
	end)
end
pcall(function()
	local tcs = game:GetService('TextChatService')
	tcs.ChatWindowConfiguration.Enabled = false
	tcs.ChatInputBarConfiguration.Enabled = false
end)
return 'modal + chat hidden'
"""
FRESH = "game:GetService('ServerStorage'):SetAttribute('StudioFreshSave', %s); return 'fresh %s'"
STATE = r"""
local p = game:GetService('Players'):GetPlayers()[1]
if not p then return '' end
local out = {}
for _, k in { 'DataLoaded', 'Faction', 'ClassChosen', 'TutorialStep', 'TutorialKills', 'WeaponTier', 'Level', 'ZoneId' } do
	table.insert(out, k .. '=' .. tostring(p:GetAttribute(k)))
end
table.insert(out, 'Held=' .. tostring(p.Character ~= nil and p.Character:FindFirstChild('WeaponModel') ~= nil))
return table.concat(out, ' ')
"""
FIRE = "local R=game:GetService('ReplicatedStorage'):WaitForChild('Remotes'); R:WaitForChild('%s'):FireServer(%s); return 'fired %s'"
# client: hold the anvil prompt (the same path as a custom prompt UI, play_weapon_first.py)
ANVIL = r"""
local found = nil
for _, d in (workspace:FindFirstChild('Map') or workspace):GetDescendants() do
	if d:IsA('ProximityPrompt') and (d.Name == 'HHC_BlacksmithPrompt' or d.Name == 'BlacksmithPrompt') then found = d; break end
end
if not found then return 'no prompt' end
found:InputHoldBegin()
task.wait(found.HoldDuration + 0.2)
found:InputHoldEnd()
return 'anvil held'
"""
DISPATCH = r"""
local kb = game.Players.LocalPlayer.PlayerScripts:FindFirstChild('Keybinds')
local d = kb and kb:FindFirstChild('Dispatch')
if not d then return 'no dispatch' end
return tostring(d:Invoke({ KeyCode = Enum.KeyCode.%s }))
"""
# client: walk to the nearest slime I may hit and press Attack (one hit per press, A23-1) until stopped
HUNT = r"""
_G.__filmHunt = (_G.__filmHunt or 0) + 1
local tok = _G.__filmHunt
local me = game.Players.LocalPlayer
local kb = me.PlayerScripts:FindFirstChild('Keybinds')
local d = kb and kb:FindFirstChild('Dispatch')
task.spawn(function()
	local t0 = os.clock()
	while _G.__filmHunt == tok and os.clock() - t0 < %d do
		local c = me.Character
		local hum = c and c:FindFirstChildOfClass('Humanoid')
		local root = c and c:FindFirstChild('HumanoidRootPart')
		local folder = workspace:FindFirstChild('Monsters')
		if hum and root and folder then
			local best, bd
			for _, m in folder:GetChildren() do
				local owner = m:GetAttribute('OwnerUserId')
				if m:GetAttribute('MonsterKind') == 'Slime' and not m:GetAttribute('Leaving') and (owner == nil or owner == me.UserId) then
					local q = m:GetPivot().Position
					local dd = (Vector3.new(q.X, 0, q.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
					if not bd or dd < bd then best, bd = m, dd end
				end
			end
			if best then
				local q = best:GetPivot().Position
				if bd > 5 then
					local away = Vector3.new(root.Position.X - q.X, 0, root.Position.Z - q.Z)
					hum:MoveTo(q + (away.Magnitude > 0.1 and away.Unit * 3.5 or Vector3.zero))
				else
					hum:MoveTo(root.Position)
					root.CFrame = CFrame.lookAt(root.Position, Vector3.new(q.X, root.Position.Y, q.Z))
					if d then pcall(function() d:Invoke({ KeyCode = Enum.KeyCode.F }) end) end
				end
			end
		end
		task.wait(0.45)
	end
end)
return 'hunt'
"""
HUNT_STOP = "_G.__filmHunt = (_G.__filmHunt or 0) + 1; local c=game.Players.LocalPlayer.Character; local h=c and c:FindFirstChildOfClass('Humanoid'); if h and c.PrimaryPart then h:MoveTo(c.PrimaryPart.Position) end; return 'hunt stopped'"
ZONES = r"""
local Z = require(game:GetService('ReplicatedStorage'):WaitForChild('Shared'):WaitForChild('Config')).Zones
local o = {}
for k, z in Z do
	if type(z) == 'table' and typeof(z.Center) == 'Vector3' and typeof(z.Spawn) == 'Vector3' then
		table.insert(o, string.format('%s=%.1f,%.1f,%.1f,%.1f', k, z.Center.X, z.Center.Z, z.Spawn.X, z.Spawn.Z))
	end
end
return table.concat(o, ';')
"""
BARK = ("local m=%s; if not m then return 'no monster' end; m:SetAttribute('Bark', %s); "
        "m:SetAttribute('BarkAt', workspace:GetServerTimeNow()); return 'bark'")
MAP_OPEN = "local M = require(game.Players.LocalPlayer.PlayerScripts:WaitForChild('WorldMap')); M.Open(); return 'map open'"
MAP_CLOSE = "local M = require(game.Players.LocalPlayer.PlayerScripts:WaitForChild('WorldMap')); M.Close(); return 'map closed'"
SKIP = set(s for s in os.environ.get("SKIP", "").split(",") if s)
# the Lost Lunchbox pick: Evil = [One bite!] (the first run), Good = [Give it back] (a second fresh Play that films only
# that card: 검수 2026-10-08 "둘 다 찍기")
LUNCH = "Good" if os.environ.get("LUNCH") == "Good" else "Evil"
# LUNCH_ONLY=1: film only the lunchbox card (a re-take); LUNCH=Good always does
if LUNCH == "Good" or os.environ.get("LUNCH_ONLY") == "1":
    SKIP |= {"s40_faction_pick", "s40_guide_card", "s40_forge_trip", "s40_first_hunt", "s40_new_skill", "s40_world_map"}
    if os.environ.get("KEEP_WEAPON") == "1":
        SKIP.add("s40_first_weapon")
LOG = []
Z = {}


def sheet(name):
    D.subprocess.run([D.FFMPEG, "-hide_banner", "-loglevel", "error", "-y", "-i", os.path.join(D.RAW, name + ".mp4"), "-vf",
                      "fps=1/2,scale=360:-2,tile=6x2", "-frames:v", "1", "build/devlog/check/%s_sheet.png" % name])


def rec(name, sec, cam=None):
    if name in SKIP:  # no recording, but the shot's actions (a remote, the anvil, a claim) still run on time
        print("skip", name, flush=True)
        t0 = time.time()
        if cam:
            cam()
        time.sleep(max(0.0, sec - (time.time() - t0)))
        return
    p, out = D.start_rec(name, sec)
    time.sleep(0.5)
    if cam:
        cam()
    p.wait()
    sheet(name)
    LOG.append(name)
    print(out, flush=True)


def state(f):
    raw = f.lua(STATE) or ""
    return dict(kv.split("=", 1) for kv in raw.split() if "=" in kv)


def wait_for(f, cond, timeout, every=0.5):
    t0 = time.time()
    st = {}
    while time.time() - t0 < timeout:
        try:
            st = state(f)
            if cond(st):
                return st
        except Exception:
            pass
        time.sleep(every)
    print("timeout:", st, flush=True)
    return st


def num(v, d=0.0):
    try:
        return float(v)
    except (TypeError, ValueError):
        return d


def load_zones(f):
    for row in (f.lua(ZONES) or "").split(";"):
        if "=" in row:
            k, v = row.split("=", 1)
            Z[k] = [float(x) for x in v.split(",")]
    print("zones:", {k: Z[k] for k in sorted(Z)}, flush=True)


def zc(name):
    return Z[name][0], Z[name][1]


def zs(name):
    return Z[name][2], Z[name][3]


def tag_nearest(f, kind, near, tag):
    return f.lua("for _,o in workspace.Monsters:GetChildren() do if o:GetAttribute('FilmTag')=='%s' then o:SetAttribute('FilmTag', nil) end end; "
                 "local best,bd; for _,m in workspace.Monsters:GetChildren() do if m:GetAttribute('MonsterKind')=='%s' then local q=m:GetPivot().Position; "
                 "local d=(Vector3.new(q.X,0,q.Z)-Vector3.new(%f,0,%f)).Magnitude; if not bd or d<bd then best,bd=m,d end end end; "
                 "if not best then return '' end; best:SetAttribute('FilmTag','%s'); return tostring(best:GetPivot().Position)" % (tag, kind, near[0], near[1], tag))


def tagged(tag):
    return "(function() for _,o in workspace.Monsters:GetChildren() do if o:GetAttribute('FilmTag')=='%s' then return o end end end)()" % tag


def close_up(f, kind, near, name, r=7, h=2.2, ly=1.4, sec=9):
    if name in SKIP:
        print("skip", name, flush=True)
        return
    pos = tag_nearest(f, kind, near, "f_" + kind)
    if not pos:
        print("no", kind, flush=True)
        return
    x, y, z = [float(v) for v in pos.split(",")]
    f.teleport((x - 60, 6, z - 60), (x, 6, z))
    time.sleep(1.2)
    rec(name, sec, lambda: f.orbit((x, y, z), r, h, -60, 60, sec - 0.6, look_y=ly, target=tagged("f_" + kind), front=True))


def boss(f, key, kind, name):
    print(key, f.debug(key, True), flush=True)
    kp = ""
    for i in range(20):
        kp = f.lua("local k=" + KING % kind + "; return k and tostring(k:GetPivot().Position) or ''")
        if kp:
            break
        time.sleep(1)
    if not kp:
        print("no", kind, flush=True)
        return ""
    x, y, z = [float(v) for v in kp.split(",")]
    f.teleport((x - 45, 6, z - 45), (x, 6, z))
    time.sleep(2)
    f.look("king", focus=12)
    rec(name, 12, lambda: f.orbit((0, 0, 0), 12, 2.0, -50, 50, 11.2, look_y=5.0, target=KING % kind, front=True))
    return kp


def approach(f, zone, name):
    """walk the camera in through a town's entrance (the s30 path: spawn = entrance, toward the zone centre)"""
    sx, sz = zs(zone)
    cx, cz = zc(zone)
    dx, dz = cx - sx, cz - sz
    L = math.hypot(dx, dz) or 1.0
    dx, dz = dx / L, dz / L
    px, pz = -dz, dx
    f.teleport((sx - dx * 80 + px * 60, 6, sz - dz * 80 + pz * 60), (sx, 6, sz))
    time.sleep(1.5)
    rec(name, 12, lambda: f.dolly((sx - dx * 170 - px * 30, 26, sz - dz * 170 - pz * 30), (sx - dx * 90 + px * 30, 16, sz - dz * 90 + pz * 30),
                                  (sx, 10, sz), (sx + dx * 30, 12, sz + dz * 30), 11.4))


def flow_a(f):
    """A: the new player's first minutes (fresh data); ends with the world map (HUD on)"""
    rec("s40_faction_pick", 6)
    print(f.lua(FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"), flush=True)
    wait_for(f, lambda s: s.get("Faction") == "Halo", 20)
    print(f.lua(FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"), flush=True)
    wait_for(f, lambda s: s.get("ClassChosen") == "true", 20)
    f.look("angel", focus=9)  # 검수 2026-10-08 "미장센": warm gold, soft background
    for i in range(16):  # the guide's mission card opens after the pick
        time.sleep(0.5)
        if f.lua(MODAL, "Client") == "true":
            break
    time.sleep(1.0)
    rec("s40_guide_card", 6)

    # [I'm In!] -> 'Off to the Forge!' -> the landing in front of the anvil -> the game presses the anvil for me when I
    # land near it (HUD L.PressAnvil) -> [Twig] + "Stronger!": all in one clip, the close front camera set up during the
    # fade so the moment is never missed (2026-10-08: a separate forge clip swallowed the gift)
    def gift():
        f.clean(("Announce", "Toasts"))  # 9:16 shorts: no half-cut HUD, only the banner and the weapon toast
        print(f.lua(FIRE % ("AcceptTutorial", "", "AcceptTutorial"), "Client"), flush=True)
        wait_for(f, lambda s: s.get("TutorialStep") == "3", 6, 0.3)
        time.sleep(2.6)  # the 3·2·1 fade and the trip
        # the anvil button only shows while the anvil is on screen: the game's own camera (behind me, facing it) until
        # the gift, then at once the close front camera for "Stronger!"
        got = wait_for(f, lambda s: s.get("WeaponTier") not in (None, "nil", "0"), 2.5, 0.2)
        if got.get("WeaponTier") in (None, "nil", "0"):
            print("anvil:", f.lua(ANVIL, "Client"), flush=True)
            got = wait_for(f, lambda s: s.get("WeaponTier") not in (None, "nil", "0"), 1.5, 0.2)
        if got.get("WeaponTier") in (None, "nil", "0"):
            print("forge key U:", f.lua(DISPATCH % "U", "Client"), flush=True)
        f.orbit((0, 0, 0), 9, 1.0, -30, 30, 9.0, look_y=1.9, target=MY_ROOT, front=True)  # low = heroic, me centred
        time.sleep(2.4)
        for k in range(2):  # not standing still: two swings with the new twig
            f.lua(DISPATCH % "F", "Client")
            time.sleep(1.1)
    rec("s40_first_weapon", 14, gift)
    print("first weapon:", wait_for(f, lambda s: s.get("WeaponTier") not in (None, "nil", "0") and s.get("Held") == "true", 10), flush=True)

    # the meadow trip (Forge.TravelDelay) and the first hunt with the twig (the game's own camera follows behind)
    wait_for(f, lambda s: s.get("ZoneId") == "SlimeMeadow", 20)
    time.sleep(1.0)
    f.clean(())  # world only: my twig, the slimes and their bubbles
    f.look("angel", focus=9)
    if os.environ.get("HUNT_LEVEL"):  # a stronger twig: slimes go down in a hit or two, so they hardly hit back ("Ouch!")
        print("hunt level:", f.debug("Level", int(os.environ["HUNT_LEVEL"])), flush=True)
    print(f.lua(HUNT % 90, "Client"), flush=True)
    # 검수 2026-10-08: the swing must show — a near camera beside / in front of me (my facing), the twig arm toward it
    rec("s40_first_hunt", 25, lambda: f.orbit((0, 0, 0), 9, 2.2, -75, -35, 24, look_y=2.0, target=MY_ROOT, front=True))
    st = wait_for(f, lambda s: num(s.get("TutorialKills")) >= 5, 60, 1.0)
    print(f.lua(HUNT_STOP, "Client"), flush=True)
    # a card waits while I fight (the meadow slimes keep hitting me, 2026-10-08): claim from the quiet Crossroads square
    # in front of the new fountain, after Panels STORY.CalmSeconds
    cx, cz = zc("Crossroads")
    f.teleport((cx + 10, 5, cz - 28), (cx, 5, cz))
    time.sleep(5.5)  # Panels STORY.CalmSeconds: a card right after a fight waits for a tap instead of opening

    f.clean(("PanelsModal", "Toasts"))  # the card and the kid's reply only
    f.look("angel", focus=10)
    # [Claim] (+150 gold) -> the Lost Lunchbox card -> [One bite!] -> the kid's line
    def claim():
        print(f.lua(FIRE % ("ClaimQuest", '"tutorial"', "ClaimQuest"), "Client"), flush=True)
        for i in range(10):
            time.sleep(0.4)
            if f.lua(MODAL, "Client") == "true":
                break
        else:
            print(f.lua(FIRE % ("StoryAction", '"Lunch1", "Open"', "StoryAction"), "Client"), flush=True)
        time.sleep(3.0)
        # the server takes the pick, but only the card's own button closes the card on the client (2026-10-08 test):
        # press by remote, then close it ourselves -> the kid's reply toast shows (A23-70, d8b6a590)
        print(f.lua(FIRE % ("StoryAction", '"Lunch1", "Choose", "%s"' % LUNCH, "StoryAction"), "Client"), flush=True)
        time.sleep(0.15)
        print(f.lua("local mg=game.Players.LocalPlayer.PlayerGui:FindFirstChild('MainGui'); local m=mg and mg:FindFirstChild('PanelsModal'); "
                    "if m then m.Visible=false end; return 'card closed'", "Client"), flush=True)
    rec("s40_claim_lunchbox" + ("_good" if LUNCH == "Good" else ""), 14, claim)
    if LUNCH == "Good" or os.environ.get("LUNCH_ONLY") == "1":
        return
    time.sleep(1.0)

    f.unclean()
    # Lv5: "New skill!" + the Q button pops in (A23-71)
    rec("s40_new_skill", 8, lambda: (time.sleep(0.8), print("level 5:", f.debug("Level", 5), flush=True)))
    time.sleep(1.0)

    print(f.lua(MAP_OPEN, "Client"), flush=True)
    time.sleep(0.8)
    rec("s40_world_map", 6)
    print(f.lua(MAP_CLOSE, "Client"), flush=True)
    time.sleep(0.8)


def knight(f):
    """the strong knight for C and B (the s30 setup): Lv30, T6 weapon, past the Pumpkin King's newcomer rule"""
    for k, v in (("Faction", "Halo"), ("Class", "Warrior"), ("ClassChosen", True), ("Level", 30), ("PlaytimeSeconds", 1500), ("WeaponTier", 6)):
        f.debug(k, v)
    f.lua("local p=game.Players:GetPlayers()[1]; p:SetAttribute('AutoCombatUnlocked',true); return 'ok'")
    print(f.lua(HIDE_MODAL, "Client"), flush=True)
    time.sleep(1.0)
    print("knight weapon:", wait_for(f, lambda s: s.get("Held") == "true", 10), flush=True)


def flow_c(f):
    """C: places and monsters, HUD off, map v2 positions"""
    f.hud(False)
    f.clean(())
    f.look("far")
    cx, cz = zc("Crossroads")
    f.teleport((cx + 8, 4, cz - 24), (cx, 4, cz))
    time.sleep(1)
    rec("s40_crossroads", 12, lambda: f.orbit((cx, 4, cz), 40, 9, -60, 60, 11.4, look_y=8))
    approach(f, "HaloTown", "s40_halo_town")
    approach(f, "HornsTown", "s40_horns_town")

    ms, mz = zs("SlimeMeadow")
    mc, mcz = zc("SlimeMeadow")
    f.teleport((ms - 40, 6, mz + 60), (ms, 6, mz))
    time.sleep(1.5)
    rec("s40_meadow_wide", 12, lambda: f.dolly((ms - 30, 34, mz - 70), (ms + 110, 22, mz - 40), (ms + 80, 2, mz + 10), (mc, 2, mcz), 11.4))
    ws_, wz = zs("GoblinWoods")
    wc, wcz = zc("GoblinWoods")
    f.teleport((ws_ - 40, 6, wz + 60), (ws_, 6, wz))
    time.sleep(1.5)
    rec("s40_woods_wide", 12, lambda: f.dolly((ws_ - 30, 40, wz - 80), (ws_ + 110, 26, wz - 40), (ws_ + 90, 4, wz + 10), (wc, 4, wcz), 11.4))

    close_up(f, "Slime", (ms + 100, mz), "s40_slime_front")
    # a slime saying its idle line in its own bubble (BarkService contract: Bark + BarkAt; shown within 60 studs of me)
    if "s40_slime_bark" not in SKIP:
        pos = tag_nearest(f, "Slime", (ms + 100, mz), "f_bark")
        if pos:
            x, y, z = [float(v) for v in pos.split(",")]
            f.teleport((x - 18, 6, z - 18), (x, 6, z))
            time.sleep(1.2)
            rec("s40_slime_bark", 8, lambda: (f.orbit((x, y, z), 7, 2.4, -40, 40, 7.4, look_y=2.2, target=tagged("f_bark"), front=True),
                                              time.sleep(0.8), f.lua(BARK % (tagged("f_bark"), '"Blub blub~"')),
                                              time.sleep(3.6), f.lua(BARK % (tagged("f_bark"), '"Jiggle~"'))))
    pc, pcz = zc("PumpkinPatch")
    close_up(f, "PumpkinSlime", (pc, pcz), "s40_pumpkin_slime")
    f.teleport((pc - 30, 5, pcz - 130), (pc, 5, pcz - 60))
    time.sleep(1.5)
    rec("s40_patch_dolly", 12, lambda: f.dolly((pc - 68, 26, pcz - 72), (pc + 72, 16, pcz - 44), (pc, 2, pcz), (pc + 12, 2, pcz + 12), 11.2))
    kp = boss(f, "PumpkinKing", "PumpkinKing", "s40_king_front")
    gx, gz = zs("GoblinWoods")
    close_up(f, "BatGoblin", (gx, gz), "s40_bat_goblin", r=9, h=3.0, ly=3.0)
    hc, hcz = zc("HauntedHollow")
    close_up(f, "LittleGhost", (hc, hcz), "s40_little_ghost", r=8, h=2.5, ly=3.0)
    close_up(f, "GhostMinion", (hc, hcz), "s40_ghost_minion", r=7, h=2.2, ly=2.5)
    f.teleport((hc - 70, 6, hcz - 45), (hc, 6, hcz))
    time.sleep(1.5)
    rec("s40_haunted_hollow", 12, lambda: f.dolly((hc - 60, 24, hcz - 55), (hc + 55, 14, hcz - 30), (hc, 2, hcz), (hc + 8, 2, hcz + 10), 11.2))
    boss(f, "GhostKing", "GhostKing", "s40_ghost_king_front")

    # the Baby Slime model as a still prop (short 2's turntable cut)
    f.lua(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "devlog_pet_prop.lua"), encoding="utf-8").read())
    f.teleport((260, 6, -80), (300, 6, -40))
    time.sleep(1)
    rec("s40_pet", 9, lambda: f.orbit((300, 0.5, -40), 3.2, 0.9, -80, 80, 8.4, look_y=0.45, target="workspace:FindFirstChild('FilmPet')", front=True))
    return kp


def flow_k(f):
    """K: the two new castles up close (2026-10-08: the entrance dolly showed them small and far), HUD off, me out of frame"""
    f.hud(False)
    f.clean(())
    for zone, model, name, a0, a1 in (("HaloTown", "HaloCastle", "s40_halo_castle", 55, 125), ("HornsTown", "HornsCastle", "s40_horns_castle", -125, -55)):
        box = f.lua("local m=workspace.Map.Landmarks:FindFirstChild('%s'); if not m then return '' end; local cf,sz=m:GetBoundingBox(); "
                    "return string.format('%%.1f,%%.1f,%%.1f,%%.1f', cf.X, cf.Y, cf.Z, math.max(sz.X, sz.Z))" % model)
        if not box:
            print("no", model, flush=True)
            continue
        bx, by, bz, bw = [float(v) for v in box.split(",")]
        sx, sz = zs(zone)
        f.teleport((sx + 40, 6, sz), (bx, 6, bz))
        time.sleep(2.0)
        r = bw * 1.25
        f.look("far" if zone == "HaloTown" else "devil", focus=r)
        rec(name, 10, lambda: f.orbit((bx, 0, bz), r, 6, a0, a1, 9.4, look_y=by * 0.75))
    f.hud(True)


def flow_b(f, kp=""):
    """B: the strong knight fights (HUD on, auto combat)"""
    f.hud(True)
    f.lua("local p=game.Players:GetPlayers()[1]; local h=p.Character and p.Character:FindFirstChildOfClass('Humanoid'); if h then h.Health=h.MaxHealth end; return 'hp'")
    kp2 = f.lua("local k=" + KING % "PumpkinKing" + "; return k and tostring(k:GetPivot().Position) or ''") or kp
    if not kp2:
        print("PumpkinKing", f.debug("PumpkinKing", True), flush=True)
        for i in range(20):
            kp2 = f.lua("local k=" + KING % "PumpkinKing" + "; return k and tostring(k:GetPivot().Position) or ''")
            if kp2:
                break
            time.sleep(1)
    if kp2:
        x, y, z = [float(v) for v in kp2.split(",")]
        f.teleport((x - 6, 5, z - 6), (x, 5, z))
        time.sleep(1.0)
        f.lua("local p=game.Players:GetPlayers()[1]; p:SetAttribute('AutoCombatEnabled',true); return 'auto'")
        f.clean(())
        f.look("king", focus=15)
        rec("s40_king_fight", 25, lambda: f.orbit((0, 0, 0), 15, 3.5, -150, -80, 24, look_y=4.0, target="char"))
    f.unclean()
    ms, mz = zs("SlimeMeadow")
    f.lua("local p=game.Players:GetPlayers()[1]; p:SetAttribute('AutoCombatEnabled',true); return 'auto'")
    f.teleport((ms + 106, 4, mz - 2), (ms + 117, 4, mz + 13))
    time.sleep(1.5)
    rec("s40_meadow_auto", 20, lambda: (f.orbit((0, 0, 0), 17, 8.5, -150, -80, 19, look_y=1.5, target="char"),
                                        f.walk([(ms + 115, 4, mz + 9), (ms + 120, 4, mz + 18), (ms + 132, 4, mz + 26)], speed=12)))
    f.lua("local p=game.Players:GetPlayers()[1]; p:SetAttribute('AutoCombatEnabled',false); return 'off'")


def main():
    groups = [g for g in sys.argv[1:] if g in ("A", "B", "C", "K")] or ["A", "C", "B"]
    f = D.Film()
    fresh = "A" in groups
    try:
        if fresh:
            print(f.lua(FRESH % ("true", "on"), "Edit"), flush=True)
        print(f.call("start_stop_play", {"is_start": True}), flush=True)
        wait_for(f, lambda s: s.get("DataLoaded") == "true", 90, 2.0)
        for i in range(60):  # the faction picker comes after the opening (15-25 s the first time)
            time.sleep(1)
            try:
                if f.lua(PICKER, "Client") == "true":
                    break
            except Exception:
                pass
        time.sleep(1.5)
        load_zones(f)
        if "A" in groups:
            flow_a(f)
        knight(f)
        kp = ""
        if "K" in groups:
            flow_k(f)
        if "C" in groups:
            kp = flow_c(f) or ""
        if "B" in groups:
            flow_b(f, kp)
    finally:
        try:
            f.cam_reset()
            f.hud(True)
        except Exception:
            pass
        try:
            print(f.call("start_stop_play", {"is_start": False}), flush=True)
        finally:
            if fresh:
                time.sleep(2)
                try:
                    print(f.lua(FRESH % ("nil", "off"), "Edit"), flush=True)
                except Exception as e:  # noqa: BLE001
                    print("fresh off failed:", e, flush=True)
            f.close()
            D.minimize_film()
            print("DONE: play stopped, window minimized; shots:", LOG, flush=True)


if __name__ == "__main__":
    main()
