-- Real source is injected by test_skill_release.py. These doubles replace only engine/service boundaries.
local checks = 0
local function check(value, message) assert(value, message); checks += 1 end
local function execute(source, env)
	local fn, err = loadstring(source); assert(fn, err)
	setfenv(fn, setmetatable(env or {}, { __index = getfenv() }))
	return fn()
end
local function signal()
	local callbacks = {}
	return { Connect = function(_, fn) table.insert(callbacks, fn); return { Disconnect = function() end } end,
		Fire = function(_, ...) for _, fn in callbacks do fn(...) end end }
end
local vmt = {}
local function vec(x, y, z) return setmetatable({ X=x or 0, Y=y or 0, Z=z or 0, __kind="Vector3" }, vmt) end
vmt.__add = function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vmt.__sub = function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vmt.__mul = function(a,b)
	if type(a)=="number" then a,b=b,a end
	if type(b)=="number" then return vec(a.X*b,a.Y*b,a.Z*b) end
	return vec(a.X*b.X,a.Y*b.Y,a.Z*b.Z) -- Vector3 * Vector3 is component-wise (aim-cone flattening)
end
vmt.__index = function(v,key)
	if key=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
	if key=="Unit" then local n=v.Magnitude; return vec(v.X/n,v.Y/n,v.Z/n) end
	if key=="Dot" then return function(a,b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end
end
local enum = setmetatable({}, { __index=function(_,kind)
	return setmetatable({}, { __index=function(_,id) return kind.."."..id end }) end })
local nativeEnv = { Vector3={new=vec}, Vector2={new=vec}, Color3={new=vec,fromRGB=vec},
	BrickColor={new=function(value) return value end}, Rect={new=function(...) return {...} end},
	UDim2={fromScale=function(...) return {...} end}, Enum=enum }
local serial = 0
local function fixture(classId, fac)
	serial += 1
	local config = execute(CONFIG_SOURCE, nativeEnv)
	assert(config.BasicSkill, "Config.BasicSkill must be present; production data is not replaced by test tuning")
	local f={Config=config, Now=100, Ready=true, Fx={}, Notices={}, Warnings={}, Events={}, Monsters={}, Players={}, Tasks={}, Delays={}, Active=0}
	local playerService = { PlayerReady=signal(), PlayerLeaving=signal(), CharacterDied=signal(), CharacterSpawned=signal() }
	local players = { GetPlayers=function() return f.Players end }
	function f:NewPlayer(id, factionId)
		local p={__kind="Instance",Parent=players,UserId=id,Name="Test"..id,
			Attrs={ClassChosen=true,Class=classId or "Warrior",Faction=factionId or "Neutral",Level=1,WeaponTier=1},
			Root={Parent=true,Position=vec(330,0,0),CFrame={LookVector=vec(1,0,0)}},
			Hum={Health=100,MaxHealth=100},Character={FindFirstChild=function() return nil end}}
		function p:IsA(kind) return kind=="Player" end
		function p:GetAttribute(key) return self.Attrs[key] end
		function p:SetAttribute(key,value) self.Attrs[key]=value end
		function p.Hum:TakeDamage(amount) self.Health=math.max(0,self.Health-amount) end
		table.insert(f.Players,p)
		return p
	end
	f.Player=f:NewPlayer(serial,fac)
	local util = { Signal={new=signal}, Now=function() return f.Now+1000 end,
		IsAlive=function(p) return p.Hum and p.Hum.Health>0 and p.Root~=nil end,
		GetRoot=function(p) return p.Root end, GetHumanoid=function(p) return p.Hum end,
		GetCharacter=function(p) return p.Character end, FindPart=function() return nil end,
		RoundDamage=function(v) return math.max(0,math.floor(v+0.5)) end,
		FlatDistance=function(a,b) return math.sqrt((a.X-b.X)^2+(a.Z-b.Z)^2) end,
		Warn=function(_,err) table.insert(f.Warnings,err) end, Random={NextNumber=function() return 1 end} }
	local clock={clock=function() return f.Now end}
	util.RateLimit=execute(RATE_SOURCE,{os=clock})
	local remotes={}
	local net={Get=function(name)
		if not remotes[name] then remotes[name]={OnServerEvent=signal()} end
		return remotes[name]
	end, Notify=function(p,text,kind) table.insert(f.Notices,{p,text,kind}) end,
		Fx=function(p,kind,data) table.insert(f.Fx,{Player=p,Kind=kind,Data=data}) end}
	playerService.IsReady=function() return f.Ready end
	playerService.GetReadyPlayers=function() return f.Players end
	playerService.MarkActive=function() f.Active+=1 end
	playerService.SetStat=function(p,key,value) p.Attrs[key]=value end
	local world={GetServerTimeNow=function() return f.Now+1000 end}
	local services={Players=players,ReplicatedStorage={Shared={Config="Config",Util="Util",Net="Net"}},
		RunService={IsStudio=function() return true end}}
	local env={game={GetService=function(_,name) return assert(services[name],name) end},workspace=world,
		typeof=function(v) return type(v)=="table" and v.__kind or type(v) end, Vector3={new=vec},os=clock,
		require=function(name) return ({Config=config,Util=util,Net=net})[name] end,print=function() end,
		task={spawn=function(fn) table.insert(f.Tasks,fn) end, wait=function(t) coroutine.yield(t) end,
			delay=function(_,fn) table.insert(f.Delays,fn) end,defer=function(fn) fn() end}}
	local registry={PlayerService=playerService,
		FactionService={FactionChanged=signal(),GetFaction=function(p) return p.Attrs.Faction end,
			GetPerks=function(p) return config.Factions[p.Attrs.Faction] end},
		ClassService={ClassChanged=signal(),GetClass=function(p) return p.Attrs.Class end,
			GetClassDef=function(p) return config.Classes[p.Attrs.Class] end},
		PvPService={GetStars=function() return 0 end,HasRevenge=function() return false end,
			CanAttack=function() return f.AllowPvP==true end,BreakProtection=function() f.BrokenProtection=true end,
			HandleNonPvPDeath=function() end,HandleKO=function() end},
		JusticeService={GetDamageMult=function() return 1 end},
		KaijuService={GetState=function(p) return p.Attrs.KaijuState or "None" end},
		GooseService={GetPosition=function() return nil end},GrudgeService={OnCarrierDown=function() end},
		ZoneService={IsPlausible=function() return not f.BlockPosition end,IsTown=function() return false end},
		MonsterService={GetMonstersInRadius=function() return f.Monsters end,
			DamageMonster=function(rec,amount) if f.RefuseDamage then return false end
				rec.HP=math.max(0,rec.HP-amount);rec.Alive=rec.HP>0;return not rec.Alive end}}
	local vitals=execute(VITALS_SOURCE,env); registry.VitalsService=vitals
	local combat=execute(COMBAT_SOURCE,env); registry.CombatService=combat
	vitals.Init(registry);combat.Init(registry);vitals.Start();combat.Start()
	combat.Released:Connect(function(_,info) table.insert(f.Events,info) end)
	playerService.PlayerReady:Fire(f.Player,{})
	f.Combat,f.Vitals,f.Registry,f.Remotes=combat,vitals,registry,remotes
	function f:AddMonster(position, hp)
		local rec={Alive=true,HP=hp or 10000,Root={Parent=true,Position=position or vec(335,0,0)},ZoneId="SlimeMeadow"}
		table.insert(self.Monsters,rec);return rec
	end
	function f:Skill(auto) self.Combat.Release(self.Player,auto) end
	function f:Mana(amount) assert(self.Vitals.DebugSetMana(self.Player,amount)) end
	function f:Snapshot() return {self.Player.Attrs.Mana,self.Player.Attrs.SkillReadyAt,self.Player.Hum.Health,#self.Events,#self.Fx,self.Monsters[1] and self.Monsters[1].HP} end
	function f:Unchanged(before)
		local after=self:Snapshot();for i=1,6 do check(after[i]==before[i],"rejected action mutated snapshot field "..i) end
	end
	return f
end

-- Basic skill has fixed class-adjusted damage/radius at zero gauge and pays MP through real VitalsService.
for _,classId in {"Warrior","Mage","Archer"} do
	local f=fixture(classId);local rec=f:AddMonster();local expected=f.Combat.ComputeMonsterHit(f.Player,false)*f.Config.BasicSkill.DamageMultiplier*f.Config.Classes[classId].ReleaseMult
	f:Skill(false)
	check(rec.HP==10000-math.floor(expected+0.5),classId.." fixed skill damage")
	check(f.Player.Attrs.Mana==80,classId.." MP 20 paid")
	check(#f.Events==1 and f.Events[1].Stacks==0 and f.Events[1].Perfect==false and f.Events[1].Auto==false,"legacy event flags not zero/manual")
	check(f.Events[1].MonstersHit==1 and f.Events[1].PlayersHit==0,"Released.MonstersHit (A23 skill-quest count) not reported")
	check(f.Events[1].Radius==9 and f.Fx[#f.Fx].Data.Radius==9 and f.Fx[#f.Fx].Data.Stacks==0,"fixed radius/Fx contract")
	check(f.Player.Attrs.SkillReadyAt==1103,"server deadline not mirrored")
	check(f.Player.Attrs.Charge==0 and f.Player.Attrs.ChargeCap==0 and f.Player.Attrs.PerfectUntil==0,"legacy gauge remained active")
	local before=f:Snapshot();f:Skill(false);f:Unchanged(before)
	f.Now+=2.999;f:Skill(false);f:Unchanged(before)
	f.Now+=.002;f:Skill(false);check(#f.Events==2 and f.Player.Attrs.Mana==60,"cooldown did not reopen")
end

-- Failed MP, readiness, life, root and level/anti-cheat eligibility change no combat state.
for _,mutate in {
	function(f) f:Mana(19.9) end, function(f) f.Ready=false end,
	function(f) f.Player.Hum.Health=0 end,function(f) f.Player.Root=nil end,
	function(f) f.Player.Parent=nil end,function(f) f.Player.Attrs.ClassChosen=false end,
	function(f) f.Player.Root.Position=vec(720,0,0) end,
	function(f) f.Config.AntiCheat.Enforce=true;f.BlockPosition=true end,
} do
	local f=fixture();f:AddMonster();mutate(f);local before=f:Snapshot();f:Skill(false);f:Unchanged(before)
end
do
	local f=fixture();f:AddMonster();f:Mana(0);f:Skill(false)
	check(f.Player.Attrs.SkillReadyAt==0,"failed MP consumed cooldown")
	f:Mana(20);f:Skill(false);check(#f.Events==1 and f.Player.Attrs.Mana==0,"MP refill could not immediately cast")
end

-- A23-1: auto combat starts locked and OFF; the toggle remote, direct auto entry points, the legacy AutoAttack
-- attribute and the AutoCombatLoop cannot start an attack or skill until it is unlocked and switched ON.
check(string.find(COMBAT_SOURCE,'startPlayerLoop("AutoCombatLoop", Config.Combat.AutoTick',1,true)~=nil,"AutoCombatLoop missing from CombatService.Start")
for _,classId in {"Warrior","Mage","Archer"} do
	local f=fixture(classId);f:AddMonster();local before=f:Snapshot()
	check(f.Player.Attrs.AutoAttack==false and f.Player.Attrs.AutoCombatEnabled==nil,"auto combat did not start OFF")
	f.Remotes.SetAutoAttack.OnServerEvent:Fire(f.Player,true)
	check(f.Player.Attrs.AutoCombatEnabled==nil,"locked auto remote enabled auto combat")
	f.Combat.Swing(f.Player,false);f:Skill(true);f:Unchanged(before)
	check(#f.Tasks==3,"expected Vitals regen + HP RegenLoop + AutoCombatLoop timers only")
	f.Player.Attrs.Charge=175;f.Player.Attrs.PerfectUntil=1;f.Player.Attrs.AutoAttack=true
	local intervals={}
	for _,fn in f.Tasks do
		local co=coroutine.create(fn);local ok,interval=coroutine.resume(co);check(ok,"loop setup failed")
		intervals[interval]=true
		f.Now+=10;local ok2,err=coroutine.resume(co);check(ok2,tostring(err))
	end
	check(intervals[f.Config.Combat.AutoTick]==true,"no loop runs at Config.Combat.AutoTick")
	check(#f.Events==0 and f.Monsters[1].HP==10000,"idle time triggered combat while auto combat is locked/OFF")
	check(f.Combat.GetCharge(f.Player)==0,"legacy attribute changed authoritative gauge")
end

-- Swings still obey real class shape, timing and Mage MP cost, and never charge a gauge.
for _,classId in {"Warrior","Mage","Archer"} do
	local f=fixture(classId);f:AddMonster(vec(333,0,0));f:AddMonster(vec(335,0,0));f:AddMonster(vec(336,0,0))
	f.Combat.Swing(f.Player,true)
	local hit=0;for _,m in f.Monsters do if m.HP<10000 then hit+=1 end end
	check(hit==(classId=="Archer" and 2 or 3),classId.." swing target pattern changed")
	check(f.Config.Vitals.MageSwingCost==2 and f.Config.Classes.Mage.SwingInterval==1.1,"2026-10-06 Mage tuning (cost 2, interval 1.1) changed")
	check(f.Player.Attrs.Mana==(classId=="Mage" and 100-f.Config.Vitals.MageSwingCost or 100),classId.." swing MP changed")
	check(f.Player.Attrs.Charge==0 and f.Player.Attrs.PerfectUntil==0,"manual swing gained gauge")
	local before=f:Snapshot();f.Combat.Swing(f.Player,true);f:Unchanged(before)
end

-- Remote throttle plus successful-use cooldown block repeated presses and direct-call bypass.
-- Selecting a faction does not yet authorize attacking with the default Warrior before class selection.
for _,classId in {"Warrior","Mage","Archer"} do
	local f=fixture(classId);f:AddMonster();f.Player.Attrs.ClassChosen=false
	local before=f:Snapshot();f.Combat.Swing(f.Player,true);f:Unchanged(before)
	f.Remotes.Swing.OnServerEvent:Fire(f.Player);f:Unchanged(before)
	check(f.Active==0 and #f.Fx==0,"unselected class swing produced activity/animation")
	f.Player.Attrs.ClassChosen=true;f.Remotes.Swing.OnServerEvent:Fire(f.Player)
	check(f.Monsters[1].HP<10000,"first selected-class swing was incorrectly throttled")
end
do
	local f=fixture();f:AddMonster();f.Ready=false;local before=f:Snapshot()
	f.Combat.Swing(f.Player,true);f.Remotes.Swing.OnServerEvent:Fire(f.Player);f:Unchanged(before)
end
do
	local f=fixture();f:AddMonster();f.Remotes.Swing.OnServerEvent:Fire(f.Player)
	f.Now+=f.Config.Classes.Warrior.SwingInterval-0.1
	f.Remotes.Swing.OnServerEvent:Fire(f.Player) -- one accepted jitter-early press waits for cooldown
	check(#f.Delays==2,"expected one cosmetic shove and one pending manual swing")
	f.Player.Attrs.ClassChosen=false;f.Now+=0.11;local before=f:Snapshot()
	for _,callback in f.Delays do callback() end
	f:Unchanged(before)
	f.Player.Attrs.ClassChosen=true;f.Now+=0.11;f.Remotes.Swing.OnServerEvent:Fire(f.Player)
	check(f.Monsters[1].HP<before[6],"cancelled pending swing blocked later deliberate attack")
end

-- Remote throttle plus successful-use cooldown block repeated presses and direct-call bypass.
do
	local f=fixture();f:AddMonster();for _=1,30 do f.Remotes.Release.OnServerEvent:Fire(f.Player,true,9999) end
	check(#f.Events==1 and f.Player.Attrs.Mana==80,"repeated/forged remote arguments changed skill use")
	f.Now+=.5;f.Remotes.Release.OnServerEvent:Fire(f.Player);check(#f.Events==1,"network interval bypassed gameplay cooldown")
	f.Now+=2.501;f.Remotes.Release.OnServerEvent:Fire(f.Player);check(#f.Events==2,"manual remote failed after deadline")
end

-- Cosmetic respawn/class/faction changes cannot reset skill cooldown; real respawn matches MP reset.
do
	local f=fixture();f:AddMonster();f:Skill(false);local deadline=f.Player.Attrs.SkillReadyAt
	f.Registry.PlayerService.CharacterSpawned:Fire(f.Player,{},f.Player.Hum,true)
	check(f.Player.Attrs.SkillReadyAt==deadline and f.Player.Attrs.Mana==80,"cosmetic respawn refilled skill")
	f.Registry.ClassService.ClassChanged:Fire(f.Player);f.Registry.FactionService.FactionChanged:Fire(f.Player)
	f:Skill(false);check(#f.Events==1,"class/faction change bypassed cooldown")
	f.Registry.PlayerService.CharacterSpawned:Fire(f.Player,{},f.Player.Hum,false)
	check(f.Player.Attrs.SkillReadyAt==0 and f.Player.Attrs.Mana==100,"real respawn did not reset MP/cooldown together")
	f:Skill(false);check(#f.Events==2,"real respawn could not use skill")
end

-- Halo heal retains real-damage semantics and gives no ally charge; whiffs cannot heal.
do
	local f=fixture("Warrior","Halo");local ally=f:NewPlayer(999,"Halo");ally.Hum.Health=50
	f.Registry.PlayerService.PlayerReady:Fire(ally,{});f:AddMonster();f:Skill(false)
	check(ally.Hum.Health>50,"Halo damaged-target heal disappeared")
	check(ally.Attrs.Charge==0 and ally.Attrs.PerfectUntil==0,"Halo ally regained removed gauge")
	f.Now+=4;f.Monsters={};local before=ally.Hum.Health;f:Skill(false)
	check(ally.Hum.Health==before,"empty skill healed an ally")
	check(#f.Events==2 and f.Events[2].MonstersHit==0,"whiffed skill reported a monster hit (would count for skill quests)")
end

-- PvP skill remains capped and automatic invocation never damages a victim.
do
	local f=fixture("Warrior","Horns");local victim=f:NewPlayer(999,"Halo");f.AllowPvP=true
	f.Player.Attrs.WeaponTier=f.Config.MaxWeaponTier;f:Skill(false)
	check(victim.Hum.Health==65,"PvP 35 percent cap changed")
	check(f.BrokenProtection==true,"manual PvP did not break protection")
	f.Now+=4;local before=victim.Hum.Health;f:Skill(true);check(victim.Hum.Health==before,"auto skill caused PvP damage")
end
print("SKILL_RELEASE_OFFLINE_OK checks="..checks.." Studio/API calls=0")
