"""Crossroads 3D check (검수 2026-10-08: the 21 old K_ props -> Tripo, tools/worldkit/crossroads_3d_swap.luau) in the main
Studio. Edit: one shot from above + one from the plaza. Own test Play with a FRESH in-memory save (PC): every prompt
draws G (the 10/08 interact key); the altar prompt (AltarPrompt, held) opens its window; the anvil prompt answers from
the shop distance; the most-wanted board text (Map.Landmarks.MostWantedBoard.BoardGui) sits on the new board face; the
goose nest; walking through the market arch (Humanoid:MoveTo, must come out the other side); the three pads and the
fountain from the plaza. Captures + probes; Play stopped in finally (device stays default).
Usage: py tools/play_crossroads_check.py pc|phone   Out: docs/art/verification_2026-10-08/crossroads_check/<mode>/
(+ the two castles from their town roads; phone = the same shots on the phone simulator, device back to default)"""
import base64
import io
import json
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import play_sound_check as psc  # noqa: E402
from studio_mcp import Client  # noqa: E402

MODE = sys.argv[1] if len(sys.argv) > 1 else "pc"  # pc | phone (749x361, back to default at the end)
OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-08", "crossroads_check", MODE)
LOG = []
psc.OUT, psc.LOG = OUT, LOG

# client: stand on the ground r studs from (tx, tz), facing it: the first of 16 directions whose ground is low (below
# MaxY - not a roof or a stall top, the 10/08 run stood on the guild hall roof); falls back to the first direction
NEAR = r"""
local p = game:GetService("Players").LocalPlayer
local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if not root then return "no root" end
local params = RaycastParams.new()
params.FilterDescendantsInstances = { p.Character }
local tx, tz, r, maxY, start = %s, %s, %s, %s, %s
for i = 0, 15 do
	local a = start + i / 16 * math.pi * 2
	local x, z = tx + math.cos(a) * r, tz + math.sin(a) * r
	local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), params)
	if hit and hit.Position.Y < maxY then
		local y = hit.Position.Y + 3
		root.CFrame = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(tx, y, tz))
		root.AssemblyLinearVelocity = Vector3.zero
		return string.format("near: stood at %%.0f,%%.0f y=%%.1f on %%s (try %%d)", x, z, y, hit.Instance.Name, i + 1)
	end
end
return "near: no low ground"
"""
# client: stand at spot (x, z) on the ground, facing (fx, fz)
STAND = r"""
local p = game:GetService("Players").LocalPlayer
local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if not root then return "no root" end
local params = RaycastParams.new()
params.FilterDescendantsInstances = { p.Character }
local hit = workspace:Raycast(Vector3.new(%s, 200, %s), Vector3.new(0, -400, 0), params)
local y = (hit and hit.Position.Y or 4) + 3
root.CFrame = CFrame.lookAt(Vector3.new(%s, y, %s), Vector3.new(%s, y, %s))
root.AssemblyLinearVelocity = Vector3.zero
return string.format("stand y=%%.1f on %%s", y, hit and hit.Instance.Name or "?")
"""
# client: where things are (prompts + keys, the board gui, the nest, the arch, pads)
FIND = r"""
local HttpService = game:GetService("HttpService")
local out = { Prompts = {}, Board = nil, Nest = nil, Arch = nil, Altar = nil, Anvil = nil, Castles = {} }
for _, d in workspace:GetDescendants() do
	if d:IsA("ProximityPrompt") then
		local part = d.Parent
		local pos = part and (part:IsA("BasePart") and part.Position or (part:IsA("Attachment") and part.WorldPosition)) or nil
		table.insert(out.Prompts, { Name = d.Name, Key = d.KeyboardKeyCode.Name, Enabled = d.Enabled,
			Dist = d.MaxActivationDistance, Hold = d.HoldDuration, Pos = pos and { pos.X, pos.Y, pos.Z } or nil })
		if d.Name == "AltarPrompt" and pos then out.Altar = { pos.X, pos.Y, pos.Z } end
		if d.Name == "HHC_BlacksmithPrompt" and pos then out.Anvil = { pos.X, pos.Y, pos.Z } end
	end
end
local map = workspace:FindFirstChild("Map")
local board = map and map:FindFirstChild("Landmarks") and map.Landmarks:FindFirstChild("MostWantedBoard")
if board then
	local gui = board:FindFirstChild("BoardGui")
	local text = gui and gui:FindFirstChild("BoardText", true)
	out.Board = { Pos = { board.Position.X, board.Position.Y, board.Position.Z }, Look = { board.CFrame.LookVector.X, board.CFrame.LookVector.Z },
		Right = { board.CFrame.RightVector.X, board.CFrame.RightVector.Z },
		Face = gui and gui.Face.Name or "?", Text = text and string.sub(text.Text, 1, 80) or "", Transparency = board.Transparency }
end
local c3 = map and map:FindFirstChild("Decor") and map.Decor:FindFirstChild("Crossroads3D")
for _, m in (c3 and c3:GetChildren() or {}) do
	if m:IsA("Model") and (m.Name == "X_GooseNest" or m.Name == "X_MarketArch") then
		local cf, size = m:GetBoundingBox()
		local e = { Pos = { cf.Position.X, cf.Position.Y, cf.Position.Z }, Size = { size.X, size.Y, size.Z },
			Look = { cf.LookVector.X, cf.LookVector.Z } }
		if m.Name == "X_GooseNest" then out.Nest = e else out.Arch = e end
	end
end
for _, name in { "HaloCastle", "HornsCastle" } do
	local m = map and map:FindFirstChild("Landmarks") and map.Landmarks:FindFirstChild(name)
	if m then
		local cf, size = m:GetBoundingBox()
		out.Castles[name] = { Pos = { cf.Position.X, cf.Position.Y, cf.Position.Z }, Size = { size.X, size.Y, size.Z } }
	end
end
return HttpService:JSONEncode(out)
"""
# server: stream the area around a far target to the player first (StreamingEnabled: far parts are not on the client)
STREAM = r"""
local p = game:GetService("Players"):GetPlayers()[1]
if not p then return "no player" end
local ok, err = pcall(function() p:RequestStreamAroundAsync(Vector3.new(%s, %s, %s), 6) end)
return ok and "streamed around" or ("stream failed " .. tostring(err))
"""
HOLD = r"""
for _, d in workspace:GetDescendants() do
	if d:IsA("ProximityPrompt") and d.Name == "%s" then
		d:InputHoldBegin()
		task.wait(d.HoldDuration + 0.2)
		d:InputHoldEnd()
		return "held " .. d:GetFullName()
	end
end
return "no prompt"
"""
PANEL = r"""
local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
for _, d in pg:GetDescendants() do
	if d.Name == "PanelsModal" and d:IsA("GuiObject") then
		local t = d:FindFirstChild("Title", true)
		return tostring(d.Visible) .. " " .. (t and t.Text or "")
	end
end
return "none"
"""
WALK = r"""
local p = game:GetService("Players").LocalPlayer
local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if not hum or not root then return "no humanoid" end
local goal = Vector3.new(%s, root.Position.Y, %s)
hum:MoveTo(goal)
local t0 = os.clock()
while os.clock() - t0 < 6 and (root.Position - goal).Magnitude > 3 do task.wait(0.1) end
return string.format("walked to %%.0f,%%.0f: left %%.1f studs after %%.1f s", goal.X, goal.Z, (root.Position - goal).Magnitude, os.clock() - t0)
"""
CLOSE = r"""
local ps = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts")
local d = ps:FindFirstChild("Keybinds") and ps.Keybinds:FindFirstChild("Dispatch")
if d then d:Invoke({ KeyCode = Enum.KeyCode.B }) end
return "closed"
"""


