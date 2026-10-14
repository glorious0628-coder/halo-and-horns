# 메인 반영 1 — 인계 상태

## 10/15 04:30 게시판 4 저장 (사용자가 새벽에 직접 Save to File As)
- build/GoodEvil.rbxlx = place/GoodEvil.rbxlx = 10/15 04:30:59, 45,059,343 B, SHA256 56145ea1…bb98. 소스 178개 일치(main 856a8540, 그 뒤 src 변경 없음), 거위 광장 Model 자식 23, 임시 시험 개체 0, 끝 `</roblox>`. 앞 판(10/14 20:22)을 새 판으로 덮음. 다음 = 사용자 Alt+P.
- Studio: 10/15 00:20 시점 열려 있었음(Edit·미저장·Play 없음), PC 재시작 뒤엔 닫혀 있을 수 있음. 컴퓨터 제어 허락은 이전 설치 경로 Studio에만 걸려 있고 새 경로(packages\claude_…)는 사용자가 거부 → Save As는 계속 사용자 몫.

## 10/14 20:22 게시판 3 저장 (사용자 Save to File As)
- build/GoodEvil.rbxlx = place/GoodEvil.rbxlx = 10/14 20:22:13, 44,969,519 B, SHA256 ecebfac6…c63b, push b52d2c4. 소스 179개 일치(main c7c3505a), 임시 시험 개체 0, 끝 `</roblox>`. 앞 판(13:44)을 새 판으로 덮음. 다음 = 사용자 Alt+P.

## 10/14 밤 (게시 준비 sync 대기)
- **Studio**: 메인 창 = build/GoodEvil.rbxlx로 연 것(id 가변; list_roblox_studios, 창이 최소화되면 3D가 하얗게 찍히니 ShowWindowAsync 9로 복원), Edit, Play 없음, **저장 안 함**, main c7c3505a(= HEAD d05c8413 src 동일) sync 완료. build/·place/ = 13:44:07 판(소스 0703bbdd 시점).
- **다음**: 사용자 Save to File As build/GoodEvil.rbxlx('저장했어') → 시간(sync 뒤)·해시·소스 대조(`py build/p2_cmp.py <rev>`, git 무시 — 없으면 CDATA Source를 git show <rev>:src/...와 sha1 대조) → place/ 복사 → `py tools/push_paths.py -m ...` → 사용자 Alt+P. 무기 메시 Model→MeshId/TextureId(build/weapon_mesh_ids.json)는 최종 검수가 build/weapon_model_ids.json 만든 뒤.
- **알아둔 것**: push 때 .git/index.lock 찌꺼기가 가끔 남음(git 프로세스 없으면 rm). push_paths에 디렉터리 인자는 파일을 안 올림(파일 목록으로). 사진 스크립트: tools/play_publish2~7_photos.py(+phone). 임시 번역표는 LocalizationService 아래(ReplicatedStorage 아님), 시험 뒤 꼭 지움. 새 저장은 Crossroads 대장간에서 시작(A23-188).

## 10/14 13:30 게시판 2 저장 (사용자 Save to File As)
- build/GoodEvil.rbxlx = place/GoodEvil.rbxlx = 10/14 13:29:46, 44,746,759 B, SHA256 d8cb0d3e…d8fb, push 39a078e. 소스 176개 일치(main 5fb03ad0 = sync 판), 임시 시험 개체(TmpKoTest·TmpMainApplyTest) 0, 끝 `</roblox>`. 앞 판(83173b9e…, 12:24)을 새 판으로 덮음. 다음 = 사용자 Alt+P.
- 번역 시험 기록: 임시 LocalizationTable을 LocalizationService 아래에 두면 HUD가 한국어로 그려짐(코드 정상, publish3/ko_local.png) — 게시본 영어는 클라우드 표에 글이 없어서(최종 검수 판단).

