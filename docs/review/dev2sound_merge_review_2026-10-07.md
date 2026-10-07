# dev2-sound def36002 병합 검토

## 1) 결론
**고친 뒤 병합.** 서버 코드는 깨끗하고 시험도 모두 통과했습니다. 다만 대장간 단계(TutorialStep 3)를 다루는 클라이언트 코드가 main에 없습니다. 그래서 `origin/wtc-weapon-client`(dd1d4135)를 같은 라운드에 함께 넣어야 합니다. dev2-sound만 따로 main에 병합하거나 Studio에 동기화하면 안 됩니다.

## 2) 확인된 문제 (real=true)

| 위치 | 문제 | 고칠 것 | 담당 |
|---|---|---|---|
| **major**: `src/ServerScriptService/QuestService.luau:582-585`(수락 시 step 3), `:660`(tryTutorial이 step 3에서 아무것도 안 함), `:471`(RequestTutorial). main 클라이언트: `HUD.luau:4062-4079`(PinnedTap에 step 3 없음), `HUD.luau:3772-3792`(빔 없음), `QuestTarget.luau:426-431`(마커 없음), `Panels.luau:2220`(문구 틀림) | 새 플레이어가 [Accept]를 누르면 step 3이 되고 대장간 이동은 한 번만 실행됩니다. 이 이동이 거절되거나(전투 중, 이미 Travel 진행 중 등) 플레이어가 재접속·사망하면 고향 마을에서 step 3인 채로 남습니다. 서버는 이동을 다시 시작하지 않습니다. main 클라이언트에는 탭, 빔, 마커가 모두 없어 첫 무기와 첫 임무에 갈 길이 막힙니다. 가방에도 "after your first mission"이라는 틀린 문구가 남아 있습니다. | `wtc-weapon-client`(dd1d4135, `docs/design/weapon_first_server_2026-10-07.md` §4 a–e)를 같은 라운드에 병합한 뒤 Studio에 동기화. dev2-sound 단독 병합·동기화 금지 | 게임성 개발 2 (병합 순서는 게임성 개발 1과 맞춤) |

## 3) 반박된 것
- 검증에서 반박된 항목은 없습니다. 올라온 major 1건은 실제 문제로 확인됐습니다.
- 보고하지 않은 것 (봤지만 지금 게임에 실제 문제가 아닌 것):
  - `ZoneService.AllowMove`가 1초 동안 모든 이동 검사에 hop 거리를 더해 줍니다. `AntiCheat.Enforce=false`라서 로그만 남습니다.
  - `HopReach`는 아래에 땅이 없는 지점도 받아 줍니다. Displace도 같은 방식인데, 실제 맵에서 문제가 되는 경우는 만들지 못했습니다.
  - wtc-weapon-client의 폰 QuestBlockTap은 step 3에서 두 번 눌러야 합니다. 클라이언트 브랜치 쪽 일이라 이번 범위 밖입니다.
  - 첫 임무를 예전에 받은 옛 저장은 M1_1이 열려 있으면 Lunch1이 한 번 뜹니다. 설계상 허용 범위입니다.

## 4) 작은 것 (minor)
1. **Version을 올리지 않고 step 3 저장**: `DataService.luau:214-217`, `Config.luau:2010`, `QuestService.luau:583`.
   - 옛 빌드(현재 main, 공개 서버)가 이 저장을 읽으면 3을 99로 바꿔 다시 저장합니다. 그러면 첫 임무를 영영 건너뛰게 됩니다.
   - 고칠 것: 대장간 단계를 낼 때 `Data.Version`을 올리거나, 공개 체크리스트에 "모든 서버 종료, 옛 빌드가 이 저장을 읽지 않게"를 적습니다.
2. **모루가 없으면 step 3에 영구히 갇힘**: `QuestService.luau:582-585`, `ShopService.luau:220-233`, `:312-316`.
   - 고칠 것: `FORGE.Anvil()`이 nil이면 수락할 때와 tryTutorial의 step 3에서 `GrantFirstWeapon` + `setStep(STEP_GUIDE)`를 실행합니다.
