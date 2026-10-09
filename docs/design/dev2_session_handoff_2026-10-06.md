# 게임성 개발 2 세션 인계 (서버 전용, 검수 세션 2026-10-06)

사용자 결정(2026-10-06, SPEC A23-25): 세션 5개 — 이미지 생성 · 이미지 개발 · 게임성 개발 · **게임성 개발 2(당신)** · 검수(이끈다). 게임성 개발 하나로는 10/24 기능 마감까지 약 6일이 모자라서, 서버 기능을 따로 맡는다.
> 2026-10-09 검수: 지금은 세션 10개(`docs/handoff/role_prompts/README.md`). 이 글의 '게임성 개발' = 게임성 개발 1(클라이언트 코드만, worktree Game-wtc). 메인 Studio sync·Play·`place/` 커밋 = 메인 반영 1, 개발 2 브랜치 검증 = 게임성 개발 3, main 병합 = 검수.

먼저 읽을 것: `AGENTS.md`, ~~`docs/design/beta_board_2026-10-06.md`(진행판)~~ → `docs/handoff/review_handoff_2026-10-09.md` §8·§9(지금 큐, 진행판은 10/07 뒤로 안 고침), `docs/design/beta_basics_2026-10-05.md`(BB 계약, BB10의 2026-10-06 변경 메모 두 개 포함), `docs/SPEC_ADDENDUM.md` A23-18·A23-22·A23-23·A23-24·A23-25, `docs/design/skills_weapons_pets_2026-10-05.md`(펫).

## 일하는 곳 — git worktree, Studio 금지
- ~~게임성 개발의 핼러윈 커밋이 main에 들어간 뒤 깨끗한 main에서 `… worktree add … Game-dev2 -b dev2 main`~~ → 지금(10/09): 새 일마다 **origin/main에서 새 브랜치**(예: `dev2-pet2b`)를 Game-dev2 계열 worktree에서 만든다(`docs/handoff/role_prompts/03_dev2.md`).
- 모든 작업은 Game-dev2 계열 worktree에서 한다. 원래 폴더의 파일은 고치지 않는다(다른 세션의 작업 트리다).
- `build/`는 git에 없다. 오프라인 검사 도구가 필요하면 `build/luau_cli_0_741/`을 원래 폴더에서 worktree의 `build/`로 복사한다.
- **Studio를 만지지 않는다:** `sync_to_studio.py`, `playtest.py`, `studio_mcp.py`, Studio MCP, `update_gameplay_place.py --apply`, Publish, `place/` 커밋 모두 금지. 검사는 `tools/test_*.py` 오프라인 러너와 `luau-compile`로 한다.
- 증거 파일은 새 이름으로 남긴다(`docs/art/verification_2026-10-2x/…` 또는 새 파일명). 다른 세션의 증거를 덮어쓰지 않는다. 변이 검사를 끄고 돌린 보고서는 커밋하지 않는다.
- ~~매일 아침과 병합 전에 `git rebase main`(dev2 브랜치)으로 최신을 따라간다.~~ 새 브랜치는 늘 origin/main에서 시작한다. 커밋은 자기 파일만 경로로(`git add -A` 금지), 제목은 짧은 한국어. main에 직접 push하지 않는다.
- **병합:** ~~게임성 개발 [8afa46]에게 보내고 … main 병합·메인 Studio 동기화·플레이 확인·place 커밋은 게임성 개발이 한다~~ → 지금(10/09): 한 덩어리가 끝나면(오프라인 검사 + 변이 통과) 해시를 **게임성 개발 3**(검증)과 **'모든 것 검수'**에 보낸다. 개발 3 통과 뒤 검수가 main에 병합하고, 메인 반영 1이 메인 Studio에 sync·Play로 확인한다. 메인 Play로 확인되기 전에는 '적용 완료'라고 쓰지 않는다.

## 파일 주인 (10/07부터)
- **당신만:** 새 `RankingService.luau`, 새 `PetService.luau`, `PvPService.luau`, `PlayerService.luau`, `DataService.luau`(fillDefaults), `CombatService.luau`, `JusticeService.luau`, `Main.server.luau`의 INIT/START 목록. 서비스 파일과 목록 줄은 **반드시 같은 커밋**에 넣는다(목록만 있고 파일이 없으면 서버가 멈춘다).
- **Config.luau:** 새 최상위 표(`Config.Ranking`, `Config.Pets`, 무법자·장인 명성 문구 등)는 파일 끝 한 블록에만 추가한다. 다른 부분(`Config.StoryQuests`, `Announce.Text` 등)은 고치기 전에 게임성 개발에게 한 줄로 알리고 작게 고친다. `Config.UIArt`는 이미지 개발 것이다.
- **LootService.luau:** 당신은 RollKill 배율(무법자 ×0.5, 주간 +10%, 장인 명성 표, LOG)만, 게임성 개발은 SellItem 쪽만. 고치기 전에 서로 알린다.
- **Net.luau:** 원격은 끝에 줄만 붙인다.
- **손대지 않는다:** `Panels.luau`, `HUD.luau`, `ClientMain`의 ORDER, 클라이언트 모듈 전부(창·HUD 칩·펫 따라다니기 클라이언트는 게임성 개발 몫). 클라이언트가 필요하면 원격 계약(이름·인자·속성)을 정해 게임성 개발에게 보낸다.

