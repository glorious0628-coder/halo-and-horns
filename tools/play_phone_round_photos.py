"""A23-145 phone round prep (게임성 개발 1, 2026-10-13): phone photos + an automatic screen audit in the MAIN Studio
(메인 반영 1 only, HH_MAIN_STUDIO=1; own test Play with a FRESH in-memory save; no mouse / keyboard input; the device
emulation is put back to default at the end, even after an error). The private test 10/17~20 has the user's phone too
and the last phone photos were 10/07 (since then: the Monster Codex, the Hero window, the Tool hold, the Goose Square,
stickers ...).
Per device (749x361 Galaxy S22 Ultra, 844x390 iPhone 13), Halo Warrior, the tutorial's first claim done:
  hud_lv1, hud_lv25 (Q / the auto button), then every window that opens (server OpenPanel): Bag, Character, Skills, Pet,
  Journal, Codex, Settings, Help, News, Shop, Travel, Ranking (a window that does not open is logged, no photo).
For every shot <dev>_<name>.json lists, over what is on screen (every ancestor shown):
  cut  = a text whose words do not fit (TextFits false) - name, text, box px;
  small = a button whose pressable area (with its UIKit.TapPad strips) is under 44 px on a side (a finger);
  off  = a button / text partly off the screen;
  overlap = two buttons that cover each other (not one inside the other);
  tiny = a one-line text drawn under 17 real px (phone floor 19 px; finder only - judge by the photo);
  english = (10/15) a drawn text (LocalizedText) with English words of 3+ letters (Lv / HP / MP / XP / PvP / VIP /
  KO / Robux / MAX / 'Halo & Horns' allowed) - all of them gathered in english_words.json (run it in Korean).
Usage: HH_MAIN_STUDIO=1 py tools/play_phone_round_photos.py [phone] [844]   (default both)
Out: docs/art/verification_2026-10-13/phone_round/<dev>_<name>.png / .json, summary.txt, log.txt

A23-160 ③ (10/13 evening, the private test's first 10 minutes on a phone): `... play_phone_round_photos.py first10
[phone] [844] [out=<dir>]` walks the first minutes instead - the opening (Skip), the faction picker, the class picker, the guide's
welcome, the HUD after the first mission, the Forge, the Potion Shop, the attendance board (Gifts), the Bag, the Lv 5
moment (the first skill) - same audit per shot. Out: docs/art/verification_2026-10-14/phone_first10/."""
import base64
import io
import json
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402
from PIL import Image  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-13", "phone_round")
OUT_FIRST10 = os.path.join(ROOT, "docs", "art", "verification_2026-10-14", "phone_first10")
LOG = []
DEVICES = {"phone": ("samsung_galaxy_s22_ultra", 749, 361), "844": ("iphone_13", 844, 390)}
WINDOWS = ["Bag", "Character", "Skills", "Pet", "Journal", "Codex", "Settings", "Help", "News", "Shop", "Travel", "Ranking"]


def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))


def lua(c, code, dm):
    try:
        return text_of(c.call("execute_luau", {"code": code, "datamodel_type": dm}))
    except Exception as e:  # noqa: BLE001
        return "ERR " + str(e)[:200]


def note(m):
    print(m, flush=True)
    LOG.append(m)


def save(c, name):
    res = c.call("screen_capture", {"capture_id": name})
    for part in res.get("content", []):
        if part.get("type") == "image":
            Image.open(io.BytesIO(base64.b64decode(part["data"]))).convert("RGB").save(os.path.join(OUT, name + ".png"))
            note("saved " + name)
            return
    note("capture failed " + name)


