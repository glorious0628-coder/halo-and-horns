# 인계 폴더 — 무엇이 지금 기준인가 (검수 2026-10-09, 10/11 고침)

**이 폴더에서 지금 기준은 이 곳들이에요.**
1. `role_prompts/` — 세션마다 시작 프롬프트(이름·모델·노력·첫 일). 표는 `role_prompts/README.md`(상시 8개 세션, 검수가 관리해요).
2. `state/<역할>.md` — 세션별 상태(있으면).
3. 가장 새 `review_handoff_*.md`(지금은 `review_handoff_2026-10-11b.md`) — 오늘 상태·세션 표·다음 일. 그 전 날짜 파일은 기록이에요.
4. 10/11 새 기준 문서: `after_reset_2026-10-11.md`(리셋 뒤 할 큰 일), `api_agent_howto.md`(api_agent 쓰는 법), `agents_detail.md`(AGENTS.md 긴 설명), `docs/design/halo_restart_2026-10-11.md`(빛 마을 다시 짓기, A23-121).

나머지 파일(`*_status_*`, `*_handoff_*`, `*_evening`, `*_night`, `account_switch_*`, `api_mode_start_*`, `next_account_*`, `session_prompts_*`, `main_apply_queue_*`, `review_restart_*` 등)은 **그날의 기록**이에요(헷갈릴 만한 파일은 맨 위에 '기록용' 한 줄). 옛 세션 id, 옛 담당, 옛 큐, 옛 허락, 옛 날짜(베타 10/31·마감 10/24·정식 12/19)가 적혀 있어도 오늘 일을 허락하지 않아요(AGENTS.md "Which rule wins" 6번과 같은 원칙). 세션 id는 새 문서에 쓰지 않아요(list_sessions로 찾기).

- 규칙 순서: 사용자 최신 결정 → AGENTS.md → `docs/RELEASE_PLAN.md`(날짜는 A23-119가 이김) → `docs/SPEC_ADDENDUM.md` A23(번호 큰 것이 최신) → GDD.
- 지금 날짜(A23-119): 베타 2026-12-01 11:00 KST(장인 길드 포함), 기능 마감 11/24, 정식 2027년 1월 말.
- 세션 대화 끝부분(자동 추출)은 git에 없는 `build/handoff_<날짜>/<역할>_tail.md`에 있어요(10/09 16:11까지 = `build/handoff_2026-10-09b/`).
