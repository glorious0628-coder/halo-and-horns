"""Sound Play check (docs/design/sound_play_check_2026-10-07.md): own test Play in the main Studio with a FRESH in-memory
save (ServerStorage StudioFreshSave, Studio only), on PC or on the phone simulator (749x361, back to default at the end).
A client collector hooks Sound.Played on every Sound under SoundService (Audio's pools are named Sfx_<event>_<n>, Fx's
cached ones Fx_<name>) and records name / SoundId / Volume / PlaybackSpeed / SoundGroup volume (ducking) with a time
stamp; the flow below fires the first-10-minutes moments and the world events (DebugCommand, Studio only), and every
step writes a marker row so each sound can be matched to its scene. No mouse / keyboard: remotes, Keybinds.Dispatch,
ProximityPrompt:InputHoldBegin, DebugCommand. Stops Play in a finally block.
Usage: py tools/play_sound_check.py pc|phone|world [outdir-name]   (world = after the first weapon: a real level-up to
Lv5 + the Q skill, then the world sounds sent the way their services send them and a step into a PvP zone)
Out: docs/art/verification_2026-10-08/sound_play/<mode>/ (log.txt, sounds.json, captures)"""
import base64
import ctypes
import io
import json
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402

MODE = sys.argv[1] if len(sys.argv) > 1 else "pc"
OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-08", "sound_play",
                   sys.argv[2] if len(sys.argv) > 2 else MODE)
LOG = []
T0 = time.time()


def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))


def lua(c, code, dm):
    try:
        return text_of(c.call("execute_luau", {"code": code, "datamodel_type": dm}))
    except Exception as e:  # noqa: BLE001
        return "ERR " + str(e)[:200]


def note(msg):
    line = f"[{time.time() - T0:6.1f}] {msg}"
    print(line, flush=True)
    LOG.append(line)


def save(c, name):
    try:
        res = c.call("screen_capture", {"capture_id": name})
    except Exception as e:  # noqa: BLE001
        note("capture failed " + name + " " + str(e)[:120])
        return
    for part in res.get("content", []):
        if part.get("type") == "image":
            from PIL import Image
            os.makedirs(OUT, exist_ok=True)
            path = os.path.join(OUT, name + ".png")
            Image.open(io.BytesIO(base64.b64decode(part["data"]))).save(path)
            note("saved " + os.path.relpath(path, ROOT))
            return
    note("capture failed " + name)


def restore_studio_window():
    """A minimized Studio renders the 3D view white in captures: restore it to the bottom of the z-order (no focus)."""
    user32 = ctypes.windll.user32
    found = []

    @ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
    def cb(h, _):
        n = user32.GetWindowTextLengthW(h)
        if n:
            buf = ctypes.create_unicode_buffer(n + 1)
            user32.GetWindowTextW(h, buf, n + 1)
            if "GoodEvil" in buf.value and "Roblox Studio" in buf.value:
                found.append(h)
        return True

    user32.EnumWindows(cb, 0)
    for h in found:
        if user32.IsIconic(h):
            user32.SetWindowPos(h, 1, 0, 0, 0, 0, 0x13)
            user32.ShowWindow(h, 4)
            note("studio window restored (no focus)")
    return len(found)


SET_PHONE = r'''
local svc = game:GetService("StudioDeviceSimulatorService")
svc:SetDeviceAsync("samsung_galaxy_s22_ultra")
task.wait(0.3)
svc:SetResolutionAsync(749, 361)
task.wait(0.3)
svc:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.ActualResolution)
task.wait(0.3)
local r = svc:GetResolutionAsync()
return svc:GetDeviceAsync() .. " " .. r.X .. "x" .. r.Y
'''
RESTORE = r'''
local svc = game:GetService("StudioDeviceSimulatorService")
if svc:GetDeviceAsync() ~= "default" then
	pcall(function() svc:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.FitToWindow) end)
	svc:StopSimulationAsync()
	task.wait(0.3)
end
return svc:GetDeviceAsync()
'''

