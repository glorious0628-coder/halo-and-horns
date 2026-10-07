# 게임성 개발 2 인계 (2026-10-07 저녁, 계정 바꾸기 전)

## ★ 최신 (2026-10-07 밤, 앱 재시작 뒤 이어서 함) — 아래 절들은 그 전 기록

| 일 | 상태 | 가지 / 커밋 |
|---|---|---|
| A23-71 남은 일 S8·S9·S11·S13·S14·S16 | **main에 병합됨**(개발 1, 33bc5f4) | dev2 5c71430 |
| **A23-74 무기 먼저**(수락 → 대장간 단계 3 → 첫 무기 → 초원, 옛 저장 맨손 안 남김) | 오프라인 55개 통과, **병합 요청 보냄**(검수·개발 1) | 가지 **dev2-weapon** 49d2744 (origin/main 위, Data v4 없음). 계약 `docs/design/weapon_first_server_2026-10-07.md` |
| SKL-3 마무리(X 스킬 서버 + 시험 `tools/test_skills_x.py`, SK1·SK2, 다음 목표 New skill) | **검수 통과**, 개발 1 병합·Studio 반영 대기 | dev2 94c3870 |
| A23-69 스탯 1단계(스위치 꺼짐) + 소리 서버 몫 | 검수 검토 → 고칠 것 4개를 dev2-sound에서 고침: ① KingDefeat Contributors(PaidUserIds) ② 환불 Fx Thief = 뺏은 사람 ③ 장판 늦은 Released = 끝날 때 최다 마릿수 한 번 ④ **저장 버전 3 그대로(Stats는 더하기 필드), SanitizeStats A–Z 보존** | 가지 **dev2-sound** (CI 뒤 병합 요청) |
| A23-69 2단계 | 검수 지시로 **아직 시작 안 함** | — |

- 가지 정리: `dev2` = a698787(스탯 1단계)까지. `dev2-sound` = dev2 + 소리 묶음 + 검수 고칠 것 4개 → 이 끝 하나로 병합 요청. `dev2-weapon` = main 위 무기 먼저(따로 병합). `dev2-skl3-wip`은 dev2에 다 들어가서 더 안 씀. 시험용 worktree: `Game-dev2-ci`(전체 CI), `Game-dev2-mtest`(합쳐 보기·증거 커밋용).
- 증거 정리 요령: CI 뒤 바뀐 증거 중 **경로·시간만 바뀐 것**(작업 폴더 이름이 다른 것)은 올리지 않는다. 상태·검사 수·변이·sourceSHA256·계약 글이 바뀐 것만 Game-dev2로 복사해 커밋한다.
- 문서: `docs/design/skills_server_2026-10-07.md` §3-2(X 계약), `docs/design/stats_server_2026-10-07.md`(스탯 1단계, 저장 버전 3 그대로: 서버 종료 필요 없음), `docs/design/sound_server_2026-10-07.md`(소리 계약).
- 새 시험: `tools/test_skills_x.py`(X 스킬·몬스터 고리·MP·이동 허용), `tools/test_stats.py`(스탯 1단계). `tools/test_notify_sound.py`는 소리 경로표 + Plunder/Crown/KingDefeat까지 본다.
- 다음 큐(검수 확인 필요): A23-69 2단계(10/16–17: StatService·피해·HP·PvP) 또는 검수가 정하는 다른 일. 소리 묶음 병합 요청이 먼저.
- 시험 팁(오늘 겪은 것): CI 증거는 **복사한 뒤에** `git -C ../Game-dev2-ci checkout -- docs/art` 할 것(먼저 지우면 다시 돌려야 함). Python으로 고칠 때는 스크립트를 Write로 파일에 쓰고 실행(Bash heredoc은 `\n`을 바꿔 버림). 변이 문구가 소스와 맞는지 한 번에 보는 도구는 scratchpad의 check_mutations.py 같은 것을 다시 만들면 된다(모든 `tools/test_*.py`의 MUTATIONS가 정확히 1번 맞는지).

