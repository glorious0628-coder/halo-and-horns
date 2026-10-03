# 코드 리뷰 R1 (검수 세션) — 커밋 88a438c

HIGH 2 / MED 27 / LOW 51 (검증 통과 88건, 중복 9쌍 병합, S2-H3 잔여 1건 추가)
범위: `src/` 33개 파일(약 22,000줄). 기준 문서는 TECH_SPEC v2, SPEC_ADDENDUM A1~A13(우선), GDD, impl_notes다. round2_inputs와 겹치는 지적은 뺐다.
방법: 파일 묶음 12개와 교차 관점 5개로 지적을 모았다. 반박 검증을 통과한 지적만 실었다. reviewer_spec_v2 항목의 현재 상태는 따로 표기했다.

> **줄 번호**
> - 모두 88a438c 기준이다.
> - a316a95까지 바뀐 파일: HUD, Fx, EventHUD, UIKit, MonsterService, Panels(2줄), Config(926줄 이후 +4). 이 파일들은 함수명으로 찾는다. 나머지 서버 파일은 88a438c 그대로다.
> - HEAD 위치:
>   - HUD: onClaim 1318, onReroll 1339, Claim·Reroll 버튼 1413·1426, buildTravel 698, 퀘스트 BarText 1522, ui.war 배치 1933, onFx 1992, keyHint(ui.menu) 901
>   - Fx: MERGE/FLASH 50-51, showHits 조건 1370, comboLabel 1158, Hurt 1545
>   - EventHUD: placeArrow 715
>   - UIKit: IgnoreGuiInset 760, TOAST 60-61
>   - MonsterService: visibleTo 158, groundPoint 213, CountInRadius 323, OwnerUserId 712, 기여자 루프 909, DamageMonster 924, targetable 1043, reevaluate 1349
>
> **같이 고칠 묶음** (같은 함수를 건드린다)
> - CR-M10 + CR-M23 + CR-M15: DamagePlayer, PlayerDamaged
> - CR-M3 + CR-M4 + CR-L6: 쌍 쿨다운
> - CR-M11 + CR-M12 + CR-L1: PlayerLeaving 순서
> - CR-M24 + CR-M25: onReroll
> - CR-M27 + CR-L31: HUD 퀘스트 글자
> - CR-M6 + CR-L12: 퀘스트 보상 상한
> - CR-H1 + CR-M7: 발사
> - CR-H2 + CR-M5 + CR-M9: 위치·존·입금

## HIGH

**[CR-H1] 기사단 발사의 동료 +10 스택이 무한 순환함** `G1,G4`
- 위치: CombatService.luau:741-742, 754-756 / Config.luau:214(MinRelease 10), 224(HaloAllyStacks 10), 906(Release 0.25초)
- 문제·실패 시나리오:
  - 1라운드에서 `shareStacks = monstersHit + playersHit > 0` 조건만 추가됐다. 받는 쪽 쿨다운(A13-H2)은 없다.
  - 기사 2명이 슬라임 옆에서 번갈아 발사하면 A 발사 → B +10 → B 발사 → A +10이 0.25초마다 이어진다. 반경 9 광역 피해(6D)가 무한히 나간다.
  - 3명이면 발사 1회당 10을 쓰고 20을 받아 스택이 늘어난다. 몇 초 만에 150 캡에 닿아 PERFECT(×4)가 연달아 나가고, 괴수도 3발이면 쓰러진다(CR-M7).
- 수정:
```lua
-- Config.Charge
HaloAllyStackCooldown = 5,
-- CombatService 상단
local lastAllyStackAt = {} -- [Player] = os.clock()
-- 754-756
if shareStacks then
	local t = os.clock()
	if t - (lastAllyStackAt[a] or -math.huge) >= (Config.Charge.HaloAllyStackCooldown or 5) then
		lastAllyStackAt[a] = t
		addCharge(a, Config.Charge.HaloAllyStacks)
	end
end
-- onPlayerLeaving(874)의 task.defer 블록에 추가: lastAllyStackAt[player] = nil
```

**[CR-H2] 서버가 클라이언트의 캐릭터 위치를 검증 없이 믿음** `G3,G2,G4,G6,G1`
- 위치: ZoneService.luau:141-180(updateZone), 323-340(onPadTouched) / CombatService.luau:191, 473 / ProgressionService.luau:244 / FactionService.luau:121-127
- 문제: HumanoidRootPart 위치는 클라이언트가 소유하고 그대로 서버에 복제된다. 그런데 서버에 이동 검증이 없다. 존은 0.5초마다 그 순간 위치로만 계산하고, Swing·BankAll·발판·제단은 그 위치를 그대로 믿는다.
- 실패 시나리오:
  1. PvP 지역에서 골드를 든 채 HornsTown 좌표로 0.6초 순간이동하면 다음 틱에 BankAll이 돌아 약탈 위험이 0이 된다.
  2. firetouchinterest로 발판 Touched를 일으키면 3초 채널 없이 어디서든 즉시 탈출한다.
  3. Lv5가 해골 유적 몬스터 옆으로 순간이동해 Swing을 보내고 0.5초 안에 돌아오면 레벨 게이트를 우회한다.
  4. 스피드 핵으로 자루를 들고 도주하거나, 제단에서 먼 곳에서 진영을 바꾼다.
- 수정: ZoneService에 이동 검증을 넣는다.
```lua
local lastGood, graceUntil = {}, {}
local MOVE_MULT, MOVE_SLACK, RISE_PER_SEC = 1.35, 4, 60
function ZoneService.MarkTeleported(player, seconds)
	graceUntil[player] = os.clock() + (seconds or 1)
	lastGood[player] = nil
end
function ZoneService.IsPlausible(player, pos)
	local g = lastGood[player]
	if not g or os.clock() < (graceUntil[player] or 0) then return true end
	local hum = Util.GetHumanoid(player)
	local dt = math.max(os.clock() - g.T, 0.05)
	local speed = hum and hum.WalkSpeed or Config.Player.WalkSpeed
	return Util.FlatDistance(pos, g.Pos) <= speed * MOVE_MULT * dt + MOVE_SLACK
		and pos.Y - g.Pos.Y <= RISE_PER_SEC * dt + 12 -- 낙하는 제한하지 않음
end
local function validateMove(player, root)
	local now, pos = os.clock(), root.Position
	if ZoneService.IsPlausible(player, pos) then lastGood[player] = { Pos = pos, T = now } return true end
	local g = lastGood[player]
	root.CFrame = CFrame.new(g.Pos) * root.CFrame.Rotation
	root.AssemblyLinearVelocity = Vector3.zero
	g.T = now
	return false
end
```
  - updateZone: RESCUE_Y 처리 직후(151줄 앞)에 `if not validateMove(player, root) then return end`를 넣는다. Config.Travel.ZoneTick은 0.5에서 0.2로 줄인다.
  - 서버가 순간이동시키기 직전에 `MarkTeleported`를 부른다: ZoneService.teleport(113), PlayerService 155·260, JusticeService 297. 다른 서비스에서는 `S.ZoneService.MarkTeleported`로 부른다. CharacterSpawned에서는 `MarkTeleported(player, 2)`를 부르고, cleanup에서 lastGood·graceUntil을 지운다.
  - CombatService.Swing(459줄 뒤)과 Release 첫머리에 다음을 넣는다:
    `if not S.ZoneService.IsPlausible(player, root.Position) then return end`
    `if Config.ZoneAt(root.Position).MinLevel > (tonumber(player:GetAttribute("Level")) or 1) then return end`
  - onPadTouched의 playerFromHit 다음에 거리 검사를 넣는다:
    `local r = Util.GetRoot(player); if not r or Util.FlatDistance(r.Position, pad.Position) > math.max(pad.Size.X, pad.Size.Z) / 2 + 4 then return end`
  - FactionService.nearAltar 반환식에 `and S.ZoneService.IsPlausible(player, root.Position)`을 추가한다.
  - 오탐 위험은 낮다. 플레이어에게 넉백이나 속도를 주는 서버 코드가 없고, WalkSpeed는 서버만 설정한다.

## MED

**[CR-M1] 쓰기 슬롯이 FIFO가 아니라서, 같은 서버에 빨리 재접속하면 골드가 복제되고 진행도가 사라짐** `G2`
- 위치: DataService.luau:24, 43-58(acquireSlot/releaseSlot), 157(writeRecord 토큰 비교), 269(Load)
- 문제·실패 시나리오:
  - 0.1초 간격으로 확인하는 폴링 뮤텍스라 대기 순서가 없다.
  - 자동 저장이 재시도(1+2+4초) 중일 때 약탈당한 P1이 나갔다가 같은 서버로 다시 들어온다. 새 Load가 Release보다 먼저 슬롯을 잡아 약탈 전 저장본을 읽는다.
  - 이전 세션의 Release는 157줄에서 foreign으로 판정되어 취소된다. 도둑은 골드를 받고 피해자 골드도 복구된다.
  - A13-M22(1)을 충족한 것처럼 보이지만 실제로는 충족하지 못한다.
- 수정: UserId별 FIFO 큐로 바꾼다(기존 token 인터페이스는 그대로).
```lua
local slotQueue = {} -- [userId] = { token, ... }
local function acquireSlot(userId)
	local q = slotQueue[userId]; if not q then q = {}; slotQueue[userId] = q end
	local token = {}; table.insert(q, token)
	local t0 = os.clock()
	while q[1] ~= token do
		if os.clock() - t0 >= SLOT_TIMEOUT then local i = table.find(q, token); if i then table.remove(q, i) end; return nil end
		task.wait(0.1)
	end
	return token
end
local function releaseSlot(userId, token)
	local q = slotQueue[userId]
	if q and q[1] == token then table.remove(q, 1); if #q == 0 then slotQueue[userId] = nil end end
end
```
  Load 269줄의 acquireSlot 앞에도 대기를 넣는다. 같은 UserId의 이전 Player가 cache에 남아 있으면, Release가 405줄에서 cache를 비울 때까지 기다린다(`player.Parent == nil`이거나 SLOT_TIMEOUT을 넘기면 nil 반환). impl_notes.md:81 문구도 이 수정에 맞춰 고친다.

**[CR-M2] 서버 종료 때 전투 중이던 플레이어가 주머니 25%를 잃고, 도둑의 자루 환불이 사라짐** `G2,G8`
- 위치: ProgressionService.luau:396-398 / PlayerService.luau:31, 324-348, 468-486 / GrudgeService.luau:86-92, 116-127
- 문제·실패 시나리오:
  - 업데이트로 서버가 닫히면 PvP 중이던 플레이어에게 CombatLogPenalty 25%가 적용된다.
  - onClose는 FinalizeLeave를 플레이어마다 spawn한다. 피해자가 먼저 ready에서 빠지면, 뒤에 나간 도둑의 returnShares에서 presentVictim이 nil이 되어 환불이 사라진다.
  - PlayerLeaving 중복 발생 문제는 이미 고쳐졌다.
