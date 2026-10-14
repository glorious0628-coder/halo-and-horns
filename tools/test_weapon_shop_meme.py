"""The Forge sells 5 weapons (A23-186: Otto - tiers 2..3 + the joke Frying Pan / Rubber Chicken), screen side, offline.

1. Panels WSHOP.CatalogTiers(): tiers 1..Config.WeaponShop.MaxSoldTier (tier 1 = the M1_1 gift row) then every row the
   Forge sells as a joke (Config.WeaponSoldAtForge + Meme): 1, 2, 3, 10, 11. WSHOP.IsMeme(tier). WSHOP.Offer accepts a
   listed joke tier (it refused anything over MaxSoldTier before). Each joke row shows Config.WeaponMemeScreen.Line.
2. WeaponPose.MemeOf(WeaponTier) -> "Pan" / "Chicken" / nil; a joke weapon is drawn by code here (MemeLook: the server's
   class-shaped parts hidden locally, Config.WeaponMemeScreen.Look parts on the Handle) and held like a sword (A23-187).
3. Fx "Swing" with Meme = a Config.WeaponMemes key: Feel.memeHits plays its SoundId once and its ParticleId on each hit;
   empty ids = nothing (the assets are not made yet).
Extracted and run: Config.luau (real, with doubles) + the WSHOP / MemeOf functions. Static: the wiring. Mutations.
Report: docs/art/verification_2026-10-15/offline_weapon_shop_meme_2026-10-15.json (do not commit)
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
FILES = {"CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau", "PANELS": SPS / "Panels.luau",
         "WP": SPS / "WeaponPose.luau", "FX": SPS / "Fx.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-15/offline_weapon_shop_meme_2026-10-15.json"
PANEL_CUTS = [("function WSHOP.Finite(", "\nend\n"), ("function WSHOP.CatalogLimit()", "\nend\n"),
              ("function WSHOP.CatalogTiers()", "\nend\n"), ("function WSHOP.IsMeme(tier)", "\nend\n")]
WP_CUTS = [("function WeaponPose.MemeOf(tier)", "\nend\n")]

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
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

local WSHOP, WeaponPose = {}, {}
local f = assert(loadstring(PANEL_PART .. "\n" .. WP_PART, "=Part"))
setfenv(f, setmetatable({ WSHOP = WSHOP, WeaponPose = WeaponPose, Config = Config }, { __index = getfenv() }))
f()

local tiers = WSHOP.CatalogTiers()
check(table.concat(tiers, ",") == "1,2,3,10,11", "the Forge rows: 1, 2, 3 + the two joke weapons", table.concat(tiers, ","))
check(WSHOP.IsMeme(10) and WSHOP.IsMeme(11) and not WSHOP.IsMeme(3) and not WSHOP.IsMeme(nil), "joke rows are 10 / 11")
check(Config.WeaponSoldAtForge(10) and Config.WeaponSoldAtForge(11) and not Config.WeaponSoldAtForge(1)
	and not Config.WeaponSoldAtForge(4), "the server's sale rule: 2..3 + jokes, never the gift tier 1 or tier 4")
local keep = Config.WeaponShop.MaxSoldTier
Config.WeaponShop.MaxSoldTier = 2
check(table.concat(WSHOP.CatalogTiers(), ",") == "1,2,10,11", "MaxSoldTier 2: 1, 2 + the jokes", table.concat(WSHOP.CatalogTiers(), ","))
Config.WeaponShop.MaxSoldTier = keep
check(WeaponPose.MemeOf(10) == "Pan" and WeaponPose.MemeOf(11) == "Chicken" and WeaponPose.MemeOf(3) == nil
	and WeaponPose.MemeOf(nil) == nil, "MemeOf: 10 Pan, 11 Chicken, others none")
check(type(Config.WeaponMemeScreen) == "table" and type(Config.WeaponMemeScreen.Line) == "string"
	and Config.WeaponMemeScreen.Look.Pan.Pan and Config.WeaponMemeScreen.Look.Chicken.Comb, "Config: the joke line + both looks")
check(Config.WeaponMemes.Pan.Sound == "Bonk" and Config.WeaponMemes.Chicken.Sound == "Squeak"
	and Config.WeaponMemes.Chicken.Particle == "Feathers", "Config.WeaponMemes keys (game dev 2)")
print(("WEAPON_SHOP_MEME_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("PANELS", "the joke rows not listed", "if type(def) == \"table\" and def.Meme and type(Config.WeaponSoldAtForge)",
     "if type(def) == \"table\" and false and type(Config.WeaponSoldAtForge)"),
    ("PANELS", "a joke tier refused by Offer", "or (selectedTier > cap and not table.find(WSHOP.CatalogTiers(), selectedTier)) then",
     "or selectedTier > cap then"),
    ("PANELS", "the rows still 1..cap", "\tfor _, tier in WSHOP.CatalogTiers() do\n", "\tfor tier = 1, cap or 0 do\n"),
    ("PANELS", "no joke line", 'Meme = WSHOP.IsMeme(tier) and addText(row,', 'Meme = false and addText(row,'),
    ("WP", "MemeOf finds nothing", 'return type(def) == "table" and type(def.Meme) == "string" and def.Meme or nil', "return nil"),
    ("WP", "a joke weapon held like its class", "\t\t\tif meme then kind = T.MemeKind end\n", ""),
    ("WP", "no joke look", "\t\t\tpcall(WeaponPose.MemeLook, tool, meme)\n", ""),
    ("FX", "no joke hit", "\tif data.Meme ~= nil then pcall(Feel.memeHits, data.Meme, hits) end", "\tlocal _ = Feel.memeHits"),
    ("FX", "a sound with an empty id", 'if n == 1 and type(def.SoundId) == "string" and def.SoundId ~= "" then',
     'if n == 1 and type(def.SoundId) == "string" then'),
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
    p, w, fx = src["PANELS"], src["WP"], src["FX"]
    return [
        ("the Forge window lists WSHOP.CatalogTiers() and each joke row shows its line",
         "\tfor _, tier in WSHOP.CatalogTiers() do\n" in p and 'Meme = WSHOP.IsMeme(tier) and addText(row,' in p
         and "or (selectedTier > cap and not table.find(WSHOP.CatalogTiers(), selectedTier)) then" in p),
        ("WeaponPose: a joke weapon gets the code look and the sword hold (rest + pose)",
         "\t\t\tpcall(WeaponPose.MemeLook, tool, meme)\n" in w and "\t\t\tif meme then kind = T.MemeKind end\n" in w
         and 'MemeKind = "Sword"' in w and "and T.MemeKind\n\t\t\tor tool:GetAttribute(\"Kind\")" in w),
        ("Fx Swing plays a joke hit (sound once, particle per hit; empty ids = nothing)",
         "\tif data.Meme ~= nil then pcall(Feel.memeHits, data.Meme, hits) end" in fx
         and 'if n == 1 and type(def.SoundId) == "string" and def.SoundId ~= "" then' in fx
         and 'if type(def.ParticleId) == "string" and def.ParticleId ~= "" then' in fx),
    ]


def run(src: dict) -> tuple[int, int, str]:
    panel = "".join(cut(src["PANELS"], a, b) + "\n" for a, b in PANEL_CUTS)
    wp = "".join(cut(src["WP"], a, b) + "\n" for a, b in WP_CUTS)
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "weapon_shop_meme.luau"
        p.write_text("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal PANEL_PART = " + lua_str(panel)
                     + "\nlocal WP_PART = " + lua_str(wp) + "\n" + FIXTURE, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=180)
    out = proc.stdout + proc.stderr
    m = re.search(r"WEAPON_SHOP_MEME_SUMMARY checks=(\d+) failed=(\d+)", out)
    st = statics(src)
    out += "".join(("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + n for n, ok in st)
    return (int(m[1]) if m else 0) + len(st), (int(m[2]) if m else 1) + sum(1 for _, ok in st if not ok), out


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
    ok = failed == 0 and checks > 5 and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Extracted")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
