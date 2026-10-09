# 깊어지는 이야기 (A23-52, 검수 설계 2026-10-06)

> 사용자 요청 두 가지를 함께 다룹니다. 첫째, 레벨이 오를수록 이야기가 깊어져서 악은 왜 악을 하고 선은 왜 선을 하는지 묻게 합니다. 선은 흥미롭고 악은 지루하다는 느낌이 들어야 합니다. 둘째, 어른도 즐길 수 있게 이스터에그와 현실 풍자를 넣습니다.
> 화면 문구는 쉬운 영어입니다(A23-48, `glossary_en_2026-10-06.md`). 설명은 한국어로 씁니다. 이 문서는 네 초안(주제·어린이·어른·시스템)을 하나로 합친 것입니다.
> **코드에서 직접 확인한 것**
> - `StoryQuestService.luau:318-321`: 옛 세이브가 Lv10 이상이면 `SQ.Main` **전체**를 Done으로 바꿉니다.
> - `Near`는 머문 시간을 재지 않습니다.
> - `Landmarks`는 SlimePond와 Fountain 두 곳뿐입니다.
> - `TitleDefs`에는 칭호가 2개만 있습니다.
> - `LootService`에 공개 아이템 지급 함수가 없습니다(내부 `addItem`과 `DebugGive`만 있음).
> - 환생할 때 `data.Story`는 그대로 남습니다(ProgressionService:425-427은 문구만 띄움).
> - 진영을 바꾸면 그 진영 전용 서브가 빠집니다(StoryQuestService:342).
> - Choice에서 `Points = 0`이어도 "+0" 토스트가 뜹니다(:502).

---

## 0. 한눈에

1. **Lv1~10은 지금처럼 밝고 쉽게 둡니다.** Lv10부터는 장마다 묻는 '왜'가 한 단계씩 깊어집니다. 3장은 "왜 빼앗나", 4장은 "왜 지키나", 5장은 "왜 꽉 쥐나", 환생은 "다시 고른다면"을 묻습니다.
2. **주제는 말로 하지 않고 보여 줍니다.** 천사 쪽 선택은 나중에, 그리고 매번 다른 모습으로 돌아옵니다(새 친구, 새 대사). 악마 쪽 선택은 바로, 그리고 매번 같은 모습으로 돌아옵니다(같은 NPC, 같은 "Ka-ching!"). 보상 크기는 양쪽이 같습니다.
3. **지루한 것은 어느 진영이 아니라 '왜를 잊은 되풀이'입니다.** 고블린은 뿔의 동사(빼앗기)를 비추는 거울이고, 해골은 빛의 동사(지키기)를 비추는 거울입니다. 빛 쪽에도 '하트를 세려고 하는 착한 일' 같은 함정이 있습니다. 그래서 뿔을 고른 플레이어를 꾸짖지 않습니다.
4. **어른을 위해 한 겹을 더 얹습니다.** 회의, 줄 서기, 약관, 좋아요, 출석 보상, 패치 노트, 로딩 팁, 리뷰를 비꼬는 두 겹 대사와 숨은 이스터에그 13개를 넣습니다. 보상은 대사와 칭호뿐이고 능력치나 점수는 없습니다. 정치·종교·나라·실존 인물·브랜드는 다루지 않습니다.
5. **베타(10/24)에 넣을 것:** 장 끝 질문, 두 겹 대사, H1·R1·N3 반전, 3장 M3_1·M3_3·M3_4, 이스터에그 6개. 개발 2는 약 2.2일, 개발 1은 약 1일이 듭니다. **가장 먼저 옛 세이브 이전 버그(E0)를 고칩니다.**

> 2026-10-09 검수: ① 이 문서의 'King Slime / 왕 슬라임 / `KingSlime`'(M1_2·H1·N5·XR1 등)은 지금 화면 이름 **Slime Prince**(내부 `BigSlime`)예요. 새 네모 보스 King Slime(`SlimeKing`)은 따로예요(A23-84). ② 3장 M3_1~M3_8·Pip1과 서브 GW1·H2·H3·R3·XR1은 베타로 당겨 main에 들어갔어요(A23-56, `quest_volume_server_2026-10-07.md`·`town_quests_server_2026-10-07.md`) — 아래 표의 '정식' 표시는 그 전 계획이에요. 이스터에그 EG01~06과 4장은 아직이에요.


## 0-1. 세계의 비밀(최종, A23-55)
- **소문 (오프닝부터, 늘 "They say…"로 시작):** 누군가 균형의 왕관을 혼자 다 가지려다 못 갖자 "If I can't have it, no one can!" 하고 깼다고 합니다. 빛은 "뿔이 그랬다", 뿔은 "빛이 그랬다"고 말합니다. 두 편의 소문은 토씨 하나 같고 범인만 바뀝니다. 데면데면하던 이웃 사이가 이 소문 때문에 확 나빠졌습니다.
- **진실 (5장 끝 M5_6·M5_7에서만 밝힘):** 약 1년 전 저녁, 빛의 아이 **Bright**(빛의 성채 경비 견습)와 뿔의 아이 **Smokey**(뿔 소굴 망보는 꼬마)가 **둘이 함께** 깼습니다. 둘 다 10살쯤이고, 어른들이 서로 미워하는 동안 몰래 단짝이 됐습니다. 플레이어가 2장부터 만나는 바로 그 둘이라 새 인물은 없습니다.
- **어떻게:** 왕관은 분수 가운데 받침에 놓여 있었습니다. 옛 왕의 규칙 "The Crown is for ONE"대로 한 사람, 한 편만 가질 수 있게 만들어진 왕관이었습니다. 그래서 두 아이가 셋을 세고 함께 들자 금이 갔습니다. **화합 자체가 왕관을 깬 것입니다.**
  - 경비 교대 때라 어른들은 서로 노려보느라 왕관을 보는 사람이 없었습니다.
  - 깨진 왕관은 교차로 하늘로 떠올랐습니다(지금 보이는 것). 조각은 사방으로 흩어졌고, 큰 조각은 옛 유적으로 날아가 잠들었습니다.
- **왜 깼나 (욕심의 반대):** 모두 "왕관이 있어야 균형이 지켜진다"고 믿었습니다. 빛은 지키고 뿔은 노리며 늘 긴장하며 살았고, 어른들 입에는 왕관 얘기뿐이었습니다. 아이들은 본질을 봤습니다. 왕관 때문에 아무도 함께 놀지 못한다는 것입니다. 아이 말로는 "If no one owns it, no one has to fight."
- **소문이 생긴 길:** 아이들이 외친 "No one owns it now!"가 CRACK 소리와 웃음에 섞여 "…no one… it!"으로 들렸고, 아침에는 "If I can't have it, no one can!"이 됐습니다. 욕심은 아이들이 아니라 **왕관을 서로 가지려던 모두**(빛·뿔·장인)에게 있었습니다. 마지막 장에서 세 안내자가 한 줄씩 스스로 인정합니다.
- **표식:** 그날 밤 Bright는 주운 부스러기로 길 잃은 어른(지금의 빛 안내자)에게 등불을 밝혀 줘서 후광이 돋았습니다. Smokey는 "이 조각만은 아무도 싸우지 않게" 간직해서 뿔이 돋았습니다. 둘 다 조각을 힘에 쓰지 않아서 표식이 자라지 않습니다(누구보다 작음).
- **옛 왕:** 왕관은 300년 전 옛 왕의 것이었습니다. "Nothing must change"는 옛 왕과 해골 유적(늘 화요일)에만 남깁니다.
- **아이 안전:** 아이들은 벌받지 않고, 사과하거나 뒷수습하지도 않습니다("Nobody got in trouble."). 둘은 그냥 best friends이고 연애 표현은 없습니다. 위험한 행동도 없고, 아이들은 마을과 교차로에만 있습니다.
- **마지막 질문:** "Which side will you choose today?" 오프닝 질문 "Which side will you choose?"에 today 한 단어만 더했습니다. 균형은 왕관이 아니라 우리가 날마다 고르는 것이라는 GDD §0을 말로 하지 않고 질문으로 남깁니다.
- **어른용 한 겹:** 소문 전달 게임("Grown-ups always lose at Telephone."), "Nobody asks our names. Just 'Which side?'", 그리고 지키는 쪽도 노리는 쪽도 속으로는 "우리 것"이었다는 점.

---

## 1. 규칙

### 1-1. 어린이용 (8~12살)
- 한 줄은 12단어 안팎으로 쓰고, 한 장면은 3쪽까지입니다(이스터에그만 4쪽). 용어는 용어 표를 따릅니다(Crown Shard, Purify/Devour, Vault/Pouch, Honor/Infamy).
- 이야기 문구에는 "kill" 대신 "beat"나 "stop"을 씁니다.
- 무섭거나 잔인한 장면은 없습니다. 해골은 웃긴 경비원이나 창구 직원으로 나옵니다. 해골왕은 무서운 왕이 아니라 졸린 왕입니다. 죽음·굶주림·피를 소재로 한 농담은 쓰지 않습니다.
- **PvP 지역(숲, 유적 안쪽 왕관 구덩이 — 유적 바깥 고리는 PvP 없음, A23-90) 안전**
  - 대화하거나 머무는 장소는 지역 입구 쪽에 둡니다.
  - 머무는 시간은 20초 이하로 합니다.
  - 싸우는 중이면 대화창은 B15 대기열로 미룹니다(지금 동작).
- 표지판에는 플레이어 이름을 넣지 않습니다. "for YOU"처럼 씁니다.

