# Halo & Horns 퀘스트 바이블 v1

작성: Codex · 2026-10-15 · Claude 최종 검수용 초안. 이 파일만 작성했으며 코드·저장·Studio·SPEC는 바꾸지 않았다.

**목표: 같은 장소를 가더라도 빛은 누군가를 지키고, 뿔은 무언가를 차지하려다 마음이 흔들리고, 장인은 실제 주문을 완성하며 양쪽 주장의 틈을 발견한다.**
첫 왕자의 팔찌 → 아이들의 소포 → 분수의 가루 → 고블린의 등불 → 폐허의 옛 수리 기록 → 지금의 왕관전 → 내 마을의 결말로 이어진다.
아래 첫 30분은 채택된 문서를 기반으로 한다. 폐허 이후 사건·후반 레벨 배치·새 의뢰는 이번 제안이며, 확정 설정으로 취급하지 않는다.

## 1. 근거와 범위

| 근거 | 이번 문서에서 지킬 것 |
|---|---|
| `docs/GDD.md` §0·§1-1 | 모든 행동의 쓰임이 남을 돕는 쪽/내 몫을 챙기는 쪽으로 기운다. 부서진 왕관, 조각, 서로 상대를 탓하는 이야기 |
| `docs/SPEC_ADDENDUM.md` A23-150~199, 특히 152·162·188·191·193·194·197~199 | 베타 7구역, 대장간 먼저, 설명 UI 없음, 스승 시험, 펫 12종, 도시락 부탁, 수락/거절·전 단계 길 안내 |
| `docs/design/quests_first30_2026-10-15.md` | 왕자 1회, M1_2 통합, Lv5 슬라임 4, 등불 결말, 소포→연못→보급→숲. 30분은 실측 전 목표 |
| `docs/script/script_en_ko_2026-10-12.md` | Hallie/Magpie/Kit, Bright/Rose/Tiny/Pip 말투·팔찌·생일·그림 단서. 과거 토스트·줄다리기 설명은 재사용하지 않음 |
| `docs/design/quest_chain_2026-10-06.md`, `docs/design/town_npc_quests_2026-10-06.md` | 기존 이야기의 재료만 참고. 옛 일정·장인 제외·폐허 정식 전용·자동 수락·토스트 규칙은 폐기 |
| `src/ReplicatedStorage/Shared/Config.luau` | 실제 ID·보상·레벨·레시피·진영 제한의 기준. 아래 위치는 읽은 시점 기준 |
| `src/ServerScriptService/StoryQuestService.luau` | 현재 목표 판정·보상 단위·sanitize·저장 형식을 함께 확인. 새 행동이 이미 구현되었다고 가정하지 않음 |

| 확인한 현재 상태 | 설계에 미치는 영향 |
|---|---|
| `Config.Levels` 약 271행: MaxLevel=100. 별도 베타 상한은 이 표에 없음 | Lv25나 50을 베타 만렙이라고 쓰지 않는다. Lv100까지 후일담 포함 |
| `Config.Zones` 약 2155행: 초원 1, 숲 10, 폐허 25 | 새 지역을 레벨 사이에 끼워 넣지 않는다 |
| 숲은 PvP, 폐허는 바깥 안전·Crown Pit만 PvP | 주선 폐허 증거·주문은 안전 고리에서 끝낼 수 있게 한다 |
| 현재 Neutral의 집은 Crossroads. `ArtisanTown`은 이 표에 없음 | 장인 마을은 A23-152의 필수 추가 작업. 좌표를 지어내지 않는다 |
| `StoryQuests.Main` 약 3286행: M1~M3_8까지만 있음 | 세 진영 체인 선택과 M4 이후는 새 구현이다 |
| `Skills.Order={Q,Z,X}`, 해금 Lv5/15/25. ZEnabled/XEnabled는 현재 false | 문서의 1·2·3번 스킬은 내부 Q/Z/X. 실제 키 표시는 입력 설정을 사용. 꺼진 스킬 시험은 노출하지 않음 |
| `TownNpcs` 약 4486행: Bright, Gleam, Otto, Tiny, Rose 등 | Rose의 모델 Id는 Rose, 이야기/스승 키는 **Smokey**. 이를 함부로 바꾸지 않음 |
| Pip·Grabbo·Dibs·Rex는 Speakers에 있으나 이 NPC 목록의 실물과 같지 않음 | 부탁·납품 전에 몸/태그/정확한 자리를 만들어야 함. NPC가 없다고 원격 완료 금지 |
| `Goose.Mode="Eggs"`, Schedule.Every=14400 | 대본의 옛 10분 줄다리기를 새 주선에 넣지 않는다. 시험 주기와 본 서비스 주기를 구분 |
| `Data.Version=6`; 저장 Story.Main은 `{Id,St,P,T,Claim}` | 옛 문서의 `Story.M/St` 예시나 Version=2를 복사하지 않음 |

언어는 쉬운 영어 원문을 중앙 표에 쓴다. A23-179·185가 옛 영어 전용 해석보다 최신이다. 한국어는 최종 검수의 클라우드 현지화 경로로 반영하며 별도 한국어 모드를 새로 만들지 않는다.
이번 문서는 새 일정·유료 상품·새 점수 재화를 만들지 않는다. 장인 베타 포함은 A23-152·162가 옛 GDD의 제외 문구보다 우선한다.

## 2. 공통 이야기와 서로 다른 믿음

**확정된 출발:** 균형의 왕관이 부서졌다. 조각을 주운 사람들은 후광 또는 뿔을 얻었다. 기사단은 뿔의 욕심을, 뿔 군단은 기사의 독점을 원인으로 말한다. 장인은 조각의 쓰임과 수리 흔적을 본다.
**이번에 제안하는 베타의 답:** 두 편이 말하는 ‘상대만의 물건’에는 양쪽 흔적과 길드의 수리 자국이 함께 있다. 현재의 조각 과열은 한쪽이 독차지할 때 심해진다. 나눠 쓰거나 직접 책임지고 식히면 오늘의 문제는 해결된다.
**아직 답하지 않는 것:** 왕관을 처음 깨뜨린 정확한 인물·의도. Bright와 Rose가 친하다는 증거를 두 아이가 왕관을 깼다는 증거로 둔갑시키지 않는다. 새 흑막·해골왕·새 던전은 넣지 않는다.
베타 결말은 ‘현재의 큰 조각을 안전하게 두고 내가 어떤 사람인지 마을에 남기기’다. 왕관 전체 복원이나 영구 평화를 선언하지 않으므로 반복 왕관전과 모순되지 않는다.

| 장·레벨대 | Halo — Knights of Light | Horns — Horn Legion | Neutral — Artisan Guild |
|---|---|---|---|
| 서장·Lv1·고향 | Hallie: “우리가 길을 지켜야 해.” 약속과 무기 | Magpie: “남보다 먼저 챙겨!” 허세와 첫 심부름 | Kit: “두 편의 물건부터 고치자.” 주문과 도구 |
| 1장·Lv1~5·교차로/대장간→초원 | 오토의 부탁으로 위험 제거, 아이의 잃어버린 물건 회수 | 반짝이는 전리품 선점, 아이에게 큰소리쳤다가 약속 지키기 | 오토의 가루 표본 수거, 첫 제작품을 실제 주문자에게 납품 |
| 2장·Lv5~9·고향→교차로→초원 | 생일 소포를 적의 공작으로 오해. 사실을 보고할지 체면을 지킬지 | 축하 가루를 기사의 비밀 무기로 오해. 비밀을 지킬지 장난에 쓸지 | 같은 매듭·주문번호를 양쪽 장부에서 발견. 중재할지 소문으로 장사할지 |
| 3장 전반·Lv10~14·숲 | 도둑 소탕 중 아이 고블린의 등불을 발견. 규칙보다 사람을 볼지 | ‘우리 물건’ 회수 중 더 큰 욕심쟁이를 만남. 작은 녀석에게 나눌지 | 미납 재료 추적 중 생활용품 수요 발견. 전리품보다 필요한 물건 제작 |
| 3장 후반·Lv15~24·숲/고향 | 스승의 명령과 구조 현장이 어긋남. 용기와 독선 구별 | 대장 놀이와 동료 챙기기 사이. 자랑에도 책임이 따름 | 서로 반대 내용의 두 주문. 거짓말을 팔지, 고쳐서 납품할지 |
| 4장·Lv25~34·폐허 | 옛 기사단 기록에도 빠진 절반이 있음. 증거를 보존 | ‘우리가 빼앗았다’는 무용담도 과장. 훔칠 것은 전리품인가 이야기인가 | 양쪽 부품이 하나의 장치에 맞음. 길드도 불편한 기록을 숨겼음을 발견 |
| 5장·Lv35~49·폐허→교차로·1차 결말 | 큰 조각을 지키되 혼자 소유하는 것이 보호인지 선택 | 조각을 먼저 잡되 친구보다 중요한지 선택 | 모두가 쓸 수리품 또는 길드 전용품으로 마무리. 협동의 실체를 보여 줌 |
| 6장·Lv50~79·왕관전과 세 마을의 후일담 | 승리 기여와 상대 주민의 생활을 구별 | 경쟁은 계속하되 웃을 수 있는 장난의 선을 정함 | 왕관전 중립 보급·정비. 편에 점수를 주는 전투원이 되지 않음 |
| 종장·Lv80~100·폐허 기록→고향 | 자기 편의 누락을 인정하고 기록을 남기거나 영웅상을 독점 | 빈말인 전설을 고치거나 내 자랑으로 포장 | 양쪽 기록을 함께 공개하거나 원본을 길드 금고에 보관 |

**선악 적용:** 직업·진영과 선택은 별개다. Halo도 독선·독점을 고를 수 있고 Horns도 나눌 수 있다. 장인은 전쟁 중립이지 도덕적 무색무취가 아니다. 공용 수리/길드 독점, 사실 전달/소문 장사는 각각 빛/뿔 방향의 Pick을 남긴다. 장인에게 Honor·Mischief를 새로 주지 않는다.
전투·제작의 모든 클릭마다 점수를 찍지 않는다. ‘누구를 위해 무엇을 했는가’와 퀘스트의 최종 쓰임으로 기울기를 보여 준다. 순수 이동·수락·거절에는 선악 벌점이 없다.

## 3. 표 읽는 법과 공통 계약

표는 **위에서 아래가 주선 순서**다. Lv는 최소 레벨 제안이며 이전 행 완료도 필요하다. 같은 레벨의 여러 행은 순서대로 한다. `—`는 강제 선택 없이 다음 사건으로 연결한다는 뜻이다.
`M1_1[H]` 같은 표기는 설명용 진영 변형이다. 실제 저장 키는 기존 `M1_1`을 유지하고 별도 Variant를 둔다. H=Halo, R=Horns, N=Neutral. 신규 `H4_* / R4_* / N4_*` 등은 실제 새 ID 제안이다.
각 행의 부탁은 NPC에게 직접 상호작용했을 때만 나온다. **모든 행 앞에는 Offer→Accept/Decline이 있으며, 모든 완료는 명시된 NPC 또는 현장 상호작용에 연결된다.** 표에서 이 공통 단계를 반복해 길게 쓰지 않았다.
한 NPC가 이어 주는 작은 단계는 한 퀘스트 안에 둔다. NPC가 바뀌면 이전 완료의 말풍선으로 다음 부탁자를 알려 주고 그 NPC가 새로 제안한다. 레벨 도달만으로 자동 수락하지 않는다.

