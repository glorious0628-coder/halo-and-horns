# 클라우드 세션 인수인계 프롬프트

> **폐기된 옛 프롬프트(2026-10-03 무렵).** "main에 push 금지", 자동 장전/손 발사 고정, Codex 그림 파이프라인, A1–A12 등 지금과 맞지 않는다. 사용하지 말고 ~~`AGENTS.md`와 `docs/HANDOFF_CODEX.md` 맨 위 절, `docs/review/worker_prompt_2026-10-06.md`~~ → (2026-10-09) `AGENTS.md`, `docs/handoff/review_handoff_2026-10-09.md`(맨 아래 최신 절), 세션별 시작 글 `docs/handoff/role_prompts/README.md`를 쓴다(HANDOFF_CODEX·worker_prompt도 이제 기록용).

아래 블록 전체를 클라우드 Claude Code 세션의 첫 메시지로 붙여 넣으세요.

---

```
너는 로블록스 게임 "선악 키우기: 헤일로 & 혼즈"(Halo & Horns)의 코드 담당이야.
저장소: https://github.com/glorious0628-coder/halo-and-horns (private, main 브랜치). 클론해서 작업해.

## 나(유저)에 대해
- 한국어로, 짧게. 설명이나 기획 이론은 필요 없고 결과만 보고해.
- 다른 Claude 세션에 보내는 메시지도 한국어로 (코드 식별자/경로만 영어).

## 먼저 읽을 것 (순서대로)
1. README.md
2. docs/GDD.md (기획서, 한국어)
3. docs/TECH_SPEC.md (기술 명세 v2, 모든 모듈 계약)
4. docs/SPEC_ADDENDUM.md (A1~A12. TECH_SPEC보다 우선. 충돌하면 ADDENDUM이 이김)
5. docs/ART_DIRECTION.md (색, 조명, 형태 언어, HUD 배치)
6. docs/review/ (리뷰 결과와 다음 작업 입력)

## 확정된 결정 (바꾸지 마)
- 진영 3개: 빛의 기사단(Halo) / 뿔 군단(Horns) / 장인 길드(Neutral: 전투 버프 없음, PvP 면역, 제작 특화, 색 청록 40,200,190)
- 직업 3개(전사/마법사/궁수), 진영별 이름. 버튼은 같고 공격 모양만 다름.
- 변경 규칙: 무료 = 진행도 손실(직업: Lv1로, 진영: 떠나는 진영 명예/악명 0), 로벅스 티켓 = 유지. 능력치·뽑기는 절대 판매 안 함.
- 일일 퀘스트 유지 + 안 하면 휴가 보너스 70% (하는 게 항상 더 이득).
- 독창성 7개: 덩치 저울, 원한 돈자루, 자동 장전/손 발사, 수배범 괴수화, 황금 거위 줄다리기, 전향 환생, 휴가 보너스.
- 1:1 직접 거래 금지. 거래소만 (2단계: 판매 등록 + 예약 구매, 개당 최소 10골드, 수수료).
- 세계: 엘든 링 풍. 지역마다 산으로 둘러싼 분지, 하늘에 부서진 거대 왕관. 유저는 땅에서 주변만 보고 전체 맵은 지도(WorldMap)로만 봄.
- 맵 레이아웃: RPG 대륙(교차로 → 강 → 말랑 초원 → 강 → 고블린 숲 → 고갯길 → 해골 유적) + 진영 섬(빛 북쪽, 뿔 남쪽). 좌표는 ADDENDUM A10.

## 현재 상태
- src/ 32개 파일, 약 2만 줄. 전부 로블록스 Luau 컴파일러로 문법 검사 통과. 첫 플레이테스트에서 서버 19개, 클라 7개 서비스 에러 없이 시작.
- 리뷰·수정 1라운드 완료(로컬 세션이 진행).
- 맵(지형 포함)은 tools/preview_map.lua가 스튜디오 편집 모드에서 짓는다. 게임 서버 MapBuilder는 그 맵을 재사용한다.

## 다음 할 일 (우선순위 순)
1. 리뷰·수정 2라운드: docs/review/round2_inputs.md + docs/review/reviewer_spec_v2.md(HIGH 5 / MED 27 / LOW 19, 그룹별 체크리스트, 끝에 A13 블록 → ADDENDUM에 A13으로 추가). 각 항목이 실제 코드에 남아 있는지 먼저 확인하고 고쳐.
2. A12 연결: 카메라 줌 40, MaxSlopeAngle 46, 안개 120/650(Config.Sky 세 프리셋 모두), WorldMap.luau를 ClientMain에 등록 + 메뉴 '지도' + M키.
3. Config.Map을 preview_map v4 값과 맞추기(Lands, Bridges, Gates, PassX). WorldMap과 MapBuilder는 Config만 읽게.
4. Config.Assets 훅(Icons/Emblems/Textures, 비어 있으면 지금처럼 도형·텍스트).
5. 2단계 경제: 몬스터 재료 드랍 → 전부 팔기 → 원버튼 제작 → 서버 간 거래소(판매 등록 + 예약 구매, 최소 10골드, 세금). 먼저 ADDENDUM에 설계(A14)를 쓰고 구현.

## 아트 파이프라인 (로컬 세션 담당)
- 이미지: art/prompts/<id>.txt (완성본 프롬프트 65개, art/prompts.json) → 로컬 세션이 Codex CLI로 생성(tools/gen_images.sh) → art/out/<id>.png → Studio MCP upload_image로 로블록스 업로드 → rbxassetid를 Config.Assets에 기록.
- 코드에서는 Config.Assets.Icons/Emblems/Textures에 id가 있으면 이미지를 쓰고, 없으면 지금처럼 도형/텍스트로 대체하는 훅만 만들면 된다(IMG-R4).

## 클라우드에서 못 하는 것 (로컬 세션 담당)
- 로블록스 스튜디오/Studio MCP 접근이 없어서 tools/luau_check.py, tools/sync_to_studio.py, tools/playtest.py, preview_map 실행이 안 된다.
- 그래서: 문법은 아주 신중하게(Luau: continue, +=, 타입 주석 OK. `local x <const>` 같은 Lua 5.4 문법 금지). 작업 단위마다 브랜치(cloud/<주제>)에 커밋하고 PR을 열어. 로컬 세션이 PR을 받아서 스튜디오에서 문법 검사와 플레이테스트를 하고 main에 합친다.
- main에 직접 푸시하지 마.

## 작업 방식
- 큰 작업은 서브에이전트/워크플로로 병렬 처리하고, 각 파일은 그룹 하나만 소유(TECH_SPEC §2 그룹 표).
- 모든 플레이어 문구는 한국어. task.* 만 사용. 서버 권한. 리모트는 전부 검증.
- 커밋 메시지는 한국어로 짧게.
```
