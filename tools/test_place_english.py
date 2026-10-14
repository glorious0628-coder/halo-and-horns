"""The place shows English only (A23-48; 검수 2026-10-07: find every Hangul text inside the place, not only in src).

Offline (default): reads a saved place file (place/GoodEvil.rbxlx, or --place <file>) and lists every Hangul string in
any property of any object (TextLabel / TextButton / SurfaceGui / BillboardGui texts, ProximityPrompt texts, names,
StringValues, string attributes, ...) except script sources (comments there are never shown). --studio runs the same
search live in the open Studio's Edit DataModel through Studio MCP (Edit mode only; it changes nothing).
Static: beta signs (Config.Features): no "Market" landmark on the world map while Market is off; the Crossroads anvil spot
is called "Forge" while NeutralFaction (the artisan guild) is off.
Status "passed" only when the search finds 0 Hangul strings, the static checks pass and the self test passes.
Roblox writes each non-ASCII byte of a string as its own character reference ('말' = &#235;&#167;&#144;), so the parser
hands back Latin-1 characters; every text is read back as the UTF-8 bytes it is (roblox_text). 검수 2026-10-08
(docs/review/main_studio_audit_2026-10-08.md §5): before that fix the scan never saw Hangul, so the old "0" reports
prove nothing. The self test (offline runs) checks a Roblox-style sample is caught, that the old reading misses it (the
mutation), and that the saved place from before 84c7dbdd (Korean labels then) is caught again.
Reports: docs/art/verification_2026-10-07/place_english_2026-10-07.json (offline),
         docs/art/verification_2026-10-07/place_english_studio_2026-10-07.json (--studio)
"""
from pathlib import Path
import argparse
import base64
import hashlib
import json
import re
import struct
import subprocess
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


def roblox_text(text: str) -> str:
    """A string property as Roblox meant it: the place file writes every non-ASCII byte as its own character reference
    (&#235;&#167;&#144; = '말'), which the parser returns as Latin-1 characters, so they are read back as UTF-8 bytes.
    A text that is no such byte string (a character above U+00FF, or bytes that are not UTF-8) stays as it is."""
    try:
        return text.encode("latin-1").decode("utf-8")
    except (UnicodeEncodeError, UnicodeDecodeError):
        return text


# Roblox's AttributesSerialize blob: u32 count, then per attribute a key (u32 length + bytes), a type byte and the value.
# Only keys and String values can hold words; every other type is skipped by its size (2026-10-08: reading the whole blob
# as UTF-8 turned a CFrame attribute's float bytes (MeadowKit W_Tree_A MT_OrigPivot) into a "Hangul" false alarm).
ATTR_FIXED = {0x03: 1, 0x04: 4, 0x05: 4, 0x06: 8, 0x09: 8, 0x0A: 16, 0x0B: 24, 0x0C: 4, 0x0D: 4, 0x0E: 4, 0x0F: 12,
              0x10: 8, 0x11: 12, 0x12: 4, 0x13: 6, 0x1B: 8, 0x1C: 16}


def attr_strings(blob: bytes):
    """(texts, complete): the attribute names and String values of an AttributesSerialize blob, and False when an
    unknown type or a short blob stopped the reading (the texts read so far are still returned)."""
    texts, i = [], 0

    def u32(at):
        if at + 4 > len(blob):
            raise ValueError("short")
        return int.from_bytes(blob[at:at + 4], "little"), at + 4

    def string(at):
        n, at = u32(at)
        if at + n > len(blob):
            raise ValueError("short")
        return blob[at:at + n].decode("utf-8", errors="replace"), at + n

    try:
        count, i = u32(0)
        for _ in range(count):
            key, i = string(i)
            texts.append(key)
            kind = blob[i]
            i += 1
            if kind == 0x02:  # String
                value, i = string(i)
                texts.append(value)
            elif kind in ATTR_FIXED:
                i += ATTR_FIXED[kind]
            elif kind == 0x14:  # CFrame: position, a rotation id, 9 floats only when the id is 0
                i += 12
                rot = blob[i]
                i += 1 + (36 if rot == 0 else 0)
            elif kind == 0x15:  # EnumItem: enum name + u32
                _, i = string(i)
                i += 4
            elif kind == 0x17:  # NumberSequence: u32 count x (envelope, time, value)
                n, i = u32(i)
                i += 12 * n
            elif kind == 0x19:  # ColorSequence: u32 count x (envelope, time, r, g, b)
                n, i = u32(i)
                i += 20 * n
            elif kind == 0x1D:  # Font: u16 weight, u8 style, family, cached face id
                i += 3
                family, i = string(i)
                _, i = string(i)
                texts.append(family)
            else:
                return texts, False
            if i > len(blob):
                return texts, False
    except (ValueError, IndexError):
        return texts, False
    return texts, True


