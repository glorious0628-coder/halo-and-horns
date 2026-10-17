"""Quick slots 1 / 2 / 3 (게임성 개발 1, SPEC A23-109, user 2026-10-10), offline.

Runs, in the official Luau CLI, the CURRENT Config.luau and QuickSlots.luau in tools/fixtures/quick_slots_offline.luau.
Checks: the saved attribute "QuickSlots" (default 1 HP, 2 MP, 3 empty; unknown entries empty), what a slot shows (count,
cooldown left of Config.Vitals.PotionCooldown, ready), using a slot (VitalsUI.Request; an empty slot nothing), the HUD's
press hook (HUD.OnQuickSlot), keys 1 / 2 / 3 (Keybinds PotionHP / PotionMP / QuickSlot3), the slot parts filled (icon,
count, cooldown from the bottom, key badge; empty = blank), putting an item in a slot (swap; SetQuickSlot when the server
has it, else this session) and the bag's quick items rows. Static: VitalsUI leaves its potion keys to the quick slots,
VitalsUI.Request exists, ClientMain loads QuickSlots after HUD and VitalsUI, Config has QuickSlot3 on key Three.
Mutations: each must be caught.

Usage: py tools/test_quick_slots.py
Report: docs/art/verification_2026-10-10/offline_quick_slots_2026-10-10.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"QS": SPS / "QuickSlots.luau", "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
         "VITALS": SPS / "VitalsUI.luau", "MAIN": SPS / "ClientMain.client.luau", "PANELS": SPS / "Panels.luau", "HUD": SPS / "HUD.luau"}
FIXTURE = ROOT / "tools/fixtures/quick_slots_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-10/offline_quick_slots_2026-10-10.json"

MUTATIONS = [
    ("QS", "10/18 King warn: every poll of the fight", "if king == nil or king == warned then return false end", "if king == nil then return false end"),
    ("QS", "10/18 King warn: at any HP", "return hp < maxHp * T.KingWarn.Share", "return true"),
    ("QS", "game play r8: the 0-potion icon dims again", "if w.Icon.ImageTransparency ~= 0 then w.Icon.ImageTransparency = 0 end",
     "w.Icon.ImageTransparency = (def and s.Count <= 0) and 0.55 or 0"),
    ("QS", "game play r8: the 0 count not gray", "local want = (def and s.Count <= 0) and T.ZeroCount or (own or nil)",
     "local want = own or nil"),
    ("CONFIG", "a new player starts with potions in the slots", '	Default = { "", "", "" },', '	Default = { "HP", "MP", "" },'),
    ("QS", "unknown items kept", "out[i] = (type(v) == \"string\" and T.Items[v] ~= nil) and v or \"\"", "out[i] = v or \"\""),
    ("QS", "an empty slot still uses (an HP potion)", "\tlocal def = slot.Def\n\tif type(def) ~= \"table\" then\n",
     "\tlocal def = slot.Def or T.Items.HP\n\tif type(def) ~= \"table\" then\n"),
    ("QS", "an empty slot's press opens nothing", 'pcall(panels.Open, "Bag", { Tab = "Use", Select = "P:" .. tostring(order[1] or "HP") })', "local _ = 0"),
    ("QS", "the HUD presses never hooked", "\tlocal ok = pcall(h.OnQuickSlot, function(i) QuickSlots.Use(i, true) end)\n",
     "\tlocal ok = true\n"),
    ("QS", "keys go to the wrong slot", 'Actions = { "PotionHP", "PotionMP", "QuickSlot3" },', 'Actions = { "PotionMP", "PotionHP", "QuickSlot3" },'),
    ("QS", "a game-taken key still uses", "if processed or UserInputService:GetFocusedTextBox() or type(keys) ~= \"table\" then return end",
     "if UserInputService:GetFocusedTextBox() or type(keys) ~= \"table\" then return end"),
    ("QS", "no swap", "\tif from and from ~= i then cur[from] = cur[i] end\n", ""),
    ("QS", "the server never told", "\t\tpcall(remote.FireServer, remote, i, item)\n", ""),
    ("QS", "the server's answer ignored", "\t\t\tS.Local = nil\n\t\t\tQuickSlots.Refresh()\n", "\t\t\tQuickSlots.Refresh()\n"),
    ("QS", "cooldown never shown", "\t\t\t\t\tw.Cooldown.Visible = frac > 0\n", "\t\t\t\t\tw.Cooldown.Visible = false\n"),
    ("QS", "an empty slot keeps the old icon", 'local id = def and artId(def.Icon) or ""', 'local id = def and artId(def.Icon) or w.Icon.Image'),
    ("QS", "the lit slot cannot be emptied", "QuickSlots.Set(i, on and \"\" or item)", "QuickSlots.Set(i, item)"),
    ("VITALS", "keys used twice (VitalsUI too)", "and quick.OwnsKeys() then return end", "and false then return end"),
    ("MAIN", "never loaded", '"SkillBar", "QuickSlots", "BuffBar"', '"SkillBar", "BuffBar"'),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def statics(src: dict) -> list[dict]:
    order = re.search(r"local ORDER = \{([^}]*)\}", src["MAIN"])
    names = re.findall(r'"(\w+)"', order.group(1)) if order else []
    out = [
        {"check": "ClientMain loads QuickSlots after HUD and VitalsUI", "ok": "QuickSlots" in names and "HUD" in names
         and "VitalsUI" in names and names.index("QuickSlots") > max(names.index("HUD"), names.index("VitalsUI"))},
        {"check": "VitalsUI leaves its potion keys to the quick slots", "ok":
         "if type(quick) == \"table\" and type(quick.OwnsKeys) == \"function\" and quick.OwnsKeys() then return end" in src["VITALS"]},
        {"check": "VitalsUI.Request(kind) = the potion button's request", "ok": "function VitalsUI.Request(kind)" in src["VITALS"]
         and "\treturn requestPotion(kind)\n" in src["VITALS"]},
        {"check": "the bag (Items, no scroll chosen) shows the quick items rows", "ok":
         "if not mode and C and type(C.QuickSlots) == \"table\" and type(C.QuickSlots.BagRows) == \"function\" then" in src["PANELS"]
         and "pcall(C.QuickSlots.BagRows, parent, REG.Kit())" in src["PANELS"]},
        {"check": "A23-110 KO1 rows: Guide QuickSlot opens the bag (H-1: Bag on its Use tab), PotionShop shows the way to the seller", "ok":
         'if g == "PotionShop" or g == "QuickSlot" or g == "Bag" then' in src["HUD"]  # (+ M1_1's scroll step, A23-127)
         and 'panels.Open(bag and "Bag" or "Items", bag and { Tab = "Use" } or nil)' in src["HUD"]
         and "pcall(vitals.ShowShopWay)" in src["HUD"] and "function VitalsUI.ShowShopWay()" in src["VITALS"]},
        {"check": "A23-110 KO1: while PotionSip is set a full bar may still drink (the server's practice sip)", "ok":
         'if player:GetAttribute(sip) == true then return count, "Use", true end' in src["VITALS"]
         and "PotionSip = true," in src["VITALS"]},
        {"check": "Config: QuickSlot3 on key Three (Potion group)", "ok":
         '{ Id = "QuickSlot3", Group = "Potion", Key = "Three"' in src["CONFIG"]},
    ]
    return out


def run(src: dict) -> tuple[int, int, str, list]:
    text = ("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal QS_SOURCE = " + lua_str(src["QS"]) + "\n"
            + FIXTURE.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "quick_slots.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"QUICK_SLOTS_SUMMARY checks=(\d+) failed=(\d+)", out)
    st = statics(src)
    failed = (int(m[2]) if m else 1) + sum(0 if s["ok"] else 1 for s in st)
    return (int(m[1]) if m else 0), failed, out, st


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    checks, failed, out, st = run(src)
    print(out.strip())
    for s in st:
        print(("STATIC_OK  " if s["ok"] else "STATIC_FAIL ") + s["check"])
    muts = []
    for key, name, old, new in MUTATIONS:
        hits = src[key].count(old)
        caught = False
        if hits == 1:
            m = dict(src)
            m[key] = src[key].replace(old, new)
            caught = run(m)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    ok = failed == 0 and checks > 0 and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "static": st, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