| 약어·목표 | 현재/추가 | 판정 |
|---|---|---|
| K=Kill, B=BasicKill, S=SkillHit | 현재 | 서버 몬스터/스킬 신호. S는 수동·실제 몬스터 적중만. 허공·자동 시전은 시험 횟수에 넣지 않음 |
| Enter, Near, Level, State, Talk, Choice, Trials | 현재 | Near는 위치·머문 시간만. 조사·줍기·수리·납품의 대용품이 아님 |
| Gather, Craft, SellMat | 현재 | 현재 Craft는 Role/Kind 필터 중심. 정확한 Recipe/주문품 인스턴스·납품 필터는 확장 필요 |
| I(x)=조사, P(x)=줍기, D(x→NPC)=납품 | **추가** | `Event` 목표에 서버 발행 신호를 연결. 거리·대상·소유자·순서·중복 요청 검증 |
| F(x)=수리/조립, E(x)=짧게 데려오기 | **추가** | 서버가 부품 사용·도착 확인. 이동 애니메이션만 끝나서는 완료하지 않음 |
| O(품목)=주문 제작 | **추가 결합** | 승인한 레시피로 Craft→결과품 묶기→D. 남의 제작이나 거래소 구매로 제작 시험 통과 불가 |
| WarPoints, WarChest, Goose | 현재 | 실제 서비스 결과만. WarPoints의 단위는 현재 kill units여서 표시 정수 점수와 구별 |
| W=왕관전 참여 확인 | **추가** | 수락 후 합법적인 기여 1회→해당 라운드 종료 신호. 승리/상자 지급을 조건으로 하지 않음 |
| Kaiju 관찰/지원 | **추가/기존 연결 확인** | 현재 엔진에 Type=Kaiju라고 적는 것만으로 작동하지 않음. 서비스 결과를 검증한 Event로 연결 |

| 보상 표기 | 의미 |
|---|---|
| G1 / GX2 | 기존 `Reward={Gold=1}` / `{Gold=2,XP=2}`. **1골드/2XP가 아니라 HuntValue 기준 사냥 분량** |
| 기존(id) | 해당 ID의 현재 기본·선택 보상 유지. 새 숫자를 추정해 쓰지 않음 |
| 신규G / 신규GX | 새 퀘스트의 골드 / 골드+캐릭터 XP 예산. v1은 기존 G1/GX2 계열을 상한 기준으로 실측 후 결정 |
| O급여 | NPC 주문 완료 보상(골드·캐릭터 XP), 기존 재료 원가·제작 XP와 구분. 새 화폐 없음 |
| 기록/연출 | 단서 저장·NPC/등불 변화. 새 전투 스탯 보너스 없음 |

기존 선택 보상은 별도다. 예: H1/R1/N3 기본은 GoldN=120·XPBar=0.5, 선 선택 Enh70×1, 장난 선택 HP×3+220골드다. 옛 마을 문서의 +60으로 되돌리지 않는다. 선택 보상의 Gold는 정액이며 2배 골드 패스 적용 경로도 일반 퀘스트와 다르다.
새 선택은 기본 `Points=0`으로 제안한다. 기존 S0=2, M2_3=2, M3_4=3 및 기존 마을 선택 값은 그대로 둔다. 진영에 반대되는 선택은 기존 A23-58 방식이며 장인은 Pick만 남긴다. 새 선택 수가 늘었다고 계급/주간 점수를 부풀리지 않는다.

### 첫 30분의 고정 장면

| 목표 시간 | 필수로 보일 사건 | 주의 |
|---|---|---|
| 0~1분 | 건너뛸 수 있는 기존 오프닝→진영/직업→안내자 부탁→오토 첫 무기·150골드 | 무기 수령 전에 추가 사냥 없음 |
| 1~5분 | 아이의 도시락 부탁→왕자 1회→팔찌/가루→T2·주문서 사용→도시락 귀환 | Lunch1 거절해도 주선은 진행. 다시 부탁받을 수 있음 |
| 5~10분 | Lv5 시험: 슬라임4 기본 공격→진영별 도움→스승 귀환→등불 결말 | 시험 때문에 초원 짧은 왕복 1회는 채택안의 의도적 예외 |
| 10~15분 | H1/R1/N3 중 하나의 소포 반전→연못 표본→분수 선택 | 소포가 M2_3 이전에 오므로 기존 Requires 변경 필요 |
| 15~20분 | 보급 상자→첫 스킬 2마리 동시 적중1회→발자국→Lv10 숲 | 장인은 자기 제작품을 운반. N1/N2/N4와 보급 단계 중복 방지 |
| 20~30분 | 특정 운반 고블린→야영지 생활 흔적→우두머리→Pip의 등불 | 교전 앞뒤의 이유와 결과가 실제 물건으로 보임 |

이는 속도 약속이 아니다. 현재 XPToNext 합은 Lv5=157, Lv10=962, Lv15=4,859, Lv25=24,164, Lv50=143,049, Lv100=776,420이다(새 Lv1 기준, 보너스 전). 왕자·슬라임 몇 마리만으로 Lv5를 보장할 수 없다.
**출시 조건:** 필수 동선의 처치·완료 XP와 실제 적용되는 첫 10분 배율을 계산해 Lv5/10 부족분을 먼저 측정한다. 부족하면 이미 끝낸 사건의 XP 배분을 검수하고, 채택안에 없는 반복 사냥을 몰래 끼우지 않는다. 장인의 Craft XP는 제작 숙련도이므로 캐릭터 레벨 XP로 오해하지 않는다.

## 4. Halo 전체 주선 — 보호하는 사람이 판단까지 독점할 때

| 순서·ID·Lv | 부탁자·짧은 영어 초안 | 단계·목적지 | 선택→보이는 결과·반전 | 보상 |
|---|---|---|---|---|
| H00 Tutorial ·1 | Hallie: “Please help keep our road safe.” | Talk→Enter 교차로→오토 무기 수령 | —; 지킬 길과 무기가 먼저 생김 | 무료 T1·150골드 |
| H01 M1_1[H] ·1 | Otto: “Please free the shiny thing in that slime.” | K BigSlime1→I 가루/팔찌→T2 장착→Event ScrollUsed | —; 적의 물건 같은 팔찌에 금·보라 매듭 | 기존 M1_1+미지급 M1_2, 첫 드롭 |
| H02 M1_3[H] ·5 | Gleam: “Clear the path. Then help our neighbor.” | B Slime4→P 주민 짐→D Folk1→Talk Gleam | 도움을 마치고 배우며 스승이 직접 시범 | 첫 스킬·기존 M1_3 |
| H03 M1_4[H] ·5 | Hallie: “Can your dust light this lamp?” | D 가루→Choice→I 팔찌를 Bright에게 | 공용 등불/내 표식: 등불 점등/후광에 빛. Bright가 손목 숨김 | GX2·기록 |
| H04 H1 ·5 | Bright: “Please check that Horns parcel.” | I 다리 소포→P 생일 메모→D Bright | 사실 알리기/소문 유지: 주민이 간식 나눔/소포를 경계. 적의 작전이 생일 선물 | 기존 H1 |
| H05 M2_2[H] ·5 | Bright: “Please find what washed into the pond.” | I SlimePond 흔적→K Slime2→P 표본 | —; 가루가 소포와 같은 빛으로 반응 | G1 |
| H06 M2_3[H] ·5 | Fountain: “Will you bring that dust to me?” | D 표본→Choice 분수/보관 | 분수 점등/내 표식 여운. Bright·Rose가 마주 보고 갈라짐 | G1·기존 선택2 |
| H07 M2_4[H] ·6 | Tiny: “Please take supplies to the woods gate.” | P 구호 상자→운반→중간 표식 I | —; 아이들이 기다리는 실물이 보여 보호 목적 구체화 | G1 |
| H08 M2_5[H] ·6 | Tiny: “Please clear a path for the box.” | S Q로 몬스터2 동시 적중1→D 숲 입구 Pip | —; 상자를 내려놓자 길목 등불 하나 켜짐 | G1 |
| H09 M2_6[H] ·7 | Pip: “Please follow the dragged sack.” | I 발자국2→P 걸린 자루 천 | —; 무턱대고 도둑을 쫓기 전에 방향 확인 | G1 |
| H10 M2_7[H] ·10 | Hallie: “Please bring the missing dust home.” | Level10→D 의뢰 봉인→Enter GoblinWoods | —; 길목 경비가 길을 가리킴. 기존 위험 아이콘 유지 | GX2·가방+4 |
| H11 M3_1[H] ·10 | Pip: “That carrier took our lamp dust. Help?” | K 표시된 Goblin 운반꾼1→P 쪽지 | —; ‘갚을게. 아마도.’ 도둑에게도 사정이 있음 | G1 |
| H12 M3_2[H] ·10 | Pip: “Please look before you take it all.” | I 가루 병→I 어린 고블린 그림→I 빈 등불 | —; 훔친 가루는 무기만이 아닌 야간등 재료 | G1 |
| H13 M3_3[H] ·10 | Pip: “Please get our sack from the Brute.” | K GoblinBrute1→P 자루/그림 | —; 분수에서 두 아이가 함께 있던 그림 발견 | G1 |
| H14 M3_4[H] ·10 | Hallie/Pip: “May we keep a little for our lamps?” | D 고향 문 앞→Choice 일부 나눔/모두 보관 | Pip 등불 점등/내 금고 반짝임. 지킨다는 명분도 독점이 될 수 있음 | GX2·기존 선택3/분기 보상 |
| H15 TR15_H ·15 | Gleam: “Guard the road without forgetting its people.” | §7의 사냥 시험→구호 짐 전달→스승 귀환 | 주민 우선/내 공로 표식: 주민 손인사/내 표식에 리본 | 2번 스킬 |
| H16 M3_6[H] ·18 | Bright: “Please recover the cart's axle.” | K 자루 지닌 GoblinBrute1→P 축→D Pip | —; 빼앗긴 건 군수품이 아닌 공동 수레 부품 | G1 |
| H17 M3_7[H] ·21 | Pip: “Please help us move the lamp cart.” | F 축 끼우기→E 수레 짧은 구간→I 옛 도장 | —; 폐허 기사단 도장이 뿔 표식과 겹침 | G1 |
| H18 M3_8[H] ·25 | Gleam: “Please check the old guard records.” | Level25→Enter 폐허 안전 고리→D 조사 의뢰 | —; ‘적의 도장’이 우리 기록에도 있음 | GX2 |
| H19 TR25_H ·25 | Gleam: “Test your strength. Then make room for others.” | §7 사냥→폐허 입구 짐 정리→귀환 | 먼저 길 열기/내 깃발 먼저: 통로 등불/개인 깃발 | 3번 스킬 |
| H20 H4_1 ·25 | Bright: “Please recover the fallen guard's badge.” | K Skeleton2→P 경비 표장→D Bright의 현장 파견점 | —; 옛 경비 표장에 양 진영 색 | 신규G |
| H21 H4_2 ·27 | Tiny: “Please match these broken records.” | I 아치 기록2→F 문양 맞춤1 | —; 기사의 책에서 지워진 절반은 공동 수리 약속 | 신규G·단서 |
| H22 H4_3 ·30 | Gleam: “Please stop the knight blocking the way.” | K SkeletonKnight1→P 기록함 열쇠 | —; 옛 기사는 특정 진영보다 조각 보관함을 지켰음 | 신규G |
| H23 H4_4 ·32 | Bright: “Please bring both pages back.” | I 안전 고리 기록함→D 두 장 | 둘 다 전시/우리 장만 앞에: 개인 전시대 양면/단면. 누락을 내 손으로 재현할 수 있음 | 신규GX |
| H24 H5_1 ·35 | Fountain: “Please help me cool this shard.” | I 큰 조각→F 냉각 고리3개 순서 조절 | —; 한쪽 고리만 켜면 과열, 모두 연결하면 안정 | 신규G |
| H25 H5_2 ·38 | Pip: “Please keep the lamp road open.” | E Pip 짧은 구간→K 막는 Skeleton2→D 조각 받침 | —; 도와준 고블린이 이번에는 운반을 도움 | 신규G |
| H26 H5_3 ·40 | Hallie: “Where should we guard the shard?” | Choice 공용 분수/성채 보관→D 지정 받침 | 공용 점등/성채 개인 진열과 별도 냉각. 둘 다 안정되지만 이웃의 접근이 다름 | 신규GX·1차 결말 |
| H27 H6_1 ·50 | Bright: “Please help our side in one Crown War.” | W: 몬스터 기여1→그 라운드 종료→Talk Bright | —; 승패와 무관하게 누구를 지키려 싸웠는지 회수 | 신규G, 전쟁 보상은 별도 |
| H28 H6_2 ·60 | Tiny: “Please take this parcel across the plaza.” | P 상대편 아이의 짐→D 교차로 Rose | 조용히 도움/내 깃발 포장: 아이 웃음/과한 깃발에 머쓱한 반응 | 신규G |
| H29 H6_3 ·70 | Gleam: “Please check our old lamp road.” | I M1_4 등불→F 느슨한 받침→D Pip에게 교체품 | —; 내 초기 선택을 NPC가 기억. 어두웠으면 지금 고칠 기회 | 신규GX |
| H30 H7_1 ·80 | Bright: “Please help me finish the true record.” | I 폐허 인장→D Bright→F 두 기록 나란히 전시 | 사실 공유/내 공로 제목: 전시 내용은 보존, 표지 주인공만 다름 | 신규G |
| H31 H7_2 ·90 | Hallie: “Please choose what our new guards inherit.” | P 등불/표식 중 선택→D 새 경비 NPC | 공용 길 등불/내 전시대: 다음 주민 동선·인사가 달라짐 | 신규GX |
| H32 H7_3 ·100 | Gleam: “Will you show us what a guardian leaves?” | I 지난 선택 전시3→Choice 공동 길/내 기념대→F 마무리 | 나눔의 길/영웅 기념대. 둘 다 완료, 조각 안정·서로 다른 고향 장면 | 기록·새 무능력치 칭호 제안 |

