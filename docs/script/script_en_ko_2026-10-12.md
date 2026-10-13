# 게임 대본 (영어 원문 + 한국어 뜻)

2026-10-12에 main 기준으로 만듦. 2026-10-13: 보이는 이름 바꿈(A23-138: Smokey → Rose, Flappy Zigzag → Bat Zigzag, Legendary Villain → Final Boss; 설정 키·퀘스트 id는 그대로)과 첫 무기 새 흐름 글(맨 아래 '10/13 새 글')을 손으로 넣음. 글이 바뀌면 다시 만들어야 함 (영어 목록은 `py tools/l10n_export.py --out build/script_tmp/strings_server_en.json`으로 뽑을 수 있음).

게임 화면은 영어뿐입니다(SPEC A23-146). 이 문서는 **소유자만 읽는 용도**이고 게임에는 들어가지 않습니다.

## 이 문서 보는 법

1. 표 한 줄 = 게임에 나오는 글 한 줄. **영어**는 게임에 나오는 그대로, **한국어 뜻**은 이해를 돕는 풀이(다듬은 번역 아님), **메모**는 어디에 나오는지와 설정 이름(Config 키).
2. `%d`는 숫자, `%s`는 이름이나 숫자, `%d/%d`는 지금 숫자/목표 숫자, `%%`는 % 기호 하나, `{Auto}` 같은 것은 게임이 알아서 채우는 자리입니다. 줄바꿈은 `<br>`로 보입니다.
3. 메모 앞의 **[숨김]**은 설정 파일엔 있지만 지금 화면엔 안 나오는 글, **[꺼짐]**은 기능 스위치가 꺼진 글입니다. **⚠ 영어 고칠 만함**은 영어가 어색하거나 아이에게 길 때 쓴 표시(게임은 안 고침).

순서는 플레이 순서입니다: ① 오프닝·진영·직업 → ② 첫 임무·첫 10분 힌트 → ③ 본편 스토리 → ④ 마을·사이드 퀘스트 → ⑤ 일일·주간 → ⑥ 이벤트 → ⑦ NPC 대사 → ⑧ 짧은 메시지.

## 줄 수

| 구역 | 표 줄 수 |
|---|---|
| ① 오프닝 · 진영 고르기 · 직업 고르기 | 78 |
| ② 첫 임무와 첫 10분 힌트 | 92 |
| ③ 본편 스토리 퀘스트 (18개) | 201 |
| ④ 마을·사이드 퀘스트 | 498 |
| ⑤ 일일·주간·출석 퀘스트 | 54 |
| ⑥ 이벤트 (황금 거위·황금 알·왕관 전쟁·괴수) | 89 |
| ⑦ NPC 대사·상점·몬스터 소리 (대표만) | 33 |
| ⑧ 자주 뜨는 짧은 메시지 (대표만) | 30 |
| 합계 | 1075 |

⑦ ⑧은 대표만 뽑았습니다(뺀 것은 각 구역 첫머리에 적음). ①~⑥은 설정에 있는 글을 거의 다 담았습니다.

## 이름 읽는 법 (자주 나오는 영어)

| 영어 | 한국어 | 설명 |
|---|---|---|
| Halo & Horns | 헤일로 앤 혼즈 (선악 키우기) | 게임 이름. Halo = 후광(천사 쪽), Horns = 뿔(악마 쪽) |
| Knights of Light / Halo | 빛의 기사단 | Halo 진영. 줄여서 Knights |
| Horn Legion / Horns | 뿔 군단 | Horns 진영 |
| Artisan Guild | 장인 길드 | 세 번째 진영(Neutral). 지금은 선택이 꺼져 있음 |
| Crown of Balance / Crown Shard | 균형의 왕관 / 왕관 조각 | 부서진 왕관이 이야기의 중심, 조각을 주우면 후광이나 뿔이 자람 |
| Honor / Mischief | 명예 / 장난 점수 | Halo 점수 / Horns 점수 |
| Hallie / Magpie / Kit | 할리 / 맥파이 / 킷 | 안내자(Guide): Halo / Horns / 길드 |
| Otto / Fizzby | 오토 / 피즈비 | 대장장이(Forge) / 물약 상인(Potion Seller) |
| Bright / Rose / Tiny | 브라이트 / 로즈 / 타이니 | 마을 아이들: 빛의 성채 경비 / 뿔 소굴 / 교차로 길드 꼬마 |
| Sir Gleam / Rascal Rex | 글림 경 / 래스칼 렉스 | 빛의 기사 / 뿔 소굴 장난꾼 |
| Pip / Dibs / Grabbo | 핍 / 딥스 / 그래보 | 고블린 (작은 고블린 / 장사꾼 / Grab Club 대장) |
| Crossroads | 교차로 마을 | 가운데 마을. 분수·대장간·운명의 제단이 있음 |
| Halo Citadel / Horns Den | 빛의 성채 / 뿔 소굴 | 각 진영 마을 |
| Squishy Meadow | 말랑 초원 | 첫 사냥터 (슬라임) |
| Goblin Woods / Skeleton Ruins | 고블린 숲 / 해골 유적 | 다음 사냥터 (Lv10 / Lv25) |
| Slime / Slime Prince / King Slime / Baby Slime | 슬라임 / 슬라임 왕자 / 킹 슬라임 / 아기 슬라임 | 슬라임 가족: 막내 / 첫째 / 아빠 보스 / 펫 |
| Goblin / Goblin Brute / Skeleton | 고블린 / 고블린 우두머리 / 해골 병사 | 몬스터 |
| Forge / Blacksmith | 대장간 / 대장장이 | 무기를 파는 곳 |
| Enhance Scroll / Transfer Scroll | 강화 주문서 / 옮기기 주문서 | 무기를 강화(+) / 강화를 다른 무기로 옮김 |
| Vault / Pouch | 금고 / 주머니 | 마을에 맡긴 골드(안전) / 들고 있는 골드(빼앗길 수 있음) |
| Auto Battle | 자동 전투 | 조각이 대신 몬스터를 때려 줌 |
| Sprout Shield | 새싹 보호 | Lv15 + 1시간 전까지 PvP를 못 당함 |
| Wanted / Bounty / Kaiju | 현상수배 / 현상금 / 괴수 | Horns가 별 5개면 괴수로 변신 |
| Grudge Sack | 원한 자루 | 빼앗긴 골드가 들어가는 자루. 45초 지키면 도둑 것 |
| Golden Goose | 황금 거위 | 10분마다 열리는 줄다리기 이벤트 |
| Altar of Fate | 운명의 제단 | 진영을 바꾸는 곳 (교차로) |
| Rebirth | 환생 | 레벨만 처음으로 돌리고 진영을 다시 고름 (Lv50~) |
| Purify / Devour | 정화 / 삼킴 | 조각을 어떻게 할지 고르는 선택 |

## ① 오프닝 · 진영 고르기 · 직업 고르기

플레이 순서: 처음 접속 → 3D 오프닝(건너뛰기 가능) → **진영 고르기**(Knights of Light / Horn Legion) → **직업 고르기** → 안내자 첫 대화(②로 이어짐). 화면 글자는 전부 영어뿐입니다. `**[숨김]**` = 설정 파일에는 있지만 지금 화면엔 안 나옴, `**[꺼짐]**` = 기능 스위치가 꺼져 있음.

### 1-1 3D 오프닝 자막 (처음 한 번, 메뉴에서 다시 볼 수 있음)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| The Crown of Balance broke. | Crown of Balance(균형의 왕관)가 부서졌다. | 자막 1 — 하늘에 부서진 왕관이 보일 때 · `Intro.luau` TXT.Lines.1 · ⚠ 영어 고칠 만함: 이야기 규칙은 '소문(They say…)'인데 여기만 사실처럼 말함. 다음 진영 화면과 말투가 어긋남 |
| Some who touched the shards grew halos. Others grew horns. | 조각을 만진 사람 중 일부는 후광(halo)이 생기고, 다른 사람들은 뿔(horns)이 자랐다. | 자막 2 — 조각이 빛의 성과 뿔 소굴로 날아갈 때 · TXT.Lines.2 |
| Whoever gathers more shards will remake the world. | 조각을 더 많이 모으는 쪽이 세상을 다시 만들 것이다. | 자막 3 — 내 앞에 조각이 떨어질 때 · TXT.Lines.3 |
| Which side will you join? | 어느 쪽에 들어갈래? | 자막 4 (크고 금색) — 마지막 질문 · TXT.Ask |
| Skip | 건너뛰기 | 오른쪽 아래 건너뛰기 버튼. 키보드면 'Skip ▶ (Enter)'로 보임 · TXT.Skip |
| Replay Opening | 오프닝 다시 보기 | 설정 창의 버튼 — 오프닝을 다시 봄 · `Settings.Window.Intro` |
| You can replay the opening inside a town. | 오프닝은 마을 안에서만 다시 볼 수 있다. | 마을 밖에서 다시 보려 할 때 알림 · `Settings.Window.IntroUnsafe` |
| They say the Crown kept the world in balance. | 소문에 따르면 왕관이 세상의 균형을 지켜 주었다고 한다. | **[숨김]** 옛 오프닝 문구 1 (지금 오프닝은 위의 자막을 씀) · `Story.OpeningRumor.1` |
| They say someone wanted it all to themselves. | 소문에 따르면 누군가가 전부 혼자 갖고 싶어 했다고 한다. | **[숨김]** 옛 오프닝 문구 2 · `Story.OpeningRumor.2` |
| "If I can't have it, no one can!" CRACK. | "내가 못 가지면 아무도 못 가져!" 쩍! (부서지는 소리) | **[숨김]** 옛 오프닝 문구 3 · `Story.OpeningRumor.3` |
| Which side will you choose? | 어느 쪽을 고를래? | **[숨김]** 옛 질문 문구 (지금은 위 자막 4번이 대신함) · `Story.OpeningAsk` |

### 1-2 진영 고르는 화면 (Choose your side!)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| They say someone broke the Crown of Balance. | 누군가 Crown of Balance를 부쉈다는 소문이 있다. | 화면 위쪽 파란 상자 글 1줄 (작은 폰 화면에서는 숨김) · `Story.Premise.1` |
| Some who picked up its shards grew a halo. Others grew horns. | 그 조각을 주운 사람 중 일부는 후광이 생기고, 다른 사람들은 뿔이 자랐다. | 위쪽 글 2줄 · `Story.Premise.2` |
| Now each side says the other did it. | 이제 양쪽 모두 상대가 그랬다고 말한다. | 위쪽 글 3줄 · `Story.Premise.3` |
| Choose your side! | 네 편을 골라! | 화면 큰 제목 · `FactionPicker.luau` T.Title |
| Join this side! | 이 편에 들어가기! | 카드 아래 선택 버튼 · T.Choose |
| One moment... | 잠깐만... | 누른 뒤 서버 답을 기다리는 동안 버튼 글자 · T.Wait |
| Joining the smaller side! Start gold +%d · the Size Scale makes you bigger | 더 작은(사람이 적은) 편에 들어가는 중! 시작 골드 +%d · Size Scale(덩치 저울)이 몸을 더 크게 해 줌 | 사람이 더 적은 쪽을 고를 때만 카드에 뜸 · T.WeakerF · %d = 시작 보너스 골드. ⚠ 영어 고칠 만함: 'Size Scale(덩치 저울)'이 처음 나오는 말이고 문장이 길다 |
| You can switch later at the Altar of Fate in the Crossroads (free or with a ticket) | 나중에 Crossroads(교차로 마을)에 있는 Altar of Fate(운명의 제단)에서 편을 바꿀 수 있다 (무료 또는 변경권으로) | 화면 아래 안내(PC) · T.Footer · ⚠ 영어 고칠 만함: 길다. 폰용 짧은 줄은 아래 |
| Switch sides later at the Altar of Fate. | 나중에 Altar of Fate에서 편을 바꿀 수 있다. | 화면 아래 안내(폰, 작은 화면) · T.FooterShort |
| Knights of Light | 빛의 기사단 | Halo 진영 카드 이름 · `Factions.Halo.Name` |
| Heal friends and catch thieves! | 친구를 치료하고 도둑을 잡자! | Halo 카드 맨 위 큰 한 줄 · `Factions.Halo.Pitch` |
| XP +30% (level up faster) | 경험치 +30% (레벨이 더 빨리 오름) | Halo 카드 장점 1 · `Factions.Halo.Perks.1` |
| HP +20%, keeps healing | HP +20%, 계속 회복됨 | 장점 2 · `Factions.Halo.Perks.2` |
| Your skill heals nearby allies | 내 스킬이 가까운 동료를 치료함 | 장점 3 · `Factions.Halo.Perks.3` |
| Half your pouch gold goes to the vault | 주머니 골드의 절반이 금고로 들어감 | 장점 4 · `Factions.Halo.Perks.4` |
| Catch Grudge Sack thieves to win gold back | Grudge Sack(원한 자루) 도둑을 잡으면 골드를 되찾음 | 장점 5 · `Factions.Halo.Perks.5` |
| Horn Legion | 뿔 군단 | Horns 진영 카드 이름 · `Factions.Horns.Name` |
| Sneaky tricks and grab gold in PvP zones! | 교활한 꾀로 PvP 구역에서 골드를 챙기자! | Horns 카드 맨 위 큰 한 줄 · `Factions.Horns.Pitch` |
| Gold +25% (get rich faster) | 골드 +25% (더 빨리 부자가 됨) | Horns 카드 장점 1 · `Factions.Horns.Perks.1` |
| ATK +15%, your hits steal HP | 공격력 +15%, 때리면 HP를 훔침 | 장점 2 · `Factions.Horns.Perks.2` |
| Keep stolen gold safe and it is yours | 훔친 골드를 안전하게 지키면 내 것이 됨 | 장점 3 · `Factions.Horns.Perks.3` |
| Rob the Knights and guard the Grudge Sack | 빛의 기사들의 골드를 빼앗고 Grudge Sack을 지킴 | 장점 4 · `Factions.Horns.Perks.4` |
| 5 Wanted stars = turn into a Kaiju! | Wanted(현상수배) 별 5개 = Kaiju(괴수)로 변신! | 장점 5 (★ 다섯 개면 Kaiju가 됨) · `Factions.Horns.Perks.5` |
| Artisan Guild | 장인 길드 | 잠긴 세 번째 카드 이름 · T.SoonName |
| Coming soon | 곧 나와요 | 잠긴 카드 글자 · T.Soon |
| Crafting update | 제작 업데이트 | 잠긴 카드 작은 글 · T.SoonSub |
| Don't grab it. Shape it and craft it! | 빼앗지 말고, 빚고 만들어요! | **[꺼짐]** Artisan Guild 카드 맨 위 줄 (길드 선택이 켜지면 보임) · `Factions.Neutral.Pitch` |
| No fight buffs (no XP, gold, HP or ATK bonus) | 전투 보너스 없음 (경험치·골드·HP·공격력 보너스 없음) | **[꺼짐]** 길드 장점 1 · `Factions.Neutral.Perks.1` |
| No PvP: you never attack or get attacked | PvP 없음: 때리지도, 맞지도 않음 | **[꺼짐]** 길드 장점 2 · `Factions.Neutral.Perks.2` |
| No worries about loot, Wanted or Grudge Sacks | 전리품·Wanted·Grudge Sack 걱정 없음 | **[꺼짐]** 길드 장점 3 · `Factions.Neutral.Perks.3` |
| The Crossroads is your home | Crossroads가 내 고향 | **[꺼짐]** 길드 장점 4 · `Factions.Neutral.Perks.4` |
| Crafting expert (coming soon) | 제작 전문가 (곧 나옴) | **[꺼짐]** 길드 장점 5 · `Factions.Neutral.Perks.5` |
| No fight buffs · No PvP · Crafting (coming soon) | 전투 보너스 없음 · PvP 없음 · 제작 (곧 나옴) | **[꺼짐]** 길드 카드 작은 메모 · `Factions.Neutral.Note` |
| Their Crown Shards became halos. They guard the shards and fix the world. | 그들의 Crown Shard(왕관 조각)는 후광이 되었다. 조각을 지키며 세상을 고친다. | 진영 설명 (제단·정보 창에 나옴) · `Story.FactionLore.Halo` |
| Their Crown Shards became horns. They take the shards and rule the world. | 그들의 Crown Shard는 뿔이 되었다. 조각을 빼앗아 세상을 다스린다. | 진영 설명 · `Story.FactionLore.Horns` |
| Those who shape the shards instead of grabbing them. | 조각을 빼앗는 대신 빚어서 만드는 사람들. | 진영 설명 · `Story.FactionLore.Neutral` |
| Halos and horns are the power of the Crown Shards. They grow as your rank goes up. | 후광과 뿔은 Crown Shard의 힘이다. 계급이 오를수록 커진다. | Hero(내 캐릭터) 창에서 후광/뿔 표시 설명 · `Story.MarkLore` |

### 1-3 직업 고르는 화면 (Pick a class!)

진영을 고른 직후 열립니다. 직업 이름은 진영마다 다르게 보입니다 (Halo · Horns · Artisan 순서).

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Pick a class! | 직업을 골라! | 화면 큰 제목 · `ClassPicker.luau` T.Title |
| Pick this class! | 이 직업으로! | 카드 버튼 · T.Choose |
| Pick! | 선택! | 좁은 카드의 짧은 버튼 · T.ChooseShort |
| Paladin · Berserker · Blacksmith | 성기사(Paladin) · 광전사(Berserker) · 대장장이(Blacksmith) | Warrior(전사) 카드 이름: Halo = Paladin, Horns = Berserker, 길드 = Blacksmith · `Classes.Warrior.Names` |
| Light Mage · Dark Mage · Alchemist | 빛의 마법사(Light Mage) · 어둠의 마법사(Dark Mage) · 연금술사(Alchemist) | Mage(마법사) 카드 이름: Halo = Light Mage, Horns = Dark Mage, 길드 = Alchemist · `Classes.Mage.Names` |
| Ranger · Shadow Hunter · Pet Tamer | 레인저(Ranger) · 그림자 사냥꾼(Shadow Hunter) · 펫 조련사(Pet Tamer) | Archer(궁수) 카드 이름: Halo = Ranger, Horns = Shadow Hunter, 길드 = Pet Tamer · `Classes.Archer.Names` |
| Hits every enemy in front of you at once. Very tough! | 앞에 있는 적을 한꺼번에 때린다. 아주 튼튼하다! | 전사 카드 설명 · `Classes.Warrior.Desc` |
| Get close and smash everything in front | 가까이 가서 앞의 모두를 부수기 | 전사 짧은 줄(설명이 안 들어갈 때) · `Classes.Warrior.PickLine` |
| Smash all around! | 주변을 다 부숴요! | 전사 카드 한 줄(폰 카드) · T.Tag.Warrior |
| Hits all in front | 앞에 있는 적을 모두 때림 | 전사 능력 줄 (HP ×1.3 / ATK ×1.0 / 이 줄) · `Classes.Warrior.Stats.3` |
| Magic orbs for far enemies! Boom, it hits the area too! | 먼 적에게 마법 구슬! 쾅, 주변까지 맞아요! | 마법사 카드 설명 · `Classes.Mage.Desc` |
| Stay back and blast a wide area | 뒤에서 넓은 범위를 쏘기 | 마법사 짧은 줄 · `Classes.Mage.PickLine` |
| Blast from afar! | 멀리서 펑! | 마법사 카드 한 줄(폰 카드) · T.Tag.Mage |
| 35-stud range + blast | 사거리 35스터드 + 폭발 | 마법사 능력 줄 · `Classes.Mage.Stats.3` · stud = 게임 속 길이 단위 |
| Shoots two foes at a time, fast. Quick feet! | 한 번에 두 마리를 빠르게 쏜다. 발이 빠르다! | 궁수 카드 설명 · `Classes.Archer.Desc` |
| Shoot foes one by one from afar | 멀리서 한 마리씩 쏘기 | 궁수 짧은 줄 · `Classes.Archer.PickLine` |
| Two arrows, fast! | 화살 두 발, 빠르게! | 궁수 카드 한 줄(폰 카드) · T.Tag.Archer |
| Hits 2 at 30 studs · Move +10% | 30스터드 거리의 2마리를 맞힘 · 이동 속도 +10% | 궁수 능력 줄 · `Classes.Archer.Stats.3` |
| ATK ×0.55 (2x fast) | 공격력 ×0.55 (2배 빠름) | 궁수 능력 줄 2 · `Classes.Archer.Stats.2` · ATK = 공격력 |
| Your Baby Slime pet fights for you! It headbutts enemies from afar. | Baby Slime(아기 슬라임) 펫이 대신 싸워요! 멀리서 적에게 박치기해요. | **[꺼짐]** Pet Tamer(길드 궁수) 카드 설명 · `Tamer.Card.Desc` |
| Your pet bonks foes one by one | 펫이 적을 한 마리씩 콩 때려요 | **[꺼짐]** Pet Tamer 짧은 줄 · `Tamer.Card.PickLine` |
| Best for beginners | 초보자에게 딱 좋음 | 전사 카드에 붙는 표시 · `Text.FirstTimeRecommend` |
| Outfit coming later | 옷은 나중에 나와요 | 카드 그림 아래 작은 글 (캐릭터 옷은 나중에) · T.Outfit |
| First weapon: %s (from the Blacksmith) | 첫 무기: %s (대장장이에게서) | 카드에 첫 무기 이름 안내 · T.StartWeaponF · %s = 무기 이름 |
| Change class later: Menu > Change Class | 직업은 나중에 바꿀 수 있어요: Menu > Change Class | 화면 아래 안내(작은 화면) · T.FooterShort |
| Change class later in Menu. Free: level kept below Lv%d. Ticket: level always kept. | 직업은 나중에 Menu에서 바꿀 수 있어요. 무료: Lv%d 아래면 레벨이 그대로. 변경권: 항상 레벨 그대로. | 화면 아래 안내(PC) · `Text.ClassChangeRuleF` · %d = 레벨. ⚠ 영어 고칠 만함: 규칙 문장이 아이에게 어렵고 길다 |

### 1-4 진영을 고른 직후

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| You joined the %s! | %s에 들어왔어요! | 진영을 처음 고른 뒤 3초 알림 · `ChatText.Joined` · %s = 진영 이름(예: Horn Legion) |
| Pick a side to start! | 시작하려면 편을 고르세요! | **[숨김]** 채팅 팀 이름이 '고르는 중'일 때 (지금은 채팅에 팀 줄을 안 보냄) · `ChatText.Choosing` |
| Smaller side bonus: +%d gold! | 작은 편 보너스: 골드 +%d! | 사람이 적은 쪽을 처음 고르면 받는 보너스 알림 · `Text.UnderdogSignOn` · %d = 골드 |
| Pick a side first. | 먼저 편을 고르세요. | 진영 없이 뭘 하려 할 때 · `Text.NeedFaction` |

## ② 첫 임무와 첫 10분 힌트

