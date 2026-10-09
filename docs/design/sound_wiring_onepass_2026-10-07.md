# 소리 연결 한 번에 — Config.Audio 붙여 넣기 (2026-10-07, 소리 만들기 → 게임성 개발 1)
> 기록용(10/07 당시). 지금과 다른 점: 이 조각은 이미 `Config.Audio`에 들어갔고(ab708339) 옛 ogg 30개 정리도 끝남(55fe9a11) — 맨 아래 줄대로 `art/sfx/*.ogg`를 지우지 말 것: 남은 `SwingMage.ogg`·`SwingTamer.ogg`는 지금도 씀(`asset_ids.json` "kept"). 다시 붙여 넣지 말 것 — 지금 값은 `Config.Audio`(src/ReplicatedStorage/Shared/Config.luau)를 볼 것.

`py tools/sfx_wiring_check.py --ref origin/main` 결과(옛 id 8 · 빈 칸 4 · 새 이벤트 15)를 한 번에 넣는 조각이에요. 값은 `art/sfx/asset_ids.json` "ids"(새 57개)·"kept"(SwingMage·SwingTamer)와 설계표 `tools/sfx_spec.json` 볼륨에서 뽑았어요. `src/`는 소리 만들기가 고치지 않아요 — 아래를 개발 1이 넣고, 넣은 뒤 `py tools/sfx_wiring_check.py`가 '옛 id 0 · 빈 칸 0'이면 끝이에요.

## 1. Files 블록 통째로 바꾸기

```lua
	Files = {
		SwingWarrior = "rbxassetid://114585478722203",
		SwingMage = "rbxassetid://136838684864577", -- the Guild's alchemist (no faction file)
		SwingMageHalo = "rbxassetid://101498441090410",
		SwingMageHorns = "rbxassetid://139514092831666",
		SwingArrow = "rbxassetid://76900813038959", -- sound_gaps A1: one arrow, no twang
		SwingTamer = "rbxassetid://126503879214394",
		HitSoft = "rbxassetid://96440842663562",
		HitHeavy = "rbxassetid://95463530376920",
		HitCrit = "rbxassetid://78018534821425",
		HurtBig = "rbxassetid://73666772845621",
		KillPop = "rbxassetid://117802423144289",
		ComboCoin = "rbxassetid://132925998560879",
		ComboMilestone = "rbxassetid://73147095978331",
		LevelUp = "rbxassetid://108525821312554",
		PowerUp = "rbxassetid://118952858498086",
		Jump = "rbxassetid://119789949243782",
		WindowOpen = "rbxassetid://129419018750436",
		WindowClose = "rbxassetid://86085176622331",
		Deny = "rbxassetid://124536292557880",
		AutoOn = "rbxassetid://90300088723425",
		AutoOff = "rbxassetid://128226305896103",
		Purify = "rbxassetid://126260420453106",
		Purify_b = "rbxassetid://75155843966047",
		Devour = "rbxassetid://118262766439187",
		PumpkinKing = "rbxassetid://112500082253148",
		GhostKing = "rbxassetid://100319357258743",
		GooseHonk = "rbxassetid://115693307820380",
		QuestDone = "rbxassetid://131457371135343",
		GoldPickup = "rbxassetid://119243238199900",
		ScrollSuccess = "rbxassetid://116061752455414",
		ScrollFail = "rbxassetid://124525939049830",
		Tap = "rbxassetid://118436931537673",
		SkillHalo = "rbxassetid://75898672312875",
		SkillHorns = "rbxassetid://110780992455213",
		Potion = "rbxassetid://133789691162407",
		QuestNew = "rbxassetid://123199271616228",
		RankDown = "rbxassetid://81421593114766",
		TalkBlip = "rbxassetid://94593126133806",
		Equip = "rbxassetid://132294814566104",
		SkillReady = "rbxassetid://99319219774246",
		Spend = "rbxassetid://80768400627761",
		RankUp = "rbxassetid://84902463002053",
		SkillLearn = "rbxassetid://113535664889883",
		GooseArrive = "rbxassetid://113800368972766",
		-- new events (sound_gaps B1-B14): wire their hooks below
		CrownHalo = "rbxassetid://123752635254582",
		CrownHorns = "rbxassetid://131150435186247",
		KingDefeat = "rbxassetid://115530599858312",
		WarFinal30 = "rbxassetid://102592807006385",
		CountTick = "rbxassetid://96016194154678",
		GooseEnd = "rbxassetid://103362677938359",
		KaijuSiren = "rbxassetid://110447360461794",
		KaijuStomp = "rbxassetid://82058880758348",
		ZoneEnterPvP = "rbxassetid://104461336219672",
		GoldenSpot = "rbxassetid://128057879317544",
		KO = "rbxassetid://137556643487651",
		Respawn = "rbxassetid://128867123359602",
		Plunder = "rbxassetid://74602898707411",
		JackpotOther = "rbxassetid://99814762304779",
		Loot = "rbxassetid://114739645345413",
	},
```

바뀌는 줄: GooseHonk · ScrollSuccess · SwingWarrior · KillPop · ComboMilestone · LevelUp · Tap · WindowOpen(옛 id → 새 id), Spend · RankUp · SkillLearn · GooseArrive(빈 칸 → id), 새 15줄.

## 2. Sounds에 더할 줄(새 이벤트 15개)

