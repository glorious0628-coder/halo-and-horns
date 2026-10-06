# 베타 진행판 (검수 세션, 2026-10-06)

원자료: `docs/design/beta_board_2026-10-06.json` (항목 194개, 코드·커밋·증거로 상태 확인). 10/12·10/17·10/20 점검 때 이 판을 새로 고친다.

## 한눈에
개발 세션 1개로는 10/24까지 베타 필수가 약 6일 모자라요. 영어와 Z 스킬을 빼도 그래요.
가장 큰 위험은 두 가지예요. 창 6개·랭킹·펫이 개발 한 명에게 몰려 있고, 그림 승인 속도가 일정을 정해요.
대책은 네 가지예요. 영어는 지금 정식으로 미루고, Z는 꺼 둔 채 베타를 내요. 서버만 맡는 개발 세션을 하나 더 열고, 검증은 10/25~30 테스트 주로 보내요.
오늘 할 일: 개발은 핼러윈을 커밋하고, 검수는 HUD 회색 상자 배치를 만들고, 이미지는 아이콘 승인 시트 1장을 보내요.

## 일할 수 있는 양
개발(게임성) 1세션 기준:
- 남은 베타 필수 개발 일은 약 27일이에요(S=0.5, M=1, L=2, 동기화·플레이 확인 포함).
- 아래 단순화 뒤에는 약 24.5일이에요.
- 일할 수 있는 날은 10/06 오후부터 10/24까지 약 18.5일이라 약 6일 모자라요.
- Z 스킬(약 5.5일)과 영어(약 4.5일)를 넣으면 약 16일 모자라요.
- 10/05에 커밋된 양은 명목보다 많았어요. 하지만 여러 날 작업이 한꺼번에 들어간 것이라 속도 근거로 쓰지 않아요. 10/12에 실제 속도로 다시 계산해요.

개발2(서버 전용)를 10/07부터 열면:
- 개발은 약 16.75일 / 18.5일이에요(개발2 작업 병합 약 1.5일 포함).
- 개발2는 약 10.75일 / 약 17일이에요.
- 둘 다 1.5~2일 여유가 생겨요. Z는 그래도 들어가지 않아요(개발 쪽 Z 버튼·선생님 NPC 약 3일이 남지 않음).

이미지 세션:
- 묶음 1~11과 요청 아이콘(R2·R3·R1F·RANK3)이 약 14일이에요.
- 승인 마감 10/22까지 약 16.5일이라 약 2.5일 여유가 있어요.
- 단, 사용자 승인 약 11번이 거의 매일 와야 해요.

이미지 개발 세션:
- 할 일은 약 14일이에요(G1 재배치 2일, 묶음 적용 약 9일, BM4 HUD 마무리 2일, 정리 1일).
- 일할 수 있는 날은 18.5일이에요.

검증 전용 항목은 10/25~30 테스트 주로 보내요: BM8-D 3명 테스트, BM8-E 저장 안전, LIVE-TEST 2차, PERF-1, A14-2 수치 조정.

## 날짜별 할 일

### 10/06 (화)
- **개발:** [개발] HW-11 핼러윈 반영: Play를 멈춘다고 먼저 한국어로 알림 → sync_to_studio → apply_studio_state 다시 실행(FRONT_FIX) → DebugCommand 'PumpkinKing'으로 직접 플레이(스폰·대왕·칩·알림·사탕 드랍)
- **개발:** [개발] 같은 커밋: 호박 대왕 EventHUD 칩과 상태판 겹침 임시 수정
- **개발:** [개발] 같은 커밋: UIArt.Parts 키 12개(IconMon×5, IconCandy, IconPetBabySlime, 메뉴 5장)와 몬스터별 QUEST_ICON 연결(ART-I0·HW-12). 다시 올리지 않는다
- **개발:** [개발] 경로별 커밋: HalloweenService.luau와 Main.server.luau는 반드시 함께(따로 올리면 서버가 멈춤). BatGoblin 클립 5개, test_halloween.py·fixture·offline_halloween 증거, asset_ids.json도 같이
- **개발:** [개발] Save to File As → 해시 확인 → place/ 커밋
- **개발:** [개발] F10-4 재현 시작: 뿔·마법사 런2가 5/5 뒤 '받기'에서 멈춘 원인
- **이미지·이미지 개발:** [이미지] 승인 시트 1장: R2 고블린 A/B, R3 재료 6장 누끼, 새 주문서 1장(흰색으로 그리고 코드로 색 입힘. 옛 UIP_IconScroll 프롬프트는 쓰지 않음), R1F 단정함 확인, RANK3 3장 생성
- **이미지·이미지 개발:** [이미지 개발] SESS-UISANDBOX 마무리: build/UiSandbox.rbxlx는 09:22에 복사됨. STUDIO_NAME=UiSandbox일 때 studio_mcp와 sync가 메인 Studio를 고르지 않는지 확인
- **이미지·이미지 개발:** [이미지 개발] ART-DEL1: 78개 삭제 목록 작성
- **검수:** ART-G0 layout.json 작성: 1280×720, 749×361, 844×390, 태블릿. [가방][지도][메뉴] 줄, 상태판 전투력 칸, 가방 예약 칸, 높이 560 아래 접기를 넣는다
- **검수:** render_graybox.py로 겹침 0 확인 → 사용자에게 1장
- **검수:** DOC-SYNC: AGENTS Roles를 4세션으로(개발2 승인 시 5), RELEASE_PLAN의 낡은 줄(Tripo '노노', 슬라임 재디자인) 정리, A23-23 추가
- **검수:** ART-DEL1 목록 확인
- **사용자:** 아이콘 승인 시트 1장(폰)
- **사용자:** 질문 답하기: 영어 연기, 개발2 세션, R15만, 그림 승인 리듬

### 10/07 (수)
- **개발:** [개발] F10-4 수정: 뿔·마법사·터치에서 고정 줄이 '받기'로 바뀌고 150골드가 들어오는지 확인
- **개발:** [개발] BB13 시작: Panels.Register(id,{Build,Title,FixedBody,Rebuild,Cleanup}), Open arg 전달, 이전 창 Cleanup
- **개발:** [개발2·승인 시] 핼러윈 커밋 뒤 main에서 git worktree 만들기
- **개발:** [개발2·승인 시] BB37 PublicName(전체 알림 7곳 + 마을 게시판)
- **개발:** [개발2·승인 시] BB12 Tab 열(전투력·레벨·환생·명성, 골드 숨김) + 오프라인 검사
- **이미지·이미지 개발:** [이미지] 묶음 1 스타일 보드 6칸×4안: 승인된 아이콘과 한 장에 모아 저녁에 폰으로
- **이미지·이미지 개발:** [이미지 개발] 승인된 R2·R3·R1F·RANK3 업로드(10장 이하씩 2번) → UIArt 키 → UiSandbox에서 1280×720·749×361, 밝은·어두운 배경 확인
- **이미지·이미지 개발:** [이미지 개발] ART-DEL1: 78개를 경로별로 git rm, asset_ids.json에 'deleted' 표시
- **검수:** BM8-C 성숙도 설문 답안 초안(무법자 빨간 이름표와 PvP 판 포함)
- **검수:** A23-22 주간 1~3위 보상 계약을 BB10 문서에 확정: 깡패 벌칙과의 곱셈 순서, 칭호 기간. 개발2가 10/10에 만들기 전에 끝낸다
- **사용자:** ART-G0 회색 상자 배치 1장 승인
- **사용자:** 저녁에 묶음 1 스타일 보드 보기