STATE = r"""
local p = game:GetService("Players"):GetPlayers()[1]
if not p then return "no player" end
local keys = { "DataLoaded", "Faction", "Class", "ClassChosen", "TutorialStep", "TutorialKills", "WeaponTier", "Level",
	"CarriedGold", "BankGold", "Honor", "Infamy", "AutoCombatUnlocked", "AutoCombatEnabled", "ZoneId", "ZonePvP", "HPPotionCount",
	"MPPotionCount" }
local out = {}
for _, k in keys do table.insert(out, k .. "=" .. tostring(p:GetAttribute(k))) end
local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if root then table.insert(out, string.format("pos=%.0f,%.0f,%.0f", root.Position.X, root.Position.Y, root.Position.Z)) end
local map = workspace:FindFirstChild("Map")
for _, d in (map and map:GetDescendants() or {}) do
	if d:IsA("ProximityPrompt") and d.Name == "HHC_BlacksmithPrompt" and d.Parent:IsA("BasePart") and root then
		table.insert(out, string.format("anvilDist=%.1f", ((root.Position - d.Parent.Position) * Vector3.new(1, 0, 1)).Magnitude))
		break
	end
end
return table.concat(out, " ")
"""

# client: the collector (survives between execute_luau calls in _G of the MCP client context)
COLLECT = r"""
local SS = game:GetService("SoundService")
local G = _G.HHC_SND
if not G then
	G = { rows = {}, hooked = setmetatable({}, { __mode = "k" }), t0 = os.clock() }
	_G.HHC_SND = G
end
local function stamp() return math.floor((os.clock() - G.t0) * 1000) / 1000 end
G.push = function(row) if #G.rows < 6000 then row.t = row.t or stamp(); table.insert(G.rows, row) end end
local function hook(s)
	if not s:IsA("Sound") or G.hooked[s] then return end
	G.hooked[s] = true
	s.Played:Connect(function()
		local g = s.SoundGroup
		G.push({ k = "play", n = s.Name, id = s.SoundId, v = math.floor(s.Volume * 1000) / 1000,
			sp = math.floor(s.PlaybackSpeed * 1000) / 1000, g = g and g.Name or "", gv = g and g.Volume or 1 })
	end)
end
if not G.svc then
	G.svc = true
	for _, d in SS:GetDescendants() do hook(d) end
	SS.DescendantAdded:Connect(hook)
	local ws = workspace
	for _, d in ws:GetDescendants() do if d:IsA("Sound") and not d:IsDescendantOf(game:GetService("Players")) then hook(d) end end
	ws.DescendantAdded:Connect(function(d) if d:IsA("Sound") then hook(d) end end)
end
local n = 0
for _ in G.hooked do n += 1 end
return "collector ok, hooked " .. n .. ", rows " .. #G.rows
"""
MARK = r"""
local G = _G.HHC_SND
if not G then return "no collector" end
G.push({ k = "mark", n = %s })
return "mark"
"""
DUMP = r"""
local G = _G.HHC_SND
if not G then return "[]" end
local HttpService = game:GetService("HttpService")
local from = %d
local out = {}
for i = from + 1, math.min(#G.rows, from + 400) do table.insert(out, G.rows[i]) end
return HttpService:JSONEncode(out)
"""

