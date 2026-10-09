# Glorious Studio 홈페이지 — 인계 (2026-10-08, 검수 → 다른 계정)
> 기록용(10/08 첫 인계, HTML 쓰기 전). 지금과 다른 점: 사이트는 공개됨(https://glorious.ai.kr, GitHub Pages), 아래 '남은 일'은 끝났거나 `HANDOFF_homepage1_2026-10-08.md`의 '남은 일'로 넘어갔고, 홈페이지 세션은 지워짐.
> 지금 기준: `docs/website/HANDOFF_homepage1_2026-10-08.md`(고치는 방법 = `index.html` → `build_site.py`) · AGENTS.md · SPEC_ADDENDUM A23 · RELEASE_PLAN.

사용자: "스타트업 지원(Claude) 받고 싶은데 웹사이트를 하나 만들어야겠어, 간단하게." 사용자가 주간 한도 때문에 다른 계정에서 이어 하기로 함. **아직 HTML은 한 줄도 안 씀.** 조사·사실·사진까지 끝남.

## 1. 사용자 결정 (2026-10-08, 채팅)
- 스튜디오 이름 **Glorious Studio** — 한국어 화면에서도 똑같이 "Glorious Studio" (번역하지 않음).
- **영어 기본 + 한국어 버전**(위쪽 EN/KO 버튼으로 바꾸기). 심사는 영어로 읽음.
- 연락 메일 **jian@glorious.ai.kr** (페이지에 글자로 보이게 + 복사 버튼; mailto 링크는 artifact 안에서 안 될 수 있음).
- 첫 게임은 로블록스 **Halo & Horns(선악 키우기)**, 더 나아가 **스팀(PC) 게임**도 만들고 싶음 → 로드맵에 넣기.

## 2. 지원 프로그램 조사 결과 (중요)
전체: `docs/website/content_2026-10-08.json`의 `gather:research`. 출처는 공식 페이지(claude.com/programs/startups, 2026-10-06 확장 블로그, 공식 약관). **검증 단계(verify:research)는 계정 전환으로 멈춤 → 신청 전에 공식 페이지를 한 번 다시 열어 확인할 것.**
- 이름: **Claude Startups**("Claude for Startups"). 신청: Claude Console 로그인 → https://platform.claude.com/offers/startups-application
- 주는 것: API 크레딧 $1,000(6개월), Claude Team 1년 무료(최대 5석, Team 처음인 조직만), 파트너 혜택(최대 $45K), 높은 rate limit, 오피스아워·행사. 파트너 VC 투자를 받은 곳만 추가 최대 $100K.
- 자격: 설립 5년 이내 **또는** 투자 2년 이내. VC 없어도 됨(부트스트랩 OK). 한국 지원 국가.
- **꼭 필요한 것: 회사 메일 도메인 = 홈페이지 도메인.** → 홈페이지를 **glorious.ai.kr**에 올려야 함. claude.ai artifact 링크만으로는 도메인이 안 맞음. 그래서 결과물은 ① 사용자에게 보여 줄 artifact 미리보기 + ② glorious.ai.kr에 올릴 파일(index.html + 이미지, 외부 의존 없음) 두 가지.
- 불확실: 1인·개인사업자 가능 여부(약관은 'company'와 '회사를 대표할 권한'을 말함), 매출 전 단계, 게임 스튜디오 특례(없음). 사용자에게 "사업자등록 여부"는 신청할 때 물어볼 것(지금 페이지에는 영향 없음).
- 페이지에 넣을 것(공식 + 추론): 스튜디오 이름, 무엇을 만드는지, 같은 도메인 연락 메일, 나라(대한민국), 제품(게임 사진), Claude로 어떻게 만드는지, 설립 시점, 간단한 About. 개인정보처리방침/약관 페이지는 있으면 좋음(선택).

## 3. 게임 사실 (사실만, 지어내지 말 것)
전체: `content_2026-10-08.json`의 `gather:facts`. **검증(verify:facts)은 멈춤 → 'built' 기능과 숫자를 페이지에 쓰기 전에 다시 확인**(아래 명령).
- 한 줄: "A Roblox action RPG where every choice tilts you toward angel or devil — and everyone sees it over your own avatar."
- 핵심 규칙 GDD §0: 모든 행동은 천사 또는 악마 쪽으로 기운다. 첫 선택은 약 3분째 'Lost Lunchbox!'(돌려주기/한 입 먹기).
- 흐름: 3D 인트로 → 진영(Halo/Horns)·직업(전사·마법사·궁수) → 대장간 첫 무기 → 초원 슬라임 → 전리품·강화(10/30/70%, 파괴 없음) → 숲 Lv10 · 폐허 Lv25 · 할로윈 보스. 10분마다 왕관 전쟁(하늘 색 바뀜).
- 일정: 기능 마감 2026-10-24, **베타 2026-10-31 11:00 KST**, 정식 2026-12-19. **게임은 아직 공개 전** → "live", "players", 매출 같은 말 금지.
- 과금 원칙: 능력치는 절대 안 팜. 2x XP/골드·VIP·꾸미기·비공개 서버(A23-75)는 베타 전 예정. 뽑기 없음. 아이 안전(카운트다운·연속 출석 초기화·친구 수 보상 금지).
- 진짜 숫자(2026-10-08 13:41 KST, origin/main 08ae2a86 기준 — 쓰기 전에 다시 세기):
  - Luau 파일 110개 / 64,396줄: `py -c "..."`로 src/**/*.luau 세기
  - 오프라인 시험 65묶음(53개 이상 mutation): `tools/test_*.py`
  - 커밋 1,007개(첫 커밋 2026-10-02): `git rev-list --count origin/main`
  - 2D 그림 503개 승인(Firefly 405): `art/approved.json`
  - 3D 모델 기록 199(GLB 193, 그중 30은 은퇴한 치비 의상): `art/models/tripo/records.json`
  - 효과음 57개: `art/sfx/asset_ids.json`
  - 몬스터 12종, 에이전트 세션 9개
- 만드는 방법: 사람 1명(디렉터, 코딩·그림 경험 없음) + Claude Code 세션 9개(검수/리드, 게임성 개발 1·2·3, 이미지 개발, 이미지 생성 1·2, 소리, 촬영). 도구: Claude Code, Adobe Firefly(2D·효과음), Tripo(3D), Roblox Studio MCP, Blender. 습관: 오프라인 시험 + mutation, '고쳤다' = 메인 Studio PC·폰 Play 사진, 자기 일은 자기가 승인 못 함.
- 창업자 이야기(개인정보 없이): 코딩·그림 배경 없음, 게임을 좋아해 남의 게임에 시간과 돈을 많이 쓰다가 직접 만들기로 함. 큰 결정만 하고 AI 세션 팀이 만들고·그리고·시험함. 첫 게임은 로블록스, 다음은 스팀.

## 4. 사진 (검수 끝, `docs/website/img/`, 합계 약 1.2MB)
| 파일 | 내용 | 주의 |
|---|---|---|
| hero.jpg 1400×933 | 세계 지도(위 Halo 마을, 아래 Horns 요새, 다리로 이은 섬들) | 지도 전체로만 쓰기. 교차로 광장(길 8갈래)을 확대·크롭하면 빛살처럼 보일 수 있음 |
| shot1.jpg 900×442 | 호박왕 보스 전투(영어 HUD) | 10/06 사진이라 이름표 겹침·배너 잘림이 보임 → 메인 Studio 최신 Play 사진이 있으면 교체 |
| shot2.jpg 900×344 | 초원 슬라임 "Blub?" 말풍선 | 가로로 긴 띠, 퀘스트 줄 잘림 |
| shot3.png 478×427 | 깨진 왕관 3D(반 금빛·후광 / 반 빨강·뿔) — 게임 상징 | 투명 PNG |
| shot4.png 700×270 | 3D 몬스터 3종(슬라임·꼬마 유령·호박 슬라임) | 테두리 여백 1px → 페이지에서 패딩 주기 |
| shot5.png 700×336 | Halo 문 / Horns 문 3D | 투명 PNG |
| shot6.jpg 900×384 | UI 그림 모음(버튼·배지·아이콘) | |
모두 노출 없음·빛살 없음·한국어 없음 확인. 다른 사진을 더 쓰면 같은 규칙(AGENTS Hard rule 1, no ray-burst)으로 직접 보고 고르기.

## 5. 디자인 계획 (검수 초안 — 바꿔도 됨)
- 방향: 게임의 두 진영을 그대로. 밝은 쪽 = 후광 금빛, 어두운 쪽 = 뿔 진홍. 라이트/다크 테마 둘 다(artifact 규칙).
- 색 토큰(라이트): 배경 옅은 하늘 #F3F5FB, 글자 남보라 #1C1830, 금 #E8B23A(글자로는 더 진하게 #9A6A0A), 진홍 #C8364A. 다크: 배경 #14111F, 글자 #EDEAF5, 금 #F2C55C, 진홍 #E2566A.
- 글꼴(Google Fonts): 제목 Fredoka(게임 글꼴과 같음), 본문 Figtree, 숫자 JetBrains Mono. 한국어는 Pretendard 대신 Google의 "Noto Sans KR"(또는 "Gowun Dodum") 폴백.
- 히어로 한 가지 상호작용: **선악 저울** — "Return the lunchbox" / "Take a bite" 같은 버튼을 누르면 바늘이 Halo↔Horns로 기움(게임 핵심 규칙을 바로 보여 줌). 그 외 애니메이션은 최소.
- 섹션: 헤더(Glorious Studio, EN/KO) → 히어로(한 줄 + 베타 날짜 + 저울 + hero.jpg) → The game(설명·핵심 규칙·기능: Built/In progress/Planned 칩) → Gallery(shot1~6, 캡션) → How we build(사람 1 + 세션 9 역할표, 도구, 시험 습관, 진짜 숫자) → Roadmap(10/24 마감 → 10/31 베타 → 12/19 정식 → 2027 로블록스 업데이트 → 스팀 PC 게임; 실제 순서라 번호 OK) → About(창업자 이야기, 대한민국) → Contact(jian@glorious.ai.kr + 복사).
- 한국어: 요소마다 `<span lang="en">`/`<span lang="ko">` 둘 다 두고 `html[data-lang]`로 숨김. 기본 en. 선택은 localStorage(try/catch).
- 금지: 지어낸 숫자·사용자 수·수상, "출시됨/live", 빛살 무늬, 스튜디오 이름 번역.

## 6. 남은 일 (순서대로)
1. `content_2026-10-08.json`의 facts 중 'built' 기능과 숫자를 다시 확인(위 명령). 'Sound effects wired into the game'은 소리 7번 묶음 5개가 아직 업로드 대기(크롬 끊김)이니 표현을 "57 sound effects made" 정도로.
2. artifact-design 스킬을 읽고 `index.html` 작성(이미지는 data URI로 넣거나 artifact `files`로 같이 올림). artifact로 publish → 사용자에게 링크(처음엔 비공개).
3. 사용자가 OK하면 **glorious.ai.kr에 올릴 파일**: 같은 HTML을 `<!doctype html>`·`<head>` 포함한 완전한 파일로 + `img/` 폴더(또는 data URI 한 파일). 도메인 호스팅을 어디서 쓰는지 사용자에게 묻고(가비아/카페24/GitHub Pages/Cloudflare Pages 등) 올리는 방법을 짧게 안내. 사용자 대신 로그인·결제하지 않음.
4. 신청 체크리스트 전달: Console 계정, jian@glorious.ai.kr, 사이트 주소, 짧은 설명(Claude Code로 어떻게 만드는지 포함), 설립 시점, 사업자등록 여부.

## 7. 참고
- 워크플로 기록(이 계정): `~/.claude/projects/C--Users-glori-Documents-Roblox-Game/8b6ac5a0-.../subagents/workflows/wf_30bc4aab-2fb/journal.jsonl` (gather 3개 + 사진 검증 끝, research·facts 검증은 멈춤).
- 사진 원본 경로는 content JSON의 `gather:images[].source`.