### 10/08–10/09 (목–금)
- **개발:** [개발] BB13 마무리: Config.Menu.Sections 5묶음, Esc(MenuOpened)와 패드 ButtonB로 닫기, 오프닝 다시 보기·이름 숨기기를 설정으로 이동, Keybinds.Refresh → 동기화·플레이
- **개발:** [개발] BB3 SettingsUI: 탭 [키 설정][기타], 효과음 배율, 흔들림 끄기, 마우스 감도, 이름 숨기기 줄(BB37 문구), 아래 줄 BuildLabel·SaveOK, 749×361 확인
- **개발:** [개발2] BB10 RankingService: 주간 판 3개(Honor·Infamy·PvP), GrantFame 7곳, PvPCreditOK, OrderedDataStore 쓰기 예산과 읽기 캐시, PrivateServerId 가드, STUDIO 시즌 우회
- **개발:** [개발2] BB10 오프라인 검사(가짜 DataStore): 약자 KO는 PvP만, 공정 KO는 명예/악명만, 친구 KO는 둘 다 아님
- **이미지·이미지 개발:** [이미지] 묶음 1 승인 반영 → 묶음 2: 진영 빈 카드 3, 제목, 설명판, 하단, 직업 카드 틀 3. FreshTyped 카드에서 글자만 지운 판을 구조 참조로 쓴다
- **이미지·이미지 개발:** [이미지 개발] ART-G1 HUD 재배치(UiSandbox): L 표와 applyLayout 수정, 3D 지역 간판을 칩으로, 높이 560 아래 접기
- **이미지·이미지 개발:** [이미지 개발] ART-G1 같이: BB5 폰 겹침 수정(+N 팝업이 금고 줄을 덮음, 물약·퀘스트가 조이스틱 자리로 내려감)
- **이미지·이미지 개발:** [이미지 개발] ART-G1 같이: 가방 칸 예약(Panels.Has('Bag')일 때만 보임)
- **이미지·이미지 개발:** [이미지 개발] 10/09 밤 커밋 → 개발에 해시 전달
- **검수:** BB13·BB37 증거 재확인
- **검수:** A23-23 무법자 문구 아동 안전 점검
- **사용자:** 10/08 묶음 1 스타일 보드 승인
- **사용자:** 10/09 묶음 2 진영 카드 승인 + 뿔 카드 A/B 선택(질문 6)

### 10/10–10/12 (토–월)
- **개발:** [개발] 10/10 아침: G1을 메인 Studio에 동기화하고 플레이
- **개발:** [개발] BB6: Panels.Items 내보내기, Config.WeaponView·ItemView·ItemSources, Loot.Items에 Grade·Desc·Icon(사탕·재료 IconKey)
- **개발:** [개발] BB7 가방: BagUI Register('Bag'), 탭 4개, 88px 격자, 상세, SellItem 원격 검증, '모두 팔기'는 Common만
- **개발:** [개발] BB7 HUD [가방]은 G1 예약 칸에 바로 연결(임시 위치 없음), 결과 문구에 '전투력 A → B'
- **개발:** [개발2] A23-23 주간 정산 + 무법자 벌칙 + A23-22 주간 1~3위 보상을 정산 하나로. HH_RankSettle_<WeekId>는 한 번만 쓴다
- **개발:** [개발2] BB14 서버 부분: DamagePlayer sourceKind, KO 페이로드
- **이미지·이미지 개발:** [이미지] 10/10 묶음 3 특성 아이콘 10장
- **이미지·이미지 개발:** [이미지] 10/11–12 묶음 4: 아이콘 4장 + 9-slice 부품 6개
- **이미지·이미지 개발:** [이미지 개발] 묶음 2 코드: BakedText=false, 글자 자리, ButtonRects·CardLayout 다시 재기, 옛 FreshTyped 삭제
- **이미지·이미지 개발:** [이미지 개발] 묶음 3 적용: BakedPerkIcons=false
- **검수:** 10/10 토 주간 보고 #1(폰)
- **검수:** 10/12 점검 1: BB0~BB7, G1, 묶음 2 판정
- **검수:** 남은 일을 실제 속도로 다시 계산해 사용자에게 한국어로 보고
- **사용자:** 10/10 묶음 3 승인, 10/12 묶음 4 승인
- **사용자:** 주간 보고 읽기

### 10/13–10/14 (화–수)
- **개발:** [개발] BB9 스킬 정의 + 스킬창: Q 줄은 MP·쿨다운 실시간, Z 줄은 ZEnabled일 때만, 패시브 칸, [키 바꾸기] → 설정
- **개발:** [개발] BB8 캐릭터·장비창: 얼굴과 큰 전투력, 무기 칸, 칭호 고르기(BB16), 능력치 탭, C키
- **개발:** [개발] BB8 펫 칸 = PET-5. 임시 펫 줄은 만들지 않는다
- **개발:** [개발2] PET-1 이동 속도 한곳 계산: 스킬 버프 없이, 상한 ×1.35, checkMove 오탐 검사
- **개발:** [개발2] PET-2 펫 저장·EquipPet·펫 XP·따라잡기 지급 + 오프라인 검사
- **이미지·이미지 개발:** [이미지] 10/13 묶음 5 공통 창 2 + 상태판·바
- **이미지·이미지 개발:** [이미지] 10/14 묶음 6 전투 버튼·레벨 배지·글리프
- **이미지·이미지 개발:** [이미지 개발] 묶음 4 9-slice 적용: 설정·가방·스킬·캐릭터 창도 UIKit 키로 만들어져 있어 키만 바꾸면 같이 바뀐다(다시 만들 일 없음)
- **검수:** BB7·BB10 증거 재확인
- **검수:** LAUNCH-OPS 체크리스트 초안
- **사용자:** 묶음 5·6 승인

### 10/15–10/17 (목–토)
- **개발:** [개발] 개발2의 랭킹·정산 병합 → 동기화 → 2클라 확인
- **개발:** [개발] BB11 랭킹 창 3탭×2범위 + 마을 게시판(PublicName, ProximityPrompt, L키) + 무법자 HUD 칩
- **개발:** [개발] BB15 도움말: '매년 돌아와요'(P10), 베타 저장 안내, 장인 길드는 주간 보상 없음
- **개발:** [개발] BB14 DeathScreen 클라이언트
- **개발:** [개발] BB38: UiMetric, KeyRebind, Level10
- **개발:** [개발2] PET-4 '길 잃은 아기 슬라임' + PET-6 펫 알림
- **개발:** [개발2] WPN-3, GOOSE-Q(데이터만 3단계, 새 대화 없음)
- **개발:** [개발2] A23-18 오프라인 검사(유예·운·깡패) + A23-18-LOG
- **이미지·이미지 개발:** [이미지] 10/15–16 묶음 7 글리프·등급 칸
- **이미지·이미지 개발:** [이미지] 10/17 묶음 8(별·물약 3장) + 묶음 9(T8·상태 아이콘 7장)
- **이미지·이미지 개발:** [이미지 개발] 묶음 5 적용(VitalsUI 색) + 묶음 6 적용(공격 버튼 주황, 레벨 배지)
- **검수:** 10/17 토 점검 2 + 주간 보고 #2: 필수 BB가 다 끝났나
- **검수:** Z 결정. 예상은 끈 채 베타
- **사용자:** 묶음 7·8·9 승인
- **사용자:** Z 결정 확인

