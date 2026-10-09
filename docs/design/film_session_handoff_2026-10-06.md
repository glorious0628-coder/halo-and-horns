# 촬영·편집 세션 인계 (모든 것 검수, 2026-10-06)

사용자: "내가 보내 준 사람처럼 유튜브 영상 만들고 싶어" (참고: MedoDeveloper `jnJpzyF-8PA`, `docs/design/video_lessons_jnJpzyF-8PA_2026-10-06.md`) / "유튜브에 올리는 건 직접 할게, 대신 촬영 편집은 너가 해줘" / 촬영 세션을 열고 **로블록스 스튜디오 창만 녹화**하는 것을 허락(2026-10-06). SPEC A23-42.

먼저 읽을 것: `AGENTS.md`, 이 문서, `docs/SPEC_ADDENDUM.md` A23-42, `docs/design/video_lessons_jnJpzyF-8PA_2026-10-06.md`, `docs/design/reference_sites_2026-10-06.md`(umanmade.com = 움직임·전환 참고).
> 2026-10-09 검수: 지금 할 일은 `docs/handoff/role_prompts/08_film.md`(지금은 쉬는 차례, 검수가 부를 때). 마지막 상태(10/08 저녁): 첫 쇼츠 v7(6e70408f)을 검수에 보냄(`docs/handoff/account_switch_2026-10-08_2100.md`, `build/handoff_2026-10-08/film_tail.md`), 쇼츠 2~4·1편은 s40 원본으로 다시(`docs/handoff/film_2026-10-08.md`). 규칙 더하기(10/08): 같은 장면 반복 금지, 0.5초 넘게 가만히 서 있는 장면 금지, Downloads에는 검수 통과 뒤 최종 mp4 + 제목 txt만(`HaloHorns_<무엇>_<날짜>`).

## 할 일
1. **에피소드 기획과 대본(영어, 사용자 2026-10-06):** 1편 예: "I made a Roblox Halloween game with 7 AI teammates #1"(5~8분, **영어**, 해외 아이들도 알아듣는 쉬운 말). 장면 예: 시작 한마디(10/31 핼러윈 베타까지 남은 날) → 게임 소개(모든 행동이 천사 아니면 악마로 기운다) → Firefly 그림 → Tripo 3D 몬스터(네모 슬라임·호박 대왕) → 화면 배치 A/B를 고른 이야기 → 핼러윈 호박 대왕 → 세션 6개 팀(→ 지금 10개, `docs/handoff/role_prompts/README.md`) → 다음 편 예고. 재밌고 짧은 문장, 아이도 알아듣게. 대본은 `docs/devlog/ep01_script.md`(영어 대본 + 옆에 한국어 뜻), 검수에게 보내 확인받는다.
2. **재료 모으기:** `docs/devlog/<날짜>/`(세션들이 남긴 전·후 캡처와 한 줄 설명), `art/review/`·`art/review/s2/` 시트, `docs/art/verification_*` 캡처, Tripo 미리보기, git log(날짜·제목).
3. **녹화(게임이 움직이는 장면):**
   - 녹화 전용 연습 장소 `build/FilmSet.rbxlx`를 쓴다: `build/GoodEvil.rbxlx`(또는 최신 저장본)를 복사해 Studio로 열고, `STUDIO_NAME=FilmSet`으로만 `tools/sync_to_studio.py`·Studio MCP를 쓴다. **메인 Studio(81671223175574)·UiSandbox·WorldKit은 녹화·조작하지 않는다.** 게시 금지.
   - 허락 범위: **Studio 창만** ffmpeg로 녹화한다(`ffmpeg -f gdigrab -framerate 30 -i title="<FilmSet Studio 창 제목>" …`, 실행 파일은 `%LOCALAPPDATA%\Microsoft\WinGet\Packages\Gyan.FFmpeg…\bin\ffmpeg.exe`). 데스크톱 전체·다른 창은 녹화하지 않는다. 마우스·키보드는 건드리지 않는다. 캐릭터는 우리 테스트 Play 안에서 Studio MCP(character_navigation 등)로만 움직인다. 한 번에 60초 이하로 짧게 찍고, 끝나면 Play를 멈춘다.
   - 원본 영상은 `build/devlog/raw/`(git 밖). 큰 파일은 커밋하지 않는다.
