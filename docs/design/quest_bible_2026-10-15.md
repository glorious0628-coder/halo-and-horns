# Halo & Horns 퀘스트 바이블 v2

작성: Codex · 2026-10-15 · Claude 최종 검수용 수정안. 문서 설계이며 구현·승인·Studio 적용 완료를 뜻하지 않는다.

## 사용자용 요약

**만들 범위는 초원에서 시작해 숲을 지나 폐허에서 첫 결말을 보는 약 35레벨까지입니다.** 세 편은 같은 팔찌의 비밀을 만나지만, 그곳까지 가는 놀이가 다릅니다.

**빛 기사단**
- 처음에는 슬라임 왕자에게서 반짝이는 팔찌를 찾습니다.
- 짐을 잃은 주민을 돕고, 길을 못 건너는 친구를 데려옵니다.
- 수상한 소포를 지켰더니 적의 작전이 아니라 생일 간식입니다.
- 숲에서는 등불을 기다리는 고블린을 구하고 수레를 호위합니다.
- 폐허에서는 옛 기록을 지키고, 마지막 조각을 둘 자리를 고릅니다.
- 예시 세 가지: 주민 짐 찾아주기 / 간식 수레 호위하기 / 떨어지는 기록함 받아내기.

**뿔 군단**
- 처음에는 슬라임 왕자의 반짝이를 내가 먼저 챙기려 합니다.
- 가장 빠른 대장인 척하고, 허풍으로 고블린의 시선을 돌립니다.
- 몰래 살펴본 비밀 소포에서 생일 간식이 나와 머쓱해집니다.
- 장난 장치가 거꾸로 작동해 내 머리에 종이 왕관이 떨어집니다.
- 폐허에서도 먼저 손을 뻗지만, 마지막 무대를 누구와 쓸지 고릅니다.
- 예시 세 가지: 굴러가는 소포 먼저 잡기 / 삑삑 상자로 우두머리 유인하기 / 자원한 부하에게 종 치기 지시하기.

**장인 길드**
- 지금은 교차로의 오토 대장간과 작업대에서 시작합니다.
- 필요한 재료를 모으고, 내 손으로 만든 물건을 주문자에게 줍니다.
- 소포의 포장을 고치다가 양쪽 아이가 같은 생일 선물을 준비한 걸 봅니다.
- 숲에서는 등불과 수레를 고치고, 조련사는 간식으로 동물을 안내합니다.
- 폐허에서는 서로 다른 표식의 부품을 맞춰 조각 받침을 완성합니다.
- 예시 세 가지: 약을 만들어 전달하기 / 덜컹거리는 수레 고치기 / 간식으로 아기 슬라임 데려오기.

새 장인 마을이 생기면 접수대와 작업 자리만 옮깁니다. 50~100레벨 이야기는 베타 뒤에 실제 성장 속도와 재미를 확인하고 정합니다.

## 1. 근거와 범위

| 근거 | v2 적용 |
|---|---|
| 이번 사용자 비평 | 1~5장 BUILD, 약 Lv35 폐허 첫 결말; 6~7장은 §10 한 표만 |
| `docs/SPEC_ADDENDUM.md` A23-152·193·197~199 | 장인 포함·마을은 나중, 스승 시험, 아이의 도시락 부탁, NPC 수락/거절·모든 단계 Guide |
| `docs/design/quests_first30_2026-10-15.md` | 왕자 1회, Lv5 기본 공격 슬라임4+도움1, 팔찌·등불·분수 연결; 이후 행동은 이번 비평에 맞게 분화 |
| `src/ReplicatedStorage/Shared/Config.luau` | Zones: Meadow1 / Woods10 / Ruins25; MaxLevel100은 콘텐츠 분량의 보증이 아님 |
| 같은 파일 `TownNpcs`·`StoryQuests.Speakers` | 부탁자 실물과 화자 이름을 구분; Rose의 이야기 키는 Smokey 유지 |
| `src/ServerScriptService/StoryQuestService.luau` | 기존 목표·보상·저장 기준; 새 상호작용은 별도 구현 |
| A23-179·185·190, 기존 대본 | 쉬운 영어 원문은 중앙 표; 한국어는 최신 클라우드 현지화 경로, 별도 한국어 모드 없음 |

**BUILD는 이 문서의 제작 범위다. 기존 승인·구현을 뜻하지 않는다.** 신규 행동과 사건은 최종 검수의 구현 목록으로 넘긴다. 새 일정·재화·유료 상품·지역·레벨 상한 변경은 없다. 숲의 PvP 규칙은 유지하고, 폐허 주선은 Crown Pit 밖 안전 고리에서 끝낸다.

| NPC 표기 | 파일에서 확인한 상태 | 사용 규칙 |
|---|---|---|
| Bright·Gleam·Rose·Tiny·Otto `[몸]` | TownNpcs에 몸 정의; Otto도 Story 상호작용 연결 | 현장 생성 성공은 Play에서 별도 확인; 새 원격 분신을 만들지 않음 |
| Folk1~4 `[주민]` | TownNpcs의 Folk 몸 | 도움 수령 상호작용 추가 필요; 현재 Story NPC라고 가정하지 않음 |
| Pip·Rex·Kit·Fizzby `[몸 필요]` | Speakers에 이름만 있음; Kit=Guild, Fizzby=Potion | **needs NPC body**: 기본 몸·태그·대화 거리·Guide 앵커 구현 전 해당 의뢰 비노출 |
| Fountain·Shard `[조각]` | Speakers의 물체 화자 | 사람 몸 대신 실제 조각 상호작용 앵커 필요; v2 부탁은 기존 사람 NPC가 맡음 |

## 2. 공통 이야기와 서로 다른 믿음

왕관은 부서졌고 두 편은 상대를 의심한다. 첫 왕자가 삼킨 금색·보라색 매듭의 팔찌, 생일 소포, 분수 반응이 두 아이의 우정을 드러낸다. 숲의 등불과 폐허의 수리 흔적은 같은 가루를 여러 사람이 써 왔음을 보여준다. 처음 왕관을 깬 범인은 확정하지 않는다.

첫 결말은 작은 조각 하나를 안정시키고 **누구와 쓸지 고르는 장면**이다. 왕관 전체 복원·전쟁 종료가 아니므로 왕관전은 계속된다. 조각 과열·공동 수리 기록은 이번 제안이다. 설명 대신 삐걱거리는 받침, 엇갈린 도장, NPC의 머쓱한 몸짓으로 보여준다.

| BUILD 장·레벨 | 빛의 주동사 | 뿔의 주동사 | 장인의 주동사 | 같은 사건을 만나는 이유 |
|---|---|---|---|---|
| 1장 Lv1~5, 초원·교차로 | 구하다→짐 돌려주다→등불 지키다 | 먼저 잡다→간식 장난하다→멋부리다 | 채집하다→만들다→납품하다 | 첫 왕자와 팔찌; 스승 시험은 A23-198 공통 틀 |
| 2장 Lv5~9, 연못·보급로 | 호위하다→받아내다→길 열다 | 선점하다→허풍 떨다→부하 지휘하다 | 포장 고치다→여과하다→제작·배달하다 | 팔찌의 매듭과 분수만 공유; 표본·보급품 얻는 방법은 다름 |
| 3장 Lv10~24, 숲 | 구출하다→지키다→수레 호위하다 | 장난치다→유인하다→먼저 차지하다 | 채집하다→수리하다→조련·납품하다 | 같은 등불 문제를 각자 해결; 공통 운반꾼·우두머리 처치 체인 삭제 |
| 4장 Lv25~32, 폐허 | 통로 지키다→기록 구하다→보존하다 | 허풍 떨다→틈에 낚아채다→장치 속이다 | 부품 찾다→맞추다→시험·복원하다 | 같은 기록의 다른 부분을 얻음; 같은 해골 사냥 복사 없음 |
| 5장 Lv33~35, 폐허 첫 결말 | 흔들리는 길 지키다→운반자 호위하다→자리 내주다 | 자원한 부하 지휘하다→먼저 옮기다→무대 나누다 | 냉각품 만들다→받침 고치다→설치하다 | 개인 조각을 안정시키는 결말, 전역 왕관전 상태는 불변 |

선택은 진영과 별개다. 빛도 자기 전시를 고르고 뿔도 나눌 수 있다. 장인도 공용/내 작업용을 고른다. 신규 선택의 점수는 기본 0, 기존 Pick과 보상은 보존한다. 8~14세가 먼저 웃도록 쓴다. 뿔의 장난은 아이·동물을 괴롭히지 않으며, 역효과는 플레이어·자원한 성인 고블린에게 무해하게 돌아온다.

## 3. 표 읽는 법과 공통 계약

주선은 각 표의 순서다. `H/R/N`은 설명용 진영 표기이고 기존 ID는 유지한다. 같은 행의 화살표는 단계 순서다. 각 행의 영어 한 문장이 Offer이며 버튼은 항상 **Accept / Decline**이다. 거절·닫기는 벌점 없이 다시 수락 가능하다. `—`는 별도 선택 없이 표의 실물 결과가 생긴다는 뜻이다.

