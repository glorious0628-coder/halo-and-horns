"""거래소 창 photos (게임성 개발 4): own test Play in the practice Studio with a FRESH in-memory save (ServerStorage
StudioFreshSave, Studio only; nothing is saved). The Studio must hold a PHOTO-ONLY sync of this branch with
Config.Features.Market switched on in that throwaway tree (never committed). The market server (C-5, 게임성 개발 2) is not in
the game yet: the server side of this Play makes the nine Market remotes itself (ReplicatedStorage.Remotes) and fires
MarketIndex / MarketPage / MarketMine with made-up rows (a server double), the DebugCommand gives items, OpenPanel("Market",
{ Tab }) moves between the tabs. No mouse, no keyboard. Probes + photos, the console's errors, then Play stops (finally)
and the fresh-save flag is cleared.
Usage: STUDIO_ID=<UiSandbox id> py tools/play_market_photos.py [outdir-name]   (own test Play only: 최종 검수 approves first)
Out: docs/art/verification_2026-10-12/market/<outdir-name or pc>/"""
import base64
import io
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-12", "market", ARGS[0] if ARGS else "pc")
LOG = []


def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))


def lua(c, code, dm):
    try:
        return text_of(c.call("execute_luau", {"code": code, "datamodel_type": dm}))
    except Exception as e:  # noqa: BLE001
        return "ERR " + str(e)[:200]


def note(msg):
    print(msg, flush=True)
    LOG.append(msg)


def save(c, name):
    res = c.call("screen_capture", {"capture_id": name})
    for part in res.get("content", []):
        if part.get("type") == "image":
            from PIL import Image
            os.makedirs(OUT, exist_ok=True)
            path = os.path.join(OUT, name + ".png")
            Image.open(io.BytesIO(base64.b64decode(part["data"]))).save(path)
            note("saved " + path)
            return
    note("capture failed " + name)


STATE = r"""
local p = game:GetService("Players"):GetPlayers()[1]
if not p then return "no player" end
local out = {}
for _, k in { "DataLoaded", "Faction", "Class", "ClassChosen", "BankGold", "CarriedGold" } do
	table.insert(out, k .. "=" .. tostring(p:GetAttribute(k)))
end
return table.concat(out, " ")
"""

FIRE = r"""
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
R:WaitForChild("%s"):FireServer(%s)
return "fired %s"
"""

DEBUG = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local fn = game:GetService("ServerScriptService"):FindFirstChild("DebugCommand")
if not (p and fn) then return "no player / DebugCommand" end
local out = {}
for _, kv in { %s } do
	local ok, r = pcall(function() return fn:Invoke(p.Name, kv[1], kv[2]) end)
	table.insert(out, kv[1] .. "=" .. tostring(ok and r or ("ERR " .. tostring(r))))
end
return table.concat(out, " ")
"""

# server: the market remotes this Play's double needs (the C-5 server makes them later)
REMOTES = r"""
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local made = {}
for _, n in { "MarketIndex", "MarketBrowse", "MarketPage", "MarketList", "MarketBuy", "MarketCancel", "MarketMine" } do
	if not R:FindFirstChild(n) then
		local r = Instance.new("RemoteEvent")
		r.Name = n
		r.Parent = R
		table.insert(made, n)
	end
end
return "made " .. table.concat(made, ",")
"""

SEND = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
R:WaitForChild("%s"):FireClient(p, %s)
return "sent %s"
"""

OPEN = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
R:WaitForChild("OpenPanel"):FireClient(p, "Market", %s)
return "open market"
"""

PROBE = r"""
local HttpService = game:GetService("HttpService")
local p = game:GetService("Players").LocalPlayer
local pg = p:FindFirstChildOfClass("PlayerGui")
local out = { Words = {}, Cut = {} }
local modal = nil
for _, d in pg:GetDescendants() do
	if d.Name == "PanelsModal" and d:IsA("Frame") then modal = d end
end
if not modal or not modal.Visible then return "no open window" end
local win = modal:FindFirstChild("Window")
out.Window = win and string.format("%.0fx%.0f px", win.AbsoluteSize.X, win.AbsoluteSize.Y)
for _, d in win:GetDescendants() do
	if (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) and d.Text ~= "" and d.Visible then
		table.insert(out.Words, d.Name .. ":" .. d.Text)
		if d:IsA("TextLabel") and not d.TextFits then table.insert(out.Cut, d.Name .. ":" .. d.Text) end
	end
