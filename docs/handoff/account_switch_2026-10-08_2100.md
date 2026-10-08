# 계정 전환 인계 (2026-10-08 21:00 KST, 컴퓨터 끄기 전) — 검수 작성

**이 문서가 지금 기준이에요.** 사용자: "다른 아이디에서 하게 정리해주고, 정리 다 하면 컴퓨터도 꺼줭".
- 이유: 이 계정의 주간 사용량이 96%예요(10/13 16:00 KST에 초기화).
- 같은 PC, 같은 폴더예요. 파일, worktree, 메모리(`C:\Users\glori\.claude\projects\C--Users-glori-Documents-Roblox-Game\memory\`)는 그대로 남아요.
- 바뀌는 것은 세션과 세션 id(local_…)뿐이에요. 옛 id는 모두 못 써요.
- 옛 세션 10개는 18:42~19:11 KST 사이에 네트워크 오류(ENOTFOUND)로 멈췄어요. 그 뒤로 돌아가는 일은 없어요.

## 0. 새 계정에서 처음 할 것 (사용자)
1. Claude 앱에 새 계정으로 로그인 → Code 탭 → 폴더 `C:\Users\glori\Documents\Roblox\Game`.
2. 세션 **"모든 것 검수"**를 만들어요(노력 xhigh + Ultracode). §5-1 프롬프트를 붙여 넣어요.
3. 나머지 9개 세션은 §5-2~§5-10 프롬프트로 만들어요. 이름과 노력은 표대로 해요.
   - 순서: 메인 반영 → 개발 1 → 개발 2 → 개발 3 → 이미지 개발 → 이미지 생성 1·2 → 촬영 → 소리.
4. Studio, Firefly, Tripo, Chrome 로그인은 필요할 때 검수가 한 번씩 부탁해요(비밀번호는 사용자가 직접).

## 1. 메인 저장 상태 (새 검수·메인 반영이 먼저 읽기)
- **메인은 클라우드 장소 "Halo & Horns"(81671223175574)예요.**
- **클라우드 마지막 Save to Roblox는 17:29 KST예요.** Studio 로그 `StudioSavePlaceToCloud 08:29:30Z`로 확인했어요.
  - 들어 있는 것: 장식 충돌 BlockPost 214(17:03), 코드 13b38e2e.
- **가장 새 메인은 `build/GoodEvil.rbxlx` 19:35:20이에요.**
  - 메인 Studio가 18:47에 Save As로 이 파일에 묶였어요. 19:35에 Ctrl+S로 파일 저장한 뒤 닫혔어요.
  - 이 파일을 `place/`에 복사해 함께 push했어요(sha256 98b84dae…).
  - 안의 `src`는 origin **ea59ec7e(17:59)**와 전 파일이 똑같아요(스크립트 대조).
  - 17:29 뒤에 이 파일에만 들어간 것:
    - 킹 슬라임 뒷면 메시 교체 + KingCrown(`tools/worldkit/slime_backfix_crown.luau`)
    - WorldKit 4차 6개(`art/models/worldkit/import_fourth_assets_2026-10-08.json`)
    - ServerStorage 속성 `StudioFreshSave=true`
    - 하늘 Lf↔Rt
    - ea59ec7e sync
- **아직 메인에 없는 코드(main에는 있음):**
  - 55f04cf2 다시 오게 화면(ComeBack·KingDiary)
  - 38cd3723 알림 4줄
  - e5b52933
  - a8e10956 조명 어둡게·카메라 기본 Free·하늘 6면 코드
  - fc890f88 HUD 묶음(FitText 재진입·초상화·전쟁 막대)
  - 9ae51c75 도구
- **메인 반영 첫 일:**
  1. 클라우드 장소를 열어요(Studio 열기·저장·닫기는 상시 허락).
  2. Edit에서 확인해요: `ServerStorage:GetAttribute("StudioFreshSave")`, KingCrown이 있는지, WorldKit3D의 4차 6개.
  3. 빠진 것은 도구로 다시 돌려요:
     - `slime_backfix_crown.luau` apply
     - `py tools/build_kit_from_ids.py --list art/models/worldkit/import_fourth_assets_2026-10-08.json …`
     - StudioFreshSave 속성
     - `crossroads_3d_swap.luau`(K_CrownShard_v2, 9453f0f4)
  4. origin/main과 같은지 확인한 뒤 `py tools/sync_to_studio.py`를 돌려요.
  5. Play로 PC와 폰 에뮬을 확인해요.
  6. 두 곳에 저장해요: Save to Roblox, 그리고 Save to File As `build/GoodEvil.rbxlx` → `place/` → push_paths.
  - **파일을 클라우드로 Publish하는 것은 사용자 OK 없이는 금지예요.**

## 2. 세션별 상태 (옛 계정 마지막 대화: `build/handoff_2026-10-08/<세션>_tail.md`, git 무시 폴더)
| 세션 | 노력 | 작업 폴더 | 마지막 상태 / 안 올린 것 | 다음 |
|---|---|---|---|---|
| 모든 것 검수 | xhigh + Ultracode | Game(공유) | 아래 §3 | §3 |
| 메인 반영 1 | high | Game(공유) + 메인 Studio 주인 | 19:35 파일 저장 후 Studio 닫힘 | §1 → 초원 3차 apply |
| 게임성 개발 1 | xhigh | `Game-wtc`(branch invite), **코드만**(메인 Studio는 메인 반영) | **안 올림:** HUD.luau 퀘스트 줄. 빈 이름 원인은 받기 알약 때문에 글자 칸이 0으로 줄어드는 것(flex shrink). `tools/test_quest_lines.py` 36개, 변이 25/25 통과. | 퀘스트 줄 push → 이미지 개발에 커밋 번호 → 카메라 Settings V3 이전 → 교차로 RoadSouth/North → 퀘스트 창 시험 훅 → separation 시험 → King 클라 몫 |
| 게임성 개발 2 | xhigh + Ultracode | `Game-dev2`(branch dev2-kingfinish) | 올림: 5bda0d47(마무리 카드 고침). **안 올림:** `SlimeKingService.luau`(새) + Config, Net, FinisherService, Main, finisher 시험. King Slime 보스 패치를 시험하다 끊김. 게임 패스 고침 3f5dd020(`Game-dev2-mtest`)은 **검수 검증 미완**. | 보스 패치 시험 끝 → push → 계약 문서(대사 표) → 검수 |
| 게임성 개발 3 | xhigh | `Game-dev3`(branch dev3) | 커밋 4개는 21:00에 검수가 origin/dev3에 push함(93865039) + **안 올린 수정 13개**(Slime Prince 글, glossary, 증거). 보고서 다시 만들기는 끝남. | 퀘스트 글 고침 main push → Slime Prince 글 15곳 + `test_slime_prince.py` |
| 이미지 개발 1 | xhigh | `Game-imgdev*`(hudfb는 main에 들어감) | fc890f88 main에 올림(메인 반영 sync 대기). 업로드 10장은 시트 검사까지 끝, 아직 안 올림. hud3 미커밋 패치는 백업함. | 10장 업로드(UiSandbox) → 퀘스트 줄 판(개발 1 push 뒤) → QuestTabIcon 5개 → 패드 안내 판 → 미니맵 몬스터 아이콘 → 측정 훅 → 숲 질감 |
| 이미지 생성 1 | high | Game(공유) | Tripo 웹에서 **왕관 돌 성(Crown Shrine) 3D 생성 시작**: Firefly 고급 3장 `art/out/hq/HQ_M_CrownShrine_{front,side,back}.png`, 폴리 20,000, 55포인트. 결과 받기 전 끊김. | Tripo 웹 기록에서 GLB 받기 → Blender 앞 렌더 → 검수 → 숲 도구(`docs/design/woods_layout_plan_2026-10-08.json`) |
| 이미지 생성 2 | high | Game(공유) | King Slime 심술 표정 A/B/C(5762c7a2, `art/review/monsters/king_slime_grumpy_sheet.jpg`). 사용자 고르기 대기, 검수 추천 A. | 고르면 멀티뷰 고급 4장(20크레딧) → 이미지 생성 1에 Tripo용으로 |
| 촬영 편집 1 | high | `Game-film`, `build/devlog/` | 쇼츠 v7(6e70408f, 26초)을 검수에 보냄. 자체 검사: 반복 0, 서 있기 0, 화면 멈춤 0. | 검수 통과 뒤에만 `Downloads/HaloHorns_Shorts01_v7_2026-10-08`에 mp4 + 제목 txt |
| 소리 생성 1 | high | `.claude/worktrees/epic-lewin-d41821` | 8번 묶음 10개 중 6개 올림(QuestOpen, QuestTab, StampPress, Chest7Open, WelcomeBack, DiaryPage; id는 asset_ids.json). **CandyPlop은 제출했는데 목록 확인을 못 함** → 다시 올리기 전 Creator Hub 목록 먼저 확인. | 남은 KingHelpHome, KingTickleCoins, TipDing → id를 개발 1에 |
| 홈페이지 | — | `docs/website/` | 세션은 사용자가 지움. 사이트 운영 중: https://glorious.ai.kr | 필요할 때만 새로 만들기(`docs/website/HANDOFF_homepage1_2026-10-08.md`) |

## 3. 검수가 이어서 할 일 (순서대로)
1. **메인 저장 맞추기**(§1, 메인 반영에 지시).
2. **쇼츠 v7 검사관 3명**(Workflow)을 다시 돌려요. 옛 워크플로 wgr3tdtv2는 끊겼어요.
   - 기준(사용자 10/08): 같은 장면 반복이면 실패예요.
   - **싸우면서 맞는 건 괜찮아요.** 0.5초 넘게 가만히 서 있으면 실패예요.
   - 통과해야만 사용자에게 보내요. 그다음 촬영이 Downloads에 mp4 + txt만 넣어요.
3. **게임 패스 고침 3f5dd020** 반박 검증을 해요(4건 → 고친 것 확인). 통과하면 병합해요.
4. **초원 3차**: `build/meadow_terrain_apply.json` → `build/meadow_dress_kit.json` → terrain apply 다시 → `decor_collision` apply 다시 → 시안과 같은 각도 사진 → 비교 시트 → 사용자.
   - 사용자가 원하는 수준: "시안이랑 똑같거나, 더 멋있으면 좋겠어".
   - JSON이 없으면 `__MODE__`를 바꿔 다시 만들어요. 꽃은 LOD를 써요. 폰 예산(ART_DIRECTION §9)을 지켜요.
5. **King Slime (A23-84):**
   - 사용자가 표정을 골라요(A 추천).
   - 멀티뷰 → Tripo로 3D를 만들어요.
   - 왕관 돌 성 3D가 나오면 배치 도구를 만들어요(검수 몫, KingSpawn 속성).
   - 개발 2: SlimeKingService + 카드, 개발 3: Slime Prince 글, 개발 1: 보스 칩·등장 알림·미니맵 아이콘.
6. **10분 뒤 콘텐츠 사용자 결정 4개**(`docs/design/content_beyond_10min_2026-10-08.md`):
   - 반복 행동 명예/악명: A 추천
   - 대장간 의뢰 T4–T6 베타 전: A 추천
   - Z/X 스킬: 10/20에 판단
   - 펫 걷기 속도: B 추천(Tamer 아니면 0)
   - 결정이 나면 TOP 목록을 나눠 줘요(CC 공용 선택 카드 먼저).
7. 소리 남은 4개 id를 개발 1에 넘겨요. 숲 지형·꾸미기 도구도 만들어요.
8. 세션 id가 바뀌었어요. 메모리 `reviewer-session-role.md`와 `beta_board`에 새 id를 적어요.

## 4. 오늘 사용자 결정 (모두 SPEC에 있음)
- A23-81: HUD 위 막대, 퀘스트 탭(Q 전체·진행 중만 표시), 장식 충돌, King Slime 뒤 자국, 스킬 배울 때 키 설정 안내. 설문은 안 해요.
- A23-82: 아이 접근은 10/31 베타 때 보증금으로 해요(사용자가 직접, 신분증·2FA).
- A23-83: 주간 업데이트는 수요일 05:00 UTC(14:00 KST)예요.
- A23-84: 네모 King Slime 보스예요(왕관 돌 성 앞, 로열 블루, 조금 무섭게). BigSlime은 Slime Prince로 바뀌어요.
  - 가족: 조각이 막내, 프린스 첫째, 킹은 아빠예요. 아빠 혼자 키워요.
- A23-85: 가족은 여러 모양이에요. 설교는 하지 않아요.
- 메인 Studio에서 메인 반영이 켜지 않은 Play가 돌면 사용자의 것이에요. 그냥 멈추고 작업해요.
- 화면 제어(마우스·키보드)는 이 순서예요: 검수가 사용자에게 🟠 알림 → 세션에 "전달함, 시작". "진행해 주세요"라고 쓰면 안 돼요.
- 크레딧: Firefly 잔액은 이미지 세션 tail 참고(약 8,000대). Tripo 웹은 25,000 계정을 써요.

## 5. 새 세션 시작 프롬프트
모두 폴더 `C:\Users\glori\Documents\Roblox\Game`에서 열어요. 공통 첫 줄로 다음 셋을 먼저 읽게 해요.
- `AGENTS.md`
- 이 문서 `docs/handoff/account_switch_2026-10-08_2100.md`
- `build/handoff_2026-10-08/<자기>_tail.md`

메모리가 자동으로 안 보이면 `C:\Users\glori\.claude\projects\C--Users-glori-Documents-Roblox-Game\memory\MEMORY.md`를 직접 읽게 해요.

### 5-1. 모든 것 검수 (xhigh + Ultracode)
```
너는 Halo & Horns(선악 키우기)의 '모든 것 검수' 세션이야. 사용자는 너에게만 짧은 한국어로 말하고, 너는 다른 9개 세션을 이끌고 모든 커밋·그림·영상을 검수해(Workflow로 독립 검사관 + 반박 검증). 먼저 읽어: AGENTS.md, docs/handoff/account_switch_2026-10-08_2100.md(지금 기준), build/handoff_2026-10-08/00_review_tail.md(옛 계정 검수 마지막 대화), memory 폴더 MEMORY.md, docs/design/beta_board_2026-10-06.md. 계정을 바꿔서 세션 id가 모두 새로 생겼어: ListAgents/list_sessions로 새 id를 찾아 메모리 reviewer-session-role에 적고, 각 세션에 인계 문서 §2의 다음 일을 보내. 그다음 인계 §3 순서대로 해.
```
### 5-2. 메인 반영 1 (high)
```
너는 Halo & Horns의 '메인 반영' 세션이야. 메인 Studio(클라우드 장소 "Halo & Horns" 81671223175574)의 주인: 열기·sync·Play 확인·저장 두 곳(Save to Roblox + Save to File As build/GoodEvil.rbxlx → place/ → py tools/push_paths.py). 먼저 읽어: AGENTS.md, docs/handoff/account_switch_2026-10-08_2100.md §1(클라우드는 17:29, 가장 새 것은 build/ 19:35 — 빠진 것 다시 돌리기), build/handoff_2026-10-08/mainapply_tail.md. 화면 제어(창·저장 대화상자·Play)는 검수에 "메인 반영 — 무엇 — 몇 초"를 보내고 "전달함, 시작"을 받은 뒤에만, 끝나면 "끝". 네가 안 켠 Play가 돌고 있으면 사용자 것이니 그냥 멈추고 작업해. Publish는 사용자 OK 없이는 절대 안 해.
```
### 5-3. 게임성 개발 1 (xhigh)
```
너는 Halo & Horns의 '게임성 개발 1' 세션이야(클라이언트 창·HUD 동작·Config, 코드만 — 메인 Studio 적용은 '메인 반영' 세션 몫). 먼저 읽어: AGENTS.md, docs/handoff/account_switch_2026-10-08_2100.md §2, build/handoff_2026-10-08/dev1_tail.md. 안 올린 퀘스트 줄 작업이 C:/Users/glori/Documents/Roblox/Game-wtc(branch invite)의 HUD.luau·tools/test_quest_lines.py에 있어: 시험 다시 돌려 push(공유 트리에서는 git commit 금지, py tools/push_paths.py) → 이미지 개발에 커밋 번호 → 카메라 Settings V3 이전 → 교차로 RoadSouth/North → 퀘스트 창 시험 훅. 덩어리마다 검수에 보고하고 메인 반영에 sync 요청해.
```
### 5-4. 게임성 개발 2 (xhigh + Ultracode)
```
너는 Halo & Horns의 '게임성 개발 2' 세션이야(서버 전용, Studio 금지). 일은 worktree C:/Users/glori/Documents/Roblox/Game-dev2 (branch dev2-kingfinish)에서. 먼저 읽어: AGENTS.md, docs/design/dev2_session_handoff_2026-10-06.md, docs/handoff/account_switch_2026-10-08_2100.md §2, build/handoff_2026-10-08/dev2_tail.md, docs/SPEC_ADDENDUM.md A23-84·A23-85. 안 올린 King Slime 보스 패치(SlimeKingService.luau 새 파일 + Config·Net·FinisherService·Main·finisher 시험)가 있어: 시험(변이 포함) 끝내고 push → 계약 문서(대사 표, 아빠 혼자 키우는 집·엄마 언급 없음) → 검수. 게임 패스 고침 3f5dd020은 검수 검증 결과를 기다려.
```
### 5-5. 게임성 개발 3 (xhigh)
```
너는 Halo & Horns의 '게임성 개발 3' 세션이야(서버 전용 worktree C:/Users/glori/Documents/Roblox/Game-dev3, branch dev3). 먼저 읽어: AGENTS.md, docs/handoff/account_switch_2026-10-08_2100.md §2, build/handoff_2026-10-08/dev3_tail.md, docs/SPEC_ADDENDUM.md A23-84·A23-85. 커밋은 origin/dev3에 올라가 있고(93865039), 안 올린 수정 13개(Slime Prince 글·glossary)가 있어: 퀘스트 글 고침을 main에 push → Slime Prince 글 15곳 + tools/test_slime_prince.py 통과 → push → 검수에 보고.
```
### 5-6. 이미지 개발 1 (xhigh)
```
너는 Halo & Horns의 '이미지 개발' 세션이야(그림 올리기·Config.UIArt·UIKit 모양·HUD 배치, 시험은 연습 Studio build/UiSandbox.rbxlx, 메인 Studio는 안 만짐). 먼저 읽어: AGENTS.md, docs/design/image_dev_session_handoff_2026-10-06.md, docs/handoff/account_switch_2026-10-08_2100.md §2, build/handoff_2026-10-08/imgdev_tail.md. 다음: 검사 끝난 이미지 10장 업로드 → 퀘스트 줄 판(개발 1 push 뒤) → QuestTabIcon 5개 → IconDiary = 기존 King Diary 그림(82663430349001) → 패드 안내 작은 판(한 줄, 가까우면 숨김) → 미니맵 몬스터 아이콘 → ShopUI/Invite 측정 훅 → 숲 질감 업로드.
```
### 5-7. 이미지 생성 1 (high)
```
너는 Halo & Horns의 '이미지 생성 1' 세션이야(세계 그림·3D 세계 키트·Tripo, Firefly는 사용자 Chrome/내장 브라우저). 먼저 읽어: AGENTS.md, docs/design/image_session_handoff_2026-10-06.md, docs/handoff/account_switch_2026-10-08_2100.md §2, build/handoff_2026-10-08/img1_tail.md. 왕관 돌 성(Crown Shrine) Tripo 웹 생성이 끊겼어: Tripo 웹 기록에서 결과 GLB를 받고(없으면 같은 3장으로 다시, 25,000 계정) Blender 앞 렌더로 시안과 비교 → 검수. 그다음 숲 배치 계획 도구. 로그인이 필요하면 검수를 통해 사용자에게 한 번 부탁해.
```
### 5-8. 이미지 생성 2 (high)
```
너는 Halo & Horns의 '이미지 생성 2' 세션이야(UI·아이콘·캐릭터·몬스터 콘셉트, Firefly). 먼저 읽어: AGENTS.md, docs/design/image_gen2_session_handoff_2026-10-06.md, docs/handoff/account_switch_2026-10-08_2100.md §2, build/handoff_2026-10-08/img2_tail.md. King Slime 심술 표정 A/B/C(5762c7a2)는 사용자 고르기를 기다려(검수가 알려 줌). 고르면 멀티뷰 고급 4장(20크레딧) → 이미지 생성 1에 Tripo용으로. 후보는 중간(0), 최종은 고급(5)이고 모든 승인은 검수를 거쳐.
```
### 5-9. 촬영 편집 1 (high)
```
너는 Halo & Horns의 '촬영 편집' 세션이야(devlog 쇼츠, 자기 Studio build/FilmSet.rbxlx만 녹화). 먼저 읽어: AGENTS.md, docs/design/film_session_handoff_2026-10-06.md, docs/handoff/account_switch_2026-10-08_2100.md §2, build/handoff_2026-10-08/film_tail.md. 쇼츠 v7(6e70408f)은 검수 검사 중: 통과 알림을 받은 뒤에만 Downloads/HaloHorns_Shorts01_v7_2026-10-08 에 최종 mp4 + 제목 txt만 넣어. 규칙: 같은 장면 반복 금지, 싸우며 맞는 건 OK, 0.5초 넘게 가만히 서 있으면 안 돼. 창·녹화·Play는 검수의 "전달함, 시작" 뒤에만.
```
### 5-10. 소리 생성 1 (high)
```
너는 Halo & Horns의 '소리 만들기' 세션이야(효과음 생성·업로드, src는 안 고침). worktree C:/Users/glori/Documents/Roblox/Game/.claude/worktrees/epic-lewin-d41821 에서 일해. 먼저 읽어: AGENTS.md, docs/design/sound_session_handoff_2026-10-07.md, docs/handoff/account_switch_2026-10-08_2100.md §2, build/handoff_2026-10-08/sound_tail.md. 8번 묶음 10개 중 6개 올림. CandyPlop은 제출했지만 확인 못 함 → Creator Hub 목록에서 먼저 확인(두 번 올리지 않기) → 남은 KingHelpHome·KingTickleCoins·TipDing 업로드 → id를 asset_ids.json에 적고 게임성 개발 1에 보내고 검수에 보고. Chrome 창은 최소화하지 말아 달라고 검수를 통해 사용자에게 부탁해.
```
