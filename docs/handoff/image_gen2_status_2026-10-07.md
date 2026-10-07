# 이미지 생성 2 상태 (2026-10-07)

이전 기록: `docs/handoff/image_gen2_status_2026-10-06.md`. 크레딧: 오늘 **0**(Firefly GPT Image 2.5 Sunburst, 중간만).

## 오전
- E11 사냥터 게시판 그림 10장 생성(문구 bc474c7) → 원본 `art/out/s2/<Key>_src.png`, 누끼 `<Key>_cut.png`(로컬, 고른 것만 나중에 커밋) → 시트 **`art/review/s2/e11_job_board_sheet.jpg`(5dc69ad)** → 검수가 보고 사용자에게 가져감. 추천: 창 A · 카드 A · Kind B · Sneaky B · 꼬리표 A. 글자 칸 분수는 scratchpad `e11_measure.py`·`e11_sheet.py`의 `LAYOUT`(검수 메시지에도 적음).
- 같은 커밋: QuestRow `sockets.Count`를 실제 그림에서 다시 잼 → (425,48)-(489,80)(예전 값은 25px 왼쪽). Config.luau 주석은 이미지 개발 몫.
- push가 갈라짐으로 막혔던 것은 검수가 공용 main을 origin 위로 rebase해서 해결(9783b01 → 5dc69ad). **규칙(검수):** 앞으로 push가 거절되고 작업 트리에 남의 수정이 있으면 `git worktree add <임시 폴더> origin/main`에서 내 커밋만 cherry-pick해 올리고, 공용 main은 건드리지 않는다.
- 브라우저: 이 세션이 창에 열려 있어도 내장 브라우저 창이 좁으면(800px) Firefly가 휴대폰 화면처럼 바뀌어 `sp-picker`가 없음 → `resize_window` 1440×900로 넓히고 생성(턴이 끝나면 풀리므로 생성 동안 턴 유지). 다 쓰면 탭 닫음.
- **사용자 OK(검수 전달): 추천 조합** → `art/ui/JobBoard.png`(1024x647, slice [320,130,704,550])·`JobCard.png`(339x512, 비율 유지)·`BtnKind.png`(512x175, slice [88,54,424,121])·`BtnSneaky.png`(512x171, slice [86,53,426,118])·`JobTag.png`(256x106, 구멍 안쪽 회색 테 → 테두리 색) + approved.json 5키(`layout` 포함) → 이미지 개발에 전달(폰 배치 메모 포함: 폰 749×361은 카드 4장 가로면 글자가 너무 작음 → 2장씩 넘기기나 2×2).
