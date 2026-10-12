# 게임성 개발 2 — 상태 (2026-10-12 오후)

서버 전용·Studio 금지·main에 코드 push 금지(검수가 병합). **보고처 = '게임성 검수'**(id는 list_sessions). 최종 검수 = '최종 검수'.
보고는 묶음마다 한 번. 대화가 길어지면 이 파일 적고 push → clear_session("self").
- **API(api_agent) 거의 바닥(10/12 남은 약 $22, 최종 검수: 최종 병합 검토용으로 남김) → 큰 일도 앱에서 직접.** 충전되면 최종 검수가 알림.
  도구 버그 고침: edit_file이 파일 전체 크기를 쓰기 한도에 세던 것 → main 476362b(새 글만 셈).

## 보고함 / 검토 대기 (보고한 가지 = 다시 쌓지 말고 위에 커밋만; main 합치기는 충돌 때만)
- **fix/lesstext-server 8c8dc44d** — 강화 결과 토스트 5개 되살림, 보스 등장 구역 이름, 출석 이정표 줄(중립 14일 'N days collected!').
  그 아래 1f42e88f(무법자 주 시작 1줄)·6adf2c82(A23-130 서버 글 판정표).
- **C1 = api/dev2-c1-t9-v4 435999d0** — 9단계 Mythic(2200/Lv50/Crownforged, 길이 6.2), Version 4(v1/v2 단계 8 고정, v3의 9비트 = 손상),
  Spares·Market sanitize, LootService.SpareRoom/AddSpare(키 20·합 60), KingJelly 20%·ClatterGem 10%(Source Boss). 구슬 8단계에서 멈춤.
  main 합친 뒤 전체 172개: 원래 실패만 + skeleton_ground·studio_guard(이 가지가 안 건드린 worldkit, main이 더 바뀜).
- **황금 알 1차 = api/dev2-golden-egg 3dfdc791** (Config·GooseEggs·GooseService) — 1차만으론 덜 됨, 아래 거위 광장과 같이 병합 권함.

## 진행 중 — 거위 광장 (A23-141) = 가지 **dev2-goose-square** (worktree ../wt_goose_square, 3dfdc791 위)
- 이름: 개발 1 계약 `docs/design/goose_square_contract_2026-10-12.md` 그대로 — 원격 `GooseSquare("Join"|"Leave")`, 속성
  `InGooseSquare`·`GooseJoinBlock`, Join은 GooseActive만, 어두워짐은 화면. `Config.Goose.Square`(Remote·Attr·Block·Fade·Text) = **개발 1
  가지에서만 정의**, 서버는 `or` 기본값으로 읽기만. 서버 숫자 = `Config.Goose.SquareSpace`. 공간 = 이미지 개발 골격
  `docs/design/goose_square_skeleton_2026-10-12.md`(workspace.GooseSquare Model, GooseSpot·Nest·Cart·SpawnHalo·SpawnHorns, 속성 <이름>Pos,
  Floor = 범위, 중심 (6000,200,6000)); 없으면 서버가 대역(바닥·벽·표시) 한 번 만듦.
- 코드 끝(커밋 전): GooseSquare.luau(새), GooseEggs GEO(SetGeometry·Members·광장 안 = 링 안), GooseService(require·start 전 기하·끝 4초 뒤
  ReturnAll·tick·Init 나감/죽음/진영·Start 원격·LeaveSquare), Net "GooseSquare", Config SquareSpace·InGooseSquare·RateLimits·
  Landmarks.GooseNest, CombatService(LastPvPAt·거위 공격은 Tug만), PvPService(광장 = SafeZone), ZoneService teleport → LeaveSquare,
  PlayerService ComputeWalkSpeed 맨 위 EggPlaza 조기 반환, SkillService Hop TooHeavy, CharacterVisuals EggStack(등 바구니·Motor6D EggJoint),
  MapBuilder 횃대 Tug만, StoryQuest 첫 +1 Tug만, HealthService Joins 등. 새 test_goose_square(77 + 정적 22, 변이 43).
- 다음: 전체 시험 → origin/main 합치기 → 문서(스크래치 square_contract_s6.md → 광장 계약 §6, egg_contract_s9.md → 알 계약 §9 답) →
  커밋·push(origin dev2-goose-square) → 게임성 검수에 보고(1차 3dfdc791 + 이 가지 함께).

## 다음 큐
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
