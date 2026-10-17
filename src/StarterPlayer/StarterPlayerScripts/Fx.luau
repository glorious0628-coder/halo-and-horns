-- Fx.luau : client-side effects for Halo & Horns (G11).
-- Plays every server "Fx" remote kind (TECH_SPEC §5), pooled damage numbers, class swing / release shapes, camera
-- shake, built-in sounds, the hurt edge flash, the own level-up "next unlock" announce (addendum A7-3), the kill
-- combo counter and the A9-2 hit feel (local white flash on monsters I hit, number pop, number merging), my own
-- attack animations (stock Roblox animations on my character; they replicate) and the monster attack lunge / hit
-- recoil (local tweens of the monster's VisualJoint.C0).
-- A14-4 combat feel: procedural R15 attack / hurt clips (avatar joint Transform layers, every client animates every nearby
-- character from the Fx), slash / spark / magic / dust / shock-ring art with code fallbacks, hit-stop + camera kick,
-- monster wind-up telegraph (WindupAt), pain stickers over hurt monsters (HurtSeq) and players (Pain Fx).
-- Everything here is local-only and purely cosmetic; the server never trusts anything from it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))
local Ground = require(Shared:WaitForChild("Ground")) -- the walking ground (Config.Ground)

local LocalPlayer = Players.LocalPlayer

local Fx = {}

local C = nil -- client registry (set in Init)

----------------------------------------------------------------- constants
local VIS = Config.Visuals or {}
local CULL_DISTANCE = VIS.FxCullDistance or 150
local POPUP_COUNT = math.max(5, VIS.MaxDamagePopups or 25)
local HUGE_SCALE = VIS.HugeNumberScale or 2.5
local SHAKE_OWN = VIS.ShakeOwnRelease or 0.6
local SHAKE_NEAR = VIS.ShakeNearRelease or 0.25
local SHAKE_NEAR_DIST = VIS.ShakeNearDistance or 40

local COMBO_CFG = Config.Combo or {}
local COMBO_RESET = COMBO_CFG.ResetSeconds or 4
local COMBO_MILESTONES = COMBO_CFG.Milestones or {}
local COMBO_SHOW_AT = 5

local NUMBER_W, NUMBER_H = 140, 44
local NUMBER_RISE = 3
local NUMBER_LIFE = 0.8

-- addendum A9-2 hit feel (white flash on my hits, crit / my-release number pop, number merging)
local HIT_CFG = Config.HitFeel or {}
local FLASH_TIME = HIT_CFG.FlashTime or 0.06
local POP_SCALE = HIT_CFG.PopScale or 1.4
local POP_TIME = HIT_CFG.PopTime or 0.1
local MERGE_WINDOW = HIT_CFG.MergeWindow or 0.25
-- CR-L42: both radii come from Config.HitFeel (studs)
local MERGE_DIST = HIT_CFG.MergeRadius or 3 -- numbers spawned this close (and within MERGE_WINDOW) add into one label
local FLASH_DIST = HIT_CFG.FlashRadius or 3 -- monsters whose root is this close to one of my hit positions flash white

local WHITE = Color3.new(1, 1, 1)
local COLOR_CRIT = Color3.fromRGB(255, 225, 60)
local COLOR_PVP = Color3.fromRGB(255, 70, 70)
local COLOR_HURT = Color3.fromRGB(255, 55, 55)
local COLOR_GOLD = Color3.fromRGB(255, 210, 60)
local COLOR_XP = Color3.fromRGB(90, 170, 255)
local COLOR_PERFECT = Color3.fromRGB(255, 215, 70)
local COLOR_FALLBACK = Color3.fromRGB(175, 175, 185)
local COLOR_STOMP = Color3.fromRGB(255, 50, 40)
local COLOR_DUST = Color3.fromRGB(170, 150, 120)
local COLOR_SMOKE = Color3.fromRGB(35, 25, 40)
local COLOR_FIRE = Color3.fromRGB(255, 140, 50)
local COLOR_PILLAR = Color3.fromRGB(255, 240, 150)
local COLOR_HORNS_WIN = Color3.fromRGB(220, 50, 60)

local SOUND_MIN_GAP = 0.06 -- seconds between two plays of the same sound
local SOUND_VOLUME = { Swing = 0.35, Release = 0.6, Coin = 0.35, Click = 0.4 }

local SHAKE_BIND_NAME = "HaloHornsFxShake"
local MAX_SHAKE = 3

local FONT_NUMBER = Enum.Font.DenkOne -- A23-63 (user 2026-10-07) / UI ideas #7: damage numbers, combo and milestone in Denk One
local MIN_TEXT_SIZE = (Config.UI and Config.UI.MinTextSize) or 11 -- addendum M1

-- A7-3 level-up banner removed (A23-191, user 10/14: no blue banners at all)
local TXT_BANK = "Vault +%s"

-- B14 loot popups / toasts (2026-10-05 loot review). One table: Fx.luau is close to the 200-locals limit.
-- Popups live Life s (damage numbers keep NUMBER_LIFE), are Wide x wider and stack by Step label heights in screen
-- space (BillboardGui.SizeOffset), so a king-slime drop stays readable on a phone. Scroll drops also get a toast;
-- the first one of a session (item list not opened yet) carries the "where to use it" hint for HintSeconds.
local LOOT_UI = {
	Life = 1.8, Wide = 1.9, Scale = 0.9, WeaponScale = 1.2, Step = 1.05, MaxLines = 5,
	ToastSeconds = 2.5, HintSeconds = 6, Hinted = false,
	Text = Config.ClientText.FxLoot, -- the words: Config.ClientText.FxLoot (moved 10/14)
}