FIRE = r"""
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
R:WaitForChild("%s"):FireServer(%s)
return "fired %s"
"""
DISPATCH = r"""
local ps = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts")
local kb = ps:FindFirstChild("Keybinds")
local d = kb and kb:FindFirstChild("Dispatch")
if not d then return "no dispatch" end
return tostring(d:Invoke({ KeyCode = Enum.KeyCode.%s }))
"""
ANVIL_PROMPT = r"""
local map = workspace:FindFirstChild("Map")
for _, d in (map or workspace):GetDescendants() do
	if d:IsA("ProximityPrompt") and d.Name == "HHC_BlacksmithPrompt" then
		d:InputHoldBegin()
		task.wait(d.HoldDuration + 0.2)
		d:InputHoldEnd()
		return "held " .. d:GetFullName()
	end
end
return "no prompt"
"""
JUMP = r"""
local p = game:GetService("Players").LocalPlayer
local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
if not hum then return "no humanoid" end
hum.Jump = true
return "jump"
"""
# client: stand 4 studs from the nearest living monster (own tutorial slime first), facing it
NEAR_MONSTER = r"""
local p = game:GetService("Players").LocalPlayer
local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if not root then return "no root" end
local folder = workspace:FindFirstChild("Monsters")
if not folder then return "no monsters" end
local want = "%s"
local from = %s
local best, bd, bestMine = nil, math.huge, false
for _, m in folder:GetChildren() do
	if m:IsA("Model") and m:GetAttribute("Leaving") ~= true then
		local hum = m:FindFirstChildOfClass("Humanoid")
		local kind = tostring(m:GetAttribute("MonsterKind") or m.Name)
		if (hum == nil or hum.Health > 0) and (want == "" or string.find(kind, want, 1, true)) then
			local ok, pv = pcall(m.GetPivot, m)
			if ok then
				local mine = m:GetAttribute("OwnerUserId") == p.UserId
				local d = (pv.Position - (from or root.Position)).Magnitude
				if (mine and not bestMine) or (mine == bestMine and d < bd) then best, bd, bestMine = m, d, mine end
			end
		end
	end
end
if not best then return "none" end
local pos = best:GetPivot().Position
local dir = (root.Position - pos) * Vector3.new(1, 0, 1)
if dir.Magnitude < 0.5 then dir = Vector3.new(1, 0, 0) end
local stand = pos + dir.Unit * %s + Vector3.new(0, 2.5, 0)
root.CFrame = CFrame.lookAt(stand, Vector3.new(pos.X, stand.Y, pos.Z))
root.AssemblyLinearVelocity = Vector3.zero
return string.format("%%s %%s d=%%.0f mine=%%s", best.Name, tostring(best:GetAttribute("MonsterKind")), bd, tostring(bestMine))
"""
GOTO = r"""
local p = game:GetService("Players").LocalPlayer
local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if not root then return "no root" end
local target = %s
if typeof(target) ~= "Vector3" then return "no target" end
root.CFrame = CFrame.new(target + Vector3.new(0, 3, 0))
root.AssemblyLinearVelocity = Vector3.zero
return string.format("at %%.0f,%%.0f,%%.0f", target.X, target.Y, target.Z)
"""
MERCHANT = r"""(function()
	local map = workspace:FindFirstChild("Map")
	local npcs = map and map:FindFirstChild("NPCs")
	for _, m in (npcs and npcs:GetChildren() or {}) do
		if m:GetAttribute("HHC_PotionMerchant") == true and m.PrimaryPart then
			local cf = m.PrimaryPart.CFrame
			return cf.Position + cf.LookVector * 5
		end
	end
	return nil
end)()"""
GOOSE_POS = r"""(function()
	for _, d in workspace:GetDescendants() do
		if d:IsA("Model") and d.Name == "GoldenGoose" then
			local ok, pv = pcall(d.GetPivot, d)
			if ok then return pv.Position + Vector3.new(4, 0, 0) end
		end
	end
	return nil
end)()"""
GOOSE_FACE = r"""
local p = game:GetService("Players").LocalPlayer
local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
for _, d in workspace:GetDescendants() do
	if d:IsA("Model") and d.Name == "GoldenGoose" and root then
		local pos = d:GetPivot().Position
		local stand = pos + Vector3.new(4, 2.5, 0)
		root.CFrame = CFrame.lookAt(stand, Vector3.new(pos.X, stand.Y, pos.Z))
		return "facing goose"
	end
end
return "no goose"
"""
SETTINGS_SFX = r"""
local ps = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts")
return "sfx setting: " .. tostring(game:GetService("Players").LocalPlayer:GetAttribute("SettingsSfx"))
"""


def debug(c, key, value):
    v = json.dumps(value) if not isinstance(value, bool) else ("true" if value else "false")
    r = lua(c, 'local p = game:GetService("Players"):GetPlayers()[1] '
            f'return tostring(p and game.ServerScriptService.DebugCommand:Invoke(p.Name, "{key}", {v}))', "Server")
    note(f"debug {key}={value}: {r}")
    return r


def mark(c, label):
    lua(c, MARK % json.dumps(label), "Client")
    note("== " + label)


def wait_state(c, cond, timeout, every=1.0):
    t0 = time.time()
    last = ""
    while time.time() - t0 < timeout:
        last = lua(c, STATE, "Server")
        if cond(last):
            return last
        time.sleep(every)
    return last


def attr(state, key):
    for part in state.split():
        if part.startswith(key + "="):
            return part[len(key) + 1:]
    return None


