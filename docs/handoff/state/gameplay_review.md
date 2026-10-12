# 게임성 검수 상태 (2026-10-12 아침)

역할: `role_prompts/14_gameplay_review.md`. 시험 폴더(sparse): `C:/Users/glori/Documents/Roblox/Game-gprev`, `Game-gprev2`, `Game-gprev3`, `Game-gprev4` (src·tools·docs + build/luau_cli_0_741; 바꿀 땐 `git checkout -f --detach`). 시험 병합 = `git merge-tree --write-tree origin/main <가지>` → `git commit-tree`. 큰 가지는 전체 시험을 네 폴더로: scratchpad `shard.sh <폴더> <커밋> <k> <n> <로그> <목록>`(--no-mutations), 변이까지는 `shard_full.sh`; 목록 = tools/test_*.py에서 halloween·place_english·rank_marks·shop_layout·costume_physics·skin_binding_studio(은퇴/파일 필요) 뺀 161개. 다른 세션 메시지는 사용자 입력 한 번에 10개까지 — 최종 검수에는 `mcp__ccd_session_mgmt__send_message`(local_d522c0f1…)가 됨.
규칙(memory): 보고한 끝 커밋은 다시 쓰지 않기; **서버 알림을 지우는 가지는 그 행동을 보내는 클라 화면이 결과를 그리는지 따라가 보고, 글·시험을 건드린 병합은 전체 sweep**(10/12 판정표에서 강화 결과 토스트 놓침).

**사용자 지시(10/12, 최종 검수 전달): 큰 리뷰·반박 검토 = `py tools/api_agent.py` 읽기 모드**(`--make-worktree <시험 병합 커밋> --model opus --max-usd 2~3`, 프롬프트는 scratchpad review_*.md 형식: 확인한 것/그럴 수 있는 것 + 파일:줄 + 장면). 앱 세션은 지휘·시험 sweep·짧은 확인. 남은 API 약 $85. 개발 1~4에도 '큰 코드는 API 쓰기 모드 먼저' 전달함.

**병합 알림 받으면 확인:** `git merge-base --is-ancestor <가지 끝> origin/main` — 10/12 dev4-tonics 병합 5db4018e가 push 거절로 main에 안 들어갔는데 상태 파일만 올라간 적 있음(최종 검수에 알림, 다시 병합 대상 6867e71f).

## main에 병합됨 (지난밤까지 + 오늘)
지난밤 목록 + fix/egg-mine, spawnclear-rim(+town_quests 정규식), imgdev-icons1, fix/pvp-toast, fix/staff-slope-hero. 메인 반영 1 사진: spawn probe 프롭 안 0·빈 시도 비율이 내 오프라인 실측과 몇 % 안, PvP 카드·Hero 자물쇠·지팡이 평지/경사 OK.

## "병합 가능" 올림, 최종 검수 병합 대기
- dev4-craft c35905ee(제작 창), fix/stairs-ground 3099197e(계단 = 땅), dev3-alchemy ba91630f(연금 물약 + A23-139), dev3-craft2 e0556202(제작 창용 서버) — 최종 검수 '지금 병합' 중.
- **fix/lesstext-server 8c8dc44d**(판정표 + 강화 토스트 되살림 + 보스 구역 이름 + 출석 한 줄): 전체 161 + 바뀐 시험 5개 변이 + a23_14 99/99.
- **dev3-tamer b3972a6b**(조련사 연구·소환·간식 Herb, PetService 개발 2 OK) — alchemy → craft2 다음.
- **dev4-tamer d9db0a67**(조련사 화면 4개) — dev4-craft 다음. 낮은 것: 펫 칸 작은 줄 글자 크기(개발 4).

## 결정 (오늘)
- A23-139(사용자): 2배 XP 패스 = 제작 XP도 2배, 제작·제작 XP는 장인 길드만. 패스 글 "Get 2x level and crafting XP. No stats are for sale."
- 행운 물약 = Source 없는 몬스터 재료만. 소환 속도 = 무작위 5~8 + 망치질 +N(최대 10). 간식 = Jelly 5 + Herb 2. 보스 재료 Source "Boss". 한 번에 팔기 = 몬스터 재료만.
- A23-130: 무법자 주 시작 한 줄, 첫 PvP 카드 뜰 땐 'PvP zone!' 건너뜀, 남의 무기 자랑 배너·사이렌 칩·첫 10분 줄은 그대로.
- 망치질: CraftStrike(Id, i, ms) 두드림마다, 공용 CraftMini, 두드림 키 = 점프 요청.

## A23-141 거위 광장 가지 오면 볼 것(최종 검수 요청)
못 들어가는 때(죽음·괴수·원한 자루·PvP 10초 안 때림/맞음), 돌아가는 자리(누른 자리, 없거나 위험하면 진영 마을 시작점), 판 끝 자동 귀환·Leave, 인원 기준 = 거위 광장 안 사람(협동 목표·H·한 편 안 옴·MinDelivered), 교차로 광장에 거위·알·막대 0, 자동 전투 멈춤/복원, 장인 입장(알 바로 가방), 같은 서버·저장 넘김 없음. 서버 = 개발 2(dev2_golden_egg 위), 화면 = 개발 1.

## 기다림
- api/dev3-gear 고친 커밋(GearMultsOf 지키기 → test_owner_restore) → 그다음 dev3-fame(⑦ 명성, 주간 상한 100).
- 개발 3 ⑥ 장비 칸, 개발 4 다음 화면, 개발 1 다음 가지, 개발 2 C1(AddSpare/SpareRoom·저장 v4·보스 재료).
- 월드 쪽(최종 검수 경로): 새 빛 마을 계단·바닥이 다른 폴더면 WalkGround 태그 또는 Decor.*Props 이름 규칙.

## 원래 있던 문제
- test_ops_safety 할로윈 변이 1개(병합 기준 아님).
