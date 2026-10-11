# 게임성 검수 상태 (2026-10-12, PC 끄기 전 정리)

역할: `role_prompts/14_gameplay_review.md`. 시험 폴더(sparse): `C:/Users/glori/Documents/Roblox/Game-gprev`, `Game-gprev2`, `Game-gprev3`, `Game-gprev4` (src·tools·docs + build/luau_cli_0_741; 시험이 보고 json을 고치므로 바꿀 땐 `git checkout -f --detach`). 시험 병합 = `git merge-tree --write-tree origin/main <가지>` → `git commit-tree`. 다른 세션 메시지는 사용자 입력 한 번에 10개까지(넘으면 막힘 → 여기 적기, `mcp__ccd_session_mgmt__send_message`로 최종 검수에는 갈 때가 있음). 큰 가지는 전체 시험을 세 폴더로 나눠 돌림: scratchpad `shard.sh <폴더> <커밋> <k> <n> <로그> <목록>`.
개발 세션에 부탁함: '병합 가능'으로 보고한 끝 커밋은 다시 쓰지 말고 위에 쌓기.

## main에 병합됨 (main 37a5dc62까지)
onehand·onehand-2, golden-egg(3d95925a·eebeebd3·egg-mine cef8f3f6), v4-tables, lesstext + lesstext-server 6fc3ba52, dev4-bag + fix/bag-2, dev3-gather, dev3-craft b868d6ce, spawnclear 358867c7 + rim e1429fba, reward-chip, dev4-gather bb2cdbfe, dev4-craft 5d4fc6f3, photo-1012 40159fe9, imgdev-icons1. 메인 반영 1 96ec45ad 사진: spawn probe 프롭 안 0·Play 8회 0, 받기 칩·강화 줄 안 잘림, 재료 팔기 494 = +494, 오토 G(모루 프롬프트 12칸) 열림 — 통과.

메인 반영 1 37a5dc62 probe: 프롭 안 0, 빈 시도 비율 숲 Goblin 68.5%·Brute 60.4%, 초원 Slime 80.6%·BigSlime 72.3%, 폐허 98~99% → 내 오프라인 실측(잃은 면적 32%·36%·17%·24%·1% 안)과 몇 % 안에서 맞음 = spawnclear 끝. 웅덩이 테두리 안 슬라임 0, 가방 재료 아이콘 8칸 그림.

## 아침에 할 것 (순서)
1. **fix/spawnclear-rim 0a1e3e75 = 병합 가능**(town_quests 정규식 한 커밋, 1035·STATIC 8/8·변이 244/244) — 최종 검수에 알림(전달됨).
2. **fix/lesstext-server 6adf2c82(개발 2 서버 글 판정표, src 25개) sweep 마저:** 시험 병합 ec3588f9(main 37a5dc62 위, scratchpad ls_merge.txt·ls_list.txt 163개). 지금까지 134개 통과, 실패 2개 = test_costume_physics·test_skin_binding_studio(이름상 Studio/옛 의상 파일 필요 — main에서도 같은지 확인할 것). 남은 약 27개(셋째 폴더) 돌리고 → 반박 리뷰(소리만 내는 빈 글 Notify는 Audio.NotifySound가 Sound로 재생, UIKit은 빈 글 무시 — 확인함) → 병합 가능 보고. main이 그 사이 바뀌면 merge-tree 다시.
3. 못 보낸 메시지(10개 제한): 개발 2 — OutlawStart + OutlawAutoOff 동시 2줄 → 한 줄("Outlaw! Auto is off." 같은), 판정표 다른 결정은 그대로 받음. 개발 2·3·4 '지금 마무리'는 최종 검수가 대신 보냄.
4. **fix/pvp-toast 2dec3bdf 시험**(개발 1, 'PvP zone!' 겹침: UIKit.NotifyFilters + FirstSteps PVP.SkipToast; 개발 1이 first_steps 57·32/32 등 통과, test_audio는 아직) → compile + first_steps·audio·notify_sound·toast_queue 돌리고 병합 가능 보고.
5. 개발 1(전달됨): 지팡이 끝 계단 −0.12·경사 +0.51(경사 Ground.Cast 법선), HUD Hero 칸 'Coming soon!' → 잠금 표시·글 없음(Hero 창 BB8 전까지), 첫 PvP 카드 + 'PvP zone!' 겹침 → 카드 뜰 땐 토스트 건너뜀.

## 결정
- 한 번에 팔기 = 몬스터 재료만(Source 채집 "Gather"·보스 "Boss" 제외, SellItem은 Source 상관없이). 화면 합계도 같은 규칙.
- 2배 XP 패스 글: 제작 켜는 가지에서 "Get 2x level XP, so you level up 2x faster. Crafting levels do not change. No stats are for sale."
- 망치질: 두드림마다 CraftStrike(Id, i, ms), 공용 Shared/CraftMini, Finish(Id)만, Skip = +0, 나가기·20초 = +0, 핑 = 큰 값; 베타는 CraftMini 창 그대로 + CraftStrikeD 지표로 10/17~20 뒤 조정. 두드림 키 = 점프 요청(고리 열린 동안 점프 끔).
- 제작 서버: 레시피 시작값, 펫 장비 = 조련사, 무기는 AddSpare 뒤. 켜는 조건: 채집 = SellItem/거래소, 제작 = AddSpare/SpareRoom.
- A23-130 화면 쪽: 남의 무기 자랑 배너(A23-15)·사이렌 칩·첫 10분 Travel/Welcome 줄은 그대로.

## 원래 있던 문제
- test_ops_safety 할로윈 변이 1개(병합 기준 아님).
