-- A23-1 auto combat. Real Config, CombatService, VitalsService, Util.RateLimit and the KaijuService Released handler
-- are injected by tools/test_auto_combat.py; only engine/service boundaries are doubles (no Studio, no input).
local checks = 0
local function check(value, message) assert(value, message); checks += 1 end
local function execute(source, env, ...)
	local fn, err = loadstring(source); assert(fn, err)
	setfenv(fn, setmetatable(env or {}, { __index = getfenv() }))
	return fn(...)
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
	return vec(a.X*b.X,a.Y*b.Y,a.Z*b.Z)
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
-- opts: Class, Faction (attacker), Unlocked, Enabled (initial saved attributes)
local function fixture(opts)
	opts = opts or {}
	serial += 1
	local config = execute(CONFIG_SOURCE, nativeEnv)
	local f={Config=config, Now=100, Ready=true, Fx={}, Events={}, Monsters={}, Players={}, Tasks={}, Delays={},
		Active=0, SetStats={}, PlayerDamage={}, AllowPvP=true}
	local playerService = { PlayerReady=signal(), PlayerLeaving=signal(), CharacterDied=signal(), CharacterSpawned=signal() }
	local players = { GetPlayers=function() return f.Players end }
	function f:NewPlayer(id, factionId, position, attrs)
		local p={__kind="Instance",Parent=players,UserId=id,Name="Test"..id,
			Attrs={ClassChosen=true,Class="Warrior",Faction=factionId or "Neutral",Level=1,WeaponTier=1},
			Root={Parent=true,Position=position or vec(330,0,0),CFrame={LookVector=vec(1,0,0)}},
			Hum={Health=100,MaxHealth=100},Character={FindFirstChild=function() return nil end}}
		for k,v in attrs or {} do p.Attrs[k]=v end
		function p:IsA(kind) return kind=="Player" end
		function p:GetAttribute(key) return self.Attrs[key] end
		function p:SetAttribute(key,value) self.Attrs[key]=value end
		function p.Hum:TakeDamage(amount) self.Health=math.max(0,self.Health-amount) end
		table.insert(f.Players,p)
		return p
	end
	f.Player=f:NewPlayer(serial,opts.Faction or "Halo",nil,{Class=opts.Class or "Warrior",
		AutoCombatUnlocked=opts.Unlocked,AutoCombatEnabled=opts.Enabled})
	local util = { Signal={new=signal}, Now=function() return f.Now+1000 end,
		IsAlive=function(p) return p.Hum and p.Hum.Health>0 and p.Root~=nil end,
		GetRoot=function(p) return p.Root end, GetHumanoid=function(p) return p.Hum end,
		GetCharacter=function(p) return p.Character end, FindPart=function() return nil end,
		RoundDamage=function(v) return math.max(0,math.floor(v+0.5)) end,
		FlatDistance=function(a,b) return math.sqrt((a.X-b.X)^2+(a.Z-b.Z)^2) end,
		Warn=function(_,err) error("unexpected warning: "..tostring(err)) end, Random={NextNumber=function() return 1 end} }
	local clock={clock=function() return f.Now end}
	util.RateLimit=execute(RATE_SOURCE,{os=clock})
	local remotes={}
	local net={Get=function(name)
		if not remotes[name] then remotes[name]={OnServerEvent=signal()} end
		return remotes[name]
	end, Notify=function() end,
		Fx=function(p,kind,data) table.insert(f.Fx,{Player=p,Kind=kind,Data=data}) end}
	playerService.IsReady=function() return f.Ready end
	playerService.GetReadyPlayers=function() return f.Players end
	playerService.MarkActive=function(p) if p==f.Player then f.Active+=1 end end
	playerService.SetStat=function(p,key,value) table.insert(f.SetStats,{p,key,value}); p.Attrs[key]=value end
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
			-- PvP is fully allowed here, so only the auto/manual branch decides whether a player can be hit
			CanAttack=function() return f.AllowPvP==true end,BreakProtection=function(p) f.BrokenProtection=p end,
			HandleNonPvPDeath=function() end,HandleKO=function() end},
		JusticeService={GetDamageMult=function() return 1 end},
		KaijuService={GetState=function(p) return p.Attrs.KaijuState or "None" end,GetHealthMult=function() return 1 end},
		GooseService={GetPosition=function() return nil end},GrudgeService={OnCarrierDown=function() end},
		ZoneService={IsPlausible=function() return true end,IsTown=function() return false end},
		MonsterService={GetMonstersInRadius=function() return f.Monsters end,
			DamageMonster=function(rec,amount) rec.HP=math.max(0,rec.HP-amount);rec.Alive=rec.HP>0;return not rec.Alive end}}
	local vitals=execute(VITALS_SOURCE,env); registry.VitalsService=vitals
	local combat=execute(COMBAT_SOURCE,env); registry.CombatService=combat
	vitals.Init(registry);combat.Init(registry);vitals.Start();combat.Start()
	combat.Released:Connect(function(p,info) table.insert(f.Events,{Player=p,Info=info}) end)
	combat.PlayerDamaged:Connect(function(victim,amount,attacker) table.insert(f.PlayerDamage,{victim,amount,attacker}) end)
	for _,p in f.Players do playerService.PlayerReady:Fire(p,{}) end
	f.Combat,f.Vitals,f.Registry,f.Remotes=combat,vitals,registry,remotes
	-- Identify the real loops by their wait interval; only the AutoCombatLoop is ever resumed by this fixture
	-- (HP/MP regen stay paused so they cannot hide damage or refill MP).
	local intervals={}
	for _,fn in f.Tasks do
		local co=coroutine.create(fn); local ok,interval=coroutine.resume(co); assert(ok,interval)
		intervals[interval]=(intervals[interval] or 0)+1
		if interval==config.Combat.AutoTick then f.AutoLoop=co end
	end
	f.LoopIntervals=intervals
	function f:Tick(dt)
		self.Now+=dt or self.Config.Combat.AutoTick
		local ok,err=coroutine.resume(self.AutoLoop); assert(ok,tostring(err))
	end
	function f:Run(seconds) for _=1,math.floor(seconds/self.Config.Combat.AutoTick+0.5) do self:Tick() end end
	function f:AddMonster(position, hp)
		local rec={Alive=true,HP=hp or 1e6,Root={Parent=true,Position=position or vec(335,0,0)},ZoneId="SlimeMeadow"}
		table.insert(self.Monsters,rec);return rec
	end
	function f:MonsterDamage() local n=0;for _,m in self.Monsters do n+=(1e6-m.HP) end;return n end
	function f:Enable() self.Player.Attrs.AutoCombatUnlocked=true;self.Player.Attrs.AutoCombatEnabled=true end
	function f:Swings(manual)
		local n=0
		for _,e in self.Fx do if e.Kind=="Swing" and e.Data.UserId==self.Player.UserId and e.Data.Manual==manual then n+=1 end end
		return n
	end
	function f:AutoSkills() local n=0;for _,e in self.Events do if e.Info.Auto==true then n+=1 end end;return n end
	return f
