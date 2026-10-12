"""Goblin woods chase check (main Studio, own test Play, FRESH in-memory save via ServerStorage StudioFreshSave; the
tester's real save is not touched): after the woods kit (tools/worldkit/woods_kit_place.luau) a goblin must still reach
the player round the tree trunks. Each trial picks a living Goblin / Goblin Brute in the woods, the nearest trunk post
5-22 studs from it, and stands the player (invisible ForceField, huge health) just behind that trunk, so the trunk is in
the straight line; then it follows the monster for up to 14 s: reached (within 7 studs) and when, or not (closest).
Usage: py tools/play_woods_chase.py [tag]   (Play stops at the end). Own test Play only: ask 검수 first (it starts /
stops Play in the main Studio)."""
import base64
import io
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402

TAG = sys.argv[1] if len(sys.argv) > 1 else "pc"
OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-08", "woods_chase")
LOG = []
TRIALS = ["Goblin", "Goblin", "Goblin", "GoblinBrute", "GoblinBrute"]
REACH = 7
FOLLOW_S = 14

READY = r'''
local p = game:GetService("Players"):GetPlayers()[1]
return p and p:GetAttribute("DataLoaded") == true and p.Character and "ready" or "wait"
'''
FIRE = r"""
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
R:WaitForChild("%s"):FireServer(%s)
return "fired %s"
"""
GO_WOODS = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local ch = p.Character
if not ch:FindFirstChildOfClass("ForceField") then
	local ff = Instance.new("ForceField")
	ff.Visible = false
	ff.Parent = ch
end
local hum = ch:FindFirstChildOfClass("Humanoid")
hum.MaxHealth, hum.Health = 1e6, 1e6
ch:PivotTo(CFrame.new(900, 5, 60))
local n = {}
for _, m in workspace.Monsters:GetChildren() do
	local k = m:GetAttribute("MonsterKind")
	if k then n[k] = (n[k] or 0) + 1 end
end
local s = {}
for k, v in n do table.insert(s, k .. "=" .. v) end
return "in the woods; monsters " .. table.concat(s, " ")
'''
PICK = r'''
local KIND = "%s"
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local p = game:GetService("Players"):GetPlayers()[1]
local ch = p.Character
local hum = ch:FindFirstChildOfClass("Humanoid")
hum.MaxHealth, hum.Health = 1e6, 1e6
local wk = workspace.Map.Decor:FindFirstChild("WoodsKit")
if not wk then return "ERR no WoodsKit" end
local posts = {}
for _, m in wk:GetChildren() do
	local post = m:FindFirstChild("TrunkPost")
	if post then table.insert(posts, post) end
end
local gp = RaycastParams.new()
gp.FilterType = Enum.RaycastFilterType.Include
gp.FilterDescendantsInstances = { workspace.Terrain, workspace.Map:FindFirstChild("Ground") }
gp.IgnoreWater = false
local bp = RaycastParams.new()
bp.FilterType = Enum.RaycastFilterType.Include
bp.FilterDescendantsInstances = { workspace.Map.Decor, workspace.Map:FindFirstChild("Landmarks") }
bp.RespectCanCollide = true
local zone = Config.Zones.GoblinWoods
local function flat(a, b) return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude end
local function inZone(q, inset)
	return math.abs(q.X - zone.Center.X) <= zone.Size.X / 2 - inset and math.abs(q.Z - zone.Center.Z) <= zone.Size.Z / 2 - inset
end
local function ground(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), gp)
	if not hit or hit.Material == Enum.Material.Water or hit.Position.Y < -0.8 or hit.Position.Y > 6 then return nil end
	return hit.Position.Y
end
for _, m in workspace.Monsters:GetChildren() do m:SetAttribute("TestChase", nil) end
for _, m in workspace.Monsters:GetChildren() do
	local h = m:FindFirstChildOfClass("Humanoid")
	local r = m:FindFirstChild("HumanoidRootPart")
	if m:GetAttribute("MonsterKind") == KIND and m:GetAttribute("Golden") ~= true and not m:GetAttribute("TestChaseDone")
		and h and r and h.Health > 0 and inZone(r.Position, 20) then
		local g = r.Position
		local best
		for _, post in posts do
			local d = flat(post.Position, g)
			if d > 5 and d < 22 and (not best or d < best.D) then best = { Post = post, D = d } end
		end
		if best then
			local t = best.Post.Position
			local dir = Vector3.new(t.X - g.X, 0, t.Z - g.Z).Unit
			local at = Vector3.new(t.X, 0, t.Z) + dir * (best.Post.Size.Y / 2 + 8)
			local y = ground(at.X, at.Z)
			if y and inZone(at, 10) and not workspace:Raycast(Vector3.new(at.X, y + 40, at.Z), Vector3.new(0, -39.5, 0), bp) then
				m:SetAttribute("TestChaseDone", true)
				m:SetAttribute("TestChase", true)
				ch:PivotTo(CFrame.lookAt(Vector3.new(at.X, y + 4, at.Z), Vector3.new(g.X, y + 4, g.Z)))
				return string.format("trial %%s %%s from (%%.0f,%%.0f) to (%%.0f,%%.0f), trunk (%%.0f,%%.0f) d %%.1f, start %%.1f", KIND, m.Name,
					g.X, g.Z, at.X, at.Z, t.X, t.Z, best.Post.Size.Y, flat(g, at))
			end
		end
	end
