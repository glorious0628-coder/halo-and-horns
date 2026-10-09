"""Lighting depth check (2026-10-08, user on the meadow photo: "입체적이지 않아"; 검수: our darkest 10% was 0.69-0.74 bright,
the concept's 0.41). Static, no Studio: the CURRENT Config.Sky.Neutral, WarService (LIGHTING_FIXED / TINT_FIXED /
LIGHT_STYLE) and tools/preview_map.lua (the values Edit bakes) give a picture with shade: a lower sun, a darker cooler
shade, sharper shadows, less flat sky fill, more contrast, less neon saturation, a closer haze in the horizon colour - and
preview_map bakes exactly Config's Neutral numbers (no drift between Edit and the server). No Atmosphere anywhere (A9-3:
it would replace the war skies' FogColor / FogStart / FogEnd). Mutations: in-memory copies with one value pushed back to
the flat look; each must make a check fail. Status "passed" only when every check passes AND every mutation is caught.
Report: docs/art/verification_2026-10-08/offline_lighting_depth_2026-10-08.json
"""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
WAR = ROOT / "src/ServerScriptService/WarService.luau"
PREVIEW = ROOT / "tools/preview_map.lua"
OUT = ROOT / "docs/art/verification_2026-10-08/offline_lighting_depth_2026-10-08.json"

MUTATIONS = [
    ("CONFIG", "the noon sun back", "Neutral = { ClockTime = 15.3,", "Neutral = { ClockTime = 14.2,"),
    ("CONFIG", "the bright flat shade back", "OutdoorAmbient = Color3.fromRGB(95, 104, 118), FogColor = Color3.fromRGB(150, 205, 228), FogStart = 150",
     "OutdoorAmbient = Color3.fromRGB(128, 126, 124), FogColor = Color3.fromRGB(150, 205, 228), FogStart = 150"),
    ("CONFIG", "the far haze back", "FogStart = 150, FogEnd = 950, ExposureCompensation = -0.25", "FogStart = 250, FogEnd = 1100, ExposureCompensation = -0.25"),
    ("CONFIG", "the too-bright day back (user 10/08)", "FogEnd = 950, ExposureCompensation = -0.25", "FogEnd = 950, ExposureCompensation = -0.05"),
    ("CONFIG", "the bright sun back", "Neutral = { ClockTime = 15.3, Brightness = 2,", "Neutral = { ClockTime = 15.3, Brightness = 2.2,"),
    ("CONFIG", "a war dawn brighter than the day's step", "OutdoorAmbient = Color3.fromRGB(130, 113, 90)", "OutdoorAmbient = Color3.fromRGB(150, 130, 104)"),
    ("CONFIG", "a war dawn without its own exposure", "FogEnd = 650, ExposureCompensation = -0.35,", "FogEnd = 650,"),
    ("WAR", "the sky faces never set", "\t\tif type(id) == \"string\" and id ~= \"\" then setProps(sky, { [\"Skybox\" .. side] = id }) end\n", ""),
    ("WAR", "an empty face blanks the place's sky", "\t\tif type(id) == \"string\" and id ~= \"\" then setProps(sky, { [\"Skybox\" .. side] = id }) end\n",
     "\t\tsetProps(sky, { [\"Skybox\" .. side] = tostring(id or \"\") })\n"),
    ("CONFIG", "the eclipse night as dark as the day's step", "FogEnd = 650, ExposureCompensation = 0.35,", "FogEnd = 650, ExposureCompensation = 0.1,"),
    ("WAR", "a war sky paints over the faces", "\tlocal goals = { { Lighting, lightingGoal } }\n",
     "\tlocal goals = { { Lighting, lightingGoal } }\n\tLighting.Sky.SkyboxUp = \"\"\n"),
    ("WAR", "soft shadows back", "GlobalShadows = true, ShadowSoftness = 0.15,", "GlobalShadows = true, ShadowSoftness = 0.5,"),
    ("WAR", "full sky fill back", "\tEnvironmentDiffuseScale = 0.5, EnvironmentSpecularScale = 0.6,\n", "\tEnvironmentDiffuseScale = 1.0, EnvironmentSpecularScale = 0.6,\n"),
    ("WAR", "low contrast back", "Contrast = 0.12, Saturation = -0.05", "Contrast = 0.05, Saturation = -0.05"),
    ("WAR", "neon saturation back", "Contrast = 0.12, Saturation = -0.05", "Contrast = 0.12, Saturation = 0.1"),
    ("WAR", "the soft lighting style back", 'local LIGHT_STYLE = "Realistic"', 'local LIGHT_STYLE = "Soft"'),
    ("CONFIG", "the sky sides back in the seam order", 'Lf = "rbxassetid://80981399991828",\n\tRt = "rbxassetid://113124022425103",',
     'Lf = "rbxassetid://113124022425103",\n\tRt = "rbxassetid://80981399991828",'),
    ("PREVIEW", "Edit bakes the old noon", "Lighting.ClockTime = 15.3\n", "Lighting.ClockTime = 14.2\n"),
    ("PREVIEW", "Edit bakes the old fog colour", "Lighting.FogColor = RGB(150, 205, 228)\n", "Lighting.FogColor = RGB(205, 215, 230)\n"),
]


