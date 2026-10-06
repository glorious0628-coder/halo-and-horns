"""
Tripo 3D API(v3) 자동화 — 그림 → 3D(GLB) → (리깅) → 다운로드까지 한 번에.
자세한 문서 정리: docs/vendor/tripo_api/README_KO.md

  py tools/tripo_api.py balance                                   -> 남은 크레딧
  py tools/tripo_api.py gen <그림.png> <이름> [--recipe character|monster|boss] [--rig] [--seed N] [--dry]
  py tools/tripo_api.py batch <목록.json> [--dry]                 -> [{"image":..,"name":..,"recipe":..,"rig":true}, ...]
  py tools/tripo_api.py task <task_id> [<저장할 이름>]            -> 작업 조회(+성공이면 다시 다운로드)
  py tools/tripo_api.py rig <task_id> <이름> [--dry]             -> 기존 모델 검사 → 사람형 Mixamo 리깅
  py tools/tripo_api.py anim <모델.glb> <이름> --cap N [--rig <리깅id>] [--clips Idle,Walk] [--dry]
                                                                  -> 가져오기(무료) → Tripo 뼈대 → 동작(제자리) 각각

- API 키는 프로젝트의 .env(TRIPO_API_KEY=...) 또는 환경변수에서만 읽는다. 화면에 찍지 않는다.
- 결과: art/models/tripo/<이름>_raw.glb (+ _rig.glb), 기록: art/models/tripo/records.json
- rig 명령은 원본을 보존하고 <이름>_rig_<rig_task_id>.glb와 단계별 기록만 저장한다.
- 같은 분류는 최대 3개만 동시에 돌린다(문서끼리 3/5/10으로 달라서 안전한 쪽).
- --dry: 크레딧을 쓰지 않고 보낼 요청만 보여 준다.
"""

import argparse
import concurrent.futures as cf
import json
import os
import re
import sys
import threading
import time
import uuid
import zlib

import requests

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = "https://openapi.tripo3d.ai/v3"
OUT_DIR = os.path.join(ROOT, "art", "models", "tripo")
RECORDS = os.path.join(OUT_DIR, "records.json")
BAD = {"failed", "banned", "expired", "cancelled"}
MAX_PARALLEL = 3
# never send images the account got moderated for (see memory: Roblox-safe art)
BLOCKED_DIRS = (os.path.join("art", "out", "v1"),)

GEO_MODEL = "v3.1-20260211"
TEX_MODEL = "v3.5-20260815"
RECIPES = {
    # chibi characters: face sharpness first (README_KO 9.2 C1)
    "character": {"face_limit": 18000, "texture_quality": "detailed", "texture_alignment": "original_image"},
    # regular monsters (9.3 M1)
    "monster": {"face_limit": 12000, "texture_quality": "standard", "texture_alignment": "original_image"},
    # bosses from a single front image; use multiview by hand for best results (9.4)
    "boss": {"face_limit": 20000, "texture_quality": "detailed", "geometry_quality": "detailed", "texture_alignment": "original_image"},
    # A23-47 world kit (same settings as batch 2, 2026-10-06): props <= 3k tris, buildings <= 10k, HD texture
    "prop": {"face_limit": 3000, "texture_quality": "detailed", "texture_alignment": "original_image"},
    "building": {"face_limit": 10000, "texture_quality": "detailed", "texture_alignment": "original_image"},
    # standard texture (30 credits) for small or simple pieces
    "prop_std": {"face_limit": 3000, "texture_quality": "standard", "texture_alignment": "original_image"},
    # head accessories (rank horns / halo, A23-54): small on screen, 2k tris
    "acc": {"face_limit": 2000, "texture_quality": "detailed", "texture_alignment": "original_image"},
}
COST = {"character": 40, "monster": 30, "boss": 60, "prop": 40, "building": 40, "prop_std": 30, "acc": 40}
RIG_COST = 25
HUMANOID_RIG = {"model": "v1.0-20240301", "rig_type": "biped", "spec": "mixamo", "out_format": "glb"}

