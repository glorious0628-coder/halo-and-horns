"""미리 확인한 art/ui PNG 배치 업로드. --dry는 검증만 하고 아무 파일도 바꾸지 않는다.

py tools/upload_ui_assets.py --batch build/reviewed_batch.json [--dry]
py tools/upload_ui_assets.py --batch build/reviewed_batch.json --studio UiSandbox   (연습 Studio로 올리기; 이미지 개발)
py tools/upload_ui_assets.py --batch build/reviewed_batch.json --record-result build/upload_result.json [--dry]
py tools/upload_ui_assets.py --batch build/reviewed_batch.json --retry-disconnected-unknown --reason "이전 Studio 종료; 원본 매칭 불가"
Batch: [{"key": "PanelParchment", "file": "art/ui/UIP_PanelParchment.png", "sha256": "..."}]
HTTP 서버는 별도로 art/ui를 127.0.0.1:8765에서 제공해야 한다.
"""

import argparse
import hashlib
import json
import os
import re
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote, unquote, urlparse
from urllib.request import HTTPRedirectHandler, build_opener

ROOT = Path(__file__).resolve().parents[1]
UI = (ROOT / "art/ui").resolve()
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
ASSETS = UI / "asset_ids.json"
BUILD = ROOT / "build"
LEDGER = BUILD / "ui_upload_ledger.json"
BASE_URL = "http://127.0.0.1:8765/"


def read_json(path, default=None):
    if not path.exists() and default is not None:
        return default
    return json.loads(path.read_text(encoding="utf-8-sig"))


