# 메인 반영 1 — 인계 상태

> **10/18 정리(최종 검수):** 옛 절은 지움 — 전부 git 역사에 있음: `git show b558445b:docs/handoff/state/mainapply.md`. 아래 = 지금 필요한 절 + 방법·도구 메모.

## 절차 메모 (자세한 건 `docs/handoff/role_prompts/01_mainapply.md` "메인 Studio 절차 메모")
- Play 테스트: 내 스크립트 `build/mainapply_2026-10-09b/play_*.py`(git 무시). 최신 틀 = `play_rain.py`/`play_morning11.py`. `tools/play_main_checklist.py` 머리를 exec. 새로 시작 → 원격으로 ChooseFaction Halo / ChooseClass Warrior,"M" / AcceptTutorial → 테스트 → Play 정지.
- 임시 스크립트 `TmpMainApplyTest`(StarterPlayerScripts LocalScript / ServerScriptService Script)는 Edit에서 만들고 끝나면 삭제. **`sync_to_studio.py`가 이걸 지우니 sync 뒤에 다시 만들 것**(이번에 이것 때문에 Play가 WaitForChild에서 멈춤).
- 창이 최소화되면 3D 캡처가 흰색 → PowerShell `ShowWindow(handle,4)`(활성화 없음)로 복원, 끝나면 `7`. `open_application`은 새 Studio 홈을 띄우므로 쓰지 말 것.
- Play는 한 번에 하나. 다른 세션 python 테스트가 많으면 Studio가 느려지고 내 Play에 원격을 쏘기도 함.
- Studio 사진 폴더: `docs/art/verification_2026-10-10/main_apply_morning/<이름>/`.

## 막힌 것 / 결정 대기
- 없음. 새 검수(local_78581314) 큐 대기.

## 큐 추가 (10/13, 최종 검수 → 게임성 계획 §5 '메인 반영 1')
- 10/15: Save As 화면 제어가 필요하면 최종 검수에게 미리 신청(최종 검수가 사용자에게 알림).
- 10/16 오후: 코드 == origin/main(`0 0`) → sync → PC·폰 첫 10분 재기(ForgeWalk 초, 막힌 곳 사진) → TextChatService(말풍선·VIP 채팅) 확인 → Save As `build/GoodEvil.rbxlx` → `place/` 복사·커밋. Publish는 사용자.
- 그 전까지: 병합이 올 때 sync·사진만. 10/17~20 급한 고침만 sync. 10/21 주: 6단계 교체 → 10줄 점검 + 걷기 시간.

- 10/16 종료 전: 메인 Studio 소스 = 2a3489d1, place/는 15:10 게시판 그대로, Save As 안 함(코드는 git).

- 10/17 밤 멈춤: 메인 Studio 창 하나(2:57에 연 창, 복구 창은 사용자가 닫음), 마지막 sync = d54ee16c(코드 == origin/main), Save As·게시 안 함(place/ = 10/16 15:10 dce0db87 그대로). 화요일 오전 재개: 창 개수 먼저 확인.

## 10/18 새 PC로 옮김 (메인 반영 1)
- 메인 Studio 창 없음(Studio 프로세스 0개 — PC 바뀜. 10/17 밤 열었던 pid 34772는 PC 이동으로 사라짐, 내가 닫은 것 아님).
- 메인 Studio 마지막 sync = d54ee16c(코드 == 당시 origin/main), 그 뒤 main은 문서만. Save As·게시 없음. place/ = 10/16 15:10 dce0db87 그대로.
- 다음: 최종 검수 "전달함, 시작" 뒤 `roblox-studio:` URI로 열기(placeId 81671223175574, universeId 8570876289) → 창 하나 확인 → sync → 한 줄 보고.

## 10/18 정리 (메인 반영 1) — 위 '새 PC로 옮김' 절은 취소됨(이 PC에서 계속)
- 메인 Studio 마지막 sync = d54ee16c. main 62b7b48e(dev2-detail + Neighbor + 물속 무기·칼 손에) sync 대기. Save As·게시 없음, place/ = dce0db87. 오늘 sync 안 함, Studio 안 열려 있음. 규칙: Studio는 짧게 열고 sync 뒤 닫기(저장 안 함).
