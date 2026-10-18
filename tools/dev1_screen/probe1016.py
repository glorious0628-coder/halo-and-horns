"""Grip probe (grip_check #1 / #5, 10/16): where the fist really is on the 3D weapon mesh, in the engine. MY test Play only.
Per combo: the hand centre / grip attachment / mesh centre in the Handle's frame, the mesh's width profile along its
length (raycasts on a PreciseConvexDecomposition copy -> the guard / wrap / pommel), close-up photos at the hand
(side / front), then the same with the grip point moved to the fist's centre (Config.WeaponGrip monkeypatch if the
command VM shares the game's modules; reported).
Usage: py probe1016.py [--running] [--keep]"""
import json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from h1016 import Client, log, save_log, lua, shot, debug, scene, start_play, pick, stop_play, GAME  # noqa: E402

OUT = os.path.join(GAME, "docs", "art", "verification_2026-10-16", "grip_probe")
os.makedirs(OUT, exist_ok=True)
COMBOS = [("Halo", "Warrior", 1), ("Halo", "Warrior", 3), ("Halo", "Mage", 1), ("Halo", "Archer", 1)]

# the numbers (server: the server built the weapon; the precise copy needs AssetService)
PROBE = r'''
local p = game.Players:GetPlayers()[1]
local ch = p.Character
local tool = ch and ch:FindFirstChild("WeaponModel")
local handle = tool and tool:FindFirstChild("Handle")
local mesh = tool and tool:FindFirstChild("WeaponMesh", true)
local hand = ch and ch:FindFirstChild(tool and tool:GetAttribute("GripHand") or "RightHand")
if not (handle and hand) then return "{\"err\":\"no weapon\"}" end
local att = hand:FindFirstChild("RightGripAttachment")
local H = handle.CFrame
local function rel(v) local r = H:PointToObjectSpace(v) return { math.floor(r.X * 1000) / 1000, math.floor(r.Y * 1000) / 1000, math.floor(r.Z * 1000) / 1000 } end
local out = { kind = tool:GetAttribute("Kind"), handleSize = { handle.Size.X, handle.Size.Y, handle.Size.Z },
	handCentre = rel(hand.Position), handSize = { hand.Size.X, hand.Size.Y, hand.Size.Z },
	attach = att and rel(att.WorldPosition) or nil, attLocal = att and { att.Position.X, att.Position.Y, att.Position.Z } or nil,
	grip = tostring(tool.Grip), centreAttr = tostring(tool:GetAttribute("GripCentre")) }
-- which weld holds the handle
for _, w in ch:GetDescendants() do
	if w:IsA("JointInstance") and w.Part1 == handle and w.Enabled then out.weld = w:GetFullName() .. " C1=" .. tostring(w.C1) end
end
if mesh then
	out.meshId = mesh.MeshId
	out.mesh = { centre = rel(mesh.Position), size = { mesh.Size.X, mesh.Size.Y, mesh.Size.Z }, up = rel(H.Position + mesh.CFrame.UpVector) }
	-- the width profile on a precise copy, in the mesh's own frame (share 0 = bottom .. 1 = top)
	local ok, copy = pcall(function()
		return game:GetService("AssetService"):CreateMeshPartAsync(mesh.MeshId, { CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	end)
	if ok and copy then
		copy.Size, copy.CFrame, copy.Anchored, copy.Transparency, copy.CanCollide = mesh.Size, mesh.CFrame, true, 1, false
		copy.CanQuery = true
		copy.Parent = workspace
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { copy }
		local prof = {}
		local M = mesh.CFrame
		local W = math.max(mesh.Size.X, mesh.Size.Z) + 2
		for i = 0, 39 do
			local s = (i + 0.5) / 40
			local y = (s - 0.5) * mesh.Size.Y
			local a = workspace:Raycast((M * CFrame.new(-W, y, 0)).Position, M.RightVector * (2 * W), rp)
			local b = workspace:Raycast((M * CFrame.new(W, y, 0)).Position, -M.RightVector * (2 * W), rp)
			local wx = (a and b) and (a.Position - b.Position).Magnitude or 0
			table.insert(prof, math.floor(wx * 100) / 100)
		end
		copy:Destroy()
		out.profileX = prof
	else
		out.profileErr = tostring(copy)
	end
end
return game:GetService("HttpService"):JSONEncode(out)
'''
# a close-up camera at the holding hand (render-step binding, workspace attribute Dev1Hand = side / front / back)
CAM = r'''
local RS = game:GetService("RunService")
local cam = workspace.CurrentCamera
pcall(function() RS:UnbindFromRenderStep("Dev1Hand") end)
RS:BindToRenderStep("Dev1Hand", Enum.RenderPriority.Last.Value + 60, function()
	local v = workspace:GetAttribute("Dev1Hand")
	local ch = game.Players.LocalPlayer.Character
	local r = ch and ch:FindFirstChild("HumanoidRootPart")
	local tool = ch and ch:FindFirstChild("WeaponModel")
	local hand = ch and ch:FindFirstChild(tool and tool:GetAttribute("GripHand") or "RightHand")
	if not v or v == "" or not r or not hand then return end
	local flat = CFrame.lookAt(r.Position, r.Position + (r.CFrame.LookVector * Vector3.new(1, 0, 1)))
	local dir = ({ side = Vector3.new(1, 0, 0), front = Vector3.new(0, 0, -1), back = Vector3.new(0, 0, 1) })[v] or Vector3.new(1, 0, 0)
	if tool and tool:GetAttribute("GripHand") == "LeftHand" and v == "side" then dir = Vector3.new(-1, 0, 0) end
	local at = hand.Position
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 40
	cam.CFrame = CFrame.lookAt(at + flat:VectorToWorldSpace(dir) * 4 + Vector3.new(0, 0.3, 0), at)
end)
return "hand cam on"
'''
CAM_OFF = r'''
pcall(function() game:GetService("RunService"):UnbindFromRenderStep("Dev1Hand") end)
workspace:SetAttribute("Dev1Hand", nil)
workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
workspace.CurrentCamera.FieldOfView = 70
return "off"
'''
# does the command VM share the game's modules? (SceneSetup flips Config.Features on the server)
SAME_VM = r'''
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
Config.__dev1probe = (Config.__dev1probe or 0) + 1
return tostring(Config.Features.Crafting) .. " probe=" .. tostring(Config.__dev1probe)
'''
# the fist-centre grip on the CLIENT (WeaponPose writes the weld every frame from Config.WeaponGrip): monkeypatch
PATCH = r'''
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
if not Config.__dev1old then Config.__dev1old = Config.WeaponGrip end
local old = Config.__dev1old
local on = %s
Config.WeaponGrip = function(kind, len, mode, centre)
	local g = old(kind, len, mode)
	if on then
		local ch = game.Players.LocalPlayer.Character
		local hand = ch and ch:FindFirstChild("RightHand")
		local att = hand and hand:FindFirstChild("RightGripAttachment")
		if att then g = g * CFrame.new(-att.CFrame:PointToObjectSpace(Vector3.zero)) end
	end
	return g
end
return "patched " .. tostring(on)
'''


