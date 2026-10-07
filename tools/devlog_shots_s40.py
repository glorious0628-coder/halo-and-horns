"""Re-shoot every devlog clip as s40_* (촬영 편집, docs/devlog/reshoot_2026-10-07.md): the 16 s30 clips with the same
cameras + the story window, the reward popup (no rays), the world map and the Pet Tamer's baby slime.

  FILM_OK=1 STUDIO_NAME=FilmSet py tools/devlog_shots_s40.py

Only after 검수 "전달함, 시작" (FilmSet window + test Play, ~12 min) — and (검수 2026-10-07 evening) only after the map v2,
the 3D decor and the HUD layout are in main, so FilmSet shows the new screens. Before it: put the latest place/ copy into
build/FilmSet.rbxlx and sync src from a clean origin/main worktree (Game-film). No mouse / keyboard: camera, character
and windows by Studio MCP code only."""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import devlog_film as D

KING = "(function() for _,m in workspace.Monsters:GetChildren() do if m:GetAttribute('MonsterKind')=='%s' then return m end end end)()"
PICKER = "local mg=game.Players.LocalPlayer.PlayerGui:FindFirstChild('MainGui'); local f=mg and mg:FindFirstChild('FactionPicker'); return f and tostring(f.Visible) or 'none'"
MODAL = "local mg=game.Players.LocalPlayer.PlayerGui:FindFirstChild('MainGui'); local f=mg and mg:FindFirstChild('PanelsModal'); return f and tostring(f.Visible) or 'none'"
HIDE_MODAL = r"""
local pg = game.Players.LocalPlayer:WaitForChild('PlayerGui')
_G.__filmHideModal = true
task.spawn(function()
	local t = os.clock()
	while os.clock() - t < 1200 do
		if _G.__filmHideModal then
			local mg = pg:FindFirstChild('MainGui')
			local m = mg and mg:FindFirstChild('PanelsModal')
			if m and m.Visible then m.Visible = false end
		end
		task.wait(0.1)
	end
end)
pcall(function()
	local tcs = game:GetService('TextChatService')
	tcs.ChatWindowConfiguration.Enabled = false
	tcs.ChatInputBarConfiguration.Enabled = false
end)
return 'modal + chat hidden'
"""
REWARD = r"""
local UIKit = require(game.Players.LocalPlayer.PlayerScripts:WaitForChild('UIKit'))
_G.__filmReward = UIKit.RewardPopup({ Title = 'Supply road', Lines = { 'Thanks for guarding the supply road!' },
	Rewards = { { Icon = 'IconCoin', Amount = 150 } }, Button = 'Claim!', Faction = 'Halo' })
return _G.__filmReward and 'reward popup' or 'no popup'
"""
REWARD_CLOSE = "local p = _G.__filmReward; if p and p.Close then pcall(p.Close) end; _G.__filmReward = nil; return 'closed'"
MAP_OPEN = "local M = require(game.Players.LocalPlayer.PlayerScripts:WaitForChild('WorldMap')); M.Open(); return 'map open'"
MAP_CLOSE = "local M = require(game.Players.LocalPlayer.PlayerScripts:WaitForChild('WorldMap')); M.Close(); return 'map closed'"
LOG = []


def sheet(name):
    D.subprocess.run([D.FFMPEG, "-hide_banner", "-loglevel", "error", "-y", "-i", os.path.join(D.RAW, name + ".mp4"), "-vf",
                      "fps=1/2,scale=360:-2,tile=6x2", "-frames:v", "1", "build/devlog/check/%s_sheet.png" % name])


def rec(name, sec, cam=None):
    p, out = D.start_rec(name, sec)
    time.sleep(0.5)
    if cam:
        cam()
    p.wait()
    sheet(name)
    LOG.append(name)
    print(out, flush=True)


