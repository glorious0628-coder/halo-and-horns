# 게임성 개발 4 — 인계 상태 (2026-10-12 점심, **사용자 결정: 10/17 주간 초기화 뒤까지 쉼**)

클라 화면만(StarterPlayerScripts·UIKit·클라 시험 + 공용 순수 모듈). 메인 Studio 안 건드림. **보고: 가지 push·사진·결과 = '게임성 검수', UiSandbox 화면 조작 승인·사용자 질문 = '최종 검수'**(list_sessions로 찾기). UiSandbox 창·Play는 최종 검수에 "게임성 개발 4 / 무엇 / 몇 분" → "전달함, 시작"(또는 앞 차례 세션의 "끝") 뒤에만, 끝나면 Play 멈추고 UiSandbox 저장 없이 닫기(Stop-Process 그 pid, 제목 확인) → "끝". 바탕화면 마우스·키보드 금지.
- **API 쓰기 job 끝**(남은 ≈ $22는 최종 검수 검토용, 사용자: 충전 안 함) → 큰 코드도 앱 세션에서 직접.
- **'병합 가능'으로 보고한 끝 커밋은 다시 쓰지 않음**(rebase·push -f 금지) — 위에 쌓고, main(또는 아래 가지)은 `git merge`.
- 커밋: worktree에서 `git commit -m "짧은 한국어" -- <경로>` → 내 가지만 push. 시험이 덮어쓰는 옛 docs/art/verification_* JSON은 `git restore`.
- worktree(sparse src/tools/docs): `Game-dev4g`(이 상태 가지 dev4-state / dev4-market-window), `Game-dev4t`(dev4-gear-slots). **사진 전용 묶음** = 그때만 `git worktree add --no-checkout --detach ../Game-dev4p <commit>` + sparse + Config 스위치만 켬 → UiSandbox에만 sync → `git worktree remove --force`(커밋 절대 안 함).
- UiSandbox: Start-Process "C:\Users\glori\AppData\Local\Roblox\Versions\version-9b554450a0fc4e65\RobloxStudioBeta.exe" '"…\Game\build\UiSandbox.rbxlx"' → list_roblox_studios에서 이름 "UiSandbox.rbxlx" id만 STUDIO_ID → 사진 묶음 폴더에서 `py tools/sync_to_studio.py --stop-play` → 내 가지 폴더에서 사진 스크립트.
- Bash heredoc·python -c는 `\n`·`\t`를 진짜 줄바꿈으로 바꿈 → 변이 문자열 편집은 scratchpad .py 또는 Edit 도구.

## main에 들어간 것
가방 BagUI, 채집 GatherView, 망치질 CraftMini·CraftView, 제작 창 CraftWindow(작업대 프롬프트), 조련사 화면(소환·Research 탭·펫 Roll/Born/Feed), 연금 물약 화면(dev4-tonics 6867e71f: 가방 Drink·Wait m:ss·꺼지면 재료 탭, BuffBar = MP 줄 끝·px 바닥·경고 10초).

## 병합 대기 (게임성 검수 시험 중)
- **② 거래소 창 C-6 — origin/dev4-market-window 3bd187d9**: MarketWindow.luau(Buy·Sell·Mine, 계약 docs/design/market_window_2026-10-12.md §6 = 개발 2 합의, 스위치 Market 꺼짐, 서버 C-5 없으면 "The market is resting."). 시험 tools/test_market_window.py 165·60/60. 사진 docs/art/verification_2026-10-12/market/pc 00~03(+04 영웅 창). 사진 스크립트 tools/play_market_photos.py [--hero](Play 안 서버 대역). 남은 질문(개발 2 서버 올 때): Fx "Market" 알림 직접 듣기, 열린 동안 Mine 10초, Sell에서 T1 여분 거르기, 값 = 한 줄 전체 값.
- **③ 장비 칸 — origin/dev4-gear-slots 01a3fc3b**(개발 1 api/dev1-character-ui-2 b479014a 위; 개발 1 먼저 병합): GearSlots.luau(EquipSlots 안 6칸, 무기 → CharacterUI.ShowView("Weapons"), 펫 → 펫 창, 방어구·반지·펫 장비 = 서버 C-7 전 빈 칸, Cells(ctx).Gear로 채움). 시험 tools/test_gear_slots_ui.py 69·28/28(개발 3 test_gear_slots와 다른 파일), test_character_ui 138·59/59. 사진 market/pc/04_hero_gear_slots.

## 10/17 뒤 다음 큐
1. 게임성 검수가 위 둘에 낸 고칠 것.
2. 그림 들어오면 사진 확인: imgdev-icons2(CraftRing·CraftTarget·CraftIngot·IconCrownDust), imgdev-icons3(IconPetTreat·물약 4개) — 고리 화면·가방·버프 칸·펫 Feed.
3. Tonics 켤 때 물약 화면 다시 찍기(tools/play_tonic_photos.py, 지금 pc2 = 고친 배치).
4. 거래소 서버(개발 2 C-5) 오면: 대역 대신 실제 원격으로 사진 + 위 남은 질문.
5. 장비 서버(개발 3 C-7) 오면: GearSlots에 Gear 데이터·끼기/빼기·전투력 미리보기.
6. 소리 HammerPerfect/Great/Good/Miss·CraftDone 요청(소리 만들기, 미요청).
7. ⑦ 장인 스킬 효과·장인 채집 Fx "Gather"(그림 오면).
