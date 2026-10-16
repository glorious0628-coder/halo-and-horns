-- Horns_Ch2.luau : the Horns side's story fields of the shared chapter-2 mains M2_1 ~ M2_6 (GPT build/codex/story_ch2_r1.md §2-2,
-- 최종 검수 10/16; contract docs/design/quest_data_contract_2026-10-15.md §5). Story only: every goal, reward, id, Requires, step
-- count and order stay the base quest's in Config.StoryQuests.Defs. A Variants step becomes def.Steps[i].Horns, laid over the
-- base step field by field (StoryQuestService stepOf / StoryNpcs.StepFor). Rose's Story NPC key is "Smokey".
-- Mood: a grand plan gets a little smaller, and we laugh together.
return {
	Faction = "Horns",
	Variants = {
		M2_1 = {
			Offer = {
				Npc = "Smokey",
				Before = "Dust made the old cleaners add my grand ribbon to their pile!",
				Lines = { All = {
					"Rose: Will you stop the fuss and help our crown shine?",
				} },
			},
			Steps = {
				[1] = {
					On = "Self", Find = "My grand ribbon is cleaning gear now?",
					Lines = { All = {
						"Grand plan done. Smaller ribbon next time.",
					} }, Scene = "Laugh",
				},
			},
			Next = { Id = "M2_2", Line = "Rose spotted more sparkle by the pond." },
		},
		M2_2 = {
			Offer = {
				Npc = "Smokey",
				Before = "Dust made the pond cleaners mistake my ribbon for a big leaf.",
				Lines = { All = {
					"Rose: Will you calm four slimes by the pond?",
					"Rose: My grand ribbon needs a break from cleaning.",
				} },
			},
			Steps = {
				[1] = {
					On = "Self", Find = "That leaf has a very fancy knot.",
					Lines = { All = {
						"A small sparkle. I may have called it a giant treasure.",
					} }, Scene = "Laugh",
				},
			},
			Next = { Id = "M2_3", Line = "Tiny wants a look at my very grand little sparkle." },
		},
		M2_3 = {
			Offer = {
				Npc = "Tiny",
				Before = "I tied Bright a crooked knot. She still wears it.",
				Lines = { All = {
					"Tiny: Will you bring your sparkle to the fountain?",
					"Tiny: You can give it to the fountain or keep it.",
				} },
			},
			Steps = {
				[1] = { On = "Self", Find = "Tiny's knot is crooked too." },
				-- the fountain choice (no Npc): the Self minimal version (the Tiny peak line is added separately)
				[2] = {
					-- story_ch2_r1 §1 peak (최종 검수 10/16): Tiny says it at the fountain (On = his body), the card keeps the player's lines
					On = "Tiny", Find = "Bright kept my bad knot!",
					Lines = { All = {
						"They tied each other's bands. Mine can be crooked too.",
						"The fountain can shine. Or I can keep this sparkle.",
					} }, Scene = "Laugh",
				},
			},
			Next = { Id = "M2_4", Line = "Tiny saved Pip a snack. A grand plan needs a friend." },
		},
		M2_4 = {
			Offer = {
				Npc = "Tiny",
				Before = "Dust made the old cleaners stack the road boxes like a throne.",
				Lines = { All = {
					"Tiny: Will you earn 60 gold from monsters on the road?",
					"Tiny: Enter a town after. Keep your grand plan's gold safe.",
				} },
			},
			Steps = {
				[1] = { On = "Self", Find = "A throne? Oh. Empty boxes." },
				[2] = {
					On = "Self", Find = "A captain can stop by town too.",
					Lines = { All = {
						"Gold safe. No throne yet. Pip still gets a snack spot.",
					} }, Scene = "Bow",
				},
			},
			Next = { Id = "M2_5", Line = "The meadow cleaners have made another grand pile." },
		},
		M2_5 = {
			Offer = {
				Npc = "Smokey",
				Before = "Dust made the old cleaners sweep my box into their grand pile.",
				Lines = { All = {
					"Rose: Hit three monsters at once with your first skill.",
					"Rose: Twice, captain. I'll save the victory pose for you.",
				} },
			},
			Steps = {
				[1] = { On = "Self", Find = "Skill first. Grand pose after." },
				[2] = {
					On = "Self", Find = "They even swept up the empty box!",
					Lines = { All = {
						"Two big moves. One very crooked victory pose.",
					} }, Scene = "Cheer",
				},
			},
			Next = { Id = "M2_6", Line = "Tiny is looking for Pip. My pose can wait." },
		},
		M2_6 = {
			Offer = {
				Npc = "Tiny",
				Before = "Dust made the hat fans and snack porters carry far too much.",
				Lines = { All = {
					"Tiny: Will you calm two Slime Princes in the meadow?",
					"Tiny: From level 10, Brutes in the woods count too.",
				} },
			},
			Steps = {
				[1] = {
					On = "Self", Find = "Even a grand captain needs help.",
					Lines = { All = {
						"The fuss is quieter. I'll leave a place beside me.",
					} }, Scene = "Wave",
				},
			},
			Next = { Id = "M2_7", Line = "At level 10, I'll look for Pip on the woods path." },
		},
	},
}
