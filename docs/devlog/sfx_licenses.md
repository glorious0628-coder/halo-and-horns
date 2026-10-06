# 영상 효과음 기록 (촬영 편집)

유튜브 수익 영상이라 효과음마다 출처·라이선스를 적는다. 소리 파일은 `build/devlog/sfx/`(git 밖).
쓰면 안 되는 것: Roblox Creator Store 오디오(로블록스 안에서만), 출처 모르는 무료 모음, NC·표기 못 하는 CC-BY, 유명 게임·만화 소리.

| 소리 | 파일 / 만드는 곳 | 출처 | 라이선스 | 날짜 |
|---|---|---|---|---|
| whoosh(휙) · pop(뿅) · boom(쿵) · ding(딩) · tick(틱) | `tools/devlog_build.py` `sfx()` — numpy로 직접 합성(잡음 필터 휙, 짧은 상승 사인 뿅, 낮은 사인+잡음 쿵, 배음 딩, 짧은 틱) | 우리가 만듦 | 저작권 걱정 없음(직접 생성) | 2026-10-06 |

후보(사용자 채팅 OK 뒤에 내려받기): Kenney **Impact Sounds** `kenney_impact-sounds.zip` 801 KB · **Interface Sounds** `kenney_interface-sounds.zip` 835 KB — kenney.nl, CC0(표기 필요 없음).