직업을 고르면 **안내자(Guide)** 가 첫 임무를 줍니다. 순서: 안내자 대화 → [I'm In!] → 대장간(Forge)에서 첫 무기 받기 → 말랑 초원으로 이동 → 슬라임 5마리 → [Claim]으로 150골드. 그 사이 처음 10분에 만나는 **작은 사이드 퀘스트**(Lost Lunchbox, 조각의 시험, 아기 슬라임, 킹의 점프)는 ④-1에 있습니다.

### 2-1 안내자 첫 대화 (직업 고른 직후, 퀘스트 줄을 누르면 열림)

안내자 이름은 진영마다 다릅니다: Halo = **Hallie**(여, 'Guide of Light'), Horns = **Magpie**(남, 'Horn Legion Guide'), 길드 = **Kit**(여, 'Guild Guide', 길드 선택이 꺼져 있어 지금은 안 나옴).

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Guide of Light | 빛의 안내자 | Hallie의 이름표 둘째 줄 · `Tutorial.Welcome.Halo.Title` |
| Horn Legion Guide | 뿔 군단 안내자 | Magpie의 이름표 둘째 줄 · `Tutorial.Welcome.Horns.Title` |
| Guild Guide | 길드 안내자 | **[꺼짐]** Kit의 이름표 둘째 줄 · `Tutorial.Welcome.Neutral.Title` |
| Guide · Take Back the Supply Road | 안내자 · 보급로를 되찾자 | 대화 창 제목 · `Panels.luau` T.Titles.Welcome |
| First, get a weapon from Otto the Blacksmith!<br>Then beat 5 slimes to free the supply road. | 먼저 대장장이 Otto(오토)에게서 무기를 받으세요!<br>그다음 슬라임 5마리를 잡아 보급로를 풀어 주세요. | 대화 1쪽 — 세 진영이 똑같음 (첫 임무 카드) · `Tutorial.Welcome.*.Lines.1` |
| Hallie here! Now you know my name. Welcome to the Knights! | 나 Hallie(할리)예요! 이제 내 이름을 알았죠. 빛의 기사단에 온 걸 환영해요! | Halo 대화 2쪽 (안내자의 말버릇) · `Tutorial.Welcome.Halo.Lines.2` |
| Finders keepers! HA! You're with us now. I'm Magpie. | 줍는 놈이 임자야! 하하! 이제 우리 편이다. 나는 Magpie(맥파이). | Horns 대화 2쪽 · `Tutorial.Welcome.Horns.Lines.2` |
| Fix first. Talk later. I'm Kit. Welcome to the Guild! | 먼저 고치고, 이야기는 나중에. 나는 Kit(킷). 길드에 온 걸 환영해! | **[꺼짐]** 길드 대화 2쪽 · `Tutorial.Welcome.Neutral.Lines.2` |
| I'm In! | 함께할게요! | 큰 수락 버튼 — 누르면 첫 임무 시작 · T.WelcomeAccept |
| Checking... | 확인하는 중... | 수락 버튼을 누르고 서버 답을 기다리는 동안 · T.WelcomePending |
| We couldn't confirm that. Please tap again. | 확인하지 못했어요. 다시 눌러 주세요. | 5초 넘게 답이 없을 때 · T.WelcomeRetry |
| Pick a class first, then talk to the Guide again. | 먼저 직업을 고른 다음 안내자와 다시 이야기하세요. | 직업을 아직 안 골랐을 때 · T.WelcomeUnavailable |
| Tap here: first quest from %s | 여기를 눌러요: %s에게서 첫 퀘스트 | 수락 전 화면 왼쪽 퀘스트 줄 · `Tutorial.Text.Welcome` · %s = 안내자 이름 |
| Meet %s | %s 만나기 | 같은 줄의 폰용 짧은 이름 · %s = 안내자 이름 · `Tutorial.ShortNames.Welcome` |
| Meet the Guide | 안내자 만나기 | 메뉴에서 안내자를 다시 만나는 버튼 · T.MenuWelcome |
| Pick a class, then get your first mission from the Guide. | 직업을 고르고, 안내자에게서 첫 임무를 받으세요. | **[숨김]** 옛 안내 한 줄 (쓰는 곳을 코드에서 못 찾음) · `Tutorial.Text.FirstFight` |

### 2-2 첫 임무 진행 (순서대로)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Go to Otto's Forge in the Crossroads | Crossroads에 있는 Otto의 Forge(대장간)로 가기 | [1단계] 화면 왼쪽 퀘스트 줄 — 대장간으로 가라 · `Tutorial.Text.Forge` |
| To the Forge | Forge로 | [1단계] 폰용 짧은 줄 · `Tutorial.ShortNames.Forge` |
| First weapon | 첫 무기 | **[꺼짐]** [1단계] 대장간 위에 뜨는 이름표 (GuideLabel 꺼짐) · HUD TXT.ForgeGuide |
| See weapons | 무기 보기 | [1단계] 모루 앞에서 뜨는 버튼 글자 (행동) · `Text.BlacksmithPromptAction` |
| Forge | 대장간 | [1단계] 같은 버튼의 물건 이름 · `Text.BlacksmithPromptObject` |
| Otto: Clang, clang… done. Here's your first weapon! The Squishy Meadow is next. | Otto: 땅땅, 다 됐다… 자, 첫 무기야! 다음은 Squishy Meadow(말랑 초원)야. | [1단계] 첫 무기를 받을 때 Otto의 대사 알림 · `Tutorial.Text.ForgeGift` |
| First weapon: [%s]! | 첫 무기: [%s]! | [1단계] 첫 무기 알림 · `Loot.Text.FirstWeapon` · %s = 무기 이름 |
| [%s] equipped! Power %s → %s | [%s] 장착! 전투력 %s → %s | [1단계] 맨손에서 무기를 끼는 알림 · `Loot.Text.BareEquip` · 앞의 %s = 무기 이름, 뒤 두 %s = 전투력 전 → 후 |
| Stronger! | 더 강해졌어요! | [1단계] 첫 무기 뒤 화면 가운데 큰 글자 · HUD TXT.Stronger |
| Twig · Dry Staff · Slingshot Bow | 나뭇가지(Twig) · 마른 지팡이(Dry Staff) · 새총 활(Slingshot Bow) | 첫 무기 이름: 전사 = Twig, 마법사 = Dry Staff, 궁수 = Slingshot Bow · `WeaponNames.*.1` |
| Your first weapon, a gift from the Blacksmith | 첫 무기, 대장장이의 선물 | 무기 설명 줄 (첫 무기) · `WeaponInfo.1.SourceEn` |
| Travel to Squishy Meadow — step on the glowing travel pad (or Map → Travel) | Squishy Meadow로 가기 — 빛나는 이동 판을 밟으세요 (또는 Map → Travel) | [2단계] 말랑 초원으로 가라 (빛나는 이동 판을 밟음) · `Tutorial.Text.Travel` · ⚠ 영어 고칠 만함: 길다. 줄표(—)와 괄호가 많음 |
| To the meadow | 초원으로 | [2단계] 폰용 짧은 줄 · `Tutorial.ShortNames.Travel` |
| Off to %s! | %s(으)로 출발! | **[숨김]** 옛 자동 이동 화면 글자 (서버가 더는 안 보냄, A23-88) · FirstSteps TXT.Travel · %s = 장소 |
| Traveling... | 이동하는 중... | 이동 판·메뉴로 이동할 때 · `Text.Traveling` |
| Free the supply road · %d slimes | 보급로를 풀어 주자 · 슬라임 %d마리 | [3단계] 슬라임 5마리 — 화면 왼쪽 퀘스트 줄 · `Tutorial.QuestText` · %d = 5 |
| Supply road | 보급로 | [3단계] 폰용 짧은 줄 · `Tutorial.ShortNames.Quest` |
| Done! | 완료! | [4단계] 5/5가 되면 줄 끝에 붙는 말 · HUD TXT.QuestDone |
| Claim | 받기 | [4단계] 받기 버튼 · HUD TXT.Claim |
| +%s gold | +%s 골드 | [4단계] [Claim]을 누르면 뜨는 보상 알림 (첫 임무 = 150골드) · `Tutorial.Text.Claimed` · %s = 골드 |
| Get your first weapon · Crossroads Forge | 첫 무기 받기 · Crossroads Forge | [4단계 뒤] 아직 맨손이면 나오는 줄 · `Tutorial.Text.VisitBlacksmith` |
| Check the weapons · Crossroads Forge | 무기 살펴보기 · Crossroads Forge | [4단계 뒤] 첫 무기가 있는 저장 파일에 나오는 줄 · `Tutorial.Text.VisitBlacksmithArmed` |
| You got a scroll! Enhance your weapon from your Bag. (Your weapon is safe even if it fails) | 주문서를 얻었어요! 가방(Bag)에서 무기를 강화하세요. (실패해도 무기는 안전해요) | 슬라임이 처음 주문서를 떨어뜨릴 때 · `Loot.Text.FirstScroll` |
| You got a scroll! The Blacksmith gives you your first weapon. Then enhance it from your Bag. | 주문서를 얻었어요! 대장장이가 첫 무기를 줄 거예요. 그다음 가방에서 강화하세요. | 첫 주문서인데 아직 맨손일 때 · `Loot.Text.FirstScrollBare` |

### 2-3 처음 10분에 만나는 알림·힌트

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Level up! Lv %d | 레벨 업! Lv %d | 레벨이 오를 때 화면 가운데 · `Text.LevelUp` · %d = 숫자 |
| New skill! %s (%s) | 새 스킬! %s (%s) | Lv5에 첫 스킬을 배울 때 알림 · `Skills.Text.NewSkill` · 앞 %s = 스킬 이름, 뒤 %s = 키 |
| New skill! %s | 새 스킬! %s | 스킬 버튼 쪽 큰 글자 (3초) · SkillBar TXT.NewSkill · %s = 이름이나 숫자가 들어감 |
| Press %s | %s 키를 누르세요 | 새 스킬을 45초 안에 안 쓰면 나오는 힌트 (쓰면 안 나옴) · SkillBar TXT.LearnKey · %s = 키 이름 |
| New skill! Tap the new button. | 새 스킬! 새 버튼을 누르세요. | 폰: 새 스킬 버튼을 눌러 보라고 함 · `Skills.Text.NewSkillTouch` |
| Skills come at Lv %d | 스킬은 Lv%d에 나와요 | 스킬 키를 너무 일찍 눌렀을 때 · SkillBar TXT.Later · %d = 숫자 |
| Tip: You can change your keys in Settings! | 팁: 키는 Settings(설정)에서 바꿀 수 있어요! | **[꺼짐]** 첫 스킬 뒤 키 바꾸기 힌트 (KeysTip 꺼짐) · SkillBar TXT.KeysTip |
| Not enough MP | MP가 모자라요 | MP(마나)가 모자랄 때 · `Skills.Text.NoMP` |
| Costs %d MP | MP %d 필요 | 스킬 설명 · `Skills.Text.Cost` · %d = MP |
| %s s cooldown | 쿨타임 %s초 | 스킬 설명 · `Skills.Text.Cooldown` · %s = 초 |
| No target | 대상이 없어요 | 때릴 몬스터가 없을 때 · `Skills.Text.NoTarget` |
| Ready | 준비됨 | 스킬을 다시 쓸 수 있을 때 · `Skills.Text.Ready` |
| Slam your sword down. A gold ring hits and heals you and friends. | 검을 내려쳐요. 금빛 고리가 적을 때리고 나와 친구를 치료해요. | 전사 Halo 쪽 첫 스킬 'Halo Slam'(후광 내려치기) 설명 · `Skills.Defs.Warrior.Q.Halo.DescEn` |
| Smash the ground hard! Hit monsters around you and steal HP. | 땅을 힘껏 부숴요! 주변 몬스터를 때리고 HP를 훔쳐요. | 전사 Horns 쪽 첫 스킬 'Crater Smash'(구덩이 박살) 설명 · `Skills.Defs.Warrior.Q.Horns.DescEn` |
| A big star falls on the closest monster. Heals you and friends. | 큰 별이 가장 가까운 몬스터에게 떨어져요. 나와 친구를 치료해요. | 마법사 Halo 쪽 첫 스킬 'Star Fall'(별 떨어짐) 설명 · `Skills.Defs.Mage.Q.Halo.DescEn` |
| Purple bubbles pop up under the closest monster. Steal HP. | 보라색 방울이 가장 가까운 몬스터 밑에서 터져요. HP를 훔쳐요. | 마법사 Horns 쪽 첫 스킬 'Purple Pop'(보라 방울 펑) 설명 · `Skills.Defs.Mage.Q.Horns.DescEn` |
| Gold arrows rain on the closest group. Heals you and friends. | 금빛 화살이 가장 가까운 무리에게 비처럼 쏟아져요. 나와 친구를 치료해요. | 궁수 Halo 쪽 첫 스킬 'Feather Rain'(깃털 비) 설명 · `Skills.Defs.Archer.Q.Halo.DescEn` |
| Shoot twice! Dark arrows rain on the closest group. Steal HP. | 두 번 쏴요! 어두운 화살이 가장 가까운 무리에게 쏟아져요. HP를 훔쳐요. | 궁수 Horns 쪽 첫 스킬 'Spark Shower'(불꽃 소나기) 설명 · `Skills.Defs.Archer.Q.Horns.DescEn` |
| Bonk the ground with your hammer. | 망치로 땅을 쿵 쳐요. | **[꺼짐]** 길드 전사(Blacksmith) 첫 스킬 'Hammer Quake'(망치 지진) · `Skills.Defs.Blacksmith.Q.DescEn` |
| Throw a fizzy potion at the closest monster. | 가장 가까운 몬스터에게 톡톡 튀는 물약을 던져요. | **[꺼짐]** 길드 마법사(Alchemist) 첫 스킬 'Potion Bomb'(물약 폭탄) · `Skills.Defs.Alchemist.Q.DescEn` |
| Your slime jumps in and bonks the group. | 내 슬라임이 뛰어들어 무리를 때려요. | **[꺼짐]** Pet Tamer 첫 스킬 'Pet Rush'(펫 돌격) · `Skills.Defs.Tamer.Q.DescEn` |
| Hunt slimes and big slimes for XP. | 슬라임과 큰 슬라임을 잡아 경험치를 얻으세요. | **[꺼짐]** 말랑 초원 처음 도착할 때 알림 (HuntSlimes 꺼짐) · HUD TXT.HuntSlimes |
| Click to hit! | 클릭해서 때려요! | **[꺼짐]** 첫 임무 중 공격 버튼 위 말풍선, PC (AttackHint 꺼짐) · HUD TXT.HintClick |
| Tap to hit! | 터치해서 때려요! | **[꺼짐]** 같은 말풍선, 폰 · HUD TXT.HintTap |
| PvP zone | PvP 구역 | 처음 PvP 구역에 들어갈 때 카드 제목 · FirstSteps PVP.Title |
| Other players can fight you here!<br>Knocked out? You can lose pocket gold. Towns keep it safe. | 여기서는 다른 플레이어가 나를 공격할 수 있어요!<br>쓰러지면 주머니 골드를 잃을 수 있어요. 마을에 두면 안전해요. | 그 카드 글 (한 번만) · FirstSteps PVP.Text |
| PvP zone! | PvP 구역! | PvP 구역에 들어갈 때 알림 (처음 한 번은 위 카드가 대신함) · `Text.EnteredPvP` |
| Safe zone. | 안전 구역. | **[꺼짐]** 안전 구역에 들어갈 때 알림 (EnteredSafe 꺼짐) · `Text.EnteredSafe` |
| You need Lv %d or higher to enter! | 들어가려면 Lv %d 이상이어야 해요! | 레벨이 모자란 구역에 들어가려 할 때 · `Text.NeedLevel` · %d = 필요한 레벨 |
| You can't enter the other side's town! | 다른 편의 마을에는 들어갈 수 없어요! | 상대 진영 마을에 들어가려 할 때 · `Text.EnemyTown` |
| Hold the right mouse button and drag to turn the camera. | 오른쪽 마우스 버튼을 누른 채 끌면 카메라가 돌아요. | 도움말 창 — 카메라 돌리기 (PC) · `Help.CameraLine` |
| Tap the buttons on the screen to attack, use skills and drink potions. | 화면의 버튼을 눌러 공격하고, 스킬을 쓰고, 물약을 마셔요. | 도움말 창 — 폰 조작 · `Help.TouchLines.1` |
| Drag with one finger to turn the camera. | 손가락 하나로 끌면 카메라가 돌아요. | 도움말 창 — 폰 카메라 · `Help.TouchLines.2` |
| One press = one attack. Holding it down won't repeat it. | 한 번 누르면 한 번 공격해요. 누르고 있어도 반복되지 않아요. | 도움말 창 'Combat & Auto Battle' 1 · `Help.Topics.3.Lines.1` |
| Your first skill comes at Lv 5. It costs 20 MP; wait 3 s to use it again. | 첫 스킬은 Lv 5에 나와요. MP 20이 들고, 다시 쓰려면 3초 기다려요. | 도움말 창 'Combat & Auto Battle' 2 · `Help.Topics.3.Lines.2` |
| Finish the Crown Shard side quest to unlock Auto Battle. It only hits monsters. | Crown Shard 사이드 퀘스트를 끝내면 Auto Battle(자동 전투)이 열려요. 몬스터만 때려요. | 도움말 창 'Combat & Auto Battle' 3 · `Help.Topics.3.Lines.3` |
| No input for 20 minutes? Roblox will disconnect you. | 20분 동안 아무것도 안 하면 Roblox가 연결을 끊어요. | 도움말 창 'Combat & Auto Battle' 4 · `Help.Topics.3.Lines.4` |

### 2-4 첫 임무 뒤 '다음 목표' 줄 (본편 퀘스트가 없을 때 왼쪽 위에 계속 뜸)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Next goal · Iron weapon at Lv%d (now Lv%d) | 다음 목표 · Lv%d에 철 무기 (지금 Lv%d) | 다음 목표 줄 — 철 무기를 사려면 레벨이 필요 · `Tutorial.Text.NextIronLevel` · 앞 %d = 필요 레벨, 뒤 %d = 지금 레벨 |
| Next goal · Lv%d: first skill + Iron weapon (now Lv%d) | 다음 목표 · Lv%d: 첫 스킬 + 철 무기 (지금 Lv%d) | 다음 목표 — 첫 스킬 + 철 무기 · `Tutorial.Text.NextSkillIron` · 앞 %d = 필요 레벨, 뒤 %d = 지금 레벨 |
| Next goal · Iron weapon for %s gold (you have %s) | 다음 목표 · 철 무기 값 %s 골드 (내 골드 %s) | 다음 목표 — 철 무기 값 · `Tutorial.Text.NextIronGold` · 앞 %s = 값, 뒤 %s = 내 골드 |
| Next goal · Lv%d opens %s (now Lv%d) | 다음 목표 · Lv%d에 %s 열림 (지금 Lv%d) | 다음 목표 — 다음 사냥터가 열리는 레벨 · `Tutorial.Text.NextZone` · 레벨, 사냥터 이름, 지금 레벨 순서 · %d = 숫자 · %s = 이름이나 숫자가 들어감 |
| Next goal · New skill at Lv%d (now Lv%d) | 다음 목표 · Lv%d에 새 스킬 (지금 Lv%d) | 다음 목표 — 새 스킬 · `Tutorial.Text.NextSkill` · %d = 숫자 |
| Next goal · Lv%d: Rebirth, choose your side again (now Lv%d) | 다음 목표 · Lv%d: Rebirth(환생), 편을 다시 고르기 (지금 Lv%d) | 다음 목표 — 환생 · `Tutorial.Text.NextRebirth` · ⚠ 영어 고칠 만함: 'choose your side again'이 처음엔 무슨 말인지 어려움 · %d = 숫자 |
| Next goal · Rebirth is open! Choose your side again | 다음 목표 · Rebirth가 열렸어요! 편을 다시 고르세요 | 다음 목표 — 환생이 열림 · `Tutorial.Text.NextRebirthReady` |
| Stay a knight, or not? | 기사로 남을까, 아닐까? | 환생 목표 아래 작은 줄 (Halo) · `Tutorial.Text.RebirthNoteHalo` |
| Stay a rascal, or not? | 말썽꾸러기로 남을까, 아닐까? | 환생 목표 아래 작은 줄 (Horns) · `Tutorial.Text.RebirthNoteHorns` |
| That's all from me! Now hunt and get stronger. | 내가 알려 줄 건 여기까지야! 이제 사냥하며 강해져 봐. | **[꺼짐]** 다음 목표가 끝났을 때 한 줄 (GuideDone 꺼짐) · `Tutorial.Text.GuideDone` |
| Daily quests are open! Try them along with your first mission. | 일일 퀘스트가 열렸어요! 첫 임무와 함께 해 보세요. | **[꺼짐]** 첫 [Claim] 뒤 일일 퀘스트 열림 알림 (DailiesOpened 꺼짐) · `Tutorial.Text.DailiesOpened` |
| Lv 2 | Lv 2 | **[숨김]** 메뉴 칸이 잠겨 있을 때 칸 아래 글(코드에서 쓰는 곳을 못 찾음) — Hero 칸 · `HudReveal.TileWords.Character` |
| Lv %d | Lv %d | **[숨김]** 잠긴 Skills 칸 · `HudReveal.TileWords.Skills` · %d = 레벨 |
| Get pet | 펫 얻기 | **[숨김]** 잠긴 Pet 칸 · `HudReveal.TileWords.Pet` |
| Story 1 | 이야기 1 | **[숨김]** 잠긴 Ranking 칸 · `HudReveal.TileWords.Ranking` |

## ③ 본편 스토리 퀘스트 (부서진 왕관 이야기)

첫 임무를 [Claim]하면 본편이 1장 → 2장 → 3장 순서로 이어집니다 (총 18개). 4장은 아직 없습니다. 한 번에 본편 줄은 하나만 보입니다. 대화창이 뜨는 단계는 **[Next] → … → [Got it] / 선택 버튼 두 개**로 읽습니다. 선택 버튼은 **왼쪽 = 착한 쪽(날개 그림), 오른쪽 = 장난·악 쪽(뿔 그림)** 입니다. 길드(Neutral)는 A/B 글자가 따로 있습니다.

**글이 바로 안 보이는 칸 안내**: 퀘스트마다 `Start`(시작 알림), `Finish`(마무리 대사), `Clue`(단서), 목표별 `Start`는 설정 파일에 있지만 **A23-130 결정으로 서버가 보내지 않아 지금 화면엔 안 나옵니다** (`**[숨김]**`로 표시). 화면에는 목표 글, 대화창 글, 선택 버튼 글, 완료 알림만 나옵니다.

### 3-0 퀘스트 공통 문구 (대화창 버튼, 완료·보상 알림)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Next | 다음 | 대화창 [다음] 버튼 · `StoryQuests.Text.Next` |
| Got it | 알겠어 | 대화창 마지막 쪽 확인 버튼 · `StoryQuests.Text.Ok` |
| Later | 나중에 | 대화창 [나중에] 버튼 · `StoryQuests.Text.Later` |
| %s done! Press [Claim]. | %s 완료! [Claim]을 누르세요. | [Claim]을 눌러야 끝나는 퀘스트가 목표를 다 채웠을 때 줄 글 · `StoryQuests.Text.Claim` · %s = 퀘스트 이름 |
| %s done! | %s 완료! | 보상 없이 끝났을 때 알림 · `StoryQuests.Text.Done` · %s = 퀘스트 이름 |
| %s done! +%s gold | %s 완료! +%s 골드 | 골드 보상 알림 · `StoryQuests.Text.Reward` · 앞 %s = 퀘스트 이름, 뒤 %s = 골드 |
| %s done! +%s gold · +%s XP | %s 완료! +%s 골드 · +%s XP | 골드+경험치 보상 알림 · `StoryQuests.Text.RewardXP` · 이름, 골드, XP 순서 · %s = 이름이나 숫자가 들어감 |
| %s done! +%s XP | %s 완료! +%s XP | 경험치만 받을 때 알림 · `StoryQuests.Text.RewardOnlyXP` · %s = 이름이나 숫자가 들어감 |
| +%s gold | +%s 골드 | 선택으로 받은 골드 한 줄 · `StoryQuests.Text.ChoiceGold` · %s = 이름이나 숫자가 들어감 |
| Left: Honor +%d · Right: Honor -%d | 왼쪽: Honor(명예) +%d · 오른쪽: Honor -%d | Halo가 선택 버튼 아래에서 보는 글 — 왼쪽은 +, 오른쪽은 − · `StoryQuests.Text.ChoiceHintHalo` · 두 %d = 점수 |
| Left: Mischief -%d · Right: Mischief +%d | 왼쪽: Mischief(장난 점수) -%d · 오른쪽: Mischief +%d | Horns가 보는 글 — 왼쪽은 −, 오른쪽은 + · `StoryQuests.Text.ChoiceHintHorns` · 두 %d = 점수 |
| No good or evil points. | 착한 점수도 나쁜 점수도 없어요. | 길드가 보는 글 · `StoryQuests.Text.ChoiceHintNeutral` |
| Left: angel side · Right: devil side | 왼쪽: 천사 쪽 · 오른쪽: 악마 쪽 | (진영을 모를 때 쓰는 기본 글) · `StoryQuests.Text.ChoiceHint` |
| Honor +%d | Honor +%d | 선택 뒤 점수 알림 — Halo가 착한 쪽 고름 · `StoryQuests.Text.Good` · %d = 점수 |
| Mischief +%d | Mischief +%d | 선택 뒤 점수 알림 — Horns가 장난 쪽 고름 · `StoryQuests.Text.Evil` · %d = 점수 |
| Honor -%d | Honor -%d | Halo가 반대쪽을 골라 명예가 깎일 때 · `StoryQuests.Text.OffSideHalo` · %d = 깎인 점수 |
| Mischief -%d | Mischief -%d | Horns가 반대쪽을 골라 장난 점수가 깎일 때 · `StoryQuests.Text.OffSideHorns` · %d = 숫자 |
| Hallie: Hmm… not very angel-like! | Hallie: 흠… 별로 천사답지 않은데! | Halo가 반대쪽을 골랐는데 깎을 점수가 0일 때 안내자 대사 · `StoryQuests.Text.OffSideHaloZero` (Hallie) |
| Magpie: Too nice for a devil! | Magpie: 악마치고는 너무 착해! | Horns가 반대쪽을 골랐는데 깎을 점수가 0일 때 안내자 대사 · `StoryQuests.Text.OffSideHornsZero` (Magpie) |
| Rank down! | 계급이 내려갔어요! | 점수가 깎여 계급이 내려갈 때 (Halo) · `StoryQuests.Text.RankDownHalo` |
| Honor +%d | Honor +%d | 처음 거위를 칠 때 점수 알림(Halo) · `StoryQuests.Text.GooseFirstHalo` · %d = 점수 |
| Mischief +%d | Mischief +%d | 처음 거위를 칠 때 점수 알림(Horns) · `StoryQuests.Text.GooseFirstHorns` · %d = 숫자 |
| Your shard leaned to the light. | 조각이 빛 쪽으로 기울었다. | 점수 0점짜리 선택 뒤: 착한 쪽 · `StoryQuests.Text.LeanGood` |
| Your shard leaned to the dark. | 조각이 어둠 쪽으로 기울었다. | 점수 0점짜리 선택 뒤: 장난 쪽 · `StoryQuests.Text.LeanEvil` |
| Your choice is saved. | 선택이 저장됐어요. | 선택을 저장했다는 알림 · `StoryQuests.Text.Recorded` |
| You kept it last time. Now you give. People change. Shards too. | 지난번엔 네가 가졌어. 이번엔 나눠 주네. 사람은 변해. 조각도 그래. | 지난번엔 장난, 이번엔 착한 쪽을 고르면 대사 한 줄이 덧붙음 · `StoryQuests.Text.ChangedGood` |
| You gave it last time. Now you keep. Shards change too. | 지난번엔 나눠 줬어. 이번엔 네가 가져. 조각도 변해. | 지난번엔 착한, 이번엔 장난 쪽을 고르면 덧붙는 대사 · `StoryQuests.Text.ChangedEvil` |
| New title: %s! | 새 칭호: %s! | 새 칭호를 받았을 때 · `StoryQuests.Text.NewTitle` · %s = 칭호 이름 |
| Auto Battle unlocked! | Auto Battle이 열렸어요! | S0를 끝내 자동 전투가 열릴 때 · `StoryQuests.Text.Unlocked` |
| %s · Skills come at Lv%d | %s · 스킬은 Lv%d에 나와요 | 첫 스킬을 배우기 전에 스킬 목표 줄에 붙는 말 · `StoryQuests.Text.SkillLater` · 앞 %s = 목표 글, %d = 레벨 |
| Terms of Fate | 운명의 약관 | 이스터에그 말하는 이름: 두루마리 · `StoryQuests.Speakers.Scroll` |
| Notice | 안내문 | 이스터에그 말하는 이름: 안내문 · `StoryQuests.Speakers.Notice` |
| Bright & Rose | Bright(브라이트)와 Rose(로즈) | **[숨김]** 두 아이를 함께 부르는 이름 (Bright + Rose) · `StoryQuests.Speakers.Kids` |

### 3-0b 퀘스트 창(Q)에 보이는 글자

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Quests | 퀘스트 | 퀘스트 창 제목 · QuestBook T.Text.Title |
| Main · Side · Daily · Event · Faction | 본편 · 사이드 · 일일 · 이벤트 · 진영 | 창 위쪽 탭 5개: 본편 · 사이드 · 일일 · 이벤트 · 진영(Halo/Horns/길드 이야기) · `QuestTabs.Names` |
| In progress | 하는 중 | 하는 중인 퀘스트 묶음 제목 · T.Text.InProgress |
| Available | 받을 수 있음 | 아직 안 받았지만 받을 수 있는 퀘스트 묶음 · T.Text.Available |
| Done | 끝남 | 끝낸 퀘스트 묶음 · T.Text.Done |
| %s · Opens at Lv %d | %s · Lv %d에 열림 | 레벨이 모자라 아직 못 받는 퀘스트 줄 · `QuestBook.Text.OpensAt` · 앞 %s = 퀘스트 이름, %d = 레벨 |
| Nothing to do here right now. | 지금은 여기서 할 일이 없어요. | 이 탭에 하는 중인 퀘스트가 없을 때 · T.Text.EmptyInProgress |
| Nothing new right now. | 지금은 새로운 게 없어요. | 받을 수 있는 새 퀘스트가 없을 때 · T.Text.EmptyAvailable |
| Nothing finished yet. | 아직 끝낸 게 없어요. | 끝낸 퀘스트가 아직 없을 때 · T.Text.EmptyDone |
| First mission | 첫 임무 | 첫 임무 줄 이름 · T.Text.FirstMission |
| Daily quests today: %d/%d | 오늘의 일일 퀘스트: %d/%d | 일일 탭 위 오늘 진행 · T.Text.DailyToday · %d/%d = 지금 숫자/목표 숫자 |

말하는 사람 이름표(화자) 목록: Shard = Crown Shard, Fountain = Fountain Shard, Smith = Otto, Guild = Kit, Potion = Fizzby, Bright, Rose, Tiny, Pip, Dibs, Grabbo, Gleam = Sir Gleam, Rex = Rascal Rex, Goose = Golden Goose. 말하는 사람이 없는 퀘스트는 **내 진영 안내자**(Hallie / Magpie / Kit)가 말합니다.

### 3-1 1장 — 슬라임 가루

#### M1_1 · Sparkly Jelly (반짝이는 젤리)
- 종류: 본편 1장
- 주는 사람: Otto (대장장이, 말하는 쪽: Smith)
- 열리는 때: 첫 임무 [Claim] 뒤 본편이 시작될 때 첫 퀘스트
- 보상: 골드(사냥 1분어치) — 완료 알림 "<이름> done! +골드" + 첫 무기를 아직 안 받았으면 대장장이가 줌(안전장치)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Sparkly Jelly | 반짝이는 젤리 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Slime jelly | 슬라임 젤리 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Show the jelly to the Blacksmith | 대장장이에게 젤리를 보여 주세요 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| Use the Enhance Scroll on your weapon | 무기에 강화 주문서를 써 보세요 | 목표 2 (10/13 새로) — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴; 이 단계가 열릴 때 Otto가 Enhance Scroll 70% 1장을 줌 · `Steps.2.Text` |
| Enhance | 강화 | 목표 2 폰 화면용 짧은 이름 · `Steps.2.ShortName` |
| Otto: Clang, clang… done. Cocoa time.<br>Otto: That's Crown Shard dust! The Slime Princes ate the most of it.<br>Otto: Big brothers always grab the biggest bite! | Otto: 땅땅, 다 됐다… 코코아 마실 시간이야.<br>Otto: 이건 Crown Shard 가루야! 대부분은 Slime Prince(슬라임 왕자)들이 먹어 버렸지.<br>Otto: 형들은 늘 제일 큰 걸 먼저 집어 가거든! | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

#### M1_2 · The Prince Who Ate the Dust (가루를 먹은 왕자)
- 종류: 본편 1장
- 주는 사람: (말하는 사람 없음)
- 열리는 때: M1_1을 끝낸 뒤
- 보상: 골드(사냥 1분어치) — 완료 알림 "<이름> done! +골드"

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| The Prince Who Ate the Dust | 가루를 먹은 왕자 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Slime Princes | 슬라임 왕자들 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Slime Princes full of shard dust guard their little brothers and sisters. | 조각 가루를 잔뜩 먹은 Slime Prince들이 어린 동생들을 지키고 있다. | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Slime Princes %d/%d | Slime Prince 잡기 %d/%d | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Dust spills out! …And a braided band? Gold and purple. | 가루가 쏟아졌다! …그리고 땋은 띠? 금색과 보라색이다. | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

#### M1_3 · Boom, All at Once! (한꺼번에 쾅!)
- 종류: 본편 1장
- 주는 사람: (없음)
- 열리는 때: M1_2 뒤. Lv5에 첫 스킬을 배워야 진행
- 보상: 골드(사냥 1분어치) — 완료 알림 "<이름> done! +골드"

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Boom, All at Once! | 한꺼번에 쾅! | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Skill boom | 스킬 쾅 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Lv5 · Learn your first skill (now Lv%d) | Lv5 · 첫 스킬 배우기 (지금 Lv%d) | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d = 숫자 |
| Reach Lv 5 | Lv 5 달성 | 목표 1 폰 화면 짧은 줄 · `Steps.1.ShortName` |
| Grow to Lv5 to learn your first skill! | Lv5까지 키워서 첫 스킬을 배우자! | **[숨김]** 목표 1 시작 알림 · `Steps.1.Start` |
| Hit monsters with a skill %d/%d | 스킬로 몬스터 맞히기 %d/%d | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Dusty slimes move in groups. Skills use MP! | 가루투성이 슬라임은 무리 지어 움직인다. 스킬은 MP를 쓴다! | **[숨김]** 목표 2 시작 알림 · `Steps.2.Start` |

#### M1_4 · Report to Your Side (내 편에 보고하기)
- 종류: 본편 1장 마지막 (끝나면 [Claim] 눌러야 함)
- 주는 사람: 내 진영 안내자 (Hallie / Magpie / Kit)
- 열리는 때: M1_3 뒤
- 보상: 골드·경험치 각각 사냥 2분어치 — "<이름> done! Press [Claim]." 후 [Claim]

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Report to Your Side | 내 편에 보고하기 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Report home | 보고하러 가기 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Go to your town | 내 마을로 가기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| Report to the Guide | 안내자에게 보고하기 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| Hallie here! Now you know my name. | 나 Hallie예요! 이제 내 이름을 알았죠. | 목표 2 대화창 1쪽 — Halo(빛) 쪽 플레이어에게만 · `Steps.2.Lines.Halo.1` |
| Did you see the statues on the Heroes' Road? They are the knights who guarded the shards. | 영웅의 길(Heroes' Road)에 있는 동상들 봤어요? 조각을 지키던 기사들이에요. | 목표 2 대화창 2쪽 — Halo(빛) 쪽 플레이어에게만 · `Steps.2.Lines.Halo.2` |
| They say a Horn broke the Crown. Pure greed!<br>Broken things get fixed. Right? | 소문엔 Horn이 Crown을 깼대요. 순 욕심쟁이!<br>깨진 건 고치면 되죠. 그렇죠? | 목표 2 대화창 3쪽 — Halo(빛) 쪽 플레이어에게만 · `Steps.2.Lines.Halo.3` |
| More shards are out there.<br>What will you do with the next one? | 조각은 아직 더 있어요.<br>다음 조각은 어떻게 할래요? | 목표 2 대화창 4쪽 — Halo(빛) 쪽 플레이어에게만 · `Steps.2.Lines.Halo.4` |
| Finders keepers! HA! | 줍는 놈이 임자야! 하하! | 목표 2 대화창 1쪽 — Horns(뿔) 쪽 플레이어에게만 · `Steps.2.Lines.Horns.1` |
| See the lava cracks? Our horn power boils up from there! | 용암 갈라진 틈 보여? 우리 뿔의 힘은 거기서 끓어올라! | 목표 2 대화창 2쪽 — Horns(뿔) 쪽 플레이어에게만 · `Steps.2.Lines.Horns.2` |
| They say a Halo broke it. So greedy. Typical!<br>Shiny! Finders keepers! | 소문엔 Halo(후광·천사 쪽)가 깼대. 욕심쟁이들! 늘 저래!<br>반짝이는 건! 줍는 놈이 임자! | 목표 2 대화창 3쪽 — Horns(뿔) 쪽 플레이어에게만 · `Steps.2.Lines.Horns.3` |
| More shards are out there.<br>What will you do with the next one? | 조각은 아직 더 있어요.<br>다음 조각은 어떻게 할래요? | 목표 2 대화창 4쪽 — Horns(뿔) 쪽 플레이어에게만 · `Steps.2.Lines.Horns.4` |
| Fix first. Talk later. | 먼저 고치고, 이야기는 나중에. | 목표 2 대화창 1쪽 — Artisan Guild(길드) 쪽에게만 · `Steps.2.Lines.Neutral.1` |
| Nice dust. The guild doesn't grab, it shapes. | 가루가 좋네. 길드는 빼앗지 않아, 빚어 만들지. | 목표 2 대화창 2쪽 — Artisan Guild(길드) 쪽에게만 · `Steps.2.Lines.Neutral.2` |
| More shards are out there.<br>What will you do with the next one? | 조각은 아직 더 있어요.<br>다음 조각은 어떻게 할래요? | 목표 2 대화창 3쪽 — Artisan Guild(길드) 쪽에게만 · `Steps.2.Lines.Neutral.3` |

