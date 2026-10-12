"""Final images through the user's ChatGPT plan (SPEC A23-151, 최종 검수 2026-10-12).

Runs the Codex desktop app's bundled CLI (`codex exec`, logged in with the user's ChatGPT account) with its built-in
image tool, in a throw-away folder, and copies the one generated PNG to --out. Concepts stay on Firefly Medium; this is
for confirmed (final) images. When ChatGPT usage runs out the script exits 3 -> draw that image with Firefly High.

  py tools/codex_image.py --prompt-file art/prompts/<id>.txt --ref <approved 2D> [--ref ...] --out art/out/<...>.png

Every image lit in the 3D world must be shadow-free (A23-150): the prompt must say so (flat even light, no cast /
ground / contact shadow, no AO, no dark side, no strong highlights). Modest clothing and no ray bursts as always.
Exit codes: 0 ok, 2 bad args / codex missing, 3 ChatGPT usage limit (use Firefly High), 4 no image produced.
"""
import argparse
import os
import shutil
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS = ["gpt-6-sol", "gpt-6.1-sol", "gpt-6-luna", "gpt-5.6-sol"]  # the agent model only drives the image tool
LIMIT_WORDS = ("usage limit", "rate limit", "limit reached", "quota", "upgrade your plan", "try again later")
CAPACITY_WORDS = ("at capacity", "try a different model")
SAVE_NAME = "codex_out.png"


def codex_exe():
    exe = os.environ.get("CODEX_EXE")
    if exe and os.path.exists(exe):
        return exe
    try:
        loc = subprocess.run(
            ["powershell", "-NoProfile", "-Command", "(Get-AppxPackage -Name 'OpenAI.Codex*').InstallLocation"],
            capture_output=True, text=True, timeout=60).stdout.strip().splitlines()
    except Exception:
        loc = []
    for line in loc:
        cand = os.path.join(line.strip(), "app", "resources", "codex.exe")
        if os.path.exists(cand):
            return cand
    return shutil.which("codex")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--prompt-file", required=True)
    ap.add_argument("--ref", action="append", default=[], help="reference image(s), e.g. the approved 2D")
    ap.add_argument("--out", required=True)
    ap.add_argument("--model", action="append", default=None, help="agent model(s) to try in order")
    ap.add_argument("--timeout", type=int, default=600)
    a = ap.parse_args()

    exe = codex_exe()
    if not exe:
        print("codex.exe not found (install the Codex app and log in with ChatGPT)", file=sys.stderr)
        return 2
    prompt = open(a.prompt_file, encoding="utf-8").read().strip()
    stem = os.path.splitext(os.path.basename(a.out))[0]
    work = os.path.join(ROOT, "build", "codex_jobs", "%s_%d" % (stem, int(time.time())))
    os.makedirs(work, exist_ok=True)
    refs = []
    for i, r in enumerate(a.ref):
        dst = os.path.join(work, "ref%d%s" % (i + 1, os.path.splitext(r)[1] or ".png"))
        shutil.copyfile(r, dst)
        refs.append(dst)
    ref_note = ""
    if refs:
        ref_note = ("The attached image(s) %s are the approved design: keep the same object/character, shape, colours, "
                    "proportions and view; change only what the instructions below say.\n\n"
                    % ", ".join(os.path.basename(p) for p in refs))
    task = ("Use your image generation tool to make exactly ONE image and save it in the current folder as %s. "
            "Do not create or edit any other file.\n\n%s%s\n" % (SAVE_NAME, ref_note, prompt))

    for model in (a.model or MODELS):
        cmd = [exe, "exec", "-m", model, "-C", work, "-s", "workspace-write", "--skip-git-repo-check"]
        for p in refs:
            cmd += ["-i", p]
        cmd.append("-")
        try:
            r = subprocess.run(cmd, input=task, capture_output=True, text=True, encoding="utf-8",
                               errors="replace", timeout=a.timeout)
            log = (r.stdout or "") + (r.stderr or "")
        except subprocess.TimeoutExpired:
            log = "timeout"
        open(os.path.join(work, "log_%s.txt" % model), "w", encoding="utf-8").write(log)
        out_png = os.path.join(work, SAVE_NAME)
        if os.path.exists(out_png):
            os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
            shutil.copyfile(out_png, a.out)
            print("OK %s (model %s, work %s)" % (a.out, model, work))
            return 0
        low = log.lower()
        if any(w in low for w in LIMIT_WORDS):
            print("CHATGPT_LIMIT: usage ran out -> draw this one with Firefly High (A23-151). log: %s" % work)
            return 3
        if any(w in low for w in CAPACITY_WORDS):
            print("model %s at capacity, trying the next" % model)
            continue
        print("no image from model %s, see %s" % (model, work))
    return 4


if __name__ == "__main__":
    sys.exit(main())
