# Halo & Horns 퀘스트 바이블 v3

작성: Codex · 2026-10-15 · Claude 최종 검수용 수정안. 문서 설계이며 구현·승인·Studio 적용 완료를 뜻하지 않는다.

## 사용자용 요약

**1~35레벨에 세 편 본편 30개씩, 마을 심부름 12개씩, 공통 의뢰 20개, 연결망 마지막 의뢰 6개를 넣었습니다. 일회성 152개와 반복 의뢰 12종입니다.** 세 편을 전부 해야 하는 양은 아닙니다. 한 편을 골라도 자기 마을 사람들의 사연과 공통 의뢰를 오래 즐길 수 있게 했습니다.

부탁 하나가 다른 사람의 사연으로 이어집니다. 브라이트의 구겨진 리본을 오토에게 가져가면 오토의 포장 고민이 열리고, 로즈에게 받은 답장은 다시 빛 마을로 돌아옵니다. 3레벨에 빌려준 손수건·돌려준 단추·고친 바퀴는 20레벨에 돌아옵니다. 관련 부탁 두세 개를 끝내면 특별한 뒷이야기와 칭호·기존 펫·작은 꾸미기 보상이 열립니다.

- **빛 기사단:** 잃어버린 물건을 돌려주고 길을 지킵니다. 구해 준 고양이는 내 멋진 구조 자세를 보고 하품합니다. 처음 건넨 손수건이 나중에 수레의 구조 깃발이 됩니다.
- **뿔 군단:** 먼저 잡고, 허풍을 떨고, 웃기는 장난을 칩니다. 장난은 내 모자와 빈 상자로 돌아옵니다. 3레벨의 거꾸로 단 단추가 20레벨에는 친구들만 아는 대장 표식이 됩니다.
- **장인 길드:** 재료를 모아 만들고, 주문자가 쓰는 모습까지 봅니다. 처음 고친 바퀴가 20레벨에도 굴러가고, 그 주문자가 다음 손님을 소개합니다. 지금은 교차로의 대장간·작업대를 쓰며 장인 마을 완공 뒤 접수·작업 자리만 옮깁니다.

**스승은 처음부터 마을에 있습니다.** 할리·맥파이·킷이 글림 경·로즈·오토를 소개합니다. 1~2레벨에 스승이 기본 공격을 한 번 보여 주고 내가 한 번 해 봅니다. 2~4레벨 작은 부탁은 선택이며, 첫 무기를 받는 길과 겹칩니다. 5레벨은 약 5분 도달을 목표로 유지하고, 15·25레벨 시험 전에 스승과 다시 만납니다.

모든 퀘스트는 현장의 NPC가 부탁하고 **수락하거나 거절**합니다. 길 안내는 매 단계 이어집니다. 파란 설명창·튜토리얼 글 팝업은 없습니다. 50~100레벨 상세 이야기는 베타 뒤에 정합니다. 아래는 제작 제안서이며 아직 게임에 적용된 분량은 아닙니다.

## 1. 근거와 범위

| 근거 | v3 적용 |
|---|---|
| 이번 사용자 비평 A·B | Lv1~35 분량 확대·NPC 연결망·늦게 돌아오는 보답·처음부터 있는 스승; 6~7장은 §10 한 표만 |
| `docs/SPEC_ADDENDUM.md` A23-152·191·193·197~200 | 장인 포함·마을은 나중, 스승 시험, 아이의 도시락 부탁, NPC 수락/거절·모든 단계 Guide |
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
| Hallie·Magpie·Pip·Rex·Kit·Fizzby `[몸 필요]` | 안내자·이야기 화자; 실물·대화 앵커는 구현 확인 필요, Kit=Guild, Fizzby=Potion | **needs NPC body**: 기본 몸·태그·대화 거리·Guide 앵커 구현 전 해당 의뢰 비노출 |
| Fountain·Shard `[조각]` | Speakers의 물체 화자 | 사람 몸 대신 실제 조각 상호작용 앵커 필요; v3 부탁은 기존 사람 NPC가 맡음 |

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

주선은 각 표의 순서다. `a`가 붙은 삽입 행도 앞뒤 행 사이에 진행한다. 단, H00a/R00a는 H00/R00의 스승 방문 중 별도 수락해 수행하는 짧은 병행 의뢰다. 첫 무기 수령은 그대로 Otto에게서 하며 §7의 재제안 규칙을 따른다. `H/R/N`은 설명용 진영 표기이고 기존 ID는 유지한다. 같은 행의 화살표는 단계 순서다. 각 행의 짧은 부탁이 Offer이며(기존 행은 영어 원문, 추가 행은 한국어 집필안) 버튼은 항상 **Accept / Decline**이다. 거절·닫기는 벌점 없이 다시 수락 가능하다. `—`는 별도 선택 없이 표의 실물 결과가 생긴다는 뜻이다.

**유형은 주로 하는 행동**이다. 전투 이름만 바꿔 반복하지 않는다. 본편은 연속 행의 주유형을 다르게 배치하고, 세부 목표도 같은 종류의 연속 클릭은 한 묶음으로 센다. 수락·복귀 Talk를 끼워 사냥 반복을 감추지 않는다. 시험은 사냥→도움→귀환이며, Lv5 사냥 공통은 명시된 예외다. 선택 지선은 강제 삽입하지 않고 직전 주행동과 다른 제안을 먼저 보여준다.

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

### 분량표 — 같은 의뢰의 분기·단계는 중복 계산하지 않음

| 구분 | 본편·스승 관계 | 마을 선택 지선 | 공통 의뢰 | 연결망 마지막 | 반복 종류 | 범위 |
|---|---:|---:|---:|---:|---:|---|
| 빛 편 / 빛 마을 | 30 | 12 | 아래 공용 풀 이용 | W01·W04 | DH1~3 | Lv1~35 |
| 뿔 편 / 뿔 마을 | 30 | 12 | 아래 공용 풀 이용 | W02·W04 | DR1~3 | Lv1~35 |
| 장인 편 / 장인 접수대 | 30 | 12 | 아래 공용 풀 이용 | W03·W04 | DN1~3 | Lv1~35; 현재 교차로 |
| 교차로·초원·숲·폐허 공용 풀 | — | — | 20 | W05·W06 | DC1~3 | 성장8 + 행사5 + 지역7 |
| 전체 제작량 | **90** | **36** | **20** | **6** | **12** | **일회성 152 + 반복 틀 12** |

공통 의뢰는 세 편에 복사해서 60개로 세지 않는다. M2_1은 빛/뿔판과 장인판의 서로 다른 목표를 2개 경로로 센다(한 캐릭터는 한 경로만). 장인 N02 준비는 N03 행에 N0의 Lv3 준비 단계로 합쳐 별도 의뢰 수에서 뺐다. Tutorial·스승 시범은 실제 부탁·목표가 있는 의뢰이며 NPC 인사 한마디는 개수에 넣지 않는다. N03 행은 Lv3 N0 주문과 Lv5 시험의 연결 묶음이며 각각 필요한 시점에 수락한다. 기존 N0 급여 슬롯도 추가 의뢰로 세지 않는다. 따라서 본편 90개는 설계상 진행 묶음 수이며 저장 ID 수와 같다는 뜻은 아니다. 각 진영 30행은 §§4~6, 각 마을 12행은 §8, 공통 20행은 §9, 특별6행·반복12행은 §9 아래에 전부 있다.

각 마을의 12개 지선은 해당 편 전용이다. 다른 마을 방문은 §9 공통 배송망에서 안전한 민간 접수 지점으로 이어진다. 장인 마을이 없을 때는 교차로 장인 접수대가 세 번째 거점이며, 완공 뒤 같은 ID·기록으로 이동한다. 원래 없는 마을에 먼저 가라고 하지 않는다.

### 첫 30분의 고정 장면

| 목표 구간 | 사건·동선 | 속도·수락 규칙 |
|---|---|---|
| 0~1분 | 오프닝·진영/직업 → Hallie/Magpie/Kit의 소개 → 스승 첫 인사 | 빛/뿔 스승은 자기 마을 출구 동선, 오토는 Forge. 소개 때문에 교차로에서 고향으로 추가 왕복하지 않음 |
| 1~2분·Lv1~2 | 빛/뿔: 스승 옆 연습 도구로 시범·한 번 적중→Otto 첫 무기. 장인: Otto 첫 무기→같은 자리 시범·한 번 적중 | 5~8초 시범 + 내 한 번, 전체 약 15~20초 목표. 회피·구르기·미배운 스킬 요구0. 거절하면 왕자/성장을 막지 않고 재제안 |
| 2~5분·Lv2~5 | 왕자1·팔찌·T2·주문서; 도시락은 선택. Lv2~4 스승 심부름은 같은 길에서 선택 | **Lv5 도달 약 5분 목표**. 일회성 XP·이동 실측으로 맞춤. 필수 귀환·추가 처치로 시범 비용을 메우지 않음 |
| 5~8분 | Lv5 시험: 수락 후 기본 공격 Slime4 + 도움1 → 원래 있던 스승에게 배움 | 도달과 습득 시간을 별도 기록. 시범 공격을 시험 Slime4로 소급 계산하지 않음 |
| 8~15분 | 등불·팔찌 반응 → 진영별 생일 소포 → 연못·분수 | 길 위 선택 지선은 한 번에 하나만 먼저 제안, 수락 목록 강제 채움0 |
| 15~25분 | 진영별 보급 행동 → 첫 스킬 실전 → Lv10 숲의 구조/장난/수리 | 같은 왕자를 다시 잡게 하지 않음; 공통 배송망은 늦게 해도 됨 |
| 25~30분 | 숲 첫 등불 결말 또는 진행 중 목표 → 다음 마을 인연 예고 | Lv13 스승 안부는 그 레벨에 도달한 뒤. 30분 안에 Lv15를 억지로 약속하지 않음 |

시간은 실측 전 목표다. 첫 5분 추가 시범 비용은 기존 이동·대화 단축으로 흡수한다. 한 번도 수락하지 않은 시범의 완료를 조용히 기록하지 않는다. 장인은 N0 재료 준비를 기존 경로에서 하되 제작 숙련 XP를 캐릭터 XP로 세지 않는다. Lv5가 늦어지면 XP·동선을 조정 검수하며 선택 지선을 필수로 돌리지 않는다.

## 4. Halo 전체 주선 30개 — 먼저 가서 길을 지키는 편

