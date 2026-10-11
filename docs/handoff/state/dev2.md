# 게임성 개발 2 — 상태 (2026-10-12 아침)

서버 전용·Studio 금지·main에 코드 push 금지(검수가 병합). 큰 코드는 api_agent 쓰기 모드로 맡길 수 있음
(`py tools/api_agent.py run --prompt-file P.md --out build/api_agent/<job> --model opus|sonnet --max-usd 5 --max-turns 60~80
--make-worktree <ref> --write --branch api/<이름> [--allow-run-modified-py]`).
**보고처 = '게임성 검수'**(id는 list_sessions). 최종 검수 = '최종 검수'. 보고는 묶음마다 한 번. 대화가 길어지면 이 파일 적고 push → clear_session("self").

## 병합됨 / 검토 대기
- main에 들어감: fix/lesstext-server 6fc3ba52(MinGap), fix/spawnclear 358867c7(main 96ec45ad), fix/spawnclear-rim 0a1e3e75.
- **검토 대기: fix/lesstext-server 1f42e88f** (보고한 가지 = 다시 쌓지 말고 위에 커밋만) — 6adf2c82 위에 무법자 주 시작 2줄 → 1줄
  (게임성 검수 10/12 결정: RankingService.OutlawToldAt, CombatService가 10초 안이면 OutlawAutoOff 건너뜀; ranking 487·187/187).
  6adf2c82까지 = 서버 글 판정표(A23-130 §2) 본 커밋 becb9cc9 + main 두 번 합침 + 시험 고침
  (test_town_quests 'Pick' 정규식 = main에서도 실패하던 것, test_enhance_lines·test_gather 변이). 판정 갈린 줄 결정·안 한 것 목록은
  게임성 검수에 보낸 보고 그대로(첫 PvP 카드 겹침, 남의 무기 자랑 토스트(클라), 사이렌 칩(클라),
  Tut.Text.Travel/Welcome 경계선, 할로윈 왕 수다). 전체 오프라인: 실패 = 파일 없는 3개(place_english·shop_layout·rank_marks)뿐.

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

## worktree·도구
- 가벼운 worktree: `git worktree add --no-checkout -b <가지> ../wt_<이름> origin/main` → `MSYS_NO_PATHCONV=1 git sparse-checkout set
  --no-cone /src/ /tools/ /docs/ /AGENTS.md` → `git read-tree -mu HEAD` → `cp -r ../Game/build/luau_cli_0_741 build/`.
  worktree 안에서 `git commit -m … -- <경로>`. 지금 worktree: wt_lesstext_server, wt_spawnclear, wt_rim, wt_mingap(지워도 됨).
- 고치기: Write로 `(경로, 옛 글, 새 글, 개수)` 목록 파일 → 정확 치환(Bash heredoc 안 `\n`·`\\n`이 바뀜 → 금지).
- 시험 병렬 러너(스크래치 run_tests.py, 10개씩, --mut). test_a23_14 변이 약 40분(10개 동시면 변이 하나가 600초 초과로 실패할 수 있음 →
  혼자 다시). luau 문법 = build/luau_cli_0_741/luau-compile.exe. 커밋 전 `git checkout -- docs/art`(보고서 덮어씀).
- 원래 있던 실패: halloween 'pattern 0회'(GLB 필요), ops_safety 변이 "Halloween is not applied", sparse 폴더의 place_english·
  shop_layout·rank_marks(파일 없음).
