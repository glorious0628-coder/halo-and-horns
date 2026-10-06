# 게임성 개발 2 인계 상태 (2026-10-06 저녁)
- 끝난 것: BB37·BB12(main 병합 완료). **BB10 RankingService + 주간 정산·무법자·1~3위 보상**: dev2 커밋 "랭킹 서비스(BB10)·주간 정산·무법자·1~3위 보상"(병합 요청을 게임성 개발 [348428]에 보냄). 오프라인 tools/test_ranking.py: 474검사, 변이 179/179. 증거는 docs/art/verification_2026-10-06/offline_ranking_2026-10-06.json. 검수 10건 + 검수 결정(10분 안 3번 반복 KO = PvP 판 1점) + 에이전트 자체 검토 2회를 반영. 구현 메모: docs/design/ranking_service_plan_2026-10-06.md §13.
- 다른 스위트: 15개 중 halloween만 HUD 검사 3건이 실패함(main 쪽 문제, 이미지 개발 담당). test_loot 변이 1줄은 RollKill 글자가 바뀐 데 맞춤.
- 다음 할 일(검수 순서):
  1. A23-32 가방 '얻은 순': data.ItemSeq[itemId]·ItemSeqNext, WeaponSeq[tier]. 아이템이 들어오는 모든 길에서 갱신하고 가방 원격(Inventory)에 실어 보냄. 오프라인 검사(젤리→주문서→젤리, 재접속 유지, 변이). 끝나면 게임성 개발 1에 원격 필드를 알림.
  2. A23-34 맨손 시작: 새 세이브 WeaponTier 0·OwnedMask 0, 맨손 근접(Config.Combat.Unarmed). Lv1·무기 없음 전투력 0. M1_1 보상으로 T1 지급+장착(한 번만). 무기 0이면 손에 아무것도 없음. 옛 세이브는 그대로. Config 공유 줄은 먼저 게임성 개발 1에 알림.
  3. BB11 서버 게시판 3목록(명예·악명·무법자 TOP3, PublicName, Config.Ranking.Text.Board) → BB14 서버(DamagePlayer sourceKind, KO 페이로드) → PET-1·2·4·6.
- 규칙: worktree C:/Users/glori/Documents/Roblox/Game-dev2(dev2)에서만 일함, Studio 금지, 병합 전 rebase main, 경로를 지정해 커밋, 변이 포함 증거만 커밋.