- 수정:
  - PlayerService에 `function PlayerService.IsShuttingDown() return closing end`를 추가하고, ProgressionService 396 조건에 `and not S.PlayerService.IsShuttingDown()`을 더한다.
  - onClose의 spawn 루프 앞에서, ready이고 finalizing이 아닌 모든 p에 대해 다음을 동기로 실행한다: `finalizing[p] = true; leftFired[p] = true; PlayerService.PlayerLeaving:Fire(p, S.DataService.Get(p))`. 이때 ready는 내리지 않는다. 그래야 상대의 환불이 피해자 data에 들어간다.
  - FinalizeLeave 맨 앞(469 대기 분기보다 앞)에 분기를 둔다: `leftFired[p]`이면 ready 해제 → Release → finalizing·leftFired 해제만 하고 return한다.

**[CR-M3] 괴수 담합 파밍: 발행 풀이 5분마다 다시 지급되고, 같은 쌍으로 별이 쌓이고, 주머니가 상한 없이 넘어감** `G1,G7,G9`
- 위치: KaijuService.luau:570-571, 589, 599, 609 / PvPService.luau:415-423
- 문제·실패 시나리오:
  - 기사 부계정 B·C·D가 B·C·D·B·C 순서로 뿔 부계정에게 죽어 주면 약 1분 만에 별 5개 괴수가 된다.
  - 기사 본계정 혼자 막타를 치면 L60 기준 발행분 13,500(깡패면 27,000)과 괴수 주머니 전액(frac=1)을 받는다.
  - 쿨다운이 300초라 5분마다 반복된다. 1:1 거래 금지를 우회하는 골드 발행이다.
- 수정:
  - Config.Kaiju에 `PairRewardCooldown = 1800`을 추가하고, 599줄을 `local cooldown = Config.Kaiju.PairRewardCooldown or 1800`으로 바꾼다.
  - 589줄 다음에 `taken = math.min(taken, Config.PvP.PlunderCapPerLevel * level)`을 넣는다. 초과분은 소멸한다.
  - PvPService 423줄을 `if pairOk then addStar(killer) end`로 바꾼다.
  - 쿨다운은 CR-M4 방식으로 저장해야 서버 이동으로 풀리지 않는다.

**[CR-M4] 담합 방지 쌍 쿨다운이 서버 메모리에만 있어, 둘이 함께 서버를 옮기면 초기화됨** `G1,G2,G7,G9`
- 위치: PvPService.luau:39-46(koLog/pairReward/bullyBountyAt) / GrudgeService.luau:26-28(lastSteal/lastRefund/lastAvenge) / KaijuService.luau:51(poolPaidAt)
- 문제·실패 시나리오:
  - 뿔 H가 기사 부계정 A를 2번 KO한 뒤, 둘이 친구 참가로 다른 서버로 옮긴다(약 30초).
  - 3회 반복 깡패 판정, 쌍 보상 300초, RestealWindow 180초, 환불 보너스, CR-M3의 1800초가 모두 0부터 다시 시작한다.
  - 자루 Paid로 부계정에서 본계정으로 골드를 옮기는 속도 제한도 풀린다.
- 수정: 쌍 기록을 보상받는 쪽 데이터에 os.time() 기준으로 저장한다. 데이터는 세션 잠금으로 서버를 따라간다. Config.Data.Defaults에 `PairCD = {}`를 추가한다(Mirrored에는 넣지 않는다).
```lua
function PlayerService.PairReady(holder, otherUserId, kind, cooldown, commit)
	local d = PlayerService.GetData(holder); if not d then return false end
	if type(d.PairCD) ~= "table" then d.PairCD = {} end
	local k = kind .. ":" .. tostring(otherUserId)
	if os.time() - (tonumber(d.PairCD[k]) or 0) < cooldown then return false end
	if commit ~= false then d.PairCD[k] = os.time() end
	return true
end
```
  바꿀 곳:
  - PvPService 415 pairOk → `S.PlayerService.PairReady(killer, victim.UserId, "ko", P.PairRewardCooldown)`
  - bullyBountyAt → 피해자 data의 `"bully", 0`
  - koLog → 킬러 data `PairCD["kolog:"..vid] = {t1, t2}`(최근 2회만, RepeatWindow로 판정)
  - Grudge lastSteal(CanSteal은 commit=false로 조회하고 AddToSack에서 기록), lastRefund → 피해자 data
  - lastAvenge → 킬러 data (키는 CR-L6 기준)
  - KaijuService poolPaidAt → 참가자 data `"kaiju", kaijuUserId`
  - 정리: PlayerReady에서 1800초가 지난 항목을 지우고, 200개를 넘으면 오래된 것부터 지운다.

**[CR-M5] 몬스터 존 바로 밖(바깥 들판·고개)에서 일방적으로 사냥 가능** `G5`
- 위치: MonsterService.luau:151-153(visibleTo), 279-328(GetMonstersInRadius/GetNearest/CountInRadius), 892-906(DamageMonster), 1011-1013(targetable) / CombatService.luau:191-214, 1006-1015
- 문제·실패 시나리오:
  - 몬스터는 자기 존 안의 플레이어만 노리는데(A10-V3-2a), 공격하는 쪽은 존을 보지 않는다.
  - Lv5 마법사(사거리 35)가 Outskirts (563,0,0)에서 고블린 숲(MinLevel 10) 몬스터를 자동 공격으로 잡는다. Lv12가 고개 x≈955에서 해골 유적(MinLevel 25)을 사냥하는 것도 같다.
  - 몬스터는 반격하지 않는다. 전투 태그가 안 생기므로 적 진영도 공격할 수 없다. 레벨 튕김도 걸리지 않는다.
- 수정: MonsterService만 고치면 Swing·Release·autoTick이 모두 막힌다. CombatService는 수정할 필요가 없다.
```lua
local function zoneIdOf(player)
	local r = player and Util.GetRoot(player)
	return r and Config.ZoneAt(r.Position).Id or nil
end
local function visibleTo(rec, forPlayer, forZone)
	if forPlayer == nil then return true end
	if rec.Owner ~= nil then return rec.Owner == forPlayer end
	return forZone ~= nil and rec.ZoneId == forZone
end
```
  - 세 질의 함수는 루프 앞에 `local fz = zoneIdOf(forPlayer)`를 두고 `visibleTo(rec, forPlayer, fz)`로 부른다. 호출처는 이 세 곳뿐이다.
  - DamageMonster 895줄 직후(_contributors 기록 전)에 `if record.Owner == nil and player and zoneIdOf(player) ~= record.ZoneId then return false end`를 넣는다.
  - 개인 몬스터는 지금처럼 존과 관계없이 허용한다.

**[CR-M6] 받지 않고 둔 보상으로 무료 직업 변경과 환생의 초기화를 우회함** `G8,G7`
- 위치: QuestService.luau:223-224, 560-566, 573-577, 604-605, 652-658, 791-802 / ProgressionService.luau:159-164(ResetLevel), 325-330(TryRebirth) / GrudgeService.luau:116-153, 210-216
- 문제·실패 시나리오:
  - 일일 보상은 생성 시점 레벨로, 휴가 보상은 복귀 시점 레벨로 고정된다. 받을 때는 현재 레벨을 보지 않는다.
  - Lv60이 일일 3개와 3일치 휴가를 받지 않고 무료 직업 변경(Lv1) 뒤에 받으면 60,450XP로 곧바로 Lv35가 된다.
  - 환생 직전에 남겨 두면 최대 60,450G가 금고 0 초기화를 우회해 들어온다.
  - 원한 자루 환불도 피해자가 환생했는지 보지 않는다. 부계정이 자루를 들고 기다렸다가 환생 뒤에 환불되게 할 수 있다.
- 수정:
  1. QuestService에 `local function capTo(g, x, capG, capX) return math.min(g, math.floor(num(capG))), math.min(x, math.floor(num(capX))) end`를 추가한다. 레벨이 오른 경우에는 기존 값이 더 작으므로 그대로 지급된다. 적용할 곳:
     - onClaimQuest 604줄 다음: `g, x = capTo(g, x, Config.DailyQuestReward(getLevel(data)))`
     - runDayCheck 573-577 루프: 같은 상한을 적용한 뒤 `paidGold += g; payReward(player, g, x)`
     - onClaimVacation 653줄 다음: `g, x = capTo(g, x, Config.VacationReward(getLevel(data), num(data.VacationDays)))`
  2. ProgressionService 17줄 다음에 `M.LevelReset = Util.Signal.new()`를 추가하고, ResetLevel 163줄 다음에 `M.LevelReset:Fire(player)`를 넣는다. QuestService.Init에서 `connectSignal("ProgressionService", "LevelReset", onRebirthed)`로 Extra를 다시 만든다.
  3. GrudgeService.AddToSack의 entry에 `Rebirths = victim:GetAttribute("Rebirths") or 0`을 저장한다(기존 entry에 더할 때도 갱신). returnShares와 avenge의 `if victim then`을 `if victim and (victim:GetAttribute("Rebirths") or 0) == (entry.Rebirths or 0) then`으로 바꾼다.
  4. 리드: TECH_SPEC 1897-1898, 2285의 '보상 유지'를 A13에 '수령 시점 레벨 기준 상한'으로 고쳐 적는다.

**[CR-M7] 괴수에게도 발사 상한이 현재 MaxHealth의 35%라 HP ×20이 의미 없음** `G1,G4`
- 위치: CombatService.luau:715-724
- 문제·실패 시나리오: 기사 3명이 149스택을 들고 있다가(캡 미만이라 자동 발사되지 않음) 괴수가 나타나면 각자 1발씩 쏜다. 120초 레이드가 1초 만에 끝난다.
- 수정: Config.Kaiju에 `ReleaseCapPct = 0.08`을 추가한다. 721-724줄을 다음으로 바꾼다:
  `local capPct = (kstate(vp) == "Active") and (Config.Kaiju.ReleaseCapPct or 0.08) or Config.Charge.PvPCapPct; local raw = math.min(Config.ReleaseDamage(D, n, false) * releaseMult, capPct * vHum.MaxHealth)`

**[CR-M8] 흡혈 상한이 괴수의 ×20 MaxHealth 기준이라 괴수가 레이드보다 빨리 회복함** `G4,G9`
- 위치: CombatService.luau:440-449(applyLifesteal)
- 문제·실패 시나리오: 기사 4명이 근처에 있으면 괴수 MaxHealth는 20,384이고, 스윙당 흡혈 상한은 611이다. 괴수가 해골 기사 무리를 자동 공격하면 초당 125~374를 회복한다. 기사가 1~2명이면 처치할 수 없다.
- 수정: 449줄 앞에서 Active 괴수는 상한 기준을 기본 체력으로 되돌린다:
  `local capBase = hum.MaxHealth; if kstate(player) == "Active" then local okK, km = pcall(S.KaijuService.GetHealthMult, player); if okK and type(km) == "number" and km > 1 then capBase = capBase / km end end`
  그다음 `CombatService.HealPlayer(player, math.min(total * rate, capBase * (perks.LifestealCapPct or 0)))`로 바꾼다. 더 단순한 대안은 Active 괴수의 흡혈을 끄는 것이다(applyLifesteal 첫 줄에서 return).