| 순서·장·Lv·ID | 부탁자 상태 | Offer — Accept / Decline | 유형·실제 목표 | Guide 대상 순서 | 선택→보이는 결과 | 보상 |
|---|---|---|---|---|---|---|
| H00·1·1·Tutorial | Hallie[몸 필요] | For fighting, see Sir Gleam. Then get a weapon from Otto. | 방문: 고향 출구 Gleam 첫 인사→오토 무료 무기 | Hallie→고향 Gleam→Blacksmith/Otto | —; Gleam이 인사하고 무기 길을 가리킴 | 무료 T1·150골드; 기존 한 번 |
| H00a·1·1~2·H_Basics | Gleam[몸] | Watch my swing, then try one hit. | 시범: Gleam 기본 공격1→빌린 연습 도구로 내 기본 공격1→도구 반납; 이후 H00의 Otto 무기 수령으로 이어짐 | Gleam→바로 옆 연습대→Gleam | 함께 정렬/내 승리 자세; 큰 방패 뒤 작은 인사 | 기록; 첫 무기 급여 중복0; →HS01 |
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
| H15a·3·13·H_CheckIn | Gleam[몸] | Show me where you kept the cart safe. | 재현: 숲길 모형에 지킨 위치 놓기→스승과 방패 위치 맞춤 | Gleam→고향 연습대 모형→Gleam | 친구 쪽/내 표식 쪽; 스승이 반대쪽을 맡음 | G·기록; →H16 |
| H16·3·15·TR15_H | Gleam[몸] | Pass the hunt, then escort our porter. | 시험: §7 Lv15 사냥→짐 든 Pip 호위1→귀환 | Gleam→숲 시험터→Pip[몸 필요]→안전 턱→Gleam | 앞에서/옆에서 안내; Pip의 이동 대형 변경 | 2번 스킬, 추가 급여0 |
| H17·3·18·M3_6[H] | Pip[몸 필요] | Please catch our records before the shelf falls. | 구조: 받침 위치 선택→넘어지는 기록함 받아 안전대에 둠 | Pip→숲 임시 선반→안전대→Pip | 기록함/등불부터; 마지막에 두 물건 모두 안전, Pip의 든 짐 달라짐 | 기존(M3_6) |
| H17a·3·20·H_Return | Pip[몸 필요] | Help me raise this old rescue ribbon. | 설치: 수레에 안전 깃발 고정→Pip과 한 번 들어 확인 | 숲 Pip→수레 깃대→Pip | 남들 길잡이/내 표식; HS01 완료면 Lv3 손수건이 깃발로 돌아오고 Gleam의 매듭도 남음; 미완이면 Pip 천 사용 | G·기록; HS01⇢회수 연출, →W04 |
| H18·3·21·M3_7[H] | Pip[몸 필요] | Please guard the cart at each bend. | 방어: 두 굽이의 위협 저지→수레 도착 | Pip→숲 수레 굽이→폐허 입구 보관대 | 안쪽/뒤쪽 지키기; Pip이 반대편을 맡음 | 기존(M3_7) |
| H19·4·25·M3_8[H] | Gleam[몸] | Please inspect the old road before we use it. | 조사: 폐허 안전 고리의 발판·옛 도장 확인 | Gleam→폐허 안전 입구→발판·도장→Gleam | —; 기사 표장 밑에서 뿔 표식도 보임 | 기존(M3_8) |
| H20·4·25·TR25_H | Gleam[몸] | Pass the hunt, then guard the loading ramp. | 시험: §7 Lv25 사냥→적재 경사로 보호1→귀환 | Gleam→폐허 시험터→Pip[몸 필요] 경사로→Gleam | 사람 길/짐 길 지키기; Pip이 열린 반대편으로 운반 | 3번 스킬, 추가 급여0 |
| H21·4·27·H4_1 | Pip[몸 필요] | Please guide our record cart under the arch. | 호위: 낙하 예고를 보고 정차·출발, 기록 수레 통과 | Pip→폐허 안전 아치→보관대→Pip | 낮은 길/넓은 길; 수레 리본이 접힘/펼쳐짐 | G |
| H22·4·30·H4_2 | Pip[몸 필요] | Please catch both pages from that loose box. | 구조: 두 위치에 받침 펼침→날리는 기록 두 장 회수 | Pip→느슨한 기록함→받침→Pip | 왼쪽/오른쪽부터; 내 머리에 마지막 빈 종이가 붙음 | G·기록 |
| H23·4·32·H4_4 | Bright[몸] | Please show me how the two pages fit. | 전시: 두 기록 맞춤→공용판/내 전시판 | Bright→고향 기록판→Bright | 양쪽 나란히/내 장 앞에; Bright가 뒤쪽 보려고 빙 돌아감 | GX |
| H24·5·33·H5_1 | Pip[몸 필요] | Please hold the crossing while I move the shard. | 방어: 흔들림 예고마다 안전 걸쇠 잡기, 운반자 통과 | Pip→폐허 안전 다리→걸쇠→Pip | 왼쪽/오른쪽 담당; Pip이 반대쪽을 잡고 엄지 듦 | G |
| H25·5·34·H5_2 | Pip[몸 필요] | Please walk with me to the cool stone. | 호위: 뜨거운 조각 운반자의 쉼 지점2 선택→냉각대 | Pip→그늘 표식→냉각대→Pip | 짧게 자주/넓은 곳 한 번; Pip의 쉬는 동작 차이 | G |
| H26·5·35·H5_3 | Bright[몸] | Please choose a place for our little light. | 선택: 식은 조각을 공용 등불/내 전시대에 놓음 | Bright→고향 공용 등불/개인 전시대→Bright | 주민이 모임/내 그림자에 모자 장난; 첫 결말 | GX·기록 |

## 5. Horns 전체 주선 30개 — 내가 대장이라며 먼저 뛰는 편

| 순서·장·Lv·ID | 부탁자 상태 | Offer — Accept / Decline | 유형·실제 목표 | Guide 대상 순서 | 선택→보이는 결과 | 보상 |
|---|---|---|---|---|---|---|
| R00·1·1·Tutorial | Magpie[몸 필요] | For fighting, see Rose. Then get a weapon from Otto. | 방문: 고향 출구 Rose 첫 인사→오토 무료 무기 | Magpie→고향 Rose→Blacksmith/Otto | —; Rose가 먼저 자세를 잡다가 무기 길을 가리킴 | 무료 T1·150골드; 기존 한 번 |
| R00a·1·1~2·R_Basics | Rose[몸] | Watch my hit, then try one of your own. | 시범: Rose 기본 공격1→빌린 연습 도구로 내 기본 공격1→도구 반납; 이후 R00의 Otto 무기 수령으로 이어짐 | Rose→바로 옆 연습대→Rose | 함께 인사/나만 대장; 허수아비 모자가 Rose 쪽으로 기울어짐 | 기록; →RS01 |
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
| R15a·3·13·R_CheckIn | Rose[몸] | Show me how your squeaky trick worked. | 재현: 숲 미끼 모형의 빈 안전 자리에 장치 놓기→Rose 시범 | Rose→고향 연습대→Rose | 함께 등장/나부터; 장치가 내 발밑에서 삑 | G·기록; →R16 |
| R16·3·15·TR15_R | Rose[몸] | Pass the hunt, then sort out your squeaky helper. | 시험: §7 Lv15 사냥→Pip을 지휘해 장난 표지 정리1→귀환 | Rose→숲 시험터→Pip[몸 필요] 표지 자리→Rose | 손짓/휘파람 명령; 내 장치가 마지막에 내게 경례 소리 | 2번 스킬, 추가 급여0 |
| R17·3·18·M3_6[R] | Pip[몸 필요] | Please bluff your way past our pretend toll booth. | 허풍: 영수증 그림을 보고 통행 암호 선택→놀이 문 열기 | Pip→숲 놀이 요금소→문 뒤 상자→Pip | 엄숙한/우스운 암호; 내 대장 도장이 얼굴 그림으로 찍힘 | 기존(M3_6) |
| R17a·3·20·R_Return | Pip[몸 필요] | Give our silly signal before the cart leaves. | 지휘: 두 신호 중 정차 신호를 골라 수레 출발 맞춤 | 숲 Pip→안전 수레 신호대→Pip | 동료 먼저/내 경례 먼저; RS01 완료면 Lv3 단추가 거꾸로 단 대장 표식으로 돌아옴, 미완이면 보통 깃발 | G·기록; RS01⇢회수 연출, →W04 |
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

## 6. Artisan 전체 주선 30개 — 만들어서 쓰는 모습을 보는 편

S=대장장이, A=연금술사, T=조련사. `W2/AP1/T1`은 현재 레시피를 사용한다. W2는 내 무기로 남기고 도움용 부품은 의뢰 전용 파트로 처리한다. AP1은 HP, T1은 간식의 실제 제작·사용을 확인한다. 후반 주문품은 새 퀘스트 Event이며 기존 상점 레시피라고 주장하지 않는다.

**현재 접수·귀환은 교차로/Forge/작업대뿐이다.** 아래 이전 열의 `접수·작업`은 장인 마을 완공 시 그 부분만 이동, `접수`는 NPC 접수만 이동, `유지`는 교차로 이야기 장면 유지다. 현장인 초원·숲·폐허는 이동하지 않는다. 오토 스승·Forge의 이동 여부는 별도 배치 결정 전 현재 자리 고정이다.