### 10/18–10/20 (일–화)
- **개발:** [개발] PET-3 펫 따라다니기(0.35배, 15Hz) + 펫 서버 병합 → 플레이
- **개발:** [개발] RP5 장비 상인 기본 NPC, QC-8 옛 문구 정리
- **개발:** [개발] BM1·BM2: R15로 3직업 공격·스킬 캡처, 사망/부활 기록
- **개발:** [개발] LIVE-TEST 1차: 사용자 OK 뒤 비공개 장소에 게시 → 7일 넘은 계정과 폰으로 저장·닉네임·물약·랭킹 확인
- **개발:** [개발2] Z가 켜졌으면 ZSK-1·ZSK-3 서버
- **개발:** [개발2] Z가 꺼졌으면 BB24 첫 안내, REV-LEFT shop-8, BB40 삭제 도구
- **이미지·이미지 개발:** [이미지] 10/18–19 묶음 10 직업 그림 9장(한 장씩 단정한 옷 확인)
- **이미지·이미지 개발:** [이미지] 10/20 묶음 11a 안내자 초상 3장
- **이미지·이미지 개발:** [이미지 개발] 묶음 7 적용(가방 칸 등급 테)
- **이미지·이미지 개발:** [이미지 개발] 묶음 8·9 적용. T8 슬라임 초록은 개발과 같은 커밋으로
- **이미지·이미지 개발:** [이미지 개발] BM4 HUD 마무리: PC·폰, 터치 60 이상
- **검수:** 10/20 점검 3: 최종 컷 결정 보고
- **검수:** ART-SAFE 시작: 사람이 나오는 그림을 한 장씩 점검
- **사용자:** 비공개 장소 게시(Publish) OK. Public은 하지 않음
- **사용자:** 묶음 10 직업 그림 승인
- **사용자:** 최종 컷 확인

### 10/21–10/24 (수–토, 기능 마감)
- **개발:** [개발] QC-7 + F10-E2E 실측(디버그 없이, 핼러윈 켠 상태): 3진영, PC와 폰 749×361
- **개발:** [개발] 실측 경로: 오프닝 → 150골드 → 대장간 → 다음 목표. Lv5·Lv10 도달 시각과 60초 넘는 공백 기록 → 찾은 문제 수정
- **개발:** [개발] 10/23 여유일: BB39·BB24
- **개발:** [개발] 10/24 기능 마감: 마지막 동기화, Save to File As → 해시 → place/ 커밋·태그
- **개발:** [개발2] 오프라인 검사 전체 다시 돌리기(새 폴더 verification_2026-10-2x), 병합 도움
- **이미지·이미지 개발:** [이미지] 10/21–22 묶음 11b: 게임 아이콘 3안 + 썸네일 2장. 고품질 장당 5크레딧, 약 25크레딧이라 먼저 알림
- **이미지·이미지 개발:** [이미지] 10/23–24: 다시 그리기만
- **이미지·이미지 개발:** [이미지 개발] 묶음 10 적용(CardLayout, 성별 버튼 숨김), 묶음 11a 적용
- **이미지·이미지 개발:** [이미지 개발] ART-DEL2 바뀐 옛 그림 삭제, 마지막 캡처
- **검수:** QC-7 증거 재확인
- **검수:** ART-SAFE 기록 파일
- **검수:** 10/24 토 주간 보고 #3 + 테스트 주 계획
- **사용자:** 안내자 초상 승인, 아이콘 1안과 썸네일 고르기
- **사용자:** 핼러윈 끝나는 날 정하기

### 10/25–10/30 (테스트·버그 수정만)
- **개발:** BM8-D 3클라 다인 테스트: PvP, 원한 자루, 거위, 괴수, 호박 대왕, 닉네임 중복
- **개발:** BM8-E 저장 안전: 재접속, 서버 종료 저장, 두 서버 잠금
- **개발:** LIVE-TEST 2차 + PERF-1 폰 FPS
- **개발:** A14-2 일일 수치 조정과 버그 수정만
- **개발:** 10/30 LAUNCH-OPS 리허설, 테스트 계정 저장 정리(사용자 승인 뒤)
- **이미지·이미지 개발:** 새 그림 없음. 깨진 누끼만 고침
- **검수:** 재검사
- **검수:** 성숙도 설문 답안 최종본
- **사용자:** 성숙도 설문 제출
- **사용자:** 체험 페이지에 아이콘·썸네일·설명문 올리기
- **사용자:** 10/31 11:00 Publish → Public

## 점검일

### 10/12 (월)
- HW-11: 핼러윈이 메인 Studio에서 플레이 확인됨. src·tools·place/ 커밋 완료(HalloweenService와 Main을 같이)
- F10-4: 뿔·마법사·터치에서 150골드 받기 고침
- BB13 Panels.Register와 메뉴 5묶음
- BB3 설정 창과 키 바꾸기
- BB6 아이템 공용 접근
- BB7 가방과 HUD [가방]. 버튼은 G1 예약 칸에 있음
- ART-G0 회색 상자 배치 승인 → ART-G1 메인 Studio 적용(BB5 폰 겹침 포함)
- 묶음 1 스타일 보드 승인, 묶음 2 진영 화면 승인과 코드(BakedText=false)
- R1·R2·R3 아이콘이 UIArt에 연결됨, ART-DEL1 78개 삭제
- 개발2를 열었다면: BB37, BB12, BB10 서버가 오프라인 검사 통과
- 실제 속도로 남은 일 다시 계산 → 사용자에게 보고

### 10/17 (토)
- BB9 스킬창, BB8 캐릭터·장비창(펫 칸 포함), BB11 랭킹 창과 게시판, BB15 도움말, BB14 쓰러짐 화면, BB38 지표
- BB10 랭킹, A23-23 무법자, A23-22 주간 보상이 병합되고 2클라로 확인됨
- PET-1·PET-2 서버가 병합됨
- 묶음 3~7이 게임에 들어감
- 묶음 8·9 승인
- Z 결정: 필수가 다 끝났을 때만 켬. 예상은 끈 채 베타

### 10/20 (화)
- PET-3 따라다니기, PET-4 서브 퀘스트, PET-5(BB8 안), PET-6 알림
- GOOSE-Q, RP5 장비 NPC, WPN-3, QC-8
- BM1·BM2: R15 3직업 캡처
- LIVE-TEST 1차(비공개 게시본, 7일 넘은 계정, 폰)
- 묶음 10 직업 그림 승인. 못 하면 아바타 미리보기로 대신
- 최종 컷 결정: 영어 정식, Z 끔, 랭킹 전체 또는 이 서버

### 10/24 (토, 기능 마감)
- QC-7 + F10-E2E 실측 기록(디버그 없음, 3진영, 폰)과 그 수정
- 묶음 11a 적용, 11b 아이콘·썸네일 선택
- BM4 HUD 마무리 증거(PC·폰, 터치 60 이상)
- ART-DEL2, ART-SAFE 기록
- Save to File As → place/ 커밋·태그
- LAUNCH-OPS 체크리스트 문서
- 남은 것은 전부 '정식' 또는 '테스트 주' 표시

## 늦을 때 줄이는 계획

