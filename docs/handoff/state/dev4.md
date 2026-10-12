# 게임성 개발 4 — 인계 상태 (2026-10-12 낮: 가방·채집·망치질·제작 창·조련사 화면 main 병합 끝 · 연금 물약 화면 병합 대기 · 거래소 계약 합의 · 장비 칸 훅 합의)

클라 화면만(StarterPlayerScripts·UIKit·클라 시험 + 공용 순수 모듈). 메인 Studio 안 건드림. **보고: 가지 push·사진·결과 = '게임성 검수', UiSandbox 화면 조작 승인·사용자 질문 = '최종 검수'**(list_sessions로 찾기). UiSandbox 창·Play는 최종 검수에 "게임성 개발 4 / 무엇 / 몇 분" → "전달함, 시작" 뒤에만, 끝나면 Play 멈추고 UiSandbox 저장 없이 닫기(Stop-Process 그 pid, 제목에 UiSandbox 확인) → "끝". 바탕화면 마우스·키보드 금지(내 시험 Play 안 Studio MCP user_mouse_input은 승인받고만). 사용자가 WorldKit 등에서 직접 일할 땐 최종 검수가 기다리라 함 — 그 말 따름.
- **큰 코드·큰 시험 = `py tools/api_agent.py` 쓰기 모드 먼저**(최종 검수·게임성 검수 10/12, 사용자 "API SDK 잘 쓰고 있지?"): 공유 트리 `Game`에서 `py tools/api_agent.py run --prompt-file <md> --out build/api_agent/<job> --model sonnet --max-usd N --max-turns N --make-worktree origin/main --write --branch api/<이름>` (docs/handoff/api_agent_howto.md). 앱 세션 = 프롬프트·결과 읽기·시험 다시 돌리기·UiSandbox 사진. job 이름·비용을 보고에. API 결과 위에 내 고침은 내 가지(dev4-…)로 쌓아 보고.
- worktree(sparse src/tools/docs): `Game-dev4g`(지금 `dev4-market`), `Game-dev4t`(`dev4-tonics`, api/dev4-tonics 위), `Game-dev4p` = **사진 전용 묶음**(커밋 절대 안 함: 가지 + Config 스위치만 켬 → UiSandbox에만 sync, 쓰고 나면 `git worktree remove --force`). `Game-dev4w` 옛 fix/bag-2.
- **게임성 검수 10/12 규칙: '병합 가능'으로 보고한 끝 커밋은 절대 다시 쓰지 않음(rebase·push -f 금지).** 그 위에 커밋을 쌓고, main과 충돌할 때만 `git merge origin/main`.
- 커밋: worktree에서 `git commit -m "짧은 한국어" -- <경로>` → 내 가지만 push(main 금지). 시험이 덮어쓰는 옛 docs/art/verification_* JSON은 `git restore`(내 새 보고 JSON만 커밋).
- UiSandbox: `Start-Process "C:\Users\glori\AppData\Local\Roblox\Versions\version-9b554450a0fc4e65\RobloxStudioBeta.exe" '"…\Game\build\UiSandbox.rbxlx"'` → list_roblox_studios에서 이름 "UiSandbox.rbxlx"인 id만 `STUDIO_ID`로(WorldKit·메인 창 헷갈리지 않게) → `py tools/sync_to_studio.py --stop-play`(사진 묶음 폴더에서) → 사진 스크립트(내 가지 폴더에서) → 닫기.
- Bash heredoc·`python -c`는 `\n`·`\t`를 진짜 줄바꿈으로 바꿈 → 변이 문자열이 든 편집은 Write로 scratchpad에 .py를 쓰고 `py` 로 돌리거나 Edit 도구.

## main에 들어간 것
- 가방 BagUI(H-1), 채집 GatherView, 망치질 CraftMini·CraftView, 제작 창 CraftWindow(작업대 프롬프트 글·역할 장인만), 조련사 화면(dev4-tamer: 소환 레시피·Research 탭·"Baby Slime +9% speed"·펫 창 Roll/Born/Feed·작은 줄 Body 글자).
- 펫 창 Roll 건(최종 검수 반박)은 이미 main에 있어 '고칠 것 없음'으로 정리됨(test_pet_tamer 22·14/14).

## ① 연금 물약 화면 — dev4-tonics a777e6bd (게임성 검수 병합 가능: 3adfe612, 그 위 a777e6bd 낮은 것 고침)
- API job dev4_tonics_2026-10-12(sonnet 50턴 ~$2.41) = api/dev4-tonics 9e4f9239·70370162 → 내 커밋 3adfe612(막힌 Drink = "Wait m:ss"·보통 버튼 색, 버프 칸 = MP 줄 오른쪽 끝) → a777e6bd(BuffBar 경고 10초 한 줄·꺼짐이면 고리 아무것도 안 함).
- BagUI: Tonic = Use 탭, Desc·"2:31 left"·[Drink] = UseTonic, 두 개면 TwoMax + Wait. BuffBar.luau(새): 켜진 물약 2개까지 칸 + m:ss, HUD relayout 목록에 "BuffBar", ORDER QuickSlots 다음. 퀵슬롯 물약은 서버(QuickSlotService)가 안 받아 안 함.
- 시험 test_bag_ui 190·84/84, test_buff_bar 75·37/37. 사진 docs/art/verification_2026-10-12/tonics/pc(4장) — **고친 뒤 pc2는 최종 검수 허락 대기**(사용자 WorldKit Import 중). 스크립트 tools/play_tonic_photos.py(클릭 없음, 클라에서 UseTonic).

## ② 거래소 창 C-6 — 계약 합의(dev4-market 9d8a679f), 화면은 아직
- `docs/design/market_window_2026-10-12.md` §6 합의(개발 2): MarketIndex(30초 캐시), Browse/Page(Pages), List("W","T:P"), Buy, Cancel, Mine(Paid·Today), **Gate = { Buy, List, ListIn }을 버튼에 그대로**(클라는 관문 계산 안 함), 거절 키 + TooFast·Off, 거래소 퀘스트 3개는 개발 2. 다음: MarketWindow.luau + 서버 대역 시험(스위치 Market 꺼짐) — API 쓰기로.

## ③ 장비 칸(A23-133) — 훅 합의, 개발 1 BB8 기다림
- 개발 1 CharacterUI(Panels 'Character', api/dev1-character-ui 예정)가 창 안 빈 Frame 'EquipSlots'를 만들고 처음 그릴 때 `C.GearSlots.Build(frame, { Refresh = fn })`, 열 때마다 `C.GearSlots.Refresh()`. **6칸 모두 내가 그림**: 위 Weapon · Armor · Ring, 아래 Pet + Pet Armor · Pet Acc. 무기 칸 누르면 가방 Gear, 펫 칸 누르면 펫 창, 방어구·반지·펫 장비는 서버 C-7(개발 3) 전엔 빈 칸. 개발 1이 가지·해시 보내면 그 위에.

## 그 뒤
- imgdev-icons2(CraftRing·CraftTarget·CraftIngot·IconCrownDust) main 들어가면 고리 화면 그림 사진 한 번.
- 아이콘 IconPetTreat·물약 4개 = 디자인 검수 → 이미지 생성 2(키 그대로).
- 소리 HammerPerfect/Great/Good/Miss·CraftDone 미요청(게임성 검수에 적어 둠).
- ⑦ 장인 스킬 효과·장인 채집 Fx "Gather"(그림 오면).