def photos(c, tag):
    for v in ("side", "front", "back"):
        lua(c, 'workspace:SetAttribute("Dev1Hand", %s) return ""' % json.dumps(v), "Client")
        time.sleep(0.4)
        shot(c, os.path.join(OUT, f"{tag}_{v}.png"))
    lua(c, 'workspace:SetAttribute("Dev1Hand", nil) return ""', "Client")


def main():
    c = Client()
    c.start()
    if "--running" not in sys.argv:
        start_play(c)
        log("pick:", pick(c, "Halo", "Warrior"))
        time.sleep(2)
        lua(c, 'for _, g in game.Players.LocalPlayer.PlayerGui:GetDescendants() do if g:IsA("GuiButton") and g.Name == "Close" and g.Visible then end end return ""', "Client")
    res = {}
    try:
        log(lua(c, CAM, "Client"))
        for side, cls, t in COMBOS:
            tag = f"{side}_{cls}_T{t}"
            log("==", tag, scene(c, {"Faction": side, "Class": cls, "Level": 30, "Tutorial": "Done", "Done": ["M1_1", "M1_3", "M1_4"],
                                     "At": "Landmark:Fountain"}))
            debug(c, "WeaponOwnedMask", 7)
            debug(c, "WeaponTier", t)
            time.sleep(3.0)
            raw = lua(c, PROBE, "Server")
            try:
                res[tag] = json.loads(raw)
            except Exception:  # noqa: BLE001
                res[tag] = {"raw": raw[:500]}
            log(" ", json.dumps(res[tag])[:900])
            photos(c, tag + ("_fix" if "--fix" in sys.argv else "_now"))
        if "--no-patch" in sys.argv:
            return
        log("same VM? server:", lua(c, SAME_VM, "Server"), "client:", lua(c, SAME_VM, "Client"), lua(c, SAME_VM, "Client"))
        # the fist-centre grip on the client for the swords and the staff (photos only; the server's Tool.Grip stays)
        log(lua(c, PATCH % "true", "Client"))
        for side, cls, t in COMBOS:
            tag = f"{side}_{cls}_T{t}"
            scene(c, {"Faction": side, "Class": cls, "Level": 30, "At": "Landmark:Fountain"})
            debug(c, "WeaponTier", t)
            time.sleep(3.0)
            log(" centre weld:", lua(c, 'local ch = game.Players.LocalPlayer.Character local h = ch.RightHand local w = h:FindFirstChild("RightGrip") return tostring(w and w.C1)', "Client"))
            photos(c, tag + "_centre")
        log(lua(c, PATCH % "false", "Client"))
    finally:
        try:
            log(lua(c, CAM_OFF, "Client"))
        except Exception:  # noqa: BLE001
            pass
        with open(os.path.join(OUT, "probe_fix.json" if "--fix" in sys.argv else "probe.json"), "w", encoding="utf-8") as f:
            json.dump(res, f, ensure_ascii=False, indent=1)
        if "--keep" not in sys.argv:
            stop_play(c)
        save_log(os.path.join(OUT, "probe_log.txt"))


main()