### 1-2. 설교 금지
- 주제 문장("Good is fun, evil is boring")은 어떤 대사에도 쓰지 않습니다.
- 이야기 문구에 쓰지 않는 말: bad, wrong, should, shame, evil person, sin.
- 천사 쪽을 고른 뒤에도 "잘했어요" 같은 칭찬은 없습니다. 토스트 형식은 양쪽이 똑같습니다(지금의 `Good`/`Evil` 문구).
- **악마 쪽 선택지에는 이유를 붙여** 신나게 씁니다. 예: "They took it first!", "Just in case!"
- 뿔 쪽 NPC는 끝까지 행복합니다. 예: "Bigger sack! Best day ever!"
- 반대쪽을 골랐을 때는 지금 있는 한 줄 반응을 그대로 씁니다(OddHalo/OddHorns).
- 진영 변경이나 환생을 권하는 대사는 없습니다(quest_chain 규칙).

### 1-3. 양쪽 다 진짜 이유가 있다
| 누구 | 진짜 이유 (아이 눈높이) | 되풀이로 굳으면 (지루함) | 새것으로 열리면 (흥미) |
|---|---|---|---|
| 빛 Knights of Light | 받은 친절을 갚고 싶어서. 이름 모를 사람에게서 등불을 받았습니다 | 하트 세기, 서류 늘리기 (Sir Gleam, Bright) | 매번 다른 누군가를 돕습니다 |
| 뿔 Horn Legion | 혼자 빠질까 봐 무서워서. 조각이 떨어질 때 너무 멀리 있었습니다 | 같은 Plan A, 자루만 커집니다 (Smokey) | Plan C, 깜짝 파티 (Rascal Rex) |
| 장인 Artisan Guild | 어느 편도 아닌 손으로 고치고 싶어서 | 양쪽에 다 팔기 (N3 B) | 양쪽 모두를 위한 것을 만듭니다 |
| 고블린 | 왕관이 깨진 뒤 숲이 깜깜해져서, 꼬마들 밤 등불이 필요했습니다 | Grab Club 회의 #47, #48… | Pip의 등불 가게 |
| 해골 | 옛 왕의 명령 "아무것도 변하지 마라" | 늘 화요일, 번호표 9,999 | 첫 휴가, 첫 수요일 |
| 해골왕 | 잃는 게 무서워서 | 30분마다 같은 연설 | 인사하고 잠들면 아침이 옵니다 |

빛의 이유와 뿔의 이유는 사실 같은 두려움(혼자 남겨짐)에서 나와 반대 방향으로 갑니다.
- 빛: "So no one is left out."
- 뿔: "So I'm never left out."

### 1-4. '선은 새롭고 악은 되풀이'를 보여 주는 법
1. **메아리 규칙 (가장 중요)**

   | | 천사 쪽 (Good / 장인 A) | 악마 쪽 (Evil / 장인 B) |
   |---|---|---|
   | 언제 | 나중에 (몇 레벨 뒤, 다음 장) | 바로 (받기 순간) |
   | 모습 | 매번 다름: 새 친구, 새 대사, 새 장면 | 매번 같음: 같은 NPC, 같은 대사, 같은 소리 |
   | 보상 | 기존 아이템 (70% 주문서 등) | 같은 값의 골드 |
   | 느낌 | "다음엔 뭐가 나올까?" | "빠르고 확실해! …또 이거네 ㅋㅋ" |

2. **거울:** 고블린은 '빼앗기', 해골은 '지키기'를 이유를 잊은 채 되풀이합니다. 플레이어 진영이 아니라 NPC가 되풀이를 보여 줍니다.
3. **되풀이는 NPC가 맡습니다.** 플레이어에게 "너는 같은 일만 해"라고 말하지 않습니다.
4. **손으로 하는 플레이는 양쪽 다 새롭습니다.** 악마 쪽 후속 퀘스트도 목표 종류는 매번 바꿉니다(우두머리 → 골드 → 스킬). 감싸는 대사만 같습니다("Same job as always?").
5. **빛의 함정도 같은 무게로 둡니다.** 칭찬받으려고 하는 착한 일(Sir Gleam), 이유를 잊고 계속 지키기(해골, Bright의 서류)가 있어야 이야기가 "뿔 = 나쁨"으로 읽히지 않습니다.
6. **즐겁게 고른 되풀이는 괜찮습니다.** 호박 대왕의 대사 "A loop with friends is a party!"가 그 예입니다. 사냥 반복 자체를 놀리지 않습니다(노가다는 줄이되 없애지 않는다는 원칙). 놀리는 대상은 '왜를 잊은' 되풀이뿐입니다.
7. **장 끝은 질문으로 끝납니다.** 마지막 쪽은 플레이어에게 묻는 한 줄이고, 답 버튼은 없습니다. 웃음 다음에 질문이 오고, 질문을 농담으로 덮지 않습니다.

### 1-5. 점수·보상 공정
- **메인 선택 점수는 quest_chain 결정 3 예산을 그대로 씁니다:** S0 +2, S3 +1, S1 +1, M2_3 +2, S6 +1, **M3_4 +3 → 계급 2**, M4_4 +3. 5장 점수는 만들 때 정합니다.
- **마을 사람 서브(H/R/N)**는 town_npc_quests 규칙을 그대로 따릅니다. 보상 크기는 같고 종류만 다르며, 기울기는 기록하지만 주간 랭킹 점수는 주지 않습니다.
- **이스터에그 선택**은 Pick만 기록하고 점수는 0입니다. 숨은 것을 찾은 사람만 점수를 더 받는 불공평을 막기 위해서입니다. 대신 기울기 토스트("Your shard leaned to the light." / "…to the dark.")는 띄워서 GDD §0(모든 선택이 기운다)을 지킵니다.
- 칭호는 능력치가 없습니다(BB16). 선택형 이스터에그는 천사 쪽과 악마 쪽에 같은 수의 칭호를 둡니다.
- **A23-58(사용자 2026-10-06 저녁):** 자기 편답지 않은 선택은 내 점수를 깎습니다 — 빛이 나쁜 쪽이면 명예 −, 뿔이 착한 쪽이면 악명 −(0 아래로 안 내려감). 반대 편 점수는 선택으로 오르지 않습니다. 모든 선택(메인·H/R/N·조각 꽃)에 같은 규칙입니다.

---

## 2. 레벨대별 장

### 1장 「Sparkly Jelly」 · Lv1~5 · 말랑 초원 (있음, 줄만 더함)
- **중심 질문:** 이 반짝이는 가루는 뭐지?
- 빛: "Broken things get fixed. Right?" / 뿔: "Shiny! Finders keepers!" / 장인: "Raw dust is ugly. Let's shape it."
- **끝 선택:** S0 Purify / Devour (+2)
- **장 끝 질문 (M1_4 마지막 쪽, 모든 진영):** "More shards are out there." / "What will you do with the next one?"

### 2장 「The Fountain's Question」 · Lv5~10 · 교차로 + 초원 (있음, 줄만 더함)
- **중심 질문:** 돌려줄까, 가질까?
- 빛: "It belongs to everyone." / 뿔: "First hand, first owner!" / 장인: "Both sides look suspicious. Noted."
- **끝 선택:** M2_3 분수 "Give it back / Keep it" (+2)
- **장 끝 질문 (M2_7 마지막 쪽):** "The goblins took the dust." / "But why would a goblin need dust?"
- 뿔 안내자 M2_7에 한 줄을 더합니다(자기 풍자): "Goblins grab for a boss. We grab for US. Big difference! …Right?"

### 3장 「Grab Club」 · Lv10~25 · 고블린 숲 (베타 3단계, 나머지 정식)
- **중심 질문:** 빼앗는 쪽은 왜 빼앗을까?
- **새 설정 (검수가 정함, 세부 규칙):** 왕관이 깨진 날부터 고블린 숲의 밤이 아주 깜깜해졌습니다. 조각 가루는 빛을 내서, 고블린은 처음에 꼬마들의 밤 등불로 쓰려고 가져갔습니다. 그러다 빼앗기가 습관이 되었고, 지금은 이유를 잊은 채 매주 "MORE" 회의를 합니다. 막내 Pip만 처음 이유를 기억합니다.
- 빛: "If we don't bring light, who will?"
- 뿔: "Nobody hands you anything. So we take."
- 장인: "A hammer doesn't pick a side. …Is that a side too?"

| Id | 제목 (EN) | 열림 · 레벨 | 목표 (지금 타입) | 이야기 한 줄 (EN) | 단계 |
|---|---|---|---|---|---|
| M3_1 | Thief Footprints | M2_7 Done (Lv10) | `Kill Goblin 5, Zone=GoblinWoods` | 끝 토스트: "A note: 'IOU 1 dust. Will pay back. Maybe.'" | 베타 |
| M3_2 | Three Camps | M3_1 | `Trials`: `Kill Goblin Near=GoblinCamp1/2/3, Radius 40` 각 1 | ① "Jars of dust… glowing like night-lights?" ② "A goblin drawing: a tiny goblin, a big dark." ③ "Meeting #47. Topic: Grab more. Result: Meet again." | 정식 (B+) |
| M3_3 | The Brute's Sack | 베타 M3_1 / 정식 M3_2 | `Kill GoblinBrute 1` (함께 잡아도 인정) | Brute: "Not stealing! I'm a… surprise collector." | 베타 |
| **M3_4** | Whose Shard? (**선택 ③ +3**) | M3_3 | `Enter OwnTown` → `Talk` (1쪽 **LinesBy From=M2_3**, 2~3쪽 Pip) → `Choice` → 받기 | 아래 5절 ③ | 베타 |
| M3_5 | Sprout Graduation | M3_4 + `Level 15` | `State Graduated`(E7) → `Talk` (안내자 셋의 진짜 이유, 5절 ④) | 끝: "And you? Why are you here?" | 정식 |
| M3_6 | Brute Hunt | `Level 18` | `Kill GoblinBrute 2` | Grabbo 회의 #48 (**LinesBy From=M3_4**) | 정식 |
| M3_7 | Campfire Dust | `Level 21` | `SkillHit Min 3 ×2` + 숲 지역 조건(quest_chain B) | "They grab in a line. Break the line!" | 정식 |
| M3_8 | Call of the Tombs (장 끝) | `Level 25` | `Enter SkeletonRuins` → `Talk` | 복선: "From the tombs, a sleepy voice: 'Is it still Tuesday?'" | 정식 |