### 3-2 2장 — 분수와 공급로

#### M2_1 · The Crown in the Sky (하늘의 왕관)
- 종류: 본편 2장
- 주는 사람: (없음)
- 열리는 때: M1_4 뒤. 길드(Neutral)는 점수 대신 "사냥 골드 45"
- 보상: 골드(사냥 1분어치) — 완료 알림 "<이름> done! +골드"

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| The Crown in the Sky | 하늘의 왕관 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Crown points | 왕관 점수 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| The sky crown glows for the side with more shards.<br>Each monster you beat = 1 point for your side! | 하늘의 왕관은 조각이 더 많은 쪽을 비춰 줘요.<br>몬스터를 잡을 때마다 우리 편에 1점! | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Crown points %d/%d | 왕관 점수 %d/%d | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Supply gold %d/%d | 보급 골드 %d/%d | 목표 1 줄 글, 길드(Neutral)만 이걸로 바뀜 · `Steps.1.Neutral.Text` · %d/%d = 지금 숫자/목표 숫자 |

#### M2_2 · Sparkles in the Pond (연못의 반짝임)
- 종류: 본편 2장
- 주는 사람: (없음)
- 열리는 때: M2_1 뒤
- 보상: 골드(사냥 1분어치) — 완료 알림 "<이름> done! +골드"

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Sparkles in the Pond | 연못의 반짝임 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Pond slimes | 연못 슬라임 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| They say the dust melted into the pond. The pond slimes look fishy. | 가루가 연못에 녹아들었다고 한다. 연못 슬라임들이 수상하다. | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Pond slimes %d/%d | 연못 슬라임 %d/%d | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d/%d = 지금 숫자/목표 숫자 |

#### M2_3 · The Fountain of Balance (균형의 분수)
- 종류: 본편 2장 (처음으로 착한/장난 선택이 나오는 곳)
- 주는 사람: Fountain Shard (분수의 조각)
- 열리는 때: M2_2 뒤
- 보상: 골드(사냥 1분어치) — 완료 알림 "<이름> done! +골드" · 선택 점수 2점(착한 쪽/장난 쪽)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| The Fountain of Balance | 균형의 분수 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| The fountain | 분수 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| They say a Crown Shard is stuck in the Crossroads fountain. Go look!<br>(Tap the quest line for directions) | Crossroads 분수에 Crown Shard가 박혀 있다고 한다. 가 보자!<br>(퀘스트 줄을 누르면 길을 알려 줘요) | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Go to the Crossroads fountain | Crossroads의 분수로 가기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| Talk to the Fountain Shard | Fountain Shard(분수의 조각)와 이야기하기 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| I'm a Crown Shard, stuck in this fountain since the sky crown broke.<br>Halos and Horns tell the same story. They just swap who did it. | 나는 Crown Shard야. 하늘의 왕관이 깨진 뒤로 이 분수에 갇혀 있어.<br>Halo도 Horns(뿔·악마 쪽)도 똑같은 이야기를 해. 누가 그랬는지만 서로 바꿔서. | 목표 2 대화창 1쪽 — 모두에게 · `Steps.2.Lines.All.1` |
| The sparkly dust you got from the pond slimes? That's crown dust. | 연못 슬라임에게서 얻은 반짝이는 가루? 그건 왕관 가루야. | 목표 2 대화창 2쪽 — 모두에게 · `Steps.2.Lines.All.2` |
| Give the dust to the fountain: the world leans to the light.<br>Keep it: it leans to the dark. What will you do? | 가루를 분수에 주면 세상이 빛 쪽으로 기울고,<br>네가 가지면 어둠 쪽으로 기울어. 어떻게 할래? | 목표 2 대화창 3쪽 — 모두에게 · `Steps.2.Lines.All.3` |
| Give it to the fountain | 분수에 주기 | 목표 2 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.2.Obj.Good.Label` |
| Keep it | 내가 갖기 | 목표 2 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.2.Obj.Evil.Label` |
| Shape it and give it back | 빚어서 돌려주기 | 목표 2 선택 버튼 — 길드(Neutral)용 왼쪽 A · `Steps.2.Obj.Neutral.A` |
| Leave it with the guild | 길드에 맡기기 | 목표 2 선택 버튼 — 길드(Neutral)용 오른쪽 B · `Steps.2.Obj.Neutral.B` |
| Two kids by the fountain. They see you and run… opposite ways. | 분수 옆에 아이 둘이 있다. 너를 보더니 서로 반대쪽으로 달아난다… | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

#### M2_4 · Supply Road Fund (보급로 기금)
- 종류: 본편 2장
- 주는 사람: (없음)
- 열리는 때: M2_3 뒤
- 보상: 골드(사냥 1분어치) — 완료 알림 "<이름> done! +골드"

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Supply Road Fund | 보급로 기금 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Road fund | 길 기금 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Collect gold to fix the supply road. Walk into a town and it goes into your vault! | 보급로를 고칠 골드를 모으자. 마을에 들어가면 금고에 들어가요! | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Hunting gold %d/%d | 사냥 골드 %d/%d | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Put it in the town vault | 마을 금고에 넣기 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |

#### M2_5 · The Dusty Slime Swarm (가루투성이 슬라임 떼)
- 종류: 본편 2장
- 주는 사람: (없음)
- 열리는 때: M2_4 뒤. Lv5 첫 스킬이 필요
- 보상: 골드(사냥 1분어치) — 완료 알림 "<이름> done! +골드"

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| The Dusty Slime Swarm | 가루투성이 슬라임 떼 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Slime swarm | 슬라임 떼 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| The dust smell brings a slime swarm! Gather them and hit them all at once! | 가루 냄새가 슬라임 떼를 불러요! 한곳에 모아 한꺼번에 때리세요! | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Lv5 · Learn your first skill (now Lv%d) | Lv5 · 첫 스킬 배우기 (지금 Lv%d) | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d = 숫자 |
| Reach Lv 5 | Lv 5 달성 | 목표 1 폰 화면 짧은 줄 · `Steps.1.ShortName` |
| Hit 3 with one skill %d/%d | 스킬 한 번에 3마리 맞히기 %d/%d | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` · ⚠ 영어 고칠 만함: '3 무엇을?'이 빠져 있음. 'Hit 3 monsters with one skill'이 더 분명함 · %d/%d = 지금 숫자/목표 숫자 |

#### M2_6 · Little Footprints on the Hill (언덕 위의 작은 발자국)
- 종류: 본편 2장
- 주는 사람: (없음)
- 열리는 때: M2_5 뒤
- 보상: 골드(사냥 1분어치) — 완료 알림 "<이름> done! +골드"

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Little Footprints on the Hill | 언덕 위의 작은 발자국 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Hill tracks | 언덕의 발자국 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| The Slime Prince dust is gone. Little footprints lead to the woods… | Slime Prince 가루가 사라졌다. 작은 발자국이 숲으로 이어진다… | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Slime Princes %d/%d | Slime Prince 잡기 %d/%d | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Slime Princes or Goblin Brutes %d/%d | Slime Prince 또는 Goblin Brute(고블린 우두머리) 잡기 %d/%d | 목표 1 줄 글이 Lv10부터 이걸로 바뀜 · `Steps.1.AltText` · %d/%d = 지금 숫자/목표 숫자 |
| Goblins stole the dust! | 고블린들이 가루를 훔쳐 갔다! | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

#### M2_7 · A Call From Beyond the Woods (숲 너머에서 오는 부름)
- 종류: 본편 2장 마지막 ([Claim])
- 주는 사람: 내 진영 안내자 (Halo=Hallie, Horns=Magpie, 길드=Kit)
- 열리는 때: M2_6 뒤. Lv10이 되어야 진행
- 보상: 골드·경험치 각각 사냥 2분어치

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| A Call From Beyond the Woods | 숲 너머에서 오는 부름 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| To the woods | 숲으로 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Lv10 · Goblin Woods (now Lv%d) | Lv10 · Goblin Woods(고블린 숲) (지금 Lv%d) | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d = 숫자 |
| Hear the Guide's warning | 안내자의 경고 듣기 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| A Crown Shard calls from beyond the woods. Watch out for thieves! | 숲 너머에서 Crown Shard가 부르고 있어요. 도둑을 조심하세요! | 목표 2 대화창 1쪽 — 모두에게 · `Steps.2.Lines.All.1` |
| In the woods, others can steal the gold you carry. Put it in the town vault first! | 숲에서는 다른 사람이 내가 들고 있는 골드를 훔칠 수 있어요. 먼저 마을 금고에 넣어 두세요! | 목표 2 대화창 2쪽 — 모두에게 · `Steps.2.Lines.All.2` |
| Until Lv15 and 1 hour of play, the Sprout Shield keeps you safe. | Lv15가 되고 1시간 플레이할 때까지는 Sprout Shield(새싹 보호)가 지켜 줘요. | 목표 2 대화창 3쪽 — 모두에게 · `Steps.2.Lines.All.3` |
| The goblins took the dust.<br>But why would a goblin need dust? | 고블린들이 가루를 가져갔어요.<br>그런데 고블린이 가루를 어디에 쓸까요? | 목표 2 대화창 4쪽 — 모두에게 · `Steps.2.Lines.All.4` |
| A Crown Shard calls from beyond the woods. Watch out for thieves! | 숲 너머에서 Crown Shard가 부르고 있어요. 도둑을 조심하세요! | 목표 2 대화창 1쪽 — Horns(뿔) 쪽 플레이어에게만 · `Steps.2.Lines.Horns.1` |
| In the woods, others can steal the gold you carry. Put it in the town vault first! | 숲에서는 다른 사람이 내가 들고 있는 골드를 훔칠 수 있어요. 먼저 마을 금고에 넣어 두세요! | 목표 2 대화창 2쪽 — Horns(뿔) 쪽 플레이어에게만 · `Steps.2.Lines.Horns.2` |
| Until Lv15 and 1 hour of play, the Sprout Shield keeps you safe. | Lv15가 되고 1시간 플레이할 때까지는 Sprout Shield가 지켜 줘요. | 목표 2 대화창 3쪽 — Horns(뿔) 쪽 플레이어에게만 · `Steps.2.Lines.Horns.3` |
| Goblins grab for a boss. We grab for US. Big difference! …Right? | 고블린은 보스 몫으로 챙기지. 우린 우리 몫으로 챙겨! 큰 차이야! …그렇지? | 목표 2 대화창 4쪽 — Horns(뿔) 쪽 플레이어에게만 · `Steps.2.Lines.Horns.4` |
| The goblins took the dust.<br>But why would a goblin need dust? | 고블린들이 가루를 가져갔어요.<br>그런데 고블린이 가루를 어디에 쓸까요? | 목표 2 대화창 5쪽 — Horns(뿔) 쪽 플레이어에게만 · `Steps.2.Lines.Horns.5` |
| A Crown Shard calls from beyond the woods. Watch out for thieves! | 숲 너머에서 Crown Shard가 부르고 있어요. 도둑을 조심하세요! | 목표 2 대화창 1쪽 — Artisan Guild(길드) 쪽에게만 · `Steps.2.Lines.Neutral.1` |
| The Artisan Guild can't be attacked in the woods either. | Artisan Guild(장인 길드)도 숲에서는 공격받지 않아요. | 목표 2 대화창 2쪽 — Artisan Guild(길드) 쪽에게만 · `Steps.2.Lines.Neutral.2` |
| The goblins took the dust.<br>But why would a goblin need dust? | 고블린들이 가루를 가져갔어요.<br>그런데 고블린이 가루를 어디에 쓸까요? | 목표 2 대화창 3쪽 — Artisan Guild(길드) 쪽에게만 · `Steps.2.Lines.Neutral.3` |
| Go to the Goblin Woods | Goblin Woods로 가기 | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` |

### 3-3 3장 — Grab Club (고블린 숲)

#### M3_1 · Thief Footprints (도둑의 발자국)
- 종류: 본편 3장
- 주는 사람: (없음)
- 열리는 때: M2_7 뒤. 고블린 숲
- 보상: 골드(사냥 1분어치) — 완료 알림 "<이름> done! +골드"

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Thief Footprints | 도둑의 발자국 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Goblin thieves | 고블린 도둑 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| The dust thieves were goblins! Go stop them. | 가루 도둑은 고블린이었다! 막으러 가자. | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Goblins %d/%d | 고블린 %d/%d | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d/%d = 지금 숫자/목표 숫자 |
| A note: 'IOU 1 dust. Will pay back. Maybe.' | 쪽지: '가루 1개 빌림. 갚을게. 아마도.' | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

#### M3_2 · Three Camps (세 개의 야영지)
- 종류: 본편 3장
- 주는 사람: (없음)
- 열리는 때: M3_1 뒤
- 보상: 골드(사냥 1분어치) — 완료 알림 "<이름> done! +골드"

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Three Camps | 세 개의 야영지 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Three camps | 야영지 셋 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| They hid dust sacks in three goblin camps. | 가루 자루를 고블린 야영지 세 곳에 숨겼다. | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Goblin camps %d/3 | 고블린 야영지 %d/3 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d = 숫자 |
| Jars of dust… glowing like night-lights? | 가루 병들… 야간 조명처럼 빛나네? | **[숨김]** 목표 1 시련 칸을 깰 때 한 줄 (코드에서 안 씀) · `Steps.1.Obj.List.1.Say` |
| A goblin drawing: a tiny goblin, a big dark. | 고블린 그림: 작은 고블린과 커다란 어둠. | **[숨김]** 목표 1 시련 칸을 깰 때 한 줄 (코드에서 안 씀) · `Steps.1.Obj.List.2.Say` |
| Meeting #47. Topic: Grab more. Result: Meet again. | 회의 #47. 주제: 더 빼앗기. 결과: 또 모이기. | **[숨김]** 목표 1 시련 칸을 깰 때 한 줄 (코드에서 안 씀) · `Steps.1.Obj.List.3.Say` |

#### M3_3 · The Brute's Sack (우두머리의 자루)
- 종류: 본편 3장
- 주는 사람: (없음)
- 열리는 때: M3_2 뒤
- 보상: 골드(사냥 1분어치) — 완료 알림 "<이름> done! +골드"

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| The Brute's Sack | 우두머리의 자루 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Brute's sack | 우두머리의 자루 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| The Goblin Brute has the sack. Beat it with friends. Everyone counts! | Goblin Brute가 자루를 갖고 있다. 친구들과 함께 쓰러뜨리자. 모두가 센다! | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Goblin Brute %d/%d | Goblin Brute 잡기 %d/%d | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Brute: Not stealing! I'm a… surprise collector. | Brute: 훔친 거 아냐! 난… 깜짝 수집가야. | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |
| In the sack: a crayon drawing. Two kids holding something round.<br>The sun? A cookie?<br>Brute: Found it by the fountain. The night of the big CRACK! | 자루 안에는 크레용 그림이 있다. 아이 둘이 둥근 걸 들고 있다.<br>해? 쿠키?<br>Brute: 분수 옆에서 주웠어. 큰 쩍! 소리가 난 그날 밤에! | **[숨김]** 단서 알림 (A23-130부터 안 보냄) · `Clue` |

#### M3_4 · Whose Shard? (누구의 조각일까?)
- 종류: 본편 3장 마지막 ([Claim])
- 주는 사람: 내 진영 안내자 + Pip (작은 고블린)
- 열리는 때: M3_3 뒤
- 보상: 골드·경험치 각각 사냥 2분어치. 선택 점수 3점 · 장난 쪽은 골드 192도 바로 받음. 착한 쪽(또는 길드 A)이면 Lv15에 사이드 Pip1이 열림
- 참고: 대사 묶음이 M2_3(분수)에서 한 선택에 따라 달라집니다: 아래 'Lines'는 기본, 'LinesBy.Good / Evil / Default'는 변형. 마지막 '안내자 이야기' 쪽도 이 퀘스트에서 고른 선택(Good / Evil / A / B)에 따라 달라집니다.

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Whose Shard? | 누구의 조각일까? | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Whose shard? | 누구의 조각? | 폰 화면용 짧은 줄 이름 · `ShortName` |
| A Crown Shard shines in the sack! Take it home. | 자루 안에서 Crown Shard가 빛난다! 집으로 가져가자. | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Go to your town | 내 마을로 가기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| Whose shard is it? | 이건 누구의 조각일까? | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| Another shard. Another choice. | 또 다른 조각. 또 다른 선택. | 목표 2 대화창 1쪽 — 모두에게 · `Steps.2.Lines.All.1` |
| Pip: Wait! A tiny goblin followed you home.<br>Please, just a little dust? Our woods are so dark at night. | Pip(핍): 잠깐! 작은 고블린이 너를 따라 집까지 왔어.<br>가루를 조금만 줄 수 있어? 우리 숲은 밤에 너무 어두워. | 목표 2 대화창 2쪽 — 모두에게 · `Steps.2.Lines.All.2` |
| Pip: We took it for lamps. Then the big ones kept taking. | Pip: 등불 만들려고 가져갔어. 그런데 덩치 큰 애들이 계속 가져가 버렸어. | 목표 2 대화창 3쪽 — 모두에게 · `Steps.2.Lines.All.3` |
| Last time you gave the shard back. The fountain still sparkles. | 지난번엔 조각을 돌려줬지. 분수가 아직도 반짝여. | 목표 2 대화창 1쪽 — 앞선 선택이 착한 쪽이었을 때 (M2_3의 선택에 따라), 모두에게 · `Steps.2.LinesBy.Good.All.1` |
| Pip: Wait! A tiny goblin followed you home.<br>Please, just a little dust? Our woods are so dark at night. | Pip: 잠깐! 작은 고블린이 너를 따라 집까지 왔어.<br>가루를 조금만 줄 수 있어? 우리 숲은 밤에 너무 어두워. | 목표 2 대화창 2쪽 — 앞선 선택이 착한 쪽이었을 때 (M2_3의 선택에 따라), 모두에게 · `Steps.2.LinesBy.Good.All.2` |
| Pip: We took it for lamps. Then the big ones kept taking. | Pip: 등불 만들려고 가져갔어. 그런데 덩치 큰 애들이 계속 가져가 버렸어. | 목표 2 대화창 3쪽 — 앞선 선택이 착한 쪽이었을 때 (M2_3의 선택에 따라), 모두에게 · `Steps.2.LinesBy.Good.All.3` |
| Last time you kept the shard. Still shiny in your pocket! | 지난번엔 조각을 네가 가졌지. 아직도 주머니 속에서 반짝여! | 목표 2 대화창 1쪽 — 앞선 선택이 장난(악) 쪽이었을 때 (M2_3의 선택에 따라), 모두에게 · `Steps.2.LinesBy.Evil.All.1` |
| Pip: Wait! A tiny goblin followed you home.<br>Please, just a little dust? Our woods are so dark at night. | Pip: 잠깐! 작은 고블린이 너를 따라 집까지 왔어.<br>가루를 조금만 줄 수 있어? 우리 숲은 밤에 너무 어두워. | 목표 2 대화창 2쪽 — 앞선 선택이 장난(악) 쪽이었을 때 (M2_3의 선택에 따라), 모두에게 · `Steps.2.LinesBy.Evil.All.2` |
| Pip: We took it for lamps. Then the big ones kept taking. | Pip: 등불 만들려고 가져갔어. 그런데 덩치 큰 애들이 계속 가져가 버렸어. | 목표 2 대화창 3쪽 — 앞선 선택이 장난(악) 쪽이었을 때 (M2_3의 선택에 따라), 모두에게 · `Steps.2.LinesBy.Evil.All.3` |
| Another shard. Another choice. | 또 다른 조각. 또 다른 선택. | 목표 2 대화창 1쪽 — 선택 기록이 없을 때(기본) (M2_3의 선택에 따라), 모두에게 · `Steps.2.LinesBy.Default.All.1` |
| Pip: Wait! A tiny goblin followed you home.<br>Please, just a little dust? Our woods are so dark at night. | Pip: 잠깐! 작은 고블린이 너를 따라 집까지 왔어.<br>가루를 조금만 줄 수 있어? 우리 숲은 밤에 너무 어두워. | 목표 2 대화창 2쪽 — 선택 기록이 없을 때(기본) (M2_3의 선택에 따라), 모두에게 · `Steps.2.LinesBy.Default.All.2` |
| Pip: We took it for lamps. Then the big ones kept taking. | Pip: 등불 만들려고 가져갔어. 그런데 덩치 큰 애들이 계속 가져가 버렸어. | 목표 2 대화창 3쪽 — 선택 기록이 없을 때(기본) (M2_3의 선택에 따라), 모두에게 · `Steps.2.LinesBy.Default.All.3` |
| Leave some for their lamps | 등불 만들 만큼 조금 남겨 주기 | 목표 2 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.2.Obj.Good.Label` |
| Into our vault. They took it first! | 우리 금고로! 쟤네가 먼저 가져갔잖아! | 목표 2 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.2.Obj.Evil.Label` · ⚠ 영어 고칠 만함: 버튼에 쓰기엔 길고, 'They'가 누구인지(고블린) 안 보임 |
| Make them a real lamp | 진짜 등불을 만들어 주기 | 목표 2 선택 버튼 — 길드(Neutral)용 왼쪽 A · `Steps.2.Obj.Neutral.A` |
| Sell the dust back to them | 가루를 되팔기 | 목표 2 선택 버튼 — 길드(Neutral)용 오른쪽 B · `Steps.2.Obj.Neutral.B` |
| Hear the Guide | 안내자 이야기 듣기 | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` |
| The shard found a home. | 조각이 집을 찾았다. | 목표 3 대화창 1쪽 — 모두에게 · `Steps.3.Lines.All.1` |
| You left them some? Soft! …The little ones look happy, though. | 조금 남겨 줬다고? 무르네! …그래도 꼬마들은 기뻐 보이네. | 목표 3 대화창 1쪽 — 앞선 선택이 착한 쪽이었을 때 (이 퀘스트 자신의 선택에 따라), 모두에게 · `Steps.3.LinesBy.Good.All.1` |
| A little light for them. Not bad. | 그 애들한테 작은 빛이 됐네. 나쁘지 않아. | 목표 3 대화창 1쪽 — 앞선 선택이 착한 쪽이었을 때 (이 퀘스트 자신의 선택에 따라), Halo(빛) 쪽 플레이어에게만 · `Steps.3.LinesBy.Good.Halo.1` |
| Into the vault? …It does shine nicely. | 금고에? …반짝이긴 하네. | 목표 3 대화창 1쪽 — 앞선 선택이 장난(악) 쪽이었을 때 (이 퀘스트 자신의 선택에 따라), 모두에게 · `Steps.3.LinesBy.Evil.All.1` |
| Dibs: Ka-ching! Same as always? Same as always! | Dibs(딥스): 짤랑! 늘 하던 대로? 늘 하던 대로! | 목표 3 대화창 2쪽 — 앞선 선택이 장난(악) 쪽이었을 때 (이 퀘스트 자신의 선택에 따라), 모두에게 · `Steps.3.LinesBy.Evil.All.2` |
| Ha! Finders keepers! | 하하! 줍는 놈이 임자! | 목표 3 대화창 1쪽 — 앞선 선택이 장난(악) 쪽이었을 때 (이 퀘스트 자신의 선택에 따라), Horns(뿔) 쪽 플레이어에게만 · `Steps.3.LinesBy.Evil.Horns.1` |
| Dibs: Ka-ching! Same as always? Same as always! | Dibs: 짤랑! 늘 하던 대로? 늘 하던 대로! | 목표 3 대화창 2쪽 — 앞선 선택이 장난(악) 쪽이었을 때 (이 퀘스트 자신의 선택에 따라), Horns(뿔) 쪽 플레이어에게만 · `Steps.3.LinesBy.Evil.Horns.2` |
| A real lamp! The little goblins will love it. | 진짜 등불이라니! 꼬마 고블린들이 좋아하겠다. | 목표 3 대화창 1쪽 — 앞선 선택이 길드 A였을 때 (이 퀘스트 자신의 선택에 따라), 모두에게 · `Steps.3.LinesBy.A.All.1` |
| Sold it back? Business is business. | 되팔았다고? 장사는 장사지. | 목표 3 대화창 1쪽 — 앞선 선택이 길드 B였을 때 (이 퀘스트 자신의 선택에 따라), 모두에게 · `Steps.3.LinesBy.B.All.1` |
| Dibs: Ka-ching! Same as always? Same as always! | Dibs: 짤랑! 늘 하던 대로? 늘 하던 대로! | 목표 3 대화창 2쪽 — 앞선 선택이 길드 B였을 때 (이 퀘스트 자신의 선택에 따라), 모두에게 · `Steps.3.LinesBy.B.All.2` |
| The shard found a home. | 조각이 집을 찾았다. | 목표 3 대화창 1쪽 — 선택 기록이 없을 때(기본) (이 퀘스트 자신의 선택에 따라), 모두에게 · `Steps.3.LinesBy.Default.All.1` |

#### M3_6 · Brute Hunt (우두머리 사냥)
- 종류: 본편 3장
- 주는 사람: (없음)
- 열리는 때: M3_4 뒤. Lv18 필요
- 보상: 골드(사냥 1분어치) — 완료 알림 "<이름> done! +골드"

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Brute Hunt | 우두머리 사냥 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Brute hunt | 우두머리 사냥 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Lv18 · Brute Hunt (now Lv%d) | Lv18 · 우두머리 사냥 (지금 Lv%d) | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d = 숫자 |
| Goblin Brutes %d/%d | Goblin Brute 잡기 %d/%d | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` · %d/%d = 지금 숫자/목표 숫자 |
| The Brutes carry the sacks to the mountain path! | 우두머리들이 자루를 산길로 나르고 있다! | **[숨김]** 목표 2 시작 알림 · `Steps.2.Start` |

