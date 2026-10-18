"""Shared helpers for game dev 1's 10/16 Studio checks (my test Studio only: STUDIO_NAME / STUDIO_ID, never the main one)."""
import base64, io, json, os, sys, time
GAME = r"C:\Users\glori\Documents\Roblox\Game"
sys.path.insert(0, os.path.join(GAME, "tools"))
from studio_mcp import Client  # noqa: E402,F401

LOG = []


def log(*a):
    s = " ".join(str(x) for x in a)
    print(s, flush=True)
    LOG.append(s)


def save_log(path):
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(LOG))


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


def shot(c, path):
    from PIL import Image
    try:
        res = c.call("screen_capture", {"capture_id": os.path.basename(path)})
    except Exception as e:  # noqa: BLE001
        log("shot fail", path, e)
        return False
    for part in res.get("content", []):
        if part.get("type") == "image":
            Image.open(io.BytesIO(base64.b64decode(part["data"]))).convert("RGB").save(path)
            return True
    log("shot: no image", path)
    return False


def debug(c, k, v):
    """Main's Studio-only DebugCommand on the first player (server)"""
    return lua(c, "local p = game.Players:GetPlayers()[1] if not p then return 'no player' end "
                  "return tostring(game.ServerScriptService.DebugCommand:Invoke(p.Name, %s, %s))" % (json.dumps(k), json.dumps(v)
                  if not isinstance(v, (int, float)) else str(v)), "Server")


def scene(c, spec):
    return debug(c, "Scene", spec if isinstance(spec, str) else json.dumps(spec))


def story(c):
    raw = debug(c, "StoryDump", "")
    try:
        return json.loads(raw)
    except Exception:  # noqa: BLE001
        return {"raw": raw[:300]}


def main_of(st):
    m = st.get("Main") if isinstance(st, dict) else None
    return "main=%s st=%s p=%s claim=%s" % (m and m.get("Id"), m and m.get("St"), m and m.get("P"), m and m.get("Claim"))


PANEL = r'''
local pg = game.Players.LocalPlayer.PlayerGui
local m = pg:FindFirstChild("PanelsModal", true)
local out = {}
if m and m.Visible then
	for _, d in m:GetDescendants() do
		if d:IsA("GuiButton") and d.Visible and d.Name ~= "Button" then
			local vis = true
			local x = d.Parent
			while x and x ~= m do if x:IsA("GuiObject") and not x.Visible then vis = false break end x = x.Parent end
			if vis then table.insert(out, d.Name .. "=" .. d:GetFullName()) end
		end
	end
end
return "panel=" .. tostring(m and m.Visible) .. " " .. table.concat(out, " ")
'''
WORDS = r'''
local pg = game.Players.LocalPlayer.PlayerGui
local m = pg:FindFirstChild("PanelsModal", true)
if not (m and m.Visible) then return "(no window)" end
local out = {}
for _, d in m:GetDescendants() do
	if d:IsA("TextLabel") and d.Visible and d.Text ~= "" then table.insert(out, d.Name .. ":" .. string.sub(d.Text, 1, 80)) end
end
return table.concat(out, " / ")
'''
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
		local p = m:GetPivot().Position
		table.insert(out, string.format("at=(%%.0f,%%.0f,%%.0f)", p.X, p.Y, p.Z))
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
		hrp.CFrame = CFrame.lookAt(at + Vector3.new(0, 1, 0), Vector3.new(cf.X, at.Y + 1, cf.Z))
		return "at " .. id
	end
end
return "no body " .. id
'''
# every visible text in the player's screen that looks like a quest row / bubble line containing `needle`
FIND_TEXT = r'''
local needle = %s
local pg = game.Players.LocalPlayer.PlayerGui
local out = {}
local function scan(root, where)
	for _, d in root:GetDescendants() do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and string.find(d.Text, needle, 1, true) then
			local g = d:FindFirstAncestorWhichIsA("LayerCollector")
			table.insert(out, where .. ":" .. d.Name .. "='" .. string.sub(d.Text, 1, 70) .. "' vis=" .. tostring(d.Visible)
				.. " gui=" .. tostring(g and g.Name) .. "(" .. tostring(g and g.Enabled) .. ")"
				.. (g and g:IsA("BillboardGui") and g.Adornee and (" on=" .. g.Adornee:GetFullName()) or ""))
		end
	end
end
scan(pg, "screen")
scan(workspace, "world")
return #out > 0 and table.concat(out, " ; ") or ("no text '" .. needle .. "'")
'''
MARKER = r'''
local pg = game.Players.LocalPlayer.PlayerGui
local g = pg:FindFirstChild("QuestMarkerGui")
local m = g and g:FindFirstChild("QuestMarker", true)
local d = g and g:FindFirstChild("Distance", true)
return string.format("marker gui=%s vis=%s pos=(%.0f,%.0f) dist='%s'", tostring(g and g.Enabled), tostring(m and m.Visible),
	m and m.AbsolutePosition.X or -1, m and m.AbsolutePosition.Y or -1, tostring(d and d.Text))
'''


def panel_buttons(c):
    p = lua(c, PANEL, "Client")
    btns = {}
    for tok in p.split(" ")[1:]:
        if "=" in tok:
            n, full = tok.split("=", 1)
            btns[n] = full
    return p.split(" ")[0], btns


def close(c):
    for _ in range(3):
        b = lua(c, CLOSER, "Client")
        if b == "none" or b.startswith("ERR"):
            return
        log("  close:", click(c, b))
        time.sleep(1.0)


def press_until(c, label, want, avoid=("OfferDecline", "StoryLater", "Close")):
    """Next / Ok through the window until a button in `want` shows, then press it (returns its name or None)."""
    for _ in range(10):
        state, btns = panel_buttons(c)
        for w in want:
            if w in btns:
                log(label, w, click(c, btns[w]))
                time.sleep(2.0)
                return w
        nxt = next((btns[n] for n in ("OfferNext", "StoryNext", "WelcomeNext", "StoryOk") if n in btns and n not in avoid), None)
        if not nxt:
            log(label, "no", want, "::", state, list(btns))
            return None
        click(c, nxt)
        time.sleep(0.9)
    return None


def console_errors(c, tail=15):
    try:
        out = text_of(c.call("get_console_output", {}))
        errs = [l for l in out.splitlines() if ("rror" in l or "failed" in l or "nfinite yield" in l) and "DebugTainted" not in l]
        log("console errors:", "\n".join(errs[-tail:]) or "none")
    except Exception as e:  # noqa: BLE001
        log("console err", e)


def start_play(c, fresh=True):
    if fresh:
        lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return ""', "Edit")
    c.call("start_stop_play", {"is_start": True})
    t0 = time.time()
    while time.time() - t0 < 120:
        if lua(c, 'local p = game.Players:GetPlayers()[1] return tostring(p and p:GetAttribute("DataLoaded"))', "Server") == "true":
            break
        time.sleep(1.5)
    time.sleep(2.5)
    key(c, "Return")  # skip the opening
    time.sleep(2.5)


def pick(c, side, cls="Warrior"):
    return lua(c, 'local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes") R:WaitForChild("ChooseFaction"):FireServer("%s") '
                  'task.wait(2.5) R:WaitForChild("ChooseClass"):FireServer("%s", "M") task.wait(3) return "picked"' % (side, cls), "Client")


def stop_play(c):
    try:
        c.call("start_stop_play", {"is_start": False})
    except Exception as e:  # noqa: BLE001
        log("stop", e)
