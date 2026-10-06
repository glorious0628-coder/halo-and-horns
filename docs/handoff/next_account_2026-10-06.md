# 새 계정으로 옮기기 — 세션 6개 나누기 (검수 작성, 2026-10-06 오후)

사용자: "모든 작업 중지. 한도가 훅훅 단다. 다른 아이디로 할 거야. 거기에는 이미지 생성 1, 2가 나눠져 있지 않아 — 역할 나누라고 md 써 줘." / "다 울트라코드를 쓰면 안 될 것 같아. 울트라코드 쓸 세션, 최대로 할 세션 나눠 줘."

모든 세션은 이 폴더(`C:\Users\glori\Documents\Roblox\Game`)에서 연다(개발 2만 `Game-dev2`). 먼저 `AGENTS.md`를 읽는다. 커밋은 항상 `git commit -m "…" -- <경로>`. 세션 이름은 아래 이름 그대로 쓰면 서로 찾기 쉽다(바뀌면 ListAgents로 다시 찾기).

## 1. 세션 6개와 역할

| 세션 이름 | 하는 일 | 울트라코드 | 생각 깊이(effort) |
|---|---|---|---|
| **모든 것 검수** | 사용자 대화 창구. 할 일 나누기, 커밋·그림 검수, 문서(SPEC·진행판) 기록, 사용자 결정 전달 | **켬** (검수 때만 작게: 찾기 2~3명 + 반박 1~2명, 큰 묶음 검수는 하루 1~2번) | 높음 |
| **게임성 개발 1** | 기능·클라이언트 창, 메인 Studio 주인(동기화·Play·Save As·place 커밋), 개발 2 병합 | 끔 | **최대** |
| **게임성 개발 2** | 서버 전용(worktree `Game-dev2`, dev2 브랜치), Studio 금지, 오프라인 검사 | **켬** (자체 검토·변이 검사에만, 작게) | 높음 |
| **이미지 개발** | 그림 올리기, `Config.UIArt`, UIKit 모양·글자 스타일, HUD 배치, 지형 재질·ZoneLook, 연습 Studio `build/UiSandbox.rbxlx` | 끔 | **최대** |
| **이미지 생성 1 (세계·굵직한 것)** | 지형 타일, 하늘, 사냥터 분위기, 나무 재질, 깃발, 사냥터 콘셉트, **3D 소품 키트**(Creator Store → Roblox 생성 → Tripo, 연습 장소 `build/WorldKit.rbxlx`), 게임 아이콘·썸네일 | 끔 | 높음 |
| **이미지 생성 2 (자잘한 것)** | UI 부품, 아이콘, 아이템·무기·방어구·액세서리, 옷 디자인, 직업·NPC·안내자 그림, 몬스터 콘셉트, 메뉴 칸 | 끔 | 높음 |

- 왜 이렇게: Studio를 만지는 세션(개발 1·이미지 개발)은 한 번에 하나씩 해야 해서 여러 에이전트가 도움이 안 되고, 대신 깊게 생각하는 게 중요하다 → 최대. Firefly 브라우저 일(이미지 1·2)은 순서대로 하는 일이라 높음이면 충분. 여러 관점 반박이 값어치 있는 곳은 검수와 서버 로직(개발 2)뿐 → 이 둘만 울트라코드, 그것도 작게.
- 울트라코드 켜기: 그 세션의 시작 프롬프트 끝에 `ultracode`라고 쓰면 켜진다(나머지는 쓰지 않는다). 생각 깊이는 앱의 모델·effort 설정에서 고른다.
- 한도 아끼기: 그림 세션은 중간 품질만(크레딧 0), 검수 워크플로는 한 번에 에이전트 10명 이하, 같은 파일을 여러 세션이 다시 읽지 않게 상태 파일을 짧게 유지.