#### M3_7 · Campfire Dust (모닥불 가루)
- 종류: 본편 3장
- 주는 사람: (없음)
- 열리는 때: M3_6 뒤. Lv21 필요
- 보상: 골드(사냥 1분어치) — 완료 알림 "<이름> done! +골드"

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Campfire Dust | 모닥불 가루 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Campfire dust | 모닥불 가루 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Lv21 · Campfire Dust (now Lv%d) | Lv21 · 모닥불 가루 (지금 Lv%d) | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d = 숫자 |
| Hit 3 at once with a skill %d/%d | 스킬로 한 번에 3마리 맞히기 %d/%d | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` · %d/%d = 지금 숫자/목표 숫자 |
| They grab in a line. Break the line! | 저들은 줄지어 훔쳐 가. 그 줄을 끊어 버려! | **[숨김]** 목표 2 시작 알림 · `Steps.2.Start` |

#### M3_8 · Call of the Tombs (무덤의 부름)
- 종류: 본편 3장 마지막 ([Claim])
- 주는 사람: (없음, 무덤의 목소리)
- 열리는 때: M3_7 뒤. Lv25 필요
- 보상: 골드·경험치 각각 사냥 2분어치. 4장은 아직 없음

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Call of the Tombs | 무덤의 부름 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| The tombs | 무덤 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Lv25 · Skeleton Ruins (now Lv%d) | Lv25 · Skeleton Ruins(해골 유적) (지금 Lv%d) | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d = 숫자 |
| Go to the Skeleton Ruins | Skeleton Ruins로 가기 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| Listen to the tombs | 무덤의 소리 듣기 | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` |
| A big shard sleeps in the old kingdom's tombs. | 큰 조각 하나가 옛 왕국의 무덤에서 잠자고 있다. | 목표 3 대화창 1쪽 — 모두에게 · `Steps.3.Lines.All.1` |
| From the tombs, a sleepy voice: 'Is it still Tuesday?' | 무덤에서 졸린 목소리가 들린다: '오늘 아직도 화요일이야?' | 목표 3 대화창 2쪽 — 모두에게 · `Steps.3.Lines.All.2` |
| The goblins took for light. Then they forgot why.<br>What do YOU want the shard for? | 고블린들은 빛이 필요해서 가져갔어. 그러다 이유를 잊었지.<br>너는 조각을 뭐에 쓰고 싶어? | 목표 3 대화창 3쪽 — 모두에게 · `Steps.3.Lines.All.3` |
| Chapter 4 is coming! | 4장이 곧 와요! | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

※ M3_5 'Sprout Graduation'(졸업)은 본편이 아니라 사이드로 옮겨져 ④-3에 있습니다.

## ④ 마을·사이드 퀘스트

퀘스트 창(Q)의 **Side / Faction** 탭에 나옵니다. 진영 전용(H=Halo, R=Horns)은 자기 진영만 받고, 길드(Neutral)는 지금 꺼져 있어 못 받습니다. 끝에 나오는 **선택**은 모두 같은 틀입니다: 왼쪽(착한)과 오른쪽(장난)을 고르면 보상 종류가 다르고 둘 다 같은 가치입니다.

### 4-1 처음 10분 안팎에 만나는 사이드

#### Lunch1 · Lost Lunchbox! (잃어버린 도시락!)
- 종류: 사이드 (카드가 저절로 한 번 뜸)
- 주는 사람: (말하는 사람 없음 — 내 진영 안내자 목소리)
- 열리는 때: 첫 임무 [Claim] 바로 뒤
- 보상: 선택 점수 0점(조각이 한쪽으로 기울기만 함). 착한 쪽 = HP 물약 1개, 장난 쪽 = 골드 25

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Lost Lunchbox! | 잃어버린 도시락! | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Lost lunchbox | 잃어버린 도시락 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Return the lunchbox, or take a bite? | 도시락을 돌려줄까, 한입 먹을까? | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| A slime dropped a lunchbox. It belongs to a kid at the Crossroads. | 슬라임이 도시락을 떨어뜨렸다. Crossroads에 사는 아이 것이다. | 목표 1 대화창 1쪽 — 모두에게 · `Steps.1.Lines.All.1` |
| Give it back | 돌려주기 | 목표 1 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.1.Obj.Good.Label` |
| One bite! | 한입만! | 목표 1 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.1.Obj.Evil.Label` |
| Give it back | 돌려주기 | 목표 1 선택 버튼 — 길드(Neutral)용 왼쪽 A · `Steps.1.Obj.Neutral.A` |
| One bite! | 한입만! | 목표 1 선택 버튼 — 길드(Neutral)용 오른쪽 B · `Steps.1.Obj.Neutral.B` |

#### S0 · The Shard That Learns to Fight (싸우는 법을 배우는 조각)
- 종류: 사이드
- 주는 사람: Crown Shard (말하는 왕관 조각)
- 열리는 때: 직업을 고른 직후 자동으로 받음
- 보상: 완료하면 Auto Battle(자동 전투)이 열림 · 선택 점수 2점

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| The Shard That Learns to Fight | 싸우는 법을 배우는 조각 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Learn to fight | 싸움 배우기 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Beat a Slime Prince and find the shard %d/%d | Slime Prince를 잡고 조각을 찾기 %d/%d | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d/%d = 지금 숫자/목표 숫자 |
| A Slime Prince swallowed a shard! Beat it to free the shard. | Slime Prince가 조각을 삼켰다! 쓰러뜨려서 조각을 풀어 주자. | **[숨김]** 목표 1 시작 알림 · `Steps.1.Start` |
| The shard's test %d/3 | 조각의 시험 %d/3 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` · %d = 숫자 |
| Shard: Show me how you fight! | Shard: 네가 싸우는 걸 보여 줘! | **[숨김]** 목표 2 시작 알림 · `Steps.2.Start` |
| What will you do with the shard? | 조각을 어떻게 할래? | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` |
| I saw it all! Now I can fight like you. | 다 봤어! 이제 나도 너처럼 싸울 수 있어. | 목표 3 대화창 1쪽 — 모두에게 · `Steps.3.Lines.All.1` |
| What will you do with me? | 나를 어떻게 할 거야? | 목표 3 대화창 2쪽 — 모두에게 · `Steps.3.Lines.All.2` |
| Purify it | 정화하기 | 목표 3 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.3.Obj.Good.Label` |
| Devour it | 삼키기 | 목표 3 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.3.Obj.Evil.Label` |
| Purify it | 정화하기 | 목표 3 선택 버튼 — 길드(Neutral)용 왼쪽 A · `Steps.3.Obj.Neutral.A` |
| Devour it | 삼키기 | 목표 3 선택 버튼 — 길드(Neutral)용 오른쪽 B · `Steps.3.Obj.Neutral.B` |

#### Pet1 · The Lost Baby Slime (길 잃은 아기 슬라임)
- 종류: 사이드
- 주는 사람: (없음)
- 열리는 때: M1_1 끝난 뒤
- 보상: Baby Slime 펫을 얻음 · 선택 점수 1점 (착한 쪽 = 펫 이름 Good Buddy, 장난 쪽 = Little Minion)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| The Lost Baby Slime | 길 잃은 아기 슬라임 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Baby Slime | 아기 슬라임 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Beat meadow slimes %d/%d | 초원 슬라임 잡기 %d/%d | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Something small is crying in the meadow... | 초원에서 작은 무언가가 울고 있어요... | **[숨김]** 목표 1 시작 알림 · `Steps.1.Start` |
| A lost Baby Slime! What will you do? | 길 잃은 Baby Slime! 어떻게 할래? | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| A tiny lost slime hops up to you. | 길 잃은 아주 작은 슬라임이 폴짝 다가온다. | 목표 2 대화창 1쪽 — 모두에게 · `Steps.2.Lines.All.1` |
| It wants to come with you! | 너랑 같이 가고 싶대! | 목표 2 대화창 2쪽 — 모두에게 · `Steps.2.Lines.All.2` |
| Take care of it | 돌봐 주기 | 목표 2 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.2.Obj.Good.Label` |
| Make it my minion | 내 부하로 삼기 | 목표 2 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.2.Obj.Evil.Label` |
| Take care of it | 돌봐 주기 | 목표 2 선택 버튼 — 길드(Neutral)용 왼쪽 A · `Steps.2.Obj.Neutral.A` |
| Make it my minion | 내 부하로 삼기 | 목표 2 선택 버튼 — 길드(Neutral)용 오른쪽 B · `Steps.2.Obj.Neutral.B` |

#### KO1 · The King's Hop (킹의 점프)
- 종류: 사이드 (5줄, 알림 없음)
- 주는 사람: (없음)
- 열리는 때: M1_2 뒤, Lv8 이하이면서 물약이 하나도 없을 때만
- 보상: 골드·경험치 각각 사냥 2분어치 + 강화 주문서 70% 1장
- 참고: 5개 목표가 차례로 줄에 나옵니다. 처음 King Slime은 한 번 쓰러져도 잃는 게 없고(Nothing lost), 물약을 사고 퀵슬롯에 넣고 마신 뒤 다시 도전합니다. 알림이나 팝업은 없습니다(A23-99).

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| The King's Hop | 킹의 점프 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| King's hop | 킹의 점프 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Defeat the King Slime | King Slime(킹 슬라임) 쓰러뜨리기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · 1번 목표와 5번 목표의 글이 똑같음. 1번은 이기라고 적혀 있지만 실제로는 King Slime에게 한 번 쓰러져야 다음으로 넘어감(의도된 설계) |
| Defeat King | 킹 쓰러뜨리기 | 목표 1 폰 화면 짧은 줄 · `Steps.1.ShortName` |
| Buy a potion | 물약 사기 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| Buy a potion | 물약 사기 | 목표 2 폰 화면 짧은 줄 · `Steps.2.ShortName` |
| Put the potion in a quick slot | 물약을 퀵슬롯에 넣기 | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` |
| Quick slot | 퀵슬롯 | 목표 3 폰 화면 짧은 줄 · `Steps.3.ShortName` |
| Drink it from your quick slot | 퀵슬롯으로 마시기 | 목표 4 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.4.Text` |
| Drink potion | 물약 마시기 | 목표 4 폰 화면 짧은 줄 · `Steps.4.ShortName` |
| Defeat the King Slime | King Slime 쓰러뜨리기 | 목표 5 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.5.Text` · 1번 목표와 5번 목표의 글이 똑같음. 1번은 이기라고 적혀 있지만 실제로는 King Slime에게 한 번 쓰러져야 다음으로 넘어감(의도된 설계) |
| Defeat King | 킹 쓰러뜨리기 | 목표 5 폰 화면 짧은 줄 · `Steps.5.ShortName` |

#### S4 · The Shard Fights for You (나를 위해 싸우는 조각)
- 종류: 사이드
- 주는 사람: Crown Shard (조각)
- 열리는 때: S0 끝난 뒤
- 보상: 골드(사냥 1분어치) — 완료 알림 "<이름> done! +골드"

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| The Shard Fights for You | 나를 위해 싸우는 조각 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Auto Battle | 자동 전투 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Shard: Now I'll fight monsters for you. Players, only by your own hand! | Shard: 이제 내가 대신 몬스터와 싸워 줄게. 플레이어는 직접 손으로만! | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Turn on Auto Battle ({Auto}) | Auto Battle 켜기 ({Auto}) | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · {Auto} = 게임이 알아서 채움 |
| Auto Battle defeats %d/%d | Auto Battle로 쓰러뜨리기 %d/%d | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` · %d/%d = 지금 숫자/목표 숫자 |

#### S3 · Golden Jelly (황금 젤리)
- 종류: 사이드
- 주는 사람: (없음)
- 열리는 때: M1_4 뒤
- 보상: 선택 점수 1점 (보상 골드 없음)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Golden Jelly | 황금 젤리 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Golden jelly | 황금 젤리 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Golden monsters %d/%d | 황금 몬스터 %d/%d | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d/%d = 지금 숫자/목표 숫자 |
| What will you do with the gold dust? | 황금 가루를 어떻게 할래? | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| Monsters that eat lots of dust turn gold! | 가루를 많이 먹은 몬스터는 금색이 된다! | 목표 2 대화창 1쪽 — 모두에게 · `Steps.2.Lines.All.1` |
| What will you do with this gold dust? | 이 황금 가루를 어떻게 할래? | 목표 2 대화창 2쪽 — 모두에게 · `Steps.2.Lines.All.2` |
| Give it to the fountain | 분수에 주기 | 목표 2 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.2.Obj.Good.Label` |
| Into my pouch! | 내 주머니로! | 목표 2 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.2.Obj.Evil.Label` |
| Give it to the fountain | 분수에 주기 | 목표 2 선택 버튼 — 길드(Neutral)용 왼쪽 A · `Steps.2.Obj.Neutral.A` |
| Leave it with the guild | 길드에 맡기기 | 목표 2 선택 버튼 — 길드(Neutral)용 오른쪽 B · `Steps.2.Obj.Neutral.B` |

### 4-2 스킬을 새로 배운 뒤 연습 (2·3번째 스킬이 켜지면 열림)

#### SK1 · A New Move (새 기술) **[꺼짐]**
- 종류: 사이드
- 주는 사람: Crown Shard (조각)
- 열리는 때: 두 번째 스킬(Z)을 배운 뒤 (지금 Z/X 스킬은 꺼져 있어서 안 열림)
- 보상: 골드(사냥 1분어치) — 완료 알림 "<이름> done! +골드"

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| A New Move | 새 기술 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| New move | 새 기술 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Shard: A new move! Try it on a group. | Shard: 새 기술이다! 무리에게 써 봐. | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Hit 2 monsters at once with your new skill %d/%d | 새 스킬로 몬스터 2마리를 한꺼번에 맞히기 %d/%d | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d/%d = 지금 숫자/목표 숫자 |

#### SK2 · The Shard's Gift (조각의 선물) **[꺼짐]**
- 종류: 사이드
- 주는 사람: Crown Shard (조각)
- 열리는 때: 세 번째 스킬(X)을 배운 뒤 (지금은 꺼져 있어서 안 열림)
- 보상: 골드(사냥 1분어치) — 완료 알림 "<이름> done! +골드" · 선택 점수 1점

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| The Shard's Gift | 조각의 선물 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Shard's gift | 조각의 선물 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Shard: You grew strong. Come to the Crossroads fountain. | Shard: 강해졌네. Crossroads 분수로 와 봐. | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Go to the Crossroads fountain | Crossroads의 분수로 가기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| How will you use your power? | 힘을 어떻게 쓸래? | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| You grew strong. Your side's power woke up in you.<br>How will you use it? | 강해졌어. 네 편의 힘이 깨어났어.<br>어떻게 쓸래? | 목표 2 대화창 1쪽 — 모두에게 · `Steps.2.Lines.All.1` |
| Guard my friends | 친구를 지키기 | 목표 2 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.2.Obj.Good.Label` |
| Take what I want | 원하는 걸 가지기 | 목표 2 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.2.Obj.Evil.Label` |
| Build things | 무언가 만들기 | 목표 2 선택 버튼 — 길드(Neutral)용 왼쪽 A · `Steps.2.Obj.Neutral.A` |
| Fix things | 무언가 고치기 | 목표 2 선택 버튼 — 길드(Neutral)용 오른쪽 B · `Steps.2.Obj.Neutral.B` |
| Hit monsters with your new skill %d/%d | 새 스킬로 몬스터 맞히기 %d/%d | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` · %d/%d = 지금 숫자/목표 숫자 |

### 4-3 마을 사람 사이드 — 소문과 오해 (Lv5~22)

#### S6 · Keep the Path Safe (길을 안전하게 지키자)
- 종류: 마을 사이드
- 주는 사람: 내 진영 안내자 (Halo/Horns만)
- 열리는 때: M1_4 뒤, Lv5부터
- 보상: 골드 120 + 경험치(현재 레벨 막대의 절반) — 완료하면 "<이름> done! +골드 · +XP" 알림
- 선택 보상: 왼쪽(착한 쪽) = 강화 주문서 70% 1장 · 오른쪽(장난 쪽) = HP 물약 3개 + 골드 220. 점수 1점 (자기 진영 점수는 오르고, 반대쪽 고르면 자기 점수가 깎임, A23-58)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Keep the Path Safe | 길을 안전하게 지키자 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Safe path | 안전한 길 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Slimes by the meadow arrival %d/%d | 초원 도착지 근처 슬라임 %d/%d | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Hunting gold %d/%d | 사냥 골드 %d/%d | 목표 1 줄 글, Horns(뿔) 쪽만 이걸로 바뀜 · `Steps.1.Horns.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Back to your town | 내 마을로 돌아가기 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| Talk with the Guide | 안내자와 이야기하기 | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` |
| New kids walk this path. Keep it safe! | 새로 온 아이들이 이 길을 걸어요. 안전하게 지켜 줘요! | 목표 3 대화창 1쪽 — Halo(빛) 쪽 플레이어에게만 · `Steps.3.Lines.Halo.1` |
| The new kids keep asking for help… | 새로 온 아이들이 자꾸 도와 달라고 해요… | 목표 3 대화창 2쪽 — Halo(빛) 쪽 플레이어에게만 · `Steps.3.Lines.Halo.2` |
| A Horn Legion pouch must be FAT! | Horn Legion(뿔 군단)의 주머니는 두둑해야지! | 목표 3 대화창 1쪽 — Horns(뿔) 쪽 플레이어에게만 · `Steps.3.Lines.Horns.1` |
| So. What will you do with all that gold? | 그래서. 그 골드로 뭘 할래? | 목표 3 대화창 2쪽 — Horns(뿔) 쪽 플레이어에게만 · `Steps.3.Lines.Horns.2` |
| Help them find the slimes | 슬라임 찾는 걸 도와주기 | 목표 3 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.3.Obj.Good.Label` |
| Make them say "Thanks, boss!" | "고마워요, 대장!" 하고 말하게 하기 | 목표 3 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.3.Obj.Evil.Label` |
| Share snacks with the den | 소굴 친구들과 간식 나눠 먹기 | 목표 3 선택 버튼 — Horns(뿔) 쪽 전용 왼쪽(착한 쪽) · `Steps.3.Horns.Obj.Good.Label` |
| Count it twice. Mine! | 두 번 세어 보기. 내 거야! | 목표 3 선택 버튼 — Horns(뿔) 쪽 전용 오른쪽(장난 쪽) · `Steps.3.Horns.Obj.Evil.Label` |
| Who walks this path next? | 다음엔 누가 이 길을 걸을까? | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

#### XR1 · Lost & Found (분실물 찾기)
- 종류: 마을 사이드
- 주는 사람: Tiny (길드 꼬마, 교차로)
- 열리는 때: M1_4 뒤, Lv5부터
- 보상: 골드 120 + 경험치(현재 레벨 막대의 절반) — 완료하면 "<이름> done! +골드 · +XP" 알림
- 선택 보상: 왼쪽(착한 쪽) = 강화 주문서 70% 1장 · 오른쪽(장난 쪽) = HP 물약 3개 + 골드 220. 점수 1점 (자기 진영 점수는 오르고, 반대쪽 고르면 자기 점수가 깎임, A23-58)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Lost & Found | 분실물 찾기 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Lost bear | 잃어버린 곰 인형 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Talk to Tiny at the Crossroads | Crossroads의 Tiny(타이니)와 이야기하기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| Tiny: A Slime Prince swallowed a teddy bear! | Tiny: Slime Prince가 곰 인형을 삼켰어! | 목표 1 대화창 1쪽 — 모두에게 · `Steps.1.Lines.All.1` |
| Tiny: Noted. Teddy bear: very loved. Very lost. | Tiny: 메모했어. 곰 인형: 아주 사랑받음. 아주 잃어버림. | 목표 1 대화창 2쪽 — 모두에게 · `Steps.1.Lines.All.2` |
| Slime Prince %d/%d | Slime Prince 잡기 %d/%d | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Bring the bear to Tiny | 곰 인형을 Tiny에게 가져가기 | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` |
| Tiny: A bit sticky. Still very soft. | Tiny: 좀 끈적해. 그래도 아주 폭신해. | 목표 3 대화창 1쪽 — 모두에게 · `Steps.3.Lines.All.1` |
| Tiny: So. What now? | Tiny: 자. 이제 어떻게 할까? | 목표 3 대화창 2쪽 — 모두에게 · `Steps.3.Lines.All.2` |
| Return it to its owner | 주인에게 돌려주기 | 목표 3 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.3.Obj.Good.Label` |
| Sell it at the counter | 카운터에서 팔기 | 목표 3 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.3.Obj.Evil.Label` |
| Return it to its owner | 주인에게 돌려주기 | 목표 3 선택 버튼 — 길드(Neutral)용 왼쪽 A · `Steps.3.Obj.Neutral.A` |
| Sell it at the counter | 카운터에서 팔기 | 목표 3 선택 버튼 — 길드(Neutral)용 오른쪽 B · `Steps.3.Obj.Neutral.B` |
| Tiny: Thanks for your business. …Who lost it, anyway? | Tiny: 거래해 줘서 고마워. …근데 누가 잃어버렸더라? | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

#### H1 · The Horns Are Up to Something (뿔 쪽이 뭔가 꾸미고 있어요)
- 종류: 마을 사이드 (Halo 전용)
- 주는 사람: Bright (젊은 경비, 빛의 성채)
- 열리는 때: M2_3 뒤
- 보상: 골드 120 + 경험치(현재 레벨 막대의 절반) — 완료하면 "<이름> done! +골드 · +XP" 알림
- 선택 보상: 왼쪽(착한 쪽) = 강화 주문서 70% 1장 · 오른쪽(장난 쪽) = HP 물약 3개 + 골드 220. 점수 1점 (자기 진영 점수는 오르고, 반대쪽 고르면 자기 점수가 깎임, A23-58)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| The Horns Are Up to Something | 뿔 쪽이 뭔가 꾸미고 있어요 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Spy on Horns | Horns 염탐 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Bright, the young guard, needs help. Find her in Halo Citadel! | 젊은 경비 Bright가 도움이 필요해요. Halo Citadel(빛의 성채)에서 찾아보세요! | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Talk to Bright in Halo Citadel | Halo Citadel에서 Bright와 이야기하기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| The Horns are up to something! I need Form H-1.<br>To get Form H-1, I need Form H-0. …Can you just help? | Horns가 뭔가 꾸미고 있어요! 나는 H-1 서식이 필요해요.<br>H-1 서식을 받으려면 H-0 서식이 필요하고요. …그냥 도와줄래요? | 목표 1 대화창 1쪽 — 모두에게 · `Steps.1.Lines.All.1` |
| They say a Horn broke the Crown. Everyone says so.<br>…Who said so first? | 소문엔 Horn이 Crown을 깼대요. 다들 그렇게 말해요.<br>…근데 누가 제일 먼저 그렇게 말했죠? | 목표 1 대화창 2쪽 — 모두에게 · `Steps.1.Lines.All.2` |
| Page 12 of my rulebook is missing. Don't look at me!<br>The Horns sneak past the woods with big sacks. Go take a look! | 규정집 12쪽이 사라졌어요. 나를 쳐다보지 마요!<br>Horns가 큰 자루를 들고 숲 쪽으로 몰래 지나가요. 가서 살펴보세요! | 목표 1 대화창 3쪽 — 모두에게 · `Steps.1.Lines.All.3` |
| Spy by the woods' edge %d/%d s | 숲 입구에서 염탐하기 %d/%d초 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Slime Princes in the meadow %d/%d | 초원 Slime Prince 잡기 %d/%d | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` · %d/%d = 지금 숫자/목표 숫자 |
| A sack fell open… and Slime Princes gobbled what was inside! | 자루가 터졌다… 그리고 Slime Prince들이 안에 든 걸 게걸스럽게 먹었다! | **[숨김]** 목표 3 시작 알림 · `Steps.3.Start` |
| Tell Bright what you found | 알아낸 것을 Bright에게 알려 주기 | 목표 4 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.4.Text` |
| Sticky… sweet… is this jelly? | 끈적… 달콤… 이거 젤리인가? | 목표 4 대화창 1쪽 — 모두에게 · `Steps.4.Lines.All.1` |
| Their secret sacks… are full of birthday jelly? For Rose? | 비밀 자루가… 생일 젤리로 가득이라고? Rose를 위해? | 목표 4 대화창 2쪽 — 모두에게 · `Steps.4.Lines.All.2` |
| One jar says: 'Happy birthday, S. From the bench.'<br>Bright: Not my writing! I mean… whose writing? | 한 병에 이렇게 적혀 있다: '생일 축하해, S. 벤치에서.'<br>Bright: 내 글씨 아냐! 그러니까… 누구 글씨지? | 목표 4 대화창 3쪽 — 모두에게 · `Steps.4.Lines.All.3` |
| So what do we tell everyone? | 그래서 다들 뭐라고 말해 줄까요? | 목표 4 대화창 4쪽 — 모두에게 · `Steps.4.Lines.All.4` |
| Tell everyone the truth | 모두에게 사실대로 말하기 | 목표 4 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.4.Obj.Good.Label` |
| Keep the rumor going. It's more fun! | 소문을 계속 퍼뜨리기. 그게 더 재밌어! | 목표 4 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.4.Obj.Evil.Label` |
| Bright: So who started the rumor? …Does anyone remember? | Bright: 그래서 누가 소문을 낸 거죠? …기억하는 사람 있나요? | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |
| Bright's wristband: gold and purple. Where have you seen one? | Bright의 손목밴드: 금색과 보라색. 어디서 본 적 있지? | **[숨김]** 단서 알림 (A23-130부터 안 보냄) · `Clue` |

#### R1 · The Halos Are Up to Something (빛 쪽이 뭔가 꾸미고 있어요)
- 종류: 마을 사이드 (Horns 전용)
- 주는 사람: Rose (뿔 소굴 꼬마)
- 열리는 때: M2_3 뒤
- 보상: 골드 120 + 경험치(현재 레벨 막대의 절반) — 완료하면 "<이름> done! +골드 · +XP" 알림
- 선택 보상: 왼쪽(착한 쪽) = 강화 주문서 70% 1장 · 오른쪽(장난 쪽) = HP 물약 3개 + 골드 220. 점수 1점 (자기 진영 점수는 오르고, 반대쪽 고르면 자기 점수가 깎임, A23-58)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| The Halos Are Up to Something | 빛 쪽이 뭔가 꾸미고 있어요 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Spy on Halos | Halo 염탐 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Psst! Rose in Horns Den has a secret job for you. | 쉿! Horns Den(뿔 소굴)의 Rose가 비밀 일을 맡길래요. | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Talk to Rose in Horns Den | Horns Den의 Rose와 이야기하기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| Psst! A Halo broke the Crown! My uncle's friend's cousin saw it! | 쉿! Halo가 Crown을 깼어! 우리 삼촌 친구의 사촌이 봤대! | 목표 1 대화창 1쪽 — 모두에게 · `Steps.1.Lines.All.1` |
| This gold spyglass? Found it. Gold is fine. For spying.<br>Plan A: we spy. Plan B: same as Plan A, but sneakier! | 이 금빛 망원경? 주웠어. 금이면 괜찮지. 염탐용으로.<br>계획 A: 염탐하기. 계획 B: 계획 A와 같은데 더 몰래! | 목표 1 대화창 2쪽 — 모두에게 · `Steps.1.Lines.All.2` |
| The Halos whisper at the fountain. A secret plan!<br>Go listen there. Look natural! | Halo들이 분수에서 속닥거려. 비밀 계획이야!<br>가서 들어 봐. 자연스럽게! | 목표 1 대화창 3쪽 — 모두에게 · `Steps.1.Lines.All.3` |
| Listen at the fountain %d/%d s | 분수에서 엿듣기 %d/%d초 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Slimes in the meadow %d/%d | 초원 슬라임 잡기 %d/%d | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` · %d/%d = 지금 숫자/목표 숫자 |
| You heard: "Slimes… sparkles… BOOM at sunset!" Check the meadow! | 들은 말: "슬라임… 반짝… 해 질 녘에 쾅!" 초원을 살펴보세요! | **[숨김]** 목표 3 시작 알림 · `Steps.3.Start` |
| Tell Rose what you heard | 들은 것을 Rose에게 알려 주기 | 목표 4 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.4.Text` |
| The slimes were full of sparkle dust. For a show? | 슬라임은 반짝 가루로 가득했다. 공연용인가? | 목표 4 대화창 1쪽 — 모두에게 · `Steps.4.Lines.All.1` |
| Their big secret… is a fireworks show? For everyone? | 그들의 큰 비밀이… 불꽃놀이라고? 모두를 위한? | 목표 4 대화창 2쪽 — 모두에게 · `Steps.4.Lines.All.2` |
| One purple firework? In a Halo show?<br>The plan is signed 'B.' …Never heard of a B. | 보라색 불꽃 하나? Halo 쇼에?<br>계획서에는 'B.'라고 서명돼 있다. …B라는 사람은 처음 들어 봐. | 목표 4 대화창 3쪽 — 모두에게 · `Steps.4.Lines.All.3` |
| So what do we tell everyone? | 그래서 다들 뭐라고 말해 줄까요? | 목표 4 대화창 4쪽 — 모두에게 · `Steps.4.Lines.All.4` |
| Tell everyone the truth | 모두에게 사실대로 말하기 | 목표 4 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.4.Obj.Good.Label` |
| Keep the rumor going. It's more fun! | 소문을 계속 퍼뜨리기. 그게 더 재밌어! | 목표 4 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.4.Obj.Evil.Label` |
| Rose: So who started the rumor? …Does anyone remember? | Rose: 그래서 누가 소문을 낸 거야? …기억하는 사람 있어? | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |
| Rose's wristband: gold and purple. Where have you seen one? | Rose의 손목밴드: 금색과 보라색. 어디서 본 적 있지? | **[숨김]** 단서 알림 (A23-130부터 안 보냄) · `Clue` |

