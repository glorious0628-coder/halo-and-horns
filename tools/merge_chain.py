"""최종 검수 merge helper (2026-10-12): build merge commits on origin/main without touching the shared index or working
tree, export the result for offline tests, then push with a real check that the branches landed.

  py tools/merge_chain.py build <outdir> <commit>=<title> [<commit>=<title> ...]
      -> merge commits on origin/main (one per branch, in order), prints "FINAL <sha>", exports src/ tools/ docs/design
         of FINAL into <outdir>/tree (copy build/luau_cli_0_741 and build/*.luau in before running tools/test_*.py)
  py tools/merge_chain.py push <tested-final-sha> <commit>=<title> [...]
  (both take --ours <path> [--ours <path> ...]: a conflicted non-src file keeps main's version, e.g. an old state doc;
   a value ending in * is a prefix, e.g. --ours 'docs/art/verification_*' for generated test reports)
      -> rebuilds the same chain on the newest origin/main, refuses unless src/ is byte-identical to the tested FINAL,
         pushes, fetches and checks every branch commit is an ancestor of origin/main; retries while others push art/docs

A conflict is resolved only when a file has exactly ONE conflict block where both sides only ADDED lines at the same
spot (e.g. two branches appending to the end of Config.luau): both blocks are kept, ours first. Anything else stops.
The check reads the diff3 base part (10/12: a changed-on-both-sides line used to pass and was duplicated).
Why `push` exists: on 10/12 a hand-written retry treated "! [rejected] ... -> main" as success and a merge never
landed (게임성 검수 caught it). Never trust push output - check ancestry after a fetch.
"""
import os
import re
import subprocess
import sys
import tempfile

TRAILER = "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"


def run(*args, inp=None, env=None, ok=(0,)):
    r = subprocess.run(["git", *args], capture_output=True, input=inp, env=env)
    if r.returncode not in ok:
        raise SystemExit(f"git {' '.join(args)} failed ({r.returncode}): {r.stdout[-600:]!r} {r.stderr[-600:]!r}")
    return r


def out(*args):
    return run(*args).stdout.decode("utf-8", errors="replace").strip()


def resolve_append(text):
    # 10/12 fix: the conflict text comes in diff3 style (merge.conflictStyle=diff3) and is accepted ONLY when the base
    # part is empty, i.e. both sides inserted new lines at the same spot. Two branches that CHANGED the same line (e.g.
    # both editing ClientMain's ORDER list) have that line in the base part - keeping both sides would duplicate it
    # (three `local ORDER` lines compiled fine and silently dropped a module), so that stops for a hand merge.
    if len(re.findall(rb"^<<<<<<< [^\n]*\n", text, flags=re.M)) != 1:
        return None
    m = re.search(rb"^<<<<<<< [^\n]*\n(.*?)^\|\|\|\|\|\|\|[^\n]*\n(.*?)^=======\n(.*?)^>>>>>>> [^\n]*\n", text,
                  flags=re.M | re.S)
    if not m or m.group(2).strip():
        return None
    return text[:m.start()] + m.group(1) + m.group(3) + text[m.end():]


OURS = set()  # --ours <path>: a conflicted NON-src file (e.g. an old state doc) takes main's side, said in the message


