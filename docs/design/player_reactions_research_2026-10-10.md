# 다른 게임 유저 반응 조사 (2026-10-10)

> 날짜 메모(10/11, A23-119): '10/24 기능 마감'은 **11/24**로 옮겨졌고 공개 베타는 12/1 11:00 KST, 정식 2027년 1월 말. 호박 대왕은 숨김(A23-119)이라 표 1번의 '호박 대왕·클래터 대장' 중 클래터 대장에만 적용.

## 한눈에 — 우리 게임에 넣을 것 TOP 10

| 무엇 (우리 게임에서 구체적으로) | 근거 (게임 + 유저 반응 한 줄) | 크기 | 언제 | 담당 |
|---|---|---|---|---|
| **1. 이미 있음 → 더 좋게: King Slime 큰 착지 전에 바닥 그림자 원.** 지금 몬스터 공격에는 0.28초 빨간 번쩍 예고(A15)가 있다. King 착지에는 떨어진 뒤의 '쿵'·먼지 고리(A23-99)만 있다. 그래서 떨어질 자리에 약 1초 전 둥근 그림자 원을 먼저 보여 준다(글 없음, 빛살 없음). **원 규칙은 언제나 같다: 원 밖이면 안 맞는다.** KO1 첫 단계의 개인 King(A23-110)은 계속 따라 뛴다. 그래서 처음 보는 사람은 거의 반드시 한 번 맞고, "원 안에 있어서 졌다"가 눈에 남는다. 물약·퀵슬롯 뒤 다시 싸울 때(KO1 5단계)는 원을 피해서 이긴다. 호박 대왕·클래터 대장의 큰 공격에도 같은 원을 쓴다. | Arcane Odyssey: 보스 2페이즈의 큰 잡기·광역 때문에 "내 입력이 의미 없다"(AO 포럼 2026-01). 개발자도 경고가 더 필요하다고 인정했다는 글이 같은 글타래에 있다. GPO: 피할 수 없는 공격 때문에 혼자서는 못 깬다(AO 2023-07). The Forge: 적 동작이 안 읽혀서 못 막는다(AO 2025-12, 한 사람 글이라 근거 약함). | S | 베타 전 | 게임성 개발 2 서버(예고 시간·판정, KO1 개인 King) + 게임성 개발 1 클라(바닥 원) |
| **2. 이미 있음 → 더 좋게: 첫 10분 퍼널에 KO1 묶음 더하기.** 이미 기록하는 것: 온보딩 13단계(FirstSkillHit 포함), 대장간까지 걸은 초(ForgeWalk, A23-88), 첫 KO 원인(FirstDeath_), KO 뒤 60초 안에 나감(KOLeave60). 새로 더할 것 ① 따로 퍼널 'FirstKO'(한 번만): King에게 쓰러짐 → 물약 삼 → 퀵슬롯에 넣음 → 마심 → King 이김(KO1 다섯 줄). 13단계 번호는 바꾸지 않고 `Config.Analytics.Funnels`에 더한다. ② Lv5에 닿을 때까지 플레이한 분. 10/17~20 비공개 시험(A23-90 '첫 10분 퍼널')에서 가장 많이 빠지는 한 곳부터 고친다. | Roblox 공식 예시 Plant: 씨앗 심기 단계에서 약 70%가 빠졌고, 아이콘으로 고치는 법을 보여 줬다(DevForum 2024, 고친 뒤 숫자는 없어서 근거 약함). How Fast Can You Go: 튜토리얼을 약 75%가 끝내도 대부분 5~10분 안에 떠난다(개발자 글, DevForum 2026-08). Roblox 리텐션 문서: 온보딩 단계마다 완료율을 보고 크게 빠지는 곳을 고친다. | S | 베타 전(10/17 시험 전) | 게임성 개발 3 서버(+ 게임성 개발 2 KO1 이벤트) |
| **3. 이미 있음 → 더 좋게: 아래 메뉴 칸도 '필요할 때 나타나기'.** 규칙은 이미 있다: UI 정리 원칙 2 '필요해질 때 보여 준다'(`ui_clutter_review_2026-10-09`, `Config.HudReveal`). 스킬 버튼(Lv5)·자동 버튼(해금 뒤)·일일 탭(소개 뒤)도 이미 이렇게 나타난다. 같은 규칙을 아래 메뉴 칸(A23-109)에도 쓴다. 처음에는 가방·퀘스트·지도만 보인다. 스탯 칸은 첫 레벨업, 스킬 칸은 Lv5, 펫 칸은 펫을 받을 때, 순위 칸은 첫 장(M1)이 끝날 때 짧게 톡 나타난다(흔들림을 끄면 바로 나타남). 글 알림은 없다. **퀵슬롯 1·2·3은 처음부터 늘 보인다**(사용자 10/09 "물약 칸 있어야지", A23-109). A23-109 바로 뒤라서 PC 사진을 검수가 사용자에게 보여 준다. | Wall Busters: 메뉴가 붐비고 모양이 제각각이고, 맵은 회색이고 소리가 없다. 개발자 어림으로 약 95%가 바로 나갔다(DevForum 2025-02). 한국 로블록스 갤: "UI가 복잡하지 않으면 노가다가 조금 있어도 괜찮다"(DC 2026-10-10). | S | 베타 전 | 이미지 개발 UI(칸 배치) + 게임성 개발 1 클라(나타나는 때) |
| **4. 이미 있음 → 더 좋게: 손맛 — 남은 두 가지.** 이미 있는 것: 맞은 몬스터 하얀 번쩍(A9-2), 짧은 멈춤·불꽃·작은 카메라 튐(A14-4, 수동만), 밀림(A15), 직업별 휘두르는 그림·소리, 직업별 Lv5 첫 스킬(Shockwave / Meteor / Arrow Rain). 남은 것: ① **A23-108 직업별 쥐는 법·기본 공격 몸짓.** 지금은 Roblox 기본 도구 동작이라 직업마다 같다. 9개 전부가 아니라 3직업(검·지팡이·활) 기본 공격부터 한다. ② **맞는 소리를 직업별로.** 지금은 HitSoft·HitHeavy·HitCrit을 같이 쓰므로 칼·마법·화살 3종으로 나눈다. 10/17 시험에서 해금 직후 자동을 켜는 비율(AutoOn, 이미 기록)을 본다. 자동보다 손으로 칠 때 더 재밌어야 한다. | Throne and Liberty: 자동을 빼자 손맛이 없어서 재미가 없다는 반응(twig24 2023-12). Wall Busters: 소리·효과가 없어 허전하다(DevForum 2025). Dungeon Quest: 후반에는 전사와 마법사가 똑같다(AO 2022-05). | M | 베타 전(A23-108은 이미 베타 전 일) | 게임성 개발 1 클라 + 소리 만들기 |
| **5. 새로: 진영별 PvP 승패 기록.** 이미 기록하는 것: 서버의 진영 인원(ServerPopulation, 5분마다), 진영·레벨대(DaysPlayed), 털기 결과(Plunder_Kept/_Avenged). 없는 것은 진영끼리 PvP 승패다. PvP KO마다 '이긴 진영·진 진영·두 사람 레벨대·덩치 저울 배율'을 한 줄 남긴다. 10/17 시험과 베타 첫 주에 진영별 승률을 보고, 숫자(GDD §5-1 특성, 덩치 저울)는 Config로 고친다. | WoW: 작은 종족 힘 차이 때문에 진영이 오래 한쪽으로 쏠렸다(포럼 2019). 약자 보너스가 문제를 거꾸로 뒤집어 놓기도 했다(EU 포럼 2019, 포럼 2024). Aion: 지는 쪽 인원이 계속 줄었고, 경험치 보너스로는 모자랐다(Engadget 2011). | S | 베타 전(10/17 시험 전) | 게임성 개발 3 서버 |
| **6. 이미 정함 → 앞당기기: 마을 사람이 내 기울기를 알아봄.** A23-64 ① '마을 사람 눈치'는 사용자가 고른 '베타 여유 몫'이다. 대사 표와 서버 값은 이미 있다(`Config.TownReact`: 계급·My Way·마지막 마을 선택에 따라 한 줄, 30초에 한 번, 판단·설교 없음). 없는 것은 말풍선을 띄우는 클라뿐이다. 빛 마을 '완벽' 점검의 ④ 선악 칸으로 앞당겨 빛 마을 차례에 넣는다. 점검표 #39가 "빛 마을 선택 결과가 마을에서 안 보인다"고 적었다. 안내자·물약 상인·문지기도 같은 표를 쓴다. | Fable III: 얼굴은 악마로 변했는데 이야기와 인물이 모른 척해서 "고장 났다"는 평(Game Developer 블로그 2010). Undertale: 게임이 내가 한 일을 기억해 주는 게 좋다(Steam 2021). | S | 베타 전(지금 빛 마을 차례, 일정은 질문 2) | 게임성 개발 1 클라(말풍선) + 게임성 개발 3(대사 검토) |
| **7. 이미 있음 → 더 좋게: 필드 보스 체력을 근처 사람 수에 맞추기.** King Slime 체력은 2500으로 고정이다. 혼자(Lv5~8, 1~2단계 무기) 약 4분이 걸리게 정했는데, 보스는 5분만 머문다(Config). 첫 10분의 King은 KO1 개인 King(물약 2개로 이기는 숫자)이라 이 문제와 따로다. 필드 King은 혼자면 약 2분에 잡히게 기본 체력을 낮추고, 보스 둘레 사람 1명당 체력을 더한다. 괴수의 '근처 기사 1명당 +15%'(GDD 괴수)와 같은 방식이고, 숫자는 개발 2가 시험으로 정한다. 호박 대왕(9000, 혼자 약 4분)·클래터 대장도 같은 방식으로 한다. 기여자 보상 규칙(A23-27)은 그대로다. | GPO: 보스가 너무 단단해서 혼자서는 거의 못 깬다(AO 2023-07). Toram: 사람이 적으면 어려운 보스를 혼자 못 깬다(Steam 2026). | S | 베타 전 | 게임성 개발 2 서버(+ 게임성 개발 3 검증) |
| **8. 베타 뒤 후보 (지표 먼저): 강화 보정 막대.** 실패할 때마다 한 칸씩 차고, 다 차면 다음 한 번은 꼭 성공한다. 성공할 때만 비우고, 몰래 초기화하지 않는다. 10/30/70%·파괴 없음·실패 50% 유지/50% 한 단계 하락(A23-11·14)은 그대로다. 다만 사용자가 실패 규칙을 A23-14에서 다시 확정했다. '강화 하락 완화'도 "베타 지표에서 강화 직후 이탈이 크면 그때 묻는다"고 이미 정해 두었다(`mmorpg_painpoints_ideas_2026-10-05.md` §4). 그래서 지금은 묻지 않는다. 베타의 EnhanceFailLeave(이미 기록)가 크면 그때 이 막대를 안으로 낸다. | 마비노기 모바일: 확정 성공을 축하하고, 램프 3개 = 100% 표시를 반긴다(루리웹 2026-09). 로스트아크: 천장까지 가는 긴 불운에 지친다(루리웹 2026-03). 메이플 키우기: 숨은 확률 오류로 사과하고 환불했다(다음 2026-01). 확률은 보이는 대로여야 한다. | S | 베타 뒤(지표를 보고 사용자에게 질문) | 게임성 개발 2 서버 + 게임성 개발 1 클라(막대) |
| **9. 이미 있음 → 더 좋게: 일일 3칸 중 1칸은 사냥이 아닌 일.** 지금 3칸은 이미 서로 다른 종류로 뽑힌다. 그런데 Monster hunt·Golden hunt·Earn gold·Skill hits가 모두 '사냥'이라 실제로는 같은 일이 된다. Lv10+ 일일 3칸 중 최소 1칸은 사냥이 아닌 종류로 한다: 거위(이미 있음), 새 'Choice' 칸(게시판 Kind 또는 Sneaky 일 1번), 필드 보스 기여. Choice 칸은 GDD §0에 맞고, 하루 장부 6점 상한(A23-86) 안에서 센다. 3칸을 다 하는 데 실제로 몇 분 걸리는지 10/17 시험에서 잰다(보상 기준은 하루 약 25분어치, A23-77). 휴가 70%와 모은 날 출석은 그대로 둔다. | Blox Fruits: 첫 바다는 같은 퀘스트만 반복해서 많이 그만둔다(rowatcher 2026, 리뷰어 한 명의 정리). Ragnarok 신작: 하루 제한·체크리스트가 숙제가 된다(Steam 2026). OSRS: 그만두지 않고 쉬었다 온다(Steam 2026). | S | 베타 전 | 게임성 개발 3 서버 |
| **10. 이미 있음 → 더 좋게: 다른 진영 친구와 만나기 쉽게.** Go to friend(A23-79)는 친구가 상대 진영 마을에 있으면 "Your friend is in the other side's town."이라고만 답한다. 빛·뿔 친구가 같은 서버에 있으면 [Meet up] 한 줄로 둘 다 갈 수 있는 가장 가까운 곳(교차로 분수나 초원 입구)으로 두 사람을 모두 안내한다. 새싹을 PvP 구역으로 보내지 않는 규칙과 보상 0(A23-68)은 그대로다. 아이디어 목록에 이미 있는 '함께 싸운 모험가 카드'와 '진영 화면 친구 OO는 빛의 기사단'(둘 다 원래 정식)은 베타 뒤 첫 업데이트로 당긴다. PvP 휴전은 질문 1에서 정한다(아이디어 목록 '휴전 깃발' 후보와 같은 줄). | WoW: 다른 진영 친구와 길드를 허용하자 "드디어", "고맙다"며 반겼고, 같이 퀘스트·던전도 하게 해 달라는 요청이 이어졌다(EU 포럼 2023-04). Aion 2: 다른 진영과 귓말·친구·파티를 열어 달라는 요청(인벤 2026-08). Ragnarok 신작: 친구가 계속하는 이유로 꼽힌다(Steam 2026). | M | 베타 후(11/04~ 주간 업데이트) | 게임성 개발 3 서버 + 게임성 개발 1 클라 |

