"""Round 2 (최종 검수 10/16): the bow plan A refined (hand at the belly..sternum, the top end out 5..15, forward 25..40, the right
hand near the string) and the mage attacks without the tip aim (the staff 20..40 forward at the cast, never over the head).
MY test Play only, branch dev1-hold-angles synced (WeaponPose Dev1Tune + Fx Dev1Clips, Studio only).
Usage: py tune2_1016.py [--running] [--keep]"""
import itertools, json, os, re, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from h1016 import Client, log, save_log, lua, key, shot, debug, scene, start_play, pick, stop_play, close, GAME  # noqa: E402
import tune1016 as T1  # noqa: E402  (M2, CAM, photos, tune, setup)

OUT = os.path.join(GAME, "docs", "art", "verification_2026-10-16", "hold_tune2")
os.makedirs(OUT, exist_ok=True)
T1.OUT = OUT
FX = os.path.join(GAME, "..", "Game-dev1grip", "src", "StarterPlayer", "StarterPlayerScripts", "Fx.luau")


def clip_from_source(name):
    """MOTION.CLIPS.<name> from Fx.luau as { Len, Keys = [[t, ease, {joint: [x, y, z]}]] }"""
    src = open(FX, encoding="utf-8").read()
    i = src.index(f"\t\t{name} = {{ Len = ")
    head = re.match(r"\t\t\w+ = \{ Len = ([\d.]+)", src[i:])
    body = src[i:src.index("\n\t\t} },", i)]
    keys = []
    for m in re.finditer(r'\{ ([\d.]+), "(\w+)", \{(.*?)\} \},', body):
        joints = {j: [float(a), float(b), float(c)] for j, a, b, c in
                  re.findall(r"(\w+) = \{ (-?[\d.]+), (-?[\d.]+), (-?[\d.]+) \}", m.group(3))}
        keys.append([float(m.group(1)), m.group(2), joints])
    return {"Len": float(head.group(1)), "Keys": keys}


def with_wrist(clip, wA, wB, strike):
    """every key's RightWrist X: wA before the strike time, wB from it on (Y / Z kept); keys without a wrist keep none"""
    out = json.loads(json.dumps(clip))
    for k in out["Keys"]:
        j = k[2]
        if "RightWrist" in j:
            j["RightWrist"][0] = wA if k[0] < strike - 1e-6 else wB
    return out


# during one attack: the staff's forward lean (+ = the top forward of upright, degrees, in the body frame), its most
# backward lean, frames the top end is behind / over the head, frames the weapon overlaps the head / torso
M3 = r'''
local secs = %s
local RS = game:GetService("RunService")
local ch = game.Players.LocalPlayer.Character
local root, head, tool = ch.HumanoidRootPart, ch:FindFirstChild("Head"), ch:FindFirstChild("WeaponModel")
local mesh = tool and (tool:FindFirstChild("WeaponMesh", true) or tool:FindFirstChild("Handle"))
if not mesh then return "{\"err\":\"no weapon\"}" end
local op = OverlapParams.new()
op.FilterType = Enum.RaycastFilterType.Include
op.FilterDescendantsInstances = { head, ch:FindFirstChild("UpperTorso"), ch:FindFirstChild("LowerTorso") }
local acc = { n = 0, maxFwd = -999, minFwd = 999, behind = 0, hits = {} }
local conn
conn = RS.Heartbeat:Connect(function()
	local dir, rc = mesh.CFrame.UpVector, root.CFrame
	local fwd = math.deg(math.atan2(rc.LookVector:Dot(dir), rc.UpVector:Dot(dir)))
	acc.n += 1
	acc.maxFwd, acc.minFwd = math.max(acc.maxFwd, fwd), math.min(acc.minFwd, fwd)
	local top = mesh.Position + dir * (mesh.Size.Y / 2)
	local rel = top - head.Position
	if rel:Dot(rc.LookVector) < -0.2 and rel.Y > -0.6 and math.abs(rel:Dot(rc.RightVector)) < 1.4 then acc.behind += 1 end
	for _, p in workspace:GetPartsInPart(mesh, op) do acc.hits[p.Name] = (acc.hits[p.Name] or 0) + 1 end
end)
task.wait(secs)
conn:Disconnect()
return game:GetService("HttpService"):JSONEncode({ n = acc.n, maxFwd = math.floor(acc.maxFwd + 0.5), minFwd = math.floor(acc.minFwd + 0.5),
	behind = acc.behind, hits = acc.hits })
'''
FACE = T1.__dict__.get("FACE_SLIME") or r'''
local p = game.Players:GetPlayers()[1]
local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
local best, bd
local f = workspace:FindFirstChild("Monsters")
for _, m in f and f:GetChildren() or {} do
	local mr = m:IsA("Model") and (m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart"))
	if mr and r then local d = (mr.Position - r.Position).Magnitude if not bd or d < bd then best, bd = mr, d end end
end
if not best then return "no monster" end
local dir = ((r.Position - best.Position) * Vector3.new(1, 0, 1)).Unit
local at = best.Position + dir * 7
r.CFrame = CFrame.lookAt(Vector3.new(at.X, r.Position.Y, at.Z), Vector3.new(best.Position.X, r.Position.Y, best.Position.Z))
return "facing"
'''


