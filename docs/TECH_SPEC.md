# TECH_SPEC — Halo & Horns (선악 키우기) MVP v2

> **2026-10-09 검수 — 이 문서는 10/02 MVP v2의 원래 계약이다(일부만 고쳐 둠).** 지금 계약은 `SPEC_ADDENDUM.md`
> (A23 안에서는 번호가 클수록 최신, 10/09 기준 A23-99까지)와 `src/` 코드다. 이 문서와 다르면 그쪽이 맞다. 크게 바뀐 곳:
> - 전투: 충전·발사·PERFECT 없음 → 수동 한 번 = 공격 한 번 + 자동 전투 켜기/끄기(왕관 조각 퀘스트로 해금, Lv5 첫 스킬 뒤, 몬스터만; A22·A23-1·A23-71).
>   스킬 = 직업마다 3칸, Lv5·15·25에 배움(`Config.Skills.Unlock` Q=5·Z=15·X=25 — Q·Z·X는 내부 칸 이름이고 기본 키는 Z·X·C, A23-78; 원격 `UseSkill`; A23-49·A23-71). 단 Z·X 칸은 10/20 점검에서 켤지 정한다 — 지금 `Config.Skills.ZEnabled`·`XEnabled` = false(A23-86 결정 3). 기본 공격 = 앞쪽 반원(A23-61).
>   맨손으로 시작하고 첫 무기는 대장간에서 받는다(A23-34·A23-74), 대장간까지 걸어간다(A23-88).
> - 글: 게임 화면은 영어만(A23-48). 아래의 한국어 문구·`Config.Text` 예시는 옛 것이다.
> - 저장 `Config.Data.Version = 3`, 새 필드가 많다(§6.1 메모). 원격은 52개(§4.2·§5 메모). 서버 서비스 48개, 클라이언트 모듈 37개(§2·§7 메모).
> - 대장간 = 사고팔기(`UpgradeWeapon(tier)`·`SellWeapon`, A23-4). 무기 8단계(T8 = 전설 드랍, A23-12). 강화 주문서(A23-11·A23-12). 환생 = 레벨만 초기화(A23-14).
> - 돈: 베타 전 게임 패스(2배 경험치 199·2배 골드 149·VIP 249·후광/뿔 치장 99) + 개인 서버 100(A23-75). 변경권은 베타에서 안 판다(A23-28). 능력치는 절대 안 판다.
> - 진영 `Neutral`(장인 길드)은 코드에 있지만 베타에서 새로 못 고른다(A6·A23-57). 플레이어 = 본인 Roblox 아바타 + 직업 무기 + 후광/뿔, 베타는 R15만(A23-5·A23-28).
> - 화면 배치·키는 A23-40·A23-74·A23-78·A23-94·A23-98(PC 먼저)이 정한다. 아래 §4.23의 HUD 표·키는 옛 것이다.
> - 작업 방식: G1~G12 병렬 구현과 "copy verbatim" 규칙은 10/02 기록이다. 지금 세션(10개)·역할은 `docs/handoff/role_prompts/README.md`, Studio·커밋 규칙은 `AGENTS.md`가 정한다(메인 Studio sync·Play·저장 = 메인 반영 1, `01_mainapply.md`).
>
> **2026-10-05 최신 사용자 변경:** `SPEC_ADDENDUM.md` **A23**이 이 문서보다 우선한다 — 수동 전투 + 왕관 조각 선택 퀘스트로
> 얻는 자동 전투 켜기/끄기(자동은 몬스터만), 대장간 선택 구매/판매 계약(옛 "UpgradeWeapon = 다음 티어 자동 장착" 대체),
> ~~환생 시 보유 무기 초기화~~ → 환생은 레벨만 초기화, 골드·무기 유지(A23-14), 치비 3D 코스튬 제거, Firefly 그림. 아래 §1.1의 "No asset IDs"(지금은 승인 이미지 ID를 `Config.UIArt`로 사용)와
> "Do NOT run sync_to_studio/playtest/build_place — the lead does integration"(사용자 10/08부터 메인 Studio sync·Play·저장은 메인 반영 1 세션만 한다;
> `build_place.py`는 여전히 실행 금지)은 과거 규칙이다. 규칙 순서는 `AGENTS.md` "Which rule wins".
>
> **2026-10-04 사용자 변경:** 사용자가 자동 전투 방향에서 마음을 바꿔 수동 전투를 선택했다.
> `SPEC_ADDENDUM.md` **A22**와 `GDD.md` **§0-2**가 이 문서의 자동 공격·충전 게이지·PERFECT·자동 발사·스택 조건,
> 다음 해금 예고 및 옛 튜토리얼 계약보다 우선한다. 아래 v2 코드 예제·피해 계산·검사 목록의 해당 부분은 과거 기준이다.
> 현재 스킬은 MP·재사용 시간으로 동작하며 기본 구현값은 MP20·3초다(→ 지금 스킬 규칙은 위 10/09 메모). 과거 기능을 복구하지 않는다.
> 현재 소스 반영과 실제 Studio 통합 검증 완료는 구분한다. 새 실행 검증은 2026-10-06 작업 재개 후 진행한다.

Audience: implementer agents writing files **in parallel without talking to each other**. Every cross-file contract
(module names, function signatures, signal names, remote names, payload shapes, attribute names, data keys, config keys)
is defined here. **If something is not in this document, do not invent a public contract for it** — keep it private
inside your own file. If this spec and your intuition disagree, follow the spec.

Companion design doc (Korean, for the human): `docs/GDD.md`. This spec implements GDD Milestones A + B + C **plus** the v2
systems: Size Justice (덩치 저울), Grudge Bag (원한 돈자루), ~~Charge & Release (자동은 장전, 손은 발사)~~ (removed: A22, A23-1), Wanted Kaiju
(수배범 괴수화), Golden Goose Tug (황금 거위 줄다리기) + Regular's Luck (→ Today's Luck, A23-18), Turncoat Rebirth (전향 환생), Daily quests +
Vacation bonus, Classes (직업), Light story (세계관 문구), Robux change tickets (변경권; not sold in the beta, A23-28). All of it is in the MVP build.

v2 removed these v1 contracts — do not implement or reference them: faction skills (`UseSkill` remote, `SkillReadyAt`,
`SkillUsed`, Fx `Skill`, `Config.Factions.*.Skill`) (2026-10-09: a NEW `UseSkill(slot)` remote for the 3 class skills came back
with SKL-2, A23-49 / A23-71, and the attributes `SkillReadyAt` / `SkillReadyAtZ` / `SkillReadyAtX` are the class-skill
cooldowns — the old faction-skill contract stays removed), the percentage underdog bonus (`Config.Underdog`, `GetUnderdog`,
GameState `UnderdogFaction`/`UnderdogTier`), the 10-level-gap rule, the "2 KOs in 10 min" anti-camp immunity, the 50%
justice refund (`JusticeRefundRate`, `stolenThisLife`), the "first switch free + 30 min" rule, and everything named
`Sword*` (now `Weapon*`).

> **Later changes:** `docs/SPEC_ADDENDUM.md` (A1–A23, newest first; inside A23 the higher number is newer) overrides this document where they conflict. Code review R1
> (2026-10-03) changed many contracts below; they are marked "R1 / CR-xx" here and listed in full in **A16**.

---

## 1. Overview & architecture

### 1.1 Hard rules (apply to every file)
- Single Roblox place. Source in `C:/Users/glori/Documents/Roblox/Game/src`, Rojo-style layout (no Rojo installed).
  ~~built by `tools/build_place.py` into `build/GoodEvil.rbxlx`~~ → 2026-10-09: the 메인 반영 1 session runs `py tools/sync_to_studio.py`
  (only from code equal to origin/main, AGENTS.md Hard rule 5) to push `src/` into the open main Studio (cloud place
  81671223175574); it is saved with File > Save to File As `build/GoodEvil.rbxlx` and copied
  to `place/`. Never run `tools/build_place.py` without arguments (AGENTS.md). `*.server.luau` = Script, `*.client.luau` = LocalScript, `*.luau` = ModuleScript,
  directories = Folder. No `init.*` files are used in this project. No `.rbxm`/model files in `src/` (2026-10-09: 3D models
  are imported into the place itself — monsters, goose and pets in `ServerStorage.CustomModels`, A1 / A23-47).
- ~~**No asset IDs** of any kind (no `rbxassetid://`, no `http://www.roblox.com/asset`).~~ → approved image / sound ids
  are used through `Config.UIArt` and `Config.Audio` (A17, A23-7, A23-67); a few free Creator Store / Roblox ids stay in
  the module that uses them (e.g. `FountainFx` particle textures, `Fx` tool animations); `Config.CustomModels` only names the
  `ServerStorage.CustomModels` folder (A1). Still allowed: Parts, Materials, Colors,
  BillboardGui/SurfaceGui, ParticleEmitter (default texture), Highlight, PointLight, ForceField, built-in
  `rbxasset://sounds/*.wav` files listed in `Config.Sounds` (optional; failure to load must be silently ignored).
- The map is generated by `MapBuilder` (or reused if a pre-baked `workspace.Map` exists, §4.6). All UI is built at
  runtime by client modules. All player-facing text is ~~**Korean**~~ **English only** (A23-48, easy English for kids,
  `docs/design/glossary_en_2026-10-06.md`) and lives in `Config.Text` / `Config.Story` (or other
  Config tables). Code comments/identifiers in English.
- Server-authoritative: damage, gold, XP, level, bounty, stars, charge stacks, sacks, events, tickets, purchases, quests
  are computed on the server only. Clients send **intents** through RemoteEvents; every handler validates (ready check,
  type check, rate limit, range/state).
- Luau style: `task.wait/task.spawn/task.delay/task.defer` only (never `wait`, `spawn`, `delay`). Plain Luau, no external
  libraries, type annotations optional. Strict nil checks before indexing anything that can be missing
  (characters, HumanoidRootPart, players that left). Generalized iteration (`for _, v in t do`) or `ipairs` — both fine.
- Time sources: `os.clock()` for local cooldowns/rate limits on one machine; `workspace:GetServerTimeNow()`
  (exposed as `Util.Now()`) for any timestamp sent to clients through attributes; `os.time()` only for persisted
  timestamps and day math (`LastSwitchTime`, `FirstJoinTime`, `LastLogoutTime`, `Config.DayIndex`, session lock).
  `Util.Now()` and `os.time()` are both Unix seconds, so the client may compare `LastSwitchTime` with `Util.Now()`.
- Faction ids are exactly `"Halo"`, `"Horns"`, `"None"` (+ `"Neutral"`, the artisan guild, A6; no new Neutral pick while
  `Config.Features.NeutralFaction = false`, A23-57). Class ids are exactly `"Warrior"`, `"Mage"`, `"Archer"` (Neutral `"Archer"` is shown as the Pet Tamer, A23-39).
  Zone ids exactly as in `Config.ZoneOrder` plus `"Outskirts"`.
- **Logging (console must be diagnosable — the lead tests live in Studio via MCP and reads the Output):**
  every server service prints exactly one line `[<ServiceName>] started` as the **last statement of its `Start()`**
  (e.g. `print("[CombatService] started")`); every client module prints `[<ModuleName>] started` at the end of its
  `Start()`. Every `warn` starts with `[<ServiceName>] ` (use `Util.Warn(tag, msg)`). No other per-frame/per-swing prints.
- **Syntax check before you finish:** `py tools/luau_check.py <paths under src/>` (e.g.
  `py tools/luau_check.py ServerScriptService/CombatService.luau`). It compiles your files with the real Roblox compiler
  (loadstring in the open Studio, nothing is executed). Fix every error it reports. ~~**Do NOT run
  `tools/sync_to_studio.py`, `tools/playtest.py` or `tools/build_place.py`** — the lead does integration and play tests.~~
  → since 2026-10-08 (user): only the 메인 반영 1 session syncs, plays and saves the main Studio (`docs/handoff/role_prompts/01_mainapply.md`); `tools/build_place.py` is still never run.
- Robux: only `MonetizationService` touches `MarketplaceService` on the server (it owns `ProcessReceipt` and the A23-75
  game-pass checks `UserOwnsGamePassAsync` / `PromptGamePassPurchaseFinished`). Client prompts: `PromptGamePassPurchase` in
  `ShopUI` (A23-75 passes / looks) and `PromptProductPurchase` in `Panels` / `ShopUI` (change tickets, not sold in the beta, A23-28),
  only when the id is not 0.
- Character size: only `JusticeService` calls `Model:ScaleTo` on characters (always through `Util.SafeScaleTo`).
  Everyone who builds parts on a character multiplies sizes/offsets by `character:GetScale()` at build time.

### 1.2 Manual Studio settings (cannot be set from the built file — document only)
- Game Settings > Security: **Enable Studio Access to API Services** (to test saving; game still runs without it).
- Max players per server: **20** (Game Settings > Places after publishing). `Config.Game.MaxPlayers` documents it.
- Avatar: R6 or R15 both supported (all code must handle both rigs: look for `RightHand` then `Right Arm`,
  `UpperTorso` then `Torso`). 2026-10-09: the beta place is **R15 only**; R6 is allowed again at the full launch (A23-28).
- Workspace.StreamingEnabled: leave **false** for the MVP. (2026-10-09: still `false` in `place/GoodEvil.rbxlx`; A23-47 /
  A23-53 list StreamingEnabled for phone performance, not turned on yet.)
- ~~Developer Products (after publishing): create **two** consumable Developer Products on create.roblox.com
  (직업 변경권 ≈ 49 R$, 진영 변경권 ≈ 79 R$) and paste their ids into `Config.Products.*.Id`. While an id is 0 the buy
  buttons show "상품 준비 중" and nothing can be bought.~~ → 2026-10-09: change tickets are not sold in the beta (A23-28).
  At publish the user creates the A23-75 game passes (2x XP 199, 2x Gold 149, VIP 249, faction looks 99 each) and turns on
  private servers (100 R$ / month), then pastes the ids into `Config.GamePasses` / `Config.Looks`; while an id is 0 the
  shop shows "Coming soon" (`docs/design/launch_ops_checklist.md`).

### 1.3 Architecture diagram

> 2026-10-09 검수: 이 그림은 낡음(10/02의 서비스 19개·클라이언트 7개·원격 16개). 지금은 서버 서비스 48개(`Main.server.luau`의 INIT_ORDER), 클라이언트 모듈 37개(`ClientMain.client.luau`의 ORDER), 원격 52개(`Net.Names`)이고, 충전·발사 칸은 없어졌다(A22·A23-1). 구조(Init(S)/Start, S·C 레지스트리)는 그대로다.

```
                         ReplicatedStorage
   Shared/Config (all numbers, formulas, Korean text)   Shared/Util (Signal, helpers)   Shared/Net (remotes + helpers)
   Remotes/ (16 RemoteEvents, created by Net.CreateAll)   GameState/ (Folder; war, counts, justice, goose, kaiju attrs)
          ^ require                                            ^ WaitForChild
          |                                                    |
 ServerScriptService                                           |   StarterPlayerScripts (client)
 Main.server.luau -- requires + Init(S) + Start()              |   ClientMain.client.luau -- requires + Init(C) + Start()
   S = registry table of all services                          |     C = registry of client modules
   +-- DataService        (DataStore, session lock, v1->v2)    |     UIKit         (ScreenGui, widgets, toasts, confirm)
   +-- PlayerService      (join/leave, attributes, spawn,      |     Fx            (numbers, class projectiles, release
   |                       MaxHealth, regular-minutes)         |                    blasts, shake, stomp, rare)
   +-- MonetizationService(ProcessReceipt, tickets)            |     HUD           (stats, war meter, quests, 5 buttons,
   +-- MapBuilder         (procedural map / reuse)             |                    charge ring, inputs)
   +-- ZoneService        (zones, travel, pads)                |     EventHUD      (goose bar, kaiju banner, arrows,
   +-- FactionService     (Teams, choose/altar switch)         |                    sack/revenge line, luck corner)
   +-- ClassService       (choose/change class)                |     Panels        (Menu/Travel/Rebirth/Altar/Class/
   +-- JusticeService     (power sums, Size S, bully, scale)   |                    Shop/Vacation)
   +-- ProgressionService (XP, gold, bank, turncoat rebirth)   |     FactionPicker (first-join faction + premise)
   +-- CombatService      (class swings, charge & release,     |     ClassPicker   (class choice + intro toasts)
   |                       damage, regen, death pipeline)      |
   +-- MonsterService     (spawn, AI, monster HP)              |   Client reads ONLY: Player attributes (own + others'),
   +-- PvPService         (rules, bully KO, stars, bounty,     |   GameState attributes, Remotes (Notify/Fx/OpenPanel),
   |                       revenge, protection, board)         |   Character/Workspace instances for visuals.
   +-- GrudgeService      (grudge sack: steal/avenge/pay)      |   Client writes ONLY: client->server RemoteEvents and
   +-- KaijuService       (queue, siren, kaiju, stomp, pool)   |   MarketplaceService:PromptProductPurchase.
   +-- GooseService       (golden goose tug, rare rewards)     |
   +-- WarService         (crown war meter, rounds, sky)       |
   +-- ShopService        (weapon upgrade)                     |
   +-- QuestService       (dailies, extras, vacation)          |
   +-- CharacterVisuals   (nametag, marks, weapons, sacks,     |
                           ghost, auras, glow, kaiju fire)     |
```

### 1.4 Service pattern (server) — MANDATORY
Every server ModuleScript in `ServerScriptService` (except `Main`) returns a table `M` with:
- Public signals created **at module top level** (so they exist before any `Init`): `M.SomeSignal = Util.Signal.new()`.
- `function M.Init(S)` — store `S` (the registry: `S.DataService`, `S.PlayerService`, …). May create private state,
  connect to *other services' signals*, create instances that nobody else needs yet. **Must not yield. Must not call
  other services' functions.**
- `function M.Start()` — may call other services, connect remotes (`Net.Get(name).OnServerEvent:Connect(...)`),
  start loops with `task.spawn`. Must not yield for more than one frame except `MapBuilder.Start` (synchronous build).
  Last line: `print("[<ServiceName>] started")`.
- Services never `require` each other. They only use `S.<ServiceName>`. They may `require` the three Shared modules.
- Signals: `Util.Signal` (§4.1). `Fire` calls handlers **synchronously** in connection order, each in `pcall`
  (an erroring handler warns and does not stop others). Handlers must not yield; if they need to, wrap in `task.spawn`.
- Calling another service's public function from a signal handler, remote handler or loop is allowed (all services are
  initialized by then). Where order matters, this spec uses **direct calls** instead of signals (e.g. the death pipeline).

Client modules follow the same pattern with registry `C` (`C.UIKit`, `C.Fx`, `C.HUD`, `C.EventHUD`, `C.Panels`,
`C.FactionPicker`, `C.ClassPicker`; 2026-10-09: 37 modules, see `ClientMain.client.luau`).

### 1.5 v2 systems → owners (read the referenced sections)

> 2026-10-09 검수: 이 표는 10/02 것이다. "Charge & Release" 줄은 낡음(충전 게이지 없음, `Release` 원격은 이제 첫 스킬 칸, A22·A23-1·A23-49), "Regular's Luck"는 오늘의 운(A23-18), 변경권은 베타에서 안 판다(A23-28). 그 뒤 생긴 시스템은 SPEC_ADDENDUM에서 본다: 스킬 SkillService(A23-49·A23-71), 드랍·주문서 LootService(A23-11·A23-12), 이야기 퀘스트 StoryQuestService, 랭킹 RankingService(A23-23·A23-24), 출석 AttendanceService(A23-77), 펫 PetService(A23-39·PET-2), 게임 패스·치장 MonetizationService(A23-75), 다시 오기 묶음 Return/Invite/DiaryService(A23-79), 선행 장부·선택 카드·의뢰 Deeds/ChoiceCard/CommissionService(A23-86).

| System | Owner(s) | Key contracts |
|---|---|---|
| Size Justice (S per faction, MaxHealth/damage/size) | JusticeService (§4.12) | `Config.PowerOf`, `Config.SizeJustice`, GameState `HaloSize`/`HornsSize`, attrs `SizeMult`, `VisualScale` |
| Bully shrink | PvPService detects (§4.13), JusticeService stores stacks | `Config.Bully`, attr `BullyStacks`, `PlayerKO` info `Bully` |
| Revenge | PvPService | `Config.Revenge`, attrs `RevengeTargetId`, `RevengeUntil`, `HasRevenge` |
| Grudge sack | GrudgeService (§4.14); PvPService feeds it; CombatService death pipeline resolves | `Config.Grudge`, attrs `SackGold`, `SackSeconds`, `SackVictimName` |
| Charge & Release | CombatService (§4.9) | `Config.Charge`, `Release` remote, attrs `Charge`, `ChargeCap`, `PerfectUntil`, signal `Released` |
| Classes | ClassService (§4.11) + CombatService targeting + CharacterVisuals weapons | `Config.Classes`, `ChooseClass`/`ChangeClass` remotes, attr `Class` |
| Wanted Kaiju | KaijuService (§4.15) | `Config.Kaiju`, GameState `Kaiju*`, attr `KaijuState`, `SessionTitle` |
| Golden Goose + Regular's Luck + cheer stars | GooseService (§4.16), PlayerService (regular minutes) | `Config.Goose`, `Config.Luck`, GameState `Goose*`, attrs `GooseCount`, `RegularMinutes`, `CheerStars` |
| Turncoat Rebirth | ProgressionService (§4.18) + FactionService.SetFaction | `Config.Rebirth`, `Rebirth(factionId)` remote, `RebirthBonus`, `FallMarks`, `RedeemMarks` |
| Daily quests + Vacation | QuestService (§4.20) | `Config.Quests`, `Config.Daily`, `ClaimQuest`/`ClaimVacation` remotes |
| Robux change tickets | MonetizationService (§4.21); used by ClassService & FactionService | `Config.Products`, `Tickets`, `ProcessedReceipts`, attrs `ClassTickets`/`FactionTickets` |
| Light story | Config.Story / Config.Text; shown by pickers, banners, panels | `Config.Story.*` |

---

## 2. File list & implementer groups

> 2026-10-09 검수: 이 절은 낡음 — G1~G12 병렬 구현 그룹·줄 수 목표는 10/02 첫 구현 기록이다. 지금 파일 목록은 `src/`(10/09: 서버 `ServerScriptService` 49파일 = Main + 서비스 48, 클라이언트 `StarterPlayerScripts` 39파일 = ClientMain + ORDER 모듈 37 + HUD가 require하는 `HudLayout`)이고, 누가 무엇을 맡는지는 `docs/handoff/role_prompts/README.md`(세션 10개)가 정한다. ShopService는 사고팔기(A23-4), Panels의 Shop 칸은 변경권 대신 게임 패스(ShopUI, A23-75)다.

Twelve groups. Each file is owned by exactly one group. Line budgets are targets (±30%). New logic ≈ 8,400 lines in
G2–G12 (no group above ~850); G1 copies ≈ 1,240 lines of Shared code **verbatim** from this document.

| Group | Scope | ~New lines |
|---|---|---|
| **G1** Shared foundation | Config, Util, Net — copy §3 / §4.1 / §4.2 **verbatim** (fix only syntax errors if any) | (copy ≈ 1,240) |
| **G2** Data, lifecycle & Robux | Main, DataService, PlayerService, Health override, MonetizationService | 760 |
| **G3** World & war | MapBuilder, ZoneService, WarService | 790 |
| **G4** Combat | CombatService | 720 |
| **G5** Monsters & visuals | MonsterService, CharacterVisuals | 800 |
| **G6** Identity & balance | FactionService, ClassService, JusticeService | 660 |
| **G7** PvP & grudge | PvPService, GrudgeService | 620 |
| **G8** Progression & quests | ProgressionService, ShopService, QuestService | 780 |
| **G9** Server events | GooseService, KaijuService | 620 |
| **G10** Client core | ClientMain, UIKit, HUD | 700 |
| **G11** Client effects & event UI | Fx, EventHUD | 680 |
| **G12** Client menus | Panels, FactionPicker, ClassPicker | 800 |

| Path (under `src/`) | Type | Group | ~Lines | Responsibility |
|---|---|---|---|---|
| `ReplicatedStorage/Shared/Config.luau` | Module | G1 | 930 | Every tuning number, pure helper formula and Korean string (§3) |
| `ReplicatedStorage/Shared/Util.luau` | Module | G1 | 220 | Signal, formatting, rate limit, character/part helpers, log helpers, SafeScaleTo (§4.1) |
| `ReplicatedStorage/Shared/Net.luau` | Module | G1 | 85 | Remote names, creation, lookup, Notify/Fx helpers, GameState folder (§4.2) |
| `ServerScriptService/Main.server.luau` | Script | G2 | 90 | The only server entry point; registry, Init all, Start all, Studio debug hook (§7) |
| `ServerScriptService/DataService.luau` | Module | G2 | 260 | DataStore load/save, session lock, retries, autosave, v1→v2 migration, Studio memory mode |
| `ServerScriptService/PlayerService.luau` | Module | G2 | 250 | Join/leave, attribute mirroring, leaderstats, spawn/respawn, MaxHealth/WalkSpeed, playtime, regular minutes |
| `StarterPlayer/StarterCharacterScripts/Health.server.luau` | Script | G2 | 2 | Empty script that replaces Roblox's default regen script (comment only) |
| `ServerScriptService/MonetizationService.luau` | Module | G2 | 160 | `ProcessReceipt` (idempotent), ticket grant/use, ticket attributes, Studio product hint |
| `ServerScriptService/MapBuilder.luau` | Module | G3 | 390 | Builds or reuses `workspace.Map`: floors, walls, towns, decor, gates, pads, altar, board, goose perch |
| `ServerScriptService/ZoneService.luau` | Module | G3 | 180 | Zone tracking, level gates, Travel remote, teleport pads, spawn CFrames |
| `ServerScriptService/WarService.luau` | Module | G3 | 220 | Crown war meter, 10-min rounds, faction points, blessing, sky, war chests |
| `ServerScriptService/CombatService.luau` | Module | G4 | 720 | Class swing patterns, charge & release, damage formulas, player damage, regen, auto-attack, death pipeline |
| `ServerScriptService/MonsterService.luau` | Module | G5 | 330 | Monster rigs, spawn/respawn, AI loop, monster HP, kill rewards signal |
| `ServerScriptService/CharacterVisuals.luau` | Module | G5 | 470 | Nametag, faction mark, 3 class weapons, gold sack, grudge sack + ghost, auras, marks, glow, kaiju fire |
| `ServerScriptService/FactionService.luau` | Module | G6 | 220 | Teams, ChooseFaction, altar SwitchFaction (free/ticket), SetFaction, faction counts |
| `ServerScriptService/ClassService.luau` | Module | G6 | 160 | ChooseClass (first pick), ChangeClass (free = Lv 1 / ticket = keep level) |
| `ServerScriptService/JusticeService.luau` | Module | G6 | 280 | Faction power sums, Size Justice S, bully stacks + decay, character scale lerp |
| `ServerScriptService/PvPService.luau` | Module | G7 | 400 | CanAttack, protection, bully detection, KO outcomes, stars, bounty, revenge, Most Wanted board |
| `ServerScriptService/GrudgeService.luau` | Module | G7 | 220 | Grudge sack: add, PvP-zone countdown, payout, avenge (120%) / return (100%), anti-collusion |
| `ServerScriptService/ProgressionService.luau` | Module | G8 | 300 | XP/levels, carried/bank gold, auto-bank, multipliers, kill rewards, turncoat rebirth, ResetLevel |
| `ServerScriptService/ShopService.luau` | Module | G8 | 70 | UpgradeWeapon remote |
| `ServerScriptService/QuestService.luau` | Module | G8 | 410 | 3 slots: dailies (KST day) → extras, claim, chest, reroll, vacation bonus, `QuestsJson` |
| `ServerScriptService/GooseService.luau` | Module | G9 | 290 | Golden goose schedule, model, tug counting, rewards (rare/cheer stars), war points |
| `ServerScriptService/KaijuService.luau` | Module | G9 | 330 | Kaiju queue, siren, kaiju HP/scale, stomp, participants, reward pool, survive reward |
| `StarterPlayer/StarterPlayerScripts/ClientMain.client.luau` | LocalScript | G10 | 45 | The only client entry point (§7.2) |
| `StarterPlayer/StarterPlayerScripts/UIKit.luau` | Module | G10 | 220 | ScreenGui, UIScale, theme, widget factories, toasts/announcements, confirm dialog, attribute helpers |
| `StarterPlayer/StarterPlayerScripts/HUD.luau` | Module | G10 | 440 | Stats, war meter, status chips, quest rows (claim/reroll), 5 big buttons + charge ring, inputs, travel bar |
| `StarterPlayer/StarterPlayerScripts/Fx.luau` | Module | G11 | 360 | `Fx` remote: numbers, class swing projectiles, release blasts, shake, stomp, rare, coins, combo, sounds |
| `StarterPlayer/StarterPlayerScripts/EventHUD.luau` | Module | G11 | 320 | Goose timer/tug bar, kaiju siren/timer, screen-edge arrows, sack/revenge line, luck corner |
| `StarterPlayer/StarterPlayerScripts/Panels.luau` | Module | G12 | 500 | Modal panels: Menu, Travel, Rebirth (turncoat), Altar, Class, Shop (tickets), Vacation |
| `StarterPlayer/StarterPlayerScripts/FactionPicker.luau` | Module | G12 | 150 | First-join faction choice with the story premise |
| `StarterPlayer/StarterPlayerScripts/ClassPicker.luau` | Module | G12 | 150 | First class choice (faction-specific names) + one-time intro toasts |

Exact content of `Health.server.luau`:
```lua
-- Intentionally empty. Replaces Roblox's default "Health" regen script; regen is handled by CombatService.
```

---
## 3. Shared Config — `src/ReplicatedStorage/Shared/Config.luau` (G1, copy verbatim)

> 2026-10-09 검수: 아래 코드는 10/02 첫 Config(약 930줄)의 사본이라 낡음 — "copy verbatim"은 하지 않는다. 지금 Config는 `src/ReplicatedStorage/Shared/Config.luau`(약 6,500줄)가 정답이다. 크게 다른 것: `Config.Game.Name = "Halo & Horns"`, 모든 글 영어(A23-48), `Config.Data.Version = 3`·`Defaults.WeaponTier = 0`(맨손, A23-34), `Config.Weapons` 8단계(T8 전설, A23-12)·`Config.WeaponShop.MaxSoldTier = 3`(A23-4), `Config.FactionOrder`에 Neutral(A6·A23-57), 구역 8개(PumpkinPatch·HauntedHollow 추가, A23-30·A23-45), 몬스터 17종(A23-84·A23-87), `Config.Skills`·`Config.Loot`·`Config.GamePasses`·`Config.Looks`·`Config.Keybinds`·`Config.Attendance` 등 새 표, `Config.Charge`(충전) 표는 남아 있지만 서비스가 쓰지 않는다(충전 게이지 없음, A22). 변경권 상품 이름은 영어, 베타에서 안 판다(A23-28).

Require path everywhere: `local Config = require(game:GetService("ReplicatedStorage").Shared.Config)`.
Nobody else hard-codes a gameplay number or a player-facing sentence. If a number you need is missing, add a **private**
local constant in your own file and leave a `-- TODO(config)` comment.

**String rule:** every string in `Config.Text` and `Config.Story` is ALWAYS used through `string.format(str, ...)`, even
when it takes no arguments (a literal percent sign is written `%%`). Other display strings (`Perks`, `Pitch`, `Stats`,
`Desc`, `Names`, weapon/zone/monster names, `Premise`/`Intro`/`ZoneLore`/`FactionLore` lines) contain no format
specifiers and are shown as-is. (`Config.Story.Premise`, `Intro`, `ZoneLore`, `FactionLore`, `MarkLore` are plain.)

