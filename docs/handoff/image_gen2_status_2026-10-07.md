# 이미지 생성 2 상태 (2026-10-07)

이전 기록: `docs/handoff/image_gen2_status_2026-10-06.md`. 크레딧: 오늘 **0**(Firefly GPT Image 2.5 Sunburst, 중간만).

## 오전
- E11 사냥터 게시판 그림 10장 생성(문구 bc474c7) → 원본 `art/out/s2/<Key>_src.png`, 누끼 `<Key>_cut.png`(로컬, 고른 것만 나중에 커밋) → 시트 **`art/review/s2/e11_job_board_sheet.jpg`(5dc69ad)** → 검수가 보고 사용자에게 가져감. 추천: 창 A · 카드 A · Kind B · Sneaky B · 꼬리표 A. 글자 칸 분수는 scratchpad `e11_measure.py`·`e11_sheet.py`의 `LAYOUT`(검수 메시지에도 적음).
- 같은 커밋: QuestRow `sockets.Count`를 실제 그림에서 다시 잼 → (425,48)-(489,80)(예전 값은 25px 왼쪽). Config.luau 주석은 이미지 개발 몫.
- push가 갈라짐으로 막혔던 것은 검수가 공용 main을 origin 위로 rebase해서 해결(9783b01 → 5dc69ad). **규칙(검수):** 앞으로 push가 거절되고 작업 트리에 남의 수정이 있으면 `git worktree add <임시 폴더> origin/main`에서 내 커밋만 cherry-pick해 올리고, 공용 main은 건드리지 않는다.
- 브라우저: 이 세션이 창에 열려 있어도 내장 브라우저 창이 좁으면(800px) Firefly가 휴대폰 화면처럼 바뀌어 `sp-picker`가 없음 → `resize_window` 1440×900로 넓히고 생성(턴이 끝나면 풀리므로 생성 동안 턴 유지). 다 쓰면 탭 닫음.
- **사용자 OK(검수 전달): 추천 조합** → `art/ui/JobBoard.png`(1024x647, slice [320,130,704,550])·`JobCard.png`(339x512, 비율 유지)·`BtnKind.png`(512x175, slice [88,54,424,121])·`BtnSneaky.png`(512x171, slice [86,53,426,118])·`JobTag.png`(256x106, 구멍 안쪽 회색 테 → 테두리 색) + approved.json 5키(`layout` 포함) → 이미지 개발에 전달(폰 배치 메모 포함: 폰 749×361은 카드 4장 가로면 글자가 너무 작음 → 2장씩 넘기기나 2×2).

## 오전 2
- 검수 큐: ① 사냥터 게시판 실물 2D(초원·숲) ② 몬스터 말풍선 UI ③ 대장장이·연금술사 아이콘은 장인 업데이트 때(뒤로).
- **a4b978a** 시트 2장 → 검수 대기: `art/review/s2/kit_jobboard_sheet.jpg`(초원·숲 A = 글로만 / B = 교차로 `art/out/hq/HQ_X_NoticeBoard.png`(Firefly 자산 4d3efe50)를 참조로 재질만, 실루엣 겹침 0.93·0.97, 추천 B 둘) · `art/review/s2/bark_bubble_sheet.jpg`(A 흰색+남색 / B 크림+금, 꼬리 왼쪽 아래 9조각 칸, 추천 A, slice A (166,130,893,178)·B (202,134,889,184)). 말풍선 누끼 `art/out/s2/UIP_BarkBubble_{A,B}_cut.png`는 로컬.
- 고른 게시판은 나중에 High로 다시(Tripo용) → 그때 등불 고리 구멍 회색 점·숲 등불 빛 번짐도 누끼에서 정리. 이름: KIT_Meadow_JobBoard / KIT_Woods_JobBoard(MostWantedBoard와 다르게, 이미지 생성 1 요청).
- 요령: Firefly 문구 1000자 넘으면 생성 클릭이 조용히 무시됨 → 1000자 아래로. 참조 이미지 빼기 버튼은 aria-label이 "Remove "(끝에 공백) — `trim()`으로 찾기.
- 요령: push가 갈라졌을 때 임시 worktree는 짧은 경로(예: `C:/Users/glori/Documents/Roblox/Game-push`)에 — scratchpad 경로는 "Filename too long"으로 실패. 다시 하기 전에 `git fetch`(다른 세션이 이미 rebase·push했을 수 있음).
