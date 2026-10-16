"""My level-up and a skill lesson as moments (최종 검수 10/15, Codex build/codex/feedback_audit.md #2; server Fx LevelUp From / PowerFrom /
PowerTo), offline static check.

Fx: my own level-up = a gold ring of light at my feet, then stars round my body (others keep the old pillar), and the
HUD's moment at the same time (HUD.LevelUpMoment with the server's numbers). HUD: the level badge pops (bigger, then back
with a little overshoot; not with reduced motion) and the power number counts up with its "+N" from PowerFrom to
PowerTo, the settle after it stays quiet (Base / LevelAt). No banner, no words (A23-191). Each mutation must fail a check.

Usage: py tools/test_levelup_moment.py
"""
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"FX": SPS / "Fx.luau", "HUD": SPS / "HUD.luau", "BAR": SPS / "SkillBar.luau"}


def block(src: str, start: str) -> str:
    a = src.find(start)
    if a < 0:
        return ""
    m = re.search(r"^end\n", src[a:], re.M)
    return src[a:a + m.end()] if m else ""


def statics(s: dict) -> list[tuple[str, bool]]:
    handler = block(s["FX"], "handlers.LevelUp = function(data)")
    queue = block(s["FX"], "function Feel.levelQueue(data, level)")
    fx = block(s["FX"], "function Feel.levelMoment(q)")
    hud = block(s["HUD"], "function HUD.LevelUpMoment(d)")
    count = block(s["HUD"], "function HUD.LevelCount(from, to)")
    return [
        ("mine: a gold ring at my feet, then stars round me", "-- 최종 검수 10/15" in fx
         and "ring(pos, 6, COLOR_GOLD," in fx and "task.delay(0.15, function()" in fx and "burst(pos + Vector3.new(0, 2, 0), COLOR_GOLD, 30," in fx),
        ("others keep the pillar", "if own or not (pos and nearCamera(pos)) then return end\n\tpillar(pos, 40, 4, COLOR_PILLAR, 1.0)" in handler),
        ("the HUD moment with the server's numbers", "pcall(hud.LevelUpMoment, { Level = q.To, From = q.From, PowerFrom = q.PowerFrom, PowerTo = q.PowerTo })" in fx),
        ("A23-221 ③: my level-ups in a fight wait (Calm after the last hit) and play once, the badge ticks From -> To",
         "Feel.levelQueue(data, level)" in handler and "q.To = math.max(q.To, level)" in queue and "\t\treturn q\n\tend\n\tq = { From" in queue
         and "now - asNum(Fx.LastFightAt, -math.huge) >= W.Calm" in queue and "pcall(hud.LevelHold, q.From)" in queue
         and "pcall(hud.LevelCount, q.From, q.To)" in fx and "for v = from + 1, to do" in count and "L.Lv.Seq ~= seq" in count),
        ("no banner / words", "Announce" not in fx and "Toast" not in fx and "Announce" not in hud and "Toast" not in hud),
        ("the badge pops and comes back (Back), not with reduced motion",
         "if holder and not reduced then" in hud and "{ Scale = L.LevelPop.Up }" in hud and "Enum.EasingStyle.Back" in hud),
        ("the power counts up with its +N, the settle after it stays quiet",
         "L.Pow.Base, L.Pow.LevelAt = to, os.clock()" in hud and "L.PowerPopup(L.Pow.Shown or from, to, to - from)" in hud),
        ("only a real rise shows", "if from and to and to > from then" in hud),
        # feedback_audit #3: the teacher's light -> my weapon -> the slot opens
        ("the lesson sends a light from the teacher to my weapon", "pcall(LEARN.Orb, body) -- feedback_audit #3" in s["BAR"]
         and 'local to = (wm and wm:FindFirstChild("Handle")) or' in s["BAR"]),
        ("the light flies on an arc and ends in sparkles", "return a:Lerp(b, k) + Vector3.new(0, 4 * (arc or 0) * k * (1 - k), 0)" in s["BAR"]
         and "pcall(sfx.Ring, at)" in s["BAR"]),
        ("the slot waits for the light, then pops with a gold rim", "local wait = math.max(0, LEARN.ArriveAt - os.clock())" in s["BAR"]
         and "if b.Holder.Parent then LEARN.Flash(b.Holder) end" in s["BAR"] and "task.delay(LEARN.Listen, function()" in s["BAR"]),
    ]


MUTATIONS = [
    ("FX", "the pillar for me too", "if own or not (pos and nearCamera(pos)) then return end", "if not (pos and nearCamera(pos)) then return end"),
    ("FX", "level-ups never wait for the fight", "now - asNum(Fx.LastFightAt, -math.huge) >= W.Calm or", "true or"),
    ("FX", "every level-up its own moment", "\t\tq.To = math.max(q.To, level)\n\t\tq.PowerTo = asNum(data.PowerTo, q.PowerTo)\n\t\treturn q\n",
     "\t\tq.To = math.max(q.To, level)\n\t\tq.PowerTo = asNum(data.PowerTo, q.PowerTo)\n"),
    ("FX", "no stars", "\t\t\tburst(pos + Vector3.new(0, 2, 0), COLOR_GOLD, 30,", "\t\t\tlocal _ = (pos + Vector3.new(0, 2, 0), COLOR_GOLD, 30,"),
    ("FX", "the HUD never told", "pcall(hud.LevelUpMoment,", "pcall(print,"),
    ("HUD", "the badge pops under reduced motion", "if holder and not reduced then", "if holder then"),
    ("HUD", "a second +N after", "L.Pow.Base, L.Pow.LevelAt = to, os.clock()", "L.Pow.LevelAt = os.clock()"),
    ("HUD", "a drop shows too", "if from and to and to > from then", "if from and to then"),
    ("BAR", "no light", "	pcall(LEARN.Orb, body) -- feedback_audit #3", "	-- (no light) feedback_audit #3"),
    ("BAR", "a straight light", "4 * (arc or 0) * k * (1 - k)", "0 * k"),
    ("BAR", "the slot pops before the light arrives", "local wait = math.max(0, LEARN.ArriveAt - os.clock())", "local wait = 0"),
    ("BAR", "no gold rim", "if b.Holder.Parent then LEARN.Flash(b.Holder) end", ""),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    src = {k: p.read_text(encoding="utf-8") for k, p in FILES.items()}
    st = statics(src)
    for name, g in st:
        print(("STATIC_OK " if g else "STATIC_FAIL ") + name)
    good = all(g for _, g in st)
    caught = 0
    for key, name, old, new in MUTATIONS:
        if src[key].count(old) != 1:
            print(f"MUTATION NOT_APPLIED {name} (matched {src[key].count(old)})")
            continue
        m = dict(src)
        m[key] = src[key].replace(old, new)
        bad = not all(g for _, g in statics(m))
        caught += 1 if bad else 0
        print(("MUTATION caught  " if bad else "MUTATION MISSED ") + name)
    passed = good and caught == len(MUTATIONS)
    print(f"Status: {'passed' if passed else 'failed'} (statics {sum(g for _, g in st)}/{len(st)}, mutations {caught}/{len(MUTATIONS)})")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
