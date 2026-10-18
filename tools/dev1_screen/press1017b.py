"""Screen burst 2 (10/17): values + photos for dev1-feel2 in MY test Studio (STUDIO_ID = PhoneTest_1015, ../Game-dev1grip synced).
1. XP x2: a fresh Horns Archer Lv1 in the meadow, F at slimes - every Fx Reward's XP / XPMult + the drawn '+N XP x2' texts
2. an empty quick slot press (the HUD button, Studio MCP mouse in my Play) -> the bag on Use with the HP potion picked
3. EdgeHint: 6 studs from the map's MinX edge -> the curtain's transparency + a photo
4. G1: one press -> the sounds that started (SoundService / camera Sound names) within 0.6 s
Usage: STUDIO_ID=... py press1017b.py"""
import json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from h1016 import Client, log, save_log, lua, key, shot, scene, start_play, pick, stop_play, close, GAME, WORDS, click  # noqa: E402
import photo1017b as B  # noqa: E402

OUT = os.path.join(GAME, "docs", "art", "verification_2026-10-17", "press_feel2")
os.makedirs(OUT, exist_ok=True)
HOOK = r'''
local Net = require(game.ReplicatedStorage.Shared.Net)
_G.DEV1_REWARDS = {}
if _G.DEV1_HOOK then pcall(function() _G.DEV1_HOOK:Disconnect() end) end
_G.DEV1_HOOK = Net.Get("Fx").OnClientEvent:Connect(function(kind, data)
	if kind == "Reward" and type(data) == "table" then
		table.insert(_G.DEV1_REWARDS, string.format("XP=%s XPMult=%s", tostring(data.XP), tostring(data.XPMult)))
	end
end)
return "hooked"
'''
REWARDS = 'return table.concat(_G.DEV1_REWARDS or {}, " ; ")'
XPTEXT = r'''
local out = {}
for _, root in { game.Players.LocalPlayer.PlayerGui, workspace } do
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") and string.find(d.Text, "XP", 1, true) and string.find(d.Text, "+", 1, true) then
			table.insert(out, d.Text)
		end
	end
end
return #out > 0 and table.concat(out, " | ") or "no +XP text"
'''
FACE_SLIME = r'''
local r = game.Players:GetPlayers()[1].Character.HumanoidRootPart
local f = workspace:FindFirstChild("Monsters")
local best, bd
for _, m in f and f:GetChildren() or {} do
	local p = m:IsA("Model") and (m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart"))
	if p and m:GetAttribute("MonsterKind") == "Slime" then local d = (p.Position - r.Position).Magnitude if not bd or d < bd then best, bd = p, d end end
end
if not best then return "no slime" end
local dir = ((r.Position - best.Position) * Vector3.new(1, 0, 1)).Unit
local at = best.Position + dir * 18
r.CFrame = CFrame.lookAt(Vector3.new(at.X, best.Position.Y + 3, at.Z), Vector3.new(best.Position.X, best.Position.Y + 3, best.Position.Z))
return string.format("facing a slime at 18 (%.0f)", bd)
'''
SLOT = r'''
local pg = game.Players.LocalPlayer.PlayerGui
for _, d in pg:GetDescendants() do
	if d:IsA("GuiButton") and d.Visible and d:GetAttribute("QuickSlot") == 3 then return d:GetFullName() end
end
return "none"
'''
EDGE = r'''
local c = workspace.CurrentCamera:FindFirstChild("HH_EdgeHint")
return c and string.format("edge curtain t=%.2f at=(%.0f,%.0f,%.0f)", c.Transparency, c.Position.X, c.Position.Y, c.Position.Z) or "no curtain"
'''
PROMPT_HOOK = r'''
local PPS = game:GetService("ProximityPromptService")
_G.DEV1_SHOWN, _G.DEV1_TRIG = {}, {}
for _, c in _G.DEV1_PCONN or {} do pcall(function() c:Disconnect() end) end
_G.DEV1_PCONN = {
	PPS.PromptShown:Connect(function(p) table.insert(_G.DEV1_SHOWN, string.format("%.2f %s", os.clock(), p.Parent and p.Parent.Parent and p.Parent.Parent.Name or p.Name)) end),
	PPS.PromptTriggered:Connect(function(p) table.insert(_G.DEV1_TRIG, string.format("%.2f %s", os.clock(), p.Parent and p.Parent.Parent and p.Parent.Parent.Name or p.Name)) end),
}
return "prompt hook " .. tostring(PPS.Enabled)
'''
SLOTN = r'''
for _, d in game.Players.LocalPlayer.PlayerGui:GetDescendants() do
	if d:IsA("GuiButton") and d.Visible and d:GetAttribute("QuickSlot") == %d then return d:GetFullName() end
end
return "none"
'''
QSTATE = r'''
local p = game.Players.LocalPlayer
local icon = nil
for _, d in p.PlayerGui:GetDescendants() do
	if d:IsA("GuiButton") and d:GetAttribute("QuickSlot") == 1 then local i = d:FindFirstChild("Icon") local n = d:FindFirstChild("Count") icon = tostring(i and i.Visible and i.Image) .. " n=" .. tostring(n and n.Text) end
end
local goal = {}
local qt = p.PlayerGui:FindFirstChild("QuestTracker", true)
for _, d in qt and qt:GetDescendants() or {} do
	if d:IsA("TextLabel") and d.Visible and d.Text ~= "" and #goal < 3 then table.insert(goal, d.Text) end
end
return string.format("attr=%s hp=%s icon=%s goal=%s", tostring(p:GetAttribute("QuickSlots")), tostring(p:GetAttribute("HPPotionCount")),
	tostring(icon), table.concat(goal, " / "))
'''
# r8 split (최종 검수): every SetQuickSlot the server gets (args + its data AFTER the service handled it: our listener
# connects later, so it runs after) -> the player's attribute DevQSLog. Accepted = data changed; refused = data the same
QS_HOOK = r'''
local p = game.Players:GetPlayers()[1]
local PS = require(game.ServerScriptService.PlayerService)
p:SetAttribute("DevQSLog", "")
game.ReplicatedStorage.Remotes.SetQuickSlot.OnServerEvent:Connect(function(pl, a, b)
	local d = PS.GetData(pl)
	pl:SetAttribute("DevQSLog", tostring(pl:GetAttribute("DevQSLog")) .. string.format("[%.2f slot=%s item=%s data=%s attr=%s] ",
		os.clock(), tostring(a), tostring(b), tostring(d and d.QuickSlots), tostring(pl:GetAttribute("QuickSlots"))))
end)
return "hooked"
'''
QS_SERVER = r'''
local p = game.Players:GetPlayers()[1]
local d = require(game.ServerScriptService.PlayerService).GetData(p)
return string.format("data=%s attr=%s log=%s", tostring(d and d.QuickSlots), tostring(p:GetAttribute("QuickSlots")), tostring(p:GetAttribute("DevQSLog")))
'''
# A23-219 Tool tab test helpers. TOOL_SETUP % (role, mats to grant {id = n}, total gold to set, craft = false |
# { Tool = +N, Lv = craft Lv, Bless = true (bless chance 100% on this server), Clear = { item ids to empty } }):
# the player stands at the role's bench afterwards
TOOL_SETUP = r'''
local p = game.Players:GetPlayers()[1]
local SSS = game.ServerScriptService
local Config = require(game.ReplicatedStorage.Shared.Config)
local PS, Loot, Prog = require(SSS.PlayerService), require(SSS.LootService), require(SSS.ProgressionService)
local role, mats, gold, craft = "%s", %s, %d, %s
local d = PS.GetData(p)
local out = {}
if type(craft) == "table" then
	for _, id in craft.Clear or {} do
		local n = d.Items and d.Items[id] or 0
		if n > 0 then Loot.TakeItem(p, id, n) end
	end
	d.Craft = type(d.Craft) == "table" and d.Craft or {}
	if craft.Lv then d.Craft[role] = { Lv = craft.Lv, XP = 0 } end
	if craft.Tool then d.Craft["Tool" .. role] = craft.Tool end
	if craft.Bless then
		local K = Config.Craft.Tools
		_G.DevBlessKeep = _G.DevBlessKeep or K.Bless
		local all = {}
		for i = 0, 10 do all[i] = 1 end
		K.Bless = all
	end
	table.insert(out, "craft set")
end
for id, n in mats do
	if n > 0 then Loot.GrantItem(p, id, n, "Debug") end
end
local have = Prog.GetTotalGold(p)
if have > 0 then Prog.SpendGold(p, have, "Debug") end
if gold > 0 then Prog.AddBankGold(p, gold, "Debug") end
local best = nil
for _, s in game:GetService("CollectionService"):GetTagged(Config.Craft.StationTag) do
	if s:IsA("BasePart") and s:GetAttribute("Role") == role then best = s break end
end
if not best and role == "Smith" then best = workspace.Map.Landmarks.ArtisanGuild:FindFirstChild("Anvil") end
if best and p.Character then p.Character:PivotTo(best.CFrame * CFrame.new(0, 3, 5)) end
table.insert(out, "gold=" .. tostring(Prog.GetTotalGold(p)))
table.insert(out, "at " .. tostring(best and best:GetFullName()))
return table.concat(out, ", ")
'''
CRAFT_ON = r'''
local C = require(game.ReplicatedStorage.Shared.Config)
C.Features.Crafting = true
return "Crafting on=" .. tostring(C.FeatureOn and C.FeatureOn("Crafting"))
'''
OPEN_TOOL = r'''
game.ReplicatedStorage.Remotes.OpenPanel:FireClient(game.Players:GetPlayers()[1], "Craft", { Tab = "Tool" })
return "sent"
'''
FIND_UPGRADE = r'''
for _, d in game.Players.LocalPlayer.PlayerGui:GetDescendants() do
	if d:IsA("GuiButton") and d.Name == "Upgrade" and d.Visible then return d:GetFullName() end
end
return "none"
'''
TOOL_SERVER = r'''
local p = game.Players:GetPlayers()[1]
local d = require(game.ServerScriptService.PlayerService).GetData(p)
local c = type(d.Craft) == "table" and d.Craft or {}
return string.format("ToolSmith=%s gold=%s", tostring(c.ToolSmith), tostring(require(game.ServerScriptService.ProgressionService).GetTotalGold(p)))
'''
TOOL_STATE = r'''
local out = {}
for _, d in game.Players.LocalPlayer.PlayerGui:GetDescendants() do
	if d:IsA("TextLabel") and d.Visible and d.Parent and (d.Parent.Name == "Tool" or d.Parent.Name == "Cost") then table.insert(out, d.Name .. "=" .. d.Text) end
	if d:IsA("GuiButton") and d.Name == "Upgrade" then table.insert(out, "Upgrade.Active=" .. tostring(d.Active)) end
end
return table.concat(out, " | ")
'''
FORGE = r'''
local pg = game.Players.LocalPlayer.PlayerGui
local out = {}
for _, d in pg:GetDescendants() do
	if d:IsA("GuiObject") and string.match(d.Name, "^WeaponTier%d+$") then
		local lock = d:FindFirstChild("ForgeLock", true)
		local sell = d:FindFirstChild("SellWeapon" .. string.sub(d.Name, 11), true)
		local name = d:FindFirstChildWhichIsA("TextLabel")
		table.insert(out, string.format("%s lock=%s sell=%s '%s'", d.Name, tostring(lock and lock.Visible), tostring(sell and sell.Visible),
			tostring(name and string.sub(name.Text, 1, 40))))
	end
end
return #out > 0 and table.concat(out, " | ") or "no forge rows"
'''
SOUNDS = r'''
local t0 = os.clock()
local seen = {}
local conns = {}
for _, root in { game:GetService("SoundService"), workspace.CurrentCamera, game.Players.LocalPlayer.PlayerGui } do
	table.insert(conns, root.DescendantAdded:Connect(function(d) if d:IsA("Sound") then table.insert(seen, string.format("%.2f %s", os.clock() - t0, d.Name)) end end))
end
local playing = {}
local function scan()
	for _, root in { game:GetService("SoundService"), workspace.CurrentCamera } do
		for _, d in root:GetDescendants() do
			if d:IsA("Sound") and d.IsPlaying and not playing[d] then playing[d] = true table.insert(seen, string.format("%.2f %s", os.clock() - t0, d.Name)) end
		end
	end
end
for _ = 1, 24 do scan() task.wait(0.025) end
for _, c in conns do c:Disconnect() end
return table.concat(seen, ", ")
'''


