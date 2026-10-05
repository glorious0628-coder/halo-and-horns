# 베타 기본 RPG 시스템 계약 (2026-10-05, A23-19)

사용자 결정(A23-19): "스킬창, 인벤토리, 장비창, 캐릭터 전투력, 랭킹 시스템, 키세팅(원하는 대로) + 그 밖에 기본적인 것도 md에 넣어서 베타 전까지"

- 만든 과정: 영역 5개 코드 감사 + 외부 조사 → 계약 작성 → 비평 3개(빠진 것, 실현성·충돌, 안전·공정) → 최종본. 원자료: `beta_basics_2026-10-05.json`.
- **우선순위:** 이 문서는 SPEC_ADDENDUM A23-19의 세부 계약이다. A23의 다른 결정과 부딪히면 A23이 먼저다.
- **사용자 확인 대기:** 아래 §4의 질문(일정·키 범위·Tab 열·랭킹 규칙)에 답이 오면 이 문서와 A23에 적는다. 그 전에는 해당 부분을 추천안으로 만들지 말고, 답에 영향받지 않는 항목부터 한다.

## 1. 요약

사용자가 말한 6개(스킬창·가방·장비창·전투력·랭킹·키 설정)와, 빠져 있던 기본 기능을 베타 계약 하나로 묶은 최종본이다. 비평 3건의 높음·중간 지적을 모두 반영했다.

바뀐 점:
- BB17(자리 비움 자동 쉼)을 뺐다. A23-20 '계속 사냥'(SPEC_ADDENDUM.md:91-96, Config.luau:394 AutoIdleRest=false)과 부딪힌다. 대신 Roblox 20분 무입력 퇴장 예고(BB39)를 넣었다.
- BB27(원한 골드 우편)을 뺐다. 커밋 735419e에서 GrudgeService MAIL로 이미 들어갔다.
- 키 설정:
  - G 키가 겹치던 문제를 풀었다. 커밋된 GrudgeGhost.luau:79가 G를 고정으로 쓰고 있었다. 이제 가방은 G, 유령 붙잡기는 T이고, 모든 키를 Keybinds 한곳에서 다룬다.
  - 키 비우기, F1~F8·숫자패드·기호·Ctrl·Alt를 쓸 수 있다.
  - 창 키를 다시 누르면 그 창이 닫힌다.
  - 새 기본 키가 내 키와 겹쳐도 내 키는 지워지지 않는다.
  - 서버의 1초 제한 때문에 마지막 변경이 되돌아가지 않도록 Seq 번호를 붙인다.
- 전투력 상한: 8티어(젤리 전설, 공격력 76, Config.luau:186)는 가장 센 무기가 아니다. 그래서 상한을 Config.MaxCombatPower()=25,488로 바꿨다. 공식으로 직접 계산해 확인했다.
- 랭킹:
  - 주간 명예·악명 점수는 공정한 PvP에서만 준다. 친구, 자리 비움, 약한 상대, 같은 상대 반복은 빠진다. 털기 자루 점수도 KO 순간에 판정한다.
  - 장인 길드도 들어갈 수 있는 주간 '사냥' 판을 추가했다.
  - 최고값은 시즌마다 따로 센다. 디버그·테스트 저장은 빠지고, Studio 시험용 우회가 있고, 사설 서버는 세지 않는다.
  - 시즌 이름은 베타 전에는 PRE, 베타 날 B1이다.
- 이름 숨기기: 서버 전체 알림 모두에 적용한다(BB37 PublicName).
- 창 구조:
  - Panels.Register에 인자 전달, 정리 훅, 일부만 다시 그리기를 넣었다.
  - Items는 파일을 나누는 대신 기존 표를 내보내기만 한다.
  - 장비창의 3D 몸 미리보기는 권장(BB8b)으로 옮겼다.
- 가방에 골라 팔기를 넣었다. '모두 팔기'는 일반 재료만 판다.
- 새로 넣은 기본 기능: 베타 지표(P6, BB38), 의견 보내기, 데이터 삭제 절차, '베타에 안 넣는 기본 기능과 이유' 목록.

일정: 필수만 명목 약 16일이다. 펫·Z·핼러윈과 합치면 남은 19일에 다 들어가지 않는다. 그래서 지금 순서와 빼는 순서를 정하고, 점검일을 10/12·10/17·10/20으로 앞당겼다. 사용자에게는 일정·범위·PvP 공정성·보상 다섯 가지만 묻는다.

## 2. 순서와 일정

**만드는 순서:** BB0 → BB16 → BB4 → BB5 → BB1 → BB2 → BB13 → BB3 → BB6 → BB7 → BB9 → BB8 → BB37 → BB10 → BB11 → BB12 → BB14 → BB15 → BB38 → BB39 → BB3b → BB24 → BB21 → BB18 → BB19 → BB20 → BB25 → BB8b → BB41 → BB40 → BB26 → BB28 → BB23 → BB29 → BB22 → BB30 → BB31 → BB32 → BB33 → BB34 → BB35 → BB36

[남은 날]
- 오늘은 10/05이고, 기능 마감 10/24(토)까지 약 19일 남았다.
- 10/25~30은 테스트와 버그 수정만 한다(RELEASE_PLAN.md:28).

[작업량]
작업 세션 1개 기준이다. 동기화(Play 중지는 한국어로 먼저 알림), MCP 플레이 확인, 749×361·1280×720 확인을 포함했다(S=반나절, M=1일, L=2일).
- 베타 필수 19개: 명목 약 16일
  - BB0·BB16·BB4·BB5·BB6·BB37·BB12·BB14·BB15·BB38: S 10개, 5일
  - BB1·BB2·BB13·BB3·BB9·BB8·BB11: M 7개, 7일
  - BB7·BB10: L 2개, 4일
- 비평을 반영해 줄인 것:
  - BB17 삭제: A23-20과 충돌한다.
  - BB27 삭제: 735419e에서 이미 구현됐다.
  - BB6: 리팩터 대신 내보내기만 한다. 약 1일 절약.
  - BB8: 3D 몸 미리보기를 BB8b로 뺐다. 약 1일 절약.
  - 설정의 피해 숫자·이름표 줄은 BB3b로 뺐다.
  - BB22는 정식으로 옮겼다.
- 베타 권장 15개: 약 9~10일.
- 이미 잡힌 마감 전 작업:
  - 진행 중인 퀘스트 사슬
  - 아기 슬라임 펫 2~3일
  - Z 스킬 5~6일
  - 핼러윈 몬스터(Tripo는 사용자가 '아직 노노')
  - 6단계 Firefly 교체와 HUD 재설계
  - 물약 상점 마무리, 폰 점검, 3명 테스트, 영어
- 필수 16 + 펫 2.5 + Z 5.5 = 약 24일로, 19일을 넘는다. 그래서 10/20까지 기다리지 않고 지금 순서와 빼는 순서를 정한다.

[순서]
1. 지금 하는 퀘스트 사슬 한 덩어리를 끝낸다. 그동안 A23-18 묶음의 '베타 개척자'는 BB16 데이터 모양(Titles·TitleSel·SetTitle)으로 바로 만든다.
2. 기본 필수를 이 순서로 넣는다: BB0 → BB4·BB5 → BB1(GrudgeGhost G 고정부터 해제)·BB2·BB13·BB3 → BB6·BB7 → BB9 → BB8 → BB37 → BB10·BB11·BB12 → BB14·BB15·BB38.
   - 항목마다 '작게 고치기 → 동기화 → 직접 플레이 → 보고' 한 바퀴로 끝낸다.
   - 새 모듈 파일은 먼저 Studio에 넣고, 그다음 ClientMain ORDER와 Main INIT/START 목록에 추가한다.
3. 아기 슬라임 펫은 BB7·BB8 다음에 넣는다. 그러면 가방 [장비] 탭과 캐릭터 펫 칸의 EquipPet 계약을 그대로 쓴다.
4. Z 스킬은 BB9의 Config.Skills를 같이 쓰므로 BB9 다음에 붙인다. 기본 필수가 10/17까지 끝났을 때만 시작한다.
5. Firefly 그림은 승인 대기가 길어서 기능 작업과 나란히 돌린다. 6단계 HUD 회색 시안에는 [가방][지도][메뉴]와 상태판 전투력 칸을 처음부터 넣는다. 그래서 BB5·BB7의 HUD 변경은 임시 최소 변경으로만 한다.
6. 권장 항목은 위 order 순서대로 남는 날에 넣는다. BB39(20분 예고)와 BB24(첫 안내)는 작아서 먼저 한다.

[점검일]
- 10/12: BB0~BB7이 끝났는지 본다. 실제 속도로 남은 일을 다시 계산한다.
- 10/17: 필수가 다 끝났는지 본다. 끝났으면 Z를 시작하고, 아니면 Z 플래그를 끈 채로 둔다.
- 10/20: 최종으로 뺄 것을 정한다.

[늦으면 빼는 순서 제안 — 사용자 질문 1]
- ① 영어 → 정식 ② Z 플래그 끄기 ③ 핼러윈 몬스터 수 줄이기: 이미 정한 것이다(RELEASE_PLAN.md:55).
- ④ 못 끝낸 권장 기본 기능 → 정식.
- ⑤ 전체 랭킹을 '이 서버 랭킹 + 마을 게시판'으로 줄이기. 약 1.5일을 아낀다.
- 사용자가 직접 말한 6개(스킬창·가방·장비창·전투력·랭킹·키 설정)는 줄인 모양으로라도 반드시 남긴다.

## 3. 기능 목록

| ID | 이름 | 우선 | 크기 | 사용자 요청 |
|---|---|---|---|---|
| BB0 | 문서 정리 + 새 모듈 공통 규칙 + '베타에 안 넣는 기본 기능' 목록 | beta-must | S |  |
| BB16 | 칭호 보관·선택 + 베타 개척자 | beta-must | S |  |
| BB4 | 전투력 숫자 하나 (서버 계산) | beta-must | S | 예 |
| BB5 | HUD 전투력 표시와 상승 알림 | beta-must | S | 예 |
| BB1 | 키 지도 한곳 관리 (Keybinds 모듈) | beta-must | M | 예 |
| BB2 | 설정 저장 (SettingsService, 서버 검증) | beta-must | M | 예 |
| BB13 | 메뉴 정리 + 새 창 등록 통로 (Panels.Register) | beta-must | M |  |
| BB3 | 설정 창 + 키 바꾸기 (원하는 대로) | beta-must | M | 예 |
| BB6 | 아이템 공용 접근 (Panels.Items 내보내기 + Config 보기 함수) | beta-must | S | 예 |
| BB7 | 가방 창 + HUD [가방] 버튼 + 골라 팔기 | beta-must | L | 예 |
| BB9 | 스킬 정의 + 스킬창 | beta-must | M | 예 |
| BB8 | 내 캐릭터·장비창 (무기 칸, 펫 칸, 칭호, 능력치) | beta-must | M | 예 |
| BB37 | 이름 숨기기 한곳 처리 (PublicName) | beta-must | S |  |
| BB10 | 랭킹 서비스 (이 서버·전체, 시즌·주간, 공정 점수) | beta-must | L | 예 |
| BB11 | 랭킹 창 + 마을 게시판 대칭 | beta-must | M | 예 |
| BB12 | 플레이어 목록(Tab) 열 정리 | beta-must | S | 예 |
| BB14 | 쓰러짐·부활 화면 | beta-must | S |  |
| BB15 | 도움말(게임 방법) + 베타 안내 + 안내자 다시 만나기 | beta-must | S |  |
| BB38 | 베타 지표 (P6 퍼널, AnalyticsService) | beta-must | S |  |
| BB39 | Roblox 20분 무입력 퇴장 예고 | beta-should | S |  |
| BB3b | 피해 숫자·다른 사람 이름표 설정 | beta-should | S |  |
| BB24 | 처음 겪는 순간 한 줄 안내 (P8②) | beta-should | S |  |
| BB21 | 게임패드 기본 배치 | beta-should | S |  |
| BB18 | 퀘스트 일지 | beta-should | S |  |
| BB19 | 알림 기록 | beta-should | S |  |
| BB20 | 다른 플레이어 살펴보기 + 차단 바로가기 | beta-should | S |  |
| BB25 | 친구 초대 버튼 | beta-should | S |  |
| BB8b | 장비창 3D 아바타 미리보기 | beta-should | M | 예 |
| BB41 | 베타 의견 보내기 | beta-should | S |  |
| BB40 | 데이터 삭제 요청 처리 절차 | beta-should | S |  |
| BB26 | 명예의 전당 게시판 (교차로·성채·소굴) | beta-should | M |  |
| BB28 | PvP 센 상대 표시 + 깡패 직전 경고 | beta-should | M |  |
| BB23 | 배경 음악 + 효과음 묶음 | beta-should | M |  |
| BB29 | 언어 선택 줄 (자동/한국어/English) | beta-should | S |  |
| BB22 | 스킬별 자동 사용 켜기/끄기 | launch | S |  |
| BB30 | 코드 입력 | launch | S |  |
| BB31 | Roblox 배지 | launch | S |  |
| BB32 | 출석 달력 | launch | S |  |
| BB33 | 로딩 화면 | launch | S |  |
| BB34 | 편의 묶음 (UI 크기, 폰 버튼 위치, 스킬 툴팁) | launch | M |  |
| BB35 | 지도 목표·친구 표시 | launch | S |  |
| BB36 | 이번 판 영웅 + 랭킹 확장 | launch | S |  |

### BB0. 문서 정리 + 새 모듈 공통 규칙 + '베타에 안 넣는 기본 기능' 목록 (beta-must, S)

**플레이어가 보는 것:** 플레이어에게 보이는 변화는 없다. 작업 세션과 검토 세션이 같은 규칙을 보고, 사용자는 무엇을 일부러 뺐는지 한눈에 본다.

**지금 상태:** RELEASE_PLAN.md:51과 SPEC_ADDENDUM.md:101(A23-19)이 docs/design/beta_basics_2026-10-05.md를 가리키지만, 이 파일은 아직 없다.

서로 맞지 않는 문서:
- 가방: GDD.md:386이 '가방 없음'이다. A23-12의 가방 줄과 Config.Loot 주석('no bag screen')도 마찬가지다.
- 랭킹: GDD.md:449는 전체 랭킹을 v1.4로 미뤘다.
- 전투력: GDD.md:255·:265의 정의가 서로 다르다.

이미 끝났거나 대체된 계획:
- mmorpg_painpoints_ideas_2026-10-05.md:35 P2는 A23-20(SPEC_ADDENDUM.md:91-96)으로 대체됐다. 코드는 5c977d6에 있고 89bf690에서 껐다.
- P3 원한 우편은 735419e에서 끝났다(GrudgeService MAIL, 주석 '잃을 수는 있어도 두 번 주지 않음').
- P7 드랍 표는 2fde077에서 아이템 목록에 들어갔다.

HANDOFF_CODEX.md:9는 '베타 개척자'를 A23-18 묶음에 넣었지만 데이터 모양은 정하지 않았다.

**계약:**

Docs only, no code.

Write this spec to docs/design/beta_basics_2026-10-05.md. Cite functions and identifiers, not line numbers (lines drift under active edits).

Mark these as superseded by A23-19:
- GDD.md:386, the A23-12 bag line and the Config.Loot 'no bag screen' comment: the bag exists; ground pickup is still not added.
- GDD.md:449: the global ranking moves to beta. The cross-server crown war stays in v1.4.

Rename the GDD.md:255 faction sum to '진영 힘'. From now on '전투력' means only Config.CombatPower (BB4).

TECH_SPEC:
- The GetCombatPower comment now includes enhance.
- §4.13: town board gets Infamy TOP3 and PublicName (BB37).
- §4.14: grudge mail as built in 735419e. Rule: 'a crash may lose a letter, never double-pays'.

mmorpg_painpoints status:
- P2 → '대체: A23-20, AutoIdleRest=false'.
- P3 → '완료 735419e'.
- P7 → '완료 2fde077 → 가방 재료 탭으로 이동(BB7)'.

visual_direction_2026-10-05.md: add a power slot to the status plate and [가방] to the right rail.

Add a section '공통 규칙(새 모듈)':
1. Never yield in Init/Start. Bind remotes with FindFirstChild, else task.spawn(WaitForChild(name, 30)), the same as ITEMS.Bind.
2. New state goes into tables. HUD, Fx, WorldMap and Panels each stay under 200 top-level locals.
3. Korean text goes in Config.*.Text with *En keys.
4. Use existing UIArt parts and UIKit code fallbacks only.
5. Put a new module file into Studio before adding it to an ORDER/INIT list. Remove it from the lists before deleting the file.
6. Every acceptance check is marked either 'MCP 확인' or '사용자 실기기 확인'.

Add a section '베타에 안 넣는 기본 기능과 이유', one line each:
- 파티·길드: GDD.md:450 '이후'.
- 1:1 거래: the ban stays; the auction house comes at launch (A23-13).
- 갑옷·장신구 칸: no design yet (user question 2).
- 스킬 레벨·포인트: no design yet.
- 미니맵: A12.
- 진영 채팅: Roblox /t team chat already works; one line goes in BB15 help.
- 그림 도감: the P7 text table stands in.
- 폰 버튼 배치와 패드 키 바꾸기: BB34 and BB21 (user question 2).
- 스킬별 자동 끄기: BB22. It changes the A23-1 contract, so it waits for launch.

