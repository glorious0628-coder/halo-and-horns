"""Monster spacing check at the zone edge (A23-74 separation, 게임성 개발 2's dev2-separation3, 검수 10/08: "구역 선 근처
슬라임 무리") in the main Studio, my own test Play with a FRESH in-memory save. A Warrior (DebugCommand Level 20 for the
hit points; this Play only) is set down beside the nearest slimes of Squishy Meadow, lets them see him, walks to the
meadow's west edge (x = Center - Size/2 + 2, where the monsters' move line is 6 studs further in) and stands there. The
server is sampled every 0.5 s for 6 s: the slimes within ChaseR studs, their smallest flat gap / (rA + rB) (1 = bodies
touch; SEP.Overlap 1), how many stand past the move line, and whether they still move. Photos from behind the player.
Not covered here: two players standing together (needs two clients) and the Warrior taunt end (the X skill is Lv25 and
Config.Skills XEnabled is off) - those stay with tools/test_monster_spacing.py.
Usage: py tools/play_separation_check.py pc|phone   Out: docs/art/verification_2026-10-08/separation/<mode>/"""
import json
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import play_sound_check as psc  # noqa: E402
import play_crossroads_check as pcc  # noqa: E402
from studio_mcp import Client  # noqa: E402

MODE = sys.argv[1] if len(sys.argv) > 1 else "pc"
OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-08", "separation", MODE)
LOG = []
psc.OUT, psc.LOG = OUT, LOG
pcc.OUT = OUT
CHASE_R = 18
SAMPLES = 12

SRV_PREP = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local dbg = game:GetService("ServerScriptService"):FindFirstChild("DebugCommand")
local r = dbg and dbg:Invoke(p.Name, "Level", 20) or "no DebugCommand"
local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
if hum then hum.Health = hum.MaxHealth end
return "level: " .. tostring(r) .. " hp " .. tostring(hum and hum.MaxHealth)
"""
# server: the meadow box and the slimes nearest to the meadow's west edge (x small), as JSON
SRV_SLIMES = r"""
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local zone = Config.Zones.SlimeMeadow
local out = { MinX = zone.Center.X - zone.Size.X / 2, MinZ = zone.Center.Z - zone.Size.Z / 2, MaxZ = zone.Center.Z + zone.Size.Z / 2,
	Slimes = {} }
for _, m in workspace:WaitForChild("Monsters"):GetChildren() do
	local kind = m:GetAttribute("MonsterKind")
	local def = kind and Config.Monsters and Config.Monsters[kind]
	local root = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")
	local hum = m:FindFirstChildOfClass("Humanoid")
	if root and def and def.Zone == "SlimeMeadow" and (not hum or hum.Health > 0) then
		table.insert(out.Slimes, { Kind = kind, X = root.Position.X, Z = root.Position.Z, Y = root.Position.Y })
	end
end
table.sort(out.Slimes, function(a, b) return a.X < b.X end)
return game:GetService("HttpService"):JSONEncode(out)
"""
# server: one sample of the slimes near the player: gaps / (rA + rB), past the move line
SRV_SAMPLE = r"""
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local p = game:GetService("Players"):GetPlayers()[1]
local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if not root then return "{}" end
local zone = Config.Zones.SlimeMeadow
local line = zone.Center.X - zone.Size.X / 2 + 6
local R = { Slime = 1.5, Humanoid = 1.25 }
local near = {}
for _, m in workspace.Monsters:GetChildren() do
	local kind = m:GetAttribute("MonsterKind")
	local def = kind and Config.Monsters and Config.Monsters[kind]
	local mr = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")
	local hum = m:FindFirstChildOfClass("Humanoid")
	if mr and def and (not hum or hum.Health > 0) then
		local d = Vector3.new(mr.Position.X - root.Position.X, 0, mr.Position.Z - root.Position.Z).Magnitude
		if d <= %d then
			table.insert(near, { P = mr.Position, R = (R[def.Shape] or 1.25) * (tonumber(def.Scale) or 1), Kind = kind })
		end
	end
end
local minRatio, minPair, past = math.huge, "", 0
for i = 1, #near do
	if near[i].P.X < line - 0.5 then past += 1 end
	for j = i + 1, #near do
		local a, b = near[i], near[j]
		local gap = Vector3.new(a.P.X - b.P.X, 0, a.P.Z - b.P.Z).Magnitude
		local ratio = gap / (a.R + b.R)
		if ratio < minRatio then minRatio, minPair = ratio, a.Kind .. "+" .. b.Kind end
	end
end
local pos = {}
for _, n in near do table.insert(pos, { math.floor(n.P.X * 10) / 10, math.floor(n.P.Z * 10) / 10 }) end
return game:GetService("HttpService"):JSONEncode({ N = #near, MinRatio = minRatio < math.huge and minRatio or -1, Pair = minPair,
	Past = past, Line = line, Me = { root.Position.X, root.Position.Z }, Pos = pos })