4. **목소리(영어):** 오픈 소스 TTS **MeloTTS** 영어 목소리(EN-US 등)(MIT 라이선스 — 상업 이용 가능, 한국어 지원, CPU로 실시간)를 쓴다. 설치는 사용자 OK를 받았다(2026-10-06). 설치가 안 되면 윈도우 영어 목소리(Microsoft Zira)로 대신한다. 라이선스가 비상업(CC-BY-NC 등)인 모델(XTTS, F5-TTS 가중치, Fish Speech 등)은 쓰지 않는다.
5. **편집:** ffmpeg 스크립트(`tools/devlog_build.py`)로 장면 자르기·빨리 감기(타임랩스)·자막(영어를 화면에 넣음, 굵은 외곽선; 한국어 자막은 따로 .srt)·전환·시작 제목·끝 화면을 만든다. 1920×1080 H.264, 100MB 안쪽. 음악은 넣지 않거나 사용자가 고른 무료 음악만. 쇼츠(9:16, 60초) 판도 하나 만든다.
6. **올리기 전 점검(검수와 같이):** 화면에 계정 이름·이메일·사용자 ID·다른 프로젝트 이름(Studio 목록의 다른 장소 이름 등)·`.env`·Tripo 키·디스코드·다른 게임 세션 이름이 없는지, 노출 그림 규칙(AGENTS Hard rule 1)을 지키는지 본다. 있으면 자르거나 흐리게 한다.
7. **넘기기:** 영상 파일 경로 + 한국어 .srt + 제목·설명·태그 초안(영어 + 한국어 한 줄)을 검수에게 보낸다. **유튜브 올리기는 사용자가 직접 한다.** 썸네일은 이미지 생성 1에게 요청(~~중간 품질~~ 시안 중간 → 고른 최종 고급, A23-47 보강 3).

## 규칙
- 사용자에게는 한국어로 짧게. 큰 단계마다 '모든 것 검수'에 보고. 커밋은 자기 worktree(`Game-film`)에서는 `git commit -m "…" -- <경로>`, 공유 트리(`Game`)에서는 `git commit` 대신 `py tools/push_paths.py -m "제목" <경로>`(AGENTS Hard rule 5)(대본·도구·작은 캡처만, 영상 파일은 git 밖).
- 개발 세션 Play와 부딪히지 않게 녹화는 FilmSet에서만. PC가 느려지면 FilmSet을 닫는다.

## 재미 포인트: 마우스 대신 'AI 팀이 만든다'를 보여 준다 (검수, 2026-10-06)
사용자 걱정: "유튜브는 스튜디오에서 마우스로 막 하는 게 보이는데, 우리는 MCP라 재미가 떨어지지 않을까?" → 우리만의 장면으로 채운다.
- **AI 팀 대화 장면:** 세션끼리 주고받은 메시지(검수 ↔ 개발 ↔ 이미지)를 채팅 말풍선 애니메이션으로 다시 그린다(내용은 실제 기록에서, 개인정보·다른 게임 이름 빼고). 예: "장인 궁수 없애자고 했잖아!" → AI가 사과하고 펫 조련사를 그리는 장면, 사용 한도가 차서 "AI들이 지쳐 쓰러짐" 같은 웃긴 실제 순간.
- **스튜디오가 저절로 지어지는 타임랩스:** MCP가 소품·지형·몬스터를 넣는 동안 FilmSet Studio 창을 녹화해 빨리 감기 — 물건이 하나씩 '뿅' 나타나는 장면이 마우스 작업보다 신기해 보인다.
- **그림 → 3D 변신:** Firefly 시안 → 누끼 → Tripo 3D 모델 회전(Blender 렌더 `tools/render_front.py` 응용) → 게임 속 몬스터. 전·후 밀어내기 전환.
- **코드 타자 장면:** 실제 커밋 diff를 빠르게 타자 치는 애니메이션(구문 색칠)으로 몇 초만.
- **버그 → 고침:** 떠 있던 몬스터 → 발밑 그림자, 위 가운데가 복잡한 HUD → B안. 실제 전·후 캡처 그대로.
- **플레이 장면:** 테스트 Play에서 캐릭터가 사냥·호박 대왕과 싸우는 장면(MCP 이동), 중간중간 확대·화살표·말풍선 같은 편집 강조.
- 정직하게: 사람이 마우스로 한 것처럼 꾸미지 않는다(가짜 커서로 '사람이 조작하는 척' 금지). 편집 강조(확대·화살표·자막)는 괜찮다.
- 마우스로 직접 하는 장면은 넣지 않는다(사용자 2026-10-06: "마우스로 하는 거 안 해도 될 듯"). 사용자가 "오 좋다"고 한 위 장면들로 간다.