Send BB16's data shape to the worker now (the A23-18 bundle is in progress).

**키·폰:** 해당 없음

**먼저 필요한 것:** 없음

**합격 확인:**
- docs에서 '가방 없음'을 grep하면 A23-19 대체 표시가 붙은 줄만 나온다.
- '전투력' 정의가 문서 전체에 하나뿐이다(Config.CombatPower, 환생 제외).
- P2·P3·P7 줄에 대체·완료 표시가 있다.
- '베타에 안 넣는 기본 기능과 이유' 절이 있고, 줄마다 이유가 적혀 있다.

### BB16. 칭호 보관·선택 + 베타 개척자 (beta-must, S)

**플레이어가 보는 것:** 베타에 들어온 모든 사람이 능력치 없는 '베타 개척자' 칭호를 받는다. 내 캐릭터 창에서 이름표에 띄울 칭호를 고른다: 자동(진영 계급), 베타 개척자, 회색 전설 등. 고른 칭호는 다시 들어와도 그대로다.

**지금 상태:** 칭호는 자동으로만 정해진다. 하나는 진영 계급이고(Config.Titles, Config.DisplayTitle), 다른 하나는 KaijuService의 세션 칭호다. A23-18(SPEC_ADDENDUM.md:108)에서 '베타 개척자'를 약속했지만 src를 grep하면 0건이다. 작업 세션이 A23-18 묶음으로 곧 만들 예정이다(HANDOFF_CODEX.md:9).

**계약:**

Data (additive, Version stays 3):
- Titles = {} as [id] = os.time().
- TitleSel = '' (add to Mirrored).

Config:
- Config.TitleDefs = { BetaPioneer = { Name='베타 개척자', NameEn='Beta Pioneer', Color }, GrayLegend = {...} }.
- Config.Beta = { GrantPioneer = true, PioneerUntil = 1797645600 } (2026-12-19 11:00 KST).

Grant: PlayerService grants BetaPioneer on PlayerReady while GrantPioneer is true and os.time() < PioneerUntil.

Remote c→s 'SetTitle'(id):
- id is a string of 32 chars or fewer: an owned id, or '' for automatic.
- select('#') == 1, PlayerService.IsReady, RateLimits.SetTitle = 0.5.
- Anything else is ignored.

Display:
- Config.DisplayTitle gains a selected param. Order: session > selected > gray legend > rank.
- CharacterVisuals adds TitleSel to its REBUILD map.
- The HUD stats title uses the same function.
- Titles never give stats.

Schedule: grant and display ship now with the A23-18 bundle. Only the picker row waits for BB8.

**키·폰:** 모든 기기에서 내 캐릭터 창의 칭호 줄을 눌러 고른다.

**먼저 필요한 것:** 고르는 줄은 BB8

**합격 확인:**
- 새 계정으로 들어오면 칭호 목록에 '베타 개척자'가 있다.
- 칭호를 고르면 이름표 두 번째 줄이 바뀌고, 다시 들어와도 유지된다.
- 가지지 않은 칭호 id를 보내면 무시되고, 능력치는 변하지 않는다.

### BB4. 전투력 숫자 하나 (서버 계산) (beta-must, S)

**플레이어가 보는 것:** '전투력'은 숫자 하나다. 레벨과 무기(강화 포함)로 정해지고, 같은 레벨에 같은 무기면 누구나 같은 숫자다. 예: Lv1 시작 무기 283, Lv5 철 무기 758, Lv10 철 무기 +3 1,052, Lv20 5티어 2,829. 무기는 등급 번호가 아니라 공격력 순서대로 센다. 그래서 전설 젤리 무기(공격력 76)는 4티어(88)보다 전투력이 조금 낮게, 있는 그대로 나온다.

**지금 상태:** 공식은 Config.PowerOf(Config.luau:588)다.

JusticeService.GetCombatPower(:197):
- 환생을 빼고 계산한 실수다.
- 두 규칙의 기준이다: 깡패 판정(Config.Bully.WeakPowerRatio 0.5, Config.luau:599)과 대담함 배율(PvPService.BoldMult :216, BoldStrongRatio 1.2, Config.luau:635, 커밋 c08c382).
- 화면에는 나오지 않는다.

무기 상한 문제: Config.MaxWeaponTier = #Config.Weapons = 8(Config.luau:188)이다. 그런데 8티어는 공격력 76인 젤리 전설(:186)이라 '가장 센 무기'가 아니다.

공식으로 직접 계산한 값:
- 283 / 387 / 758 / 1,052 / 2,829
- Lv1 8티어 872, Lv1 4티어 938
- Lv100 7티어+10 25,488
- 잘못된 상한 7,027

**계약:**

Config:
- Config.Power = { DisplayScale=10, Text = { Label='전투력', LabelEn='Power', Formula='레벨과 무기(강화 포함)로 정해져요', PvPNote='무기 공격력 차이가 커도 PvP 피해는 최대 1.5배, 최소 0.8배예요', Up='전투력 +%s' } }, with En keys alongside.
- Config.Bully.Text = { Title='깡패가 되는 경우', Lines built with string.format from WeakPowerRatio, FreshSpawnSeconds and RepeatKOs/RepeatWindow: '내 전투력 절반보다 약한 상대를 쓰러뜨릴 때', '막 부활한 상대(15초 안)를 쓰러뜨릴 때', '같은 상대를 10분 안에 3번 쓰러뜨릴 때' }. BB8, BB15, BB24 and BB28 share it.
- Config.CombatPower(level, tier, enhance) = math.floor(Config.PowerOf(level, tier, 1, enhance) * DisplayScale + 0.5). It leaves out class, faction, rebirth, Size Justice, bully, buffs and pets.
- Config.MaxCombatPower() = max over t = 1..MaxWeaponTier of CombatPower(Levels.MaxLevel, t, Loot.MaxEnhance), cached (25,488 today).
- Rule: anything that means 'strongest weapon' sorts by Config.Weapons[t].Damage, never by tier index.

JusticeService:
- GetCombatPower returns this integer. The bully test and BoldMult compare it; their ratios do not change.
- GetPower stays as it is ('진영 힘').
- onPlayerReady connects GetAttributeChangedSignal for Level, WeaponTier and WeaponEnhance to one task.defer-coalesced refresh, because LootService writes WeaponEnhance after WeaponTier.
- The refresh calls player:SetAttribute('CombatPower', n). Disconnect on leave.

No save field: the season best lives in BB10 data.Rank.

Client: read the attribute, and fall back to Config.CombatPower(attrs) before the first set.

**키·폰:** 입력 없음. 모든 기기에서 같은 숫자를 보여 준다.

**먼저 필요한 것:** 없음 (BB5·BB8·BB10·BB12의 기반)

**합격 확인:**
- 오프라인 검사(새 tools/test_beta_basics.py)에서 표본 값이 맞는다: 283 / 387 / 758 / 1,052 / 2,829, Lv1 8티어 872 < 4티어 938, MaxCombatPower()=25,488.
- 레벨 1→100, 강화 0→10으로 올리면 숫자가 늘 늘어난다. 무기는 공격력 순서로 늘어난다.
- 무기를 장착하면 CombatPower 속성이 정확히 1번 바뀐다.
- 깡패 50%와 대담함 80%·120% 경계 사례에서, 화면 숫자로 계산한 결과가 서버 판정과 같다.

### BB5. HUD 전투력 표시와 상승 알림 (beta-must, S)

**플레이어가 보는 것:** 왼쪽 위 상태판에 '전투력 1,052'가 늘 보인다.

- 전투력이 오르면 금색 '+45'가 떠오르고 숫자가 올라간다.
- 레벨업과 함께 오르면 레벨업 알림이 이미 축하하므로 '+N'은 띄우지 않고 숫자만 바뀐다.
- 내려가면(약한 무기, 주문서 실패, 환생) 조용히 숫자만 바뀐다.
- 숫자나 얼굴을 누르면 '내 캐릭터' 창이 열린다.

**지금 상태:** 상태판은 HUD.luau에 있다(데스크톱 직업 줄, 터치 금고 줄). 레벨업 알림은 Fx.announceLevelUp이다. 전투력은 어디에도 표시되지 않는다. HUD의 최상위 local은 약 144~150개, Fx는 약 170개다.

**계약:**

HUD: new state goes in the ui / L / TXT tables. No new top-level locals. No Fx change.

Layout:
- Desktop: the class line splits into the class name (left) and TXT.Power (right, gold).
- Touch: the bank row splits into 금고 | 전투력.
- If the class text gets cut off, widen L.StatsW from 280 to 300.

Refresh and tap:
- Refresh with UIKit.OnAttr({'CombatPower'}).
- A tap calls Panels.Open('Character'). This does nothing until BB8 registers the window.

L.Power popup:
- Take the baseline only after DataLoaded and ClassChosen. Merge changes within 0.4 s.
- On a rise, float '+N' and count the number up over 0.6 s (UIKit code fallback), unless the Level attribute changed in the same window.
- Drops update silently.
- While Intro.IsOpen() or a picker is open, hold one pending popup.

Result text: equip and scroll results append '전투력 923 → 968' through the item result helper (BB6).

The step-6 HUD redesign keeps a power slot.

**키·폰:** PC: 표시만 하고, 숫자나 얼굴을 클릭하면 캐릭터 창이 열린다. 폰: 금고 줄 오른쪽 절반에 보이고, 누르면 캐릭터 창이 열린다. 패드: 표시만 한다.

**먼저 필요한 것:** BB4

**합격 확인:**
- 슬라임을 잡아 레벨업하면 레벨업 알림만 뜨고, '+N' 팝업은 따로 뜨지 않는다. 숫자는 맞게 바뀐다.
- 나무 무기를 사서 장착하면 '+N' 팝업이 정확히 1번 뜬다.
- 주문서 실패, 약한 무기 장착, 환생 때는 팝업 없이 숫자만 바뀐다.
- 오프닝이나 진영 선택 중에는 팝업이 뜨지 않는다.
- 749×361과 1280×720에서 상태판 글자가 잘리지 않는다(MCP 확인).

### BB1. 키 지도 한곳 관리 (Keybinds 모듈) (beta-must, M)

**플레이어가 보는 것:** PC의 모든 키가 한곳에서 정해진다. 화면의 키 표시(F, Q, 1, 2 …)와 안내 문구('{자동} 키')는 항상 지금 키를 보여 준다.

- 새 창 키가 생긴다: 가방 G, 내 캐릭터 C, 스킬 K, 랭킹 L, 도움말 H.
- 원한 유령 붙잡기는 T로 옮긴다. G는 가방만 연다.
- 창 키를 다시 누르면 그 창이 닫힌다.
- 다른 창이 열려 있을 때 창 키를 누르면 그 창으로 바뀐다.

**지금 상태:** 키가 클라이언트 파일 5개에 Enum.KeyCode로 박혀 있다:
- HUD.luau:2970-3014: F, Q, U, R, B와 패드 R2, L2.
- VitalsUI.luau:214-215: 1, 2.
- WorldMap.luau:1768: M. 닫기는 ButtonB :1295, Escape :1350. HintMouse 문구 'M / Esc: 닫기'도 있다.
- Intro.luau:310: Return, KeypadEnter, ButtonA.
- GrudgeGhost.luau:79: G. 735419e에서 커밋됐고, 문구는 Config.Text.GhostButton '유령으로 붙잡기 (G)'(Config.luau:2114)다.

다른 문제:
- 자동 전투 안내와 퀘스트 문구에 'R키', '(R)'이 박혀 있다.
- Panels 창이 열려 있으면 HUD inputAllowed()가 false다. 그래서 B만 예외로 처리되고, 다른 키로는 창을 닫거나 바꿀 수 없다.
- 상호작용 E는 Roblox ProximityPrompt 기본값이다.

**계약:**

Config.Keybinds.Actions: an ordered list of { Id, Group ('Combat'|'Potion'|'Window'|'Other'), Key (KeyCode name or '' = unbound), Pad, Label, LabelEn, Flag?, Window? }.

Defaults:
- Attack F / ButtonR2
- SkillQ Q / ButtonL2
- SkillZ Z / ButtonL1 (Flag: Config.Skills.ZEnabled)
- Auto R / ButtonR1
- GhostHold T / DPadRight
- PotionHP One / DPadUp
- PotionMP Two / DPadDown
- Interact E / ButtonX
- Upgrade U
- Bag G
- Character C
- Skills K
- Ranking L
- Help H
- Journal J
- Map M / DPadLeft
- Menu B / ButtonY

Live rule: an action is live when its Flag is on and, for the Window group, its Panels id is registered. Non-live actions hold no key and take no part in swaps.

Key sets:
- Reserved = {Escape, Slash, Tab, Backquote, Return, KeypadEnter, Space, LeftShift, RightShift, W, A, S, D, I, O, Comma, Period, PageUp, PageDown, Up, Down, Left, Right, F9, F10, F11, F12}. The Roblox camera uses I/O, Comma/Period, the arrows and PageUp/PageDown.
- Allowed = A–Z, Zero–Nine, F1–F8, Keypad0–Keypad9, Minus, Equals, LeftBracket, RightBracket, Semicolon, Quote, BackSlash, LeftControl, LeftAlt, CapsLock, minus Reserved.
- Check each non-letter key once in a Studio Play. Any key Roblox swallows moves to Reserved.

Shared pure functions:
- Config.KeyMap(sparse, liveSet) → full action→key map, with the collision rule from BB2.
- Config.KeyLabel(name): 'One'→'1', 'LeftControl'→'Ctrl', 'Keypad1'→'Num1', ''→'없음'.

Keybinds.luau:
- New client ModuleScript. In ClientMain ORDER it goes right after 'UIKit', before Fx, VitalsUI, HUD and GrudgeGhost.
- API: Get, ActionFor, Label (returns a button name on touch-only devices), PadFor, Changed (Util.Signal), Apply(sparse), SetLocal(action, key) (swap with the live holder, which gets my old key or ''), Clear(action), Reset, IsCapturing, Capture(action, cb) (BB3), Collisions(), and Dispatch(fakeInput) (test hook used through execute_luau).

Rewire:
- HUD onInputBegan/onInputEnded dispatch through ActionFor. Keep the gameProcessed and TextBox guards.
- Window-group actions and Menu are handled before inputAllowed(): if Panels.CurrentId() == target, call Panels.Close(true); otherwise call Panels.Open(target), which switches windows.
- Every handler returns early while IsCapturing().
- HUD key badges redraw on Changed. SHOW_KEYS becomes L.ShowKeys (Settings.KeyBadges).
- VitalsUI potions use ActionFor.
- WorldMap: on Changed, UnbindAction then BindActionAtPriority with Get('Map'). HintMouse becomes '{Map} / Esc: 닫기'.
- GrudgeGhost uses ActionFor('GhostHold'). GhostButton becomes '유령으로 붙잡기 ({GhostHold})'.
- Interact: ProximityPromptService.PromptShown sets prompt.KeyboardKeyCode = Get('Interact'), re-applied on Changed. If Studio shows prompts ignore this, show the row as '고정 E' and add E to Reserved at runtime.

Unchanged: short left-click attack, left-drag camera, Intro Return/KeypadEnter/ButtonA, WorldMap ButtonB/Escape close.

Text tokens:
- '{Auto}', '{GhostHold}' and '{Map}' in Config texts.
- The server fills them from Config.KeyMap(data.Settings.Keys) in StoryQuestService.
- The client fills them with Keybinds.Label.

No remote in this item.

**키·폰:** PC 기본 키는 위 표와 같다. 패드는 베타에서 고정 배치이고, 실제 연결은 BB21에서 한다. 폰(터치 전용)은 키 표시를 숨기고, 안내 문구에 키 대신 버튼 이름을 쓴다.

**먼저 필요한 것:** 없음 (BB2와 함께 쓰면 저장된다)

**합격 확인:**
- 기본 키 F·Q·R·B·M·U·1·2·E가 지금과 똑같이 동작한다(회귀 0). 털린 뒤 T로 유령 붙잡기가 되고, G는 가방만 연다.
- G를 두 번 누르면 가방이 열렸다 닫힌다. 가방이 열린 상태에서 C를 누르면 캐릭터 창으로 바뀐다.
- 아직 없는 창의 키를 눌러도 아무 일이 없다(오류 0).
- 채팅이나 닉네임 입력 중에는 어떤 게임 키도 동작하지 않는다.
- src/StarterPlayer에서 'Enum.KeyCode.'를 grep하면 Keybinds.luau, Intro.luau(Return/KeypadEnter/ButtonA), WorldMap.luau(ButtonB/Escape 닫기)에서만 나온다.
- luau_check를 통과하고, HUD·Fx·WorldMap의 최상위 local이 200 미만이다.

### BB2. 설정 저장 (SettingsService, 서버 검증) (beta-must, M)

**플레이어가 보는 것:** 바꾼 키와 설정이 다음 접속이나 다른 서버에서도 그대로다. 나중에 새 동작(예: 일지 J)이 생겨서 그 기본 키가 내 키와 겹쳐도 내 키는 지워지지 않는다. 새 동작의 키만 비워 두고 '설정에서 정해 주세요'를 한 번 알려 준다.

