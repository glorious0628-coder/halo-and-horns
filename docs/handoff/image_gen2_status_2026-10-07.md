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

## 오전 3
- 사용자 OK(검수 전달): 게시판 실물 **초원 B + 숲 B**, 말풍선 **A**.
- **8e517a6** `art/ui/BarkBubble.png` 512x190 + approved.json `BarkBubble`(slice 84,65,446,89 · Text) → 이미지 개발 업로드 a3fc2ea(124351323911597, SliceScale 0.3). E11 5장도 업로드 4da02d3, 폰 게시판 = 카드 2장씩 넘기기(이미지 개발).
- **ffe806d** 게시판 고급(High, 약 10크레딧) 2D: 원본 `art/out/hq/HQ_{Meadow,Woods}_JobBoard.png`(Tripo용, 회색 바탕), 누끼 `art/out/kit/{meadow,woods}/JobBoard.png`(고리 구멍 회색·빛 번짐 정리), 시트 `art/review/s2/kit_jobboard_hq_sheet.jpg` → 이미지 생성 1에 경로 전달. Tripo 비용은 검수가 사용자에게.
- **ffe806d** 진영별 지도 화살표 후보 4장(검수 요청: 사용자 "화살표 더 멋있게, 진영 따라 색·분위기"): 시트 `art/review/s2/faction_map_arrow_sheet.jpg`, 누끼 `art/out/s2/UIP_MapArrow{Halo,Horns}_{A,B}_cut.png`(512 정사각, 로컬). 추천 빛 A(날개) + 뿔 A(위쪽 뿔). 고르면 키 MapArrowHalo / MapArrowHorns → 이미지 개발.
- push 요령: 갈라졌을 때 체크아웃 없이 `git merge-tree --write-tree --merge-base=<c>^ origin/main <c>` → `git commit-tree` → `git push origin <new>:main`(198bdd6 → ffe806d).

## 오후
- **17817e6** 지도 화살표 확정(사용자: 빛 A + 뿔 C1 = 뿔 뺀 빨간 화살표, 검수: 크림 테 추가): `art/ui/MapArrowHalo.png`·`MapArrowHorns.png` 512 정사각(몸통 높이 같음, 가운데 = 회전 중심, 남색 테 바깥 크림 테 20px 4배 그리기), approved.json 2키 → 이미지 개발(칠하지 말고 그대로). 대비 5곳 모두 3:1↑. 스크립트 scratchpad `final_arrows.py`.
- **c51be3f** 게시판 버튼 아이콘 확정(검수, 사용자에게 결과로): `art/ui/GlyphKindWing(.png 256, _64)`·`GlyphSneakyHorns`(뿔 A를 로컬로 흰 라일락 + 남색 테 4px 더 → 날개와 같은 두께) → 이미지 개발. 색약 흉내 시트 `board_btn_icon_sheet.jpg`·`board_btn_horns_fix_sheet.jpg`(scratchpad `btn_icon_sheet.py`·`horns_fix_sheet.py`).
- **5bbfbcc** 고블린 숲 작은 소품 16장 + 빛 버섯 B(`kit_woods.md`, 이미지 생성 1 5a1eec0): `art/out/kit/woods/<이름>.png`(+ _src), 시트 `art/review/s2/kit_woods16_sheet.jpg` → 검수 대기. 빛 버섯 첫 안은 통나무 옹이가 눈처럼 보여 이끼 흙더미로 다시(B 추천). 3D 후보 8종은 고르면 High.
- 브라우저: 사용자 요청으로 Firefly 탭 열어 둠(생성 끝나면 보기 크기 원래대로).
- **a8d7bb3** 숲 3D 후보 8개 고급(40크레딧, 사용자 Tripo 320 승인 — Tripo는 이미지 생성 1): `art/out/kit/woods/<이름>_HQ_src.png`(Tripo 입력) + `<이름>_HQ.png`, 시트 `art/review/s2/kit_woods_hq8_sheet.jpg` → 검수 대기. 통나무 의자 B·고사리 B(중간) 고침. 크레딧: 이 세션 고급 오늘 10장 = 50.
- **새 규칙(사용자, SPEC A23-47 보강 3, 4e65f16):** 고르기용 시안 = 중간, 고른 최종 = 종류와 관계없이 전부 고급(5). 시트마다 쓴 크레딧 + 웹 남은 크레딧. 이미 중간으로 게임에 들어간 것(지도 화살표·버튼 아이콘 등)은 검수가 따로 정할 때까지 손대지 않기.
- 누끼 주의: `cut_kit.py`의 '회색 틈 지우기'는 쇠(통 쇠테·등불 쇠지붕) 반사도 지움 → **쇠가 있으면 `--no-pockets`**, 틈은 좁은 창으로만 지우고 4배로 확인. 숨은 창에서 Firefly를 새로고침하면 화면이 안 그려져 크레딧 숫자를 못 읽음(새로고침은 창이 보일 때만).