def clips(c, payload):
    return lua(c, 'workspace:SetAttribute("Dev1Clips", %s) return "set"' % json.dumps(json.dumps(payload) if payload else ""), "Client")


def attack_measure(c, k):
    lua(c, FACE, "Server")
    time.sleep(0.25)
    key(c, k)
    raw = lua(c, M3 % 1.0, "Client")
    time.sleep(0.5)
    try:
        return json.loads(raw)
    except Exception:  # noqa: BLE001
        return {"raw": raw[:200]}


def score_attack(r):
    if "maxFwd" not in r:
        return 999
    s = max(0, 20 - r["maxFwd"]) + max(0, r["maxFwd"] - 40) + max(0, -10 - r["minFwd"]) * 2 + r["behind"] * 3
    hits = r.get("hits") if isinstance(r.get("hits"), dict) else {}
    s += sum(v for k, v in hits.items() if k != "UpperTorso") * 2 + hits.get("UpperTorso", 0)
    return s


BOW = []
for elbow, shx, rx, rz in itertools.product((50, 60, 70), (0, -10), (-75, -60, -45, -30), (-45, -30, -15, 0, 15)):
    stand = {"LeftShoulder": [shx, 0, -14], "LeftElbow": [elbow, 0, 0], "LeftWrist": [0, 0, 0],
             "RightShoulder": [30, 0, -18], "RightElbow": [70, 0, 0]}
    row = {"Arm": "Left", "Stand": stand, "Walk": stand, "Run": {"LeftShoulder": [0, 0, -4], "LeftElbow": [8, 0, 0]},
           "Air": {"LeftElbow": [10, 0, 0]}, "Damp": {"Stand": 0.85, "Walk": 0.95, "Run": 0.95, "Air": 0.97, "Lower": 0.98, "Free": 0.85}}
    BOW.append(({"elbow": elbow, "shx": shx, "rest": [rx, -90, rz]},
                {"HoldPoses": {"Bow": row}, "WeaponGrips": {k: {"Rest": [rx, -90, rz]} for k in ("Bow", "ShortBow")}}))


def score_bow(r):
    if "tilt" not in r:
        return 999
    lo, hi = r["hand"]
    s = abs(r["fwd"] - 32) * 0.7 + max(0, abs(r["out"] - 10) - 5) + max(0, 0.15 - r["gapMin"]) * 40
    s += max(0, 0.3 - lo) * 10 + max(0, hi - 0.8) * 10
    return round(s, 2)


MAGE = [("Halo", "LightMageSwing", "F", 0.24), ("Halo", "LightMageRelease", "Q", 0.35), ("Horns", "MageSwing", "F", 0.24),
        ("Horns", "DarkMageRelease", "Q", 0.35)]