**지금 상태:** 통합 설정 저장이 없다. 따로 저장되는 값만 있다: HideAnnounceName(AnnounceService 검증), AutoCombatEnabled, IntroSeen.

관련 동작:
- fillDefaults는 최상위 키만 채운다(DataService).
- Util.RateLimit은 간격 안에 온 두 번째 호출을 조용히 버린다(Util.luau:114-124).
- Panels의 ITEMS는 그래서 ReadyAt 대기열을 쓴다.

**계약:**

Data (additive, Version stays 3; not in Mirrored):
- Config.Data.Defaults.Settings = { V=1, Keys={}, Sfx=1, Shake=true, DmgNum='All', Tags='All', KeyBadges=true, Lang='Auto', BagSort='Default' }.

Config.Settings.Defs:
- Sfx: Number 0..1, Step 0.1
- Shake: Bool
- DmgNum: Enum All / Off
- Tags: Enum All / Near / Off
- KeyBadges: Bool
- Lang: Enum Auto / ko / en
- BagSort: Enum Default / Grade / Count
- Text table (KO + EN).

Config.SanitizeSettings(t) (pure, shared by server and client):
- Drops unknown keys.
- Keys is a sparse map: action id → '' or a key name of 24 chars or fewer, in Allowed and not in Reserved. Entries equal to the default are dropped.
- Numbers must be finite; they are clamped and snapped to Step. Bools must be boolean. Enums must be in Options. Anything else falls back to the default.
- DataService.fillDefaults sets d.Settings = Config.SanitizeSettings(d.Settings).

Collision rule (Config.KeyMap). Never wipe all keys:
1. Explicit entries are applied first, in Actions order. An explicit entry whose key is already taken becomes ''.
2. A live default-only action whose default key is taken becomes '' and is reported through Keybinds.Collisions(). The client toasts once per action per session: '새 동작 [%s]의 기본 키 %s가 이미 쓰여서 비워 뒀어요. 설정에서 정해 주세요'.

SettingsService.luau:
- New server module. Main.server.luau: INIT after 'AnnounceService', START before 'PlayerService'.

Remotes:
- c→s 'SetSettings'(blob?). select('#') <= 1. Zero args means 'send me mine'.
  - When present, blob is a table with at most 16 top-level keys and blob.Seq is an integer the server clamps to 0..2^31.
  - Checks: PlayerService.IsReady and Util.RateLimit(player, 'SetSettings', Config.RateLimits.SetSettings = 1).
  - On a rate-limit drop, send nothing.
  - Otherwise save Config.SanitizeSettings(blob) into GetData(player).Settings and echo.
- s→c 'Settings' { Seq, Settings }, owner only. Also sent once on PlayerReady.

Client:
- Pull once at Start.
- Keep one pending blob and send it at max(now, lastSent + RateLimits.SetSettings + 0.05). On window close, flush through the same slot and never send twice inside the limit.
- Ignore echoes with Seq lower than the newest Seq sent.
- Otherwise the server value wins.

**키·폰:** 입력 없음. 기기가 아니라 계정마다 저장된다. 키 설정은 PC 키보드에만 의미가 있다.

**먼저 필요한 것:** BB1 (Actions·Allowed·Reserved 정의)

**합격 확인:**
- 키와 효과음을 바꾸고 나갔다 들어오면 그대로다(DataStore가 켜진 비공개 장소에서 확인).
- 잘못된 값을 보내면 서버가 정리한 값만 저장하고 되돌려 준다. 시험 값: Keys.Attack='Escape', Sfx=5, 모르는 키, 1000자 문자열, 두 동작에 같은 키.
- 키를 바꾸고 0.3초 뒤 창을 닫아도 마지막 변경이 되돌아가지 않는다. 연타해도 서버 처리는 1초에 1번이다.
- Keys={Attack='J'}인 저장을 Journal=J가 추가된 뒤 불러오면, Attack은 J 그대로이고 Journal은 '없음'이 되며 안내가 1번 뜬다.
- Settings가 없는 옛 저장도 오류 없이 기본값으로 들어오고, Version은 3 그대로다.

### BB13. 메뉴 정리 + 새 창 등록 통로 (Panels.Register) (beta-must, M)

**플레이어가 보는 것:** 메뉴가 묶음으로 정리된다:
- [내 캐릭터 · 가방 · 스킬]
- [퀘스트 · 랭킹]
- [이동 · 지도 · 상점]
- [환생 · 직업 · 닉네임]
- [설정 · 도움말]

폰에서도 원하는 창을 두 번 안에 찾는다. 아직 없는 기능의 버튼은 보이지 않는다. Esc(로블록스 메뉴)를 열면 열려 있던 게임 창이 닫힌다.

**지금 상태:** 메뉴는 2열 격자 하나다. 항목 9개에 조건부 항목이 더 있다.

Panels의 한계:
- BUILDERS는 파일 안에서만 쓸 수 있다. 다른 모듈이 창을 등록할 수 없다.
- render()는 BUILDERS[currentId](content)를 부모 하나만 넘겨 부른다(Panels.luau:2833). Panels.Open(id, arg)(:2882)의 arg는 Story 창만 쓴다.
- REBUILD_ATTRS(Panels.luau:24: DataLoaded, Faction, Class, ClassChosen, VacationDays, HideAnnounceName) 중 하나가 바뀌면 창 전체를 다시 그린다.
- Panels.Close(:2927)는 내용만 지운다. 창마다 정리하는 훅이 없다.
- Panels.CurrentId가 없다.

**계약:**

Panels.Register(id, opts):
- opts = { Build = fn(parent, kit, arg) -> update?, Title, FixedBody = bool, Rebuild = { [attr] = true } | false, Cleanup = fn() }.
- It adds the window to BUILDERS and T.Titles.
- Panels.Open stores the arg (RENDER.Arg). render() passes it to Build and calls the previous window's Cleanup before clearContent. Panels.Close calls Cleanup.
- For registered windows, REBUILD_ATTRS applies only to attributes listed in opts.Rebuild. Windows refresh themselves through kit.OnAttr.
- With FixedBody, the body is a plain Frame instead of the ScrollingFrame + UIListLayout, so tabs stay pinned.
- kit = { Button, Toast, Fire, Palette, NextOrder, Rebuild, Close, Open, OnAttr }.

New exports: Panels.CurrentId() and Panels.IsRegistered(id).

Close rules:
- GuiService.MenuOpened (Esc) closes the open Panels window, the same as WorldMap.
- ButtonB closes every Panels window (pad).

New UI modules go after 'Panels' in ClientMain ORDER and call Register in Init. Tab state lives in the module, not in the builder closure.

Menu:
- BUILDERS.Menu uses Config.Menu.Sections, an ordered list of { Title, TitleEn, Ids }.
- Each section is a header plus a 2-column grid of 60+ px buttons. An entry shows only when its window is registered.
- '오프닝 다시 보기' and '이름 숨기기' move to Settings (BB3).
- The conditional Welcome and Vacation entries stay at the top.
- The back button keeps the openedFromMenu behaviour.

**키·폰:** PC: B키로 메뉴를 열고 닫는다. 폰: 오른쪽 위 [메뉴]. 패드: Y로 열고 B로 닫는다. 버튼 높이는 60 이상.

**먼저 필요한 것:** 없음

**합격 확인:**
- 기존 메뉴 기능(이동·직업·환생·상점·지도·닉네임·휴가)이 모두 두 번 안에 열린다.
- 749×361에서 섹션 제목이 보이고, 버튼이 겹치지 않으며, 높이가 60 이상이다.
- 등록되지 않은 창의 버튼은 메뉴에 나오지 않는다.
- Panels.Open('Settings', {Tab='Keys'})로 열면 키 탭이 바로 보인다. 설정 창에서 이름 숨기기를 바꿔도 탭과 스크롤이 유지된다.
- Esc를 누르면 열린 게임 창이 닫힌다.

### BB3. 설정 창 + 키 바꾸기 (원하는 대로) (beta-must, M)

**플레이어가 보는 것:** 메뉴 → 설정에서 연다.

[키 설정] 탭:
- 동작마다 지금 키가 적힌 버튼과 [비우기]가 있다.
- 버튼을 누르면 '바꿀 키를 누르세요 (5초)'가 뜬다.
- 다른 동작이 쓰는 키를 고르면 두 동작의 키가 서로 바뀐다('Q ↔ Z 바꿨어요').
- 로블록스가 쓰는 키를 고르면 '그 키는 로블록스가 써요'가 뜬다.
- 글자, 숫자, F1~F8, 숫자패드, 기호, Ctrl, Alt를 쓸 수 있다.
- [기본값으로] 버튼이 있다.

[기타] 탭:
- 효과음 크기
- 화면 흔들림
- 키 표시 켜기/끄기
- 알림·랭킹에 내 이름 숨기기(무엇이 숨겨지고 무엇이 안 숨겨지는지 안내 2줄)
- 오프닝 다시 보기

맨 아래에 버전·서버 정보가 있다. 저장이 꺼져 있으면 '저장 꺼짐'이 뜬다.

**지금 상태:** 설정 창이 없다.

지금 값:
- 효과음 크기, 화면 흔들림: 고정이다(Fx).
- 마우스 왼쪽 끌기 감도: CameraFollow.luau:17 RADIANS_PER_PIXEL 상수다. CameraFollow는 ORDER 첫 번째라 Init에서 설정을 읽을 수 없다.

키 입력을 받는 중의 충돌:
- M을 누르면 WorldMap CAS(우선순위 High+10)가 먼저 반응한다.
- B를 누르면 창이 닫힌다(HUD).

오프닝 다시 보기와 이름 숨기기는 지금 메뉴에 있다.

**계약:**

Window:
- Panels id 'Settings', registered through Panels.Register with FixedBody and Rebuild = false. UI lives in the new client module SettingsUI.luau, which also hosts 'Help' (BB15).
- Tabs: [키 설정][기타]. The arg {Tab='Keys'} opens the key tab.
- Touch-only devices see a one-line note instead of the key tab.
- With a gamepad connected, a read-only pad table appears under the key tab.

Key list:
- Only live actions (BB1). Each row has a key button and [비우기] (Keybinds.Clear).
- Unbound rows show '없음' highlighted.

Keybinds.Capture:
- ContextActionService:BindActionAtPriority('HH_KeyCapture', fn, false, 4000, Enum.UserInputType.Keyboard), returning Sink for every key. 4000 is above WorldMap and Intro.
- IsCapturing() is a second guard.
- Ends after 5 s, on [취소], on GuiService.MenuOpened (Esc belongs to Roblox) and in the window Cleanup. Always UnbindAction.
- Rules: a Reserved key → toast Settings.Text.Reserved. A key outside Allowed → reject. A key another live action holds → swap and toast. No modifier combos.
- Changes apply at once on the client and persist through BB2.
- [기본값으로] asks once to confirm, then sets Keys = {}.

Other rows apply locally; read settings lazily through the registry:
- Sfx: a multiplier inside an existing Fx table, applied to SOUND_VOLUME.
- Shake: Fx.Shake runs only when Settings.Shake is on and GuiService.ReducedMotionEnabled is off.
- KeyBadges: drives HUD L.ShowKeys.
- Name hiding: fires the existing SetAnnounceName. The note text comes from BB37.
- '오프닝 다시 보기': keeps its existing town-only rule.

No camera sensitivity row. CameraFollow multiplies RADIANS_PER_PIXEL by UserSettings():GetService('UserGameSettings').MouseSensitivity, read when used, so Roblox's own sensitivity setting controls both drags.

Footer:
- Config.BuildLabel, game.PlaceVersion, JobId:sub(1,8) and players n/Max.
- '저장 꺼짐' when GameState SaveOK == false. The server sets SaveOK = not DataService.IsMemoryMode(); add SaveOK to Net.GameStateDefaults.

Text: Config.Settings.Text; Keybinds Label / LabelEn.

The damage-number and nametag rows are BB3b.

**키·폰:** PC: 메뉴 → 설정. 키 입력은 키보드로 받는다. 폰: 키 탭 대신 '키보드가 없어요. 화면 버튼을 써요.'가 뜨고, 기타 설정은 모두 동작한다. 패드: 고정 배치표만 보여 준다(패드 키 바꾸기는 사용자 질문 2).

**먼저 필요한 것:** BB1, BB2, BB13

**합격 확인:**
- 공격 키를 F에서 J로 바꾸면 바로 J로 공격되고, F는 아무 일도 안 한다. HUD의 공격 키 표시도 J로 바뀐다.
- 스킬 Q 자리에 R을 넣으면 두 동작의 키가 맞바뀌고 토스트가 뜬다. [비우기]를 누른 동작은 '없음'이 되고 그 키로는 아무 일도 안 한다.
- 키를 받는 중 M이나 B를 눌러도 창이 닫히지 않고 그 키가 지정된다. Esc를 누르면 입력 받기가 바로 취소된다.
- W·Space·Tab·/·쉼표를 고르면 거절 문구가 뜬다. F5, Num1, Ctrl은 지정된다(Studio에서 막히는 키는 Reserved로 옮긴 뒤 다시 확인).
- 효과음 0%면 소리가 안 난다. 흔들림을 끄면 맞아도 화면이 안 흔들린다.
- 폰(터치 전용) 화면에서 키 탭 대신 안내 1줄이 뜬다.
- 749×361에서 글자가 잘리지 않고, 버튼 높이가 60 이상이다.

### BB6. 아이템 공용 접근 (Panels.Items 내보내기 + Config 보기 함수) (beta-must, S)

**플레이어가 보는 것:** 겉으로 바뀌는 것은 없다. 가방, 장비창, 대장간이 같은 개수와 같은 강화 수치, 같은 '얻는 곳'을 보여 준다.

**지금 상태:** Panels 안의 ITEMS 표가 아이템 일을 모두 맡는다. 방금 검수된 코드다.
- Inventory 원격 검증·캐시. Data = { Items, Enhance, Seen }이고, Seen은 P7에서 2fde077로 들어왔다.
- 연타 막기 Send / ReadyAt.
- 주문서 모드와 결과 문구.

파일 상태: Panels 최상위 local은 약 139개다. Config.Loot.Items에는 등급, 설명, 아이콘 필드가 없다. 몬스터별 드랍 글 표는 Panels 아이템 목록 안에 있다(2fde077).

**계약:**

No refactor of ITEMS for beta. The Items.luau split moves to launch.

Panels.Items() exports the existing table:
- Data, Send, ReadyAt, ValidMode, ResultText, FailText.
- Changed: a Util.Signal fired at the end of ITEMS.OnInventory.
- MarkNew(ids), NewCount(tab), ClearNew(tab): a session-only table.

The Fx loot handler calls Panels.Items().MarkNew lazily through the registry, with no new Fx locals.

Config pure helpers (Config has almost no top-level locals):
- Config.WeaponView(tier, level, classId, factionId, enhance) → { Name, Grade, Stars, Color, Plus, Damage, HitsSlime, HitsGoblin, Power, SellPrice }.
  - Damage is the same as Config.SwingHitsToKill.
  - Power = Config.CombatPower(level, tier, enhance).
  - SellPrice only for tiers 2..MaxSoldTier.
- Config.ItemView(id, count, enhance) → { Name, Kind, Grade, Desc, Count, Sell, IconKey, Color }.
- Config.ItemSources(id, seen):
  - Moves the P7 drop-text logic out of Panels.
  - Bands: 자주 = 20% or more, 가끔 = 2% or more, 드물게 = 0.2% or more, otherwise 아주 드물게.
  - Golden monsters count ×3. Potions add '물약 상인 25골드'.
  - Only monsters in Seen are named.

Config.Loot.Items gains (additive, no server change except BB7):
- Grade: materials are Common; SlimeCore, BruteHorn, KnightCrest and the 70% scrolls are Fine; 30% scrolls are Rare; 10% scrolls are Epic.
- Desc and DescEn.
- Icon: a UIArt key, or nil for the code fallback.

**키·폰:** 화면 없음.

**먼저 필요한 것:** BB4 (Power 값)

**합격 확인:**
- 대장간과 옛 아이템 목록이 그대로 동작한다: 구매, 판매, 장착, 강화, 옮기기, 재료 팔기, 몬스터가 주는 것(회귀 0).
- 주문서 버튼을 연타해도 서버 거절 없이 한 번만 쓰인다.
- 오프라인 검사에서 ItemSources의 띠 경계값(20% / 2% / 0.2%)과 황금 몬스터 ×3이 맞는다. 콘솔 오류는 0이다.

### BB7. 가방 창 + HUD [가방] 버튼 + 골라 팔기 (beta-must, L)

**플레이어가 보는 것:** 오른쪽 위 [가방] 버튼이나 PC G키로 연다.

- 탭: [장비][소모품][주문서][재료]. 탭마다 새 아이템 수가 붙는다.
- 칸마다 그림, 개수(×N), 강화(+N), '장착' 표시, 새 아이템 점이 있다.
- 칸을 누르면 설명이 나온다: 등급과 별, 어디서 얻는지, 공격력, 슬라임 몇 방인지, 전투력 변화.
- 버튼: [장착][강화][옮기기][사용][팔기(개수 고르기)][일반 재료 모두 팔기].
- 물약은 가방에서 바로 마신다.
- 귀한 재료(왕 슬라임 핵 등)는 '모두 팔기'에 들어가지 않는다. 정식의 제작 재료라서다.
- [재료] 탭 아래에 '몬스터가 주는 것' 표가 이어진다.
- 칸 수 제한은 없다.

