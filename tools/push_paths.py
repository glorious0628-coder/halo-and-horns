"""
Push files from the shared working tree straight onto origin/main without a local commit.

  py tools/push_paths.py -m "커밋 제목" [-m "본문"] <path> [<path> ...]

Why (2026-10-07): several sessions share C:\\Users\\glori\\Documents\\Roblox\\Game. A local commit that is not pushed yet
is wiped from the working tree when another session runs `git reset --keep origin/main` (it happened to 검수's
handoff file). Uncommitted edits survive another session's reset --keep, so this tool never commits locally:
  1. git fetch origin
  2. hash the working-tree files of <path>... (a missing file = delete it)
  3. build a commit on top of origin/main in a private temporary index (commit-tree), push it
  4. if the push is rejected (someone pushed first), fetch and rebuild on the new origin/main (up to 5 tries)
  5. `git reset --keep origin/main` so the shared HEAD equals origin again (your pushed files are now clean)
Only the listed paths are touched; nobody else's staged or modified files are committed.

Before anything is pushed (검수 2026-10-10, the core of a pre-push AI check, our way): a secrets scan of the listed paths.
A path named .env / .env.* (not *.example), anything under .tripo/, *.pem or id_rsa* is refused; a text file holding a
key-shaped value (TRIPO_API_KEY=<value>, an sk-ant- key, a PRIVATE KEY block, a long tsk_ token) is refused. Only the
file and line number are printed - never the value. Nothing is pushed when anything is found.
"""

import os
import re
import subprocess
import sys
import tempfile

TRAILER = "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"

# key shapes (built from pieces so this file never matches itself)
SECRET_PATTERNS = [
    ("TRIPO_API_KEY with a value", re.compile("TRIPO_API_KEY" + r"\s*[=:]\s*['\"]?[A-Za-z0-9_\-]{8,}")),
    ("an Anthropic key (sk-ant-)", re.compile("sk-" + "ant-" + r"[A-Za-z0-9_\-]{10,}")),
    ("a PRIVATE KEY block", re.compile("-----BEGIN " + r"[A-Z ]*" + "PRIVATE KEY-----")),
    ("a long tsk_ token", re.compile(r"\b" + "tsk" + r"_[A-Za-z0-9_\-]{20,}")),
]
MAX_SCAN_BYTES = 5 * 1024 * 1024
# a matched value holding one of these is a placeholder in docs / tests (vendor 'TRIPO_API_KEY=your_api_key'), not a key
PLACEHOLDER_WORDS = ("your", "xxx", "dummy", "fake", "test", "example", "placeholder", "here", "redact", "<", "...")


def secret_name(path):
    """why a path's NAME alone is refused, else None"""
    parts = path.replace("\\", "/").split("/")
    name = parts[-1]
    if name == ".env" or (name.startswith(".env.") and not name.endswith(".example")):
        return "an .env file"
    if ".tripo" in parts[:-1] or name == ".tripo":
        return "under .tripo/"
    if name.lower().endswith(".pem"):
        return "a .pem key file"
    if name.startswith("id_rsa"):
        return "an id_rsa key file"
    return None


def scan_paths(paths):
    """[(path, line or None, reason)] for every listed path that looks like a secret; never holds the value itself"""
    found = []
    for p in paths:
        why = secret_name(p)
        if why:
            found.append((p, None, why))
            continue
        if not os.path.isfile(p) or os.path.getsize(p) > MAX_SCAN_BYTES:
            continue
        with open(p, "rb") as f:
            data = f.read()
        if b"\x00" in data[:4096]:
            continue  # a binary file (images, places)
        text = data.decode("utf-8", errors="replace")
        for n, line in enumerate(text.splitlines(), 1):
            for reason, pat in SECRET_PATTERNS:
                m = pat.search(line)
                if m and not any(w in m.group(0).lower() for w in PLACEHOLDER_WORDS):
                    found.append((p, n, reason))
    return found


