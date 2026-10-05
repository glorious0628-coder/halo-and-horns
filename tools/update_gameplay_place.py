"""Preserve GoodEvil XML bytes while updating the listed gameplay ModuleScripts.

Default is read-only validation. --apply creates verified ignored backups and
updates only the two hard-coded GoodEvil places. XML parsing, source byte-span
replacement and non-target preservation checks reuse update_faction_place.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os

import update_faction_place as xml_update

ROOT = xml_update.ROOT
PLACE_PATHS = ("build/GoodEvil.rbxlx", "place/GoodEvil.rbxlx")
SOURCES = {
    "ReplicatedStorage/Shared/Config": "src/ReplicatedStorage/Shared/Config.luau",
    "ReplicatedStorage/Shared/Net": "src/ReplicatedStorage/Shared/Net.luau",
    "StarterPlayer/StarterPlayerScripts/CameraFollow": "src/StarterPlayer/StarterPlayerScripts/CameraFollow.luau",
    "StarterPlayer/StarterPlayerScripts/ClassPicker": "src/StarterPlayer/StarterPlayerScripts/ClassPicker.luau",
    "StarterPlayer/StarterPlayerScripts/FactionPicker": "src/StarterPlayer/StarterPlayerScripts/FactionPicker.luau",
    "StarterPlayer/StarterPlayerScripts/Fx": "src/StarterPlayer/StarterPlayerScripts/Fx.luau",
    "StarterPlayer/StarterPlayerScripts/HUD": "src/StarterPlayer/StarterPlayerScripts/HUD.luau",
    "StarterPlayer/StarterPlayerScripts/Panels": "src/StarterPlayer/StarterPlayerScripts/Panels.luau",
    "ServerScriptService/QuestService": "src/ServerScriptService/QuestService.luau",
    "ServerScriptService/DataService": "src/ServerScriptService/DataService.luau",
    "ServerScriptService/ShopService": "src/ServerScriptService/ShopService.luau",
    "ServerScriptService/CombatService": "src/ServerScriptService/CombatService.luau",
}
AUDIT = "docs/art/verification_2026-10-04/gameplay_10min/place_update.json"


def prepare(data: bytes, texts: dict[str, str]):
    """Temporarily configure the imported engine; never alter its file or other targets."""
    if set(texts) != set(SOURCES):
        raise ValueError("Exactly the listed gameplay sources are required")
    previous = xml_update.SOURCES
    try:
        xml_update.SOURCES = SOURCES
        updated, checks = xml_update.prepare(data, texts)
    finally:
        xml_update.SOURCES = previous
    checks["all_sources_match_files"] = checks.pop("both_sources_match_files")
    checks["allowed_source_count"] = len(SOURCES)
    return updated, checks


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Back up and update only build/place GoodEvil.rbxlx")
    args = parser.parse_args()
    paths = [xml_update.fixed_path(relative) for relative in PLACE_PATHS]
    originals = [path.read_bytes() for path in paths]
    if originals[0] != originals[1]:
        raise ValueError("The two GoodEvil originals must be byte-identical before this helper can apply")
    source_bytes = {key: xml_update.fixed_path(relative).read_bytes() for key, relative in SOURCES.items()}
    texts = {key: value.decode("utf-8").replace("\r\n", "\n").replace("\r", "\n")
             for key, value in source_bytes.items()}
    updated, checks = prepare(originals[0], texts)
    second, _ = prepare(updated, texts)
    if second != updated:
        raise ValueError("Idempotence failed: a second run would alter the place")
    checks["second_run_byte_identical"] = True
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    report = {
        "schema": 1, "status": "validated_no_write", "timestamp_utc": stamp,
        "originals_identical": True, "original_bytes": len(originals[0]),
        "original_sha256": xml_update.sha(originals[0]), "updated_bytes": len(updated),
        "updated_sha256": xml_update.sha(updated), "changed": updated != originals[0],
        "allowed_places": list(PLACE_PATHS), "allowed_sources": SOURCES,
        "checks": checks, "targets": [],
    }
    if args.apply:
        backup_dir = xml_update.fixed_path(f"build/gameplay_source_backups/{stamp}")
        backup_dir.mkdir(parents=True, exist_ok=False)
        for relative, original in zip(PLACE_PATHS, originals):
            backup = xml_update.fixed_path(
                f"build/gameplay_source_backups/{stamp}/{relative.split('/')[0]}_GoodEvil.rbxlx")
            with backup.open("xb") as stream:
                stream.write(original)
                stream.flush()
                os.fsync(stream.fileno())
            if backup.read_bytes() != original:
                raise ValueError("Backup verification failed; original places were not changed")
            report["targets"].append({
                "path": relative, "backup": backup.relative_to(ROOT).as_posix(),
                "backup_sha256": xml_update.sha(original),
            })

        def verify_snapshot() -> None:
            for key, relative in SOURCES.items():
                if xml_update.fixed_path(relative).read_bytes() != source_bytes[key]:
                    raise ValueError("Source changed during preflight/staging; no replacement was performed")
            for path, original in zip(paths, originals):
                if path.read_bytes() != original:
                    raise ValueError("Place changed during preflight/staging; no replacement was performed")

        verify_snapshot()
        staged = []
        for path in paths:
            temporary = xml_update.fixed_path(path.relative_to(ROOT).as_posix() + f".gameplay_{stamp}.tmp")
            with temporary.open("xb") as stream:
                stream.write(updated)
                stream.flush()
                os.fsync(stream.fileno())
            if temporary.read_bytes() != updated:
                raise ValueError("Staged bytes differ; originals and verified backups are retained")
            staged.append(temporary)
        verify_snapshot()
        # No XML serialization or whole-place rebuild: only the verified source-body byte replacements.
        for path, temporary in zip(paths, staged):
            os.replace(temporary, path)
        for path in paths:
            if path.read_bytes() != updated:
                raise ValueError("Final verification failed; restore the recorded verified backup")
        report["status"] = "applied_and_verified"
        report["final_files_identical"] = True
        audit = xml_update.fixed_path(AUDIT)
        audit.parent.mkdir(parents=True, exist_ok=True)
        audit.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
