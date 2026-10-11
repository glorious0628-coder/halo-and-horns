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

## 못 보낸 메시지 2 — 제작 판정 하나로 (개발 3·개발 4)
- dev3-craft bdc333f4 = **고쳐서 다시**(test_craft 94·60/60 통과지만 계약이 개발 4와 다름). 결정: 판정은 **공용 Shared/CraftMini.luau 하나**(서버·화면 같은 함수). 개발 4가 CraftMini + test_craft_mini만 담은 작은 가지(origin/main 위)를 올림 → 게임성 검수 시험 → 먼저 병합 → dev3-craft·dev4-craft가 그 위로 다시 쌓고 CraftService는 CraftMini.Accept/Check를 부름(Config.CraftGrade/CraftPlus 따로 두지 않음).
- 허용 숫자(TolMs, 개발 3 질문 답): 1번 두드림 = 250ms + 1.5×핑(세션 시작·지금·받을 때 중 큰 핑), **2~5번 = 앞 두드림과의 간격으로 비교, 120ms**(핑이 지워짐). 시험에 '실제 +290ms를 40ms로 속임 → Miss' 변이.

## 못 보낸 보고 — 최종 검수에 (spawnclear)
- **병합 가능 fix/spawnclear a86ca243**(5e524e70·c54f4bfb·a86ca243). 시험 병합 f51720a0 충돌 0, src 2개 compile OK. spawn_clear 179·62/62 + 관련 13개(Game-gprev3 결과 확인 후 적기).
- 실제 지도(내가 잼, 새 CLEAR 코드를 place 72a5f19b 부품 위에서 그대로 실행, scratch spawn2/rv2_measure.py·json): 설계 검사관 추천 규칙과 판정 일치 98~99.9%(다른 곳은 전부 꽃·풀 Pass로 새 코드가 더 풀어 줌), 옛 규칙 대비 잃은 면적: 숲 고블린 32.0%(추천 예상 32.6%, 옛 가지 45.7%), 브루트 36.0%(37.0%/49.8%), 초원 슬라임 17.1%, 빅 슬라임 23.9%, 폐허 0.4~0.8%. 첫 KO 킹 '모두 막힘' 11.5% → 4.1%(24곳), 킹 언덕 60칸 안 19.4% → 10.5% — 실패 시 FirstKOService가 SpawnGap 4초 뒤 그때 위치로 다시 시도 → 몇 초 늦을 뿐.
- 메인 반영 1: 병합·sync 뒤 tools/spawn_clear_probe.luau를 메인 Studio Edit에서 돌려 위 숫자와 비교 + 숲·초원 몹 생김 사진.

## 결정·전달 끝
- 한 번에 팔기 = 몬스터 재료만(개발 2·3). 2배 XP 패스 글: 제작 켜는 가지에서 "Get 2x level XP, so you level up 2x faster. Crafting levels do not change. No stats are for sale."(개발 3).
- 망치질 계약(개발 4 dev4-craft 48dff273 + 개발 3 제작 서버): 두드림마다 CraftStrike, d ∈ [−50, 250+1.5×핑], Finish(Id)만, Skip = +0, 나가기·20초 = +0 저장. 핑은 세션 시작 때와 지금 중 큰 값(개발 4에 제안).
- 제작 서버 설계(dev3-craft 37113fa4) OK: 레시피 시작값, 펫 장비 = 조련사, 무기는 개발 2 AddSpare 뒤.

## 원래 있던 문제 (main)
- test_skills: STATIC_FAILURE "Q heals / steals through the window" + 변이 패턴 0번(87/88) → 최종 검수에 개발 2 몫으로 알림.
- test_ops_safety: 할로윈 변이 1개 놓침(병합 기준 아님).

## 기다림
- fix/spawnclear 고친 커밋(시험 + 실제 지도 측정), lesstext-server '서버 글 판정표' 큰 커밋, dev3-craft 코드, dev4-gather 1d935025·dev4-craft 1634e079(bag → dev3-gather → dev4-gather → dev4-craft 순서).
