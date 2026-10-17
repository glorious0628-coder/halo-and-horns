"""A23-229 NPC dialogue box (DialogBox.luau, plan docs/design/dialog_box_plan_2026-10-18.md), offline.

Runs the CURRENT Config.luau and DialogBox.luau in the official Luau CLI on small doubles (an Instance tree with signals,
UIKit's InkText / Portrait / ArtFrame / Typewriter, a Panels.DialogKit with buttons that record presses).
Checks: the speaker of a line ("Bright: ..." with a known speaker switches face and name, an unknown 'Note:' stays the
card's own words, Otto -> Smith, Hallie -> Halo, Kit -> Guild); Plan pages ([Next] until the last line, the final
buttons on the last - or on every line with FinalAlways); Show builds the bottom box (no cover, the plate, the face
column with the name under it, [Bye] left, [Next] / the final buttons right); a press while the line types only shows
it whole; [Next] pages; the final button runs its OnPress only on the last line; [Bye] hides it and runs OnBye; the same
Key again keeps the page; SetFinal changes the words / state; Hide clears it.
Static: Panels draws Story / Offer / Welcome in the box (render's dialogue branch, no modal), Panels.Close hides it,
STORY.StoryDialog / OfferDialog / WELCOME.Dialog send the same remotes as the windows, ClientMain loads DialogBox after
Panels, the only new word is Config.ClientText.DialogBox.Bye. Mutations: each must be caught.
Usage: py tools/test_dialog_box.py
"""
from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = {"BOX": ROOT / "src/StarterPlayer/StarterPlayerScripts/DialogBox.luau",
         "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
         "PANELS": ROOT / "src/StarterPlayer/StarterPlayerScripts/Panels.luau",
         "MAIN": ROOT / "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else
		failed += 1
		print("CHECK_FAIL " .. name .. (detail ~= nil and (" :: " .. tostring(detail)) or ""))
	end
end
local function signal()
	local s = { Fns = {} }
	function s:Connect(fn) table.insert(self.Fns, fn) return { Disconnect = function() end } end
	function s:Fire(...) for _, fn in self.Fns do fn(...) end end
	return s
end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local function vec(x, y, z) return { X = x or 0, Y = y or 0, Z = z or 0 } end
local base = { Vector3 = { new = vec, zero = vec() }, Vector2 = { new = vec }, Color3 = { new = vec, fromRGB = vec, fromHSV = vec },
	BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), UDim2 = ctor("UDim2"), UDim = ctor("UDim"),
	NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"),
	NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"), ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"),
	CFrame = ctor("CFrame"), TweenInfo = ctor("TweenInfo"), Font = ctor("Font"), Enum = enum }
local cfgEnv = setmetatable(table.clone(base), { __index = getfenv() })
cfgEnv.workspace = { GetServerTimeNow = function() return 1790000000 end }
local cf = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cf, cfgEnv)
local Config = cf()

local omt = {}
local function obj(class, props)
	local o = setmetatable({ __p = { ClassName = class, Name = class, Children = {}, Attrs = {}, Visible = true } }, omt)
	for k, v in props or {} do o[k] = v end
	return o
end
local M = {}
function M.GetChildren(self) return table.clone(rawget(self, "__p").Children) end
function M.FindFirstChild(self, n, deep)
	for _, ch in rawget(self, "__p").Children do
		if ch.Name == n then return ch end
		if deep then local d = ch:FindFirstChild(n, true) if d then return d end end
	end
	return nil
end
function M.IsA(self, c) local k = rawget(self, "__p").ClassName return k == c or c == "Instance" or (c == "GuiButton" and (k == "TextButton" or k == "ImageButton")) or (c == "BasePart" and k == "Part") end
function M.Destroy(self)
	local p = rawget(self, "__p")
	if p.Parent then local i = table.find(rawget(p.Parent, "__p").Children, self) if i then table.remove(rawget(p.Parent, "__p").Children, i) end end
	p.Parent = nil
	p.Destroyed = true
end
function M.GetAttribute(self, k) return rawget(self, "__p").Attrs[k] end
function M.SetAttribute(self, k, v) rawget(self, "__p").Attrs[k] = v end
omt.__index = function(o, k)
	if M[k] then return M[k] end
	local p = rawget(o, "__p")
	if k == "Activated" or k == "MouseButton1Click" then p[k] = p[k] or signal() return p[k] end
	return p[k]
end
omt.__newindex = function(o, k, v)
	local p = rawget(o, "__p")
	if k == "Parent" then
		if p.Parent then local i = table.find(rawget(p.Parent, "__p").Children, o) if i then table.remove(rawget(p.Parent, "__p").Children, i) end end
		p.Parent = v
		if v then table.insert(rawget(v, "__p").Children, o) end
		return
	end
	p[k] = v
