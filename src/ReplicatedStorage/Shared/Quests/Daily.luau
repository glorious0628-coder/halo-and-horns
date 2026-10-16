-- Daily.luau : the 12 daily repeat requests (A23-205 / A23-206 / A23-207, 게임성 개발 2, 2026-10-15; contract
-- docs/design/quest_data_contract_2026-10-15.md §6, story build/codex/story_emotion_r2.md §3, rewards 최종 검수 10/15).
-- A player takes at most Config.StoryQuests.RepeatDailyMax (5) a day; each pays a different kind (bound to the character).
-- Each side sees its town's three (Easy / Normal / Hard) and the three shared ones (Normal / Hard / Challenge). Every request
-- ends with a small choice whose result is saved (Story.Flags, key = the quest id): the next day's Before remembers it
-- (Offer.BeforeBy). Props (boxes, name tags, chairs ...) stand at the Landmarks below: 0-won part skeletons tagged
-- StoryLandmark, placed by 메인 반영 1 (list: docs/design/daily_props_2026-10-15.md). Pip has a temporary default body.

-- the rewards in ONE place: SPEC A23-215 (user 10/16) = twelve DIFFERENT bundles, build/codex/artisan_switch_r1.md §3 (no
-- material the side cannot use while the artisan switches are off). Items = { { Id, N } } (potions too, StoryQuestService
-- rewardItems; quest items are bound, A23-206). Gold = GoldN, a fixed amount (Gold is hunt units). The artisans' three keep
-- their materials: they show only with the guild (NeutralFaction) on. DC3's title comes once (TitleService: a held title is
-- not given again), then the scrolls only
local R = {
	DH2 = { Potion = "HP", N = 1, GoldN = 30 }, -- Easy: a heal
	DH3 = { Items = { { Id = "HP", N = 2 }, { Id = "MP", N = 1 } }, GoldN = 60 }, -- Normal: travel supplies
	DH1 = { Item = "Enh70", N = 1, GoldN = 100 }, -- Hard: an upgrade try
	DR3 = { Potion = "MP", N = 1, GoldN = 30 }, -- Easy: mana
	DR2 = { Items = { { Id = "MP", N = 2 }, { Id = "HP", N = 1 } }, GoldN = 60 }, -- Normal: skill supplies
	DR1 = { Item = "Move70", N = 1, GoldN = 100 }, -- Hard: useful once a weapon has a + to move
	DN3 = { Item = "PetTreat", N = 3, GoldN = 30 }, -- Easy (the guild on)
	DN1 = { Item = "Herb", N = 10, GoldN = 60 }, -- Normal (the guild on)
	DN2 = { Item = "Glowcap", N = 8, GoldN = 100 }, -- Hard (the guild on)
	DC1 = { XPBar = 0.03, GoldN = 60 }, -- Normal: 3% of the current level's bar
	DC2 = { Items = { { Id = "Enh70", N = 1 }, { Id = "HP", N = 2 } }, GoldN = 100 }, -- Hard: the woods' fight costs more
	DC3 = { Items = { { Id = "Enh30", N = 1 }, { Id = "Enh70", N = 1 } }, Title = "RecordKeeper", GoldN = 200 }, -- Challenge
}

