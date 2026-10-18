"""Pre-publish press-through (최종 검수 10/16): a NEW save, opening skipped -> side + class -> guide Talk prompt Enabled + '!'
-> Talk -> Welcome -> [I'm In!] -> teacher prompt Enabled -> Talk -> forge -> anvil key = first weapon -> anvil key again =
Otto's M1_1 offer window + the quest row 'Talk to Otto' -> [Accept] -> M1_1 started. In MY test Studio
(STUDIO_NAME=PhoneTest_1015) only; Studio MCP virtual keys / clicks inside my test Play.
Usage: py full1016.py <Halo|Horns> <tag>"""
import os, sys, time
GAME = r"C:\Users\glori\Documents\Roblox\Game"
sys.path.insert(0, os.path.join(GAME, "tools"))
from studio_mcp import Client  # noqa: E402

SIDE = sys.argv[1] if len(sys.argv) > 1 else "Halo"
TAG = sys.argv[2] if len(sys.argv) > 2 else SIDE.lower()
GUIDE = {"Halo": "Hallie", "Horns": "Magpie"}[SIDE]
TEACHER = {"Halo": "Gleam", "Horns": "Smokey"}[SIDE]
OUT = os.path.join(GAME, "docs", "art", "verification_2026-10-16", "prepublish_flow")
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


def key(c, k):
    c.call("user_keyboard_input", {"actions": [{"action": "keyPress", "key_code": k}], "datamodel_type": "Client"})


def click(c, full):
    if "PlayerGui." not in full:
        return "no path " + full
    path = "LocalPlayer.PlayerGui." + full.split("PlayerGui.", 1)[1]
    try:
        c.call("user_mouse_input", {"actions": [{"action": "moveTo", "instance_path": path},
                                                {"action": "mouseButtonClick", "mouse_button": "left"}], "datamodel_type": "Client"})
        return "clicked " + path
    except Exception as e:  # noqa: BLE001
        return "click err " + str(e)[:200]


NPC_STATE = r'''
local id = "%s"
local out = {}
for _, m in game:GetService("CollectionService"):GetTagged("StoryNpc") do
	if m:GetAttribute("NpcId") == id and m:IsDescendantOf(workspace) then
		for _, d in m:GetDescendants() do
			if d:IsA("ProximityPrompt") then
				table.insert(out, string.format("prompt %%s enabled=%%s key=%%s", d.Name, tostring(d.Enabled), d.KeyboardKeyCode.Name))
			end
		end
		local mark = m:FindFirstChild("StoryNpcMark", true)
		local lbl = mark and mark:FindFirstChild("Mark", true)
		table.insert(out, "mark=" .. tostring(mark and mark.Enabled) .. " sign=" .. tostring(lbl and lbl.Text))
	end
end
return #out > 0 and table.concat(out, " | ") or ("no body " .. id)
'''
GO_TO = r'''
local id = "%s"
local p = game:GetService("Players"):GetPlayers()[1]
local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
for _, m in game:GetService("CollectionService"):GetTagged("StoryNpc") do
	if m:GetAttribute("NpcId") == id and m:IsDescendantOf(workspace) then
		local cf = m:GetPivot()
		local at = (cf * CFrame.new(0, 0, -4)).Position
		hrp.CFrame = CFrame.lookAt(at + Vector3.new(0, 1, 0), cf.Position)
		return "at " .. id
	end
end
return "no body " .. id
'''
STATE = r'''
local p = game:GetService("Players"):GetPlayers()[1]
return "step=" .. tostring(p:GetAttribute("TutorialStep")) .. " faction=" .. tostring(p:GetAttribute("Faction"))
	.. " tier=" .. tostring(p:GetAttribute("WeaponTier")) .. " offers=" .. tostring(p:GetAttribute("StoryOffers"))
'''
MAIN = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local ok, PD = pcall(require, game:GetService("ServerScriptService"):FindFirstChild("DataService", true))
local d = ok and type(PD) == "table" and type(PD.Get) == "function" and PD.Get(p) or nil
local st = d and d.Story
return "main=" .. tostring(st and st.Main and st.Main.Id) .. " st=" .. tostring(st and st.Main and st.Main.St)
'''
ROWS = r'''
local pg = game.Players.LocalPlayer.PlayerGui
local out = {}
for _, d in pg:GetDescendants() do
	if d:IsA("TextLabel") and d.Text ~= "" and (string.find(d.Text, "Talk to", 1, true) or string.find(d.Text, "To ", 1, true) == 1) then
		table.insert(out, d.Name .. "='" .. d.Text .. "' vis=" .. tostring(d.Visible))
	end
