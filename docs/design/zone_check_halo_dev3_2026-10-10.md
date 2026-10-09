# 빛 마을 점검표 — 게임성 개발 3 줄 (2026-10-10)

원본: `docs/design/zone_check_halo_2026-10-10.md`(담당 dev3 줄 #19·#43·#44·#45, 검수 결정 #55). 시험 숫자는 아래 각 줄.

## 끝난 것
| # | 한 일 | 시험 |
|---|---|---|
| 43 | 새 Halo·Horns 플레이어가 마을 문 쪽을 보고 태어남. `Config.Zones.HaloTown.SpawnLook = (0,0,-330)`, `HornsTown.SpawnLook = (0,0,330)`; `ZoneService.GetSpawnCFrame(zoneId, faceOut)`는 `faceOut == true`일 때만 SpawnLook을 보고(없는 구역은 구역 가운데), `PlayerService`는 **첫 임무가 열려 있는 동안**(`TutorialStep < Steps.Done`) 새 캐릭터를 그렇게 세워요. 여행(`ZoneService.teleport`)·첫 임무 끝난 사람은 그대로. ⚠ 점검표는 'TutorialStep == Forge'라고 썼는데 진영을 고른 직후 첫 스폰은 아직 step 0(Forge=3은 [I'm In!] 뒤)이라 '첫 임무 열림'으로 바꿨어요. | `py tools/test_spawn_look.py` 49검사, 변이 18/18 |
| 44 | 첫 임무 줄 `Text.Forge = "Go to Otto's Forge in the Crossroads"`(폰 이름 `To the Forge` 그대로, 새 알림·이름표 없음). | test_weapon_first 105·변이 41/41(+1) |
| 55 | 쉬운 영어: 새싹 맹세 → **The Sprout Promise**(폰 `Sprout promise`, 단계 `Make your promise to Bright/Smokey`, 안내 줄 `Make your promise.`), H6 `Look at the hero statues in Halo Citadel`. Hallie 고정 대사는 그대로(안내 2쪽·M1_4 첫 줄, M3_5 짝 줄). 글로서리에 4줄. OathH/OathR 마무리 줄(`Oath sworn!…`)은 #54(개발 2)가 고치는 줄이라 그대로 — 개발 2에 알림. | `py tools/test_halo_text.py` 51검사, 변이 16/16 · test_sprout_oath 72·29/29 |
| — | 안내자 첫 대화 4쪽 → 2쪽(ui_clutter_review, A23-99): 1쪽 임무 카드·2쪽 안내자 말버릇만(3·4쪽 삭제). | onboarding 860 · english 84·21/21 · test_halo_text |
| 19 | 서브 퀘스트가 3개를 넘어도 다 보냄(`SubRows`): `Config.StoryQuests.SendAllSubs = true`면 MaxSubs(3) 넘는 줄에 `More = true`를 붙여 함께 보내요. 마을 NPC 제안(`Factions` + 대화 상대 `Npc`가 있는 첫 카드)은 순위 2(진행 중인 서브와 같은 줄, 새것 먼저) — 다른 제안에 밀려나지 않아요. **기본 꺼짐**(`SendAllSubs = false` = 지금과 똑같이 3줄). | test_town_quests 507검사·변이 113/113 |

## 개발 1에게 (클라) — #19를 켜려면
1. `HUD`가 퀘스트 줄을 그릴 때 `e.More == true`인 줄은 **그리지 않기**(맨 위 MaxSubs개만 그림).
2. 퀘스트 창(`QuestBook` '진행 중')은 `HUD.QuestEntries()`로 `More` 줄까지 **전부** 보여 주기(지금도 받은 줄을 다 보여 주므로 그대로면 돼요; `More` 줄을 거르지 말 것).
3. 그 뒤 `Config.StoryQuests.SendAllSubs = true`로 켜기(개발 1의 Config 한 줄). 켜기 전까지는 서버가 지금처럼 3줄만 보내요.
- 안내 창(`Welcome`)은 `#Lines`를 따라가므로 2쪽으로 줄어도 코드는 그대로예요. 버튼 정리(큰 [I'm In!] + 작은 ▶, 'Later' 빼기)는 ui_clutter_review 그대로 개발 1 몫.

## 남은 것
- **#45 Lost & Found(C)** — ChoiceCard + Deeds 위에 만들기(Keep = 가이드 'OwnTown', Give back = 'Fountain'). 점검표는 10/24 계획. 검수가 순서를 정해 주세요.
