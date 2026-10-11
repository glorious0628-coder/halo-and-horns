# 선악 키우기: 헤일로 & 혼즈 (Halo & Horns)

뇌 빼고 하는 로블록스 MMORPG. 빛의 기사단(선) · 뿔 군단(악) · 장인 길드(중립) 중 하나를 골라 싸우고, 키우고, 환생한다. (공개 베타는 2026-12-01 11:00 KST, 장인 길드 포함 — A23-119. 게임 화면 글자는 지금 영어만 — A23-48; 한국어는 빛 마을 뒤 같은 게임 안 한국어 모드 — A23-111.)

## 폴더
- `src/` — 게임 코드 (Luau, Rojo 호환 구조)
- `docs/` — 기획서(GDD), 기술 명세(TECH_SPEC + SPEC_ADDENDUM), 아트 디렉션, 출시 계획(RELEASE_PLAN), 인계(`docs/handoff/`). 읽는 순서·규칙은 `AGENTS.md`
- `tools/` — 스튜디오 연동 도구

## 스튜디오에서 작업하기
1. Roblox Studio에서 게임 place를 연다 (Studio MCP가 켜져 있어야 함).
2. `py tools/sync_to_studio.py` — `src/` 코드를 열린 스튜디오에 넣는다. (메인 Studio sync는 '메인 반영 1' 세션만, 코드가 origin/main과 같을 때만 — `docs/handoff/role_prompts/01_mainapply.md`, AGENTS Hard rule 5)
3. `tools/preview_map.lua`는 맵(지형 포함)을 스튜디오 편집 모드에 짓는 스크립트 (`studio_mcp.py call execute_luau`로 실행).
4. `py tools/playtest.py 20` — 20초 플레이하고 콘솔 출력을 보여준다.
5. `py tools/luau_check.py` — 모든 파일을 로블록스 Luau 컴파일러로 문법 검사.

`py tools/build_place.py`로 `src/`만 담은 `.rbxlx`도 만들 수 있지만, 지형과 맵은 스튜디오에 저장한 place 파일에만 들어 있다. 단, 인자 없이 돌리면 `build/GoodEvil.rbxlx`를 덮어쓰므로 그렇게 돌리지 않는다(AGENTS Tools).
