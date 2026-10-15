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
-- Config literals need only inert value constructors offline.
local CONFIG_ENV = { Color3 = { fromRGB = function(r, g, b) return { R = r, G = g, B = b } end,
	new = function(r, g, b) return { R = r, G = g, B = b } end } }
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
	local config = execute(CONFIG_SOURCE, CONFIG_ENV)
	config.Levels = { MaxLevel = 100 }
	check(config.MaxWeaponTier == 11, "extracted Config.MaxWeaponTier is not 11 (C1 tier 9 + A23-186 joke tiers 10 / 11)")
	config.Tickets = { MaxReceiptsKept = 100 }
	config.Rebirth = { BonusNormal = .25 }
	config.Factions = { None = {}, Halo = {}, Horns = {}, Neutral = {} }
	config.Classes = { Warrior = {}, Mage = {}, Archer = {} }
	-- The real Config.Text table (extracted by the runner): ShopService's player-facing strings live there.
	check(type(config.Text) == "table" and type(config.Text.NotEnoughGold) == "string"
		and type(config.Text.PotionBought) == "string" and type(config.Text.PotionStockFull) == "string"
		and type(config.Text.PotionShopFar) == "string", "ShopService potion strings missing from Config.Text")
	check(config.Vitals.MerchantEnabled == true, "A23-6 production potion merchant is disabled")
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
	merchantPart.Anchored = true -- #34: a seller's root is server-anchored (a client cannot move it)
	local prompt=node("ProximityPrompt",merchantPart);prompt.Name=config.Vitals.PotionMerchantPrompt;prompt.Enabled=true
	merchantPart.Children[prompt.Name]=prompt
	if not missingMerchant then npcs.Children.PotionMerchant = merchant end
	local rootPart = node("BasePart", world, vector(3,0,0))
	local hum = { Health=50, MaxHealth=100 }
	local f = { Config=config, Player=player, Attrs=attrs, Now=100, Root=rootPart, Humanoid=hum,
		World=world, Merchant=merchant, MerchantPart=merchantPart, Prompt=prompt, Ready=true, Blocks={}, Tasks={}, Notices={},Opened={}, Tagged={}, FxLog={} }
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
	Fx = function(p, kind, data) if f.FxLog then table.insert(f.FxLog, { P = p, Kind = kind, Data = data }) end end }
	local util = { DeepCopy=copy, Warn=function(tag, message)
		if tag ~= "DataService" then error(message) end
	end,
		Signal={ new=signal }, RateLimit=function(_, key) return f.Blocks[key] ~= true end,
		IsAlive=function() return f.Humanoid ~= nil and f.Humanoid.Health > 0 and f.Root ~= nil end,
		GetHumanoid=function() return f.Humanoid end, GetRoot=function() return f.Root end }
	local services = { Players=players, ReplicatedStorage={ Shared={ Config="Config", Net="Net", Util="Util" } },
		ProximityPromptService={PromptTriggered=signal()},
		-- #34: server-side tags only (a client's tags never replicate); f.Tagged[tag] = { models }
		CollectionService={GetTagged=function(_,tag) return table.clone(f.Tagged[tag] or {}) end},
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
	-- #34: a second seller, shaped like TownNpcs' Halo stall seller (Config.TownNpcs PotionHalo): a server-made Model in
	-- Map.NPCs under its own name, anchored root at `position` with the server prompt, tagged Config.Vitals.PotionMerchantTag
	-- (or the given tags)
	function f:Stall(position, tags)
		local folder = self.World.Children.Map.Children.NPCs
		local model = node("Model", folder); model:SetAttribute("HHC_PotionMerchant", true)
		local part = node("BasePart", model, position); part.Anchored = true; model.PrimaryPart = part
		local stallPrompt = node("ProximityPrompt", part)
		stallPrompt.Name = self.Config.Vitals.PotionMerchantPrompt; stallPrompt.Enabled = true
		part.Children[stallPrompt.Name] = stallPrompt
		folder.Children.PotionMerchant_Halo = model
		for _, tag in tags or { self.Config.Vitals.PotionMerchantTag } do
			self.Tagged[tag] = self.Tagged[tag] or {}
			table.insert(self.Tagged[tag], model)
		end
		return model, part, stallPrompt
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

-- zone_check_halo #34 (검수 2026-10-10): every server-made seller tagged Config.Vitals.PotionMerchantTag sells with the one
-- price table; the nearest live seller within PotionMerchantDistance decides; a prompt opens the shop only at its own seller.
do
	local prod=execute(CONFIG_SOURCE,CONFIG_ENV).Vitals
	check(prod.PotionMerchantTag=="PotionMerchant","#34 seller tag is not \"PotionMerchant\" (TownNpcs / MiniMap / VitalsUI contract)")
end
do
	-- far from the Crossroads seller (0,0,0), 10 studs from the Halo stall: opening, buying and the one price work there
	local f=fixture();local _,_,stallPrompt=f:Stall(vector(-34,11,-546));f.Root.Position=vector(-34,11,-536);f:Gold(200,0)
	f:Open(f.Prompt);check(#f.Opened==0,"#34 the far Crossroads prompt opened the shop at the Halo stall")
	f:Open(stallPrompt)
	check(#f.Opened==1 and f.Opened[1].Id=="PotionShop" and f.Opened[1].Player==f.Player,"#34 Halo stall prompt did not open the shop")
	local price=f.Config.Vitals.PotionPrices
	check(f:Buy("HP",1)==true and f.Data.HPPotionCount==1 and f.Data.CarriedGold==200-price.HP,"#34 Halo stall HP sale failed / other price")
	check(f:Buy("MP",5)==true and f.Data.MPPotionCount==5 and f.Data.CarriedGold==200-price.HP-5*price.MP,"#34 Halo stall MP x5 sale failed")
	-- the boundary: exactly PotionMerchantDistance from the stall sells and opens, 12.01 does neither
	local edge=fixture();local _,_,edgePrompt=edge:Stall(vector(-34,11,-546));edge.Root.Position=vector(-34,11,-534);edge:Gold(100,0)
	check(edge:Buy("HP",1)==true,"#34 exact 12-stud stall boundary refused a sale")
	edge:Open(edgePrompt);check(#edge.Opened==1,"#34 exact 12-stud stall boundary refused the prompt")
	local far=fixture();local _,_,farPrompt=far:Stall(vector(-34,11,-546));far.Root.Position=vector(-34,11,-533.99);far:Gold(100,0)
	local before=far:Snapshot();check(far:Buy("HP",1)==false,"#34 stall sold at 12.01 studs");far:Unchanged(before)
	far:Open(farPrompt);check(#far.Opened==0,"#34 stall prompt opened at 12.01 studs")
	-- at the Crossroads with a stall in the world: the far Halo prompt stays shut, the Crossroads seller still works
	local home=fixture();local _,_,haloPrompt=home:Stall(vector(-34,11,-546));home:Gold(100,0)
	home:Open(haloPrompt);check(#home.Opened==0,"#34 the far Halo prompt opened the shop at the Crossroads")
	home:Open(home.Prompt);check(#home.Opened==1 and home:Buy("HP",1)==true,"#34 the Crossroads seller stopped working beside a stall")
	-- MapBuilder tags the Crossroads seller too: found by name AND by tag, it still sells
	local both=fixture();both.Tagged[both.Config.Vitals.PotionMerchantTag]={both.Merchant};both:Gold(100,0)
	both:Open(both.Prompt);check(#both.Opened==1 and both:Buy("HP",1)==true,"#34 the tagged Crossroads seller stopped working")
	-- a tagged seller outside Map.NPCs (e.g. built inside a stall prop) is still a seller
	local decor=fixture();local stall,_,decorPrompt=decor:Stall(vector(-34,11,-546));stall.Parent=decor.World
	decor.Root.Position=vector(-34,11,-536);decor:Gold(100,0)
	decor:Open(decorPrompt);check(#decor.Opened==1 and decor:Buy("HP",1)==true,"#34 a tagged seller outside Map.NPCs was refused")
	-- the nearest LIVE seller decides: a disabled nearer stall does not hide the live Crossroads seller in range
	local near=fixture();local _,_,nearPrompt=near:Stall(vector(4,0,0));nearPrompt.Enabled=false
	near.Root.Position=vector(3,0,0);near:Gold(100,0)
	check(near:Buy("HP",1)==true,"#34 a disabled nearer stall blocked the live seller in range")
	near:Open(nearPrompt);check(#near.Opened==0,"#34 a disabled stall prompt opened the shop")
	-- a same-name clone of the stall prompt never opens the shop
	local twin=fixture();local _,stallPart,twinPrompt=twin:Stall(vector(-34,11,-546));twin.Root.Position=vector(-34,11,-536)
	local clone=node("ProximityPrompt",stallPart);clone.Name=twinPrompt.Name;clone.Enabled=true;twin:Open(clone)
	check(#twin.Opened==0,"#34 same-name cloned stall prompt bypassed exact identity")
end
-- Nothing a client can create or move, and no half-made / disabled / template seller, can sell or open the shop.
for label,mutate in {
	Untagged=function(f) f.Tagged[f.Config.Vitals.PotionMerchantTag]=nil end,
	OnlyNpcTag=function(f,m) f.Tagged[f.Config.Vitals.PotionMerchantTag]=nil;f.Tagged.NPC={m} end,
	NoTagInConfig=function(f) f.Config.Vitals.PotionMerchantTag=nil end,
	NoAttribute=function(_,m) m:SetAttribute("HHC_PotionMerchant",nil) end,
	TextAttribute=function(_,m) m:SetAttribute("HHC_PotionMerchant","true") end,
	NotAModel=function(f,m,part)
		local fake=node("Folder",m.Parent);fake.Attrs=m.Attrs;fake.PrimaryPart=part;part.Parent=fake
		f.Tagged[f.Config.Vitals.PotionMerchantTag]={fake}
	end,
	TemplateOutsideWorkspace=function(_,m) m.Parent=node("Folder") end,
	Unparented=function(_,m) m.Parent=nil end,
	UnanchoredRoot=function(_,_,part) part.Anchored=false end,
	NoPrimaryPart=function(_,m) m.PrimaryPart=nil end,
	RootOutsideModel=function(f,_,part) part.Parent=f.World end,
	RootNaN=function(_,_,part) part.Position=vector(0/0,11,-546) end,
	PromptDisabled=function(_,_,_,p) p.Enabled=false end,
	PromptMissing=function(_,_,part,p) part.Children[p.Name]=nil end,
	PromptWrongClass=function(_,_,part,p) part.Children[p.Name]=node("BasePart",part) end,
	PromptMovedAway=function(f,_,_,p) p.Parent=f.World end,
	PromptShadowed=function(_,_,part,p) part.Children[p.Name]=node("ProximityPrompt",part) end,
	MerchantOff=function(f) f.Config.Vitals.MerchantEnabled=false end,
} do
	local f=fixture();local m,part,p=f:Stall(vector(-34,11,-546));f.Root.Position=vector(-34,11,-536);f:Gold(100,100)
	mutate(f,m,part,p);local before=f:Snapshot()
	check(f:Buy("HP",1)==false and f:Buy("MP",5)==false,"#34 "..label.." seller still sold");f:Unchanged(before)
	f:Open(p);check(#f.Opened==0,"#34 "..label.." seller prompt opened the shop")
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
		local f=fixture(); local price=f.Config.Vitals.PotionPrices[kind]; f:Gold(7,200)
		check(price==25,"potion price is not 25 gold")
		check(f:Buy(kind,amount)==true,"valid purchase rejected")
		local key=f.Config.PotionStockKey(kind)
		check(f.Data[key]==amount and f.Attrs[key]==amount,"purchased stock not mirrored")
		check(f.Data.CarriedGold==0 and f.Data.BankGold==207-amount*price,"gold price/carried-first deduction wrong")
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
	function(f) f:Gold(100,24) end, -- 124 < 5 x 25
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
	local h=fixture();h:Gold(5*h.Config.Vitals.PotionPrices.MP,0); check(h:Buy("MP",5) and h.Data.CarriedGold==0,"exact gold rejected")
end

-- The actual MapBuilder merchant helper (A23-6): a temporary default Roblox-style NPC built from a HumanoidDescription.
-- No costume rig, ServerStorage template or new art is read; the NPC body comes from
-- Players:CreateHumanoidModelFromDescription (doubled here; the real call loads Roblox default meshes and yields).
do
	local enum={KeyCode={E="E",G="G"},HumanoidRigType={R15="R15",R6="R6"},HumanoidDisplayDistanceType={None="None"}}
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
	function methods:GetBoundingBox() if self.BoundsError then error("invalid bounds") end;return self.Pivot,vector(4,5.2,2) end
	function methods:PivotTo(pivot) self.Pivot=pivot;if self.PrimaryPart then self.PrimaryPart.Position=pivot.Position end end
	local R15={"HumanoidRootPart","Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm",
		"RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"}
	local function mapFixture()
		local cfg=execute(CONFIG_SOURCE,CONFIG_ENV);cfg.Zones={Crossroads={Spawn=vector(0,0,-25)}}
		local npcs=object("Folder","NPCs")
		local t={Config=cfg,NPCs=npcs,Tags={},Warnings={},Ctx={pieces=0},Created={},Queue={},Defer=false}
		-- Default R15 body as Roblox returns it: bounding-box center 2.6 studs above the feet, plus default scripts.
		local players={}
		function players:CreateHumanoidModelFromDescription(desc,rigType)
			table.insert(t.Created,{Desc=desc,Rig=rigType})
			if t.CreateError then error("avatar service unavailable") end
			local npc=object("Model","Player");npc.Pivot=positionFrame(40,7.6,40)
			local human=object("Humanoid","Humanoid");human.Health=100;human.WalkSpeed=16;human.JumpPower=50
			human.AutoRotate=true;human.DisplayDistanceType="Viewer";human.Parent=npc
			for _,name in R15 do
				if not (t.NoRoot and name=="HumanoidRootPart") then
					local part=object(name=="HumanoidRootPart" and "Part" or "MeshPart",name);part.Position=vector(40,7.6,40)
					part.Anchored=false;part.CanCollide=true;part.CanTouch=true;part.CanQuery=true;part.Parent=npc
				end
			end
			for _,kind in {"Script","LocalScript"} do local s=object(kind,"Animate"..kind);s.Parent=npc end
			local nested=object("ModuleScript","Nested");nested.Parent=npc:FindFirstChild("Head")
			if t.BadBounds then npc.BoundsError=true end
			t.LastNpc=npc
			return npc
		end
		local env={Enum=enum,Vector3={new=vector},Color3={fromRGB=function(r,g,b) return {R=r,G=g,B=b} end},
			Instance={new=function(kind) return object(kind,kind) end},
			game={GetService=function(_,name) assert(name=="Players","merchant asked for "..tostring(name));return players end},
			task={spawn=function(fn) if t.Defer then table.insert(t.Queue,fn) else fn() end end},
			typeof=function(v) return type(v)=="table" and v.__kind or type(v) end}
		local build=execute(MAP_MERCHANT_SOURCE,env,cfg,{AddTag=function(_,obj,tag) t.Tags[obj]=t.Tags[obj] or {};t.Tags[obj][tag]=true end},
			{Warn=function(_,msg) table.insert(t.Warnings,msg) end},"MapBuilder",function(inst,suffix) inst.Name..=suffix end)
		function t.Build() build(t.Ctx,npcs) end
		function t.Flush() local q=t.Queue;t.Queue={};for _,fn in q do fn() end end
		return t
	end
	do
		local prod=execute(CONFIG_SOURCE,CONFIG_ENV)
		check(prod.Vitals.MerchantEnabled==true,"A23-6 production merchant is not enabled")
		check(prod.Vitals.PotionPrices.HP==25 and prod.Vitals.PotionPrices.MP==25,"potion prices are not 25/25")
		check(not string.find(MAP_MERCHANT_SOURCE,"CostumeService",1,true) and not string.find(MAP_MERCHANT_SOURCE,"CostumeRigs",1,true)
			and not string.find(MAP_MERCHANT_SOURCE,"ServerStorage",1,true),"merchant still depends on the removed costume rig source")
	end
	local f=mapFixture();f.Config.Vitals.MerchantEnabled=false;f.Build()
	check(#f.NPCs:GetChildren()==0 and f.Ctx.pieces==0 and #f.Created==0,"disabled merchant created an NPC")
	f.Config.Vitals.MerchantEnabled=true;f.Build()
	local npc=f.NPCs:FindFirstChild("PotionMerchant")
	check(npc~=nil and f.Ctx.pieces==1 and #f.Created==1,"default NPC merchant was not built: "..table.concat(f.Warnings,"; "))
	local made=f.Created[1]
	check(made.Desc.ClassName=="HumanoidDescription" and made.Rig=="R15","merchant body is not a HumanoidDescription R15 default NPC")
	local colors=f.Config.Vitals.PotionMerchantColors
	check(made.Desc.HeadColor==colors.Head and made.Desc.LeftArmColor==colors.Head and made.Desc.RightArmColor==colors.Head
		and made.Desc.TorsoColor==colors.Torso and made.Desc.LeftLegColor==colors.Legs and made.Desc.RightLegColor==colors.Legs,
		"HumanoidDescription colors do not come from Config.Vitals.PotionMerchantColors")
	check(f.Tags[npc]~=nil and f.Tags[npc].NPC==true and npc:GetAttribute("HHC_PotionMerchant")==true and npc:GetAttribute("HHC_MerchantLook")=="DefaultNPC",
		"merchant NPC tag/ownership/temporary-look markers missing")
	check(npc.PrimaryPart==npc:FindFirstChild("HumanoidRootPart"),"merchant PrimaryPart is not the root")
	local prompt=npc.PrimaryPart:FindFirstChild(f.Config.Vitals.PotionMerchantPrompt)
	check(prompt and prompt.Enabled and prompt.KeyboardKeyCode=="E" and prompt.HoldDuration==0,"merchant prompt is not E key / HoldDuration 0")
	check(prompt.MaxActivationDistance==12 and prompt.RequiresLineOfSight==false and prompt:GetAttribute("Conversation")==true,
		"verified merchant conversation/range contract missing")
	check(prompt.ActionText=="Buy potions" and prompt.ObjectText=="Fizzby","merchant prompt wording changed (⑪: the seller's name Fizzby)")
	local pivot=npc:GetPivot().Position
	check(pivot.X==12 and pivot.Z==-34 and math.abs(pivot.Y-2.6)<1e-9,"merchant not standing on the ground beside the Crossroads spawn")
	local humanoid=npc:FindFirstChildOfClass("Humanoid")
	check(humanoid.WalkSpeed==0 and humanoid.JumpPower==0 and humanoid.AutoRotate==false and humanoid.DisplayDistanceType=="None",
		"merchant humanoid can move/turn or shows a name plate")
	local parts=0
	for _,child in npc:GetDescendants() do
		check(not child:IsA("LuaSourceContainer"),"merchant kept a default script")
		if child:IsA("BasePart") then
			parts+=1
			check(child.Anchored and not child.CanCollide and not child.CanTouch and not child.CanQuery,"merchant has moving/collidable/queryable part")
		end
	end
	check(parts==#R15,"merchant body parts missing")
	f.Build();check(f.NPCs:FindFirstChild("PotionMerchant")==npc and #f.NPCs:GetChildren()==1 and f.Ctx.pieces==1 and #f.Created==1,
		"map rebuild duplicated or rebuilt the merchant")
	prompt:Destroy();f.Build()
	local repaired=npc.PrimaryPart:FindFirstChild(f.Config.Vitals.PotionMerchantPrompt)
	check(repaired~=nil and repaired.KeyboardKeyCode=="E" and repaired.HoldDuration==0,"missing merchant prompt not repaired with E/0")
	f.Config.Vitals.MerchantEnabled=false;f.Build()
	check(not repaired.Enabled and #f.Created==1,"disabled merchant retained an active prompt")
	-- Failure modes: nothing half-built or server-owned is left, and the map build itself never throws.
	for label,mutate in {
		CreateError=function(t) t.CreateError=true end,
		NoRoot=function(t) t.NoRoot=true end,
		BadBounds=function(t) t.BadBounds=true end,
		InfiniteOffset=function(t) t.Config.Vitals.PotionMerchantOffset={X=math.huge,Z=0} end,
		NanOffset=function(t) t.Config.Vitals.PotionMerchantOffset={X=0/0,Z=0} end,
		FarOffset=function(t) t.Config.Vitals.PotionMerchantOffset={X=31,Z=0} end,
		Occupied=function(t) local occupied=object("Model","PotionMerchant");occupied.Parent=t.NPCs end,
	} do
		local t=mapFixture();t.Config.Vitals.MerchantEnabled=true;mutate(t);t.Build()
		local found=t.NPCs:FindFirstChild("PotionMerchant")
		check(not found or found:GetAttribute("HHC_PotionMerchant")~=true,label.." left a server-owned merchant")
		if t.LastNpc and found~=t.LastNpc then check(t.LastNpc.Destroyed==true or t.LastNpc.Parent==nil,label.." leaked a half-built NPC") end
		if label=="Occupied" or string.find(label,"Offset") then check(#t.Created==0,label.." still built an NPC") end
	end
	-- Two builds racing the yielding avatar load: only one merchant survives.
	local race=mapFixture();race.Config.Vitals.MerchantEnabled=true;race.Defer=true
	race.Build();race.Build();check(#race.Queue==2 and #race.NPCs:GetChildren()==0,"race fixture did not defer both builds")
	race.Flush()
	check(#race.NPCs:GetChildren()==1 and #race.Created==2,"racing builds left zero or two merchants")
	local keep=race.NPCs:FindFirstChild("PotionMerchant")
	check(keep and keep:GetAttribute("HHC_PotionMerchant")==true and race.LastNpc.Destroyed==true,"second racing NPC was not destroyed")
end

-- Stock consumption only after actual recovery, independent deadlines and no free refill on respawn/cosmetic.
do
	local f=fixture();f:Stock(3,3);f.Vitals.DebugSetMana(f.Player,20)
	f:Use("HP");check(f.Humanoid.Health==80,"HP recovery wrong")
	check(f.Data.HPPotionCount==2 and f.Attrs.HPPotionCount==2,"HP did not consume exactly1")
	check(f.Attrs.HPPotionReadyAt==110,"HP cooldown wrong")
	f:Use("MP");check(f.Attrs.Mana==60 and f.Data.MPPotionCount==2,"MP recovery/stock wrong")
	check(f.Attrs.MPPotionReadyAt==110,"independent MP cooldown wrong")
	-- feedback_audit #4 (최종 검수 10/15): a real drink sends Fx Drink { Kind, From, To, Max } (the bar lights what came back)
	local dr={}
	for _,e in f.FxLog do if e.Kind=="Drink" then table.insert(dr,e) end end
	check(#dr==2 and dr[1].P==f.Player and dr[1].Data.Kind=="HP" and dr[1].Data.From==50 and dr[1].Data.To==80 and dr[1].Data.Max==100
		and dr[2].Data.Kind=="MP" and dr[2].Data.From==20 and dr[2].Data.To==60,"Fx Drink HP 50->80 / MP 20->60 wrong")
	local nfx=#f.FxLog
	local before=f:Snapshot();f:Use("HP");f:Use("MP");f:Unchanged(before)
	check(#f.FxLog==nfx,"a refused drink sent an Fx")
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
-- A23-110 (the King's Hop quest): a bought and a drunk potion report to StoryQuestService.Event (a refused one never does), and
-- the 'Drink a potion from your quick slot' step never dead-ends at full HP / MP: a practice sip counts for the step, keeps the
-- potion and the cooldown (only while a quest step waits for it)
do
	local function watch(f, wants)
		local rec = { Events = {}, Wants = wants }
		f.Registry.StoryQuestService = {
			Event = function(p, name, info) table.insert(rec.Events, { P = p, Name = name, Info = info }) return true end,
			Wants = function(_, name) return rec.Wants == name end }
		return rec
	end
	local function last(f) return f.Notices[#f.Notices] and f.Notices[#f.Notices][1] end
	local f = fixture(); local rec = watch(f); f:Gold(300, 0)
	check(f:Buy("HP", 5) == true and #rec.Events == 1 and rec.Events[1].Name == "PotionBought" and rec.Events[1].P == f.Player
		and rec.Events[1].Info.Kind == "HP" and rec.Events[1].Info.N == 5, "A23-110 a purchase did not report PotionBought once")
	check(f:Buy("MP", 1) == true and #rec.Events == 2 and rec.Events[2].Info.Kind == "MP" and rec.Events[2].Info.N == 1,
		"A23-110 the MP purchase did not report")
	for label, mutate in {
		Poor = function(g) g:Gold(4, 5) end,
		Far = function(g) g.Root.Position = vector(12.01, 0, 0) end,
		Full = function(g) g:Stock(99, 0) end,
		BadAmount = function() end,
		Dead = function(g) g.Humanoid.Health = 0 end,
		Cooldown = function(g) g.Blocks.BuyPotion = true end,
	} do
		local g = fixture(); local r = watch(g); g:Gold(100, 0); mutate(g)
		check(g:Buy("HP", label == "BadAmount" and 2 or 1) == false and #r.Events == 0, "A23-110 a refused purchase (" .. label .. ") reported PotionBought")
	end
	-- a real drink reports PotionUsed once (HP hurt, MP low)
	local u = fixture(); local ur = watch(u); u:Stock(3, 3); u.Vitals.DebugSetMana(u.Player, 20)
	u:Use("HP")
	check(u.Data.HPPotionCount == 2 and #ur.Events == 1 and ur.Events[1].Name == "PotionUsed" and ur.Events[1].Info.Kind == "HP"
		and ur.Events[1].Info.Practice == nil, "A23-110 a real HP drink did not report PotionUsed")
	u.Now += 100; u:Use("MP")
	check(u.Data.MPPotionCount == 2 and #ur.Events == 2 and ur.Events[2].Info.Kind == "MP", "A23-110 a real MP drink did not report")
	-- full HP / MP and no step waiting: refused as before, no event, the potion stays
	local n = fixture(); local nr = watch(n); n:Stock(3, 3); n.Humanoid.Health = n.Humanoid.MaxHealth
	n:Use("HP")
	check(n.Data.HPPotionCount == 3 and #nr.Events == 0 and last(n) == "HP is full.", "A23-110 full HP with nothing waiting reported or changed",
		tostring(last(n)))
	n.Vitals.DebugSetMana(n.Player, n.Config.Vitals.MaxMana); n:Use("MP")
	check(n.Data.MPPotionCount == 3 and #nr.Events == 0 and last(n) == "MP is full.", "A23-110 full MP with nothing waiting reported or changed")
	-- a step waiting for another happening does not take a sip either
	local o = fixture(); local orr = watch(o, "PotionBought"); o:Stock(3, 3); o.Humanoid.Health = o.Humanoid.MaxHealth
	o:Use("HP")
	check(#orr.Events == 0 and last(o) == "HP is full.", "A23-110 a step waiting for another happening took a sip")
	-- the step waits for the drink: a sip at full HP counts, keeps the potion, the HP and the cooldown
	local s = fixture(); local sr = watch(s, "PotionUsed"); s:Stock(3, 3); s.Humanoid.Health = s.Humanoid.MaxHealth
	local ready0, said0 = s.Attrs.HPPotionReadyAt, #s.Notices
	s:Use("HP")
	check(s.Data.HPPotionCount == 3 and s.Humanoid.Health == s.Humanoid.MaxHealth and #sr.Events == 1 and sr.Events[1].Name == "PotionUsed"
		and sr.Events[1].Info.Practice == true and sr.Events[1].Info.Kind == "HP" and #s.Notices == said0
		and s.Attrs.HPPotionReadyAt == ready0, "A23-110 a practice sip at full HP: counted, potion kept, no cooldown (A23-130: no line)",
		tostring(last(s)))
	s.Vitals.DebugSetMana(s.Player, s.Config.Vitals.MaxMana); s:Use("MP")
	check(s.Data.MPPotionCount == 3 and #sr.Events == 2 and sr.Events[2].Info.Practice == true and sr.Events[2].Info.Kind == "MP"
		and last(s) ~= s.Config.Text.PotionPractice, "A23-110 a practice sip at full MP: counted, potion kept (no line)")
	-- no potion in the bag: nothing to sip (the refusal comes first)
	local e = fixture(); local er = watch(e, "PotionUsed"); e.Humanoid.Health = e.Humanoid.MaxHealth
	e:Use("HP")
	check(#er.Events == 0 and e.Data.HPPotionCount == 0, "A23-110 a sip without a potion counted")
	-- while a step waits, a real drink (hurt) still works as usual and reports as a real use
	local h = fixture(); local hr = watch(h, "PotionUsed"); h:Stock(3, 3)
	h:Use("HP")
	check(h.Data.HPPotionCount == 2 and #hr.Events == 1 and hr.Events[1].Info.Practice == nil, "A23-110 a hurt drink while the step waits is a real use")
end
print("POTION_OFFLINE_OK checks="..checks.." Studio/API calls=0")