_lock = threading.Lock()


class TripoError(Exception):
    pass


def api_key():
    key = os.environ.get("TRIPO_API_KEY", "").strip()
    env = os.path.join(ROOT, ".env")
    if not key and os.path.exists(env):
        for line in open(env, encoding="utf-8"):
            line = line.strip()
            if line.startswith("TRIPO_API_KEY="):
                key = line.split("=", 1)[1].strip().strip('"').strip("'")
    if not key:
        sys.exit("API 키가 없어요. 프로젝트 폴더의 .env 파일에 TRIPO_API_KEY=... 를 넣어 주세요.")
    return key


def call(method, path, *, json_body=None, files=None, retries=5):
    """returns data on code 0; waits and retries on 429 / 5xx; raises TripoError otherwise"""
    headers = {"Authorization": "Bearer " + api_key()}
    for attempt in range(retries + 1):
        r = requests.request(method, BASE + path, headers=headers, json=json_body, files=files, timeout=120)
        if r.status_code == 429 or r.status_code >= 500:
            if attempt == retries:
                break
            ra, reset = r.headers.get("Retry-After"), r.headers.get("X-RateLimit-Reset")
            if ra:
                wait = float(ra)
            elif reset:
                wait = max(int(reset) - time.time(), 1)
            else:
                wait = min(2 ** attempt, 32)
            time.sleep(wait)
            continue
        try:
            body = r.json()
        except ValueError:
            raise TripoError(f"HTTP {r.status_code}: {r.text[:200]}")
        if body.get("code") != 0:
            code = body.get("code")
            hint = {2010: "크레딧이 부족해요 (developers.tripo3d.ai/en/billing 에서 충전)",
                    2008: "콘텐츠 정책에 걸렸어요 — 그림을 고쳐야 해요 (같은 그림 재시도 금지)",
                    1000: "API 키가 틀렸거나 삭제됐어요", 1001: "API 키가 없어요"}.get(code, "")
            raise TripoError(f"[{code}] {body.get('message')} {hint}".strip())
        return body["data"]
    raise TripoError(f"{path}: 재시도를 다 썼어요")


def upload(path):
    rel = os.path.relpath(os.path.abspath(path), ROOT)
    if any(rel.startswith(d) for d in BLOCKED_DIRS):
        raise TripoError(f"{rel}: 예전(노출) 그림 폴더라 업로드하지 않아요")
    ext = os.path.splitext(path)[1].lower()
    mime = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
            ".glb": "model/gltf-binary"}.get(ext)
    if not mime:
        raise TripoError(f"{rel}: PNG/JPEG/GLB만 올릴 수 있어요")
    with open(path, "rb") as f:
        data = f.read()
    limit_mb = 150 if ext == ".glb" else 20
    if len(data) > limit_mb * 1024 * 1024:
        raise TripoError(f"{rel}: {limit_mb}MB를 넘어요")
    return call("POST", "/files", files={"file": (os.path.basename(path), data, mime)})["file_token"]


def wait(task_id, timeout=900, interval=3, label=""):
    t0 = time.time()
    last = -1
    while time.time() - t0 < timeout:
        d = call("GET", f"/tasks/{task_id}")
        st = d.get("status")
        if st == "success":
            return d
        if st in BAD:
            raise TripoError(f"{label} {task_id} {st} code={d.get('error_code')} {d.get('error_message') or ''}")
        p = d.get("progress", 0)
        if p != last and p % 25 == 0:
            print(f"  {label} {st} {p}%", flush=True)
            last = p
        time.sleep(interval)
    raise TimeoutError(f"{label} {task_id}: 시간 초과 — 나중에 `task {task_id}` 로 다시 조회하세요")