**[CR-M9] 활성 괴수가 교차로(Town=true)에 있으면 주머니가 매초 금고로 들어가 레이드 풀이 빔** `G8`
- 위치: ProgressionService.luau:241-249(bankTick) / Config.luau:623-624 / ZoneService.luau:147, 158-162
- 문제·실패 시나리오:
  - 별 5개로 주머니 3만을 든 괴수가 교차로로 간다. 교차로는 마을에서 튕긴 괴수와 낙하 구조 괴수가 보내지는 곳이기도 하다.
  - 1초 안에 BankAll이 돌아 주머니가 금고로 옮겨진다. 이후 처치해도 HandleKaijuDeath의 taken이 0이다.
  - 무적·재생 문제는 이미 고쳐졌다.
- 수정: 244줄 앞에 `local ks = S.KaijuService and S.KaijuService.GetState(player); if ks == "Siren" or ks == "Active" then return end`를 넣는다.

**[CR-M10] 실제로 깎은 HP가 아니라 요청한 피해(오버킬 포함)를 집계함: 치유가 부풀고 괴수 막타가 몫을 독식** `G4,G9`
- 위치: CombatService.luau:390-404(DamagePlayer), 573-576, 586-589, 703-709, 725-728, 751 / KaijuService.luau:499-505, 592-608 / MonsterService.luau:886, 931
- 문제·실패 시나리오:
  - (a) 기사단 10스택 발사가 HP 90 고블린 1마리만 맞혀도 676이 total에 들어간다. 반경 안 기사단이 68HP(18%)를 회복하고, 고블린 2마리면 30% 상한까지 회복한다.
  - (b) 괴수 HP가 50 남았을 때 아껴 둔 150스택 발사가 8,590으로 dmg에 기록된다. 피해 몫의 약 26%를 혼자 가져가므로 GDD 158의 '막타 보너스 없음'을 위반한다.
- 수정:
  - DamagePlayer의 모든 조기 `return`을 `return 0`으로 바꾸고, 끝에 `return applied`를 추가한다.
  - 404줄을 `CombatService.PlayerDamaged:Fire(victim, applied, attacker)`로 바꾼다. applied가 0이어도 발신은 유지한다(PvPService lastHitOn 기록 때문). KaijuService 504는 이제 실제 피해를 누적하고, 0 이하는 이미 무시한다.
  - Swing·Release의 몬스터 쪽:
    `local hpBefore = math.max(0, tonumber(rec.HP) or 0); S.MonsterService.DamageMonster(rec, dealt, player); local applied = math.max(0, hpBefore - math.max(0, tonumber(rec.HP) or 0)); totalDealt += applied`
    Release에서는 `total += applied`로 쓴다.
  - 플레이어 쪽: `+= CombatService.DamagePlayer(vp, dealt, player) or 0`
  - 화면 숫자(hits의 A)는 dealt 그대로 둔다.
  - 주의: 몬스터 쪽 기사단 치유가 크게 줄어든다(고블린 1마리 기준 68 → 9). 치유량을 유지하려면 HaloHealPct 상향을 유저와 정한다.

**[CR-M11] 괴수나 수배범이 로그아웃하면 레이드 보상과 현상금이 사라짐** `G7,G9`
- 위치: KaijuService.luau:479-482 / PvPService.luau:651-655
- 문제·실패 시나리오: 체력 15% 남은 괴수가 나가면 `finish(..."Cancelled"...)`로 끝나 풀, Halo +150, 참가자 보상이 모두 없다. 별 4개 수배범도 몰리면 로그아웃해 현상금을 지운다.
- 수정:
  - KaijuService PlayerLeaving: `player == current`이고 phase가 "Active"이며 dmg 합계가 0보다 크면 `pcall(KaijuService.HandleKaijuDeath, player, nil, true)`를 실행한다. 실패하거나 current가 그대로면 Cancelled로 끝낸다. 그 밖의 경우는 기존처럼 Cancelled다.
  - HandleKaijuDeath(victim, killer, leaving): 631줄을 `finish(victim, "Defeated", participants, leaving)`로 바꾸고, leaving이면 캐릭터 접근을 건너뛴다. lethalHit=false이므로 575-585가 Halo 피해 비율만큼만 발행해 담합 방지는 유지된다.
  - PvPService.onPlayerLeaving: clearRevengeInvolving 앞에 다음을 넣는다. 별이 1개 이상이고 `IsInCombat`이면, 마지막 PvP 공격자가 접속 중인 Halo이고 쌍 쿨다운(CR-M4 PairReady)을 통과할 때 `Config.Bounty(Level, stars, bullyStacksOf(player))`를 `AddBankGold(a, b, "Bounty")`로 지급하고 BountyGain을 알린다.
  - CR-L1을 먼저 고쳐야 깡패 배수가 0으로 읽히지 않는다.

**[CR-M12] 깡패 단계와 현상수배 별이 재접속하면 0이 됨** `G1,G6,G7`
- 위치: JusticeService.luau:267-283 / PvPService.luau:626-636 / Config.luau:29-63(Data.Defaults)
- 문제·실패 시나리오: 깡패 3단계(공격 ×0.55)이고 별 4개인 플레이어가 전투 태그 15초를 마을에서 기다린 뒤 재접속한다. 둘 다 0이 되고 현상금과 사냥 대상 표시도 사라진다.
- 수정:
  - Config.Data.Defaults에 `SavedBully = 0, SavedBullyAt = 0, SavedStars = 0, SavedStarsAt = 0`을 추가한다(Mirrored에는 넣지 않는다).
  - JusticeService.onPlayerLeaving(player, data): clear 전에 `data.SavedBully = GetBullyStacks(player); data.SavedBullyAt = os.time()`을 기록한다.
  - JusticeService.onPlayerReady: 경과 시간 / Config.Bully.DecaySeconds만큼 감쇠한 값을 MaxStacks 이내로 복원한다. 진영이 Halo/Horns일 때만 복원하고 BullyStacks 속성도 쓴다.
  - PvPService도 같은 방식으로 SavedStars를 기록·복원한다. 복원값은 `math.min(Config.Kaiju.StarsNeeded - 1, 감쇠값)`이고, 복원 뒤 refreshStarAttrs를 부른다.
  - CR-L1을 같이 고친다.

**[CR-M13] 괴수 발구르기가 안전 사냥터에서도 PvP 공격으로 기록됨** `G9`
- 위치: KaijuService.luau:384-390 / CombatService.luau:382-386, 819-836 / PvPService.luau:122-124
- 문제·실패 시나리오:
  - 괴수가 말랑 초원에서 빛 플레이어를 밟는다. 그 플레이어가 15초 안에 슬라임에게 죽으면 PvP KO(약탈·별)로 처리된다.
  - 발구르기가 양쪽에 전투 태그를 붙이므로 inPvP가 true가 된다. 괴수가 안전 사냥터에서 일반 스윙으로 약탈할 수 있다.
- 수정: 390줄을 다음으로 바꾼다:
  `local atk = (call("ZoneService", "IsPvPZone", v) == true) and p or nil`
  `call("CombatService", "DamagePlayer", v, Util.RoundDamage(hum.MaxHealth * Config.Kaiju.StompPct), atk)`
  TECH_SPEC 2082도 같이 고친다.

**[CR-M14] 깡패 판정의 '부활 15초'와 '3회 반복'에 미끼 예외가 없고, 괴수도 깡패가 됨** `G7`
- 위치: PvPService.luau:379-389, 405-408
- 문제·실패 시나리오:
  - 먼저 덤빈 뿔이 10분 안에 3번 죽어 주면, 방어한 기사가 깡패가 된다(공격 −15%, 현상금 ×2).
  - 괴수가 리스폰 직후의 Halo를 밟아 죽이면 괴수가 깡패 스택을 받는다. 그러면 괴수 처치 발행 풀이 2배가 된다.
- 수정: 380-389줄을 다음으로 바꾼다.
  - `local baited = baitAt ~= nil and now - baitAt <= B.BaitWindow` (CR-M15의 baited로 대체)
  - `if weak and baited then weak = false end`
  - `local bully = weak or fresh or repeated; local defense = baited and (fresh or repeated); if defense or kstate(killer) ~= "None" then bully = false end`
  - 405줄 분기 앞에 `if defense then info = { Kind = "Defense", Bully = false, VictimStars = starsBefore, Stolen = 0, Bounty = 0, Rewarded = false }`를 둔다. Defense는 스택·별·약탈·명예/악명·현상금을 모두 생략한다. 복수 처리(391-403)와 koLog(369-375)는 유지한다.

**[CR-M15] 미끼 판정이 피해 1회 기준이라, 수동 스윙이 자동으로 넣은 1타만으로 약자 보호가 꺼짐** `G1,G7`
- 위치: PvPService.luau:379-383, 662-672 / CombatService.luau:510-512, 526-530, 555-557
- 문제·실패 시나리오: Lv16이 슬라임을 치려고 공격 버튼을 누르고 있는데, 다가온 Lv40에게 수동 스윙 1타가 들어간다. 이후 Lv40이 Lv16을 처치하면 깡패 KO가 아니라 정상 약탈 20%와 별 +1로 처리된다.
- 수정:
  - Config.Bully에 `BaitMinPct = 0.2`를 추가한다.
  - lastHitOn 대신 `dmgLog[attacker][victim] = { {t, amount}, ... }`를 쓴다. BaitWindow가 지난 항목은 지우고, cleanupPlayer도 dmgLog 기준으로 바꾼다.
  - HandleKO에서 BaitWindow 안의 합을 구해 `baited = sum >= B.BaitMinPct * Config.MaxHealth(num(killer,"Level",1), fk, S.ClassService.GetClass(killer))`로 판정한다.
  - CR-M10이 적용되면 amount가 실제 피해이고, CR-M14도 이 baited를 쓴다.

**[CR-M16] 레벨업하면 무조건 체력이 가득 참: PvP 중 보상 받기, 활성 괴수** `G8`
- 위치: ProgressionService.luau:146-147
- 문제·실패 시나리오: HP 10%인 Lv27이 PvP 도중 완료해 둔 일일 퀘스트를 받으면 레벨업과 함께 HP가 100%가 된다(하루 최대 4번, Release Extra는 시점 조절도 가능). HP 10%인 괴수도 같은 방법으로 MaxHealth×20 기준으로 가득 찬다.
- 수정: 147줄을 `S.PlayerService.RefreshCharacter(player, not S.CombatService.IsInCombat(player) and S.KaijuService.GetState(player) ~= "Active")`로 바꾼다. 퀘스트 받기 자체는 막지 않는다.

