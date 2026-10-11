# 검수 인계 — 2026-10-11 저녁 (3번째 검수, 주간 사용량 94% → 19:00 리셋 전 정리)

> 먼저: AGENTS.md(10/11 줄인 판) → `docs/handoff/role_prompts/README.md` → 이 파일. 옛 `review_handoff_2026-10-11b.md`는 기록. 세션 id는 list_sessions로 찾는다(문서에 안 씀).

## 1. 오늘 사용자 결정 (SPEC 맨 위)
- **A23-127:** 제작은 장인 직업만(기본~전설·신화), 일반은 몬스터 드롭 무기, 유저 거래소(모든 서버 하나, 거래소만·1:1 없음, 팔 때 수수료 10%, 2배 골드 패스 유지), **골드→로벅스 없음**.
- **큰 일은 Anthropic API(api_agent)로**, 세션은 지휘·확인·앱 도구 일만(role_prompts README).
- **할로윈 시험은 병합 조건 아님**(내년 10월).
- 무기 디자인을 이미지 생성 2 큐 맨 앞으로(9종 × T1~T3 시트 Medium → 검수 고름 → 4면 High → Tripo).
- 한국어: 늘 같은 큰 글(간판·판 제목·창 제목) = GPT 글자 그림, 바뀌는 글 = 꾸민 나눔고딕(계약 §8을 월드에도, 7f3d691c).

## 2. 오늘 병합 (main)
028a937e(grips9 + bosshp + landcircle + leapfx) · 51aa97f3(petlist + healfair) · c9782f4f(goosemut) · b0dd0dd3(grips10) · 3acb3f18(새 구역 몬스터 표, 꺼진 스위치). AGENTS.md 줄이기 e33a41e(+ `docs/handoff/agents_detail.md`).
- 메인 Studio: c9782f4f까지 sync·사진 끝. **HH_Fabric(밝은 천 MV)이 메인 Studio에 들어가 있음 → 다음 Save to File As 때 저장**(메인 반영 1). 3acb3f18은 아직 sync 안 함(꺼진 스위치라 급하지 않음).

## 3. 리셋 뒤 검수 큐 (순서)
1. **md 정리 API 4개**(사용자 "md도 최신 규칙과 어긋나는 것 검수하고 삭제"): 브랜치 `api/md-audit-core`·`-design1`·`-design2`·`-history`, 결과 `build/api_agent/md_audit_*/result.md`. 지운 파일마다 "가리키는 곳 없음"이 맞는지, 사용자 규칙(복장·업로드 금지·Publish·비밀 키)이 안 지워졌는지 보고 병합. 서로·SPEC와 겹치면 하나씩.
2. **스트리밍 켜기 결정:** `docs/review/streaming_risk_2026-10-11.md`(개발 1). 제안: 연습 Studio에서 Min 160/Target 512 → main 전 A표 T-1~T-5·T-8·T-9 + B표 6줄 고침. 코드는 API 쓰기 모드.
3. 개발 1 `api/dev1-l10n-core`(한국어 클라 중심) 시험·병합 → 개발 2 한국어 서버 A→B→C.
4. 개발 2 **A23-127 설계 문서**(`docs/design/crafting_market_2026-10-11.md`, API) 확인 → 서버 덩어리별 API.
5. 그림·3D 판정: 이미지 생성 2 무기 시트·이유 소품 10종(halo_reason_props_4views.jpg)·벤치 옆(halo_bench_sides_fix.jpg)·등불 정면 / 이미지 생성 3 집 1묶음 고침·11채 spec / 이미지 생성 1 바닥·섬 아래 사진 16장.
6. api/* 다 쓴 브랜치 지우기(skeleton-ground·island-underside는 daf4094로 이미 main).

## 4. 알아 둘 것
- **세션 메시지 한도:** 사용자가 말한 뒤 10개. 사용자가 작업 중간에 보낸 말로는 안 풀린다. 막히면 사용자에게 한마디 부탁.
- **워크트리 세션은 앱으로 못 연다**(전체 6GB, 5분 넘음). 시험은 sparse worktree(`Game-rv3lite`, src·tools·docs, 0.5GB). api_agent도 sparse가 기본(e6779bed).
- 병합은 공유 트리를 안 건드리고 `git merge-tree --write-tree` + `commit-tree` + `push <commit>:main`. 병합 뒤 sparse에서 핵심 시험 한 번 더.
- 판정 사진은 WorldKit **C2c 낮 빛**으로(기본 빛은 벽이 회색, 금이 올리브로 보임).
- 공유 트리 `.git/index.lock`이 멈춰 있으면(빈 파일, git 프로세스 없음) 지우고 `reset --keep origin/main`.
- 로딩: StreamingEnabled=false, SurfaceAppearance 약 1255개. 진짜 로딩 시간은 10/17 비공개 시험에서 PC·폰으로 잰다.
