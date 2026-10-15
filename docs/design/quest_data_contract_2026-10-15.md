# 퀘스트 데이터 작성 규격 (게임성 개발 2, 2026-10-15) — 퀘스트 바이블 전체를 진영·장별 데이터 묶음으로

근거: 사용자 "게임 전반적인 퀘스트를 원하는 거야. 아주 잘 짜인"(최종 검수 10/15), `docs/design/quest_bible_2026-10-15.md` v3 §3~§13, SPEC A23-199~206, 엔진 계약 `docs/design/quest_p1_server_contract_2026-10-15.md`.
역할: **내용(대사·단계·보상 데이터) = Codex가 진영·장별 파일로**, 엔진·시험·통합 = 개발 2, 화면 = 개발 1. 글은 쉬운 짧은 영어(`docs/design/glossary_en_2026-10-06.md`), 코드에 글 없음.

## 1. 파일 = 데이터 묶음(pack)
- 위치: `src/ReplicatedStorage/Shared/Quests/<이름>.luau` (ModuleScript). 이름 예: `Halo_Ch2`, `Horns_Ch2`, `Artisan_Ch2`, `Halo_Town`, `Common_Web`, `Common_Daily`. 이름 순서로 읽힘.
- 게임은 `Config.AddQuests(pack, 이름)`으로 `Config.StoryQuests`에 합침 → 서버·화면 모두 지금처럼 `Config.StoryQuests`를 읽음.
- 같은 id 두 번 = 불러오기 실패(덮어쓰기 없음). 기존 Landmarks/Speakers 키를 다시 쓰는 것도 실패.
- 검사: `py tools/test_quest_data.py`(구조·규칙), `py tools/test_story_text.py`(글 길이·단어; 묶음도 같이 읽음). 둘 다 통과해야 병합.

## 2. 묶음 모양
```lua
return {
	Faction = "Halo",                 -- 이 묶음의 Variants가 어느 진영 것인지 (Variants 없으면 생략 가능)
	Defs = { [id] = 퀘스트 },         -- 새 퀘스트
	Subs = { id, ... },                -- 새 Sub를 부탁 순서대로 (Defs에 있는 Sub는 전부 여기에)
	Main = { { After = "M1_4", Ids = { id, ... } } }, -- 새 Main을 본편 줄의 어느 뒤에 (After 없으면 끝)
	Variants = { [공유 id] = { Offer = {...}, Steps = { [i] = 단계 } } }, -- 이 진영판 (아래 4)
	Landmarks = { [키] = Vector3.new(x, 0, z) }, -- 새 장소(현장 물건·등불·연습대…)
	Speakers = { [키] = "이름" },
	Npcs = { TownNpcs.List 항목 },    -- 새 임시 몸 (Story = NpcId 필수)
}
```
예시 한 개 전체: `tools/fixtures/quest_pack_example.luau` (빛 2장 Main 1 + 마을 Sub 1 + 매일 부탁 1 + M2_2 빛판).

## 3. 퀘스트(Def) 필드
| 필드 | 필수 | 뜻 |
|---|---|---|
| `Kind` | ✔ | `"Main"`(본편 줄) / `"Sub"`(선택·지선·반복) |
| `Type` | ✔ | 주로 하는 행동(바이블 §3): Combat, Skill, Gather, Craft, Sell, Investigate, Recover, Deliver, Repair, Install, Escort, Rescue, Defend, Claim(선점), Boast(허풍), Prank(장난), Command(지휘), Lure(유인), Tame(조련), Choice, Display(전시), Test(시험), Visit. **한 진영 본편 줄에서 연속 두 Main의 Type이 같으면 실패** |
| `Difficulty` | ✔ | `"Easy"` / `"Normal"` / `"Hard"` / `"Challenge"` (A23-207: 어려울수록 좋은 보상, 아래 3-1) |
| `Title`, `ShortName` | ✔ | ShortName 14자 이하(폰 줄) |
| `Speaker` | | Config.StoryQuests.Speakers 키 |
| `Factions` | | `{ Halo = true }` 등. Main에 있으면 그 진영 본편 줄에만 |
| `Chapter` | Main | 장 번호 |
| `Offer` | ✔ | `{ Npc = "NpcId" 또는 { Halo=…, Horns=…, Neutral=… }, Lines = { All = {…} } 또는 진영별, AcceptScene = "키"? }` — 모든 부탁은 NPC가 1~2줄로 분명히 부탁(A23-199), 몸 있는 NPC만 |
| `Requires` | | `Level`, `MaxLevel`, `Done = {id}`, `DoneAny`, `NotDone`, `Pick = { Id, Is }`, `Classes`, `Feature`, `TeacherMet`, `Skill`… (없는 id·순환 = 실패) |
| `Steps` | ✔ | 단계 목록(아래) |
| `Reward` | | `Gold`/`XP`(사냥 환산 단위), `GoldN`(정액), `XPBar`(레벨 비율), `Item`+`N`, `Potion`+`N`, `BagSlots`, `Title`/`TitleBy`. **스탯 판매 키 = 실패**(A23-75). 금액이 정해지지 않았으면 비움(바이블 §3) |
| `Claim` | | true = 끝나면 [받기] |
| `Repeat` | | `"Daily"` = 매일 부탁(아래 6) |

