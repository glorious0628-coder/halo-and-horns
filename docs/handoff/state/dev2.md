# 게임성 개발 2 — 상태 (2026-10-11 밤 늦게, PC 재시작 뒤 이어서)

서버 전용·Studio 금지·main에 코드 push 금지(검수가 병합). 큰 코드는 api_agent 쓰기 모드로 맡길 수 있음
(`py tools/api_agent.py run --prompt-file P.md --out build/api_agent/<job> --model opus|sonnet --max-usd 5 --max-turns 60~80
--make-worktree <ref> --write --branch api/<이름> [--allow-run-modified-py]`).
**보고처 = '게임성 검수'**(10/11 최종 검수 지시; id는 list_sessions). 최종 검수 = '최종 검수'(옛 모든 것 검수). 보고는 묶음마다 한 번.
대화가 길어지면 이 파일 적고 push → clear_session("self").

## push 끝 (게임성 검수에 보고함)
1. **fix/lesstext-server 6fc3ba52** (249a68a0 위) — MinGap 고침: 개발 1 PauseCard가 Chapter 카드만 띄우는데 서버가 Daily/War
   카드를 보내 120초 간격을 잡던 것. Config.Return.Cards = { Chapter = true, Daily = false, War = false }, queueCard가 꺼진 종류는
   안 보냄(Fx·MinGap·CardShown 없음), Daily 순간 알림 동의는 Fx OptInMoment { Why = "Daily" }. test_return 190·89/89.
2. **fix/spawnclear c54f4bfb + a86ca243** (5e524e70 위) — 검수 결정 1~6(docs/review/spawnclear_review_2026-10-11.md): 나무 = TrunkPost
   1개 + W_Tree_A/B/C 메시면 줄기 원판(Base)·캐노피(Canopy) 위 상자(Config.SpawnClear), 충돌 없는 꽃·디딤돌·폭포·불빛 안 막음
   (Pass/NotPass), 태그 붙은 바닥 파트만 빼고 다리·태그 모델은 안으로(난간 막음), SpawnEvent 고리 Radius+3/6/9, SpawnPersonal 4방향
   → 12방향 ×(거리, 1.5배), 마을 대체 자리 몸 검사, 필드 킹 Config.Spawn = KingSpawn 자리, 색인 = 맵 바뀔 때만 재빌드·0.002초 쉼·첫
   실패 빈 색인·Map 밖이면 안 바꿈, 프로브가 구역·종류별 빈 시도 비율·고리 실패율 출력, GroundAt(x, z, kind). 덤 커밋: test_skills·
   test_finisher 낡은 패턴. 시험 spawn_clear 628·62/62 외 16개 통과. 병합 뒤 메인 반영 1이 프로브 실행(실맵 기대: 숲 고블린 -32.6%).

## 지금 하는 일: 서버 글 판정표 큰 커밋 (fix/lesstext-server, worktree `C:/Users/glori/Documents/Roblox/wt_lesstext_server`)
- 로컬 HEAD = 7facf741 = 6fc3ba52 + origin/fix/lesstext(0325d628) merge 커밋(commit-tree로 만듦, 아직 push 안 함) + **커밋 안 한 고침**
  (Config 글 90곳·서비스 24파일 73곳 + 시험 고침). 판정표 `docs/review/server_text_verdicts_2026-10-11.md`.
- 판정이 둘로 갈린 줄은 이렇게 정함(보고에 적기): 강화·옮기기 결과 토스트 OFF(가방 창이 같은 글 표시, 소리는 Fx Enhance),
  DuplicateWeapon SHORT "%s again! +%s gold", PotionFull "No room for %s.", FirstWeaponBag "New weapon: [%s]!", WeaponAutoSwap
  "Needs Lv %d. Now using %s.", MostWanted "Most Wanted: %s · Bounty %s gold", BullyKO SHORT, BoldWeak SHORT, PlunderTooSoon
  "Too soon to rob them again.", Kaiju 패배 공지 OFF(셋째 판정), SwitchDoneFree SHORT "%s back to 0."(호출 lostScore만),
  UnderdogSignOn "Smaller side bonus: +%d gold!", BlockedBully "Not while you are a bully.", NoTicket "No change ticket.",
  TicketSaving "Still saving. Try again soon.", DailyChest SHORT, DailyAutoPaid "Daily rewards! +%s gold", TravelBlockedStars
  "Too many Wanted stars to teleport!", WeaponShopFar/SellFar "Too far from the Forge.", PotionShopFar "Too far from the Potion Seller.",
  Commission Done "%s equipped!"·NeedLevel "You need Lv %d.", Board Full "Max 3 jobs.", Diary Page OFF, OutlawEnd/BullyPenaltyEnd은
  자동 해제됐을 때만 "… over! Auto is back." (시험이 두 글 다르길 요구), Cheer Star는 보상 줄에 붙임.