def download(url, out_path):
    r = requests.get(url, timeout=600)  # signed URL: no Authorization header
    r.raise_for_status()
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "wb") as f:
        f.write(r.content)
    return len(r.content)


def record(name, entry):
    with _lock:
        os.makedirs(OUT_DIR, exist_ok=True)
        data = json.load(open(RECORDS, encoding="utf-8")) if os.path.exists(RECORDS) else {}
        data.setdefault(name, []).append(entry)
        json.dump(data, open(RECORDS, "w", encoding="utf-8"), ensure_ascii=False, indent=1)


def gen_body(token, recipe, seed):
    body = {
        "input": token,
        "model": GEO_MODEL,
        "texture": True,
        "pbr": False,  # cartoon look needs only base colour; fix_face.py reads the first image node
        "texture_version": TEX_MODEL,
        "delight": False,
        "model_seed": seed,
        "texture_seed": seed + 1,
    }
    body.update(RECIPES[recipe])
    return body


def rig_task_id(value):
    """Accept existing UUIDs and the task_ identifiers documented by the API."""
    try:
        if str(uuid.UUID(value)) == value.lower():
            return value
    except (ValueError, AttributeError):
        pass
    if re.fullmatch(r"task_[A-Za-z0-9_-]{1,120}", value):
        return value
    raise argparse.ArgumentTypeError("작업 ID는 UUID 또는 task_ 형식이어야 해요.")


def rig_name(value):
    # A filename stem only: never accept directory separators, '..', drives or ADS.
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,79}", value):
        raise argparse.ArgumentTypeError("이름은 영문·숫자·밑줄·하이픈으로 1~80자만 써 주세요.")
    return value


def run_import(path, name, dry=False):
    """Free import of a reviewed local GLB when an old task belongs to another account."""
    name = rig_name(name)
    path = os.path.abspath(path)
    if os.path.splitext(path)[1].lower() != ".glb" or not os.path.isfile(path):
        raise TripoError("기존 GLB 파일이 필요해요.")
    if dry:
        print(json.dumps({"endpoint": "/models/import", "input": os.path.relpath(path, ROOT),
                          "payload": {"input": "<file_token>"}, "credits_estimate": 0}))
        return
    token = upload(path)
    tid = call("POST", "/models/import", json_body={"input": token}, retries=0)["task_id"]
    record(name, {"operation": "import", "event": "import_submitted", "task_id": tid,
                  "file": os.path.relpath(path, ROOT)})
    result = wait(tid, label=name + " import")
    billed = result.get("credits_consumed")
    record(name, {"operation": "import", "event": "import_completed", "task_id": tid,
                  "file": os.path.relpath(path, ROOT), "credits": billed})
    print(f"import {tid}: {billed}크레딧", flush=True)
    return tid


