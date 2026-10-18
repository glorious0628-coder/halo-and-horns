"""Attack poses on differently built avatars (최종 검수 10/17: the user's decorated avatar 'hits oddly'). MY test Studio only
(STUDIO_ID = PhoneTest_1015, my own Play; Studio Play uses the logged-in user's own avatar = variant 'mine').
For each body variant (HumanoidDescription scales applied on the server, Roblox's limits) x class (Warrior / Mage / Archer,
T1, Halo by default) beside a slime: one F, the weapon / hand measured over 0.6 s (grip1016.MEASURE: the fist's distance
from the handle line, the hand-handle angle, the weapon parts inside the body, the lowest weapon point over the feet) +
a side photo at the contact moment, and the arm stretch (shoulder -> hand distance / arm length, max over the swing).
Out: docs/art/verification_2026-10-17/avatar_attack/<variant>_<class>.png, table.json, summary.txt, log.txt
Usage: STUDIO_ID=... py avatar1017.py [Halo|Horns] [variant ...]   (default: every variant)
Variants: mine (as is), tall (H 1.05), short (H 0.9), thin (W 0.7), wide (W 1.0, depth 1.0), rthro (BodyType 1,
Proportion 1), bighead (Head 1.0 + H 0.9), slender (Proportion 1, BodyType 0.3, W 0.75)"""
import json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from h1016 import Client, log, save_log, lua, key, shot, debug, scene, start_play, pick, stop_play, close, GAME  # noqa: E402
from measure_common import MEASURE, FACE_SLIME  # noqa: E402
import tune1016 as T1  # noqa: E402

OUT = os.path.join(GAME, "docs", "art", "verification_2026-10-17", "avatar_attack")
os.makedirs(OUT, exist_ok=True)
VARIANTS = {
    "mine": None,
    "tall": {"HeightScale": 1.05},
    "short": {"HeightScale": 0.9},
    "thin": {"WidthScale": 0.7},
    "wide": {"WidthScale": 1.0, "DepthScale": 1.0},
    "rthro": {"BodyTypeScale": 1.0, "ProportionScale": 1.0},
    "bighead": {"HeadScale": 1.0, "HeightScale": 0.9},
    "slender": {"ProportionScale": 1.0, "BodyTypeScale": 0.3, "WidthScale": 0.75},
    "longwear": {},  # as 'mine' + a test long hair down the back + a long skirt drum (LONGWEAR)
}
APPLY = r'''
local p = game.Players:GetPlayers()[1]
local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
if not hum then return "no humanoid" end
_G.DEV1_BASEDESC = _G.DEV1_BASEDESC or hum:GetAppliedDescription():Clone()
local d = _G.DEV1_BASEDESC:Clone()
for k, v in %s do d[k] = v end
local ok, err = pcall(function() hum:ApplyDescription(d) end)
return string.format("%%s H%%.2f W%%.2f D%%.2f Head%%.2f BT%%.2f P%%.2f", ok and "applied" or ("fail " .. tostring(err)),
	d.HeightScale, d.WidthScale, d.DepthScale, d.HeadScale, d.BodyTypeScale, d.ProportionScale)
'''
# the stowed weapon (sword at the hip / bow on the back, A23-223) against the character's own accessories (long hair, a
# long skirt = Accessory handles; the user's avatar 10/17) and body parts, with the test hair / skirt of 'longwear'
STOWHIT = r'''
local ch = game.Players.LocalPlayer.Character
local tool = ch and ch:FindFirstChild("WeaponModel")
if not tool then return "no weapon" end
local handle = tool:FindFirstChild("Handle")
local w = handle and handle:FindFirstChild("StowWeld")
local list = {}
for _, d in ch:GetDescendants() do
	if d:IsA("BasePart") and not d:IsDescendantOf(tool) and d.Name ~= "HumanoidRootPart" then table.insert(list, d) end
end
local op = OverlapParams.new()
op.FilterType = Enum.RaycastFilterType.Include
op.FilterDescendantsInstances = list
local hits = {}
for _, wp in tool:GetDescendants() do
	if wp:IsA("BasePart") and wp.Transparency < 0.95 then
		for _, h in workspace:GetPartsInPart(wp, op) do
			local acc = h:FindFirstAncestorWhichIsA("Accessory")
			local n = acc and ("acc:" .. acc.Name) or h.Name
			hits[n] = (hits[n] or 0) + 1
		end
	end
end
local out = {}
for k, v in hits do table.insert(out, k .. "=" .. v) end
return string.format("stowed=%s hits: %s", tostring(w and w.Enabled), #out > 0 and table.concat(out, ",") or "none")
'''
LONGWEAR = r'''
local ch = game.Players:GetPlayers()[1].Character
for _, n in { "TestHair", "TestSkirt" } do local o = ch:FindFirstChild(n) if o then o:Destroy() end end
local head, lt = ch:FindFirstChild("Head"), ch:FindFirstChild("LowerTorso")
local function add(name, size, part, cf, shape)
	local a = Instance.new("Accessory") a.Name = name
	local h = Instance.new("Part") h.Name = "Handle" h.Size = size h.CanCollide = false h.Massless = true h.Transparency = 0.3
	if shape then h.Shape = shape end
	h.CFrame = part.CFrame * cf h.Parent = a
	local wc = Instance.new("WeldConstraint") wc.Part0, wc.Part1 = part, h wc.Parent = h
	a.Parent = ch
end
-- long hair: down the back of the head to the waist; a long skirt: a wide drum from the hips to the knees
add("TestHair", Vector3.new(1.4, 3.2, 0.5), head, CFrame.new(0, -1.3, 0.55))
add("TestSkirt", Vector3.new(2.4, 2.6, 2.4), lt, CFrame.new(0, -1.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder)
return "long hair + long skirt on"
'''
STRETCH = r'''
local secs = %s
local ch = game.Players.LocalPlayer.Character
local out = {}
local function len(a, b) return (a.Position - b.Position).Magnitude end
local t0 = os.clock()
for _, s in { "Right", "Left" } do out[s] = 0 end
while os.clock() - t0 < secs do
	for _, s in { "Right", "Left" } do
		local ua, la, h = ch:FindFirstChild(s .. "UpperArm"), ch:FindFirstChild(s .. "LowerArm"), ch:FindFirstChild(s .. "Hand")
		local sh = ua and ua:FindFirstChild(s .. "ShoulderRigAttachment")
		if ua and la and h and sh then
			local arm = ua.Size.Y + la.Size.Y + h.Size.Y * 0.5
			out[s] = math.max(out[s], (sh.WorldPosition - h.Position).Magnitude / arm)
		end
	end
	task.wait()
end
return string.format("stretch R %%.2f L %%.2f", out.Right, out.Left)
'''


