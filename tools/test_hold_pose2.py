"""hold-pose-2 (최종 검수 10/15, Codex build/codex/hold_pose_advice.md), WeaponPose, offline.

1. The pure parts: WeaponPose.Smooth (smoothstep), Approach, MoveState (Air / Run / Walk / Stand by the ground speed's
   share of WalkSpeed, Config.HoldMotion), Compose (base damped under the rest turn, s = how much shows), DampOf.
2. WeaponPose.PoseStep (the real function, a double R15 arm, a fake Animator writing the shoulder / elbow each frame):
   - walking with the arm swinging +-40 degrees, the weapon's axis stays within 20 degrees of its no-swing axis (sword /
     staff on the right arm, the bow on the left); the bow's empty right arm keeps ~85% of its swing (Damp Free 0.15);
   - an attack: the rest share goes to 0 within HoldMotion In (0.08 s; the bow InBow 0.06 s), smoothly, nothing written
     at 0 (the clip owns the arm) and the grip's C1 = the plain Turn grip; after it, back to the Rest grip within Out
     (0.18 s), half-way between in the middle;
   - a joint the animation never writes (the wrist) holds ONE turn after 60 frames (no build-up).
3. Config.HoldPoses: every hold has Arm, Stand, Walk, Damp (shoulder Stand <= Walk <= Run <= Air in 0.8..0.99, Lower
   0.9..0.99; the bow Free 0.1..0.2); Config.HoldMotion In 0.08, InBow 0.06, Out 0.18..0.2, Blend 0.16.
Static: toolnone stays down while attacking; the bow's left rest weld stays until Fx's left BowGrip is on (never back to
the right grip); Stepped passes dt; Measure finds the hand whose weld is on.
Report: docs/art/verification_2026-10-15/offline_hold_pose2_2026-10-15.json (do not commit)
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import test_weapon_motion as twm  # noqa: E402

WP = ROOT / "src/StarterPlayer/StarterPlayerScripts/WeaponPose.luau"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-15/offline_hold_pose2_2026-10-15.json"
WP_CUTS = ["function WeaponPose.MemeOf(tier)", "function WeaponPose.HoldOf(kind)", "function WeaponPose.Smooth(r)",
           "function WeaponPose.Approach(x, want, dt, time)", "function WeaponPose.MoveState(air, share)",
           "function WeaponPose.PoseFor(kind, w, state)", "function WeaponPose.Compose(base, target, damp, s)",
           "function WeaponPose.DampOf(pose, joint, state)", "local function fxAttacking(char)", "function WeaponPose.BaseOf(m)",
           "function WeaponPose.JointOf(char, joint)", "function WeaponPose.PoseStep(dt)"]

EXTRA = r'''
function CF:ToEulerAnglesXYZ()
    local r = self.R
    local y = math.asin(math.clamp(r[3], -1, 1))
    return math.atan2(-r[6], r[9]), y, math.atan2(-r[2], r[1])
end
function CF:FuzzyEq(b, eps)
    if not near(self.P, b.P, eps) then return false end
    for i = 1, 9 do if math.abs(self.R[i] - b.R[i]) > (eps or 1e-5) then return false end end
    return true
end
local Enum = { HumanoidStateType = { Jumping = "Jumping", Freefall = "Freefall", Running = "Running" } }
local Config = { Weapons = {} }
local ATTACK = false
local C = { Fx = { AttackPlaying = function() return ATTACK end } }
'''

TESTS = r'''
local nchecks, failed = 0, 0
local function ok(v, name, detail)
    nchecks += 1
    if v then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local function deg(a) return math.deg(a) end
local function angle(a, b) return math.deg(math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1))) end
local function xOf(cf) local x = cf:ToEulerAnglesXYZ() return deg(x) end

-- 1. pure parts
ok(WeaponPose.Smooth(0) == 0 and WeaponPose.Smooth(1) == 1 and math.abs(WeaponPose.Smooth(0.5) - 0.5) < 1e-9
    and WeaponPose.Smooth(0.25) < 0.25, "Smooth: smoothstep (slow at both ends)")
ok(math.abs(WeaponPose.Approach(0, 1, 0.04, 0.08) - 0.5) < 1e-9 and WeaponPose.Approach(0.9, 1, 0.5, 0.18) == 1
    and WeaponPose.Approach(0.5, 0, 0.1, 0) == 0, "Approach: dt / time per step, clamped; time 0 = at once")
ok(WeaponPose.MoveState(true, 0) == "Air" and WeaponPose.MoveState(false, 0.9) == "Run" and WeaponPose.MoveState(false, 0.3) == "Walk"
    and WeaponPose.MoveState(false, 0.02) == "Stand", "MoveState: Air / Run / Walk / Stand")
local base = CFrame.Angles(math.rad(30), 0, 0)
local tgt = CFrame.Angles(0, 0, math.rad(10))
ok(WeaponPose.Compose(base, tgt, 0.9, 0):FuzzyEq(base, 1e-9), "Compose s 0: the animation untouched")
ok(WeaponPose.Compose(base, tgt, 1, 1):FuzzyEq(tgt, 1e-9), "Compose damp 1: the rest turn alone")
ok(math.abs(xOf(WeaponPose.Compose(base, nil, 0.85, 1)) - 4.5) < 1e-6, "Compose damp 0.85: 15% of the swing left", xOf(WeaponPose.Compose(base, nil, 0.85, 1)))

-- the double character
local function rig(kind, tier)
    local char = node("Model", "Char")
    local m = {}
    for _, j in { { "Shoulder", "UpperArm" }, { "Elbow", "LowerArm" }, { "Wrist", "Hand" } } do
        for _, s in { "Right", "Left" } do
            local part = child(char, node("Part", s .. j[2], { CFrame = CFrame.new(), Size = Vector3.new(1, 1, 1) }))
            m[s .. j[1]] = child(part, node("Motor6D", s .. j[1], { Transform = CFrame.new(), Enabled = true }))
        end
    end
    local tool = child(char, node("Tool", "WeaponModel"))
    tool:SetAttribute("Kind", kind)
    local handle = child(tool, node("Part", "Handle", { Size = Vector3.new(0.3, 1.2, 0.3), CFrame = CFrame.new() }))
    local hand = char:FindFirstChild("RightHand")
    local grip = child(hand, node("Weld", "RightGrip", { Part1 = handle, C1 = Config.WeaponGrip(kind, 1.2), Enabled = true }))
    local state = "Running"
    local hum = child(char, node("Humanoid", "Humanoid", { WalkSpeed = 16 }))
    function hum:GetState() return state end
    local root = child(char, node("Part", "HumanoidRootPart", { AssemblyLinearVelocity = Vector3.new(8, 0, 0), CFrame = CFrame.new() }))
    local player = { Character = char, GetAttribute = function(_, k) return k == "WeaponTier" and (tier or 1) or nil end }
    PLAYERS = { player }
    S.Char = {}
    S.Joint = {}
    S.Wrote = setmetatable({}, { __mode = "k" })
    return m, grip, root, function(v) state = v end
end
local DT = 1 / 60

-- 2a. the walk swing
for _, row in { { "Sword", "Right" }, { "Staff", "Right" }, { "Bow", "Left" } } do
    local kind, side = row[1], row[2]
    local m = rig(kind)
    local rest = Config.WeaponGrips[kind].Rest
    local grip = CFrame.Angles(math.rad(rest[1]), math.rad(rest[2]), math.rad(rest[3]))
    local function axis()
        return (m[side .. "Shoulder"].Transform * m[side .. "Elbow"].Transform * m[side .. "Wrist"].Transform * grip)
            :VectorToWorldSpace(Vector3.new(0, 1, 0))
    end
    local function frame(sh, el)
        m[side .. "Shoulder"].Transform = CFrame.Angles(math.rad(sh), 0, 0)
        m[side .. "Elbow"].Transform = CFrame.Angles(math.rad(el), 0, 0)
        m.RightShoulder.Transform = side == "Left" and CFrame.Angles(math.rad(sh), 0, 0) or m.RightShoulder.Transform
        WeaponPose.PoseStep(DT)
    end
    for _ = 1, 30 do frame(0, 10) end -- the walk blend settles
    local still = axis()
    local worst = 0
    for t = 0, 40 do
        frame(40 * math.sin(t / 40 * 2 * math.pi), 10 + 10 * math.sin(t / 40 * 2 * math.pi))
        worst = math.max(worst, angle(axis(), still))
    end
    ok(worst <= 20, kind .. ": walking (arm +-40 degrees) the weapon within 20 degrees of its axis", worst)
    if side == "Left" then
        frame(40, 10)
        local rx = xOf(m.RightShoulder.Transform)
        ok(rx > 30 and rx < 38, "the bow's empty right arm keeps ~85% of its swing (Damp Free 0.15)", rx)
    end
end

-- 2b. the attack hand-over
for _, row in { { "Sword", 0.08 }, { "Bow", 0.06 } } do
    local kind, inT = row[1], row[2]
    local m, grip = rig(kind)
    local function frame()
        m.RightShoulder.Transform = CFrame.Angles(math.rad(25), 0, 0)
        m.LeftShoulder.Transform = CFrame.Angles(math.rad(25), 0, 0)
        WeaponPose.PoseStep(DT)
    end
    for _ = 1, 20 do frame() end
    local st = S.Char[PLAYERS[1].Character]
    ok(st and st.R == 1, kind .. ": resting = the full rest share", st and st.R)
    ATTACK = true
    frame() frame()
    local mid = st.R
    ok(mid > 0 and mid < 1, kind .. ": an attack starts: the rest share on its way down", mid)
    local armM = kind == "Bow" and m.LeftShoulder or m.RightShoulder
    local pose = Config.HoldPoses[WeaponPose.HoldOf(kind)]
    local jn = kind == "Bow" and "LeftShoulder" or "RightShoulder"
    local want = WeaponPose.Compose(CFrame.Angles(math.rad(25), 0, 0), WeaponPose.PoseFor(kind, st.W, "Walk")[jn],
        WeaponPose.DampOf(pose, jn, "Walk"), WeaponPose.Smooth(st.R))
    ok(armM.Transform:FuzzyEq(want, 1e-6), kind .. ": the hand-over on a smoothstep curve")
    for _ = 1, math.ceil(inT / DT) - 2 do frame() end
    ok(st.R == 0, kind .. ": rest share 0 within " .. inT .. " s", st.R)
    local arm = kind == "Bow" and m.LeftShoulder or m.RightShoulder
    -- the clip's own value on the joint (Fx wrote it; it looks like our last output): at 0 it stays
    local clip = CFrame.Angles(math.rad(60), 0, 0)
    arm.Transform = clip
    S.Wrote[arm] = { Out = clip, Base = CFrame.Angles(math.rad(25), 0, 0) }
    WeaponPose.PoseStep(DT)
    ok(math.abs(xOf(arm.Transform) - 60) < 1e-6, kind .. ": at 0 nothing is written (the clip owns the arm)", xOf(arm.Transform))
    if kind ~= "Bow" then
        ok(grip.C1:FuzzyEq(Config.WeaponGrip(kind, 1.2), 1e-6), "Sword: during the attack the plain Turn grip")
    end
    ATTACK = false
    for _ = 1, math.floor(0.09 / DT) do frame() end
    local half = st.R
    ok(half > 0.3 and half < 0.7, kind .. ": half-way back after ~0.09 s", half)
    if kind ~= "Bow" then
        local a = grip.C1:VectorToWorldSpace(Vector3.new(0, 1, 0))
        local h = Config.WeaponGrip(kind, 1.2):VectorToWorldSpace(Vector3.new(0, 1, 0))
        local r = Config.WeaponGrip(kind, 1.2, "Rest"):VectorToWorldSpace(Vector3.new(0, 1, 0))
        ok(angle(a, h) > 5 and angle(a, r) > 5, "Sword: the grip turns between Turn and Rest on the same clock", angle(a, h))
    end
    for _ = 1, math.ceil(0.18 / DT) do frame() end
    ok(st.R == 1, kind .. ": back to rest within 0.18 s", st.R)
    if kind ~= "Bow" then
        ok(grip.C1:FuzzyEq(Config.WeaponGrip(kind, 1.2, "Rest"), 1e-6), "Sword: the Rest grip again")
    end
end

-- 2c. no build-up
do
    local m = rig("Sword")
    for _ = 1, 60 do
        m.RightShoulder.Transform = CFrame.Angles(math.rad(20), 0, 0) -- the animation writes the shoulder only
        WeaponPose.PoseStep(DT)
    end
    local pose = Config.HoldPoses[WeaponPose.HoldOf("Sword")]
    local want = WeaponPose.Compose(CFrame.new(), WeaponPose.PoseFor("Sword", 1, "Walk").RightElbow,
        WeaponPose.DampOf(pose, "RightElbow", "Walk"), 1)
    ok(m.RightElbow.Transform:FuzzyEq(want, 1e-6), "60 frames: the unwritten elbow holds ONE turn (no build-up)", xOf(m.RightElbow.Transform))
end

-- 2d. an upgraded avatar (HoldTest 10/15): its Motor6Ds are off, AnimationConstraints drive the arms
do
    local m = rig("Sword")
    local char = PLAYERS[1].Character
    local torso = child(char, node("Part", "UpperTorso", { CFrame = CFrame.new(), Size = Vector3.new(1, 1, 1) }))
    local upper = char:FindFirstChild("RightUpperArm")
    m.RightShoulder.Enabled = false
    local a0 = child(torso, node("Attachment", "RightShoulderRigAttachment", {}))
    local a1 = child(upper, node("Attachment", "RightShoulderRigAttachment", {}))
    local ac = child(char, node("AnimationConstraint", "RightShoulder", { Attachment0 = a0, Attachment1 = a1, Enabled = true,
        Transform = CFrame.new() }))
    for _ = 1, 20 do
        ac.Transform = CFrame.Angles(math.rad(40), 0, 0)
        WeaponPose.PoseStep(DT)
    end
    -- grip-3: the sword's hold (SwordReady) adds its own shoulder turn on top of the damped 40 degrees
    local sp = Config.HoldPoses[WeaponPose.HoldOf("Sword")]
    local wantX = 40 * (1 - sp.Damp.Stand) + sp.Stand.RightShoulder[1]
    ok(math.abs(xOf(ac.Transform) - wantX) < 1.5 and math.abs(xOf(m.RightShoulder.Transform)) < 1e-9,
        "an upgraded avatar: the AnimationConstraint gets the damped pose, the off Motor6D is left alone", xOf(ac.Transform) .. " vs " .. wantX)
end

-- 3. Config
local good = true
for name, pose in Config.HoldPoses do
    local d = pose.Damp or {}
    if not (type(pose.Arm) == "string" and type(pose.Stand) == "table" and type(pose.Walk) == "table" and d.Stand and d.Stand >= 0.8
        and d.Stand <= d.Walk and d.Walk <= d.Run and d.Run <= d.Air and d.Air <= 0.99 and d.Lower >= 0.9 and d.Lower <= 0.99) then
        good = false
        print("bad " .. name)
    end
end
local HM = Config.HoldMotion
ok(good and Config.HoldPoses.Bow.Arm == "Left" and Config.HoldPoses.Bow.Damp.Free >= 0.1 and Config.HoldPoses.Bow.Damp.Free <= 0.2
    and HM.In == 0.08 and HM.InBow == 0.06 and HM.Out >= 0.18 and HM.Out <= 0.2 and HM.Blend == 0.16,
    "Config.HoldPoses / HoldMotion: Codex's numbers")
print(("HOLD_POSE2_SUMMARY checks=%d failed=%d"):format(nchecks, failed))
'''

MUTATIONS = [
    ("WP", "the arm's swing not damped", "local rest = (target or CFrame.identity) * base:Lerp(CFrame.identity, math.clamp(tonumber(damp) or 0, 0, 1))",
     "local rest = (target or CFrame.identity) * base"),
    ("WP", "no smoothstep", "\t\tlocal share = WeaponPose.Smooth(st.R)\n", "\t\tlocal share = st.R\n"),
    ("WP", "written at share 0 (fights the clip)", "\t\tif share <= 0 then continue end -- the attack clip owns the arm\n", ""),
    ("WP", "the attack cuts the pose at once", "attacking and (hold == \"Bow\" and HM.InBow or HM.In) or HM.Out", "attacking and 0 or HM.Out"),
    ("WP", "the grip not on the same clock", "Config.WeaponGrip(kind, handle.Size.Y, nil, centre):Lerp(Config.WeaponGrip(kind, handle.Size.Y, \"Rest\", centre), share)",
     "Config.WeaponGrip(kind, handle.Size.Y, \"Rest\", centre)"),
    ("WP", "the other arm damped like the holding one", "\treturn tonumber(d.Free) or 0\n", "\treturn tonumber(d.Lower) or 0\n"),
    ("WP", "our own output built on again", "\tif w and now:FuzzyEq(w.Out, T.Same) then return w.Base end\n", ""),
    ("WP", "toolnone raised for the attack", "if math.abs(tr.WeightTarget - T.Low) > 1e-3 then tr:AdjustWeight(T.Low, T.Fade) end",
     "local w = rest and T.Low or 1 if math.abs(tr.WeightTarget - w) > 1e-3 then tr:AdjustWeight(w, T.Fade) end"),
    ("WP", "the bow back in the right hand for an attack", "\telseif mine and mine.Enabled and fxOn then\n", "\telseif mine and mine.Enabled then\n\t\trightGrip.Enabled = true\n"),
    ("WP", "only Motor6Ds (an upgraded avatar's arms untouched)", "\tlocal parentName = T.Parents[joint]\n\tfor _, d in char:GetDescendants() do",
     "\tlocal parentName = T.Parents[joint]\n\tfor _, d in {} do"),
    ("WP", "a switched-off Motor6D used", "\tif m and m:IsA(\"Motor6D\") and m.Enabled then\n", "\tif m and m:IsA(\"Motor6D\") then\n"),
    ("CONFIG", "the sword's shoulder barely damped", "Damp = { Stand = 0.85, Walk = 0.90, Run = 0.95, Air = 0.97, Lower = 0.95 } },\n\tStaff",
     "Damp = { Stand = 0.3, Walk = 0.3, Run = 0.3, Air = 0.3, Lower = 0.95 } },\n\tStaff"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def cut(text: str, start: str) -> str:
    a = text.find(start)
    if a < 0:
        return ""
    b = text.find("\nend\n", a)
    return text[a:b + 5] if b >= 0 else ""


def block(text: str, start: str) -> str:
    a = text.find(start)
    if a < 0:
        return ""
    b = text.find("\n}\n", a)
    return text[a:b + 3] if b >= 0 else ""


def statics(src: dict) -> list[tuple[str, bool]]:
    w = src["WP"]
    return [
        ("toolnone stays down while a hold weapon is held (rest and attack)",
         "if math.abs(tr.WeightTarget - T.Low) > 1e-3 then tr:AdjustWeight(T.Low, T.Fade) end" in w and "rest and T.Low or 1" not in w),
        ("the bow keeps its left rest weld until Fx's left BowGrip is on", "\telseif mine and mine.Enabled and fxOn then\n\t\t-- hold-pose-2" in w
         and "if rightOk and not fxOn then rightGrip.Enabled = true end" not in w),
        ("Stepped passes dt to PoseStep; Measure finds the hand whose weld is on",
         "RunService.Stepped:Connect(function(_, dt)" in w and "pcall(WeaponPose.PoseStep, dt)" in w
         and 'for _, name in { T.RestBow, "BowGrip" } do' in w),
    ]


def run(src: dict) -> tuple[int, int, str]:
    w, c = src["WP"], src["CONFIG"]
    t = re.search(r"\nlocal T = \{\n.*?\n\}\n", w, re.S)
    parts = [EXTRA, block(c, "Config.WeaponGrips = {"), block(c, "Config.HoldPoses = {"),
             c[c.find("Config.HoldMotion = {"):c.find("\n", c.find("Config.HoldMotion = {"))] + "\n",
             cut(c, "function Config.WeaponGripOf(kind)"), cut(c, "function Config.WeaponGrip(kind, len, mode, centre)"),
             "local PLAYERS = {}\nlocal Players = { GetPlayers = function() return PLAYERS end }\nlocal WeaponPose = {}\n",
             t[0] if t else "local T = {}\n", "local S = { Rest = {}, Wrote = {}, Char = {}, Joint = {} }\n"]
    parts += [cut(w, s) for s in WP_CUTS]
    code = twm.MATH + "\n" + "\n".join(parts) + "\n" + TESTS
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "hold_pose2.luau"
        p.write_text(code, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"HOLD_POSE2_SUMMARY checks=(\d+) failed=(\d+)", out)
    st = statics(src)
    out += "".join(("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + n for n, ok in st)
    return (int(m[1]) if m else 0) + len(st), (int(m[2]) if m else 1) + sum(1 for _, ok in st if not ok), out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {"WP": WP.read_text(encoding="utf-8-sig").replace("\r\n", "\n"),
           "CONFIG": CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")}
    found = all(cut(src["WP"], s) for s in WP_CUTS)
    checks, failed, out = run(src)
    print(out.strip())
    muts = []
    for key, name, old, new in MUTATIONS:
        hits = src[key].count(old)
        caught = False
        if hits == 1:
            m = dict(src)
            m[key] = src[key].replace(old, new)
            caught = run(m)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    ok = found and failed == 0 and checks >= 20 and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Static:")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