def run_rig(task_id, name, dry=False):
    """Continue an existing generation; no image upload or model generation."""
    task_id, name = rig_task_id(task_id), rig_name(name)
    check_body = {"input": task_id}
    rig_body = {"input": task_id, **HUMANOID_RIG}
    if dry:
        plan = {"dry_run": True, "name": name, "source_task_id": task_id,
                "steps": [
                    {"endpoint": "/animations/rig-check", "payload": check_body, "credits_estimate": 0},
                    {"endpoint": "/animations/rig", "payload": rig_body, "credits_estimate": RIG_COST,
                     "condition": "riggable=true and rig_type=biped"}],
                "credits_estimate": RIG_COST,
                "file": f"art/models/tripo/{name}_rig_<rig_task_id>.glb",
                "records": "art/models/tripo/records.json"}
        print(json.dumps(plan, ensure_ascii=False, indent=2))
        return plan

    stage, current_task = "rig-check", None
    entry = {"operation": "rig", "source_task_id": task_id, "rig_parameters": rig_body,
             "at": time.strftime("%Y-%m-%d %H:%M:%S")}
    try:
        current_task = call("POST", "/animations/rig-check", json_body=check_body)["task_id"]
        entry["rig_check_task_id"] = current_task
        record(name, {**entry, "event": "rig_check_submitted"})
        checked = wait(current_task, label=name + " rig-check")
        out = checked.get("output", {})
        entry["rig_check"] = {key: out.get(key) for key in ("riggable", "rig_type")}
        entry["rig_check_credits"] = checked.get("credits_consumed")
        if out.get("riggable") is not True or out.get("rig_type") != "biped":
            record(name, {**entry, "event": "rig_check_rejected"})
            print(f"[{name}] 사람형 리깅 검사 불통과 — 리깅 요청을 보내지 않았어요.", flush=True)
            return entry
        record(name, {**entry, "event": "rig_check_completed"})

        stage = "rig"
        current_task = call("POST", "/animations/rig", json_body=rig_body, retries=0)["task_id"]
        entry["rig_task_id"] = current_task
        record(name, {**entry, "event": "rig_submitted"})
        rigged = wait(current_task, label=name + " rig")
        # Validate the server's ID too; it becomes part of the output filename.
        output_id = rig_task_id(current_task)
        path = os.path.join(OUT_DIR, f"{name}_rig_{output_id}.glb")
        if os.path.exists(path):
            raise TripoError("리깅 결과 파일이 이미 있어요. 기존 파일을 보존했어요.")
        stage = "download"
        size = download(rigged["output"]["model_url"], path)
        entry.update({"rig_file": os.path.relpath(path, ROOT), "bytes": size,
                      "rig_credits": rigged.get("credits_consumed")})
        record(name, {**entry, "event": "rig_completed"})
        print(f"[{name}] 리깅 완료: {entry['rig_file']} ({size // 1024}KB)", flush=True)
        print(f"  rig-check {entry['rig_check_task_id']}: {entry['rig_check_credits']}크레딧", flush=True)
        print(f"  rig {entry['rig_task_id']}: {entry['rig_credits']}크레딧", flush=True)
        credits = [entry["rig_check_credits"], entry["rig_credits"]]
        total = sum(credits) if all(isinstance(value, (int, float)) for value in credits) else "확인 필요"
        print(f"  총 {total}크레딧", flush=True)
        return entry
    except Exception as error:
        # Do not persist signed URLs, HTTP response bodies or credentials in errors.
        record(name, {**entry, "event": "rig_failed", "stage": stage,
                      "resume_task_id": current_task, "error_type": type(error).__name__})
        print(f"[{name}] {stage} 실패 ({type(error).__name__}). 단계 기록을 확인해 주세요.", file=sys.stderr)
        return None


# 2026-10-06 monster motion: idle / walk / attack / hit / fall, one clip per call, played in place.
# Tripo presets only retarget onto a Tripo-spec rig (a Mixamo-spec rig returned 1004 for every preset).
MONSTER_ANIMS = {"Idle": "preset:idle", "Walk": "preset:walk", "Slash": "preset:slash", "Hurt": "preset:hurt",
                 "Fall": "preset:fall",
                 # 2026-10-06 motion survey (docs/design/monster_motion_survey_2026-10-06.md): chase + idle variety
                 "Run": "preset:run", "LookAround": "preset:biped:look_around"}
RETARGET_COST_EACH = 10
MONSTER_RIG = {"model": "v1.0-20240301", "rig_type": "biped", "spec": "tripo", "out_format": "glb"}


