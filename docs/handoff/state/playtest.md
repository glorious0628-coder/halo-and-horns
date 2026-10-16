# 게임 플레이 — 상태

## 10/16 오후 (최종 검수가 엶)
- 사용자 "게임 플레이하는 세션도 하나 만들자!" → 역할 파일 `docs/handoff/role_prompts/04_playtest.md`.
- **다음(1판):** `build/PlayTest.rbxlx` 복사·열기(🟠 절차) → main sync → 빛 첫 10분 PC 처음부터 → 보고 `docs/review/playtest/2026-10-16_r1.md`.
- 이미 아는 것(다시 보고 X): 무기 쥐는 모습 이상(개발 1 고치는 중, `docs/review/grip_check_2026-10-16.md`), Tiny 첫 G가 M2_3 제안보다 분실물 창 먼저, 순간이동 직후 Rose 첫 G 무반응(둘 다 개발 2).

## 10/16 저녁 — 1판 끝 (빛 · 전사 · PC, sync acf54995 / src 9ca5aafc)
- 한 것: build/PlayTest.rbxlx 열고(창 이름이 'Game'으로 잡힘 → STUDIO_ID로 고름, game.Name = PlayTest.rbxlx 확인) main sync → 새 저장으로 진영 → 할리 → I'm In → 선생님 → 대장간 첫 무기 → Otto M1_1 → 왕자 → 강화 → M1_3 받음까지(12분 26초). Play 중지, PlayTest 프로세스만 닫음.
- 보고서 `docs/review/playtest/2026-10-16_r1.md`, 사진 `docs/art/verification_2026-10-16/playtest/r1/`(jpg).
- TOP 5: 선생님 연습 막다른 길 / 강화 단계에서 KO / 할리가 첫 화면 밖 / 보상 안 느껴짐 / 첫 10분 절반이 밤.
- 도구: scratchpad pt.py(play·stop·state·texts·btns·near·shot·key·click·lua) — 다음 세션이면 이 절 보고 다시 만들기. 걷기는 character_navigation(길 찾기)라 시간은 아이보다 짧음. 서버에서 허수아비를 못 찾음 = 허수아비는 클라(StoryNpcs makeDummy)에만 있음.
- **다음 판:** 메인 반영 1의 다음 'sync <sha>' 신호 → 뿔 · 궁수/마법사로 처음부터 + 바뀐 곳(scene.py). 가능하면 2x XP 패스 끈 판.
- 최종 검수 10/16 저녁 메모(다음 판 꼭): ① **패스 없이** — Play 시작 직후 Server에서 `game.ServerScriptService.DebugCommand:Invoke("", "Pass", "XP2:off")`, 같은 식으로 `Gold2:off`·`VIP:off`(MonetizationService.DebugSetPass, 이 세션만, 저장 안 됨; 첫 인자 = 플레이어 이름이 필요하면 이름) → 위쪽 '2x XP · Gold' 칩이 없어졌는지 사진으로 확인. ② 오프닝 안 나온 원인 값 하나: Play 직후 1~2초 간격으로 IntroSeen·화면(인트로 GUI) 값 기록 — 1판은 25초 뒤 처음 봤을 때 이미 IntroSeen=true(인트로가 그 사이 끝났는지, 안 나왔는지 모름). 클라가 `IntroSeen` 원격을 쏴야 true가 됨(QuestService onIntroSeen).
- 지금: 쉼, 메인 반영 1 sync 신호 기다림.
