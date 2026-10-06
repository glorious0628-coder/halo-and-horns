# 검수 대사·소리 묶음 (2026-10-06)

## 0. 한눈에
1. 검수 지적을 모두 반영했어요. 화면 영어 줄은 모두 12단어 이하(몬스터 한마디는 8단어 이하)이고, 금지어·실존 이름·무서운 말은 0개예요. 새 그림 0장, 크레딧 0이에요.
2. 늘 만나는 다섯 명은 Hallie·Magpie·Kit·Otto·Fizzby예요. Kit은 베타 화면에 나오지 않아서, 마을 사람(A23-46)을 여자 많게 두어 성비를 맞춰요.
3. 몬스터 한마디는 `Config.Barks`에 그대로 붙여 넣으면 돼요. 황금 몬스터는 모든 순간에 Golden 줄을 먼저 쓰고, 거위 Low(80%)는 협동과 줄다리기 모두 정했어요.
4. 벽보는 주 계산 버그(시작 전에 4주가 나옴)를 고쳤고, 빛·뿔 마을에 게시판을 하나씩 새로 둬야 해요(개발 1). 대왕 9일 줄은 `%d`를 먼저 채워요. 조각 줄은 "the other side", 폰 키 이름, KO 화면 겹침을 고쳤어요.
5. 효과음 파일은 27~30개예요. 유령 왕 등장은 #17 파일을 다시 써요. 올리기 전에 새 계정의 오디오 업로드 한도부터 확인해야 해요.

---

## 1. 늘 만나는 다섯 명 (⑪ · 개발 2 약 0.1일)

이름은 이미 승인된 초상(PTR_GuideHalo·PTR_GuideHorns·PTR_GuideArtisan·PTR_MerchantC·PTR_PotionMerchant)의 얼굴과 성별에 맞췄어요. 그래서 그림은 새로 그리지 않아요. 영어 대명사도 이 성별을 따라요.

### 1-1. 인물표
| 인물 (지금 화면 이름) | 고른 이름 | 대안 | 말버릇 (EN, 고정) | 성격 한 줄 |
|---|---|---|---|---|
| 빛 안내자 (**Guide of Light**) · 여 · 금발 쪽머리·금 머리띠 | **Hallie** (Halo와 소리가 닮아 '빛 편 사람'으로 바로 기억해요) | Clara | "Hallie here! Now you know my name." | 다정하고 성실한 기사단 선배예요. 무엇이든 조금 너무 열심히 지켜요. 늘 이름부터 말해요. 왕관이 깨진 밤 등불을 빌려준 작은 손이 이름을 알려 주지 않았기 때문이에요(M3_5에서 밝혀짐, Smokey의 "Nobody asks our names."와 짝) |
| 뿔 안내자 (**Horn Legion Guide**) · 남 · 동전 자루를 멘 **장난꾸러기 뿔 선배(젊은 어른)** | **Magpie** (반짝이를 모으는 새, 뿔의 "Shiny! Finders keepers!"와 맞아요) | Kettle | "Finders keepers! HA!" | 먼저 집고 제일 크게 웃는 패거리 대장이에요. 그런데 늘 패거리 몫으로 집어요. 조각이 떨어질 때 너무 멀리 있어서 하나도 못 받은 적이 있어요(M3_5). "HA!"는 M5_7 "Twins! HA!"까지 이어져요 |
| 길드 안내자 (**Guild Guide**) · 여 · 고글·귀에 꽂은 연필·청록 앞치마 | **Kit** (공구 상자, 세 글자라 읽기 쉬워요) | Nell | "Fix first. Talk later." | 침착하고 손이 빠른 길드 반장이에요. 누가 깼든 고치는 게 먼저래요(A23-55). 양쪽 주문을 다 받아요. Tiny의 스승이에요. **베타 화면에는 나오지 않아요**(아래 1-2) |
| 대장장이 (**Blacksmith**, 말하는 이 키 `Smith`) · 남 · 콧수염·주황 두건·코코아 머그 | **Otto** (앞뒤로 읽어도 같아 재미있고 든든해요) | Barnaby | "Clang, clang… done. Cocoa time." | 졸린 눈의 베테랑이에요. 말은 느리고 망치는 빨라요. 첫 무기를 주면서 마른 농담을 해요("Don't name it. You'll get attached.") |
| 물약 상인 (**Potion Seller**) · 남 · 곱슬머리·안경·물약 배낭 | **Fizzby** ('보글보글 fizz'가 바로 읽혀요) | Corky | "Glug, glug, feel better!" | 광고처럼 말하는 수다쟁이예요("Potions! Now with 0% more potion!"). 값은 정직하고(25 gold) 더 사라고 조르지 않아요. 물약은 HP 30%만 채우니(`HPRecovery 0.30`) "good as new" 같은 과장은 하지 않아요 |

- 이미 있는 이름(Bright·Smokey·Tiny·Sir Gleam·Rascal Rex·Grabbo·Pip·Dibs·Sunny Sam·Sir Halt·Clerk Bones·Old Slime)과 겹치지 않아요. 첫 글자도 H·M·K·O·F로 모두 달라요. 무기 접두어 "Dawn", 스킬 "Anvil Guard", 계급 이름과도 겹치지 않아요.
- **Magpie는 어른이에요.** §0-1·M5_7 구도에서 아이는 Bright와 Smokey 둘뿐이고, 안내자는 '욕심을 인정하는 어른'이에요.
  - 영어 대사에서 Magpie를 kid나 boy로 부르지 않아요. M3_5 "two kids ran past us"도 이 구도 그대로예요.
  - 승인 프롬프트의 "guide boy"는 그림과 맞아서 그림은 그대로 둬요.
- **"Captain"은 쓰지 않아요.** 계급표(Squire…Archangel)에 없는 말이라 헷갈려요. 어디서든 "Hallie"만 써요.
- **이름 충돌(낮음, 그대로 써요):**
  - Hallie·Otto·Kit·Magpie는 흔한 이름이라 다른 작품이 조금 떠오를 뿐이고, Fizzby는 충돌이 없어요.
  - Hallie/Halo/Sir Halt, Otto/Old Slime의 소리 겹침도 사소해요.

### 1-2. 성비 (A23-59 '고르게', 검수 결정)
- **Kit은 베타 화면에 나오지 않아요.**
  - 세계에 서 있는 안내자 NPC가 없어요(`Config.Tutorial.Welcome` 주석 "no world NPC is spawned").
  - Kit은 Welcome.Neutral, N1·N2(Neutral 전용·베타 숨김), M5_7(나중)에만 나와요.
- 그래서 베타에 보이는 다섯 명 쪽은 여 1(Hallie) : 남 3(Magpie·Otto·Fizzby)이에요.
- 이름 있는 마을 인물까지 보면 이래요.
  - 여: Hallie, Bright(A23-59), Smokey(승인 초상 PTR_TownSmokey_A 프롬프트가 'lookout girl')
  - 남: Tiny(승인 초상 'apprentice boy')
- **검수 결정:** 마을 사람(A23-46, 마을마다 4~6명, 이름 없는 HumanoidDescription NPC)은 **여자를 더 많이** 둬요.
  - 마을마다 5명이면 여 3 · 남 2예요. 교차로를 오가는 사람도 같은 비율이에요.
  - 모두 하드 규칙 1(단정한 옷)을 지켜요. 마을 사람을 배치할 때 개발 1이 적용해요.

### 1-3. 쓰는 규칙
- **이름이 들어가는 곳:** 말하는 사람 칸, 머리 위 이름표, 대사 앞 이름이에요(예: "Otto: …").
- **이름표는 두 줄이에요:** 위는 이름, 아래는 역할이에요. 예: "Hallie / Guide of Light", "Fizzby / Potion Seller".
- **역할 이름을 그대로 두는 곳:** 퀘스트 줄, 도움말, 시스템 안내예요. 아이가 '어디로 가야 하나'를 역할로 찾게 하려는 거예요(예: "Report to the Guide", "Crossroads Forge").
  - 대장장이 시스템 줄은 **"The Blacksmith" 그대로** 둬요: `Config.Text.WeaponFromQuest`, `Loot.Text.FirstScrollBare`·`FirstWeaponBag`, Help 2234줄, 무기 `Source` 233줄. "Otto at the Forge"는 쓰지 않아요.
  - 모루 프롬프트 `Config.Text.BlacksmithPromptObject = "Forge"`도 그대로 둬요.
  - 물약 시스템 줄(`VitalsService.luau:60`, `Config.Text.PotionShopFar`)도 "Potion Seller" 그대로예요.