def main():
    c = Client()
    c.start()
    start_play(c)
    log("pick:", pick(c, "Horns", "Archer"))
    try:
        log(lua(c, B.FREE, "Client"))
        # 1 XP x2
        log("1", scene(c, {"Faction": "Horns", "Class": "Archer", "Level": 1, "Tutorial": "Done", "At": "Zone:SlimeMeadow"}))
        time.sleep(4)
        close(c)
        log(lua(c, HOOK, "Client"))
        log("  playtime:", lua(c, 'return tostring(game.Players:GetPlayers()[1]:GetAttribute("PlaytimeSeconds"))', "Server"))
        for i in range(10):
            log("  ", lua(c, FACE_SLIME, "Server"))
            time.sleep(0.4)
            key(c, "F")
            time.sleep(0.35)
            if i == 0:
                log("  sounds after one press:", lua(c, SOUNDS, "Client"))
            else:
                time.sleep(0.6)
            log("  xp text:", lua(c, XPTEXT, "Client"))
            if i in (2, 6):
                shot(c, os.path.join(OUT, f"1_xp_{i}.png"))
        log("  rewards:", lua(c, REWARDS, "Client"))
        # 2 empty quick slot
        path = lua(c, SLOT, "Client")
        log("2 slot button:", path)
        if path != "none":
            log("  ", click(c, path))
            time.sleep(1.5)
            log("  window:", lua(c, WORDS, "Client")[:400])
            shot(c, os.path.join(OUT, "2_empty_slot_bag.png"))
            close(c)
        # 3 EdgeHint
        log("3", lua(c, 'local b = require(game.ReplicatedStorage.Shared.Config).Map.Bounds local r = game.Players:GetPlayers()[1].Character '
                       'r:PivotTo(CFrame.lookAt(Vector3.new(b.MinX + 6, 8, 0), Vector3.new(b.MinX - 10, 8, 0))) return "at the edge"', "Server"))
        time.sleep(2.0)
        log(lua(c, B.FREE, "Client"))
        time.sleep(0.6)
        log("  ", lua(c, EDGE, "Client"))
        shot(c, os.path.join(OUT, "3_edge.png"))
        # 4 the Forge rows: a new save (nothing dropped yet) at the anvil, G = the weapon window
        log("4", scene(c, {"Faction": "Halo", "Class": "Warrior", "Level": 3, "Tutorial": "Done", "Done": ["M1_1"],
                           "At": "Anvil"}))
        time.sleep(4)
        close(c)
        log(lua(c, B.FREE, "Client"))
        log("  forgeopen:", lua(c, 'return tostring(game.Players:GetPlayers()[1]:GetAttribute("ForgeOpen"))', "Server"))
        key(c, "G")
        time.sleep(1.5)
        log("  rows:", lua(c, FORGE, "Client"))
        shot(c, os.path.join(OUT, "4_forge.png"))
        close(c)
        # 5 game play r8: right after getting up beside Fizzby, the first G did nothing (a small move fixed it)
        log("5", lua(c, PROMPT_HOOK, "Client"))
        log("  ", lua(c, 'local p = game.Players:GetPlayers()[1] p.Character:FindFirstChildOfClass("Humanoid").Health = 0 return "ko"', "Server"))
        time.sleep(7)
        log("  ", lua(c, 'local G = require(game.ReplicatedStorage.Shared.Config).FirstKOKing.GetUp local p = game.Players:GetPlayers()[1] '
                       'local at = G.Spot + Vector3.new(0, 4, 0) p.Character:PivotTo(CFrame.lookAt(at, Vector3.new(G.Face.X, at.Y, G.Face.Z))) return "up by Fizzby"', "Server"))
        time.sleep(0.8)
        close(c)
        log("  prompts:", lua(c, B.PROMPTS, "Client"), "| shown:", lua(c, 'return table.concat(_G.DEV1_SHOWN or {}, ",")', "Client"))
        key(c, "G")
        time.sleep(1.0)
        log("  after G#1:", lua(c, 'return table.concat(_G.DEV1_TRIG or {}, ",")', "Client"), "| window:", lua(c, WORDS, "Client")[:120])
        close(c)
        log("  ", lua(c, 'local ch = game.Players.LocalPlayer.Character ch:FindFirstChildOfClass("Humanoid"):Move(Vector3.new(0, 0, -1), true) task.wait(0.3) '
                       'ch:FindFirstChildOfClass("Humanoid"):Move(Vector3.zero) return "moved a bit"', "Client"))
        key(c, "G")
        time.sleep(1.0)
        log("  after G#2:", lua(c, 'return table.concat(_G.DEV1_TRIG or {}, ",")', "Client"), "| window:", lua(c, WORDS, "Client")[:120])
        shot(c, os.path.join(OUT, "5_fizzby.png"))
        close(c)
        # 6 game play r8: the bag's Quick [1] once -> the HUD slot 1 shows the potion at once and key 1 drinks it
        log("6", scene(c, {"Faction": "Halo", "Class": "Archer", "Level": 4, "Tutorial": "Done", "Done": ["M1_1"],
                           "Main": "M1_2:3", "At": "Zone:Crossroads"}))
        time.sleep(4)
        close(c)
        log("  ", lua(c, 'local p = game.Players:GetPlayers()[1] local d = require(game.ServerScriptService.PlayerService).GetData(p) '
                       'd.HPPotionCount = 1 p:SetAttribute("HPPotionCount", 1) d.QuickSlots = ",,MP" p:SetAttribute("QuickSlots", ",,MP") '
                       'return "1 HP potion, slot 1 emptied, slots=" .. tostring(d.QuickSlots)', "Server"))
        log("  hook:", lua(c, QS_HOOK, "Server"))
        log("  t=before", lua(c, QSTATE, "Client"), "| server", lua(c, QS_SERVER, "Server"))
        slot1 = lua(c, SLOTN % 1, "Client")
        log("  slot1 button:", slot1)
        if slot1 != "none":
            log("  ", click(c, slot1))
            time.sleep(1.2)
            q1 = lua(c, 'for _, d in game.Players.LocalPlayer.PlayerGui:GetDescendants() do if d:IsA("GuiButton") and d.Name == "Quick1" and d.Visible then return d:GetFullName() end end return "none"', "Client")
            log("  bag Quick1:", q1)
            if q1 != "none":
                log("  ", click(c, q1))
                prev = 0
                for t in (0.3, 1.5, 4.0):
                    time.sleep(t - prev)
                    prev = t
                    log(f"  t={t}", lua(c, QSTATE, "Client"), "| server", lua(c, QS_SERVER, "Server"))
                # r8 toggle: the same [1] again must keep the potion in slot 1
                q1b = lua(c, 'for _, d in game.Players.LocalPlayer.PlayerGui:GetDescendants() do if d:IsA("GuiButton") and d.Name == "Quick1" and d.Visible then return d:GetFullName() end end return "none"', "Client")
                if q1b != "none":
                    log("  again:", click(c, q1b))
                    time.sleep(1.5)
                    log("  t=again+1.5", lua(c, QSTATE, "Client"), "| server", lua(c, QS_SERVER, "Server"))
                shot(c, os.path.join(OUT, "6_quick1.png"))
                close(c)
                key(c, "One")
                time.sleep(1.0)
                log("  after key 1:", lua(c, QSTATE, "Client"), "| server", lua(c, QS_SERVER, "Server"))
        # 7 A23-219 the craft window's Tool tab (dev1-craft-tool), Crafting switched on for this test Play (server + client)
        log("7", lua(c, CRAFT_ON, "Server"), lua(c, CRAFT_ON, "Client"))
        log("  ", scene(c, {"Faction": "Neutral", "Class": "Warrior", "Level": 10, "Tutorial": "Done",
                            "Done": ["M1_1", "M1_2", "M1_3", "M1_4"], "At": "Zone:Crossroads"}))
        time.sleep(4)
        close(c)
        log("  ", lua(c, TOOL_SETUP % ("Smith", "{}", 0, "{ Clear = { \"CopperOre\", \"Jelly\" } }"), "Server"))
        time.sleep(1.0)
        log("  open:", lua(c, OPEN_TOOL, "Server"))
        time.sleep(1.5)
        log("  7a no mats, no gold:", lua(c, TOOL_STATE, "Client"))
        shot(c, os.path.join(OUT, "7a_need_mats.png"))
        log("  ", lua(c, TOOL_SETUP % ("Smith", "{ CopperOre = 40, Jelly = 40 }", 0, "false"), "Server"))
        time.sleep(1.2)
        log("  7b mats, no gold:", lua(c, TOOL_STATE, "Client"))
        shot(c, os.path.join(OUT, "7b_need_gold.png"))
        log("  ", lua(c, TOOL_SETUP % ("Smith", "{}", 500, "false"), "Server"))
        time.sleep(1.2)
        log("  7c ready:", lua(c, TOOL_STATE, "Client"))
        up = lua(c, FIND_UPGRADE, "Client")
        log("  upgrade button:", up)
        if up != "none":
            log("  ", click(c, up))
            time.sleep(0.15)
            shot(c, os.path.join(OUT, "7c_tool_pop.png"))
            time.sleep(1.2)
            log("  7c after (+0 -> +1 is 100%):", lua(c, TOOL_STATE, "Client"), "| server", lua(c, TOOL_SERVER, "Server"))
            shot(c, os.path.join(OUT, "7c_tool_up.png"))
            # 7d a fail: the hammer at +8 (+9 = 40%), craft Lv 20, all of the +9 cost x4, presses until a fail and a success
            log("  ", lua(c, TOOL_SETUP % ("Smith", "{ SilverOre = 100, KnightCrest = 60, ClatterGem = 4, DeepMoonShard = 8, MoonCrystal = 0 }",
                                           60000, "{ Tool = 8, Lv = 20 }"), "Server"))
            time.sleep(1.0)
            seen = set()
            for i in range(6):
                up = lua(c, FIND_UPGRADE, "Client")
                if up == "none":
                    break
                click(c, up)
                time.sleep(1.4)
                st = lua(c, TOOL_STATE, "Client")
                log(f"  7d press {i + 1}:", st, "| server", lua(c, TOOL_SERVER, "Server"))
                ok = "Result=Craft Hammer +" in st and "!" in st.split("Result=")[1].split(" | ")[0]
                same = "Result=Not this time" in st
                kind = "ok" if ok else "same" if same else "?"
                if kind not in seen:
                    shot(c, os.path.join(OUT, f"7d_tool_{kind}.png"))
                seen.add(kind)
                if "same" in seen and "ok" in seen:
                    break
            log("  7d seen:", sorted(seen))
        close(c)
        # 7e a blessed Enhance Scroll craft: an alchemist, the bless chance forced to 100% on the server for this Play
        log("7e", scene(c, {"Faction": "Neutral", "Class": "Mage", "Level": 10, "Tutorial": "Done",
                            "Done": ["M1_1", "M1_2", "M1_3", "M1_4"], "At": "Zone:Crossroads"}))
        time.sleep(4)
        close(c)
        log("  ", lua(c, TOOL_SETUP % ("Alch", "{ Herb = 20, CopperOre = 16, SlimeCore = 4 }", 500, "{ Tool = 3, Lv = 5, Bless = true }"), "Server"))
        time.sleep(1.0)
        log("  start:", lua(c, 'game.ReplicatedStorage.Remotes.CraftStart:FireServer("AS1") return "sent"', "Client"))
        time.sleep(2.0)
        skip = lua(c, 'for _, d in game.Players.LocalPlayer.PlayerGui:GetDescendants() do if d:IsA("GuiButton") and d.Name == "Skip" and d.Visible then return d:GetFullName() end end return "none"', "Client")
        log("  skip:", skip)
        if skip != "none":
            log("  ", click(c, skip))
            time.sleep(0.6)
            log("  7e result:", lua(c, 'local r, b = "", "" for _, d in game.Players.LocalPlayer.PlayerGui:GetDescendants() do if d:IsA("TextLabel") and d.Name == "Result" and d.Parent and d.Parent.Name == "CraftRing" then r = d.Text elseif d:IsA("TextLabel") and d.Name == "Bless" then b = d.Text end end return "Result=" .. r .. " | Bless=" .. b', "Client"),
                "| items", lua(c, 'local d = require(game.ServerScriptService.PlayerService).GetData(game.Players:GetPlayers()[1]) return "Enh70=" .. tostring(d.Items.Enh70) .. " Enh70B=" .. tostring(d.Items.Enh70B)', "Server"))
            shot(c, os.path.join(OUT, "7e_blessed.png"))
            time.sleep(2.0)
            log("  7e at 2.6 s still open:", lua(c, 'for _, d in game.Players.LocalPlayer.PlayerGui:GetDescendants() do if d.Name == "CraftRing" then return tostring(d.Enabled ~= false and (d:IsA("ScreenGui") and d.Enabled or d.Visible)) end end return "gone"', "Client"))
        log("  ", lua(c, 'local K = require(game.ReplicatedStorage.Shared.Config).Craft.Tools if _G.DevBlessKeep then K.Bless = _G.DevBlessKeep end return "bless table back"', "Server"))
        close(c)
    finally:
        save_log(os.path.join(OUT, "log.txt"))
        stop_play(c)


if __name__ == "__main__":
    main()
