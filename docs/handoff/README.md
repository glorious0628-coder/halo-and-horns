# 인계 폴더 — 읽는 순서 (검수 2026-10-11)

규칙 우선순위는 `AGENTS.md`의 "Which rule wins"를 따른다. 인계 파일은 현재 파일·브랜치·최신 사용자 결정과 대조한 뒤 쓴다.

1. `AGENTS.md` → 이 파일 → `role_prompts/README.md` → 자기 역할 프롬프트.
2. `state/<역할>.md`가 있으면 읽는다. 검수는 `state/review.md`.
3. 가장 최신 `review_handoff_*.md`를 끝까지 읽는다. 현재 최신은 `review_handoff_2026-10-11e.md`(앞은 11d).

- `role_prompts/`는 검수가 관리하는 시작 안내다. 모델 표·도구 이름·옛 작업 큐를 현재 실행 상태로 추정하지 않는다.
- `state/`와 최신 검수 인계의 완료 표시는 근거 커밋·검증 결과·실제 Studio 상태를 구분해 읽는다. 파일 수정·푸시·Studio 반영·Play 검증은 각각 다른 상태다.
- 그 밖의 날짜별 인계·설계·검토 문서는 기록이다. `after_reset_*` 등의 옛 큐·허락·사용량·종료 지시는 오늘 작업을 허락하지 않는다. `agents_detail.md`·`api_agent_howto.md`는 필요한 절만 참고한다.
- 현재 도구로 이 프로젝트 또는 연결 worktree의 세션을 찾는다. Codex에서는 `list_threads` → `read_thread`/`wait_threads`, 사용자가 전달을 지시한 세션에는 `send_message_to_thread`를 쓴다. 세션 id는 문서에 저장하지 않는다.
- 10/11 사용자 확인: 담당 작업 세션은 아직 새로 만들지 않았다. 최신 인계의 역할별 작업은 전달 대기이며 실행 중이 아니다.
- 일정은 A23-119: 비공개 시험 10/17~20, 기능 마감 11/24, 공개 베타 12/1 11:00 KST(장인 길드 포함), 정식 2027년 1월 말.