## 10/14 12:25 게시판 저장 (사용자 Save to File As)
- build/GoodEvil.rbxlx = place/GoodEvil.rbxlx = 10/14 12:24:26, 44,728,640 B, SHA256 83173b9e…cd18, push 13c7098. 소스 176개 전부 일치(main 4204aa30 = HEAD src, 스크립트 Source 대조 missing 0), 끝 `</roblox>` 확인. 대조 스크립트 build/p2_cmp.py(git 무시). Studio 열림·Edit. 다음 = 사용자 Alt+P, '게시함' 오면 Creator Hub 기록 확인.

## 10/14 낮 (게시 앞 sync + Play 사진, 최종 검수 신청 OK)
- **Studio**: build/GoodEvil.rbxlx(10/13 23:28:22 판)로 다시 열었음(전 Studio는 홈 화면이라 새로 염, id 58a04fbe…), Edit, Play 없음, 창 앞에 둠, StudioFreshSave=true, **저장 안 함**. 코드 = main 30b7a13e sync(새로 쓴 스크립트 36). Save As = 사용자(최종 검수 판정 뒤).
- **사진**(docs/art/verification_2026-10-14/publish2/): pc/(first_look 3장+log), phone/(844 first10 11장), new/(마을 기금 카드·설정 창 아래 줄(피해 숫자·남 이름표)·이름표 VIP 왕관 있음/없음 + log). 콘솔 오류 0(DataStore 안내만).
- 새 시험 스크립트 tools/play_publish2_photos.py(분수로 텔레포트 → FundOpen 보냄, OpenPanel Settings, PassVIP 켜고 끄고 이름표 사진; KEEP=1이면 Play 안 끔).
- 참고: 마을 기금 카드는 분수 반경+8 밖이면 곧 닫힘(설계대로) — 시험은 FundSpot_Halo 옆으로 텔레포트 후 연다. 내 이름표는 서버가 나에게 숨김(PlayerToHideFrom) — 사진은 그 속성을 시험용으로 풀어서 찍음.
- 다음: 최종 검수 판정 → 사용자 Save to File As build/GoodEvil.rbxlx → 시간·해시 확인 → place/ 복사 → push_paths → 사용자 Alt+P.

## 10/14 아침 (Studio 열기·sync·사진 3종)
- **Studio**: build/GoodEvil.rbxlx(10/13 23:28:22 판)로 열림(id 73c64908…, list_roblox_studios), Edit, Play 없음, 창 최소화, StudioFreshSave=true, **저장 안 함**(Save As = 10/16 저녁 사용자). 코드 = main 89255e8b sync(스크립트 12 새로 씀·161 그대로).
- **사진**(docs/art/verification_2026-10-14/): comeback/(PC+phone 5장씩), phone_first10/(844·phone 11장씩), first_look_1014/(pc_01~03; menu_one_line/ 덮어쓴 것의 복사). 콘솔 오류 0.
- 눈에 띈 것: 두 comeback 모두 `back line: no bubble`(Returned 말풍선 안 뜸, 최종 검수가 사진 보고 판정). phone first10 로그에 cut 2 / overlap 1~4 숫자 있음(판정은 최종 검수).
- 다음: 최종 검수 요청대로. 10/16 저녁 Save As는 사용자.

