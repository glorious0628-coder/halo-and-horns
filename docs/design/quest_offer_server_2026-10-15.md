# 퀘스트 공통 장치 — 부탁 [수락]/[거절]·줍기·배달 (서버 계약, 게임성 개발 2, 2026-10-15, A23-199)

어떤 퀘스트 설계든 쓰는 서버 장치. 퀘스트 내용(누가 무엇을 부탁하는지)은 Config.StoryQuests.Defs에 적고, 화면은 개발 1.

## 1. 부탁 → [수락] / [거절]
- Def에 `Offer = { Npc = "<NpcId>", Lines = { All = { "..." }, Halo = {...}, ... } }`가 있으면 그 서브 퀘스트는 **자동으로 시작하지 않는다**. 조건(Requires·Factions·Feature)이 맞으면 '제안 중' 상태(저장 없음).
- 플레이어 속성 `StoryOffers` = 지금 나에게 부탁할 게 있는 NPC id들(쉼표, 정렬, 없으면 ""). 화면: 그 NPC 머리 위 '!'.
- 그 NPC에게 말 걸기(`StoryQuestService.TalkToNpc`, 기존 Talk 프롬프트) → 열린 퀘스트 단계가 그 NPC에 없으면 OpenPanel `"Offer"` `{ Id, Npc }`. 대사 = `Defs[Id].Offer.Lines`(Lines 모양 그대로: All / 진영별). 버튼 [수락] [거절].
- 원격 `StoryAction(Id, "Accept")` / `StoryAction(Id, "Decline")` — NPC 근처(NpcRange)·조건 다시 확인.
  - Accept = 트랙 시작(저장) + 첫 단계가 Panel이면 그 창을 연다. 신호 `StoryQuestService.Accepted(player, id)`.
  - Decline = 아무것도 저장 안 함. 다음에 다시 말 걸면 또 부탁. 신호 `Declined(player, id)`.
- 대사 규칙(A23-199): 분명한 부탁 1~2줄("곰 인형을 슬라임 왕자가 삼켰어요! 찾아 주실래요?"), 혼잣말·메모로 시작 금지.

## 2. 줍기 (Pickup)
- 단계 `Obj = { Type = "Pickup", Spot = "<Landmarks 키>", Radius = 8 }` (+ `Guide = Spot`).
- 화면: 그 단계일 때 Spot 자리에 물건 모양 + 반짝임 + 줍기 프롬프트 → `StoryAction(Id, "Pickup")`.
- 서버 확인: 지금 열린 단계가 그 Pickup인지, 캐릭터가 Spot 반경 안인지. 통과 = 다음 단계(= 들고 있는 상태, 트랙에 저장).

## 3. 배달 (Deliver)
- 단계 `Obj = { Type = "Deliver" }` + `Npc = "<NpcId>"` (또는 `Obj.Npc`), `Guide` = 그 NPC가 있는 곳.
- Panel 없음: 그 NPC에게 말 걸면 바로 건넴(TalkToNpc). Panel 있음: 창의 버튼 → `StoryAction(Id, "Deliver")`.
- 서버 확인: 열린 단계가 그 Deliver인지(= 앞의 Pickup을 마쳤는지), NPC 근처인지.

## 4. 갈 곳 표시 검사 (시험)
- `tools/test_town_quests.py` 'a23-199 every step has a guide': 모든 퀘스트 단계는 `Guide` 또는 `Npc`가 있어야 함(그 자리에서 바로 열리는 Panel 카드만 예외).
- 10/15 지금 없는 단계 33개 = KNOWN 목록(퀘스트 다시 짜기 때 채움, 목록은 줄기만 함): EG01~04·EG14, GW4·GW8, M2_1·M2_4·M2_5·M2_7, M3_5~M3_8, N0/N0A/N0T 1~2, N1·N2·N4, R3·R6·R7 2단계, S2·S3·S4, SK1, SK2 3단계.
