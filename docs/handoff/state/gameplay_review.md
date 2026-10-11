# 게임성 검수 상태 (2026-10-11 밤 늦게)

역할: `role_prompts/14_gameplay_review.md`. 시험 폴더(sparse): `C:/Users/glori/Documents/Roblox/Game-gprev`, `Game-gprev2`, `Game-gprev3` (src·tools·docs + build/luau_cli_0_741; 시험이 보고 json을 고치므로 바꿀 땐 `git checkout -f --detach`). 시험 병합 = `git merge-tree --write-tree origin/main <가지>` → `git commit-tree`. **메시지는 사용자 한 번 입력마다 10개까지** — 넘으면 막힘.

## 최종 검수에 "병합 가능"으로 올린 것 (최종 검수 순서: golden-egg → v4-tables → 묶음 ① → onehand-2)
- fix/onehand 33272a46 → 병합됨.
- fix/golden-egg-client **3d95925a**.
- dev3-v4-tables e5c8bb08.
- 묶음 ① fix/lesstext 0325d628 + fix/lesstext-server 6fc3ba52. a23_14 변이판은 Game-gprev2에서 도는 중(놓친 변이 나오면 최종 검수에 바로).
- fix/onehand-2 **0dc6c46d** (자세 + 뿔 마법사/궁수 허리 −8/−12). 사진 목록은 보고에.
- dev4-bag **7a2c9afd** (ClientMain ORDER 한 줄이 golden-egg와 충돌 → 둘째 병합 쪽이 main 다시 받기).
- dev3-gather 520e8cb7 (스위치 꺼짐으로 병합 가능).

## 못 보낸 메시지 (10개 제한) — 다음 사용자 입력 뒤 개발 3에게 보낼 것
dev3-gather 켜기 전 고칠 것: 1) 채집 재료 팔 곳 없음(LootService 602 Source 제외 + SellItem 없음; 재료 설명 "Sell it at the Forge."·가방 가득 줄 거짓) → 켜기 조건. 2) 꽃 나눔 중심 = 누른 사람 위치(GatherService 352-353) → bloom.Pos, 받는 사람 IsAlive+ClassChosen. 3) onHoldBegan·Try가 IsReady 안 봄 → ST.Hold 남음(PlayerRemoving 정리). 4) GrantItems 오류 시 개수는 전후 비교로. 5) 앉음·순간이동 중 거절. (API 리뷰: build/api_agent/gprev_gather_review_1/result.md)

## 결정·전달 끝
- 한 번에 팔기 = 몬스터 재료만(개발 2·3). 2배 XP 패스 글: 제작 켜는 가지에서 "Get 2x level XP, so you level up 2x faster. Crafting levels do not change. No stats are for sale."(개발 3).
- 망치질 계약(개발 4 dev4-craft 48dff273 + 개발 3 제작 서버): 두드림마다 CraftStrike, d ∈ [−50, 250+1.5×핑], Finish(Id)만, Skip = +0, 나가기·20초 = +0 저장. 핑은 세션 시작 때와 지금 중 큰 값(개발 4에 제안).
- 제작 서버 설계(dev3-craft 37113fa4) OK: 레시피 시작값, 펫 장비 = 조련사, 무기는 개발 2 AddSpare 뒤.

## 원래 있던 문제 (main)
- test_skills: STATIC_FAILURE "Q heals / steals through the window" + 변이 패턴 0번(87/88) → 최종 검수에 개발 2 몫으로 알림.
- test_ops_safety: 할로윈 변이 1개 놓침(병합 기준 아님).

## 기다림
- fix/spawnclear 고친 커밋(시험 + 실제 지도 측정), lesstext-server '서버 글 판정표' 큰 커밋, dev3-craft 코드, dev4-gather 1d935025·dev4-craft 1634e079(bag → dev3-gather → dev4-gather → dev4-craft 순서).