## 10/14 새벽 정리 (사용자: 컴퓨터 끔 — 최종 검수 전달)
- **저장 기준:** build/GoodEvil.rbxlx = place/GoodEvil.rbxlx = 10/13 23:28:22, 44,601,218 B, SHA256 63f4aa56941e…daf5, push 956e521, 소스 = main 75890afd(src 173개 전부 일치). 그 뒤 병합(4baa63e6 메뉴 한 줄 2 등)은 저장 안 된 sync. Studio는 Edit·Play 없음·저장 안 함, 컴퓨터 꺼지면 사라짐.
- **다음 일(내일 아침, 3줄):** ① Studio가 다시 열리면 로그인 확인(PC 재시작 때 로그인이 풀려 사용자가 눌러야 했음), 열기는 build/GoodEvil.rbxlx 인자 실행 뒤 list_roblox_studios로 id(창 제목이 "헤일로 & 혼스 (placeId: 81671223175574)"로 바뀔 수 있음, studio_mcp MAIN_NAMES에 이미 포함). ② `py tools/push_paths.py --sync` → 0 0 확인 → `HH_MAIN_STUDIO=1 STUDIO_ID=<id> py tools/sync_to_studio.py` → `py tools/play_phone_round_photos.py first10` + `py tools/play_first_look_photos.py`(결과는 menu_one_line/에 덮어쓰므로 끝나면 새 폴더로 복사) + build/mainapply_2026-10-09b/play_first10_1013.py(PC 첫 10분, git 무시). ③ 저장은 컴퓨터 제어 권한이 계속 거부(user_denied)라 사용자가 직접 File → Save to File As → build/GoodEvil.rbxlx(rbxlx, 44MB XML)로 저장(Ctrl+S는 build/헤일로 & 혼스.rbxl 바이너리로 감 = 우리 형식 아님) → '사용자 저장함' 오면 시간·해시·소스 173개 대조(py로 CDATA Source 비교) → place/ 복사 → push_paths.
- **알아둔 것:** search_asset은 제작자 필터 없음(덤불 후보는 최종 검수에 보고 끝, "Roblox"+보이지 않는 글자 계정은 사칭). 큰 지도 b 업로드 id rbxassetid://114107691990380(개발 1 적용, asset_ids.json엔 안 적음). 시험 스크립트: build/mainapply_2026-10-09b/play_first10_1013.py·play_first_look2.py(git 무시), tools/play_first_look_photos.py·play_phone_round_photos.py first10.

## 10/13 낮 (자가 클리어 직전)
- **Studio**: build/GoodEvil.rbxlx(10/12 18:41 판) 셸로 열림(Get-Process RobloxStudioBeta MainWindowTitle -like '*GoodEvil*'; id는 list_roblox_studios로, 지금 205d8933…), Edit, Play 없음, 창 최소화(ShowWindowAsync 6), 기기 흉내 default, StudioFreshSave=true. 코드 = main 56c19428 sync(C2 드롭표·도감 화면·폰 Hero·무기 들기 Tool 포함) — **저장 안 된 sync**. 다른 세션의 WorldKit.rbxlx Studio도 따로 떠 있음(안 건드림).
- **화면 조작 규칙(최종 검수 10/13 재공지)**: 창 복원·Play 앞으로·마우스·키보드는 **매번** 최종 검수에게 "메인 반영 1 / 무엇 / 몇 초" 신청 → "전달함, 시작" 받은 뒤에만. 미리 준 OK는 취소됨. 끝나면 창 최소화 + "끝".
- **Save As 대기**: 컴퓨터 제어 권한(robloxstudiobeta.exe)을 사용자가 앱 창에서 누르는 순서. 최종 검수가 "전달함, 시작" 주면: 창 앞으로 → File → "새 이름으로 활성 로컬 파일 저장"(위 10/12 점심 절차) → build/GoodEvil.rbxlx(rbxlx 형식) → 시간·SHA·`</roblox>` 끝 확인 → place/ 복사 → push_paths. 저장 전 build/ 18:41(SHA 4b81750e…)와 place/ 14:53(e68e7e5a…)는 새 스크립트 5개만 다른 것으로 확인됨.
- **오늘 통과한 촬영·시험(10/12~13)**: 무기 9종 들기·활 연사·거위 Leave·도감 서버·도감 화면(main/main2/main3)·폰 사진(phone_round·_hero2·_codex2)·C2 Prince 드롭. 시험 스크립트: build/mainapply_2026-10-09b/play_codex.py·play_prince.py·play_phone_codex2.py·play_phone_hero2.py(git 무시), tools/play_codex_photos.py·play_phone_round_photos.py·play_bow_rapid.py·play_tool_grip_ours.py(모두 끝에 StudioFreshSave true 유지).
- **다음 일**: 최종 검수가 병합 알림 주면 `py tools/push_paths.py --sync` → `HH_MAIN_STUDIO=1 STUDIO_ID=<id> py tools/sync_to_studio.py` → 요청한 시험.

