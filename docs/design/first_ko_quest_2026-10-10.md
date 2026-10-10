# 첫 KO → 물약 사기 → 퀵슬롯 → King Slime 다시 — 퀘스트 설계 (게임성 개발 3, 2026-10-10)

A23-109(사용자 "퀵슬롯 퀘스트도 만들자")와 A23-110(사용자 "한 번 죽자 … 킹 슬라임을 잡자 … 한 방 맞고 죽으면 물약 사기 퀘스트")을 **한 묶음**으로. 줄로만 안내한다(팝업·팁 없음, D0 방식: 알림 없음, 보통 완료 줄). 검수가 보고 고친 뒤 구현한다.

## 한눈에
새 서브 **KO1 'The King's Hop'**(제목 안, `Config.StoryQuests.Defs.KO1`)이 첫 장 중간(M1_2 'Slime Princes' 뒤)에 저절로 줄로 생기고, 다섯 줄을 차례로 보여 준다.

| # | 줄 (Text) | 끝나는 때 | 이벤트 (누가 알림) |
|---|---|---|---|
| 1 | Defeat the King Slime | King의 착지 쿵 한 방으로 **내가 쓰러짐(첫 KO)** | `FirstKO` (개발 2: 개인 King·무손실 KO) |
| 2 | Buy a potion | 물약을 1개라도 삼 | `PotionBought` (ShopService.BuyPotion 성공 — 내가 한 줄 더함) |
| 3 | Put the potion in a quick slot | 퀵슬롯에 물약을 넣음 | `QuickSlotSet` (퀵슬롯 쪽 — 개발 1·2가 계약 결정 중) |
| 4 | Use the potion | 물약을 한 번 씀 | `PotionUsed` (VitalsService.UsePotion 성공 — 내가 한 줄 더함) |
| 5 | Defeat the King Slime | 이번엔 King을 **이김** (물약 2개로 이기는 숫자) | 기존 `Kill` (info.Kind = SlimeKing, 개인 King) |

보상(제안, 검수 결정): 사냥 2분어치 골드·XP + 강화 주문서(70%) 1장. 마무리 줄(`Finish`)은 두지 않는다(A23-99).

## 단계마다
1. **Defeat the King Slime** (안내: 초원) — `Start`는 이미 있는 King 등장 줄 "King Slime: Who's bothering my kids?!"을 재활용하지 않고 한 줄만: 퀘스트 시작 때 알림 없음(줄만). King이 어떻게 나오고(개인, 바로 옆), 어떻게 한 방에 쓰러뜨리고(착지 쿵), 어디서 일어나는지(무손실, 근처)는 개발 2. 끝나는 순간은 개발 2가 `StoryQuestService.Event(player, "FirstKO")`를 부름. 플레이어가 King을 먼저 쓰러뜨리는 건 설계상 불가(한 방이라서); 혹시 이기면 그 줄도 끝난 것으로 본다(`Kill SlimeKing` 첫 처치 = 다음 줄로).
2. **Buy a potion** (안내: 물약 상인 — 빛은 빛 마을 상인, 그 밖은 교차로 상인) — 이 줄이 시작되는 순간 **가진 골드가 물약 2개 값(25×2=50)보다 적으면 모자란 만큼 채운다**(그 단계 보상, 한 번만). 이미 물약이 있으면(스톡 > 0 또는 이번 저장에서 산 적 있음) 이 줄은 바로 끝난다.
3. **Put the potion in a quick slot** — 퀵슬롯에 넣은 적이 있으면(저장 `First.QuickSlot`) 바로 끝난다. 줄 눌렀을 때 안내 대상은 클라(개발 1)가 정함(퀵슬롯 칸).
4. **Use the potion** — 쓴 적이 있으면 끝. 쓸 때 HP가 가득이어도 쓴 걸로 센다(사용 성공 = 스톡이 줄어든 순간).
5. **Defeat the King Slime** — 다시 도전은 개발 2의 개인 King(이길 수 있는 숫자: 물약 2개로). 이기면 보상.

