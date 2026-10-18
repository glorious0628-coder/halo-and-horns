# 게임 플레이 — 상태

## 10/18 정리 (사용자 "우선 이거 정리하자" — 멈춤)
- 11판 ③은 안 함. 봇 준비는 끝(flow.py: LOSE1 재대결 KO→Fizzby 거리, 11 가방→Neighbor 대화, 12 물속 무기·F, 13 서서 칼 손에; water_find.lua·weapon_state.lua) — 아직 실제 Play에선 안 돌려 봄. Studio 안 엶.
- 다음 판 = 최종 검수 'sync 62b7b48e'(또는 뒤) 신호 → ③ 성문 이웃·물속 무기·칼 손에·재대결 KO, ④ 대화 상자(병합 뒤), ⑤ 직업별 전체 판.

## 10/18 — 다시 시작, 'sync 62b7b48e' 신호 기다림
- main 62b7b48e = 성문 Neighbor(빛 M1_3 Return bag) + 재대결 KO Fizzby 옆 + 물속 무기 숨김(A23-231) + 칼 손에(A23-232).
- **12판 계획(빛 전사, 새 저장, 패스 끔):** `FAST=1 NOSHOT=1 LOSE1=1 py -X utf8 flow.py Halo Warrior 0` — 0~7 그대로 → 8 재대결 한 번 일부러 짐(공격 안 함) → 깬 곳·Fizzby 거리 → 다시 가서 이김 → 10 M1_3 선생님·슬라임 → **11 가방 줍기 → Neighbor(12,0,-378) G → 대화 글·사진 → 다음 목표 'Learn a skill'** → **12 물: 가까운 깊은 물 찾기(water_find.lua) → 헤엄 중 무기 안 보임(weapon_state.lua: 부품 투명 1)·F 눌러 공격 안 나감 → 나오면 다시 보임** → **13 서서 7초 = 칼이 손에(RightGrip·StowWeld 없음)**. 그다음 `pose.py idle warrior` 사진.
- 순서: 신호 → 화면 신청('전달함, 시작') → PlayTest 열기·sync → 판 → Play 멈춤 → 창 닫기 → '끝' + 보고서 r12.

## 10/17 밤 늦게 멈춤 (사용자 "정리해줘 내일 하자" — 최종 검수가 다시 부름)
- **지금:** PlayTest Studio 닫힘(저장 안 함), 봇 안 돎. 공유 폴더 = origin/main.
- **11판 결과(src 5b90afa9, 빛 궁수, 보고서 `docs/review/playtest/2026-10-17_r11.md`):**
  - 앞부분: 두 번째 King 짐(물약 3병, King 54 남김) — 봇이 쿨다운 사진 찍느라 쉰 탓(정정됨). 쿨다운 중 키 1 = 슬롯 어두운 막만, 다시 눌러도 반응 없음(개발 1로 넘어감).
  - **① 다시(사진 없이·F 연타)는 멈춤 지시 전에 이미 끝남:** 판 A 이김 27.8초·실제 2병·최저 52/156, 판 B(1병만) 이김 32.2초·최저 25/156. 둘 다 재대결 Lv4·HP 156·Attack 17(전사·마법사는 Lv5). 기록 `docs/art/verification_2026-10-17/playtest/r11b/`.
- **내일 할 것(최종 검수 신호 뒤):** ① 궁수 두 번째 King은 위 다시 판으로 끝 — 최종 검수가 원하면 한 번 더(뒤로 빠지며 쏘기). ③ 빛 M1_3 성문 이웃 돌려주기(dev2-detail 병합 뒤) ④ NPC 대화 상자(dialog-box 병합 뒤) ⑤ 새 sync면 직업별 전체 판(전사·궁수·마법사 새 저장, 진영 섞어, 패스 끔, 직업마다 칸 먼저 → '끝' + TOP). 판마다: 화면 신청 → PlayTest 열기 → 판 → Play 멈춤 → 창 닫기 → '끝'.
- 도구: `build/playtest_tools/flow.py` + 환경 변수 FAST=1(재대결 F 연타)·NOSHOT=1·MAXDRINK=N, STUDIO_ID는 list_roblox_studios로 매번.


