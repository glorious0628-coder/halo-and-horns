# 영상 효과음 기록 (촬영 편집)

유튜브 수익 영상이라 효과음마다 출처·라이선스를 적는다. 소리 파일은 `build/devlog/sfx/`(git 밖).
쓰면 안 되는 것: Roblox Creator Store 오디오(로블록스 안에서만), 출처 모르는 무료 모음, NC·표기 못 하는 CC-BY, 유명 게임·만화 소리.

## 내려받은 팩 (사용자가 촬영 편집 채팅에서 직접 OK, 2026-10-06)

| 팩 | 파일 | 받은 곳 | 라이선스 | 날짜 |
|---|---|---|---|---|
| Kenney **Impact Sounds** 1.0 (130개) | `kenney_impact-sounds.zip` 800,850 B | https://kenney.nl/assets/impact-sounds (공식 페이지 다운로드 링크) | CC0 1.0 (팩 안 License.txt: 개인·교육·상업 무료, 표기 선택) | 2026-10-06 |
| Kenney **Interface Sounds** (100개) | `kenney_interface-sounds.zip` 834,536 B | https://kenney.nl/assets/interface-sounds (공식 페이지 다운로드 링크) | CC0 1.0 (팩 안 License.txt) | 2026-10-06 |

## 영상에 쓰는 소리 (`tools/devlog_build.py` `SFX_FILES`)

| 이름 | 쓰는 곳 | 파일 | 출처 · 라이선스 |
|---|---|---|---|
| boom(쿵) | 호박 대왕 등장·첫 장면·빨간 X | `impact/Audio/impactSoft_heavy_000.ogg` + 우리 합성 저음 | Kenney Impact Sounds · CC0 / 직접 합성 |
| hit(퍽) | 대왕이 때림·흔들림 컷 | `impact/Audio/impactPunch_heavy_002.ogg` | Kenney Impact Sounds · CC0 |
| pop(뿅) | 3D 모델 등장·변신 | `interface/Audio/drop_002.ogg` | Kenney Interface Sounds · CC0 |
| card(톡) | 팀 카드 일곱 장 등장 | `interface/Audio/drop_003.ogg` | Kenney Interface Sounds · CC0 |
| ding(딩) | 사탕·끝 화면 | `interface/Audio/confirmation_002.ogg` | Kenney Interface Sounds · CC0 |
| tick(틱) | 동전·5분 칩 | `interface/Audio/tick_004.ogg` | Kenney Interface Sounds · CC0 |
| whoosh(휙) | 컷 전환 | 직접 합성(`synth_sfx("whoosh")`, 잡음 필터) | 우리가 만듦 · 저작권 걱정 없음 |

크기: 내레이션보다 약 -18~-11 dB(`SFX_GAIN`), 전체는 -14 LUFS / -1.5 dBTP로 맞춘다. 크레딧은 의무가 아니지만 설명란에 "Sound effects: Kenney (kenney.nl, CC0)" 한 줄을 넣는다.
