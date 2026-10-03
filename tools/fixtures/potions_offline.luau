-- Offline doubles only. The test runner injects current repository sources on every run.
local checks = 0
local function check(condition, message)
	assert(condition, message)
	checks += 1
end
local function execute(text, replacements, ...)
	local fn, err = loadstring(text)
	assert(fn, err)
	setfenv(fn, setmetatable(replacements or {}, { __index = getfenv() }))
	return fn(...)
end
do
	local net = execute(NET_SOURCE, { game = { GetService = function() return {} end } })
	local names = {}
	for _, name in net.Names do names[name] = (names[name] or 0) + 1 end
	check(names.BuyPotion == 1, "actual Net registry missing/duplicated BuyPotion")
	check(names.UsePotion == 1, "actual Net registry missing/duplicated UsePotion")
end
local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for k, v in value do result[k] = copy(v) end
	return result
end
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn) table.insert(callbacks, fn); return { Disconnect = function() end } end,
		Fire = function(_, ...) for _, fn in callbacks do fn(...) end end,
	}
end
local vectorMT = {}
local function vector(x, y, z) return setmetatable({ X=x, Y=y, Z=z, __kind="Vector3" }, vectorMT) end
vectorMT.__add = function(a,b) return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vectorMT.__sub = function(a, b)
	local x,y,z = a.X-b.X, a.Y-b.Y, a.Z-b.Z
	return { Magnitude = math.sqrt(x*x+y*y+z*z) }
end
local function node(kind, parent, position)
	local n = { Parent = parent, Position = position, Children = {}, __kind="Instance", Attrs={} }
	function n:IsA(name) return kind == name end
	function n:GetAttribute(key) return self.Attrs[key] end
	function n:SetAttribute(key,value) self.Attrs[key]=value end
	function n:IsDescendantOf(target)
		local p = self.Parent
		while p do if p == target then return true end; p = p.Parent end
		return false
	end
	function n:FindFirstChild(name) return self.Children[name] end
	return n
