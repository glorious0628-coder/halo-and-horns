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
  5. move the shared HEAD to origin/main (sync_head: files only ever move forward, see there; 2026-10-11)
Only the listed paths are touched; nobody else's staged or modified files are committed.
`py tools/push_paths.py --sync` does step 5 alone.

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
import time

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
    sync_head()


ZERO = "0" * 40
FILE_MODES = ("000000", "100644", "100755")


def pid_alive(pid):
    if os.name == "nt":  # never os.kill on Windows: it terminates the process
        import ctypes
        k = ctypes.windll.kernel32
        h = k.OpenProcess(0x1000, False, pid)  # PROCESS_QUERY_LIMITED_INFORMATION
        if not h:
            return False
        code = ctypes.c_ulong()
        ok = k.GetExitCodeProcess(h, ctypes.byref(code))
        k.CloseHandle(h)
        return bool(ok) and code.value == 259  # STILL_ACTIVE
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def take_sync_lock(path):
    """one sync_head at a time: two at once can move HEAD backwards. The lock holds the owner's pid; a lock whose
    owner is gone (killed by a tool timeout) or older than 10 min is taken over."""
    for _ in range(30):
        try:
            fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            os.write(fd, str(os.getpid()).encode())
            os.close(fd)
            return True
        except FileExistsError:
            try:
                with open(path, encoding="ascii", errors="replace") as f:
                    owner = f.read().strip()
                dead = owner.isdigit() and not pid_alive(int(owner))
                if dead or time.time() - os.path.getmtime(path) > 600:
                    os.remove(path)
                    continue
            except OSError:
                pass
            time.sleep(2)
    return False


def parse_raw(data):
    """[(path, old blob or None, new blob or None, plain file mode)] from `git diff/log --raw -z` output"""
    out = []
    toks = data.split(b"\0")
    i = 0
    while i < len(toks):
        meta = toks[i].lstrip(b"\n")
        if not meta.startswith(b":") or i + 1 >= len(toks):
            i += 1
            continue
        path = toks[i + 1].decode("utf-8")
        i += 2
        omode, nmode, ob, nb, _ = meta[1:].decode().split(" ", 4)
        out.append((path, None if ob == ZERO else ob, None if nb == ZERO else nb,
                    omode in FILE_MODES and nmode in FILE_MODES))
    return out


def raw_is_checkout(paths):
    """{path: True} when checkout writes the blob bytes as they are (no filter, LF or binary) - true for this repo's
    `* text=auto eol=lf`; other paths get one `git cat-file --filters` each"""
    if not paths:
        return {}
    r = subprocess.run(["git", "check-attr", "-z", "--stdin", "filter", "eol", "text"], capture_output=True,
                       input=b"\0".join(p.encode("utf-8") for p in paths) + b"\0")
    toks = r.stdout.split(b"\0")
    attrs = {}
    for j in range(0, len(toks) - 2, 3):
        attrs.setdefault(toks[j].decode("utf-8"), {})[toks[j + 1].decode()] = toks[j + 2].decode()
    ok = {}
    for p in paths:
        a = attrs.get(p, {})
        no_filter = a.get("filter", "unspecified") in ("unspecified", "unset")
        ok[p] = no_filter and (a.get("eol") == "lf" or a.get("text") == "unset")
    return ok


class BlobReader:
    """one `git cat-file --batch` for all blobs (each git start costs ~2.5 s in the shared tree)"""

    def __init__(self):
        self.proc = subprocess.Popen(["git", "cat-file", "--batch"], stdin=subprocess.PIPE, stdout=subprocess.PIPE)

    def read(self, blob):
        self.proc.stdin.write(blob.encode() + b"\n")
        self.proc.stdin.flush()
        head = self.proc.stdout.readline().split()
        if len(head) != 3 or head[1] != b"blob":
            return None
        data = self.proc.stdout.read(int(head[2]))
        self.proc.stdout.read(1)
        return data

    def close(self):
        try:
            self.proc.stdin.close()
            self.proc.wait(timeout=10)
        except Exception:
            self.proc.kill()


def prune_empty_dirs(path):
    d = os.path.dirname(path)
    while d:
        try:
            os.rmdir(d)  # only succeeds when empty
        except OSError:
            return
        d = os.path.dirname(d)