| 순서·장·Lv·ID | 부탁자 상태 | Offer — Accept / Decline | 유형·실제 목표 | Guide 대상 순서 | 선택→보이는 결과 | 보상 | 장인 마을 완공 시 이전 |
|---|---|---|---|---|---|---|---|
| N00·1·1·Tutorial | Kit[몸 필요] | For fighting and tools, see Otto at the Forge. | 방문: 오토에게 첫 무기·도구 수령, 같은 자리 스승 소개 | Kit→Blacksmith/Otto | —; 오토가 무기를 건네고 옆 연습대를 톡 두드림 | 무료 T1·150골드 | 유지(Forge) |
| N00a·1·1~2·N_Basics | Otto[몸] | Watch my hit, then try it with your tool. | 시범: 첫 무기 받은 자리 옆에서 오토 기본 공격1→내 기본 공격1 | Otto→Forge 옆 연습대→Otto | 공용 받침/내 상표; 허수아비가 작업 완료 도장처럼 끄덕 | 기록; →NS01 | 유지(Forge) |
| N01·1·1·M1_1[N] | Otto[몸] | Please bring back the shiny band from that slime. | 전투: BigSlime1→팔찌 조사→T2 장착·주문서 사용 | Otto→초원 왕자→팔찌→Bag | —; 재료 봉투에서 두 색 매듭이 튀어나옴 | 기존(M1_1)+미지급 M1_2·첫 드롭 | 유지 |
| N03·1·3~5·M1_3[N]+N0계열 완료 | Otto[몸] | 준비: Please gather the materials for Tiny's order. / Lv5: Beat four slimes, then make something for Tiny. | 시험: Lv3 N0 주문 수락·준비 S Herb3·CopperOre2 / A·T Herb3를 주문함에 보관→Lv5 시험 별도 수락·BasicKill Slime4→S W2+의뢰부품 / A AP1·HP1 / T T1·간식1 제작·Tiny 도움1→귀환 | Otto→인근 해당 채집점→주문함→Lv5 Otto→초원 입구→교차로 직업 작업대→Tiny→Otto | —; 수레 바퀴 회전/약병 받음/아기 슬라임 접근 | 첫 스킬·기존(M1_3)+자기 N0계열150골드1회 | 작업만 이전; 시험 귀환 Forge |
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
| N16a·3·13·N_CheckIn | Otto[몸] | Show me what kept your lamp steady. | 재현: 숲 등불 모형의 흔들리는 받침 고정→오토와 시험 | Otto→Forge 시험대→Otto | 공용 도장/내 서명; 오토가 흔들어도 컵만 딸깍 | G·기록; →N17 | 유지(Forge) |
| N17·3·15·TR15_N | Otto[몸] | Pass the hunt, then help our next customer. | 시험: §7 Lv15 사냥→S 수레 수리 / A 약 제작·전달 / T 간식 제작·따라오기1→귀환 | Otto→숲 시험터→직업 작업대→Tiny/아기 슬라임→Otto | 공용 표식/내 서명; 사용 물건의 꼬리표 변경 | 2번 스킬, 추가 급여0 | 작업만 이전 |
| N18·3·18·M3_6[N] | Tiny[몸] | Please bring back the borrowed tool case. | 배달: 숲 작업대의 도구함을 교차로 Tiny에게 운반 | Tiny→숲 작업대 도구함→Tiny | 손잡이/끈 운반; 내 들고 가는 자세 차이 | 기존(M3_6) | 접수·반납 이전 |
| N18a·3·20·N_Return | Pip[몸 필요] | Help me test the wheel that brought us here. | 수리: 수레 안전 받침 넣기→바퀴 시험 회전→잠금 | 숲 Pip→수레 바퀴→Pip | 공용 보증/내 도장; NS01 완료면 Lv3 고친 바퀴와 오토 쪽지가 돌아옴, 미완이면 표준 부품 | G·기록; NS01⇢회수 연출, →W04 | 유지(현장) |
| N19·3·21·M3_7[N] | Otto[몸] | Please make one order for each side. | 제작: 직업 부품1묶음→양쪽 수령함에 나눠 넣음 | Otto→교차로 작업대→두 수령함→Otto | 같은 포장/각자 표식; 양쪽 상자가 같은 내용으로 열림 | 기존(M3_7) | 작업·수령함 이전 |
| N20·4·25·M3_8[N] | Otto[몸] | Please match the old maker's marks. | 조사: 폐허 안전 고리 부품 도장2 대조 | Otto→폐허 안전 입구 도장→Otto | —; 다른 진영 표식의 연결 홈이 맞음 | 기존(M3_8) | 유지 |
| N21·4·25·TR25_N | Otto[몸] | Pass the hunt, then make the worksite usable. | 시험: §7 Lv25 사냥→S 난간 수리 / A 냉각병 제작·사용 / T 간식으로 기존 아기 안전 안내1→귀환 | Otto→폐허 시험터→안전 작업 자리→Otto | 공용 표식/내 서명; 손본 자리 꼬리표 변경 | 3번 스킬, 추가 급여0 | 유지 |
| N22·4·27·N4_1 | Otto[몸] | Please gather the parts on this old receipt. | 채집: 폐허 안전 고리 의뢰 부품2→주문 보관 | Otto→폐허 부품함2곳→Otto | 작은/큰 쟁반; 부품 실루엣이 한 장치로 보임 | 주문급여 | 유지 |
| N23·4·30·N4_2 | Otto[몸] | Please test how these odd pieces work together. | 수리: S 홈 맞춤 / A 반응 순서 / T 간식 냄새 길로 아기 안내→기록함 개방 | Otto→폐허 안전 시험대→기록함→Otto | 내 도장/공용 도장; 수리 흔적에 선택한 도장 남음 | G·기록 | 유지 |
| N24·4·32·N4_4 | Tiny[몸] | Please put both orders on our display. | 전시: 두 원본 조립→공용 기록대/내 주문함 | Tiny→교차로 기록대/작업대→Tiny | 원본 나란히/내 주문 앞에; Tiny가 뒤쪽 보려고 몸을 기울임 | GX | 접수·전시 이전 |
| N25·5·33·N5_1 | Otto[몸] | Please make a cool cradle for the shard. | 제작: S 받침 / A 냉각병 / T 운반 간식1→완성 확인 | Otto→교차로 직업 작업대→주문 보관함 | 둥근/네모 꼬리표; 운반품 표시 차이 | 주문급여 | 작업만 이전 |
| N26·5·34·N5_2 | Pip[몸 필요] | Please deliver the cradle to our shaky stand. | 배달: 완성품 폐허 안전대로 운반→직업품 실제 사용 | Pip→폐허 안전 운반대→받침→Pip | 먼저 받침/먼저 냉각; 최종 모두 완료, 중간 동작 차이 | G | 유지 |
| N27·5·35·N5_3 | Tiny[몸] | Please choose who can use our finished light. | 설치: 공용 분수 옆/교차로 내 작업대에 식은 조각 장착 | Tiny→Fountain 옆 공용대/개인 작업대→Tiny | 주민이 모여 씀/내 도구만 빛; Tiny가 큰 도구 그림자와 인사 | GX·기록 | 개인 작업대만 이전 |

의뢰 지급 재료·결과품은 거래·판매 불가인 주문 보관함에 둔다. 개인 가방을 막지 않으며 돈을 다 쓴 초보도 필수 주문을 재시도할 수 있다. 기존 일반 제작의 원가·숙련·레시피 조건은 유지한다. 옛 N02 준비는 N03 행에 묶인 N0의 Lv3 단계이며 별도 재료 보상·재수락 파밍이 아니다.

첫 스킬 실전1회는 채택된 학습 목표를 유지한다. 다만 빛은 움직이는 수레 방어, 뿔은 위치·줄 조작으로 유인, 장인은 직업 받침 조립 후 작업장 확보다. 미끼·받침 단계를 생략하고 세 편 모두 같은 몬스터2 적중으로 끝내는 구현은 통과시키지 않는다.

## 7. 처음부터 만나는 스승과 Lv5·15·25 시험

스승 몸은 첫 접속부터 고정 배치한다. 빛 Gleam(글림 경)·뿔 Rose는 각 마을 출구와 기존 초반 동선이 만나는 곳, Otto는 교차로 Forge다. 스킬 레벨이 됐다고 갑자기 생성하거나 원격 분신을 만들지 않는다. Hallie·Magpie·Kit도 실제 안내자 몸·G 상호작용·Guide 앵커가 필요하다. 구현 전 글 알림으로 대체하지 않는다.

| 관계 시점 | 빛 | 뿔 | 장인 | 필수성·보이는 변화 |
|---|---|---|---|---|
| Lv1~2 첫 만남 | H00→H00a | R00→R00a | N00→N00a | 안내자 소개·기본 공격 시범, 무기 방문과 한 방향 동선. 빛/뿔은 스승의 연습 도구, 장인은 Forge에서 받은 내 도구로 수행 |
| Lv2~4 작은 부탁 | HS01 손수건→Bright의 HS02 | RS01 단추→Rex의 RS02 | NS01 바퀴→Kit의 NS02 | 선택. 이미 갈 길의 물건1·전달1, 새 사냥 없음. 스승은 다음 방문에 그 물건을 알아봄 |
| Lv5 첫 시험 | H03 | R03 | N03 | 첫 시범과 별개 수락, Slime4+도움1. 시범 거절자는 같은 자리에서 다시 제안, 거절해도 시험 자격 유지 |
| Lv5~10 첫 배움 이후 | H04 등불 뒤 짧은 경례 | R04 등불 뒤 같은 포즈 | N04 뒤 도구 점검 몸짓 | 별도 퀘스트·보상0. 다음 스승 대화에 짧은 말풍선1, 화면 팝업0 |
| Lv13~15 중간 확인 | H15a→H16 | R15a→R16 | N16a→N17 | 숲에서 한 일을 모형으로 재현한 뒤 Lv15 시험. 이미 배운 기술만 사용 |
| Lv20 옛 부탁의 회수 | HS01⇢H17a | RS01⇢R17a | NS01⇢N18a | 초반 호의를 기억한 물건·인사. 초반 지선 미완이어도 본편은 보통 물건으로 진행 |
| Lv25 세 번째 시험 | H19→H20 | R19→R20 | N20→N21 | 폐허 앞 스승에게 보고·시험; 새 스승 등장 없음 |
| Lv35 결말 이후 | Gleam이 손수건 매듭 확인 | Rose가 거꾸로 경례 | Otto가 오래된 바퀴 도장 확인 | 기존 결말의 귀환 반응, 새 필수 왕복·추가 의뢰 수0 |

시범은 플레이어와 같은 직업의 기본 공격 동작을 안전 연습대에 1회 보여 준다. 빛/뿔은 스승 옆에서 기존 T1 외형의 연습 도구를 잠깐 빌려 치고 반납한 뒤 Otto로 간다. 연습 도구는 가방·거래·판매·필드 전투에 쓰지 못하며 중단하면 즉시 회수한다. Otto 방문 뒤 시범 때문에 고향에 돌아가는 길은 없다. 장인은 첫 무기를 받자마자 같은 Forge에서 수행한다. 스승 정체성·장비를 교체하는 연출이 아니라 직업별 연습 도구를 잠깐 든다. 회피 기능을 새로 만들거나 가르치지 않는다. 문장 튜토리얼·타이밍 설명창 없이 몸짓→실제 한 번 적중→스승 끄덕임으로 끝낸다. 입력은 기존 기본 공격, 길게 눌러 연속 공격하도록 가르치지 않는다.


9개 시험의 부탁자·Offer·Guide·선택·보상은 H03/H16/H20, R03/R16/R20, N03/N17/N21에 모두 적었다. 아래는 그 행들의 **사냥 단계 공통 사양**이며 새 의뢰가 아니다.

| 레벨 | 사냥 목표 | 빛 도움1 | 뿔 도움1 | 장인 도움1 |
|---|---|---|---|---|
| 5 확정 | 모든 직업 BasicKill Slime4 | 떨어진 주민 짐 회수·전달 | Tiny에게 간식 장난 소포 전달 | 자기 N0계열 제작품으로 실제 도움 |
| 15 제안 | Warrior/Smith: BasicKill Goblin4; Mage/Alch: 첫 스킬로 Goblin2 동시 적중2회; Archer/Tame: 기존 거리 판정 Goblin4 | 짐 든 Pip 짧은 호위 | Pip에게 명령해 장난 표지 정리 | S 수레 축 수리 / A AP1 제작·HP1 전달 / T T1 제작·간식으로 아기 따라오기 |
| 25 제안 | Warrior/Smith/Mage/Alch: 이미 배운 2번 스킬로 Skeleton2 동시 적중2회; Archer/Tame: 기존 거리 판정 Skeleton4 | 적재 경사로 지키기 | 빈 경비 수레 미끼 유인 | S 난간 수리 / A 냉각병 제작·사용 / T 간식으로 기존 아기 안전 안내 |

Lv15/25 수량은 제안이다. 기존 `Skills.Tasks`를 시험의 사냥으로 합치고 별도 숨은 횟수를 남기지 않는다. 기존 내부 슬롯 순서 Q/Z/X와 실제 키 표시는 분리한다. 아직 배우지 않은 슬롯은 시험에 요구하지 않는다. 2·3번 기능이 꺼져 있으면 해당 시험을 노출하지 않고, 주선은 이전 기술로 진행한다. 나중에 열려도 기존에 배운 기술은 회수하지 않는다.

도움은 보상1건으로 센다. 여러 제작·전달 클릭을 도움 여러 건으로 늘리지 않는다. 스승 귀환·거리 검사 후 배움 신호를 보낸다. 실패·재접속 때 완료된 사냥과 도움은 유지한다. 스승 반응은 짧게: Gleam `“My bag is bigger than my shield!”`, Rose `“That ribbon was meant for you!”`, Otto `“It works, and my eyebrows survived!”`.