def main():
    c = Client()
    c.start()
    if "--running" not in sys.argv:
        start_play(c)
        log("pick:", pick(c, "Halo", "Archer"))
    res = {"bow": [], "mage": {}}
    try:
        log(lua(c, T1.CAM, "Client"))
        log("clock:", lua(c, 'return tostring(game.ServerScriptService.DebugCommand:Invoke("", "Clock", 13))', "Server"))
        if "--mage-only" not in sys.argv:
            # 1. the bow, plan A refined
            T1.setup(c, "Halo", "Archer", 1)

            for k, payload in BOW:
                T1.tune(c, payload)
                time.sleep(0.4)
                r = T1.m(c, 0.3)
                res["bow"].append({"key": k, "m": r, "score": score_bow(r)})
            res["bow"].sort(key=lambda e: e["score"])

            for e in res["bow"][:4]:
                log("bow A2 best:", json.dumps(e))
            bestBow = next(p for k, p in BOW if k == res["bow"][0]["key"])
            res["bowBest"] = {"key": res["bow"][0]["key"], "payload": bestBow}
            T1.tune(c, bestBow)
            time.sleep(0.6)
            T1.photos(c, "Halo_Archer_T1_A2")
            res["bowBestWalk"] = T1.walk_measure(c)
            lua(c, T1.HALT, "Client")
            T1.setup(c, "Horns", "Archer", 2)
            T1.tune(c, bestBow)
            time.sleep(0.6)
            T1.photos(c, "Horns_Archer_T2_A2")
            T1.tune(c, None)
        # 2. the mage attacks without the tip aim
        for side, name, k, strike in MAGE:
            T1.setup(c, side, "Mage", 1)
            debug(c, "Mana", 999)
            scene(c, {"Monsters": [{"Kind": "Slime", "N": 1, "Dist": 8, "Anchor": True}]})
            time.sleep(1.0)
            base = clip_from_source(name)
            clips(c, None)
            now = attack_measure(c, k)
            rows = [{"key": "now (no aim)", "m": now, "score": score_attack(now)}]
            for wA, wB in itertools.product((-30, 0, 25), (-45, -20, 0, 25)):
                clips(c, {name: with_wrist(base, wA, wB, strike)})
                time.sleep(0.2)
                debug(c, "Mana", 999)
                r = attack_measure(c, k)
                rows.append({"key": {"wA": wA, "wB": wB}, "m": r, "score": score_attack(r)})
            rows.sort(key=lambda e: e["score"])
            res["mage"][name] = rows
            for e in rows[:3]:
                log("mage", name, json.dumps(e))
            best = rows[0]["key"]
            if isinstance(best, dict):
                clips(c, {name: with_wrist(base, best["wA"], best["wB"], strike)})
                res["mage"][name + "_def"] = with_wrist(base, best["wA"], best["wB"], strike)
            lua(c, 'workspace:SetAttribute("Dev1Cam2", "side") return ""', "Client")
            lua(c, FACE, "Server")
            time.sleep(0.4)
            key(c, k)
            for i in range(5):
                shot(c, os.path.join(OUT, f"{side}_{name}_strip{i}.png"))
            lua(c, 'workspace:SetAttribute("Dev1Cam2", nil) return ""', "Client")
            time.sleep(0.6)
            clips(c, None)
    finally:
        try:
            log(lua(c, 'workspace:SetAttribute("Dev1Clips", nil) ' + T1.CAM_OFF, "Client"))
        except Exception:  # noqa: BLE001
            pass
        with open(os.path.join(OUT, "tune2.json"), "w", encoding="utf-8") as f:
            json.dump(res, f, ensure_ascii=False, indent=1)
        if "--keep" not in sys.argv:
            stop_play(c)
        save_log(os.path.join(OUT, "tune2_log.txt"))


if __name__ == "__main__":
    main()
