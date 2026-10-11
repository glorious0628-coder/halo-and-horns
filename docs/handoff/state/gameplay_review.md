# 게임성 검수 상태 (2026-10-12 아침)

역할: `role_prompts/14_gameplay_review.md`. 시험 폴더(sparse): `C:/Users/glori/Documents/Roblox/Game-gprev`, `Game-gprev2`, `Game-gprev3` (src·tools·docs + build/luau_cli_0_741; 시험이 보고 json을 고치므로 바꿀 땐 `git checkout -f --detach`). 시험 병합 = `git merge-tree --write-tree origin/main <가지>` → `git commit-tree`. 다른 세션 메시지가 막히면(10개 제한) 여기 적기.
개발 세션에 부탁함: '병합 가능'으로 보고한 끝 커밋은 다시 쓰지 말고 위에 쌓기.

## main에 병합됨 (main 96ec45ad까지, 최종 검수)
onehand·onehand-2, golden-egg(3d95925a·eebeebd3), v4-tables, lesstext + lesstext-server, dev4-bag + fix/bag-2, dev3-gather, dev3-craft b868d6ce, spawnclear 358867c7, reward-chip, dev4-gather bb2cdbfe, dev4-craft 5d4fc6f3, photo-1012 40159fe9. 낡은 시험(skills·english·finisher) 풀림.

## 지금 기다리는 것 (아직 안 옴)
- 개발 1: Eggs 켜기 전 알 낮은 것 2개(Near에 최근 위치, MineAt은 미리보기 없을 때만) — 보냄.
- 개발 2: Config.SpawnClear.Pass "Puddle"이 Kit_M_PuddleRim 안에 슬라임 생기게 함("Puddle" 빼기 또는 NotPass "Rim") — 최종 검수가 보냄. lesstext-server '서버 글 판정표' 큰 커밋. C1(AddSpare/SpareRoom, 저장 v4, 보스 재료 Source "Boss").
- 개발 3: ④ 연금 버프 물약. 개발 4: ③-3 제작 창.
- 메인 반영 1 사진: spawn_clear_probe 실측 비교, 지팡이 끝 tip-foot(0.05~0.15), 강화 결과 줄, 받기 칩 동전, 대장장이 G 대화(3~4칸).

## 결정
- 한 번에 팔기 = 몬스터 재료만(Source 있는 채집 "Gather"·보스 "Boss" 제외, SellItem은 Source 상관없이). 화면 합계도 같은 규칙.
- 2배 XP 패스 글: 제작 켜는 가지에서 "Get 2x level XP, so you level up 2x faster. Crafting levels do not change. No stats are for sale."
- 망치질: 두드림마다 CraftStrike(Id, i, ms), 공용 Shared/CraftMini, Finish(Id)만, Skip = +0, 나가기·20초 = +0, 핑 = 큰 값; 베타는 CraftMini 창 그대로 + CraftStrikeD 지표로 10/17~20 뒤 조정. 두드림 키 = 점프 요청(고리 열린 동안 점프 끔).
- 제작 서버: 레시피 시작값, 펫 장비 = 조련사, 무기는 AddSpare 뒤. 켜는 조건: 채집 = SellItem/거래소, 제작 = AddSpare/SpareRoom.

## 원래 있던 문제
- test_ops_safety 할로윈 변이 1개(병합 기준 아님).
