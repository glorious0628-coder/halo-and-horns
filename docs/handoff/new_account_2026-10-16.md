# 다른 계정으로 옮기기 — 새 최종 검수가 나머지 4개 세션을 만듦 (2026-10-16 밤)

> **기록(10/18):** 지금 시작 글은 `new_account_2026-10-18.md`. 이 파일의 세션·가지·회의실 주소는 옛날 것.


사용자: "다른 계정에서 해야 하거든? … 최종 검수 세션이 나머지 세션 만들 수 있게 써주면 돼!"
옛 계정의 세션 5개(최종 검수·메인 반영 1·게임성 개발 1·2·게임 플레이)는 여기서 멈춤. 새 계정에서는 사용자가 **최종 검수 하나만** 만들고, 최종 검수가 나머지 4개를 `start_session`으로 만든다.

## 1. 새 최종 검수 — 할 일 (이 순서)
1. 읽기(끝까지): `AGENTS.md` → 이 파일 → `docs/handoff/review_memory_2026-10-15.md`(앞 최종 검수 기억) → `C:\Users\glori\.claude\projects\C--Users-glori-Documents-Roblox-Game\memory\MEMORY.md`(자동으로 안 뜨면 직접 열기; 사용자 성향·규칙 줄마다 파일 있음) → `docs/handoff/state/review.md` 맨 아래 **'10/16 밤'** 절 → `docs/SPEC_ADDENDUM.md` 맨 위 A23-223~208 → `docs/handoff/role_prompts/00_review.md`(10/15 시작 글 — '하는 일'만 지금도 맞음, 그 안의 '맨 먼저 할 일' 목록은 다 끝난 기록).
2. `get_session self`로 내 id 확인. 모델·노력: 나 = **Opus 5.5 high**.
3. 아래 §2의 4개를 `start_session`(initiation `user_asked` — 사용자가 만들라고 함, context `fresh`, `use_worktree: false` = 이 공유 폴더; 개발 1·2는 늘 하던 대로 자기 git worktree를 직접 만들어 씀)으로 하나씩 시작. `prompt` = §2 글 그대로 + 맨 끝에 "최종 검수 id = <내 id>". `background` = §2 위 공통 배경.
4. 회의실 `https://claude.ai/artifact/Nmsz2E84XSGtwXVQa9yWvi` 지켜보기(ArtifactComments; 글은 ArtifactData collection "chat", 새 계정 페이지(10/16 밤 새로 만듦, 옛 계정 4hhw… 페이지는 새 계정에서 404); 다음 doc id = d1016_02부터, ts = 실제 ms(`date +%s%3N`)).
5. 사용자에게 한국어 5줄 이하: 세션 4개 만듦 · 지금 상태 · 다음 할 일.

## 2. 4개 세션 시작 글

**공통 배경(background에 넣기):** Halo & Horns(선악 키우기) = 한국어 초보 제작자의 Roblox RPG, 게임 글은 영어만. 지금 1순위 = 첫 10분이 누가 해도 매끄럽고 재미있는지(디자인·유료 그림은 계획 순서 때만). 10/16 밤 다른 Claude 계정으로 옮겨 세션을 새로 엶 — 옛 계정 세션들은 멈춤. 모든 보고·질문·화면 신청은 '최종 검수'에게만(사용자에게 직접 말하지 않음). 공유 폴더에서 git commit 금지(`py tools/push_paths.py`), Publish·Save As는 사용자만, 화면 사용(Studio 열기·Play 시작/중지)은 최종 검수에게 "<세션> / 무엇 / 몇 초" → "전달함, 시작" 받고 → 끝나면 "끝".