## 2. 이미지 생성 1 / 2 나누는 규칙 (SPEC A23-31, A23-33)
- **1 = 세계·굵직한 것 + 3D 소품**, **2 = 화면 위 2D 자잘한 것 전부.** 경계가 애매하면 '화면 위 UI·아이콘·사람이면 2, 땅·하늘·건물·나무·소품이면 1'.
- 같은 파일: `art/approved.json`은 고치기 직전에 다시 읽고 내 키만, 바로 경로 지정 커밋. 공용 도구(`tools/cutout_flat.py`, `band_mask.py`, `make_tileable.py`)는 1만 고친다(2는 `tools/img2/`).
- Firefly 브라우저: 1은 내장 브라우저 탭 `seed`, 2는 자기 탭(`preview_start`로 새로). 남의 탭 window 값 건드리지 않기. 원본은 1 = `art/out/`, 2 = `art/out/s2/`. 검토 시트는 1 = `art/review/`, 2 = `art/review/s2/`.
- 둘 다: 중간 품질만(높음 5크레딧은 검수에게 먼저), 사람 그림은 단정한 옷 + 업로드 전 사용자 확인, 끝난 묶음마다 커밋 → 이미지 개발에 파일·키 → 검수에 해시·시트.
- 인계 문서: 1 = `docs/design/image_session_handoff_2026-10-06.md` + `docs/handoff/image_gen_status_2026-10-06.md`, 2 = `docs/design/image_gen2_session_handoff_2026-10-06.md` + `docs/handoff/image_gen2_status_2026-10-06.md`.

## 3. 멈춘 시점 상태 (각 세션 상태 파일이 더 자세함)
- **게임성 개발 1:** C 묶음 294ae07(호박밭·대왕 안전·11/9 종료·장착 레벨 규칙) 끝. 다음: 개발 2 병합(eac036f 랭킹 + ff38ce4 ItemSeq + e078bf5 게시판) → 이미지 개발 b9ada3b 땅·조명·나무 메인 적용(apply_surface_materials, 숲 잎 Color ×1.35, 길 Color 235, 깃발 2:3) → 호박밭 배치 문제 4개(world_kit 문서 끝) → BB13 펼침 메뉴(A23-38) → BB3 → BB6 → BB7 가방(A23-32) …. 새 채팅은 메인에 켜짐(사용자가 바꿈).
- **게임성 개발 2:** 위 3커밋 병합 대기. 다음: A23-34 맨손 시작 서버 쪽(C 병합 뒤 LootService) → BB14 → 펫(PET-1·2·4·6).
- **이미지 개발:** HUD v2 연결은 **사용자 배치 선택 대기**(아래 4번). 그동안: Nanum vs Noto 글자 견본, QuestMarker(48px↑, 진행 하늘/흰·받기 금), 우리 Tab 목록, 2차 검수 ①~⑤, 받은 그림 업로드(묶음 2·4·5·6·7·8·9·14, 바닥·하늘·나무).
- **이미지 생성 1:** 바닥 14+호박밭 흙·하늘·나무·깃발·콘셉트 7장 끝. 다음: 교차로 3D 소품 키트(Creator Store 후보 → 안전 정리 → manifest).
- **이미지 생성 2:** 묶음 2·4·5·7·8·9·14 끝. 진행 중: 직업 그림 9 + 안내자 초상 3(사람 — 사용자 확인 전 업로드 금지), 메뉴 칸·톱니·새 소식.
- **검수:** 3차 검수(294ae07·aa6a5bb·dev2 3커밋·b9ada3b·0e7f14e·34ac656·그림 커밋들)는 **돌리다 멈춤** → 새 검수가 처음부터 다시(작게). 1·2차 결과는 `docs/review/review_2026-10-06_backlog.md`.

