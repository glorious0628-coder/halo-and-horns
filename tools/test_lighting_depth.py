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
    ("CONFIG", "the bright flat shade back", "OutdoorAmbient = Color3.fromRGB(110, 120, 135), FogColor = Color3.fromRGB(150, 205, 228), FogStart = 150",
     "OutdoorAmbient = Color3.fromRGB(128, 126, 124), FogColor = Color3.fromRGB(150, 205, 228), FogStart = 150"),
    ("CONFIG", "the far haze back", "FogStart = 150, FogEnd = 950, ExposureCompensation = -0.05", "FogStart = 250, FogEnd = 1100, ExposureCompensation = -0.05"),
    ("WAR", "soft shadows back", "GlobalShadows = true, ShadowSoftness = 0.15,", "GlobalShadows = true, ShadowSoftness = 0.5,"),
    ("WAR", "full sky fill back", "\tEnvironmentDiffuseScale = 0.5, EnvironmentSpecularScale = 0.6,\n", "\tEnvironmentDiffuseScale = 1.0, EnvironmentSpecularScale = 0.6,\n"),
    ("WAR", "low contrast back", "Contrast = 0.12, Saturation = -0.05", "Contrast = 0.05, Saturation = -0.05"),
    ("WAR", "neon saturation back", "Contrast = 0.12, Saturation = -0.05", "Contrast = 0.12, Saturation = 0.1"),
    ("WAR", "the soft lighting style back", 'local LIGHT_STYLE = "Realistic"', 'local LIGHT_STYLE = "Soft"'),
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
        ("the lit side stays bright (Brightness >= 2, exposure >= -0.15)", bright >= 2.0 and exp >= -0.15),
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
    return out


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