- **끝 선택 M3_4**
  - 빛·뿔: Good **[Leave some for their lamps]** / Evil **[Into our vault. They took it first!]**
  - 장인: A **[Make them a real lamp]** / B **[Sell the dust back to them]** (기록만)
- **안내자 반응 (claim Talk, LinesBy From=M3_4, 진영별)**
  - 빛 안내자, Good: "A little light for them. Not bad."
  - 뿔 안내자, Evil: "Ha! Finders keepers!"
  - 반대쪽을 골랐을 때는 지금의 OddHalo/OddHorns를 씁니다.
- **메아리**
  - **Good/A (나중, 매번 다름):** 서브 `Pip1`이 열립니다(Requires.Pick M3_4=Good, Level 15). 숲 입구에서 Pip이 "Look! My own lamp!"라고 말하고 70% 주문서 1장을 줍니다. 정식에서는 Pip의 대사가 레벨마다 바뀌고, 교차로에 Pip의 등불 가게가 생깁니다(나에게만 보임).
  - **Evil/B (바로, 매번 같음):** M3_4를 받는 순간 뒷골목 고블린 거래상 **Dibs**가 나타나 "Ka-ching! Same as always? Same as always!"라고 말하고, 주문서 1장과 같은 값의 골드를 줍니다. Dibs는 이후 장에서도 늘 같은 대사를 합니다.
- **장 끝 질문 (M3_8):** "The goblins took for light. Then they forgot why." / "What do YOU want the shard for?"

### 4장 「Always Tuesday」 · Lv25~35 · 해골 유적 (정식)
- **중심 질문:** 무엇을 위해 지키지?
- **새 설정 (quest_chain ⑤의 확장):** 옛 왕은 "Nothing must change."를 원했습니다. 큰 조각이 그 말을 들어 왕국을 '같은 하루'에 멈춰 버렸습니다. 해골들은 무엇을 지키는지 잊은 채 300년째 경비를 섭니다. 이곳은 늘 화요일입니다.
- 빛: "Guarding is good. But if you forget why, every day is the same."
- 뿔: "If it's mine forever, it's safe forever."
- 장인: "You can't shape a thing that never changes."

| Id | 제목 (EN) | 목표 (지금 타입) | 이야기 한 줄 (EN) |
|---|---|---|---|
| M4_1 | Still on Duty | `Kill Skeleton 5` | 시작: "The skeletons still think they guard the crown." 토스트: "Clatter! …Back to work!" |
| M4_2 | Broken Arches | `Trials`: `Kill Skeleton Near=Arch1/2/3, Radius 40` | 왕국 패치 비석 3개 (EG11) |
| M4_3 | The Crown's Knight | `Kill SkeletonKnight 1` (함께 잡아도 인정) | 끝: "Is my shift over? Nobody ever told me." |
| **M4_4** | The Sleeping Big Shard (**선택 ④ +3**) | `Near RuinsGate, Radius 15` → `Talk` (Sir Halt + 큰 조각) → `Choice` | 5절 ⑦ |
| M4_5 | Deep in the Tomb (장 끝) | `Talk`만 (보상·약속 없음) | "From deep below: 'Same… same… same…'" |

- **끝 선택 M4_4**
  - 빛·뿔: Good **[Let tomorrow come]** / Evil **[Guard MY vault now!]**
  - 장인: A **[Fix their old armor]** / B **[Hire them for the Guild]**
- **메아리 (StoryWorld, 정식)**
  - **Good:** 초원 연못가에 해골 2~3명이 파라솔을 펴고 휴가 중입니다. 갈 때마다 대사가 바뀝니다.
    - "First day off in 300 years!"
    - "What is a 'Wednesday'? I love it!"
    - "I learned to swim. Bones float!"
    - 칭호 *Shift Ender*
  - **Evil:** 내 마을 금고 옆에 멋진 해골 경비가 섭니다(나에게만 보임). 늘 같은 말을 합니다: "Still guarding. Still guarding." 칭호 *Boss of Bones*
- **장 끝 질문 (M4_5):** "They forgot why they guard." / "Do you remember why you fight?"

### 5장 「The Same-Day King」 · Lv35~50 · 해골왕 왕좌 마당 (나중, 지역이 생길 때)
- **중심 질문:** 왕관을 다 가지면, 둘째 날엔 뭘 하지?
- 빛: "Let go, and new things come." / 뿔: "Hold on, and you never lose." / 장인: "The crown was never anyone's."
- **목표 (있는 타입만)**
  - M5_1 `Enter ThroneYard`
  - M5_2 `Near` ×3: 왕의 규칙 쪽지 — "Rule 1: Balance needs a Crown. —The King" / "Rule 2: The Crown is for ONE. —The King" / "Rule 3: Never let two hold it. NEVER. —The King"
  - M5_3 `SkillHit Min 3 ×2` (왕좌 마당): "They marched this loop 100,000 times. Break the line!"
  - M5_4 `Talk`: 잠꼬대 "Same… same… same…"
  - **M5_5 `Talk` → `Choice` (선택 ⑤)**
- **끝 선택 M5_5:** 왕은 양쪽 모두에게 같은 거래를 내밉니다(`step[faction]`).
  - 뿔에게: "never lose again" / 빛에게: "nobody ever gets hurt again"
  - Good **[No. Let tomorrow be new.]** / Evil **[Deal. Keep today forever!]**
  - 장인: A **[Pass the shards around]** / B **[Keep the crown in the Guild]**
- **장 끝 질문:** "If you could keep today forever… would you?"
- 왕관을 깬 진실은 §2-2 M5_6·M5_7에서 밝힙니다(두 아이 Bright·Smokey, §0-1).

### 환생 「Who Will You Be?」 · Lv50+ (정식에 대사만, 나머지 나중)
- **중심 질문:** 다시 고르면 같은 걸 고를래?
- S0의 왕관 조각이 돌아와 내 Pick을 기억합니다(7절). 마지막 줄: "Who will you be this time?"
- **회색 전설:** "You walked both roads. Which one surprised you more?"


## 2-1. 복선 지도

