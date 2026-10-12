"""User 2026-10-08 MMO keys check (SPEC A23-78) in the main Studio: own test Play with a FRESH in-memory save (PC). After
the faction / class: I = the bag (the Items window until a Bag window exists), Q = the HUD quest list folds out / in,
E = Hero and K = Skills ('Coming soon!' like their HUD tiles), L = the ranking list, Z = the skill ('Skills come at
Lv 5' before Lv5), G = interact (the prompts draw G). Keys go through Keybinds.Dispatch (the game's own key path);
then the REAL I and O keys through Studio MCP keyboard input (this test Play only, not the desktop keyboard): I must
open the bag without changing the camera distance (Roblox's I zoom is sunk while the bag holds I), O still zooms out.
Sounds are logged like tools/play_sound_check.py (WindowOpen / WindowClose). Captures + probes; Play stopped in finally.
Usage: py tools/play_keys_check.py [outdir-name]   Out: docs/art/verification_2026-10-08/keys_check/<outdir>/"""
import json
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import play_sound_check as psc  # noqa: E402  (helpers: lua, STATE, FIRE, DISPATCH, COLLECT, MARK, DUMP, ...)
from studio_mcp import Client  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-08", "keys_check",
                   sys.argv[1] if len(sys.argv) > 1 else "pc")
LOG = []
psc.OUT, psc.LOG = OUT, LOG  # psc.note / psc.save write here

# client: what the keys opened (Panels window + title, the HUD quest list, the ranking list, toasts, prompt keys,
# the camera distance)
PROBE = r"""
local HttpService = game:GetService("HttpService")
local p = game:GetService("Players").LocalPlayer
local pg = p:FindFirstChildOfClass("PlayerGui")
local function shown(x)
	while x and x ~= pg do
		if x:IsA("GuiObject") and not x.Visible then return false end
		if x:IsA("ScreenGui") and not x.Enabled then return false end
		x = x.Parent
	end
	return x == pg
end
local out = { Panels = false, Title = "", Quests = false, PlayerList = false, Toasts = {}, Prompts = {} }
for _, d in pg:GetDescendants() do
	if d.Name == "PanelsModal" and d:IsA("GuiObject") then
		out.Panels = shown(d)
		local t = d:FindFirstChild("Title", true)
		if t and t:IsA("TextLabel") then out.Title = t.Text end
	elseif d.Name == "Quests" and d:IsA("Frame") and d.Parent and d.Parent.Name == "HUD" then
		out.Quests = shown(d)
	elseif d.Name == "PlayerList" and d:IsA("GuiObject") then
		out.PlayerList = out.PlayerList or shown(d)
	elseif d.Name == "Toast" and d:IsA("GuiObject") and shown(d) then
		for _, t in d:GetDescendants() do
			if t:IsA("TextLabel") and t.Text ~= "" then table.insert(out.Toasts, t.Text) end
		end
	end
end
local seen = {}
for _, d in workspace:GetDescendants() do
	if d:IsA("ProximityPrompt") and not seen[d.KeyboardKeyCode.Name] then
		seen[d.KeyboardKeyCode.Name] = true
		table.insert(out.Prompts, d.KeyboardKeyCode.Name)
	end
end
local cam = workspace.CurrentCamera
local head = p.Character and p.Character:FindFirstChild("Head")
out.CamDist = head and math.floor((cam.CFrame.Position - head.Position).Magnitude * 10 + 0.5) / 10 or -1
return HttpService:JSONEncode(out)
"""


def probe(c, tag):
    raw = psc.lua(c, PROBE, "Client")
    psc.note(f"probe {tag}: {raw}")
    try:
        return json.loads(raw)
    except Exception:  # noqa: BLE001
        return {}


def key(c, name, tag):
    psc.mark(c, tag)
    psc.note(f"dispatch {name}: " + psc.lua(c, psc.DISPATCH % name, "Client"))
    time.sleep(1.2)
    return probe(c, tag)