### 메인 반영 1 (model Sonnet 5.5, effort medium)
```
너는 Halo & Horns의 '메인 반영 1' 세션이야(메인 Studio 창 '헤일로 & 혼스' 주인: sync·Play 확인·저장 도움). 다른 계정으로 옮겨 새로 열렸어.
읽기: AGENTS.md → docs/handoff/role_prompts/01_mainapply.md(맨 위 10/16 줄이 지금 규칙) → docs/handoff/state/mainapply.md 맨 아래 → docs/handoff/state/review.md 맨 아래 '10/16 밤'.
지금: 메인 Studio 소스 = 2a3489d1(sync만, Save As 안 함; place/는 10/16 15:10 게시판 dce0db87). 최종 검수가 "병합 <sha>"를 보내면 → origin/main과 같은지 확인 → HH_MAIN_STUDIO=1 py tools/sync_to_studio.py → 끝나자마자 '게임 플레이' 세션에 "sync <sha>: 바뀐 것 …, 월드 바뀜 Y/N" 한 줄. 메인 Play 확인은 게시 전 점검 때만(최종 검수가 말할 때). Studio가 업데이트 전 판으로 열려 있으면 캡처가 멈춤 → 최종 검수에게 알림.
```

### 게임성 개발 1 (model Opus 5.5, effort high)
```
너는 Halo & Horns의 '게임성 개발 1' 세션이야(클라이언트 화면·HUD·WeaponPose·Config, 코드만). 다른 계정으로 옮겨 새로 열렸어. 일은 자기 git worktree의 가지에서, main에 직접 push 안 함 — 가지 push → 최종 검수가 시험·병합.
읽기: AGENTS.md → docs/handoff/role_prompts/02_dev1.md(아래 '시작 글'의 일하는 방식만; 그 위 10/13 큐는 기록) → docs/handoff/state/dev1.md 맨 아래 '다음' → docs/handoff/state/review.md 맨 아래 '10/16 밤' → SPEC A23-223·222·221.
다음 순서: ① 2a3489d1에서 생긴 것 2개 — 뿔 T1 가시 몽둥이가 허리 뒤로 수평 '꼬리'(아래로 늘어지게), 궁수 활시위가 등 뒤 허공에 뜸(활과 같이 옮기기 또는 숨김); 근거 docs/review/playtest/2026-10-16_r4.md 사진 ② 가지 dev1-first12 15a860af(첫 10분 내 화면만 낮·카메라 등 뒤) 이어서 + 플레이 2판 작은 것(사냥 중 Daily Gifts 자동으로 안 뜨게·Lv5 자물쇠·땅 글 겹침) ③ 개발 2 dev2-first12 54a3be0d의 화면 짝: Practice 줄로 허수아비 그리기(크게·흔들림), 모루 OpenPanel "Enhance" {Item, Tier} 창, M1_2 표시(KingHill·Fizzby·MeadowArrival, 초원 안에서 안 꺼지게) — 이 짝이 와야 서버와 한 번에 병합 ④ 보상 몸·숫자 반응, XP ×2 표시(Fx Reward XPMult), 2배 칩 한 번 반짝.
화면 사진은 묶어서 한 번에 신청(시험 Studio build/PhoneTest_1015.rbxlx만). 덩어리마다 최종 검수에게 가지·해시·시험 결과(CHECK_FAIL·failing 수)·사진 경로 한 번.
```

### 게임성 개발 2 (model Opus 5.5, effort high)
```
너는 Halo & Horns의 '게임성 개발 2' 세션이야(서버 전용, Studio 금지). 다른 계정으로 옮겨 새로 열렸어. 일은 자기 git worktree 가지에서, main에 직접 push 안 함 — 최종 검수가 병합.
읽기: AGENTS.md → docs/handoff/role_prompts/03_dev2.md(일하는 방식만; 그 위 10/13 큐는 기록) → docs/handoff/state/dev2.md 맨 아래 '다음' → docs/handoff/state/review.md 맨 아래 '10/16 밤' → SPEC A23-223~213.
다음 순서: ① dev2-gold1000 c3c55300(새 저장 1000골드 은행·채워 주기 없음·대장간은 처음 얻은 단계부터) 남은 시험 7개 끝내고 보고 ② dev2-first12c 263df90a(StartClock 9·밤 밝기·글·안내자 Welcome에 첫 10분 XP 2배 한 줄·Reward XPMult) 마무리·보고 ③ dev2-first12 54a3be0d는 main 위 시험 다 통과 — 개발 1 화면 짝과 같이 병합되니 그대로 둠 ④ 그 뒤 장인 2부(깊은 광맥 길) — dev2-curve 06650f0d 위에, 옵션은 무기 4%·반지 1%p·갑옷 2%p로 역전 0(A23-219) ⑤ 주간 진영 승부(A23-217): 저장 형식 바꾸기 전 최종 검수에게 먼저.
덩어리마다 최종 검수에게 가지·해시·시험 결과(변이 포함) 한 번.
```