end
local serial = 0
local function fixture(saved, missingMerchant)
	serial += 1
	local config = execute(CONFIG_SOURCE)
	config.Levels = { MaxLevel = 100 }
	config.MaxWeaponTier = 7
	config.Tickets = { MaxReceiptsKept = 100 }
	config.Rebirth = { BonusNormal = .25 }
	config.Factions = { None = {}, Halo = {}, Horns = {}, Neutral = {} }
	config.Classes = { Warrior = {}, Mage = {}, Archer = {} }
	config.Text = { NotEnoughGold = "골드가 부족해요." }
	config.Vitals.MerchantEnabled = true -- explicit offline activation; production remains gated by GPT selection
	local attrs = { ClassChosen=true }
	local players = {}
	local player = { Parent=players, UserId=serial, Name="Tester"..serial, __kind="Instance", IsA=function(_,kind) return kind=="Player" end }
	function player:GetAttribute(key) return attrs[key] end
	function player:SetAttribute(key, value) attrs[key] = value end
	local world = node("Workspace")
	local map = node("Model", world); world.Children.Map = map
	local npcs = node("Folder", map); map.Children.NPCs = npcs
	local merchant = node("Model", npcs)
	merchant:SetAttribute("HHC_PotionMerchant",true)
	local merchantPart = node("BasePart", merchant, vector(0,0,0)); merchant.PrimaryPart = merchantPart
	local prompt=node("ProximityPrompt",merchantPart);prompt.Name=config.Vitals.PotionMerchantPrompt;prompt.Enabled=true
	merchantPart.Children[prompt.Name]=prompt
	if not missingMerchant then npcs.Children.PotionMerchant = merchant end
	local rootPart = node("BasePart", world, vector(3,0,0))
	local hum = { Health=50, MaxHealth=100 }
	local f = { Config=config, Player=player, Attrs=attrs, Now=100, Root=rootPart, Humanoid=hum,
		World=world, Merchant=merchant, MerchantPart=merchantPart, Prompt=prompt, Ready=true, Blocks={}, Tasks={}, Notices={},Opened={} }
	function world:GetServerTimeNow() return f.Now end
	local rows = {}
	if saved then rows["P_"..serial] = copy(saved) end
	local db = {}
	function db:GetAsync(key) return copy(rows[key]) end
	function db:UpdateAsync(key, fn)
		local result = fn(copy(rows[key]))
		if result ~= nil then rows[key] = copy(result) end
		return copy(result)
	end
	local remote = {}
	local net = { Get = function(name)
		if not remote[name] then remote[name] = { OnServerEvent=signal(),FireClient=function(_,p,id) table.insert(f.Opened,{Player=p,Id=id}) end } end
		return remote[name]
	end, Notify = function(_, message, kind) table.insert(f.Notices, { message, kind }) end,
	Fx = function() end }
	local util = { DeepCopy=copy, Warn=function(tag, message)
		if tag ~= "DataService" then error(message) end
	end,
		Signal={ new=signal }, RateLimit=function(_, key) return f.Blocks[key] ~= true end,
		IsAlive=function() return f.Humanoid ~= nil and f.Humanoid.Health > 0 and f.Root ~= nil end,
		GetHumanoid=function() return f.Humanoid end, GetRoot=function() return f.Root end }
	local services = { Players=players, ReplicatedStorage={ Shared={ Config="Config", Net="Net", Util="Util" } },
		ProximityPromptService={PromptTriggered=signal()},
		RunService={ IsStudio=function() return true end }, HttpService={ GenerateGUID=function() return "token"..serial end },
		DataStoreService={ GetDataStore=function() return db end } }
	local env = { print=function() end, game={ JobId="offline", GetService=function(_, name) return assert(services[name], name) end },
		workspace=world, require=function(name)
			if name == "Config" then return config elseif name == "Net" then return net elseif name == "Util" then return util end
			error("unexpected dependency")
		end, typeof=function(value) return type(value)=="table" and value.__kind or type(value) end,
		task={ spawn=function(fn) table.insert(f.Tasks, fn) end, wait=function() error("unexpected yield") end } }
	local dataService = execute(DATA_SOURCE, env)
	dataService.Init({})
	dataService.Start()
	f.Tasks[1]() -- mocked datastore probe; leave infinite autosave task unstarted
	local data = dataService.Load(player)
	assert(data)
	local ps = { IsReady=function() return f.Ready end, GetData=function() return data end,
		MarkActive=function() f.Active=true end, PlayerReady=signal(), PlayerLeaving=signal(), CharacterSpawned=signal() }
	local mirrored = {}
	for _, key in config.Data.Mirrored do mirrored[key]=true end
	ps.SetStat = execute(SET_STAT_SOURCE, env, { DataService=dataService }, mirrored)
	ps.AddStat = function(p,k,value) ps.SetStat(p,k,(data[k] or 0)+value) end
	local registry = { PlayerService=ps, DataService=dataService, MonsterService={ MonsterKilled=signal() } }
	local gold = execute(GOLD_SOURCE, env); registry.ProgressionService=gold; gold.Init(registry)
	local shop = execute(SHOP_SOURCE, env); shop.Init(registry); shop.Start()
	local vitals = execute(VITALS_SOURCE, env); vitals.Init(registry); vitals.Start()
	ps.PlayerReady:Fire(player, data)
	f.Data, f.StoreRows, f.Shop, f.Vitals, f.Registry = data, rows, shop, vitals, registry
	function f:Stock(hp,mp) ps.SetStat(player,"HPPotionCount",hp); ps.SetStat(player,"MPPotionCount",mp) end
	function f:Gold(carried,bank) ps.SetStat(player,"CarriedGold",carried); ps.SetStat(player,"BankGold",bank) end
	function f:Buy(kind,amount) return shop.BuyPotion(player,kind,amount) end
	function f:Use(kind) remote.UsePotion.OnServerEvent:Fire(player,kind) end
	function f:Open(promptArg,playerArg)
		if playerArg==nil then playerArg=player end
		services.ProximityPromptService.PromptTriggered:Fire(promptArg,playerArg)
	end
	function f:Snapshot() return { self.Data.HPPotionCount,self.Data.MPPotionCount,self.Data.CarriedGold,self.Data.BankGold,
		self.Humanoid and self.Humanoid.Health,self.Attrs.Mana,self.Attrs.HPPotionReadyAt,self.Attrs.MPPotionReadyAt } end
	function f:Unchanged(before)
		local after=self:Snapshot()
		for i=1,8 do check(after[i] == before[i], "rejected transaction changed field "..i) end
	end
	return f
