# 게임성 검수 상태 (2026-10-12 낮 12:30)

역할: `role_prompts/14_gameplay_review.md`. 시험 폴더(sparse): `C:/Users/glori/Documents/Roblox/Game-gprev`, `Game-gprev2` … `Game-gprev6` (src·tools·docs + build/luau_cli_0_741; 바꿀 땐 `git checkout -f --detach`). 시험 병합 = `git merge-tree --write-tree origin/main <가지>` → `git commit-tree`(종료 코드 1 = 충돌). 전체 시험은 폴더 2~4개로 나눠: scratchpad `shard.sh <폴더> <커밋> <k> <n> <로그> <목록>`(--no-mutations), 변이까지는 `shard_full.sh`; 목록 = 시험 병합 커밋의 tools/test_*.py에서 halloween·place_english·rank_marks·shop_layout·costume_physics·skin_binding_studio·skeleton_ground(은퇴/파일 필요) 뺀 것(10/12 낮 166개). 다른 세션 메시지는 사용자 입력 한 번에 10개까지 — `mcp__ccd_session_mgmt__send_message`(local_… id)가 됨.
규칙(memory): 보고한 끝 커밋은 다시 쓰지 않기(충돌 때만 main 합치기); **서버 알림을 지우는 가지는 그 행동을 보내는 클라 화면이 결과를 그리는지 따라가 보고, 글·시험을 건드린 병합은 전체 sweep**; 시험 범위는 SPEC 숫자와 맞추기.

**API:** 남은 약 $22는 최종 검수용 → 내 검토는 앱 안(시험 sweep + 직접 읽기 + 필요하면 앱 하위 에이전트). 개발 세션도 이제 앱에서 직접 코드.

**병합 알림 받으면 확인:** `git merge-base --is-ancestor <가지 끝> origin/main` (10/12 dev4-tonics 5db4018e push 거절 사례).

## main에 들어간 것 (오늘 확인)
fix/lesstext-server 8c8dc44d, dev3-tamer, dev4-tamer d9db0a67, dev4-craft, fix/stairs-ground, dev3-alchemy, dev3-craft2, fix/staff-short d56d0f1e, api/dev3-gear f0367a1d, imgdev-emo.

## "병합 가능" 올림, 최종 검수 병합 대기
- dev3-fame 5933d919(⑦ 명성, 주간 상한 100) — dev3-gear 다음.
- api/dev1-character-ui-2 b479014a(영웅 창, 닉네임 줄·Lv2 잠금 고침) — 개발 4 장비 칸이 이 위에 얹힘.
- imgdev-stickers de9e4fcf.
- (확인 필요) dev4-tamer 뒤 커밋 4c69f15f 펫 창 작은 줄 글자(내가 낮은 것으로 적은 것) — 아직 보고 안 받음.

## 시험 중 (10/12 낮)
- **fix/goose-square cb886aae**(개발 1, A23-141 화면): main a09de901과 깨끗. 코드 검토 막는 것 없음(거위 모드 아니면 그대로, 광장 밖이면 막대·고리·소리·째깍·지도 둥지/수레·퀘스트 화살표 꺼짐). egg_fx 126·66/66, quest_target, map_v2 36/36, hud_reveal 15/15, audio 통과; 전체 166 도는 중. 낮은 것: 도움말 Config 'Golden Goose: every 10 minutes in the Crossroads'(A23-137/141과 다름), GuideZones.Goose = Crossroads, 광장(6000,200,6000)은 큰 지도 밖이라 지도에 둥지/수레 안 보임. 개발 2 서버 가지와 같이 병합 — 서버 오면 아래 A23-141 목록.
- **api/dev2-c1-t9-v4 435999d0**(개발 2 C1: 9단계 신화·저장 v4·Spares·보스 재료): main c8407657과 **충돌**(CharacterVisuals·test_one_hand_grips — A23-142 지팡이 뒤) → 개발 2에 main 합치기 + main의 staffOrb 그대로(9단계 구슬 멈춤은 staffOrb 안 math.min) 보냄. 저장 이전 읽음: v3 이하에 9단계/9비트 = 손상 처리, CR-L3 그대로 — 막는 것 없음. 새 끝 오면 전체 + loot·weapon_ladder·save_v4·craft 변이.
- **dev4-market-window 3bd187d9**(개발 4 거래소 창 C-6): main 79b2a5f3과 깨끗, 전체 sweep(2폴더) + 하위 에이전트 반박 검토 중.
- **dev4-gear-slots 77e5789b**(개발 4 장비 칸): 고칠 것 보냄 — 시험 이름이 개발 3 서버 test_gear_slots와 겹침(→ test_gear_slots_ui), 바탕이 47dce676이라 b479014a 위 ORDER 충돌(→ 개발 1 끝 합치기).

## A23-141 거위 광장 서버 오면 볼 것(최종 검수 요청)
못 들어가는 때(죽음·괴수·원한 자루·PvP 10초 안 때림/맞음), 돌아가는 자리(누른 자리, 없거나 위험하면 진영 마을 시작점), 판 끝 자동 귀환·Leave, 인원 기준 = 광장 안 사람(협동 목표·H·한 편 안 옴·MinDelivered), 교차로 광장에 거위·알·막대 0, 광장 = 안전 지대(PvP 피해 0, 몬스터 0), 자동 전투 멈춤/복원, 장인 입장(알 바로 가방), 같은 서버·저장 넘김 없음, 알 명예 +5 = GrantFame RankPoints(주간 150 안, 개발 2 답 10/12). Config.Goose.Square는 화면 가지에 이미 있음 → 서버 가지가 같은 표를 또 넣으면 충돌.

## 결정 (오늘)
- A23-139: 2배 XP 패스 = 제작 XP도 2배, 글 "Get 2x level and crafting XP. No stats are for sale."
- 행운 물약 = Source 없는 몬스터 재료만. 소환 속도 = 무작위 5~8 + 망치질 +N(최대 10). 간식 = Jelly 5 + Herb 2. 보스 재료 Source "Boss". 한 번에 팔기 = 몬스터 재료만.
- 장비: 방어구 6/12/18%(+2/N), 반지 4/8/12%(+1/N), 착용 Lv 10/20/30, +N은 망치질만. 명성 1/2/3/4, 등급 0/30/150/500/1500, 장인 주간 100.
- A23-130: 무법자 주 시작 한 줄, 첫 PvP 카드 뜰 땐 'PvP zone!' 건너뜀.

## 원래 있던 문제
- test_ops_safety 할로윈 변이 1개, rank_marks STATIC(그림 없음), skeleton_ground(build/wk 파일 필요) — 병합 기준 아님.
