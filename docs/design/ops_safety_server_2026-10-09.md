# 베타 전 안전장치 3개 — 서버 계약 (게임성 개발 3, 2026-10-09)

시스템 점검 1회차(`docs/design/system_review_round1_2026-10-09.md`)의 더할 것 ③ 서버 오류 기록 · ② 실시간 스위치판 · ⑧ 저장소 이름 환경별. 시험: `py tools/test_ops_safety.py` (검사 117 + 정적 27, 변이 61/61).

## ⑧ 환경별 저장소 이름 (Config.Env / Config.StoreName)
- `Config.EnvName()` = 이 서버가 어느 복사본인지: `Config.Env.Names[<장소 id>] = "Beta" | "Live"`(게시할 때 채움), 그 밖의 장소·Studio는 `"Dev"`.
- `Config.StoreName(base)` = 그 환경의 DataStore 이름: **Dev는 지금 이름 그대로**(`HaloHorns_Player_v1` 등 — 아무것도 옮기지 않아요), Beta는 `_Beta`, Live는 `_Live`가 붙어요. 이미 적용: 플레이어 저장(DataService), 닉네임, 털기 우편, 후원자 명단, 알림 동의 명단, 랭킹 시즌(`<시즌>_Beta` 등), 새 서비스 둘.
- `Config.BuildLabel` = `beta-prep 2026.10.09`(설정 맨 아래 칸에 보이는 글자; 배포마다 올려요).
- **옛 저장을 옮길지 — 검수/사용자 결정이 필요해요(돈·데이터):** 지금 개발 장소(81671223175574)의 테스트 저장은 `Dev`(접미사 없음)에 그대로 남아요. Beta·Live는 **빈 저장소에서 시작**해요(테스트 계정의 레벨·골드가 정식에 안 섞임 — 제 추천). 옛 테스트 저장을 베타로 가져가고 싶다면 따로 한 번 복사하는 도구가 필요하고, 그건 사용자가 정해야 해요(가져가면 테스트 때 얻은 후광·뿔·골드가 정식에 남음).
- **게시할 때 꼭:** Beta 장소와 Live 장소를 게시한 뒤 각 장소 id를 `Config.Env.Names`에 `Beta`/`Live`로 넣고 같은 코드를 올려요. id를 안 넣으면 그 장소는 `Dev`로 보여서 개발 저장소를 써요 — `launch_ops_checklist.md`에 한 줄 추가 필요(검수).

## ③ 서버 오류 기록 (ServerErrorService)
- `ScriptContext.Error`(잡히지 않은 스크립트 오류)와 느린 틱(Heartbeat 한 번이 0.5초 넘음, 시작 30초는 무시)을 **분석 이벤트 하나 `ServerError`**로: 값 = 오류 1 / 느린 틱은 밀리초, 칸(customField) = 스크립트 이름 · 메시지(80자, 3자리 이상 숫자는 `#`) · `"Error"|"Slow"`. 이름·UserId·채팅은 안 들어가요. **분당 5개**까지, 서버에 사람이 없으면(로그에 쓸 플레이어가 없음) 기록만 남아요. 이벤트 이름 한도 100 중 사용 수 +1.
- 최근 **50개**를 서버 메모리에 보관(같은 오류가 1분 안에 이어지면 한 줄 + 횟수), 120초마다와 서버가 닫힐 때 DataStore 문서(`HaloHorns_Errors_v1`(+환경), 키 `Recent`)에 합쳐 저장.
- **Studio에서 읽기:** Play 중 Command Bar에서 `game.ServerScriptService.DebugCommand:Invoke("Player1", "Errors")`(이 서버), `"Errors", "stored"`(저장된 문서; Studio는 자기 `_STUDIO` 복사본), `"Errors", "live"`(진짜 게임의 문서, 읽기만).

## ② 실시간 스위치판 (SwitchService)
- DataStore 문서 하나(`HaloHorns_Switches_v1`(+환경), 키 `Live`, 모양 `{ Set = { 스위치 = 값 }, At }`)를 서버가 **60초마다 읽어요**. 허용 키만(`Config.Switches.Defs`): **PassSales**(패스·치장 [Buy] 버튼), **Halloween**, **CrownWar**, **Goose** — 모두 Bool, 기본 켜짐. 값은 타입·범위로 잘라요(Bool은 true/false만, Number는 Min..Max). 문서에서 빠진 스위치는 기본값으로 돌아가고, **읽기가 실패하면 마지막 값을 유지**해요.
- 효과: Halloween = `Config.Halloween.Enabled`가 따라감(켜는 쪽은 원래 설정이 꺼져 있으면 켜지 않음), CrownWar = 왕관전 점수·라운드 멈춤(`WarService`), Goose = 새 거위 안 나옴(`GooseService`), PassSales = GameState `SwitchPassSales`(false면 클라가 [Buy]를 숨김 — **개발 1 몫**; 이미 산 패스는 계속 작동). 모든 스위치는 GameState `Switch<이름>`(true = 켜짐)으로도 나가요.
- 쓰기: Studio 명령창에서(키·계정 페이지 필요 없음) — `docs/ops/switchboard_2026-10-09.md`의 복사해서 붙이는 줄.
