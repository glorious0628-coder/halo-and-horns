"""Preserve GoodEvil XML bytes while installing the two camera client sources.

Without --apply, validate both fixed files and print an audit without writing.
With --apply, save verified backups under build/, then replace only ClientMain's
Source and CameraFollow's Source (or insert that one ModuleScript if absent).
No arbitrary place or source paths are accepted.
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
PARENT = "StarterPlayer/StarterPlayerScripts"
CLIENT = PARENT + "/ClientMain"
CAMERA = PARENT + "/CameraFollow"
SOURCES = {
    CLIENT: "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau",
    CAMERA: "src/StarterPlayer/StarterPlayerScripts/CameraFollow.luau",
}
CLASSES = {CLIENT: "LocalScript", CAMERA: "ModuleScript"}
AUDIT = "docs/art/verification_2026-10-04/camera_follow/place_update.json"
CAMERA_REFERENT = "RBX" + hashlib.sha256(b"halo-and-horns:" + CAMERA.encode()).hexdigest()[:32].upper()


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def fixed_path(relative: str) -> Path:
    path = ROOT / relative
    if path.resolve() != path or not path.is_relative_to(ROOT):
        raise ValueError(f"Symlinks, junctions and external paths are forbidden: {relative}")
    return path


def reject_doctype(*_args):
    raise ValueError("DTD/entity declarations are not accepted")


def xml_offsets(data: bytes):
    """Read exact Item and Source byte spans without serializing the place."""
    parser = expat.ParserCreate()
    parser.StartDoctypeDeclHandler = reject_doctype
    parser.EntityDeclHandler = reject_doctype
    stack, items, spans, sources = [], [], {}, {}
    current = None

    def start(name, attrs):
        nonlocal current
        offset = parser.CurrentByteIndex
        if name == "Item":
            ref = attrs.get("referent")
            if not ref or ref in spans:
                raise ValueError("Missing or duplicate Item referent")
            spans[ref] = {"begin": offset}
            items.append(ref)
        if name == "ProtectedString" and attrs.get("name") == "Source" and stack[-1:] == ["Properties"]:
            if not items or current is not None:
                raise ValueError("Unexpected Source nesting")
            end = data.find(b">", offset)
            if end < 0 or data[end - 1:end] == b"/":
                raise ValueError("Source must have explicit opening and closing tags")
            current = (items[-1], end + 1)
        stack.append(name)

    def end(name):
        nonlocal current
        if name == "ProtectedString" and current is not None:
            ref, begin = current
            if ref in sources:
                raise ValueError("Duplicate Source")
            sources[ref] = (begin, parser.CurrentByteIndex)
            current = None
        stack.pop()
        if name == "Item":
            ref = items.pop()
            closing = parser.CurrentByteIndex
            if data[closing:closing + 7] != b"</Item>":
                raise ValueError("Item must have an explicit closing tag")
            spans[ref].update(close=closing, end=closing + 7)

    parser.StartElementHandler = start
    parser.EndElementHandler = end
    parser.Parse(data, True)
    return spans, sources


def inspect_xml(data: bytes):
    spans, sources = xml_offsets(data)  # Reject DTDs before ElementTree reads.
    root = ET.fromstring(data)
    if root.tag != "roblox":
        raise ValueError("Expected a Roblox place")
    targets, containers = {}, []

    def visit(item, parent):
        props = item.find("Properties")
        names = [] if props is None else props.findall("string[@name='Name']")
        if len(names) != 1 or not names[0].text:
            raise ValueError("Expected exactly one nonempty instance Name")
        path = "/".join((*parent, names[0].text))
        ref = item.get("referent")
        if path == PARENT:
            if item.get("class") != "StarterPlayerScripts":
                raise ValueError("Unexpected StarterPlayerScripts class")
            containers.append({"item": item, "span": spans[ref]})
        if path in SOURCES:
            nodes = props.findall("ProtectedString[@name='Source']")
            if path in targets or item.get("class") != CLASSES[path] or len(nodes) != 1 or ref not in sources:
                raise ValueError(f"Ambiguous or invalid target: {path}")
            targets[path] = {"item": item, "node": nodes[0], "source_span": sources[ref],
                             "item_span": spans[ref], "referent": ref}
        for child in item.findall("Item"):
            visit(child, (*parent, names[0].text))

    for item in root.findall("Item"):
        visit(item, ())
    if len(containers) != 1 or CLIENT not in targets:
        raise ValueError("Expected one StarterPlayerScripts container and one ClientMain")
    return root, targets, containers[0], spans


def cdata(text: str) -> bytes:
    return ("<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>").encode("utf-8")


def exclude_ranges(data: bytes, ranges):
    chunks, cursor = [], 0
    for begin, end in sorted(ranges):
        if begin < cursor or end < begin:
            raise ValueError("Overlapping edit ranges")
        chunks.append(data[cursor:begin])
        cursor = end
    chunks.append(data[cursor:])
    return b"".join(chunks)


def fingerprint(root, targets, container, exclude_camera):
    for path, row in targets.items():
        if path == CAMERA and exclude_camera:
            container["item"].remove(row["item"])
        else:
            row["node"].text = "SOURCE_BODY_EXCLUDED_FROM_PRESERVATION_CHECK"
    assets = [{"tag": node.tag, "attributes": node.attrib, "text": node.text}
              for node in root.iter() if node.text and any(
                  token in node.text for token in ("rbxassetid://", "rbxasset://", "roblox.com/asset"))]
    return {"preserved_structure_sha256": sha(ET.tostring(root, encoding="utf-8")),
            "asset_fields_outside_target_sources_count": len(assets),
            "asset_fields_outside_target_sources_sha256": sha(
                json.dumps(assets, ensure_ascii=False, sort_keys=True).encode("utf-8"))}


def prepare(data: bytes, texts: dict[str, str]):
    root, targets, container, spans = inspect_xml(data)
    added = CAMERA not in targets
    edits, changes = [], []
    for path, row in targets.items():
        begin, end = row["source_span"]
        body = data[begin:end] if (row["node"].text or "") == texts[path] else cdata(texts[path])
        edits.append((begin, end, body))
        changes.append({"instance_path": path, "source_file": SOURCES[path],
                        "referent": row["referent"], "operation": "source_update",
                        "changed": body != data[begin:end], "source_sha256": sha(texts[path].encode())})
    if added:
        if CAMERA_REFERENT in spans:
            raise ValueError("The new CameraFollow referent collides with an existing instance")
        body = (f'<Item class="ModuleScript" referent="{CAMERA_REFERENT}"><Properties>'
                '<Content name="LinkedSource"><null></null></Content>'
                '<ProtectedString name="Source">').encode() + cdata(texts[CAMERA]) + (
                    '</ProtectedString><string name="Name">CameraFollow</string>'
                    '<int64 name="SourceAssetId">-1</int64></Properties></Item>').encode()
        begin = container["span"]["close"]
        edits.append((begin, begin, body))
        changes.append({"instance_path": CAMERA, "source_file": SOURCES[CAMERA],
                        "referent": CAMERA_REFERENT, "operation": "insert_module", "changed": True,
                        "source_sha256": sha(texts[CAMERA].encode())})
    chunks, cursor = [], 0
    for begin, end, replacement in sorted(edits):
        if begin < cursor:
            raise ValueError("Overlapping camera edits")
        chunks.extend((data[cursor:begin], replacement))
        cursor = end
    updated = b"".join((*chunks, data[cursor:]))
    after_root, after_targets, after_container, after_spans = inspect_xml(updated)
    if set(after_targets) != set(SOURCES):
        raise ValueError("Missing target source after update")
    for path, row in after_targets.items():
        if row["node"].text != texts[path]:
            raise ValueError(f"Source readback mismatch: {path}")
    before_kept = exclude_ranges(data, [row["source_span"] for row in targets.values()])
    after_ranges = []
    for path, row in after_targets.items():
        after_ranges.append((row["item_span"]["begin"], row["item_span"]["end"])
                            if path == CAMERA and added else row["source_span"])
    if before_kept != exclude_ranges(updated, after_ranges):
        raise ValueError("Bytes outside the allowed source edits and new ModuleScript changed")
    before_fingerprint = fingerprint(root, targets, container, False)
    if before_fingerprint != fingerprint(after_root, after_targets, after_container, added):
        raise ValueError("Existing instance structure, properties or asset fields changed")
    if len(after_spans) != len(spans) + int(added):
        raise ValueError("Unexpected instance count change")
    return updated, {"instances_before": len(spans), "instances_after": len(after_spans),
                     "camera_module_added": added, "source_changes": changes,
                     "all_other_bytes_unchanged": True, "both_sources_match_files": True,
                     "preserved_bytes_sha256": sha(before_kept), **before_fingerprint}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    paths = [fixed_path(relative) for relative in PLACE_PATHS]
    originals = [path.read_bytes() for path in paths]
    if originals[0] != originals[1]:
        raise ValueError("The two GoodEvil files differ; refusing to overwrite either file")
    source_bytes = {key: fixed_path(relative).read_bytes() for key, relative in SOURCES.items()}
    texts = {key: value.decode("utf-8").replace("\r\n", "\n").replace("\r", "\n")
             for key, value in source_bytes.items()}
    updated, checks = prepare(originals[0], texts)
    second, _ = prepare(updated, texts)
    if second != updated:
        raise ValueError("A second run would change the place: idempotence failed")
    checks["second_run_byte_identical"] = True
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    report = {"schema": 1, "status": "validated_no_write", "timestamp_utc": stamp,
              "originals_identical": True, "original_sha256": sha(originals[0]),
              "original_bytes": len(originals[0]), "updated_sha256": sha(updated),
              "updated_bytes": len(updated), "changed": updated != originals[0],
              "checks": checks, "targets": []}
    if args.apply:
        backup_relative = f"build/camera_source_backups/{stamp}"
        fixed_path(backup_relative).mkdir(parents=True, exist_ok=False)
        for relative, original in zip(PLACE_PATHS, originals):
            backup = fixed_path(f"{backup_relative}/{relative.split('/')[0]}_GoodEvil.rbxlx")
            with backup.open("xb") as stream:
                stream.write(original)
            if backup.read_bytes() != original:
                raise ValueError("Backup verification failed; originals were not changed")
            report["targets"].append({"path": relative, "backup": backup.relative_to(ROOT).as_posix(),
                                      "backup_sha256": sha(original)})
        for key, relative in SOURCES.items():
            if fixed_path(relative).read_bytes() != source_bytes[key]:
                raise ValueError("Source changed during preflight; rerun on a stable snapshot")
        for path, original in zip(paths, originals):
            if path.read_bytes() != original:
                raise ValueError("Place changed during preflight; originals were not changed")
        staged = []
        for path in paths:
            temporary = fixed_path(path.relative_to(ROOT).as_posix() + f".camera_{stamp}.tmp")
            with temporary.open("xb") as stream:
                stream.write(updated)
                stream.flush()
                os.fsync(stream.fileno())
            if temporary.read_bytes() != updated:
                raise ValueError("Staged write verification failed; verified backups remain")
            staged.append(temporary)
        for path, original in zip(paths, originals):
            if path.read_bytes() != original:
                raise ValueError("Place changed while staging; no replacement was performed")
        for path, temporary in zip(paths, staged):
            os.replace(temporary, path)
        for path in paths:
            if path.read_bytes() != updated:
                raise ValueError("Final verification failed; use the recorded verified backup")
        report.update(status="applied_and_verified", final_files_identical=True)
        audit = fixed_path(AUDIT)
        audit.parent.mkdir(parents=True, exist_ok=True)
        audit.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