- **말버릇은 대화 하나에 한 번, 따로 한 줄로 넣어요.** 기존 줄 앞에 붙이지 않아요. 환영 1쪽 첫 줄이 이미 18단어라서 붙이면 24단어가 돼요.
  - Hallie: `Welcome.Halo.Lines` 맨 앞에 새 줄 "Hallie here! Now you know my name. Welcome to the Knights!"를 넣어요. 'Knight'는 R2 계급 이름이라 Faction Short "Knights"를 써요. M1_4 보고와 'Meet the Guide Again'에도 첫 줄로 "Hallie here! Now you know my name."을 넣어요.
  - Magpie: `Welcome.Horns.Lines` 맨 앞에 "Finders keepers! HA! You're with us now. I'm Magpie."를 넣어요. M1_4와 'Meet the Guide Again' 첫 줄은 "Finders keepers! HA!"예요.
  - Kit: `Welcome.Neutral.Lines` 맨 앞에 "Fix first. Talk later. I'm Kit. Welcome to the Guild!"를 넣어요(베타에서 숨은 데이터).
  - Otto: M1_1 Finish 앞 줄과 Forge 창 인사에 "Clang, clang… done. Cocoa time."을 넣어요.
  - Fizzby: 물약 구매 창 인사에 "Glug, glug, feel better!"를 넣어요. 구매 창 근처라서 free·sale·hurry·limited처럼 재촉하는 말은 쓰지 않아요(story_depth 5-1 다).
- **"Noted."는 Tiny만 써요.** Kit은 쓰지 않아요(아래 1-5).
- **OddHalo/OddHorns:** "Guide:"를 이름으로 바꾸기 전에 A23-58 알림과 **한 토스트로 합쳐요.** 안 그러면 한 번 고를 때 토스트가 두 개 떠요.
  - 최종 문구는 A23-58대로 개발 2가 정해요. 숫자 앞 빼기는 ASCII "-"를 써요.
  - 제안(빛): "Hallie: Hmm… not very angel-like! Honor -%d"
  - 제안(뿔): "Magpie: Too nice for a devil! Your call. Infamy -%d"

### 1-4. Config에서 바꿀 곳 (개발 2)
| 인물 | 지금 키 = 값 | 새 값 | 같이 바꿀 줄 |
|---|---|---|---|
| 빛 안내자 | `Config.Tutorial.Welcome.Halo.Name` = "Guide of Light" | "Hallie" + 새 필드 `Title = "Guide of Light"`(이름표 둘째 줄) | `Lines` 맨 앞 말버릇 줄. `Config.StoryQuests.Text.OddHalo` → 1-3의 합친 줄. M1_4·M2_7은 `Speaker`가 없어서 Panels `STORY.Title`(2697–2700)이 Welcome 이름을 그대로 가져가요 |
| 뿔 안내자 | `Config.Tutorial.Welcome.Horns.Name` = "Horn Legion Guide" | "Magpie" + `Title = "Horn Legion Guide"` | `Lines` 맨 앞 말버릇 줄. `Text.OddHorns` → 합친 줄 |
| 길드 안내자 | `Config.Tutorial.Welcome.Neutral.Name` = "Guild Guide", `Config.StoryQuests.Speakers.Guild` = "Guild Guide" | 둘 다 "Kit" (+ `Title = "Guild Guide"`, 키 이름 `Guild`는 그대로) | `Defs.N1.Start`·`Defs.N2.Start`의 "Guild Guide:" → "Kit:" (베타에서 숨은 데이터지만 같이 고쳐요) |
| 대장장이 | `Config.StoryQuests.Speakers.Smith` = "Blacksmith" | "Otto" | `Defs.M1_1.Finish` "Blacksmith: …" → "Otto: …". 시스템 줄과 `BlacksmithPromptObject = "Forge"`는 그대로 |
| 물약 상인 | 이름 키 없음. `MapBuilder.luau:768` ObjectText "Potion Seller"가 코드에 직접 있어요 | 새 키 `Config.Vitals.PotionMerchantLabel = "Fizzby"` → ObjectText "Fizzby" (ActionText "Buy potions"는 그대로). 새 말하는 이 키 `Config.StoryQuests.Speakers.Potion = "Fizzby"` | `Config.Vitals.PotionMerchantName = "PotionMerchant"`는 workspace 모델 이름이라 **바꾸지 않아요** |

### 1-5. 같이 고칠 줄 (검수: story_depth · glossary)
1. **M5_7 2쪽 이름표:** "Guide of Light:" → "Hallie:", "Horn Legion Guide:" → "Magpie:", "Guild Guide:" → "Kit:".
2. **"Noted."를 Tiny에게만 남기기**
   - §2 2장 장인 줄: "Both sides look suspicious. Noted." → "Both sides look suspicious. Fix first anyway."
   - M5_7 장인 2쪽: "Kit: Fix first… then rent it out. That was the plan." / "Kit: …Oops. Us too."
   - 끝난 뒤 장인 한 줄: "Kit: Tiny's chart says 'Suspicious: nobody.' First time ever."
3. **H2 "Dawn" 충돌:** H2 메아리의 '등불 안 이름 Dawn'은 두 곳과 부딪혀요. §0-1(등불을 준 건 Bright이고 이름은 끝내 모름), 그리고 무기 접두어 "Dawn"이에요.
   - 고칠 줄: "Inside the lamp: a tiny 'B.' scratched in. …Hallie still can't guess."
   - R1의 "signed 'B.'" 단서와 이어져요.
4. **그대로 두는 줄:**
   - M3_5 빛 "I never learned their name. So now I give mine." (Hallie 말버릇의 답)
   - 뿔 "That night, two kids ran past us."
5. **glossary_en 추가 줄:** 빛 안내자 = **Hallie** (Guide of Light) / 뿔 안내자 = **Magpie** (Horn Legion Guide) / 길드 안내자 = **Kit** (Guild Guide) / 대장장이 NPC = **Otto** (Blacksmith) / 물약 상인 NPC = **Fizzby** (Potion Seller). 메모: "이름표 둘째 줄과 퀘스트·시스템 줄은 역할 이름".

---

## 2. 몬스터 한마디 (③ · 개발 2 `Config.Barks`·MonsterService 0.5일, 개발 1 MonsterLabels 0.15일)

화면 글자는 영어만(A23-48) 쓰고 한 줄은 8단어 이하예요(가장 긴 줄 7단어). 대사 때문에 점수가 바뀌지는 않아요. GDD §0의 기울기는 선택에서만 생겨요.

### 2-1. 규칙
- **빈도:**
  - 한 몬스터는 12초에 1번, 한 지역은 모든 몬스터를 합쳐 6초에 1번만 말해요.
  - 쿨다운에 막힌 한마디는 버려요(대기열 없음).
  - 두 대왕도 같은 규칙이고, 지역 6초 몫에 같이 세요.
- **말풍선:** 머리 위 BillboardGui로 3초 동안 떠요. 60스터드 안에서만 보이고, 채팅을 꺼 둔 아이도 봐요. 플레이어 이름은 넣지 않아요.
- **언제 말하나**
  - Spot: 새 목표를 잡을 때 50%
  - Hit: 맞을 때 20% (자동 공격에 맞아도 똑같이 세요)
  - Low: HP가 30% 아래로 내려가면 그 목숨 동안 한 번. 쿨다운에 막히면 다음에 맞을 때 다시 시도해요
  - Idle: 목표가 없고 40스터드 안에 플레이어가 있을 때, 10초마다 15%
  - 같은 순간에 겹치면 Low > Spot > Hit > Idle 순서로 하나만 말해요.
- **줄 고르기:** 종류마다 섞어서 골라 같은 줄이 연달아 나오지 않게 해요. 종류에 줄이 없으면 `Config.QuestKind`(QuestAs) 종류의 줄을 써요.
- **황금 몬스터(검수 결정):** `GoldenChance`로 나온 황금 몬스터는 **모든 순간(Spot·Hit·Low·Idle)** 에 `Golden` 줄을 먼저 써요. 그 순간 줄이 없을 때만 자기 종류 줄을 써요.
  - 욕심 부리던 말("Not sharing!")이 HP가 낮아지면 "Share the sparkle!"로 바뀌는 흐름이에요(설교 없음).
  - 개인 튜토리얼 슬라임(`Tutorial.Golden = true`)이 첫 Spot에 "So much sparkle! Not sharing!"을 말하는 것은 **일부러 그대로 둬요.** 1장 「Sparkly Jelly」와 S0 Purify/Devour 선택으로 바로 이어지기 때문이에요.
- **거위(GooseService가 읽어요, 선택 약 0.05일)**
  - Spot: 거위가 나타날 때
  - Hit: 당기기가 인정될 때(`RegisterHit`)
  - Idle: 떠 있는 동안
  - Low: **협동**은 게이지 80% 이상일 때, **줄다리기**는 pivot이 어느 한쪽 끝까지 80% 이상 갔을 때예요(`GetPosition`이 pivot을 따라가요).