다음 계정의 게임성 개발 2는 이 파일 → `AGENTS.md` → 검수 목록 `docs/design/skill_unlock_impact_2026-10-07.md`(eb078dd) 순서로 읽고 시작한다.

## 0. 자리

| 무엇 | 어디 |
|---|---|
| 일하는 곳 | worktree `C:/Users/glori/Documents/Roblox/Game-dev2`, branch **dev2**. 서버만 고친다(Studio·place/·sync·playtest 금지) |
| 하다 만 SKL-3 | branch **dev2-skl3-wip** (788f5d4, origin에 push). dev2에는 아직 안 합쳤다 |
| 전체 시험용 | worktree `C:/Users/glori/Documents/Roblox/Game-dev2-ci` (detached, `build/luau_cli_0_741` 복사본 있음). 커밋한 상태로 전체 시험을 따로 돌리는 곳이라, 그동안 Game-dev2에서 계속 고칠 수 있다 |
| 병합 | 개발 1이 dev2를 main에 병합한다. 2026-10-07 저녁 기준 **940fb2e까지 모두 main에 있다**(main 1c5e91e) |

## 1. 끝난 것 (dev2, push 완료, main에 병합됨)

| 커밋 | 내용 |
|---|---|
| 968598b | 소리 3차(도구 `tools/sfx_game.py`·모양 시트). 소리 일은 이제 '소리 만들기' 세션 몫이다. 도구·시트는 지우지 말 것 |
| 8a191d6 / 5adca06 / 0f6de17 | 단·복수 `Config.Plural` / 퀘스트 ShortName(14자 이하) / 이름표 글꼴 `Config.Fonts` |
| 324055a | A23-68 서버: 수락 3초 뒤 초원 입구로 이동, 첫 임무 동안 초원 입구 부활, Folded, 퍼널 단계 |
| 2c5e84e | 3회차 서버 #1·#2·#3·#5 + 소리 서버 일(Fx Choice, Notify Sound 경로표) |
| 54c1041 + d939b14 | A23-70 잃어버린 도시락(Lunch1, 0점, Reply 줄) |
| daebdaf | 3회차 #7: 첫 임무 슬라임이 새싹 가까이(SpawnSpread.Tutorial, 사냥꾼 1명당 목표 +3) |
| fd910c2 | 3회차 #6: 후광·뿔이 머리카락·모자 위로(markFloor, RankScale R1 ×1.4 / R2 ×1.2, MaxRise 1.0) |
| a95e9c6 | 위 둘과 main 48b631a 병합(c15b67b)의 증거 |
| 9e4509d / e4841e6 / 940fb2e | **A23-71 서버**(스킬 Q Lv5·Z Lv15·X Lv25) / 물약 시험 Config 자르기 고침 / 증거 |

A23-71에서 한 것:
- `Config.SkillSlotsFor(level, rebirths)`, `Config.SkillLearned(slots, level, rebirths)`
- 저장: `SkillSlots` 기본 0, `SkillsA71` 깃발. 예전 저장은 한 번만 레벨로 다시 센다.
- Lv5 전에는 Q 원격·옛 Release 원격·자동 모두 Q가 안 나간다.
- 'Skill hits' 일일·추가와 J4는 스킬을 배운 뒤에만 나온다. 미완료 Release는 접속 때 다시 뽑는다(보상 유지).
- M1_3·M2_5 앞에 'Lv5 · Learn your first skill (now Lv%d)' 단계, N1은 Lv5부터.
- S0 시험 b는 그대로다(사용자 정정: **(A) 맞음**, 자동 전투는 첫 스킬 뒤). Lv5 전에는 줄 끝에 ' · Skills come at Lv5'.

## 2. 하다 만 것: SKL-3 (`dev2-skl3-wip` 788f5d4)