**유형은 주로 하는 행동**이다. 전투 이름만 바꿔 반복하지 않는다. 연속 행의 주유형을 다르게 배치했고, 세부 목표도 같은 종류의 연속 클릭은 한 묶음으로 센다. 수락·복귀 Talk를 끼워 사냥 반복을 감추지 않는다. 시험은 사냥→도움→귀환이며, Lv5 사냥 공통은 명시된 예외다. 선택 지선은 강제 삽입하지 않고 직전 주행동과 다른 제안을 먼저 보여준다.

| 유형 | 현재 판정 / 새로 필요한 것 |
|---|---|
| 전투·기술 | Kill / BasicKill / SkillHit / 기존 Tasks; 스킬은 수동으로 실제 몬스터에 적중해야 셈 |
| 채집·제작·판매 | Gather / Craft / SellMat; 의뢰품·레시피·소유자 필터 확장 필요 |
| 조사·회수·배달·수리·설치 | 새 서버 Event. Near나 Enter로 줍기·납품 완료를 대신하지 않음 |
| 호위·구조·방어 | 새 Event. 도착·위협 제거·보호 대상 상태 확인; 타이머만 버티면 완료되는 방어 금지 |
| 선점·허풍·장난·지휘·유인·조련 | 새 Event. 타이밍 창/단서 답/장치 발동/명령 지점/유인 도착/간식 반응을 각각 검증; 전부 Talk 한 번으로 대체 금지 |
| 선택·전시 | Choice+개인 WorldFlags; 물건·NPC 동작·사용 자리 중 하나가 실제로 바뀜 |

Guide 열은 **현재 단계의 대상→다음 대상→완료 대상**이다. 아래 이름 중 새 물건은 제안 앵커이며 이미 존재하는 Guide 키가 아니다. 기존 지역·NPC에 연결해 제작한다. 가방·스킬 버튼은 UI Guide, 대장간은 Blacksmith, 연못은 SlimePond, 지역 키는 SlimeMeadow/GoblinWoods/SkeletonRuins다. Pip의 현장 배치는 단계별로 만들되 실제 몸 앞에서만 수락·완료한다.

| 보상 표기 | 기존 단위·지급 규칙 |
|---|---|
| 기존(ID) | 현재 해당 ID의 기본·선택 보상 전부 보존; ID 없는 행에 쓰지 않음 |
| G / GX | 신규 골드 / 골드+캐릭터 XP 예산, 기존 HuntValue 환산 단위 사용; 정액·계수는 실측 뒤 설정 |
| 주문급여 | 기존 골드·캐릭터 XP 단위; 제작 숙련 XP와 구분, 새 토큰 없음 |
| 기록 | 단서·개인 연출 저장만, 전투 스탯·새 화폐 없음 |

`Reward.Gold=1`은 정액 1골드가 아니다. `GoldN`은 정액, `XPBar`는 기존 레벨 비율이다. 첫 T1·150골드, N0계열 150골드, Lunch1의 HP1/25골드·가방+4를 유지한다. H1/R1/N3의 현재 GoldN120·XPBar0.5 및 선택 Enh70×1 / HP×3+220골드를 임의로 바꾸지 않는다. 신규 보상 수치는 빈칸을 확정값처럼 배포하지 않는다.

### 첫 30분의 고정 장면

| 목표 구간 | 사건 | 측정할 것 |
|---|---|---|
| 0~5분 | 기존 오프닝·진영/직업→오토 무기→도시락 부탁→왕자1→팔찌·T2·주문서 | 오프닝 포함, 도시락 거절 가능, 미배운 스킬 요구0 |
| 5~10분 | Lv5 사냥4+도움1→스승 배움→등불·팔찌 반응 | 실제 Lv5 도달과 왕복 시간; 반복 사냥을 몰래 붙이지 않음 |
| 10~20분 | 진영별 소포 처리→연못→분수→각자 보급 행동 | 세 편의 버튼·대상·실패 방식이 다른지 |
| 20~30분 | Lv10 숲의 구출 / 유인 장난 / 수리 주문 | 공통 보스 재처치 없이 각자 등불 결말까지 가능한지 |

시간은 실측 전 목표다. 제작 숙련 XP를 캐릭터 XP로 계산하지 않는다. Lv5/10/15/25/35 도달이 부족하면 일회성 완료 XP와 기존 성장 경로를 먼저 측정하고 보상안을 검수한다.

## 4. Halo 전체 주선 — 먼저 가서 길을 지키는 편

| 순서·장·Lv·ID | 부탁자 상태 | Offer — Accept / Decline | 유형·실제 목표 | Guide 대상 순서 | 선택→보이는 결과 | 보상 |
|---|---|---|---|---|---|---|
| H00·1·1·Tutorial | Gleam[몸] | Please get a weapon from Otto. | 방문: 오토 첫 무기 수령 | Gleam→Blacksmith/Otto | —; 오토가 무기를 건네고 길을 가리킴 | 무료 T1·150골드 |
| H01·1·1·M1_1[H] | Otto[몸] | Please free the shiny band from that slime. | 전투: BigSlime1→팔찌 조사→T2 장착·주문서 사용 | Otto→초원 왕자→팔찌→Bag | —; 두 색 매듭이 펴짐 | 기존(M1_1)+미지급 M1_2·첫 드롭 |
| H02·1·3·H_Band | Bright[몸] | Please hold that band beside my ribbon. | 조사: 팔찌와 손목 리본 대조 | Bright→리본→Bright | 보여주기/잠깐 가리기; Bright가 손목 숨김/까치발로 봄 | 기록; M1_2 단서 슬롯, 추가 급여0 |
| H03·1·5·M1_3[H] | Gleam[몸] | Beat four slimes, then return our neighbor's bag. | 시험: BasicKill Slime4→짐 회수·Folk1 전달1→귀환 | Gleam→초원 입구→짐→Folk1[주민]→Gleam | —; 주민이 짐보다 큰 손인사, 스승 시범 | 첫 스킬·기존(M1_3) |
| H04·1·5·M1_4[H] | Bright[몸] | Please try your dust in this lamp. | 선택: 가루를 등불/내 표식에 사용 | Bright→등불→Bright | 공용 등불/내 빛; 주민 박수/손으로 눈 가리며 웃음 | 기존(M1_4) |
| H05·2·5·H1 | Bright[몸] | Please guard this parcel cart across the bridge. | 호위: 소포 수레를 다리 끝까지→생일 메모 확인 | Bright→다리 수레→안전 턱→Bright | 생일 선물 알리기/내 비밀 간식이라 자랑; 간식 나누는 원/내 얼굴에 자랑 리본 | 기존(H1), 사실 공유/내 이익 Pick 대응 |
| H06·2·5·M2_2[H] | Bright[몸] | Please catch the sample before it floats away. | 구조: 연못 낚싯대 지점 선택→떠가는 표본 건짐 | Bright→SlimePond 건짐 자리→표본 | 손에 받기/통에 받기; 물방울이 내 신발/통에 튐 | 기존(M2_2) |
| H07·2·5·M2_3[H] | Tiny[몸] | Please bring that dust to the fountain. | 선택: 표본 운반→분수/내 표식 | Tiny→Fountain→Tiny | 분수 켜짐/개인 빛; 두 아이가 눈 마주치고 각자 숨음 | 기존(M2_3) |
| H08·2·6·M2_4[H] | Tiny[몸] | Please walk beside our supply cart. | 호위: 구호 수레를 길목 정차점까지 지킴 | Tiny→교차로 수레→초원 정차점 | 안쪽/바깥쪽 길; 수레가 작은 경사/웅덩이를 돌아감 | 기존(M2_4) |
| H09·2·6·M2_5[H] | Tiny[몸] | Please clear the slimes around our cart. | 기술: 배운 첫 스킬로 몬스터2 동시 적중1→수레 통과 | Tiny→정차점 슬라임→숲 입구 인계대 | —; 길이 열리자 상자 뚜껑이 박수처럼 달그락 | 기존(M2_5) |
| H10·2·7·M2_6[H] | Tiny[몸] | Please find which way the missing porter went. | 조사: 발자국2를 한 묶음으로 대조→자루 천 확인 | Tiny→보급로 발자국→걸린 천→Tiny | —; 천이 구조할 운반자의 길을 가리킴 | 기존(M2_6) |
| H11·3·10·M2_7[H] | Gleam[몸] | Please help the porter at the woods gate. | 구조: 숲 진입→쓰러진 짐 옆 Pip을 안전 턱으로 안내 | Gleam→WoodsGate→Pip[몸 필요]→안전 턱 | 짐 먼저/손 먼저; Pip이 짐/내 팔을 붙들고 일어남 | 기존(M2_7)·가방+4 |
| H12·3·10·M3_1[H] | Pip[몸 필요] | Please stop the carrier chasing our cart. | 전투: 수레를 쫓는 지정 Goblin1 저지→쪽지 확인 | Pip→추격 운반꾼→떨어진 쪽지→Pip | —; 쪽지에 갚겠다는 말과 간식 그림 | 기존(M3_1) |
| H13·3·11·M3_2[H] | Pip[몸 필요] | Please lead me past those noisy barrels. | 호위: 두 안전 정차점을 골라 Pip과 등불 자리 도착 | Pip→통 사이 길→빈 등불 | 가까운 길/넓은 길; Pip이 배를 집어넣음/여유롭게 손 흔듦 | 기존(M3_2) |
| H14·3·12·M3_3[H] | Pip[몸 필요] | Please guard our dust while I lift the cart. | 방어: 가루 자루를 노리는 GoblinBrute1 저지→수레 들어올림 | Pip→가루 수레→접근 Brute→Pip | —; 수레 밑에서 두 아이 그림이 나옴 | 기존(M3_3) |
| H15·3·12·M3_4[H] | Pip[몸 필요] | Please leave a little dust for our lamp. | 선택: 가루 일부 나누기/내 보관함에 넣기 | Pip→빈 등불/개인 보관함→Pip | 등불 켜짐/내 상자 반짝; Pip이 작은 빈 컵을 내밈 | 기존(M3_4) |
| H16·3·15·TR15_H | Gleam[몸] | Pass the hunt, then escort our porter. | 시험: §7 Lv15 사냥→짐 든 Pip 호위1→귀환 | Gleam→숲 시험터→Pip[몸 필요]→안전 턱→Gleam | 앞에서/옆에서 안내; Pip의 이동 대형 변경 | 2번 스킬, 추가 급여0 |
| H17·3·18·M3_6[H] | Pip[몸 필요] | Please catch our records before the shelf falls. | 구조: 받침 위치 선택→넘어지는 기록함 받아 안전대에 둠 | Pip→숲 임시 선반→안전대→Pip | 기록함/등불부터; 마지막에 두 물건 모두 안전, Pip의 든 짐 달라짐 | 기존(M3_6) |
| H18·3·21·M3_7[H] | Pip[몸 필요] | Please guard the cart at each bend. | 방어: 두 굽이의 위협 저지→수레 도착 | Pip→숲 수레 굽이→폐허 입구 보관대 | 안쪽/뒤쪽 지키기; Pip이 반대편을 맡음 | 기존(M3_7) |
| H19·4·25·M3_8[H] | Gleam[몸] | Please inspect the old road before we use it. | 조사: 폐허 안전 고리의 발판·옛 도장 확인 | Gleam→폐허 안전 입구→발판·도장→Gleam | —; 기사 표장 밑에서 뿔 표식도 보임 | 기존(M3_8) |
| H20·4·25·TR25_H | Gleam[몸] | Pass the hunt, then guard the loading ramp. | 시험: §7 Lv25 사냥→적재 경사로 보호1→귀환 | Gleam→폐허 시험터→Pip[몸 필요] 경사로→Gleam | 사람 길/짐 길 지키기; Pip이 열린 반대편으로 운반 | 3번 스킬, 추가 급여0 |
| H21·4·27·H4_1 | Pip[몸 필요] | Please guide our record cart under the arch. | 호위: 낙하 예고를 보고 정차·출발, 기록 수레 통과 | Pip→폐허 안전 아치→보관대→Pip | 낮은 길/넓은 길; 수레 리본이 접힘/펼쳐짐 | G |
| H22·4·30·H4_2 | Pip[몸 필요] | Please catch both pages from that loose box. | 구조: 두 위치에 받침 펼침→날리는 기록 두 장 회수 | Pip→느슨한 기록함→받침→Pip | 왼쪽/오른쪽부터; 내 머리에 마지막 빈 종이가 붙음 | G·기록 |
| H23·4·32·H4_4 | Bright[몸] | Please show me how the two pages fit. | 전시: 두 기록 맞춤→공용판/내 전시판 | Bright→고향 기록판→Bright | 양쪽 나란히/내 장 앞에; Bright가 뒤쪽 보려고 빙 돌아감 | GX |
| H24·5·33·H5_1 | Pip[몸 필요] | Please hold the crossing while I move the shard. | 방어: 흔들림 예고마다 안전 걸쇠 잡기, 운반자 통과 | Pip→폐허 안전 다리→걸쇠→Pip | 왼쪽/오른쪽 담당; Pip이 반대쪽을 잡고 엄지 듦 | G |
| H25·5·34·H5_2 | Pip[몸 필요] | Please walk with me to the cool stone. | 호위: 뜨거운 조각 운반자의 쉼 지점2 선택→냉각대 | Pip→그늘 표식→냉각대→Pip | 짧게 자주/넓은 곳 한 번; Pip의 쉬는 동작 차이 | G |
| H26·5·35·H5_3 | Bright[몸] | Please choose a place for our little light. | 선택: 식은 조각을 공용 등불/내 전시대에 놓음 | Bright→고향 공용 등불/개인 전시대→Bright | 주민이 모임/내 그림자에 모자 장난; 첫 결말 | GX·기록 |

