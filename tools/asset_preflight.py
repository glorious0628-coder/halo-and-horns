"""승인 대상 아트 파일을 읽고 build/asset_preflight.json에 점검 목록을 저장한다.

  py tools/asset_preflight.py

파일 업로드, API 호출, 소스/에셋 수정 기능은 없다. 업로드 목록은 아래 고정 목록만
사용하며 art/ui/*.png 전체나 art/out/v1/를 대상으로 삼지 않는다.

2026-10-06: 치비 3D 코스튬이 게임에서 빠져(A23-5) 코스튬 18종 점검(CostumeService·
art/models/costume·APose 그림 참조)을 뺐다. 나머지 UI·글자·무기·텍스처·지도·몬스터 점검은 그대로다.
"""

from __future__ import annotations

import json
import re
import struct
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "build" / "asset_preflight.json"
CONFIG = ROOT / "src" / "ReplicatedStorage" / "Shared" / "Config.luau"
KST = timezone(timedelta(hours=9))
FACTIONS = ("Halo", "Horns", "Neutral")
CLASSES = ("Warrior", "Mage", "Archer")
GENDERS = ("M", "F")

# 현재 게임에서 쓰는 68개와 효과/스티커 10개만 허용한다.
UI_BASE = (
    "PanelParchment", "PanelCard", "RibbonHeader", "Pill", "BarTrack", "BtnSquare",
    "BtnAttack", "BtnSpecial", "LevelBadge", "PortraitRing", "ShieldHalo", "ShieldHorns", "Crown",
    "IconCoin", "IconPouch", "IconSword", "IconAttack", "IconSpecial", "IconLock", "IconMap",
    "IconGear", "IconGoose", "IconSafe", "IconSprout", "IconStar", "IconStarEmpty", "IconClover",
    "IconScroll", "IconSlime", "CardHalo", "CardHorns", "CardNeutral", "ClassCardHalo",
    "ClassCardHorns", "ClassCardNeutral", "ShieldNeutral", "TitleRibbon",
    "IconExp", "IconHeart", "IconWings", "IconGoldPile", "IconBloodSword", "IconGauge",
    "IconDemon", "IconNoBuff", "IconShieldBlue", "IconNoLoot", "IconHammer", "IconAltar", "IconBoot",
)
CHARACTERS = tuple(f"Char{f}{c}{g}" for f in FACTIONS for c in CLASSES for g in GENDERS)
FX_EMO = (
    "FxSlash", "FxHitSpark", "FxShockRing", "FxMagicBurst", "FxDust",
    "EmoOuch", "EmoTears", "EmoDizzy", "EmoAngry", "EmoStress",
)
TEXT_KEYS = (
    "Attack", "Release", "Menu", "Map", "Claim", "Reroll", "Quests", "Light", "Horn", "Safe",
    "Rookie", "Regular", "CheerStars", "Next", "PickFaction", "PickClass", "ThisSide", "ThisClass",
    "Halo", "Horns", "Neutral", "Paladin", "LightMage", "Ranger", "Berserker", "DarkMage",
    "ShadowHunter", "Blacksmith", "Alchemist", "Hunter", "Male", "Female", "LevelUp", "GoldenGoose",
    "Crossroads", "HaloTown", "HornsTown", "Meadow", "GoblinWoods", "SkeletonRuins", "SafeZone", "PvPZone",
)
TEXTURES = (
    "Grass", "LeafyGrass", "HaloTiles", "Ground", "DirtPath", "CrownShardGround", "CrackedLava",
    "Cobblestone", "Basalt", "WoodPlanks", "Slate", "Sand", "Rock", "Marble", "Limestone",
)
MONSTERS = ("Slime", "Goblin", "GoblinBrute", "Skeleton", "SkeletonKnight", "GoldenGoose", "SkeletonKing")


def relative(path: Path) -> str:
    """Workspace 밖과 폐기 폴더는 점검 대상 경로로도 허용하지 않는다."""
    resolved = path.resolve()
    rel = resolved.relative_to(ROOT)
    if rel.parts[:3] == ("art", "out", "v1"):
        raise ValueError("art/out/v1/ 파일은 점검/업로드 대상에서 제외합니다")
    return rel.as_posix()


def read_json(path: Path) -> dict:
    if not path.is_file():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"JSON 객체가 아닙니다: {relative(path)}")
    return data


def file_info(path: Path) -> dict:
    result = {"path": relative(path), "exists": path.is_file(), "bytes": None}
    if not result["exists"]:
        return result
    result["bytes"] = path.stat().st_size
    if path.suffix.lower() == ".png":
        try:
            with Image.open(path) as image:
                result.update(width=image.width, height=image.height, mode=image.mode)
        except (OSError, ValueError) as error:
            result["error"] = str(error)
    elif path.suffix.lower() == ".glb":
        try:
            with path.open("rb") as stream:
                header = stream.read(20)
                magic, version, total, chunk_size, chunk_type = struct.unpack("<5I", header)
                if magic != 0x46546C67 or version != 2 or chunk_type != 0x4E4F534A:
                    raise ValueError("GLB v2 JSON 헤더가 아닙니다")
                if total != result["bytes"] or chunk_size > 16 * 1024 * 1024:
                    raise ValueError("GLB 파일/JSON 청크 용량이 올바르지 않습니다")
                data = json.loads(stream.read(chunk_size))
            result["glb"] = {
                "meshes": len(data.get("meshes", [])),
                "skins": len(data.get("skins", [])),
                "animations": len(data.get("animations", [])),
                "images": len(data.get("images", [])),
            }
        except (OSError, ValueError, struct.error) as error:
            result["error"] = str(error)
    return result