> **10/18 정리(최종 검수):** 옛 절은 지움 — 전부 git 역사에 있음: `git show b558445b:docs/handoff/state/playtest.md`. 아래 = 지금 필요한 절 + 방법·도구 메모.

## 10/17 밤 멈춤 (사용자: "화요일 오전부터 작업하자" — 최종 검수가 다시 부름)
- **10판 결과(4ec46c64, 뿔 전사·마법사, 고친 봇):** 두 번째 King **둘 다 이김** — 전사 F 21번·약 25초·물약 1병·최저 HP 59/182, 마법사 F 22번·약 25초·물약 2병·최저 39/112. 'Buy 3 potions' 줄 0/3→1/3→2/3→다음 목표 ✅. 첫 KO 순간 위치 땅 위(y 9.4/땅 8.9). 보고서 `docs/review/playtest/2026-10-17_r10.md` (push cb652d1). 8·9판 '못 이김'은 봇 NaN 탓(r9 보고서 맨 위에 정정).
- **봇·도구 위치:** `build/playtest_tools/`(git 밖, 재부팅에도 남음) — `flow.py <Halo|Horns> <Warrior|Archer|Mage> [단계]`(0 시작·1 안내자·2 선생님→허수아비·3 대장간·4 Otto→Prince·5 King 첫 KO·6 물약→슬롯→마시기·7 강화·8 King 다시·9 쉼·10 M1_3→가방), `pose.py idle|walk|atk PRE`(공격 몸짓 사진 시트), `pt.py`(state/texts/btns/click/key/shot/nav/lua/console), `intro_watch.py`. 환경 변수: STUDIO_ID(list_roblox_studios로 매번), PT_ROUND(사진 폴더 r<N>), PT_DATE, `BUY5=1`(가게 [5개]). 열기: `cp place/GoodEvil.rbxlx build/PlayTest.rbxlx` → Start-Process Studio(옛 pid는 pid.txt) → `py tools/sync_to_studio.py`.
- **NaN 고침:** 8·9판 봇이 서버에서 F마다 `CFrame.lookAt(내 위치, King 위치)`를 썼는데, King이 발밑에 내려앉으면 두 점이 같아 NaN → 몸이 Y −1,000,000 → 마을로 구하기/맵 아래 KO. 이제 몸 돌리기 세 곳(monster face·FACE_KING·face())은 평면 거리 0.5스터드 미만이면 건너뜀. fight()의 MoveTo는 거리 > near일 때만.
- **도구 주의:** KO 순간 길 찾기가 약 2분 멈춤(게임 아님) → KO되면 `walk stop`으로 끊음. 멈춘 python은 `Get-CimInstance Win32_Process`에서 flow.py로 찾아 끄기. 빛 Gleam 동상 옆 nav 'Success'만 하고 안 움직이면 W 키로 빼기. 서버 콘솔 DataStore 줄은 PlayTest라 정상(Studio 저장 없음).
- **다음 판 할 것(화요일 오전):**
  1. 궁수(빛) 재대결 King — 물약 3개 사고 50%에서 마시기.
  2. 물약 쿨다운 중 키 1을 눌렀을 때 화면에 '기다려' 같은 표시가 있나(사진).
  3. 성문 이웃 돌려주기(빛 M1_3 'Return bag' → 이웃 G → 대사·다음 목표 'Learn your first skill from Sir Gleam.').
  4. 대화 상자(Tiny·이웃 등)가 나오면 그것 — 뿔 Tiny G 대화 카드, 이웃 대사가 화면에 보이는지.
  5. 그 위에 새 sync 신호가 오면 처음부터 직업별 한 판(8판 점검표).