def hunt(c, label, kills_key, need, seconds, want="", skill_every=0):
    """attack the nearest monster until TutorialKills (or kill count by state) reaches need, or seconds pass"""
    mark(c, label)
    t0 = time.time()
    n = 0
    while time.time() - t0 < seconds:
        where = lua(c, NEAR_MONSTER % (want, "nil", "4"), "Client")
        if n % 6 == 0:
            note("near: " + where)
        lua(c, DISPATCH % "F", "Client")
        n += 1
        if skill_every and n % skill_every == 0:
            lua(c, DISPATCH % "Q", "Client")
        time.sleep(0.55)
        if kills_key and n % 4 == 0:
            s = lua(c, STATE, "Server")
            k = attr(s, kills_key)
            if k is not None and k.isdigit() and int(k) >= need:
                note(f"{kills_key}={k} after {n} presses")
                return s
    s = lua(c, STATE, "Server")
    note(f"hunt end after {n} presses: {s}")
    return s


# server: what the world services send, sent the same way (Net.Fx = Remotes.Fx, Net.Notify = Remotes.Notify)
SRV_SEND = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local root = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if not root then return "no root" end
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local pos = root.Position + Vector3.new(%s)
%s
return "sent"
"""
SRV_GS = r"""
local gs = game:GetService("ReplicatedStorage"):WaitForChild("GameState")
local now = workspace:GetServerTimeNow()
%s
return "gamestate set"
"""
SRV_XP = r"""
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
return tostring(Config.XPToNext(%d))
"""
SRV_GOLDEN = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local root = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
local best, bd = nil, math.huge
for _, m in workspace:WaitForChild("Monsters"):GetChildren() do
	if m:IsA("Model") and m:GetAttribute("Leaving") ~= true and root then
		local d = (m:GetPivot().Position - root.Position).Magnitude
		if d < bd then best, bd = m, d end
	end
end
if not best then return "no monster" end
best:SetAttribute("Golden", true)
return string.format("golden %s d=%.0f", best.Name, bd)
"""
GROUND_TP = r"""
local p = game:GetService("Players").LocalPlayer
local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if not root then return "no root" end
local params = RaycastParams.new()
params.FilterDescendantsInstances = { p.Character }
local hit = workspace:Raycast(Vector3.new(%s, 300, %s), Vector3.new(0, -600, 0), params)
local y = hit and hit.Position.Y or 5
root.CFrame = CFrame.new(%s, y + 3, %s)
root.AssemblyLinearVelocity = Vector3.zero
return string.format("at y=%%.1f (%%s)", y, hit and hit.Instance.Name or "no ground")
"""


