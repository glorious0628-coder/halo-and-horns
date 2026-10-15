"""grip3 on the MAIN Studio (메인 반영 1, 2026-10-15; HH_MAIN_STUDIO=1 STUDIO_ID=<id>): 3 classes x 3 sides = 9 combinations,
the real weapon meshes (main 8f4b45db). Per combination: T3 standing side, the attack as 3 shots in a row after the Swing
(+0.12 s, +0.35 s, +0.8 s) and the return (+1.8 s), then T2 standing side. Reuses play_tool_grip_ours (fresh in-memory save,
DebugCommand Level 30 + WeaponOwnedMask 511, Faction / Class switched per kind, own Play, no mouse / keyboard).
Usage: HH_MAIN_STUDIO=1 py tools/play_grip3_main.py   Out: docs/art/verification_2026-10-15/grip3_main/"""
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.argv = [sys.argv[0], "../../verification_2026-10-15/grip3_main"]
sys.path.insert(0, os.path.join(ROOT, "tools"))
import play_tool_grip_ours as g  # noqa: E402

g.KINDS = [(f"{cls}_{fac}", fac, cls) for cls in ("Warrior", "Mage", "Archer") for fac in ("Halo", "Horns", "Neutral")]
if os.environ.get("ONLY"):
    g.KINDS = [k for k in g.KINDS if k[0] in os.environ["ONLY"].split(",")]
lua, note, save = g.lua, g.note, g.save
g.TELE = ('local p = game:GetService("Players"):GetPlayers()[1] local s = workspace.VillageFund.FundSpot_Halo '
          'p.Character:PivotTo(s.CFrame * CFrame.new(0, 3, 14)) return "plaza"')


def kind_shots(c, tag):
    out = {}
    note(lua(c, g.ANCH % ("true", "on"), "Server"))
    time.sleep(1.2)
    note(lua(c, 'local p = game:GetService("Players").LocalPlayer.Character.HumanoidRootPart return "pos " .. tostring(p.Position)', "Client"))
    out["stand3"] = g.shot(c, f"{tag}_T3_stand_side", "side")
    cam = lua(c, g.CAM % "side", "Client")
    note(lua(c, g.FIRE % ("Swing", "", "Swing"), "Client"))
    t0 = time.time()
    for i, at in enumerate((0.12, 0.35, 0.8, 1.8)):
        time.sleep(max(0.0, at - (time.time() - t0)))
        note(f"{tag}_attack{i}: " + lua(c, g.ARMS, "Client"))
        out[f"attack{i}"] = save(c, f"{tag}_attack{i}", cam)
    note(lua(c, g.RESET, "Client"))
    note(lua(c, g.FIRE % ("EquipWeapon", "2", "EquipWeapon"), "Client"))
    time.sleep(3)
    out["stand2"] = g.shot(c, f"{tag}_T2_stand_side", "side")
    note(lua(c, g.RESET, "Client"))
    note(lua(c, g.ANCH % ("false", "off"), "Server"))
    time.sleep(1.0)
    note(lua(c, g.TELE, "Server"))
    time.sleep(0.8)
    return out


g.kind_shots = kind_shots
g.sheet = lambda rows: None
g.main()
