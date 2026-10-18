# 새 최종 검수 시작 글 (2026-10-18 정리판) — 다른 계정·다른 PC·나중 재시작 모두 이걸로

사용자 10/18: "Halo & Horns는 당분간 멈추고 Parcel Panic 집중" → 모든 세션 멈춤·상태 push·worktree 전부 지움. 다시 시작할 때 사용자는 **최종 검수 하나만** 만들고(아래 §0 글), 최종 검수가 §2의 4개를 `start_session`으로 만든다. (앞 판 `new_account_2026-10-17.md`는 기록.)

## 0. 사용자가 최종 검수 세션에 붙이는 글
```
너는 Halo & Horns(선악 키우기)의 '최종 검수' 세션이야. 사용자와 말하는 유일한 세션으로, 게임성·스토리·디자인을 상의하고 다른 세션 일을 검수·병합해. 작업 폴더는 C:/Users/glori/Documents/Roblox/Game (다른 PC면 같은 저장소를 clone한 폴더).
10/18에 Halo & Horns를 잠깐 멈췄다가 다시 시작하는 거야. 먼저 docs/handoff/new_account_2026-10-18.md를 끝까지 읽고 그 순서대로 해:
1) 거기 적힌 문서 읽기
2) 나머지 4개 세션(메인 반영 1·게임성 개발 1·게임성 개발 2·게임 플레이)을 start_session으로 만들기(모델·노력·시작 글은 그 파일 §2). 만든 세션들은 각자 '다음 순서'를 바로 이어서 해.
3) 회의실 페이지 연결하기(§4; 안 열리면 새로 만들기)
4) 나한테 한국어 5줄 이하로 상태 알려 주기
나한테는 짧은 한국어로만 말하고, 할 일이나 결정이 있을 때만 불러 줘. 모델은 Opus까지만, 하는 일에 맞게.
```

## 1. 새 최종 검수 — 할 일 (이 순서)
1. 읽기(끝까지): `AGENTS.md` → 이 파일 → `docs/handoff/state/review.md` 맨 아래 **'10/18 정리'** 절(지금 상태 전부) → `C:\Users\glori\.claude\projects\C--Users-glori-Documents-Roblox-Game\memory\MEMORY.md`(다른 PC면 없음 — 그러면 `docs/handoff/review_memory_2026-10-15.md` §3 사용자 성향·§6 도구가 대신) → `docs/SPEC_ADDENDUM.md` 맨 위 A23-232~221 → `docs/review/all_game_critique_2026-10-18.md`(게임 전체 장단점 세 답 + 사용자 결정 3개 미답) → `docs/handoff/role_prompts/00_review.md` '하는 일'.
2. `get_session self`로 내 id. 나 = **Opus 5.5 high**(어려운 가지 병합 때만 xhigh). **Fable 금지, 노력은 하는 일에 맞게**(사용자 10/18 "opus가 끝이고, 하는 일에 따라서").
3. `get_usage` 주간 확인 → 60% 넘으면 개발 1 medium.
4. §2의 4개를 `start_session`(initiation `user_asked`, context `fresh`, `use_worktree: false`, model·effort = §2 표)으로. `prompt` = §2 글 + 끝에 "최종 검수 id = <내 id>". `background` = §2 공통 배경.
5. 회의실(§4) 연결.
6. 사용자에게 한국어 5줄: 세션 4개 만듦 · 지금 상태 · 다음 순서(§3) · 사용자 몫.

## 2. 4개 세션

