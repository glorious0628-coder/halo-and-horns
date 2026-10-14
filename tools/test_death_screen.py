"""KO screen (게임성 개발 1, BB14 client + SPEC A23-110 "짧게: KO!·쓰러뜨린 것·3-2-1, 팁 없음"), offline.

Runs, in the official Luau CLI, the CURRENT Config.luau and DeathScreen.luau on doubles (UIKit.Gui, Instance.new, the
Fx remote, CharacterAdded). Checks: the lines (KO!, "Knocked out by King Slime" / "You fell" / "You were knocked out",
pouch gold lost or the Grudge Sack - no line when nothing was lost, "Back in 3 s" counting, never the server's fun tip),
the screen drawn on UIKit.Gui (not modal, dim, under the opening), my own KO only, closed by my next character.
Box height (최종 검수 10/14): the box is the sum of its shown lines (each size + 8, 6 between) with 4 'This run' lines on
a PC; a phone (TouchEnabled, UIScale 0.75, 361 px high) shows at most 2 (XP, gold) and the whole box sits between the
Roblox top bar (58 px) and the screen bottom.
Static: ClientMain loads DeathScreen after EventHUD. Mutations: each must be caught.

Usage: py tools/test_death_screen.py
Report: docs/art/verification_2026-10-10/offline_death_screen_2026-10-10.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"DS": SPS / "DeathScreen.luau", "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
         "MAIN": SPS / "ClientMain.client.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-10/offline_death_screen_2026-10-10.json"

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local function signal()
	local s = { Fns = {} }
	function s:Connect(fn) table.insert(self.Fns, fn) return {} end
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
local function obj(c)
	local o = { ClassName = c, Children = {} }
	setmetatable(o, { __newindex = function(t, k, v)
		rawset(t, k, v)
		if k == "Parent" and type(v) == "table" and v.Children then table.insert(v.Children, t) end
	end })
	o.Destroy = function(self)
		local p = rawget(self, "Parent")
		if p then local i = table.find(p.Children, self) if i then table.remove(p.Children, i) end end
		rawset(self, "Parent", nil)
	end
	return o
end
local GUI = obj("ScreenGui")
local FX = { OnClientEvent = signal() }
local ME = { UserId = 7, CharacterAdded = signal(), Attrs = { Level = 1, XP = 0, CarriedGold = 0, BankGold = 0, Honor = 0, Faction = "Halo" } }
function ME:GetAttribute(k) return self.Attrs[k] end
local UIS = { TouchEnabled = false }
local env = setmetatable(table.clone(base), { __index = getfenv() })
env.game = { GetService = function(_, n)
	if n == "Players" then return { LocalPlayer = ME } end
	if n == "ReplicatedStorage" then return { WaitForChild = function() return { WaitForChild = function(_, m) return m end } end } end
	if n == "TweenService" then return { Create = function() return { Play = function() end } end } end
	if n == "UserInputService" then return UIS end
	return {}
end }
env.require = function(m)
	if m == "Config" then return Config end
	if m == "Net" then return { Get = function(n) return n == "Fx" and FX or nil end } end
	return { Warn = function(...) print("WARN", ...) end, FormatNumber = function(n) return tostring(n) end }
end
env.Instance = { new = obj }
env.typeof = function(v) if type(v) == "table" and v.ClassName then return "Instance" end return typeof(v) end
local SPAWN = false -- run spawned functions only while Start runs (the screen's own loop never ends here)
env.task = { spawn = function(fn, ...) if SPAWN then fn(...) end end, wait = function() end }
local f = assert(loadstring(DS_SOURCE, "=DeathScreen"))
setfenv(f, env)
local DS = f()
DS.Init({ UIKit = { Gui = GUI, ReducedMotion = function() return true end } })
SPAWN = true
DS.Start()
SPAWN = false

local L = DS.Lines({ By = "Monster", Name = "King Slime", Lost = 0, RespawnIn = 3, Tip = "Tip: slimes are 90% jelly" }, 3)
check(L.Title == "KO!" and L.Cause == "Knocked out by King Slime" and L.Back == "Back in 3 s", "a monster KO: KO!, who, Back in 3 s",
	tostring(L.Cause) .. " / " .. tostring(L.Back))
check(L.Lost == "Nothing lost", "nothing lost: it says so (the first KO, 검수 10/10)", tostring(L.Lost))
local seen = false
for _, v in L do if type(v) == "string" and string.find(v, "Tip", 1, true) then seen = true end end
check(not seen, "no tip line, not even the server's fun tip (A23-99 / A23-110)", "")
check(DS.Lines({ By = "Fall" }, 2).Cause == "You fell", "a fall: You fell", "")
check(DS.Lines({ By = "Other" }, 2).Cause == "You were knocked out" and DS.Lines({ By = "Player" }, 2).Cause == "You were knocked out",
	"no name: the plain line", "")
check(DS.Lines({ By = "Player", Name = "Bo", Lost = 120 }, 1).Lost == "Lost 120 pouch gold", "pouch gold lost: its line", "")
check(DS.Lines({ By = "Player", Name = "Bo", Sack = true, Lost = 50 }, 1).Lost == "You lost the Grudge Sack", "the Grudge Sack: its line", "")
check(DS.Lines({ By = "Monster", Name = "Slime" }, 1.2).Back == "Back in 2 s" and DS.Lines({ By = "Monster", Name = "Slime" }, 0).Back == nil,
	"the countdown rounds up, and is gone at 0", "")
FX.OnClientEvent:Fire("Reward", {})
check(#GUI.Children == 0, "another Fx kind draws nothing", #GUI.Children)
FX.OnClientEvent:Fire("KO", { UserId = 9, By = "Fall" })
check(#GUI.Children == 0, "someone else's KO draws nothing here", #GUI.Children)
FX.OnClientEvent:Fire("KO", { By = "Monster", Name = "King Slime", RespawnIn = 3 })
local frame = GUI.Children[1]
check(DS.IsOpen() and frame and frame.Name == "DeathScreen" and frame.Active == false and frame.BackgroundTransparency > 0,
	"my KO: a dim, not modal screen on UIKit.Gui", frame and frame.Name)
local box = frame and frame.Children[1]
local texts = {}
for _, c in box and box.Children or {} do if c.ClassName == "TextLabel" and c.Visible then texts[c.Name] = c.Text end end
check(texts.Title == "KO!" and texts.Cause == "Knocked out by King Slime" and texts.Back == "Back in 3 s" and texts.Lost == "Nothing lost",
	"it reads KO! / Knocked out by King Slime / Back in 3 s", tostring(texts.Cause))
check(frame and frame.ZIndex < 100, "under the opening and the pickers", frame and frame.ZIndex)
ME.CharacterAdded:Fire({})
check(not DS.IsOpen() and #GUI.Children == 0, "my next character closes it", #GUI.Children)

-- box height: a run that gave XP, gold, items and Honor (4 'This run' lines)
ME.Attrs.XP, ME.Attrs.CarriedGold, ME.Attrs.Honor = 50, 100, 5
FX.OnClientEvent:Fire("Loot", { Items = { { N = 2 } } })
local function shown(touch)
	UIS.TouchEnabled = touch
	FX.OnClientEvent:Fire("KO", { By = "Monster", Name = "King Slime", Lost = 30, RespawnIn = 3 })
	local b = GUI.Children[1] and GUI.Children[1].Children[1]
	local sum, n, vis = 0, 0, {}
	for _, c in b and b.Children or {} do
		if c.ClassName == "TextLabel" and c.Visible then sum += c.Size.Args[4] n += 1 vis[c.Name] = c.Text end
	end
	local pad = 0
	for _, c in b and b.Children or {} do if c.ClassName == "UIListLayout" then pad = c.Padding.Args[2] end end
	return b, sum + math.max(0, n - 1) * pad, n, vis
end
local b, want, n, vis = shown(false)
local h = b and b.Size.Args[4]
check(n == 9 and vis.Got4 ~= nil and h == want and h > 220, "PC: 4 'This run' lines, the box is the sum of its 9 lines (not 220)",
	tostring(n) .. " lines, box " .. tostring(h) .. " want " .. tostring(want))
DS.Hide()
b, want, n, vis = shown(true)
h = b and b.Size.Args[4]
local y = b and b.Position.Args[2] or 0
local top, bottom = y * 361 - h * 0.75 / 2, y * 361 + h * 0.75 / 2
check(vis.Got1 == "+50 XP" and vis.Got2 == "+100 gold" and vis.Got3 == nil and vis.Got4 == nil,
	"phone: at most 2 'This run' lines, XP and gold first", tostring(vis.Got1) .. " / " .. tostring(vis.Got2) .. " / " .. tostring(vis.Got3))
check(h == want and top >= 58 and bottom <= 361 - 8, "phone 361 px high: the box is its lines and fits under the top bar",
	("box %s want %s top %.0f bottom %.0f"):format(tostring(h), tostring(want), top, bottom))
DS.Hide()
UIS.TouchEnabled = false
print(("DEATH_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("DS", "the fun tip shown", "\tif type(left) == \"number\" and left > 0 then\n", "\tout.Tip = data.Tip\n\tif type(left) == \"number\" and left > 0 then\n"),
    ("DS", "pouch gold lost reads as nothing lost", "\telseif lost >= 1 then\n", "\telseif false then\n"),
    ("DS", "nothing lost: no line", "\t\tout.Lost = txt(\"LostNone\")", "\t\tout.Lost = nil"),
    ("DS", "no name for a monster", "local f = txt(by)\n\t\tout.Cause = f and string.format(f, name) or nil", "out.Cause = txt(\"Other\")"),
    ("DS", "the countdown never ends", "\tif type(left) == \"number\" and left > 0 then\n", "\tif type(left) == \"number\" then\n"),
    ("DS", "everyone's KO shows", "data.UserId ~= nil and LocalPlayer and data.UserId ~= LocalPlayer.UserId then return false end",
     "false then return false end"),
    ("DS", "never closes on the new character", "LocalPlayer.CharacterAdded:Connect(function() DeathScreen.Hide() end)", "local _ = 0"),
    ("DS", "the box stays 220 high", "S.Box.Size = UDim2.new(0.8, 0, 0, DeathScreen.BoxHeight(lines, S.Look))",
     "S.Box.Size = UDim2.new(0.8, 0, 0, 220)"),
    ("DS", "the phone keeps 4 lines", "GotSize = 19, MaxGot = 2, Y = 0.5 }", "GotSize = 19, MaxGot = 4, Y = 0.5 }"),
    ("DS", "the phone box sits high", "GotSize = 19, MaxGot = 2, Y = 0.5 }", "GotSize = 19, MaxGot = 2, Y = 0.42 }"),
    ("DS", "the phone uses PC sizes", "local src = touch == true and T.Touch or T", "local src = T"),
    ("DS", "modal (blocks input)", "\tframe.Active = false\n", "\tframe.Active = true\n"),
    ("MAIN", "never loaded", '"EventHUD", "DeathScreen", "Panels"', '"EventHUD", "Panels"'),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(src: dict) -> tuple[int, int, str]:
    text = "local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal DS_SOURCE = " + lua_str(src["DS"]) + "\n" + FIXTURE
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "death.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"DEATH_SUMMARY checks=(\d+) failed=(\d+)", out)
    order = re.search(r"local ORDER = \{([^}]*)\}", src["MAIN"])
    names = re.findall(r'"(\w+)"', order.group(1)) if order else []
    ok = "DeathScreen" in names and "EventHUD" in names and names.index("DeathScreen") > names.index("EventHUD")
    out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + "ClientMain loads DeathScreen after EventHUD"
    return (int(m[1]) if m else 0) + 1, (int(m[2]) if m else 1) + (0 if ok else 1), out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    checks, failed, out = run(src)
    print(out.strip())
    muts = []
    for key, name, old, new in MUTATIONS:
        hits = src[key].count(old)
        caught = False
        if hits == 1:
            m = dict(src)
            m[key] = src[key].replace(old, new)
            caught = run(m)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    ok = failed == 0 and checks > 1 and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
