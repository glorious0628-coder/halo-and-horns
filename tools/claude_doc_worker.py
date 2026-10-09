"""Independent, resumable Markdown fixer/reviewer. No project writes or Git pushes.

py tools/claude_doc_worker.py start|status|stop
Results: build/claude_doc_worker/candidate/, reports and changes.patch.
"""
import argparse
import ctypes
import difflib
import hashlib
import json
import os
import pathlib
import shutil
import subprocess
import sys
import time
import webbrowser

import claude_doc_api as api

ROOT = pathlib.Path(__file__).resolve().parents[1]
JOB = ROOT / "build/claude_doc_worker"
OLD = ROOT / "build/md_resume_2026-10-09"
NAMES = {"1":"기준 문서", "2":"게임 설계", "3":"그림·세계·소리", "4":"인계·운영", "5":"검증 기록", "6":"도구·참고 자료", "7":"영상·홈페이지"}


def load(p):
    return json.loads(p.read_text(encoding="utf-8"))


def save(p, data):
    tmp = p.with_name(p.name + f".{os.getpid()}.tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    os.replace(tmp, p)


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def alive(pid):
    if not pid:
        return False
    if os.name == "nt":
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.OpenProcess.restype = ctypes.c_void_p
        kernel.GetExitCodeProcess.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_ulong)]
        kernel.CloseHandle.argtypes = [ctypes.c_void_p]
        handle = kernel.OpenProcess(0x1000, False, pid)
        if not handle:
            return False
        code = ctypes.c_ulong()
        ok = kernel.GetExitCodeProcess(handle, ctypes.byref(code))
        kernel.CloseHandle(handle)
        return bool(ok and code.value == 259)
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def allowed_path(base, name, allowed):
    if name not in allowed or name == "AGENTS.md" or not name.endswith(".md"):
        raise ValueError("수정 허용 목록 밖의 파일: " + name)
    p = (base / name).resolve()
    if not p.is_relative_to(base.resolve()):
        raise ValueError("폴더 밖 경로 거절")
    return p


def add_notice(text, notice):
    if not notice.strip() or len(notice) > 2500:
        raise ValueError("기록 안내는 짧은 문장이어야 합니다")
    lines = text.splitlines(keepends=True)
    if lines and lines[0].startswith("# "):
        return lines[0].rstrip("\r\n") + "\n\n" + notice.strip() + "\n" + "".join(lines[1:])
    return notice.strip() + "\n\n" + text


def apply_candidate(report, allowed):
    """Validate the complete report before writing any staged files."""
    prepared = {}
    restores = set()
    counts = {}
    for p in report["patches"]:
        counts[p["file"]] = counts.get(p["file"], 0) + 1
    for patch in report["patches"]:
        name = patch["file"]
        p = allowed_path(JOB / "candidate", name, allowed)
        text = prepared.get(name, p.read_text(encoding="utf-8-sig"))
        op = patch["op"]
        if op == "replace":
            old = patch["old"]
            if not old or text.count(old) != 1:
                raise ValueError("교체할 문자열이 정확히 한 곳이 아님: " + name)
            text = text.replace(old, patch["new"], 1)
        elif op == "restore_history":
            if counts[name] != 1:
                raise ValueError("기록 복원과 다른 수정 혼합 거절: " + name)
            original = JOB / "original" / name
            if not original.is_file():
                raise ValueError("복원할 원문 없음: " + name)
            text = add_notice(original.read_text(encoding="utf-8-sig"), patch["new"])
            restores.add(name)
        elif op == "prepend":
            text = add_notice(text, patch["new"])
        else:
            raise ValueError("알 수 없는 수정 방식")
        prepared[name] = text
    for name, text in prepared.items():
        p = allowed_path(JOB / "candidate", name, allowed)
        p.write_text(text, encoding="utf-8")
    return len(prepared)


def export(state):
    patches = []
    changed = []
    for name in state["hashes"]:
        a = (JOB / "input" / name).read_text(encoding="utf-8-sig")
        b = (JOB / "candidate" / name).read_text(encoding="utf-8-sig")
        if a != b:
            changed.append(name)
            patches.extend(difflib.unified_diff(a.splitlines(True), b.splitlines(True), fromfile="a/"+name, tofile="b/"+name))
    (JOB / "changes.patch").write_text("".join(patches), encoding="utf-8")
    lines = ["# 클로드 문서 검사 진행", "", f"상태: {state['status']}", "", "원본 303개 + 새 인계 안내 1개를 검사합니다. 수정본은 candidate 폴더에만 저장합니다.", "", "| 묶음 | 상태 |", "|---|---|"]
    for g, label in NAMES.items():
        lines.append(f"| {g}. {label} | {state['groups'].get(g, {}).get('status', '대기')} |")
    lines += ["", f"검토용 수정 파일: {len(changed)}개", "", "- AGENTS.md는 수정하지 않습니다.", "- 원래 프로젝트 문서·코드·Studio는 이 프로그램이 변경하지 않습니다.", "- 수정본과 반박 결과는 각 묶음 JSON, 전체 차이는 changes.patch에 저장합니다.", "- unresolved가 남거나 반박 검사에 통과하지 못한 묶음은 완료로 표시하지 않습니다."]
    (JOB / "진행상황.md").write_text("\n".join(lines)+"\n", encoding="utf-8")
    state["changed_files"] = changed
    state["updated_at"] = time.strftime("%Y-%m-%d %H:%M:%S")
    save(JOB / "state.json", state)