## 10/13 새벽 정리 (사용자 "정리하고 컴퓨터 꺼줘" — 최종 검수 전달)
- **Studio**: Edit, Play 없음, 창 최소화, **저장하지 않음**. 코드는 main 310abb37·0aa6a0b7(도감 서버·저장 v5)까지 sync했지만 **저장 안 된 sync**: Studio가 꺼지면 사라짐 → 다음엔 build/GoodEvil.rbxlx를 열고 `py tools/push_paths.py --sync` → `py tools/sync_to_studio.py` 다시.
- **build/GoodEvil.rbxlx**(18:41, 44,422,837 B, SHA256 4b81750e09fd…) = place/(14:53, e68e7e5a01a7…, f1928aad)와 구조 비교로 새 스크립트 5개(GooseEggs·GooseSquare·BubbleUI·HeroPreview·StickerUI)만 다름 → 안전. **place/ 는 그대로**(둘 다 덮어쓰지 않음).
- **남은 일**: Save As(build/GoodEvil.rbxlx → place/ 복사·push) — 컴퓨터 제어 권한을 사용자가 앱 창에서 한 번 거부함(10/12 밤) → 최종 검수가 사용자 허용을 받은 뒤 "전달함, 시작"을 주면 신청. 권한 요청은 robloxstudiobeta.exe 이름으로.
- **통과한 것**: 무기 9종 들기·활 연사·거위 Leave(10/12), 도감 서버 Play(콘솔 0, CodexCards 0→1, Slime 99→100 Stage 2, BankGold 0→60). 시험 스크립트 build/mainapply_2026-10-09b/play_codex.py(git 무시).

## 10/12 밤 (최종 검수 통과까지)
- **Studio**: build/GoodEvil.rbxlx 셸로 열림(id는 list_roblox_studios로, 지금 633b22a6…), Edit, Play 없음, 창 최소화(ShowWindowAsync 6; 복원 9 + SetForegroundWindow). 코드 = main 310abb37 sync본(무기 들기 Tool + Leave 폭). **저장은 아직 안 함**(Save As = 도감 서버 병합 뒤 한 번에, 최종 검수가 부름; 마지막 저장 f1928aa 소스 74f1dd79 판).
- 끝난 촬영(통과): docs/art/verification_2026-10-12/main_apply/ classic_sword/·goose_square4/·5/·tool_basics_r15b/·tool_grip_ours/(9종)·bow_rapid/. 컴퓨터 제어(창 복원·최소화)는 사용자 상시 지시(10/12 22:30)로 최종 검수에 "메인 반영 1 / 무엇 / 몇 초" 보내고 "전달함, 시작" 받으면 바로.
- 도구(tools/, 모두 push): play_bow_rapid.py(연사·초상화), play_tool_grip_basics.py(HH_KINDS·HH_SKIP_USER), 모든 play_*.py 끝은 StudioFreshSave를 true로 유지(nil로 지우지 않음).
- 교훈: 창 최소화 상태 사진 = 흰·회색 화면(창 탓 확정) → 사진 전엔 꼭 복원.