def sync_head():
    """Move the shared HEAD (and index) to origin/main without ever reverting or removing anyone's work.

    2026-10-11 (최종 검수): the old way put pushed files back to the old HEAD (or removed new ones) and then ran
    `git reset --keep`. When a stale .git/index.lock blocked the reset, or the caller's tool timeout killed the script
    half way, files stayed reverted or deleted in the working tree (이미지 생성 3 lost new tools twice, src/ files were
    left at old versions). Now a file only ever moves FORWARD, so a kill at any point is harmless and a rerun
    finishes the job:
      - one run at a time (a lock file next to the index; HEAD is checked again right before the reset)
      - for each path origin changed since HEAD: working bytes == origin -> nothing; working bytes == ANY version the
        path had between HEAD and origin (or absent where one of those versions was absent) -> write origin's version
        (or remove it, and empty folders, when origin removed it); anything else is someone's edit -> never touched,
        listed so they merge before pushing it. A file saved (or created) while this runs counts as an edit.
      - deletions go first, so a case-only rename on Windows ends with the new name, not with no file
      - then `git reset --mixed origin/main` moves HEAD + index only (never the working tree)
    HEAD stays put while a clean file could not move forward (open in another program) - moving
    it would make the old bytes look like an edit - and when HEAD has local commits that origin lacks."""
    head = git("rev-parse", "HEAD")
    new = git("rev-parse", "origin/main")
    if head == new:
        print("HEAD...origin/main = 0\t0")
        return
    if git("rev-list", "--count", f"{new}..{head}") != "0":
        print("주의: 공유 HEAD에 origin에 없는 로컬 커밋이 있어요. 지워질 수 있어서 HEAD를 옮기지 않았어요 - 검수에 알려 주세요.")
        print("HEAD...origin/main =", git("rev-list", "--left-right", "--count", "HEAD...origin/main"))
        return
    lock = git("rev-parse", "--git-path", "push_paths_sync.lock")
    if not take_sync_lock(lock):
        print("다른 세션이 공유 HEAD를 맞추는 중이라 건너뛰었어요 (올린 것은 origin에 안전해요)")
        return
    try:
        sync_locked(head, new)
    finally:
        try:
            os.remove(lock)
        except OSError:
            pass


