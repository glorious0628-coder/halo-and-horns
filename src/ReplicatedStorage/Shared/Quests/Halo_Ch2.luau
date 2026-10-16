-- Halo_Ch2.luau : the Halo side's story fields of the shared chapter-2 mains M2_1 ~ M2_6 (GPT build/codex/story_ch2_r1.md §2-1,
-- 최종 검수 10/16; contract docs/design/quest_data_contract_2026-10-15.md §5). Story only: every goal, reward, id, Requires, step
-- count and order stay the base quest's in Config.StoryQuests.Defs. A Variants step becomes def.Steps[i].Halo, which the server
-- (StoryQuestService stepOf) and the client (StoryNpcs.StepFor) lay over the base step field by field, so a step here carries
-- only the fields it changes (On / Find / Lines / Scene). Mood: curiosity about the two knots -> a kind worry for Pip.
return {
	Faction = "Halo",
	Variants = {
		M2_1 = { -- 1 step: WarPoints 15 as before
			Offer = {
				Npc = "Bright",
				Before = "Dust made our old fountain cleaners gather everyone's bags.",
				Lines = { All = {
					"Bright: Will you stop the fuss and help our crown shine?",
				} },
			},
			Steps = {
				[1] = {
					On = "Self", Find = "Even bags go in their cleaning pile!",
					Lines = { All = {
						"The road feels quieter. What's shining by the pond?",
					} }, Scene = "Nod",
				},
			},
			Next = { Id = "M2_2", Line = "Bright wants a closer look at that pond dust." },
		},
		M2_2 = { -- H06: pond Slime 4 (not a rescue goal)
			Offer = {
				Npc = "Bright",
				Before = "Dust made the pond cleaners scoop up ribbons with the leaves.",
				Lines = { All = {
					"Bright: Will you calm four slimes by the pond?",
					"Bright: I want to see what's caught in their dust.",
				} },
			},
			Steps = {
				[1] = {
					On = "Self", Find = "A ribbon in the leaf pile?",
					Lines = { All = {
						"The dust settled. Two colors, just like the band.",
					} }, Scene = "Sparkle",
				},
			},
			Next = { Id = "M2_3", Line = "Tiny knows those colors. He's by the fountain." },
		},
		M2_3 = { -- H07: reach the fountain + the existing choice (2 steps)
			Offer = {
				Npc = "Tiny",
				Before = "Bright keeps hiding her wrist. Mine has the same knot.",
				Lines = { All = {
					"Tiny: Will you take that dust to the fountain?",
					"Tiny: You can give it to the fountain or keep it.",
				} },
			},
			Steps = {
				[1] = { On = "Self", Find = "Two wrists. The same crooked knots." },
				-- the fountain choice (no Npc): the Self minimal version (the Tiny peak line is added separately)
				[2] = {
					-- story_ch2_r1 §1 peak (최종 검수 10/16): Tiny says it at the fountain (On = his body), the card keeps the player's lines
					On = "Tiny", Find = "Bright tied mine. I tied hers.",
					Lines = { All = {
						"Bright tied Tiny's. Tiny tied hers. Both kept them.",
						"This dust can light the fountain, or stay with me.",
					} }, Scene = "Wave",
				},
			},
			Next = { Id = "M2_4", Line = "Tiny is saving a snack for Pip on the supply road." },
		},
		M2_4 = { -- H08: monster gold 60 + enter a town (no escort lines)
			Offer = {
				Npc = "Tiny",
				Before = "Dust made the old cleaners pile our road supplies in the way.",
				Lines = { All = {
					"Tiny: Will you earn 60 gold from monsters on the road?",
					"Tiny: Then enter a town to keep your gold safe.",
				} },
			},
			Steps = {
				[1] = { On = "Self", Find = "Pip has a snack spot too." },
				[2] = {
					On = "Self", Find = "The town is right here.",
					Lines = { All = {
						"My gold is safe. Tiny still has Pip's snack ready.",
					} }, Scene = "Nod",
				},
			},
			Next = { Id = "M2_5", Line = "The slimes are piling up by the meadow supplies." },
		},
		M2_5 = { -- H09: Lv5 + skill / Min 3 Count 2 as before
			Offer = {
				Npc = "Tiny",
				Before = "Dust made our slime cleaners sweep the boxes into one big pile.",
				Lines = { All = {
					"Tiny: With your first skill, hit three monsters at once.",
					"Tiny: Do that twice. These boxes need room!",
				} },
			},
			Steps = {
				[1] = { On = "Self", Find = "I've learned a move for this." },
				[2] = {
					On = "Self", Find = "Those boxes aren't pond leaves!",
					Lines = { All = {
						"Room again. That empty snack spot is still there.",
					} }, Scene = "Clap",
				},
			},
			Next = { Id = "M2_6", Line = "Tiny is wondering which way Pip went." },
		},
		M2_6 = { -- H10: Slime Prince 2 (+ the Lv10 Goblin Brute Alt as before)
			Offer = {
				Npc = "Tiny",
				Before = "Dust made the princes grab hats and the porters grab huge sacks.",
				Lines = { All = {
					"Tiny: Will you calm two Slime Princes in the meadow?",
					"Tiny: From level 10, Brutes in the woods count too.",
				} },
			},
			Steps = {
				[1] = {
					On = "Self", Find = "That's a lot to carry alone.",
					Lines = { All = {
						"The fuss has eased. I hope Pip left room for his snack.",
					} }, Scene = "Nod",
				},
			},
			Next = { Id = "M2_7", Line = "I'll take the woods path when I'm ready at level 10." },
		},
	},
}