#### N3 · Both Sides Are Suspicious (양쪽 다 수상해요)
- 종류: 마을 사이드 (모두)
- 주는 사람: Tiny (교차로)
- 열리는 때: M2_3 뒤
- 보상: 골드 120 + 경험치(현재 레벨 막대의 절반) — 완료하면 "<이름> done! +골드 · +XP" 알림
- 선택 보상: 왼쪽(착한 쪽) = 강화 주문서 70% 1장 · 오른쪽(장난 쪽) = HP 물약 3개 + 골드 220. 점수 1점 (자기 진영 점수는 오르고, 반대쪽 고르면 자기 점수가 깎임, A23-58)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Both Sides Are Suspicious | 양쪽 다 수상해요 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Spy on both | 양쪽 염탐 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Tiny from the guild is taking notes. Find Tiny at the Crossroads! | 길드의 Tiny가 메모하고 있어요. Crossroads에서 Tiny를 찾아보세요! | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Talk to Tiny at the Crossroads | Crossroads의 Tiny와 이야기하기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| Halos blame Horns. Horns blame Halos.<br>Noted: nobody saw it. | Halo는 Horns 탓을 하고, Horns는 Halo 탓을 해요.<br>메모: 아무도 못 봤음. | 목표 1 대화창 1쪽 — 모두에게 · `Steps.1.Lines.All.1` |
| Can you watch both bridges for me? Quietly. | 양쪽 다리를 조용히 지켜봐 줄래요? | 목표 1 대화창 2쪽 — 모두에게 · `Steps.1.Lines.All.2` |
| Watch the Halo bridge | Halo 쪽 다리 지켜보기 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| Watch the Horns bridge | Horns 쪽 다리 지켜보기 | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` |
| Hunting gold for the guild %d/%d | 길드를 위한 사냥 골드 %d/%d | 목표 4 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.4.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Show Tiny your notes | Tiny에게 내 메모 보여 주기 | 목표 5 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.5.Text` |
| Both sides buy spy glasses. To spy on each other. From us. | 양쪽이 다 망원경을 사요. 서로 염탐하려고. 우리한테서. | 목표 5 대화창 1쪽 — 모두에게 · `Steps.5.Lines.All.1` |
| Suspicious: two kids. Bench behind the fountain. Every evening.<br>Their halo and horns are tiny. Smaller than anyone's. | 수상함: 아이 둘. 분수 뒤 벤치. 매일 저녁.<br>둘의 후광과 뿔은 아주 작다. 누구 것보다도 작다. | 목표 5 대화창 2쪽 — 모두에게 · `Steps.5.Lines.All.2` |
| Noted. …Is selling to both sides a side too? | 메모했어. …양쪽에 파는 것도 한 편일까? | 목표 5 대화창 3쪽 — 모두에게 · `Steps.5.Lines.All.3` |
| Send both sides a peace letter | 양쪽에 평화 편지 보내기 | 목표 5 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.5.Obj.Good.Label` |
| Sell more spy glasses to both! | 양쪽에 망원경 더 팔기! | 목표 5 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.5.Obj.Evil.Label` |
| Send both sides a peace letter | 양쪽에 평화 편지 보내기 | 목표 5 선택 버튼 — 길드(Neutral)용 왼쪽 A · `Steps.5.Obj.Neutral.A` |
| Sell more spy glasses to both! | 양쪽에 망원경 더 팔기! | 목표 5 선택 버튼 — 길드(Neutral)용 오른쪽 B · `Steps.5.Obj.Neutral.B` |
| Tiny: Noted. Suspicious: everyone. …So who started it? | Tiny: 메모했어. 수상한 사람: 전부. …그래서 누가 시작했지? | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

#### H2 · The Missing Halo Lantern (사라진 Halo 등불)
- 종류: 마을 사이드 (Halo 전용)
- 주는 사람: Bright
- 열리는 때: M1_4 뒤, Lv8부터
- 보상: 골드 120 + 경험치(현재 레벨 막대의 절반) — 완료하면 "<이름> done! +골드 · +XP" 알림
- 선택 보상: 왼쪽(착한 쪽) = 강화 주문서 70% 1장 · 오른쪽(장난 쪽) = HP 물약 3개 + 골드 220. 점수 1점 (자기 진영 점수는 오르고, 반대쪽 고르면 자기 점수가 깎임, A23-58)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| The Missing Halo Lantern | 사라진 Halo 등불 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Lost lantern | 잃어버린 등불 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Bright: The town lantern is gone! Did a slime eat it? | Bright: 마을 등불이 없어졌어요! 슬라임이 먹었나? | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Look around the fountain | 분수 주변 살펴보기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| Slimes %d/%d | 슬라임 잡기 %d/%d | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Glowing jelly tracks lead to the meadow! | 반짝이는 젤리 자국이 초원으로 이어져요! | **[숨김]** 목표 2 시작 알림 · `Steps.2.Start` |
| Bring the lantern home | 등불을 집으로 가져가기 | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` |
| The lantern! Take it home to Halo Citadel. | 등불이다! Halo Citadel로 가져가자. | **[숨김]** 목표 3 시작 알림 · `Steps.3.Start` |
| The lantern is back! | 등불이 돌아왔어요! | 목표 4 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.4.Text` |
| Found it! Still warm. Still glowing. | 찾았다! 아직 따뜻해. 아직 빛나. | 목표 4 대화창 1쪽 — 모두에게 · `Steps.4.Lines.All.1` |
| Inside the lamp: a tiny 'B.' scratched in.<br>Whose is it now? | 등불 안쪽에 작게 'B.'라고 긁어 새겨져 있다.<br>이제 누구 거지? | 목표 4 대화창 2쪽 — 모두에게 · `Steps.4.Lines.All.2` |
| Give it back to the town | 마을에 돌려주기 | 목표 4 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.4.Obj.Good.Label` |
| Hang it in my house | 내 집에 걸어 두기 | 목표 4 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.4.Obj.Evil.Label` |
| Bright: Who was the first to carry it, I wonder? | Bright: 맨 처음 이걸 든 사람이 누구였을까요? | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

#### R5 · Rose's Hat Problem (Rose의 모자 문제)
- 종류: 마을 사이드 (Horns 전용)
- 주는 사람: Rose
- 열리는 때: M1_4 뒤, Lv8부터
- 보상: 골드 120 + 경험치(현재 레벨 막대의 절반) — 완료하면 "<이름> done! +골드 · +XP" 알림
- 선택 보상: 왼쪽(착한 쪽) = 강화 주문서 70% 1장 · 오른쪽(장난 쪽) = HP 물약 3개 + 골드 220. 점수 1점 (자기 진영 점수는 오르고, 반대쪽 고르면 자기 점수가 깎임, A23-58)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Rose's Hat Problem | Rose의 모자 문제 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Rose's hat | Rose의 모자 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Rose: A Slime Prince is wearing my sack as a crown! | Rose: Slime Prince가 내 자루를 왕관처럼 쓰고 있어! | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Find the slime by the pond | 연못 옆 슬라임 찾기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| Slime Prince %d/%d | Slime Prince 잡기 %d/%d | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` · %d/%d = 지금 숫자/목표 숫자 |
| The sack is free! | 자루가 풀려났다! | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` |
| A sack! A bit slimy. Rose's name is on it. | 자루다! 좀 끈적해. Rose의 이름이 적혀 있다. | 목표 3 대화창 1쪽 — 모두에게 · `Steps.3.Lines.All.1` |
| So whose sack is it now? | 그럼 이 자루는 이제 누구 거지? | 목표 3 대화창 2쪽 — 모두에게 · `Steps.3.Lines.All.2` |
| Give it back to Rose | Rose에게 돌려주기 | 목표 3 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.3.Obj.Good.Label` |
| Finders keepers! | 줍는 놈이 임자! | 목표 3 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.3.Obj.Evil.Label` |
| Rose: Did the slime look good in it, at least? | Rose: 그래서 그 슬라임, 쓰니까 멋있긴 했어? | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

#### H3 · Day 40: Cat in Tree (40일째: 나무 위의 고양이)
- 종류: 마을 사이드 (Halo 전용)
- 주는 사람: Sir Gleam (기사, 빛의 성채)
- 열리는 때: M2_7 뒤, Lv12부터
- 보상: 골드·경험치 각각 사냥 2분어치 — 완료 알림 "<이름> done! +골드 · +XP"
- 선택 보상: 왼쪽(착한 쪽) = 강화 주문서 70% 1장 · 오른쪽(장난 쪽) = HP 물약 3개 + 골드 220. 점수 1점 (자기 진영 점수는 오르고, 반대쪽 고르면 자기 점수가 깎임, A23-58)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Day 40: Cat in Tree | 40일째: 나무 위의 고양이 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Cat in a tree | 나무 위 고양이 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Sir Gleam needs help in Halo Citadel! | Sir Gleam(글림 경)이 Halo Citadel에서 도움이 필요해요! | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Talk to Sir Gleam | Sir Gleam과 이야기하기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| Sir Gleam: Day 40: Cat in tree. Again! | Sir Gleam: 40일째: 나무 위의 고양이. 또! | 목표 1 대화창 1쪽 — 모두에게 · `Steps.1.Lines.All.1` |
| Sir Gleam: Each rescue is a heart. 10,001 hearts!<br>Clear the slimes so I can reach it. | Sir Gleam: 구조 한 번이 하트 하나. 10,001개의 하트!<br>슬라임을 치워 줘, 내가 닿을 수 있게. | 목표 1 대화창 2쪽 — 모두에게 · `Steps.1.Lines.All.2` |
| Slimes %d/%d | 슬라임 잡기 %d/%d | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Back to Sir Gleam | Sir Gleam에게 돌아가기 | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` |
| Talk with Sir Gleam | Sir Gleam과 이야기하기 | 목표 4 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.4.Text` |
| Sir Gleam: The cat is down! …It is already climbing again. | Sir Gleam: 고양이가 내려왔다! …벌써 다시 올라가고 있네. | 목표 4 대화창 1쪽 — 모두에게 · `Steps.4.Lines.All.1` |
| Sir Gleam: What should we do? | Sir Gleam: 어떻게 해야 할까? | 목표 4 대화창 2쪽 — 모두에게 · `Steps.4.Lines.All.2` |
| Let the cat be. Help someone new. | 고양이는 그냥 두고, 새로 온 사람을 도와주기 | 목표 4 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.4.Obj.Good.Label` |
| Put it back up. More hearts! | 다시 올려놓기. 하트가 더 많이! | 목표 4 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.4.Obj.Evil.Label` |
| Sir Gleam: Is it still helping if you do it for the hearts? | Sir Gleam: 하트 때문에 하는 거라면 그래도 돕는 걸까? | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

#### R3 · Prank #200 (장난 #200)
- 종류: 마을 사이드 (Horns 전용)
- 주는 사람: Rascal Rex (뿔 소굴)
- 열리는 때: M2_7 뒤, Lv12부터
- 보상: 골드·경험치 각각 사냥 2분어치 — 완료 알림 "<이름> done! +골드 · +XP"
- 선택 보상: 왼쪽(착한 쪽) = 강화 주문서 70% 1장 · 오른쪽(장난 쪽) = HP 물약 3개 + 골드 220. 점수 1점 (자기 진영 점수는 오르고, 반대쪽 고르면 자기 점수가 깎임, A23-58)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Prank #200 | 장난 #200 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Prank #200 | 장난 #200 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Talk to Rascal Rex | Rascal Rex(래스칼 렉스)와 이야기하기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| Rascal Rex: Prank number 200! Same as 199? | Rascal Rex: 장난 200번째! 199번째랑 똑같은 거야? | 목표 1 대화창 1쪽 — 모두에게 · `Steps.1.Lines.All.1` |
| Rascal Rex: Pranks cost gold. Go hunt some! | Rascal Rex: 장난에는 골드가 들어. 가서 사냥해! | 목표 1 대화창 2쪽 — 모두에게 · `Steps.1.Lines.All.2` |
| Hunting gold %d/%d | 사냥 골드 %d/%d | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Back to Rascal Rex | Rascal Rex에게 돌아가기 | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` |
| Rascal Rex: The boos are the best part! | Rascal Rex: 야유 소리가 제일 재밌지! | 목표 3 대화창 1쪽 — 모두에게 · `Steps.3.Lines.All.1` |
| Rascal Rex: So. Which prank? | Rascal Rex: 그래서. 어떤 장난? | 목표 3 대화창 2쪽 — 모두에게 · `Steps.3.Lines.All.2` |
| Plan a surprise party instead | 대신 깜짝 파티를 준비하기 | 목표 3 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.3.Obj.Good.Label` |
| Do prank 201. The same one! | 201번째 장난하기. 똑같은 걸로! | 목표 3 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.3.Obj.Evil.Label` |
| Rascal Rex: Classic! …Is classic getting old? | Rascal Rex: 고전이지! …고전도 낡아 가나? | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

#### H5 · Form H-2 (H-2 서식)
- 종류: 마을 사이드 (Halo 전용)
- 주는 사람: Bright
- 열리는 때: M2_7 뒤, Lv15부터
- 보상: 골드·경험치 각각 사냥 2분어치 — 완료 알림 "<이름> done! +골드 · +XP"
- 선택 보상: 왼쪽(착한 쪽) = 강화 주문서 70% 1장 · 오른쪽(장난 쪽) = HP 물약 3개 + 골드 220. 점수 1점 (자기 진영 점수는 오르고, 반대쪽 고르면 자기 점수가 깎임, A23-58)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Form H-2 | H-2 서식 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` · ⚠ 영어 고칠 만함: 'Form'(서식)이 무슨 뜻인지 제목만 보면 알기 어려움 (Bright의 서류 농담) |
| Form H-2 | H-2 서식 | 폰 화면용 짧은 줄 이름 · `ShortName` · ⚠ 영어 고칠 만함: 'Form'(서식)이 무슨 뜻인지 제목만 보면 알기 어려움 (Bright의 서류 농담) |
| Bright needs a form signed. Find her in Halo Citadel! | Bright가 서명받을 서식이 필요해요. Halo Citadel에서 찾아보세요! | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Talk to Bright | Bright와 이야기하기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| Bright: I need Form H-2 to fight a Brute. | Bright: Brute와 싸우려면 H-2 서식이 필요해요. | 목표 1 대화창 1쪽 — 모두에게 · `Steps.1.Lines.All.1` |
| Bright: Who made these forms?! …Oh. Us. | Bright: 이 서식은 누가 만든 거야?! …아. 우리구나. | 목표 1 대화창 2쪽 — 모두에게 · `Steps.1.Lines.All.2` |
| Goblin Brute %d/%d | Goblin Brute 잡기 %d/%d | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Tell Bright | Bright에게 알리기 | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` |
| Bright: You beat it! Without a form! | Bright: 해냈네요! 서식도 없이! | 목표 3 대화창 1쪽 — 모두에게 · `Steps.3.Lines.All.1` |
| Bright: So… what about the forms? | Bright: 그럼… 서식은 어떻게 할까요? | 목표 3 대화창 2쪽 — 모두에게 · `Steps.3.Lines.All.2` |
| Skip the form. Just help! | 서식은 건너뛰고 그냥 돕기! | 목표 3 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.3.Obj.Good.Label` |
| Fill in three more forms | 서식을 세 장 더 쓰기 | 목표 3 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.3.Obj.Evil.Label` |
| Bright: Do rules help, or do people help? | Bright: 규칙이 도움이 될까요, 사람이 도움이 될까요? | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

#### R6 · Plan B, Again (계획 B, 또)
- 종류: 마을 사이드 (Horns 전용)
- 주는 사람: Rose
- 열리는 때: M2_7 뒤, Lv15부터
- 보상: 골드·경험치 각각 사냥 2분어치 — 완료 알림 "<이름> done! +골드 · +XP"
- 선택 보상: 왼쪽(착한 쪽) = 강화 주문서 70% 1장 · 오른쪽(장난 쪽) = HP 물약 3개 + 골드 220. 점수 1점 (자기 진영 점수는 오르고, 반대쪽 고르면 자기 점수가 깎임, A23-58)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Plan B, Again | 계획 B, 또 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Plan B | 계획 B | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Talk to Rose | Rose와 이야기하기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| Rose: Plan B failed. Time for… Plan B? | Rose: 계획 B가 실패했어. 이제… 계획 B? | 목표 1 대화창 1쪽 — 모두에게 · `Steps.1.Lines.All.1` |
| Rose: Plans cost gold. Lots of it. | Rose: 계획에는 골드가 들어. 아주 많이. | 목표 1 대화창 2쪽 — 모두에게 · `Steps.1.Lines.All.2` |
| Hunting gold %d/%d | 사냥 골드 %d/%d | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Back to Rose | Rose에게 돌아가기 | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` |
| Rose: Gold! Now, the plan… | Rose: 골드다! 자, 계획은… | 목표 3 대화창 1쪽 — 모두에게 · `Steps.3.Lines.All.1` |
| Rose: Which plan? | Rose: 어떤 계획? | 목표 3 대화창 2쪽 — 모두에게 · `Steps.3.Lines.All.2` |
| Try a brand-new plan | 완전히 새로운 계획 세우기 | 목표 3 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.3.Obj.Good.Label` |
| Plan B again, but LOUDER | 계획 B를 또, 이번엔 더 시끄럽게 | 목표 3 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.3.Obj.Evil.Label` |
| Rose: What if a plan needs two people? | Rose: 계획이 두 사람이 필요하면 어쩌지? | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

#### H6 · Dusty Heroes (먼지 쌓인 영웅들)
- 종류: 마을 사이드 (Halo 전용)
- 주는 사람: Bright
- 열리는 때: M2_7 뒤, Lv22부터
- 보상: 골드·경험치 각각 사냥 2분어치 — 완료 알림 "<이름> done! +골드 · +XP"
- 선택 보상: 왼쪽(착한 쪽) = 강화 주문서 70% 1장 · 오른쪽(장난 쪽) = HP 물약 3개 + 골드 220. 점수 1점 (자기 진영 점수는 오르고, 반대쪽 고르면 자기 점수가 깎임, A23-58)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Dusty Heroes | 먼지 쌓인 영웅들 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Dusty heroes | 먼지 쌓인 영웅 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Bright: The hero statues are dusty. Who were they, really? | Bright: 영웅 동상이 먼지투성이예요. 이 영웅들은 정말 누구였을까요? | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Look at the hero statues in Halo Citadel %d/%d s | Halo Citadel의 영웅 동상 바라보기 %d/%d초 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Goblins %d/%d | 고블린 %d/%d | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Back to the statues | 동상으로 돌아가기 | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` |
| The statues shine again! | 동상이 다시 반짝여요! | 목표 4 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.4.Text` |
| Bright: The statues are shiny again! | Bright: 동상이 다시 반짝반짝해요! | 목표 4 대화창 1쪽 — 모두에게 · `Steps.4.Lines.All.1` |
| Bright: What should the road show next? | Bright: 이 길에 다음엔 뭘 세울까요? | 목표 4 대화창 2쪽 — 모두에게 · `Steps.4.Lines.All.2` |
| Add a statue of a sprout too | 새싹 동상도 하나 더 세우기 | 목표 4 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.4.Obj.Good.Label` |
| Make OUR statue bigger | 우리 동상을 더 크게 만들기 | 목표 4 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.4.Obj.Evil.Label` |
| Bright: Who is a hero? Only the big ones? | Bright: 누가 영웅일까요? 큰 사람만? | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

#### R7 · Lava Party (용암 파티)
- 종류: 마을 사이드 (Horns 전용)
- 주는 사람: Rose
- 열리는 때: M2_7 뒤, Lv22부터
- 보상: 골드·경험치 각각 사냥 2분어치 — 완료 알림 "<이름> done! +골드 · +XP"
- 선택 보상: 왼쪽(착한 쪽) = 강화 주문서 70% 1장 · 오른쪽(장난 쪽) = HP 물약 3개 + 골드 220. 점수 1점 (자기 진영 점수는 오르고, 반대쪽 고르면 자기 점수가 깎임, A23-58)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Lava Party | 용암 파티 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Lava party | 용암 파티 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Rose: Party at the lava cracks! Bring snacks… or gold. | Rose: 용암 갈라진 틈에서 파티야! 간식을 가져와… 아니면 골드. | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Warm up at the lava %d/%d s | 용암 옆에서 몸 녹이기 %d/%d초 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Hunting gold %d/%d | 사냥 골드 %d/%d | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Party time | 파티 시간 | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` |
| Rose: Snacks! Gold! Music! | Rose: 간식! 골드! 음악! | 목표 3 대화창 1쪽 — 모두에게 · `Steps.3.Lines.All.1` |
| Rose: Who gets in? | Rose: 누가 들어올 수 있게 할까? | 목표 3 대화창 2쪽 — 모두에게 · `Steps.3.Lines.All.2` |
| Invite the whole den | 소굴 모두를 초대하기 | 목표 3 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.3.Obj.Good.Label` |
| VIP only. Just us! | VIP만. 우리끼리만! | 목표 3 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.3.Obj.Evil.Label` |
| Rose: Is a party better big, or just right? | Rose: 파티는 큰 게 좋을까, 딱 맞는 게 좋을까? | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

### 4-4 고블린 숲과 졸업 사이드 (Lv10~25)

#### WB1 · The Dropped Lantern (떨어뜨린 등불)
- 종류: 숲 사이드 (카드 한 번)
- 주는 사람: (없음)
- 열리는 때: M1_4 뒤, Lv10부터 숲 다리에 처음 서면
- 보상: 착한 쪽 = 강화 주문서 70% 1장 · 장난 쪽 = HP 물약 3개 + 골드 192. 점수 1점

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| The Dropped Lantern | 떨어뜨린 등불 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Bridge lamp | 다리 등불 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| A light flickers on the woods bridge… | 숲 다리 위에 불빛이 깜빡여요… | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Step onto the woods bridge | 숲 다리에 올라서기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| Pick up the lantern? | 등불을 주울까? | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| A goblin dropped his lantern on the bridge. It is still warm. | 고블린이 다리에 등불을 떨어뜨렸다. 아직 따뜻하다. | 목표 2 대화창 1쪽 — 모두에게 · `Steps.2.Lines.All.1` |
| Hand it back | 돌려주기 | 목표 2 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.2.Obj.Good.Label` |
| Finders keepers! | 줍는 놈이 임자! | 목표 2 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.2.Obj.Evil.Label` |
| Hand it back | 돌려주기 | 목표 2 선택 버튼 — 길드(Neutral)용 왼쪽 A · `Steps.2.Obj.Neutral.A` |
| Finders keepers! | 줍는 놈이 임자! | 목표 2 선택 버튼 — 길드(Neutral)용 오른쪽 B · `Steps.2.Obj.Neutral.B` |
| The woods feel a little less dark. | 숲이 조금 덜 어두워졌다. | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

#### GW2 · The Dark Path (어두운 길)
- 종류: 숲 사이드
- 주는 사람: (없음)
- 열리는 때: M2_7 뒤, Lv11부터
- 보상: 골드·경험치 각각 사냥 2분어치 — 완료 알림 "<이름> done! +골드 · +XP"
- 선택 보상: 왼쪽(착한 쪽) = 강화 주문서 70% 1장 · 오른쪽(장난 쪽) = HP 물약 3개 + 골드 220. 점수 1점 (자기 진영 점수는 오르고, 반대쪽 고르면 자기 점수가 깎임, A23-58)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| The Dark Path | 어두운 길 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Dark path | 어두운 길 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| The woods path has no light. Kids won't walk it in the dark. | 숲길에는 불빛이 없어요. 아이들은 어두운 길을 안 걸어요. | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Watch the woods path %d/%d s | 숲길 지켜보기 %d/%d초 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Goblins by the woods arrival %d/%d | 숲 도착지 근처 고블린 %d/%d | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` · %d/%d = 지금 숫자/목표 숫자 |
| What will you put up? | 무엇을 세울까요? | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` |
| The path is clear for now. | 지금은 길이 깨끗해요. | 목표 3 대화창 1쪽 — 모두에게 · `Steps.3.Lines.All.1` |
| What will you put up by the path? | 길가에 무엇을 세울까요? | 목표 3 대화창 2쪽 — 모두에게 · `Steps.3.Lines.All.2` |
| Put up a lamp for everyone | 모두를 위한 등불 세우기 | 목표 3 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.3.Obj.Good.Label` |
| Put up a KEEP OUT sign | '출입 금지' 팻말 세우기 | 목표 3 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.3.Obj.Evil.Label` |
| Put up a lamp for everyone | 모두를 위한 등불 세우기 | 목표 3 선택 버튼 — 길드(Neutral)용 왼쪽 A · `Steps.3.Obj.Neutral.A` |
| Put up a KEEP OUT sign | '출입 금지' 팻말 세우기 | 목표 3 선택 버튼 — 길드(Neutral)용 오른쪽 B · `Steps.3.Obj.Neutral.B` |
| Who will walk this path tomorrow? | 내일은 누가 이 길을 걸을까? | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

#### GW1 · Grab Club Meeting (Grab Club 모임)
- 종류: 숲 사이드
- 주는 사람: Grabbo (고블린 모임 대장)
- 열리는 때: M2_7 뒤, Lv12부터
- 보상: 골드·경험치 각각 사냥 2분어치 — 완료 알림 "<이름> done! +골드 · +XP"
- 선택 보상: 왼쪽(착한 쪽) = 강화 주문서 70% 1장 · 오른쪽(장난 쪽) = HP 물약 3개 + 골드 220. 점수 1점 (자기 진영 점수는 오르고, 반대쪽 고르면 자기 점수가 깎임, A23-58)
- 참고: 마지막 목표 'Grabbo의 대답'은 방금 고른 선택에 따라 다릅니다 (LinesBy).

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Grab Club Meeting | Grab Club 모임 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Grab Club | Grab Club | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Find the goblin camp meeting | 고블린 야영지 모임 찾기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| Grab Club, meeting #47 | Grab Club, 모임 #47 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| Grabbo: Welcome to Grab Club! This is meeting number 47. | Grabbo(그래보): Grab Club에 온 걸 환영해! 이번이 47번째 모임이야. | 목표 2 대화창 1쪽 — 모두에게 · `Steps.2.Lines.All.1` |
| Grabbo: Last week we grabbed 100 dust. This week's goal: MORE. | Grabbo: 지난주엔 가루 100개를 빼앗았어. 이번 주 목표: 더 많이. | 목표 2 대화창 2쪽 — 모두에게 · `Steps.2.Lines.All.2` |
| Pip: Um, boss? Why do we grab?<br>Grabbo: Because we grabbed last week! Next meeting: right now. | Pip: 저기, 대장? 우리 왜 빼앗는 거예요?<br>Grabbo: 지난주에 빼앗았으니까! 다음 모임: 지금 당장. | 목표 2 대화창 3쪽 — 모두에게 · `Steps.2.Lines.All.3` |
| Give the dust back | 가루를 돌려주기 | 목표 2 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.2.Obj.Good.Label` |
| Grab MORE dust! | 가루를 더 빼앗기! | 목표 2 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.2.Obj.Evil.Label` |
| Give the dust back | 가루를 돌려주기 | 목표 2 선택 버튼 — 길드(Neutral)용 왼쪽 A · `Steps.2.Obj.Neutral.A` |
| Grab MORE dust! | 가루를 더 빼앗기! | 목표 2 선택 버튼 — 길드(Neutral)용 오른쪽 B · `Steps.2.Obj.Neutral.B` |
| Grabbo's answer | Grabbo의 대답 | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` |
| Grabbo: Hmm. Noted! | Grabbo: 흠. 메모했어! | 목표 3 대화창 1쪽 — 모두에게 · `Steps.3.Lines.All.1` |
| Grabbo: Give it… back? Write that down! A new idea! | Grabbo: 돌려…준다고? 적어 둬! 새로운 생각이야! | 목표 3 대화창 1쪽 — 앞선 선택이 착한 쪽이었을 때 (이 퀘스트 자신의 선택에 따라), 모두에게 · `Steps.3.LinesBy.Good.All.1` |
| Grabbo: Same plan, but MORE! Meeting 48 starts now! | Grabbo: 똑같은 계획인데 더 많이! 48번째 모임을 지금 시작한다! | 목표 3 대화창 1쪽 — 앞선 선택이 장난(악) 쪽이었을 때 (이 퀘스트 자신의 선택에 따라), 모두에게 · `Steps.3.LinesBy.Evil.All.1` |
| Grabbo: Hmm. Noted! | Grabbo: 흠. 메모했어! | 목표 3 대화창 1쪽 — 선택 기록이 없을 때(기본) (이 퀘스트 자신의 선택에 따라), 모두에게 · `Steps.3.LinesBy.Default.All.1` |
| Grabbo: What were we grabbing for again? | Grabbo: 근데 우리 뭘 위해 빼앗고 있었지? | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

