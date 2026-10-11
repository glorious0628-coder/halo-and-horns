# 게임성 검수 상태 (2026-10-12 새벽)

역할: `role_prompts/14_gameplay_review.md`. 시험 폴더(sparse): `C:/Users/glori/Documents/Roblox/Game-gprev`, `Game-gprev2`, `Game-gprev3` (src·tools·docs + build/luau_cli_0_741; 시험이 보고 json을 고치므로 바꿀 땐 `git checkout -f --detach`). 시험 병합 = `git merge-tree --write-tree origin/main <가지>` → `git commit-tree`. 다른 세션 메시지가 막히면(10개 제한) 여기 적기.
**개발 세션에 부탁함:** '병합 가능'으로 보고한 끝 커밋은 다시 쓰지 말고 위에 쌓기(개발 4 동의).

## main에 병합됨 (최종 검수)
onehand 33272a46, golden-egg 3d95925a, v4-tables, lesstext 0325d628 + lesstext-server 6fc3ba52, onehand-2 0dc6c46d, dev4-bag 597e5faf, dev3-gather 520e8cb7, dev3-craft 22cda7d5 (main d688f360).

## "병합 가능" 올림, 병합 대기
- fix/spawnclear **358867c7** (실측 scratch spawn2/rv2_measure.py: 숲 고블린 −32.0%, 브루트 −36.0%, 킹 모두 막힘 11.5% → 4.1%; main test_english 낡은 변이도 고침).
- fix/golden-egg-client **eebeebd3** (알 팝·소리 두 번 고침).
- dev3-craft **b868d6ce** (켜기 전 고칠 것 반영; 켜는 조건 = 채집: SellItem/거래소, 제작: 개발 2 AddSpare/SpareRoom + 보스 재료 Source "Boss").
- fix/reward-chip **a5de2b9f** (IconCoin + "+150", 칩 넓힘).
- fix/bag-2 **4e6d3f6f** → dev4-gather **bb2cdbfe** (순서대로).

## 고쳐서 다시
- dev4-craft 3f94f2f5: keys_settings STATIC_FAILURE(CraftView Space·ButtonA 직접 묶음, BB1) → 개발 4. 나머지 6개 통과.
- 개발 1(낮음): 지팡이 끝 사용자 아바타에서 0.26~0.27칸 뜸(목표 0.08), 강화 결과 칩 "…+1 (attack…" 잘림.
- 대장장이 G 대화 미확인(메인 반영 1 smith log) → 최종 검수가 메인 반영 1에 다시 확인 부탁.

## 결정
- 한 번에 팔기 = 몬스터 재료만(Source 있는 채집 "Gather"·보스 "Boss" 제외, SellItem은 Source 상관없이). 화면 합계도 같은 규칙(fix/bag-2).
- 2배 XP 패스 글: 제작 켜는 가지에서 "Get 2x level XP, so you level up 2x faster. Crafting levels do not change. No stats are for sale."
- 망치질: 두드림마다 CraftStrike(Id, i, ms), 공용 Shared/CraftMini(서버·화면 같은 파일), Finish(Id)만, Skip = +0, 나가기·20초 = +0, 핑 = 큰 값; 베타는 CraftMini 창 그대로 + CraftStrikeD 지표로 10/17~20 뒤 조정.
- 제작 서버: 레시피 시작값, 펫 장비 = 조련사, 무기는 AddSpare 뒤.

## 원래 있던 문제
- test_ops_safety 할로윈 변이 1개(병합 기준 아님). test_english 낡은 변이 → spawnclear 358867c7이 고침.
