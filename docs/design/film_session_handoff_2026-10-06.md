# 촬영·편집 세션 인계 (모든 것 검수, 2026-10-06)

사용자: "내가 보내 준 사람처럼 유튜브 영상 만들고 싶어" (참고: MedoDeveloper `jnJpzyF-8PA`, `docs/design/video_lessons_jnJpzyF-8PA_2026-10-06.md`) / "유튜브에 올리는 건 직접 할게, 대신 촬영 편집은 너가 해줘" / 촬영 세션을 열고 **로블록스 스튜디오 창만 녹화**하는 것을 허락(2026-10-06). SPEC A23-42.

먼저 읽을 것: `AGENTS.md`, 이 문서, `docs/SPEC_ADDENDUM.md` A23-42, `docs/design/video_lessons_jnJpzyF-8PA_2026-10-06.md`, `docs/design/reference_sites_2026-10-06.md`(umanmade.com = 움직임·전환 참고).

## 할 일
1. **에피소드 기획과 대본:** 1편 "AI 6명이랑 핼러윈까지 로블록스 게임 만들기 #1"(5~8분, 한국어). 장면 예: 시작 한마디(10/31 핼러윈 베타까지 남은 날) → 게임 소개(모든 행동이 천사 아니면 악마로 기운다) → Firefly 그림 → Tripo 3D 몬스터(네모 슬라임·호박 대왕) → 화면 배치 A/B를 고른 이야기 → 핼러윈 호박 대왕 → 세션 6개 팀 → 다음 편 예고. 재밌고 짧은 문장, 아이도 알아듣게. 대본은 `docs/devlog/ep01_script.md`, 검수에게 보내 확인받는다.
2. **재료 모으기:** `docs/devlog/<날짜>/`(세션들이 남긴 전·후 캡처와 한 줄 설명), `art/review/`·`art/review/s2/` 시트, `docs/art/verification_*` 캡처, Tripo 미리보기, git log(날짜·제목).
3. **녹화(게임이 움직이는 장면):**
   - 녹화 전용 연습 장소 `build/FilmSet.rbxlx`를 쓴다: `build/GoodEvil.rbxlx`(또는 최신 저장본)를 복사해 Studio로 열고, `STUDIO_NAME=FilmSet`으로만 `tools/sync_to_studio.py`·Studio MCP를 쓴다. **메인 Studio(81671223175574)·UiSandbox·WorldKit은 녹화·조작하지 않는다.** 게시 금지.
   - 허락 범위: **Studio 창만** ffmpeg로 녹화한다(`ffmpeg -f gdigrab -framerate 30 -i title="<FilmSet Studio 창 제목>" …`, 실행 파일은 `%LOCALAPPDATA%\Microsoft\WinGet\Packages\Gyan.FFmpeg…\bin\ffmpeg.exe`). 데스크톱 전체·다른 창은 녹화하지 않는다. 마우스·키보드는 건드리지 않는다. 캐릭터는 우리 테스트 Play 안에서 Studio MCP(character_navigation 등)로만 움직인다. 한 번에 60초 이하로 짧게 찍고, 끝나면 Play를 멈춘다.
   - 원본 영상은 `build/devlog/raw/`(git 밖). 큰 파일은 커밋하지 않는다.
4. **목소리:** 오픈 소스 TTS **MeloTTS**(MIT 라이선스 — 상업 이용 가능, 한국어 지원, CPU로 실시간)를 쓴다. 설치(파이썬 라이브러리 + 모델 약 2GB 내려받기)는 **사용자 OK를 받은 뒤**에만 한다. 그 전이나 설치가 안 되면 윈도우 한국어 목소리 Microsoft Heami(System.Speech)로 대신한다. 라이선스가 비상업(CC-BY-NC 등)인 모델(XTTS, F5-TTS 가중치, Fish Speech 등)은 쓰지 않는다.
5. **편집:** ffmpeg 스크립트(`tools/devlog_build.py`)로 장면 자르기·빨리 감기(타임랩스)·자막(한국어, 굵은 외곽선, 글꼴 맑은 고딕/나눔)·전환·시작 제목·끝 화면을 만든다. 1920×1080 H.264, 100MB 안쪽. 음악은 넣지 않거나 사용자가 고른 무료 음악만. 쇼츠(9:16, 60초) 판도 하나 만든다.
6. **올리기 전 점검(검수와 같이):** 화면에 계정 이름·이메일·사용자 ID·다른 프로젝트 이름(Studio 목록의 다른 장소 이름 등)·`.env`·Tripo 키·디스코드·다른 게임 세션 이름이 없는지, 노출 그림 규칙(AGENTS Hard rule 1)을 지키는지 본다. 있으면 자르거나 흐리게 한다.
7. **넘기기:** 영상 파일 경로 + 제목·설명·태그 초안(한국어, 필요하면 영어)을 검수에게 보낸다. **유튜브 올리기는 사용자가 직접 한다.** 썸네일은 이미지 생성 1에게 요청(중간 품질).

## 규칙
- 사용자에게는 한국어로 짧게. 큰 단계마다 '모든 것 검수'에 보고. 커밋은 `git commit -m "…" -- <경로>`(대본·도구·작은 캡처만, 영상 파일은 git 밖).
- 개발 세션 Play와 부딪히지 않게 녹화는 FilmSet에서만. PC가 느려지면 FilmSet을 닫는다.
