"""Find explicit known texture IDs in local content caches, without credentials.

No log/cookie/settings files are opened. Only known content-cache folders and
read-only storage DB records are scanned. Payloads/URLs are never printed.
"""
from pathlib import Path
import hashlib
import io
import json
import os
import sqlite3

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/art/verification_2026-10-04/face_sharpness_audit"
IDS = ["114282379234661", "84211055370691", "106725946673245"]


def matches(data):
    return [i for i in IDS if i.encode() in data or i.encode("utf-16le") in data]


def inspect_match(data):
    result = {"sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data),
              "explicit_asset_ids": matches(data), "direct_image": None}
    try:
        image = Image.open(io.BytesIO(data))
        result["direct_image"] = {"format": image.format, "size": list(image.size)}
    except Exception:
        pass
    return result


def main():
    local = Path(os.environ["LOCALAPPDATA"])
    temp = local / "Temp/Roblox"
    roots = [local / "Roblox/rbx-storage", local / "Roblox/rbx-storage-sc", temp / "http", temp / "http-wob"]
    roots.extend(sorted(p for p in temp.glob("ContentProvider_*") if p.is_dir()))
    scanned = []
    findings = []
    for directory in roots:
        count = byte_count = failures = 0
        for path in directory.rglob("*"):
            if not path.is_file():
                continue
            try:
                data = path.read_bytes()
            except OSError:
                failures += 1
                continue
            count += 1
            byte_count += len(data)
            if matches(data) or matches(path.name.encode()):
                findings.append({"cache_relative_path": str(path.relative_to(local)), **inspect_match(data)})
        scanned.append({"cache_relative_path":str(directory.relative_to(local)),
                        "files":count,"bytes":byte_count,"read_failures":failures})
    db_path = local / "Roblox/rbx-storage.db"
    database = {"opened_read_only":False,"rows_scanned":0,"explicit_id_matches":0}
    if db_path.exists():
        conn = sqlite3.connect(db_path.as_uri()+"?mode=ro", uri=True)
        database["opened_read_only"] = True
        database["tables"] = [r[0] for r in conn.execute("select name from sqlite_master where type='table'")]
        for key, content in conn.execute("select id,content from files"):
            database["rows_scanned"] += 1
            parts = [v.encode() if isinstance(v,str) else bytes(v or b"") for v in (key,content)]
            found = sorted(set(matches(parts[0])+matches(parts[1])))
            if found:
                database["explicit_id_matches"] += 1
                findings.append({"database":"Roblox/rbx-storage.db","key_sha256":hashlib.sha256(parts[0]).hexdigest(),
                                 **inspect_match(parts[1]),"explicit_asset_ids":found})
        conn.close()
    report = {"schema":1,"known_production_texture_ids":IDS,"cache_scan":scanned,"database":database,
        "findings":findings,"explicit_asset_id_to_response_mapping_found":bool(findings),
        "remote_original_dimensions_confirmed":False,"downloaded_texture_dimensions_confirmed":False,
        "scope_ko":"알려진 캐시 파일과 읽기 전용 storage DB에서 세 에셋 ID의 ASCII/UTF16 문자열만 확인했다. 로그·인증 저장소·쿠키·설정 파일은 읽지 않았다.",
        "limitation_ko":"명시 ID→응답 매핑이 없으면 이미지 파일 크기·갱신 시각·유사한 그림만으로 실제 다운로드 에셋 크기를 추정하지 않는다. 압축된 내부 매핑 또는 해시 키만 남은 항목은 이 문자 검색으로 판별할 수 없다.",
        "network_calls":0,"studio_calls":0,"credentials_read_or_output":False,"source_mutations":0}
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/"cache_explicit_id_audit.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"files":sum(r["files"] for r in scanned),"bytes":sum(r["bytes"] for r in scanned),
                      "database_rows":database["rows_scanned"],"matches":len(findings)},ensure_ascii=False))


if __name__ == "__main__":
    main()
