# 게임성 검수 상태 (2026-10-11 밤)

역할: `role_prompts/14_gameplay_review.md`. 시험 폴더(sparse): `C:/Users/glori/Documents/Roblox/Game-gprev`, `Game-gprev2` (src·tools·docs + build/luau_cli_0_741; 시험이 보고 json을 고치므로 바꿀 땐 `git checkout -f --detach`). 시험 병합 = `git merge-tree --write-tree origin/main <가지>` → `git commit-tree`.

## 끝난 판단
- fix/onehand 33272a46 = 병합 가능 → **최종 검수가 main에 병합함.** 낮은 후속 6개는 개발 1에 보냄.
- **dev3-v4-tables e5c8bb08 = 병합 가능**(최종 검수에 보냄). 새 main f66ceeec 위 save_v4_tables 96·53/53 + 관련 13개. ops_safety 할로윈 변이 1개 = main도 같음. 후속(개발 3): EggHonorAt 미래 값 → now로 자르기; 오토 한 번에 팔기는 몬스터 재료만(채집·제작 재료 제외, 개발 2와).
- **dev4-bag ada1a4ef = 고쳐서 다시**(개발 4에 보냄): 물약 0개면 Use 탭 칸 없음(KO1), REG.Arg 다시 적용(탭 튐), ScrollCombat 키 없음, Slow 줄(A23-130), 골드·LiveSig 전체 다시 그리기 + 확인 3개(첫 Inventory 푸시, Drink가 VitalsUI.Request 건너뜀, 메뉴 Items 옛 목록). API 리뷰: build/api_agent/gprev_bag_review_2/result.md.

## 기다리는 것
- 묶음 ① 남은 것 = fix/lesstext 0325d628 + fix/lesstext-server(개발 2 MinGap 고침 커밋 대기, 원격 아직 249a68a0). 둘 합친 시험 병합 충돌 0. 고친 커밋 오면: a23_14·onboarding·weapon_first·unarmed_start·gamepass·notify_sound(변이) + ReturnService 시험.
- fix/spawnclear: 고친 커밋 오면 시험 + 실제 지도 측정(숲 면적 손실·첫 KO 킹 실패율).
- dev4-bag 고친 커밋, dev4-gather(bcc7b951 = 가방 + GatherView, 보고 오면), api/dev3-gather.

## 진행 중
- fix/golden-egg-client 30fa96da (시험 병합 28db855d, Game-gprev2): egg_fx 51·25/25 통과, audio·quest_target·map_v2·marker_top·hud_reveal·quest_lines·notify_sound·a23_14(--no-mutations) 진행. 꺼짐 길 코드 확인 끝. 낮은 것: EggFx.Step 오류 시 RenderStepped마다 warn.
- **충돌 주의:** dev4-bag × golden-egg-client = ClientMain ORDER 한 줄 → 둘째 병합 가지는 main 다시 받기.