| 장 | 레벨 | 어디 | 단서 줄 (EN) | 퀘스트 id | 단계 |
|---|---|---|---|---|---|
| 서장 | 첫 접속 | 오프닝 (하늘 왕관 → 분수) | 자막 순서: "They say the Crown kept the world in balance." → "They say someone wanted it all to themselves." → "'If I can't have it, no one can!' CRACK." → (기존 2·3줄) → "Now each side says the other did it." → "Which side will you choose?" | `Config.Story.Premise` 1줄 고침 + 새 키 `Config.Story.OpeningRumor` 3줄. 진영 카드 판은 3줄 그대로이고, Intro만 끼워 읽음 (A23-44 다시 만들기 때) | 베타 |
| 1장 | Lv2~4 | 말랑 초원 | Finish 토스트: "Dust spills out! …And a braided band? Gold and purple." | M1_2 (기존) | 베타 |
| 1장 | Lv4~5 | 우리 마을 안내자 (2쪽째) | 빛: "They say a Horn broke the Crown. Pure greed!" / "Broken things get fixed. Right?"<br>뿔: "They say a Halo broke it. So greedy. Typical!"<br>장인: "Both sides say 'they did it.' The Guild says: fix first." | M1_4 (기존, 3쪽 = 기존 1쪽 + 이 줄 + 장 끝 질문) | 베타 (장인 줄은 장인 업데이트) |
| 2장 | Lv5~7 | 교차로 분수 | 1쪽에 줄 추가: "Halos and Horns tell the same story. Word for word." / "They just swap who did it."<br>Finish 토스트(NPC 없음): "Two kids by the fountain. They see you and run… opposite ways." | M2_3 (기존) | 베타 |
| 2장 | 약 Lv6, 빛 | 빛의 성채 → 초원 가장자리 | Bright: "They say a Horn broke the Crown. Everyone says so." / "…Who said so first?" / "Page 12 of my rulebook is missing. Don't look at me!"<br>반전 뒤: "One jar says: 'Happy birthday, S. From the bench.'" / Bright: "Not my writing! I mean… whose writing?"<br>토스트: "Bright's wristband: gold and purple. Where have you seen one?" | H1 (기존) | 베타 |
| 2장 | 약 Lv6, 뿔 | 뿔 소굴 → 분수 | Smokey: "A Halo broke the Crown! My uncle's friend's cousin saw it!" / "This gold spyglass? Found it. Gold is fine. For spying."<br>반전 뒤: "One purple firework? In a Halo show?" / "The plan is signed 'B.' …Never heard of a B."<br>토스트: "Smokey's wristband: gold and purple. Where have you seen one?" | R1 (기존) | 베타 |
| 2장 | 약 Lv6, 모두 (A23-57) | 교차로 | Tiny: "Halos blame Horns. Horns blame Halos. Noted: nobody saw it." / "Suspicious: two kids. Bench behind the fountain. Every evening." / "Their halo and horns are tiny. Smaller than anyone's." | N3 (기존) | 베타 |
| 2장 숨김 | Lv5+ (M2_3 뒤) | 거위 둥지 | "The Golden Goose has 0 followers. She has never been happier." / "Also, she saw who broke the Crown. Honk." | EG03 (기존, 줄 추가) | 베타 |
| 2장 숨김 | Lv5+ (M2_3 뒤) | KidsBench (분수 뒤, 반경 6, 길에서 비킴) | "Under the bench: two small handprints in old paint." / "One gold. One purple. Side by side." | **EG14 (새)**: Hidden, `Near KidsBench 6` → `Talk`, 점수 0, 칭호 *Bench Detective* | 베타 선택 (밀리면 가장 먼저 자름) |
| 3장 | Lv10~15 | 고블린 숲 | Finish 토스트: "In the sack: a crayon drawing. Two kids holding something round." / "The sun? A cookie?" / "Brute: Found it by the fountain. The night of the big CRACK!" | M3_3 (기존) | 베타 |
| 3장 | Lv12+ | 숲 입구 야영지 (PvP 밖) | Grabbo: "Meeting #1 was the night of the CRACK." / "Topic: two kids ran by, laughing. Why?" / "No answer. Meeting #2: grab more." | GW1 (기존 계획) | 정식 |
| 3장 | Lv15 | 우리 마을 안내자 (진짜 이유 ④에 덧붙임) | 빛: "When the Crown broke, I got lost." / "A stranger gave me their lamp. Such a small hand." / "I never learned their name. So now I give mine."<br>뿔: "That night, two kids ran past us. Laughing. Who laughs then?"<br>장인: "That night, two kids asked me: 'Can two hold one crown?'" / "I said no. They looked very happy. Odd." | M3_5 (기존 계획) | 정식 (장인 줄은 장인 업데이트) |
| 4장 | Lv25+ | 교차로의 다른 벤치 (KidsBench 아님) | Sunny Sam: "Nice weather today!" → "…Okay. I have one more line." → "Nice weather that night, too. Two kids. Big laugh." | EG08 (기존 계획) | 정식 |
| 4장 | Lv30~35 | 유적 입구 RuinsGate | Big Shard: "The Crown was made for ONE. One head. One side." / "Two small hands held it at once. I never felt so light." | M4_4 (기존 계획) | 정식 |
| 5장 | Lv35~40 | 왕좌 마당 | 쪽지 3장: "Rule 1: Balance needs a Crown. —The King" / "Rule 2: The Crown is for ONE. —The King" / "Rule 3: Never let two hold it. NEVER. —The King" | M5_2 (옛 'pass it on' 쪽지를 대체) | 나중 |
| 5장 | Lv40~45 | 왕좌 마당 | King, 잠꼬대: "Same… same… same…" / "Who broke my Crown? …Two giggles?" | M5_4 (기존 계획) | 나중 |
| 숨김 | Lv35+ | 지역마다 | 일기 마지막 쪽: "Last day as a crown: two hands at once. Not one." / "I couldn't pick. Best day ever." | EG13 (기존 계획, 마지막 쪽 교체) | 나중 |

**단서가 쌓이는 순서**
- 소문 → 두 편이 같은 문장 → 두 아이가 반대쪽으로 달아남 → 끈, 12쪽, "S.", "B." → 작은 표식 → 크레용 그림 → 회의 #1 → 등불을 준 작은 손 → "ONE" 규칙과 두 손 → 왕의 규칙 순입니다.
- 눈 밝은 아이는 4장쯤 스스로 맞힐 수 있습니다. 이름은 마지막 장에서 확인합니다.
- 장인 플레이어는 N3와 모두가 보는 줄로 단서를 전부 볼 수 있습니다.

**만들 때 규칙**
- **말하는 사람:** 새 엔진 없이 줄 앞에 "Bright: "를 붙입니다. 한 쪽은 문자열 하나로 쓰고, 줄을 나눌 때는 `\n`을 씁니다.
- **Speakers 추가 (+En):** `Bright`, `Smokey`, `Tiny`, `Kids` = "Bright & Smokey"
- **Landmarks 추가:** `KidsBench`. 지금 교차로 벤치 (18, 0, 18)을 씁니다. 스폰에서 보면 분수 뒤이고 길에서 비켜 있습니다. EG08 Sunny Sam은 (18, 0, -18) 벤치를 씁니다. 둘 다 지도 v2 때 좌표를 다시 정합니다.
- **LinesBy:** 모두 Default가 있어야 합니다. 앞 장 기억에 기대는 조건(From=M1_2 같은 것)은 쓰지 않습니다.
- **Bright·Smokey 모습 (10/15 H1·R1 배치 전에 검수가 확정)**
  - 10살쯤으로 `Model:ScaleTo` 약 0.8
  - 표식은 가장 작은 R1
  - 손목 끈은 임시 금·보라 링 Part입니다. 화면에서 안 보여도 되고, 단서는 글자로 전합니다.
  - 새 그림은 없습니다.
- **비용**
  - 베타 단서: 개발 2 약 0.1일(영어 데이터 작업에 끼워 넣음) + EG14 0.05일, 개발 1 0.1일(KidsBench, 아이 크기)
  - 정식 단서: 개발 2 약 0.1일

(이 절의 '같이 고칠 줄'은 본문에 바로 반영함, 검수 2026-10-06.)

## 2-2. 마지막 장 「The Kids Who Broke It」
(깬 사람이 두 아이라서 제목을 복수형으로 썼습니다. 퀘스트는 둘입니다: **M5_6 「Two Hands」**(밝힘), **M5_7 「Which Side Today?」**(선택).)

- **열림·레벨:** M5_5를 끝내면 열립니다. Lv45 권장(5장 Lv35~50 안)이고, 단계는 **나중**(왕좌 마당이 생길 때)입니다.
- **장소:** 교차로 KidsBench입니다. Bright와 Smokey가 처음으로 나란히 앉아 있습니다(E9, 이 플레이어에게만 보임). 하늘의 깨진 왕관이 화면 위쪽에 보입니다. 기존 대화창을 쓰고, 새 그림과 모델은 없습니다.
- **목표 (지금 있는 타입만)**
  - M5_6: `Enter Crossroads` → `Near KidsBench Radius 8` → `Talk` 3쪽 (Speaker = Kids)
  - M5_7: `Talk` 3쪽 + `Choice` (한 step) → `Talk` 2쪽 (`LinesBy From=M5_7`, Claim)
  - Pick은 고르는 순간 저장되므로(StoryQuestService:499) 같은 퀘스트의 다음 step에서 읽을 수 있습니다.

**M5_6 「Two Hands」 (3쪽)**
1. "Two kids on one bench. Bright from Halo. Smokey from Horns." / "Smokey: Oh no. It's you. Plan B: act normal." / "Bright: …This IS us acting normal."
2. "Bright: Grown-ups only ever talked about the Crown." / "Smokey: Guard it! Grab it! Every single day." / "Smokey: Nobody asks our names. Just 'Which side?'"
3. "Bright: My rulebook, page 12: 'The Crown is for ONE.'" / "Smokey: So we held it together. One, two, three…" / "Bright & Smokey: CRACK!"

**M5_7 「Which Side Today?」 (3쪽 + 선택)**
1. "Smokey: We yelled, 'No one owns it now!'" / "Bright: By morning it was 'If I can't have it, no one can!'" / "Smokey: Grown-ups always lose at Telephone."
2. 진영별 Lines: 세 안내자가 스스로 인정합니다.
   - 빛: "Your guide runs up, out of breath." / "Guide of Light: We guarded it for everyone. …So nobody else could touch it." / "Guide of Light: …Huh."
   - 뿔: "Your guide runs up, grinning." / "Horn Legion Guide: We wanted it all for US. So did they." / "Horn Legion Guide: Twins! HA!"
   - 장인 (장인 업데이트 뒤): "Your guide runs up, clipboard first." / "Guild Guide: Noted: we planned to rent it out." / "Guild Guide: …Oops. Us too."
3. "Bright: We never wanted a fight. We wanted everyone to play." / "Smokey: Nobody picked me for a team. Then a Light kid did." / "Bright: So… do we fix the Crown?"

**선택 (두 쪽 모두 존중, 점수 같게)**
- 빛·뿔: Good **[Leave it in pieces. It's nobody's now.]** / Evil **[Fix it. Our side keeps it. Just in case!]** — 점수 3. **A23-58:** 빛은 Good 명예 +3 / Evil 명예 −3, 뿔은 Evil 악명 +3 / Good 악명 −3(0 아래로 안 내려감).
- 장인: A **[Make it into something for everyone]** / B **[Fix it, then rent it. To both sides!]** (기록만)
- +3은 M3_4·M4_4와 같은 무게입니다. 5장 예산을 정할 때 바꾸더라도 양쪽은 같게 둡니다.
- 자기 편답지 않은 쪽을 고르면 A23-58 알림 한 줄("Not very angel-like!" / "Too nice for a devil!")만 나옵니다. 아이들(Bright·Smokey)의 대사는 꾸중하지 않습니다.

**선택 뒤 (LinesBy From=M5_7, 2쪽)**
1. 고른 것에 따라
   - Good: "Bright: Then every day can be a new day!" / "Smokey: Tomorrow: kites. The day after? Who knows!"
   - Evil: "Smokey: Fix it? Then you need every shard. From everyone!" / "Bright: So… Crown Wars. Every ten minutes. Same as always." / "Smokey: Ha! Have fun. We'll be on the bench."
   - A: "Bright: Something for everyone? Like… a bench for two sides!" / "Smokey: Plan C! I like Plan C."
   - B: "Smokey: Rent it to both sides? Ha! Same as always." / "Bright: We'll be on the bench. Rent-free."
   - Default: "Bright: Okay. We trust you." / "Smokey: Mostly."
