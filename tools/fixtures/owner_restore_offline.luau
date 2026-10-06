-- Engine/physics doubles only. Production functions are loaded from current files by the runner.
-- This fixture checks lifecycle contracts; it cannot prove network ownership or physical OFF stability.
local checks, cases, failed = 0, 0, 0
local function check(condition, message)
	checks += 1
	assert(condition, message)
end
local function testcase(name, fn)
	cases += 1
	local ok, err = pcall(fn)
	if not ok then failed += 1 end
	print("OWNER_RESTORE_CASE "..name.." "..(ok and "PASS" or "FAIL")..(ok and "" or " "..tostring(err):gsub("[\r\n]", " ")))
end
local function execute(text, env, ...)
	local fn, err = loadstring(text)
	assert(fn, err)
	setfenv(fn, setmetatable(env or {}, { __index=getfenv() }))
	return fn(...)
end

local function scheduler()
	local s = { Now=100, Queue={}, Sequence=0, Errors={} }
	function s:QueueThread(co, at, args)
		self.Sequence += 1
		table.insert(self.Queue, { Thread=co, At=at, Order=self.Sequence, Args=args or {} })
	end
	function s:Resume(co, args)
		local ok, value = coroutine.resume(co, table.unpack(args or {}))
		if not ok then table.insert(self.Errors, tostring(value)); return end
		if coroutine.status(co) ~= "dead" then
			assert(type(value)=="table" and value.Delay, "fixture coroutine yielded without task.wait")
			self:QueueThread(co, self.Now + value.Delay)
		end
	end
	function s:Start(fn, ...)
		local co = coroutine.create(fn)
		self:Resume(co, table.pack(...))
		return co
	end
	function s:Later(delay, fn, ...)
		self:QueueThread(coroutine.create(fn), self.Now+delay, table.pack(...))
	end
	function s:Run(seconds)
		local untilTime = self.Now + (seconds or 40)
		local iterations = 0
		while #self.Queue > 0 do
			table.sort(self.Queue, function(a,b) return a.At<b.At or (a.At==b.At and a.Order<b.Order) end)
			local item = self.Queue[1]
			if item.At>untilTime then break end
			table.remove(self.Queue,1)
			self.Now=item.At
			self:Resume(item.Thread,item.Args)
			iterations+=1
			assert(iterations<100000,"fixture scheduler did not terminate")
		end
	end
	s.Task = {
		wait=function(seconds) local duration=seconds or .05; coroutine.yield({Delay=duration}); return duration end,
		spawn=function(fn,...) return s:Start(fn,...) end,
		defer=function(fn,...) s:Later(.001,fn,...) end,
		delay=function(seconds,fn,...) s:Later(seconds,fn,...) end,
	}
	return s
end

-- Native signals run in separate coroutines. Deferred delivery is cancelled by Disconnect.
local function engineSignal(s, delay)
	local handlers={}
	local sig={}
	function sig:Connect(fn)
		local entry={ Fn=fn, Connected=true };table.insert(handlers,entry)
		return { Disconnect=function() entry.Connected=false end }
	end
	function sig:Once(fn)
		local conn;conn=self:Connect(function(...) conn.Disconnect();fn(...) end);return conn
	end
	function sig:Fire(...)
		local args=table.pack(...)
		for _,entry in table.clone(handlers) do
			local function deliver() if entry.Connected then entry.Fn(table.unpack(args,1,args.n)) end end
			if delay and delay>0 then s:Later(delay,deliver) else s:Start(deliver) end
		end
	end
	return sig
end