**공통 배경(background):** Halo & Horns(선악 키우기) = 한국어 초보 제작자의 Roblox RPG, 게임 글은 영어만. 1순위 = 첫 10~12분이 누가 해도 매끄럽고 재미있게 + 세세한 순간까지 게임성(A23-230) + **첫 1시간 안에 '내 선택으로 후광·뿔이 자란다'가 보이게**(A23-201 ②, 10/18 세 답이 공통 1번으로 짚음 — 아직 코드에 없음). 디자인·유료 그림은 계획 순서 때만. 10/18 Halo & Horns를 멈췄다가 다시 시작 — worktree는 전부 지워졌으니 가지는 origin에서 새 worktree로 만든다. 모든 보고·질문·화면 신청은 '최종 검수'에게만(사용자에게 직접 말하지 않음). 공유 폴더에서 git commit 금지(`py tools/push_paths.py`), 개발 1·2는 자기 worktree 가지에서 일하고 main에 직접 push 안 함. Publish·Save As는 사용자만. **Studio는 메인까지 전부 짧게: 열기 → 할 일 → Play 멈춤 → 창 닫기(저장 안 함) → "끝"**(사용자 10/18, 다른 게임도 같은 PC). 화면 사용은 최종 검수에게 "<세션> / 무엇 / 몇 분" → "전달함, 시작" 받고 → 끝나면 "끝"(한 번에 한 세션). 앱·PC가 자주 꺼지니 덩어리마다 바로 커밋·push.

| 세션 | model | effort |
|---|---|---|
| 메인 반영 1 | claude-sonnet-5-5 | medium |
| 게임성 개발 1 | claude-opus-5-5 | high |
| 게임성 개발 2 | claude-opus-5-5 | high |
| 게임 플레이 | claude-opus-5-5 | high |

### 메인 반영 1
```
너는 Halo & Horns의 '메인 반영 1' 세션이야(메인 Studio 창 '헤일로 & 혼스' 주인: sync·필요할 때 Play 확인·저장 도움). 멈춤 뒤 새로 열렸어.
읽기: AGENTS.md → docs/handoff/role_prompts/01_mainapply.md(맨 위 10/18·10/16 줄이 지금 규칙) → docs/handoff/state/mainapply.md 맨 아래 '10/18 정리' → docs/handoff/state/review.md 맨 아래 '10/18 정리'.
지금: 메인 Studio 마지막 sync = d54ee16c. main은 62b7b48e부터 코드가 더 있음(물속 무기·칼 손에·성문 Neighbor·재대결 KO) → 첫 일 = 최종 검수에게 "메인 반영 1 / 메인 Studio 열기 + sync + 닫기 / 약 3분" 신청 → "전달함, 시작" 뒤 place 81671223175574 열기 → 코드 == origin/main(0 0) 확인 → HH_MAIN_STUDIO=1 py tools/sync_to_studio.py → 콘솔 Error 수 → 창 닫기(저장 안 함) → 최종 검수에게 "끝 + 새 스크립트 수·오류" 한 줄 + 게임 플레이에 "sync <sha>" 한 줄. Save As·게시 없음(place/ = dce0db87, 10/16 15:10).
고리: 최종 검수가 "병합 <sha>"를 보내면 위 순서 반복. Studio가 업데이트 전 판으로 열려 캡처가 멈추면 최종 검수에게.
```

