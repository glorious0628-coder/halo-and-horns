# 게임성 검수 상태 (2026-10-12 낮 — 쉼)

**사용자 결정(10/12 점심, 최종 검수 전달): 사용량 때문에 세션 7개로 → 게임성 검수 쉼.** 다시 부를 때까지 새 시험 안 함. 개발 1~4의 가지 보고는 **최종 검수로**(개발 1·2·4에 알림, 개발 3·4도 쉼).

역할: `role_prompts/14_gameplay_review.md`. 시험 폴더(sparse): `C:/Users/glori/Documents/Roblox/Game-gprev`, `Game-gprev2` … `Game-gprev6` (src·tools·docs + build/luau_cli_0_741; 바꿀 땐 `git checkout -f --detach`). 시험 병합 = `git merge-tree --write-tree origin/main <가지>` → `git commit-tree`(종료 코드 1 = 충돌). 전체 시험은 폴더 2~4개로 나눠: scratchpad `shard.sh <폴더> <커밋> <k> <n> <로그> <목록>`(--no-mutations), 변이까지는 `shard_full.sh`; 목록 = 시험 병합 커밋의 tools/test_*.py에서 halloween·place_english·rank_marks·shop_layout·costume_physics·skin_binding_studio·skeleton_ground(은퇴/파일 필요) 뺀 것(10/12 낮 166~167개).

## 규칙 (다시 시작할 때)
- 보고한 끝 커밋은 다시 쓰지 않기(충돌 때만 main 합치기, rebase 금지).
- 서버 알림을 지우는 가지는 그 행동을 보내는 클라 화면이 결과를 그리는지 따라가 보기. 글·시험을 건드린 병합은 전체 sweep.
- **시험 범위는 SPEC 숫자와 맞대기**(지팡이 REACH 시험 0.82~1.03이 SPEC 0.85~1.0H보다 넓어 1.008H를 놓침).
- 병합 알림 받으면 `git merge-base --is-ancestor <끝> origin/main`(10/12 dev4-tonics push 거절 사례).
- API 남은 약 $22 = 최종 검수용. 내 검토는 앱 안.

## 병합 가능 (최종 검수 병합 대기)
- **dev3-fame 5933d919**(⑦ 명성, 주간 상한 100) — 최종 검수가 character-ui-2와 같이 병합 중.
- **api/dev1-character-ui-2 b479014a**(영웅 창, 닉네임 줄·Lv2 잠금 고침).
- **imgdev-stickers de9e4fcf**.
- **fix/goose-square cb886aae**(개발 1, A23-141 화면 = API job api/dev1-goose-square 4e34b165 $6에서 멈춤 → 개발 1이 마무리): main a09de901과 깨끗, 전체 166/166, egg_fx 126·66/66, map_v2 36/36, hud_reveal 15/15, quest_target·audio 통과. 코드: 거위 모드 아니면 그대로, 광장 밖이면 알 막대·고리·소리·째깍·지도 둥지/수레·퀘스트 화살표 꺼짐, Join은 GooseJoinBlock이면 흐림. **개발 2 서버(아래)와 같이 병합.** 사진(메인 반영 1): 위 막대 Join(PC, HUD v2 열 안에서 화면 밖으로 안 나가는지)·Leave·어두워짐.
- **dev4-market-window 3bd187d9**(개발 4 거래소 창 C-6): main 79b2a5f3과 깨끗, 전체 167/167, test_market_window 165·60/60. 스위치 Market 꺼짐 = 안 보임·안 보냄(앱 하위 에이전트 반박 검토 + 내 확인). **스위치 켜기(C-5) 전에 고칠 것**(개발 4): ① TimeText 65초와 3900초가 둘 다 "1:05"(`MarketWindow.luau:194-200`, 시간·분 모양 다르게) ② 팔린 줄 값 = 수수료 전 값(`:1007`, Sold는 Fee 뺀 값) ③ T1 여분이 Sell 목록에(`:328-334`, 계약 §1·서버 §6-1과 다름) — 셋 다 내가 확인. 에이전트만 본 것: ④ 첫 MarketIndex 답 전 "Nothing here."(`:720`) ⑤ 답 없는 MarketBrowse 다시 안 물음(`:468`) / 낮은 것: 대체 간격 List 6·Cancel 6 vs 서버 설계 10·5, Fee 0.10 하드코딩 → Config.Market.Fee, Config.Market.Text 없으면 전부 "Not now.", 탭 상관없이 10초마다 다시 그림, 검색 24바이트 자르기(한국어 깨짐).