end

local GUI = obj("ScreenGui", { Name = "MainGui" })
local typing = {} -- [label] = handle
local UIKit = { Gui = GUI,
	InkText = function(p)
		local l = obj("TextLabel")
		for k, v in p do if k ~= "Parent" and k ~= "TextColor" and k ~= "Title" then l[k] = v end end
		l.Parent = p.Parent
		return l
	end,
	Portrait = function(key, p)
		local h = obj("Frame", { Name = p.Name, Art = key, Initial = p.Initial })
		h.Parent = p.Parent
		return h
	end,
	ArtFrame = function(name, p) local f = obj("ImageLabel", { Name = p.Name, Art = name }) f.Parent = p.Parent return f end,
	ArtPart = function(k) return (k == "PTR_TownBright" or k == "PortraitGuideHalo") and {} or nil end,
	Typewriter = function(label, text, opts)
		label.Text = text
		label.Speaker = opts and opts.Speaker
		local h = { done = false }
		h.Done = function() return h.done end
		h.Finish = function() h.done = true end
		typing[label] = h
		return h
	end,
}
local pressed = {}
local function button(parent, text, color, size, onClick)
	local b = obj("TextButton", { Text = text, Color = color })
	b.Activated:Connect(function() onClick() end)
	b.Parent = parent
	return b