- 폰 조작은 이번 조사에 근거가 거의 없어서 넣지 않았다. 폰 라운드(A23-98)에서 따로 본다.

## 피할 것 TOP 8

### 1. 첫 시간이 같은 일의 반복이고, 아무것도 안 알려 줌
- **유저 반응:**
  - Blox Fruits 첫 바다에서 많이 그만둔다(rowatcher 2026).
  - Deepwoken·GPO는 설명과 지도가 없어서 위키를 봐야 한다(AO 2022-04, 2023-07).
  - 99 Nights는 기계 번역된 퀘스트 글 때문에 한국 유저가 헷갈렸다(DC 2026-09).
- **우리 위험:**
  - 첫 10분 할 일이 대부분 '슬라임 잡기'다: 보급로 슬라임 5마리 → Slime Prince 2마리(M1_2) → 스킬로 맞히기(M1_3) → King(KO1). 사이에 대장간, 도시락 선택(A23-70), 아기 슬라임 펫(PET-4)이 있다. 꽃 슬라임 선택(A23-87)은 늦으면 먼저 빼는 목록에 있다(RELEASE_PLAN 자를 순서표).
  - 덜 친절한 화면(A23-99)이 너무 나가면 원한 자루·덩치 저울·강화 옮기기를 모르고 지나간다.
  - 한국어 모드(A23-111) 번역 초안을 그대로 쓰면 99 Nights 같은 혼란이 생긴다.
- **막기:**
  - 10/17 시험 퍼널로 도시락 카드와 아기 슬라임이 첫 10분 안에 실제로 나오는지 본다.
  - 거위(A23-15)·일일(A23-104)·퀵슬롯(A23-109)처럼, 원한 자루·강화 옮기기 주문서·덩치 저울도 처음 만날 때 퀘스트 한 줄이 있는지 개발 3이 확인한다. 없으면 같은 틀로 한 줄 둔다.
  - 한국어 글은 A23-111대로 검수가 확인한다. 첫 10분 글부터 실제 화면에서 읽고 고친다.

### 2. 안 읽히는 보스와 억울한 한 방
- **유저 반응:** Arcane Odyssey 보스 2페이즈(AO 2026-01, 개발자도 경고 부족을 인정했다는 글), GPO의 피할 수 없는 공격(AO 2023-07).
- **우리 위험:**
  - KO1 첫 단계는 King 한 방이다(A23-110). 예고 없이 쓰러지면 연출이 아니라 억울함으로 읽힌다.
  - 필드 King Slime과 호박 대왕은 혼자 잡는 데 각각 약 4분이 걸린다. 그런데 King은 5분만 머문다.
- **막기:** TOP 1번과 7번.

### 3. 손맛 없는 수동 전투, 잠수 자동 사냥이 최고 전략이 되는 것
- **유저 반응:**
  - Throne and Liberty는 자동을 빼자 손맛이 없다는 반응이었다(twig24 2023-12).
  - MapleStory M·Ragnarok 신작은 처음 1~2시간 유저가 "게임이 혼자 한다"며 그만뒀다(Steam 2026, MapleStory M은 리뷰 88개라 표본이 작음).
  - Bee Swarm 엔드게임은 24시간 매크로를 전제로 한다(DC 2026-03). Fisch는 서버 절반이 매크로라는 글이 있다(DC 2024-11).
- **우리 위험:**
  - 공격 몸짓이 아직 Roblox 기본 도구 동작이고 직업마다 같다(A23-108, RELEASE_PLAN '공격 모션 단조로움'). 휘두르는 그림·소리와 첫 스킬은 이미 직업마다 다르다.
  - 자리를 비워도 자동 사냥은 계속된다(A23-20). 상한은 Roblox 20분 무입력 퇴장인데, 매크로로 넘기면 초원 자리를 차지한다.
  - 자동이 Lv5 뒤에 열리는 것은 맞다. 그대로 지킨다.
- **막기:** TOP 4번. 초원 자리 차지는 이미 있는 기록(초원의 Lv20+ 수 HighLevelInMeadow, AutoOn)으로 보고, A23-20대로 베타 지표 뒤에 사용자에게 다시 묻는다.

### 4. 진영 사이 작은 힘 차이 때문에 한쪽으로 쏠림
- **유저 반응:**
  - WoW는 호드 종족 특성 차이로 오래 쏠렸다(포럼 2019). 약자 보너스가 문제를 거꾸로 뒤집기도 했다(EU 포럼 2019, 포럼 2024).
  - Aion은 지는 쪽 인원이 계속 줄었고, 경험치 보너스로는 모자랐다(Engadget 2011).
  - Aion 1에서는 스킬 효율 차이에 크게 화냈다(게임메카 2009).
  - 반대로 KOTOR는 빛 = 버티기·치유, 어둠 = 피해처럼 역할이 다르면 양쪽 다 세다고 느꼈다(Steam 2015).
- **우리 위험:**
  - 빛은 체력 +20%·초당 2% 회복, 뿔은 공격 +15%·흡혈 10%다(GDD §5-1). KOTOR처럼 역할은 다르지만 숫자로 된 힘 차이라서, WoW처럼 쏠림의 이유가 될 수 있다.
  - 덩치 저울(약한 편 최대 1.6배), 약한 편 +300골드, 환생 +40%가 이미 있다. WoW처럼 이 약자 보너스가 거꾸로 뒤집을 수도 있다. 쏠림은 베타에서 처음 보인다.
- **막기:** 진영별 인원·레벨대는 이미 기록된다(ServerPopulation, DaysPlayed). 없는 진영별 PvP 승패는 TOP 5번에서 넣는다. 숫자는 Config로 바로 고친다.

### 5. 신규 갱킹, 복수가 괴롭힘이 됨
- **유저 반응:**
  - Aion 2는 출시 이틀 만에 고렙이 저렙을 학살했다(퀘이사존 2025-11).
  - Deepwoken은 신규가 갱킹당한다(AO 2022-08).
  - Steal a Brainrot은 게임 속 도둑질이 학교 다툼으로 번졌다(Automaton 2026). 한 사람만 쫓는 게 재미라는 글도 있다(DC 2026-01, 한 사람 글).
- **우리 위험:**
  - 막는 장치는 많다: 새싹 보호(Lv15·60분 + 졸업 60초 유예), 깡패 규칙(같은 상대 반복 KO 포함), 무단 PvP 판(같은 상대는 주 4번째부터 셈), 유적 바깥 PvP 끔.
  - 남은 곳 하나: 새싹 보호가 막 끝난 Lv15~20이 고블린 숲에서 고렙에게 계속 쓰러지는 기분이다. 상대 보상이 0이어도 기분은 나쁘다.
  - 남은 곳 둘: 보라 화살표를 따라 서버의 기사 모두가 도둑 한 명을 쫓는 장면이 아이에게는 '몰이'로 느껴질 수 있다.
- **막기:** 10/17~20 시험에서 털기 금액(A23-90 목록)과 함께 두 가지를 잰다. ① 같은 사람이 하루에 몇 번 쓰러지는지(새 기록 한 줄, 개발 3) ② 도둑이 45초를 버틴 비율(Plunder_Kept/_Avenged, 이미 기록). 반복 KO가 많으면 깡패 숫자를 고친다. 도둑이 거의 못 버티면 자루 시간과 화살표를 고친다.