- 1. 지금(10/06) 결정 요청: 영어(BM7)와 BB29 언어 줄을 정식으로 미뤄요. 약 4.5일을 아껴요. 베타는 한국어로 내고, Config의 *En 필드는 그대로 둬요. 체험 페이지 설명문만 한국어·영어로 써요.
- 2. Z 스킬(ZSK-1~5, 묶음 14 Z 3장)은 플래그를 끈 채로 계획해요(Skills.ZEnabled=false는 이미 있음). 약 5.5일을 아껴요. 10/17에 필수가 다 끝났고 개발2에 여유가 있을 때만 서버 부분을 시작해요.
- 3. 핼러윈 몬스터 수는 줄이지 않아요. 거의 끝났어요(오프라인 2652/0, 남은 것은 HW-11 반나절~1일). 끝나는 날(HW-13)만 정해요.
- 4. 베타 권장 기본 기능 중 BB39·BB24만 10/23 여유일에 해요. BB3b, BB21, BB18, BB19, BB20, BB25, BB8b, BB41, BB40, BB26, BB28, BB23과 BB22·BB30~36은 정식으로 미뤄요.
- 5. 전체 랭킹을 '이 서버 랭킹'으로 줄이는 것은 10/17에 BB10이 병합되지 않았을 때만 해요. 약 1.5일을 아껴요. 이렇게 하면 무법자와 주간 보상이 서버별 판이 돼요. A23-21 위험 기록대로 사용자 확인이 필요해요.
- 6. 범위를 지키면서 단순화해요(약 2.5일 절약). 펫 화면은 BB8 펫 칸에 바로 만들고, 이동 속도 계산에서 스킬 버프를 빼서 펫이 4.5일에서 3.5일이 돼요. 무법자와 주간 보상은 정산 하나로 2일에서 1.5일이 돼요. GOOSE-Q는 새 대화 없이 데이터 3단계로 0.5일이에요. QC-7과 F10-E2E는 한 번의 실측으로 묶어요.
- 7. 검증만 하는 항목은 10/25~30 테스트 주로 보내요. BM8-D, BM8-E, LIVE-TEST 2차, PERF-1, BM3·BM5 실기, A14-2 수치 조정이에요. 개발2가 없으면 A23-18 오프라인 검사도 여기로 가요.
- 8. 그림 최저선(약 50장) 규칙: 10/17에 묶음 7까지 못 들어가면 남은 HUD·창 키트(묶음 4~7)는 옛 그림에 배치만 바꿔요. 대신 묶음 8~11(아이템·T8·직업·안내자·아이콘)을 먼저 해요. 여유 묶음 12~21(지형 15장 포함)은 정식으로 미뤄요. 사용자 확인이 필요해요.
- 9. 묶음 10 직업 그림이 10/20까지 승인되지 않으면 직업 고르기 화면을 본인 아바타 3D 미리보기로 대신해요(그림 0장, 노출 위험 0).
- 10. 개발2를 열지 않으면 위 1~7을 다 해도 약 3~4일이 더 모자라요. 그때 추가로 빼는 순서는 A23-22 주간 1~3위 보상(칭호·+10%)을 정식 첫 주로 미루고 무법자 벌칙만 베타에 남기는 것, 그다음 GOOSE-Q를 정식으로 미루는 것이에요. 사용자 결정이 필요해요.

## 개발 세션 하나 더 (개발2)
개발2를 열 것을 추천해요. 조건부 '예'이고, 사용자 OK가 필요해요(10/06에 정한 4세션에 하나를 더하는 것이라서).

이유:
- 개발 1세션이면 단순화 뒤에도 약 6일 모자라요.
- 서버 줄은 BB13 창 작업을 기다리지 않아요: BB37 → BB12 → BB10 → A23-23/A23-22 정산 → BB14 서버 → PET-1·2·4·6 → WPN-3 → GOOSE-Q → A23-18 검사·LOG.
- 오프라인 검사 도구가 이미 있어요. tools/test_*.py는 build/luau_cli_0_741/luau.exe로 Studio 없이 돌아가요(test_halloween.py 설명 참고).
- 명목으로 약 10.75일을 덜어 내고, 개발의 병합 비용은 약 1.5일이에요.

방식:
- 시작은 10/07이에요. 핼러윈 커밋 뒤 깨끗한 main에서 git worktree를 만들고 dev2 브랜치에서 일해요.
- 개발2는 Studio를 만지지 않아요. sync_to_studio, playtest, Publish도 하지 않아요.
- 통합은 개발만 해요. 메인 Studio 동기화, 플레이, place/ 커밋, main 병합이 모두 개발 몫이에요.
- 개발2는 증거를 새 이름으로 남겨요(verification_2026-10-2x).

같이 쓰는 파일 규칙:
- Config.luau: 개발2는 새 최상위 표(Config.Ranking, Config.Pets, 무법자 문구)만 파일 끝 한 블록에 추가해요. Config.StoryQuests.Subs와 Announce.Text 줄은 SendMessage로 알린 뒤 작게 고쳐요. 개발은 Menu, Bag, Help, Skills, Equip, Death 표를 맡아요. 이미지 개발은 UIArt 블록을 맡아요. 개발2는 매일 rebase해요.
- Main.server.luau INIT/START 목록: 개발2만 고쳐요(RankingService, PetService). 서비스 파일과 목록 줄은 같은 커밋에 넣어요. HalloweenService에서 이미 겪은 '목록만 있고 파일 없음 → 서버 멈춤' 위험이 있어서예요.
- ClientMain ORDER: 개발만 고쳐요. 그래서 PET-3 PetFollow 클라이언트는 개발에게 줬어요.
- Panels.luau: 개발만 고쳐요. 새 창 6개를 모두 개발이 차례로 만들어요.
- HUD.luau: 이미지 개발(L 표, applyLayout)과 개발(상태 연결)만 고쳐요. 개발2는 손대지 않아요. 무법자 HUD 칩도 개발이 BB11 때 연결해요.
- Net.luau: 둘 다 원격을 추가하지만 끝에 줄만 붙여서 충돌이 작아요.
- LootService: 개발은 SellItem, 개발2는 RollKill 배율(무법자 ×0.5, 주간 +10%, LOG)을 고쳐요. 함수를 나누고, 고치기 전에 SendMessage로 알려요.
- PvPService, PlayerService, DataService fillDefaults, CombatService: 10/07부터 개발2만 고쳐요.

위험:
- PC 부하가 커요(Claude 세션 5개, Studio 2개, Firefly 브라우저). 느리면 연습 Studio를 먼저 닫아요.
- 개발2 결과는 개발이 플레이로 확인하기 전까지 '적용 완료'라고 쓰지 않아요.
- 개발2를 열지 않으면 위 10번 컷이 필요해요.

## 사용자에게 물을 것

- 영어(BM7)를 지금 정식(12/19)으로 미룰까요? → 추천: 예. 베타는 한국어로 내고, 영어는 정식 때 제대로 넣어요(약 4~5일 절약). 체험 페이지 설명문만 한국어·영어로 써요.
- 게임성 개발 세션을 하나 더 10/07부터 열까요? 서버 기능만 맡고, 다른 작업 폴더를 쓰고, Studio는 만지지 않아요. → 추천: 예. 랭킹·무법자·펫 서버를 맡기면 10/24에 맞출 수 있어요. 안 열면 주간 1~3위 보상이나 거위 설명 퀘스트를 정식으로 미뤄야 해요.
- Z 스킬은 꺼 둔 채 베타를 낼까요? 최종 결정은 10/17 점검 때 해요. → 추천: 예. 정식 때 켜요.
- 캐릭터는 R15만 쓸까요? 지금 장소는 R15 강제예요. → 추천: 예. R6 확인은 생략해요.
- 그림 승인을 매일 저녁 한 번, 폰으로 한 장씩 해 주실 수 있나요? → 추천: 예. 승인이 하루 밀리면 베타 그림도 하루 밀려요.
- 바닥 지형 15장과 여유 묶음(12~21)은 정식으로 미뤄도 될까요? → 추천: 예. 지금 지형은 새 계정 그림으로 잘 나와요.
- 직업 그림 9장이 10/20까지 승인되지 않으면, 직업 고르기 화면에 내 아바타 3D 미리보기를 대신 쓸까요? → 추천: 예. 그림이 필요 없고 노출 위험도 없어요.
- 게임 아이콘·썸네일을 고품질로 만들어도 될까요? 장당 5크레딧, 모두 약 25크레딧이에요. → 추천: 예.
- 비공개 장소 게시(Publish)를 10/19와 10/26에 한 번씩 해도 될까요? → 추천: 예. Public 전환은 하지 않아요.
- 핼러윈은 언제 끌까요? → 추천: 11/9(월) 0시(한국 시간)에 자동으로 꺼지게 해요.
- 변경권 로벅스 상품 2개를 베타에서 팔까요? → 추천: 베타에서는 팔지 않고 정식 전에 만들어요. 성숙도 설문과 테스트가 단순해져요.
- 테스트 계정 저장(디버그로 받은 레벨·골드)을 10/30에 지울까요? → 추천: 예. 베타 저장이 정식까지 이어지니까 깨끗하게 시작해요.

## 항목 상태 (베타 필수 중 끝나지 않은 것)

