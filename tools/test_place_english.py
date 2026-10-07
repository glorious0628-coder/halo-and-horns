"""The place shows English only (A23-48; 검수 2026-10-07: find every Hangul text inside the place, not only in src).

Offline (default): reads a saved place file (place/GoodEvil.rbxlx, or --place <file>) and lists every Hangul string in
any property of any object (TextLabel / TextButton / SurfaceGui / BillboardGui texts, ProximityPrompt texts, names,
StringValues, string attributes, ...) except script sources (comments there are never shown). --studio runs the same
search live in the open Studio's Edit DataModel through Studio MCP (Edit mode only; it changes nothing).
Static: beta signs (Config.Features): no "Market" landmark on the world map while Market is off; the Crossroads anvil spot
is called "Forge" while NeutralFaction (the artisan guild) is off.
Status "passed" only when the search finds 0 Hangul strings and the static checks pass.
Reports: docs/art/verification_2026-10-07/place_english_2026-10-07.json (offline),
         docs/art/verification_2026-10-07/place_english_studio_2026-10-07.json (--studio)
"""
from pathlib import Path
import argparse
import base64
import hashlib
import json
import re
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
WORLDMAP = ROOT / "src/StarterPlayer/StarterPlayerScripts/WorldMap.luau"
OUT = ROOT / "docs/art/verification_2026-10-07/place_english_2026-10-07.json"
OUT_STUDIO = ROOT / "docs/art/verification_2026-10-07/place_english_studio_2026-10-07.json"
HANGUL = re.compile(r"[ᄀ-ᇿ㄰-㆏가-힣]")
SKIP_PROPS = {"Source", "LinkedSource"}

# the live search (Edit DataModel): every instance's Name, text-like properties, StringValue.Value and string attributes
STUDIO_SCAN = r"""
local function hangul(s)
	if type(s) ~= "string" or s == "" then return false end
	local ok, found = pcall(function()
		for _, c in utf8.codes(s) do
			if (c >= 0xAC00 and c <= 0xD7A3) or (c >= 0x3130 and c <= 0x318F) or (c >= 0x1100 and c <= 0x11FF) then return true end
		end
		return false
	end)
	return ok and found
end
local PROPS = { "Text", "PlaceholderText", "ActionText", "ObjectText", "ToolTip", "DisplayName", "InitialPrompt",
	"UserDialog", "ResponseDialog", "Value", "Title" }
local out, n = {}, 0
local roots = { "Workspace", "ReplicatedStorage", "ReplicatedFirst", "StarterGui", "StarterPack", "StarterPlayer",
	"ServerStorage", "ServerScriptService", "Lighting", "Teams", "SoundService", "MaterialService" }
for _, svcName in roots do
	local okSvc, svc = pcall(game.GetService, game, svcName)
	if okSvc and svc then
		for _, inst in svc:GetDescendants() do
			n += 1
			local hits = {}
			if hangul(inst.Name) then table.insert(hits, "Name=" .. inst.Name) end
			for _, p in PROPS do
				local okP, v = pcall(function() return inst[p] end)
				if okP and hangul(v) then table.insert(hits, p .. "=" .. v) end
			end
			for k, v in inst:GetAttributes() do
				if hangul(k) or hangul(v) then table.insert(hits, "Attr " .. k .. "=" .. tostring(v)) end
			end
			if #hits > 0 then table.insert(out, inst.ClassName .. "\t" .. inst:GetFullName() .. "\t" .. table.concat(hits, " | ")) end
		end
	end
end
return "SCANNED " .. n .. "\n" .. table.concat(out, "\n")
"""


