# 게임성 개발 2 — 상태 (2026-10-13 밤)

서버 전용·Studio 금지·main에 코드 push 금지(최종 검수가 병합). 보고처 = '최종 검수'(list_sessions, send_message). 덩어리마다 한 번.
읽는 순서: `docs/handoff/README.md`(새 입구) → `role_prompts/03_dev2.md` → 이 파일 → `docs/design/six_week_plan_2026-10-13.md`(주별 몫).

## 끝난 것 (10/13)
- **dev2-halo-stage6** = 814bb3ca + bd903c79(test_map_v2 변이 문자열) push. 6단계 병합은 2주 차(10/20~26) 첫 일. map_v2 2개 실패 = 새 큰 지도 그림 기다림.
- **fix/test-prep-server e43370e2** = main 병합됨(0c2bc4cc). 1-A #2 #3 #4 #7 #9 #10 #11 + A23-138 이름 + 시험 스위치. 설명 `docs/design/test_prep_server_2026-10-13.md`.
- **fix/test-prep-server-2 8df1f299**(origin/main cbd83f91 위) push, 보고 대기: 시험 숫자판(TestMetricsService + `tools/test_metrics_board.py`,
  문서 `docs/design/test_metrics_2026-10-13.md`), `tools/set_pass_ids.py`(패스 9개 ID), 검토 MINOR 3개(ApplyTestServer Live 막기, test_test_server
  거짓 FINDING, 주문서 지급 실패 = 표시 지우고 RetryGifts가 접속 때 다시). 손댄 시험 다 통과. **전체 시험은 ../wt_prep_t(8df1f299 고정)에서 도는 중** →
  끝나면 숫자를 최종 검수에 보고.
- 날짜가 박힌 값 목록(3주 차 '아주 먼 날짜 + 출시 날 스위치' 몫, 2-A #12): BuildLabel, Beta.PioneerUntil 12/19, 하늘 주석 '12/19 launch',
  Halloween EndsAt 11/09·Banter DayOneStart 10/31, Badges Order Halloween2026, 할로윈 주석 'beta 2026-12-01', 글 "launch date is set in December".

## 다음 (2주 차, 최종 검수 지시 10/13 밤)
- 가지 **dev2-honor-crown**(origin/main에서): #4 PvP 없이 명예·악명(자기 레벨대 사냥 100마리당 1점, 하루 선행 점수) + #5 왕관전 새 점수
  (A23-135·137: KillsPerPoint 100, 황금 = 5마리, PvP KO 2 + 별당 0.5·판당 3번, 괴수 30, 알 30(이미 WinWarPoints), ChestMinPoints·SiegeTarget
  다시, M2_1 'Crown points 15'·서브 40·S2 30, 몬스터마다 '+1' 안 뜨게). 지금 값: `Config.War`(MonsterPoints 1, GoldenPoints 5, PvPKOPoints 20,
  PerStar 5, SiegeTarget 150, ChestMinPoints 30), `Config.Kaiju.HaloWarPoints/HornsWarPoints` 150.
- 6단계 서버 병합은 6단계 교체 날 최종 검수와 같이.

## worktree·도구
- ../wt_prep = fix/test-prep-server-2, ../wt_prep_t = 전체 시험용 고정 판, ../wt_halo6 = dev2-halo-stage6.
- 가벼운 worktree: `git worktree add --no-checkout -b <가지> ../wt_<이름> origin/main` → `MSYS_NO_PATHCONV=1 git sparse-checkout set --no-cone
  /src/ /tools/ /docs/ /AGENTS.md` → `git read-tree -mu HEAD` → `cp -r ../Game/build/luau_cli_0_741 build/`. **경로는 worktree add를 Game 안에서
  부를 때 '../wt_…'**(Game -C로 부르면 Game 안에 생김).
- 시험 실행기: 스크래치 run_tests.py(`<worktree> <outdir> [이름…]`, 하나씩, a23_14는 --no-mutations; 로그·rc·CHECK_FAIL·failing·MISSED 요약).
  시험 도는 worktree 파일은 고치지 말 것. 전체 시험은 따로 고정 worktree에서.
- **Bash 도구는 `\n`·`\b`를 진짜 줄바꿈·백스페이스로 바꿈** → 백슬래시가 든 고침은 Edit 도구나 Write로 만든 py 파일로.
- 원래 실패(main): costume_physics(은퇴), halloween(그림 필요), ops_safety 변이 'Halloween is not applied', place_english, rank_marks,
  skeleton_ground, studio_guard 변이, skin_binding.
- 일반 몬스터 드롭 줄에 BelowLevel 쓰지 말 것(LootService.rollRows는 처치마다 줌).