#### GW3 · Gold Paint (금색 페인트)
- 종류: 숲 사이드
- 주는 사람: (없음, 금칠한 고블린)
- 열리는 때: M2_7 뒤, Lv14부터
- 보상: 골드·경험치 각각 사냥 2분어치 — 완료 알림 "<이름> done! +골드 · +XP"
- 선택 보상: 왼쪽(착한 쪽) = 강화 주문서 70% 1장 · 오른쪽(장난 쪽) = HP 물약 3개 + 골드 220. 점수 1점 (자기 진영 점수는 오르고, 반대쪽 고르면 자기 점수가 깎임, A23-58)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Gold Paint | 금색 페인트 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Gold paint | 금색 페인트 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| A goblin painted himself gold to look rich! | 고블린이 부자처럼 보이려고 온몸을 금색으로 칠했다! | **[숨김]** 퀘스트 시작 알림 · `Start` |
| A golden monster in the woods %d/%d | 숲의 황금 몬스터 %d/%d | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d/%d = 지금 숫자/목표 숫자 |
| The gold goblin | 금색 고블린 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| Goblin: Don't tell! The gold comes off in the rain. | Goblin: 말하지 마! 금색은 비 오면 벗겨져. | 목표 2 대화창 1쪽 — 모두에게 · `Steps.2.Lines.All.1` |
| Goblin: Do I look rich? Be honest. | Goblin: 나 부자처럼 보여? 솔직히 말해 줘. | 목표 2 대화창 2쪽 — 모두에게 · `Steps.2.Lines.All.2` |
| Tell him he's fine as he is | 그대로도 괜찮다고 말해 주기 | 목표 2 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.2.Obj.Good.Label` |
| Sell him more gold paint | 금색 페인트를 더 팔기 | 목표 2 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.2.Obj.Evil.Label` |
| Tell him he's fine as he is | 그대로도 괜찮다고 말해 주기 | 목표 2 선택 버튼 — 길드(Neutral)용 왼쪽 A · `Steps.2.Obj.Neutral.A` |
| Sell him more gold paint | 금색 페인트를 더 팔기 | 목표 2 선택 버튼 — 길드(Neutral)용 오른쪽 B · `Steps.2.Obj.Neutral.B` |
| Does gold paint make anyone rich? | 금색 페인트가 누군가를 부자로 만들까? | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

#### M3_5 · Sprout Graduation (새싹 졸업)
- 종류: 사이드 (졸업)
- 주는 사람: 내 진영 안내자
- 열리는 때: M3_4 뒤
- 보상: 골드(사냥 1분어치) — 완료 알림 "<이름> done! +골드"

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Sprout Graduation | 새싹 졸업 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Graduation | 졸업 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Sprout Shield on · ends at Lv15 + 1 hour of play | Sprout Shield 켜짐 · Lv15 + 1시간 플레이하면 끝남 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| Talk with the Guide | 안내자와 이야기하기 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| No more Sprout Shield. Now you can catch Wanted villains! | 이제 Sprout Shield는 없어요. 이제 Wanted 악당을 잡을 수 있어요! | 목표 2 대화창 1쪽 — Halo(빛) 쪽 플레이어에게만 · `Steps.2.Lines.Halo.1` |
| When the crown broke, I was lost. A stranger gave me their lamp.<br>I never knew their name. So now I give mine. | 왕관이 깨졌을 때 나는 길을 잃었어요. 낯선 사람이 자기 등불을 줬죠.<br>이름도 모르는 사람이에요. 그래서 이제 내가 내 이름을 줘요. | 목표 2 대화창 2쪽 — Halo(빛) 쪽 플레이어에게만 · `Steps.2.Lines.Halo.2` |
| And you? Why are you here? | 그럼 당신은요? 왜 여기에 있나요? | 목표 2 대화창 3쪽 — Halo(빛) 쪽 플레이어에게만 · `Steps.2.Lines.Halo.3` |
| No more Sprout Shield. Now you can raid the knights. Hold the sack for 45 seconds! | 이제 Sprout Shield는 없어. 이제 기사들을 털 수 있어. 자루를 45초 동안 지키면 돼! | 목표 2 대화창 1쪽 — Horns(뿔) 쪽 플레이어에게만 · `Steps.2.Lines.Horns.1` |
| When the shards fell, we were too far. We got nothing.<br>So now we never wait. We take first! | 조각이 떨어졌을 때 우린 너무 멀리 있었어. 아무것도 못 얻었지.<br>그래서 이젠 안 기다려. 먼저 빼앗아! | 목표 2 대화창 2쪽 — Horns(뿔) 쪽 플레이어에게만 · `Steps.2.Lines.Horns.2` |
| And you? Why are you here? | 그럼 당신은요? 왜 여기에 있나요? | 목표 2 대화창 3쪽 — Horns(뿔) 쪽 플레이어에게만 · `Steps.2.Lines.Horns.3` |
| The Guild is still safe, shield or not. | 길드는 보호막이 있든 없든 계속 안전해요. | 목표 2 대화창 1쪽 — Artisan Guild(길드) 쪽에게만 · `Steps.2.Lines.Neutral.1` |
| Both sides break things. We fix them. For both.<br>…Is fixing for both sides a side too? | 양쪽 다 물건을 부숴요. 우리는 고쳐요. 양쪽 모두를 위해.<br>…양쪽 모두를 위해 고치는 것도 한 편일까? | 목표 2 대화창 2쪽 — Artisan Guild(길드) 쪽에게만 · `Steps.2.Lines.Neutral.2` |
| And you? Why are you here? | 그럼 당신은요? 왜 여기에 있나요? | 목표 2 대화창 3쪽 — Artisan Guild(길드) 쪽에게만 · `Steps.2.Lines.Neutral.3` |

#### Pip1 · Pip's Lamp (Pip의 등불)
- 종류: 숲 사이드
- 주는 사람: Pip (작은 고블린)
- 열리는 때: M3_4에서 '착한 쪽'을 골랐고 Lv15가 되면
- 보상: 강화 주문서 70% 1장

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Pip's Lamp | Pip의 등불 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Pip's lamp | Pip의 등불 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Someone small is waving at the woods' edge… | 작은 누군가가 숲 입구에서 손을 흔들어요… | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Go to the woods' edge | 숲 입구로 가기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| Talk to Pip | Pip와 이야기하기 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| Pip: Look! My own lamp! It glows purple. I never knew purple! | Pip: 봐요! 내 진짜 등불이에요! 보라색으로 빛나요. 보라색이 이렇게 예쁜 줄 몰랐어요! | 목표 2 대화창 1쪽 — 모두에게 · `Steps.2.Lines.All.1` |

#### OathH · The Sprout Promise (새싹의 약속)
- 종류: 마을 사이드 (Halo 전용, 새싹 약속)
- 주는 사람: Bright
- 열리는 때: M3_4 뒤, Lv15부터
- 보상: 골드·경험치 각각 사냥 2분어치 — 완료 알림 "<이름> done! +골드 · +XP" + 칭호(착한 쪽 = Guardian Cadet, 장난 쪽 = Rascal Cadet). 선택 점수 2점

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| The Sprout Promise | 새싹의 약속 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Sprout promise | 새싹 약속 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Bright has one more lesson for you. | Bright가 알려 줄 게 하나 더 있어요. | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Talk to Bright in Halo Citadel | Halo Citadel에서 Bright와 이야기하기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| Bright: A real Halo guard catches Wanted villains! | Bright: 진짜 Halo 경비는 Wanted 악당을 잡아요! | 목표 1 대화창 1쪽 — 모두에게 · `Steps.1.Lines.All.1` |
| Bright: First, guard the woods bridge. Then face a Goblin Brute! | Bright: 먼저 숲 다리를 지키세요. 그다음 Goblin Brute와 맞서세요! | 목표 1 대화창 2쪽 — 모두에게 · `Steps.1.Lines.All.2` |
| Guard the woods bridge %d/%d s | 숲 다리 지키기 %d/%d초 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Goblin Brute %d/%d | Goblin Brute 잡기 %d/%d | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Make your promise to Bright | Bright에게 약속하기 | 목표 4 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.4.Text` |
| Bright: You did it! Make your promise. What kind of Halo are you? | Bright: 해냈네요! 약속을 해 봐요. 당신은 어떤 Halo인가요? | 목표 4 대화창 1쪽 — 모두에게 · `Steps.4.Lines.All.1` |
| I'll guard the small ones | 작은 아이들을 지킬래요 | 목표 4 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.4.Obj.Good.Label` |
| Rascals bow to no one! | 말썽꾸러기는 아무에게도 안 숙여! | 목표 4 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.4.Obj.Evil.Label` |
| Promise made! Keep it close, wherever you go. | 약속했어요! 어디를 가든 마음에 간직하세요. | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

#### OathR · The Sprout Promise (새싹의 약속)
- 종류: 마을 사이드 (Horns 전용, 새싹 약속)
- 주는 사람: Rose
- 열리는 때: M3_4 뒤, Lv15부터
- 보상: 골드·경험치 각각 사냥 2분어치 — 완료 알림 "<이름> done! +골드 · +XP" + 칭호(착한 쪽 = Guardian Cadet, 장난 쪽 = Rascal Cadet). 선택 점수 2점

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| The Sprout Promise | 새싹의 약속 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Sprout promise | 새싹 약속 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Rose has one more lesson for you. | Rose가 알려 줄 게 하나 더 있어. | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Talk to Rose in Horns Den | Horns Den의 Rose와 이야기하기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| Rose: A real Horn raids knights in the woods! | Rose: 진짜 Horn은 숲에서 기사들을 털어! | 목표 1 대화창 1쪽 — 모두에게 · `Steps.1.Lines.All.1` |
| Rose: Hold the sack for 45 seconds and it's yours! | Rose: 자루를 45초 동안 쥐고 있으면 네 거야! | 목표 1 대화창 2쪽 — 모두에게 · `Steps.1.Lines.All.2` |
| Rose: Warm up first. Two goblin camps, then punch a Goblin Brute. Basic hits only! | Rose: 먼저 몸풀기. 고블린 야영지 두 곳, 그다음 Goblin Brute를 한 대 쳐. 기본 공격만! | 목표 1 대화창 3쪽 — 모두에게 · `Steps.1.Lines.All.3` |
| Find the first goblin camp | 첫 번째 고블린 야영지 찾기 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| Find the second goblin camp | 두 번째 고블린 야영지 찾기 | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` |
| Basic hits on a Goblin Brute %d/%d | Goblin Brute에게 기본 공격만 %d/%d | 목표 4 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.4.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Make your promise to Rose | Rose에게 약속하기 | 목표 5 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.5.Text` |
| Rose: Not bad, rascal! Make your promise. What kind of Horn are you? | Rose: 나쁘지 않네, 말썽꾸러기! 약속을 해 봐. 너는 어떤 Horn이야? | 목표 5 대화창 1쪽 — 모두에게 · `Steps.5.Lines.All.1` |
| I'll guard the small ones | 작은 아이들을 지킬래요 | 목표 5 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.5.Obj.Good.Label` |
| Rascals bow to no one! | 말썽꾸러기는 아무에게도 안 숙여! | 목표 5 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.5.Obj.Evil.Label` |
| Promise made! Keep it close, wherever you go. | 약속했어요! 어디를 가든 마음에 간직하세요. | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

#### GW6 · Nap Time (낮잠 시간)
- 종류: 숲 사이드
- 주는 사람: (없음, 졸린 우두머리)
- 열리는 때: M2_7 뒤, Lv19부터
- 보상: 골드·경험치 각각 사냥 2분어치 — 완료 알림 "<이름> done! +골드 · +XP"
- 선택 보상: 왼쪽(착한 쪽) = 강화 주문서 70% 1장 · 오른쪽(장난 쪽) = HP 물약 3개 + 골드 220. 점수 1점 (자기 진영 점수는 오르고, 반대쪽 고르면 자기 점수가 깎임, A23-58)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Nap Time | 낮잠 시간 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Nap time | 낮잠 시간 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Beat a Brute and stay above half HP. He wants a nap. | Brute를 쓰러뜨리되 HP를 절반 위로 지키세요. 그는 낮잠을 자고 싶어 해요. | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Goblin Brute above half HP %d/%d | HP 절반 이상으로 Goblin Brute 잡기 %d/%d | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d/%d = 지금 숫자/목표 숫자 |
| The sleepy Brute | 졸린 Brute | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| Brute: Zzz… five more minutes… | Brute: 쿨… 5분만 더… | 목표 2 대화창 1쪽 — 모두에게 · `Steps.2.Lines.All.1` |
| What will you do? | 어떻게 할래? | 목표 2 대화창 2쪽 — 모두에게 · `Steps.2.Lines.All.2` |
| Tuck him in for a nap | 이불 덮어 주고 낮잠 재우기 | 목표 2 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.2.Obj.Good.Label` |
| Draw a mustache on him | 얼굴에 콧수염 그리기 | 목표 2 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.2.Obj.Evil.Label` |
| Tuck him in for a nap | 이불 덮어 주고 낮잠 재우기 | 목표 2 선택 버튼 — 길드(Neutral)용 왼쪽 A · `Steps.2.Obj.Neutral.A` |
| Draw a mustache on him | 얼굴에 콧수염 그리기 | 목표 2 선택 버튼 — 길드(Neutral)용 오른쪽 B · `Steps.2.Obj.Neutral.B` |
| Even Brutes get tired. What makes you tired? | 우두머리도 피곤해요. 당신은 뭐 때문에 피곤해요? | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

#### GW7 · Grab Club, Again (Grab Club, 또)
- 종류: 숲 사이드
- 주는 사람: Grabbo
- 열리는 때: GW1 끝난 뒤, Lv21부터
- 보상: 골드·경험치 각각 사냥 2분어치 — 완료 알림 "<이름> done! +골드 · +XP"
- 선택 보상: 왼쪽(착한 쪽) = 강화 주문서 70% 1장 · 오른쪽(장난 쪽) = HP 물약 3개 + 골드 220. 점수 1점 (자기 진영 점수는 오르고, 반대쪽 고르면 자기 점수가 깎임, A23-58)
- 참고: 목표 2의 대사는 GW1에서 한 선택에 따라 다릅니다 (LinesBy: Good / Evil / Default).

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Grab Club, Again | Grab Club, 또 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Grab Club 2 | Grab Club 2 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Back to the goblin camp | 고블린 야영지로 돌아가기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| Grab Club meets again | Grab Club이 다시 모여요 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| Grabbo: Grab Club meets again. Same topic? | Grabbo: Grab Club이 다시 모였어. 주제는 똑같지? | 목표 2 대화창 1쪽 — 모두에게 · `Steps.2.Lines.All.1` |
| Grabbo: Last time someone said 'give it back'. We wrote it down! | Grabbo: 지난번에 누가 '돌려주자'고 했어. 적어 뒀지! | 목표 2 대화창 1쪽 — 앞선 선택이 착한 쪽이었을 때 (GW1의 선택에 따라), 모두에게 · `Steps.2.LinesBy.Good.All.1` |
| Grabbo: Now help us practice. Gently! | Grabbo: 이제 연습을 도와줘. 살살! | 목표 2 대화창 2쪽 — 앞선 선택이 착한 쪽이었을 때 (GW1의 선택에 따라), 모두에게 · `Steps.2.LinesBy.Good.All.2` |
| Grabbo: Meeting #48! Topic: MORE. Same as always! | Grabbo: 모임 #48! 주제: 더 많이. 늘 하던 대로! | 목표 2 대화창 1쪽 — 앞선 선택이 장난(악) 쪽이었을 때 (GW1의 선택에 따라), 모두에게 · `Steps.2.LinesBy.Evil.All.1` |
| Grabbo: Show us how you grab three at once! | Grabbo: 한 번에 세 마리 빼앗는 법을 보여 줘! | 목표 2 대화창 2쪽 — 앞선 선택이 장난(악) 쪽이었을 때 (GW1의 선택에 따라), 모두에게 · `Steps.2.LinesBy.Evil.All.2` |
| Grabbo: Grab Club meets again. Same topic? | Grabbo: Grab Club이 다시 모였어. 주제는 똑같지? | 목표 2 대화창 1쪽 — 선택 기록이 없을 때(기본) (GW1의 선택에 따라), 모두에게 · `Steps.2.LinesBy.Default.All.1` |
| Grabbo: Show us how you grab three at once! | Grabbo: 한 번에 세 마리 빼앗는 법을 보여 줘! | 목표 2 대화창 2쪽 — 선택 기록이 없을 때(기본) (GW1의 선택에 따라), 모두에게 · `Steps.2.LinesBy.Default.All.2` |
| Hit 3 at once with a skill %d/%d | 스킬로 한 번에 3마리 맞히기 %d/%d | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` · %d/%d = 지금 숫자/목표 숫자 |
| The club votes | 모임이 투표해요 | 목표 4 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.4.Text` |
| Grabbo: Time to vote! | Grabbo: 투표 시간이다! | 목표 4 대화창 1쪽 — 모두에게 · `Steps.4.Lines.All.1` |
| Bring the club a new idea | 모임에 새 아이디어 가져가기 | 목표 4 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.4.Obj.Good.Label` |
| Vote for MORE. Again! | '더 많이'에 또 투표하기! | 목표 4 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.4.Obj.Evil.Label` |
| Bring the club a new idea | 모임에 새 아이디어 가져가기 | 목표 4 선택 버튼 — 길드(Neutral)용 왼쪽 A · `Steps.4.Obj.Neutral.A` |
| Vote for MORE. Again! | '더 많이'에 또 투표하기! | 목표 4 선택 버튼 — 길드(Neutral)용 오른쪽 B · `Steps.4.Obj.Neutral.B` |
| Grabbo: What else can a club do? | Grabbo: 모임이 또 뭘 할 수 있을까? | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

#### GW8 · A Very Full Vault (가득 찬 금고)
- 종류: 숲 사이드
- 주는 사람: (없음)
- 열리는 때: M2_7 뒤, Lv23부터
- 보상: 골드·경험치 각각 사냥 2분어치 — 완료 알림 "<이름> done! +골드 · +XP"
- 선택 보상: 왼쪽(착한 쪽) = 강화 주문서 70% 1장 · 오른쪽(장난 쪽) = HP 물약 3개 + 골드 220. 점수 1점 (자기 진영 점수는 오르고, 반대쪽 고르면 자기 점수가 깎임, A23-58)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| A Very Full Vault | 가득 찬 금고 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Full vault | 가득 찬 금고 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Your vault is SO full. What is all this gold for? | 금고가 너무 가득해요. 이 골드는 다 뭘 위한 거죠? | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Hunting gold %d/%d | 사냥 골드 %d/%d | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Back to your town | 내 마을로 돌아가기 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| Talk about the vault | 금고 이야기하기 | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` |
| So much gold! The vault door barely shuts. | 골드가 이렇게 많다니! 금고 문이 겨우 닫혀요. | 목표 3 대화창 1쪽 — 모두에게 · `Steps.3.Lines.All.1` |
| Is a bigger vault ever big enough? | 더 큰 금고도 충분히 클 때가 있을까요? | 목표 3 대화창 2쪽 — 모두에게 · `Steps.3.Lines.All.2` |
| Give some to the town fund | 마을 기금에 조금 내기 | 목표 3 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.3.Obj.Good.Label` |
| Build a bigger vault | 더 큰 금고 짓기 | 목표 3 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.3.Obj.Evil.Label` |
| Give some to the town fund | 마을 기금에 조금 내기 | 목표 3 선택 버튼 — 길드(Neutral)용 왼쪽 A · `Steps.3.Obj.Neutral.A` |
| Build a bigger vault | 더 큰 금고 짓기 | 목표 3 선택 버튼 — 길드(Neutral)용 오른쪽 B · `Steps.3.Obj.Neutral.B` |
| What is gold for, really? | 골드는 도대체 뭘 위한 걸까요? | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

### 4-5 처음 만날 때 한 줄 설명 퀘스트

#### TS1 · Moving a Plus (플러스 옮기기)
- 종류: 사이드 (처음 만날 때 한 줄)
- 주는 사람: Otto (대장장이)
- 열리는 때: 가방에 Transfer Scroll(옮기기 주문서)이 처음 생겼을 때
- 보상: 골드·경험치 각각 사냥 1분어치

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Moving a Plus | 플러스 옮기기 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` · ⚠ 영어 고칠 만함: 'Plus(+)'가 강화 수치인 줄 아이가 모를 수 있음. 'Moving an Upgrade'처럼 쉬운 말이 나을 수 있음 |
| Move a plus | 플러스 옮기기 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Hear about your Transfer Scroll | 내 Transfer Scroll(옮기기 주문서) 이야기 듣기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| A Transfer Scroll moves a weapon's + to another weapon. | Transfer Scroll은 무기의 +를 다른 무기로 옮겨 줘요. | 목표 1 대화창 1쪽 — 모두에게 · `Steps.1.Lines.All.1` |
| If it fails, the + stays where it was. Only the scroll is used up. | 실패하면 +는 원래 자리에 그대로예요. 주문서만 사라져요. | 목표 1 대화창 2쪽 — 모두에게 · `Steps.1.Lines.All.2` |

#### SG1 · The Grudge Sack (원한 자루)
- 종류: 사이드 (처음 만날 때 한 줄)
- 주는 사람: Notice (안내문)
- 열리는 때: PvP로 골드를 빼앗겨 Grudge Sack(원한 자루)이 처음 생겼을 때
- 보상: 골드·경험치 각각 사냥 1분어치

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| The Grudge Sack | 원한 자루 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Grudge Sack | 원한 자루 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Read about the Grudge Sack | Grudge Sack 읽어 보기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| Gold taken in a PvP fight goes into the thief's Grudge Sack. | PvP 싸움에서 빼앗긴 골드는 도둑의 Grudge Sack에 들어가요. | 목표 1 대화창 1쪽 — 모두에게 · `Steps.1.Lines.All.1` |
| The thief keeps it after 45 seconds in a PvP zone. | 도둑이 PvP 구역에서 45초를 버티면 그 골드는 도둑 것이 돼요. | 목표 1 대화창 2쪽 — 모두에게 · `Steps.1.Lines.All.2` |
| Beat the thief first and the gold goes back to its owner! | 먼저 도둑을 쓰러뜨리면 골드가 주인에게 돌아가요! | 목표 1 대화창 3쪽 — 모두에게 · `Steps.1.Lines.All.3` |

#### SZ1 · The Size Scale (덩치 저울)
- 종류: 사이드 (처음 만날 때 한 줄)
- 주는 사람: Fountain (분수)
- 열리는 때: 내 몸이 커졌을 때(작은 진영이라 덩치 저울이 켜짐)
- 보상: 골드·경험치 각각 사냥 1분어치

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| The Size Scale | 덩치 저울 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Size scale | 덩치 저울 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Hear about the size scale | 덩치 저울 이야기 듣기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| The Fountain weighs both sides. The side with less power grows bigger and stronger! | 분수가 양쪽을 저울질해요. 힘이 약한 쪽은 더 크고 더 강해져요! | 목표 1 대화창 1쪽 — 모두에게 · `Steps.1.Lines.All.1` |
| It grows up to 1.6 times, then shrinks back as the sides even out. | 최대 1.6배까지 커지고, 양쪽이 비슷해지면 다시 줄어들어요. | 목표 1 대화창 2쪽 — 모두에게 · `Steps.1.Lines.All.2` |

### 4-6 숨은 이스터에그 (찾으면 줄이 나타나고 칭호만 줌)

#### EG01 · Terms of Fate (운명의 약관)
- 종류: 숨은 이스터에그
- 주는 사람: Terms of Fate (운명의 약관, 두루마리)
- 열리는 때: M2_3 뒤, 제단 뒤 두루마리 앞에 서면 발견
- 보상: 칭호만 (읽었으면 Actually Read It, 동의했으면 Didn't Read It)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Terms of Fate | 운명의 약관 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Terms of Fate | 운명의 약관 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Read the scroll | 두루마리 읽기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| TERMS OF FATE | 운명의 약관 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| TERMS OF FATE (page 1 of 4,000) | 운명의 약관 (4,000쪽 중 1쪽) | 목표 2 대화창 1쪽 — 모두에게 · `Steps.2.Lines.All.1` |
| Read it all | 전부 읽기 | 목표 2 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.2.Obj.Good.Label` |
| I agree | 동의합니다 | 목표 2 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.2.Obj.Evil.Label` |
| Read it all | 전부 읽기 | 목표 2 선택 버튼 — 길드(Neutral)용 왼쪽 A · `Steps.2.Obj.Neutral.A` |
| I agree | 동의합니다 | 목표 2 선택 버튼 — 길드(Neutral)용 오른쪽 B · `Steps.2.Obj.Neutral.B` |
| The fine print | 깨알 같은 작은 글씨 | 목표 3 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.3.Text` |
| Thanks! You agreed to… something. Not even Fate knows what. | 고마워! 너는 무언가에 동의했어… 무엇인지는 운명도 몰라. | 목표 3 대화창 1쪽 — 모두에게 · `Steps.3.Lines.All.1` |
| Rule 1: No slimes on the altar. Rule 2: See Rule 1. | 규칙 1: 제단에 슬라임 금지. 규칙 2: 규칙 1을 볼 것. | 목표 3 대화창 1쪽 — 앞선 선택이 착한 쪽이었을 때 (이 퀘스트 자신의 선택에 따라), 모두에게 · `Steps.3.LinesBy.Good.All.1` |
| …You're still reading? Nobody reads this far. | …아직도 읽고 있어? 여기까지 읽는 사람은 없는데. | 목표 3 대화창 2쪽 — 앞선 선택이 착한 쪽이었을 때 (이 퀘스트 자신의 선택에 따라), 모두에게 · `Steps.3.LinesBy.Good.All.2` |
| Page 4,000: Be kind. That was the whole thing. | 4,000쪽: 친절하게 지내세요. 그게 전부였어. | 목표 3 대화창 3쪽 — 앞선 선택이 착한 쪽이었을 때 (이 퀘스트 자신의 선택에 따라), 모두에게 · `Steps.3.LinesBy.Good.All.3` |
| Thanks! You agreed to… something. Not even Fate knows what. | 고마워! 너는 무언가에 동의했어… 무엇인지는 운명도 몰라. | 목표 3 대화창 1쪽 — 앞선 선택이 장난(악) 쪽이었을 때 (이 퀘스트 자신의 선택에 따라), 모두에게 · `Steps.3.LinesBy.Evil.All.1` |
| Thanks! You agreed to… something. Not even Fate knows what. | 고마워! 너는 무언가에 동의했어… 무엇인지는 운명도 몰라. | 목표 3 대화창 1쪽 — 선택 기록이 없을 때(기본) (이 퀘스트 자신의 선택에 따라), 모두에게 · `Steps.3.LinesBy.Default.All.1` |

#### EG02 · Patch Note (패치 노트)
- 종류: 숨은 이스터에그
- 주는 사람: Notice (안내문)
- 열리는 때: M2_3 뒤, 현상수배 게시판 앞 쪽지에 다가가면
- 보상: 칭호 Bug Reporter

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Patch Note | 패치 노트 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Patch Note | 패치 노트 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Read the note | 쪽지 읽기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| Patch Note | 패치 노트 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| Patch 0.0.1: The crown is broken. | 패치 0.0.1: 왕관이 부서졌습니다. | 목표 2 대화창 1쪽 — 모두에게 · `Steps.2.Lines.All.1` |
| Known issue. We are looking into it. | 알려진 문제입니다. 확인하고 있습니다. | 목표 2 대화창 2쪽 — 모두에게 · `Steps.2.Lines.All.2` |

