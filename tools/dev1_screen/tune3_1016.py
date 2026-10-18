"""Round 3 (A23-223 + the bow's side tilt + the mage clips in the engine). MY test Play only, branch dev1-hold-angles synced.
1. stow places: candidates for the back / the hip measured (weapon parts overlapping the body), the best photographed
   stowed, then drawn by an attack (within HandSeconds), then stowed again after it (weld state read)
2. the bow plan A in the hand: the left shoulder / wrist side turns for the top end 5..15 out (stow off while tuning)
3. the mage clips as committed: one F and one Q per side measured over the whole clip + a side strip
Usage: py tune3_1016.py [--running] [--keep]"""
import itertools, json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from h1016 import Client, log, save_log, lua, key, shot, debug, scene, start_play, pick, stop_play, close, GAME  # noqa: E402
import tune1016 as T1  # noqa: E402
import tune2_1016 as T2  # noqa: E402

OUT = os.path.join(GAME, "docs", "art", "verification_2026-10-16", "hold_tune3")
os.makedirs(OUT, exist_ok=True)
T1.OUT = OUT

# the stowed weapon: its parts overlapping the body (frames over secs), the stow weld on?
STOWM = r'''
local secs = %s
local RS = game:GetService("RunService")
local ch = game.Players.LocalPlayer.Character
local tool = ch:FindFirstChild("WeaponModel")
local handle = tool and tool:FindFirstChild("Handle")
if not handle then return "{\"err\":\"no weapon\"}" end
local body = {}
for _, n in { "Head", "UpperTorso", "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
	"LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm" } do local p = ch:FindFirstChild(n) if p then table.insert(body, p) end end
local op = OverlapParams.new()
op.FilterType = Enum.RaycastFilterType.Include
op.FilterDescendantsInstances = body
local mesh = tool:FindFirstChild("WeaponMesh", true) or handle
local acc, n = {}, 0
local conn
conn = RS.Heartbeat:Connect(function()
	n += 1
	for _, p in workspace:GetPartsInPart(mesh, op) do acc[p.Name] = (acc[p.Name] or 0) + 1 end
end)
task.wait(secs)
conn:Disconnect()
local w = handle:FindFirstChild("StowWeld")
local root = ch.HumanoidRootPart
local d = root.CFrame:VectorToObjectSpace(mesh.CFrame.UpVector)
return game:GetService("HttpService"):JSONEncode({ frames = n, hits = next(acc) and acc or { none = 0 }, stowed = w ~= nil and w.Enabled,
	up = { math.floor(d.X * 100) / 100, math.floor(d.Y * 100) / 100, math.floor(d.Z * 100) / 100 } })
'''


def stowm(c, secs=0.4):
    raw = lua(c, STOWM % secs, "Client")
    try:
        return json.loads(raw)
    except Exception:  # noqa: BLE001
        return {"raw": raw[:200]}


def hits_of(r):
    h = r.get("hits")
    return sum(v for k, v in h.items() if k != "none") if isinstance(h, dict) else 999


BACK = [{"Part": "UpperTorso", "Pos": [x, y, z], "Turn": [0, ry, rz]}
        for x, y, z, ry, rz in itertools.product((0,), (0, 0.3), (1.3, 1.7), (0, 90, 180, -90), (-30, -40))]
HIP = [{"Part": "LowerTorso", "Pos": [x, -0.2, z], "Turn": [rx, 0, rz]}
       for x, z, rx, rz in itertools.product((-1.15, -1.4), (-0.35, 0), (115, 130), (-8, -20))]


def stow_round(c, side, cls, tier, where, cands, res):
    T1.setup(c, side, cls, tier)
    rows = []
    for row in cands:
        T1.tune(c, {"WeaponStow": {where: row}})
        time.sleep(0.5)
        r = stowm(c)
        rows.append({"row": row, "m": r, "hits": hits_of(r)})
    rows.sort(key=lambda e: e["hits"])
    for e in rows[:3]:
        log("stow", side, cls, where, json.dumps(e))
    best = rows[0]["row"]
    T1.tune(c, {"WeaponStow": {where: best}})
    time.sleep(0.6)
    tag = f"{side}_{cls}_T{tier}"
    T1.photos(c, tag + "_stowed")
    res[tag] = {"rows": rows[:5], "best": best}
    # drawn by an attack, then back after HandSeconds
    scene(c, {"Monsters": [{"Kind": "Slime", "N": 1, "Dist": 8, "Anchor": True}]})
    time.sleep(0.8)
    lua(c, T2.FACE, "Server")
    key(c, "F")
    time.sleep(0.9)
    res[tag]["afterAttack"] = stowm(c, 0.2)
    T1.photos(c, tag + "_drawn")
    time.sleep(5.5)
    res[tag]["after6s"] = stowm(c, 0.2)
    log(" ", tag, "after attack", json.dumps(res[tag]["afterAttack"]), "| 6 s later", json.dumps(res[tag]["after6s"]))
    return best