## 8. 마을별 선택 의뢰 — 각 12개

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

### 추가 마을 지선 24개 — 기존 각 4개와 합쳐 각 12개

아래 모든 행도 **현장 NPC 부탁 → Accept / Decline → Guide → 현장 인계**다. `선행`은 완료가 필요한 화살표, `없음`은 레벨·진영만 요구한다. 끝에 수령 NPC 이름이 나오면 그곳에서 완료하며 처음 부탁자에게 불필요하게 돌아가지 않는다. 각 수령 NPC는 답장 한마디 뒤 **자기 새 부탁을 별도로 제안**한다. 새 지선에서 `나눔/내 자랑` 선택은 기존 선악 체계의 개인 기록으로 남기되 수치·전투 보상 차이는 새로 확정하지 않는다.

| ID·Lv·선행→열림 | 부탁자·짧은 부탁(한국어 집필안) | 유형·목표·Guide | 선택·웃음·보이는 결과 | 보상 |
|---|---|---|---|---|
| HS01·3·H00a→HS02, ⇢H17a | Gleam: 이 손수건을 브라이트에게 전해 줘. | 배달1: Gleam→고향 출구 손수건→Bright | 남의 짐 덮기/내 깃발; 작은 천이 큰 짐의 모자처럼 됨 | G·호의 기록 |
| HS02·4·HS01→HS03 | Bright: 오토에게 내 구겨진 리본도 보여 줄래? | 배달1: Bright→첫 Forge 길→Otto | 공용 포장/내 표식; 펴니 리본이 내 키보다 김 | G |
| HS03·7·HS02→HS04 | Otto: 리본 끝을 못 떼겠어. 슬라임 접착 표본이 필요해. | 사냥·수집: Otto→초원 Slime5→확정 표본3→Bright | 함께 쓸 접착/내 포장; 장갑 둘이 붙어 큰 박수 | GX |
| HS04·9·HS03→W05 재료 이야기 | Bright: 붙어 버린 초대장을 로즈에게 전해 줘. | 전달·분리: Bright→교차로 안전 접수→Rose→초대장 가장자리 떼기 | 모두 초대/내 이름 크게; 둘의 이름이 반씩 붙음 | G·기록 |
| HS05·16·H3→HS06 | Folk1[주민]: 고양이 침대를 누가 북으로 썼나 봐. | 수집: Folk1→숲 Goblin4→확정 천 조각3→Folk1 | 고양이 침대/내 구조 쿠션; 고양이는 빈 상자를 고름 | GX |
| HS06·20·HS05→W04의 선택 후일담 | Gleam: 그 빈 상자를 작은 수레에 실어 줘. | 적재: Gleam→고향 빈 상자→교차로 Pip | 여러 짐/내 표식; 고양이 대신 스승 모자가 올라탐 | G |
| HS07·27·H6→HS08 | Bright: 해골이 가져간 명판 받침을 찾아 줘. | 사냥·회수: Bright→폐허 Skeleton5→확정 받침2→Bright | 이름 나란히/내 이름 앞; 받침 둘이 짝짝 악기처럼 부딪힘 | GX |
| HS08·31·HS07→W06 | Folk1[주민]: 이 삐뚤어진 안내 화살표를 바로 세워 줘. | 조립: Folk1→고향 안내판의 방향 홈2→Folk1 | 남들 길/내 전시 길; 전에는 자기 발을 가리켰음 | G·기록 |
| RS01·3·R00a→RS02, ⇢R17a | Rose: 내 대장 단추를 렉스에게 돌려줘. | 회수·전달1: Rose→출구 단추→Rex[몸 필요] | 같이 경례/나부터; Rex가 일부러 거꾸로 달고 둘 다 웃음 | G·호의 기록 |
| RS02·4·RS01→RS03 | Rex: 오토에게 소리 없는 종을 부탁해 줘. | 배달1: Rex→첫 Forge 길→Otto | 공동 연습/내 등장; 종 모양 그림만 아주 크게 그림 | G |
| RS03·7·RS02→RS04 | Otto: 슬라임 표본으로 종을 조용하게 만들자. | 사냥·수집: Otto→초원 Slime5→확정 말랑 표본3→Rex | 조용한 공동 연습/몰래 내 등장; 종은 조용한데 내 신발이 삑 | GX |
| RS04·9·RS03→W05 재료 이야기 | Rex: 브라이트에게 무음 공연 초대장을 가져가. | 전달·시연: Rex→교차로 안전 접수→Bright→손짓 인사1 | 다 같이/내 독무대; 박수도 손짓이라 모두 잠깐 멈칫 | G·기록 |
| RS05·16·R3→RS06 | Rex: 고블린들이 내 연습 영수증을 모자처럼 써! | 사냥·수집: Rex→숲 Goblin4→확정 종이 영수증3→Rex | 공동 기록/내 대장 증서; 모두 내 모자 그림임 | GX |
| RS06·20·RS05→W04의 선택 후일담 | Rose: 핍에게 내 조용한 행진을 보여 줘. | 지휘: Rose→교차로 Pip→안전 발판 순서2 | 동료 먼저/나부터; 내 발판만 삑 소리 | G |
| RS07·27·R7→RS08 | Rose: 해골이 굴리는 빈 깡통으로 북을 만들자. | 사냥·회수: Rose→폐허 Skeleton5→확정 빈 깡통2→Rex | 합주/내 독주; 가장 큰 통에서 가장 작은 소리 | GX |
| RS08·31·RS07→W06 | Rex: 내 대장 의자가 뒤를 보고 있어. | 조립: Rex→고향 의자 발 홈2→Rex | 원형 좌석/내 앞자리; 먼저 앉으면 벽에게 인사 | G·기록 |
| NS01·3·N00a→NS02, ⇢N18a | Otto: 킷의 작은 바퀴를 함께 고치자. | 수리1: Otto→Forge 바퀴 홈→Kit[몸 필요] | 공용 수레/내 도장; 작은 바퀴에 큰 승인 도장 | G·호의 기록 |
| NS02·4·NS01→NS03 | Kit: 타이니에게 포장 크기를 물어봐 줘. | 측정·전달1: Kit→현재 장인 접수대 포장틀→Tiny | 나눔 꾸러미/내 상표; 가장 작은 상자에 가장 긴 주문서 | G |
| NS03·7·NS02→NS04 | Tiny: 슬라임 표본으로 새는 포장 틈을 막아 줘. | 사냥·수집: Tiny→초원 Slime5→확정 밀봉 표본3→Otto | 공동 밀봉/내 도장; 완성 뒤 빈 상자가 통통 튐 | GX |
| NS04·9·NS03→W05 재료 이야기 | Otto: 두 아이에게 똑같은 상자를 배달해 줘. | 배송: Otto→안전 접수 Bright→Rose | 같은 포장/내 상표; 서로 선물할 상자를 바꿔 들고 돌아옴 | 주문급여·기록 |
| NS05·16·NA1→NS06 | Kit: 고블린이 굴린 수레에서 나사가 빠졌어. | 사냥·수집: Kit→숲 Goblin4→확정 나사3→Otto | 공용 공구/내 도장; 마지막 나사가 오토 모자에 걸림 | GX |
| NS06·20·NS05→W04의 선택 후일담 | Otto: 핍에게 맞는 나사 상자를 가져가 줘. | 분류·배달: Otto→작업대 크기 홈2→교차로 Pip | 급한 수레/내 서명; 큰 상자에 작은 나사 하나 | 주문급여 |
| NS07·27·NA3→NS08 | Kit: 해골 옆에서 달그락거리는 빈 통이 필요해. | 사냥·회수: Kit→폐허 Skeleton5→확정 빈 통2→Otto | 공용 공구함/내 진열; 통보다 뚜껑 손잡이가 큼 | GX |
| NS08·31·NS07→W06 | Otto: 새 공구함의 잠금이 거꾸로야. | 수리: Otto→작업대 안전 잠금 홈2→Kit | 함께 쓰기/내 도장; 열었더니 뚜껑에 공구 그림만 있음 | 주문급여·기록 |

NS01~08은 현재 교차로 장인 접수대·작업대에서 진행한다. 완공 뒤 Kit 접수·작업·수령함만 장인 마을로 이전하고 Otto·Tiny·현장 배송은 기존 위치를 유지한다. 수집품은 해당 몬스터를 수락 뒤 유효 처치하면 지정 횟수 안에 확정 지급한다. 신체 부위 수집·희귀 드롭 운 요구0. 같은 편 안에서 슬라임→고블린→해골 장난의 이유가 이어지며, 사냥 사이에 실제 배송·조립을 둔다.

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

아래 공통 지선은 편의 기능·기존 개인 사건이다. 각 진영 본편 30개에는 합산하지 않고 공통 20개 풀에만 센다. 주선에 추가 사냥을 강제하지 않는다.

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

### 공통 지역 의뢰 7개 — 위 성장8·행사5와 합쳐 20개

공통 의뢰는 진영 가입이나 PvP를 요구하지 않는다. 민간 배송 접수는 전투·진영 경계 바깥에서 안전하게 만들되 전역 PvP 규칙을 바꾸지 않는다. 길이 준비되지 않으면 해당 선택 의뢰만 숨긴다. 타 진영 전용 스승 시험·상점 권한이 열리는 것은 아니다. 대체 수령인 없이 한 NPC 몸을 같은 순간 두 곳에 만들지 않는다.

| ID·Lv·선행→열림 | 부탁자·짧은 부탁 | 유형·목표·Guide | 선택·웃음·실물 결과 | 보상 |
|---|---|---|---|---|
| C01·6·Lunch1→C02 | Tiny: 내 도시락 뚜껑을 오토에게 보여 줘. | 배달: 교차로 Tiny→Otto Forge, 빈 도시락1 인계 | 같이 고치기/내 서명; 뚜껑이 너무 커 오토 모자가 됨 | G·기록 |
| C02·7·C01→C03 | Otto: 브라이트에게 리본 길이를 재 달라고 해 줘. | 측정·배송: Otto→빛 민간 접수 Bright→주어진 리본 홈 맞춤 | 같은 길이/내 매듭; 늘어뜨린 리본이 내 발에 닿음 | G |
| C03·8·C02→C04 | Bright: 로즈에게 이 리본과 답장을 전해 줘. | 전달·답장: Bright→뿔 민간 접수 Rose | 나란히 이름/내 배달 도장; Rose 답장은 종이가 아니라 접힌 모자 | G·기록 |
| C04·9·C03→C05 | Rose: 킷에게 모자가 아니라 포장이라고 전해 줘. | 배송·조립: Rose→장인 접수 Kit→포장 접기1→Tiny | 모두의 선물/내 걸작; 접었더니 모자가 하나 더 나옴 | 주문급여·기록 |
| C05·12·C04→W05 | Kit: 숲에서 주문표를 되찾고 핍에게 전해 줘. | 사냥·수집: Kit→숲 Goblin4→확정 주문표3→Pip | 공동 명단/내 이름 먼저; 표 세 장을 펴니 거대한 모자 도면 | GX·기록 |
| C06·18·없음→W06 | Pip: 우두머리가 굴리는 빈 북을 멈춰 줘. | 전투·수리: 숲 Pip→기존 GoblinBrute1 유효 처치→빈 북 걸쇠 고정→Pip | 마을 합주/내 북; 때리려니 북이 의자로 접힘 | GX |
| C07·28·C06→W06 | Pip: 해골 곁의 빈 통으로 기록함을 받쳐 줘. | 수집·설치: Pip→폐허 Skeleton4→확정 빈 통2→안전 기록대→Pip | 공용 기록/내 전시; 통을 세우자 전에 만든 북과 같은 도장 | GX·기록 |

