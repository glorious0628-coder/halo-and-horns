"""(tools/play_classic_sword_grip.py) A23-150 #7 reference (게임성 개발 1, 2026-10-12): Roblox's own sword gear, measured.
Main Studio test Play (메인 반영 1, own Play): the server loads Roblox's sword gear (InsertService:LoadAsset, ids tried
in order - the first that loads wins), logs its Tool.Grip (position + GripForward / GripRight / GripUp), its Handle's
size and mesh, then gives it to the user's avatar: front / side / 3/4 standing + side mid-slash photos. Nothing is
saved into the place (Play only).
Usage: HH_MAIN_STUDIO=1 py tools/play_classic_sword_grip.py [outdir-name]
Out: docs/art/verification_2026-10-12/main_apply/<outdir>/ (default classic_sword) + log.txt"""
import base64
import io
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402
from PIL import Image  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-12", "main_apply", sys.argv[1] if len(sys.argv) > 1 else "classic_sword")
os.makedirs(OUT, exist_ok=True)
LOG = []
IDS = [47433, 125013769]  # ClassicSword, Linked Sword (Roblox gear)


def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))


def lua(c, code, dm):
    try:
        return text_of(c.call("execute_luau", {"code": code, "datamodel_type": dm}))
    except Exception as e:  # noqa: BLE001
        return "ERR " + str(e)[:200]


def note(m):
    print(m, flush=True)
    LOG.append(m)


def save(c, name, cam=None):
    args = {"capture_id": name}
    if cam and "|" in cam:
        a, b = cam.strip().split("|")
        args["camera_position"] = [float(v) for v in a.split(",")]
        args["look_at_position"] = [float(v) for v in b.split(",")]
    res = c.call("screen_capture", args)
    for part in res.get("content", []):
        if part.get("type") == "image":
            Image.open(io.BytesIO(base64.b64decode(part["data"]))).convert("RGB").save(os.path.join(OUT, name + ".png"))
            note("saved " + name)
            return
    note("capture failed " + name)


STATE = r"""
local p = game:GetService("Players"):GetPlayers()[1]
if not p then return "no player" end
local out = {}
for _, k in { "DataLoaded", "Faction", "Class", "ClassChosen", "Level", "WeaponTier" } do table.insert(out, k .. "=" .. tostring(p:GetAttribute(k))) end
return table.concat(out, " ")
"""
FIRE = r"""
game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("%s"):FireServer(%s)
return "fired %s"
"""
LOAD = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local ch = p.Character
local hum = ch and ch:FindFirstChildOfClass("Humanoid")
if not hum then return "no humanoid" end
local wm = ch:FindFirstChild("WeaponModel")
if wm then wm.Parent = game:GetService("ServerStorage") end -- our weapon off (WeaponPose lets go)
local out = {}
for _, id in { %s } do
	local ok, model = pcall(function() return game:GetService("InsertService"):LoadAsset(id) end)
	if ok and model then
		local tool = model:FindFirstChildWhichIsA("Tool", true)
		if tool then
			local g = tool.Grip
			local h = tool:FindFirstChild("Handle")
			local mesh = h and h:FindFirstChildWhichIsA("DataModelMesh")
			table.insert(out, string.format("id %d '%s' Grip pos=(%.3f,%.3f,%.3f) GripForward=(%.2f,%.2f,%.2f) GripRight=(%.2f,%.2f,%.2f) GripUp=(%.2f,%.2f,%.2f)",
				id, tool.Name, g.Position.X, g.Position.Y, g.Position.Z, tool.GripForward.X, tool.GripForward.Y, tool.GripForward.Z,
				tool.GripRight.X, tool.GripRight.Y, tool.GripRight.Z, tool.GripUp.X, tool.GripUp.Y, tool.GripUp.Z))
			if h then
				table.insert(out, string.format("  Handle %s size=(%.2f,%.2f,%.2f) mesh=%s scale=%s", h.ClassName, h.Size.X, h.Size.Y, h.Size.Z,
					mesh and mesh.ClassName or "none", mesh and tostring(mesh.Scale) or "-"))
			end
			for _, s in tool:GetDescendants() do
				if s:IsA("LuaSourceContainer") then s.Disabled = true end -- its own scripts off: only the hold is looked at
			end
			tool.Name = "RobloxSword"
			tool.Parent = p:FindFirstChildOfClass("Backpack") or ch
			hum:EquipTool(tool)
			table.insert(out, "  equipped")
			return table.concat(out, "\n")
		end
		table.insert(out, "id " .. id .. ": no Tool inside")
	else
		table.insert(out, "id " .. id .. ": load failed " .. tostring(model))
	end
