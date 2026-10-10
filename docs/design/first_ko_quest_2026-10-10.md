# 킹의 점프 — 첫 KO → 물약 사기 → 퀵슬롯으로 마시기 → King Slime 다시 (게임성 개발 3, 2026-10-10, 구현됨)

A23-109(사용자 "퀵슬롯 퀘스트도 만들자")와 A23-110(사용자 "한 번 죽자 … 킹 슬라임을 잡자 … 한 방 맞고 죽으면 물약 사기 퀘스트")을 **한 묶음**으로. 줄로만 안내한다(팝업·팁·시작/마무리 알림 없음, A23-99). 검수가 숫자를 승인했다(TopUpGold 50, 보상 2분 + Enh70 1장, M1_2 뒤 · Lv ≤ 8 · 물약 없는 저장만).

## 한눈에
새 서브 **KO1 'The King's Hop'**(`Config.StoryQuests.Defs.KO1`)이 M1_2('Slime Princes') 뒤에 저절로 줄로 생기고 **네 줄**을 차례로 보여 준다.

| # | 줄 (Text) | 끝나는 때 | 누가 알림 |
|---|---|---|---|
| 1 | Defeat the King Slime | King이 날아와 착지하는 쿵 한 방에 **내가 쓰러짐(첫 KO)** | `Event "FirstKO"` — 개발 2의 개인 King |
| 2 | Buy a potion | 물약을 1개라도 삼 | `Event "PotionBought"` — `ShopService.BuyPotion` 성공 뒤(한 줄) |
| 3 | Drink a potion from your quick slot | 물약을 한 번 마심(퀵슬롯 키 1/2 = 같은 `UsePotion`) | `Event "PotionUsed"` — `VitalsService` 진짜 사용 뒤(한 줄) |
| 4 | Defeat the King Slime | **개인 King**을 초원에서 이김(물약 2개로 이기는 숫자 — 개발 2) | 기존 `Kill` (`Personal = true`: 나의 개인 King만) |

원래 설계의 3번(퀵슬롯에 넣기)·4번(쓰기)은 **한 줄로 합쳤다**: main의 `Config.QuickSlots.Default = {"HP","MP",""}`라 새 플레이어는 처음부터 1번 칸에 HP 물약, 2번 칸에 MP 물약이 들어 있어서 '넣기' 줄이 의미가 없다. (`QuickSlotSet` 이벤트는 만들지 않음.)

보상: 사냥 2분어치 골드·XP(`Reward.Gold = 2, XP = 2`) + 강화 주문서 70% 1장. 마무리 줄(`Finish`)·`Start`·`Pop` 없음 — 보통 퀘스트 완료 줄만.

## 누구에게 / 언제
- **받는 사람:** 모든 진영. `Requires = { Done = {"M1_2"}, MaxLevel = 8, NoPotionYet = true }`.
- **NoPotionYet:** HP·MP 물약 스톡이 0이고, 이 저장에서 물약을 산 적도(`Story.First.PotionBought`) 마신 적도(`First.PotionUsed`) 없음.
- **건너뜀:** Lv9 이상, 물약이 있거나 산/마신 저장, 이미 끝낸 저장 → 줄이 아예 안 생긴다. 시작은 한 번만(시작한 뒤에 물약을 사도 취소되지 않음).

## 서버 구현
- `StoryQuestService.Event(player, name, info)`: 이름 있는 일을 알리는 **유일한 입구**. `Config.StoryQuests.Events`(FirstKO·PotionBought·PotionUsed)에 있는 이름만, 준비된 플레이어만. 먼저 `data.Story.First[name] = true`로 저장하고, 그 이름을 기다리는 열린 줄을 한 칸 전진시킨 뒤 `refresh`를 합쳐 돌려 **곧바로 지나갈 줄**(Past)이 1초 루프를 기다리지 않게 한다. 한 칸이라도 움직이면 true.
- **Past:** `Obj = { Type = "Event", Name, Past = true }` 줄은 그 일이 **열리기 전에** 이미 있었으면 기다리지 않고 지나간다(앞서간 플레이어가 막히지 않음). 1번 줄은 Past가 아니다 — 퀘스트 이전의 옛 KO는 세지 않는다.
- `StoryQuestService.Wants(player, name)`: 열린 줄이 그 일을 기다리는 중(이미 본 일 제외)이면 true. `CurrentStep(player, id)`: 시작한 퀘스트의 현재 줄 번호(없음·끝남·[받기] 대기는 nil).
- **TopUpGold:** 그 줄로 들어갈 때 (들고 있는 + 은행) 골드가 이만큼이 안 되면 **모자란 만큼 들고 있는 골드에 채운다**(출처 `Choice`: 2배 패스 안 탐). 줄마다 한 번(`First["Top"..id..St]`를 먼저 저장), 곧바로 지나갈 줄에는 안 준다. 2번 줄에서 50골드 = 물약 2개(25×2).
- **Personal:** 개인 몬스터는 원래 어떤 퀘스트 줄에도 안 셌다. `obj.Personal = true`인 줄만 개인 처치를 세고(공유 처치는 안 셈), 다른 줄은 그대로다.
- `Requires.MaxLevel` / `Requires.NoPotionYet`: `requirementsMet`에 새 키.