## 5. Horns 전체 주선 — 제일 멋진 대장이 작은 친구를 챙길 때

| 순서·ID·Lv | 부탁자·짧은 영어 초안 | 단계·목적지 | 선택→보이는 결과·반전 | 보상 |
|---|---|---|---|---|
| R00 Tutorial ·1 | Magpie: “Get a tool. Bring back something shiny!” | Talk→Enter 교차로→오토 첫 무기 | —; 남보다 먼저 챙길 도구부터 준비 | 무료 T1·150골드 |
| R01 M1_1[R] ·1 | Otto: “Get that shiny thing out for me, please.” | K BigSlime1→P 팔찌/가루→T2 장착→ScrollUsed | —; 자랑할 전리품에 남의 매듭. 오토의 의뢰품임을 분명히 함 | 기존 M1_1+미지급 M1_2, 첫 드롭 |
| R02 M1_3[R] ·5 | Rose: “Clear four slimes. Deliver my surprise!” | B Slime4→P 장난 소포→D Tiny→Talk Rose | —; 열면 간식. 골탕 먹이는 줄 알았는데 Tiny도 웃음 | 첫 스킬·기존 M1_3 |
| R03 M1_4[R] ·5 | Magpie: “Can that dust make our den shine?” | D 가루→Choice 공용 등불/내 뿔→I Rose의 팔찌 | 등불/뿔 여운. Rose가 손목을 숨겨 내 전리품의 주인이 수상해짐 | GX2·기록 |
| R04 R1 ·5 | Rose: “Please check what the Halos are hiding.” | I 분수 소포→P 축하 메모→D Rose | 사실 알리기/소문으로 장난: 함께 웃음/경계 자세. 기사의 비밀무기는 축하 준비 | 기존 R1 |
| R05 M2_2[R] ·5 | Rose: “Fetch that sparkle before Bright does!” | I 연못 반짝임→K Slime2→P 표본 | —; 내 것이라 우겼던 가루가 생일 소포와 연결 | G1 |
| R06 M2_3[R] ·5 | Fountain: “Will you share that sparkle with me?” | D 표본→Choice 분수/보관 | 분수 점등/내 뿔 여운. Rose와 Bright가 서로 손 흔들다 모른 척 | G1·기존 선택2 |
| R07 M2_4[R] ·6 | Tiny: “Can the fastest rascal deliver this?” | P 간식 상자→운반→I 길목 표식 | —; 최고라는 말에 맡았지만 받는 사람은 작은 고블린 | G1 |
| R08 M2_5[R] ·6 | Tiny: “Show those slimes who's boss!” | S Q로 몬스터2 동시 적중1→D Pip | —; 첫 기술 자랑이 누군가의 배달을 완성 | G1 |
| R09 M2_6[R] ·7 | Pip: “Someone took the big sack. Find it?” | I 끌린 자국→P 천 조각→D Rose의 전달함 | —; 내 보급품까지 가져간 큰 녀석을 찾아야 함 | G1 |
| R10 M2_7[R] ·10 | Magpie: “Please bring our missing delivery back.” | Level10→P 빈 회수 자루→Enter 숲 | —; ‘되찾기’와 ‘더 챙기기’가 섞인 명령 | GX2·가방+4 |
| R11 M3_1[R] ·10 | Grabbo: “Catch my runner. He took the list!” | K 표시 Goblin1→P 차용 쪽지 | —; Grab Club도 자기 물건을 잃으면 화냄 | G1 |
| R12 M3_2[R] ·10 | Pip: “Look. We only wanted night-lights.” | I 가루 병→I 그림→I 빈 등불 | —; ‘우리보다 작은 도둑’의 잠자리라는 발견 | G1 |
| R13 M3_3[R] ·10 | Grabbo: “Please show that Brute who's boss!” | K GoblinBrute1→P 자루/그림 | —; 보스 흉내 내던 우두머리도 두 아이 그림은 소중히 보관 | G1 |
| R14 M3_4[R] ·10 | Pip: “Boss... may we have a little?” | D 고향 문 앞→Choice 나눔/내 자루 | Pip 등불/내 전리품 진열. 나눠도 Rose는 놀리며 미소 | GX2·기존 선택3/분기 보상 |
| R15 TR15_R ·15 | Rose: “Win the scrap. Then fix our prank.” | §7 사냥→장난 때문에 엉킨 짐 정리→귀환 | 사과 간식/내 깃발: 주민 웃음/눈 굴리며 웃음 | 2번 스킬 |
| R16 M3_6[R] ·18 | Dibs: “Get my noisy bell back, please!” | K GoblinBrute1→P 방울→D Dibs | —; 겁주기용인 줄 알았는데 야간 길잡이 방울 | G1 |
| R17 M3_7[R] ·21 | Rose: “Set our decoy. Get the real sack!” | F 빈 자루 미끼→E 짧은 이동→P 옛 문양 천 | —; 남을 속이는 솜씨로 뺏긴 생활품을 회수 | G1 |
| R18 M3_8[R] ·25 | Magpie: “Please find where our legend began.” | Level25→Enter 폐허 안전 고리→I 두 표식 | —; 뿔의 전리품 전설에 빛의 수리 표시 | GX2 |
| R19 TR25_R ·25 | Rose: “Make some noise. Then clean it up!” | §7 사냥→망가진 길목 종 수리→귀환 | 작은 안내종/내 응원종: 다른 소리·NPC 반응 | 3번 스킬 |
| R20 R4_1 ·25 | Dibs: “Please recover our famous trophy tag.” | F 삑삑 미끼→해골이 돌아보는 동안 P 꼬리표→D Dibs | —; 힘으로 정면 돌파하는 빛과 달리 장난으로 회수. 뒷면에는 ‘빌린 물건’ 도장 | 신규G |
| R21 R4_2 ·27 | Rose: “Please bring our little scout back.” | F 엉킨 상자 잠금→E 기존 아기 슬라임→떨어진 기록 P | —; 조그만 정찰대장을 꺼내 주자 물고 있던 반쪽 기록을 줌. 뿔의 전설도 절반을 잘랐음 | 신규G |
| R22 R4_3 ·30 | Magpie: “Get past that knight. Bring the key!” | K SkeletonKnight1→P 보관함 열쇠 | —; 진짜 전리품 대신 수리 영수증 | 신규G |
| R23 R4_4 ·32 | Rose: “Please help me tell this properly.” | D 기록→Choice 사실 자랑/내 공로로 포장 | 두 사람 같이 포즈/나만 앞에서 포즈. ‘잘 훔친 이야기’도 선택 | 신규GX |
| R24 R5_1 ·35 | Fountain: “Please stop that shard from overheating.” | I 큰 조각→F 고리3 순서 조절 | —; 힘을 독차지하려니 내 손에도 뜨거움 | 신규G |
| R25 R5_2 ·38 | Pip: “Boss, can you carry the heavy end?” | P 빈 자루→F 삑삑 미끼→E 옆길 운반→D 받침 | —; 빛은 정면을 열고 뿔은 장난으로 옆길을 만듦. 대장 자랑이 진짜 도움이 됨 | 신규G |
| R26 R5_3 ·40 | Magpie: “Where will you put your big prize?” | Choice 공용 분수/소굴 전리품대→D 조각 | 모두의 둥근 빛/개인 진열대와 냉각. 친구의 접근이 다름 | 신규GX·1차 결말 |
| R27 R6_1 ·50 | Rose: “Help our side make a splash this round!” | W: 몬스터 기여1→라운드 종료→Talk Rose | —; 지든 이기든 의뢰 완료. 괴롭힘·상대 KO 요구 없음 | 신규G |
| R28 R6_2 ·60 | Tiny: “Please return the shield from your prank.” | P 장식 방패→D 교차로 Bright | 몰래 반환/우스운 포장: 안도/웃으며 한숨. 플레이어 장비는 훔치지 않음 | 신규G |
| R29 R6_3 ·70 | Rose: “Please check on our little lamp friends.” | I Pip 등불→F 흔들린 받침→D 간식 | —; 독점했던 사람도 지금 돌볼 수 있음. 옛 Pick은 보존 | 신규GX |
| R30 R7_1 ·80 | Dibs: “Please catch the fake trophy seller.” | F 가짜 반짝 상자→Dibs가 가져오게 유도→P 원래 수리 서명판 | 모두 이름/내 이름 크게: 서명 배치와 주민 포즈 차이. 수상한 장사꾼은 부탁한 Dibs 본인이었음 | 신규G |
| R31 R7_2 ·90 | Magpie: “Please plan our biggest welcome.” | P 간식·깃발→D 소굴 문 | 모두 초대/내 단짝석: NPC 자리·잔치 모양이 달라짐 | 신규GX |
| R32 R7_3 ·100 | Rose: “What should the next rascals remember?” | I 지난 선택 전시3→Choice 공동 놀이터/내 무대→F 마무리 | 같이 노는 대장/스스로 빛나는 대장. 잔혹한 결말 없음 | 기록·새 무능력치 칭호 제안 |