Slime·Goblin·Skeleton은 각 편 마을 수집 3단계, GoblinBrute는 C06에 각각 농담과 후속 사용처가 있다. BigSlime/Slime Prince는 첫 팔찌·선택 XR1, King Slime·Clatter는 기존 펫 획득 경로다. 새로운 몬스터 종이나 보스 대기 의무는 추가하지 않는다.

### 퀘스트 연결 지도

`→`는 왼쪽 완료 뒤 오른쪽 NPC에게 새 부탁이 열림, `+`는 모두 완료, `또는`은 하나면 됨, `⇢`는 선택 기록에 따른 훗날 연출이다. 화살표 끝에서 **자동 수락하지 않는다**. 모든 행은 별도 Accept / Decline. 레벨 조건도 함께 충족해야 한다. 아래는 새로운 의뢰를 더 세는 목록이 아니라 위아래 표의 연결 지도다.

| 연결망·레벨 | 선행 → 해금 / 늦은 보답 |
|---|---|
| 빛 스승·Lv1~35 | Hallie → H00의 Gleam 방문 중 H00a 기본 공격 → Otto 무기로 H00 완료; H00a → HS01(Lv3) → HS02 Otto → HS03 표본 → HS04 Rose; HS01 ⇢ H17a(Lv20) → 결말의 Gleam 인사 |
| 뿔 스승·Lv1~35 | Magpie → R00의 Rose 방문 중 R00a 기본 공격 → Otto 무기로 R00 완료; R00a → RS01(Lv3) → RS02 Otto → RS03 표본 → RS04 Bright; RS01 ⇢ R17a(Lv20) → 결말의 Rose 경례 |
| 장인 스승·Lv1~35 | Kit → N00 Otto 무기·스승 → N00a 기본 공격 → NS01(Lv3) → NS02 Tiny → NS03 표본 → NS04 두 마을; NS01 ⇢ N18a(Lv20) → 결말의 Otto 도장 |
| 세 편 스승 시험 | H03/R03/N03(Lv5) → 각 편 등불·숲 → H15a/R15a/N16a(Lv13) → H16/R16/N17(Lv15) → H20/R20/N21(Lv25); 꺼진 스킬 시험은 본편에서 우회 |
| 고양이가 고른 집·빛 | H2 등불 + H3 고양이 + H6 명판 → W01(Lv22) → 기존 Halo Chick 수령 장면 |
| 조용한 대장·뿔 | R5 모자 + R3 삑삑 상자 + R7 좌석 → W02(Lv22) → 기존 Horns Bat 수령 장면 |
| 버려진 부품의 자리·장인 | N0b 판매 + N2 주문 제작 + N4 실제 납품 → W03(Lv10+) → 기존 Gear Mouse 수령 장면 |
| 오래된 물건·각 편 | HS01 + H17a, 또는 RS01 + R17a, 또는 NS01 + N18a → W04(Lv20) → 칭호 제안 ‘Old Friend’; 다른 편 완료는 필요 없음 |
| 세 마을 포장 소동 | Lunch1 → C01 Tiny→Otto → C02 Bright → C03 Rose → C04 Kit→Tiny → C05 Pip(Lv12); C04 + C05 → W05 → 장식 제안 ‘Parcel Ribbon’ |
| 빛 수집 후일담 | H3 → HS05 Goblin 천 → HS06 Pip; H6 → HS07 Skeleton 받침 → HS08 안내판 |
| 뿔 수집 후일담 | R3 → RS05 Goblin 영수증 → RS06 Pip; R7 → RS07 Skeleton 깡통 → RS08 의자 |
| 장인 수집 후일담 | NA1 → NS05 Goblin 나사 → NS06 Pip; NA3 → NS07 Skeleton 통 → NS08 공구함 |
| 숲에서 폐허까지 | C06 Brute 북 → C07 Skeleton 기록대; C06 + C07 + (HS08 또는 RS08 또는 NS08) → W06(Lv31) → 칭호 제안 ‘Odd Jobs Hero’ |
| 반가운 재방문 | HS03→DH1, H3→DH2, H6→DH3 / RS03→DR1, R3→DR2, R7→DR3 / NS03→DN1, NA1→DN2, NA3→DN3 / C04→DC1, C06→DC2, C07→DC3 |

W01~03은 기존 펫 조건을 **더 늘리는 잠금이 아니다**. 기존 조건을 충족하면 펫 자격은 즉시 유지하며, W 완료 전에도 기존 수령 경로를 쓸 수 있다. 이미 펫을 받은 사람은 같은 장면만 보고 두 번째 펫·급여를 받지 않는다. 펫 소유를 W 수락 조건으로 쓰지 않는다.

### 연결망 마지막 의뢰 6개

칭호·꾸미기 3개는 새 제안이며 능력치·새 재화·유료화가 없다. 구현·승인 전 보상 버튼이나 약속을 노출하지 않는다. 기존 펫은 기존 원장과 한 번만 지급한다. 일반 G 급여와 펫 수령을 분리하고 과거 완료자는 미지급분만 받는다.

| ID·Lv·조건 | 부탁자·짧은 부탁 | 유형·목표·Guide | 선택·눈에 보이는 마무리 | 보상 |
|---|---|---|---|---|
| W01·22·H2+H3+H6 | Gleam: 친구들이 쉬어 갈 자리를 같이 만들어 줘. | 설치: Gleam→고향 등불 옆 빈 상자·명판 조립→Bright | 공용 쉼터/내 구조 표식; 고양이는 상자, 병아리는 명판 아래 | G·기존 HaloChick 수령 연출(조건 추가0) |
| W02·22·R5+R3+R7 | Rose: 조용한 공연의 마지막 자리를 정해 줘. | 배치: Rose→고향 좌석에 빈 모자·상자 배치→Rex | 원형/내 대장석; 박쥐가 거꾸로 매달려 모두 같은 자세 | G·기존 HornsBat 수령 연출(조건 추가0) |
| W03·10·N0b+N2+N4 | Otto: 남은 부품으로 작은 손님 자리를 만들자. | 조립: Otto→현재 장인 작업대 부품홈2→Kit | 공용 작업대/내 도장; 톱니 쥐가 큰 도장을 굴림 | 주문급여·기존 GearMouse 수령 연출(조건 추가0) |
| W04·20·각 편 호의+회수 의뢰 | 자기 스승: 그때 그 물건을 같이 걸어 두자. | 전시: Gleam/Rose/Otto→자기 연습대 옛 물건 걸이→같은 스승 | 함께 이름/내 이름; 스승이 기억한 손수건·단추·바퀴, 미완 초반 호의는 수락 불가 | G·칭호 Old Friend(제안) |
| W05·12·C04+C05 | Tiny: 모두의 답장을 한 상자에 넣어 줘. | 조립·배달: Tiny→교차로 상자에 세 거점 답장→Kit→Tiny | 공동 선물/내 포장 도장; 최종 상자 안에는 서로에게 준 작은 모자들 | G·장식 Parcel Ribbon(제안) |
| W06·31·C06+C07+자기 마을 08 | Pip: 오래된 물건들이 어디 쓰였는지 보여 주자. | 설치: 폐허 안전 Pip→북·통·도장 모형의 홈 맞춤→Pip | 공용 기록/내 전시; 첫 북이 받침, 통이 보관함으로 이어짐 | GX·칭호 Odd Jobs Hero(제안) |

### 작은 일일·반복 부탁 12종

각 마을 3종 + 공용 3종이다. 게시판 자동 배정 없이 해당 NPC가 직접 제안한다. 일일은 기존 날짜 기준으로 하루1회, 반복은 완료 뒤 다시 부탁을 받아야 한다. 날짜 기준·보상 제한은 서버 공통 정책으로 구현하고 계정·진영 변경으로 초기화하지 않는다. 일일 미접속 손해·연속 출석 보상·새 돈·랭킹을 붙이지 않는다. 2~4분 안에 끝낼 작은 목표이며 주선·스킬·웹·펫의 조건이 아니다.

| ID·종류·개방 | 부탁자·짧은 부탁 | 유형·목표·Guide | 선택·웃음 | 보상 |
|---|---|---|---|---|
| DH1·일일·HS03 | Bright: 오늘도 봉투가 벌어졌어. | 수집: Bright→Slime3 확정 표본2→Bright | 공용 봉투/내 도장; 내 장갑이 잠깐 붙음 | 일일 G |
| DH2·반복·H3 | Gleam: 고양이 경사로를 정리해 줘. | 정리: Gleam→고향 경사로 빈 상자2 이동→Folk1 | 고양이 길/내 구조 자리; 고양이는 옆에서 하품 | 반복 G |
| DH3·일일·H6 | Bright: 이름표 두 개가 바뀌었어. | 맞춤: Bright→고향 명판 그림2 맞춤→Bright | 같은 높이/내 이름 위; 내 표지가 잠깐 거꾸로 | 일일 G |
| DR1·일일·RS03 | Rex: 오늘 종은 너무 시끄러워. | 수집: Rex→Slime3 확정 완충 표본2→Rex | 공동 연습/내 독주; 신발만 삑 | 일일 G |
| DR2·반복·R3 | Rose: 빈 상자의 장난 순서를 골라 줘. | 장치: Rose→고향 안전 상자 손잡이2→Rose | 함께 웃기/내 등장; 내 모자가 한 칸 올라감 | 반복 G |
| DR3·일일·R7 | Rex: 손님 의자를 두 개만 옮겨 줘. | 지휘: Rex→고향 빈 좌석2→Rex | 원형/내 앞자리; Rex가 벽을 보고 경례 | 일일 G |
| DN1·일일·NS03 | Kit: 오늘 포장용 표본이 필요해. | 수집: Kit→Slime3 확정 밀봉 표본2→Otto | 공용 포장/내 상표; 빈 상자가 통통 | 일일 주문급여 |
| DN2·반복·NA1 | Otto: 이 빈 수레의 손잡이를 고쳐 줘. | 수리: Otto→현재 장인 작업대 손잡이 홈2→Kit | 함께 쓰기/내 서명; 수레보다 손잡이가 돋보임 | 반복 주문급여 |
| DN3·일일·NA3 | Tiny: 빈 간식 그릇을 맞는 자리에 놓아 줘. | 분류: Tiny→장인 안전 자리 그림 그릇2→Tiny | 공용 자리/내 훈련 자리; 아기가 빈 그릇을 보고 갸웃 | 일일 G |
| DC1·반복·C04 | Kit: 오토에게 빈 상자를 보내 줘. | 배송: 장인 접수 Kit→교차로 Otto | 공동 포장/내 도장; 상자 안에 더 작은 빈 상자 | 반복 G |
| DC2·일일·C06 | Pip: 고블린이 굴린 빈 통을 치워 줘. | 사냥·회수: 숲 Pip→Goblin3 확정 통2→Pip | 공동 길/내 표식; 두 통이 같은 소리 | 일일 GX |
| DC3·일일·C07 | Pip: 기록대 받침 두 개를 맞춰 줘. | 수리: 폐허 안전 Pip→기록대 홈2→Pip | 공동 기록/내 서명; 흔들리던 컵만 마지막에 딸깍 | 일일 G |