def tag_nearest(f, kind, near, tag):
    return f.lua("for _,o in workspace.Monsters:GetChildren() do if o:GetAttribute('FilmTag')=='%s' then o:SetAttribute('FilmTag', nil) end end; "
                 "local best,bd; for _,m in workspace.Monsters:GetChildren() do if m:GetAttribute('MonsterKind')=='%s' then local q=m:GetPivot().Position; "
                 "local d=(Vector3.new(q.X,0,q.Z)-Vector3.new(%f,0,%f)).Magnitude; if not bd or d<bd then best,bd=m,d end end end; "
                 "if not best then return '' end; best:SetAttribute('FilmTag','%s'); return tostring(best:GetPivot().Position)" % (tag, kind, near[0], near[1], tag))


def tagged(tag):
    return "(function() for _,o in workspace.Monsters:GetChildren() do if o:GetAttribute('FilmTag')=='%s' then return o end end end)()" % tag


def close_up(f, kind, near, name, r=7, h=2.2, ly=1.4, sec=9):
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
    rec(name, 12, lambda: f.orbit((0, 0, 0), 12, 4.2, -50, 50, 11.2, look_y=4.2, target=KING % kind, front=True))
    return kp


f = D.Film()
try:
    print(f.call("start_stop_play", {"is_start": True}), flush=True)
    for i in range(60):  # the faction picker comes after the opening
        time.sleep(1)
        try:
            if f.lua(PICKER, "Client") == "true":
                break
        except Exception:
            pass
    time.sleep(1.5)
    rec("s40_faction_pick", 6)
    for k, v in (("Faction", "Halo"), ("Class", "Warrior"), ("ClassChosen", True), ("Level", 30), ("PlaytimeSeconds", 1500), ("WeaponTier", 6)):
        f.debug(k, v)
    f.lua("local p=game.Players:GetPlayers()[1]; p:SetAttribute('AutoCombatUnlocked',true); return 'ok'")
    for i in range(10):  # the guide's story window (with the guide portrait) opens after the faction pick
        time.sleep(0.8)
        if f.lua(MODAL, "Client") == "true":
            break
    time.sleep(1.0)
    rec("s40_story_portrait", 8)
    print(f.lua(HIDE_MODAL, "Client"), flush=True)
    time.sleep(1.5)
    D.grab_viewport("build/devlog/check/s40_probe.png")

    # ---------- windows: the reward popup (no rays since cb9d30e) and the world map
    f.teleport((8, 4, -24), (0, 4, 0))
    time.sleep(1.0)
    print(f.lua(REWARD, "Client"), flush=True)
    rec("s40_reward_popup", 6)
    print(f.lua(REWARD_CLOSE, "Client"), flush=True)
    time.sleep(0.8)
    print(f.lua(MAP_OPEN, "Client"), flush=True)
    time.sleep(0.8)
    rec("s40_world_map", 6)
    print(f.lua(MAP_CLOSE, "Client"), flush=True)
    time.sleep(0.8)

    # ---------- HUD off: places
    f.hud(False)
    f.teleport((8, 4, -24), (0, 4, 0))
    time.sleep(1)
    rec("s40_crossroads", 12, lambda: f.orbit((0, 4, 0), 46, 20, -60, 60, 11.4, look_y=6))
    f.teleport((60, 6, -330), (0, 6, -400))
    time.sleep(1.5)
    rec("s40_halo_town", 12, lambda: f.dolly((-30, 26, -250), (30, 16, -330), (0, 10, -420), (0, 12, -450), 11.4))
    f.teleport((60, 6, 330), (0, 6, 400))
    time.sleep(1.5)
    rec("s40_horns_town", 12, lambda: f.dolly((30, 26, 250), (-30, 16, 330), (0, 10, 420), (0, 12, 450), 11.4))

    # ---------- HUD off: monsters, one family per shot
    close_up(f, "Slime", (330, 0), "s40_slime_front")
    close_up(f, "PumpkinSlime", (370, 250), "s40_pumpkin_slime")
    f.teleport((330, 5, 120), (330, 5, 60))
    time.sleep(1.5)
    rec("s40_patch_dolly", 12, lambda: f.dolly((292, 26, 178), (432, 16, 206), (360, 2, 250), (372, 2, 262), 11.2))
    kp = boss(f, "PumpkinKing", "PumpkinKing", "s40_king_front")
    close_up(f, "BatGoblin", (720, 0), "s40_bat_goblin", r=9, h=3.0, ly=3.0)
    close_up(f, "LittleGhost", (220, 240), "s40_little_ghost", r=8, h=2.5, ly=3.0)
    close_up(f, "GhostMinion", (220, 240), "s40_ghost_minion", r=7, h=2.2, ly=2.5)
    f.teleport((150, 6, 200), (220, 6, 240))
    time.sleep(1.5)
    rec("s40_haunted_hollow", 12, lambda: f.dolly((160, 24, 190), (275, 14, 215), (220, 2, 245), (228, 2, 255), 11.2))
    boss(f, "GhostKing", "GhostKing", "s40_ghost_king_front")

    # ---------- HUD on: the fight and the meadow (my character)
    f.hud(True)
    f.lua("local p=game.Players:GetPlayers()[1]; local h=p.Character and p.Character:FindFirstChildOfClass('Humanoid'); if h then h.Health=h.MaxHealth end; return 'hp'")
    kp2 = f.lua("local k=" + KING % "PumpkinKing" + "; return k and tostring(k:GetPivot().Position) or ''") or kp
    if kp2:
        x, y, z = [float(v) for v in kp2.split(",")]
        f.teleport((x - 6, 5, z - 6), (x, 5, z))
        time.sleep(1.0)
        f.lua("local p=game.Players:GetPlayers()[1]; p:SetAttribute('AutoCombatEnabled',true); return 'auto'")
        rec("s40_king_fight", 25, lambda: f.orbit((0, 0, 0), 15, 7.5, -150, -80, 24, look_y=2.5, target="char"))
    f.lua("local p=game.Players:GetPlayers()[1]; p:SetAttribute('AutoCombatEnabled',true); return 'auto'")
    f.teleport((336, 4, -2), (346.8, 4, 12.8))
    time.sleep(1.5)
    rec("s40_meadow_auto", 20, lambda: (f.orbit((0, 0, 0), 17, 8.5, -150, -80, 19, look_y=1.5, target="char"),
                                        f.walk([(345, 4, 9), (350, 4, 18), (362, 4, 26)], speed=12)))

    # ---------- the Pet Tamer (artisan guild Archer) and the baby slime that follows
    f.lua("local p=game.Players:GetPlayers()[1]; p:SetAttribute('AutoCombatEnabled',false); return 'off'")
    f.debug("Faction", "Neutral")
    time.sleep(3)
    f.debug("Class", "Archer")
    f.debug("ClassChosen", True)
    time.sleep(4)
    print("pet:", f.lua("local p=game.Players:GetPlayers()[1]; return tostring(p:GetAttribute('EquippedPet'))"), flush=True)
    f.teleport((300, 4, -20), (330, 4, 0))
    time.sleep(2.5)
    f.lua("local p=game.Players:GetPlayers()[1]; p:SetAttribute('AutoCombatEnabled',true); return 'auto'")
    rec("s40_tamer_pet", 12, lambda: (f.orbit((0, 0, 0), 13, 5.5, -160, -100, 11.4, look_y=1.0, target="char"),
                                      f.walk([(312, 4, -10), (322, 4, -2), (334, 4, 6)], speed=10)))

    # ---------- the Baby Slime model as a still prop (used by short 2 before; kept for the turntable cut)
    f.lua("local p=game.Players:GetPlayers()[1]; p:SetAttribute('AutoCombatEnabled',false); return 'off'")
    f.hud(False)
    f.lua(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "devlog_pet_prop.lua"), encoding="utf-8").read())
    f.teleport((260, 6, -80), (300, 6, -40))
    time.sleep(1)
    rec("s40_pet", 9, lambda: f.orbit((300, 0.5, -40), 3.2, 0.9, -80, 80, 8.4, look_y=0.45, target="workspace:FindFirstChild('FilmPet')", front=True))
finally:
    try:
        f.cam_reset(); f.hud(True)
    except Exception:
        pass
    try:
        print(f.call("start_stop_play", {"is_start": False}), flush=True)
    finally:
        f.close()
        D.minimize_film()
        print("DONE: play stopped, window minimized; shots:", LOG, flush=True)