end
local Panels = { DialogKit = function()
	return { Button = button, ChoiceButton = function(parent, side, text, size, onClick)
		local b = button(parent, text, side, size, onClick)
		b.Side = side
		return b
	end, RewardRow = function(parent, list, look)
		local r = obj("Frame", { Name = "OfferReward", N = #list })
		r.Parent = parent
		return r
	end, Palette = { Free = "free", Button = "button" }, SetEnabled = function(b, on) b:SetAttribute("Disabled", not on) end }
end }
local RS = { Heartbeat = signal() }
local UIS = { InputBegan = signal() }
local ME = { Character = nil }
local env = setmetatable(table.clone(base), { __index = getfenv() })
env.game = { GetService = function(_, n)
	if n == "Players" then return { LocalPlayer = ME } end
	if n == "ReplicatedStorage" then return { WaitForChild = function() return { WaitForChild = function(_, m) return m end } end } end
	if n == "RunService" then return RS end
	if n == "UserInputService" then return UIS end
	return {}
end }
env.require = function(m)
	if m == "Config" then return Config end
	return { Warn = function(...) print("WARN", ...) end }
end
env.Instance = { new = function(c) return obj(c) end }
env.typeof = function(v) if type(v) == "table" and rawget(v, "__p") then return "Instance" end return typeof(v) end
local f = assert(loadstring(BOX_SOURCE, "=DialogBox"))
setfenv(f, env)
local Box = f()
Box.Init({ UIKit = UIKit, Panels = Panels })
Box.Start()

-- pure: speakers
local s = Box.Speaker("Bright: Look at this!", "Smith", nil)
check(s.Voice == "Bright" and s.Name == "Bright" and s.Text == "Look at this!", "a known speaker's line: her face, her name, the rest", s.Text)
s = Box.Speaker("Note: this is not a speaker", "Smith", nil)
check(s.Voice == "Smith" and s.Text == "Note: this is not a speaker" and s.Name == "Otto", "an unknown 'Note:' = the card's own words (Otto)", s.Name)
check(Box.VoiceOf("Otto") == "Smith" and Box.VoiceOf("Hallie") == "Halo" and Box.VoiceOf("Kit") == "Guild"
	and Box.VoiceOf("Nobody") == nil, "voices: Otto -> Smith, Hallie -> Halo, Kit -> Guild, unknown -> nil")
local p = Box.Plan({ Lines = { "a", "b" } }, 1)
check(p.Next and not p.Final and not p.Last, "line 1 of 2: [Next], no final buttons")
p = Box.Plan({ Lines = { "a", "b" } }, 2)
check(not p.Next and p.Final and p.Last, "the last line: the final buttons")
check(Box.Plan({ Lines = { "a", "b" }, FinalAlways = true }, 1).Final == true, "FinalAlways: the final buttons on every line")

-- the box
local okPress, byes = 0, 0
local spec = { Key = "Story|M1_1|2", Voice = "Smith", Lines = { "Otto: Hammer time.", "Bright: Me next!", "Otto: Done." },
	Hint = "Honor +5", Final = { { Text = "Got it", Style = "Free", Name = "StoryOk", OnPress = function() okPress += 1 end } },
	OnBye = function() byes += 1 end }
check(Box.Show(spec) == true and Box.IsOpen(), "Show opens the box")
local root = GUI:FindFirstChild("DialogBox")
check(root ~= nil and root.AnchorPoint ~= nil and GUI:FindFirstChild("Cover") == nil, "the box sits in MainGui (no dark cover)")
local plate = root:FindFirstChild("Plate")
check(plate and plate.Art == "DialogBox", "the plate is the approved DialogBox art")
local left, right = root:FindFirstChild("Left"), root:FindFirstChild("Right")
local face, name = left:FindFirstChild("Face"), left:FindFirstChild("SpeakerName")
check(face and face.Art == "PortraitMerchantC" or (face and face.Art == nil), "line 1: Otto's face (his portrait key or the initial)", face and face.Art)
check(name and name.Text == "Otto", "the name under the face: Otto", name and name.Text)
local line = right:FindFirstChild("Line")
check(line.Text == "Hammer time." and line.Speaker == "Smith", "the line without 'Otto:', typed in his voice", line.Text)
local bar = root:FindFirstChild("Bar")
local nextBtn = bar:FindFirstChild("Buttons"):FindFirstChild("DialogNext")
local okBtn = bar:FindFirstChild("Buttons"):FindFirstChild("StoryOk")
local bye = bar:FindFirstChild("DialogBye")
check(nextBtn and nextBtn.Visible and okBtn and okBtn.Visible == false and bye, "[Next] right, the final hidden until the last line, [Bye] left")
check(right:FindFirstChild("Hint").Visible == false, "the choice hint waits for the last line")
nextBtn.Activated:Fire()
check(line.Text == "Hammer time.", "a press while the line types only shows it whole")
nextBtn.Activated:Fire()
check(line.Text == "Me next!" and name.Text == "Bright" and left:FindFirstChild("Face").Art == "PTR_TownBright",
	"[Next]: line 2 is Bright's - her face and name", name.Text)
typing[line].done = true
okBtn.Activated:Fire()
check(okPress == 0, "the final button does nothing before the last line")
nextBtn.Activated:Fire()
typing[line].done = true
check(line.Text == "Done." and okBtn.Visible and nextBtn.Visible == false and right:FindFirstChild("Hint").Visible,
	"the last line: [Got it] (+ the hint), no [Next]")
-- the same Key again (Panels' refresh) keeps the page
Box.Show(spec)
check(Box._T.S.Page == 3, "the same talk again keeps its page", Box._T.S.Page)
okBtn = root:FindFirstChild("Bar"):FindFirstChild("Buttons"):FindFirstChild("StoryOk")
typing[line].done = true
okBtn.Activated:Fire()
check(okPress == 1, "[Got it] on the last line runs its press once")
-- Enter = the one final button on the last line
UIS.InputBegan:Fire({ KeyCode = "KeyCode.Return" }, false)
check(okPress == 2, "Enter on the last line = the one final button")
bye.Activated:Fire()
check(byes == 1 and not Box.IsOpen() and GUI:FindFirstChild("DialogBox") == nil, "[Bye]: the box goes, OnBye runs")
-- a choice: two buttons, Enter never picks
local picks = {}
Box.Show({ Key = "c", Voice = "Halo", Lines = { "Pick one." }, Final = {
	{ Text = "Help", Style = "Good", Name = "StoryChoiceGood", OnPress = function() table.insert(picks, "Good") end },
	{ Text = "Prank", Style = "Evil", Name = "StoryChoiceEvil", OnPress = function() table.insert(picks, "Evil") end } } })
root = GUI:FindFirstChild("DialogBox")
local good = root:FindFirstChild("Bar"):FindFirstChild("Buttons"):FindFirstChild("StoryChoiceGood")
check(good and good.Side == "Good" and good.Visible, "a choice: the kind / sneaky art buttons")
line = root:FindFirstChild("Right"):FindFirstChild("Line")
typing[line].done = true
UIS.InputBegan:Fire({ KeyCode = "KeyCode.Return" }, false)
check(#picks == 0, "Enter never picks a side")
good.Activated:Fire()
check(picks[1] == "Good", "a press picks")
-- an Offer: the reward row on the last line; Welcome: SetFinal
Box.Show({ Key = "o", Voice = "Tiny", Name = "Tiny", Lines = { "a", "b" }, Before = "Something is up.",
	Reward = { List = { { Icon = "IconCoin", N = 50 } } }, Final = { { Text = "Sure!", Style = "Free", Name = "OfferAccept", OnPress = function() end } } })
root = GUI:FindFirstChild("DialogBox")
local reward = root:FindFirstChild("Right"):FindFirstChild("OfferReward")
check(reward and reward.Visible == false and root:FindFirstChild("Right"):FindFirstChild("Before").Text == "Something is up.",
	"an Offer: the situation line on top, the reward row waits for the last line")
Box.SetFinal(1, { Text = "Joining...", Enabled = false })
local acc = root:FindFirstChild("Bar"):FindFirstChild("Buttons"):FindFirstChild("OfferAccept")
check(acc.Text == "Joining..." and acc:GetAttribute("Disabled") == true, "SetFinal: words and state")
Box.Hide()
check(not Box.IsOpen() and GUI:FindFirstChild("DialogBox") == nil, "Hide clears it")
print(("DIALOG_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

STATIC = [
    ("Panels: Story / Offer / Welcome draw in the box (render's dialogue branch, no modal)", "PANELS",
     ["STORY.Dialog = { Story = true, Offer = true, Welcome = true }",
      "\tif STORY.Dialog[currentId] and STORY.Box() then\n\t\troot.Visible = false"]),
    ("Panels.Close hides the box", "PANELS", ["if STORY.Dialog[currentId] and STORY.Box() then pcall(STORY.Box().Hide) end"]),
    ("the box sends the same remotes as the windows", "PANELS",
     ['fire("StoryAction", arg.Id, "Talk")', 'fire("StoryAction", arg.Id, "Choose", option)', 'fire("StoryAction", arg.Id, what)',
      'fire("AcceptTutorial") -- exact zero arguments']),
    ("ClientMain loads DialogBox right after Panels", "MAIN", ['"Panels", "DialogBox",']),
    ("the only new word: Config.ClientText.DialogBox.Bye", "CONFIG", ['Config.ClientText.DialogBox = { Bye = "Bye" }']),
]

MUTATIONS = [
    ("BOX", "the speaker prefix never read", "\tif v then return { Voice = v, Name = who, Text = rest } end\n", ""),
    ("BOX", "a press while typing pages on", "\tif finishTyping() then return true end\n\tlocal v = DialogBox.Plan(spec, S.Page)", "\tlocal v = DialogBox.Plan(spec, S.Page)"),
    ("BOX", "the final button before the last line", "if not (f and v.Final and b and b.Visible)", "if not (f and b)"),
    ("BOX", "Bye keeps the box", "\t\tlocal fn = spec.OnBye\n\t\tDialogBox.Hide()\n", "\t\tlocal fn = spec.OnBye\n"),
    ("BOX", "a refresh rewinds", "if S.Spec and S.View and S.Spec.Key ~= nil and S.Spec.Key == spec.Key then", "if false then"),
    ("BOX", "Enter picks a side", "\telseif #S.Final == 1 then\n", "\telseif #S.Final >= 1 then\n"),
    ("BOX", "the hint always on", "\tif view.Hint then view.Hint.Visible = v.Last end\n", ""),
    ("PANELS", "the modal window again", "\tif STORY.Dialog[currentId] and STORY.Box() then\n\t\troot.Visible = false", "\tif false then\n\t\troot.Visible = false"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(src: dict[str, str]) -> tuple[bool, str]:
    text = "local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal BOX_SOURCE = " + lua_str(src["BOX"]) + "\n" + FIXTURE
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as fh:
        fh.write(text)
        path = fh.name
    r = subprocess.run([str(BINARY), path], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
    out = r.stdout + r.stderr
    m = re.search(r"DIALOG_SUMMARY checks=(\d+) failed=(\d+)", out)
    return (r.returncode == 0 and m is not None and m.group(2) == "0"), out


def statics(src: dict[str, str]) -> list[tuple[str, bool]]:
    return [(name, all(n in src[key] for n in needles)) for name, key, needles in STATIC]


def main() -> int:
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    ok, out = run(src)
    for line in out.splitlines():
        if line.startswith(("CHECK_", "WARN", "DIALOG_SUMMARY")) or "error" in line.lower():
            print(line)
    st = statics(src)
    for name, good in st:
        print(("STATIC_OK " if good else "STATIC_FAIL ") + name)
    caught = 0
    for key, name, old, new in MUTATIONS:
        if src[key].count(old) != 1:
            print(f"MUTATION MISSED {name} (pattern matched {src[key].count(old)})")
            continue
        mut = dict(src)
        mut[key] = src[key].replace(old, new)
        bad = not run(mut)[0] if key in ("BOX", "CONFIG") else not all(g for _, g in statics(mut))
        if bad:
            caught += 1
            print(f"MUTATION caught  {name}")
        else:
            print(f"MUTATION MISSED {name}")
    passed = ok and all(g for _, g in st) and caught == len(MUTATIONS)
    print(f"Status: {'passed' if passed else 'failed'} (statics {sum(g for _, g in st)}/{len(st)}, mutations {caught}/{len(MUTATIONS)})")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
