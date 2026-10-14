"""VillageFundUI offline check (A23-178 B, user 10/14 "마을 기금은 좋아"; contract docs/design/village_fund_server_2026-10-14.md §8).

Runs the CURRENT src/StarterPlayer/StarterPlayerScripts/VillageFundUI.luau with the CURRENT Config.luau and Util.luau in
tools/fixtures/village_fund_ui_offline.luau with the official Luau CLI (build/luau_cli_0_741): workspace, the fountain
prompts, ReplicatedStorage attributes, GameState, Panels, the window kit, UIKit.ArtBar, Net and the player are small
doubles (Config.VillageFund from the contract §2 when the server branch is not merged yet). Covers: the pure lines
(Share / Show off, Today n/3, my gold, Give 1,000, the server's Poor / Full words, no gift without a side), the weekly
bar (fill toward the fireworks goal, the lantern mark, live FundHalo), the prompts (only my own side's stays on; side
switch, Neutral, prompts made later), the card (opens on FundOpen, FundGive with no arguments, locked until the answer
or Wait, redrawn in place, grey + reason line, [Close], closes when I walk away or switch sides), the town glow
(lanterns from level 1, fireworks bursts only at level 2 at night and not every poll, fewer on phones, gone at level 0,
the other side's town too).
Static: ClientMain loads it after Panels; Net has FundGive / FundOpen once; FundGive fires with no arguments; English
words; no shop near the card (A23-79); particle textures from the known list only, no Beam / Trail (no rays, user 10/07).
Mutations: in-memory copies with one rule broken each; each must make a check fail.
Report: docs/art/verification_2026-10-14/offline_village_fund_ui_2026-10-14.json (do not commit)
"""
from pathlib import Path
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
MODULE = SCRIPTS / "VillageFundUI.luau"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
UTIL = ROOT / "src/ReplicatedStorage/Shared/Util.luau"
NET = ROOT / "src/ReplicatedStorage/Shared/Net.luau"
CLIENT_MAIN = SCRIPTS / "ClientMain.client.luau"
FIXTURE = ROOT / "tools/fixtures/village_fund_ui_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-14/offline_village_fund_ui_2026-10-14.json"
TEXTURES = {"rbxasset://textures/particles/sparkles_main.dds", "rbxassetid://244221535"}