## 5. Horns 전체 주선 — 내가 대장이라며 먼저 뛰는 편

| 순서·장·Lv·ID | 부탁자 상태 | Offer — Accept / Decline | 유형·실제 목표 | Guide 대상 순서 | 선택→보이는 결과 | 보상 |
|---|---|---|---|---|---|---|
| R00·1·1·Tutorial | Rose[몸] | Please ask Otto for your first weapon. | 방문: 오토 첫 무기 수령 | Rose→Blacksmith/Otto | —; 무기를 들자 내 멋진 자세가 살짝 흔들림 | 무료 T1·150골드 |
| R01·1·1·M1_1[R] | Otto[몸] | Please grab the shiny band from that slime. | 전투: BigSlime1→팔찌 조사→T2 장착·주문서 사용 | Otto→초원 왕자→팔찌→Bag | —; 자랑하려니 팔찌가 내 머리에 걸림 | 기존(M1_1)+미지급 M1_2·첫 드롭 |
| R02·1·3·R_Band | Rose[몸] | Please show me your biggest victory pose. | 허풍: 자세 둘 중 하나→팔찌 매듭 보여주기 | Rose→안전 포즈 자리→Rose | 팔 번쩍/깊은 인사; 팔찌가 코/이마로 내려옴 | 기록; M1_2 단서 슬롯, 추가 급여0 |
| R03·1·5·M1_3[R] | Rose[몸] | Beat four slimes, then take Tiny this snack prank. | 시험: BasicKill Slime4→간식 소포 Tiny 전달1→귀환 | Rose→초원 입구→Rose 소포→Tiny→Rose | —; 열면 간식, 내 머리에 리본이 튀고 Tiny도 웃음 | 첫 스킬·기존(M1_3) |
| R04·1·5·M1_4[R] | Rose[몸] | Please show us what that dust can do. | 선택: 등불/내 뿔에 가루 | Rose→등불→Rose | 마을 빛/내 빛; 주민 박수/내 그림자를 보고 우스운 포즈 | 기존(M1_4) |
| R05·2·5·R1 | Rose[몸] | Please grab that rolling parcel before the bell. | 선점: 무인 소포 경사로의 타이밍 창에 잡기→메모 확인 | Rose→교차로 소포 경사로→정지선→Rose | 생일 선물 알리기/내 작전이라 자랑; 모두 간식/내 모자에서 간식이 쏟아짐 | 기존(R1), 사실 공유/내 이익 Pick 대응 |
| R06·2·5·M2_2[R] | Rose[몸] | Please trick that slime into bouncing the sample ashore. | 유인: 내 삑삑 장치를 세 지점 중 설치→슬라임이 빈 부표 밀기 | Rose→SlimePond 장치 자리→밀려온 표본→Rose | 높은/낮은 소리; 내 장치가 내 쪽으로 물을 뿜음 | 기존(M2_2) |
| R07·2·5·M2_3[R] | Tiny[몸] | Please show the fountain your shiny sample. | 선택: 분수/내 표식에 표본 | Tiny→Fountain→Tiny | 분수 켜짐/내 빛; 두 아이가 마주치고 다른 쪽으로 숨음 | 기존(M2_3) |
| R08·2·6·M2_4[R] | Tiny[몸] | Please talk Pip into carrying our snack flag. | 허풍: 실제 상자 무게를 보고 맞는 대장 약속 선택→Pip 동의 | Tiny→보급 상자→Pip[몸 필요]→출발선 | 내가 앞장/내가 뒤짐; 허풍 끝에 내가 더 큰 빈 상자를 듦 | 기존(M2_4) |
| R09·2·6·M2_5[R] | Pip[몸 필요] | Please draw those slimes into your squeaky trap. | 장난: 삑삑 미끼 위치 선택→당김 줄로 몬스터2 유인→첫 스킬 동시 적중1 | Pip→초원 미끼 자리→당김 줄→모인 슬라임→Pip | 내 앞/옆으로 유인; 빈 장난 뚜껑이 내 머리로 돌아옴 | 기존(M2_5) |
| R10·2·7·M2_6[R] | Pip[몸 필요] | Please pick a lookout spot for your new helper. | 지휘: 자원한 성인 Pip에게 관측점 명령→천 조각 위치 보고 | Pip→보급로 관측점2 중1→걸린 천→Pip | 높은 턱/자루 위; Pip의 과장된 경례가 달라짐 | 기존(M2_6) |
| R11·3·10·M2_7[R] | Rose[몸] | Please take our squeaky flag into the woods. | 장난: 숲 입구 무인 깃대에 삑삑 깃발 설치 | Rose→WoodsGate 깃대→Pip[몸 필요] | 짧게/길게 울리기; 깃발이 돌아 내 쪽에서만 삑삑 | 기존(M2_7)·가방+4 |
| R12·3·10·M3_1[R] | Pip[몸 필요] | Please grab the receipt while the carrier naps. | 선점: 운반꾼이 내려놓은 의뢰 봉투를 깨어나기 전 회수 | Pip→숲 봉투 정차대→Pip | 굴러서/상자 뒤로 접근; 성공 뒤 빈 뚜껑이 내 머리에 씌워짐 | 기존(M3_1) |
| R13·3·11·M3_2[R] | Pip[몸 필요] | Please lure the Brute away with this squeaky box. | 유인: 미끼 상자 경로 선택→Brute가 빈 자리로 이동 | Pip→숲 빈 공터→미끼 도착점→Pip | 긴 길/빙 도는 길; 내 삑삑 신발도 같이 울림 | 기존(M3_2) |
| R14·3·12·M3_3[R] | Pip[몸 필요] | Please tell your helper when to roll the sack. | 지휘: Pip에게 멈춤/굴림 명령→가루 자루 회수 | Pip→빈 가루 적재대→안전선→Pip | 한 번에/나눠 굴림; 마지막 빈 자루에 내가 잠깐 덮임 | 기존(M3_3) |
| R15·3·12·M3_4[R] | Pip[몸 필요] | Please pick a lamp for our grand entrance. | 선택: Pip 등불/내 자랑 상자에 가루 | Pip→숲 등불/개인 상자→Pip | 공동 입장/나부터 등장; Pip이 박수/손전등 흉내 | 기존(M3_4) |
| R16·3·15·TR15_R | Rose[몸] | Pass the hunt, then sort out your squeaky helper. | 시험: §7 Lv15 사냥→Pip을 지휘해 장난 표지 정리1→귀환 | Rose→숲 시험터→Pip[몸 필요] 표지 자리→Rose | 손짓/휘파람 명령; 내 장치가 마지막에 내게 경례 소리 | 2번 스킬, 추가 급여0 |
| R17·3·18·M3_6[R] | Pip[몸 필요] | Please bluff your way past our pretend toll booth. | 허풍: 영수증 그림을 보고 통행 암호 선택→놀이 문 열기 | Pip→숲 놀이 요금소→문 뒤 상자→Pip | 엄숙한/우스운 암호; 내 대장 도장이 얼굴 그림으로 찍힘 | 기존(M3_6) |
| R18·3·21·M3_7[R] | Pip[몸 필요] | Please beat my cart to the old stamp stand. | 선점: 개인 시험용 수레와 다른 길로 달려 도장 먼저 찍기 | Pip→숲 갈림길→폐허 앞 도장대→Pip | 지름길/넓은 길; 내가 찍은 도장이 거꾸로/옆으로 남음 | 기존(M3_7) |
| R19·4·25·M3_8[R] | Rose[몸] | Please try our secret knock at the old gate. | 장난: 폐허 안전문 소리 패턴 맞추기→종이 왕관 발사 | Rose→폐허 안전 입구 문→Rose | 작은/큰 마지막 두드림; 내 머리에 작은/큰 종이 왕관 | 기존(M3_8) |
| R20·4·25·TR25_R | Rose[몸] | Pass the hunt, then draw the cart away with a decoy. | 시험: §7 Lv25 사냥→빈 경비 수레를 미끼로 안전 만에 유인1→귀환 | Rose→폐허 시험터→빈 수레→미끼 정차대→Rose | 삑삑/덜컹 미끼; 수레가 내 빈 모자를 끌고 옴 | 3번 스킬, 추가 급여0 |
| R21·4·27·R4_1 | Pip[몸 필요] | Please claim the loose scroll before the shutter closes. | 선점: 자동 덧문 틈에 안전 손잡이 당겨 두루마리 받기 | Pip→폐허 안전 기록대→받침→Pip | 위/아래 손잡이; 빈 두루마리가 내 팔에 감김 | G |
| R22·4·30·R4_2 | Pip[몸 필요] | Please fool the old bell with this echo tube. | 장난: 울림 관 방향 바꾸기→기록함 잠금 해제 | Pip→폐허 울림 관→기록함→Pip | 짧은/긴 울림; 내 승리 소리가 우스운 저음으로 되돌아옴 | G·기록 |
| R23·4·32·R4_4 | Rose[몸] | Please choose the picture for our big tale. | 전시: 두 기록을 이야기판에 배치 | Rose→고향 이야기판→Rose | 둘 다/내 얼굴 앞에; Rose가 판 뒤에서 고개를 빼꼼 | GX |
| R24·5·33·R5_1 | Pip[몸 필요] | Please command our grand shard delivery. | 지휘: Pip 정차·내 깃발 신호로 조각 운반대를 이동 | Pip→폐허 안전 운반대→냉각대 앞→Pip | 팔 신호/깃발 신호; 내 깃발이 내 얼굴을 가림 | G |
| R25·5·34·R5_2 | Pip[몸 필요] | Please reach the cool stand before my empty cart. | 선점: 조각을 들고 안전 지름길 선택→냉각대 배치 | Pip→안전 갈림길→냉각대→Pip | 안쪽/바깥쪽; 우승 자세 뒤 내 모자가 뒤집힘 | G |
| R26·5·35·R5_3 | Rose[몸] | Please pick who joins your big entrance. | 선택: 공동 무대/내 단독 무대에 식은 조각 설치 | Rose→고향 공동 등불/개인 무대→Rose | 모두 등장/나부터; 단독 포즈 때 주민들이 뒤에서 따라 함 | GX·기록 |