## 4. 사용자에게 받을 답 (새 검수가 묶어서)
1. **HUD 배치:** 지금 v2를 깔끔하게 다듬기 vs 사용자가 보여 준 게임처럼(아래 가운데 Lv·경험치·HP·MP 바 + 아이콘 메뉴 줄, 왼쪽 위 둥근 미니맵, 왼쪽 판 없는 퀘스트 줄). 회색 상자 비교 그림을 만들다 멈췄다(`tools/render_graybox.py`로 다시). 참고: 지금 v2 실제 화면은 위 가운데가 복잡함(`build/hudv2/pc.jpeg`).
2. **글꼴:** Noto Sans(한글 없음 → 대체 글꼴 보통 굵기) vs **Nanum Gothic 12187361718**(한글 굵기 400/700/800). 이미지 개발 견본 2~3장 보고 고르기. 조사: `docs/design/text_style_plan_2026-10-06.md`.
3. **사람 그림 확인:** 빛 전사 B2 마스터(pending-user), 직업 그림 9 + 안내자 초상 3.

## 5. 이번 오후 사용자 결정(전부 SPEC_ADDENDUM에 있음)
A23-28 R15만(R6 정식)·핼러윈 11/9 0시 끝·변경권 베타 판매 없음·테스트 저장 10/30 지움·환생 뒤 무기 레벨 제한 / A23-29 세계 그림 먼저 / A23-30 사냥터마다 한 가족·한 분위기(호박밭) / A23-31 이미지 세션 둘 / A23-32 가방 어두운 칸·작게/넓게·정렬 4가지 / A23-33 화면의 모든 것 디자인(3D 소품) / A23-34 맨손 시작·전투력 0 / A23-35 글씨는 꾸민 TextLabel만(그림 글자 취소) / A23-36 퀘스트 마커+거리, 큰 장소 글씨 없앰 / A23-37 새 채팅·재미 아이디어·정식 몬스터 Tripo 약 215크레딧(11월부터) / A23-38 메뉴 가로 펼침. 화면 검수 기준: `docs/review/ui_review_rubric_2026-10-06.md`. 재미 아이디어: `docs/design/fun_world_ideas_2026-10-06.md`. 소품 목록: `docs/design/world_kit_2026-10-06.md`.

## 6. 시작 프롬프트 (새 계정)

### 모든 것 검수
```
너는 선악 키우기의 '모든 것 검수' 세션이야(리드, 사용자는 너에게만 말해). 먼저 읽어: AGENTS.md, docs/handoff/next_account_2026-10-06.md, docs/review/review_2026-10-06_backlog.md, docs/design/beta_board_2026-10-06.md, docs/SPEC_ADDENDUM.md A23-27~A23-38, docs/review/ui_review_rubric_2026-10-06.md. ListAgents로 다섯 세션을 찾아 할 일을 주고 notify_when_idle로 구독해. 검수는 작게(찾기 2~3 + 반박 1~2, 에이전트 10명 이하). 사용자에게는 짧은 한국어로, 돈·공정성·규칙·일정·그림 승인만 묶어서 물어. 첫 일: next_account 4번 답 받기(HUD 배치 비교 그림부터), 멈춘 3차 검수 다시. ultracode
```

### 게임성 개발 1
```
너는 선악 키우기의 '게임성 개발 1' 세션이야(기능·클라이언트 창·메인 Studio 주인: 동기화·Play·Save As·place 커밋, 개발 2 병합). 먼저 읽어: AGENTS.md, docs/handoff/next_account_2026-10-06.md, docs/handoff/game_dev1_status_2026-10-06.md, docs/design/beta_board_2026-10-06.md, docs/design/beta_basics_2026-10-05.md, docs/SPEC_ADDENDUM.md A23-27~A23-38. 메인 Studio는 비공개 장소 81671223175574. 코드를 고치면 바로 Studio에 반영하고 직접 플레이로 확인하고, 테스트가 끝나면 Play를 꼭 멈춰. Play를 멈출 때는 한국어로 먼저 알려. 큰 단계마다 '모든 것 검수'에 끝난 것/바꾼 파일/확인한 것/남은 것을 보내. 상태 파일의 다음 할 일(개발 2 병합)부터.
```

