"""No-shadow redraw driver (이미지 생성 2, SPEC A23-150/151). Runs tools/codex_image.py one image at a time.
Usage: py tools/_noshadow_redo.py <Name> [<Name> ...]   (names from docs/review/noshadow_redo_2026-10-12.md)
Per name: front first (ref1 = old front), then back/left/right (ref1 = old that view if found, ref2 = new front).
Output art/out/s2/noshadow/<Name>_<view>_ns.png ; skips existing; stops with exit 3 when ChatGPT usage is out."""
import glob
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOC = os.path.join(ROOT, "docs/review/noshadow_redo_2026-10-12.md")
OUT = os.path.join(ROOT, "art/out/s2/noshadow")
LOG = os.path.join(ROOT, "build/img2_next/noshadow_log.txt")
LIGHT = ("Keep the 3D look: real volume, rounded edges, soft gentle form shading so every shape reads as 3D, same smooth material as the ref. "
         "Lighting: soft, even studio light from all around (like a bright light box). NO cast shadows, NO shadow on the ground or floor, "
         "NO contact shadows, NO ambient-occlusion darkening in crevices, NO dark shadowed side, no strong glare highlights, no glowing light that lights the walls. "
         "Colours stay bright and true to the design. Plain light grey background, no floor. No text, no extra objects, no ray patterns. Modest, kid-friendly. Square image.")
FRONT = ("ref1 is an approved design of a prop/building for a kid-friendly Roblox game. Redraw the SAME object exactly (same shapes, parts, count of windows/towers/ornaments, colours, "
         "proportions, materials) as a 3D-rendered toy-like object, seen straight-on from the FRONT at mid-height, perfectly centered, whole object in frame with a margin. "
         "If ref1 is slightly angled or from above, turn it to a straight-on front view. " + LIGHT)
OTHER = ("ref1 is an approved view of an object for a kid-friendly Roblox game; ref2 is the same object's new front view. Redraw the SAME object exactly as in ref2 (same shapes, parts, colours, "
         "proportions, materials), as a 3D-rendered toy-like object, from the SAME camera viewpoint and direction as ref1, whole object in frame, centered. " + LIGHT)
OTHER_NOREF = ("ref1 is the new front view of an object for a kid-friendly Roblox game. Draw the SAME object exactly (same shapes, parts, colours, proportions, materials) as a 3D-rendered toy-like object "
               "seen straight-on from the %s at mid-height, whole object in frame, centered, the same size and distance as ref1. " + LIGHT)
SIDE_WORDS = {"back": "BACK (opposite side to ref1)", "left": "left side (90 degrees to the left of ref1's front)", "right": "right side (90 degrees to the right of ref1's front)"}


def rows():
    out = {}
    for line in open(DOC, encoding="utf-8"):
        m = re.match(r"\|\s*([^|]+?)\s*\|[^|]*\|[^|]*\|[^|]*\|[^|]*\|\s*`([^`]+)`\s*\|", line)
        if m:
            out[m.group(1)] = m.group(2)
    return out


def old_view(path, view):
    d, f = os.path.split(path)
    cands = []
    if "front" in f:
        base = f.replace("front", view)
        cands.append(os.path.join(d, base))
        stem = f.split("front")[0]
        cands += sorted(glob.glob(os.path.join(d, stem + view + "*")))
    hit = next((c for c in cands if os.path.exists(c)), None)
    if hit:
        return hit
    # search the other halo folders (kits_mv etc.) for <stem>...<view>...
    stem = re.sub(r"[_-]?front.*$", "", os.path.splitext(f)[0])
    stem = re.sub(r"_HQ$|_src$|_v\d$", "", stem)
    for root, _, files in os.walk(os.path.join(ROOT, "art/out/s2")):
        for fn in sorted(files):
            if fn.startswith(stem) and re.search(r"[_-]%s([_.-]|$)" % view, fn) and fn.lower().endswith(".png") and "ns" not in fn.split("_")[-1:]:
                return os.path.join(root, fn)
    return None


def run(prompt, refs, out):
    pf = out[:-4] + ".txt"
    os.makedirs(os.path.dirname(out), exist_ok=True)
    open(pf, "w", encoding="utf-8").write(prompt)
    cmd = [sys.executable, os.path.join(ROOT, "tools/codex_image.py"), "--prompt-file", pf, "--out", out]
    for r in refs:
        cmd += ["--ref", r]
    p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    msg = (p.stdout or "") + (p.stderr or "")
    open(LOG, "a", encoding="utf-8").write("%s rc=%s %s\n" % (os.path.basename(out), p.returncode, msg.strip()[-200:]))
    return p.returncode


def main():
    table = rows()
    for name in sys.argv[1:]:
        old = table.get(name)
        if not old:
            print("not in doc:", name)
            continue
        oldp = os.path.join(ROOT, old)
        front = os.path.join(OUT, "%s_front_ns.png" % name)
        if not os.path.exists(front):
            rc = run(FRONT, [oldp], front)
            if rc:
                return rc
        for v in ("back", "left", "right"):
            out = os.path.join(OUT, "%s_%s_ns.png" % (name, v))
            if os.path.exists(out):
                continue
            ov = old_view(oldp, v)
            if ov:
                rc = run(OTHER, [ov, front], out)
            else:
                rc = run(OTHER_NOREF % SIDE_WORDS[v], [front], out)
            if rc:
                return rc
    return 0


if __name__ == "__main__":
    sys.exit(main())
