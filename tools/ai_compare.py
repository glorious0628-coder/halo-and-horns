"""ai_compare.py - compare in-game screenshots with a zone's concept art using the Claude API.

Runs on the Console API key in .env (ANTHROPIC_API_KEY=...; an organization-level key also needs
ANTHROPIC_WORKSPACE_ID=wrkspc_...), so it bills the Console credits (the monthly Max-plan API
credits), not the Claude Code subscription. Never prints the key.

  py tools/ai_compare.py --concept art/out/s2/places/HaloTown_whole_src.png \
      --shot docs/art/verification_2026-10-09/halo/halo_zone_a.png --zone "Halo town"
  options: --shot can repeat; --model (default claude-opus-5-5); --effort low|medium|high;
           --out result.json (default: next to the first shot, <name>_aicompare.json)

Output: scores 0-10 per aspect, the biggest differences with a concrete fix each, rule flags
(ray-burst patterns, lettering on props, unsafe content) and a short Korean summary.
Numbers are hints; 검수 still judges by eye (memory: numbers-are-hints-judge-by-eye).
"""
import argparse
import base64
import io
import json
import os
import sys
from typing import List

import anthropic
from PIL import Image
from pydantic import BaseModel

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAX_SIDE = 1568  # long side sent to the model; bigger images are scaled down first
PRICE = {  # $ per 1M tokens (input, output), from the claude-api skill table 2026-10-06
    "claude-opus-5-5": (4.0, 20.0),
    "claude-sonnet-5-5": (2.0, 10.0),
    "claude-haiku-5-5": (0.10, 0.50),
}


class Aspect(BaseModel):
    name: str
    score: int  # 0-10, 10 = matches the concept
    note: str


class Difference(BaseModel):
    where: str
    concept_has: str
    game_has: str
    fix: str
    priority: int  # 1 = most important


class Verdict(BaseModel):
    overall: int  # 0-10
    aspects: List[Aspect]
    differences: List[Difference]
    ray_burst_seen: bool
    lettering_on_props_seen: bool
    unsafe_content_seen: bool
    flag_notes: str
    summary_ko: str


PROMPT = """You review a Roblox game zone against its approved concept art.
Image 1 is the CONCEPT ART for the zone "{zone}". The next image(s) are IN-GAME SCREENSHOTS of the same zone.
Judge how closely the game matches the concept: the game should look like the concept, not like a flat map with props.

Score each aspect 0-10 (10 = matches the concept): terrain shape and height (cliffs, tiers, slopes),
layout and paths, water (sea, rivers, waterfalls), edge density (dense borders, no empty flat ground),
landmarks and props (do the key buildings/objects exist and look like the concept style), colour and light.
Then list the biggest differences, most important first (at most 8), each with a concrete fix a level builder can do.

Also flag, as true/false with a short note:
- ray_burst_seen: any stripes or rays fanning out from a centre or half-circle (sunburst / rising-sun look) - banned in this game.
- lettering_on_props_seen: readable words or letters painted on props or buildings (the game wants no baked lettering).
- unsafe_content_seen: anything not kid-friendly (revealing clothing, gore).

Finish with summary_ko: 2-3 short, plain Korean sentences for a beginner: how close it is and the top thing to fix.
Be specific and honest; do not praise. Describe only what you can see."""


def env_value(name):
    """Environment first, then the git-ignored .env file. Values are never printed."""
    value = os.environ.get(name, "").strip()
    if value:
        return value
    try:
        with open(os.path.join(ROOT, ".env"), encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line.startswith(name) and "=" in line and line.split("=", 1)[0].strip() == name:
                    return line.split("=", 1)[1].strip().strip('"').strip("'")
    except OSError:
        pass
    return ""


def make_client():
    key = env_value("ANTHROPIC_API_KEY")
    if not key:
        sys.exit("ANTHROPIC_API_KEY not found in the environment or .env")
    # An organization-level key needs the workspace id header (Console > Settings > Workspaces > Default > ID).
    workspace = env_value("ANTHROPIC_WORKSPACE_ID")
    headers = {"anthropic-workspace-id": workspace} if workspace else None
    return anthropic.Anthropic(api_key=key, default_headers=headers)


def image_block(path):
    img = Image.open(path)
    img = img.convert("RGB")
    w, h = img.size
    scale = min(1.0, MAX_SIDE / max(w, h))
    if scale < 1.0:
        img = img.resize((round(w * scale), round(h * scale)), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=90)
    data = base64.standard_b64encode(buf.getvalue()).decode("utf-8")
    return {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": data}}, img.size


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--concept", required=True)
    ap.add_argument("--shot", required=True, action="append")
    ap.add_argument("--zone", required=True)
    ap.add_argument("--model", default="claude-opus-5-5")
    ap.add_argument("--effort", default="medium", choices=["low", "medium", "high", "xhigh", "max"])
    ap.add_argument("--out")
    args = ap.parse_args()

    content = []
    sizes = []
    for p in [args.concept] + args.shot:
        if not os.path.isfile(p):
            sys.exit("missing image: " + p)
        block, size = image_block(p)
        content.append(block)
        sizes.append((os.path.basename(p), size))
    content.append({"type": "text", "text": PROMPT.format(zone=args.zone)})

    client = make_client()
    try:
        response = client.messages.parse(
            model=args.model,
            max_tokens=16000,
            output_config={"effort": args.effort},
            messages=[{"role": "user", "content": content}],
            output_format=Verdict,
        )
    except anthropic.RateLimitError as e:
        sys.exit("rate limited (429): " + str(e))
    except anthropic.APIStatusError as e:
        sys.exit("API error %s: %s" % (e.status_code, e))
    except anthropic.APIConnectionError as e:
        sys.exit("connection error: " + str(e))

    if response.stop_reason == "refusal":
        sys.exit("model refused: %s" % (response.stop_details,))
    verdict = response.parsed_output
    if verdict is None:
        sys.exit("no structured output (stop_reason=%s)" % response.stop_reason)

    usage = response.usage
    pin, pout = PRICE.get(args.model, (0.0, 0.0))
    cost = usage.input_tokens / 1e6 * pin + usage.output_tokens / 1e6 * pout
    result = {
        "zone": args.zone,
        "model": args.model,
        "effort": args.effort,
        "images": [{"file": n, "sent_size": list(s)} for n, s in sizes],
        "usage": {"input_tokens": usage.input_tokens, "output_tokens": usage.output_tokens,
                  "est_cost_usd": round(cost, 4)},
        "verdict": verdict.model_dump(),
    }
    out = args.out or os.path.splitext(args.shot[0])[0] + "_aicompare.json"
    with open(out, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    v = verdict
    print("overall %d/10  (%s, est $%.4f)" % (v.overall, args.model, cost))
    for a in v.aspects:
        print("  %-28s %2d  %s" % (a.name[:28], a.score, a.note))
    for d in sorted(v.differences, key=lambda d: d.priority):
        print("  [%d] %s: concept %s | game %s -> %s" % (d.priority, d.where, d.concept_has, d.game_has, d.fix))
    print("  flags: ray_burst=%s lettering=%s unsafe=%s  %s" % (
        v.ray_burst_seen, v.lettering_on_props_seen, v.unsafe_content_seen, v.flag_notes))
    print("  KO:", v.summary_ko)
    print("saved", out)


if __name__ == "__main__":
    main()
