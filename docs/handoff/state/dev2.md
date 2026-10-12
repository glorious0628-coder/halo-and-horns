# 게임성 개발 2 — 상태 (2026-10-12 아침)

서버 전용·Studio 금지·main에 코드 push 금지(검수가 병합). 큰 코드는 api_agent 쓰기 모드로 맡길 수 있음
(`py tools/api_agent.py run --prompt-file P.md --out build/api_agent/<job> --model opus|sonnet --max-usd 5 --max-turns 60~80
--make-worktree <ref> --write --branch api/<이름> [--allow-run-modified-py]`).
**보고처 = '게임성 검수'**(id는 list_sessions). 최종 검수 = '최종 검수'. 보고는 묶음마다 한 번. 대화가 길어지면 이 파일 적고 push → clear_session("self").

## 병합됨 / 검토 대기
- main에 들어감: fix/lesstext-server 6fc3ba52(MinGap), fix/spawnclear 358867c7(main 96ec45ad), fix/spawnclear-rim 0a1e3e75.
- **검토 대기: fix/lesstext-server 8c8dc44d** (10/12 게임성 검수 되돌림 고침: 강화 결과 토스트 5개 되살림(Bag 창은 결과 줄 없음,
  A23-99), 보스 등장 줄에 구역 이름, 출석 이정표 팡파르는 첫 보상 줄에·보상 줄 없으면(중립 14일) 'N days collected!'.
  보고함.) 1f42e88f까지: (보고한 가지 = 다시 쌓지 말고 위에 커밋만) — 6adf2c82 위에 무법자 주 시작 2줄 → 1줄
  (게임성 검수 10/12 결정: RankingService.OutlawToldAt, CombatService가 10초 안이면 OutlawAutoOff 건너뜀; ranking 487·187/187).
  6adf2c82까지 = 서버 글 판정표(A23-130 §2) 본 커밋 becb9cc9 + main 두 번 합침 + 시험 고침
  (test_town_quests 'Pick' 정규식 = main에서도 실패하던 것, test_enhance_lines·test_gather 변이). 판정 갈린 줄 결정·안 한 것 목록은
  게임성 검수에 보낸 보고 그대로(첫 PvP 카드 겹침, 남의 무기 자랑 토스트(클라), 사이렌 칩(클라),
  Tut.Text.Travel/Welcome 경계선, 할로윈 왕 수다). 전체 오프라인: 실패 = 파일 없는 3개(place_english·shop_layout·rank_marks)뿐.

## 진행 중
- **C1 API job** 가지 api/dev2-c1-t9-v4: 첫 job `dev2_c1_t9_v4`($2.6)는 api_agent 버그(edit_file이 파일 전체 크기를 쓰기 한도에 셈
  → Config 13번 고치면 멈춤)로 Config만 미완성 커밋 ab5b9777. 버그는 main 476362b로 고침(새 글만 셈, test_api_agent 314).
  이어서 `dev2_c1b_t9_v4`(Opus $10·130턴, --make-worktree origin/api/dev2-c1-t9-v4, 프롬프트 c1b_prompt.md = 남은 1~4 + 원래
  c1_prompt.md: Sanitize Spares/Market, DataService <4 + v1/v2 단계는 8 고정, LootService.SpareRoom/AddSpare, test_weapon_ladder +
  Version 3·8단계 가정 시험들). 끝나면: `.py` diff 먼저 읽기 → 임시 worktree에서 시험 → 게임성 검수에 해시.
- 거래소 창 계약 합의(개발 4, origin/dev4-market 9d8a679f `docs/design/market_window_2026-10-12.md` §6): MarketIndex 30초 캐시
  (요약 SortedMap 하나)·힌트, 무기 키 "T:P", MarketPage.Pages, MarketMine Paid·Today, 응답에 Gate = { Buy, List, ListIn }(관문은
  서버만), 거래소 퀘스트 3개 = 내 거래소 가지, 거절 키 + TooFast·Off. 모양 바꾸면 그 문서에 적기.
- 장비 칸(개발 3 api/dev3-gear): 내 파일 줄은 개발 3이 해시와 함께 보냄 → 그 줄만 검토.
- 버그 알림: 개발 3(dev3_gear)·개발 4(dev4_tonics)·최종 검수(house-gen-porch 주인에게)에 보냄 — 옛 한도로 돈 job은 멈출 수 있음.
- **황금 알 API job `dev2_golden_egg`** (10/12, 가지 api/dev2-golden-egg, Opus $18·170턴, 프롬프트 = 스크래치 egg_prompt.md:
  약속 문서 그대로 + 개발 1 가지 origin/fix/golden-egg-client에 맞춤, A23-134 네 개 모두 켬, A23-137 4시간·+30, 중립 = 바로 가방
  GoldenEgg·1등 +50%, 깃털 Kind Feather → GooseFeather(Fx 없음), 'Bring 2 eggs' Notify, 명예 +5 한 시간 한 번(첫 +1 대신),
  속도 = ComputeWalkSpeed 맨 위 조기 반환(EggPlaza), Tug 코드 남김). §9 답은 개발 1에 보냄. 끝나면 C1처럼 검토.
