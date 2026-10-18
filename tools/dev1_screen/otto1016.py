"""Repro: after the first weapon at Otto's anvil, can a new save open Otto's M1_1 offer? In MY test Studio
(STUDIO_NAME=PhoneTest_1015) with 개발 2's scene command synced. Virtual keys inside my test Play only.
Usage: py otto1016.py <tag>"""
import os, subprocess, sys, time
GAME = r"C:\Users\glori\Documents\Roblox\Game"
sys.path.insert(0, os.path.join(GAME, "tools"))
from studio_mcp import Client  # noqa: E402

TAG = sys.argv[1] if len(sys.argv) > 1 else "run"
TREE = r"C:\Users\glori\Documents\Roblox\wt_dev1b"
OUT = os.path.join(GAME, "docs", "art", "verification_2026-10-16", "otto_offer")
os.makedirs(OUT, exist_ok=True)
LOG = []


def log(*a):
    s = " ".join(str(x) for x in a)
    print(s, flush=True)
    LOG.append(s)


def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))


def lua(c, code, dm):
    try:
        return text_of(c.call("execute_luau", {"code": code, "datamodel_type": dm}))
    except Exception as e:  # noqa: BLE001
        return "ERR " + str(e)[:300]


PROMPTS = r'''
local me = game.Players.LocalPlayer
local hrp = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
local out = {}
for _, d in workspace:GetDescendants() do
	if d:IsA("ProximityPrompt") and d.Parent and hrp then
		local par = d.Parent
		local pos = par:IsA("BasePart") and par.Position or (par:IsA("Attachment") and par.WorldPosition) or nil
		local dist = pos and (pos - hrp.Position).Magnitude or 999
		if dist < 40 then
			table.insert(out, string.format("%s[%s] on=%s key=%s excl=%s dist=%.1f max=%s story=%s", d.Name, d.Parent:GetFullName():sub(-30),
				tostring(d.Enabled), d.KeyboardKeyCode.Name, d.Exclusivity.Name, dist, tostring(d.MaxActivationDistance), tostring(d:GetAttribute("StoryNpcId"))))
		end
	end
end
return table.concat(out, "\n")
'''
STATE = r'''
local p = game:GetService("Players"):GetPlayers()[1]
return "step=" .. tostring(p:GetAttribute("TutorialStep")) .. " tier=" .. tostring(p:GetAttribute("WeaponTier")) .. " offers=" .. tostring(p:GetAttribute("StoryOffers"))
'''
PANEL = r'''
local pg = game.Players.LocalPlayer.PlayerGui
local m = pg:FindFirstChild("PanelsModal", true)
local o = pg:FindFirstChild("OfferAccept", true)
local t = m and m:FindFirstChild("Title", true)
return "panel=" .. tostring(m and m.Visible) .. " offerAccept=" .. tostring(o ~= nil) .. " title=" .. tostring(t and t.Text)
'''
SHOWN = r'''
local PPS = game:GetService("ProximityPromptService")
local me = game.Players.LocalPlayer
local hrp = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
local shown = {}
local c1 = PPS.PromptShown:Connect(function(p) shown[p] = true end)
local c2 = PPS.PromptHidden:Connect(function(p) shown[p] = nil end)
local near = {}
for _, d in workspace:GetDescendants() do
	local par = d:IsA("ProximityPrompt") and d.Parent or nil
	local pos = par and (par:IsA("BasePart") and par.Position or (par:IsA("Attachment") and par.WorldPosition)) or nil
	if pos and d.Enabled and hrp and (pos - hrp.Position).Magnitude < 15 then
		table.insert(near, d)
	end
end
for _, d in near do d.Enabled = false end
task.wait(0.3)
for _, d in near do d.Enabled = true end
task.wait(1.0)
c1:Disconnect() c2:Disconnect()
local out = {}
for p in shown do table.insert(out, p.Name .. "(" .. tostring(p:GetAttribute("StoryNpcId")) .. ")") end
return "shown: " .. table.concat(out, ", ") .. " of near " .. #near
'''
TO_ANVIL = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
local anvil, otto
for _, d in workspace:GetDescendants() do
	if d:IsA("ProximityPrompt") and d.Name == "HHC_BlacksmithPrompt" then anvil = d.Parent end
	if d:IsA("Model") and d.Name == "Npc_Otto" then otto = d end
end
if not anvil or not hrp then return "no anvil" end
local a = anvil:IsA("BasePart") and anvil.Position or anvil:GetPivot().Position
local o = otto and otto:GetPivot().Position or (a + Vector3.new(0, 0, 4))
local away = (a - o) * Vector3.new(1, 0, 1)
away = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1)
local at = a + away * 5
hrp.CFrame = CFrame.lookAt(Vector3.new(at.X, a.Y + 3, at.Z), Vector3.new(a.X, a.Y + 3, a.Z))
return string.format("at anvil front (otto %.1f studs behind it)", (o - a).Magnitude)
'''
TO_OTTO = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
for _, d in workspace:GetDescendants() do
	if d:IsA("Model") and d.Name == "Npc_Otto" then
		local cf = d:GetPivot()
		local at = (cf * CFrame.new(0, 0, -3)).Position
		hrp.CFrame = CFrame.lookAt(at, cf.Position)
		return "next to Otto"
	end
end
return "no otto"
'''
CLOSE = 'local pg = game.Players.LocalPlayer.PlayerGui for _, d in pg:GetDescendants() do if d.Name == "PanelsModal" and d:IsA("GuiObject") then d.Visible = false end end return "closed"'