def build_chain(specs):
    run("fetch", "-q", "origin")
    base = out("rev-parse", "origin/main")
    cur = base
    for commit, title in specs:
        r = run("-c", "merge.conflictStyle=diff3", "merge-tree", "--write-tree", "--name-only", cur, commit, ok=(0, 1))
        lines = r.stdout.decode("utf-8").splitlines()
        tree, note = lines[0], ""
        if r.returncode == 1:
            files = sorted({l for l in lines[1:] if l and not l.startswith(("Auto-merging", "CONFLICT"))})
            fd, idx = tempfile.mkstemp(prefix="merge_chain_idx_")
            os.close(fd)
            os.remove(idx)
            env = dict(os.environ, GIT_INDEX_FILE=idx)
            try:
                run("read-tree", tree, env=env)
                kept = []
                for f in files:
                    if (f in OURS or any(o.endswith("*") and f.startswith(o[:-1]) for o in OURS)) and not f.startswith("src/"):
                        ob = out("rev-parse", f"{cur}:{f}")
                        run("update-index", "--cacheinfo", f"100644,{ob},{f}", env=env)
                        print(f"  took main's side (--ours) for {f}")
                        kept.append(f + " (main)")
                        continue
                    text = run("cat-file", "-p", out("rev-parse", f"{tree}:{f}")).stdout
                    fixed = resolve_append(text)
                    if fixed is None:
                        raise SystemExit(f"{commit}: conflict in {f} is not a single append-only block - resolve by hand")
                    nb = run("hash-object", "-w", "--stdin", inp=fixed).stdout.decode().strip()
                    run("update-index", "--cacheinfo", f"100644,{nb},{f}", env=env)
                    print(f"  kept both appended blocks in {f}")
                tree = run("write-tree", env=env).stdout.decode().strip()
                note = "\n\n끝에 덧붙인 두 덩어리 충돌만 있어 둘 다 살림: " + ", ".join(files)
            finally:
                if os.path.exists(idx):
                    os.remove(idx)
        msg = f"{title}\n\n{commit[:10]} 병합 (게임성 검수 시험 + 최종 검수 확인){note}\n\n{TRAILER}\n"
        cur = run("commit-tree", tree, "-p", cur, "-p", commit, "-F", "-", inp=msg.encode("utf-8")).stdout.decode().strip()
        print("merged", commit[:10], "->", cur[:10])
    return base, cur


def parse_specs(argv):
    rest = []
    it = iter(argv)
    for a in it:
        if a == "--ours":
            OURS.add(next(it))
        else:
            rest.append(a)
    specs = [a.split("=", 1) for a in rest]
    if not specs or any(len(s) != 2 for s in specs):
        raise SystemExit(__doc__)
    return specs


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    if len(sys.argv) < 4:
        raise SystemExit(__doc__)
    os.chdir(out("rev-parse", "--show-toplevel"))
    mode = sys.argv[1]
    if mode == "build":
        outdir = sys.argv[2]
        base, final = build_chain(parse_specs(sys.argv[3:]))
        tree_dir = os.path.join(outdir, "tree")
        if os.path.exists(tree_dir):
            subprocess.run(["rm", "-rf", tree_dir])
        os.makedirs(tree_dir)
        arch = subprocess.run(["git", "archive", final, "src", "tools", "docs/design"], capture_output=True)
        subprocess.run(["tar", "-x", "-C", tree_dir], input=arch.stdout, check=True)
        changed = out("diff", "--name-only", base, final, "--", "src").splitlines()
        with open(os.path.join(outdir, "changed.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(changed))
        print("base", base[:10])
        print("FINAL", final)
        print("changed src", len(changed))
    elif mode == "push":
        tested = sys.argv[2]
        specs = parse_specs(sys.argv[3:])
        for attempt in range(8):
            _, final = build_chain(specs)
            if run("diff", "--quiet", tested, final, "--", "src", ok=(0, 1)).returncode != 0:
                raise SystemExit("src/ differs from the tested FINAL (origin changed src) - rebuild and retest")
            run("push", "origin", f"{final}:refs/heads/main", ok=(0, 1))
            run("fetch", "-q", "origin")
            if all(run("merge-base", "--is-ancestor", c, "origin/main", ok=(0, 1)).returncode == 0 for c, _ in specs):
                print("VERIFIED in origin/main:", out("rev-parse", "--short", "origin/main"))
                return
            print(f"not landed yet (someone pushed first), retry {attempt + 1}")
        raise SystemExit("push did not land after 8 tries")
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