### 3-1. 난이도와 보상 (A23-207, 검사 = `tools/test_quest_data.py`)
| 난이도 | 아이템(최고 등급) | Gold/XP(사냥 단위) | GoldN | XPBar | 칭호·펫 | 최소 |
|---|---|---|---|---|---|---|
| Easy | 보통(물약·기본 재료·펫 간식) | ≤1 | ≤60 | ≤0.25 | ✗ | — |
| Normal | 보통 | ≤2 | ≤150 | ≤0.5 | ✗ | — |
| Hard | 주문서·희귀 재료·토닉까지 | ≤4 | ≤400 | ≤1 | ✗ | 주문서/희귀 재료, 또는 Normal보다 많은 골드 |
| Challenge | 희귀 아이템(문 크리스탈·왕관 보석·왕실 젤리…)까지 | 제한 없음 | 제한 없음 | 제한 없음 | ✔ | 희귀 아이템·칭호·펫 중 하나 |

'쉬운데 보상 큼'(Easy가 주문서·칭호, 상한 넘는 골드)과 '어려운데 보상 작음'은 검사가 실패시킴. 등급표 = `ITEM_TIER`(시험 파일). 화면: 부탁 창 보상 아이콘 테두리 색·별 수(개발 1).

## 4. 단계(Step) 필드
- `Text`(%d/%d 진행 숫자 가능), `ShortName`, **`Guide`(장소 키) 또는 `Npc`(NpcId) 필수**(그 자리 카드 `Panel` + Npc 없음만 예외).
- `Panel = true` + `Lines`(+`LinesBy = { From = id, Good/Evil/A/B/Default }`) = 대화·선택 카드.
- `SetFlag = { Key, Value }` = 이 단계가 끝나면 개인 결과 기록 + 장면(Fx StoryScene). `Value = "Class"` = 장인 직업(Smith/Alch/Tame).
- 진영별 다른 단계: 단계 안에 `Halo = { … }`, `Horns = { … }`, `Neutral = { … }`(그 필드만 덮음).
- `Obj.Type` 목록:

| Type | 필드 | 판정 |
|---|---|---|
| Kill / BasicKill / SafeKill / AutoKill | Kind, Zone, Near+Radius, Golden, Count | 처치(BasicKill = 기본 공격만, SafeKill = HP 절반 위) |
| SkillHit | Min, Slot, Count | 수동 스킬이 몬스터 Min 이상 적중 |
| Trials | List = { {Key, Type, …, Count, Text} } | 여러 목표 동시 |
| Gather / Craft / SellMat | Item, Node / Role("Own" = 자기 직업), Kind / Count | 채집·제작·판매 |
| EarnGold, WarPoints, WarChest, Goose | Count | 기존 |
| Talk, Choice | (Panel) Choice: Good/Evil/Neutral{A,B}, Points, Pick, Reward, Flag={Key,Good,Evil} | 대화·선택 |
| Near, Enter, Level, State, Event | Spot+Radius(+Stay) / Zone / Level / Key / Name | 도착·상태 |
| Pickup / Deliver | Spot+Radius / Npc | 줍기(서버가 자리 확인) / 건네기(NPC 옆) |
| Practice | Spot, Radius, Count | 연습대에 기본 공격 |
| Emote | Spot, Radius, Allowed = { cheer = "Evil", wave = "Good" }, Flag | 자리에서 감정표현 |
| Match | Target, Wrong = { 둘 } (Config.QuestShapes) | 모양 맞추기 |
| Timing | — | 작업대 5번 중 3번 |
| Learn | Slot | 스승에게 배움 |
| Skip | — | 이 진영판에 필요 없는 단계(바로 통과) |

