"""Avatar check before a re-shoot (촬영 편집): FilmSet test Play, front / side / in-game photo of my character
(the user's current Roblox avatar, loaded when FilmSet Studio is opened fresh), stop Play, minimize.

  FILM_OK=1 STUDIO_NAME=FilmSet py tools/devlog_step1_front.py     (only after 검수 "전달함, 시작")

Photos: build/devlog/avatar/new_avatar_{front,side,game}.png"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import devlog_film as D

OUT = os.path.join("build", "devlog", "avatar")
os.makedirs(OUT, exist_ok=True)
f = D.Film()
try:
    print(f.call("start_stop_play", {"is_start": True}), flush=True)
    time.sleep(16)
    print(f.lua(r"""
local pg = game.Players.LocalPlayer:WaitForChild('PlayerGui')
task.spawn(function() local t = os.clock() while os.clock() - t < 120 do
  local mg = pg:FindFirstChild('MainGui')
  for _, n in {'PanelsModal', 'FactionPicker', 'ClassPicker'} do local m = mg and mg:FindFirstChild(n); if m and m.Visible then m.Visible = false end end
  task.wait(0.1) end end)
return 'pickers hidden'""", "Client"), flush=True)
    for k, v in (("Faction", "Halo"), ("Class", "Warrior"), ("ClassChosen", True), ("Level", 30), ("PlaytimeSeconds", 1500), ("WeaponTier", 6)):
        f.debug(k, v)
    time.sleep(5)
    x, y, z = 14.0, 3.2, -30.0
    f.teleport((x, y + 2, z), (x, y + 2, z + 10))
    time.sleep(2.5)
    f.hud(False)
    for view, cam in (("front", (x, y + 2.4, z + 8.5)), ("side", (x + 8.5, y + 2.4, z))):
        f.lua(r"""
local RS = game:GetService('RunService'); local cam = workspace.CurrentCamera
_G.__filmTok = (_G.__filmTok or 0) + 1; local tok = _G.__filmTok; local name = 'HHC_Film' .. tok
RS:BindToRenderStep(name, Enum.RenderPriority.Last.Value, function()
  if _G.__filmTok ~= tok then pcall(RS.UnbindFromRenderStep, RS, name); return end
  cam.CameraType = Enum.CameraType.Scriptable; cam.FieldOfView = 40
  cam.CFrame = CFrame.lookAt(Vector3.new(%f, %f, %f), Vector3.new(%f, %f, %f))
end)
return 'cam'""" % (cam[0], cam[1], cam[2], x, y + 1.5, z), "Client")
        time.sleep(1.5)
        print(D.grab_viewport(os.path.join(OUT, "new_avatar_%s.png" % view)), flush=True)
    f.lua("_G.__filmTok = (_G.__filmTok or 0) + 1; local c = workspace.CurrentCamera; c.FieldOfView = 70; c.CameraType = Enum.CameraType.Custom; return 'reset'", "Client")
    f.hud(True)
    time.sleep(1.5)
    print(D.grab_viewport(os.path.join(OUT, "new_avatar_game.png")), flush=True)
finally:
    try:
        f.lua("_G.__filmTok = (_G.__filmTok or 0) + 1; local c = workspace.CurrentCamera; c.FieldOfView = 70; c.CameraType = Enum.CameraType.Custom; return 'reset'", "Client")
    except Exception:
        pass
    try:
        print(f.call("start_stop_play", {"is_start": False}), flush=True)
    finally:
        f.close()
        D.minimize_film()
        print("DONE: play stopped, window minimized", flush=True)
