# 게임성 개발 4 — 인계 상태 (2026-10-12 새벽, ① 가방 창 첫 판 끝·보고 전)

클라 화면만(StarterPlayerScripts·UIKit 사용·클라 시험). 메인 Studio 안 건드림. UiSandbox 창·Play는 검수에 "게임성 개발 4 / 무엇 / 몇 초" 보내고 "전달함, 시작" 뒤에만. 보고 = 검수(list_sessions로 '모든 것 검수' 찾기) 덩어리마다 한 번 → 턴 끝.
- worktree(sparse src/tools/docs): `C:/Users/glori/Documents/Roblox/Game-dev4w`, 브랜치 `dev4-bag`. 비교용 `Game-dev4base`(origin/main, 읽기·시험 전용). build/luau_cli_0_741 복사해 둠.
- 커밋: worktree에서 `git commit -m "짧은 한국어" -- <경로>` → 내 브랜치만 push(main 금지, 병합은 검수). 시험이 덮어쓰는 옛 docs/art/verification_* JSON은 커밋하지 말고 `git restore`.

## ① 가방 창 H-1 (BB7, A23-32) — 첫 판 끝
- 새 `BagUI.luau`(Panels 창 "Bag", HUD 가방 칸·I 키가 이제 이 창을 엶): 탭 Gear·Use·Scrolls·Materials(새 것 수 = BadgeDot), 승인된 어두운 등급 칸(SlotCommon~Legendary, 빈 칸 SlotEmpty로 줄 채움), +N 왼쪽 위·개수 오른쪽 아래·장착 GlyphCheck·새 것 점, Gear 위 '입은 칸' Weapon·Armor·Ring·Pet gear(방어구·반지·펫 장비는 서버 데이터 없음 → 빈 자리), 오른쪽 설명 칸(공격력·전투력 변화·레벨 잠금·개수·판매가·잡아 본 몬스터 중 주는 것), 버튼 Equip / Drink + 퀵슬롯 1·2·3 / 주문서 Use → 무기 고르기 → Enhance·Move(성공률·실패 결과를 보내기 전에 보여 줌), 아래 줄 골드·정렬(Newest·Name·Grade·Type, Settings.BagSort)·좁게/넓게(4↔8열, Settings.BagWide).
- 데이터 = 지금 Inventory remote(Items·Enhance·Seen·ItemSeq·WeaponSeq) + 속성. Spares("tier:plus")는 서버가 보내면 바로 Gear에 뜸(A23-127 C2).
- 고친 곳: Panels(opts.Width·Bag 아이콘·가방 열면 B14 반짝 끔·`Panels.LastEnhance()`), HUD(KO1 퀵슬롯 줄 → 가방 Use 탭), ClientMain ORDER(+BagUI), Config.Settings(BagSort 옵션 Default/Name/Grade/Kind, BagWide Bool, 옛 "Count" → Default).
- 결과 글은 서버 토스트가 이미 말하므로 가방에 다시 안 씀(A23-130).
- 팔기 없음: 옛 SellMaterials는 대장간 창에 그대로. 골라 팔기는 서버 SellItem + A23-127 오토(재료·여분 사기) 정해지면.
- 시험: `py tools/test_bag_ui.py`(새, 124 검사·45 변이), test_keys_settings·test_quick_slots·test_skill_book 기대값 고침(통과).

## 기다리는 것
- 검수: 브랜치 확인·병합, UiSandbox(또는 메인 반영 1) 사진. 사진 전에는 화면 크기·겹침을 눈으로 못 봄.
- 서버(개발 2/3)와 맞출 것: SellItem(itemId, n) 또는 오토 판매 화면 계약, Spares 저장(v4), 방어구·반지·펫 장비 칸 데이터 모양(A23-133).

## 다음 큐 (검수가 바꾸지 않으면)
1. 망치질 미니게임 참고 게임 검색(A23-133) → 손맛 설계 메모.
2. ② 채집 G 꾹 화면 ③ 제작 창 + 망치질 ④ 연금·조련 창 ⑤ 거래소 창 + 퀘스트 화면 ⑥ 장비창 방어구·반지·펫 칸 ⑦ 장인 스킬 효과.