end
return table.concat(out, "\n")
"""
SLASH = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local tool = p.Character and p.Character:FindFirstChild("RobloxSword")
if not tool then return "no tool" end
local v = Instance.new("StringValue")
v.Name = "toolanim"
v.Value = "Slash"
v.Parent = tool
return "slash asked"
"""
CAM = r"""
local p = game:GetService("Players").LocalPlayer
local ch = p.Character
local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
if not hrp then return "no char" end
for _, g in p:FindFirstChildOfClass("PlayerGui"):GetChildren() do
	if g:IsA("ScreenGui") then g.Enabled = false end
end
local cam = workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
cam.FieldOfView = 40
local mode = "%s"
local f, r = hrp.CFrame.LookVector, hrp.CFrame.RightVector
local dir = mode == "side" and r or (mode == "quarter" and (f + r).Unit or f)
local target = hrp.Position + Vector3.new(0, 0.6, 0)
local camPos = target + dir * 11 + Vector3.new(0, 0.6, 0)
cam.CFrame = CFrame.lookAt(camPos, target)
return string.format("%%f,%%f,%%f|%%f,%%f,%%f", camPos.X, camPos.Y, camPos.Z, target.X, target.Y, target.Z)
"""
ARMS = r"""
local ch = game:GetService("Players").LocalPlayer.Character
local ut = ch and ch:FindFirstChild("UpperTorso")
local hand = ch and ch:FindFirstChild("RightHand")
local tool = ch and ch:FindFirstChildOfClass("Tool")
local h = tool and tool:FindFirstChild("Handle")
if not (ut and hand) then return "no body" end
local r = ut.CFrame:PointToObjectSpace(hand.Position)
local s = string.format("RightHand@torso=(%.2f,%.2f,%.2f)", r.X, r.Y, r.Z)
if h then
	local up, look = ut.CFrame:VectorToObjectSpace(h.CFrame.UpVector), ut.CFrame:VectorToObjectSpace(h.CFrame.LookVector)
	s ..= string.format(" handleUp@torso=(%.2f,%.2f,%.2f) handleLook@torso=(%.2f,%.2f,%.2f)", up.X, up.Y, up.Z, look.X, look.Y, look.Z)
end
return s
"""
ANCH = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if hrp then hrp.Anchored = %s end
return "anchored %s"
"""
TELE = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local ch = p.Character
if not ch then return "no char" end
ch:PivotTo(CFrame.new(0, 5, -25))
return "spot"
"""


def wait_state(c, cond, timeout, every=1.0):
    t0, last = time.time(), ""
    while time.time() - t0 < timeout:
        last = lua(c, STATE, "Server")
        if cond(last):
            return last
        time.sleep(every)
    return last


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    c = Client()
    c.start()
    try:
        st = text_of(c.call("get_studio_state", {}))
        if "Current Studio Mode: Edit" not in st:
            sys.exit("not in Edit: " + st)
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh on"', "Edit"))
        c.call("start_stop_play", {"is_start": True})
        note("loaded: " + wait_state(c, lambda x: "DataLoaded=true" in x, 90, 2.0))
        time.sleep(26)
        note(lua(c, FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
        wait_state(c, lambda x: "Faction=Halo" in x, 20)
        note(lua(c, FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"))
        note("chosen: " + wait_state(c, lambda x: "ClassChosen=true" in x, 20))
        note(lua(c, FIRE % ("AcceptTutorial", "", "AcceptTutorial"), "Client"))
        time.sleep(2)
        note(lua(c, TELE, "Server"))
        time.sleep(1)
        note("load:\n" + lua(c, LOAD % ", ".join(str(i) for i in IDS), "Server"))
        time.sleep(2.5)
        note(lua(c, ANCH % ("true", "on"), "Server"))
        time.sleep(1.2)
        for m in ("front", "side", "quarter"):
            cam = lua(c, CAM % m, "Client")
            time.sleep(1.0)
            note(f"{m}: " + lua(c, ARMS, "Client"))
            save(c, f"classic_{m}", cam)
        cam = lua(c, CAM % "side", "Client")
        note(lua(c, SLASH, "Server"))
        time.sleep(0.18)
        note("slash: " + lua(c, ARMS, "Client"))
        save(c, "classic_slash", cam)
        note(lua(c, ANCH % ("false", "off"), "Server"))
    finally:
        try:
            c.call("start_stop_play", {"is_start": False})
            note("play stopped")
        except Exception as e:  # noqa: BLE001
            note("stop failed " + str(e))
        time.sleep(2)
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", nil) return "fresh off"', "Edit"))
        with open(os.path.join(OUT, "log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")


if __name__ == "__main__":
    main()