**[CR-M17] 자동 공격 양보 창(1.0초)이 전사·마법사 간격 이하라, 누르고 있는 수동 공격의 절반이 자동으로 나감** `G4`
- 위치: CombatService.luau:994-996 / Config.luau:206
- 문제·실패 시나리오: 자동 ON인 마법사가 공격 버튼을 누른 채 Horns와 싸우면 수동과 자동이 번갈아 나간다. 자동 스윙은 플레이어를 때리지 않으므로 PvP 피해가 절반이 된다. A3-H3 '수동이 자동보다 우선' 위반이다.
- 수정: 995줄을 `if lm and os.clock() - lm < (cls(p).SwingInterval or 1) + 0.3 then return end`로 바꾼다. Config.Combat.ManualPriority와 23줄 주석은 정리한다.

**[CR-M18] 몬스터 1마리 처치의 전쟁 점수가 기여자 수만큼 중복으로 들어감** `G5,G3`
- 위치: MonsterService.luau:893-913 / WarService.luau:305-311, 349-353
- 문제·실패 시나리오: 같은 진영 4명이 함께 잡으면 진영 풀에 4점이 들어간다. 뭉쳐 다니는 진영의 1인당 점수가 N배가 되어 왕관전을 독차지한다.
- 수정:
  - killRecord: 먼저 ContributorWindow 안의 기여자를 eligible로 모으고 진영별 수(perFaction)를 센다. 각 기여자에게 `i = table.clone(info); i.WarShare = info.WarPoints / math.max(1, perFaction[faction])`를 담아 Fire한다.
  - WarService.AddPoints(player, n, poolN): `points[f] += (isValidAmount(poolN) and poolN or n)`로 바꾸고, 개인 점수에는 n을 쓴다.
  - 351줄을 `AddPoints(player, info.WarPoints, info.WarShare)`로 바꾼다.

**[CR-M19] 전쟁 1인당 점수의 분모가 종료 순간 인원이라, 막판 이탈로 승패가 뒤집힘** `G3`
- 위치: WarService.luau:222-246, 267-300
- 문제·실패 시나리오: 뿔 5명 700점, 기사 5명 750점에서 종료 10초 전 뿔 4명이 나간다. 뿔은 700/1=700이 되어 이긴다.
- 수정:
  - 모듈 상단에 `local presence, ticks = { Halo = 0, Horns = 0 }, 0`을 둔다.
  - tick()에서 getCounts 직후 인원을 누적하고 평균(aH, aR)을 낸다. 평균이 0.5 미만이면 0으로 친다. 이 평균을 publish와 endRound/decideWinner에 넘긴다.
  - endRound 리셋 블록(270-275)에서 presence와 ticks를 0으로 되돌린다. 292줄 publish는 현재 인원 그대로 둔다.

**[CR-M20] 덩치 저울 합산에 잠수·새싹·마을 대기 계정이 들어감** `G2,G6`
- 위치: JusticeService.luau:204-224 / PlayerService.luau:405, 503(lastActive)
- 문제·실패 시나리오: Lv70 기사 부계정을 HaloTown에 세워 두기만 해도 뿔의 S가 1.6이 된다. 그러면 PvE 피해, 거위 카운트, 괴수 HP가 모두 ×1.6이 된다.
- 수정:
  - PlayerService에 `function PlayerService.GetLastActive(p) return lastActive[p] or 0 end`를 추가한다.
  - JusticeService: `townSince`를 ZoneChanged로 유지한다(마을이면 진입 시각, 아니면 nil).
  - Recompute에서 `counted = not IsRookie(p) and now - GetLastActive(p) <= 120 and not (townSince[p] and now - townSince[p] >= 60)`일 때만 sum과 count에 더한다. entries 삽입은 그대로 두어 제외된 사람도 S를 받는다. clearPlayer에서 townSince를 지운다.

**[CR-M21] 일일을 일부만 한 날이 결석한 날보다 손해이고, 자정 자동 지급이 상자를 빠뜨림** `G8,G12`
- 위치: QuestService.luau:557-577 / Panels.luau:1284
- 문제·실패 시나리오:
  - Lv30이 하루를 쉬면 휴가 보너스로 17.5분 치를 받는다. 5분 접속해 일일 1개만 하면 약 10분 치다. 확정 사항 '일일퀘가 항상 더 이득'에 어긋난다.
  - 2개를 받고 3번째는 완료만 한 채 자정을 넘기면 상자(10분 치, 티켓 10%)가 사라진다.
- 수정:
  - 557줄 앞에서 `prevClaims`와 `claims = min(slots, prevClaims + #toPay)`를 구한다.
  - 휴가 일수를 `기존 + (1 - f) + 완전 결석일`로 계산한다(상한 VacationMaxDays, floor 제거). f는 `(claims × QuestMinutes + (claims >= slots and ChestMinutes or 0)) / (QuestMinutes × slots + ChestMinutes)`다.
  - 자동 지급 뒤 `prevClaims < slots and claims >= slots`이면 DailyChestReward를 지급하고 ChestTicketChance로 Class 티켓을 굴린다.
  - Panels 1284는 `math.ceil(num("VacationDays"))`로 표시한다.

**[CR-M22] 고블린 숲 이동 발판이 교차로 동쪽 큰길 한가운데에 있음** `G1,G3`
- 위치: Config.luau:669-674, 703 / ZoneService.luau:276-280, 323-340 / MapBuilder.luau:543-561 / tools/preview_map.lua:31-35
- 문제·실패 시나리오:
  - Pad_GoblinWoods(60,0,0)가 RoadCross 위에 있다. Lv12가 초원으로 가려고 길 한가운데를 걷다 밟으면 즉시 고블린 숲(PvP)으로 이동해 KO·약탈을 당한다.
  - Lv10 미만은 이 길을 지날 때마다 2초 간격으로 경고를 받는다.
  - ensurePads는 이미 있는 발판을 다시 배치하지 않는다. Config 좌표만 옮기면 WorldMap과 실제 발판·HUD 가이드가 어긋난다.
- 수정:
  - Pads 좌표를 SlimeMeadow (52,0,-24), GoblinWoods (52,0,24), SkeletonRuins (68,0,24)로 옮기고(ART_DIRECTION.md:158), preview_map.lua PADS도 같은 값으로 맞춘다.
  - ensurePads의 '-- functional bits' 아래에서 재사용한 발판도 `want = Vector3.new(X, 0.5 - pad.Size.Y/2, Z)`로 옮긴다. delta만큼 하위 BasePart를 함께 옮기고 PadSign 글자를 `padLabel(zone)`으로 다시 쓴다.
  - 옮긴 뒤 Studio에서 가로등·벤치와 겹치지 않는지 확인한다.

**[CR-M23] 플레이어에게 맞으면 피해자 화면에 피격 숫자와 붉은 테두리가 없음** `G4,G11`
- 위치: CombatService.luau:395-407, 588, 727 / Fx.luau:1037, 1206-1222 / KaijuService.luau:390
- 문제·실패 시나리오:
  - attacker가 있으면 Hurt를 보내지 않는다. 남의 Swing 숫자는 A9-2에 따라 크리티컬일 때만 그리는데, PvP 히트는 항상 C=false다.
  - 그래서 수동 스윙에 맞는 피해자 화면에는 숫자도 테두리 플래시도 없다. 발구르기도 숫자가 없다.
  - 약탈 PvP의 핵심 피드백이 빠진 상태다.
- 수정:
  - DamagePlayer: attacker 분기(힌트와 PlayerDamaged)와 별도로 `if applied > 0 then Net.Fx(victim, "Hurt", { Pos = rootPos, Amount = applied }) end`를 넣는다(CR-M10의 applied 사용).
  - 588과 727의 PvP 히트에 `V = vp.UserId`를 추가한다.
  - Fx.showHits 루프의 `local kind = h.K` 다음에 `if kind == "P" and not own and LocalPlayer and asNum(h.V, -1) == LocalPlayer.UserId then continue end`를 넣는다(Release 숫자 중복 방지).
  - 발구르기는 이 수정으로 자동 해결된다. TECH_SPEC 1828을 'applied>0이면 항상 Hurt'로 고친다.

**[CR-M24] 받기와 교체(↻) 버튼이 같은 자리라, 받기를 연타하면 교체가 눌려 진행도가 사라짐** `G10`
- 위치: HUD.luau:1220-1247(onClaim/onReroll), 1305-1329(같은 Position (250,6) 46×46), 1368-1375, 1392-1393
- 문제·실패 시나리오:
  - 튜토리얼이나 일일 [받기]를 연타한다. 0.1~0.7초 뒤 행이 다음 퀘스트(예: 7/30)로 바뀌고, 같은 자리에 활성 상태의 교체 버튼이 나타난다.
  - 다음 탭이 RerollQuest로 들어가 진행도가 사라지고 60초 쿨다운도 소모된다.
- 수정:
  - 모듈 상단에 `local lastClaimAt = 0`을 두고, onClaim의 fire 다음에 `lastClaimAt = os.clock()`을 넣는다. onReroll 맨 앞에서 `if os.clock() - lastClaimAt < 1.5 then return end`.
  - 행 단위 잠금도 넣는다. refreshQuests에서 `key = e.Id.."|"..tostring(e.Slot).."|"..e.Kind`가 바뀌면 `r.LockUntil = os.clock() + 0.8`로 두고, onReroll에서 `if os.clock() < (r.LockUntil or 0) then return end`.
  - CR-M25의 확인창을 넣어도 이 잠금은 유지한다.

**[CR-M25] 폰에서 퀘스트 교체 버튼이 조이스틱 영역 안에 있고, 확인 없이 일일 퀘스트를 바꿈** `G10`
- 위치: HUD.luau onReroll(88a438c 1241-1247), 퀘스트 블록 배치(applyLayout)
- 문제·실패 시나리오: 844×390 폰에서 첫 행 버튼이 실제 x 약 155~186, y 약 131~158로 DynamicThumbstick 영역(왼쪽 40%, 아래 2/3) 안에 있다. 이동하려고 엄지를 대면 38/50 진행 중이던 일일 퀘스트가 확인 없이 바뀐다.
- 수정:
  - onReroll의 fire를 `UIKit.Confirm("퀘스트 바꾸기", "진행도가 사라져요. 바꿀까요?", "바꾸기", function() fire("RerollQuest", e.Slot) end)`로 감싼다(모든 기기).
  - 터치 기기에서는 행의 Claim과 Reroll을 숨긴다. 상단 칩 줄(x ≥ 40%)에 '퀘스트' 칩을 추가하고, 그 칩이 여는 오버레이 안에서만 받기와 교체를 누를 수 있게 한다(A13-M25).

**[CR-M26] '이 편으로!'와 '이 직업으로!' 버튼이 같은 좌표라 두 번 탭하면 직업이 저절로 정해짐** `G12`
- 위치: ClassPicker.luau:329-338(choose), 535-549(refresh) / FactionPicker.luau:527-534
- 문제·실패 시나리오: 폰에서 '이 편으로!'를 빠르게 두 번 탭한다. 두 번째 탭이 곧바로 뜬 ClassPicker의 가운데 카드를 눌러, 직업 화면을 보지도 못한 채 직업이 확정된다.
- 수정:
  - ClassPicker.refresh의 `if open then` 블록에서 refreshButtons() 앞에 `lockedUntil = math.max(lockedUntil, os.clock() + 0.6)`을 넣고, 뒤에 `task.delay(0.65, function() if built then refreshButtons() end end)`를 추가한다. choose()의 lockedUntil 검사가 이미 있어 이것만으로 막힌다.
  - FactionPicker.refresh에도 같은 잠금을 넣는다.

