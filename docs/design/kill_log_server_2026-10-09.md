# 처치 기록 (KillLog) — 서버 계약 (게임성 개발 3, 2026-10-09)

SPEC A23-86 TOP 9의 D 몫 `content_beyond_10min_2026-10-08.md` D(몬스터 스티커북): **화면은 11/04**, 처치 수는 나중에 거슬러 채울 수 없어서 베타 첫날부터 쌓아요. 보상·점수·스탯 없음.

- 저장(추가 칸, Version 3 그대로): `data.KillLog = { Total, M, A, Golden, ByKind = { [몬스터 종류] = n }, ByTier = { ["0".."8"] = { M, A } } }`. 접속 때 고쳐 써요(알려진 종류·무기 티어만, 0~10억 정수).
- 센다: 이 플레이어에게 보상이 간 처치(`MonsterService.MonsterKilled`, 개인 튜토리얼 몬스터 제외). **M = 손, A = 자동 전투** — `MonsterKilled`에 자동 여부가 없어서 처치 순간 플레이어 속성 `AutoCombatEnabled`로 판단해요(이야기 AutoKill과 같은 규칙). 무기 티어는 그때의 `WeaponTier`(0 = 맨손).
- 몬스터 종류별(`ByKind`)·황금(`Golden`)도 함께. 표 크기는 게임의 종류·티어 수로 막혀 있어요.
- 시험: `py tools/test_kill_log.py` — 검사 28 + 정적 6, 변이 21/21.
- 11/04 몫(개발 1 + 이미지 + 소리): 스티커 칸 4개(첫 잡음 / 25 / 250 / 2,500), Journal [Stickers] 탭, 페이지 보상·칭호 6개.