**들어간 것(컴파일만 확인, 시험 없음).** XEnabled = false라 게임에서는 아직 안 보인다. MonsterService 고리 3개는 개발 1 OK(10/07)를 받았다.
- SkillService:
  - X 모양 Roar·Field·Hop
    - Field: 1초 틱, 한 사람 하나, 끝나는 조건, Fields 꺼짐이면 한 번에 터짐
    - Hop: HopReach, TooHeavy·CantHop, AllowMove, Fx Hop
  - Guard(`GuardOf`, 속성 GuardPct/GuardUntil), MP 훔치기 시전당 20, 도발, 느리게
  - 시전 번호(castId), X 자동 규칙, AutoCast X→Z→Q
  - Fx: Skill에 Statuses·Craft·To, SkillTick, SkillEnd
- MonsterService: `Taunt`, `Slow`(NATURAL.Pace), `DamageMonster(…, castId)`(시전당 `_hits` 1번), `HopReach`(+DISPLACE.HopDrop)
- 그 밖의 서버:
  - CombatService: 몬스터 피해에만 Guard, `Kit.HitMonster` castId
  - VitalsService.AddMana, ZoneService.AllowMove
- 이야기와 목표 줄:
  - SK1·SK2 서브. `Requires.Skill`(그 칸 플래그가 켜지고 칸이 열림)일 때 받는다.
  - SkillHit `Slot` 거르기.
  - QuestService '다음 목표 · New skill at Lv%d'(GoalKind "Skill").

**남은 일 (이 순서로):**
1. 공용 시험 세계 `tools/fixtures/dev2_combat_world.luau`에 가짜 함수를 더한다:
   - MonsterService: Taunt, Slow, HopReach(`w.HopReach`로 정함). DamageMonster는 5번째 인자 castId도 기록한다.
   - VitalsService.AddMana
   - ZoneService: ZoneChanged 신호, AllowMove, `w.ZoneOf`
   - KaijuService.GetState: `w.KaijuOf`를 읽게 한다
   - GrudgeService.HasSack
   - **ZoneChanged가 없으면 SkillService.Start가 경고를 내서 'no service warnings' 검사가 실패한다.**
2. `tools/fixtures/skills_offline.luau` + `tools/test_skills.py`에 묶음을 더한다. 계획:
   - **x roar:** 12칸 x2, 16칸 도발 4초, 내 Guard 40%·6초, 빛 동료 20%. 뿔은 MP +5×맞힌 수, 상한 20. 대장장이는 Anvil Craft만. Taunt 꺼짐.
     - Guard 확인: `Combat.DamagePlayer(p, 10, nil, false, "Slime")`이면 6, "Kaiju"·사람 공격자는 10, 6초 뒤 다시 10. 더 큰 Guard가 이김. 부활하면 지움.
   - **x field:** 겨냥 몬스터 자리에 r12, 틱 5번 x1.5, 모든 틱이 같은 castId, Released 1번, Slow(0.5, 1.5초).
     - 진영: 빛은 원 안 동료 Guard, 뿔은 MP 2×맞힌 수(합계 20).
     - 끝남: 죽음·지역·직업 바꿈·괴수(틱 때)·나감(SkillEnd 없음)·새 장판(CD를 줄여서 시험).
     - 사람은 안 맞음. Fields 꺼짐이면 x7.5 한 번에 3초 느리게.
   - **x hop:** Fx Hop(To = 뒤 10, T 0.25)은 시전자에게만, AllowMove(p, 12, 1), 바람 r7 x3·밀기 6.
     - 거리: HopReach 5면 To 5, 2.5면 CantHop(MP·재사용 그대로).
     - 거절: 자루·괴수(Siren/Active)는 TooHeavy. MoveSkills 꺼짐이면 바람만.
     - 진영과 자동: 빛은 착지 12칸 동료 Guard 4초, 뿔은 MP. 조련사 Craft BigSlime. 자동은 절대 안 씀.
   - **x auto / 잠김:** 전사 auto는 X(16칸 3마리) → 0.5초 뒤 Z → Q. LowHP 50% + 10칸 1마리면 X. 마법사 장판 자동은 2마리 이상. XEnabled 꺼짐이면 'X:Locked'.
   - **몬스터 고리(진짜 코드):** 'displace' 묶음이 이미 `local DISPLACE = {`~event monsters를 잘라 오므로 Taunt·Slow·HopReach가 들어 있다.
     - Taunt: 보스·개인 몬스터·다른 사람의 도발 중이면 거절.
     - Slow: 보스는 0.75, 더 센 느리게가 이김.
     - HopReach: 물·벽·지역 끝·높이 차 8 넘음.
     - DamageMonster castId와 `function NATURAL.Pace(`를 따로 잘라 시험한다. aiStep 도발은 정적 검사로 본다.
   - **이야기(town_quests):** SK1은 ZEnabled 꺼짐이면 안 받음. 켜짐 + SkillSlots 2면 받음. Slot "Q"는 안 셈, "Z"·2마리면 셈. SK2는 분수 → 선택(빛 Guard 명예 +1) → X 3번.
   - **다음 목표(onboarding):** 'New skill at Lv%d'. 단, 아래 3번 D6과 먼저 맞춘다.