def edit_shot(c, name, cam, look):
    res = c.call("screen_capture", {"capture_id": name, "camera_position": cam, "look_at_position": look})
    for part in res.get("content", []):
        if part.get("type") == "image":
            from PIL import Image
            os.makedirs(OUT, exist_ok=True)
            Image.open(io.BytesIO(base64.b64decode(part["data"]))).save(os.path.join(OUT, name + ".png"))
            psc.note("saved " + name)


def near(c, tx, tz, r, max_y=6.0, start=0.785):
    psc.note(psc.lua(c, NEAR % (tx, tz, r, max_y, start), "Client"))


def stand(c, x, z, fx, fz):
    psc.note(psc.lua(c, STAND % (x, z, x, z, fx, fz), "Client"))


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    os.makedirs(OUT, exist_ok=True)
    psc.restore_studio_window()
    c = Client()
    c.start()
    results = {}
    try:
        st = psc.text_of(c.call("get_studio_state", {}))
        if "Current Studio Mode: Edit" not in st:
            sys.exit("not in Edit: " + st)
        if MODE == "phone":
            psc.note("device: " + psc.lua(c, psc.SET_PHONE, "Edit"))
        else:
            edit_shot(c, "00_crossroads_top", [0, 170, 70], [0, 0, 0])
            edit_shot(c, "00_crossroads_plaza", [55, 30, 55], [0, 6, 0])
        if MODE != "phone":
            psc.note("device before Play: " + psc.lua(c, psc.RESTORE, "Edit"))
        psc.note(psc.lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh on"', "Edit"))
        c.call("start_stop_play", {"is_start": True})
        s = psc.wait_state(c, lambda x: "DataLoaded=true" in x, 90, 1.0)
        psc.note("loaded: " + s)
        time.sleep(24)
        psc.note(psc.lua(c, psc.FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
        psc.wait_state(c, lambda x: "Faction=Halo" in x, 20)
        psc.note(psc.lua(c, psc.FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"))
        psc.wait_state(c, lambda x: "ClassChosen=true" in x, 20)
        time.sleep(3)
        psc.note(psc.lua(c, CLOSE, "Client"))
        found = json.loads(psc.lua(c, FIND, "Client") or "{}")
        psc.note("found: " + json.dumps(found, ensure_ascii=False)[:1500])
        keys = sorted({p["Key"] for p in found.get("Prompts", [])})
        results["every prompt draws G"] = keys == ["G"]
        # the altar (G)
        if found.get("Altar"):
            ax, _, az = found["Altar"]
            near(c, ax, az, 8.5)
            time.sleep(1.0)
            psc.save(c, "01_altar")
            psc.note(psc.lua(c, HOLD % "AltarPrompt", "Client"))
            time.sleep(1.2)
            panel = psc.lua(c, PANEL, "Client")
            psc.note("altar panel: " + panel)
            results["the altar prompt opens its window"] = panel.startswith("true")
            psc.save(c, "02_altar_window")
            psc.note(psc.lua(c, CLOSE, "Client"))
        # the anvil from the shop distance
        if found.get("Anvil"):
            nx, _, nz = found["Anvil"]
            near(c, nx, nz, 9.0, start=3.93)  # the anvil's open (north-west) side first
            time.sleep(1.0)
            psc.note(psc.lua(c, HOLD % "HHC_BlacksmithPrompt", "Client"))
            s = psc.wait_state(c, lambda x: "WeaponTier=1" in x, 6, 0.5)
            panel = psc.lua(c, PANEL, "Client")
            psc.note("anvil: " + panel)
            results["the anvil answers from 10 studs (first weapon or the shop)"] = "WeaponTier=1" in s or panel.startswith("true")
            psc.save(c, "03_anvil")
            psc.note(psc.lua(c, CLOSE, "Client"))
        # the most-wanted board text on the new board face
        b = found.get("Board")
        if b:
            bx, by, bz = b["Pos"]
            face = b.get("Face")
            nx_, nz_ = {"Right": b["Right"], "Left": [-b["Right"][0], -b["Right"][1]],
                        "Back": [-b["Look"][0], -b["Look"][1]]}.get(face, b["Look"])
            stand(c, bx + nx_ * 12, bz + nz_ * 12, bx, bz)  # in front of the SurfaceGui face
            time.sleep(1.2)
            psc.save(c, "04_board")
            results["the board has its text"] = len(b.get("Text", "")) > 0
        # the goose nest
        n = found.get("Nest")
        if n:
            near(c, n["Pos"][0], n["Pos"][2], 12.0)
            time.sleep(1.0)
            psc.save(c, "05_nest")
        # walk through the market arch
        a = found.get("Arch")
        if a:
            x, _, z = a["Pos"]
            lx, lz = a["Look"]
            # start on the side whose ground is low (the 10/08 run started on a stall top) and walk to the other
            side = -1
            probe_low = psc.lua(c, NEAR % (x - lx * 12, z - lz * 12, 0.01, 6.0, 0), "Client")
            if "no low ground" in probe_low:
                side = 1
            stand(c, x + side * lx * 12, z + side * lz * 12, x, z)
            time.sleep(1.0)
            psc.save(c, "06_arch_before")
            walk = psc.lua(c, WALK % (x - side * lx * 12, z - side * lz * 12), "Client")
            psc.note(walk)
            results["the market arch can be walked through"] = "left " in walk and float(walk.split("left ")[1].split()[0]) < 3.5
            psc.save(c, "07_arch_after")
        # the plaza: the three pads and the fountain
        stand(c, 30, 30, 0, 0)
        time.sleep(1.2)
        psc.save(c, "08_plaza_fountain")
        # the two castles from their town road (A23-74 3D swap)
        # 검수 10/08: the castle shots came out white (not streamed in) and the Horns one hit "You can't enter the other
        # side's town" -> my own castle from inside my town (this run plays Halo), the other from just outside its gate
        # (map v2 town boxes start at |z| 330), the server streams the castle in first (RequestStreamAroundAsync)
        for name, cs in sorted(found.get("Castles", {}).items()):
            x, y, z = cs["Pos"]
            if name == "HaloCastle":
                sx, sz = x, z + (cs["Size"][2] / 2 + 45) * (1 if z < 0 else -1)
            else:
                sx, sz = x, (318 if z > 0 else -318)
            psc.note(name + ": " + psc.lua(c, STREAM % (x, y, z), "Server"))
            stand(c, sx, sz, x, z)
            time.sleep(3.0)
            psc.save(c, "09_" + name)
        con = psc.text_of(c.call("get_console_output", {}))
        errs = [ln for ln in con.splitlines() if any(k in ln.lower() for k in ("error", "failed", "infinite yield"))
                and "DataStore" not in ln]
        psc.note("console: " + "\n".join(errs[-20:]))
    finally:
        try:
            c.call("start_stop_play", {"is_start": False})
            psc.note("play stopped")
        except Exception as e:  # noqa: BLE001
            psc.note("stop failed " + str(e))
        time.sleep(2)
        psc.note(psc.lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh kept on"', "Edit"))
        psc.note("device: " + psc.lua(c, psc.RESTORE, "Edit"))
        for name, ok in results.items():
            psc.note(("OK   " if ok else "FAIL ") + name)
        with open(os.path.join(OUT, "results.json"), "w", encoding="utf-8") as f:
            json.dump(results, f, ensure_ascii=False, indent=1)
        with open(os.path.join(OUT, "log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")
        c.close()


if __name__ == "__main__":
    main()
