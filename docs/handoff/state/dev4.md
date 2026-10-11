# 게임성 개발 4 — 인계 상태 (2026-10-12 아침, ①②③ main 병합 끝 · ③-3 제작 창 dev4-craft에 쌓음)

10/12 아침: fix/bag-2·dev4-gather·dev4-craft 5d4fc6f3 모두 main에 들어감. dev4-craft에 origin/main을 merge(다시 쓰기 아님, 4a0b467f)한 뒤 ③-3 제작 창을 그 위에 쌓음.

클라 화면만(StarterPlayerScripts·UIKit·클라 시험 + 공용 순수 모듈). 메인 Studio 안 건드림. **보고: 가지 push·사진·결과 = '게임성 검수', UiSandbox 화면 조작 승인·사용자 질문 = '최종 검수'**(list_sessions로 찾기). UiSandbox 창·Play는 최종 검수에 "게임성 개발 4 / 무엇 / 몇 초" → "전달함, 시작" 뒤에만, 끝나면 Play 멈추고 UiSandbox 저장 없이 닫기(Stop-Process 그 pid, 제목에 UiSandbox 확인) → "끝". 바탕화면 마우스·키보드 금지(내 시험 Play 안 Studio MCP user_mouse_input은 승인받고만).
- worktree(sparse src/tools/docs): `Game-dev4w` = `fix/bag-2`(옛 dev4-bag은 main에 병합됨), `Game-dev4g` = `dev4-gather` / `dev4-craft`(같은 폴더, 브랜치 바꿔 씀). 쌓는 순서 fix/bag-2 → dev4-gather → dev4-craft.
- **게임성 검수 10/12 규칙: '병합 가능'으로 보고한 끝 커밋은 절대 다시 쓰지 않음(rebase·push -f 금지).** 그 위에 커밋을 쌓고, 아래 가지의 새 커밋은 `git merge`로 받고, main과 충돌할 때만 `git merge origin/main`(해결 후 커밋). 보고 안 한 내 가지만 rebase 가능.
- 커밋: worktree에서 `git commit -m "짧은 한국어" -- <경로>` → 내 가지만 push(main 금지). 시험이 덮어쓰는 옛 docs/art/verification_* JSON은 커밋 말고 `git restore`(내 새 보고 JSON은 커밋).
- UiSandbox 열기: 실행 중 Studio exe 경로로 `Start-Process <exe> "C:\Users\glori\Documents\Roblox\Game\build\UiSandbox.rbxlx"`; MCP 이름이 "Game"으로 뜰 수 있음 → `STUDIO_ID=<id>`로 고정(execute_luau `game.Name`이 UiSandbox.rbxlx인지 확인). 사진: `STUDIO_ID=<id> py tools/sync_to_studio.py --stop-play` → `STUDIO_ID=<id> py tools/play_bag_photos.py <새 폴더명>` / `py tools/play_craft_photos.py <폴더>`.

## ① 가방 H-1 — main 병합(d688f360) + fix/bag-2 4e6d3f6f(시험 받음)
BagUI.luau(탭 4·등급 칸·입은 칸·설명 칸·Equip/Drink+퀵슬롯/주문서 단계·정렬 4·좁게/넓게), Panels(opts.Width·아이콘·B14·LastEnhance·LastInventory·메뉴 Bag·창이 HUD 아이콘 줄 위에서 끝남(PC만)), HUD(KO1 퀵슬롯 → Use), Config.Settings(BagSort·BagWide). fix/bag-2: 재료 팔기 합계·가방 판매가 Source 빼기, 설명 칸 레이아웃 재사용, 코드 칸 흐리기, 레일 PC만·같은 단위. 시험 test_bag_ui 147·59/59. 사진 pc(8)·pc2(10). 팔기는 나중(개발 2 SellItem — 채집 재료 포함). 아이콘 12개는 디자인 검수 → 이미지 생성 2.