def rgb(s):
    return tuple(int(v) for v in s.split(","))


def checks_for(config, war, preview):
    m = re.search(r"\tNeutral = \{ ClockTime = ([\d.]+), Brightness = ([\d.]+), Ambient = Color3\.fromRGB\(([\d, ]+)\), "
                  r"OutdoorAmbient = Color3\.fromRGB\(([\d, ]+)\), FogColor = Color3\.fromRGB\(([\d, ]+)\), FogStart = (\d+), "
                  r"FogEnd = (\d+), ExposureCompensation = (-?[\d.]+)", config)
    lf = re.search(r"GlobalShadows = true, ShadowSoftness = ([\d.]+),.*?EnvironmentDiffuseScale = ([\d.]+)", war, re.S)
    tint = re.search(r"local TINT_FIXED = \{ Brightness = 0, Contrast = (-?[\d.]+), Saturation = (-?[\d.]+) \}", war)
    style = re.search(r'local LIGHT_STYLE = "(\w+)"', war)
    out = []
    if not m:
        return [("Config.Sky.Neutral parses", False)]
    clock, bright, amb, outamb, fog, fs, fe, exp = (float(m[1]), float(m[2]), rgb(m[3]), rgb(m[4]), rgb(m[5]), int(m[6]),
                                                    int(m[7]), float(m[8]))
    out += [
        ("a lower afternoon sun (ClockTime 15-16.5: longer shadows)", 15.0 <= clock <= 16.5),
        ("a shade the sky does not flatten (OutdoorAmbient every channel <= 140)", max(outamb) <= 140),
        ("a darker indoor / cave shade (Ambient every channel <= 100)", max(amb) <= 100),
        ("the shade a little cool (OutdoorAmbient blue > red)", outamb[2] > outamb[0]),
        ("one step darker than 10/08 noon (user 'too bright'): Brightness 1.8-2.1, exposure -0.4..-0.15, OutdoorAmbient <= 120",
         1.8 <= bright <= 2.1 and -0.4 <= exp <= -0.15 and max(outamb) <= 120),
        ("a closer haze (FogStart <= 200, FogEnd <= 1000) in the horizon colour 150, 205, 228",
         fs <= 200 and fe <= 1000 and fog == (150, 205, 228)),
        ("sharper sun shadows (ShadowSoftness <= 0.2)", bool(lf) and float(lf[1]) <= 0.2),
        ("less flat sky fill (EnvironmentDiffuseScale <= 0.6)", bool(lf) and float(lf[2]) <= 0.6),
        ("more contrast (>= 0.1) and calmer greens (saturation <= 0)", bool(tint) and float(tint[1]) >= 0.1 and float(tint[2]) <= 0),
        ("the Realistic lighting style", bool(style) and style[1] == "Realistic"
         and "Lighting.LightingStyle = Enum.LightingStyle[LIGHT_STYLE]" in war),
    ]
    baked = {
        "ClockTime": f"Lighting.ClockTime = {m[1]}\n" in preview,
        "Brightness": f"Lighting.Brightness = {m[2]}\n" in preview,
        "Ambient": f"Lighting.Ambient = RGB({m[3]})\n" in preview,
        "OutdoorAmbient": f"Lighting.OutdoorAmbient = RGB({m[4]})\n" in preview,
        "FogColor": f"Lighting.FogColor = RGB({m[5]})\n" in preview,
        "FogStart": f"Lighting.FogStart = {m[6]}\n" in preview,
        "FogEnd": f"Lighting.FogEnd = {m[7]}\n" in preview,
        "Exposure": f"Lighting.ExposureCompensation = {m[8]}\n" in preview,
        "ShadowSoftness": bool(lf) and f"Lighting.ShadowSoftness = {lf[1]} end)" in preview,
        "Diffuse": bool(lf) and f"Lighting.EnvironmentDiffuseScale = {lf[2]} end)" in preview,
    }
    out.append(("preview_map bakes Config's Neutral and WarService's values (" + ", ".join(k for k, v in baked.items() if not v) + ")"
                if not all(baked.values()) else "preview_map bakes Config's Neutral and WarService's values", all(baked.values())))
    out.append(("no Atmosphere is made anywhere (A9-3)", 'Instance.new("Atmosphere")' not in config + war + preview))
    # user 10/08 "too bright": the crown-war skies take the same step; the painted sky's faces (Config.Sky.Faces)
    dawn = re.search(r"\tDawn = \{[^\n]*Brightness = ([\d.]+),[^\n]*OutdoorAmbient = Color3\.fromRGB\(([\d, ]+)\)", config)
    dawn_exp = re.search(r"\tDawn = \{[^\n]*ExposureCompensation = (-?[\d.]+)", config)
    ecl_exp = re.search(r"\tEclipse = \{[^\n]*ExposureCompensation = (-?[\d.]+)", config)
    apply = war[war.find("local function applySky("):war.find("------------------------------------------------------------------ round state")]
    out += [
        ("the crown-war dawn takes the same step (Brightness <= 2.0, OutdoorAmbient <= 135, its own exposure <= -0.25)",
         bool(dawn) and bool(dawn_exp) and float(dawn[1]) <= 2.0 and max(rgb(dawn[2])) <= 135 and float(dawn_exp[1]) <= -0.25),
        ("the eclipse night keeps its light (its own exposure 0.2..0.45)", bool(ecl_exp) and 0.2 <= float(ecl_exp[1]) <= 0.45),
        ("Lighting.Sky gets Config.Sky.Faces' six faces at Start (an empty face keeps the place's)",
         "local faces = type(Config.Sky.Faces) == \"table\" and Config.Sky.Faces or {}" in war
         and 'for _, side in { "Ft", "Bk", "Lf", "Rt", "Up", "Dn" } do' in war
         and 'if type(id) == "string" and id ~= "" then setProps(sky, { ["Skybox" .. side] = id }) end' in war),
        ("the war skies never touch the faces (applySky has no Skybox)", bool(apply) and "Skybox" not in apply),
        # 메인 반영 33a77cb8: the seamless order is "B" (Lf / Rt swapped from the first sheet); 검수 10/09 saw the seam again
        ("Config.Sky.Faces is the seamless order (Ft 86737469798577, Bk 106230772458054, Lf 80981399991828, "
         "Rt 113124022425103, Up 139860275275280, Dn 111194337613180)",
         faces_ok(config)),
    ]
    return out


