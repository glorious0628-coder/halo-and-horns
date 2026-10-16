"""A23-150 7 weapons held the Roblox way (user 10/12 night (가) "로블록스 기본 그대로"; 게임성 개발 1), offline.

Builds every class x side weapon (9 rows: the 7 kinds of the user's sheet + the Dark Mage's crook staff + the Shadow
Hunter's short bow) with the CURRENT CharacterVisuals.luau weapon section and Config.luau (ClassGrips, WeaponGrips,
WeaponGrip) in a Luau harness (the rigid CFrame math of tools/test_weapon_motion.py), every tier, on three right hands:
the place's R15 grip (RightGripAttachment (0, -0.158, 0) turned -90 about X, the hand posed like Roblox's toolnone: the
arm forward), the user's AJU avatar grip (tools/fixtures/archer_native_aju.json) and a hand turned at random. Checks:
- the weapon is a Roblox Tool "WeaponModel" in the character (RequiresHandle, CanBeDropped false, ManualActivationOnly
  true: a click / tap stays our attack input), every part welded to its Handle, the Tool in the RIGHT hand - the bows too
  (GripHand), Tool.Grip = Config.WeaponGrip(kind, the Handle's length), and the parts sit exactly where the engine's
  RightGrip weld holds them (hand x RightGripAttachment x Grip:Inverse() = the Handle);
- the grip point: the hand's grip attachment lies on the Handle's axis (<= 1e-6) at the user's table share up from its
  bottom (sword / dark sword 0.75 of the hilt = Roblox's ClassicSword, staffs 0.45 of the shaft, hammer / baton 0.3, bows
  0.5 of the riser);
- the Handle axis: along the fist's knuckle line (the grip attachment's +Y), so upright with the arm forward; the short
  bow canted 15 degrees sideways (about the forearm);
- the sizes (A23-133 / A23-142, shares of the place's avatar height 5.18): sword 0.72..0.95 with the hand 0.10..0.30 up
  from its end (ClassicSword ~0.18; 0.30: the dark sword's pommel under its hilt), staffs 0.65..0.75 with the orb / flask >= 1.2 over the
  hand, bow 0.55..0.97, short bow <= 0.72, hammer 0.35..0.55, baton 0.3..0.6; the flask staff's leather wrap centred on
  the hand; the dark sword = the sword's handle and blade;
- the bows: the string on the body side (the Handle's +Z), AttackHand = LeftHand and HandMuzzle / HandBowRest in the left
  hand's space (the Handle on LeftGripAttachment with the same Grip); the others' HandMuzzle in the right hand's;
- Fx.bowHand (the real function): an archer draw moves the bow onto the left grip (a local weld BowGrip = LeftGrip x
  Grip, the RightGrip off) so the muzzle lands on the left hand's HandMuzzle, and back after; a sword never moves; a bow
  swapped mid-draw lets go of the old one. 최종 검수 10/13 review: ONE weld per bow (switched on / off, never re-made),
  after a clip the bow waits MOTION.BOW_HOLD (0.1..0.5 s) on the left - five rapid shots never put it back in the right
  hand, a stale return never wins over a new draw - then goes back; death puts it back at once;
- HUD's portrait (L.PortraitAppearance, the real function): nothing inside the weapon Tool (the BowGrip, a swap) nor the
  engine's RightGrip asks for a new copy of the character; an accessory part and a body joint still do.
Static: WeaponPose never writes a joint (Studio grip probe only) and ClientMain still loads it, Config.ClassGrips rows
hold only Weapon (no Hold / OneHand / OffHand / TwoHand / Walk), no fist() in CharacterVisuals, mount never welds the
Handle to itself, HeroPreview keeps the weapon Tool, the Backpack hotbar stays off, Fx calls bowHand in stepChar (archer
clips) and drop, and the attack clips are the ones from before (sha256 of Fx MOTION, Feel.archerPose, Feel.staffPose =
main 11213d87). Mutations on in-memory copies: each must be caught. Run alone (one test at a time).

Usage: py tools/test_tool_grip.py
Report: docs/art/verification_2026-10-12/offline_tool_grip_2026-10-12.json
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import test_weapon_motion as WM  # noqa: E402  (the rigid CFrame harness, lua(), source_function())

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau", "CV": ROOT / "src/ServerScriptService/CharacterVisuals.luau",
         "FX": SPS / "Fx.luau", "WP": SPS / "WeaponPose.luau", "MAIN": SPS / "ClientMain.client.luau",
         "HERO": SPS / "HeroPreview.luau", "VITALS": SPS / "VitalsUI.luau", "HUD_MAIN": SPS / "HUD.luau"}
OUT = ROOT / "docs/art/verification_2026-10-12/offline_tool_grip_2026-10-12.json"
LUAU = ROOT / "build/luau_cli_0_741/luau.exe"
FIXTURE = ROOT / "tools/fixtures/archer_native_aju.json"
# the user's table (docs/design/weapon_grip_plan_2026-10-12.md, chosen 10/12 night): where the fist holds the Handle;
# the swords: 최종 검수 10/14 (user while playing: the fist sat on the guard) = the middle of the hilt, 0.5 (was 0.75 =
# Roblox's ClassicSword, the fist's top against the guard)
POINTS = {"Sword": 0.5, "DarkSword": 0.5, "Bow": 0.5, "ShortBow": 0.5, "Staff": 0.45, "CrookStaff": 0.45, "FlaskStaff": 0.45,
          "Hammer": 0.3, "Baton": 0.3}
ROWS = [("Warrior", "Halo", "Sword"), ("Warrior", "Horns", "DarkSword"), ("Warrior", "Neutral", "Hammer"),
        ("Mage", "Halo", "Staff"), ("Mage", "Horns", "CrookStaff"), ("Mage", "Neutral", "FlaskStaff"),
        ("Archer", "Halo", "Bow"), ("Archer", "Horns", "ShortBow"), ("Archer", "Neutral", "Baton")]
# the attack clips as on main 11213d87 (before A23-150 7): "공격 = 지금 직업별 동작 그대로"; hold-angles (최종 검수 10/16):
# the mage clips' right wrist leans the staff ~30 forward (no tip aim: Feel.staffPose is gone) - the MOTION print of that
CLIP_SHA = {"MOTION": "a36e23b56b7bbbe610c56aed23e40e9cbb89f9f758e5ed2793ec53df1196a67c",
            "archerPose": "136320ecfdf70cd2880ca6351602cc4a7bee3084e98ebe77681228782c3aa868"}  # (the same body; the comment after it is launchWeapon's now)

CHECK_OLD = '''local function check(value, message)
    assert(value, message)
    checks += 1
end'''
CHECK_NEW = '''local failed = 0
local function check(value, message, detail)
    checks += 1
    if value then print("CHECK_OK   " .. message) else failed += 1; print("CHECK_FAIL " .. message .. (detail ~= nil and (" :: " .. tostring(detail)) or "")) end
end'''

TESTS = r'''
-- extra mocks: colours with Lerp (the dark sword shades its blade), materials, a Players double
local C3M = { __index = { Lerp = function(a) return a end } }
Color3 = { fromRGB = function() return setmetatable({}, C3M) end, new = function() return setmetatable({}, C3M) end }
Config.WeaponColor = function() return Color3.new() end
local function vec(t) return Vector3.new(t[1], t[2], t[3]) end
local function cfOf(t) return CFrame.new(table.unpack(t)) end
local function angleDeg(a, b) return math.deg(math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1))) end
local ROWS, POINTS, HANDS, AVATAR_H = ROWS_IN, POINTS_IN, HANDS_IN, 5.18

-- a character with two hands (their grip attachments as given; the left one mirrored in x, as on a real rig, so a value
-- in the wrong hand's space shows) and a Player double
local function makeChar(hand)
	local char = node("Model", "Char")
	local function handPart(name, att, grip)
		local p = child(char, node("Part", name, { CFrame = hand.CFrame, Size = Vector3.new(1, 1, 1) }))
		if att then
			local a = child(p, node("Attachment", att, { CFrame = grip }))
			a.Position = grip.Position
			a.WorldPosition = (p.CFrame * grip).Position
		end
		return p
	end
	local g = hand.Grip
	local right = handPart("RightHand", "RightGripAttachment", g)
	local left = handPart("LeftHand", "LeftGripAttachment", CFrame.new(-g.Position.X, g.Position.Y, g.Position.Z) * g.Rotation)
	left.CFrame = hand.CFrame * CFrame.new(-3, 0, 0) -- the other hand elsewhere (its own space matters, not its place)
	local hum = child(char, node("Humanoid", "Humanoid", { Health = 100, RigType = "R15" }))
	local player = node("Player", "P", { Character = char, UserId = 1 })
	return char, right, left, player
end

-- the weapon's extent along its Handle axis, studs (as tools/test_one_hand_grips.py measured A23-133 / A23-142: each
-- stick part's centre line end to end, a ball's diameter, part thickness left out; a bow = its string, tip to tip; the
-- crook staff = its foot to the hook's top, the orb hanging in the hook)
local function extent(model, handle)
	local axis, lo, hi = handle.CFrame.UpVector, math.huge, -math.huge
	local str = model:FindFirstChild("String")
	if str then
		local c = str.CFrame.Position:Dot(axis)
		return c - str.Size.Y / 2, c + str.Size.Y / 2
	end
	local hooked = model:FindFirstChild("Hook") ~= nil
	for _, p in model.Children do
		if p.ClassName == "Part" and not p.Destroyed and not (hooked and p.Name == "Tip") then
			local c = p.CFrame.Position:Dot(axis)
			local r = p.Shape == "Ball" and p.Size.X / 2 or math.abs(p.CFrame.UpVector:Dot(axis)) * p.Size.Y / 2
			lo, hi = math.min(lo, c - r), math.max(hi, c + r)
		end
	end
	return lo, hi
end

local function build(row, tier, hand)
	local char, right, left, player = makeChar(hand)
	player.Attributes.Class, player.Attributes.Faction, player.Attributes.WeaponTier = row[1], row[2], tier
	buildWeapon(player, char)
	return char, right, left, player, char:FindFirstChild("WeaponModel")
end

for _, hand in HANDS do
	for _, row in ROWS do
		local kind, tag = row[3], hand.Name .. " " .. row[1] .. "_" .. row[2]
		local ok = { tool = true, grip = true, weld = true, onAxis = true, point = true, axis = true, len = true, hand = true,
			clear = true, wrap = true, bow = true, muzzle = true, base = true }
		local worst = { onAxis = 0, point = 0 }
		for tier = 1, Config.MaxWeaponTier do
			local char, right, left, player, model = build(row, tier, hand)
			local handle = model and model:FindFirstChild("Handle")
			if not (model and handle) then
				check(false, tag .. ": the weapon has a Handle", tier)
				break
			end
			ok.tool = ok.tool and model.ClassName == "Tool" and model.Name == "WeaponModel" and model.Parent == char
				and model.RequiresHandle == true and model.CanBeDropped == false and model.ManualActivationOnly == true
				and model:GetAttribute("GripHand") == "RightHand" and model:GetAttribute("Kind") == kind
			ok.base = ok.base and model.HandPart == handle
			-- Tool.Grip from the grip table, and the Handle where the engine's RightGrip holds it
			-- grip-centre (10/16, docs/review/grip_check_2026-10-16.md #1): the grip point in the middle of the fist
			local att = right:FindFirstChild("RightGripAttachment")
			local centre = att.CFrame:PointToObjectSpace(Vector3.new(0, 0, 0))
			local gripCF = Config.WeaponGrip(kind, handle.Size.Y, nil, centre)
			ok.grip = ok.grip and same(model.Grip, gripCF) and model:GetAttribute("GripCentre") ~= nil
				and near(model:GetAttribute("GripCentre"), centre, 1e-6)
			local held = right.CFrame * att.CFrame * model.Grip:Inverse()
			ok.weld = ok.weld and same(held, handle.CFrame)
			-- the fist's centre on the Handle's axis at the table share (grip-centre 10/16: the hand's centre, not the
			-- attachment on its fingertip face)
			local g = handle.CFrame:PointToObjectSpace(right.CFrame.Position)
			worst.onAxis = math.max(worst.onAxis, math.sqrt(g.X * g.X + g.Z * g.Z))
			local share = g.Y / handle.Size.Y + 0.5
			worst.point = math.max(worst.point, math.abs(share - POINTS[kind]))
			-- the Handle axis: the fist's knuckle line (the attachment's +Y), the short bow canted 15 degrees about the forearm
			local fistUp, fistZ = (right.CFrame * att.CFrame).UpVector, (right.CFrame * att.CFrame).LookVector * -1
			local tilt = angleDeg(handle.CFrame.UpVector, fistUp)
			if kind == "ShortBow" then
				ok.axis = ok.axis and math.abs(tilt - 15) < 1e-3 and math.abs(handle.CFrame.UpVector:Dot(fistZ)) < 1e-6
			else
				ok.axis = ok.axis and tilt < 1e-3
			end
			-- sizes: shares of the avatar height, the hand's share up from the weapon's end
			local lo, hi = extent(model, handle)
			local len = (hi - lo) / AVATAR_H
			local handAt = right.CFrame.Position:Dot(handle.CFrame.UpVector)
			local handShare = (handAt - lo) / (hi - lo)
			-- (the crook's hook bends over: its top 0.075 under the nominal Hook, so its measured floor is 0.62)
			local span = ({ Sword = { .72, .95 }, DarkSword = { .72, .95 }, Staff = { .65, .75 }, CrookStaff = { .62, .75 },
				FlaskStaff = { .65, .75 }, Bow = { .55, .97 }, ShortBow = { .3, .72 }, Hammer = { .35, .55 }, Baton = { .3, .6 } })[kind]
			ok.len = ok.len and len >= span[1] - 1e-6 and len <= span[2] + 1e-6
			if kind == "Sword" or kind == "DarkSword" then ok.hand = ok.hand and handShare >= .10 and handShare <= .30 end
			if kind == "Hammer" then ok.hand = ok.hand and handShare >= .15 and handShare <= .33 end
			-- the orb / flask bottom >= 1.2 over the hand (staffs)
			local orb = model:FindFirstChild("Tip") or model:FindFirstChild("Flask")
			if kind == "Staff" or kind == "CrookStaff" or kind == "FlaskStaff" then
				local bottom = orb.CFrame.Position:Dot(handle.CFrame.UpVector) - orb.Size.Y / 2
				ok.clear = ok.clear and bottom - handAt >= 1.2 - 1e-6
			end
			if kind == "FlaskStaff" then
				local wrap = model:FindFirstChild("Wrap")
				ok.wrap = ok.wrap and near(wrap.CFrame.Position, right.CFrame.Position, 1e-6)
			end
			if kind == "DarkSword" then -- the sword's own handle and blade (A23-128)
				local blade = model:FindFirstChild("Blade")
				ok.wrap = ok.wrap and math.abs(handle.Size.Y - 1.2) < 1e-6
					and math.abs(handle.CFrame:PointToObjectSpace(blade.CFrame.Position).Y - (0.6 + 0.25 + blade.Size.Y / 2)) < 1e-6
			end
			-- muzzles: the bows' in the LEFT hand's space (the draw), the others' in the right's
			local main = model:FindFirstChild("AttackMuzzle", true)
			local muzzleWorld = main.Parent.CFrame * main.CFrame
			if kind == "Bow" or kind == "ShortBow" then
				local stringPart = model:FindFirstChild("String")
				ok.bow = ok.bow and handle.CFrame:PointToObjectSpace(stringPart.CFrame.Position).Z > 0.05
					and model:GetAttribute("AttackHand") == "LeftHand"
				local leftAtt = left:FindFirstChild("LeftGripAttachment")
				local onLeft = left.CFrame * leftAtt.CFrame * model.Grip:Inverse()
				local nock = stringPart:FindFirstChild("BowNock")
				ok.muzzle = ok.muzzle and same(left.CFrame * model:GetAttribute("HandMuzzle"), onLeft * handle.CFrame:ToObjectSpace(muzzleWorld))
					and same(left.CFrame * model:GetAttribute("HandBowRest"), onLeft * handle.CFrame:ToObjectSpace(stringPart.CFrame * nock.CFrame))
			else
				ok.muzzle = ok.muzzle and same(right.CFrame * model:GetAttribute("HandMuzzle"), muzzleWorld)
					and model:GetAttribute("AttackHand") == nil
			end
		end
		check(ok.tool, tag .. ": a Roblox Tool WeaponModel in the right hand (RequiresHandle, never dropped, manual activation)")
		check(ok.base, tag .. ": every part welded to the Handle")
		check(ok.grip, tag .. ": Tool.Grip = Config.WeaponGrip(kind, the Handle's length)")
		check(ok.weld, tag .. ": the parts sit where the engine's RightGrip holds the Handle")
		check(worst.onAxis < 1e-6, tag .. ": the grip point on the Handle's axis", worst.onAxis)
		check(worst.point < 1e-6, tag .. ": the fist " .. POINTS[kind] .. " up the Handle (the user's table)", worst.point)
		check(ok.axis, tag .. (kind == "ShortBow" and ": the short bow canted 15 degrees about the forearm" or ": the Handle along the knuckle line (upright, the arm forward)"))
		check(ok.len, tag .. ": the length a share of the avatar's height (A23-133 / A23-142)")
		if kind == "Sword" or kind == "DarkSword" or kind == "Hammer" then check(ok.hand, tag .. ": the hand's share up from the end") end
		if kind == "Staff" or kind == "CrookStaff" or kind == "FlaskStaff" then check(ok.clear, tag .. ": the orb >= 1.2 over the hand") end
		if kind == "FlaskStaff" then check(ok.wrap, tag .. ": the leather wrap centred on the hand") end
		if kind == "DarkSword" then check(ok.wrap, tag .. ": the dark sword = the sword's handle and blade") end
		if kind == "Bow" or kind == "ShortBow" then check(ok.bow, tag .. ": the string on the body side, the draw in the left hand (AttackHand)") end
		check(ok.muzzle, tag .. ((kind == "Bow" or kind == "ShortBow") and ": HandMuzzle / HandBowRest in the left hand's space" or ": HandMuzzle in the right hand's space"))
	end
end

-- the toolnone pose: the arm forward = the hand's -Z up; the Handle stands upright
do
	local hand = HANDS[1]
	local _, right, _, _, model = build(ROWS[1], 3, hand)
	check(model:FindFirstChild("Handle").CFrame.UpVector:Dot(Vector3.yAxis) > 0.9999, "toolnone (the arm forward): the sword stands upright")
end

-- A23-187 (user 10/14, our own hold): standing / walking the arm hangs (WeaponPose.RestStep fades toolnone out; the hand
-- keeps the body's axes) and the Rest grip puts the blade at the hip, its tip DOWN and 35..55 degrees back, not across the
-- body; the grip point stays the hilt's middle; a staff rests upright; every row has a resting hold (Side / Staff / Bow)
do
	local att = HANDS[1].Grip
	local hand = CFrame.new(1.5, 1, 0)
	for _, kind in { "Sword", "DarkSword" } do
		local grip = Config.WeaponGrip(kind, 1.2, "Rest")
		local cf = hand * att * grip:Inverse()
		local up = cf.UpVector
		-- grip-3 (user 10/15 + Codex grip2, HoldTest measured: SwordReady's arm puts the blade up and 30 degrees forward
		-- with Rest 30 standing, 27..33 walking): the turn the photos passed
		local rest = Config.WeaponGrips[kind].Rest
		check(rest[1] == 30 and rest[2] == 0 and rest[3] == 0 and Config.WeaponGrips[kind].Hold == "SwordReady",
			kind .. ": SwordReady, Rest 30 (HoldTest: the tip up and 30 forward)", table.concat(rest, ","))
		check(((hand * att).Position - cf.Position).Magnitude < 1e-6, kind .. ": resting, the fist still holds the hilt's middle")
		local held = hand * att * Config.WeaponGrip(kind, 1.2):Inverse()
		check(held.UpVector:Dot(cf.UpVector) < 0.9, kind .. ": the attack hold (plain grip) is not the rest turn")
	end
	-- hold-angles (10/16 grip_check #4): the staff stands up from the bent elbow (HoldPoses Staff RightElbow 80) and a small
	-- turn in the fist, not a turn that sets it upright in a hanging hand (that laid it along the forearm, on the arm);
	-- the test Play measured 7 degrees off upright, 0.7 studs from the upper arm (docs/art/verification_2026-10-16/hold_tune)
	local okStaff = true
	for _, k in { "Staff", "CrookStaff", "FlaskStaff" } do
		local r = Config.WeaponGrips[k].Rest
		okStaff = okStaff and r[1] == 15 and r[2] == 0 and r[3] == 0
	end
	local staffPose = Config.HoldPoses.Staff
	check(okStaff and staffPose.Stand.RightElbow[1] >= 70 and staffPose.Stand.RightElbow[1] <= 100,
		"a staff rests upright from the bent elbow (Rest 15, elbow 70..100)", staffPose.Stand.RightElbow[1])
	local holds = true
	for kind, row in Config.WeaponGrips do
		if type(row.Rest) ~= "table" or type(row.Hold) ~= "string" or type(Config.HoldPoses[row.Hold]) ~= "table" then holds = false end
	end
	check(holds, "every weapon row has a resting hold (Rest + a Config.HoldPoses row)")
	-- grip-3: each class its own hold; the joke weapons keep the old side hold (their own Meme row)
	local G = Config.WeaponGrips
	check(G.Hammer.Hold == "HammerCarry" and G.Baton.Hold == "BatonReady" and G.Staff.Hold == "Staff" and G.Bow.Hold == "Bow"
		and G.Meme.Hold == "Side" and G.Meme.Rest[1] == 225, "grip-3: hammer over the shoulder, baton up-forward, jokes on the old side hold")
	check(G.Bow.Rest[2] == -90 and G.ShortBow.Rest[2] == -90, "grip-3: the bow turned a quarter (string behind, limbs in front)")
end

-- Fx.bowHand: the draw moves the bow onto the left grip and back - one weld per bow (switched on / off), MOTION.BOW_HOLD s
-- on the left after a clip (rapid shots never flip it), at once on death (최종 검수 10/13 review)
local function bowWelds(handle)
	local n = 0
	for _, c in handle.Children do
		if c.Name == "BowGrip" and not c.Destroyed then n += 1 end
	end
	return n
end
for _, hand in HANDS do
	for _, bowRow in { ROWS[7], ROWS[8] } do -- the bow and the short bow (its Grip is turned)
		local tag = hand.Name .. " " .. bowRow[3]
		local char, right, left, player, model = build(bowRow, 3, hand)
		local handle = model:FindFirstChild("Handle")
		local rightGrip = right:FindFirstChild("RightGrip") -- the engine's weld (the harness's mount makes it)
		check(rightGrip ~= nil and rightGrip.Part1 == handle and rightGrip.Enabled == true, tag .. ": the bow stands on the right grip")
		local st = { Char = char }
		Feel.bowHand(st, true)
		local bowGrip = handle:FindFirstChild("BowGrip")
		check(bowGrip ~= nil and bowGrip.Part0 == left and bowGrip.Part1 == handle and rightGrip.Enabled == false,
			tag .. ": an archer draw puts the bow on the left grip (BowGrip, the RightGrip off)")
		local onLeft = bowGrip and bowGrip.Part0.CFrame * bowGrip.C0 * bowGrip.C1:Inverse()
		local muzzle = model:FindFirstChild("AttackMuzzle", true)
		check(onLeft ~= nil and same(onLeft * handle.CFrame:ToObjectSpace(muzzle.Parent.CFrame * muzzle.CFrame), left.CFrame * model:GetAttribute("HandMuzzle")),
			tag .. ": on the left grip the muzzle is the draw's HandMuzzle")
		Feel.bowHand(st, true)
		check(st.BowGrip ~= nil and st.BowGrip.Weld == bowGrip, tag .. ": a held draw keeps one weld")
		-- the clip ends: the bow waits on the left, then goes back (the weld kept, off)
		Feel.bowHand(st, false)
		check(st.BowGrip.On == true and rightGrip.Enabled == false and bowGrip.Enabled ~= false, tag .. ": after a clip the bow waits on the left (BOW_HOLD)")
		delays()
		check(st.BowGrip ~= nil and st.BowGrip.On == false and bowGrip.Enabled == false and rightGrip.Enabled == true
			and not bowGrip.Destroyed, tag .. ": after the hold the bow is back on the right grip (its weld kept, off)")
		-- rapid shots: every new clip before the hold is over keeps it on the left, the same weld; a stale return never wins
		local flips, created = 0, 0
		for _ = 1, 5 do
			Feel.bowHand(st, true)
			if rightGrip.Enabled then flips += 1 end
			Feel.bowHand(st, false)
			if rightGrip.Enabled then flips += 1 end
		end
		Feel.bowHand(st, true)
		delays() -- the five returns asked between the shots are all stale now
		check(flips == 0 and rightGrip.Enabled == false and st.BowGrip.On == true and bowWelds(handle) == 1,
			tag .. ": rapid shots: the bow never leaves the left hand, one weld", string.format("flips=%d welds=%d", flips, bowWelds(handle)))
		Feel.bowHand(st, false)
		delays()
		check(rightGrip.Enabled == true and bowWelds(handle) == 1, tag .. ": rapid shots over: back on the right after the hold")
		-- death: back at once
		Feel.bowHand(st, true)
		Feel.bowHand(st, false, true)
		check(rightGrip.Enabled == true and st.BowGrip.On == false, tag .. ": death puts the bow back at once")
		-- a swap mid-draw: the old bow is let go, the new one moved
		Feel.bowHand(st, true)
		local old = st.BowGrip
		player.Attributes.WeaponTier = 4
		buildWeapon(player, char) -- the server swaps the Tool (the old one destroyed, a new RightGrip)
		local again = char:FindFirstChild("WeaponModel")
		local newHandle = again:FindFirstChild("Handle")
		local newGrip = right:FindFirstChild("RightGrip")
		Feel.bowHand(st, true)
		check(old.Weld.Destroyed and st.BowGrip ~= nil and st.BowGrip.Handle == newHandle and newGrip.Enabled == false,
			tag .. ": a bow swapped mid-draw: the old weld goes, the new bow moves")
		Feel.bowHand(st, false, true)
	end
	-- a sword never moves
	local schar, sright, _, _, sword = build(ROWS[1], 3, hand)
	local sgrip = sright:FindFirstChild("RightGrip")
	local sst = { Char = schar }
	Feel.bowHand(sst, true)
	check(sst.BowGrip == nil and sgrip.Enabled == true and sword:FindFirstChild("Handle"):FindFirstChild("BowGrip") == nil, hand.Name .. ": a sword stays in the right hand")
end

-- HUD's portrait: nothing in the weapon Tool (the BowGrip every shot, a swap) nor the engine's RightGrip asks for a new
-- copy of the character; its body, accessories and own joints still do
do
	local function obj(class, name, ancestors)
		return { Name = name, IsA = function(_, c) return c == class or (c == "JointInstance" and (class == "Weld" or class == "Motor6D"))
			or (c == "BasePart" and class == "Part") or (c == "Model" and class == "Tool") end,
			FindFirstAncestor = function(_, n) return ancestors[n] and {} or nil end }
	end
	local inTool = { WeaponModel = true, Char = true }
	check(L.PortraitAppearance(obj("Weld", "BowGrip", inTool)) == false, "portrait: the archer's BowGrip asks for no copy")
	check(L.PortraitAppearance(obj("Part", "Handle", inTool)) == false and L.PortraitAppearance(obj("Tool", "WeaponModel", { Char = true })) == false,
		"portrait: a weapon swap (the Tool, its parts) asks for no copy")
	check(L.PortraitAppearance(obj("Weld", "RightGrip", { Char = true })) == false, "portrait: the engine's RightGrip asks for no copy")
	check(L.PortraitAppearance(obj("Part", "Handle", { Hat = true, Char = true })) == true and L.PortraitAppearance(obj("Motor6D", "RightWrist", { Char = true })) == true,
		"portrait: an accessory's part and a body joint still refresh it")
end
print("TOOL_GRIP_CHECKS " .. checks .. " FAILED " .. failed)
'''


def hands():
    aju = json.loads(FIXTURE.read_text(encoding="utf-8"))["parts"]["RightHand"]["grip"]
    rx = "CFrame.Angles(-math.pi/2,0,0)"
    return ("{"
            # the place's R15 grip, the hand posed like toolnone (the forearm forward: the hand turned +90 about X)
            f"{{Name='place R15 (toolnone)',CFrame=CFrame.new(1.3,4.4,-1.8)*CFrame.Angles(math.pi/2,0,0),Grip=CFrame.new(0,-0.158,0)*{rx}}},"
            f"{{Name='user AJU',CFrame=CFrame.new(-2,3,1)*CFrame.Angles(math.pi/2,0,0),Grip=CFrame.new({','.join(repr(v) for v in aju)})}},"
            f"{{Name='turned hand',CFrame=CFrame.new(5,2,-7)*CFrame.Angles(0.4,-1.1,0.7),Grip=CFrame.new(0.04,-0.158,0.03)*{rx}}}"
            "}")


def harness(src: dict) -> str:
    cfg, cv, fx = src["CONFIG"], src["CV"], src["FX"]
    math_ = WM.MATH.replace(CHECK_OLD, CHECK_NEW)
    if math_ == WM.MATH:
        raise RuntimeError("the shared harness changed its check()")
    out = math_
    out += "\n" + cfg[cfg.index("Config.Weapons = {"):cfg.index("-- display names per class")]
    out += "\n" + cfg[cfg.index("Config.ClassGrips = {"):cfg.index("Config.Combo = {")]
    for name in ("attrNum", "attrStr", "getFaction", "getClass", "charScale", "clearChild", "accPart"):
        out += "\n" + WM.local_function(cv, name)
    out += "\n" + cv[cv.index("------------------------------------------------------------------ WeaponModel"):
                     cv.index("------------------------------------------------------------------ sacks & ghost")]
    # the bow's hand-over (+ its hold: MOTION.BOW_HOLD read from Fx) and HUD's portrait filter
    hold = fx[fx.index("\tBOW_HOLD = "):].split("=", 1)[1].split(",", 1)[0].strip()
    out += "\nlocal MOTION = { BOW_HOLD = " + hold + " }\n" + WM.source_function(fx, "bowRight") + "\n" + WM.source_function(fx, "bowHand")
    hud = src["HUD_MAIN"]
    out += "\nlocal L = {}\n" + hud[hud.index("function L.PortraitAppearance("):hud.index("\nfunction L.PortraitLoad(")]
    rows ="{" + ",".join("{%s,%s,%s}" % (WM.lua(a), WM.lua(b), WM.lua(c)) for a, b, c in ROWS) + "}"
    tests = TESTS.replace("ROWS_IN", rows).replace("POINTS_IN", WM.lua(POINTS)).replace("HANDS_IN", hands())
    return out + "\n" + tests


def run_luau(src: dict) -> tuple[list[tuple[str, bool]], str]:
    path = ROOT / "build/tool_grip_offline_test.luau"
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        path.write_text(harness(src), encoding="utf-8")
    except (ValueError, RuntimeError) as e:
        return [("harness built from the sources", False)], str(e)
    done = subprocess.run([str(LUAU), str(path)], capture_output=True, text=True, encoding="utf-8")
    res = []
    for line in done.stdout.splitlines():
        if line.startswith("CHECK_OK   "):
            res.append((line[11:], True))
        elif line.startswith("CHECK_FAIL "):
            res.append((line[11:], False))
    finished = any(line.startswith("TOOL_GRIP_CHECKS ") for line in done.stdout.splitlines())
    if done.returncode != 0 or not finished:
        res.append(("the Luau harness ran to its end", False))
    return res, (done.stderr or "")[-600:]


def sha(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _hold_ok(fx: str) -> bool:
    try:
        v = float(fx[fx.index("\tBOW_HOLD = "):].split("=", 1)[1].split(",", 1)[0])
    except ValueError:
        return False
    return 0.1 <= v <= 0.5 and "later(MOTION.BOW_HOLD, function()" in fx


def statics(src: dict) -> list[tuple[str, bool]]:
    cfg, cv, fx, wp, main, hero, vitals = (src[k] for k in ("CONFIG", "CV", "FX", "WP", "MAIN", "HERO", "VITALS"))
    grips = cfg[cfg.index("Config.ClassGrips = {"):cfg.index("Config.WeaponGrips = {")]
    rows = [line for line in grips.splitlines() if line.startswith("\t") and "= { Weapon =" in line]
    weapon = cv[cv.index("------------------------------------------------------------------ WeaponModel"):
                cv.index("------------------------------------------------------------------ sacks & ghost")]
    out = [
        # A23-187: joints are written only for a resting hold (Config.HoldPoses on top of the animation, after it)
        ("WeaponPose writes joints only while a weapon rests (Config.HoldPoses, Stepped), no ClassGrips pose",
         "\t\t\t\tm.Transform = out\n" in wp and "local now = m.Transform" in wp
         and "\t\tif share <= 0 then continue end -- the attack clip owns the arm\n" in wp
         and "RunService.Stepped:Connect(function(_, dt)" in wp and wp.count("m.Transform") == 2 and "ClassGrips" not in wp
         and "SolveArm" not in wp),
        ("WeaponPose: the grip probe runs in Studio only, with GripProbe", 'RunService:IsStudio() and me and me:GetAttribute("GripProbe") == true' in wp),
        ("ClientMain still loads WeaponPose", '"WeaponPose"' in main),
        # 최종 검수 10/14: the sword rests at the side unless an attack clip runs (toolnone faded, the Rest grip)
        # hold-pose-2 (Codex ③): toolnone stays down (rest and attack); the grip Turn <-> Rest on the pose's clock (PoseStep)
        ("WeaponPose: toolnone down while held, the Rest grip while no attack runs (blended on the pose's clock)",
         "local want = WeaponPose.Want(kind, attacking)" in wp and "local attacking = fxAttacking(char)" in wp
         and "if math.abs(tr.WeightTarget - T.Low) > 1e-3 then tr:AdjustWeight(T.Low, T.Fade) end" in wp
         and 'local c1 = Config.WeaponGrip(kind, handle.Size.Y, nil, centre):Lerp(Config.WeaponGrip(kind, handle.Size.Y, "Rest", centre), share)' in wp
         and "weld.C1 = c1" in wp
         and "weld.Part1 == handle" in wp
         and "pcall(WeaponPose.RestStep, os.clock())" in wp and "function Fx.AttackPlaying(char)" in fx),
        ("ClassGrips: nine rows, each only its Weapon", len(rows) == 9 and all(line.rstrip().endswith("},") or "}, --" in line for line in rows)
         and all(k not in grips.split("Config.ClassGrips = {", 1)[1] for k in ("Hold =", "OneHand", "OffHand", "TwoHand", "Walk ="))),
        ("CharacterVisuals: no fist() angle rule left", "fist(" not in weapon.replace("old per-weapon fist() angle", "")),
        ("CharacterVisuals: mount never welds the Handle to itself", "if p ~= base then Util.Weld(base, p) end" in cv),
        ("buildWeapon makes a Tool held round its Handle", 'local model = Instance.new("Tool")' in weapon
         and "mount(model, parts, character, handle)" in weapon),
        ("HeroPreview keeps the weapon Tool", 'if inst:IsA("Tool") and inst.Name == "WeaponModel" then return true end' in hero),
        ("the Backpack hotbar stays off (a Tool shows no slot)", "Enum.CoreGuiType.Backpack, false" in vitals),
        ("Fx: the archer draw moves the bow (stepChar)",
         'Feel.bowHand(st, attack ~= nil and attack.Clip ~= nil and plain and st.AttackContext.Class == "Archer")' in fx),
        ("Fx: drop puts the bow back", "function Feel.drop(st)\n\tFeel.clearWeaponMotion(st)\n\tFeel.bowHand(st, false)" in fx),
        ("Fx: WeaponPose's old exports are gone", "Fx.SolveArm" not in fx and "function Fx.Animating" not in fx),
        ("Fx: death / a changed actor puts the bow back at once (stepChar)",
         "\t\tFeel.bowHand(st, false, true) -- death / a changed actor: the bow back on the right grip at once\n\t\tFeel.drop(st)\n\t\treturn" in fx),
        ("Fx: the bow's hold after a clip is a MOTION value (0.1 .. 0.5 s)", _hold_ok(fx)),
    ]
    try:
        motion = fx[fx.index("local MOTION = {"):fx.index("-- A14-4 combat feel: functions")]
        # (the attack clips as on main 11213d87; the one new MOTION line is the bow's hold, 최종 검수 10/13)
        motion = "\n".join(line for line in motion.split("\n") if not line.startswith("\tBOW_HOLD = "))
        out.append(("the attack clips as before (Fx MOTION)", sha(motion) == CLIP_SHA["MOTION"]))
        out.append(("hold-angles: no staff tip aim (Feel.staffPose gone)", "function Feel.staffPose(" not in fx))
        for name in ("archerPose",):
            out.append((f"the attack solve as before (Feel.{name})", sha(WM.source_function(fx, name)) == CLIP_SHA[name]))
    except ValueError:
        out.append(("the attack clips found", False))
    return out


def run(src: dict) -> tuple[list[tuple[str, bool]], str]:
    res, err = run_luau(src)
    return statics(src) + res, err


MUTATIONS = [
    ("CONFIG", "the sword's fist on the guard again (0.75)", '\tSword = { Point = 0.5, Rest = { 30, 0, 0 }, Hold = "SwordReady" },', '\tSword = { Point = 0.75, Rest = { 30, 0, 0 }, Hold = "SwordReady" },'),
    ("CONFIG", "the dark sword at 0.6", '\tDarkSword = { Point = 0.5, Rest = { 30, 0, 0 }, Hold = "SwordReady" },', '\tDarkSword = { Point = 0.6, Rest = { 30, 0, 0 }, Hold = "SwordReady" },'),
    ("CONFIG", "the sword back on the old side hold", '\tSword = { Point = 0.5, Rest = { 30, 0, 0 }, Hold = "SwordReady" },', '\tSword = { Point = 0.5, Rest = { 225, 0, 0 }, Hold = "Side" },'),
    ("CONFIG", "the rest blade tip up and back (the old 10/14 rest)", '\tDarkSword = { Point = 0.5, Rest = { 30, 0, 0 }, Hold = "SwordReady" },', '\tDarkSword = { Point = 0.5, Rest = { 130, 0, 0 }, Hold = "SwordReady" },'),
    ("CONFIG", "hold-angles: the staff turned upright in a hanging hand again", '\tStaff = { Point = 0.45, Rest = { 15, 0, 0 }, Hold = "Staff" },', '\tStaff = { Point = 0.45, Rest = { 81, 0, 0 }, Hold = "Staff" },'),
    ("CONFIG", "a weapon without a resting hold", '\tBaton = { Point = 0.3, Rest = { -38, 0, 0 }, Hold = "BatonReady" },', '\tBaton = { Point = 0.3 },'),
    ("CONFIG", "the rest mode ignored", '\tif mode == "Rest" and type(row.Rest) == "table" then turn = row.Rest end\n', ""),
    ("CONFIG", "the staff at the old 43%", '\tStaff = { Point = 0.45, Rest = { 15, 0, 0 }, Hold = "Staff" },', '\tStaff = { Point = 0.43, Rest = { 15, 0, 0 }, Hold = "Staff" },'),
    ("CONFIG", "the hammer held at its head", '\tHammer = { Point = 0.3, Rest = { 90, 0, 0 }, Hold = "HammerCarry" },', '\tHammer = { Point = 0.7, Rest = { 90, 0, 0 }, Hold = "HammerCarry" },'),
    ("CONFIG", "the bow flat across the side again", 'Bow = { Point = 0.5, Rest = { 90, -90, 0 }, Hold = "Bow" },', 'Bow = { Point = 0.5, Rest = { 90, 0, 0 }, Hold = "Bow" },'),
    ("CONFIG", "the joke weapons take the sword's new hold", 'Meme = { Point = 0.5, Rest = { 225, 0, 0 }, Hold = "Side" },', 'Meme = { Point = 0.5, Rest = { 30, 0, 0 }, Hold = "SwordReady" },'),
    ("CONFIG", "the short bow not canted", 'ShortBow = { Point = 0.5, Turn = { 0, 0, 15 }, Rest = { 90, -90, 0 }, Hold = "Bow" },', 'ShortBow = { Point = 0.5, Rest = { 90, -90, 0 }, Hold = "Bow" },'),
    ("CONFIG", "Tool.Grip without the turn", "local grip = CFrame.new(0, (point - 0.5) * (tonumber(len) or 0), 0) * angles:Inverse()",
     "local grip = CFrame.new(0, (point - 0.5) * (tonumber(len) or 0), 0)"),
    ("CONFIG", "Tool.Grip measured from the other end", "local grip = CFrame.new(0, (point - 0.5) * (tonumber(len) or 0), 0) * angles:Inverse()",
     "local grip = CFrame.new(0, (0.5 - point) * (tonumber(len) or 0), 0) * angles:Inverse()"),
    ("CONFIG", "grip-centre: the fist's centre ignored (the fingertip face again)", "\tif typeof(centre) == \"Vector3\" then grip *= CFrame.new(-centre) end\n", "\n"),
    ("CONFIG", "a standing pose back in ClassGrips", '\tWarrior_Halo = { Weapon = "Sword" },',
     '\tWarrior_Halo = { Weapon = "Sword", Hold = { Waist = { 3, 0, 0 } } },'),
    ("CV", "the bow in the left hand again", 'local hand = Util.FindPart(character, "RightHand", "Right Arm")',
     'local hand = (kind == "Bow" or kind == "ShortBow") and Util.FindPart(character, "LeftHand", "Left Arm") or Util.FindPart(character, "RightHand", "Right Arm")'),
    ("CV", "a Model, not a Tool", 'local model = Instance.new("Tool")', 'local model = Instance.new("Model")'),
    ("CV", "clicks activate the Tool", "model.ManualActivationOnly = true", "model.ManualActivationOnly = false"),
    ("CV", "the Tool can be dropped", "model.CanBeDropped = false", "model.CanBeDropped = true"),
    ("CV", "Tool.Grip not set", "\tmodel.Grip = grip\n", "\n"),
    ("CV", "the parts built where the weld does not hold them", "local place = hand.CFrame * attCF * grip:Inverse()",
     "local place = hand.CFrame * attCF"),
    ("CV", "the grip attachment's turn ignored (the hand's own axes)", "\tif att and att:IsA(\"Attachment\") then return att.CFrame end",
     "\tif att and att:IsA(\"Attachment\") then return CFrame.new(att.Position) end"),
    ("CV", "the parts welded to the hand", "mount(model, parts, character, handle)", "mount(model, parts, character, hand)"),
    ("CV", "the mount welds the Handle to itself", "if p ~= base then Util.Weld(base, p) end", "Util.Weld(base, p)"),
    ("CV", "the flask staff's wrap at the shaft's middle", "CFrame = H * CFrame.new(0, (point - 0.5) * shaftLen * sc, 0),", "CFrame = H,"),
    ("CV", "the bow's draw spots in the right hand's space", 'model:SetAttribute("HandMuzzle", toLeft * (main.CFrame * muzzle.CFrame))',
     'model:SetAttribute("HandMuzzle", hand.CFrame:ToObjectSpace(main.CFrame * muzzle.CFrame))'),
    ("CV", "the bow's string on the far side", "CFrame = H * CFrame.new(0, 0, sag * sc),", "CFrame = H * CFrame.new(0, 0, -sag * sc),"),
    ("CV", "the staff's orb sunk onto the shaft (by the hand)", "CFrame = H * CFrame.new(0, (shaftLen / 2 + d * 0.35) * sc, 0),",
     "CFrame = H * CFrame.new(0, (shaftLen / 2 - d) * sc, 0),"),
    ("CV", "the staff 0.8 of the height", "Staff = { 0.65, 0.75 }", "Staff = { 0.8, 0.9 }"),
    ("FX", "the draw never moves the bow", "\t\trightGrip.Enabled = false\n\t\tweld.Parent = handle\n", "\t\tweld.Parent = nil\n"),
    ("FX", "the bow on the right grip's spot in the left hand", "\t\tweld.C1 = weapon.Grip\n", "\t\tweld.C1 = CFrame.identity\n"),
    ("FX", "the bow never comes back", "\t\tif cur.Right.Parent and cur.Right.Part1 == cur.Handle then cur.Right.Enabled = true end\n", ""),
    # 최종 검수 10/13 review: one weld per bow, the hold between rapid shots, death at once
    ("FX", "a new weld every shot", "\tif cur then -- a draw again", "\tif false then -- a draw again"),
    ("FX", "no hold: back the moment a clip ends", "\t\tif now then\n\t\t\tFeel.bowRight(cur)\n", "\t\tif true then\n\t\t\tFeel.bowRight(cur)\n"),
    ("FX", "a stale return wins over a new draw", "if st.BowGrip == cur and cur.Back == token then Feel.bowRight(cur) end",
     "if st.BowGrip == cur then Feel.bowRight(cur) end"),
    ("FX", "the weld thrown away after each draw", "\t\tcur.Weld.Enabled = false\n", "\t\tcur.Weld.Enabled = false\n\t\tcur.Weld:Destroy()\n"),
    ("FX", "death keeps the bow in the left hand", "\t\tFeel.bowHand(st, false, true) -- death / a changed actor: the bow back on the right grip at once\n", ""),
    ("HUD_MAIN", "the portrait copies the character for every bow shot", 'if object.Name == "WeaponModel" or object:FindFirstAncestor("WeaponModel")',
     'if object.Name == "WeaponModel"'),
    ("HUD_MAIN", "the portrait copies on the engine's RightGrip", 'or (object.Name == "RightGrip" and object:IsA("JointInstance")) then',
     'or false then'),
    ("FX", "drop leaves the bow in the left hand", "\tFeel.clearWeaponMotion(st)\n\tFeel.bowHand(st, false)\n", "\tFeel.clearWeaponMotion(st)\n"),
    ("FX", "a sword moved too", 'weapon:GetAttribute("AttackHand") == "LeftHand" and weapon:FindFirstChild("Handle")', 'weapon:FindFirstChild("Handle")'),
    ("FX", "an attack clip changed", "PaladinSwing", "PaladinSwing2"),
    ("WP", "the sword never rests", 'Config.WeaponGrip(kind, handle.Size.Y, nil, centre):Lerp(Config.WeaponGrip(kind, handle.Size.Y, "Rest", centre), share)',
     "Config.WeaponGrip(kind, handle.Size.Y, nil, centre)"),
    ("WP", "rests during an attack too", "local want = WeaponPose.Want(kind, attacking)", "local want = WeaponPose.Want(kind, false)"),
    ("WP", "the rest step never runs", "local okR, errR = pcall(WeaponPose.RestStep, os.clock())", "local okR, errR = true, nil"),
    ("WP", "the weld never turns (Tool.Grip only: the engine weld kept the blade level)", "weld.C1 = c1", "local _ = c1"),
    ("WP", "toolnone raised for an attack again", "if math.abs(tr.WeightTarget - T.Low) > 1e-3 then tr:AdjustWeight(T.Low, T.Fade) end",
     "local w = rest and T.Low or 1 if math.abs(tr.WeightTarget - w) > 1e-3 then tr:AdjustWeight(w, 0) end"),
    ("WP", "WeaponPose writes a joint again", "function WeaponPose.Step(dt)\n", "function WeaponPose.Step(dt)\n\tlocal m = nil; if m then m.Transform = CFrame.identity end\n"),
    ("HERO", "the Hero preview drops the weapon Tool", 'if inst:IsA("Tool") and inst.Name == "WeaponModel" then return true end', ""),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    res, err = run(src)
    for name, ok in res:
        print(("CHECK_OK   " if ok else "CHECK_FAIL ") + name)
    if err.strip():
        print(err)
    failed = [n for n, ok in res if not ok]
    muts = []
    for key, name, old, new in MUTATIONS:
        hits = src[key].count(old)
        caught = False
        if hits >= 1:
            mutated = dict(src)
            mutated[key] = src[key].replace(old, new, 1)
            caught = not all(ok for _, ok in run(mutated)[0])
        muts.append({"file": key, "name": name, "applied": hits >= 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits >= 1 else " (not applied)"))
    ok = not failed and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": len(res), "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Named checks: {len(res) - len(failed)} passed, {len(failed)} failing")
    print(f"MUTATIONS caught={sum(m['caught'] for m in muts)}/{len(muts)}")
    print(f"Status: {status}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