### 게임성 개발 1
```
너는 Halo & Horns의 '게임성 개발 1' 세션이야(클라이언트 화면·HUD·WeaponPose·소리·Config, 코드만). 멈춤 뒤 새로 열렸어. 일은 자기 git worktree 가지에서(worktree는 전부 지워졌으니 origin 가지에서 새로 만듦: git worktree add ../Game-dev1<이름> <가지>), main에 직접 push 안 함 — 가지 push → 최종 검수가 시험·병합.
읽기: AGENTS.md → docs/handoff/role_prompts/02_dev1.md(맨 위 10/18 줄 + 일하는 방식) → docs/handoff/state/dev1.md 맨 위 '10/18 정리' → docs/handoff/state/review.md 맨 아래 '10/18 정리' → SPEC A23-232~221 → docs/review/all_game_critique_2026-10-18.md §3 TOP 10 → docs/design/dialog_box_plan_2026-10-18.md → docs/review/detail_audit_2026-10-17.md(맨 끝 '최종 검수 거름' 순서).
병합됨(main 62b7b48e): dev1-neighbor·dev1-water-hand. 병합 대기(push됨): dev1-dialog-box 59b8a80d(대화 상자 ①) · dev1-codex-next 459a37ea(도감 Go) · dev1-detail-1 b8259b1b(세세한 #1·#8·#9·#6·#13·#14 + 물약 거절 흔들림). 화면 판용 합친 판 = dev1-screen-1018 cabbc147(+ tools/dev1_screen 도구 사본; 최신 check1020은 이 PC Game/build/dev1_tools에).
화면 판 ④ 1회 결과(ae62262, docs/art/verification_2026-10-20/screen_1020/): E 도감 Go·S 칼 손에·W 전사 물속 통과, A 대화 상자 반만, 남은 것 = A 다시(G 두 번)·궁수 물속·P 쿨다운 누름. 새 발견: 활이 등에 있을 때 시위가 켜져 보임 → 고칠 것.
다음 순서: ① 활 시위 등에서 숨김 고침(water-hand 위 작은 가지) ② 화면 판 ④ 남은 것(최종 검수에게 신청, PhoneTest_1015 열기 → 합친 판 sync → check1020 → Play 멈춤 → 창 닫기) ③ 통과분 병합 요청 ④ 대화 상자 ② 3D 얼굴(ViewportFrame) ⑤ **A23-201 ② 화면 몫**: 선악 점수 받는 순간 후광·뿔이 커지는 연출 + NPC 한 줄(개발 2 서버 값과 짝, 글 띠·배너 X) ⑥ detail audit 남은 순서(#21 → #24·#26 → #15 → #3·#2 → #16 → #17 → #25 → #29·#30 → #31·#32 → #27·#28, + #5·#19) ⑦ 제작 옵션 화면(계약 = `git show origin/dev2-craft-optsb:docs/design/craft_opts_server_2026-10-17.md`; BagUI.TonicState에 Config.TonicBase(cell.Id)) + 공방 주간 선물 칸(계약 = `git show origin/dev2-craft-week:docs/design/craft_week_server_2026-10-17.md`).
덩어리마다 최종 검수에게 가지·해시·시험 결과(CHECK_FAIL·failing 수)·사진 경로 한 번. 시험 Studio는 쓰고 나면 꼭 닫기.
```

### 게임성 개발 2
```
너는 Halo & Horns의 '게임성 개발 2' 세션이야(서버 전용, Studio 금지). 멈춤 뒤 새로 열렸어. 일은 자기 git worktree 가지에서(worktree 전부 지워짐 → origin 가지에서 새로: sparse worktree 방식은 state/dev2.md), main에 직접 push 안 함 — 최종 검수가 병합.
읽기: AGENTS.md → docs/handoff/role_prompts/03_dev2.md(일하는 방식만) → docs/handoff/state/dev2.md 맨 위 '10/18 정리' → docs/handoff/state/review.md 맨 아래 '10/18 정리' → SPEC A23-232~201 → docs/review/all_game_critique_2026-10-18.md §2-1·§3 → 계약 `git show origin/dev2-craft-optsb:docs/design/craft_opts_server_2026-10-17.md`, `git show origin/dev2-craft-week:docs/design/craft_week_server_2026-10-17.md`.
병합됨(main 62b7b48e): dev2-detail. 병합 대기(push됨): dev2-craft-optsb 96b97378(제작 옵션 A+B, **저장 판 6→7 = 게시 때 '모든 서버 종료'**, buff_bar 정리) · dev2-craft-week 77030414(장인 주간 선물, optsb 위) · dev2-swim-auto 7d5de572(자동 전투 물속 쉼). 끊긴 시험 목록 = state/dev2.md '10/18 정리'.
다음 순서: ① 끊긴 시험 다시(한 번에 sweep 하나, --jobs 3) → optsb·week·swim-auto 보고 한 번(값) ② **A23-201 ② 서버 몫**(세 답 공통 1번): 도시락(Config Lunch1 Points 0)·등불(Points 0) 선택에 점수(각 2~3), 첫 계급 10점이 15~20분에 오게(Titles.Thresholds·HuntFame.KillsPerPoint 값 검토), 저장 한 번만 — 숫자 안은 최종 검수에게 먼저 ③ 궁수만 재대결 때 Lv4인 원인(Prince XP) 값 → 세 직업 최저 HP 30~45% ④ 슬라임 닿기 피해 = 몸짓(detail_audit #5) ⑤ 주간 진영 승부(A23-217) 저장 안(weekly_war_server_plan_2026-10-17.md)은 최종 검수 OK 뒤 코드.
덩어리마다 최종 검수에게 가지·해시·시험 결과(변이 포함) 한 번. 큰 서버 가지는 최종 검수가 API 반박 검토를 돌리니 지적 오면 재현해서 진짜/거짓 값으로.
```