end

-- 1. Saved defaults and wiring: OFF and locked by default, mirrored, AutoCombatLoop at Config.Combat.AutoTick.
do
	local f=fixture()
	local D=f.Config.Data
	check(D.Defaults.AutoCombatUnlocked==false and D.Defaults.AutoCombatEnabled==false,"auto combat defaults are not locked/OFF")
	check(table.find(D.Mirrored,"AutoCombatUnlocked")~=nil and table.find(D.Mirrored,"AutoCombatEnabled")~=nil,"auto combat state not mirrored")
	check(type(f.Config.Combat.AutoTick)=="number" and f.Config.Combat.AutoTick>0,"Config.Combat.AutoTick missing")
	check(f.AutoLoop~=nil and f.LoopIntervals[f.Config.Combat.AutoTick]==1,"exactly one AutoCombatLoop must run at Config.Combat.AutoTick")
	check(string.find(COMBAT_SOURCE,'startPlayerLoop("AutoCombatLoop"',1,true)~=nil,"AutoCombatLoop name missing")
	check(f.Player.Attrs.AutoAttack==false,"legacy AutoAttack attribute not cleared on ready")
	f:AddMonster();f.Player.Attrs.AutoAttack=true -- the legacy attribute alone never enables anything
	f:Run(5)
	check(f:MonsterDamage()==0 and #f.Events==0 and #f.Fx==0,"locked/OFF auto combat attacked")
end

-- 2. Unlocking never turns auto ON; only the player's toggle does (and it is saved through SetStat).
do
	local f=fixture();f:AddMonster()
	check(f.Combat.UnlockAutoCombat("not a player")==false,"UnlockAutoCombat accepted a non-player")
	f.Ready=false;check(f.Combat.UnlockAutoCombat(f.Player)==false and f.Player.Attrs.AutoCombatUnlocked==nil,"unready player unlocked")
	f.Ready=true
	check(f.Combat.UnlockAutoCombat(f.Player)==true,"UnlockAutoCombat failed")
	check(f.Player.Attrs.AutoCombatUnlocked==true and f.Player.Attrs.AutoCombatEnabled==nil,"unlock changed the ON/OFF choice")
	check(#f.SetStats==1 and f.SetStats[1][2]=="AutoCombatUnlocked" and f.SetStats[1][3]==true,"unlock wrote anything but AutoCombatUnlocked")
	check(f.Combat.UnlockAutoCombat(f.Player)==true and f.Player.Attrs.AutoCombatEnabled==nil,"repeat unlock turned auto ON")
	f:Run(5);check(f:MonsterDamage()==0 and #f.Events==0,"unlocked-but-OFF auto combat attacked")
	-- toggle remote: one boolean only, unlocked, class chosen, alive, ready, rate limited
	local toggle=f.Remotes.SetAutoAttack.OnServerEvent
	for _,payload in { table.pack(), table.pack(nil), table.pack("true"), table.pack(1), table.pack({}), table.pack(true,1), table.pack(true,nil) } do
		f.Now+=1;toggle:Fire(f.Player,table.unpack(payload,1,payload.n))
		check(f.Player.Attrs.AutoCombatEnabled==nil,"malformed toggle payload accepted")
	end
	for _,mutate in {
		function() f.Ready=false end, function() f.Player.Hum.Health=0 end,
		function() f.Player.Attrs.ClassChosen=false end, function() f.Player.Attrs.AutoCombatUnlocked=false end,
	} do
		mutate();f.Now+=1;toggle:Fire(f.Player,true)
		check(f.Player.Attrs.AutoCombatEnabled==nil,"invalid player state toggled auto ON")
		f.Ready=true;f.Player.Hum.Health=100;f.Player.Attrs.ClassChosen=true;f.Player.Attrs.AutoCombatUnlocked=true
	end
	f.Now+=1;toggle:Fire(f.Player,true)
	check(f.Player.Attrs.AutoCombatEnabled==true,"valid toggle did not turn auto ON")
	local last=f.SetStats[#f.SetStats];check(last[2]=="AutoCombatEnabled" and last[3]==true,"toggle not saved through SetStat")
	toggle:Fire(f.Player,false);check(f.Player.Attrs.AutoCombatEnabled==true,"toggle rate limit bypassed")
	f.Now+=f.Config.RateLimits.SetAutoAttack+0.01;toggle:Fire(f.Player,false)
	check(f.Player.Attrs.AutoCombatEnabled==false,"toggle OFF after the rate window failed")
end

-- 3. Auto runs only while unlocked + ON + ready + alive + class chosen + not a kaiju, and stops at once otherwise.
do
	local f=fixture({Unlocked=true,Enabled=true});f:AddMonster()
	f:Run(1.2)
	check(f:MonsterDamage()>0 and f:Swings(false)>=1,"enabled auto combat did not swing at a monster in reach")
	check(f:AutoSkills()>=1 and f.Player.Attrs.Mana<=80,"enabled auto combat did not use the skill with MP/cooldown ready")
	check(f.Active==0,"auto attacks marked the player active (AFK detection)")
	for label,mutate in {
		Disabled=function(g) g.Player.Attrs.AutoCombatEnabled=false end,
		NotUnlocked=function(g) g.Player.Attrs.AutoCombatUnlocked=false end,
		Dead=function(g) g.Player.Hum.Health=0 end,
		NoRoot=function(g) g.Player.Root=nil end,
		NotReady=function(g) g.Ready=false end,
		Left=function(g) g.Player.Parent=nil end,
		ClassNotChosen=function(g) g.Player.Attrs.ClassChosen=false end,
		KaijuActive=function(g) g.Player.Attrs.KaijuState="Active" end,
		KaijuSiren=function(g) g.Player.Attrs.KaijuState="Siren" end,
		KaijuQueued=function(g) g.Player.Attrs.KaijuState="Queued" end,
		StringEnabled=function(g) g.Player.Attrs.AutoCombatEnabled="true" end,
	} do
		local g=fixture({Unlocked=true,Enabled=true});g:AddMonster();mutate(g)
		g:Run(5)
		check(g:MonsterDamage()==0 and #g.Events==0 and #g.Fx==0,label.." auto combat still attacked")
		-- direct auto entry points obey the same gate
		g.Combat.Swing(g.Player,false);g.Combat.Release(g.Player,true)
		check(g:MonsterDamage()==0 and #g.Events==0,label.." direct auto Swing/Release bypassed the gate")
	end
	-- turning auto OFF mid-fight stops the next tick
	local h=fixture({Unlocked=true,Enabled=true});h:AddMonster();h:Run(1)
	local dealt,events=h:MonsterDamage(),#h.Events
	h.Player.Attrs.AutoCombatEnabled=false;h:Run(6)
	check(h:MonsterDamage()==dealt and #h.Events==events,"auto combat continued after OFF")
	-- no monster in reach: no swing, no skill, no MP spent
	local idle=fixture({Unlocked=true,Enabled=true});idle:AddMonster(vec(380,0,0));idle:Run(5)
	check(#idle.Fx==0 and #idle.Events==0 and idle.Player.Attrs.Mana==100,"auto attacked/cast with no monster in reach")
end

-- 4. Auto skill economy: real MP cost and cooldown, Released carries Auto=true and the monster count.
for _,classId in {"Warrior","Mage","Archer"} do
	local f=fixture({Class=classId,Unlocked=true,Enabled=true});f:AddMonster()
	f:Tick()
	check(f:AutoSkills()==1,classId.." first auto tick did not cast the ready skill")
	local info=f.Events[1].Info
	check(info.Auto==true and info.MonstersHit==1 and info.PlayersHit==0,classId.." auto Released info wrong")
	local cost=f.Config.BasicSkill.ManaCost or f.Config.Vitals.ReleaseCost
	local swingCost=classId=="Mage" and f.Config.Vitals.MageSwingCost*f:Swings(false) or 0
	check(f.Player.Attrs.Mana==100-cost-swingCost,classId.." auto skill MP not spent exactly once")
	local cooldown=f.Config.BasicSkill.Cooldown
	f:Run(cooldown-0.4);check(f:AutoSkills()==1,classId.." auto skill ignored the cooldown")
	f:Run(0.8);check(f:AutoSkills()==2,classId.." auto skill did not recast after the cooldown")
	f.Vitals.DebugSetMana(f.Player,cost-0.5);f:Run(cooldown+0.4)
	check(f:AutoSkills()==2,classId.." auto skill cast without enough MP")
end

-- 5. Manual presses win: auto yields one class SwingInterval + ManualYieldPad after a manual attack or skill.
for _,classId in {"Warrior","Mage","Archer"} do
	local f=fixture({Class=classId,Unlocked=true,Enabled=true});f:AddMonster()
	f.Remotes.Swing.OnServerEvent:Fire(f.Player)
	check(f:Swings(true)==1,classId.." manual swing refused")
	local yield=f.Config.Classes[classId].SwingInterval+f.Config.Combat.ManualYieldPad
	local ticks=math.floor((yield-0.05)/f.Config.Combat.AutoTick)
	for _=1,ticks do f:Tick() end
	check(f:Swings(false)==0 and f:AutoSkills()==0,classId.." auto acted inside the manual yield window")
	f:Run(0.6)
	check(f:Swings(false)+f:AutoSkills()>=1,classId.." auto did not resume after the manual yield window")
end

-- 6. Auto attacks and auto skills hit monsters only: never a player, never a kaiju, even with PvP fully allowed.
-- Positive control first: the same layout is hit by a MANUAL swing/skill, so the victims are really in reach.
local function layout(classId, attackerFaction)
	local f=fixture({Class=classId,Faction=attackerFaction})
	local enemy=attackerFaction=="Halo" and "Horns" or "Halo"
	f:AddMonster(vec(335,0,0))
	local near=f:NewPlayer(9000+serial,enemy,vec(333,0,0))           -- nearer than the monster
	local onMonster=f:NewPlayer(9100+serial,enemy,vec(335.5,0,0))    -- inside the splash / blast of the monster
	local kaiju=nil
	if attackerFaction=="Halo" then
		kaiju=f:NewPlayer(9200+serial,"Horns",vec(334,0,0),{KaijuState="Active"})
		kaiju.Hum.MaxHealth,kaiju.Hum.Health=2000,2000
	end
	for _,p in f.Players do if p~=f.Player then f.Registry.PlayerService.PlayerReady:Fire(p,{}) end end
	f.Victims={near,onMonster,kaiju}
	function f:VictimHealth() local t=0;for _,v in self.Victims do t+=v.Hum.Health end;return t end
	return f
end
for _,classId in {"Warrior","Mage","Archer"} do
	for _,fac in {"Halo","Horns"} do
		local control=layout(classId,fac);local full=control:VictimHealth()
		control.Combat.Swing(control.Player,true);control.Now+=4;control.Combat.Release(control.Player,false)
		check(control:VictimHealth()<full and #control.PlayerDamage>0,classId.."/"..fac.." positive control: manual attacks did not reach the victims")
		local f=layout(classId,fac);f:Enable();full=f:VictimHealth()
		f:Run(8)
		check(f:MonsterDamage()>0 and f:AutoSkills()>=2 and f:Swings(false)>=2,classId.."/"..fac.." auto did not fight the monster")
		check(f:VictimHealth()==full and #f.PlayerDamage==0,classId.."/"..fac.." auto combat damaged a player or kaiju")
		check(f.BrokenProtection==nil,classId.."/"..fac.." auto combat broke spawn protection (PvP engagement)")
		for _,e in f.Events do check(e.Info.PlayersHit==0,classId.."/"..fac.." auto skill reported player hits") end
		local targetCenter=f.Config.Classes[classId].ReleaseCenter=="Target"
		for _,e in f.Fx do
			for _,hit in (e.Data and e.Data.Hits) or {} do check(hit.K~="P",classId.."/"..fac.." auto Fx showed a player hit") end
			if e.Data and e.Data.UserId==f.Player.UserId then
				-- target selection itself ignores players: aim points and skill centers are the monster, never a nearer player
				if e.Kind=="Swing" then
					for _,t in e.Data.Targets or {} do check(t.X==335 and t.Z==0,classId.."/"..fac.." auto swing aimed at a player") end
				elseif e.Kind=="Release" and targetCenter then
					check(e.Data.Pos.X==335 and e.Data.Pos.Z==0,classId.."/"..fac.." auto skill centered on a player")
				end
			end
		end
		-- direct auto entry points with only players in reach: still no player damage
		f.Monsters={};f.Now+=5
		f.Combat.Swing(f.Player,false);f.Combat.Release(f.Player,true)
		check(f:VictimHealth()==full and #f.PlayerDamage==0,classId.."/"..fac.." direct auto call hit a player with no monster near")
	end
end

-- 7. KaijuService: an AUTO skill's heal never makes a Halo player a kaiju-raid healer (rewards need direct input).
do
	check(string.find(KAIJU_RELEASED_SOURCE,"info.Auto == true then return",1,true)~=nil,"KaijuService Released handler lost its auto guard")
	local function run(healerFaction, auto, damagedAlly)
		local released=signal()
		local healer={Faction=healerFaction,__kind="Instance",IsA=function(_,k) return k=="Player" end}
		local ally={Faction="Halo",__kind="Instance",IsA=function(_,k) return k=="Player" end}
		local kaiju={Faction="Horns",__kind="Instance",IsA=function(_,k) return k=="Player" end}
		local dmg,healers={},{}
		if damagedAlly then dmg[ally]=25 end
		execute(KAIJU_RELEASED_SOURCE,{typeof=function(v) return type(v)=="table" and v.__kind or type(v) end},
			{CombatService={Released=released}},
			function(p) return type(p)=="table" and p.__kind=="Instance" and p:IsA("Player") end,
			function(p) return p.Faction end, "Active", kaiju, dmg, healers)
		released:Fire(healer,{Auto=auto,Healed={ally},MonstersHit=1,PlayersHit=0})
		return healers[healer]==true
	end
	check(run("Halo",false,true)==true,"positive control: manual Halo heal of a kaiju damager was not credited")
	check(run("Halo",true,true)==false,"auto skill heal was credited as kaiju-raid participation")
	check(run("Horns",false,true)==false and run("Halo",false,false)==false,"non-Halo or non-damager heal credited")
end
print("AUTO_COMBAT_OFFLINE_OK checks="..checks.." Studio/API calls=0")