2. 모두 같음: "Bright: We made a third band. For the next friend. It's yours." / "Smokey: Oh, and nobody got in trouble. Not even us." / "**Bright & Smokey: Which side will you choose today?**"
   - 이것이 마지막 질문입니다. 답 버튼은 없고 [OK]를 누르면 받기로 넘어갑니다.

**보상:** 장 끝 보상(5장 예산) + 칭호 *Third Band*(E3)입니다. 어느 쪽을 골랐든 같은 칭호이고 능력치는 없습니다.

**진영 반응 (아무도 아이를 꾸짖지 않음)**
- **장면 안:** 위 2쪽에서 세 안내자가 한 줄씩 "우리도 그랬네"를 말합니다. 욕심은 모두에게 있었다는 것을 말 대신 보여 줍니다.
- **끝낸 뒤 안내자 대화 한 줄 (메뉴 '안내자 만나기')**
  - 빛: "We still guard things. Now we ask what for."
  - 뿔: "Plan A: grab it. Plan K: there is no 'it'. HA!"
  - 장인: "Noted. Tiny's chart says 'Suspicious: nobody.' First time ever."

**끝난 뒤 세계 (능력치 0, 끝낸 플레이어에게만 보임, E9 StoryWorld)**
1. **KidsBench:** Bright와 Smokey가 마을 자리 대신 벤치에 나란히 앉아 있습니다. 등받이에 SurfaceGui 글자로 "Two Hands Bench"를 답니다.
2. **메아리 (§1-4 규칙)**
   - **Good/A:** 다음 접속부터, 갈 때마다 다른 놀이를 합니다(6줄 돌림). 예: "Today: kite day!" / "We taught Old Slime a game!" / "A Horn kid joined. A Halo kid too. Four now!"
   - **Evil/B:** 바로, 늘 같습니다. 벤치 옆 병에 "Crown Fund: 3 gold and a button. Same as always!"가 붙고, Smokey는 늘 "Crown Wars? It's just a game now. Best game!"라고 말합니다.
3. **오프닝 다시 보기:** 마지막 자막 뒤에 "…At least, that's what they say." 한 줄이 붙습니다.
4. **환생:** 조각 대사가 "Two kids broke me. You carried me. Who will you be this time?"로 바뀝니다.
5. **하늘의 왕관:** 어느 쪽을 골랐든 깨진 채로 둡니다. 10분 왕관 쟁탈전, 점수, 거위, 랭킹은 그대로입니다.
6. **나중 선택 (각각 따로 승인):** 세 번째 끈 액세서리(이미지 생성 2가 2D를 그리고 검수를 거쳐 사용자에게, 능력치 0), 시소(소품 키트에 생기면 벤치 옆).

**만들기**
- **나중 (5장 때)**
  - 개발 2 약 0.3일: M5_6·M5_7 데이터, Speakers `Kids`, TitleDefs `ThirdBand`, M5_5 선택 고침
  - 개발 1 약 0.5일: E9 벤치 장면, 오프닝 다시 보기 줄, 환생 줄
- **선택안:** M4_5 뒤 Lv35 교차로 장면으로 정식에 당길 수 있습니다. 새 지역이 필요 없고 일수는 같습니다. 대신 M5_2·M5_4·EG13 단서가 결말 뒤로 밀리므로 기본은 '나중'으로 둡니다.

---

## 3. 서브 퀘스트 주제 (마을·사냥터별)

공통 규칙은 town_npc_quests와 같습니다.
- 한 번만 합니다.
- 마지막은 A(천사)/B(악마) 선택입니다.
- 보상은 크기가 같고 종류만 다릅니다(A: 70% 주문서, B: 물약 3 + 골드 60).
- 마지막 줄은 질문입니다.

| 자리 | Id · 제목 (EN) | 레벨 · 열림 | 목표 (지금 타입) | 선택 A / B | 메아리: 새것 / 되풀이 | 단계 |
|---|---|---|---|---|---|---|
| 빛의 성채 | **H1** The Horns Are Up to Something | **M2_3 뒤 (약 Lv6)**, 빛 | `Talk` Bright → `Near WoodsGate Stay 10` (초원 쪽, PvP 밖) → **`Kill KingSlime 2` 숲 쪽 초원 가장자리** → `Talk` → `Choice` | 반전: 뿔의 자루는 Smokey 생일 젤리. A "Tell everyone the truth" / B "Keep the rumor going. It's more fun!" | Bright가 파티에 가서 새 대사 / 소문만 커짐: "Now the sacks are 'giant'. Still jelly." | **베타** |
| 빛의 성채 | H2 The Missing Halo Lantern | M1_1 뒤, 빛 | town 문서 그대로 | town 문서 그대로 | A를 고르면 M3_5에서 빛 안내자가 등불 안 이름 "Dawn"을 처음 알게 됨 (LinesBy From=H2) | 정식 |
| 빛의 성채 | **H3** Day 40: Cat in Tree | Lv12, 빛 | `Talk` Sir Gleam → `Kill Slime 6` (초원) → `Talk` → `Choice` | A "Let the cat be. Help someone new." / B "Put it back up. More hearts!" | 갈 때마다 다른 사람을 도움 / "Day 41. Cat in tree. Hearts: 10,002!" | 정식 |
| 뿔 소굴 | **R1** The Halos Are Up to Something | **M2_3 뒤**, 뿔 | `Talk` Smokey → `Near Fountain Stay 15` → `Kill Slime 6` → `Talk` → `Choice` | 반전: 후광의 속닥거림은 분수 불꽃 쇼 연습. A/B는 H1과 같음 | Smokey가 쇼를 보고 새 대사 / "Plan B: same rumor, but louder!" | **베타** |
| 뿔 소굴 | R2 The Ember Thief | Lv25, 뿔 | town 문서 그대로 (해골 4) | town 문서 그대로 | 소굴 모닥불에 갈 때마다 꼬마가 하나씩 늘어남 / "My pile is SO big. …I need a bigger pile." | 정식 |
| 뿔 소굴 | **R3** Prank #200 | Lv12, 뿔 | `Talk` Rascal Rex → `EarnGold 60` → `Talk` → `Choice` | A "Plan a surprise party instead" / B "Do prank 201. The same one!" | 매번 다른 깜짝 일 / "Classic! …Classic is getting old. Again!" | 정식 |
| 뿔 소굴 | R4 Plan C? | Lv35, 뿔 | `Talk` → `Kill Skeleton 5` → `Choice` | A "Let's make a Plan C!" / B "Plan A, but BIGGER!" | 갈 때마다 다른 발명품 / "PLAN A FOREVER" 깃발 | 나중 |
| 교차로 (장인) | **N3** Both Sides Are Suspicious | M2_3 뒤, 장인 | town 문서 그대로 | A "Send both sides a peace letter" / B **"Sell more spy glasses to both!"** (무기 → 망원경으로 순화) | 티니의 표가 "Suspicious: everyone, for different reasons"로 바뀜 / "Sold out. Again." | **베타** |
| 교차로 (장인) | N4 The Guild Storage Rat | town 문서 그대로 | town 문서 그대로 | town 문서 그대로 | — | 정식 |
| 교차로 (장인) | **N5** Five Stars | Lv12, 장인 | `Talk` Tiny → `Kill KingSlime 3` → `Talk` → `Choice` | A "Fix what they asked for" / B "Write our own five stars" | 매번 새 손님과 새 부탁 / 판에 "5.0 stars (all from us)" | 정식 |
| 교차로 (모두) | **XR1** Lost & Found | Lv5+, 모두 | `Talk` Tiny → `Kill KingSlime 1` (곰인형을 삼킴) → `Talk` → `Choice` | A "Return it to its owner" / B "Sell it at the counter" | 주인마다 다른 이야기 / 언제나 "Thanks for your business." | 정식 |
| 고블린 숲 | **Pip1** Pip's Lamp (M3_4 메아리) | Requires.Pick M3_4 = Good/A, Lv15 | `Near WoodsGate` → `Talk` | 없음 (메아리 보상: 70% 주문서) | 정식: Pip 대사가 레벨마다 바뀜 | **베타** |
| 고블린 숲 | **GW1** Grab Club Meeting | Lv12, 모두, 숲 입구 야영지 | `Near GoblinCamp1 Radius 10` → `Talk` (회의 4쪽) → `Choice` | A "Give the dust back" / B "Grab MORE dust!" | 회의 주제가 "What else can we do?"로 바뀜 / 회의 번호만 오름 #48, #49… | 정식 |
| 해골 유적 | SR1 = EG10 Take a Number | Lv25 | 5-1 참고 | | | 정식 |
| 소라게 해변 | BE1 Shell with a View | Lv15+, 해변이 생길 때 | `Talk` → `Kill` (해변 몬스터) → `Choice` | A "Find him a home" / B "Borrow the King Crab's shell" | 껍데기가 커지고 정원이 생김 / 대왕 소라게: "Hey! That's my house! I'm still paying for it!" | 나중 |
| 호박밭 (시즌) | 호박 대왕 연설 (대사만) | 핼러윈 (11/9까지) | 보스 등장 공지 문구 | 없음 | "Same patch. Same pumpkins. Every year. And I love it!" (즐겁게 고른 되풀이는 괜찮다는 장면) | 베타 (문구만) |