def prepare():
    if (JOB / "state.json").exists():
        return load(JOB / "state.json")
    JOB.mkdir(parents=True, exist_ok=True)
    manifest = load(OLD / "inventory.json")
    names = sorted(set(p for group in manifest["groups"].values() for p in group) | {"docs/handoff/README.md"})
    state = {"status":"준비", "pid":None, "base":manifest["base"], "groups":{}, "hashes":{}}
    for name in names:
        if pathlib.PurePosixPath(name).is_absolute() or ".." in pathlib.PurePosixPath(name).parts or not name.endswith(".md"):
            raise ValueError("잘못된 문서 경로")
        src = ROOT / name
        state["hashes"][name] = sha(src)
        for folder in ["input", "candidate"]:
            out = JOB / folder / name
            out.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(src, out)
        r = subprocess.run(["git", "show", f"{manifest['base']}:{name}"], cwd=ROOT, capture_output=True)
        if r.returncode == 0:
            out = JOB / "original" / name
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_bytes(r.stdout)
    save(JOB / "inventory.json", manifest)
    # Reuse completed API work only when every source byte is still the same.
    for g in NAMES:
        report = OLD / f"fix_group{g}.json"
        snap = OLD / f"fix_group{g}_snapshot.json"
        if report.exists() and snap.exists():
            hashes = load(snap)
            if all(state["hashes"].get(p) == h for p,h in hashes.items()):
                shutil.copyfile(report, JOB / report.name)
                usage = OLD / f"fix_group{g}_usage.json"
                if usage.exists():
                    shutil.copyfile(usage, JOB / usage.name)
    export(state)
    return state


def configure():
    api.OUT = JOB
    api.WORKROOT = JOB / "candidate"
    api.MANIFEST = load(JOB / "inventory.json")
    api.BASE = api.MANIFEST["base"]


def run():
    state = prepare()
    lock = JOB / "worker.lock"
    try:
        fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError:
        prior = int(lock.read_text() or "0")
        if alive(prior):
            raise RuntimeError("이미 실행 중입니다")
        lock.unlink()
        fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    os.write(fd, str(os.getpid()).encode())
    os.close(fd)
    configure()
    state["pid"] = os.getpid()
    state["status"] = "실행 중"
    export(state)
    try:
        for g in NAMES:
            if (JOB / "STOP").exists():
                break
            gs = state["groups"].setdefault(g, {})
            if gs.get("status") in ["통과", "확인 필요", "오류"]:
                continue
            try:
                if not gs.get("fix_applied"):
                    gs["status"] = "수정 검사 중"
                    export(state)
                    result = api.run(g, "fix")
                    if isinstance(result, dict) and result.get("error"):
                        raise RuntimeError(result["error"])
                    report = load(JOB / f"fix_group{g}.json")
                    gs["changed"] = apply_candidate(report, api.group_files(g))
                    gs["fix_applied"] = True
                    export(state)
                # Separate stateless requests: the fixer cannot approve itself.
                for round_no in range(gs.get("review_round", 0), 2):
                    if (JOB / "STOP").exists():
                        break
                    suffix = "" if round_no == 0 else "2"
                    gs["status"] = f"반박 검사 {round_no+1}차"
                    export(state)
                    result = api.run(g, "review", suffix)
                    if isinstance(result, dict) and result.get("error"):
                        raise RuntimeError(result["error"])
                    report = load(JOB / f"review{suffix}_group{g}.json")
                    if report["verdict"] == "pass" and not report["patches"] and not report["unresolved"]:
                        gs["status"] = "통과"
                        break
                    if round_no == 0 and report["patches"]:
                        apply_candidate(report, api.group_files(g))
                        gs["review_round"] = 1
                        export(state)
                    else:
                        gs["status"] = "확인 필요"
                        break
            except Exception as exc:
                gs["status"] = "오류"
                gs["error"] = str(exc)
                if (JOB / "STOP").exists():
                    gs["status"] = "중지됨"
                    break
            export(state)
        if (JOB / "STOP").exists():
            state["status"] = "중지됨"
        else:
            state["status"] = "검사 종료" if all(v.get("status")=="통과" for v in state["groups"].values()) and len(state["groups"])==7 else "검사 종료 — 확인 필요 항목 있음"
        export(state)
    finally:
        lock.unlink(missing_ok=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("command", choices=["prepare", "start", "run", "status", "stop"])
    args = ap.parse_args()
    if args.command == "prepare":
        prepare()
        print("독립 실행 준비 완료")
    elif args.command == "run":
        run()
    elif args.command == "start":
        state = prepare()
        lock = JOB / "worker.lock"
        if lock.exists() and alive(int(lock.read_text() or "0")):
            print("이미 실행 중입니다")
            return
        (JOB / "STOP").unlink(missing_ok=True)
        with (JOB / "worker.log").open("a", encoding="utf-8") as log:
            flags = subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0
            proc = subprocess.Popen([sys.executable, "-u", str(pathlib.Path(__file__).resolve()), "run"], cwd=ROOT,
                                    stdin=subprocess.DEVNULL, stdout=log, stderr=log, close_fds=True,
                                    creationflags=flags, start_new_session=os.name != "nt")
        print(f"독립 프로세스 시작: {proc.pid}")
    elif args.command == "stop":
        JOB.mkdir(parents=True, exist_ok=True)
        (JOB / "STOP").touch()
        print("중지 요청됨. 응답 수신 시 또는 통신 시간 초과 뒤 멈춥니다(최대 약 60초).")
    else:
        if not (JOB / "state.json").exists():
            print("아직 시작하지 않았습니다")
            return
        state = load(JOB / "state.json")
        print(json.dumps({"status":state["status"], "pid":state.get("pid"), "running":alive(state.get("pid")), "groups":state["groups"]}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