```lua
-- Config.luau : every tuning number, pure helper formula and Korean string for Halo & Horns.
-- Shared by server and client. Pure data + pure functions only (no services, no instances).
local Config = {}

Config.Game = {
	Name = "선악 키우기: 헤일로 & 혼즈",
	MaxPlayers = 20, -- documentation only; set in Studio Game Settings
}

----------------------------------------------------------------- player / data
Config.Player = {
	WalkSpeed = 20,
	RespawnTime = 3,
	BaseMaxHealth = 100,
	MaxHealthPerLevel = 10,
	PlaytimeTick = 5, -- seconds between PlaytimeSeconds updates
}

Config.Data = {
	StoreName = "HaloHorns_Player_v1", -- unchanged on purpose: v1 saves are migrated in place by DataService
	KeyPrefix = "P_",
	Version = 2,
	AutosaveInterval = 60,
	LockTimeout = 120, -- seconds; a lock older than this is considered dead
	LoadRetries = 5,
	LoadRetryDelay = 3,
	SaveRetries = 3,
	Defaults = {
		Version = 2,
		Level = 1,
		XP = 0,
		BankGold = 0,
		CarriedGold = 0,
		WeaponTier = 1, -- v1 name: SwordTier (migrated by DataService)
		Faction = "None",
		Class = "Warrior",
		ClassChosen = false, -- false -> ClassPicker shows (first pick is free and keeps level)
		Rebirths = 0,
		RebirthBonus = 0, -- sum of per-rebirth bonuses (0.25 or 0.40 each); v1 data: Rebirths * 0.25
		FallMarks = 0, -- "타락" stacks (Halo -> Horns at rebirth), max Config.Rebirth.MarkMax
		RedeemMarks = 0, -- "구원" stacks (Horns -> Halo at rebirth), max Config.Rebirth.MarkMax
		Honor = 0, -- Halo rank points (kept while in Horns)
		Infamy = 0, -- Horns rank points (kept while in Halo)
		SwitchCount = 0,
		LastSwitchTime = 0, -- os.time() of the last ALTAR faction change
		PlaytimeSeconds = 0,
		TotalKills = 0,
		Quests = {},
		DailyDay = 0, -- Config.DayIndex of the day the current dailies were generated (0 = never)
		DailyClaims = 0, -- dailies claimed on DailyDay (0..3)
		VacationDays = 0, -- pending vacation reward (0 = nothing pending)
		VacationGold = 0,
		VacationXP = 0,
		CheerStars = 0, -- "응원별"
		Tickets = { Class = 0, Faction = 0 },
		ProcessedReceipts = {}, -- recent PurchaseId strings, oldest first, at most Config.Tickets.MaxReceiptsKept
		FirstJoinTime = 0,
		LastLogoutTime = 0,
	},
	-- keys mirrored 1:1 to Player attributes (same name) by PlayerService
	Mirrored = {
		"Level", "XP", "BankGold", "CarriedGold", "WeaponTier", "Faction", "Class", "ClassChosen",
		"Rebirths", "RebirthBonus", "FallMarks", "RedeemMarks", "Honor", "Infamy", "SwitchCount",
		"LastSwitchTime", "PlaytimeSeconds", "TotalKills", "DailyDay", "DailyClaims",
		"VacationDays", "VacationGold", "VacationXP", "CheerStars",
	},
}

----------------------------------------------------------------- levels
Config.Levels = {
	MaxLevel = 100,
	XPBase = 30,
	XPExponent = 1.4,
}

function Config.XPToNext(level)
	return math.floor(Config.Levels.XPBase * level ^ Config.Levels.XPExponent)
end

----------------------------------------------------------------- weapons (7 tiers shared by every class)
-- Damage = normal per-target swing damage at Lv 1 for class Damage multiplier 1.0, BEFORE the 50% immediate rule.
Config.Weapons = {
	{ Tier = 1, Damage = 8, Price = 0, MinLevel = 1, Color = Color3.fromRGB(120, 85, 50), Material = Enum.Material.Wood, Length = 3 },
	{ Tier = 2, Damage = 15, Price = 150, MinLevel = 1, Color = Color3.fromRGB(165, 120, 75), Material = Enum.Material.WoodPlanks, Length = 3.5 },
	{ Tier = 3, Damage = 38, Price = 800, MinLevel = 5, Color = Color3.fromRGB(175, 180, 190), Material = Enum.Material.Metal, Length = 4 },
	{ Tier = 4, Damage = 88, Price = 3000, MinLevel = 12, Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Metal, Length = 4.5 },
	{ Tier = 5, Damage = 200, Price = 10000, MinLevel = 20, Color = Color3.fromRGB(140, 220, 255), Material = Enum.Material.Glass, Length = 5 },
	{ Tier = 6, Damage = 450, Price = 30000, MinLevel = 30, Color = Color3.fromRGB(80, 255, 170), Material = Enum.Material.Neon, Length = 5.5 },
	{ Tier = 7, Damage = 1000, Price = 90000, MinLevel = 40, Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon, Length = 6.5,
		RequiresFaction = true,
		FactionColors = { Halo = Color3.fromRGB(255, 230, 120), Horns = Color3.fromRGB(200, 30, 40) },
	},
}
Config.MaxWeaponTier = #Config.Weapons

-- display names per class; tier 7 is a table keyed by faction
Config.WeaponNames = {
	Warrior = { "나뭇가지", "나무 검", "철 검", "황금 검", "크리스탈 검", "네온 검",
		{ Halo = "여명의 검", Horns = "파멸의 검", None = "왕관 조각 검" } },
	Mage = { "마른 지팡이", "참나무 지팡이", "철 지팡이", "황금 지팡이", "크리스탈 지팡이", "네온 지팡이",
		{ Halo = "여명의 지팡이", Horns = "파멸의 지팡이", None = "왕관 조각 지팡이" } },
	Archer = { "새총 활", "나무 활", "철 활", "황금 활", "크리스탈 활", "네온 활",
		{ Halo = "여명의 활", Horns = "파멸의 활", None = "왕관 조각 활" } },
}

function Config.WeaponName(tier, classId, factionId)
	local names = Config.WeaponNames[classId] or Config.WeaponNames.Warrior
	local n = names[tier]
	if type(n) == "table" then return n[factionId] or n.None end
	return n or "?"
end

function Config.WeaponColor(tier, factionId)
	local w = Config.Weapons[tier]
	if not w then return Color3.new(1, 1, 1) end
	if w.FactionColors and w.FactionColors[factionId] then return w.FactionColors[factionId] end
	return w.Color
end

-- normal per-target damage of the weapon at this level (before class, bonuses and multipliers)
function Config.WeaponDamage(tier, level)
	local w = Config.Weapons[tier] or Config.Weapons[1]
	return w.Damage * (1 + Config.Combat.LevelDamagePerLevel * (level - 1))
end

----------------------------------------------------------------- classes
-- Same buttons for everyone; the class only changes attack SHAPE, stats, weapon look and release shape.
Config.ClassOrder = { "Warrior", "Mage", "Archer" }
Config.Classes = {
	Warrior = {
		Id = "Warrior",
		Names = { Halo = "성기사", Horns = "광전사", None = "전사" },
		Desc = "내 주변 적을 한 번에 전부 베어요. 튼튼해요!",
		Weapon = "Sword",
		HealthMult = 1.3, Damage = 1.0, SwingInterval = 1.0,
		Pattern = "Around", -- every valid target within Range of self
		Range = 10, Targets = 0, Splash = 0, -- Targets 0 = unlimited
		ReleaseCenter = "Self", -- shockwave on self
		ChargeAuto = 1, ChargeManual = 2,
		Ranged = false, PvPMult = 1.0,
		WalkSpeedMult = 1.0,
		ReleaseMult = 1.0, -- tuning knob: multiplies this class's release damage
		Stats = { "체력 ×1.3", "공격 ×1.0", "주변 전체 공격" },
	},
	Mage = {
		Id = "Mage",
		Names = { Halo = "빛의 마법사", Horns = "흑마법사", None = "마법사" },
		Desc = "멀리 있는 적에게 마법 구슬! 맞은 곳 주변까지 펑!",
		Weapon = "Staff",
		HealthMult = 0.8, Damage = 1.3, SwingInterval = 1.25,
		Pattern = "Splash", -- nearest valid target within Range, then every valid target within Splash of it
		Range = 35, Targets = 1, Splash = 7,
		ReleaseCenter = "Target", -- meteor on the nearest target within Range (self if none)
		ChargeAuto = 1, ChargeManual = 2,
		Ranged = true, PvPMult = 0.85,
		WalkSpeedMult = 1.0,
		ReleaseMult = 1.0,
		Stats = { "체력 ×0.8", "공격 ×1.3", "35칸 원거리 + 폭발" },
	},
	Archer = {
		Id = "Archer",
		Names = { Halo = "레인저", Horns = "그림자 사냥꾼", None = "궁수" },
		Desc = "빠르게 두 명씩 쏘고, 발이 빨라요.",
		Weapon = "Bow",
		HealthMult = 1.0, Damage = 0.55, SwingInterval = 0.5,
		Pattern = "Multi", -- the Targets nearest valid targets within Range
		Range = 30, Targets = 2, Splash = 0,
		ReleaseCenter = "Target", -- arrow rain on the nearest target within Range (self if none)
		ChargeAuto = 0.5, ChargeManual = 1, -- swings twice as often, so half the stacks per swing
		Ranged = true, PvPMult = 0.85,
		WalkSpeedMult = 1.1,
		ReleaseMult = 1.0,
		Stats = { "체력 ×1.0", "공격 ×0.55 (2배 빠름)", "30칸 2명 동시 · 이동 +10%" },
	},
}

function Config.ClassName(classId, factionId)
	local c = Config.Classes[classId] or Config.Classes.Warrior
	return c.Names[factionId] or c.Names.None
end

----------------------------------------------------------------- combat
Config.Combat = {
	CritChance = 0.10, -- PvE swings only (never releases, never PvP)
	CritMult = 2,
	LevelDamagePerLevel = 0.02, -- weapon damage * (1 + 0.02 * (level - 1))
	AutoUnlockLevel = 5,
	TownRegenPerSec = 0.10, -- fraction of max HP per second inside Town zones (all factions)
	AutoLoopInterval = 0.1,
	RegenTick = 1,
	ChargeTick = 0.1, -- perfect-window watcher interval
}

----------------------------------------------------------------- charge & release ("자동은 장전, 손은 발사")
-- Design intent: pure idle (auto swings + auto release) ~= 1.25x baseline DPS; auto swings + PERFECT release ~= 2.5x.
Config.Charge = {
	SwingImmediate = 0.5, -- a swing that hits deals 50% of the normal per-target damage right away
	MinRelease = 10, -- minimum (floored) stacks to release
	BaseFactor = 0.5, -- release per target = BaseFactor * D * stacks * mult
	PerStackBonus = 0.02, -- manual release: mult = 1 + 0.02 * stacks
	AutoReleaseMult = 1.5, -- automatic release (PERFECT window missed): mult = 1.5
	PerfectWindow = 3, -- seconds the golden ring glows after reaching the cap
	RadiusBase = 8,
	RadiusPerStack = 0.1,
	PvPCapPct = 0.35, -- release damage to a player <= 35% of the target's current MaxHealth
	HaloHealPct = 0.10, -- Halo release heals allies in the radius by 10% of the total damage dealt...
	HaloHealCapPct = 0.30, -- ...capped at 30% of each ally's MaxHealth...
	HaloAllyStacks = 10, -- ...and gives each OTHER ally in the radius +10 stacks
}

function Config.ReleaseRadius(stacks)
	return Config.Charge.RadiusBase + Config.Charge.RadiusPerStack * stacks
end

-- perTargetDamage = D (the player's normal per-target swing damage vs that target); stacks = floored stacks
function Config.ReleaseDamage(perTargetDamage, stacks, isAuto)
	local mult = isAuto and Config.Charge.AutoReleaseMult or (1 + Config.Charge.PerStackBonus * stacks)
	return Config.Charge.BaseFactor * perTargetDamage * stacks * mult
end

----------------------------------------------------------------- factions
Config.FactionOrder = { "Halo", "Horns" }
Config.Factions = {
	Halo = {
		Id = "Halo", Name = "빛의 기사단", Short = "기사단", Emblem = "빛",
		TeamName = "빛의 기사단", TeamColor = BrickColor.new("New Yeller"),
		Color = Color3.fromRGB(255, 215, 90),
		XPBonus = 0.30, GoldBonus = 0, DamageBonus = 0,
		MaxHPMult = 1.2,
		RegenPerSec = 0.02, -- always on (outside towns)
		Lifesteal = 0, LifestealCapPct = 0,
		AutoBankInterval = 90, AutoBankFraction = 0.5,
		PartyAuraPerAlly = 0.05, PartyAuraMaxAllies = 3, PartyAuraRadius = 30,
		CanBeWanted = false,
		ChargeCap = 150,
		ReleaseSupport = true, -- release heals allies + shares stacks (Config.Charge.Halo*)
		Perks = {
			"경험치 +30% (레벨이 빨리 올라요)",
			"체력 +20%, 계속 체력 회복",
			"발사하면 주변 동료 치유 + 게이지 +10",
			"주머니 골드 절반 자동 저금",
			"원한 자루 도둑을 잡아 골드를 되찾아 줘요",
		},
		Pitch = "지키고, 치유하고, 되찾아 줘라!",
	},
	Horns = {
		Id = "Horns", Name = "뿔 군단", Short = "뿔 군단", Emblem = "뿔",
		TeamName = "뿔 군단", TeamColor = BrickColor.new("Really red"),
		Color = Color3.fromRGB(220, 50, 60),
		XPBonus = 0, GoldBonus = 0.25, DamageBonus = 0.15,
		MaxHPMult = 1.0,
		RegenPerSec = 0,
		Lifesteal = 0.10, LifestealCapPct = 0.03, -- heal 10% of damage dealt, max 3% max HP per swing/release
		AutoBankInterval = 0, AutoBankFraction = 0,
		PartyAuraPerAlly = 0, PartyAuraMaxAllies = 0, PartyAuraRadius = 0,
		CanBeWanted = true,
		ChargeCap = 175,
		ReleaseSupport = false,
		Perks = {
			"골드 +25% (빨리 부자가 돼요)",
			"공격력 +15%, 때리면 체력 흡수",
			"발사 게이지가 더 높이 쌓여요 (175)",
			"기사단을 털어 원한 자루를 지켜라",
			"현상수배 별 5개면 괴수로 변신!",
		},
		Pitch = "털고, 버티고, 괴수가 되어라!",
	},
	None = {
		Id = "None", Name = "무소속", Short = "무소속", Emblem = "?",
		TeamName = nil, TeamColor = BrickColor.new("Medium stone grey"),
		Color = Color3.fromRGB(200, 200, 200),
		XPBonus = 0, GoldBonus = 0, DamageBonus = 0,
		MaxHPMult = 1.0,
		RegenPerSec = 0.01,
		Lifesteal = 0, LifestealCapPct = 0,
		AutoBankInterval = 0, AutoBankFraction = 0,
		PartyAuraPerAlly = 0, PartyAuraMaxAllies = 0, PartyAuraRadius = 0,
		CanBeWanted = false,
		ChargeCap = 150,
		ReleaseSupport = false,
		Perks = {},
		Pitch = "",
	},
}

-- level-only base health (no faction, class, Size Justice or kaiju)
function Config.BaseHealth(level)
	return Config.Player.BaseMaxHealth + Config.Player.MaxHealthPerLevel * (level - 1)
end

-- "base MaxHealth": level x faction x class. PlayerService multiplies by JusticeService.GetHealthMult on top.
function Config.MaxHealth(level, factionId, classId)
	local f = Config.Factions[factionId] or Config.Factions.None
	local c = Config.Classes[classId] or Config.Classes.Warrior
	return math.floor(Config.BaseHealth(level) * f.MaxHPMult * c.HealthMult)
end

Config.Titles = {
	Thresholds = { 0, 10, 50, 200, 1000 },
	Halo = { "견습 기사", "기사", "성기사", "성자", "대천사" },
	Horns = { "불량배", "약탈자", "군벌", "공포의 군주", "마왕" },
	None = "모험가",
}

-- returns (titleText, rankIndex 1..5; 0 for None)
function Config.GetTitle(factionId, honor, infamy)
	local names = Config.Titles[factionId]
	if type(names) ~= "table" then return Config.Titles.None, 0 end
	local points = (factionId == "Halo") and (honor or 0) or (infamy or 0)
	local rank = 1
	for i, t in Config.Titles.Thresholds do
		if points >= t then rank = i end
	end
	return names[rank], rank
end

-- title shown on nametag / HUD: session title > gray legend > rank title
function Config.DisplayTitle(factionId, honor, infamy, fallMarks, redeemMarks, sessionTitle)
	if type(sessionTitle) == "string" and sessionTitle ~= "" then return sessionTitle end
	if (fallMarks or 0) >= Config.Rebirth.GrayLegendMin and (redeemMarks or 0) >= Config.Rebirth.GrayLegendMin then
		return Config.Story.GrayLegendTitle
	end
	local title = Config.GetTitle(factionId, honor, infamy)
	return title
end

----------------------------------------------------------------- Size Justice ("덩치 저울")
Config.Justice = {
	RecalcInterval = 30, -- seconds; also recomputed (deferred) on join / leave / faction change / rebirth
	MinScale = 1.0,
	MaxScale = 1.6,
	SignOnGold = 300, -- banked gold for picking the weaker faction on the FIRST faction choice only
	MaxVisualScale = 3.0, -- cap of the combined visual scale (S x bully x kaiju)
	ScaleRatePerSec = 0.6, -- character scale moves toward its target at this many scale units per second
	ScaleTick = 0.1,
}

-- "base power" of a player (no Size Justice, no kaiju); rebirthMult = 1 + RebirthBonus
function Config.PowerOf(level, weaponTier, rebirthMult)
	return math.sqrt(Config.WeaponDamage(weaponTier, level) * Config.BaseHealth(level)) * (rebirthMult or 1)
end

-- S for a faction: weaker side = clamp(sqrt(enemy / ours), 1.0, 1.6); the stronger side naturally clamps to 1.0
function Config.SizeJustice(ourSum, enemySum)
	if ourSum <= 0 or enemySum <= 0 then return 1 end
	return math.clamp(math.sqrt(enemySum / ourSum), Config.Justice.MinScale, Config.Justice.MaxScale)
end

Config.Bully = {
	WeakPowerRatio = 0.5, -- (a) victim base power < 50% of the attacker's
	BaitWindow = 10, -- (a) does not apply if the victim damaged the attacker within the last 10 s
	WantedIgnoresWeakRule = true, -- (a) does not apply if the victim had Wanted stars or bully stacks (lead decision)
	FreshSpawnSeconds = 15, -- (b) victim respawned less than 15 s ago
	RepeatKOs = 3, -- (c) 3rd+ KO of the same victim by the same attacker...
	RepeatWindow = 600, -- ...within 10 minutes
	MaxStacks = 3,
	PerStack = 0.15, -- each stack: -15% visual size and -15% damage (multiplies with S)
	DecaySeconds = 300, -- one stack decays per 5 min without a new bully KO
	BountyMult = 2, -- bounty for KOing a bully is doubled
}

function Config.BullyMult(stacks)
	return math.max(0, 1 - Config.Bully.PerStack * (stacks or 0))
end

Config.Revenge = {
	Bonus = 0.25, -- after being KO'd by a player: +25% damage to that killer...
	Duration = 90, -- ...for 90 s (plus a screen-edge arrow to them)
}

Config.Switch = {
	AltarRange = 20,
	Cooldown = 600, -- minimum seconds between two ALTAR faction changes (everyone, free or ticket)
}

----------------------------------------------------------------- PvP
Config.PvP = {
	RookieLevel = 15, -- rookie if Rebirths == 0 and (Level < 15 or PlaytimeSeconds < 3600)
	RookiePlaytime = 3600,
	SpawnProtection = 10, -- seconds; broken early when the protected player damages a player
	HitPctOfMaxHP = 0.10, -- normal per-target PvP hit = victim BASE MaxHealth * 0.10 * powerRatio * ... (§4.9)
	PowerRatioMin = 0.8,
	PowerRatioMax = 1.5,
	CombatTagTime = 15, -- PvP damage within this window credits the KO and blocks travel/switch/class change
	PlunderRate = 0.20, -- Horns KO Halo: take 20% of (carried - safe floor) into the grudge sack
	PlunderCapPerLevel = 100, -- max stolen per KO = victim level * 100
	SafeFloorPerLevel = 10, -- never-stealable carried gold = victim level * 10
	BountyPerLevelStar = 15, -- bounty = 15 * level * stars (minted)
	VillainLossOnBountyKO = 0.25, -- Wanted Horns KO'd by Halo lose 25% of remaining carried gold
	VillainLossOnWantedPvEDeath = 0.25, -- Wanted Horns dying without a PvP killer
	MaxStars = 5,
	StarDecaySeconds = 120,
	StarDamageBonus = 0.05,
	StarGoldBonus = 0.10, -- monster gold bonus per star
	GlowStars = 3, -- red Highlight at >= 3
	NoTravelStars = 3, -- cannot use Travel at >= 3
	AnnounceStars = 5,
	PairRewardCooldown = 300, -- minted rewards (bounty, honor, infamy, war points) once per killer/victim pair per 300 s
	HonorPerKOMin = 1, -- Halo KO of a 0-star, non-bully Horns gives 1 Honor
	CombatLogPenalty = 0.25, -- leaving while combat-tagged loses 25% of carried gold
	BoardRefresh = 5,
}

-- bounty on a player: stars (Horns) or bully stacks (anyone), doubled while the player is a bully
function Config.Bounty(level, stars, bullyStacks)
	bullyStacks = bullyStacks or 0
	local units = math.max(stars or 0, bullyStacks)
	local b = Config.PvP.BountyPerLevelStar * level * units
	if bullyStacks > 0 then b *= Config.Bully.BountyMult end
	return b
end

----------------------------------------------------------------- grudge sack ("원한 돈자루")
Config.Grudge = {
	SackSeconds = 45, -- countdown; ticks ONLY while the thief is in a PvP zone; each new steal resets it to 45
	AvengeRefundRate = 1.2, -- a Halo player KOs the thief in time: each victim gets 120% (to the bank)...
	RefundBonusCooldown = 600, -- ...the extra 20% only if this victim/thief pair had no refund in the last 10 min
	ReturnRate = 1.0, -- thief died without a Halo killer, or left the server: victims get 100% back
	RestealWindow = 180, -- the same thief stealing from the same victim again within 3 min steals 0
	AvengerBonus = 100, -- "복수 대행" bonus (minted, to the bank) for the Halo player who KO'd the thief
	Tick = 0.25,
}

----------------------------------------------------------------- wanted kaiju ("수배범 괴수화")
Config.Kaiju = {
	StarsNeeded = 5,
	SirenSeconds = 10, -- server-wide siren banner before the transformation
	Duration = 120,
	VisualScale = 3, -- combined visual scale is capped at Config.Justice.MaxVisualScale
	HPMult = 20, -- MaxHealth = base MaxHealth x S x 20 x (1 + 0.15 x Halo players within 80 studs)
	HPPerNearbyHalo = 0.15,
	NearbyRadius = 80,
	HPRecalc = 5, -- seconds; preserves HP %
	StompInterval = 4,
	StompRadius = 15,
	StompPct = 0.06, -- of each stomped Halo player's MaxHealth (never rookies, never Protected, never in towns)
	BountyPoolMult = 3, -- reward pool = 3 x current bounty + the kaiju's carried gold
	DamageShare = 0.5, -- 50% of the pool split by damage share, the rest split equally among participants
	SurviveBankMult = 1.5, -- survived: carried gold x1.5 moved to the bank
	ShieldSeconds = 10, -- spawn-protection-style shield after the event
	HaloWarPoints = 150, -- war points to Halo's pool when the kaiju is KO'd
	HornsWarPoints = 150, -- war points to Horns' pool when the kaiju survives
	Tick = 0.25,
}

----------------------------------------------------------------- war meter ("왕관 쟁탈전")
Config.War = {
	RoundSeconds = 600,
	MonsterPoints = 1, -- carried in MonsterKilled info.WarPoints
	GoldenPoints = 5,
	PvPKOPoints = 20,
	PvPKOPerStar = 5,
	SiegeTarget = 150, -- per-capita points needed when only one faction is online
	ChestMinPoints = 30, -- personal points needed for a chest
	WinnerChestPerLevel = 100,
	LoserChestPerLevel = 30,
	BlessingGold = 0.25,
	BlessingXP = 0.25,
	Tick = 1,
}

Config.Sky = {
	TweenTime = 3,
	Neutral = { ClockTime = 14, Brightness = 2, Ambient = Color3.fromRGB(110, 110, 120), OutdoorAmbient = Color3.fromRGB(130, 130, 140), FogColor = Color3.fromRGB(190, 205, 225), FogEnd = 1400, Tint = Color3.fromRGB(255, 255, 255) },
	Dawn = { ClockTime = 7.2, Brightness = 3, Ambient = Color3.fromRGB(150, 130, 80), OutdoorAmbient = Color3.fromRGB(205, 175, 105), FogColor = Color3.fromRGB(255, 220, 150), FogEnd = 1400, Tint = Color3.fromRGB(255, 240, 200) },
	Eclipse = { ClockTime = 0.5, Brightness = 1.2, Ambient = Color3.fromRGB(115, 45, 45), OutdoorAmbient = Color3.fromRGB(125, 45, 45), FogColor = Color3.fromRGB(90, 10, 20), FogEnd = 1100, Tint = Color3.fromRGB(255, 185, 185) },
}

----------------------------------------------------------------- golden goose tug ("황금 거위 줄다리기")
Config.Goose = {
	Interval = 600, -- one goose every 10 min...
	OffsetFromWarEnd = 300, -- ...starting 5 min before each war round end (something happens every 5 min)
	Duration = 60,
	Position = Vector3.new(-30, 0, 30), -- Crossroads plaza (safe zone); MapBuilder builds the perch here
	HoverHeight = 4, -- goose body center = Position + (0, HoverHeight, 0)
	HitRadius = 4, -- added to a class's Range when checking whether a swing reaches the goose
	ManualCount = 2,
	AutoCount = 1,
	MaxCountsPerSecond = 3, -- per player (rolling 1 s window); each count is multiplied by the player's faction S
	RewardMinutes = 10, -- winner reward ~ 10 min of hunting at the player's level (Config.HuntValue)
	MainShare = 1.0, -- Halo winners: XP x Main, gold x Off; Horns winners: gold x Main, XP x Off
	OffShare = 0.3,
	LoserShare = 0.4, -- losers (and both sides on a tie) get 40% + 1 cheer star
	CheerStarsForRare = 5, -- 5 cheer stars -> the next golden reward is guaranteed RARE (stars consumed)
	RareMult = 5,
	WinWarPoints = 60,
	Tick = 0.25,
}

-- gold, xp of one golden-goose reward
function Config.GooseReward(level, factionId, won, rare)
	local g, x = Config.HuntValue(level, Config.Goose.RewardMinutes)
	local gm, xm = Config.Goose.MainShare, Config.Goose.OffShare -- Horns shape (gold-heavy)
	if factionId == "Halo" then gm, xm = Config.Goose.OffShare, Config.Goose.MainShare end -- XP-heavy
	local m = (won and 1 or Config.Goose.LoserShare) * (rare and Config.Goose.RareMult or 1)
	return math.floor(g * gm * m), math.floor(x * xm * m)
end

> **대체됨 (SPEC_ADDENDUM A23-18, 2026-10-05):** 단골 운(서버에 있던 분 수, `RegularMinutes`)은 **오늘의 운**으로 바뀌었다. `Config.Luck = { BaseRare = 0.05, PerEvent = 0.02, MaxRare = 0.125 }`, 저장 `data.LuckDay`/`LuckEvents`(한국 자정 `Config.DayIndex` 기준), `PlayerService.AddLuckEvent`/`GetLuckEvents`. 아래 `PerActiveMinute`/`MinuteSeconds`/`GetRegularMinutes`/`RegularMinutes` 계약은 역사 기록이다.

Config.Luck = { -- "단골 운" (superseded by A23-18 오늘의 운)
	BaseRare = 0.05,
	PerActiveMinute = 0.0025, -- +0.25 percentage points per active minute on THIS server
	MaxRare = 0.125,
	MinuteSeconds = 60, -- a minute counts if the player had input/combat within it
}

function Config.RareChance(activeMinutes)
	return math.min(Config.Luck.MaxRare, Config.Luck.BaseRare + Config.Luck.PerActiveMinute * (activeMinutes or 0))
end

Config.Economy = {
	KillsPerMinute = 12, -- reference hunting speed used for event / daily / vacation rewards
}

-- gold, xp of `minutes` of hunting the main monster of the player's level zone (before multipliers)
function Config.HuntValue(level, minutes)
	local zone = Config.QuestZoneForLevel(level)
	local def = Config.MonsterTypes[Config.ZoneMainMonster[zone]]
	local kills = Config.Economy.KillsPerMinute * minutes
	return math.floor(kills * def.Gold), math.floor(kills * def.XP)
end

----------------------------------------------------------------- rebirth ("전향 환생")
Config.Rebirth = {
	BaseLevel = 50,
	PerRebirth = 5,
	MaxLevelReq = 100,
	BonusNormal = 0.25, -- permanent gold & XP bonus added to RebirthBonus per rebirth
	BonusUnderdog = 0.40, -- if the chosen faction has < UnderdogShare of the OTHER faction players
	UnderdogShare = 0.45,
	UnderdogMinOthers = 2, -- the ratio only counts with at least 2 other faction players online
	MarkMax = 5,
	FallGoldPer = 0.05, -- per "타락" mark (Halo -> Horns at rebirth)
	RedeemXPPer = 0.05, -- per "구원" mark (Horns -> Halo at rebirth)
	GrayLegendMin = 3, -- both marks >= 3 -> title "회색 전설" + gray aura
	-- aura by rebirth count (highest matching entry wins); Color nil = faction color
	Auras = {
		{ Min = 1, Color = Color3.fromRGB(205, 127, 50) },
		{ Min = 3, Color = Color3.fromRGB(200, 200, 215) },
		{ Min = 5, Color = Color3.fromRGB(255, 205, 60) },
		{ Min = 10, Color = nil },
	},
}

function Config.RebirthLevel(rebirths)
	return math.min(Config.Rebirth.MaxLevelReq, Config.Rebirth.BaseLevel + Config.Rebirth.PerRebirth * rebirths)
end

-- bonus for rebirthing into a faction that has targetCountOthers of othersTotal OTHER faction players (self excluded)
function Config.RebirthBonusFor(targetCountOthers, othersTotal)
	if othersTotal >= Config.Rebirth.UnderdogMinOthers and targetCountOthers / othersTotal < Config.Rebirth.UnderdogShare then
		return Config.Rebirth.BonusUnderdog
	end
	return Config.Rebirth.BonusNormal
end

----------------------------------------------------------------- zones & map
-- Ground top surface is Y = 0 everywhere. Size.Y is unused (0). Zones are XZ rectangles; first match in ZoneOrder wins.
Config.ZoneOrder = { "Crossroads", "HaloTown", "HornsTown", "SlimeMeadow", "GoblinWoods", "SkeletonRuins" }
Config.Zones = {
	Crossroads = { Id = "Crossroads", Name = "교차로 마을", Center = Vector3.new(0, 0, 0), Size = Vector3.new(160, 0, 160),
		MinLevel = 1, PvP = false, Town = true, Faction = nil,
		FloorColor = Color3.fromRGB(205, 195, 170), FloorMaterial = Enum.Material.Cobblestone, Spawn = Vector3.new(0, 0, -25) },
	HaloTown = { Id = "HaloTown", Name = "빛의 성채", Center = Vector3.new(0, 0, -160), Size = Vector3.new(160, 0, 160),
		MinLevel = 1, PvP = false, Town = true, Faction = "Halo",
		FloorColor = Color3.fromRGB(245, 238, 210), FloorMaterial = Enum.Material.Marble, Spawn = Vector3.new(0, 0, -170) },
	HornsTown = { Id = "HornsTown", Name = "뿔 소굴", Center = Vector3.new(0, 0, 160), Size = Vector3.new(160, 0, 160),
		MinLevel = 1, PvP = false, Town = true, Faction = "Horns",
		FloorColor = Color3.fromRGB(70, 40, 45), FloorMaterial = Enum.Material.Slate, Spawn = Vector3.new(0, 0, 170) },
	SlimeMeadow = { Id = "SlimeMeadow", Name = "말랑 초원", Center = Vector3.new(210, 0, 0), Size = Vector3.new(260, 0, 260),
		MinLevel = 1, PvP = false, Town = false, Faction = nil,
		FloorColor = Color3.fromRGB(115, 195, 95), FloorMaterial = Enum.Material.Grass, Spawn = Vector3.new(100, 0, 0) },
	GoblinWoods = { Id = "GoblinWoods", Name = "고블린 숲", Center = Vector3.new(490, 0, 0), Size = Vector3.new(300, 0, 300),
		MinLevel = 10, PvP = true, Town = false, Faction = nil,
		FloorColor = Color3.fromRGB(60, 125, 55), FloorMaterial = Enum.Material.Grass, Spawn = Vector3.new(360, 0, 0) },
	SkeletonRuins = { Id = "SkeletonRuins", Name = "해골 유적", Center = Vector3.new(800, 0, 0), Size = Vector3.new(320, 0, 320),
		MinLevel = 25, PvP = true, Town = false, Faction = nil,
		FloorColor = Color3.fromRGB(150, 140, 120), FloorMaterial = Enum.Material.Slate, Spawn = Vector3.new(660, 0, 0) },
	Outskirts = { Id = "Outskirts", Name = "바깥 들판", Center = Vector3.new(440, 0, 0), Size = Vector3.new(1080, 0, 520),
		MinLevel = 1, PvP = false, Town = false, Faction = nil,
		FloorColor = Color3.fromRGB(130, 165, 100), FloorMaterial = Enum.Material.Grass, Spawn = Vector3.new(0, 0, -25) },
}

function Config.ZoneAt(pos)
	for _, id in Config.ZoneOrder do
		local z = Config.Zones[id]
		if math.abs(pos.X - z.Center.X) <= z.Size.X / 2 and math.abs(pos.Z - z.Center.Z) <= z.Size.Z / 2 then
			return z
		end
	end
	return Config.Zones.Outskirts
end

function Config.HomeZoneId(factionId)
	if factionId == "Halo" then return "HaloTown" end
	if factionId == "Horns" then return "HornsTown" end
	return "Crossroads"
end

Config.Map = {
	Bounds = { MinX = -100, MaxX = 980, MinZ = -260, MaxZ = 260 }, -- Outskirts ground + invisible walls
	WallHeight = 80,
	FountainPosition = Vector3.new(0, 0, 0),
	AltarPosition = Vector3.new(0, 0, 45), -- "운명의 제단": Part named "Altar" + ProximityPrompt "AltarPrompt"
	BoardPosition = Vector3.new(-55, 0, 0), -- "현상수배 게시판": faces +X
	PadSize = Vector3.new(10, 1, 10),
	Pads = { -- inside Crossroads; touching = instant Travel
		{ Dest = "SlimeMeadow", Position = Vector3.new(60, 0, -30) },
		{ Dest = "GoblinWoods", Position = Vector3.new(60, 0, 0) },
		{ Dest = "SkeletonRuins", Position = Vector3.new(60, 0, 30) },
	},
	Gates = { -- decorative arches with a level sign, centered on zone borders
		{ Zone = "SlimeMeadow", Position = Vector3.new(80, 0, 0) },
		{ Zone = "GoblinWoods", Position = Vector3.new(340, 0, 0) },
		{ Zone = "SkeletonRuins", Position = Vector3.new(640, 0, 0) },
		{ Zone = "HaloTown", Position = Vector3.new(0, 0, -80) },
		{ Zone = "HornsTown", Position = Vector3.new(0, 0, 80) },
	},
	MaxParts = 450, -- total map parts budget (decor included)
}

Config.Travel = {
	ChannelSeconds = 3,
	PadDebounce = 2,
	ZoneTick = 0.5, -- ZoneService polling interval
	Destinations = {
		{ Id = "Home", Name = "우리 진영 마을" }, -- resolves to Config.HomeZoneId(faction)
		{ Id = "Crossroads", Name = "교차로 마을" },
		{ Id = "SlimeMeadow", Name = "말랑 초원" },
		{ Id = "GoblinWoods", Name = "고블린 숲" },
		{ Id = "SkeletonRuins", Name = "해골 유적" },
	},
}

----------------------------------------------------------------- monsters
Config.Monsters = {
	AIInterval = 0.25,
	AggroRadius = 30,
	LeashRadius = 60, -- from the monster's home point
	AttackRange = 5.5,
	AttackCooldown = 1.5,
	RespawnDelay = 4,
	ContributorWindow = 15, -- every player who damaged it within 15 s gets full rewards
	SpawnInset = 25, -- spawn points are at least 25 studs inside the zone edge
	GoldenChance = 0.04,
	GoldenHPMult = 3,
	GoldenGoldMult = 10,
	GoldenXPMult = 3,
	GoldenColor = Color3.fromRGB(255, 200, 30),
}

Config.MonsterTypeOrder = { "Slime", "BigSlime", "Goblin", "GoblinBrute", "Skeleton", "SkeletonKnight" }
Config.MonsterTypes = {
	Slime = { Name = "조각먹은 슬라임", Zone = "SlimeMeadow", Count = 12, HP = 10, Damage = 2, XP = 5, Gold = 3, Speed = 10, Shape = "Slime", Scale = 1.0, Color = Color3.fromRGB(95, 205, 95) },
	BigSlime = { Name = "왕 슬라임", Zone = "SlimeMeadow", Count = 4, HP = 40, Damage = 4, XP = 18, Gold = 10, Speed = 9, Shape = "Slime", Scale = 1.8, Color = Color3.fromRGB(70, 160, 235) },
	Goblin = { Name = "조각 도둑 고블린", Zone = "GoblinWoods", Count = 10, HP = 90, Damage = 6, XP = 28, Gold = 16, Speed = 12, Shape = "Humanoid", Scale = 1.0, Color = Color3.fromRGB(110, 170, 70) },
	GoblinBrute = { Name = "고블린 우두머리", Zone = "GoblinWoods", Count = 4, HP = 260, Damage = 12, XP = 70, Gold = 40, Speed = 10, Shape = "Humanoid", Scale = 1.5, Color = Color3.fromRGB(80, 120, 50) },
	Skeleton = { Name = "옛 왕국 해골 병사", Zone = "SkeletonRuins", Count = 8, HP = 450, Damage = 14, XP = 65, Gold = 65, Speed = 12, Shape = "Humanoid", Scale = 1.0, Color = Color3.fromRGB(235, 235, 220) },
	SkeletonKnight = { Name = "왕관을 지키던 해골 기사", Zone = "SkeletonRuins", Count = 4, HP = 1300, Damage = 24, XP = 170, Gold = 170, Speed = 11, Shape = "Humanoid", Scale = 1.5, Color = Color3.fromRGB(120, 120, 140) },
}

-- the "unit" monster used for quest targets / rewards and Config.HuntValue
Config.ZoneMainMonster = { SlimeMeadow = "Slime", GoblinWoods = "Goblin", SkeletonRuins = "Skeleton" }

function Config.QuestZoneForLevel(level)
	if level >= Config.Zones.SkeletonRuins.MinLevel then return "SkeletonRuins" end
	if level >= Config.Zones.GoblinWoods.MinLevel then return "GoblinWoods" end
	return "SlimeMeadow"
end

----------------------------------------------------------------- quests (3 slots: dailies first, then rolling extras)
Config.Quests = {
	Slots = 3,
	RerollCooldown = 60,
	EndowedMin = 0.10, -- new quests with Target >= 5 start 10-20% done
	EndowedMax = 0.20,
	MaxPvPQuests = 1,
	PvPMinLevel = 15,
	ExtraRewardMult = 0.5, -- extras pay floor(units * mainMonster.Gold|XP * RewardPerUnit * ExtraRewardMult)
	-- Units = extra-quest sizes, DailyUnits = daily sizes (~5 min of play). For Id "Gold": Target = units * mainMonster.Gold.
	-- Every DAILY pays Config.DailyQuestReward(level at generation) regardless of template.
	Templates = {
		{ Id = "Kill", Weight = 40, Units = { 25, 40 }, DailyUnits = { 50, 60 }, RewardPerUnit = 1.0,
			Text = "몬스터 %d마리 쓰러뜨려 조각 모으기" },
		{ Id = "Golden", Weight = 10, Units = { 1 }, DailyUnits = { 1 }, RewardPerUnit = 30,
			Text = "황금 몬스터 %d마리 처치" },
		{ Id = "Gold", Weight = 20, Units = { 40, 60 }, DailyUnits = { 50, 60 }, RewardPerUnit = 0.5,
			Text = "사냥으로 골드 %s 벌기" },
		{ Id = "Release", Weight = 20, Units = { 2, 3 }, DailyUnits = { 3 }, RewardPerUnit = 8, MinStacks = 50,
			Text = "게이지 50 이상으로 %d번 발사하기" },
		{ Id = "Goose", Weight = 10, Units = { 1 }, DailyUnits = { 1 }, RewardPerUnit = 20,
			Text = "황금 거위 줄다리기 %d번 참여" },
		{ Id = "Hunt", Weight = 12, Units = { 1, 2 }, DailyUnits = { 1 }, RewardPerUnit = 40, Faction = "Halo", PvP = true,
			Text = "현상수배범 %d명 잡기 (괴수 토벌 포함)" },
		{ Id = "Plunder", Weight = 12, Units = { 1, 2 }, DailyUnits = { 1 }, RewardPerUnit = 40, Faction = "Horns", PvP = true,
			Text = "빛의 기사단 %d명 털기" },
	},
}

Config.Daily = {
	TimezoneOffset = 9 * 3600, -- KST: the day flips at 00:00 Korea time
	QuestMinutes = 5, -- each daily pays HuntValue(level, 5)
	ChestMinutes = 10, -- claiming all 3 dailies pays a bonus chest of HuntValue(level, 10)
	ChestTicketChance = 0.10, -- the chest also drops 1 class change ticket with this chance
	VacationRate = 0.7, -- per missed whole day: 70% of a full day (3 dailies + chest) at the CURRENT level
	VacationMaxDays = 3,
	CheckInterval = 30, -- seconds between day-rollover checks for online players
}

function Config.DayIndex(unixTime)
	return math.floor((unixTime + Config.Daily.TimezoneOffset) / 86400)
end

function Config.DailyQuestReward(level) -- gold, xp
	return Config.HuntValue(level, Config.Daily.QuestMinutes)
end

function Config.DailyChestReward(level) -- gold, xp
	return Config.HuntValue(level, Config.Daily.ChestMinutes)
end

function Config.VacationReward(level, days) -- gold, xp for `days` missed days (clamped)
	local d = math.clamp(days or 0, 0, Config.Daily.VacationMaxDays)
	local g, x = Config.HuntValue(level, Config.Daily.QuestMinutes * Config.Quests.Slots + Config.Daily.ChestMinutes)
	return math.floor(g * Config.Daily.VacationRate * d), math.floor(x * Config.Daily.VacationRate * d)
end

----------------------------------------------------------------- Robux change tickets ("변경권")
-- Id 0 = Developer Product not created yet -> buy buttons show "상품 준비 중". After publishing, create two
-- consumable Developer Products on create.roblox.com and paste their ids here.
Config.Products = {
	ClassTicket = { Id = 0, PriceHint = 49, Kind = "Class", Name = "직업 변경권" },
	FactionTicket = { Id = 0, PriceHint = 79, Kind = "Faction", Name = "진영 변경권" },
}
Config.Tickets = {
	MaxReceiptsKept = 50,
	ReceiptWaitSeconds = 15, -- ProcessReceipt waits this long for the buyer's data to load
}

function Config.ProductByKind(kind)
	for _, p in Config.Products do
		if p.Kind == kind then return p end
	end
	return nil
end

----------------------------------------------------------------- visuals
Config.Visuals = {
	MarkScalePerRank = 0.15, -- halo/horn scale = 1 + 0.15 * (rank - 1)
	SackThresholdsPerLevel = { 10, 40, 120, 300, 800 }, -- sack tier = count of thresholds t with gold >= t * level
	SackSizes = { 0.8, 1.2, 1.6, 2.1, 2.8 }, -- ball diameter per tier (tier 0 = no sack)
	NametagMaxDistance = 120,
	MaxDamagePopups = 25,
	FxCullDistance = 150,
	GrudgeSackColor = Color3.fromRGB(110, 40, 150),
	GhostColor = Color3.fromRGB(170, 210, 255),
	GhostTransparency = 0.6,
	GhostHeight = 4, -- studs above the head (x character scale)
	CapeColor = Color3.fromRGB(20, 20, 25),
	CrackedHaloColor = Color3.fromRGB(200, 200, 200),
	GrayAuraColor = Color3.fromRGB(160, 160, 170),
	BullyColor = Color3.fromRGB(255, 50, 50),
	KaijuFireColor = Color3.fromRGB(255, 90, 30),
	ShakeOwnRelease = 0.6, -- camera shake magnitude (studs) for your own release / stomp hit
	ShakeNearRelease = 0.25, -- other players' releases within ShakeNearDistance
	ShakeNearDistance = 40,
	HugeNumberScale = 2.5, -- release total damage number scale
}

function Config.SackTier(gold, level)
	local tier = 0
	for _, t in Config.Visuals.SackThresholdsPerLevel do
		if gold >= t * math.max(1, level) then tier += 1 end
	end
	return tier
end

----------------------------------------------------------------- remotes / misc
-- minimum seconds between two accepted calls of the same remote from the same player (Util.RateLimit)
Config.RateLimits = {
	ChooseFaction = 1, ChooseClass = 1, Swing = 0.1, Release = 0.25, SetAutoAttack = 0.25,
	UpgradeWeapon = 0.3, Rebirth = 1, SwitchFaction = 1, ChangeClass = 1, Travel = 0.5,
	RerollQuest = 0.5, ClaimQuest = 0.3, ClaimVacation = 1,
}

Config.Sounds = { -- optional built-in files; client must pcall and ignore failures
	Swing = "rbxasset://sounds/swordslash.wav",
	Release = "rbxasset://sounds/swordlunge.wav",
	Coin = "rbxasset://sounds/electronicpingshort.wav",
	Click = "rbxasset://sounds/button.wav",
}

Config.Combo = { ResetSeconds = 4, Milestones = { { 10, "좋아요! x10" }, { 25, "멋져요! x25" }, { 50, "폭주! x50" }, { 100, "전설! x100" } } }

----------------------------------------------------------------- story ("세계관": flavor text only)
Config.Story = {
	-- plain lines (no format specifiers)
	Premise = {
		"세상을 지키던 균형의 왕관이 부서졌다.",
		"조각을 주운 자들 중 누구는 머리 위에 후광이, 누구는 뿔이 돋았다.",
		"조각을 더 많이 모으는 쪽이 세상을 다시 만든다.",
	},
	Intro = { -- one-time toasts right after the first class choice (auto-dismiss, never blocking)
		"몬스터를 때리면 왕관 조각의 힘이 모여요! (공격 버튼)",
		"발사 게이지가 꽉 차서 금빛 고리가 빛나면 바로 [발사]!",
		"10분마다 왕관의 주인이 바뀌어요. 우리 편을 도와주세요!",
	},
	FactionLore = {
		Halo = "왕관 조각이 후광이 된 자들. 조각을 지키고 세상을 고친다.",
		Horns = "왕관 조각이 뿔이 된 자들. 조각을 빼앗아 세상을 차지한다.",
	},
	MarkLore = "후광과 뿔은 왕관 조각의 힘이에요. 계급이 오를수록 커져요.",
	ZoneLore = {
		Crossroads = "부서진 왕관이 떨어진 곳",
		HaloTown = "후광을 얻은 자들의 성",
		HornsTown = "뿔이 돋은 자들의 굴",
		SlimeMeadow = "조각 가루를 먹은 슬라임 들판",
		GoblinWoods = "조각 도둑들의 숲",
		SkeletonRuins = "옛 왕국의 무덤",
	},
	-- format strings (always through string.format)
	WarWin = {
		Halo = "이번 판 왕관은 빛의 기사단이 차지했다! 하늘이 왕관의 금빛으로 물들어요. (10분간 골드·경험치 +25%%)",
		Horns = "이번 판 왕관은 뿔 군단이 차지했다! 하늘이 왕관의 핏빛으로 물들어요. (10분간 골드·경험치 +25%%)",
	},
	WarDraw = "이번 판 왕관은 아무도 차지하지 못했어요!",
	GooseStart = "왕관 조각을 품은 황금 거위가 교차로 마을에 내려왔어요! 기사단은 구조, 뿔 군단은 밀렵!",
	GooseResult = {
		Halo = "기사단이 황금 거위를 구조했어요! 조각이 빛을 되찾았어요.",
		Horns = "뿔 군단이 황금 거위를 밀렵했어요! 조각이 어둠에 물들었어요.",
		Tie = "황금 거위가 날아가 버렸어요! 무승부예요.",
	},
	KaijuSiren = "경보! %s이(가) 왕관 조각의 어둠에 삼켜지고 있어요! 10초 뒤 괴수가 돼요!",
	KaijuStart = "괴수 %s 출현! 기사단은 어디서든 공격할 수 있어요!",
	KaijuDefeated = "기사단이 괴수 %s을(를) 쓰러뜨렸어요! 보상 %s골드를 나눠 가져요.",
	KaijuSurvived = "괴수 %s이(가) 끝까지 살아남았어요! 전설의 악당 탄생!",
	SurviveTitle = "전설의 악당",
	GrayLegendTitle = "회색 전설",
	RebirthIntro = "환생하면 왕관 조각을 다시 고를 수 있어요. 어느 편으로 다시 태어날까요?",
	Fall = "타락: 후광이 깨지고 뿔이 돋았다. (골드 +5%% 영구 · 찢어진 검은 망토)",
	Redeem = "구원: 뿔이 부서지고 금 간 후광이 떠올랐다. (경험치 +5%% 영구)",
	SackLore = "빼앗긴 골드에는 원한이 붙어요. 기사단이 도둑을 잡으면 120%%로 돌아와요!",
}

-- Korean message templates (always through string.format). Use these for the listed situations.
Config.Text = {
	LoadFailed = "데이터를 불러오지 못했어요. 잠시 후 다시 접속해 주세요.",
	NeedLevel = "레벨 %d 이상만 들어갈 수 있어요!",
	EnteredPvP = "PvP 지역이에요! 다른 진영을 조심하세요.",
	EnteredSafe = "안전 지대예요.",
	Banked = "골드 %s을(를) 금고에 넣었어요.",
	HaloCourier = "천사 배달부가 골드 %s을(를) 금고에 넣었어요.",
	LevelUp = "레벨 업! Lv %d",
	NotEnoughGold = "골드가 부족해요.",
	WeaponBought = "%s 장착!",
	WeaponMaxed = "이미 최고의 무기예요!",
	WeaponNeedLevel = "이 무기는 레벨 %d부터 쓸 수 있어요.",
	NeedFaction = "먼저 진영을 골라야 해요.",
	AutoLocked = "자동 공격은 레벨 %d부터 쓸 수 있어요.",
	ReleaseNeed = "게이지가 %d 이상이어야 발사할 수 있어요.",
	-- PvP
	Plundered = "%s에게 골드 %s을(를) 빼앗겼어요! 기사단이 45초 안에 도둑을 잡으면 120%%로 돌아와요.",
	PlunderGain = "골드 %s을(를) 원한 자루에 담았어요! PvP 지역에서 45초 버티면 내 것! (현상수배 별 %d개)",
	PlunderTooSoon = "방금 턴 상대예요. 3분 동안은 또 털 수 없어요.",
	HonorGain = "명예 +%d",
	BountyGain = "현상금 %s골드 획득! 명예 +%d",
	BountyAnnounce = "[빛의 기사단] %s님이 현상금 %s골드를 받았어요!",
	BullyBountyGain = "깡패 현상금 %s골드 획득!",
	MostWanted = "%s이(가) 최고 현상수배범이 되었어요! 현상금 %s골드",
	BullyKO = "깡패 처치! 보상 없음, 덩치·공격력 -15%% (깡패 %d단계)",
	BullyVictim = "깡패에게 당했어요. 잃은 건 없어요!",
	BullyDecay = "깡패 단계가 줄었어요 (%d단계)",
	Revenge = "%s에게 복수하세요! 90초 동안 공격력 +25%%",
	RevengeDone = "복수 성공!",
	-- grudge sack
	SackPaid = "원한 자루를 지켜냈어요! 골드 %s 획득",
	SackLost = "원한 자루를 빼앗겼어요!",
	GrudgeRefund = "%s님이 원한 자루를 되찾아 줬어요! 골드 %s이(가) 금고로!",
	GrudgeReturned = "도둑이 쓰러져서 빼앗긴 골드 %s이(가) 금고로 돌아왔어요.",
	AvengerBonus = "복수 대행 보너스 +%s골드!",
	GrudgeAvengedAll = "%s님이 %s의 원한 자루를 되찾았어요!",
	-- travel / blocks
	TravelBlockedStars = "현상수배 별이 3개 이상이면 걸어서 도망쳐야 해요!",
	TravelBlockedCombat = "전투 중에는 할 수 없어요.",
	TravelBlockedSack = "원한 자루를 든 동안은 순간이동할 수 없어요!",
	TravelBlockedKaiju = "괴수는 순간이동할 수 없어요!",
	Traveling = "이동 중...",
	TravelCancelled = "이동이 취소됐어요.",
	BlockedSack = "원한 자루를 든 동안은 할 수 없어요.",
	BlockedKaiju = "괴수 이벤트 중에는 할 수 없어요.",
	BlockedStars = "현상수배 별이 없어야 할 수 있어요.",
	-- faction / class / tickets
	UnderdogSignOn = "약한 편 합류 보너스 +%d골드!",
	SwitchDoneFree = "%s(으)로 진영을 바꿨어요! (배신의 대가: %s 0)",
	SwitchDoneTicket = "%s(으)로 진영을 바꿨어요! (변경권 사용, 점수 유지)",
	SwitchCooldown = "진영 변경은 %s 후에 가능해요.",
	NoTicket = "변경권이 없어요. 메뉴 > 변경권 상점에서 살 수 있어요.",
	ClassChosen = "%s이(가) 되었어요!",
	ClassChangedFree = "%s(으)로 직업을 바꿨어요! 레벨 1부터 다시 시작해요.",
	ClassChangedTicket = "%s(으)로 직업을 바꿨어요! (변경권 사용, 레벨 유지)",
	ClassSame = "이미 그 직업이에요.",
	ClassNeedSafe = "직업은 안전 지대에서만 바꿀 수 있어요.",
	ClassTicketGot = "직업 변경권 1장을 받았어요!",
	FactionTicketGot = "진영 변경권 1장을 받았어요!",
	ProductNotReady = "상품 준비 중이에요.",
	-- rebirth
	RebirthNeed = "환생하려면 레벨 %d이(가) 필요해요.",
	RebirthDone = "환생 완료! 골드·경험치 영구 +%d%%",
	RebirthAnnounce = "%s님이 %d번째 환생을 했어요!",
	-- quests
	QuestDone = "추가 퀘스트 완료! +%s골드",
	DailyReady = "일일 퀘스트 완료! [받기]를 눌러요.",
	DailyClaimed = "일일 보상! +%s골드 +%s 경험치",
	DailyChest = "일일 퀘스트 3개 완료! 보너스 상자 +%s골드 +%s 경험치",
	DailyChestTicket = "보너스 상자에서 직업 변경권이 나왔어요!",
	DailyAutoPaid = "어제 받지 않은 일일 보상을 금고에 넣었어요. (+%s골드)",
	VacationClaimed = "휴가 보너스! +%s골드 +%s 경험치",
	-- war
	WarChest = "전쟁 상자! +%s골드",
	-- goose
	GooseReward = "황금 거위 보상! +%s골드 +%s 경험치",
	GooseCheer = "응원별 +1 (%d/5) — 5개 모이면 다음 황금 보상은 희귀!",
	RareToast = "희귀 보상! ×5",
	RareAnnounce = "%s님이 황금 거위 희귀 보상을 받았어요!",
	-- kaiju
	KaijuQueued = "다른 괴수가 있어요. 그 괴수가 끝나면 변신해요!",
	KaijuReward = "괴수 토벌 보상 +%s골드!",
	KaijuSurviveReward = "살아남았다! 주머니 골드 ×1.5 = %s골드가 금고로!",
}

return Config
```