def config_parts(source: str) -> dict:
    """Luau를 실행하지 않고 { Id, Size } 데이터 정의만 읽는다."""
    result = {}
    pattern = re.compile(
        r'^\s*(?P<key>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*\{\s*Id\s*=\s*"(?P<id>[^\"]*)"(?P<body>[^}]*?)\}',
        re.MULTILINE,
    )
    for match in pattern.finditer(source):
        body = match.group("body")
        size = re.search(r"Size\s*=\s*Vector2\.new\(\s*(\d+)\s*,\s*(\d+)\s*\)", body)
        result[match.group("key")] = {
            "asset_id": match.group("id"),
            "size": [int(size.group(1)), int(size.group(2))] if size else None,
            "line": source.count("\n", 0, match.start("key")) + 1,
        }
    return result


def config_info(key: str | None, parts: dict, old_ids: dict, file_key: str, uploaded_ids: set[str]) -> dict:
    definition = parts.get(key) if key else None
    registry_id = old_ids.get(file_key)
    old_id = registry_id if registry_id not in uploaded_ids else None
    return {
        "file": relative(CONFIG),
        "key": key,
        "present": definition is not None,
        "definition": definition,
        "registry_asset_id": registry_id,
        "recorded_upload_asset_id": registry_id if registry_id in uploaded_ids else None,
        "old_account_asset_id": old_id,
        "old_id_still_in_config": bool(old_id and definition and definition["asset_id"] == old_id),
    }


def png_entry(name: str, category: str, key: str | None, *, parts: dict, old_ids: dict, meta: dict, uploaded_ids: set[str]) -> dict:
    source = file_info(ROOT / "art" / "out" / f"{name}.png")
    prepared = file_info(ROOT / "art" / "ui" / f"{name}.png")
    metadata = meta.get(name)
    dimensions = [prepared.get("width"), prepared.get("height")]
    definition = parts.get(key) if key else None
    config_size = definition["size"] if definition else None
    return {
        "name": name,
        "category": category,
        "source": source,
        "prepared": prepared,
        "upload_candidate": prepared["path"] if prepared["exists"] else None,
        "image_review": "업로드 전 직접 검토·사용자 표시 여부는 이 점검 목록에서 기록하지 않는다",
        "metadata": {
            "key": name,
            "present": metadata is not None,
            "definition": metadata,
            "matches_prepared_size": (
                [metadata.get("w"), metadata.get("h")] == dimensions
                if isinstance(metadata, dict) and prepared["exists"] and "error" not in prepared else None
            ),
        },
        "config": config_info(key, parts, old_ids, name, uploaded_ids),
        "config_size_matches_prepared": (
            config_size == dimensions if config_size and prepared["exists"] and "error" not in prepared else None
        ),
        "resize_needed": max(source.get("width", 0), source.get("height", 0)) > 1024,
    }