**[CR-M27] 처치·황금 퀘스트 진행이 소수로만 올라가는데, 문구는 'N마리'라 멈춘 것처럼 보임** `G8,G1,G10`
- 위치: QuestService.luau:232-237, 448, 492-501(killWeight), 720-726 / Config.luau:809, 811 / HUD.luau:1389
- 문제·실패 시나리오: Lv25의 '황금 몬스터 1마리 처치'(unit=Skeleton)는 황금 고블린을 잡으면 0.43이 오르는데 화면은 0/1 그대로다. TECH_SPEC 2265의 '+1'에서 벗어났는데 이탈 기록도 없다.
- 수정:
  - Config 809 문구를 `"%s %d마리 쓰러뜨리기"`, 811을 `"황금 %s %d마리 처치"`로 바꾼다.
  - newQuest: Kill과 Golden이면 `string.format(t.Text, main.Name, target)`으로 몬스터 이름을 넣는다.
  - publish 448: `Progress = math.floor(num(q.Progress) * 10 + PROGRESS_EPS) / 10`
  - HUD 1389: 소수면 `%.1f`로 표시한다. CR-L31과 같은 줄이므로 함께 고친다.
  - 리드: A13/impl_notes에 'Kill/Golden 진행 = 단위 몬스터 XP 비율(최대 1)'을 기록한다.

## LOW

