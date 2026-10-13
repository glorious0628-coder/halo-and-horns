# 10/17 비공개 시험 준비 — 서버 몫 (게임성 개발 2, 2026-10-13)

근거: `docs/design/gameplay_plan_2026-10-13.md` §1-A·§5(개발 2), SPEC A23-127·A23-138·A23-156, 최종 검수 10/13 결정(휴가 XP·Enh70).
가지 `fix/test-prep-server`. 화면 몫은 게임성 개발 1 `fix/test-prep-client`(두 가지를 함께 합침).

## 바뀐 것

| # | 무엇 | 어디 |
|---|---|---|
| 1-A #2 | 대장간은 안 가진 새 무기를 팔지 않음: `Config.WeaponShop.Buy = false`(MaxSoldTier 3 그대로, 끼기·강화·팔기 그대로). 사려 하면 거절 + `Config.Text.WeaponDropOnly` "New weapons drop from monsters!"(info) | `ShopService` |
| 1-A #2 | 첫 King Slime(진짜 보상 처치, 연습 King·무임승차 제외) = 철 무기 T3 확정: `Config.Loot.FirstKingDrop = { Monster = "SlimeKing", Tier = 3 }`, `LootFlags.FirstKingWeapon`, 글 `Loot.Text.FirstKingWeapon` / `FirstKingEquip`. 첫 Prince(C2)와 같은 길(Loot Fx 목록, 더 세면 끼고 `Fx Upgrade`). 이미 가지고 있으면 기회만 씀 | `LootService` |
| 1-A #2 | M1_1 둘째 단계 "Use the Enhance Scroll on your weapon"(ShortName "Enhance", Guide "Bag"): 단계가 열릴 때 Otto가 Enh70 1장(새 단계 값 `GiveItem`, 저장 플래그 `Story.First["GiveM1_12"]` 먼저 → 계정당 한 번), 주문서를 무기에 쓰면(성공·실패 무관) 끝 = 이벤트 `ScrollUsed`(LootService가 `StoryQuestService.Event`로 알림, Past). M1_1 무기 안전망(GiveWeapon)은 방문(1단계 끝) 때 먼저 줌 → 맨손 저장도 주문서를 쓸 수 있음. 첫 사용은 +0 무기라 실패해도 떨어지지 않음 | `StoryQuestService`, `LootService`, Config M1_1 |
| 1-A #2 | 다음 목표: Buy=false·철 무기 없음·Lv≥5 → `Tutorial.Text.NextIronDrop`(개발 1의 글), GoalKind `"IronDrop"`; 그 글이 없으면 철 무기 줄 없음(옛 골드 줄은 Buy=true일 때만). 돌아가기 구역 `Config.Return.GoalZones.IronDrop = "SlimeMeadow"` | `QuestService` |
| 1-A #3 | 일일 셋째 칸: 거위 일일은 다음 알 사냥이 `Config.Quests.GooseWindow`(3600 s) 안이거나 진행 중일 때만. PvP(Hunt/Plunder)는 '사냥 아닌 칸' 강제 후보에서 뺌(보통 뽑기로만). S1·GW5 = 알 사냥 1번 | `QuestService`, Config |
| 1-A #4 | `Config.Levels.EarlyMult` 0.5 → 0.35(Lv10까지 1,381 → 962 XP). A23-14 '휴가만으로 Lv10 없음' 유지: Lv1~9 휴가 XP × 0.35/0.5(`Daily.VacationEarlyBase`), 받을 때 Lv9 끝까지만(2x 패스 포함, AddXP 상한) | Config, `QuestService` |
| 1-A #7 | 도감 페이지·반짝임은 지금 나오는 몬스터만 셈: `Config.CodexCounts(kind)` = 필드 보스이거나 스폰 수 > 0 (원거리 고블린·해골 궁수는 Mobs3Ranged 꺼진 동안 빠짐, 켜지면 다시 셈) | `CodexService` |
| 1-A #9 | Tiny(교차로 아이들 의자 옆 (24,0,12))·Rose(뿔 소굴 스폰 옆 (-18,0,424), 퀘스트 id는 "Smokey") 임시 NPC 몸: TownNpcs 표 뒤 `table.insert` | Config |
| 1-A #10 | 결정타 카드 꺼짐 `Config.Finisher.Kinds = {}`(카드 창 2-A #3 때 `{ SlimeKing, CaptainClatter }`) | Config |
| 1-A #11 | `Config.BuildLabel = "private-test 2026.10.16"` | Config |
| A23-138 | 보이는 이름: Smokey → Rose(Speakers, 퀘스트 글), Legendary Villain → Final Boss(Story.KaijuSurvived/SurviveTitle). 키·id는 그대로. 스킬 이름·마을 반응 줄·다음 목표 글은 개발 1 몫 | Config, `docs/script/` |
| A23-156 | 시험 서버 스위치 `Config.TestServer = { Enabled = true, Skills = { ZEnabled = true }, GooseEvery = 600, PassSales = true }` + `Config.ApplyTestServer()`(한 번만). 서버 Main.server.luau·클라 ClientMain(개발 1)이 맨 처음 부름. 사람에게 Z(PvPZX)는 꺼진 그대로. 시험 끝 = `Enabled = false` 한 줄 | Config, `Main.server.luau` |
| 개발 1 부탁 | GameState `PrivateServer`(bool, `Net.CreateAll`에서 `game.PrivateServerId ~= ""`) | `Net.luau` |

## 시험
- 새 시험 `tools/test_test_server.py`(+ `fixtures/test_server_offline.luau`): 스위치 값·한 번만·끄기·Main 순서·PrivateServer, 변이 12.
- 고친·더한 시험: a23_14(거위 창·PvP 강제 없음·휴가 상한 + 변이), loot(첫 King T3·Buy=false), weapon_first(새 M1_1 흐름), unarmed_start(방문 때 무기), codex(지금 나오는 몬스터), finisher·field_boss·first_ko_king(카드 꺼짐 + 창 켠 세계), town_npcs(Tiny·Rose), next_goal·onboarding(IronDrop), 이름 바꾸기 시험들.
- 내 가지 혼자서 실패가 정상인 것: `test_slime_prince`(첫 King 글 허용은 개발 1 47f4db54), `test_story_text`(main의 `Codex.Screen.Text.Kills`, 개발 1 몫). `test_skill_kit`은 개발 1 몫.
