"""A23-167 comeback screens (fix/comeback-client, 게임성 개발 1, 2026-10-14) in the MAIN Studio (메인 반영 1 only,
HH_MAIN_STUDIO=1; own test Play with a FRESH in-memory save; no mouse / keyboard input; the server double fires the Fx
the server sends - to me only; a phone run puts the device emulation back to default at the end, even after an error).
Halo Warrior, the tutorial's first claim done, then:
  01_chip        the first minutes' 2x XP chip ("2x XP · N min", the status chip row; the log has its words)
  02_tomorrow    Fx TomorrowGift { Tomorrow = 2 }: "Tomorrow's gift" + Day 2's art, [OK] only
  03_today       Fx TomorrowGift { Tomorrow = 3, Today = 2 }: + "Today's gift is waiting too!", [Open] + [OK]
  04_back_news   Fx WelcomeBack { Next, Zone, News }: the "while you were away" line under the goal
  05_back_line   attribute Returned = true (this Play only): the first town person who speaks says a back line
                 (waits up to 20 s for a TownReactBubble near me; the log has its words or "no bubble")
Each card's title / body / buttons go to the log; the card is taken away before the next Fx.
Usage: HH_MAIN_STUDIO=1 py tools/play_comeback_photos.py [phone]
Out: docs/art/verification_2026-10-14/comeback/<dev>_<name>.png, log_<dev>.txt"""
import json
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import play_first_look_photos as plp  # noqa: E402
from studio_mcp import Client  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-14", "comeback")
LOG = []
plp.OUT, plp.LOG = OUT, LOG
lua, note, save = plp.lua, plp.note, plp.save

SRV_FX = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local fx = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Fx")
fx:FireClient(p, "%s", game:GetService("HttpService"):JSONDecode(%s))
return "fired %s"
'''
CHIP = r'''
local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
local out = {}
for _, d in pg:GetDescendants() do
	if d:IsA("TextLabel") and d.Visible and string.find(d.Text, "2x", 1, true) then
		table.insert(out, d:GetFullName() .. " = '" .. d.Text .. "'")
	end
end
local p = game:GetService("Players").LocalPlayer
return "PlaytimeSeconds " .. tostring(p:GetAttribute("PlaytimeSeconds")) .. " | " .. (#out > 0 and table.concat(out, " | ") or "no 2x chip")
'''
CARD = r'''
local gui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("MainGui")
local card = gui and gui:FindFirstChild("PauseCard")
if not card then return "no card" end
local t, b, i = card:FindFirstChild("Title", true), card:FindFirstChild("Body", true), card:FindFirstChild("Icon", true)
local buttons = {}
for _, d in card:GetDescendants() do
	if d:IsA("TextButton") and d ~= card then table.insert(buttons, d.Name .. "='" .. d.Text .. "'") end
end
return string.format("title '%s' | body '%s' | icon %s | buttons %s", t and t.Text or "?", b and b.Text or "?",
	i and "yes" or "no", table.concat(buttons, ", "))
'''
DROP = r'''
local gui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("MainGui")
local card = gui and gui:FindFirstChild("PauseCard")
if card then card:Destroy() return "card taken away" end
return "no card to take away"
'''
RETURNED = r'''
local p = game:GetService("Players"):GetPlayers()[1]
p:SetAttribute("Returned", true)
return "Returned " .. tostring(p:GetAttribute("Returned"))
'''
BUBBLE = r'''
for _, d in workspace:GetDescendants() do
	if d.Name == "TownReactBubble" and d:IsA("BillboardGui") then
		local l = d:FindFirstChild("Line", true)
		return "bubble '" .. (l and l.Text or "?") .. "' over " .. tostring(d.Parent and d.Parent.Parent and d.Parent.Parent.Name)
	end
end
return "no bubble"
'''


def fx(c, kind, data):
    note(lua(c, SRV_FX % (kind, json.dumps(json.dumps(data)), kind), "Server"))


def card_shot(c, dev, name):
    time.sleep(1.5)
    note(name + ": " + lua(c, CARD, "Client"))
    save(c, f"{dev}_{name}")
    note(lua(c, DROP, "Client"))
    time.sleep(1.0)


def run(c, dev):
    if dev == "phone":
        note("device: " + lua(c, plp.SET_PHONE, "Edit"))
    note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh on"', "Edit"))
    c.call("start_stop_play", {"is_start": True})
    note("loaded: " + plp.wait_state(c, lambda x: "DataLoaded=true" in x, 90, 2.0))
    time.sleep(15)
    note(lua(c, plp.FIRE % ("IntroSeen", "", "IntroSeen"), "Client"))
    note(lua(c, plp.FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
    plp.wait_state(c, lambda x: "Faction=Halo" in x, 20)
    note(lua(c, plp.FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"))
    note("chosen: " + plp.wait_state(c, lambda x: "ClassChosen=true" in x, 20))
    note(lua(c, plp.FIRE % ("AcceptTutorial", "", "AcceptTutorial"), "Client"))
    time.sleep(2)
    note(lua(c, plp.CLAIMED, "Server"))
    time.sleep(4)
    note("chip: " + lua(c, CHIP, "Client"))
    save(c, f"{dev}_01_chip")
    fx(c, "TomorrowGift", {"Tomorrow": 2, "Days": 1})
    card_shot(c, dev, "02_tomorrow")
    fx(c, "TomorrowGift", {"Tomorrow": 3, "Today": 2, "Days": 1})
    card_shot(c, dev, "03_today")
    fx(c, "WelcomeBack", {"Next": "Beat 5 slimes", "Zone": "SlimeMeadow",
                          "News": "While you were away, crown wars won: Halo 3, Horns 1"})
    card_shot(c, dev, "04_back_news")
    note(lua(c, RETURNED, "Server"))
    seen = "no bubble"
    for _ in range(20):
        time.sleep(1.0)
        seen = lua(c, BUBBLE, "Client")
        if seen.startswith("bubble"):
            break
    note("back line: " + seen)
    save(c, f"{dev}_05_back_line")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    os.makedirs(OUT, exist_ok=True)
    dev = "phone" if "phone" in sys.argv[1:] else "pc"
    c = Client()
    c.start()
    try:
        st = plp.text_of(c.call("get_studio_state", {}))
        if "Current Studio Mode: Edit" not in st:
            sys.exit("not in Edit: " + st)
        try:
            run(c, dev)
        finally:
            try:
                c.call("start_stop_play", {"is_start": False})
                note("play stopped")
            except Exception as e:  # noqa: BLE001
                note("stop failed " + str(e))
    finally:
        if dev == "phone":
            time.sleep(3)
            note("device: " + lua(c, plp.RESTORE, "Edit"))
        with open(os.path.join(OUT, f"log_{dev}.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")


if __name__ == "__main__":
    main()