-- how many, in ONE place (user 10/16 via 최종 검수: "슬라임 6마리 너무 적지 않아? 50마리에 표본 5개"): Kill = monsters to
-- beat, Pick = the things picked up after (the asker's line says the number). Hard / Challenge repairs = three timing
-- panels at the object after a long walk for the parts (DN2 / DC3: three steps). Easy errands have no count
local K = {
	DH1 = { Kill = 50, Pick = 5 }, DR1 = { Kill = 50, Pick = 5 }, -- Hard (slimes)
	DN1 = { Kill = 20, Pick = 3 }, -- Normal (slimes)
	DC2 = { Kill = 30, Pick = 5 }, -- Hard (goblins)
	DC3 = { Kill = 50 }, -- Challenge (ruins skeletons, then the three rests)
}

-- the last step: the asker's card with the small choice (Flag key = the quest id; Neutral players pick A / B)
local function choice(npc, line, good, evil, flagGood, flagEvil, id, scene, text, short)
	return { Text = text, ShortName = short, Npc = npc, Panel = true, Lines = { All = { line } }, Scene = scene,
		Obj = { Type = "Choice", Good = { Label = good, Points = 0 }, Evil = { Label = evil, Points = 0 },
			Neutral = { A = good, B = evil }, Flag = { Key = id, Good = flagGood, Evil = flagEvil } } }
end

return {
	Defs = {
		------------------------------------------------------------------ Halo town (Bright / Sir Gleam)
		DH2 = {
			Kind = "Sub", Type = "Deliver", Repeat = "Daily", Difficulty = "Easy", Factions = { Halo = true },
			Title = "The Cat's Ramp", ShortName = "Cat's ramp", Speaker = "Gleam",
			Offer = { Npc = "Gleam", BeforeBy = { Flag = "DH2",
					Cat = "The cat naps on your clear ramp. New boxes came in today.",
					Mine = "Your lookout still stands! New boxes are in the cat's way.",
					Default = "The cat likes our ramp. These new boxes block its spot." },
				Lines = { All = { "Sir Gleam: Will you move two boxes off the cat's ramp?" } } },
			Requires = { Done = { "M1_4" } },
			Last = true,
			Steps = {
				{ Text = "Pick up the empty boxes", ShortName = "Two boxes", Guide = "DH2Boxes",
					Obj = { Type = "Pickup", Spot = "DH2Boxes", Radius = 8 }, On = "Self", Find = "Two empty boxes. Let's move them." },
				{ Text = "Set them down by the ramp", ShortName = "By the ramp", Guide = "DH2Ramp",
					Obj = { Type = "Near", Spot = "DH2Ramp", Radius = 10 }, On = "Self", Find = "The cat's spot is right here." },
				choice("Gleam", "Sir Gleam: Leave the ramp clear for the cat, or stack a lookout?", "Clear it for the cat",
					"Make my lookout", "Cat", "Mine", "DH2", "Wave", "Back to Sir Gleam", "Sir Gleam"),
			},
			Reward = R.DH2,
		},
		DH3 = {
			Kind = "Sub", Type = "Investigate", Repeat = "Daily", Difficulty = "Normal", Factions = { Halo = true },
			Title = "Mixed-Up Name Tags", ShortName = "Name tags", Speaker = "Bright",
			Offer = { Npc = "Bright", BeforeBy = { Flag = "DH3",
					Even = "Our tags still match! Two new ones got mixed up today.",
					Top = "Your tag still sits on top. Two new ones got mixed up!",
					Default = "Two new name tags got mixed up. Mine is upside down!" },
				Lines = { All = { "Bright: Will you help me fix our name tags?" } } },
			Requires = { Done = { "M1_4" } },
			Last = true,
			Steps = {
				{ Text = "Look at the name tags", ShortName = "Name tags", Guide = "DH3Tags",
					Obj = { Type = "Near", Spot = "DH3Tags", Radius = 10 }, On = "Self", Find = "Two name tags... both upside down?" },
				{ Text = "Match the tag shapes", ShortName = "Match them", Guide = "DH3Tags",
					Obj = { Type = "Match", Target = "Tag", Wrong = { "Seal", "Knot" } }, On = "Self", Find = "Which shape goes where?" },
				choice("Bright", "Bright: Same height for both tags, or yours on top?", "Same height", "Mine on top",
					"Even", "Top", "DH3", "Nod", "Back to Bright", "Bright"),
			},
			Reward = R.DH3,
		},
		DH1 = {
			Kind = "Sub", Type = "Recover", Repeat = "Daily", Difficulty = "Hard", Factions = { Halo = true },
			Title = "Glue for the Letters", ShortName = "Letter glue", Speaker = "Bright",
			Offer = { Npc = "Bright", BeforeBy = { Flag = "DH1",
					Shared = "Your sealed envelopes still hold! These new ones need glue.",
					Mine = "Your stamp is on every letter I sent! More need glue today.",
					Default = "My new letters need glue. The slimes keep bouncing on it." },
				Lines = { All = { string.format("Bright: Will you beat %d slimes and bring %d glue samples?", K.DH1.Kill, K.DH1.Pick) } } },
			Requires = { Done = { "M1_4" } },
			Last = true,
			Steps = {
				{ Text = "Beat slimes %d/%d", ShortName = "Slimes x" .. K.DH1.Kill, Guide = "SlimeMeadow",
					Obj = { Type = "Kill", Kind = "Slime", Zone = "SlimeMeadow", Count = K.DH1.Kill }, On = "Self",
					Find = "Off my glue, you bouncy things!" },
				{ Text = "Pick up the glue samples", ShortName = "Glue", Guide = "DH1Glue",
					Obj = { Type = "Pickup", Spot = "DH1Glue", Radius = 8 }, On = "Self", Find = "All the sticky samples. Perfect!" },
				choice("Bright", "Bright: Seal the envelopes for everyone, or add your stamp?", "Seal them for everyone",
					"Press my stamp on", "Shared", "Mine", "DH1", "Nod", "Back to Bright", "Bright"),
			},
			Reward = R.DH1,
		},
		------------------------------------------------------------------ Horns town (Rascal Rex / Rose)
		DR3 = {
			Kind = "Sub", Type = "Command", Repeat = "Daily", Difficulty = "Easy", Factions = { Horns = true },
			Title = "Chairs for the Guests", ShortName = "Guest chairs", Speaker = "Rex",
			Offer = { Npc = "Rex", BeforeBy = { Flag = "DR3",
					Circle = "Your circle worked great! Two more guests are coming.",
					Front = "You loved the front row! Two more guests need chairs.",
					Default = "Two more guests are coming. I saved the wrong chairs." },
				Lines = { All = { "Rascal Rex: Move two chairs for my guests, please?" } } },
			Requires = { Done = { "M1_4" } },
			Last = true,
			Steps = {
				{ Text = "Pick up the chairs", ShortName = "Two chairs", Guide = "DR3Chairs",
					Obj = { Type = "Pickup", Spot = "DR3Chairs", Radius = 8 }, On = "Self", Find = "Wrong chairs. I'll take these two." },
				{ Text = "Bring them to the guest seats", ShortName = "Guest seats", Guide = "DR3Seats",
					Obj = { Type = "Near", Spot = "DR3Seats", Radius = 10 }, On = "Self", Find = "The guests sit right here." },
				choice("Rex", "Rascal Rex: A circle for all, or the front row for you?", "Make a circle", "Front row for me",
					"Circle", "Front", "DR3", "Bow", "Back to Rascal Rex", "Rascal Rex"),
			},
			Reward = R.DR3,
		},
		DR2 = {
			Kind = "Sub", Type = "Prank", Repeat = "Daily", Difficulty = "Normal", Factions = { Horns = true },
			Title = "The Trick Box", ShortName = "Trick box", Speaker = "Smokey",
			Offer = { Npc = "Smokey", BeforeBy = { Flag = "DR2",
					Both = "We popped out together last time! I made a new box trick.",
					Me = "You stole the show last time! I built a sneakier box.",
					Default = "I made a new box trick. My hat is already hiding." },
				Lines = { All = { "Rose: Will you test the two handles of my trick box?" } } },
			Requires = { Done = { "M1_4" } },
			Last = true,
			Steps = {
				{ Text = "Go to the trick box", ShortName = "Trick box", Guide = "DR2Box",
					Obj = { Type = "Near", Spot = "DR2Box", Radius = 10 }, On = "Self", Find = "A trick box with two handles." },
				{ Text = "Pull the handles on time", ShortName = "Handles", Guide = "DR2Box",
					Obj = { Type = "Timing" }, On = "Self", Find = "Pull them at the right time!" },
				choice("Smokey", "Rose: Who pops out first? Both of us, or just you?", "Pop out together", "Me first!",
					"Both", "Me", "DR2", "Laugh", "Back to Rose", "Rose"),
			},
			Reward = R.DR2,
		},
		DR1 = {
			Kind = "Sub", Type = "Recover", Repeat = "Daily", Difficulty = "Hard", Factions = { Horns = true },
			Title = "Pads for the Bell", ShortName = "Bell pads", Speaker = "Rex",
			Offer = { Npc = "Rex", BeforeBy = { Flag = "DR1",
					Duet = "Our bell still rings softly. The new pads are pillows again!",
					Solo = "Your solo still echoes! The slimes took the new pads too.",
					Default = "My bell needs soft pads. The slimes use them as pillows." },
				Lines = { All = { string.format("Rascal Rex: Beat %d slimes and grab %d soft pads?", K.DR1.Kill, K.DR1.Pick) } } },
			Requires = { Done = { "M1_4" } },
			Last = true,
			Steps = {
				{ Text = "Beat slimes %d/%d", ShortName = "Slimes x" .. K.DR1.Kill, Guide = "SlimeMeadow",
					Obj = { Type = "Kill", Kind = "Slime", Zone = "SlimeMeadow", Count = K.DR1.Kill }, On = "Self",
					Find = "Hey! Those pads aren't pillows!" },
				{ Text = "Pick up the soft pads", ShortName = "Soft pads", Guide = "DR1Pads",
					Obj = { Type = "Pickup", Spot = "DR1Pads", Radius = 8 }, On = "Self", Find = "All the squishy pads. Got them." },
				choice("Rex", "Rascal Rex: Soft pads! A quiet duet, or my big solo?", "Play it together", "Your big solo",
					"Duet", "Solo", "DR1", "Clap", "Back to Rascal Rex", "Rascal Rex"),
			},
			Reward = R.DR1,
		},
		------------------------------------------------------------------ the artisans (Tiny / Kit / Otto, at the Crossroads)
		DN3 = {
			Kind = "Sub", Type = "Tame", Repeat = "Daily", Difficulty = "Easy", Factions = { Neutral = true },
			Title = "The Right Bowl", ShortName = "Right bowl", Speaker = "Tiny",
			Offer = { Npc = "Tiny", BeforeBy = { Flag = "DN3",
					Shared = "The little slime loves the shared spot! It found new bowls.",
					Train = "Your training spot works! The little slime found new bowls.",
					Default = "The little slime keeps waiting beside the wrong bowl." },
				Lines = { All = { "Tiny: Will you put the two empty bowls in the right spot?" } } },
			Requires = { Done = { "M1_4" } },
			Last = true,
			Steps = {
				{ Text = "Pick up the empty bowls", ShortName = "Two bowls", Guide = "DN3Bowls",
					Obj = { Type = "Pickup", Spot = "DN3Bowls", Radius = 8 }, On = "Self", Find = "Two empty bowls. Where do they go?" },
				{ Text = "Set them by the little slime", ShortName = "Slime's spot", Guide = "DN3Spot",
					Obj = { Type = "Near", Spot = "DN3Spot", Radius = 10 }, On = "Self", Find = "The little slime waits here." },
				choice("Tiny", "Tiny: One spot for everyone, or a training spot for yours?", "One spot for all",
					"My training spot", "Shared", "Train", "DN3", "Nod", "Back to Tiny", "Tiny"),
			},
			Reward = R.DN3,
		},
		DN1 = {
			Kind = "Sub", Type = "Recover", Repeat = "Daily", Difficulty = "Normal", Factions = { Neutral = true },
			Title = "Seals for the Parcels", ShortName = "Parcel seals", Speaker = "Guild",
			Offer = { Npc = "Kit", BeforeBy = { Flag = "DN1",
					Plain = "Your plain boxes went out fine! New parcels need seals.",
					Mark = "People love your mark! New parcels need seals today.",
					Default = "New parcels need seals. The slimes think they're hats." },
				Lines = { All = { string.format("Kit: Beat %d slimes and bring %d seal samples to Otto?", K.DN1.Kill, K.DN1.Pick) } } },
			Requires = { Done = { "M1_4" } },
			Last = true,
			Steps = {
				{ Text = "Beat slimes %d/%d", ShortName = "Slimes x" .. K.DN1.Kill, Guide = "SlimeMeadow",
					Obj = { Type = "Kill", Kind = "Slime", Zone = "SlimeMeadow", Count = K.DN1.Kill }, On = "Self",
					Find = "Those seals are not hats!" },
				{ Text = "Pick up the seal samples", ShortName = "Seals", Guide = "DN1Seals",
					Obj = { Type = "Pickup", Spot = "DN1Seals", Radius = 8 }, On = "Self", Find = "All the sticky seals. Nice." },
				choice("Otto", "Otto: Good seals! Plain boxes for all, or your own mark?", "Plain for everyone",
					"Put my mark on", "Plain", "Mark", "DN1", "Nod", "Bring them to Otto", "Otto"),
			},
			Reward = R.DN1,
		},
		DN2 = {
			Kind = "Sub", Type = "Repair", Repeat = "Daily", Difficulty = "Hard", Factions = { Neutral = true },
			Title = "A Better Handle", ShortName = "Cart handle", Speaker = "Smith",
			Offer = { Npc = "Otto", BeforeBy = { Flag = "DN2",
					Shared = "Your shared cart still rolls! This one needs a handle too.",
					Signed = "Your signed handle still holds! This cart needs one too.",
					Default = "This old cart needs a better handle. Can you fix it?" },
				Lines = { All = { "Otto: Bring hard wood from the far meadow and fix the three grooves?" } } },
			Requires = { Done = { "M1_4" } },
			Last = true,
			Steps = {
				{ Text = "Go to the old cart", ShortName = "Old cart", Guide = "DN2Cart",
					Obj = { Type = "Near", Spot = "DN2Cart", Radius = 10 }, On = "Self", Find = "A cart with a wobbly handle." },
				{ Text = "Get hard wood by the woods", ShortName = "Hard wood", Guide = "DN2Wood",
					Obj = { Type = "Pickup", Spot = "DN2Wood", Radius = 8 }, On = "Self", Find = "Good hard wood. Back to the cart!" },
				{ Text = "Fix the first groove", ShortName = "Groove 1", Guide = "DN2Cart",
					Obj = { Type = "Timing", Spot = "DN2Cart" }, On = "Self", Find = "Tap, tap... steady now." },
				{ Text = "Fix the second groove", ShortName = "Groove 2", Guide = "DN2Cart",
					Obj = { Type = "Timing", Spot = "DN2Cart" }, On = "Self" },
				{ Text = "Fix the last groove", ShortName = "Groove 3", Guide = "DN2Cart",
					Obj = { Type = "Timing", Spot = "DN2Cart" }, On = "Self" },
				choice("Kit", "Kit: Nice fix! Share the cart, or sign the handle?", "Share the cart", "Sign the handle",
					"Shared", "Signed", "DN2", "Spin", "Show Kit", "Kit"),
			},
			Reward = R.DN2,
		},
		------------------------------------------------------------------ shared (every side)
		DC1 = {
			Kind = "Sub", Type = "Deliver", Repeat = "Daily", Difficulty = "Normal",
			Title = "A Smaller Box", ShortName = "Small box", Speaker = "Guild",
			Offer = { Npc = "Kit", BeforeBy = { Flag = "DC1",
					Together = "Otto kept your last box! Now he needs a smaller one.",
					Stamp = "Otto loves your stamped box! Now he needs a smaller one.",
					Default = "Otto needs a small box for his tools. Can you bring it?" },
				Lines = { All = { "Kit: Will you take this small box to Otto?" } } },
			Requires = { Done = { "M1_4" }, Level = 8 },
			Last = true,
			Steps = {
				{ Text = "Pick up the small box", ShortName = "Small box", Guide = "DC1Box",
					Obj = { Type = "Pickup", Spot = "DC1Box", Radius = 8 }, On = "Self", Find = "A smaller box for Otto." },
				{ Text = "Take it to Otto", ShortName = "To Otto", Npc = "Otto", Obj = { Type = "Deliver" },
					Find = "Ah, the small box. Perfect." },
				choice("Otto", "Otto: Pack it together with Kit, or put your stamp on it?", "Pack it together",
					"My stamp on it", "Together", "Stamp", "DC1", "Clap", "Talk to Otto", "Otto"),
			},
			Reward = R.DC1,
		},
		DC2 = {
			Kind = "Sub", Type = "Recover", Repeat = "Daily", Difficulty = "Hard",
			Title = "Barrel Racers", ShortName = "Barrel race", Speaker = "Pip",
			Offer = { Npc = "Pip", BeforeBy = { Flag = "DC2",
					Clear = "Your clear path still works! The goblins raced again.",
					Mark = "Your mark is still on the path! The goblins raced again.",
					Default = "The goblins tried barrel racing. Our path is the finish line." },
				Lines = { All = { string.format("Pip: Beat %d goblins and roll %d barrels off our path?", K.DC2.Kill, K.DC2.Pick) } } },
			Requires = { Done = { "M1_4" }, Level = 10 },
			Last = true,
			Steps = {
				{ Text = "Beat goblins %d/%d", ShortName = "Goblins x" .. K.DC2.Kill, Guide = "GoblinWoods",
					Obj = { Type = "Kill", Kind = "Goblin", Zone = "GoblinWoods", Count = K.DC2.Kill }, On = "Self",
					Find = "Goblin barrel racers! Stop!" },
				{ Text = "Roll the barrels away", ShortName = "Barrels", Guide = "DC2Barrels",
					Obj = { Type = "Pickup", Spot = "DC2Barrels", Radius = 8 }, On = "Self", Find = "So many barrels. Same funny sound." },
				choice("Pip", "Pip: A clear path for all, or leave your mark on it?", "Clear it for all", "Leave my mark",
					"Clear", "Mark", "DC2", "Wave", "Back to Pip", "Pip"),
			},
			Reward = R.DC2,
		},
		DC3 = {
			Kind = "Sub", Type = "Repair", Repeat = "Daily", Difficulty = "Challenge",
			Title = "The Record Stand", ShortName = "Record stand", Speaker = "Pip",
			Offer = { Npc = "Pip", BeforeBy = { Flag = "DC3",
					Shared = "Our record stand still works! New pages need room again.",
					Signed = "Your name is still on the stand! New pages need room.",
					Default = "The old stand is fine. These new pages need more room." },
				Lines = { All = { string.format("Pip: Beat %d skeletons, then fit three old rests on the record stand?", K.DC3.Kill) } } },
			Requires = { Done = { "M1_4" }, Level = 25 },
			Last = true,
			Steps = {
				{ Text = "Go to the record stand in the ruins", ShortName = "Record stand", Guide = "DC3Stand",
					Obj = { Type = "Near", Spot = "DC3Stand", Radius = 10 }, On = "Self", Find = "An old stand. Still steady." },
				{ Text = "Beat skeletons %d/%d", ShortName = "Skeletons x" .. K.DC3.Kill, Guide = "SkeletonRuins",
					Obj = { Type = "Kill", Kind = "Skeleton", Zone = "SkeletonRuins", Count = K.DC3.Kill }, On = "Self",
					Find = "Such tidy fighters!" },
				{ Text = "Find the old rests deep in the ruins", ShortName = "Old rests", Guide = "DC3Rests",
					Obj = { Type = "Pickup", Spot = "DC3Rests", Radius = 8 }, On = "Self", Find = "Three old rests. Heavy!" },
				{ Text = "Fit the first rest", ShortName = "Rest 1", Guide = "DC3Stand",
					Obj = { Type = "Timing", Spot = "DC3Stand" }, On = "Self", Find = "Easy does it." },
				{ Text = "Fit the second rest", ShortName = "Rest 2", Guide = "DC3Stand",
					Obj = { Type = "Timing", Spot = "DC3Stand" }, On = "Self" },
				{ Text = "Fit the last rest", ShortName = "Rest 3", Guide = "DC3Stand",
					Obj = { Type = "Timing", Spot = "DC3Stand" }, On = "Self" },
				choice("Pip", "Pip: One shared record, or your name on the stand?", "Share the record", "Sign the stand",
					"Shared", "Signed", "DC3", "Nod", "Back to Pip", "Pip"),
			},
			Reward = R.DC3,
		},
	},
	Subs = { "DH2", "DH3", "DH1", "DR3", "DR2", "DR1", "DN3", "DN1", "DN2", "DC1", "DC2", "DC3" },
	-- where the props stand (temporary spots; a StoryLandmark-tagged part with Spot = <key> moves them, MapBuilder rule)
	Landmarks = {
		DH2Boxes = Vector3.new(-34, 0, -392), DH2Ramp = Vector3.new(-44, 0, -360), DH3Tags = Vector3.new(44, 0, -452),
		DH1Glue = Vector3.new(196, 0, 24),
		DR3Chairs = Vector3.new(36, 0, 440), DR3Seats = Vector3.new(56, 0, 428), DR2Box = Vector3.new(-44, 0, 400),
		DR1Pads = Vector3.new(176, 0, -44),
		DN3Bowls = Vector3.new(18, 0, 22), DN3Spot = Vector3.new(8, 0, 34), DN1Seals = Vector3.new(212, 0, -20),
		DN2Cart = Vector3.new(28, 0, 62), DN2Wood = Vector3.new(640, 0, 80), -- the wood: the meadow's far end, ~610 studs out
		DC1Box = Vector3.new(54, 0, 38), DC2Barrels = Vector3.new(764, 0, 28), DC3Stand = Vector3.new(1292, 0, 40),
		DC3Rests = Vector3.new(1580, 0, 120), -- deep in the ruins, ~310 studs past the stand
	},
	-- Pip (story_depth §4, chapter 3's goblin friend): a temporary default Roblox-style body at the woods' edge (the shop NPCs'
	-- temporary rule) until an approved look
	Npcs = {
		{ Id = "Pip", Name = "Npc_Pip", Story = "Pip", Label = "Pip", At = Vector3.new(700, 0, 30), Look = Vector3.new(660, 0, 30),
			Colors = { Head = Color3.fromRGB(150, 190, 110), Torso = Color3.fromRGB(120, 90, 60), Legs = Color3.fromRGB(80, 70, 55) } },
	},
}
