"""Pause card check (SPEC A23-79 #1, PauseCard.luau) in the main Studio, before the server sends it (게임성 개발 2): my own
test Play with a FRESH in-memory save; past the first steps (TutorialStep = Done, this Play only) the server double fires
the Fx the server will send - "PauseCard" { Next, Why } and "WelcomeBack" { Next, Zone } - to me only. Checks: the card
opens with its words, two buttons of one size, no other button; PC: a real click on [OK] closes it, a real click on [Go]
starts the travel to the zone (TravelingUntil); phone: the cards are photographed (Studio's phone simulator puts MCP
clicks in the wrong place, menu_tap_view.py note) and the first one is taken away so the second can open.
Usage: py tools/play_pause_card_check.py pc|phone   Out: docs/art/verification_2026-10-08/pause_card/<mode>/"""
import json
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import play_sound_check as psc  # noqa: E402
import play_crossroads_check as pcc  # noqa: E402
from studio_mcp import Client  # noqa: E402

MODE = sys.argv[1] if len(sys.argv) > 1 else "pc"  # pc | phone (749x361, back to default at the end)
OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-08", "pause_card", MODE)
LOG = []
psc.OUT, psc.LOG = OUT, LOG
pcc.OUT = OUT

# server: past the first steps (this test Play only), then send me an Fx
SRV_READY = r"""
local Players = game:GetService("Players")
local p = Players:GetPlayers()[1]
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local done = type(Config.Tutorial) == "table" and type(Config.Tutorial.Steps) == "table" and tonumber(Config.Tutorial.Steps.Done) or 99
p:SetAttribute("TutorialStep", done)
return "TutorialStep = " .. tostring(p:GetAttribute("TutorialStep"))
"""
SRV_FX = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local fx = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Fx")
fx:FireClient(p, %s, %s)
return "fired " .. %s
"""
SRV_TRAVEL = r"""
local p = game:GetService("Players"):GetPlayers()[1]
return string.format("TravelingUntil %.1f now %.1f zone %s", tonumber(p:GetAttribute("TravelingUntil")) or 0,
	workspace:GetServerTimeNow(), tostring(p:GetAttribute("Zone")))
"""
# client: the card as JSON
CARD = r"""
local p = game:GetService("Players").LocalPlayer
local gui = p.PlayerGui:FindFirstChild("MainGui")
local card = gui and gui:FindFirstChild("PauseCard")
if not card then return game:GetService("HttpService"):JSONEncode({ Open = false }) end
local out = { Open = true, Buttons = {}, Path = card:GetFullName() }
local t, b = card:FindFirstChild("Title", true), card:FindFirstChild("Body", true)
out.Title = t and t.Text or ""
out.Body = b and b.Text or ""
for _, d in card:GetDescendants() do
	if d:IsA("GuiButton") then
		table.insert(out.Buttons, { Name = d.Name, Text = d:IsA("TextButton") and d.Text or "", W = d.AbsoluteSize.X, H = d.AbsoluteSize.Y,
			Path = d:GetFullName() })
	end