> 2026-10-09 검수: 아래 밸런스 메모는 충전·발사 기준이라 낡음(A22·A23-1).

**Balance notes (read-only, for reviewers):** Warrior baseline = `WeaponDamage` per 1.0 s swing. Idle (auto swings
+1 stack, auto-release at cap 150 with ×1.5): `0.5 + (0.5 × 150 × 1.5) / 150 = 1.25×` baseline. Auto swings + PERFECT
release: `0.5 + 0.5 × 150 × 4 / 150 = 2.5×`. Manual swings (+2 stacks) + PERFECT reach ≈ 4.5× (decided numbers; tune
`ChargeManual` or `PerStackBonus` if this gap feels too big). Any release ≥ ~30 stacks hits the 35% PvP cap.

---
## 4. Module public APIs

Require paths (the only `require` calls allowed outside the entry scripts):
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Util   = require(ReplicatedStorage.Shared.Util)
local Net    = require(ReplicatedStorage.Shared.Net)
```
Server services are reached only through the registry `S` passed to `Init(S)`; client modules through `C`.
(2026-10-09, exceptions in code: `HUD.luau` requires the pure module `HudLayout`, which is not in ClientMain's ORDER, and
`Intro.luau` requires Roblox's `PlayerModule` for `GetControls()`.)

### 4.1 `Shared/Util.luau` (G1, copy verbatim)

> 2026-10-09 검수: 아래 코드는 10/02 사본이다. 지금 Util은 `src/ReplicatedStorage/Shared/Util.luau`가 정답이고 함수가 더 있다(예: `GlyphSafe`, `ValidateNickname`, `NicknameCanonical`, `PlayerDisplayName`). 베끼지 않는다.

```lua
-- Util.luau : small helpers shared by server and client.
local Players = game:GetService("Players")

local Util = {}

------------------------------------------------------------------ Signal
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

-- returns a connection { Disconnect = function() }
function Signal:Connect(fn)
	local entry = { fn = fn, connected = true }
	table.insert(self._handlers, entry)
	local handlers = self._handlers
	return {
		Disconnect = function()
			entry.connected = false
			local idx = table.find(handlers, entry)
			if idx then table.remove(handlers, idx) end
		end,
	}
end

-- synchronous; each handler runs in pcall so one failure does not stop the others
function Signal:Fire(...)
	for _, entry in table.clone(self._handlers) do
		if entry.connected then
			local ok, err = pcall(entry.fn, ...)
			if not ok then warn("[Signal] handler error: " .. tostring(err)) end
		end
	end
end

Util.Signal = Signal

------------------------------------------------------------------ logging
function Util.Log(tag, msg)
	print("[" .. tostring(tag) .. "] " .. tostring(msg))
end

function Util.Warn(tag, msg)
	warn("[" .. tostring(tag) .. "] " .. tostring(msg))
end

------------------------------------------------------------------ time / random
Util.Random = Random.new()

function Util.Now()
	return workspace:GetServerTimeNow()
end

------------------------------------------------------------------ formatting
local SUFFIXES = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }

function Util.FormatNumber(n)
	n = tonumber(n) or 0
	local sign = n < 0 and "-" or ""
	n = math.abs(n)
	for _, s in SUFFIXES do
		if n >= s[1] then
			local v = n / s[1]
			local str
			if v >= 100 then
				str = tostring(math.floor(v))
			else
				str = string.format("%.1f", math.floor(v * 10) / 10)
				str = string.gsub(str, "%.0$", "")
			end
			return sign .. str .. s[2]
		end
	end
	return sign .. tostring(math.floor(n))
end

