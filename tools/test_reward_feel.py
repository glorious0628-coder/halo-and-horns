"""A23-221 ③ / ⑦ reward feel (게임성 개발 1, 2026-10-16), offline static check.

Fx: the reward's XP number carries the server's multiplier ('+12 XP ×2' when Fx Reward XPMult >= 2, its own merge key),
the first XP makes HUD.PulseBoost shine the '2x XP · N min' chip once (only in the first minutes, never twice, no pop
with reduced motion); a notable drop (a weapon, an Enhance / Transfer scroll, Gear) rises over my head for a moment in a
round glow (Feel.holdUp: a BillboardGui on my head, round sparkles, the free 'cheer' emote only out of a fight, nothing
blocked, gone after Time s); the first weapon (HUD L.FirstWeapon) does the same. No banner, no words (A23-191), no rays.
Each mutation must fail a check.

Usage: py tools/test_reward_feel.py
"""
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"FX": SPS / "Fx.luau", "HUD": SPS / "HUD.luau"}


def block(src: str, start: str) -> str:
    a = src.find(start)
    if a < 0:
        return ""
    m = re.search(r"^end\n", src[a:], re.M)
    return src[a:a + m.end()] if m else ""


def statics(s: dict) -> list[tuple[str, bool]]:
    reward = block(s["FX"], "function Feel.rewardNow(data)")
    loot = block(s["FX"], "function Feel.lootNow(data)")
    icon = block(s["FX"], "function Feel.holdIcon(it)")
    hold = block(s["FX"], "function Feel.holdUp(icon)")
    pulse = block(s["HUD"], "function HUD.PulseBoost()")
    first = block(s["HUD"], "function L.FirstWeapon()")
    return [
        ("the XP number says the server's multiplier",
         'local mult = math.floor(asNum(data.XPMult, 1) + 0.5)' in reward
         and 'Suffix = mult >= 2 and (" XP ×" .. mult) or " XP"' in reward and 'Key = mult >= 2 and "RX" .. mult or "RX"' in reward),
        ("the first XP asks the HUD to shine the 2x chip (before the near-camera check)",
         "if xp > 0 and type(hud) == \"table\" and type(hud.PulseBoost) == \"function\" then pcall(hud.PulseBoost) end" in reward
         and reward.find("pcall(hud.PulseBoost)") < reward.find("if not pos or not nearCamera(pos) then return end")),
        ("the chip shines once, only in the first minutes, quietly with reduced motion",
         "if L.BoostPulsed or L.EarlyXPLeft() == nil then return false end" in pulse and "L.BoostPulsed = true" in pulse
         and "if UIKit.ReducedMotion() then return true end" in pulse and "chip.Frame.Visible" in pulse),
        ("a notable drop is held up (weapons, scrolls, gear; not jelly / potions)",
         "local icon = Feel.holdIcon(it)" in loot and "pcall(Feel.holdUp, icon)" in loot and "if it.Weapon ~= nil then" in icon
         and "MOTION.HOLD.Kinds[def.Kind]" in icon and "Kinds = { Enhance = true, Transfer = true, Gear = true }" in s["FX"]),
        ("held up over my head in a round glow, gone after Time s",
         'gui.Adornee = head' in hold and 'corner.CornerRadius = UDim.new(0.5, 0)' in hold
         and "task.delay(H.Time, function()" in hold and "Debris:AddItem(gui, H.Out + 0.1)" in hold),
        ("the cheer only out of a fight, nothing blocked",
         "if now - asNum(Fx.LastFightAt, -math.huge) >= H.Calm then" in hold and "play:Invoke(H.Emote)" in hold
         and "WalkSpeed" not in hold and "Anchored" not in hold),
        ("no pop with reduced motion / shake off", "local still = not MOTION.ShakeAllowed()" in hold and "if not still then" in hold),
        ("the first weapon is held up too", "C.Fx.HoldUp(key)" in first and "Config.WeaponArtKey(" in first),
        ("no banner / words / rays", all("Announce" not in b and "Toast" not in b and "Beam" not in b for b in (hold, pulse, icon))),
    ]


MUTATIONS = [
    ("FX", "no x2 on the number", 'Suffix = mult >= 2 and (" XP ×" .. mult) or " XP"', 'Suffix = " XP"'),
    ("FX", "the chip never told", "pcall(hud.PulseBoost)", "pcall(print)"),
    ("HUD", "the chip shines every time", "\tL.BoostPulsed = true\n", "\n"),
    ("FX", "jelly held up too", "if type(def) == \"table\" and MOTION.HOLD.Kinds[def.Kind] then return it.Item end",
     "if type(def) == \"table\" then return it.Item end"),
    ("FX", "cheer mid-fight", "if now - asNum(Fx.LastFightAt, -math.huge) >= H.Calm then", "if true then"),
    ("FX", "never goes away", "task.delay(H.Time, function()", "task.delay(H.Time * 0, function() do return end"),
    ("HUD", "the first weapon not held up", "C.Fx.HoldUp(key)", "print(key)"),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    src = {k: p.read_text(encoding="utf-8") for k, p in FILES.items()}
    st = statics(src)
    good = all(g for _, g in st)
    for name, g in st:
        print(("STATIC_OK " if g else "STATIC_FAIL ") + name)
    caught = 0
    for key, name, old, new in MUTATIONS:
        if src[key].count(old) != 1:
            print(f"MUTATION NOT_APPLIED {name} (matched {src[key].count(old)})")
            continue
        m = dict(src)
        m[key] = src[key].replace(old, new)
        if all(g for _, g in statics(m)):
            print(f"MUTATION_SURVIVED {name}")
        else:
            caught += 1
            print(f"MUTATION caught  {name}")
    ok = good and caught == len(MUTATIONS)
    print(f"Status: {'passed' if ok else 'failed'} (statics {sum(1 for _, g in st if g)}/{len(st)}, mutations {caught}/{len(MUTATIONS)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
