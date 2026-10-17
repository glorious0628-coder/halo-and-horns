-- DeepVein.luau : the deep vein run (A23-215 장인 2부, build/codex/craft_curve_r1.md §2: "SkeletonRuins 안쪽의 보호된 광맥 코스에서
-- 위험 구간 이동·전투/타이밍을 마치면 1개 확정 ... 경로 2~3종 순환, 실패 시 재료 소멸 없음, 기다리는 타이머 X"). One run = walk
-- three trail marks deep in the ruins -> beat the vein's guards (personal Skeleton Knights, one at a time) -> work the vein
-- (the Timing panel: 3 of 5) -> one Deep Moon Shard, sure, NOT bound (Reward.FreeItems: a tradeable material). Going down
-- starts the CURRENT step over (ResetOnKO; 최종 검수 10/16: marks already passed stay, A23-203); nothing is lost. Three routes take turns (Run = { Group "Vein", Turn, Of 3 }):
-- A, B, C, A, ... - never counted in the day's RepeatDailyMax, no wait between runs; only the FIRST run is accepted at Pip,
-- the next route starts at once when one ends (Run.Chain, 최종 검수 10/16). Only while the guild's crafting is on
-- (Requires.Feature "Crafting": the shard is a crafting material), from Lv25 (the ruins' level).
-- The asker = Pip (최종 검수 10/16: the goblin carrier of the ruins' loading ramp in the quest bible, Neutral like the guild, no new
-- character): his one body (Daily pack, Npcs) - no second Pip body.
-- How many, in ONE place (API review 10/17: the guards pay a plain Skeleton's XP / gold and drop nothing - never a farm;
-- HPMult / GUARDS / VeinSeconds = the run's length levers, see the contract doc for the minutes):
local GUARDS = 3 -- personal Skeleton Knights per run (one at a time)
local K = { GuardPay = "Skeleton", GuardHPMult = 3, VeinSeconds = 8 }

local function route(turn, tag, title, short, marks, guard, vein)
	local steps = {}
	for i, spot in marks do
		table.insert(steps, { Text = string.format("Follow the miner's marks (%d/3)", i), ShortName = string.format("Mark %d/3", i),
			Guide = spot, Obj = { Type = "Near", Spot = spot, Radius = 12 }, On = "Self",
			Find = i == 1 and "A miner's mark. The trail goes on." or nil })
	end
	table.insert(steps, { Text = "Beat the vein's guards %d/%d", ShortName = "Guards x" .. GUARDS, Guide = guard,
		Spawn = { Kind = "SkeletonKnight", Spot = guard, Radius = 40, Pay = K.GuardPay, HPMult = K.GuardHPMult },
		Obj = { Type = "Kill", Kind = "SkeletonKnight", Personal = true, Count = GUARDS }, On = "Self",
		Find = "Guards! They won't let anyone near." })
	table.insert(steps, { Text = "Work the deep vein", ShortName = "Deep vein", Guide = vein,
		Obj = { Type = "Timing", Spot = vein, MinSeconds = K.VeinSeconds }, On = "Self", Find = "There it is. Easy taps." })
	return {
		Kind = "Sub", Type = "Gather", Difficulty = "Challenge", Run = { Group = "Vein", Turn = turn, Of = 3, Chain = true }, ResetOnKO = true,
		Title = title, ShortName = short, Speaker = "Pip",
		Offer = { Npc = "Pip",
			Before = "The deep vein glows again. Skeletons guard it.",
			Lines = { All = { "Pip: I chalked marks to the " .. tag .. " vein. Bring back a shard?" } } },
		Requires = { Done = { "M1_4" }, Level = 25, Feature = "Crafting" },
		Last = true,
		Steps = steps,
		Reward = { FreeItems = { { Id = "DeepMoonShard", N = 1 } } },
	}
end

return {
	Defs = {
		DV1 = route(1, "north", "The North Vein", "North vein", { "DV1Mark1", "DV1Mark2", "DV1Mark3" }, "DV1Guard", "DV1Vein"),
		DV2 = route(2, "south", "The South Vein", "South vein", { "DV2Mark1", "DV2Mark2", "DV2Mark3" }, "DV2Guard", "DV2Vein"),
		DV3 = route(3, "deep", "The Deep Vein", "Deep vein", { "DV3Mark1", "DV3Mark2", "DV3Mark3" }, "DV3Guard", "DV3Vein"),
	},
	Subs = { "DV1", "DV2", "DV3" },
	-- temporary spots inside the Skeleton Ruins (Config.Zones.SkeletonRuins: x 1260..1780, z -290..290), all OUTSIDE the Crown
	-- Pit PvP area (centre (1660, 0), 200 x 240 = x 1560..1760, z -120..120; API review 10/17: no PvP KO resetting a run); a
	-- StoryLandmark-tagged part with Spot = <key> moves one (MapBuilder rule). North / south routes go round the pit, the deep one
	-- stays west of it
	Landmarks = {
		DV1Mark1 = Vector3.new(1360, 0, -130), DV1Mark2 = Vector3.new(1480, 0, -200), DV1Mark3 = Vector3.new(1600, 0, -170),
		DV1Guard = Vector3.new(1680, 0, -190), DV1Vein = Vector3.new(1730, 0, -230),
		DV2Mark1 = Vector3.new(1380, 0, 150), DV2Mark2 = Vector3.new(1500, 0, 220), DV2Mark3 = Vector3.new(1610, 0, 170),
		DV2Guard = Vector3.new(1690, 0, 190), DV2Vein = Vector3.new(1735, 0, 235),
		DV3Mark1 = Vector3.new(1360, 0, 20), DV3Mark2 = Vector3.new(1420, 0, -80), DV3Mark3 = Vector3.new(1480, 0, 80),
		DV3Guard = Vector3.new(1510, 0, -20), DV3Vein = Vector3.new(1535, 0, 10),
	},


}
