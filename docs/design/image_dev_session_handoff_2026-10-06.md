# 이미지 개발 세션 인계 + 두 개발 세션 나누기 (검수 세션, 2026-10-06)

사용자 결정(2026-10-06): 세션 4개 — **이미지**(그림) · **이미지 개발**(그림·화면을 게임에 넣기) · **게임성 개발**(기능, 지금의 '개발' 세션) · **검수**(이끌기·검사). 검수 세션이 일을 정하고 결과를 검사한다.
> 2026-10-09 검수: 지금은 세션 10개(`docs/handoff/role_prompts/README.md`). 이 글의 '게임성 개발' 칸은 지금 둘로 나뉨: 창·HUD 동작·Config = 게임성 개발 1(클라이언트 코드만, worktree Game-wtc), 서버·시험 = 게임성 개발 2·3(worktree Game-dev2·Game-dev3). **메인 Studio 주인(sync·Play 사진·저장·`place/` 커밋)은 메인 반영 1**(10/08부터), 검증 통과한 개발 2 브랜치의 main 병합은 검수. 지금 할 일은 `docs/handoff/role_prompts/05_imgdev.md`.

먼저 읽을 것: `AGENTS.md`, `docs/design/visual_direction_2026-10-05.md`(스타일·화면 배치·묶음), `docs/design/image_session_handoff_2026-10-06.md`(그림 흐름), 이 문서.

## 누가 무엇을 맡나 (파일 주인)
| 영역 | 이미지 개발 | 게임성 개발 |
|---|---|---|
| 그림 올리기(≤10장씩)·`art/ui/asset_ids.json` | ✅ | |
| `Config.UIArt` 전체(`Config.luau`의 `Config.UIArt = {`부터 `Config.UIArt.FactionE` 끝까지) | ✅ | |
| `UIKit.luau`, `FactionPicker.luau`, `ClassPicker.luau`, `VitalsUI.luau`의 모양 | ✅ | |
| `HUD.luau` 배치(`L` 표의 위치·크기, `applyLayout`, UIScale) | ✅ | |
| 지형 텍스처·MaterialService(`tools/apply_surface_materials.lua`) | ✅ | |
| 옛 그림 삭제(새 그림이 Studio에 들어간 뒤), 화면 캡처 검사 | ✅ | |
| 서버 서비스 전부(`src/ServerScriptService/*`), `Net.luau`, 게임 수치 표 | | ✅ |
| `Panels.luau` 창 내용·기능, 새 창 모듈(가방·스킬·랭킹 …), `Keybinds`, `Settings`, `EventHUD` 동작 | | ✅ |
| 테스트 러너·fixture(`tools/test_*`, `tools/fixtures/*`) | | ✅ |
| 장소 파일 저장·`place/` 커밋, 메인 Studio 동기화·Play | | ~~✅~~ → 메인 반영 1 |

**같이 쓰는 파일**(`Config.luau`의 나머지, `HUD.luau`의 게임 상태 연결, `Panels.luau`, `ClientMain`/`Main`의 모듈 목록): 고치기 전에 상대에게 SendMessage로 "어느 파일 어느 부분"을 알리고, 고치기 직전에 다시 읽고, 작게 고친다. 새 창은 게임성 개발이 `UIKit` 코드 대체 모양으로 기능을 먼저 만들고, 이미지 개발이 승인된 부품으로 모양을 입힌다.

## Studio 두 개 (서로 Play를 멈추지 않게)
- **메인 Studio**(비공개 장소 81671223175574): ~~게임성 개발이 주인이다~~ → **메인 반영 1**이 주인이다. 동기화·Play·Save to Roblox + File > Save to File As `build/GoodEvil.rbxlx`·`place/` 커밋은 메인 반영 1만 한다.
- **이미지 개발용 연습 Studio:** `build/GoodEvil.rbxlx`를 `build/UiSandbox.rbxlx`로 복사해 두 번째 Studio로 연다(게시 금지, `build/GoodEvil.rbxlx`·`place/`에 덮어쓰기 금지).
  - 이미지 개발의 모든 Studio 도구 호출에는 `STUDIO_NAME=UiSandbox`를 붙인다. 예: `STUDIO_NAME=UiSandbox py tools/sync_to_studio.py`, PowerShell은 `$env:STUDIO_NAME='UiSandbox'; py tools/studio_mcp.py call …`.
  - 이름에 'GoodEvil'을 넣지 않는다. 기본 선택 규칙("GoodEvil|81671223175574")이 연습 Studio를 메인으로 잘못 고르지 않게 하기 위해서다.
  - 연습 Studio는 게시되지 않아 DataStore 대신 메모리 저장으로 돈다. 화면 확인용으로는 충분하다.
  - PC가 느려지면 연습 Studio를 닫는다. ~~메인 Studio에서 게임성 개발에게 "Play 써도 돼요?"라고 묻고 짧게 쓴다~~ → 메인 Studio는 만지지 않는다(메인 사진은 메인 반영 1에 부탁).
