# 깊은 광맥 길 (장인 2부, A23-215) — 서버 계약 (게임성 개발 2, 2026-10-16)

근거: SPEC A23-215, `build/codex/craft_curve_r1.md` §2 (DeepMoonShard: 유적 안쪽 보호된 광맥 코스, 1개 확정, 경로 2~3종 순환, 실패 시 재료 소멸 없음, 기다리는 타이머 X).

## 무엇
- 데이터: `src/ReplicatedStorage/Shared/Quests/DeepVein.luau` — 길 3개 DV1(north)·DV2(south)·DV3(deep), 차례로(A→B→C→A…).
- 부탁 NPC: **Pip**(최종 검수 10/16: 바이블의 폐허 적재 경사로 고블린 운반꾼, 중립, 새 인물 0) — Pip 몸은 하나(Daily 묶음, 지금 (700, 0, 30)). Lv25, `Config.Features.Crafting` 켜졌을 때만, M1_4 뒤.
- 한 판: 표시 3개(Near 12, 순서대로) → 경비 해골 기사 3마리(개인, 한 번에 한 마리, 경비 자리 40 안에 서 있을 때 나옴) → 광맥 Timing(5중 3, 실패 = 그 자리 다시) → **Deep Moon Shard 1개, 귀속 X(거래 가능)**.
- 쓰러지면 **지금 단계만 처음부터**(지난 표시는 남음, 최종 검수 10/16·A23-203). 가진 것 잃음 없음(조각은 끝에만).
- 하루 5개(매일 부탁)에 안 셈, Done 안 됨. **처음 한 번만 Pip에게 수락**, 끝나면 다음 길이 바로 시작(Run.Chain, 최종 검수 10/16). Pip 몸은 숲 가장자리 그대로.

## 엔진(StoryQuestService) 새 칸
| 칸 | 뜻 |
|---|---|
| `def.Run = { Group, Turn, Of, Chain }` | 같은 Group의 def가 차례로. Chain = 끝나면 다음 차례 def를 바로 시작(부탁 없이). `data.Story.Runs[Group]` = 끝낸 판 수(새 저장 칸, 빈 표가 기본), `Runs % Of + 1 == Turn`인 def만 부탁됨 |
| 단계 `Spawn = { Kind, Spot, Radius }` | Kill 단계(`Obj.Personal = true`)가 열려 있고 플레이어가 Spot의 Radius(기본 40) 안이면 `MonsterService.SpawnPersonal(player, Kind, { Near = true })` 한 마리. 죽으면 다음 틱에 다음 한 마리, Count 차면 끝. 단계가 끝나거나 없어지면 남은 것 `RemovePersonal` |
| `def.ResetOnKO = true` | `PlayerService.CharacterDied` → 그 퀘스트의 지금 단계 P·T 0(St 그대로), 경비 지움, 그 단계 Near.Stay·열린 Timing 창 지움 |
| `Reward.FreeItems = { { Id, N } }` | 귀속 없이 줌: `LootService.GrantItem(..., "RewardFree")` = 가방 가득해도 들어감(Reward처럼), 귀속만 X |

## 개발 1(화면) 몫
- 새 화면 없음: 줄·표시(Guide = 표시·경비·광맥 자리)·Find 말풍선·Timing 창은 기존 그대로.
- Pip 몸 그대로. Pip을 폐허 입구 보관대로 옮길지(M3_7 수레 이야기)는 최종 검수 결정.
- 자리(표시·경비·광맥) = 임시 좌표. 지도에 StoryLandmark 태그(Spot = `DV1Mark1` …)로 옮김 — 메인 반영/지도 때.

## 시험
`py tools/test_deep_vein.py` (변이 포함). `tools/test_quest_data.py`가 `Reward.FreeItems`를 앎.
