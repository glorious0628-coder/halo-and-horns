# 게임성 개발 2 — 상태 (2026-10-13 오후)

## 지금 (사용자 새 지시: "자잘한 디자인은 나중, 지금은 빛 마을에 집중")
- **빛 마을 6단계 준비 — 서버·Config 쪽 = 가지 dev2-halo-stage6 (worktree ../wt_halo6, origin/main d2477aac 위). 6단계 때 병합(지금은 병합 안 함).**
  근거 `docs/design/halo_fixed_points_v2_2026-10-11.md` 표 B·C·F + `halo_restart_2026-10-11.md`. 값은 `py -X utf8 tools/halo_fixed_points.py`로
  다시 뽑음 = 커밋된 표와 같음. WorldKit 저장 파일 읽기(Studio 안 엶, 스크래치 wk_positions.py)로 놓인 표시(NPC·영웅상·훈련장·스폰·발판) = 표 B와 같음,
  가게 건물 pivot = plan의 skeleton.origin(표 E의 x,z는 다른 기준점이라 몇 칸 달라 보일 뿐).
  바꾼 것: Zones.HaloTown Center (-2.5,0,-596.5) Size (615,0,533) · IslandHalo -310..305 / -863..-330 · **Map.Bounds MinX -330 MinZ -883**(표는 -320/-873;
  지도 규칙 '땅~경계 바다 20칸' 때문에 10 더) · Outskirts Center (755,0,-81.5) Size (2170,0,1603) · TownNpcs Gleam/PotionHalo/Folk1~4(표 B, Y = 마당 높이)
  · Landmarks.HeroStatue (-34,0,-388) · 새 Landmarks.TrainingYard (-130,2,-446)(퀘스트는 아직 안 가리킴) · Audio Waterfall.Spots 3곳.
  시험 고침: audio(폭포 3), map_v2(배치표 json HaloTown + tools/preview_map.lua), spawn_look(마을 가운데 = 새 구역 중심), town_npcs(v2 plan 문 기준 + v2 땅 높이),
  town_quests(영웅상 변이), water_rescue(새 상자). **map_v2 '큰 지도 그림이 Bounds를 덮음' 2개는 새 큰 지도 그림(표 D, 이미지 생성 2 + 변환값)이 나와야 풀림.**
  전체 시험 하나씩 도는 중 → 끝나면 고치고 커밋·push → 최종 검수 보고(표와 다른 것: Bounds 10칸, 상인 4명이 문 옆 벽에서 1.5칸 — Play 사진에서 계단 위인지 확인).
  미니맵 띠 RoadNorthIsland·큰 지도·오프닝·FountainFx·ZoneLook = 개발 1 몫.
- **거래소 서버(C-5/C-7) = dev2-market d9e0abc2 (push함, 멈춤).** 48d7e252 + main 병합(C2 포함). MarketService(장부 DataStore + MemoryStore 목록 + 사기·판 돈·
  취소·72시간·접속 확인) + LootService TakeSpare/GrantMarketWeapon/Pack/Unpack + 거래소 퀘스트 MK1~3(Requires.Feature) + Config.Market(스위치 꺼짐).
  설계 `docs/design/market_server_2026-10-13.md`. test_market 161 + 정적 14, 변이 72/72(합친 판 161 통과). **전체 시험은 6개만 돌고 멈춤** → 다시 시작할 때
  전체 시험 하나씩 → 보고. 화면 쪽 알릴 것: 값 = 1개 값(창의 "You get"·[Buy] 금액은 N 곱하기).
- 끝난 것(main): 도감 카드 서버 dev2-codex 3481c431(main 0aa6a0b7), 도감 카드 모델 fix/codex-models 2961fe9c(main cd047ef7),
  **C2 dev2-c2 91ea03e9(main 56c19428)** — 일반 몬스터 무기 줄 BelowLevel 함정 고침(그 무기 레벨 아래면 처치마다 확정으로 재료를 줌 → 보스 줄만).

서버 전용·Studio 금지·main에 코드 push 금지(검수가 병합). **보고처 = '최종 검수'**(id는 list_sessions). 보고는 묶음마다 한 번.
시험은 한 번에 하나씩(PC 렉), 서브에이전트·워크플로 쓰지 않음(최종 검수 10/13). 대화가 길어지면 이 파일 적고 push → clear_session("self").
- API(api_agent) 거의 바닥(남은 것은 최종 검수의 최종 병합 검토용) → 큰 일도 앱에서 직접.
- 전체 시험 기준(main): 182개 중 원래 실패 9개 = costume_physics·skin_binding(은퇴), halloween·shop_layout(그림 필요), place_english(place 필요),
  rank_marks, ops_safety 변이 "Halloween is not applied", skeleton_ground(build/wk 파일 없음), studio_guard 변이 "only GoodEvil is main". api_agent·claude_doc_worker 건너뜀.
- 지우지 못한 worktree(병합 끝; 자동 모드 분류기가 `git worktree remove` 막음, 그냥 둠): ../wt_goose_square, ../wt_stickers, ../wt_lesstext_server,
  ../wt_c1, ../wt_famecap, ../wt_codex, ../wt_codexmodels, ../wt_c2, ../wt_base(main 기준 시험용).

## 다음 큐 (빛 마을 뒤, 최종 검수가 부르면)
1. 거래소 서버 마무리(위).
2. `api/dev2-l10n-a` 정리(한국어 모드 취소 A23-146 → 필요한 것만), 제작 설계 `api/dev2-crafting-design` ea0ce9bc 정리(A23-127).
3. A23-138 영어 밈 서버 쪽(fix/meme-en-server).
- 알아 둘 것: 개발 3이 내 파일에 넣은 줄 — 연금 물약 BuffService.Mult 4줄(Combat·Loot·Progression), 조련사 PetService(SummonPet·AddPetXP·
  PetRoll, findSpecies는 소환 펫 제외), 장비 api/dev3-gear — 모두 검토 OK. 보스 재료도 행운 물약에 오름(빼려면 `def.Source == nil`, 결정 대기).

## worktree·도구
- 가벼운 worktree: `git worktree add --no-checkout -b <가지> ../wt_<이름> origin/main` → `MSYS_NO_PATHCONV=1 git sparse-checkout set
  --no-cone /src/ /tools/ /docs/ /AGENTS.md` → `git read-tree -mu HEAD` → `cp -r ../Game/build/luau_cli_0_741 build/`.
  worktree 안에서 `git add <새 파일>` + `git commit -m … -- <경로>`(docs/art 시험 출력은 빼고, 내 새 보고서만).
- 고치기: Write 도구로 스크래치에 python 정확 치환 스크립트(Bash heredoc은 `\\t`·작은따옴표를 망칠 수 있음). Python write_text는 CRLF로 씀 →
  git이 LF로 맞춰 줌(경고만). 시험 줄 상세에 플레이어 객체를 show()하면 스택 넘침.
- 전체 시험: 스크래치에 run_all_tests.py(`<worktree> <outdir> [시험 이름…]`, 하나씩, a23_14는 --no-mutations) — 스크래치는 세션마다
  지워지니 다시 만들 것(tools/test_*.py 차례로 `py tools/<t>` 실행, rc·로그 저장). **시험 도는 중엔 그 worktree 파일을 고치지 말 것**.
- 일반 몬스터 드롭 줄에 BelowLevel 쓰지 말 것(LootService.rollRows는 뽑기 없이 처치마다 줌).