**지금 상태:** 메뉴 → 아이템은 글자 목록뿐이다. 탭도, 그림도, 물약도 없다.

물약:
- HUD 버튼으로만 쓴다(VitalsUI).
- Panels 창이 열려 있으면 물약을 못 쓴다.

팔기:
- 판매는 SellMaterials 하나다(LootService). 등급 구분 없이 재료를 전부 판다.
- A23-18에 따라 베타 저장이 정식까지 이어진다. 그래서 지금 팔린 재료는 정식 제작 때 없다.

HUD와 문구:
- 오른쪽 칸은 자동·지도·메뉴뿐이다. 다음 무기 카드가 그 줄의 너비(rowW)에 맞춰 놓인다.
- '메뉴 → 아이템' 문구가 Config와 Fx에 있다.
- visual_direction_2026-10-05.md:809에 기록이 있다: 749×361에서 EventHUD 오늘의 운 판(210×58)이 오른쪽 칸 줄과 부딪힌다.

**계약:**

Window:
- Panels id 'Bag', registered with FixedBody and Rebuild = false. UI in the new client module BagUI.luau (ORDER after Panels).
- Layout from top: gold line (금고 + 주머니), tabs with NEW badges, sort pill (Settings.BagSort), then a ScrollingFrame with UIGridLayout of 88 px cells.
- Cell: grade frame drawn as a code fallback (dark fill + 3 px UIStroke in the WeaponGrade colour + stars). Icon through UIKit.ArtImage. ×N, +N, 장착 chip, NEW dot.
- The 재료 tab ends with the P7 '몬스터가 주는 것' text (Config.ItemSources + Data.Seen).
- Detail pane: on a canvas 640 px or wider, grid 60% | detail 40%. At 749×361 the detail replaces the grid and shows a [← 가방] button.
- Tap targets are 60 canvas px or more.

Actions:
- EquipWeapon(tier).
- UseItem(itemId, tier[, toTier]), through the existing mode → pick → confirm flow and the ITEMS guard.
- Potions fire UsePotion(kind) after the same checks through an exported VitalsUI.PotionState(kind) (full / kaiju / dead / cooldown).
- During PvP combat the buttons show '전투 중'.

New remote c→s 'SellItem'(itemId, n):
- itemId: a string of 32 chars or fewer that is a Material in Config.Loot.Items. n: an integer from 1 to the held count.
- select('#') == 2, IsReady, not PvP combat-tagged, the same anvil check as SellMaterials, RateLimits.SellItem = 0.3.
- Remove before pay. Price = Items[id].Sell × n.

SellMaterials changes on the server: it skips materials whose Grade ~= 'Common'. The client asks once to confirm ('젤리 12, 이빨 5 → 84골드').

Sell buttons are enabled only near the anvil. Elsewhere they show '대장간 모루에서 팔아요'.

HUD:
- Add a 4th BtnSquare 'Bag' (IconPouch).
- Keep a separate L.UpgradeRowW = 3*SQ + 2*RG for the next-weapon card. Use the 4-wide value only for ClusterLeft, and check that ClusterLeft stays right of 60% of the width at 749×361.
- Move the B14 scroll glow from 메뉴 to 가방. The first-scroll toast opens Bag on the 주문서 tab.
- Menu entry 아이템 → 가방. The '메뉴 → 아이템' strings become '가방'.
- The step-6 grey-box rail replaces this square, so spend no art or polish on it.

Text: Config.Bag.Text (KO + EN).

**키·폰:** PC: G키 또는 오른쪽 위 [가방]. 칸은 클릭으로 고르고, 끌어 옮기기는 쓰지 않는다. 폰: [가방] 버튼(누르는 범위 60 이상). 상세는 화면을 바꿔 열린다. 패드: 메뉴 → 가방으로 열고, Roblox UI 선택으로 칸을 옮기며, B로 닫는다.

**먼저 필요한 것:** BB6, BB13, BB1(G키)

**합격 확인:**
- 슬라임에게서 젤리를 얻으면 [재료] 탭에 새 아이템 점과 개수가 생긴다. 그 탭을 보면 점이 사라진다.
- 가방에서 HP 물약 [사용]을 누르면 HP가 차고 개수가 1 줄어든다. HP가 가득이면 버튼이 '가득'으로 꺼진다.
- 주문서 [사용] → 무기 고르기 → 확인을 하면 결과 문구와 '전투력 A → B'가 뜬다. +N이 가방·장비창·대장간에 똑같이 보인다.
- 모루 근처에서 젤리 3개를 [팔기]하면 정확히 3개만 팔린다. [일반 재료 모두 팔기]를 해도 왕 슬라임 핵은 가방에 남는다.
- 749×361과 1280×720에서 HUD 오른쪽 줄, 오늘의 운 판, 퀘스트 판의 사각형이 겹치지 않는다(execute_luau로 AbsolutePosition·AbsoluteSize를 잼). 겹치면 운 판을 전쟁 바 아래 줄로 옮긴다.
- 749×361에서는 88 칸, 상세 화면 전환, [← 가방] 버튼이 보이고 글자가 안 잘린다.
- PvP 전투 중에는 장착·주문서·팔기 버튼이 '전투 중'으로 바뀐다.

### BB9. 스킬 정의 + 스킬창 (beta-must, M)

**플레이어가 보는 것:** '스킬' 창은 PC K키나 메뉴로 연다.

- 줄마다 그림, 이름, 키, 'MP20 · 3초 · 공격력 ×6 · 반경 9칸'이 있다.
- 진영 효과 1줄과 상태('준비됨 / 2.4초 / MP 부족')가 보인다.
- 기본 공격 줄도 있다.
- 아래에 '패시브' 칸이 있다: 직업 특성, 진영 특성, 타락·속죄 표식 효과.
- Z 스킬 줄은 Z가 실제로 켜졌을 때만 보인다. 아직 안 배웠으면 'Lv5 · 교차로 스킬 선생님 · 100골드'와 [길 안내]가 나온다.
- [키 바꾸기] 버튼이 있다.

**지금 상태:** 스킬 정의는 Config.BasicSkill 하나뿐이다. 세 직업이 같은 수치를 쓰고, 스킬 이름도 없다.

- HUD 버튼에는 '스킬'과 'MP20'만 나온다.
- 직업 차이는 Config.Classes의 ReleaseCenter와 ReleaseMult뿐이다.
- Z 스킬 코드가 없다(UseSkill·LearnSkill 원격 없음).
- 스킬창이 없다.

**계약:**

Config.Skills:
- ZEnabled = false (the A23-15 flag).
- Order = {'Q','Z'}.
- Defs:
  - Q_Warrior = { Slot='Q', Class='Warrior', Name='회오리 충격파', NameEn='Whirl Shockwave', Desc, Shape='SelfAoE', Icon='IconSpecial', Uses='BasicSkill' }
  - Q_Mage = '유성 낙하' (TargetAoE)
  - Q_Archer = '화살비' (TargetAoE)
  - Z_Warrior / Z_Mage / Z_Archer from skills_weapons_pets §3: 대지 가르기 / 마력 사슬 / 꿰뚫는 화살, MP25, Lv5, 100골드.
- Q numbers always read Config.BasicSkill. Never copy them.

Pure helpers:
- Config.SkillDef(classId, slot).
- Config.SkillLines(def, factionId). The faction line comes from Config.Factions: 빛 '동료 치유 10% · 최대 30%', 뿔 '흡수 10% · 최대 3%', 장인 none.

Data shape owned by the Z task (it goes into skills_weapons_pets §3): Config.Data.Defaults.Skills = { Learned = {} } with string ids.

Window:
- Panels id 'Skills' (Register). UI in the new client module SkillBook.luau.
- Basic attack row: F/click, SwingInterval, range and targets from Config.Classes, Mage swing MP2.
- Q row: live state from the Mana and SkillReadyAt attributes through the update loop.
- Z row: only when ZEnabled and the teacher NPC exists. Not learned → requirement line + [길 안내] through HUD.ShowGuide.
- X is never shown (A23-1: no unlock teasers).
- Passive section, from Config only: class Stats lines, faction Perks, FallMarks / RedeemMarks effects.
- Key badge from Keybinds.Label. [키 바꾸기] calls Panels.Open('Settings', {Tab='Keys'}).

No remote here.

**키·폰:** PC: K키나 메뉴 → 스킬. 폰: 메뉴 → 스킬. 스킬 버튼 길게 누르기는 공격 입력과 헷갈려서 쓰지 않는다. 패드: 메뉴 → 스킬, B로 닫기.

**먼저 필요한 것:** BB1, BB13 (Z 줄은 A23-15 Z 작업)

**합격 확인:**
- 전사·마법사·궁수의 Q 이름이 각각 다르고, 수치가 Config.BasicSkill과 같다.
- Q를 쓰면 스킬창 줄의 남은 시간이 줄어들다가 '준비됨'이 된다. MP가 20 미만이면 'MP 부족'이 뜬다.
- ZEnabled=false면 스킬창의 Z 줄과 키 설정의 Z 줄이 모두 안 보인다.
- 빛·뿔·장인 진영에서 진영 효과 줄과 패시브 칸이 각각 맞게 나온다.
- 폰에서 메뉴 → 스킬로 열리고, 줄 높이가 64 이상이다.

### BB8. 내 캐릭터·장비창 (무기 칸, 펫 칸, 칭호, 능력치) (beta-must, M)

**플레이어가 보는 것:** '내 캐릭터' 창은 PC C키, 상태판 얼굴이나 전투력 누르기, 메뉴로 연다.

[장비] 탭:
- 왼쪽에 내 로블록스 얼굴 사진과 큰 전투력 숫자가 있다.
- 오른쪽에 무기 칸(등급 테, +N)이 있다. 누르면 가진 무기 목록이 나오고, 무기마다 '전투력 +N · 슬라임 4방 → 2방'과 [장착]이 있다.
- 펫이 생기면 펫 칸이 생긴다.
- 칭호도 여기서 고른다.

[능력치] 탭:
- 레벨, 최대 HP, MP, 이동 속도, 공격 1번 피해, 스킬, 치명타
- 직업·진영 특성
- 지금 걸린 효과(덩치 저울, 깡패, 현상 별, 복수)
- 환생 보너스
- 명예/악명과 다음 칭호까지 남은 점수
- 깡패가 되는 세 가지 경우

3D 몸 미리보기는 BB8b(권장)다.

**지금 상태:** 이런 창이 없다. 쓸 만한 재료는 있다:
- HUD 얼굴 3D 미리보기
- 직업 수치(선택 카드에서만 보임)
- 진영 특성, 칭호

무기는 아이템 목록에서만 장착한다(EquipWeapon → LootService).

펫 계약이 아직 없다. skills_weapons_pets §2에는 EquipPet 원격이 없고, 펫 줄을 '메뉴 → 아이템 맨 위'에 둔다고 적혀 있다. 그런데 그 화면은 BB7이 가방으로 바꾼다.

**계약:**

Window:
- Panels id 'Character' (Register, FixedBody, Rebuild = false). UI in the new client module CharacterUI.luau.
- Portrait: UIKit.HeadshotImage(LocalPlayer.UserId). No HUD refactor; the 3D body is BB8b.

Weapons: no new remote. Equip uses EquipWeapon(tier) through the Panels.Items() guard. List rows come from Config.WeaponView.

Pet contract, defined here for the pet task (update skills_weapons_pets §2 to match):
- c→s 'EquipPet'(uid): a string of 32 chars or fewer that the player owns, or '' for none. select('#') == 1, IsReady, RateLimits.EquipPet = 0.5.
- s→c owner-only 'Pets' { List = { {Uid, Kind, Name} }, Equipped }. Attribute EquippedPet.
- The pet row goes at the top of the Bag [장비] tab and in the Character pet cell. The cell shows only when Config.Pets exists.

Title row: BB16 SetTitle.

Stats, from Config and replicated attributes only:
- CombatPower, Humanoid.MaxHealth, MP (Config.Vitals), Humanoid.WalkSpeed.
- Swing damage = WeaponDamage × class Damage × (1 + DamageBonus) × 0.5.
- Skill (Config.Skills / BasicSkill). Crit 10% ×2, monsters only.
- Class Stats and faction Perks.
- Active effects only while active: SizeMult, BullyStacks, WantedStars, RevengeUntil, WarBlessing.
- Rebirth bonus %, FallMarks / RedeemMarks.
- Honor / Infamy and the next threshold (Config.Titles.Thresholds).
- Help lines: Config.Power.Text.Formula / PvPNote and Config.Bully.Text.
- Live refresh through kit.OnAttr.

No placeholder armor or accessory slots (A23-1 '다음 해금 예고 금지'; user question 2).

Text: Config.Equip.Text.

**키·폰:** PC: C키, 상태판 얼굴·전투력 클릭, 메뉴. 폰: 얼굴을 누르거나 메뉴로 연다. 패드: 메뉴 → 내 캐릭터, B로 닫기.

**먼저 필요한 것:** BB4, BB6, BB13 (펫 칸은 펫 작업, 칭호는 BB16)

**합격 확인:**
- C키, 얼굴 누르기, 메뉴 세 가지로 모두 열린다.
- 무기 목록의 '전투력 +N'이 장착한 뒤 HUD 숫자 변화와 같다. 8티어처럼 낮아지는 경우는 '전투력 −N'으로 나온다.
- 능력치 탭의 최대 HP가 실제 Humanoid.MaxHealth와 같다(직업·진영이 다른 3명으로 확인).
- 펫이 없으면 펫 칸이 안 보이고, 빈 장비 칸(갑옷 등)도 없다.
- 749×361에서 얼굴, 무기 칸, 전투력이 한 화면에 보인다.

### BB37. 이름 숨기기 한곳 처리 (PublicName) (beta-must, S)

**플레이어가 보는 것:** '알림·랭킹에 내 이름 숨기기'를 켜면 서버 전체 알림(현상수배, 현상금, 원한 복수, 환생, 거위, 괴수), 마을 게시판, 랭킹에서 내 이름이 '빛의 기사단 한 명'처럼 나온다. 설정에는 안내가 2줄 있다: '같은 서버의 머리 위 이름표와 Tab 목록은 숨길 수 없어요', '전체 랭킹에는 로블록스 이름과 얼굴이 나와요. 숨기면 "<진영> 한 명"으로 보여요'.

**지금 상태:** HideAnnounceName을 지키는 곳은 AnnounceService who()(AnnounceService.luau:26) 하나뿐이다.

지키지 않는 곳:
- src/ServerScriptService의 Net.NotifyAll 17곳 중 이름이 들어가는 줄. 이 줄들은 Util.PlayerDisplayName을 그대로 쓴다. 예: GrudgeService.luau:260 GrudgeAvengedAll, PvPService의 MostWanted·BountyAnnounce, ProgressionService RebirthAnnounce, GooseService RareAnnounce, KaijuService 괴수 이름 줄.
- 마을 게시판(PvPService updateBoard). 이름과 '깡패'를 그대로 보여 준다.

**계약:**

AnnounceService.PublicName(player) -> string:
- Returns Util.PlayerDisplayName(player).
- When data.HideAnnounceName == true, returns the existing hidden-name text formatted with the faction name instead.

Use it everywhere another player's name reaches the whole server: every NotifyAll and announce site, the town board (PvPService updateBoard), RankingService rows, BB26 boards and the BB36 hero line.

The setting label becomes '알림·랭킹에 내 이름 숨기기'. Add the two note lines to Config.Announce.Text.

The Server scope and nametags are unchanged: players in the same server see each other anyway.

**키·폰:** 입력 없음. 설정 창(BB3)의 줄 하나로 켜고 끈다.

**먼저 필요한 것:** 없음 (BB10·BB11보다 먼저)

**합격 확인:**
- src/ServerScriptService에서 'NotifyAll.*PlayerDisplayName'을 grep하면 0건이다.
- 숨기기를 켜고 현상수배·환생·거위 알림을 일으키면 '<진영> 한 명'으로 나온다(MCP 2명 테스트).
- 마을 게시판도 숨긴 이름을 지킨다.

### BB10. 랭킹 서비스 (이 서버·전체, 시즌·주간, 공정 점수) (beta-must, L)

**플레이어가 보는 것:** 랭킹 판은 다섯이다.
- 이번 시즌 최고 전투력
- 성장(환생·레벨)
- 이번 주 사냥(모든 진영)
- 이번 주 명예(빛의 기사단)
- 이번 주 악명(뿔 군단)

갱신과 참가:
- 전체 랭킹은 2~3분마다 새로 고쳐진다.
- 주간 판은 월요일 0시(한국 시간)에 새로 시작한다.
- 새 계정(3일 미만)이나 플레이 30분 미만은 전체 랭킹에 오르지 않지만, 이 서버 랭킹에는 보인다.