## 10/12 저녁 정리 (사용자 지시 "모든 세션 다 여기까지만 하고 정리")
- **메인 Studio**: GoodEvil.rbxlx(id는 list_roblox_studios로, 지금 ace67cec…) **Edit, Play 없음, 창 최소화**(PowerShell ShowWindowAsync 6; 복원은 9 + SetForegroundWindow). 셸로 열었음: RobloxStudioBeta.exe "build/GoodEvil.rbxlx". 사진 찍을 땐 창을 **복원**해야 함(최소화/가림 = 3D 흰·회색 화면). 긴 촬영 중 뷰가 흰색으로 바뀐 적 있음(tool_basics r15 20장).
- **저장 상태**: build/GoodEvil.rbxlx = place/ = 10/12 14:52:20, 44,262,615 B, SHA256 e68e7e5a01a730b0…, push f1928aa, **소스 74f1dd79 판**. 그 뒤 병합(56ad3014 팔·ca99cc69 거위·d4c7c3be 팔 진짜 원인·77b27f50 새내기 등)은 **저장 안 된 sync**: Studio 코드는 main fa559ed7 부근까지 sync됨(src 마지막 sync 680316db 이후 변화는 `py tools/sync_to_studio.py`로).
- **끝난 촬영**(docs/art/verification_2026-10-12/main_apply/): staff_front_v3f/·v4/(세 마법사 앞·옆·합본), charui/(캐릭터 창 12장), arm_probe/(값 + Motor6D 0개 발견), arm_check/·arm_check2/·arm_check3/(직업×진영 팔), arm_rig/(숫자 로그, 사진 흰 화면), tool_grip/·tool_grip2/(칼·지팡이·활 우리 vs 로블록스 Tool), tool_basics/(7종 기본 Tool, **r15_baton·flaskstaff·hammer·staff 20장 흰 화면**), goose_square/·2/(사진 + 값)·3/(클라이언트 카메라 값, 창 최소화라 사진 무의미).
- **거위 광장 서버 확인 결과**: Edit 상태 place에 workspace.GooseSquare 없음; Play 중 Join 후 생김(BuiltBy=GooseSquare, 11 BasePart: Floor 6000,198,6000 110×4×90 투명0, 벽 4개 투명1 충돌, Spawn·Cart·Nest·GooseSpot 투명1). 새내기 Join/Leave·InGooseSquare true↔false 정상. 클라이언트: 카메라 Custom·Humanoid 추적 정상, 안개·조명 정상, 화면 덮는 GUI 0개 → 회색 사진 = 창 상태 영향 추정(창 복원 상태로 재촬영 필요).
- **안 끝난 것**: ① `play_classic_sword_grip.py`(개발 1이 2aa7de25에서 서식 오류 고침) 아직 안 돌림 → `HH_MAIN_STUDIO=1 py tools/play_classic_sword_grip.py classic_sword`(창 복원 후). ② tool_basics r15 4종 재촬영(개발 1이 사진 보고 필요하면 요청). ③ goose_square 창 복원 상태 재촬영. ④ Save As(저장 안 된 sync 반영) — 최종 검수 "전달함, 시작" 뒤.
- **새 도구**(tools/): play_mage_staff_photos.py(세 마법사, screen_capture camera_position 인자로 카메라), play_character_ui_photos.py(캐릭터 창), play_arm_probe.py, play_goose_square_photos.py(Join/Leave + GooseSquare 읽기 + 클라이언트 카메라 읽기), 개발 1 것: play_arm_check_photos.py·play_arm_rig_probe.py·play_tool_grip_compare.py·play_tool_grip_basics.py·play_classic_sword_grip.py.
- **교훈**: ① 사용자에게 컴퓨터 쓴다고 직접 알리고 시작(최종 검수 말만 믿지 말 것, 사용자 화냄 10/12). 창 복원·최소화는 PowerShell로(마우스 X). ② 공유 트리가 다른 세션 수정 중이면 `git reset --keep`이 막힘 → git update-index --refresh 뒤 재시도. ③ push_paths는 새 폴더째 주면 "변경 없음" 나올 수 있음 → 파일 하나씩. ④ Game 창 찾기: Get-Process RobloxStudioBeta MainWindowTitle -like '*GoodEvil*'.

