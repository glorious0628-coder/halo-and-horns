# 게임성 검수 상태 (2026-10-11 밤)

역할: `role_prompts/14_gameplay_review.md`. 시험 폴더(sparse): `C:/Users/glori/Documents/Roblox/Game-gprev`, `Game-gprev2`, `Game-gprev3` (src·tools·docs + build/luau_cli_0_741; 시험이 보고 json을 고치므로 바꿀 땐 `git checkout -f --detach`). 시험 병합 = `git merge-tree --write-tree origin/main <가지>` → `git commit-tree`.

## 최종 검수에 "병합 가능"으로 올린 것
- fix/onehand 33272a46 → main에 병합됨.
- dev3-v4-tables e5c8bb08 (최종 검수 병합 예정). 후속(개발 3): EggHonorAt 미래 값 → now로 자르기.
- fix/golden-egg-client **3d95925a**(30fa96da 아님) (최종 검수 병합 예정). dev4-bag과 ClientMain ORDER 한 줄 충돌.
- fix/onehand-2 6d449153 (사진: 사용자 아바타 마법사 옆 발끝, 연금술사 팔, 대장장이 Q).
- **묶음 ① fix/lesstext 0325d628 + fix/lesstext-server 6fc3ba52** (시험 17개 + a23_14 --no-mutations). a23_14 변이판은 Game-gprev2에서 도는 중 → 결과 확인(놓친 변이 있으면 최종 검수에 따로).

## 결정 (최종 검수 OK)
- 한 번에 팔기(오토 포함) = 몬스터 재료만, 채집·제작 재료는 가방에서 하나씩(SellItem) → 개발 2·3에 보냄.

## 고쳐서 다시 / 기다림
- dev4-bag (지금 d15da56c): 내 목록 1~8 아직 안 고침(물약 0개 칸, REG.Arg 다시 적용, ScrollCombat 키, Slow 줄, 골드·LiveSig 다시 그리기, 첫 Inventory 푸시, Drink 공용 제한, 메뉴 Items) + 창 아래 테두리가 아래 메뉴 줄 덮음. API 리뷰: build/api_agent/gprev_bag_review_2/result.md. dev4-gather는 그 위(9a59e752).
- fix/spawnclear: 개발 2 고친 커밋 오면 시험 + 실제 지도 측정(숲 면적 손실·첫 KO 킹 실패율).
- fix/lesstext-server의 '서버 글 판정표' 큰 커밋(같은 가지, 6fc3ba52 뒤에 올 것) — 따로 검수.
- api/dev3-gather (개발 3 GatherService), 개발 4 제작 창.