주간 명예·악명 점수는 공정한 싸움에서만 쌓인다. 명예·악명 자체와 골드는 지금과 같다.
- 비슷하거나 센 상대만 센다.
- 친구가 아닌 상대만 센다.
- 방금까지 직접 움직이던 상대만 센다.
- 같은 상대는 한 주에 3번까지 센다.

사냥 판은 자동 전투를 켜 놓고 자리를 비운 동안 잡은 것은 세지 않는다.

**지금 상태:** 게시판은 이 서버 접속자만 센다. 현상수배 TOP3와 기사단 명예 TOP3가 PvPService에 5초 루프로 있다. OrderedDataStore와 MemoryStore는 쓰지 않는다.

명예·악명이 쌓이는 곳은 7곳이다.
- PvPService.HandleKO: 3곳(:613, :633, :649)
- payLeaveBounty: :856
- GrudgeService pay: :207. 자루의 sack.Infamy는 피해자 정보 없이 합쳐진 값이다(:324).
- StoryQuestService: :480, :519

반복해서 얻는 점수는 PvP KO에서만 나온다. 이야기 퀘스트 점수는 한 번뿐이다.

그 밖의 위험:
- Studio Play도 실제 DataStore에 저장한다. DebugCommand(Main.server.luau:52-57)로 바꾼 레벨·골드가 그대로 남는다.
- 베타 저장은 정식까지 이어진다(A23-18).
- Studio 테스트 클라이언트는 UserId가 음수이고 AccountAge가 0이다.
- 사용자의 새 계정은 10/03에 만들어졌다.

**계약:**

RankingService.luau: new server module. INIT after 'AnnounceService', START before 'PlayerService'.

Seasons:
- Config.Ranking.Season = 'PRE' until beta day. The beta-day checklist line is 'Season을 B1로 바꾸고 SeasonHistory에 PRE 추가'. SeasonHistory = {'PRE'}.
- The effective season is 'STUDIO' when RunService:IsStudio() or DataService.IsMemoryMode().

Boards:
- Power: Period Season, value Rank.BestPower.
- Growth: Period Season, value Rank.BestGrowth = max(Rebirths*1000 + Level).
- Hunt: Period Week, all factions.
- Honor: Period Week, Faction Halo.
- Infamy: Period Week, Faction Horns.
- Order = {'Power','Growth','Hunt','Honor','Infamy'}.

Tuning:
- TopN = 50, RefreshSeconds = 180 staggered, WriteEverySeconds = 120, MinBudget = 5.
- MinAccountDays = 3, MinPlaySeconds = 1800.
- FairCredit = true, VictimActiveSeconds = 60, PvPMinVictimAccountDays = 7, PvPMinVictimPlaytime = 10800, MaxCreditPerVictimPerWeek = 3, MaxYieldPerVictimPerDay = 5.
- WeekCap = { Honor=150, Infamy=150, Hunt=5000 } (tune from beta logs).
- ExcludeUserIds = {}, MaxGrowthPerHour = 60, NameCacheSeconds = 3600, StudioNames = 'Player%d'.
- Config.WeekIndex(t) = math.floor((t + Config.Daily.TimezoneOffset + 3*86400) / 604800). This flips at Monday 00:00 KST (checked: 10/05 KST is week 2962).

Data (additive, Version stays 3):
- data.Rank = { Season='', BestPower=0, BestGrowth=0, WeekId=0, Honor=0, Infamy=0, Kills=0, Victims={}, YieldDay=0, YieldN=0, HideSynced=false }.
- data.DebugTainted = false.
- fillDefaults normalizes Rank:
  - Victims keys are strings 'U'..userId with integer counts 1..99, at most 100 entries.
  - Season fields reset when Rank.Season ~= the effective season.
  - Week fields reset when WeekId ~= WeekIndex(now). This also runs in the daily loop.
- BestPower and BestGrowth only rise within a season.

Stores:
- GetOrderedDataStore('HH_Rank_'..Season..'_'..Board[..'_W'..WeekId]).
- Key 'U_'..userId.
- Value = score*100 + hidden*10 + factionCode (0 None, 1 Halo, 2 Horns, 3 Neutral).

Fame funnel:
- PlayerService.GrantFame(player, stat, n, ctx) = AddStat + pcall(RankingService.Credit).
- It replaces every Honor/Infamy AddStat site.
- When ctx.PvP is set, it needs ctx.VictimUserId or ctx.Precleared.

Credit(player, board, n, ctx). It counts nothing when:
- game.PrivateServerId ~= '' (private or reserved server);
- the board's faction does not match the player's current Faction;
- WeekCap has been reached (throttled Util.Warn).

RankingService.PvPCreditOK(killer, victim). It runs at KO time and every check must pass:
1. PvPService.BoldMult(killer, victim) >= 1.
2. os.clock() - PlayerService.GetLastActive(victim) <= 60.
3. Not killer:IsFriendsWith(victim.UserId). Use pcall and a per-pair session cache; a failed call counts as friends.
4. victim.AccountAge >= 7 and the victim's PlaytimeSeconds >= 10800.
5. The killer's Rank.Victims['U'..id] < 3.
6. The victim's YieldN < 5 for today's Config.DayIndex.

On a pass, increment both counters.

Where PvPCreditOK applies:
- Plunder: HandleKO computes rankPts = (pairOk and PvPCreditOK) and PvPService.ScalePoints(1, bold) or 0. It passes this to GrudgeService.AddToSack(thief, victim, amount, infamy, rankPts), which keeps sack.RankInfamy += rankPts. pay() credits RankInfamy with ctx.Precleared. Avenged or returned sacks credit nothing. Never credit from sack.Infamy.
- payLeaveBounty passes the leaver as the victim, before the leaver's data is released.
- Hunt: the kill path credits 1 only when os.clock() - GetLastActive(player) <= 60.

These rules change ranking points only. Honor/Infamy stats, gold and stars are unchanged.

Every refusal adds its reason to RankingService.Stats.Refused[reason], for the A23-18 pre-launch abuse check.

Writes:
- Dirty set. A 10 s loop writes players whose last write was 120 s ago or more.
- Write at once on rebirth, on faction change (RemoveAsync on the old weekly board) and on PlayerLeaving.
- Skip a write when:
  - the SetIncrementSortedAsync budget is below MinBudget;
  - the value is unchanged;
  - the player is not eligible (AccountAge < 3 or Playtime < 1800);
  - DebugTainted is set;
  - the player is in ExcludeUserIds;
  - Power > Config.MaxCombatPower();
  - Growth > 999*1000 + MaxLevel;
  - BestGrowth rose by more than 20 + MaxGrowthPerHour × hours since the last write. Log these.
- BindToClose: player saves first; rankings only with leftover budget.

Hide must-write:
- AnnounceService's SetAnnounceName handler calls RankingService.MarkHideChanged(player).
- It writes every board the player has a row on as soon as budget allows, ignores the 120 s gap and retries every 10 s.
- After all writes succeed, set Rank.HideSynced = HideAnnounceName. PlayerReady re-runs this when the two differ.
- Cached rows of players in this server are re-masked from their live HideAnnounceName attribute.

Reads:
- Each board calls GetSortedAsync(false, TopN) every 180 s, staggered. Five boards make about 1.7 reads per minute.
- Read only when the GetSortedAsync budget is 2 or more.
- Cache the rows on the server. Clients read only the cache.

Names:
- Both scopes show the Roblox DisplayName, looked up with UserService:GetUserInfosByUserIdsAsync (batched, pcall, 1 h cache, fallback '플레이어').
- A player who is in this server also gets the game nickname as a subtitle.
- UserId <= 0 → StudioNames.
- Hidden rows show '<진영> 한 명' with UserId 0.
- The Server scope is computed live from GetReadyPlayers with PublicName (BB37).

Remotes:
- c→s 'RequestRankings'(boardId in Order, scope 'Server'|'Global'): select('#') == 2, IsReady, RateLimits.RequestRankings = 1.
- s→c 'Rankings' { Board, Scope, Rows (≤ 50: Rank, UserId, Name, Sub, Faction, Value, Test?), Me { Rank|nil, Value, Note? }, UpdatedAt }.

Studio and tests:
- In season STUDIO, skip MinAccountDays, MinPlaySeconds and the victim age / playtime / friend checks.
- DebugCommand keys: 'RankWrite' flushes now; 'PairCD' clears the pair cooldown.
- Every DebugCommand branch sets data.DebugTainted = true. Tainted saves never write outside STUDIO, and the Server scope tags them '테스트'. tools/reset_test_save.py clears the flag.
- RankingService.Stats = { Reads, Writes, Skipped, Refused }.

Store names are deterministic (SeasonHistory × Boards × week ids), so BB40 can erase a player's rows.

Text: Config.Ranking.Text.

**키·폰:** 서버 기능이라 입력은 없다. 화면은 BB11에서 다룬다.

**먼저 필요한 것:** BB4, BB37 (사용자 질문 4의 답으로 FairCredit 확정)

**합격 확인:**
- Studio 플레이는 HH_Rank_STUDIO_* 저장소에만 쓰고, PRE나 B1에는 한 번도 쓰지 않는다(로그로 확인).
- Studio 클라이언트 3명: 전투력이 오른 뒤 2분 안에 저장되고, 3분 안에 [전체] 탭 값이 바뀐다. DebugCommand RankWrite로 기다림을 줄여도 된다.
- 같은 상대를 한 주에 4번째로 KO하면 명예는 받지만 주간 점수는 그대로고, 거절 이유가 기록된다(PairCD로 쿨다운을 지우고 시험).
- 내 전투력 80% 미만인 상대를 KO하면 명예는 지금처럼 ×0.5를 받고, 주간 점수는 0이다.
- 털기 자루를 지켜 낸 도둑의 주간 악명은 통과한 KO에서 나온 RankInfamy만큼만 오른다.
- 진영을 바꾸면 옛 진영 주간 판에서 내 줄이 사라진다.
- 숨기기를 켜면 이 서버 [전체] 줄은 1초 안에, 다른 서버는 RefreshSeconds+10초 안에 '<진영> 한 명'이 된다.
- 오프라인 검사: Victims가 HttpService:JSONEncode를 왕복한다. CombatPower(100,7,10)=25,488은 상한을 통과하고, 상한+1은 거절된다.
- DebugCommand로 레벨을 바꾼 저장은 PRE·B1 판에 쓰이지 않는다.
- 1명 서버에서 1시간 동안 DataStore 예산 경고 0, 플레이어 저장 실패 0.
- 실제 서버 확인(사용자 실기기 확인): 10/10 이후, 7일 넘은 계정 2개로 확인한다.

### BB11. 랭킹 창 + 마을 게시판 대칭 (beta-must, M)

**플레이어가 보는 것:** 메뉴 → 랭킹(PC L키)으로 연다.

- 위에 탭 [전투력][성장][사냥][명예][악명], 그 아래 [이 서버][전체]가 있다.
- 줄마다 순위(1~3위는 금·은·동), 얼굴, 이름(로블록스 이름, 같은 서버면 게임 닉네임도), 진영 색, 값이 나온다.
- 맨 아래에는 내 줄이 고정된다('12위' 또는 '50위 밖 · 내 점수 1,052').
- 맨 위에는 진영 현황 1줄이 있다.

교차로 게시판에는 기사단 명예 TOP3 옆에 뿔 군단 악명 TOP3가 생기고, 게시판에서 E를 누르면 랭킹 창이 열린다.

**지금 상태:** 랭킹 창이 없다. 게시판에는 기사단 명예만 있고 악명이 없다. 이름 숨기기도 지키지 않는다. 게시판 문구는 PvPService 안 상수다. 진영 합계는 GameState에 이미 있다(WarHaloScore/WarHornsScore, HaloCount/HornsCount).

**계약:**

Window:
- Panels id 'Ranking' (Register, FixedBody, Rebuild = false). UI in the new client module Rankings.luau.
- Client cache per (board, scope) for 30 s. Opening a tab sends RequestRankings only when its cache is stale.
- Rows are 64 px with UIKit.HeadshotImage(UserId), skipped when UserId is 0. My row is pinned at the bottom.
- Header line from GameState.
- An empty board shows Config.Ranking.Text.Empty ('아직 기록이 없어요').
- Code fallbacks only. Medal colours are constants in Config.Ranking. Firefly parts come in step 6.

Town board (PvPService.updateBoard):
- Add a '뿔 군단 악명 TOP 3' section and use PublicName (BB37).
- Move the board strings into Config.Ranking.Text.Board.
- Add a ProximityPrompt '랭킹 보기'. The server fires the existing s→c OpenPanel 'Ranking'.

**키·폰:** PC: L키, 메뉴 → 랭킹, 게시판에서 E(또는 바꾼 상호작용 키). 폰: 메뉴 → 랭킹, 게시판 버튼. 탭은 두 줄이고 누르는 범위는 60 이상이다. 패드: 메뉴 → 랭킹, 게시판에서 X, B로 닫기.

**먼저 필요한 것:** BB10, BB13, BB37

**합격 확인:**
- 탭 5개와 범위 2개, 모두 10개 조합이 열린다. 빈 판은 '아직 기록이 없어요'를 보여 준다.
- [전체]를 10번 빠르게 눌러도 서버 요청은 1초에 1번이고, RankingService.Stats.Reads는 늘지 않는다.
- 내가 50위 안이면 순위가 나오고, 밖이면 '50위 밖 · 내 점수'가 나온다.
- 게시판에 기사단 명예 TOP3와 뿔 군단 악명 TOP3가 나란히 보이고, 게시판에서 E를 누르면 랭킹 창이 열린다.
- 749×361에서 탭 두 줄, 목록, 내 줄이 겹치지 않는다.

### BB12. 플레이어 목록(Tab) 열 정리 (beta-must, S)

**플레이어가 보는 것:** Tab 플레이어 목록에서 전투력을 볼 수 있다(사용자 답에 따라). 목록은 첫 열 순서로 정렬된다. 환생하면 전투력이 내려가는 만큼 목록에서 내려간다. 레벨 1 정렬처럼 맨 아래로 떨어지지는 않는다.

**지금 상태:** 열은 레벨·골드·환생·명성이다(PlayerService buildLeaderstats). 첫 열(레벨)로 정렬돼서 환생하면 맨 아래로 내려간다. 골드 열은 금고와 주머니를 더한 값이라 약탈 대상을 고르는 데 쓰인다.

**계약:**

Config.Leaderstats.Columns is an ordered list of column ids.
- Until the user answers: {'Level','Gold','Rebirths','Fame'} (current).
- Options from user question 3:
  - ⓑ recommended: {'Power','Level','Rebirths','Fame'}
  - ⓒ: {'Level','Rebirths','Fame'}

PlayerService.buildLeaderstats builds the columns from this list; creation order = column order.

The Power IntValue reads the CombatPower attribute. Add CombatPower to LEADERSTAT_KEYS.

Switching columns is a one-line Config change.

**키·폰:** PC Tab, 폰은 Roblox 상단 목록(Roblox 기본 UI).

**먼저 필요한 것:** BB4, 사용자 질문 3

**합격 확인:**
- 전투력 열을 켜면 그 숫자가 HUD 숫자와 같다.
- 환생하면 전투력 열이 HUD와 같은 숫자로 내려가고, 목록 순서도 그 숫자를 따른다.
- Config 한 줄로 열 구성을 바꿀 수 있다.

### BB14. 쓰러짐·부활 화면 (beta-must, S)

**플레이어가 보는 것:** 쓰러지면 화면이 어두워지고 원인이 뜬다('고블린 우두머리에게 쓰러졌어요', '떨어졌어요', '뿔 군단 ○○에게 쓰러졌어요').

- 잃은 것: 보통 몬스터 사망은 '잃은 것 없음'이다. 현상수배 중인 뿔 군단만 주머니 골드의 25%를 잃는다. 약탈당하면 그 금액이 나온다.
- 3·2·1 카운트가 나온다.
- 팁이 1줄 나온다. 예: 'HP가 낮으면 1번 물약!', '기사단이 45초 안에 잡으면 120% 돌려받아요', '갇혔을 땐 메뉴 → 이동'.

부활하면 화면이 사라진다.

**지금 상태:** PvE로 죽으면 피해자에게 아무것도 보내지 않는다. PvP는 토스트만 있다.

막힌 곳:
- 몬스터 타격은 누가 때렸는지 넘기지 않는다(MonsterService DamagePlayer(target, dmg, nil)).
- 사망 처리 함수들은 잃은 금액을 돌려주지 않고, pipelineCall도 반환값을 버린다(CombatService).
- Fx.Play는 모르는 kind를 조용히 무시한다.

원한 유령 버튼은 이미 따로 있다. GrudgeGhost.luau가 부활한 뒤에만 보여 준다.

**계약:**

Server:
- CombatService.DamagePlayer gets an optional 5th arg sourceKind. It is stored per victim as { Kind, At }. MonsterService passes the monster kind.
- runDeathPipeline:
  - Snapshot the victim's CarriedGold before step 1. After step 2, Lost = max(0, before - after).
  - By is chosen in this order:
    - Player: a killer exists.
    - Kaiju.
    - Monster: the last source is within 3 s.
    - Fall: no source within 3 s, and the HumanoidRootPart Y is below the zone floor - 30 or the Humanoid state is Freefall.
    - Other: everything else, including Reset Character.
  - Send owner-only Net.Fx(victim, 'KO', { By, Name = Config.MonsterTypes[kind].Name or PublicName(killer), Lost, Sack = bool, RespawnIn = Config.Player.RespawnTime }). No new remote name.