뿔의 선점 대상은 개인 퀘스트 물건이다. 다른 플레이어의 드롭·주문·재료를 빼앗지 않는다. 실패하면 물건이 안전 위치로 돌아오고 즉시 재시도한다. Pip은 자원한 성인 고블린이며 아기 펫을 명령 시험에 쓰지 않는다.

## 6. Artisan 전체 주선 — 만들어서 쓰는 모습을 보는 편

S=대장장이, A=연금술사, T=조련사. `W2/AP1/T1`은 현재 레시피를 사용한다. W2는 내 무기로 남기고 도움용 부품은 의뢰 전용 파트로 처리한다. AP1은 HP, T1은 간식의 실제 제작·사용을 확인한다. 후반 주문품은 새 퀘스트 Event이며 기존 상점 레시피라고 주장하지 않는다.

**현재 접수·귀환은 교차로/Forge/작업대뿐이다.** 아래 이전 열의 `접수·작업`은 장인 마을 완공 시 그 부분만 이동, `접수`는 NPC 접수만 이동, `유지`는 교차로 이야기 장면 유지다. 현장인 초원·숲·폐허는 이동하지 않는다. 오토 스승·Forge의 이동 여부는 별도 배치 결정 전 현재 자리 고정이다.

| 순서·장·Lv·ID | 부탁자 상태 | Offer — Accept / Decline | 유형·실제 목표 | Guide 대상 순서 | 선택→보이는 결과 | 보상 | 장인 마을 완공 시 이전 |
|---|---|---|---|---|---|---|---|
| N00·1·1·Tutorial | Otto[몸] | Please collect your first tool from my anvil. | 방문: Forge 첫 무기·도구 수령 | 교차로 Otto→Blacksmith | —; 작업대에 내 주문표가 걸림 | 무료 T1·150골드 | 유지(Forge) |
| N01·1·1·M1_1[N] | Otto[몸] | Please bring back the shiny band from that slime. | 전투: BigSlime1→팔찌 조사→T2 장착·주문서 사용 | Otto→초원 왕자→팔찌→Bag | —; 재료 봉투에서 두 색 매듭이 튀어나옴 | 기존(M1_1)+미지급 M1_2·첫 드롭 | 유지 |
| N02·1·3·N0계열 준비 | Otto[몸] | Please gather the materials for your first order. | 채집: S Herb3·CopperOre2 / A·T Herb3→주문 보관 | Otto→교차로 인근 해당 채집점→작업대 | 작은/큰 묶음 포장; 개인 주문 봉투 크기만 변경 | 완료 급여는 N03에서1회 | 작업만 이전 |
| N03·1·5·M1_3[N]+N0계열 완료 | Otto[몸] | Beat four slimes, then make something for Tiny. | 시험: BasicKill Slime4→S W2+의뢰부품 / A AP1·HP1 / T T1·간식1 제작·Tiny 도움1→귀환 | Otto→초원 입구→교차로 직업 작업대→Tiny→Otto | —; 수레 바퀴 회전/약병 받음/아기 슬라임 접근 | 첫 스킬·기존(M1_3)+자기 N0계열150골드1회 | 작업만 이전; 시험 귀환 Forge |
| N04·1·5·M1_4[N] | Tiny[몸] | Please choose a home for our repaired lamp. | 선택: 공용 등불 수리/작업등에 가루 | Tiny→교차로 등불/작업등→Tiny | 모여드는 주민/내 도구 빛; Tiny가 눈을 가리고 웃음 | 기존(M1_4) | 작업등만 이전 |
| N05·2·5·N3 | Tiny[몸] | Please mend these two birthday parcels. | 수리: 찢어진 포장2를 한 작업으로 맞춤→같은 주문표 발견 | Tiny→교차로 포장대→Tiny | 두 편지 연결/길드 비밀상품이라 자랑; 두 간식 접시/내 상표가 간식을 가려 Tiny가 들춰 봄 | 기존(N3), 사실 공유/내 이익 Pick 대응 | 유지(생일 장면) |
| N06·2·5·M2_2[N] | Otto[몸] | Please collect clean dust with this little filter. | 채집: 연못 채취점 선택→여과망으로 표본1 확보 | Otto→SlimePond 여과 자리→표본통→Otto | 고운/굵은 망; 망에 걸린 무해한 돌의 크기 차이 | 기존(M2_2) | 유지 |
| N07·2·5·M2_3[N] | Tiny[몸] | Please fit your sample into the fountain. | 선택: 분수 받침/내 작업용 표본함 | Tiny→Fountain→Tiny | 분수 켜짐/도구 빛; 두 아이가 같은 매듭을 보고 숨음 | 기존(M2_3) | 유지 |
| N08·2·6·N2 | Otto[몸] | Please make the supplies on Pip's order. | 제작: S 축 부품 / A 구호병 / T 간식 꾸러미1, 지급 의뢰 재료 사용 | Otto→교차로 직업 작업대→완성품함 | 둥근/네모 포장; 상자 실물 변경 | 기존(N2), M2_4 급여 중복0 | 작업만 이전 |
| N09·2·6·N1 | Otto[몸] | Please set up a safe stand for your supplies. | 설치: S 상자 받침 / A 새는 병 고정대 / T 간식 보관대 조립→다가오는 몬스터2에 첫 스킬 동시 적중1 | Otto→초원 임시 작업 자리→직업 받침→접근 슬라임→정차점 | 낮은/높은 받침; 완성품이 흔들리지 않고 놓임 | 기존(N1), M2_5 급여 중복0 | 유지 |
| N10·2·7·N4 | Pip[몸 필요] | Please bring me the supplies I ordered. | 배달: 귀속 주문품 인계→S 끼우기 / A 병 전달 / T 간식 사용 확인 | 숲 입구 Pip→수레/구호대/간식 자리→Pip | 즉시 사용/내 상표 붙인 뒤 사용; 수령 동작·상표 차이 | 기존(N4), Gold3/XP3 단위 보존 | 유지(현장 인계) |
| N11·2·8·M2_6[N] | Pip[몸 필요] | Please fix the wheel that dropped my receipt. | 수리: 바퀴 걸림 해제→안쪽의 가루 주문표 회수 | Pip→보급로 바퀴→영수증→Pip | —; 바퀴가 돌자 영수증이 내 얼굴에 붙음 | 기존(M2_6) | 유지 |
| N12·3·10·M2_7[N] | Otto[몸] | Please collect the missing parts by the woods gate. | 채집: 숲 입구 의뢰 재료3점 수거→주문함 보관 | Otto→WoodsGate 부품 자리→Pip[몸 필요] 주문함 | 작은/큰 통; 재료 담기는 모양 변경 | 기존(M2_7)·가방+4 | 유지 |
| N13·3·10·M3_1[N] | Pip[몸 필요] | Please mend our lamp before it wobbles away. | 수리: S 받침 / A 새는 병 / T 당김 끈을 맞춰 등불 안정 | Pip→숲 등불 작업 자리→Pip | 왼쪽/오른쪽 지지; 등불 기울기 회복 방향 차이 | 기존(M3_1) | 유지 |
| N14·3·11·M3_2[N] | Pip[몸 필요] | Please bring the right filling for this lamp. | 채집: 빈 등불의 그림 확인→해당 재료1 묶음 확보 | Pip→등불 그림→숲 의뢰 재료함→Pip | —; 재료 아래서 두 아이 그림이 펼쳐짐 | 기존(M3_2) | 유지 |
| N15·3·12·M3_3[N] | Pip[몸 필요] | Please build the last piece for our night-light. | 제작: S 받침 / A 안전 냉각병 / T 운반 간식1 제작 | Pip→숲 임시 작업대→등불 받침→Pip | 낮은/높은 장식; 같은 기능의 의뢰품 실물 차이 | 기존(M3_3) | 유지(현장 작업) |
| N16·3·12·M3_4[N] | Pip[몸 필요] | Please choose where our finished lamp goes. | 선택: Pip 공용 등불/내 주문 전시함에 완성품 설치 | Pip→등불 자리/개인 전시함→Pip | 주민이 모임/내 상자 반짝; Pip이 빈 컵을 모자처럼 씀 | 기존(M3_4) | 유지 |
| N17·3·15·TR15_N | Otto[몸] | Pass the hunt, then help our next customer. | 시험: §7 Lv15 사냥→S 수레 수리 / A 약 제작·전달 / T 간식 제작·따라오기1→귀환 | Otto→숲 시험터→직업 작업대→Tiny/아기 슬라임→Otto | 공용 표식/내 서명; 사용 물건의 꼬리표 변경 | 2번 스킬, 추가 급여0 | 작업만 이전 |
| N18·3·18·M3_6[N] | Tiny[몸] | Please bring back the borrowed tool case. | 배달: 숲 작업대의 도구함을 교차로 Tiny에게 운반 | Tiny→숲 작업대 도구함→Tiny | 손잡이/끈 운반; 내 들고 가는 자세 차이 | 기존(M3_6) | 접수·반납 이전 |
| N19·3·21·M3_7[N] | Otto[몸] | Please make one order for each side. | 제작: 직업 부품1묶음→양쪽 수령함에 나눠 넣음 | Otto→교차로 작업대→두 수령함→Otto | 같은 포장/각자 표식; 양쪽 상자가 같은 내용으로 열림 | 기존(M3_7) | 작업·수령함 이전 |
| N20·4·25·M3_8[N] | Otto[몸] | Please match the old maker's marks. | 조사: 폐허 안전 고리 부품 도장2 대조 | Otto→폐허 안전 입구 도장→Otto | —; 다른 진영 표식의 연결 홈이 맞음 | 기존(M3_8) | 유지 |
| N21·4·25·TR25_N | Otto[몸] | Pass the hunt, then make the worksite usable. | 시험: §7 Lv25 사냥→S 난간 수리 / A 냉각병 제작·사용 / T 간식으로 기존 아기 안전 안내1→귀환 | Otto→폐허 시험터→안전 작업 자리→Otto | 공용 표식/내 서명; 손본 자리 꼬리표 변경 | 3번 스킬, 추가 급여0 | 유지 |
| N22·4·27·N4_1 | Otto[몸] | Please gather the parts on this old receipt. | 채집: 폐허 안전 고리 의뢰 부품2→주문 보관 | Otto→폐허 부품함2곳→Otto | 작은/큰 쟁반; 부품 실루엣이 한 장치로 보임 | 주문급여 | 유지 |
| N23·4·30·N4_2 | Otto[몸] | Please test how these odd pieces work together. | 수리: S 홈 맞춤 / A 반응 순서 / T 간식 냄새 길로 아기 안내→기록함 개방 | Otto→폐허 안전 시험대→기록함→Otto | 내 도장/공용 도장; 수리 흔적에 선택한 도장 남음 | G·기록 | 유지 |
| N24·4·32·N4_4 | Tiny[몸] | Please put both orders on our display. | 전시: 두 원본 조립→공용 기록대/내 주문함 | Tiny→교차로 기록대/작업대→Tiny | 원본 나란히/내 주문 앞에; Tiny가 뒤쪽 보려고 몸을 기울임 | GX | 접수·전시 이전 |
| N25·5·33·N5_1 | Otto[몸] | Please make a cool cradle for the shard. | 제작: S 받침 / A 냉각병 / T 운반 간식1→완성 확인 | Otto→교차로 직업 작업대→주문 보관함 | 둥근/네모 꼬리표; 운반품 표시 차이 | 주문급여 | 작업만 이전 |
| N26·5·34·N5_2 | Pip[몸 필요] | Please deliver the cradle to our shaky stand. | 배달: 완성품 폐허 안전대로 운반→직업품 실제 사용 | Pip→폐허 안전 운반대→받침→Pip | 먼저 받침/먼저 냉각; 최종 모두 완료, 중간 동작 차이 | G | 유지 |
| N27·5·35·N5_3 | Tiny[몸] | Please choose who can use our finished light. | 설치: 공용 분수 옆/교차로 내 작업대에 식은 조각 장착 | Tiny→Fountain 옆 공용대/개인 작업대→Tiny | 주민이 모여 씀/내 도구만 빛; Tiny가 큰 도구 그림자와 인사 | GX·기록 | 개인 작업대만 이전 |

