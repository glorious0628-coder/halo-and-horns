# 게임성 개발 2 — 상태 (2026-10-12 저녁)

서버 전용·Studio 금지·main에 코드 push 금지(검수가 병합). **보고처 = '최종 검수'**(10/12 게임성 검수 쉼; id는 list_sessions).
보고는 묶음마다 한 번. 대화가 길어지면 이 파일 적고 push → clear_session("self").
- **API(api_agent) 거의 바닥(10/12 남은 약 $22, 최종 검수: 최종 병합 검토용으로 남김) → 큰 일도 앱에서 직접.** 충전되면 최종 검수가 알림.
  도구 버그 고침: edit_file이 파일 전체 크기를 쓰기 한도에 세던 것 → main 476362b(새 글만 셈).

## 보고함 / 검토 대기 (최종 검수; 보고한 가지 = 다시 쌓지 말고 위에 커밋만; main 합치기는 충돌 때만)
- **fix/lesstext-server 8c8dc44d** — 강화 결과 토스트 5개 되살림, 보스 등장 구역 이름, 출석 이정표 줄.
- **C1 = api/dev2-c1-t9-v4 ab9578b7** — 최종 검수 API 검토 VERDICT MERGE, 병합 중. 그 위 **fix/c1-minor 1b491953**: 보스 재료
  Feature = "Crafting"(제작 꺼지면 드롭 안 함, 뽑기는 함), v3 9번째 비트는 band로 아래 8칸 살림.
- **fix/fame-cap d3c40ce9** (dev3-fame a5d38f39 위): WeekCap.Artisan 60 + CraftWeekCap 100 + Config.WeekCapOf(제작 켜짐일 때만 100).
- **거위 광장 = dev2-goose-square e6dc909a** (황금 알 1차 3dfdc791 + 광장 서버 d689d56f + main 합침 + 계약 문서 §6·§9 답).
  worktree ../wt_goose_square. 명예 +5 = GrantFame RankPoints. 이야기 GooseNest 표지는 교차로 그대로(부활절 달걀).
  Config.Goose.Square는 개발 1 fix/goose-square에만(서버는 읽기만).
- worktree: wt_c1(fix/c1-minor), wt_famecap(fix/fame-cap), wt_goose_square, wt_lesstext_server — 병합되면 지우기.

## 다음 큐
0. **스티커 패스(SPEC A23-143)**: 이미지 개발 스티커 17개 Config.UIArt.Parts.Emo<이름>, 무료 5개 = Parts `Free = true`(EmoThumbsUp·
   EmoQuestion·EmoExclaim·EmoHelp·EmoThanks), 나머지 12 + EmoGG = 99 R$ 패스 — 패스 목록·가격·소유 Config는 내 몫(가지 imgdev-stickers de9e4fcf).
1. **C2**: 드롭표 + 첫 Prince T2 + 중복 무기 → Spares(save_v4·crafting_market §3·§7). C1 병합 뒤.
2. 거래소 서버(C-5/C-7): 개발 4 계약 `origin/dev4-market` `docs/design/market_window_2026-10-12.md` §6 합의(MarketIndex 30초 캐시·요약 맵,
   무기 키 "T:P", Pages·Paid·Today, Gate { Buy, List, ListIn }, 거래소 퀘스트 3개는 내 몫, 거절 키 + TooFast·Off).
3. `api/dev2-l10n-a` 필수 시험·보완 → 병합 요청. 제작 설계 `api/dev2-crafting-design` ea0ce9bc 정리(A23-127).
4. 한국어 서버 B·C(알림 → NotifyKey 등). 5. A23-138 영어 밈 서버 쪽(fix/meme-en-server).
- 알아 둘 것: 개발 3이 내 파일에 넣은 줄 — 연금 물약 BuffService.Mult 4줄(Combat·Loot·Progression), 조련사 PetService(SummonPet·AddPetXP·
  PetRoll, findSpecies는 소환 펫 제외), 장비 api/dev3-gear(gearAtk/gearHp/petGear/gearOf + GearRem 펫 XP 나머지) — 모두 검토 OK.
  보스 재료도 행운 물약에 오름(빼려면 `def.Source == nil`, 게임성 검수 결정 대기). WeekCap.Artisan 100(개발 3, OK).

## worktree·도구
- 가벼운 worktree: `git worktree add --no-checkout -b <가지> ../wt_<이름> origin/main` → `MSYS_NO_PATHCONV=1 git sparse-checkout set
  --no-cone /src/ /tools/ /docs/ /AGENTS.md` → `git read-tree -mu HEAD` → `cp -r ../Game/build/luau_cli_0_741 build/`.
  worktree 안에서 `git commit -m … -- <경로>`. 지금 내 worktree: wt_lesstext_server, wt_goose_square.
- 고치기: 스크래치에 python 정확 치환 스크립트(CRLF 맞춤: 파일에 \r\n 있으면 옛·새 글도 \r\n). heredoc 안 `\n` 주의.
- 전체 시험: 스크래치 run_all_tests.py `<worktree> <outdir> <동시 수> [시험 이름…]`(a23_14는 --no-mutations). **시험 도는 중엔 그
  worktree 파일을 고치지 말 것**(sourcesChangedDuringRun 실패). 커밋 전 `git checkout -- docs/art`.
- 원래 있던 실패: costume_physics·skin_binding(은퇴), halloween·shop_layout(그림 필요), place_english(place 필요), rank_marks,
  ops_safety 변이 "Halloween is not applied".
