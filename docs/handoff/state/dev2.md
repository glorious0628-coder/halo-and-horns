# 게임성 개발 2 — 상태 (2026-10-14 새벽)

서버 전용·Studio 금지·main에 코드 push 금지(최종 검수가 병합). 보고처 = '최종 검수'(list_sessions, send_message). 덩어리마다 한 번.
읽는 순서: `docs/handoff/README.md`(새 입구) → `role_prompts/03_dev2.md` → 이 파일 → `docs/design/six_week_plan_2026-10-13.md`(주별 몫).

## 가지 (모두 push, 최종 검수 병합 대기·진행)
| 가지 | tip | 무엇 | 상태 |
|---|---|---|---|
| fix/test-prep-server | e43370e2 | 1-A 서버 몫 + 시험 스위치 | main 병합됨 |
| fix/test-prep-server-2 | bd50ad74 | 시험 숫자판(TestMetricsService, tools/test_metrics_board.py), set_pass_ids, 검토 고침 3개 + main 합침(bag_ui = 개발 1 판) | 검토 MERGE, 병합 중 |
| fix/mischief-name | 61d7c162 | A23-166 보이는 Infamy → Mischief(Config.FameName/FameLabel) + 검토 MINOR 3개(숫자판 Live 끔, Kept = Roblox 실제 답만 = MonetizationService.PassAnswer·'Unknown', 주문서 칸 가득 차면 표시 유지) | 보고함 |
| fix/scroll-toast-off | 696088cf | 첫 Slime Prince 주문서 안내 토스트 삭제(A23-130, Loot.Text.FirstScroll* 키 삭제) | 보고함 |
| dev2-honor-crown | ab6fcc0a | 2-A #4 HuntFameService + #5 왕관 새 점수(WarService.AddKill/PersonalAdded) — mischief 위 | 보고함. 설명 `docs/design/honor_crown_server_2026-10-14.md` |
| dev2-halo-stage6 | bd903c79 | 빛 마을 6단계 서버 | 2주 차 교체 날 병합(map_v2 2개 = 새 큰 지도 그림 기다림) |

- 날짜 박힌 값 목록(3주 차 '아주 먼 날짜 + 출시 날 스위치', 2-A #12): BuildLabel, Beta.PioneerUntil 12/19, 하늘 주석 '12/19 launch',
  Halloween EndsAt 11/09·Banter DayOneStart 10/31, Badges Order Halloween2026, 할로윈 주석 'beta 2026-12-01', 글 "launch date is set in December".
- 다음 후보(최종 검수가 정함): 6단계 서버 병합, 무기 운 보정(2-A #6), 골드 쓸 곳(#7), 스탯 서버(#9), 날짜 값(#12), 보스 경쟁·황금 시간(crown_war_content).

## worktree·도구
- ../wt_prep(test-prep-server-2), ../wt_prep_t(전체 시험 고정판), ../wt_mischief, ../wt_scroll, ../wt_honor, ../wt_halo6. 병합 끝난 것은 그냥 둠.
- 가벼운 worktree: Game에서 `git worktree add --no-checkout -b <가지> ../wt_<이름> origin/main` → `MSYS_NO_PATHCONV=1 git sparse-checkout set
  --no-cone /src/ /tools/ /docs/ /AGENTS.md` → `git read-tree -mu HEAD` → `cp -r ../Game/build/luau_cli_0_741 build/`.
- 시험 실행기: 스크래치 run_tests.py(`<worktree> <outdir> [이름…]`, 하나씩; rc·CHECK_FAIL·failing·MISSED 요약). 스크래치는 세션마다 다시 만듦.
  시험 도는 worktree 파일은 고치지 말 것. 커밋 전 `git checkout -- docs/art/`(시험 보고서 되돌림).
- **Bash 도구는 `\n`·`\b`를 진짜 줄바꿈·백스페이스로 바꿈** → 백슬래시가 든 고침은 Edit 도구나 Write로 만든 py 파일로.
- 시험 상세에 플레이어 객체를 show()하면 스택 넘침 → 플레이어 뺀 복사본으로.
- 새 저장 칸·새 연결은 다른 시험 세계에서 경고가 나지 않게 '부드럽게' 찾기(PvP 훅처럼).
- 원래 실패(main): costume_physics(은퇴), halloween(그림 필요), ops_safety 변이 'Halloween is not applied', place_english, rank_marks,
  skeleton_ground, studio_guard 변이, skin_binding.