**고칠 점 (검수 결정):** H1의 3단계 "고블린 5"는 Lv10 PvP 지역인데, 열림은 M1_1(Lv1)이었습니다.
- H1·R1·N3은 셋 다 **M2_3 뒤**에 엽니다.
- H1 3단계는 초원 쪽 왕 슬라임으로 바꿉니다.
- 이렇게 하면 세 진영이 같은 때에 '꿍꿍이' 퀘스트를 받습니다.

---

## 4. 다시 나오는 인물

| 이름 (EN) | 자리 · 처음 | 성격 · 말버릇 | 진짜 이유 (EN 한 줄) | 장마다 바뀌는 것 | 모습 |
|---|---|---|---|---|---|
| 브라이트 **Bright** | 빛의 성채 경비 견습(10살쯤), H1 | 규칙책을 든 성실한 경비. "By the book!" 서류 개그(빛의 자기 풍자) | "A knight fixed my kite once. Now I fix things." | 천사 쪽을 고를수록 서류를 하나씩 버리고 새 일을 맡습니다 | 블록 마을 사람 (A23-46) |
| 스모키 **Smokey** | 뿔 소굴 망보는 꼬마(10살쯤), R1 | 꿍꿍이 장인 꼬마. "Plan B: same as Plan A, but sneakier!" | "Nobody ever picked me for their team." | 자루가 작은 자루 → 큰 자루 → 자루 안의 자루. Lv35에 "Ever get bored of Plan A?" (R4) | 블록 마을 사람 |
| 티니 **Tiny** | 교차로, N3 | 클립보드를 든 견습생. "Noted." | "A hammer doesn't pick a side. …Is that a side?" | 표가 자랍니다: "Suspicious: everyone" → "…for different reasons" | 블록 마을 사람 |
| 분수의 조각 **Fountain Shard** | 교차로 분수, M2_3 | 능청맞은 해설자 | — | Pick에 따라 메아리 대사가 달라집니다 | 있음 |
| 왕관 조각 **Crown Shard** | S0·S4, 환생 | 플레이어 짝꿍 | — | 환생 때 내 선택을 기억합니다 | 있음 |
| 그래보 **Grabbo** | 숲 야영지, 3장 | Grab Club 사장. 늘 목표는 "MORE" | "Our woods got dark. We were scared of having nothing." | 회의 번호가 하나씩 오릅니다. M3_4에 따라 주제가 한 번 바뀝니다 | 고블린 우두머리 모델, 싸우지 않음 (정식) |
| 핍 **Pip** | 숲, 3장 | 뭔가 만들고 싶은 막내 | "Can dust make a lamp for the dark woods?" | 천사 쪽: 등불 → 가게 → 새 색. 악마 쪽: 나오지 않음 | 베타는 이름만, 정식은 고블린 모델 |
| 딥스 **Dibs** | 교차로 뒷골목 | 고블린 거래상 | "Business is business. Same business!" | **늘 같습니다:** "Ka-ching! Same as always?" | 베타는 이름만, 정식은 고블린 모델 |
| 서 글림 **Sir Gleam** | 빛의 성채, H3 | 칭찬 하트를 세는 기사 (빛의 함정) | "Helping feels good. Hearts feel… also good?" | 천사 쪽: 매번 다른 누군가를 돕습니다 | 블록 마을 사람 |
| 래스컬 렉스 **Rascal Rex** | 뿔 소굴, R3 | 조회수 집착 장난꾼 (뿔의 함정) | "Boos mean people see me." | 천사 쪽: 매번 다른 깜짝 파티 | 블록 마을 사람 |
| 서 홀트 **Sir Halt** | 유적 입구, 4장 | 300년째 "HALT!" | "The king said: nothing must change." | 천사 쪽: 벤치에서 첫 휴가. 악마 쪽: "HALT! (For you now.)" | 해골 모델 (정식) |
| 클럭 본즈 **Clerk Bones** | 유적 입구 창구, EG10 | 번호표 창구 직원 | "We are open every Tuesday. It is always Tuesday." | 번호가 아주 가끔 하나 오릅니다 | 해골 모델 + 표지판 |
| 해골왕 **Skeleton King** | 왕좌 마당, 5장 | 30분마다 깨어나 같은 연설을 합니다 | "I didn't want to lose anything. So I held on." | 결말 선택 | SkeletonKingClothed 계획 (나중) |
| 늙은 슬라임 **Old Slime** | 초원 큰 바위 뒤, EG07 | 지친 회색 슬라임 | "You bonk me. I pop back. Every day." | 천사 쪽: "OUT OF OFFICE" 팻말 | ~~슬라임 색만 바꿈~~ → 제 모델을 새로(A23-96) (정식) |
| 써니 샘 **Sunny Sam** | 교차로 벤치, EG08 | 한 줄만 말하는 아저씨 | "Nice weather today!" | 새 대사를 배웁니다 | 블록 마을 사람 (정식) |

---

## 5. 게임 속 영어 예시 (쉬운 영어, 한 쪽 1~3줄)

**① 대장장이 (M1_1, 두 겹)**
- "Here's your first weapon. Don't name it. You'll get attached."

**② 언덕 발자국 (M2_6 끝 토스트)**
- "A note in the grass: 'Not goblins. Signed, the goblins.'"

**③ M3_4 Whose Shard? (3장 큰 선택)**
- 1쪽 (LinesBy From=M2_3)
  - Good: "Last time you gave the shard back. The fountain still sparkles."
  - Evil: "Last time you kept the shard. Still shiny in your pocket!"
  - Default: "Another shard. Another choice."
- 2쪽 Pip: "Wait! A tiny goblin followed you home." / "Please, just a little dust? Our woods are so dark at night."
- 3쪽 Pip: "We took it for lamps. Then the big ones kept taking."
- 선택: **[Leave some for their lamps]** / **[Into our vault. They took it first!]**
- 메아리
  - Dibs (바로): "Ka-ching! Same as always? Same as always!"
  - Pip (Lv15): "Look! My own lamp! It glows purple. I never knew purple!"

**④ M3_5 안내자 셋의 진짜 이유**
- 빛: "When the crown broke, I was lost. A stranger gave me their lamp." / "I never knew their name. So now I give mine."
- 뿔: "When the shards fell, we were too far. We got nothing." / "So now we never wait. We take first!"
- 장인: "Both sides break things. We fix them. For both." / "…Is fixing for both sides a side too?"
- 공통 마지막: "And you? Why are you here?"

**⑤ Grab Club 회의 (GW1)**
- Grabbo: "Welcome to Grab Club! This is meeting number 47."
- Grabbo: "Last week we grabbed 100 dust. This week's goal: MORE."
- Pip: "Um, boss? Why do we grab?" / Grabbo: "Because we grabbed last week! Next meeting: right now."
- A 뒤: "Give it… back? Write that down! A new idea!"
- B 뒤: "Same plan, but MORE! Meeting 48 starts now!"