function Util.FormatTime(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- 0.1075 -> "10.75", 0.05 -> "5", 0.125 -> "12.5"
function Util.FormatPercent(fraction)
	local v = math.floor((fraction or 0) * 10000 + 0.5) / 100
	return string.format("%g", v)
end

-- final rounding for every damage / heal number
function Util.RoundDamage(x)
	return math.max(1, math.floor((x or 0) + 0.5))
end

------------------------------------------------------------------ rate limit (server)
local lastCall = {} -- [Player] = { [key] = os.clock() }

-- true if this call is allowed (and records it); false if called again within minInterval seconds
function Util.RateLimit(player, key, minInterval)
	local now = os.clock()
	local p = lastCall[player]
	if not p then
		p = {}
		lastCall[player] = p
	end
	local last = p[key]
	if last and now - last < minInterval then return false end
	p[key] = now
	return true
end

function Util.ClearPlayer(player)
	lastCall[player] = nil
end

------------------------------------------------------------------ characters
function Util.GetCharacter(player)
	local c = player and player.Character
	if c and c.Parent then return c end
	return nil
end

function Util.GetHumanoid(player)
	local c = Util.GetCharacter(player)
	if not c then return nil end
	return c:FindFirstChildOfClass("Humanoid")
end

function Util.GetRoot(player)
	local c = Util.GetCharacter(player)
	if not c then return nil end
	return c:FindFirstChild("HumanoidRootPart")
end

function Util.IsAlive(player)
	local h = Util.GetHumanoid(player)
	return h ~= nil and h.Health > 0 and Util.GetRoot(player) ~= nil
end

-- first existing child among names (R15 name first, then R6), or nil
function Util.FindPart(character, ...)
	if not character then return nil end
	for _, name in { ... } do
		local p = character:FindFirstChild(name)
		if p and p:IsA("BasePart") then return p end
	end
	return nil
end

function Util.FlatDistance(a, b)
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

-- Model:ScaleTo wrapped in pcall; ignores invalid scales. Returns true on success.
function Util.SafeScaleTo(model, scale)
	if not model or not model.Parent or type(scale) ~= "number" or scale <= 0 then return false end
	local ok = pcall(model.ScaleTo, model, scale)
	return ok
end

------------------------------------------------------------------ instances
function Util.GetFolder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

-- props: any Part properties plus optional ClassName (default "Part") and Parent (applied last)
function Util.MakePart(props)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "Parent" and k ~= "ClassName" then
			p[k] = v
		end
	end
	if props.Parent then p.Parent = props.Parent end
	return p
end

-- welds part1 to part0 at their CURRENT relative position (WeldConstraint parented to part1)
function Util.Weld(part0, part1)
	local w = Instance.new("WeldConstraint")
	w.Part0 = part0
	w.Part1 = part1
	w.Parent = part1
	return w
end

function Util.RandomPointInZone(zone, inset)
	inset = inset or 0
	local hx = math.max(1, zone.Size.X / 2 - inset)
	local hz = math.max(1, zone.Size.Z / 2 - inset)
	return Vector3.new(
		zone.Center.X + Util.Random:NextNumber(-hx, hx),
		0,
		zone.Center.Z + Util.Random:NextNumber(-hz, hz)
	)
end

function Util.DeepCopy(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in t do out[k] = Util.DeepCopy(v) end
	return out
end

function Util.PlayersExcept(player)
	local out = {}
	for _, p in Players:GetPlayers() do
		if p ~= player then table.insert(out, p) end
	end
	return out
end

return Util
```

### 4.2 `Shared/Net.luau` (G1, copy verbatim)

> 2026-10-09 검수: 아래 코드는 10/02 사본이라 낡음. 지금 `src/ReplicatedStorage/Shared/Net.luau`의 `Net.Names`는 원격 52개다(새로 생긴 것 예: `SellWeapon`·`UseItem`·`EquipWeapon`(A23-4·A23-12), `UseSkill`(SKL-2, A23-49), `IntroSeen`(A23-9), `StoryAction`, `SetSettings`·`Settings`, `RequestRankings`·`Rankings`, `Inventory`, `SetLook`(A23-75), `EquipPet`·`PetList`(PET-2), `ClaimAttendance`(A23-77), `GoToFriend`·`CandyTrade`(A23-79), `FinisherPick`(King Slime 마무리 카드, A23-84), `CardAction`·`Commission`(A23-86)). `Net.Notify`/`NotifyAll`에는 마지막 인자 `sound`(Config.Audio 키, 선택)가 붙었고, `GameStateDefaults`도 늘었다(호박 대왕·유령 왕·필드 보스·랭킹 주·스위치 등).

```lua
-- Net.luau : remote names, creation (server), lookup (both), and send helpers (server).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

Net.Names = {
	-- client -> server
	"ChooseFaction", "ChooseClass", "Swing", "Release", "SetAutoAttack", "UpgradeWeapon",
	"Rebirth", "SwitchFaction", "ChangeClass", "Travel", "RerollQuest", "ClaimQuest", "ClaimVacation",
	-- server -> client
	"Notify", "Fx", "OpenPanel",
	"Quests", -- R1 CR-L50: the owner's quest list (replaces the replicated QuestsJson attribute), fired only on change
}

Net.GameStateDefaults = {
	-- WarService
	WarHaloScore = 0, WarHornsScore = 0, WarRoundEndsAt = 0, WarMode = "Idle", WarBlessing = "None",
	-- FactionService
	HaloCount = 0, HornsCount = 0,
	-- R1 CR-L7: FactionService.GetUnderdogCounts (no rookies, no 120 s idlers) for the rebirth underdog bonus + preview
	UnderdogHalo = 0, UnderdogHorns = 0,
	-- JusticeService
	HaloPower = 0, HornsPower = 0, HaloSize = 1, HornsSize = 1, WeakerFaction = "None",
	-- GooseService
	GooseNextAt = 0, GooseActive = false, GooseEndsAt = 0, GooseRescue = 0, GoosePoach = 0,
	-- KaijuService
	KaijuPhase = "None", KaijuUserId = 0, KaijuName = "", KaijuEndsAt = 0,
}

-- server only; call once, first thing in Main.server.luau
function Net.CreateAll()
	assert(RunService:IsServer(), "Net.CreateAll is server-only")
	local folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in Net.Names do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage

	local gs = ReplicatedStorage:FindFirstChild("GameState") or Instance.new("Folder")
	gs.Name = "GameState"
	for k, v in Net.GameStateDefaults do
		if gs:GetAttribute(k) == nil then gs:SetAttribute(k, v) end
	end
	gs.Parent = ReplicatedStorage
end

function Net.Get(name)
	if RunService:IsServer() then
		local r = ReplicatedStorage.Remotes:FindFirstChild(name)
		assert(r, "Unknown remote: " .. tostring(name))
		return r
	end
	return ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(name)
end

function Net.GameState()
	if RunService:IsServer() then return ReplicatedStorage.GameState end
	return ReplicatedStorage:WaitForChild("GameState")
end

-- server helpers --------------------------------------------------------
-- kind: "info" | "good" | "bad" | "reward" | "announce"
function Net.Notify(player, text, kind, duration)
	Net.Get("Notify"):FireClient(player, { Text = text, Kind = kind or "info", Duration = duration })
end

function Net.NotifyAll(text, kind, duration)
	Net.Get("Notify"):FireAllClients({ Text = text, Kind = kind or "announce", Duration = duration })
end

-- player == nil -> FireAllClients
function Net.Fx(player, kind, data)
	if player then
		Net.Get("Fx"):FireClient(player, kind, data)
	else
		Net.Get("Fx"):FireAllClients(kind, data)
	end
end

return Net
```

### 4.3 Conventions for every server service
- Signatures below are the **complete public surface**. Anything else is private (`local function`).
- "ready" = `S.PlayerService.IsReady(player)`. Every remote handler starts with:
  `if not S.PlayerService.IsReady(player) then return end` → type checks → `Util.RateLimit(player, "<RemoteName>", Config.RateLimits.<RemoteName>)` → domain checks.
  Domain-check failures notify the player with the listed `Config.Text` key (kind `"bad"`) unless marked "silent".
- Persistent stats are written **only** through `S.PlayerService.SetStat / AddStat` (keeps data table and attribute in
  sync). Exceptions (direct data-table mutation, documented per owner): `Quests` (QuestService), `Tickets` and
  `ProcessedReceipts` (MonetizationService), the leave-time gold fold in ProgressionService, DataService migration.
- Gold is changed **only** through ProgressionService functions (`AddCarriedGold`, `AddBankGold`, `TakeCarriedGold`,
  `SpendGold`, `BankAll`). Level/XP only through ProgressionService (`AddXP`, `ResetLevel`, rebirth).
- Every loop is `task.spawn(function() while true do task.wait(interval) ... end end)` and must `pcall` its per-player
  body (or guard every index) so a player leaving mid-iteration never kills the loop. On a caught error,
  `Util.Warn("<ServiceName>", err)` (at most once per 10 s per loop, to keep the console readable).
- When iterating players, use `S.PlayerService.GetReadyPlayers()`.
- Helper names used below: `faction(p)` = `S.FactionService.GetFaction(p)`; `cls(p)` = `S.ClassService.GetClassDef(p)`;
  `attr(p, k)` = `p:GetAttribute(k)`; `stars(p)` = `S.PvPService.GetStars(p)`; `kstate(p)` = `S.KaijuService.GetState(p)`.

### 4.4 DataService (G2) — `ServerScriptService/DataService.luau`
```
DataService.Init(S) ; DataService.Start()
DataService.Load(player) -> data | nil        -- yields. nil = failed (caller kicks) or player left during load
DataService.Get(player) -> data | nil         -- the live session table (mutable)
DataService.Save(player, release: boolean) -> boolean   -- yields; safe to call concurrently (autosave + forced save)
DataService.Release(player)                   -- yields; sets LastLogoutTime, Save(player, true), drops cache. Idempotent.
DataService.IsMemoryMode() -> boolean
```
Behavior:
- Store: `DataStoreService:GetDataStore(Config.Data.StoreName)`, key `Config.Data.KeyPrefix .. player.UserId`.
- **Memory mode:** in `Start`, `task.spawn` a probe: if `RunService:IsStudio()`, `pcall` GetDataStore + `GetAsync("__probe")`;
  on failure set memory mode and `warn` once: `"[DataService] DataStore unavailable (enable Studio Access to API Services). Using in-memory data; nothing will be saved."`.
  Outside Studio memory mode is always false. `Load` waits (`task.wait()` loop) until the probe finished.
  In memory mode `Load` returns a fresh `Util.DeepCopy(Config.Data.Defaults)` with `FirstJoinTime = os.time()`; `Save` returns true without I/O.
- **Load with session lock** (up to `LoadRetries` attempts, `LoadRetryDelay` s apart):
  `pcall(store.UpdateAsync, store, key, transform)` where `transform(old)`:
  if `old` is a table with `SessionLock` whose `JobId ~= game.JobId` and `os.time() - SessionLock.Time < Config.Data.LockTimeout`
  and this is not the final attempt → mark "locked", `return nil` (cancels write). Otherwise
  `local d = (type(old) == "table") and old or {}`; `d.SessionLock = { JobId = game.JobId, Time = os.time() }`; capture `d`; `return d`.
  On the final attempt the lock is stolen (dead-server recovery). On success: remove `SessionLock` from the session table,
  run **`migrate(d)`** (below), add every missing key from `Config.Data.Defaults` (deep-copied; for the table default
  `Tickets` also add missing sub-keys `Class`/`Faction` = 0), set `Version = Config.Data.Version`, set `FirstJoinTime = os.time()`
  if 0, cache it, return it. If all attempts error → return nil. If the player left during the load → `Save(player, true)`
  the loaded data and return nil.
- **Migration v1 → v2** (`migrate(d)`, idempotent, also harmless on a brand-new empty table):
  ```lua
  if (d.Version or 1) < 2 then
  	d.WeaponTier = d.WeaponTier or d.SwordTier or 1   -- v1 field SwordTier is renamed
  	d.SwordTier = nil
  	d.RebirthBonus = (d.Rebirths or 0) * Config.Rebirth.BonusNormal
  	d.Class = "Warrior"
  	d.ClassChosen = false          -- migrated players get one free class pick (keeps their level)
  	d.Quests = {}                  -- QuestService regenerates (DailyDay = 0 -> fresh dailies, no vacation)
  	d.Version = 2
  end
  ```
  All other new keys come from the defaults fill. `print("[DataService] migrated v1 -> v2 for " .. player.Name)` once per migration.
  2026-10-09: there is a second step **v2 → v3** (B4 / A23-12: weapon tier 8 and `Items` / `WeaponEnhance` / `LootFlags`;
  older records keep weapon tier 1 owned, A23-34). `Config.Data.Version = 3`; later fields (`Stats`, `Looks`, `Attendance`,
  `Pets`, …) are additive and keep version 3. `LoadRetryDelay` is now 6 s (A23-48 batch). The code in `DataService.luau` is the contract.
- **Save**: deep-copy the session table, set `copy.SessionLock = release and nil or { JobId = game.JobId, Time = os.time() }`,
  `UpdateAsync` with transform: if stored lock exists and its `JobId ~= game.JobId` → abort (`return nil`, warn, return false,
  no retry — another server owns the data). Else `return copy`. Retry `SaveRetries` times with waits 1, 2, 4 s on errors.
- **Autosave**: every `Config.Data.AutosaveInterval` s, `task.spawn(Save, player, false)` for each cached player.
- `BindToClose` is owned by PlayerService (it must fire `PlayerLeaving` first). DataService does not bind it.
- **R1 (A16-3):** writes per UserId go through a FIFO slot queue [CR-M1]; `Load` first waits until an earlier session of the
  same UserId has finished `Release`, and always frees the slot (pcall). `Load` refuses a stored record with
  `Version > Config.Data.Version` (write and lock cancelled, nil → LoadFailed) [CR-L3].

### 4.5 PlayerService (G2) — `ServerScriptService/PlayerService.luau`

> 2026-10-09 검수: 공개 함수가 아래보다 많다(예: `GrantFame`, `SpawnCharacter`, `ReplaceCharacter`, `RestoreOwnerCharacter`, `ComputeWalkSpeed`, `RefreshSpeed`, `GetLastOwnActive`, `GetLuckEvents`·`AddLuckEvent`). 단골 분(`RegularMinutes`)과 그 루프는 없어졌고(A23-18), `MarkActive(player, kind)`는 이제 쉬는 중 판정(`GetLastActive`·`GetLastOwnActive`)에만 쓴다. 실제 계약은 `PlayerService.luau`.

```
Signals (top level):
PlayerService.PlayerReady       : Signal(player, data)              -- data loaded, attributes + leaderstats set
PlayerService.PlayerLeaving     : Signal(player, data)              -- fired once, BEFORE the final save; mutate data here
PlayerService.CharacterSpawned  : Signal(player, character, humanoid) -- after stats applied and character placed
PlayerService.CharacterDied     : Signal(player, character)

PlayerService.Init(S) ; PlayerService.Start()
PlayerService.IsReady(player) -> boolean
PlayerService.GetReadyPlayers() -> { Player }
PlayerService.GetData(player) -> data | nil                -- = S.DataService.Get(player)
PlayerService.SetStat(player, key, value)                  -- data[key] = value; if key in Config.Data.Mirrored then player:SetAttribute(key, value)
PlayerService.AddStat(player, key, delta) -> newValue      -- numeric convenience over SetStat
PlayerService.Respawn(player)                              -- task.spawn(player.LoadCharacter, player) if ready
PlayerService.RefreshCharacter(player, fullHeal: boolean)  -- recompute MaxHealth + WalkSpeed (formula below)
PlayerService.FinalizeLeave(player)                        -- idempotent: if ready -> PlayerLeaving:Fire + DataService.Release; always Util.ClearPlayer; ready = false
PlayerService.MarkActive(player)                           -- "had input/combat now"; 2026-10-09: feeds only the idle checks (GetLastActive), no longer the luck (A23-18)
PlayerService.GetRegularMinutes(player) -> number          -- REMOVED (A23-18): use GetLuckEvents(player) -> number (events joined today, saved)
PlayerService.GetLastActive(player) -> number              -- R1 CR-M20: os.clock() of the last MarkActive, 0 = never
PlayerService.IsShuttingDown() -> boolean                  -- R1 CR-M2: true once BindToClose started
PlayerService.PairReady(holder, otherUserId, kind, cooldown, commit?) -> boolean  -- R1 CR-M4: saved pair cooldown (A16-2)
```
Health/speed formula (used by `RefreshCharacter` and on spawn):
```
maxHP = math.max(1, math.floor(Config.MaxHealth(Level, Faction, Class) * S.JusticeService.GetHealthMult(player)))
humanoid.WalkSpeed = Config.Player.WalkSpeed * cls(player).WalkSpeedMult
```
`RefreshCharacter`: no-op without a humanoid. If `humanoid.Health <= 0` only set MaxHealth (never revive). Else keep the
health ratio (`Health = math.clamp(ratio * maxHP, 1, maxHP)`) unless `fullHeal` (`Health = maxHP`).

Flow:
- `Init`: `Players.CharacterAutoLoads = false`.
- `Start` (runs LAST in the start order): connect `PlayerAdded` → `task.spawn(onJoin)`, `PlayerRemoving` → `FinalizeLeave`;
  run `onJoin` for players already present; `game:BindToClose(function() ... end)` that calls `FinalizeLeave` for every
  player in parallel (`task.spawn`) and waits until all finished or 25 s passed. Start the playtime loop and the
  regular-minutes loop.
  **R1 CR-M2:** before spawning the FinalizeLeave calls, BindToClose fires `PlayerLeaving` synchronously (pcall) for every
  ready, not-finalizing player while all of them are still ready; their FinalizeLeave then only clears ready, Releases and
  cleans up. A load still running at shutdown keeps `joining[player]` until its Release finishes (CR-L2), so BindToClose
  waits for it. PairCD is pruned right before `PlayerReady` (A16-2). The fall-rescue loop was removed (CR-L16, ZoneService
  owns A10), and server teleports call `ZoneService.MarkTeleported` first (A16-1).
- `onJoin(player)`: `data = S.DataService.Load(player)`; if `player.Parent == nil` → return; if `data == nil` →
  `player:Kick(Config.Text.LoadFailed)` and return. Then: mirror every key of `Config.Data.Mirrored` to attributes;
  attribute `RegularMinutes = 0` (→ removed, A23-18 Today's Luck); create `leaderstats` Folder with IntValues ~~**"레벨"** (Level), **"골드"** (BankGold +
  CarriedGold), **"환생"** (Rebirths), **"명성"** (Honor if Faction == "Halo", Infamy if "Horns", else 0)~~ → 2026-10-09:
  `Config.Leaderstats.Columns` = **Power, Level, Rebirths, Fame** (English; Fame = Honor / Infamy / this week's artisan fame;
  gold is no longer listed — BB12, A23-21, A23-24, A23-48), kept in sync via
  `GetAttributeChangedSignal` on the attributes they read. Mark ready,
  `player:SetAttribute("DataLoaded", true)`, `PlayerReady:Fire(player, data)`, connect `CharacterAdded`, then
  `player:LoadCharacter()`.
- `CharacterAdded(character)`: `WaitForChild` Humanoid and HumanoidRootPart (5 s; abort if missing);
  `humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None`; apply the health/speed formula with full heal;
  `character:PivotTo(S.ZoneService.GetSpawnCFrame(Config.HomeZoneId(Faction)))`;
  `humanoid.Died:Once(...)` → `CharacterDied:Fire(player, character)` then `task.delay(Config.Player.RespawnTime, ...)` →
  `player:LoadCharacter()` only if `player.Parent` and `player.Character == character`. Finally `CharacterSpawned:Fire(player, character, humanoid)`.
- Playtime loop: every `Config.Player.PlaytimeTick` s → `AddStat(p, "PlaytimeSeconds", tick)` for ready players.
- Regular minutes (→ replaced by Today's Luck `AddLuckEvent` / `GetLuckEvents`, A23-18; the next lines are history): `MarkActive(p)` stores `lastActive[p] = os.clock()`. Loop every `Config.Luck.MinuteSeconds` s: for each
  ready player with `lastActive[p]` and `os.clock() - lastActive[p] <= Config.Luck.MinuteSeconds` → attribute
  `RegularMinutes += 1`. Cleared on leave (resets when leaving the server). Callers of `MarkActive`: CombatService (every
  accepted `Swing`/`Release` remote, every swing that hits ≥ 1 target incl. the goose, and the victim of any damage).

### 4.6 MapBuilder (G3) — `ServerScriptService/MapBuilder.luau`

> 2026-10-09 검수: 아래 "작은 평평한 맵·장식은 Part로" 부분은 낡음. 진짜 세계는 메인 Studio에 저장된 Terrain 세계(`tools/preview_map.lua`, A8·A10·A11, 지도 v2 A23-53)이고, 소품은 Tripo 3D 키트(A23-47·A23-96), 장식은 플레이어만 막는 충돌 그룹 `DecorPlayerOnly`(A23-81)다. MapBuilder는 그 맵을 그대로 쓰고 기능 부품(패드·제단·게시판·구역 표시 등)만 보장한다(파일 머리말). 큰 3D 장소 글씨는 없앴고(A23-36), 땅은 납작하지 않게 구역마다 시안대로, 한 번에 한 구역씩 꾸민다(A23-76·A23-93·A23-97).

```
MapBuilder.Init(S) ; MapBuilder.Start()      -- Start calls Build() synchronously
MapBuilder.Build()                           -- ENSURE: reuse workspace.Map if present, create only what is missing
MapBuilder.Rebuild()                         -- destroy workspace.Map, then Build() (Studio command bar helper)
MapBuilder.GetAltar() -> BasePart            -- workspace.Map.Landmarks.Altar (child ProximityPrompt "AltarPrompt")
MapBuilder.GetBoardLabel() -> TextLabel      -- workspace.Map.Landmarks.MostWantedBoard.BoardGui.BoardText
```
**Reuse rule (pre-baked maps):** the lead may pre-bake the map in Studio **edit mode** from the command bar with
`require(game.ServerScriptService.MapBuilder).Build()`. Therefore `Build()` must **not use `S`**, must not yield, and is
idempotent: `local map = workspace:FindFirstChild("Map")`; create it only if missing. Then for **every named element
below**, `FindFirstChild(name)` first and build only the missing ones; for existing functional pieces re-apply the
functional bits (Pad attribute `TravelTo`, `Altar.AltarPrompt` existence/properties, `BoardGui.BoardText` existence,
zone floor attribute `ZoneId`). `Decor` is populated only when the `Decor` folder has no children. Always ensure
`workspace.Monsters` and `workspace.Effects` (`Util.GetFolder`). Print one line before the standard start line:
`[MapBuilder] reused workspace.Map (+N missing pieces built)` or `[MapBuilder] built workspace.Map (N parts)`.

Required named output (functional parts are contracts; decoration is free):
- `workspace.Map` Folder with sub-folders `Ground`, `Zones`, `Walls`, `Gates`, `Pads`, `Landmarks`, `Decor`.
- `Ground.OutskirtsGround`: one Part covering `Config.Map.Bounds`, Size.Y = 4, top at Y = 0, Outskirts color/material.
- `Zones.<ZoneId>` per zone in `Config.ZoneOrder`: Size (Size.X, 1, Size.Z), top at Y = 0.05 (center Y = -0.45), zone
  FloorColor/FloorMaterial, attribute `ZoneId`.
- `Walls.Wall_MinX` / `Wall_MaxX` / `Wall_MinZ` / `Wall_MaxZ`: invisible collidable walls (Transparency 1) on the `Bounds`
  edges, height `Config.Map.WallHeight`.
- `Landmarks.Altar`: Part (8×4×8, bottom on ground) at `AltarPosition` with a glowing Neon top, BillboardGui "운명의 제단",
  child `ProximityPrompt` named `AltarPrompt` (ActionText "진영 바꾸기", ObjectText "운명의 제단", HoldDuration 0.5,
  MaxActivationDistance 12, RequiresLineOfSight false).
- `Landmarks.MostWantedBoard`: Part (1×12×20) at `BoardPosition` (+6 Y), SurfaceGui `BoardGui` on `Enum.NormalId.Right`
  (faces +X) containing TextLabel `BoardText` (TextScaled, white on dark, default text "현상수배 게시판").
- `Landmarks.Fountain` at `FountainPosition`.
- `Landmarks.GoosePerch` at `Config.Goose.Position`: round gold platform (Cylinder, 10 diameter, 1 tall, top at Y = 1,
  Marble) with BillboardGui "황금 거위 둥지". The goose itself is spawned by GooseService.
- `Pads.Pad_<Dest>`: one Neon Part per `Config.Map.Pads` entry, Size `PadSize`, top at Y = 0.5, attribute `TravelTo = Dest`,
  BillboardGui text `"→ " .. zone.Name .. " (Lv " .. zone.MinLevel .. "+)"`. `CanTouch = true`, `CanCollide = true`.
- `Gates.Gate_<Zone>`: for each `Config.Map.Gates` entry an arch (two pillars 14 studs apart across the path + lintel,
  grouped in a Model) centered on the border, with a sign: line 1 `zone.Name .. "  Lv " .. MinLevel .. "+  " ..
  (PvP and "PvP 지역" or "안전 지역")`, line 2 `Config.Story.ZoneLore[zoneId]`. Never block walking.
- Decor (free): Halo town white/gold towers with yellow PointLights; Horns town dark spikes with red PointLights; trees in
  SlimeMeadow/GoblinWoods; broken pillars/tombstones in SkeletonRuins; a few cracked "crown shard" Neon wedges around the
  Crossroads fountain. Keep total map parts ≤ `Config.Map.MaxParts`. No decor within 12 studs of any zone `Spawn`, pad,
  altar, board, gate or the goose perch.
- All map parts: `Anchored = true`, `Locked = true`. Built only with Parts/WedgeParts/BillboardGui/SurfaceGui/PointLight.

### 4.7 ZoneService (G3) — `ServerScriptService/ZoneService.luau`
```
ZoneService.ZoneChanged : Signal(player, newZoneId, oldZoneId)

ZoneService.Init(S) ; ZoneService.Start()
ZoneService.GetZoneId(player) -> string             -- cached; "Crossroads" before first tick
ZoneService.GetZone(player) -> zoneConfigTable
ZoneService.IsPvPZone(player) -> boolean
ZoneService.IsTown(player) -> boolean
ZoneService.GetSpawnCFrame(zoneId) -> CFrame         -- zone.Spawn + random XZ offset in [-6, 6] + Vector3.new(0, 4, 0)
ZoneService.ResolveDestination(player, destId) -> zoneId | nil   -- "Home" -> Config.HomeZoneId(faction); others must be a zone id in Config.Travel.Destinations
ZoneService.Travel(player, destId, instant: boolean) -> (ok: boolean, reasonText: string?)
ZoneService.IsPlausible(player, pos: Vector3) -> boolean   -- R1 CR-H2: movement sanity; false only while Config.AntiCheat.Enforce (A16-1)
ZoneService.MarkTeleported(player, seconds: number?)      -- R1 CR-H2: call right before any server teleport (A16-1)
```
- Remote **Travel**(destId): ready → `type(destId) == "string"` → rate limit → `local ok, reason = Travel(player, destId, false)`;
  if not ok and reason then `Net.Notify(player, reason, "bad")`.
- `Travel` checks in order (reason texts are `string.format(Config.Text.X, ...)`): alive; destination resolves;
  `Level >= zone.MinLevel` (else `NeedLevel`); `kstate(player)` is `"Siren"` or `"Active"` → `TravelBlockedKaiju`;
  `S.GrudgeService.HasSack(player)` → `TravelBlockedSack`; `stars(player) >= Config.PvP.NoTravelStars` →
  `TravelBlockedStars`; `S.CombatService.IsInCombat(player)` → `TravelBlockedCombat`; already traveling
  (a channel is running, R1 CR-L18) → return false with no reason. Instant → `character:PivotTo(GetSpawnCFrame(zoneId))`.
  Otherwise **(R1 CR-L18)** store `channels[player] = { Token = {}, Start = os.clock() }`, set attribute
  `TravelingUntil = Util.Now() + ChannelSeconds`, notify `Traveling`, and `task.delay(ChannelSeconds)`: return at once if
  `channels[player]` no longer holds this Token (cancelled, left or a newer channel); otherwise if player still in game,
  alive, `S.CombatService.GetLastDamagedAt(player) < Start`, no sack, not kaiju (Siren/Active) and stars still below the
  limit → pivot; else notify `TravelCancelled`. Always clear the channel and reset `TravelingUntil = 0`. The zone loop
  also cancels a running channel immediately (dead, damaged since Start, in combat, sack, kaiju, too many stars):
  clear it, `TravelingUntil = 0`, notify `TravelCancelled`. Call `S.PlayerService.MarkActive(player)` on every accepted
  Travel remote. Every server teleport here calls `MarkTeleported` first (A16-1).
- Zone loop every `Config.Travel.ZoneTick` (0.2 since R1 CR-H2): for each ready, alive player: `z = Config.ZoneAt(root.Position)`.
  After the A10 fall rescue, the movement check runs (`validateMove`, A16-1: logs only while `Config.AntiCheat.Enforce`
  is false). If `Level < z.MinLevel` → pivot to `GetSpawnCFrame("Crossroads")`, notify `NeedLevel` (once per 3 s max), skip.
  If `z.Id` differs from the cached id → set attributes `ZoneId`, `ZonePvP`, `ZoneTown`; notify `EnteredPvP` ("bad") when
  entering a PvP zone from a non-PvP zone (Neutral players get `EnteredPvPNeutral`, "info", R1 CR-L24) and `EnteredSafe`
  ("good") when entering a non-PvP zone from a PvP zone; `ZoneChanged:Fire(player, new, old)`.
- Pads: in `Start`, for each child of `workspace.Map.Pads` with attribute `TravelTo`, connect `Touched`: resolve player
  from `hit.Parent`; **(R1 CR-H2, always enforced)** ignore the touch unless the player's root is within
  `max(pad.Size.X, pad.Size.Z) / 2 + Config.AntiCheat.PadSlack` (flat) of the pad; debounce per player `PadDebounce` s,
  `Travel(player, dest, true)`; notify the reason on failure.
- Subscriptions: `PlayerReady` → attributes `ZoneId = "Crossroads"`, `ZonePvP = false`, `ZoneTown = true`, `TravelingUntil = 0`.
  `CharacterSpawned` → recompute that player's zone immediately (same code as the loop body).

### 4.8 MonsterService (G5) — `ServerScriptService/MonsterService.luau`

> 2026-10-09 검수: 아래 "Rig construction (no animations, no assets)"와 몬스터 6종은 낡음. 지금 몬스터는 `Config.MonsterTypeOrder`의 17종(슬라임 가족·고블린·해골·핼러윈·유령, A23-30·A23-45·A23-84·A23-87; 새총 고블린·해골 궁수는 `Config.Mobs3Ranged = false`인 동안 나오지 않음)이고, 보이는 모습은 `ServerStorage.CustomModels`의 Tripo 3D 모델(폴더 이름 `Config.CustomModels.FolderName`, A1·A23-47; 모델이 없으면 코드로 만든 모양)이고, 리그가 있는 몬스터는 클라이언트 `MonsterMotion`이 `ReplicatedStorage.MonsterAnims`의 동작을 재생한다(파일 머리말). 세계는 Terrain이라 스폰 점은 땅에 레이캐스트한다(파일 머리말). 필드 보스·호박 대왕·유령 왕은 FieldBossService·HalloweenService가 맡는다.

```
MonsterService.MonsterKilled : Signal(player, info)   -- fired once PER CONTRIBUTOR
  info = { Kind: string, ZoneId: string, Golden: boolean, Position: Vector3,
           XP: number, Gold: number,        -- base values incl. golden multiplier, BEFORE player multipliers
           WarPoints: number,               -- Config.War.MonsterPoints or Config.War.GoldenPoints
           WarShare: number }               -- R1 CR-M18: WarPoints / same-faction contributors of this kill (faction pool share)

MonsterService.Init(S) ; MonsterService.Start()        -- Start spawns Count of every type in Config.MonsterTypeOrder
MonsterService.GetMonstersInRadius(position: Vector3, radius: number, forPlayer: Player?) -> { MonsterRecord }  -- alive only, flat XZ distance
MonsterService.GetNearest(position: Vector3, radius: number, maxCount: number?, forPlayer: Player?) -> { MonsterRecord } -- alive, within radius, sorted nearest first; nil maxCount = all
MonsterService.CountInRadius(position: Vector3, radius: number, forPlayer: Player?) -> number
  -- R1 CR-M5: with forPlayer → that player's personal monsters + zone monsters of the zone the player stands in
MonsterService.DamageMonster(record: MonsterRecord, amount: number, player: Player) -> killed: boolean
  -- R1 CR-M5: false (no HP / contributor change) for a zone monster when `player` stands outside its zone
MonsterService.ApplyKnockback(record: MonsterRecord, fromPosition: Vector3, power: number)
```
`MonsterRecord` (read-only outside this file): `{ Id: number, Kind: string, Def: table, ZoneId: string, Model: Model,
Root: BasePart, Humanoid: Humanoid, HP: number, MaxHP: number, Golden: boolean, Home: Vector3, Alive: boolean }`.

Rig construction (no animations, no assets):
- Model named `Kind`, parent `workspace.Monsters`, `PrimaryPart = HumanoidRootPart`. Attributes `MonsterKind`, `Golden`.
- `Humanoid`: `RigType = Enum.HumanoidRigType.R15` (hover physics via HipHeight), `WalkSpeed = Def.Speed`,
  `DisplayDistanceType = None`, `BreakJointsOnDeath = false`, `MaxHealth = Health = 100` (never changed — **monster HP
  lives in `record.HP`**, the Humanoid is only for movement).
- All parts unanchored, `CanCollide = false`, `CanQuery = true`, every part except the root `Massless = true`, welded to the
  root with `Util.Weld` after positioning. Root is invisible (`Transparency = 1`).
- `s = Def.Scale`. Shape `"Slime"`: root 2s×2s×2s; Ball body diameter 3s at root center; two small black Ball eyes on the
  front (−Z face); `HipHeight = 0.5 * s`. Shape `"Humanoid"` (R6 look): root 2s×2s×1s; Torso 2s×2s×1s at root;
  Head 2s×1s×1s at (0, 1.5s, 0); arms 1s×2s×1s at (±1.5s, 0, 0); legs 1s×2s×1s at (±0.5s, −2s, 0); `HipHeight = 2 * s`.
  Spawn so the root center is at `ground + HipHeight + rootHeight/2`.
- Golden (chance `GoldenChance`): all visible parts `GoldenColor`, a gold `ParticleEmitter` (Rate 8) and `PointLight`;
  `MaxHP = Def.HP * GoldenHPMult`; reward XP/Gold multiplied by `GoldenXPMult` / `GoldenGoldMult`; WarPoints = `GoldenPoints`.
  Name label "황금 " .. Def.Name.
- BillboardGui on the root: name + HP bar (`MaxDistance` 80), updated in `DamageMonster`.
- After parenting: `pcall(root.SetNetworkOwner, root, nil)`.
- Spawn point: `Util.RandomPointInZone(Config.Zones[Def.Zone], Config.Monsters.SpawnInset)`; `Home` = that point.

AI loop every `AIInterval` s over all alive records:
- If flat distance from `Home` > `LeashRadius` or `Config.ZoneAt(root.Position).Town` → `Humanoid:MoveTo(Home)`; continue.
- Target = nearest player that is alive, within `AggroRadius` (flat), and `not S.ZoneService.IsTown(player)`.
- If target within `AttackRange`: stop (`MoveTo(root.Position)`) and, if `AttackCooldown` elapsed for this record,
  `S.CombatService.DamagePlayer(player, Def.Damage, nil)`. Else `MoveTo(targetRoot.Position)`.
- No target: every 4–8 s `MoveTo` a random point within 15 studs of `Home`.

`DamageMonster(record, amount, player)`: ignore if not alive or amount <= 0; `contributors[player] = os.clock()`;
`HP -= amount`; update bar. If `HP <= 0`: `Alive = false`; for each contributor still in game with
`os.clock() - t <= ContributorWindow` → `MonsterKilled:Fire(p, info)`; death pop (shrink/fade 0.3 s, `ParticleEmitter:Emit(15)`),
`Destroy` after 0.4 s; `task.delay(RespawnDelay)` → spawn a new record of the same Kind. Return true. Does **not** send Fx
(CombatService batches hit numbers).
`ApplyKnockback`: `root.AssemblyLinearVelocity = flatDir * power + Vector3.new(0, 25, 0)` (monsters only, never players).
(v2: nobody calls ApplyKnockback in the MVP; keep it for later.)

### 4.9 CombatService (G4) — `ServerScriptService/CombatService.luau`

> 2026-10-09 검수: 이 절의 충전·발사 계약(`Charge`·`ChargeCap`·`PerfectUntil` 속성, 50% 즉시 피해, 자동 발사, 충전 감시 루프, `Release` = 충전 발사)은 낡음 — 충전 게이지는 없다(`GetCharge`는 늘 0). 지금: 입력 한 번 = 공격 한 번(A22), 기본 공격은 바라보는 쪽 앞쪽 반원 `AimCone = 90`(A23-61), `Release` 원격은 첫 스킬 칸과 같은 길이고 스킬은 SkillService `UseSkill(slot)`(MP·재사용, A23-49·A23-71). `SetAutoAttack`은 레벨이 아니라 `AutoCombatUnlocked`(왕관 조각 퀘스트, Lv5 첫 스킬 뒤)를 보고 `AutoCombatEnabled`를 저장한다(A23-1·A23-2·A23-71). 자동은 몬스터만 때리고, 깡패·무법자는 자동 전투를 못 쓴다(A23-22·A23-23). 실제 계약은 `CombatService.luau`·`SkillService.luau`.

```
CombatService.Released : Signal(player, info)
  info = { Stacks: number, Auto: boolean, Perfect: boolean, Center: Vector3, Radius: number,
           Total: number, MonstersHit: number, PlayersHit: number, Healed: { Player } }  -- Healed = OTHER Halo allies healed > 0
CombatService.PlayerDamaged : Signal(victim, amount, attacker)   -- fired by DamagePlayer only when attacker ~= nil, after the damage
  -- R1 CR-M10: amount = HP actually removed (no overkill; may be 0, still fired)

CombatService.Init(S) ; CombatService.Start()
CombatService.DamagePlayer(victim: Player, amount: number, attacker: Player?, crit: boolean?) -> applied: number  -- attacker nil = monster; R1 CR-M10: returns HP actually removed (0 on refusal)
CombatService.HealPlayer(player, amount) -> healedAmount
CombatService.IsInCombat(player) -> boolean           -- dealt or received PvP damage within Config.PvP.CombatTagTime
CombatService.GetLastDamagedAt(player) -> number      -- os.clock() of last damage of any kind, 0 if never
CombatService.GetLastPvPAttacker(player) -> Player?   -- within CombatTagTime and still in game
CombatService.GetDamageBonus(attacker, victim: Player?) -> number   -- additive bonus sum
CombatService.GetDamageMult(attacker, victim: Player?) -> number    -- multiplicative factor
CombatService.ComputeMonsterHit(attacker, allowCrit: boolean) -> (damage: number, isCrit: boolean)  -- NORMAL per-target hit (unrounded)
CombatService.ComputePvPHit(attacker, victim) -> damage: number                                     -- NORMAL per-target hit (unrounded)
CombatService.GetCharge(player) -> number
CombatService.Swing(player, isManual: boolean)
CombatService.Release(player, isAuto: boolean)
```
Formulas (`c = cls(attacker)`, `perks = S.FactionService.GetPerks(attacker)`; every dealt amount is rounded with
`Util.RoundDamage` at the moment it is applied):
```
bonus = perks.DamageBonus
      + stars(attacker) * Config.PvP.StarDamageBonus
      + (faction == "Halo" and perks.PartyAuraPerAlly * math.min(perks.PartyAuraMaxAllies, <other alive Halo players within PartyAuraRadius>) or 0)
      + ((victim ~= nil and S.PvPService.HasRevenge(attacker, victim)) and Config.Revenge.Bonus or 0)
mult  = S.JusticeService.GetDamageMult(attacker)                       -- Size Justice S x bully factor
      * ((victim ~= nil and c.Ranged) and c.PvPMult or 1)              -- Mage/Archer vs players x0.85
monsterHit = Config.WeaponDamage(WeaponTier, Level) * c.Damage * (1 + bonus) * mult * (crit and Config.Combat.CritMult or 1)
             crit = allowCrit and Util.Random:NextNumber() < Config.Combat.CritChance
pvpHit     = Config.MaxHealth(vLevel, vFaction, vClass) * Config.PvP.HitPctOfMaxHP       -- victim BASE health (no S, no kaiju)
             * math.clamp(Config.WeaponDamage(aTier, aLevel) / Config.WeaponDamage(vTier, vLevel), PowerRatioMin, PowerRatioMax)
             * c.Damage * (1 + bonus) * mult
```
(Using the victim's BASE health keeps Size Justice HP and kaiju HP meaningful: the big side really takes more hits.)

**Valid targets** for a swing by `p` (root position `pos`, class `c`):
- monsters: alive records (`S.MonsterService`).
- players: **only if `isManual`** — other players `v` with `S.PvPService.CanAttack(p, v)` true (auto swings and
  automatic releases never hit players).
- goose: `S.GooseService.GetPosition()` (nil when inactive) — counts as reachable if its flat distance to the relevant
  point ≤ (relevant radius) + `Config.Goose.HitRadius`. The goose takes no damage and gives **no charge**.

**R1 changes to Swing / Release (A16-1, A16-5):** both first run `attackBlocked`: return when
`Config.ZoneAt(root.Position).MinLevel > Level` (always), or when `S.ZoneService.IsPlausible(player, pos)` is false (only
while `Config.AntiCheat.Enforce`); Swing then keeps its cooldown unspent and Release keeps the charge. Monster candidates
skip zone monsters whose zone MinLevel > the attacker's Level. `totalDealt` / `total` add the HP really removed
(`hpBefore - rec.HP` for monsters, `DamagePlayer`'s return for players); a monster hit MonsterService refuses adds no hit,
charge or shove. Hit numbers `A` keep `dealt`. PvP hit entries add `V = victim.UserId` (CR-M23).

**`Swing(player, isManual)`**:
1. Alive check; per-player `nextSwingAt` (os.clock): if not reached → return silently; set `nextSwingAt = now + c.SwingInterval`.
2. Select by `c.Pattern`:
   - `"Around"`: monsters `GetMonstersInRadius(pos, c.Range)`; players within `c.Range` of `pos`; goose if within
     `c.Range + HitRadius` of `pos`. `center = pos`, `Radius = c.Range`.
   - `"Splash"`: candidates within `c.Range` of `pos` = nearest monster (`GetNearest(pos, c.Range, 1)`), valid players,
     the goose (within `c.Range + HitRadius`); pick the nearest → `center` = its position (none → whiff). Hit every monster
     within `c.Splash` of `center` and every valid player within `c.Splash` of `center`; the goose counts if it was the pick
     or is within `c.Splash + HitRadius` of `center`. `Radius = c.Splash`, `Targets = { center }`.
   - `"Multi"`: candidates = `GetNearest(pos, c.Range, c.Targets)` monsters + valid players within `c.Range` + goose
     (within `c.Range + HitRadius`); sort by distance; take the first `c.Targets`. `Targets` = their positions, `center = pos`, `Radius = 0`.
3. Each monster: `d, crit = ComputeMonsterHit(player, true)`; `dealt = Util.RoundDamage(d * Config.Charge.SwingImmediate)`;
   `S.MonsterService.DamageMonster(rec, dealt, player)`; hit `{ P = rec.Root.Position, A = dealt, C = crit, K = "M" }`.
4. Each player: `dealt = Util.RoundDamage(ComputePvPHit(player, v) * Config.Charge.SwingImmediate)`;
   `DamagePlayer(v, dealt, player)`; `S.PvPService.BreakProtection(player)`; hit `{ P, A = dealt, C = false, K = "P" }`.
5. Goose reached → `counted = S.GooseService.RegisterHit(player, isManual)`; **R1 CR-L21:** only if `counted > 0` → hit
   `{ P = gooseCenter, A = counted (rounded to 0.1), C = false, K = "G" }` (nil return → old Manual/AutoCount fallback).
6. If ≥ 1 monster or player was hit → `addCharge(player, isManual and c.ChargeManual or c.ChargeAuto)`.
7. Horns lifesteal: `HealPlayer(player, math.min(totalDealt * perks.Lifesteal, maxHealth * perks.LifestealCapPct))`
   (R1 CR-M8: for an Active kaiju the cap base is `maxHealth / S.KaijuService.GetHealthMult(player)`).
8. `MarkActive(player)` if manual or anything (incl. goose) was hit.
9. `Fx "Swing" { UserId, Class = c.Id, Faction, From = <hand position or pos>, Pos = center, Radius, Targets, Hits }`
   — sent when anything was hit, or when `isManual` (whiff feedback, empty Hits). **R1 CR-L49:** not FireAllClients: sent
   to the attacker plus every player whose root is within `Config.Visuals.FxCullDistance + 60 + max(Radius, c.Range)` of `center`.

**Charge** (private `addCharge(p, amount)`): `charge = math.min(cap, charge + amount)` where
`cap = S.FactionService.GetPerks(p).ChargeCap`; attributes `Charge` (number, may be fractional; clients floor it) and
`ChargeCap`. When `charge` reaches `cap` and `PerfectUntil == 0` → attribute `PerfectUntil = Util.Now() + Config.Charge.PerfectWindow`.
Charge is reset to 0 (and `PerfectUntil = 0`) on death, after every release, on `FactionChanged` and on `ClassChanged`
(also update `ChargeCap` there). Charge persists through monster deaths and zone changes. Session only.

**`Release(player, isAuto)`**:
1. Alive; `n = math.floor(charge)`; if `n < Config.Charge.MinRelease` → if not isAuto notify `ReleaseNeed` (MinRelease); return.
2. `perfect = (not isAuto) and attr(player, "PerfectUntil") > Util.Now()`.
3. `center`: `c.ReleaseCenter == "Self"` → own root position; `"Target"` → position of the nearest monster (or, only if not
   isAuto, nearest valid player) within `c.Range`, else own root position. `radius = Config.ReleaseRadius(n)`.
4. Monsters within `radius` of `center`: `D = ComputeMonsterHit(player, false)`;
   `dealt = Util.RoundDamage(Config.ReleaseDamage(D, n, isAuto) * c.ReleaseMult)`; `DamageMonster`.
5. Only if not isAuto: valid players within `radius` of `center`: `D = ComputePvPHit(player, v)`;
   `dealt = Util.RoundDamage(math.min(Config.ReleaseDamage(D, n, false) * c.ReleaseMult, capPct * vHumanoid.MaxHealth))`
   with `capPct = Config.Charge.PvPCapPct`, or `Config.Kaiju.ReleaseCapPct` (0.08) when `v` is the Active kaiju (R1 CR-M7);
   `DamagePlayer(v, dealt, player)`; `BreakProtection(player)`.
6. `total` = sum of HP actually removed (R1 CR-M10). If `perks.ReleaseSupport` (Halo): every alive ready Halo player `a` (self included) within `radius`
   of `center`: `HealPlayer(a, math.min(Config.Charge.HaloHealPct * total, Config.Charge.HaloHealCapPct * aMaxHealth))`;
   every **other** such ally gets `addCharge(a, Config.Charge.HaloAllyStacks)` at most once per
   `Config.Charge.HaloAllyStackCooldown` (5 s) per receiving ally (R1 CR-H1); others with healed > 0 go to `info.Healed`.
7. Horns lifesteal on `total` (same cap as Swing).
8. Reset own charge to 0, `PerfectUntil = 0`. `MarkActive(player)` if not isAuto.
9. `Fx "Release" { UserId, Class = c.Id, Faction, Pos = center, Radius = radius, Stacks = n, Perfect = perfect,
   Auto = isAuto, Total = <sum of the shown hit numbers>, Hits }` to the attacker plus every player whose root is within
   `Config.Visuals.FxCullDistance + 60 + radius` of `center` (R1 CR-L49, not FireAllClients); `Released:Fire(player, info)`
   (`info.Total` = real HP removed).
   R1 CR-L22: `perfect` also counts within `Config.Charge.PerfectGrace` (0.25 s) after `PerfectUntil`; a manual
   `ReleaseNeed` toast within 1 s after an automatic release is skipped.

Remotes:
- **Swing**(): ready → rate limit → `MarkActive` → `Swing(player, true)`.
- **Release**(): ready → rate limit → `Release(player, false)` (MarkActive inside).
- **SetAutoAttack**(enabled): ready → `type(enabled) == "boolean"` → rate limit → if enabled and `Level < AutoUnlockLevel`
  → notify `AutoLocked` (AutoUnlockLevel) and force false → attribute `AutoAttack`.

Loops:
- Auto loop every `AutoLoopInterval`: players with `AutoAttack == true` and alive: if `Level < AutoUnlockLevel` set false;
  if `os.clock() >= nextSwingAt` and (`S.MonsterService.CountInRadius(pos, c.Range) > 0` or the goose is within
  `c.Range + HitRadius`) → `Swing(p, false)`. R1 CR-M17: skip the player for `c.SwingInterval + Config.Combat.ManualYieldPad`
  (0.3) after their last manual Swing request.
- Charge watcher every `Config.Combat.ChargeTick`: players with `PerfectUntil > 0` and
  `Util.Now() >= PerfectUntil + Config.Charge.PerfectGrace` (R1 CR-L22) → `Release(p, true)` (auto-release, ×1.5, monsters only).
- Regen every `RegenTick`: `pct = S.ZoneService.IsTown(p) and Config.Combat.TownRegenPerSec or perks.RegenPerSec`;
  heal `MaxHealth * pct * RegenTick` if below max.

`DamagePlayer(victim, amount, attacker) -> applied`: requires alive victim (else return 0); `humanoid:TakeDamage(amount)`
(respects ForceField); `applied` = HP actually removed (R1 CR-M10); `lastDamagedAt[victim] = os.clock()`;
`S.PlayerService.MarkActive(victim)`. If attacker: `lastPvPAttacker[victim] = { Player = attacker, T = os.clock() }`, mark
both as in combat (`lastPvPTime[x] = os.clock()`, attribute `InCombatUntil = Util.Now() + CombatTagTime` on both), then
`PlayerDamaged:Fire(victim, applied, attacker)` (also when applied is 0). **R1 CR-M23:** whenever `applied > 0` (with or
without an attacker) → `Net.Fx(victim, "Hurt", { Pos = rootPos, Amount = applied })`. Every early return returns 0; the end
returns `applied`.

**Death pipeline (the only KO entry point)** — subscribe `PlayerService.CharacterDied(victim)`:
```
killer = GetLastPvPAttacker(victim)
if killer and (killer == victim or killer.Parent == nil or faction(killer) == faction(victim)
               or faction(killer) == "None" or faction(victim) == "None") then killer = nil end
S.GrudgeService.OnCarrierDown(victim, killer)                    -- 1. resolve a grudge sack first (no-op without one)
if kstate(victim) == "Active" then S.KaijuService.HandleKaijuDeath(victim, killer)   -- 2a. kaiju: event rewards only
elseif killer then S.PvPService.HandleKO(victim, killer)                              -- 2b. normal PvP KO
else S.PvPService.HandleNonPvPDeath(victim) end                                     -- 2c. monster / fall / reset
reset victim charge; clear lastPvPAttacker[victim]
```
`PlayerReady` → attributes `AutoAttack = false`, `InCombatUntil = 0`, `Charge = 0`, `ChargeCap = perks.ChargeCap`,
`PerfectUntil = 0`. `PlayerLeaving` → clear per-player tables inside `task.defer` (ProgressionService's PlayerLeaving
handler reads `IsInCombat`; do not rely on handler order).

### 4.10 FactionService (G6) — `ServerScriptService/FactionService.luau`
```
FactionService.FactionChanged : Signal(player, newFaction, oldFaction, reason: "Choose" | "Altar" | "Rebirth")

FactionService.Init(S) ; FactionService.Start()
FactionService.GetFaction(player) -> "Halo" | "Horns" | "None"     -- player:GetAttribute("Faction") or "None"
FactionService.GetPerks(player) -> table                             -- Config.Factions[faction]
FactionService.GetCounts() -> (haloCount: number, hornsCount: number) -- ready players only, excluding leaving players
FactionService.GetUnderdogCounts(always: Player?) -> (halo: number, horns: number) -- R1 CR-L7: GetCounts minus rookies and > 120 s idlers (`always` counted even if idle)
FactionService.GetTeam(factionId) -> Team | nil
FactionService.SetFaction(player, factionId, reason)                 -- the ONLY writer of the Faction stat
```
- `Init`: create two `Team`s in `game:GetService("Teams")` (Name = `TeamName`, `TeamColor`, `AutoAssignable = false`).
- `PlayerReady`: if Faction ~= "None" → `player.Team = team`, `player.Neutral = false`; else `player.Team = nil`, `player.Neutral = true`.
- `SetFaction(player, f, reason)`: `old = GetFaction(player)`; `SetStat(player, "Faction", f)`; `player.Team`/`Neutral`;
  `FactionChanged:Fire(player, f, old, reason)`; recount. Never touches Honor/Infamy, tickets or cooldowns (callers do).
- Remote **ChooseFaction**(factionId): ready → string and (`"Halo"` or `"Horns"`) → rate limit → current faction must be
  `"None"` (silent). `wasWeaker = (S.JusticeService.GetWeakerFaction() == factionId)` read **before** changing.
  `SetFaction(player, factionId, "Choose")`. If wasWeaker → `S.ProgressionService.AddBankGold(player, Config.Justice.SignOnGold, "Other")`
  + notify `UnderdogSignOn` (SignOnGold, "reward"), and **(R1 CR-L10)** `SetStat LastSwitchTime = os.time()` before the gold,
  so the bonus cannot be followed by an instant free switch. Then `S.PlayerService.Respawn(player)`. (First choice only — never on switches.)
- Remote **SwitchFaction**(useTicket): ready → `type(useTicket) == "boolean"` → rate limit → faction ~= "None" → flat
  distance to `S.MapBuilder.GetAltar().Position` ≤ `Config.Switch.AltarRange` (silent) → `S.GrudgeService.HasSack` →
  `BlockedSack` → `kstate(player) ~= "None"` → `BlockedKaiju` → `stars(player) > 0` → `BlockedStars` →
  `S.CombatService.IsInCombat` → `TravelBlockedCombat` → `os.time() < LastSwitchTime + Config.Switch.Cooldown` →
  `SwitchCooldown` with `Util.FormatTime(remaining)` → if useTicket and `not S.MonetizationService.UseTicket(player, "Faction")`
  → `NoTicket`. Success: `old = faction`, `new = other`.
  **Free** (`useTicket == false`): the score of the faction being LEFT resets ("배신의 대가"): leaving Halo →
  `SetStat(player, "Honor", 0)`, leaving Horns → `SetStat(player, "Infamy", 0)`. **Ticket**: both kept.
  Then `AddStat SwitchCount +1`, `SetStat LastSwitchTime = os.time()`, `SetFaction(player, new, "Altar")`, notify
  `SwitchDoneFree` (new faction Name, "명예"/"악명") or `SwitchDoneTicket` (new faction Name) ("good"),
  `S.PlayerService.Respawn(player)`. Level, gold, weapon, class, marks are kept. Altar switches never grant marks.
  **R1:** after the combat check, a switch to `"Neutral"` with `JusticeService.GetBullyStacks > 0` → `BlockedBully` (CR-L9);
  `UseTicket` returning `false, "Pending"` → `TicketSaving` instead of `NoTicket` (CR-L25); a ticket is spent only when
  the score being left (Honor / Infamy) is > 0, otherwise the switch is free with the plain `SwitchDonePlain` message
  (CR-L11); `nearAltar` also requires `S.ZoneService.IsPlausible` (blocks only while `Config.AntiCheat.Enforce`, CR-H2).
- Altar: in `Start`, `S.MapBuilder.GetAltar().AltarPrompt.Triggered` → if ready and faction ~= "None" →
  `Net.Get("OpenPanel"):FireClient(player, "Altar")`.
- Recount every 10 s, on FactionChanged, PlayerReady and PlayerLeaving (exclude the leaving player): write GameState
  `HaloCount`, `HornsCount`, and (R1 CR-L7) `UnderdogHalo`, `UnderdogHorns` from `GetUnderdogCounts()`.

### 4.11 ClassService (G6) — `ServerScriptService/ClassService.luau`
```
ClassService.ClassChanged : Signal(player, newClass, oldClass)

ClassService.Init(S) ; ClassService.Start()
ClassService.GetClass(player) -> "Warrior" | "Mage" | "Archer"     -- attribute Class, "Warrior" if missing/invalid
ClassService.GetClassDef(player) -> table                           -- Config.Classes[GetClass(player)]
```
- Remote **ChooseClass**(classId) — the first pick: ready → `type(classId) == "string"` and `Config.Classes[classId]` →
  rate limit → `ClassChosen == false` (silent) → faction ~= "None" (`NeedFaction`). `old = GetClass`; `SetStat Class`,
  `SetStat ClassChosen = true`; `S.PlayerService.RefreshCharacter(player, true)`; `ClassChanged:Fire(player, classId, old)`
  (also when equal, so visuals/charge refresh); notify `ClassChosen` (`Config.ClassName(classId, faction)`, "good").
  Level is kept (it is a first choice, not a change).
- Remote **ChangeClass**(classId, useTicket): ready → valid string id and `type(useTicket) == "boolean"` → rate limit →
  `ClassChosen == true` (silent) → `classId ~= GetClass` (`ClassSame`) → alive (silent) → `S.ZoneService.IsPvPZone(player)`
  → `ClassNeedSafe` → `S.GrudgeService.HasSack` → `BlockedSack` →
  `kstate(player) ~= "None"` → `BlockedKaiju` → if useTicket and `not S.MonetizationService.UseTicket(player, "Class")` →
  `NoTicket` (`TicketSaving` when UseTicket returns `"Pending"`, R1 CR-L25). **Free** (2026-10-09: below Lv 5 the free change
  keeps the level, `Config.ClassChange.FreeKeepLevelBelow = 5`, A23-14; tickets are not sold in the beta, A23-28): `S.ProgressionService.ResetLevel(player)`
  (Level 1, XP 0; gold, bank, weapon tier, rebirth bonus, marks, tickets, quests are kept — but unclaimed daily / vacation
  rewards are capped to the level at claim time and Extras are remade on `LevelReset`, R1 CR-M6). **Ticket**: level/XP kept. Then `SetStat Class`, `RefreshCharacter(player, true)`,
  `ClassChanged:Fire`, notify `ClassChangedFree` / `ClassChangedTicket` (`Config.ClassName(classId, faction)`, "good").
  No cooldown. (Safe zones all have MinLevel 1, so no teleport is needed; ZoneService's level gate and PvPService's
  rookie rule re-evaluate on their own loops.)

### 4.12 JusticeService (G6) — `ServerScriptService/JusticeService.luau`
```
JusticeService.Init(S) ; JusticeService.Start()
JusticeService.GetPower(player) -> number            -- Config.PowerOf(Level, WeaponTier, 1 + RebirthBonus)
JusticeService.GetCombatPower(player) -> number      -- R1 CR-L5: Config.PowerOf(Level, WeaponTier, 1) (bully weak-victim test); 2026-10-05 (beta_basics BB4): now includes the weapon enhance (+N scroll level, WeaponEnhance) and will return the integer Config.CombatPower(level, tier, enhance) (no rebirth); sets player attribute CombatPower. GetPower stays the faction-scale value ("진영 힘", with rebirth). 2026-10-09: it returns `Config.CombatPowerOf(player)`, the one power formula incl. stat points (A23-69; they count only while `Config.Features.StatPoints` is on, off now); 0 at Lv 1 bare-handed (A23-34).
JusticeService.GetFactionScale(factionId) -> number  -- current S of that faction (1 for "None")
JusticeService.GetWeakerFaction() -> "Halo" | "Horns" | "None"
JusticeService.GetDamageMult(player) -> number       -- GetFactionScale(faction) * Config.BullyMult(BullyStacks)
JusticeService.GetHealthMult(player) -> number       -- GetFactionScale(faction) * S.KaijuService.GetHealthMult(player)
JusticeService.GetBullyStacks(player) -> number
JusticeService.AddBullyStack(player) -> newStacks    -- +1 (max Config.Bully.MaxStacks), resets the decay timer
JusticeService.RefreshScale(player)                  -- recompute this player's visual scale target now
JusticeService.Recompute()                           -- recompute faction sums / S now
```
- **Recompute** (every `Config.Justice.RecalcInterval` s; plus a debounced `task.defer` request on `PlayerReady`,
  `PlayerLeaving` (exclude the leaving player), `FactionChanged`, `Rebirthed`, `ClassChanged`):
  `haloSum/hornsSum` = sum of `GetPower(p)` over ready players of each faction; counts likewise (R1 CR-M20: only players
  who are not rookies, were active within 120 s (`PlayerService.GetLastActive`) and have not been in a town for 60 s+;
  excluded players still receive their side's S). If both counts ≥ 1:
  `S_Halo = Config.SizeJustice(haloSum, hornsSum)`, `S_Horns = Config.SizeJustice(hornsSum, haloSum)`; else both 1.
  Weaker faction: `"None"` if both sums are 0 or equal, else the faction with the lower sum (an empty faction counts as 0).
  Write GameState `HaloPower`, `HornsPower` (rounded to integers), `HaloSize`, `HornsSize` (rounded to 0.01), `WeakerFaction`.
  For every ready player whose faction S changed by > 0.001 (or whose faction changed since the last pass): attribute
  `SizeMult = S` (rounded 0.01), `S.PlayerService.RefreshCharacter(p, false)` (HP % preserved), `RefreshScale(p)`.
- **Visual scale target** = `math.min(Config.Justice.MaxVisualScale, GetFactionScale(f) * Config.BullyMult(stacks) *
  (kstate(p) == "Active" and Config.Kaiju.VisualScale or 1))`.
  Scale loop every `ScaleTick`: for each ready alive character with `|target - character:GetScale()| > 0.005`, move toward
  the target by at most `ScaleRatePerSec * ScaleTick` via `Util.SafeScaleTo(character, newScale)`; write attribute
  `VisualScale` (rounded 0.01) whenever it changes. `CharacterSpawned` → snap straight to the target (no lerp) and write
  `VisualScale`.
- **Bully stacks** (session only): attribute `BullyStacks`. `AddBullyStack` → `RefreshScale`. Decay loop (1 s): stacks > 0
  and `os.clock() - lastBullyChange >= Config.Bully.DecaySeconds` → stacks −1, `lastBullyChange = os.clock()`, notify
  `BullyDecay` (stacks, "info"), `RefreshScale`. Cleared on leave (R1 CR-L1: inside `task.defer`, so other
  PlayerLeaving handlers can still read them). R1 CR-M12: saved as `data.SavedBully` / `SavedBullyAt` in PlayerLeaving and
  restored (minus elapsed decay) in PlayerReady — A16-3.
- `PlayerReady` → attributes `SizeMult = 1`, `BullyStacks = 0`, `VisualScale = 1`, then request a recompute.

### 4.13 PvPService (G7) — `ServerScriptService/PvPService.luau`

> 2026-10-09 검수: 뼈대는 그대로지만 더해진 규칙이 있다 — 해골 유적은 바깥 사냥 고리 PvP 끔, 안쪽 왕관 구덩이만 PvP(`zone.PvPArea`, A23-90), 개인 서버에서는 거위·포위 상자·현상금 보상 절반(`Config.PrivateServer`, A23-90), 주간 PvP 판·무법자 벌칙(RankingService, A23-22·A23-23), 자동 전투는 사람을 때리지 않음(A23-1), 스킬 Z·X의 사람 피해는 `Config.Skills.PvPZX` 스위치(A23-49). 게시판 글은 영어(A23-48).

```
PvPService.PlayerKO : Signal(killer, victim, info)
  info = { Kind: "Plunder" | "Bounty" | "Honor" | "Bully" | "Defense" (R1 CR-M14), Bully: boolean, VictimStars: number,
           Stolen: number, Bounty: number,
           Rewarded: boolean }   -- = pair cooldown allowed minted rewards AND not a bully KO

PvPService.Init(S) ; PvPService.Start()
PvPService.CanAttack(attacker, victim) -> (boolean, reasonKey: string?)
PvPService.IsRookie(player) -> boolean     -- Rebirths == 0 and (Level < RookieLevel or PlaytimeSeconds < RookiePlaytime)
PvPService.GetStars(player) -> number
PvPService.ResetStars(player)              -- stars = 0 + attributes (used by KaijuService and internally)
PvPService.HasRevenge(attacker, victim) -> boolean   -- attacker holds an active revenge mark on victim
PvPService.BreakProtection(player)
PvPService.Protect(player, seconds)        -- visible ForceField + attribute Protected = true for `seconds`
PvPService.HandleKO(victim, killer)        -- called ONLY by CombatService's death pipeline
PvPService.HandleNonPvPDeath(victim)       -- called ONLY by CombatService's death pipeline
PvPService.DebugSetStars(player, n)        -- Studio debug hook (§7.1)
```
`CanAttack(a, v)` (in order): `a ~= v`; both ready and alive; both factions ~= "None" and different (`"SameFaction"`);
**kaiju exception:** if `kstate(v) == "Active"` and `faction(a) == "Halo"` → return true (any zone, rookies allowed,
protection ignored); `S.ZoneService.IsPvPZone` true for **both** (`"SafeZone"`); neither `IsRookie` (`"Rookie"`);
victim attribute `Protected ~= true` (`"Protected"`). (v1's level-gap rule and anti-camp immunity are gone.)

State per player: `stars`, `lastStarChange` (os.clock), `protectedUntil`, `spawnedAt`, `koLog[killer][victim] = {times}`,
`lastHitOn[a][v] = os.clock()` (a damaged v), `pairReward[killer][victim] = lastTime`, `revenge[p] = { Target: Player, Until }`.
**R1:** `koLog` and `pairReward` moved into the saved `PairCD` (keys `kolog:<victimUserId>` = last 2 KO times and
`ko:<victimUserId>` on the killer, via `PlayerService.PairReady`; bully-bounty claims `bully:0` on the victim — A16-2,
CR-M4). `lastHitOn` became `dmgLog[a][v] = { { T, A } }` (amount > 0, BaitWindow, ≤ 64 entries, CR-M15).

- `CharacterSpawned` → `spawnedAt[p] = os.clock()`; `Protect(p, Config.PvP.SpawnProtection)`.
- `Protect(p, s)`: add a visible `ForceField` to the character if none; `protectedUntil = max(current, os.clock() + s)`;
  attribute `Protected = true`. `BreakProtection` destroys ForceFields and sets `Protected = false` immediately.
- `CombatService.PlayerDamaged(victim, amount, attacker)` → `lastHitOn[attacker][victim] = os.clock()` (R1: append
  `{ T = os.clock(), A = amount }` to `dmgLog[attacker][victim]` when amount > 0).
- 1 s loop: expire protection; star decay (one star per `StarDecaySeconds` since `lastStarChange`) **only while
  `kstate(p) == "None"`** (queued/active kaiju keep their stars); attributes `WantedStars`,
  `Bounty = Config.Bounty(Level, stars, S.JusticeService.GetBullyStacks(p))`, `Rookie = IsRookie(p)`; expire revenge
  (`RevengeTargetId = 0`, `RevengeUntil = 0`). Every `BoardRefresh` s update the board text (below).
- `addStar(killer)`: `min(MaxStars, stars + 1)`, reset `lastStarChange`, update attributes; when it becomes `AnnounceStars`
  → `Net.NotifyAll(string.format(Config.Text.MostWanted, killer.DisplayName, Util.FormatNumber(bounty)))`.
  (Reaching 5 stars is what KaijuService polls for.)

`HandleKO(victim, killer)`:
1. `starsBefore = GetStars(victim)`; `bullyBefore = S.JusticeService.GetBullyStacks(victim)`; `now = os.clock()`.
   Append `now` to `koLog[killer][victim]`, drop entries older than `Config.Bully.RepeatWindow`.
2. **Bully check** (any faction pairing):
   ```
   weak = S.JusticeService.GetPower(victim) < Config.Bully.WeakPowerRatio * S.JusticeService.GetPower(killer)
   if weak and now - (lastHitOn[victim][killer] or -math.huge) <= Config.Bully.BaitWindow then weak = false end -- anti-bait
   if weak and Config.Bully.WantedIgnoresWeakRule and (starsBefore > 0 or bullyBefore > 0) then weak = false end
   fresh    = now - (spawnedAt[victim] or -math.huge) < Config.Bully.FreshSpawnSeconds
   repeated = #koLog[killer][victim] >= Config.Bully.RepeatKOs
   bully = weak or fresh or repeated
   ```
   **R1:** `weak` compares `JusticeService.GetCombatPower` (no rebirth bonus, CR-L5; since BB4 it includes the weapon enhance, ratio unchanged). The anti-bait line becomes
   `baited = <victim's damage to the killer in dmgLog within BaitWindow> >= Config.Bully.BaitMinPct * Config.MaxHealth(killer
   Level, faction, class)` (CR-M15); `if weak and baited then weak = false end`; `defense = baited and (fresh or repeated)`;
   `if defense or kstate(killer) ~= "None" then bully = false end` (CR-M14). A `defense` KO builds
   `info = { Kind = "Defense", Bully = false, VictimStars = starsBefore, Stolen = 0, Bounty = 0, Rewarded = false }` and skips
   steps 4–6 (no stacks, stars, plunder, honor/infamy or bounty); revenge (step 3) and the KO log still run → step 7.
3. **Revenge** (always): `revenge[victim] = { Target = killer, Until = now + Config.Revenge.Duration }`; victim attributes
   `RevengeTargetId = killer.UserId`, `RevengeUntil = Util.Now() + Config.Revenge.Duration`; notify victim `Revenge`
   (killer.DisplayName, "info"). If `revenge[killer]` targets `victim` → clear it (attributes 0) and notify killer `RevengeDone` ("good").
4. **Bully KO** → `n = S.JusticeService.AddBullyStack(killer)`; notify killer `BullyKO` (n, "bad"); notify victim
   `BullyVictim` ("info"). No plunder, no stars, no honor/infamy, no bounty, no war points:
   `info = { Kind = "Bully", Bully = true, VictimStars = starsBefore, Stolen = 0, Bounty = 0, Rewarded = false }` → step 7.
5. `pairOk = now - (pairReward[killer][victim] or -math.huge) >= PairRewardCooldown`; if pairOk record now.
   (R1 CR-M4: `pairOk = S.PlayerService.PairReady(killer, victim.UserId, "ko", PairRewardCooldown)`, saved in PairCD.)
6. **Horns killer, Halo victim** (Kind `"Plunder"`): first `addStar(killer)` — **R1 CR-M3: only if `pairOk`**. Then if
   `not S.GrudgeService.CanSteal(killer, victim)` → `stolen = 0`, notify killer `PlunderTooSoon`; else
   `floor = SafeFloorPerLevel * vLevel`;
   `stolen = math.min(math.floor(math.max(0, carried - floor) * PlunderRate), PlunderCapPerLevel * vLevel)`.
   If stolen > 0: `S.ProgressionService.TakeCarriedGold(victim, stolen)`,
   `S.GrudgeService.AddToSack(killer, victim, stolen, pairOk and 1 or 0)` (gold goes into the SACK, not the killer's gold),
   `Net.Fx(nil, "Plunder", { From = victimPos, To = killerPos, Amount = stolen })`, notify victim `Plundered`
   (killer.DisplayName, FormatNumber(stolen), "bad"), notify killer `PlunderGain` (FormatNumber(stolen), current stars) "reward".
   If stolen == 0 and pairOk → `AddStat(killer, "Infamy", 1)` directly (no sack to carry it).
   Bully bounty: if `bullyBefore > 0` and pairOk → `b = Config.Bounty(vLevel, 0, bullyBefore)`; `AddBankGold(killer, b, "Bounty")`;
   notify `BullyBountyGain`; `info.Bounty = b`.
   **Halo killer, Horns victim**: if `starsBefore == 0 and bullyBefore == 0` → Kind `"Honor"`: if pairOk →
   `AddStat(killer, "Honor", HonorPerKOMin)` + notify `HonorGain`. Else Kind `"Bounty"`:
   `bounty = pairOk and Config.Bounty(vLevel, starsBefore, bullyBefore) or 0`; if bounty > 0 → `AddBankGold(killer, bounty, "Bounty")`;
   `honor = pairOk and math.max(1, starsBefore) or 0` → `AddStat(killer, "Honor", honor)`; if `starsBefore > 0` →
   `TakeCarriedGold(victim, math.floor(carried * VillainLossOnBountyKO))`; notify killer `BountyGain` (FormatNumber(bounty), honor);
   if `starsBefore >= GlowStars` and bounty > 0 → `Net.NotifyAll(BountyAnnounce)` (names only the hero).
   (A thief's grudge sack was already resolved by GrudgeService in pipeline step 1.)
7. `ResetStars(victim)`. `PlayerKO:Fire(killer, victim, info)` with `Rewarded = pairOk and not bully`.

`HandleNonPvPDeath(victim)`: **R1 CR-L4:** if stars ≥ 1 and (`S.ZoneService.IsTown(victim)` or
`os.clock() - S.CombatService.GetLastDamagedAt(victim) > 3`) → keep the stars and return (no loss: a town reset or a fall
must not wipe a bounty). Otherwise: if stars ≥ 1 → `TakeCarriedGold(victim, floor(carried * VillainLossOnWantedPvEDeath))`;
`ResetStars`. Also `ResetStars` on `FactionChanged`. Clean all tables on `PlayerLeaving` (also clear other players'
revenge marks that target the leaver).
**R1 PlayerLeaving(p, data):** first the logout bounty (CR-M11, A16-4: Horns leaver with ≥ 1 star, in combat, not an Active
kaiju, last PvP attacker an online ready Halo passing `PairReady(a, p.UserId, "ko", PairRewardCooldown)` → `Config.Bounty`
to the attacker's bank + honor + BountyGain), then `data.SavedStars` / `SavedStarsAt` (0 after a paid logout bounty or for
an Active kaiju; restored minus decay in PlayerReady, ≤ `Kaiju.StarsNeeded - 1`, CR-M12), then the cleanup.

Board text (via `S.MapBuilder.GetBoardLabel().Text`), newline-separated: `"현상수배 TOP 3"`, then up to 3 lines
`"1. 이름 ★★★ 900G"` (players with `Bounty > 0`, sorted by Bounty desc; append `" 깡패"` when BullyStacks > 0) or
`"(아직 없음)"`, blank line, `"빛의 기사단 명예 TOP 3"`, up to 3 lines `"1. 이름 명예 120"` (Halo players by Honor desc)
or `"(아직 없음)"`.
**갱신 (2026-10-05, beta_basics BB37):** the board also gets an Infamy TOP 3 block (`"뿔 군단 악명 TOP 3"`, Horns players by Infamy desc, up to 3 lines, `"(아직 없음)"` when empty). Every name on the board (and in every other server-wide announcement) goes through `AnnounceService.PublicName(player)`: it returns `Util.PlayerDisplayName(player)`, or the hidden-name text with the faction name (e.g. "빛의 기사단 한 명") when `data.HideAnnounceName == true`. The `" 깡패"` suffix stays; only the name becomes the public one.

### 4.14 GrudgeService (G7) — `ServerScriptService/GrudgeService.luau`

> **갱신 (2026-10-05, A23-18 + mmorpg_painpoints P3):** 아래의 "나간 피해자 몫은 사라진다(destroyed)"는 **대체**됐다. 자루가 끝나는 순간 서버에 없는 피해자의 몫은 DataStore 우편(`HaloHorns_GrudgeMail_v1`, 키 `M_<userId>`, 최대 20통)으로 보내고, 다음 접속 때 먼저 비운 뒤 같은 생(`Rebirths` 같음)만 지급한다. 120%는 Avenged이고 `pairReady('refund')` 쿨다운이 지났을 때 첫 통만이다. **원한 유령 붙잡기:** 털린 피해자가 부활한 뒤 `GhostHold` 원격(인자 없음, 3초 제한, 살아 있을 때만)으로 자루 시간을 +2초씩, 자루당 최대 +10초(45→55초) 늘린다. 놓아주기·명예 보상은 없다. 구현: 커밋 735419e.
>
> **원한 우편 구현 상세 (커밋 735419e, 검수 수정 포함):**
> - 피해자가 서버에 없을 때 그 몫을 편지 한 통으로 DataStore `HaloHorns_GrudgeMail_v1`, 키 `M_<userId>`에 쓴다 (`MAIL.Send`, `UpdateAsync`, 최대 `Config.Grudge.MailMax` = 20통, 넘으면 오래된 것부터 버림). 편지: `{ Id, A = 금액, R = 훔칠 때 환생 수, K = "Avenged" | "Returned", T }`.
> - 편지 `Id` = 도둑 + 자루 시작 시각 + 종류 (`sack.Id .. ":Avenged"` / `":Returned"`, `sack.Id` = `thief.UserId:os.time()`). 같은 `Id`가 이미 있으면 다시 쓰지 않아서, 쓰기를 재시도(최대 4번, 1·2·4초 간격)해도 같은 편지가 두 통 생기지 않는다.
> - 피해자가 다음에 접속하면 (`MAIL.Receive`) 우편함을 먼저 비운 뒤 같은 생(`R == Rebirths`)의 편지만 은행 금고로 지급한다. 환생한 뒤의 편지는 지급하지 않는다(CR-M6). 지급 전에 피해자가 나가거나 준비가 안 되면 편지를 도로 넣는다(아직 아무것도 안 줬으니 두 번 줄 수 없다).
> - 120%는 `Avenged` 편지이고 `pairReady('refund')` 쿨다운이 지났을 때, 받은 편지 중 첫 통만이다. 나머지는 `Config.Grudge.ReturnRate`.
> - 서버를 닫을 때 `PlayerService`의 `BindToClose`가 `GrudgeService.MailPending()`(쓰는 중인 편지 수)이 0이 될 때까지 (최대 `CLOSE_TIMEOUT`) 기다린다.
> - **규칙: 서버가 꺼지면 편지를 잃을 수는 있어도 두 번 주지는 않는다.** (A crash may lose a letter, never double-pays.)
```
GrudgeService.SackResolved : Signal(thief, outcome: "Paid" | "Avenged" | "Returned", total: number)

GrudgeService.Init(S) ; GrudgeService.Start()
GrudgeService.HasSack(player) -> boolean
GrudgeService.GetSackTotal(player) -> number
GrudgeService.CanSteal(thief, victim) -> boolean          -- false if this thief stole from this victim < RestealWindow ago
GrudgeService.AddToSack(thief, victim, amount, infamy)    -- amount was already taken from the victim's carried gold
GrudgeService.OnCarrierDown(player, killer: Player?)      -- death pipeline step 1; no-op without a sack
```
State: `sacks[thief] = { Entries = { [victimUserId] = { Amount, Name } }, Total, Remaining, Infamy }`;
`lastSteal[pairKey]`, `lastRefund[pairKey]` (pairKey = `thief.UserId .. ":" .. victim.UserId`), `lastAvenge[avengerKey]`.
**R1:** the three cooldowns live in the saved `PairCD` via `PlayerService.PairReady` (A16-2, CR-M4): victim
`steal:<thiefUserId>` (CanSteal looks with commit = false, AddToSack records), victim `refund:0` (extra 20 % once per
VICTIM whatever the thief) and avenger `avenge:0` (bonus once per AVENGER whatever the thief) (CR-L6). Each entry also
stores the victim's `Rebirths`; a refund / return is paid only while it is unchanged, otherwise that share is destroyed
(an older entry's Amount is zeroed when more gold is added after a rebirth) (CR-M6).
- `AddToSack`: create or merge (multiple steals stack into ONE sack), `Remaining = Config.Grudge.SackSeconds` (reset),
  `Infamy += infamy`, `lastSteal[pairKey] = os.clock()`; thief attributes `SackGold = Total`,
  `SackSeconds = math.ceil(Remaining)`, `SackVictimName = victim.DisplayName` (latest victim; the ghost shows it).
- Tick every `Config.Grudge.Tick`: for each sack, **only if `S.ZoneService.IsPvPZone(thief)`** → `Remaining -= Tick`;
  update `SackSeconds` when its ceil changes. `Remaining <= 0` → **Paid**: `AddCarriedGold(thief, Total, "Plunder")`; if
  `Infamy > 0` → `AddStat(thief, "Infamy", Infamy)`; notify thief `SackPaid` (FormatNumber(Total), "reward");
  clear; `SackResolved:Fire(thief, "Paid", Total)`.
- `OnCarrierDown(thief, killer)`: if `killer` and `faction(killer) == "Halo"` → **Avenged**: for each entry whose victim is
  still in the server and ready: `bonusOk = os.clock() - (lastRefund[pairKey] or -math.huge) >= RefundBonusCooldown`;
  `refund = math.floor(Amount * (bonusOk and AvengeRefundRate or ReturnRate))`; `AddBankGold(victim, refund, "Refund")`;
  if bonusOk record `lastRefund`; notify victim `GrudgeRefund` (killer.DisplayName, FormatNumber(refund), "good");
  `Net.Fx(victim, "Plunder", { From = thiefPos, To = victimPos, Amount = refund })` when both positions exist. Shares of
  victims who left are destroyed. Avenger: if `os.clock() - (lastAvenge[killer:thief] or -math.huge) >= Config.PvP.PairRewardCooldown`
  → `AddBankGold(killer, Config.Grudge.AvengerBonus, "Bounty")` + notify `AvengerBonus`; record. `Net.NotifyAll(GrudgeAvengedAll`
  (killer.DisplayName, thief.DisplayName)). (The normal bounty is paid by PvPService.HandleKO.)
  Otherwise (no killer, or killer not Halo) → **Returned**: each present victim gets `math.floor(Amount * ReturnRate)` to
  the bank + notify `GrudgeReturned`. In both cases notify thief `SackLost` ("bad"), clear, fire `SackResolved`.
- `PlayerLeaving(thief)` with a sack → **Returned** (as above). Leaving never pays the thief.
- Clearing a sack sets thief attributes `SackGold = 0`, `SackSeconds = 0`, `SackVictimName = ""`.
- The thief cannot Travel/use pads (ZoneService), switch faction (FactionService), change class (ClassService) or rebirth
  (ProgressionService) while `HasSack` — those services check it.

### 4.15 KaijuService (G9) — `ServerScriptService/KaijuService.luau`
```
KaijuService.KaijuStarted : Signal(player)
KaijuService.KaijuEnded   : Signal(player, outcome: "Defeated" | "Survived" | "Cancelled", participants: { Player })

KaijuService.Init(S) ; KaijuService.Start()
KaijuService.GetState(player) -> "None" | "Queued" | "Siren" | "Active"
KaijuService.GetActive() -> Player?            -- the current Siren/Active player, if any
KaijuService.GetHealthMult(player) -> number   -- 1 unless Active; Active: Config.Kaiju.HPMult * (1 + HPPerNearbyHalo * nearbyHalo) (cached)
KaijuService.HandleKaijuDeath(victim, killer: Player?, leaving: boolean?)   -- called by CombatService's death pipeline;
                                               -- R1 CR-M11: also by KaijuService itself with leaving = true (no character access)
```
One kaiju per server; others wait in a FIFO queue. Player attribute `KaijuState` mirrors `GetState`. Loop every
`Config.Kaiju.Tick`:
- **Queue:** each ready Horns player with `stars(p) >= StarsNeeded` and state `"None"` → append, state `"Queued"`
  (notify `KaijuQueued` if a kaiju is current). Drop queued players who left, are no longer Horns or have fewer stars.
- **Siren:** no current kaiju and queue non-empty → pop first → state `"Siren"`; GameState `KaijuPhase = "Siren"`,
  `KaijuUserId`, `KaijuName = DisplayName`, `KaijuEndsAt = Util.Now() + SirenSeconds`;
  ~~`Net.NotifyAll(string.format(Config.Story.KaijuSiren, name), "announce", SirenSeconds)`~~ (removed in R1 CR-L23: the
  EventHUD siren banner, driven by GameState `KaijuPhase = "Siren"`, is the only announcement). When the siren ends: player
  still in game, Horns, alive and `stars ≥ StarsNeeded` → **Activate**, else `finish(p, "Cancelled")`.
- **Activate:** state `"Active"`, GameState `KaijuPhase = "Active"`, `KaijuEndsAt = Util.Now() + Duration`; compute the
  health mult; `S.JusticeService.RefreshScale(p)` (×3 visual, capped 3.0); `S.PlayerService.RefreshCharacter(p, true)`
  (full heal at transformation); `Net.NotifyAll(KaijuStart)`; `KaijuStarted:Fire(p)`; reset participant tables.
- **Every `HPRecalc` s while Active:** `nearby` = alive Halo players within `NearbyRadius` (flat) of the kaiju →
  health mult → `RefreshCharacter(p, false)` (HP % preserved).
- **Every `StompInterval` s while Active:** for each alive Halo player `v` within `StompRadius` (flat) that is not
  `IsRookie`, not `Protected` and not in a town: `S.CombatService.DamagePlayer(v, Util.RoundDamage(vMaxHealth * StompPct), atk)`
  with **`atk = S.ZoneService.IsPvPZone(v) and p or nil`** (R1 CR-M13: in a safe zone the stomp is environmental damage —
  no combat tag and no PvP KO credit; the victim still sees the Hurt number, CR-M23);
  `Net.Fx(nil, "Stomp", { UserId, Pos = kaijuPos, Radius = StompRadius })`. The kaiju keeps normal controls otherwise.
- **Survived** (`Util.Now() >= KaijuEndsAt`): `c = TakeCarriedGold(p, CarriedGold)`; `amount = math.floor(c * SurviveBankMult)`;
  `AddBankGold(p, amount, "Kaiju")`; attribute `SessionTitle = Config.Story.SurviveTitle` (session only);
  `S.WarService.AddFactionPoints("Horns", HornsWarPoints)`; notify `KaijuSurviveReward`; `Net.NotifyAll(KaijuSurvived)`;
  `finish(p, "Survived")`.
- **`HandleKaijuDeath(victim, killer)`** (Defeated, whoever/whatever dealt the last hit — no last-hit bonus):
  `pool = BountyPoolMult * Config.Bounty(Level, stars(victim), S.JusticeService.GetBullyStacks(victim)) + TakeCarriedGold(victim, all)`.
  Participants = Halo players still in game who damaged the kaiju during the event, plus Halo players who healed (via
  release) a Halo player who damaged it. For each participant: `share = math.floor(pool * DamageShare * dmg[p] / totalDmg)
  + math.floor(pool * (1 - DamageShare) / #participants)` → `AddBankGold(p, share, "Kaiju")` + notify `KaijuReward`.
  No participants → nothing is paid. `S.WarService.AddFactionPoints("Halo", HaloWarPoints)`;
  `Net.NotifyAll(KaijuDefeated(name, FormatNumber(pool)))`; `finish(victim, "Defeated")`.
  **R1:** the kaiju's carried gold put into the pool is capped at `Config.PvP.PlunderCapPerLevel × kaiju Level` (rest
  destroyed); the minted share is paid once per participant per `Config.Kaiju.PairRewardCooldown` (1800 s) through
  `PairReady(p, kaijuUserId, "kaiju", ...)`, spent only when that share > 0 (CR-M3, CR-M4). The announcement uses the gold
  actually paid, or `Config.Story.KaijuDefeatedNoReward` when nobody was paid (CR-L19). With `leaving = true` the character
  is not touched and `finish(victim, "Defeated", participants, leaving)` also zeroes `data.SavedStars` (CR-M11, CR-M12).
- `finish(p, outcome)`: `S.PvPService.ResetStars(p)`; state `"None"`; mult 1; GameState `KaijuPhase = "None"`,
  `KaijuUserId = 0`, `KaijuName = ""`, `KaijuEndsAt = 0`; `S.JusticeService.RefreshScale(p)`; if alive →
  `RefreshCharacter(p, false)` and `S.PvPService.Protect(p, ShieldSeconds)` (a Defeated kaiju respawns with normal spawn
  protection); `KaijuEnded:Fire(p, outcome, participantsList)`; clear tables.
- Participation: `CombatService.PlayerDamaged(victim, amount, attacker)` → if victim is the Active kaiju and
  `faction(attacker) == "Halo"` → `dmg[attacker] += amount`. `CombatService.Released(player, info)` → if a kaiju is Active
  and `faction(player) == "Halo"` → for each `h` in `info.Healed` with `dmg[h] > 0` → `healers[player] = true`.
- `PlayerLeaving` of the current kaiju → `finish(p, "Cancelled")` (no rewards); remove leavers from the queue.
  **R1 CR-M11:** if the leaver is Active and the Halo damage total > 0 → `pcall(HandleKaijuDeath, p, nil, true)` (settled as
  Defeated); Cancelled only if that fails or the kaiju is still current afterwards.
  `FactionChanged` of the current kaiju (defensive; normally blocked) → `finish(p, "Cancelled")`.

### 4.16 GooseService (G9) — `ServerScriptService/GooseService.luau`

> 2026-10-09 검수: 바뀐 곳 — 상대 진영이 서버에 없으면 "함께 구조" 모드(GameState `GooseMode`·`GooseCoop*`, 보상은 이긴 편의 70%, 전쟁 점수 없음), 직접 3번 이상 때린 사람만 보상(A23-14). 희귀 확률은 단골 분이 아니라 오늘의 운(`GetLuckEvents`, A23-18). 개인 서버에서는 보상 절반(A23-90).

```
GooseService.GooseFinished : Signal(result: "Halo" | "Horns" | "Tie", counts: { [Player]: number })

GooseService.Init(S) ; GooseService.Start()
GooseService.IsActive() -> boolean
GooseService.GetPosition() -> Vector3?         -- goose body center while active (Position + (0, HoverHeight, 0)), else nil
                                               -- R1 CR-L21: + Vector3.new(sideOffset, 0, 0) (the tug pivot)
GooseService.RegisterHit(player, isManual) -> number  -- CombatService calls this for every swing that reached the goose
                                               -- R1 CR-L21: returns the faction-scaled count added (0 when rejected)
GooseService.DebugStart()                      -- Studio debug hook: start a goose right now
```
- **Schedule:** in `Start` (after WarService started): `nextAt = S.WarService.GetRoundEndsAt() - Config.Goose.OffsetFromWarEnd`;
  `while nextAt <= Util.Now() do nextAt += Interval end`; GameState `GooseNextAt = nextAt`. Tick loop (`Goose.Tick`):
  not active and `Util.Now() >= nextAt` → `start()`; active and `Util.Now() >= GooseEndsAt` → `finish()`.
- `start()`: GameState `GooseActive = true`, `GooseEndsAt = Util.Now() + Duration`, `GooseRescue = 0`, `GoosePoach = 0`;
  build `workspace.Effects.GoldenGoose` (Model of anchored, `CanCollide = false`, `CanQuery = false` Parts: gold body,
  neck, head, orange beak, two wings, a small Neon crown-shard wedge on the head, PointLight, sparkle ParticleEmitter,
  BillboardGui "황금 거위"); gentle bob tween; `Net.NotifyAll(GooseStart)`. The goose cannot die.
  While active, pivot it sideways by `math.clamp((poach - rescue) / math.max(1, rescue + poach) * 6, -6, 6)` studs on X.
- `RegisterHit(p, isManual)`: ignore if inactive or faction not Halo/Horns. Rolling 1 s window per player: if
  `MaxCountsPerSecond` counts already happened in the last second → ignore. `amount = (isManual and ManualCount or AutoCount)
  * S.JusticeService.GetFactionScale(faction)`; `counts[p] += amount`; Halo → rescue, Horns → poach; attribute
  `GooseCount = math.floor(counts[p])`. GameState `GooseRescue`/`GoosePoach` (rounded 0.1) are published from the tick loop.
- `finish()`: `result = rescue > poach and "Halo" or (poach > rescue and "Horns" or "Tie")`; **R1 CR-L8:** if either faction
  has 0 players (`FactionService.GetCounts`) the result becomes "Tie" and the broadcast is `Config.Story.GooseNoRival`. For each ready participant
  (`counts[p] > 0`, faction Halo/Horns): `won = (result == faction)`; RARE: if `CheerStars >= CheerStarsForRare` →
  rare = true and `AddStat(p, "CheerStars", -CheerStarsForRare)`; else `rare = Util.Random:NextNumber() <
  Config.RareChance(S.PlayerService.GetRegularMinutes(p))`. `gold, xp = Config.GooseReward(Level, faction, won, rare)`;
  `AddBankGold(p, gold, "Event")`; `AddXP(p, xp)`; notify `GooseReward` (FormatNumber(gold), FormatNumber(xp), "reward").
  Rare → `Net.Fx(p, "Rare", { Gold = gold, XP = xp })` + `Net.NotifyAll(RareAnnounce(DisplayName), "info")`.
  Not won (loss or tie) → `AddStat(p, "CheerStars", 1)` + notify `GooseCheer` (new count, "info").
  If result ~= "Tie" → `S.WarService.AddFactionPoints(result, WinWarPoints)`. `Net.NotifyAll(GooseResult[result])`;
  `Net.Fx(nil, "GooseEnd", { Pos = gooseCenter, Winner = result })`; destroy the model; reset `GooseCount = 0` on
  participants; GameState `GooseActive = false`, `GooseEndsAt = 0`; advance `nextAt` by `Interval` (past now) and publish
  `GooseNextAt`; `GooseFinished:Fire(result, counts)`.
- `PlayerLeaving` → drop the leaver from `counts` (their contribution stays in the side totals).

### 4.17 WarService (G3) — `ServerScriptService/WarService.luau`
```
WarService.Init(S) ; WarService.Start()
WarService.AddPoints(player, points, poolPoints?)    -- personal + faction pool (R1 CR-M18: pool gets poolPoints if valid, capped at points)
WarService.AddFactionPoints(factionId, points)       -- faction pool only (events: goose, kaiju)
WarService.HasBlessing(player) -> boolean            -- blessing faction == player's faction (and ~= "None")
WarService.GetBlessingFaction() -> "Halo" | "Horns" | "None"
WarService.GetPersonalPoints(player) -> number
WarService.GetRoundEndsAt() -> number                -- server time; valid after Start
```
- Story: each round decides which side "holds the crown"; the sky change is the crown's color.
- Subscriptions: `MonsterKilled` → `AddPoints(p, info.WarPoints, info.WarShare)` (R1 CR-M18: one kill adds WarPoints once
  to the faction pool, however many same-faction players helped); `PlayerKO` → if `info.Rewarded` →
  `AddPoints(killer, PvPKOPoints + PvPKOPerStar * info.VictimStars)`; `FactionChanged` / `PlayerReady` → personal = 0;
  `PlayerLeaving` → remove personal.
- `AddPoints`: ignore faction "None"; `points[f] += n`; personal += n; attribute `WarPoints`. `AddFactionPoints`: ignore
  unknown factions; `points[f] += n`.
- `Init`: create `ColorCorrectionEffect` named `WarTint` in `Lighting`. `Start`: apply `Config.Sky.Neutral` instantly,
  `roundEndsAt = Util.Now() + RoundSeconds`, start the tick loop.
- Tick every `Config.War.Tick` s: `halo, horns = S.FactionService.GetCounts()`; per-capita `score = points / math.max(1, count)`
  (R1 CR-M19: `count` = the faction's ROUND-AVERAGE head count, summed every tick and reset each round; an average < 0.5
  counts as 0; it also decides `WarMode` and the winner, so a last-second exodus cannot flip the result);
  GameState attributes `WarHaloScore`, `WarHornsScore` (rounded to 0.1), `WarRoundEndsAt = roundEndsAt`,
  `WarMode` = "Idle" (both counts 0) / "Siege" (exactly one is 0) / "Normal". If `Util.Now() >= roundEndsAt` → end round.
- End round: Normal → higher per-capita wins, equal → "None". Siege → the present faction wins iff its per-capita
  ≥ `SiegeTarget`, else "None". Idle → "None" silently. Set blessing, GameState `WarBlessing`, tween sky
  (`Dawn` for Halo, `Eclipse` for Horns, `Neutral` for None) over `Config.Sky.TweenTime` (Lighting ClockTime, Brightness,
  Ambient, OutdoorAmbient, FogColor, FogEnd + `WarTint.TintColor`; R1 CR-L20: ClockTime always moves forward through a
  NumberValue, `ClockTime = v % 24`). Chests: every ready player with faction ~= "None" and
  personal ≥ `ChestMinPoints` gets `Level * WinnerChestPerLevel` (on the winning faction) or `Level * LoserChestPerLevel`
  (everyone else, including draws) via `AddBankGold(p, amount, "War")` + notify `WarChest`. Unless Idle,
  `Net.NotifyAll(string.format(Config.Story.WarWin[winner]))` or `Config.Story.WarDraw`. Reset points and personal
  points, next `roundEndsAt = Util.Now() + RoundSeconds`.

### 4.18 ProgressionService (G8) — `ServerScriptService/ProgressionService.luau`
```
ProgressionService.GoldEarned : Signal(player, amount, source)
  source: "Monster" | "Quest" | "Bounty" | "Plunder" | "War" | "Refund" | "Event" | "Kaiju" | "Other"
ProgressionService.LeveledUp  : Signal(player, newLevel)
ProgressionService.Rebirthed  : Signal(player, rebirths, info)   -- info = { From, To, Bonus: number, Mark: "Fall" | "Redeem" | "None" }
ProgressionService.LevelReset : Signal(player)                   -- R1 CR-M6: end of ResetLevel (free class change); QuestService remakes Extras

ProgressionService.Init(S) ; ProgressionService.Start()
ProgressionService.GetGoldMult(player) -> number
ProgressionService.GetXPMult(player) -> number
ProgressionService.AddXP(player, amount)                         -- raw amount (no multiplier); handles level-ups
ProgressionService.AddCarriedGold(player, amount, source)        -- raw; fires GoldEarned
ProgressionService.AddBankGold(player, amount, source)           -- raw; fires GoldEarned
ProgressionService.TakeCarriedGold(player, amount) -> taken      -- clamped to [0, carried]; no signal
ProgressionService.SpendGold(player, amount) -> boolean          -- carried first, then bank; false = no change
ProgressionService.GetTotalGold(player) -> number
ProgressionService.BankAll(player, silent: boolean) -> banked
ProgressionService.ResetLevel(player)                            -- Level 1, XP 0, RefreshCharacter(full) (free class change)
ProgressionService.TryRebirth(player, factionId) -> (ok: boolean, reasonText: string?)
```
Multipliers (additive; applied to monster kill rewards only — quest/event/vacation/bounty amounts are raw):
```
GoldMult = 1 + perks.GoldBonus + stars(p) * Config.PvP.StarGoldBonus
             + (S.WarService.HasBlessing(p) and Config.War.BlessingGold or 0)
             + RebirthBonus + FallMarks * Config.Rebirth.FallGoldPer
XPMult   = 1 + perks.XPBonus
             + (S.WarService.HasBlessing(p) and Config.War.BlessingXP or 0)
             + RebirthBonus + RedeemMarks * Config.Rebirth.RedeemXPPer
```
2026-10-09: on top of these, the A23-75 2x XP / 2x Gold passes multiply every XP grant and the earned gold sources in
`Config.PassBoost.GoldSources` by `Config.PassBoost.Mult` (once per grant, never inside `GetXPMult` / `GetGoldMult`).
In a private server `AddBankGold` first multiplies gold from `Config.PrivateServer.HalfSources` (Event, War, Bounty) by
`Config.PrivateServer.RewardMult` (0.5), before the pass (A23-90).
- `MonsterKilled(p, info)` → `gold = math.floor(info.Gold * GoldMult + 0.5)`, `xp = math.floor(info.XP * XPMult + 0.5)`;
  `AddCarriedGold(p, gold, "Monster")`; `AddXP(p, xp)`; `AddStat(p, "TotalKills", 1)`;
  `Net.Fx(p, "Reward", { Pos = info.Position, Gold = gold, XP = xp, Golden = info.Golden })`.
- `AddXP`: add, then `while Level < MaxLevel and XP >= Config.XPToNext(Level)` → subtract, level++. At MaxLevel clamp XP to
  `XPToNext(MaxLevel)`. Write via SetStat. On any level-up: `S.PlayerService.RefreshCharacter(p, fullHeal)` with
  `fullHeal = not IsInCombat(p) and KaijuService.GetState(p) ~= "Active"` (R1 CR-M16),
  `Net.Fx(nil, "LevelUp", { UserId, Level, Pos })`, `LeveledUp:Fire` (R1 CR-L23: no `LevelUp` Notify; Fx announces it).
- 1 s loop: (R1 CR-M9: skip players whose kaiju state is Siren or Active) if `S.ZoneService.IsTown(p)` and carried > 0 →
  `BankAll(p, false)`. Else if the faction's `AutoBankInterval > 0` and that many seconds passed since the last auto-bank →
  move `math.floor(carried * AutoBankFraction)` to the bank (Fx `"Bank" { Amount, Courier = true }`; R1 CR-L23: no
  `HaloCourier` Notify, the client shows it). (Grudge-sack gold is not carried gold and is never banked here.)
- `BankAll`: moves all carried to bank; if > 0 and not silent → `Net.Fx(p, "Bank", { Amount })` (R1 CR-L23: no `Banked` Notify).
- `PlayerReady`: if carried > 0 → `BankAll(p, true)` (leftover from a crash). Reset the auto-bank timer.
- `PlayerLeaving(p, data)`: if `S.CombatService.IsInCombat(p)` and not `S.PlayerService.IsShuttingDown()` (R1 CR-M2) →
  `data.CarriedGold = math.floor(data.CarriedGold * (1 - CombatLogPenalty))`;
  then `data.BankGold += data.CarriedGold; data.CarriedGold = 0` (direct data mutation; attributes do not matter here).
- **Turncoat rebirth** — Remote **Rebirth**(factionId): ready → `type(factionId) == "string"` → rate limit →
  `TryRebirth`; notify the reason ("bad") on failure. `TryRebirth(p, factionId)`:
  1. `factionId` must be `"Halo"` or `"Horns"` (else false, nil). `Level >= Config.RebirthLevel(Rebirths)` (else `RebirthNeed`).
     Blocks: `stars(p) > 0` → `BlockedStars`; `S.GrudgeService.HasSack` → `BlockedSack`; `kstate(p) ~= "None"` →
     `BlockedKaiju`; `S.CombatService.IsInCombat` → `TravelBlockedCombat`; (R1 CR-L9) `factionId == "Neutral"` and
     `JusticeService.GetBullyStacks(p) > 0` → `BlockedBully`.
  2. Underdog bonus: `halo, horns = S.FactionService.GetCounts()`; subtract 1 from the player's current faction count;
     `bonus = Config.RebirthBonusFor(factionId == "Halo" and halo or horns, halo + horns)` (0.25 or 0.40).
     (R1 CR-L7: the counts come from `GetUnderdogCounts()` — no rookies, no > 120 s idlers — and the player is subtracted
     only when counted; the Rebirth remote calls `MarkActive` first.)
  3. Mark: `old == "Halo" and factionId == "Horns"` → `"Fall"` (`FallMarks = math.min(MarkMax, FallMarks + 1)`);
     `old == "Horns" and factionId == "Halo"` → `"Redeem"` (`RedeemMarks` likewise); else `"None"`.
  4. Reset `Level = 1, XP = 0`~~`, BankGold = 0, CarriedGold = 0, WeaponTier = 1`~~ (2026-10-09: gold, owned weapons,
     enhancements and items are KEPT, A23-14; an equipped weapon whose MinLevel is above the new level is swapped to the best usable one, A23-28); `Rebirths += 1`;
     `RebirthBonus = math.floor((RebirthBonus + bonus) * 100 + 0.5) / 100`. Keeps Class, Honor, Infamy (both),
     tickets, marks, quests (QuestService regenerates extras on `Rebirthed`; unclaimed daily / vacation rewards are capped
     to the level at claim time and grudge refunds skip a rebirthed victim, R1 CR-M6). Free, no tickets, no altar cooldown.
  5. If `factionId ~= old` → `S.FactionService.SetFaction(p, factionId, "Rebirth")` + `S.PlayerService.Respawn(p)`;
     else `RefreshCharacter(p, true)`.
  6. `Net.Fx(nil, "Rebirth", { UserId, Rebirths, Pos, Mark })`, notify `RebirthDone` (`math.floor(bonus * 100 + 0.5)`,
     "reward"); if Mark ~= "None" → `Net.Notify(p, string.format(Config.Story.Fall or Redeem), "announce")`;
     `Net.NotifyAll(RebirthAnnounce)`; `Rebirthed:Fire(p, Rebirths, { From = old, To = factionId, Bonus = bonus, Mark = mark })`.

### 4.19 ShopService (G8) — `ServerScriptService/ShopService.luau`

> 2026-10-09 검수: 아래 "UpgradeWeapon() = 다음 티어 자동 구매·장착"은 낡음 — A23-4가 대체: `UpgradeWeapon(tier)`(tier 1..`Config.WeaponShop.MaxSoldTier` = 3, 미보유는 구매+장착, 보유는 무료 재장착), `SellWeapon(tier)`(가격의 10%), `WeaponOwnedMask`, `BlacksmithVisited`, 대장간 12스터드 안. 첫 무기(T1)는 대장간에서 무료로 받는다(A23-34·A23-74). 황금 무기 T4~T6 의뢰는 CommissionService `Commission(tier)`(A23-86 결정 2).

```
ShopService.Init(S) ; ShopService.Start()
```
Remote **UpgradeWeapon**(): ready → rate limit → `tier = WeaponTier`; `tier >= Config.MaxWeaponTier` → `WeaponMaxed`;
`nextDef = Config.Weapons[tier + 1]`; `Level < nextDef.MinLevel` → `WeaponNeedLevel` (MinLevel); `nextDef.RequiresFaction`
and faction "None" → `NeedFaction`; `not S.ProgressionService.SpendGold(p, nextDef.Price)` → `NotEnoughGold`. Success:
`SetStat(p, "WeaponTier", tier + 1)`, notify `WeaponBought` with `Config.WeaponName(tier + 1, Class, faction)` ("reward"),
`Net.Fx(p, "Upgrade", { Tier = tier + 1 })`. (CharacterVisuals rebuilds the weapon from the attribute change.)

### 4.20 QuestService (G8) — `ServerScriptService/QuestService.luau`

> 2026-10-09 검수: 일일·추가 퀘스트 뼈대는 그대로지만 바뀐 곳이 있다. `Release` 템플릿은 이제 "Skill hits" = 몬스터를 1마리 이상 맞힌 스킬만 센다(게이지 조건 없음, A23-1), Lv5 전에는 스킬 퀘스트를 주지 않는다(A23-71). 새싹(Lv1~9) 일일은 짧은 목표 3개(A23-14, `Config.Quests.Newbie`). 이야기·마을·게시판 퀘스트는 StoryQuestService·BoardService(A23-46·A23-56), Q 창 탭 5개(A23-81), HUD에는 지금 퀘스트 하나만 크게(A23-94). `Quests` 원격 내용은 §5 표 참고.

```
QuestService.Init(S) ; QuestService.Start()
QuestService.GetQuests(player) -> { Quest }     -- data.Quests (array of Config.Quests.Slots entries)
Quest = { Id: string, Kind: "Daily" | "Extra", Target: number, Progress: number, RewardGold: number, RewardXP: number,
          Text: string, MinStacks: number?,
          Unit: string? }   -- R1 CR-M27: Kill/Golden quests: the monster type whose kills count as 1 (see Progress)
QuestService.DebugSimulateAbsence(player, days)  -- Studio hook: DailyDay = today - (days + 1), then run the day check
```
- `newQuest(player, kind)`: candidates = templates where `Faction` (if set) equals the player's faction; `PvP` →
  `Level >= PvPMinLevel`, `not S.PvPService.IsRookie(p)` and no other slot holds a PvP quest; prefer templates whose `Id`
  is not already in another slot. Weighted random by `Weight`. `units` = random entry of (`kind == "Daily"` and
  `DailyUnits` or `Units`); `main = Config.MonsterTypes[Config.ZoneMainMonster[Config.QuestZoneForLevel(Level)]]`;
  `Target = (Id == "Gold") and units * main.Gold or units`. Rewards: Daily → `RewardGold, RewardXP = Config.DailyQuestReward(Level)`;
  Extra → `math.floor(units * main.Gold * RewardPerUnit * ExtraRewardMult)` / same with `main.XP`. `Text`: Gold →
  `string.format(T.Text, tostring(Target))` (R1 CR-L31: exact number); Kill / Golden → `string.format(T.Text,
  main.Short or main.Name, Target)` with `Unit = <main id>` (R1 CR-M27; texts `"%s %d마리 쓰러뜨리기"` / `"황금 %s %d마리 처치"`);
  others → `string.format(T.Text, Target)`. `MinStacks = T.MinStacks`.
  `Progress = Target >= 5 and math.floor(Target * Util.Random:NextNumber(EndowedMin, EndowedMax)) or 0`.
- **Day check** (on `PlayerReady` and every `Config.Daily.CheckInterval` s): `today = Config.DayIndex(os.time())`; if
  `DailyDay ~= today`:
  1. Vacation: if `DailyDay > 0` and `today > DailyDay + 1` → `missed = today - DailyDay - 1`;
     `days = math.min(Config.Daily.VacationMaxDays, VacationDays + missed)`; `g, x = Config.VacationReward(Level, days)`;
     `SetStat VacationDays = days, VacationGold = g, VacationXP = x` (recomputed at the current level, pending until claimed).
  2. Any slot that is a completed but unclaimed Daily → pay it now (`AddBankGold "Quest"` + `AddXP`) and notify `DailyAutoPaid`.
  3. `SetStat DailyDay = today`, `SetStat DailyClaims = 0`; all 3 slots become fresh `newQuest(p, "Daily")`. Publish.
  (New players: `DailyDay == 0` → dailies, no vacation.)
  **R1 CR-M21 (replaces step 1):** `claims = min(Slots, DailyClaims + #auto-paid dailies)` is read before the reset; if
  `DailyDay > 0` and `today > DailyDay`: `add = (1 - f) + (today - DailyDay - 1)` with
  `f = (claims * QuestMinutes + (claims >= Slots and ChestMinutes or 0)) / (Slots * QuestMinutes + ChestMinutes)`;
  `VacationDays = min(VacationMaxDays, VacationDays + add)` (fractional, 3 decimals), gold/XP recomputed as before. So a
  partly played day never pays less than an absent day. If the step-2 auto-pay completes the set
  (`DailyClaims < Slots <= claims`), the bonus chest (and the ticket roll) is paid too. **R1 CR-M6:** the auto-paid amounts
  are capped to `Config.DailyQuestReward(current Level)`.
- Progress: `MonsterKilled(p, info)` → Kill +1; Golden +1 if `info.Golden`. **R1 CR-M27 (deviation):** instead of +1 a kill
  adds `killWeight = math.clamp(Config.MonsterTypes[info.Kind].XP / Config.MonsterTypes[q.Unit].XP, 0, 1)` (quests saved
  without `Unit` use the level zone's main monster), so a quest sized for the player's zone cannot be farmed on low-zone
  slimes; Progress is fractional and published floored to 0.1. `GoldEarned(p, amount, source)` → only
  `source == "Monster"` → Gold +amount. `CombatService.Released(p, info)` → Release +1 if `info.Stacks >= quest.MinStacks`.
  `GooseService.GooseFinished(result, counts)` → Goose +1 for each player with `counts[p] > 0`. `PlayerKO(killer, victim, info)`
  → killer's Hunt +1 if `info.Kind == "Bounty"`; killer's Plunder +1 if `info.Kind == "Plunder"`.
  `KaijuService.KaijuEnded(p, "Defeated", participants)` → Hunt +1 for each participant.
- Completion (`Progress >= Target`, clamp Progress to Target): **Extra** → `AddBankGold(p, RewardGold, "Quest")`,
  `AddXP(p, RewardXP)`, notify `QuestDone` (FormatNumber(RewardGold), "reward"), replace the slot with `newQuest(p, "Extra")`.
  **Daily** → stays in the slot as done, notify `DailyReady` once ("good"); paid only by `ClaimQuest`.
- Remote **ClaimQuest**(slot): ready → integer `1..Slots` → rate limit → slot is a Daily with `Progress >= Target` (silent
  otherwise) → pay (`AddBankGold "Quest"`, `AddXP`), notify `DailyClaimed`, `AddStat DailyClaims +1`, replace the slot with
  `newQuest(p, "Extra")`. If `DailyClaims == Slots` → bonus chest: `g, x = Config.DailyChestReward(Level)`, pay, notify
  `DailyChest`; with chance `Config.Daily.ChestTicketChance` → `S.MonetizationService.AddTickets(p, "Class", 1)` + notify `DailyChestTicket`.
  R1 CR-M6: the paid daily reward is `min(stored, Config.DailyQuestReward(current Level))` (gold and XP separately).
- Remote **ClaimVacation**(): ready → rate limit → `VacationDays > 0` (silent) → `AddBankGold(p, VacationGold, "Quest")`,
  `AddXP(p, VacationXP)`, notify `VacationClaimed`, `SetStat` all three to 0. (Doing dailies always beats vacation: 100% vs 70%.)
  R1 CR-M6: capped to `Config.VacationReward(current Level, VacationDays)`.
- Remote **RerollQuest**(slot): ready → integer `1..Slots` → rate limit → `Util.Now() >= RerollReadyAt` → slot not complete
  → regenerate with the SAME Kind (`newQuest(p, kind)`), `RerollReadyAt = Util.Now() + RerollCooldown`, publish.
- Publish (**R1 CR-L50**): a 0.5 s loop builds `json = HttpService:JSONEncode(list)` for dirty players, each entry
  `{ Id, Kind, Text, Progress, Target, RewardGold, RewardXP, Slot }` (+ the pinned tutorial entry, A5-C6), and sends it with
  `Net.Get("Quests"):FireClient(player, json)` only when it differs from the last one sent (and once again after each
  CharacterSpawned). The `QuestsJson` attribute is no longer written. Progress is floored to 0.1; Daily rewards are shown
  capped to the current level (CR-M6).
- `PlayerReady`: ensure exactly `Slots` valid quests (missing/invalid entries → `newQuest(p, "Extra")`), attribute
  `RerollReadyAt = 0`, run the day check, publish. `FactionChanged`: regenerate (same Kind) slots whose template no
  longer fits (R1 CR-L12: a remade Daily keeps `max(new, old)` rewards). `Rebirthed` and (R1 CR-M6) `ProgressionService.LevelReset`:
  regenerate Extra slots only (dailies keep their stored rewards, but claims are capped to the current level).
  Data: `data.Quests` is mutated directly.

### 4.21 MonetizationService (G2) — `ServerScriptService/MonetizationService.luau`

> 2026-10-09 검수: 변경권(아래 계약)은 코드에 남아 있지만 베타에서 팔지 않는다(A23-28). 베타 전 상품은 A23-75 게임 패스다: `Config.GamePasses`(XP2 199·Gold2 149·VIP 249, 속성 `PassXP2`/`PassGold2`/`PassVIP`), 진영 치장 `Config.Looks`(99, `SetLook` 원격, 출석 전용 치장 포함, A23-77), 개인 서버 100(게시 때 사용자), VIP 후원자 게시판(GameState `SupporterNames`). 소유 확인은 접속 때 `UserOwnsGamePassAsync` + `PromptGamePassPurchaseFinished`. ID 0이면 "Coming soon". 능력치는 안 판다. 설계: `docs/design/gamepass_server_2026-10-08.md`. 아래의 한국어 안내 문구("상품 준비 중")는 옛 것.

```
MonetizationService.Init(S) ; MonetizationService.Start()
MonetizationService.GetTickets(player, kind: "Class" | "Faction") -> number
MonetizationService.AddTickets(player, kind, delta) -> newCount   -- data.Tickets[kind] (>= 0) + attribute
MonetizationService.UseTicket(player, kind) -> (boolean, reason: "Pending" | "None" | nil)  -- consumes 1 if available
                                               -- R1 CR-L25: "Pending" = a purchase is still saving (callers toast TicketSaving), "None" = no ticket
```
- Attributes `ClassTickets`, `FactionTickets` mirror `data.Tickets.Class` / `.Faction`; set on `PlayerReady` and on every
  change. `data.Tickets` and `data.ProcessedReceipts` are mutated directly (documented exception).
- `Start`: `MarketplaceService.ProcessReceipt = processReceipt` (assigned ONCE, only here). If `RunService:IsStudio()` and
  any `Config.Products.*.Id == 0` → `print("[MonetizationService] Developer Product ids are 0: buy buttons show '상품 준비 중'. Create 2 Developer Products on create.roblox.com (your game > Monetization > Developer Products) and paste their ids into Config.Products.")`.
- `processReceipt(info)` — wrapped in `pcall`; any error → `Util.Warn` + `NotProcessedYet`:
  1. `player = Players:GetPlayerByUserId(info.PlayerId)`; not in this server → `NotProcessedYet`.
  2. Wait (0.5 s steps, up to `Config.Tickets.ReceiptWaitSeconds`) until `S.PlayerService.IsReady(player)`; still not ready
     or left → `NotProcessedYet`.
  3. `kind` = the `Kind` of the `Config.Products` entry whose `Id == info.ProductId` (Id 0 never matches); unknown →
     `Util.Warn` + `NotProcessedYet`.
  4. `data = S.PlayerService.GetData(player)`; `already = table.find(data.ProcessedReceipts, info.PurchaseId) ~= nil`.
     If not already: insert `info.PurchaseId`, trim the oldest entries beyond `MaxReceiptsKept`, `AddTickets(player, kind, 1)`.
  5. **Force a save:** `if not S.DataService.Save(player, false) then return NotProcessedYet end` (the grant stays in
     memory; Roblox retries later and step 4 sees the PurchaseId, so nothing is granted twice).
  6. If not already → notify `ClassTicketGot` / `FactionTicketGot` ("reward"). Return `PurchaseGranted`.

### 4.22 CharacterVisuals (G5) — `ServerScriptService/CharacterVisuals.luau`

> 2026-10-09 검수: 아래 모양(노란 원판 후광·쐐기 뿔, 한국어 이름표 글)은 낡음. 지금 플레이어는 본인 Roblox 아바타 + 직업 무기 + 후광/뿔이고 치비 코스튬은 없다(A23-5). 후광·뿔은 계급 R1~R5 모양(A23-54)에 A23-75 치장 색(`LookOn`)을 입히고, 이름표 글은 영어(A23-48)·글꼴 `Config.Fonts`(A23-63)다. 무기는 아직 코드가 Part로 만든다 — 맨손(WeaponTier 0)이면 없음(A23-34), 활은 왼손, 펫 조련사는 지휘봉(A23-39); 직업×단계마다 새 Tripo 무기로 바꾸는 일은 A23-96 목록 P3. 실제 계약은 `CharacterVisuals.luau`.

```
CharacterVisuals.Init(S) ; CharacterVisuals.Start()
CharacterVisuals.Refresh(player)     -- rebuild everything on the current character
```
All accessory parts: unanchored, `Massless = true`, `CanCollide = false`, `CanQuery = false`, `CanTouch = false`,
positioned then welded with `Util.Weld`. **Sizes and offsets are multiplied by `sc = character:GetScale()` at build
time** (JusticeService scales the whole model afterwards, including these parts). Each piece is a child named exactly as
below and is rebuilt on `CharacterSpawned` and when its watched attributes change (connect attribute signals once per
player at `PlayerReady`; handlers re-check the current character).
- **Nametag** BillboardGui on Head (`StudsOffset (0, 2.6 * VisualScale, 0)`, 240×80 px, `MaxDistance = NametagMaxDistance`,
  RichText): line 1 `"[" .. Config.DisplayTitle(Faction, Honor, Infamy, FallMarks, RedeemMarks, SessionTitle) .. "] " .. DisplayName`
  in faction color; line 2 `"Lv " .. Level .. " · " .. Config.ClassName(Class, Faction)` + (`"  환생 " .. Rebirths` if > 0)
  + (`"  새싹 보호"` if `Rookie`); line 3 (red, only if any): `"깡패"` (+ `" ×" .. BullyStacks` when > 1) when
  `BullyStacks > 0`, then `string.rep("★", WantedStars) .. " 현상금 " .. FormatNumber(Bounty)` when `Bounty > 0`.
  Watches: Level, Class, Faction, Honor, Infamy, Rebirths, WantedStars, Bounty, Rookie, BullyStacks, SessionTitle,
  FallMarks, RedeemMarks, VisualScale (VisualScale only moves the offset).
- **FactionMark** (watches Faction, Honor, Infamy): `scale = 1 + MarkScalePerRank * (rank - 1)`.
  Halo: flat Neon yellow disc (Cylinder part, size `0.15, 2.2*scale, 2.2*scale`, lying flat) 1.6 studs above the head +
  yellow PointLight. Horns: two red Neon WedgeParts (`0.4, 1.0*scale, 0.6*scale`) on the top-left and top-right of the head,
  tilted outward. None: nothing.
- **WeaponModel** (watches WeaponTier, Faction, Class), attached to `RightHand` (R15) or `Right Arm` (R6); `w = Config.Weapons[tier]`,
  color `Config.WeaponColor(tier, Faction)`, material `w.Material`:
  Warrior (`Sword`): Handle (0.3×1.2×0.3, wood), Guard (1.2×0.25×0.4, dark metal), Blade (0.25 × `w.Length` × 0.6), pointing
  forward. Mage (`Staff`): shaft (0.3 × (`w.Length` + 1.5) × 0.3, wood), held upright, with a Neon Ball tip (diameter
  `0.7 + 0.1 * tier`) + PointLight in the weapon color. Archer (`Bow`): 5 thin parts (0.2×0.9×0.2) forming a vertical arc
  of height ≈ `w.Length` + a straight white string (0.05 thick) between the arc ends. Tier ≥ 6: PointLight; tier 7: also a
  ParticleEmitter.
- **GoldSack** (watches CarriedGold, Level): `tier = Config.SackTier(CarriedGold, Level)`; tier 0 → none; otherwise a Ball
  (`SackSizes[tier]`, brown Fabric) welded to the back of `UpperTorso`/`Torso`; tier ≥ 4 adds a gold ParticleEmitter.
- **GrudgeSack** (watches SackGold, Level): when `SackGold > 0`, a `GrudgeSackColor` Fabric Ball (`SackSizes[max(1, SackTier(SackGold, Level))]`)
  on the back, offset lower than GoldSack, with a purple ParticleEmitter. **GrudgeGhost** (watches SackGold, SackVictimName):
  when `SackGold > 0`, a translucent "grudge ghost" of the victim floating `GhostHeight` studs above the head: Ball head
  (1.2) + block torso (1.6×2×0.8), `GhostColor`, `Transparency = GhostTransparency`, Neon, with a BillboardGui
  `SackVictimName .. "의 원한"`. Both destroyed when `SackGold == 0`.
- **RebirthAura** (watches Rebirths, Faction): ParticleEmitter in HumanoidRootPart when Rebirths ≥ 1, color from the highest
  `Config.Rebirth.Auras` entry with `Min <= Rebirths` (nil Color → faction color). Rate 6, Lifetime 1.2, LightEmission 0.6.
- **MarkCape** (watches FallMarks): FallMarks ≥ 1 → torn black cape: 3 thin `CapeColor` parts of uneven length hanging
  from the back of the torso. **MarkHalo** (watches RedeemMarks): RedeemMarks ≥ 1 → cracked halo: 4 `CrackedHaloColor`
  arc segments with gaps, 2.4 studs above the head (above FactionMark). **GrayAura** (watches FallMarks, RedeemMarks): both
  ≥ `Config.Rebirth.GrayLegendMin` → gray ParticleEmitter (`GrayAuraColor`) in HumanoidRootPart.
- **WantedGlow** (watches WantedStars, KaijuState): `Highlight` parented to the character when `WantedStars >= GlowStars`
  or `KaijuState == "Active"` (FillColor 255,40,40, FillTransparency 0.6, OutlineColor 255,0,0, `DepthMode = AlwaysOnTop`);
  destroyed otherwise. Highlight is used for nothing else (Roblox renders at most 31).
- **KaijuFire** (watches KaijuState): `KaijuState == "Active"` → fire-like ParticleEmitter (`KaijuFireColor`, Rate 30) + red
  PointLight in HumanoidRootPart; destroyed otherwise.

### 4.23 Client modules (G10–G12) — `StarterPlayer/StarterPlayerScripts/`

> 2026-10-09 검수: 아래 화면 자리 표, HUD 5버튼(공격·발사·자동·업그레이드·메뉴)·충전 고리, 키, 한국어 문구는 낡음. 지금 화면: 왼쪽 위 둥근 미니맵(카메라 쪽이 위, A23-66; 코드로 그린 땅 위에 위에서 찍은 실제 세상 사진 칸을 까는 중 — 지금 시험 4칸 `Config.UIArt.MapTiles`, A23-95), 왼쪽 가운데 '지금 퀘스트 하나' 큰 글씨(A23-94; PC — 폰은 아직 미니맵 옆, `HudLayout`), 아래 가운데 Lv·경험치·HP/MP·아이콘 줄, 오른쪽 위 [Menu]가 왼쪽으로 펼침(A23-38·A23-40·A23-74), 오른쪽 아래 공격·스킬(Lv5부터 보임)·자동·물약(물약 칸은 늘 보임) 묶음(A23-74·A23-71·A23-99). PC를 먼저 끝내고 폰은 따로(A23-98). 기본 키(A23-78, `Config.Keybinds`, 설정에서 바꿀 수 있음): 공격 F, 스킬 Z·X·C(X·C는 Z·X 스킬을 켤 때만, A23-86 결정 3), 자동 R, 유령 붙잡기 T, 물약 1·2, 상호작용 G, 다음 무기 U, 가방 I, 영웅 E, 스킬 K, 퀘스트 목록 Q, 지도 M, 랭킹 L, 도움말 H, 메뉴 B. 카메라는 콘솔식 따라가기가 기본(Settings에서 Free, A23-91), 오른쪽 드래그로 돌리고 왼쪽 드래그는 안 돈다(A23-51). 글꼴 Denk One + Montserrat(A23-63). 모듈 목록은 `ClientMain.client.luau`(37개), 그림은 `Config.UIArt` + UIKit.

Each module returns a table with `Init(C)` and `Start()` (last line of `Start`: `print("[<ModuleName>] started")`).
Client code reads state only from player attributes (LocalPlayer and, for arrows/markers, other players),
`Net.GameState()` attributes and the Fx/Notify/OpenPanel remotes. Required by `ClientMain` via
`script.Parent:WaitForChild(name)`. Server time on the client = `Util.Now()`.

**Screen layout slots** (reference 1280×720 at UIScale 1, offsets in px) — each owner stays inside its slot:

| Slot | Owner | Where |
|---|---|---|
| Stats block | HUD | top-left (12, 12), ~300×150 |
| War meter block | HUD | top-center, y 8–66 |
| Event strip (goose timer / tug bar / kaiju chip) | EventHUD | top-center, y 72–110 |
| Status chips | HUD | top-center, y 116–146 |
| Toast stack (max 4) | UIKit | top-center from y 152 down |
| Kaiju siren banner | EventHUD | full width at 18% screen height |
| Announce banner | UIKit | 30% screen height |
| Luck corner | EventHUD | top-right (right 12, y 52), 250×52 |
| Quest rows | HUD | left-middle (12, 200), 300×(3×62) |
| Personal line (sack / kaiju / revenge) | EventHUD | bottom-center at 72% height |
| Travel bar | HUD | center at 60% height |
| 5 big buttons | HUD | bottom-right |
| Screen-edge arrows | EventHUD | full-screen layer, ZIndex 1 |
| Modals | Panels, FactionPicker, ClassPicker | ZIndex ≥ 50; `UIKit.Confirm` ZIndex 100 |

**UIKit** (`UIKit.luau`, G10)
```
UIKit.Gui : ScreenGui        -- "MainGui", ResetOnSpawn=false, IgnoreGuiInset=true, ZIndexBehavior=Sibling, DisplayOrder=10; created in Init
                             -- R1 CR-L34: then ScreenInsets=DeviceSafeInsets, SafeAreaCompatibility=None (pcall) — see A3-H4
UIKit.Theme = { Bg = Color3.fromRGB(25,25,35), BgTransparency = 0.25, Text = Color3.new(1,1,1), SubText = Color3.fromRGB(200,200,210),
                Good = Color3.fromRGB(80,220,120), Bad = Color3.fromRGB(255,80,80), Gold = Color3.fromRGB(255,210,60),
                XP = Color3.fromRGB(90,170,255), Halo = Config.Factions.Halo.Color, Horns = Config.Factions.Horns.Color,
                Sack = Config.Visuals.GrudgeSackColor, Revenge = Color3.fromRGB(255,150,40), Font = Enum.Font.GothamBold }
UIKit.Create(className, props, children?) -> Instance
UIKit.Button(props, onClick) -> TextButton   -- props: Name, Text, Size, Position, AnchorPoint, Color, TextColor, TextSize, Parent
                                             -- adds UICorner + UIStroke, press-shrink tween, calls C.Fx.PlaySound("Click")
UIKit.Label(props) -> TextLabel              -- transparent background, Theme.Font
UIKit.Bar(props) -> (frame, setFraction(f: number, color: Color3?), textLabel)
UIKit.Toast(text, kind, duration?)           -- kinds: info/good/bad/reward; max 4 stacked; default 2.5 s
UIKit.Announce(text, duration?)              -- large banner at 30% screen height; default 3.5 s
UIKit.Confirm(title, body, confirmText, onConfirm)  -- modal dialog with [취소] and [confirmText]; onConfirm() only on confirm
UIKit.Fmt(key, ...) -> string                -- string.format(Config.Text[key], ...)
UIKit.Attr(name, default) -> any             -- LocalPlayer:GetAttribute(name) ?? default
UIKit.OnAttr(names: {string}, fn)            -- connect LocalPlayer:GetAttributeChangedSignal for each; call fn() once now
UIKit.GameAttr(name, default) -> any ; UIKit.OnGameAttr(names, fn)   -- same for Net.GameState()
```
`UIScale` child of the Gui: `math.clamp(viewport.Y / 720, 0.6, 1.25)`, updated on `Camera:GetPropertyChangedSignal("ViewportSize")`.
`Start`: `Net.Get("Notify").OnClientEvent` → `Kind == "announce"` → `Announce(Text, Duration)` else `Toast(Text, Kind, Duration)`.

**HUD** (`HUD.luau`, G10)
- Stats block: `"Lv 12"` badge + `Config.DisplayTitle(Faction, Honor, Infamy, FallMarks, RedeemMarks, SessionTitle)` +
  `Config.ClassName(Class, Faction)`; XP bar 260×16 `"XP / XPToNext"`; `"금고 12.3K"` (BankGold) and `"주머니 1.2K"`
  (CarriedGold); stars row `"★★★☆☆  현상금 900"` only when Faction == "Horns".
- War meter 420×26 — left Halo fill / right Horns fill proportional to `WarHaloScore / (WarHaloScore + WarHornsScore)`
  (0.5 when both 0), numbers at both ends; below `"왕관 결정까지 m:ss"` from `WarRoundEndsAt`; Siege mode
  `"몬스터 포위전: 1인당 150점"`; blessing chip `"<faction name> 왕관 축복 +25%"` when `WarBlessing ~= "None"` (brighter
  if mine); my `WarPoints`.
- Status chips: ZoneTown → `"안전 지대"` (green); ZonePvP → `"PvP 지역"` (red); Rookie → `"새싹 보호중"`;
  Protected → `"부활 보호"`; `InCombatUntil > now` → `"전투 중"`; `SizeMult > 1.001` → `"덩치 저울 ×1.32"` (gold,
  2 decimals); `BullyStacks > 0` → `"깡패 N단계"` (red); `KaijuState == "Queued"` → `"괴수 대기 중"`.
- Quest rows (3 × 300×58), parsed from the last `Quests` remote payload (R1 CR-L50; connected synchronously in `Init`,
  accepts the JSON string, an array or `{ Quests = array }`; pcall `HttpService:JSONDecode`); fractional Progress shows one
  decimal and targets under 10000 show as integers (R1 CR-M27, CR-L31); header `"오늘의 퀘스트 (DailyClaims/3)"`
  (`"오늘 일일 완료! 추가 퀘스트 진행 중"` at 3). Each row: badge `"일일"` (gold) for Kind Daily / `"추가"` (gray) for Extra;
  text; bar `"12/40"`; reward `"+1.2K"`; right: completed Daily → green **받기** button → `ClaimQuest:FireServer(i)`;
  otherwise small `"↻"` → `RerollQuest:FireServer(i)` (disabled until `RerollReadyAt`).
- **Bottom-right buttons (exactly these 5):**
  **공격** round 160×160 (press = Swing once, hold = repeat every `Config.Classes[Class].SwingInterval` s);
  **발사** round 120×120 with a charge ring: inner fill rising with `Charge / ChargeCap`, center number `math.floor(Charge)`,
  dimmed while `< Config.Charge.MinRelease`; during the PERFECT window (`PerfectUntil > now`) a thick pulsing gold
  UIStroke ring + `"PERFECT!"` + remaining seconds → `Release:FireServer()`;
  **자동** 100×56 toggle `"자동 ON/OFF"` (`"Lv5 해금"` when locked) → `SetAutoAttack:FireServer(not AutoAttack)`;
  **업그레이드** 230×70 `"다음: <Config.WeaponName(tier+1, Class, Faction)> (800G)"` + progress bar `TotalGold / price`
  (`"최고 등급"` at max, `"Lv 12 필요"` if level short) → `UpgradeWeapon:FireServer()`;
  **메뉴** 100×56 → `C.Panels.Open("Menu")` (gold glow when `Level >= Config.RebirthLevel(Rebirths)` or `VacationDays > 0`).
- Travel bar (center) while `TravelingUntil > now`.
- R1 CR-L36 / CR-L37 (read by EventHUD, MainGui logical units, nil until the first layout): `HUD.TopCenterX`,
  `HUD.TopCenterW` (war-meter column: width clamped to 200..380 between the stats card and the luck corner) and
  `HUD.Layout = { W, H, Scale, ClusterTop, ClusterLeft, TopCenterX, TopCenterW }` (ClusterTop/Left = top / left edge of the
  bottom-right button cluster). Status chips wrap onto a second row instead of overflowing.
- Keys (ignore when `gameProcessedEvent`): ~~MouseButton1 / F = attack (hold repeats), Q or E = release, R = auto toggle,
  U = upgrade, M = menu.~~ → 2026-10-09: one press = one attack, holding never repeats (A22); default keys in `Config.Keybinds`
  (A23-78): F or left click attack, Z / X / C skills (X / C only while `Config.Skills.ZEnabled` / `XEnabled` are on; off until
  the 10/20 check, A23-86), R auto, T ghost hold, 1 / 2 potions, G interact, U next weapon, I bag, E hero, K skills,
  Q quest list, M map, L ranking, H help, B menu.
- Timers refresh in a 0.2 s loop; everything else is attribute-driven (`UIKit.OnAttr` / `OnGameAttr`).
- Hide everything except toasts while `C.FactionPicker.IsOpen()` or `C.ClassPicker.IsOpen()`.

**Fx** (`Fx.luau`, G11)
```
Fx.Play(kind: string, data: table)     -- also connected to Net.Get("Fx").OnClientEvent(kind, data)
Fx.PlaySound(name: string)             -- Config.Sounds[name]; pcall; SoundService:PlayLocalSound; ignore failures
Fx.ShowNumber(worldPos: Vector3, text: string, color: Color3, scale: number?)
Fx.Shake(magnitude: number, duration: number)   -- local camera shake (RenderStepped offset)
```
Kinds handled (unknown kinds ignored; events whose `Pos` is farther than `Config.Visuals.FxCullDistance` from the camera
are skipped). All visual parts are local, anchored, `CanCollide/CanQuery/CanTouch = false`, under a local folder in
`workspace.CurrentCamera`, cleaned up with `Debris`.
- `Swing`: by `Class` — Warrior: flat Neon ring at `Pos` expanding to `Radius` over 0.15 s in faction color; Mage: glowing
  Neon orb tweened `From` → `Targets[1]` (0.2 s), then a splash ring of `Radius` there; Archer: one thin arrow Part
  tweened `From` → each of `Targets` (0.15 s). Then numbers for each hit: `K == "M"` white (crits yellow & larger),
  `K == "P"` red, `K == "G"` small gold `"+N"` feather pop. Play `Swing` sound if own UserId. R1 CR-M23: in another
  player's Swing/Release, a `K == "P"` hit whose `V` equals my UserId is skipped (I already see it as my `Hurt` number).
- `Release`: class shape at `Pos` with radius `Radius` — Warrior: big shockwave ring + dust burst; Mage: meteor (Neon
  ball) falling from 60 studs above `Pos` in 0.35 s, then the ring; Archer: ~12 arrows raining inside the radius over 0.4 s,
  then the ring. Shockwave ring always sized exactly to `Radius`. Hit numbers as Swing, plus one HUGE number
  (`Total`, scale `HugeNumberScale`) above `Pos`; `Perfect` → gold `"PERFECT!"` text; `Auto` → smaller `"자동 발사"`.
  Shake: own → `Fx.Shake(ShakeOwnRelease, 0.35)`; others within `ShakeNearDistance` → `ShakeNearRelease`. Sound `Release`.
- `Hurt` (red number at own head + brief red screen-edge flash), `Reward` (`"+N G"` gold and `"+N XP"` blue at Pos;
  Golden → bigger gold burst; `Coin` sound; counts the combo), `LevelUp` (Neon light pillar 40 studs at Pos fading in 1 s;
  if own → `UIKit.Announce(UIKit.Fmt("LevelUp", Level))`), `Plunder` (8 small gold balls tween From → To), `Bank` (gold
  toast `"금고 +N"`; R1 CR-L23: `Courier == true` → `Config.Text.HaloCourier` instead — the only toast for it), `Upgrade` (sparkle at own character), `Rebirth` (big pillar + particles; `Mark == "Fall"` black
  smoke, `"Redeem"` white light), `Stomp` (red ground ring of `Radius` at Pos + `Fx.Shake(ShakeOwnRelease, 0.3)` if own
  character is within `Radius`), `Rare` (gold burst on own character + `UIKit.Announce(UIKit.Fmt("RareToast"))`),
  `GooseEnd` (feather burst at Pos, gold if Winner == "Halo", red if "Horns", white if "Tie").
- Damage numbers use a pool of `Config.Visuals.MaxDamagePopups` BillboardGuis on anchored invisible parts (local-only),
  rising 3 studs and fading over 0.8 s.
- Combo: count `Reward` events; reset after `Config.Combo.ResetSeconds` without one; show `"x12"` at bottom-centre
  (AnchorPoint 0.5, 0.5 at scale (0.5, 0.66), 120×24; R1 CR-L39 — was right-center) while ≥ 5; at each
  `Config.Combo.Milestones` value show its text big for 1 s, just above the combo label. Purely cosmetic.
- R1 CR-L15: another player's personal monster (`OwnerUserId` ≠ mine) is hidden locally (LocalTransparencyModifier = 1,
  effects disabled) and gets no flash / recoil / attack motion. R1 CR-L42: the flash and merge radii come from
  `Config.HitFeel.FlashRadius` / `MergeRadius`.

**EventHUD** (`EventHUD.luau`, G11)
```
EventHUD.Init(C) ; EventHUD.Start()     -- no other public functions
```
- Event strip: `GooseActive == false` → chip `"황금 거위까지 m:ss"` (`GooseNextAt - now`). `GooseActive == true` → tug-of-war
  bar 420×30: left gold `"구조 N"` (GooseRescue, floored), right red `"밀렵 N"` (GoosePoach), fill proportional (0.5 when
  both 0); center `"황금 거위 줄다리기! 0:42"` (`GooseEndsAt`); under it `"내 기여 N"` (own `GooseCount`) + hint
  (`"거위를 때려 구조하세요!"` for Halo / `"거위를 때려 밀렵하세요!"` for Horns). `KaijuPhase == "Active"` → extra red chip
  `"괴수 <KaijuName> m:ss"` (`KaijuEndsAt`) at the strip's right.
- Kaiju siren banner while `KaijuPhase == "Siren"`: full-width red flashing banner with
  `string.format(Config.Story.KaijuSiren, KaijuName)` and the remaining seconds.
- Screen-edge arrows (pooled, ≤ 10, updated on RenderStepped): if LocalPlayer is Halo → one purple arrow to every other
  player with `SackGold > 0` (label `"원한 자루 " .. FormatNumber(SackGold)`) and one red arrow to the Active kaiju
  (`KaijuUserId`, label `"괴수"`); any faction → orange arrow to `RevengeTargetId` while `RevengeUntil > now` (label `"복수"`).
  Project the target's HumanoidRootPart with `Camera:WorldToViewportPoint`: on-screen → small marker above the target;
  off-screen or behind → clamp to the screen edge (40 px margin) rotated toward the target.
- Personal line (first that applies): own `SackGold > 0` → `"원한 자루 1.2K · 34초 (PvP 지역에서만 줄어요)"` (purple);
  own `KaijuState == "Active"` → `"괴수 변신 중! m:ss 버티면 전설의 악당"` (red); own revenge active →
  `"복수 대상: <name> · 0:42"` (orange).
- R1 CR-L36 / CR-L37 / CR-L43: the strip is centred on `HUD.TopCenterX` with width clamp(`HUD.TopCenterW`, 200, 360)
  (fallback: the live war-meter frame, then screen centre); the personal line uses ZIndex 6, width min(480, W − 24) and,
  on desktop, y = min(0.72 H, `HUD.Layout.ClusterTop` − 8 − h/2) when it would otherwise reach under the button cluster;
  edge arrows stay below the top-bar inset.
- Lore hint: the first time in a session that a sack-carrier arrow appears for a Halo player →
  `UIKit.Toast(string.format(Config.Story.SackLore), "info", 4)`.
- Luck corner (A23-18: now `"오늘의 운 · 희귀 X%"` from `LuckEvents`; the next line is history): `"단골 " .. RegularMinutes .. "분 · 희귀 " .. Util.FormatPercent(Config.RareChance(RegularMinutes)) .. "%"`
  and below `"응원별 ★★★☆☆ (" .. CheerStars .. "/5)"`.
- Hidden while `C.FactionPicker.IsOpen()` or `C.ClassPicker.IsOpen()`.

**Panels** (`Panels.luau`, G12)

> 2026-10-09 검수: 아래 Menu·Shop 칸 목록은 낡음. [Menu]는 오른쪽 위에서 칸이 펼쳐지고(A23-38·A23-40), 직업 바꾸기·환생·오프닝 다시 보기·이름 숨기기·휴가·키 설정은 설정 창 안에 있다(A23-46). "Shop"은 ShopUI의 게임 패스 창이다(A23-75). 다른 창은 `Panels.Register(id, opts)`로 붙는다(BB13).

```
Panels.Open(id: "Menu" | "Travel" | "Rebirth" | "Altar" | "Class" | "Shop" | "Vacation") ; Panels.Close() ; Panels.IsOpen() -> boolean
```
Modal (dim background, close "X", one panel at a time). `Start` connects `Net.Get("OpenPanel").OnClientEvent(id)` → `Open(id)`.
Every irreversible choice goes through `UIKit.Confirm`.
- **Menu**: big buttons (2 columns, 200×70): 이동 → Travel; 환생 (glows when Level ≥ `Config.RebirthLevel(Rebirths)`) →
  Rebirth; 직업 변경 → Class; 변경권 상점 → Shop; 휴가 보너스 (only while `VacationDays > 0`) → Vacation. Footer:
  `"진영 변경은 교차로 마을의 운명의 제단에서!"` and `Config.Story.MarkLore`.
- **Travel**: one row per `Config.Travel.Destinations` (name, `"Lv N+"`, `"PvP"`/`"안전"`); disabled if Level < MinLevel,
  (Home and Faction == "None"), `SackGold > 0` or `KaijuState` is Siren/Active (show the reason); click →
  `Travel:FireServer(id)` and close.
- **Rebirth** (turncoat): `Config.Story.RebirthIntro`; rebirth count; required level; `"빛 n명 : 뿔 m명"` from
  `HaloCount`/`HornsCount`; two big buttons **[빛의 기사단] [뿔 군단]**, each showing its bonus from
  `Config.RebirthBonusFor(countOthers, totalOthers)` (counts minus 1 for my current faction): `"+25%"` or
  `"+40%! (인원이 적은 편)"`; on the side that differs from my faction the mark preview (`Config.Story.Fall` when Halo →
  Horns, `Config.Story.Redeem` when Horns → Halo, via `string.format`); lines ~~`"초기화: 레벨, 골드, 무기"`~~ (→ only the level
  resets; gold, weapons and items stay, A23-14; English text, A23-48),
  `"유지: 직업, 명예·악명, 환생 보너스, 표식, 변경권"`. Enabled when Level is enough → Confirm → `Rebirth:FireServer(factionId)`.
- **Altar** (faction change): current → other faction (other's `Perks` + `FactionLore`). Two option cards side by side:
  **[무료]** `"<명예|악명> N → 0 (배신의 대가)"` (the score of the faction being LEFT: Honor when leaving Halo, Infamy when
  leaving Horns) and **[변경권 1장]** `"명예·악명 모두 그대로"` + `"보유: N장"` (`FactionTickets`) + **[로벅스로 구매]**
  (FactionTicket). Rules: `"현상수배 별 0개 · 원한 자루 없음 · 괴수 아님 · 전투 중 아님"`, `"진영 변경은 10분에 한 번"`.
  Cooldown from `LastSwitchTime + Config.Switch.Cooldown` vs `Util.Now()` disables both options (`"m:ss 후 가능"`).
  Ticket option disabled at 0 tickets (buy button stays). Option → Confirm → `SwitchFaction:FireServer(useTicket)`.
- **Class** (class change): 3 cards (`Config.ClassName(id, Faction)`, `Desc`, `Stats`, current marked `"현재"`). Picking a
  different card shows two options: **[무료]** `"Lv N → Lv 1 (골드·무기·환생 보너스는 그대로)"` and **[변경권 1장]**
  `"레벨 그대로"` + `"보유: N장"` (`ClassTickets`) + **[로벅스로 구매]** (ClassTicket). Disabled with the reason while
  `ZonePvP` (`"안전 지대에서만 바꿀 수 있어요"`), `SackGold > 0` or `KaijuState ~= "None"`. Option → Confirm →
  `ChangeClass:FireServer(classId, useTicket)`.
- **Shop**: rows `"직업 변경권 — 보유 N장"` / `"진영 변경권 — 보유 N장"`, each with a buy button; note
  `"변경권은 능력치가 아니에요. 진행도를 지키는 선택권이에요. 무료로도 언제든 바꿀 수 있어요!"`.
- **Vacation**: `"휴가 보너스! N일 동안 못 왔지만 괜찮아요."` + gold/XP (`VacationDays`, `VacationGold`, `VacationXP`) +
  **받기** → `ClaimVacation:FireServer()` → close. Opens automatically once per session, 2 s after both pickers are closed,
  when `VacationDays > 0`; also from the Menu.
- Purchase helper (private `buy(kind)`): `p = Config.ProductByKind(kind)`; `p.Id ~= 0` →
  `MarketplaceService:PromptProductPurchase(Players.LocalPlayer, p.Id)`; else `UIKit.Toast(UIKit.Fmt("ProductNotReady"), "info")`.
  Button label: `"상품 준비 중"` when Id == 0, else `"로벅스로 구매 (" .. p.PriceHint .. " R$)"`. Ticket counts update live
  from attributes (the server toast confirms the purchase).

**FactionPicker** (`FactionPicker.luau`, G12)

> 2026-10-09 검수: 진영을 고르기 전에 3D 오프닝 `Intro.luau`(자체 `IsOpen()`, 처음 한 번, 건너뛰기, A23-9)가 먼저 나온다. 카드는 빛·뿔 2장(A23-57), 글은 영어(A23-48)다. 직업을 고른 뒤 옛 `Config.Story.Intro` 토스트는 비어 있고 서버가 `Config.Tutorial.Welcome`을 연다; 그 뒤 대장간까지 걸어가 첫 무기를 받는다(A23-34·A23-74·A23-88).

```
FactionPicker.IsOpen() -> boolean
```
Visible exactly when `DataLoaded == true` and `Faction == "None"`. Full-screen dim; the 3 `Config.Story.Premise` lines at the
top (fading in 0.6 s apart; never blocking the buttons); title `"어느 편에 설래요?"`; two cards (Halo left, Horns right):
big `Emblem`, `Name`, `FactionLore`, `Pitch`, the `Perks`, button `"이 편으로!"` → `ChooseFaction:FireServer(id)` (buttons
disabled for 2 s after a click). Card badge when GameState `WeakerFaction == id`: `"약한 편 합류! 시작 골드 +300 · 덩치 저울로 더 커져요"`.
Footer: `"나중에 교차로 마을의 운명의 제단에서 바꿀 수 있어요 (무료 또는 변경권)"`.

**ClassPicker** (`ClassPicker.luau`, G12)
```
ClassPicker.IsOpen() -> boolean
```
Visible exactly when `DataLoaded == true`, `Faction ~= "None"`, `ClassChosen == false` and `C.FactionPicker.IsOpen()` is
false. Title `"어떤 직업으로 싸울까요?"`; 3 big cards in `Config.ClassOrder`: `Config.ClassName(id, Faction)`, `Desc`,
`Stats`, starting weapon `Config.WeaponName(1, id, Faction)`; button `"이 직업으로!"` → `ChooseClass:FireServer(id)`
(disabled 2 s). Footer `"나중에 메뉴 > 직업 변경에서 바꿀 수 있어요 (무료: 레벨 1부터 / 변경권: 레벨 유지)"`.
Intro: when `ClassChosen` flips false → true during this session and `Level <= 1`, show `Config.Story.Intro` lines as
`UIKit.Toast(line, "info", 4)` 3 s apart (auto-dismiss, never blocking).

---

## 5. Remotes (all `RemoteEvent`, in `ReplicatedStorage.Remotes`, created by `Net.CreateAll()`)

> 2026-10-09 검수: 아래 표는 10/02의 16개(+ R1의 `Quests`)만 담아서 낡음 — 지금은 52개이고 목록과 인자 설명은 `src/ReplicatedStorage/Shared/Net.luau`의 `Net.Names` 주석이 정답이다(아직 RemoteFunction은 없다). 바뀐 줄: `Release` = 첫 스킬 칸(충전 조건 없음, A22·A23-49), `SetAutoAttack` = `AutoCombatUnlocked` 필요(레벨 조건 아님, A23-1·A23-71), `UpgradeWeapon(tier)`·`SellWeapon(tier)`(A23-4), `ChooseFaction`은 `NeutralFaction` 스위치가 켜질 때만 "Neutral"도 받는다(A23-57). 게임 패스 구매는 `PromptGamePassPurchase` → 서버 소유 확인(A23-75). Fx 종류도 늘었다(코드의 `Net.Fx` 호출 참고).

There are **no RemoteFunctions**. Clients never send numbers that the server trusts (only ids, booleans and a slot index).
Purchases go through Roblox (`PromptProductPurchase` → `ProcessReceipt`), never through a remote.

| Name | Direction | Payload | Server owner | Validation (in order, after `IsReady`) |
|---|---|---|---|---|
| `ChooseFaction` | C→S | `factionId: string` | FactionService | ∈ {"Halo","Horns"}; rate 1 s; current Faction == "None" |
| `ChooseClass` | C→S | `classId: string` | ClassService | valid class id; rate 1 s; `ClassChosen == false`; Faction ≠ "None" |
| `Swing` | C→S | none | CombatService | rate 0.1 s; alive; class `SwingInterval` (silently ignored if early) |
| `Release` | C→S | none | CombatService | rate 0.25 s; alive; `floor(Charge) >= 10` |
| `SetAutoAttack` | C→S | `enabled: boolean` | CombatService | boolean; rate 0.25 s; Level ≥ 5 to enable |
| `UpgradeWeapon` | C→S | none | ShopService | rate 0.3 s; tier < 7; Level ≥ next MinLevel; faction for tier 7; enough gold |
| `Rebirth` | C→S | `factionId: string` | ProgressionService | ∈ {"Halo","Horns"}; rate 1 s; Level ≥ `RebirthLevel`; 0 stars; no sack; kaiju "None"; not in combat |
| `SwitchFaction` | C→S | `useTicket: boolean` | FactionService | boolean; rate 1 s; faction ≠ None; ≤ 20 studs from Altar; no sack; kaiju "None"; 0 stars; not in combat; 10-min altar cooldown; a ticket if `useTicket` |
| `ChangeClass` | C→S | `classId: string, useTicket: boolean` | ClassService | valid id + boolean; rate 1 s; `ClassChosen`; different class; alive; not in a PvP zone; no sack; kaiju "None"; a ticket if `useTicket` (no cooldown) |
| `Travel` | C→S | `destId: string` | ZoneService | string; rate 0.5 s; known destination; alive; level gate; not kaiju (Siren/Active); no sack; stars < 3; not in combat; not already traveling |
| `RerollQuest` | C→S | `slot: number` | QuestService | integer 1..3; rate 0.5 s; `RerollReadyAt` passed; slot not complete |
| `ClaimQuest` | C→S | `slot: number` | QuestService | integer 1..3; rate 0.3 s; slot is a completed Daily |
| `ClaimVacation` | C→S | none | QuestService | rate 1 s; `VacationDays > 0` |
| `Notify` | S→C | `{ Text: string, Kind: "info"\|"good"\|"bad"\|"reward"\|"announce", Duration: number? }` | `Net.Notify/NotifyAll` | — |
| `Fx` | S→C | `(kind: string, data: table)` — see table below | `Net.Fx` | — |
| `OpenPanel` | S→C | `panelId: "Altar"` | FactionService | — |
| `Quests` | S→C | `{ Quests = { entry, … } (the quest entries, §4.20), Book = { Available = { { Id, Kind, Level?, Text? } }, Done = { "story:<id>" } } }` (A23-81, 2026-10-08; older servers sent the JSON string of the entries — clients read both) | QuestService (+ StoryQuestService.BookRows) | — (R1 CR-L50: fired to the owner only when the rows or the book change; replaces the `QuestsJson` attribute) |

`Fx` kinds (sender → recipients → data):

| kind | Sender | Recipients | data |
|---|---|---|---|
| `Swing` | CombatService | attacker + players near the centre (R1 CR-L49) | `{ UserId, Class, Faction, From: Vector3, Pos: Vector3, Radius: number, Targets: { Vector3 }, Hits = { { P: Vector3, A: number, C: boolean, K: "M"\|"P"\|"G", V: number? } } }` (V = victim UserId on P hits, R1 CR-M23) |
| `Release` | CombatService | attacker + players near the centre (R1 CR-L49) | `{ UserId, Class, Faction, Pos: Vector3, Radius, Stacks, Perfect: boolean, Auto: boolean, Total: number, Hits = (same as Swing) }` |
| `Hurt` | CombatService | victim, whenever HP was actually removed (R1 CR-M23) | `{ Pos: Vector3, Amount: number }` |
| `Reward` | ProgressionService | earner | `{ Pos: Vector3, Gold: number, XP: number, Golden: boolean }` |
| `LevelUp` | ProgressionService | all | `{ UserId, Level, Pos }` |
| `Rebirth` | ProgressionService | all | `{ UserId, Rebirths, Pos, Mark: "Fall"\|"Redeem"\|"None" }` |
| `Bank` | ProgressionService | owner | `{ Amount, Courier: boolean? }` (Courier = Halo auto-bank, R1 CR-L23) |
| `Plunder` | PvPService (all), GrudgeService (refunded victim) | all / victim | `{ From: Vector3, To: Vector3, Amount }` |
| `Upgrade` | ShopService | buyer | `{ Tier }` |
| `Stomp` | KaijuService | all | `{ UserId, Pos: Vector3, Radius }` |
| `Rare` | GooseService | the lucky player | `{ Gold, XP }` |
| `GooseEnd` | GooseService | all | `{ Pos: Vector3, Winner: "Halo"\|"Horns"\|"Tie" }` |

---

## 6. Player data schema & attributes

### 6.1 Persisted data (DataStore `HaloHorns_Player_v1`, key `P_<UserId>`, ~~`Version = 2`~~ `Version = 3`)

> 2026-10-09 검수: 아래 표는 10/02 필드만 있다. 지금 기본값 전체는 `Config.Data.Defaults`(Config.luau의 `Config.Data` 표 + 뒤쪽에서 덧붙이는 `Config.Data.Defaults.<키>`)가 정답이다. 새 필드 예: `WeaponOwnedMask`·`BlacksmithVisited`(A23-4), `Items`·`WeaponEnhance`·`LootFlags`(A23-12), `ItemSeq`·`WeaponSeq`(A23-32 가방 정렬), `HPPotionCount`·`MPPotionCount`(A18), `Nickname`(A21), `TutorialStep`·`TutorialKills`(A4), `IntroSeen`(A23-9), `AutoCombatUnlocked`·`AutoCombatEnabled`(A23-1), `Story`(이야기 퀘스트), `LuckDay`·`LuckEvents`(A23-18), `Titles`·`TitleSel`(BB16), `Settings`(BB2, V4), `Telemetry`, `Rank`·`RankReward`·`Outlaw`(A23-23·A23-24), `SkillSlots`·`SkillsA71`(A23-49·A23-71), `Stats`(A23-69), `Looks`·`PassSeen`(A23-75), `Pets`·`TamerNotice`(A23-39·PET-2), `Attendance`(A23-77), `Return`·`Diary`·`Invite`(A23-79), `Deeds`·`Cards`(A23-86), `FieldBoss`, `KillLog`.

| Key | Type | Default | Written by (through PlayerService.SetStat/AddStat unless noted) |
|---|---|---|---|
| `Version` | number | ~~2~~ 3 | DataService (migration v1 → v2 → v3, §4.4) |
| `Level` | number | 1 | ProgressionService (AddXP, ResetLevel, rebirth) |
| `XP` | number | 0 | ProgressionService |
| `BankGold` | number | 0 | ProgressionService |
| `CarriedGold` | number | 0 | ProgressionService (banked on join and on leave) |
| `WeaponTier` | number ~~1..7~~ 0..8 (0 = bare hands) | ~~1~~ 0 (A23-34) | ShopService, LootService (equip / first weapon / level fix), CommissionService; ~~ProgressionService (rebirth reset)~~ kept through rebirth (A23-14). **v1 name `SwordTier`** (migrated) |
| `Faction` | "Halo"/"Horns"/"None" | "None" | FactionService.SetFaction only |
| `Class` | "Warrior"/"Mage"/"Archer" | "Warrior" | ClassService |
| `ClassChosen` | boolean | false (also false after migration) | ClassService |
| `Rebirths` | number | 0 | ProgressionService |
| `RebirthBonus` | number | 0 (v1: Rebirths × 0.25) | ProgressionService |
| `FallMarks` | number 0..5 | 0 | ProgressionService |
| `RedeemMarks` | number 0..5 | 0 | ProgressionService |
| `Honor` | number | 0 | PvPService (+), FactionService (reset on a free switch away from Halo) |
| `Infamy` | number | 0 | PvPService (+ when no sack), GrudgeService (sack payout), FactionService (reset on a free switch away from Horns) |
| `SwitchCount` | number | 0 | FactionService |
| `LastSwitchTime` | number (os.time) | 0 | FactionService (altar only) |
| `PlaytimeSeconds` | number | 0 | PlayerService |
| `TotalKills` | number | 0 | ProgressionService |
| `Quests` | array of Quest (§4.20) | {} | QuestService (direct table mutation; not mirrored) |
| `DailyDay` | number | 0 | QuestService |
| `DailyClaims` | number 0..3 | 0 | QuestService |
| `VacationDays` / `VacationGold` / `VacationXP` | number | 0 | QuestService (pending vacation reward) |
| `CheerStars` | number 0..5 | 0 | GooseService |
| `Tickets` | `{ Class: number, Faction: number }` | `{0, 0}` | MonetizationService (direct; mirrored as `ClassTickets`/`FactionTickets`) |
| `ProcessedReceipts` | array of PurchaseId strings (≤ 50) | {} | MonetizationService (direct; not mirrored) |
| `FirstJoinTime` | number (os.time) | 0 → set on first load | DataService |
| `LastLogoutTime` | number (os.time) | 0 | DataService (on Release) |
| `SessionLock` | `{ JobId, Time }` | — | DataService only; stored in DataStore, never in the session table |
| `PairCD` | `{ ["<kind>:<otherUserId>"] = os.time() }` (`kolog:*` = `{ t1, t2 }`) | {} | R1 CR-M4: PlayerService.PairReady + PvP/Grudge/Kaiju (direct; not mirrored; pruned on join) — A16-2 |
| `SavedBully` / `SavedBullyAt` | number / number (os.time) | 0 | R1 CR-M12: JusticeService (PlayerLeaving write, PlayerReady read + zero; not mirrored) |
| `SavedStars` / `SavedStarsAt` | number / number (os.time) | 0 | R1 CR-M12: PvPService (same), KaijuService zeroes it for a defeated leaver |

Session-only (never saved): Wanted stars, bounty, grudge sacks, revenge, bully stacks, charge stacks, war points, buffs,
cooldowns, protection, regular minutes, goose counts, kaiju state and session title. (R1: bully stacks and wanted stars
now survive a rejoin through `SavedBully` / `SavedStars`, minus the decay while away; pair cooldowns are saved in `PairCD`.)

### 6.2 Player attributes (server writes, client reads)

> 2026-10-09 검수: 이 표는 10/02 것이다. `RegularMinutes`는 없어졌다(A23-18). `Charge`·`ChargeCap`·`PerfectUntil`은 호환용으로 늘 0이고 `AutoAttack`은 늘 false인 옛 속성이다 — 자동 전투 상태는 저장 미러 `AutoCombatUnlocked`·`AutoCombatEnabled`(A23-1). 새 속성 예: `CombatPower`(BB4), `SkillSlots`(A23-49), `PassXP2`·`PassGold2`·`PassVIP`·`LooksOwned`·`LookOn`(A23-75), `Outlaw`(A23-23), `SaveLoading`(A23-48 묶음). 코드가 정답이다.

| Attribute | Type | Writer | Meaning |
|---|---|---|---|
| all keys of `Config.Data.Mirrored` | as §6.1 | PlayerService.SetStat (called by owners) | mirrors of persisted data |
| `DataLoaded` | boolean | PlayerService | true once data is loaded |
| `RegularMinutes` | number | PlayerService | active minutes on this server (Regular's Luck) |
| `ClassTickets`, `FactionTickets` | number | MonetizationService | ticket counts |
| ~~`QuestsJson`~~ | — | — | removed in R1 CR-L50 (it replicated to every player); the list now comes through the `Quests` remote |
| `RerollReadyAt` | number (server time) | QuestService | quest reroll available at |
| `ZoneId` / `ZonePvP` / `ZoneTown` | string / boolean / boolean | ZoneService | current zone |
| `TravelingUntil` | number (server time, 0 = no) | ZoneService | travel channel end |
| `AutoAttack` | boolean | CombatService | auto attack on |
| `InCombatUntil` | number (server time) | CombatService | PvP combat tag end |
| `Charge` | number (may be fractional) | CombatService | charge stacks (display `math.floor`) |
| `ChargeCap` | number | CombatService | 150 Halo / 175 Horns / 150 None |
| `PerfectUntil` | number (server time, 0 = no) | CombatService | PERFECT window end |
| `WantedStars` | number 0..5 | PvPService | Wanted stars |
| `Bounty` | number | PvPService | `Config.Bounty(Level, stars, BullyStacks)` (0 if none) |
| `Rookie` | boolean | PvPService | newbie PvP shield |
| `Protected` | boolean | PvPService | spawn / post-kaiju shield active |
| `RevengeTargetId` | number (UserId, 0 = none) | PvPService | who I may take revenge on |
| `RevengeUntil` | number (server time) | PvPService | revenge window end |
| `SizeMult` | number | JusticeService | my faction's Size Justice S |
| `BullyStacks` | number 0..3 | JusticeService | bully shrink stacks ("깡패") |
| `VisualScale` | number | JusticeService | currently applied character scale |
| `SackGold` | number | GrudgeService | gold in my grudge sack (0 = no sack) |
| `SackSeconds` | number | GrudgeService | sack countdown (ticks only in PvP zones) |
| `SackVictimName` | string | GrudgeService | latest victim (shown on the ghost) |
| `KaijuState` | "None"/"Queued"/"Siren"/"Active" | KaijuService | my kaiju state |
| `SessionTitle` | string ("" = none) | KaijuService | e.g. "전설의 악당" (this session only) |
| `GooseCount` | number | GooseService | my counted goose hits this event |
| `WarPoints` | number | WarService | personal war points this round |

"server time" = `Util.Now()` = `workspace:GetServerTimeNow()`.

### 6.3 GameState attributes (`ReplicatedStorage.GameState`)

> 2026-10-09 검수: 이 표 뒤로 더 생겼다 — `Net.GameStateDefaults`가 정답이다(예: `SupporterNames`(A23-75), `Switch*`(SwitchService), `GooseMode`·`GooseCoop*`(A23-14 함께 구조), `PumpkinKing*`·`GhostKing*`(HalloweenService), `SlimeKing*`·`Clatter*`(FieldBossService), `RankWeekId`·`RankWeekEndsAt`(A23-23), `SaveOK`).

| Attribute | Type | Writer | Meaning |
|---|---|---|---|
| `WarHaloScore`, `WarHornsScore` | number | WarService | per-capita round score (0.1 precision; R1 CR-M19: divided by the round-average head count) |
| `WarRoundEndsAt` | number (server time) | WarService | round end |
| `WarMode` | "Normal"/"Siege"/"Idle" | WarService | round mode |
| `WarBlessing` | "Halo"/"Horns"/"None" | WarService | faction holding the crown this round |
| `HaloCount`, `HornsCount` | number | FactionService | players per faction |
| `UnderdogHalo`, `UnderdogHorns` | number | FactionService | R1 CR-L7: counts for the rebirth underdog bonus (no rookies, no > 120 s idlers) |
| `HaloPower`, `HornsPower` | number | JusticeService | faction base-power sums |
| `HaloSize`, `HornsSize` | number | JusticeService | Size Justice S per faction (1.0..1.6) |
| `WeakerFaction` | "Halo"/"Horns"/"None" | JusticeService | lower power sum (sign-on bonus target) |
| `GooseNextAt` | number (server time) | GooseService | next golden goose start |
| `GooseActive` | boolean | GooseService | goose event running |
| `GooseEndsAt` | number (server time, 0 = none) | GooseService | current goose end |
| `GooseRescue`, `GoosePoach` | number | GooseService | tug totals (Halo / Horns) |
| `KaijuPhase` | "None"/"Siren"/"Active" | KaijuService | server kaiju phase |
| `KaijuUserId` | number (0 = none) | KaijuService | current kaiju |
| `KaijuName` | string | KaijuService | current kaiju display name |
| `KaijuEndsAt` | number (server time) | KaijuService | end of siren (Siren) or of the kaiju (Active) |

### 6.4 Workspace instances other files may rely on
- `workspace.Map.Landmarks.Altar` (+ `AltarPrompt`), `workspace.Map.Landmarks.MostWantedBoard.BoardGui.BoardText`,
  `workspace.Map.Landmarks.GoosePerch`, `workspace.Map.Pads.Pad_<ZoneId>` (attribute `TravelTo`) — MapBuilder.
- `workspace.Monsters` (monster models with attributes `MonsterKind`, `Golden`) — MonsterService.
- `workspace.Effects` — shared server effect folder (anyone may parent temporary server effects; use `Debris`);
  `workspace.Effects.GoldenGoose` while a goose is active — GooseService.
- On characters: `Nametag`, `FactionMark`, `WeaponModel`, `GoldSack`, `GrudgeSack`, `GrudgeGhost`, `RebirthAura`,
  `MarkCape`, `MarkHalo`, `GrayAura`, `WantedGlow`, `KaijuFire` (CharacterVisuals); `ForceField` (PvPService);
  character scale (JusticeService via `Model:ScaleTo`).
- `Lighting.WarTint` ColorCorrectionEffect — WarService. `leaderstats` folder — PlayerService. `Teams` — FactionService.

---

## 7. Startup / initialization order

> 2026-10-09 검수: §7.1·§7.2의 "exact code"는 10/02 사본이라 낡음 — 서비스 19개·모듈 7개 목록이 아니라 지금은 `Main.server.luau`의 INIT_ORDER/START_ORDER(서비스 48개, PlayerService가 맨 끝에 Start)와 `ClientMain.client.luau`의 ORDER(37개, 맨 앞에서 모든 GUI의 AutoLocalize를 끔 — 영어만, A23-48)가 정답이다. 모듈을 지울 때는 이 목록과 모든 require에서 먼저 뺀다(AGENTS.md). DebugCommand 키도 늘었다(Main 주석). 흐름(§7.3)은 그대로지만 진영 고르기 전 3D 오프닝(A23-9)과 대장간까지 걷기(A23-88)가 들어갔다.

### 7.1 Server — `ServerScriptService/Main.server.luau` (G2, exact code)
```lua
-- Main.server.luau : the ONLY server entry point.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
Net.CreateAll() -- remotes + GameState folder exist before anything else runs

local INIT_ORDER = {
	"DataService", "PlayerService", "MonetizationService", "MapBuilder", "ZoneService", "FactionService",
	"ClassService", "JusticeService", "ProgressionService", "CombatService", "MonsterService", "PvPService",
	"GrudgeService", "WarService", "KaijuService", "GooseService", "ShopService", "QuestService", "CharacterVisuals",
}
-- WarService starts before GooseService (goose schedule reads the round end).
-- PlayerService starts LAST so every service is ready before the first player is processed.
local START_ORDER = {
	"MapBuilder", "ZoneService", "FactionService", "ClassService", "JusticeService", "ProgressionService",
	"CombatService", "MonsterService", "PvPService", "GrudgeService", "WarService", "KaijuService", "GooseService",
	"ShopService", "QuestService", "MonetizationService", "CharacterVisuals", "DataService", "PlayerService",
}

local S = {}
for _, name in INIT_ORDER do
	local module = ServerScriptService:WaitForChild(name)
	local ok, result = pcall(require, module)
	if not ok then
		error(("[Main] failed to require %s: %s"):format(name, tostring(result)))
	end
	S[name] = result
end

for _, name in INIT_ORDER do
	local ok, err = pcall(S[name].Init, S)
	if not ok then
		warn(("[Main] %s.Init failed: %s"):format(name, tostring(err)))
	end
end

local started = 0
for _, name in START_ORDER do
	local ok, err = pcall(S[name].Start)
	if ok then
		started += 1
	else
		warn(("[Main] %s.Start failed: %s"):format(name, tostring(err)))
	end
end

-- Studio-only debug hook for the test checklist (Command Bar, server side):
--   game.ServerScriptService.DebugCommand:Invoke("Player1", "Level", 20)
--   game.ServerScriptService.DebugCommand:Invoke("Player1", "Gold", 5000)   -- adds carried gold
--   keys: Gold, Stars, Bully, Tickets, Absent, Goose, Faction, any mirrored stat (Level, PlaytimeSeconds, Class, ...)
if game:GetService("RunService"):IsStudio() then
	local debugFn = Instance.new("BindableFunction")
	debugFn.Name = "DebugCommand"
	debugFn.OnInvoke = function(playerName, key, value)
		local player = game:GetService("Players"):FindFirstChild(playerName)
		if not player or not S.PlayerService.IsReady(player) then return "no such ready player" end
		if key == "Gold" then
			S.ProgressionService.AddCarriedGold(player, value, "Other")
		elseif key == "Stars" then
			S.PvPService.DebugSetStars(player, value)
		elseif key == "Bully" then
			for _ = 1, value do S.JusticeService.AddBullyStack(player) end
		elseif key == "Tickets" then
			S.MonetizationService.AddTickets(player, "Class", value)
			S.MonetizationService.AddTickets(player, "Faction", value)
		elseif key == "Absent" then
			S.QuestService.DebugSimulateAbsence(player, value)
		elseif key == "Goose" then
			S.GooseService.DebugStart()
		elseif key == "Faction" then
			S.FactionService.SetFaction(player, value, "Choose")
			S.PlayerService.RefreshCharacter(player, true)
		else
			S.PlayerService.SetStat(player, key, value)
			if key == "Level" or key == "Class" then S.PlayerService.RefreshCharacter(player, true) end
		end
		return "ok"
	end
	debugFn.Parent = ServerScriptService
end

print(("[Main] Halo & Horns server started (%d/%d services)"):format(started, #START_ORDER))
```

### 7.2 Client — `StarterPlayerScripts/ClientMain.client.luau` (G10, exact code)
```lua
-- ClientMain.client.luau : the ONLY client entry point.
local ORDER = { "UIKit", "Fx", "HUD", "EventHUD", "Panels", "FactionPicker", "ClassPicker" }

local C = {}
for _, name in ORDER do
	C[name] = require(script.Parent:WaitForChild(name))
end
for _, name in ORDER do
	local ok, err = pcall(C[name].Init, C)
	if not ok then
		warn(("[ClientMain] %s.Init failed: %s"):format(name, tostring(err)))
	end
end
for _, name in ORDER do
	local ok, err = pcall(C[name].Start)
	if not ok then
		warn(("[ClientMain] %s.Start failed: %s"):format(name, tostring(err)))
	end
end
print("[ClientMain] client started")
```
Client `Init` may only create instances/state; cross-module calls (`C.Panels.Open`, `C.Fx.PlaySound`,
`C.FactionPicker.IsOpen`, `C.ClassPicker.IsOpen`) are allowed only from `Start` onward or from event handlers.

### 7.3 Join timeline (what happens for one player)
1. `PlayerAdded` → `DataService.Load` (yields; memory mode in Studio without API access; v1 data migrated to v2, then v3).
2. Attributes mirrored, `leaderstats` created, `DataLoaded = true`, `PlayerReady` fired → Faction / Class / Justice /
   Zone / Progression / Combat / PvP / War / Quest (day check → dailies or vacation) / Monetization / Visuals initialize
   their per-player state and attributes; Justice schedules a recompute.
3. `LoadCharacter` → `CharacterAdded`: MaxHealth/WalkSpeed applied, pivot to the home town (Crossroads if no faction) →
   `CharacterSpawned` → spawn protection (PvP), accessories (Visuals), scale snap (Justice), zone recompute (Zone).
4. Client: (first time only: the 3D opening `Intro`, A23-9) → FactionPicker opens if `Faction == "None"` → `ChooseFaction` → team set, respawn in the faction town →
   ClassPicker opens if `ClassChosen == false` → `ChooseClass` → ~~intro toasts (new players)~~ the guide's Welcome dialogue
   (`Config.Tutorial.Welcome`), then the player walks to Otto's Forge for the first weapon (A23-34, A23-74, A23-88) → Vacation popup if pending.

---

## 8. Test checklist (Studio)

> 2026-10-09 검수: 이 목록은 10/02 MVP 기준이라 많이 낡음 — 서비스 19/모듈 7/원격 16 개수, 충전·발사·PERFECT·자동 발사, Lv5 자동 해금, "업그레이드 = 다음 티어", 한국어 목록 이름("레벨/골드/환생/명성"), 변경권 구매 확인, 단골 운은 지금과 다르다(A22·A23-1·A23-4·A23-18·A23-28·A23-48). 지금 "끝"의 기준은 메인 Studio Play 사진(UI는 PC 먼저, A23-74·A23-98)이고, sync·Play는 메인 반영 1이 한다(`docs/handoff/role_prompts/01_mainapply.md`). 오프라인 시험은 `py tools/luau_check.py`와 각 기능의 시험 도구로 본다. 아래 항목 중 PvP·원한 자루·괴수·거위·전쟁 같은 남은 시스템 확인은 참고로 쓸 수 있다.

The lead builds and syncs (implementers only run `py tools/luau_check.py <their files>`). Single-player tests with
**Play**; PvP tests with **Test > Start Server + 2 Players**. Watch the Output: no errors at startup.
R1 fixes: also run the per-item checks in `docs/review/reviewer_code_r1.md` ("플레이테스트로 확인할 것"). While
`Config.AntiCheat.Enforce` is false, CR-H2 is checked by reading the `[ZoneService] CR-H2 suspicious move (..., log only)`
warnings in the Output (expected for a command-bar teleport, never for menu travel, respawn or a fall rescue), not by being pulled back.

Startup & data
- [ ] Output shows one `[<ServiceName>] started` line for each of the 19 services, then
      `[Main] Halo & Horns server started (19/19 services)`; each client shows 7 module lines + `[ClientMain] client started`.
- [ ] `ReplicatedStorage.Remotes` has exactly the 16 remotes; `GameState` has every attribute of §6.3.
- [ ] With API access OFF: one memory-mode warning, game fully playable. With API access ON: progress, stop, play again →
      Level, BankGold, WeaponTier, Faction, Class, Honor/Infamy, RebirthBonus, marks, tickets, quests, CheerStars restored.
- [ ] A v1 save (has `SwordTier`, no `Class`) loads as v2: `WeaponTier` = old SwordTier, `RebirthBonus = Rebirths × 0.25`,
      ClassPicker shows once and keeps the level; Output shows `[DataService] migrated v1 -> v2 for <name>`.
- [ ] Leaving with carried gold → it appears in BankGold next session (minus 25% if you left within 15 s of PvP damage).
- [ ] Player list shows 레벨 / 골드 / 환생 / 명성 and updates live.

World & movement
- [ ] Map builds (6 zone floors, walls, altar, board, 3 pads, 5 gate signs with lore line, goose perch). Pre-bake test:
      in edit mode run `require(game.ServerScriptService.MapBuilder).Build()`, then Play → Output says `reused workspace.Map`
      and pads/altar/board still work; delete `Landmarks.Altar` in edit mode → Play rebuilds only it.
- [ ] New player: faction picker (premise lines) → faction town → class picker (faction-specific names) → intro toasts.
- [ ] Walking into 고블린 숲 below Lv 10 teleports you back; pads and the 이동 panel respect levels.
- [ ] Travel channel takes 3 s, cancelled by damage; blocked at ≥ 3 stars, in combat, with a sack, as kaiju.

Combat, classes, charge & release
- [ ] Warrior hits every monster within 10 studs every 1.0 s; Mage hits the nearest target ≤ 35 studs + 7-stud splash every
      1.25 s (orb visual); Archer hits the 2 nearest ≤ 30 studs every 0.5 s (arrow visuals) and walks 10% faster.
- [ ] Each swing that hits shows numbers ≈ half of the weapon damage and adds +1 (auto) / +2 (manual) to the 발사 ring
      (Archer +0.5 / +1). Stacks persist across kills, reset on death.
- [ ] 발사 below 10 stacks is refused; at ≥ 10 it blasts a radius of 8 + 0.1 × stacks with a huge number and screen shake;
      Mage meteor / Archer arrow rain land on the nearest target. At the cap (150 Halo / 175 Horns) the ring glows gold for
      3 s ("PERFECT"); waiting 3 s auto-releases with "자동 발사" (×1.5) that never hits players.
- [ ] Halo release heals nearby Halo allies and gives them +10 stacks; Horns lifesteal works on swings and releases.
- [ ] 자동 is locked below Lv 5; auto swings never damage players.
- [ ] Upgrade buys the next weapon tier; the model is a sword / staff / bow by class with class-specific names.
- [ ] Menu > 직업 변경 in a safe zone: free path → Lv 1, gold/weapon kept; with a ticket (`DebugCommand(..., "Tickets", 1)`)
      → level kept and ticket count −1; refused in a PvP zone / with a sack / as kaiju.
- [ ] Golden monster (~4%): gold color, sparkles, 10× gold popup. Monsters never enter towns, respawn after 4 s.

Size Justice, bully, revenge (2 players: A = Halo, B = Horns; raise B with `DebugCommand("Player2", "Level", 40)` and
`... "WeaponTier", 6`)
- [ ] Within 30 s GameState `HaloSize` > 1 (≤ 1.6), A grows smoothly over ~1–3 s, A's MaxHealth rises with HP % kept,
      HUD chip "덩치 저울 ×1.xx"; `HornsSize = 1`. A new player picking the `WeakerFaction` gets +300 gold (first choice only).
- [ ] B KOs a much weaker A (or A within 15 s of respawning, or A for the 3rd time in 10 min): no plunder/stars/infamy,
      B shows red "깡패", shrinks 15% per stack (max 3), deals less damage; KOing B pays a doubled bounty; stacks decay 1
      per 5 min. If A hit B first within 10 s, (a) does not trigger.
- [ ] After any PvP KO the victim sees an orange arrow + "복수" to the killer and deals +25% to them for 90 s.
- [ ] Below Lv 15 / under 60 min playtime both show "새싹 보호" and cannot hurt each other; spawn ForceField 10 s.

Grudge sack & stars (B = Horns, A = Halo with carried gold via `"Gold", 5000`)
- [ ] B KOs A in 고블린 숲: A loses 20% of carried above the floor, B gets a purple sack + translucent ghost "A의 원한" and
      1 star; every Halo player sees a purple arrow to B; B cannot Travel/use pads; the sack timer only ticks in PvP zones.
- [ ] 45 s in the PvP zone → B gets the gold + Infamy. Variant: A (or another Halo) KOs B in time → A's bank +120%,
      avenger gets bounty (if stars) + 100 "복수 대행", server toast. B KO'd by a monster → A gets 100% back.
- [ ] Same thief/victim again within 3 min steals 0; the 20% bonus only once per pair per 10 min.
- [ ] B at 3 stars glows red, cannot Travel; at 5 stars a server announcement; stars decay every 120 s (not while kaiju/queued).

Wanted kaiju (`DebugCommand("Player2", "Stars", 5)`)
- [ ] 10 s red siren banner for everyone, then B grows ×3, HP ×20+, fire particles, red glow; every 4 s nearby non-rookie
      Halo players outside towns lose 6% HP (red ring); A can hit B even inside a town; B cannot Travel.
- [ ] A KOs B: pool (3 × bounty + B's carried) split 50% by damage / 50% equally among participants (incl. a Halo who
      healed A via release); Halo war points +150; B back to normal with 0 stars.
- [ ] B survives 120 s: carried ×1.5 to bank, nametag title "전설의 악당", Horns war points +150, 10 s shield.
- [ ] A second 5-star Horns waits in the queue ("괴수 대기 중") and transforms after the first ends.

Golden goose (`DebugCommand("Player1", "Goose", 0)` or wait for the HUD "황금 거위까지" timer)
- [ ] A golden goose appears on the Crossroads perch for 60 s; tug bar shows 구조 vs 밀렵; manual swings count 2, auto 1,
      max 3 counts/s, × the faction's S; the goose never dies and gives no charge.
- [ ] Winners get XP-heavy (Halo) / gold-heavy (Horns) rewards; losers 40% + 1 응원별; tie → both loser rewards; winner
      faction war points +60. With 5 응원별 the next reward is RARE (×5, big toast) and the stars are consumed.
- [ ] Luck corner shows "단골 N분 · 희귀 X%": +0.25%p per active minute, capped at 12.5%, resets on rejoin.

Quests, vacation, rebirth
- [ ] On a new day the 3 slots are "일일" quests; progress is automatic; 받기 pays; the slot becomes an "추가" quest
      (auto-paid, smaller); claiming all 3 pays the chest (10% class ticket). Reroll works once per 60 s.
- [ ] `DebugCommand("Player1", "Absent", 2)` → vacation popup with 2 days × 70% of a full day at the current level; 받기 pays once.
- [ ] Rebirth panel shows the server ratio and +25% / +40%; switching side grants 타락/구원 marks (cape / cracked halo),
      gold/XP bonuses rise accordingly; both marks ≥ 3 → "회색 전설" + gray aura; rebirth refused with stars/sack/kaiju/combat.

Altar & tickets
- [ ] Altar free switch: the left faction's score (Honor or Infamy) becomes 0, the other is restored; ticket switch keeps
      both and uses a ticket; any second switch within 10 min is refused with the remaining time; refused with
      stars / sack / kaiju / combat.
- [ ] With product ids 0: buy buttons say "상품 준비 중" and Output has the `[MonetizationService]` hint. With real ids
      (after publishing): purchase → ticket +1, toast "직업 변경권 1장을 받았어요!"; replaying the same receipt grants nothing.

War meter
- [ ] Meter moves with kills; countdown from 10:00 (test with `Config.War.RoundSeconds = 60`). At round end: crown
      announcement (Story.WarWin), sky tween, blessing chip, chests (≥ 30 points), +25% gold/XP next round.
- [ ] Only one faction online → `WarMode = "Siege"` and the "몬스터 포위전" label.

Robustness
- [ ] Spamming any remote (e.g. `for i=1,1000 do Remotes.Release:FireServer() end`) causes no errors and no extra effect;
      wrong types (`ChooseFaction:FireServer(123)`, `ChangeClass:FireServer("Mage", "yes")`) are ignored.
- [ ] A player leaving mid-fight, mid-travel, with a sack, as kaiju, during a goose or mid-quest causes no Output errors.
- [ ] Phone emulator (landscape): the 5 buttons are reachable with thumbs, nothing overlaps the jump button or joystick,
      text readable, arrows stay inside the screen.