- **CR-L1** `G6` JusticeService.luau:276-283, 370-372 — PlayerLeaving 맨 앞에서 bully를 바로 지워서, 뒤 핸들러(CR-M11 현상금, CR-M12 SavedBully)가 항상 0을 읽음. → onPlayerLeaving은 (SavedBully 기록 후) `requestRecompute(); task.defer(clearPlayer, player)`로 바꾼다. PlayerRemoving 직접 연결은 `if not S.PlayerService.IsReady(player) then clearPlayer(player) end`로 바꾼다.
- **CR-L2** `G2` PlayerService.luau:280-293 — 셧다운 중 로드가 끝난 플레이어의 closing 분기 Release를 onClose가 기다리지 않음. 잠금이 남아 다른 서버 재접속이 약 12초 대기. → Release가 끝날 때까지 `joining[player]`를 유지하고, Release 뒤에 nil로 바꿔 return한다.
- **CR-L3** `G2` DataService.luau:83, 101-104, 335 — 더 높은 Version 저장본을 구 서버가 v2로 정리해 다시 저장함. → Load의 UpdateAsync transform에서 `(tonumber(old.Version) or 1) > Config.Data.Version`이면 tooNew=true로 두고 `return nil`(쓰기 취소)한다. 루프 뒤에서 releaseSlot 후 nil을 반환해 LoadFailed로 킥한다. 운영 규칙: MaxLevel이나 직업·진영을 추가할 때는 Version을 올린다.
- **CR-L4** `G7` PvPService.luau:327-339 — 마을에서 리셋하면 소지금이 0이라 손실 없이 별과 현상금이 지워짐. → 별이 1개 이상이고 `S.ZoneService.IsTown(victim) or os.clock() - S.CombatService.GetLastDamagedAt(victim) > 3`이면 별을 유지하고 return한다. TECH_SPEC 2013도 갱신한다.
- **CR-L5** `G6,G7` JusticeService.luau:142-148 / PvPService.luau:378 — 약자 판정 전투력에 환생 보너스(골드·XP 전용)가 곱해져, 환생을 많이 한 숙련자가 동급을 기습하면 깡패 KO가 됨. → `JusticeService.GetCombatPower`(PowerOf(level, tier, 1))를 추가하고 378줄만 이것으로 바꾼다. 덩치 저울 합산은 GetPower를 유지한다.
- **CR-L6** `G7` GrudgeService.luau:138-143, 156-161 — 20% 추가 환불과 복수 대행 보너스의 쿨다운이 쌍 단위라 도둑 부계정 수만큼 발행됨. → 키를 `tostring(userId)`(피해자 단위)와 `tostring(killer.UserId)`(복수자 단위)로 바꾼다. Config.luau:28, 464 주석과 GDD 147 문구도 고친다.
- **CR-L7** `G8,G6,G12` ProgressionService.luau:273-285 / FactionService.luau:171-185 — 언더독 환생 +40%를 Lv1 부계정 2개로 확정할 수 있음. → `FactionService.GetUnderdogCounts`(새싹·120초 잠수 제외, GetLastActive는 CR-M20)를 추가해 rebirthBonusFor 277에 쓴다. GameState에 UnderdogHalo/Horns를 게시하고 Panels.luau:644-645 미리보기도 그 값을 쓴다.
- **CR-L8** `G9` GooseService.luau:486 — 상대 진영이 없어도 거위 승자 보상 100%와 전쟁 60점을 받음. → 486줄 뒤에 `local okC, halo, horns = pcall(S.FactionService.GetCounts)`를 두고, 한쪽이라도 0이면 result="Tie"로 바꾸고 안내를 띄운다. call 헬퍼는 반환값을 하나만 주므로 쓰지 않는다.
- **CR-L9** `G6,G8,G1,G12` FactionService.luau:240-261 / ProgressionService.luau:305-317 / JusticeService.luau:341-356 — 깡패 단계가 남은 채 장인 길드로 바꾸거나 환생하면 스택이 즉시 0이 됨. → onSwitchFaction 256 뒤와 TryRebirth 317 뒤에서 `목표 == "Neutral" and GetBullyStacks > 0`이면 막는다. Config.Text.BlockedBully("깡패 단계가 모두 풀린 뒤에 장인 길드로 갈 수 있어요.")를 추가하고, Panels.altarBlock도 같은 문구를 쓴다.
- **CR-L10** `G6` FactionService.luau:220-225 — 약한 편 가입 보너스 +300을 받고 바로 무료 전환할 수 있음. → wasWeaker 블록의 AddBankGold 앞에 `S.PlayerService.SetStat(player, "LastSwitchTime", os.time())`을 넣는다.
- **CR-L11** `G6` FactionService.luau:267 — (S2-H3 잔여) 명예/악명이 0이어도 티켓을 차감함. → `if useTicket and lostScore and ((old == "Halo" and num(player, "Honor") > 0) or (old == "Horns" and num(player, "Infamy") > 0)) then`
- **CR-L12** `G8` QuestService.luau:776-788 — 진영이 바뀌어 다시 만든 일일 퀘스트의 보상이 현재 레벨(환생이면 Lv1)로 다시 계산됨. → 784줄에서 Daily면 `nq.RewardGold/XP = math.max(nq값, math.floor(num(q값)))`로 기존 보상을 유지한다. 환생 수령은 CR-M6 capTo가 다시 제한하므로 충돌하지 않는다.
- **CR-L13** `G5` MonsterService.luau:838-849, 1297-1313 — GlobalCap을 MonsterTypeOrder 순으로 채워서 상한에 걸리면 유적 밀도가 기본치에 머묾. → `cappedTargets(zoneCounts)`로 추가 목표를 비례 배분한다(room = GLOBAL_CAP − 기본 합). reevaluate 1302와 scheduleRespawn 843에서 이 목표를 쓴다.
- **CR-L14** `G5` MonsterService.luau:174-211 — 지면 탐사가 Decor 고체를 무시해 킹 슬라임 언덕·텐트·기둥 속에 스폰되고, 보이지 않는 슬라임에게 맞음. → `getBlockParams()`(Decor 중 Bridge_가 아닌 것 + Landmarks, 10초 캐시)와 `occupied(x,y,z)`(y+40에서 −39.5 레이)를 만든다. groundPoint 209에서 occupied면 nil을 반환한다.
- **CR-L15** `G11,G5` MonsterService.luau:681-686 / Fx.luau:698-718 — 튜토리얼 개인 황금 슬라임이 모두에게 보이지만 다른 사람은 칠 수 없음. → Fx에서 OwnerUserId가 자기가 아니면 BasePart의 LocalTransparencyModifier=1, Billboard/Particle/Light/Highlight의 Enabled=false로 숨긴다(기존 몬스터와 ChildAdded 모두). flashMonstersAt 루프에서도 건너뛴다.
- **CR-L16** `G2,G3` PlayerService.luau:43-44, 148-158, 386-395 / ZoneService.luau:145-149 — 낙하 구조가 중복되고, PlayerService 쪽은 활성 괴수를 자기 진영 마을로 보냈다가 다시 튕김. → PlayerService의 FALL_RESCUE_Y·FALL_CHECK_INTERVAL, rescueIfFallen, 구조 루프, 헤더 주석을 삭제한다(A10: ZoneService 담당).
- **CR-L17** `G3` MapBuilder.luau:349-352, 372-379 — 경계벽 바닥이 Y=0이라 바다(수면 −1.2, 바닥 −16) 밑으로 잠수해 맵 밖으로 나감. → `WALL_BOTTOM = (Config.Map.WaterTop or 0) - 20`으로 두고, wallSpecs 4개를 `Size Y = h - WALL_BOTTOM`, `Position Y = (h + WALL_BOTTOM)/2`로 바꾼다. ensureWalls에서 재사용한 벽의 바닥도 내린다. preview_map.lua:221-226도 같은 값으로 맞춘다.
- **CR-L18** `G3 [SPEC]` ZoneService.luau:231-291 — 이동 채널이 맞아도 바로 취소되지 않아 3초 막대가 남고, 다시 눌러도 반응이 없으며, 채널 토큰이 없음. → `channels[player] = {Token, Start}`를 두고 delay 콜백에서 토큰을 확인한다. updateZone에서 피격·전투·자루·괴수·별 조건이면 즉시 취소하고 TravelCancelled를 알린다. cleanup에서 지운다. TECH_SPEC 1653-1657 변경이 필요하다.
- **CR-L19** `G9` KaijuService.luau:565-629 — 아무도 보상을 받지 못해도 '기사단이 쓰러뜨렸어요! 보상 N골드' 공지가 나감. → 지급할 때 `paid += share`로 누적한다. paid>0이면 KaijuDefeated에 paid를 넣고, 아니면 '괴수 %s이(가) 쓰러졌어요.'를 띄운다.
- **CR-L20** `G3` WarService.luau:164-197 — ClockTime을 숫자 그대로 Tween해서 해가 거꾸로 돌거나 하루를 통째로 훑음. → lightingGoal에서 ClockTime을 빼고, NumberValue로 항상 앞으로 보간한다(to<from이면 +24, `Lighting.ClockTime = v % 24`). 애니메이션이 없는 분기는 바로 대입한다.
- **CR-L21** `G9,G4` GooseService.luau:601-643 / CombatService.luau:597-605 — 거위 GetPosition이 좌우 이동(±6)을 반영하지 않고, RegisterHit 반환값이 없어 '+2' 표시가 실제와 다름. → GetPosition은 `gooseCenter() + Vector3.new(sideOffset, 0, 0)`을 반환한다. RegisterHit은 조기 return을 `return 0`으로, 끝에 `return amount`를 둔다. CombatService는 counted>0일 때만 G 히트를 넣고 A=counted(소수 1자리)로 표시한다.
- **CR-L22** `G1,G4` CombatService.luau:647-671, 1019-1023 — PERFECT 창 끝에서 자동 발사가 지연된 수동 발사를 가로채고 '부족' 빨간 토스트까지 뜸. → Config.Charge.PerfectGrace=0.25를 1021과 666 판정에 더한다. autoReleasedAt을 기록해 1초 안의 수동 실패 토스트는 생략하고, 퇴장할 때 정리한다.
- **CR-L23** `G8,G9,G11` ProgressionService.luau:152, 232, 266-267 / KaijuService.luau:315 — 레벨업·금고·배달부·사이렌 알림이 2중으로 나옴. → LevelUp·Banked·HaloCourier Notify와 NotifyAll(KaijuSiren)을 삭제한다. 배달부는 `Net.Fx(player, "Bank", {Amount, Courier = true})`로 보내고, Fx.handlers.Bank가 HaloCourier 문구로 1장만 띄운다.
- **CR-L24** `G3,G1` ZoneService.luau:172-178 — PvP 면역인 장인 길드에게도 'PvP 지역이에요!' 빨간 경고가 나감. → Neutral이면 `EnteredPvPNeutral`("PvP 지역이지만 장인 길드는 공격받지 않아요.", "info")를 띄운다. Config.Text에 이 키를 추가한다.
- **CR-L25** `G2,G6,G1` MonetizationService.luau:55-67, 197-199 / FactionService.luau:268 / ClassService.luau:111 — 구매를 저장하는 동안 '보유 1장'인데, 쓰면 '변경권이 없어요, 상점에서 사세요'가 떠서 재구매를 유도함. → UseTicket이 저장 중이면 `false, "Pending"`을 반환하고, 호출부는 `TicketSaving` 토스트("변경권 구매를 저장하는 중이에요. 잠시 뒤 다시 눌러 주세요.")를 띄운다.
- **CR-L26** `G12` Panels.luau:499-535, 1306-1325 — 메뉴 '변경권 상점'을 두 번 탭하면 진영 변경권 로벅스 구매창이 뜸. → render 끝에 `inputGuardUntil = os.clock() + 0.35`를 넣고, makeButton handler와 makeCard Activated 첫 줄에서 이 시각 전이면 return한다.
- **CR-L27** `G12` Panels.luau:1064-1095 — 폰에서 제단 [무료]/[티켓] 버튼이 첫 화면 아래로 잘림. → reasonLabel과 optRow 블록(1087-1095)을 cardRow 루프 끝(1080) 다음, lore 앞으로 옮긴다.
- **CR-L28** `G12` Panels.luau:885-900 — 장인 길드의 이동 패널에 교차로 마을이 두 줄로 나옴. → 886줄 다음에 `if destId == "Crossroads" and faction ~= "None" and Config.HomeZoneId(faction) == "Crossroads" then continue end`
- **CR-L29** `G12,G1` ClassPicker.luau:280-290 / Config.luau:946-950 — 장인 길드에게도 '우리 편을 도와주세요' 전쟁 인트로가 나옴. → Config.Story.IntroNeutral(전쟁 문구 대신 '장인 길드는 전쟁·PvP에 끼지 않아요. 마음 놓고 사냥하세요!')을 추가하고, Neutral이면 그것을 쓴다.
- **CR-L30** `G12,G1` Panels.luau:619-631, 692-698 — 죽어 있는 3초 동안 이동·직업 변경을 누르면 패널만 닫히고 반응이 없음. → `isDead()` 헬퍼를 만들고, travelBlock·classBlock(그리고 rebirth·altar) 첫 줄에서 `WaitRespawn`("다시 살아난 뒤에 할 수 있어요.")을 반환한다.
- **CR-L31** `G10,G8` Util.luau:70 / HUD.luau:1389 / QuestService.luau:234 — Gold 퀘스트가 '3.2K/3.2K'로 보이는데 아직 미완료임. → HUD는 Target<10000이면 정수 그대로 표시한다(CR-M27과 같은 줄). QuestService 234는 `string.format(t.Text, tostring(target))`
- **CR-L32** `G10` HUD.luau:1865-1874 — 'N마리 더!' 평균에 황금(골드 ×10) 보상이 섞여 남은 마리 수가 3~10배 적게 표시됨. → onFx에서 `if data.Golden == true then return end`로 표본에서 뺀다.
- **CR-L33** `G10` HUD.luau:803 — 메뉴 버튼에 'M' 키 배지가 남아 있지만 M은 세계지도를 엶. → `keyHint(ui.menu, "M", ...)`를 삭제한다. round2의 '지도' 칩에 붙인다.
- **CR-L34** `G10,G11,GW [SPEC]` UIKit.luau:752 — IgnoreGuiInset=true라 노치를 무시해, 아이폰 가로 화면에서 퀘스트 배지와 메뉴 끝이 가려짐. → `gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets`와 `gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None`을 둘 다 넣는다. EventHUD:186, Fx:768, WorldMap:1288의 ScreenGui에도 적용한다. A3-H4 문구를 고치고 CR-L48을 다시 확인한다.
- **CR-L35** `G10` HUD.luau:603-611, 1916-1917 — 폰에서 이동 바(화면 60% 고정)가 업그레이드 버튼 밑에 깔려 '이동 중... N초'가 가려짐. → buildTravel panel에 `ZIndex = 3`을 준다(Active=false라 입력은 통과). 위로 옮기면 칩·토스트와 겹치므로 옮기지 않는다.
- **CR-L36** `G10,G11` HUD.luau:404-418, 472-477, 1796-1798 / EventHUD.luau:301-308, 492 — 좁은 폰에서 전쟁 게이지·이벤트 줄·칩이 스탯 블록·단골 코너와 겹침(HEAD는 실제 폭 630px 미만만 해당). → applyLayout에서 `warW = clamp(rightX - leftX, 200, WAR_W)`와 cx를 클램프해 Size·Position을 정하고, `HUD.TopCenterX/W`를 공개한다. Bar/Info는 `UDim2.new(1,0,0,h)`로 바꾼다. EventHUD.layout은 이 값으로 Strip을 배치하고, Tug/TugSub는 scale, TugCenterText는 (1,-208,1,-8)로 바꾼다.
- **CR-L37** `G11,G10` EventHUD.luau:433-441, 479-494 — 개인 라인(72% 고정, ZIndex 3)이 폰에서 퀘스트 행·발사 버튼 밑에 깔려 자루 남은 초가 가려짐. → HUD.applyLayout 끝에 `HUD.Layout = {W, H, ClusterTop = rowY - UPGRADE_H/2}`를 공개한다. EventHUD.layout은 `y = min(0.72H, ClusterTop - 8 - PERSONAL_H/2)`, 폭 `min(PERSONAL_W, W - 24)`로 두고 key에 포함한다. Personal의 ZIndex는 6으로 올린다.
- **CR-L38** `G10` UIKit.luau:55-57, 443, 762-766 — 폰에서도 토스트 4개·폭 460 고정이라 업그레이드·발사 버튼을 덮음. → 뷰포트 높이가 500 미만이면 최대 2개로 줄이고, 홀더 폭은 `min(460, 화면폭 / scale × 0.45)`로 한다.
- **CR-L39** `G11` Fx.luau:821-835 — 콤보 'x12' 라벨이 오른쪽 중앙에 고정이라 작은 폰과 폴백 배치에서 메뉴·자동 버튼을 가림. → AnchorPoint (0.5,0.5), `fromScale(0.5, 0.66)`, 120×24, 가운데 정렬, `addTextConstraint(comboLabel, 24)`로 바꾼다. 마일스톤 라벨도 같은 x로 옮긴다.
- **CR-L40** `G12` Panels.luau:384-404, 975, 1193-1195 / ClassPicker.luau:415, 417, 465 / FactionPicker.luau:418 — TextScaled=false인 14px 글자가 폰에서 10.5px로 줄어듦. → addText에 `TextSize = math.max(opts.Size or 18, 15)`, constrainText는 TextScaled일 때만 붙인다. 피커의 14는 15로 바꾸고, newLabel에도 최소 15를 둔다.
- **CR-L41** `G12,GW` Panels.luau:765-775 / FactionPicker.luau:382 / ClassPicker.luau:433 / WorldMap.luau:1429, 1513-1531 — 폰에서 패널 X·뒤로 버튼이 실제 33pt(44pt 미만)이고 서로 7.5px 붙어 있음. → 터치 기기면 `th = max(44, ceil(44 / s))`로 닫기·뒤로 버튼 크기, 위치, content 오프셋을 다시 잡는다(버튼은 모듈 변수로 올림). WorldMap 버튼은 `max(52, ceil(44 / s))`로 한다.
- **CR-L42** `G11` Fx.luau:48-49 — Config.HitFeel의 FlashRadius/MergeRadius를 읽지 않고 3으로 하드코딩함. → `HIT_CFG.MergeRadius or 3`, `HIT_CFG.FlashRadius or 3`
- **CR-L43** `G11` EventHUD.luau:39, 741-747 — 화면 가장자리 화살표가 상단바 영역(y≈23~57)에 그려져 H4를 위반하고 Roblox 버튼과 겹침. → layout()에서 인셋을 cachedInset으로 저장한다. placeArrow에서 `topMin = max(EDGE_MARGIN, cachedInset + TOP_PAD + 글리프 높이/2)`보다 위면 edge.Y를 내리고, 라벨도 그 아래로 둔다.
- **CR-L44** `GW,G12,G5,G1` Config.luau:293 / FactionPicker.luau:36, 299-306 / CharacterVisuals.luau:17, 266 / WorldMap.luau:141-176 — ⚙ 같은 기호가 □(두부)로 보임(HEAD에서는 HUD·Panels만 고침). → Neutral.Emblem과 폴백을 '장'으로, WorldMap Guild는 Emblem 값, Kaiju는 '괴', Market은 '상'으로 바꾼다. 나머지(✦◯◆◎▣✪◈●−)는 Studio에서 확인한 뒤 바꾼다. HEAD의 HUD glyphSafe는 Util로 옮겨 같이 쓴다.
- **CR-L45** `GW` WorldMap.luau:36, 46, 1009-1019, 1046-1047 — 높이 약 368px 미만 폰에서는 최대 확대(3×)에도 교차로 랜드마크·발판 이름이 나오지 않음. → `updateDetail(ppsL, vpWidthL, fitL)`로 바꾸고, labels 임계값은 `min(LABEL_PPS, fitL × ZOOM_MAX × 0.9)`, icons는 `min(ICON_PPS, maxL × 0.5)`로 한다. applyView는 fit/s를 넘긴다.
- **CR-L46** `GW` WorldMap.luau:545-558 — Config.Map.Roads를 읽지 않고 길을 직접 계산함(서쪽 길 없음, 광장 관통, 폭 14 대 실제 16). → `roadsData = legacy and {} or readLands(map.Roads)`로 바꾸고, 비어 있을 때만 기존 계산을 폴백으로 쓴다.
- **CR-L47** `GW` WorldMap.luau:48, 183, 1233, 1653-1660 — 쓸모없어진 KEY_GUARD가 M을 누른 직후 0.35초 안에 열린 휴가 자동 팝업이나 제단 패널을 닫음(휴가 팝업은 그 세션에 다시 뜨지 않음). → tick을 `if panelsOpen() then WorldMap.Close() return end`로 바꾸고 KEY_GUARD와 lastKeyAt을 삭제한다.
- **CR-L48** `GW` WorldMap.luau:1079-1082, 1117-1121, 1156-1160, 1180, 1249 — 휠·핀치 확대 기준점과 휠을 흡수하는 영역이 상단 인셋만큼 어긋남. → `guiOrigin()`(root.Parent의 AbsolutePosition)을 만들고, zoomAtAbs와 pointInViewport에서 `viewport.AbsolutePosition - guiOrigin()`을 쓴다. 1156 주석도 바로잡는다.
- **CR-L49** `G4` CombatService.luau:618-631, 775 — 모든 Swing/Release Fx를 거리와 상관없이 전원에게 보냄(다른 존 클라이언트는 받아서 버림). → 공격자 본인과, center에서 `FxCullDistance + 40 + radius` 안에 있는 플레이어에게만 `Net.Fx(rp, ...)`로 보낸다. TECH_SPEC 1782/1806을 갱신한다.
- **CR-L50** `G8,G10,G1` QuestService.luau:423-463 / HUD.luau:1190, 1942 — QuestsJson(500~800B)을 Player 속성으로 써서 20명 전원에게 복제됨. → Net Names에 'Quests' 리모트를 추가하고 값이 바뀔 때만 FireClient한다. HUD.Init의 동기 구간에서 OnClientEvent를 연결하고, OnAttr 목록에서 QuestsJson을 뺀다. TECH_SPEC 2281/2643을 갱신한다.
- **CR-L51** `리드` docs/GDD.md:9 — GDD에 장인 길드가 전혀 없음. → '5-8 장인 길드' 절을 추가한다(PvP 완전 면역, 전쟁·저울 제외, 홈=교차로, 직업명, 제작은 페이즈2). 1장, 5-5, 9장, 12장 문구도 고친다.

