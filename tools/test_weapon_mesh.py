"""dev1-weapon-mesh (최종 검수 10/14): the Tripo weapons on the code shapes, offline.

1. Config.WeaponMeshes covers every weapon of art/models/tripo/weapons/weapons_fit_manifest.json (9 class x side rows
   T1..T3, the Berserker's T7, the two joke weapons under Meme) with the manifest's Length and Pivot.
2. Config.WeaponMeshFor(gkey, tier, meme): an entry only with a MeshId (and a sane Length / Pivot); "" / unknown = nil
   (CharacterVisuals keeps the code shape - the fallback); a joke weapon by its Meme key.
3. CharacterVisuals WMESH.CodeLength: the code shape's length along the Handle (turned parts measured by their turned
   size); WMESH.Fit: the mesh scaled to that length (proportional to tierLen) with its grip point (Pivot) ON the Handle's
   grip point (Config.WeaponGrips Point); WMESH.Attach: no loaded template = nothing changes; else the code parts go
   invisible (they keep the grip / muzzle / nock / lights) and one "WeaponMesh" (no collision, massless) rides on top.
Static: buildWeapon attaches after placing the parts and never waits (CreateMeshPartAsync only in WMESH.Load, preloaded
at Start); the client's joke look steps aside for a server mesh (WeaponPose.MemeLook).
Runs the CURRENT Config.luau (with doubles) + the WMESH functions in the rigid CFrame harness of test_weapon_motion.py.
Report: docs/art/verification_2026-10-14/offline_weapon_mesh_2026-10-14.json (do not commit)
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import test_weapon_motion as twm  # noqa: E402

FILES = {"CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau", "CV": ROOT / "src/ServerScriptService/CharacterVisuals.luau",
         "WP": ROOT / "src/StarterPlayer/StarterPlayerScripts/WeaponPose.luau"}
MANIFEST = ROOT / "art/models/tripo/weapons/weapons_fit_manifest.json"
if not MANIFEST.exists():
    MANIFEST = ROOT.parent / "Game/art/models/tripo/weapons/weapons_fit_manifest.json"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-14/offline_weapon_mesh_2026-10-14.json"
ART = {"Paladin": "Warrior_Halo", "Berserker": "Warrior_Horns", "Blacksmith": "Warrior_Neutral", "LightMage": "Mage_Halo",
       "DarkMage": "Mage_Horns", "Alchemist": "Mage_Neutral", "Ranger": "Archer_Halo", "ShadowHunter": "Archer_Horns",
       "PetTamer": "Archer_Neutral"}
MEME = {"FryingPan": "Pan", "RubberChicken": "Chicken"}
CV_CUTS = ["function WMESH.CodeLength(parts, handle)", "function WMESH.Fit(entry, codeLen, handleLen, point)",
           "function WMESH.Attach(parts, handle, entry, point)"]

TESTS = r'''
local nchecks, failed = 0, 0
local function ok(v, name, detail)
    nchecks += 1
    if v then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
-- 1. the manifest
local missing = {}
for _, m in MANIFEST_ROWS do
    local row = m.Meme and Config.WeaponMeshes.Meme or Config.WeaponMeshes[m.Key]
    local e = row and row[m.Meme or m.Tier]
    if not (e and math.abs(e.Length - m.Length) < 1e-9 and math.abs(e.Pivot - m.Pivot) < 1e-9) then table.insert(missing, m.Name) end
end
ok(#MANIFEST_ROWS == 30 and #missing == 0, "every manifest weapon (30) has its row with the manifest's Length / Pivot",
    #MANIFEST_ROWS .. " " .. table.concat(missing, ","))
-- 메인 반영 1 10/15 (build/weapon_mesh_ids.json): all 30 uploaded - every row has a mesh and its colour map
local uploaded = 0
for key, row in Config.WeaponMeshes do
    for t, e in row do
        if string.match(e.MeshId, "^rbxassetid://%d+$") and string.match(e.TextureId, "^rbxassetid://%d+$") then uploaded += 1 end
    end
end
ok(uploaded == 30, "all 30 weapon meshes have their MeshId + TextureId (the uploads)", uploaded)
-- 2. WeaponMeshFor (on cleared ids: an empty one keeps the code shape)
for _, row in Config.WeaponMeshes do
    for _, e in row do e.MeshId = "" end
end
local none = true
for key, row in Config.WeaponMeshes do
    for t, _ in row do
        if Config.WeaponMeshFor(key, t) ~= nil or (key == "Meme" and Config.WeaponMeshFor(nil, nil, t) ~= nil) then none = false end
    end
end
ok(none, "no MeshId yet: no mesh anywhere (the code shapes stay)")
Config.WeaponMeshes.Warrior_Halo[2].MeshId = "rbxassetid://1"
Config.WeaponMeshes.Meme.Chicken.MeshId = "rbxassetid://2"
ok(Config.WeaponMeshFor("Warrior_Halo", 2) == Config.WeaponMeshes.Warrior_Halo[2] and Config.WeaponMeshFor("Warrior_Halo", 1) == nil
    and Config.WeaponMeshFor("Warrior_Halo", 9) == nil and Config.WeaponMeshFor("Nobody", 2) == nil,
    "a MeshId: that class x side x tier only")
ok(Config.WeaponMeshFor("Warrior_Halo", 2, "Chicken") == Config.WeaponMeshes.Meme.Chicken and Config.WeaponMeshFor("Mage_Horns", 1, "Pan") == nil,
    "a joke weapon by its Meme key (any class)")
local keep = Config.WeaponMeshes.Warrior_Halo[2].Length
Config.WeaponMeshes.Warrior_Halo[2].Length = 0
ok(Config.WeaponMeshFor("Warrior_Halo", 2) == nil, "a broken Length: no mesh")
Config.WeaponMeshes.Warrior_Halo[2].Length = keep

-- 3. the fit
local handle = { CFrame = CFrame.new(0, 0, 0), Size = Vector3.new(0.3, 1.2, 0.3), Transparency = 0 }
local blade = { CFrame = CFrame.new(0, 1.85, 0), Size = Vector3.new(0.25, 2.5, 0.6), Transparency = 0 }
local guard = { CFrame = CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.pi / 2), Size = Vector3.new(1.4, 0.25, 0.4), Transparency = 0 }
local len = WMESH.CodeLength({ handle, blade, guard }, handle)
ok(math.abs(len - 3.7) < 1e-6, "the code length along the Handle: -0.6 .. 3.1", len)
local tall = { CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.pi / 2), Size = Vector3.new(5, 0.2, 0.2), Transparency = 0 }
ok(math.abs(WMESH.CodeLength({ handle, tall }, handle) - 5) < 1e-6, "a turned part counts by its turned size", WMESH.CodeLength({ handle, tall }, handle))
local worst = 0
for _, m in MANIFEST_ROWS do
    if m.CodeLen then
        local e = { Length = m.Length, Pivot = m.Pivot }
        local point = 0.5
        local scale, dy = WMESH.Fit(e, m.CodeLen, 1.2, point)
        local meshGrip = dy - e.Length * scale / 2 + e.Pivot * e.Length * scale
        worst = math.max(worst, math.abs(meshGrip - (point - 0.5) * 1.2), math.abs(scale * e.Length - m.CodeLen))
    end
end
ok(worst < 1e-9, "every weapon: the mesh as long as its code shape, its grip point on the Handle's grip point", worst)
local sc = WMESH.Fit({ Length = 3, Pivot = 0.2 }, 3.85, 1.2, 0.75)
ok(math.abs(sc - 3.85 / 3) < 1e-9, "the scale = code length / mesh length (proportional to tierLen)", sc)
-- Attach
local parts = { handle, blade, guard }
ok(WMESH.Attach(parts, handle, { MeshId = "rbxassetid://404", Length = 3, Pivot = 0.2 }, 0.5) == nil and #parts == 3
    and blade.Transparency == 0, "no loaded template: nothing changes (the code shape)")
-- the uploads load at the FBX's 100x (메인 반영 1 10/15): the template's own size never changes the result
local template = { Size = Vector3.new(60, 300, 20) }
function template:Clone()
    return { Size = self.Size, Name = "x" }
end
WMESH.Cache["rbxassetid://7"] = template
local e = { MeshId = "rbxassetid://7", Length = 3, Pivot = 0.2 }
local mesh = WMESH.Attach(parts, handle, e, 0.5)
local s2, dy2 = WMESH.Fit(e, 3.7, 1.2, 0.5)
ok(mesh and mesh.Name == "WeaponMesh" and parts[4] == mesh and math.abs(mesh.Size.Y - 3 * s2) < 1e-9
    and math.abs(mesh.CFrame.Position.Y - dy2) < 1e-9, "a loaded template: one WeaponMesh sized and placed on the Handle", mesh and mesh.Size.Y)
ok(handle.Transparency == 1 and blade.Transparency == 1 and guard.Transparency == 1 and mesh.CanCollide == false
    and mesh.Massless == true and mesh.Anchored == false, "the code parts invisible (still there), the mesh no collision, massless")
print(("WEAPON_MESH_SUMMARY checks=%d failed=%d"):format(nchecks, failed))
'''

CONFIG_HARNESS = r'''
local function ctor2(kind)
    return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum2 = setmetatable({}, { __index = function(_, kind)
    return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local cfgEnv = setmetatable({ Vector3 = { new = function(x, y, z) return { X = x or 0, Y = y or 0, Z = z or 0 } end, zero = { X = 0, Y = 0, Z = 0 } },
    Vector2 = { new = function() return {} end }, Color3 = { new = function() return {} end, fromRGB = function() return {} end, fromHSV = function() return {} end },
    BrickColor = { new = function(v) return v end }, Rect = ctor2("Rect"), UDim2 = ctor2("UDim2"), UDim = ctor2("UDim"),
    NumberRange = ctor2("NumberRange"), NumberSequence = ctor2("NumberSequence"), ColorSequence = ctor2("ColorSequence"),
    NumberSequenceKeypoint = ctor2("NumberSequenceKeypoint"), ColorSequenceKeypoint = ctor2("ColorSequenceKeypoint"),
    CFrame = ctor2("CFrame"), TweenInfo = ctor2("TweenInfo"), Font = ctor2("Font"), Enum = enum2,
    workspace = { GetServerTimeNow = function() return 1790000000 end } }, { __index = getfenv() })
local cfFn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cfFn, cfgEnv)
local Config = cfFn()
local WMESH = { Cache = {}, Loading = {}, Name = "WeaponMesh" }
'''

MUTATIONS = [
    ("CV", "the grip point the wrong way", "return scale, grip + (0.5 - entry.Pivot) * entry.Length * scale",
     "return scale, grip - (0.5 - entry.Pivot) * entry.Length * scale"),
    ("CV", "the mesh at its own size", "\tlocal scale = codeLen / entry.Length\n", "\tlocal scale = 1\n"),
    ("CV", "turned parts by their unturned size", "local half = (math.abs(up.Y) * p.Size.Y + math.abs(rel.RightVector.Y) * p.Size.X + math.abs(rel.LookVector.Y) * p.Size.Z) / 2",
     "local half = p.Size.Y / 2 + 0 * math.abs(up.Y)"),
    ("CV", "the code shape stays visible under the mesh", "\tfor _, p in parts do p.Transparency = 1 end\n", ""),
    ("CV", "the mesh collides", "mesh.Anchored, mesh.CanCollide, mesh.CanQuery, mesh.CanTouch, mesh.Massless = false, false, false, false, true",
     "mesh.Anchored, mesh.CanCollide, mesh.CanQuery, mesh.CanTouch, mesh.Massless = false, true, false, false, true"),
    ("CONFIG", "an empty MeshId counts", 'if type(e) ~= "table" or type(e.MeshId) ~= "string" or e.MeshId == "" then return nil end',
     'if type(e) ~= "table" or type(e.MeshId) ~= "string" then return nil end'),
    ("CONFIG", "the joke weapons not looked up", 'e = type(M.Meme) == "table" and M.Meme[meme] or nil', "e = nil"),
    ("CONFIG", "the T7 Ruin Sword missing", "\t\t[7] = { MeshId = \"rbxassetid://72072766738977\", TextureId = \"rbxassetid://123814346168925\", Length = 6.5, Pivot = 0.17 }, -- Weapon_Horns_Berserker_T7\n", ""),
    ("CONFIG", "a mesh id lost", 'MeshId = "rbxassetid://72072766738977"', 'MeshId = ""'),
    ("CV", "the mesh at its loaded (100x) size", "mesh.Size = template.Size * (entry.Length / math.max(1e-6, template.Size.Y)) * scale",
     "mesh.Size = template.Size * scale"),
    ("CV", "buildWeapon waits for a mesh", "\tlocal template = entry and WMESH.Cache[entry.MeshId]\n",
     "\tlocal template = entry and (WMESH.Cache[entry.MeshId] or WMESH.Load(entry))\n"),
    ("CV", "the joke weapons get no mesh", "and Config.WeaponMeshFor(gkey, tier, type(w) == \"table\" and w.Meme or nil) or nil",
     "and Config.WeaponMeshFor(gkey, tier, nil) or nil"),
    ("WP", "the client's joke look over the server mesh", '\tif tool:FindFirstChild("WeaponMesh") then meme = nil end\n', ""),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def cut(text: str, start: str) -> str:
    a = text.find(start)
    if a < 0:
        return ""
    b = text.find("\nend\n", a)
    return text[a:b + 5] if b >= 0 else ""


def manifest_rows() -> str:
    rows = []
    for w in json.loads(MANIFEST.read_text(encoding="utf-8"))["weapons"]:
        p = w["name"].split("_")
        if p[1] == "Meme":
            rows.append('{ Name = "%s", Meme = "%s", Length = %r, Pivot = %r }' % (w["name"], MEME[p[2]], w["length_studs"], w["pivot_share_from_bottom"]))
        else:
            rows.append('{ Name = "%s", Key = "%s", Tier = %d, Length = %r, Pivot = %r, CodeLen = %r }' % (
                w["name"], ART[p[2]], int(p[3][1:]), w["length_studs"], w["pivot_share_from_bottom"], w["code_len"]))
    return "local MANIFEST_ROWS = { " + ", ".join(rows) + " }\n"


def statics(src: dict) -> list[tuple[str, bool]]:
    cv, wp = src["CV"], src["WP"]
    b = cv.find("local function buildWeapon(")
    body = cv[b:cv.find("\nend\n", b)] if b >= 0 else ""
    place = body.find("\t\tp.CFrame = place * p.CFrame\n")
    attach = body.find("pcall(WMESH.Attach, parts, handle, meshEntry, point)")
    tool = body.find('local model = Instance.new("Tool")')
    return [
        ("buildWeapon: the mesh (a joke weapon by its Meme key) after the parts are placed, before the Tool is made",
         0 <= place < attach < tool and 'Config.WeaponMeshFor(gkey, tier, type(w) == "table" and w.Meme or nil)' in body),
        ("never waits in buildWeapon: CreateMeshPartAsync only in WMESH.Load (pcall), preloaded at Start",
         cv.count("CreateMeshPartAsync") == 1 and "CreateMeshPartAsync" in cut(cv, "function WMESH.Load(entry)")
         and "\ttask.spawn(WMESH.PreloadAll)" in cv and "Load(" not in body),
        ("the client's joke look steps aside for the server mesh", '\tif tool:FindFirstChild("WeaponMesh") then meme = nil end\n' in wp),
    ]


def run(src: dict) -> tuple[int, int, str]:
    cv = src["CV"]
    code = (twm.MATH + "\nlocal CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\n" + CONFIG_HARNESS + manifest_rows()
            + "\n".join(cut(cv, s) for s in CV_CUTS) + "\n" + TESTS)
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "weapon_mesh.luau"
        p.write_text(code, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=180)
    out = proc.stdout + proc.stderr
    m = re.search(r"WEAPON_MESH_SUMMARY checks=(\d+) failed=(\d+)", out)
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
    ok = failed == 0 and checks >= 14 and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Runs the")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