Client:
- New module DeathScreen.luau (ORDER after EventHUD). It connects its own Net 'Fx' listener filtered on kind == 'KO', bound with the FindFirstChild + timed WaitForChild pattern.
- A non-modal overlay, not a Panels window. Its ZIndex sits below Intro and the pickers.
- Closes on CharacterAdded, or RespawnIn + 2 s after showing.
- The tip comes from Config.Death.Tips by situation. The potion key comes from Keybinds.Label('PotionHP'); touch shows '물약 버튼'. By = 'Other' shows the tip '갇혔을 땐 메뉴 → 이동'.

Text: Config.Death.Text / Tips.

**키·폰:** 입력이 필요 없다. 폰에서는 팁의 키 이름 대신 '물약 버튼'이라고 쓴다.

**먼저 필요한 것:** BB1 (키 이름), BB37

**합격 확인:**
- 슬라임, 고블린, 플레이어, 낙하, 캐릭터 리셋으로 각각 죽어 보면 원인 글자가 맞다.
- 보통 몬스터 사망은 '잃은 것 없음', 현상수배 뿔 군단 사망은 잃은 금액이 실제 주머니 골드 차이와 같다.
- 부활하는 즉시 화면이 사라지고, 카메라·HUD·원한 유령 버튼이 정상이다.
- 오프닝이나 진영 선택 중에는 뜨지 않는다.

### BB15. 도움말(게임 방법) + 베타 안내 + 안내자 다시 만나기 (beta-must, S)

**플레이어가 보는 것:** 메뉴 → 도움말(PC H키)로 연다. 주제마다 4줄 이하다.

주제:
- 조작법: 내 키가 자동으로 표시된다.
- 전투·자동 전투: '아무 입력이 없으면 20분 뒤 로블록스가 연결을 끊어요' 1줄이 있다.
- 명예·악명
- 새싹 보호·깡패: 깡패가 되는 세 가지 경우가 있다.
- 현상 별·원한 자루
- 황금 거위, 괴수, 환생
- 주문서: 성공 10/30/70%, 실패하면 그대로거나 한 단계 내려가요, 무기는 사라지지 않아요.
- 진영 채팅: 채팅에 /t를 쓰면 같은 편에게만 보여요.
- 새 소식·베타 안내: 베타 저장은 정식까지 이어져요, 베타 개척자 칭호, 이번 주 바뀐 것.

'안내자 다시 만나기'로 첫 안내 대사를 다시 읽을 수 있다.

**지금 상태:** 규칙을 설명하는 페이지가 없다. 안내자 대화는 TutorialStep이 0일 때만 열린다. 지금 메뉴에서 다시 볼 수 있는 것은 '오프닝 다시 보기'뿐이다.

**계약:**

Config.Help.Topics is an ordered list of { Id, Title, TitleEn, Lines (4 or fewer, Korean), LinesEn = {} }.

Topic sources:
- Controls: built from Config.Keybinds + Keybinds.Label. Touch shows button names; a pad shows the fixed table.
- 새싹 보호·깡패: Config.Bully.Text.
- 자동 전투: Config.Afk.Text.HelpLine.
- 진영 채팅: one line about /t.
- 새 소식: Config.Help.News, a text table the worker updates weekly.

Window: Panels id 'Help', built in SettingsUI.luau.

'안내자 다시 만나기' shows the Config.Tutorial.Welcome lines read-only at any step. The accept button still appears only at step 0.

Tone follows text_rewrite_2026-10-05.md.

**키·폰:** PC: H키. 폰: 메뉴 → 도움말. 패드: 메뉴 → 도움말, B로 닫기.

**먼저 필요한 것:** BB1, BB13, BB4(깡패 문구)

**합격 확인:**
- 키를 바꾸면 조작법 주제에 새 키가 나온다.
- 749×361에서 모든 주제의 글이 잘리지 않는다.
- '안내자 다시 만나기'를 해도 퀘스트 상태는 바뀌지 않는다.

### BB38. 베타 지표 (P6 퍼널, AnalyticsService) (beta-must, S)

**플레이어가 보는 것:** 플레이어에게 보이는 것은 없다. 베타 동안 첫 10분이 어디서 끊기는지, 자동 전투를 얼마나 켜는지, 강화 실패 뒤 바로 나가는지, 새 창(가방·스킬·캐릭터·랭킹·설정)을 실제로 여는지를 숫자로 본다. 개인정보는 남기지 않는다.

**지금 상태:** src에서 AnalyticsService를 쓰는 곳이 0건이다. P6은 '기능 마감 전'에 하기로 했다(mmorpg_painpoints_ideas_2026-10-05.md:39). A23-20은 자리 비움 사냥 문제를 P6 지표를 보고 다시 묻기로 했다(SPEC_ADDENDUM.md:96).

**계약:**

Metrics.luau: new server module.
- Metrics.Step(player, n, name) = pcall(AnalyticsService.LogOnboardingFunnelStepEvent, AnalyticsService, player, n, name). Once per account via data.Funnel = {} (additive, Version stays 3).
- Metrics.Event(player, name, value) = pcall LogCustomEvent.
- Config.Analytics.Debug = RunService:IsStudio() prints each call.

Config.Analytics.Steps:
1. IntroDone
2. Faction
3. Class
4. FirstMissionAccept
5. FirstMissionDone
6. FirstWeapon
7. AutoUnlocked
8. Level10

Config.Analytics.Events:
- FirstDeath_<By> (from BB14).
- AutoOn.
- AutoAwayMinutes: auto ON while GetLastActive is older than 5 min, summed per session.
- EnhanceFailLeave: the player leaves within 300 s of a failed enhance.
- Plunder_Kept / Plunder_Avenged.
- KeyRebind.
- WindowOpen_<id>.

Window opens come from c→s 'UiMetric'(id):
- id must be in Config.Analytics.UiIds.
- select('#') == 1, IsReady, RateLimits.UiMetric = 2.
- Counted once per session per id.

No names, UserIds or free text in event names or values.

**키·폰:** 입력 없음.

**먼저 필요한 것:** BB14(사망 원인), BB13(창 id)

**합격 확인:**
- Studio 디버그 출력에서 각 단계가 계정마다 1번씩만 찍히고, 오류는 0이다.
- UiMetric을 10번 연타해도 서버 처리는 2초에 1번이고, 같은 창은 세션에 1번만 센다.

### BB39. Roblox 20분 무입력 퇴장 예고 (beta-should, S)

**플레이어가 보는 것:** 자동 전투를 켜 놓고 17분 동안 아무 입력이 없으면 '3분 뒤 로블록스가 자리 비움으로 연결을 끊어요. 아무 키나 눌러 주세요'(폰은 '화면을 한 번 눌러 주세요')가 한 번 뜬다. 다시 움직이면 예고가 초기화된다.

**지금 상태:** A23-20으로 자리 비움 중에도 자동 사냥이 계속되고, Roblox 기본 20분 무입력 퇴장은 그대로 작동한다(SPEC_ADDENDUM.md:93). 예고는 없다. 자리 비움 쉬기 코드(CombatService AUTO_IDLE)는 AutoIdleRest=false로 꺼져 있고(Config.luau:394), 이 항목은 그 코드를 건드리지 않는다.

**계약:**

Client only, in Announce.luau (client), with no HUD or Fx locals.

Behaviour:
- Players.LocalPlayer.Idled:Connect(fn(t)). When t >= Config.Afk.WarnAt (1020) and not warned, toast once.
- Reset the warned flag on UserInputService.InputBegan.

Config.Afk.Text = { Warn, WarnTouch, HelpLine }.

No VirtualUser, no fake input, no server change.

**키·폰:** 키보드·패드는 '아무 키', 폰은 '화면을 한 번 눌러'로 안내한다.

**먼저 필요한 것:** 없음

**합격 확인:**
- execute_luau로 Idled 처리 함수에 1020을 넘기면 토스트가 정확히 1번 뜬다. 두 번째 호출에는 뜨지 않는다.
- 입력을 한 번 하면 다음 1020 호출에 다시 1번 뜬다.

### BB3b. 피해 숫자·다른 사람 이름표 설정 (beta-should, S)

**플레이어가 보는 것:** 설정 [기타] 탭에 줄이 2개 더 생긴다.
- 피해 숫자: 켜기/끄기.
- 다른 사람 이름표: 전부/가까이/끄기.

이름표를 꺼도 PvP 지역에서는 가까운(40칸) 사람의 새싹·깡패·현상 별 표시가 계속 보인다. 그래서 위험한 사람을 놓치지 않는다.

**지금 상태:** 피해 숫자는 늘 켜져 있다(Fx showAmount/spawnNumber). 하지만 누가 때렸는지 정보가 없어서 '내 것만' 보기는 할 수 없다. 이름표 BillboardGui 'Nametag'에는 이름과 새싹·깡패·현상 별 표시가 함께 들어 있다(CharacterVisuals).

**계약:**

Settings rows:
- DmgNum (All/Off): a filter inside an existing Fx table.
- Tags (All/Near/Off): a client tag filter.
  - Near sets MaxDistance to 40.
  - Off hides only the name lines of other characters' Nametag.
  - While I am in a PvP zone or combat-tagged, the rookie, bully and wanted parts of players within 40 studs stay visible.

No server change.

**키·폰:** 설정 창.

**먼저 필요한 것:** BB3

**합격 확인:**
- 피해 숫자를 끄면 숫자가 안 뜬다.
- 이름표를 '끄기'로 하면 마을에서 이름이 사라진다. PvP 지역에서는 40칸 안의 깡패·현상 별 표시가 계속 보인다.

### BB24. 처음 겪는 순간 한 줄 안내 (P8②) (beta-should, S)

**플레이어가 보는 것:** 처음 PvP 지역에 들어가면 한 줄 안내가 한 번만 뜬다: '여기선 다른 진영과 싸울 수 있어요. 마을은 안전해요. 약한 상대를 쓰러뜨리면 깡패가 돼요'. 첫 현상 별, 첫 원한 자루, 첫 괴수 알림, 첫 쓰러짐, 환생 가능, 자동 해금 때도 마찬가지로 한 번씩 뜬다.

**지금 상태:** 한 번만 뜨는 안내는 첫 주문서 안내(Fx)와 이야기 첫 플래그(data.Story.First, StoryQuestService)뿐이다.

**계약:**

Server: a one-time Notify keyed in data.Story.First, using the same pattern as StoryQuestService.

Sites: ZoneService, PvPService, GrudgeService, KaijuService and ProgressionService.

Text: Config.FirstHints.Text. The PvP hint uses Config.Bully.Text.

**키·폰:** 토스트로만 알린다.

**먼저 필요한 것:** BB4(깡패 문구)

**합격 확인:**
- 각 안내가 계정마다 딱 1번만 뜨고, 다시 들어와도 다시 뜨지 않는다.

### BB21. 게임패드 기본 배치 (beta-should, S)

**플레이어가 보는 것:** 패드 기본 배치가 연결된다.
- R2 공격, L2 Q, L1 Z, R1 자동
- Y 메뉴, B 창·지도 닫기, X 상호작용
- 십자 위/아래 물약, 십자 왼쪽 지도, 십자 오른쪽 유령 붙잡기

패드로 키를 바꾸는 기능은 사용자 답에 따른다(질문 2).

**지금 상태:** 패드로 되는 것은 R2 공격, L2 스킬, 지도 닫기 B, 오프닝 건너뛰기 A뿐이다. 메뉴, 지도 열기, 물약, 자동은 패드로 못 한다. Studio MCP에는 패드 입력 도구가 없다.

**계약:**

Keybinds:
- Resolve the Pad defaults through Keybinds.PadFor in HUD, VitalsUI, WorldMap and GrudgeGhost.
- Ignore DPad input while GuiService.SelectedObject ~= nil.
- ButtonB closes Panels windows (BB13).

Tests use Keybinds.Dispatch({KeyCode, UserInputType = Gamepad1}) through execute_luau.

No pad remapping UI in beta (user question 2).

**키·폰:** 패드 전용 항목이다. PC·폰에는 영향이 없다.

**먼저 필요한 것:** BB1

**합격 확인:**
- Dispatch 시험으로 메뉴 열기, 가방 열기, 물약 쓰기, 자동 켜기, 창 닫기가 된다.
- UI 선택 중 십자키를 눌러도 물약이 나가지 않는다.
- 실제 패드로 같은 동작을 확인한다(사용자 실기기 확인).

### BB18. 퀘스트 일지 (beta-should, S)

**플레이어가 보는 것:** PC J키나 퀘스트 판 제목을 눌러 연다. 탭은 셋이다.
- [진행 중]: 지금 장과 단계, 서브 퀘스트, 일일 n/3, 자정까지 남은 시간.
- [지난 이야기]: 내가 고른 선택이 천사 쪽(돌려줘요)인지 악마 쪽(가질래요)인지 보인다.
- [다시 읽기]: 이야기 대사를 다시 읽는다.

**지금 상태:** 끝난 이야기와 선택은 저장만 되고 화면에 보이지 않는다(data.Story.Done/Pick). 이야기 페이지는 닫으면 다시 못 읽는다(BUILDERS.Story).

**계약:**

Server: QuestService adds Journal = { Done = ids, Pick = map } to the existing owner-only 'Quests' payload.

Client:
- New module Journal.luau, Panels id 'Journal' (Register).
- The Keybinds action 'Journal' = J becomes live once the window is registered. The BB2 collision rule protects existing binds.
- Story text comes from Config.StoryQuests. The daily countdown uses Config.DayIndex.

**키·폰:** PC: J키. 폰: 퀘스트 판 제목을 누르거나 메뉴로 연다.

**먼저 필요한 것:** BB13, BB2, 진행 중인 퀘스트 사슬 작업

**합격 확인:**
- S0 선택을 하면 [지난 이야기]에 천사/악마 표시가 남고, 다시 들어와도 그대로다.
- Attack을 J로 바꿔 둔 계정은 일지가 생겨도 J가 공격 그대로이고, 일지 키는 '없음'이 된다.

### BB19. 알림 기록 (beta-should, S)

**플레이어가 보는 것:** 놓친 알림(보상, 털림, 원한 우편 도착, 퀘스트 결과)을 최근 40개까지 '알림 기록'에서 다시 본다. 'n분 전'으로 표시된다.

**지금 상태:** 토스트는 2.5초만 보이고, 폰에서는 2개까지만 뜬다(UIKit). 기록이 남지 않는다. 원한 우편(GrudgeMail)도 접속할 때 토스트로만 알린다.

**계약:**

Log: UIKit.Toast and Announce push { Text, Kind, At } into UIKit.Log, a 40-entry ring kept for the session only.

Window: shown as a tab in Journal.luau.

No server change.

**키·폰:** 퀘스트 일지 안의 탭이다.

**먼저 필요한 것:** BB18

**합격 확인:**
- 토스트 10개가 지나간 뒤 기록에 10줄이 최신순으로 있다.
- 원한 우편을 받은 뒤 기록에 그 줄이 있다.

### BB20. 다른 플레이어 살펴보기 + 차단 바로가기 (beta-should, S)

**플레이어가 보는 것:** 랭킹의 [이 서버] 줄이나 '주변 사람' 목록에서 이름을 누르면 카드가 뜬다. 카드에는 닉네임, 레벨, 직업, 진영, 칭호, 무기 등급·+N, 전투력이 있다. [차단] 버튼과 '신고는 Esc 메뉴 → 신고' 안내도 있다.

**지금 상태:** 다른 플레이어를 살펴보는 기능이 없다. 필요한 값은 이미 모든 클라이언트에 복제된다(Config.Data.Mirrored, CombatPower). 차단·신고는 Roblox Esc 메뉴에만 있다.

**계약:**

Client only:
- Cards open from list rows, never by clicking the world (that would conflict with the one-click attack).
- The card reads attributes only. Exact power is shown, the same rule as BB12.
- [차단] calls pcall(StarterGui.SetCore, StarterGui, 'PromptBlockPlayer', plr).
- The '주변 사람' list shows players within 100 studs, friends first.

No new remote.

**키·폰:** 모든 기기에서 목록 줄을 눌러 연다.

**먼저 필요한 것:** BB11, BB4

**합격 확인:**
- 카드의 전투력이 그 사람의 HUD 숫자와 같다.
- [차단]을 누르면 Roblox 차단 확인 창이 뜬다(사용자 실기기 확인).

### BB25. 친구 초대 버튼 (beta-should, S)

**플레이어가 보는 것:** 메뉴의 '친구 초대'를 누르면 Roblox 초대 창이 뜬다.

**지금 상태:** 초대 버튼이 없다.

**계약:**

Client only:
- Call SocialService:CanSendGameInviteAsync(player) with pcall.
- Only when it returns true, call SocialService:PromptGameInvite(player).
- Otherwise hide the button.

**키·폰:** 모든 기기에서 메뉴 버튼으로 연다.

**먼저 필요한 것:** BB13

**합격 확인:**
- 초대 창이 뜬다(사용자 실기기 확인). 초대할 수 없는 계정에서는 버튼이 안 보인다.