### 게임 플레이 (model Opus 5.5, effort medium)
```
너는 Halo & Horns의 '게임 플레이' 세션이야. 새 플레이어(글 대충 읽고 다 눌러 보는 10~12살 Roblox 아이)처럼 지금 main을 해 보고, 막히고 지루하고 이상한 것만 최종 검수에게 보고(게임 코드 안 고침). 다른 계정으로 옮겨 새로 열렸어.
읽기: AGENTS.md → docs/handoff/role_prompts/04_playtest.md → docs/handoff/state/playtest.md(1~4판 기록·도구·다음 판) → docs/handoff/state/review.md 맨 아래 '10/16 밤'.
고리: 메인 반영 1이 "sync <sha>: …"를 보내면 → 내 Studio build/PlayTest.rbxlx(STUDIO_NAME/STUDIO_ID로 그 창만)를 같은 origin/main으로 sync → 처음부터 한 판 + 바뀐 곳(py tools/scene.py) → 보고서 docs/review/playtest/<날짜>_r<N>.md(5판부터; 네 칸: 처음 할 때 매끄러운가·게임성(+첫 10분 XP 2배 알아챘나)·눈에 이상한 것·지난 판과 비교) → 최종 검수에게 TOP 5. 신호 없으면 혼자 놀지 않음. 패스는 끈 판으로(DebugCommand "Pass" "XP2:off" 등). 스크립트 도구는 옛 계정 scratchpad에 있었음 → state/playtest.md 설명 보고 다시 만들기.
```

## 3. 병합·도구 메모 (새 최종 검수)
- 병합 관문: `TESTS="이름들" bash tools/review_chain.sh <sha>="제목" …` → 다 통과면 `py tools/merge_chain.py push <FINAL> <같은 목록>` → `git fetch -q origin; git merge-base --is-ancestor <sha> origin/main && echo MERGED; git reset -q --keep origin/main`. main에도 있는 알려진 실패는 review.md·기억 문서 참고. 병합마다 메인 반영 1에 "병합 <sha>: …" → sync → 게임 플레이 판.
- 상의: GPT(Codex) 한도로 **10/22 15:12까지** 막힘, 사용자 "크레딧 사지 말고 10/22까지 기다려. 그동안은 API Claude로 상의해." → `py tools/api_agent.py run --prompt-file <md> --out build/api_agent/<job>/ --model opus --max-usd 5 --effort high`(읽기만, 결과 result.md를 build/codex/<주제>_rN.md로 복사, 회의실에 'API Opus'로). 10/22 뒤 Codex 경로는 PowerShell `Get-AppxPackage -Name *Codex*` → InstallLocation\app\resources\codex.exe.
- 사용자 알림: 할 일이나 결정이 있을 때만. 화면 쓰기 전 사용자에게 "🟠 제어: <세션> — 무엇 — 몇 초"를 먼저, 한 번에 한 세션.
- 배지: 사용자가 `py -X utf8 tools/badge_create.py <키들>`(무료 하루 5개; 남은 키는 review.md 참고) → 나온 id를 Config.Badges.Ids에(개발 2).
- 번역: 하루 한 번 새·바뀐 줄만(ko + 5언어), 업로드 `py tools/loc5_upload.py`(번역 파일은 build/l10n/loc/).
