-- Artisan_Ch2.luau : the Artisan Guild (Neutral) side's story fields of the shared chapter-2 mains M2_1 ~ M2_6 (GPT
-- build/codex/story_ch2_r1.md §2-3, 최종 검수 10/16; contract docs/design/quest_data_contract_2026-10-15.md §5). Story only: every
-- goal, reward, id, Requires, step count and order stay the base quest's in Config.StoryQuests.Defs. A Variants step becomes
-- def.Steps[i].Neutral, laid over the base step field by field (StoryQuestService stepOf / StoryNpcs.StepFor) - and it REPLACES
-- an earlier Neutral override, so M2_1 step 1 keeps the base quest's Neutral goal (Text + Obj EarnGold 45) here.
-- Mood: making new things, and leaving the crooked bits that matter.
return {
	Faction = "Neutral",
	Variants = {
		M2_1 = {
			Offer = {
				Npc = "Kit",
				Before = "Dust made the old cleaners gather tools along with the leaves.",
				Lines = { All = {
					"Kit: Will you earn 45 gold from monsters?",
					"Kit: Keep it for your work. I'll sort the tools here.",
				} },
			},
			Steps = {
				[1] = {
					-- the base quest's Neutral goal, unchanged (Config M2_1 Steps[1].Neutral)
					Text = "Gold from monsters %d/%d", Obj = { Type = "EarnGold", Source = "Monster", Count = 45 },
					On = "Self", Find = "The tool pile has leaves in it.",
					Lines = { All = {
						"A little gold for my work. That pond dust looks useful.",
					} }, Scene = "Nod",
				},
			},
			Next = { Id = "M2_2", Line = "Otto wants a closer look at the pond dust." },
		},
		M2_2 = {
			Offer = {
				Npc = "Otto",
				Before = "Dust made the pond cleaners gather every shiny bit they see.",
				Lines = { All = {
					"Otto: Will you calm four slimes by the pond?",
					"Otto: Let's see what settles when the bouncing stops.",
				} },
			},
			Steps = {
				[1] = {
					On = "Self", Find = "So many shiny bits in one pile.",
					Lines = { All = {
						"The dust settled. Tiny might know what we can use it for.",
					} }, Scene = "Nod",
				},
			},
			Next = { Id = "M2_3", Line = "Tiny is waiting by the fountain with his old knot." },
		},
		M2_3 = {
			Offer = {
				Npc = "Tiny",
				Before = "The box needs mending. Bright's crooked knot is staying.",
				Lines = { All = {
					"Tiny: Will you bring the dust to the fountain?",
					"Tiny: Shape it for the fountain, or leave it with the guild.",
				} },
			},
			Steps = {
				[1] = { On = "Self", Find = "A torn box. A carefully kept knot." },
				-- the fountain choice (no Npc): the Self minimal version (the Tiny peak line is added separately)
				[2] = {
					-- story_ch2_r1 §1 peak (최종 검수 10/16): Tiny says it at the fountain (On = his body), the card keeps the player's lines
					On = "Tiny", Find = "The box can wait. Her knot can stay.",
					Lines = { All = {
						"Bright and Tiny tied these. I can leave the knots alone.",
						"The fountain or the guild. Where shall this dust go?",
					} }, Scene = "Nod",
				},
			},
			Next = { Id = "M2_4", Line = "Tiny saved a snack for Pip. The road needs room." },
		},
		M2_4 = {
			Offer = {
				Npc = "Kit",
				Before = "Dust made the old cleaners stack supplies across our work road.",
				Lines = { All = {
					"Kit: Will you earn 60 gold from monsters?",
					"Kit: Then enter a town. Keep your work money safe.",
				} },
			},
			Steps = {
				[1] = { On = "Self", Find = "Tools, boxes... no room to work." },
				[2] = {
					On = "Self", Find = "Somewhere safe for my work money.",
					Lines = { All = {
						"My gold is safe. I'll leave room for someone else's work.",
					} }, Scene = "Nod",
				},
			},
			Next = { Id = "M2_5", Line = "The meadow slimes are sweeping boxes again." },
		},
		M2_5 = { -- separate from N1 (goals and rewards never merged)
			Offer = {
				Npc = "Otto",
				Before = "Dust made the old cleaners sweep boxes onto the work space.",
				Lines = { All = {
					"Otto: With your first skill, hit three monsters at once.",
					"Otto: Do it twice. We need space to work.",
				} },
			},
			Steps = {
				[1] = { On = "Self", Find = "Otto taught me a move for this." },
				[2] = {
					On = "Self", Find = "That's a box, not a pile of leaves!",
					Lines = { All = {
						"Space again. A small job can help the next maker too.",
					} }, Scene = "Clap",
				},
			},
			Next = { Id = "M2_6", Line = "Tiny is keeping a snack spot open for Pip." },
		},
		M2_6 = {
			Offer = {
				Npc = "Tiny",
				Before = "Dust made the hat fans and snack porters carry too much again.",
				Lines = { All = {
					"Tiny: Will you calm two Slime Princes in the meadow?",
					"Tiny: From level 10, Brutes in the woods count too.",
				} },
			},
			Steps = {
				[1] = {
					On = "Self", Find = "A small load might be easier.",
					Lines = { All = {
						"The fuss has eased. I wonder what Pip needs for his load.",
					} }, Scene = "Nod",
				},
			},
			Next = { Id = "M2_7", Line = "At level 10, I can take the woods path to find out." },
		},
	},
}