def scan_file(path: Path):
    root = ET.parse(path).getroot()
    hits = []

    def walk(item, trail):
        props = item.find("Properties")
        name = ""
        if props is not None:
            for p in props:
                if p.get("name") == "Name":
                    name = p.text or ""
        here = trail + [name or item.get("class")]
        if props is not None:
            for p in props:
                pname = p.get("name")
                if pname in SKIP_PROPS:
                    continue
                text = p.text or ""
                if p.tag == "BinaryString" and pname == "AttributesSerialize" and text.strip():
                    try:
                        text = base64.b64decode(text).decode("utf-8", errors="ignore")
                    except ValueError:
                        text = ""
                    pname = "Attributes"
                if HANGUL.search(text):
                    hits.append({"class": item.get("class"), "path": "/".join(here), "property": pname, "value": text[:160]})
        for child in item.findall("Item"):
            walk(child, here)

    for item in root.findall("Item"):
        walk(item, [])
    return hits


def scan_studio():
    sys.path.insert(0, str(ROOT / "tools"))
    from studio_mcp import Client  # noqa: E402
    c = Client()
    c.start()
    try:
        state = "".join(p.get("text", "") for p in c.call("get_studio_state", {}).get("content", []))
        if "Current Studio Mode: Edit" not in state:
            raise SystemExit("Studio is not in Edit mode; the live search runs only in Edit (never during a Play): " + state[:120])
        res = c.call("execute_luau", {"code": STUDIO_SCAN, "datamodel_type": "Edit"})
        text = "".join(p.get("text", "") for p in res.get("content", []))
    finally:
        c.close()
    lines = [ln for ln in text.splitlines() if ln.strip()]
    scanned = int(lines[0].split()[1]) if lines and lines[0].startswith("SCANNED") else 0
    hits = []
    for ln in lines[1:]:
        parts = ln.split("\t")
        if len(parts) == 3:
            hits.append({"class": parts[0], "path": parts[1], "property": "live", "value": parts[2][:160]})
    return scanned, hits


def static_checks(config: str, worldmap: str):
    feat = re.search(r"Config\.Features = \{([^}]*)\}", config)
    return [
        ("Config.Features.Market is off for the beta", bool(feat and re.search(r"\bMarket = false\b", feat[1]))),
        ("Config.Features.NeutralFaction is off for the beta (A23-57)", bool(feat and re.search(r"\bNeutralFaction = false\b", feat[1]))),
        ("the world map adds the Market landmark only when the feature is on",
         'if Config.FeatureOn("Market") then -- not in the beta' in worldmap
         and re.search(r'if Config\.FeatureOn\("Market"\) then[^\n]*\n\t\tlandmark\("Market"', worldmap) is not None),
        ("the world map calls the anvil spot Forge while the artisan guild is off",
         'Text = Config.FeatureOn("NeutralFaction") and TXT.Guild or TXT.Forge,' in worldmap and 'Forge = "Forge",' in worldmap),
    ]


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--place", default=str(ROOT / "place/GoodEvil.rbxlx"))
    ap.add_argument("--studio", action="store_true")
    args = ap.parse_args()
    static = static_checks(CONFIG.read_text(encoding="utf-8-sig"), WORLDMAP.read_text(encoding="utf-8-sig"))
    for name, good in static:
        print(("STATIC_OK " if good else "STATIC_FAILURE ") + name)
    if args.studio:
        scanned, hits = scan_studio()
        source = {"studio": "Edit DataModel", "instancesScanned": scanned}
        out = OUT_STUDIO
    else:
        place = Path(args.place)
        hits = scan_file(place)
        source = {"place": place.resolve().relative_to(ROOT).as_posix() if place.resolve().is_relative_to(ROOT) else str(place),
                  "placeSHA256": hashlib.sha256(place.read_bytes()).hexdigest()}
        out = OUT
    for h in hits:
        print(f"HANGUL {h['class']}\t{h['path']}\t{h['property']}\t{h['value']!r}")
    passed = not hits and all(g for _, g in static)
    report = {"status": "passed" if passed else "failed", "hangulStrings": len(hits), "hits": hits,
              "static": [{"check": n, "ok": g} for n, g in static], "source": source,
              "contract": __doc__.split("Status")[0].strip(),
              "limitations": "Script sources are skipped (comments are never shown); text that code makes at run time is "
                             "covered by the src text tests (test_english, test_ko_screen)."}
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Hangul strings: {len(hits)}")
    print(f"Status: {report['status']}")


if __name__ == "__main__":
    main()