def main():
    c = Client()
    c.start()
    if "--running" not in sys.argv:
        start_play(c)
        log("pick:", pick(c, "Halo", "Archer"))
    res = {"stow": {}, "bow": [], "mage": {}}
    try:
        log(lua(c, T1.CAM, "Client"))
        log("clock:", lua(c, 'return tostring(game.ServerScriptService.DebugCommand:Invoke("", "Clock", 13))', "Server"))
        # 1. stow places
        back = stow_round(c, "Halo", "Archer", 1, "Back", BACK, res["stow"])
        hip = stow_round(c, "Halo", "Warrior", 1, "Hip", HIP, res["stow"])
        res["stowBest"] = {"Back": back, "Hip": hip}
        for side, cls, tier, where, row in (("Horns", "Archer", 2, "Back", back), ("Horns", "Warrior", 2, "Hip", hip)):
            T1.setup(c, side, cls, tier)
            T1.tune(c, {"WeaponStow": {where: row}})
            time.sleep(0.6)
            res["stow"][f"{side}_{cls}_T{tier}"] = stowm(c)
            T1.photos(c, f"{side}_{cls}_T{tier}_stowed")
        # 2. the bow plan A: the side turns (stow off while tuning)
        T1.setup(c, "Halo", "Archer", 1)
        a2 = {"LeftShoulder": [-10, 0, -14], "LeftElbow": [70, 0, 0], "RightShoulder": [30, 0, -18], "RightElbow": [70, 0, 0]}
        for shz, wz in itertools.product((-14, -24, -34), (-25, -12, 0, 12, 25)):
            stand = dict(a2, LeftShoulder=[-10, 0, shz], LeftWrist=[0, 0, wz])
            row = {"Arm": "Left", "Stand": stand, "Walk": stand, "Run": {"LeftShoulder": [0, 0, -4], "LeftElbow": [8, 0, 0]},
                   "Air": {"LeftElbow": [10, 0, 0]}, "Damp": {"Stand": 0.85, "Walk": 0.95, "Run": 0.95, "Air": 0.97, "Lower": 0.98, "Free": 0.85}}
            payload = {"WeaponStow": {"On": False}, "HoldPoses": {"Bow": row},
                       "WeaponGrips": {k: {"Rest": [-45, -90, -45]} for k in ("Bow", "ShortBow")}}
            T1.tune(c, payload)
            time.sleep(0.45)
            r = T1.m(c, 0.3)
            sc = T2.score_bow(r) if "tilt" in r else 999
            res["bow"].append({"key": {"shz": shz, "wz": wz}, "m": r, "score": sc, "payload": payload})
        res["bow"].sort(key=lambda e: e["score"])
        for e in res["bow"][:3]:
            log("bow A3:", json.dumps({k: v for k, v in e.items() if k != "payload"}))
        T1.tune(c, res["bow"][0]["payload"])
        time.sleep(0.6)
        T1.photos(c, "Halo_Archer_T1_A3")
        T1.tune(c, None)
        # 3. the mage clips as committed (no Dev1Clips)
        for side, name, k in (("Halo", "LightMageSwing", "F"), ("Halo", "LightMageRelease", "Q"), ("Horns", "MageSwing", "F"), ("Horns", "DarkMageRelease", "Q")):
            T1.setup(c, side, "Mage", 1)
            debug(c, "Mana", 999)
            scene(c, {"Monsters": [{"Kind": "Slime", "N": 1, "Dist": 8, "Anchor": True}]})
            time.sleep(1.0)
            r = T2.attack_measure(c, k)
            res["mage"][name] = r
            log("mage", name, json.dumps(r))
            lua(c, 'workspace:SetAttribute("Dev1Cam2", "side") return ""', "Client")
            lua(c, T2.FACE, "Server")
            time.sleep(0.5)
            debug(c, "Mana", 999)
            key(c, k)
            for i in range(5):
                shot(c, os.path.join(OUT, f"{side}_{name}_strip{i}.png"))
            lua(c, 'workspace:SetAttribute("Dev1Cam2", nil) return ""', "Client")
            time.sleep(0.6)
    finally:
        try:
            log(lua(c, 'workspace:SetAttribute("Dev1Clips", nil) ' + T1.CAM_OFF, "Client"))
        except Exception:  # noqa: BLE001
            pass
        with open(os.path.join(OUT, "tune3.json"), "w", encoding="utf-8") as f:
            json.dump(res, f, ensure_ascii=False, indent=1)
        if "--keep" not in sys.argv:
            stop_play(c)
        save_log(os.path.join(OUT, "tune3_log.txt"))


if __name__ == "__main__":
    main()