- 소리 붙은 OFF 줄 = 빈 글 Notify(소리만): PotionBought(Spend), Attendance 마일스톤(RankUp), 상점 재장착(Equip), Diary 칭호(RankUp),
  왕관전 승리 = 이긴 진영만 글, 나머지는 소리만.
- 안 한 것(보고에 적기): OutlawStart+OutlawAutoOff 겹침, PvP 첫 카드와 'PvP zone!' 겹침 건너뛰기, 남의 무기 자랑 토스트(클라),
  EventHUD 사이렌 칩(클라), Tut.Text.Travel/Welcome(검수 판단), Halloween 왕 수다(꺼진 기능), 거위 GOOSE_LABEL은 Config로 옮김.
- 시험: 고친 것 = notify_sound·names_columns·a2390·attendance·board·choice_card·commission·english·field_boss·finisher·friend_pvp·
  return·grudge·keys_settings·loot·lost_found·ranking·tamer·town_quests·unarmed_start·weapon_first·water_rescue·a23_14·onboarding·
  potions. 마지막에 전체(변이 포함) 다시 돌림 → 실패 = 원래 것(place_english·shop_layout·rank_marks = sparse 폴더에 파일 없음,
  test_skills = 이 가지엔 옛 패턴, costume 2개 = RETIRED)만이면 커밋. **커밋 전 `git checkout -- docs/art`**(보고서 덮어씀).
- 커밋 뒤 push: `git push origin HEAD:fix/lesstext-server`(merge 커밋 포함 → 개발 1 가지도 같이 들어감, 검수가 둘 같이 병합).

## 그다음 큐
1. **황금 알 줍기** Goose.Mode="Eggs" — 설계 `docs/design/golden_egg_2026-10-11.md` + SPEC A23-131·134·137(4시간마다 30점 등 확인).
2. **저장 v4 표**(개발 3과 합의, `origin/dev3-v4-tables:docs/design/save_v4_tables_2026-10-11.md`).
3. `api/dev2-l10n-a` 필수 시험·보완 → 병합 요청. 제작 설계 `api/dev2-crafting-design` ea0ce9bc 정리(A23-127).
4. 한국어 서버 B·C(알림 → NotifyKey 등).
- 참고: Smokey 새 이름 = 'Rose'(A23-138) — 서버 글에 Smokey가 나오면 같이 바꿀 것.

## worktree·도구
- 가벼운 worktree: `git worktree add --no-checkout -b <가지> ../wt_<이름> origin/main` → `MSYS_NO_PATHCONV=1 git sparse-checkout set
  --no-cone /src/ /tools/ /docs/ /AGENTS.md` → `git read-tree -mu HEAD` → `cp -r ../Game/build/luau_cli_0_741 build/`.
  worktree 안에서 `git commit -m … -- <경로>`. 지금 worktree: wt_lesstext_server, wt_spawnclear, wt_mingap(6fc3ba52, 지워도 됨).
- 고치기 스크립트: Write로 `(경로, 옛 글, 새 글, 개수)` 목록 파일을 만들고 정확 치환(Bash 안에서 `\n`·`\\n`이 바뀜 → Bash heredoc 금지).
- 시험 병렬: 스크래치 run_tests.py(10개씩, --mut). test_a23_14 변이 약 40분. luau 문법 = build/luau_cli_0_741/luau-compile.exe.
- 원래 있던 실패: halloween 'pattern 0회'(GLB 필요), ops_safety 변이 "Halloween is not applied".