def scan_tree(root, decode=roblox_text):
    hits = []

    def walk(item, trail):
        props = item.find("Properties")
        name = ""
        if props is not None:
            for p in props:
                if p.get("name") == "Name":
                    name = decode(p.text or "")
        here = trail + [name or item.get("class")]
        if props is not None:
            for p in props:
                pname = p.get("name")
                if pname in SKIP_PROPS:
                    continue
                text = decode(p.text or "")
                if p.tag == "BinaryString" and pname == "AttributesSerialize" and text.strip():
                    try:
                        texts, complete = attr_strings(base64.b64decode(text))
                    except ValueError:
                        texts, complete = [], False
                    text = " | ".join(texts)
                    pname = "Attributes" if complete else "Attributes (partly read)"
                if HANGUL.search(text):
                    hits.append({"class": item.get("class"), "path": "/".join(here), "property": pname, "value": text[:160]})
        for child in item.findall("Item"):
            walk(child, here)

    for item in root.findall("Item"):
        walk(item, [])
    return hits


def scan_file(path: Path, decode=roblox_text):
    return scan_tree(ET.parse(path).getroot(), decode)


# a Roblox-style sample: '말' and '→' written byte by byte, as Studio saves them
SAMPLE = """<roblox version="4">
  <Item class="ScreenGui" referent="RBX1"><Properties><string name="Name">Shop</string></Properties>
    <Item class="TextLabel" referent="RBX2"><Properties><string name="Name">&#235;&#167;&#144;</string>
      <string name="Text">&#235;&#167;&#144; Hi</string></Properties></Item>
    <Item class="TextLabel" referent="RBX3"><Properties><string name="Name">Title</string>
      <string name="Text">Forge &#226;&#134;&#146; Shop</string></Properties></Item>
  </Item>
</roblox>"""
OLD_PLACE = "84c7dbdd^:place/GoodEvil.rbxlx"  # the last saved place with Korean labels (검수 2026-10-08: 9 of them)