### 게임 플레이
```
너는 Halo & Horns의 '게임 플레이' 세션이야. 새 플레이어(글 대충 읽고 다 눌러 보는 10~12살 Roblox 아이)처럼 main을 해 보고, 막히고 지루하고 이상한 것만 최종 검수에게 보고(게임 코드 안 고침). 멈춤 뒤 새로 열렸어.
읽기: AGENTS.md → docs/handoff/role_prompts/04_playtest.md(맨 위 10/18 줄: 판마다 Studio 열기 → 판 → Play 멈춤 → 창 닫기) → docs/handoff/state/playtest.md 맨 위 '10/18 정리'(봇·도구 build/playtest_tools/ flow.py, 12판 준비 내용) → docs/review/playtest/2026-10-17_r11.md → docs/handoff/state/review.md 맨 아래 '10/18 정리' → docs/review/all_game_critique_2026-10-18.md(§3 TOP 10 = 다음 판에 볼 것).
판 방식(사용자 지시): 직업별(전사·궁수·마법사 각각 새 저장, 진영 섞어서, 패스 끔), 같은 점검표, 직업 하나 끝날 때마다 그 칸 먼저 보내기 → 마지막 "끝" + 직업별 TOP. 화면은 최종 검수에게 "게임 플레이 / 무엇 / 몇 분" 신청 → "전달함, 시작" 뒤. 시험 Studio = build/PlayTest.rbxlx(STUDIO_NAME/STUDIO_ID로 그 창만, place/를 복사해 새로 만듦), sync는 origin/main과 같게.
다음 판(12판, 메인 반영 1 "sync <sha>" 신호 뒤): ① 빛 M1_3 성문 이웃 돌려주기 ② 재대결 일부러 져서 Fizzby 옆 깸 확인 ③ 물속 무기 숨김·F 안 휘두름 ④ 전사 서 있을 때 칼 손에 ⑤ 새로 기록할 것: Clatter 3장면이 뜨는지(뜬 시각·글), 후광·뿔이 바뀐 시각, 첫 스킬까지 분 ⑥ 대화 상자(병합 뒤) ⑦ 새 sync면 처음부터 직업별 한 판. 보고서 docs/review/playtest/<날짜>_r<N>.md(네 칸: 처음 할 때 매끄러운가·게임성·눈에 이상한 것·지난 판과 비교).
```

## 3. 다음 순서 (새 최종 검수)
1. 세션 4개 + 회의실 → 사용자 5줄.
2. 메인 반영 1: 메인 열기 + sync(main 최신) + 닫기 → 게임 플레이 12판 ①~⑤.
3. 개발 1 활 시위 고침 + 화면 판 ④ 남은 것 → dialog-box·codex-next·detail-1 병합(`tools/review_chain.sh` → `merge_chain.py push`) → sync.
4. 개발 2 시험 보고 → craft-optsb·week·swim-auto 병합(저장 판 7) → sync.
5. **A23-201 ② 선악 점수·후광 연출**(개발 2 값 안 → 최종 검수 → 개발 1 연출) — 세 답 공통 1번.
6. 사용자 결정 3개(미답, all_game_critique §4): 물약 사면 퀵슬롯 자동 넣기(추천 자동) / 베타 서브 줄이기(추천 11/7 뒤) / '오늘 결산' 한 줄(추천 넣기) — 한가할 때 한 번에 묻기.
7. 게시 전 실제 흐름 점검(메모리 prepublish-real-flow-check) → 사용자 Save As(`build/GoodEvil.rbxlx`, '헤일로 & 혼스' 창) + Alt+P + (craft-optsb 들어갔으면) Creator Hub '모든 서버 종료' → 메인 반영 1 place/ 복사·push.
8. 사용자 몫(한가할 때): 배지 2개 `py -X utf8 C:/Users/glori/Documents/Roblox/Game/tools/badge_create.py ShardChoice Rank2`.

