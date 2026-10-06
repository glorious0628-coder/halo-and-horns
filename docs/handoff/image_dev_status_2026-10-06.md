# 이미지 개발 인계 상태 (2026-10-06, 사용량 한도로 멈춤)

- **끝난 것(push 완료):**
  - 새 그림 업로드·적용: a62c6e8(20장), aebf974(PvP 탭), 938c230(진영 특성 10장).
  - 알림 그림: bff00df(드랍 알림·호박 대왕 공지 그림, UIKit.Toast/Announce icon 인자).
  - UIKit.ItemIcon(띠 색)·CharacterIcon 함수, 호박 대왕 알약 폭(f0e011a).
  - ART-DEL1 정리 7dd8103(빈 키 그림 78장·로그 삭제, 9개 남김: docs/art/art_cleanup2_2026-10-06.json), asset_ids 키 UIP_ 정리 9759dd3.
- **HUD v2(A23-26):** 1단계 시작 단계. `src/StarterPlayer/StarterPlayerScripts/HudLayout.luau`(커밋 안 됨, 문법 OK, 아직 어디서도 require 안 함)에 v2 사각형 → 논리 단위 계산, 폰 안전 영역 비율 축소, 누르는 칸 최소 60du, 가운데 열 맞춤이 들어 있어요.
  - luau.exe 오프라인 검사(1280×720, 1024×768, 749×361 안전 655×340, 844×390)에서 겹침 0이에요. 검사 스크립트는 scratch에만 있어요.
  - HUD.luau는 아직 안 고쳤어요.
  - 다음 순서: ClientMain ORDER에 HudLayout 추가 → HUD applyLayout가 Rects를 쓰게 → 왼쪽 위 얼굴·HP·MP·전투력·경험치 → 오른쪽 위 줄·퀘스트 판 → 전투 묶음 → EventHUD Strip/Personal/Luck·GrudgeGhost G.Place(게임성 개발 허락받음).
- **커밋 안 한 파일:** HudLayout.luau(위 설명), tools/terrain_view.py(Play 화면에서 지형 재질별 캡처. LeafyGrass·Basalt·Cobblestone 자리 좌표가 마을로 잘못 잡혀 고쳐야 함).
- **연습 Studio:** build/UiSandbox.rbxlx가 열려 있고 최소화했어요(Edit 모드, 기기 흉내 default로 복원).
  - 도구는 `STUDIO_NAME=UiSandbox`와 `tools/device_view.py pc|phone|844`를 써요.
  - 창이 최소화되면 3D가 하얗게 찍혀요. 사용자 허락이 있어 ShowWindow로 잠깐 열 수 있어요.
- **받았지만 안 올린 그림:** 없어요.
  - 옛 UIP_IconPouch 파일(ui·out)은 메인 Studio 동기화를 확인한 뒤 지워요.
  - 9개(FactionE 6, FactionTitle_FreshTyped, IconLock ui·out)는 묶음 2·13 뒤에 지워요.
- **다음 할 일:** HUD v2 1~5(10/10 목표), 6 미니맵·7 전투 묶음(10/12 목표). 지형 15장은 그림이 오면 Config Tex_ Id를 바꾸고 apply_surface_materials.lua를 돌린 뒤 terrain_view로 확인해요.
