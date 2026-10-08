# 왕 슬라임 나누기 — 영향 조사 (게임성 개발 2, 2026-10-08)

**사용자 요청(검수 전달 2026-10-08):** "네모난 킹 슬라임을 하나 만들자. 지금 킹 슬라임은 좀 작잖아. 걔는 이름을 다시 지어 주자."

**검수 정리:**
- 지금 `BigSlime`의 화면 이름을 **'Slime Prince'**로 바꿔요(내부 id는 그대로).
- 새 보스 **'King Slime'**(`SlimeKing`)을 만들어요. 크고 네모나고, King Slime Hill에 가끔 하나 나와요.
- 마무리 카드는 새 King에 붙여요.

조사 범위는 origin/main 03e5aa4e의 `src/`, `tools/worldkit`, `tools/*.lua`예요. `BigSlime`·`King Slime`·`KingSlime`·`king slime`을 모두 찾았어요.

## 0. 원칙(제안)
- **첫 10분은 그대로예요.**
  - 신규가 Lv1~5에 잡는 것(A23-2 S0, A23-12 첫 70% 주문서, M1_2, 일일, 게시판)은 전부 `BigSlime` = **Slime Prince**에 남겨요.
  - 이들의 목표 종류(`Kind = "BigSlime"`)는 하나도 바꾸지 않고 **글만** 바꿔요.
- **새 King은 덤이에요.** 몇 분마다 나오는 보스라 기다려야 해요. 그래서 메인 퀘스트나 필수 목표를 거기에 걸지 않아요. 선택 퀘스트나 보상으로만 써요.
- **이름은 Config 한 곳에서 와요.** 몬스터 이름표, 일일·게시판 글(`def.Short`), 퀘스트 HUD 아이콘(`IconMon<Kind>`)은 `Config.MonsterTypes.BigSlime.Name/Short` 하나만 바꾸면 따라와요. 퀘스트·대사 글에 박혀 있는 "King Slime"만 손으로 바꿔요.

## 1. 지금 King Slime(`BigSlime`)을 가리키는 곳