local vectorMT={}
local function vector(x,y,z) return setmetatable({ X=x,Y=y,Z=z,__kind="Vector3" },vectorMT) end
vectorMT.__add=function(a,b) return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vectorMT.__sub=function(a,b) return vector(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
local frameMT={}
local function frame(x,y,z,facing) return setmetatable({Position=vector(x,y,z),Facing=facing or "owner-facing",__kind="CFrame"},frameMT) end
frameMT.__add=function(a,b) return frame(a.Position.X+b.X,a.Position.Y+b.Y,a.Position.Z+b.Z,a.Facing) end
local function sameVector(a,b) return a and b and a.X==b.X and a.Y==b.Y and a.Z==b.Z end

local nodeMethods={}
local nodeMT={}
nodeMT.__index=function(self,key) return nodeMethods[key] or self._props[key] end
nodeMT.__newindex=function(self,key,value)
	local props=self._props
	if key=="Parent" then
		local old=props.Parent
		if old==value then return end
		if old then local idx=table.find(old._children,self);if idx then table.remove(old._children,idx) end end
		props.Parent=value
		if value then
			table.insert(value._children,self)
			local ancestor=value
			while ancestor do ancestor.DescendantAdded:Fire(self);ancestor=ancestor.Parent end
		end
	elseif key=="Character" and props.ClassName=="Player" then
		props.Character=value
		if value and not props.SuppressCharacterAdded then self.CharacterAdded:Fire(value) end
	else props[key]=value end
end
local function node(s,kind,name,delay)
	local n=setmetatable({_props={ClassName=kind,Name=name or kind,__kind="Instance"},_children={},_attrs={},_s=s},nodeMT)
	n.DescendantAdded=engineSignal(s,delay)
	if kind=="Player" then n.CharacterAdded=engineSignal(s,delay) end
	if kind=="Humanoid" then n.Died=engineSignal(s,delay) end
	return n
end
function nodeMethods:IsA(kind)
	return self.ClassName==kind or (kind=="BasePart" and (self.ClassName=="Part" or self.ClassName=="MeshPart"))
end
function nodeMethods:GetChildren() return table.clone(self._children) end
function nodeMethods:GetDescendants()
	local result={}
	local function visit(n) for _,c in n._children do table.insert(result,c);visit(c) end end
	visit(self);return result
end
function nodeMethods:FindFirstChild(name)
	for _,c in self._children do if c.Name==name then return c end end
	return nil
end
function nodeMethods:FindFirstChildOfClass(kind)
	for _,c in self._children do if c:IsA(kind) then return c end end
	return nil
end
function nodeMethods:WaitForChild(name,timeout)
	local start=self._s.Now
	while not self:FindFirstChild(name) and self._s.Now-start<(timeout or 5) do self._s.Task.wait() end
	return self:FindFirstChild(name)
end
function nodeMethods:SetAttribute(key,value) self._attrs[key]=value end
function nodeMethods:GetAttribute(key) return self._attrs[key] end
function nodeMethods:Destroy()
	if self.Destroyed then return end
	for _,c in self:GetChildren() do c:Destroy() end
	self.Parent=nil;self.Destroyed=true
end
function nodeMethods:Clone()
	if self.CloneError then error("description clone failed") end
	local clone=node(self._s,self.ClassName,self.Name)
	clone.Source=self;self.LastClone=clone
	return clone
end
function nodeMethods:GetPivot() return self.Pivot end
function nodeMethods:PivotTo(pivot) self.Pivot=pivot;self.PivotCalls=(self.PivotCalls or 0)+1 end
function nodeMethods:SetNetworkOwner(player) self.NetworkOwnerCalls=(self.NetworkOwnerCalls or 0)+1;self.Owner=player end

local serial=0
local function fixture(options)
	options=options or {};serial+=1
	local s=scheduler()
	local delay=options.Deferred and (options.CallbackDelay or .02) or nil
	local f={ Scheduler=s,Options=options,Warnings={},SpawnEvents={},DeathEvents=0,TeleportCalls=0,NativeCalls=0,NormalCalls=0,ReleaseCalls=0 }
	local players=node(s,"Players","Players")
	local world=node(s,"Workspace","Workspace")
	function world:GetServerTimeNow() return s.Now end
	local storage=node(s,"ServerStorage","ServerStorage")
	local player=node(s,"Player","Owner"..serial,delay);player.Parent=players;player.UserId=serial
	player:SetAttribute("ClassChosen",true);player:SetAttribute("Faction","Halo")
	-- Config.Vitals now holds Color3 literals (A23-6 merchant colors); inert constructors are enough offline.
	local config=execute(CONFIG_SOURCE,{Color3={fromRGB=function(r,g,b) return {R=r,G=g,B=b} end,new=function(r,g,b) return {R=r,G=g,B=b} end}})
	-- The restored class formula is a fixture constant; production formulas are outside this lifecycle test.
	config.MaxHealth=function() return options.MaxHealth or 100 end
	config.Classes={Warrior={WalkSpeedMult=1}}
	-- PET-1: PlayerService.ComputeWalkSpeed -> Config.WalkSpeed (class x pet, tools/test_pet_speed.py); here the plain class speed
	config.WalkSpeed=function(classId) return config.Player.WalkSpeed*((config.Classes[classId] or config.Classes.Warrior).WalkSpeedMult or 1) end
	config.HomeZoneId=function() return "HaloHome" end
	config.AntiCheat={SpawnGrace=2}
	local data={Level=1,Faction="Halo",Class="Warrior",HPPotionCount=3,MPPotionCount=3}
	local env={task=s.Task,workspace=world,os={clock=function() return s.Now end,time=function() return math.floor(s.Now) end},
		Enum={HumanoidRigType={R15="R15",R6="R6"},HumanoidDisplayDistanceType={None="None"}},
		Vector3={new=vector},CFrame={new=function(v) return frame(v.X,v.Y,v.Z) end},
		typeof=function(value) return type(value)=="table" and value.__kind or type(value) end,
		warn=function(message) table.insert(f.Warnings,tostring(message)) end,print=function() end}
	local util=execute(UTIL_SOURCE,env)
	util.Warn=function(_,message) table.insert(f.Warnings,tostring(message)) end
	util.ClearPlayer=function() f.Cleared=true end
	util.RateLimit=function() return true end
	local net={Notify=function() end}
	local services={Players=players,ServerStorage=storage,ReplicatedStorage={Shared={Config="Config",Util="Util",Net="Net"}},
		PhysicsService={IsCollisionGroupRegistered=function() return true end,CollisionGroupSetCollidable=function() end},
		RunService={IsStudio=function() return true end}}
	env.game={GetService=function(_,key) return assert(services[key],key) end}
	env.require=function(name) if name=="Config" then return config elseif name=="Util" then return util elseif name=="Net" then return net end;error(name) end
	env.Instance={new=function(kind) return node(s,kind,kind,delay) end}
	local ps,priv=execute(PLAYER_SOURCE,env)
	local move={lastGood={},graceUntil={}}
	local zone=execute(ZONE_SOURCE,env,move)
	zone.MarkTeleported=function(p,seconds) f.TeleportCalls+=1;move.graceUntil[p]=s.Now+seconds;move.lastGood[p]=nil end
	zone.GetSpawnCFrame=function() return frame(-200,5,-200,"spawn-facing") end
	local registry={PlayerService=ps,ZoneService=zone,DataService={Get=function() return data end,Release=function() f.ReleaseCalls+=1 end}}
	ps.Init(registry);priv.ready[player]=true
	local characterAdded=player.CharacterAdded:Connect(function(c) priv.onCharacterAdded(player,c) end)
	priv.conns[player]={characterAdded}
	local vitals,vitalPriv=execute(VITALS_SOURCE,env);vitals.Init(registry)
	registry.VitalsService=vitals
	ps.CharacterSpawned:Connect(function(_,c,h,cosmetic)
		table.insert(f.SpawnEvents,{Character=c,Cosmetic=cosmetic})
		if options.ScaleAfterSpawn then h.HipHeight=options.ScaleAfterSpawn;zone.MarkTeleported(player,29) end
	end)
	ps.CharacterDied:Connect(function() f.DeathEvents+=1;f.DeathAt=s.Now end)
	local function makeCharacter(name,new)
		local c=node(s,"Model",name,delay);c.Pivot=new and frame(0,4,0,"engine-facing") or frame(31,12,-17,"owner-facing")
		local h=node(s,"Humanoid","Humanoid",delay)
		h.HipHeight=new and (options.NewHipHeight or 2) or 1
		h.RigType=new and (options.NewRig or "R15") or (options.OldRig or "R15")
		h.Health=new and 100 or 37;h.MaxHealth=100;h.Parent=c
		local root=node(s,"Part","HumanoidRootPart",delay)
		root.Size=vector(2,new and (options.NewRootY or 2) or 2,1)
		root.AssemblyLinearVelocity=vector(new and 0 or 2,new and 0 or 3,new and 0 or 4)
		root.AssemblyAngularVelocity=vector(new and 0 or .1,new and 0 or .2,new and 0 or .3)
		root.CanCollide=true
		if not (new and options.MissingRoot) then root.Parent=c end
		if h.RigType=="R6" then local leg=node(s,"Part","Left Leg",delay);leg.Size=vector(1,new and (options.NewLegY or 2) or 2,1);leg.Parent=c end
		local animate=node(s,"LocalScript","Animate",delay);animate.EngineOwned=true;animate.Parent=c
		local controller=node(s,"AnimationConstraint","NativeController",delay);controller.EngineOwned=true;controller.Parent=c
		c.Parent=world
		return c,h,root
	end
	local old,h,root=makeCharacter("OldCostume",false)
	player.SuppressCharacterAdded=true;player.Character=old;player.SuppressCharacterAdded=false
	local ff=node(s,"ForceField","ExistingShield",delay);ff.ExpiresAt=s.Now+(options.ShieldDuration or 4);ff.Parent=old
	s:Later(options.ShieldDuration or 4,function() ff:Destroy() end)
	move.lastGood[player]={Char=old,Position=vector(31,12,-17),Time=99,Velocity=vector(2,3,4)}
	move.graceUntil[player]=101.5
	ps.PlayerReady:Fire(player,data)
	vitals.DebugSetMana(player,20);vitalPriv.usePotion(player,"HP");vitalPriv.usePotion(player,"MP")
	local description=node(s,"HumanoidDescription","OriginalDescription",delay)
	f.Player,f.Players,f.World,f.Storage,f.Old,f.OldHumanoid,f.OldRoot=player,players,world,storage,old,h,root
	f.Shield,f.Description,f.PS,f.Private,f.Vitals,f.VitalPrivate,f.Move,f.Data,f.Config=ff,description,ps,priv,vitals,vitalPriv,move,data,config
	f.HP=h.Health;f.MP=player:GetAttribute("Mana");f.HPReady=player:GetAttribute("HPPotionReadyAt");f.MPReady=player:GetAttribute("MPPotionReadyAt")
	f.OldPivot=old:GetPivot();f.OldStanding=priv.standingHeight(old,h,root)
	function player:LoadCharacterWithHumanoidDescriptionAsync(copied)
		f.NativeCalls+=1;f.EngineDescription=copied
		if options.ErrorBefore then error("engine failed before replacement") end
		if options.NoReplacement then s.Task.wait(options.EngineDelay or .2);return end
		local c,nh,nroot=makeCharacter("NativeOwner",true)
		local newFF=node(s,"ForceField","NewEngineShield",delay);newFF.Parent=c;f.NewShield=newFF
		self.SuppressCharacterAdded=options.NoCallback==true
		self.Character=c;self.SuppressCharacterAdded=false
		f.New,f.NewHumanoid,f.NewRoot=c,nh,nroot
		old:Destroy()
		if options.AfterAssigned then options.AfterAssigned(f) end
		local wait=options.EngineDelay
		if wait==nil then wait=.2 end
		if wait>0 then s.Task.wait(wait) end
		if options.ErrorAfter then error("engine failed after replacement") end
	end
	function player:LoadCharacter()
		f.NormalCalls+=1
		f.NormalLoadedAt=s.Now
		local c,nh,nroot=makeCharacter("NormalRespawn",true)
		local previous=self.Character;self.Character=c;if previous and previous~=c then previous:Destroy() end
		f.RespawnCharacter,f.RespawnHumanoid,f.RespawnRoot=c,nh,nroot
	end
	function f:Restore(stillWanted)
		s:Start(function() self.Result=self.PS.RestoreOwnerCharacter(player,description,old,stillWanted);self.ReturnedAt=s.Now end)
		s:Run(options.RunFor or 2)
	end
	function f:NoErrors() check(#s.Errors==0,"scheduler/production error: "..table.concat(s.Errors,"; ")) end
	function f:ResourcesPreserved()
		check(self.NewHumanoid.Health==self.HP,"cosmetic restore changed HP")
		check(player:GetAttribute("Mana")==self.MP,"cosmetic restore changed MP")
		check(player:GetAttribute("HPPotionReadyAt")==self.HPReady and player:GetAttribute("MPPotionReadyAt")==self.MPReady,"cosmetic restore changed cooldown deadlines")
		check(data.HPPotionCount==2 and data.MPPotionCount==2,"cosmetic restore changed saved bottle stock")
	end
	function f:Clean()
		check(priv.characterLoading[player]==nil,"spawn lock leaked")
		check(priv.nativeRestore[player]==nil,"pending native slot leaked")
		check(#storage:GetChildren()==0,"shield holder leaked")
		check(description.LastClone and description.LastClone.Destroyed,"description copy leaked")
	end
	return f
end

for _,deferred in {false,true} do
	for _,oldRig in {"R15","R6"} do
		for _,newRig in {"R15","R6"} do
			testcase((deferred and "deferred" or "immediate").."_"..oldRig.."_to_"..newRig,function()
				local f=fixture({Deferred=deferred,OldRig=oldRig,NewRig=newRig,EngineDelay=deferred and 0 or .2})
				f:Restore();f:NoErrors();check(f.Result==true,"valid native restoration did not complete")
				f:ResourcesPreserved();f:Clean()
				check(#f.SpawnEvents==1 and f.SpawnEvents[1].Cosmetic==true,"native OFF fired a normal spawn")
				check(f.DeathEvents==0,"appearance replacement fired death")
				check(f.TeleportCalls==0,"appearance replacement granted fresh movement grace")
				local track=f.Move.lastGood[f.Player]
				check(track and track.Char==f.New and track.Time==99,"movement sample not rebound to exact native model")
				check(sameVector(track.Position,vector(31,12,-17)) and f.Move.graceUntil[f.Player]==101.5,"movement sample/grace changed")
				local pivot=f.New:GetPivot()
				local expectedY=f.OldPivot.Position.Y+f.Private.standingHeight(f.New,f.NewHumanoid,f.NewRoot)-f.OldStanding
				check(pivot.Position.X==31 and pivot.Position.Z==-17 and pivot.Position.Y==expectedY and pivot.Facing=="owner-facing","feet/world position/facing not preserved")
				check(sameVector(f.NewRoot.AssemblyLinearVelocity,vector(2,3,4)) and sameVector(f.NewRoot.AssemblyAngularVelocity,vector(.1,.2,.3)),"velocities not preserved")
				check(f.Shield.Parent==f.New and not f.Shield.Destroyed and f.Shield.ExpiresAt==104,"existing shield identity/deadline lost")
				check(f.NewShield.Destroyed,"new engine shield retained")
				check(f.New:FindFirstChild("Animate").EngineOwned and f.New:FindFirstChild("NativeController").EngineOwned,"native controllers replaced")
				check(f.NewRoot.CanCollide==true and not f.NewRoot.NetworkOwnerCalls,"native root collision/ownership rewritten")
				f.Scheduler:Run(5);check(f.Shield.Destroyed,"original shield expiration did not follow moved instance")
			end)
		end
	end
end

testcase("post_spawn_scale_recomputed_once",function()
	local f=fixture({ScaleAfterSpawn=3})
	f:Restore();f:NoErrors();check(f.Result,"scaled native restore failed");f:ResourcesPreserved();f:Clean()
	check(f.New:GetPivot().Position.Y==14,"spawn-handler height correction accumulated/wrong")
	check(f.Move.graceUntil[f.Player]==101.5 and f.Move.lastGood[f.Player].Time==99,"spawn handler overwritten preserved track/grace")
end)

testcase("shield_expires_during_engine_wait",function()
	local f=fixture({EngineDelay=1,ShieldDuration=.1})
	f:Restore();f:NoErrors();check(f.Result,"slow valid restore failed");f:Clean()
	check(f.Shield.Destroyed and not f.New:FindFirstChild("ExistingShield"),"expired old shield was renewed")
	check(f.NewShield.Destroyed,"engine shield was not removed")
end)

testcase("new_shield_while_engine_waiting",function()
	local f=fixture({AfterAssigned=function(t)
		t.Scheduler:Later(.1,function() local ff=node(t.Scheduler,"ForceField","LaterEngineShield");ff.Parent=t.New;t.LaterShield=ff end)
	end})
	f:Restore();f:NoErrors();check(f.Result,"restore failed");check(f.LaterShield.Destroyed,"new shield added during native load retained")
end)

for _,case in {{"engine_error_before","ErrorBefore"},{"engine_error_after","ErrorAfter"},{"no_replacement","NoReplacement"}} do
	testcase(case[1],function()
		local opts={[case[2]]=true,RunFor=7}
		local f=fixture(opts);f:Restore();f:NoErrors();check(f.Result==false,"failed native call reported success");f:Clean()
		check(f.Player:GetAttribute("Mana")==f.MP and f.Player:GetAttribute("HPPotionReadyAt")==f.HPReady,"failed call reset resource state")
		check(f.Shield.Destroyed,"original shield expiration lost after failed native call")
		check(f.TeleportCalls==0,"failed native call granted new grace")
	end)
end

testcase("missing_root_timeout_cleanup",function()
	local f=fixture({MissingRoot=true,RunFor=12})
	f:Restore();f:NoErrors();check(f.Result==false,"missing root restored successfully");f:Clean()
	check(f.Private.cosmeticContext[f.New]==nil,"missing-root callback context leaked")
	check(#f.SpawnEvents==0,"incomplete native model fired spawn")
end)

testcase("missing_callback_timeout_cleanup",function()
	local f=fixture({NoCallback=true,RunFor=7})
	f:Restore();f:NoErrors();check(f.Result==false,"missing callback reported success");f:Clean()
	check(f.Private.cosmeticContext[f.New]==nil,"timeout retained live model's stale cosmetic context")
end)

testcase("delayed_callback_after_timeout_cancelled",function()
	local f=fixture({Deferred=true,CallbackDelay=8,EngineDelay=0,RunFor=10})
	f:Restore();f:NoErrors();check(f.Result==false and f.ReturnedAt<108,"delayed callback did not time out")
	f:Clean();check(#f.SpawnEvents==0,"failed/timed-out restore later fired cosmetic spawn")
	check(f.Private.cosmeticContext[f.New]==nil,"late callback left stale context")
	check(f.NormalCalls==0 and f.Player:GetAttribute("Mana")==f.MP,"alive callback timeout triggered healing normal respawn")
end)

testcase("native_wait_30_second_timeout_aborts",function()
	local f=fixture({EngineDelay=32,RunFor=35,ShieldDuration=40})
	f:Restore();f:NoErrors();check(f.Result==false,"native readiness timeout reported success")
	f:Clean();check(#f.SpawnEvents==0,"unready/timed-out engine model was placed/scaled and spawned")
	check(f.NewHumanoid.Health==100,"timed-out callback changed unfinished avatar HP")
	check(f.NormalCalls==0 and f.Player:GetAttribute("Mana")==f.MP,"alive native timeout triggered healing normal respawn")
end)

testcase("death_during_native_load_not_revived",function()
	local f=fixture({AfterAssigned=function(t)
		t.Scheduler:Later(.1,function() t.NewHumanoid.Health=0;t.NewHumanoid.Died:Fire() end)
	end})
	f:Restore();f:NoErrors();check(f.Result==false,"dead native restore reported success")
	check(f.NewHumanoid.Health==0,"cosmetic context revived a native humanoid that died during loading")
	f:Clean()
end)

testcase("death_during_native_load_then_real_respawn",function()
	local f=fixture({AfterAssigned=function(t)
		t.Scheduler:Later(.1,function() t.KilledAt=t.Scheduler.Now;t.NewHumanoid.Health=0;t.NewHumanoid.Died:Fire() end)
	end})
	f:Restore();f:NoErrors()
	check(f.Result==false and f.NewHumanoid.Health==0,"loading death was disguised as successful cosmetic restoration")
	check(f.NormalCalls==0 and f.Player:GetAttribute("Mana")==f.MP,"death restored resources before the respawn delay")
	f.Scheduler:Run(5);f:NoErrors();f:Clean()
	check(f.DeathEvents==1 and f.NormalCalls==1,"loading death missed the normal Died event/one real respawn")
	check(f.NormalLoadedAt>=f.KilledAt+f.Config.Player.RespawnTime,"loading death respawn occurred before configured delay")
	check(f.NormalLoadedAt<=f.KilledAt+f.Config.Player.RespawnTime+.1,"loading death lifecycle was connected too late")
	check(f.RespawnHumanoid.Health==100 and f.Player:GetAttribute("Mana")==100,"real post-death respawn failed to replenish HP/MP")
	check(f.Player:GetAttribute("HPPotionReadyAt")==f.HPReady and f.Player:GetAttribute("MPPotionReadyAt")==f.MPReady,"loading death respawn erased potion cooldowns")
	check(f.Data.HPPotionCount==2 and f.Data.MPPotionCount==2,"loading death respawn refilled potion stock")
	check(#f.SpawnEvents==1 and f.SpawnEvents[1].Cosmetic==false,"dead native avatar fired cosmetic spawn")
end)

testcase("death_during_long_native_load_queued_respawn",function()
	local f=fixture({EngineDelay=3.5,RunFor=2,AfterAssigned=function(t)
		t.Scheduler:Later(.1,function() t.NewHumanoid.Health=0;t.NewHumanoid.Died:Fire();t.NewHumanoid.Died:Fire() end)
	end})
	f:Restore();f:NoErrors()
	check(f.NormalCalls==0 and f.Player:GetAttribute("Mana")==f.MP,"pending engine load granted an early normal spawn")
	f.Scheduler:Run(5);f:NoErrors();f:Clean()
	check(f.Result==false and f.DeathEvents==1 and f.NormalCalls==1,"loading death queue duplicated/lost Died or respawn")
	check(f.NormalLoadedAt>=103.5 and f.Private.respawnQueued[f.Player]==nil,"engine loading was bypassed or respawn queue leaked")
	check(f.RespawnHumanoid.Health==100 and f.Player:GetAttribute("Mana")==100,"queued death respawn did not replenish resources")
	check(f.Player:GetAttribute("HPPotionReadyAt")==f.HPReady and f.Player:GetAttribute("MPPotionReadyAt")==f.MPReady,"queued loading death erased potion cooldowns")
	check(f.Data.HPPotionCount==2 and f.Data.MPPotionCount==2,"queued loading death granted free bottles")
end)

testcase("already_dead_before_deferred_callback_respawns_once",function()
	local f=fixture({Deferred=true,CallbackDelay=.3,AfterAssigned=function(t)
		t.Scheduler:Later(.1,function() t.NewHumanoid.Health=0;t.NewHumanoid.Died:Fire() end)
		-- These events arrive after the missed-death catch-up and must not schedule another respawn.
		t.Scheduler:Later(.35,function() t.NewHumanoid.Died:Fire();t.NewHumanoid.Died:Fire() end)
	end})
	f:Restore();f:NoErrors()
	check(f.Result==false and f.NewHumanoid.Health==0,"already-dead deferred avatar was revived")
	check(f.DeathEvents==1 and f.NormalCalls==0,"missed death was not caught once before the delay")
	check(f.Player:GetAttribute("Mana")==f.MP,"missed-death catch-up replenished MP before real respawn")
	f.Scheduler:Run(5);f:NoErrors();f:Clean()
	check(f.NormalCalls==1,"missed-death catch-up/duplicate Died scheduled wrong number of respawns")
	check(f.NormalLoadedAt>=f.DeathAt+f.Config.Player.RespawnTime,"catch-up respawn bypassed configured delay")
	check(f.RespawnHumanoid.Health==100 and f.Player:GetAttribute("Mana")==100,"catch-up real respawn failed to replenish HP/MP")
	check(f.Player:GetAttribute("HPPotionReadyAt")==f.HPReady and f.Player:GetAttribute("MPPotionReadyAt")==f.MPReady,"catch-up death cleared potion cooldowns")
	check(f.Data.HPPotionCount==2 and f.Data.MPPotionCount==2,"catch-up death granted free bottles")
	check(#f.SpawnEvents==1 and f.SpawnEvents[1].Cosmetic==false,"already-dead cosmetic model fired spawn")
end)

testcase("leave_during_native_load",function()
	local f=fixture({AfterAssigned=function(t)
		t.Scheduler:Later(.1,function() t.Player.Parent=nil;t.PS.FinalizeLeave(t.Player) end)
	end})
	f:Restore();f:NoErrors();check(f.Result==false,"departed player restored successfully");f:Clean()
	check(f.ReleaseCalls==1 and f.Cleared,"leave finalization did not run once")
	check(f.VitalPrivate.states[f.Player]==nil and #f.SpawnEvents==0,"left player retained vitals/spawned")
	check(f.Private.cosmeticContext[f.New]==nil,"leave retained native model cosmetic context")
end)

testcase("respawn_queued_once_while_restoring",function()
	local f=fixture({AfterAssigned=function(t)
		t.Scheduler:Later(.1,function() t.PS.Respawn(t.Player);t.PS.Respawn(t.Player) end)
	end})
	f:Restore();f:NoErrors();f:Clean()
	check(f.NormalCalls==1 and f.Private.respawnQueued[f.Player]==nil,"queued respawns duplicated or queue leaked")
	check(f.RespawnHumanoid.Health==100 and f.Player:GetAttribute("Mana")==100,"real respawn did not replenish HP/MP")
	check(f.Player:GetAttribute("HPPotionReadyAt")==f.HPReady and f.Player:GetAttribute("MPPotionReadyAt")==f.MPReady,"queued respawn erased potion cooldowns")
	check(f.Data.HPPotionCount==2 and f.Data.MPPotionCount==2,"queued respawn granted free potions")
end)

testcase("death_after_restore_uses_normal_respawn",function()
	local f=fixture()
	f:Restore();f:NoErrors();check(f.Result,"initial restore failed")
	f.NewHumanoid.Health=0;f.NewHumanoid.Died:Fire()
	f.Scheduler:Run(5);f:NoErrors();f:Clean()
	check(f.DeathEvents==1 and f.NormalCalls==1,"native restored character death did not trigger one normal respawn")
	check(f.RespawnHumanoid.Health==100 and f.Player:GetAttribute("Mana")==100,"normal death respawn failed to restore HP/MP")
	check(f.Player:GetAttribute("HPPotionReadyAt")==f.HPReady and f.Player:GetAttribute("MPPotionReadyAt")==f.MPReady,"death respawn cleared potion cooldowns")
	check(f.Data.HPPotionCount==2 and f.Data.MPPotionCount==2,"death respawn refilled bottles")
end)

testcase("movement_snapshot_is_copied_and_validated",function()
	local f=fixture()
	local capture=execute(ZONE_SOURCE,{
		typeof=function(v) return type(v)=="table" and v.__kind or type(v) end,
	},f.Move)
	local before=f.Move.lastGood[f.Player]
	local snapshot=capture.CaptureMovementTrack(f.Player)
	check(snapshot.LastGood~=before and snapshot.GraceUntil==101.5,"capture shares mutable last-good record")
	snapshot.LastGood.Time=98
	check(before.Time==99,"snapshot mutation changed original track")
	capture.RestoreMovementTrack(f.Player,snapshot,node(f.Scheduler,"Model","ForgedModel"))
	check(f.Move.lastGood[f.Player]==before,"forged/noncurrent model replaced movement track")
	capture.RestoreMovementTrack(f.Player,snapshot,f.Old)
	check(f.Move.lastGood[f.Player]~=snapshot.LastGood and f.Move.lastGood[f.Player].Time==98,"restored track is not independently copied")
	check(f.Move.lastGood[f.Player].Char==f.Old and f.Move.graceUntil[f.Player]==101.5,"exact current model/deadline restore failed")
end)

testcase("standing_height_rejects_invalid_geometry",function()
	local f=fixture()
	check(f.Private.standingHeight(f.Old,f.OldHumanoid,f.OldRoot)==2,"R15 standing formula incorrect")
	for _,height in {0/0,math.huge,-math.huge,-4} do
		f.OldHumanoid.HipHeight=height
		check(f.Private.standingHeight(f.Old,f.OldHumanoid,f.OldRoot)==nil,"invalid height accepted")
	end
	f.OldHumanoid.HipHeight=1;f.OldHumanoid.RigType="R6"
	check(f.Private.standingHeight(f.Old,f.OldHumanoid,f.OldRoot)==nil,"R6 missing leg height accepted")
end)

testcase("restore_rejections_do_not_call_engine",function()
	for _,mutate in {
		function(f) f.Private.ready[f.Player]=nil end,
		function(f) f.Player.Parent=nil end,
		function(f) f.Private.characterLoading[f.Player]=true end,
		function(f) f.OldHumanoid.Health=0 end,
		function(f) f.Description.CloneError=true end,
	} do
		local f=fixture();mutate(f);f:Restore();f:NoErrors()
		check(f.Result==false and f.NativeCalls==0,"invalid restore state invoked engine")
		check(f.Shield.Parent==f.Old and f.TeleportCalls==0,"rejected restore moved shield/granted grace")
	end
	local f=fixture();f:Restore(function() return false end);f:NoErrors()
	check(f.Result==false and f.NativeCalls==0 and f.Description.LastClone.Destroyed,"cancelled intent called engine/leaked description")
end)

print("OWNER_RESTORE_SUMMARY checks="..checks.." cases="..cases.." failed="..failed.." Studio/API calls=0")
if failed>0 then error("Owner restoration lifecycle contract failures: "..failed) end