def world_flow(c):
    """after the first weapon: a real level-up to Lv5 (SkillLearn, the server's Q slot), the Q skill and its cooldown,
    then the world sounds sent the way their services send them (KO, GooseEnd + its reward line, Stomp, the kaiju
    alarm and its 3-2-1, the war round's last 30 s and 3-2-1, someone else's jackpot, a golden monster in view) and
    the walk into a PvP zone"""
    xp = lua(c, SRV_XP % 4, "Server")
    debug(c, "Level", 4)
    need = int(xp) if xp.isdigit() else 0
    debug(c, "XP", max(0, need - 1))
    time.sleep(1.0)
    hunt(c, "real level-up 4 -> 5 on a slime kill (LevelUp, then SkillLearn ~1.1 s)", "Level", 5, 40, "Slime")
    time.sleep(3.0)
    note("near: " + lua(c, NEAR_MONSTER % ("Slime", "nil", "5"), "Client"))
    time.sleep(2.0)
    mark(c, "skill Q after a real level-up (SkillCast + SkillHalo + hit)")
    note(lua(c, DISPATCH % "Q", "Client"))
    time.sleep(4.0)
    mark(c, "after the 3 s cooldown (SkillReady)")
    time.sleep(0.5)
    save(c, "03_skill")
    # B1: KO and back (the real death path: my humanoid at 0 on the server)
    mark(c, "KO (KO) then back (Respawn)")
    note(lua(c, 'local p = game:GetService("Players"):GetPlayers()[1] local h = p.Character and '
                'p.Character:FindFirstChildOfClass("Humanoid") if h then h.Health = 0 end return "ko"', "Server"))
    time.sleep(10.0)  # Config.Death respawn wait
    note("after respawn: " + lua(c, STATE, "Server"))
    time.sleep(1.0)
    # B3: the goose leaves 20 studs away, its reward line right after (waits 1.5 s)
    mark(c, "GooseEnd near me + reward line (GooseEnd, GoldPickup 1.5 s later)")
    note(lua(c, SRV_SEND % ("20, 0, 0", 'R.Fx:FireAllClients("GooseEnd", { Pos = pos, Winner = "Halo", Coop = false })\n'
                            'R.Notify:FireClient(p, { Text = "Goose gold!", Kind = "good", Sound = "GoldPickup" })'),
             "Server"))
    time.sleep(2.5)
    # B4: kaiju stomps 10 / 30 / 80 studs away
    for d in (10, 30, 80):
        mark(c, f"Stomp {d} studs away (KaijuStomp x{max(0, min(1, (60 - d) / 45)):.2f})")
        note(lua(c, SRV_SEND % (f"{d}, 0, 0", 'R.Fx:FireAllClients("Stomp", { UserId = 0, Pos = pos, Radius = 12 })'),
                 "Server"))
        time.sleep(1.3)
    # B5 + B7: the kaiju alarm and its 3-2-1
    mark(c, "KaijuPhase Siren, ends in 5 s (KaijuSiren, CountTick x3)")
    note(lua(c, SRV_GS % 'gs:SetAttribute("KaijuEndsAt", now + 5)\ngs:SetAttribute("KaijuPhase", "Siren")', "Server"))
    time.sleep(6.0)
    note(lua(c, SRV_GS % 'gs:SetAttribute("KaijuPhase", "None")\ngs:SetAttribute("KaijuEndsAt", 0)', "Server"))
    # B7: the war round's last 30 s, then a round that ends in 4 s (3-2-1)
    mark(c, "WarRoundEndsAt now+31 (WarFinal30 at 30 s left)")
    note(lua(c, SRV_GS % 'gs:SetAttribute("WarRoundEndsAt", now + 31)', "Server"))
    time.sleep(2.5)
    mark(c, "WarRoundEndsAt now+4 (CountTick x3)")
    note(lua(c, SRV_GS % 'gs:SetAttribute("WarRoundEndsAt", now + 4)', "Server"))
    time.sleep(5.0)
    # B10: someone else's jackpot line
    mark(c, "Announce Jackpot from someone else (JackpotOther)")
    note(lua(c, SRV_SEND % ("0, 0, 0", 'R.Announce:FireClient(p, { Key = "Jackpot", Args = { Name = "Bo", Weapon = "Iron Sword" }, '
                            'Grade = "Epic" })'), "Server"))
    time.sleep(1.5)
    # B8: a golden monster in view
    note("near: " + lua(c, NEAR_MONSTER % ("Slime", "nil", "12"), "Client"))
    time.sleep(1.0)
    mark(c, "a monster near me turns golden (GoldenSpot)")
    note(lua(c, SRV_GOLDEN, "Server"))
    time.sleep(1.5)
    save(c, "04_world")
    # B9: walk into the Goblin Woods (PvP, Lv 10+): stand outside 3.5 s, then a small step in
    debug(c, "Level", 12)
    note(lua(c, GROUND_TP % ("690", "0", "690", "0"), "Client"))
    time.sleep(4.0)
    note("outside: " + lua(c, STATE, "Server"))
    mark(c, "step into the Goblin Woods (ZoneEnterPvP)")
    note(lua(c, GROUND_TP % ("725", "0", "725", "0"), "Client"))
    time.sleep(2.5)
    note("inside: " + lua(c, STATE, "Server"))
    save(c, "05_pvp")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    os.makedirs(OUT, exist_ok=True)
    restore_studio_window()
    c = Client()
    c.start()
    rows = []
    try:
        st = text_of(c.call("get_studio_state", {}))
        if "Current Studio Mode: Edit" not in st:
            sys.exit("not in Edit: " + st)
        if MODE == "phone":
            note("device: " + lua(c, SET_PHONE, "Edit"))
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh on"', "Edit"))
        c.call("start_stop_play", {"is_start": True})
        for _ in range(40):
            r = lua(c, COLLECT, "Client")
            if r.startswith("collector ok"):
                note(r)
                break
            time.sleep(0.5)
        s = wait_state(c, lambda x: "DataLoaded=true" in x, 90, 1.0)
        note("loaded: " + s)
        note(lua(c, COLLECT, "Client"))
        mark(c, "opening (first-time intro plays)")
        time.sleep(24)
        # 1 faction / class (remotes: the button Tap itself needs a real click)
        mark(c, "ChooseFaction Halo")
        note(lua(c, FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
        wait_state(c, lambda x: "Faction=Halo" in x, 20)
        mark(c, "ChooseClass Warrior")
        note(lua(c, FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"))
        s = wait_state(c, lambda x: "ClassChosen=true" in x, 20)
        note("chosen: " + s)
        mark(c, "guide talks (TalkBlip expected)")
        time.sleep(5)
        save(c, "01_guide")
        # 4 accept -> QuestNew, the Forge walk
        mark(c, "AcceptTutorial (QuestNew expected)")
        note(lua(c, FIRE % ("AcceptTutorial", "", "AcceptTutorial"), "Client"))
        s = wait_state(c, lambda x: "anvilDist=" in x and float(attr(x, "anvilDist")) < 14, 14, 0.5)
        note("at forge: " + s)
        time.sleep(1.5)
        # 11 first weapon -> PowerUp (no QuestDone with it: server C1)
        mark(c, "anvil first weapon (PowerUp expected, no QuestDone)")
        note(lua(c, ANVIL_PROMPT, "Client"))
        s = wait_state(c, lambda x: "WeaponTier=1" in x, 10, 0.5)
        note("weapon: " + s)
        time.sleep(2.5)
        save(c, "02_first_weapon")
        if MODE == "world":
            world_flow(c)
        else:
            # 2 windows
            # (G / C / K / L / J window keys are not live: their Panels windows are not registered; M is a
            # ContextAction bind that Dispatch does not reach -> the Help window (H) is the window-key path here)
            mark(c, "help window open (WindowOpen)")
            note(lua(c, DISPATCH % "H", "Client"))
            time.sleep(1.5)
            mark(c, "help window close (WindowClose)")
            note(lua(c, DISPATCH % "H", "Client"))
            time.sleep(1.2)
            # 5 jump
            mark(c, "jump (Jump)")
            note(lua(c, JUMP, "Client"))
            time.sleep(1.5)
            # 6-8 the first mission: slimes (Swing / HitSoft / HitCrit / KillPop / ComboCoin)
            s = hunt(c, "hunt slimes (SwingWarrior, HitSoft, KillPop, ComboCoin)", "TutorialKills", 5, 75 if MODE == "pc" else 60,
                     "Slime")
            save(c, "03_hunt")
            time.sleep(1.5)
            # 9 claim -> QuestDone (+ reward lines; LevelUp overlap rule)
            lvl0 = attr(lua(c, STATE, "Server"), "Level")
            mark(c, f"ClaimQuest tutorial (QuestDone; level before {lvl0})")
            note(lua(c, FIRE % ("ClaimQuest", '"tutorial"', "ClaimQuest"), "Client"))
            time.sleep(3.0)
            s = lua(c, STATE, "Server")
            note("after claim: " + s)
            save(c, "04_claim")
            if MODE == "phone":
                # the phone run: HitSoft again on the phone screen, then Level 5 + the skill
                mark(c, "Level 5 (debug sets the stat: no LevelUp Fx; SkillLearn at the learn moment)")
                debug(c, "Level", 5)
                time.sleep(4)
                # the server's movement check refuses a cast right after a jump in position: stand still 2 s first
                note("near: " + lua(c, NEAR_MONSTER % ("Slime", "nil", "5"), "Client"))
                time.sleep(2.0)
                mark(c, "skill Q after standing still (SkillCast + SkillHalo + hit)")
                note(lua(c, DISPATCH % "Q", "Client"))
                time.sleep(4.0)  # basic skill cooldown 3 s -> SkillReady
                mark(c, "after the cooldown (SkillReady expected at ~3 s)")
                hunt(c, "phone: slimes again + Q (HitSoft on phone)", None, 0, 20, "Slime", skill_every=6)
                save(c, "05_phone_hunt")
            else:
                # 13 Level 5 -> LevelUp + SkillLearn
                mark(c, "Level 5 (LevelUp then SkillLearn ~1.1 s)")
                debug(c, "Level", 5)
                time.sleep(4)
                # 14 skill Q, ready, MP short (Deny)
                lua(c, NEAR_MONSTER % ("Slime", "nil", "4"), "Client")
                mark(c, "skill Q (SkillCast + SkillHalo + hit)")
                note(lua(c, DISPATCH % "Q", "Client"))
                time.sleep(4.0)  # basic skill cooldown 3 s -> SkillReady
                mark(c, "Mana 0 + Q (Deny)")
                debug(c, "Mana", 0)
                time.sleep(0.5)
                note(lua(c, DISPATCH % "Q", "Client"))
                time.sleep(1.5)
                # 12 potions: buy (Spend) at the merchant, drink MP (Potion)
                mark(c, "potion merchant: BuyPotion MP x1 (Spend)")
                debug(c, "Gold", 500)
                note(lua(c, GOTO % MERCHANT, "Client"))
                time.sleep(1.0)
                note(lua(c, FIRE % ("BuyPotion", '"MP", 1', "BuyPotion"), "Client"))
                time.sleep(1.5)
                mark(c, "drink MP potion (Potion)")
                note(lua(c, FIRE % ("UsePotion", '"MP"', "UsePotion"), "Client"))
                time.sleep(1.5)
                # 15 auto on / off
                debug(c, "AutoCombatUnlocked", True)
                time.sleep(0.5)
                mark(c, "auto on (AutoOn)")
                note(lua(c, DISPATCH % "R", "Client"))
                time.sleep(1.5)
                mark(c, "auto off (AutoOff)")
                note(lua(c, DISPATCH % "R", "Client"))
                time.sleep(1.5)
                # 16 faction points: Honor up (Purify), down (RankDown)
                mark(c, "Honor +40 (Purify; RankUp if a new title)")
                honor = attr(lua(c, STATE, "Server"), "Honor")
                base = int(honor) if honor and honor.isdigit() else 0
                debug(c, "Honor", base + 40)
                time.sleep(2.0)
                mark(c, "Honor -10 (RankDown)")
                debug(c, "Honor", base + 30)
                time.sleep(2.0)
                # 18 scroll: Item Enh70 + use on the tier-1 weapon (ScrollSuccess / ScrollFail)
                debug(c, "Item", "Enh70:2")
                time.sleep(0.5)
                mark(c, "UseItem Enh70 on tier 1 (ScrollSuccess / ScrollFail)")
                note(lua(c, FIRE % ("UseItem", '"Enh70", 1', "UseItem"), "Client"))
                time.sleep(2.5)
                note(lua(c, FIRE % ("UseItem", '"Enh70", 1', "UseItem"), "Client"))
                time.sleep(2.0)
                save(c, "05_scroll")
                # 19 the goose: arrive / honk / (end unwired)
                mark(c, "Goose (GooseArrive + duck)")
                debug(c, "Goose", True)
                time.sleep(3.0)
                note(lua(c, GOTO % GOOSE_POS, "Client"))
                time.sleep(0.8)
                mark(c, "hit the goose (GooseHonk)")
                for _ in range(4):
                    lua(c, GOOSE_FACE, "Client")
                    lua(c, DISPATCH % "F", "Client")
                    time.sleep(0.6)
                save(c, "06_goose")
                # 20 kings appear
                mark(c, "PumpkinKing appears (PumpkinKing + duck)")
                debug(c, "PumpkinKing", True)
                time.sleep(3.0)
                mark(c, "GhostKing appears (GhostKing)")
                debug(c, "GhostKing", True)
                time.sleep(3.0)
                # 25 jackpot announce (JackpotOther: not wired yet)
                mark(c, "Announce Jackpot:8 (JackpotOther)")
                debug(c, "Announce", "Jackpot:8")
                time.sleep(3.0)
                save(c, "07_events")
        mark(c, "end")
        time.sleep(0.5)
        # collect everything
        start = 0
        while True:
            raw = lua(c, DUMP % start, "Client")
            try:
                part = json.loads(raw)
            except Exception:  # noqa: BLE001
                note("dump parse failed: " + raw[:200])
                break
            rows.extend(part)
            if len(part) < 400:
                break
            start += len(part)
        note(f"rows: {len(rows)}")
        con = text_of(c.call("get_console_output", {}))
        errs = [ln for ln in con.splitlines() if any(k in ln.lower() for k in ("error", "failed", "warn", "infinite yield"))]
        note("console: " + "\n".join(errs[-30:]))
        with open(os.path.join(OUT, "console.txt"), "w", encoding="utf-8") as f:
            f.write(con)
    finally:
        try:
            c.call("start_stop_play", {"is_start": False})
            note("play stopped")
        except Exception as e:  # noqa: BLE001
            note("stop failed " + str(e))
        time.sleep(2)
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", nil) return "fresh off"', "Edit"))
        note("device: " + lua(c, RESTORE, "Edit"))
        with open(os.path.join(OUT, "sounds.json"), "w", encoding="utf-8") as f:
            json.dump(rows, f, ensure_ascii=False, indent=1)
        with open(os.path.join(OUT, "log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")
        c.close()


if __name__ == "__main__":
    main()