## 할 일 (순서, 진행판 기준)
> 2026-10-09 검수: 이 절은 낡음 — BB37·BB12·BB10(RankingService)·PET-2·PET-4(PetService, main ae1fa582) 등은 main에 들어감. 지금 할 일은 `docs/handoff/role_prompts/03_dev2.md`와 review_handoff_2026-10-09 §8·§9. Z·X 스킬 켜기는 10/20 점검에서 정함(A23-86 결정 3, 스킬은 Lv5·15·25 A23-71).

1. **BB37** 이름 숨기기 한곳 처리: `AnnounceService.PublicName(player)`, 전체 알림 7곳 + 마을 게시판 이름 교체.
2. **BB12** Tab 목록 열: 전투력·레벨·환생·명성(골드 숨김). 명성 칸은 진영별(명예/악명/장인 명성).
3. **BB10** RankingService: 주간 판 4개 **Honor · Infamy · Artisan · PvP**(A23-23·A23-24), 공정 점수 PvPCreditOK, GrantFame 7곳, 무단 KO → PvP 판, 장인 명성(직접 얻은 주문서 표 → 강화 성공 칸 수), OrderedDataStore 쓰기 예산·읽기 캐시, PrivateServerId 가드, STUDIO 시즌. 오프라인 검사(가짜 DataStore): 약자 KO는 PvP만, 공정 KO는 명예/악명만, 친구 KO는 둘 다 아님, 표 없는 주문서는 0점.
4. **주간 정산 하나로:** A23-22 명예·악명·장인 1~3위 보상(칭호 + 경험치·드랍 +10%, 대박 제외, 그 진영에 있을 때만) + A23-23 PvP 1~3위 무법자(깡패 벌칙 + '무법자' 표시 + 현상금 ×2, 깡패 벌칙과 겹치면 한 번만). `HH_RankSettle_<WeekId>`는 한 번만 쓴다. DebugCommand 'RankSettle'(STUDIO 시즌만).
5. **BB14 서버 부분:** DamagePlayer sourceKind, KO 페이로드(Net.Fx 'KO' {By, Name, Lost, Sack, RespawnIn}).
6. **펫 서버:** PET-1 이동 속도 한곳 계산(상한 ×1.35, checkMove 오탐 없음) → PET-2 펫 저장·EquipPet·펫 XP·따라잡기 지급 → PET-4 '길 잃은 아기 슬라임' 서브 퀘스트 → PET-6 펫 획득 전체 알림.
7. WPN-3 무기 저장 안전 잔여, GOOSE-Q(데이터 3단계, 새 대화 없음), A23-18 오프라인 검사(유예·운·깡패) + A23-18-LOG.
8. 10/17 점검에서 Z 스킬을 켜기로 하면 Z 서버 부분. 꺼 두면 BB40 데이터 삭제 도구.
- 진행판 목표: 10/12까지 BB37·BB12·BB10 오프라인 통과, 10/17까지 정산·무법자·펫 서버 병합.

## 공통 규칙
- 사용자에게는 **한국어로 짧게**. 클릭을 부탁하지 않는다.
- Luau 규칙: 함수(파일 최상위 포함)마다 local 200개 제한, `task.*` 사용, 던질 수 있는 것은 pcall, 모든 원격 검증, 플레이어 문구는 중앙 표에 ~~KO/EN~~ **영어만**(A23-48, 쉬운 영어, 용어 `docs/design/glossary_en_2026-10-06.md`).
- 큰 단계마다 ~~검수 세션(ListAgents '검수')~~ **'모든 것 검수' 세션(id는 list_sessions로 찾기)**에 보고한다: 끝난 것 / 바꾼 파일 / 직접 확인한 것 / 남은 것. 검수가 커밋마다 검사한다.
- 같은 이름의 다른 게임(fashion 폴더) 세션이 있다. 받는 쪽은 받은 메시지의 from 주소나 list_sessions의 cwd(Game)로 고른다. ~~게임성 개발 [8afa46], 이미지 개발 [e2802a], 이미지 생성 [9751d5]~~ — 옛 id는 10/09 16:30 세션을 새로 만들어 모두 무효.