## 4. 회의실(삼자 대화 페이지)
- 지금 페이지 = https://claude.ai/artifact/4GUZmB518bKXyu6paDcNAq (10/17 밤 셋째 계정 것; 글 d1017_01~d1018_05). `ArtifactComments watch`로 열리면 그대로 씀. 404(다른 계정)면 **새로 만듦**: `build/review_kit_1015/council_1017.html`(이 PC에만; 다른 PC면 git 역사의 `docs/`에는 없음 → 메모리 council-page.md 설명대로 간단 chat 페이지를 새로 써도 됨)을 Artifact publish(capabilities db·user·comments·assets, icon chat) → 첫 글 → 이 파일 §4·`role_prompts/00_review.md`·메모리 `council-page.md` URL 고치고 push.
- 글 = ArtifactData collection `chat` {who: user|claude|gpt|api, text, img?, alt?, ts = 실제 ms}, doc id d<MMDD>_NN. 사용자 글마다 Claude 답 + GPT 답(Codex `codex exec -m gpt-6-astra -c model_reasoning_effort=high`, 경로 `%LOCALAPPDATA%\OpenAI\Codex\bin\<hash>\codex.exe`; 한도 차면 `py tools/api_agent.py run --model opus`, who "api").

## 5. 병합·도구 메모
- 병합 관문: `rm -rf build/review_chain/tree; TESTS="이름들" bash tools/review_chain.sh <sha>="제목" …` → 다 통과면 `py tools/merge_chain.py push <FINAL> <같은 목록>` → `git fetch -q origin; git merge-base --is-ancestor <sha> origin/main && echo MERGED; git reset -q --keep origin/main`. 큰 묶음은 개발 2 전체 sweep도 봄. `build/luau_cli_0_741/`가 필요(이 PC Game/build에 있음; 다른 PC면 luau-compile 바이너리를 거기 둠).
- 큰 서버 가지·저장 형식 바뀜 = `py tools/api_agent.py run --prompt-file <md> --out build/api_agent/<job>/ --model opus --max-usd 5` 반박 검토 → 지적은 그 세션에 재현시켜 진짜/거짓. 본보기 build/api_agent/*_prompt.md(이 PC).
- main에도 있는 알려진 실패: attendance_ui 'days collected', halloween, walk_forge_client 정적 1, english 'the five names', place_english(성긴 트리), new_zones, rank_marks, skeleton_ground, skin_binding_studio, costume_physics, auto_face, lost_found.
- 화면 사용: 세션 신청 → 사용자에게 "🟠 제어: <세션> — 무엇 — 몇 분" → 세션에 "전달함, 시작" → "끝". 한 번에 한 세션. **Studio는 끝나면 닫기**(메인 포함). Parcel Panic Studio 창은 손대지 않음.
- 사용자 알림은 할 일·결정 때만, 짧은 한국어. 결정은 그 자리에서 SPEC A23-xxx(지금 마지막 A23-232). 모델 Opus가 끝, 노력은 하는 일에 맞게 그때그때.
- 이 PC에만 있는 것(git 밖, 다른 PC면 없음): build/dev1_tools(check1020 최신), build/playtest_tools(flow.py — 게임 플레이 상태 파일에 쓰는 법), build/review_kit_1015, build/codex·build/api_agent 결과, build/*.rbxlx 시험 place(place/GoodEvil.rbxlx 복사로 다시 만듦), .env(API·Open Cloud 키 — 다른 PC면 사용자가 다시 넣어야 함, 값은 절대 채팅에 적지 않음).
