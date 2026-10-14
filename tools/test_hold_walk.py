"""최종 검수 10/14 hold_pose follow-up (walk photos: the sword's handle axis z -0.13 = the arm swing threw the blade forward;
the staff and the bow crossed the body), offline. WeaponPose (게임성 개발 1):

1. WeaponPose.Counter(shoulder, elbow, k): the wrist turn that takes back k of the arm's animated swing (the shoulder's
   and the elbow's turn about X summed, -k of it about X).
2. WeaponPose.PoseStep (the real function, on a double R15 arm): while a weapon rests, a walk swing of the holding arm
   moves the weapon's axis at most 20 degrees from its standing axis (shoulder swing up to +-40 degrees, elbow 0..20),
   for the sword (right arm, Side), the staff (right arm, Staff) and the bow (left arm, Bow); the shoulder still swings.
3. No build-up: a joint the animation does not write (the wrist) gets this frame's turn on top of its last animated
   value (WeaponPose.BaseOf), never on top of our own output again - 60 frames later it is still one turn.
4. Config.HoldPoses: every hold has a Counter (Arm Right / Left, 0.5 <= K <= 0.9); the bow counters the LEFT arm.
Runs the CURRENT WeaponPose.luau functions + Config.HoldPoses / WeaponGrips in the rigid CFrame harness of
tools/test_weapon_motion.py. Mutations: each must be caught.
Report: docs/art/verification_2026-10-14/offline_hold_walk_2026-10-14.json (do not commit)
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
OUT = ROOT / "docs/art/verification_2026-10-14/offline_hold_walk_2026-10-14.json"
WP_CUTS = ["function WeaponPose.HoldOf(kind)", "function WeaponPose.PoseFor(kind, walking)",
           "function WeaponPose.Counter(shoulder, elbow, k)", "function WeaponPose.BaseOf(m)", "function WeaponPose.PoseStep()"]

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
local Config = {}
'''

TESTS = r'''
local nchecks, failed = 0, 0
local function ok(v, name, detail)
    nchecks += 1
    if v then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local function deg(a) return math.deg(a) end
local function angle(a, b) return math.deg(math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1))) end

-- 1. Counter
local c = WeaponPose.Counter(CFrame.Angles(math.rad(30), 0, 0), CFrame.Angles(math.rad(10), 0, 0), 0.7)
local cx = c:ToEulerAnglesXYZ()
ok(math.abs(deg(cx) + 28) < 1e-6, "Counter: 30 + 10 degrees of swing, k 0.7 -> -28 about X", deg(cx))
ok(WeaponPose.Counter(nil, nil, 0.7):FuzzyEq(CFrame.new(), 1e-9), "Counter: no swing read -> no turn", "")

-- a double R15 character: the holding arm's three motors, a resting weapon, a walking humanoid
local function rig(kind, side)
    local char = node("Model", "Char")
    local m = {}
    for _, j in { { "Shoulder", "UpperArm" }, { "Elbow", "LowerArm" }, { "Wrist", "Hand" } } do
        for _, s in { "Right", "Left" } do
            local part = child(char, node("Part", s .. j[2], { CFrame = CFrame.new() }))
            m[s .. j[1]] = child(part, node("Motor6D", s .. j[1], { Transform = CFrame.new() }))
        end
    end
    local tool = child(char, node("Tool", "WeaponModel"))
    tool:SetAttribute("Kind", kind)
    local hum = child(char, node("Humanoid", "Humanoid", { MoveDirection = Vector3.new(1, 0, 0) }))
    S.Rest[tool] = "Rest"
    PLAYERS = { { Character = char } }
    return m, hum
end
-- the weapon's long axis in the upper arm's space: shoulder x elbow x wrist (rigid chain, each joint's Transform) x the
-- weapon's rest turn (Config.WeaponGrips Rest about the fist)
local function axis(m, side, kind)
    local rest = Config.WeaponGrips[kind].Rest
    local grip = CFrame.Angles(math.rad(rest[1]), math.rad(rest[2]), math.rad(rest[3]))
    local cf = m[side .. "Shoulder"].Transform * m[side .. "Elbow"].Transform * m[side .. "Wrist"].Transform * grip
    return cf:VectorToWorldSpace(Vector3.new(0, 1, 0))
end

-- 2. the walk swing keeps the weapon's axis
for _, row in { { "Sword", "Right" }, { "Staff", "Right" }, { "Bow", "Left" } } do
    local kind, side = row[1], row[2]
    local m = rig(kind, side)
    local function frame(sh, el)
        m[side .. "Shoulder"].Transform = CFrame.Angles(math.rad(sh), 0, 0) -- the animation writes the arm, not the wrist
        m[side .. "Elbow"].Transform = CFrame.Angles(math.rad(el), 0, 0)
        WeaponPose.PoseStep()
    end
    frame(0, 0)
    local still = axis(m, side, kind)
    local worst, shoulderMoved = 0, true
    for t = 0, 40 do
        local sh = 40 * math.sin(t / 40 * 2 * math.pi)
        local el = 10 + 10 * math.sin(t / 40 * 2 * math.pi)
        frame(sh, el)
        worst = math.max(worst, angle(axis(m, side, kind), still))
        local sx = m[side .. "Shoulder"].Transform:ToEulerAnglesXYZ()
        if t == 10 and math.abs(deg(sx) - 40) > 15 then shoulderMoved = false end
    end
    ok(worst <= 20, kind .. ": walking (shoulder +-40, elbow 0..20) the weapon stays within 20 degrees of its standing axis", worst)
    ok(shoulderMoved, kind .. ": the shoulder still swings with the walk", "")
end

-- 3. no build-up on a joint the animation does not write
do
    local m = rig("Sword", "Right")
    for _ = 1, 60 do
        m.RightShoulder.Transform = CFrame.Angles(math.rad(20), 0, 0)
        m.RightElbow.Transform = CFrame.Angles(math.rad(10), 0, 0)
        WeaponPose.PoseStep() -- the wrist keeps what we wrote last frame (no animation writes it)
    end
    local wx = m.RightWrist.Transform:ToEulerAnglesXYZ()
    local k = Config.HoldPoses.Side.Counter.K
    ok(math.abs(deg(wx) + k * 30) < 1e-4, "60 frames: the wrist holds ONE counter turn (no build-up)", deg(wx))
    local ex = m.RightElbow.Transform:ToEulerAnglesXYZ()
    -- the animation rewrote the elbow every frame: our turn once on top of it
    local want = (CFrame.Angles(math.rad(10), 0, 0) * CFrame.Angles(math.rad(Config.HoldPoses.Side.RightElbow[1]), 0, 0)):ToEulerAnglesXYZ()
    ok(math.abs(ex - want) < 1e-6, "an animated joint: the animation's value + our turn once", deg(ex))
end

-- 4. Config
local all = true
for name, pose in Config.HoldPoses do
    local c2 = pose.Counter
    if type(c2) ~= "table" or (c2.Arm ~= "Right" and c2.Arm ~= "Left") or not (c2.K >= 0.5 and c2.K <= 0.9) then all = false end
end
ok(all and Config.HoldPoses.Bow.Counter.Arm == "Left" and Config.HoldPoses.Side.Counter.Arm == "Right",
    "Config.HoldPoses: every hold counters its holding arm (the bow the left), K 0.5..0.9", "")
print(("HOLD_WALK_SUMMARY checks=%d failed=%d"):format(nchecks, failed))
'''

MUTATIONS = [
    ("WP", "no counter turn", "\t\t\t\t\tturns[wrist] = turns[wrist] and turns[wrist] * back or back\n", ""),
    ("WP", "the counter the wrong way", "return CFrame.Angles(-(tonumber(k) or 0) * (swing(shoulder) + swing(elbow)), 0, 0)",
     "return CFrame.Angles((tonumber(k) or 0) * (swing(shoulder) + swing(elbow)), 0, 0)"),
    ("WP", "the elbow's swing ignored", "(swing(shoulder) + swing(elbow))", "(swing(shoulder))"),
    ("WP", "our own output built on again", "\tif w and now:FuzzyEq(w.Out, T.Same) then return w.Base end\n", ""),
    ("CONFIG", "the bow counters the right arm", 'Counter = { Arm = "Left", K = 0.8 } },', 'Counter = { Arm = "Right", K = 0.8 } },'),
    ("CONFIG", "the sword counter too weak", 'Counter = { Arm = "Right", K = 0.7 } },', 'Counter = { Arm = "Right", K = 0.2 } },'),
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


def run(src: dict) -> tuple[int, int, str]:
    wp, cfg = src["WP"], src["CONFIG"]
    t = re.search(r"\nlocal T = \{\n.*?\n\}\n", wp, re.S)
    parts = [EXTRA, block(cfg, "Config.WeaponGrips = {"), block(cfg, "Config.HoldPoses = {"),
             "local PLAYERS = {}\nlocal Players = { GetPlayers = function() return PLAYERS end }\nlocal WeaponPose = {}\n",
             t[0] if t else "local T = {}\n",
             "local S = { Rest = {}, Wrote = setmetatable({}, { __mode = 'k' }) }\n"]
    parts += [cut(wp, s) for s in WP_CUTS]
    code = twm.MATH + "\n" + "\n".join(parts) + "\n" + TESTS
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "hold_walk.luau"
        p.write_text(code, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"HOLD_WALK_SUMMARY checks=(\d+) failed=(\d+)", out)
    return (int(m[1]) if m else 0), (int(m[2]) if m else 1), out


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
    ok = found and failed == 0 and checks >= 8 and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Runs the")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
