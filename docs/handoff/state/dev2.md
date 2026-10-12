# 게임성 개발 2 — 상태 (2026-10-13 정리)

## 10/13 정리 (사용자: "이제 정리하고 컴퓨터 꺼줘")
- **도감 카드 서버(A23-153) 끝 = dev2-codex 3481c431 → main 0aa6a0b7 병합, 메인 Play 확인 통과(최종 검수).**
  CodexService(새) + 저장 v5(옛 저장은 KillLog.ByKind에서 카드 한 번, 보상 없음) + 원격 CodexOpen/Codex/CodexUp +
  속성 CodexCards/CodexGlow + Config.Codex(11종·3페이지, 단계 1/100/1000, **보스 1/10/30**, 보상 3/20/100마리 몫·보스 1/3/10·포일 5,
  작은 몫(info.Minor) 단계 보상 × MinorShare, XPCapBelowLevel 아래면 카드 XP 한 레벨까지, 칭호 Slime/Goblin/Skeleton Scholar).
  약속 문서 `docs/design/codex_cards_contract_2026-10-13.md`(화면 = 게임성 개발 1). 시험 test_codex 139 + 정적 13, 변이 60/60.
  저장 v5로 옛 시험(버전 4 고정) 16개 fixture + save_v4_tables·stats·weapon_ladder·gamepass 고쳐 함께 들어감.
  최종 검수 결정: 뒷면 이야기 33줄은 카드 화면 만들 때 다듬기, ServerToast = true 그대로(카드 순간 화면 들어오면 개발 1이 false).
- **C2 = dev2-c2 eb3c2633 (push함)**: 491ef614(드롭표·첫 무기 드롭 BigSlime T2·겹친 무기 → Spares) + main 병합 2번(마지막 eb3c2633, 충돌 없음).
  아직 보고 안 함. 할 일: 최신 main 병합 → 전체 시험 하나씩 → 실패(new_zones 무기 줄 비교, 경제·첫 10분 등) 고치기 → 숫자와 함께 최종 검수 보고.
- **지금 큐는 멈춤(사용자 상시 지시 10/12 22:30: 이미지→Tripo 먼저):** C2·거래소 등 새 일은 Tripo 끝난 뒤 최종 검수가 부르면 시작.
- 전체 시험 기준(10/13, main 기준): 183개 중 원래 실패 9개 = costume_physics·skin_binding(은퇴), halloween·shop_layout(그림 필요),
  place_english(place 필요), rank_marks, ops_safety 변이 "Halloween is not applied", skeleton_ground(build/wk/halo_walls.json 없음),
  studio_guard 변이 "only GoodEvil is main"(0번 맞음). api_agent·claude_doc_worker는 건너뜀(도구 자체 시험).
- **지우지 못한 worktree 5개**(병합 끝, 시험 출력 파일만 남음; 자동 모드 분류기가 `git worktree remove` 막음, 최종 검수도 막힘 → 그냥 둠):
  ../wt_goose_square, ../wt_stickers, ../wt_lesstext_server, ../wt_c1, ../wt_famecap. 그 밖에 ../wt_codex(병합 끝), ../wt_base(main 기준 시험용, detached).

서버 전용·Studio 금지·main에 코드 push 금지(검수가 병합). **보고처 = '최종 검수'**(id는 list_sessions). 보고는 묶음마다 한 번.
시험은 한 번에 하나씩(PC 렉), 서브에이전트·워크플로 쓰지 않음(최종 검수 10/13). 대화가 길어지면 이 파일 적고 push → clear_session("self").
- API(api_agent) 거의 바닥(남은 것은 최종 검수의 최종 병합 검토용) → 큰 일도 앱에서 직접.

## 다음 큐 (Tripo 끝난 뒤, 최종 검수가 부르면)
1. **C2** 위 그대로.
2. 거래소 서버(C-5/C-7): 개발 4 계약 `origin/dev4-market` `docs/design/market_window_2026-10-12.md` §6 합의(MarketIndex 30초 캐시·요약 맵,
   무기 키 "T:P", Pages·Paid·Today, Gate { Buy, List, ListIn }, 거래소 퀘스트 3개는 내 몫, 거절 키 + TooFast·Off).
3. `api/dev2-l10n-a` 정리(한국어 모드 취소 A23-146 → 필요한 것만), 제작 설계 `api/dev2-crafting-design` ea0ce9bc 정리(A23-127).
4. A23-138 영어 밈 서버 쪽(fix/meme-en-server).
- 알아 둘 것: 개발 3이 내 파일에 넣은 줄 — 연금 물약 BuffService.Mult 4줄(Combat·Loot·Progression), 조련사 PetService(SummonPet·AddPetXP·
  PetRoll, findSpecies는 소환 펫 제외), 장비 api/dev3-gear — 모두 검토 OK. 보스 재료도 행운 물약에 오름(빼려면 `def.Source == nil`, 결정 대기).

## worktree·도구
- 가벼운 worktree: `git worktree add --no-checkout -b <가지> ../wt_<이름> origin/main` → `MSYS_NO_PATHCONV=1 git sparse-checkout set
  --no-cone /src/ /tools/ /docs/ /AGENTS.md` → `git read-tree -mu HEAD` → `cp -r ../Game/build/luau_cli_0_741 build/`.
  worktree 안에서 `git add <새 파일>` + `git commit -m … -- <경로>`(docs/art 시험 출력은 빼고, 내 새 보고서만).
- 고치기: Write 도구로 스크래치에 python 정확 치환 스크립트(Bash heredoc은 `\t`·`\n`·작은따옴표를 망침). Python write_text는 CRLF로 씀 →
  git이 LF로 맞춰 줌(경고만). 시험 줄 상세에 플레이어 객체를 show()하면 스택 넘침.
- 전체 시험: 스크래치에 run_all_tests.py(`<worktree> <outdir> [시험 이름…]`, 하나씩, a23_14는 --no-mutations) — 스크래치는 세션마다
  지워지니 다시 만들 것(tools/test_*.py 차례로 `py tools/<t>` 실행, rc·로그 저장). **시험 도는 중엔 그 worktree 파일을 고치지 말 것**.