## reviewer_spec_v2 항목 상태

**아직 남은 것 (S2-ID → CR)**
- HIGH:
  - H1 → CR-M9 (무적·재생은 고쳐졌고, 교차로 BankAll이 남음)
  - H2 → CR-H1
  - H5 → CR-M17 (대기열은 생겼고, 1.0초 양보 창이 남음)
- MED:
  - M6 → CR-M18, M7 → CR-M19, M8 → CR-M20, M10 → CR-M3, M11 → CR-M21
  - M12 → CR-M14, M13 → CR-M15, M14 → CR-M12, M15 → CR-M11, M16 → CR-M7
  - M20 → CR-M16, M25 → CR-M25
  - M22 → CR-M1 (고쳐진 것처럼 보이지만 FIFO가 아님)
  - M23 → CR-M2 (PlayerLeaving 중복은 고쳐졌고, 셧다운 처리가 남음)
- LOW:
  - L2 → CR-L21, L3 → CR-L12, L6 → CR-L22, L7 → CR-L23
  - L10 → CR-L9, L11 → CR-L24, L12 → CR-L51, L14 → CR-L10
  - L16 → CR-L40, L18 → CR-L39, L19 → CR-L38
  - L13 → CR-M13 (MED로 상향)
- H3 잔여 → CR-L11

**고쳐진 것**
- H3 (잔여는 CR-L11), H4
- M1, M2, M3, M4, M5, M9, M17
- M18: 환생으로 진영을 바꾸면 LastSwitchTime을 기록해 제단 10분 쿨다운이 걸린다. 30분 StayLock은 아니다.
- M19: 피해자별 900초 쿨다운 방식으로 고쳐졌다.
- M21: 롤백은 남았지만, 결제 처리 중 UseTicket을 막아 이중 사용은 막힌다.
- M24: 세로 겹침은 고쳐졌다. 가로 겹침은 CR-L36이다.
- M26, M27
- L1, L4 (배지 문구는 '안내'), L5, L8, L9, L17
- L15: 선택 사항으로 ClassService.luau:111 앞에 `if useTicket and Level <= 1 and XP <= 0 then useTicket = false end` 서버 가드를 둘 수 있다.

**해당 없음**: 없음

## 그룹별 체크리스트

> **2026-10-03 재검증 기록:** 아래 원본 체크리스트는 구현 항목 목록이며, 체크 표시 자체가 플레이테스트 통과를 뜻하지 않는다.
> 정적 대조에서 발사 동료 5초 쿨다운, 이동 검사(아직 로그 전용), 괴수 발사 8%/흡혈 기본 체력 상한,
> 실제 피해 합산, 존 밖 몬스터 공격 차단, 저장 슬롯 FIFO/이전 세션 대기, 저장 PairCD, 셧다운 벌금 면제,
> 현재 레벨 기준 퀘스트 보상 상한, Quests 전용 리모트, 퀘스트 입력 잠금·교체 확인,
> 진영/직업 선택창 0.6초 입력 잠금을 코드에서 확인했다. 계약은 SPEC_ADDENDUM A16에 이미 있다.
> 전체 33개 파일 컴파일, 동기화, 15초 시작 테스트와 실제 진영/직업 선택·전투·퀘스트·지도(M)·거위·괴수
> 기본 동작 확인을 완료했다. 결과와 스크린샷은 [스튜디오 검증 기록](r1_studio_verify_2026-10-03.md)을 본다.
> 단일 플레이/메모리 모드 검증이므로 다인 PvP·저장/재접속·퇴장 정산 및 이동 오탐 조건 전체는 미검증이다.

**G1 Config/Util/Net**
- [ ] CR-H1 Config.Charge.HaloAllyStackCooldown = 5
- [ ] CR-H2 Config.Travel.ZoneTick 0.5 → 0.2
- [ ] CR-M3 Config.Kaiju.PairRewardCooldown = 1800
- [ ] CR-M4 Data.Defaults.PairCD = {}
- [ ] CR-M7 Config.Kaiju.ReleaseCapPct = 0.08
- [ ] CR-M12 Data.Defaults SavedBully/SavedBullyAt/SavedStars/SavedStarsAt
- [ ] CR-M15 Config.Bully.BaitMinPct = 0.2
- [ ] CR-M22 Config.Map.Pads 좌표를 길 밖으로
- [ ] CR-M27 Kill/Golden 퀘스트 문구에 몬스터 이름 자리
- [ ] CR-L9 Text.BlockedBully
- [ ] CR-L22 Charge.PerfectGrace = 0.25
- [ ] CR-L24 Text.EnteredPvPNeutral
- [ ] CR-L25 Text.TicketSaving
- [ ] CR-L29 Story.IntroNeutral
- [ ] CR-L30 Text.WaitRespawn
- [ ] CR-L44 Neutral.Emblem '장'
- [ ] CR-L50 Net 'Quests' 리모트

**G2 Main/DataService/PlayerService/MonetizationService/Health**
- [ ] CR-H2 PlayerService 155·260에서 MarkTeleported 호출
- [ ] CR-M1 DataService 슬롯 FIFO + 재접속 대기
- [ ] CR-M2 IsShuttingDown, onClose PlayerLeaving 선발화, leftFired 분기
- [ ] CR-M4 PlayerService.PairReady
- [ ] CR-M20 PlayerService.GetLastActive
- [ ] CR-L2 onJoin closing 분기 Release 동안 joining 유지
- [ ] CR-L3 상위 Version 저장본 로드 거부
- [ ] CR-L16 PlayerService 낙하 구조 삭제
- [ ] CR-L25 UseTicket "Pending" 반환

**G3 MapBuilder/ZoneService/WarService**
- [ ] CR-H2 validateMove/IsPlausible/MarkTeleported, 발판 거리 검사
- [ ] CR-M18 WarService.AddPoints(poolN)
- [ ] CR-M19 전쟁 1인당 점수 분모를 평균 인원으로
- [ ] CR-M22 ensurePads 재배치·글자 갱신 + tools/preview_map.lua PADS
- [ ] CR-L17 경계벽 바닥을 수면 −20까지
- [ ] CR-L18 [SPEC] 이동 채널 즉시 취소·토큰
- [ ] CR-L20 ClockTime 전진 보간
- [ ] CR-L24 장인 길드 PvP 진입 토스트

**G4 CombatService**
- [ ] CR-H1 lastAllyStackAt 쿨다운
- [ ] CR-H2 Swing/Release에 IsPlausible + MinLevel 검사
- [ ] CR-M7 괴수 발사 상한 ReleaseCapPct
- [ ] CR-M8 괴수 흡혈 상한을 기본 체력 기준으로
- [ ] CR-M10 DamagePlayer return applied, PlayerDamaged(applied), total·totalDealt를 실제 피해로
- [ ] CR-M17 자동 양보 창 = SwingInterval + 0.3
- [ ] CR-M23 applied>0이면 항상 Hurt, PvP 히트에 V
- [ ] CR-L21 거위 히트를 RegisterHit 반환값으로
- [ ] CR-L22 PerfectGrace, 자동 발사 직후 수동 실패 토스트 생략
- [ ] CR-L49 Swing/Release Fx를 근처에만 송신

**G5 MonsterService/CharacterVisuals**
- [ ] CR-M5 visibleTo 존 필터 + DamageMonster 존 검사
- [ ] CR-M18 killRecord WarShare
- [ ] CR-L13 cappedTargets 비례 배분
- [ ] CR-L14 groundPoint occupied 검사
- [ ] CR-L44 CharacterVisuals 폴백 '장'

**G6 FactionService/ClassService/JusticeService**
- [ ] CR-H2 nearAltar IsPlausible, JusticeService 297 MarkTeleported
- [ ] CR-M12 SavedBully 기록·복원
- [ ] CR-M20 Recompute에서 잠수·새싹·마을 대기 제외
- [ ] CR-L1 bully 정리 defer, PlayerRemoving은 미준비 플레이어만
- [ ] CR-L5 GetCombatPower
- [ ] CR-L7 GetUnderdogCounts
- [ ] CR-L9 깡패 상태로 장인 길드 전환 차단
- [ ] CR-L10 가입 보너스 시 LastSwitchTime 기록
- [ ] CR-L11 점수 0이면 티켓 미차감
- [ ] CR-L25 Faction/Class의 Pending 토스트

