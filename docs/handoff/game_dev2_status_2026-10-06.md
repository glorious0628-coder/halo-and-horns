# 게임성 개발 2 인계 상태 (2026-10-06, 사용량 한도로 멈춤)
- 끝난 것: BB37 이름 숨기기(AnnounceService.PublicName, 알림 7곳+게시판), BB12 Tab 열(전투력·레벨·환생·명성) — dev2 5f52534, **main 병합 완료**(게임성 개발, Studio에서 Tab 열 확인). 설계 메모 docs/design/ranking_service_plan_2026-10-06.md(검수 결정 D1~D6 포함, main 8941b5b).
- 작업 중: BB10 RankingService + 주간 정산·무법자·1~3위 보상 연결 — dev2 **d38d49f "작업 중 — 병합 금지"**(origin/dev2 푸시). 모든 서버 파일 luau-compile 통과, 기존 오프라인 검사 13개 변이 포함 통과. **랭킹 전용 오프라인 검사는 아직 없음.**
- 커밋 안 한 파일: 없음(worktree C:/Users/glori/Documents/Roblox/Game-dev2 깨끗함). dev2는 main 최신(6b1e45a 이후)으로 아직 rebase 안 함.
- 다음 할 일:
  1. `git -C …/Game-dev2 rebase main`(test_loot 변형 2줄 확인: `info.DropMult = num(pen.DropMult, 1)`·대박 `* rowMult` 글자는 그대로 둠).
  2. tools/test_ranking.py + tools/fixtures/ranking_offline.luau(dev2_kit 위): 메모 §10 목록 — 약자 KO는 PvP만, 공정 KO는 명예/악명만, 친구 KO는 둘 다 아님, 4번째·자리 비움·새내기·막 부활, 면제 8가지, 자루 RankInfamy, payLeaveBounty, 장인 표, 쓰기·읽기·숨기기, 정산 2서버·D4 포기·D5 3점, 효과(경험치·줄·대박·현상금·자동 끔), DebugSettle.
  3. 통과하면 커밋 메시지 정정 후 게임성 개발 [8afa46]에게 병합 요청(Main 목록과 RankingService가 같은 커밋), 검수 보고.
  4. 이어서 BB11 서버 쪽 게시판 3목록, BB14 서버(DamagePlayer sourceKind·KO 페이로드), 펫 서버(PET-1·2·4·6).
- 참고: 혼자 Play에서 MostWanted 줄은 Announce 원격이 아니라 Notify 원격(NotifyAll)으로 와요(게임성 개발 확인 메모).