end
return game:GetService("HttpService"):JSONEncode(out)
"""
DROP = r"""
local gui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("MainGui")
local card = gui and gui:FindFirstChild("PauseCard")
if card then card:Destroy() return "card taken away" end
return "no card"
"""


def lua_str(s):
    return json.dumps(s)


def fire(c, kind, data):
    table = "{" + ", ".join(f"{k} = {lua_str(v)}" for k, v in data.items()) + "}"
    psc.note(psc.lua(c, SRV_FX % (lua_str(kind), table, lua_str(kind)), "Server"))
    time.sleep(1.2)


def card(c):
    raw = psc.lua(c, CARD, "Client")
    try:
        found = json.loads(raw or "{}")
    except ValueError:
        psc.note("card probe: " + raw[:300])
        return {"Open": False}
    psc.note("card: " + json.dumps(found, ensure_ascii=False)[:500])
    return found


def click(c, path):
    # instance paths from GetFullName: "Players.<name>.PlayerGui..." -> "game.Players...."
    res = psc.text_of(c.call("user_mouse_input", {"datamodel_type": "Client", "actions": [
        {"action": "moveTo", "instance_path": "game." + path}, {"action": "mouseButtonClick", "mouse_button": "left"}]}))
    psc.note("click " + path.split(".")[-1] + ": " + res[:120])
    time.sleep(1.0)


def buttons_ok(found, names):
    bs = {b["Name"]: b for b in found.get("Buttons", [])}
    if sorted(bs) != sorted(names):
        return False
    sizes = {(round(b["W"]), round(b["H"])) for b in bs.values()}
    return len(sizes) == 1


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    os.makedirs(OUT, exist_ok=True)
    psc.restore_studio_window()
    c = Client()
    c.start()
    results = {}
    try:
        st = psc.text_of(c.call("get_studio_state", {}))
        if "Current Studio Mode: Edit" not in st:
            sys.exit("not in Edit: " + st)
        if MODE == "phone":
            psc.note("device: " + psc.lua(c, psc.SET_PHONE, "Edit"))
        else:
            psc.note("device before Play: " + psc.lua(c, psc.RESTORE, "Edit"))
        psc.note(psc.lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh on"', "Edit"))
        c.call("start_stop_play", {"is_start": True})
        s = psc.wait_state(c, lambda x: "DataLoaded=true" in x, 90, 1.0)
        psc.note("loaded: " + s)
        time.sleep(24)
        psc.note(psc.lua(c, psc.FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
        psc.wait_state(c, lambda x: "Faction=Halo" in x, 20)
        psc.note(psc.lua(c, psc.FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"))
        psc.wait_state(c, lambda x: "ClassChosen=true" in x, 20)
        time.sleep(3)
        psc.note(psc.lua(c, pcc.CLOSE, "Client"))
        psc.note(psc.lua(c, SRV_READY, "Server"))
        time.sleep(1.0)
        # 1) the pause card
        fire(c, "PauseCard", {"Next": "King Slime (2 of 3)", "Why": "Chapter"})
        found = card(c)
        results["the pause card opens: Saved! / Next time: <goal>"] = (
            found.get("Open") and found.get("Title") == "Saved!" and found.get("Body") == "Next time: King Slime (2 of 3)")
        results["[Keep playing] and [OK], one size, no other button"] = buttons_ok(found, ["Keep", "OK"])
        psc.save(c, "01_pause_card")
        if MODE == "pc":
            ok_btn = next((b for b in found.get("Buttons", []) if b["Name"] == "OK"), None)
            if ok_btn:
                click(c, ok_btn["Path"])
            results["a real click on [OK] closes it"] = not card(c).get("Open")
        else:
            psc.note(psc.lua(c, DROP, "Client"))
            time.sleep(1.0)
        # 2) Welcome back
        fire(c, "WelcomeBack", {"Next": "Slime jelly 2 of 5", "Zone": "SlimeMeadow"})
        found = card(c)
        results["Welcome back opens: Welcome back! / Next: <goal>"] = (
            found.get("Open") and found.get("Title") == "Welcome back!" and found.get("Body") == "Next: Slime jelly 2 of 5")
        results["[Go] and [OK], one size"] = buttons_ok(found, ["Go", "OK"])
        psc.save(c, "02_welcome_back")
        if MODE == "pc":
            go_btn = next((b for b in found.get("Buttons", []) if b["Name"] == "Go"), None)
            if go_btn:
                click(c, go_btn["Path"])
            travel = psc.lua(c, SRV_TRAVEL, "Server")
            psc.note(travel)
            try:
                until, now = float(travel.split()[1]), float(travel.split()[3])
            except (IndexError, ValueError):
                until, now = 0.0, 1.0
            results["a real click on [Go] closes it and starts the travel"] = (not card(c).get("Open")) and until > now
            time.sleep(1.5)
            psc.save(c, "03_after_go")
        con = psc.text_of(c.call("get_console_output", {}))
        errs = [ln for ln in con.splitlines() if any(k in ln.lower() for k in ("error", "failed", "infinite yield"))
                and "DataStore" not in ln]
        psc.note("console: " + "\n".join(errs[-20:]))
        results["no PauseCard error in the console"] = not any("PauseCard" in ln for ln in errs)
    finally:
        try:
            c.call("start_stop_play", {"is_start": False})
            psc.note("play stopped")
        except Exception as e:  # noqa: BLE001
            psc.note("stop failed " + str(e))
        time.sleep(2)
        psc.note(psc.lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", nil) return "fresh off"', "Edit"))
        psc.note("device: " + psc.lua(c, psc.RESTORE, "Edit"))
        for name, ok in results.items():
            psc.note(("OK   " if ok else "FAIL ") + name)
        with open(os.path.join(OUT, "results.json"), "w", encoding="utf-8") as f:
            json.dump(results, f, ensure_ascii=False, indent=1)
        with open(os.path.join(OUT, "log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")
        c.close()


if __name__ == "__main__":
    main()