end
return #out > 0 and table.concat(out, " ; ") or "no 'Talk to' label"
'''
PANEL = r'''
local pg = game.Players.LocalPlayer.PlayerGui
local m = pg:FindFirstChild("PanelsModal", true)
local function vis(n) local x = pg:FindFirstChild(n, true) return x and x:IsA("GuiObject") and x.Visible and x:GetFullName() or "none" end
return "panel=" .. tostring(m and m.Visible) .. " welcomeNext=" .. vis("WelcomeNext") .. " offerNext=" .. vis("OfferNext")
	.. " offerAccept=" .. vis("OfferAccept") .. " storyNext=" .. vis("StoryNext") .. " storyOk=" .. vis("StoryOk")
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
return "at anvil"
'''
ANVIL_KEY = r'''
for _, d in workspace:GetDescendants() do
	if d:IsA("ProximityPrompt") and d.Name == "HHC_BlacksmithPrompt" then return d.KeyboardKeyCode.Name .. " enabled=" .. tostring(d.Enabled) end
end
return "none"
'''
WORDS = r'''
local pg = game.Players.LocalPlayer.PlayerGui
local m = pg:FindFirstChild("PanelsModal", true)
if not (m and m.Visible) then return "(no window)" end
local out = {}
for _, d in m:GetDescendants() do
	if d:IsA("TextLabel") and d.Visible and d.Text ~= "" then table.insert(out, d.Name .. ":" .. string.sub(d.Text, 1, 70)) end
end
return table.concat(out, " / ")
'''
QROWS = r'''
local pg = game.Players.LocalPlayer.PlayerGui
local out = {}
for _, d in pg:GetDescendants() do
	if d:IsA("TextLabel") and (d.Name == "Text" or d.Name == "Goal" or d.Name == "Title") and d.Text ~= "" and d:FindFirstAncestorOfClass("ScreenGui") and d:FindFirstAncestorOfClass("ScreenGui").Name ~= "Chat" then
		table.insert(out, d.Name .. "='" .. string.sub(d.Text, 1, 60) .. "'")
	end
end
return table.concat(out, " ; ")
'''
AWAY = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
for _, d in workspace:GetDescendants() do
	if d:IsA("Model") and d.Name == "Npc_Otto" then
		local cf = d:GetPivot()
		local at = (cf * CFrame.new(0, 0, -35)).Position
		hrp.CFrame = CFrame.lookAt(at + Vector3.new(0, 3, 0), cf.Position + Vector3.new(0, 3, 0))
		return string.format("35 studs from Otto (otto at %.0f,%.0f,%.0f)", cf.X, cf.Y, cf.Z)
	end
end
return "no otto"
'''
MARKER = r'''
local pg = game.Players.LocalPlayer.PlayerGui
local g = pg:FindFirstChild("QuestMarkerGui")
local m = g and g:FindFirstChild("QuestMarker", true)
local d = g and g:FindFirstChild("Distance", true)
local cam = workspace.CurrentCamera
local otto
for _, x in workspace:GetDescendants() do if x:IsA("Model") and x.Name == "Npc_Otto" then otto = x break end end
local sp = otto and cam:WorldToViewportPoint(otto:GetPivot().Position)
return string.format("marker gui=%s vis=%s pos=(%.0f,%.0f) dist='%s' | otto on screen at (%.0f,%.0f)", tostring(g and g.Enabled),
	tostring(m and m.Visible), m and m.AbsolutePosition.X or -1, m and m.AbsolutePosition.Y or -1, tostring(d and d.Text),
	sp and sp.X or -1, sp and sp.Y or -1)
'''
ROWTAP = r'''
local pg = game.Players.LocalPlayer.PlayerGui
for _, d in pg:GetDescendants() do
	if d:IsA("TextLabel") and d.Text == "Talk to Otto" then
		local row = d.Parent
		while row and not (row:FindFirstChild("Tap") and row:FindFirstChild("Tap"):IsA("TextButton")) do row = row.Parent end
		if row then return row.Tap:GetFullName() .. " vis=" .. tostring(row.Tap.Visible) end
	end
end
return "none"
'''
CLOSE = 'local pg = game.Players.LocalPlayer.PlayerGui for _, d in pg:GetDescendants() do if d.Name == "PanelsModal" and d:IsA("GuiObject") then d.Visible = false end end return "closed"'


CLOSER = r'''
local pg = game.Players.LocalPlayer.PlayerGui
local m = pg:FindFirstChild("PanelsModal", true)
if not (m and m.Visible) then return "none" end
for _, n in { "OfferDecline", "StoryLater", "Close" } do
	local x = m:FindFirstChild(n, true)
	if x and x:IsA("GuiButton") and x.Visible then return x:GetFullName() end
end
return "none"
'''


def shot(c, name):
    import base64, io
    from PIL import Image
    try:
        res = c.call("screen_capture", {"capture_id": name})
    except Exception as e:  # noqa: BLE001
        log("shot fail", name, e)
        return
    for part in res.get("content", []):
        if part.get("type") == "image":
            Image.open(io.BytesIO(base64.b64decode(part["data"]))).convert("RGB").save(os.path.join(OUT, f"{TAG}_{name}.png"))
            log("shot", name)
            return


def close(c):
    """a real close: [Not now] / [Later] / the window's Close button (Panels.IsOpen goes false)"""
    for _ in range(3):
        b = lua(c, CLOSER, "Client")
        if b == "none":
            return
        log("  close:", click(c, b))
        time.sleep(1.0)


