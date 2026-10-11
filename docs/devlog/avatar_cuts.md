# 아바타가 나오는 컷 (촬영 편집, 2026-10-07)
> 기록용(10/07 당시, s30 원본 기준). 지금과 다른 점: 첫 쇼츠는 10/08 s40 원본으로 새로 찍어 만들었고, 1편·쇼츠 2~4도 s40 원본으로 다시 만든다(`docs/handoff/film_2026-10-08.md`) → 아래 s30 컷 표는 지금 기준이 아님.
> 10/11 추가: 표의 "Halloween beta"·호박 대왕 컷은 낡음 — 베타 12/1, 호박밭·유령 숲 숨김(A23-119).
> 지금 기준: AGENTS.md · SPEC_ADDENDUM A23 · RELEASE_PLAN.

**최종(사용자 2026-10-07, 검수 전달): "그냥 지금 아바타로 하자" — 새 아바타를 기다리지 않고, 아래 두 원본도 다시 찍지 않는다.** (그 전 결정: 새 아바타가 나온 뒤 올리기 — 취소됨.) 나중에 아바타를 바꾸게 되면 이 표대로 두 원본만 다시 찍으면 된다.

## 다시 찍을 원본 2개 (FilmSet 테스트 Play, 영어 화면)
- `s30_king_fight` 25초 — 호박 대왕과 싸움(HUD 켬, 자동 전투, 캐릭터 뒤 카메라 반 바퀴, 대왕 쓰러짐·사탕 드랍 포함)
- `s30_meadow_auto` 20초 — 말랑 초원 슬라임 사냥(HUD 켬, 자동 전투, 캐릭터 뒤 카메라 반 바퀴 + 걷기)
- 다른 원본(교차로·마을·호박밭·몬스터 근접·유령 숲·펫·진영 고르기)에는 내 캐릭터가 안 보인다(프레임 확인 `build/devlog/check/avatar_presence.png`).

새 아바타가 들어오면: 같은 스크립트로 두 원본만 다시 찍어 같은 이름으로 바꾸고 → `py tools/devlog_build.py shorts01 --no-tts`, `py tools/devlog_long.py ep01 --no-tts` → 아래 컷이 모두 한 번에 바뀐다.
싸움 원본은 대왕이 쓰러지는 때(지금 약 2.7초)와 사탕 드랍 때가 달라질 수 있어서, 다시 찍은 뒤 `ss`(시작 초)만 맞춘다.

## short01_ai_team (5컷)

| 줄 | 말 | 원본 |
|---|---|---|
| A0c | But I LOVE games! | s30_meadow_auto (ss 3.0) |
| A0e | So I decided to make my own, with seven AI teammates! | s30_meadow_auto (ss 9.0) |
| A7b | And me? I'm the director. I play, I pick, and I say yes or n | s30_meadow_auto (ss 1.0) |
| A7b | And me? I'm the director. I play, I pick, and I say yes or n | s30_meadow_auto (ss 13.0) |
| A8 | The goal: a Halloween beta in {DAYS} days. | s30_king_fight (ss 6.0) |

## short02_picture_to_3d (1컷)

| 줄 | 말 | 원본 |
|---|---|---|
| B4 | and boom, it's in my Roblox game! | s30_meadow_auto (ss 6.0) |

## short03_pumpkin_king (2컷)

| 줄 | 말 | 원본 |
|---|---|---|
| C4 | And he hits hard! | s30_king_fight (ss 7.0) |
| C6 | Team up, and everyone who helps gets candy! | s30_king_fight (ss 22.2) |

## short04_monster_reveal (0컷)

| 줄 | 말 | 원본 |
|---|---|---|

## ep01_longform (13컷)

| 줄 | 말 | 원본 |
|---|---|---|
| 0-2 | But I LOVE games! | s30_meadow_auto (ss 3.0) |
| 0-5 | This is the Pumpkin King. In {DAYS} days, he has to be ready | s30_king_fight (ss 6.0) |
| 2-4 | And me? I'm the director. I play, I pick, and I say yes or n | s30_meadow_auto (ss 9.0) |
| 2-5 | When I find a bug, I tell the boss, and the boss sends it to | s30_meadow_auto (ss 13.0) |
| 3-6 | Even the Auto Battle button is a choice. A big slime swallow | s30_meadow_auto (ss 16.0) |
| 3-8 | Angel or devil. Either way, you unlock Auto Battle. | s30_meadow_auto (ss 1.0) |
| 6-1 | Being the director means making the calls. Here are some of  | s30_meadow_auto (ss 6.0) |
| 6-2 | Call one: where the buttons go. My team drew layout A and la | s30_king_fight (ss 9.0) |
| 6-7 | And call six: the game is in English only. Easy English, so  | s30_king_fight (ss 12.0) |
| 7-3 | You have five minutes to beat him. Team up, and everyone who | s30_king_fight (ss 7.0) |
| 7-3 | You have five minutes to beat him. Team up, and everyone who | s30_king_fight (ss 22.2) |
| 8-1 | {DAYS} days left. | s30_king_fight (ss 14.0) |
| 8-2 | Next time: I play the first ten minutes like a brand-new pla | s30_meadow_auto (ss 18.0) |