## 누구에게 / 언제
- **받는 사람:** 모든 진영. 첫 장(M1_2)을 끝낸 새 플레이어. `Requires = { Done = {"M1_2"}, Level ≤ 8, NoPotionYet }`.
- **건너뜀:** 레벨 9 이상, 물약을 이미 가졌거나 산 적 있는 저장(HP/MP 스톡 > 0 또는 `data.Story.First.PotionBought`), 이미 이 서브를 끝낸 저장. 그런 사람에게는 줄이 아예 안 생긴다(가볍게).
- **중간에 끼어들기:** 줄 1~2 사이에 이미 물약을 사면 2번 줄은 바로 지나간다; 퀵슬롯·사용도 같은 규칙(한 번이라도 했으면 지나감) → 사용자가 앞서가도 막히지 않는다.
- **KO가 안 일어나면:** King이 사라지거나 플레이어가 구역을 떠나도 1번 줄은 그대로(개발 2가 구역에 다시 들어오면 King을 다시 세움).

## 서버 구현 (내 몫)
- `StoryQuestService.Event(player, name, info)`: 이름 있는 일을 알림받는 공용 입구. `Obj = { Type = "Event", Name = ..., Count? }` 줄이 그 이름을 기다리고, 오면 한 칸 전진(줄 진행 저장·열린 줄만; 오래 전에 일어난 일은 `First.<이름>` 표로 건너뜀).
- 새 `Requires` 키: `MaxLevel`, `NoPotionYet`(HP/MP 스톡 0 이고 `First.PotionBought` 없음).
- 새 줄 필드 `TopUpGold = 50`: 그 줄로 들어갈 때 가진 골드(들고 있는 + 은행)가 이만큼이 안 되면 모자란 만큼 들고 있는 골드로 채움(출처 `Choice`처럼 2배 패스 안 탐).
- `ShopService.BuyPotion` 성공 → `Event(player, "PotionBought", { Kind, N })`, `VitalsService.UsePotion` 성공 → `Event(player, "PotionUsed", { Kind })` (한 줄씩, pcall).
- 저장은 `data.Story.First`(이미 있는 칸)에 `PotionBought`·`QuickSlot`·`PotionUsed`·`FirstKO` 표시만(추가 필드 없음, 데이터 버전 3 그대로).

## 약속 (각 담당)
| 누구 | 무엇 |
|---|---|
| 개발 2 | 개인 King(착지 쿵 한 방, 무손실 KO — 골드·아이템 안 잃음, 근처에서 일어남), KO가 나면 `S.StoryQuestService.Event(player, "FirstKO")`. 5번 줄 때 이길 수 있는 King 숫자(물약 2개). KO 퀘스트 id/단계는 `Config.FirstKO = { Quest = "KO1", Step = 1, RematchStep = 5 }`로 읽음. |
| 개발 1 | KO 화면(팁 없이 줄만), 줄 눌렀을 때 안내(상인·퀵슬롯 칸), 퀵슬롯에 넣음/씀 이벤트의 클라 쪽. |
| 퀵슬롯 소유(개발 1·2 합의) | 넣었을 때 서버가 `S.StoryQuestService.Event(player, "QuickSlotSet", { Slot, Kind })` 한 줄. |
| 개발 3(나) | 위 서버 구현 + 시험. |

## 숫자 (제안, 검수 결정)
- 물약 값 25(HP·MP 같음, `Config.Vitals.PotionPrices`), 채움 50(물약 2개).
- 보상 사냥 2분어치 + Enh70 1장.
- 시작: M1_2 뒤, Lv ≤ 8.

## 시험 계획
Event 입구(이름 틀림·남의 줄·두 번), 각 줄의 끝, 건너뛰기(물약 있음·레벨 높음·이미 끝남), 앞서가기(2~4번 줄이 이미 한 일), TopUpGold(모자랄 때만·한 번만·2배 패스 안 탐), 이벤트 신호 연결(ShopService·VitalsService 실패 때는 안 보냄), 진영 셋, 옛 저장. 변이 포함.
