"""Estimate Console API spend of Claude Code sessions from their JSONL transcripts.

Usage:
  py tools/api_spend.py [--since 2026-10-09T05:59:00Z] [--start 199.97] [--all-projects]

Reads ~/.claude/projects/<project>/**/*.jsonl, keeps assistant records newer than --since,
dedupes by message id, and prices usage per model (USD per million tokens, claude-api skill
2026-10-06 table: Opus 5.5 $4/$20, Sonnet 5.5 $2/$10, cache read $0.20, cache write 1.25x (5 min) /
2x (1 h) of input). Prints spend per session file and the estimated balance left.
This is an estimate; the Console billing page is the real number.
"""
import glob
import json
import os
import sys
from collections import defaultdict

PRICES = {
    # model prefix: (input, output, cache_read)
    "claude-opus-5-5": (4.0, 20.0, 0.20),
    "claude-sonnet-5-5": (2.0, 10.0, 0.20),
    "claude-haiku-5-5": (0.10, 0.50, 0.01),
    "claude-fable-5-1": (10.0, 50.0, 0.25),
    "claude-opus-5": (5.0, 25.0, 0.50),
    "claude-sonnet-5": (2.0, 10.0, 0.20),
}

PROJECT_ROOT = os.path.join(os.path.expanduser("~"), ".claude", "projects")
DEFAULT_PROJECT = "C--Users-glori-Documents-Roblox-Game"


def price_for(model):
    if not model:
        return None
    best = None
    for prefix, p in PRICES.items():
        if model.startswith(prefix) and (best is None or len(prefix) > len(best[0])):
            best = (prefix, p)
    return best[1] if best else None


def cost_of(usage, model):
    p = price_for(model)
    if p is None:
        return 0.0, True
    inp, out, cread = p
    cc = usage.get("cache_creation") or {}
    w5 = cc.get("ephemeral_5m_input_tokens")
    w1 = cc.get("ephemeral_1h_input_tokens")
    total_write = usage.get("cache_creation_input_tokens") or 0
    if w5 is None and w1 is None:
        w5, w1 = total_write, 0
    w5 = w5 or 0
    w1 = w1 or 0
    c = (
        (usage.get("input_tokens") or 0) * inp
        + (usage.get("output_tokens") or 0) * out
        + (usage.get("cache_read_input_tokens") or 0) * cread
        + w5 * inp * 1.25
        + w1 * inp * 2.0
    ) / 1_000_000
    return c, False


def first_prompt(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                try:
                    rec = json.loads(line)
                except Exception:
                    continue
                msg = rec.get("message")
                if isinstance(msg, dict) and msg.get("role") == "user":
                    content = msg.get("content")
                    if isinstance(content, str):
                        text = content
                    elif isinstance(content, list):
                        text = " ".join(
                            p.get("text", "") for p in content if isinstance(p, dict) and p.get("type") == "text"
                        )
                    else:
                        text = ""
                    text = text.strip()
                    if text and not text.startswith("<"):
                        return text[:60].replace("\n", " ")
    except Exception:
        pass
    return ""


def main():
    args = sys.argv[1:]
    since = "2026-10-09T05:59:00Z"
    start = 199.97
    all_projects = False
    i = 0
    while i < len(args):
        if args[i] == "--since":
            since = args[i + 1]
            i += 2
        elif args[i] == "--start":
            start = float(args[i + 1])
            i += 2
        elif args[i] == "--all-projects":
            all_projects = True
            i += 1
        else:
            i += 1

    if all_projects:
        roots = [os.path.join(PROJECT_ROOT, d) for d in os.listdir(PROJECT_ROOT)]
    else:
        roots = [os.path.join(PROJECT_ROOT, DEFAULT_PROJECT)]

    seen = set()
    per_file = defaultdict(float)
    per_model = defaultdict(float)
    unknown_models = set()
    total = 0.0
    for root in roots:
        if not os.path.isdir(root):
            continue
        for path in glob.glob(os.path.join(root, "**", "*.jsonl"), recursive=True):
            try:
                if os.path.getmtime(path) < 0:
                    continue
            except OSError:
                continue
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                for line in f:
                    if '"usage"' not in line:
                        continue
                    try:
                        rec = json.loads(line)
                    except Exception:
                        continue
                    ts = rec.get("timestamp") or ""
                    if ts < since:
                        continue
                    msg = rec.get("message")
                    if not isinstance(msg, dict) or msg.get("role") != "assistant":
                        continue
                    usage = msg.get("usage")
                    if not isinstance(usage, dict):
                        continue
                    mid = msg.get("id") or rec.get("requestId") or rec.get("uuid")
                    if mid in seen:
                        continue
                    seen.add(mid)
                    model = msg.get("model") or ""
                    c, unknown = cost_of(usage, model)
                    if unknown and model and model != "<synthetic>":
                        unknown_models.add(model)
                    per_file[path] += c
                    per_model[model] += c
                    total += c

    rows = sorted(per_file.items(), key=lambda kv: -kv[1])
    for path, c in rows:
        if c < 0.005:
            continue
        rel = os.path.relpath(path, PROJECT_ROOT)
        print(f"${c:8.2f}  {rel[:90]}  | {first_prompt(path)}")
    print("-" * 60)
    for model, c in sorted(per_model.items(), key=lambda kv: -kv[1]):
        if c >= 0.005:
            print(f"${c:8.2f}  {model}")
    if unknown_models:
        print("unpriced models:", ", ".join(sorted(unknown_models)))
    print(f"TOTAL since {since}: ${total:.2f}  | estimated balance left: ${start - total:.2f} (start ${start:.2f})")


if __name__ == "__main__":
    main()