### 풀HP에서 마시기 (연습 한 모금)
King 착지 뒤 플레이어는 멀쩡하다(무손실 KO). `VitalsService`는 HP/MP가 가득이면 물약 쓰기를 거절("HP is full.")하고, **클라이언트(`VitalsUI.potionState`)는 가득이면 "Full"로 아예 요청을 안 보낸다** → 3번 줄이 막힌다. 그래서:
- **서버:** 3번 줄이 열려 있는 동안만(`Wants("PotionUsed")`) 풀HP/풀MP에서 마시면 "연습 한 모금"으로 센다: 줄은 끝나지만 **물약도 쿨다운도 쓰지 않고**, "Cheers! The potion stays in your bag." 한 줄. 다친 채 진짜로 마시면 평소처럼 물약이 줄고 같은 이벤트가 간다.
- **클라 신호:** 플레이어 attribute **`PotionSip`**(`Config.FirstKO.SipAttr`, boolean)을 서버가 1초 루프·Event마다 갱신한다(3번 줄이 열려 있을 때만 true). 개발 1이 `VitalsUI.potionState`에서 `PotionSip == true`이면 가득 찬 막대도 "Use"(available)로 취급한다(한 줄, 퀵슬롯 칸은 `vitals.Request`를 거치므로 같이 고쳐짐).
- (개발 2가 KO 직후 HP를 낮게 남겨 주면 진짜 마시기가 자연스럽다 — 권장이지만 필수는 아님.)

## 약속 (각 담당)
| 누구 | 무엇 |
|---|---|
| 개발 2 | 개인 King(착지 쿵 한 방, 무손실 KO — 골드·아이템 안 잃음, 초원 입구에서 다시 일어남), KO가 나면 `S.StoryQuestService.Event(player, "FirstKO")`. 4번 줄 때(`CurrentStep(player, Config.FirstKO.Quest) == Config.FirstKO.RematchStep`) 개인 King을 다시 세우고 물약 2개로 이기는 숫자. 1번 줄 때 King을 보내는 조건도 `CurrentStep(...) == Config.FirstKO.Step`. |
| 개발 1 | 줄 눌렀을 때 안내(2번: 교차로 상인 `Guide="Crossroads"`, 4번·1번: 초원), KO 화면(팁 없이 줄만). 퀵슬롯 칸 자체는 이미 있음. **`VitalsUI.potionState`: 플레이어 attribute `PotionSip`(= `Config.FirstKO.SipAttr`)이 true면 가득 찬 HP/MP도 "Use"로.** |
| 개발 3(나) | 위 서버 구현 + 시험, `Config.FirstKO = { Quest = "KO1", Step = 1, RematchStep = 4 }`. |

## 시험 (`tools/test_first_ko.py` + `tools/test_potions.py`)
- first_ko: 정의(네 줄·보상·알림 없음·짧은 이름), 누구에게(Lv8/9·M1_2 전·물약 스톡·산/마신 저장·끝낸 저장, 진영 셋, 알림·팝업 없음), 흐름(Event 하나씩·남의 줄 안 움직임·클라이언트가 못 움직임·보상 한 번), TopUp(0/30/10+20/49/50/50은행/500, 한 번만, 곧바로 지나갈 줄엔 안 줌), 앞서가기(이른 구매·이른 마시기·옛 KO), 개인 처치 규칙. 변이 53개 모두 잡힘(동치 변이 1개 제외).
- potions: BuyPotion 성공/거절별 이벤트, 진짜 마시기 이벤트, 풀HP 연습 한 모금(물약·쿨다운 안 씀, 줄 있음/없음, 다른 일 기다릴 때 안 셈, 물약 없을 때 안 셈). 변이 +9.