```lua
		CrownHalo = { File = "CrownHalo", Volume = 0.70, Speed = { 1, 1 }, Max = 1, Gap = 60 }, -- B6 war round won by Halo (everyone; a draw has none); the chest reward 1.5 s later
		CrownHorns = { File = "CrownHorns", Volume = 0.70, Speed = { 1, 1 }, Max = 1, Gap = 60 }, -- B6 war round won by Horns
		KingDefeat = { File = "KingDefeat", Volume = 0.65, Speed = { 1, 1 }, Max = 1, Gap = 10 }, -- B11 a king is beaten; contributors' KillPop + coin 0.25 s later
		WarFinal30 = { File = "WarFinal30", Volume = 0.50, Speed = { 1, 1 }, Max = 1, Gap = 60 }, -- B7 once per round at 30 s left (WarRoundEndsAt), faction set, joined > 30 s ago
		CountTick = { File = "CountTick", Volume = 0.40, Speed = { 1, 1 }, Max = 1, Gap = 0.5 }, -- B7 3-2-1 before a reveal: SpeedMul 1.0 / 1.12 / 1.26
		GooseEnd = { File = "GooseEnd", Volume = 0.50, Speed = { 1, 1 }, Max = 1, Gap = 5 }, -- B3 Fx GooseEnd near the camera; the reward is GoldPickup 1.5 s later
		KaijuSiren = { File = "KaijuSiren", Volume = 0.70, Speed = { 1, 1 }, Max = 1, Gap = 30 }, -- B5 KaijuPhase -> 'Siren'; CountTick follows
		KaijuStomp = { File = "KaijuStomp", Volume = 0.45, Speed = { 0.97, 1.03 }, Max = 2, Gap = 1 }, -- B4 Fx Stomp: Volume x1 within 15 studs -> 0 at 60
		ZoneEnterPvP = { File = "ZoneEnterPvP", Volume = 0.45, Speed = { 1, 1 }, Max = 1, Gap = 10 }, -- B9 ZonePvP false->true, not within 3 s of a spawn / teleport, nothing on leaving
		GoldenSpot = { File = "GoldenSpot", Volume = 0.40, Speed = { 1, 1 }, Max = 1, Gap = 10 }, -- B8 a golden monster first in view within 50 studs (once per monster); GoldenKill = same file
		KO = { File = "KO", Volume = 0.40, Speed = { 1, 1 }, Max = 1, Gap = 2 }, -- B1 Fx KO (mine): cartoon dizzy, no death jingle
		Respawn = { File = "Respawn", Volume = 0.40, Speed = { 1, 1 }, Max = 1, Gap = 1 }, -- B1 my character comes back after a KO
		Plunder = { File = "Plunder", Volume = 0.40, Speed = { 1, 1 }, Max = 1, Gap = 1 }, -- B2 my sack / pocket is taken (the victim only; the taker hears GoldPickup)
		JackpotOther = { File = "JackpotOther", Volume = 0.40, Speed = { 1, 1 }, Max = 1, Gap = 30 }, -- B10 someone else's Jackpot / FirstMax line (not RareWeapon)
		Loot = { File = "Loot", Volume = 0.45, Speed = { 1, 1 }, Max = 1, Gap = 0.3 }, -- B14 Fx Loot with a scroll or a weapon (weapon SpeedMul 0.92); materials / potions silent
```

## 3. 값 바꾸기(이미 있는 줄)

- `Tap` Volume 0.42 → **0.46** (7번 묶음 새 Tap, TalkBlip보다 +3 LU — 설계서 범위 0.42~0.50)
- `GooseHonk` Volume 0.55 → **0.40** (설계표 값. 새 파일은 '꽉!' 한 번이라 0.55면 커요 — 게임에서 들어 보고 정해도 돼요)
- `ComboMilestone`: 단계마다 높일 때 **최대 1.15배**(끝음 4.8 kHz, 설계서 '5 kHz 아래')
- `Duck.By`에 `CrownHalo = true, CrownHorns = true, KaijuSiren = true` 더하기(설계서 4-2 #10, GooseArrive는 이미 있음)

## 4. 이벤트 연결(어디서 틀지) — `docs/design/sound_gaps_2026-10-07.md` 번호

| 키 | 신호 | 비고 |
|---|---|---|
| KO / Respawn | Fx "KO"(나에게만, CombatService) / KO 뒤 CharacterAdded | |
| Plunder | Fx "Plunder"(PvPService는 모두에게 `{From, To, Amount}`) | 피해자 id가 없어 개발 2 필드 필요(B2) |
| GooseEnd | Fx "GooseEnd"(모두에게) | 카메라 가까이일 때만 |
| KaijuStomp | Fx "Stomp"(모두에게, Pos) | 거리로 볼륨 |
| KaijuSiren | GameState `KaijuPhase` → "Siren" | |
| CrownHalo / CrownHorns | 전쟁 판 끝 `NotifyAll(WarWin[winner])`에 Sound 없음 | 개발 2가 Sound 필드(B6) 또는 클라가 판 끝 감지 |
| WarFinal30 / CountTick | GameState `WarRoundEndsAt` 클라 타이머 | 서버 신호 없음 |
| GoldenSpot | 몬스터 `Golden` 속성 + Fx Reward `Golden=true`(GoldenKill) | |
| ZoneEnterPvP | 내 `ZonePvP` false→true | |
| JackpotOther | AnnounceService → Announce.luau의 남 Jackpot·FirstMax 줄 | |
| KingDefeat | HalloweenService `finish(b, true)` | 신호 필요(개발 2, B11) |
| Loot | Fx "Loot"(LootService) Items에 Enhance·Transfer 주문서나 Weapon | |

연결 + Play 확인(폰 흉내 HitSoft 포함) 뒤 소리 만들기가 옛 id("old" 30개)와 `art/sfx/*.ogg`를 정리해요.