def build_report() -> dict:
    old_ids = read_json(ROOT / "art" / "ui" / "asset_ids.json")
    meta = read_json(ROOT / "art" / "ui" / "ui_meta.json")
    labels = read_json(ROOT / "art" / "ui" / "text_labels.json")
    source = CONFIG.read_text(encoding="utf-8")
    parts = config_parts(source)
    records = read_json(ROOT / "build" / "ui_upload_ledger.json").get("records", {})
    uploaded_ids = {
        record["id"] for record in records.values()
        if isinstance(record, dict) and isinstance(record.get("id"), str)
    }
    shared = {"parts": parts, "old_ids": old_ids, "meta": meta, "uploaded_ids": uploaded_ids}
    entries = []

    for name in (*UI_BASE, *CHARACTERS, *FX_EMO):
        category = "fx_emo" if name in FX_EMO else "ui"
        entries.append(png_entry(f"UIP_{name}", category, name, **shared))
    for key in TEXT_KEYS:
        entry = png_entry(f"TXT_{key}", "text", f"TXT_{key}", **shared)
        entry["text"] = labels.get(key)
        entries.append(entry)
    for class_id in CLASSES:
        for tier in (*[f"T{i}" for i in range(1, 7)], *[f"T7_{f}" for f in FACTIONS]):
            name = f"Weapon_{class_id}_{tier}"
            entry = png_entry(name, "weapon", name, **shared)
            entry.update(class_id=class_id, tier=tier)
            entries.append(entry)
    for name in TEXTURES:
        entry = png_entry(f"Tex_{name}", "texture", None, **shared)
        entry["target"] = "MaterialService.GE_Grass.ColorMap" if name == "Grass" else None
        entry["target_kind"] = "MaterialVariant"
        entries.append(entry)
    map_entry = png_entry("UI_MapParchment", "map", "MapParchment", **shared)
    map_entry["target"] = "WorldMap background"
    entries.append(map_entry)

    for name in MONSTERS:
        entries.append({
            "name": name,
            "category": "monster",
            "source": file_info(ROOT / "art" / "models" / f"{name}.glb"),
            "reference": file_info(ROOT / "art" / "out" / f"{name}.png"),
            "target": f"ServerStorage.CustomModels.{name}",
            "config": {
                "file": relative(CONFIG),
                "custom_models_folder": "CustomModels",
                "registered_monster_or_goose": (
                    bool(re.search(r"^\s*" + re.escape(name) + r"\s*=\s*\{\s*Name\s*=", source, re.MULTILINE))
                    or bool(re.search(r'GooseId\s*=\s*"' + re.escape(name) + '"', source))
                ),
            },
        })
    # 코스튬 18종 점검은 2026-10-06에 뺐다(A23-5: 코스튬 제거, CostumeService 삭제).

    excluded = [
        {"path": "art/out/v1/", "reason": "폐기/거절/노출 이미지 폴더 전체를 제외한다", "recursive": True},
    ]
    for faction in FACTIONS:
        for class_id in CLASSES:
            name = f"UIP_Char{faction}{class_id}.png"
            excluded.append({
                "paths": [f"art/out/{name}", f"art/ui/{name}"],
                "reason": "성별 없는 잔여 캐릭터: 현재 승인/Config 대상이 아니다",
            })

    counts = {category: sum(e["category"] == category for e in entries) for category in (
        "ui", "fx_emo", "text", "weapon", "texture", "map", "monster",
    )}
    expected = {"ui": 68, "fx_emo": 10, "text": 42, "weapon": 27, "texture": 15, "map": 1, "monster": 7}
    if counts != expected:
        raise ValueError(f"고정 대상 개수가 예상과 다릅니다: {counts}")
    image_entries = [e for e in entries if "prepared" in e]
    return {
        "schema_version": 1,
        "generated_at_kst": datetime.now(KST).isoformat(timespec="seconds"),
        "policy": {
            "mode": "read-only inspection; generated report only",
            "earliest_roblox_upload_date": "2026-10-03",
            "upload_function_present": False,
            "network_api_used": False,
            "max_upload_batch": 10,
            "required_before_upload": ["각 이미지를 직접 확인", "사용자에게 이미지 표시", "새 계정 확인", "배치 사이 간격 두기"],
            "selection_method": "고정 파일 목록만 사용; art/ui/*.png 전체 업로드 금지",
        },
        "summary": {
            "counts": counts,
            "total": len(entries),
            "missing_source": [e["source"]["path"] for e in entries if not e["source"]["exists"]],
            "missing_prepared": [e["prepared"]["path"] for e in image_entries if not e["prepared"]["exists"]],
            "old_ids_still_in_config": [e["name"] for e in image_entries if e["config"]["old_id_still_in_config"]],
            "missing_metadata": [e["name"] for e in image_entries if not e["metadata"]["present"]],
            "metadata_size_mismatches": [e["name"] for e in image_entries if e["metadata"]["matches_prepared_size"] is False],
            "config_size_mismatches": [e["name"] for e in image_entries if e["config_size_matches_prepared"] is False],
            "unregistered_config_parts": [e["name"] for e in image_entries if e["config"]["key"] and not e["config"]["present"]],
            "file_read_errors": [e["source"]["path"] for e in entries if "error" in e["source"]],
        },
        "excluded": excluded,
        "deferred": {
            "BigSlime": {
                "source": file_info(ROOT / "art" / "models" / "BigSlime.glb"),
                "reference": file_info(ROOT / "art" / "out" / "BigSlime.png"),
                "note": "모델이 미생성이라 기존 몬스터 7개 목록에 포함하지 않는다",
            },
        },
        "entries": entries,
    }


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    report = build_report()
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    summary = report["summary"]
    counts = summary["counts"]
    print(f"목록 저장: {relative(REPORT)}")
    print(f"대상 {summary['total']}개: UI {counts['ui'] + counts['fx_emo']}, 그림 글자 {counts['text']}, "
          f"무기 {counts['weapon']}, 텍스처/지도 {counts['texture'] + counts['map']}, "
          f"몬스터 {counts['monster']} (코스튬 점검은 A23-5로 제외)")
    print(f"원본 누락 {len(summary['missing_source'])}개, 준비 파일 누락 {len(summary['missing_prepared'])}개, "
          f"Config의 옛 ID {len(summary['old_ids_still_in_config'])}개")
    print(f"메타 크기 불일치 {len(summary['metadata_size_mismatches'])}개, "
          f"Config 크기 불일치 {len(summary['config_size_mismatches'])}개")
    print("업로드/API 호출 없음. v1/ 전체와 성별 없는 잔여 캐릭터 9개 제외.")


if __name__ == "__main__":
    main()