#### EG03 · Goose Fan (거위 팬)
- 종류: 숨은 이스터에그
- 주는 사람: Golden Goose (황금 거위)
- 열리는 때: M2_3 뒤, 거위 둥지에 다가가면
- 보상: 칭호 Goose Fan

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Goose Fan | 거위 팬 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Goose Fan | 거위 팬 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Visit the goose | 거위 찾아가기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| Goose Fan | 거위 팬 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| The Golden Goose has 0 followers. She has never been happier. | 황금 거위의 팔로워는 0명. 그래도 이렇게 행복한 적이 없어요. | 목표 2 대화창 1쪽 — 모두에게 · `Steps.2.Lines.All.1` |
| Also, she saw who broke the Crown. Honk. | 그리고 그녀는 누가 Crown을 깼는지 봤어요. 꽥. | 목표 2 대화창 2쪽 — 모두에게 · `Steps.2.Lines.All.2` |

#### EG04 · Sky Watcher (하늘 지킴이)
- 종류: 숨은 이스터에그
- 주는 사람: Crown Shard (조각)
- 열리는 때: M2_3 뒤, 분수 옆에서 30초 하늘 쳐다보면
- 보상: 칭호 Sky Watcher

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Sky Watcher | 하늘 지킴이 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Sky Watcher | 하늘 지킴이 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Look up %d/%d s | 하늘 보기 %d/%d초 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Sky Watcher | 하늘 지킴이 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| Stop staring. I'm broken, not famous. | 그만 쳐다봐. 나는 깨졌을 뿐, 유명한 건 아니야. | 목표 2 대화창 1쪽 — 모두에게 · `Steps.2.Lines.All.1` |

#### EG14 · Bench Detective (벤치 탐정)
- 종류: 숨은 이스터에그
- 주는 사람: Notice (안내문)
- 열리는 때: M2_3 뒤, 교차로 벤치 아래를 보면
- 보상: 칭호 Bench Detective

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Bench Detective | 벤치 탐정 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Bench clue | 벤치 단서 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Look under the bench | 벤치 밑을 보기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| Bench Detective | 벤치 탐정 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| Under the bench: two small handprints in old paint. | 벤치 밑: 오래된 페인트로 찍힌 작은 손바닥 두 개. | 목표 2 대화창 1쪽 — 모두에게 · `Steps.2.Lines.All.1` |
| One gold. One purple. Side by side. | 하나는 금색. 하나는 보라색. 나란히. | 목표 2 대화창 2쪽 — 모두에게 · `Steps.2.Lines.All.2` |

### 4-7 길드(Artisan Guild) 전용 사이드

#### N1 · The Artisan's Touch (장인의 손길) **[꺼짐]**
- 종류: 길드 전용 사이드
- 주는 사람: Kit (길드 안내자)
- 열리는 때: M1_4 뒤, Lv5 (길드 선택이 꺼져 있어 지금은 안 열림)
- 보상: 골드(사냥 1분어치) — 완료 알림 "<이름> done! +골드"

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| The Artisan's Touch | 장인의 손길 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Artisan touch | 장인의 손길 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Kit: Shape with care. Two at once! | Kit: 조심해서 빚어요. 두 개 한꺼번에! | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Hit 2 with one skill %d/%d | 스킬 한 번에 2마리 맞히기 %d/%d | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · ⚠ 영어 고칠 만함: '2 무엇을?'이 빠져 있음 (M2_5와 같은 문제) · %d/%d = 지금 숫자/목표 숫자 |

#### N2 · Guild Supply Book (길드 보급 장부) **[꺼짐]**
- 종류: 길드 전용 사이드
- 주는 사람: Kit
- 열리는 때: M2_1 뒤 (지금은 안 열림)
- 보상: 골드(사냥 1분어치) — 완료 알림 "<이름> done! +골드"

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Guild Supply Book | 길드 보급 장부 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Supply book | 보급 장부 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Kit: Both sides need our gear. Collect supply gold. | Kit: 양쪽 다 우리 장비가 필요해요. 보급 골드를 모아요. | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Supply book %d/2 | 보급 장부 %d/2 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d = 숫자 |
| Go to the Crossroads | Crossroads로 가기 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |

### 4-8 사냥터 일자리 게시판과 작은 선택 카드 (지금 꺼짐)

일자리 게시판(Job Board)과 선택 카드는 코드는 있지만 스위치가 꺼져 있어 지금은 나오지 않습니다 (`Board.Enabled=false`, `LostFound.Enabled=false`, `KillCards.FlowerPatch.Enabled=false`). 목표 글과 알림 글만 모았고, 카드마다 있는 착한/장난 설명 줄 20여 개는 뺐습니다.

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Clear the path · {Unit} %d/%d | 길 치우기 · {Unit} %d/%d | **[꺼짐]** 일자리 목표 글 · `Board.Jobs.1.Goal` · {Unit} = 슬라임/고블린 같은 이름, %d/%d = 진행/목표 |
| By the {Camp} · {Unit} %d/%d | {Camp} 근처 · {Unit} %d/%d | **[꺼짐]** 일자리 목표 글 2 · {Camp} = pond/camp · `Board.Jobs.2.Goal` |
| Hit 3 at once with a skill %d/%d | 스킬로 한 번에 3마리 맞히기 %d/%d | **[꺼짐]** 일자리 목표 글 4 · `Board.Jobs.4.Goal` · %d/%d = 지금 숫자/목표 숫자 |
| Basic hits only · {Unit} %d/%d | 기본 공격만 · {Unit} %d/%d | **[꺼짐]** 일자리 목표 글 5 · `Board.Jobs.5.Goal` · %d/%d = 지금 숫자/목표 숫자 · {Unit} = 게임이 알아서 채움 |
| Hunting gold %d/%d | 사냥 골드 %d/%d | **[꺼짐]** 일자리 목표 글 6 · `Board.Jobs.6.Goal` · %d/%d = 지금 숫자/목표 숫자 |
| Auto Battle defeats %d/%d | Auto Battle로 쓰러뜨리기 %d/%d | **[꺼짐]** 일자리 목표 글 7 · `Board.Jobs.7.Goal` · %d/%d = 지금 숫자/목표 숫자 |
| A golden monster %d/%d | 황금 몬스터 %d/%d | **[꺼짐]** 일자리 목표 글 8 · `Board.Jobs.8.Goal` · %d/%d = 지금 숫자/목표 숫자 |
| {Big} above half HP %d/%d | {Big} HP 절반 이상 %d/%d | **[꺼짐]** 일자리 목표 글 9 · `Board.Jobs.9.Goal` · %d/%d = 지금 숫자/목표 숫자 · {Big} = 게임이 알아서 채움 |
| Stand guard at the gate %d/%d s | 문 앞에서 경비 서기 %d/%d초 | **[꺼짐]** 일자리 목표 글 10 · `Board.Jobs.10.Goal` · %d/%d = 지금 숫자/목표 숫자 |
| Job Board · tap for directions | 일자리 게시판 · 눌러서 길 안내 | **[꺼짐]** 게시판 안내 줄 · `Board.Text.Hint` |
| Job done! +%s gold · +%s XP | 일 완료! +%s 골드 · +%s XP | **[꺼짐]** 일자리 완료 알림 · `Board.Text.Done` · %s = 이름이나 숫자가 들어감 |
| Bonus: +%s | 보너스: +%s | **[꺼짐]** 보너스 알림 · `Board.Text.Bonus` · %s = 이름이나 숫자가 들어감 |
| Max 3 jobs. | 일은 최대 3개. | **[꺼짐]** 하루 한도 알림 · `Board.Text.Full` |
| A flower got squished! | 꽃이 밟혔어요! | **[꺼짐]** 꽃 슬라임을 잡으면 뜨는 선택 카드 제목 · `ChoiceCard.Kinds.FlowerPatch.Title` |
| Replant it | 다시 심기 | **[꺼짐]** 카드 왼쪽 버튼 · `ChoiceCard.Kinds.FlowerPatch.Good.Label` |
| Pick the petals | 꽃잎 따기 | **[꺼짐]** 카드 오른쪽 버튼 · `ChoiceCard.Kinds.FlowerPatch.Evil.Label` |
| The apprentice scratched the hilt a little. | 견습생이 칼자루를 조금 긁었어요. | **[꺼짐]** 무기 주문 뒤 대장장이 견습생 카드 · `ChoiceCard.Kinds.ApprenticeScratch.Title` |
| It's fine. Thank you! | 괜찮아요. 고마워요! | **[꺼짐]** 카드 왼쪽 버튼 · `ChoiceCard.Kinds.ApprenticeScratch.Good.Label` |
| Fix it AND give me a discount! | 고쳐 주고 할인까지 해 줘요! | **[꺼짐]** 카드 오른쪽 버튼 · `ChoiceCard.Kinds.ApprenticeScratch.Evil.Label` |
| A lost teddy! Someone must miss it. | 잃어버린 곰 인형이다! 누군가 그리워하고 있을 거야. | **[꺼짐]** 분실물 카드(곰 인형) 제목 · `ChoiceCard.Kinds.LostTeddy.Title` |
| Give it back | 돌려주기 | **[꺼짐]** 분실물 카드 왼쪽 버튼 · `ChoiceCard.Kinds.LostTeddy.Good.Label` |
| Finder's fee! | 사례금! | **[꺼짐]** 분실물 카드 오른쪽 버튼 (어린이 물건) · `ChoiceCard.Kinds.LostTeddy.Evil.Label` |
| A Grab Club badge! A big goblin must be sad. | Grab Club 배지다! 덩치 큰 고블린이 슬퍼하고 있겠다. | **[꺼짐]** 분실물 카드(Grab Club 배지) 제목 · `ChoiceCard.Kinds.LostBadge.Title` |
| Keep it as a trophy | 전리품으로 갖기 | **[꺼짐]** 분실물 카드 오른쪽 버튼 (어린이 물건이 아닐 때) · `ChoiceCard.Kinds.LostBadge.Evil.Label` |
| An old guard medal! It still shines. | 오래된 경비 메달이다! 아직도 반짝인다. | **[꺼짐]** 분실물 카드(옛 경비 메달) 제목 · `ChoiceCard.Kinds.LostMedal.Title` |
| A candy bag! Someone is looking for it. | 사탕 주머니다! 누군가 찾고 있을 거야. | **[꺼짐]** 분실물 카드(사탕 주머니) 제목 · `ChoiceCard.Kinds.LostCandy.Title` |
| A Shard Bloom! It sparkles with crown dust. What will you do? | 조각 꽃이다! 왕관 가루로 반짝인다. 어떻게 할래? | **[꺼짐]** 조각 꽃 카드 제목 · `ChoiceCard.Kinds.ShardBloom.Title` |
| Share it | 나누기 | **[꺼짐]** 조각 꽃 카드 왼쪽 버튼 · `ChoiceCard.Kinds.ShardBloom.Good.Label` |
| Keep it all | 전부 갖기 | **[꺼짐]** 조각 꽃 카드 오른쪽 버튼 · `ChoiceCard.Kinds.ShardBloom.Evil.Label` |
| Kind choice! | 착한 선택! | 선택 카드로 착한 쪽을 골랐을 때 · `ChoiceCard.Text.GoodDone` |
| Sneaky choice! | 장난꾸러기 선택! | 선택 카드로 장난 쪽을 골랐을 때 · `ChoiceCard.Text.EvilDone` |
| Your shard is full for today. Come back tomorrow! | 오늘은 조각이 가득 찼어요. 내일 또 와요! | 오늘 점수 한도를 다 채웠을 때 · `ChoiceCard.Text.Full` |

## ⑤ 일일·주간·출석 퀘스트

본편 1장([Claim] M1_4)이 끝나면 안내자가 **일일 일(Daily Jobs)**을 알려 줍니다(D0). 그 뒤 매일(한국 시간 0시) 작은 일 3개가 새로 나오고, 3개를 다 하면 상자를 줍니다. 주간으로는 **랭킹 상위 3명**에게 칭호와 보너스가 있습니다. 이벤트 탭의 퀘스트(황금 거위·왕관 전쟁)는 ⑥에 있습니다.

### 5-1 일일 일 소개 퀘스트

#### D0 · Daily Jobs (일일 일)
- 종류: 사이드 (한 줄짜리 대화)
- 주는 사람: 내 진영 안내자
- 열리는 때: M1_4가 끝나면 저절로 시작
- 보상: 골드·경험치 각각 사냥 1분어치. 끝나면 '일일 퀘스트' 탭이 열림

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Daily Jobs | 일일 일 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Daily jobs | 일일 일 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Hear about the daily jobs | 일일 일 이야기 듣기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |
| Every day I have 3 small jobs for you. Do all 3 for a daily chest! | 매일 작은 일 3개를 줄게요. 3개를 다 하면 일일 상자를 받아요! | 목표 1 대화창 1쪽 — 모두에게 · `Steps.1.Lines.All.1` |
| Look in your Quests window. New jobs come every morning. | Quests 창을 보세요. 새 일은 매일 아침 와요. | 목표 1 대화창 2쪽 — 모두에게 · `Steps.1.Lines.All.2` |

### 5-2 일일 일 내용 (퀘스트 창 Daily 탭)

Lv1~9에는 "슬라임 왕자 3마리 / 슬라임 12~15마리 / 스킬로 몬스터 3~5번 맞히기 / 사냥으로 골드 40~60" 중에서 서로 다른 3개가 나옵니다. Lv10 이상은 숲 몬스터에 맞춰 숫자가 커지고, 가끔 황금 몬스터·황금 거위·착한/장난 선택 일이 섞입니다.

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Defeat %s ×%d | %s ×%d 쓰러뜨리기 | 일일 일: 몬스터 사냥 · `Quests.Templates.1.Text` · 앞 %s = 몬스터 이름, 뒤 %d = 마릿수 |
| Defeat golden %s ×%d | 황금 %s ×%d 쓰러뜨리기 | 일일 일: 황금 몬스터 · `Quests.Templates.2.Text` · %s = 몬스터 이름 |
| Earn %s gold by hunting | 사냥으로 골드 %s 벌기 | 일일 일: 골드 벌기 · `Quests.Templates.3.Text` · %s = 골드 양 |
| Hit monsters with skills %d times | 스킬로 몬스터를 %d번 맞히기 | 일일 일: 스킬 맞히기 · `Quests.Templates.4.Text` · %d = 숫자 |
| Join the Golden Goose tug %d times | Golden Goose(황금 거위) 줄다리기에 %d번 참여하기 | 일일 일: 황금 거위 줄다리기 · `Quests.Templates.5.Text` · %d = 숫자 |
| Catch %d Wanted players (Kaiju count) | Wanted 플레이어 %d명 잡기 (Kaiju도 센다) | 일일 일: Halo 전용, 드물게 나옴 · `Quests.Templates.6.Text` · "Kaiju count" = 괴수가 된 사람도 센다는 뜻 · %d = 숫자 |
| Rob %d Knights of Light | 빛의 기사 %d명의 골드 빼앗기 | 일일 일: Horns 전용, 드물게 · `Quests.Templates.7.Text` · %d = 숫자 |
| Make a kind or sneaky choice | 착한 선택 또는 장난 선택 하나 하기 | 일일 일: 착한/장난 선택 하나 · `Quests.Templates.8.Text` |
| Monster hunt | 몬스터 사냥 | 폰 짧은 줄 이름 — 사냥 · `Quests.Templates.1.ShortName` |
| Golden hunt | 황금 사냥 | 폰 짧은 줄 — 황금 몬스터 · `Quests.Templates.2.ShortName` |
| Earn gold | 골드 벌기 | 폰 짧은 줄 — 골드 · `Quests.Templates.3.ShortName` |
| Skill hits | 스킬 맞히기 | 폰 짧은 줄 — 스킬 · `Quests.Templates.4.ShortName` |
| Goose tug | 거위 줄다리기 | 폰 짧은 줄 — 거위 · `Quests.Templates.5.ShortName` |
| Catch Wanted | Wanted 잡기 | 폰 짧은 줄 — Halo PvP · `Quests.Templates.6.ShortName` |
| Rob Knights | 기사 털기 | 폰 짧은 줄 — Horns PvP · `Quests.Templates.7.ShortName` |
| Kind or sneaky | 착함 또는 장난 | 폰 짧은 줄 — 선택 · `Quests.Templates.8.ShortName` |
| Daily Quests %d/%d | 일일 퀘스트 %d/%d | 화면 왼쪽 위 머리글(PC) · HUD TXT.QuestHeader · 지금 숫자/전체 숫자 · %d/%d = 지금 숫자/목표 숫자 |
| Dailies %d/%d | 일일 일 %d/%d | 같은 머리글(폰) · HUD TXT.QuestHeader · %d/%d = 지금 숫자/목표 숫자 |
| Dailies done! Bonus quests on | 일일 일 끝! 보너스 퀘스트 켜짐 | 3개를 다 끝냈을 때 머리글 · HUD TXT.QuestAllDone |
| Swap quest | 퀘스트 바꾸기 | 일일 일 바꾸기 확인창 제목 · HUD TXT.RerollTitle |
| Your progress will be lost. Swap it? | 지금까지 한 진행이 사라져요. 바꿀까요? | 그 확인창 글 · HUD TXT.RerollBody |
| Daily quest done! Press [Claim]. | 일일 퀘스트 완료! [Claim]을 누르세요. | **[꺼짐]** 일일 일을 끝냈을 때 (DailyReady 꺼짐: 줄에 Done!/[Claim]이 이미 있어서) · `Text.DailyReady` |
| Daily reward! +%s gold +%s XP | 일일 보상! +%s 골드 +%s XP | 일일 일 [Claim] 보상 · `Text.DailyClaimed` · 골드, 경험치 · %s = 이름이나 숫자가 들어감 |
| Bonus chest! +%s gold +%s XP | 보너스 상자! +%s 골드 +%s XP | 3개를 다 받으면 보너스 상자 · `Text.DailyChest` · %s = 이름이나 숫자가 들어감 |
| +1 Class Change Ticket! | 직업 변경권 +1! | **[숨김]** 상자에서 직업 변경권이 나올 때 (이번 베타엔 변경권 판매·지급 없음) · `Text.DailyChestTicket` |
| Daily rewards! +%s gold | 일일 보상! +%s 골드 | 안 받은 일일 보상을 자동으로 줄 때 · `Text.DailyAutoPaid` · %s = 이름이나 숫자가 들어감 |
| All done for today! You can rest now without missing out. Want more? Enjoy story quests or hunting. | 오늘 할 일은 다 끝났어요! 이제 쉬어도 놓치는 게 없어요. 더 하고 싶으면 스토리 퀘스트나 사냥을 즐겨요. | 하루 일을 다 끝낸 뒤 · `Text.DailyAllDone` · ⚠ 영어 고칠 만함: 세 문장이라 길다 |
| Vacation bonus! +%s gold +%s XP | 휴가 보너스! +%s 골드 +%s XP | 며칠 쉬고 돌아오면 주는 휴가 보너스 · `Text.VacationClaimed` · %s = 이름이나 숫자가 들어감 |
| Extra quest done! +%s gold | 추가 퀘스트 완료! +%s 골드 | 추가 퀘스트 보상 · `Text.QuestDone` · %s = 이름이나 숫자가 들어감 |

### 5-3 출석·돌아왔을 때

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| %d days collected! | %d일 모았어요! | 출석 보상 창 — 지금까지 모은 날 · `Attendance.Text.Days` · %d = 숫자 |
| Day %d reward! %s | %d일째 보상! %s | 출석 보상 받음 · `Attendance.Text.Claimed` · 몇 번째 날, 보상 이름 · %d = 숫자 · %s = 이름이나 숫자가 들어감 |
| New look: %s! | 새 모양: %s! | 출석으로 새 후광/뿔 모양을 받음 · `Attendance.Text.NewLook` · %s = 이름이나 숫자가 들어감 |
| New title: %s! | 새 칭호: %s! | 출석으로 새 칭호 · `Attendance.Text.NewTitle` · %s = 이름이나 숫자가 들어감 |
| New name frame! | 새 이름 테두리! | 출석으로 새 이름 테두리 · `Attendance.Text.NewBorder` |
| Welcome back! | 다시 오신 걸 환영해요! | 한참 쉬었다 오면 뜨는 카드 제목 · PauseCard Text.BackTitle |
| Next: %s | 다음: %s | 그 카드의 '다음에 할 일' · PauseCard Text.BackNext · %s = 다음 목표 줄 |
| Good to see you again! | 다시 만나서 반가워요! | 할 일 줄이 없을 때 · PauseCard Text.BackPlain |
| Hunt and get stronger! | 사냥하며 더 강해져요! | 돌아온 카드 아래 한 줄 · `Return.Text.NextHunt` |
| New dailies | 새 일일 퀘스트 | 내일 일일 일 안내 · `Return.Text.TomorrowDaily` |

### 5-4 주간 랭킹 (상위 3명에게 보너스)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| This server · this week | 이 서버 · 이번 주 | 랭킹 창 맨 위 · `Ranking.Text.Board.Header` |
| %s #%d! New title · XP, drops +10%% | %s #%d! 새 칭호 · 경험치, 드롭 +10% | 새 주가 시작될 때 상위 3명 알림 · `Ranking.Text.RewardStart` · 앞 %s = 랭킹 종류, %d = 등수, %% = % 기호 |
| This week's %s #%d: XP and drops +10%% (until Monday) | 이번 주 %s #%d: 경험치와 드롭 +10% (월요일까지) | 보너스가 켜져 있는 동안 화면 칩 · `Ranking.Text.RewardChip` · %d = 숫자 · %s = 이름이나 숫자가 들어감 · %% = % 기호 하나로 보임 |
| Top 3: XP and drops +10% next week | 상위 3명: 다음 주 경험치와 드롭 +10% | 랭킹 창 아래 설명 · `Ranking.Text.RewardTabNote` |
| Rises when you KO weaker, idle or new players. Top 3 (3+ points) turn outlaw. | 약한 사람, 가만히 있는 사람, 새로 온 사람을 쓰러뜨리면 올라가요. 상위 3명(3점 이상)은 무법자가 돼요. | PvP 랭킹 설명 · `Ranking.Text.PvPTabNote` · ⚠ 영어 고칠 만함: 'Rises when you KO weaker, idle or new players'가 어렵다 |
| Outlaw week: no Auto, half rewards, 2x bounty | 무법자 주간: 자동 전투 없음, 보상 절반, 현상금 2배 | PvP 랭킹 상위 3명이 무법자(Outlaw)가 될 때 · `Ranking.Text.OutlawStart` |
| Outlaw: no Auto Battle · half XP and drops (until Monday) | 무법자: 자동 전투 없음 · 경험치와 드롭 절반 (월요일까지) | 무법자 주간 화면 칩 · `Ranking.Text.OutlawChip` |
| Outlaw week over! Auto is back. | 무법자 주간이 끝났어요! 자동 전투가 돌아와요. | 무법자 주간이 끝남 · `Ranking.Text.OutlawEnd` |
| New accounts join the global ranking after 3 days and 30 minutes of play | 새 계정은 3일 + 30분 플레이한 뒤에 전체 랭킹에 들어가요 | 새 계정이 랭킹에 못 들어갈 때 · `Ranking.Text.Ineligible` · ⚠ 영어 고칠 만함: 길다 |
| Private servers do not earn ranking points | 비공개 서버에서는 랭킹 점수가 쌓이지 않아요 | 비공개 서버에선 랭킹 점수가 없음 · `Ranking.Text.Private` |

## ⑥ 이벤트 — 황금 거위·황금 알·왕관 전쟁·괴수

모두 정해진 시간에 서버 전체에 열립니다. 알림은 화면 위에 잠깐 뜨고, 진행은 위쪽 막대(바)에 숫자로 나옵니다.

**황금 알 줍기(Eggs 모드)**: 클라이언트 코드(EggFx)는 있지만 서버 설정 `Config.Goose.Mode`가 `"Eggs"`가 아니라서 **지금은 꺼져 있고**, 지금 도는 건 아래 '황금 거위 줄다리기'입니다. 알 모드는 글이 거의 없고 기호만 씁니다: `!`(깜짝), `Zzz`(졸고 있는 거위), `+숫자`(얻은 알 수), 막대 숫자 `%d` 또는 `%d / %d`.

### 6-1 황금 거위 줄다리기 (10분마다 약 60초)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Golden Goose! | 황금 거위! | 거위가 나올 때 크게 한 줄 (2초) · `Goose.Text.Start` |
| Golden Goose | 황금 거위 | 거위 머리 위 이름표 · `Goose.Text.Label` |
| Golden Goose %s | 황금 거위 %s | 폰 다음 이벤트 줄 · EventHUD TXT.GooseNext · %s = 남은 시간 |
| Golden Goose Tug! %s | 황금 거위 줄다리기! %s | 위쪽 막대 제목 · EventHUD TXT.GooseTitle · %s = 남은 시간 |
| Rescue %d | 구하기 %d | 막대 왼쪽 숫자(Halo가 구하기 점수) · EventHUD TXT.Rescue · %d = 숫자 |
| Poach %d | 밀렵 %d | 막대 오른쪽 숫자(Horns가 밀렵 점수) · EventHUD TXT.Poach · %d = 숫자 |
| My hits %d | 내 타격 %d | 내가 친 횟수 · EventHUD TXT.MyCount · %d = 숫자 |
| Hit the goose to rescue it! | 거위를 때려서 구해요! | Halo에게 힌트 · EventHUD TXT.HintHalo |
| Hit the goose to poach it! | 거위를 때려서 밀렵해요! | Horns에게 힌트 · EventHUD TXT.HintHorns |
| The Artisan Guild sits out the tug | 장인 길드는 이번 줄다리기에 안 껴요 | **[꺼짐]** 길드에게 · EventHUD TXT.HintNeutral |
| No reward: hit it yourself %d+ times | 보상 없음: 직접 %d번 이상 때려야 해요 | 손으로 친 횟수가 모자라 보상이 없을 때 · `Goose.Text.NeedManual` · %d = 필요한 횟수 |
| Team Rescue! %s | 함께 구조! %s | 상대 진영이 서버에 없을 때(함께 구조) 막대 제목 · `Goose.Text.HudTitle.Halo` · %s = 남은 시간 |
| Team Poach! %s | 함께 밀렵! %s | (함께 밀렵) 막대 제목 · `Goose.Text.HudTitle.Horns` · %s = 이름이나 숫자가 들어감 |
| %d together | %d명이 함께 | 함께 하는 사람 수 · `Goose.Text.HudPeople` · %d = 숫자 |
| My points %d · Knights, fill the gauge! | 내 점수 %d · 기사들, 게이지를 채워요! | **[꺼짐]** 막대 아래 한 줄 (GooseSub 꺼짐) · `Goose.Text.HudSub.Halo` · %d = 숫자 |
| My points %d · Rescued! Hit it %d times for a reward | 내 점수 %d · 구했어요! 보상을 받으려면 %d번 때려요 | **[꺼짐]** 게이지가 찼을 때 막대 아래 한 줄 (꺼짐) · `Goose.Text.HudFull.Halo` · %d = 숫자 |
| This goose is the Knights' Team Rescue | 이 거위는 빛의 기사단의 '함께 구조'예요 | 다른 진영에게 보이는 말 · `Goose.Text.HudOther.Halo` |
| Gauge full! Team Rescue done.<br>Hit it yourself %d+ times before the end for a reward! | 게이지 가득! 함께 구조 완료.<br>끝나기 전에 직접 %d번 이상 때리면 보상을 받아요! | 게이지가 가득 찼을 때 모두에게 알림 · `Goose.Text.CoopFull.Halo` · ⚠ 영어 고칠 만함: 두 문장 + 줄바꿈. 짧게 줄일 만함 · %d = 숫자 |
| Gauge full! Team Poach done.<br>Hit it yourself %d+ times before the end for a reward! | 게이지 가득! 함께 밀렵 완료.<br>끝나기 전에 직접 %d번 이상 때리면 보상을 받아요! | (Horns 판) · `Goose.Text.CoopFull.Horns` · %d = 숫자 |
| The Knights worked together and rescued the Golden Goose! The shard shines with light again. | 기사들이 힘을 합쳐 황금 거위를 구했다! 조각이 다시 빛으로 빛난다. | 끝났을 때 결과 알림 (Halo) · `Goose.Text.CoopResult.Halo` |
| The Horn Legion worked together and poached the Golden Goose! The shard turned dark. | 뿔 군단이 힘을 합쳐 황금 거위를 밀렵했다! 조각이 어둠으로 변했다. | 끝났을 때 결과 알림 (Horns) · `Goose.Text.CoopResult.Horns` |
| The gauge wasn't filled, so the Golden Goose flew away! | 게이지를 못 채워서 황금 거위가 날아가 버렸다! | 게이지가 못 찼을 때 · `Goose.Text.CoopFail` |
| Team Rescue reward! +%s gold +%s XP | 함께 구조 보상! +%s 골드 +%s XP | 함께 구조 성공 보상 알림 · `Goose.Text.CoopReward.Halo` · 골드, 경험치 · %s = 이름이나 숫자가 들어감 |
| Team Poach reward! +%s gold +%s XP | 함께 밀렵 보상! +%s 골드 +%s XP | 함께 밀렵 성공 보상 알림 · `Goose.Text.CoopReward.Horns` · %s = 이름이나 숫자가 들어감 |
| The other side all left, so the team rule decides it. %s | 상대 편이 모두 나가서 팀 규칙으로 정해요. %s | 상대 진영이 다 나가서 팀 규칙으로 정할 때 · `Goose.Text.RivalLeft` · %s = 앞 결과 글 |
| Not your goose this time. | 이번엔 네 거위가 아니야. | 상대 진영이 줄다리기에 끼려 하면 한 번 뜸 · `Goose.Text.RivalWait.Halo` |
| The Knights rescued the Golden Goose! The shard shines with light again. | 기사들이 황금 거위를 구했다! 조각이 다시 빛으로 빛난다. | Halo가 이겼을 때 결과 알림 · `Story.GooseResult.Halo` |
| The Horn Legion poached the Golden Goose! The shard turned dark. | 뿔 군단이 황금 거위를 밀렵했다! 조각이 어둠으로 변했다. | Horns가 이겼을 때 · `Story.GooseResult.Horns` |
| The Golden Goose flew away! It's a tie. | 황금 거위가 날아가 버렸다! 무승부. | 비겼을 때 · `Story.GooseResult.Tie` |
| Golden Goose reward! +%s gold +%s XP | 황금 거위 보상! +%s 골드 +%s XP | 내 거위 보상 알림 · `Text.GooseReward` · 골드, 경험치 · %s = 이름이나 숫자가 들어감 |
| Cheer Star %d/5 | 응원별 %d/5 | 진 편이 받는 응원별 (5개 모이면 다음에 보상 5배) · `Text.GooseCheer` · %d = 별 개수 |
| Cheer Stars | 응원별 | 응원별 라벨 · EventHUD TXT.CheerLabel |
| Rare reward! ×5 | 희귀 보상! ×5 | 5배 보상이 터졌을 때 · `Text.RareToast` |
| %s got a rare Golden Goose reward! | %s이(가) 황금 거위의 희귀 보상을 받았어요! | 서버 전체에 알림 · `Text.RareAnnounce` · %s = 이름(숨기면 'A member of …') |

