# 촬영 편집 인계 (2026-10-07 저녁, 계정 바꾸기 전)

> 기록용(2026-10-09 검수): 10/07 저녁 기록이에요. 다시 찍기는 10/08에 s40 원본으로 했어요(`docs/handoff/film_2026-10-08.md`). 지금 할 일은 `docs/handoff/role_prompts/08_film.md`예요.

1. **대기:** 다시 찍기는 지형(지도 v2)·3D 장식·화면 배치가 메인에 들어간 뒤(검수). 그 전엔 녹화 금지. 표·순서 = `docs/devlog/reshoot_2026-10-07.md`(원본 16개 + 새 장면 4개: 이야기 창 초상·빛살 없는 보상 팝업·큰 지도·펫 조련사 아기 슬라임, Z 스킬 뺌).
2. **그때 할 일:** 최신 `place/GoodEvil.rbxlx` → `build/FilmSet.rbxlx` 복사, 깨끗한 origin/main 작업트리(`../Game-film`)에서 `STUDIO_NAME=FilmSet py tools/sync_to_studio.py` → 검수 "전달함, 시작" 뒤 `tools/devlog_step1_front.py`(새 아바타 사진) → OK 뒤 `tools/devlog_shots_s40.py`(전부, 약 12분) → 장면표의 `s30_` 이름을 `s40_`로 바꾸고 다시 만들기.
3. **만들기:** 쇼츠 `py tools/devlog_build.py shorts01 [--only <id>] [--no-tts]`, 1편 `py tools/devlog_long.py ep01`(16:9, 95MB 안쪽). 쇼츠 자막(사용자 10/07 "말도 안 됨" 뒤): 가로 540 가운데 고정, 덩어리마다 크기·줄을 한 번 정해 강조 단어가 바뀌어도 안 움직임, 길면 두 줄 → 글자 줄임, 이모지는 줄 밖(위). 빌드가 프레임마다 자막·이모지·큰 글자·칩 상자를 재서 안전 영역(60,200)-(960,1500) 밖이 하나라도 있으면 실패(`safe_check.json`), 시트는 `py tools/devlog_safe_sheet.py build/devlog/shorts01/<id> ...` → `safe_overlay.png`. 목소리: 속도 1.0·noise 0.5/0.6, 문장 끝 쉼 0.24초, 또렷하게 처리 + 말할 때 효과음 낮춤(덕킹), -14 LUFS. 팀 카드 8장(소리 SOUND 포함), 카드는 그 단어를 말할 때 나옴(장면 `cues`). 다운로드 폴더 `HaloHorns_<무엇>_<날짜>` → 검수로.
4. **지금 상태:** 옛 원본(s30, 지금 아바타)으로 자막·목소리·팀 8명을 고친 쇼츠 4편 = 다운로드 `HaloHorns_ShortsFix_2026-10-07`(검수 확인 대기, 이전 판 `HaloHorns_Shorts_2026-10-07`은 버려도 됨). 1편 3:45 초안은 대사·팀 카드만 8명으로 고침(영상은 다시 찍은 뒤 새로 만듦).
5. **규칙:** 창 펼치기·Play·녹화 전 검수 "촬영 편집 — 무엇 — 몇 초(마우스·키보드 여부)" → "전달함, 시작" 뒤에만, 끝나면 "끝". 공유 폴더는 git commit 금지, `py tools/push_paths.py`. 사용자에게는 한국어만.
