"""A23-211 (user 2026-10-16 "몬스터 애들이 죽는 모션이 아니라, 뭔가 편안해지는 느낌으로 사라지면 좋을듯?") - the screen part
(게임성 개발 1). Static checks on the current sources:
- no death motion of any kind is left on the client: no slime splat (Fx WOBBLE DeathHold / DeathShrink / Splat), no
  Fall clip (MonsterMotion Fall / FallRate / FallImpactAt, ReplicatedStorage.MonsterAnims *_Fall), no death sounds
  (Audio T.DieOf, Config.Audio DeathByKind / Die*);
- a beaten monster (anchored root, not Leaving) gets Fx WOBBLE.calm: the shard dust pops out (round default-texture
  sparkles, no rays), one soft hop / King Slime's bounces / Captain Clatter's bow + sit, a soft light fill (Highlight),
  then a fade (LocalTransparencyModifier, this client only) with a few round sparkles rising, gone at Gone x Time,
  before the server removes the body (MonsterService DEATH_DESTROY); a rigged one stays Idle (MonsterMotion);
- the kill itself still sounds (KillPop).
Mutations: in-memory copies with one rule broken each; each must be caught.

Usage: py tools/test_calm_fade.py
Report: docs/art/verification_2026-10-16/offline_calm_fade_2026-10-16.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {
    "FX": SPS / "Fx.luau",
    "MM": SPS / "MonsterMotion.luau",
    "AUDIO": SPS / "Audio.luau",
    "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
    "MONSTER": ROOT / "src/ServerScriptService/MonsterService.luau",
}
ANIMS = ROOT / "src/ReplicatedStorage/MonsterAnims"
OUT = ROOT / "docs/art/verification_2026-10-16/offline_calm_fade_2026-10-16.json"

ABSENT = [
    ("FX", "no slime splat / puddle", ["DeathHold", "DeathShrink", "st.Splat", "local splat"]),
    ("MM", "no Fall clip or fall rate", ['"Fall"', "FallRate", "FallImpactAt"]),
    ("AUDIO", "no death sound picker", ["DieOf", "DeathByKind"]),
    ("CONFIG", "no death sounds in Config.Audio", ["DeathByKind", "DieSlime", "DieBigSlime", "DieFlowerSlime"]),
]
PRESENT = [
    ("FX", "a beaten monster (anchored, not Leaving, not hidden) gets WOBBLE.calm", [
        'if sroot and sroot.Anchored and not foreign and model:GetAttribute("Leaving") ~= true then',
        "pcall(WOBBLE.calm, model, sroot, WOBBLE.State[model], camPos)"]),
    ("FX", "(1) the dust pops out: round sparkles drifting up (nothing falls)", [
        "burst(c.Mid, K.PopColor, K.Pop, {", "Acceleration = Vector3.new(0, 3, 0)"]),
    ("FX", "(2) one soft hop, a slime a little smaller, a soft light fill", [
        "up = math.sin(math.pi * u) * hopH\n\t\tk = 1 - (1 - K.Shrink) * u", 'hl.Name = "CalmSoft"',
        "hl.OutlineTransparency = 1"]),
    ("FX", "kings: King Slime bounces, Captain Clatter bows then sits", [
        'Kings = { SlimeKing = "Bounce", CaptainClatter = "Salute" }',
        "up = math.abs(math.sin(math.pi * K.Bounces * u)) * hopH * (1 - u)",
        "tilt = math.sin(math.pi * bow) * K.Bow", "up = -c.H * K.Sit *"]),
    ("FX", "(3) the fade is this client's only and ends fully gone", [
        "if p.Parent then p.LocalTransparencyModifier = fade end",
        "local fade = math.clamp((t - K.FadeAt * T) / math.max(0.05, (K.Gone - K.FadeAt) * T), 0, 1)",
        "c.Soft.FillTransparency = math.max(soft, fade)"]),
    ("FX", "the rising sparkles come once", ["if fade > 0 and not c.Rose then"]),
    ("MM", "a beaten rigged monster stays calm (Idle)", ['want = "Idle" -- beaten (A23-211']),
    ("AUDIO", "the kill still pops", ['\t\tadd(out, "KillPop", 0)\n']),
]


def calm_table(fx: str) -> dict[str, float]:
    m = re.search(r"\tCalm = \{(.*?)\n\tCalming = \{\} \}", fx, re.S)
    out = {}
    if m:
        for k, v in re.findall(r"(\w+) = ([\d.]+)[,\s]", m[1]):
            out.setdefault(k, float(v))
    return out


def run(files: dict[str, str], anims_fall: list[str]) -> tuple[int, int, list[str]]:
    lines, checks, failed = [], 0, 0

    def check(name, ok, detail=""):
        nonlocal checks, failed
        checks += 1
        failed += 0 if ok else 1
        lines.append(("CHECK_OK " if ok else "CHECK_FAIL ") + name + ("" if ok else f" :: {detail}"))

    for fk, name, words in ABSENT:
        hits = [w for w in words if w in files[fk]]
        check(f"{fk}: {name}", not hits, hits)
    check("MonsterAnims: no *_Fall clip files", not anims_fall, anims_fall)
    for fk, name, needles in PRESENT:
        miss = [n for n in needles if files[fk].count(n) != 1]
        check(f"{fk}: {name}", not miss, miss)
    K = calm_table(files["FX"])
    check("Calm: about a second, the hop first, then the fade", K.get("Time") == 1.0 and 0 < K.get("Hop", 0) < K.get("FadeAt", 0)
          < K.get("Gone", 0) < 1, K)
    m = re.search(r"local DEATH_DESTROY = ([\d.]+)", files["MONSTER"])
    destroy = float(m[1]) if m else 0
    check("gone before the server removes the body (Gone x Time < DEATH_DESTROY)", K.get("Gone", 9) * K.get("Time", 9) < destroy,
          (K.get("Gone"), K.get("Time"), destroy))
    calm = re.search(r"\nfunction WOBBLE\.calm\(.*?\nend\n", files["FX"], re.S)
    body = calm[0] if calm else ""
    check("calm draws no rays (default round particles, no beams / textures)", body != "" and "Texture" not in body
          and "Beam" not in body, "")
    return checks, failed, lines


MUTATIONS = [
    ("FX", "the splat comes back", "Calming = {} }", "Calming = {}, DeathHold = 0.75 }"),
    ("MM", "the fall comes back", 'want = "Idle" -- beaten (A23-211', 'want = "Fall" -- beaten (A23-211'),
    ("AUDIO", "a death sound by kind", '\t\tadd(out, "KillPop", 0)\n', '\t\tadd(out, T.DieOf(data.Kind), 0)\n'),
    ("FX", "the fade waits forever", "(K.Gone - K.FadeAt) * T), 0, 1)", "(K.Gone - K.FadeAt) * T * 9), 0, 1)"),
    ("FX", "fade on the server's parts (Transparency)", "p.LocalTransparencyModifier = fade", "p.Transparency = fade"),
    ("FX", "no calm for beaten monsters", "pcall(WOBBLE.calm, model, sroot, WOBBLE.State[model], camPos)", "true"),
    ("FX", "the dust falls like a burst", "Acceleration = Vector3.new(0, 3, 0)", "Acceleration = Vector3.new(0, -25, 0)"),
    ("FX", "Clatter does not sit", "up = -c.H * K.Sit *", "up = 0 * K.Sit *"),
    ("FX", "too slow for the server", "Gone = 0.92,", "Gone = 1.4,"),
    ("FX", "a ray texture", "\t\tc.Soft = hl\n", "\t\tc.Soft = hl\n\t\thl:SetAttribute(\"Texture\", \"rays\")\n"),
    ("CONFIG", "a Die sound back", "\t\tKillPop = { File = \"KillPop\",", "\t\tDieSlime = {},\n\t\tKillPop = { File = \"KillPop\","),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    files = {k: p.read_text(encoding="utf-8").replace("\r\n", "\n") for k, p in FILES.items()}
    falls = sorted(p.name for p in ANIMS.glob("*_Fall.luau"))
    checks, failed, lines = run(files, falls)
    print("\n".join(lines))
    muts = []
    for fk, name, old, new in MUTATIONS:
        hits = files[fk].count(old)
        caught = False
        if hits == 1:
            copy = dict(files)
            copy[fk] = files[fk].replace(old, new)
            caught = run(copy, falls)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    status = "passed" if failed == 0 and all(m["caught"] for m in muts) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