- **거울(story_depth §1-4):** 놀리는 대상은 행동뿐이고, 생김새나 무리는 놀리지 않아요.
  - 고블린: 이유를 잊은 빼앗기예요(Grab Club, 회의 #47, 원래는 등불용 glow).
  - 해골: 같은 하루를 계속 지켜요(늘 화요일).
  - 슬라임: blub.
  - 대왕들: 즐겁게 고른 되풀이예요.
- **피한 표현:**
  - kill·die·dead·blood·scary 같은 낱말은 쓰지 않았어요.
  - 다른 작품의 유명 대사로 들리는 줄도 뺐어요. 예: "Stay a while", "Mine! Mine!", "None shall pass", "my precious".
- **"Dibs!"** 는 교차로 고블린 거래상 이름(Dibs, story_depth §4)과 같아요. 고블린 말버릇에서 그 이름이 나왔다고 보면 자연스러워서 그대로 둬요.
- **"Grab Club"(검수 결정: 그대로):** 유명 영화 제목을 비튼 이름이에요. 하지만 낱말 자체는 아이에게 안전하고, 그 영화의 대사는 쓰지 않았어요. 이미 story_depth 3장 제목이에요.
- **해골왕:** `Config.MonsterTypes`에 아직 없어서 넣지 않았어요(맨 아래 '나중').

### 2-2. Config.Barks (붙여 넣기용)
```lua
-- quality_ideas ③ monster barks: MonsterService picks a line, MonsterLabels shows it in a BillboardGui bubble.
-- English only (A23-48), <= 8 words a line. Cadence: one bark per monster per PerMonster s, per zone per PerZone s.
-- Missing kind -> Config.QuestKind(kind) lines. Golden monsters (Config.Monsters.GoldenChance, incl. the tutorial
-- golden slime) prefer Lines.Golden for EVERY trigger; a trigger Golden lacks falls back to the kind's lines.
-- Lines.Goose is read by GooseService (not MonsterService).
Config.Barks = {
	Enabled = true,
	PerMonster = 12, -- s: at most one bark per monster
	PerZone = 6, -- s: at most one bark per zone (all monsters in it share this)
	Show = 3, -- s the bubble stays up
	MaxDistance = 60, -- studs: bubble visible range
	LowAt = 0.3, -- HP fraction for Low (once per life)
	IdleEvery = 10, -- s between Idle rolls (no target, a player within IdleNear)
	IdleNear = 40,
	Chance = { Spot = 0.5, Hit = 0.2, Low = 1, Idle = 0.15 },
	Priority = { "Low", "Spot", "Hit", "Idle" }, -- same moment: only the first one speaks
	Lines = {
		Slime = {
			Spot = { "Blub?", "Blub! New friend? Blub!" },
			Hit = { "Bloop! Rude.", "Squish! Hey, I'm jelly!" },
			Low = { "Wobbly… so wobbly… blub." },
			Idle = { "Blub blub. Sparkle snack time." },
		},
		PumpkinSlime = {
			Spot = { "Blub-kin? Blub-kin!" },
			Hit = { "Squish! My stem!" },
			Low = { "Too squishy! Need a patch nap." },
			Idle = { "Orange is my best color. Blub.", "Candy smells nice today. Blub-kin." },
		},
		BigSlime = { -- King Slime
			Spot = { "Who dares wobble near the King?", "A visitor! Bow! Or wobble. Either works." },
			Hit = { "Hey! Royal jelly here!" },
			Low = { "The King needs… a royal nap." },
			Idle = { "King of the puddle. Big puddle!", "Royal rule one: more snacks. Blub." },
		},
		Goblin = {
			Spot = { "Dibs! Need more glow!", "Ooh, sparkly! Grab Club, grab!" },
			Hit = { "Hey! I grabbed first!" },
			Low = { "Wait… why do we grab again?" },
			Idle = { "Meeting #47: grab more. Same as #46.", "Grab more glow. Then… grab more." },
		},
		BatGoblin = {
			Spot = { "Flap flap! Candy? Dibs!", "Bat Club? No, Grab Club! Flap!" },
			Hit = { "Eek! Watch the wings!" },
			Low = { "Flap away! Grab later!" },
			Idle = { "Grab Club, night shift. Flap flap." },
		},
		GoblinBrute = {
			Spot = { "New stuff for the sack!", "Not stealing! Surprise collecting!" },
			Hit = { "Hey! Sack's closed today!", "Ow! Mind the sack!" },
			Low = { "Sack too heavy… can't run!" },
			Idle = { "Big sack. Bigger sack. BIGGEST sack!" },
		},
		Skeleton = {
			Spot = { "HALT! …Please?", "Guarding! Guarding what? Not sure. Halt!" },
			Hit = { "Clank! I'm on duty here!" },
			Low = { "Clatter clatter! I'm fine. Mostly." },
			Idle = { "Is it Wednesday yet? …No.", "Tuesday again. Love Tuesdays. I think." },
		},
		SkeletonKnight = {
			Spot = { "Halt! Knight on duty. Since forever." },
			Hit = { "My armor! I polished it Tuesday!" },
			Low = { "Is my shift over yet?" },
			Idle = { "Same post. Same Tuesday. Same me.", "Guarding the Crown. Which Crown? Oh well." },
		},
		GhostMinion = {
			Spot = { "Boo! Boo! Boo! …Together now!", "Team Boo, go!" },
			Hit = { "Hey! Wait for the team!" },
			Low = { "Float away! Float away!" },
			Idle = { "Count off! One, two, boo!" },
		},
		LittleGhost = {
			Spot = { "Boo! …Did that work?" },
			Hit = { "Eep! That tickles!" },
			Low = { "I'm see-through enough already!" },
			Idle = { "Floaty floaty. Candy smells nice.", "Boo practice. Day one hundred." },
		},
		GhostKing = {
			Spot = { "Visitors! Finally! Welcome to my hollow!", "BOO! …The Pumpkin King never does that." },
			Hit = { "Ow! I'm see-through, not tough!" },
			Low = { "Fading… dramatically… are you watching?" },
			Idle = { "My hollow beats his patch. Obviously." },
		},
		PumpkinKing = {
			Spot = { "Welcome to my patch! Pick a pumpkin!" },
			Hit = { "Ha! You tickle my stem!" },
			Low = { "Fine, fine! Candy for everyone!" },
			Idle = { "Ghost King thinks he's the best. Cute.", "Same patch, every year. Best patch!" },
		},
		Golden = { -- any golden monster: used first for every trigger
			Spot = { "So much sparkle! Not sharing!" },
			Hit = { "Hey! You're scratching my shine!" },
			Low = { "Okay, okay! Share the sparkle!" },
			Idle = { "Ate all the dust. Tummy ache." },
		},
		Goose = { -- GooseService: Spot = appears, Hit = accepted tug (RegisterHit), Idle = hovering,
			-- Low = co-op gauge >= 0.8, or tug-of-war pivot >= 0.8 of the way to either end
			Spot = { "HONK! I'm not a piggy bank!" },
			Hit = { "Honk! Gentle hands, please!", "Tug, tug, HONK!" },
			Low = { "Okay, okay! You win! Honk!" },
			Idle = { "No golden eggs today. Honk.", "Both sides want me? Popular goose!" },
		},
	},
}
```

### 2-3. 나중 (해골왕, 5장 지역이 생겨 MonsterTypes에 들어가면)
| Trigger | Line |
|---|---|
| Spot | "Visitors? On a Tuesday? Again?" |
| Hit | "Rude! I was mid-speech!" |
| Low | "Wake me in 30 minutes." |
| Idle | "Zzz… same… same… Tuesday…" |

---

## 3. 서로 탓하는 벽보 4주 (⑩ · 개발 1)

- 빛의 성채(Halo Citadel) 벽보는 뿔(Horns)을 탓하고, 뿔 소굴(Horns Den) 벽보는 빛(Halos)을 탓해요.
- 놀리는 대상은 벽보를 쓴 사람의 **어설픈 추리와 증거**뿐이에요. 진영의 생김새나 무리는 놀리지 않아요(story_depth 5-1, quality_ideas §4).
- 아이를 가리키는 단서(작은 발자국, 크레용, 금·보라 실)는 **'실수로' 흘리기만** 하고, 아이라고 말하지 않아요(A23-55, §0-1).
- 4주째 두 벽보는 범인 이름만 빼고 완전히 같아요. M2_3의 "Word for word."와 이어져요.

### 1주 · 소문
| | 빛의 성채 (Horns 탓) | 뿔 소굴 (Halos 탓) |
|---|---|---|
| 제목 | "WHO BROKE THE CROWN? The Horns. Obviously." | "WHO BROKE THE CROWN? The Halos. Who else?" |
| 1줄 | "They say someone yelled: 'If I can't have it, no one can!'" | "Proof: It went CRACK. A Halo clapped very loudly that week." |
| 2줄 | "A Horn yelled about the last cookie once. Same yell!" | "Clapping is loud. CRACK is loud. Think about it." |
| 웃음 포인트 | 과자 하나에 소리친 일을 왕관 깬 증거로 써요 | 박수 소리를 CRACK 소리로 봐요 |

### 2주 · 작은 단서
| | 빛의 성채 | 뿔 소굴 |
|---|---|---|
| 제목 | "NEW CLUE! Small footprints by the fountain!" | "NEW CLUE! A gold crayon by the fountain!" |
| 1줄 | "We checked every Horn's boots. Way too big. Hmm!" | "The Halos painted their gate gold. With crayons? Maybe!" |
| 2줄 | "So: a Horn. On tiptoes. Mystery solved!" | "Gold crayon. Gold gate. See? It all fits!" |
| 아이 단서 | 장화가 다 커서 '발끝으로 걸었다'고 우겨요. 작은 발의 주인은 말하지 않아요 | 크레용을 쓰는 게 누구일지는 말하지 않아요 |

- 고친 것:
  - "Tiny footprints"는 문장 첫머리의 대문자 Tiny가 NPC Tiny로 읽혀서 "Small"로 바꿨어요.
  - "grown-up"이 들어간 두 줄은 '아이가 했다'를 너무 분명하게 말해서 바꿨어요.

### 3주 · 실 한 가닥 (M1_2 '금·보라 끈'과 이어짐)
| | 빛의 성채 | 뿔 소굴 |
|---|---|---|
| 제목 | "BIG CLUE! A purple thread by the fountain!" | "BIG CLUE! A gold thread by the fountain!" |
| 1줄 | "The Horns hang red cloth everywhere. Purple is close to red. Hmm!" | "The Halos hang gold flags all over town. Just luck? No way!" |
| 2줄 | "A gold thread was braided into it. Please ignore that part." | "A purple thread was braided into it. That part doesn't count." |
| 아이 단서 | 두 벽보가 같은 끈을 반씩 보고 있어요. 금과 보라를 땋은 끈은 Bright·Smokey의 손목 끈이에요 | |

- 고친 것:
  - 뿔 진영 색은 빨강이에요(`Factions.Horns.Color` 220,50,60, kit_towns "붉은 천"). 그래서 "보라 리본"을 "보라는 빨강이랑 비슷하다"는 어설픈 추리로 바꿨어요.
  - 빛 색은 금(`Factions.Halo.Color` 255,215,90)이라 뿔 쪽 줄은 그대로 맞아요.

### 4주 · 같은 글 (범인 이름만 다름)
| | 빛의 성채 | 뿔 소굴 |
|---|---|---|
| 제목 | "OUR ANSWER: The Horns broke the Crown." | "OUR ANSWER: The Halos broke the Crown." |
| 1줄 | "Proof: We said it first. First means true. Right?" | "Proof: We said it first. First means true. Right?" |
| 2줄 | "P.S. They copied this poster. Word for word. Rude!" | "P.S. They copied this poster. Word for word. Rude!" |
| 웃음 포인트 | 두 벽보 모두 "우리가 먼저 말했다"고 해요. P.S.는 한쪽만 봐도 "글이 똑같다"는 힌트예요 | |

- 고친 것: "FINAL ANSWER:"는 유명 퀴즈쇼 말버릇이라 "OUR ANSWER:"로 바꿨어요. "Case closed"는 쓰지 않아요.

### 3-1. 만들 때 (개발 1)
- **게시판:** X_NoticeBoard는 교차로(kit_crossroads)에만 있어요.
  - **빛의 성채와 뿔 소굴에 게시판을 하나씩 새로 둬야 해요.**
  - 지금 키트 게시판 모델을 복제해 쓰고, 새 그림은 없어요.
  - 교차로의 MostWantedBoard는 쓰지 않아요.
  - 개발 1 ⑩ 일정에 배치를 더해 주세요.
- **글자:** SurfaceGui만 써요. 제목은 Fredoka One, 줄은 Builder Sans이고, 줄 사이는 `\n`으로 나눠요.
- **주 계산(버그 고침):** 시작 전에는 `math.floor(음수 / 604800) % 4`가 3이 되어 4주가 나왔어요. 이것을 고쳤어요.
  - 식: `week = (math.floor(math.max(0, Config.SeasonNow() - StartUtc) / 604800) % 4) + 1`
  - 시계는 핼러윈과 같은 `Config.SeasonNow()`(서버 시각)를 써요.
  - 서버가 1주 넘게 켜져 있을 수 있으니 1시간마다 다시 계산해요.
  - 시작 전(테스트 중)에는 1주예요. 베타 7주 동안 1→2→3→4→1→2→3으로 돌아요.
- **4주째 농담이 닿는 길:** 상대 마을에는 들어갈 수 없어요(`Config.Text.EnemyTown`). 그래서 이럴 때 웃음이 터져요.
  - 다른 편 친구끼리 서로의 벽보를 이야기할 때
  - 진영을 바꿨을 때
  - 개발 일지 영상에서 두 벽보를 나란히 보여 줄 때
- **점수:** 벽보는 보기만 하고 선택이 없어요. 그래서 Pick·명예·악명·A23-58과 상관없어요. '벽보 떼기' 같은 선택은 베타에 넣지 않아요.
- **A23-57:** 교차로·장인 벽보는 만들지 않아요. 빛·뿔 두 장만 둬요.
- **이어지는 줄:** 3주째 실 단서와 4주째 "Word for word"는 M1_2·M2_3의 새 줄(story_depth 베타 계획)이 코드에 들어가야 이어져요.

```lua
-- ⑩ blame posters (review 2026-10-06): one SurfaceGui board in Halo Citadel, one in Horns Den (beta: Halo/Horns only).
-- week = (math.floor(math.max(0, Config.SeasonNow() - StartUtc) / 604800) % 4) + 1, rechecked every RecheckSeconds.
-- Mock the poster writer's silly evidence only, never a side's looks or people.
Config.Story.BlamePosters = {
	StartUtc = 1793412000, -- 2026-10-31 11:00 KST (beta start); before it = week 1
	WeekSeconds = 604800,
	RecheckSeconds = 3600,
	Weeks = {
		{ -- 1: rumor
			Halo = { Head = "WHO BROKE THE CROWN? The Horns. Obviously.",
				Lines = { "They say someone yelled: 'If I can't have it, no one can!'", "A Horn yelled about the last cookie once. Same yell!" } },
			Horns = { Head = "WHO BROKE THE CROWN? The Halos. Who else?",
				Lines = { "Proof: It went CRACK. A Halo clapped very loudly that week.", "Clapping is loud. CRACK is loud. Think about it." } },
		},
		{ -- 2: small clue
			Halo = { Head = "NEW CLUE! Small footprints by the fountain!",
				Lines = { "We checked every Horn's boots. Way too big. Hmm!", "So: a Horn. On tiptoes. Mystery solved!" } },
			Horns = { Head = "NEW CLUE! A gold crayon by the fountain!",
				Lines = { "The Halos painted their gate gold. With crayons? Maybe!", "Gold crayon. Gold gate. See? It all fits!" } },
		},
		{ -- 3: one thread (M1_2 gold-purple band)
			Halo = { Head = "BIG CLUE! A purple thread by the fountain!",
				Lines = { "The Horns hang red cloth everywhere. Purple is close to red. Hmm!", "A gold thread was braided into it. Please ignore that part." } },
			Horns = { Head = "BIG CLUE! A gold thread by the fountain!",
				Lines = { "The Halos hang gold flags all over town. Just luck? No way!", "A purple thread was braided into it. That part doesn't count." } },
		},
		{ -- 4: word for word (only the culprit differs)
			Halo = { Head = "OUR ANSWER: The Horns broke the Crown.",
				Lines = { "Proof: We said it first. First means true. Right?", "P.S. They copied this poster. Word for word. Rude!" } },
			Horns = { Head = "OUR ANSWER: The Halos broke the Crown.",
				Lines = { "Proof: We said it first. First means true. Right?", "P.S. They copied this poster. Word for word. Rude!" } },
		},
	},
}
```

---

## 4. 호박 대왕 vs 유령 왕 9일 (⑫ · 개발 2 `Config.Halloween.Banter` 0.2일)

- **날짜:** 베타 핼러윈은 10/31 11:00 KST부터 11/9 00:00 KST(`EndsAt` 1794150000)까지예요. KST 날짜로 10/31이 Day 1, 11/08이 Day 9예요.
  - 식: `Day = math.floor((Config.SeasonNow() - 1793372400) / 86400) + 1`(1793372400 = 10/31 00:00 KST)
  - 1보다 작으면 1, 9보다 크면 9로 고정해요. 10/31 전에 시험하는 서버는 Day 1을 보여 줘요.
- **어디에 붙나:**
  - `PumpkinKingAppear` 공지 바로 다음 채팅에 호박 대왕 줄이 나와요. `GhostKingAppear` 다음에는 유령 왕 줄이 나와요.
  - 색은 그 공지의 `Events[Key].Color`를 써요. 토스트에는 넣지 않아요.
  - 유령 왕은 10분 뒤에 나와서 대답처럼 읽혀요. 그래도 한 줄만 봐도 뜻이 통하게 썼어요.
  - 앞에 `MonsterTypes[kind].Short`를 붙여요(예: `Pumpkin King: "…"`). 이름 2단어를 빼고 모든 줄이 12단어 이하예요.
- **`%d` 순서(꼭 지킬 것):** Day 9 유령 왕 줄은 **먼저** `string.format(line, count)`로 채우고, **그다음** `Format`(`%s: "%s"`)에 넣어요. 순서가 바뀌면 화면에 "%d"가 그대로 보여요.
  - count는 이 서버에서 두 대왕이 쓰러진 횟수의 합이에요. 서버 시작부터 메모리에만 세고 저장하지 않아요(`HalloweenService` Defeat 때 +1). 0이면 `GhostKingZero` 줄을 써요.
  - ⑭ 검사기의 'format 자리 수' 규칙은 `Banter.Days[9].GhostKing` 한 줄에서만 `%d` 1개를 예외로 받아요.
- **말줄임표:** 다른 블록과 Config 글자처럼 한 글자 "…"로 맞췄어요("..."는 쓰지 않아요).
- **되풀이:** 같은 날에는 20분마다 같은 줄이 나와요(서버 하나에서 하루 약 72번). 그래서 시각("tonight")이나 승패("you lost")에 기대는 말은 쓰지 않았어요.
- **흐름:**
  - 1~5일: 라이벌 자랑이에요. 4일째는 우스운 증거로 서로 탓해요(왕관 소문 A23-55를 비추는 거울).
  - 6일: 처음으로 조용함을 느껴요.
  - 7일: 두 진영이 함께 대왕을 잡는 모습을 보고 "같이 하는 게 재밌어 보인다"고 해요.
  - 8일: "One crown, two kings?"
  - 9일: Truce.
- **규칙 확인:**
  - 놀리는 대상은 행동(자랑·탓하기·사탕 쌓기)과 물건뿐이에요.
  - 장인 길드는 말하지 않아요(A23-57).
  - "Team Pumpkin / Team Ghost" 고르기나 투표는 없어요. 제3 진영이나 A23-58 선택처럼 보이지 않게 하려는 거예요.
  - "Pumpkin King"과 이름이 같은 유명 영화의 대사·노래·"King of Halloween"은 쓰지 않았어요.
  - "Truce!"는 조금 어려운 말이에요. 하지만 바로 뒤 "One big candy party"가 뜻을 알려 줘서 그대로 둬요.

| Day (KST) | Pumpkin King (Appear 뒤) | Ghost King (Appear 뒤) |
|---|---|---|
| 1 · 10/31 | "Happy Halloween! Just so you know, the best king here is me." | "Best king? My ribbon says it's me. I made the ribbon." |
| 2 · 11/01 | "My candy pile is taller than the trees in the Haunted Hollow!" | "Cute pile. Mine has a second pile sitting on top." |
| 3 · 11/02 | "I can bounce from here to the Crossroads in one hop!" | "I floated there and back twice. You were still bouncing." |
| 4 · 11/03 | "My best candy is gone! Clue: glowy crumbs. Hmm, Ghost King?" | "Not me! And why is there orange jelly on MY candy?" |
| 5 · 11/04 | "New crown! Bigger than yours. With extra sprinkles!" | "Mine has a bell on top. It rings when I'm right. Ding!" |
| 6 · 11/05 | "Biggest crown, pile, AND bounce! …So why is it so quiet?" | "Quiet here too. Nobody plays tag with a king." |
| 7 · 11/06 | "Both sides teamed up on me. They looked like they had fun!" | "Same here. Teaming up looks fun. …Hey, Pumpkin. Want to try it?" |
| 8 · 11/07 | "Okay, Ghost King. One crown, two kings? It's sticky, but it's big." | "Deal. You hold the left side. I hold the shiny side." |
| 9 · 11/08 | "Truce! One big candy party. Ghost King, you bring the music!" | "Truce! Kings beaten on this server: %d. Fine, you're all invited!" |
| 9 · 처치 0 | (같음) | "Truce! No kings beaten here yet. Party anyway. Come on in!" |

- **Day 7 대체 줄(선택, 두 아이 복선):** 호박 대왕 줄을 "Two kids just split one candy bag. Nobody fought. Is that allowed?"로 바꿔도 돼요.
  - 이름이 없고 비밀도 밝히지 않아서 5장 스포일러가 아니에요.
  - 바꿔도 유령 왕 줄은 그대로 둬요.

```lua
	-- ⑫ (review 2026-10-06): one line after each king's Appear announcement, by KST day (Day 1 = 2026-10-31)
	-- day = math.floor((Config.SeasonNow() - DayOneStart) / 86400) + 1, clamped 1..#Days
	-- Day 9 GhostKing: string.format(line, count) FIRST (count = both kings' defeats on this server, memory only;
	-- 0 -> GhostKingZero), THEN string.format(Format, Config.MonsterTypes[kind].Short, line). Chat only, no toast.
	Banter = {
		DayOneStart = 1793372400, -- 2026-10-31 00:00 KST
		Format = "%s: \"%s\"",
		Days = { -- keys = Config.Halloween.Bosses[i].Key
			{ PumpkinKing = "Happy Halloween! Just so you know, the best king here is me.",
				GhostKing = "Best king? My ribbon says it's me. I made the ribbon." },
			{ PumpkinKing = "My candy pile is taller than the trees in the Haunted Hollow!",
				GhostKing = "Cute pile. Mine has a second pile sitting on top." },
			{ PumpkinKing = "I can bounce from here to the Crossroads in one hop!",
				GhostKing = "I floated there and back twice. You were still bouncing." },
			{ PumpkinKing = "My best candy is gone! Clue: glowy crumbs. Hmm, Ghost King?",
				GhostKing = "Not me! And why is there orange jelly on MY candy?" },
			{ PumpkinKing = "New crown! Bigger than yours. With extra sprinkles!",
				GhostKing = "Mine has a bell on top. It rings when I'm right. Ding!" },
			{ PumpkinKing = "Biggest crown, pile, AND bounce! …So why is it so quiet?",
				GhostKing = "Quiet here too. Nobody plays tag with a king." },
			{ PumpkinKing = "Both sides teamed up on me. They looked like they had fun!",
				GhostKing = "Same here. Teaming up looks fun. …Hey, Pumpkin. Want to try it?" },
			{ PumpkinKing = "Okay, Ghost King. One crown, two kings? It's sticky, but it's big.",
				GhostKing = "Deal. You hold the left side. I hold the shiny side." },
			{ PumpkinKing = "Truce! One big candy party. Ghost King, you bring the music!",
				GhostKing = "Truce! Kings beaten on this server: %d. Fine, you're all invited!" }, -- the only %d (⑭ exception)
		},
		GhostKingZero = "Truce! No kings beaten here yet. Party anyway. Come on in!",
	},
```

---

## 5. 조각의 처음 안내 (⑬ · BB24를 만드는 개발 1이 Kind 'Shard'로 넘김)

처음 겪는 순간 안내(BB24, A23-50)를 짝꿍 **Crown Shard** 말투로 바꾼 줄이에요. 빛·뿔만 넣고 장인 줄은 없어요(A23-57).

### 5-1. 규칙
1. **표시:** `Kind = "Shard"`로 조각 아이콘과 ②의 높은 '삑삑' 목소리를 써요. 토스트는 최대 2줄이고, 한 번에 하나씩 5초 동안 떠요. 계정마다 1번만 떠요(`data.Story.First` 키, hud_layout_spec first_time_hints).
2. **단어 수:** 공백으로 세요. `{키 토큰}`과 `%s`는 1단어, 아이템 이름은 최대 3단어로 세요. 모든 줄이 12단어 이하예요.
3. **베타에는 진영이 둘뿐이에요.** 같은 진영끼리는 PvP가 안 돼요(`PvPService.CanAttack` → "SameFaction"). 그래서 "other sides"가 아니라 **"the other side"** 로 써요. 지금 있는 `Config.Text.GraduateStart`도 같이 고쳐요(5-3 `SproutDone`).
4. **같은 정보:** 빛과 뿔은 같은 `All` 줄을 받아요.
   - 진영 맛(선택)은 첫머리만 바꾸고 사실은 그대로예요.
   - 현상 별과 원한 자루는 진영 차이가 아니라 역할(훔친 쪽/털린 쪽) 차이라서 짝으로 뒀어요.
5. **조각이 아직 왕 슬라임 안에 있을 때(S0 1단계 전):**
   - 그때 뜰 수 있는 줄(쓰러짐·PvP·Lv10·거위·전쟁 미터·가방)은 'I/me' 없이 썼어요.
   - 'I'가 들어간 줄(자동 해금, 쉴 때 한마디)은 S0 1단계 뒤에만 떠요.
   - S0 전에는 아이콘 없는 기본 토스트로 같은 문장을 띄워요(개발 1 판단).
6. **숫자는 Config에서 format으로 넣어요:**
   - 3 = `Goose.MinManualHits`, 45 = `Grudge.SackSeconds`, 2 minutes = `Kaiju.Duration`(120)
   - 30 = `War.ChestMinPoints`, 50 = `RebirthLevel(0)`, x1.5 = `Kaiju.SurviveBankMult`
   - 3/5 stars = `PvP.NoTravelStars`/`Kaiju.StarsNeeded`, 1 minute = `PvP.GraduateGraceSeconds`(60), 10 = Goblin Woods 열림 레벨
   - 초가 60으로 나누어떨어지면 "%d minute(s)", 아니면 "%d seconds"로 써요. "120 s" 같은 줄임말은 쓰지 않아요.
   - 레벨은 "Lv10"처럼 띄어 쓰지 않아요(지금 화면 "Lv10 · Goblin Woods"와 같게).
   - 배수는 ASCII "x1.5"로 써요(지금 PvPNote와 같게).
7. **키 토큰:** 서버는 `{Auto}`를 폰과 PC 구분 없이 키 이름 "R"로 채워요(`Config.FillKeys`). LootService 알림은 토큰을 아예 채우지 않아요.
   - 그래서 **조각 토스트는 클라이언트에서 `Keybinds.Fill`로 채워요.** PC는 키 이름, 폰은 버튼 이름이 들어가요.
   - 이 경로를 쓸 수 없으면 표의 '토큰 없는 줄'을 써요.
8. **이미 뜨는 글과 겹치지 않게**
   - KO 화면이 이미 "Nothing lost"·"Lost %s pouch gold"·"Back in %d s"를 보여 줘요. 첫 쓰러짐 줄은 이 사실을 다시 말하지 않아요.
   - Lv10에는 지금 레벨 업 공지와 `Config.StoryLines.GoblinWoods` 토스트(Fx:1997)가 함께 떠요. 조각 줄을 더하지 말고 **StoryLines 토스트를 조각 줄로 바꿔요.** M2_7 안내자가 금고 경고를 하니 1줄만 둬요.
   - 자동 해금의 '몬스터만' 안내는 S4 시작 대사("Players, only by your own hand!")가 이미 해요.
   - 털린 쪽 줄은 KO 화면의 120% 팁과 겹치지 않게 했어요.
   - 같은 KO에서 원한 자루 줄과 첫 쓰러짐 줄이 함께 걸리면 원한 자루 줄만 띄워요. 첫 쓰러짐 줄은 다음 쓰러짐으로 미뤄요.
9. **기존 문구 대체:**
   - 원래 1번만 뜨는 문구는 조각 줄로 바꿔요: `Loot.Text.FirstScroll`/`FirstScrollBare`, `StoryQuests.Text.Unlocked`, `Config.StoryLines.GoblinWoods`, `Config.Text.GraduateStart`.
   - `ItemFull`·`ItemFullUse`·`PotionFull`은 **첫 1번만** 조각 줄로 띄워요. 그 뒤에 반복될 때는 지금 시스템 문구 그대로예요.
10. **안전:**
    - kill/die/dead/bad/wrong/should/shame, 종교, 연애, 브랜드, 두 뜻 표현이 없어요.
    - 진영이나 무리를 놀리지 않아요.
    - 환생을 권하지 않아요("No rush", story_depth 1-2).
    - 확률은 정직하게 써요(story_depth 5-1).

### 5-2. 처음 겪는 순간 (베타)
| # | 키(제안) | 언제 · 어디 | 줄 1 (EN) | 줄 2 (EN) | 단어 |
|---|---|---|---|---|---|
| 1 | `FirstKO` | 첫 쓰러짐 · CombatService KO Fx(`Lost`로 고름) | Lost = 0: "Oof! Nap time. It happens to every hero. Try again!"<br>Lost > 0: "Oof! Only Pouch gold can be lost. Vault gold is always safe." | Lost > 0만: "Walk into a town and your gold goes to your Vault." | 10 / 12 · 11 |
| 2 | `PvPZone` | 첫 PvP 지역(숲·유적) 입장 · ZoneService | 새싹 보호 중: "Psst! The other side fights here. Your Sprout Shield keeps you safe."<br>새싹 보호 없음: "Psst! The other side fights here. Keep your gold in the Vault!" | "Careful! KO someone much weaker and you become a Bully." (Bully 첫째 규칙만 말해요. 세 규칙 전부는 도움말·캐릭터 창에 그대로 있어요) | 12 / 12 · 10 |
| 3 | `Level10` | 처음 Lv10 · Fx:1997 `Config.StoryLines.GoblinWoods` 값을 이 줄로 **바꿈** | "Lv10! New monsters and new loot wait in the Goblin Woods!" | (없음. M2_7 안내자가 금고 경고를 해요) | 11 |
| 4 | `GooseFirst` | 첫 거위 착지(첫 임무 뒤) · GooseService | All: "Golden Goose time! Hit it yourself 3 times for a reward."<br>빛(선택): "Golden Goose! Rescue it: hit it yourself 3 times for a reward."<br>뿔(선택): "Golden Goose! Poach it: hit it yourself 3 times for a reward." | 자동 해금 뒤만: "Auto Battle helps pull, but only your own hits earn the reward." | 11 / 12 / 12 · 12 |
| 5 | `FirstScroll` | 첫 왕 슬라임 70% 주문서 · LootService(S0 1단계와 같은 처치라서 사실상 조각의 첫마디) | 무기 있음: "Ooh, a scroll! Open your Bag ({Bag}) and make your weapon stronger."<br>토큰 없는 줄: "Ooh, a scroll! Open your Bag and make your weapon stronger."<br>맨손: "Ooh, a scroll! Keep it for your first weapon from the Blacksmith." | "If it fails, it may slip a level, but never breaks. Promise!" (`FailDropChance` 0.5, +0 아래로는 안 내려감) | 12 / 11 / 12 · 12 |
| 6 | `AutoUnlock` | S0 끝 자동 해금 · StoryQuestService(`Text.Unlocked` 대체) | 클라이언트 채움: "I learned your moves! Switch Auto Battle on or off with {Auto}."<br>서버 채움(토큰 없는 줄 대신): "I learned your moves! Auto Battle: {Auto} or the Auto button." | (없음. S4 시작 대사가 '몬스터만'을 말해요) | 12 / 11 |
| 7 | `WarMeter` | 전쟁 미터가 처음 보일 때(⑨ HudLayout.Reveal, ⑨가 빠지면 첫 전쟁 점수) · HUD/WarService | "See the sky crown? It glows for the side with more points!" | "Beat monsters for points. 30 in one round earns a chest!" | 12 · 11 |
| 8 | `BagFull` | 처음 아이템·물약이 가득 찼을 때 · LootService | 재료: "%s is full! Sell some at the Forge for gold."<br>주문서: "%s is full! Use some from your Bag."<br>물약: "You can't carry more potions! Drink one to make room." | (없음) | ≤12 / ≤10 / 10 |
| 9 | `WantedStar` | 뿔: 첫 현상 별 · PvPService | "Ooh, a Wanted star! Knights get Bounty gold for catching you." | "Stars fade with time. 3 stars: no Travel. 5 stars: Kaiju!" | 11 · 11 |
| 9b | `FirstBounty`(선택, 9의 짝) | 빛: 첫 현상금 받음 · PvPService | "Nice catch! More Wanted stars mean a bigger Bounty." | (없음) | 9 |
| 10 | `GrudgeThief` | 뿔: 첫 원한 자루를 들었을 때 · GrudgeService | "Grudge Sack! Survive 45 seconds in the PvP zone and it's yours." | "No Travel while you carry it. Knights will try to catch you!" (`TravelBlockedSack`) | 12 · 12 |
| 10b | `GrudgeVictim` | 빛: 처음 털렸을 때 · GrudgeService | 클라이언트 채움: "Your gold is in their Grudge Sack! Ghost hold ({GhostHold}) adds time."<br>토큰 없는 줄: "Your gold is in their Grudge Sack! Ghost hold buys you time." | (없음. 120% 팁은 KO 화면에 있어요) | 12 / 12 |
| 11 | `KaijuFirst` | 첫 괴수 알림 · KaijuService | All: "Whoa, a Kaiju! It stays huge for 2 minutes."<br>빛(선택): "Whoa, a Kaiju! Team up, Knights. It stays huge for 2 minutes."<br>뿔(선택): "Whoa, a Horn Legion Kaiju! It stays huge for 2 minutes." | All: "Knights can hit it anywhere. If it lasts, the Horn Legion scores." | 9 / 12 / 11 · 12 |
| 11b | `KaijuSelf`(선택) | 내가 처음 괴수가 될 때 · KaijuService | "Kaiju time! Survive 2 minutes: Pouch gold x1.5 into your Vault!" | "The bonus counts only if Knights try to stop you." | 11 · 10 |
| 12 | `RebirthReady` | 처음 환생 가능 레벨 · ProgressionService | "Lv50! Rebirth is open. Only your level starts over." | "No rush. It waits in Settings whenever you want." | 9 · 9 |

- 11b 줄 2는 검수가 더 확인해서 넣었어요. 아무도 싸우러 오지 않으면 보너스가 없어요(`KaijuService` 422줄 `opposed`, "Nobody fought you … (no bonus)").
- 10b의 "Ghost hold"는 키 설정 이름(`Keybinds` Label "Ghost hold")과 같게 맞췄어요.
- 1의 Lost > 0 줄은 KO 화면 "Lost %s pouch gold"와 같은 사실을 되풀이하지 않게 바꿨어요(규칙 8).

### 5-3. 덧붙이면 좋은 것 (선택, BB24 밖)
| 키(제안) | 언제 | 줄 1 (EN) | 줄 2 (EN) | 단어 |
|---|---|---|---|---|
| `BullyFirst` | 첫 깡패 KO · PvPService | "Uh-oh, a Bully KO! Half XP and drops until it fades." | 자동 해금 뒤만: "And I can't Auto Battle for you until then. Sorry!" | 11 · 10 |
| `RankDown` | A23-58 첫 계급 내려감(아직 코드에 없어요. 기능과 최종 문구 모두 개발 2 일) | All: "Your rank went down. Picks that fit your side bring it back."<br>빛(선택): "Your rank slipped. Knightly picks will bring it back up!"<br>뿔(선택): "Your rank slipped. Sneaky picks will bring it back up!" | (없음) | 12 / 10 / 10 |
| `SproutDone` | 새싹 졸업. 지금 `Config.Text.GraduateStart`("…fight other sides in 60 s") 대체 | "Sprout Shield done! In 1 minute, the other side can fight you." | (없음) | 12 |

### 5-4. 쉴 때 한마디 (3줄, 빛·뿔 공통)
- "Stuck? Tap your quest line. I'll light the way!"
- "You're getting stronger. I can feel it. Ready for more?"
- "Best part of being a shard? Adventuring with you!"
- 쓰는 법(개발 1 판단):
  - S0 1단계 뒤에만, 접속마다 최대 1번 띄워요.
  - 마을에서 20초 넘게 서 있을 때 띄워요.
  - 싸우는 중, PvP 지역, 다른 토스트가 떠 있을 때는 띄우지 않아요.
  - 지금 있는 AutoSleepy·AutoRest 문구는 기능 경고라서 그대로 둬요.

---

## 6. 효과음 크기 표 (① · 이미지 개발 Audio.luau, 촬영 편집 다듬기, Kenney Impact + Interface CC0)

**읽는 법**
- **Volume**은 Sound.Volume 값(0~1)이에요. 설정의 'Sound effects'(Sfx 0~1) 값이 여기에 곱해져요.
- **자동 0.5x**는 자동 전투가 낸 소리일 때 볼륨만 0.5배로 줄인다는 뜻이에요. 속도는 그대로예요.
- **측정**은 `build/devlog/sfx/` 원본을 ffmpeg로 잰 값이에요. 길이(초)와 120Hz 아래 에너지 비율을 적었어요. 이 비율이 높을수록 폰 스피커에서 거의 안 들려요.
- 파일 이름은 실제 이름을 따라요. Impact는 `_000~_004`, Interface는 `_001~`이에요. `tick`은 `_001·_002·_004`만 있어요(`_003` 없음).

**크기 순서(지킬 것):** 전투(0.28~0.40) < UI(0.42~0.60) < 큰 순간(0.65~0.75) < **레벨 업 0.85**(가장 큼)

| # | 이벤트 (Audio 키) | Kenney 파일 (후보는 "중 하나") | 측정 | Volume | PlaybackSpeed | 최대 겹침 | 쿨다운 | 자동 0.5x |
|---|---|---|---|---|---|---|---|---|
| 1 | 전사 휘두르기 `SwingWarrior` | Kenney에 바람 소리 없음 → 촬영 편집 합성 whoosh(`synth_sfx("whoosh")`, 0.15~0.2s, 500~3000Hz 띠) | 직접 만든 소리 | 0.30 | 0.92~1.05 랜덤 | 2 | 0.08 | 예 |
| 2 | 마법사 쏘기 `SwingMage` | `glass_003` · `maximize_009` · `select_005` 중 하나 | 0.12~0.38s, 저음 0~4% | 0.28 | 1.00~1.10 랜덤 | 2 | 0.08 | 예 |
| 3 | 궁수 쏘기 `SwingArcher` | `pluck_001` · `pluck_002` 중 하나 | 0.10~0.16s, 저음 0%, 밝음(~5kHz) | 0.28 | 0.85~0.95 랜덤 | 2 | 0.08 | 예 |
| 4 | 맞힘 약 `HitSoft` (슬라임·유령·호박) | `drop_004` · `impactGeneric_light_000` · `impactWood_light_002` 중 2개(변형) | 0.14~0.29s, 저음 4~20% | 0.32 | 0.95~1.10 랜덤 | 3 | 0.05 | 예 |
| 5 | 맞힘 강 `HitHeavy` (고블린·우두머리·치명타) | `impactPunch_medium_002` · `_004` · `impactWood_medium_002` 중 2개(변형) | 0.33~0.54s, 저음 12~25% | 0.38 | 0.90~1.00 랜덤 | 3 | 0.06 | 예 |
| 6 | 처치 '뽕' `KillPop` | `drop_002` (영상 pop과 같은 소리) | 0.19s, 저음 4% | 0.40 | 0.95~1.12 랜덤 | 3 | 0.05 | 예 |
| 7 | 연속 처치 동전 `ComboCoin` | `impactMetal_light_002` · `_004` · `glass_002` 중 하나 | 0.13~0.24s, 저음 1~3% | 0.30 | 한 단계마다 오름(아래) | 2 | 0.06 | 예 |
| 8 | 콤보 기념 `ComboMilestone` (x10·25·50·100) | `confirmation_003` | 0.32s, 저음 0% | 0.45 | 1.0 고정 | 1 | 1.0 | 예 |
| 9 | 레벨 업 팡파르 `LevelUp` | 촬영 편집이 한 파일로 섞기: `confirmation_002` + 0.1s 뒤 `impactBell_heavy_002` + `glass_004` 반짝 | 약 1.0~1.2s, 저음 13% 이하 | **0.85** | 1.0 고정 | 1 | 2.0 | **아니요(늘 전체 크기)** |
| 10 | 창 열기 `WindowOpen` | `maximize_008` (또는 `_006`·`_009`, 닫기와 같은 번호) | 0.23s, 저음 0% | 0.45 | 1.0 고정 | 1 | 0.15 | 아니요 |
| 11 | 창 닫기 `WindowClose` | `minimize_008` (열기와 같은 번호) | 0.23s, 저음 0% | 0.42 | 1.0 고정 | 1 | 0.15 | 아니요 |
| 12 | 안 돼요 `Deny` | `error_004` · `error_008` 중 하나 | 0.10~0.14s, 저음 6~26% | 0.45 | 1.0 고정 | 1 | 0.5 | 아니요 |
| 13 | 자동 켜기 `AutoOn` | `toggle_002` · `toggle_001` · `switch_001` 중 하나 | 0.14s, 저음 0% | 0.50 | 1.10 | 1 | 0.3 | 아니요 |
| 14 | 자동 끄기 `AutoOff` | 켜기와 같은 파일 | 같음 | 0.45 | 0.90 | 1 | 0.3 | 아니요 |
| 15 | 정화 '찰랑' `Purify` | `glass_001` · `glass_006` · `impactGlass_light_002` 중 하나 | 0.11~0.28s, 저음 1~2% | 0.55 | 1.00~1.05 | 1 | 1.0 | 아니요 |
| 16 | 삼킴 '꿀꺽' `Devour` | 촬영 편집이 한 파일로 섞기: `bong_001`(0.9x) + `drop_004`(0.75x) | 약 0.3s, 저음 약 11% | **0.55 (정화와 같게)** | 1.00~1.05 | 1 | 1.0 | 아니요 |
| 17 | 호박 대왕 등장 `PumpkinKing` | `impactBell_heavy_000` · `_001` 중 하나 (+ 끝에 `maximize_006` '뿅'을 붙여도 됨) | 1.5~1.7s, 저음 7~8% | 0.70 | 0.90~0.95 (**0.85 아래 금지**) | 1 | 60(등장당 1번) | 아니요 |
| 17b | 유령 왕 등장 `GhostKing` | **#17과 같은 파일**(업로드 추가 0개) | 같음 | 0.70 | **1.00~1.05**(조금 가볍게, 0.85 아래 금지 그대로) | 1 | 60(등장당 1번) | 아니요 |
| 18 | 거위 '꽥' `GooseHonk` | Kenney에 없음 → 촬영 편집 합성(코맹맹이 '꽥' 0.15s×2, 500~700Hz, 끝음 내림). 안 되면 `error_004`를 0.75x로 두 번 | 직접 만든 소리 | 0.55 | 0.95~1.10 랜덤 | 1 | 3.0 | 아니요 |
| 19 | 퀘스트 완료 `QuestDone` | `confirmation_001` (또는 `_004`) | 0.29s, 저음 0% | 0.65 | 1.0 고정 | 1 | 1.0 | 아니요 |
| 20 | 골드 받기 `GoldPickup` (처치 밖: 보상·판매·주머니) | `tick_004` (영상 coin과 같은 소리) | 0.05s, 저음 2% | 0.45 | 0.95~1.10 랜덤 | 3 | 0.08 | 아니요 |
| 21 | 주문서 성공 `ScrollSuccess` | 한 파일로 섞기: `confirmation_004` + `glass_004` 반짝 | 약 0.7s, 저음 0% | 0.70 | 1.0 고정 | 1 | 0.5 | 아니요 |
| 22 | 주문서 실패 `ScrollFail` | `back_002` · `error_008` 중 하나 ('아쉽다' 느낌) | 0.07~0.14s | 0.45 | 0.90 | 1 | 0.5 | 아니요 |
| 23 | 버튼 누름 `Tap` | `select_002` · `tick_002` 중 하나 | 0.02~0.04s, 저음 0~2% | 0.42 | 0.98~1.02 | 1 | 0.05 | 아니요 |
| 24 | 스킬 시전 `SkillCast` (Q·Z·X) | 내 직업 휘두르기 파일을 0.85x로 + 아래 진영 층 | — | 0.40 | 0.85 | 2 | 0.1 | 예 |
| 25 | X 진영 층: 빛 `SkillHalo` | `glass_005` | 0.11s, 저음 0% | 0.36 | 1.0 | 1 | 0.3 | 예 |
| 26 | X 진영 층: 뿔 `SkillHorns` | `bong_001` | 0.12s, 저음 11% | 0.36 | 1.0 | 1 | 0.3 | 예 |
| 27 | 내가 세게 맞음 `HurtBig` (⑥과 같은 순간) | `impactPunch_medium_004` | 0.54s, 저음 25% | 0.36 | 0.95~1.05 | 1 | 0.6 | 아니요 |
| 28 | 물약 마시기 `Potion` | `drop_001` · `glass_003` 중 하나 | 0.11~0.12s | 0.42 | 1.0~1.05 | 1 | 0.3 | 아니요 |
| 29 | 새 퀘스트 받기 `QuestNew` | `select_003` · `maximize_009` 중 하나 | 0.22~0.38s, 저음 0% | 0.50 | 1.0 고정 | 1 | 1.0 | 아니요 |
| 30 | 계급 내려감·점수 −(A23-58) `RankDown` | `back_004` (작게), 또는 소리 없음 | 0.07s | 0.35 | 1.0 | 1 | 2.0 | 아니요 |

**연속 처치 음 올리기(#7)**
- 속도 = `0.8 × 2^(s/12)`이고, s는 장음계 `{0,2,4,5,7,9,11,12}`를 따라가요.
- 그래서 0.80 → 0.90 → 1.01 → 1.07 → 1.20 → 1.35 → 1.51 → **1.60**이에요. 8번째부터는 1.60에 머물러요. 폰에서 끝음이 날카로워지지 않게 하려는 거예요.
- 처치 없이 4초(`Config.Combo.ResetSeconds`)가 지나면 처음으로 돌아가요.
- 콤보 중에 처치로 얻은 골드는 #7만 내고 #20은 내지 않아요.

**폰 스피커(저음 주의, 측정값)**
- 폰 스피커는 약 200Hz 아래가 거의 안 나와요. 아래 소리는 폰에서 거의 안 들리고, PC 헤드폰에서는 '쿵' 하고 커져요. 그래서 게임에는 쓰지 않아요.

  | 소리 | 120Hz 아래 비율 |
  |---|---|
  | `impactSoft_heavy_*` | 99% |
  | `impactSoft_medium_*` | 92~96% |
  | `impactMining_*` | 83~96% |
  | `impactPunch_heavy_*` | 67~83% |
  | `impactPlate_heavy_*` | 60~85% |
  | `impactWood_heavy_*` | 61~94% |
  | `impactMetal_heavy_*` | 62~67% |
  | `switch_003~005` | 72~90% |
  | `error_005` | 78% |
  | `glitch_001` | 76% |

  `impactSoft_heavy_000`은 영상의 boom에는 써도 돼요. 영상은 헤드폰 기준으로 섞기 때문이에요.
- 촬영 편집이 다듬을 때 할 일:
  - 모든 전투 소리에 150Hz 하이패스(12dB/oct)를 걸어요.
  - 피크를 −3 dBFS로 맞춰요. Impact 원본은 디코드하면 피크가 +1.4~2.4 dBFS라서 이미 잘리고 있어요.
  - 파일마다 크기를 RMS 약 −18 dB로 맞춰요. 원본이 −10~−26 dB로 제각각이라, 맞추지 않으면 위 Volume 숫자가 뜻이 없어져요.
- `open_00x`·`close_00x`는 소리 중심이 9~13kHz라서 폰에서 '칙' 하는 잡음처럼 들려요. 그래서 창 소리는 `maximize`/`minimize` 006·008·009를 써요.
- 폰에서 한 번, 소리를 중간으로 두고 들리는지만 확인해요.

**Audio.luau 규칙(이미지 개발)**
- **겹침:** 이벤트마다 Sound를 '최대 겹침' 수만큼 미리 만들어 두고 돌려 써요.
  - 지금 `Fx.PlaySound`는 이름 하나에 Sound 하나뿐이에요. 그래서 연주 중에 PlaybackSpeed를 바꾸면 이미 나는 소리까지 바뀌어요.
  - 다 차면 새 소리는 건너뛰어요. 전체 동시 소리는 8개까지예요.
- **여러 마리를 맞힐 때:** 스킬 한 번에 **여러 마리**를 맞혀도(전사는 `Targets = 0`, 무제한) 맞힘 소리는 한 번만 내요. 3마리 이상이면 #4 대신 #5를 내요.
- **다른 플레이어 소리:** 남의 휘두르기·맞힘·처치 소리는 0.35배로 작게 내고, 40스터드 밖이면 내지 않아요. UI 소리는 나에게만 나요.
- **큰 순간 덕킹:** #9·#17·#17b·#21이 날 때 전투 소리를 1.2초 동안 0.5배로 낮춰요.
- **설정:** 'Sound effects'가 0이면 아무 소리도 내지 않아요(지금 동작 그대로).
- **옛 키 옮기기:** `Config.Sounds`의 Swing → #1~3(직업별), Release → #24, Coin → #20, Click → #23으로 바꿔요. 옛 rbxasset 파일은 Id가 없을 때의 대체 소리로만 남겨요.

**이야기·안전 규칙과 맞추기**
- 정화와 삼킴은 같은 크기(0.55)이고 둘 다 기분 좋은 소리예요. 삼킴을 '틀렸다'는 오류음처럼 만들지 않아요(story_depth §1-2, §1-5). 방귀처럼 들리게도 하지 않아요.
- 주문서 실패와 계급 내려감은 혼내는 부저가 아니라 작은 '아쉬움' 소리예요.
- 두 대왕은 공포 효과음이 아니라 장난스러운 종소리예요. 0.85x 아래로 늦추면 낮고 무서워져서 금지예요.
- 거위 '꽥'은 직접 합성해요. 유명 게임의 꽥 소리를 흉내 내거나 출처 모르는 녹음을 쓰지 않아요. 유명한 '동전 소리'를 닮게 만들지도 않아요.
- 사람 목소리(TTS)로 만든 몬스터·대왕 소리는 쓰지 않아요(품질 문서 §4).
- 화면에 나오는 글자는 없어요.

**개수와 일정**
- 올릴 파일은 **27~30개**예요.
  - #1~#30에서 같은 파일을 다시 쓰는 줄(#14, #17b, #24)을 빼고, #4·#5 변형을 2개씩 세면 최대 30개예요.
  - #9·#16·#21은 섞어서 한 파일로 만들어요.
  - 후보가 겹치면 줄어요: #27 = #5 변형 `_004`, #28 `glass_003` = #2 후보, #29 `maximize_009` = #2·#10 후보, #18 대체 소리 `error_004` = #12 후보.
  - #30을 '소리 없음'으로 하면 하나 더 줄어요.
- 비용은 0원이에요. 출처는 `docs/devlog/sfx_licenses.md` 장부에 한 줄씩 적어요(촬영 편집).
- **업로드 한도부터 확인해요(7번).** 검수가 알기로는 ID 인증 계정은 30일 100개, 인증 안 한 계정은 30일 10개예요. 하지만 확인된 내용은 아니에요.
  - 한도가 100개면: 후보는 10/12까지 고르고, 10개씩 나눠 10/15까지 올려요.
  - 한도가 10개면: 10/15까지 1차 10개만 올려요.
    - 1차 10개: #1·#2·#3·#4(변형 1)·#5(변형 1)·#6·#7·#9·#17·#19
    - 첫 10분의 전투 느낌과 베타 주간 핼러윈 대왕이 먼저예요.
    - 나머지는 30일 뒤에 올려요. 그동안은 지금 소리(`Config.Sounds`)나 Roblox가 이미 올린 무료 소리를 써요.
- 업로드는 사용자 답(품질 문서 §5-1)을 받은 뒤에 해요.

---

## 7. 남은 확인
1. **(사용자·업로드)** 새 Roblox 계정의 오디오 업로드 한도를 Creator Dashboard에서 확인해야 해요(ID 인증 여부와 30일 개수). 품질 문서 §5-1 질문의 "30일 100개 무료 한도 안"도 확인 결과에 맞게 고쳐서 물어요.
2. **(개발 1 일정)** 빛의 성채·뿔 소굴에 게시판 2개를 새로 두는 일이 ⑩에 더해져요. 일수를 다시 적어 주세요.
3. **(개발 2)** 두 문구를 정해 주세요.
   - A23-58 알림과 OddHalo/OddHorns를 한 토스트로 합친 최종 문구
   - `RankDown` 계급 안내 문구
4. **(개발 2 일정)** 3주째 벽보의 실 단서와 4주째 "Word for word"는 M1_2·M2_3의 새 줄이 베타에 들어가야 이어져요. 그 줄이 베타에 들어가는지 확인해 주세요.
5. **(⑭ 검사기)** 지금 있는 긴 줄(예: 빛 환영 1쪽 첫 줄 18단어)은 14단어 검사에 걸려요. 이 묶음 밖의 일이라 개발 2가 영어를 손볼 때 같이 줄여 주세요.

---
검수 메모(2026-10-06 밤): 사용자 결정 — 스모키도 여자아이(A23-59 보강, 그림 그대로). 위 1-2 성비 표와 맞아요. 화면 영어에서 Bright·Smokey 모두 she/her.
