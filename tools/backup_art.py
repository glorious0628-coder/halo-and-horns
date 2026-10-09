"""
Back up the art files that live only on this PC to the private GitHub repo glorious0628-coder/halo-and-horns-art.

  py tools/backup_art.py            # copy + commit + push (only what changed since last time)

What (SPEC A23-90, user 2026-10-09 "비공개 GitHub 저장소"):
  - every file under art/ that the main repo does not track (untracked + git-ignored),
  - the current practice/main places build/{GoodEvil,WorldKit,UiSandbox,FilmSet}.rbxlx.
Never backed up: art/out/v1/ and the four revealing copies (AGENTS hard rule 1; they are to be deleted).
GitHub takes at most 2 GB per push and 100 MB per file, so files are committed and pushed in batches of ~1.2 GB and
files over 95 MB are skipped (listed at the end).
The backup repo is a plain folder next to the game: C:/Users/glori/Documents/Roblox/HH-art-backup.
"""

import os
import shutil
import subprocess
import sys

GAME = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BACKUP = os.path.join(os.path.dirname(GAME), "HH-art-backup")
REMOTE = "https://github.com/glorious0628-coder/halo-and-horns-art.git"
PLACES = ["build/GoodEvil.rbxlx", "build/WorldKit.rbxlx", "build/UiSandbox.rbxlx", "build/FilmSet.rbxlx"]
NEVER = {"art/ui/UIP_CharHaloArcher.png", "art/ui/UIP_CharHornsArcher.png", "art/ui/UIP_CharHornsMage.png",
         "art/ui/UIP_CharHornsWarrior.png", "art/out/UIP_CharHaloArcher.png", "art/out/UIP_CharHornsArcher.png",
         "art/out/UIP_CharHornsMage.png", "art/out/UIP_CharHornsWarrior.png"}
BATCH = 1200 * 1024 * 1024
MAX_FILE = 95 * 1024 * 1024
TRAILER = "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"


def run(args, cwd, check=True):
    r = subprocess.run(args, cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if check and r.returncode != 0:
        raise RuntimeError(f"{' '.join(args)} failed: {r.stderr.strip()[:400]}")
    return r.stdout


def wanted():
    out = run(["git", "ls-files", "--others", "-z", "art"], GAME)
    out += run(["git", "ls-files", "--others", "--ignored", "--exclude-standard", "-z", "art"], GAME)
    paths = sorted({p.replace("\\", "/") for p in out.split("\0") if p})
    paths = [p for p in paths if not p.startswith("art/out/v1/") and p not in NEVER]
    paths += [p for p in PLACES if os.path.isfile(os.path.join(GAME, p))]
    return paths


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    os.makedirs(BACKUP, exist_ok=True)
    if not os.path.isdir(os.path.join(BACKUP, ".git")):
        run(["git", "init", "-b", "main"], BACKUP)
        run(["git", "remote", "add", "origin", REMOTE], BACKUP)
        run(["git", "config", "core.longpaths", "true"], BACKUP)
    skipped, changed = [], []
    for p in wanted():
        src = os.path.join(GAME, p)
        dst = os.path.join(BACKUP, p)
        size = os.path.getsize(src)
        if size > MAX_FILE:
            skipped.append((p, size))
            continue
        if os.path.isfile(dst) and os.path.getsize(dst) == size and os.path.getmtime(dst) >= os.path.getmtime(src):
            continue
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)
        changed.append((p, size))
    print(f"copied {len(changed)} files, {sum(s for _, s in changed) / 1048576:.0f} MB")
    batch, total, n = [], 0, 0
    for p, size in changed + [(None, 0)]:
        if p is not None:
            batch.append(p)
            total += size
        if batch and (p is None or total >= BATCH):
            n += 1
            for i in range(0, len(batch), 200):
                run(["git", "add", "--", *batch[i:i + 200]], BACKUP)
            run(["git", "commit", "-q", "-m", f"art backup batch {n} ({len(batch)} files)\n\n{TRAILER}"], BACKUP)
            run(["git", "push", "-q", "origin", "main"], BACKUP)
            print(f"pushed batch {n}: {len(batch)} files, {total / 1048576:.0f} MB")
            batch, total = [], 0
    if not changed:
        print("nothing new")
    for p, size in skipped:
        print(f"skipped (over 95 MB): {p} {size / 1048576:.0f} MB")


if __name__ == "__main__":
    main()
