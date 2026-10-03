"""
Tripo 3D API(v3) 자동화 — 그림 → 3D(GLB) → (리깅) → 다운로드까지 한 번에.
자세한 문서 정리: docs/vendor/tripo_api/README_KO.md

  py tools/tripo_api.py balance                                   -> 남은 크레딧
  py tools/tripo_api.py gen <그림.png> <이름> [--recipe character|monster|boss] [--rig] [--seed N] [--dry]
  py tools/tripo_api.py batch <목록.json> [--dry]                 -> [{"image":..,"name":..,"recipe":..,"rig":true}, ...]
  py tools/tripo_api.py task <task_id> [<저장할 이름>]            -> 작업 조회(+성공이면 다시 다운로드)

- API 키는 프로젝트의 .env(TRIPO_API_KEY=...) 또는 환경변수에서만 읽는다. 화면에 찍지 않는다.
- 결과: art/models/tripo/<이름>_raw.glb (+ _rig.glb), 기록: art/models/tripo/records.json
- 같은 분류는 최대 3개만 동시에 돌린다(문서끼리 3/5/10으로 달라서 안전한 쪽).
- --dry: 크레딧을 쓰지 않고 보낼 요청만 보여 준다.
"""

import concurrent.futures as cf
import json
import os
import sys
import threading
import time
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
    "monster": {"face_limit": 12000, "texture_quality": "standard"},
    # bosses from a single front image; use multiview by hand for best results (9.4)
    "boss": {"face_limit": 20000, "texture_quality": "detailed", "geometry_quality": "detailed", "texture_alignment": "original_image"},
}
COST = {"character": 40, "monster": 30, "boss": 60}
RIG_COST = 25

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
    mime = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg"}.get(ext)
    if not mime:
        raise TripoError(f"{rel}: PNG/JPEG만 올릴 수 있어요")
    with open(path, "rb") as f:
        data = f.read()
    if len(data) > 20 * 1024 * 1024:
        raise TripoError(f"{rel}: 20MB를 넘어요")
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


def run_one(image, name, recipe="character", rig=False, seed=None, dry=False):
    seed = seed if seed is not None else (zlib.crc32(name.encode()) % 90000) + 10000  # stable per name
    body = gen_body("<file_token>", recipe, seed)
    if dry:
        print(f"[dry] {name}: upload {image} -> POST /generation/image-to-model {json.dumps(body, ensure_ascii=False)}"
              + (f" -> rig-check -> rig(biped)" if rig else ""))
        return {"name": name, "credits_estimate": COST[recipe] + (RIG_COST if rig else 0)}
    print(f"[{name}] 업로드", flush=True)
    body["input"] = upload(image)
    tid = call("POST", "/generation/image-to-model", json_body=body)["task_id"]
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
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