def atomic_bytes(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp." + uuid.uuid4().hex)
    try:
        with tmp.open("xb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(tmp, path)
    finally:
        if tmp.exists():
            tmp.unlink()


def atomic_json(path, data):
    atomic_bytes(path, (json.dumps(data, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))


def parts_span(text):
    """UIArt.Parts의 중괄호 범위. 문자열/주석 안의 중괄호는 무시한다."""
    start = re.search(r"Config\.UIArt\s*=\s*\{", text)
    if not start:
        raise ValueError("Config.UIArt를 찾지 못했습니다.")
    part = re.search(r"\bParts\s*=\s*\{", text[start.end():])
    if not part:
        raise ValueError("Config.UIArt.Parts를 찾지 못했습니다.")
    begin = start.end() + part.end() - 1
    depth, i = 1, begin + 1
    while i < len(text):
        if text.startswith("--", i):
            long = re.match(r"--\[(=*)\[", text[i:])
            if long:
                end = text.find("]" + long.group(1) + "]", i + long.end())
                if end < 0:
                    break
                i = end + len(long.group(1)) + 2
            else:
                end = text.find("\n", i)
                i = len(text) if end < 0 else end + 1
            continue
        if text[i] in "\"'":
            marker = text[i]
            i += 1
            while i < len(text):
                if text[i] == "\\":
                    i += 2
                elif text[i] == marker:
                    i += 1
                    break
                else:
                    i += 1
            continue
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return begin + 1, i
        i += 1
    raise ValueError("Config.UIArt.Parts의 닫는 중괄호를 찾지 못했습니다.")


def id_match(text, key):
    begin, end = parts_span(text)
    pattern = re.compile(r"(?m)^[ \t]*" + re.escape(key)
                         + r'\s*=\s*\{\s*Id\s*=\s*"([^"\r\n]*)"')
    matches = list(pattern.finditer(text, begin, end))
    if len(matches) != 1:
        raise ValueError(f"UIArt.Parts 기존 키/Id가 유일하지 않습니다: {key}")
    return matches[0]


def validate_batch(path):
    batch = read_json(path)
    if not isinstance(batch, list) or not 1 <= len(batch) <= 10:
        raise ValueError("배치는 1~10개만 허용합니다.")
    text = CONFIG.read_text(encoding="utf-8")
    items, keys, files = [], set(), set()
    for row in batch:
        if not isinstance(row, dict):
            raise ValueError("배치 항목은 JSON 객체여야 합니다.")
        key, file, digest = row.get("key"), row.get("file"), row.get("sha256")
        if not isinstance(key, str) or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            raise ValueError("올바른 Config 키가 필요합니다.")
        if not isinstance(file, str) or ".." in Path(file).parts:
            raise ValueError(f"상위 경로는 금지합니다: {key}")
        normalized = file.replace("\\", "/")
        if not re.fullmatch(r"art/ui/[^/]+\.png", normalized, flags=re.IGNORECASE):
            raise ValueError(f"art/ui 바로 아래 PNG만 허용합니다: {key}")
        source = (ROOT / file).resolve(strict=True)
        if source.parent != UI or source.suffix.lower() != ".png" or not source.is_file():
            raise ValueError(f"허용 폴더 밖 파일입니다: {key}")
        if key in keys or source.name.casefold() in files:
            raise ValueError(f"배치에 중복 키/파일이 있습니다: {key}")
        if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-fA-F]{64}", digest):
            raise ValueError(f"명시적인 SHA256이 필요합니다: {key}")
        data = source.read_bytes()
        if not data.startswith(b"\x89PNG\r\n\x1a\n"):
            raise ValueError(f"실제 PNG 파일이 아닙니다: {key}")
        if hashlib.sha256(data).hexdigest() != digest.lower():
            raise ValueError(f"검토 후 이미지가 변경됐습니다(SHA256 불일치): {key}")
        id_match(text, key)
        keys.add(key)
        files.add(source.name.casefold())
        item = {"key": key, "file": "art/ui/" + source.name, "sha256": digest.lower(),
                "url": BASE_URL + quote(source.name), "bytes": len(data)}
        item["token"] = hashlib.sha256((key + "\n" + item["file"] + "\n" + digest.lower()).encode()).hexdigest()
        items.append(item)
    return items


def asset_id(value):
    if isinstance(value, bool):
        return None
    if isinstance(value, int) and value > 0:
        return "rbxassetid://" + str(value)
    if isinstance(value, str):
        found = re.fullmatch(r"(?:rbxassetid://)?([1-9][0-9]*)", value.strip())
        if found:
            return "rbxassetid://" + found.group(1)
    return None


def verify_served_images(items):
    # Check the reviewed bytes on the fixed local HTTP origin before contacting Studio.
    class NoRedirect(HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            return None
    opener = build_opener(NoRedirect())
    for item in items:
        with opener.open(item["url"], timeout=15) as response:
            if response.geturl() != item["url"]:
                raise ValueError(f"이미지 HTTP 리디렉션은 금지합니다: {item['key']}")
            data = response.read(item["bytes"] + 1)
        if len(data) != item["bytes"] or hashlib.sha256(data).hexdigest() != item["sha256"]:
            raise ValueError(f"HTTP 이미지가 검토한 파일과 다릅니다: {item['key']}")


def parse_response(response, pending):
    """확실한 경로+ID만 사용한다. 배열 순서로 추측하지 않는다."""
    result, failed = {}, set()
    def token_for(value):
        if not isinstance(value, str):
            return None
        name = unquote(urlparse(value.replace("\\", "/")).path).rsplit("/", 1)[-1]
        matches = [item for item in pending if value == item["url"] or name == Path(item["file"]).name]
        return matches[0]["token"] if len(matches) == 1 else None
    def walk(value):
        if isinstance(value, list):
            for child in value:
                walk(child)
        elif isinstance(value, dict):
            path = next((value[k] for k in ("imagePath", "image_path", "path", "file", "url", "imageUrl", "image_url") if k in value), None)
            token = token_for(path)
            bad = value.get("success") is False or value.get("isError") is True or bool(value.get("error")) or value.get("status") in ("error", "failed", "failure")
            aid = next((asset_id(value[k]) for k in ("assetId", "asset_id", "assetID", "id", "assetUri", "assetUrl") if k in value and asset_id(value[k])), None)
            if token and bad:
                failed.add(token)
            elif token and aid:
                if token in result and result[token] != aid:
                    raise ValueError("응답에 같은 이미지의 서로 다른 ID가 있습니다.")
                result[token] = aid
            for key, child in value.items():
                token = token_for(key)
                aid = asset_id(child)
                if token and aid:
                    if token in result and result[token] != aid:
                        raise ValueError("응답 ID가 서로 충돌합니다.")
                    result[token] = aid
                if key == "text" and isinstance(child, str):
                    try:
                        walk(json.loads(child))
                    except json.JSONDecodeError:
                        pass
                elif isinstance(child, (dict, list)):
                    walk(child)
    walk(response)
    return result, failed - result.keys()


def apply_ids(items, records, label):
    known = [item for item in items if item["token"] in records]
    if not known:
        return None
    # Upload may take minutes: read the latest Config here to keep other edits.
    original = CONFIG.read_bytes()
    text = original.decode("utf-8")
    assets = read_json(ASSETS, {})
    if not isinstance(assets, dict):
        raise ValueError("asset_ids.json은 객체여야 합니다.")
    replacements = []
    for item in known:
        aid = asset_id(records[item["token"]]["id"])
        if not aid:
            raise ValueError("기록의 새 에셋 ID가 올바르지 않습니다.")
        match = id_match(text, item["key"])
        replacements.append((match.start(1), match.end(1), aid))
        assets[Path(item["file"]).stem] = aid
    for begin, end, value in sorted(replacements, reverse=True):
        text = text[:begin] + value + text[end:]
    updated = text.encode("utf-8")
    backup = BUILD / ("ui_config_" + label + "_" + uuid.uuid4().hex[:8] + ".bak")
    if updated != original:
        atomic_bytes(backup, original)
        if CONFIG.read_bytes() != original:
            raise RuntimeError("Config가 동시에 변경됐습니다. 기록된 ID로 재시도하세요.")
        atomic_bytes(CONFIG, updated)
    atomic_json(ASSETS, assets)
    return str(backup.relative_to(ROOT)) if updated != original else None


def record_result(batch_path, result_path, dry):
    """이미 성공한 upload_image 결과를 복구한다. Studio/HTTP 호출은 절대 하지 않는다."""
    items = validate_batch(batch_path)
    response = read_json(result_path)
    uploaded, failed = parse_response(response, items)
    tool_error = isinstance(response, dict) and response.get("isError") is True
    if not uploaded:
        raise ValueError("결과에서 배치 이미지에 대응하는 새 ID를 찾지 못했습니다.")
    signature = hashlib.sha256(json.dumps(items, sort_keys=True).encode()).hexdigest()[:20]
    report_path = BUILD / ("ui_upload_" + signature + ".json")
    summary = {"status": "dry-record" if dry else "recorded", "count": len(items),
               "recordedCount": len(uploaded), "networkCalls": 0,
               "report": str(report_path.relative_to(ROOT)),
               "results": [{"key": item["key"], "id": uploaded[item["token"]]}
                           for item in items if item["token"] in uploaded]}
    if dry:
        return summary, 0 if len(uploaded) == len(items) and not tool_error else 1
    # Root runs this serially with the uploader; read the ledger only at commit time.
    ledger = read_json(LEDGER, {"version": 1, "records": {}, "inflight": {}})
    records = ledger["records"]
    global_inflight = ledger.setdefault("inflight", {})
    report = {"version": 1, "batch": str(batch_path), "sourceResult": str(result_path),
              "items": items, "results": {}, "inflight": [], "unknown": [],
              "failed": sorted(failed), "status": "recorded"}
    now = datetime.now(timezone.utc).isoformat()
    for item in items:
        token = item["token"]
        if token in uploaded:
            existing = records.get(token)
            if existing and asset_id(existing.get("id")) != uploaded[token]:
                raise ValueError(f"이 이미지의 기존 업로드 기록과 ID가 다릅니다: {item['key']}")
            records[token] = {"key": item["key"], "file": item["file"], "sha256": item["sha256"],
                              "id": uploaded[token], "recordedAt": now, "sourceResult": str(result_path)}
            global_inflight.pop(token, None)
        elif token in failed:
            global_inflight.pop(token, None)
        elif token not in records:
            report["unknown"].append(token)
            global_inflight[token] = {"report": str(report_path.relative_to(ROOT))}
        if token in records:
            report["results"][token] = records[token]
    # Preserve IDs before changing either Config or asset_ids, allowing a safe repair retry.
    atomic_json(report_path, report)
    atomic_json(LEDGER, ledger)
    report["backup"] = apply_ids(items, records, signature)
    report["status"] = "complete" if len(report["results"]) == len(items) and not tool_error else "partial"
    atomic_json(report_path, report)
    summary.update(status=report["status"], backup=report["backup"])
    return summary, 0 if report["status"] == "complete" else 1


def studio_inventory(client):
    """조회 실패/빈 목록을 '이전 Studio 종료'로 오인하지 않는다."""
    response = client.call("list_roblox_studios", {})
    if response.get("isError"):
        raise RuntimeError("재시도 검증용 Studio 목록 조회에 실패했습니다.")
    payload = response.get("structuredContent")
    if not isinstance(payload, dict) or "studios" not in payload:
        for part in response.get("content", []):
            if part.get("type") == "text":
                try:
                    value = json.loads(part.get("text", ""))
                except json.JSONDecodeError:
                    continue
                if isinstance(value, dict) and "studios" in value:
                    payload = value
                    break
    studios = payload.get("studios") if isinstance(payload, dict) else None
    if not isinstance(studios, list) or not studios:
        raise RuntimeError("Studio 목록이 비어 있거나 불명확합니다. 재시도를 허용하지 않습니다.")
    if any(not isinstance(row, dict) or not isinstance(row.get("id"), str) or not row["id"] for row in studios):
        raise RuntimeError("Studio 목록에 올바른 ID가 없습니다.")
    return studios


def retry_evidence(batch_path):
    """같은 배치 분류의 로컬 복구 JSON을 보존한다. 후보 ID를 업로드 성공 ID로 사용하지 않는다."""
    match = re.fullmatch(r"([A-Za-z_]+)_[0-9]+", batch_path.stem)
    if not match:
        return []
    folder = BUILD / (match.group(1) + "_recovery")
    if not folder.is_dir():
        return []
    if folder.resolve().parent != BUILD.resolve():
        raise ValueError("복구 근거 폴더는 build 바로 아래 실제 폴더여야 합니다.")
    evidence = []
    for path in sorted(folder.glob("*.json")):
        if path.resolve().parent != folder.resolve() or path.stat().st_size > 1_000_000:
            raise ValueError("재시도 근거 JSON은 복구 폴더 바로 아래 1 MB 이하 파일만 허용합니다.")
        data = path.read_bytes()
        evidence.append({"file": str(path.relative_to(ROOT)), "sha256": hashlib.sha256(data).hexdigest(),
                         "record": json.loads(data.decode("utf-8-sig"))})
    return evidence


def disconnected_retry(items, pending, previous, global_inflight, report_path, studios, studio_id, reason, evidence):
    """재시도 조건/기록만 만든다. 파일, ID, 업로드 상태는 이 함수에서 변경하지 않는다."""
    if not isinstance(reason, str) or not reason.strip():
        raise ValueError("--retry-disconnected-unknown에는 명시적인 --reason이 필요합니다.")
    old_studio = previous.get("studio_id")
    if not isinstance(old_studio, str) or not old_studio:
        raise RuntimeError("이전 보고서에 Studio ID가 없어 종료 여부를 확인할 수 없습니다.")
    ids = {row["id"] for row in studios}
    if old_studio in ids:
        raise RuntimeError("이전 업로드 Studio가 아직 연결되어 있습니다. 불명확한 업로드 재시도를 막았습니다.")
    selected = next((row for row in studios if row["id"] == studio_id), None)
    if not selected or "goodevil" not in str(selected.get("name", "")).lower():
        raise RuntimeError("현재 GoodEvil Studio 연결을 확인하지 못했습니다.")
    old_items = {row.get("token"): row for row in previous.get("items", []) if isinstance(row, dict)}
    old_uncertain = set(previous.get("unknown", [])) | set(previous.get("inflight", []))
    report_name = str(report_path.relative_to(ROOT))
    released = []
    for item in items:
        old_item = old_items.get(item["token"])
        if not old_item or any(old_item.get(key) != item[key] for key in ("key", "file", "sha256")):
            raise ValueError("재시도 배치가 이전 검토 원본/SHA256과 다릅니다.")
    for item in pending:
        token = item["token"]
        global_row = global_inflight.get(token)
        if global_row and str(global_row.get("report", "")).replace("\\", "/") != report_name.replace("\\", "/"):
            raise RuntimeError("다른 배치의 불명확한 업로드는 해제할 수 없습니다.")
        if token in old_uncertain:
            released.append(token)
        elif global_row:
            raise RuntimeError("이전 보고서에 없는 전역 inflight 항목은 해제할 수 없습니다.")
    if not released:
        raise RuntimeError("이 배치에 종료된 Studio의 불명확한 업로드가 없습니다.")
    return {"retriedAt": datetime.now(timezone.utc).isoformat(), "reason": reason.strip(),
            "previousStudioId": old_studio, "currentStudioId": studio_id,
            "studioInventory": studios, "releasedTokens": released,
            "previousReport": {key: value for key, value in previous.items() if key != "retryHistory"},
            "candidateEvidence": evidence}


# the only Studio windows this tool may talk to (never the user's other place): the game, or the practice copy
STUDIOS = ("GoodEvil", "UiSandbox")


def run(batch_path, dry, retry_disconnected_unknown=False, reason=None, studio="GoodEvil"):
    if studio not in STUDIOS:
        raise ValueError(f"--studio는 {STUDIOS} 중 하나만: {studio}")
    if retry_disconnected_unknown and (not isinstance(reason, str) or not reason.strip()):
        raise ValueError("--retry-disconnected-unknown에는 명시적인 --reason이 필요합니다.")
    if reason is not None and not retry_disconnected_unknown:
        raise ValueError("--reason은 --retry-disconnected-unknown과 함께 사용하세요.")
    items = validate_batch(batch_path)
    signature = hashlib.sha256(json.dumps(items, sort_keys=True).encode()).hexdigest()[:20]
    report_path = BUILD / ("ui_upload_" + signature + ".json")
    ledger = read_json(LEDGER, {"version": 1, "records": {}, "inflight": {}})
    records = ledger["records"]
    global_inflight = ledger.setdefault("inflight", {})
    previous = read_json(report_path, {})
    ledger_before = LEDGER.read_bytes() if LEDGER.exists() else None
    report_before = report_path.read_bytes() if report_path.exists() else None
    for token, row in previous.get("results", {}).items():
        if asset_id(row.get("id")):
            records[token] = row
            global_inflight.pop(token, None)
    pending = [item for item in items if item["token"] not in records]
    uncertain = set(previous.get("unknown", [])) | set(previous.get("inflight", [])) | set(global_inflight)
    blocked = any(item["token"] in uncertain for item in pending)
    if dry:
        return {"status": "dry", "count": len(items), "uploadCount": len(pending), "reuseCount": len(items) - len(pending),
                "blockedCount": sum(item["token"] in uncertain for item in pending),
                "retryRequested": retry_disconnected_unknown, "studioCheck": "실제 실행 시 검증" if retry_disconnected_unknown else None,
                "report": str(report_path.relative_to(ROOT)), "items": items}, 0
    if blocked and not retry_disconnected_unknown:
        raise RuntimeError(f"이전 호출 결과가 불명확해 중복 업로드를 막았습니다. 확인할 기록: {report_path}")
    report = {"version": 1, "batch": str(batch_path), "items": items, "results": {item["token"]: records[item["token"]] for item in items if item["token"] in records},
              "status": "prepared", "inflight": [], "unknown": []}
    if previous.get("retryHistory"):
        report["retryHistory"] = list(previous["retryHistory"])
    report_written = False
    if not blocked:
        atomic_json(report_path, report)
        report_written = True
    tool_error = False
    if pending:
        verify_served_images(pending)
        from studio_mcp import Client
        # Ignore ambient STUDIO_NAME; never select the user's other place.
        os.environ["STUDIO_NAME"] = studio
        client = Client()
        try:
            client.start()
            studio_id = client.studio_id()
            if blocked:
                history = disconnected_retry(items, pending, previous, global_inflight, report_path,
                                             studio_inventory(client), studio_id, reason, retry_evidence(batch_path))
                if ((LEDGER.read_bytes() if LEDGER.exists() else None) != ledger_before
                        or (report_path.read_bytes() if report_path.exists() else None) != report_before):
                    raise RuntimeError("재시도 검증 중 업로드 기록이 변경됐습니다. 최신 기록으로 다시 실행하세요.")
                report.setdefault("retryHistory", []).append(history)
                for token in history["releasedTokens"]:
                    global_inflight.pop(token, None)
            report["studio_id"] = studio_id
            report["status"] = "inflight"
            report["inflight"] = [item["token"] for item in pending]
            atomic_json(report_path, report)  # Unknown interrupted uploads are never silently repeated.
            report_written = True
            for item in pending:
                global_inflight[item["token"]] = {"report": str(report_path.relative_to(ROOT))}
            atomic_json(LEDGER, ledger)  # Also blocks a retry using a reordered/subset batch file.
            response = client.call("upload_image", {"studio_id": studio_id, "imagePaths": [item["url"] for item in pending]})
            # Save text/structured metadata immediately; never store image base64.
            report["response"] = {"isError": response.get("isError", False), "structuredContent": response.get("structuredContent"),
                                  "content": [part for part in response.get("content", []) if part.get("type") == "text"]}
            atomic_json(report_path, report)
            uploaded, failed = parse_response(response, pending)
            tool_error = response.get("isError") is True
            now = datetime.now(timezone.utc).isoformat()
            for item in pending:
                token = item["token"]
                if token in uploaded:
                    row = {"key": item["key"], "file": item["file"], "sha256": item["sha256"], "id": uploaded[token], "uploadedAt": now}
                    records[token] = row
                    report["results"][token] = row
                    global_inflight.pop(token, None)
                elif token in failed:
                    global_inflight.pop(token, None)
            report["inflight"] = []
            report["unknown"] = [item["token"] for item in pending if item["token"] not in uploaded and item["token"] not in failed]
            report["failed"] = sorted(failed)
            report["status"] = "complete" if len(report["results"]) == len(items) and not tool_error else "partial"
            atomic_json(report_path, report)
        except Exception as exc:
            if report_written:
                report["status"] = "error"
                report["error"] = str(exc)
                atomic_json(report_path, report)
            raise
        finally:
            client.close()
    atomic_json(LEDGER, ledger)  # Record fresh IDs before modifying Config, so a retry reuses them.
    report["backup"] = apply_ids(items, records, signature)
    report["status"] = "complete" if len(report["results"]) == len(items) and not tool_error else "partial"
    atomic_json(report_path, report)
    return {"status": report["status"], "count": len(items), "recordedCount": len(report["results"]),
            "report": str(report_path.relative_to(ROOT)), "backup": report["backup"],
            "results": [{"key": row["key"], "id": row["id"]} for row in report["results"].values()]}, 0 if report["status"] == "complete" else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--batch", type=Path, required=True)
    parser.add_argument("--dry", action="store_true")
    parser.add_argument("--record-result", type=Path,
                        help="이미 받은 upload_image JSON 결과만 반영(네트워크/업로드 없음)")
    parser.add_argument("--retry-disconnected-unknown", action="store_true",
                        help="이전 Studio가 종료된 배치만 근거 보존 후 불명확한 PNG 재업로드")
    parser.add_argument("--reason", help="종료된 Studio의 불명확한 업로드를 다시 시도하는 이유")
    parser.add_argument("--studio", choices=STUDIOS, default="GoodEvil",
                        help="올릴 Studio 창(GoodEvil = 게임, UiSandbox = 이미지 개발 연습 Studio)")
    args = parser.parse_args()
    try:
        if args.record_result:
            if args.retry_disconnected_unknown or args.reason is not None:
                raise ValueError("--record-result와 불명확한 업로드 재시도 옵션은 함께 사용할 수 없습니다.")
            result, code = record_result(args.batch.resolve(strict=True), args.record_result.resolve(strict=True), args.dry)
        else:
            result, code = run(args.batch.resolve(strict=True), args.dry, args.retry_disconnected_unknown, args.reason,
                               args.studio)
    except Exception as exc:
        result, code = {"status": "error", "error": str(exc)}, 1
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return code


if __name__ == "__main__":
    sys.exit(main())
