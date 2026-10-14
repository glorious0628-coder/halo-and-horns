"""A23-167 ① ③ ④ screens (fix/goal-chips-3, 게임성 개발 1, 2026-10-14) in the MAIN Studio (메인 반영 1 only,
HH_MAIN_STUDIO=1; own test Play with a FRESH in-memory save; no mouse / keyboard input; a phone run puts the device
emulation back to default at the end, even after an error).
  01_faction     the faction picker: under each side's card the three 'what this pick changes' lines (the log has their
                 words, size and whether they fit)
  02_tiers       Halo Warrior, first mission taken: the 'now do' quest + 'Next: Lv 5 · first skill' + 'Big goal: ...'
                 (PC; phones show tier 1 only - the log says what is shown)
  03_tiers_goal  the first claim done (TutorialStep 99): the tracker's next-goal row + the tiers after it
  04_ko          this run's gains (the server double sets XP / pouch gold / Honor attributes and sends my Fx "Loot" with
                 2 scrolls), then my humanoid's health 0: the KO screen with 'This run' (+XP, +gold, +2 items, +3 Honor)
Usage: HH_MAIN_STUDIO=1 py tools/play_goal_chips_photos.py [phone]
Out: docs/art/verification_2026-10-14/goal_chips/<dev>_<name>.png, log_<dev>.txt"""
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import play_first_look_photos as plp  # noqa: E402
from studio_mcp import Client  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-14", "goal_chips")
LOG = []
plp.OUT, plp.LOG = OUT, LOG
lua, note, save = plp.lua, plp.note, plp.save

PICKER = r'''
local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
local out = {}
for _, d in pg:GetDescendants() do
	if d:IsA("Frame") and string.match(d.Name, "^Changes_") then
		local lines = {}
		for _, l in d:GetChildren() do
			if l:IsA("TextLabel") then
				table.insert(lines, string.format("'%s' %dpx fits=%s", l.Text, math.floor(l.TextBounds.Y + 0.5), tostring(l.TextFits)))
			end
		end
		table.insert(out, string.format("%s y=%d h=%d: %s", d.Name, math.floor(d.AbsolutePosition.Y), math.floor(d.AbsoluteSize.Y),
			table.concat(lines, ", ")))
	end
end
return #out > 0 and table.concat(out, " | ") or "no change lines (picker not open?)"
'''
TIERS = r'''
local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
local out = {}
for _, d in pg:GetDescendants() do
	if d:IsA("TextLabel") and d.Parent and d.Parent.Name == "QuestTracker" then
		table.insert(out, string.format("%s %s '%s' %dpx", d.Name, d.Visible and "shown" or "hidden", d.Text, math.floor(d.TextBounds.Y + 0.5)))
	elseif d.Name == "Title" and d.Parent and d.Parent.Name == "Row" and d.Parent.Parent and d.Parent.Parent.Name == "Head" then
		table.insert(out, "Title '" .. d.Text .. "'")
	end
end
local p = game:GetService("Players").LocalPlayer
return "Lv " .. tostring(p:GetAttribute("Level")) .. " | " .. (#out > 0 and table.concat(out, " | ") or "no tracker")
'''
GAINS = r'''
local p = game:GetService("Players"):GetPlayers()[1]
p:SetAttribute("XP", (p:GetAttribute("XP") or 0) + 12)
p:SetAttribute("CarriedGold", (p:GetAttribute("CarriedGold") or 0) + 40)
p:SetAttribute("Honor", (p:GetAttribute("Honor") or 0) + 3)
local fx = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Fx")
fx:FireClient(p, "Loot", { Items = { { Item = "Scroll", Name = "Scroll", N = 2 } } })
return "gains set: XP " .. tostring(p:GetAttribute("XP")) .. " gold " .. tostring(p:GetAttribute("CarriedGold")) .. " honor " .. tostring(p:GetAttribute("Honor"))
'''
KO = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
if not h then return "no humanoid" end
h.Health = 0
return "health 0"
'''
KO_TEXT = r'''
local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
for _, d in pg:GetDescendants() do
	if d.Name == "DeathScreen" and d:IsA("Frame") then
		local box = d:FindFirstChild("Lines")
		local out = {}
		for _, l in box and box:GetChildren() or {} do
			if l:IsA("TextLabel") and l.Visible then table.insert(out, { l.LayoutOrder, l.Name .. "='" .. l.Text .. "'" }) end
		end
		table.sort(out, function(a, b) return a[1] < b[1] end)
		local s = {}
		for _, v in out do table.insert(s, v[2]) end
		return "KO screen: " .. table.concat(s, " | ")
	end
end
return "no KO screen"
'''


def run(c, dev):
    if dev == "phone":
        note("device: " + lua(c, plp.SET_PHONE, "Edit"))
    note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh on"', "Edit"))
    c.call("start_stop_play", {"is_start": True})
    note("loaded: " + plp.wait_state(c, lambda x: "DataLoaded=true" in x, 90, 2.0))
    time.sleep(15)
    note(lua(c, plp.FIRE % ("IntroSeen", "", "IntroSeen"), "Client"))
    time.sleep(4)
    note("picker: " + lua(c, PICKER, "Client"))
    save(c, f"{dev}_01_faction")
    note(lua(c, plp.FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
    plp.wait_state(c, lambda x: "Faction=Halo" in x, 20)
    note(lua(c, plp.FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"))
    note("chosen: " + plp.wait_state(c, lambda x: "ClassChosen=true" in x, 20))
    note(lua(c, plp.FIRE % ("AcceptTutorial", "", "AcceptTutorial"), "Client"))
    time.sleep(4)
    note("tiers: " + lua(c, TIERS, "Client"))
    save(c, f"{dev}_02_tiers")
    note(lua(c, plp.CLAIMED, "Server"))
    time.sleep(4)
    note("tiers after claim: " + lua(c, TIERS, "Client"))
    save(c, f"{dev}_03_tiers_goal")
    note(lua(c, GAINS, "Server"))
    time.sleep(2)
    note(lua(c, KO, "Server"))
    seen = "no KO screen"
    for _ in range(10):
        time.sleep(0.5)
        seen = lua(c, KO_TEXT, "Client")
        if seen.startswith("KO screen"):
            break
    note(seen)
    save(c, f"{dev}_04_ko")


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