의뢰 지급 재료·결과품은 거래·판매 불가인 주문 보관함에 둔다. 개인 가방을 막지 않으며 돈을 다 쓴 초보도 필수 주문을 재시도할 수 있다. 기존 일반 제작의 원가·숙련·레시피 조건은 유지한다. N0 준비는 같은 주문의 단계이며 별도 재료 보상·재수락 파밍이 아니다.

첫 스킬 실전1회는 채택된 학습 목표를 유지한다. 다만 빛은 움직이는 수레 방어, 뿔은 위치·줄 조작으로 유인, 장인은 직업 받침 조립 후 작업장 확보다. 미끼·받침 단계를 생략하고 세 편 모두 같은 몬스터2 적중으로 끝내는 구현은 통과시키지 않는다.

## 7. 스승 시험 — Lv5·15·25, 진영별 9개

9개 시험의 부탁자·Offer·Guide·선택·보상은 H03/H16/H20, R03/R16/R20, N03/N17/N21에 모두 적었다. 아래는 그 행들의 **사냥 단계 공통 사양**이며 새 의뢰가 아니다.

| 레벨 | 사냥 목표 | 빛 도움1 | 뿔 도움1 | 장인 도움1 |
|---|---|---|---|---|
| 5 확정 | 모든 직업 BasicKill Slime4 | 떨어진 주민 짐 회수·전달 | Tiny에게 간식 장난 소포 전달 | 자기 N0계열 제작품으로 실제 도움 |
| 15 제안 | Warrior/Smith: BasicKill Goblin4; Mage/Alch: 첫 스킬로 Goblin2 동시 적중2회; Archer/Tame: 기존 거리 판정 Goblin4 | 짐 든 Pip 짧은 호위 | Pip에게 명령해 장난 표지 정리 | S 수레 축 수리 / A AP1 제작·HP1 전달 / T T1 제작·간식으로 아기 따라오기 |
| 25 제안 | Warrior/Smith/Mage/Alch: 이미 배운 2번 스킬로 Skeleton2 동시 적중2회; Archer/Tame: 기존 거리 판정 Skeleton4 | 적재 경사로 지키기 | 빈 경비 수레 미끼 유인 | S 난간 수리 / A 냉각병 제작·사용 / T 간식으로 기존 아기 안전 안내 |