### BB8b. 장비창 3D 아바타 미리보기 (beta-should, M)

**플레이어가 보는 것:** 내 캐릭터 창의 얼굴 사진 자리에 내 아바타가 무기와 후광/뿔을 들고 천천히 돈다. 끌어서 돌릴 수 있고, 무기를 바꾸면 1초 안에 미리보기도 바뀐다.

**지금 상태:** HUD 얼굴 3D 미리보기는 HUD.luau 안에 있고, 무기를 빼고 보여 준다. 이것을 따로 쓰려면 HUD에서 꺼내야 한다.

**계약:**

AvatarView.luau (new client module, extracted from the HUD portrait; ORDER before HUD):
- opts { KeepGear, Framing = 'Head'|'Body' }. The HUD portrait switches to it, which frees HUD locals.
- The Body view keeps WeaponModel, FactionMark, MarkCape / MarkHalo and RebirthAura.
- Rebuild when the CharacterVisuals WATCH attributes change, debounced 0.3 s.
- Destroy in the Character window Cleanup.
- Drag rotates the yaw; idle spin otherwise. Camera drag is blocked while the window is open.
- When the canvas is under 400 high, the view shrinks to 120 wide.

**키·폰:** PC: 마우스로 끌어 돌린다. 폰: 한 손가락으로 돌린다.

**먼저 필요한 것:** BB8

**합격 확인:**
- 무기를 바꾸면 1초 안에 미리보기도 바뀐다.
- 창을 10번 열고 닫아도 ViewportFrame이 남지 않는다.
- HUD 얼굴 미리보기가 그대로 동작한다.

### BB41. 베타 의견 보내기 (beta-should, S)

**플레이어가 보는 것:** 설정 창 아래 [의견 보내기]를 누르면 버튼 5개 중 하나를 고른다: 버그 / 너무 어려워요 / 너무 쉬워요 / 지루해요 / 재밌어요. 글은 쓰지 않는다. '고마워요!'가 뜬다.

**지금 상태:** 베타 플레이어가 의견을 전할 통로가 게임 안에 없다.

**계약:**

Remote c→s 'SendFeedback'(cat):
- cat must be in Config.Feedback.Cats.
- select('#') == 1, IsReady, RateLimits.SendFeedback = 30, at most 5 per session.

Server:
- Metrics.Event(player, 'Feedback_'..cat).
- UpdateAsync-append to DataStore 'HaloHorns_Feedback_v1', keyed by Config.DayIndex, with at most 300 entries per day.
- Each entry: { Cat, PlaceVersion, Job8, Zone, Level, Class, Faction, At }. No UserId, name or free text.

Add a Studio execute_luau snippet in the docs for reading a day's entries.

**키·폰:** 모든 기기에서 설정 창 버튼으로 보낸다.

**먼저 필요한 것:** BB3, BB38

**합격 확인:**
- 누르면 그날 키에 1줄이 쌓이고, 30초 안에 다시 누르면 무시된다.
- 저장된 줄에 UserId나 이름이 없다.

### BB40. 데이터 삭제 요청 처리 절차 (beta-should, S)

**플레이어가 보는 것:** 플레이어에게 보이는 것은 없다. Roblox에서 개인정보 삭제 요청이 오면, 사용자가 도구 하나로 그 사람의 저장·닉네임·우편·랭킹 줄을 모두 지운다.

**지금 상태:** 삭제 절차가 저장소 어디에도 없다. 전체 랭킹이 생기면 UserId를 키로 쓰는 저장소가 주마다 늘어난다: HH_Rank_*_W<n>, HaloHorns_GrudgeMail_v1, Rank.Victims.

**계약:**

Docs and tool:
- docs/ops/data_erasure.md and tools/erase_user.py, using Open Cloud.
- The key lives in the git-ignored .env as OPEN_CLOUD_KEY. Never print it.
- Dry run by default; the user runs it.

Given a UserId, the tool removes:
- the main save key;
- the nickname directory and claim keys;
- the GrudgeMail key;
- 'U_<id>' in every HH_Rank_<Season>_<Board>[_W<n>] store, enumerated from Config.Ranking.SeasonHistory × Boards × week ids since the season start.

**키·폰:** 해당 없음.

**먼저 필요한 것:** BB10

**합격 확인:**
- 시험 계정으로 dry run하면 지울 키 목록이 나온다. 실제 실행 뒤 그 키들이 모두 없다.

### BB26. 명예의 전당 게시판 (교차로·성채·소굴) (beta-should, M)

**플레이어가 보는 것:** 랭킹 게시판이 세 곳에 생긴다. 판 앞에서 E를 누르면 랭킹 창이 열린다.
- 교차로 '명예의 전당': 이번 시즌 전투력 TOP5, 성장 TOP5, 이번 주 사냥 TOP5.
- 빛의 성채: '이번 주 명예 TOP10'.
- 뿔 소굴: '이번 주 악명 TOP10'.

**지금 상태:** 게시판은 교차로에 하나뿐이다(MapBuilder buildBoard).

**계약:**

Map:
- Three landmarks in MapBuilder, using the buildBoard pattern.
- Positions are new Config.Map coordinates. Stay within MaxParts 1600.

Content:
- SurfaceGui text is filled from the RankingService cache every 60 s, using PublicName.
- A ProximityPrompt fires OpenPanel 'Ranking'.

Art: text only for now. One blank board-panel prompt comes later in the Firefly batch.

**키·폰:** PC E(바꾼 상호작용 키), 폰 화면 버튼, 패드 X.

**먼저 필요한 것:** BB10, BB11

**합격 확인:**
- 세 판의 값이 랭킹 창 값과 같고, 60초 안에 갱신된다.

### BB28. PvP 센 상대 표시 + 깡패 직전 경고 (beta-should, M)

**플레이어가 보는 것:** PvP 지역에서 내 전투력의 1.2배 이상인 적 머리 위에 금색 '센 상대 ×2'가 뜬다(점수 2배). 약한 상대에게는 표시를 붙이지 않는다. 대신 내가 공격해서 상대 HP가 30% 아래로 떨어졌을 때 지금 쓰러뜨리면 깡패가 되는 상황이면 나한테만 '지금 쓰러뜨리면 깡패가 돼요 (보상 없음)'가 뜬다.

**지금 상태:** 깡패 규칙(약한 상대 50%, 부활 15초, 10분에 3번, Config.Bully)과 대담함 배율(1.2/0.8)이 화면에 보이지 않는다. 이름표에는 새싹·깡패 표시만 있다.

**계약:**

Client:
- A client-only BillboardGui on enemy Halo/Horns players whose CombatPower is at least BoldStrongRatio × mine, shown while I am in a PvP zone or combat-tagged.
- Never on rookies, players in graduation grace, Neutral players or Protected players.
- Config.Power.Markers = true.

Server:
- PvPService.WouldBeBully(killer, victim) is an exported pure check, the same as HandleKO step 2 (weak, fresh, repeat).
- CombatService: after a PvP hit leaves the victim under 30% HP and WouldBeBully is true, Net.Notify the attacker once per pair per 60 s.

Until the user answers question 4, build only the gold marker.

**키·폰:** 표시만 하고 입력은 없다.

**먼저 필요한 것:** BB4, 사용자 질문 4

**합격 확인:**
- 2명 테스트에서 금색 표시가 대담함 ×2 판정과 경계 사례까지 일치한다.
- 부활 15초 안의 상대를 30% 아래로 깎으면 경고가 1번 뜨고, 60초 안에는 다시 뜨지 않는다.

### BB23. 배경 음악 + 효과음 묶음 (beta-should, M)

**플레이어가 보는 것:** 마을, 사냥터, PvP, 거위, 괴수마다 배경 음악이 나온다(핼러윈 곡 포함). 레벨업, 맞음, 쓰러짐, 물약, 강화 성공/실패, 퀘스트 완료에 소리가 난다. 설정에서 음악과 효과음을 따로 줄인다.

**지금 상태:** 음악이 없고 효과음은 4개뿐이다(Config Sounds, Fx). SoundGroup이 없다.

**계약:**

Audio.luau (new client module):
- Creates SoundGroups Music and SFX.
- Crossfades tracks by the ZoneTown / ZoneId attributes and GameState GooseActive / KaijuPhase.
- Config.Music holds asset ids per slot; 0 = silent. Use only Roblox-licensed library audio; the worker picks.

Fx: add a Group field inside the existing SOUND_VOLUME table. No new Fx locals.

Settings: add Music to the Defs. The row shows only once a track exists.

**키·폰:** 설정 창의 슬라이더로 조절한다.

**먼저 필요한 것:** BB3

**합격 확인:**
- 지역을 옮기면 곡이 2초 안에 바뀐다. 음악 0%면 효과음만 들린다.

### BB29. 언어 선택 줄 (자동/한국어/English) (beta-should, S)

**플레이어가 보는 것:** 설정에서 언어를 고른다. 처음에는 Roblox 언어를 따른다.

**지금 상태:** L(key) 텍스트 층과 영어 표가 아직 없다(text_rewrite_2026-10-05.md). 영어는 RELEASE_PLAN 컷라인 대상이다(RELEASE_PLAN.md:46).

**계약:**

Settings:
- Lang row, defaulting from Player.LocaleId.
- The row shows only after the L(key) layer exists.
- If English moves to the full launch under the cut-line, this row moves with it.

**키·폰:** 설정 창.

**먼저 필요한 것:** BB3, 영어 작업

**합격 확인:**
- English를 고르면 새 창 글자(BB 시리즈의 Text 표)가 바로 바뀐다.

### BB22. 스킬별 자동 사용 켜기/끄기 (launch, S)

**플레이어가 보는 것:** 스킬창의 줄마다 '자동 사용' 스위치가 있다. 꺼 두면 자동 전투가 그 스킬을 쓰지 않는다.

**지금 상태:** A23-1은 '자동은 공격과 스킬을 모두 쓴다'로 정했다. 스킬별로 끄는 것은 계약을 바꾸는 일이라서, 정식 때 사용자에게 한 번 물어본 뒤 넣는다.

**계약:**

Data (additive): Skills.AutoOff = {}.

Remote c→s 'SetSkillAuto'(slot 'Q'|'Z', on boolean):
- select('#') == 2, IsReady and AutoCombatUnlocked, RateLimits.SetSkillAuto = 0.5.

Server: autoTick skips slots listed in AutoOff. The default is on.

**키·폰:** 스킬창 스위치.

**먼저 필요한 것:** BB9, 사용자 결정(정식)

**합격 확인:**
- Q 자동을 끄면 자동 전투 중 Q가 나가지 않고, 다시 들어와도 유지된다.

### BB30. 코드 입력 (launch, S)

**플레이어가 보는 것:** 설정에 코드 칸이 있다. 코드를 넣으면 골드나 물약을 받는다.

**지금 상태:** 없다.

**계약:**

Config.Codes = { CODE = { Gold, HP, MP, Expires } }.

Data: Codes, a set of codes already used.

Remote 'RedeemCode'(code):
- A string of 20 chars or fewer, uppercase letters and digits only.
- RateLimits 2.

The server grants the reward through AddBankGold or potion stock. Reward sizes are set by the user.

**키·폰:** 설정 창.

**먼저 필요한 것:** BB3, 사용자 보상 결정

**합격 확인:**
- 같은 코드는 한 번만 받는다. 만료된 코드는 거절된다.

### BB31. Roblox 배지 (launch, S)

**플레이어가 보는 것:** 진영 선택, 첫 무기, Lv10, 첫 환생, 거위 참여 때 Roblox 배지를 받는다.

**지금 상태:** BadgeService를 쓰지 않는다.

**계약:**

AchievementService calls BadgeService:AwardBadge with pcall.

Config.Badges ids stay 0 (off) until the user creates the badges on the Creator Dashboard.

**키·폰:** 입력 없음.

**먼저 필요한 것:** 사용자 배지 생성

**합격 확인:**
- id가 0이면 아무 일도 없고, id를 넣으면 배지가 1번 지급된다.

### BB32. 출석 달력 (launch, S)

**플레이어가 보는 것:** 7일 출석 달력이 있다. 하루 빠져도 손해는 없다.

**지금 상태:** 없다. 일일 퀘스트와 휴가 보상이 대신하고 있다.

**계약:**

Data: Attendance = { Day, Streak }, using Config.DayIndex.

Reward sizes are a user (money) decision. Watch for chore fatigue (P8).

**키·폰:** 메뉴.

**먼저 필요한 것:** 사용자 보상 결정

**합격 확인:**
- 하루에 1번만 받을 수 있고, 날짜는 한국 시간 자정에 바뀐다.

### BB33. 로딩 화면 (launch, S)

**플레이어가 보는 것:** 처음 들어올 때 그림이 하나씩 튀어나오지 않고, 진행 막대가 있는 로딩 화면이 보인다.

**지금 상태:** ReplicatedFirst를 쓰지 않는다. sync_to_studio.py의 ROOTS에도 없다.

**계약:**

Script: src/ReplicatedFirst/Loading.client.luau runs ContentProvider:PreloadAsync on the Config.UIArt ids, then hands off to Intro.

Tooling: add ReplicatedFirst to the sync ROOTS.

Art: final art comes at the full launch.

**키·폰:** 입력 없음.

**먼저 필요한 것:** 없음

**합격 확인:**
- 느린 폰 환경에서 HUD가 깜빡이는 일이 줄어든다.

### BB34. 편의 묶음 (UI 크기, 폰 버튼 위치, 스킬 툴팁) (launch, M)

**플레이어가 보는 것:** 버튼·글자 크기를 보통/크게로 고른다. 폰 버튼 위치를 끌어서 옮기고, 왼손 배치로 뒤집을 수 있다. PC에서는 스킬 버튼 위에 마우스를 올리면 이름이 뜬다.

**지금 상태:** UIScale은 자동으로만 정해진다(UIKit). 버튼 배치는 6단계 HUD 재설계에서 새로 정해진다.

**계약:**

UI size: Settings.UiScale is stored per input type: { Touch, Desktop }.

Button layout editor and left-hand mirror:
- Save positions on the server.
- Comes after the step-6 HUD redesign.

Tooltip: kept in the HUD L table.

If the user answers 'no' to question 2, move UiScale and the left-hand mirror to beta-must (S).

**키·폰:** 폰 위주 기능이다.

**먼저 필요한 것:** BB3, 6단계 HUD 재설계, 사용자 질문 2

**합격 확인:**
- 폰에서 고른 크기가 PC 배치를 바꾸지 않는다.

### BB35. 지도 목표·친구 표시 (launch, S)

**플레이어가 보는 것:** 큰 지도에 지금 목표('여기로!')와 친구 위치가 보인다. 미니맵은 만들지 않는다(A12).

**지금 상태:** 지도에는 거위, 괴수, 자루 표시만 있다(WorldMap). 목표 안내는 빔으로 한다.

**계약:**

HUD exposes CurrentGoal().

WorldMap:
- Draws the goal marker.
- Draws friend markers using IsFriendsWith, with pcall and a cache.

**키·폰:** M키(바꾼 지도 키) 또는 지도 버튼.

**먼저 필요한 것:** 없음

**합격 확인:**
- 목표 줄이 바뀌면 지도 표시도 같이 바뀐다.

### BB36. 이번 판 영웅 + 랭킹 확장 (launch, S)

**플레이어가 보는 것:** 전쟁 판이 끝나면 '가장 많이 싸운 기사: 이름 (N점)'이 뜬다. 이름 숨기기를 켠 사람은 '<진영> 한 명'으로 나온다.

**지금 상태:** 전쟁 snapshot은 있지만(WarService endRound) 최고 기여자를 알리지 않는다. PvP KO 점수(20)가 몬스터 1마리(1)보다 훨씬 커서, 그대로 뽑으면 영웅은 사실상 PK 1등이 된다.

**계약:**

Pick the hero from the WarService.endRound snapshot, per faction:
- Needs 2 or more participants and ChestMinPoints or more.
- PvP KO points count for at most 50% of the hero score.

Announce with PublicName (BB37). Give the hero the RoundHeroUntil attribute.

**키·폰:** 입력 없음.

**먼저 필요한 것:** BB10, BB37

**합격 확인:**
- 참가자가 1명이면 영웅을 알리지 않는다. PvP 점수만 높은 사람이 몬스터·거점 기여가 많은 사람을 이기지 못한다.

## 공통 규칙(새 모듈)

새 기능(BB 항목)을 만드는 모든 세션이 지킨다. 줄 번호 대신 함수·식별자 이름으로 가리킨다(작업 중에 줄 번호가 밀리기 때문).

1. Init/Start에서 기다리지(yield) 않는다. 원격은 `FindFirstChild`로 바로 묶고, 아직 없으면 `task.spawn`으로 `WaitForChild(이름, 30)`을 기다렸다 묶는다(`ITEMS.Bind`와 같은 방식).
2. 새 상태는 표(table)에 넣는다. HUD, Fx, WorldMap, Panels는 각자 최상위 local이 200개를 넘지 않게 한다.
3. 한국어 글자는 `Config.*.Text`에 두고, 영어는 `*En` 키로 짝을 맞춘다.
4. 이미 있는 UIArt 부품과 UIKit 코드 대체(fallback)만 쓴다. 새 모양은 승인된 그림이 있어야 만든다.
5. 새 모듈 파일은 Studio에 먼저 넣고, 그다음에 ORDER/INIT 목록에 올린다. 지울 때는 목록에서 먼저 빼고 나서 파일을 지운다.
6. 모든 합격 확인에는 'MCP 확인' 또는 '사용자 실기기 확인' 중 하나를 적는다.