def run_anim(path, name, cap, dry=False, rig_id=None, clips=None):
    """Local GLB -> free import -> biped Tripo-spec rig -> one retarget per clip. Stops before going over `cap`."""
    name = rig_name(name)
    clips = clips or list(MONSTER_ANIMS)
    estimate = (0 if rig_id else 25) + RETARGET_COST_EACH * len(clips)
    if dry:
        print(json.dumps({"name": name, "rig": rig_id or "new", "clips": clips, "credits_estimate": estimate}))
        return {"estimate": estimate}
    if estimate > cap:
        raise TripoError(f"{name}: 예상 {estimate}크레딧이 남은 한도 {cap}를 넘어요 — 멈췄어요")
    spent = 0.0
    if not rig_id:
        src = run_import(path, name + "_src")
        rig_id = call("POST", "/animations/rig", json_body={"input": src, **MONSTER_RIG}, retries=0)["task_id"]
        record(name, {"operation": "rig", "event": "rig_submitted", "spec": "tripo", "rig_task_id": rig_id})
        done = wait(rig_id, label=name + " rig")
        spent += float(done.get("credits_consumed") or 0)
        record(name, {"operation": "rig", "event": "rig_completed", "spec": "tripo", "rig_task_id": rig_id,
                      "credits": done.get("credits_consumed")})
    files = {}
    for clip in clips:
        body = {"input": rig_id, "animation": MONSTER_ANIMS[clip], "out_format": "glb", "animate_in_place": True}
        tid = call("POST", "/animations/retarget", json_body=body, retries=0)["task_id"]
        done = wait(tid, label=f"{name} {clip}")
        out_path = os.path.join(OUT_DIR, f"{name}_{clip}.glb")
        size = download(done["output"]["model_url"], out_path)
        billed = float(done.get("credits_consumed") or 0)
        spent += billed
        record(name, {"operation": "retarget", "event": "retarget_completed", "task_id": tid, "clip": clip,
                      "credits": billed, "file": os.path.relpath(out_path, ROOT), "bytes": size})
        files[clip] = out_path
        print(f"[{name}] {clip} 완료 ({size // 1024}KB, {billed}크레딧)", flush=True)
    print(f"[{name}] 이번 합계 {spent}크레딧 · rig {rig_id}", flush=True)
    return {"files": files, "spent": spent, "rig": rig_id}