## 메인 Studio 상태 (2026-10-12 낮 11:00, 3번째 메인 반영 1 → 다음에게; 스스로 clear 함)
- 창: Edit, Play 정지, StudioFreshSave=true. 창 id는 열 때마다 바뀜 → `HH_MAIN_STUDIO=1 py tools/studio_mcp.py call list_roblox_studios '{}'` 후 `STUDIO_ID=<id>`(지금 b2281643-ef9b-4501-8753-69c024b67d0f). 이름이 "헤일로 & 혼스 (81671223175574)" 또는 "Darugi_S2의 장소: 10122026_1 (79345022650204)"로 번갈아 보일 수 있음 — 사용자 답 "무시해도 돼"(설문 다시 하려고 만든 것). **Ctrl+S·Save to Roblox·Publish 절대 금지**(클라우드가 새 place로 감), 저장은 Save to File As build/GoodEvil.rbxlx만. studio_mcp MAIN_NAMES·AGENTS 규칙 3은 최종 검수가 고침(건드리지 말 것).
- 코드: Studio는 main **5b1a2f96**(A23-142 지팡이 0.7배) sync본(그 뒤 shared HEAD는 0ee15714 이상, src 새 변화 있으면 `py tools/push_paths.py --sync`(공유 트리가 다른 세션 수정 중이면 reset --keep이 막히므로 이걸 씀) 뒤 `py tools/sync_to_studio.py`).
- 천 HH_Fabric v3b ID(Color 130243612742018·Normal 78044174442027·Roughness 111200474370652)는 파일에 저장됨. Studio를 닫았다 클라우드에서 다시 열면 v1이 되니 execute_luau(Edit)로 이 3개를 다시 넣을 것(v2 되돌릴 값 76316272601072 / 102973991596175 / 119858177335377).
- **마지막 저장**: build/GoodEvil.rbxlx 2026-10-12 10:41:15, 44,082,577B, SHA256 bacdbf24…58e6 = place/GoodEvil.rbxlx (push **6e8b2600**), 소스 ecde46c6 판. 그 뒤 병합(5b1a2f96 지팡이 짧게 등)은 아직 저장 안 됨 → 최종 검수 "전달함, 시작" 받으면 저장(이번 묶음엔 '저장 안 해도 됨'이라 했음).
- 보고처: **최종 검수**(list_sessions 제목 "최종 검수"), 마법사·그림 사진은 **디자인 검수**에도, 게임성 관련은 **게임성 검수**에도 사본.
- 시험 스크립트(build/mainapply_2026-10-09b/, git 무시, 헤더는 tools/play_main_checklist.py exec): play_staff_short.py/play_staff_hip.py(세 마법사 앞·옆·손·계단·걷기·T1/T7), play_e27.py(PvP 카드·Hero 칸·계단 지팡이), play_text1012.py(서버 글: 강화·보스·물약·거위), play_puddle.py, play_bag_main.py, play_r1012a.py(모루 G·재료 팔기), play_chip.py, play_spawn.py, play_merge11*.py. 시험 Play는 늘 끝에 멈추고 StudioFreshSave=true 유지.
- 저장 요령(마우스·키보드, 최종 검수 "전달함, 시작" 뒤에만): ① PowerShell SetForegroundWindow로 메인 창을 앞으로(창 제목 "헤일로*"). ② 컴퓨터 제어 권한은 `robloxstudiobeta.exe` 이름으로(앱 이름 "Roblox Studio"는 창이 마스크됨; 이미 승인돼 있으면 재사용). ③ File 메뉴(22,42) → 마우스를 (108,333)에 올려 툴팁 "새 이름으로 활성 로컬 파일 저장" 확인 → 클릭. ④ 저장 창이 열리면 **스크린샷으로 위치 확인**(창 위치가 ±8px 바뀐 적 있음): 형식 드롭다운 → "Roblox XML 플레이스 파일 (*.rbxlx)" 고르기, 이름 칸 삼중클릭·Ctrl+A·"GoodEvil" 입력 → 자동완성 목록의 "GoodEvil.rbxlx" 클릭 → Enter → 덮어쓰기 "예". ⑤ 끝나면 시간·SHA·`</roblox>` 끝·PackageLink 99 확인 → place/ 복사 → py tools/push_paths.py -m "…" place/GoodEvil.rbxlx → "끝".
- 알게 된 것: 이 Bash 도구는 가끔 PATH가 깨짐 → `export PATH="/usr/bin:/bin:/c/Users/glori/AppData/Local/Programs/Python/Launcher:/c/Users/glori/AppData/Local/Programs/Python/Python313:/c/Program\ Files/Git/cmd:$PATH"`. 모루 G 프롬프트는 Map.Landmarks.ArtisanGuild.Anvil(NPC Otto 아님), 진짜 키(user_keyboard_input keyDown/keyUp)만. Q는 퀘스트 장부, Z가 첫 스킬. 첫 미션 뒤 Hallie "Lost Lunchbox!" 모달이 카드를 막음 → 시험 땐 DebugCommand StoryDone "Lunch1". HUD Hero 칸은 자물쇠(창 없음). 옮기기(Transfer)·무법자 주 시작 줄은 아직 못 봄(다음 기회).