def sync_locked(head, new):
    if git("rev-parse", "HEAD") != head:
        print("공유 HEAD가 방금 바뀌어서 이번에는 건너뛰었어요")
        return
    r = subprocess.run(["git", "diff", "--raw", "-z", "--no-renames", "--no-abbrev", head, new], capture_output=True)
    lg = subprocess.run(["git", "log", "--format=", "--raw", "-z", "--no-renames", "--no-abbrev", f"{head}..{new}"],
                        capture_output=True)
    if r.returncode != 0 or lg.returncode != 0:
        print("주의: git diff/log 실패 - 공유 HEAD를 그대로 뒀어요:", (r.stderr + lg.stderr).decode(errors="replace")[:200])
        return
    versions = {}  # path -> every blob (None = absent) the path had in head..new
    for p, ob, nb, _ in parse_raw(lg.stdout):
        versions.setdefault(p, set()).update((ob, nb))
    changes, skipped = [], []
    for p, ob, nb, ok in parse_raw(r.stdout):
        if ok:
            changes.append((p, ob, nb))
        else:
            skipped.append(p)  # a symlink / submodule: leave it to a person
    changes.sort(key=lambda c: (c[2] is not None, c[0]))  # deletions first (case-only renames on Windows)
    files = [p for p, _, _ in changes if os.path.isfile(p)]
    stat0 = {}
    for p in files:
        try:
            st = os.stat(p)
            stat0[p] = (st.st_size, st.st_mtime_ns)
        except OSError:
            pass
    cur = {}
    if files:
        out = subprocess.run(["git", "hash-object", "--stdin-paths"], capture_output=True,
                             input=("\n".join(files) + "\n").encode("utf-8")).stdout.decode().split()
        if len(out) == len(files):
            cur = dict(zip(files, out))
        else:  # a file git cannot read (locked by another program): hash one by one
            for p in files:
                cur[p] = git("hash-object", p, check=False) or "unreadable"
    rawok = raw_is_checkout([p for p, _, nb in changes if nb is not None])
    reader = BlobReader()
    moved, kept, blocked = 0, [], []  # blocked = a clean (or unreadable) file that could not move forward
    done = set()  # casefolded paths this run wrote or removed
    try:
        for p, ob, nb in changes:
            seen = versions.get(p, set()) | {ob}
            mine = p.casefold() in done
            if os.path.isfile(p):
                try:
                    st = os.stat(p)
                    same = stat0.get(p) == (st.st_size, st.st_mtime_ns)
                except OSError:
                    same = False
                if mine:
                    have = git("hash-object", p, check=False) or "unreadable"
                elif not same:
                    kept.append(p)  # saved or created while this ran: someone is working on it
                    continue
                else:
                    have = cur.get(p, "unreadable")
            elif os.path.isdir(p):
                prune_empty_dirs(os.path.join(p, "x"))  # an empty folder (maybe emptied above) is in the way
                if os.path.lexists(p):
                    kept.append(p)  # someone's folder with files where origin now has a file: a person merges it
                    continue
                have = None
            elif os.path.lexists(p):
                kept.append(p)  # a link or something odd: a person decides
                continue
            else:
                if p in stat0 and not mine:
                    kept.append(p)  # removed while this ran
                    continue
                have = None
            if have == nb:
                continue
            if have == "unreadable":
                blocked.append(p)
                continue
            if have not in seen:
                kept.append(p)
                continue
            tmp = p + ".push_paths_tmp"
            try:
                if nb is None:
                    os.remove(p)
                    prune_empty_dirs(p)
                else:
                    if rawok.get(p):
                        data = reader.read(nb)
                    else:
                        c = subprocess.run(["git", "cat-file", "--filters", f"--path={p}", nb], capture_output=True)
                        data = c.stdout if c.returncode == 0 else None
                    if data is None:
                        blocked.append(p)
                        continue
                    try:
                        os.makedirs(os.path.dirname(p) or ".", exist_ok=True)
                    except OSError:
                        kept.append(p)  # someone's file sits where origin now has a folder: a person merges it
                        continue
                    with open(tmp, "wb") as f:
                        f.write(data)
                    os.replace(tmp, p)  # never a half-written file
            except OSError as e:  # open in Studio / an editor, or a file where a folder must go
                print(f"주의: {p} 를 못 바꿨어요({e.__class__.__name__}) - 그대로 둠")
                try:
                    if os.path.exists(tmp):
                        os.remove(tmp)
                except OSError:
                    pass
                blocked.append(p)
                continue
            done.add(p.casefold())
            moved += 1
    finally:
        reader.close()
    if blocked:
        # moving HEAD now would make these old bytes look like someone's edit (and Studio sync would push them)
        print(f"주의: 파일 {len(blocked)}개를 새 판으로 못 바꿔서 공유 HEAD를 그대로 뒀어요"
              " (다른 프로그램이 열었음 - 닫은 뒤 py tools/push_paths.py --sync):")
        for p in blocked[:20]:
            print("  ", p)
    elif git("rev-parse", "HEAD") != head:
        print("공유 HEAD가 방금 바뀌어서 이번에는 옮기지 않았어요 (파일은 이미 새 판)")
    else:
        for attempt in range(15):
            r = subprocess.run(["git", "reset", "-q", "--mixed", new], capture_output=True, text=True,
                               encoding="utf-8", errors="replace")
            if r.returncode == 0 or "index.lock" not in r.stderr:
                break
            time.sleep(2)  # another git (or an app's git status) holds the index for a moment
        if r.returncode != 0:
            print("주의: 공유 HEAD를 못 옮겼어요(파일은 새 판으로 맞춘 그대로 - 다음 push나 --sync 때 다시 해요):",
                  r.stderr.strip()[:200])
    if moved:
        print(f"origin에서 바뀐 깨끗한 파일 {moved}개를 새 판으로 맞췄어요")
    if kept or skipped:
        print(f"주의: origin에서도 바뀐 파일 {len(kept) + len(skipped)}개는 누군가 고치는 중이라 그대로 뒀어요"
              " (올리기 전에 origin 판과 합치세요):")
        for p in (kept + skipped)[:20]:
            print("  ", p)
    print("HEAD...origin/main =", git("rev-list", "--left-right", "--count", "HEAD...origin/main"))


if __name__ == "__main__":
    if sys.argv[1:] == ["--sync"]:
        sys.stdout.reconfigure(encoding="utf-8")
        os.chdir(git("rev-parse", "--show-toplevel"))
        git("fetch", "-q", "origin")
        sync_head()
    else:
        main()