- **메인 Studio에 넣기:** ~~자기 파일만 경로로 커밋하고, 게임성 개발에게 … 게임성 개발이 메인 Studio에 동기화~~ → 지금(10/09): 새 일은 origin/main에서 새 브랜치(Game-imgdev 계열 worktree)로 하고, UiSandbox에서 확인한 덩어리만 main에 올린 뒤 해시·바뀐 파일·확인할 화면을 '모든 것 검수'에 보낸다(덩어리마다 한 번). 메인 Studio 반영은 메인 반영 1이 sync해 Play 사진(UI는 PC 먼저, A23-98)으로 확인한다.
- 동기화 도구는 작업 폴더의 **바뀐 src 전부**를 올린다. 두 세션 모두 반쯤 고친 상태로 오래 두지 말고, 고칠 때마다 `py tools/luau_check.py <files>` 또는 `build/luau_cli_0_741/luau-compile.exe`로 문법을 맞춰 둔다.

## 공통 규칙
- 사용자에게는 **한국어로 짧게**. 클릭을 부탁하지 않는다. 큰 덩어리가 되면 "해 볼 수 있어요"라고 알린다.
- 커밋은 자기 파일만 경로로 하나씩 추가한다(`git add -A` 금지). 커밋 제목은 짧은 한국어로 쓴다. 공유 트리(`Game`)에서는 `git commit` 금지 — `py tools/push_paths.py -m "제목" <경로>`(AGENTS Hard rule 5).
- 큰 단계마다 ~~검수 세션(ListAgents 이름 **검수**)~~ **'모든 것 검수' 세션(id는 list_sessions로 찾기)**에 보고한다: 끝난 것 / 바꾼 파일 / 직접 확인한 것 / 남은 것.
- 옛 그림은 새 그림이 승인·업로드되고 Studio에 들어간 뒤에만 지운다(화면이 비면 안 된다). `art/out/v1/`와 노출 사본은 절대 올리지 않는다.
- 업로드한 그림은 Studio에서 1280×720과 749×361로 실제 크기를 보고, 밝은·어두운 배경에서 테두리 얼룩을 확인한다.

## 이미지 개발 첫 일 (순서)
> 2026-10-09 검수: 이 절은 낡음(10/06 첫 일, 끝났거나 바뀜 — HUD는 A23-74·81·94, UI는 PC 먼저 A23-98). 지금 할 일은 `docs/handoff/role_prompts/05_imgdev.md`와 `docs/design/ui_clutter_review_2026-10-09.md`.

1. 연습 Studio 준비(위 방법). 메인 Studio는 건드리지 않는다.
2. **그림 넣기 인수:** 게임성 개발이 지금 작업 트리에 넣고 있는 `UIArt` 키 7개(IconMon* 5 + IconCandy + IconPetBabySlime)와 퀘스트 줄 아이콘은 게임성 개발이 핼러윈 커밋과 함께 끝낸다. 그 뒤로 오는 그림은 전부 이미지 개발이 넣는다.
   - 메뉴 버튼 5장(IconBag 110554679799730, IconCharacter 85845386405558, IconSkills 113811090785765, IconRanking 119501472065745, IconHelp 102236302870647)은 게임성 개발이 **이미 올렸고**, 핼러윈 커밋에서 `Config.UIArt.Parts`에 Id만 넣는다. 다시 올리지 않는다.
   - IconCharacterF부터는 이미지 개발이 올린다. 'CharacterGender'가 "F"면 IconCharacterF, 아니면 IconCharacter를 쓰고, 속성이 바뀌면 다시 그린다. 메뉴 화면(BB13)은 게임성 개발이 만든다.
   - 호박 대왕 EventHUD 알림이 상태판과 겹치는 것은 게임성 개발이 핼러윈 커밋에서 고친다.
   - 드랍 알림과 호박 대왕 공지 아이콘(IconMon*)을 붙인다(핼러윈 범위).
   - 이어서 이미지 세션이 보내는 몬스터 머리 5 · 재료 6 · 주문서 1 · 랭킹 탭 3.
3. **HUD 배치 바꾸기:** 검수 세션이 회색 상자 배치(PC 1280×720 + 폰 749×361)를 사용자에게 승인받아 보내면, 그 배치대로 `HUD.luau` 배치를 바꾼다. 그림이 아직 없으면 지금 부품 그대로 자리만 옮긴다. 검수에서 나온 폰 전투력 줄 겹침(+N 팝업이 금고 줄을 덮음, 물약·퀘스트가 조이스틱 자리로 내려감)도 이때 같이 정리한다.
4. 그 뒤: 묶음 1 스타일 보드가 승인되면 공통 창 키트 → HUD 부품 → 진영 화면 순서로 갈아 끼우고, 바꾼 옛 그림을 지운다.