"""
# client: set me down at (x, z) on the ground facing (fx, fz) - pcc.STAND; walk to (x, z) - pcc's WALK
# client: the camera for a horizon photo (style drift #18: the fog against the sky), then back to the player
CAM_LOOK = r"""
local cam = workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
cam.CFrame = CFrame.lookAt(Vector3.new(%s, %s, %s), Vector3.new(%s, %s, %s))
return "camera set"
"""
CAM_BACK = r"""
local cam = workspace.CurrentCamera
local p = game:GetService("Players").LocalPlayer
cam.CameraType = Enum.CameraType.Custom
local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
if hum then cam.CameraSubject = hum end
return "camera back"
"""
HORIZON = [("03_horizon_sea", (0, 30, -60), (-900, 10, -600)), ("04_high_view", (80, 160, 120), (900, 0, 600))]


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    os.makedirs(OUT, exist_ok=True)
    psc.restore_studio_window()
    c = Client()
    c.start()
    results, samples = {}, []
    try:
        st = psc.text_of(c.call("get_studio_state", {}))
        if "Current Studio Mode: Edit" not in st:
            sys.exit("not in Edit: " + st)
        if MODE == "phone":
            psc.note("device: " + psc.lua(c, psc.SET_PHONE, "Edit"))
        else:
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
        psc.note(psc.lua(c, pcc.CLOSE, "Client"))
        psc.note(psc.lua(c, SRV_PREP, "Server"))
        info = json.loads(psc.lua(c, SRV_SLIMES, "Server") or "{}")
        slimes = info.get("Slimes", [])
        psc.note(f"meadow minX {info.get('MinX')} slimes {len(slimes)}: " + json.dumps(slimes[:6]))
        if not slimes:
            results["slimes found in the meadow"] = False
            return
        edge_x = info["MinX"] + 2
        first = slimes[0]
        # beside the nearest slimes (west side), facing them, then a few seconds to be seen
        pcc.stand(c, first["X"] - 8, first["Z"], first["X"], first["Z"])
        time.sleep(3)
        psc.save(c, "01_beside_slimes")
        # walk to the west edge (the slimes follow), then stand
        ez = max(info["MinZ"] + 30, min(info["MaxZ"] - 30, first["Z"]))
        psc.note(psc.lua(c, pcc.WALK % (edge_x, ez), "Client"))
        time.sleep(3)
        for _ in range(SAMPLES):
            raw = psc.lua(c, SRV_SAMPLE % CHASE_R, "Server")
            try:
                samples.append(json.loads(raw or "{}"))
            except ValueError:
                psc.note("sample: " + raw[:200])
            time.sleep(0.5)
        psc.save(c, "02_at_the_edge")
        good = [x for x in samples if x.get("N", 0) >= 2]
        psc.note("samples: " + json.dumps([{k: x.get(k) for k in ("N", "MinRatio", "Pair", "Past")} for x in samples]))
        if good:
            worst = min(x["MinRatio"] for x in good)
            results[f"slimes near me at the edge ({max(x['N'] for x in good)} at most)"] = True
            results[f"no two bodies overlap (smallest gap / (rA + rB) = {worst:.2f}, needs >= 0.90)"] = worst >= 0.90
            results["no slime past the move line"] = all(x.get("Past", 0) == 0 for x in good)
            first_pos, last_pos = good[0].get("Pos", []), good[-1].get("Pos", [])
            results["the slimes are not frozen (positions change over 6 s)"] = first_pos != last_pos
        else:
            results["at least two slimes followed me to the edge"] = False
        # the fog against the sky (Config.Sky.Neutral FogColor = the horizon colour, 10/08)
        for name, (cx, cy, cz), (lx, ly, lz) in HORIZON:
            psc.note(psc.lua(c, CAM_LOOK % (cx, cy, cz, lx, ly, lz), "Client"))
            time.sleep(1.0)
            psc.save(c, name)
        psc.note(psc.lua(c, CAM_BACK, "Client"))
        con = psc.text_of(c.call("get_console_output", {}))
        errs = [ln for ln in con.splitlines() if any(k in ln.lower() for k in ("error", "failed", "infinite yield"))
                and "DataStore" not in ln]
        psc.note("console: " + "\n".join(errs[-20:]))
        results["no MonsterService error in the console"] = not any("MonsterService" in ln for ln in errs)
    finally:
        try:
            c.call("start_stop_play", {"is_start": False})
            psc.note("play stopped")
        except Exception as e:  # noqa: BLE001
            psc.note("stop failed " + str(e))
        time.sleep(2)
        psc.note(psc.lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", nil) return "fresh off"', "Edit"))
        psc.note("device: " + psc.lua(c, psc.RESTORE, "Edit"))
        for name, ok in results.items():
            psc.note(("OK   " if ok else "FAIL ") + name)
        with open(os.path.join(OUT, "results.json"), "w", encoding="utf-8") as f:
            json.dump({"results": results, "samples": samples}, f, ensure_ascii=False, indent=1)
        with open(os.path.join(OUT, "log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")
        c.close()


if __name__ == "__main__":
    main()