| # | 어디 | 지금 | 제안 | 맡을 곳 |
|---|---|---|---|---|
| 1 | `Config.MonsterTypes.BigSlime` (Config.luau:1658) | Name/Short "King Slime" | **"Slime Prince"** / "Slime Prince". id·숫자·Count 4는 그대로. 이름표·일일·게시판 글이 따라 바뀌어요 | 개발 2 |
| 2 | **A23-2 S0** 1단계 (Config:2243-2245) | "Beat a King Slime and find the shard", Start "A King Slime swallowed a shard!" · Kill BigSlime 1 | **Slime Prince에 남김**(첫 10분). 글만 "Beat a Slime Prince and find the shard" / "A Slime Prince swallowed a shard!…" | 개발 3(퀘스트 데이터) |
| 3 | S0 시험 c (Config:2250) | SafeKill BigSlime (HP 50% 이상) | 그대로(글 없음) | — |
| 4 | **A23-12 첫 왕 슬라임 70% 주문서** `Config.Loot.FirstScroll.Monster` (Config:3859) | "BigSlime" | **Slime Prince에 남김.** 신규가 Lv3~5에 받는 보장이에요. 새 King에 옮기면 몇 분을 기다려야 하고 첫 무기 강화가 늦어져요. 알림 글(FirstScroll/FirstScrollBare)에는 이름이 없어요 | — (그대로) |
| 5 | M1_1 끝 대사 (Config:2308) | "…The King Slimes ate the most of it." | "…The Slime Princes ate the most of it." | 개발 3 |
| 6 | **M1_2** 메인 1장 (Config:2311-2314) | Title "The King Who Ate the Dust", ShortName "King Slimes", "King Slimes %d/%d" · Kill BigSlime 2 | 목표는 그대로예요. 글: Title "The Prince Who Ate the Dust", ShortName "Slime Princes", "Slime Princes %d/%d", Start "Slime Princes full of shard dust…" | 개발 3 |
| 7 | M2_6 메인 2장 (Config:2401-2403) | "The King Slime dust is gone…", "King Slimes %d/%d" · Kill BigSlime 2 | 목표는 그대로예요(메인은 보스를 기다리지 않게). 글은 "Slime Prince". 언덕 위 새 King은 다음 장 이야기 거리로 남겨요(§3 #9) | 개발 3 |
| 8 | N2 시험 a (Config:2577) | Kill BigSlime 3 (글 "Supply book") | 그대로 | — |
| 9 | H1 3단계 (Config:2600-2602) | "King Slimes near the woods", "…King Slimes gobbled…" | 글만 "Slime Princes" | 개발 3 |
| 10 | XR1 Tiny (Config:2708-2709) | "A King Slime swallowed a teddy bear!", "King Slime %d/%d" · Kill BigSlime 1 (Lv5) | 글만 "Slime Prince". 새 King으로 옮기는 건 비추예요(Lv5 곰 인형 퀘스트가 보스를 기다리게 돼요) | 개발 3 |
| 11 | R5 Smokey (Config:2739-2742) | "A King Slime is wearing my sack as a hat!", "King Slime %d/%d" · BigSlime 1 | 글만: "A Slime Prince is wearing my sack as a crown!" 등 | 개발 3 (문구는 검수) |
| 12 | 게시판 Meadow `Big = "BigSlime"` (Config:3032) | 큰 몬스터 일감 | 그대로. 글은 `def.Short`로 자동 | — |
| 13 | 일일 신규 줄 (Config:3152) | Kill BigSlime 3 "왕 슬라임 3마리" | 그대로(주석만 "슬라임 왕자"). 글은 자동 | 개발 2(주석) |
| 14 | 드롭 표 `Loot.Tables.BigSlime` (Config:3777) | SlimeCore·Jelly·주문서 | 그대로 | — |
| 15 | 몬스터 말 `Barks.BigSlime` (Config:1751) | "Bow! Blub!", "Royal BOING!", "Royal nap…" (왕 말투) | 왕자 말투로 바꿔요. A23-74 규칙(2단어·12글자, 다른 종류와 겹치지 않기)을 지켜요. 예: "Prince BOING!", "Hmph! Blub!". 왕 말투는 새 King에 줘요 | 검수(문구) → 개발 2(Config) |
| 16 | `BubbleFamily.BigSlime = "Slime"`, `Audio.SoftKinds.BigSlime` (Config:1727, 4171) | 슬라임 말풍선·부드러운 맞는 소리 | 그대로. 새 King에도 `SlimeKing = "Slime"` / `SoftKinds.SlimeKing = true` | 개발 2 / 소리 |
| 17 | `IconMonBigSlime`, `BarkBubbleBigSlime` (Config:4494, 4363) | 왕관 쓴 왕 슬라임 그림 | 지금 그림을 Slime Prince 것으로 써요(작은 왕관이면 그대로 OK). 새 King 아이콘·말풍선은 새로 그려요 | 이미지 생성 2 → 이미지 개발 |
| 18 | 3D `CustomModels.BigSlime` + 금 왕관 (`docs/design/king_slime_crown_2026-10-08.md`, `tools/worldkit/slime_backfix_crown.luau`) | 왕관 붙은 몸 | 왕자는 작은 왕관이나 티아라로 할지 이미지 개발이 정해요. 큰 금 왕관은 새 King에 옮기는 게 자연스러워요 | 이미지 개발 1 / 검수 |
| 19 | 펫 조련사 X "Big Boing" `Craft = "BigSlime"` (Config:634, SkillService:465) | 스킬 소품으로 BigSlime 모델 | 그대로(소품 이름에는 글이 없어요) | — |
| 20 | 주석: MonsterService:133·327, QuestService:256·278·311, StoryQuestService:565·604, Config:1566 | "King Slime(s)" | 다음에 손댈 때 "Slime Prince"로(동작과 상관없음) | 각 파일 담당 |
| 21 | 지도 `KingSlimeHill`(장식 이름), `meadow_terrain` HillTop, `meadow_dress` 언덕 왕관 | 언덕 이름 | **그대로.** 새 King이 그 언덕에 나오니 이름이 맞아요 | — |
| 22 | 측정 | Steps·퍼널에 종류 이름 없음. S0·M1_3는 퀘스트 id로만 셈(TelemetryService:388, 664-670) | 그대로. 새 King은 §3 #8 | — |
| 23 | 일기(Config.Diary)·도움말(Help)·News | King Slime 언급 없음(일기는 호박 대왕) | 그대로. News 'New this week'에 새 King 소식 한 줄 | 검수(News) |
| 24 | 마무리 카드 `Config.Finisher.Kinds` (dev2-kingfinish, 아직 미병합) | `{ BigSlime = true }` | **`{ SlimeKing = true }`**(Slime Prince는 카드 없음). 시험의 King 기록을 SlimeKing으로 바꿔요 | 개발 2 |

## 2. 손으로 바꿀 글 모음 (개발 3에게, 목표 종류는 그대로)
- S0: 1단계 Text·Start (2개)
- M1_1: Finish 1개
- M1_2: Title·ShortName·Start·Text (4개)
- M2_6: Start·Text (2개)
- H1: 3단계 Text·Start (2개)
- XR1: 대사 1줄 + Text (2개)
- R5: Start·Text (2개)
- 모두 쉬운 영어로 써요. 문구는 검수가 마지막으로 봐요.
- 시험: 퀘스트 글에 "King Slime"이 남지 않았는지 정적 검사로 확인해요. 단, 새 King을 부르는 글은 빼고 세요.

## 3. 새 보스 King Slime (`SlimeKing`) — 서버 제안(개발 2)

| # | 무엇 | 제안 |
|---|---|---|
| 1 | Config | `MonsterTypes.SlimeKing = { Name = "King Slime", Short = "King Slime", Zone = "SlimeMeadow", Count = 0, Boss = true, Shape = "Slime", Scale = 3.2, ContributorWindow = 120, RewardMinHits = 3, RewardMinDamageFrac = 0.005, XPCapBelowLevel = 8, ModelFrom = "BigSlime", … }`. `MonsterTypeOrder`에서 BigSlime 다음에 넣어요 |
| 2 | 체력·보상(제안, 구현 때 호박 대왕 계산 방식으로 다시) | 초원은 Lv1~10이고 무기는 1~2단계예요. 혼자면 약 4분, 셋이면 약 1분 20초가 되게 **HP 2500 안팎**이에요. 공격 6(왕자의 1.5배, 느림), XP 120 / Gold 60 (Lv8 아래는 한 레벨치까지, A23-27). 드롭 표는 `Loot.Tables.SlimeKing`(SlimeCore ×2, Jelly ×4, 70% 주문서는 왕자보다 높은 확률) |
| 3 | 나오는 법 | **한 서버에 하나만** 있어요. 초원에 사람이 있으면 **8분마다** 나오고, 5분 머문 뒤 떠나요(제안). **자리는 §3-1이에요**(사용자 결정: 언덕 위 왕관 모양 돌 사당 앞 공터). `MonsterService.SpawnEvent`/`RemoveEvent`는 호박 대왕 것을 그대로 써요. 시계는 새 `SlimeKingService`가 맡거나 HalloweenService의 보스 시계를 시즌 없이 나눠 써요 |
| 4 | 알림 | 나올 때 초원에 있는 사람에게 "The King Slime is on the hill!"을 보내요(서버 전체가 아니라 초원만). 잡으면 "The King Slime hopped home!"이에요. `GameState SlimeKingActive / SlimeKingNextAt / SlimeKingEndsAt`(호박 대왕과 같은 틀) |
| 5 | 아이 안전 | 새싹 보호를 그대로 지켜요. 보스 공격은 느리게 하고 미리 보이게 해요. 쓰러져도 마을로 돌아가는 규칙은 그대로예요. 자동 전투로도 기여할 수 있고 카드만 수동이에요 |
| 6 | 마무리 카드 | `Config.Finisher.Kinds = { SlimeKing = true }`. 기여자(120초 안)이면서 수동 공격을 1번 이상 한 사람만 받아요 |
| 7 | 겉모습(임시) | 새 3D가 오기 전에는 **슬라임 큐브 ×3(`ModelFrom = "BigSlime"`, Scale 3.2)에 큰 금 왕관**을 써요. 최종 모델은 이미지 생성 2 → Tripo예요 |
| 8 | 측정 | 커스텀 이벤트 1개, `SlimeKingDefeat`(값 = 기여자 수, 칸1 = 진영 구성 Halo/Horns/Mixed)예요. 100개 이름 예산 안이에요 | 
| 9 | 퀘스트(나중, 선택) | 개발 3에게: Lv5 이상 선택 퀘스트 1개를 만들어요. 예: "Help beat the King Slime 1/1", 기여만 해도 돼요. 메인·일일·S0에는 넣지 않아요 |

### 3-1. 등장 자리 (사용자 2026-10-08: "저기 왕관처럼 있는 돌 성 앞에서 나오게 해 줘")

새 King Slime은 King Slime Hill 꼭대기, 왕관 모양 돌 사당 **앞 공터**에서 나와요.
사당 3D는 이미지 생성 1이 만들고, 검수 도구가 그 자리에 놓아요.

| 순서 | 자리 | 어디서 읽나 |
|---|---|---|
| 1 | 사당 모델의 속성 `KingSpawn`(Vector3, 사당 앞 6~8스터드) | `workspace.Map` 아래에서 `KingSpawn` 속성을 가진 첫 인스턴스를 서버 시작 때와 스폰마다 찾아요. 사당을 다시 놓아도 따라가요 |
| 2 (사당이 오기 전) | `ServerStorage.MeadowTerrainStore`의 `HillTop`에서 **길 쪽으로 8스터드** | 길 쪽 = 같은 store의 `HillPathFoot` 방향(수평)이에요. 언덕 왕관 돌의 틈도 이쪽을 향해요(`meadow_dress.luau`) |
| 3 (둘 다 없을 때) | Config 기본값: `M_KingHill` (430, −170) 꼭대기 + 길 쪽 8 | `Config.SlimeKing.Spawn`(새 블록) |

- 나올 때 바닥을 레이로 다시 찾아요. 호박 대왕의 `Near`/`Radius` 틀과 같고, 반지름은 2스터드라 사당 안이나 돌 위에 서지 않아요.
- 사당·왕관 돌은 몬스터가 들어가지 않는 단단한 장식이에요(CR-L14 목록에 사당 모델 이름 한 줄 추가).
- 잡으면 그 자리에서 퐁 사라져요. 떠날 때(시간 끝)는 사당 쪽으로 뒷걸음질 없이 그 자리에서 흐려져요(호박 대왕과 같아요).
- 검수 도구에 부탁해요: 사당을 놓을 때 `KingSpawn` 속성을 사당 모델(Model)에 Vector3 월드 좌표로 써 주세요. 이름이 정해지면 문서에 적을게요.

## 4. 몫 나누기
- **개발 2(서버):**
  - §1 #1·#13·#24, §3 #1~#8, §3-1 등장 자리(KingSpawn → HillTop+8 → Config)(Config, 스폰 시계, 알림 키, GameState, 드롭 표, 카드 옮기기)
  - 시험 + 변이
- **개발 3(퀘스트 데이터):**
  - §2의 글 바꾸기(목표 종류는 그대로)
  - §3 #9 선택 퀘스트(보스가 들어온 뒤)
  - 글 정적 검사
- **개발 1(화면):**
  - 새 King 알림 배너·칩(EventHUD, 호박 대왕 칩 틀)
  - 미니맵·세계 지도 표시(`SlimeKingActive` 동안 언덕에 왕관 표시)
  - 마무리 카드 화면(이미 보냄)
- **이미지 생성 2 → 이미지 개발:** 새 King 아이콘·말풍선·3D(Tripo), 왕자 왕관 크기 정하기(§1 #17·#18)
- **소리 만들기:** 새 King 등장·쓰러짐 소리(선택)
- **검수:** 문구(왕자·왕 말, 알림), 숫자 확정(§3 #2·#3), News 한 줄, 사당을 놓을 때 `KingSpawn` 속성 쓰기(§3-1)
- **이미지 생성 1:** 왕관 모양 돌 사당 3D(사당 앞 공터 6~8스터드를 비워 두기)

## 5. 확인 부탁(검수)
1. 첫 10분 묶음(S0, 첫 주문서, M1_2, 일일, 게시판)을 모두 Slime Prince에 두는 것.
2. 새 King 숫자(HP 2500 안팎, 8분마다 5분 머묾, 한 서버 하나, 초원 사람 있을 때만).
3. 메인 퀘스트는 새 King에 걸지 않는 것(기다림 방지).
4. 서버 시계를 새 `SlimeKingService`로 따로 둘지, HalloweenService의 보스 시계를 시즌 없이 나눠 쓸지. 추천은 따로 두는 거예요(핼러윈이 끝나도 그대로 돌게).