SET_DEVICE = r'''
local svc = game:GetService("StudioDeviceSimulatorService")
svc:SetDeviceAsync("%s")
task.wait(0.3)
svc:SetResolutionAsync(%d, %d)
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
STATE = r'''
local p = game:GetService("Players"):GetPlayers()[1]
if not p then return "no player" end
local out = {}
for _, k in { "DataLoaded", "Faction", "Class", "ClassChosen", "Level", "TutorialStep" } do table.insert(out, k .. "=" .. tostring(p:GetAttribute(k))) end
return table.concat(out, " ")
'''
FIRE = r'''
game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("%s"):FireServer(%s)
return "fired %s"
'''
DEBUG = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local fn = game:GetService("ServerScriptService"):FindFirstChild("DebugCommand")
if not (p and fn) then return "no player / DebugCommand" end
local out = {}
for _, kv in { %s } do
	local ok, r = pcall(function() return fn:Invoke(p.Name, kv[1], kv[2]) end)
	table.insert(out, kv[1] .. "=" .. tostring(ok and r or ("ERR " .. tostring(r))))
end
return table.concat(out, " ")
'''
CLAIMED = r'''
local p = game:GetService("Players"):GetPlayers()[1]
p:SetAttribute("TutorialStep", 99)
return "TutorialStep " .. tostring(p:GetAttribute("TutorialStep"))
'''
OPEN = r'''
local p = game:GetService("Players"):GetPlayers()[1]
game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("OpenPanel"):FireClient(p, "%s")
return "open %s"
'''
OPENED = r'''
local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
for _, d in pg:GetDescendants() do
	if d.Name == "PanelsModal" and d:IsA("GuiObject") then return tostring(d.Visible) end
end
return "none"
'''
CLOSE = r'''
local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
for _, d in pg:GetDescendants() do
	if d.Name == "PanelsModal" and d:IsA("GuiObject") then d.Visible = false end
end
return "closed"
'''
# what is on screen: cut words, small / off-screen / overlapping buttons (real px)
AUDIT = r'''
local HttpService = game:GetService("HttpService")
local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
local cam = workspace.CurrentCamera
local vw, vh = cam.ViewportSize.X, cam.ViewportSize.Y
local inset = game:GetService("GuiService"):GetGuiInset()
local function shown(o)
	local p = o
	while p and p ~= pg do
		if p:IsA("GuiObject") and not p.Visible then return false end
		if p:IsA("LayerCollector") and not p.Enabled then return false end
		p = p.Parent
	end
	return true
end
local function box(o)
	local gui = o:FindFirstAncestorWhichIsA("ScreenGui")
	local y0 = (gui and gui.IgnoreGuiInset) and 0 or inset.Y
	local p, s = o.AbsolutePosition, o.AbsoluteSize
	return { math.floor(p.X), math.floor(p.Y + y0), math.floor(s.X), math.floor(s.Y) }
end
local TINY = 17
local out = { view = { vw, vh }, cut = {}, small = {}, off = {}, overlap = {}, tiny = {}, english = {} }
-- 최종 검수 10/15 (Korean client: 'Paladin / Light Mage / Ranger' stayed English): the English words on screen, by what
-- is DRAWN (LocalizedText = after Roblox's translation; rich-text tags out). A word = 3+ letters; the game's own short
-- words / names are allowed (ENG_OK)
local ENG_OK = { Lv = true, HP = true, MP = true, XP = true, PvP = true, VIP = true, KO = true, Robux = true, MAX = true }
local function englishWords(t)
	t = string.gsub(t, "<[^>]->", "")
	t = string.gsub(t, "Halo & Horns", "")
	local words = {}
	for w in string.gmatch(t, "%a+") do
		if #w >= 3 and not ENG_OK[w] and not string.find(w, "[^%w]") then table.insert(words, w) end
	end
	return words
end
local buttons = {}
for _, d in pg:GetDescendants() do
	if d:IsA("GuiObject") and shown(d) and (d.BackgroundTransparency < 1 or d:IsA("TextLabel") or d:IsA("TextButton")
		or d:IsA("ImageLabel") or d:IsA("ImageButton") or d:IsA("ViewportFrame")) then
		local b = box(d)
		if b[3] > 2 and b[4] > 2 then
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and d.TextTransparency < 0.95 and d.TextFits == false then
				table.insert(out.cut, { d:GetFullName():gsub("^.-PlayerGui%.", ""), d.Text, b })
			end
			if (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) and d.TextTransparency < 0.95 then
				local okL, drawn = pcall(function() return d.LocalizedText end)
				local t = (okL and type(drawn) == "string" and drawn ~= "") and drawn or d.Text
				if t ~= "" then
					local words = englishWords(t)
					if #words > 0 then
						table.insert(out.english, { d:GetFullName():gsub("^.-PlayerGui%.", ""), t, words, d.AutoLocalize })
					end
				end
			end
			-- tiny = words drawn under TINY real px (the phone floor is 19; a line box ~ the text size). TextBounds is
			-- already screen px (10/14 photos: multiplying by the UIScales again listed "Bag" as 9 px - it reads ~12)
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and d.TextTransparency < 0.95 and d.TextBounds.Y > 0 then
				local h = d.TextBounds.Y
				if h < TINY then
					table.insert(out.tiny, { d:GetFullName():gsub("^.-PlayerGui%.", ""), d.Text, b, math.floor(h * 10) / 10 })
				end
			end
			if d:IsA("GuiButton") and d.Active ~= false and string.sub(d.Name, 1, 6) ~= "TapPad" then
				table.insert(buttons, { d, b })
				-- the pressable size = the button + its UIKit.TapPad strips (A23-160: touch-only invisible strips)
				local x0, y0, x1, y1 = b[1], b[2], b[1] + b[3], b[2] + b[4]
				for _, ch in d:GetChildren() do
					if ch:IsA("GuiButton") and ch.Visible and string.sub(ch.Name, 1, 6) == "TapPad" then
						local cb = box(ch)
						x0, y0 = math.min(x0, cb[1]), math.min(y0, cb[2])
						x1, y1 = math.max(x1, cb[1] + cb[3]), math.max(y1, cb[2] + cb[4])
					end
				end
				if math.min(x1 - x0, y1 - y0) < 44 - 0.5 then
					table.insert(out.small, { d:GetFullName():gsub("^.-PlayerGui%.", ""), b, { x0, y0, x1 - x0, y1 - y0 } })
				end
			end
			if (d:IsA("GuiButton") or d:IsA("TextLabel")) and string.sub(d.Name, 1, 6) ~= "TapPad" and (b[1] < 0 or b[2] < 0 or b[1] + b[3] > vw + 1 or b[2] + b[4] > vh + 1) then
				table.insert(out.off, { d:GetFullName():gsub("^.-PlayerGui%.", ""), b })
			end
		end
	end
end
for i = 1, #buttons do
	for j = i + 1, #buttons do
		local a, c = buttons[i], buttons[j]
		if not a[1]:IsDescendantOf(c[1]) and not c[1]:IsDescendantOf(a[1]) then
			local A, B = a[2], c[2]
			local w = math.min(A[1] + A[3], B[1] + B[3]) - math.max(A[1], B[1])
			local h = math.min(A[2] + A[4], B[2] + B[4]) - math.max(A[2], B[2])
			if w > 4 and h > 4 and #out.overlap < 40 then
				table.insert(out.overlap, { a[1].Name, c[1].Name, A, B })
			end
		end
	end
end
return HttpService:JSONEncode(out)
'''