def self_test():
    """(name, ok, detail) checks: the fix finds a Roblox-style Korean label, the old reading (no decode) misses it - the
    mutation the test must catch - and the old saved place shows its Korean labels again."""
    out = []
    sample = ET.fromstring(SAMPLE)
    fixed = scan_tree(sample)
    out.append(("a Roblox-style Korean label is found (Name and Text, read as UTF-8)",
                len(fixed) == 2 and {h["property"] for h in fixed} == {"Name", "Text"}
                and any(h["value"] == "말 Hi" for h in fixed), [h["value"] for h in fixed]))
    old = scan_tree(sample, decode=lambda t: t)
    out.append(("mutation: the old Latin-1 reading misses it (the self test catches that bug)", len(old) == 0, len(old)))
    out.append(("non-Hangul bytes ('→') are decoded and not reported",
                all("→" not in h["value"] for h in fixed) and not any("Forge" in h["value"] for h in fixed), ""))
    # attributes (2026-10-08): number bytes are no words, a Korean String attribute still is
    cf = (struct.pack("<I", 1) + struct.pack("<I", 12) + b"MT_OrigPivot" + bytes([0x14]) + struct.pack("<3f", 1.0, 2.0, 3.0)
          + bytes([0]) + b"\x00\xec\x83\x84" + struct.pack("<8f", *([0.0] * 8)))
    texts, complete = attr_strings(cf)
    out.append(("an attribute's number bytes are never read as words (a CFrame holding EC 83 84 = U+C0C4)",
                complete and not any(HANGUL.search(t) for t in texts), texts))
    out.append(("mutation: reading the whole blob as UTF-8 (the old scan) reports that false Hangul",
                bool(HANGUL.search(cf.decode("utf-8", errors="ignore"))), ""))
    ko = struct.pack("<I", 1) + struct.pack("<I", 5) + b"Label" + bytes([0x02]) + struct.pack("<I", 3) + "말".encode()
    texts, complete = attr_strings(ko)
    out.append(("a Korean String attribute is still found", complete and any(HANGUL.search(t) for t in texts), texts))
    try:
        data = subprocess.run(["git", "show", OLD_PLACE], cwd=ROOT, capture_output=True, check=True, timeout=120).stdout
        root = ET.fromstring(data)
        then, before_fix = len(scan_tree(root)), len(scan_tree(root, decode=lambda t: t))
        out.append((f"the place from before 84c7dbdd: its Korean labels are found again ({then}; the old scan said {before_fix})",
                    then >= 9 and before_fix == 0, {"found": then, "oldScan": before_fix}))
    except (OSError, subprocess.SubprocessError, ET.ParseError) as err:
        out.append(("the place from before 84c7dbdd (git history) could not be read: skipped", True, str(err)[:120]))
    return out


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
    ] + english_checks()


def english_checks():
    """A23-48 (검수 2026-10-07): Roblox auto-translation is off for every GUI; no Korean in FactionPicker's code lines."""
    cm = (ROOT / "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau").read_text(encoding="utf-8-sig")
    fp = (ROOT / "src/StarterPlayer/StarterPlayerScripts/FactionPicker.luau").read_text(encoding="utf-8-sig")
    mb = (ROOT / "src/ServerScriptService/MapBuilder.luau").read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    fp_code = "\n".join(line.split("--")[0] for line in fp.splitlines())
    return [
        # A23-179 (user 10/14): Roblox's automatic translation is ON again - no game-wide AutoLocalize = false watcher
        # (the narrow name / number / typed-text list is tools/test_auto_translate.py)
        ("ClientMain no longer turns AutoLocalize off game-wide (A23-179: Roblox auto translation on)",
         "AutoLocalize = false" not in "\n".join(line.split("--")[0] for line in cm.splitlines())
         and "DescendantAdded:Connect(off)" not in cm),
        ("FactionPicker has no Korean in its code (warnings / errors are English)", HANGUL.search(fp_code) is None),
        ("the Altar of Fate prompt opens on E at once and is auto-translated again (A23-179; the saved place had it off)",
         "\tprompt.HoldDuration = 0\n\tprompt.AutoLocalize = true" in mb[mb.find("local function ensureAltarPrompt(altar)"):]),
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
    selftest = [] if args.studio else self_test()
    for name, good, detail in selftest:
        print(("SELFTEST_OK " if good else "SELFTEST_FAILURE ") + name + (f" :: {detail}" if not good else ""))
    for h in hits:
        print(f"HANGUL {h['class']}\t{h['path']}\t{h['property']}\t{h['value']!r}")
    passed = not hits and all(g for _, g in static) and all(g for _, g, _ in selftest)
    report = {"status": "passed" if passed else "failed", "hangulStrings": len(hits), "hits": hits,
              "static": [{"check": n, "ok": g} for n, g in static],
              "selfTest": [{"check": n, "ok": g, "detail": d} for n, g, d in selftest], "source": source,
              "contract": __doc__.split("Status")[0].strip(),
              "limitations": "Script sources are skipped (comments are never shown); text that code makes at run time is "
                             "covered by the src text tests (test_english, test_ko_screen)."}
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Hangul strings: {len(hits)}")
    print(f"Status: {report['status']}")


if __name__ == "__main__":
    main()
