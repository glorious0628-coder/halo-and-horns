"""Run the chosen-weapon shop, Config, Util and gold code in an offline Luau fixture.

No Studio, network, upload or datastore calls. Engine UI/physics/persistence need live checks.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCES = {
    "CONFIG": "src/ReplicatedStorage/Shared/Config.luau",
    "UTIL": "src/ReplicatedStorage/Shared/Util.luau",
    "SHOP": "src/ServerScriptService/ShopService.luau",
    "GOLD": "src/ServerScriptService/ProgressionService.luau",
    "NET": "src/ReplicatedStorage/Shared/Net.luau",
}

FIXTURE = r'''
local passed = 0
local function check(ok, name)
    assert(ok, name)
    passed += 1
end
local function execute(source, env)
    local fn, err = loadstring(source)
    assert(fn, err)
    setfenv(fn, setmetatable(env, {__index=getfenv()}))
    return fn()
end
do
    local network=execute(NET_SOURCE,{game={GetService=function() return {} end}})
    local names={};for _,name in network.Names do names[name]=(names[name] or 0)+1 end
    check(names.UpgradeWeapon==1 and names.SellWeapon==1,"actual trade remote registry is missing or duplicated")
end
local function signal()
    local handlers={}
    return {Connect=function(_,fn) table.insert(handlers,fn);return {Disconnect=function() end} end,
        Fire=function(_,...) for _,fn in handlers do fn(...) end end}
end
local vectorMeta={}
local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z,Kind="Vector3"},vectorMeta) end
vectorMeta.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vectorMeta.__index=function(v,k) if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end end
local function kind(v) return type(v)=="table" and v.Kind or type(v) end
local function object(class,name,parent)
    local state={ClassName=class,Name=name,Parent=parent,Children={},Kind="Instance"}
    local value={}
    setmetatable(value,{
        __index=state,
        __newindex=function(_,key,v)
            if key=="Parent" then
                if state.Parent then state.Parent.Children[state.Name]=nil end
                state.Parent=v
                if v then v.Children[state.Name]=value end
            elseif key=="Name" then
                if state.Parent then state.Parent.Children[state.Name]=nil end
                state.Name=v
                if state.Parent then state.Parent.Children[v]=value end
            else state[key]=v end
        end,
    })
    function value:IsA(c) return class==c or (c=="BasePart" and class=="Part") end
    function value:FindFirstChild(n) return self.Children[n] end
    function value:FindFirstChildOfClass(c)
        for _,child in self.Children do if child:IsA(c) then return child end end
    end
    function value:IsDescendantOf(p)
        local current=self.Parent
        while current do if current==p then return true end;current=current.Parent end
        return false
    end
    if parent then parent.Children[name]=value end
    return value
end
local function fixture()
    local f={Now=100,Ready=true,Warnings={},Notices={},Opened={},Fx={},GoldEvents={},Active=false}
    local players=object("Players","Players")
    local world=object("Workspace","Workspace")
    local map=object("Folder","Map",world)
    local landmarks=object("Folder","Landmarks",map)
    local guild=object("Model","ArtisanGuild",landmarks)
    local anvil=object("Part","Anvil",guild);anvil.Anchored=true;anvil.Position=vec(39,1.5,45)
    local p=object("Player","Tester",players)
    local character=object("Model","TesterCharacter",world);p.Character=character
    local root=object("Part","HumanoidRootPart",character);root.Position=vec(40,1.5,45)
    local humanoid=object("Humanoid","Humanoid",character);humanoid.Health=120
    local events={PromptTriggered=signal()}
    local remotes={}
    local net={Get=function(name)
        if not remotes[name] then remotes[name]={OnServerEvent=signal(),FireClient=function(_,who,id)
            table.insert(f.Opened,{Player=who,Id=id}) end} end
        return remotes[name]
    end,Notify=function(_,message) table.insert(f.Notices,message) end,
    Fx=function(_,event) table.insert(f.Fx,event) end}
    local constants=setmetatable({}, {__index=function(t,k)
        local enum=setmetatable({}, {__index=function(_,v) return k.."."..v end});rawset(t,k,enum);return enum end})
    local function tuple(...) return {...} end
    local env={Enum=constants,Color3={fromRGB=tuple,new=tuple},Vector3={new=vec},Vector2={new=tuple},
        BrickColor={new=tuple},Rect={new=tuple},UDim2={fromScale=tuple},Random={new=function() return {} end},
        Instance={new=function(c) return object(c,c) end},typeof=kind,
        print=function() end,warn=function(message) table.insert(f.Warnings,message) end,
        workspace=world,os=setmetatable({clock=function() return f.Now end},{__index=os}),
        task={wait=function() error("unexpected yield") end,spawn=function() error("unexpected task") end}}
    local config=execute(CONFIG_SOURCE,env)
    check(type(config.WeaponShop)=="table" and config.WeaponShop.MaxSoldTier==3,"production shop ceiling is not 3")
    check(config.Weapons[2].Price==150 and config.Tutorial.QuestRewardGold>=config.Weapons[2].Price,
        "A23-3 first mission reward (150) no longer covers the wood weapon")
    check(config.Data.Defaults.WeaponOwnedMask==1 and config.Data.Defaults.BlacksmithVisited==false,"production trade defaults differ")
    check(table.find(config.Data.Mirrored,"WeaponOwnedMask")~=nil and table.find(config.Data.Mirrored,"BlacksmithVisited")~=nil,"trade attributes are not mirrored")
    local services={Players=players,ReplicatedStorage={Shared={Config="Config",Util="Util",Net="Net"}},
        ProximityPromptService=events}
    env.game={GetService=function(_,name) return assert(services[name],name) end}
    local util=execute(UTIL_SOURCE,env)
    env.require=function(name)
        if name=="Config" then return config elseif name=="Util" then return util elseif name=="Net" then return net end
        error("unexpected require: "..tostring(name))
    end
    local data={WeaponTier=1,WeaponOwnedMask=1,Level=5,BankGold=1000,CarriedGold=200,ClassChosen=true,Class="Archer",Faction="Halo",
        HPPotionCount=10,MPPotionCount=10,BlacksmithVisited=false}
    local registry={PlayerService={IsReady=function(who) return who==p and f.Ready end,
        GetData=function() return data end,SetStat=function(_,key,value) data[key]=value end,
        AddStat=function(_,key,value) data[key]=(data[key] or 0)+value;return data[key] end,
        MarkActive=function() f.Active=true end},ClassService={GetClass=function() return data.Class end},
        FactionService={GetFaction=function() return data.Faction end},
        -- review B6: blacksmith buy/re-equip is refused while PvP-tagged (same rule as the item-list equip)
        CombatService={IsInCombat=function(who) return who==p and f.InCombat==true end}}
    local gold=execute(GOLD_SOURCE,env);gold.Init(registry);registry.ProgressionService=gold
    gold.GoldEarned:Connect(function(_,amount,source) table.insert(f.GoldEvents,{Amount=amount,Source=source}) end)
    local shop=execute(SHOP_SOURCE,env);shop.Init(registry);shop.Start()
    f.Shop,f.Config,f.Data,f.Player,f.Root,f.Humanoid,f.Gold=shop,config,data,p,root,humanoid,gold
    f.Anvil,f.World,f.Guild,f.Map,f.Landmarks,f.Players,f.Events=anvil,world,guild,map,landmarks,players,events
    f.Prompt=anvil:FindFirstChild("HHC_BlacksmithPrompt")
    function f:Buy(...) remotes.UpgradeWeapon.OnServerEvent:Fire(p,...) end
    function f:Sell(...) remotes.SellWeapon.OnServerEvent:Fire(p,...) end
    function f:Open(prompt,who) events.PromptTriggered:Fire(prompt or self.Prompt,who or p) end
    function f:Snapshot() return {data.WeaponTier,data.CarriedGold,data.BankGold,data.HPPotionCount,data.MPPotionCount,data.WeaponOwnedMask} end
    function f:Unchanged(before,label)
        for i,v in before do check(self:Snapshot()[i]==v,label.." mutated field "..i) end
    end
    return f
end

do
    local f=fixture()
    check(f.Prompt~=nil and f.Prompt.Parent==f.Anvil,"prompt not attached to existing anvil")
    -- 2026-10-06: shop/anvil interaction is the standard E key and opens on a tap; the skill key is Q only
    check(f.Prompt.KeyboardKeyCode=="KeyCode.E" and f.Prompt.HoldDuration==0,"blacksmith prompt is not E key / HoldDuration 0")
    check(f.Prompt.KeyboardKeyCode~="KeyCode.Q","blacksmith prompt collides with the Q skill key")
    check(f.Prompt.MaxActivationDistance==12,"prompt range not 12")
    local first=f.Prompt;check(f.Shop.EnsureBlacksmithPrompt(),"idempotent ensure failed")
    check(f.Anvil:FindFirstChild(first.Name)==first,"second ensure replaced prompt")
    local count=0;for _,child in f.Anvil.Children do if child:IsA("ProximityPrompt") then count+=1 end end
    check(count==1,"second ensure duplicated prompt")
    local before=f:Snapshot();f:Open()
    check(#f.Opened==1 and f.Opened[1].Player==f.Player and f.Opened[1].Id=="WeaponShop","prompt failed to open owner shop")
    check(f.Data.BlacksmithVisited==true,"valid prompt did not record blacksmith visit")
    f:Unchanged(before,"opening")
    f:Open();check(#f.Opened==1,"immediate prompt replay bypassed rate limit")
    f:Buy(7,0,-1000,"forged payload");f:Unchanged(before,"forged purchase payload")
    f:Buy(nil);f:Unchanged(before,"unexpected nil payload")
    f:Buy();f:Unchanged(before,"missing tier payload")
    f:Buy(2)
    check(f.Data.WeaponTier==2 and f.Data.WeaponOwnedMask==3,"chosen tier 2 not bought/equipped")
    check(f.Data.CarriedGold==50 and f.Data.BankGold==1000,"tier 2 did not debit exact 150 carried-first")
    check(f.Active,"purchase did not mark activity")
    before=f:Snapshot();f:Buy(2);f:Unchanged(before,"immediate purchase replay")
    f.Now+=0.31;f:Buy(2);f:Unchanged(before,"delayed duplicate purchase charged twice")
    check(f.Notices[#f.Notices]==string.format(f.Config.Loot.Text.Equip,f.Config.WeaponName(2,"Archer","Halo")),"owned re-equip was described as a new purchase")
    f.Now+=0.31;f:Buy(3)
    check(f.Data.WeaponTier==3 and f.Data.WeaponOwnedMask==7 and f.Data.CarriedGold==0 and f.Data.BankGold==250,"tier 3 exact 800 purchase")
    f.Now+=0.31;before=f:Snapshot();f:Buy(4);f:Unchanged(before,"rare tier above ceiling")
    f.Now+=0.31;f:Buy(2)
    check(f.Data.WeaponTier==2 and f.Data.WeaponOwnedMask==7 and f.Data.BankGold==250,"owned downgrade lost item or charged gold")
    f.Now+=0.31;f:Buy(3)
    check(f.Data.WeaponTier==3 and f.Data.WeaponOwnedMask==7 and f.Data.BankGold==250,"owned higher tier was lost after downgrade")
    f.Now+=0.31;f:Buy(1)
    check(f.Data.WeaponTier==1 and f.Data.WeaponOwnedMask==7 and f.Data.BankGold==250,"starting gear was not free to re-equip")
    check(f.Data.HPPotionCount==10 and f.Data.MPPotionCount==10,"weapon purchase changed potion inventory")
    for _,message in f.Warnings do check(not string.find(message,"weapon purchase:"),"valid purchase path threw: "..message) end
end
-- review B6: PvP combat refuses both a purchase (before any gold is spent) and an owned re-equip; selling is not gated
do
    local f=fixture();f.InCombat=true
    local before=f:Snapshot();f:Buy(2);f:Unchanged(before,"purchase while in PvP combat")
    check(f.Notices[#f.Notices]==f.Config.Loot.Text.EquipCombat,"combat purchase refusal did not use Config.Loot.Text.EquipCombat")
    check(#f.GoldEvents==0 and f.Data.BlacksmithVisited==false,"combat-refused purchase recorded a trade")
    f.Data.WeaponOwnedMask=3;f.Now+=0.31;before=f:Snapshot();f:Buy(2);f:Unchanged(before,"owned re-equip while in PvP combat")
    f.InCombat=false;f.Now+=0.31;f:Buy(2)
    check(f.Data.WeaponTier==2 and f.Data.CarriedGold==200 and f.Data.BankGold==1000,"owned re-equip after combat failed or charged")
    f.Data.WeaponOwnedMask=7;f.Data.WeaponTier=3;f.InCombat=true;f.Now+=0.31;local carried=f.Data.CarriedGold;f:Sell(2)
    check(f.Data.WeaponOwnedMask==5 and f.Data.CarriedGold==carried+15,"weapon sale was gated by PvP combat")
    for _,message in f.Warnings do check(not string.find(message,"weapon "),"combat gate threw: "..message) end
end
-- A23-4 / A23-14 review: MinLevel gates the PURCHASE only. An owned weapon re-equips for free at any level (Lv1 after a
-- rebirth or a free class change keeps every weapon), an unowned one above the level is still refused with a notice.
do
    local f=fixture();f.Data.Level=1;f.Data.WeaponOwnedMask=5;f.Data.WeaponTier=1
    f:Buy(3)
    check(f.Data.WeaponTier==3 and f.Data.WeaponOwnedMask==5 and f.Data.CarriedGold==200 and f.Data.BankGold==1000,
        "owned tier 3 could not be re-equipped for free at Lv1")
    check(f.Notices[#f.Notices]==string.format(f.Config.Loot.Text.Equip,f.Config.WeaponName(3,"Archer","Halo")),
        "Lv1 owned re-equip notice is not Config.Loot.Text.Equip")
    local g=fixture();g.Data.Level=4;local before=g:Snapshot();g:Buy(3);g:Unchanged(before,"unowned tier 3 bought below MinLevel 5")
    check(g.Notices[#g.Notices]==string.format(g.Config.Text.WeaponNeedLevel,5),"purchase level refusal notice missing")
    check(string.find(g.Config.Text.WeaponNeedLevel,"살 수",1,true)~=nil,"WeaponNeedLevel no longer says the level gates buying")
    g.Data.Level=5;g.Now+=0.31;g:Buy(3)
    check(g.Data.WeaponTier==3 and g.Data.WeaponOwnedMask==5,"tier 3 purchase at exactly MinLevel 5 failed")
end
do
    local f=fixture();f:Buy(3)
    check(f.Data.WeaponTier==3 and f.Data.WeaponOwnedMask==5,"direct tier 3 purchase required tier 2")
    check(f.Data.CarriedGold==0 and f.Data.BankGold==400,"direct tier 3 purchase did not cost exactly 800")
    check(bit32.band(f.Data.WeaponOwnedMask,2)==0,"skipping tier 2 granted it for free")
    f.Now+=0.31;f:Buy(2)
    check(f.Data.WeaponTier==2 and f.Data.WeaponOwnedMask==7 and f.Data.BankGold==250,"buying lower unowned tier failed")
    f.Data.CarriedGold=0;f.Data.BankGold=0;f.Now+=0.31;f:Buy(3)
    check(f.Data.WeaponTier==3 and f.Data.WeaponOwnedMask==7 and f.Data.BankGold==0,"owned gear needed more gold to equip")
    f.Now+=0.31;f.Config.Weapons[2].Price=nil;f:Buy(2)
    check(f.Data.WeaponTier==2 and f.Data.WeaponOwnedMask==7 and f.Data.BankGold==0,"owned item unexpectedly used purchase price")
end
for _,payload in {
    {false},{"2"},{-1},{0},{2.5},{4},{7},{8},{math.huge},{0/0},{{Tier=2}},{2,150},{2,0},
} do
    local f=fixture();local before=f:Snapshot();f:Buy(table.unpack(payload));f:Unchanged(before,"invalid catalog request")
end

local rejects={
    {"distance12.01",function(f) f.Root.Position=vec(51.01,1.5,45) end},
    {"verticalDistance",function(f) f.Root.Position=vec(39,13.51,45) end},
    {"nanPosition",function(f) f.Root.Position=vec(0/0,0,0) end},
    {"infinitePosition",function(f) f.Root.Position=vec(math.huge,0,0) end},
    {"inflatedPromptRadius",function(f) f.Prompt.MaxActivationDistance=100;f.Root.Position=vec(59,1.5,45) end},
    {"zeroPromptRadius",function(f) f.Prompt.MaxActivationDistance=0 end},
    {"nanPromptRadius",function(f) f.Prompt.MaxActivationDistance=0/0 end},
    {"disabledPrompt",function(f) f.Prompt.Enabled=false end},
    {"renamedPrompt",function(f) f.Prompt.Name="Other" end},
    {"wrongPromptParent",function(f) f.Prompt.Parent=f.World end},
    {"missingMap",function(f) f.Map.Parent=nil end},
    {"wrongGuildParent",function(f) f.Guild.Parent=f.World end},
    {"unanchoredAnvil",function(f) f.Anvil.Anchored=false end},
    {"notReady",function(f) f.Ready=false end},
    {"dead",function(f) f.Humanoid.Health=0 end},
    {"noCharacter",function(f) f.Player.Character=nil end},
    {"playerLeft",function(f) f.Player.Parent=nil end},
    {"classNotChosen",function(f) f.Data.ClassChosen=false end},
    {"tierNan",function(f) f.Data.WeaponTier=0/0 end},
    {"tierFraction",function(f) f.Data.WeaponTier=1.5 end},
    {"tierZero",function(f) f.Data.WeaponTier=0 end},
    {"notEnoughGold",function(f) f.Data.CarriedGold=149;f.Data.BankGold=0 end},
    {"levelGate",function(f) f.Data.Level=1 end,3},
    {"pvpCombat",function(f) f.InCombat=true end},
    {"missingOwnership",function(f) f.Data.WeaponOwnedMask=nil end},
    {"nanOwnership",function(f) f.Data.WeaponOwnedMask=0/0 end},
    {"negativeOwnership",function(f) f.Data.WeaponOwnedMask=-1 end},
    {"fractionOwnership",function(f) f.Data.WeaponOwnedMask=1.5 end},
    {"overflowOwnership",function(f) f.Data.WeaponOwnedMask=128 end},
    {"missingStarterOwnership",function(f) f.Data.WeaponOwnedMask=2 end},
    {"zeroPrice",function(f) f.Config.Weapons[2].Price=0 end},
    {"negativePrice",function(f) f.Config.Weapons[2].Price=-100 end},
    {"nanPrice",function(f) f.Config.Weapons[2].Price=0/0 end},
    {"infinitePrice",function(f) f.Config.Weapons[2].Price=math.huge end},
    {"fractionPrice",function(f) f.Config.Weapons[2].Price=1.5 end},
    {"missingPrice",function(f) f.Config.Weapons[2].Price=nil end},
    {"invalidCeiling",function(f) f.Config.WeaponShop.MaxSoldTier=0/0 end},
    {"missingCeiling",function(f) f.Config.WeaponShop.MaxSoldTier=nil end},
    {"missingShopContract",function(f) f.Config.WeaponShop=nil end},
}
for _,case in rejects do
    local f=fixture();case[2](f);local before=f:Snapshot();f:Buy(case[3] or 2)
    -- NaN is intentionally unchanged but never compares equal to itself.
    if case[1]=="tierNan" then check(f.Data.WeaponTier~=f.Data.WeaponTier,"invalid tier was rewritten");before[1]=nil end
    if case[1]=="nanOwnership" then check(f.Data.WeaponOwnedMask~=f.Data.WeaponOwnedMask,"invalid ownership was rewritten");before[6]=nil end
    f:Unchanged(before,case[1])
    for _,message in f.Warnings do check(not string.find(message,"weapon purchase:"),case[1].." threw inside callback") end
end
do
    local f=fixture();f.Root.Position=vec(51,1.5,45)
    check(f.Shop.CanBuyWeapon(f.Player),"exact 12-stud boundary rejected")
    local before=f:Snapshot();f:Open();f.Root.Position=vec(52,1.5,45);f:Buy(2)
    f:Unchanged(before,"leave shop after panel opened")
end
do
    local f=fixture();local clone=object("ProximityPrompt",f.Prompt.Name)
    clone.Enabled=true;clone.Parent=f.Anvil
    -- Restore the canonical child index; triggering an unregistered same-name object is invalid.
    f.Anvil.Children[f.Prompt.Name]=f.Prompt;local before=f:Snapshot();f:Open(clone)
    check(#f.Opened==0,"cloned prompt opened shop");f:Unchanged(before,"clone prompt")
    f:Open(f.Prompt,object("Player","Forged",f.Players))
    check(#f.Opened==0,"forged player opened shop")
    check(f.Data.BlacksmithVisited==false,"forged prompt recorded a visit")
end
do
    local f=fixture();f.Data.WeaponOwnedMask=7;f.Data.WeaponTier=3
    local initial=f.Data.CarriedGold;f:Sell(2)
    check(f.Data.CarriedGold==initial+15 and f.Data.BankGold==1000,"wood sale must give exactly 15 carried gold")
    check(f.Data.WeaponOwnedMask==5 and f.Data.WeaponTier==3,"selling unused weapon affected equipped iron or retained sold bit")
    check(#f.GoldEvents==1 and f.GoldEvents[1].Source=="Sale" and f.GoldEvents[1].Amount==15,"sale gold was incorrectly marked as monster loot")
    local before=f:Snapshot();f:Sell(2);f:Unchanged(before,"immediate duplicate sale")
    f.Now+=0.31;f:Sell(2);f:Unchanged(before,"delayed duplicate sale")
    check(#f.GoldEvents==1,"duplicate sale emitted reward signal")
    f.Now+=0.31;f:Sell(3)
    check(f.Data.CarriedGold==initial+95 and f.Data.BankGold==1000,"iron sale must give exactly 80 carried gold")
    check(f.Data.WeaponOwnedMask==1 and f.Data.WeaponTier==1,"selling equipped gear did not fall back to owned starter")
    check(#f.GoldEvents==2 and f.GoldEvents[2].Amount==80,"second legitimate sale reward incorrect")
    check(f.Active,"sale did not mark activity")
    f.Now+=0.31;before=f:Snapshot();f:Sell(1);f:Unchanged(before,"starting item sale")
    f:Buy(2)
    check(f.Data.WeaponOwnedMask==3 and f.Data.WeaponTier==2 and f.Data.CarriedGold==initial+95-150,"buying back sold gear must pay full price")
end
do
    local f=fixture();f.Data.WeaponOwnedMask=3;f.Config.Weapons[2].Price=159
    local before=f.Data.CarriedGold;f:Sell(2)
    check(f.Data.CarriedGold==before+15,"resale rounding was not floor(price * 0.1)")
end
do
    local f=fixture();f.Data.WeaponOwnedMask=3;f.Data.WeaponTier=2
    f.Gold.GoldEarned:Connect(function() f.Now+=0.31;f:Sell(2) end)
    local before=f.Data.CarriedGold;f:Sell(2)
    check(f.Data.CarriedGold==before+15 and #f.GoldEvents==1,"reentrant sale from reward callback paid twice")
    check(f.Data.WeaponOwnedMask==1 and f.Data.WeaponTier==1,"reentrant sale corrupted ownership/equipment")
end
for _,payload in {
    {},{false},{"2"},{-1},{0},{1},{2.5},{4},{7},{8},{math.huge},{0/0},{{Tier=2}},{2,150},{2,0},
} do
    local f=fixture();f.Data.WeaponOwnedMask=7;f.Data.WeaponTier=3
    local before=f:Snapshot();f:Sell(table.unpack(payload));f:Unchanged(before,"invalid sale request")
    check(#f.GoldEvents==0,"invalid sale emitted money")
end
for _,case in rejects do
    -- Resale does not require the purchase level or any current gold balance.
    -- PvP combat does not gate selling (it only ever drops the player to the starter).
    if case[1]=="notEnoughGold" or case[1]=="levelGate" or case[1]=="pvpCombat" then continue end
    local f=fixture();f.Data.WeaponOwnedMask=7;f.Data.WeaponTier=3
    case[2](f);local before=f:Snapshot();f:Sell(2)
    if case[1]=="tierNan" then check(f.Data.WeaponTier~=f.Data.WeaponTier,"invalid sale tier was rewritten");before[1]=nil end
    if case[1]=="nanOwnership" then check(f.Data.WeaponOwnedMask~=f.Data.WeaponOwnedMask,"invalid sale mask was rewritten");before[6]=nil end
    f:Unchanged(before,"sale "..case[1]);check(#f.GoldEvents==0,"blocked sale emitted money")
    for _,message in f.Warnings do check(not string.find(message,"weapon sale:"),case[1].." threw inside sale callback") end
end
do
    local f=fixture();f.Data.WeaponOwnedMask=5;f.Data.WeaponTier=3;f.Data.Level=1
    f.Data.CarriedGold=0;f.Data.BankGold=0;f:Sell(3)
    check(f.Data.WeaponOwnedMask==1 and f.Data.WeaponTier==1 and f.Data.CarriedGold==80,"owned item could not be sold after level reset")
end
print("BLACKSMITH_OFFLINE_OK checks="..passed.." Studio/API calls=0")
'''


def quote(source: str) -> str:
    eq = "===="
    while f"]{eq}]" in source:
        eq += "="
    return f"[{eq}[{source}]{eq}]"


def main() -> int:
    cli = ROOT / "build/luau_cli_0_741"
    for executable in ("luau.exe", "luau-compile.exe"):
        if not (cli / executable).is_file():
            raise SystemExit(f"Installed Luau CLI required: {cli / executable}")
    paths = [ROOT / rel for rel in SOURCES.values()]
    source = "\n".join(f"local {key}_SOURCE = {quote((ROOT / rel).read_text(encoding='utf-8-sig'))}"
                       for key, rel in SOURCES.items()) + "\n" + FIXTURE
    generated = ROOT / "build/gameplay_blacksmith_offline.luau"
    generated.write_text(source, encoding="utf-8")
    compiled = subprocess.run([str(cli / "luau-compile.exe"), *(str(path) for path in paths)],
                              capture_output=True, timeout=60)
    if compiled.returncode:
        print(compiled.stderr.decode("utf-8", "replace"))
        return compiled.returncode
    tested = subprocess.run([str(cli / "luau.exe"), str(generated)], capture_output=True,
                            text=True, encoding="utf-8", errors="replace", timeout=60)
    marker = re.search(r"BLACKSMITH_OFFLINE_OK checks=(\d+) Studio/API calls=0", tested.stdout)
    ok = tested.returncode == 0 and marker is not None
    report = {"status": "passed" if ok else "failed", "checks": int(marker.group(1)) if marker else 0,
              "contract": "UpgradeWeapon(tier 1..3): buy/re-equip; SellWeapon(tier 2..3): remove owned bit and pay floor(price * 0.1); "
                          "anvil prompt KeyCode E, HoldDuration 0 (2026-10-06); first mission 150 gold covers the 150-gold wood weapon; "
                          "review B6: buy and owned re-equip refused in PvP combat before any gold is spent (sale not gated); "
                          "MinLevel gates the purchase only, an owned weapon re-equips free at any level (A23-14 rebirth / free class change)",
              "covered_catalog_cases": ["direct tier 3 purchase", "lower unowned tier purchase", "owned lower/higher re-equip",
                                        "immediate and delayed duplicate debit blocked", "invalid payload and rare tiers rejected",
                                        "finite ownership/price validation", "distance, alive, class and level gates",
                                        "starter free re-equip and no sale", "15/80 sale proceeds and no duplicate payout",
                                        "equipped-item sale falls back to starter", "sale source cannot count as monster gold",
                                        "valid prompt records BlacksmithVisited; forged prompt does not",
                                        "PvP combat refuses purchase and re-equip without debit; sale still allowed",
                                        "owned tier re-equips free at Lv1; unowned tier below MinLevel refused with WeaponNeedLevel"],
              "source_sha256": {str(p.relative_to(ROOT)).replace("\\", "/"): hashlib.sha256(p.read_bytes()).hexdigest()
                                for p in paths},
              "real_source_executed": list(SOURCES.values()), "studio_calls": 0, "api_calls": 0,
              "limitations": "Offline Roblox objects; live UI, physics and persistence not verified here.",
              "stdout": tested.stdout, "stderr": tested.stderr}
    output = ROOT / "docs/art/verification_2026-10-06/offline_blacksmith_2026-10-06.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(tested.stdout, end="")
    if tested.stderr:
        print(tested.stderr, end="")
    print(output)
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