| id | 이름 | 상태 | 크기 | 담당 | 남은 일 |
|---|---|---|---|---|---|
| BB5 | HUD 전투력 표시·상승 알림 | partial | S | 이미지 개발 (HUD layout owner) / 개발 | Fix the phone 749×361 layout. Either a small interim nudge now, or include it in the ART-G1 relayout. Then capture 749×361 and 844×390 and confirm the +N popup does not cover the bank row and nothing sits in the joystick… |
| BB13 | 메뉴 정리 + 창 등록 통로(Panels.Register) | partial | M | 개발 session | Panels.Register(id,{Build(parent,kit,arg),Title,FixedBody,Rebuild,Cleanup}) + Open arg 전달(RENDER.Arg) + 이전 창 Cleanup + 등록 창은 opts.Rebuild 속성만 전체 재그리기 + kit 표; Config.Menu.Sections 5묶음(등록된 창만 표시); 오프닝 다시 보기·이름 숨기기를 설정(BB3… |
| BB3 | 설정 창 + 키 바꾸기 | partial | M | 개발 session | SettingsUI.luau + Register('Settings', FixedBody, Rebuild=false), 탭 [키 설정][기타], arg {Tab='Keys'}; 살아 있는 동작마다 키 버튼·[비우기]·[기본값으로](확인 1회); 터치 전용 안내 1줄, 패드 고정표; 효과음 배율(Fx SOUND_VOLUME 표 안), 흔들림 끄기(+ReducedMotion), 키 표시, 이름 숨… |
| BB6 | 아이템 공용 접근(Panels.Items·Config 보기 함수) | not-started | S | 개발 session | Panels.Items() 내보내기(Data·Send·ReadyAt·ValidMode·ResultText·FailText·Changed 신호·MarkNew/NewCount/ClearNew); Fx 드랍 → MarkNew(지연 참조); Config.WeaponView/ItemView/ItemSources(P7 글 이동, 자주/가끔/드물게 띠, 황금×3, 물약 25골드, 계절 몬스터 필터·Can… |
| BB7 | 가방 창 + HUD [가방] + 골라 팔기 | not-started | L | 개발 session | BagUI.luau Register('Bag') 탭 4개+NEW 수, 정렬, 88px 격자, 등급 테 코드 대체, 상세(640px 이상 6:4, 749×361 전환+[← 가방]); 장착/주문서(mode→pick→confirm)/물약(VitalsUI.PotionState 내보내기)/팔기; 새 원격 SellItem(id,n) 검증·RateLimits 0.3·모루 근처·PvP 중 거부; SellM… |
| BB9 | 스킬 정의 + 스킬창 | not-started | M | 개발 session | Config.Skills.Order/Defs(Q_Warrior 회오리 충격파, Q_Mage 유성 낙하, Q_Archer 화살비 + Z 3종 정의, 수치는 BasicSkill 참조), SkillDef/SkillLines(진영 줄); SkillBook.luau Register('Skills'): 기본 공격 줄, Q 줄(Mana·SkillReadyAt 실시간 준비됨/n초/MP 부족), Z 줄은 Z… |
| BB8 | 내 캐릭터·장비창 | not-started | M | 개발 session | CharacterUI.luau Register('Character'): [장비] 탭 얼굴 사진+큰 전투력, 무기 칸·가진 무기 목록(Config.WeaponView '전투력 ±N · 슬라임 n방', EquipWeapon via Panels.Items 가드), 칭호 고르기 줄(SetTitle, BB16), 펫 칸(Config.Pets 있을 때만); [능력치] 탭(HP·MP·속도·1회 피해·스킬… |
| BB37 | 이름 숨기기 한곳 처리(PublicName) | not-started | S | 개발 session | AnnounceService.PublicName(player) 추가(숨김이면 '<진영> 한 명'); 위 7곳 + 마을 게시판 이름 교체; 설정 문구 '알림·랭킹에 내 이름 숨기기' + 안내 2줄 Config.Announce.Text; grep 'NotifyAll.*PlayerDisplayName' 0건; 2명 MCP 확인 |
| BB10 | 랭킹 서비스 (주간 명예·악명·PvP 3판, 공정 점수) | not-started | L | 개발 | 1) RankingService in the INIT/START lists, with Config.Ranking: Order={'Honor','Infamy','PvP'}, WeekCap Honor/Infamy 150, and a STUDIO/PRE season. 2) data.Rank {Honor, Infamy, PvP week fields} and DebugTainted. 3) Route … |
| BB11 | 랭킹 창 + 마을 게시판 (3탭) | not-started | M | 개발 | Rankings.luau Register('Ranking') with 3 tabs × 2 scopes (6 combinations) and a 30-second cache. Red '무법자' tag on PvP ranks 1-3. One explanation line above the PvP tab and one above Honor/Infamy ('다음 주 경험치·드랍 +10%'). A f… |
| BB12 | 플레이어 목록(Tab) 열 정리 | not-started | S | 개발 session | Config.Leaderstats.Columns = {'Power','Level','Rebirths','Fame'}; buildLeaderstats를 목록으로 생성(생성 순서=열 순서), Power IntValue = CombatPower 속성, LEADERSTAT_KEYS에 CombatPower 추가, 골드 열 제거; HUD 숫자와 일치·환생 후 순서 MCP 확인 |
| BB14 | 쓰러짐·부활 화면 | not-started | S | 개발 session | DamagePlayer 5번째 인자 sourceKind + MonsterService 전달; runDeathPipeline에 CarriedGold 전후 Lost, By(Player/Kaiju/Monster/Fall/Other) 판정, 주인 전용 Net.Fx 'KO' {By,Name,Lost,Sack,RespawnIn}; DeathScreen.luau(ORDER EventHUD 뒤) 비모달 오… |
| BB15 | 도움말 + 베타 안내 + 안내자 다시 만나기 | not-started | S | 개발 session | Config.Help.Topics(조작법 자동 키, 전투·자동+20분 퇴장 줄, 명예·악명, 새싹·깡패(Bully.Text), 현상 별·원한 자루, 거위·괴수·환생, 주문서 10/30/70%, /t 진영 채팅, 새 소식 Config.Help.News); SettingsUI.luau 안 Register('Help'); '안내자 다시 만나기'로 Config.Tutorial.Welcome 읽기 전… |
| BB38 | 베타 지표(P6 퍼널) | partial | S | 개발 session | c→s 'UiMetric'(id) 원격(Config.Analytics.UiIds, select==1, IsReady, RateLimits.UiMetric=2, 세션당 창별 1회) → WindowOpen_<id>; KeyRebind 이벤트(Settings 키 변경), AutoAwayMinutes(자동 ON + 5분 이상 무입력 합계), Level10 단계(계약 8단계; 현재는 Joined가 1… |
| F10-E2E | 첫 10분 전체 흐름(끝까지 플레이) | partial | M | 개발 | 10-05 저녁 변경(이야기 퀘스트·S0·일일·전투력·깡패 벌칙·핼러윈) 뒤 새 계정으로 다시 실측한다. 디버그 없이 3진영 각 1회 + 폰 749x361 1회, 오프닝→진영→안내자→5마리→150골드→대장간→다음 목표 줄까지. TelemetryService 퍼널 시간도 기록한다. 보상 받은 뒤 대장간까지 262초 걸린 이동을 줄일지 정한다 |
| F10-2 | 진영·직업 선택 화면 | partial | L | 이미지 → 개발 | Firefly 묶음 2(진영 화면), 3·4(특성 아이콘), 10(직업 그림 9장)을 승인 → 누끼 → 업로드 → Config.UIArt 교체 → Studio 확인 순으로 진행한다 |
| F10-4 | 슬라임 5마리 → 150골드 받기 | partial | S | 개발 | 런2가 멈춘 원인을 재현해 고친다. 뿔·마법사·터치에서 고정 줄이 '받기'로 바뀌고 누르면 지급되는지 본다. 필요하면 5/5에서 자동 지급하거나 토스트에 받기 버튼을 둔다 |
| BM1 | 치비 제거·본인 아바타 R15/R6 (진행 3단계) | partial | S | 개발 (+사용자: R6 허용 여부) | R15만 쓸지 R6도 허용(Player Choice)할지 정한다. R15만이면 'R6 해당 없음'으로 기록하고, R6를 허용하면 걷기·점프·공격·스킬·사망/부활을 확인한다. R15 사망/부활·점프 기록도 남긴다 |
| BM2 | 3직업 공격·스킬 모션(본인 아바타) | partial | S | 개발 | 본인 R15 아바타로 전사·마법사·궁수 기본 공격·스킬을 각 1회 캡처한다(R6 허용 시 R6도). 모션 다양화와 손 모양은 '나중에 고칠 것'이라 베타에서 제외한다 |
| RP5 | 장비(대장간) 상인 기본 NPC | partial | S | 개발 | 모루 옆에 HumanoidDescription 기본 NPC 1명과 같은 E 프롬프트를 둔다(UpgradeWeapon 12stud 검증 공유). 첫 10분 안내도 그 NPC를 가리키게 한다 |
| BM3 | 물약 NPC 구매·남은 수량 | partial | S | 개발 | Studio에서 E → 1개/5개 구매 → 수량 표시 → 사용 → 재접속 후 유지를 확인한다. 폰 물약 버튼도 본다 |
| RP6-A | HUD 회색 상자·전면 재배치 (중복 항목) | not-started | 0 | 검수 → 이미지 개발 | Count it in ART-G0 and ART-G1 only. |
| RP6-B | Firefly 그림 전면 교체(베타 묶음 1~11) | in-progress | XL | 이미지 + 개발(업로드·적용) | 묶음 1~11(약 93장, 최저선 약 50장)을 진행한다: 스타일 보드 → 진영 화면 → 특성 아이콘 → 공통 창 → HUD 버튼 → 아이템 아이콘 → T8 무기 → 직업 9장 → 안내자·아이콘·썸네일. 장마다 승인·누끼·10장 이하 업로드·Studio 적용·옛 그림 삭제 |
| RP6-C | 핼러윈 몬스터·호박 대왕 게임 반영 | in-progress | 0 | 개발 | Same work as HW-11, count it once there: sync → re-run apply_studio_state (FRONT_FIX) → play with DebugCommand 'PumpkinKing' → save the place → commit by path. |
| RP7 | 베타 목록 나머지(기본 RPG 시스템 등) | in-progress | XL | 개발 | 10/12까지 BB13 → BB3 → BB6 → BB7. 그다음 BB9 → BB8 → BB37 → BB10·11·12 → BB14·15 → 펫. Z 스킬은 10/17 점검을 통과한 뒤에 한다 |
| BM4 | HUD 마무리(글자·균형·폰·터치·자동 버튼) | partial | L | 개발 | RP6-A 배치를 반영한 뒤 글자·균형·749x361·터치 60 이상을 PC와 폰으로 캡처해 검사한다 |
| BM5 | 닉네임 중복 방지·금칙어·재접속 저장 | partial | S | 개발 | DataStore가 켜진 비공개 장소에서 이름 설정 → 다른 클라이언트에서 같은 이름 거절 → 재접속 후 유지를 확인한다. test_nickname은 새 날짜 폴더에 다시 돌려 기록한다 |
| BM7 | 한국어+영어 | not-started | XL | 개발 + 검수(번역·용어집) | 클라이언트 문구를 중앙 문구 표(Lang 모듈 또는 LocalizationTable)로 옮긴다. 용어집과 영어 번역, BB29 언어 줄, ko/en 스크린샷, 글자 없는 Firefly 카드가 필요하다 |
| BM8-A | 게임 아이콘·썸네일 | not-started | M | 이미지 + 사용자 | Firefly로 아이콘 3안과 썸네일 2장을 만들어 사용자가 고르고, 사용자가 크리에이터 대시보드에 올린다 |
| BM8-B | 설명문 한/영 | not-started | S | 검수 | 한국어·영어 설명문 초안(진영 선택·사냥·PvP·핼러윈 베타·유료는 변경권만)을 쓰고 사용자 확인을 받는다 |
| BM8-C | 성숙도 설문 답안 | not-started | S | 검수 → 사용자 | 폭력(PvP·괴수), 훔치기·원한, 전체 채팅 알림, 유료(변경권), 무작위 보상(대박 드랍은 무료) 문항별 답과 근거 체크리스트를 만들어 사용자에게 넘긴다 |
| BM8-D | 3명 이상 다인 테스트 | not-started | M | 개발 | Studio 로컬 서버 3클라이언트로 PvP·원한 자루·거위 함께 구조·괴수·호박 대왕 공동 처치·기여자별 드랍·닉네임 중복을 확인하고 콘솔 오류 0을 기록한다 |
| BM8-E | 저장(DataStore) 안전 확인 | partial | M | 개발 + 사용자(유니버스 결정) | 비공개 장소에서 재접속, 서버 종료 저장, 두 서버 잠금, 쓰기 제한을 실제로 검사한다. 베타를 같은 유니버스(10769445522)로 낼지 정하고 테스트 계정 세이브(디버그 골드·레벨)를 정리한다 |
| BM8-F | 새 계정 업로드 안전 재점검 | partial | S | 개발 + 이미지 | 베타 직전에 Config.UIArt 97개·MaterialService·모델 자산 최종 목록을 점검한다. 63b95d9에서 ID를 비운 옛 직업 초상 UIP_Char*F/M 36개 파일(art/out 18개 + art/ui 18개)은 이제 쓰이지 않으니 삭제한다 |
| WPN-3 | 무기 저장 안전(B0) 잔여 | partial | S | 개발 | Config.WeaponShop.Tiers={2,3} 명시, WeaponIsShop/WeaponAtLeast 헬퍼로 순서 비교 교체, CharacterVisuals T8 연출 확인, Config.Weapons '뒤에만 붙이기' 주석 |
| A14-2 | 새싹 일일 3개(짧고 다양하게) | partial | S | 개발 | 사람 손 실측 분당 처치 수로 목표 수·보상 재조정(결정문: 수동 실측 기준), 일일만으로 Lv10 안 되는지 재확인 |
| GOOSE-Q | 거위 설명 퀘스트(S1 보강) | partial | M | 개발 | 처음 1번 짧은 대화(조각 품은 거위 → 빛 구조·뿔 밀렵 → 직접 3번 → 상대 없으면 함께 구조), 단계 3개(둥지 가기 빔 → 직접 때리기 n/3 수동 타수 → 결과 보기), 줄에 'm:ss 뒤' 카운트다운 |
| PET-1 | 이동 속도 한곳 계산 | not-started | M | 개발 | 기본20×직업×(1+펫)×스킬 버프, 전체 상한 ×1.35, 재계산(장착·펫Lv·지역·괴수·InCombat 만료·SackGold), PvP 중에도 켜짐, checkMove 최대 속도 오탐 없음 오프라인 테스트 |
| PET-2 | 펫 저장·지급·장착 서버 | not-started | M | 개발 | data.Pets {List[uid]={Sp,Lv,XP,Name,Lean,Bound}, Equipped}, sanitize, EquipPet 원격 검증·간격, 펫 XP(처치·자동 포함, 15×Lv), 속도 +7%→+10%, 속성 EquippedPet/PetLv/PetForm, 본인 전용 목록 원격, '퀘스트 완료인데 펫 없으면 지급' 따라잡기, 오프라인 테스트 |
| PET-3 | 펫 따라다니기(클라이언트) | not-started | M | 개발 | 0.35배 복제, 깡충·눌림 작은 공용 모듈(Fx·HUD 200 local 한도), 15Hz 땅 붙이기, 남의 펫도 보임, 이름표 '아기 슬라임 · 착한 친구/장난꾸러기 졸개', 폰 성능 확인 |
| PET-4 | 서브 '길 잃은 아기 슬라임' | not-started | S | 개발 | M1_1 뒤 열림(서브 순위 2), 초원 슬라임 8 → [보살펴요] 명예+1 / [내 졸개로 삼아요] 악명+1, 장인 기록만, 완료 시 펫 지급 |
| PET-5 | 펫 화면(장착·숨기기) | not-started | S | 개발 | 아이템/가방 맨 위 펫 줄 또는 장비창 펫 칸, 장착·숨기기 버튼, 아이콘 Config.UIArt 연결 |
| PET-6 | 펫 획득 전체 알림 | not-started | S | 개발 | 펫 알림 문구·등급색, 지급 때 AnnounceService.Announce 호출, 묶기 규칙 재사용 |
| QC-6 | S5 철 무기 장만 | cut | 0 | 사용자(결정 완료) | 없음 |
| QC-7 | 이야기 검증 묶음·30분 실측 | not-started | L | 개발 (검수가 증거로 재확인) | 오프라인 테스트(중복 보상 0, 재접속 단계 유지, S0 안 해도 정상, 환생·직업 변경 반복 지급 없음, 진영 변경 서브 빠짐, 장인 경로), 새 세이브 30분 실측(직업 3·빛/뿔/장인·PC/폰: 분당 처치, Lv5/Lv10 시각, 60초+ 공백), 749×361 한 줄·5행 스크린샷, 3클라 왕 슬라임 쟁탈 |
| QC-8 | 옛 흔적 정리 | partial | S | 개발 | '왕 슬라임'으로 통일, 지역 해금 토스트와 M2-7 대화를 한 번만 |
| HW-2 | Config.Halloween·계절 스폰 계산 | in-progress | S | 개발 | HW-10 테스트 통과, Studio에서 지역 총수가 시즌 켜도 같은지 확인, 커밋 |
| HW-3 | 호박 슬라임 | in-progress | S | 개발 | Studio 스폰·말랑 움직임·앞 방향·퀘스트 집계 확인 (HW-11 안에서) |
| HW-4 | 꼬마 유령 | in-progress | S | 개발 | 떠 있는 모습·맞기 반응 Studio 확인 (HW-11 안에서) |
| HW-5 | 박쥐 고블린 | in-progress | S | 개발 | 클립 5개 Studio 동기화·재생 확인, 앞 방향 180°, 커밋 |
| HW-6 | 호박 대왕 미니보스 | in-progress | M | 개발 | 실제 싸움 측정(혼자 약 4분·3명 약 70초 가정), 처치·떠남 판정, Lv1 신규가 많은 초원에서 체감 확인 |
| HW-7 | 사탕 재료·핼러윈 드랍 | in-progress | S | 개발 | 사탕 아이콘 연결(HW-12), 커밋 |
| HW-8 | 호박 대왕 타이머 칩 | in-progress | S | 개발 | PC·폰(749×361) 배치 스크린샷, 거위·괴수 칩과 겹침 확인 |
| HW-9 | 핼러윈 서버 알림 | in-progress | S | 개발 | 채팅 줄·토스트 Studio 확인(오프닝·첫 임무 중 토스트 생략), 문구 말투 규칙 맞춤 |
| HW-11 | 핼러윈 Studio 반영·플레이·커밋 | not-started | M | 개발 | sync_to_studio(Play 멈춤 먼저 알림), apply_studio_state 재실행(FRONT_FIX), 직접 플레이(스폰·대왕·칩·알림·드랍), src·tools 경로별 커밋, 이후 place 저장·해시·복사·커밋 |
| HW-12 | 사탕·몬스터 머리·펫 아이콘 연결 | partial | S | 개발 (+검수: 쓸 곳 결정) | Config.UIArt.Parts 등록, 사탕 줄·드랍 목록 몬스터 줄·대왕 칩에 표시, 몬스터 머리 아이콘 쓸 곳 결정 |
| A23-19 | 기본 RPG 시스템 베타 필수(묶음) | partial | XL | 개발 | BB13·BB3·BB6·BB7·BB9·BB8·BB37·BB10·BB11·BB12·BB14·BB15(BB38은 P6로 대부분 끝)가 남음. 세부는 BB 영역 항목에서 따로 센다. |
| A23-19-halloween | 핼러윈 몬스터 베타 포함 | in-progress | M | 개발 | Studio 반영·플레이 확인, test_halloween 증거 저장, 커밋. 시즌 끄는 날짜(종료 플래그) 정하기. |
| A23-21-keys | 키 설정(PC 키보드만 원하는 대로) | partial | M | 개발 | BB13(Panels.Register)·BB3 설정 창(키 줄·[비우기]·초기화, 오프닝 다시 보기·이름 숨기기 이동)이 없다. |
| A23-21-tab | Tab 목록 골드 숨김·전투력 표시 | not-started | S | 개발 | 골드 열 삭제, 전투력·레벨·환생·명성 열(BB12 계약), 진영 바뀔 때 명성 갱신 확인. |
| A23-22-weekly | 주간 명예·악명 1~3위 같은 보상 | not-started | M | 검수(계약) + 개발 | BB10 계약에 보상 추가(검수) → 월요일 0시(KST) 주간 1~3위 확정 기록, 다음 주 동안 능력치 없는 순위 칭호(TitleService, 기간 만료), 경험치 +10%(ProgressionService), 드랍 +10%(LootService, 대박 제외), 깡패 벌칙과 겹칠 때 곱셈 순서 정하기. |
| A23-22-guild | 장인 길드 주간 사냥판 같은 보상 | cut | 0 | 사용자 (결정 완료) | None. 검수 should state in help text (BB15) that the guild has no weekly reward. |
| P2 | 자리 비움 15분 자동 쉼 | cut | 0 | 개발 | 없음(코드는 꺼진 채 유지) |
| P10 | 핼러윈 FOMO 방지 문구 | in-progress | S | 검수(문서) + 개발(문구) | 게임 글자에 '매년 돌아와요' 한 줄(도움말·시즌 안내), 놓친 아이가 나중에 얻는 길(사탕→정식 장인 제작 등)을 문서에 적기. |
| ART-G0 | HUD 회색 상자 배치 시안 승인 | in-progress | S | 검수 (draft) → 사용자 (approval) | 1) Write layout.json for PC 1280x720, phone 749x361 and 844x390, and tablet. It must place: the status plate with the power box, the war meter with chips under it, the [가방][지도][메뉴] row, the quest panel that folds below h… |
| ART-G1 | HUD 재배치 실제 적용 | not-started | L | 이미지 개발 | Same work as audited: after ART-G0 approval, move HUD, EventHUD and VitalsUI to the approved gray box, replace the 3D zone sign with a chip, add the fold below height 560, and fix the BB5 phone overlap. The work is done … |
| ART-I0 | 승인 아이콘 7장 게임 연결 | partial | S | 개발 | 1) Add 7 keys of 512x512 to UIArt.Parts. 2) Point QUEST_ICON at a head icon per monster (IconMonSlime and others), then delete the old UIP_IconSlime file and its ID. 3) Connect Candy through the BB6 ItemView IconKey. 4) … |
| ART-R1 | 메뉴 버튼 아이콘 5장 (가방·내 캐릭터·스킬·랭킹·도움말) | partial | S | 이미지 개발 | Add 5 UIArt.Parts keys with Size 512. Connect them to the HUD [가방] button (BB7) and the menu entries of BB13, BB8, BB9, BB11 and BB15. Commit asset_ids.json. Check in Studio at 1280×720 and 749×361 on light and dark back… |
| ART-R3 | 재료 6장 + 주문서 1장 아이콘 | in-progress | S | 이미지 → 사용자 → 이미지 개발 | Cut out the 6 materials and make check sheets. Write a new scroll prompt (white or pale, tinted in code) and generate it. User approves the sheet. Upload. Add an Icon key to Loot.Items or the BB6 ItemView. Connect the ba… |
| ART-B1 | 묶음 1 스타일 보드 (마스터 6칸×4안) | not-started | M | 이미지 → 사용자 | 1) Generate 6 slots x 4 candidates (about 24 images) and put them on one sheet with the approved pet, monster and menu icons. 2) Compare the grade-slot inner colour with 3 real icons at 48px. 3) User approves. 4) Each ap… |
| ART-B2 | 묶음 2 진영 화면 빈 카드·제목·설명판·하단 + 직업 카드 틀 9장 + 코드 | not-started | L | 이미지 → 사용자 → 개발 | 1) Generate 3 blank faction cards, title, premise panel and footer, using the FreshTyped cards with the text removed as structure reference. 2) Generate 3 class card frames as 3:4 arches. 3) User approves; the horns card… |
| ART-B3 | 묶음 3 진영 특성 아이콘 10장 | not-started | S | 이미지 → 사용자 → 개발 | 1) Make a sibling sheet of 10 icons with the iron-sword master as style reference. 2) User approves. 3) Upload. 4) Put Id and Size on the existing keys. 5) Set FactionE.BakedPerkIcons=false. 6) Check the faction screen. |
| ART-B4 | 묶음 4 직업 선택 능력 아이콘 + 공통 창 1 (판·머리띠·리본·버튼) | not-started | M | 이미지 → 사용자 → 개발 | 1) Draw Icon_Safe, Hammer, StatSpeed and StatAttack. 2) Draw 6 9-slice parts (PanelMain, PanelDark, PanelHeader, TitleRibbon, BtnPrimary, BtnSecondary) with a flat center and left-right symmetry. 3) Measure slices with p… |
| ART-B5 | 묶음 5 공통 창 2 + HUD 상태판·바 | not-started | M | 이미지 → 사용자 → 개발 | 1) Make a 3-colour button sibling sheet. 2) Draw ListRow, a new Chip key (keep Pill), DialogBox, GlyphClose, StatusPlate, BarTrack and a white BarFill. 3) Upload. 4) Change VitalsUI colours: HP green, MP royal blue, XP s… |
| ART-B6 | 묶음 6 HUD 전투 버튼·레벨 배지 4·직업 글리프 | not-started | M | 이미지 → 사용자 → 개발 | 1) Draw PortraitRing and check the hole after cutout, orange BtnAttack, BtnSkill, BtnPotion, 4 faction LevelBadges, GlyphSword and GlyphStaff. 2) Upload. 3) Change COL.AttackFill from red to orange. 4) Let the level badg… |
| ART-B7 | 묶음 7 버튼 줄 글리프 + 등급 칸 6 | not-started | M | 이미지 → 사용자 → 개발 | 1) Make a sibling sheet: GlyphBow, Bag, Map, Menu, the 5 grade slots and the empty slot. 2) Upload. 3) Connect the slots to the bag (BB7), blacksmith and drop cells; only Legendary gets the UIGradient shine. 4) Delete th… |
| ART-B8 | 묶음 8 별·HP/MP 물약 아이콘 | not-started | S | 이미지 → 사용자 → 개발 | 1) Jelly and the scroll move to ART-R3. That leaves UIP_Star (one image tinted in code), Item_PotionHP and Item_PotionMP: 3 images. 2) Upload. 3) Replace IconStar and IconStarEmpty. 4) Connect the potion button and the p… |
| ART-B9 | 묶음 9 젤리 왕관 T8 무기·상태 아이콘 | partial | M | 이미지 → 사용자 → 개발 | 1) Draw 7 images: Weapon_Warrior_T3 (iron-sword master from B1), Weapon_{Warrior,Mage,Archer}_T8, Icon_Coin, Icon_Sprout, Icon_WantedStar. 2) Upload at 512. 3) In one commit: new keys Weapon_<Class>_T8 and Config.Weapons… |
| ART-B10 | 묶음 10 직업 그림 9장 (로블록스 스타일, 단정한 옷) | not-started | L | 이미지 → 사용자 → 개발 | 1) Start from the CLS_HaloWarrior_M master (B1). 2) Draw the other 8; female characters use the male master as structure reference (about 70). 3) Check every image: shoulders, torso, midriff and legs covered. 4) User app… |
| ART-B11a | 묶음 11 안내자 초상 3장 | not-started | S | 이미지 → 사용자 → 개발 | 1) Draw PTR_GuideHalo, PTR_GuideHorns and PTR_GuideArtisan as 170px portraits, with the modest-clothing line in each prompt. 2) User approves. 3) Upload. 4) Connect the portrait in Panels to the new keys. 5) Play the gui… |
| ART-B11b | 게임 아이콘·썸네일 (체험 페이지) | not-started | M | 이미지 → 사용자 | 1) Draw 3 icon options (High quality, 5 credits each) and compare them on a 512px/150px sheet; the user picks 1. 2) Draw thumbnails Thumb_A (light vs horns) and Thumb_C (Halloween) at 1920x1080, matching the real beta (b… |
| ART-DEL1 | 안 쓰는 옛 그림 즉시 삭제 (남은 분) | partial | S | 개발 (검수 confirms the list) | 1) Mark the 78 files as delete in the cleanup list. 2) git rm them by explicit path. 3) Mark those lines in asset_ids.json as 'deleted'. 4) Clean up the untracked old prompts (UI_FactionParts_*, UI_Icon*_Redraw, NPC_Equi… |
| ART-DEL2 | 게임 속 옛 그림 교체 시 삭제 (묶음마다) | partial | S | 개발 | 1) For every bundle: after the swap and the Studio check, delete the old file, mark its asset_ids line and set 'deleted' in approved.json. 2) Write a list of old art still left after the beta (terrain, T7, Fx and others)… |
| ART-SAFE | 새 계정 업로드 안전 재점검 (사람 그림) | partial | S | 검수 | Before 10/24: 1) Compare every ID uploaded on the new account with approved.json and confirm 0 unapproved uploads. 2) Check the human images one by one for modesty and record it: class art 9, guide portraits 3, thumbnail… |
| A23-23-OUTLAW | 주간 정산 + PvP 1~3위 무법자 벌칙 | not-started | M | 개발 | 1) Weekly settle: the first server loop with a new WeekIndex reads last week's top 3 per board (Global, falling back to this server), writes 'HH_RankSettle_<WeekId>' once so every server applies the same list, and applie… |
| SESS-UISANDBOX | 이미지 개발 세션 연습 Studio·파일 주인 규칙 | not-started | S | 이미지 개발 (+검수 for AGENTS) | Copy build/GoodEvil.rbxlx to build/UiSandbox.rbxlx and open it as a second Studio. Check that tools/studio_mcp.py and sync_to_studio.py honor STUDIO_NAME and never pick the main Studio. Agree file ownership for the share… |
| LAUNCH-OPS | 베타 공개 당일 절차·장소 설정 체크리스트 | not-started | S | 검수 (문서) + 사용자 (Publish·Public) + 개발 (Season·플래그) | Write one Korean checklist covering: - Game Settings: MaxPlayers 20, avatar R15 (or the BM1 decision), private servers off (P11), devices including phone, genre. - Config.Ranking.Season PRE → B1. - Config.Halloween.Enabl… |
| LIVE-TEST | 비공개 게시본으로 실서버·실기기 확인 | not-started | M | 사용자 (Publish OK·폰·두 번째 계정) + 개발 | The user OKs a Publish to the private place (never Public). At least one round before 10/24 and one in 10/25-30. Use 2 accounts (one older than 7 days) plus a phone. Record results under verification_2026-10-2x/. |
| OPS-WEEKLY | 매주 토요일 남은 필수·날짜 위험 보고 | not-started | 0 | 검수 (+개발 numbers) | A short Korean report each Saturday (done / remaining / cut candidates) aligned with the 10/12, 10/17 and 10/20 checkpoints (A23-21-cut). Send it to the user's phone with SendUserFile or a message. |