### 6-2 이벤트 탭 사이드 퀘스트

#### S1 · The Golden Goose With a Shard (조각을 가진 황금 거위)
- 종류: 이벤트 탭 사이드
- 주는 사람: (없음)
- 열리는 때: 황금 거위가 곧 나올 때 보임 (Halo/Horns만)
- 보상: 처음 한 번 Honor/Mischief +1 (거위 보상은 거위 이벤트가 따로 줌)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| The Golden Goose With a Shard | 조각을 가진 황금 거위 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Golden Goose | 황금 거위 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Hit the Golden Goose yourself 3 times | 황금 거위를 직접 3번 때리기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |

#### S2 · First Crown War Chest (첫 왕관 전쟁 상자)
- 종류: 이벤트 탭 사이드
- 주는 사람: (없음)
- 열리는 때: M2_1 뒤 (Halo/Horns만)
- 보상: (퀘스트 보상 없음, 전쟁 상자가 보상)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| First Crown War Chest | 첫 왕관 전쟁 상자 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| War chest | 전쟁 상자 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Get 30 points in one round · win the chest | 한 판에서 30점 얻기 · 상자 얻기 | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` |

#### GW5 · The Tired Goose (지친 거위)
- 종류: 이벤트 탭 사이드
- 주는 사람: Fountain Shard (분수의 조각)
- 열리는 때: M2_7 뒤, Lv17부터 (Halo/Horns만)
- 보상: 골드·경험치 각각 사냥 2분어치 — 완료 알림 "<이름> done! +골드 · +XP"
- 선택 보상: 왼쪽(착한 쪽) = 강화 주문서 70% 1장 · 오른쪽(장난 쪽) = HP 물약 3개 + 골드 220. 점수 1점 (자기 진영 점수는 오르고, 반대쪽 고르면 자기 점수가 깎임, A23-58)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| The Tired Goose | 지친 거위 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Tired goose | 지친 거위 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| Fountain Shard: The Golden Goose looks so tired… | Fountain Shard: 황금 거위가 너무 지쳐 보여… | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Join the Golden Goose tug %d/%d | 황금 거위 줄다리기에 참여하기 %d/%d | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d/%d = 지금 숫자/목표 숫자 |
| Talk with the Fountain Shard | Fountain Shard와 이야기하기 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| Fountain Shard: She runs every day. Pulled this way, then that way. | Fountain Shard: 쟤는 매일 달려. 이쪽으로 당겨졌다, 저쪽으로 당겨졌다. | 목표 2 대화창 1쪽 — 모두에게 · `Steps.2.Lines.All.1` |
| Fountain Shard: What now? | Fountain Shard: 이제 어떻게 할래? | 목표 2 대화창 2쪽 — 모두에게 · `Steps.2.Lines.All.2` |
| Let her rest a day | 하루 쉬게 해 주기 | 목표 2 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.2.Obj.Good.Label` |
| Make her lay eggs faster! | 알을 더 빨리 낳게 하기! | 목표 2 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.2.Obj.Evil.Label` |
| Fountain Shard: Are more eggs ever enough? | Fountain Shard: 알이 많으면 많을수록 충분할까? | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

### 6-3 왕관 전쟁 (10분 한 판, 몬스터를 잡아 진영 점수 올리기)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Crown won! Gold, XP +25%% | 왕관 승리! 골드, 경험치 +25% | 이긴 진영에게만 알림 (두 진영 글이 같음) · `Story.WarWin.Halo` · %% = % 기호 하나 |
| Nobody won the crown this round! | 이번 판에는 아무도 왕관을 못 얻었어요! | 아무도 못 이겼을 때 · `Story.WarDraw` |
| Crown in %s | 왕관까지 %s | 다음 왕관 전쟁까지 남은 시간 (위쪽 막대) · HUD TXT.WarTime · %s = 시간 |
| Crown War | 왕관 전쟁 | 혼자 있는 진영일 때 막대 이름 · HUD TXT.WarSiege |
| Siege: %d each | 포위전: 각자 %d | **[숨김]** 옛 이름(막대에서 안 씀) · HUD TXT.Siege · %d = 숫자 |
| My pts %s | 내 점수 %s | 내 점수 · HUD TXT.MyWar · %s = 이름이나 숫자가 들어감 |
| %s Crown Blessing +%d%% | %s 왕관 축복 +%d% | 이긴 진영이 받는 축복 칩 · HUD TXT.Blessing · 앞 %s = 진영, %d = % |
| Crown War: win points for your side! | 왕관 전쟁: 우리 편 점수를 올려요! | **[꺼짐]** 전쟁 막대가 처음 나올 때 한 줄 (WarIntro 꺼짐) · HUD TXT.WarIntro |
| War chest! +%s gold | 전쟁 상자! +%s 골드 | 개인 점수 30점 이상이면 상자 보상 알림 · `Text.WarChest` · %s = 골드 |

### 6-3b 왕관 전쟁 사이드 퀘스트

#### GW4 · The Crown War Is Close (왕관 전쟁이 다가와요)
- 종류: 이벤트 탭 사이드
- 주는 사람: (없음)
- 열리는 때: M2_7 뒤, Lv16부터 (Halo/Horns만)
- 보상: 골드·경험치 각각 사냥 2분어치 — 완료 알림 "<이름> done! +골드 · +XP"
- 선택 보상: 왼쪽(착한 쪽) = 강화 주문서 70% 1장 · 오른쪽(장난 쪽) = HP 물약 3개 + 골드 220. 점수 1점 (자기 진영 점수는 오르고, 반대쪽 고르면 자기 점수가 깎임, A23-58)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| The Crown War Is Close | 왕관 전쟁이 다가와요 | 퀘스트 이름 — 퀘스트 창, 완료 알림에 나옴 · `Title` |
| Crown War | 왕관 전쟁 | 폰 화면용 짧은 줄 이름 · `ShortName` |
| The Crown War is close! Win points for your side. | 왕관 전쟁이 다가와요! 우리 편 점수를 올려요. | **[숨김]** 퀘스트 시작 알림 · `Start` |
| Crown points %d/%d | 왕관 점수 %d/%d | 목표 1 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.1.Text` · %d/%d = 지금 숫자/목표 숫자 |
| The round is over | 한 판이 끝났어요 | 목표 2 — 퀘스트 창·화면 왼쪽 퀘스트 줄에 나옴 · `Steps.2.Text` |
| What a round! | 대단한 한 판이었어요! | 목표 2 대화창 1쪽 — 모두에게 · `Steps.2.Lines.All.1` |
| How will you end it? | 어떻게 끝낼래요? | 목표 2 대화창 2쪽 — 모두에게 · `Steps.2.Lines.All.2` |
| Cheer for both sides | 양쪽 모두를 응원하기 | 목표 2 선택 버튼 — 왼쪽(착한 쪽, 날개 그림) · `Steps.2.Obj.Good.Label` |
| Victory dance, our side only! | 우리 편만 승리 춤을! | 목표 2 선택 버튼 — 오른쪽(장난·악 쪽, 뿔 그림) · `Steps.2.Obj.Evil.Label` |
| Who was the war really for? | 이 전쟁은 정말 누구를 위한 걸까? | **[숨김]** 퀘스트 마무리 대사 (A23-130부터 서버가 안 보냄) · `Finish` |

### 6-4 괴수(Kaiju)와 원한 자루(Grudge Sack)

Horns가 Wanted(현상수배) 별 5개를 모으면 10초 뒤 **괴수(Kaiju)**로 변신합니다. 괴수는 120초 동안 커지고, Knights가 어디서든 때릴 수 있습니다.

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Alert! %s is being swallowed by the Crown Shard's darkness! A Kaiju in 10 seconds! | 경고! %s이(가) Crown Shard의 어둠에 삼켜지고 있다! 10초 뒤 Kaiju가 된다! | 변신 10초 전 경보 · `Story.KaijuSiren` · %s = 이름 |
| Kaiju %s is here! | Kaiju %s이(가) 나타났다! | 변신했을 때 · `Story.KaijuStart` · %s = 이름이나 숫자가 들어감 |
| The Knights defeated the Kaiju %s! They share a %s gold reward. | 기사들이 Kaiju %s을(를) 쓰러뜨렸다! 보상 %s 골드를 나눠 가진다. | Knights가 괴수를 쓰러뜨림 · `Story.KaijuDefeated` · 이름, 골드 · %s = 이름이나 숫자가 들어감 |
| The Kaiju %s was defeated. | Kaiju %s이(가) 쓰러졌다. | 보상을 받은 사람이 없을 때 · `Story.KaijuDefeatedNoReward` · %s = 이름이나 숫자가 들어감 |
| The Kaiju %s survived to the end! A Final Boss is born! | Kaiju %s이(가) 끝까지 살아남았다! 최종 보스가 태어났다! | 괴수가 끝까지 살아남음 · `Story.KaijuSurvived` · %s = 이름이나 숫자가 들어감 |
| You're the Kaiju! Last %s | 네가 Kaiju다! 남은 시간 %s | 내가 괴수일 때 위쪽 글 · EventHUD TXT.KaijuSelf · %s = 남은 시간 |
| Another Kaiju is out. You'll transform when it's over! | 다른 Kaiju가 이미 나왔어요. 끝나면 변신해요! | 괴수가 이미 있어서 대기 중 · `Text.KaijuQueued` |
| Kaiju hunt reward +%s gold! | Kaiju 사냥 보상 +%s 골드! | 괴수 사냥 보상 · `Text.KaijuReward` · %s = 이름이나 숫자가 들어감 |
| Survived! +%s gold to vault | 살아남았어요! +%s 골드가 금고로 | 괴수로 살아남은 보상 · `Text.KaijuSurviveReward` · %s = 이름이나 숫자가 들어감 |
| %s stole %s gold from you!<br>If a knight catches the thief within 45 s, you get 120%% back. | %s이(가) 네 골드 %s을(를) 훔쳤어요!<br>기사가 45초 안에 도둑을 잡으면 120%를 돌려받아요. | 골드를 빼앗겼을 때 · `Text.Plundered` · 앞 %s = 빼앗은 사람, 뒤 %s = 골드, %% = % 기호 |
| +%s gold in Grudge Sack! | Grudge Sack에 +%s 골드! | 내가 빼앗았을 때 · `Text.PlunderGain` · %s = 이름이나 숫자가 들어감 |
| You kept the Grudge Sack! Got %s gold | Grudge Sack을 지켰어요! %s 골드 획득 | 원한 자루를 45초 지켜 골드를 얻음 · `Text.SackPaid` · %s = 이름이나 숫자가 들어감 |
| You lost the Grudge Sack! | Grudge Sack을 잃었어요! | 원한 자루를 잃음 · `Text.SackLost` |
| Stolen gold back: +%s | 빼앗긴 골드 회수: +%s | 기사가 도둑을 잡아 골드가 돌아옴 · `Text.GrudgeRefund` · %s = 이름이나 숫자가 들어감 |

### 6-5 필드 보스 알림 (서버 전체에 뜸)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| King Slime is here! (Squishy Meadow) | King Slime이 나타났다! (Squishy Meadow) | 킹 슬라임 등장 · `Announce.Text.SlimeKingAppear` |
| King Slime was defeated! | King Slime이 쓰러졌다! | 킹 슬라임을 쓰러뜨림 · `Announce.Text.SlimeKingDefeat` |
| King Slime went home. | King Slime이 집으로 돌아갔다. | 킹 슬라임이 돌아감 · `Announce.Text.SlimeKingLeave` |
| Captain Clatter is here! (Skeleton Ruins) | Captain Clatter가 나타났다! (Skeleton Ruins) | Captain Clatter(해골 대장) 등장 · `Announce.Text.ClatterAppear` |
| Captain Clatter was defeated! | Captain Clatter가 쓰러졌다! | Captain Clatter 쓰러짐 · `Announce.Text.ClatterDefeat` |
| Captain Clatter left. | Captain Clatter가 떠났다. | Captain Clatter가 떠남 · `Announce.Text.ClatterLeave` |

※ 호박밭(Pumpkin Patch)·유령 숲(Haunted Hollow)의 Pumpkin King / Ghost King 알림과 핼러윈 대사(`Halloween.*`)는 구역이 숨겨져 있어(`Halloween.Enabled=false`) 이 문서에서 뺐습니다.

## ⑦ NPC 대사·상점·몬스터 소리 (대표만 뽑음)

**뺀 것**: 마을 사람 말풍선 146줄 중 계급 5단계 × 사람 5명 × 진영 변형을 거의 다 뺐고(아래는 사람마다 1~2줄씩만), 몬스터 소리 169줄 중 대표 몇 줄만 넣었습니다. 마을 사람은 30초에 한 번, 가까이 가면 머리 위 말풍선으로 한 줄씩 말합니다. 말투는 내 계급(Squire~Archangel / Rascal~Demon King)과 최근 착한/장난 선택에 따라 바뀝니다.

### 7-1 상점 NPC

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Otto: Clang, clang… done. Cocoa time. | Otto: 땅땅, 다 됐다… 코코아 마실 시간이야. | 대장간(Forge) 창 맨 위 Otto 인사 · `Text.ForgeGreeting` |
| Fizzby: Glug, glug, feel better! | Fizzby(피즈비): 꿀꺽꿀꺽, 기운 나지! | 물약 가게 창 맨 위 Fizzby 인사 · `Text.PotionGreeting` |
| Too far from the Forge. | 대장간에서 너무 멀어요. | 대장간에서 너무 멀 때 · `Text.WeaponShopFar` |
| %s equipped! | %s 장착! | 무기를 샀을 때 · `Text.WeaponBought` · %s = 무기 이름 |
| You can buy this weapon from Lv %d. | 이 무기는 Lv %d부터 살 수 있어요. | 레벨이 모자라 못 살 때 · `Text.WeaponNeedLevel` · %d = 숫자 |
| Not sold. Quest reward. | 팔지 않아요. 퀘스트 보상이에요. | 퀘스트로만 받는 무기 · `Text.WeaponFromQuest` |
| Bought %s potion ×%d! | %s 물약 ×%d 구매! | 물약을 샀을 때 · `Text.PotionBought` · 앞 %s = 물약 종류, 뒤 %d = 개수 |
| You can hold up to %d of each potion. | 물약은 종류마다 최대 %d개까지 들 수 있어요. | 물약을 더 못 들 때 · `Text.PotionStockFull` · %d = 숫자 |

### 7-2 마을 사람 말풍선 (대표)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Welcome, Squire! I'm Bright. Stay shiny! | 어서 와요, Squire! 나는 Bright예요. 반짝반짝 지내요! | Bright(빛의 성채 경비), Halo Squire일 때 · `TownReact.Text.Npc.Bright.Rank.Halo.1` |
| A Rascal in our town? Behave, okay? | 우리 마을에 Rascal이? 얌전히 있어요, 알겠죠? | Bright, Horns Rascal이 놀러 왔을 때 · `TownReact.Text.Npc.Bright.Rank.Horns.1` |
| Welcome, Squire. Stand tall! | 어서 오게, Squire. 허리를 펴게! | Sir Gleam, Halo Squire일 때 · `TownReact.Text.Npc.Gleam.Rank.Halo.1` |
| Warlord! I do not bow. Quite. | Warlord! 나는 절하지 않소. 전혀. | Sir Gleam, Horns Warlord가 왔을 때 · `TownReact.Text.Npc.Gleam.Rank.Horns.3` |
| Squire! Fresh juice for the new face! | Squire! 새로 온 얼굴에게 신선한 주스를! | 주스 가게 아저씨(Folk1), Halo Squire일 때 · `TownReact.Text.Npc.Folk1.Rank.Halo.1` |
| A Rascal! Eyes off the cookies, dear. | Rascal이구나! 쿠키에서 눈 떼렴. | 빵집 할머니, Horns Rascal일 때 · `TownReact.Text.Npc.Folk3.Rank.Horns.1` |
| Welcome, Squire! Bottles are cheap today. | 어서 와요, Squire! 오늘은 병이 싸요. | 물약 상인(빛의 성채), Halo Squire일 때 · `TownReact.Text.Npc.PotionHalo.Rank.Halo.1` |
| Welcome, little Squire! | 어서 와, 어린 Squire! | 이름 없는 마을 사람, Halo Squire일 때 · `TownReact.Text.Rank.Halo.1.1` |
| A little Rascal! Hide the cookies! | 어린 Rascal이다! 쿠키 숨겨! | 마을 사람, Horns Rascal일 때 · `TownReact.Text.Rank.Horns.1.1` |
| The Demon King! Everyone, bow! | Demon King이다! 다들 절해! | 마을 사람, Horns Demon King일 때 · `TownReact.Text.Rank.Horns.5.1` |
| You always help. Thank you! | 늘 도와주네요. 고마워요! | 계속 착한 선택만 했을 때 (True Knight) · `TownReact.Text.Lean.TrueKnight.1` |
| Huh? A NICE devil? …Suspicious. | 응? 착한 악마? …수상한데. | Horns인데 착한 선택을 많이 했을 때 (Soft-Hearted Devil) · `TownReact.Text.Lean.SoftDevil.1` |
| Trouble again? Classic you! | 또 말썽이야? 역시 너답다! | 계속 장난 선택만 했을 때 (Proud Rascal) · `TownReact.Text.Lean.ProudRascal.1` |
| You told the truth! It was just birthday jelly! | 사실대로 말했구나! 그냥 생일 젤리였대! | 내 마을에서, H1에서 진실을 말한 걸 알아줌 · `TownReact.Text.Good.H1` |
| Did you hear? The Horns are up to something! | 들었어? Horns가 뭔가 꾸미고 있대! | H1에서 소문을 계속 퍼뜨린 걸 알아줌 · `TownReact.Text.Evil.H1` |
| Our vault shines! The goblins look a bit sad. | 우리 금고가 반짝여! 고블린들은 좀 슬퍼 보이네. | M3_4에서 금고에 넣기를 고른 걸 알아줌 · `TownReact.Text.Evil.M3_4` |
| The new kids keep calling you boss. Hmm… | 새로 온 아이들이 너를 자꾸 대장이라고 불러. 흠… | S6 장난 쪽을 알아줌 · `TownReact.Text.Evil.S6` |

### 7-3 몬스터가 내는 소리 (말풍선, 대표)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| Blub? | 부글? | Slime이 나를 발견 · `Barks.Lines.Slime.Spot.1` |
| Squish! | 푹! | Slime이 맞을 때 · `Barks.Lines.Slime.Hit.1` |
| BLOOP! | 뽀옹! | Slime Prince가 나를 발견 · `Barks.Lines.BigSlime.Spot.1` |
| MY KIDS?! | 내 아이들?! | King Slime이 나를 발견 ("내 아이들?!") · `Barks.Lines.SlimeKing.Spot.1` |
| Daddy BOING! | 아빠 통통! | King Slime이 맞을 때 · `Barks.Lines.SlimeKing.Hit.2` |
| Ooh, shiny! | 오, 반짝이다! | Goblin이 나를 발견 · `Barks.Lines.Goblin.Spot.3` |
| Tuesday? | 화요일? | 해골 병사가 서 있을 때 (화요일 농담) · `Barks.Lines.Skeleton.Idle.2` |
| Burp. Shiny. | 꺽. 반짝반짝. | 황금 몬스터가 서 있을 때 · `Barks.Lines.Golden.Idle.1` |

## ⑧ 자주 뜨는 짧은 메시지 (보상·레벨업·쓰러짐·오류)

**뺀 것**: 설정·키 바꾸기·가방 정렬 같은 UI 글자, PvP 상세 규칙 알림, 환생 상세, 가챠/상품 글은 뺐습니다. 아래는 아이가 가장 자주 보는 줄만 모았습니다.

### 8-1 보상·성장

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| An angel courier put %s gold in your vault. | 천사 배달부가 골드 %s을(를) 금고에 넣어 주었어요. | Halo가 골드를 금고에 넣어 줄 때 (Halo 장점 4번) · `Text.HaloCourier` · %s = 이름이나 숫자가 들어감 |
| +%s | +%s | 아이템을 얻음 · %s = 아이템 이름 |
| %s equipped! | %s 장착! | 무기를 바꿔 낌 · `Loot.Text.Equip` · %s = 이름이나 숫자가 들어감 |
| Not enough gold. | 골드가 모자라요. | 골드가 모자람 · `Text.NotEnoughGold` |
| Unlocked! %s | 열렸어요! %s | 새 기능·무기가 열림 · `Text.Unlocked` · %s = 이름 |
| Nice! x10 | 좋아! x10 | 연속 타격 표시 · `Combo.Milestones` (10 / 25 / 50 / 100번째: Nice! x10, Great! x25, Wild! x50, Legend! x100) |
| Sprout Shield ends in 60 s! | Sprout Shield가 60초 뒤에 끝나요! | 새싹 보호가 60초 뒤 끝남 · `Text.GraduateStart` |
| Now you can fight the other sides! | 이제 다른 편과 싸울 수 있어요! | 새싹 보호가 끝남 · `Text.GraduateEnd` |

### 8-2 쓰러짐(KO) 화면과 저장 카드

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| KO! | 쓰러짐! (KO) | 쓰러지면 화면 가운데 큰 글자 · DeathScreen T.Title |
| Knocked out by %s | %s에게 쓰러졌어요 | 몬스터에게 쓰러짐 · `Death.Text.Monster` · %s = 몬스터 이름 |
| You fell | 떨어졌어요 | 떨어져서 쓰러짐 · `Death.Text.Fall` |
| Nothing lost | 잃은 것 없음 | 잃은 게 없음 (첫 쓰러짐) · `Death.Text.LostNone` |
| Lost %s pouch gold | 주머니 골드 %s을(를) 잃었어요 | 주머니 골드를 잃음 · `Death.Text.Lost` · %s = 골드 |
| Back in %d s | %d초 뒤에 돌아와요 | 되살아날 때까지 카운트다운 · `Death.Text.Respawn` · %d = 초 |
| Saved! | 저장됐어요! | 쉬어 가도 좋을 때 카드 제목 · PauseCard Text.PauseTitle |
| Next time: %s | 다음에 할 일: %s | 저장 카드의 '다음에 할 일' · PauseCard Text.PauseNext · %s = 이름이나 숫자가 들어감 |
| Keep playing | 계속 하기 | 저장 카드 버튼 · PauseCard Text.Keep |

### 8-3 자주 만나는 오류·안내

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| We couldn't load your save. Please rejoin in a moment. | 저장 파일을 불러오지 못했어요. 잠시 뒤에 다시 들어와 주세요. | 저장 파일을 못 불러옴 · `Text.LoadFailed` |
| Loading your save… | 저장 파일을 불러오는 중… | 저장 파일을 불러오는 중 · `Text.SaveLoading` |
| Not enough MP. | MP가 모자라요. | MP가 모자람 · `Text.NoMana` |
| No potions left. | 남은 물약이 없어요. | 물약이 없음 · `Text.PotionNone` |
| You can't do that in combat. | 싸우는 중에는 할 수 없어요. | 싸우는 중이라 이동이 안 됨 · `Text.TravelBlockedCombat` |
| You can do that after you respawn. | 되살아난 뒤에 할 수 있어요. | 쓰러져 있어서 지금은 못 함 · `Text.WaitRespawn` |
| Splash! Back on dry land. | 풍덩! 땅으로 돌아왔어요. | 물에 빠져 땅으로 돌아옴 · `Text.WaterRescue` |
| You can only change class in a safe zone. | 직업은 안전 구역에서만 바꿀 수 있어요. | 직업은 안전 구역에서만 바꿈 · `Text.ClassNeedSafe` |
| Class: %s. Back to Lv 1! | 직업: %s. Lv 1로 돌아갔어요! | 직업을 무료로 바꿈(Lv5 이상: 레벨 1로 돌아감) · `Text.ClassChangedFree` · %s = 직업 이름 |
| You can switch sides again in %s. | %s 뒤에 다시 편을 바꿀 수 있어요. | 진영을 또 바꾸려면 기다려야 함 · `Text.SwitchCooldown` · %s = 남은 시간 |
| The shard is sleepy… Take a step? (Auto Battle rests in 30 s) | 조각이 졸려요… 한 걸음 움직여 볼래요? (Auto Battle은 30초 뒤에 쉬어요) | 자동 전투 중 가만히 있을 때 · `Text.AutoSleepy` |
| You seem away, so Auto Battle is resting. Move and it starts again. | 자리를 비운 것 같아서 Auto Battle이 쉬고 있어요. 움직이면 다시 시작해요. | 자리를 비워서 자동 전투가 쉼 · `Text.AutoRestOn` |
| You're under attack! Hit back with the Attack button | 공격받고 있어요! 공격 버튼으로 맞서 싸워요 | 자동 전투 중 PvP로 맞는 중 · `Text.AutoUnderAttack` |

---

## 이 문서에서 뺀 것·확인 못 한 것

- 호박밭(Pumpkin Patch)·유령 숲(Haunted Hollow)·핼러윈 대사: 구역이 숨겨져 있음(`Halloween.Enabled=false`).
- 일자리 게시판의 카드별 착한/장난 설명 줄, 분실물 센터 상세, 대장간 주문(Commission), 채집·제작·약·연구·장비 기능 글: 스위치가 꺼져 있고 아직 게임에 안 나옴.
- 설정·키 바꾸기·가방·상점 UI 글자, 랭킹/가챠/상품 글, Help 창의 PvP 규칙 긴 설명, 몬스터 이름표 전체 목록, 무기 이름 전체 목록은 UI 글자 위주라 뺐음.
- `[숨김]`으로 적은 글은 코드에서 쓰는 곳을 찾아보고 정한 것입니다. 이름이 동적으로 불러지는 글은 놓쳤을 수 있습니다.

## 10/13 새 글 (첫 무기 새 흐름, 서버)

| 영어 | 한국어 뜻 | 메모 |
|---|---|---|
| New weapons drop from monsters! | 새 무기는 몬스터가 떨어뜨려요! | 대장간에서 안 가진 무기를 사려고 할 때 · `Text.WeaponDropOnly` |
| The King Slime dropped [%s]! | King Slime이 [%s]을(를) 떨어뜨렸다! | 처음 잡은 King Slime의 철 무기 · `Loot.Text.FirstKingWeapon` · %s = 무기 이름 |
| The King Slime dropped [%s]! Equipped. | King Slime이 [%s]을(를) 떨어뜨렸다! 손에 들었어요. | 위와 같고, 손에 든 무기보다 세서 바로 낌 · `Loot.Text.FirstKingEquip` |

대장간이 무기를 안 팔 때(`WeaponShop.Buy = false`)의 다음 목표 줄(`Tutorial.Text.NextIronDrop`)·짧은 이름(`ShortNames.IronDrop`)과 화면 쪽 이름 바꾸기(스킬 Bat Zigzag, 마을 반응 줄의 Rose)는 게임성 개발 1 가지(fix/test-prep-client)에서 들어옴.
