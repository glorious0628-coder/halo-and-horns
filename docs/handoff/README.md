# 인계 — 지금 읽을 것 (최종 검수, 2026-10-13 밤에 새로 씀)

10/13 밤에 md를 정리했다(467 → 약 170). 지운 문서는 git 역사(이 커밋 이전)에 있다. **날짜가 10/12보다 오래된 문서는 기록이지 허락이 아니다.**

## 읽는 순서 (모든 세션)
1. `AGENTS.md` — 규칙. "Which rule wins"와 "Latest user decisions"만 외우면 된다.
2. `docs/SPEC_ADDENDUM.md` 맨 위 — 사용자 결정, 번호가 클수록 새것(지금 A23-163).
3. `docs/handoff/role_prompts/README.md` — 지금 세션 표(누가 무엇을, 모델·노력). 자기 역할 파일(`role_prompts/0N_*.md`)과 `state/<역할>.md`.
4. `docs/design/six_week_plan_2026-10-13.md` — 12/15까지 주별 목표와 세션별 몫, 시험 셋, 디자인 마감표.
5. `docs/design/gameplay_plan_2026-10-13.md` — 일 목록(번호 #). 날짜는 six_week_plan이 대신한다.
6. `docs/handoff/state/review.md` 맨 아래 — 최종 검수의 지금 상태·기다리는 것.

## 지금 숫자 (10/13 밤)
- 공개 베타 **12/15(화) 11:00**, 기능 마감 12/8, 두 번째 시험 12/3~6, 첫 10분 시험 11/7~10, 기술 시험 10/17~20(동결 없음). 정식 2/9쯤.
- 세션 4개: 최종 검수(Fable 5.1 high), 메인 반영 1(Sonnet 5.5 medium), 게임성 개발 1·2(Opus 5.5 high). 10/20 이미지 생성 2, 10/27 Blender 손보기 + 디자인 검수 다시(A23-163).
- 돈: Tripo·Firefly High·ChatGPT 생성 = 사용자 "가" 전까지 0. API ≈$200은 `tools/api_agent.py`로 반박 검토·긴 읽기.

## 자주 쓰는 문서
| 무엇 | 파일 |
|---|---|
| 사용자 10/15·16 할 일 | `docs/design/private_test_user_checklist_2026-10-15.md` |
| 빛 마을 지출(A) / 최소 그림 범위(B) | `docs/review/halo_spend_2026-10-13.md`, `docs/review/art_scope_min_2026-10-13.md` |
| 3D 다섯 단계 | `docs/design/3d_pipeline_2026-10-13.md` (+ SPEC A23-159·158·157·154) |
| PBR 최종 판정·멀티뷰 다시 후보 | `docs/review/pbr_final_2026-10-13.md`, `docs/review/multiview_redo_triage_2026-10-13.md` |
| 그림자 없이 다시 목록 | `docs/review/noshadow_redo_2026-10-12.md` |
| 집 장식 덩어리·빛 마을 고정점 | `docs/design/house_chunk_decor_2026-10-12.md`, `docs/design/halo_fixed_points_v2_2026-10-11.md` |
| Firefly 자동 받기 | `docs/handoff/firefly_autodownload_2026-10-13.md` |
| 게시·운영 | `docs/design/launch_ops_checklist.md`, `docs/ops/launch_day_runbook_2026-10-09.md`, `docs/ops/switchboard_2026-10-09.md` |
| 영어 용어·대본 | `docs/design/glossary_en_2026-10-06.md`, `docs/script/script_en_ko_2026-10-12.md` |
| 긴 설명·사고 기록·도구 목록 | `docs/handoff/agents_detail.md` |
| API 검토 도구 | `docs/handoff/api_agent_howto.md` |
| 아이디어 보관 | `docs/design/idea_backlog.md` |

## 남긴 설계 문서의 규칙
- `docs/design/*_server_*.md`, `*_contract_*.md`처럼 **코드 주석이 가리키는 문서**는 남겼다(그 기능의 계약). 바꿀 때 코드와 같이 고친다.
- 10/12 이후 문서는 전부 남겼다. 새 문서는 `docs/design/<이름>_<날짜>.md`, 끝나면 이 표에 한 줄.
- 세션 상태는 `state/<역할>.md` 한 파일에 덮어쓴다(날짜별 새 파일 금지). 인계 묶음도 `state/review.md`에 절로 덧붙인다.

## 보고 길
- 코드 가지 → 최종 검수(API 반박 검토 → merge_chain 병합 → 메인 반영 1 sync·사진).
- 그림·3D → 디자인 검수(10/27부터) → 최종 검수. 사용자에게 가는 말은 전부 최종 검수만.
- 화면 쓰는 모든 단계: "<세션> / 무엇 / 몇 초" → 최종 검수가 사용자에게 🟠 → "전달함, 시작" → "끝".