### 6. 확률을 숨기거나 몰래 바꾸거나, 아주 낮은 확률로 쫓게 함
- **유저 반응:**
  - 메이플 키우기는 숨은 확률 오류로 사과하고 환불했다(다음 2026-01).
  - Grow a Garden은 0.08% 펫 때문에 개발자가 사과했다(Dexerto 2025-07).
  - Pet Simulator 99 알 뽑기에 큰돈을 쓰고도 원하는 펫을 못 얻었다는 댓글이 있다(DevForum 2024-07, 한 사람 주장이라 금액은 뺐다).
- **우리 위험:**
  - 슬라임 '대박' 전설 무기는 1/20,000(0.005%, `Config.Loot.Jackpot`)이다. Grow a Garden 0.08%보다 16배 낮다. 확률은 이미 'What Monsters Drop' 창에 "1 in 20,000"으로 보인다. 팔지 않고 사냥으로만 나온다는 점은 다르다.
  - 사람마다 드롭이 다르다: 주간 1~3위 +10%(대박 제외), 무법자·깡패 ×0.5(대박도 절반), 오늘의 운.
- **막기:**
  - 대박은 '깜짝 선물'로 둔다. 퀘스트·일일·순위가 대박을 쫓게 만들지 않고, "아깝다!" 연출을 넣지 않는다(`psychology_retention_2026-10-08.md` 규칙 그대로).
  - 'What Monsters Drop' 창 아래에 지금 내 드롭 배수를 한 줄 보여 준다(예: "Your drops now: ×0.5 (Outlaw)").
  - 이벤트 중에 확률을 몰래 바꾸지 않는다. 바꾸면 그 창의 숫자도 같이 바뀐다.
  - 강화 확률 표시는 이미 있으니 그대로 둔다.

### 7. 돈과 물건에 대한 신뢰가 깨짐
- **유저 반응:**
  - Blox Fruits는 이미 산 열매를 토큰으로 바꿔서 '사기'라는 말을 들었다(Distractify 2024-12).
  - 2x EXP 패스는 페이투윈이라는 인식이 있다(rowatcher 2026, 리뷰어 한 명).
  - OSRS는 광고·짧은 잠수 타이머 같은 유료 등급 아이디어를 설문에 넣었다가 CEO가 사과했다. 회원끼리 게임 차이를 만들지 않겠다고 약속했다(2025-01-17).
  - Adopt Me·Grow a Garden은 거래 사기가 많았다(Common Sense, Dexerto). PS99 거래 사기로 그만둔 글도 있다(DC 2026-01).
- **우리 위험:**
  - 2배 패스로 얻은 레벨·골드는 레벨 상한·랭킹에 그대로 들어간다(A23-75, 사용자 "그래야 사지"). 지금 판 4개(명예·악명·장인 명성·PvP)는 레벨·골드를 세지 않는다. 성장·전투력 판은 만들지 않기로 사용자가 정했다(A23-23). Tab 목록에는 레벨·전투력이 보이고 골드는 숨긴다(A23-21).
  - VIP 왕관 이름표가 계급처럼 보이면 안 된다(A23-75 '번 모양 ≠ 산 모양'을 지킨다).
  - 정식 때 경매장과 펫 입양이 들어온다(A23-13).
- **막기:**
  - 패스 설명에 하는 일을 그대로 적는다: "레벨·골드가 2배 빨리, 능력치는 안 팖".
  - 산 패스·치장을 나중에 약하게 바꾸지 않는다. 꼭 바꿔야 하면 먼저 사용자에게 묻는다(돈 = 사용자).
  - 무료였던 편의를 패스 뒤로 옮기지 않는다.
  - 경매장 안전 규칙(사기·대가 요구 방지, 가격 상한·하한)은 아이디어 목록에 이미 있다. '먼저 주고 기다리기' 없이 양쪽이 한 창에서 확인하고, 가격을 보여 준다.

### 8. 숙제, 한정 압박, 늦은 업데이트
- **유저 반응:**
  - MapleStory는 한 이벤트에 한 달 50시간 넘게 들어서 놓칠까 봐 불안했다(Steam 2026).
  - Grow a Garden은 주간 이벤트가 반복적이었고(개발자 인정), 길어진 이벤트에 지쳤다(GameRant 2025, roonby 2026).
  - Sol's RNG는 지연과 약속 뒤집기로 반발을 샀다(roonby 2024).
  - Arcane Odyssey는 업데이트 뒤 몇 주만 붐볐다(AO 2024-02).
- **우리 위험:**
  - 매주 수요일 업데이트(A23-83)가 '복사해 붙인 주간 행사'가 될 수 있다.
  - 핼러윈은 11/09에 끝난다.
  - 홈페이지·쇼츠에 날짜를 먼저 말하면, 늦어질 때 반발이 생긴다.
- **막기:**
  - 주간 업데이트는 작은 고침으로 하고, A23-83의 게임 안 'New this week' 칸에 다음 주 예고 한 줄('Coming next')만 더한다.
  - 날짜는 확실할 때만 말한다.
  - 핼러윈은 '매년 돌아와요'(아이디어 목록 P10)로 하고, 사탕 단지는 계속 열어 둔다(A23-79 그대로).

## 사용자에게 물을 것

1. **로블록스 친구끼리는 빛·뿔이어도 PvP 구역에서 서로 안 맞게 할까요?** (PvP 규칙)
   - 지금은 친구 KO가 순위에서만 빠지고(A23-23), 서로 때리는 것은 됩니다.
   - 아이디어 목록의 '휴전 깃발'(다른 편 친구와 3분 휴전)보다 단순한 안입니다.
   - 추천: 친구끼리는 안 맞게 한다. 원하면 둘 다 켜는 결투는 나중에 만든다.
2. **TOP 1~7과 9를 10/24 기능 마감 전에 넣어도 될까요?** (일정)
   - 모두 작은 일(S)이고 4번(손맛)만 중간(M)입니다. 빛 마을 일과 나란히 개발 1·2·3이 합니다.
   - 6번은 사용자가 고른 '베타 여유 몫'(A23-64 ①)을 빛 마을 차례로 앞당기는 것입니다.
   - 8번(강화 보정 막대)과 10번은 베타 뒤입니다.
   - 늦으면 RELEASE_PLAN 자를 순서표를 따르고, 이 중에서는 9 → 6 → 7 순서로 베타 뒤로 미룹니다.
   - 추천: 넣는다.
3. **베타 뒤에 정해진 시간 행사(예: 주말 30분 '왕관 축제')를 만들면, 지역마다 낮 시간에 두 번 열까요?** (일정)
   - 예: 한국 토요일 14:00 + 미국 토요일 낮(서부 12:00 = 한국 일요일 04:00).
   - 그 나라 시간으로 밤 10시~아침 7시는 피합니다.
   - 근거: Steal a Brainrot 새벽 행사 때문에 아이들이 잠을 못 잤습니다(Automaton 2026).
   - 추천: 두 번 연다.

(지난 판의 '강화 보정 막대'와 '레벨 순위판' 질문은 뺐습니다. 앞의 것은 베타 지표를 본 뒤에 묻기로 이미 정해져 있습니다. 뒤의 것은 사용자가 A23-23·A23-75에서 이미 정했습니다.)

## 게임별 장점·단점

(근거 약함) = 한 사람 글이거나, 교차 확인에서 약하다고 나온 것이다. 확인되지 않은 숫자는 뺐다.