def wait_state(c, cond, timeout, every=1.0):
    t0, last = time.time(), ""
    while time.time() - t0 < timeout:
        last = lua(c, STATE, "Server")
        if cond(last):
            return last
        time.sleep(every)
    return last


SUMMARY = []
ENGLISH = {}  # 10/15: word -> where it showed (english_words.json)


def audit(c, name):
    raw = lua(c, AUDIT, "Client")
    try:
        data = json.loads(raw)
    except ValueError:
        note(f"audit {name} failed: {raw[:200]}")
        return
    with open(os.path.join(OUT, name + ".json"), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    line = (f"{name}: cut {len(data['cut'])}, small {len(data['small'])}, off {len(data['off'])}, overlap {len(data['overlap'])}, "
            f"tiny {len(data.get('tiny', []))}, english {len(data.get('english', []))}")
    for item in data.get("english", []):
        for w in item[2]:
            ENGLISH.setdefault(w, []).append({"shot": name, "path": item[0], "text": item[1], "autoLocalize": item[3]})
    note(line)
    SUMMARY.append(line)
    for item in data["cut"][:8]:
        SUMMARY.append(f"    cut: {item[0]} = {item[1]!r} {item[2]}")
    for item in data.get("tiny", [])[:8]:
        SUMMARY.append(f"    tiny: {item[0]} = {item[1]!r} {item[3]} px")


def shot(c, name):
    time.sleep(1.2)
    save(c, name)
    audit(c, name)


def run_device(c, dev):
    device, w, h = DEVICES[dev]
    note(f"== {dev}: " + lua(c, SET_DEVICE % (device, w, h), "Edit"))
    note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh on"', "Edit"))
    c.call("start_stop_play", {"is_start": True})
    note("loaded: " + wait_state(c, lambda x: "DataLoaded=true" in x, 90, 2.0))
    time.sleep(20)
    note(lua(c, FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
    wait_state(c, lambda x: "Faction=Halo" in x, 20)
    note(lua(c, FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"))
    note("chosen: " + wait_state(c, lambda x: "ClassChosen=true" in x, 20))
    note(lua(c, FIRE % ("AcceptTutorial", "", "AcceptTutorial"), "Client"))
    time.sleep(3)
    note(lua(c, CLAIMED, "Server"))
    shot(c, f"{dev}_hud_lv1")
    note("lv25: " + lua(c, DEBUG % '{ "Level", 25 }, { "WeaponOwnedMask", 511 }', "Server"))
    time.sleep(2)
    shot(c, f"{dev}_hud_lv25")
    for win in WINDOWS:
        note(lua(c, OPEN % (win, win), "Server"))
        time.sleep(1.5)
        if lua(c, OPENED, "Client") != "true":
            note(f"{win}: did not open")
            continue
        shot(c, f"{dev}_win_{win.lower()}")
        note(lua(c, CLOSE, "Client"))
        time.sleep(0.6)


def open_shot(c, win, name):
    note(lua(c, OPEN % (win, win), "Server"))
    time.sleep(1.5)
    if lua(c, OPENED, "Client") != "true":
        note(f"{win}: did not open")
        return
    shot(c, name)
    note(lua(c, CLOSE, "Client"))
    time.sleep(0.6)


def run_first10(c, dev):
    """A23-160 ③: the first minutes in the order a new player sees them (fresh save, no mouse / keyboard)."""
    device, w, h = DEVICES[dev]
    note(f"== first10 {dev}: " + lua(c, SET_DEVICE % (device, w, h), "Edit"))
    note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh on"', "Edit"))
    c.call("start_stop_play", {"is_start": True})
    note("loaded: " + wait_state(c, lambda x: "DataLoaded=true" in x, 90, 2.0))
    time.sleep(6)
    shot(c, f"{dev}_f10_01_intro")
    note(lua(c, FIRE % ("IntroSeen", "", "IntroSeen"), "Client"))
    time.sleep(4)
    shot(c, f"{dev}_f10_02_faction")
    note(lua(c, FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
    wait_state(c, lambda x: "Faction=Halo" in x, 20)
    time.sleep(2.5)
    shot(c, f"{dev}_f10_03_class")
    note(lua(c, FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"))
    note("chosen: " + wait_state(c, lambda x: "ClassChosen=true" in x, 20))
    time.sleep(2.5)
    shot(c, f"{dev}_f10_04_welcome")
    note(lua(c, FIRE % ("AcceptTutorial", "", "AcceptTutorial"), "Client"))
    time.sleep(3)
    shot(c, f"{dev}_f10_05_first_mission")
    note(lua(c, CLAIMED, "Server"))
    time.sleep(2)
    shot(c, f"{dev}_f10_06_hud")
    open_shot(c, "WeaponShop", f"{dev}_f10_07_forge")
    open_shot(c, "PotionShop", f"{dev}_f10_08_potions")
    open_shot(c, "Attendance", f"{dev}_f10_09_gifts")
    open_shot(c, "Bag", f"{dev}_f10_10_bag")
    note("lv5: " + lua(c, DEBUG % '{ "Level", 5 }', "Server"))
    time.sleep(2.5)
    shot(c, f"{dev}_f10_11_lv5")


def main():
    global OUT
    sys.stdout.reconfigure(encoding="utf-8")
    first10 = "first10" in sys.argv[1:]
    if first10:
        OUT = OUT_FIRST10
    # 10/15: out=<dir> (relative to the repo) keeps older evidence - a new dated folder instead of overwriting
    for a in sys.argv[1:]:
        if a.startswith("out="):
            OUT = os.path.join(ROOT, a[4:])
    os.makedirs(OUT, exist_ok=True)
    want = [a for a in sys.argv[1:] if a in DEVICES] or list(DEVICES)
    c = Client()
    c.start()
    try:
        st = text_of(c.call("get_studio_state", {}))
        if "Current Studio Mode: Edit" not in st:
            sys.exit("not in Edit: " + st)
        for dev in want:
            try:
                (run_first10 if first10 else run_device)(c, dev)
            finally:
                try:
                    c.call("start_stop_play", {"is_start": False})
                    note("play stopped")
                except Exception as e:  # noqa: BLE001
                    note("stop failed " + str(e))
                time.sleep(3)
    finally:
        note("device: " + lua(c, RESTORE, "Edit"))
        with open(os.path.join(OUT, "log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")
        with open(os.path.join(OUT, "summary.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(SUMMARY) + "\n")
        # 10/15: every English word drawn on the screens, most places first (the run should be in Korean)
        words = sorted(ENGLISH.items(), key=lambda kv: (-len(kv[1]), kv[0]))
        with open(os.path.join(OUT, "english_words.json"), "w", encoding="utf-8") as f:
            json.dump({"words": len(words), "list": [{"word": w, "count": len(v), "where": v[:12]} for w, v in words]},
                      f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
