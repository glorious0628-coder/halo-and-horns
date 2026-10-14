"""C-6 거래소 창 (게임성 개발 4, 2026-10-12; SPEC A23-127 / A23-133 / A23-130 / A23-111, contract
docs/design/market_window_2026-10-12.md §1 the window, §2 the remotes, §6 the agreed answers), offline, client only.

Runs the CURRENT Config.luau and MarketWindow.luau in the official Luau CLI (tools/fixtures/market_window_offline.luau;
a Remotes folder whose remotes appear when the test says so, the s->c remotes MarketIndex / MarketPage / MarketMine fired by
the test, a recording Instance tree with TextBox events, Panels, UIKit and the kit are doubles; the switch is turned on
inside the fixture). Checks: off = no menu entry, Open does nothing, nothing drawn; no remotes = Resting and nothing sent
(also while one of the six is missing); Buy (kinds, search by name, index rows, page rows with time left, pages, [Buy] once +
Checking…, Gate.Buy's key text, an owned weapon tier off, my class's weapon names); Sell (only sellable kinds + spares,
MarketBrowse on pick, hint rows, count - / + / All, price box numbers only and clamped Min..Max, You get = price - 10%,
MarketList for "I" and "W", Gate.List / Wait); Mine (states, Cancel, Paid, Waiting, Today, the dot); the request
intervals (Config.RateLimits wins, margin, Index 30 s, 3 s re-request); the open arg Tab once (a rebuild keeps my tab).
Static: ClientMain order, no Enum.KeyCode, no gate computed by the client, remotes by name only, no hard-coded English
outside TXT (dev log lines through Util.Warn excepted). Mutations: each must be caught.

Usage: py tools/test_market_window.py
Report: docs/art/verification_2026-10-12/offline_market_window_2026-10-12.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = {"WIN": ROOT / "src/StarterPlayer/StarterPlayerScripts/MarketWindow.luau",
         "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
         "PANELS": ROOT / "src/StarterPlayer/StarterPlayerScripts/Panels.luau",
         "MAIN": ROOT / "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau"}
FIXTURE = ROOT / "tools/fixtures/market_window_offline.luau"
OUT = ROOT / "docs/art/verification_2026-10-12/offline_market_window_2026-10-12.json"


def find_binary() -> Path:
    for base in (ROOT, *ROOT.parents):
        for rel in ("build/luau_cli_0_741/luau.exe", "Game/build/luau_cli_0_741/luau.exe"):
            p = base / rel
            if p.exists():
                return p
    return ROOT / "build/luau_cli_0_741/luau.exe"


BINARY = find_binary()

SENDS = ["MarketBrowse", "MarketBuy", "MarketCancel", "MarketIndex", "MarketList", "MarketMine"]

MUTATIONS = [
    ("WIN", "a sold row shows the price before the cut", 'if r.State == "Sold" then shown = select(2, MarketWindow.Fee(r.Price)) end', ""),
    ("WIN", "tier-1 spares on the sell list", "if t and tonumber(t) <= 1 then t = nil end", ""),
    ("WIN", "hours look like minutes again", 'return tx(TXT, "Hours", sec // 3600, (sec % 3600) // 60)', 'return string.format("%d:%02d", sec // 3600, (sec % 3600) // 60)'),
    ("WIN", "the menu entry shows while the switch is off", "Menu = function() return MarketWindow.On() and tx(TXT, \"Menu\") or nil end",
     "Menu = function() return tx(TXT, \"Menu\") end"),
    ("WIN", "Open works while the switch is off", "function MarketWindow.Open(tab)\n\tif not MarketWindow.On() then return end\n",
     "function MarketWindow.Open(tab)\n"),
    ("WIN", "a window built while off draws", "\tif not MarketWindow.On() then return nil end -- off: nothing at all\n", ""),
    ("WIN", "a missing remote is sent to anyway", "not hasRemote(name) or now < (S.ReadyAt[name] or 0)", "now < (S.ReadyAt[name] or 0)"),
    ("WIN", "resting needs only some of the remotes", "\tfor _, name in L.Sends do\n\t\tif not hasRemote(name) then return true end",
     "\tfor _, name in { \"MarketMine\" } do\n\t\tif not hasRemote(name) then return true end"),
    ("WIN", "the interval is ignored", "not hasRemote(name) or now < (S.ReadyAt[name] or 0)", "not hasRemote(name)"),
    ("WIN", "no margin over the interval", "num(limits[name], L.Gaps[name] or 1)) + L.GapMargin", "num(limits[name], L.Gaps[name] or 1))"),
    ("WIN", "Config.RateLimits is ignored", "num(limits[name], L.Gaps[name] or 1)", "L.Gaps[name] or 1"),
    ("WIN", "Buy / List / Cancel wait 1 s only", "MarketBuy = 6, MarketList = 6, MarketCancel = 6", "MarketBuy = 1, MarketList = 1, MarketCancel = 1"),
    ("WIN", "Index every time", "S.WantIndex, S.IndexNext = false, now + L.IndexEvery", "S.WantIndex, S.IndexNext = false, now"),
    ("WIN", "update never pumps the requests", "\t\tMarketWindow.Pump()\n\t\tif VIEW.Resting ~= resting() then", "\t\tif VIEW.Resting ~= resting() then"),
    ("WIN", "update never redraws what changed", "\t\telseif sigOf(context()) ~= VIEW.Sig then\n\t\t\trefreshParts()\n", "\t\telseif false then\n"),
    ("WIN", "MarketPage is never bound", "\thook(\"MarketPage\", MarketWindow.OnPage)", "\t--"),
    ("WIN", "no TXT fallback for Resting", "\tif key == \"Resting\" then return tx(TXT, \"Resting\") end\n", ""),
    ("WIN", "Config.Market.Text is ignored", "\tif texts and texts[key] ~= nil then", "\tif false then"),
    ("WIN", "the search reads the key, not the name", "string.find(string.lower(info.Name), q, 1, true)", "string.find(string.lower(info.Key), q, 1, true)"),
    ("WIN", "the search is case-sensitive", "local q = string.lower(type(query) == \"string\" and query or \"\")",
     "local q = type(query) == \"string\" and query or \"\""),
    ("WIN", "a quest thing is sold / listed", "local kind = type(def) == \"table\" and L.ItemKind[def.Kind] or nil",
     "local kind = type(def) == \"table\" and (L.ItemKind[def.Kind] or \"Material\") or nil"),
    ("WIN", "Pet Treat is no tonic", "Tonic = \"Tonic\", Treat = \"Tonic\"", "Tonic = \"Tonic\", Treat = \"Material\""),
    ("WIN", "a weapon tier that does not exist shows", "if not (tier and plus and Config.Weapons[tier]) then return nil end",
     "if not (tier and plus) then return nil end"),
    ("WIN", "the first index row is not picked", "S.BuyKey, S.BuyPage = all[1] and all[1].Key or nil, 1", "S.BuyKey, S.BuyPage = nil, 1"),
    ("WIN", "picking a thing to sell asks no Browse", "S.SellKey, S.SellN, S.SellPrice = key, 1, nil\n\tVIEW.Focus = false\n\twantOpenPage()",
     "S.SellKey, S.SellN, S.SellPrice = key, 1, nil\n\tVIEW.Focus = false"),
    ("WIN", "the price is not clamped to Max", "\tif m.Max then p = math.min(p, math.floor(m.Max)) end\n", ""),
    ("WIN", "the price is not clamped to Min", "\tif m.Min then p = math.max(p, math.floor(m.Min)) end\n", ""),
    ("WIN", "the price does not start at Ref", "num(S.SellPrice, m.Ref or m.Min or 1)", "num(S.SellPrice, 1)"),
    ("WIN", "the fee rounds up", "local fee = math.floor(price * L.Fee)", "local fee = math.ceil(price * L.Fee)"),
    ("WIN", "the price box takes letters", "local digits = (string.gsub(tb.Text, \"%D\", \"\"))", "local digits = tb.Text"),
    ("WIN", "a spare is listed as an item", "\tif entry.Info.Kind == \"Weapon\" then kind, id = \"W\", entry.Info.Spare end\n", ""),
    ("WIN", "a spare's id is its tier only", "Spare = string.format(\"%d:%d\", tier, plus) }", "Spare = tostring(tier) }"),
    ("WIN", "List sends one whatever the count", "if not send(\"MarketList\", kind, id, n, price) then return false end",
     "if not send(\"MarketList\", kind, id, 1, price) then return false end"),
    ("WIN", "Gate.List is ignored", "\tif S.Gate.List ~= \"\" then return noteText(S.Gate.List), false end\n", ""),
    ("WIN", "Gate.ListIn is ignored", "\tif wait > 0 then return tx(TXT, \"Wait\", MarketWindow.TimeText(wait)), false end\n", ""),
    ("WIN", "Gate.Buy is ignored", "\tif S.Gate.Buy ~= \"\" then return noteText(S.Gate.Buy), false end\n", ""),
    ("WIN", "an owned weapon tier can be bought",
     "\tif info.Kind == \"Weapon\" and owns(ctx, info.Tier) then return tx(TXT, \"Owned\"), false end\n", ""),
    ("WIN", "the worn tier is not owned", "return tier == math.floor(num(ctx.Equipped, 0)) or bit32.btest(", "return bit32.btest("),
    ("WIN", "Buy sends another price", "send(\"MarketBuy\", row.Id, row.Price)", "send(\"MarketBuy\", row.Id, row.Price + 1)"),
    ("WIN", "no Checking while a Buy waits", "S.Pending = { Name = \"MarketBuy\", Id = row.Id, At = os.clock() }", "S.Pending = nil"),
    ("WIN", "a request never stops waiting", "if p and now - p.At >= L.Timeout then", "if false then"),
    ("WIN", "after 3 s Mine is not asked again", "\t\tS.Pending = nil\n\t\tS.WantMine = true\n\t\twantOpenPage()\n\t\trefreshParts()",
     "\t\tS.Pending = nil\n\t\twantOpenPage()\n\t\trefreshParts()"),
    ("WIN", "after 3 s the open page is not asked again", "\t\tS.WantMine = true\n\t\twantOpenPage()\n\t\trefreshParts()\n\tend",
     "\t\tS.WantMine = true\n\t\trefreshParts()\n\tend"),
    ("WIN", "no page past the last", "math.clamp(S.BuyPage + (delta < 0 and -1 or 1), 1, entry.Pages)", "math.max(1, S.BuyPage + (delta < 0 and -1 or 1))"),
    ("WIN", "the time left never runs", "timeLabel.Text = MarketWindow.TimeText(left - (now - entry.At))", "timeLabel.Text = MarketWindow.TimeText(left)"),
    ("WIN", "no h:mm from an hour", "\tif sec >= 3600 then", "\tif false then"),
    ("WIN", "a Sold row gets a [Cancel]", "\tif r.State == \"Open\" then\n\t\tlocal left = r.Left", "\tif r.State ~= \"Expired\" then\n\t\tlocal left = r.Left"),
    ("WIN", "Paid is always shown", "tx(TXT, r.Paid and \"Paid\" or \"Paying\")", "tx(TXT, \"Paid\")"),
    ("WIN", "the Mine tab never gets its dot", "local n = (id == \"Mine\" and not on) and soldNew() or 0", "local n = 0"),
    ("WIN", "the dot never goes away", "\t\tif r.State == \"Sold\" and S.Tab == \"Mine\" then S.SeenSold[r.Id] = true end -- I looked at it\n", ""),
    ("WIN", "[Cancel] works on any row", "if r.Id == id and r.State == \"Open\" then row = r end", "if r.Id == id then row = r end"),
    ("WIN", "a Mine row in a state the server never sends", "if (state == \"Open\" or state == \"Sold\" or state == \"Cancel\" or state == \"Expired\")",
     "if state ~= nil"),
    ("WIN", "Waiting rows are not shown", "for i = 1, math.min(mine.Waiting, L.MaxWaiting) do", "for i = 1, 0 do"),
    ("WIN", "the open arg is applied on every rebuild", "\tif arg == S.LastArg then arg = nil else S.LastArg = arg end\n", ""),
    ("WIN", "the open arg's tab is not applied", "if type(arg) == \"table\" and table.find(L.Tabs, arg.Tab) then S.Tab = arg.Tab end",
     "if false then S.Tab = arg.Tab end"),
    ("WIN", "an unknown tab in the arg is taken", "if type(arg) == \"table\" and table.find(L.Tabs, arg.Tab) then S.Tab = arg.Tab end",
     "if type(arg) == \"table\" and arg.Tab ~= nil then S.Tab = arg.Tab end"),
    ("WIN", "my gold is the bank only", "num(attr(\"BankGold\"), 0) + num(attr(\"CarriedGold\"), 0)", "num(attr(\"BankGold\"), 0)"),
    ("WIN", "a weapon named for another class", "Config.WeaponName(tier, ctx.Class, ctx.Faction)", "Config.WeaponName(tier, \"Warrior\", ctx.Faction)"),
    ("WIN", "a weapon's +N is not shown", "Title = plus > 0 and (name .. \" \" .. tx(TXT, \"Plus\", plus)) or name,", "Title = name,"),
    ("WIN", "four hint rows", "HintRows = 3,", "HintRows = 4,"),
    ("WIN", "All lists one", "\t\tS.SellN = entry.Count\n", "\t\tS.SellN = 1\n"),
    ("WIN", "the price box loses the keyboard to a redraw", "\tif VIEW.Focus then\n\t\tVIEW.Dirty = true", "\tif false then\n\t\tVIEW.Dirty = true"),
    ("MAIN", "the window is never loaded", "\"CraftWindow\", \"MarketWindow\",", "\"CraftWindow\","),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def code_lines(text: str) -> list[str]:
    return [l for l in text.splitlines() if not l.strip().startswith("--")]


def english_literals(text: str) -> list[str]:
    """Player-looking string literals (two words) outside the TXT table, comments and Util.Warn lines."""
    cut = re.sub(r"local TXT = \{.*?\n\}\nL10n\.Register", "L10n.Register", text, flags=re.S)
    bad = []
    for line in code_lines(cut):
        if "Util.Warn" in line or "L10n.Register(" in line:
            continue
        line = line.split(" -- ")[0]
        for lit in re.findall(r'"([^"\n]*)"', line):
            if re.search(r"[A-Za-z]{3,}[ .,!?]+[A-Za-z]{2,}", lit):
                bad.append(lit)
    return bad


def static(src: dict) -> list[tuple[str, bool]]:
    order = re.search(r"local ORDER = \{([^}]*)\}", src["MAIN"])
    names = re.findall(r'"(\w+)"', order.group(1)) if order else []
    code = "\n".join(code_lines(src["WIN"]))
    sends = sorted(set(re.findall(r'send\("(\w+)"', code)))
    return [
        ("ClientMain loads MarketWindow right after CraftWindow (and after Panels / UIKit)", "MarketWindow" in names and "CraftWindow" in names
         and names.index("MarketWindow") == names.index("CraftWindow") + 1
         and all(n in names and names.index("MarketWindow") > names.index(n) for n in ("Panels", "UIKit"))),
        ("the window sends the six market requests only, all through send()", sends == SENDS and code.count("kit.Fire(") == 1),
        ("no fixed key in MarketWindow (BB1)", "Enum.KeyCode" not in code),
        ("the client computes no gate (§6-4): no AccountAge, no Level, no PlaytimeSeconds", "AccountAge" not in code
         and "PlaytimeSeconds" not in code and "\"Level\"" not in code),
        ("remotes are looked up by name when used (no Net.Get, no WaitForChild for a c->s remote)", "Net.Get" not in code
         and "hasRemote" in code and 'FindFirstChild("Remotes")' in code),
        ("notice texts come from Config.Market.Text with a TXT fallback", "Config.Market" in code and "texts[key]" in code
         and "tx(TXT, \"Refused\")" in code),
        ("no hard-coded English outside TXT (dev log lines through Util.Warn excepted)", not english_literals(src["WIN"])),
        ("Panels' menu takes a registered window's opts.Menu", "type(o.Menu) == \"function\"" in src["PANELS"]
         and "table.insert(entries, 2 + i, e)" in src["PANELS"]),
    ]


def run(src: dict) -> tuple[int, int, str]:
    text = ("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal WINDOW_SOURCE = " + lua_str(src["WIN"]) + "\n"
            + FIXTURE.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "market_window.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"MARKET_WINDOW_SUMMARY checks=(\d+) failed=(\d+)", out)
    failed = int(m[2]) if m else 1
    st = static(src)
    for name, ok in st:
        out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + name
        failed += 0 if ok else 1
    return (int(m[1]) if m else 0) + len(st), failed, out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    checks, failed, out = run(src)
    print(out.strip())
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
    status = "passed" if failed == 0 and checks > 0 and all(m["caught"] for m in muts) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
