# 게임성 검수 상태 (2026-10-11 밤 늦게)

역할: `role_prompts/14_gameplay_review.md`. 시험 폴더(sparse): `C:/Users/glori/Documents/Roblox/Game-gprev`, `Game-gprev2`, `Game-gprev3` (src·tools·docs + build/luau_cli_0_741; 시험이 보고 json을 고치므로 바꿀 땐 `git checkout -f --detach`). 시험 병합 = `git merge-tree --write-tree origin/main <가지>` → `git commit-tree`. 다른 세션 메시지는 막힐 때가 있음(10개 제한) → 못 보낸 것은 여기 적기.

## main에 병합됨
fix/onehand 33272a46, golden-egg 3d95925a, dev3-v4-tables e5c8bb08, fix/lesstext 0325d628, fix/lesstext-server 6fc3ba52 (main 3176b8fb). 묶음 ① a23_14 변이판 99/99 통과(병합 뒤 확인).

## "병합 가능"으로 올리고 최종 검수가 병합할 차례인 것
- fix/onehand-2 **0dc6c46d** (자세 + 뿔 마법사/궁수 허리 −8/−12; 사진: 빛|뿔 전사 앞·3/4·옆, 뿔 마법사·궁수 옆, 사용자 아바타 지팡이 발끝, 대장장이 Q, 연금술사 팔).
- dev4-bag **597e5faf** (새 main 위, ORDER 고침, bag_ui·egg_fx 통과). 그 위 dev4-gather 9e42277c, dev4-craft 6ecc3197(아직 시험 전).
- dev3-gather 520e8cb7 (꺼짐). 켜기 전 고칠 것 5개 개발 3에 보냄.

## 고쳐서 다시 / 기다림
- fix/spawnclear a86ca243: 시험 14개 + 실측 OK(scratch spawn2/rv2_measure.py: 숲 고블린 −32.0%, 브루트 −36.0%, 킹 모두 막힘 11.5% → 4.1%), **main과 Config 끝 충돌** → 개발 2가 main 다시 받기 → compile + spawn_clear·first_ko_king·save_v4_tables 보고 병합 가능.
- dev3-craft 22cda7d5 (꺼짐, CraftMini 개발 4와 같은 파일): 시험 7개 통과, API 반박 리뷰 build/api_agent/gprev_craft_review_1 진행 중 → 결과 보고 병합 가능 판단. TolMs = 베타는 CraftMini 창 그대로 + 어긋남 지표(내 결정, 개발 3에 보냄).
- dev4-gather·dev4-craft: dev4-bag 병합 뒤 순서대로 시험.
- 개발 1: Eggs 모드 켜기 전 알 팝·소리 두 번 고침(보냄).
- lesstext-server '서버 글 판정표' 큰 커밋(개발 2) — 오면 따로.

## 전달 확인 필요
- 개발 4 (전달 안 됐을 수 있음 eb6349d2): 재료 팔기 합계 골드·개수 = `Kind == "Material" and Source == nil`만(Panels 2240·2727-2733), 팔 것 없으면 버튼 끔, 가방 판매가 줄은 Source 물건이면 숨김.
- 개발 2: main test_english 낡은 변이(twins drift apart, ClaimedEn 지워짐) 고치기 — main에서 실패 확인. 보스 재료 KingJelly·ClatterGem = Source "Boss"(결정).
- 개발 1: 받기 칩 "★ +150..." 잘림(merge_a23130/06_claim_*) → 칩 폭 또는 IconCoin + 숫자.
- 최종 검수: golden-egg eebeebd3 병합 가능(egg_fx 53·27/27, audio), main test_english 실패(개발 2 몫), dev3-craft b868d6ce 시험 결과.

## 결정
- 보스 재료(KingJelly·ClatterGem) = Source "Boss" → 한 번에 팔기에서 빠짐(개발 2 C1/C2).
- 한 번에 팔기 = 몬스터 재료만(채집·제작 재료는 SellItem으로). 2배 XP 패스 글은 제작 켜는 가지에서("Get 2x level XP, so you level up 2x faster. Crafting levels do not change. No stats are for sale.").
- 망치질: 두드림마다 CraftStrike(Id, i, ms), 공용 Shared/CraftMini 하나, Finish(Id)만, Skip = +0, 나가기·20초 = +0 저장, 핑 = 시작·두드림·지금 중 큰 값.
- 제작 서버: 레시피 시작값 OK, 펫 장비 = 조련사, 무기는 개발 2 AddSpare 뒤.

## 원래 있던 문제
- test_ops_safety 할로윈 변이 1개(병합 기준 아님). test_skills·finisher 낡은 패턴 → spawnclear a86ca243이 고침.