## 베타에 안 넣는 기본 기능과 이유

일부러 뺀 것이다. 사용자가 한눈에 보고, 검토 세션이 '빠졌다'고 다시 올리지 않게 한다.

- 파티·길드: GDD 로드맵에서 '이후'로 잡혀 있다. 지금은 같은 서버 진영 전투와 Roblox 친구 기능으로 충분하다.
- 1:1 거래: 사기·부계정 문제 때문에 금지를 그대로 둔다. 대신 경매장이 정식(12/19)에 열린다(A23-13).
- 갑옷·장신구 칸: 아직 설계가 없다(사용자 질문 2). 장비창은 무기·펫·칭호 칸으로 시작한다.
- 스킬 레벨·포인트: 아직 설계가 없다. 베타 스킬은 직업별로 정해진 것을 그대로 쓴다.
- 미니맵: A12에서 큰 지도만 두기로 했다. 작은 폰 화면을 가리지 않으려는 결정이다(BB35는 큰 지도에 목표를 표시한다).
- 진영 채팅: Roblox 기본 팀 채팅(/t)이 이미 동작한다. BB15 도움말에 한 줄만 적는다.
- 그림 도감: 아직 그림이 없다. P7의 글자 표(몬스터별 '주는 것')가 대신한다(가방 재료 탭, BB7).
- 폰 버튼 배치와 패드 키 바꾸기: 정식 이후로 미룬다(BB34, BB21, 사용자 질문 2). 폰 버튼 크기·왼손 배치는 사용자 답에 따라 BB34에서 정한다.
- 스킬별 자동 끄기: BB22. A23-1의 자동 전투 계약(스킬도 자동으로 쓴다)을 바꾸는 일이라 정식까지 기다린다.

## 4. 사용자에게 묻는 것 (답 오면 A23에 기록)

- (일정) 기본 기능 필수분만 약 16일(작업 1개 기준)이라, 10/24까지 펫·Z 스킬·핼러윈 몬스터를 모두 넣기는 어렵습니다. 기본 기능을 Z 스킬보다 먼저 하고, 늦으면 다음 순서로 빼도 될까요? 직접 말씀하신 6개(스킬창·가방·장비창·전투력·랭킹·키 설정)는 줄인 모양으로라도 꼭 넣습니다.
  ① 영어 → 정식
  ② Z 스킬 끄기
  ③ 핼러윈 몬스터 수 줄이기
  ④ 남은 '권장' 기본 기능 → 정식: 퀘스트 일지, 알림 기록, 패드 배치, 음악, 첫 안내, 친구 초대, 명예의 전당, 센 상대 표시, 3D 미리보기, 의견 보내기, 언어 선택
  ⑤ 전체 랭킹을 '이 서버 랭킹 + 마을 게시판'으로 줄이기
  (추천: 예)
- (범위) 베타의 '원하는 대로 키 설정'은 PC 키보드에서만 할까요? 글자·숫자·F1~F8·숫자패드·기호·Ctrl·Alt를 쓸 수 있고, 키 비우기도 됩니다. 그리고 아래 세 가지는 정식(12/19) 이후로 미뤄도 될까요?
  - 폰 버튼 위치·크기 바꾸기
  - 패드 키 바꾸기
  - 장비창의 갑옷·장신구 칸(장비창은 무기·펫·칭호 칸으로 시작)
  (추천: 예. 아니라면 폰 버튼 크기·왼손 배치를 베타에 넣습니다)
- (PvP 공정성) Tab 플레이어 목록 열을 어떻게 할까요? 지금은 남의 금고+주머니 골드가 다 보여서 털 사람을 고르기 쉽습니다. 답을 받기 전까지는 지금 열을 그대로 둡니다.
  ⓐ 지금 그대로: 레벨·골드·환생·명성
  ⓑ 전투력·레벨·환생·명성: 골드를 숨깁니다 (추천)
  ⓒ 레벨·환생·명성만: 골드와 전투력을 숨깁니다
- (PvP 공정성) 두 가지를 추천대로 해도 될까요? (추천: 둘 다 예)
  1. 주간 명예·악명 랭킹 점수는 공정한 싸움에서만 쌓이게 합니다.
  - 비슷하거나 센 상대(내 전투력 80% 이상)만 셉니다.
  - 친구가 아닌 상대만 셉니다.
  - 방금까지 직접 움직이던 상대만 셉니다.
  - 같은 상대는 한 주에 3번까지만 셉니다.
  - 한 사람이 남에게 점수를 주는 것은 하루 5번까지입니다.
  명예·악명 자체, 골드, 현상 별은 지금 그대로입니다. 자리 비움으로 자동 사냥 중인 사람도 지금처럼 털릴 수 있고, 랭킹 점수만 없습니다.
  2. PvP 지역에 빨간 '약한 상대' 머리 표시는 만들지 않습니다. 대신 쓰러뜨리기 직전 공격자에게만 '지금 쓰러뜨리면 깡패' 경고를 띄웁니다.
- (보상) 베타 랭킹에 보상을 줄까요? 추천은 '보상 없이 순위만'입니다. 보상을 주면 PK나 부계정으로 점수를 쌓는 사람이 늘어납니다. 그래도 주고 싶으시면 주간 1~3위에 능력치 없는 칭호만 주는 방법이 있습니다.

## 5. 비평에서 나온 것 (참고)

The spec is thorough and covers all six requested items (skill window, bag, equipment window, combat power, ranking, key settings) with server-side checks. Three things block it as written:
1. **BB17 is overruled by a newer decision.** It brings back the AFK auto-rest that A23-20 switched off (commits 5c977d6 and 89bf690, AutoIdleRest = false).
2. **The G key is taken twice.** GrudgeGhost.luau, which is uncommitted work in progress, uses G, and BB1 also makes G the bag key.
3. **The ranking power cap is wrong.** BB10 computes the cap with MaxWeaponTier = 8, but tier 8 is the 76-damage jelly weapon. The cap comes out at 7,027 and leaves every tier-7 player off the power board.

Next most important:
- BB27 clashes with the grudge-mail code now being written. Its 'never lost or doubled' acceptance check does not match that code.
- BB12's 'order unchanged after rebirth' check is false, because rebirth resets level and combat power drops.
- If a new default key collides with a player's saved keys, the settings clean-up wipes all of their keys.
- The 1-second rate limit can undo the player's last settings change.
- The ranking acceptance tests cannot pass in Studio, where test clients have account age 0 and negative UserIds. They also cannot pass soon on the user's new account, which is under 3 days old until 10/06 and under 7 days old until 10/10.

**Completeness:**
- **Key settings:** only letters and digits on the PC keyboard, with no way to unbind a key. Phone and gamepad remapping are moved to launch without asking the user.
- **Factions:** the Neutral faction gets no weekly ranking.
- **Bag:** it can only sell all materials at once, including materials needed for crafting at launch, and beta saves carry over to launch.
- **Missing items:**
  - the P6 analytics funnel, which A23-20 depends on;
  - a warning before Roblox's 20-minute idle disconnect;
  - a list of the basic features deliberately left out.
- **Scope:** A23-19 makes the extra basics beta-required, but about 12 of them are marked beta-should/launch without a user question.

Fix the three blockers and add the missing user questions before workers start BB1, BB2, BB10 or BB27. The other items are small contract edits.

- 빠진 것: Roblox 20-minute idle disconnect warning (LocalPlayer.Idled toast at about 17 min). Replaces BB17, which goes against A23-20.
- 빠진 것: Config.Keybinds action for the in-progress GrudgeGhost hold key (currently hardcoded G, which collides with Bag G).
- 빠진 것: Unbound/empty key state plus a [비우기] button, and deterministic resolution when a new default key collides with saved binds (no full wipe).
- 빠진 것: Wider rebindable key set (F1–F8, keypad, punctuation, Ctrl/Alt/CapsLock) to meet '원하는대로'.
- 빠진 것: Window hotkeys that toggle (press again to close, press another to switch) and Esc closing Panels like WorldMap.
- 빠진 것: Per-item material sell with quantity, plus confirmation, with Fine+ crafting materials excluded from '모두 팔기' (beta saves carry into launch, and crafting comes at launch).
- 빠진 것: Weekly ranking board for the Neutral (장인 길드) faction, or one all-faction weekly board.
- 빠진 것: AnalyticsService beta funnel (P6), which A23-20 relies on for later decisions.
- 빠진 것: Studio test bypass for ranking eligibility (AccountAge, playtime, negative test UserIds), debug flush/pair-cooldown commands, and RankingService.Stats counters.
- 빠진 것: Ranking season 'PRE' before beta, switched to 'B1' on beta day (checklist line).
- 빠진 것: Explicit '베타에 안 넣는 기본 기능' list (party, trade, armor/accessory slots, skill points, guild, minimap, monster book, faction chat via /t) and a user question about armor slots.
- 빠진 것: User question on phone button layout/size and gamepad remapping for beta vs launch (the phone/pad side of key settings).
- 빠진 것: User question listing which beta-should basics may slip past 10/31 (A23-19 makes extra basics beta-required).
- 빠진 것: Client pull for saved Settings at Start (do not rely only on the one-time PlayerReady echo).
- 빠진 것: Acceptance grep check that no hardcoded Enum.KeyCode letters remain outside Keybinds/Intro/WorldMap close.
- 빠진 것: Passive section (class/faction/mark effects) in the skill window.

The direction is sound: separate modules registered through Panels, one integer CombatPower, a central key map, additive Version-3 fields, and an OrderedDataStore with a server cache and a STUDIO season. Most of the code claims check out against the source: the PowerOf samples (283/387/758/1,052/2,829 reproduce exactly), the GetCombatPower/BoldMult wiring, fillDefaults behaviour, the WorldMap priority of 3010, the HUD/Fx/Panels local counts (about 144/171/139; WorldMap is at about 176, so it is also tight), the leaderstats order and the remote names. The spec is out of date in three places, though. BB17 contradicts A23-20 ('계속 사냥', AutoIdleRest = false) and duplicates shipped code. BB27 duplicates the grudge mail being built right now in GrudgeService. The new GrudgeGhost.luau already owns the G key that BB1 gives to the Bag. Real bugs to fix before handing it off: the BB10 sanity cap uses tier 8 (7,027) and would reject legitimate players; the BB2 rate-limit echo can silently revert settings; the BB2 duplicate-key rule wipes every rebind when a default changes; Panels.Register has no arg pass-through, no Cleanup hook and is caught by the REBUILD_ATTRS full rebuilds; Week.Victims needs string keys; debug or Studio values can reach the real boards, and the eligibility gates make Studio testing of the global boards impossible. On schedule, roughly 15 'must' days on top of Z, pets, Halloween and the step-6 redesign does not fit in about 19 days. Cut now, not at 10/20: keep the user's six requests in minimal form (about 9 days, skip the BB6 refactor, BB8 without the 3D body, rankings without the Growth board), add the P6 analytics funnel, demote BB14/15/16 polish to 'should' (send BB16's data shape to the worker now, since they are doing the A23-18 bundle), delete BB17 and BB27, and schedule the basics right after the current quest-chain chunk, ahead of Z.

- 빠진 것: P6 AnalyticsService funnel (beta-must, S). A23-20 says the decision on away-from-keyboard hunting will be revisited using 'P6 퍼널' beta metrics, but AnalyticsService is not used anywhere in src (grep 0). Without it the beta produces no data for the 10-minute flow, the A23-20 decision or the upgrade-scroll drop-off question (mmorpg_painpoints:39, :62).
- 빠진 것: In-game beta feedback / bug report (beta-should, S). Category buttons only, with no free text (moderation), plus automatic context: PlaceVersion, JobId:sub(1,8), zone, level, class and the last error. Send it through AnalyticsService custom events or a small DataStore queue. Beta players have no other channel.
- 빠진 것: '새 소식 / 베타 안내' topic in Help (beta-should, S). It tells players that their beta save carries over to launch (A23-18), that the Beta Pioneer title exists, and what changed this week. Text only, from Config.Help.
- 빠진 것: Ranking guard for private and reserved servers (part of BB10). Skip credit and writes when game.PrivateServerId ~= '' (P11, mmorpg_painpoints:44).

The spec is policy-safe on the basics, but its anti-abuse layer is too thin for a PvP game played by children aged 8-14.

What is already safe:
- No new chat surface.
- Global boards use Roblox DisplayName.
- Game nicknames are already broadcast-filtered and re-filtered on join.
- Blocking uses PromptBlockPlayer.
- Rankings carry no rewards by default.
- Studio writes go to a STUDIO season.

Blocking problems:
1. BB17 contradicts the user's newer A23-20 decision ('계속 사냥'; the feature already exists in 5c977d6 and is OFF on purpose). It must be dropped.
2. The weekly 명예/악명 boards are in practice PK leaderboards, because story points are one-time and repeatable points come only from PvP KOs. Their filters miss friend kill-trading, AFK auto-hunters, weak-but-not-bully victims, pre-aged alts and repeat targeting of one child by many killers. The plunder path bypasses per-victim checks entirely, because sack.Infamy is aggregated (GrudgeService.luau:324/207).
3. The renamed '알림·랭킹에 내 이름 숨기기' setting would be false: 7+ NotifyAll sites (Most Wanted, bounty, avenge, rebirth, goose, kaiju) and the town board's '깡패' line ignore it.
4. Debug-boosted dev and test saves live in the real DataStore and carry to launch (A23-18). Because BestPower/BestGrowth are all-time save fields, a season rename does not reset the Power and Growth boards.

Medium items:
- BB28's red 'weak' billboard is a target finder and misses the fresh-spawn and repeat bully rules. Replace it with a server-side pre-KO warning.
- BullyNote is over-simplified.
- A hide toggle can be skipped by budget.
- payLeaveBounty credit lacks a VictimUserId.
- No right-to-erasure procedure exists for the new UserId-keyed stores.

Add the three short Korean questions in missing_features to user_questions. They cover PvP-credit rules, plunder of AFK hunters and the weak-marker replacement. Everything else above is a technical fix the worker can apply without asking.

Line numbers in PvPService, GrudgeService and Config are shifting under active worker edits (uncommitted diffs). Cite by function name and route all fame grants through one helper.

- 빠진 것: AnnounceService.PublicName(player): one name source for every server-wide mention (all NotifyAll sites, kaijuName, the town board, rankings, BB36) that honors HideAnnounceName, plus a grep acceptance check (0 raw Util.PlayerDisplayName inside NotifyAll).
- 빠진 것: RankingService.PvPCreditOK(killer, victim): fair fight only (BoldMult >= 1); victim manually active within 60 s; not Roblox friends; victim AccountAge >= 7 and PlaytimeSeconds >= 3h; killer-side 3 per victim per week; victim-side MaxYieldPerVictimPerDay = 5. Applied at KO time, including the grudge sack (AddToSack rankPts) and payLeaveBounty.
- 빠진 것: Season-scoped ranking fields (data.Rank = {Season, BestPower, BestGrowth}), a persisted DebugTainted flag set by every DebugCommand branch, and Config.Ranking.ExcludeUserIds, so Studio-boosted dev and test saves never reach the beta or launch boards.
- 빠진 것: Server-side pre-KO bully warning to the attacker (PvPService.WouldBeBully: weak, fresh spawn or repeat KO) in place of the red '약한 상대' billboard.
- 빠진 것: Must-write path for the hide toggle (retry until success, RankHideSynced flag, instant local re-mask of cached rows).
- 빠진 것: Data erasure procedure (docs/ops/data_erasure.md + tools/erase_user.py) covering the main save, nickname stores, every HH_Rank_<Season>_<Store>[_W<n>] store and the mail store; Config.Ranking.SeasonHistory.
- 빠진 것: Beta abuse log: refused ranking credits with their reason, plunder totals per killer/victim pair, and BestGrowth jumps per hour, feeding the A23-18 pre-launch check.
- 빠진 것: Shared Config.Bully.Text with all three bully conditions, used by BB4 PowerNote, BB8, BB15 Help and the pre-KO warning.
- 빠진 것: user_questions to add (short Korean): (1) '주간 명예·악명 랭킹에 PvP 처치를 셀 때, 비슷하거나 센 상대(내 전투력 80% 이상)·친구가 아닌 상대·방금까지 직접 움직이던 상대만 점수로 칠까요? (추천: 예. 명예·악명 자체와 골드는 그대로)' (2) '자리 비움으로 자동 사냥 중인 플레이어(A23-20)를 고블린 숲·해골 유적에서 털 수 있게 그대로 둘까요? (추천: 공격·털기는 그대로, 랭킹 점수만 없음)' (3) 'PvP 지역의 빨간 "약한 상대" 머리 표시 대신, 쓰러뜨리기 직전 공격자에게만 "지금 쓰러뜨리면 깡패" 경고를 띄울까요? (추천: 예)'