end
return HttpService:JSONEncode(out)
"""

GATE = "Gate = { Buy = \"\", List = \"\", ListIn = 0 }"
INDEX = ("{ At = 1, " + GATE + ", Rows = { { Key = \"I:Jelly\", Low = 3, Count = 40 }, { Key = \"I:SlimeCore\", Low = 14, Count = 6 },"
         " { Key = \"I:Petal\", Low = 5, Count = 12 }, { Key = \"I:Enh70\", Low = 300, Count = 2 }, { Key = \"I:MightTonic\", Low = 20, Count = 4 },"
         " { Key = \"W:3:2\", Low = 500, Count = 1 }, { Key = \"W:2:0\", Low = 120, Count = 2 } } }")
PAGE_JELLY = ("{ Key = \"I:Jelly\", Page = 1, Pages = 2, Ref = 2, Min = 2, Max = 50, Rows = { { Id = \"a1\", Price = 3, N = 1, Plus = 0, Left = 7200 },"
              " { Id = \"a2\", Price = 30, N = 10, Plus = 0, Left = 3500 }, { Id = \"a3\", Price = 120, N = 40, Plus = 0, Left = 125 } } }")
PAGE_SLIME = ("{ Key = \"I:SlimeCore\", Page = 1, Pages = 1, Ref = 8, Min = 8, Max = 200, Rows = { { Id = \"s1\", Price = 14, N = 1, Plus = 0, Left = 600 },"
              " { Id = \"s2\", Price = 60, N = 5, Plus = 0, Left = 9000 } } }")
MINE = ("{ " + GATE + ", Waiting = 0, Today = { Lists = 3, Buys = 1 }, Rows = {"
        " { Id = \"m1\", Key = \"I:Jelly\", N = 10, Plus = 0, Price = 30, State = \"Open\", Left = 5400, Paid = false },"
        " { Id = \"m2\", Key = \"I:Enh70\", N = 1, Plus = 0, Price = 320, State = \"Sold\", Left = 0, Paid = true },"
        " { Id = \"m3\", Key = \"W:2:0\", N = 1, Plus = 0, Price = 150, State = \"Expired\", Left = 0, Paid = false } } }")


def wait_state(c, cond, timeout, every=1.0):
    t0 = time.time()
    last = ""
    while time.time() - t0 < timeout:
        last = lua(c, STATE, "Server")
        if cond(last):
            return last
        time.sleep(every)
    return last


def send(c, remote, payload):
    note(lua(c, SEND % (remote, payload, remote), "Server"))


def shot(c, name, wait=1.5):
    time.sleep(wait)
    note(f"probe {name}: " + lua(c, PROBE, "Client"))
    save(c, name)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    c = Client()
    c.start()
    try:
        st = text_of(c.call("get_studio_state", {}))
        if "Current Studio Mode: Edit" not in st:
            sys.exit("not in Edit: " + st)
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh on"', "Edit"))
        c.call("start_stop_play", {"is_start": True})
        note("loaded: " + wait_state(c, lambda x: "DataLoaded=true" in x, 90, 2.0))
        time.sleep(26)  # the first-time opening plays (15-25 s)
        note(lua(c, FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
        wait_state(c, lambda x: "Faction=Halo" in x, 20)
        note(lua(c, FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"))
        note("chosen: " + wait_state(c, lambda x: "ClassChosen=true" in x, 20))
        time.sleep(3)
        gives = ['{ "Gold", 1234 }', '{ "Level", 12 }'] + [f'{{ "Item", "{x}" }}' for x in ("Jelly:24", "SlimeCore:3", "Enh70:2", "Bone:5")]
        note("debug: " + lua(c, DEBUG % ", ".join(gives), "Server"))
        note(lua(c, OPEN % '{ Tab = "Buy" }', "Server"))
        shot(c, "00_resting_no_server", 1.0)
        note(lua(c, REMOTES, "Server"))
        time.sleep(1.5)
        send(c, "MarketIndex", INDEX)
        send(c, "MarketMine", MINE)
        note(lua(c, OPEN % '{ Tab = "Buy" }', "Server"))
        time.sleep(1.0)
        send(c, "MarketIndex", INDEX)
        send(c, "MarketPage", PAGE_JELLY)
        shot(c, "01_buy_materials_jelly")
        note(lua(c, OPEN % '{ Tab = "Sell" }', "Server"))
        time.sleep(1.0)
        send(c, "MarketPage", PAGE_SLIME)
        shot(c, "02_sell_tab")
        note(lua(c, OPEN % '{ Tab = "Mine" }', "Server"))
        time.sleep(0.5)
        send(c, "MarketMine", MINE)
        shot(c, "03_mine_tab")
        if "--hero" in sys.argv:  # the bundle also holds the Hero window (개발 1) + GearSlots: the six gear cells
            note(lua(c, SEND % ("OpenPanel", '"Character"', "OpenPanel"), "Server"))
            shot(c, "04_hero_gear_slots")
        con = text_of(c.call("get_console_output", {}))
        errs = [ln for ln in con.splitlines() if any(k in ln.lower() for k in ("error", "failed", "warn", "infinite yield"))]
        note("console: " + "\n".join(errs[-30:]))
    finally:
        try:
            c.call("start_stop_play", {"is_start": False})
            note("play stopped")
        except Exception as e:  # noqa: BLE001
            note("stop failed " + str(e))
        time.sleep(2)
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh kept on"', "Edit"))
        os.makedirs(OUT, exist_ok=True)
        with open(os.path.join(OUT, "log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")


if __name__ == "__main__":
    main()