반복 급여는 같은 시간의 일반 사냥·제작 수익을 넘지 않는 예산으로 검수하며 첫 회 보너스 중복0이다. 지급 재료를 판매해 순환 이익을 내지 못한다. 보상용 카운트는 수락 뒤에만 증가하고 중복 완료·재접속·일자 경계에서도 한 번만 지급한다. 되풀이 대사는 짧게 바꾸되 새 의뢰 종류로 세지 않는다.

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

### v3 연결·저장 추가 계약

- H00a/R00a/N00a·체크인·회수·HS/RS/NS·C·W·D는 설명용 신규 ID다. 기존 ID 충돌 검사 뒤 최종 키를 정하며 옛 ID를 덮어쓰지 않는다. N02는 기존 N0 준비의 설명행만 합쳤으므로 기존 저장 삭제0.
- 본편 기본 선행은 각 편 표의 직전 본편이다. 초기 시범 거절·꺼진 스킬 시험은 명시적 우회이며 다음 본편 Offer를 막지 않는다. HS01/RS01/NS01은 시범 완료 뒤 선택 제안한다. 늦게 시범을 해도 초기 지선을 받는다.
- 웹 선행은 Done과 최소 레벨로 평가하고, 완료 시 NPC Offer만 연다. Accept가 없으면 Active·진행·급여를 만들지 않는다. 일괄 수락·로그인 자동 수락0.
- H17a/R17a/N18a의 기본 진행은 초반 호의에 잠기지 않는다. 늦게 초반 지선을 끝내면 스승에게 옛 물건 반응을 다시 보고 W04를 받을 수 있다. 본편 재완료·보상 재지급0.
- W01~03은 기존 PetUnlock 원장과 공통 지급 키를 쓴다. N0b+N2+N4 같은 기존 조건을 W 수락·완료로 바꿔 잠그지 않는다. W04~06은 별도 신규 보상 원장·외형/칭호 승인 전 비노출.
- 전달품은 소유자 귀속 주문 보관함·확정 수령 로그를 사용한다. 중간 NPC 답장도 별도 물건으로 이어지며 이전 단계 소모와 다음 단계 지급을 한 처리로 묶는다. 가방 가득 참·연결 끊김 때 자동 소실0.
- 모든 새 행은 선악 방향의 선택·개인 결과를 기록한다. 실제 점수는 기존 선택 대응을 검수한 뒤 중앙 설정에 넣고, 이름만 선/악인 가짜 보상·새 스탯은 만들지 않는다.
- 의뢰 동시 카운트는 같은 몬스터 조건이면 수락된 목표에 함께 인정 가능하나 서로 다른 의뢰품은 따로 귀속한다. 신규 의뢰·반복의 지급은 각 원장 한 번, 동일 기존 급여 슬롯 복사0.

### ID 처리표

| 기존 묶음 | v3 처리 | 보존할 것 |
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

- [ ] 모든 상세 행에 부탁자·짧은 부탁·Accept/Decline·단계별 Guide·실제 목표·결과·보상이 있다. 추가 행 한국어 집필안은 중앙 영어 원문과 최신 현지화 표로 옮기며 코드에 문장을 박지 않는다.
- [ ] `[몸 필요]` NPC와 새 물건 앵커가 없으면 의뢰를 열지 않는다. NPC가 없어서 거리 검사를 통과하는 우회가 없다.
- [ ] Guide 탭은 길 안내다. 원격 수락·납품·Learn을 대신하지 않는다. 새 장인 마을 좌표를 현재 목표로 쓰지 않는다.
- [ ] A23-191/199: 설명 카드·상단 파란 띠·튜토리얼 토스트·웹 해금 글 팝업을 복원하지 않는다. 부탁·결과는 짧은 NPC 말풍선과 물체 반응으로 보인다.
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
| 2 | 안내자·고정 스승·첫 시범·왕자·팔찌·도시락·Lv5 시험·등불 | Lv1~2 스승 만남, Lv5 약5분 목표 실측, 왕자1, 시험 사냥4+도움1, 첫 스킬 전 사용 요구0 |
| 3 | 2장 호위 / 선점·유인 / 포장·여과·주문 | 같은 소포·표본이라도 입력·목표·실패가 다름; 폰에서도 대상 구분 |
| 4 | Pip 몸·3장 세 편 숲 행동·Lv15 시험 | 공통 운반꾼/Brute 처치 체인 복사0, 개인 등불 저장 |
| 5 | 마을12개씩·공통20개·웹6개·반복12종·장인3직업 주문 | 분량표 대조, 선행 화살표 무순환·다른 편 완료 요구0, 기존 펫 조건·급여 보존 |
| 6 | Lv25 시험·폐허4장·Lv33~35 첫 결말 | 안전 고리에서 완주, 이벤트·상대 플레이어 없이 엔딩 |
| 7 | 1~5장 성장·이관·폰 최종 확인 | 실제 Lv35까지 동선·XP·반복 시간 기록; 부족분을 콘텐츠 완성으로 보고하지 않음 |

장인 마을 건설은 이 체인의 선행 조건이 아니다. 완공 뒤 §6·§8·§9 이전 열대로 접수·작업 앵커를 옮긴다. 6~7장 상세 제작은 §10의 측정 뒤 별도 결정한다.

### 검수할 실제 시나리오

| 범위 | 실제 확인 |
|---|---|
| 신규·성장 | 첫 안내자·스승이 실제 첫 접속에 존재, 시범 거절·나중 수락, 선택 지선0개 상태의 Lv5 약5분; 빛/뿔 전투3직업, 장인3직업; 보너스 없는 계정의 Lv5/10/15/25/35 시간과 XP 출처 |
| 분화 | 10분 이후 화면만 보고 진영을 구분 가능한지; 목표 이름을 가려도 행동이 다른지 |
| 의뢰 | 도시락 거절·늦은 수락, 사냥 전/후 수락, 호위 중 종료, 선점 실패·재시도, 재료0·골드0 |
| 저장 | M1_2 완료·미완, N0/N4 과거 지급, 구스킬 보유, Sub→Main 이관, 진영 변경·환생·장인 접수대 이전 |
| 월드 | NPC 생성 실패, 막힌 호위길, 타인 선점 충돌, 개인 물건 겹침, 안전 고리 경계, 폰 Guide |
| 연결망 | 3레벨 호의→20레벨 반응, 선행2~3개 모두/일부, 타 NPC 답장 뒤 새 부탁 거절, 펫 이미 보유, 장인 마을 전후 동일 기록, 반복 날짜 경계 |
| 엔딩 | 한 명 서버·행사 없음·왕관전 패배·중립 모두 Lv35 결말 가능; 전역 전쟁 종료 연출0 |

## 14. Claude가 먼저 비평할 쟁점

1. **범위:** 일회성 152개·반복12종의 모든 행을 확인한다. 실제 XP·이동·행동 분량은 별도로 측정한다. 많은 선택 의뢰를 전부 끝내야 레벨이 오르는 구조로 만들지 않는다.
2. **행동:** 호위·선점·지휘·제작을 같은 상호작용1회로 구현하면 v3 취지가 사라진다. 입력·실패·실물 결과까지 비교한다.
3. **웃음:** 장난의 피해자가 아이·동물로 읽히는 장면, 플레이어에게 설교하는 반응은 교체한다. 종이 왕관 같은 반복 농담도 실제 플레이에서 빈도를 조절한다.
4. **구현량:** 첫 구간에는 안내자 Hallie·Magpie·Kit와 고정 스승이 필요하고, 후속 연결망에는 Pip·Rex·주민 상호작용이 필요하다. 공용 행동 도구를 재사용하되 152개를 이름만 다른 처치로 채우지 않는다. 구현은 첫30분→마을 연결망→숲·폐허 순서로 작은 완성본을 만든다.
5. **장인:** 아직 없는 마을로 안내하는 줄이 없어야 한다. S/A/T 모두 실제 결과품이 쓰이는지, Craft 숙련 XP를 성장 XP로 오해하지 않았는지 본다.
6. **남은 판단:** 신규 행동·보상 계수·폐허 새 사건은 제안이다. 원래 왕관 파괴자·새 지역·후반 레벨 일정은 이 문서로 확정하지 않는다.

완료 기준은 세 편 모두 첫 부탁에서 폐허 첫 결말까지 이어지고, 플레이어가 “나는 무엇을 했고 무엇이 달라졌는지” 서로 다른 말로 설명할 수 있는가다.


## 15. Claude ↔ GPT 퀘스트 게임성 대화 (10/15, 사용자 "GPT랑 퀘스트 관련해서 게임성 관련해서 더 이야기 해줘")

### 1회차 (GPT 답)

**클로드의 큰 방향에 동의합니다. 풍성함은 “부탁이 많다”와 함께 “하는 일이 다르고, 내가 한 일이 마을에 남는다”에서 나와야 합니다.** [바이블 v3](C:/Users/glori/Documents/Roblox/Game/docs/design/quest_bible_2026-10-15.md)의 분량·수락 방식·연결망은 유지하는 제안입니다.

비용은 기존 자산 재사용 기준의 상대 추정입니다. **S**는 기존 기능 확장, **M**은 새 공용 기능, **L**은 이동·판정·동시 플레이까지 필요한 기능입니다. **P1**은 첫 30분, **P2**는 베타, **P3**는 이후입니다.

**1. 퀘스트 UX — 동의하되, 화면에 동시에 보이는 정보는 줄이겠습니다.**

| 제안·판정 | 플레이어가 보는 것·하는 일 / 이유 | 비용·우선 |
|---|---|---|
| NPC 머리 아이콘 — 동의 | 가능 `!`, 완료 `?`, 메인은 금색에 별 테두리까지 붙여 색 없이도 구별합니다. 같은 NPC에서는 완료 표시를 먼저 보여줍니다. | M·P1 |
| 고레벨 흐린 `!` — 제한 동의 | 가까이 왔을 때만 잠금·필요 레벨을 봅니다. 먼 곳까지 잠긴 의뢰가 가득하면 지금 할 일을 찾기 어렵습니다. | S·P2 |
| 로그 5개 탭 — 동의 | Main / Town / Shared / Daily / Webs로 찾습니다. Webs의 `2/3`을 누르면 **남은 부탁자와 길**을 봅니다. 카운트만으로는 부족합니다. | M·P2 |
| 제안 보상 미리보기 — 동의 | NPC 부탁 아래 아이콘·수량, 필요한 경우 짧은 이름을 봅니다. Accept / Decline은 바로 누릅니다. 아이콘만 보고 모를 보상은 눌러 확인합니다. | M·P1 |
| 납품 순간 — 강한 동의 | 서버가 완료를 확정하면 물건이 NPC 손으로 이동하고 NPC가 받거나 착용합니다. 보상 아이콘은 기존 가방·골드·스킬 칸으로 들어갑니다. 별도 완료 팝업은 없습니다. | M·P1 |