추격·호위(⑧)는 엔진 준비 후 이 표에 추가.

## 5. 공유 퀘스트의 진영판(Variants)
- 바이블의 `M2_2[H]`처럼 세 진영이 같은 id(진행·보상 공유)를 다른 행동으로 할 때: 그 진영 묶음의 `Variants[id]`.
- `Steps[i]` = i번째 단계의 그 진영 덮어쓰기. **기본 퀘스트와 단계 수 같게**(남는 단계는 `Obj = { Type = "Skip" }`). 없는 단계 번호 = 불러오기 실패.
- `Offer` = 그 진영 부탁 NPC·대사. 기본에 Offer가 없던 퀘스트는 다른 진영은 예전처럼 저절로 시작.
- 보상·제목은 공유(진영 변경해도 같은 id = 재지급 0).

## 6. 매일 부탁(반복) — A23-205 / A23-206
- `Repeat = "Daily"`, 종류 12개까지(`Common_Daily` 등). 하루(KST)에 **5개까지만** 받기(`Config.StoryQuests.RepeatDailyMax = 5`), 고르는 건 플레이어, 하나만 해도 보상, 연속 보상·강요 없음. 5개 받으면 다른 부탁 NPC의 '!'가 흐려짐(글 없음). (엔진 = 다음 단계)
- **종류마다 보상이 다름**(검사: 같은 보상 종류 둘 = 실패), 도감 진척·스탯 없음, **난이도 섞어서**. 초안(최종 검수 확정 전):

| # | 난이도 | 보상 | # | 난이도 | 보상 |
|---|---|---|---|---|---|
| 1 | Easy | HP Potion ×3 | 7 | Normal | Copper Ore ×3 |
| 2 | Easy | MP Potion ×3 | 8 | Normal | Oak Log ×3 |
| 3 | Hard | Enhance Scroll 70% ×1 | 9 | Hard | Glowcap ×2 |
| 4 | Hard | Transfer Scroll 30% ×1 | 10 | Hard | Guard Tonic ×1 |
| 5 | Easy | Pet Treat ×2 | 11 | Hard | Lucky Tonic ×1 |
| 6 | Normal | Meadow Herb ×5 | 12 | Challenge | 꾸미기 조각(새 아이템; 그 전엔 Moon Crystal ×1) |

- **보상 아이템 = 캐릭터 귀속**(퀘스트·매일 부탁·스승 시험·연결 끝): 거래소·선물·판매 불가, 쓸 때 귀속분 먼저 소모, 사냥·제작으로 얻은 같은 아이템은 지금 규칙. 저장 = 아이템별 귀속 개수 따로(저장 v7, 엔진 = 다음 단계).

## 7. 쓰는 사람이 지킬 것 (퀘스트 체감 규칙 14줄 요약)
1. 부탁(NPC 1~2줄) → 수락/거절 → 행동 → 건네기·사용·보상. 자동 수락·설명 팝업 없음.
2. 빛 = 보호·돌려주기, 뿔 = 선점·허풍, 장인 = 제작·수리·사용. 대사만 바꾼 같은 행동 금지.
3. 뿔 장난은 내 왕관·리본·허풍으로 돌아옴. 아이·동물·다른 플레이어 피해 없음.
4. 선택 결과는 개인 기록(`Flag` / `SetFlag`) — 남의 등불·서버 상태를 바꾸지 않음.
5. 거절·선택 지선은 본편·레벨을 막지 않음. 새 몸이 필요하면 `Npcs`로 같이 넣음(몸 없으면 부탁 안 나옴).
6. 금액·수치 미정은 비움 → 최종 검수가 정함.
