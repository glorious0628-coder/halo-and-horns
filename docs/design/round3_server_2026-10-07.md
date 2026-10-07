# 3회차 아이디어(처음 10분) — 서버 몫 + 소리 서버 일 (게임성 개발 2, 2026-10-07)

근거: `docs/design/ideas_first10_2026-10-07.md` §3·§4(개발 2 1~4번), `docs/design/sound_spec_2026-10-07.md` §4-1(개발 2의 서버 일).

## #1 퀘스트 줄 숫자는 한 번만
- `StoryQuestService.rowFor`: ShowProgress가 켜진 줄(목표 > 1, [Claim] 아님)은 Text에서 '%d/%d'를 뺀다
  ('King Slimes 0/2 0/2' → Text 'King Slimes' + HUD가 Progress/Target). '%d/%d s'(초) 줄은 단위를 `ProgressUnit = "s"`로 보낸다
  → **개발 1: HUD가 숫자 뒤에 ProgressUnit을 붙이면 '5/10 s'.**
- S0 1단계 Start 줄: "A King Slime swallowed a shard! Beat it to free the shard."('I' 없음).

## #5 0점이어도 대답하는 선택
- 반대 편을 골랐는데 깎을 점수가 없으면(A23-58 바닥 0 그대로) 숫자 없는 한 줄 + 기울기 줄:
  "Hallie: Hmm… not very angel-like! Your shard leaned to the dark." / "Magpie: Too nice for a devil! Your shard leaned to the light."
  (`OffSideHaloZero` / `OffSideHornsZero` + `LeanEvil` / `LeanGood`).

## 소리 서버 일 (sound_spec §4-1)
- **Fx `Choice` { Option = "Good" | "Evil" }**: 이야기 선택을 고르는 순간 고른 사람에게(점수가 바뀌든 안 바뀌든, 장인 A = Good, B = Evil).
  → **개발 1: Purify / Devour 소리는 이것으로만**(명예·악명 값이 바뀔 때가 아님).
- **Notify `Sound` 필드**: `Net.Notify(player, text, kind, duration, sound)`·`NotifyAll(…, sound)` → payload `Sound`.
  "None" = 소리 없음, 없으면 지금처럼 kind로(bad → Deny, reward → QuestDone). 경로:
  | 일 | Sound |
  |---|---|
  | 첫 임무·추가·일일·자동 지급·이야기·게시판 완료 | QuestDone (같은 순간의 다음 줄들은 None) |
  | 거위 보상·일일 상자·휴가 보너스·전쟁 상자·괴수 몫·PvP 현상금 | GoldPickup |
  | 새 칭호(NewTitle) | RankUp |
  | 무기 구매·장착(대장간, 가방) | Equip |
  | 물약 구매 | Spend |
  | 강화·강화 옮기기 | ScrollSuccess / ScrollFail만 |
  | 약탈당함·자루 잃음·유령에게 잡힘·PvP 지역 들어감·이동이 맞아서 끊김·괴롭힘 알림 | None(Deny 아님) |
  | 그 밖의 거절('bad') | (필드 없음 → Deny) |

## #2 안내자 1쪽 = 할 일 카드
- `Config.Tutorial.Welcome[진영].Lines[1]` = "Slimes blocked the road! Beat 5. No weapon yet, so use your fists!\nThen the Blacksmith gives you your first weapon!"
  (검수 문구 그대로, 두 문장 두 줄). 말버릇 줄은 2쪽, 옛 4쪽(할 일)은 1쪽과 같아서 뺐다(4쪽 그대로).

## #3 'Guide' 대신 안내자 이름
- 고정 줄: "Tap here: first quest from Hallie"(Magpie / Kit), 짧은 이름 "Meet Hallie". 진영·직업이 바뀌면 목록을 다시 보낸다.
- `test_story_text` 규칙 10: 짧은 이름의 %s는 검사기가 아는 값(안내자 이름)만 허락, 가장 긴 이름으로 14자 검사.

## #7 첫 임무 슬라임은 새싹 가까이 (ideas_first10 §3-#7)
- `Config.SpawnSpread.Tutorial = { StarvedThreshold = 3, MinDist = 10, MaxDist = 18, Extra = 3 }`.
- 사냥꾼 = TutorialStep 2(Steps.Quest)로 초원(GuideZone)에 서 있는 사람(`MonsterService.tutorialHunter`).
- 슬라임(Tutorial.Monster)이 새로 생길 때(`pickSpawnPoint`):
  - 근처 30스터드에 몬스터가 3마리 미만인 사냥꾼을 먼저 고른다. 동점이면 Rookie, 그다음 낮은 레벨, 그다음 근처 몬스터가 적은 사람.
  - 사냥꾼이면 10~18스터드 거리, 초원 가운데를 향한 반원에 놓는다. 시도는 12번이다.
    - 이유: 도착 지점 Spawn (220,0,0)이 생성 가능 구역(SpawnInset 25 → X ≥ 225) 경계 바로 밖이다. 원 전체로 놓으면 시도의 반 이상이 버려졌다.
    - 아이도 도착하면 가운데를 본다(GetSpawnCFrame lookAt).
  - 다른 사람·다른 몬스터(왕 슬라임 포함)는 A7-1 그대로다(2마리 미만, 18~28, 6번). 고르는 순서만 위와 같다.
- 목표 수(`wantedTargets` → targetCount·cappedTargets):
  - 초원 사냥꾼 1명마다 슬라임 목표 +3, 최대 Count × MaxZoneMult(24).
  - 혼자 있는 서버에서는 12 → 15가 된다. 다음 재평가(5초)에 3마리가 바로 생긴다.
  - 첫 [Claim]으로 사냥이 끝나면 다음 재평가부터 보너스가 사라진다. 살아 있는 슬라임을 없애지는 않는다(A3-M2 그대로).
- 확인할 것(개발 1, Studio 1번): 도착 뒤 첫 처치까지 10초 이하.

## 검사
- `tools/test_town_quests.py`: 초 줄 Text·ProgressUnit, Fx Choice(고를 때·0점일 때), 완료 줄 QuestDone 1번 + 다음 줄 None, 0점 반응 줄. 변이 77/77(+6).
- `tools/test_notify_sound.py`(새): 경로표 36줄 + 래퍼 6개 + Net payload + Fx Choice, 변이 37/37.
- `tools/test_onboarding.py`: 고정 줄 'Tap here: first quest from Hallie' / 'Meet Hallie'. `tools/test_english.py`: 1쪽 카드, 말버릇 2쪽.
- `tools/test_tutorial_spawn.py`(새, #7): 사냥꾼 판정, 목표 +3·+6·상한 24·[Claim] 뒤 사라짐, 10~18 반원·입구 100/100·12번 시도, 고르는 순서(두 순서 모두). 검사 45개, 변이 24/24.
- `tools/test_halloween.py`: 몬스터 수 하네스가 wantedTargets와 TUTORIAL·TUT_SPAWN을 함께 잘라 온다(추출 경계만 바뀜).