def real_keys(c, actions):
    try:
        res = c.call("user_keyboard_input", {"actions": actions, "datamodel_type": "Client"})
        return psc.text_of(res)[:200]
    except Exception as e:  # noqa: BLE001
        return "ERR " + str(e)[:200]


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    os.makedirs(OUT, exist_ok=True)
    psc.restore_studio_window()
    c = Client()
    c.start()
    rows = []
    results = {}
    try:
        st = psc.text_of(c.call("get_studio_state", {}))
        if "Current Studio Mode: Edit" not in st:
            sys.exit("not in Edit: " + st)
        psc.note("device before Play: " + psc.lua(c, psc.RESTORE, "Edit"))
        psc.note(psc.lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh on"', "Edit"))
        c.call("start_stop_play", {"is_start": True})
        for _ in range(40):
            r = psc.lua(c, psc.COLLECT, "Client")
            if r.startswith("collector ok"):
                break
            time.sleep(0.5)
        s = psc.wait_state(c, lambda x: "DataLoaded=true" in x, 90, 1.0)
        psc.note("loaded: " + s)
        time.sleep(24)  # the first-time opening
        psc.note(psc.lua(c, psc.FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
        psc.wait_state(c, lambda x: "Faction=Halo" in x, 20)
        psc.note(psc.lua(c, psc.FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"))
        psc.wait_state(c, lambda x: "ClassChosen=true" in x, 20)
        time.sleep(4)
        # the guide window is open after the class pick: close it with its own key path first (B = menu closes windows)
        psc.note("close guide: " + psc.lua(c, psc.DISPATCH % "B", "Client"))
        time.sleep(1.0)
        base = probe(c, "start")
        results["prompts draw G"] = base.get("Prompts") == ["G"] or ("G" in (base.get("Prompts") or []))
        p = key(c, "I", "I (the bag: Items)")
        results["I opens the bag (Items)"] = bool(p.get("Panels"))
        psc.save(c, "01_I_bag")
        p = key(c, "I", "I again (closes)")
        results["I again closes it"] = not p.get("Panels")
        p = key(c, "Q", "Q (quest list out)")
        results["Q folds the quest list out"] = bool(p.get("Quests"))
        psc.save(c, "02_Q_quests")
        p = key(c, "Q", "Q again (quest list in)")
        results["Q again folds it in"] = not p.get("Quests")
        p = key(c, "E", "E (Hero: Coming soon)")
        results["E says Coming soon"] = any("Coming soon" in t for t in p.get("Toasts", []))
        psc.save(c, "03_E_hero")
        time.sleep(2.0)
        p = key(c, "K", "K (Skills: Coming soon)")
        results["K says Coming soon"] = any("Coming soon" in t for t in p.get("Toasts", []))
        time.sleep(2.0)
        p = key(c, "L", "L (the ranking list)")
        results["L opens the ranking list"] = bool(p.get("PlayerList"))
        psc.save(c, "04_L_ranking")
        p = key(c, "L", "L again (closes)")
        results["L again closes it"] = not p.get("PlayerList")
        p = key(c, "Z", "Z (the skill before Lv5)")
        results["Z = the skill key (Lv5 note before)"] = any("Lv 5" in t or "Lv5" in t for t in p.get("Toasts", []))
        # the REAL keys (Studio MCP keyboard input in this test Play): I opens the bag, the camera does not zoom
        time.sleep(1.5)
        before = probe(c, "before real I")
        psc.mark(c, "real I key held 1.5 s")
        psc.note("real I: " + real_keys(c, [{"action": "keyDown", "key_code": "I"}, {"action": "wait", "wait_time_ms": 1500},
                                              {"action": "keyUp", "key_code": "I"}]))
        time.sleep(0.8)
        after = probe(c, "after real I")
        psc.save(c, "05_real_I")
        results["real I opens the bag"] = bool(after.get("Panels"))
        results["real I does not zoom the camera"] = abs(after.get("CamDist", -1) - before.get("CamDist", -2)) < 0.6
        psc.note("close: " + psc.lua(c, psc.DISPATCH % "I", "Client"))
        time.sleep(1.0)
        before_o = probe(c, "before real O")
        psc.note("real O: " + real_keys(c, [{"action": "keyDown", "key_code": "O"}, {"action": "wait", "wait_time_ms": 1200},
                                              {"action": "keyUp", "key_code": "O"}]))
        time.sleep(0.8)
        after_o = probe(c, "after real O")
        results["real O still zooms out (Roblox's)"] = after_o.get("CamDist", 0) > before_o.get("CamDist", 0) + 0.5
        psc.mark(c, "end")
        start = 0
        while True:
            raw = psc.lua(c, psc.DUMP % start, "Client")
            try:
                part = json.loads(raw)
            except Exception:  # noqa: BLE001
                break
            rows.extend(part)
            if len(part) < 400:
                break
            start += len(part)
        con = psc.text_of(c.call("get_console_output", {}))
        errs = [ln for ln in con.splitlines() if any(k in ln.lower() for k in ("error", "failed", "infinite yield"))
                and "DataStore" not in ln]
        psc.note("console: " + "\n".join(errs[-20:]))
    finally:
        try:
            c.call("start_stop_play", {"is_start": False})
            psc.note("play stopped")
        except Exception as e:  # noqa: BLE001
            psc.note("stop failed " + str(e))
        time.sleep(2)
        psc.note(psc.lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh kept on"', "Edit"))
        psc.note("device: " + psc.lua(c, psc.RESTORE, "Edit"))
        for name, ok in results.items():
            psc.note(("OK   " if ok else "FAIL ") + name)
        with open(os.path.join(OUT, "results.json"), "w", encoding="utf-8") as f:
            json.dump({"results": results, "sounds": rows}, f, ensure_ascii=False, indent=1)
        with open(os.path.join(OUT, "log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")
        c.close()


if __name__ == "__main__":
    main()
