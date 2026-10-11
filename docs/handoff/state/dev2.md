# 게임성 개발 2 — 상태 (2026-10-11 19:00 리셋 전 정리)

서버 전용·Studio 금지·main에 코드 push 금지(검수가 병합). 큰 코드는 api_agent 쓰기 모드로 맡기고, 개발 2는 지휘·검증만 한다
(사용자 "무거운 작업 다 api가"): `py tools/api_agent.py run --prompt-file P.md --out build/api_agent/<job> --model opus|sonnet
--max-usd 5 --max-turns 60~80 --make-worktree <ref> --write --branch api/<이름> [--allow-run-modified-py]` → api/* 가지를 읽고
시험한 뒤 검수에게 병합 요청. 보고처 = '모든 것 검수'(id는 list_sessions로).

## 오늘 main에 들어간 것 (10/11)
dev2-bosshp(필드 보스 체력, 검수 지적 6개 고친 판) · dev2-landcircle(바닥 원 서버, +dev1-leapfx) · dev2-walkground ·
dev2-petlist · dev2-healfair(A23-126) · dev2-goosemut · 새 구역 몬스터 표(api/dev2-newzones*, main 3acb3f18, 스위치
Config.NewZones.Enabled = false). 쓴 api/dev2-newzones* 가지는 지움.

## 돌고 있는 API 작업 (API 크레딧, 그대로 둬도 됨)
1. **A23-127 설계 문서** — job `dev2_crafting_design`(opus $5/70턴) → 가지 `api/dev2-crafting-design`, 파일
   `docs/design/crafting_market_2026-10-11.md`(장인만 제작·신화 등급·드롭표·오토/의뢰 다시 설계·전역 거래소·첫 10분·시험 이름·
   열린 결정).
2. **한국어 서버 A(기반)** — job `dev2_l10n_a`(opus $5/80턴, --allow-run-modified-py) → 가지 `api/dev2-l10n-a`, 기준
   `origin/api/dev1-l10n-core` a8462d18(개발 1 L10n 중심, 검수 병합 요청 중). 범위: Lang 속성, PublicNameArg/hiddenNameArg·
   KaijuHidden, 이름 키 도우미, 프롬프트 → Config.Text.Prompts + ActionKey/ObjectKey, 펫 기본 이름 "", 채팅·Kick 예외,
   dev2_kit NotifyKey 대역, 시험 test_l10n_server_a(영어 글 한 글자도 그대로 비교).
- 결과 보기: `py tools/api_agent.py status <job>`, `build/api_agent/<job>/result.md`.

## 다음 큐 (순서, 검수 OK)
1. A23-127 설계 문서 확인 → 검수에게 → 승인 뒤 서버 코드를 덩어리별 API 쓰기 작업(작업당 ≤ $5).
2. 한국어 서버 A 확인(시험 다시 돌림) → 병합 요청. 그다음 **B**(알림 약 230곳·래퍼 17개 → NotifyKey, 서비스 묶음별 API
   작업 2~3개) → **C**(퀘스트 TextKey/Countless·게시판 Named·KO Fx Kind/TipIndex/이름 Arg·거위 RareAnnounce·Bark 키·
   SessionTitle id·이름표/몬스터 바 Gui 비우기·간판 TextKey+L10nText·현상수배판 BoardRows). B·C는 제작 덩어리 사이사이에.
   규칙: 영어로 보이는 글은 한 글자도 바뀌면 안 됨 → 가지마다 "옛 글 = L10n.T(en)" 비교 시험. v4 확인 새 문제 4 항목
   (KO Fx Name·TipIndex, Bark 키, SessionTitle, KaijuHidden, 펫 기본 이름, 퀘스트 TextKey/Countless)은 B·C 시험에.
3. 남은 판단 없음(Lv30+ 클래터 혼자 빨리 = 베타엔 그대로, 새 구역 라이브 스위치 = 지금 필요 없음).

## worktree
Game-dev2-ci, Game-dev2-hint(stage된 빛 마을 도구 8개 = 옛 검수 흔적, 건드리지 말 것), Game-dev2-pet, Game-dev2-snap —
모두 병합 끝, 다음 일에 origin/main에서 새 가지로 재사용. 각 폴더에 build/luau_cli_0_741 있음.

## 참고
- 설계: docs/design/field_boss_crowd_2026-10-11.md, boss_leap_2026-10-11.md, new_zones_monsters_2026-10-11.md.
- 시험이 덮어쓴 옛 docs/art/verification_* 보고서는 커밋 전에 되돌림. 새 결과는 날짜 파일로.
- 파이썬 고칠 때 Bash 안 `\n`·`\t`가 바뀜 → Write로 스크립트 파일을 만들어 실행.