def press_through(c, label, first):
    """Next... until first (a button name) shows, then press it."""
    for _ in range(8):
        p = lua(c, PANEL, "Client")
        target = p.split(first + "=")[1].split(" ")[0]
        if target != "none":
            log(label, click(c, target))
            time.sleep(2.5)
            return True
        nxt = None
        for n in ("offerNext", "storyNext", "welcomeNext"):
            v = p.split(n + "=")[1].split(" ")[0]
            if v != "none" and n.lower() != first.lower():
                nxt = v
                break
        if not nxt:
            log(label, "no", first, "::", p)
            return False
        click(c, nxt)
        time.sleep(0.9)
    return False


def console(c):
    try:
        out = text_of(c.call("get_console_output", {}))
        errs = [l for l in out.splitlines() if "rror" in l or "failed" in l or "nfinite yield" in l]
        log("console errors:", "\n".join(errs[-15:]) or "none")
    except Exception as e:  # noqa: BLE001
        log("console err", e)


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
        key(c, "Return")  # skip the opening
        time.sleep(2.5)
        log("0", lua(c, STATE, "Server"))
        log(lua(c, 'local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes") R:WaitForChild("ChooseFaction"):FireServer("%s") task.wait(2.5) R:WaitForChild("ChooseClass"):FireServer("Warrior", "M") task.wait(3) return "picked"' % SIDE, "Client"))
        time.sleep(2)
        log("1 picked:", lua(c, STATE, "Server"))
        log(lua(c, GO_TO % GUIDE, "Server"))
        time.sleep(2)
        log("2 near", GUIDE + ":", lua(c, NPC_STATE % GUIDE, "Client"))
        key(c, "G")
        time.sleep(2.5)
        log("3 after Talk:", lua(c, STATE, "Server"), lua(c, PANEL, "Client"))
        press_through(c, "3b Welcome -> I'm In:", "welcomeNext")
        log("4 after I'm In:", lua(c, STATE, "Server"), lua(c, PANEL, "Client"))
        close(c)
        log(lua(c, GO_TO % TEACHER, "Server"))
        time.sleep(2)
        log("5 near", TEACHER + ":", lua(c, NPC_STATE % TEACHER, "Client"))
        key(c, "G")
        time.sleep(2.5)
        log("6 after teacher Talk:", lua(c, STATE, "Server"), lua(c, PANEL, "Client"))
        log("6 words:", lua(c, WORDS, "Client"))
        for _ in range(4):  # the teacher's pages (Next / Ok) to the end
            p = lua(c, PANEL, "Client")
            nxt = next((p.split(n + "=")[1].split(" ")[0] for n in ("storyNext", "welcomeNext", "storyOk")
                        if p.split(n + "=")[1].split(" ")[0] != "none"), None)
            if not nxt:
                break
            click(c, nxt)
            time.sleep(1.2)
        close(c)
        time.sleep(1)
        log("7 after teacher:", lua(c, STATE, "Server"))
        log(lua(c, TO_ANVIL, "Server"))
        time.sleep(1.5)
        ak = lua(c, ANVIL_KEY, "Client")
        log("8 anvil prompt:", ak)
        k = ak.split(" ")[0] if ak != "none" else "G"
        key(c, k)
        time.sleep(3)
        log("9 anvil 1 (first weapon):", lua(c, STATE, "Server"), lua(c, PANEL, "Client"))
        log("9 words:", lua(c, WORDS, "Client"))
        close(c)
        time.sleep(2)
        log("10 rows:", lua(c, ROWS, "Client"))
        log("10 Otto:", lua(c, NPC_STATE % "Otto", "Client"))
        log("10b", lua(c, AWAY, "Server"))
        time.sleep(2.5)
        log("10b marker:", lua(c, MARKER, "Client"))
        shot(c, "otto_marker")
        tap = lua(c, ROWTAP, "Client")
        log("10c row tap:", tap, click(c, tap.split(" ")[0]) if tap != "none" else "")
        time.sleep(1.5)
        log("10c marker after tap:", lua(c, MARKER, "Client"))
        log(lua(c, TO_ANVIL, "Server"))
        time.sleep(1.5)
        key(c, k)
        time.sleep(3)
        log("11 anvil 2:", lua(c, STATE, "Server"), lua(c, PANEL, "Client"))
        log("11 words:", lua(c, WORDS, "Client"))
        ok = press_through(c, "12 offer -> Accept:", "offerAccept")
        log("13 after Accept:", ok, lua(c, STATE, "Server"), lua(c, MAIN, "Server"), lua(c, PANEL, "Client"))
        close(c)
        time.sleep(1)
        log("14 rows:", lua(c, ROWS, "Client"))
        log("14 quest rows:", lua(c, QROWS, "Client"))
        console(c)
    finally:
        try:
            c.call("start_stop_play", {"is_start": False})
        except Exception as e:  # noqa: BLE001
            log("stop", e)
        with open(os.path.join(OUT, f"{TAG}_log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG))


main()