## 10/17 밤 늦게 — 새 계정 '게임 플레이' 세션 엶 (대기)
- 읽음: AGENTS → 04_playtest → 이 파일 '10/17 밤 멈춤' → r10 → review.md '10/17 밤'. 도구 `build/playtest_tools/` 그대로(flow.py·pose.py·pt.py·intro_watch.py), 공유 폴더 HEAD = origin/main(0 0), src 깨끗.
- PlayTest Studio는 지금 안 열림(옛 pid 34592 없음). `build/PlayTest.rbxlx` = place/ 10/16 15:11 판과 같은 크기. 열 때 다시 복사 + list_roblox_studios로 새 id.
- **11판 = 최종 검수 신호 뒤**(dev2-detail·dialog-box 병합 → sync): ① 빛 궁수 재대결 King(물약 3개, 50% 아래 마시기) ② 쿨다운 중 키 1 화면 사진 ③ 빛 M1_3 성문 이웃 Return bag ④ NPC 대화 상자 ⑤ 새 sync면 직업별 처음부터(전사·궁수·마법사 새 저장, 진영 섞어, 패스 끔), 직업마다 칸 먼저 보내고 마지막 '끝' + 직업별 TOP.

## 10/17 밤 — 11판 앞부분 끝 (빛 궁수, src 5b90afa9)
- 보고서 `docs/review/playtest/2026-10-17_r11.md`, 기록 `docs/art/verification_2026-10-17/playtest/r11/`(git 밖).
- ① 궁수 두 번째 King **짐**: Lv4·HP 156, 물약 3병 다 마심, F 16번 40초, King 54 남김. 단 봇이 쿨다운 사진 찍느라 ~8~10초 공격 안 함 → 사진 없이 재판 필요.
- ② 쿨다운 중 키 1: 슬롯에 어두운 막(투명 0.45)이 줄어듦, 다시 눌러도 글·흔들림 없음('Status=Wait' 글은 숨김).
- 도구: flow.py에 쿨다운 사진 추가(`cd_dump.lua`, 물약 #1·#2 뒤) — 재판 땐 이 부분 끄기(CD 블록). 사진 3D가 하얗게(창이 뒤) — 다음엔 Play 뒤 창 앞으로인지 확인. 사용자 10/17 밤: **시험 Studio는 판마다 Play 멈춤 → 창 닫기 → '끝'**. PlayTest pid는 닫은 뒤에도 잠깐 목록에 남음(taskkill '없음') = 닫힌 것.
- **다음:** 최종 검수 신호 → 궁수 재대결(사진 없이) / ③ 성문 이웃·④ 대화 상자·⑤ 직업별 전체 판(병합 뒤).

## 10/17 밤 — 11판 ① 다시 끝 (빛 궁수 두 판, 사진 없이·F 연타)
- 보고서 `docs/review/playtest/2026-10-17_r11.md` 아래 절, 기록 `.../playtest/r11b/`.
- 판 A(물약 3개 가짐): **이김** 27.8초, 실제 2병, 최저 52/156. 판 B(1병만): **이김** 32.2초, 최저 25/156. 둘 다 재대결 Lv4·HP 156·Attack 17. r11 앞 '짐'은 사진 지연 탓.
- 도구(flow.py): `FAST=1`(재대결 King만 0.25초 F 연타 8번 묶음, mash()), `NOSHOT=1`(재대결 사진·쿨다운 사진 끔), `MAXDRINK=N`(재대결 물약 수), 빛 첫 대장간 지점은 MoveTo(Gleam 동상 nav 2분 멈춤 피함), KING2 START/SUMMARY 줄. 백업 flow_r10_backup.py·flow_r11a_backup.py. 판 끝 Play 멈춤 → PlayTest 프로세스만 닫음.
- **다음:** 최종 검수 신호 → ③ 성문 이웃·④ 대화 상자·⑤ 직업별 전체 판(병합 뒤).