## 6. Artisan 전체 주선 — 주문을 완성할수록 양쪽의 거짓말이 보인다

장인의 전투는 재료·길 확보를 위한 짧은 구간이다. 사냥 점수를 문구만 ‘납품’으로 바꾸지 않는다. **직업마다 실제 제작 결과와 받는 사람이 있어야 한다.**
S=대장장이(Smith, 저장 Class Warrior), A=연금술사(Alch, Class Mage), T=조련사(Tame, Class Archer). 아래 직업별 물건은 NPC 의뢰품이며 새 유료 재화가 아니다.
현재 첫 레시피는 S: W2(Herb3·CopperOre2·40골드), A: AP1(Herb3·10골드, HP2), T: T1(Herb3·10골드, 간식3). 제작 숙련 Lv와 캐릭터 Lv를 구분한다.

| 순서·ID·Lv | 부탁자·짧은 영어 초안 | 단계·목적지 | 선택→보이는 결과·반전 | 보상 |
|---|---|---|---|---|
| N00 Tutorial ·1 | Kit: “Please take our first order to Otto.” | Talk 장인 집→교차로 오토→첫 도구 수령 | —; 의뢰 장부가 비어 있다가 첫 주문 그림이 들어감 | 무료 T1·150골드 |
| N01 M1_1[N] ·1 | Otto: “Please bring me a clean dust sample.” | K BigSlime1→I 표본/팔찌→T2 장착→ScrollUsed | —; 재료 검사 중 두 편의 매듭 발견 | 기존 M1_1+미지급 M1_2, 첫 드롭 |
| N02 N0/N0A/N0T 준비 ·1 | Kit: “Please gather what this order needs.” | S Gather Herb3·CopperOre2 / A·T Gather Herb3→주문 재료 보관 | —; 사냥 대신 재료 위치를 직접 보고 작업 준비 | 보상은 아래 납품 때 1회 |
| N03 M1_3[N]+N0 완료 ·5 | Otto: “Clear four slimes. Then finish our order.” | B Slime4→S W2 제작 후 내 도구 장착·NPC 부품 F / A AP1 제작·HP1 D / T T1 제작·간식1 D→Otto | 각 주문자: 수레 다시 움직임/주민이 병 받음/아기 슬라임이 간식에 접근. W2를 뺏어 초보 무기를 없애지 않음 | 첫 스킬·기존 M1_3·직업 N0의150골드 |
| N04 M1_4[N] ·5 | Kit: “Can you fix our shared lamp?” | I 고장 등불→Choice F 공용 수리/작업대 보관→D 팔찌 Tiny | 공용 등불/길드 작업등. Tiny가 Bright를 가리킴 | GX2·기록 |
| N05 N3 ·5 | Tiny: “Please check these two matching parcels.” | I 두 다리의 소포→D 주문표 대조 | 화해 편지/소문 장사: 두 아이가 함께 간식/망원경 든 주민. 장부는 중립도 이익을 챙겼다고 말함 | 기존 N3 |
| N06 M2_2[N] ·5 | Otto: “Please collect the dust by the pond.” | I 흔적→K Slime2→P 표본 | —; 가루의 성질이 양쪽 주문에서 같음 | G1 |
| N07 M2_3[N] ·5 | Fountain: “Can you fit that piece here?” | F 표본 받침→Choice 공용 분수/길드 보관 | 분수 점등/작업 도구 여운. 두 아이가 반대편으로 달아남 | G1·기존 Pick |
| N08 N2 ·6 | Tiny: “Please prepare an order for the woods.” | 주문 수락→S 부품/A 구호병/T 간식 꾸러미의 재료 P·Gather→O | —; 고객이 Pip임을 알게 됨. 왕자3·사냥골드60 삭제 | 기존 N2, 보급 접수 슬롯 |
| N09 N1 ·6 | Otto: “Please clear the road for your delivery.” | 상자 운반→S Q로 몬스터2 동시 적중1 | —; 제작자도 자기 배달길은 열 수 있음 | 기존 N1, 실전 슬롯 |
| N10 N4 ·6 | Pip: “Is that the order I asked for?” | D 묶인 주문품→F 부품/A 병 전달/T 간식 사용 확인 | —; 수레/구호 자리/아기 슬라임의 반응. 단순 마을 입장은 납품이 아님 | 기존 N4, 납품 슬롯 |
| N11 M2_6[N] ·7 | Pip: “Please trace our missing supply sack.” | I 바닥 자국→P 천→D Tiny의 현장 장부 | —; 내가 만든 물건의 다음 재료가 사라짐 | G1 |
| N12 M2_7[N] ·10 | Kit: “Please check the late order in the woods.” | Level10→Enter 숲→P 미납 주문표 | —; 중립 주문의 고객은 고블린도 포함 | GX2·가방+4 |
| N13 M3_1[N] ·10 | Pip: “Please recover the carrier's receipt.” | K 표시 Goblin1→P 영수증 | —; 돈만 받으러 왔다가 등불 재료 누락 발견 | G1 |
| N14 M3_2[N] ·10 | Pip: “Please see what our homes need.” | I 가루 병→I 아이 그림→I 빈 등불 | —; 필요한 것은 무기보다 생활 수리품 | G1 |
| N15 M3_3[N] ·10 | Pip: “Please get the order back from the Brute.” | K GoblinBrute1→P 주문 자루/그림 | —; 두 아이 그림과 길드의 납품 봉인이 같이 있음 | G1 |
| N16 M3_4[N] ·10 | Kit/Pip: “Can you make a lamp with our share?” | D 장인 집 문 앞→Choice 공용 등불 F/가루 되팔기 | Pip 등불/길드 상자. 중립도 남의 곤란으로 이익을 낼 수 있음 | GX2·기존 A/B 보상 |
| N17 TR15_N ·15 | Otto: “Show safe hands. Then help a customer.” | §7 사냥→직업 수리/구호/조련 주문→귀환 | 무료 추가 손질/내 작업 표식: 사용 장면/도구 표식 | 2번 스킬 |
| N18 M3_6[N] ·18 | Tiny: “Please recover the borrowed tool case.” | I 숲 작업 자리→P 도구함→D Pip | —; S 축 맞춤/A 새는 병 봉합/T 운반 끈 맞춤. 큰 적2 사냥을 그대로 복사하지 않음 | G1 |
| N19 M3_7[N] ·21 | Kit: “Please finish both sides' repair orders.” | O 직업 주문1→D 교차로 두 수령함에 분배 | —; 똑같은 부품을 양쪽이 ‘우리만의 비밀’이라 주문 | G1 |
| N20 M3_8[N] ·25 | Otto: “Please check the old maker's marks.” | Level25→Enter 폐허 안전 고리→I 수리 도장 | —; 길드의 옛 기록도 일부 빠져 있음 | GX2 |
| N21 TR25_N ·25 | Otto: “Clear the worksite. Then repair what matters.” | §7 사냥→S 난간/A 냉각병/T 안내 간식→귀환 | 공용 수리/길드 작업대 우선: 서로 다른 작업물 점등 | 3번 스킬 |
| N22 N4_1 ·25 | Tiny: “Please find the parts on this old receipt.” | I 폐허 부품2→P 부품함→D Otto | —; 한 장치의 부품을 서로 다른 진영 이름으로 팔았음 | O급여 |
| N23 N4_2 ·27 | Otto: “Please test how these pieces fit.” | S F 받침 / A F 시약 반응 / T E 아기 슬라임의 냄새 추적 | —; 양쪽 부품이 맞물린다. 외형 없는 새 펫을 강제로 소환하지 않음 | 신규G·단서 |
| N24 N4_3 ·30 | Kit: “Please recover the sealed tool key.” | K SkeletonKnight1→P 열쇠→I 보관함 | —; 길드가 고친 흔적을 숨겼던 장부 발견 | 신규G |
| N25 N4_4 ·32 | Tiny: “Please help me show the complete order.” | F 장부 조각2→Choice 공개/길드 보관→D | 공용 양면 전시/길드 금고. 장인도 진실의 소유권을 시험받음 | 신규GX |
| N26 N5_1 ·35 | Fountain: “Please build a safe cradle for me.” | O S 받침/A 냉각병/T 운반 간식→F 고리3 | —; 직업별 기여가 같은 큰 조각을 안정시킴 | O급여 |
| N27 N5_2 ·38 | Pip: “Please help me bring it safely.” | E 운반→F 중간 받침→D 교차로 | —; 전투 대신 내 제작품이 운반 문제를 해결 | 신규G |
| N28 N5_3 ·40 | Kit: “Who should use our finished work?” | Choice 공용 분수/길드 작업대→F 조각 설치 | 공용 빛/길드 전용 작업등. 수리는 끝나고 접근 범위가 다름 | 신규GX·1차 결말 |
| N29 N6_1 ·50 | Tiny: “Please finish these Crown War supplies.” | O 직업 보급1→D 교차로 수령대2 | —; 왕관전 승패·시작을 기다리지 않는 중립 의뢰. 점수/축복 없음 | O급여 |
| N30 N6_2 ·60 | Otto: “Please repair both sides' returned gear.” | I 파손품→F S 부품/A 병/T 운반 끈→D | 먼저 필요한 편/길드 전시 먼저: 수령 NPC 순서·전시가 달라짐 | O급여 |
| N31 N6_3 ·70 | Pip: “Please check the lamp you left us.” | I 옛 등불→F 손질→D 간식/부품 | —; 가루를 팔았어도 이번 주문으로 관계를 바꿀 수 있음 | 신규GX |
| N32 N7_1 ·80 | Tiny: “Please put both stories on one page.” | I 폐허 도장→F 두 원본 대조→D 공개 기록대 | 원본 공유/사본만 공개: 열려 있는 원본/잠긴 원본함 | 신규G |
| N33 N7_2 ·90 | Kit: “Please prepare a bench for our next maker.” | O S 작업 받침/A 병 거치대/T 간식 자리→D 길드 집 | 공용 작업대/내 서명 전시: 다음 견습 NPC의 자리 변화 | O급여 |
| N34 N7_3 ·100 | Otto: “What will your best work be for?” | I 지난 납품 결과3→Choice 함께 쓰기/내 작업실→F 완성 | 함께 켜진 작업등/개인 명작 전시. 중립의 도덕적 선택으로 닫음 | 기록·새 무능력치 칭호 제안 |

**장인 주문의 구현 한계:** 위의 의뢰 부품은 상점 레시피에 있다고 주장하지 않는다. 첫30분은 W2/AP1/T1과 무료 의뢰용 부품 상호작용을 조합한다. 이후 수리품은 별도 퀘스트 전용 레시피/작업 Event로 만든다. 전투 장비 성능이나 거래 상품 목록을 몰래 추가하지 않는다.
NPC가 맡긴 재료와 퀘스트 결과품은 판매·거래·해체 불가, 일반 가방을 막지 않는 주문 보관함에 귀속한다. 개인 재료를 쓰는 반복 주문은 수락 전에 실제 비용을 보여 준다. 최초 필수 주문은 돈을 다 써도 막히지 않게 의뢰 재료로 재시도 가능해야 한다.
N2/N1/N4는 Neutral에서 M2_4/M2_5 역할을 대신한다. `MainByFaction`에서 중복 등록하지 않으며, 지급 예산은 §11의 동등 보상 슬롯으로 관리한다. N0b는 여분이 있을 때만 받는 선택 판매 의뢰다.