Lv15/25 수량은 제안이다. 기존 `Skills.Tasks`를 시험의 사냥으로 합치고 별도 숨은 횟수를 남기지 않는다. 기존 내부 슬롯 순서 Q/Z/X와 실제 키 표시는 분리한다. 아직 배우지 않은 슬롯은 시험에 요구하지 않는다. 2·3번 기능이 꺼져 있으면 해당 시험을 노출하지 않고, 주선은 이전 기술로 진행한다. 나중에 열려도 기존에 배운 기술은 회수하지 않는다.

도움은 보상1건으로 센다. 여러 제작·전달 클릭을 도움 여러 건으로 늘리지 않는다. 스승 귀환·거리 검사 후 배움 신호를 보낸다. 실패·재접속 때 완료된 사냥과 도움은 유지한다. 스승 반응은 짧게: Gleam `“My bag is bigger than my shield!”`, Rose `“That ribbon was meant for you!”`, Otto `“It works, and my eyebrows survived!”`.

## 8. 마을별 선택 의뢰 — 각 4개

H1/R1/N3는 주선이므로 여기서 제외한다. 아래는 선택 지선이며 표의 유형 순서로 추천하되 수락을 강제하지 않는다. 장인 의뢰는 전부 교차로에서 접수한다.

| ID·Lv·진영 | 부탁자 상태 | Offer — Accept / Decline | 유형·목표 | Guide 대상 순서 | 선택→보이는 결과 | 보상 | 장인 마을 완공 시 이전 |
|---|---|---|---|---|---|---|---|
| H2·8·빛 | Bright[몸] | Please bring our missing lamp home. | 회수: 초원 등불 찾아 귀환 | Bright→초원 등불→Bright | 공용/내 진열; 등불 자리 변화 | 기존(H2)·HaloChick 조건 | 해당 없음 |
| H3·12·빛 | Gleam[몸] | Please guide the cat down this little ramp. | 구조: 간식 두기→낮은 담장 고양이를 안전 경사로 안내 | Gleam→담장→안전 경사로→Folk1[주민] | 조용히/내 구조 포즈; 고양이 휴식/내 옆 무심한 하품 | 기존(H3)·HaloChick 조건 | 해당 없음 |
| H5·15·빛 | Bright[몸] | Please carry this pass to the waiting cart. | 배달: 통행표 전달→걸쇠 열기 | Bright→길목 수레→Gleam | 먼저 통과/내 도장 추가; 수레 깃발 변화 | 기존(H5) | 해당 없음 |
| H6·22·빛 | Bright[몸] | Please clean the little names on these plaques. | 수리: 명판 닦기·작은 이름표 끼우기 | Bright→고향 명판→Bright | 모두 같은 크기/내 이름 앞; 명판 배치 변화 | 기존(H6)·HaloChick 조건 | 해당 없음 |
| R5·8·뿔 | Rose[몸] | Please catch my hat before it reaches the drain. | 선점: 안전 수로 정지선에서 모자 건짐 | Rose→고향 수로→Rose | 바로 반환/잠깐 쓰기; Rose 착용/내 눈 가린 모자 | 기존(R5)·HornsBat 조건 | 해당 없음 |
| R3·12·뿔 | Rex[몸 필요] | Please test my squeaky surprise box. | 장난: 자원한 성인 Rex와 빈 장치 시험 | Rex→고향 시험 상자→Rex | 간식/삑삑 장치; 내 머리에 리본, Rex도 웃음 | 기존(R3)·HornsBat 조건 | 해당 없음 |
| R6·15·뿔 | Rose[몸] | Please convince Pip to try your silly salute. | 허풍: 상황 그림에 맞는 대장 구호 선택→Pip 시범 | Rose→교차로 Pip[몸 필요]→Rose | 근엄/과장; Pip과 내가 서로 반대로 경례 | 기존(R6) | 해당 없음 |
| R7·22·뿔 | Rose[몸] | Please tell our helpers where the party seats go. | 지휘: 자원한 성인 도우미 Pip에게 좌석 배치 지시 | Rose→고향 잔치 자리 Pip[몸 필요]→Rose | 모두 원형/내 자리 앞; NPC 앉는 배치 변화 | 기존(R7)·HornsBat 조건 | 해당 없음 |
| N0b·5·장인 | Otto[몸] | Please sell me five spare materials. | 판매: 실제 남는 재료5 SellMat | Otto→Forge 판매 버튼→Otto | 공용/내 상표 포장; 판매 상자 표시 차이 | 기존30골드+판매대금·GearMouse 조건 | 유지(Forge) |
| NA1·10·장인 | Otto[몸] | Please fix the wheel on our delivery cart. | 수리: S 축 / A 윤활병 / T 운반 끈 정리 | Otto→교차로 수레→Otto | 공용/내 상표; 굴러가는 수레 깃발 차이 | 주문급여 | 작업만 이전 |
| NA2·15·장인 | Tiny[몸] | Please deliver these bottles to the matching baskets. | 배달: 그림 맞는 두 수령함에 주문품 인계 | Tiny→교차로 직업 작업대→수령함2곳→Tiny | 급한 주문/단골 먼저; 실제 열리는 함 순서 차이 | 주문급여 | 접수·작업·수령함 이전 |
| NA3·22·장인 | Tiny[몸] | Please guide our little slime back to its bowl. | 조련: 안전 간식 경로를 골라 기존 아기 슬라임 안내 | Tiny→교차로 간식 지점→주인 Tiny | 조용히/내 포즈; 아기가 내 발/그릇 옆에 앉음 | G·기록, 펫 지급 아님 | 접수·안전 경로 이전 |

## 9. 세 편이 만나는 장면과 같은 사실의 다른 해석

| 공유 장면 | 빛 | 뿔 | 장인 | 공유하는 범위 |
|---|---|---|---|---|
| 첫 Slime Prince·팔찌 | 구해 낸 물건 | 먼저 챙긴 반짝이 | 살펴볼 표본 | 첫 왕자1 처치·두 색 매듭·T2/주문서만 공통 |
| 매듭·생일 소포 | 수레 호위로 발견 | 굴러가는 소포 선점 | 포장 수리로 발견 | 같은 생일 메모, 획득 행동은 서로 다름 |
| 분수 | 건져 낸 표본 | 유인해서 받은 표본 | 여과한 표본 | 가루 선택·두 아이 눈맞춤은 공통 필수 장면 |
| 숲 등불 | 운반자를 구하고 가루 지킴 | 빈 자리로 유인하고 자루 굴림 지휘 | 재료 모아 실제 등불 제작 | 결과가 같은 장소에 남을 뿐, 공통 처치 묶음 없음 |
| 폐허 기록 | 날리는 기록 받아냄 | 덧문 타이밍·울림 관 장난 | 부품 맞춤·시험 | 공동 수리 흔적만 같음, 동일 조사 클릭3회 복사 없음 |
| 왕관전 | 우리 편 기여 | 우리 편 자랑 | 교차로 물자 작업 | 실제 행사만 공유; 중립 기여 점수·승리로 위장하지 않음 |

### 성장 선택 지선의 완결 구조

아래 공통 지선은 편의 기능·기존 개인 사건이다. 각 진영 본편의 차별화를 대신하는 분량으로 세지 않는다. 주선에 추가 사냥을 강제하지 않는다.