def run_one(image, name, recipe="character", rig=False, seed=None, dry=False):
    seed = seed if seed is not None else (zlib.crc32(name.encode()) % 90000) + 10000  # stable per name
    body = gen_body("<file_token>", recipe, seed)
    if dry:
        print(f"[dry] {name}: upload {image} -> POST /generation/image-to-model {json.dumps(body, ensure_ascii=False)}"
              + (f" -> rig-check -> rig(biped)" if rig else ""))
        return {"name": name, "credits_estimate": COST[recipe] + (RIG_COST if rig else 0)}
    print(f"[{name}] 업로드", flush=True)
    body["input"] = upload(image)
    tid = call("POST", "/generation/image-to-model", json_body=body, retries=0)["task_id"]
    record(name, {"event": "generation_submitted", "task_id": tid,
                  "image": os.path.relpath(image, ROOT), "recipe": recipe, "seed": seed})
    print(f"[{name}] 3D 생성 시작 {tid}", flush=True)
    d = wait(tid, label=name)
    raw = os.path.join(OUT_DIR, f"{name}_raw.glb")
    size = download(d["output"]["model_url"], raw)
    if d["output"].get("rendered_image_url"):
        try:
            download(d["output"]["rendered_image_url"], os.path.join(OUT_DIR, f"{name}_preview.png"))
        except Exception:
            pass
    entry = {"task_id": tid, "image": os.path.relpath(image, ROOT), "recipe": recipe, "seed": seed,
             "credits": d.get("credits_consumed"), "file": os.path.relpath(raw, ROOT), "bytes": size,
             "at": time.strftime("%Y-%m-%d %H:%M:%S")}
    print(f"[{name}] 완료 {size // 1024}KB, {d.get('credits_consumed')}크레딧", flush=True)
    if rig:
        chk = wait(call("POST", "/animations/rig-check", json_body={"input": tid})["task_id"], label=name + " rig-check")
        out = chk.get("output", {})
        entry["rig_check"] = out
        if out.get("riggable"):
            rt = out.get("rig_type") or "biped"
            ver = "v1.0-20240301" if rt == "biped" else "v2.5-20260210"
            rd = wait(call("POST", "/animations/rig", json_body={"input": tid, "model": ver, "rig_type": rt,
                                                                  "spec": "mixamo" if rt == "biped" else "tripo",
                                                                  "out_format": "glb"})["task_id"], label=name + " rig")
            rigged = os.path.join(OUT_DIR, f"{name}_rig.glb")
            download(rd["output"]["model_url"], rigged)
            entry["rig_task_id"] = rd.get("task_id")
            entry["rig_file"] = os.path.relpath(rigged, ROOT)
            print(f"[{name}] 리깅 완료 ({rt})", flush=True)
        else:
            print(f"[{name}] 리깅 불가 판정 — 정적 모델로 써요", flush=True)
    record(name, entry)
    return entry


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    a = sys.argv[1:]
    if not a:
        sys.exit(__doc__)
    cmd = a[0]
    flags = {x for x in a if x.startswith("--") and "=" not in x}
    dry = "--dry" in flags

    def opt(name, default=None):
        if name in a:
            i = a.index(name)
            return a[i + 1] if i + 1 < len(a) else default
        return default

    if cmd == "balance":
        d = call("GET", "/account/balance")
        print(f"남은 크레딧 {d.get('balance')} (작업 중 묶인 것 {d.get('frozen')})  = ${float(d.get('balance', 0)) / 100:.2f}")
    elif cmd == "import":
        run_import(a[1], a[2], dry)
    elif cmd == "gen":
        image, name = a[1], a[2]
        recipe = opt("--recipe", "character")
        seed = opt("--seed")
        run_one(image, name, recipe, "--rig" in flags, int(seed) if seed else None, dry)
    elif cmd == "batch":
        items = json.load(open(a[1], encoding="utf-8"))
        est = sum(COST[i.get("recipe", "character")] + (RIG_COST if i.get("rig") else 0) for i in items)
        print(f"{len(items)}개, 예상 {est}크레딧 (${est / 100:.2f})")
        if not dry:
            bal = float(call("GET", "/account/balance").get("balance", 0))
            if bal < est:
                sys.exit(f"크레딧이 부족해요: 남은 {bal}, 필요 {est}")
        with cf.ThreadPoolExecutor(MAX_PARALLEL) as ex:
            futs = {ex.submit(run_one, i["image"], i["name"], i.get("recipe", "character"), bool(i.get("rig")),
                              i.get("seed"), dry): i["name"] for i in items}
            for f in cf.as_completed(futs):
                try:
                    f.result()
                except Exception as e:
                    print(f"[{futs[f]}] 실패: {e}", flush=True)
    elif cmd == "task":
        d = call("GET", f"/tasks/{a[1]}")
        print(json.dumps({k: v for k, v in d.items() if k != "output"}, ensure_ascii=False))
        if d.get("status") == "success" and len(a) > 2:
            print("저장:", download(d["output"]["model_url"], os.path.join(OUT_DIR, f"{a[2]}_raw.glb")), "bytes")
    elif cmd == "anim":
        cap = float(opt("--cap", "0"))
        clips = opt("--clips")
        run_anim(a[1], a[2], cap, dry, rig_id=opt("--rig"), clips=clips.split(",") if clips else None)
    elif cmd == "rig":
        parser = argparse.ArgumentParser(prog="tripo_api.py rig", description="기존 모델을 사람형 Mixamo 뼈대로 리깅해요.")
        parser.add_argument("task_id", type=rig_task_id)
        parser.add_argument("name", type=rig_name)
        parser.add_argument("--dry", action="store_true", help="API 호출 없이 요청 계획만 출력해요.")
        args = parser.parse_args(a[1:])
        if run_rig(args.task_id, args.name, args.dry) is None:
            sys.exit(1)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
