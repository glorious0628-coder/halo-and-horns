# TECH_SPEC addendum (authoritative; read together with TECH_SPEC.md)

## A1. Custom 3D model override (monsters, bosses, golden goose)

The game must run with the procedural Part-built rigs, but the creator will later drop in custom 3D models
(made from images via Tripo 3D, imported with Studio's 3D Importer). Support this WITHOUT code changes:

- Folder `ServerStorage.CustomModels` (created by MapBuilder or MonsterService at start if missing; may be empty).
- For a monster with Config id `<Id>` (e.g. `Slime`, `BigSlime`, `Goblin`, `GoblinBrute`, `Skeleton`, `SkeletonKnight`)
  and for the golden goose (`GoldenGoose`): if `ServerStorage.CustomModels:FindFirstChild(<Id>)` is a `Model` (or a
  `MeshPart`/`BasePart`), the owning service uses a CLONE of it as the VISUAL body instead of the procedural body:
  - Keep the existing gameplay rig (invisible HumanoidRootPart + Humanoid + hitbox) exactly as specified; the custom
    visual is purely cosmetic.
  - Every BasePart of the clone: `Anchored = false`, `CanCollide = false`, `CanQuery = false`, `CanTouch = false`,
    `Massless = true`; weld every part to the root with `WeldConstraint`s.
  - Scale the clone (`Model:ScaleTo`, or `Size` for a single part) so its bounding-box height matches the procedural
    body's height for that monster (`Config.Monsters[Id].Scale` etc.), then position it so its bottom sits on the floor
    under the HumanoidRootPart and it faces the root's LookVector.
  - Golden (4% variant) monsters: tint the custom visual by adding a gold `Highlight` (FillColor gold, FillTransparency ~0.5)
    instead of recoloring parts.
  - Simple "alive" motion for custom visuals: a small vertical bob/squash tween is enough (no animations required).
- Owners: MonsterService (monsters), the service that spawns the golden goose (goose). Print once per Id at startup:
  `[MonsterService] custom model for <Id>: yes/no`.

## A2. Process note

Spec revision may still have open contract nits; when the spec is ambiguous, pick the interpretation that keeps your
file's public API exactly as written in TECH_SPEC.md and report it under integrationRisks.

## A3. Mandatory fixes from pre-implementation review (override TECH_SPEC where they conflict)

- **DataService session lock (H1):** never write `copy.SessionLock = release and nil or {...}` (Lua and/or pitfall: always
  yields the table). Use:
  `if release then copy.SessionLock = nil else copy.SessionLock = { JobId = game.JobId, Time = os.time() } end`.
- **Monster Humanoids (H2):** on every monster rig: `hum.RequiresNeck = false`; disable states
  `Dead, FallingDown, Ragdoll, Seated, Climbing, Swimming, PlatformStanding` via `hum:SetStateEnabled(state, false)`
  (death is handled by the service's own HP, not Humanoid state); `hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff`;
  `hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None`. Knockback must not topple them.
- **Manual beats auto (H3):** manual and auto swings share the swing cooldown, but record `lastManualAt[player]`; the auto
  loop skips a player while `os.clock() - lastManualAt[player] < cls(player).SwingInterval + Config.Combat.ManualYieldPad`
  (0.3; R1 CR-M17 — the old fixed 1.0 s was not longer than the Warrior/Mage interval). A manual swing request is accepted
  whenever the cooldown is ready (never silently dropped because auto consumed it).
- **Top bar inset (H4, revised by R1 CR-L34):** every own ScreenGui sets `IgnoreGuiInset = true` and then
  `ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets` + `SafeAreaCompatibility = Enum.SafeAreaCompatibility.None` (each in
  pcall), so content stays out of notches / the home indicator but still extends under the Roblox top bar. Therefore every
  top-anchored HUD block must still start at `Y >= GuiService:GetGuiInset().Y + 8` (fallback 64 px), and code that maps
  screen pixels into the gui must use the gui's own AbsolutePosition (it is no longer always 0,0). Never place UI in the
  top-left 0..64 px band.
- **Mobile jump button (H5):** on touch devices, read `PlayerGui.TouchGui.TouchControlFrame.JumpButton`
  (WaitForChild with 5 s timeout) AbsolutePosition/AbsoluteSize and place the main attack button up-left of it
  (fallback offset (-200, -170) from bottom-right); place release/auto buttons relative to the attack button. Re-layout on
  `workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize")`.
- **Readable text (M1):** UIScale = clamp(viewportY / 720, 0.75, 1.25); every TextLabel/TextButton gets a
  `UITextSizeConstraint` with `MinTextSize = 11` (or uses TextScaled with MinTextSize 11).
- **Monster density (M2):** add `Config.MonsterDensity = { ExtraPerPlayer = 2, MaxZoneMult = 2 }` (G1 owns Config: add it).
  Per monster type, target count = `min(def.Count + ExtraPerPlayer × max(0, playersInZone - 1), def.Count × MaxZoneMult)`,
  still respecting the global monster cap. MonsterService re-evaluates every ~5 s.
- **AFK in PvP hint (M3):** when a player with auto-attack ON takes PvP damage, show once per 60 s a toast
  "공격받는 중! 공격 버튼으로 반격하세요" (rules unchanged: auto never hits players).
- **Monster leash anti-jitter (M4):** monsters never target players standing in a town/safe zone; when a monster's
  target enters a safe zone, it returns home and cannot re-aggro for 3 s.
- **Enemy towns (L1):** a player who enters the OTHER faction's town (HaloTown/HornsTown) is teleported to the
  Crossroads spawn with toast "상대 진영 마을에는 들어갈 수 없어요!". Exception: none (a kaiju is also bounced; a sack
  carrier is also bounced and the sack keeps its state).
- **Rebirth resets (L2, decision):** rebirth resets Level, XP, carried gold, bank gold and weapon tier (standard
  simulator rebirth). It keeps: rebirth bonus, marks (타락/구원), tickets, faction scores (honor/infamy), cheer stars,
  daily-quest state, class, titles.
- **Quests (L3):** release/skill-type quest progress counts auto-releases too (brainless by design).

## A4. First-60-seconds onboarding (new; small)

- Persisted data field `TutorialStep` (number). Default for brand-new players 0; data migrated from older versions gets 99
  (done). Mirrored to Player attribute `TutorialStep`. Owner of transitions: **QuestService**.
- Step 0 (after the first faction+class pick and first spawn): QuestService calls
  `MonsterService.SpawnPersonal(player, "Slime", { Golden = true, HP = 10 })` — a monster placed ~8 studs in front of the
  player's spawn that only that player can damage/aggro/get rewards from, despawning after 120 s or when the player leaves.
  (MonsterService must implement `SpawnPersonal(player, monsterId, opts) -> Model?`.) On that kill → step 1.
- Step 1: client (the HUD module) shows a `Beam` (two Attachments, no texture asset; use default) from the character to
  the Slime Meadow travel pad / zone entrance plus a BillboardGui "여기로!" there. When the server sees the player enter
  `SlimeMeadow` → step 2 and the client removes the guide.
- Step 2: a pinned tutorial quest "말랑 슬라임 5마리 잡기" (reward 120 gold, enough with starting gold for the 2nd weapon
  tier in ~60 s) shown above the normal quest list; on claim → step 99. It does not replace daily quests.
- Every step is skippable by just playing; nothing blocks input; the whole tutorial must never error if the player
  leaves mid-way.

## A5. Clarifications to A3/A4 (review round 1.5; authoritative)

- **C1 Monster cap:** `Config.MonsterDensity = { ExtraPerPlayer = 2, MaxZoneMult = 2, GlobalCap = 72, ReevalInterval = 5 }`
  (if the revised spec adds zones, GlobalCap = round(sum of base Counts × 1.7)). Reducing density never despawns living
  monsters; it just skips respawns until under target.
- **C2 Personal monsters:** monster records get `Owner: Player?`. `GetMonstersInRadius(pos, r, forPlayer?)` and
  `CountInRadius(pos, r, forPlayer?)` — when `forPlayer` is given, return only monsters with `Owner == nil or Owner == forPlayer`;
  CombatService ALWAYS passes the attacking player. `DamageMonster` ignores (returns false) when `record.Owner and record.Owner ~= player`.
  Kills of personal monsters give 0 war points and personal monsters are excluded from density counts and from the goose/kaiju
  logic. (If the revised spec names these functions differently, apply the same optional `forPlayer` parameter to its equivalents.)
  R1 CR-M5 adds a zone filter on top of this (zone monsters only in the zone the player stands in) — see A16-6.
- **C3 Personal monster AI:** for `Owner ~= nil` monsters skip town/leash/home logic entirely; they only track their Owner
  (standing still is fine when the owner is in a town — it is a sandbag).
- **C4 Tutorial can't get stuck:** if the personal slime despawns by timeout, advance to step 1 automatically. On every
  character spawn, if `TutorialStep` is 0 or 1, (re)start that step (respawn the personal slime for step 0 if none exists).
- **C5 New vs migrated:** set `TutorialStep = 0` only when the data was freshly created in this Load (no stored record);
  any loaded stored record lacking the field gets 99. Apply this BEFORE generic default-filling.
- **C6 Tutorial quest delivery:** quests use a claim button (the revised spec's quest-claim remote). The tutorial quest is
  delivered as the FIRST element of the `QuestsJson` array with `Pinned = true`; it has no slot index, cannot be rerolled,
  and is claimed through the same claim remote (identify it by an id such as `"tutorial"`). On claim → TutorialStep 99.
- **N1 Quest addressing:** every `QuestsJson` entry carries `Id` (string) and `Slot` (number; `nil` for the pinned tutorial).
  Clients NEVER send array indices: reroll sends `entry.Slot`; claim sends `entry.Slot` or the string `"tutorial"`.
  Server claim handler accepts only `"tutorial"` (string) or an integer `1..Config.Quests.Slots` (or the revised spec's
  equivalent slot count); reroll accepts only that integer range.

## A6. Third playable faction: NEUTRAL (중립 · 장인 길드) — USER DECISION, core rules now, crafting perks in phase 2

Faction ids become `"Halo"`, `"Horns"`, `"Neutral"` (playable) and `"None"` (not chosen yet — unchanged meaning).
All code that branches on faction must handle `"Neutral"` explicitly (never assume "not Halo ⇒ Horns").

- **Config.Factions.Neutral** (G1 adds it next to Halo/Horns, same shape; numbers neutral):
  `Id = "Neutral", Name = "장인 길드", Short = "장인", Emblem = "장", TeamName = "장인 길드", TeamColor = BrickColor.new("Medium stone grey")`
  (Emblem was "⚙" until R1 CR-L44: that glyph renders as a tofu box; TeamColor/Color became teal in A9-1),
  every combat/economy perk multiplier = 1.0 / 0 (no XP bonus, no gold bonus, no HP/damage bonus, no lifesteal, no regen bonus),
  release: no heal/no stack sharing, cap 150 (Halo-like cap, no Halo extras), home zone = `Crossroads`.
  Story line for the picker card: "조각을 줍지 않고, 다듬기로 한 자들." Add a third Team in the Teams service.
- **Class display names for Neutral:** Warrior → "대장장이", Mage → "연금술사", Archer → "사냥꾼" (same combat shapes/stats as the class).
- **PvP:** Neutral players can never attack players and can never be damaged by players (manual swing, release, stomp,
  anything) in any zone. They never get/give plunder, sacks, wanted stars, bounty, bully stacks, revenge, kaiju.
  Rookie protection rules are irrelevant for them.
- **War / Size Justice / underdog:** Neutral players contribute 0 war points, receive no war blessing, are excluded from
  faction power sums and from all faction ratio computations (ratios are Halo vs Horns only); their Size-Justice S is always 1.0.
- **Golden Goose:** Neutral players cannot add tug counts (their swings on the goose count 0) and get no tug rewards
  (phase 2 may give them a material instead).
- **Towns:** Neutral's home/respawn is the Crossroads town. Neutral players may enter neither HaloTown nor HornsTown (bounced to
  Crossroads like the enemy-town rule); Halo/Horns may enter Crossroads as before.
- **Faction picker:** three big cards (빛의 기사단 / 뿔 군단 / 장인 길드), the third with the note "싸움 버프 없음 · PvP 없음 · 제작 특화(곧 추가)".
  The +300 starting-gold underdog bonus applies only between Halo and Horns.
- **Faction change** (altar/tickets/rebirth): Neutral is a valid target. Neutral has no faction score of its own yet
  (phase 2 adds 장인 명성), so a FREE switch away from Neutral loses nothing; switching away from Halo/Horns follows the
  existing free/ticket rule. Turncoat marks are granted only for Halo↔Horns switches at rebirth.
- **Daily quests:** the pool must be filtered by faction; Neutral never gets PvP/plunder/bounty/goose/kaiju quests.
- **Visuals:** no halo/horns; nametag with the Neutral emblem prefix ("장", CR-L44) in the Neutral colour (A9-1).

## A7. Lessons from the "Soul RPG" playtest video (authoritative; if a name differs from the revised spec, follow the revised spec's name)

- **A7-1 Spawn where players are starving (MonsterService, cost S):**
  `Config.SpawnSpread = { Enabled = true, StarvedThreshold = 2, MinDist = 18, MaxDist = 28, Tries = 6 }` (G1 adds it).
  On each (re)spawn of a non-personal monster: among alive players inside `def.Zone` (not in a town, any faction),
  pick the one with the smallest `CountInRadius(root.Position, 30, player)`; if that count < StarvedThreshold, try up to
  `Tries` random points 18–28 studs from that player that are inside `def.Zone` (respecting the zone inset); fall back to
  the normal random point. A7-1 decides only WHERE; A5-C1 decides HOW MANY. Check: two players standing at opposite ends
  of Slime Meadow both get monsters approaching within 5 s.
- **A7-2 Faster early levels (Config only, cost S):** `Config.Levels.EarlyUntil = 10`, `Config.Levels.EarlyMult = 0.5`;
  `XPToNext(level)` multiplies by EarlyMult (min 1) when `level < EarlyUntil`. Target: Lv 10 in about 10–12 minutes of
  slime hunting for a new player. If gold then feels slow, raise monster Gold, not XP.
- **A7-3 "Next goal" display (client-only, cost S–M):**
  - Own level-up announce: "레벨 업! Lv N · 다음 해금: Lv M <내용>", and on reaching an unlock level "해금! <내용>". The unlock
    list is derived on the client from existing Config (auto-attack unlock level, zone MinLevel, weapon MinLevel, rebirth level).
  - Story one-liners (≤ 30 chars) only at those unlock moments and only while Rebirths == 0:
    `Config.StoryLines = { GoblinWoods = "...", SkeletonRuins = "..." }` (G1 writes them in the crown-shard voice).
  - Upgrade button second line: when the level allows but gold is short → "<몬스터 이름> N마리 더!" with
    N = ceil(shortfall / average gold of the player's last 10 kill rewards) (if N > 99 keep the normal text). The first
    moment it becomes affordable (once per tier per session): gold pulse + coin sound + toast "<무기> 살 수 있어요!".
  - Implement the A4 beam as `HUD.ShowGuide(part, text)` / `HUD.ClearGuide()` and reuse it when reaching Lv 10 / Lv 25
    (guide to the GoblinWoods / SkeletonRuins pad or gate; cleared on entering or after 90 s). The Travel panel marks the
    recommended zone for the current level with a "추천" badge.
  - Lowest priority (drop first if over budget): ShowGuide reuse → the affordable pulse.
- **A7-4 Pick/change screens (checklist for ClassPicker/FactionPicker/Panels/MonetizationService):**
  - Class cards: faction-specific name + "(전사/마법사/궁수)" + one action line from `Config.Classes[id].PickLine`
    (Warrior "가까이 붙어서 주변을 한 번에 쾅", Mage "조금 떨어져서 넓게 펑", Archer "멀리서 하나씩 슝"); Warrior shows
    "처음이면 추천". Faction → class → play in 3 taps. No gacha/draw animation at start.
  - Altar / class-change panels: two equal-size buttons. Under [무료로 바꾸기] show the exact loss as numbers
    ("명예 340 초기화" / "Lv 23 → Lv 1"); under [티켓으로 바꾸기 (보유 N장)] show "전부 유지". With 0 tickets that button
    becomes a purchase button; NEVER auto-use a ticket after purchase. When the free option loses nothing (leaving Neutral),
    hide the ticket button.
  - Cooldown / 0 wanted stars / not-in-combat / no sack / not kaiju apply identically to free and ticket paths.
  - ProcessReceipt: registered in exactly one service, idempotent: data not loaded → NotProcessedYet; PurchaseId already
    processed → PurchaseGranted; new → ticket +1, record PurchaseId (keep last 50), save immediately; return PurchaseGranted
    only if the save succeeded (otherwise roll back and return NotProcessedYet).
- **A7-5 No player-player collision (cost S):** register PhysicsService collision group "Players" (not collidable with
  itself) at server start and assign every character BasePart on CharacterSpawned / DescendantAdded. Prevents body-blocking
  trolls (Neutral is PvP-immune and could otherwise shield wanted players or block paths). Owner: PlayerService.

## A8. Pre-built preview map

The Studio place already contains `workspace.Map` built by `tools/preview_map.lua` (same folder structure as the
MapBuilder contract: Ground, Zones, Walls, Gates, Pads, Landmarks incl. `Altar`+`AltarPrompt`, `MostWantedBoard.BoardGui.BoardText`,
Decor, a `PreviewSpawn` SpawnLocation, market stalls and an `ArtisanGuild` model in Crossroads). MapBuilder (G3) must REUSE an
existing `workspace.Map`, create any required instance that is missing (e.g. the goose perch, pads, altar prompt), and when
building from scratch reproduce the same look (read `tools/preview_map.lua` for the part recipes and coordinates).

## A9. Post-implementation items (applied in the review/fix phase)

- **A9-1 Neutral identity (G1, G5, G10):** `Config.Factions.Neutral.Color = Color3.fromRGB(40, 200, 190)` and
  `TeamColor = BrickColor.new(Color3.fromRGB(40, 200, 190))` (teal; grey stays reserved for 회색 전설/금 간 후광).
  Nametag and `UIKit.Theme` neutral colors read this Config value (no hard-coded grey). CharacterVisuals FactionMark gets
  a Neutral branch: a teal Neon gear 1.6 studs above the head (one thin Cylinder + two small Blocks, ≤ 3 parts, does not
  grow with rank). Check: the 3 Teams have distinct TeamColors; from 30+ studs Halo/Horns/Neutral/None are distinguishable by
  colour AND silhouette.
- **A9-2 Hit feel (G1, G11 Fx only):** `Config.HitFeel = { FlashTime = 0.06, PopScale = 1.4, PopTime = 0.1, MergeWindow = 0.25 }`.
  White flash: for my own Swing/Release hit positions, monster models in `workspace.Monsters` within 3 studs → locally set
  their part Colors to white for FlashTime then restore (store original colors once per flash start so rapid hits never
  "stick" white; skip custom-model visuals; no Highlight). Number pop: only crits and my Release numbers scale 1.4 → 1.0 in
  0.1 s. Merge: numbers spawned within 3 studs and 0.25 s add into the existing label. Other players' swing numbers: show
  crits only (protect the 25-label pool). No hit-stop, no extra screen shake.
- **A9-3 Lighting rule:** never add an `Atmosphere` to Lighting (it overrides FogColor/FogEnd that WarService animates) and
  never add per-zone ColorCorrection effects (they dilute `WarTint`). Zones are distinguished by floor colour/material only.
- **A9-4 Darker default lighting (user feedback "조명이 너무 허옇다"):** `Config.Sky.Neutral` becomes
  `ClockTime = 15, Brightness = 1.6, Ambient = (60,60,75), OutdoorAmbient = (105,105,120), FogColor = (150,180,225), FogEnd = 1800`
  (+ `FogStart = 250`, `ExposureCompensation = -0.25` applied once by WarService.Start). Scale Dawn/Eclipse Brightness and
  Ambients down by the same ratio (×0.65 brightness, ambients −40). Bloom Intensity 0.3 / Threshold 1.5. Floor colours:
  HaloTown (228,218,190), Crossroads (190,176,150), SkeletonRuins (135,125,108).

## A10. World layout v3 — RPG continent + faction islands (USER DECISION "장소가 떼거지로 있다" + "rpg랑 섞어봐")

Applied in the Studio preview map (`tools/preview_map.lua` v3). Config must match (patched by the lead after implementation):
- Zones (Size unchanged): Crossroads (0,0,0); HaloTown Center (0,0,-400) Spawn (0,0,-410); HornsTown Center (0,0,400)
  Spawn (0,0,410); SlimeMeadow Center (330,0,0) Spawn (220,0,0); GoblinWoods Center (720,0,0) Spawn (590,0,0);
  SkeletonRuins Center (1120,0,0) Spawn (980,0,0). Outskirts Center (595,0,0) Size (1450,0,1040).
- `Config.Map.Bounds = { MinX = -130, MaxX = 1320, MinZ = -520, MaxZ = 520 }`.
- `Config.Map.Gates`: SlimeMeadow (200,0,0), GoblinWoods (570,0,0), SkeletonRuins (960,0,0), HaloTown (0,0,-320), HornsTown (0,0,320).
- Crossroads internals unchanged (Altar, Board, Pads, Fountain, goose nest).
- Land: continent pieces x [-110,115], [155,490], [530,1300] × z [-175,175] (rivers between them, bridges at z=0),
  islands x [-110,110] × z [-500,-300] / [300,500] (sea between, bridges at x=0). Terrain Water surface Y = -1.2 everywhere
  else. Mountain pass (Terrain Rock) at x≈915 between GoblinWoods and SkeletonRuins, road corridor |z| < 20.
- Gameplay implications: players can fall into water and swim (Humanoid Swimming allowed for players; monsters keep it
  disabled and must never path into water — clamp monster wander/spawn points to their zone rect, which is all land).
  If a player ends up below Y = -20 (anywhere), ZoneService teleports them to their home spawn.
- **A10 Config data for MapBuilder (G1 adds; values = preview v3):**
  `Config.Map.WaterTop = -1.2`, `Config.Map.PassX = 915`,
  `Config.Map.Lands = { {Name="LandCrossroads",MinX=-110,MaxX=115,MinZ=-175,MaxZ=175}, {Name="LandMeadow",MinX=155,MaxX=490,MinZ=-175,MaxZ=175}, {Name="LandWild",MinX=530,MaxX=1300,MinZ=-175,MaxZ=175}, {Name="IslandHalo",MinX=-110,MaxX=110,MinZ=-500,MaxZ=-300}, {Name="IslandHorns",MinX=-110,MaxX=110,MinZ=300,MaxZ=500} }`,
  `Config.Map.Bridges = { {Name="Meadow",From=(113,0,0),To=(157,0,0),Width=18}, {Name="Goblin",From=(488,0,0),To=(532,0,0),Width=18}, {Name="Halo",From=(0,0,-173),To=(0,0,-302),Width=18}, {Name="Horns",From=(0,0,173),To=(0,0,302),Width=18} }`.
- **A10-V3-1 (G3 MapBuilder):** `Ground.OutskirtsGround` from TECH_SPEC v2 is DELETED in v3 — never create a ground plate
  covering the Bounds (it would cover the sea and rivers). Ground = `Config.Map.Lands` parts + Terrain sea. When building
  from scratch (no `workspace.Map`), reproduce the Terrain recipe of `tools/preview_map.lua` (sand bed, water FillBlock,
  PassX mountains, coastal hills, island rocks) and the bridges. Release builds are made from the Studio-saved place
  (which contains the terrain), not from `build_place.py` output.
- **A10-V3-2 (G5 MonsterService):** monsters must never enter water. (a) Target candidates only players with
  `Config.ZoneAt(targetRoot.Position).Id == record.ZoneId` (personal monsters exempt). (b) Clamp every MoveTo destination
  into the monster's own zone rect inset by 6 studs. (c) If `Config.ZoneAt(root.Position).Id ~= record.ZoneId` or
  `root.Position.Y < -3` → MoveTo(Home) + 3 s no re-aggro (reuse M4); if `Y < -8` for more than 2 s → PivotTo(Home).
  This also recovers monsters knocked back by Release.
- **A10-V3-3 (G7 PvPService, design adopted):** with wide safe Outskirts between zones, `CanAttack` uses
  `inPvP(p) = IsPvPZone(p) or (not IsTown(p) and S.CombatService.IsInCombat(p))` and requires BOTH players `inPvP` —
  a combat tag (15 s) keeps you attackable in Outskirts/bridges until you reach a town or stay out of PvP damage for 15 s.
  Neutral, rookie and spawn-protection exceptions unchanged.

## A11. Elden-Ring-style world mood (USER DECISION "젤다처럼 전체 맵이 안 보이게", "엘든링처럼")

- World = Terrain landscape (no flat slabs): each hunting region is a valley enclosed by Terrain mountain ridges with
  openings only at gates/bridges/roads; faction islands have coastal cliff ridges. From the ground you see only the current
  region + distant landmarks. Zone floor parts stay for the MapBuilder contract but are `Transparency = 1, CanCollide = false`;
  players and monsters stand on Terrain (top at Y = 0 inside zones).
- Landmark: a giant broken "Crown of Balance" floats above Crossroads at about (0, 350, 0) (radius ≈ 80), visible from
  every region; the fountain shard's beam rises to it.
- `Config.Sky.Neutral` (supersedes A9-4): `ClockTime = 16.8, Brightness = 1.8, Ambient = (70,60,55), OutdoorAmbient = (120,105,90),
  FogColor = (190,170,140), FogStart = 200, FogEnd = 1600, ExposureCompensation = -0.1`; Dawn/Eclipse keep their hues but use
  FogStart 200 and FogEnd 1600 (A11-R4). Bloom Intensity 0.4.
- Later (not now): map fragments that reveal each region on the world map; checkpoint "grace" lights that point the way.
- A11-R1..R5 (review session): ground raycasts include only Terrain/Map.Ground/bridges; MaxSlopeAngle 46 for players and
  monsters; MapBuilder from-scratch = minimal + warning (release from the Studio-saved place); FogEnd 1600; monster
  stuck detection (moved < 1 stud in 1.5 s → new destination).

## A12. Players never see the whole world — only the World Map shows it (USER DECISION)

- **Camera:** on join and every CharacterAdded, server sets `player.CameraMaxZoomDistance = 40`, `player.CameraMinZoomDistance = 6`
  (PlayerService, G2). No other code may raise it (kaiju may use 60 while transformed, then restore).
- **No climbing:** MaxSlopeAngle 46 (A11-R2) for players; ridges are ≥ 50° and ≥ 30 studs tall.
- **Fog:** gameplay presets `Config.Sky.*` use `FogStart = 120, FogEnd = 650` (supersedes the 1600 of A11-R4). Distant regions
  disappear into haze.
- **Sky crown stays visible through fog:** verified in Studio — fully-fogged parts render in FogColor and stay visible as a
  golden silhouette against the (unfogged) sky, so the real crown is enough. The optional `BillboardGui` (name `CrownSkyBillboard`,
  `AlwaysOnTop = false`, `LightInfluence = 0`, `MaxDistance = 1e5`, Size in studs ≈ 200×120) on an invisible anchor part at the
  crown position (ViewportFrame clone of the crown) exists but stays `Enabled = false`; no client code needed.
- **World Map (new client module `StarterPlayerScripts/WorldMap.luau`, owner: new group G13):** full-screen panel opened by
  the Menu panel's "지도" entry and the `M` key (also a small "지도" chip on the HUD top-right under the zone pill). Draws a
  top-down map from Config only (no screenshots, no asset ids): Config.Map.Lands (land shapes), sea background, zone rectangles
  with name + level + 안전/PvP colour (ART_DIRECTION 2.4), bridges and roads, faction town icons (후광/뿔/장 — CR-L44), Crossroads
  landmarks (제단, 거래소, 거위 둥지, 이동 발판), the sky crown icon, the local player's arrow (rotates with camera/character
  heading, updates 10×/s), active event markers (golden goose when GameState says active, kaiju position if GameState exposes it,
  sack carriers for Halo only — reuse whatever EventHUD already reads). Pan by drag, zoom with wheel/pinch (0.5×–3×), close with X / M /
  Escape. Must work on mobile (touch) and never block gameplay input when closed.
- **Later (not now):** map fragments that reveal regions; until then the whole map is drawn.

## A14. Playtest feedback 2026-10-02/03 (USER: "왜 때리는 모션을 안하지?", "지금 화면이 너무 커!", "모든 디자인은 다 gpt!")
(A13 is reserved for the review round 2 block in docs/review/reviewer_spec_v2.md.)
- **A14-1 Attack motion.** Fx.luau plays Roblox stock animations on the LOCAL character only (they replicate): Warrior Swing = toolslash, Mage Swing = point, Archer Swing = toollunge; Release = the bigger move (MOTION.CLASS_MOVES). Monsters: MonsterService welds every visible part to an invisible `VisualRoot` jointed to the root by Weld `VisualJoint`; each monster hit on a player bumps model attribute `AttackSeq`; clients tween `VisualJoint.C0` locally (wind-up → lunge → return; slimes squash-hop) and give a small recoil to monsters their own hits land on. The server never writes C0 after spawn. Fx.luau is near Luau's 200-locals limit: new tunables go into the `MOTION` table.
- **A14-2 Compact HUD.** Non-touch UIScale = clamp(vy/720 × Config.UI.DesktopScaleMult 0.8, 0.6, 1.0); touch keeps A3-M1. Daily quests collapse to header + one row (header turns green with "받기 N" when claimable). Smaller stats / upgrade / menu / attack (desktop 60%, touch 85%) elements. Legacy chat window moved to bottom-left via SetCore("ChatWindowPosition"); TextChatService window is bottom-aligned in the place file.
- **A14-3 Design source.** Every visual design is generated by GPT (Codex image generation, art/prompts → art/out) and approved by the user before implementation. HUD redesign: user picked mockup C (storybook parchment) merged with A (chunky toy) — see art/out/UI_HUD_*.png.

## A15. Combat feel + pain reactions (USER: "때리는 모션 더 실감나게", "맞으면 아파하는 거 … GPT한테")
- Server: monsters wind up `Config.HitReact.MonsterWindup` (0.28 s, model attribute `WindupAt`) before the hit lands (`AttackSeq` at impact; cancelled if the target leaves range / dies). Monsters that take damage and survive bump `HurtSeq` (+ `HurtBig` for crits / ≥ 25% max HP), throttled 0.15 s. Players that take damage broadcast Fx `"Pain"` {UserId, Pos, Big} (throttled 0.4 s per victim). Swing/Release hits shove monsters 1.2–2 studs (`MonsterService.Shove`, zone/water/wall safe).
- Client (Fx.luau): procedural R15 attack/hurt clips applied through Motor6D.Transform on PreSimulation (AnimationClipProvider runtime clips are Studio-only), stock animations as fallback; slash arc / arrow trail / magic burst, hit spark, 0.05 s hit-stop on my own attack track, small camera kick, monster anticipation pose + lunge + dust, monster pain stickers (EmoOuch/Stress/Tears/Angry, EmoDizzy on big hits) and player pain stickers for everyone nearby. All GPT art parts are registered in Config.UIArt.Parts with Id = "" until uploaded; code-drawn fallbacks are used meanwhile.
- Class costumes: 18 Tripo models (art/models/costume/fixed/Costume_<Faction><Class><M|F>.glb) — 2k export, head split into its own 1024 texture, sharpened (tools/fix_face.py). Not uploaded/imported yet (account upload block 2026-10-03); avatar toggle is a user decision: costume ON by default, can be turned off.

## A16. Code review R1 fixes (docs/review/reviewer_code_r1.md; overrides TECH_SPEC and A1–A15 where they conflict)

Applied 2026-10-03 by groups G1–G12 + GW, initially without Studio. Verified afterward in GoodEvil:
all 33 Luau files compiled, sync changed 29 / kept 4, and a 15 s start test ran all 19 server services plus 8 client
modules without Luau runtime errors. Single-player UI checks passed faction/class selection, travel, map, manual/auto
combat, release, a tutorial claim paid once after a double click, goose hits, and the kaiju Siren → Active transition.
See [the verification record and screenshots](review/r1_studio_verify_2026-10-03.md) for exact scope and limitations;
DataStore was in memory mode and multiplayer/persistent-data scenarios remain unverified. CR-M24, CR-M25, CR-M26,
CR-L33 and CR-L35 were already fixed by the HUD / picker redesign. `[CR-xx]` = review item.
Config values below are the ones in Config.luau.

### A16-1 Anti-cheat movement check — LOG-ONLY for now [CR-H2]
- `Config.AntiCheat = { Enforce = false, MoveMult = 1.6, Slack = 8, RisePerSec = 60, RiseSlack = 12, TeleportGrace = 1,
  SpawnGrace = 2, PadSlack = 4, LogCooldown = 10 }`; `Config.Travel.ZoneTick` 0.5 → 0.2. A missing / non-number key uses
  the default.
- ZoneService samples each root every zone tick (`validateMove`, right after the A10 RESCUE_Y rescue). Plausible = flat move
  since the last good sample ≤ `Humanoid.WalkSpeed × MoveMult × dt + Slack` and rise ≤ `RisePerSec × dt + RiseSlack`
  (falls are never limited). An implausible move is logged at most once per `LogCooldown` s per player. Only when
  `Enforce == true` is the player pulled back to the last good position; in log-only mode the new position simply becomes
  the last good one.
- `ZoneService.IsPlausible(player, pos) -> boolean`: same test against the last sample; true when there is no sample yet,
  the character is new, the player is in teleport/spawn grace or the input is invalid. Logs failures; returns **false only
  while `Enforce == true`**, so callers can never punish anyone in log-only mode. Callers (all pcall'd, only if present):
  CombatService Swing / Release, FactionService.nearAltar.
- `ZoneService.MarkTeleported(player, seconds?)`: call right BEFORE a server-side teleport; every move is accepted for
  `seconds` (default `TeleportGrace`, NaN/negative → default, max 30) and the track restarts. Callers: ZoneService.teleport()
  (enemy-town / level bounces, A10 rescue, pads, travel), ZoneService CharacterSpawned (`SpawnGrace`), PlayerService
  (before LoadCharacter and the spawn PivotTo) and JusticeService (spawn lift), both with `SpawnGrace`.
- **Always enforced** (independent of `Enforce`): a travel-pad touch counts only when the toucher's root is within
  `max(pad.Size.X, pad.Size.Z) / 2 + PadSlack` (flat) of the pad, checked before the pad debounce; Swing / Release return
  early when `Config.ZoneAt(root.Position).MinLevel > Level` (Swing keeps its cooldown unspent, Release keeps the charge);
  target selection skips zone monsters whose zone MinLevel > the attacker's Level (personal monsters exempt).
- ProgressionService.BankAll does not consult IsPlausible (its IsTown comes from ZoneService's checked zone).
- Switch `Enforce = true` only after a playtest shows no false positives (menu travel, respawn, fall rescue, bully / kaiju
  scale changes, enemy-town bounce). It is read on every call, so it can be flipped at runtime.

### A16-2 Saved pair cooldowns [CR-M3, CR-M4, CR-L6]
- `Config.Data.Defaults.PairCD = {}` (persisted, not mirrored): `PairCD["<kind>:<otherUserId>"] = os.time()` of the last
  reward, stored on the player who is rewarded / protected, so it follows them to another server with the session lock.
- `PlayerService.PairReady(holder, otherUserId, kind, cooldown, commit?) -> boolean`: true when
  `os.time() - PairCD[key] >= cooldown`; when true and `commit ~= false` it records now (`commit = false` = look only).
  No data / bad arguments → false. Callers pcall it and treat an error as false (no reward).
- Keys in use:

  | Holder | Key | Cooldown | Meaning |
  |---|---|---|---|
  | killer | `ko:<victimUserId>` | PvP.PairRewardCooldown 300 | minted KO rewards; also the logout bounty (A16-4) |
  | killer | `kolog:<victimUserId>` = `{ t1, t2 }` | Bully.RepeatWindow 600 | last 2 KO times for the 3rd-KO bully rule (written directly by PvPService) |
  | victim | `bully:0` | Bully.DecaySeconds × MaxStacks (900) | a bully bounty was paid on this victim |
  | victim | `steal:<thiefUserId>` | Grudge.RestealWindow 180 | CanSteal checks with commit = false; AddToSack records |
  | victim | `refund:0` | Grudge.RefundBonusCooldown 600 | extra 20 % refund, once per VICTIM whatever the thief [CR-L6] |
  | avenger | `avenge:0` | PvP.PairRewardCooldown 300 | avenger bonus, once per AVENGER whatever the thief [CR-L6] |
  | participant | `kaiju:<kaijuUserId>` | Kaiju.PairRewardCooldown 1800 | minted kaiju-pool share [CR-M3]; spent only when that share > 0 |
- Pruning right before PlayerReady (and on insert past 200): drop entries older than max(1800, the largest configured pair
  cooldown / window), timestamps in the future and non-string keys; keep at most 200 (oldest dropped first); `kolog` uses
  the newer of its two times.
- The in-memory tables `koLog`, `pairReward`, `bullyBountyAt`, `lastSteal`, `lastRefund`, `lastAvenge` and `poolPaidAt`
  are gone (`lastHitOn` became `dmgLog`, A16-9). Fallbacks while PairReady is missing: PvP/Grudge use an inline copy of the same contract on
  `GetData(holder).PairCD`; KaijuService uses an in-memory map and warns (throttled).
- [CR-M3] A Plunder KO adds a wanted star only when `pairOk`. The kaiju's carried gold moved into the raid pool is capped
  at `Config.PvP.PlunderCapPerLevel × kaiju Level` (the rest is destroyed).

### A16-3 Data, rejoin and shutdown [CR-M1, CR-M2, CR-M12, CR-L1, CR-L2, CR-L3]
- DataService: the per-UserId write slot is a FIFO queue (token interface unchanged); a waiter that exceeds SLOT_TIMEOUT
  removes itself and gets nil. `Load` first waits until an earlier session of the same UserId has finished `Release`
  (nil if the player leaves or SLOT_TIMEOUT passes), runs its body in pcall and always frees the slot; `Save` does too.
  Public API unchanged.
- `Load` refuses a stored record whose `Version > Config.Data.Version` (the UpdateAsync write and lock are cancelled; nil →
  LoadFailed kick). Operating rule: bump `Config.Data.Version` whenever MaxLevel, classes or factions are added.
- `PlayerService.IsShuttingDown() -> boolean`: true from the start of BindToClose. Shutdown order: for every ready,
  not-finalizing player, PlayerLeaving is fired synchronously (pcall) **while everyone is still ready** (so a thief's sack
  refund still reaches a victim who is leaving too); then FinalizeLeave per player (ready off → Release → cleanup).
  ProgressionService does not apply CombatLogPenalty during shutdown.
- A load that finishes after the player left / PlayerRemoving / closing keeps `joining[player]` until its Release is done,
  so BindToClose waits for that save as well.
- Kept across a rejoin [CR-M12]: `Config.Data.Defaults.SavedBully, SavedBullyAt, SavedStars, SavedStarsAt` (persisted, not
  mirrored). Written in PlayerLeaving, read and zeroed (one-shot) in PlayerReady, restored only for Halo/Horns:
  - bully stacks = min(MaxStacks, saved − floor(elapsed / Bully.DecaySeconds)); `SavedBullyAt` is the start of the running
    decay period, so the partial decay timer carries over;
  - wanted stars = min(MaxStars, Kaiju.StarsNeeded − 1, saved − floor(away / PvP.StarDecaySeconds)), partial decay carried
    over; `SavedStars = 0` when a logout bounty was just paid or for an Active kaiju (KaijuService also zeroes it when it
    settles a leaving kaiju as Defeated).
- [CR-L1] JusticeService clears bully state with `task.defer` in PlayerLeaving, so `GetBullyStacks` stays valid in every
  PlayerLeaving handler; its direct PlayerRemoving hook clears only players who never became ready.

### A16-4 Logging out does not cancel rewards [CR-M11, CR-L19]
- Kaiju: when the current kaiju leaves while Active and the Halo damage total > 0, KaijuService runs
  `HandleKaijuDeath(victim, nil, true)` (new optional 3rd argument `leaving`: no character access; with no lethal hit the
  minted part is scaled by the Halo damage share). Outcome Defeated; on failure, or in any other case, Cancelled as before.
- Wanted: PvPService pays a logout bounty before `clearRevengeInvolving` when the leaver is Horns, has ≥ 1 star, is not an
  Active kaiju, is in combat, and `GetLastPvPAttacker` is an online, ready Halo who passes
  `PairReady(attacker, leaver, "ko", PvP.PairRewardCooldown)`: `Config.Bounty(Level, stars, bully stacks)` to the attacker's
  bank (bully part only if `bully:0` allows), honor `max(1, stars)`, BountyGain toast, BountyAnnounce at GlowStars+.
- [CR-L19] The kaiju-defeated announcement shows the gold actually paid; nobody paid → `Config.Story.KaijuDefeatedNoReward`.

### A16-5 Combat [CR-H1, CR-M7, CR-M8, CR-M10, CR-M13, CR-M17, CR-M23, CR-L21, CR-L22, CR-L49]
- [CR-H1] A Halo release gives each other ally +HaloAllyStacks at most once per `Config.Charge.HaloAllyStackCooldown` (5 s)
  per receiving ally.
- [CR-M7] A manual release that hits an Active kaiju is capped at `Config.Kaiju.ReleaseCapPct` (0.08) × its current
  MaxHealth; everyone else keeps `Charge.PvPCapPct`.
- [CR-M8] Lifesteal cap base of an Active kaiju = MaxHealth / `KaijuService.GetHealthMult` (its base health).
- [CR-M10] `CombatService.DamagePlayer(victim, amount, attacker?, crit?) -> number` = HP actually removed (0 on every
  refusal and under a ForceField). `PlayerDamaged:Fire(victim, applied, attacker)` carries that value and still fires with 0.
  Swing `totalDealt` and Release `total` (Halo heal, lifesteal, `Released.Total`) add the HP really removed from monsters and
  players; a monster hit MonsterService refuses (no HP change, not killed) adds no hit entry, charge or shove. Hit numbers
  `A` keep the requested damage, and the Release Fx `Total` is the sum of those numbers. Side effect: Halo release healing
  from monster hits drops a lot (≈ 68 → 9 HP on one goblin); raising `HaloHealPct` is an open user decision.
- [CR-M13] A kaiju stomp passes the kaiju as attacker only when `ZoneService.IsPvPZone(victim)`; in safe zones it is
  environmental damage (no combat tag, no PvP KO credit).
- [CR-M17] Auto attack yields for `SwingInterval + Config.Combat.ManualYieldPad` (0.3) after a manual request (see A3-H3).
- [CR-M23] DamagePlayer sends Fx `Hurt { Pos, Amount = applied }` to the victim whenever applied > 0 (PvP hits and stomps
  included). PvP hit entries carry `V = victim UserId`; Fx skips another player's P number whose V is me (shown once as Hurt).
- [CR-L21] `GooseService.RegisterHit(player, isManual) -> number` (tug count added, 0 when rejected); a `G` hit entry is
  added only when > 0, `A` rounded to 0.1. `GooseService.GetPosition()` includes the tug side offset on X.
- [CR-L22] `Config.Charge.PerfectGrace = 0.25`: the auto release fires at PerfectUntil + grace and a manual PERFECT counts
  until then; the "need N stacks" toast is skipped within 1 s after an auto release.
- [CR-L49] Swing / Release Fx are no longer FireAllClients: they go to the attacker plus players whose root is within
  `Visuals.FxCullDistance + 60 + extent` of the centre (extent: Swing max(Radius, Range), Release Radius; 60 covers the
  kaiju camera zoom).

### A16-6 Monsters, zones and map [CR-M5, CR-M22, CR-L13, CR-L14, CR-L16, CR-L17, CR-L18, CR-L24]
- [CR-M5] `GetMonstersInRadius / GetNearest / CountInRadius(..., forPlayer)`: with a player → that player's personal
  monsters + zone monsters whose `ZoneId == Config.ZoneAt(player root).Id` (no character → personal only); nil → all.
  `DamageMonster` returns false (no HP or contributor change) for a zone monster when the player stands outside its zone.
- [CR-L13] Global cap: base counts are kept; per-player extras share the remaining room proportionally (largest remainder,
  ties by MonsterTypeOrder). [CR-L14] Spawn / wander / detour / shove points inside collidable Decor (except `Bridge_*`) or
  Landmarks are rejected (downward ray from y + 40; filter cached 10 s).
- [CR-L18] Travel channel = `channels[player] = { Token, Start }`. A new Travel is refused `(false, nil)` while one runs. The
  zone loop cancels it within one ZoneTick when the player is dead, was damaged since Start, is in combat, carries a sack,
  is a kaiju or has too many stars: `TravelingUntil = 0` + TravelCancelled toast. The delayed pivot checks the token.
- [CR-L24] A Neutral player entering a PvP zone gets `Config.Text.EnteredPvPNeutral` ("info") instead of EnteredPvP.
- [CR-M22] `Config.Map.Pads`: SlimeMeadow (52, 0, −24), GoblinWoods (52, 0, 24), SkeletonRuins (68, 0, 24) — off the east
  road. MapBuilder moves a reused pad (with every BasePart under it) to its Config position (top at Y 0.5) and rewrites its
  sign; `tools/preview_map.lua` PADS match.
- [CR-L17] Bounds walls reach down to `Config.Map.WaterTop − 20` (reused walls are stretched too; preview_map matches).
- [CR-L16] The A10 fall rescue lives only in ZoneService (PlayerService's rescue loop is deleted).

### A16-7 War and goose [CR-M18, CR-M19, CR-L8, CR-L20]
- [CR-M18] `MonsterKilled` info gains `WarShare = WarPoints / (same-faction contributors of this kill)` (0 for personal
  monsters). `WarService.AddPoints(player, n, poolN?)`: personal += n; faction pool += poolN when it is a positive finite
  number (capped at n), else n. MonsterKilled is wired as `AddPoints(p, info.WarPoints, info.WarShare)`.
- [CR-M19] Per-capita war scores (`WarHaloScore` / `WarHornsScore`), `WarMode` and the winner divide by the ROUND-AVERAGE
  head count of each faction (sampled every War.Tick; an average < 0.5 counts as 0); reset every round; the first publish
  after a round end uses the current counts.
- [CR-L20] The sky's ClockTime always tweens forward (NumberValue, +24 wrap, `ClockTime = v % 24`).
- [CR-L8] If either faction has 0 players when the goose ends, the result is "Tie" (no winner reward, no war points) with
  `Config.Story.GooseNoRival`.

### A16-8 Justice, factions, classes, tickets [CR-M20, CR-L5, CR-L7, CR-L9, CR-L10, CR-L11, CR-L25]
- [CR-M20] Size Justice sums/counts include a Halo/Horns player only when not a rookie, active within 120 s
  (`PlayerService.GetLastActive(p)` = os.clock() of the last MarkActive, 0 = never) and not 60 s+ inside a town. Excluded
  players still get their side's S.
- [CR-L5] `JusticeService.GetCombatPower(player) = Config.PowerOf(Level, WeaponTier, 1)` (no rebirth bonus) is used for the
  bully "weak victim" test; `GetPower` (with the rebirth bonus) still feeds the faction sums.
- [CR-L7] `FactionService.GetUnderdogCounts(always?) -> (halo, horns)`: ready, non-leaving Halo/Horns players without
  rookies and > 120 s idlers (`always` is counted even if idle). Published as GameState `UnderdogHalo` / `UnderdogHorns`
  (10 s loop + join / leave / faction change). The rebirth underdog bonus uses it (fallback GetCounts) and subtracts the
  player from the old faction only when counted; the Rebirth remote marks the player active first. The Panels preview
  reads the GameState values.
- [CR-L9] Switching at the altar or rebirthing to Neutral is refused with `Config.Text.BlockedBully` while BullyStacks > 0.
- [CR-L10] The +300 sign-on bonus also sets `LastSwitchTime` (starts the 10-min altar cooldown).
- [CR-L11] A ticket is spent on an altar switch only if the score being left (Honor / Infamy) is > 0; otherwise the switch
  is free and shows the plain message (`Config.Text.SwitchDonePlain`, fallback "%s(으)로 진영을 바꿨어요!").
- [CR-L25] `MonetizationService.UseTicket(player, kind) -> (boolean, reason: "Pending" | "None" | nil)`; on "Pending"
  (purchase still saving) callers show `Config.Text.TicketSaving`, otherwise NoTicket.

### A16-9 PvP rules [CR-M14, CR-M15, CR-L4]
- [CR-M15] `Config.Bully.BaitMinPct = 0.2`. PvPService keeps `dmgLog[attacker][victim] = { { T, A } }` (amount > 0 only,
  BaitWindow, ≤ 64 entries). `baited` = the victim's damage to the killer inside BaitWindow ≥ BaitMinPct ×
  `Config.MaxHealth(killer Level, faction, class)`.
- [CR-M14] A baited KO is never "weak"; `defense = baited and (fresh or repeated)` → `info.Kind = "Defense"` (Bully false,
  Rewarded false, Stolen 0, Bounty 0): no bully stack, stars, plunder, honor/infamy or bounty; revenge and the KO log are
  kept and the victim's stars still reset. A killer whose kaiju state is not "None" is never a bully.
  `PvPService.PlayerKO` info.Kind may now be "Defense".
- [CR-L4] A wanted player who dies in a town, or with no damage taken in the last 3 s (reset / fall), keeps the stars and
  loses nothing.

### A16-10 Quests and progression [CR-M6, CR-M9, CR-M16, CR-M21, CR-M27, CR-L12, CR-L23, CR-L31, CR-L50]
- [CR-M6] Rewards are capped at claim time to the CURRENT level: a Daily claim and the midnight auto-pay to
  `Config.DailyQuestReward(Level)`, a vacation claim to `Config.VacationReward(Level, VacationDays)`; the published daily
  reward shows the capped value. New signal `ProgressionService.LevelReset(player)` (end of ResetLevel = free class change)
  remakes Extras like Rebirthed. Grudge sack entries store the victim's `Rebirths`; a return/refund is paid only if it is
  unchanged (otherwise that share is destroyed). This supersedes TECH_SPEC's "quests are kept" / "dailies keep their rewards".
- [CR-M9] The town auto-bank skips a player whose kaiju state is Siren or Active.
- [CR-M16] A level-up refills HP only when not in combat and not an Active kaiju (HP % kept otherwise).
- [CR-M21] `VacationDays` is fractional (3 decimals). At the day flip it gains (1 − f) for the old day plus every whole
  missed day (cap VacationMaxDays), where f = (claims × QuestMinutes + (all claimed and ChestMinutes or 0)) /
  (Slots × QuestMinutes + ChestMinutes) and claims = earlier claims + dailies auto-paid now. An auto-pay that completes the
  set also pays the bonus chest (and rolls the class ticket). Panels shows `max(1, ceil(VacationDays))`.
- [CR-M27] Deviation from TECH_SPEC §4.20 "Kill +1": a kill adds `killWeight = clamp(def.XP / unit.XP, 0, 1)` to Kill and
  Golden quests, where unit = the quest's monster (`Quest.Unit`, fixed at generation; older quests use the level zone's main
  monster). Quest text names that monster (`"%s %d마리 쓰러뜨리기"`, `"황금 %s %d마리 처치"`, with `def.Short or def.Name`).
  Published Progress is floored to 0.1; the HUD shows fractional progress with one decimal.
- [CR-L12] A Daily remade by a faction change keeps max(new, old) rewards. [CR-L31] Gold quest text shows the exact number;
  the HUD shows targets under 10000 as integers.
- [CR-L23] The server no longer sends the LevelUp / Banked / HaloCourier Notify or NotifyAll(KaijuSiren); Fx LevelUp / Bank
  and the EventHUD siren banner announce them. The Halo courier sends Fx `Bank { Amount, Courier = true }` →
  `Config.Text.HaloCourier` toast.
- [CR-L50] The `QuestsJson` attribute is gone. New server → client remote `Quests` (`Net.Names`):
  `FireClient(player, json)` (same JSON array string as before) only when it changes, plus once after each
  CharacterSpawned. HUD accepts the JSON string, an array or `{ Quests = array }`.

### A16-11 Client / UI [CR-L15, CR-L26–L30, CR-L32, CR-L34, CR-L36–L48]
- [CR-M24] Quest claim and reroll buttons use separate positions. After a claim, reroll input is ignored for 1.5 s;
  a row whose quest identity changes ignores claim/reroll input for 0.8 s. [CR-M25] Reroll always asks for confirmation,
  and ignores confirmation if the row changed while it was open. On touch devices, the quest header opens an overlay
  above the thumbstick area. [CR-M26] FactionPicker and ClassPicker ignore card input for 0.6 s after opening.
- [CR-L34] Own ScreenGuis use DeviceSafeInsets (A3-H4 revised). [CR-L36/L37] HUD publishes `HUD.TopCenterX`,
  `HUD.TopCenterW` (war-meter column) and `HUD.Layout = { W, H, Scale, ClusterTop, ClusterLeft, TopCenterX, TopCenterW }`
  (MainGui logical units, nil before the first layout); EventHUD places the event strip and the personal line (ZIndex 6) from
  them. Status chips wrap to a second row. [CR-L38] Max 2 toasts below 500 px viewport height; toast width
  min(460, W / scale × 0.45). [CR-L39] The combo label is bottom-centre (0.5, 0.66).
- [CR-L15] Another player's personal monster (OwnerUserId ≠ me) is hidden locally. [CR-L32] Golden kill rewards are left
  out of the "N마리 더!" average. [CR-L42] Fx reads `Config.HitFeel.FlashRadius / MergeRadius`. [CR-L43] Edge arrows stay
  below the top bar.
- [CR-L26] Panels ignore input for 0.35 s after a render; [CR-L27] altar buttons sit above the lore; [CR-L28] no duplicate
  Crossroads in the Neutral travel list; [CR-L29] `Config.Story.IntroNeutral`; [CR-L30] `Config.Text.WaitRespawn` while
  dead; [CR-L40] minimum text size 15; [CR-L41] touch close/back buttons ≥ 44 pt, WorldMap buttons max(52, ceil(44 / s)).
- [CR-L44] `Util.GlyphSafe(text)` is the shared check (only ← → ▲ ▶ ▼ ★ ☆ of U+2190–U+2BFF are trusted); Neutral emblem "장";
  WorldMap Guild = Neutral Emblem, Kaiju "괴", Market "상". The other WorldMap glyphs and ClassPicker emoji fallbacks wait
  for a Studio check. [CR-L45–L48] WorldMap: zoom-relative label/icon thresholds, roads from `Config.Map.Roads`, KEY_GUARD
  removed, zoom anchor in screen pixels.

### A16-12 New or changed public surface
| Owner | Function / field | Contract |
|---|---|---|
| ZoneService | `IsPlausible(player, pos) -> boolean` | A16-1 (false only while Enforce) |
| ZoneService | `MarkTeleported(player, seconds?)` | A16-1 |
| PlayerService | `PairReady(holder, otherUserId, kind, cooldown, commit?) -> boolean` | A16-2 |
| PlayerService | `GetLastActive(player) -> number` | os.clock() of last MarkActive, 0 = never |
| PlayerService | `IsShuttingDown() -> boolean` | A16-3 |
| CombatService | `DamagePlayer(...) -> number`; `PlayerDamaged(victim, applied, attacker)` | A16-5 |
| MonsterService | query functions + `DamageMonster` zone filter; `MonsterKilled` info.`WarShare` | A16-6, A16-7 |
| WarService | `AddPoints(player, n, poolN?)` | A16-7 |
| KaijuService | `HandleKaijuDeath(victim, killer, leaving?)` | A16-4 |
| GooseService | `RegisterHit(...) -> number`; `GetPosition()` includes side offset | A16-5 |
| JusticeService | `GetCombatPower(player) -> number` | A16-8 |
| FactionService | `GetUnderdogCounts(always?) -> (halo, horns)` | A16-8 |
| MonetizationService | `UseTicket(...) -> (boolean, "Pending" \| "None" \| nil)` | A16-8 |
| ProgressionService | signal `LevelReset(player)` | A16-10 |
| PvPService | `PlayerKO` info.Kind `"Defense"` | A16-9 |
| Net / GameState | remote `Quests` (S→C); `UnderdogHalo`, `UnderdogHorns` | A16-10, A16-8 |
| Data | `PairCD`, `SavedBully`, `SavedBullyAt`, `SavedStars`, `SavedStarsAt` (not mirrored) | A16-2, A16-3 |
| Util | `GlyphSafe(text) -> boolean` | A16-11 |
| HUD (client) | `HUD.TopCenterX`, `HUD.TopCenterW`, `HUD.Layout` | A16-11 |

### A16-13 Still open after R1
- All-file compile and the basic single-player checks passed on 2026-10-03; the full review's multiplayer, persistence,
  shutdown and exploit scenarios still need Studio/published-server verification (see the verification record).
- Keep `Config.AntiCheat.Enforce = false` until all movement false-positive conditions are checked: menu travel,
  respawn, fall rescue, bully/kaiju scale changes and enemy-town bounce, plus intentional invalid moves.
- User decision: raise `Config.Charge.HaloHealPct` after CR-M10, or accept the lower release healing.
- Former G9 limitation: ProgressionService banked a leaving kaiju's pouch before the raid settled, leaving only the
  minted part. The follow-up code now escrows that pouch before settlement; actual leaving-kaiju reward/rollback and
  shutdown behavior are still unverified in this single-player run.
- `Config.Text.SwitchDonePlain` is not in Config yet (FactionService uses its fallback text).
- `tools/preview_map.lua` still writes the guild billboard as "⚙ 장인 길드" (only matters if the preview is re-run).
- Goose `G` numbers with decimals display floored (Fx uses Util.FormatNumber); CR-M22: check in Studio that the
  SkeletonRuins pad (68, 0, 24) is clear of the east Crossroads ridge (x ≈ 105).
- The Panels rebirth preview subtracts the viewer from their faction even when the viewer is idle > 120 s (not counted in
  UnderdogHalo/Horns), so it can be off by one until the viewer acts.

## A17. New-account art, exact lettering and optional R15 costumes (2026-10-03; partial implementation)

This is a code/asset contract, not a claim that all costume rigs or the saved place are complete. The latest Studio
round compiled 34 Luau files, synced 3 plus 2 subsequent A/Nanum changes, and ran 15 seconds with 20/20 server services
and 8 client modules without Luau runtime errors. See HANDOFF_CODEX and the actual-cost records in
`docs/art/` for unfinished work. A16 multiplayer, persistence and anti-cheat verification limits still apply.

### A17-1 Existing approved art and load-safe lettering
- Continue using the user's existing GPT-approved images; do not redesign the UI or regenerate these assets in code.
  New-account IDs are recorded for UI/FX/stickers 78 + lettering 42 + weapon icons 27 + terrain textures 15 + map 1 = **163** images in
  `art/ui/asset_ids.json` and `Config.UIArt.Parts`.
- `Config.UIArt.TextLabels` maps exact Korean strings to `TXT_*` parts. `UIKit.BindArtText(label, partKeyOrText?)`
  accepts a TextLabel/TextButton, returns the original label, and observes its current Text. An optional hint cannot
  override a different current string; dynamic digits/suffixes must never disappear.
- The child ArtText remains hidden until its ImageLabel reports IsLoaded. Only then hide the original font/stroke and
  contextual UIStroke. While pending, missing an ID, changing text or failing to load, restore the original font/stroke.
  Preserve callers' opacity changes and never show both the image and its fallback at once. Keep IMG-R4 fallbacks.
- Bind designated labels in the pickers, HUD, Panels, WorldMap and existing shared text helpers. Font-fit/safe-area work
  must preserve the selected art and Korean glyphs; numbers and unmatched runtime messages remain normal text.
- The user selected the latest GPT **A composition** for selection-screen balance and Nanum Gothic. Implement that
  selected layout while retaining the existing approved card/lettering assets. Nanum family `12187361718` is verified
  live; use FontFace with the intended Regular/Bold/ExtraBold weights for normal text, retaining font-load fallback.
  At the actual 991×511 viewport, clipping still needs the current follow-up fix and visual recheck.
- `Config.WeaponArtKey(tier, classId, factionId) -> string`: clamp finite integer tier to 1..MaxWeaponTier, default invalid
  class to Warrior; tiers 1..6 return `Weapon_<Class>_T<n>`, tier 7 appends Halo/Horns/Neutral (unset faction → Neutral).
  The HUD upgrade card selects the current class's NEXT tier icon, with the current faction at tier 7. A missing ID uses
  IconSword. Recreate the icon only when its key changes; keep the original approved card position/size/layout.
- Terrain textures 15 and MapParchment 1 uploads/IDs are complete. The material tool applied 15 GE variants, 12 base
  material overrides and 3 road assignments. GE_Grass was replaced with a new Instance (GrassReplaced=true); its old
  TexturePack warning did not recur in this Play. WorldMap uses the MapParchment ArtImage with its existing fallback.

### A17-2 Saved appearance choice and server-owned character replacement
- Persist and mirror `CharacterGender` (`M` default; only M/F) and `CostumeEnabled` (`true` default; boolean only).
  DataService repairs invalid/missing legacy values without resetting progression.
- `ChooseClass(classId, gender?)`, `ChangeClass(classId, useTicket, gender?)` accept only M/F when provided and retain all
  existing choice/change restrictions. `SetCostume(enabled, gender?)` is a rate-limited client→server remote for ready
  players; enabled must be boolean and optional gender M/F. The server owns the template ID and every replacement.
- Desired ID = `Costume_<Faction><Class><M|F>` only for ClassChosen=true, enabled=true, a valid Halo/Horns/Neutral faction
  and Warrior/Mage/Archer class. `Config.Costumes.TemplateFolder = "CostumeRigs"`, TemplatePrefix = `"Costume_"`.
- `CostumeService.ValidateTemplate(model) -> (boolean, reason?)` requires a living R15 Humanoid, HumanoidRootPart and all
  15 standard R15 body parts. Require enabled Motor6D edges Root→LowerTorso→UpperTorso→Head, torso→each upper arm→lower
  arm→hand and lower torso→each upper leg→lower leg→foot. A decorative welded GLB alone is not a playable template.
- `CreateSpawnCharacter(player) -> Model?` clones a valid server template. Missing/invalid rigs return nil and keep the
  owner's normal Roblox avatar. Template LuaSourceContainers are removed. Install only a verified game-owned Animate
  LocalScript for the correct RigType and create Animator on the server. Controller sources: captured owner Animate of
  the SAME RigType, then `ServerStorage.CostumeAnimationControllers.<R15|R6>` with matching CaptureRigType, origin
  RobloxDefaultCharacter and a valid 64-digit CaptureSourceSHA256. An untyped StarterCharacterScripts.Animate must not
  silently override a verified R15 controller.
- Capture the fully loaded owner's actual HumanoidDescription, RigType and compatible Animate before first replacement.
  OFF rebuilds that owner's avatar from the description, preserving their clothes/accessories and original rig type.
  Never capture a costume clone as the original avatar.
- `RequestRefresh(player)` serializes pending work with version checks. Defer while spawning/dead/in combat/kaiju;
  discard stale clones after a yielded appearance call or character change. Class/faction changes, spawns, appearance
  loading and template arrivals request refresh. Verified controller arrival/metadata updates also request refresh so
  WaitingAnimation can recover after installation. No original appearance yet → WaitingAppearance. Clean
  snapshots/controller clones/connections on PlayerLeaving.
- `PlayerService.SpawnCharacter(player, model) -> boolean` installs an unparented server-owned model through the normal
  spawn path. `ReplaceCharacter(player, model, expectedOld) -> boolean` is an appearance swap: require unchanged live
  old character, preserve position/velocities/current HP, existing shield expiration and movement-check state. Do not
  fire CharacterDied, grant a new spawn shield, heal, teleport to spawn or reset combat/progression for a cosmetic swap.
  `ZoneService.CaptureMovementTrack`/`RestoreMovementTrack` preserve the existing validation track for this path.
- Diagnostic attributes: CostumeStatus (`Avatar`, `Active`, `MissingTemplate`, `InvalidRig`, `WaitingAppearance`, `WaitingAnimation`,
  `Deferred`, `Error`); CostumeApplied reflects the current character's `HHC_CostumeId`. CostumeEnabled=true is an
  intended choice, not proof of CostumeApplied. B menu distinguishes preparation/deferred/error from applied ON/OFF.

### A17-3 Reviewable local tools and upload safety
- Use the same files on the new account; the user allowed uploads from **2026-10-03**. Inspect and show each image before
  uploads, at most 10 per batch. Never upload `art/out/v1/`. Keep humans modest; Slime/original Goblin/GoblinBrute designs
  stay unchanged, and Skeleton uses the user's selected clothed revision.
- `tools/upload_ui_assets.py` validates explicit SHA256, existing Config key, direct workspace `art/ui/*.png`, ≤10 items,
  and localhost image URLs. Write received IDs to the recoverable report/ledger before Config/asset_ids updates.
  Record-result repairs previously returned IDs without uploading. Unknown/inflight results block ordinary retry;
  the explicit disconnected-unknown retry needs reason and old/current Studio evidence. Run only one ledger writer.
- `tools/costume_r15/convert.py` exports R15 pieces/joint data from the existing rig; `assemble.py` generates inspection
  and assembly payloads. Import all source batches, inspect actual geometry, then assemble only under
  `ServerStorage.CostumePendingRigs`. Move to playable CostumeRigs only after complete animation/play QA.
- `tools/costume_r15/vendor/RobloxR15Animate.client.luau` and its serialized children are captured from a normal R15 avatar,
  read/inspected, and exactly match Source extracted from the installed Roblox engine `.rbxm` (SHA256 recorded in
  provenance). `install_animate.py --dry` is offline; `--apply` targets only GoodEvil/Edit, installs Source via multi_edit,
  deserializes the recorded children, verifies the result and saves an audit. It never stops Play or syncs other scripts.
  Root executed the installer successfully in Edit: 61 nodes, Source 28,802 characters, SHA256
  `49eab7530cfc33b8af13b995ae1fa87f482a489b6d108ec2410d12dd19b720f0`; complete audit in
  `build/costume_r15/animate_install_20261003T073704Z_4ef76cd9.json`.
- Additional paid work requires the user's actual authorized cost scope. Completed Skeleton 30 + SkeletonKing 60 +
  one human pilot rig 25 = 115 credits. Remaining 17 rigs (425) are a plan, not a verified blanket cost approval.

### A17-4 Actual verification boundary for this round
- Live diagnosis: Darugi_S2, Halo/Mage/F, ClassChosen=true, CostumeEnabled=true, CostumeStatus=MissingTemplate.
  CostumeRigs, CostumePendingRigs and CostumeAnimationControllers were absent at that diagnosis. The verified R15
  controller has since been installed; playable CostumeRigs is still empty/absent. CostumeImports contains only the male
  HaloWarrior Batch01's 7 MeshParts. **Playable costumes: 0.** ON/OFF code is prepared; a working animated costume or
  actual OFF restoration has not passed play verification.
- A later temporary Batch01 clone loaded its 9 asset references successfully and displayed its face/eyes/armor textures.
  This proves those static imported surfaces, not a complete R15 body or animation. Initial failed loads are not silently
  removed from earlier diagnostic records.
- Default Animate capture/vendor/installation verification is complete. Full R15 assembly,
  walking/jumping/combat/death/respawn/OFF restoration and state preservation remain. A free EditableMesh comparison of
  the original LeftLowerArm passed (431 faces, UV maximum error 0, position maximum error 1.237e-7). The free
  LeftLowerLeg preview had 850 vertices/596 faces and all comparison errors 0. One actual CreateAssetAsync call raised
  "CreateAssetAsync and CreateAssetVersionAsync are not available yet"; this Studio does not support that upload path.
  New mesh uploads succeeded: 0; retries: 0. Preserve Unknown in
  `build/costume_r15/Costume_HaloWarriorM/editable_upload_ledger.json`; do not blindly retry. Import the remaining 11
  file pieces using the 3D Importer before assembly. These free geometry checks are not playable-rig validation.
- `texture_01` originally had 10 unknown outcomes. Public assetdelivery returned 403 and two public thumbnails were the
  same broken-image placeholder; that comparison could not identify originals. Later, after verifying the old Studio
  had closed and recording retryHistory, the explicit retry returned all 10 complete with exact URL→ID mappings:
  Tex_Grass=78282434254609, Tex_LeafyGrass=97617252360457. Texture02 five and MapParchment=133911744102396 are also
  complete/recorded. These mappings come from actual upload results, not a guessed thumbnail match. Actual terrain
  application is 15 GE variants/12 overrides/3 roads; latest Play has no GE_Grass TexturePack warning, while
  Goblin/GoblinBrute/Skeleton asset warnings remain.
- WaitingAppearance/verified-controller fallback/retry and preparation-state menu display passed the subsequent all-file
  compiler/basic start round. Latest A/Nanum code is reflected in Studio; 991×511 clipping is being fixed and remains
  visually unverified after that fix. The later approved Warrior/Archer/Mage sheet and motion contract are A19.
  `docs/art/verification_2026-10-03/faction_a_nanum_1590.jpeg` records an intermediate failed layout, not the final result.
- Last inspected saved `build/GoodEvil.rbxlx`: 2026-10-03 14:53:38, 6,606,409 bytes; only Slime/GoldenGoose/SkeletonKnight
  had new-account monster imports in that saved file. Current live imports/latest src still need a confirmed Studio save
  and copy to the committed `place/GoodEvil.rbxlx` before this round can claim a current saved playable place.

## A18. Approved HP/MP HUD and server-owned reusable potions (2026-10-03; basic runtime verified)

The user approved GPT `art/out/UI_HUD_Vitals_A.png` ("어휴 너무 좋지"). Implement the approved addition without changing
the existing HUD style. The optional potion-mechanic question had no answer; **free reusable potions with separate
10-second cooldowns** are the implementation default, not a recorded user choice of that mechanic.

### A18-1 Resource and remote contract
- `Config.Vitals = { MaxMana=100, ManaRegen=4, MageSwingCost=3, ReleaseCost=20,
  HPRecovery=0.30, MPRecovery=0.40, PotionCooldown=10 }`.
- New server `VitalsService` follows Init(S)/Start and is registered before CombatService; new client `VitalsUI` is
  registered before HUD. Current registrations: 21 server services and 9 client modules. Register remote `UsePotion`
  (client→server) and `Config.RateLimits.UsePotion=0.3`.
- Mana is **session-only server state**, not saved in DataService. PlayerReady starts at MaxMana. A non-cosmetic
  CharacterSpawned refills mana; a cosmetic character replacement preserves it. Remove state on PlayerLeaving.
  Potion deadlines are per-player session fields and persist across death/respawn and cosmetic replacement.
- Server publishes `Mana` (rounded to 0.1), `MaxMana`, `HPPotionReadyAt`, `MPPotionReadyAt` player attributes. Deadlines use
  workspace:GetServerTimeNow. Regenerate ready, living, ClassChosen players every 0.5 seconds by ManaRegen × elapsed time
  (elapsed clamp 0..1), capped at MaxMana. Clients never set the authoritative resource state.
- `VitalsService.TrySpendMana(player, amount, silent?) -> boolean` validates finite nonnegative amount≤MaxMana and a
  ready/living/ClassChosen player. Spend once on success. Insufficient manual mana sends a Korean notice at most every
  2 seconds; automatic requests may suppress that notice.
- Mage Swing (manual or auto) spends 3 before consuming the shared Swing cooldown. Warrior/Archer Swing spend no mana.
  Every class Release (manual/auto) spends 20 only after ordinary eligibility/min-stack checks and BEFORE consuming
  charge/perfect state. Insufficient mana keeps charge and attack cooldown; no damage/attack Fx is accepted.
- `UsePotion("HP"|"MP")`: validate kind, ready/living/ClassChosen player, independent per-kind request throttle and
  authoritative deadline. Refuse kaiju Siren/Active. HP adds 30% of the current Humanoid.MaxHealth, capped at MaxHealth;
  MP adds 40% of MaxMana, capped at MaxMana. Successful use alone starts that kind's 10-second deadline, marks active
  and sends a Korean notice. Full resource, bad kind, dead/not chosen, active deadline and kaiju spend no potion deadline.
  Potions have no gold cost, purchased stock or saved inventory in this default.
- `DebugSetMana` is Studio-only via Main's existing DebugCommand; never expose a resource setter as a client remote.

### A18-2 Approved HUD and controls
- `VitalsUI.BuildStats` places HP/MP bars below XP; `BuildPotions` adds two approved parchment/icon buttons directly
  below the player card. HUD increases the card height and moves quests below the potion row, including Horns' stars.
  Keep touch/desktop scaling, existing safe-area rules and the original approved layout outside this addition.
- Show HP/MP current/maximum values, plus per-kind ready/countdown text from server time. Key **1=HP, 2=MP** and direct
  button taps send the same remote. Keyboard hint appears only on keyboard without touch. Ignore processed input or
  focused text boxes and suppress potion requests while faction/class picker, WorldMap or Panels is open.
- Disable default Backpack/Health CoreGui to avoid competing 1/2 hotbar shortcuts and duplicate health display.
  Keep code fallback when an art icon is absent.
- Root inspected/displayed each potion PNG before upload. Config part IDs: IconPotionHP=`100061379621289`,
  IconPotionMP=`133725941898063` (`art/ui/asset_ids.json` records `UIP_IconPotionHP/MP`). Existing 163+2 = **165** new-account
  2D images. This upload success is independent of potion/HUD gameplay validation.

### A18-3 Verification boundary
- Subsequent actual check: **36 Luau files compiled**, sync changed 0/kept 36, and a **15-second Play** started all
  **21/21 server services + 9 client modules** with no Luau runtime errors. The initial Play/Edit conflict was resolved;
  it was not a confirmed syntax failure. Prior A17 34-file/20-service/8-client result remains historical.
- Actual UI selected Halo/Mage. Studio DebugCommand set HP19.2/MaxHealth96 and MP20/MaxMana100. HP and MP button clicks
  recovered 30% (28.8) and 40% (40), with separate deadlines about server-now+10 seconds. Natural town HP/mana regen ran
  concurrently: first read HP68/MP64, then repeated clicks read HP78/MP68.1. Both deadlines remained exactly unchanged;
  the repeat did not grant an additional potion recovery. Both button status labels showed "9초".
  Evidence: `build/vitals_play_verify_result.json`. Do not misattribute the concurrent regeneration to the potion.
- **Still unverified:** keys 1/2, wrong kind/dead/not chosen/kaiju refusal, exact cost/failed-MP charge and cooldown
  preservation for Mage Swing/all-class Release, respawn mana refill and cosmetic resource/CD preservation.
  CostumeRigs still has 0 playable templates, so real costume replacement coverage remains pending.

## A19. Approved class attack motions and moving weapon origins (2026-10-03; runtime verification pending)

The user approved GPT `art/out/Motion_Class_Attacks_A.png` ("좋았으"). The code in CharacterVisuals, CombatService and Fx
implements that selected three-class sheet. Do not treat approval as proof the final in-game motion has been tested.

- Warrior: prepare/rotate/slash/recover for Swing; overhead preparation and ground smash for Release. Archer: hold the
  bow upright in the **left hand**, visibly draw its string with the right hand, fire from the actual bow, and use the
  approved upward Release/volley motion. Mage: gather in the left palm, thrust the right-hand staff and launch at its tip;
  Release keeps the approved meteor gesture. Keep stock animation fallback for unsupported rigs/procedural failures.
- CharacterVisuals assigns WeaponModel's Class/GripHand, mounts the bow to left grip and sword/staff to right grip,
  adds class-appropriate AttackMuzzle, and uses two bow-string Beams sharing the movable BowNock.
- Fx follows the current hands/weapon after the procedural pose batch: bow nock follows the right grip while drawn,
  temporary arrow follows nock→muzzle, and Mage gather follows the current left palm. Reset nock and remove temporary
  arrow/gather when the attack stops. Read the class-matched AttackMuzzle **at launch time**, with the proper hand as
  fallback; do not launch from a stale packet hand position.
- Swing/Release Fx carry Character identity, Class, Faction and launch/contact/flight delays. Deferred motion/launch/hit
  display checks the same living Character, current Class/Faction and actor token; character replacement/death or
  class/faction change invalidates the stale context. Server manual-queue requests also capture and validate these
  identities and are cleared on class/faction changes.
- Existing target selection, damage/reward/charge rules remain server-owned. Accepted damage and cooldown resolve
  immediately; clip launch/contact/flight delays coordinate visuals and shove timing. Add only the A18 mana gate.
  The client must never deal extra damage, decide a hit, consume server charge or move a player to match an animation.
- All three final motions, actual muzzle origin, visible string/staff behavior, class/faction/respawn cancellation and
  coexistence with movement/hurt remain **unverified in final Play** until root reports results. Keep A16 multiplayer/
  persistence/anti-cheat limits and the 0-playable-costume limitation.