| ID·제안 시점 | 부탁자 상태 | Offer — Accept / Decline | 유형·목표 | Guide 대상 순서 | 선택→보이는 결과 | 보상 | 장인 마을 완공 시 이전 |
|---|---|---|---|---|---|---|---|
| Lunch1·첫 무기 뒤 | Tiny[몸] | Please find the lunch I dropped near the slimes. | 회수: 슬라임 피하거나 저지→도시락 줍기→귀환 | Tiny→Lunchbox→Tiny | 돌려줌/한 입; 도시락 그대로/빈칸을 보고 Tiny가 볼 부풀림 | 기존 HP1/25골드·가방+4 | 유지 |
| Pet1·보급길 이후 | Tiny[몸] | Please bring that little slime to my bowl. | 조련: 간식 길로 아기를 짧게 안내 | Tiny→보급길 아기→교차로 그릇→Tiny | 돌보기/대장 놀이; 곁에 앉음/내 경례 흉내, 위협 없음 | 기존 BabySlime·기존(Pet1) | 유지 |
| S0·첫 스킬 뒤 | Otto[몸] | Please show your shard how you fight. | 기술: BasicKill Slime3→조각 반응→첫 스킬2 동시 적중1 | Otto→초원 훈련 슬라임→현장 Shard[조각]→Otto | 정화/삼키기; 조각 궤적·표식 반응 차이 | 기존 선택2·자동 전투 해금, 기본 OFF | 유지 |
| S4·S0 뒤 | Otto[몸] | Please test your shard's automatic fighting. | 설정: Auto 버튼 직접 켜기→AutoKill5→복귀 | Otto→Auto 버튼→초원→Otto | 끝에 ON/OFF 직접 선택; 버튼·공격 상태 실제 변경 | 기존(S4) | 유지 |
| SK1·2번 배움 뒤 | 자기 스승[몸] | Please try your new move on the road. | 기술: 2번 스킬 몬스터2 동시 적중1 | 스승→현재 열린 사냥터→스승 | —; 스승이 해당 동작을 짧게 따라 함 | 기존(SK1) | 유지(오토) |
| SK2·3번 배움 뒤 | 자기 스승[몸] | Please show the fountain your new move. | 선택: 분수/내 표식→3번 스킬 실제 적중3회 | 스승→Fountain→현재 사냥터→스승 | 분수/내 표식 반응 차이 | 기존(SK2)·기존 선택1 | 유지 |
| XR1·첫30분 뒤 | Tiny[몸] | Please rescue my teddy from that slime prince. | 전투: 기존 추가 왕자1→곰 회수·반환 | Tiny→초원 왕자→곰→Tiny | 바로 반환/멋진 포즈 뒤 반환; Tiny 포옹/내 포즈 흉내 | 기존(XR1), 보상 분기 변경 별도 검수 | 유지 |
| Pip1·Lv15·기존 선 선택 뒤 | Pip[몸 필요] | Please help me hang the lamp you gave us. | 설치: 낮은 안전 걸이에 등불 장착 | Pip→숲 등불 걸이→Pip | 높게/낮게; Pip 그림자 크기 차이 | 기존(Pip1) | 유지 |

Lunch1 앞 사연은 세 짧은 문장으로 유지한다: `“I packed lunch in secret.”` / `“The slimes chased me!”` / `“Please don't tell Mom.”` 이어서 표의 한 문장 부탁과 Accept/Decline을 보여준다. Tiny는 현재 몸을 재사용하며 교차로에서 수락한다. 길목에 복제 몸을 임의로 만들지 않는다.

### 공통 이벤트의 연결

| ID·조건 | 부탁자 상태 | Offer — Accept / Decline | 유형·실제 목표 | Guide 대상 순서 | 선택→보이는 결과 | 보상 | 장인 마을 완공 시 이전 |
|---|---|---|---|---|---|---|---|
| M2_1·1장 뒤·빛/뿔 | Gleam/Rose[몸] | Please help our side by hunting nearby. | 전투: 기존 WarPoints 기여 단위15, 몬스터 사냥으로 가능 | 자기 NPC→가장 가까운 열린 사냥터→자기 NPC | —; 실제 정수 표시 기여·NPC 경례 | 기존(M2_1), 15마리라고 거짓 표기 금지 | 해당 없음 |
| M2_1[N]·1장 뒤 | Otto[몸] | Please earn hunting gold for our supply run. | 전투: 기존 Monster EarnGold45 | Otto→가까운 열린 사냥터→Otto | —; 기존 정산 확정 뒤 보급함 표시 | 기존(M2_1[N]), 전쟁 기여 아님 | 유지 |
| S1·행사 가능 시 | Tiny[몸] | Please join the egg hunt and show me your haul. | 행사: 현재 참가 허용 진영의 유효 참여1→본 교차로 귀환 | Tiny→Goose Join 버튼→행사→교차로 Tiny | —; 실제 참가 결과 뒤 Tiny가 달걀 흉내 포즈 | 기존(S1), 중립 허용 여부는 현행 규칙 | 유지 |
| S2·기존 자격 충족 | Gleam/Rose[몸] | Please open the Crown War chest you earned. | 수령: 실제 지급 자격 있는 상자1 열기 | 자기 NPC→실제 상자 버튼/위치→자기 NPC | —; 실제 상자 내용·반응만 표시 | 기존(S2), 가짜 상자0 | 해당 없음 |
| NE_GoosePrep·장인·행사 준비 | Tiny[몸] | Please repair this empty egg crate. | 수리: 본 교차로 빈 운반함 손잡이·바닥 고침 | Tiny→교차로 작업대→빈 운반함→Tiny | 공용/내 상표; 운반함 꼬리표 차이 | 주문급여, 행사 참여 횟수0 | 작업만 이전 |

이벤트 지선은 주선의 문이 아니다. 패배·상자 미획득·행사 대기에도 폐허 결말을 본다. 거위 광장에는 새 NPC·납품대·퀘스트 물건을 추가하지 않는다. 중립 면역·행사 참가 제한은 현행 유지한다. 괴수 주변 수리를 참여 횟수로 세지 않는다. 새 괴수 전용 의뢰와 왕관전 후일담은 이번 BUILD 상세 행에서 제외한다.

### 펫 12종과 도감의 위치

| 펫 묶음 | 기존 획득 조건·연결 |
|---|---|
| Baby Slime / Flower Slime / Sprout Goblin / Acorn Goblin / Bone Pup | Pet1·조련 연구·기존 재료/숙련; 없는 펫 소유를 주선·시험 조건으로 쓰지 않음 |
| Crown Slime / Mini Clatter | 각각 King Slime 유효 보상5회 Lv8+ / Clatter3회 Lv30+; 첫 Prince는 King 아님 |
| Halo Chick / Horns Bat / Gear Mouse | H2·H3·H6 / R3·R5·R7 / N0b·N2·N4, 기존 Lv10+·진영 조건 유지 |
| Golden Gosling / Pocket Kaiju | 실제 유효 거위3회 Lv5+ / 괴수3회 Lv15+; 주변 심부름은 횟수0 |

준비된 종만 노출하고, 기존 효과 상한·한 마리 효과·PvP/왕관전 제한과 BabySlime 예외를 유지한다. 전 펫 수집·도감 진화를 엔딩 문으로 쓰지 않는다. 신규 미술 제작을 이 문서가 승인하지 않는다.

## 10. 후반 레벨 공백을 숨기지 않는 운영 구조

**6~7장 = after beta / measure first — 베타 이후, 실측 먼저. 아래 한 표만 남긴다. 상세 퀘스트·보상·NPC·제작 일정은 아직 만들지 않는다.**

| 이후 장 | 빛의 줄거리·주동사 | 뿔의 줄거리·주동사 | 장인의 줄거리·주동사 | 열기 전 실측 |
|---|---|---|---|---|
| 6장 Lv50~79 가안 | 왕관전 뒤 길의 변화: 구조·호위·방어 | 대장 놀이의 후일담: 선점·허풍·장난 정리 | 돌아온 물자 주문: 수거·제작·수리·납품 | Lv35 이후 성장 시간, 실제 전투 난도, 왕관전 참여·대기, 반복 의뢰 이탈 |
| 7장 Lv80~100 가안 | 다음 견습에게 남길 기록: 구출·보존·자리 내주기 | 다음 장난꾸러기와 잔치: 지휘·장난·무대 나누기 | 다음 제작자 작업 자리: 채집·제작·설치·조련 | 6장 완주율·재방문·선택 기억, 기존 지역으로 충분한지, 장인 마을 실제 완공 여부 |

Lv36~49 연결도 측정 전 공백이다. 반복 해골 사냥으로 채웠다고 쓰지 않는다. 코드 MaxLevel100은 그대로지만 **베타 제작 약속은 1~5장, Lv1~35**다. 후반 레벨을 낮추거나 새 지역을 넣는 결정은 이 문서에서 하지 않는다.

## 11. 저장·ID 이전과 보상 중복 방지

### ID 처리표