## 7. 스승 시험 — Lv5·15·25, 진영별 9개

사냥→생활 도움 두 단계와 스승 귀환이 기본이다. 새 스킬을 배우기 전 그 새 슬롯의 사용을 요구하지 않는다. 기존 `Skills.Tasks`는 시험의 사냥 목표로 합치며 별도 40/20/30/50회 숨은 요구를 남기지 않는다. 수량 조정은 본 초안의 제안이다.

| ID·진영·레벨·스승 | 사냥 단계 | 도움 단계·선택의 실물 | 한 줄·배움 |
|---|---|---|---|
| M1_3[H]·5·Gleam | B Slime4, 초원 입구 | Folk1 짐 P→바로 옆 주민 D | “Strong hands. A kind heart.” → Q |
| M1_3[R]·5·Rose(Smokey) | B Slime4, 초원 입구 | 장난 소포 P→Tiny D→간식 펼침 | “Good prank. Happy friends.” → Q |
| M1_3[N]·5·Otto | B Slime4, 초원 입구 | N0계열 실제 제작→주문자 도움, §6대로 | “Make it. Then make it useful.” → Q |
| TR15_H·15·Gleam | 아래 직업 패턴, 숲 입구 | 구호 상자 P→Pip D, 주민 우선/내 공로 리본 | “A guard notices who needs help.” → Z |
| TR15_R·15·Rose | 아래 직업 패턴, 숲 입구 | 장난으로 꼬인 배송끈 F→Tiny D, 사과 간식/내 깃발 | “A boss fixes the mess too.” → Z |
| TR15_N·15·Otto | 아래 직업 패턴, 숲 입구 | S 수레 축 F / A AP1→병 D / T T1→간식 D. 추가 손질/작업 표식 | “Good work reaches its owner.” → Z |
| TR25_H·25·Gleam | 아래 직업 패턴, 폐허 안전 고리 | 길목 짐 P→통행 자리 D, 통로 먼저/내 깃발 먼저 | “Leave a safe path behind.” → X |
| TR25_R·25·Rose | 아래 직업 패턴, 폐허 안전 고리 | 길목 종 부품 P→F, 안내종/내 응원종 | “Loud is fine. Broken isn't.” → X |
| TR25_N·25·Otto | 아래 직업 패턴, 폐허 안전 고리 | S 난간 F / A 냉각병 F / T 안내 간식 D. 공용 수리/길드 우선 | “A master fixes the next problem.” → X |

| 직업 묶음 | Lv15 사냥 시험안 | Lv25 사냥 시험안 |
|---|---|---|
| Warrior / Blacksmith | BasicKill Goblin4 | 이미 배운 Z로 Skeleton2 동시 적중2회 |
| Mage / Alchemist | Q로 Goblin2 동시 적중2회 | 이미 배운 Z로 Skeleton2 동시 적중2회 |
| Archer / Tamer | FarKills Goblin4, 서버 거리20 | FarKills Skeleton4, 서버 거리25 |

FarKills는 기존 Skills.Tasks 측정기를 재사용하되 이야기 시험 세션에 묶는 연결 작업이 필요하다. 조련사 거리는 조련사 캐릭터 기준으로 통일해 펫이 멀리 갔다고 악용되지 않게 한다. 정확한 기존 거리 판정은 구현 전 개발2가 대조한다.
도움 선택은 Lv15/25 모두 Points=0, 보상·스킬은 동일하다. 표시된 결과만 달라진다. 시험 실패는 완료한 도움/사냥을 지우지 않는다. 스승과 멀리 떨어져 원격 Learn 호출하면 지급하지 않는다.
스킬 기능이 꺼져 있으면 시험을 자동 등록하지 않는다. Lv25 주선 입장에는 3번 스킬을 강제하지 않고 기존 기술로 통과 가능하게 만든다. 기능을 켰을 때 해당 시험을 별도 수락할 수 있다. 옛 저장의 배운 스킬은 회수하지 않는다.

## 8. 마을별 선택 의뢰 — 각 4개

H1/R1/N3는 이번 안에서 주선으로 승격했으므로 아래 네 개에 중복 계산하지 않는다. 모든 의뢰는 마을에서 수락하고 중립 현장 또는 자기 마을에서 끝난다. 상대 마을 진입을 요구하지 않는다.

| 마을·ID·Lv | 부탁·영어 초안 | 실제 행동 | 선택→즉시 결과 | 보상·후일담 |
|---|---|---|---|---|
| Halo H2·8 | Bright: “Please find our missing lamp.” | I 분수 흔적→P 초원 등불→D Bright | 마을 반환/개인 진열: 공용 등불/휴대 진열. 소유하지 않은 ‘내 집’ 요구 없음 | 기존 H2; HaloChick 조건 유지 |
| Halo H3·12 | Gleam: “Please bring the cat down safely.” | P 간식→E 낮은 담장의 고양이→D 주민 | 새 주민 도움/내 구조 기념 촬영: 고양이 휴식/내 포즈. 동물을 다시 위험에 올리지 않음 | 기존 H3; HaloChick 조건 |
| Halo H5·15 | Bright: “Please deliver this permit before the cart leaves.” | P 서류→D 길목→F 막힌 걸쇠 | 바로 돕기/내 승인 도장: 수레 출발/도장 찍고 출발. 새 사냥 없음 | 기존 H5 |
| Halo H6·22 | Bright: “Please clean the old heroes' plaques.” | I 동상2→F 명판→P 빠진 작은 이름표 | 새싹 명판/내 명판 크게: 전시가 다름 | 기존 H6; H2+H3+H6 뒤 HaloChick |
| Horns R5·8 | Rose: “Please find my hat. Quietly!” | I 연못→P 젖은 모자→D Rose | 돌려주기/잠깐 쓰고 돌려주기: Rose 착용/플레이어 짧은 포즈 뒤 반환 | 기존 R5; HornsBat 조건 |
| Horns R3·12 | Rex: “Please set up prank number two hundred!” | P 소품→F 상자→Tiny가 열기 | 깜짝 간식/삑삑 장난: 모두 간식/모두 웃음. 위험한 폭발 없음 | 기존 R3; HornsBat 조건 |
| Horns R6·15 | Rose: “Please fix Plan B before anyone sees.” | I 뒤집힌 표지→F 방향→D 장난 영수증 | 제대로 안내/내 자랑 그림: 길은 둘 다 올바름, 장식만 차이 | 기존 R6 |
| Horns R7·22 | Rose: “Please bring the party snacks.” | P 간식→D 소굴 잔치 자리→F 좌석 | 모두 초대/단짝석: NPC 자리·몸짓 변화. 용암 접촉 요구 없음 | 기존 R7; R3+R5+R7 뒤 HornsBat |
| Artisan N0b·5 | Kit: “Have spares? Please sell five to Otto.” | 남는 재료5 확인→SellMat5→Otto 정산 | 도움용 묶음/내 상표 묶음: 판매 상자 표식 차이, 정산 같음 | 기존30골드+실제 판매대금; GearMouse 조건 |
| Artisan NA1·10 | Otto: “Please repair our delivery cart.” | S 축 F / A 윤활병 F / T 운반 간식 D | 공용 수레/길드 로고: 수레 달림/길드 깃발 달고 달림 | O급여 |
| Artisan NA2·15 | Fizzby: “Please sort these mixed-up orders.” | I 병/상자 그림→직업별 포장 F→두 NPC D | 급한 주민 먼저/단골 먼저: 실제 수령 순서 변화 | O급여 |
| Artisan NA3·22 | Tiny: “Please help this pet find its owner.” | I 간식 흔적→E 기존 아기 슬라임→D 주인 NPC | 조용히 인계/내 조련 자랑: 주인 포옹/박수 뒤 인계 | 신규G·기록, 펫 강제 빼앗기 없음 |

교차로 공통 선택 의뢰는 Lunch1·Pet1·XR1을 유지한다. Lunch1은 아이의 부탁→도시락 P→돌려줌/한 입→아이 D, 보상 HP1 또는25골드·가방+4다. 아이는 신규 `LunchKid` 제안(기본 Roblox 몸)이며 Tiny의 길드 역할과 혼동하지 않는다.
Pet1은 보급로에서 Pip이 “Please bring the little one here.”라고 부탁→아기 E→돌보기/부하 삼기. 둘 다 BabySlime을 얻고 따라오는 태도·개인 호칭이 다르다. 슬라임8 사냥은 제거한다. 거절해도 펫이 사라지지 않는다.
XR1은 첫30분 뒤 Tiny가 “Please find the teddy in that slime.”라고 부탁. 기존 왕자1 회수→실제 곰 P→주인 반환/수고비 요청→NPC 반응으로 고친다. 기존 보상 구조를 유지하되 새 장난 선택의 의미와 보상은 최종 검수가 검토한다.

## 9. 세 편이 만나는 장면과 같은 사실의 다른 해석

| 거울 장면 | Halo가 본 것 | Horns가 본 것 | Artisan이 본 것 | 같이 비교하면 드러나는 사실 |
|---|---|---|---|---|
| ① 팔찌·생일 소포, H1/R1/N3 | 뿔의 수상한 젤리 소포 | 빛의 비밀 축하 가루 | 같은 매듭·같은 주문표 | Bright와 Rose는 서로 선물을 준비했다. 원래 왕관 사건의 범인은 아직 모름 |
| ② 숲의 가루 자루, M3_2~4 | 훔친 가루를 회수하라는 명령 | 우리 몫보다 더 챙긴 큰 도둑 | 납품이 막힌 야간등 주문 | 작은 고블린의 필요와 우두머리의 독점은 다른 문제 |
| ③ 폐허 양면 기록, 각4_2~4 | 영웅 기록에서 뿔 서명이 빠짐 | 전리품 전설에서 빛 서명이 빠짐 | 같은 수리품에 양쪽 청구서 | 어느 편의 책도 전체가 아님. 길드도 누락에 책임 있음 |
| ④ 큰 조각·전쟁 뒤, 각5_3/6_1 | 보호한다고 성채에 가둘 수 있음 | 차지한 뒤 나눠 줄 수도 있음 | 고쳐 놓고 독점할 수도 있음 | 후광·뿔·길드 표식보다 지금의 쓰임이 그 사람을 보여 줌 |

거울 장면은 파티나 상대 진영 친구를 필수로 요구하지 않는다. 각자 단서의 자기 면을 보고 완료한다. 친구끼리는 같은 장소의 NPC 말풍선·공개한 기록을 비교할 수 있다. 개인 Pick은 개인 연출이며 다른 사람의 월드 충돌·길막을 만들지 않는다.

첫30분의 왕자·표본·숲 증거 순서는 이미 채택한 공통 뼈대이므로 일부 행동도 같다. 이후에는 Halo의 경비 표장 회수·정면 호위, Horns의 삑삑 미끼·상자 속 정찰꾼 구조·옆길 운반, Artisan의 부품 검사·주문 조립을 서로 다른 단계로 만든다. 단순히 Kill 목표의 NPC 이름만 바꾼 데이터를 세 개 복사하지 않는다.
뿔의 미끼는 퀘스트 전용 현장 연출/서버 상태다. 다른 플레이어가 싸우는 몬스터의 타깃을 뺏거나 전체 스폰을 멈추지 않는다. 미끼 작동 확인도 신규 Event로 검증하며, 즉석에서 전역 AI 기능이 있다고 가정하지 않는다.