def main():
    c = Client()
    c.start()
    lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return ""', "Edit")
    c.call("start_stop_play", {"is_start": True})
    try:
        t0 = time.time()
        while time.time() - t0 < 90:
            if lua(c, 'local p = game.Players:GetPlayers()[1] return tostring(p and p:GetAttribute("DataLoaded"))', "Server") == "true":
                break
            time.sleep(1.5)
        time.sleep(2.5)
        c.call("user_keyboard_input", {"actions": [{"action": "keyPress", "key_code": "Return"}], "datamodel_type": "Client"})
        time.sleep(2)
        env = dict(os.environ, STUDIO_NAME="PhoneTest_1015")
        r = subprocess.run([sys.executable, os.path.join(TREE, "tools", "scene.py"), "TutorialForge"], capture_output=True, text=True, env=env, timeout=120)
        log("scene:", (r.stdout + r.stderr).strip()[:300])
        time.sleep(3)
        log("1", lua(c, STATE, "Server"), lua(c, 'local h = game.Players.LocalPlayer.Character.HumanoidRootPart return tostring(h.Position)', "Client"))
        log(lua(c, TO_ANVIL, "Server"))
        time.sleep(1.5)
        log("prompts:\n" + lua(c, PROMPTS, "Client"))
        log("visible before:", lua(c, SHOWN, "Client"))
        # the anvil (first weapon): its key
        p = lua(c, PROMPTS, "Client")
        key = "E"
        for line in p.splitlines():
            if "story=nil" in line and "on=true" in line:
                key = line.split("key=")[1].split(" ")[0]
                break
        c.call("user_keyboard_input", {"actions": [{"action": "keyPress", "key_code": key}], "datamodel_type": "Client"})
        time.sleep(3)
        log("2 after anvil", key, lua(c, STATE, "Server"), lua(c, PANEL, "Client"))
        lua(c, CLOSE, "Client")
        time.sleep(2)
        # 개발 2's fix: the anvil again, now that Otto has M1_1 for me -> his offer window -> [Accept]
        c.call("user_keyboard_input", {"actions": [{"action": "keyPress", "key_code": key}], "datamodel_type": "Client"})
        time.sleep(3)
        pan = lua(c, PANEL, "Client")
        log("2b anvil again:", pan)
        acc = lua(c, 'local x = game.Players.LocalPlayer.PlayerGui:FindFirstChild("OfferAccept", true) return x and x:GetFullName() or "none"', "Client")
        if acc != "none" and "PlayerGui." in acc:
            path = "LocalPlayer.PlayerGui." + acc.split("PlayerGui.", 1)[1]
            # the offer pages first (Next until Accept shows), then Accept
            for _ in range(6):
                nxt = lua(c, 'local x = game.Players.LocalPlayer.PlayerGui:FindFirstChild("OfferNext", true) return x and x.Visible and x:GetFullName() or "none"', "Client")
                vis = lua(c, 'local x = game.Players.LocalPlayer.PlayerGui:FindFirstChild("OfferAccept", true) return tostring(x and x.Visible)', "Client")
                if vis == "true":
                    break
                if nxt != "none":
                    try:
                        c.call("user_mouse_input", {"actions": [{"action": "moveTo", "instance_path": "LocalPlayer.PlayerGui." + nxt.split("PlayerGui.", 1)[1]},
                                                                {"action": "mouseButtonClick", "mouse_button": "left"}], "datamodel_type": "Client"})
                    except Exception as e:  # noqa: BLE001
                        log("next err", e)
                    time.sleep(0.8)
            try:
                c.call("user_mouse_input", {"actions": [{"action": "moveTo", "instance_path": path},
                                                        {"action": "mouseButtonClick", "mouse_button": "left"}], "datamodel_type": "Client"})
            except Exception as e:  # noqa: BLE001
                log("accept err", e)
            time.sleep(2.5)
            log("2c after Accept:", lua(c, STATE, "Server"), lua(c, PANEL, "Client"))
        lua(c, CLOSE, "Client")
        time.sleep(1)
        log("prompts after gift:\n" + lua(c, PROMPTS, "Client"))
        log("visible:", lua(c, SHOWN, "Client"))
        # Otto's Talk if any: press its key
        p = lua(c, PROMPTS, "Client")
        okey = None
        for line in p.splitlines():
            if "story=Otto" in line and "on=true" in line:
                okey = line.split("key=")[1].split(" ")[0]
        if okey:
            c.call("user_keyboard_input", {"actions": [{"action": "keyPress", "key_code": okey}], "datamodel_type": "Client"})
            time.sleep(2.5)
            log("3 after Otto key", okey, lua(c, PANEL, "Client"))
        else:
            log("3 no enabled Otto Talk prompt")
        lua(c, CLOSE, "Client")
        log(lua(c, TO_OTTO, "Server"))
        time.sleep(1.5)
        log("4 next to Otto prompts:\n" + lua(c, PROMPTS, "Client"))
        log("4 visible:", lua(c, SHOWN, "Client"))
        c.call("user_keyboard_input", {"actions": [{"action": "keyPress", "key_code": okey or "G"}], "datamodel_type": "Client"})
        time.sleep(2.5)
        log("5 after key next to Otto", lua(c, PANEL, "Client"))
    finally:
        try:
            c.call("start_stop_play", {"is_start": False})
        except Exception as e:  # noqa: BLE001
            log("stop", e)
        with open(os.path.join(OUT, f"{TAG}_log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG))


main()
