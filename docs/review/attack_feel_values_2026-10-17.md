# 기본 공격 손맛 — 지금 값 표 + 모자란 곳 (게임성 개발 1, 2026-10-17, gameplay_plan 5번)

코드에서 읽은 값(main f6507381). 실측(ms)은 10/16 PhoneTest(빛, T2 무기, Studio = 지연 거의 0) 기록
`docs/art/verification_2026-10-16/attack_feel/` — 뿔·라이브 지연은 아직 안 잼(아래 '실측 계획').

## 1. 누르면 바로 나가나 (입력 → 몸짓 → 서버 → 맞은 표시)

| 단계 | 전사 | 궁수 | 마법사 | 어디 |
|---|---|---|---|---|
| 누름 → 내 몸 휘두름 시작 | **0 ms**(누르는 순간, 서버 안 기다림) | 0 ms | 0 ms | HUD L.SwingFaced → Fx.PredictSwing (10/16 손맛 ①) |
| 같은 순간 소리 | `Swing` = swordslash.wav (모든 직업 같음 ⚠) | 같음 ⚠ | 같음 ⚠ | Fx.PlaySound("Swing"), Config.Sounds.Swing |
| 몸짓의 '맞는 프레임' (서버 CombatService TUNE.MOTION과 같음; 맨손 0.15) | SLASH_CONTACT 0.23 s (칼 그림 0.17) | SHOT_DELAY 0.22 + 화살 0.15 = ~0.37 s | CAST_DELAY 0.24 + 구슬 0.2 = ~0.44 s | Fx MOTION |
| 서버 판정 | 누름이 서버에 닿는 즉시 피해(HurtSeq) — 지연 = 왕복 반 | 같음 | 같음 | CombatService.Swing |
| 맞은 표시(불꽃·숫자·움찔) 시작 | **서버 Fx가 온 때 + 맞는 프레임** ⚠ | 같음 ⚠ | 같음 ⚠ | Fx handlers.Swing(data.ContactDelay/LaunchDelay/FlightTime) |
| 맞은 소리 | 서버 Fx 온 때 + ContactDelay ⚠ | 같음 | 같음 | Audio.Plan planHits |
| 다시 누를 수 있음 | SwingInterval 1.0 s | 0.5 s | 1.1 s | Config.Classes |
| 실측(Studio, 10/16 3차) | 누름→피해 48 ms, 숫자 286 ms | — | — | feel_armed_*.json |

⚠ = 몸은 누르는 순간 움직이는데, 맞은 표시·소리는 **서버 Fx가 돌아온 때부터** 맞는 프레임을 셈 → Studio에선 거의 같지만
라이브(왕복 100~250 ms)에서는 칼이 지나간 뒤 0.1~0.25 s 늦게 '퍽'이 남(추측, 라이브 미측정).

## 2. 맞은 느낌

| 반응 | 전사 | 궁수 | 마법사 | 비고 |
|---|---|---|---|---|
| 타격 멈춤(hit-stop) | 0.08 s(치명 0.12), 손으로 칠 때만 | **없음** | **없음** | MOTION HITSTOP_* "Warrior contact frames only" |
| 카메라 톡(kick) | 0.16 / 0.1 s, 손으로만 | 0.16 | 0.16 | 자동 전투는 없음(A23-1) |
| 불꽃 | 3.2 스터드, 0.15 s | 같음 | 같음 | SPARK_* |
| 숫자 팝 | 0.8 s, 3 스터드 위로, 0.25 s 안 합침 | 같음 | 같음 | NUMBER_LIFE, MERGE_WINDOW |
| 몬스터 움찔 | 들어감 0.05 / 돌아옴 0.14 s, 9°, 큰 타격 ×1.6 | 같음 | 같음 | FLINCH_*, HurtSeq, 슬라임은 납작 |
| 아픈 스티커 | 0.6 s, 몬스터당 1 s 간격 | 같음 | 같음 | STICKER_*, MONSTER_STICKER_GAP |
| 맞은 소리 | HitBlade Soft/Heavy/Crit | HitArrow* (2발이면 두 번) | HitMagic* | Config.Audio.HitByClass |
| 처치 | 편안히 사라짐 + KillPop + 보상 숫자(맞은 표시 0.08 s 뒤) | 같음 | 같음 | A23-211, HIT_AFTER |

## 3. 직업 차이 (기본 공격, 무기 있음)

| | 전사 | 궁수 | 마법사 | 맨손(모두) |
|---|---|---|---|---|
| 간격 | 1.0 s | 0.5 s | 1.1 s | 0.8 s |
| 거리 | 10 (내 주변) | 30 | 35 | 7 |
| 맞는 수 | 앞쪽 반원 전부 | 가까운 2 | 가까운 1 + 둘레 7 | 1 |
| 피해 배수 | ×1.0 | ×0.55 | ×1.3 | 고정 4 |
| 겨눔 각 | 90° 반원 | 90° | 90° | 90° |
| 빛/뿔 차이 | 무기 모양만 | 무기 모양만 | 휘두름 소리 Halo/Horns 파일 | 없음 |

## 4. 모자란 곳 → 보강안 (작은 순서)

| # | 문제 | 보강안 | 크기 |
|---|---|---|---|
| G1 | 누를 때 모든 직업이 **칼 소리**(swordslash) + 서버 Fx 때 직업 소리가 **한 번 더** → 궁수·마법사는 '칼+마법' 두 번 | 누름 소리를 그 직업 파일(Audio swingOf: SwingArrow / SwingMage(Halo·Horns))로, 같은 휘두름의 서버 Fx 소리는 건너뜀(짝이 맞으면) | S |
| G2 | 맞은 표시·소리가 서버 Fx 도착부터 셈 → 라이브에서 몸짓보다 늦음 | 내 손 휘두름(짝 맞은 것)은 '누른 때 + 맞는 프레임'에 맞춤: 남은 시간 = 맞는 프레임 − (지금 − 누른 때), 0 아래면 바로 | M |
| G3 | 궁수·마법사는 타격 멈춤이 없어 '퍽'이 약함 | 맞는 순간(화살·구슬 도착) 아주 짧은 멈춤 0.04 s + 몬스터 움찔 ×1.2, 손으로 칠 때만 | S |
| G4 | 궁수 0.5 s 간격인데 숫자 합침 0.25 s → 두 발 숫자가 따로 떠 화면이 바쁨(추측) | 실측 뒤 결정(합침 0.35?) | 실측 |
| G5 | 뿔·라이브 지연 실측 없음 | 아래 실측 계획 | — |

## 5. 실측 계획 (다음 화면 신청에 묶음)
`build/dev1_tools/feel1016.py`(로거 feel_logger.luau, HHDbgSwing) 확장: 빛·뿔 × 전사·궁수·마법사, T1 무기, 슬라임 옆,
F 한 번씩 6회 + 연타 8회 → 누름→몸짓·피해·불꽃·숫자·소리(ms). Studio에 지연 넣기(설정 Network > IncomingReplicationLag
0.15 s)로 라이브 흉내 한 판 더 → G2가 필요한지 값으로 판단.