## 시험 안 한 것 (최종 검수가 받음)
- **dev4-gear-slots 01a3fc3b**(개발 4 장비 칸, b479014a 위 + 시험 이름 test_gear_slots_ui로 바꿈): main e8f76ed4와 깨끗만 확인. 개발 4 보고: gear_slots_ui 69·28/28, character_ui 138·59/59. character-ui-2 다음에 병합.
- **fix/staff-face cdab64c7**(개발 1, 지팡이 구슬 얼굴 밖·바깥 5°): main c9191ae0과 깨끗만 확인. 손 시험 묶음(one_hand_grips·two_hand_grip·class_grips_server·weapon_pose·weapon_motion·side_clips 변이) 필요.
- **api/dev2-c1-t9-v4 435999d0**(개발 2 C1: 9단계 신화·저장 v4·Spares·보스 재료): main c8407657과 **충돌**(CharacterVisuals·test_one_hand_grips, A23-142 뒤) → 개발 2에 main 합치기 + main의 staffOrb 그대로(9단계 구슬 멈춤은 staffOrb 안 math.min) 보냄. 저장 이전 읽음: v3 이하 9단계/9비트 = 손상 처리, CR-L3 그대로 — 막는 것 없음. 새 끝은 전체 + loot·weapon_ladder·save_v4·craft 변이. staff-face와 test_one_hand_grips가 또 겹칠 수 있음.
- **황금 알 서버 1차 api/dev2-golden-egg 3dfdc791** + 개발 2 거위 광장 서버(그 위, 코드 끝·시험 중이라 함): 알 명예 +5 = `PlayerService.GrantFame(p, stat, 5, { RankPoints = 5 })`(주간 150 안)로 바꾼다고 답함. Config.Goose.Square는 개발 1 화면 가지에 이미 있음 → 서버가 또 넣으면 충돌. 서버 오면 아래 A23-141 목록.

## A23-141 거위 광장 서버 볼 것
못 들어가는 때(죽음·괴수·원한 자루·PvP 10초 안 때림/맞음), 돌아가는 자리(누른 자리, 없거나 위험하면 진영 마을 시작점), 판 끝 자동 귀환·Leave, 인원 기준 = 광장 안 사람(협동 목표·H·한 편 안 옴·MinDelivered), 교차로 광장에 거위·알·막대 0, 광장 = 안전 지대(PvP 피해 0, 몬스터 0), 자동 전투 멈춤/복원, 장인 입장(알 바로 가방), 같은 서버·저장 넘김 없음, 알 명예 주간 상한.

## 낮은 것 (주인 정해서)
- 도움말 Config 'Golden Goose: every 10 minutes in the Crossroads. …'(A23-137 4시간·A23-141 Join과 다름) — 글 고칠 때 같이.
- Config GuideZones.Goose = "Crossroads"(A23-141 뒤엔 Join 버튼이라 길 안내 불필요).
- 거위 광장 (6000,200,6000)은 큰 지도 Map.Bounds 밖 → 광장 안에서 지도 열면 둥지·수레·내 표시가 잘려 안 보임.
- dev4-tamer 뒤 커밋 4c69f15f(펫 창 작은 줄 글자 — 내가 낮은 것으로 적었던 것) 아직 main 아님, 보고 안 받음.

## 결정 (오늘)
- A23-139: 2배 XP 패스 = 제작 XP도 2배, 글 "Get 2x level and crafting XP. No stats are for sale."
- 행운 물약 = Source 없는 몬스터 재료만. 소환 속도 = 무작위 5~8 + 망치질 +N(최대 10). 간식 = Jelly 5 + Herb 2. 보스 재료 Source "Boss". 한 번에 팔기 = 몬스터 재료만.
- 장비: 방어구 6/12/18%(+2/N), 반지 4/8/12%(+1/N), 착용 Lv 10/20/30, +N은 망치질만. 명성 1/2/3/4, 등급 0/30/150/500/1500, 장인 주간 100.
- A23-130: 무법자 주 시작 한 줄, 첫 PvP 카드 뜰 땐 'PvP zone!' 건너뜀.

## 원래 있던 문제
- test_ops_safety 할로윈 변이 1개, rank_marks STATIC(그림 없음), skeleton_ground(build/wk 파일 필요) — 병합 기준 아님.