3. **"시전 한 번에 한 번만 셈" 규칙이 깨짐**: `MonsterService.luau:1251-1255`.
   - `_castOf`가 마지막 castId 하나만 기억합니다. 그래서 필드 틱 사이에 평타나 Z가 끼면 같은 필드가 다시 셈됩니다. 왕 보스의 RewardMinHits 3을 행동 하나 적게 채울 수 있습니다.
   - 고칠 것: 플레이어마다 이미 본 castId를 집합으로 기억합니다.
4. **SK2 선택이 저장 안 됨**: `StoryQuestService.luau:33`의 SIDE에 `Guard`/`Take`가 없습니다(`Config.luau:2262-2263`).
   - changedMind가 건너뛰어져 LastSide가 갱신되지 않습니다.
   - 고칠 것: `Guard="Good", Take="Evil"` 추가.
5. **시험 빈틈: 떠난 플레이어의 늦은 필드 보고**: `SkillService.luau:501-506`.
   - fixture `skills_x_offline.luau:396-405`가 이 경우를 잡지 못합니다. 탐침 mutation이 통과했습니다.
   - 고칠 것: 첫 틱은 빗나가고 나중 틱이 맞는 퇴장 사례와 그 mutation을 추가합니다.
6. **시험 빈틈: 2단계 무기만 있고 1단계는 없는 플레이어의 [Accept]**: `QuestService.luau:582`와 `:623`의 판정이 서로 다릅니다.
   - 어느 쪽 동작이 맞는지 고정한 시험이 없습니다.
   - 고칠 것: 의도를 정하고 check와 mutation을 추가합니다.
7. **문서 어긋남 (코드 결함 아님)**: `Config.luau:203` 주석은 "Data v4"라고 하고, SPEC_ADDENDUM A23-69(155행)와 `stat_points_2026-10-07.md` §5-1은 "Version 3 → 4"라고 합니다. 1단계는 3을 유지하므로 문서를 고쳐야 합니다.

## 5) 시험 결과
- **오프라인 CI 전체**: 58/58 묶음 통과, 실패 0.
  - mutation 약 1,770개: 적용 안 됨 0, 놓침 0, 하네스 오류로 잡힌 것 0.
  - 증거 파일 54개가 커밋 내용과 일치합니다(차이는 CRLF, 경로, 시각뿐).
- **luau-compile**: src 105개 파일 모두 오류 0. 깨진 파일은 오류를 잡는 것도 확인했습니다.
- **주요 묶음**:

  | 묶음 | check | mutation |
  |---|---|---|
  | test_stats | 76 | 46/46 |
  | test_weapon_first | 105 | 41/41 |
  | test_onboarding | 871 | 없음 |
  | test_unarmed_start | 221 | 71/71 |
  | test_save_lock | 79 | 16/16 |
  | test_skills_x | 164 | 92/92 |
  | test_skills | 150 | — |
  | test_notify_sound | 73 | 64/64 |
  | test_town_quests | — | 96/96 |
  | test_first_weapon | — | 9/9 |
  | test_skill_learn | — | 16/16 |
  | test_item_seq | — | 15/15 |

  halloween, grudge, beta_basics, loot도 통과했습니다.
- **탐침 mutation**: 위 5·6번 시험 빈틈 2건은 놓쳤습니다. 3번(`_castOf`)은 luau로 재현했습니다(필드-평타 교차 시 5회, 기대 3회).
- **스탯 1단계(스위치 OFF)**: 전투력, 피해, HP, 저장 모두 동작 변화가 없습니다. Version은 3이고 Stats는 추가만 됐습니다.
- **소리 서버**: sound_spec §4-1의 경로표와 맞습니다. main 클라이언트는 모르는 키를 조용히 무시하고, 플레이어에게 보이는 한글도 없습니다.
- **병합**:
  - `merge-tree`를 origin/main(검토자들이 본 최신은 44806ddf/10ab3e7a)과 돌려 충돌이 없었습니다.
  - fb78af56 이후 main의 src 변경이 없으므로, 병합 결과의 src는 dev2-sound와 같습니다.
  - 병합 직전에는 현재 origin/main으로 `merge-tree`를 다시 돌리고 src 변경이 없는지 확인합니다.