## ② 채집 화면 — dev4-gather bb2cdbfe(게임성 검수 통과, 최종 검수 병합 대기)
GatherView.luau(노드 글 ActionKey/ObjectKey, 나만 쉬는 노드 흐리게). 개발 3 채집 서버는 main에 있음(꺼짐).

## ③ 망치질 — dev4-craft 5d4fc6f3(게임성 검수 '고쳐서 다시' 반영: Space 직접 묶기 → 점프 끄고 JumpRequest = 두드림(BB1), keys_settings·craft_view 45·20/20 통과, 다시 시험 대기)
- 설계 `docs/design/hammer_minigame_2026-10-12.md`, 공용 `Shared/CraftMini.luau`(main에 개발 3 것과 같은 파일), test_craft_mini 45·16/16. 개발 3 CraftService(main, 꺼짐)가 CraftMini로 판정, 원격 CraftStart / CraftSession / CraftStrike(Id,i,ms) / CraftFinish(Id) / CraftResult / CraftInfo.
- CraftView.luau(고리 화면, Skip, Studio 연습 CraftPractice, 그림 키 CraftTarget·CraftIngot·CraftRing 먼저), test_craft_view 41·17/17, 사진 craft_ring/pc 3장.
- 소리 키 HammerPerfect/Great/Good/Miss·CraftDone 없음(소리 만들기에 요청 필요). 그림은 디자인 검수 → 이미지 생성 2.

## ③-3 제작 창 — dev4-craft (게임성 검수 보고 대기)
- `CraftWindow.luau`(Panels 창 "Craft": 제작 Lv+XP 막대, 내 역할 레시피 목록, 재료 have/need·골드·이유 한 줄 = Config.Craft.Text, [Forge] = CraftStart, 고리 끝나면 같은 레시피로 다시 열림, 자리 거리 Far), Panels(opts.Menu 메뉴 줄 · 아이콘 IconHammer), ClientMain ORDER(CraftView 다음). 설계 hammer 문서 §6.
- 시험 `tools/test_craft_window.py` 97·31/31. UiSandbox 사진 pc(10장, 잘림 3개 고침) → 고친 뒤 사진 pc2(2번째 칸 요청함). 사진 `tools/play_craft_window_photos.py <폴더> [--click]`(UiSandbox, 최종 검수 승인 뒤).
- 개발 3이 넣음(origin/dev3-craft2 e16569cf, 게임성 검수 시험 중): CraftInfo.On, NotReady 알림, CraftStation마다 "CraftPrompt"(ActionKey/ObjectKey) → OpenPanel("Craft"). 화면 쪽: 프롬프트 글을 내 언어로 쓰고 그 역할 장인에게만 보이게(CraftWindow.RefreshStations) — 시험 108·39/39.

## 그 뒤 큐
- ④ 연금 계약(개발 3 origin/dev3-alchemy 09a149d0, 설계 docs/design/alchemy_server_2026-10-12.md §4, 스위치 Config.Features.Tonics 꺼짐): Loot.Items Kind "Tonic" 4종(MightTonic·GuardTonic·LuckyTonic·WisdomTonic, Icon IconMightTonic…) → 가방 Use 탭 [Drink] = c->s UseTonic(itemId), 거절 Config.Alchemy.Text.TwoMax / NoTonic. 도는 물약 = 속성 Buff_<itemId>(끝 서버 시각, 0 없음) → 작은 아이콘·남은 시간(3분, 2개까지). 레시피 A1~A4(Kind Item, 결과 병 수 = N + 망치 +N). 퀵슬롯 물약은 개발 2·1(검수가 순서).
④ 연금·조련 창 ⑤ 거래소 창 + 퀘스트 화면(개발 2) ⑥ 장비창 방어구·반지·펫 칸 ⑦ 장인 스킬 효과·장인 채집 Fx "Gather"(그림 오면).