3. 다음 목표 문구를 검수 결정 **D6/S16**('Next goal · Lv%d: first skill + Iron weapon (now Lv%d)')과 맞춘다. WIP의 NextSkill과 하나로 정리한다.
4. 클라 계약을 `docs/design/skills_server_2026-10-07.md` §3-2로 쓰고 개발 1·이미지 개발에 보낸다:
   - Fx 'Skill' { Shape = Roar/Field/Hop, Statuses = { Guard = { { V, Pct, Sec } }, Taunted, MP }, Craft, CraftSec, To, Life, Tick }
   - 'SkillTick' { UserId, Slot, Center, Radius, Hits, Total, Statuses }
   - 'SkillEnd' { UserId, Slot, Why }
   - 'Hop' { To, T }(시전자만)
   - SkillPress Result에 "TooHeavy"·"CantHop"
   - 속성 GuardPct/GuardUntil(서버 시각)
5. 통과하면 `git merge dev2-skl3-wip`(Game-dev2에서 dev2로) → CI 전체 → 증거 → push → 개발 1에 병합 요청.

## 3. 다음 큐 (검수가 정한 순서)
1. **A23-71 남은 것** (검수 목록 eb078dd. D1은 사용자 정정으로 (A) = 지금 그대로):
   - S8: M1_3의 지금 Start 줄을 SkillHit 단계로 옮기고, 새 Start("Grow to Lv5 to learn your first skill!")를 단다. Level 단계에 `Guide = "SlimeMeadow"`.
   - S9/D3: Lv1-4 일일 셋째 칸을 `(Id, Monster)`로 중복 거르기 → 왕 슬라임 3 + 슬라임 12-15 + 골드. T3(a23_14) 기대값도 고친다.
   - S11: BoardService.cardsOf에서 저장된 J4를 거르고 T5를 더한다(Board.Enabled = false라 급하지 않음).
   - S13/D5: `Config.Analytics.Steps`에서 FirstSkillHit를 AutoUnlocked 뒤로 옮긴다. TelemetryService 예비 목록과 T7(metrics)도 같이.
   - S14/D6: Help 문구 'Your first skill comes at Lv 5. …'(주제당 4줄 한도).
   - S16/D6: 다음 목표 문구(SKL-3 WIP와 함께, 위 2-3).
   - S15(선택): Skills.Text 정리(개발 1과 함께).
   - S12는 (A)라 할 일 없음(S0 끝 = 스킬 명중).
2. **SKL-3 마무리** (2절).
3. **A23-69 스탯 찍기:** 10/11–12 1단계, 10/16–17 2단계(`docs/design/stat_points_2026-10-07.md` §7). 날짜가 겹치면 PET-4·6, WPN-3, GOOSE-Q를 약 2일 미룬다.
4. 그 뒤: 아이디어 ②·①(10/17 뒤), PET-2·4.