**⑥ Bright와 Smokey (H1·R1, 거울 반전)**
- Bright: "The Horns are up to something! I need Form H-1." / "To get Form H-1, I need Form H-0. …Can you just help?"
- Bright 반전: "Their secret sacks… are full of birthday jelly? For Smokey?"
- Smokey: "Psst! The Halos whisper at the fountain. A secret plan!" / "Plan A: we spy. Plan B: same as Plan A, but sneakier!"
- Smokey 반전: "Their big secret… is a fireworks show? For everyone?"
- 선택: **[Tell everyone the truth]** / **[Keep the rumor going. It's more fun!]**
- 끝 질문 (둘 다): "So who started the rumor? …Does anyone remember?"

**⑦ M4_4 큰 조각 (4장 큰 선택)**
- Sir Halt: "HALT! Who goes there? …Oh, it's you. HALT anyway." / "I say it every day. Every single day."
- Big Shard: "The old king said, 'Nothing must change.' So here, it is always Tuesday."
- Big Shard: "Send me back, and tomorrow can come. Keep me, and they guard for you. Forever."
- 선택: **[Let tomorrow come]** / **[Guard MY vault now!]**

**⑧ 장 끝 질문 셋**
- M3_8: "The goblins took for light. Then they forgot why. What do YOU want the shard for?"
- M4_5: "They forgot why they guard. Do you remember why you fight?"
- M5_5: "If you could keep today forever… would you?"

**⑨ 해골왕 (나중, 30분마다)**
- 깨어날 때: "I am the King of the Same Day! …Did I say this already?"
- 쓰러질 때: "See you in 30 minutes. Same as always."

**⑩ 환생 때 왕관 조각 (Pick 다수결)**
- 대부분 착한 쪽: "You showed me so many new things. Show me more?"
- 대부분 악한 쪽: "We took a lot. It was fun! …What else is out there?"
- 반반: "You went both ways. I can never guess you. I like that."
- 공통: "Who will you be this time?"

---

## 5-1. 어른용 한 겹과 이스터에그

### (가) 이미 있는 퀘스트에 두 겹 입히기 (글자만 바꿈, 베타)
| 자리 | 줄 (EN) | 어른 층 |
|---|---|---|
| M1_2 왕 슬라임 (시작 토스트) | "'I am the KING!' …of this puddle." | 작은 권력 |
| M2_3 분수의 조각 | "The side with more shards remakes the world. …Nobody asked me, of course." | 결정에서 빠진 사람 |
| M2_4 보급로 기금 | 시작: "Our road fund has 3 gold and a button." / 끝: "Road: fixed! Fund: 63 gold and a button." | 예산 |
| 길드 안내자 (N1·N2) | "The Guild takes no sides. We take orders. From both sides." | 장사 |
| 물약 상인 | "Potions! Now with 0% more potion!" | 광고 문구 |
| 호박 대왕 (핼러윈) | "Same patch. Same pumpkins. Every year. And I love it!" | 정겨운 반복 |

### (나) 이스터에그 13개
공통 규칙
- 머리 위 '!'와 마커가 없습니다. 찾는 재미를 위해서입니다.
- 숨은 서브(`Hidden = true`, E5)로 만들고, 찾기 전에는 퀘스트 줄에 보이지 않습니다.
- 첫 10분 흐름을 막지 않도록 교차로 이스터에그는 **M2_3 뒤**에 열고, 반경 6칸으로 길에서 비켜 둡니다.
- 선택은 Pick만 기록하고 점수는 0입니다(1-5). 칭호는 능력치가 없습니다.

| Id | 자리 · 찾는 법 | 대사 (EN) — 아이 층 / 어른 층 | 보상 | 단계 |
|---|---|---|---|---|
| **EG01** Terms of Fate | 교차로 운명의 제단 뒤 두루마리. `Near 6` → `Choice` → `Talk` (LinesBy 자기 Pick) | "TERMS OF FATE (page 1 of 4,000)" **[I agree] / [Read it all]**<br>읽음: "Rule 1: No slimes on the altar. Rule 2: See Rule 1." → "…You're still reading? Nobody reads this far." → "Page 4,000: Be kind. That was the whole thing."<br>동의: "Thanks! You agreed to… something. Not even Fate knows what."<br>/ 아무도 안 읽는 약관 | 칭호 *Actually Read It* / *Didn't Read It* | **베타** |
| **EG02** Patch Note | 교차로 현상수배 게시판 아래 쪽지. `Near 6` → `Talk` | "Patch 0.0.1: The crown is broken. Known issue. We are looking into it." / 패치 노트 | *Bug Reporter* | **베타** |
| **EG03** Goose Fan | 거위 둥지. `Near 6` → `Talk` | "The Golden Goose has 0 followers. She has never been happier." / 팔로워 집착 | *Goose Fan* | **베타** |
| **EG04** Sky Watcher | 교차로 분수. `Near Fountain Stay 30` | 하늘 왕관: "Stop staring. I'm broken, not famous." / 연예인 취급 | *Sky Watcher* | **베타** |
| **EG05** Fun Tips | 쓰러짐 화면 팁(`Config.Death.Tips`). 15번에 1번, 처음 3번 쓰러질 때는 안 나옴 | "Tip: Slimes are 90% jelly and 10% attitude."<br>"Tip: Skeletons can't jump. Please don't tell them."<br>"Tip: Reading tips gives no XP. We checked."<br>"Tip: The goblins had a meeting about this tip. Same plan as last time."<br>/ 로딩 팁 | 없음 | **베타** |
| **EG06** Goblin Notes | 새 소식 창 맨 아래 따로 한 줄, 색 다르게, 주마다 바뀜 | "Fixed: goblins stealing dust. (Not fixed.)"<br>"Known issue: slimes are squishy. Working as intended."<br>"Goblins now steal 0% more. Same as before."<br>/ 패치 노트 | 없음 | **베타** |
| EG07 Old Slime | 초원 남쪽 큰 바위 뒤. `Near 8` → `Talk` → `Choice` | "Oh. You again. You bonk me. I pop back. Every day."<br>A [Take a day off, Old Slime]: "A day… off? What is that?" → "OUT OF OFFICE" 팻말 10분<br>B [One more bonk!]: "Pop! I'm back. See? Nothing changes."<br>/ 노가다·부재중 자동 응답 | *Slime's Day Off* / *Bonk Again* | 정식 |
| EG08 Sunny Sam | 교차로 벤치. `Near 6 Stay 20` (그동안 같은 말을 되풀이) → `Choice` | "Nice weather today!" (하늘이 빨개도) → "…Okay. I have one more line."<br>A [Teach him a new line]: 날마다 다른 말<br>B [Teach him "Pay me 1 gold."] (진짜 골드 없음)<br>/ 한 줄 NPC | *Line Writer* / *Toll Teacher* | 정식 |
| EG09 Goblin Daily Gifts | 숲 입구 판. **서로 다른 날 7번** 읽기(`Days 7`, E10, 연속 아니어도 됨) | "Day 1: Rock. Day 2: Rock. Day 7: BIG ROCK!" → "Your BIG rock! …Same rock. We painted it."<br>A [Give it to a goblin kid] / B [Keep the big rock]<br>/ 출석 보상 | *Rock Giver* / *Rock Keeper* | 정식 |
| EG10 Take a Number | 유적 입구 창구. `Near 8 Stay 20` → `Talk` → `Choice` | "Please take a number. Now serving: 3. Your number: 9,999."<br>A [Tell them tomorrow can come]: "Not coming? …Then what do we do today?"<br>B [Sell a skip-the-line ticket]: "Oh no. There's another line behind this line."<br>/ 줄 서기·창구 | *Line Breaker* / *Ticket Seller* | 정식 |
| EG11 Kingdom Patch Stones | M4_2 아치 3곳, 세 번째에서 `Choice` | "v1.0: Kingdom opens!" → "v1.2: The King says: no more changes. Ever." → "v1.2 (still) / v1.2 (still)"<br>A [Carve "v1.3: Something new!"] / B [Carve "(still)"]<br>/ 업데이트를 멈춘 회사 | *v1.3* / *(still)* | 정식 |
| EG12 Suggestion Box | 왕좌 마당. `Near` → `Talk` | "Can we have a day off? — Guard #12, year 1" / "…year 300" / 왕의 쪽지 "All ideas: no. Today will be like yesterday." / 건의함 | *Idea Haver* | 나중 |
| EG13 Crown Diary | 지역마다 숨은 일기 쪽 8장 | "Day 1 as a crown: said yes to the king. Day 900: said yes. So bored." / 매일 같은 출근 | *Diary Reader* | 나중 — 마지막 쪽: "Last day as a crown: two hands at once. Not one." / "I couldn't pick. Best day ever." |

- **보류:** 고블린 행운 자루(확률 뽑기 풍자). 나중에 뽑기를 팔 계획(GDD §10-1)과 부딪히므로 8절 질문 2의 답을 기다립니다.

### (다) 풍자 금지 목록
- 실제 정치인·정당·선거·투표, 국가·국기·실제 지명, 실존 인물(연예인·스트리머 포함), 실제 브랜드·게임·앱·노래 제목, 유행어 밈.
- 종교 표현: 기도, 천국·지옥, 죄, 경전. 후광과 뿔은 판타지 진영 이름으로만 씁니다.
- 나이·외모·성별·말투·장애를 놀리는 것. 사람 무리(직업 등)를 놀리는 것. 놀리는 대상은 언제나 '행동'입니다.
- 사기처럼 보일 수 있는 말: Robux, free, password, account, code, gift card, "click here", 개인 정보를 묻는 장난. 농담이어도 쓰지 않습니다.
- 진짜 돈·확률 상품. 농담 속 확률도 정직하게 씁니다.
- 연애, 술, 죽음·굶주림·피 농담, 무서운 연출.
- 구매 UI 근처에는 이스터에그를 두지 않습니다.

---

## 6. 베타 · 정식 · 나중

### 6-1. 엔진 추가 (작은 것만)
| # | 무엇 | 담당 | 일수 | 단계 |
|---|---|---|---|---|
| **E0** | 옛 세이브 이전 수정. 지금은 `SQ.Main` 전체를 Done으로 바꿉니다(:318-321). quest_chain 규칙대로 Lv10~24는 `Chapter ≤ 2`, Lv25 이상은 `≤ 3`만 Done으로 바꾸고 다음 장부터 시작합니다. 고치지 않으면 M3를 넣는 순간 Lv10 이상 옛 세이브가 3장을 통째로 건너뜁니다 | 개발 2 | 0.05 | **베타 필수** |
| E1 | `Requires.Pick = { Id = "M3_4", Is = "Good" }` (Good/Purify/A를 한 쪽, Evil/Devour/B를 다른 쪽으로 묶음) | 개발 2 | 0.1 | 베타 |
| E2 | `LinesBy = { From = id, Good, Evil, A, B, Default }`: 진영별 Lines도 됩니다. 서버가 `Var`를 넘기고 Panels:2715가 고릅니다. 고른 쪽이 지난번과 다르면 긍정 토스트 1줄을 띄웁니다(7절) | 개발 2 0.15 + 개발 1 0.2 | 0.35 | 베타 |
| E3 | `Reward.Title` / `Reward.TitleBy = { Good, Evil }` → `TitleService.Grant` + `TitleDefs` | 개발 2 | 0.05 | 베타 |
| E4 | `Near.Stay = 초`: 1초 반복에서 반경 안이면 P+1, 벗어나면 0. 줄에 "%d/%d s"를 보여 줍니다 | 개발 2 | 0.15 | 베타 (H1·R1도 필요) |
| E5 | `Hidden = true` 서브: 찾기 전에는 줄과 Start 토스트를 숨깁니다. `Points = 0`이면 "+0" 대신 기울기 토스트를 띄웁니다 | 개발 2 | 0.15 | 베타 |
| E6 | 선택지별 보상 `Choice.Good.Reward = { Item, N }` / `Evil.Reward = { Gold }` + 공개 `LootService.GrantItem` | 개발 2 | 0.3 | 베타 (마을 사람 퀘스트에도 필요) |
| E7 | `State` 키 `Graduated` (`PvPService.IsRookie` false) | 개발 2 | 0.05 | 정식 |
| E8 | 월드 말 걸기 ProximityPrompt → StoryAction (서버 거리·횟수 검사). 이스터에그를 지나가기만 해도 열리던 것이 누를 때만 열리게 바뀝니다 | 개발 1 0.3 + 개발 2 0.2 | 0.5 | 정식 |
| E9 | StoryWorld: Pick 태그가 붙은 소품을 나에게만 보이거나 숨깁니다(새 클라이언트 모듈. HUD는 local 한도 때문에 쓰지 않음) | 개발 1 | 0.5 | 정식 |
| E10 | 목표 `Days { N }` (서로 다른 날 수) | 개발 2 | 0.1 | 정식 |

### 6-2. 베타 (기능 마감 10/24)
| 항목 | 퀘스트 id | 레벨 | 개발 2 (데이터·서버) | 개발 1 (NPC·연출) |
|---|---|---|---|---|
| E0~E6 | — | — | 0.9일 | Panels LinesBy 0.2일 |
| 장 끝 질문 + 두 겹 대사 (5-1 가) | M1_2, M1_4, M2_3, M2_4, M2_6, M2_7, N1·N2, 물약 상인, 호박 대왕 | 1~10 | 0.2일 (영어 작업에 끼워 넣음) | — |
| 마을 사람 반전 + 열림 수정 | H1, R1, N3 | 약 6+ | 기존 10/15 일정 + 0.1일 | 배치는 기존 마을 키우기 일정. Landmarks WoodsGate 0.05일 |
| 3장 앞 3단계 + 메아리 | M3_1, M3_3, M3_4, Pip1, Speakers (Pip, Dibs, Bright, Smokey, Tiny) | 10~15 | 0.6일 | 이름만 씀, 모델 없음 |
| 이스터에그 + 칭호 5개 | EG01~EG04 | 1+ (M2_3 뒤) | 0.3일 | 표지판 SurfaceGui 3개 + 좌표 0.3일 |
| 재미 팁 · Goblin Notes | EG05, EG06 | — | 0.05일 | 팁 섞기 0.1일 |
| 플레이 확인 | — | — | 오프라인 검사 포함 | 0.3일 |
| **합계** | | | **약 2.2일** | **약 1일** |

- **일정**
  - 10/07 검수: 영어 대사 확정
  - 10/15 개발 2: H1·R1·N3 (기존 일정)
  - 10/16 개발 2: E0~E6
  - 10/17~18 개발 2: 데이터
  - 10/19~20 개발 1: 연출과 플레이 확인
  - 10/21 검수: 디버그 레벨로 Lv10→15 한 바퀴
  - beta_board의 개발 2 스킬 일정과 겹치는지 검수가 확인합니다.
- **밀리면 잘라 내는 순서:** EG04 → EG03 → EG02 → Pip1 메아리(양쪽 같은 Gold/XP로 되돌림) → EG01 → M3_4 LinesBy.
- **끝까지 지킬 것:** E0, M3_1·M3_3·M3_4, 장 끝 질문, H1·R1·N3 반전.

### 6-3. 정식 (12/19)
| 묶음 | 퀘스트 id | 레벨 | 개발 2 | 개발 1 |
|---|---|---|---|---|
| 3장 나머지 | M3_2, M3_5~M3_8 | 10~25 | 0.6일 (+E7) | 야영지 좌표 3곳 (지도 v2에서 다시 확인), Grabbo·Pip·Dibs 모델 0.5일 |
| 4장 | M4_1~M4_5 | 25~35 | 0.6일 | Sir Halt·Clerk Bones, 아치·RuinsGate 좌표 0.4일 |
| 마을 사람 나머지 + 함정 거울 | H2, R2, N4, H3, R3, N5, XR1 | 5~25 | 1.2일 | 블록 NPC 4명 0.4일 |
| 숲 서브 | GW1 | 12 | 0.2일 | 회의 장면 0.2일 |
| 이스터에그 | EG07~EG11 | 1~30 | 0.6일 (+E10) | 0.5일 |
| 메아리 장면 | Pip 가게 / Dibs 노점, 휴가 해골 / 금고 해골, 조각 메아리 토스트, 환생 조각 대사, 회색 전설 한 줄 | — | 0.3일 | E8·E9 0.8일 |
| **합계** | | | **약 4일** | **약 3일** |

### 6-4. 나중
- 5장 M5_1~M5_5와 해골왕 연설(왕좌 마당이 생길 때)
- R4 Plan C, Lv40~50 「Old Friends」
  - 메아리로 만난 친구들이 마지막 퀘스트를 하나씩 줍니다.
  - 악마 쪽 친구도 목표는 매번 다르고, 대사만 "Same job as always?"로 같습니다.
- BE1 (소라게 해변), EG12, EG13
- 환생 '두 번째 길' 다시 고르기(점수 0)
- 행운 자루(8절 질문 2)

---

## 7. 기억하는 것 (진영 바꾸기 · 환생)

- **Pick은 절대 지우지 않습니다.** 진영을 바꿔도, 환생해도 남습니다(지금 동작 그대로). 메아리, LinesBy, StoryWorld는 **지금 진영이 아니라 Pick**을 봅니다.
- **마음을 바꾼 사람 (E2):** 이번 선택이 지난 선택과 반대쪽이면 긍정 토스트 1줄을 띄웁니다.
  - "You kept it last time. Now you give. People change. Shards too."
  - "You gave it last time. Now you keep. Shards change too."
  - 마음을 바꾸는 것도 '새로움'입니다.
- **진영을 바꿀 때**
  - 진행 중인 진영 전용 서브는 빠집니다(:342).
  - 이미 끝낸 퀘스트는 Done으로 남습니다.
  - 새 진영의 서브(H/R/N)는 새로 열립니다. 다른 편의 이유를 직접 겪는 기회가 됩니다.
  - 칭호와 메아리 소품은 그대로 남습니다.
- **환생할 때**
  - `data.Story`(Done, Pick, 카운터)를 건드리지 않습니다(확인함).
  - 이야기는 다시 하지 않습니다.
  - 정식에서는 환생 순간에 왕관 조각 대화 1장을 넣습니다. Pick 다수결이 착함, 악함, 반반 중 무엇인지에 따라 대사가 다릅니다(5절 ⑩).
  - 회색 전설을 얻으면 한 줄을 띄웁니다.
- **칭호:** `data.Titles`에 남습니다. 이스터에그 칭호는 고르기 창에서 '비밀' 묶음으로, 얻은 것만 보입니다.
- **작은 숫자:** 회의 번호, 출석한 날 수 같은 플레이어별 숫자는 `data.Story.N` 안에 둡니다. 따로 `data.Eggs` 표를 만들지 않습니다. 이스터에그도 숨은 서브라 Done과 Pick을 같이 씁니다.
- **옛 세이브:** Pick이 비어 있으므로 모든 LinesBy에 `Default`가 반드시 있어야 합니다. 오프라인 검사에서 Default가 없으면 실패로 처리합니다.

---

## 8. 사용자에게 물을 것

> **사용자 답(2026-10-06 저녁, SPEC A23-55):** 1번은 추천안 대신 **'욕심 때문에 깨졌다'** — "내가 못 가지면 아무도 못 가져!"(황금 거위 배를 가른 동화처럼). 누가 했는지 아무도 모르고, 빛·뿔이 서로 탓하며 사이가 나빠졌다. 진짜 범인은 '혼자 다 갖고 싶은 마음'이고 그건 누구에게나 있다는 것을 4~5장에서 질문으로 보여 준다. 아래 추천안(늘 화요일·거위 웃음)은 쓰지 않고, '늘 화요일' 해골 설정은 욕심 많은 옛 왕의 '아무것도 바꾸지 마라'로 남겨 쓸 수 있다(세션 판단).

1. **"누가 왕관을 깼나" (quest_chain 결정 7-⑦)** — **답함(A23-55, §0-1·§2-2): 빛의 아이 Bright와 뿔의 아이 Smokey가 함께 깼다.** 아래 추천안은 기록용.
   - **추천안:** 균형의 왕관은 하루씩 다음 사람에게 넘겨주는 왕관이었습니다.
     - 옛 왕은 잃는 게 무서워 "아무것도 변하지 마라"를 빌고, 300년 동안 왕관을 벗지 않았습니다. 그래서 매일이 같은 날(늘 화요일)이 되었습니다.
     - 10만 번째 날, 황금 거위가 행진 한가운데에 내려와 "꽥!" 했습니다. 모두가 웃었습니다. 300년 만에 처음 생긴 새 일이었고, 왕관은 그 웃음에 깨졌습니다.
     - 조각을 주운 사람은 그 조각으로 처음 한 일에 따라 후광이나 뿔이 돋았습니다.
   - **장점**
     - 어느 진영도 범인이 아닙니다.
     - "되풀이 대 새로움"이라는 주제가 세계 설정 자체가 됩니다.
     - 거위가 조각을 품은 이유도 함께 풀립니다.
   - 베타는 이 답과 상관없습니다. 정식 4장 복선 전에 정해지면 됩니다.
2. **(급하지 않음) 뽑기 풍자 넣기**
   - 나중에 뽑기 아이템을 팔 계획이 있으니, **그때까지 보류하기를 추천합니다.**
   - 출석 보상 풍자(EG09)는 돈과 상관없어서 넣습니다.
   - 답이 없으면 보류로 둡니다.

## 8-1. 사용자에게 물을 것(남은 것)
없음.

(아래는 검수가 정하고 사용자에게는 묻지 않습니다.)
- Bright·Smokey를 10살·0.8배로 확정 (10/15 전)
- M5_7 점수 +3을 양쪽 같게
- 결말을 정식으로 당길지 (기본 '나중')

돈이 드는 것은 없습니다. 세 번째 끈 액세서리와 시소는 만들 때 따로 승인을 받습니다.
