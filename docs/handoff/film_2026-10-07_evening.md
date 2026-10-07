# 촬영 편집 인계 (2026-10-07 저녁, 계정 바꾸기 전)

1. **대기:** 다시 찍기는 지형(지도 v2)·3D 장식·화면 배치가 메인에 들어간 뒤(검수). 그 전엔 녹화 금지. 표·순서 = `docs/devlog/reshoot_2026-10-07.md`(원본 16개 + 새 장면 4개: 이야기 창 초상·빛살 없는 보상 팝업·큰 지도·펫 조련사 아기 슬라임, Z 스킬 뺌).
2. **그때 할 일:** 최신 `place/GoodEvil.rbxlx` → `build/FilmSet.rbxlx` 복사, 깨끗한 origin/main 작업트리(`../Game-film`)에서 `STUDIO_NAME=FilmSet py tools/sync_to_studio.py` → 검수 "전달함, 시작" 뒤 `tools/devlog_step1_front.py`(새 아바타 사진) → OK 뒤 `tools/devlog_shots_s40.py`(전부, 약 12분) → 장면표의 `s30_` 이름을 `s40_`로 바꾸고 다시 만들기.
3. **만들기:** 쇼츠 `py tools/devlog_build.py shorts01 [--no-tts]`(쇼츠 안전 영역 x 60~960·y 200~1500, 말하는 단어 색 자막, Kenney CC0 효과음), 1편 `py tools/devlog_long.py ep01`(16:9, 95MB 안쪽). 안전 영역 오버레이 시트 + 다운로드 폴더 `HaloHorns_<무엇>_<날짜>` → 검수로.
4. **지금 상태:** 옛 원본(s30, 지금 아바타)으로 만든 쇼츠 4편이 다운로드 `HaloHorns_Shorts_2026-10-07`에 있음(검수 ①④ 통과판 + 이모지 자막 넘침은 코드만 고침, 영상은 아직 옛 판). 1편 3:45 초안은 build/devlog/ep01(직업 그림 줄·대왕 회전 고침은 코드만, 다시 만들기 전).
5. **규칙:** 창 펼치기·Play·녹화 전 검수 "촬영 편집 — 무엇 — 몇 초(마우스·키보드 여부)" → "전달함, 시작" 뒤에만, 끝나면 "끝". 공유 폴더는 git commit 금지, `py tools/push_paths.py`. 사용자에게는 한국어만.