## 4. 시험하는 법
- 한 묶음: `py tools/test_<이름>.py`(변이 포함). `--no-mutations` 결과는 커밋하지 않는다.
- 시험이 도는 동안 **같은 worktree의 src/·fixture를 고치지 않는다**(sourcesChangedDuringRun으로 실패).
- 여러 묶음을 4개씩: Game-dev2에서
  ```bash
  mkdir -p build/testlogs && printf '%s\n' skills town_quests a23_14 onboarding | xargs -P 4 -I{} bash -c 'timeout 2400 py tools/test_{}.py > build/testlogs/{}.log 2>&1; echo "exit=$?" >> build/testlogs/{}.log'
  ```
- 전체(CI): 커밋한 뒤 `git -C ../Game-dev2-ci checkout --detach dev2`, 그다음 Game-dev2-ci에서 위와 같이 실행한다.
  - 대상은 `tools/test_*.py` 전부다. 단 `costume_physics`, `skill_binding_studio`는 뺀다.
  - 2026-10-07 기준 53개, 모두 통과(핼러윈 포함).
  - 끝나면 `git -C ../Game-dev2-ci checkout -- docs/art`으로 되돌린다.
- 증거 파일:
  - 시험이 바뀐 묶음의 증거만 커밋한다. 커밋한 스냅샷(CI)에서 만든 것을 쓴다.
  - 그 밖에 다시 쓰인 증거는 `git checkout -- <파일>`로 되돌린다.
- 멈춘 시험이 남긴 프로세스는 PowerShell로 정리한다: `Get-CimInstance Win32_Process | ? { $_.CommandLine -like '*Game-dev2*' -and $_.CommandLine -notlike '*Game-dev2-ci*' }`의 luau·py·xargs.
- Bash heredoc 안의 `\t`·`\n`이 진짜 탭·줄바꿈으로 바뀔 수 있다. 시험 문자열은 Edit/Write나 .py 패치 스크립트로 쓴다.

## 5. 주의할 점
- 서버만 고친다. 클라 파일은 개발 1·이미지 개발 몫이다.
  - **MonsterService는 개발 1 파일**이라 고치기 전에 알린다.
  - SKL-3 고리 3개(+HopReach)는 OK를 받았다.
- 커밋: `git commit -m "…" -- <경로>`(pathspec)
  - push는 dev2(또는 작업 가지)로 한다.
  - main을 받을 때는 `git merge origin/main`을 쓴다(rebase 금지).
  - 공유 트리(Game) 규칙은 AGENTS.md hard rule 5를 본다.
- **검수에게 보내는 메시지는 앱 경로가 확실하다:** SendMessage `to = "local_e41a9de6-2228-43b3-8705-67a39ea96659"`. 이름("모든 것 검수") 경로는 막히거나 늦게 갈 수 있다.
- **Config를 일부만 잘라 쓰는 시험**은 함수를 옮기거나 이름을 바꾸면 추출기도 같이 고친다:
  - test_potions: Config.Skills + SkillSlotsFor
  - test_halloween: MonsterService의 wantedTargets·TUTORIAL·TUT_SPAWN
  - test_rank_marks: markFloor·MARK_HEAD_SLOTS
  - test_tutorial_spawn
  - skills 'displace' 묶음: DISPLACE ~ event monsters
- Luau local(200 한도): SkillService 51, MonsterService 약 140, CombatService 77.
- dev2에 닿는 사용자 결정:
  - A23-71(5/15/25)
  - S0 (A)(자동 전투는 첫 스킬 뒤)
  - A23-69 스탯은 베타에 넣되 끌 수 있게(FeatureOn "StatPoints")
  - 친구 수만큼 보상 금지(idea_backlog에서 뺌)