**G7 PvPService/GrudgeService**
- [ ] CR-M3 pairOk일 때만 addStar
- [ ] CR-M4 koLog/pairReward/bullyBountyAt/lastSteal/lastRefund/lastAvenge → PairCD
- [ ] CR-M6 자루 entry.Rebirths, 환생한 피해자 환불 차단
- [ ] CR-M11 별 보유자 로그아웃 현상금
- [ ] CR-M12 SavedStars 기록·복원
- [ ] CR-M14 미끼 방어·괴수 킬러는 깡패 제외
- [ ] CR-M15 dmgLog + BaitMinPct
- [ ] CR-L4 마을·무피해 사망은 별 유지
- [ ] CR-L5 378 약자 판정에 GetCombatPower
- [ ] CR-L6 환불·복수 보너스 키를 개인 단위로

**G8 ProgressionService/ShopService/QuestService**
- [ ] CR-M2 셧다운 시 CombatLogPenalty 면제
- [ ] CR-M6 capTo, LevelReset 신호
- [ ] CR-M9 Siren/Active 괴수는 BankAll 건너뜀
- [ ] CR-M16 레벨업 풀회복 조건
- [ ] CR-M21 휴가 소수 일수, 자정 상자 지급
- [ ] CR-M27 newQuest 문구, publish 소수 1자리
- [ ] CR-L7 rebirthBonusFor에 GetUnderdogCounts
- [ ] CR-L9 TryRebirth 깡패 장인 전환 차단
- [ ] CR-L12 진영 변경 재생성 시 보상 유지
- [ ] CR-L23 LevelUp/Banked/HaloCourier Notify 삭제
- [ ] CR-L31 Gold 퀘스트 문구 정수
- [ ] CR-L50 QuestsJson → 'Quests' 리모트

**G9 GooseService/KaijuService**
- [ ] CR-M3 쌍 쿨다운 1800, 주머니 이전 상한
- [ ] CR-M4 poolPaidAt → PairCD
- [ ] CR-M11 괴수 로그아웃 시 HandleKaijuDeath(leaving)
- [ ] CR-M13 안전 지대 발구르기는 attacker 없이
- [ ] CR-L8 상대 진영 없으면 거위 무승부
- [ ] CR-L19 지급액 기준 처치 공지
- [ ] CR-L21 GetPosition sideOffset, RegisterHit 반환값
- [ ] CR-L23 NotifyAll(KaijuSiren) 삭제

**G10 ClientMain/UIKit/HUD**
- [ ] CR-M24 받기 직후·행 변경 직후 교체 잠금
- [ ] CR-M25 교체 확인창, 터치 기기는 퀘스트 칩 오버레이
- [ ] CR-M27 퀘스트 진행 소수 표시
- [ ] CR-L31 Gold 목표 정수 표시
- [ ] CR-L32 황금 보상을 평균에서 제외
- [ ] CR-L33 메뉴 'M' 배지 삭제
- [ ] CR-L34 [SPEC] DeviceSafeInsets
- [ ] CR-L35 이동 바 ZIndex 3
- [ ] CR-L36 전쟁 게이지 폭 클램프, TopCenterX/W 공개
- [ ] CR-L37 HUD.Layout(ClusterTop) 공개
- [ ] CR-L38 폰 토스트 2개·폭 45%
- [ ] CR-L50 'Quests' 리모트 수신

**G11 Fx/EventHUD**
- [ ] CR-M23 showHits에서 내 PvP 피격 중복 제외
- [ ] CR-L15 남의 개인 몬스터 숨김
- [ ] CR-L23 Bank Courier 문구 1장
- [ ] CR-L34 EventHUD/Fx ScreenGui 안전 영역
- [ ] CR-L36 Strip을 TopCenter 기준으로
- [ ] CR-L37 개인 라인 위치·ZIndex
- [ ] CR-L39 콤보 라벨 가운데 아래
- [ ] CR-L42 FlashRadius/MergeRadius를 Config에서
- [ ] CR-L43 화살표 상단 인셋 회피

**G12 Panels/FactionPicker/ClassPicker**
- [ ] CR-M21 휴가 일수 ceil 표시
- [ ] CR-M26 피커 열림 직후 0.6초 잠금
- [ ] CR-L7 언더독 미리보기
- [ ] CR-L9 altarBlock 깡패 문구
- [ ] CR-L26 render 직후 입력 가드
- [ ] CR-L27 제단 버튼을 위로
- [ ] CR-L28 장인 길드 교차로 중복 제거
- [ ] CR-L29 Neutral 인트로
- [ ] CR-L30 사망 중 안내
- [ ] CR-L40 최소 글자 15
- [ ] CR-L41 터치 버튼 44pt
- [ ] CR-L44 FactionPicker 폴백 '장'

**GW WorldMap**
- [ ] CR-L34 자체 ScreenGui 안전 영역
- [ ] CR-L41 버튼 터치 크기
- [ ] CR-L44 GLYPH 교체
- [ ] CR-L45 라벨 임계값을 화면 기준으로
- [ ] CR-L46 Config.Map.Roads 사용
- [ ] CR-L47 KEY_GUARD 삭제
- [ ] CR-L48 확대 기준점 guiOrigin 보정

**리드(문서)**
- [ ] CR-L51 GDD 장인 길드 절
- [ ] CR-M6 A13 '수령 시점 레벨 상한'
- [ ] CR-M27 killWeight 이탈 기록
- [ ] CR-M23 TECH_SPEC 1828
- [ ] CR-M1 impl_notes:81
- [ ] CR-L4 TECH_SPEC 2013
- [ ] CR-L5·CR-L6 GDD 문구
- [ ] CR-L18·CR-L34·CR-L49·CR-L50 스펙 변경 반영

## 플레이테스트로 확인할 것

Studio의 Test > Clients and Servers(클라이언트 2~3명)를 기준으로 한다. 필요한 수치는 서버 커맨드 바로 맞춘다.

- CR-H1: 기사단 2명이 슬라임 옆에서 10스택 발사를 번갈아 한다. 상대 Charge 속성이 5초 안에 다시 +10 되지 않는지 본다.
- CR-H2: 클라이언트 커맨드 바에서 HumanoidRootPart.CFrame을 HornsTown이나 해골 유적으로 옮긴다. 원위치로 되돌려지는지, 금고 입금과 Swing이 안 되는지 본다. 메뉴 이동, 리스폰, 낙하 구조, 깡패 크기 변화 때 오탐으로 되돌려지지 않는지도 확인한다.
- CR-M1: 서버 커맨드 바에서 같은 userId로 acquireSlot을 두 번 task.spawn한다. 먼저 요청한 쪽이 먼저 잡는지 print로 본다. 실서버에서는 나가기 직후 재접속해 출력에 'aborted: a newer session'이 없는지 본다.
- CR-M2: PvP 전투 태그 상태에서 서버를 종료한다(Studio 정지). 재접속했을 때 금고가 소지금 100%를 받았는지, 자루 환불이 들어왔는지 본다.
- CR-M3: 같은 쌍으로 괴수를 처치해 1800초 안에 발행이 다시 없는지, 주머니 몫이 Lv×100을 넘지 않는지 본다.
- CR-M4: KO 후 PairCD가 DataService 데이터에 기록되는지, 재접속 뒤에도 쿨다운이 유지되는지 본다.
- CR-M5: Lv5 마법사로 (563,0,0)에서 고블린을 자동 공격한다. 헛스윙이고 데미지가 없어야 한다. 숲 안에서는 정상이어야 한다.
- CR-M6: Lv60으로 일일을 완료하고 받지 않은 채 무료 직업 변경을 한다. 받았을 때 XP가 Lv1 기준 상한인지 본다. 환생 뒤 자루 환불이 없는지도 본다.
- CR-M7: 기사에게 Charge 149를 주고 괴수에게 발사한다. 피해가 MaxHealth의 8%인지 본다.
- CR-M8: 괴수 상태로 해골 무리를 자동 공격한다. 스윙당 회복이 기본 체력의 3% 이내인지 본다.
- CR-M9: 괴수 상태로 교차로에 서 있을 때 CarriedGold가 그대로인지 본다.
- CR-M10: 10스택 발사로 슬라임 1마리만 맞힌다. 기사단 회복이 약 1HP인지 본다. 괴수 막타의 dmg 기록이 남은 HP와 같은지도 본다.
- CR-M11: 괴수를 때린 기사가 있는 상태에서 괴수 클라이언트를 종료한다. 기사 금고에 보상이 들어오는지 본다.
- CR-M12: BullyStacks 3·별 3으로 재접속했을 때 감쇠만큼만 줄어 복원되는지 본다.
- CR-M13: 말랑 초원에서 발구르기에 맞은 뒤 슬라임에게 죽는다. 약탈과 별이 없어야 한다. 괴수가 일반 스윙으로 그 플레이어를 못 때리는지도 본다.
- CR-M14: 뿔이 먼저 3회 공격하다 죽어 줬을 때 기사 BullyStacks가 0으로 유지되는지 본다.
- CR-M15: 약자가 강자에게 1타만 넣은 뒤 KO되면 깡패 KO로 처리되는지 본다.
- CR-M16: 전투 태그 상태에서 퀘스트를 받아 레벨업한다. HP 비율이 유지되는지 본다.
- CR-M17: 자동 ON인 마법사가 버튼을 누른 채 적을 공격할 때 모든 스윙이 플레이어에게 맞는지 본다.
- CR-M18: 같은 진영 2명이 몬스터 1마리를 잡았을 때 진영 점수가 +1인지 본다.
- CR-M19: 종료 직전 한 진영 인원을 빼도 승패가 평균 인원 기준으로 유지되는지 본다.
- CR-M20: 고레벨 계정을 마을에 60초 이상 세워 두면 상대 S가 변하지 않는지 본다.
- CR-M21: 일일 1개만 하고 서버 날짜를 넘기면 VacationDays가 소수로 늘어나는지 본다. 3번째를 완료만 해 둔 경우 자정에 상자가 지급되는지 본다.
- CR-M22: 교차로 동쪽 길 가운데를 걸어 초원 다리까지 순간이동 없이 가는지 본다. 세계지도와 실제 발판 위치가 일치하는지도 본다.
- CR-M23: 수동 스윙에 맞은 피해자 화면에 빨간 숫자와 테두리가 뜨는지, 발사 숫자가 중복되지 않는지 본다.
- CR-M24: 튜토리얼 받기를 3연타해도 다음 일일 퀘스트가 교체되지 않는지 본다.
- CR-M25: 폰 에뮬레이터(844×390)에서 교체를 누르면 확인창이 뜨는지 본다. 조이스틱 영역에 퀘스트 버튼이 없는지도 본다.
- CR-M26: 폰 에뮬레이터에서 '이 편으로!'를 빠르게 2번 탭해도 직업 화면이 남아 있는지 본다.
- CR-M27: Lv25로 황금 고블린을 잡았을 때 '0.4/1'과 '황금 해골 병사 1마리' 문구가 보이는지 본다.