end
return "none"
'''
STEP = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
for _, m in workspace.Monsters:GetChildren() do
	if m:GetAttribute("TestChase") then
		local r = m:FindFirstChild("HumanoidRootPart")
		local h = m:FindFirstChildOfClass("Humanoid")
		if not (r and h and h.Health > 0) then return "dead" end
		local d = Vector2.new(r.Position.X - root.Position.X, r.Position.Z - root.Position.Z).Magnitude
		return string.format("%.1f %.1f %.1f", d, r.Position.X, r.Position.Z)
	end
end
return "gone"
'''


def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))


def lua(c, code, dm):
    try:
        return text_of(c.call("execute_luau", {"code": code, "datamodel_type": dm}))
    except Exception as e:  # noqa: BLE001
        return "ERR " + str(e)[:200]


def note(msg):
    print(msg, flush=True)
    LOG.append(msg)


def save(c, name):
    res = c.call("screen_capture", {"capture_id": name})
    for part in res.get("content", []):
        if part.get("type") == "image":
            from PIL import Image
            os.makedirs(OUT, exist_ok=True)
            path = os.path.join(OUT, f"{TAG}_{name}.png")
            Image.open(io.BytesIO(base64.b64decode(part["data"]))).convert("RGB").save(path)
            note("saved " + path)
            return
    note("capture failed " + name)


def follow(c, idx):
    t0 = time.time()
    closest, path, shot = 1e9, [], False
    while time.time() - t0 < FOLLOW_S:
        s = lua(c, STEP, "Server")
        if s in ("dead", "gone") or s.startswith("ERR"):
            return f"monster {s} after {time.time() - t0:.1f}s", path
        d, x, z = (float(v) for v in s.split())
        path.append((round(time.time() - t0, 1), d))
        closest = min(closest, d)
        if not shot and time.time() - t0 > 2.0:
            save(c, f"trial{idx}_2s")
            shot = True
        if d <= REACH:
            return f"REACHED in {time.time() - t0:.1f}s", path
        time.sleep(0.5)
    return f"NOT reached in {FOLLOW_S}s (closest {closest:.1f})", path


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    c = Client()
    c.start()
    results = []
    try:
        st = text_of(c.call("get_studio_state", {}))
        if "Current Studio Mode: Edit" not in st:
            sys.exit("not in Edit: " + st)
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh on"', "Edit"))
        c.call("start_stop_play", {"is_start": True})
        t0 = time.time()
        while time.time() - t0 < 90 and lua(c, READY, "Server") != "ready":
            time.sleep(2)
        time.sleep(26)  # the first-time opening
        note(lua(c, FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
        time.sleep(2)
        note(lua(c, FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"))
        time.sleep(3)
        note(lua(c, GO_WOODS, "Server"))
        time.sleep(10)  # woods monsters gather round a starved player
        for i, kind in enumerate(TRIALS, 1):
            pick = lua(c, PICK % kind, "Server")
            note(f"[{i}] {pick}")
            if not pick.startswith("trial"):
                results.append(f"[{i}] {kind}: {pick}")
                continue
            time.sleep(0.3)
            verdict, path = follow(c, i)
            note(f"[{i}] {verdict} | " + " ".join(f"{t}s:{d:.0f}" for t, d in path[::2]))
            results.append(f"[{i}] {kind}: {verdict}")
            time.sleep(1.5)
        con = text_of(c.call("get_console_output", {}))
        errs = [ln for ln in con.splitlines() if any(k in ln.lower() for k in ("error", "failed", "infinite yield"))]
        note("console: " + "\n".join(errs[-20:]))
    finally:
        try:
            c.call("start_stop_play", {"is_start": False})
            note("play stopped")
        except Exception as e:  # noqa: BLE001
            note("stop failed " + str(e))
        time.sleep(2)
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh kept on"', "Edit"))
        note("RESULT\n" + "\n".join(results))
        os.makedirs(OUT, exist_ok=True)
        with open(os.path.join(OUT, f"{TAG}_log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")
        c.close()


main()