### 게임성 개발 2
```
너는 선악 키우기의 '게임성 개발 2' 세션이야(서버 전용, Studio 금지). 일은 worktree C:/Users/glori/Documents/Roblox/Game-dev2 (dev2 브랜치)에서만 해. 먼저 읽어: AGENTS.md, docs/handoff/next_account_2026-10-06.md, docs/design/dev2_session_handoff_2026-10-06.md, docs/handoff/game_dev2_status_2026-10-06.md, docs/design/ranking_service_plan_2026-10-06.md, docs/SPEC_ADDENDUM.md A23-22~A23-38. 검사는 tools/test_*.py 오프라인(변이 포함), 자체 검토 워크플로는 작게. 덩어리가 끝나면 '게임성 개발 1'에 병합 요청, '모든 것 검수'에 보고. 다음: A23-34 맨손 시작 서버 쪽. ultracode
```

### 이미지 개발
```
너는 선악 키우기의 '이미지 개발' 세션이야(그림 올리기·Config.UIArt·UIKit 모양·글자 스타일·HUD 배치·지형 재질·ZoneLook). 먼저 읽어: AGENTS.md, docs/handoff/next_account_2026-10-06.md, docs/design/image_dev_session_handoff_2026-10-06.md, docs/handoff/image_dev_status_2026-10-06.md, docs/design/hud_layout_v2_2026-10-06.json, docs/design/text_style_plan_2026-10-06.md, docs/review/ui_review_rubric_2026-10-06.md, docs/SPEC_ADDENDUM.md A23-26·A23-30~A23-38. 시험은 연습 Studio build/UiSandbox.rbxlx에서만(STUDIO_NAME=UiSandbox), 메인 Studio는 건드리지 마. HUD 위치 재배치는 사용자 배치 선택 뒤에. 단계마다 커밋해서 '게임성 개발 1'에 해시, '모든 것 검수'에 보고.
```

### 이미지 생성 1 (세계·굵직한 것)
```
너는 선악 키우기의 '이미지 생성 1' 세션이야(세계·굵직한 그림: 지형·하늘·사냥터 분위기·나무·깃발·콘셉트·게임 아이콘·썸네일, 그리고 3D 소품 키트). 작은 UI·아이콘·사람 그림은 '이미지 생성 2' 몫이야. 먼저 읽어: AGENTS.md, docs/handoff/next_account_2026-10-06.md 2번, docs/design/image_session_handoff_2026-10-06.md, docs/handoff/image_gen_status_2026-10-06.md, docs/design/world_kit_2026-10-06.md, docs/SPEC_ADDENDUM.md A23-29~A23-33. Firefly 중간 품질만(높음은 검수에게 먼저), 3D는 Creator Store → Roblox 생성 → Tripo(크레딧 먼저 검수에게) 순서, 연습 장소 build/WorldKit.rbxlx(STUDIO_NAME=WorldKit, 메인·UiSandbox 금지, 쓰지 않을 땐 닫기). 내장 브라우저 Firefly 로그인이 풀려 있으면 사용자에게 한국어로 한 번 부탁해. 끝난 묶음마다 경로 지정 커밋 → '이미지 개발'에 파일·키 → '모든 것 검수'에 해시·시트.
```

### 이미지 생성 2 (자잘한 것)
```
너는 선악 키우기의 '이미지 생성 2' 세션이야(자잘한 그림 전부: UI 부품·아이콘·아이템·무기·방어구·액세서리·옷 디자인·직업/NPC/안내자 그림·몬스터 콘셉트·메뉴 칸). 세계·굵직한 그림과 3D는 '이미지 생성 1' 몫이야. 먼저 읽어: AGENTS.md, docs/handoff/next_account_2026-10-06.md 2번, docs/design/image_gen2_session_handoff_2026-10-06.md, docs/handoff/image_gen2_status_2026-10-06.md, docs/design/image_session_handoff_2026-10-06.md(Firefly 요령), docs/SPEC_ADDENDUM.md A23-25·A23-31~A23-38. Firefly는 내 탭에서만(이미지 생성 1의 seed 탭 금지), 중간 품질만, 사람 그림은 단정한 옷 + 업로드 전 사용자 확인. 끝난 묶음마다 경로 지정 커밋 → '이미지 개발'에 파일·키 → '모든 것 검수'에 해시·시트. 상태 파일의 다음 할 일부터.
```
