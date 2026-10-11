# 게시(Publish) 체크리스트 — 검수 관리 (2026-10-08 시작)

게시는 **사용자 OK 뒤에만** 한다(AGENTS 규칙 3). 아래 줄은 그 게시에 들어가는 묶음마다 확인한다.

## ⚠ 16세 미만에게 열기 — Roblox Kids·Select (검수 2026-10-08, 공식 문서 직접 확인)
출처: https://create.roblox.com/docs/production/publishing/kids-and-select (+ DevForum 2026-06-16 공지, rpg_success_analysis_2026-10-08 [127][128]).
- 지금 Roblox는 16세 미만(Kids 5~8, Select 9~15) 계정에게 **평가를 통과한 게임만** 보여 준다. 새 게임은 먼저 **나이 확인된 16세 이상에게만** 보인다(시험 단계).
- [ ] (사용자) 만든 계정 **정부 신분증 나이 확인**(18세 이상) — 16세 이상 공개도 나이 확인 필요.
- [ ] (사용자) **2단계 인증** 켜기.
- [ ] (사용자, **12/1 베타 때**(A23-119; 옛 10/31)) **사용자 선택(A23-82): 돌려받는 보증금(약 1,000 Robux)** — 신분증 나이 확인·2단계 인증도 같은 날. 참고(안 고른 길): Roblox Plus/Premium 2달 연속 유지 **또는** 게임마다 한 번 내는 돌려받는 수수료(포럼 기준 1,000 Robux, 문서엔 금액 없음). 무료 Plus 6개월을 받은 경우는 유지하는 동안 수수료 없음(포럼).
- [ ] (사용자) **성숙도·준수 설문**(Maturity & Compliance Questionnaire). Kids = Minimal·Mild, Select = Moderate까지. 우리 게임(판타지 전투, PvP 구역, 현상수배)이 어느 등급이 되는지 설문 답을 검수가 미리 정리.
- [ ] **평가 기준:** 60일 안에 '열심히 하는' 나이 확인된 16세 이상 플레이어의 **고유 플레이 250회** → 그 뒤 Kids·Select에 열림. Creator Hub의 Audience Reach 대시보드에서 진행 확인.
- 뜻: 12/1 베타 첫 손님은 16세 이상뿐. 13~15세 친구 초대(A23-79 #3)는 자격 전에는 못 들어옴. 빠른 심사(50,000 Robux)는 우리에게 해당 없음.

## 이번 묶음: 무기 먼저(A23-74) + 스탯 1단계(스위치 꺼짐) + 소리 서버
- [ ] **모든 서버 종료**: TutorialStep 3(대장간 단계)을 쓰는 저장을 옛 빌드가 읽으면 3을 99로 바꿔 첫 임무를 건너뛴다(dev2 검토 minor 1, `docs/design/weapon_first_server_2026-10-07.md` §6). Creator Dashboard → 체험 → 서버 → "모든 서버 종료"는 사용자가 누른다.
- [ ] dev2-sound와 wtc-weapon-client가 **같은 라운드**에 들어갔는지(따로 들어가면 새 플레이어가 대장간 단계에서 길을 잃음).
- [ ] 저장 Version은 3 그대로(스탯 Stats는 더하기 필드).
- [ ] 메인 Studio에서 PC·폰 직접 Play 사진: 진영·직업 → ~~대장간 앞 착지~~ 걸어서 Otto's Forge(자동 이동 없음, A23-88) → 모루 → 첫 무기 → 빛나는 이동 판 또는 지도 Travel로 초원 → 슬라임 5 → [Claim] 150골드(A23-74 검사 규칙).
- [ ] place/GoodEvil.rbxlx = build/GoodEvil.rbxlx(시간·해시), src와 같은지.
- [ ] 화면 글자 한글 0개: `py tools/test_place_english.py`(30ccc2d 고친 판). (한국어 모드(A23-111)가 들어가면 이 시험은 '영어 기본 상태에서 한글 0개'로 좁혀야 한다 — 그때 검수가 고침.)
- [ ] Creator Dashboard 한국어 자동 번역 끄기(사용자).
- [ ] Config.Features.StatPoints = false(스탯 2단계 검토 전)인지.
- [ ] 새 계정 흐름 세부(개발 2): ~~[Accept] → 3초 페이드 → 교차로 모루 앞 착지 → E/탭~~ → [I'm In!] 뒤 "Go to Otto's Forge" 줄 따라 걸어감(서버가 옮기지 않음, A23-88; 도착 = 모루 24스터드 안, `Config.Tutorial.Forge.Near`) → G/탭(상호작용 키 G, A23-78) → "Otto: …" + 첫 무기 Power 0 → N(Stronger!) → ~~3초 뒤 초원~~ "Travel to Squishy Meadow" — 빛나는 이동 판 또는 Map → Travel → 슬라임 5 → [Claim] 150골드 → M1_1 대장간에서 상점 창. ~~착지가 이상하면 Config.Tutorial.Forge.Landing = "Spawn".~~ (Landing 설정은 없어짐, A23-88)
- [ ] `py tools/test_place_english.py --place build/GoodEvil.rbxlx` passed(자체 시험 포함).
- 지금 날짜(A23-119): 비공개 게시 시험 10/17~20 · 기능 마감 11/24 · 공개 베타 12/1 11:00 KST(장인 길드 포함) · 정식 2027년 1월 말. 호박밭·유령 숲은 숨김(배지 'Halloween 2026'은 아래 참고).
- 문서: dev2-sound 892fa28에서 stat_points·stats_server의 버전·서버 종료 문구 정리됨.

## 수익 상품(A23-75, 2026-10-08) — 게시 때 사용자
- [ ] Creator Dashboard → 수익 창출 → **게임 패스** 만들기: 경험치 2배, 골드 2배, VIP, 진영 치장(고른 것) — 가격은 사용자가 정한 값. 아이콘 512×512(이미지 생성 2).
  - 패스 페이지의 **설명**은 `Config.PassInfo`의 `Desc`(XP2·Gold2·VIP·Look·PrivateServer)를 그대로 붙여 넣는다(쉬운 영어, 하는 일만 적었다: VIP 이모트는 아직 없어서 약속하지 않는다). 상점 카드 한 줄은 `Line`. 숫자(2x)와 말이 어긋나지 않게 `py tools/test_pass_text.py`가 지킨다.
- [ ] 나온 패스 ID를 Config(게임 패스 표)에 붙여 넣기(ID 0이면 버튼 "Coming soon").
- [ ] **개인 서버** 켜기 + 월 가격(사용자).
- [ ] (A23-90) 10/17~20 비공개 게시 시험 때는 패스를 **판매 끈 채 ID만** 만들어 붙여 넣기. 게시 버튼은 사용자.
- [ ] ~~변경권 Developer Products 2개(GDD §10) ID도 같이.~~ → 변경권은 베타에서 팔지 않음, 정식 전에 만듦(A23-28).

## 저장소 환경(ops_safety ⑧, 2026-10-09) — 게시 때
- [ ] Beta 장소·Live 장소를 게시한 뒤 각 장소 id를 `Config.Env.Names`에 `"Beta"` / `"Live"`로 넣고(`Names = { [<장소 id 숫자>] = "Beta", … }`) 같은 코드를 올린다. 안 넣으면 그 장소가 `Dev`로 보여 개발 저장소를 쓴다(`docs/design/ops_safety_server_2026-10-09.md` ⑧).
- [ ] Beta·Live는 **빈 저장소에서 시작**(검수 기본값 — 시험 때 얻은 후광·뿔·골드가 실제 게임에 섞이지 않게). 옛 시험 저장을 옮기려면 사용자가 따로 정한다.

## 다시 오게 만들기(A23-79) — 게시 때 사용자
- [ ] Roblox 배지 8개 만들기(하루 5개 무료 → 이틀에 나눔), 나온 배지 ID를 Config에 붙여 넣기.
  - 배지 그림: `art/ui/Badge*.png`(이미지 생성 2, 512 원형 — 고른 것: Chose a Side A·First Slime A·Lost Lunchbox A·Stronger! B·First Skill A·Shard Choice A·Rank 2 A·Halloween 2026 A, 시트 art/review/s2/badges_private_sheet.jpg). **A23-119(10/11): 호박밭·유령 숲이 숨어서 'Halloween 2026' 배지는 지금 만들지 않아도 된다**(배지 7개면 된다; `Config.Badges.Ids.Halloween2026`은 0 그대로 = 안 물어봄. 철을 다시 켜는 날 만든다 — `docs/design/halloween_hidden_2026-10-11.md`). 개인 서버·게임 패스 그림 = `art/ui/PassIcon*.png`.
- [ ] (베타 뒤 첫 업데이트 때 — 옛 '11/09'는 핼러윈 끝 날짜라 낡음, A23-119) Experience Notifications 문구 틀 + Open Cloud 키(Secrets) — 키는 채팅에 붙여 넣지 않기.

## 게임 페이지 영상·업데이트 표시(뜯어보기 2026-10-10, docs/design/roblox_teardown_2026-10-10.md §4)
- [ ] 게임 페이지 플레이 영상 30~60초: 지금 게임 안 모습만(해설·글·가사 음악·예고편 없이). 11/24 기능 마감 직후(A23-119; 옛 10/24) 베타 화면으로 촬영 편집이 찍고(촬영 편집 세션은 쉬는 중이라 그때 검수가 만든다), 사용자가 Creator Hub → Videos에 올림(심사 시간 여유). 홈 추천 칸에서 바로 재생돼 플레이가 늘어남(DevForum 홈 공지).
- [ ] 베타 뒤 매주 수요일 업데이트(A23-83) 때 게임 이름·설명 첫 줄에 사실만 짧게(예: "OUT NOW: …") — 사용자가 Creator Hub에서.

## 출시 날 운영 한 장(시스템 점검 더하기 8, 2026-10-09) — 사용자가 한 번씩
- [ ] **되돌리기 연습 1번**(게시하기 전 Beta 장소에서): `docs/ops/launch_day_runbook_2026-10-09.md` §2의 다섯 칸(화면 이름·시간·새 필드가 남는지)을 적는다 — 결과가 "새 필드가 사라짐"이면 S0 되돌리기는 위험하니 스위치로 끄는 길을 먼저 쓴다(검수에게 알림).
- [ ] **문제 등급표 S0~S3**(같은 문서 §1)를 한 번 읽는다. 돈·저장은 늘 S0, 스위치(`PassSales`/`Halloween`/`CrownWar`/`Goose`)가 첫 행동.
- [ ] **시간별 점검표**(같은 문서 §3): 출시 T-60분 ~ T+24시간. `Errors live`와 `Health live`는 Studio Play 중 명령창(§0).
- [ ] 건강 보고 문서가 쌓이는지 Beta 첫 시험 때 `Health live`로 한 번 확인(`docs/design/health_report_server_2026-10-09.md`) — Studio Access to API Services가 켜져 있어야 읽혀요.