### 성장 선택 지선의 완결 구조

| ID·제안 시점 | 부탁자·영어 초안 | 단계·갈 곳 | 마무리·보상 |
|---|---|---|---|
| S0·첫 스킬 습득 뒤 | Crown Shard: “Will you show me how you fight?” | 초원 B Slime3→현장 조각 Talk→S 몬스터2 동시 적중1→조각 앞 Choice | 정화/삼키기, 둥근 빛·조각 움직임이 다름. 기존 선택2·AutoCombat 해금. 추가 왕자 없음 |
| S4·S0 뒤 선택 | Crown Shard: “May I try fighting with you?” | Auto 버튼 Guide→State AutoOn→가까운 초원 AutoKill5→조각 Talk | 기존 G1. 해금 직후는 OFF, 퀘스트를 받았다고 강제 ON하지 않음 |
| SK1·TR15 완료/기존 Z 보유 | 자기 스승: “Will you try that move on the road?” | 현재 레벨 사냥터 S Slot Z·몬스터2 동시 적중1→스승 귀환 | 기존 G1. 새 스킬 실전1회만, 시험 전에 노출하지 않음 |
| SK2·TR25 완료/기존 X 보유 | Fountain: “Will you show me your new move?” | 분수 Choice→현재 레벨 사냥터 S Slot X·몬스터1 이상3회→분수 귀환 | 기존 G1·선택1. 선택에 맞춰 분수/표식이 반응 |
| M2_1·M1_4 뒤 선택 | Hallie/Magpie: “Will you help our side by hunting here?” / Kit: “Will you earn gold for our next supply run?” | 빛·뿔 WarPoints units15 / 장인 EarnGold Monster45, 항상 가장 가까운 열린 사냥터 Guide→부탁자 귀환 | 기존 G1. 표시 제목 `Help our side: hunt monsters`, 장인 `Earn gold for supplies`. ‘왕관 몬스터’ 없음 |

M2_1은 현재 가중 단위15와 ‘15마리’가 일치하지 않을 수 있다(황금 몬스터 가중치). v1은 기존 목표 판정을 보존하므로 행에는 `Contribution 0/15`와 사냥터 이름을 쓰고, 정수 왕관 점수와 같다고 설명하지 않는다. 꼭 ‘몬스터15마리’로 보이게 바꾸려면 Type=Kill Count15로 별도 승인·이관하며 UI만 바꿔 거짓 숫자를 보여주지 않는다.
S0·스승 시험·주선 스킬 과제의 같은 전투가 여러 수락 목표를 동시에 만족하는 것은 가능하다. 다만 수락 전 행동을 무조건 소급하거나 스승 시험 완료를 S0의 선택까지 자동 완료시키지 않는다.

### 공통 이벤트의 연결

| 사건·ID | 빛의 이유·목표 | 뿔의 이유·목표 | 장인의 이유·목표 | 주선과의 관계 |
|---|---|---|---|---|
| 황금 거위 S1, GW5 | Hallie 부탁: “Please help gather the golden eggs.” 실제 유효 참여1 | Rose 부탁: “Grab some eggs. Show me your haul!” 실제 유효 참여1 | `NE_GoosePrep` 제안: Tiny의 둥지 운반함 수리/간식 납품. **진짜 교차로에서 끝냄** | 모두 선택. S1/GW5는 현재 허용 진영 그대로. 이벤트 시간을 기다려야 주선이 열리는 구조 없음 |
| 왕관 기여 M2_1, S2, GW4 | 우리 편 기여 의뢰, 실제 단위15→선택 상자 의뢰 | 우리 편 자랑 기여, 동일 규칙 | 기존 M2_1의 사냥골드45는 선택 보급 의뢰로 유지하거나 N계열로 안내 | M2_1은 주선에서 뺌. S2 상자 실패/패배가 이야기 진행을 막지 않음 |
| 왕관전 각6_1 | 몬스터로 유효 기여→라운드 끝, 승패 무관 | 몬스터로 유효 기여→라운드 끝, 승패 무관 | N6_1 보급품2곳 D, 점수·축복·승패 판정 없음 | 빛·뿔은 PvP 없이 수행. 한 편 서버는 기존 포위전 결과로 완료 |
| 괴수 `HE_K1/RE_K1/NE_K1` 제안 | Gleam: “Please help us face the giant.” 실제 허용 참가/결과 확인 | Rose: “Please come back in one piece!” 실제 변신자 생존·종료 확인 또는 안전 지점의 현장 구호 | Otto: “Please repair the crates they brought back.” 일반 수리 의뢰 | 모두 선택, 출현 때만 제안. 별 모으기·괴롭힘·변신을 주선에서 강제하지 않음 |

쌍둥이 교차로에는 거위 게임만 둔다. NPC·수락창·납품·상점·추가 퀘스트 오브젝트를 넣지 않는다. S1은 본 교차로에서 수락하고 서버의 실제 거위 참여 결과를 받아 귀환 뒤 마무리한다.
Neutral의 전쟁/괴수 면역과 이벤트 참가 제한은 그대로다. 주변 의뢰를 했다고 거위·괴수 참여 횟수, 승리 점수, PocketKaiju 조건을 올리지 않는다. 중립 거위 참가 허용 같은 규칙 변경은 이 문서에서 승인하지 않는다.
Kaiju는 플레이어 기반 사건이다. ‘괴수를 잡고 엔딩’은 인구·PvP·변신 대기에 막히므로 본편 필수로 넣지 않는다. 괴수 사건이 없어도 폐허 조각의 과열을 보고 이야기를 이해한다.
W는 현재 엔진에 없는 라운드 연결 작업이다. 왕관 서비스 장애 시 거짓 승리/가짜 상자를 주지 않는다. 미완 상태를 보존하고 다른 선택 의뢰를 할 수 있게 하며, 출시 전 단독 서버에서도 실제 라운드 종료를 검증한다.

### 펫 12종과 도감의 위치

| 펫 | 주선/선택 경로 | 기존 조건을 지킬 부분 |
|---|---|---|
| Baby Slime | Pet1 구조, 또는 조련사 S1 연구 소환 | 최초 동료. Lv5 시험을 펫 소유로 잠그지 않음 |
| Flower Slime | 조련사 S2 소환·연구 | 모델 준비·숙련·재료 조건을 통과했을 때만 제안 |
| Sprout Goblin / Acorn Goblin | 조련사 S3/S4 소환·연구 | 숲 재료. 이름을 새 밈 이름으로 바꾸지 않음 |
| Bone Pup | 조련사 S5 소환·연구 | 폐허 재료. 캐릭터 Lv12에 폐허 재료가 있다고 가정하지 않음 |
| Crown Slime | King Slime 유효 보상5회, Lv8+ | M1_1의 BigSlime은 Slime Prince이므로 세지 않음 |
| Mini Clatter | Clatter 유효 보상3회, Lv30+ | 필수 결말 보상 아님, 감정표현만 |
| Halo Chick | H2·H3·H6, Lv10+, Halo | 본편 승격/이름 변경에도 기존 Done 조건 보존 |
| Horns Bat | R3·R5·R7, Lv10+, Horns | 위와 같음 |
| Gear Mouse | N0b·N2·N4, Lv10+, Neutral | N2/N4를 주선으로 옮겨도 같은 완료 원장 사용 |
| Golden Gosling | 실제 보상받은 거위3회, Lv5+ | 주변 수리/관람은 횟수 아님 |
| Pocket Kaiju | 유효 괴수 종료 참여3회, Lv15+ | 주변 수리/구경은 횟수 아님, 감정표현만 |

펫은 준비된 종만 노출한다(Config.PetReady). 새 모델이 없는 종의 소유를 주선 조건으로 삼지 않는다. 효과는 따라오는1마리만, 기존 상한·PvP/왕관전 제한·BabySlime 예외를 유지한다. 베타에 12종이 준비되어야 한다는 아트 의존성과 현재 구현 가능성을 구분한다.
도감은 첫 처치/연구/펫 획득의 실제 결과에 연결한다. 100·1000 처치 카드 진화나 전 펫 수집을 주선 문으로 삼지 않는다. 단서 기록은 퀘스트 기록으로 유지하며 새 도감 카드 미술·스탯 보상을 이 초안 때문에 요구하지 않는다.

## 10. 후반 레벨 공백을 숨기지 않는 운영 구조

**이야기의 첫 결말은 Lv40 제안, Lv100은 그 선택의 후일담 결말 제안이다.** 처음 40레벨의 사건을 100까지 늘이기 위해 같은 해골 처치량만 늘리지 않는다. 후반은 이미 아는 장소가 내가 남긴 변화로 달라지는 의뢰다.
Lv41~49·51~59 등은 새 구역이 아니라 기존 사냥·제작·선택 의뢰·일일·왕관전으로 성장하는 구간이다. 이 구간이 충분히 재미있다는 증거는 아직 없다. 현재 최대 일반 몬스터권이 Lv26~30, Clatter32이므로 Lv50~100의 적 난도·XP 곡선은 별도 검수해야 한다. 이번 안만으로 100레벨 콘텐츠 밀도를 확보했다고 주장하지 않는다.

| 반복 묶음 제안 | Halo | Horns | Artisan | 공통 규칙 |
|---|---|---|---|---|
| RP_Path | 주민의 실제 짐 회수→납품 | 장난 표지 설치→정리 | 작업품 수리→납품 | 이전 완료의 주행동과 다른 묶음을 우선 제안 |
| RP_Field | 길목 몬스터 소수→주민 통과 | 전리품 회수→자랑/나눔 | 재료 확보→직업 주문 | 기존 레벨 구역만. 가짜 고렙 몬스터명·신규 지역 없음 |
| RP_Record | 명판 정리→누락된 이름 발견 | 전설 소품 찾기→진실/허세 | 장부 대조→주문 오류 수정 | 이미 본 진실을 새 반전처럼 반복하지 않음 |

반복 의뢰는 새 무제한 보상 줄을 덧대지 않는다. 현재 일일/게시판 슬롯·감쇠·상한 안에서 교체하는 구현안이다. 게시판을 켜기 전 NPC 의뢰 형태부터 검증한다. 실제 보상 예산과 반복 목표는 개발2가 현재 Config.Daily/Board와 맞춰 별도 표로 산출한다.
진행 대기 동안 주선 행은 다음 레벨과 실제 부탁자를 표시하고, 누르면 현재 가능한 선택 의뢰의 NPC로 길을 안내한다. ‘아직 없는 다음 맵’이나 빈 ‘곧 만나요’ 목표를 보여주지 않는다.
Lv100에서는 XP 초과분을 새로운 재화로 바꾸지 않는다. 기존 상한 처리 유지. 환생은 선택이며 주선 엔딩을 본 사람에게 강제 초기화 과제로 주지 않는다.

## 11. 저장·ID 이전과 보상 중복 방지

### ID 처리표