**2. 보상 — 골드 외 보상에 동의합니다. 다만 첫 30분부터 보상 체계를 전부 늘리지는 않겠습니다.**

| 제안·판정 | 플레이어가 보는 것·하는 일 / 이유 | 비용·우선 |
|---|---|---|
| 기존 아이템·첫 획득 — 동의 | 받은 무기를 바로 들고, 도시락 보상의 늘어난 가방 칸을 봅니다. 기존 보상부터 실제 사용까지 연결합니다. | S·P1 |
| 첫 완료 보너스 — 조건부 동의 | 반복 의뢰의 첫 회에만 별도 아이콘으로 예고합니다. 기존 첫 지급 슬롯을 재사용하고 보너스를 중복으로 얹지 않습니다. | M·P2 |
| 칭호·감정표현 — 동의 | 연결망을 끝내면 NPC에게 배운 인사나 칭호를 장착합니다. 이야기의 기념품이 됩니다. 신규 보상은 승인·구현 뒤 노출합니다. | M·P2 |
| 펫 간식 — 동의 | 기존 간식을 받아 펫에게 주면 펫이 반응합니다. 없는 펫을 먼저 얻어야 주선이 진행되는 조건은 만들지 않습니다. | S·P2 |
| 내 화면의 마을 장식 — 우선 추천 | 내가 고른 리본·명판이 남고, 재접속해도 같은 자리에 있습니다. “내가 해냈다”는 결과를 다시 볼 수 있습니다. | M·P1 |
| 마을 퀘스트 메달 — 수정 동의 | 로그에 마을 지선 `4/12`와 완성되는 문양을 보여줍니다. 소비하는 새 화폐가 아닌 완료 기록으로 둡니다. | S·P2 |
| 이름 색 — 보류 | 진영·위험 상태 표시와 충돌하기 쉽습니다. 별도 장식 표시와 구별할 수 있을 때 검토합니다. | M·P3 |

**3. 먼저 만들 공용 목표 여섯 종류 — 아래 순서입니다.**

여섯 종류를 모든 진영에 똑같이 배치하지는 않습니다. 빛은 보호, 뿔은 선점·장난, 장인은 제작·수리가 중심입니다.

| 순서·유형 | 플레이어가 보는 것·하는 일 | 재사용 가치·주의점 | 비용·우선 |
|---|---|---|---|
| ① 그림·모양 맞추기 | 소포의 매듭을 살펴 세 매듭 중 같은 것을 고릅니다. 틀리면 포장이 우스꽝스럽게 풀립니다. | 매듭·명판·부품·그릇에 재사용합니다. 색 외에 모양도 달라야 합니다. | M·P1 |
| ② 작업대 타이밍 | 망치가 넓은 표시 구간에 올 때 누르면 부품이 맞물리고 완성품이 움직입니다. | 제작·수리·포장에 씁니다. 모바일에서도 넉넉하게 성공하고, 실패해도 재료를 잃지 않습니다. | M·P1 |
| ③ 짧은 추격·가로채기 | 굴러가는 소포의 길을 보고 앞질러 잡습니다. 놓치면 강가 안전망에 걸리고 가까운 곳에서 재시도합니다. | 뿔의 선점·빛의 구조에 쓰되 목표와 반응을 다르게 합니다. 다른 플레이어가 뺏지 못합니다. | M·P1 |
| ④ 사건 있는 호위 | 수레를 따라가다 바퀴가 걸리면 뒤에서 밀고, 위협이 나타나면 지킵니다. | 빛 주선에 필요합니다. 첫 판은 짧은 고정 경로·사건 하나만 만들고, 막힘 복구까지 포함합니다. | L·P1 |
| ⑤ 단서 있는 숨바꼭질 | 상자 뒤 신발, 흔들리는 커튼을 보고 아이들을 찾습니다. 찾으면 아이가 다음 숨은 곳을 슬쩍 가리킵니다. | 관찰·실종품 조사에 재사용합니다. 단서 없이 마을 전체를 뒤지게 하지 않습니다. | M·P2 |
| ⑥ 시야를 피하는 잠입 | 경비의 시야 부채꼴을 보고 빈 상자 사이를 통과합니다. 들키면 내 모자만 튀고 직전 자리에서 다시 합니다. | 뿔의 행동 차이가 큽니다. 시야·폰 조작·서버 판정이 까다로워 추격 다음에 만듭니다. | L·P2 |

| 나머지 후보·판정 | 플레이어 경험 / 이유 | 비용·우선 |
|---|---|---|
| 장소에서 감정표현 — 동의 | 동상 앞에서 손을 흔들면 옆 NPC도 따라 합니다. 짧은 지선 단계로 좋지만, 독립 핵심 유형 여섯 개 중 하나로 세기에는 행동 폭이 작습니다. | S·P2 |
| 시간제한 채집 — 뒤로 | 제한 시간 안에 물건을 모읍니다. 기존 채집과의 차이가 주로 압박이라 우선도는 낮습니다. 길을 익힌 뒤 선택 도전으로 둡니다. | S·P3 |

**4. 진행 속도 — 동선 묶기와 추적 3개 상한에 동의합니다. 숫자는 실측 전 시작값입니다.**

| 제안 | 플레이어가 보는 것·하는 일 / 이유 | 비용·우선 |
|---|---|---|
| 거점당 메인 1개 + 선택 제안 1개 우선 | 다른 부탁도 찾아볼 수 있지만 처음부터 `!` 여섯 개로 둘러싸지 않습니다. 진행에 따라 다음 부탁이 드러납니다. | S·P1 |
| 같은 길에서 받고, 다음 NPC에게 전달 | 초원에서 회수한 짐을 숲 입구 주민에게 넘깁니다. 같은 구역 목표는 함께 수행하되 **각각 수락**합니다. 스승에게 배우는 의미 있는 귀환은 남깁니다. | M·P1 |
| 짧은 부탁 1~3분, 사건형 3~5분 | 이동·수락·납품까지 포함한 목표입니다. 첫 시범은 바이블의 15~20초, Lv5 약 5분·시험 5~8분 목표를 유지합니다. | S·P1 |
| 추적은 최대 3개, 길 안내는 1개 | 메인 1개와 직접 고정한 선택 2개를 봅니다. 폰에서는 선택한 목표만 펼칩니다. 수락 한도와 추적 한도는 구별합니다. | M·P1 |

**5. 사회성 — 함께 할 수 있게 하되, 혼자서도 끝나야 합니다.**

| 제안·판정 | 플레이어가 보는 것·하는 일 / 이유 | 비용·우선 |
|---|---|---|
| 파티 처치·회수 진행 공유 — 조건부 동의 | 같은 의뢰를 수락하고 근처에서 함께 수행한 친구의 목표도 오릅니다. 물건은 각자 귀속하고 실제 드롭·골드와 퀘스트 진행을 분리합니다. 기본 공격·스킬 시험은 본인이 해야 합니다. 기존 첫 타격 보상 규칙과의 검토가 먼저입니다. | L·P2 |
| 진영별 거울 장면 — 동의, 대사만 다르면 부족 | 같은 분수에서 빛은 등불에 가루를 넣고, 뿔은 자기 표식을 자랑하고, 장인은 받침을 맞춥니다. 서로 만나되 상대 진영 플레이어의 접속·협조를 완료 조건으로 요구하지 않습니다. | M·P2 |

**6. 일일 반복 — ‘3개 강제 일일 + 주간 웹 + 연속 출석’에는 반대합니다.**

| 제안·판정 | 플레이어가 보는 것·하는 일 / 이유 | 비용·우선 |
|---|---|---|
| 마을 부탁 3종 — 기존 틀에 동의 | 바이블의 마을별 **일일 2종·반복 1종**을 유지합니다. NPC에게 골라 받고, 하나만 해도 그 보상을 받습니다. 세 개 전부 완료를 요구하지 않습니다. | M·P2 |
| 주간 웹 — 반대 | 연결망 결말 6개는 일회성입니다. 매주 초기화하면 초반의 호의가 돌아오는 의미가 약해집니다. 별도 주간 콘텐츠는 베타 이용 패턴을 본 뒤 검토합니다. | L·P3 |
| 연속 출석 시각 보상 — 반대, 누적 기록 추천 | 바이블에 연속 출석 보상 금지가 명시돼 있습니다. 대신 완료한 부탁만큼 로그의 도장이 쌓이고, 쉬어도 지워지지 않게 합니다. | S·P2 |

**7. 11/7~10 시험 — 먼저 ‘첫 10분 한 바퀴’를 완성하겠습니다.**

| 순서 | 시험에서 플레이어가 경험할 것 | 비용·우선 |
|---|---|---|
| 반드시 유지 | 실제 NPC의 부탁 → 수락/거절 → 단계별 길 → 실제 행동 → 납품·반응·보상. 거절·재접속 후에도 이어집니다. | L·P1 |
| 0~5분 | 스승의 짧은 시범, 첫 무기, 왕자 1회, 팔찌 변화. 도시락은 같은 길에서 선택하고, 거절해도 Lv5 목표가 막히지 않습니다. | L·P1 |
| 5~10분 | 시험의 기본 공격 슬라임 4마리·도움 1회 → 스승에게 첫 스킬을 배움 → 가능한 동선에서 등불 선택 결과를 봅니다. | L·P1 |
| 10~30분 | 빛은 사건 하나 있는 호위, 뿔은 짧은 선점, 장인은 작업대 완성품을 경험합니다. 진영을 바꾸면 행동이 달라집니다. | L·P1 |

시간이 부족하면 **잠입 → 숨바꼭질 → 파티 공유 → 로그의 연결망 상세 화면 → 신규 치장 보상** 순으로 첫 시험 범위에서 뺍니다. 베타 분량을 삭제하는 결정은 아닙니다.

**줄이면 안 되는 것은 수락/거절, 길 안내, 실제 보상, 눈에 보이는 반응, 저장 복구입니다.** 호위를 납품 버튼 한 번으로 바꿔 완성 처리하기보다, 첫 시험에는 짧은 경로 하나를 제대로 내는 편이 낫습니다.

시험에서는 완료 개수보다 **첫 수락까지 시간, 길을 잃은 구간, 첫 스킬 습득 시간, 선택 지선을 자발적으로 받은 비율, 플레이 뒤 기억하는 장면**을 보겠습니다. 계측·관찰표는 **S·P1**입니다.

**제가 추가로 가장 추천하는 세 가지입니다.**

| 제안 | 플레이어가 보는 것·하는 일 / 이유 | 비용·우선 |
|---|---|---|
| 납품 뒤 바로 사용 | 오토에게 고친 바퀴를 주면 NPC가 끼우고 수레를 굴립니다. “완료했다”와 “도움이 됐다”를 한 장면으로 보여줍니다. | M·P1 |
| 다음 부탁의 원인을 눈앞에서 만들기 | 소포를 건네자 리본이 풀리고, 받은 NPC가 새 부탁을 합니다. 두 번째 부탁도 거절할 수 있습니다. 연결망이 메뉴 밖에서 시작됩니다. | M·P1 |
| 초반 물건을 재회 장면에 그대로 쓰기 | 3레벨에 건넨 손수건이 20레벨 수레의 깃발로 돌아옵니다. 처음 고른 색·매듭을 보존해 플레이어가 먼저 알아보게 합니다. 바이블의 재회를 더 강하게 만드는 방식입니다. | M·P2 |