-- attack motion tuning, one table (Fx.luau is close to Luau's 200-locals-per-function limit)
local MOTION = {
	-- own attack animations: Roblox-owned stock animations (usable in any experience), played ONLY on my own
	-- character (tracks of my character's Animator replicate to everyone, so other characters are never animated here)
	ANIM_IDS = {
		R15 = {
			Slash = "rbxassetid://522635514", -- toolslash
			Lunge = "rbxassetid://522638767", -- toollunge
			Point = "rbxassetid://507770453", -- point
		},
		R6 = {
			Slash = "rbxassetid://129967390", -- toolslash
			Lunge = "rbxassetid://129967478", -- toollunge
		},
	},
	ANIM_FALLBACK = { Point = "Lunge" }, -- move -> move used when the rig has no stock id for it (R6 point)
	CLASS_MOVES = {
		Warrior = { Swing = "Slash", Release = "Lunge" }, -- sword slash, big lunge for the shockwave
		Mage = { Swing = "Point", Release = "Slash" }, -- cast forward, overhead call for the meteor
		Archer = { Swing = "Lunge", Release = "Slash" }, -- quick shot forward, overhead volley for the arrow rain
	},
	SWING_FIT = 0.9, -- a swing move finishes within this fraction of the class SwingInterval
	RELEASE_ANIM_TIME = 0.75, -- the release move finishes within this many seconds
	RELEASE_HOLD = 0.6, -- swings do not cut the release move short for this many seconds
	CUT_BLEND = 0.06, -- A23-116: a move cutting another blends from the last pose this long (no snap)
	ANIM_MAX_SPEED = 4,
	ANIM_FADE_IN = 0.05,
	ANIM_FADE_OUT = 0.12,

	-- monster attack motion. MonsterService welds every visible monster part to "VisualRoot", which hangs off the root
	-- by the Weld "VisualJoint" (C0 = identity); the server never writes C0 after spawn, so a local C0 tween sticks.
	MONSTER_FOLDER = "Monsters",
	VISUAL_ROOT_NAME = "VisualRoot",
	VISUAL_JOINT_NAME = "VisualJoint",
	ATTACK_SEQ_ATTR = "AttackSeq", -- the server bumps it on every monster hit on a player
	DEFAULT_BODY_HEIGHT = 5,
	-- distances are fractions of the body height, angles in degrees (lean pivots on the floor under the root)
	LUNGE_WINDUP_TIME = 0.08, LUNGE_WINDUP_BACK = 0.08, LUNGE_WINDUP_TILT = 10, -- step back, lean back
	LUNGE_TIME = 0.1, LUNGE_DIST = 0.35, LUNGE_TILT = 20, -- forward (-Z in root space), lean forward
	LUNGE_RETURN_TIME = 0.2,
	HOP_SQUASH_TIME = 0.08, HOP_SQUASH_DOWN = 0.06, HOP_SQUASH_BACK = 0.06, HOP_SQUASH_TILT = 6, -- slime crouch
	HOP_TIME = 0.12, HOP_UP = 0.2, HOP_FWD = 0.3, HOP_TILT = 12, -- slime hop up + forward
	HOP_LAND_TIME = 0.18,
	-- recoil of monsters my hits land on: tilt away + a visual push back along the hit direction on top of the server
	-- shove (A15 Config.HitReact.Shove*); Release hits x RECOIL_RELEASE
	RECOIL_IN = 0.05, RECOIL_OUT = 0.16, RECOIL_TILT = 15, RECOIL_PUSH = 0.08, RECOIL_RELEASE = 1.4,

	-- A14-4 monster telegraph (A15 server half): the server sets the model attribute WindupAt
	-- (workspace:GetServerTimeNow() of the wind-up start); the strike follows with AttackSeq +1 or never (cancelled).
	-- Wind-up length = attribute WindupTime, else Config.HitReact.MonsterWindup, else TELE_DEFAULT.
	WINDUP_ATTR = "WindupAt",
	WINDUP_TIME_ATTR = "WindupTime",
	TELE_DEFAULT = 0.28,
	TELE_IN = 0.12, TELE_BACK = 0.06, TELE_DOWN = 0.05, TELE_TILT = 14, -- lean back + crouch
	TELE_BACK2 = 0.09, TELE_DOWN2 = 0.08, TELE_TILT2 = 19, -- ... deepening while the wind-up lasts
	SLIME_TELE_DOWN = 0.12, SLIME_TELE_DOWN2 = 0.16, SLIME_TELE_TILT = 6, -- slimes squash down instead
	TELE_FLASH = 0.1, TELE_COLOR = Color3.fromRGB(255, 70, 60), -- red tint blink at the start and right before the strike
	TELE_GRACE = 0.35, -- no strike this long after the wind-up -> back to rest
	TELE_LUNGE_WINDOW = 0.6, -- AttackSeq this soon after a telegraph skips the lunge's own short wind-up
	-- A14-4 pain: the server bumps HurtSeq on every hit on a monster (HurtBig = true, or = the HurtSeq value, for a big one)
	HURT_SEQ_ATTR = "HurtSeq",
	HURT_BIG_ATTR = "HurtBig",
	FLINCH_IN = 0.05, FLINCH_OUT = 0.14, FLINCH_DOWN = 0.05, FLINCH_BACK = 0.04, FLINCH_TILT = 9, FLINCH_BIG = 1.6,
	FLINCH_SKIP = 0.15, -- no squash flinch this soon after my own directional recoil started
	-- HurtSeq arrives when the damage lands, the hit shows later (clip contact frame / projectile flight): Swing /
	-- Release remember where their hits will show and the pain reaction waits for that moment (HURT_SYNC_MAX cap)
	HURT_SYNC_WAIT = 0.05, -- s to let the Swing / Release Fx of the same server frame arrive first
	HURT_SYNC_MAX = 0.6,
	-- 손맛 ③⑤ (PhoneTest 10/16: +G showed 15-50 ms before the arrow / orb's damage number): a kill's reward and calm
	-- start this long after its hit shows
	HIT_AFTER = 0.08,
	PENDING_MAX = 24, PENDING_DIST = 4, -- remembered hit slots (ring buffer), studs a monster may be off its hit point
	-- pain stickers (GPT art Emo*, code fallback below): pooled BillboardGuis in PlayerGui, one per monster at a time
	-- stickers sit BESIDE the head (screen right), never over the HP bar / nametag above it, and rise only a little
	STICKER_MAX = 12, STICKER_LIFE = 0.6, STICKER_POP = 0.16, STICKER_FADE = 0.25, STICKER_RISE = 0.6,
	STICKER_TILT = 12, STICKER_DIST = 90, STICKER_SIDE = 0.85, -- side offset (screen right) as a fraction of the size
	MONSTER_STICKER_K = 0.45, MONSTER_STICKER_MIN = 2.2, MONSTER_STICKER_MAX = 5, -- size = body height x K (studs)
	MONSTER_STICKER_Y = -0.35, -- sticker centre: head top + this x size
	MONSTER_STICKER_GAP = 1.0, -- s between two stickers of one monster (the HP bar stays readable in between)
	PLAYER_STICKER_SIZE = 2.4, PLAYER_STICKER_Y = 0.4, -- studs above the head centre
	OWN_STICKER_MULT = 0.7, -- my own sticker is smaller (it sits right next to the screen centre)
	PAIN_GAP = 0.3, -- one player sticker / flinch per this many seconds (Pain and Hurt both trigger it; < server PainGap)
	PAIN_GAP_OWN = 0.8, -- ... for myself (the damage number + edge flash already mark every hit)
	PAIN_KICK = 0.14, PAIN_KICK_TIME = 0.12, -- camera kick when I get hurt: big hits only ...
	PAIN_KICK_FRAC = 0.1, -- ... or a Hurt of >= this fraction of my MaxHealth
	-- red screen edges (quality ideas 2026-10-06 #6: they showed in every screenshot): a hit flashes them by its size
	-- (Small share of my MaxHealth or less = almost invisible SmallT, Big or more = BigT), below LowHP the edges throb
	-- slowly (PulseHi <-> PulseLo transparency, Period s); never over an open window (bag / map / pickers); with shake
	-- off: no flash or throb, only a steady faint edge (CalmT) while my HP is low
	EDGE = { Small = 0.05, Big = 0.15, SmallT = 0.94, BigT = 0.35, Fade = 0.45, LowHP = 0.3, PulseHi = 0.55, PulseLo = 0.85,
		Period = 1.1, CalmT = 0.82, FlashUntil = 0 },
	EMO_HURT = { "EmoOuch", "EmoStress", "EmoTears", "EmoAngry" },
	EMO_BIG = { "EmoDizzy", "EmoDizzy", "EmoOuch" }, -- big hits: mostly dizzy, sometimes 아야!
	EMO_FALLBACK = { -- code-drawn stickers while the art ids are empty (emoji via \u escapes)
		EmoOuch = { Text = "Ouch!", Color = Color3.fromRGB(225, 40, 40), Bubble = true },
		EmoAlert = { Text = "!", Color = Color3.fromRGB(255, 190, 30), Bubble = true }, -- a monster spots me (AlertAt)
		EmoTears = { Text = "\u{1F4A7}\u{1F4A7}", Color = Color3.fromRGB(80, 170, 255) },
		EmoDizzy = { Text = "\u{1F4AB}", Color = Color3.fromRGB(255, 215, 60) },
		EmoAngry = { Text = "\u{1F4A2}", Color = Color3.fromRGB(235, 40, 40) },
		EmoStress = { Text = "!!", Color = Color3.fromRGB(235, 40, 40) },
	},
	STICKER_INK = Color3.fromRGB(34, 20, 10),

	-- A14-4 my hits: spark art (pop 0.6 -> 1.2, fade), hit-stop of my attack layer / track, small camera kick
	SPARK_SIZE = 3.2, SPARK_TIME = 0.15, SPARK_MAX = 6, SPARK_CRIT_MULT = 1.4,
	SPARK_TINT = Color3.fromRGB(255, 240, 190), -- fallback star: short rays / core of a normal hit (crits: COLOR_CRIT)
	HITSTOP_RATE = 0.05, HITSTOP_TIME = 0.08, HITSTOP_CRIT = 0.12, -- Warrior contact frames only
	RECOIL_RANGED = 1.3, -- 손맛 G3: my manual arrow / orb hits push the monster this much more
	KICK = 0.16, KICK_CRIT = 0.1, KICK_TIME = 0.1, -- manual swings and crits only (auto farming never jitters)
	-- swing art: slash arc (Warrior), arrow streak (Archer), magic burst at the target (Mage); timed to the clips below
	SLASH_SIZE = 5.5, SLASH_TIME = 0.18, SLASH_DIST = 2.6, SLASH_ROT0 = -35, SLASH_ROT1 = 15,
	SLASH_FROM = -45, SLASH_TO = 115, SLASH_PLANE_TILT = 30, -- fallback Trail sweep (degrees around the look axis)
	SLASH_VFX_AT = 0.17, -- approved wind-up -> diagonal cut
	-- 검수 10/08 (촬영 편집 + the user's HUD photo: a yellow floor oval after every attack looked like a glitch): a basic
	-- attack draws no floor disc around the attacker any more (the slash / arrow / orb and the hit sparks show the hit; a
	-- flat disc half sank into the new hills). Only MY punch / magic hit keeps a small, faint, quick mark at the target;
	-- other players' basic attacks draw none. Skills keep their area rings (the area matters there).
	HIT_RING = { Grow = 0.08, Fade = 0.14, Transparency = 0.78, Thickness = 0.06, Radius = 1.3 },
	SLASH_CONTACT = 0.23,
	SMASH_VFX_AT = 0.17, SMASH_AT = 0.24, -- Warrior release: big slash, then the shockwave impact
	CAST_DELAY = 0.24, -- left-hand gather -> staff-tip cast
	SHOT_DELAY = 0.22, -- aim -> visible draw -> release
	RELEASE_CONTACT = { Warrior = 0.24, Mage = 0.35, Archer = 0.4 },
	RELEASE_LAUNCH = { Mage = 0.35, Archer = 0.18 },
	UPPER_BLEND = { Waist = 0.5, Neck = 0.7, RightShoulder = 1, RightElbow = 1, RightWrist = 1,
		LeftShoulder = 1, LeftElbow = 1, LeftWrist = 1 },
	LAYER_FADE_IN = 0.045, LAYER_FADE_OUT = 0.1,
	BOW = { Extend = 0.995, CheekSide = 0.27, CheekDown = 0.18, CheekFront = 0.32,
		DrawStart = 0.055, SnapTime = 0.05, AimIn = 0.065, Settle = 0.105 },
	BOW_HOLD = 0.25, -- A23-150 7 (최종 검수 10/13): s a bow stays in the left hand after an archer clip (Feel.bowHand)
	STREAK_LIFE = 0.12,
	MAGIC_SIZE = 4, MAGIC_COLOR = Color3.fromRGB(190, 140, 255),

	-- A14-4 procedural animation. AnimationClipProvider:RegisterActiveAnimationClip ids work in Studio only (docs), so
	-- clips write Motor6D / AnimationConstraint.Transform in PreSimulation (the Animator writes it before that,
	-- so the clip adds on top of walk / idle). Transform does not replicate: every client animates every nearby R15
	-- character from the Swing / Release / Pain Fx. R6 rigs (or PROCEDURAL = false) keep the stock animations above.
	PROCEDURAL = true,
	PROC_MAX_CHARS = 12, -- characters animated at once (my own always)
	PROC_DIST = 120, -- studs from the camera
	JOINT_PARTS = { -- R15 joint -> its connected child body part (independent of the joint's parent/name)
		Waist = "UpperTorso", Neck = "Head", RightShoulder = "RightUpperArm", RightElbow = "RightLowerArm",
		RightWrist = "RightHand", LeftShoulder = "LeftUpperArm", LeftElbow = "LeftLowerArm", LeftWrist = "LeftHand",
	},
	JOINT_PARENTS = {
		Waist = "LowerTorso", Neck = "UpperTorso", RightShoulder = "UpperTorso", RightElbow = "RightUpperArm",
		RightWrist = "RightLowerArm", LeftShoulder = "UpperTorso", LeftElbow = "LeftUpperArm", LeftWrist = "LeftLowerArm",
	},
	-- clip = { Len = s, Keys = { { time, ease of the segment ending here, { Joint = { rx, ry, rz } } } } }: degrees in
	-- joint space (+rx raises an arm forward / leans the torso or head back, +rz swings an arm to the character's right,
	-- +ry turns left); joints missing from a key are at rest there. Consecutive keys stay < 180 degrees apart (slerp).
	CLIPS = {
		WarriorSwing = { Len = 0.68, Keys = { -- planted wind-up -> weighted diagonal cut -> settle
			{ 0, "Out", {} },
			{ 0.1, "Out", { Waist = { 6, -18, -4 }, Neck = { -2, 12, 2 }, RightShoulder = { 110, -10, 22 }, RightElbow = { 55, 0, 0 }, RightWrist = { -45, 0, 12 }, LeftShoulder = { 25, 0, -18 } } },
			{ 0.17, "InOut", { Waist = { 12, -30, -6 }, Neck = { -4, 20, 3 }, RightShoulder = { 145, -12, 28 }, RightElbow = { 72, 0, 0 }, RightWrist = { -75, 0, 18 }, LeftShoulder = { 38, 0, -25 }, LeftElbow = { 25, 0, 0 } } },
			{ 0.23, "In", { Waist = { -12, 22, 7 }, Neck = { 5, -14, -3 }, RightShoulder = { 65, 0, -32 }, RightElbow = { 10, 0, 0 }, RightWrist = { -80, 0, -12 }, LeftShoulder = { -12, 0, -30 } } },
			{ 0.32, "Out", { Waist = { -16, 34, 8 }, Neck = { 7, -18, -4 }, RightShoulder = { 28, -14, -48 }, RightElbow = { 18, 0, 0 }, RightWrist = { -55, 0, -18 }, LeftShoulder = { -20, 0, -32 } } },
			{ 0.48, "InOut", { Waist = { -4, 12, 2 }, Neck = { 2, -6, 0 }, RightShoulder = { 24, 0, -15 }, RightElbow = { 26, 0, 0 } } },
			{ 0.68, "InOut", {} },
		} },
		-- the one-hand overhead smash (the Blacksmith's hammer Q; the class default): the right hand takes the tool back
		-- over the shoulder, then down in a vertical arc in front. 게임성 검수 10/11 (A23-128 one hand): the free left arm
		-- no longer mirrors it overhead (that read as the other hand on the tool too) - it steadies low in front on the wind-up and swings
		-- out to the side for balance on the hit (references: a one-hand hammer swings vertically, head back over the
		-- shoulder, the off hand a support or counterweight, never a second striking arm - grip_reference §1-9)
		WarriorRelease = { Len = 0.7, Keys = {
			{ 0, "Out", {} },
			{ 0.16, "Out", { Waist = { 18, -10, 0 }, Neck = { -8, 6, 0 }, RightShoulder = { 168, 0, 12 }, RightElbow = { 95, 0, 0 }, RightWrist = { -100, 0, 0 }, LeftShoulder = { 40, 0, -20 }, LeftElbow = { 30, 0, 0 } } },
			{ 0.24, "In", { Waist = { -30, 6, 0 }, Neck = { 18, 0, 0 }, RightShoulder = { 58, 0, -12 }, RightElbow = { 6, 0, 0 }, RightWrist = { -75, 0, 0 }, LeftShoulder = { 18, 0, -40 }, LeftElbow = { 20, 0, 0 } } },
			{ 0.44, "Out", { Waist = { -24, 4, 0 }, Neck = { 15, 0, 0 }, RightShoulder = { 48, 0, -10 }, RightElbow = { 10, 0, 0 }, RightWrist = { -58, 0, 0 }, LeftShoulder = { 20, 0, -34 }, LeftElbow = { 22, 0, 0 } } },
			{ 0.7, "InOut", {} },
		} },
		MageSwing = { Len = 0.68, Keys = { -- left palm gathers; right wrist points the staff tip forward
			{ 0, "Out", {} },
			{ 0.1, "Out", { Waist = { 8, -14, -3 }, Neck = { -3, 8, 0 }, RightShoulder = { 28, -8, 14 }, RightElbow = { 38, 0, 0 }, RightWrist = { 28, 0, 8 }, LeftShoulder = { 60, 5, -18 }, LeftElbow = { 48, 0, 0 }, LeftWrist = { -70, 0, -15 } } },
			{ 0.19, "InOut", { Waist = { 12, -18, -4 }, Neck = { -4, 12, 0 }, RightShoulder = { 34, -8, 12 }, RightElbow = { 40, 0, 0 }, RightWrist = { 28, 0, 8 }, LeftShoulder = { 78, 8, -22 }, LeftElbow = { 42, 0, 0 }, LeftWrist = { -85, 0, -12 } } },
			{ 0.24, "In", { Waist = { -9, 10, 4 }, Neck = { 4, -6, 0 }, RightShoulder = { 38, 0, -8 }, RightElbow = { 4, 0, 0 }, RightWrist = { 28, 0, -4 }, LeftShoulder = { 64, 0, -32 }, LeftElbow = { 24, 0, 0 }, LeftWrist = { -65, 0, -12 } } },
			{ 0.36, "Out", { Waist = { -6, 8, 3 }, Neck = { 3, -4, 0 }, RightShoulder = { 34, 0, -6 }, RightElbow = { 10, 0, 0 }, RightWrist = { 28, 0, -2 }, LeftShoulder = { 42, 0, -26 }, LeftElbow = { 22, 0, 0 } } },
			{ 0.5, "InOut", { Waist = { 0, 3, 0 }, RightShoulder = { 18, 0, 0 }, RightElbow = { 18, 0, 0 }, RightWrist = { 15, 0, 0 }, LeftShoulder = { 15, 0, -8 } } },
			{ 0.68, "InOut", {} },
		} },
		MageRelease = { Len = 0.75, Keys = { -- left hand calls the meteor; right staff thrust meets its impact
			{ 0, "Out", {} },
			{ 0.15, "Out", { Waist = { 12, -12, 0 }, Neck = { 12, 8, 0 }, RightShoulder = { 30, -8, 16 }, RightElbow = { 40, 0, 0 }, RightWrist = { 42, 0, 8 }, LeftShoulder = { 86, 0, -24 }, LeftElbow = { 42, 0, 0 }, LeftWrist = { -92, 0, -12 } } },
			{ 0.33, "InOut", { Waist = { 16, -18, 0 }, Neck = { 16, 12, 0 }, RightShoulder = { 36, -8, 18 }, RightElbow = { 38, 0, 0 }, RightWrist = { 42, 0, 8 }, LeftShoulder = { 116, 0, -28 }, LeftElbow = { 24, 0, 0 }, LeftWrist = { -95, 0, -12 } } },
			{ 0.35, "In", { Waist = { -22, 0, 0 }, Neck = { 6, 0, 0 }, RightShoulder = { 38, 0, 8 }, RightElbow = { 4, 0, 0 }, RightWrist = { 42, 0, 0 }, LeftShoulder = { 75, 0, -8 }, LeftElbow = { 0, 0, 0 }, LeftWrist = { -65, 0, 0 } } },
			{ 0.55, "Out", { Waist = { -16, 0, 0 }, Neck = { 6, 0, 0 }, RightShoulder = { 68, 0, 8 }, RightElbow = { 5, 0, 0 }, LeftShoulder = { 68, 0, -8 }, LeftElbow = { 5, 0, 0 } } },
			{ 0.75, "InOut", {} },
		} },
		ArcherSwing = { Len = 0.44, Keys = { -- actual grip/arm lengths solve the six arm joints below
			{ 0, "Out", {} },
			{ 0.07, "Out", { Waist = { 0, -58, 0 }, Neck = { 0, 58, 0 } } },
			{ 0.19, "InOut", { Waist = { 0, -65, 0 }, Neck = { 0, 65, 0 } } },
			{ 0.22, "In", { Waist = { 0, -65, 0 }, Neck = { 0, 65, 0 } } },
			{ 0.29, "Out", { Waist = { 0, -60, 0 }, Neck = { 0, 60, 0 } } },
			{ 0.44, "InOut", {} },
		} },
		-- A23-116 Q (docs/design/skills18_2026-10-10.md): the Berserker's Crater Smash - the dark sword lifted high in the
		-- right hand behind the head with a big lean back, the free left arm reaching forward for balance (A23-128 one-hand
		-- sword, 검수 10/11: no empty fist on the hilt), a deep smash on RELEASE_CONTACT.Warrior with the left arm flung
		-- out behind, held, back up
		BerserkerRelease = { Len = 0.7, Keys = {
			{ 0, "Out", {} },
			{ 0.14, "Out", { Waist = { 24, -6, 0 }, Neck = { -10, 4, 0 }, RightShoulder = { 172, 0, 10 }, RightElbow = { 90, 0, 0 }, RightWrist = { -90, 0, 0 }, LeftShoulder = { 70, 0, -22 }, LeftElbow = { 36, 0, 0 } } },
			{ 0.24, "In", { Waist = { -40, 0, 0 }, Neck = { 18, 0, 0 }, RightShoulder = { 60, 0, -14 }, RightElbow = { 6, 0, 0 }, RightWrist = { -86, 0, 0 }, LeftShoulder = { 10, 0, -46 }, LeftElbow = { 20, 0, 0 } } },
			{ 0.44, "Out", { Waist = { -34, 0, 0 }, Neck = { 16, 0, 0 }, RightShoulder = { 52, 0, -12 }, RightElbow = { 10, 0, 0 }, RightWrist = { -80, 0, 0 }, LeftShoulder = { 14, 0, -40 }, LeftElbow = { 24, 0, 0 } } },
			{ 0.7, "InOut", {} },
		} },
		-- the Dark Mage's Purple Pop: crouched, the left palm sweeping low, then lifting something up on
		-- RELEASE_CONTACT.Mage (hold-angles 10/16: no tip aim; the wrist leans the staff about 30 forward, the magic from the orb)
		DarkMageRelease = { Len = 0.75, Keys = {
			{ 0, "Out", {} },
			{ 0.2, "Out", { Waist = { -20, 0, 0 }, Neck = { 6, 0, 0 }, RightShoulder = { 30, 0, 10 }, RightElbow = { 40, 0, 0 }, RightWrist = { 42, 0, 0 }, LeftShoulder = { 40, 0, -20 }, LeftElbow = { 30, 0, 0 }, LeftWrist = { -60, 0, 0 } } },
			{ 0.33, "InOut", { Waist = { -24, 4, 0 }, Neck = { 8, 0, 0 }, RightShoulder = { 26, 0, 10 }, RightElbow = { 44, 0, 0 }, RightWrist = { 42, 0, 0 }, LeftShoulder = { 30, 0, -24 }, LeftElbow = { 24, 0, 0 }, LeftWrist = { -70, 0, 0 } } },
			{ 0.35, "In", { Waist = { 10, 0, 0 }, Neck = { 10, 0, 0 }, RightShoulder = { 50, 0, 6 }, RightElbow = { 10, 0, 0 }, RightWrist = { 42, 0, 0 }, LeftShoulder = { 120, 0, -20 }, LeftElbow = { 10, 0, 0 }, LeftWrist = { -30, 0, 0 } } },
			{ 0.55, "Out", { Waist = { 6, 0, 0 }, Neck = { 6, 0, 0 }, RightShoulder = { 50, 0, 6 }, RightElbow = { 10, 0, 0 }, LeftShoulder = { 100, 0, -16 }, LeftElbow = { 20, 0, 0 } } },
			{ 0.75, "InOut", {} },
		} },
		-- the Ranger's Feather Rain: leaning back 15 and looking up while the bow solve aims high (waist / neck only)
		RangerRelease = { Len = 0.44, Keys = {
			{ 0, "Out", {} },
			{ 0.08, "Out", { Waist = { 10, -60, 0 }, Neck = { 8, 60, 0 } } },
			{ 0.16, "InOut", { Waist = { 15, -65, 0 }, Neck = { 12, 65, 0 } } },
			{ 0.18, "In", { Waist = { 15, -65, 0 }, Neck = { 12, 65, 0 } } },
			{ 0.3, "Out", { Waist = { 14, -60, 0 }, Neck = { 12, 60, 0 } } },
			{ 0.44, "InOut", {} },
		} },
		-- the Shadow Hunter's Spark Shower: crouched 20 forward, two quick half draws (Redraw / Shot2: the bow solve lets
		-- go again at Shot2; only the first shot is the server's)
		ShadowHunterRelease = { Len = 0.44, Redraw = 0.2, Shot2 = 0.3, Keys = {
			{ 0, "Out", {} },
			{ 0.08, "Out", { Waist = { -18, -58, 0 }, Neck = { 6, 58, 0 } } },
			{ 0.16, "InOut", { Waist = { -20, -62, 0 }, Neck = { 8, 62, 0 } } },
			{ 0.18, "In", { Waist = { -20, -62, 0 }, Neck = { 8, 62, 0 } } },
			{ 0.24, "Out", { Waist = { -20, -60, 0 }, Neck = { 6, 60, 0 } } },
			{ 0.3, "InOut", { Waist = { -20, -62, 0 }, Neck = { 8, 62, 0 } } },
			{ 0.44, "InOut", {} },
		} },
		-- A23-116 Z (off until the 10/20 check): the Berserker's Fire Rake - the blade dragged low behind on the right,
		-- a big upward cut to the left on the contact (the free left arm swung out to the left for balance; A23-128
		-- one-hand sword, 검수 10/11), then the right arm hauls it back over the right shoulder
		BerserkerZ = { Len = 0.75, Keys = {
			{ 0, "Out", {} },
			{ 0.14, "Out", { Waist = { 0, 25, 0 }, RightShoulder = { 20, 0, 40 }, RightElbow = { 10, 0, 0 }, RightWrist = { -30, 0, 0 }, LeftShoulder = { 46, 0, -26 }, LeftElbow = { 50, 0, 0 } } },
			{ 0.24, "In", { Waist = { 0, -30, 0 }, RightShoulder = { 120, 0, -30 }, RightElbow = { 10, 0, 0 }, RightWrist = { -40, 0, 0 }, LeftShoulder = { 20, 0, -50 }, LeftElbow = { 24, 0, 0 } } },
			{ 0.48, "Out", { Waist = { 0, -10, 0 }, RightShoulder = { 150, 0, 20 }, RightElbow = { 90, 0, 0 }, LeftShoulder = { 34, 0, -24 }, LeftElbow = { 50, 0, 0 } } },
			{ 0.75, "InOut", {} },
		} },
		-- the Dark Mage's Flappy Zigzag: the crooked staff pulled back right, a quick side swing to the left (the bat
		-- leaves), the left fingers wiggling 'go'
		DarkMageZ = { Len = 0.68, Keys = {
			{ 0, "Out", {} },
			{ 0.12, "Out", { Waist = { 0, 20, 0 }, RightShoulder = { 40, 0, 40 }, RightElbow = { 40, 0, 0 }, RightWrist = { -30, 0, 0 }, LeftShoulder = { 20, 0, -10 } } },
			{ 0.24, "In", { Waist = { 0, -25, 0 }, RightShoulder = { 70, 0, -40 }, RightElbow = { 10, 0, 0 }, RightWrist = { -60, 0, 0 }, LeftShoulder = { 60, 0, -20 }, LeftElbow = { 20, 0, 0 }, LeftWrist = { -30, 0, 0 } } },
			{ 0.4, "Out", { Waist = { 0, -15, 0 }, RightShoulder = { 50, 0, -20 }, RightElbow = { 20, 0, 0 }, LeftShoulder = { 50, 0, -16 }, LeftElbow = { 30, 0, 0 }, LeftWrist = { -50, 0, 0 } } },
			{ 0.68, "InOut", {} },
		} },
		-- the Ranger's Comet Arrow: a flat full draw leaning a little in, a small kick back after the shot (waist / neck)
		RangerZ = { Len = 0.44, Keys = {
			{ 0, "Out", {} },
			{ 0.08, "Out", { Waist = { -6, -60, 0 }, Neck = { 0, 60, 0 } } },
			{ 0.16, "InOut", { Waist = { -8, -65, 0 }, Neck = { 0, 65, 0 } } },
			{ 0.18, "In", { Waist = { -8, -65, 0 }, Neck = { 0, 65, 0 } } },
			{ 0.26, "Out", { Waist = { 4, -62, 0 }, Neck = { -2, 62, 0 } } },
			{ 0.36, "Out", { Waist = { -4, -62, 0 }, Neck = { 0, 62, 0 } } },
			{ 0.44, "InOut", {} },
		} },
		-- the Shadow Hunter's Moon Shot: crouched 30 deep, the head up on the target, a sharp shoulder kick after the shot
		ShadowHunterZ = { Len = 0.44, Keys = {
			{ 0, "Out", {} },
			{ 0.12, "Out", { Waist = { -30, -60, 0 }, Neck = { 14, 60, 0 } } },
			{ 0.16, "InOut", { Waist = { -30, -62, 0 }, Neck = { 14, 62, 0 } } },
			{ 0.18, "In", { Waist = { -30, -62, 0 }, Neck = { 14, 62, 0 } } },
			{ 0.26, "Out", { Waist = { -20, -62, 0 }, Neck = { 10, 62, 0 } } },
			{ 0.36, "Out", { Waist = { -26, -60, 0 }, Neck = { 12, 60, 0 } } },
			{ 0.44, "InOut", {} },
		} },
		-- A23-116 X (off until the 10/20 check): the Berserker's Rage Roar - the blade tip set down before the feet in the
		-- right hand (the left fist clenched low at the side; A23-128 one-hand sword, 검수 10/11), then the left arm flung
		-- wide, chest forward, head back (the roar), two shrugs, back up
		BerserkerX = { Len = 0.75, Keys = {
			{ 0, "Out", {} },
			{ 0.2, "Out", { Waist = { -20, 0, 0 }, RightShoulder = { 40, 0, -6 }, RightElbow = { 10, 0, 0 }, RightWrist = { -60, 0, 0 }, LeftShoulder = { 12, 0, -18 }, LeftElbow = { 40, 0, 0 } } },
			{ 0.3, "In", { Waist = { -10, 0, 0 }, Neck = { 20, 0, 0 }, RightShoulder = { 30, 0, -4 }, RightElbow = { 10, 0, 0 }, RightWrist = { -50, 0, 0 }, LeftShoulder = { 90, 0, -80 }, LeftElbow = { 10, 0, 0 } } },
			{ 0.42, "Out", { Waist = { -12, 0, 0 }, Neck = { 18, 0, 0 }, RightShoulder = { 34, 0, -4 }, RightElbow = { 10, 0, 0 }, LeftShoulder = { 96, 0, -84 }, LeftElbow = { 8, 0, 0 } } },
			{ 0.55, "Out", { Waist = { -10, 0, 0 }, Neck = { 20, 0, 0 }, RightShoulder = { 30, 0, -4 }, RightElbow = { 10, 0, 0 }, LeftShoulder = { 90, 0, -80 }, LeftElbow = { 10, 0, 0 } } },
			{ 0.75, "InOut", {} },
		} },
		-- the Dark Mage's Hex Circle: the crooked staff turned tip-down onto the ground (the wrist in two keys), then the
		-- left hand draws a big circle at chest height
		DarkMageX = { Len = 0.75, Keys = {
			{ 0, "Out", {} },
			{ 0.1, "Out", { RightShoulder = { 30, 0, 10 }, RightElbow = { 30, 0, 0 }, RightWrist = { -80, 0, 0 } } },
			{ 0.2, "Out", { Waist = { -10, 0, 0 }, RightShoulder = { 20, 0, 10 }, RightElbow = { 10, 0, 0 }, RightWrist = { -150, 0, 0 } } },
			{ 0.3, "In", { Waist = { -8, 0, 0 }, RightShoulder = { 20, 0, 10 }, RightElbow = { 10, 0, 0 }, RightWrist = { -150, 0, 0 }, LeftShoulder = { 80, 0, -30 }, LeftElbow = { 30, 0, 0 } } },
			{ 0.42, "Out", { Waist = { -8, 0, 0 }, RightShoulder = { 20, 0, 10 }, RightElbow = { 10, 0, 0 }, RightWrist = { -150, 0, 0 }, LeftShoulder = { 100, 0, 0 }, LeftElbow = { 30, 0, 0 } } },
			{ 0.55, "Out", { Waist = { -8, 0, 0 }, RightShoulder = { 20, 0, 10 }, RightElbow = { 10, 0, 0 }, RightWrist = { -150, 0, 0 }, LeftShoulder = { 80, 0, 30 }, LeftElbow = { 30, 0, 0 } } },
			{ 0.75, "InOut", {} },
		} },
		-- the Ranger's Light Step: a tiny crouch, a light lean back in the air (the server's hop moves the body), the
		-- decorative mid-air shot, a small bend on landing (waist / neck)
		RangerX = { Len = 0.44, Keys = {
			{ 0, "Out", {} },
			{ 0.05, "Out", { Waist = { -12, -30, 0 } } },
			{ 0.12, "In", { Waist = { 8, -40, 0 }, Neck = { 6, 40, 0 } } },
			{ 0.25, "Out", { Waist = { -8, -40, 0 }, Neck = { 0, 40, 0 } } },
			{ 0.44, "InOut", {} },
		} },
		-- the Shadow Hunter's Shadow Step: a tiny crouch, curled 40 forward through the hop, a low landing (Z's first pose)
		ShadowHunterX = { Len = 0.44, Keys = {
			{ 0, "Out", {} },
			{ 0.05, "Out", { Waist = { -14, -30, 0 } } },
			{ 0.12, "In", { Waist = { -40, -40, 0 }, Neck = { 20, 40, 0 } } },
			{ 0.25, "Out", { Waist = { -30, -40, 0 }, Neck = { 14, 40, 0 } } },
			{ 0.44, "InOut", {} },
		} },
		ArcherRelease = { Len = 0.44, Keys = { -- same hand/string solve, pointed toward the existing volley
			{ 0, "Out", {} },
			{ 0.08, "Out", { Waist = { 0, -60, 0 }, Neck = { 0, 60, 0 } } },
			{ 0.16, "InOut", { Waist = { 0, -65, 0 }, Neck = { 0, 65, 0 } } },
			{ 0.18, "In", { Waist = { 0, -65, 0 }, Neck = { 0, 65, 0 } } },
			{ 0.29, "Out", { Waist = { 0, -60, 0 }, Neck = { 0, 60, 0 } } },
			{ 0.44, "InOut", {} },
		} },
		-- A23-108 (docs/design/class_grips_a23_108_2026-10-10.md, Halo first - the town now): the Paladin's straight
		-- downward cut - the sword up over the right shoulder, the shield arm forward the whole time, a clean vertical
		-- strike at the same contact time as WarriorSwing (SLASH_CONTACT 0.23), a short settle
		PaladinSwing = { Len = 0.68, Keys = {
			{ 0, "Out", {} },
			{ 0.1, "Out", { Waist = { 6, -8, 0 }, Neck = { -3, 6, 0 }, RightShoulder = { 128, -6, 14 }, RightElbow = { 70, 0, 0 }, RightWrist = { -55, 0, 6 }, LeftShoulder = { 52, 0, -12 }, LeftElbow = { 68, 0, 0 } } },
			{ 0.17, "InOut", { Waist = { 10, -12, 0 }, Neck = { -4, 8, 0 }, RightShoulder = { 158, -6, 12 }, RightElbow = { 84, 0, 0 }, RightWrist = { -70, 0, 6 }, LeftShoulder = { 58, 0, -12 }, LeftElbow = { 70, 0, 0 } } },
			{ 0.23, "In", { Waist = { -12, 6, 0 }, Neck = { 6, -4, 0 }, RightShoulder = { 46, 0, -6 }, RightElbow = { 6, 0, 0 }, RightWrist = { -72, 0, 0 }, LeftShoulder = { 56, 0, -10 }, LeftElbow = { 66, 0, 0 } } },
			{ 0.32, "Out", { Waist = { -14, 6, 0 }, Neck = { 7, -4, 0 }, RightShoulder = { 24, 0, -10 }, RightElbow = { 14, 0, 0 }, RightWrist = { -50, 0, 0 }, LeftShoulder = { 52, 0, -10 }, LeftElbow = { 64, 0, 0 } } },
			{ 0.48, "InOut", { Waist = { -4, 2, 0 }, RightShoulder = { 22, 0, 0 }, RightElbow = { 30, 0, 0 }, LeftShoulder = { 34, 0, -10 }, LeftElbow = { 56, 0, 0 } } },
			{ 0.68, "InOut", {} },
		} },
		-- A23-108: the Light Mage's cast - the left palm pushes the light forward while the staff tip points (the right
		-- wrist +28 leans it about 30 forward at the cast, hold-angles 10/16: no tip aim); the same cast time as MageSwing (CAST_DELAY 0.24)
		LightMageSwing = { Len = 0.68, Keys = {
			{ 0, "Out", {} },
			{ 0.1, "Out", { Waist = { 6, -10, 0 }, Neck = { -2, 6, 0 }, RightShoulder = { 30, -6, 12 }, RightElbow = { 36, 0, 0 }, RightWrist = { 28, 0, 6 }, LeftShoulder = { 48, 6, -26 }, LeftElbow = { 92, 0, 0 }, LeftWrist = { -40, 0, -10 } } },
			{ 0.19, "InOut", { Waist = { 10, -14, 0 }, Neck = { -3, 9, 0 }, RightShoulder = { 34, -6, 12 }, RightElbow = { 38, 0, 0 }, RightWrist = { 28, 0, 6 }, LeftShoulder = { 56, 6, -30 }, LeftElbow = { 100, 0, 0 }, LeftWrist = { -55, 0, -10 } } },
			{ 0.24, "In", { Waist = { -8, 8, 0 }, Neck = { 4, -5, 0 }, RightShoulder = { 40, 0, -6 }, RightElbow = { 6, 0, 0 }, RightWrist = { 28, 0, -4 }, LeftShoulder = { 88, 0, -8 }, LeftElbow = { 8, 0, 0 }, LeftWrist = { -80, 0, 0 } } },
			{ 0.36, "Out", { Waist = { -6, 6, 0 }, Neck = { 3, -3, 0 }, RightShoulder = { 36, 0, -6 }, RightElbow = { 10, 0, 0 }, RightWrist = { 28, 0, -2 }, LeftShoulder = { 80, 0, -8 }, LeftElbow = { 14, 0, 0 }, LeftWrist = { -70, 0, 0 } } },
			{ 0.5, "InOut", { Waist = { 0, 2, 0 }, RightShoulder = { 18, 0, 0 }, RightElbow = { 18, 0, 0 }, RightWrist = { 15, 0, 0 }, LeftShoulder = { 30, 0, -12 }, LeftElbow = { 50, 0, 0 } } },
			{ 0.68, "InOut", {} },
		} },
		-- A23-108 ⑤ Q (Shockwave) for the Paladin: the sword raised high over the head in the right hand (A23-128 one-hand
		-- sword, 검수 10/11: the free left arm forward for balance like PaladinSwing's, no empty fist on the hilt), then
		-- driven down into the ground in front (the light ring) on RELEASE_CONTACT.Warrior (0.24), the left arm swung out
		PaladinRelease = { Len = 0.7, Keys = {
			{ 0, "Out", {} },
			{ 0.16, "Out", { Waist = { 16, 0, 0 }, Neck = { -10, 0, 0 }, RightShoulder = { 170, 0, 6 }, RightElbow = { 70, 0, 0 }, RightWrist = { -80, 0, 0 }, LeftShoulder = { 58, 0, -12 }, LeftElbow = { 70, 0, 0 } } },
			{ 0.24, "In", { Waist = { -34, 0, 0 }, Neck = { 16, 0, 0 }, RightShoulder = { 62, 0, -14 }, RightElbow = { 8, 0, 0 }, RightWrist = { -88, 0, 0 }, LeftShoulder = { 34, 0, -34 }, LeftElbow = { 40, 0, 0 } } },
			{ 0.44, "Out", { Waist = { -28, 0, 0 }, Neck = { 14, 0, 0 }, RightShoulder = { 54, 0, -12 }, RightElbow = { 10, 0, 0 }, RightWrist = { -80, 0, 0 }, LeftShoulder = { 30, 0, -30 }, LeftElbow = { 44, 0, 0 } } },
			{ 0.7, "InOut", {} },
		} },
		-- A23-108 ⑤ Q (Meteor) for the Light Mage: the staff lifted to the sky (calling the light), then brought down
		-- toward the target on RELEASE_CONTACT.Mage / RELEASE_LAUNCH.Mage (0.35); the left palm opens up then forward
		LightMageRelease = { Len = 0.75, Keys = {
			{ 0, "Out", {} },
			{ 0.15, "Out", { Waist = { 14, -6, 0 }, Neck = { 18, 4, 0 }, RightShoulder = { 150, -6, 18 }, RightElbow = { 30, 0, 0 }, RightWrist = { 42, 0, 0 }, LeftShoulder = { 70, 0, -30 }, LeftElbow = { 60, 0, 0 }, LeftWrist = { -60, 0, -10 } } },
			{ 0.33, "InOut", { Waist = { 18, -8, 0 }, Neck = { 22, 6, 0 }, RightShoulder = { 168, -6, 16 }, RightElbow = { 18, 0, 0 }, RightWrist = { 42, 0, 0 }, LeftShoulder = { 96, 0, -26 }, LeftElbow = { 40, 0, 0 }, LeftWrist = { -70, 0, -10 } } },
			{ 0.35, "In", { Waist = { -18, 0, 0 }, Neck = { 6, 0, 0 }, RightShoulder = { 44, 0, 6 }, RightElbow = { 4, 0, 0 }, RightWrist = { 42, 0, 0 }, LeftShoulder = { 84, 0, -8 }, LeftElbow = { 6, 0, 0 }, LeftWrist = { -80, 0, 0 } } },
			{ 0.55, "Out", { Waist = { -14, 0, 0 }, Neck = { 5, 0, 0 }, RightShoulder = { 60, 0, 6 }, RightElbow = { 6, 0, 0 }, LeftShoulder = { 64, 0, -8 }, LeftElbow = { 8, 0, 0 } } },
			{ 0.75, "InOut", {} },
		} },
		-- A23-108 ⑤ Z / X (Lv15 / 25; off until the 10/20 check - Config.Skills.ZEnabled / XEnabled): the Paladin's
		-- Earth Cleave (a long low sweep across, then the free hand pulls the monsters in) and Guardian Roar (the shield
		-- arm up, the sword raised to the sky, the chest out)
		PaladinZ = { Len = 0.7, Keys = {
			{ 0, "Out", {} },
			{ 0.12, "Out", { Waist = { 4, -30, 0 }, Neck = { -2, 18, 0 }, RightShoulder = { 70, -10, 60 }, RightElbow = { 30, 0, 0 }, RightWrist = { -40, 0, 20 }, LeftShoulder = { 40, 0, -20 }, LeftElbow = { 50, 0, 0 } } },
			{ 0.24, "In", { Waist = { -10, 30, 0 }, Neck = { 4, -16, 0 }, RightShoulder = { 60, 0, -50 }, RightElbow = { 10, 0, 0 }, RightWrist = { -50, 0, -20 }, LeftShoulder = { 70, 0, -10 }, LeftElbow = { 10, 0, 0 } } },
			{ 0.42, "InOut", { Waist = { -6, 16, 0 }, Neck = { 2, -8, 0 }, RightShoulder = { 30, 0, -30 }, RightElbow = { 20, 0, 0 }, LeftShoulder = { 50, 0, -16 }, LeftElbow = { 90, 0, 0 }, LeftWrist = { -40, 0, 0 } } },
			{ 0.7, "InOut", {} },
		} },
		PaladinX = { Len = 0.75, Keys = {
			{ 0, "Out", {} },
			{ 0.18, "Out", { Waist = { 10, 0, 0 }, Neck = { 10, 0, 0 }, RightShoulder = { 120, 0, 20 }, RightElbow = { 40, 0, 0 }, LeftShoulder = { 70, 0, -20 }, LeftElbow = { 80, 0, 0 } } },
			{ 0.3, "In", { Waist = { 16, 0, 0 }, Neck = { 18, 0, 0 }, RightShoulder = { 172, 0, 10 }, RightElbow = { 6, 0, 0 }, RightWrist = { -10, 0, 0 }, LeftShoulder = { 80, 0, -24 }, LeftElbow = { 90, 0, 0 } } },
			{ 0.52, "Out", { Waist = { 12, 0, 0 }, Neck = { 12, 0, 0 }, RightShoulder = { 160, 0, 10 }, RightElbow = { 10, 0, 0 }, LeftShoulder = { 74, 0, -22 }, LeftElbow = { 86, 0, 0 } } },
			{ 0.75, "InOut", {} },
		} },
		-- the Light Mage's Chain Bolt (the left finger flicks a zigzag forward) and Sun Circle (the staff taps the ground,
		-- both hands open round)
		LightMageZ = { Len = 0.68, Keys = {
			{ 0, "Out", {} },
			{ 0.1, "Out", { Waist = { 6, -12, 0 }, RightShoulder = { 26, -6, 12 }, RightElbow = { 34, 0, 0 }, RightWrist = { -60, 0, 6 }, LeftShoulder = { 60, 10, -40 }, LeftElbow = { 70, 0, 0 }, LeftWrist = { -30, 0, -20 } } },
			{ 0.24, "In", { Waist = { -6, 10, 0 }, RightShoulder = { 30, 0, 6 }, RightElbow = { 30, 0, 0 }, RightWrist = { -70, 0, 0 }, LeftShoulder = { 90, -10, -6 }, LeftElbow = { 4, 0, 0 }, LeftWrist = { -60, 0, 20 } } },
			{ 0.34, "Out", { Waist = { -4, 6, 0 }, LeftShoulder = { 84, 10, -16 }, LeftElbow = { 10, 0, 0 }, LeftWrist = { -60, 0, -20 } } },
			{ 0.5, "InOut", { RightShoulder = { 16, 0, 0 }, RightElbow = { 16, 0, 0 }, LeftShoulder = { 30, 0, -12 }, LeftElbow = { 40, 0, 0 } } },
			{ 0.68, "InOut", {} },
		} },
		LightMageX = { Len = 0.75, Keys = {
			{ 0, "Out", {} },
			{ 0.16, "Out", { Waist = { 10, 0, 0 }, RightShoulder = { 70, 0, 10 }, RightElbow = { 40, 0, 0 }, RightWrist = { -40, 0, 0 }, LeftShoulder = { 40, 0, -30 }, LeftElbow = { 60, 0, 0 } } },
			{ 0.3, "In", { Waist = { -10, 0, 0 }, Neck = { 6, 0, 0 }, RightShoulder = { 30, 0, 30 }, RightElbow = { 10, 0, 0 }, RightWrist = { -20, 0, 0 }, LeftShoulder = { 40, 0, -70 }, LeftElbow = { 10, 0, 0 }, LeftWrist = { -20, 0, 0 } } },
			{ 0.52, "Out", { Waist = { -6, 0, 0 }, RightShoulder = { 26, 0, 40 }, RightElbow = { 10, 0, 0 }, LeftShoulder = { 34, 0, -64 }, LeftElbow = { 12, 0, 0 } } },
			{ 0.75, "InOut", {} },
		} },
		-- A23-34 bare hands: guard up, a straight right jab with the torso turning into it, back to rest (~0.45 s)
		PunchSwing = { Len = 0.45, Keys = {
			{ 0, "Out", {} },
			{ 0.08, "Out", { Waist = { 0, -16, 0 }, Neck = { 0, 10, 0 }, RightShoulder = { 70, 0, 12 }, RightElbow = { 100, 0, 0 }, LeftShoulder = { 60, 0, -12 }, LeftElbow = { 95, 0, 0 } } },
			{ 0.15, "In", { Waist = { -4, 22, 0 }, Neck = { 2, -14, 0 }, RightShoulder = { 92, 0, -4 }, RightElbow = { 4, 0, 0 }, RightWrist = { -8, 0, 0 }, LeftShoulder = { 55, 0, -14 }, LeftElbow = { 100, 0, 0 } } },
			{ 0.25, "Out", { Waist = { -2, 16, 0 }, Neck = { 1, -10, 0 }, RightShoulder = { 86, 0, -2 }, RightElbow = { 12, 0, 0 }, LeftShoulder = { 55, 0, -12 }, LeftElbow = { 95, 0, 0 } } },
			{ 0.45, "InOut", {} },
		} },
		Hurt = { Len = 0.32, Keys = { -- snap back, arms jerk out, small rebound
			{ 0, "Out", {} },
			{ 0.05, "Out", { Waist = { 14, 0, 6 }, Neck = { 18, 0, 0 }, RightShoulder = { 18, 0, 22 }, LeftShoulder = { 18, 0, -22 }, RightElbow = { 35, 0, 0 }, LeftElbow = { 35, 0, 0 } } },
			{ 0.15, "InOut", { Waist = { -5, 0, -2 }, Neck = { -6, 0, 0 }, RightShoulder = { 6, 0, 8 }, LeftShoulder = { 6, 0, -8 }, RightElbow = { 12, 0, 0 }, LeftElbow = { 12, 0, 0 } } },
			{ 0.32, "InOut", {} },
		} },
		HurtBig = { Len = 0.5, Keys = { -- bigger snap, arms flung, wobble
			{ 0, "Out", {} },
			{ 0.06, "Out", { Waist = { 24, 0, 10 }, Neck = { 26, 0, 8 }, RightShoulder = { 35, 0, 45 }, LeftShoulder = { 35, 0, -45 }, RightElbow = { 50, 0, 0 }, LeftElbow = { 50, 0, 0 } } },
			{ 0.2, "InOut", { Waist = { -8, 0, -6 }, Neck = { -10, 0, -8 }, RightShoulder = { 10, 0, 12 }, LeftShoulder = { 10, 0, -12 }, RightElbow = { 15, 0, 0 }, LeftElbow = { 15, 0, 0 } } },
			{ 0.32, "InOut", { Waist = { 3, 0, 4 }, Neck = { 4, 0, 6 } } },
			{ 0.5, "InOut", {} },
		} },
	},
	-- A23-108: a class x side's own clips (Config.ClassGripKey of the attacker's class and Faction attribute) over
	-- CLASS_CLIPS; a move it has none for stays the class's. Halo first (the town now): the Ranger keeps the upright
	-- ArcherSwing draw (its bow solve), the others follow in their zones' turns
	SIDE_CLIPS = {
		Warrior_Halo = { Swing = "PaladinSwing", Release = "PaladinRelease", Z = "PaladinZ", X = "PaladinX" },
		Mage_Halo = { Swing = "LightMageSwing", Release = "LightMageRelease", Z = "LightMageZ", X = "LightMageX" },
		Archer_Halo = { Release = "RangerRelease", Z = "RangerZ", X = "RangerX" }, -- (Light Step's hop moves the body itself)
		-- A23-116 Q / Z / X: the Horns side's own moves
		Warrior_Horns = { Release = "BerserkerRelease", Z = "BerserkerZ", X = "BerserkerX" },
		Mage_Horns = { Release = "DarkMageRelease", Z = "DarkMageZ", X = "DarkMageX" },
		Archer_Horns = { Release = "ShadowHunterRelease", Z = "ShadowHunterZ", X = "ShadowHunterX" },
	},
	CLASS_CLIPS = {
		Warrior = { Swing = "WarriorSwing", Release = "WarriorRelease" },
		Mage = { Swing = "MageSwing", Release = "MageRelease" },
		Archer = { Swing = "ArcherSwing", Release = "ArcherRelease" },
	},
	-- a packet Style (A23-34 bare hands "Punch"; A23-39 pet tamer "PetHeadbutt" / "PetDash") plays its own clip and no
	-- weapon pose; until the pet follows its tamer (PET-3) the headbutt shows the punch and the dash a commanding call
	STYLE_CLIPS = {
		Punch = { Swing = "PunchSwing" },
		PetHeadbutt = { Swing = "PunchSwing" },
		PetCommand = { Swing = "MageSwing" }, -- PET-3: the headbutt while the pet is drawn (PetFollow): point at it
		PetDash = { Release = "MageRelease" },
	},
}

-- A23-108: the clips of a character's class x side (MOTION.SIDE_CLIPS over CLASS_CLIPS), nil without a row
function MOTION.SideClips(char, classId)
	local ok, p = pcall(function() return typeof(char) == "Instance" and Players:GetPlayerFromCharacter(char) or nil end)
	p = ok and p or nil
	local key = p and type(Config.ClassGripKey) == "function" and Config.ClassGripKey(classId, p:GetAttribute("Faction")) or nil
	local row = key and MOTION.SIDE_CLIPS[key] or nil
	if type(row) ~= "table" then return nil end
	local base = MOTION.CLASS_CLIPS[classId] or MOTION.CLASS_CLIPS.Warrior
	return { Swing = row.Swing or base.Swing, Release = row.Release or base.Release, Z = row.Z, X = row.X } -- Z / X: own only
end

-- A14-4 combat feel: functions and state live in this one table (Luau's 200-locals limit); defined further below
local Feel = {
	Clips = {}, -- [clip name] = { Len, Joints = { [joint] = { Times, CFs, Eases } } } (compiled from MOTION.CLIPS)
	Chars = setmetatable({}, { __mode = "k" }), -- [character Model] = procedural animation state
	Active = {}, -- [state] = true while a layer plays (or a joint still has to be handed back)
	ActiveCount = 0,
	Actors = {}, -- player lifecycle token invalidates even a quick class change followed by changing back
	StepConn = nil,
	RenderConn = nil,
	StepAt = 0,
	Stickers = {}, -- pooled pain stickers
	PainAt = {}, -- [UserId] = os.clock() of that player's last sticker / flinch
	StopTrack = nil, -- stock track slowed by a hit-stop (R6 fallback)
	StopSpeed = 1,
	MonsterAttr = {}, -- [attribute name] = handler(model), filled after the handlers exist
	Pending = {}, -- ring buffer of { Pos, At }: where / when (os.clock) a Swing / Release hit on a monster shows
	PendingCursor = 0,
	Guarded = {}, -- short preparation effects cancelled with their captured actor
	GuardConn = nil,
}

----------------------------------------------------------------- small helpers
local rng = Random.new()

local lastWarnAt = -math.huge
local function warnThrottled(msg)
	local now = os.clock()
	if now - lastWarnAt < 10 then return end
	lastWarnAt = now
	Util.Warn("Fx", msg)
end

-- task.delay with the callback guarded (effects must never spam the Output)
local function later(seconds, fn)
	task.delay(seconds, function()
		local ok, err = pcall(fn)
		if not ok then warnThrottled("delayed effect failed: " .. tostring(err)) end
	end)
end

local function asVec(v)
	if typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z then return v end
	return nil
end

local function asNum(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default
end

local function asStr(v, default)
	if type(v) == "string" then return v end
	return default
end

local function isOwn(data)
	return LocalPlayer ~= nil and asNum(data.UserId, -1) == LocalPlayer.UserId
end

local function factionColor(factionId)
	local f = (type(factionId) == "string") and Config.Factions[factionId] or nil
	if type(f) == "table" and typeof(f.Color) == "Color3" then return f.Color end
	return COLOR_FALLBACK
end

local function getOwnRoot()
	local char = LocalPlayer and LocalPlayer.Character
	if not char then return nil end
	local root = char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then return root end
	return nil
end

local function getPlayerRootPos(userId)
	if type(userId) ~= "number" then return nil end
	local p = Players:GetPlayerByUserId(userId)
	local char = p and p.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then return root.Position end
	return nil
end

local function nearCamera(pos)
	local cam = workspace.CurrentCamera
	if not cam then return true end
	return (cam.CFrame.Position - pos).Magnitude <= CULL_DISTANCE
end

local function myAttr(name, default)
	if not LocalPlayer then return default end
	local v = LocalPlayer:GetAttribute(name)
	if v == nil then return default end
	return v
end

-- calls C.UIKit.<name>(...) safely (UIKit is owned by G10)
local function uiCall(name, ...)
	local ui = C and C.UIKit
	local fn = ui and ui[name]
	if type(fn) ~= "function" then return end
	local ok, err = pcall(fn, ...)
	if not ok then warnThrottled("UIKit." .. name .. " failed: " .. tostring(err)) end
end

-- UIKit.Fmt with a local fallback (string.format(Config.Text[key], ...))
local function fmt(key, ...)
	local ui = C and C.UIKit
	if ui and type(ui.Fmt) == "function" then
		local ok, s = pcall(ui.Fmt, key, ...)
		if ok and type(s) == "string" then return s end
	end
	local template = Config.Text[key]
	if type(template) ~= "string" then return "" end
	local ok, s = pcall(string.format, template, ...)
	if ok then return s end
	return template
end

-- Config.Text[key] formatted (via fmt), or the private fallback template when the key is missing
local function textOr(key, fallback, ...)
	if type(Config.Text[key]) == "string" then
		local s = fmt(key, ...)
		if s ~= "" then return s end
	end
	local ok, s = pcall(string.format, fallback, ...)
	if ok then return s end
	return fallback
end

-- a display line that may contain "%%" escapes but no arguments
local function plainLine(s)
	if type(s) ~= "string" then return nil end
	local ok, out = pcall(string.format, s)
	if ok then return out end
	return s
end

----------------------------------------------------------------- local effect folder + parts
local fxFolder = nil

local function getFolder()
	local want = workspace.CurrentCamera or workspace
	if fxFolder and fxFolder.Parent == want then return fxFolder end
	if fxFolder then
		local ok = pcall(function()
			fxFolder.Parent = want
		end)
		if ok then return fxFolder end
	end
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "LocalFx"
	fxFolder.Parent = want
	return fxFolder
end

-- anchored, non-colliding, non-queryable local part (Neon by default)
local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Neon
	for k, v in props do
		if k ~= "Parent" then
			p[k] = v
		end
	end
	p.Parent = props.Parent or getFolder()
	return p
end

local function tween(inst, time, props, style, direction, delayTime)
	local info = TweenInfo.new(
		math.max(0, time),
		style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out,
		0,
		false,
		delayTime or 0
	)
	local t = TweenService:Create(inst, info, props)
	t:Play()
	return t
end

local function addLight(part, color, brightness, range)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = part
	return l
end

----------------------------------------------------------------- ground height (rings sit on the floor)
-- addendum A11-R1 + 걷는 바닥 (2026-10-11): Shared.Ground (Config.GroundRoots) - Terrain, workspace.Map.Ground, the
-- bridges (Decor "Bridge_*", the kits' "*Bridge*" cells / models) and every part tagged WalkGround; zone floor parts are
-- invisible and non-queryable, other decor is never ground.
local function groundY(pos)
	local hit = Ground.Cast(pos, 3, 80)
	if hit then return hit.Position.Y end
	return 0.05 -- terrain top is Y = 0 inside zones (A11)
end

----------------------------------------------------------------- effect primitives
-- flat Neon disc on the ground growing to `radius` then fading
local function ring(pos, radius, color, opts)
	opts = opts or {}
	local y = groundY(pos) + 0.12
	local d1 = math.max(0.5, radius * 2)
	local d0 = math.min(d1, opts.StartDiameter or 1)
	local grow = opts.Grow or 0.15
	local fade = opts.Fade or 0.3
	local thick = opts.Thickness or 0.2
	-- A14-4: big shockwaves (opts.Art) use the GPT ring art (white, tinted) once its id exists; else the Neon disc
	local art = opts.Art == true and Feel.art("FxShockRing") or nil
	if art then
		local rp = makePart({
			Name = "FxRing",
			Size = Vector3.new(d0, 0.05, d0),
			CFrame = CFrame.new(pos.X, y, pos.Z),
			Transparency = 1,
		})
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Top
		sg.LightInfluence = 0
		sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		sg.CanvasSize = Vector2.new(256, 256)
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = art
		img.ImageColor3 = color
		img.ImageTransparency = math.max(0, (opts.Transparency or 0.45) - 0.3)
		img.Parent = sg
		sg.Parent = rp
		tween(rp, grow, { Size = Vector3.new(d1, 0.05, d1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		tween(img, fade, { ImageTransparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, grow * 0.6)
		Debris:AddItem(rp, grow + fade + 0.2)
		return rp
	end
	local p = makePart({
		Name = "FxRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thick, d0, d0),
		CFrame = CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Transparency = opts.Transparency or 0.45,
	})
	tween(p, grow, { Size = Vector3.new(thick, d1, d1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	tween(p, fade, { Transparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, grow * 0.6)
	Debris:AddItem(p, grow + fade + 0.2)
	return p
end

-- one-shot particle burst (default texture)
local function burst(pos, color, count, opts)
	opts = opts or {}
	local p = makePart({
		Name = "FxBurst",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(pos),
		Transparency = 1,
	})
	local lifeMax = opts.LifeMax or 1.0
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Color = typeof(color) == "ColorSequence" and color or ColorSequence.new(color)
	e.LightEmission = opts.LightEmission or 0.7
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, opts.Size or 0.8),
		NumberSequenceKeypoint.new(1, opts.EndSize or 0),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, opts.StartTransparency or 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(opts.LifeMin or 0.5, lifeMax)
	e.Speed = NumberRange.new(opts.SpeedMin or 8, opts.SpeedMax or 18)
	e.SpreadAngle = opts.Spread or Vector2.new(180, 180)
	e.Acceleration = opts.Acceleration or Vector3.new(0, -10, 0)
	e.Drag = opts.Drag or 2
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-180, 180)
	e.ZOffset = opts.ZOffset or 0 -- > 0 draws the particles that many studs toward the camera
	e.Parent = p
	e:Emit(math.clamp(math.floor(count), 1, 200))
	Debris:AddItem(p, lifeMax + 0.5)
	return p
end

-- vertical Neon light pillar standing on the ground at pos, fading out
local function pillar(pos, height, diameter, color, fadeTime, transparency)
	local gy = groundY(pos)
	local p = makePart({
		Name = "FxPillar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(pos.X, gy + height / 2, pos.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Transparency = transparency or 0.25,
	})
	addLight(p, color, 3, math.clamp(diameter * 5, 12, 40))
	tween(p, fadeTime, {
		Transparency = 1,
		Size = Vector3.new(height, diameter * 0.25, diameter * 0.25),
	}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(p, fadeTime + 0.1)
	return p
end

-- thin arrow bolt flying from -> to (streak = a Color3: A14-4 glowing Trail behind my own arrows)
local function arrowBolt(from, to, time, color, linger, streak)
	local dir = to - from
	if dir.Magnitude < 0.05 then return end
	local unit = dir.Unit
	local p = makePart({
		Name = "FxArrow",
		Size = Vector3.new(0.18, 0.18, 2.4),
		CFrame = CFrame.lookAt(from, from + unit),
		Color = color,
		Transparency = 0.05,
	})
	tween(p, time, { CFrame = CFrame.lookAt(to, to + unit) }, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local life = time + (linger or 0)
	if linger and linger > 0 then
		tween(p, linger, { Transparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, time)
	end
	if typeof(streak) == "Color3" then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.14, 1.1) -- the tail (+Z is behind the flight direction)
		a0.Parent = p
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.14, 1.1)
		a1.Parent = p
		local tr = Instance.new("Trail")
		tr.Attachment0 = a0
		tr.Attachment1 = a1
		tr.FaceCamera = true
		tr.LightEmission = 1
		tr.Color = ColorSequence.new(WHITE, streak)
		tr.Transparency = NumberSequence.new(0.1, 1)
		tr.Lifetime = MOTION.STREAK_LIFE
		tr.MinLength = 0.05
		tr.Parent = p
		if not linger or linger <= 0 then
			tween(p, 0.05, { Transparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, time)
		end
		life = math.max(life, time + MOTION.STREAK_LIFE) -- let the streak fade out before the part goes
	end
	Debris:AddItem(p, life + 0.05)
end

-- glowing orb flying from -> to
local function orb(from, to, time, color)
	local p = makePart({
		Name = "FxOrb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.3, 1.3, 1.3),
		CFrame = CFrame.new(from),
		Color = color,
	})
	addLight(p, color, 2, 10)
	tween(p, time, { CFrame = CFrame.new(to) }, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	Debris:AddItem(p, time + 0.05)
end

-- meteor falling from 60 studs above center to the ground
local function meteor(center, radius, color, fallTime, ctx)
	local gy = groundY(center)
	local landing = Vector3.new(center.X, gy + 1, center.Z)
	local start = landing + Vector3.new(0, 60, 0)
	local d = math.clamp(2 + radius * 0.12, 2, 7)
	local ball = makePart({
		Name = "FxMeteor",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(d, d, d),
		CFrame = CFrame.new(start),
		Color = color,
		Transparency = 0.05,
	})
	addLight(ball, color, 4, 24)
	local trail = Instance.new("ParticleEmitter")
	trail.Color = ColorSequence.new(COLOR_FIRE, color)
	trail.LightEmission = 1
	trail.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, d * 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = NumberRange.new(0.25, 0.45)
	trail.Speed = NumberRange.new(1, 3)
	trail.Rate = 80
	trail.Parent = ball
	local fall = tween(ball, fallTime, { CFrame = CFrame.new(landing) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(ball, fallTime + 0.05)
	if ctx then Feel.guardEffect(ctx, ball, fallTime + 0.05, fall) end
end

-- ~12 arrows raining inside the radius over `duration`
local function arrowRain(center, radius, color, duration, ctx)
	local count = 12
	local gy = groundY(center)
	for i = 1, count do
		later((i - 1) * (duration / count), function()
			if ctx and not Feel.validAttack(ctx) then return end
			local r = radius * math.sqrt(rng:NextNumber())
			local a = rng:NextNumber(0, math.pi * 2)
			local landing = Vector3.new(center.X + math.cos(a) * r, gy + 0.6, center.Z + math.sin(a) * r)
			local top = landing + Vector3.new(rng:NextNumber(-3, 3), 30, rng:NextNumber(-3, 3))
			arrowBolt(top, landing, 0.2, color, 0.3)
		end)
	end
end

-- falling "feathers" (golden goose result)
local function feathers(pos, color, count)
	for _ = 1, count do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(4, 10)
		local p = makePart({
			Name = "FxFeather",
			Size = Vector3.new(0.12, 0.5, 1.1),
			CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), 0),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.1,
		})
		local target = pos + Vector3.new(math.cos(angle) * dist, rng:NextNumber(-2, 4), math.sin(angle) * dist)
		tween(p, 1.2, {
			CFrame = CFrame.new(target) * CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28)),
			Transparency = 1,
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		Debris:AddItem(p, 1.3)
	end
end

local function featherPop(pos)
	burst(pos, ColorSequence.new(COLOR_GOLD, WHITE), 6, {
		Size = 0.5,
		SpeedMin = 6,
		SpeedMax = 12,
		LifeMin = 0.4,
		LifeMax = 0.8,
		Acceleration = Vector3.new(0, -8, 0),
	})
end

----------------------------------------------------------------- damage numbers (pooled BillboardGuis)
local pool = {}
local poolCursor = 0
local poolFolderRef = nil

local function buildPool()
	local folder = getFolder()
	for _, e in pool do
		pcall(function()
			e.Part:Destroy()
		end)
	end
	table.clear(pool)
	for i = 1, POPUP_COUNT do
		local part = makePart({
			Name = "FxNumber" .. i,
			Size = Vector3.new(0.1, 0.1, 0.1),
			Transparency = 1,
			CFrame = CFrame.new(0, -500, 0),
			Parent = folder,
		})
		local gui = Instance.new("BillboardGui")
		gui.Name = "Number"
		gui.AutoLocalize = false -- A23-179: numbers stay as they are (spawnNumber turns it on for a loot line's words)
		gui.Adornee = part
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.MaxDistance = CULL_DISTANCE
		gui.Size = UDim2.fromOffset(NUMBER_W, NUMBER_H)
		gui.Enabled = false
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = FONT_NUMBER
		label.TextScaled = true
		label.TextColor3 = WHITE
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.TextStrokeTransparency = 0.25
		label.Text = ""
		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MinTextSize = MIN_TEXT_SIZE
		constraint.MaxTextSize = 100
		constraint.Parent = label
		label.Parent = gui
		gui.Parent = part
		-- MergeKey/Amount/Prefix/Suffix/Crit/SpawnAt/SpawnPos are set while the entry shows a mergeable amount (A9-2)
		pool[i] = { Part = part, Gui = gui, Label = label, Token = 0, Scale = 1 }
	end
	poolFolderRef = folder
	poolCursor = 0
end

local function ensurePool()
	local folder = getFolder()
	if poolFolderRef ~= folder or #pool == 0 or pool[1].Part.Parent ~= folder then
		buildPool()
	end
end

-- (re)starts the size / fade / hide timer of a visible entry; its rise tween keeps running.
-- sizeMode: "pop" = PopScale -> 1 in PopTime (A9-2), "set" = final size at once, "keep" = leave a running pop alone
local function restartNumberLife(e, sizeMode)
	if e.FadeTween then
		e.FadeTween:Cancel()
		e.FadeTween = nil
	end
	local w, h = NUMBER_W * e.Scale * (e.Wide or 1), NUMBER_H * e.Scale
	local life = e.Life or NUMBER_LIFE
	if sizeMode == "pop" then
		if e.SizeTween then e.SizeTween:Cancel() end
		e.Gui.Size = UDim2.fromOffset(w * POP_SCALE, h * POP_SCALE)
		e.SizeTween = tween(e.Gui, POP_TIME, { Size = UDim2.fromOffset(w, h) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	elseif sizeMode ~= "keep" or not e.SizeTween or e.SizeTween.PlaybackState ~= Enum.PlaybackState.Playing then
		if e.SizeTween then
			e.SizeTween:Cancel()
			e.SizeTween = nil
		end
		e.Gui.Size = UDim2.fromOffset(w, h)
	end
	e.Token += 1
	local token = e.Token
	e.Label.TextTransparency = 0
	e.Label.TextStrokeTransparency = 0.25
	e.FadeTween = tween(e.Label, 0.35, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, life - 0.35)
	local icon = e.Gui:FindFirstChild("Icon") -- loot line art fades with its text (the scroll Band follows the body)
	if icon then
		icon.ImageTransparency = 0
		tween(icon, 0.35, { ImageTransparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, life - 0.35)
	end
	task.delay(life + 0.02, function()
		if e.Token == token then
			e.Gui.Enabled = false
			e.MergeKey = nil
		end
	end)
end

-- shows text on the oldest pooled number (round robin). merge = { Key, Amount, Prefix, Suffix, Crit } or nil.
-- look (B14 loot lines, optional) = { Life = s, Wide = width factor, Stack = labels up in screen space,
-- Icon = item id / UIArt key drawn left of the text (UIKit.ItemIcon; the text then starts right of it) }
local function spawnNumber(worldPos, text, color, scale, pop, merge, look)
	ensurePool()
	if #pool == 0 then return end
	poolCursor = poolCursor % #pool + 1 -- round robin = the oldest popup is reused first
	local e = pool[poolCursor]
	if e.RiseTween then
		e.RiseTween:Cancel()
		e.RiseTween = nil
	end
	e.Scale = math.clamp(asNum(scale, 1), 0.3, 4)
	e.Life = look and math.clamp(asNum(look.Life, NUMBER_LIFE), 0.5, 4) or nil
	e.Wide = look and math.clamp(asNum(look.Wide, 1), 1, 3) or nil
	e.Gui.SizeOffset = Vector2.new(0, look and math.clamp(asNum(look.Stack, 0), 0, 8) or 0)
	e.Gui.AutoLocalize = look ~= nil -- A23-179: a loot line (item words) is translated, a number is not
	e.Part.CFrame = CFrame.new(worldPos)
	e.Label.Text = tostring(text or "")
	e.Label.TextColor3 = typeof(color) == "Color3" and color or WHITE
	local oldIcon = e.Gui:FindFirstChild("Icon") -- pooled entry: clear the art of its previous use
	if oldIcon then oldIcon:Destroy() end
	local ui = look and type(look.Icon) == "string" and C and C.UIKit
	local okI, img = false, nil
	if ui and type(ui.ItemIcon) == "function" then
		okI, img = pcall(ui.ItemIcon, look.Icon, { Name = "Icon", Size = UDim2.fromScale(1, 1),
			SizeConstraint = Enum.SizeConstraint.RelativeYY, Parent = e.Gui })
	end
	local r = (okI and img) and NUMBER_H / (NUMBER_W * (e.Wide or 1)) * 1.08 or 0 -- icon width as a share of the label
	e.Label.Position = UDim2.fromScale(r, 0)
	e.Label.Size = UDim2.fromScale(1 - r, 1)
	e.Label.TextXAlignment = r > 0 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
	e.Gui.Enabled = true
	e.SpawnAt = os.clock()
	e.SpawnPos = worldPos
	if merge then
		e.MergeKey = merge.Key
		e.Amount = merge.Amount
		e.Prefix = merge.Prefix
		e.Suffix = merge.Suffix
		e.Crit = merge.Crit
	else
		e.MergeKey = nil
	end
	e.RiseTween = tween(e.Part, e.Life or NUMBER_LIFE, { CFrame = CFrame.new(worldPos + Vector3.new(0, NUMBER_RISE, 0)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	restartNumberLife(e, pop and "pop" or "set")
end

-- A9-2 merge: a visible label with the same key spawned within MergeWindow s and MERGE_DIST studs
local function findMergeTarget(key, worldPos, now)
	for _, e in pool do
		if e.MergeKey == key and e.Gui.Enabled and e.SpawnAt and now - e.SpawnAt <= MERGE_WINDOW
			and (e.SpawnPos - worldPos).Magnitude <= MERGE_DIST then
			return e
		end
	end
	return nil
end

-- an amount number that merges into a nearby recent label of the same Key.
-- style = { Key, Prefix?, Suffix?, Color, Scale, Pop?, Crit? }
local function showAmount(worldPos, amount, style)
	if typeof(worldPos) ~= "Vector3" or not nearCamera(worldPos) then return end
	if MOTION.IsDamageKey(style.Key) and not MOTION.DamageNumbersOn() then return end -- 2-C #9 Settings DmgNum
	amount = asNum(amount, 0)
	local ok, err = pcall(function()
		ensurePool()
		local prefix, suffix = style.Prefix or "", style.Suffix or ""
		local e = style.Key and findMergeTarget(style.Key, worldPos, os.clock()) or nil
		if e then
			e.Amount += amount
			local sizeMode = style.Pop == true and "pop" or "keep"
			if style.Crit == true and not e.Crit then
				-- a crit merging into a plain number turns the whole label into a crit
				e.Crit = true
				e.Suffix = suffix
				e.Scale = math.clamp(asNum(style.Scale, 1), 0.3, 4)
				e.Label.TextColor3 = typeof(style.Color) == "Color3" and style.Color or WHITE
				sizeMode = "pop"
			end
			e.Label.Text = e.Prefix .. Util.FormatNumber(e.Amount) .. e.Suffix
			restartNumberLife(e, sizeMode)
		else
			spawnNumber(worldPos, prefix .. Util.FormatNumber(amount) .. suffix, style.Color, style.Scale, style.Pop == true, {
				Key = style.Key,
				Amount = amount,
				Prefix = prefix,
				Suffix = suffix,
				Crit = style.Crit == true,
			})
		end
	end)
	if not ok then warnThrottled("number failed: " .. tostring(err)) end
end

----------------------------------------------------------------- A9-2 white hit flash (my own hits on monsters)
local flashing = {} -- [monster model] = { Colors = { [BasePart] = Color3 }, Token = n, Tint = Color3 }

-- tints the model `color` (white by default) for `time` s (FLASH_TIME by default); A14-4 reuses it for the red wind-up
local function flashModel(model, color, time)
	color = color or WHITE
	local state = flashing[model]
	if not state then
		-- original colors are stored once per flash start, so rapid hits never leave a monster white
		local colors = {}
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Name ~= MOTION.VISUAL_ROOT_NAME then
				colors[d] = d.Color
			end
		end
		state = { Colors = colors, Token = 0, Tint = nil }
		flashing[model] = state
	end
	if state.Tint ~= color then
		state.Tint = color
		for part in state.Colors do
			pcall(function()
				part.Color = color
			end)
		end
	end
	state.Token += 1
	local token = state.Token
	task.delay(time or FLASH_TIME, function()
		if flashing[model] ~= state or state.Token ~= token then return end
		flashing[model] = nil
		for part, color in state.Colors do
			if part.Parent then
				pcall(function()
					part.Color = color
				end)
			end
		end
	end)
end

-- flashes every procedural monster in workspace.Monsters whose root is within FLASH_DIST of a hit position
local function flashMonstersAt(positions)
	if #positions == 0 then return end
	local folder = workspace:FindFirstChild("Monsters")
	if not folder then return end
	for _, model in folder:GetChildren() do
		-- custom-model visuals (A1) are skipped: their procedural parts are invisible hitboxes; so are other players'
		-- hidden personal monsters (CR-L15)
		if model:IsA("Model") and not model:FindFirstChild("CustomVisual") and not Feel.isForeign(model) then
			local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local rp = root.Position
				for _, p in positions do
					if (rp - p).Magnitude <= FLASH_DIST then
						flashModel(model)
						break
					end
				end
			end
		end
	end
end

----------------------------------------------------------------- monster attack lunge / hit recoil (local VisualJoint.C0)
local monsterMotion = {} -- [monster model] = { Token = n, Tween = Tween?, Attack = bool, Conn = RBXScriptConnection }
local monsterFolderConns = {}
local hookedMonsterFolder = nil

local function visualJoint(model)
	local vr = model:FindFirstChild(MOTION.VISUAL_ROOT_NAME)
	local j = vr and vr:FindFirstChild(MOTION.VISUAL_JOINT_NAME)
	if j and j:IsA("JointInstance") then return j end
	return nil
end

local function monsterRoot(model)
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then return root end
	return nil
end

-- (body height, root center height above the floor) from the model attributes MonsterService sets
local function monsterSize(model)
	local h = math.clamp(asNum(model:GetAttribute("BodyHeight"), MOTION.DEFAULT_BODY_HEIGHT), 0.5, 60)
	local rh = math.clamp(asNum(model:GetAttribute("RootHeight"), h * 0.55), 0, h)
	return h, rh
end

local function isSlimeModel(model)
	local kind = model:GetAttribute("MonsterKind")
	local def = type(kind) == "string" and Config.MonsterTypes[kind] or nil
	return type(def) == "table" and def.Shape == "Slime"
end

-- root-space offset plus a lean around the floor point under the root (pitch > 0 leans back, < 0 leans forward)
local function leanCF(rootHeight, offset, pitchDeg)
	local pivot = CFrame.new(0, -rootHeight, 0)
	return CFrame.new(offset) * pivot * CFrame.Angles(math.rad(pitchDeg), 0, 0) * pivot:Inverse()
end

-- living-motion layer (2026-10-06 playtest: "슬라임인데 너무 딱딱해 보여"): local VisualJoint.C1 only, so the lunge /
-- recoil tweens on C0 still play on top. Slimes hop with stretch in the air and a squash on landing (and breathe
-- when still); other monsters waddle while walking; a def.Float monster (no legs, e.g. the little ghost) hovers Float
-- studs up with a slow +-FloatBob bob and never rolls. Only monsters near the camera move; nothing is sent anywhere.
local WOBBLE = { State = {}, Range = 140, StartedAt = os.clock(), FloatBob = 0.25, FloatSpeed = 0.8,
	-- "grounded" pass (user 2026-10-06: "떠 있는 게 어색해"): low sun = no contact shadow, so every monster near the
	-- camera gets a soft blob shadow (3 stacked discs, darkest in the middle) on the ground under it; slimes hop at
	-- most HopMax studs (HopRatio of the body), puff a little dust on landing and sit Sink studs into the ground
	Shadows = {}, ShadowRays = 0.15, ShadowRings = { { 0.62, 0.5 }, { 0.82, 0.68 }, { 1.0, 0.84 } },
	ShadowColor = Color3.fromRGB(18, 22, 16), HopRatio = 0.15, HopMax = 0.6, Sink = 0.1, DustRange = 70,
	-- A23-211 (user 10/16 "죽는 모션이 아니라, 뭔가 편안해지는 느낌으로 사라지면"): a beaten monster (anchored root, not
	-- Leaving) never falls or splats: (1) the shard dust pops out of it (round sparkles, Pop), (2) it relaxes - one soft
	-- hop (Hop s, HopRatio of its height, at most HopMax studs), a slime a little smaller (Shrink), a soft light fill
	-- (Soft, from SoftAt over SoftIn, down to SoftFill), (3) from FadeAt it fades away with a few round sparkles rising
	-- (Rise), gone by Gone of its time. Time = the model's CalmTime attribute (server) or Time. Kings: King Slime
	-- bounces Bounces times like a drop of water, Captain Clatter salutes (Bow) and sits down (Sit of his height).
	-- Times are shares of the calm time. This client only; the drops and the kill itself are the server's
	Calm = { Time = 1.0, Pop = 14, PopColor = Color3.fromRGB(255, 236, 170), Hop = 0.35, HopRatio = 0.12, HopMax = 1.0,
		Shrink = 0.88, Soft = Color3.fromRGB(255, 246, 225), SoftAt = 0.1, SoftIn = 0.3, SoftFill = 0.55, FadeAt = 0.4,
		Gone = 0.92, Rise = 8, Kings = { SlimeKing = "Bounce", CaptainClatter = "Salute" }, Bounces = 3, Bow = 20, Sit = 0.35 },
	Calming = {} }

-- the blob shadow of one monster: { Parts = { discs }, D = diameter, Faint = ghost, Y = ground, NextRay }
function WOBBLE.shadowFor(model, st)
	local sh = WOBBLE.Shadows[model]
	if sh then return sh end
	-- a slime is measured at its REST size (st.Base): one that pops in near me is tiny on its first frames (review
	-- 2026-10-06: respawned slimes got the 1.2 minimum and their shadow hid under the body)
	local w
	if st and st.Slime and st.Base then
		w = math.max(st.Base.X, st.Base.Z)
	else
		local cv = model:FindFirstChild("CustomVisual")
		local okSize, size = pcall(function() return (cv or model):GetExtentsSize() end)
		w = okSize and math.max(size.X, size.Z) or 3
	end
	-- a slime body covers the ground under it: its shadow is a little wider so the dark rim shows around it
	local d = math.clamp(w * ((st and st.Slime) and 1.15 or 0.9), 1.2, 16)
	local faint = st ~= nil and st.Float ~= nil
	if faint then d *= 0.65 end
	sh = { Parts = {}, D = d, Faint = faint, Y = nil, NextRay = 0, Scale = 1 }
	for i, ring in WOBBLE.ShadowRings do
		sh.Parts[i] = makePart({
			Name = "BlobShadow",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.04, d * ring[1], d * ring[1]),
			Color = WOBBLE.ShadowColor,
			Material = Enum.Material.SmoothPlastic,
			Transparency = faint and math.min(0.95, ring[2] + 0.08) or ring[2],
		})
	end
	WOBBLE.Shadows[model] = sh
	return sh
end

function WOBBLE.dropShadow(model)
	local sh = WOBBLE.Shadows[model]
	if not sh then return end
	WOBBLE.Shadows[model] = nil
	for _, part in sh.Parts do part:Destroy() end
end

-- under the root on the ground; scale < 1 while a slime is in the air or still popping in (smaller and lighter)
function WOBBLE.placeShadow(model, root, st, scale)
	local sh = WOBBLE.shadowFor(model, st)
	local pos = root.Position
	local now = os.clock()
	if not sh.Y or now >= sh.NextRay then
		sh.Y = groundY(pos)
		sh.NextRay = now + WOBBLE.ShadowRays
	end
	scale = math.clamp(scale or 1, 0.05, 1)
	local rescale = math.abs(scale - sh.Scale) > 0.02
	if rescale then sh.Scale = scale end
	for i, part in sh.Parts do
		local ring = WOBBLE.ShadowRings[i]
		if rescale then
			local dd = sh.D * ring[1] * scale
			part.Size = Vector3.new(0.04, dd, dd)
			local base = sh.Faint and math.min(0.95, ring[2] + 0.08) or ring[2]
			part.Transparency = base + (1 - base) * (1 - scale) * 0.8
		end
		part.CFrame = CFrame.new(pos.X, sh.Y + 0.05 + i * 0.003, pos.Z) * CFrame.Angles(0, 0, math.pi / 2)
	end
end

-- C1 that lifts the visual `up` studs (Part1 = Part0 * C0 * C1:Inverse())
function WOBBLE.lift(up)
	return CFrame.new(0, -up, 0)
end

function WOBBLE.track(model)
	local joint, root = visualJoint(model), monsterRoot(model)
	if not joint or not joint:IsA("Weld") or not root then return nil end
	local mesh = nil
	local cv = model:FindFirstChild("CustomVisual")
	if cv then
		for _, d in cv:GetDescendants() do
			if d:IsA("MeshPart") then mesh = d break end
		end
	end
	local h = monsterSize(model)
	local kind = model:GetAttribute("MonsterKind")
	local def = type(kind) == "string" and Config.MonsterTypes[kind] or nil
	local float = type(def) == "table" and tonumber(def.Float) or nil
	local st = { Joint = joint, Root = root, Mesh = mesh, Base = mesh and mesh.Size, Slime = isSlimeModel(model),
		Float = (float and float > 0 and def.Shape ~= "Slime") and float or nil,
		H = h, Phase = math.random() * 6.283, Active = false, HitAt = -math.huge, Thud = MOTION.Thuds(model),
		-- monster naturalness (2026-10-06): each monster hops / bobs at its own pace (a group never moves in step)
		Rate = 0.88 + math.random() * 0.24,
		-- monsters that appear while I watch pop in (not the ones already standing there when I join)
		BornAt = (os.clock() - WOBBLE.StartedAt > 3) and os.clock() or -math.huge }
	WOBBLE.State[model] = st
	if st.Float then joint.C1 = WOBBLE.lift(st.Float) end -- hover from the start, also out of range
	-- (the old "depth = width" stretch for the flat round slime mesh is gone: the cube / pumpkin meshes keep their
	-- designed shape; review 2026-10-06 after the user's "슬라임이 이상해 보여")
	model:GetAttributeChangedSignal(MOTION.HURT_SEQ_ATTR):Connect(function()
		st.HitAt = os.clock() -- jelly wobble (slimes) / a quick flinch bob (others)
	end)
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			WOBBLE.State[model] = nil
			WOBBLE.dropShadow(model)
		end
	end)
	return st
end

function WOBBLE.rest(st)
	if not st.Active then return end
	st.Active = false
	st.Joint.C1 = st.Float and WOBBLE.lift(st.Float) or CFrame.identity -- a floater keeps hovering (also while dying)
	if st.Mesh and st.Base then st.Mesh.Size = st.Base end
end

-- A23-211: one frame of a beaten monster's calm fade (WOBBLE.Calm); st = its WOBBLE state (nil for rigged ones)
function WOBBLE.calm(model, root, st, camPos)
	local K = WOBBLE.Calm
	local c = WOBBLE.Calming[model]
	if c == false then return end
	if not c then
		if (root.Position - camPos).Magnitude > WOBBLE.Range then
			WOBBLE.Calming[model] = false -- beaten far away: nothing to show
			return
		end
		local h, rh = monsterSize(model)
		local kind = model:GetAttribute("MonsterKind")
		c = { Seen = os.clock(), H = h, Joint = visualJoint(model), Way = K.Kings[type(kind) == "string" and kind or ""],
			Time = math.clamp(asNum(model:GetAttribute("CalmTime"), K.Time), 0.6, 3), Parts = {} }
		for _, d in model:GetDescendants() do
			if (d:IsA("BasePart") and d.Transparency < 1) or d:IsA("Decal") then table.insert(c.Parts, d) end
		end
		c.Mid = root.Position + Vector3.new(0, h / 2 - rh, 0)
		WOBBLE.Calming[model] = c
		model.AncestryChanged:Connect(function(_, parent)
			if parent == nil then WOBBLE.Calming[model] = nil end
		end)
	end
	-- 손맛 ③⑤ (GPT game_feel_r1, 최종 검수 10/16): the server beats it at once, but the killing hit shows later (the
	-- swing's contact frame, the orb / arrow's arrival): it stands as it is until that hit shows (Feel.pendingDelay,
	-- after HURT_SYNC_WAIT for the Swing Fx of the same server frame), then relaxes
	if not c.T0 then
		if os.clock() - c.Seen < MOTION.HURT_SYNC_WAIT then return end
		local left = Feel.pendingDelay(root.Position)
		c.T0 = os.clock() + (left > 0.02 and left + MOTION.HIT_AFTER or 0)
	end
	local T = c.Time
	local t = os.clock() - c.T0
	if t < 0 then return end
	if not c.Popped then
		c.Popped = true
		-- (1) the shard dust pops out: round sparkles, a little up and out, no rays, nothing falls
		burst(c.Mid, K.PopColor, K.Pop, { Size = 0.45, EndSize = 0, LightEmission = 0.8, LifeMin = 0.5, LifeMax = 0.9,
			SpeedMin = 2, SpeedMax = 5, Spread = Vector2.new(60, 60), Acceleration = Vector3.new(0, 3, 0), Drag = 3 })
		local hl = Instance.new("Highlight")
		hl.Name = "CalmSoft"
		hl.FillColor = K.Soft
		hl.FillTransparency = 1
		hl.OutlineTransparency = 1
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Adornee = model
		hl.Parent = model
		c.Soft = hl
	end
	-- (2) relax: one soft hop (King Slime: a few water-drop bounces; Clatter: a bow, then he sits down)
	local hopH = math.min(c.H * K.HopRatio, K.HopMax)
	local up, tilt, k = 0, 0, 1
	if c.Way == "Bounce" then
		local span = K.FadeAt * T * 1.5
		local u = math.clamp(t / span, 0, 1)
		up = math.abs(math.sin(math.pi * K.Bounces * u)) * hopH * (1 - u)
		k = 1 - (1 - K.Shrink) * u
	elseif c.Way == "Salute" then
		local bow = math.clamp(t / (0.35 * T), 0, 1)
		tilt = math.sin(math.pi * bow) * K.Bow
		up = -c.H * K.Sit * math.clamp((t - 0.35 * T) / (0.25 * T), 0, 1) -- down = sitting
	else
		local u = math.clamp(t / (K.Hop * T), 0, 1)
		up = math.sin(math.pi * u) * hopH
		k = 1 - (1 - K.Shrink) * u
	end
	local half = 0
	if st and st.Slime and st.Mesh and st.Base and st.Mesh.Parent then
		st.Mesh.Size = st.Base * k
		half = st.Base.Y * 0.5
	end
	local joint = c.Joint
	if joint and joint.Parent then
		local base = (st and st.Float) and WOBBLE.lift(st.Float) or CFrame.identity
		joint.C1 = base * CFrame.new(0, -(up + (k - 1) * half), 0) * CFrame.Angles(math.rad(tilt), 0, 0)
	end
	-- (3) soft light, then a fade with a few round sparkles rising; fully gone before the server removes the body
	local fade = math.clamp((t - K.FadeAt * T) / math.max(0.05, (K.Gone - K.FadeAt) * T), 0, 1)
	if fade > 0 and not c.Rose then
		c.Rose = true
		burst(c.Mid, K.Soft, K.Rise, { Size = 0.35, EndSize = 0, LightEmission = 0.8, LifeMin = 0.6, LifeMax = 1.0,
			SpeedMin = 1, SpeedMax = 3, Spread = Vector2.new(25, 25), Acceleration = Vector3.new(0, 4, 0), Drag = 2 })
	end
	if c.Soft and c.Soft.Parent then
		local soft = 1 - (1 - K.SoftFill) * math.clamp((t - K.SoftAt * T) / (K.SoftIn * T), 0, 1)
		c.Soft.FillTransparency = math.max(soft, fade)
	end
	for _, p in c.Parts do
		if p.Parent then p.LocalTransparencyModifier = fade end
	end
end

function WOBBLE.step(dt)
	local cam = workspace.CurrentCamera
	local folder = workspace:FindFirstChild("Monsters")
	if not cam or not folder then return end
	local camPos = cam.CFrame.Position
	for _, model in folder:GetChildren() do
		local st = WOBBLE.State[model]
		if not st and model:IsA("Model") then st = WOBBLE.track(model) end
		-- blob shadow: every live monster near the camera (rigged ones too); a dying / leaving one drops it, and so does
		-- someone else's hidden personal monster (CR-L15: no body, so no shadow / dust either)
		local sroot = model:IsA("Model") and monsterRoot(model) or nil
		local foreign = sroot ~= nil and Feel.isForeign(model)
		if sroot and not sroot.Anchored and not foreign and (sroot.Position - camPos).Magnitude <= WOBBLE.Range then
			if not (st and st.Slime) then WOBBLE.placeShadow(model, sroot, st, 1) end
		else
			WOBBLE.dropShadow(model)
		end
		if sroot and sroot.Anchored and not foreign and model:GetAttribute("Leaving") ~= true then
			-- A23-211: beaten = relax and fade (after this frame's WOBBLE pass below)
			task.defer(function()
				local okC, errC = pcall(WOBBLE.calm, model, sroot, WOBBLE.State[model], camPos)
				if not okC then warnThrottled("calm fade failed: " .. tostring(errC)) end
			end)
		end
		local mm = C and C.MonsterMotion
		if st and mm and type(mm.IsRigged) == "function" and mm.IsRigged(model) then
			WOBBLE.rest(st) -- a rigged monster moves its own bones (MonsterMotion); no extra wobble on top
			st = nil
		end
		if st and st.Joint.Parent and st.Root.Parent then
			if st.Root.Anchored or (st.Root.Position - camPos).Magnitude > WOBBLE.Range then
				WOBBLE.rest(st) -- a beaten one relaxes in WOBBLE.calm below (an event monster going home floats away)
			else
				st.Active = true
				local v = st.Root.AssemblyLinearVelocity
				local moving = v.X * v.X + v.Z * v.Z > 2.25
				if st.Slime then
					local lastS = math.sin(st.Phase)
					-- the King Slime (Config.BossThud) hops slower and higher, and every landing thuds (MOTION.Thud)
					local TH = MOTION.THUD
					st.Phase += dt * st.Rate * math.pi * (moving and 2.6 * (st.Thud and asNum(TH.HopRate, 1) or 1) or 1.3)
					local s = math.sin(st.Phase)
					local hop, sy = 0, 1 + s * 0.05 -- breathing while still
					local hopMax = st.Thud and math.min(st.H * asNum(TH.HopRatio, 0.2), asNum(TH.HopMax, 2))
						or math.min(st.H * WOBBLE.HopRatio, WOBBLE.HopMax)
					if moving then
						hop = math.max(0, s) * hopMax -- in the air on the upper half of the wave (low: grounded feel)
						sy = 1 + math.max(0, s) * 0.12 - math.max(0, -s) * 0.24 -- stretch up, squash on landing
						if st.Thud and lastS > 0 and s <= 0 and not foreign then
							local okT, errT = pcall(MOTION.Thud, st.Root, st.H, 1)
							if not okT then warnThrottled("king thud failed: " .. tostring(errT)) end
						end
						if lastS > 0 and s <= 0 and not foreign and (st.Root.Position - camPos).Magnitude <= WOBBLE.DustRange then
							-- landing: a small puff of dust at the feet (3-5 specks, 0.3 s)
							local fp = st.Root.Position
							pcall(burst, Vector3.new(fp.X, groundY(fp) + 0.15, fp.Z), Color3.fromRGB(196, 184, 150),
								math.random(3, 5), { Size = 0.3, EndSize = 0.05, LightEmission = 0, StartTransparency = 0.55,
								LifeMin = 0.2, LifeMax = 0.3, SpeedMin = 2, SpeedMax = 4, Spread = Vector2.new(70, 70),
								Acceleration = Vector3.new(0, -6, 0), Drag = 4 })
						end
					end
					local since = os.clock() - st.HitAt -- hit: a damped jelly wobble
					if since < 0.8 then sy += -0.28 * math.exp(-since * 5) * math.cos(since * 26) end
					local sx = 1 / math.sqrt(math.max(0.5, sy)) -- keeps the jelly's volume
					local born = os.clock() - st.BornAt -- pop-in: grow with a little overshoot
					local pop = 1
					if born < 0.4 then
						local k = born / 0.4
						local g = math.max(0.05, 1 + 0.25 * math.sin(k * math.pi) - (1 - k) * (1 - k))
						sx, sy = sx * g, sy * g
						pop = math.min(1, g) -- the shadow grows with the body
					end
					local half = 0
					if st.Mesh and st.Base then
						st.Mesh.Size = Vector3.new(st.Base.X * sx, st.Base.Y * sy, st.Base.Z * sx)
						half = st.Base.Y * 0.5
					end
					-- A23-110: a King dropping from the sky (DropAt / DropTime) is drawn that far up (LandShadow draws its circle)
					-- A23-113 ①: a King's leap also carries the body sideways from where it jumped (world X / Z -> the joint)
					local drop, dropX, dropZ = WOBBLE.dropLift(model, st)
					-- bottom stays on the floor, Sink studs into it (no visible gap under the jelly)
					local c1 = CFrame.new(0, -(hop + drop + (sy - 1) * half) + WOBBLE.Sink, 0)
					if dropX ~= 0 or dropZ ~= 0 then
						c1 = CFrame.new(-(st.Root.CFrame * st.Joint.C0).Rotation:VectorToObjectSpace(Vector3.new(dropX, 0, dropZ))) * c1
					end
					st.Joint.C1 = c1
					if not foreign then
						WOBBLE.placeShadow(model, st.Root, st, pop * (hopMax > 0 and 1 - 0.35 * (hop / hopMax) or 1))
					end
				elseif st.Float then
					-- no legs: a slow hover bob whether it moves or not, no waddle / roll; a hit dips it a little
					st.Phase += dt * st.Rate * math.pi * WOBBLE.FloatSpeed
					local up = st.Float + math.sin(st.Phase) * WOBBLE.FloatBob
					local since = os.clock() - st.HitAt
					if since < 0.35 then up -= 0.3 * math.exp(-since * 9) * math.abs(math.sin(since * 30)) end
					st.Joint.C1 = WOBBLE.lift(up)
				else
					st.Phase += dt * st.Rate * math.pi * (moving and 3.2 or 1.0)
					local s = math.sin(st.Phase)
					local bob = moving and math.abs(s) * 0.22 or s * 0.03
					local roll = moving and s * math.rad(6) or 0
					local since = os.clock() - st.HitAt -- hit: a short shudder on top of the C0 recoil
					if since < 0.35 then roll += math.rad(5) * math.exp(-since * 9) * math.sin(since * 60) end
					st.Joint.C1 = (CFrame.new(0, bob, 0) * CFrame.Angles(0, 0, roll)):Inverse()
				end
			end
		end
	end
end

-- tweens VisualJoint.C0 through steps { { C0, time, style?, direction? }, ... }; a newer sequence cancels a running one.
-- isAttack: true = the whole sequence is an attack (st.Attack, no recoil interrupts it); a number n = only steps 1..n
-- (the return to rest after them may take a recoil)
local function playJointSeq(model, steps, isAttack)
	local st = monsterMotion[model]
	local joint = st and visualJoint(model)
	if not joint then return end
	st.Token += 1
	local token = st.Token
	if st.Tween then
		st.Tween:Cancel()
		st.Tween = nil
	end
	local attackSteps = (isAttack == true and #steps) or (type(isAttack) == "number" and isAttack) or 0
	st.Attack = attackSteps > 0
	local i = 0
	local function step()
		if st.Token ~= token or not joint.Parent then return end
		i += 1
		local s = steps[i]
		if i > attackSteps then st.Attack = false end
		if not s then
			st.Tween = nil
			return
		end
		local info = TweenInfo.new(s[2], s[3] or Enum.EasingStyle.Quad, s[4] or Enum.EasingDirection.Out)
		local t = TweenService:Create(joint, info, { C0 = s[1] })
		st.Tween = t
		t.Completed:Connect(function(state)
			if state ~= Enum.PlaybackState.Completed then return end
			local ok, err = pcall(step)
			if not ok then warnThrottled("monster motion failed: " .. tostring(err)) end
		end)
		t:Play()
	end
	step()
end

-- AttackSeq went up: wind-up, lunge along the look direction, back to rest (slimes: squash, hop forward, land).
-- A14-4: right after a WindupAt telegraph the wind-up step is skipped (the anticipation pose already played);
-- dust puffs kick up at the feet as the lunge starts.
local function onMonsterAttack(model)
	local root = monsterRoot(model)
	if not root or not nearCamera(root.Position) then return end
	local st = monsterMotion[model]
	local teleUntil = st and st.TeleUntil
	local telegraphed = teleUntil ~= nil and os.clock() <= teleUntil + MOTION.TELE_LUNGE_WINDOW
	if st then st.TeleUntil = nil end
	local h, rh = monsterSize(model)
	local steps
	if isSlimeModel(model) then
		steps = {
			{ leanCF(rh, Vector3.new(0, -MOTION.HOP_SQUASH_DOWN * h, MOTION.HOP_SQUASH_BACK * h), MOTION.HOP_SQUASH_TILT), MOTION.HOP_SQUASH_TIME },
			{ leanCF(rh, Vector3.new(0, MOTION.HOP_UP * h, -MOTION.HOP_FWD * h), -MOTION.HOP_TILT), MOTION.HOP_TIME },
			{ CFrame.identity, MOTION.HOP_LAND_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In },
		}
	else
		steps = {
			{ leanCF(rh, Vector3.new(0, 0, MOTION.LUNGE_WINDUP_BACK * h), MOTION.LUNGE_WINDUP_TILT), MOTION.LUNGE_WINDUP_TIME },
			{ leanCF(rh, Vector3.new(0, 0, -MOTION.LUNGE_DIST * h), -MOTION.LUNGE_TILT), MOTION.LUNGE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out },
			{ CFrame.identity, MOTION.LUNGE_RETURN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut },
		}
	end
	local lungeAt = steps[1][2]
	if telegraphed then
		table.remove(steps, 1)
		lungeAt = 0
	end
	playJointSeq(model, steps, #steps - 1) -- the final return to rest may take a recoil
	later(lungeAt, function()
		if model.Parent then Feel.dust(root, h, rh) end
	end)
	-- the King Slime: its attack hop lands with a bigger thud (back at rest = on the floor); never another player's own
	-- King (A23-110 first KO: only its owner sees it, Feel.isForeign)
	if MOTION.Thuds(model) and not Feel.isForeign(model) then
		local landAt = 0
		for _, s in steps do landAt += s[2] end
		later(landAt, function()
			if model.Parent and root.Parent then MOTION.Thud(root, h, asNum(MOTION.THUD.AttackMul, 1.4)) end
		end)
	end
end

-- flinch of monsters my own hits landed on: tilt + push away from me (never interrupts their attack lunge), plus a
-- pain sticker (A14-4; the HurtSeq attribute shows one for everyone's hits, this one also works without it).
-- strength > 1 = Release hits (bigger push). The sticker is a big-hit one (EMO_BIG) when the server marked it (HurtBig),
-- or for Release hits on a server without the HurtSeq contract. Dying monsters (anchored root) get neither.
local function recoilMonstersAt(positions, strength)
	if #positions == 0 then return end
	local mult = strength or 1
	local ownRoot = getOwnRoot()
	for model, st in monsterMotion do
		local root = monsterRoot(model)
		-- an anchored root is beaten (MonsterService): it only relaxes and fades (A23-211, WOBBLE.calm)
		if root and not root.Anchored and not st.Hidden then
			local rp = root.Position
			for _, p in positions do
				if (rp - p).Magnitude <= FLASH_DIST then
					local h, rh = monsterSize(model)
					Feel.monsterPain(st, root, h, rh, Feel.hurtBig(model, mult > 1))
					if not st.Attack then
						Feel.recoil(model, st, root, ownRoot, h, rh, mult)
					end
					break
				end
			end
		end
	end
end

-- CR-L15: another player's personal monster (tutorial golden slime, model attribute OwnerUserId) cannot be hit by me,
-- so this client hides it: parts / decals get LocalTransparencyModifier 1, guis / particles / lights / highlights are
-- switched off (existing and late descendants), and Fx skips its white flash, recoil, lunge, telegraph and stickers,
-- and the owner's hit numbers on it.
Feel.HIDE_CLASSES = {
	"LayerCollector", "ParticleEmitter", "Light", "Highlight", "Beam", "Trail", "Fire", "Smoke", "Sparkles",
}
-- [model] = { Root = BasePart?, Until = os.clock() expiry once untracked } of the hidden monsters; a killed one stays
-- for HIDDEN_KEEP s after its model goes, so the owner's late killing-hit number is still filtered (showHits)
Feel.HiddenRoots = {}
Feel.HIDDEN_KEEP = 1.5

-- true when p is within FLASH_DIST of a monster this client hides (same hit -> monster match as flashMonstersAt)
function Feel.nearHidden(p)
	local now = os.clock()
	for model, e in Feel.HiddenRoots do
		if e.Until and now > e.Until then
			Feel.HiddenRoots[model] = nil
		else
			if not e.Root then e.Root = monsterRoot(model) end
			if e.Root and (e.Root.Position - p).Magnitude <= FLASH_DIST then return true end
		end
	end
	return false
end

function Feel.isForeign(model)
	local owner = model:GetAttribute("OwnerUserId")
	return LocalPlayer ~= nil and type(owner) == "number" and owner ~= LocalPlayer.UserId
end

function Feel.hideInst(st, d)
	if d:IsA("BasePart") or d:IsA("Decal") then
		d.LocalTransparencyModifier = 1
		return
	end
	for _, cls in Feel.HIDE_CLASSES do
		if d:IsA(cls) then
			if d.Enabled then
				d.Enabled = false
				if st.HiddenOff then st.HiddenOff[d] = true end -- re-enabled if the monster becomes mine
			end
			return
		end
	end
end

function Feel.setHidden(model, st, hidden)
	if hidden == (st.Hidden == true) then return end
	st.Hidden = hidden
	if st.HideConn then
		st.HideConn:Disconnect()
		st.HideConn = nil
	end
	if hidden then
		Feel.HiddenRoots[model] = { Root = monsterRoot(model) }
		st.HiddenOff = setmetatable({}, { __mode = "k" })
		for _, d in model:GetDescendants() do
			pcall(Feel.hideInst, st, d)
		end
		st.HideConn = model.DescendantAdded:Connect(function(d)
			pcall(Feel.hideInst, st, d)
		end)
	else
		Feel.HiddenRoots[model] = nil
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				pcall(function()
					d.LocalTransparencyModifier = 0
				end)
			end
		end
		for d in st.HiddenOff or {} do
			pcall(function()
				d.Enabled = true
			end)
		end
		st.HiddenOff = nil
	end
end

local function untrackMonster(model)
	local st = monsterMotion[model]
	if not st then return end
	monsterMotion[model] = nil
	st.Token += 1
	if st.Tween then
		pcall(function()
			st.Tween:Cancel()
		end)
		st.Tween = nil
	end
	if st.Conn then st.Conn:Disconnect() end
	if st.HideConn then -- CR-L15
		st.HideConn:Disconnect()
		st.HideConn = nil
	end
	local hiddenEntry = st.Hidden and Feel.HiddenRoots[model]
	if hiddenEntry then -- CR-L15: keep its last root a moment (Feel.nearHidden)
		if not hiddenEntry.Root then hiddenEntry.Root = monsterRoot(model) end
		hiddenEntry.Until = os.clock() + Feel.HIDDEN_KEEP
	end
end

-- st.TeleUntil / RecoilAt / StickerUntil / LastEmo are A14-4 fields (telegraph end, last recoil, sticker gate);
-- st.Hidden / HideConn / HiddenOff are CR-L15 (another player's personal monster)
local function trackMonster(model)
	if monsterMotion[model] or not model:IsA("Model") then return end
	local st = { Token = 0, Tween = nil, Attack = false, Conn = nil }
	monsterMotion[model] = st
	-- one listener per monster: AttackSeq (lunge), WindupAt (telegraph), HurtSeq (pain sticker + flinch)
	st.Conn = model.AttributeChanged:Connect(function(name)
		if name == "OwnerUserId" then -- CR-L15
			local okHide, errHide = pcall(Feel.setHidden, model, st, Feel.isForeign(model))
			if not okHide then warnThrottled("monster hide failed: " .. tostring(errHide)) end
			return
		end
		if st.Hidden then return end -- CR-L15: no motion / stickers on a monster this client hides
		local fn = Feel.MonsterAttr[name]
		if not fn then return end
		local ok, err = pcall(fn, model)
		if not ok then warnThrottled("monster " .. name .. " failed: " .. tostring(err)) end
	end)
	if Feel.isForeign(model) then Feel.setHidden(model, st, true) end -- CR-L15
end

-- existing children + ChildAdded; models leaving the folder (death, despawn, streaming out) are untracked
local function hookMonsterFolder(folder)
	if hookedMonsterFolder == folder then return end
	hookedMonsterFolder = folder
	for _, c in monsterFolderConns do
		c:Disconnect()
	end
	table.clear(monsterFolderConns)
	local old = {}
	for model in monsterMotion do
		table.insert(old, model)
	end
	for _, model in old do
		untrackMonster(model)
	end
	table.insert(monsterFolderConns, folder.ChildAdded:Connect(function(child)
		local ok, err = pcall(trackMonster, child)
		if not ok then warnThrottled("monster track failed: " .. tostring(err)) end
	end))
	table.insert(monsterFolderConns, folder.ChildRemoved:Connect(function(child)
		untrackMonster(child)
	end))
	for _, child in folder:GetChildren() do
		local ok, err = pcall(trackMonster, child)
		if not ok then warnThrottled("monster track failed: " .. tostring(err)) end
	end
end

local function isMonsterFolder(inst)
	return inst.Name == MOTION.MONSTER_FOLDER and inst:IsA("Folder")
end

----------------------------------------------------------------- own attack animations (my character only; they replicate)
local ATTACK_PRIORITY = Enum.AnimationPriority.Action
do
	local ok, p = pcall(function()
		return Enum.AnimationPriority.Action2
	end)
	if ok and p then ATTACK_PRIORITY = p end -- above tool / emote animations
end

local animObjects = {} -- [asset id] = Animation
local animAnimator = nil -- the Animator the cached tracks were loaded on
local animTracks = {} -- [asset id] = AnimationTrack (loaded on animAnimator)
local animCurrent = nil -- the attack track played last
local animToken = 0
local releaseAnimUntil = 0

local function resetAttackAnims()
	animToken += 1
	local cur = animCurrent
	animCurrent = nil
	if cur then
		pcall(function()
			cur:Stop(0)
		end)
	end
	animAnimator = nil
	table.clear(animTracks)
	releaseAnimUntil = 0
end

-- my living character's (Animator, Humanoid), or nil
local function ownAnimator()
	local char = LocalPlayer and LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return nil, nil end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then return nil, nil end
	return animator, hum
end

-- stock animation id for a class move ("Swing" / "Release") on this rig type
local function attackAnimId(hum, classId, which)
	local ids = hum.RigType == Enum.HumanoidRigType.R6 and MOTION.ANIM_IDS.R6 or MOTION.ANIM_IDS.R15
	local moves = MOTION.CLASS_MOVES[classId] or MOTION.CLASS_MOVES.Warrior
	local move = moves[which]
	if not move then return nil end
	local id = ids[move]
	if not id and MOTION.ANIM_FALLBACK[move] then id = ids[MOTION.ANIM_FALLBACK[move]] end
	return id
end

-- cached track per Animator (a new character / Animator drops the old cache)
local function attackTrack(animator, id)
	if animAnimator ~= animator then
		resetAttackAnims()
		animAnimator = animator
	end
	local track = animTracks[id]
	if track then return track end
	local anim = animObjects[id]
	if not anim then
		anim = Instance.new("Animation")
		anim.AnimationId = id
		animObjects[id] = anim
	end
	track = animator:LoadAnimation(anim)
	track.Priority = ATTACK_PRIORITY
	track.Looped = false
	animTracks[id] = track
	return track
end

-- plays my class move, sped up to finish within maxTime and stopped then at the latest (first play may not know
-- the length yet; it is then just cut)
local function playAttackAnim(classId, which, maxTime)
	local animator, hum = ownAnimator()
	if not animator then return end
	local id = attackAnimId(hum, classId, which)
	if not id then return end
	local track = attackTrack(animator, id)
	local speed = 1
	local len = track.Length
	if len > 0 then speed = math.clamp(len / maxTime, 1, MOTION.ANIM_MAX_SPEED) end
	local prev = animCurrent
	if prev and prev ~= track and prev.IsPlaying then prev:Stop(MOTION.ANIM_FADE_OUT) end
	if track.IsPlaying then track:Stop(0) end
	track:Play(MOTION.ANIM_FADE_IN, 1, speed)
	animCurrent = track
	animToken += 1
	local token = animToken
	later(maxTime, function()
		if animToken == token and track.IsPlaying then track:Stop(MOTION.ANIM_FADE_OUT) end
	end)
end

-- my Swing / Release -> the class move on my character (failures only warn, throttled).
-- A14-4: the procedural R15 clip first (every client plays it from the Fx); the stock animation for R6 / failures.
local function animateOwnAttack(data, which)
	local classId = asStr(data.Class, "Warrior")
	if which ~= "Release" and os.clock() < releaseAnimUntil then return end -- let the release move finish
	local maxTime = Feel.attackTime(classId, which, data.Style)
	local okProc, played = pcall(Feel.playAttack, LocalPlayer and LocalPlayer.Character, classId, which, maxTime, data)
	if not okProc then warnThrottled("procedural attack failed: " .. tostring(played)) end
	if okProc and played then
		local cur = animCurrent
		if cur and cur.IsPlaying then
			pcall(function()
				cur:Stop(MOTION.ANIM_FADE_OUT)
			end)
		end
	else
		local ok, err = pcall(playAttackAnim, classId, which, maxTime)
		if not ok then warnThrottled("attack animation failed: " .. tostring(err)) end
	end
	if which == "Release" then
		releaseAnimUntil = os.clock() + math.min(MOTION.RELEASE_HOLD, maxTime)
	end
end

----------------------------------------------------------------- camera shake
local shakeMag, shakeStart, shakeDur = 0, 0, 0
local shakeBound = false

local function stopShake()
	if not shakeBound then return end
	shakeBound = false
	pcall(function()
		RunService:UnbindFromRenderStep(SHAKE_BIND_NAME)
	end)
end

-- runs right after the camera scripts; translation only, so the camera never drifts
local function shakeStep()
	local t = os.clock() - shakeStart
	if t >= shakeDur then
		stopShake()
		return
	end
	local cam = workspace.CurrentCamera
	if not cam then return end
	local k = shakeMag * (1 - t / shakeDur)
	local offset = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * k
	cam.CFrame = cam.CFrame * CFrame.new(offset)
end

----------------------------------------------------------------- the King Slime's thud (Config.BossThud)
-- every landing of a slime of BossThud.Kinds (its walk hops in WOBBLE.step, its attack hop in onMonsterAttack): my
-- camera drops a little and bounces back by my distance to it (world up / down only, so the view never turns and the
-- camera follow never sees it), the thud sound, a round dust ring
MOTION.THUD = type(Config.BossThud) == "table" and Config.BossThud or {}
MOTION.Bump = { Mag = 0, At = -math.huge, Dur = 0, Bound = false, LastAt = -math.huge, LastMul = 0, Bind = "HaloHornsFxThud" }

-- A23-110 (개발 2 FirstKOService): a monster with DropAt (server time) / DropTime falls from DROP_HEIGHT studs up,
-- faster and faster (height x (1 - u^2)), and lands with the big thud once (not for a drop long over at the join, never
-- for another player's own King). A23-113 ① (개발 2 MonsterService LEAP, docs/design/boss_leap_2026-10-11.md): with
-- DropHeight the King LEAPS instead - a low arc DropHeight studs high from DropFrom (where it jumped) to DropPos (where
-- the server body already stands): up = DropHeight x 4u(1-u) + the ground's height difference x (1-u), sideways =
-- (DropFrom - DropPos) x (1-u). Returns the studs up now (0 = on the ground) and the world X / Z offset from the body
WOBBLE.DROP_HEIGHT = 40
function WOBBLE.dropLift(model, st)
	local at, dur = model:GetAttribute("DropAt"), model:GetAttribute("DropTime")
	if type(at) ~= "number" or type(dur) ~= "number" or dur <= 0 then return 0, 0, 0 end
	local u = (workspace:GetServerTimeNow() - at) / dur
	if u >= 1 then
		if st.DropLanded ~= at then
			st.DropLanded = at
			if u < 1.5 and not Feel.isForeign(model) then
				pcall(MOTION.Thud, st.Root, st.H, asNum(MOTION.THUD.AttackMul, 1.4))
			end
		end
		return 0, 0, 0
	end
	u = math.max(0, u)
	local h = model:GetAttribute("DropHeight")
	if type(h) ~= "number" then return WOBBLE.DROP_HEIGHT * (1 - u * u), 0, 0 end -- the sky drop (KO1's first fall)
	local k = 1 - u
	local up, ox, oz = math.max(0, h) * 4 * u * k, 0, 0
	local from, to = model:GetAttribute("DropFrom"), model:GetAttribute("DropPos")
	if typeof(from) == "Vector3" and typeof(to) == "Vector3" then
		ox, oz = (from.X - to.X) * k, (from.Z - to.Z) * k
		up += (from.Y - to.Y) * k
	end
	return math.max(0, up), ox, oz
end

-- true for a monster whose kind thuds (the King Slime)
function MOTION.Thuds(model)
	local kinds = MOTION.THUD.Kinds
	local kind = model:GetAttribute("MonsterKind")
	return type(kinds) == "table" and type(kind) == "string" and kinds[kind] == true
end

-- 1 within near studs, 0 from far on, a straight line between
function MOTION.Falloff(d, near, far)
	if type(d) ~= "number" or d ~= d then return 0 end
	if d <= near then return 1 end
	if d >= far then return 0 end
	return (far - d) / (far - near)
end

-- what one landing d studs (flat) from my character does: { Bump = studs (0 = no camera drop), Volume = 0..1 }.
-- d nil = I have no character; mul = 1 (a walk hop) or AttackMul; shakeOk = 'Screen shake' on and no Reduced Motion
function MOTION.ThudPlan(d, mul, shakeOk)
	local T = MOTION.THUD
	local near = asNum(T.Near, 18)
	local bump = 0
	if shakeOk == true and d ~= nil then
		bump = math.min(asNum(T.Bump, 0.6) * asNum(mul, 1) * MOTION.Falloff(d, near, asNum(T.Far, 45)), asNum(T.BumpMax, 0.9))
	end
	return { Bump = bump, Volume = d ~= nil and MOTION.Falloff(d, near, asNum(T.SoundFar, 70)) or 0 }
end

-- the camera's height offset t s into a bump of mag studs lasting dur s: a fast drop (lowest after ~0.05 s), one small
-- bounce up, settled at dur (a damped sine, e^-3 = 5% left at the end)
function MOTION.BumpOffset(t, mag, dur)
	if t < 0 or t >= dur or mag <= 0 then return 0 end
	local w = math.pi / (2 * math.min(0.05, dur * 0.2))
	return -mag * math.sin(w * t) * math.exp(-3 * t / dur)
end

-- runs right after the camera scripts (and the shake), every frame of a bump
function MOTION.BumpStep()
	local b = MOTION.Bump
	local t = os.clock() - b.At
	if t >= b.Dur then
		b.Bound = false
		pcall(function() RunService:UnbindFromRenderStep(b.Bind) end)
		return
	end
	local cam = workspace.CurrentCamera
	if cam then cam.CFrame += Vector3.new(0, MOTION.BumpOffset(t, b.Mag, b.Dur), 0) end
end

-- a camera bump of mag studs over dur s (none with 'Screen shake' off / Reduced Motion); a bigger running bump wins.
-- true = it started
function Fx.Bump(mag, dur)
	if not MOTION.ShakeAllowed() then return false end
	mag = math.min(asNum(mag, 0), MAX_SHAKE)
	dur = math.min(asNum(dur, 0), 1)
	if mag <= 0 or dur <= 0 then return false end
	local b = MOTION.Bump
	local now = os.clock()
	local t = now - b.At
	if t < b.Dur and mag < b.Mag * (1 - t / b.Dur) then return false end
	b.Mag, b.At, b.Dur = mag, now, dur
	if not b.Bound then
		b.Bound = pcall(function()
			RunService:BindToRenderStep(b.Bind, Enum.RenderPriority.Camera.Value + 2, MOTION.BumpStep)
		end)
	end
	return true
end

-- the round dust ring: the shock-ring art (a soft round ring, no rays) in dust colour growing to Ring x the body height
-- (RingMin..RingMax studs) and RingPuffs dust clouds popping evenly on its edge (code fallback: low dust bursts)
function MOTION.ThudRing(pos, h)
	local T = MOTION.THUD
	local color = typeof(T.DustColor) == "Color3" and T.DustColor or COLOR_DUST
	local r = math.clamp(h * asNum(T.Ring, 0.9), asNum(T.RingMin, 4), asNum(T.RingMax, 12))
	local grow, fade = asNum(T.RingGrow, 0.25), asNum(T.RingFade, 0.5)
	ring(pos, r, color, { Grow = grow, Fade = fade, Transparency = 0.35, Thickness = 0.25, StartDiameter = r, Art = true })
	local gy = groundY(pos)
	local id = Feel.art("FxDust")
	local n = math.clamp(math.floor(asNum(T.RingPuffs, 8)), 0, 16)
	local turn = rng:NextNumber(0, 2 * math.pi)
	for i = 1, n do
		local a = turn + (i - 1) * 2 * math.pi / n
		local p = Vector3.new(pos.X + math.cos(a) * r * 0.8, gy + 0.6, pos.Z + math.sin(a) * r * 0.8)
		if id then
			Feel.popImage(id, p, { Size0 = 1.2, Size1 = 2.6, Time = grow + 0.1, Fade = fade, FadeDelay = 0.1, Rot0 = rng:NextNumber(-30, 30) })
		else
			burst(p, color, 3, { Size = 0.9, EndSize = 1.6, SpeedMin = 1, SpeedMax = 3, LifeMin = 0.3, LifeMax = 0.5,
				LightEmission = 0, StartTransparency = 0.35, Spread = Vector2.new(60, 60), Acceleration = Vector3.new(0, 1, 0), Drag = 4 })
		end
	end
end

-- one landing of a thudding slime (root = its root part, h = its body height, mul = 1 or AttackMul); landings closer
-- than Gap s make one thud (a bigger one, the attack hop's, still comes through). true = it thudded
function MOTION.Thud(root, h, mul)
	local T = MOTION.THUD
	local b = MOTION.Bump
	local now = os.clock()
	mul = asNum(mul, 1)
	if now - b.LastAt < asNum(T.Gap, 0.3) and mul <= (b.LastMul or 0) then return false end
	b.LastAt, b.LastMul = now, mul
	local pos = root.Position
	local me = getOwnRoot()
	local plan = MOTION.ThudPlan(me and Util.FlatDistance(me.Position, pos) or nil, mul, MOTION.ShakeAllowed())
	if plan.Bump > 0 then Fx.Bump(plan.Bump, asNum(T.BumpTime, 0.32)) end
	local audio = C and C.Audio
	if plan.Volume > 0 and type(audio) == "table" and type(audio.Play) == "function" then
		pcall(audio.Play, "KingThud", { Volume = plan.Volume })
	end
	if nearCamera(pos) then MOTION.ThudRing(pos, h) end
	return true
end

----------------------------------------------------------------- screen GUI bits (hurt flash, combo)
local ownGui = nil
local flashFrames = {}
local flashTweens = {}
local comboLabel = nil
local comboScale = nil
local milestoneLabel = nil
local milestoneToken = 0
local milestoneTween = nil
local combo = 0
local comboToken = 0

local function getGuiRoot()
	local ui = C and C.UIKit
	local g = ui and ui.Gui
	if typeof(g) == "Instance" and g:IsA("LayerCollector") then return g end
	if ownGui and ownGui.Parent then return ownGui end
	local pg = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then return nil end
	ownGui = Instance.new("ScreenGui")
	ownGui.Name = "FxGui"
	ownGui.ResetOnSpawn = false
	ownGui.IgnoreGuiInset = true
	pcall(function() -- CR-L34: keep the fallback layer inside the notch-safe area (set after IgnoreGuiInset)
		ownGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
		ownGui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	end)
	ownGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ownGui.DisplayOrder = 11
	ownGui.Parent = pg
	return ownGui
end

local function addTextConstraint(label, maxSize)
	local c = Instance.new("UITextSizeConstraint")
	c.MinTextSize = MIN_TEXT_SIZE
	c.MaxTextSize = maxSize or 48
	c.Parent = label
end

local function buildScreenFx()
	local root = getGuiRoot()
	if not root then return end

	-- red screen-edge flash (4 gradient strips, invisible until Hurt). CR-L34: a full-screen effect, so it gets its own
	-- layer that ignores the safe area (root keeps to DeviceSafeInsets, which would leave an unflashed band at a notched
	-- phone's edges); one DisplayOrder above root, like its old ZIndex 40 inside it. Any failure -> root as before.
	local flashRoot = root
	local pg = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if pg then
		local okEdge, edgeGui = pcall(function()
			local g = pg:FindFirstChild("FxEdgeGui")
			if g and g:IsA("ScreenGui") then return g end
			g = Instance.new("ScreenGui")
			g.Name = "FxEdgeGui"
			g.ResetOnSpawn = false
			g.IgnoreGuiInset = true
			pcall(function() -- set after IgnoreGuiInset (which rewrites ScreenInsets)
				g.ScreenInsets = Enum.ScreenInsets.None
				g.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None -- no compat shrink into the safe area
			end)
			g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			local baseOrder = 10
			if root:IsA("ScreenGui") then baseOrder = root.DisplayOrder end
			g.DisplayOrder = baseOrder + 1
			g.Parent = pg
			return g
		end)
		if okEdge and typeof(edgeGui) == "Instance" then flashRoot = edgeGui end
	end
	local holder = Instance.new("Frame")
	holder.Name = "FxHurtFlash"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 40
	holder.Active = false
	holder.Parent = flashRoot
	local function edge(name, size, position, anchor, rotation)
		local f = Instance.new("Frame")
		f.Name = name
		f.BorderSizePixel = 0
		f.BackgroundColor3 = COLOR_HURT
		f.BackgroundTransparency = 1
		f.Size = size
		f.Position = position
		f.AnchorPoint = anchor
		f.ZIndex = 40
		f.Active = false
		local g = Instance.new("UIGradient")
		g.Rotation = rotation
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = f
		f.Parent = holder
		table.insert(flashFrames, f)
	end
	edge("Top", UDim2.new(1, 0, 0.14, 0), UDim2.fromScale(0, 0), Vector2.new(0, 0), 90)
	edge("Bottom", UDim2.new(1, 0, 0.14, 0), UDim2.fromScale(0, 1), Vector2.new(0, 1), -90)
	edge("Left", UDim2.new(0.1, 0, 1, 0), UDim2.fromScale(0, 0), Vector2.new(0, 0), 0)
	edge("Right", UDim2.new(0.1, 0, 1, 0), UDim2.fromScale(1, 0), Vector2.new(1, 0), 180)

	-- combo counter at bottom-centre, under the character (CR-L39: the old right-centre spot covered the menu / 자동
	-- buttons on small phones and in the fallback layout)
	comboLabel = Instance.new("TextLabel")
	comboLabel.Name = "FxCombo"
	comboLabel.BackgroundTransparency = 1
	comboLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	comboLabel.Position = UDim2.fromScale(0.5, 0.66)
	comboLabel.Size = UDim2.fromOffset(120, 24)
	comboLabel.Font = FONT_NUMBER
	comboLabel.TextScaled = true
	comboLabel.TextXAlignment = Enum.TextXAlignment.Center
	comboLabel.TextColor3 = COLOR_GOLD
	comboLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	comboLabel.TextStrokeTransparency = 0.2
	comboLabel.Text = ""
	comboLabel.Visible = false
	comboLabel.ZIndex = 5
	addTextConstraint(comboLabel, 24)
	comboScale = Instance.new("UIScale")
	comboScale.Scale = 1
	comboScale.Parent = comboLabel
	comboLabel.Parent = root

	-- milestone text ("좋아요! x10"), shown big for 1 s right above the counter (same centre x, CR-L39)
	milestoneLabel = Instance.new("TextLabel")
	milestoneLabel.Name = "FxComboMilestone"
	milestoneLabel.BackgroundTransparency = 1
	milestoneLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	milestoneLabel.Position = UDim2.new(0.5, 0, 0.66, -46) -- counter half height 12 + gap 2 + own half height 32
	milestoneLabel.Size = UDim2.fromOffset(420, 64)
	milestoneLabel.Font = FONT_NUMBER
	milestoneLabel.TextScaled = true
	milestoneLabel.TextXAlignment = Enum.TextXAlignment.Center
	milestoneLabel.TextColor3 = COLOR_PERFECT
	milestoneLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	milestoneLabel.TextStrokeTransparency = 0.1
	milestoneLabel.Text = ""
	milestoneLabel.Visible = false
	milestoneLabel.ZIndex = 5
	addTextConstraint(milestoneLabel, 64)
	milestoneLabel.Parent = root
end

-- strength 0..1 = how big the hit was (MOTION.EDGE): a small hit leaves the edges almost invisible
local function flashEdges(color, strength)
	if #flashFrames == 0 then return end
	local E = MOTION.EDGE
	if MOTION.EdgeCovered() or not MOTION.ShakeAllowed() then return end
	for _, t in flashTweens do
		t:Cancel()
	end
	table.clear(flashTweens)
	local k = math.clamp(tonumber(strength) or 1, 0, 1)
	E.FlashUntil = os.clock() + E.Fade
	E.Shown = nil -- the throb (EdgeStep) re-applies itself after this flash
	for _, f in flashFrames do
		f.BackgroundColor3 = color
		f.BackgroundTransparency = E.SmallT + (E.BigT - E.SmallT) * k
		table.insert(flashTweens, tween(f, E.Fade, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
	end
end

local function updateComboLabel(pop)
	if not comboLabel then return end
	if combo >= COMBO_SHOW_AT then
		comboLabel.Text = "x" .. combo
		comboLabel.Visible = true
		if pop and comboScale then
			comboScale.Scale = 1.25
			tween(comboScale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end
	else
		comboLabel.Visible = false
	end
end

local function showMilestone(text)
	if not milestoneLabel or type(text) ~= "string" then return end
	milestoneToken += 1
	local token = milestoneToken
	if milestoneTween then milestoneTween:Cancel() end
	milestoneLabel.Text = text
	milestoneLabel.TextTransparency = 0
	milestoneLabel.TextStrokeTransparency = 0.1
	milestoneLabel.Visible = true
	milestoneTween = tween(milestoneLabel, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0.7)
	task.delay(1, function()
		if milestoneToken == token and milestoneLabel then
			milestoneLabel.Visible = false
		end
	end)
end

local function bumpCombo()
	combo += 1
	comboToken += 1
	local token = comboToken
	task.delay(COMBO_RESET, function()
		if comboToken == token then
			combo = 0
			updateComboLabel(false)
		end
	end)
	updateComboLabel(true)
	for _, m in COMBO_MILESTONES do
		if type(m) == "table" and m[1] == combo then
			showMilestone(m[2])
		end
	end
end

----------------------------------------------------------------- own level-up announce (A7-3)
local lastLevelSeen = nil

local function announceLevelUp(level)
	-- A23-191 (user 10/14 "파란 UI 아예 나오지 않게"): no level-up banner, no unlock list, no zone story toast - the HUD's
	-- level number and the goal line say it
	lastLevelSeen = math.floor(level)
end

----------------------------------------------------------------- A14-4 combat feel
-- Every function here is a field of Feel (declared next to MOTION) so Fx.luau stays under Luau's 200-locals limit.
-- GPT art parts (Config.UIArt.Parts Fx* / Emo*) are used once UIKit.ArtId returns an id; until then each effect
-- draws a code fallback (Trail / ParticleEmitter / Neon part / TextLabel) in the same colors.

-- "rbxassetid://..." of an art part, or nil while its id is empty (-> code fallback)
function Feel.art(name)
	local ui = C and C.UIKit
	local fn = ui and ui.ArtId
	if type(fn) ~= "function" then return nil end
	local ok, id = pcall(fn, name)
	if ok and type(id) == "string" and id ~= "" then return id end
	return nil
end

-- 이미지 개발 10/08: a blank bubble art carries its words' box in Config.UIArt.Parts[name].TextRect ({ x, y, w, h },
-- fractions of the picture, like BarkBubble). The sticker's square shows the picture with Fit, so the box is mapped into
-- the square by the picture's shape (Size). nil without a TextRect (the art has its own words, or none)
function Feel.textRect(name)
	local ui = C and C.UIKit
	local part = ui and type(ui.ArtPart) == "function" and ui.ArtPart(name) or nil
	local r = type(part) == "table" and part.TextRect or nil
	if type(r) ~= "table" or type(r[1]) ~= "number" or type(r[2]) ~= "number" or type(r[3]) ~= "number" or type(r[4]) ~= "number" then
		return nil
	end
	local aspect = (typeof(part.Size) == "Vector2" and part.Size.Y > 0) and part.Size.X / part.Size.Y or 1
	local w, h = 1, 1
	if aspect >= 1 then h = 1 / aspect else w = aspect end
	local ox, oy = (1 - w) / 2, (1 - h) / 2
	return { ox + r[1] * w, oy + r[2] * h, r[3] * w, r[4] * h }
end

function Feel.near(pos, dist)
	local cam = workspace.CurrentCamera
	if not cam then return true end
	return (cam.CFrame.Position - pos).Magnitude <= dist
end

-- two joint transforms equal within float noise (a Transform read back need not be bit-identical)
function Feel.same(a, b)
	return (a.Position - b.Position).Magnitude < 1e-3
		and a.LookVector:Dot(b.LookVector) > 0.99999
		and a.UpVector:Dot(b.UpVector) > 0.99999
end

function Feel.ease(kind, a)
	if kind == "Out" then
		return 1 - (1 - a) * (1 - a)
	elseif kind == "In" then
		return a * a
	elseif kind == "InOut" then
		if a < 0.5 then return 2 * a * a end
		local b = 2 - 2 * a
		return 1 - b * b / 2
	end
	return a
end

-- MOTION.CLIPS (degrees per key) -> per joint arrays of key times / CFrames / eases
function Feel.compileClips()
	table.clear(Feel.Clips)
	for name, def in MOTION.CLIPS do
		local used = {}
		for _, key in def.Keys do
			for joint in key[3] do
				used[joint] = true
			end
		end
		local joints = {}
		for joint in used do
			local track = { Times = {}, CFs = {}, Eases = {} }
			for _, key in def.Keys do
				local a = key[3][joint]
				local cf = CFrame.identity
				if a then
					cf = CFrame.Angles(math.rad(a[1] or 0), math.rad(a[2] or 0), math.rad(a[3] or 0))
				end
				table.insert(track.Times, key[1])
				table.insert(track.CFs, cf)
				table.insert(track.Eases, key[2])
			end
			joints[joint] = track
		end
		-- A23-116: Redraw / Shot2 (the Spark Shower's second bow release) ride along
		Feel.Clips[name] = { Name = name, Len = def.Len, Joints = joints, Redraw = def.Redraw, Shot2 = def.Shot2 }
	end
end

function Feel.sample(track, t)
	local times, cfs = track.Times, track.CFs
	local n = #times
	if t <= times[1] then return cfs[1] end
	for i = 2, n do
		local t1 = times[i]
		if t < t1 then
			local t0 = times[i - 1]
			local a = (t - t0) / math.max(1e-3, t1 - t0)
			return cfs[i - 1]:Lerp(cfs[i], Feel.ease(track.Eases[i], a))
		end
	end
	return cfs[n]
end

-- AJU joints expose attachments; their Part0/1 aliases are read-only and absent on some engine versions.
function Feel.jointParts(joint)
	local ok, part0, part1, rank = pcall(function()
		if joint:IsA("Motor6D") then
			if joint.Enabled and typeof(joint.Transform) == "CFrame" then return joint.Part0, joint.Part1, 1 end
		elseif joint:IsA("AnimationConstraint") then
			local a0, a1 = joint.Attachment0, joint.Attachment1
			if joint.Enabled and a0 and a1 and typeof(joint.Transform) == "CFrame" then
				return a0.Parent, a1.Parent, 2
			end
		end
	end)
	if ok and part0 and part1 and part0:IsA("BasePart") and part1:IsA("BasePart") then return part0, part1, rank end
	return nil, nil, nil
end

function Feel.restoreJoint(joint, base, last)
	if not joint or not joint.Parent or not base or not last then return end
	pcall(function()
		if Feel.same(joint.Transform, last) then joint.Transform = base end
	end)
end

-- Finds old/custom Motor6Ds and upgraded avatar constraints by the exact R15 part pair.
function Feel.findJoints(st)
	local char = st.Char
	local wanted, found, ranks = {}, {}, {}
	for joint, partName in MOTION.JOINT_PARTS do
		local part = char:FindFirstChild(partName)
		local parent = char:FindFirstChild(MOTION.JOINT_PARENTS[joint])
		if part and parent then wanted[part] = { Name = joint, Parent = parent } end
	end
	for _, candidate in char:GetDescendants() do
		local part0, part1, rank = Feel.jointParts(candidate)
		local target = part1 and wanted[part1]
		if target and part0 == target.Parent and rank > (ranks[target.Name] or 0) then
			found[target.Name], ranks[target.Name] = candidate, rank
		end
	end
	for joint in MOTION.JOINT_PARTS do
		local m = found[joint]
		if st.Joints[joint] ~= m then
			Feel.restoreJoint(st.Joints[joint], st.Base[joint], st.Last[joint])
			st.Joints[joint] = m
			st.Base[joint] = nil
			st.Last[joint] = nil
		end
	end
	return st.Joints.Waist ~= nil and st.Joints.RightShoulder ~= nil
end

-- Capture the server-approved actor, so delayed effects never move onto a replacement character/class.
function Feel.actorState(player)
	local state = Feel.Actors[player]
	if state then return state end
	state = { Token = {}, Conns = {} }
	Feel.Actors[player] = state
	local function changed() state.Token = {} end
	for _, name in { "Class", "Faction" } do
		table.insert(state.Conns, player:GetAttributeChangedSignal(name):Connect(changed))
	end
	table.insert(state.Conns, player:GetPropertyChangedSignal("Character"):Connect(changed))
	return state
end

function Feel.attackContext(data)
	if type(data) ~= "table" then return nil end
	local uid = asNum(data.UserId, nil)
	local p = uid and Players:GetPlayerByUserId(math.floor(uid))
	local char = p and p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local classId = asStr(data.Class, "Warrior")
	if not char or not char.Parent or not hum or hum.Health <= 0 or p:GetAttribute("Class") ~= classId then return nil end
	if type(data.Faction) == "string" and data.Faction ~= p:GetAttribute("Faction") then return nil end
	if data.Character ~= char then return nil end
	return { Player = p, Char = char, Class = classId, Faction = p:GetAttribute("Faction"),
		Token = Feel.actorState(p).Token }
end

function Feel.validAttack(ctx)
	if not ctx or not ctx.Player.Parent or ctx.Player.Character ~= ctx.Char or not ctx.Char.Parent then return false end
	local state = Feel.Actors[ctx.Player]
	if not state or state.Token ~= ctx.Token then return false end
	if ctx.Player:GetAttribute("Class") ~= ctx.Class or ctx.Player:GetAttribute("Faction") ~= ctx.Faction then return false end
	local hum = ctx.Char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

function Feel.after(ctx, seconds, fn)
	later(seconds, function()
		if Feel.validAttack(ctx) then fn() end
	end)
end

function Feel.handPoint(char, left)
	local hand = left and Util.FindPart(char, "LeftHand", "Left Arm")
		or (not left and Util.FindPart(char, "RightHand", "Right Arm"))
	if not hand then return nil end
	local grip = hand:FindFirstChild(left and "LeftGripAttachment" or "RightGripAttachment")
	return grip and grip:IsA("Attachment") and grip.WorldPosition
		or (hand.CFrame * CFrame.new(0, -hand.Size.Y * 0.5, 0)).Position
end

-- Read the moving, class-matched weapon at launch time, rather than the old hand position in the Fx packet.
function Feel.muzzle(ctx, fallback)
	if not Feel.validAttack(ctx) then return nil end
	local weapon = ctx.Char:FindFirstChild("WeaponModel")
	local muzzle = weapon and weapon:IsA("Model") and weapon:GetAttribute("Class") == ctx.Class
		and weapon:FindFirstChild("AttackMuzzle", true)
	if muzzle and muzzle:IsA("Attachment") and muzzle.Parent and muzzle.Parent:IsA("BasePart") then
		return muzzle.WorldPosition
	end
	return Feel.handPoint(ctx.Char, ctx.Class == "Archer") or fallback
end

-- The same FK relation applies to both joint implementations. Read attachment frames, never write
-- them: AJU retargeting depends on their original CFrames.
function Feel.jointFrames(joint)
	local ok, c0, c1, p0, p1 = pcall(function()
		if joint:IsA("AnimationConstraint") then
			local a0, a1 = joint.Attachment0, joint.Attachment1
			if not joint.Enabled or not a0 or not a1 then return end
			return a0.CFrame, a1.CFrame, a0.Parent, a1.Parent
		elseif joint:IsA("Motor6D") and joint.Enabled then
			return joint.C0, joint.C1, joint.Part0, joint.Part1
		end
	end)
	if ok and typeof(c0) == "CFrame" and typeof(c1) == "CFrame" and p0 and p1 then
		return { C0 = c0, C1 = c1, P0 = p0, P1 = p1 }
	end
	return nil
end

function Feel.rotationBetween(from, to, pole)
	local a, b = from.Unit, to.Unit
	local dot = math.clamp(a:Dot(b), -1, 1)
	local axis = a:Cross(b)
	if axis.Magnitude > 1e-5 then return CFrame.fromAxisAngle(axis.Unit, math.acos(dot)) end
	if dot > 0 then return CFrame.identity end
	axis = pole - a * pole:Dot(a)
	if axis.Magnitude < 1e-5 then axis = a:Cross(math.abs(a.Y) < 0.9 and Vector3.yAxis or Vector3.xAxis) end
	return CFrame.fromAxisAngle(axis.Unit, math.pi)
end

function Feel.armGeometry(st, side)
	local shoulder = Feel.jointFrames(st.Joints[side .. "Shoulder"])
	local elbow = Feel.jointFrames(st.Joints[side .. "Elbow"])
	local wrist = Feel.jointFrames(st.Joints[side .. "Wrist"])
	if not shoulder or not elbow or not wrist or shoulder.P1 ~= elbow.P0 or elbow.P1 ~= wrist.P0 then return nil end
	local upper = elbow.C0.Position - shoulder.C1.Position
	local lower = wrist.C0.Position - elbow.C1.Position
	if upper.Magnitude < 0.03 or lower.Magnitude < 0.03 then return nil end
	return { Shoulder = shoulder, Elbow = elbow, Wrist = wrist, Upper = upper, Lower = lower,
		L1 = upper.Magnitude, L2 = lower.Magnitude }
end

-- Analytic two-bone solve. Bone lengths come from the real attachment pairs, and the wrist uses
-- the desired whole-hand frame. Neither a mesh's bounding box nor a guessed avatar scale is a bone.
function Feel.solveArm(arm, torso, handGoal, pole)
	local s, e, w = arm.Shoulder, arm.Elbow, arm.Wrist
	local start = (torso * s.C0).Position
	local goal = (handGoal * w.C1).Position
	local delta = goal - start
	if delta.Magnitude < 1e-5 then return nil end
	local axis = delta.Unit
	local epsilon = math.min(arm.L1, arm.L2) * 0.001
	local distance = math.clamp(delta.Magnitude, math.abs(arm.L1 - arm.L2) + epsilon, arm.L1 + arm.L2 - epsilon)
	local bend = pole - axis * pole:Dot(axis)
	if bend.Magnitude < 1e-5 then bend = axis:Cross(math.abs(axis.Y) < 0.9 and Vector3.yAxis or Vector3.xAxis) end
	local along = (distance * distance + arm.L1 * arm.L1 - arm.L2 * arm.L2) / (2 * distance)
	local height = math.sqrt(math.max(0, arm.L1 * arm.L1 - along * along))
	local elbowPos = start + axis * along + bend.Unit * height
	local wristPos = start + axis * distance
	local upperRest = torso.Rotation * s.C0.Rotation * s.C1.Rotation:Inverse()
	local lowerRest = upperRest * e.C0.Rotation * e.C1.Rotation:Inverse()
	local upperRot = Feel.rotationBetween(upperRest:VectorToWorldSpace(arm.Upper), elbowPos - start, pole) * upperRest
	local lowerRot = Feel.rotationBetween(lowerRest:VectorToWorldSpace(arm.Lower), wristPos - elbowPos, pole) * lowerRest
	local upperCF = CFrame.new(start - upperRot:VectorToWorldSpace(s.C1.Position)) * upperRot
	local lowerCF = CFrame.new(elbowPos - lowerRot:VectorToWorldSpace(e.C1.Position)) * lowerRot
	local handCF = CFrame.new(wristPos - handGoal.Rotation:VectorToWorldSpace(w.C1.Position)) * handGoal.Rotation
	return {
		Shoulder = (torso * s.C0):Inverse() * upperCF * s.C1,
		Elbow = (upperCF * e.C0):Inverse() * lowerCF * e.C1,
		Wrist = (lowerCF * w.C0):Inverse() * handCF * w.C1,
		Hand = handCF, WristPosition = wristPos, ElbowPosition = elbowPos,
		Clamped = math.abs(distance - delta.Magnitude) > epsilon,
	}
end

function Feel.archerPhase(attack)
	local release = attack.Which == "Release" or (attack.Which == nil and attack.Clip.Name == "ArcherRelease")
	local clipLaunch = release and MOTION.RELEASE_LAUNCH.Archer or MOTION.SHOT_DELAY
	local at = attack.LaunchT or clipLaunch
	if attack.T <= at then return attack.T / math.max(0.001, at) * clipLaunch end
	return clipLaunch + (attack.T - at) / math.max(0.001, attack.Clip.Len - at) * (attack.Clip.Len - clipLaunch)
end

function Feel.bowAim(root, point, target, handMuzzle)
	local aim = root.CFrame.LookVector
	if target and (target - point).Magnitude > 0.05 then aim = (target - point).Unit end
	local up = root.CFrame.UpVector - aim * root.CFrame.UpVector:Dot(aim)
	if up.Magnitude < 0.05 then up = -root.CFrame.LookVector end
	local rotation = CFrame.lookAt(Vector3.zero, aim, up.Unit).Rotation
	return aim, rotation, rotation * handMuzzle.Rotation:Inverse()
end

-- Keep the string hand on the shooting line, including when its real wrist/grip offset reaches
-- either end of the two-bone range. Clamping the whole hand with solveArm would leave that line.
function Feel.bowDrawDistance(point, aim, offset, shoulder, arm, desired)
	local delta = point + offset - shoulder
	local along = delta:Dot(aim)
	local cross = delta - aim * along
	local outer = arm.L1 + arm.L2 - math.min(arm.L1, arm.L2) * 0.002
	if cross.Magnitude >= outer then return nil end
	local span = math.sqrt(math.max(0, outer * outer - cross:Dot(cross)))
	local value = math.clamp(desired, -along - span, -along + span)
	local inner = math.abs(arm.L1 - arm.L2) + math.min(arm.L1, arm.L2) * 0.002
	if cross.Magnitude < inner then
		local gap = math.sqrt(math.max(0, inner * inner - cross:Dot(cross)))
		local low, high = -along - gap, -along + gap
		if value > low and value < high then value = math.abs(value - low) < math.abs(high - value) and low or high end
	end
	return value
end

-- A23-150 7 (user 10/12 night (가) "로블록스 기본 그대로", 활도 오른손): a bow is a Roblox Tool standing in the RIGHT
-- hand (the engine's RightGrip weld, CharacterVisuals), but the archers' draw (archerPose: the left arm holds the bow,
-- the right hand pulls the string) is the class's own clip, kept: while an archer clip plays the Handle hangs on the
-- LEFT hand's grip (a local Weld "BowGrip": LeftGripAttachment, the same Tool.Grip; the RightGrip switched off), after
-- it back on the right one. The bow's HandMuzzle / HandBowRest are the left hand's (its AttackHand). Only this client's
-- view, like every Fx pose (every client moves the bows it sees; the server keeps it in the right hand).
-- 최종 검수 10/13 (review): the weld is made ONCE per bow and switched on / off (a new joint every shot made HUD copy
-- the whole character for its portrait), and after a clip the bow waits MOTION.BOW_HOLD s before going back - rapid
-- shots (0.06 .. 0.16 s between two clips) never flip it hand to hand; now = true puts it back at once (death).
-- st.BowGrip = { Weld, Right (the engine's RightGrip), Handle, On (on the left now), Back (the pending return's token) }

-- the bow back on the engine's right grip (its BowGrip kept, switched off)
function Feel.bowRight(cur)
	cur.On, cur.Back = false, nil
	pcall(function()
		cur.Weld.Enabled = false
		if cur.Right.Parent and cur.Right.Part1 == cur.Handle then cur.Right.Enabled = true end
	end)
end

function Feel.bowHand(st, left, now)
	local weapon = st.Char:FindFirstChild("WeaponModel")
	local handle = weapon and weapon:GetAttribute("AttackHand") == "LeftHand" and weapon:FindFirstChild("Handle") or nil
	local cur = st.BowGrip
	if cur and cur.Handle ~= handle then -- the bow was swapped / put away: let go of the old one
		st.BowGrip = nil
		Feel.bowRight(cur)
		pcall(function() cur.Weld:Destroy() end)
		cur = nil
	end
	if not left then
		if not (cur and cur.On) then return end
		if now then
			Feel.bowRight(cur)
		elseif not cur.Back then -- the clip is over: back on the right after the hold, unless another draw starts
			local token = {}
			cur.Back = token
			later(MOTION.BOW_HOLD, function()
				if st.BowGrip == cur and cur.Back == token then Feel.bowRight(cur) end
			end)
		end
		return
	end
	if cur then -- a draw again: stay on (or go back to) the left grip, the same weld
		cur.Back = nil
		if not cur.On then
			cur.On = true
			pcall(function()
				cur.Right.Enabled = false
				cur.Weld.Enabled = true
			end)
		end
		return
	end
	if not (handle and handle:IsA("BasePart")) then return end
	local hand, right = st.Char:FindFirstChild("LeftHand"), st.Char:FindFirstChild("RightHand")
	local rightGrip = right and right:FindFirstChild("RightGrip")
	if not (hand and rightGrip and rightGrip:IsA("JointInstance") and rightGrip.Part1 == handle) then return end
	local att = hand:FindFirstChild("LeftGripAttachment")
	local ok = pcall(function()
		local weld = Instance.new("Weld")
		weld.Name = "BowGrip"
		weld.Part0, weld.Part1 = hand, handle
		weld.C0 = (att and att:IsA("Attachment")) and att.CFrame
			or CFrame.new(0, -hand.Size.Y / 2, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
		weld.C1 = weapon.Grip
		rightGrip.Enabled = false
		weld.Parent = handle
		st.BowGrip = { Weld = weld, Right = rightGrip, Handle = handle, On = true }
	end)
	if not ok then rightGrip.Enabled = true end
end

function Feel.archerPose(st, attack, bases, outputs)
	local ctx = st.AttackContext
	if not ctx or ctx.Class ~= "Archer" or not Feel.validAttack(ctx) then return end
	local char = st.Char
	local root, head = char:FindFirstChild("HumanoidRootPart"), char:FindFirstChild("Head")
	local weapon = char:FindFirstChild("WeaponModel")
	if not root or not head or not weapon or weapon:GetAttribute("Class") ~= "Archer" then return end
	local muzzle = weapon:FindFirstChild("AttackMuzzle", true)
	local stringPart = weapon:FindFirstChild("String")
	local nock = stringPart and stringPart:FindFirstChild("BowNock")
	local left, right = Feel.armGeometry(st, "Left"), Feel.armGeometry(st, "Right")
	local waist, neck = Feel.jointFrames(st.Joints.Waist), Feel.jointFrames(st.Joints.Neck)
	if not left or not right or not waist or not neck or not muzzle or not nock then return end
	local handMuzzle = weapon:GetAttribute("HandMuzzle")
	local handRest = weapon:GetAttribute("HandBowRest")
	if typeof(handMuzzle) ~= "CFrame" or typeof(handRest) ~= "CFrame" then return end
	local torso = waist.P0.CFrame * waist.C0 * (outputs.Waist or bases.Waist or CFrame.identity) * waist.C1:Inverse()
	local headCF = torso * neck.C0 * (outputs.Neck or bases.Neck or CFrame.identity) * neck.C1:Inverse()
	local up, side = root.CFrame.UpVector, root.CFrame.RightVector
	local cheek = headCF.Position + side * (head.Size.X * MOTION.BOW.CheekSide)
		- up * (head.Size.Y * MOTION.BOW.CheekDown) + root.CFrame.LookVector * (head.Size.Z * MOTION.BOW.CheekFront)
	local shoulderPos = (torso * left.Shoulder.C0).Position
	local rightShoulder = (torso * right.Shoulder.C0).Position
	local rightHand = right.Wrist.P1
	local grip = rightHand:FindFirstChild("RightGripAttachment")
	local gripPos = grip and grip:IsA("Attachment") and grip.Position or Vector3.new(0, -rightHand.Size.Y * 0.5, 0)
	local reach = (left.L1 + left.L2) * MOTION.BOW.Extend
	local rightReach = (right.L1 + right.L2) * 0.985
	-- Project the intended cheek into both measured reaches. Recompute the target axis after each
	-- projection: a shifted face line must still point at the actual packet target.
	for _ = 1, 8 do
		local previous = cheek
		local axis, rotation, handRotation = Feel.bowAim(root, cheek, st.AttackTarget, handMuzzle)
		local wristOffset = handRotation:VectorToWorldSpace(left.Wrist.C1.Position - handMuzzle.Position)
		local delta = cheek + wristOffset - shoulderPos
		local perpendicular = delta - axis * delta:Dot(axis)
		if perpendicular.Magnitude > reach * 0.98 then
			cheek -= perpendicular * (1 - reach * 0.98 / perpendicular.Magnitude)
		end
		axis, rotation = Feel.bowAim(root, cheek, st.AttackTarget, handMuzzle)
		local rightRotation = rotation * CFrame.Angles(0, 0, -math.pi * 0.5)
		local rightDelta = cheek + rightRotation:VectorToWorldSpace(right.Wrist.C1.Position - gripPos) - rightShoulder
		if rightDelta.Magnitude > rightReach then cheek -= rightDelta * (1 - rightReach / rightDelta.Magnitude) end
		-- An elevated volley must still place the bow ahead of the string hand. Short arms cannot
		-- shoot along a face-height ray whose forward sphere intersection is behind the cheek.
		axis, rotation, handRotation = Feel.bowAim(root, cheek, st.AttackTarget, handMuzzle)
		delta = cheek + handRotation:VectorToWorldSpace(left.Wrist.C1.Position - handMuzzle.Position) - shoulderPos
		local along = delta:Dot(axis)
		perpendicular = delta - axis * along
		local forward = -along + math.sqrt(math.max(0, reach * reach - perpendicular:Dot(perpendicular)))
		local gap = reach * 0.15
		if forward < gap then cheek -= axis * (gap - forward) end
		if (cheek - previous).Magnitude < 0.0001 then break end
	end
	local aim, bowRot, handRot = Feel.bowAim(root, cheek, st.AttackTarget, handMuzzle)
	local wristOffset = handRot:VectorToWorldSpace(left.Wrist.C1.Position - handMuzzle.Position)
	local offset = cheek + wristOffset - shoulderPos
	local along = offset:Dot(aim)
	local cross = offset - aim * along
	if cross.Magnitude >= reach then return end
	local forward = -along + math.sqrt(math.max(0, reach * reach - cross:Dot(cross)))
	if forward <= 0.05 then return end
	local desiredMuzzle = CFrame.new(cheek + aim * forward) * bowRot
	local leftGoal = desiredMuzzle * handMuzzle:Inverse()
	local leftPose = Feel.solveArm(left, torso, leftGoal, -up)
	if not leftPose then return end
	local rest = (leftPose.Hand * handRest).Position
	local time = attack.T / math.max(0.01, attack.Rate)
	local launch = (attack.LaunchT or MOTION.SHOT_DELAY) / math.max(0.01, attack.Rate)
	local draw = Feel.ease("InOut", math.clamp((time - MOTION.BOW.DrawStart)
		/ math.max(0.02, launch - MOTION.BOW.DrawStart - 0.025), 0, 1))
	local rightRot = bowRot * CFrame.Angles(0, 0, -math.pi * 0.5)
	local rightOffset = rightRot:VectorToWorldSpace(right.Wrist.C1.Position - gripPos)
	local distance = Feel.bowDrawDistance(cheek, aim, rightOffset, rightShoulder, right,
		(rest - cheek):Dot(aim) * (1 - draw))
	if not distance then return end
	local drawPoint = cheek + aim * distance
	if st.BowReleased then drawPoint += side * (head.Size.X * 0.12) - aim * (head.Size.Z * 0.08) end
	local rightGoal = CFrame.new(drawPoint - rightRot:VectorToWorldSpace(gripPos)) * rightRot
	local rightPose = Feel.solveArm(right, torso, rightGoal, side + up * 0.25)
	if not rightPose then return end
	local weight = math.min(Feel.ease("Out", math.clamp(time / MOTION.BOW.AimIn, 0, 1)),
		Feel.ease("InOut", math.clamp((attack.Clip.Len - attack.T) / (MOTION.BOW.Settle * attack.Rate), 0, 1)))
	for _, spec in { { "Left", leftPose }, { "Right", rightPose } } do
		for _, suffix in { "Shoulder", "Elbow", "Wrist" } do
			local name = spec[1] .. suffix
			outputs[name] = (outputs[name] or bases[name] or CFrame.identity):Lerp(spec[2][suffix], weight)
		end
	end
end

-- Delay to the packet's launch frame, then read attachments after the Transform physics batch.
-- Class/character replacement and a newer attack invalidate this one-frame callback too.
function Feel.launchWeapon(ctx, seconds, callback)
	local st = Feel.Chars[ctx.Char]
	local serial = st and st.AttackSerial
	Feel.after(ctx, seconds, function()
		local connection
		connection = RunService.RenderStepped:Connect(function()
			connection:Disconnect()
			if not Feel.validAttack(ctx) or (serial and (not st or st.AttackSerial ~= serial)) then return end
			local ok, err = pcall(callback)
			if st and ctx.Class == "Archer" then
				st.BowReleased = true
				if st.NockArrow then st.NockArrow:Destroy(); st.NockArrow = nil end
			end
			if not ok then warnThrottled("weapon launch failed: " .. tostring(err)) end
		end)
	end)
end

function Feel.launchArrow(ctx, seconds, callback)
	Feel.launchWeapon(ctx, seconds, callback)
end

function Feel.guardEffect(ctx, part, duration, motion)
	Feel.Guarded[part] = { Context = ctx, Until = os.clock() + duration, Motion = motion }
	if Feel.GuardConn then return end
	Feel.GuardConn = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for item, entry in Feel.Guarded do
			if not Feel.validAttack(entry.Context) then
				if entry.Motion then pcall(function() entry.Motion:Cancel() end) end
				pcall(function() item:Destroy() end)
				Feel.Guarded[item] = nil
			elseif not item.Parent or now >= entry.Until then
				Feel.Guarded[item] = nil
			end
		end
		if next(Feel.Guarded) == nil then
			Feel.GuardConn:Disconnect()
			Feel.GuardConn = nil
		end
	end)
end

function Feel.clearWeaponMotion(st)
	if st.BowNock and st.BowNock.Parent and st.BowRest then st.BowNock.Position = st.BowRest end
	st.BowNock, st.BowRest = nil, nil
	for _, key in { "NockArrow", "Gather" } do
		if st[key] then st[key]:Destroy(); st[key] = nil end
	end
end

function Feel.weaponMotion(st, attack)
	local ctx = st.AttackContext
	if not attack or not attack.Clip or not Feel.validAttack(ctx) then Feel.clearWeaponMotion(st); return end
	if ctx.Style then Feel.clearWeaponMotion(st); return end -- punch / pet moves: no bow string, no staff tip
	local t = attack.T
	local release = string.find(attack.Clip.Name, "Release", 1, true) ~= nil
	local launch = attack.LaunchT or release and MOTION.RELEASE_LAUNCH[ctx.Class]
		or (ctx.Class == "Archer" and MOTION.SHOT_DELAY or MOTION.CAST_DELAY)
	local sc = 1
	pcall(function() sc = st.Char:GetScale() end)
	if ctx.Class == "Archer" then
		local weapon = st.Char:FindFirstChild("WeaponModel")
		local stringPart = weapon and weapon:GetAttribute("Class") == ctx.Class and weapon:FindFirstChild("String")
		local nock = stringPart and stringPart:FindFirstChild("BowNock")
		if not (nock and nock:IsA("Attachment")) then Feel.clearWeaponMotion(st); return end
		if st.BowNock ~= nock then
			Feel.clearWeaponMotion(st)
			st.BowNock, st.BowRest = nock, nock.Position
		end
		local handPos = Feel.handPoint(st.Char, false)
		if handPos and not st.BowReleased then
			-- The hand IK already performs the draw. A second interpolation broke hand/string contact.
			nock.Position = stringPart.CFrame:PointToObjectSpace(handPos)
		elseif st.BowReleased then
			local snap = math.clamp((t - launch) / math.max(0.01, MOTION.BOW.SnapTime * attack.Rate), 0, 1)
			nock.Position = nock.Position:Lerp(st.BowRest, snap)
		end
		if t >= MOTION.BOW.DrawStart * attack.Rate and not st.BowReleased then
			local muzzle = Feel.muzzle(ctx, nil)
			local from = nock.WorldPosition
			if muzzle and (muzzle - from).Magnitude > 0.05 then
				if not st.NockArrow then
					st.NockArrow = makePart({ Name = "FxNockedArrow", Size = Vector3.new(0.12, 0.12, 2.4) * sc,
						Color = factionColor(ctx.Faction), Transparency = 0.1 })
				end
				local dir = (muzzle - from).Unit
				local length = (muzzle - from).Magnitude + 0.6 * sc
				st.NockArrow.Size = Vector3.new(0.12 * sc, 0.12 * sc, length)
				st.NockArrow.CFrame = CFrame.lookAt(from + dir * (length * 0.5), from + dir * (length * 0.5 + 1))
			end
		elseif st.NockArrow then st.NockArrow:Destroy(); st.NockArrow = nil end
	elseif ctx.Class == "Mage" and t >= 0.05 and t < launch then
		local handPos = Feel.handPoint(st.Char, true)
		if handPos then
			if not st.Gather then
				st.Gather = makePart({ Name = "FxManaGather", Shape = Enum.PartType.Ball,
					Size = Vector3.new(1, 1, 1) * (0.25 * sc), Color = factionColor(ctx.Faction), Transparency = 0.25 })
				addLight(st.Gather, st.Gather.Color, 1.2, 5 * sc)
			end
			local size = (0.25 + 0.5 * math.clamp(t / math.max(0.05, launch), 0, 1)) * sc
			st.Gather.Size = Vector3.new(1, 1, 1) * size
			st.Gather.CFrame = CFrame.new(handPos + Vector3.new(0, size * 0.45, 0))
		end
	else
		Feel.clearWeaponMotion(st)
	end
end

-- starts clip `name` on a layer ("Attack" / "Hurt", they add up) of a living R15 character.
-- false when it cannot play (R6, dead, PROC_MAX_CHARS other characters busy, unknown clip, PROCEDURAL off)
function Feel.play(char, layer, name, rate)
	local clip = Feel.Clips[name]
	if not MOTION.PROCEDURAL or not clip or typeof(char) ~= "Instance" or not char.Parent then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.RigType ~= Enum.HumanoidRigType.R15 or hum.Health <= 0 then return false end
	local st = Feel.Chars[char]
	if not st then
		-- states of removed characters go first (the state holds its character, so the weak key alone never frees it)
		for c, other in Feel.Chars do
			if not c.Parent and not Feel.Active[other] then Feel.Chars[c] = nil end
		end
		st = { Char = char, Joints = {}, Base = {}, Last = {}, Layers = {}, HoldUntil = 0, ReleaseUntil = 0 }
		Feel.Chars[char] = st
	end
	if not Feel.findJoints(st) then return false end
	if not Feel.Active[st] then
		local mine = LocalPlayer ~= nil and char == LocalPlayer.Character
		if Feel.ActiveCount >= MOTION.PROC_MAX_CHARS and not mine then return false end
		Feel.Active[st] = true
		Feel.ActiveCount += 1
	end
	local l = st.Layers[layer]
	if not l then
		l = { Clip = nil, T = 0, Rate = 1 }
		st.Layers[layer] = l
	end
	if layer == "Attack" and l.Clip and l.T < l.Clip.Len and next(st.Last) then
		-- A23-116 고침 2: cutting a running move starts from where the arms are (CUT_BLEND s), never a snap
		st.BlendFrom, st.BlendAt = table.clone(st.Last), os.clock()
	end
	l.Clip = clip
	l.T = 0
	l.Rate = rate or 1
	Feel.bind()
	return true
end

-- the per-frame step runs only while some character plays a clip
function Feel.bind()
	if Feel.StepConn then return end
	local sig = RunService.Stepped
	pcall(function()
		sig = RunService.PreSimulation -- same point of the frame (right after the Animator), newer name
	end)
	Feel.StepAt = os.clock()
	Feel.StepConn = sig:Connect(function()
		local ok, err = pcall(Feel.step)
		if not ok then warnThrottled("procedural animation failed: " .. tostring(err)) end
	end)
	-- Both joint types apply poses after PreSimulation; follow the actual hands/weapon after that batch.
	Feel.RenderConn = RunService.RenderStepped:Connect(function()
		for st in Feel.Active do
			local ok, err = pcall(Feel.weaponMotion, st, st.Layers.Attack)
			if not ok then
				warnThrottled("weapon motion failed: " .. tostring(err))
				Feel.clearWeaponMotion(st)
			end
		end
	end)
end

function Feel.unbind()
	local conn = Feel.StepConn
	Feel.StepConn = nil
	if conn then conn:Disconnect() end
	local render = Feel.RenderConn
	Feel.RenderConn = nil
	if render then render:Disconnect() end
end

function Feel.step()
	local now = os.clock()
	local dt = math.clamp(now - Feel.StepAt, 0, 0.1)
	Feel.StepAt = now
	for st in Feel.Active do
		local ok, err = pcall(Feel.stepChar, st, dt, now)
		if not ok then
			warnThrottled("procedural joint failed: " .. tostring(err))
			Feel.drop(st)
		end
	end
	if Feel.ActiveCount <= 0 then Feel.unbind() end
end

-- advances one character's layers and writes clip offset * (the pose the Animator wrote this frame) into its joints
function Feel.stepChar(st, dt, now)
	local hum = st.Char:FindFirstChildOfClass("Humanoid")
	if not st.Char.Parent or not hum or hum.Health <= 0
		or (st.Layers.Attack and st.Layers.Attack.Clip and not Feel.validAttack(st.AttackContext)) then
		Feel.bowHand(st, false, true) -- death / a changed actor: the bow back on the right grip at once
		Feel.drop(st)
		return
	end
	local playing = false
	for layer, l in st.Layers do
		if l.Clip then
			local rate = l.Rate
			if layer == "Attack" and now < st.HoldUntil then rate = MOTION.HITSTOP_RATE end
			l.T += dt * rate
			if l.T >= l.Clip.Len then
				l.Clip = nil
			else
				playing = true
			end
		end
	end
	local bases, outputs = {}, {}
	for joint, m in st.Joints do
		local off = nil
		if playing then
			for layer, l in st.Layers do
				local track = l.Clip and l.Clip.Joints[joint]
				if track then
					local sampleTime = layer == "Attack" and st.AttackContext and st.AttackContext.Class == "Archer"
						and Feel.archerPhase(l) or l.T
					local s = Feel.sample(track, sampleTime)
					off = off and off * s or s
				end
			end
		end
		local last = st.Last[joint]
		-- The Animator rewrote the joint this frame unless it still holds our previous output.
		local cur = m.Transform
		local base = last and Feel.same(cur, last) and (st.Base[joint] or cur) or cur
		bases[joint] = base
		if off or last then
			if off then
				local attack = st.Layers.Attack
				local blend = MOTION.UPPER_BLEND[joint] or 0
				if attack and attack.Clip and attack.Clip.Joints[joint] and blend > 0 then
					local weight = math.min(math.clamp(attack.T / MOTION.LAYER_FADE_IN, 0, 1),
						math.clamp((attack.Clip.Len - attack.T) / MOTION.LAYER_FADE_OUT, 0, 1))
					base = base:Lerp(CFrame.new(), blend * weight) -- leave walk legs running; steady the attack arms
				end
				outputs[joint] = off * base
			else
				m.Transform = base -- every layer ended: hand the joint back
				st.Base[joint] = nil
				st.Last[joint] = nil
			end
		end
	end
	local attack = st.Layers.Attack
	local plain = st.AttackContext and not st.AttackContext.Style
	Feel.bowHand(st, attack ~= nil and attack.Clip ~= nil and plain and st.AttackContext.Class == "Archer")
	if attack and attack.Clip and plain and st.AttackContext.Class == "Archer" then
		Feel.archerPose(st, attack, bases, outputs)
	end -- hold-angles (최종 검수 10/16): the staff no longer turns its tip onto the target (it swung over the head);
	-- the clip leans it 20..40 forward and the magic leaves the orb (Feel.muzzle) for the target
	local blendW = st.BlendFrom and math.clamp((now - st.BlendAt) / MOTION.CUT_BLEND, 0, 1) or 1
	if blendW < 1 then
		for joint, out in outputs do
			local from = st.BlendFrom[joint]
			if from then outputs[joint] = from:Lerp(out, blendW) end
		end
	else
		st.BlendFrom = nil
	end
	-- Every solved child uses this frame's predicted parent FK, independent of table iteration order.
	for joint, out in outputs do
		st.Joints[joint].Transform = out
		st.Base[joint], st.Last[joint] = bases[joint], out
	end
	if not playing then Feel.drop(st) end
end

-- stops every layer of a character and hands back the joints it still holds
function Feel.drop(st)
	Feel.clearWeaponMotion(st)
	Feel.bowHand(st, false)
	st.AttackContext = nil
	if Feel.Active[st] then
		Feel.Active[st] = nil
		Feel.ActiveCount -= 1
	end
	for _, l in st.Layers do
		l.Clip = nil
	end
	for joint, last in st.Last do
		local m = st.Joints[joint]
		local base = st.Base[joint]
		Feel.restoreJoint(m, base, last)
	end
	table.clear(st.Last)
	table.clear(st.Base)
end

-- seconds a class move must finish in (Swing: SwingInterval x SWING_FIT, Release: RELEASE_ANIM_TIME)
function Feel.attackTime(classId, which, style)
	local def = Config.Classes[classId] or Config.Classes.Warrior
	local interval = style == "Punch" and Config.Combat.Unarmed.Interval or def.SwingInterval -- A23-34 punch 0.8 s
	local fit = math.max(0.1, tonumber(interval) or 1) * MOTION.SWING_FIT
	return which == "Release" and math.min(MOTION.RELEASE_ANIM_TIME, fit) or fit
end

-- hold-angles (10/16, STUDIO ONLY, this client only): workspace attribute Dev1Clips = a JSON { [clip name] = { Len, Keys } }
-- (MOTION.CLIPS rows) laid over MOTION.CLIPS while set, recompiled; cleared = the shipped clips. For tuning in a test Play
Feel.ClipTune = { Last = nil, Orig = {} }
function Feel.tuneClips()
	local CLIPTUNE = Feel.ClipTune
	local raw = workspace:GetAttribute("Dev1Clips")
	if raw == CLIPTUNE.Last then return end
	CLIPTUNE.Last = raw
	for name, def in CLIPTUNE.Orig do MOTION.CLIPS[name] = def end
	table.clear(CLIPTUNE.Orig)
	if type(raw) == "string" and raw ~= "" then
		for name, def in game:GetService("HttpService"):JSONDecode(raw) do
			if MOTION.CLIPS[name] and type(def) == "table" and type(def.Keys) == "table" then
				CLIPTUNE.Orig[name] = MOTION.CLIPS[name]
				MOTION.CLIPS[name] = def
			end
		end
	end
	Feel.compileClips()
end

-- class Swing / Release clip on a character, sped up to fit maxTime. true when the clip plays (or a running release
-- must not be cut short by a swing); false -> the caller may use the stock animation
function Feel.playAttack(char, classId, which, maxTime, data)
	if typeof(char) ~= "Instance" then return false end
	pcall(function() if RunService:IsStudio() then Feel.tuneClips() end end)
	local context = Feel.attackContext(data)
	if not context or context.Char ~= char then return false end
	local style = type(data.Style) == "string" and MOTION.STYLE_CLIPS[data.Style] and data.Style or nil
	local names = style and MOTION.STYLE_CLIPS[style] or MOTION.CLASS_CLIPS[classId] or MOTION.CLASS_CLIPS.Warrior
	if style == "PetHeadbutt" and MOTION.PetDrawn(data) then names = MOTION.STYLE_CLIPS.PetCommand end
	if not style then names = MOTION.SideClips(char, classId) or names end -- A23-108: the class x side's own moves
	local name = names[which] or (MOTION.CLASS_CLIPS[classId] or MOTION.CLASS_CLIPS.Warrior)[which]
	local clip = name and Feel.Clips[name]
	if not clip then return false end
	context.Style = style
	local now = os.clock()
	local st = Feel.Chars[char]
	-- A23-116 고침 1: only a basic swing waits for a skill move (a Z / X after the 0.5 s global gap plays)
	if which == "Swing" and st and Feel.Active[st] and Feel.validAttack(st.AttackContext)
		and now < st.ReleaseUntil then return true end
	local rate = math.clamp(clip.Len / math.max(0.05, maxTime), 1, MOTION.ANIM_MAX_SPEED)
	local launch = math.clamp(asNum(data.LaunchDelay, which == "Release" and MOTION.RELEASE_LAUNCH[classId]
		or (classId == "Archer" and MOTION.SHOT_DELAY or MOTION.CAST_DELAY)), 0, 1)
	if classId == "Archer" and not style then
		-- Packet launch time is real seconds. Reserve recovery time even when the clip is sped up;
		-- its launch key is remapped to that exact time rather than using rate-scaled clip seconds.
		rate = math.min(rate, clip.Len / math.max(0.05, launch + MOTION.BOW.Settle + 0.015))
	end
	if not Feel.play(char, "Attack", name, rate) then return false end
	local current = Feel.Chars[char]
	current.AttackContext = context
	Feel.clearWeaponMotion(current)
	current.AttackSerial, current.BowReleased = {}, false
	current.Layers.Attack.Which = which -- A23-116 고침 3: Feel.archerPhase picks the shot time by the slot, not the name
	if classId == "Archer" and not style then
		current.Layers.Attack.LaunchT = launch * rate
		if clip.Redraw and clip.Shot2 then Feel.secondShot(context, current, clip, rate) end
		current.AttackTarget = which == "Release" and asVec(data.Pos) and (data.Pos + Vector3.new(0, 30, 0))
			or (type(data.Targets) == "table" and asVec(data.Targets[1])) or nil
	elseif classId == "Mage" and not style then
		current.Layers.Attack.LaunchT = launch * rate
		current.AttackTarget = which == "Release" and asVec(data.Pos) and data.Pos
			or (type(data.Targets) == "table" and asVec(data.Targets[1])) or nil
	else
		current.Layers.Attack.LaunchT = nil
		current.AttackTarget = nil
	end
	if which ~= "Swing" then current.ReleaseUntil = now + math.min(MOTION.RELEASE_HOLD, maxTime) end -- Release, Z, X
	return true
end

-- A23-116 고침 4 (Spark Shower): a clip with Redraw / Shot2 draws the bow again after the first shot and lets go at
-- Shot2 (clip seconds; only the first shot is the server's - SkillFx draws the second arrow)
function Feel.secondShot(ctx, st, clip, rate)
	local serial = st.AttackSerial
	local attack = st.Layers.Attack
	local function same() return st.AttackSerial == serial and attack.Clip == clip end
	Feel.after(ctx, clip.Redraw / rate, function()
		if not same() then return end
		st.BowReleased = false
		attack.LaunchT = clip.Shot2
	end)
	Feel.after(ctx, clip.Shot2 / rate, function()
		if same() then st.BowReleased = true end
	end)
end

-- another player's Swing / Release -> the clip on their character (near the camera only)
function Feel.animateOther(data, which)
	local uid = asNum(data.UserId, nil)
	if not uid then return end
	local p = Players:GetPlayerByUserId(math.floor(uid))
	local char = p and p.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or not Feel.near(root.Position, MOTION.PROC_DIST) then return end
	local classId = asStr(data.Class, "Warrior")
	Feel.playAttack(char, classId, which, Feel.attackTime(classId, which, data.Style), data)
end

-- my hits landed: my attack layer (or the stock track, R6) runs at HITSTOP_RATE for HITSTOP_TIME (HITSTOP_CRIT for a
-- crit), then normal again
function Feel.hitStop(crit)
	local now = os.clock()
	local hold = crit and MOTION.HITSTOP_CRIT or MOTION.HITSTOP_TIME
	local char = LocalPlayer and LocalPlayer.Character
	local st = char and Feel.Chars[char]
	if st then st.HoldUntil = now + hold end
	local track = animCurrent
	if track and track.IsPlaying and not Feel.StopTrack then
		Feel.StopTrack = track
		Feel.StopSpeed = track.Speed
		track:AdjustSpeed(MOTION.HITSTOP_RATE)
		later(hold, function()
			local t = Feel.StopTrack
			Feel.StopTrack = nil
			if t and t.IsPlaying then t:AdjustSpeed(Feel.StopSpeed) end
		end)
	end
end

-- one-shot camera-facing art image at pos.
-- o = { Size0, Size1 (studs), Time, Fade?, FadeDelay?, Rot0?, Rot1? (degrees), Color? (tint), Top? (AlwaysOnTop) }
function Feel.popImage(id, pos, o)
	local part = makePart({
		Name = "FxPop",
		Size = Vector3.new(0.1, 0.1, 0.1),
		CFrame = CFrame.new(pos),
		Transparency = 1,
	})
	local gui = Instance.new("BillboardGui")
	gui.AlwaysOnTop = o.Top == true
	gui.LightInfluence = 0
	gui.MaxDistance = CULL_DISTANCE
	gui.Size = UDim2.fromScale(o.Size0, o.Size0)
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.ScaleType = Enum.ScaleType.Fit
	img.Image = id
	img.ImageColor3 = o.Color or WHITE
	img.Rotation = o.Rot0 or 0
	img.Parent = gui
	gui.Parent = part
	tween(gui, o.Time, { Size = UDim2.fromScale(o.Size1, o.Size1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	if o.Rot1 then
		tween(img, o.Time, { Rotation = o.Rot1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end
	local fade, fadeDelay = o.Fade or o.Time, o.FadeDelay or 0
	tween(img, fade, { ImageTransparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, fadeDelay)
	Debris:AddItem(part, math.max(o.Time, fadeDelay + fade) + 0.1)
end

-- code fallback flash, drawn like the art (camera-facing, AlwaysOnTop) so it never hides inside the body it hit:
-- a comic star of 4 crossed rays (long white / short `color`) around a round core, popping s0 -> s1 studs while it
-- turns a little and fades
function Feel.popStar(pos, color, s0, s1, time)
	local part = makePart({
		Name = "FxPopStar",
		Size = Vector3.new(0.1, 0.1, 0.1),
		CFrame = CFrame.new(pos),
		Transparency = 1,
	})
	local gui = Instance.new("BillboardGui")
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = CULL_DISTANCE
	gui.Size = UDim2.fromScale(s0, s0)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(1, 1)
	holder.Rotation = rng:NextNumber(0, 45)
	holder.Parent = gui
	for i = 0, 4 do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.BorderSizePixel = 0
		if i < 4 then
			f.Size = UDim2.fromScale(i % 2 == 0 and 1 or 0.72, i % 2 == 0 and 0.13 or 0.1)
			f.Rotation = i * 45
			f.BackgroundColor3 = i % 2 == 0 and WHITE or color
		else
			f.Size = UDim2.fromScale(0.36, 0.36) -- core
			f.BackgroundColor3 = color
		end
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
		f.Parent = holder
		tween(f, time, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	gui.Parent = part
	tween(gui, time, { Size = UDim2.fromScale(s1, s1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	tween(holder, time, { Rotation = holder.Rotation + 20 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	Debris:AddItem(part, time + 0.1)
end

-- FxHitSpark where one of my hits landed (pop 0.6 -> 1.2, fade SPARK_TIME); fallback: white star + sparks (both drawn
-- in front of the body: AlwaysOnTop / particle ZOffset)
function Feel.hitSpark(pos, crit)
	if not nearCamera(pos) then return end
	local s = MOTION.SPARK_SIZE * (crit and MOTION.SPARK_CRIT_MULT or 1)
	local id = Feel.art("FxHitSpark")
	if id then
		Feel.popImage(id, pos, { Size0 = s * 0.6, Size1 = s * 1.2, Time = MOTION.SPARK_TIME, Rot0 = rng:NextNumber(0, 360), Top = true })
	else
		Feel.popStar(pos, crit and COLOR_CRIT or MOTION.SPARK_TINT, s * 0.35, s * 0.8, MOTION.SPARK_TIME + 0.05)
		burst(pos, ColorSequence.new(WHITE, COLOR_CRIT), crit and 10 or 6, {
			Size = 0.35, SpeedMin = 14, SpeedMax = 26, LifeMin = 0.12, LifeMax = 0.25, LightEmission = 1,
			Acceleration = Vector3.zero, Drag = 6, ZOffset = 2,
		})
	end
end

-- FxMagicBurst (Mage hit at the target; big = meteor landing); fallback: violet star + sparkles (in front of the body)
function Feel.magicBurst(pos, big)
	if not nearCamera(pos) then return end
	local s = MOTION.MAGIC_SIZE * (big and 1.8 or 1)
	local id = Feel.art("FxMagicBurst")
	if id then
		local r = rng:NextNumber(0, 360)
		Feel.popImage(id, pos, { Size0 = s * 0.4, Size1 = s, Time = 0.22, Fade = 0.2, FadeDelay = 0.08, Rot0 = r, Rot1 = r + 40, Top = true })
	else
		Feel.popStar(pos, MOTION.MAGIC_COLOR, s * 0.3, s * 0.75, 0.22)
		burst(pos, ColorSequence.new(WHITE, MOTION.MAGIC_COLOR), big and 26 or 14, {
			Size = big and 0.8 or 0.5, SpeedMin = 8, SpeedMax = 18, LifeMin = 0.2, LifeMax = 0.4, LightEmission = 1,
			Acceleration = Vector3.zero, Drag = 4, ZOffset = 2,
		})
	end
end

-- code fallback slash: two attachments on an invisible pivot sweep an arc around the look axis and the Trail
-- between them draws the crescent (white -> faction color)
function Feel.slashTrail(cf, radius, color, time)
	local pivot = makePart({
		Name = "FxSlash",
		Size = Vector3.new(0.1, 0.1, 0.1),
		CFrame = cf * CFrame.Angles(0, 0, math.rad(MOTION.SLASH_FROM)),
		Transparency = 1,
	})
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, radius, 0)
	a0.Parent = pivot
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, radius * 0.55, 0)
	a1.Parent = pivot
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.LightEmission = 1
	tr.Color = ColorSequence.new(WHITE, color)
	tr.Transparency = NumberSequence.new(0.05, 1)
	tr.WidthScale = NumberSequence.new(1, 0.25)
	tr.Lifetime = time
	tr.MinLength = 0.05
	tr.Parent = pivot
	local sweep = time * 0.6
	tween(pivot, sweep, { CFrame = cf * CFrame.Angles(0, 0, math.rad(MOTION.SLASH_TO)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	Debris:AddItem(pivot, sweep + time + 0.05)
end

-- my swing's slash arc in front of my character, tinted by faction color (big = Warrior release smash)
function Feel.slash(color, big)
	local root = getOwnRoot()
	if not root then return end
	local cf = root.CFrame
	local look = cf.LookVector
	local chest = cf.Position + Vector3.new(0, 0.6, 0) + look * (MOTION.SLASH_DIST * (big and 1.3 or 1))
	local s = MOTION.SLASH_SIZE * (big and 1.6 or 1)
	local id = Feel.art("FxSlash")
	if id then
		Feel.popImage(id, chest, {
			Size0 = s * 0.8, Size1 = s * 1.1, Time = MOTION.SLASH_TIME, Fade = MOTION.SLASH_TIME * 0.8,
			FadeDelay = MOTION.SLASH_TIME * 0.2, Rot0 = MOTION.SLASH_ROT0, Rot1 = MOTION.SLASH_ROT1, Color = color,
		})
	else
		local plane = CFrame.lookAt(chest, chest + look) * CFrame.Angles(math.rad(MOTION.SLASH_PLANE_TILT), 0, 0)
		Feel.slashTrail(plane, s * 0.5, color, MOTION.SLASH_TIME)
	end
end

-- FxDust puffs at a monster's feet as its lunge starts; fallback: dust particles
function Feel.dust(root, h, rh)
	if not root.Parent or not nearCamera(root.Position) then return end
	local cf = root.CFrame
	local size = math.clamp(h * 0.45, 1.6, 6)
	local base = cf.Position - Vector3.new(0, rh - size * 0.3, 0) - cf.LookVector * (h * 0.12)
	local id = Feel.art("FxDust")
	for side = -1, 1, 2 do
		local pos = base + cf.RightVector * (side * h * 0.22)
		if id then
			Feel.popImage(id, pos, { Size0 = size * 0.5, Size1 = size * 1.1, Time = 0.35, Fade = 0.28, FadeDelay = 0.1, Rot0 = rng:NextNumber(-20, 20) })
		else
			burst(pos, COLOR_DUST, 5, {
				Size = size * 0.35, EndSize = size * 0.6, SpeedMin = 2, SpeedMax = 5, LifeMin = 0.3, LifeMax = 0.5,
				LightEmission = 0, StartTransparency = 0.25, Spread = Vector2.new(70, 70),
				Acceleration = Vector3.new(0, 2, 0), Drag = 4,
			})
		end
	end
end

-- leanCF around any horizontal root-space axis (the top moves toward axis x up)
function Feel.tiltCF(rootHeight, offset, axis, deg)
	local pivot = CFrame.new(0, -rootHeight, 0)
	return CFrame.new(offset) * pivot * CFrame.fromAxisAngle(axis, math.rad(deg)) * pivot:Inverse()
end

-- recoil of a monster my hit landed on: tilt away from me and push back along the hit direction, then settle
function Feel.recoil(model, st, root, ownRoot, h, rh, mult)
	if st.TeleUntil then return end -- keep the wind-up readable
	local cf = root.CFrame
	local away = ownRoot and (root.Position - ownRoot.Position) or -cf.LookVector
	local d = cf:VectorToObjectSpace(Vector3.new(away.X, 0, away.Z))
	d = Vector3.new(d.X, 0, d.Z)
	if d.Magnitude < 1e-3 then
		d = Vector3.new(0, 0, 1) -- straight back
	else
		d = d.Unit
	end
	local axis = Vector3.new(d.Z, 0, -d.X)
	st.RecoilAt = os.clock()
	playJointSeq(model, {
		{ Feel.tiltCF(rh, d * (MOTION.RECOIL_PUSH * h * mult), axis, MOTION.RECOIL_TILT * mult), MOTION.RECOIL_IN },
		{ CFrame.identity, MOTION.RECOIL_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut },
	}, false)
end

-- wind-up length of a monster: attribute WindupTime, MonsterTypes[kind].WindupTime, Config.HitReact.MonsterWindup
-- (A15 server value), TELE_DEFAULT
function Feel.windupTime(model)
	local v = model:GetAttribute(MOTION.WINDUP_TIME_ATTR)
	if type(v) ~= "number" then
		local kind = model:GetAttribute("MonsterKind")
		local def = type(kind) == "string" and Config.MonsterTypes[kind] or nil
		v = type(def) == "table" and def.WindupTime or nil
		local react = Config.HitReact
		if type(v) ~= "number" and type(react) == "table" then v = react.MonsterWindup end
	end
	return math.clamp(asNum(v, MOTION.TELE_DEFAULT), 0.1, 2)
end

-- WindupAt changed: crouch + lean back (slimes squash) deepening until the strike, two red tint blinks. The lunge on
-- AttackSeq then starts from this pose. nil / <= 0 cancels (back to rest unless the strike follows right away).
function Feel.onWindup(model)
	local st = monsterMotion[model]
	local root = monsterRoot(model)
	if not st or not root then return end
	local v = model:GetAttribute(MOTION.WINDUP_ATTR)
	if type(v) ~= "number" or v <= 0 then
		if st.TeleUntil then
			local cancelToken = st.Token
			later(0.12, function()
				if monsterMotion[model] == st and st.Token == cancelToken and st.TeleUntil then
					st.TeleUntil = nil
					playJointSeq(model, { { CFrame.identity, 0.15 } }, false)
				end
			end)
		end
		return
	end
	if not nearCamera(root.Position) then return end
	local dur = Feel.windupTime(model)
	local remaining = dur
	local okNow, serverNow = pcall(function()
		return workspace:GetServerTimeNow()
	end)
	if okNow and type(serverNow) == "number" then
		local elapsed = serverNow - v
		if elapsed >= dur and elapsed < 3 then return end -- arrived after the strike
		if elapsed > 0 and elapsed < dur then remaining = dur - elapsed end
	end
	remaining = math.max(0.12, remaining)
	local h, rh = monsterSize(model)
	local pose, deep
	if isSlimeModel(model) then
		pose = leanCF(rh, Vector3.new(0, -MOTION.SLIME_TELE_DOWN * h, MOTION.TELE_BACK * h), MOTION.SLIME_TELE_TILT)
		deep = leanCF(rh, Vector3.new(0, -MOTION.SLIME_TELE_DOWN2 * h, MOTION.TELE_BACK2 * h), MOTION.SLIME_TELE_TILT)
	else
		pose = leanCF(rh, Vector3.new(0, -MOTION.TELE_DOWN * h, MOTION.TELE_BACK * h), MOTION.TELE_TILT)
		deep = leanCF(rh, Vector3.new(0, -MOTION.TELE_DOWN2 * h, MOTION.TELE_BACK2 * h), MOTION.TELE_TILT2)
	end
	local inTime = math.min(MOTION.TELE_IN, remaining * 0.5)
	st.TeleUntil = os.clock() + remaining
	playJointSeq(model, {
		{ pose, inTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out },
		{ deep, remaining - inTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut },
	}, true)
	local token = st.Token
	-- custom-model visuals (A1) are not tinted (their procedural parts are invisible hitboxes)
	if not model:FindFirstChild("CustomVisual") then
		flashModel(model, MOTION.TELE_COLOR, MOTION.TELE_FLASH)
		later(math.max(MOTION.TELE_FLASH * 2, remaining - MOTION.TELE_FLASH), function()
			if st.Token == token and model.Parent then flashModel(model, MOTION.TELE_COLOR, MOTION.TELE_FLASH) end
		end)
	end
	-- no strike came (target escaped): back to rest
	later(remaining + MOTION.TELE_GRACE, function()
		if monsterMotion[model] == st and st.Token == token then
			st.TeleUntil = nil
			playJointSeq(model, { { CFrame.identity, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut } }, false)
		end
	end)
end

-- the server's "big hit" mark of the latest HurtSeq bump (true, or the HurtSeq value); `fallback` without the contract
function Feel.hurtBig(model, fallback)
	local bigAttr = model:GetAttribute(MOTION.HURT_BIG_ATTR)
	if bigAttr == nil then return fallback == true end
	return bigAttr == true or (type(bigAttr) == "number" and bigAttr == model:GetAttribute(MOTION.HURT_SEQ_ATTR))
end

-- a Swing / Release hit on a monster at pos will show `secs` s from now (ring buffer, slots reused)
function Feel.expect(pos, secs)
	local at = os.clock() + secs
	Feel.PendingCursor = Feel.PendingCursor % MOTION.PENDING_MAX + 1
	local slot = Feel.Pending[Feel.PendingCursor]
	if slot then
		slot.Pos, slot.At = pos, at
	else
		Feel.Pending[Feel.PendingCursor] = { Pos = pos, At = at }
	end
end

-- remembers the monster hits of a Swing / Release payload that show `secs` s from now (near the camera only)
function Feel.expectHits(hits, secs)
	if type(hits) ~= "table" or secs <= 0 then return end
	for _, h in hits do
		if type(h) == "table" and h.K == "M" then
			local p = asVec(h.P)
			if p and Feel.near(p, MOTION.STICKER_DIST) then Feel.expect(p, secs) end
		end
	end
end

-- seconds until the next remembered hit near pos shows (0 = none pending), capped by HURT_SYNC_MAX
function Feel.pendingDelay(pos)
	local now = os.clock()
	local best = math.huge
	for _, slot in Feel.Pending do
		local left = slot.At - now
		if left > 0 and left < best and (slot.Pos - pos).Magnitude <= MOTION.PENDING_DIST then best = left end
	end
	if best == math.huge then return 0 end
	return math.min(best, MOTION.HURT_SYNC_MAX)
end

-- 손맛 ③⑤ (GPT game_feel_r1, 최종 검수 10/16): fn runs once the hit remembered near pos has shown (after
-- HURT_SYNC_WAIT for the Swing / Release Fx of the same server frame); at once when no such hit is pending
function Feel.afterHit(pos, fn)
	if typeof(pos) ~= "Vector3" then
		fn()
		return
	end
	later(MOTION.HURT_SYNC_WAIT, function()
		local left = Feel.pendingDelay(pos)
		if left > 0.02 then later(left + MOTION.HIT_AFTER, fn) else fn() end
	end)
end

-- (Audio) seconds until the hit remembered near pos shows; 0 = none
function Fx.HitWait(pos)
	if typeof(pos) ~= "Vector3" then return 0 end
	local left = Feel.pendingDelay(pos)
	return left > 0.02 and left + MOTION.HIT_AFTER or 0
end

-- pain sticker + a quick squash flinch (not while it attacks / winds up, and not right after my own directional recoil)
function Feel.hurtReact(model, big)
	local st = monsterMotion[model]
	local root = monsterRoot(model)
	if not st or not root or root.Anchored or not model.Parent then return end
	if not Feel.near(root.Position, MOTION.STICKER_DIST) then return end
	local h, rh = monsterSize(model)
	Feel.monsterPain(st, root, h, rh, big)
	if st.Attack or st.TeleUntil or os.clock() - (st.RecoilAt or -math.huge) < MOTION.FLINCH_SKIP then return end
	local k = big and MOTION.FLINCH_BIG or 1
	playJointSeq(model, {
		{ leanCF(rh, Vector3.new(0, -MOTION.FLINCH_DOWN * h * k, MOTION.FLINCH_BACK * h * k), MOTION.FLINCH_TILT * k), MOTION.FLINCH_IN },
		{ CFrame.identity, MOTION.FLINCH_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut },
	}, false)
end

-- HurtSeq changed (anyone hit this monster): the reaction waits HURT_SYNC_WAIT for the Swing / Release Fx of the
-- same hit, then until that hit shows (projectile flight / contact frame); damage without such an Fx reacts then
function Feel.onMonsterHurt(model)
	local root = monsterRoot(model)
	if not monsterMotion[model] or not root or not Feel.near(root.Position, MOTION.STICKER_DIST) then return end
	local big = Feel.hurtBig(model, false) -- read now: a later hit rewrites HurtBig
	later(MOTION.HURT_SYNC_WAIT, function()
		local r = monsterRoot(model)
		if not r then return end
		local left = Feel.pendingDelay(r.Position)
		if left > 0.02 then
			later(left, function()
				Feel.hurtReact(model, big)
			end)
		else
			Feel.hurtReact(model, big)
		end
	end)
end

function Feel.pickEmo(big, last)
	local list = big and MOTION.EMO_BIG or MOTION.EMO_HURT
	local emo = list[rng:NextInteger(1, #list)]
	if emo == last then emo = list[rng:NextInteger(1, #list)] end
	return emo
end

-- one pooled sticker: BillboardGui (PlayerGui, Adornee set per use) > Holder (UIScale pop, tilt) > Image | Bubble+Text
function Feel.buildSticker(pg)
	local gui = Instance.new("BillboardGui")
	gui.Name = "FxPainSticker"
	gui.ResetOnSpawn = false
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = MOTION.STICKER_DIST
	gui.Enabled = false
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	local img = Instance.new("ImageLabel")
	img.Name = "Image"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = holder
	-- fallback "아야!" speech burst: white rounded bubble with an ink outline
	local bubble = Instance.new("Frame")
	bubble.Name = "Bubble"
	bubble.AnchorPoint = Vector2.new(0.5, 0.5)
	bubble.Position = UDim2.fromScale(0.5, 0.5)
	bubble.Size = UDim2.fromScale(1, 0.62)
	bubble.BackgroundColor3 = WHITE
	bubble.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.45, 0)
	corner.Parent = bubble
	local stroke = Instance.new("UIStroke")
	stroke.Color = MOTION.STICKER_INK
	stroke.Thickness = 2
	stroke.Parent = bubble
	bubble.Parent = holder
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.AnchorPoint = Vector2.new(0.5, 0.5)
	text.Position = UDim2.fromScale(0.5, 0.5)
	text.Size = UDim2.fromScale(1, 1)
	text.Font = FONT_NUMBER
	text.TextScaled = true
	text.TextStrokeColor3 = MOTION.STICKER_INK
	text.Text = ""
	text.ZIndex = 2
	addTextConstraint(text, 80)
	text.Parent = holder
	gui.Parent = pg
	return { Gui = gui, Holder = holder, Scale = scale, Image = img, Bubble = bubble, Stroke = stroke, Text = text, Busy = false, Token = 0 }
end

-- a free pooled sticker (rebuilt when its gui was destroyed), a new one while under STICKER_MAX, else nil
function Feel.stickerEntry()
	local pg = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then return nil end
	for i, e in Feel.Stickers do
		if not e.Busy then
			if e.Gui.Parent == pg then return e end
			pcall(function()
				e.Gui:Destroy()
			end)
			local fresh = Feel.buildSticker(pg)
			Feel.Stickers[i] = fresh
			return fresh
		end
	end
	if #Feel.Stickers >= MOTION.STICKER_MAX then return nil end
	local e = Feel.buildSticker(pg)
	table.insert(Feel.Stickers, e)
	return e
end

-- pops pain sticker `emo` (Config.UIArt part name) on adornee: scale-pop, float up, fade. false at the global cap
function Feel.sticker(adornee, emo, size, offset)
	local e = Feel.stickerEntry()
	if not e then return false end
	e.Busy = true
	e.Token += 1
	local token = e.Token
	local gui = e.Gui
	gui.Adornee = adornee
	gui.Size = UDim2.fromScale(size, size)
	gui.StudsOffset = Vector3.new(size * MOTION.STICKER_SIDE, 0, 0) -- beside the head, clear of the nametag / HP bar
	gui.StudsOffsetWorldSpace = offset
	local fade, fadeAt = MOTION.STICKER_FADE, MOTION.STICKER_LIFE - MOTION.STICKER_FADE
	local id = Feel.art(emo)
	if id then
		e.Image.Image = id
		e.Image.ImageTransparency = 0
		e.Image.Visible = true
		e.Bubble.Visible = false
		-- a blank bubble art (EmoOuch, 이미지 개발 10/08) gets its words in the art's TextRect; an art without one has its own
		local rect = Feel.textRect(emo)
		local words = rect and MOTION.EMO_FALLBACK[emo]
		e.Text.Visible = words ~= nil
		if words then
			e.Text.Text = words.Text
			e.Text.TextColor3 = words.Color
			e.Text.Position = UDim2.fromScale(rect[1] + rect[3] / 2, rect[2] + rect[4] / 2)
			e.Text.Size = UDim2.fromScale(rect[3], rect[4])
			e.Text.TextTransparency = 0
			e.Text.TextStrokeTransparency = 0
			tween(e.Text, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, fadeAt)
		end
		tween(e.Image, fade, { ImageTransparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, fadeAt)
	else
		local fb = MOTION.EMO_FALLBACK[emo] or MOTION.EMO_FALLBACK.EmoOuch
		local bubble = fb.Bubble == true
		e.Image.Visible = false
		e.Bubble.Visible = bubble
		e.Text.Visible = true
		e.Text.Text = fb.Text
		e.Text.TextColor3 = fb.Color
		e.Text.Position = UDim2.fromScale(0.5, 0.5) -- a TextRect sticker may have moved it
		e.Text.Size = bubble and UDim2.fromScale(0.84, 0.46) or UDim2.fromScale(1, 1)
		e.Text.TextTransparency = 0
		e.Text.TextStrokeTransparency = 0
		tween(e.Text, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, fadeAt)
		if bubble then
			e.Bubble.BackgroundTransparency = 0
			e.Stroke.Transparency = 0
			tween(e.Bubble, fade, { BackgroundTransparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, fadeAt)
			tween(e.Stroke, fade, { Transparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, fadeAt)
		end
	end
	e.Holder.Rotation = rng:NextNumber(-MOTION.STICKER_TILT, MOTION.STICKER_TILT)
	e.Scale.Scale = 0.3
	gui.Enabled = true
	tween(e.Scale, MOTION.STICKER_POP, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	tween(gui, MOTION.STICKER_LIFE, { StudsOffsetWorldSpace = offset + Vector3.new(0, MOTION.STICKER_RISE, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(MOTION.STICKER_LIFE + 0.03, function()
		if e.Token ~= token then return end
		e.Busy = false
		gui.Enabled = false
		gui.Adornee = nil
	end)
	return true
end

-- pain sticker beside a monster's head: one per monster per MONSTER_STICKER_GAP, near the camera only (big -> mostly
-- EmoDizzy); never on a dying monster (anchored root)
function Feel.monsterPain(st, root, h, rh, big)
	local now = os.clock()
	if root.Anchored or now < (st.StickerUntil or 0) or not Feel.near(root.Position, MOTION.STICKER_DIST) then return end
	local emo = Feel.pickEmo(big, st.LastEmo)
	local size = math.clamp(h * MOTION.MONSTER_STICKER_K, MOTION.MONSTER_STICKER_MIN, MOTION.MONSTER_STICKER_MAX)
	if Feel.sticker(root, emo, size, Vector3.new(0, (h - rh) + size * MOTION.MONSTER_STICKER_Y, 0)) then
		st.StickerUntil = now + math.max(MOTION.STICKER_LIFE, MOTION.MONSTER_STICKER_GAP)
		st.LastEmo = emo
	end
end

-- a player got hurt: sticker beside the head and the hurt clip (R15, near); for me a smaller, rarer sticker
-- (PAIN_GAP_OWN) and a camera kick on big hits only (the Hurt handler kicks for hard hits).
-- The Pain Fx (any player) and my Hurt Fx both land here; the gap keeps it to one per hit.
function Feel.playerPain(userId, big)
	local now = os.clock()
	local own = LocalPlayer ~= nil and userId == LocalPlayer.UserId
	if now - (Feel.PainAt[userId] or -math.huge) < (own and MOTION.PAIN_GAP_OWN or MOTION.PAIN_GAP) then return end
	local p = Players:GetPlayerByUserId(userId)
	local char = p and p.Character
	local head = char and char:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end -- a lethal hit is left to the KO effects
	if not own and not Feel.near(head.Position, MOTION.STICKER_DIST) then return end
	Feel.PainAt[userId] = now
	local size = MOTION.PLAYER_STICKER_SIZE * (own and MOTION.OWN_STICKER_MULT or 1)
	Feel.sticker(head, Feel.pickEmo(big, nil), size, Vector3.new(0, MOTION.PLAYER_STICKER_Y, 0))
	if own or Feel.near(head.Position, MOTION.PROC_DIST) then
		Feel.play(char, "Hurt", big and "HurtBig" or "Hurt", 1)
	end
	if own and big then
		Fx.Shake(MOTION.PAIN_KICK * 1.5, MOTION.PAIN_KICK_TIME)
	end
end

-- monster naturalness (2026-10-06): the server sets AlertAt when a monster first spots its target and holds it still
-- for a moment -> a '!' bubble over it (the pain sticker waits for it)
function Feel.onMonsterAlert(model)
	local st = monsterMotion[model]
	local root = monsterRoot(model)
	local v = model:GetAttribute("AlertAt")
	if not st or st.Hidden or not root or root.Anchored or type(v) ~= "number" or v <= 0 then return end
	if not Feel.near(root.Position, MOTION.STICKER_DIST) then return end
	local h, rh = monsterSize(model)
	local size = math.clamp(h * MOTION.MONSTER_STICKER_K, MOTION.MONSTER_STICKER_MIN, MOTION.MONSTER_STICKER_MAX)
	if Feel.sticker(root, "EmoAlert", size, Vector3.new(0, (h - rh) + size * MOTION.MONSTER_STICKER_Y, 0)) then
		st.StickerUntil = os.clock() + MOTION.STICKER_LIFE
	end
end

Feel.MonsterAttr[MOTION.ATTACK_SEQ_ATTR] = onMonsterAttack
Feel.MonsterAttr[MOTION.WINDUP_ATTR] = Feel.onWindup
Feel.MonsterAttr[MOTION.HURT_SEQ_ATTR] = Feel.onMonsterHurt
Feel.MonsterAttr.AlertAt = Feel.onMonsterAlert

----------------------------------------------------------------- hit numbers
-- A9-2: my own hits flash the hit monsters white; crits and my Release numbers pop; numbers merge;
-- other players' Swing numbers are shown only for crits (protects the MaxDamagePopups pool).
-- feel (A14-4, my hits): { Stop = hit-stop of my attack motion (Warrior: the hits show on its contact frame; Mage /
-- Archer clips are already recovering when the projectile lands), Kick = camera kick (manual swings; crits always) }
-- A23-186: a joke weapon's hit (Fx "Swing" Meme = a Config.WeaponMemes key): its sound once, its particle on each hit;
-- an empty SoundId / ParticleId = nothing (the assets are not made yet)
function Feel.memeHits(key, hits)
	local def = type(key) == "string" and type(Config.WeaponMemes) == "table" and Config.WeaponMemes[key] or nil
	if type(def) ~= "table" or type(hits) ~= "table" then return 0 end
	local n = 0
	for _, h in hits do
		local p = type(h) == "table" and asVec(h.P) or nil
		if p then
			n += 1
			if n == 1 and type(def.SoundId) == "string" and def.SoundId ~= "" then
				local s = Instance.new("Sound")
				s.Name = "Fx_Meme" .. key
				s.SoundId = def.SoundId
				s.Volume = 0.6 * math.clamp(tonumber(MOTION.Pref("Sfx", 1)) or 1, 0, 1)
				s.Parent = SoundService
				SoundService:PlayLocalSound(s)
				Debris:AddItem(s, 3)
			end
			if type(def.ParticleId) == "string" and def.ParticleId ~= "" then
				local a = Instance.new("Attachment")
				a.WorldPosition = p
				a.Parent = workspace.Terrain
				local e = Instance.new("ParticleEmitter")
				e.Texture = def.ParticleId
				e.Rate, e.Lifetime, e.Speed = 0, NumberRange.new(0.5, 0.9), NumberRange.new(4, 8)
				e.SpreadAngle = Vector2.new(180, 180)
				e.Parent = a
				e:Emit(8)
				Debris:AddItem(a, 1.5)
			end
		end
	end
	return n
end

local function showHits(hits, own, fromRelease, feel)
	if type(hits) ~= "table" then return end
	local scaleMult = own and 1 or 0.85
	local pop = own and fromRelease == true
	local tag = own and "o" or "x" -- own and other players' numbers never merge into each other
	local flashAt = {}
	local shown = 0
	local sparks, anyCrit = 0, false -- A14-4 impact art on my hits
	for _, h in hits do
		if type(h) == "table" then
			local p = asVec(h.P)
			local a = asNum(h.A, 0)
			local kind = h.K
			-- CR-M23: a PvP hit on me already shows as my Hurt number (+ edge flash); skip the attacker's copy
			if kind == "P" and not own and LocalPlayer and asNum(h.V, -1) == LocalPlayer.UserId then continue end
			-- CR-L15: the owner's hits on their personal monster (hidden here) show no number over empty ground
			if p and not own and kind ~= "P" and kind ~= "G" and next(Feel.HiddenRoots) ~= nil then
				local okHidden, nearHidden = pcall(Feel.nearHidden, p)
				if okHidden and nearHidden then continue end
			end
			local crit = h.C == true
			if p then
				if own and kind ~= "P" and kind ~= "G" and #flashAt < 16 then
					table.insert(flashAt, p)
				end
				if own and sparks < MOTION.SPARK_MAX then
					sparks += 1
					anyCrit = anyCrit or crit
					local at = p + Vector3.new(rng:NextNumber(-0.4, 0.4), 0.6 + rng:NextNumber(0, 0.5), rng:NextNumber(-0.4, 0.4))
					local okSpark, errSpark = pcall(Feel.hitSpark, at, crit)
					if not okSpark then warnThrottled("hit spark failed: " .. tostring(errSpark)) end
				end
				if shown < POPUP_COUNT and (own or fromRelease == true or crit) then
					shown += 1
					local at = p + Vector3.new(rng:NextNumber(-0.8, 0.8), 2 + rng:NextNumber(0, 0.6), rng:NextNumber(-0.8, 0.8))
					if kind == "P" then
						showAmount(at, a, { Key = "P" .. tag, Color = COLOR_PVP, Scale = 1.15 * scaleMult, Pop = pop or crit })
					elseif kind == "G" then
						showAmount(at, a, { Key = "G" .. tag, Prefix = "+", Color = COLOR_GOLD, Scale = 0.8, Pop = pop })
						featherPop(p)
					elseif crit then
						showAmount(at, a, { Key = "M" .. tag, Suffix = "!", Color = COLOR_CRIT, Scale = 1.45 * scaleMult, Pop = true, Crit = true })
					else
						showAmount(at, a, { Key = "M" .. tag, Color = WHITE, Scale = scaleMult, Pop = pop })
					end
				elseif kind == "G" and nearCamera(p) then
					featherPop(p) -- other players' goose hits: the cosmetic feather pop only, no number
				end
			end
		end
	end
	if #flashAt > 0 then
		local ok, err = pcall(flashMonstersAt, flashAt)
		if not ok then warnThrottled("hit flash failed: " .. tostring(err)) end
		local mult = fromRelease == true and MOTION.RECOIL_RELEASE or (type(feel) == "table" and feel.Recoil) or 1 -- G3
		local okRecoil, errRecoil = pcall(recoilMonstersAt, flashAt, mult)
		if not okRecoil then warnThrottled("hit recoil failed: " .. tostring(errRecoil)) end
	end
	if sparks > 0 and type(feel) == "table" then
		-- A14-4: a tiny hit-stop of my attack motion and a short camera kick (a running bigger shake wins)
		if feel.Stop then
			local okStop, errStop = pcall(Feel.hitStop, anyCrit)
			if not okStop then warnThrottled("hit-stop failed: " .. tostring(errStop)) end
		end
		if feel.Kick or anyCrit then
			Fx.Shake(MOTION.KICK + (anyCrit and MOTION.KICK_CRIT or 0), MOTION.KICK_TIME)
		end
	end
end

local function validTargets(list)
	local out = {}
	if type(list) ~= "table" then return out end
	for _, v in list do
		local p = asVec(v)
		if p then
			table.insert(out, p)
			if #out >= 8 then break end
		end
	end
	return out
end

----------------------------------------------------------------- kind handlers
local handlers = {}

-- 손맛 ① (GPT game_feel_r1 TOP 1, 최종 검수 10/16; measured 10/16: my swing waited for the server's Swing Fx): my own
-- press starts my body's basic attack at once when the swing is ready (the class interval since my last own swing;
-- inside it the server's 0.20 s reservation does the next one, no early body move). The Swing Fx of that press then
-- plays no second swing: the next own Manual Swing Fx within Window s is its pair. A23-196: only my body, weapon and
-- the whoosh - no target flash, number or hit sound before the server confirms (those stay on the Fx's Hits).
-- PhoneTest 10/16 (a loaded PC, replies 0.48-0.71 s): a time window of 0.6 s let late replies swing a second time ->
-- the presses queue up (Pending, oldest first) and each own Manual Swing Fx takes the oldest; a press older than
-- MaxAge s (its swing refused / lost) is dropped, so it never swallows a later swing
Feel.Predict = { MaxAge = 1.5, Pending = {}, LastSwing = -math.huge, Gap = 0.02 }

-- (pure on P) takes the oldest press still waiting for its Fx; drops the ones older than MaxAge -> true when one was there
function Feel.takePending(P, now)
	while P.Pending[1] and now - P.Pending[1] > P.MaxAge do table.remove(P.Pending, 1) end
	if P.Pending[1] then
		return table.remove(P.Pending, 1) -- 손맛 G2: the press's time (truthy)
	end
	return false
end

-- 손맛 G2 (pure): a paired swing's times counted from the press `ago` s back - the launch (bow / staff) and the hit show
-- that much sooner, never before now; a melee hit (no launch) the same; the projectile keeps its whole flight
function Feel.shiftTimes(launch, showAt, ago, ranged)
	ago = math.max(0, tonumber(ago) or 0)
	local cut = ranged and math.min(ago, launch) or math.min(ago, showAt)
	return math.max(0, launch - cut), math.max(0, showAt - cut)
end

-- Studio test aid (손맛 측정, attack_feel): which path started my swing and when ("P" = my press, "S" = the server's
-- Fx, "pair" = the Fx of a press that already swings), as the local attribute HHDbgSwing; nothing outside Studio
function Feel.dbgSwing(tag)
	if not RunService:IsStudio() or not LocalPlayer then return end
	pcall(LocalPlayer.SetAttribute, LocalPlayer, "HHDbgSwing", string.format("%s %.4f", tag, os.clock()))
end

-- 세세한 게임성 #1 (detail_audit_2026-10-17: a press just before the swing was ready did nothing): seconds until my next
-- press would swing (the same interval PredictSwing keeps); 0 = now
function Fx.SwingReadyIn()
	local me = LocalPlayer
	local classId = me and me:GetAttribute("Class")
	if type(classId) ~= "string" or not Config.Classes[classId] then return 0 end
	local prof = Config.AttackProfile(classId, me:GetAttribute("WeaponTier"), me:GetAttribute("Faction"))
	local P = Feel.Predict
	return math.max(0, asNum(prof.SwingInterval, 1) - P.Gap - (os.clock() - P.LastSwing))
end

function Fx.PredictSwing()
	local me = LocalPlayer
	local char = me and me.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	local classId = me:GetAttribute("Class")
	if type(classId) ~= "string" or not Config.Classes[classId] then return false end
	local faction = me:GetAttribute("Faction")
	local prof = Config.AttackProfile(classId, me:GetAttribute("WeaponTier"), faction)
	local P = Feel.Predict
	local now = os.clock()
	if now - P.LastSwing < asNum(prof.SwingInterval, 1) - P.Gap then return false end
	local data = { UserId = me.UserId, Character = char, Class = classId, Faction = faction, Style = prof.Style,
		Manual = true }
	-- 손맛 G1: MY class's swing sound now (Audio.PressSwing), the old sword file only without Audio
	local audio = C and C.Audio
	local okA, played = false, false
	if type(audio) == "table" and type(audio.PressSwing) == "function" then okA, played = pcall(audio.PressSwing, data) end
	if not (okA and played) then Fx.PlaySound("Swing") end
	animateOwnAttack(data, "Swing")
	table.insert(P.Pending, now)
	if #P.Pending > 4 then table.remove(P.Pending, 1) end
	P.LastSwing = now
	Feel.dbgSwing("P")
	return true
end

-- A14-4: projectiles / hits wait for the clip's key frame (CAST_DELAY thrust, SHOT_DELAY release, SLASH_CONTACT)
handlers.Swing = function(data)
	local ctx = Feel.attackContext(data)
	if not ctx then return end
	local own = isOwn(data)
	local pressAgo = nil -- 손맛 G2: s since my press of this swing (a paired Fx), else nil
	if own then
		Fx.LastFightAt = os.clock() -- B15: Panels keeps story pages back while I fight (manual or auto)
		local P = Feel.Predict
		local pressedAt = data.Manual == true and Feel.takePending(P, os.clock()) or nil
		if pressedAt then
			-- my press already plays this swing (Fx.PredictSwing): no restart; its hits count from the press (G2)
			pressAgo = os.clock() - pressedAt
			Feel.dbgSwing("pair")
		else
			-- 손맛 G1: Audio plays this swing's class sound (OnFx); the old sword file only without Audio
			local audio = C and C.Audio
			if not (type(audio) == "table" and type(audio.OnFx) == "function") then Fx.PlaySound("Swing") end
			animateOwnAttack(data, "Swing")
			P.LastSwing = os.clock()
			Feel.dbgSwing("S")
		end
	end
	local pos = asVec(data.Pos)
	local from = asVec(data.From) or pos
	if not pos then return end
	if not nearCamera(pos) and not (from and nearCamera(from)) then return end
	if not own then
		local okAnim, errAnim = pcall(Feel.animateOther, data, "Swing")
		if not okAnim then warnThrottled("swing animation failed: " .. tostring(errAnim)) end
	end
	local classId = asStr(data.Class, "Warrior")
	local color = factionColor(data.Faction)
	local targets = validTargets(data.Targets)
	local hits = data.Hits
	if data.Meme ~= nil then pcall(Feel.memeHits, data.Meme, hits) end -- A23-186: Bonk / Squeak + Feathers
	-- my manual hits: hit-stop / camera kick; auto-combat hits stay quiet (A23-1: no shake, no hit-stop)
	local style = asStr(data.Style, "")
	local punch = style == "Punch" or style == "PetHeadbutt" -- A23-34 / A23-39 (the pet itself comes with PET-3)
	-- 손맛 G3 (docs/review/attack_feel_values_2026-10-17.md): my manual arrow / orb hits push the monster harder
	-- (MOTION.RECOIL_RANGED x its recoil; my own body has no hit-stop after a release - nothing in the hand to stop)
	local ranged = (classId == "Mage" or classId == "Archer") and not punch
	local feel = data.Manual == true and { Stop = classId == "Warrior" or punch, Kick = true,
		Recoil = ranged and MOTION.RECOIL_RANGED or nil } or nil
	local launch = math.clamp(asNum(data.LaunchDelay, classId == "Mage" and MOTION.CAST_DELAY or MOTION.SHOT_DELAY), 0, 1)
	local flight = math.clamp(asNum(data.FlightTime, classId == "Mage" and 0.2 or 0.15), 0, 1)

	-- A14-4: when the hits will show, so the monsters' HurtSeq pain reaction waits for it
	local showAt = math.clamp(asNum(data.ContactDelay,
		classId == "Warrior" and MOTION.SLASH_CONTACT or launch + flight), 0, 1)
	-- 손맛 G2: my pressed swing (paired above) shows its hits on the body's own clock - from the press
	if own and pressAgo then
		launch, showAt = Feel.shiftTimes(launch, showAt, pressAgo, (classId == "Mage" or classId == "Archer") and not punch)
	end
	local okExpect, errExpect = pcall(Feel.expectHits, hits, showAt)
	if not okExpect then warnThrottled("hit sync failed: " .. tostring(errExpect)) end

	if punch then
		-- PET-3: the tamer's pet runs to the targets and bumps them at the contact time (no pet drawn: the punch)
		if style == "PetHeadbutt" then MOTION.PetMove("Attack", data, #targets > 0 and targets or { pos }, showAt) end
		Feel.after(ctx, showAt, function()
			if own and targets[1] then ring(targets[1], MOTION.HIT_RING.Radius, color, MOTION.HIT_RING) end
			showHits(hits, own, false, feel)
		end)
	elseif classId == "Mage" then
		Feel.launchWeapon(ctx, launch, function()
			local origin = Feel.muzzle(ctx, from)
			local target = targets[1]
			if target and origin and (target - origin).Magnitude > 0.05 then orb(origin, target, flight, color) end
			Feel.after(ctx, math.max(0, showAt - launch), function()
				if target and own then
					ring(target, MOTION.HIT_RING.Radius, color, MOTION.HIT_RING)
					Feel.magicBurst(target + Vector3.new(0, 1, 0), false)
				end
				showHits(hits, own, false, feel)
			end)
		end)
	elseif classId == "Archer" then
		Feel.launchArrow(ctx, launch, function()
			local origin = Feel.muzzle(ctx, from)
			if origin then
				for _, target in targets do
					if (target - origin).Magnitude > 0.05 then
						arrowBolt(origin, target, flight, color, 0, own and color or nil)
					end
				end
			end
			Feel.after(ctx, math.max(0, showAt - launch), function()
				showHits(hits, own, false, feel)
			end)
		end)
	else
		if own then
			Feel.after(ctx, MOTION.SLASH_VFX_AT, function()
				Feel.slash(color, false)
			end)
		end
		Feel.after(ctx, showAt, function()
			showHits(hits, own, false, feel)
		end)
	end
end

handlers.Release = function(data)
	local ctx = Feel.attackContext(data)
	if not ctx then return end
	local own = isOwn(data)
	if own then
		Fx.LastFightAt = os.clock() -- B15
		animateOwnAttack(data, "Release")
	else
		local okAnim, errAnim = pcall(Feel.animateOther, data, "Release")
		if not okAnim then warnThrottled("release animation failed: " .. tostring(errAnim)) end
	end
	local pos = asVec(data.Pos)
	if not pos then
		if own then
			Fx.PlaySound("Release")
			if data.Auto ~= true then Fx.Shake(SHAKE_OWN, 0.35) end
		end
		return
	end
	local classId = asStr(data.Class, "Warrior")
	local radius = math.clamp(asNum(data.Radius, 8), 1, 200)
	local color = factionColor(data.Faction)
	local visible = nearCamera(pos)
	local impactDelay = math.clamp(asNum(data.ContactDelay, MOTION.RELEASE_CONTACT[classId] or MOTION.SMASH_AT), 0, 1)
	-- A23-116: the class x side's own Q art (SkillFx.luau); the old class art below only when it drew nothing
	local sfx = C and C.SkillFx
	local drawn = false
	if visible and data.Style == nil and type(sfx) == "table" and type(sfx.Q) == "function" then
		local okQ, res = pcall(sfx.Q, data, pos, radius, impactDelay, own, {
			Muzzle = function() return Feel.muzzle(ctx, nil) end,
			After = function(seconds, fn) Feel.after(ctx, seconds, fn) end,
		})
		drawn = okQ and res == true
		if not okQ then warnThrottled("skill art failed: " .. tostring(res)) end
	end
	if data.Style == "PetDash" then
		-- A23-39 / PET-3: the pet dashes to the impact point (no pet drawn: only the impact below shows)
		if visible then MOTION.PetMove("Dash", data, pos, impactDelay) end
	elseif drawn and classId == "Archer" then
		-- SkillFx drew the shot; the bow still lets go at the launch (the string snaps back)
		Feel.launchArrow(ctx, math.clamp(asNum(data.LaunchDelay, MOTION.RELEASE_LAUNCH.Archer), 0, impactDelay), function() end)
	elseif drawn then
		-- SkillFx drew it
	elseif classId == "Mage" then
		if visible then meteor(pos, radius, color, impactDelay, ctx) end
	elseif classId == "Archer" then
		local launch = math.clamp(asNum(data.LaunchDelay, MOTION.RELEASE_LAUNCH.Archer), 0, impactDelay)
		if visible then
			Feel.launchArrow(ctx, launch, function()
				local origin = Feel.muzzle(ctx, nil)
				if origin then arrowBolt(origin, pos + Vector3.new(0, 30, 0), 0.2, color, 0, own and color or nil) end
				arrowRain(pos, radius, color, impactDelay, ctx)
			end)
		end
	else
		-- A14-4: the shockwave lands with the smash of the release clip; my big slash arc on the downswing
		if own then
			Feel.after(ctx, MOTION.SMASH_VFX_AT, function()
				Feel.slash(color, true)
			end)
		end
	end

	if visible and impactDelay > 0 then
		local okExpect, errExpect = pcall(Feel.expectHits, data.Hits, impactDelay)
		if not okExpect then warnThrottled("hit sync failed: " .. tostring(errExpect)) end
	end

	local function impact()
		if visible then
			-- shockwave ring always sized exactly to Radius (A14-4: GPT ring art once its id exists)
			if not drawn then ring(pos, radius, color, { Grow = 0.25, Fade = 0.45, Transparency = 0.3, Thickness = 0.3, StartDiameter = 2, Art = true }) end
			local gpos = Vector3.new(pos.X, groundY(pos) + 0.5, pos.Z)
			if drawn then
				-- SkillFx drew the impact
			elseif classId == "Mage" then
				Feel.magicBurst(gpos + Vector3.new(0, 1, 0), true)
				burst(gpos, ColorSequence.new(COLOR_FIRE, color), 40, {
					Size = 1.4, SpeedMin = 14, SpeedMax = 26, LifeMin = 0.4, LifeMax = 0.8, LightEmission = 1,
					Spread = Vector2.new(90, 90), Acceleration = Vector3.new(0, -6, 0), Drag = 3,
				})
			elseif classId == "Archer" then
				burst(gpos, color, 20, {
					Size = 0.6, SpeedMin = 8, SpeedMax = 16, LifeMin = 0.3, LifeMax = 0.6,
					Spread = Vector2.new(90, 90), Acceleration = Vector3.new(0, -10, 0),
				})
			else
				burst(gpos, COLOR_DUST, 45, {
					Size = 1.6, EndSize = 2.4, SpeedMin = 20, SpeedMax = 34, LifeMin = 0.5, LifeMax = 0.9,
					LightEmission = 0, StartTransparency = 0.3, Spread = Vector2.new(90, 90),
					Acceleration = Vector3.new(0, -4, 0), Drag = 3,
				})
			end
			showHits(data.Hits, own, true, data.Auto ~= true and { Stop = classId == "Warrior", Kick = true } or nil)
			local total = asNum(data.Total, 0)
			local top = pos + Vector3.new(0, 6, 0)
			if total > 0 and MOTION.DamageNumbersOn() then
				-- A9-2: my Release numbers pop (PopScale -> 1 in PopTime)
				Fx.ShowNumber(top, Util.FormatNumber(total), own and COLOR_GOLD or WHITE, HUGE_SCALE, { Pop = own })
			end
		end
		if own then
			if data.Auto ~= true then Fx.Shake(SHAKE_OWN, 0.35) end -- auto skills: no camera shake
			Fx.PlaySound("Release")
		elseif data.Auto ~= true then
			local root = getOwnRoot()
			if root and (root.Position - pos).Magnitude <= SHAKE_NEAR_DIST then
				Fx.Shake(SHAKE_NEAR, 0.3)
				Fx.PlaySound("Release")
			end
		end
	end

	if impactDelay > 0 then
		Feel.after(ctx, impactDelay, impact)
	else
		impact()
	end
end

-- A23-108 ⑤: a Z / X skill (Fx "Skill" { UserId, Character, Class, Faction, Slot, ... }; its art is drawn elsewhere):
-- the class x side's own Z / X move on that character (MOTION.SIDE_CLIPS; none = no body move, as before)
handlers.Skill = function(data)
	local slot = asStr(data.Slot, "")
	if slot ~= "Z" and slot ~= "X" then return end
	local ctx = Feel.attackContext(data)
	if not ctx then return end
	local classId = asStr(data.Class, "Warrior")
	if not isOwn(data) and not (ctx.Char.PrimaryPart and Feel.near(ctx.Char.PrimaryPart.Position, MOTION.PROC_DIST)) then return end
	local ok, err = pcall(Feel.playAttack, ctx.Char, classId, slot, Feel.attackTime(classId, "Release", nil), data)
	if not ok then warnThrottled("skill move failed: " .. tostring(err)) end
	-- A23-116: the class x side's own Z / X art (SkillFx.luau)
	local sfx = C and C.SkillFx
	local at = asVec(data.Center) or asVec(data.From)
	local draw = type(sfx) == "table" and type(sfx[slot]) == "function" and sfx[slot] or nil
	if draw and at and nearCamera(at) then
		local okZ, errZ = pcall(draw, data, isOwn(data), {
			Muzzle = function() return Feel.muzzle(ctx, nil) end,
			After = function(seconds, fn) Feel.after(ctx, seconds, fn) end,
		})
		if not okZ then warnThrottled("skill art failed: " .. tostring(errZ)) end
	end
end

-- A23-116: a field's tick (Fx "SkillTick" { UserId, Slot = "X", Center, Radius, Hits, Statuses }): its circle pulses,
-- the pops and the MP signal (SkillFx.Tick)
handlers.SkillTick = function(data)
	local sfx = C and C.SkillFx
	local at = asVec(data.Center)
	if type(sfx) == "table" and type(sfx.Tick) == "function" and at and nearCamera(at) then
		local ok, err = pcall(sfx.Tick, data, isOwn(data))
		if not ok then warnThrottled("skill tick art failed: " .. tostring(err)) end
	end
end

handlers.Hurt = function(data)
	Fx.LastFightAt = os.clock() -- B15: being hit counts as fighting too
	local amount = asNum(data.Amount, 0)
	local char = LocalPlayer and LocalPlayer.Character
	local head = char and char:FindFirstChild("Head")
	local at = nil
	if head and head:IsA("BasePart") then
		at = head.Position + Vector3.new(0, 1.5, 0)
	else
		local p = asVec(data.Pos)
		if p then at = p + Vector3.new(0, 3, 0) end
	end
	if at and amount > 0 then
		local jitter = Vector3.new(rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(-0.6, 0.6))
		showAmount(at + jitter, Util.RoundDamage(amount), { Key = "H", Prefix = "-", Color = COLOR_HURT, Scale = 1.1 })
	end
	do -- red edges by the hit's size (MOTION.EDGE): small hits barely show
		local h = char and char:FindFirstChildOfClass("Humanoid")
		local E = MOTION.EDGE
		local frac = (h and h.MaxHealth > 0) and amount / h.MaxHealth or 1
		flashEdges(COLOR_HURT, math.clamp((frac - E.Small) / math.max(E.Big - E.Small, 0.01), 0, 1))
	end
	-- A14-4: camera kick only for a hard hit (small hits keep the number + edge flash; auto farming stays calm)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.MaxHealth > 0 and amount >= hum.MaxHealth * MOTION.PAIN_KICK_FRAC then
		Fx.Shake(MOTION.PAIN_KICK, MOTION.PAIN_KICK_TIME)
	end
	-- A14-4: my pain sticker + flinch also without a Pain Fx (PAIN_GAP_OWN keeps one when both arrive)
	if LocalPlayer then
		local ok, err = pcall(Feel.playerPain, LocalPlayer.UserId, false)
		if not ok then warnThrottled("pain failed: " .. tostring(err)) end
	end
end

-- A14-4: { UserId, Big? } from the server whenever a player takes damage -> sticker beside the head + hurt flinch
handlers.Pain = function(data)
	local uid = asNum(data.UserId, nil)
	if not uid then return end
	Feel.playerPain(math.floor(uid), data.Big == true)
end

-- a kill's gold / XP numbers (and the drops below) show after the killing hit itself (Feel.afterHit): never a "+6 G"
-- before the orb / arrow has landed
handlers.Reward = function(data)
	Feel.afterHit(asVec(type(data) == "table" and data.Pos or nil), function() Feel.rewardNow(data) end)
end

function Feel.rewardNow(data)
	bumpCombo()
	-- 세세한 게임성 #13 (detail_audit_2026-10-17: the coin on every kill, gold or not, dulled real gold): the coin only
	-- with gold (Audio's kill pop plays for every kill)
	if asNum(data.Gold, 0) > 0 then Fx.PlaySound("Coin") end
	local xp = asNum(data.XP, 0)
	-- A23-221 ⑦: the first XP of the first minutes' 2x makes the '2x XP · N min' chip shine once (HUD.PulseBoost)
	local hud = C and C.HUD
	if xp > 0 and type(hud) == "table" and type(hud.PulseBoost) == "function" then pcall(hud.PulseBoost) end
	local pos = asVec(data.Pos)
	if not pos or not nearCamera(pos) then return end
	local gold = asNum(data.Gold, 0)
	-- A23-221 ⑦: the server's XP multiplier (XPMult, dev2: the first minutes' 2x / a pass) shows on the number: '+12 XP ×2'
	local mult = math.floor(asNum(data.XPMult, 1) + 0.5)
	local golden = data.Golden == true
	local rx, rz = rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.5, 0.5)
	if gold > 0 then
		showAmount(pos + Vector3.new(rx, 3.2, rz), gold, { Key = "RG", Prefix = "+", Suffix = " G", Color = COLOR_GOLD, Scale = golden and 1.6 or 1 })
	end
	if xp > 0 then
		showAmount(pos + Vector3.new(rx, 2.0, rz), xp, { Key = mult >= 2 and "RX" .. mult or "RX", Prefix = "+",
			Suffix = mult >= 2 and (" XP ×" .. mult) or " XP", Color = COLOR_XP, Scale = golden and 1.2 or 0.85 })
	end
	if golden then
		burst(pos + Vector3.new(0, 1.5, 0), COLOR_GOLD, 40, {
			Size = 0.9, SpeedMin = 10, SpeedMax = 22, LifeMin = 0.6, LifeMax = 1.2, LightEmission = 1,
		})
		ring(pos, 6, COLOR_GOLD, { Grow = 0.2, Fade = 0.4, Transparency = 0.35 })
	end
end

-- A23-12: { Pos, Items = { { Item | Potion | Weapon, Name, N } } } = my own drops (already saved on the server).
-- Uses the existing number popups and bursts only (no new art): "+슬라임 젤리" rises above the kill spot.
handlers.Loot = function(data)
	Feel.afterHit(asVec(type(data) == "table" and data.Pos or nil), function() Feel.lootNow(data) end)
end

function Feel.lootNow(data)
	local pos = asVec(data.Pos)
	local items = type(data.Items) == "table" and data.Items or {}
	local rare = false
	local lootText = (Config.Loot and type(Config.Loot.Text) == "table") and Config.Loot.Text or {}
	local line = 0
	-- the guaranteed first scroll: the server already shows the one-time Text.FirstScroll guide (6 s) -> no 2nd toast
	local firstId = data.First == true and Config.Loot and type(Config.Loot.FirstScroll) == "table"
		and Config.Loot.FirstScroll.Item or nil
	for i, it in items do
		if type(it) == "table" and type(it.Name) == "string" and i <= 6 then
			local n = math.max(1, math.floor(asNum(it.N, 1)))
			local def = type(it.Item) == "string" and Config.Loot and Config.Loot.Items[it.Item] or nil
			local weapon = it.Weapon ~= nil
			rare = rare or weapon
			local tier = weapon and math.floor(asNum(it.Weapon, 0)) or 0
			local color = (weapon and Config.WeaponGrade and Config.WeaponGrade(tier).Color) or (def and def.Color) or WHITE
			local okT, text = pcall(string.format, n > 1 and (lootText.GotN or "+%s ×%d") or (lootText.Got or "+%s"), it.Name, n)
			if not okT then text = "+" .. it.Name end
			if weapon and Config.WeaponStars then text = Config.WeaponStars(tier) .. " " .. text end -- design §1 B2
			if pos and nearCamera(pos) and line < LOOT_UI.MaxLines then
				-- B14: 1.6-2 s, wider labels stacked in screen space (no overlap with the +G / +XP numbers below);
				-- items / potions show their art left of the line (weapons keep the stars: their art is redrawn later)
				local icon = (def and it.Item) or (type(it.Potion) == "string" and "IconPotion" .. it.Potion) or nil
				pcall(spawnNumber, pos + Vector3.new(0, 4.6, 0), text, color, weapon and LOOT_UI.WeaponScale or LOOT_UI.Scale,
					weapon, nil, { Life = LOOT_UI.Life, Wide = LOOT_UI.Wide, Stack = line * LOOT_UI.Step, Icon = icon })
				line += 1
			end
			-- A23-191 (user 10/14): no scroll-drop toast / hint (the bag dot shows it)
		end
	end
	if pos and nearCamera(pos) and #items > 0 then
		burst(pos + Vector3.new(0, 1.2, 0), rare and COLOR_GOLD or WHITE, rare and 50 or 10, {
			Size = rare and 0.9 or 0.45, SpeedMin = 6, SpeedMax = rare and 22 or 12, LifeMin = 0.4, LifeMax = 0.9, LightEmission = 1,
		})
		if rare then ring(pos, 8, COLOR_GOLD, { Grow = 0.25, Fade = 0.5, Transparency = 0.3 }) end
	end
	if rare then Fx.PlaySound("Coin") end
	-- A23-221 ③: the first notable thing of this drop (a weapon, a scroll, a ring / armour) rises over my head
	for _, it in items do
		local icon = Feel.holdIcon(it)
		if icon then
			pcall(Feel.holdUp, icon)
			break
		end
	end
end

-- A23-221 ③: the held-up thing (Feel.holdUp): Time s over the head (Lift studs up, Size studs wide, round glow at
-- GlowAlpha), pop In / fade Out, Sparks round sparkles, the cheer emote only Calm s after the last hit, Gap s between two
MOTION.HOLD = { Time = 1.0, Lift = 2.6, Size = 2.2, GlowAlpha = 0.55, In = 0.18, Out = 0.3, Sparks = 22, Calm = 1.5, Gap = 0.8,
	Emote = "cheer", Kinds = { Enhance = true, Transfer = true, Gear = true } }

-- A23-221 ③ (pure-ish): a loot entry's art key worth holding up (a weapon: its class / side icon; an Enhance / Transfer
-- scroll, a ring, armour: the item), else nil (jelly, potions, materials: the number line is enough)
function Feel.holdIcon(it)
	if type(it) ~= "table" then return nil end
	if it.Weapon ~= nil then
		local fn = Config.WeaponArtKey
		local tier = math.floor(asNum(it.Weapon, 0))
		return type(fn) == "function" and fn(tier, LocalPlayer and LocalPlayer:GetAttribute("Class"),
			LocalPlayer and LocalPlayer:GetAttribute("Faction")) or nil
	end
	local def = type(it.Item) == "string" and Config.Loot and Config.Loot.Items[it.Item] or nil
	if type(def) == "table" and MOTION.HOLD.Kinds[def.Kind] then return it.Item end
	return nil
end

-- A23-221 ③ (body reaction, no banner / text strip): the thing rises over my head for HOLD.Time s in a round soft glow
-- with round sparkles; out of a fight (HOLD.Calm s since the last hit) my character cheers (the free Roblox emote: arms
-- up; a move ends it, nothing is blocked). Called only after the server saved the thing (Loot / the first weapon)
function Feel.holdUp(icon)
	local H = MOTION.HOLD
	local char = LocalPlayer and LocalPlayer.Character
	local head = char and char:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then return false end
	local now = os.clock()
	if Feel.HoldAt and now - Feel.HoldAt < H.Gap then return false end
	Feel.HoldAt = now
	local gui = Instance.new("BillboardGui")
	gui.Name = "FxHoldUp"
	gui.Adornee = head
	gui.Size = UDim2.fromScale(H.Size, H.Size)
	gui.StudsOffsetWorldSpace = Vector3.new(0, H.Lift, 0)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(1, 1)
	glow.BackgroundColor3 = COLOR_GOLD
	glow.BackgroundTransparency = H.GlowAlpha
	glow.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = glow
	glow.Parent = gui
	local ui = C and C.UIKit
	if type(icon) == "string" and type(ui) == "table" and type(ui.ItemIcon) == "function" then
		pcall(ui.ItemIcon, icon, { Name = "Thing", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.8), BackgroundTransparency = 1, Parent = gui })
	end
	local sc = Instance.new("UIScale")
	sc.Parent = glow
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	gui.Parent = pg or head
	local still = not MOTION.ShakeAllowed() -- (Settings Shake off / reduced motion: no pop)
	if not still then
		sc.Scale = 0.3
		tween(sc, H.In, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	end
	burst(head.Position + Vector3.new(0, H.Lift, 0), COLOR_GOLD, H.Sparks, { Size = 0.5, SpeedMin = 3, SpeedMax = 8,
		LifeMin = 0.4, LifeMax = 0.9, Acceleration = Vector3.new(0, 4, 0), LightEmission = 1 })
	if now - asNum(Fx.LastFightAt, -math.huge) >= H.Calm then
		local animate = char:FindFirstChild("Animate")
		local play = animate and animate:FindFirstChild("PlayEmote")
		if play and play:IsA("BindableFunction") then pcall(function() play:Invoke(H.Emote) end) end
	end
	task.delay(H.Time, function()
		if not gui.Parent then return end
		for _, d in gui:GetDescendants() do
			if d:IsA("ImageLabel") then tween(d, H.Out, { ImageTransparency = 1 }) end
		end
		tween(glow, H.Out, { BackgroundTransparency = 1 })
		Debris:AddItem(gui, H.Out + 0.1)
	end)
	return true
end

-- A23-221 ③: the first weapon (HUD L.FirstWeapon) and anything else that wants the same moment
function Fx.HoldUp(icon)
	return Feel.holdUp(icon)
end

-- A23-12: my scroll result { Success, Before, After, Move? } -> a gold burst on success, a small grey puff on failure
handlers.Enhance = function(data)
	-- B14: the open item list shows this result and ends its "결과 확인 중…"
	local panels = C and C.Panels
	if type(panels) == "table" and type(panels.OnEnhanceResult) == "function" then
		local ok, err = pcall(panels.OnEnhanceResult, data)
		if not ok then warnThrottled("enhance result failed: " .. tostring(err)) end
	end
	local pos = LocalPlayer and getPlayerRootPos(LocalPlayer.UserId)
	if not pos then return end
	if data.Success == true then
		burst(pos + Vector3.new(0, 2, 0), COLOR_GOLD, 45, {
			Size = 0.8, SpeedMin = 8, SpeedMax = 20, LifeMin = 0.5, LifeMax = 1.1, LightEmission = 1,
		})
		ring(pos, 7, COLOR_GOLD, { Grow = 0.25, Fade = 0.45, Transparency = 0.3 })
		-- 세세한 #14: no coin on a success - the result's sound is Audio's ScrollSuccess / ScrollFail (as in the bag)
	else
		burst(pos + Vector3.new(0, 2, 0), Color3.fromRGB(150, 150, 160), 14, {
			Size = 0.5, SpeedMin = 3, SpeedMax = 8, LifeMin = 0.4, LifeMax = 0.8,
		})
	end
end

-- a payload position, or the player's live root when the sender had none (it then sends Vector3.zero)
local function eventPos(data)
	local p = asVec(data.Pos)
	if p and p.Magnitude > 0.01 then return p end
	return getPlayerRootPos(data.UserId) or p
end

-- A23-221 ③ (several level-ups = one moment after the fight): my own level-ups wait while I fight (Fx.LastFightAt) and
-- play once Calm s after the last hit (at least Min s after the first, at most Max s): one ring + stars, the HUD's badge
-- ticks From -> To (HUD.LevelHold / LevelCount) and the power counts up once
MOTION.LVQ = { Min = 0.35, Calm = 1.2, Max = 12, Poll = 0.2 }
function Feel.levelQueue(data, level)
	local q = Feel.LvQ
	if q then
		q.To = math.max(q.To, level)
		q.PowerTo = asNum(data.PowerTo, q.PowerTo)
		return q
	end
	q = { From = asNum(data.From, level - 1), To = level, PowerFrom = asNum(data.PowerFrom, nil), PowerTo = asNum(data.PowerTo, nil),
		At = os.clock() }
	Feel.LvQ = q
	local hud = C and C.HUD
	if type(hud) == "table" and type(hud.LevelHold) == "function" then pcall(hud.LevelHold, q.From) end
	task.spawn(function()
		local W = MOTION.LVQ
		while true do
			task.wait(W.Poll)
			local now = os.clock()
			if now - q.At >= W.Min and (now - asNum(Fx.LastFightAt, -math.huge) >= W.Calm or now - q.At >= W.Max) then break end
		end
		if Feel.LvQ == q then Feel.LvQ = nil end
		local ok, err = pcall(Feel.levelMoment, q)
		if not ok then warnThrottled("level moment failed: " .. tostring(err)) end
	end)
	return q
end

function Feel.levelMoment(q)
	local pos = LocalPlayer and getPlayerRootPos(LocalPlayer.UserId)
	if pos and nearCamera(pos) then
		-- 최종 검수 10/15 (feedback_audit #2: one moment): a gold ring of light at my feet, then stars round my body
		ring(pos, 6, COLOR_GOLD, { Grow = 0.3, Fade = 0.6, Transparency = 0.2 })
		task.delay(0.15, function()
			burst(pos + Vector3.new(0, 2, 0), COLOR_GOLD, 30, { Size = 0.6, SpeedMin = 4, SpeedMax = 9, LifeMin = 0.5,
				LifeMax = 0.9, Acceleration = Vector3.new(0, 6, 0), LightEmission = 1 })
		end)
	end
	announceLevelUp(q.To)
	local hud = C and C.HUD
	if type(hud) ~= "table" then return end
	if type(hud.LevelUpMoment) == "function" then
		pcall(hud.LevelUpMoment, { Level = q.To, From = q.From, PowerFrom = q.PowerFrom, PowerTo = q.PowerTo })
	end
	if type(hud.LevelCount) == "function" then pcall(hud.LevelCount, q.From, q.To) end
end

handlers.LevelUp = function(data)
	local own = isOwn(data)
	local level = asNum(data.Level, nil)
	if own and level then
		Feel.levelQueue(data, level)
		return
	end
	-- someone else's level-up: the old pillar
	local pos = eventPos(data)
	if own or not (pos and nearCamera(pos)) then return end
	pillar(pos, 40, 4, COLOR_PILLAR, 1.0)
	burst(pos, COLOR_PILLAR, 25, { Size = 0.7, SpeedMin = 6, SpeedMax = 14, Acceleration = Vector3.new(0, 8, 0), LightEmission = 1 })
end

handlers.Plunder = function(data)
	local from, to = asVec(data.From), asVec(data.To)
	if not from or not to then return end
	if not nearCamera(from) and not nearCamera(to) then return end
	local lift = Vector3.new(0, 1.5, 0)
	for i = 1, 8 do
		later((i - 1) * 0.05, function()
			local mid = (from + to) / 2 + Vector3.new(rng:NextNumber(-2, 2), 5 + rng:NextNumber(0, 3), rng:NextNumber(-2, 2))
			local b = makePart({
				Name = "FxCoin",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.6, 0.6, 0.6),
				CFrame = CFrame.new(from + lift),
				Color = COLOR_GOLD,
			})
			tween(b, 0.3, { CFrame = CFrame.new(mid) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			tween(b, 0.3, { CFrame = CFrame.new(to + lift) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.3)
			Debris:AddItem(b, 0.65)
		end)
	end
	local amount = asNum(data.Amount, 0)
	if amount > 0 then
		later(0.65, function()
			Fx.ShowNumber(to + Vector3.new(0, 3, 0), Util.FormatNumber(amount) .. " G", COLOR_GOLD, 1)
		end)
	end
end

-- { Amount, Courier? }: the only bank toast (CR-L23: the server sends no Banked / HaloCourier notify any more);
-- Courier = the Halo courier's periodic deposit
handlers.Bank = function(data)
	local amount = asNum(data.Amount, 0)
	if amount <= 0 then return end
	local gold = Util.FormatNumber(amount)
	local text
	if data.Courier == true then
		text = textOr("HaloCourier", "An angel courier put %s gold in your Vault.", gold)
	else
		text = string.format(TXT_BANK, gold)
	end
	Fx.PlaySound("Coin") -- A23-191: no toast (the gold number moves)
end

handlers.Upgrade = function(_data)
	Fx.PlaySound("Coin")
	local root = getOwnRoot()
	if not root then return end
	local pos = root.Position
	burst(pos, ColorSequence.new(COLOR_GOLD, WHITE), 40, {
		Size = 0.7, SpeedMin = 6, SpeedMax = 14, LifeMin = 0.6, LifeMax = 1.2, LightEmission = 1,
		Acceleration = Vector3.new(0, 6, 0),
	})
	ring(pos, 5, COLOR_GOLD, { Grow = 0.2, Fade = 0.4, Transparency = 0.35 })
end

handlers.Rebirth = function(data)
	local own = isOwn(data)
	local pos = eventPos(data)
	local mark = asStr(data.Mark, "None")
	if pos and nearCamera(pos) then
		local color = COLOR_PILLAR
		if mark == "Fall" then
			color = Color3.fromRGB(70, 25, 85)
		elseif mark == "Redeem" then
			color = WHITE
		end
		pillar(pos, 80, 8, color, 1.6, 0.2)
		ring(pos, 14, color, { Grow = 0.3, Fade = 0.6, Transparency = 0.3, Thickness = 0.3 })
		if mark == "Fall" then
			burst(pos, COLOR_SMOKE, 50, {
				Size = 3.5, EndSize = 5, SpeedMin = 3, SpeedMax = 8, LifeMin = 1.2, LifeMax = 2.2, LightEmission = 0,
				StartTransparency = 0.2, Acceleration = Vector3.new(0, 4, 0), Spread = Vector2.new(60, 60), Drag = 1,
			})
		elseif mark == "Redeem" then
			burst(pos, WHITE, 60, {
				Size = 1.2, SpeedMin = 10, SpeedMax = 22, LifeMin = 0.8, LifeMax = 1.6, LightEmission = 1,
				Acceleration = Vector3.new(0, 6, 0),
			})
		else
			burst(pos, COLOR_GOLD, 50, {
				Size = 1, SpeedMin = 10, SpeedMax = 22, LifeMin = 0.8, LifeMax = 1.6, LightEmission = 1,
				Acceleration = Vector3.new(0, 6, 0),
			})
		end
	end
	if own then
		Fx.Shake(SHAKE_NEAR, 0.4)
		Fx.PlaySound("Release")
	end
end

handlers.Stomp = function(data)
	local pos = asVec(data.Pos)
	if not pos then return end
	local radius = math.clamp(asNum(data.Radius, 15), 1, 100)
	if nearCamera(pos) then
		ring(pos, radius, COLOR_STOMP, { Grow = 0.2, Fade = 0.5, Transparency = 0.3, Thickness = 0.3, StartDiameter = 2, Art = true })
		burst(Vector3.new(pos.X, groundY(pos) + 0.5, pos.Z), COLOR_DUST, 35, {
			Size = 1.8, EndSize = 2.6, SpeedMin = 18, SpeedMax = 30, LifeMin = 0.5, LifeMax = 0.9, LightEmission = 0,
			StartTransparency = 0.3, Spread = Vector2.new(90, 90), Acceleration = Vector3.new(0, -4, 0), Drag = 3,
		})
	end
	local root = getOwnRoot()
	if root and Util.FlatDistance(root.Position, pos) <= radius then
		Fx.Shake(SHAKE_OWN, 0.3)
	end
end

handlers.Rare = function(_data)
	Fx.PlaySound("Coin")
	local root = getOwnRoot()
	if root then
		local pos = root.Position
		burst(pos, ColorSequence.new(COLOR_GOLD, WHITE), 80, {
			Size = 1.1, SpeedMin = 12, SpeedMax = 28, LifeMin = 0.8, LifeMax = 1.6, LightEmission = 1,
			Acceleration = Vector3.new(0, 4, 0),
		})
		ring(pos, 10, COLOR_GOLD, { Grow = 0.3, Fade = 0.6, Transparency = 0.3 })
		pillar(pos, 30, 3, COLOR_GOLD, 1.2)
	end
	-- A23-191: no banner (the gold burst says it)
end

handlers.GooseEnd = function(data)
	local pos = asVec(data.Pos)
	if not pos or not nearCamera(pos) then return end
	local winner = asStr(data.Winner, "Tie")
	local color = WHITE
	if winner == "Halo" then
		color = COLOR_GOLD
	elseif winner == "Horns" then
		color = COLOR_HORNS_WIN
	end
	burst(pos, color, 80, {
		Size = 0.7, SpeedMin = 10, SpeedMax = 25, LifeMin = 1, LifeMax = 2, LightEmission = 0.6,
		Acceleration = Vector3.new(0, -6, 0),
	})
	feathers(pos, color, 12)
end

----------------------------------------------------------------- public API
function Fx.Init(registry)
	C = registry
end

function Fx.Play(kind, data)
	if type(kind) ~= "string" then return end
	local handler = handlers[kind]
	if not handler then return end -- unknown kinds are ignored
	if type(data) ~= "table" then data = {} end
	local ok, err = pcall(handler, data)
	if not ok then warnThrottled(kind .. " failed: " .. tostring(err)) end
end

local soundCache = {}
local soundLast = {}

-- BB3 settings, read when used (C.Settings): Sound Effects 0..1 multiplies SOUND_VOLUME; Screen Shake off (or Roblox's
-- Reduced Motion) = no camera shake
function MOTION.Pref(key, default)
	local st = C and C.Settings
	if type(st) ~= "table" or type(st.Get) ~= "function" then return default end
	local ok, v = pcall(st.Get, key)
	if ok and v ~= nil then return v end
	return default
end

-- PET-3: true when the packet's player has a pet drawn on this client (PetFollow); the pet then does the move
function MOTION.PetDrawn(data)
	local pf = C and C.PetFollow
	local uid = type(data) == "table" and tonumber(data.UserId) or nil
	return uid ~= nil and type(pf) == "table" and type(pf.Has) == "function" and pf.Has(math.floor(uid)) == true
end

function MOTION.PetMove(kind, data, targets, contact)
	local pf = C and C.PetFollow
	local uid = type(data) == "table" and tonumber(data.UserId) or nil
	if not uid or type(pf) ~= "table" then return false end
	local fn = kind == "Dash" and pf.Dash or pf.Attack
	if type(fn) ~= "function" then return false end
	local ok, res = pcall(fn, math.floor(uid), targets, contact)
	return ok and res == true
end

-- true while a window covers the screen (bag / items, map, pickers, opening): the red edges never draw over it
function MOTION.EdgeCovered()
	for _, name in { "Panels", "WorldMap", "FactionPicker", "ClassPicker", "Intro" } do
		local m = C and C[name]
		if type(m) == "table" and type(m.IsOpen) == "function" then
			local ok, open = pcall(m.IsOpen)
			if ok and open == true then return true end
		end
	end
	return false
end

-- 세세한 게임성 #6 (detail_audit_2026-10-17: HP went 112 -> 3 unnoticed; a danger signal is allowed): the moment my HP
-- first goes under EDGE.LowHP (the edge throb above starts there), once per LowWarn.Gap s: one low heart sound
-- (Config sound LowHeart, silent until its id exists) and the HP potion slot shines once (QuickSlots.Glow: nothing
-- without a potion). No text. (pure) due when it just went low and the last warning is Gap s old
MOTION.LowWarn = { Gap = 20, Was = false, At = -math.huge }
function MOTION.LowWarnDue(wasLow, low, now, lastAt)
	return low == true and wasLow ~= true and (tonumber(now) or 0) - (tonumber(lastAt) or -math.huge) >= MOTION.LowWarn.Gap
end

function MOTION.LowWarnStep()
	local W, E = MOTION.LowWarn, MOTION.EDGE
	local char = LocalPlayer and LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local low = hum ~= nil and hum.Health > 0 and hum.Health < hum.MaxHealth * E.LowHP
	local now = os.clock()
	local due = MOTION.LowWarnDue(W.Was, low, now, W.At)
	W.Was = low
	if not due then return false end
	W.At = now
	Fx.PlaySound("LowHeart")
	local qs = C and C.QuickSlots
	if type(qs) == "table" and type(qs.Glow) == "function" then pcall(qs.Glow) end
	return true
end

-- every frame: below EDGE.LowHP the edges throb slowly (shake off: a steady faint edge); a running hit flash wins
function MOTION.EdgeStep()
	if #flashFrames == 0 then return end
	local E = MOTION.EDGE
	if os.clock() < E.FlashUntil then return end
	local char = LocalPlayer and LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local low = hum ~= nil and hum.Health > 0 and hum.MaxHealth > 0 and hum.Health / hum.MaxHealth < E.LowHP
	local t = 1
	if low and not MOTION.EdgeCovered() then
		if MOTION.ShakeAllowed() then
			local w = 0.5 + 0.5 * math.sin(os.clock() * 2 * math.pi / E.Period)
			t = E.PulseLo + (E.PulseHi - E.PulseLo) * w
		else
			t = E.CalmT
		end
	end
	if E.Shown == t then return end
	E.Shown = t
	for _, f in flashFrames do
		f.BackgroundColor3 = COLOR_HURT
		f.BackgroundTransparency = t
	end
end

-- 2-C #9 (최종 검수 10/14): the Settings row "Damage numbers" (DmgNum "All" | "Off") - saved since BB2 but never read
-- until now. Off hides every damage number (my hits M / PvP P, the Release total, the hits I take H); gold / XP / loot
-- lines (G, RG, RX, ShowNumber gold) stay
MOTION.DamageKeys = { M = true, P = true, H = true }
function MOTION.IsDamageKey(key)
	return type(key) == "string" and MOTION.DamageKeys[string.sub(key, 1, 1)] == true
end

function MOTION.DamageNumbersOn()
	return MOTION.Pref("DmgNum", "All") ~= "Off"
end

function MOTION.ShakeAllowed()
	if MOTION.Pref("Shake", true) == false then return false end
	local ok, reduced = pcall(function() return game:GetService("GuiService").ReducedMotionEnabled end)
	return not (ok and reduced == true)
end

-- A23-223: a small glint (a weapon stowed / drawn: WeaponPose.StowApply, own character only)
function Fx.Glint(pos)
	if typeof(pos) ~= "Vector3" or not nearCamera(pos) then return end
	burst(pos, ColorSequence.new(WHITE, COLOR_GOLD), 8, {
		Size = 0.3, SpeedMin = 2, SpeedMax = 5, LifeMin = 0.15, LifeMax = 0.3, LightEmission = 1,
		Acceleration = Vector3.zero, Drag = 4,
	})
end

function Fx.PlaySound(name)
	if type(name) ~= "string" then return end
	local sounds = Config.Sounds
	local id = type(sounds) == "table" and sounds[name] or nil
	if type(id) ~= "string" or id == "" then return end
	local mult = tonumber(MOTION.Pref("Sfx", 1)) or 1
	if mult <= 0 then return end
	local now = os.clock()
	local last = soundLast[name]
	if last and now - last < SOUND_MIN_GAP then return end
	soundLast[name] = now
	pcall(function()
		local s = soundCache[name]
		if not s or not s.Parent then
			s = Instance.new("Sound")
			s.Name = "Fx_" .. name
			s.SoundId = id
			s.Parent = SoundService
			soundCache[name] = s
		end
		s.Volume = (SOUND_VOLUME[name] or 0.5) * math.clamp(mult, 0, 1)
		SoundService:PlayLocalSound(s)
	end)
end

-- 최종 검수 10/14: is a class attack clip running on this character right now? (WeaponPose.RestStep: the sword is raised
-- only while attacking)
function Fx.AttackPlaying(char)
	local st = char and Feel.Chars[char]
	local attack = st and Feel.Active[st] and st.Layers and st.Layers.Attack
	return attack ~= nil and attack.Clip ~= nil
end

-- opts (optional, addendum A9-2): { Pop = true } scales the number PopScale -> 1 in PopTime. Plain text never merges.
function Fx.ShowNumber(worldPos, text, color, scale, opts)
	if typeof(worldPos) ~= "Vector3" then return end
	if not nearCamera(worldPos) then return end
	local pop = type(opts) == "table" and opts.Pop == true
	local ok, err = pcall(spawnNumber, worldPos, text, color, scale, pop, nil)
	if not ok then warnThrottled("ShowNumber failed: " .. tostring(err)) end
end

function Fx.Shake(magnitude, duration)
	if not MOTION.ShakeAllowed() then return end
	magnitude = math.min(asNum(magnitude, 0), MAX_SHAKE)
	duration = math.min(asNum(duration, 0), MAX_SHAKE)
	if magnitude <= 0 or duration <= 0 then return end
	local now = os.clock()
	local remaining = 0
	if shakeBound then
		local t = now - shakeStart
		if t < shakeDur then remaining = shakeMag * (1 - t / shakeDur) end
	end
	if magnitude >= remaining then
		shakeMag = magnitude
		shakeStart = now
		shakeDur = duration
	end
	if not shakeBound then
		shakeBound = true
		local ok = pcall(function()
			RunService:BindToRenderStep(SHAKE_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, shakeStep)
		end)
		if not ok then shakeBound = false end
	end
end

function Fx.Start()
	RunService.RenderStepped:Connect(function(dt)
		local okW, errW = pcall(WOBBLE.step, dt)
		if not okW then warnThrottled("monster wobble failed: " .. tostring(errW)) end
		local okL, errL = pcall(MOTION.LowWarnStep) -- 세세한 #6
		if not okL then warnThrottled("low hp warn failed: " .. tostring(errL)) end
		local okE, errE = pcall(MOTION.EdgeStep)
		if not okE then warnThrottled("edge throb failed: " .. tostring(errE)) end
	end)
	local ok, err = pcall(buildScreenFx)
	if not ok then Util.Warn("Fx", "screen effects not built: " .. tostring(err)) end
	-- A14-4 procedural clips (a failure leaves Feel.Clips empty -> stock animations everywhere)
	local okClips, errClips = pcall(Feel.compileClips)
	if not okClips then Util.Warn("Fx", "attack clips not built: " .. tostring(errClips)) end
	Players.PlayerRemoving:Connect(function(p)
		Feel.PainAt[p.UserId] = nil
		local actor = Feel.Actors[p]
		if actor then
			for _, conn in actor.Conns do conn:Disconnect() end
			Feel.Actors[p] = nil
		end
	end)

	-- level tracking for the A7-3 unlock announce (only decreases are taken from the attribute: rebirth / class reset)
	if LocalPlayer then
		local lvl = LocalPlayer:GetAttribute("Level")
		if type(lvl) == "number" then lastLevelSeen = lvl end
		LocalPlayer:GetAttributeChangedSignal("Level"):Connect(function()
			local v = LocalPlayer:GetAttribute("Level")
			if type(v) == "number" and (lastLevelSeen == nil or v < lastLevelSeen) then
				lastLevelSeen = v
			end
		end)
		-- attack tracks belong to one Animator; a new character loads them again
		LocalPlayer.CharacterAdded:Connect(function()
			resetAttackAnims()
			Feel.StopTrack = nil
		end)
		LocalPlayer.CharacterRemoving:Connect(function(char)
			local st = Feel.Chars[char]
			if st then Feel.drop(st) end
			resetAttackAnims()
			Feel.StopTrack = nil
		end)
		for _, name in { "Class", "Faction" } do
			LocalPlayer:GetAttributeChangedSignal(name):Connect(function()
				local st = Feel.Chars[LocalPlayer.Character]
				if st then Feel.drop(st) end
				resetAttackAnims()
				Feel.StopTrack = nil
			end)
		end
	end

	-- monster attack lunge: watch workspace.Monsters (connect first, then look, so a late folder is never missed)
	workspace.ChildAdded:Connect(function(child)
		if isMonsterFolder(child) then
			local okHook, errHook = pcall(hookMonsterFolder, child)
			if not okHook then warnThrottled("monster folder hook failed: " .. tostring(errHook)) end
		end
	end)
	local monsters = workspace:FindFirstChild(MOTION.MONSTER_FOLDER)
	if monsters and isMonsterFolder(monsters) then
		local okHook, errHook = pcall(hookMonsterFolder, monsters)
		if not okHook then warnThrottled("monster folder hook failed: " .. tostring(errHook)) end
	end

	-- the remote normally exists already; never block the other client modules' Start on it
	task.spawn(function()
		local remote = Net.Get("Fx")
		remote.OnClientEvent:Connect(function(kind, data)
			Fx.Play(kind, data)
		end)
	end)

	print("[Fx] started")
end

return Fx