SKY_FACES = {"Ft": "86737469798577", "Bk": "106230772458054", "Lf": "80981399991828", "Rt": "113124022425103",
             "Up": "139860275275280", "Dn": "111194337613180"}


def faces_ok(config):
    m = re.search(r"\nConfig\.Sky\.Faces = \{\n(.*?)\n\}", config, re.S)
    if not m:
        return False
    got = dict(re.findall(r"(Ft|Bk|Lf|Rt|Up|Dn) = \"rbxassetid://(\d+)\"", m.group(1)))
    return got == SKY_FACES


def main():
    src = {"CONFIG": CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n"),
           "WAR": WAR.read_text(encoding="utf-8-sig").replace("\r\n", "\n"),
           "PREVIEW": PREVIEW.read_text(encoding="utf-8-sig").replace("\r\n", "\n")}
    base = checks_for(src["CONFIG"], src["WAR"], src["PREVIEW"])
    for name, good in base:
        print(("CHECK_OK " if good else "CHECK_FAIL ") + name)
    rows = []
    for which, name, old, new in MUTATIONS:
        applied = src[which].count(old) == 1
        caught = False
        if applied:
            mut = dict(src)
            mut[which] = src[which].replace(old, new)
            caught = not all(g for _, g in checks_for(mut["CONFIG"], mut["WAR"], mut["PREVIEW"]))
        rows.append({"mutation": name, "source": which, "applied": applied, "caught": caught})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    passed = all(g for _, g in base) and all(r["applied"] and r["caught"] for r in rows)
    report = {"status": "passed" if passed else "failed", "checks": [{"check": n, "ok": g} for n, g in base],
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in (CONFIG, WAR, PREVIEW)},
              "studioCalls": 0,
              "limitations": "Numbers only: whether the meadow now reads deep (hills, path, waterfall; PC and phone) is the main-Studio "
                             "before / after photo check (메인 반영); Lighting.Technology is a place setting set in Edit."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")


if __name__ == "__main__":
    main()