| 현재 ID/묶음 | v1 처리 | 저장·연결 영향 |
|---|---|---|
| TutorialStep | 유지, 첫 임무는 대장간 | 첫 T1/150골드 수령 플래그 유지. M1_1 GiveWeapon과 중복 지급 금지 |
| M1_1 | 유지·왕자1+가루/팔찌 조사+주문서 사용 | M1_2의 미지급 보상 슬롯을 흡수. 과거 ScrollUsed는 현재처럼 Past 인정 여부 보존 |
| M1_2 | **활성 체인에서 제거**, 저장 호환 정의/별칭은 남김 | 무작정 Defs 삭제하면 sanitize가 Done을 지움. KO1·다른 Requires 전부 M1_1 또는 의미 플래그로 교체 |
| M1_3 / M1_4 | ID 유지, 스승 시험/등불 결말로 교체 | 옛 스킬 보유자는 회수하지 않음. Done인 사람에게 시험·장 보상을 재지급하지 않음 |
| M2_1 | Main→선택 Sub, 뜻이 보이는 제목으로 교체 | 진행·Claim·Done 그대로 옮김. S2 의존은 유지하되 주선을 잠그지 않음 |
| H1/R1/N3 | 맞는 진영의 Main 경로로 승격 | Requires M2_3→M1_4. 기존 Done이면 건너뜀. N3의 옛 타 진영 완료도 보존 |
| M2_2/3/6/7 | ID 유지, 조사/분수/발자국/입장 | 새 St 번호로 숫자만 복사 금지. 의미 단계로 이관 |
| M2_4/5 | Halo/Horns에서 유지; Neutral에서는 N2/N1/N4 경로로 대체 | 동등 보상 슬롯·단서 완료 별칭 필요. 두 경로를 동시에 활성화하지 않음 |
| N0/N0A/N0T | 직업별 첫 주문 유지, Lv5 도움에 연결 | 셋 중 자기 직업1개만 급여 지급. 직업 변경으로 세 번150골드 받지 않도록 공통 첫 주문 지급 키 |
| N0b | 선택 판매 의뢰 유지 | GearMouse 의존 유지. 재료5가 없으면 강제 채집·자동 등록하지 않음 |
| N1/N2/N4 | Neutral 주선의 실전·주문 접수·납품으로 재정의 | 이전 완료·급여 인정. 기존 N4의 Gold3/XP3을 임의로 G1로 축소하지 않음 |
| Lunch1 | ID·선택값 GiveBack/Bite·가방 보상 유지, Pop 제거 | NotDone M1_1 조건 제거. 이미 선택했으면 물건/가방 재지급 없음 |
| Pet1 | ID·Care/Minion·종 지급 유지, 사냥8→구조 | PetGrant/PetGrants의 기존 소유·지급 기록 보존 |
| S0/S4 | 자동전투 선택 지선 유지 | S0의 첫/추가 왕자 단계 제거, M1_1 조각 발견 기록 활용. 첫 스킬 후 부탁. 기존 해금·토글 저장 그대로 |
| SK1/SK2 | 선택 실전 후일담 유지 또는 TR15/TR25 뒤 접속 | 스승 시험과 중복 사냥 요구 금지. SK2 선택 보상·Pick 보존 |
| TR15_H/R/N, TR25_H/R/N | 신규 시험 ID | 슬롯별 공통 Learn 지급 원장. 진영 변경으로 스킬/시험 급여 중복 불가 |
| H2/H3/H5/H6, R3/R5/R6/R7 | ID 유지·실물 행동으로 수정 | PetGrants, TownReact, LinesBy, TitleBy 참조 유지 |
| NA1/NA2/NA3, NE_GoosePrep, HE_K1/RE_K1/NE_K1 | 신규 선택 ID | 실제 NPC·목표·준비 여부가 있을 때만 Offer |
| M3_1~4/6~8 | ID 유지·진영별 단계 분기 | M3_4 Pick Good/Evil/A/B 유지, Pip1의 Good/A 의미 보존 |
| M3_5/OathH/OathR | 선택 지선 유지, 주선 문 아님 | 기존 졸업 상태·칭호 보존. TR15 사냥과 겹치는 부분은 도움/약속 단계로 대체 |
| Pip1 | 후일담 유지, Lv15·M3_4 선 선택 | 지금 등불 반응은 M3_4에서 이미 보여 주고 Pip1은 시간이 지난 변화 |
| S1/S2/S3/S6/XR1/WB1 | 선택 지선 유지, 첫30분 자동 수락 제거 | S3 무작위 황금 몬스터·S2 상자·WB1 길목 선택을 Main 필수로 만들지 않음 |
| GW1~GW10 | 선택 지역 의뢰 유지·NPC Offer/Guide 보완 | 사냥만 반복되는 GW9/10 등은 수리·조사와 교차. 기존 Done·Pick·지급 보존 |
| EG01/02/03/04/14, D0, TS1, SG1, SZ1, KO1, MK1/2/3 | 기존 기록 유지, 새 주선에서 필수 제외 | 설명 팝업 재활성화 금지. NPC 없이 설명만 하는 옛 의뢰는 비활성 호환 정의로 보관하고 새 Offer 만들기 전 노출 안 함 |
| H4_1~4/R4_1~4/N4_1~4, H5_1~3/R5_1~3/N5_1~3, H6_1~3/R6_1~3/N6_1~3, H7_1~3/R7_1~3/N7_1~3 | 신규 Main | 짧은 키 사용. 기존 `N4`와 신규 `N4_1`은 다른 ID. 진영별 진실·시각 결과 저장 |
| 옛 문서의 M4-1~5, R2, S5 등 코드에 없는 이름 | 구현됨으로 간주하지 않음 | 이관 대상이 아니라 역사. 새 ID와 임의 대응하지 않음 |

### 이전 알고리즘 제안

1. 배포 전 현재 Main/Subs/Done/Pick/First, 스킬 슬롯, 가방 보상, 펫 지급 기록의 실제 저장 샘플을 비식별 fixture로 만든다. 개인정보를 문서에 넣지 않는다.
2. 새 저장 필드 제안: `Story.Schema=2`, `Route`, `Variant`, `StageKey`, `Accepted`, `Cargo`, `WorldFlags`, `RewardLedger`. 기존 Story.Main/Subs/Done/Pick를 보존하는 어댑터부터 만든다. 이것들은 **현재 필드가 아니다**.
3. 자동 활성화하던 refresh를 `Eligible→Offered→Accepted→Progress→Claimable→Done`으로 분리한다. 거절은 수락을 지울 뿐 완료·보상·평판을 건드리지 않는다. 재접속 뒤 미수락도 유지한다.
4. 숫자 St/P는 버전별 단계 의미 표로 옮긴다. 기존 완료 처치는 호환되는 사냥 목표에만, 기존 이동은 이동에만 인정한다. Near 통과를 새 Deliver 완료로 인정하지 않는다. 이미 끝난 퀘스트는 다시 시키지 않는다.
5. M1_2 Done이면 지급완료로 기록한다. M1_2 진행 중이면 새 M1_1 왕자 재처치를 요구하지 않고 가루/팔찌 회수부터 연결한다. M1_2 미완·보상 미지급일 때만 통합 보상 슬롯을 남긴다. 데이터가 모호하면 완료 진전을 보존하고 보상은 중복 지급하지 않는 보수적 이관을 기록한다.
6. Neutral 동등 슬롯: M2_4↔N2 접수, M2_5↔N1 실전, N4는 별도 기존 납품 보상. 옛 Done을 ‘시나리오 장면 완료’와 ‘급여 수령’으로 분리한다. 둘을 완료한 옛 계정에서 어느 쪽 보상도 다시 주지 않는다. 신규 Neutral에 M2_4/5 보상까지 덧붙이지 않는다.
7. 퀘스트 완료·물건 소비·선택·급여 플래그를 같은 계정 데이터 변경 안에서 처리한다. 고유 지급 키를 먼저 예약하고 재접속 시 미완 지급을 재개한다. 중간 크래시로 지급완료 표시만 남아 보상이 사라지는 경우도 시험한다. 퀘스트 물건은 시장 거래와 연결하지 않는다.
8. 옛 스킬 보유는 유지. 옛 진행자의 시험 플래그를 해당 배운 슬롯만 완료 처리한다. 미배운 슬롯은 새 시험을 수락한다. 기존 Tasks 진도는 대응 가능한 사냥 단계로만 옮긴다.
9. 진영 변경은 진행 중인 의뢰를 안전하게 보류하고 새 진영의 같은 의미 장면에서 새 부탁을 받게 한다. 기존 인벤토리를 남의 마을에 배달해야 하는 상태로 두지 않는다. 완료 장의 기본 급여는 진영을 바꿔도 다시 주지 않는다. 다른 진영 장면은 보상 없는 다시 보기/선택 지선으로 보되, 공짜 환생/진영 변경을 새 보상 파밍 길로 만들지 않는다.
10. 환생으로 Lv1이 되어도 Done·Pick·WorldFlags·펫은 보존한다. 잠긴 단계의 짐을 잃지 않으며 해당 레벨에 돌아와 재개한다. 주선 100%를 환생 조건으로 새로 추가하지 않는다.
11. 현재 sanitize는 모르는 Done ID를 지운다. **호환 정의·별칭 보존을 sanitize보다 먼저** 넣는다. Main→Sub뿐 아니라 Sub→Main 이관과 이미 수락한 이전 진영 의뢰를 시험한다. 오래된 SkipChapters가 신규 계정/신규 진영 장면을 잘못 건너뛰지 않게 Schema별 적용 범위를 제한한다.
12. 새 구조를 옛 서버가 다시 쓰면 진행 손실 위험이 있다. DataService의 구버전 거부 동작을 검토해 필요 시 **Version7의 조율 배포**로 묶는다. 이 문서만 보고 Version을 올리지 않는다. 최종 검수가 서버 교체·롤백 가능 범위를 정하고 메인 반영1이 적용한다.

모든 레거시 선택 보상·가방 확대·펫 지급은 별도 원장으로 한 번만 인정한다. StageKey 추가와 퀘스트 문구 수정만으로 예전 지급 여부를 추정하지 않는다. 저장 실패 시 성공 연출을 먼저 보여주지 않는다.

## 12. 화면·마커·장면 규칙 체크리스트

