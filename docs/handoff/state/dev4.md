# 게임성 개발 4 — 인계 상태 (2026-10-12, ① 가방·② 채집 화면·③-1 망치질 판정 push)

클라 화면만(StarterPlayerScripts·UIKit·클라 시험 + 공용 순수 모듈). 메인 Studio 안 건드림. **보고: 가지 push·사진·결과 = '게임성 검수', UiSandbox 화면 조작 승인·사용자 질문 = '최종 검수'**(list_sessions로 찾기). UiSandbox 창·Play는 최종 검수에 "게임성 개발 4 / 무엇 / 몇 초" → "전달함, 시작" 뒤에만, 끝나면 Play 멈추고 UiSandbox 저장 없이 닫기(Stop-Process 그 pid, 제목에 UiSandbox 확인) → "끝". 바탕화면 마우스·키보드 금지(내 시험 Play 안 Studio MCP user_mouse_input은 승인받고만).
- worktree(sparse src/tools/docs): `Game-dev4w` = `dev4-bag`, `Game-dev4g` = `dev4-gather` / `dev4-craft`(같은 폴더, 브랜치 바꿔 씀). **쌓는 순서 dev4-bag → dev4-gather → dev4-craft**(ClientMain ORDER 한 줄 겹침 때문): bag을 고치면 gather를 `git rebase origin/dev4-bag`, craft를 `git rebase --onto dev4-gather <옛 gather 끝> dev4-craft` 후 둘 다 `push -f`. 비교·시험 병합용 `Game-dev4base`(origin/main). build/luau_cli_0_741 복사해 둠.
- 커밋: worktree에서 `git commit -m "짧은 한국어" -- <경로>` → 내 가지만 push(main 금지). 시험이 덮어쓰는 옛 docs/art/verification_* JSON은 커밋 말고 `git restore`(내 새 보고 JSON은 커밋).
- UiSandbox 열기: 실행 중 Studio exe 경로로 `Start-Process <exe> "C:\Users\glori\Documents\Roblox\Game\build\UiSandbox.rbxlx"`; MCP 이름이 "Game"으로 뜰 수 있음 → `STUDIO_ID=<id>`로 고정(execute_luau `game.Name`이 UiSandbox.rbxlx인지 확인). 사진: `STUDIO_ID=<id> py tools/sync_to_studio.py --stop-play` → `STUDIO_ID=<id> py tools/play_bag_photos.py <새 폴더명>`(Game-dev4w에서).

## ① 가방 H-1 — dev4-bag 7a2c9afd (게임성 검수 시험 중)
BagUI.luau(탭 4·등급 칸·입은 칸·설명 칸·Equip/Drink+퀵슬롯/주문서 단계·정렬 4·좁게/넓게), Panels(opts.Width·아이콘·B14·LastEnhance·LastInventory·메뉴 Bag·창이 HUD 아이콘 줄 위에서 끝남), HUD(KO1 퀵슬롯 → Use), Config.Settings(BagSort·BagWide). 검수 고칠 것 1~8 + 사진 1·2차 고침 다 반영. 시험 test_bag_ui 142·54/54. 사진 pc(8장)·pc2(10장). 팔기는 나중(개발 2 SellItem — 채집 재료 팔기 포함). 아이콘 12개(IconPetal 등)는 디자인 검수 → 이미지 생성 2가 그림.

## ② 채집 화면 — dev4-gather 1d935025
GatherView.luau(노드 글 ActionKey/ObjectKey, 나만 쉬는 노드 흐리게). 개발 3 서버 origin/dev3-gather와 시험 병합 충돌 0·27/27. 병합 순서 bag → dev3-gather → dev4-gather.

## ③ 망치질 — dev4-craft 1634e079
- 설계 `docs/design/hammer_minigame_2026-10-12.md`(참고 검색, 게임성 검수 OK + 고침: 두드림마다 서버 확인, 나가기 +0, 입력 막기, Skip).
- 공용 `Shared/CraftMini.luau`(고정 일정·Grade·Score·Check·Accept), test_craft_mini 42·14/14.
- **열린 것:** 개발 3은 '누름 기준 일정 + Strike(id,i) + Finish(id, hits)' 안, 나는 '고정 일정 + Strike(Id,i,ms) + Finish(Id)' 안 → 개발 3에 하나로 정하자고 물음(내 안 추천). 답 오면 CraftMini 맞추고 게임성 검수에 한 번 알림.
- 다음: ③-2 고리 화면 CraftView(UIKit 대체 원, 클릭·Space 막아 두드림만, 폰 탭, 판정 글자 4, Skip, Studio 연습 모드 속성) → UiSandbox 사진. Config.Sounds에 망치 소리 없음(소리 만들기에 4개 요청 필요). 고리·표적·달군 쇠 그림은 디자인 검수에 요청 필요.

## 그 뒤 큐
④ 연금·조련 창 ⑤ 거래소 창 + 퀘스트 화면(개발 2) ⑥ 장비창 방어구·반지·펫 칸 ⑦ 장인 스킬 효과·장인 채집 Fx "Gather"(그림 오면).