## 오늘 한 일 (사진: docs/art/verification_2026-10-11/main_apply/)
skillbook/·skillbook_lv5/·skillbook_v2/·skillbook_v3/(스킬 창), ground_bridge/(다리 위 스킬 원), twohand_horns/·twohand_horns2/·twohand_v2/·twohand_v2b/(grips9/ 포함)·twohand_v3/(쥐기), twohand_mage/(Lv25 마법사 창), halo_light_c2c/(낮·밤), halo_entrance/·halo_entrance2/(입구 전체).
- 시험 스크립트(git 무시): build/mainapply_2026-10-09b/ play_skillbook.py, play_bridge.py, play_twohand.py, play_grips_v2.py(9조합+GripProbe), play_v3.py(마법사+조명+입구; SKIPGRIP=1). **임시 Tmp 스크립트 없이 execute_luau 직접**(캐릭터 시험: Level·SkillSlots·WeaponTier 속성을 서버에서 올림, 조합 변경은 Faction/Class 속성, 조명은 `ServerScriptService.DebugCommand:Invoke("", "Clock", 시)`, 이동은 VISIT(x,z,yaw)).
- 알려진 것: 직업 id는 Warrior/Mage/Archer뿐(연금술사 = Mage+Neutral, 대장장이 = Warrior+Neutral, 조련사 = Archer+Neutral). "Alchemist"를 Class로 넣으면 Warrior로 떨어짐(개발 1 설명). 연금술사 사진은 twohand_v2/grips9/Neutral_Mage_front.png(probe Mage_Neutral: Right dGrip=0.00).

## 큐 (10/11 밤)
0. 곧 검수가 병합 4개(한손검 후속·가방·채집·제작 꺼짐) 보냄 → sync·PC Play 사진·콘솔·저장. 시험 스크립트: build/mainapply_2026-10-09b/play_merge11.py(첫 미션·사냥), play_merge11b.py(거위·쉼 카드·PvP 카드, PVP_ONLY=1 가능). 사진 docs/art/verification_2026-10-11/main_apply/merge_a23130*/.
1. 새 검수가 병합한 뒤 sync 부탁 → sync·Play 오류 0·사진.
2. 새 빛 마을이 메인에 들어간 뒤: 처마 밑 비 + 밤 등불 사진, 문·계단·다리·분수·간판 확인.
3. 저장(검수 OK 뒤): Save to Roblox + Save to File As `build/GoodEvil.rbxlx`(rbxlx), 시간·해시 → `place/` 복사 → `py tools/push_paths.py`.

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
