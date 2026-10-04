"""Update only HUD/Config Source text in the two fixed GoodEvil XML files.

Default: validate and report without writing. --apply: make ignored backups,
replace the two source bodies, verify every other byte, and save the audit JSON.
No output path or arbitrary script selection is accepted.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path
import xml.etree.ElementTree as ET
from xml.parsers import expat


ROOT = Path(__file__).resolve().parents[1]
PLACE_PATHS = ("build/GoodEvil.rbxlx", "place/GoodEvil.rbxlx")
SOURCES = {
    "StarterPlayer/StarterPlayerScripts/HUD": "src/StarterPlayer/StarterPlayerScripts/HUD.luau",
    "ReplicatedStorage/Shared/Config": "src/ReplicatedStorage/Shared/Config.luau",
}
AUDIT = "docs/art/verification_2026-10-04/hud_portrait/place_source_update_actual.json"


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def fixed_path(relative: str) -> Path:
    path = ROOT / relative
    if path.resolve() != path or not path.is_relative_to(ROOT):
        raise ValueError(f"Symlinks/junctions or paths outside this repository are forbidden: {relative}")
    return path


def reject_doctype(*_args):
    raise ValueError("DTD/entity declarations are not accepted in a place file")


def source_spans(data: bytes) -> dict[str, tuple[int, int]]:
    """Expat byte offsets let us retain the original XML without reserializing it."""
    parser = expat.ParserCreate()
    parser.StartDoctypeDeclHandler = reject_doctype
    parser.EntityDeclHandler = reject_doctype
    elements: list[str] = []
    items: list[str] = []
    found: dict[str, tuple[int, int]] = {}
    current: tuple[str, int] | None = None

    def start(name, attrs):
        nonlocal current
        if name == "Item":
            items.append(attrs.get("referent", ""))
        if name == "ProtectedString" and attrs.get("name") == "Source" and elements[-1:] == ["Properties"]:
            if not items or current is not None:
                raise ValueError("Unexpected nested Source")
            offset = parser.CurrentByteIndex
            end = data.find(b">", offset)
            if end < 0 or data[end - 1:end] == b"/":
                raise ValueError("Source must have an explicit opening and closing tag")
            current = (items[-1], end + 1)
        elements.append(name)

    def end(name):
        nonlocal current
        if name == "ProtectedString" and current is not None:
            referent, begin = current
            if referent in found:
                raise ValueError(f"Duplicate Source for referent {referent}")
            found[referent] = (begin, parser.CurrentByteIndex)
            current = None
        elements.pop()
        if name == "Item":
            items.pop()

    parser.StartElementHandler = start
    parser.EndElementHandler = end
    parser.Parse(data, True)
    return found


def inspect_xml(data: bytes):
    spans = source_spans(data)  # Reject DTDs before the separate structural parser.
    root = ET.fromstring(data)
    if root.tag != "roblox":
        raise ValueError("Expected a Roblox place XML root")
    matched = {}
    referents = set()

    def visit(item, parent):
        referent = item.get("referent")
        if not referent or referent in referents:
            raise ValueError("Missing or duplicate instance referent")
        referents.add(referent)
        props = item.find("Properties")
        names = [] if props is None else props.findall("string[@name='Name']")
        if len(names) != 1 or not names[0].text:
            raise ValueError("Each instance must have exactly one nonempty Name")
        path = "/".join((*parent, names[0].text))
        if path in SOURCES:
            nodes = props.findall("ProtectedString[@name='Source']")
            if path in matched or item.get("class") != "ModuleScript" or len(nodes) != 1 or referent not in spans:
                raise ValueError(f"Ambiguous or invalid target script: {path}")
            matched[path] = {"node": nodes[0], "span": spans[referent], "referent": referent}
        for child in item.findall("Item"):
            visit(child, (*parent, names[0].text))

    for item in root.findall("Item"):
        visit(item, ())
    if set(matched) != set(SOURCES):
        raise ValueError(f"Missing expected scripts: {set(SOURCES) - set(matched)}")
    return root, matched, len(referents)


def fingerprint(root, targets):
    for row in targets.values():
        row["node"].text = "SOURCE_BODY_EXCLUDED_FROM_PRESERVATION_CHECK"
    # Preserve every asset-bearing field outside the two intentionally updated sources.
    assets = [
        {"tag": node.tag, "attributes": node.attrib, "text": node.text}
        for node in root.iter()
        if node.text and any(token in node.text for token in ("rbxassetid://", "rbxasset://", "roblox.com/asset"))
    ]
    return {
        "xml_except_target_sources_sha256": sha(ET.tostring(root, encoding="utf-8")),
        "asset_fields_outside_target_sources_count": len(assets),
        "asset_fields_outside_target_sources_sha256": sha(json.dumps(assets, ensure_ascii=False, sort_keys=True).encode("utf-8")),
    }


def prepare(data: bytes, texts: dict[str, str]):
    root, targets, count = inspect_xml(data)
    ranges = sorted((row["span"][0], row["span"][1], path) for path, row in targets.items())
    before_fingerprint = fingerprint(root, targets)
    chunks, preserved, replacements = [], [], []
    cursor = 0
    for begin, end, path in ranges:
        unchanged = data[cursor:begin]
        body = ("<![CDATA[" + texts[path].replace("]]>", "]]]]><![CDATA[>") + "]]>").encode("utf-8")
        chunks.extend((unchanged, body))
        preserved.append(unchanged)
        replacements.append({"instance_path": path, "referent": targets[path]["referent"],
                             "source_file": SOURCES[path], "old_body_bytes": end - begin,
                             "new_body_bytes": len(body), "source_sha256": sha(texts[path].encode("utf-8"))})
        cursor = end
    chunks.append(data[cursor:])
    preserved.append(data[cursor:])
    updated = b"".join(chunks)
    after_root, after_targets, after_count = inspect_xml(updated)
    for path, row in after_targets.items():
        if row["node"].text != texts[path]:
            raise ValueError(f"Source readback mismatch: {path}")
    after_preserved, cursor = [], 0
    for begin, end in sorted(row["span"] for row in after_targets.values()):
        after_preserved.append(updated[cursor:begin])
        cursor = end
    after_preserved.append(updated[cursor:])
    if preserved != after_preserved:
        raise ValueError("Bytes outside the two Source bodies changed")
    if count != after_count or before_fingerprint != fingerprint(after_root, after_targets):
        raise ValueError("Instance structure or non-target XML properties changed")
    return updated, {"instance_count": count, "source_replacements": replacements,
                     "all_other_bytes_unchanged": True,
                     "untouched_bytes_sha256": sha(b"".join(preserved)), **before_fingerprint}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Back up and update only build/place GoodEvil.rbxlx")
    args = parser.parse_args()
    paths = [fixed_path(relative) for relative in PLACE_PATHS]
    originals = [path.read_bytes() for path in paths]
    if originals[0] != originals[1]:
        raise ValueError("The two GoodEvil originals must match byte for byte before this helper can apply")
    source_bytes = {key: fixed_path(relative).read_bytes() for key, relative in SOURCES.items()}
    texts = {key: value.decode("utf-8").replace("\r\n", "\n").replace("\r", "\n") for key, value in source_bytes.items()}
    updated, checks = prepare(originals[0], texts)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    report = {"schema": 1, "status": "validated_no_write", "timestamp_utc": stamp,
              "originals_identical": True, "original_bytes": len(originals[0]),
              "original_sha256": sha(originals[0]), "updated_bytes": len(updated),
              "updated_sha256": sha(updated), "checks": checks, "targets": []}
    if args.apply:
        backup_dir = fixed_path(f"build/source_backups/{stamp}")
        backup_dir.mkdir(parents=True, exist_ok=False)
        for relative, original in zip(PLACE_PATHS, originals):
            backup = fixed_path(f"build/source_backups/{stamp}/{relative.split('/')[0]}_GoodEvil.rbxlx")
            with backup.open("xb") as stream:
                stream.write(original)
            if backup.read_bytes() != original:
                raise ValueError("Backup verification failed; original places were not changed")
            report["targets"].append({"path": relative, "backup": backup.relative_to(ROOT).as_posix(), "backup_sha256": sha(original)})
        for key, relative in SOURCES.items():
            if fixed_path(relative).read_bytes() != source_bytes[key]:
                raise ValueError("Source changed during preflight; rerun with a stable source snapshot")
        for path, original in zip(paths, originals):
            if path.read_bytes() != original:
                raise ValueError("Place changed during preflight; no update was applied")
        # Writes are limited to these two explicit fixed paths. Do not rebuild/serialize the place tree.
        for path in paths:
            temporary = fixed_path(path.relative_to(ROOT).as_posix() + f".sources_{stamp}.tmp")
            with temporary.open("xb") as stream:
                stream.write(updated)
                stream.flush()
                os.fsync(stream.fileno())
            if temporary.read_bytes() != updated:
                raise ValueError("Staged bytes differ; the original and verified backup are retained")
            os.replace(temporary, path)
        for path in paths:
            if path.read_bytes() != updated:
                raise ValueError("Final file verification failed; restore the recorded verified backup")
        report["status"] = "applied_and_verified"
        report["final_files_identical"] = True
        audit = fixed_path(AUDIT)
        audit.parent.mkdir(parents=True, exist_ok=True)
        audit.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
