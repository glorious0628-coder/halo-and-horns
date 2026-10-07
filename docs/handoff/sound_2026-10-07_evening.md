# 소리 만들기 — 2026-10-07 저녁 인계 (계정 바꾸기 전)
- 업로드 끝: 새 효과음 51개(1~3번 32 + 4번 17 + SkillLearn + Loot), Darugi_S2 비공개 'HH SFX <키>', 중복 없음(한도 1968→1917). id = `art/sfx/asset_ids.json` "ids"; 옛 소리는 "kept"(계속 씀 8개)·"old"(바뀐 24개).
- 개발 1에게 연결표 `docs/design/sound_wiring_r4_2026-10-07.md` 보냄(SkillLearn은 LevelUp 뒤 1.1 s, Loot는 주문서·무기만·무기 0.92배). 연결은 개발 1 지금 일 뒤. 확인: `py tools/sfx_wiring_check.py`(대조), `py tools/sfx_loadcheck.py`(WorldKit에서 58개 불러오기 통과).
- 남은 일: 개발 1 연결 + Play(폰 흉내 HitSoft) 확인 뒤 "old" 24개의 `art/sfx/*.ogg`·id 정리, `sources.json` 새 wav 기준으로. 새 이벤트 14개(Crown·KO·Kaiju 등)는 `docs/design/sound_gaps_2026-10-07.md` 표(서버 몫은 개발 2).
- 업로드 요령(크롬 확장 + art/sfx 폴더 허락, 앱 브라우저 우회 금지)은 메모리 creator-hub-audio-upload, 자세한 경과는 `docs/handoff/sound_handoff_2026-10-07.md` 맨 위. Firefly 크레딧 이 세션 0.
