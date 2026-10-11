# 게임성 개발 4 — 인계 상태 (2026-10-12 새벽, ① 가방·② 채집 화면 push, 가방 UiSandbox 사진 다시 찍기 대기)

클라 화면만(StarterPlayerScripts·UIKit 사용·클라 시험). 메인 Studio 안 건드림. **보고: 가지 push·사진·결과 = '게임성 검수', UiSandbox 화면 조작 승인·사용자 질문 = '최종 검수'**(둘 다 list_sessions로 찾기). UiSandbox 창·Play는 최종 검수에 "게임성 개발 4 / 무엇 / 몇 초" 보내고 "전달함, 시작" 뒤에만, 끝나면 Play 멈추고 UiSandbox 저장 없이 최소화/닫기 → "끝".
- worktree(sparse src/tools/docs): `Game-dev4w` = 가지 `dev4-bag`, `Game-dev4g` = 가지 `dev4-gather`(**dev4-bag 위에 쌓음**: ClientMain ORDER "QuestBook", "BagUI", "GatherView"; dev4-bag을 고치면 `git rebase origin/dev4-bag` 후 `push -f`). 비교용 `Game-dev4base`(origin/main). build/luau_cli_0_741 복사해 둠.
- 커밋: worktree에서 `git commit -m "짧은 한국어" -- <경로>` → 내 가지만 push(main 금지, 병합은 검수). 시험이 덮어쓰는 옛 docs/art/verification_* JSON은 커밋하지 말고 `git restore`.

## ① 가방 창 H-1 (BB7, A23-32) — dev4-bag 923f2d01
- `BagUI.luau`(Panels 창 "Bag", HUD 가방 칸·I 키): 탭 Gear·Use·Scrolls·Materials(새 것 수 BadgeDot), 승인 등급 칸 SlotCommon~Legendary + SlotEmpty 줄 채움, +N·개수·장착 GlyphCheck·새 것 점, Gear 위 입은 칸 Weapon·Armor·Ring·Pet(방어구·반지·펫 장비 = 빈 자리), 설명 칸(공격력·전투력 A→B(낄 수 있는 무기만)·레벨 잠금·개수·판매가·잡아 본 몬스터 중 주는 것), Equip / Drink+퀵슬롯 / 주문서 Use→무기 고르기→Enhance·Move, 아래 줄 골드·정렬(Newest·Name·Grade·Type = Settings.BagSort)·좁게/넓게(Settings.BagWide). arg = { Tab, Select } 또는 { Use = 주문서, Tier | From/To }.
- 공용: Panels(opts.Width·Bag 아이콘·B14 반짝 끔·`Panels.LastEnhance()`), HUD(KO1 퀵슬롯 줄 → 가방 Use), ClientMain(+BagUI), Config.Settings(BagSort 옵션·BagWide).
- 팔기 없음(A23-127 오토·SellItem 정해지면). 결과 문장은 서버 토스트만(A23-130).
- 시험: `py tools/test_bag_ui.py` 128 검사·46/46. 기대값 고친 것: test_keys_settings·test_quick_slots·test_skill_book.
- 실제 화면: UiSandbox 첫 사진 1장(`docs/art/verification_2026-10-12/bag_ui/pc/01_gear_narrow.png`, 고치기 전, 커밋 안 함) — 창·탭·칸·설명·아래 줄 정상, 입은 칸 글자 겹침·Lv40 무기 전투력 줄은 고침. **나머지 7장은 PC 꺼짐으로 끊김 → 최종 검수에 다시 신청함.** 사진 도구: `STUDIO_NAME=UiSandbox py tools/play_bag_photos.py pc`(먼저 `STUDIO_NAME=UiSandbox py tools/sync_to_studio.py --stop-play`; UiSandbox 열기 = 실행 중 Studio exe 경로로 Start-Process build/UiSandbox.rbxlx(본 트리 Game/build)). 끝나면 UiSandbox 최소화(user32 ShowWindow 6) 또는 저장 없이 닫기.

## ② 채집 G 꾹 화면 — dev4-gather b5022764
- `GatherView.luau` = 개발 3 gather_server_2026-10-11.md §7 클라 몫: GatherPrompt 글을 ActionKey/ObjectKey로(L10n, 한국어, 언어 바뀌면 다시), s->c GatherState Ready → 나만 쉬는 노드 프롬프트 끔·흐리게·반짝이/빛 끔, 시간 지나면 되돌림. 첫 안내 줄 없음(A23-130), 장인 Fx "Gather"는 ⑦.
- 개발 3 확인(10/12): GatherState를 Net.Names에, 노드·키 모양 그대로, 서버는 Enabled 안 바꿈. 서버 코드 = api/dev3-gather(기준 dev3-v4-tables) — 들어오면 개발 3이 가지 이름 알려 줌 → 그때 실제 노드 확인.
- 시험: `py tools/test_gather_view.py` 27 검사·16/16.

## 다음 큐 (검수가 바꾸지 않으면)
1. 가방 사진 7장 다시 → 게임성 검수 보고.
2. ③ 제작 창 + 망치질 미니게임: **참고 게임 검색 먼저(A23-133)** → 손맛 설계 메모 → 개발 3과 CraftService·두드림 간격 remote 맞추기.
3. ④ 연금·조련 창 ⑤ 거래소 창 + 퀘스트 화면(개발 2와 MarketBrowse/MarketPage 등, crafting_market §6-6) ⑥ 장비창 방어구·반지·펫 칸 ⑦ 장인 스킬 효과.
