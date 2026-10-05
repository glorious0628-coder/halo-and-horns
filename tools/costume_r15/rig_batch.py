# RETIRED 2026-10-06: costumes removed, A23-5. Kept on disk only as history; it exits immediately if run.
"""Resume the specifically approved 17 costume rigs without resubmitting a paid job."""
raise SystemExit('RETIRED 2026-10-06: costumes removed (A23-5); this costume tool must not be run.')
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import sys
import threading

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import tripo_api as api

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

ROOT = Path(api.ROOT)
NAMES = tuple("Costume_" + faction + job + gender
              for faction in ("Halo", "Horns", "Neutral")
              for job in ("Warrior", "Mage", "Archer")
              for gender in ("M", "F")
              if (faction, job, gender) != ("Halo", "Warrior", "M"))
STATE = ROOT / "build/costume_r15/approved_17_rig_state.json"
LOCK = STATE.with_suffix(".lock")
mutex = threading.RLock()
state = {}


def save(name, status, **values):
    with mutex:
        state[name] = {**state.get(name, {}), "status": status, **values}
        STATE.parent.mkdir(parents=True, exist_ok=True)
        temp = STATE.with_suffix(".tmp")
        temp.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")
        os.replace(temp, STATE)


def history(name):
    with api._lock:
        return json.loads(Path(api.RECORDS).read_text(encoding="utf-8")).get(name, [])


def resume_rig(name, entry):
    task_id = api.rig_task_id(entry["rig_task_id"])
    result = api.wait(task_id, label=name + " resume")
    credits = result.get("credits_consumed")
    if credits != api.RIG_COST:
        raise RuntimeError("Unexpected rig billing")
    path = Path(api.OUT_DIR) / f"{name}_rig_{task_id}.glb"
    if not path.exists():
        api.download(result["output"]["model_url"], str(path))
    if path.read_bytes()[:4] != b"glTF":
        raise RuntimeError("Invalid GLB")
    finished = {**entry, "event": "rig_completed", "rig_file": str(path.relative_to(ROOT)),
                "bytes": path.stat().st_size, "rig_credits": credits, "resumed": True}
    api.record(name, finished)
    return finished


def process(name):
    try:
        entries = history(name)
        done = next((v for v in reversed(entries) if v.get("event") == "rig_completed"), None)
        submitted = next((v for v in reversed(entries) if v.get("event") == "rig_submitted"), None)
        previous = state.get(name, {}).get("status")
        if done:
            path = ROOT / done["rig_file"]
            if not path.is_file() or path.read_bytes()[:4] != b"glTF":
                raise RuntimeError("Recorded GLB missing or invalid")
        elif submitted:
            save(name, "ResumingKnownRig", rig_task_id=submitted["rig_task_id"])
            done = resume_rig(name, submitted)
        elif previous in ("BeforeRig", "NeedsReview", "ResumingKnownRig"):
            raise RuntimeError("Unknown previous paid submission; manual audit required")
        else:
            imported = next((v for v in reversed(entries) if v.get("event") == "import_completed"), None)
            import_pending = next((v for v in reversed(entries) if v.get("event") == "import_submitted"), None)
            if imported:
                input_id = imported["task_id"]
            elif import_pending:
                result = api.wait(import_pending["task_id"], label=name + " import resume")
                if result.get("credits_consumed") != 0:
                    raise RuntimeError("Unexpected import billing")
                input_id = import_pending["task_id"]
                api.record(name, {**import_pending, "event": "import_completed", "credits": 0, "resumed": True})
            else:
                save(name, "Importing")
                input_id = api.run_import(str(ROOT / f"art/models/costume/fixed/{name}.glb"), name)
            save(name, "BeforeRig", input_id=input_id)
            done = api.run_rig(input_id, name)
            if not done or "rig_file" not in done:
                raise RuntimeError("Rig failed or not biped; no automatic retry")
        if done.get("rig_credits") != api.RIG_COST or done.get("rig_check_credits") != 0:
            raise RuntimeError("Unexpected billing")
        save(name, "Complete", rig_file=done["rig_file"], rig_task_id=done["rig_task_id"], credits=done["rig_credits"])
        print(name + ": 완료", flush=True)
        return True
    except Exception as error:
        save(name, "NeedsReview", error_type=type(error).__name__)
        print(name + ": 확인 필요 (유료 재요청 없음)", flush=True)
        return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--execute-approved-17", action="store_true")
    args = parser.parse_args()
    manifest = []
    for name in NAMES:
        path = ROOT / f"art/models/costume/fixed/{name}.glb"
        data = path.read_bytes()
        if data[:4] != b"glTF":
            raise RuntimeError("Invalid input GLB")
        manifest.append({"name": name, "input": str(path.relative_to(ROOT)),
                         "sha256": hashlib.sha256(data).hexdigest(), "credits_max": 25})
    assert len(manifest) == 17 and sum(v["credits_max"] for v in manifest) == 425
    STATE.parent.mkdir(parents=True, exist_ok=True)
    (STATE.parent / "approved_17_rig_manifest.json").write_text(
        json.dumps({"user_approved": "17종 모두 진행", "credits_max": 425,
                    "rig_parameters": api.HUMANOID_RIG, "models": manifest}, ensure_ascii=False, indent=2), encoding="utf-8")
    print("17종 · 무료 import/검사 · 리깅 최대425크레딧", flush=True)
    if not args.execute_approved_17:
        return
    global state
    state = json.loads(STATE.read_text(encoding="utf-8")) if STATE.exists() else {}
    with LOCK.open("x", encoding="utf-8") as stream:
        stream.write(str(os.getpid()))
    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
            results = list(pool.map(process, NAMES))
        print(f"완료 {sum(results)}/17", flush=True)
    finally:
        LOCK.unlink()


if __name__ == "__main__":
    main()
