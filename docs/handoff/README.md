# 인계 폴더 — 무엇이 지금 기준인가 (검수 2026-10-09)

**이 폴더에서 지금 기준은 두 곳뿐이에요.**
1. `role_prompts/` — 세션마다 시작 프롬프트(이름·모델·노력·첫 일). 검수가 관리해요.
2. 가장 새 `review_handoff_*.md`(지금은 `review_handoff_2026-10-10.md`) — 오늘 상태·세션 표·내일 첫 일. 그 전 날짜 파일은 기록이에요.

나머지 파일(`*_status_*`, `*_handoff_*`, `*_evening`, `*_night`, `account_switch_*`, `api_mode_start_*`, `next_account_*`, `session_prompts_*`, `main_apply_queue_*`, `review_restart_*` 등)은 **그날의 기록**이에요(헷갈릴 만한 파일은 맨 위에 '기록용' 한 줄). 옛 세션 id, 옛 담당, 옛 큐, 옛 허락이 적혀 있어도 오늘 일을 허락하지 않아요(AGENTS.md "Which rule wins" 6번과 같은 원칙).

- 규칙 순서: 사용자 최신 결정 → AGENTS.md → `docs/RELEASE_PLAN.md` → `docs/SPEC_ADDENDUM.md` A23(번호 큰 것이 최신) → GDD.
- 세션 대화 끝부분(자동 추출)은 git에 없는 `build/handoff_<날짜>/<역할>_tail.md`에 있어요(10/09 16:11까지 = `build/handoff_2026-10-09b/`).
