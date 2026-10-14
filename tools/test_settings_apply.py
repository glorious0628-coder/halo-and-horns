"""Settings rows that must change the screen (gameplay_plan 2026-10-14 2-C #9, 최종 검수 10/14), offline.

Before: "Damage numbers" (DmgNum All / Off) and "Other players' name tags" (Tags All / Near / Off) were saved but no
client code read them. Now:
1. Fx: MOTION.DamageNumbersOn() reads Settings DmgNum (default All); showAmount returns early for damage keys (M my hits,
   P PvP, H hits I take) when it is Off, the Release total (Fx.ShowNumber at the cast) too; gold / XP / loot amounts
   (G, RG, RX) still show. Extracted and run: MOTION.Pref, MOTION.DamageKeys / IsDamageKey / DamageNumbersOn; static:
   the two gates sit where the numbers are drawn.
2. NameTagPrefs.luau (new, ClientMain after ChatTags): other players' server "Nametag" BillboardGuis on this screen:
   All = Enabled, MaxDistance Config.Visuals.NametagMaxDistance; Near = NametagNearDistance; Off = Enabled false; my own
   tag (PlayerToHideFrom = me) and other billboards untouched; tags made later (server rebuilds) and Settings changes apply.
Mutations: each must make a check fail. Report: docs/art/verification_2026-10-14/offline_settings_apply_2026-10-14.json
(do not commit)
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
FILES = {"FX": SPS / "Fx.luau", "TAGS": SPS / "NameTagPrefs.luau", "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
         "MAIN": SPS / "ClientMain.client.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-14/offline_settings_apply_2026-10-14.json"
FX_CUTS = [("function MOTION.Pref(key, default)", "\nend\n"), ("MOTION.DamageKeys = {", "\n"),
           ("function MOTION.IsDamageKey(key)", "\nend\n"), ("function MOTION.DamageNumbersOn()", "\nend\n")]

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local function signal()
	local s = { Fns = {} }
	function s:Connect(fn) table.insert(self.Fns, fn) return {} end
	function s:Fire(...) for _, fn in table.clone(self.Fns) do fn(...) end end
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

-- the settings double
local VALUES = {}
local CHANGED = signal()
local SETTINGS = { Get = function(k) return VALUES[k] end, Changed = CHANGED }
local function set(k, v) VALUES[k] = v CHANGED:Fire({}, false) end

-- 1) Fx damage-number switch (extracted)
local fxEnv = setmetatable(table.clone(base), { __index = getfenv() })
fxEnv.C = { Settings = SETTINGS }
fxEnv.MOTION = {}
local ff = assert(loadstring(FX_PART, "=FxPart"))
setfenv(ff, fxEnv)
ff()
local MOTION = fxEnv.MOTION
check(MOTION.DamageNumbersOn() == true, "no setting yet: damage numbers on (default All)", "")
VALUES.DmgNum = "All"
check(MOTION.DamageNumbersOn() == true, "All: on", "")
VALUES.DmgNum = "Off"
check(MOTION.DamageNumbersOn() == false, "Off: off", "")
VALUES.DmgNum = nil
check(MOTION.IsDamageKey("M12") and MOTION.IsDamageKey("P3") and MOTION.IsDamageKey("H"), "my hits / PvP / hits taken are damage", "")
check(not MOTION.IsDamageKey("G3") and not MOTION.IsDamageKey("RG") and not MOTION.IsDamageKey("RX") and not MOTION.IsDamageKey(nil),
	"gold / XP / loot amounts are not damage (they stay)", "")
fxEnv.C = {}
check(MOTION.DamageNumbersOn() == true, "no Settings module: on", "")

-- 2) NameTagPrefs (the whole module)
local imt = {}
imt.__index = function(self, k)
	local m = rawget(imt, "methods")[k]
	if m then return m end
	return nil
end
imt.methods = {
	IsA = function(self, cl) return self.ClassName == cl end,
	GetDescendants = function(self)
		local out = {}
		local function walk(o) for _, c in o.Children do table.insert(out, c) walk(c) end end
		walk(self)
		return out
	end,
	Destroy = function(self)
		local p = rawget(self, "Parent")
		if p then local i = table.find(p.Children, self) if i then table.remove(p.Children, i) end end
		rawset(self, "Parent", nil)
	end,
}
local ADDED = signal()
imt.__newindex = function(self, k, v)
	if k == "Parent" then
		rawset(self, "Parent", v)
		if type(v) == "table" and v.Children then table.insert(v.Children, self) ADDED:Fire(self) end
		return
	end
	rawset(self, k, v)
end
local function inst(class, name)
	return setmetatable({ ClassName = class, Name = name or class, Children = {} }, imt)
end
local WS = inst("Workspace")
WS.DescendantAdded = ADDED
local ME, BO = { UserId = 7, Name = "Me" }, { UserId = 9, Name = "Bo" }
local function tag(owner, parent, name)
	local bb = inst("BillboardGui", name or "Nametag")
	bb.Enabled, bb.MaxDistance, bb.PlayerToHideFrom = true, Config.Visuals.NametagMaxDistance, owner
	bb.Parent = parent
	return bb
end
local headMe, headBo = inst("Part", "Head"), inst("Part", "Head")
headMe.Parent, headBo.Parent = WS, WS
local mine, bos = tag(ME, headMe), tag(BO, headBo)
local other = tag(BO, headBo, "GhostLabel")
local tenv = setmetatable(table.clone(base), { __index = getfenv() })
tenv.game = { GetService = function(_, n)
	if n == "Players" then return { LocalPlayer = ME } end
	if n == "ReplicatedStorage" then return { WaitForChild = function() return { WaitForChild = function(_, m) return m end } end } end
	return {}
end }
tenv.workspace = WS
tenv.typeof = function(v) if type(v) == "table" and rawget(v, "ClassName") then return "Instance" end return typeof(v) end
tenv.require = function(m)
	if m == "Config" then return Config end
	return { Warn = function(...) print("WARN", ...) end }
end
local tf = assert(loadstring(TAGS_SOURCE, "=NameTagPrefs"))
setfenv(tf, tenv)
local NT = tf()
NT.Init({ Settings = SETTINGS })
local far, near = Config.Visuals.NametagMaxDistance, Config.Visuals.NametagNearDistance
check(type(near) == "number" and near < far, "Config.Visuals.NametagNearDistance under the far distance", tostring(near))
local p = NT.Plan("Off")
check(p.Enabled == false, "plan Off: hidden", "")
p = NT.Plan("Near")
check(p.Enabled == true and p.MaxDistance == near, "plan Near: the near distance", p.MaxDistance)
p = NT.Plan("All")
check(p.Enabled == true and p.MaxDistance == far, "plan All: the server's distance", p.MaxDistance)
check(NT.Plan(nil).Enabled == true and NT.Plan("junk").MaxDistance == far, "unknown mode = All", "")
VALUES.Tags = "Off"
NT.Start()
check(bos.Enabled == false, "Off at start: Bo's tag hidden", tostring(bos.Enabled))
check(mine.Enabled == true and mine.MaxDistance == far, "my own tag untouched", "")
check(other.Enabled == true, "other billboards (ghost label) untouched", "")
check(NT.Apply(other) == false and other.Enabled == true, "Apply itself leaves other billboards alone", tostring(other.Enabled))
set("Tags", "Near")
check(bos.Enabled == true and bos.MaxDistance == near, "a Settings change to Near applies at once", bos.MaxDistance)
set("Tags", "All")
check(bos.Enabled == true and bos.MaxDistance == far, "back to All: full distance", bos.MaxDistance)
set("Tags", "Off")
bos:Destroy()
local rebuilt = tag(BO, headBo)
check(rebuilt.Enabled == false, "a tag the server rebuilds later gets the setting", tostring(rebuilt.Enabled))
local headNew = inst("Part", "Head")
headNew.Parent = WS
local newcomer = tag({ UserId = 11 }, headNew)
check(newcomer.Enabled == false, "a new player's tag too", "")
set("Tags", "All")
check(rebuilt.Enabled == true and newcomer.Enabled == true and mine.Enabled == true, "All again: every other tag back", "")
print(("SETTINGS_APPLY_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("FX", "Off still shows damage", 'return MOTION.Pref("DmgNum", "All") ~= "Off"', "return true"),
    ("FX", "gold counts as damage", "MOTION.DamageKeys = { M = true, P = true, H = true }",
     "MOTION.DamageKeys = { M = true, P = true, H = true, G = true, R = true }"),
    ("FX", "hits I take ignore the switch", "MOTION.DamageKeys = { M = true, P = true, H = true }",
     "MOTION.DamageKeys = { M = true, P = true }"),
    ("FX", "showAmount never asks", "\tif MOTION.IsDamageKey(style.Key) and not MOTION.DamageNumbersOn() then return end -- 2-C #9 Settings DmgNum\n", ""),
    ("FX", "the Release total ignores it", "if total > 0 and MOTION.DamageNumbersOn() then", "if total > 0 then"),
    ("TAGS", "Off does not hide", 'if m == "Off" then return { Enabled = false, MaxDistance = far } end',
     'if m == "Off" then return { Enabled = true, MaxDistance = far } end'),
    ("TAGS", "Near = far", 'if m == "Near" then return { Enabled = true, MaxDistance = near } end',
     'if m == "Near" then return { Enabled = true, MaxDistance = far } end'),
    ("TAGS", "my own tag hidden too", "\tif LocalPlayer and bb.PlayerToHideFrom == LocalPlayer then return false end\n", ""),
    ("TAGS", "every billboard", "or bb.Name ~= L.Name then return false end", "then return false end"),
    ("TAGS", "later tags missed", "\tworkspace.DescendantAdded:Connect(consider)\n", ""),
    ("TAGS", "a Settings change ignored", "\t\tst.Changed:Connect(function()\n", "\t\t(function()\n"),
    ("MAIN", "never loaded", '"ChatTags", "NameTagPrefs", ', '"ChatTags", '),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def cut(text: str, start: str, end: str) -> str:
    a = text.find(start)
    if a < 0:
        return ""
    b = text.find(end, a)
    return text[a:b + len(end)] if b >= 0 else ""


def statics(src: dict) -> list[tuple[str, bool]]:
    fx, main = src["FX"], src["MAIN"]
    sa = cut(fx, "local function showAmount(worldPos, amount, style)", "\nend\n")
    order = re.search(r"local ORDER = \{([^}]*)\}", main)
    names = re.findall(r'"(\w+)"', order.group(1)) if order else []
    return [
        ("showAmount asks the switch before any number", "if MOTION.IsDamageKey(style.Key) and not MOTION.DamageNumbersOn() then return end" in sa),
        ("the Release total asks it", "if total > 0 and MOTION.DamageNumbersOn() then" in fx),
        ("ClientMain loads NameTagPrefs", "NameTagPrefs" in names and "Settings" in names
         and names.index("NameTagPrefs") > names.index("Settings")),
    ]


def run(src: dict) -> tuple[int, int, str]:
    part = "\n".join(cut(src["FX"], s, e) for s, e in FX_CUTS)
    text = ("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal FX_PART = " + lua_str(part)
            + "\nlocal TAGS_SOURCE = " + lua_str(src["TAGS"]) + "\n" + FIXTURE)
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "settings_apply.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"SETTINGS_APPLY_SUMMARY checks=(\d+) failed=(\d+)", out)
    st = statics(src)
    bad = sum(1 for _, ok in st if not ok)
    out += "".join(("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + n for n, ok in st)
    return (int(m[1]) if m else 0) + len(st), (int(m[2]) if m else 1) + bad, out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    found = all(cut(src["FX"], s, e) for s, e in FX_CUTS)
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
    ok = found and failed == 0 and checks > 3 and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Mutations:")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