MUTATIONS = [
    ("every fund prompt on", "return side(mySide) ~= nil and side(promptSide) == side(mySide)", "return true"),
    ("3 a day ignored", "\tif n(state.Today, 0) >= per then return \"Full\" end\n", ""),
    ("too little gold ignored", "\tif n(state.Gold, 0) < step then return \"Poor\" end\n", ""),
    ("a Neutral card can give", "CanGive = my ~= nil and why == nil,", "CanGive = why == nil,"),
    ("gift spam", "\tif os.clock() - S.SentAt < L.Wait then return end\n\tS.SentAt = os.clock()\n", "\tS.SentAt = os.clock()\n"),
    ("the gift sends an amount", 'Net.Get("FundGive"):FireServer()', 'Net.Get("FundGive"):FireServer(state.Step)'),
    ("the answer reopens the window", "\tif VIEW.Shown then\n\t\tpaint()\n\t\treturn true\n\tend\n", ""),
    ("the reason line hidden", "\t\tVIEW.Reason.Visible = lines.Reason ~= nil\n", "\t\tVIEW.Reason.Visible = false\n"),
    ("the bar ignores the live total", 'local v = my and n(fundAttr("Fund" .. my), nil)', "local v = nil"),
    ("the bar never follows the attribute",
     "ReplicatedStorage:GetAttributeChangedSignal(key):Connect(function() pcall(paintBar) end)", "local _ = key"),
    ("the card stays when I walk away", "\t\t\tif d > n(sp.Radius, 16) + L.Away then closeCard() end\n", ""),
    ("no unlock without an answer", "\t\t\tS.SentAt = -math.huge\n\t\t\tpaint()\n", ""),
    ("fireworks by day", 'Fireworks = level >= 2 and phase == "Night"', "Fireworks = level >= 2"),
    ("phones get every lantern", "Lights = phone and L.Lantern.PhoneCount or L.Lantern.Count", "Lights = L.Lantern.Count"),
    ("lanterns never go", "\t\t\tif t then clearTown(sd) end\n", ""),
    ("fireworks every poll", "if t and plan.Fireworks and now >= t.NextBurst then", "if t and plan.Fireworks then"),
    ("solid lanterns", "p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false",
     "p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, true, true, true, false"),
    ("prompts made later stay on", "\tworkspace.DescendantAdded:Connect(function(d) pcall(consider, d) end)\n", ""),
    ("a side switch keeps the old card", "\t\t\tif S.State and side(S.State.Faction) ~= mySide() then closeCard() end\n", ""),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(src: str, config: str, util: str, name: str):
    path = ROOT / f"build/village_fund_ui_offline{name}.luau"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("local CONFIG_SOURCE = " + lua_str(config) + "\nlocal UTIL_SOURCE = " + lua_str(util)
                    + "\nlocal UI_SOURCE = " + lua_str(src) + "\n" + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"VILLAGE_FUND_UI_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    src = MODULE.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    config = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    util = UTIL.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(src, config, util, "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    rows = []
    for name, old, new in MUTATIONS:
        applied = src.count(old) == 1
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run(src.replace(old, new), config, util, "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    cm = CLIENT_MAIN.read_text(encoding="utf-8-sig")
    order = re.search(r"local ORDER = \{([^}]*)\}", cm)
    names = re.findall(r'"([A-Za-z]+)"', order[1]) if order else []
    code = "\n".join(line.split("--", 1)[0] for line in src.splitlines())
    net = NET.read_text(encoding="utf-8-sig")
    screen = re.search(r"\nConfig\.VillageFundScreen = \{(.*?)\n\}\n", config, re.S)
    words = "\n".join(ln.split("--", 1)[0] for ln in screen[1].splitlines()) if screen else ""
    textures = set(re.findall(r'"(rbxasset[^"]+)"', code))
    static = [
        ("ClientMain loads VillageFundUI after Panels", "VillageFundUI" in names and "Panels" in names
         and names.index("VillageFundUI") > names.index("Panels")),
        ("Net has FundGive and FundOpen once each", net.count('"FundGive"') == 1 and net.count('"FundOpen"') == 1),
        ("FundGive fires with no arguments", re.findall(r'Net\.Get\("FundGive"\):FireServer\(([^)]*)\)', code) == [""]),
        ("the card's words are English (A23-48)", words != "" and not re.search(r"[가-힣]", words)),
        ("nothing is sold near the card (A23-79)", "MarketplaceService" not in code and "Prompt" + "Purchase" not in code),
        ("particle textures from the known list only", textures != set() and textures <= TEXTURES, sorted(textures)),
        ("no beams / trails (no rays, user 10/07)", '"Beam"' not in code and '"Trail"' not in code),
        ("no Config.VillageFund table written by the client branch", "\nConfig.VillageFund = " not in config
         or "VillageFundService" in config),
    ]
    static_rows = []
    for item in static:
        name, good = item[0], bool(item[1])
        static_rows.append({"check": name, "ok": good})
        print(("STATIC_OK " if good else "STATIC_FAIL ") + name + ("" if good or len(item) < 3 else f" :: {item[2]}"))
    status = "passed" if ok and all(r["caught"] for r in rows) and all(r["ok"] for r in static_rows) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failures": fails, "mutations": rows, "static": static_rows,
                               "status": status, "studioCalls": 0}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    caught = sum(r["caught"] for r in rows)
    print(f"Status: {status} (checks {checks}, mutations {caught}/{len(rows)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