**GPT가 Claude에게 묻는 것**

1. 첫 10분 시험에서 세 진영 각각 어떤 **한 장면**을 플레이어가 기억하면 성공이라고 볼까요?
2. 여섯 공용 목표 중 먼저 만들 네 가지를 **맞추기·작업대 타이밍·추격·짧은 호위**로 정하는 데 동의하나요? 다르다면 무엇을 바꾸겠나요?
3. 바이블대로 **일일 2종+반복 1종, 일회성 웹 6개, 연속 출석 보상 없음**을 유지하고, 재방문 동기는 NPC의 후속 부탁과 누적 기록으로 만드는 데 동의하나요?


### 2회차 (Claude 답 → GPT 정리: 퀘스트 체감 규칙 14줄 + P1 제작 순서)

# 퀘스트 체감 규칙 — 2차 합의안

기준: `docs/design/quest_bible_2026-10-15.md` §13 청크 2, Claude의 이번 답변. P1은 11/7~10 시험용 첫 30분이며, 첫 10분을 먼저 완성한다. 아래는 구현 체크리스트이고 구현 완료 보고가 아니다.

**남은 이견은 세 가지다.**

- 장소 감정표현을 다섯 번째 공용 행동 **S·P1**로 올리는 데 동의한다. 다만 기존 무료 동작을 쓰는 짧은 선택 단계로 두고, 다섯 행동 모두를 첫 10분에 강제하지 않는다.
- 빛의 기억 장면은 **필수 시험의 잃어버린 짐 반환**으로 보장한다. 선택 도시락을 거절해도 주민 인사와 등불 선택에 도달해야 한다. 10분은 실측 목표이며 연출 때문에 스킬 배움을 늦추지 않는다.
- **짧은 호위는 §13 청크 3**이다. P1에는 포함하되 청크 2 완료 뒤 붙인다. 장인 첫 장면에는 바퀴·약뿐 아니라 **조련사의 간식을 먹고 다가오는 아기 슬라임**도 필요하다.

**두 개발자가 지킬 퀘스트 체감 규칙 — 14줄**

1. 모든 부탁은 실제 NPC의 짧은 말 → 수락/거절 → 행동 → 납품·사용·보상으로 이어지고, 닫기·후속 해금은 자동 수락이 아니다.
2. 빛은 보호·돌려주기, 뿔은 선점·허풍, 장인은 제작·수리·사용으로 구분하며 대사만 바꾼 동일 행동을 세 편에 복사하지 않는다.
3. 빛의 첫 기억은 짐 반환 뒤 거리의 손인사와 내가 고른 등불의 빛이 후광에 닿는 장면이다.
4. 뿔의 첫 기억은 개인 팔찌를 먼저 챙기고 대장 자세를 잡자 종이 왕관이 내려앉고 Rose가 함께 웃는 장면이다.
5. 장인의 첫 기억은 내가 만든 바퀴가 굴러가거나, 약을 마신 Tiny가 뛰거나, 간식을 먹은 아기 슬라임이 다가오는 장면이다.
6. 선택 도시락·시범·지선은 거절해도 주선과 Lv5를 막지 않으며, 다음 방문에 다시 받을 수 있다.
7. 첫 시범 15~20초·Lv5 약 5분·첫 스킬 5~8분을 따로 측정하고, 시험은 수락 뒤 기본 공격 Slime4+도움1→스승 배움으로 지킨다.
8. 공용 행동은 모양 맞추기→작업대 타이밍→짧은 추격→짧은 호위 순으로 만들고, 장소 감정표현은 기존 동작으로 먼저 붙일 수 있다.
9. 맞추기는 색 없이 구분되고 타이밍은 폰에서도 넉넉하며, 실패는 재료 손실 없이 가까운 지점에서 재시도한다.
10. 웃음은 내 왕관·리본·허풍에 돌아오며, 아이·동물·다른 플레이어에게 피해를 주거나 남의 물건을 빼앗지 않는다.
11. NPC는 가능 `!`·완료 `?`·메인 금색+모양으로 표시하고 완료를 우선하며, 제안에는 실제 지급할 보상 아이콘·수량을 보인다.
12. 추적은 메인1+선택2까지, 길 안내는 선택 목표1개만 켜고, 거점에서는 메인1+선택 제안1을 우선 노출한다.
13. 서버가 행동·납품·지급을 확정한 뒤 물건 사용과 NPC 반응을 보이고, 개인 선택·의뢰품·보상은 재접속에도 보존하며 안내 팝업은 늘리지 않는다.
14. 재방문은 NPC 후속 부탁과 지워지지 않는 메달 도장으로 만들고, 마을별 일일2+반복1·일회성 웹을 유지하며 연속 출석 보상은 두지 않는다.

**P1 제작 순서와 크기**

S=기존 기능의 작은 확장, M=공용 기능 또는 여러 단계 연결, L=이동·복구·동시 플레이 검증이 필요한 묶음이며 상대 추정이다. **① 계약 → ②~⑦ 청크 2 완성 → ⑧ 청크 3 최소판 → ⑨ 통합 시험** 순이다. 같은 번호의 서버·클라이언트는 계약을 공유하며 붙인다.

**게임성 개발 2 — 서버**

| 순서 | 크기 | 만들 것·완료 조건 | 바이블 대응 |
|---|---|---|---|
| ① | M | 기존 청크 1을 점검하고 의뢰 ID·의미 단계·NPC/물건 앵커·보상 키·장면 키를 합의; 수락 상태·거리·소유자 검증과 중복 지급 차단을 공용화한다. | §13-1→2, §11 |
| ② | M | Hallie/Magpie/Kit→Gleam/Rose/Otto 소개·시범·첫 무기를 연결; 시범 거절/재수락, NPC 미생성 시 비노출, 기존 T1·150골드 1회를 확인한다. | §13-2, H/R/N00·00a |
| ③ | M | 왕자1→팔찌→T2·주문서와 선택 Lunch1을 연결; 수락 전 행동 소급0, 도시락 거절 시 주선 막힘0, 기존 지급 기록을 보존한다. | §13-2, H/R/N01·H/R02·Lunch1 |
| ④ | M | 모양 맞추기·작업대 타이밍을 공용 판정으로 구현; 정답/시도·거리·재료를 서버가 확인하고 실패 재시도에서 재료 손실·복제0을 확인한다. | §13-2 N03 준비, §13-3 재사용 |
| ⑤ | M | Lv5 시험 BasicKill4+진영별 도움1→고정 스승 Learn 연결; 장인 S/A/T 제작·납품·사용과 N0 급여를 구분하고, 미배운 스킬 요구0을 확인한다. | §13-2, H/R/N03·§7 |
| ⑥ | S | 기존 무료 감정표현을 지정 자리의 선택 단계에 연결; 수락·단계·거리·허용 동작을 검증하며 단순 근접으로 완료하지 않는다. | §13-2 연출 보조·이번 합의 |
| ⑦ | M | 납품 확정·직업품 사용·등불 선택을 개인 결과로 저장하고 장면 신호를 발행; 재접속 시 결과 복원, 장면 재생으로 보상 재지급0을 확인한다. | §13-2, H/R/N03~04·§11~12 |
| ⑧ | L | 짧은 추격 **M** 뒤 호위 **L**을 연결; 추격은 개인 소유·놓침 복구, 호위는 고정 경로1+사건1+막힘 복구·중도 종료 복구를 구현한다. | §13-3, 청크 2 뒤 P1 후속 |
| ⑨ | M | 신규/기존 저장·중복 요청·가방 가득 참·재접속·진영 변경을 검증; 첫 수락·Lv5·스킬 습득·지선 수락·실패/복구 시각을 기존 계측에 기록한다. | §13-2·3 완료 확인, §11·§13 검수표 |

**게임성 개발 1 — 클라이언트**

| 순서 | 크기 | 만들 것·완료 조건 | 바이블 대응 |
|---|---|---|---|
| ① | M | 서버 계약에 맞춰 NPC 제안·수락/거절·실제 보상 아이콘/수량을 기존 UIKit으로 연결; 글은 중앙 원문·현지화 표에 두고 미구현 보상은 숨긴다. | §13-1→2, §12 |
| ② | M | NPC 머리 `!/?`·메인 금색+모양·완료 우선 표시; 안내자→스승→첫 무기를 같은 동선으로 보여 주고 시범을 15~20초 안에 조작하게 한다. | §13-2, H/R/N00·00a |
| ③ | M | 추적 최대3·길1개, 폰은 선택 목표만 펼침; 단계 변경·납품·거절 뒤 안내를 갱신하고 Guide가 원격 수락/납품을 대신하지 않게 한다. | §13-2 전 구간, §12 |
| ④ | M | 모양 맞추기·작업대 타이밍의 PC/폰 입력과 즉시 반응을 구현; 넓은 성공 구간·색 외 단서·재시도 동작을 확인한다. | §13-2 N03, §13-3 재사용 |
| ⑤ | M | 왕자·팔찌·도시락·시험4+1·스승 배움을 단계별로 연결; 장인 S/A/T는 각 제작품과 실제 사용 대상을 보여 주고 제작 숙련과 캐릭터 XP를 구분한다. | §13-2, H/R/N01~03·§7 |
| ⑥ | S | 지정 자리에서 무료 감정표현을 바로 실행할 PC/폰 조작과 NPC 따라 하기를 붙이고, 서버 확인 뒤 목표를 완료 표시한다. | §13-2 연출 보조·이번 합의 |
| ⑦ | M | 서버 확정 뒤 전달→즉시 사용→NPC 반응을 연결; 빛 손인사·등불, 뿔 왕관·Rose 웃음, 장인 세 직업 결과를 만들고 개인 결과를 재접속에도 복원한다. | §13-2, H/R/N03~04·§12 |
| ⑧ | M | 추격 경로·놓침 후 재시도, 호위 사건·막힘 후 복구 상태를 읽히게 만들고 타인의 목표와 섞이지 않는지 확인한다. | §13-3, 청크 2 뒤 P1 후속 |
| ⑨ | M | PC/폰에서 세 진영·장인 세 직업을 실제 플레이로 확인; 길 잃은 지점·첫 스킬 시각·기억한 장면을 기록하고 새 설명 띠·토스트 없이 이해되는지 본다. | §13-2·3 완료 확인, §13 검수표 |

**청크 2 완료선:** 도시락·시범을 거절해도 첫 스킬까지 이어지고, 각 진영의 기억 장면과 개인 선택 결과가 실제로 보이며, 재접속 뒤 진행·물건·보상이 보존된다. 왕자1·시험4+1은 유지하고, 10분 도달 여부는 실측값으로 보고한다.

**P1 후속선:** 청크 3의 짧은 추격·호위를 붙여 첫 30분을 확인한다. 일일/반복 전체·웹·메달 화면은 §13 청크 5/P2이며, P1에서는 완료 기록과 후속 Offer 연결만 보존한다.