def one(c, variant, cls, rows):
    tag = f"{variant}_{cls}"
    log("==", tag, debug(c, "Class", cls))
    time.sleep(2.5)
    close(c)
    log("  ", lua(c, FACE_SLIME, "Server"))
    time.sleep(1.0)
    lua(c, 'workspace:SetAttribute("Dev1Cam2", "side") return ""', "Client")
    time.sleep(0.3)
    key(c, "F")
    time.sleep(0.15)
    shot(c, os.path.join(OUT, f"{tag}.png"))
    raw = lua(c, MEASURE % 0.5, "Client")
    try:
        m = json.loads(raw)
    except Exception:  # noqa: BLE001
        m = {"raw": raw[:200]}
    time.sleep(1.2)
    key(c, "F")
    st = lua(c, STRETCH % 0.6, "Client")  # the second swing: the arms' largest stretch
    m["stretch"] = st
    time.sleep(6.0)  # HandSeconds 5: the sword / bow goes to the hip / back
    m["stowed"] = lua(c, STOWHIT, "Client")
    if cls != "Mage":
        lua(c, 'workspace:SetAttribute("Dev1Cam2", "side") return ""', "Client")
        time.sleep(0.3)
        shot(c, os.path.join(OUT, f"{tag}_stowed.png"))
    rows.append({"variant": variant, "class": cls, "m": m})
    log("  ", json.dumps(m)[:400])
    lua(c, 'workspace:SetAttribute("Dev1Cam2", nil) return ""', "Client")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    side = args[0] if args and args[0] in ("Halo", "Horns") else "Halo"
    want = [a for a in args if a in VARIANTS] or list(VARIANTS)
    c = Client()
    c.start()
    start_play(c)
    log("pick:", pick(c, side, "Warrior"))
    rows = []
    try:
        log(lua(c, T1.CAM, "Client"))
        log("clock:", lua(c, 'return tostring(game.ServerScriptService.DebugCommand:Invoke("", "Clock", 13))', "Server"))
        log("scene", scene(c, {"Faction": side, "Class": "Warrior", "Level": 30, "Tutorial": "Done",
                               "Done": ["M1_1", "M1_2", "M1_3", "M1_4"], "At": "Zone:SlimeMeadow"}))
        time.sleep(3)
        close(c)
        debug(c, "WeaponOwnedMask", 7)
        debug(c, "WeaponTier", 1)
        for v in want:
            spec = VARIANTS[v]
            lua_spec = "{}" if not spec else "{" + ", ".join(f"{k} = {val}" for k, val in spec.items()) + "}"
            log("variant", v, lua(c, APPLY % lua_spec, "Server"))
            time.sleep(2.0)
            if v == "longwear":
                log("  ", lua(c, LONGWEAR, "Server"))
                time.sleep(1.0)
            for cls in ("Warrior", "Mage", "Archer"):
                try:
                    one(c, v, cls, rows)
                except Exception as e:  # noqa: BLE001
                    log("  failed", v, cls, str(e)[:200])
    finally:
        with open(os.path.join(OUT, "table.json"), "w", encoding="utf-8") as f:
            json.dump(rows, f, ensure_ascii=False, indent=1)
        lines = []
        for r in rows:
            m = r["m"]
            lines.append(f"{r['variant']:8} {r['class']:7} fistOff {m.get('dGripMax')} angle {m.get('axisMax')} "
                         f"inBody {m.get('hits')} lowOverFeet {m.get('lowAboveFeet')} {m.get('stretch')} | {m.get('stowed')}")
        with open(os.path.join(OUT, "summary.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(lines))
        save_log(os.path.join(OUT, "log.txt"))
        lua(c, T1.CAM_OFF, "Client")
        stop_play(c)


if __name__ == "__main__":
    main()