| 기존 묶음 | v2 처리 | 보존할 것 |
|---|---|---|
| Tutorial·M1_1·M1_2 | 첫 왕자1로 통합, M1_2는 호환 정의만 유지 | T1·150골드·첫 드롭·주문서·미지급 보상만1회; H/R_Band 추가 급여0 |
| M1_3·N0/N0A/N0T | 시험과 첫 주문 연결 | 배운 슬롯 회수0, 자기 직업 첫 주문150골드1회 |
| M1_4·H1/R1/N3·M2_3 | 등불·소포·분수, 소포 Requires는 M1_4 뒤로 | 기존 Pick·기본/선택 지급; 새 행동 의미가 맞지 않는 옛 플래그는 별도 대응표 |
| M2_4/5 ↔ N2/N1, 별도 N4 | Neutral 보급 경로 대체 | 동등 접수·실전 지급 슬롯, N4의 기존 Gold3/XP3 보존 |
| M2_1·S0/S4·Lunch1·Pet1 | 선택 지선 유지, 자동 등록 제거 | 수락·Claim·Done·Auto 설정·가방·펫 지급 원장 |
| M2_2/6/7·M3_1~4/6~8 | 진영별 행동 분기 | 옛 단계 번호를 새 번호로 그대로 복사하지 않음; 의미 StageKey로 이관 |
| TR15/25·4장·5장 | 신규 ID/의미 단계 추가 | 슬롯별 배움 원장, 공통 장 보상 키로 진영 변경 중복 지급 방지 |
| 기존 선택·지역·이벤트 의뢰 | 이 문서에서 재설계하지 않은 행은 현행 유지 | 기존 완료·선택·보상·펫 조건, 자동 수락 대신 NPC Offer/Guide 보완 |

### 이전 알고리즘 제안

1. 현재 `Data.Version=6`, `Story.Main={Id,St,P,T,Claim}`을 기준으로 원본 진행을 읽는다. 이 문서만 보고 버전을 올리지 않는다.
2. 호환 정의·별칭을 sanitize보다 먼저 등록한다. 옛 M1_2 Done을 삭제해 보상 재지급으로 이어지게 하지 않는다.
3. `Story.Schema/Variant/StageKey/WorldFlags/RewardLedger`는 새 필드 제안이다. 저장·클라이언트 sanitize·구버전 서버 동작을 함께 검토한다.
4. 새 단계는 의미로 대응한다. 완료한 사냥은 보존하되 새 호위를 자동 완료했다고 꾸미지 않는다. 이미 받은 장 급여는 다시 주지 않고 새 실물 장면은 보상 없이 볼 수 있다.
5. 수락·물건 소비·선택·급여를 계정 데이터 안에서 일관되게 처리한다. 고유 지급 키와 미완 지급 복구로 중복 지급과 지급 유실을 모두 시험한다.
6. N0계열은 직업이 바뀌어도 첫 주문 급여 한 번, N2/N1과 M2_4/5는 동등 슬롯 한 번, N4는 고유 기존 지급 한 번이다.
7. 진영 변경은 같은 의미 장면으로 이동하되 남의 고향에 물건을 배달하게 남기지 않는다. 환생은 완료·선택·펫 보존, 새 주선100% 조건 추가 없음.
8. 좌표 대신 NPC·물건 앵커를 저장한다. 장인 마을로 옮길 때는 Guide와 접수 위치만 이관하고 Done·Pick·의뢰품·급여는 유지한다.

## 12. 화면·마커·장면 규칙 체크리스트

- [ ] 모든 상세 행에 존재 근거 있는 부탁자, 짧은 영어 부탁, Accept/Decline, 단계별 Guide, 유형, 선택/실물 결과, 기존 단위 보상이 있다.
- [ ] `[몸 필요]` NPC와 새 물건 앵커가 없으면 의뢰를 열지 않는다. NPC가 없어서 거리 검사를 통과하는 우회가 없다.
- [ ] Guide 탭은 길 안내다. 원격 수락·납품·Learn을 대신하지 않는다. 새 장인 마을 좌표를 현재 목표로 쓰지 않는다.
- [ ] 설명 카드·상단 파란 띠·튜토리얼 토스트를 복원하지 않는다. 부탁·결과는 짧은 NPC 말풍선과 물체 반응으로 보인다.
- [ ] 연속 행 유형과 실제 입력을 함께 검사한다. 이름만 바꾼 사냥·Talk·Near3회는 다른 유형으로 인정하지 않는다.
- [ ] 팔찌·분수 같은 의도된 공유와 Lv5 시험·첫 기술 실전 같은 학습 공통을 빼면, 세 편이 같은 순서로 같은 대상을 누르지 않는다.
- [ ] 뿔 장난은 아이·동물·다른 플레이어에게 피해가 없다. 실패는 내 모자·리본·삑삑 소리로 돌아오며 다시 하기 쉽다.
- [ ] 선택 결과는 개인 상태로 저장한다. 내 전시 선택이 타인의 등불·서버 왕관전·실제 보상을 바꾸지 않는다.
- [ ] 성공 신호는 서버 확정 뒤에만 보인다. 아이템 부족·가득 찬 가방·재접속에도 의뢰품과 급여가 유실되지 않는다.
- [ ] 플레이어 대사는 훈계보다 NPC 반응이다. 둥근 빛·별·종이 조각만 사용하고 빛살 무늬는 쓰지 않는다.

## 13. 개발 순서 — 작은 완성본 단위, 첫30분부터

| 순서 | 만들 것 | 완료 확인 |
|---|---|---|
| 1 | NPC Offer/Decline·Guide·서버 상호작용·보상 원장 | 미수락·거리 밖·중복 요청 실패, 재접속 복구 |
| 2 | 첫 왕자·팔찌·도시락·Lv5 시험·등불 | 왕자1, 사냥4+도움1, 첫 스킬 전 사용 요구0, 세 편 첫10분 실측 |
| 3 | 2장 호위 / 선점·유인 / 포장·여과·주문 | 같은 소포·표본이라도 입력·목표·실패가 다름; 폰에서도 대상 구분 |
| 4 | Pip 몸·3장 세 편 숲 행동·Lv15 시험 | 공통 운반꾼/Brute 처치 체인 복사0, 개인 등불 저장 |
| 5 | 선택 의뢰·펫 연결·장인3직업 주문 | 기존 펫 조건·급여 보존, 조련사 펫 소유 필수 조건0 |
| 6 | Lv25 시험·폐허4장·Lv33~35 첫 결말 | 안전 고리에서 완주, 이벤트·상대 플레이어 없이 엔딩 |
| 7 | 1~5장 성장·이관·폰 최종 확인 | 실제 Lv35까지 동선·XP·반복 시간 기록; 부족분을 콘텐츠 완성으로 보고하지 않음 |

장인 마을 건설은 이 체인의 선행 조건이 아니다. 완공 뒤 §6·§8·§9 이전 열대로 접수·작업 앵커를 옮긴다. 6~7장 상세 제작은 §10의 측정 뒤 별도 결정한다.

### 검수할 실제 시나리오

| 범위 | 실제 확인 |
|---|---|
| 신규·성장 | 빛/뿔 전투3직업, 장인3직업; 보너스 없는 계정의 Lv5/10/15/25/35 시간과 XP 출처 |
| 분화 | 10분 이후 화면만 보고 진영을 구분 가능한지; 목표 이름을 가려도 행동이 다른지 |
| 의뢰 | 도시락 거절·늦은 수락, 사냥 전/후 수락, 호위 중 종료, 선점 실패·재시도, 재료0·골드0 |
| 저장 | M1_2 완료·미완, N0/N4 과거 지급, 구스킬 보유, Sub→Main 이관, 진영 변경·환생·장인 접수대 이전 |
| 월드 | NPC 생성 실패, 막힌 호위길, 타인 선점 충돌, 개인 물건 겹침, 안전 고리 경계, 폰 Guide |
| 엔딩 | 한 명 서버·행사 없음·왕관전 패배·중립 모두 Lv35 결말 가능; 전역 전쟁 종료 연출0 |

## 14. Claude가 먼저 비평할 쟁점

1. **범위:** 상세 행은 1~5장·선택 지선뿐이다. 약 Lv35 결말까지 실제 XP와 행동 분량이 충분한지 먼저 본다.
2. **행동:** 호위·선점·지휘·제작을 같은 상호작용1회로 구현하면 v2 취지가 사라진다. 입력·실패·실물 결과까지 비교한다.
3. **웃음:** 장난의 피해자가 아이·동물로 읽히는 장면, 플레이어에게 설교하는 반응은 교체한다. 종이 왕관 같은 반복 농담도 실제 플레이에서 빈도를 조절한다.
4. **구현량:** 새 NPC는 Pip·선택 Rex만 우선 필요하다. 새 행동 Event가 크면 퀘스트 수를 늘리기보다 한 장의 세 편을 먼저 끝낸다.
5. **장인:** 아직 없는 마을로 안내하는 줄이 없어야 한다. S/A/T 모두 실제 결과품이 쓰이는지, Craft 숙련 XP를 성장 XP로 오해하지 않았는지 본다.
6. **남은 판단:** 신규 행동·보상 계수·폐허 새 사건은 제안이다. 원래 왕관 파괴자·새 지역·후반 레벨 일정은 이 문서로 확정하지 않는다.

완료 기준은 세 편 모두 첫 부탁에서 폐허 첫 결말까지 이어지고, 플레이어가 “나는 무엇을 했고 무엇이 달라졌는지” 서로 다른 말로 설명할 수 있는가다.