- 게임성 검수 10/12: 큰 코드·큰 시험 고침은 api_agent 쓰기 모드 먼저(남은 API 약 $85, 한 일당 한도).

## 다음 큐
1. **황금 알 줍기** Goose.Mode="Eggs" — 설계 `docs/design/golden_egg_2026-10-11.md` + SPEC A23-131·134·137(4시간마다 30점 등).
   (개발 1이 egg 화면 가지를 진행 중 — 계약 맞추기.)
2. **저장 v4 C1/C2**(`docs/design/save_v4_tables_2026-10-11.md`, main에 표 들어감): Version 4(T9 마스크·WeaponEnhance[9]·Spares·
   Market sanitize). 개발 3 부탁(`origin/dev3-craft:docs/design/craft_server_2026-10-12.md` §6): `LootService.AddSpare(player, tier,
   plus) -> bool`(Spares["T:P"] += 1, 키 20·합 60 넘으면 false), `LootService.SpareRoom(player, tier, plus) -> bool`; 새 재료
   `KingJelly`(King Slime)·`ClatterGem`(Captain Clatter)를 Config.Loot.Items에 **Source = "Boss"**로(게임성 검수 결정: 한 번에 팔기에서
   빠짐, SellItem은 Source 상관없이) + test_loot 시험 1·변이 1. 골드 이유 "Craft"는 등록 필요 없음.
3. `api/dev2-l10n-a` 필수 시험·보완 → 병합 요청. 제작 설계 `api/dev2-crafting-design` ea0ce9bc 정리(A23-127).
4. 한국어 서버 B·C(알림 → NotifyKey 등).
5. **A23-138 영어 밈 묶음 서버 쪽** = 새 가지 fix/meme-en-server(급한 병합들 뒤): `docs/design/memes_en_2026-10-11.md` 서버 글,
   칭호 'Legendary Villain' → 'Final Boss'(Config.Story.SurviveTitle), 박쥐 기술 'Flappy Zigzag' → 'Bat Zigzag', NPC 'Smokey' → 'Rose'
   (대사·Speakers·'Bright & Smokey' 등; 초상화 키 PTR_TownSmokey는 그림 쪽과 맞춰서). 개발 1은 fix/meme-en-client.
- 알아 둘 것: 한 번에 팔기 = 몬스터 재료만(개발 3이 dev3-gather fec0cc68에 `def.Source ~= nil` 건너뛰기로 넣음, main에 있음).
  화면의 팔기 합계 골드는 개발 4 몫.
- 개발 3 연금 물약 ④(origin/dev3-alchemy 09a149d0, 시험 중)가 내 파일에 BuffService.Mult 줄 4개: CombatService.damageMonster 맨 앞
  (MonsterDamage)·DamagePlayer SKL-3 가드 뒤(MonsterHurt), LootService.RollKill info.MatMult + rollRows 재료 줄만, ProgressionService
  처치 XP 뒤(HuntXP). 그 옆을 고치면 개발 3에 먼저 알리기. KingJelly·ClatterGem(Source "Boss")도 행운 물약에 오름 → 빼려면
  `def.Source == nil` 조건(게임성 검수 결정 대기, 개발 3에 알림).
- 개발 3 ⑤ 조련사(dev3-tamer, 설계 docs/design/tamer_server_2026-10-12.md §4): 개발 3이 PetService.SummonPet·AddPetXP·속성 PetRoll·
  PetSpeedBonus(species, lv, roll)·PetList Roll을 넣고 **내가 읽어 확인**(10/12 합의: grant 새 줄 부분 공유, 64개는 넣기 전에 거절,
  roll은 sanitizeRoll, +3%는 Config). 해시 오면 바로 검토.

## worktree·도구
- 가벼운 worktree: `git worktree add --no-checkout -b <가지> ../wt_<이름> origin/main` → `MSYS_NO_PATHCONV=1 git sparse-checkout set
  --no-cone /src/ /tools/ /docs/ /AGENTS.md` → `git read-tree -mu HEAD` → `cp -r ../Game/build/luau_cli_0_741 build/`.
  worktree 안에서 `git commit -m … -- <경로>`. 지금 worktree: wt_lesstext_server, wt_spawnclear, wt_rim, wt_mingap(지워도 됨).
- 고치기: Write로 `(경로, 옛 글, 새 글, 개수)` 목록 파일 → 정확 치환(Bash heredoc 안 `\n`·`\\n`이 바뀜 → 금지).
- 시험 병렬 러너(스크래치 run_tests.py, 10개씩, --mut). test_a23_14 변이 약 40분(10개 동시면 변이 하나가 600초 초과로 실패할 수 있음 →
  혼자 다시). luau 문법 = build/luau_cli_0_741/luau-compile.exe. 커밋 전 `git checkout -- docs/art`(보고서 덮어씀).
- 원래 있던 실패: halloween 'pattern 0회'(GLB 필요), ops_safety 변이 "Halloween is not applied", sparse 폴더의 place_english·
  shop_layout·rank_marks(파일 없음).
