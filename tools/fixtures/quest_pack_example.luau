-- quest_pack_example.luau : the example quest data pack of docs/design/quest_data_contract_2026-10-15.md (tools/test_quest_data.py
-- loads it as an extra pack: a good pack must pass every check, and each of the test's broken copies must be caught).
-- A real pack lives in src/ReplicatedStorage/Shared/Quests/<Side>_Ch<N>.luau and returns the same shape.
return {
	Faction = "Halo", -- the side its Variants are for
	Defs = {
		-- a new main quest of the Halo chain (Factions = only Halo walks it; the other sides skip it)
		HX_Guard = {
			Kind = "Main", Chapter = 2, Type = "Escort", Difficulty = "Normal", Factions = { Halo = true },
			Title = "Guard the Parcel Cart", ShortName = "Guard cart", Speaker = "Bright",
			Offer = { Npc = "Bright", Lines = { All = { "Bright: Please guard this parcel cart across the bridge." } } },
			Requires = { Level = 5 },
			Steps = {
				{ Text = "Walk beside the cart to the bridge", ShortName = "To the bridge", Guide = "HaloBridge",
					Obj = { Type = "Near", Spot = "HaloBridge", Radius = 16 } },
				{ Text = "Tell Bright the cart is safe", ShortName = "Back to Bright", Npc = "Bright", Panel = true,
					Lines = { All = { "Bright: Safe and sound! Thank you!" } }, Obj = { Type = "Talk" } },
			},
			Reward = { Gold = 1, XP = 1 },
		},
		-- an optional town request (a sub: offered, never pushed)
		HX_Ribbon = {
			Kind = "Sub", Type = "Deliver", Difficulty = "Easy", Factions = { Halo = true },
			Title = "Bright's Ribbon", ShortName = "The ribbon", Speaker = "Bright",
			Offer = { Npc = "Bright", Lines = { All = { "Bright: Please show Otto my crumpled ribbon." } } },
			Requires = { Done = { "H_Band" }, Level = 4 },
			Steps = {
				{ Text = "Show Otto the ribbon", ShortName = "To Otto", Npc = "Otto", Obj = { Type = "Deliver" } },
			},
			Reward = { GoldN = 40 },
		},
		-- a daily repeat request (A23-205: at most Config.StoryQuests.RepeatDailyMax a day, chosen by the player; A23-206: every
		-- repeat pays a different kind, bound to the character)
		HX_DailyLamp = {
			Kind = "Sub", Type = "Repair", Repeat = "Daily", Difficulty = "Hard", Factions = { Halo = true },
			Title = "Lamp Check", ShortName = "Lamp check", Speaker = "Bright",
			Offer = { Npc = "Bright", Lines = { All = { "Bright: Please check the town lamp for me." } } },
			Requires = { Done = { "M1_4" } },
			Steps = {
				{ Text = "Check the town lamp", ShortName = "The lamp", Guide = "LampH", Obj = { Type = "Near", Spot = "LampH", Radius = 12 } },
			},
			Reward = { Item = "Enh70", N = 1 },
		},
	},
	Main = { { After = "M1_4", Ids = { "HX_Guard" } } },
	Subs = { "HX_Ribbon", "HX_DailyLamp" },
	-- the Halo version of a shared quest: same number of steps as the base (M2_2 has 1)
	Variants = {
		M2_2 = {
			Offer = { Npc = "Bright", Lines = { All = { "Bright: Please catch the sample before it floats away." } } },
			Steps = {
				[1] = { Text = "Catch the floating sample at the pond", ShortName = "The sample", Guide = "SlimePond",
					Obj = { Type = "Near", Spot = "SlimePond", Radius = 20 } },
			},
		},
	},
}