### Blox Fruits (로블록스 RPG)
- 좋음: 화려한 이펙트와 PvP 손맛이 있고, 단순해서 아이들이 좋아한다. — [AO 포럼 2023-02](https://forum.arcaneodyssey.dev/t/why-is-blox-fruits-popular/85075)
- 좋음: 로벅스는 속도만 올리고 끝 콘텐츠는 그대로라서, 노가다한 사람이 보상받는 느낌이다. — [Naavik 2024-01](https://naavik.co/digest/blox-fruits-lessons/) (분석가의 해석)
- 좋음: 한국 유저도 콘텐츠가 많고 PvP·바다 활동이 재밌다며 추천한다. — [DC 로블록스 갤 2026-09](https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=102552)
- 싫음: 첫 바다(Lv1~700)가 반복이라 많이 그만둔다. 패스 없이 만렙까지 80~120시간. — [rowatcher 2026](https://rowatcher.com/news/is-blox-fruits-worth-playing-in-2026-an-honest-review) (리뷰어 한 명의 정리)
- 싫음: 이미 산 Dragon 열매를 토큰으로 바꿔서 '사기', 신뢰를 잃었다는 반응이 나왔고, 그날 접속도 막혔다. — [Distractify 2024-12](https://www.distractify.com/p/why-is-blox-fruits-private) (재구매 가격 숫자는 기사에 없어서 뺐다)
- 싫음: 2x EXP 패스가 페이투윈이라는 인식이 있고, 공개 서버 갱킹과 원샷 콤보가 많다. — [rowatcher 2026](https://rowatcher.com/news/is-blox-fruits-worth-playing-in-2026-an-honest-review), [AO 포럼 2023](https://forum.arcaneodyssey.dev/t/why-is-blox-fruits-popular/85075)

### Deepwoken (로블록스, 유료 입장)
- 좋음: 막기·패링·강공격이 타이밍과 위치를 잘 보상한다. — [AO 2022-04](https://forum.arcaneodyssey.dev/t/a-review-of-deepwoken/73730)
- 좋음: 처음 가는 섬마다 적과 이벤트가 달라서 탐험이 재밌다. — [AO 2022-08](https://forum.arcaneodyssey.dev/t/your-thoughts-on-deepwoken-sort-of-a-rant-as-well/76821)
- 좋음: 친구·길드와 하면 좋고, 캐릭터를 다시 키우는 것을 새 빌드 기회로 본다. — [AO 2024-12](https://forum.arcaneodyssey.dev/t/should-i-play-deepwoken/143253)
- 싫음: 거의 아무것도 알려 주지 않아서 위키가 필수다. — [AO 2022-04](https://forum.arcaneodyssey.dev/t/a-review-of-deepwoken/73730), [AO 2024-12](https://forum.arcaneodyssey.dev/t/should-i-play-deepwoken/143253)
- 싫음: 영구사망 때문에 느린 초반을 반복해야 하고, 갱킹 위험은 신규에게만 크다. — [AO 2022-08](https://forum.arcaneodyssey.dev/t/your-thoughts-on-deepwoken-sort-of-a-rant-as-well/76821)
- 싫음: 유료 1회 부활 상품이 영구사망을 돈벌이로 만든다는 비판이 있다. — [AO 2024-12](https://forum.arcaneodyssey.dev/t/should-i-play-deepwoken/143253)

### Arcane Odyssey (로블록스)
- 좋음: 콤보에 갇히지 않고 늘 반격할 수 있고, 회피·대시의 손맛이 좋다. — [AO 2026-06](https://forum.arcaneodyssey.dev/t/thoughts-on-arcane-odyssey-combat-system/161107)
- 좋음: 기본 마법이 20개라 모두가 같은 조합을 고르지 않는다. — [AO 2024-09](https://forum.arcaneodyssey.dev/t/about-arcane-odysseys-base-magics-as-a-whole/136958)
- 좋음: 업데이트 직후 몇 주는 크게 붐빈다. — [AO 2024-02](https://forum.arcaneodyssey.dev/t/what-makes-arcane-odyssey-dead/123940)
- 싫음: 보스 2페이즈는 큰 잡기와 광역 때문에 입력이 의미 없다. 개발자도 큰 잡기에 경고가 더 필요하다고 인정했다는 글이 있다. 렉·물약 실패 같은 버그도 있다. — [AO 2026-01](https://forum.arcaneodyssey.dev/t/a-disappointment/156394) (버그 목록은 한 사람 글)
- 싫음: NPC·보스 AI가 단순하고, 거리를 두면 멈춘다. — [AO 2026-06](https://forum.arcaneodyssey.dev/t/thoughts-on-arcane-odyssey-combat-system/161107)
- 싫음: 콘텐츠를 다 쓰면 빠지는 '동면'이 있고, 개발자가 피드백을 안 듣는다는 불만이 있다. — [AO 2024-02](https://forum.arcaneodyssey.dev/t/what-makes-arcane-odyssey-dead/123940), [AO 2025-01](https://forum.arcaneodyssey.dev/t/why-arcane-odyssey-is-dying/144191)

### Grand Piece Online (로블록스)
- 좋음: 친구와 하면 재밌고 열매·능력이 다양하다. — [AO 2021-05](https://forum.arcaneodyssey.dev/t/whats-good-about-gpo/60178)
- 좋음: 기본 공격이 여러 적을 맞히고, 레벨업이 약 30% 빨라지고, 물약이 쓸모 있어졌다는 칭찬. — [AO 2023-11](https://forum.arcaneodyssey.dev/t/actual-good-gpo-update/119023) (한 사람 글이라 근거 약함)
- 좋음: 로벅스 없이 포인트로 확정 교환할 수 있고, 신화 상자는 오래 걸려도 결국 확정으로 나온다. — [AO 2023-11](https://forum.arcaneodyssey.dev/t/actual-good-gpo-update/119023) (같은 한 사람 글이라 근거 약함)
- 싫음: 보스가 단단하고 피할 수 없는 공격이 있어서 혼자서는 거의 못 깬다. — [AO 2023-07](https://forum.arcaneodyssey.dev/t/gpo-rant-reasons-why-gpo-sucks/108792)
- 싫음: 게임 안에 지도가 없고 안개 때문에 위키에 의존한다. 열매 보관함·리셋은 유료다. — [AO 2023-07](https://forum.arcaneodyssey.dev/t/gpo-rant-reasons-why-gpo-sucks/108792)
- 싫음: 레벨은 '그냥 있는 숫자'로 느껴지고, 지루해서 떠난다. 레벨 상한을 올리며 성장폭을 줄였다는 불만도 있다. — [AO 2023-11](https://forum.arcaneodyssey.dev/t/actual-good-gpo-update/119023) (두 사람 글), [AO 2023-02](https://forum.arcaneodyssey.dev/t/grand-piece-online/84637?page=4)

### The Forge (로블록스, 2025 말 인기)
- 좋음: 광석을 캐고 돌아와 내 장비를 만드는 루프가 좋다. — [AO 2025-12](https://forum.arcaneodyssey.dev/t/has-anyone-played-the-forge-yet/154186)
- 좋음: 할수록 좋아지고, 퀘스트·채광·제작으로 성장한다. 무료 리롤 추가로 개발자를 믿게 됐다. — [AO 2025-12 3쪽](https://forum.arcaneodyssey.dev/t/has-anyone-played-the-forge-yet/154186?page=3)
- 좋음: AFK 채광 지점이 가볍게 하는 사람에게 도움이 된다. — [roonby 2026-01](https://roonby.com/2026/01/05/players-are-mad-about-the-forge-raven-cave-update/)
- 싫음: 제작 결과가 너무 랜덤이다(네 사람). 가진 것보다 나쁜 중복 장비가 나온다는 글도 있다. — [AO 2025-12](https://forum.arcaneodyssey.dev/t/has-anyone-played-the-forge-yet/154186) (중복 장비는 한 사람 글이라 근거 약함)
- 싫음: 적 동작이 안 읽혀서 못 막고, 패스 없이는 시간 낭비라는 인식이 있다. — [AO 2025-12](https://forum.arcaneodyssey.dev/t/has-anyone-played-the-forge-yet/154186) (각각 한 사람 글이라 근거 약함)
- 싫음: 상위 갑옷을 약 1/54,000 확률 재료 뒤에 잠갔고, VIP 서버 재접속으로 스폰을 강제할 수 있다. — [roonby 2026-01](https://roonby.com/2026/01/05/players-are-mad-about-the-forge-raven-cave-update/) (블로그 정리라 근거 약함)

### Dungeon Quest (+ World // Zero, 로블록스)
- 좋음: 단순하지만 중독적인 루프다. — [AO 2021-02](https://forum.arcaneodyssey.dev/t/no-good-rpg-style-games-left/54317)
- 좋음: 첫 두 던전은 개성이 있었고, 레이드를 열어 다른 사람을 받아 주는 재미가 있었다. — [AO 2022-05](https://forum.arcaneodyssey.dev/t/dungeon-quest-a-criticism/74325)
- 싫음: 새 던전이 적만 바뀐 같은 구조다. 후반에는 전사와 마법사가 똑같아진다. — [AO 2022-05](https://forum.arcaneodyssey.dev/t/dungeon-quest-a-criticism/74325) (한 사람의 긴 글, 댓글 대부분 동의)
- 싫음: 전설이 보상 칸당 약 1/500이고, 결제자만 추가 보상 칸을 받는다. — [AO 2022-05](https://forum.arcaneodyssey.dev/t/dungeon-quest-a-criticism/74325)
- 싫음: 금방 지루해지고, 맵은 퀘스트 사이를 옮겨 다니는 용도뿐이다. — [AO 2021-05](https://forum.arcaneodyssey.dev/t/recommend-me-good-roblox-games-that-i-should-spend-my-time-grinding-to/60619), [DevForum 2022-11](https://devforum.roblox.com/t/how-to-make-a-open-world-rpg-game-fun/2059404)

### Grow a Garden (로블록스)
- 좋음: 느긋해서 어린 아이와 가족이 같이 한다. 고수가 신규에게 선물을 준다. — [AP/KSAT 2025-07](https://www.ksat.com/business/2025/07/30/millions-are-flocking-to-grow-virtual-gardens-in-viral-roblox-game-created-by-teenager/), [NBC 2025-07](https://www.nbcsandiego.com/entertainment/entertainment-news/virtual-gardens-viral-roblox-game-created-teenager/3879694/)
- 좋음: 안 해도 작물이 자라고, 공용 상점이 5분마다 바뀌어서 자주 들어온다. — [AP/KSAT 2025](https://www.ksat.com/business/2025/07/30/millions-are-flocking-to-grow-virtual-gardens-in-viral-roblox-game-created-by-teenager/)
- 좋음: 주말 라이브 행사 때 동시 접속이 약 2,200만이었다. — [Dexerto 2025-08](https://www.dexerto.com/roblox/roblox-smashes-concurrent-user-record-thanks-to-war-between-two-games-3242035/)
- 싫음: 거래창이 생기기 전에 사기가 판쳤고, 0.08% 펫 때문에 개발자가 사과했다. — [Dexerto 2025-07](https://www.dexerto.com/roblox/grow-a-garden-finally-getting-trading-amid-complaints-of-rampant-scamming-3230688/)
- 싫음: 주간 이벤트가 반복적이었고(개발자 인정), 길어진 이벤트에 지쳐서 쉬거나 그만뒀다. — [GameRant 2025-08](https://gamerant.com/roblox-grow-a-garden-weekly-events-changes/), [roonby 2026-05](https://roonby.com/2026/05/03/grow-a-garden-bizzy-bee-update-delayed-community-starts-to-split/) (이벤트를 없애면 그만둘까 걱정하는 쪽은 독자 한 명이라 근거 약함)
- 싫음: AFK 타이머 행사, 무료였던 편의를 로벅스로 바꿈. — [IGGM 2025-12](https://www.iggm.com/news/grow-a-garden-christmas-event-part-2-why-are-players-disappointed-leaving) (아이템 판매 사이트라 근거 약함)

### Steal a Brainrot (로블록스)
- 좋음: 빈 기지를 털어 희귀 캐릭터를 얻는 짜릿함이 있다. — [Kotaku 2025-07](https://kotaku.com/steal-a-brainrot-roblox-empire-review-popular-memes-1851787027)
- 좋음: 모은 캐릭터가 계속 돈을 벌어서 무언가를 쌓는 느낌이 든다. — [Kotaku 2025](https://kotaku.com/steal-a-brainrot-roblox-empire-review-popular-memes-1851787027)
- 좋음: 라이브 행사 때 동시 접속이 1,500만을 넘었다. — [Dexerto 2025-08](https://www.dexerto.com/roblox/roblox-smashes-concurrent-user-record-thanks-to-war-between-two-games-3242035/)
- 싫음: 쌓은 걸 털리면 진짜 화가 나고, 다 해 보면 지루하다. 도망치려고 로벅스를 쓰게 하는 구조가 잔인하다는 평. — [Kotaku 2025](https://kotaku.com/steal-a-brainrot-roblox-empire-review-popular-memes-1851787027)
- 싫음: 게임 속 도둑질이 학교 다툼과 현금 거래로 번졌고, 새벽 행사 때문에 아이들이 잠을 못 잤다. — [Automaton 2026-05](https://automaton-media.com/en/wp-json/wp/v2/posts/66028), [DC 2025-12](https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=85383) ('새벽 3~4시'라는 숫자는 확인 안 됨)
- 싫음: 한 사람만 쫓아서 게임을 나가게 만드는 게 재미라는 글이 있다. — [DC 2026-01](https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=87683) (한 사람 글)

### 99 Nights in the Forest (로블록스)
- 좋음: 모르는 사람과도 함께 지키고 구조하는 게 재밌어서 새벽까지 했다. — [DC 2025-07](https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=78368), [DevForum 2025-10](https://devforum.roblox.com/t/creator-spotlight-the-story-behind-99-nights-in-the-forest/4036940)
- 좋음: 재미가 분명한 새 직업(나무를 무한으로 모음)은 바로 칭찬받았다. — [DC 99밤 갤 2026-09](https://gall.dcinside.com/mgallery/board/view/?id=robloxforest99&no=377)
- 좋음: 모아 둔 다이아가 1년 만에 돌아올 이유가 됐다. — [DC 2026-08](https://gall.dcinside.com/mgallery/board/view/?id=robloxforest99&no=371)
- 싫음: 새 유료 직업이 기대에 못 미쳐서 사지 말라는 글이 나왔다. — [DC 2025-12](https://gall.dcinside.com/mgallery/board/view/?id=robloxforest99&no=167) (한 사람 글이라 근거 약함)
- 싫음: 라이브 행사 보상이 나오기 전에 다들 나갔고, 운영자가 직업을 강제로 바꿨다. — [DC 2026-01](https://gall.dcinside.com/mgallery/board/view/?id=robloxforest99&no=189)
- 싫음: 기계 번역된 퀘스트 글이 헷갈리고, 몇 주 업데이트가 없으면 바로 불만이 나온다. 가이드 없이는 가족이 하기 어렵다. — [DC 2026-09](https://gall.dcinside.com/mgallery/board/view/?id=robloxforest99&no=379), [DC 2026-05](https://gall.dcinside.com/mgallery/board/view/?id=robloxforest99&no=340), [DC 2026-07](https://gall.dcinside.com/mgallery/board/view/?id=robloxforest99&no=361)

### Adopt Me! (+ Common Sense Media의 로블록스 리뷰)
- 좋음: 펫 모으기·돌보기·같이 놀기가 좋다. 화면 화살표 덕분에 배우기 쉽다. — [Common Sense 2025-12](https://www.commonsensemedia.org/website-reviews/adopt-me)
- 좋음: 새 이벤트 알이 예쁘다고 반긴다. 4년 만에 돌아와도 내 펫이 여전히 의미 있다. — [DC 입양하세요 갤 2026-09](https://gall.dcinside.com/mgallery/board/view/?id=growme&no=164), [DC 2026-04](https://gall.dcinside.com/mgallery/board/view/?id=growme&no=137)
- 싫음: 사기·불공정 거래·괴롭힘이 가장 큰 걱정이다. 사기로 펫을 잃은 글, 중개인이 무섭다는 글이 있다. — [Common Sense](https://www.commonsensemedia.org/website-reviews/adopt-me) (리뷰 요약 기준, 전문가 리뷰에는 괴롭힘 언급 없음), [DC 2024-03](https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=57064), [DC 2026-03](https://gall.dcinside.com/mgallery/board/view/?id=growme&no=132)
- 싫음: 갤러리 대화가 가격·현금 거래 위주이고, 신규가 안 들어오면 의욕이 없다. — [DC 갤 목록](https://gall.dcinside.com/mgallery/board/lists/?id=growme), [DC 2026-09](https://gall.dcinside.com/mgallery/board/view/?id=growme&no=164)
- 싫음: 목표가 분명하지 않으면 아이들이 헤매고 지루해한다. 나이 표시를 믿기 어렵고 폭력 장면이 빨리 나온다. — [Common Sense 인기 게임 목록 2025-07](https://www.commonsensemedia.org/lists/popular-games-on-roblox), [Common Sense 로블록스 가이드 2026-08](https://www.commonsensemedia.org/website-reviews/roblox)

### Bee Swarm Simulator (로블록스)
- 좋음: 큰 업데이트 날 충성 유저가 바로 돌아온다. — [DC 2024-07](https://gall.dcinside.com/mgallery/board/view/?id=beeswarmsimulator&no=309)
- 좋음: 다 아는 상태로 부캐를 키우는 게 재밌다. — [DC 2026-10](https://gall.dcinside.com/mgallery/board/view/?id=beeswarmsimulator&no=2367)
- 좋음: 몇 년이 지나도 새 유저가 들어온다. — [DC 갤 목록 2026](https://gall.dcinside.com/mgallery/board/lists/?id=beeswarmsimulator)
- 싫음: 업데이트가 느려서 일정이 다 꼬인다. 운뿐인 수집 + 보상 없는 도전 = 최악의 이벤트라는 평. — [DC 2026-06](https://gall.dcinside.com/mgallery/board/view/?id=beeswarmsimulator&no=2133), [DC 2024-07](https://gall.dcinside.com/mgallery/board/view/?id=beeswarmsimulator&no=305)
- 싫음: 엔드게임은 24시간 매크로가 전제다. — [DC 2026-03](https://gall.dcinside.com/mgallery/board/view/?id=beeswarmsimulator&no=1877)
- 싫음: 신규가 퀘스트 물건을 잃어서 막혔고, 게임 밖 거래에서 사기를 당했다. — [DC 2026-10](https://gall.dcinside.com/mgallery/board/view/?id=beeswarmsimulator&no=2361), [DC 2026-10](https://gall.dcinside.com/mgallery/board/view/?id=beeswarmsimulator&no=2365)

### Sol's RNG (한국 스튜디오의 로블록스 게임)
- 좋음: 한국 스튜디오가 세계 규모로 컸다(회사 발표로 20억 플레이). — [유니콘팩토리 2026-06](https://www.unicornfactory.co.kr/article/2026062414081355477)
- 좋음: 시작한 지 이틀 된 신규도 큰 운이 터지면 자랑한다. — [DC 솔스 갤 2026-09](https://gall.dcinside.com/mgallery/board/view/?id=solsrng&no=342&page=1)
- 좋음: 패턴을 배우면 보스가 쉬워지고, 고수가 초보를 도와준다. — [DC 2026-09](https://gall.dcinside.com/mgallery/board/view/?id=solsrng&no=334&page=1)
- 싫음: 신규가 유튜브마다 다른 설명을 듣고 헷갈린다. — [DC 2026-09](https://gall.dcinside.com/mgallery/board/view/?id=solsrng&no=330&page=1)
- 싫음: 비싼 장비 없이는 보스를 못 깨고, 로벅스로 산 아이템이 제대로 작동하지 않았다. — [DC 2026-09](https://gall.dcinside.com/mgallery/board/view/?id=solsrng&no=327&page=1), [DC 2026-09](https://gall.dcinside.com/mgallery/board/view/?id=solsrng&no=331&page=1)
- 싫음: 업데이트가 계속 늦어지고 약속을 뒤집어서 반발을 샀다. — [roonby 2024-11](https://roonby.com/2024/11/20/sols-rng-eon-1-ria-packs-update-when-new-information/)

### 한국 로블록스 유저 글 (DC 로블록스 갤: 계훔·Miner World·Natural Disaster Survival 등)
- 좋음: 큰 발견 연출이 들어간 뒤 Miner World가 최고가 됐다는 글. — [DC 2026-10-10](https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=106298)
- 좋음: 사람 많은 서버에서 서로 아바타를 구경하는 게 재밌다(Natural Disaster Survival). 계훔을 45일째 하고 있다는 글. — [DC 2026-10-09](https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=105966), [DC 2026-10-10](https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=106314)
- 좋음: UI가 복잡하지 않으면 노가다가 조금 있어도 괜찮다. 조용히 반복하는 일이 위로가 된다는 글도 있다. — [DC 2026-10-10](https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=106287), [DC 2026-10-06](https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=105342)
- 싫음: 돈을 벌어도 쓸 데가 없다(계훔). — [DC 2026-10-10](https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=106300) (한 사람 글)
- 싫음: 천장이 낮은 값 결과로 초기화돼서 그만둘까 고민한다는 글. — [DC 2026-09-30](https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=104001) (한 사람 글이라 근거 약함)
- 싫음: 꼼수는 바로 막고 핵은 그냥 둔다. 보스 100번 잡기 같은 반복 행사, 다른 사람 포털 때문에 알을 잃었다는 글. — [DC 2026-09-29](https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=103763), [DC 2026-09-27](https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=103190), [DC 2026-10-10](https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=106315)

### 로블록스 첫 경험 (DevForum·Roblox 공식 문서)
- 좋음: 손으로 해 보는 튜토리얼로 고치자 초반 이탈이 줄었다(Ancient Peaks). — [DevForum 2025-09](https://devforum.roblox.com/t/the-age-old-question-what-makes-people-leave-this-after-30-seconds/3969002)
- 좋음: 공식 권장 — 첫 레벨은 낮게, 시작 아이템을 주고, 5분 안에 재미에 닿고, 온보딩 끝에 축하하는 순간을 둔다. 짧은 목표와 긴 목표를 분명히 하고, 온보딩 단계마다 완료율을 보고 크게 빠지는 곳을 고친다. — [Roblox 온보딩 문서](https://create.roblox.com/docs/production/game-design/onboarding), [Roblox 리텐션 문서](https://create.roblox.com/docs/production/analytics/retention), [DevForum 2024](https://devforum.roblox.com/t/improving-onboarding-through-funnel-events/3064458)
- 싫음: 붐비는 메뉴, 회색 맵, 소리 없음 때문에 약 95%가 바로 나갔다(Wall Busters). — [DevForum 2025-02](https://devforum.roblox.com/t/almost-every-player-is-immediately-leaving-my-game-can-you-tell-me-why/3483806) (95%는 개발자 어림)
- 싫음: 첫 진행이 느리고, 튜토리얼에 억지로 순간이동시켰다. — [DevForum 2025-09](https://devforum.roblox.com/t/the-age-old-question-what-makes-people-leave-this-after-30-seconds/3969002)
- 싫음: 튜토리얼을 약 75%가 끝내도 대부분 5~10분 안에 떠나고(How Fast Can You Go), 다음 목표가 불분명한 곳에서 빠진다. — [DevForum 2026-08](https://devforum.roblox.com/t/need-feedback-mainly-core-loop-ftue-and-retention/4773215), [DevForum 2024](https://devforum.roblox.com/t/improving-onboarding-through-funnel-events/3064458)

### Fable 시리즈 (후광·뿔이 몸에 자라는 원조)
- 좋음: 내 선택이 몸에 보이는 게 가장 사랑받는 부분이다. 2026 리부트에서 이걸 빼자 일부 팬이 반발했다. — [Millenium 2026-01](https://www.millenium.org/news/429194.html) ('많은'이 아니라 '일부')
- 좋음: 악의 모습을 트로피처럼 노린다. — [Steam 2017](https://steamcommunity.com/app/204030/discussions/0/133261370017672210)
- 좋음: 단순한 선악 판타지 자체가 재밌고, 마을 사람이 반응한다. — [Game Developer 블로그 2010](https://www.gamedeveloper.com/design/fable-3-s-dark-side-is-underdeveloped-incoherent-and-broken)
- 싫음: 뿔이 못생겨서 악의 길을 피했다. — [Steam 2017](https://steamcommunity.com/app/204030/discussions/0/133261370017672210) (한 사람 글이라 근거 약함)
- 싫음: 이야기와 인물이 내 기울기를 모른 척한다. — [Game Developer 블로그 2010](https://www.gamedeveloper.com/design/fable-3-s-dark-side-is-underdeveloped-incoherent-and-broken)
- 싫음: 돈이 많으면 선택이 가벼워진다. — [Steam 2013](https://steamcommunity.com/app/105400/discussions/0/810919056951634942)

### Star Wars: KOTOR I·II (라이트·다크 사이드)
- 좋음: 양쪽 다 세지만 역할이 다르다(빛 = 탱커·치유, 어둠 = 피해). — [Steam 2015](https://steamcommunity.com/app/32370/discussions/0/616198900639429470)
- 좋음: 좋은 길도 힘이 좋으면 지루하지 않고, 유혹 자체가 재미다. — [Steam 2021](https://steamcommunity.com/app/32370/discussions/0/3108017414022594386)
- 좋음: 동료가 내 편을 따라 바뀐다. — [Steam 2018](https://steamcommunity.com/app/208580/discussions/0/2595630410183943170)
- 싫음: 가운데에 머물면 손해다. 착한 길은 돈이 모자라서 전리품 때문에 악으로 간다. — [Steam 2021](https://steamcommunity.com/app/32370/discussions/0/3108017414022594386)
- 싫음: 다크 쪽 모습이 좀비처럼 변해서 끄는 모드를 쓴다. — [Steam 2018](https://steamcommunity.com/app/208580/discussions/0/2595630410183943170)

### Mass Effect (파라곤·레니게이드)
- 좋음: 나쁜 쪽의 짧고 시원한 장면이 기억에 남고, 두 길이라 다시 할 맛이 난다. — [Game Informer 2021](https://www.gameinformer.com/opinion/2021/05/13/mass-effect-legendary-edition-should-you-go-paragon-or-renegade)
- 좋음: 점수가 높으면 모두가 사는 답이 열린다. 한쪽으로 기울면 반대쪽을 조금 섞어도 된다. — [Steam 2014](https://steamcommunity.com/app/24980/discussions/0/558753804332015547), [Steam 2016](https://steamcommunity.com/app/24980/discussions/0/360670708780691318)
- 싫음: 마음 가는 대로 섞어서 하면 선택지가 잠기는데, 몰랐다는 사람들이 있다. — [Game Informer 2021](https://www.gameinformer.com/opinion/2021/05/13/mass-effect-legendary-edition-should-you-go-paragon-or-renegade), [Steam 2016](https://steamcommunity.com/app/24980/discussions/0/360670708780691318)
- 싫음: 숨은 기준이 제멋대로 느껴지고, 놓친 선택은 다시 못 고른다. — [Steam 2014](https://steamcommunity.com/app/24980/discussions/0/558753804332015547) (몇 사람 글이라 근거 약함)
- 싫음: 화면에 보이는 점수와 실제 점수가 달랐다. — [Steam 2015](https://steamcommunity.com/app/24980/discussions/0/617330406660550210)

### Undertale (평화·중립·학살 루트)
- 좋음: 살려 주기가 진짜 행동이라 착한 길이 독특하다. — [Steam 2020](https://steamcommunity.com/app/391540/discussions/0/3007801544749528084)
- 좋음: 악한 길도 빠른 속도와 어려운 보스로 사랑받는다. 게임이 내가 한 일을 기억한다. — [Steam 2021](https://steamcommunity.com/app/391540/discussions/0/2954914688097527050)
- 좋음: 몬스터마다 살릴지 싸울지 고르는 자유가 좋다. — [Steam 2018](https://steamcommunity.com/app/391540/discussions/0/1696048245845173665)
- 싫음: 설계가 한쪽(평화)을 편든다. — [Steam 2020](https://steamcommunity.com/app/391540/discussions/0/3007801544749528084)
- 싫음: 악한 길을 지키려면 2시간 노가다가 필요하고, 끌려가는 느낌이다. — [Steam 2015](https://steamcommunity.com/app/391540/discussions/0/494632768633441932), [Steam 2016](https://steamcommunity.com/app/391540/discussions/0/412448158165431812/?ctp=3)
- 싫음: 결과가 영구라서 그 길을 아예 피한다. — [Steam 2021](https://steamcommunity.com/app/391540/discussions/0/2954914688097527050)

### Aion / Aion 2 (천족 대 마족)
- 좋음: 진영 대 진영의 큰 전투가 핵심 재미다. — [게임메카 2010](https://www.gamemeca.com/view.php?gid=232968)
- 좋음: 상대 땅 침공이 PvE와 PvP를 잇고, 캐주얼 유저도 생각보다 부담이 적었다. — [루리웹 2025-11](https://bbs.ruliweb.com/news/board/11/read/2391)
- 싫음: 출시 이틀 만에 고렙이 저렙을 학살했다. 1편과 같은 문제다. — [퀘이사존 2025-11](https://quasarzone.com/bbs/qn_game/views/419959)
- 싫음: '선택'이라던 PvP가 성장 때문에 사실상 강제였고, 진영이 다르면 친구와 귓말·파티를 못 한다. — [루리웹 2025-11](https://bbs.ruliweb.com/news/board/11/read/2391), [인벤 2026-08](https://www.inven.co.kr/board/aion2/6388/249227) (12월 선택형 전쟁 모드는 이 리뷰에서 확인 안 됨)
- 싫음: 지는 쪽 인원이 줄어 안 나오게 되고, 작은 스킬 차이에도 크게 화낸다. — [Engadget 2011](https://www.engadget.com/2011-06-27-wings-over-atreia-bribing-for-balance.html), [게임메카 2009](https://www.gamemeca.com/view.php?gid=232628)

### World of Warcraft (얼라이언스 대 호드)
- 좋음: 따로 사는 시작 지역·지도자·라이벌이 진영 정체성을 만든다. — [WoW 포럼 2026-02](https://us.forums.blizzard.com/en/wow/t/faction-identity/2254828)
- 좋음: 다른 진영 친구와 길드를 맺게 해 주자 "드디어", "고맙다"며 반겼다. 같이 퀘스트·던전도 하게 해 달라는 요청이 이어졌다. — [EU 포럼 2023-04](https://eu.forums.blizzard.com/en/wow/t/443628/1)
- 좋음: 켜고 끌 수 있는 PvP(워 모드)는 재밌을 때가 있다. — [WoW 포럼 2024-06](https://us.forums.blizzard.com/en/wow/t/how-is-war-mode-as-horde-on-rp-servers/1884349)
- 싫음: 작은 종족 힘 차이 때문에 오래 쏠렸다. — [WoW 포럼 2019 2쪽](https://us.forums.blizzard.com/en/wow/t/how-would-you-fix-the-faction-imbalance/360956?page=2), [4쪽](https://us.forums.blizzard.com/en/wow/t/how-would-you-fix-the-faction-imbalance/360956?page=4) ('멋진 진영' 이미지 이야기는 한 사람 글)
- 싫음: 적은 쪽은 들판에서 사냥당하고, 약자 보너스가 문제를 뒤집어 놓기도 했다. — [EU 포럼 2019](https://eu.forums.blizzard.com/en/wow/t/warmode-do-something/58734), [WoW 포럼 2024](https://us.forums.blizzard.com/en/wow/t/how-is-war-mode-as-horde-on-rp-servers/1884349)
- 싫음: 진영을 합치다 보니 진영 차이가 사라졌다. — [WoW 포럼 2026-02](https://us.forums.blizzard.com/en/wow/t/faction-identity/2254828)

### MapleStory (PC)
- 좋음: 귀여운 그림·음악·추억이 화난 유저도 붙잡는다. 친구가 남는 이유다. — [Steam 리뷰 2025~26](https://store.steampowered.com/appreviews/216150?json=1&filter=all&language=english&num_per_page=100&purchase_type=all&day_range=365)
- 좋음: 직업이 많고 콘텐츠가 많다. — [VaporLens 2026-04](https://vaporlens.app/app/216150/maple_story/stats/details)
- 좋음: 경제를 공정하게 바꾸는 변경은 제한이 있어도 반겼다. — [mmos.com 2024-01](https://mmos.com/news/maplestory-kr-anti-inflation-measures)
- 싫음: 스타포스 하락·파괴가 수십 시간을 날린다. 없애자는 제안에 반응이 약 2,580개 달렸다. — [Steam 2026](https://store.steampowered.com/appreviews/216150?json=1&filter=all&language=english&num_per_page=100&purchase_type=all&day_range=365), [넥슨 포럼 2025-01](https://forums.maplestory.nexon.net/discussion/35046/star-force-rework)
- 싫음: 한정 이벤트와 일일 미션이 숙제가 되고, 놓칠까 봐 불안하다. — [Steam 2026](https://store.steampowered.com/appreviews/216150?json=1&filter=all&language=english&num_per_page=100&purchase_type=all&day_range=365)
- 싫음: 첫 시간은 긴 컷신 뒤 갑자기 Lv200이 되고, 혼자 하는 게임 같다. — [Steam 2025~26](https://store.steampowered.com/appreviews/216150?json=1&filter=all&language=english&num_per_page=100&purchase_type=all&day_range=365)

### MapleStory M
- 좋음: 바쁜 오래된 유저는 자동을 좋아한다(일하거나 자는 동안 진행). — [Steam 리뷰 2026](https://store.steampowered.com/appreviews/3969080?json=1&filter=recent&language=english&num_per_page=100&purchase_type=all&day_range=365)
- 좋음: 보스는 수동이라 '진짜 재미'로 남는다. — [Steam 2026](https://store.steampowered.com/appreviews/3969080?json=1&filter=recent&language=english&num_per_page=100&purchase_type=all&day_range=365)
- 싫음: 처음 1~2시간 유저는 게임이 혼자 한다며 그만둔다. — [Steam 2026](https://store.steampowered.com/appreviews/3969080?json=1&filter=recent&language=english&num_per_page=100&purchase_type=all&day_range=365) (리뷰 88개라 표본이 작음)
- 싫음: 페이투윈·과금이 가장 큰 불만이다. — [VaporLens 2026-04](https://vaporlens.app/app/3969080/maple_story_m/stats/details)
- 싫음: 이벤트 펫·버프가 끝나면 자동이 크게 약해져서 함정 같다. — [Steam 2026](https://store.steampowered.com/appreviews/3969080?json=1&filter=recent&language=english&num_per_page=100&purchase_type=all&day_range=365)

### Ragnarok: The New World
- 좋음: 익숙한 직업·몬스터·마을 덕분에 옛 팬이 돌아왔다. — [Steam 리뷰 2026](https://store.steampowered.com/appreviews/4212480?json=1&filter=recent&language=english&num_per_page=100&purchase_type=all)
- 좋음: 일하는 사람은 짧게 접속해도 자동이 돌아서 좋고, 끌 수도 있다. 친구가 계속하는 이유로 꼽힌다. — [Steam 2026](https://store.steampowered.com/appreviews/4212480?json=1&filter=recent&language=english&num_per_page=100&purchase_type=all)
- 싫음: 첫 시간 유저는 게임이 혼자 한다고 느낀다. — [Steam 2026](https://store.steampowered.com/appreviews/4212480?json=1&filter=recent&language=english&num_per_page=100&purchase_type=all)
- 싫음: 하루 제한·스태미나가 숙제가 되고, 길드가 없으면 막힌다. — [Steam 2026](https://store.steampowered.com/appreviews/4212480?json=1&filter=recent&language=english&num_per_page=100&purchase_type=all)
- 싫음: 펫이 뽑기 안에 있고, 고를 만한 직업이 몇 개뿐이다. — [Steam 2026](https://store.steampowered.com/appreviews/4212480?json=1&filter=recent&language=english&num_per_page=100&purchase_type=all)

### Toram Online
- 좋음: 정해진 직업 없이 스킬을 섞어 내 빌드를 만든다. — [Steam 리뷰 2026](https://store.steampowered.com/appreviews/1827180?json=1&filter=recent&language=english&num_per_page=100&purchase_type=all)
- 좋음: 상점이 주로 치장·편의라서 무과금에게도 공정하다. — [Steam 2026](https://store.steampowered.com/appreviews/1827180?json=1&filter=recent&language=english&num_per_page=100&purchase_type=all)
- 좋음: 사람들이 친절하고, 어려운 보스는 같이 잡는다. — [Steam 2026](https://store.steampowered.com/appreviews/1827180?json=1&filter=recent&language=english&num_per_page=100&purchase_type=all)
- 싫음: 초보가 빌드를 망치기 쉽고, 고치려면 돈이 든다. — [Steam 2026](https://store.steampowered.com/appreviews/1827180?json=1&filter=recent&language=english&num_per_page=100&purchase_type=all)
- 싫음: 후반 레벨과 드롭이 너무 느리고, 유료 뽑기에 천장이 없다. — [Steam 2026](https://store.steampowered.com/appreviews/1827180?json=1&filter=recent&language=english&num_per_page=100&purchase_type=all)
- 싫음: 사람이 적으면 혼자 보스를 못 깨고, 잘못된 밴이 있다. — [Steam 2026](https://store.steampowered.com/appreviews/1827180?json=1&filter=recent&language=english&num_per_page=100&purchase_type=all)

### Old School RuneScape
- 좋음: 옛 장비도 쓸모가 있어서 노가다가 뿌듯하다. "그만두지 않고 쉬었다 온다." — [Steam 리뷰 2026](https://store.steampowered.com/appreviews/1343370?json=1&filter=recent&language=english&num_per_page=100&purchase_type=all)
- 좋음: 유저 투표로 업데이트해서 내 게임 같고, 시간을 존중한다(PC·폰 이어 하기). — [Steam 2026](https://store.steampowered.com/appreviews/1343370?json=1&filter=recent&language=english&num_per_page=100&purchase_type=all)
- 싫음: 광고·짧은 잠수 타이머 같은 유료 등급 아이디어를 설문에 넣었다가 크게 반발을 샀다. CEO가 사과하고 회원끼리 게임 차이를 만들지 않겠다고 약속했다. — [OSRS 위키 2025-01](https://oldschool.runescape.wiki/w/Update:Membership_Survey:_An_Update_From_Mod_Pips,_Jagex_CEO)
- 싫음: 멈추기가 너무 어려워서 학교·관계에 지장이 있었다. — [Steam 2026](https://store.steampowered.com/appreviews/1343370?json=1&filter=recent&language=english&num_per_page=100&purchase_type=all)
- 싫음: 처음이 헷갈리고, 옛 퀘스트는 위키가 필요하다. — [Steam 2026](https://store.steampowered.com/appreviews/1343370?json=1&filter=recent&language=english&num_per_page=100&purchase_type=all)

### MapleStory: Idle RPG (메이플 키우기)
- 좋음: 원작 그대로의 추억이 있고, 부드럽게 돌아간다. — [App Store 2026-04](https://apps.apple.com/us/app/maplestory-idle-rpg/id6739616715)
- 좋음: 방치형인데도 하루 30~45분은 손으로 할 거리가 있다. — [App Store 2026-01](https://apps.apple.com/us/app/maplestory-idle-rpg/id6739616715)
- 좋음: 출시 직후 매출 1위였고, 45일 만에 1억 달러를 넘었다. — [다음/조선비즈 2026-01](https://v.daum.net/v/3ixEzmaegy)
- 싫음: 유료 재설정의 최고값이 아예 나올 수 없었는데 몰래 고쳤다가 사과·환불했다. — [다음 2026-01](https://v.daum.net/v/3ixEzmaegy) (약 1,200명은 '신고 예정'이라 확정 아님)
- 싫음: 큰손 위주이고, 하루 콘텐츠가 적고, 폰이 뜨거워진다. — [App Store 2026-01](https://apps.apple.com/us/app/maplestory-idle-rpg/id6739616715)
- 싫음: 외롭다. 더 같이 놀고 싶고 펫을 원한다. — [App Store 2026](https://apps.apple.com/us/app/maplestory-idle-rpg/id6739616715)

### 한국 MMO 유저 (Throne and Liberty·메이플·로스트아크·마비노기 모바일)
- 좋음: 자동사냥은 바쁜 사람이 다른 일을 하며 키우기 좋다. 옛날식 RPG에는 맞을 수도 있다는 사람도 있다. — [루리웹 2026-07](https://bbs.ruliweb.com/community/board/300143/read/75802737), [루리웹 2026-07](https://bbs.ruliweb.com/community/board/300143/read/76080478)
- 좋음: 일일 숙제는 자동보다 '건너뛰기'가 낫다는 데 동의했다. — [루리웹 2026-07](https://bbs.ruliweb.com/community/board/300143/read/75947984)
- 좋음: 눈에 보이는 확정 성공을 반기고, 능력치를 파는 상품이 없는 점을 높이 산다. — [루리웹 2026-09](https://bbs.ruliweb.com/community/board/300143/read/76830118), [twig24 2023-12](https://twig24.com/news/industry/2023/12/08/20231208500203)
- 싫음: 자동을 빼려면 수동 손맛이 있어야 한다. 자동이 직업 개성을 지울까 걱정한다. — [twig24 2023-12](https://twig24.com/news/industry/2023/12/08/20231208500203), [인벤 2026-07](https://www.inven.co.kr/board/maple/5974/6876552)
- 싫음: 이벤트 때 확률이 오히려 나빠진 것 같다는 불신, 천장까지 가는 긴 불운. — [메이플 공식 이벤트 2025-09](https://maplestory.nexon.com/News/Event/Closed/1202), [루리웹 2026-03](https://bbs.ruliweb.com/community/board/300143/read/74488700)
- 참고: 강화 파괴가 싫어서 그만뒀다는 글은 있지만, 그 글 댓글은 오히려 파괴를 옹호한 쪽이 많았다. — [루리웹 2025-01](https://bbs.ruliweb.com/community/board/300143/read/69094628) (근거 약함, 우리 '파괴 없음'은 그대로 유지)

## 출처

**Blox Fruits**
- https://forum.arcaneodyssey.dev/t/why-is-blox-fruits-popular/85075
- https://naavik.co/digest/blox-fruits-lessons/
- https://rowatcher.com/news/is-blox-fruits-worth-playing-in-2026-an-honest-review
- https://www.distractify.com/p/why-is-blox-fruits-private
- https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=102552

**Deepwoken**
- https://forum.arcaneodyssey.dev/t/a-review-of-deepwoken/73730
- https://forum.arcaneodyssey.dev/t/your-thoughts-on-deepwoken-sort-of-a-rant-as-well/76821
- https://forum.arcaneodyssey.dev/t/should-i-play-deepwoken/143253

**Arcane Odyssey**
- https://forum.arcaneodyssey.dev/t/thoughts-on-arcane-odyssey-combat-system/161107
- https://forum.arcaneodyssey.dev/t/about-arcane-odysseys-base-magics-as-a-whole/136958
- https://forum.arcaneodyssey.dev/t/what-makes-arcane-odyssey-dead/123940
- https://forum.arcaneodyssey.dev/t/a-disappointment/156394
- https://forum.arcaneodyssey.dev/t/why-arcane-odyssey-is-dying/144191

**Grand Piece Online**
- https://forum.arcaneodyssey.dev/t/whats-good-about-gpo/60178
- https://forum.arcaneodyssey.dev/t/actual-good-gpo-update/119023
- https://forum.arcaneodyssey.dev/t/gpo-rant-reasons-why-gpo-sucks/108792
- https://forum.arcaneodyssey.dev/t/grand-piece-online/84637?page=4

**The Forge**
- https://forum.arcaneodyssey.dev/t/has-anyone-played-the-forge-yet/154186
- https://forum.arcaneodyssey.dev/t/has-anyone-played-the-forge-yet/154186?page=3
- https://roonby.com/2026/01/05/players-are-mad-about-the-forge-raven-cave-update/

**Dungeon Quest / World // Zero**
- https://forum.arcaneodyssey.dev/t/dungeon-quest-a-criticism/74325
- https://forum.arcaneodyssey.dev/t/no-good-rpg-style-games-left/54317
- https://forum.arcaneodyssey.dev/t/recommend-me-good-roblox-games-that-i-should-spend-my-time-grinding-to/60619
- https://devforum.roblox.com/t/how-to-make-a-open-world-rpg-game-fun/2059404

**Grow a Garden**
- https://www.ksat.com/business/2025/07/30/millions-are-flocking-to-grow-virtual-gardens-in-viral-roblox-game-created-by-teenager/
- https://www.nbcsandiego.com/entertainment/entertainment-news/virtual-gardens-viral-roblox-game-created-teenager/3879694/
- https://www.dexerto.com/roblox/roblox-smashes-concurrent-user-record-thanks-to-war-between-two-games-3242035/
- https://www.dexerto.com/roblox/grow-a-garden-finally-getting-trading-amid-complaints-of-rampant-scamming-3230688/
- https://gamerant.com/roblox-grow-a-garden-weekly-events-changes/
- https://roonby.com/2026/05/03/grow-a-garden-bizzy-bee-update-delayed-community-starts-to-split/
- https://www.iggm.com/news/grow-a-garden-christmas-event-part-2-why-are-players-disappointed-leaving

**Steal a Brainrot**
- https://kotaku.com/steal-a-brainrot-roblox-empire-review-popular-memes-1851787027
- https://automaton-media.com/en/wp-json/wp/v2/posts/66028
- https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=85383
- https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=87683

**99 Nights in the Forest**
- https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=78368
- https://devforum.roblox.com/t/creator-spotlight-the-story-behind-99-nights-in-the-forest/4036940
- https://gall.dcinside.com/mgallery/board/view/?id=robloxforest99&no=377
- https://gall.dcinside.com/mgallery/board/view/?id=robloxforest99&no=371
- https://gall.dcinside.com/mgallery/board/view/?id=robloxforest99&no=167
- https://gall.dcinside.com/mgallery/board/view/?id=robloxforest99&no=189
- https://gall.dcinside.com/mgallery/board/view/?id=robloxforest99&no=340
- https://gall.dcinside.com/mgallery/board/view/?id=robloxforest99&no=379
- https://gall.dcinside.com/mgallery/board/view/?id=robloxforest99&no=361

**Adopt Me! / Common Sense Media**
- https://www.commonsensemedia.org/website-reviews/adopt-me
- https://www.commonsensemedia.org/lists/popular-games-on-roblox
- https://www.commonsensemedia.org/website-reviews/roblox
- https://gall.dcinside.com/mgallery/board/view/?id=growme&no=164
- https://gall.dcinside.com/mgallery/board/view/?id=growme&no=137
- https://gall.dcinside.com/mgallery/board/view/?id=growme&no=132
- https://gall.dcinside.com/mgallery/board/lists/?id=growme
- https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=57064

**Bee Swarm Simulator**
- https://gall.dcinside.com/mgallery/board/view/?id=beeswarmsimulator&no=309
- https://gall.dcinside.com/mgallery/board/view/?id=beeswarmsimulator&no=2367
- https://gall.dcinside.com/mgallery/board/lists/?id=beeswarmsimulator
- https://gall.dcinside.com/mgallery/board/view/?id=beeswarmsimulator&no=2133
- https://gall.dcinside.com/mgallery/board/view/?id=beeswarmsimulator&no=305
- https://gall.dcinside.com/mgallery/board/view/?id=beeswarmsimulator&no=1877
- https://gall.dcinside.com/mgallery/board/view/?id=beeswarmsimulator&no=2361
- https://gall.dcinside.com/mgallery/board/view/?id=beeswarmsimulator&no=2365

**Sol's RNG**
- https://www.unicornfactory.co.kr/article/2026062414081355477
- https://gall.dcinside.com/mgallery/board/view/?id=solsrng&no=342&page=1
- https://gall.dcinside.com/mgallery/board/view/?id=solsrng&no=334&page=1
- https://gall.dcinside.com/mgallery/board/view/?id=solsrng&no=330&page=1
- https://gall.dcinside.com/mgallery/board/view/?id=solsrng&no=327&page=1
- https://gall.dcinside.com/mgallery/board/view/?id=solsrng&no=331&page=1
- https://roonby.com/2024/11/20/sols-rng-eon-1-ria-packs-update-when-new-information/

**한국 로블록스 유저 글 (DC 로블록스 갤)**
- https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=106298
- https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=106314
- https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=106287
- https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=105966
- https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=105342
- https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=106300
- https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=104001
- https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=103763
- https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=103190
- https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=106315
- https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=87688 (PS99 거래 사기, 피할 것 7)
- https://gall.dcinside.com/mgallery/board/view/?id=roblox&no=67573 (Fisch 매크로, 피할 것 3)

**로블록스 첫 경험 (DevForum·공식 문서)**
- https://devforum.roblox.com/t/the-age-old-question-what-makes-people-leave-this-after-30-seconds/3969002
- https://devforum.roblox.com/t/improving-onboarding-through-funnel-events/3064458
- https://create.roblox.com/docs/production/game-design/onboarding
- https://create.roblox.com/docs/production/analytics/retention
- https://devforum.roblox.com/t/almost-every-player-is-immediately-leaving-my-game-can-you-tell-me-why/3483806
- https://devforum.roblox.com/t/need-feedback-mainly-core-loop-ftue-and-retention/4773215
- https://devforum.roblox.com/t/update-on-paid-random-items-restriction-for-uk-users-under-18/3072183?page=2 (PS99 알, 피할 것 6, 한 사람 댓글)

**Fable**
- https://www.millenium.org/news/429194.html
- https://steamcommunity.com/app/204030/discussions/0/133261370017672210
- https://www.gamedeveloper.com/design/fable-3-s-dark-side-is-underdeveloped-incoherent-and-broken
- https://steamcommunity.com/app/105400/discussions/0/810919056951634942

**KOTOR**
- https://steamcommunity.com/app/32370/discussions/0/616198900639429470
- https://steamcommunity.com/app/32370/discussions/0/3108017414022594386
- https://steamcommunity.com/app/208580/discussions/0/2595630410183943170

**Mass Effect**
- https://www.gameinformer.com/opinion/2021/05/13/mass-effect-legendary-edition-should-you-go-paragon-or-renegade
- https://steamcommunity.com/app/24980/discussions/0/558753804332015547
- https://steamcommunity.com/app/24980/discussions/0/360670708780691318
- https://steamcommunity.com/app/24980/discussions/0/617330406660550210

**Undertale**
- https://steamcommunity.com/app/391540/discussions/0/3007801544749528084
- https://steamcommunity.com/app/391540/discussions/0/2954914688097527050
- https://steamcommunity.com/app/391540/discussions/0/1696048245845173665
- https://steamcommunity.com/app/391540/discussions/0/494632768633441932
- https://steamcommunity.com/app/391540/discussions/0/412448158165431812/?ctp=3

**Aion / Aion 2**
- https://www.gamemeca.com/view.php?gid=232968
- https://bbs.ruliweb.com/news/board/11/read/2391
- https://quasarzone.com/bbs/qn_game/views/419959
- https://www.inven.co.kr/board/aion2/6388/249227
- https://www.engadget.com/2011-06-27-wings-over-atreia-bribing-for-balance.html
- https://www.gamemeca.com/view.php?gid=232628

**World of Warcraft**
- https://us.forums.blizzard.com/en/wow/t/faction-identity/2254828
- https://eu.forums.blizzard.com/en/wow/t/443628/1
- https://us.forums.blizzard.com/en/wow/t/how-is-war-mode-as-horde-on-rp-servers/1884349
- https://us.forums.blizzard.com/en/wow/t/how-would-you-fix-the-faction-imbalance/360956?page=2
- https://us.forums.blizzard.com/en/wow/t/how-would-you-fix-the-faction-imbalance/360956?page=4
- https://eu.forums.blizzard.com/en/wow/t/warmode-do-something/58734

**MapleStory (PC)**
- https://store.steampowered.com/appreviews/216150?json=1&filter=all&language=english&num_per_page=100&purchase_type=all&day_range=365
- https://vaporlens.app/app/216150/maple_story/stats/details
- https://mmos.com/news/maplestory-kr-anti-inflation-measures
- https://forums.maplestory.nexon.net/discussion/35046/star-force-rework

**MapleStory M**
- https://store.steampowered.com/appreviews/3969080?json=1&filter=recent&language=english&num_per_page=100&purchase_type=all&day_range=365
- https://vaporlens.app/app/3969080/maple_story_m/stats/details

**Ragnarok: The New World**
- https://store.steampowered.com/appreviews/4212480?json=1&filter=recent&language=english&num_per_page=100&purchase_type=all

**Toram Online**
- https://store.steampowered.com/appreviews/1827180?json=1&filter=recent&language=english&num_per_page=100&purchase_type=all

**Old School RuneScape**
- https://store.steampowered.com/appreviews/1343370?json=1&filter=recent&language=english&num_per_page=100&purchase_type=all
- https://oldschool.runescape.wiki/w/Update:Membership_Survey:_An_Update_From_Mod_Pips,_Jagex_CEO

**MapleStory: Idle RPG (메이플 키우기)**
- https://apps.apple.com/us/app/maplestory-idle-rpg/id6739616715
- https://v.daum.net/v/3ixEzmaegy

**한국 MMO 유저 (자동사냥·강화)**
- https://bbs.ruliweb.com/community/board/300143/read/75802737
- https://bbs.ruliweb.com/community/board/300143/read/76080478
- https://bbs.ruliweb.com/community/board/300143/read/75947984
- https://bbs.ruliweb.com/community/board/300143/read/76830118
- https://twig24.com/news/industry/2023/12/08/20231208500203
- https://www.inven.co.kr/board/maple/5974/6876552
- https://maplestory.nexon.com/News/Event/Closed/1202
- https://bbs.ruliweb.com/community/board/300143/read/74488700
- https://bbs.ruliweb.com/community/board/300143/read/69094628

**우리 문서·코드 (대조에 쓴 것)**
- `docs/SPEC_ADDENDUM.md` A23-11·14·20·21·22·23·64·68·75·79·83·88·90·99·104·108·109·110·111
- `docs/GDD.md` §5-1, §5-7, 괴수
- `docs/design/idea_backlog.md`, `docs/design/mmorpg_painpoints_ideas_2026-10-05.md` §4, `docs/design/ui_clutter_review_2026-10-09.md`, `docs/design/psychology_retention_2026-10-08.md`, `docs/design/first_ko_quest_2026-10-10.md`, `docs/design/zone_check_halo_2026-10-10.md` #39, `docs/RELEASE_PLAN.md` 자를 순서표
- `src/ReplicatedStorage/Shared/Config.luau` (SlimeKing·PumpkinKing 체력, Loot.Jackpot, HudReveal, TownReact, MyWay, Quests.Templates, Analytics.Funnels, StoryQuests KO1, Tutorial 다음 목표 사다리)
- `src/ServerScriptService/TelemetryService.luau` (온보딩 13단계, ForgeWalk, FirstDeath_, KOLeave60, EnhanceFailLeave, ServerPopulation, Plunder_), `src/ServerScriptService/InviteService.luau` (OtherTown), `src/ServerScriptService/QuestService.luau` (nextGoalText), `src/StarterPlayer/StarterPlayerScripts/Fx.luau` (A9-2·A14-4 손맛), `src/StarterPlayer/StarterPlayerScripts/Panels.luau` (What Monsters Drop "1 in 20,000")