def git(*args, env=None, check=True, inp=None):
    r = subprocess.run(["git", *args], capture_output=True, text=True, encoding="utf-8", errors="replace",
                       env=env, input=inp)
    if check and r.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed: {r.stderr.strip()}")
    return r.stdout.strip()


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    args = sys.argv[1:]
    msgs, paths = [], []
    i = 0
    while i < len(args):
        if args[i] == "-m" and i + 1 < len(args):
            msgs.append(args[i + 1])
            i += 2
        else:
            paths.append(args[i].replace("\\", "/"))
            i += 1
    if not msgs or not paths:
        sys.exit(__doc__)
    message = "\n\n".join(msgs)
    if TRAILER not in message:
        message += "\n\n" + TRAILER
    top = git("rev-parse", "--show-toplevel")
    os.chdir(top)
    found = scan_paths(paths)
    if found:
        for p, n, reason in found:
            print(f"비밀 같은 것 발견 - 올리지 않아요: {p}{'' if n is None else ':' + str(n)} ({reason})")
        sys.exit("push 중단: 위 파일에서 비밀 값을 빼고 다시 해 주세요 (값은 출력하지 않았어요)")
    blobs = {}
    for p in paths:
        blobs[p] = git("hash-object", "-w", p) if os.path.isfile(p) else None
    for attempt in range(5):
        git("fetch", "-q", "origin")
        base = git("rev-parse", "origin/main")
        fd, idx = tempfile.mkstemp(prefix="push_paths_idx_")
        os.close(fd)
        os.remove(idx)
        env = dict(os.environ, GIT_INDEX_FILE=idx)
        try:
            git("read-tree", base, env=env)
            for p, b in blobs.items():
                if b is None:
                    git("update-index", "--force-remove", p, env=env, check=False)
                else:
                    git("update-index", "--add", "--cacheinfo", f"100644,{b},{p}", env=env)
            tree = git("write-tree", env=env)
        finally:
            if os.path.exists(idx):
                os.remove(idx)
        if tree == git("rev-parse", f"{base}^{{tree}}"):
            print("변경 없음: origin/main에 이미 같은 내용이 있어요")
            break
        commit = git("commit-tree", tree, "-p", base, "-F", "-", inp=message)
        r = subprocess.run(["git", "push", "-q", "origin", f"{commit}:refs/heads/main"], capture_output=True, text=True)
        if r.returncode == 0:
            print(f"push 완료: {commit[:7]} ({len(paths)}개 경로)")
            break
        print(f"push 거절({attempt + 1}/5), 새 origin/main 위에서 다시 만들어요")
    else:
        sys.exit("push 실패: 5번 모두 거절됐어요")
    git("fetch", "-q", "origin")
    # reset --keep refuses while a pushed file still shows as 'modified' (or 'untracked') against the old HEAD, even
    # though it already equals origin. Put each such file back to the old HEAD version (or remove a new one) first;
    # the reset below writes origin's (= your pushed) version again at once.
    touched = {}  # path -> pushed blob, so a failed reset can put the file back
    for p, b in blobs.items():
        if b is None or not os.path.isfile(p):
            continue
        if git("rev-parse", f"origin/main:{p}", check=False) != b or git("hash-object", p) != b:
            continue  # someone changed it again meanwhile: leave it alone
        if git("cat-file", "-e", f"HEAD:{p}", check=False) == "" and subprocess.run(
                ["git", "cat-file", "-e", f"HEAD:{p}"], capture_output=True).returncode == 0:
            git("checkout", "HEAD", "--", p, check=False)
        else:
            os.remove(p)
        touched[p] = b
    # 2026-10-07 (검수): other sessions' pushed files often sit in the shared tree as 'modified' or 'untracked' with
    # exactly origin's bytes (their own reset was blocked by a third file), and then block every later reset. Any file
    # that origin changed and whose working bytes already equal origin's is put back to HEAD (or removed when HEAD
    # lacks it); the reset below writes the same bytes again. Files with other bytes are never touched.
    for p in git("diff", "--name-only", "HEAD", "origin/main").splitlines():
        if p in touched or not os.path.isfile(p):
            continue
        want = git("rev-parse", f"origin/main:{p}", check=False)
        if not want or git("hash-object", p) != want:
            continue
        if subprocess.run(["git", "cat-file", "-e", f"HEAD:{p}"], capture_output=True).returncode == 0:
            git("checkout", "HEAD", "--", p, check=False)
        else:
            os.remove(p)
        touched[p] = want
    r = subprocess.run(["git", "reset", "--keep", "origin/main"], capture_output=True, text=True)
    if r.returncode != 0:
        print("주의: reset --keep이 막혔어요(다른 세션의 수정과 겹침). 공유 HEAD는 그대로예요:", r.stderr.strip()[:200])
        # 2026-10-07 (이미지 생성 2 report): the files reverted/removed above would stay gone from the working tree.
        # Write the pushed bytes back so the session's work is still on disk (it is already safe in origin).
        for p, b in touched.items():
            data = subprocess.run(["git", "cat-file", "-p", b], capture_output=True).stdout
            os.makedirs(os.path.dirname(p) or ".", exist_ok=True)
            with open(p, "wb") as f:
                f.write(data)
        if touched:
            print(f"올린 파일 {len(touched)}개를 작업 폴더에 다시 써 두었어요(origin과 같은 내용).")
    ab = git("rev-list", "--left-right", "--count", "HEAD...origin/main")
    print("HEAD...origin/main =", ab)


if __name__ == "__main__":
    main()