end

-- Prompt opening is server-owned and exact-instance checked; opening never purchases/changes resources.
do
	local f=fixture();local before=f:Snapshot();f:Open(f.Prompt)
	check(#f.Opened==1 and f.Opened[1].Player==f.Player and f.Opened[1].Id=="PotionShop","verified merchant prompt did not open owner potion panel")
	f:Unchanged(before)
	f.Blocks.PotionMerchantPrompt=true;f:Open(f.Prompt)
	check(#f.Opened==1,"prompt cooldown did not block another opening")
end
for _,badPrompt in {false,"PotionShopPrompt",{},node("BasePart"),node("ProximityPrompt")} do
	local f=fixture();f:Open(badPrompt);check(#f.Opened==0,"malformed/forged prompt opened store")
end
for _,mutate in {
	function(f) f.Config.Vitals.MerchantEnabled=false end,
	function(f) f.Prompt.Enabled=false end,
	function(f) f.Prompt.Name="AltarPrompt" end,
	function(f) f.Prompt.Parent=f.World end,
	function(f) f.MerchantPart.Children[f.Config.Vitals.PotionMerchantPrompt]=node("ProximityPrompt",f.MerchantPart) end,
	function(f) f.Merchant:SetAttribute("HHC_PotionMerchant",nil) end,
	function(f) f.MerchantPart.Parent=f.World end,
	function(f) f.World.Children.Map=nil end,
	function(f) f.Root.Position=vector(12.01,0,0) end,
	function(f) f.Root.Position=vector(0,12.01,0) end,
	function(f) f.Root.Position=vector(math.huge,0,0) end,
	function(f) f.Config.Vitals.PotionMerchantDistance=0/0 end,
	function(f) f.Ready=false end,
	function(f) f.Humanoid.Health=0 end,
	function(f) f.Player.Parent=nil end,
	function(f) f.Blocks.PotionMerchantPrompt=true end,
} do
	local f=fixture();mutate(f);local before=f:Snapshot();f:Open(f.Prompt)
	check(#f.Opened==0,"untrusted/inactive/distant prompt opened store");f:Unchanged(before)
end
do
	local f=fixture();local clone=node("ProximityPrompt",f.MerchantPart)
	clone.Name=f.Prompt.Name;clone.Enabled=true;f:Open(clone)
	check(#f.Opened==0,"same-name cloned prompt bypassed exact identity")
	for _,badPlayer in {false,"Owner",{},node("Player"),node("Model",f.Player.Parent)} do
		f:Open(f.Prompt,badPlayer);check(#f.Opened==0,"forged prompt player opened owner UI")
	end
	local g=fixture();g.Config.Vitals.MerchantEnabled=false;g:Gold(100,0)
	local before=g:Snapshot();check(g:Buy("HP",1)==false,"disabled merchant accepted direct remote purchase");g:Unchanged(before)
	local h=fixture();h.Merchant:SetAttribute("HHC_PotionMerchant",nil);h:Gold(100,0)
	local prior=h:Snapshot();check(h:Buy("MP",1)==false,"unmarked server model accepted direct purchase");h:Unchanged(prior)
	local boundary=fixture();boundary.Root.Position=vector(12,0,0);boundary:Open(boundary.Prompt)
	check(#boundary.Opened==1,"exact 12-stud prompt boundary was rejected")
end
for _,mutate in {
	function(f) f.Prompt.Enabled=false end,
	function(f) f.Prompt.Parent=f.World end,
	function(f) f.MerchantPart.Children[f.Config.Vitals.PotionMerchantPrompt]=nil end,
	function(f) f.MerchantPart.Children[f.Config.Vitals.PotionMerchantPrompt]=node("BasePart",f.MerchantPart) end,
	function(f) f.Merchant.Parent=f.World end,
	function(f) f.World.Children.Map.Parent=nil end,
	function(f) f.World.Children.Map.Children.NPCs.Parent=f.World end,
} do
	local f=fixture();f:Gold(100,0);mutate(f);local before=f:Snapshot()
	check(f:Buy("HP",1)==false and f:Buy("MP",5)==false,"direct purchase bypassed exact NPC/prompt enabled/path validation")
	f:Unchanged(before);f:Open(f.Prompt)
	check(#f.Opened==0,"invalid server NPC/prompt opened shop")
end

-- New/legacy data: zero free stock; corrupt fractions/NaN/infinity reset; valid stock and the cap persist.
do
	local f=fixture(); check(f.Data.HPPotionCount==0 and f.Data.MPPotionCount==0,"new players received free bottles")
	local old=fixture({ Version=2,Level=1,WeaponTier=1 })
	check(old.Data.HPPotionCount==0 and old.Data.MPPotionCount==0,"legacy players received free bottles")
	for _,bad in { -.1,-1,1.5,0/0,math.huge,-math.huge,"5",{},true } do
		local row=fixture({Version=2,HPPotionCount=bad,MPPotionCount=bad})
		check(row.Data.HPPotionCount==0 and row.Data.MPPotionCount==0,"corrupt stock granted bottles")
	end
	local capped=fixture({Version=2,HPPotionCount=1000,MPPotionCount=99})
	check(capped.Data.HPPotionCount==99 and capped.Data.MPPotionCount==99,"cap normalization failed")
	local valid=fixture({Version=2,HPPotionCount=6,MPPotionCount=9})
	check(valid.Data.HPPotionCount==6 and valid.Data.MPPotionCount==9,"valid saved stock lost")
end

-- Both bottle kinds, amount1/5, real carried-first SpendGold, exact price, cap and mirrored stock.
for _,kind in {"HP","MP"} do
	for _,amount in {1,5} do
		local f=fixture(); f:Gold(7,100)
		check(f:Buy(kind,amount)==true,"valid purchase rejected")
		local key=f.Config.PotionStockKey(kind)
		check(f.Data[key]==amount and f.Attrs[key]==amount,"purchased stock not mirrored")
		check(f.Data.CarriedGold==0 and f.Data.BankGold==107-amount*10,"gold price/carried-first deduction wrong")
		check(f.Registry.DataService.Save(f.Player,false),"mock save failed")
		local row=f.StoreRows["P_"..f.Player.UserId]
		check(row[key]==amount,"purchased stock not in persisted record")
	end
end

-- Untrusted amounts/types, forged kind, missing/far/wrong merchant, dead/unready players, overflow/poverty.
for _,amount in {0,-1,1.5,2,6,100,0/0,math.huge,-math.huge,"1",{},true} do
	local f=fixture(); f:Gold(100,100); local before=f:Snapshot()
	check(f:Buy("HP",amount)==false,"invalid amount accepted"); f:Unchanged(before)
end
for _,kind in {"hp","Mana","Gold",0,{},true} do
	local f=fixture(); f:Gold(100,100); local before=f:Snapshot()
	check(f:Buy(kind,1)==false,"forged kind accepted"); f:Unchanged(before)
end
for _,mutate in {
	function(f) f.Root.Position=vector(12.01,0,0) end,
	function(f) f.World.Children.Map=nil end,
	function(f) f.Merchant.PrimaryPart=nil end,
	function(f) f.MerchantPart.Parent=f.World end,
	function(f) f.Root.Position=vector(0/0,0,0) end,
	function(f) f.Ready=false end,
	function(f) f.Humanoid.Health=0 end,
	function(f) f.Player.Parent=nil end,
	function(f) f.Blocks.BuyPotion=true end,
	function(f) f:Stock(99,0) end,
	function(f) f:Stock(98,0) end,
	function(f) f:Stock(1.5,0) end,
	function(f) f:Stock(100,0) end,
	function(f) f:Gold(4,5) end,
} do
	local f=fixture(); f:Gold(100,100); mutate(f); local before=f:Snapshot()
	check(f:Buy("HP",5)==false,"invalid shop state accepted"); f:Unchanged(before)
end
do
	local f=fixture(nil,true); f:Gold(100,100); local before=f:Snapshot()
	check(f:Buy("HP",1)==false,"missing merchant accepted"); f:Unchanged(before)
	local g=fixture(); g.Root.Position=vector(12,0,0); g:Gold(100,0)
	check(g:Buy("HP",1),"distance boundary rejected")
	g:Stock(98,0); check(g:Buy("HP",1) and g.Data.HPPotionCount==99,"exact cap rejected")
	local h=fixture();h:Gold(50,0); check(h:Buy("MP",5) and h.Data.CarriedGold==0,"exact gold rejected")
end

-- The actual map helper and R15 validator: ready folder only, immutable approved geometry, no scripts/physics.
do
	local enum={KeyCode={G="G"},HumanoidRigType={R15="R15"},HumanoidDisplayDistanceType={None="None"}}
	local methods,mt={},{}
	local function positionFrame(x,y,z)
		local p={Position=vector(x,y,z)}
		return setmetatable(p,{__add=function(a,b) return positionFrame(a.Position.X+b.X,a.Position.Y+b.Y,a.Position.Z+b.Z) end})
	end
	local function object(kind,name)
		return setmetatable({_p={ClassName=kind,Name=name or kind,__kind="Instance"},_children={},_attrs={}},mt)
	end
	mt.__index=function(self,key) return methods[key] or self._p[key] end
	mt.__newindex=function(self,key,value)
		if key=="Parent" then
			local old=self._p.Parent
			if old==value then return end
			if old then local idx=table.find(old._children,self);if idx then table.remove(old._children,idx) end end
			self._p.Parent=value;if value then table.insert(value._children,self) end
		else self._p[key]=value end
	end
	function methods:IsA(kind)
		return self.ClassName==kind or (kind=="BasePart" and (self.ClassName=="MeshPart" or self.ClassName=="Part"))
			or (kind=="LuaSourceContainer" and (self.ClassName=="Script" or self.ClassName=="LocalScript" or self.ClassName=="ModuleScript"))
	end
	function methods:GetAttribute(key) return self._attrs[key] end
	function methods:SetAttribute(key,value) self._attrs[key]=value end
	function methods:GetChildren() return table.clone(self._children) end
	function methods:GetDescendants()
		local out={};local function visit(n) for _,c in n._children do table.insert(out,c);visit(c) end end;visit(self);return out
	end
	function methods:FindFirstChild(name) for _,c in self._children do if c.Name==name then return c end end;return nil end
	function methods:FindFirstChildOfClass(kind) for _,c in self._children do if c:IsA(kind) then return c end end;return nil end
	function methods:IsDescendantOf(parent)
		local p=self.Parent;while p do if p==parent then return true end;p=p.Parent end;return false
	end
	function methods:Destroy() for _,c in self:GetChildren() do c:Destroy() end;self.Parent=nil;self.Destroyed=true end
	function methods:GetPivot() return self.Pivot end
	function methods:GetBoundingBox() if self.BoundsError then error("invalid imported bounds") end;return self.Pivot,vector(3,5.5,2) end
	function methods:PivotTo(pivot) self.Pivot=pivot;self.PrimaryPart.Position=pivot.Position end
	function methods:Clone()
		if self.CloneError then error("clone failed") end
		local copies={}
		local function allocate(src,parent)
			local dest=object(src.ClassName,src.Name);copies[src]=dest;dest.Parent=parent
			for _,c in src._children do allocate(c,dest) end
			return dest
		end
		local result=allocate(self)
		for src,dest in copies do
			for key,value in src._p do if key~="Parent" then dest[key]=copies[value] or value end end
			dest._attrs=table.clone(src._attrs)
		end
		self.LastClone=result;return result
	end
	local env={Enum=enum,Vector3={new=vector},Instance={new=object},
		typeof=function(v) return type(v)=="table" and v.__kind or type(v) end}
	local validator=execute(COSTUME_VALIDATOR_SOURCE,env)
	local function mapFixture()
		local cfg=execute(CONFIG_SOURCE);cfg.Zones={Crossroads={Spawn=vector(0,0,-25)}}
		local storage,npcs=object("ServerStorage"),object("Folder","NPCs")
		local rigs=object("Folder","CostumeRigs");rigs.Parent=storage
		local template=object("Model",cfg.Vitals.PotionMerchantTemplate);template.Pivot=positionFrame(0,2.75,0);template.Parent=rigs
		local human=object("Humanoid","Humanoid");human.Health=100;human.RigType="R15";human.Parent=template
		local parts={}
		for _,name in {"HumanoidRootPart","Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"} do
			local part=object("MeshPart",name);part.MeshId="approved:"..name;part.TextureID="approved-texture:"..name
			part.Position=vector(0,2.75,0);part.Anchored=false;part.CanCollide=true;part.CanTouch=true;part.CanQuery=true
			part.Parent=template;parts[name]=part
		end
		for _,edge in {{"HumanoidRootPart","LowerTorso"},{"LowerTorso","UpperTorso"},{"UpperTorso","Head"},{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}} do
			local joint=object("Motor6D",edge[2].."Joint");joint.Enabled=true;joint.Part0=parts[edge[1]];joint.Part1=parts[edge[2]];joint.Parent=template
		end
		template.PrimaryPart=parts.HumanoidRootPart
		for _,kind in {"Script","LocalScript","ModuleScript","Tool","ForceField","ProximityPrompt"} do local child=object(kind,"Unwanted"..kind);child.Parent=template end
		local tags={};local warned={};local ctx={pieces=0}
		local build=execute(MAP_MERCHANT_SOURCE,env,cfg,storage,validator,{AddTag=function(_,obj,tag) tags[obj]=tag end},
			{Warn=function(_,msg) table.insert(warned,msg) end},"MapBuilder",function(inst,suffix) inst.Name..=suffix end)
		return {Config=cfg,Storage=storage,NPCs=npcs,Rigs=rigs,Template=template,Parts=parts,Tags=tags,Warnings=warned,Ctx=ctx,
			Build=function() build(ctx,npcs) end}
	end
	local f=mapFixture();f.Build();check(#f.NPCs:GetChildren()==0 and f.Ctx.pieces==0,"unselected GPT merchant created visible NPC")
	f.Config.Vitals.MerchantEnabled=true;f.Build()
	local npc=f.NPCs:FindFirstChild("PotionMerchant");check(npc~=nil and f.Ctx.pieces==1,"approved ready rig did not create merchant: "..table.concat(f.Warnings,"; "))
	check(npc~=f.Template and f.Template.Parent==f.Rigs and validator.ValidateTemplate(f.Template),"merchant consumed/changed ready rig")
	check(f.Tags[npc]=="NPC" and npc:GetAttribute("HHC_PotionMerchant")==true,"merchant NPC/ownership marker missing")
	local prompt=npc.PrimaryPart:FindFirstChild(f.Config.Vitals.PotionMerchantPrompt)
	check(prompt and prompt.Enabled and prompt.KeyboardKeyCode=="G" and prompt.MaxActivationDistance==12,"merchant G/range prompt contract wrong")
	check(prompt:GetAttribute("Conversation")==true and prompt.RequiresLineOfSight==false,"verified merchant conversation contract missing")
	check(npc:GetPivot().Position.X==12 and npc:GetPivot().Position.Y==2.75 and npc:GetPivot().Position.Z==-34,"merchant not beside safe Crossroads spawn/standing height")
	for name,original in f.Parts do
		local copied=npc:FindFirstChild(name)
		check(copied and copied.MeshId==original.MeshId and copied.TextureID==original.TextureID,"merchant altered approved mesh/texture")
		check(copied.Anchored and not copied.CanCollide and not copied.CanTouch and not copied.CanQuery,"merchant has moving/collidable/queryable part")
		check(not original.Anchored and original.CanCollide and original.Parent==f.Template,"NPC preparation modified avatar source part")
	end
	for _,child in npc:GetDescendants() do check(not child:IsA("LuaSourceContainer") and not child:IsA("Tool") and not child:IsA("ForceField"),"merchant retained executable/player-only child") end
	f.Build();check(f.NPCs:FindFirstChild("PotionMerchant")==npc and #f.NPCs:GetChildren()==1 and f.Ctx.pieces==1,"map rebuild duplicated merchant")
	prompt:Destroy();f.Build();check(npc.PrimaryPart:FindFirstChild(f.Config.Vitals.PotionMerchantPrompt)~=nil,"missing merchant prompt not repaired")
	f.Config.Vitals.MerchantEnabled=false;f.Build()
	check(not npc.PrimaryPart:FindFirstChild(f.Config.Vitals.PotionMerchantPrompt).Enabled,"disabled GPT merchant retained active prompt")
	for _,mutate in {
		function(t) t.Rigs.Name="CostumePendingRigs" end,
		function(t) t.Rigs.Parent=nil end,
		function(t) t.Rigs.ClassName="Model" end,
		function(t) t.Template:FindFirstChild("Head"):Destroy() end,
		function(t) t.Template:FindFirstChildOfClass("Humanoid").Health=0 end,
		function(t) t.Template:FindFirstChild("LeftHandJoint").Enabled=false end,
		function(t) t.Template.CloneError=true end,
		function(t) t.Template.BoundsError=true end,
		function(t) t.Config.Vitals.PotionMerchantOffset={X=math.huge,Z=0} end,
		function(t) t.Config.Vitals.PotionMerchantOffset={X=0/0,Z=0} end,
		function(t) local occupied=object("Model","PotionMerchant");occupied.Parent=t.NPCs end,
	} do
		local t=mapFixture();t.Config.Vitals.MerchantEnabled=true;mutate(t);t.Build()
		check(t.Ctx.pieces==0,"unready/pending/invalid/unrelated merchant source became NPC")
		local unexpected=t.NPCs:FindFirstChild("PotionMerchant")
		check(not unexpected or unexpected:GetAttribute("HHC_PotionMerchant")~=true,"failed preparation left server-owned NPC")
	end
end

-- Stock consumption only after actual recovery, independent deadlines and no free refill on respawn/cosmetic.
do
	local f=fixture();f:Stock(3,3);f.Vitals.DebugSetMana(f.Player,20)
	f:Use("HP");check(f.Humanoid.Health==80,"HP recovery wrong")
	check(f.Data.HPPotionCount==2 and f.Attrs.HPPotionCount==2,"HP did not consume exactly1")
	check(f.Attrs.HPPotionReadyAt==110,"HP cooldown wrong")
	f:Use("MP");check(f.Attrs.Mana==60 and f.Data.MPPotionCount==2,"MP recovery/stock wrong")
	check(f.Attrs.MPPotionReadyAt==110,"independent MP cooldown wrong")
	local before=f:Snapshot();f:Use("HP");f:Use("MP");f:Unchanged(before)
	f.Registry.PlayerService.CharacterSpawned:Fire(f.Player,nil,nil,true);f:Unchanged(before)
	f.Registry.PlayerService.CharacterSpawned:Fire(f.Player,nil,nil,false)
	check(f.Attrs.Mana==100 and f.Data.HPPotionCount==2 and f.Data.MPPotionCount==2,"respawn refilled stock")
	check(f.Attrs.HPPotionReadyAt==110 and f.Attrs.MPPotionReadyAt==110,"respawn erased cooldowns")
	f.Now=110;f.Humanoid.Health=99;f:Use("HP")
	check(f.Humanoid.Health==100 and f.Data.HPPotionCount==1,"capped HP heal not charged exactly1")
	f.Vitals.DebugSetMana(f.Player,99);f:Use("MP")
	check(f.Attrs.Mana==100 and f.Data.MPPotionCount==1,"capped MP recovery not charged exactly1")
end
for _,kind in {"HP","MP"} do
	for _,mutate in {
		function(f) f:Stock(0,0) end,
		function(f) f:Stock(-1,-1) end,
		function(f) f:Stock(1.5,1.5) end,
		function(f) f:Stock(100,100) end,
		function(f) f.Humanoid.Health=100;f.Vitals.DebugSetMana(f.Player,100) end,
		function(f) f.Attrs.KaijuState="Active" end,
		function(f) f.Attrs.KaijuState="Siren" end,
		function(f) f.Ready=false end,
		function(f) f.Humanoid.Health=0 end,
		function(f) f.Attrs.ClassChosen=false end,
		function(f) f.Player.Parent=nil end,
		function(f) f.Blocks["UsePotion"..kind]=true end,
	} do
		local f=fixture();f:Stock(3,3);f.Vitals.DebugSetMana(f.Player,20);mutate(f)
		local before=f:Snapshot();f:Use(kind);f:Unchanged(before)
	end
end
do
	local f=fixture();f:Stock(3,3);f.Vitals.DebugSetMana(f.Player,20)
	local before=f:Snapshot();f:Use("fake");f:Use({});f:Unchanged(before)
	check(f.Registry.DataService.Save(f.Player,false),"final mock save failed")
	check(f.StoreRows["P_"..f.Player.UserId].HPPotionCount==3,"rejected use changed persisted stock")
end
print("POTION_OFFLINE_OK checks="..checks.." Studio/API calls=0")
