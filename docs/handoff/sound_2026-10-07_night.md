# 소리 만들기 — 2026-10-07 밤 인계 (23:00 컴퓨터 끄기 전)
- **업로드 다 끝:** 새 효과음 57개(1~4번 49 + SkillLearn + Loot + 7번 6개), Darugi_S2 비공개 'HH SFX <키>'. id = `art/sfx/asset_ids.json` "ids"(pending 없음), 계속 쓰는 옛 소리 = "kept"(SwingMage·SwingTamer), 바뀐 옛 소리 = "old" 30개.
- **확인:** 메인 Studio(Edit)·WorldKit에서 `py tools/sfx_loadcheck.py` 59개 불러오기 실패 0·길이 이상 0, 임시 폴더 지움(nil).
- **개발 1 몫(대기):** 한 번에 붙여 넣기 `docs/design/sound_wiring_onepass_2026-10-07.md`(Files 59줄 + 새 Sounds 15줄 + Tap 0.46·GooseHonk 0.40·Duck.By 3개). 가상 붙여 넣기로 `py tools/sfx_wiring_check.py --file <사본>` 57개 맞음·옛 id 0·빈 칸 0. 서버 몫(Plunder 피해자 id·Crown·KingDefeat·reward→QuestDone 기본값)은 개발 2.
- **Play 확인 목록:** `docs/design/sound_play_check_2026-10-07.md`(처음 10분 18줄 + 세계 사건 7줄, DebugCommand로 띄우기). 개발 1이 연결 뒤 이 순서로 확인.
- **다음 소리 만들기:** 개발 1 연결 + Play(폰 흉내 HitSoft) 확인 뒤 → `py tools/sfx_wiring_check.py`로 '옛 id 0' 확인 → "old" 30개의 `art/sfx/*.ogg`와 id 정리, `sources.json`을 새 wav 기준으로. 쇼츠 SOUND 카드(문구·대표 '띵')는 촬영 편집이 물으면.
- 크롬 탭 열어 둔 것 없음. Firefly 크레딧 이 계정 세션 0. 요령: 메모리 creator-hub-audio-upload, 경과: `docs/handoff/sound_handoff_2026-10-07.md`.