- [ ] 각 퀘스트에 누가/왜/부탁/실제 행동/결과가 있다. 이름은 “Check the parcel”, “Deliver Pip's supplies”처럼 뜻이 바로 보인다.
- [ ] 첫 말풍선은 부탁 1~2문장. 도시락만 사연 3짧은 줄 허용. 버튼은 `Accept` / `Decline`. 닫기=미수락, 거절=재수락 가능. 선택 A/B와 수락/거절을 섞지 않는다.
- [ ] A23-199의 NPC 대화는 허용된 수락 상호작용이다. 이를 빌미로 A23-191이 없앤 설명창·튜토리얼 카드·토스트·상단 파란 띠를 복원하지 않는다.
- [ ] 수락할 때와 각 단계가 바뀔 때 Guide가 실제 목표로 바뀐다. NPC, 조사물, 물건, 안전 경로, 복귀 NPC까지 모두 있다. 행 탭은 길 안내이지 원격 NPC 대화/납품 완료가 아니다.
- [ ] Guide=Bag은 가방/해당 주문서 버튼을 가리킨다. 소모품 사용처럼 월드 좌표가 없는 목표에 허공 화살표를 만들지 않는다. Level 대기는 가능한 의뢰 NPC/사냥터로 안내한다.
- [ ] 지도는 지역→현장→물건 순서. 새 마을은 태그/Anchor로 연결하고 옛 고정 좌표를 그대로 복사하지 않는다. 계단·높이·접근 불가 지역을 검증한다.
- [ ] 기본 HUD는 주선1개 우선. 도시락 등 내가 수락한 선택 의뢰를 덧붙이되 시작하자마자 여러 사냥 줄을 자동 등록하지 않는다. 기다리는 이벤트가 당장 할 목표를 덮지 않는다.
- [ ] 연속 퀘스트의 핵심 행동이 같지 않다. 전투→조사→전투→선택, 제작→납품/반응→조사로 바꾼다. 문구만 바뀐 Kill→EarnGold→Kill도 반복으로 판정한다.
- [ ] 같은 퀘스트 안의 조사2곳·배달2곳은 한 사건의 비교/분배일 때만 허용한다. 수량만 늘려 시간을 채우지 않는다.
- [ ] 모든 선택은 즉시 몸짓·등불·물건·자리·표식 중 하나가 달라진다. 대사/보상 숫자만 다르면 미완이다. 후일담은 저장된 Pick과 WorldFlags로 이어진다.
- [ ] 개인 선택은 개인 전시·NPC 반응으로 표현한다. 같은 서버에서 두 사람의 등불 선택이 충돌해 길·물리·다른 사람 보상을 바꾸지 않는다. 현재 서버 왕관전 하늘색도 개인 결말이 덮지 않는다.
- [ ] M1_4 여운은 약60초, 둥근 빛·작은 움직임. 계급 상승처럼 후광/뿔 크기를 키우지 않는다. 빛살/방사형 줄무늬 없음.
- [ ] 아이·고블린·펫을 괴롭히는 강제 목표 없음. 장난은 돌려주기·과장·자랑·삑삑 소품 수준. 현실 플레이어 모욕/물건 탈취/반복 KO를 주선에 넣지 않는다.
- [ ] 갑자기 부자가 되었다고 말하거나 아직 없는 장비/펫/지역 보상을 예고하지 않는다. 실제 지급 성공 뒤 기존 골드/XP 자리·가방 점·습득 연출로 답한다.
- [ ] 선택의 게임상 불이익은 기존 규칙 그대로 짧은 선택 버튼/기존 수치 자리에서 읽힌다. 장난 선택이 더 비싸다는 이유로 결제를 유도하지 않는다.
- [ ] 초보 보호·Neutral 면역 유지. 시험과 필수 주선에 다른 플레이어 존재·승리·황금 스폰·필드 보스 출현·PvP KO를 필수로 걸지 않는다.
- [ ] 필수 조사는 전용 증거 스폰을 사용해 다른 플레이어가 먼저 집어도 없어지지 않는다. 호위는 짧고 재개 가능, 경로 실패 시 마지막 안전 지점에서 복구한다.
- [ ] 몬스터 처치 귀속은 현재 서비스 규칙을 따른다. A23-181 첫 타격자 규칙을 모르고 ‘모두 퀘스트 인정’이라고 약속하지 않는다. 시험 전용 표적이 필요하면 기존 Personal 제외 판정을 우회하지 말고 별도 검증된 신호로 연결한다.
- [ ] 영어는 중앙 표, 이름은 현행 이름. 한국어 현지화 뒤 버튼/수량/폰 줄 잘림 확인. NPC 없는 상태에서 아무 곳에서나 Talk가 성공하는 기존 fallback은 새 의뢰에 허용하지 않는다.

## 13. 개발 순서 — 작은 완성본 단위, 첫30분부터

각 묶음은 서버와 화면이 함께 검증되면 출하 가능하다. 저장소 파일 변경만으로 적용됐다고 말하지 않는다. 최종 검수 검토→검증된 가지 병합→메인 반영1 sync/Play/저장 순서를 유지한다. 날짜를 새로 정하지 않는다.

| 묶음 | 게임성 개발2 — 서버·데이터 | 게임성 개발1 — 화면·상호작용 | 완료 기준 |
|---|---|---|---|
| 0. 계약 고정 | ID/StageKey/Variant·보상 원장·선후행 DAG·레거시 fixture·각 NPC/Guide 목록 | 한 화면의 부탁/Accept·Decline·선택·마커 계약, A23-191 금지 호출 점검 | 자동 수락/주선 순환/누락 Guide를 데이터 검사로 잡음 |
| 1. 수락과 첫 무기 | Tutorial 첫 보상1회, Offer 상태, 진영별 Main 선택 기반 | 안내자 말풍선·수락 버튼·오토 경로, 자동 설명창 제거 | 새 저장 세 진영 모두 무기·150골드1회. 거절/닫기/재접속 통과 |
| 2. 첫 왕자·도시락 | P/I/D 거리·소유 검증, Lunch1 전 과정, M1_2 통합·KO1 의존 수정 | 아이 몸/!·도시락 실물·팔찌 확인·주문서 위치·귀환 반응 | 왕자1회, 도시락 늦게 수락 가능, 지급·가방 중복0 |
| 3. Lv5 스승·장인 첫 주문 | M1_3 시험, Tasks 통합, N0 세 직업 결과품·배움 연동 | 스승 시범·잠긴 슬롯·작업대·납품 반응 | 배우기 전 스킬 요구0, 세 장인 직업 모두 주문 완료. 기존 스킬 회수0 |
| 4. 첫 장 결말 | M1_4 Choice·등불·팔찌 기록과 보상 원자 처리 | 개인 등불/표식·주민 손인사·Bright/Rose 손목 동작 | 45~60초 안에 ‘내가 바꾼 것’이 보임. 재접속 뒤 상태 동일 |
| 5. 10~20분 | H1/R1/N3 선행 변경, M2 조사/보급, Neutral N1/N2/N4 대체 | 소포·표본·분수 두 아이·운반 상자·직업별 납품 | 진영별 동기가 다름. 사냥→사냥 반복 없이 Lv10 진입 경로 완주 |
| 6. 20~30분 | M3_1~4 진영 변형·특정 운반꾼·Pip 선택·Pet1/S0 늦은 Offer | 캠프3 흔적·우두머리 자루·Pip 등불·짧은 따라오기 | 첫30분 실제 플레이 세 진영/장인3직업, PC·폰. 점수/XP 부족 지점 기록 |
| 7. 첫30분 저장 배포 | 이전 알고리즘·구서버 호환/거부·재시도·금고/가방/펫 원장 | 재접속 시 목표·물건·마커 복원, 보상 확정 신호 | 중간 종료·중복 원격·미수락·가득 찬 가방·직업/진영 변경 fixture 통과 |
| 8. 숲 후반·Lv15 | TR15, M3_6/7/8, 마을4개씩·Pip1·기존 펫 조건 | 수레·표지·주문·고향 반응, 실제 NPC 모델/태그 | Lv15 시험2단계. 사냥 할당량만 늘리지 않음. 기존 펫 조건 보존 |
| 9. 장인 마을·폐허 앞 | A23-152 ArtisanTown/HomeZone/스승·상점 좌표 연동, TR25·각4_1~4 | 마을 이동·안전 고리 길·양면 기록·기존 폰 지도 | 상대 마을 진입 요구0, 신규 마을 경로 검증, 스킬 꺼짐에도 주선 막힘0 |
| 10. Lv35~40 1차 결말 | 각5_1~3, 직업별 주문, 개인 조각 안정 상태 | 냉각 고리·운반·공용/개인 설치 장면 | 보스/거위/상대 유저 없이 끝남. 서버 왕관전 상태와 개인 결말 충돌0 |
| 11. 이벤트 교차 | M2_1/S1/S2/GW4/GW5 Offer, W 라운드 신호, 괴수 선택 의뢰 | 실제 참여 가능할 때만 표시, 귀환 마커, 본 교차로 수령 | 쌍둥이 광장 추가 NPC0, Neutral 허위 참가0, 패배도 W 완료 |
| 12. Lv50~100 후일담 | 각6/7, 반복 의뢰 예산·레벨 실측·환생 이관 | 이전 선택 전시·견습 NPC·Lv100 고향 마무리 | 고레벨 XP 공백의 실제 시간/재미 판정. 전 진영 완주·보상 파밍0 |

### 검수할 실제 시나리오

| 범위 | 꼭 해 볼 플레이 |
|---|---|
| 신규 | Halo·Horns 전투3직업, Neutral 제작3직업. 무과금/보너스 없는 계정 기준과 적용 배율을 구분 |
| 첫30분 | 도시락 즉시 수락/거절 후 나중, 왕자 처치 후 미수락, 스승 시험 중 종료, M1_4 양쪽 선택, Lv5/10 부족 |
| 저장 | M1_2 진행·완료, M2_1 진행·Claim, H1/R1/N3 기존 Done, N0/N4 기존 Done, 구스킬 보유, 새 서버 뒤 구버전 접속 |
| 보상 | 중복 Accept/Choose/Claim/Deliver, 가방 가득 참, 제작 실패/돈0, 재료 판매 시도, 물건 없는 원격 납품, 지급 도중 종료 |
| 세계 | NPC 없는 맵, 바뀐 마을 좌표, 호위 길막, 다른 사람이 증거 먼저 줍기, 개인 등불 선택 충돌, 폰 세로 화면 |
| 후반 | 한 명 서버 왕관전, 지는 편, 이벤트 없는 시간, Neutral 왕관전/괴수 주변 의뢰, 환생·진영 변경·Lv100 |

## 14. Claude가 먼저 비평할 쟁점

1. **차별화:** 첫 왕자·기초 시험·팔찌·숲 핵심 증거는 공유한다. 그러나 장인은 실제 제작·납품, 빛은 구조·공적 책임, 뿔은 선점·장난·뒷수습이 중심이다. 대사만 다른 행이 과도한지, 특히 첫10분 이후를 지적해 달라.
2. **첫30분 시간:** 채택 문서의 시간표와 현재 XP/왕복 거리/장인 제작을 동시에 만족하는지 미검증이다. 필수 행이 많으면 사건을 지우기보다 같은 NPC의 연속 단계를 한 의뢰로 묶을 후보를 고른다.
3. **후반 범위:** Lv40 1차 결말과 Lv100 후일담은 제안이다. 현 적/XP만으로 Lv50~100이 지루할 가능성이 크다. 이를 해결했다고 주장하지 말고 실제 성장 측정 뒤 후반 레벨 배치를 조정해야 한다. 상한을 내리거나 새 지역을 추가하는 결정은 여기서 하지 않는다.
4. **새 설정의 선:** ‘공동 수리 흔적·양쪽 누락·길드 책임·조각 과열’은 초안이다. 기존 팔찌·두 아이 그림을 잇지만 원래 왕관 파괴자를 확정하지 않는다. 지나치게 교훈적으로 들리면 행동과 농담으로 줄인다.
5. **구현 규모:** I/P/D/F/E·주문 귀속·진영별 Main·보상 이관은 새 기능이다. 문구 수정만의 일정으로 잡으면 안 된다. 첫30분 묶음이 통과하기 전 후반 퀘스트 데이터 양부터 늘리지 않는다.
6. **선택의 결과:** 대화만 바뀌는 선택이 남았는지, 장난이 동물/아이 괴롭힘으로 보이는지, 개인 연출이 전역 왕관전과 충돌하는지 우선 검토한다.
7. **이벤트와 펫:** 중립의 이벤트 규칙을 바꾸지 않고도 세 편이 같은 사건을 말할 수 있는지 확인한다. 모든 진영에게 모든 이벤트 펫을 보장하는 문서가 아니다.

이 문서의 완료 판정은 ‘표에 퀘스트가 많음’이 아니라, 첫 부탁에서 고향의 마지막 장면까지 이유·행동·선택·실물 결과·저장이 연결되고 세 진영이 서로 다른 경험을 말할 수 있는가다.
