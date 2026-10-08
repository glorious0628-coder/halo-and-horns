"""Lost Lunchbox check (검수 2026-10-08: the film session pressed [One bite!] with StoryAction Choose "Evil" and the card did
not change, no reply line). Own test Play with a FRESH in-memory save (PC): faction / class -> the guide's first quest ->
the anvil's first weapon -> 5 slimes -> [Claim] -> the Lunch1 sub ("Lost Lunchbox!", Requires TutorialDone, a Choice
panel) -> StoryAction("Lunch1", "Choose", "Evil") (the remote's real argument order: quest id, action, option) -> the
reply line ("Yum! ...Nobody saw that, right?"), +25 bank gold, the sub moves on; and what a call without the quest id
does (StoryAction("Choose", "Evil") = nothing, the film call). Captures + probes; Play stopped in finally.
Usage: py tools/play_lunch_check.py pc|phone   Out: docs/art/verification_2026-10-08/lunch_check/<mode>/
(after the reply-order fix: the answer is polled on screen for 3 s and photographed when it shows)"""
import json
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import play_sound_check as psc  # noqa: E402
from studio_mcp import Client  # noqa: E402

MODE = sys.argv[1] if len(sys.argv) > 1 else "pc"  # pc | phone (749x361, back to default at the end)
OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-08", "lunch_check", MODE)
LOG = []
psc.OUT, psc.LOG = OUT, LOG

# client: the visible story panel title / lines + the latest notices (toasts and chat-like lines)
PROBE = r"""
local HttpService = game:GetService("HttpService")
local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
local function shown(x)
	while x and x ~= pg do
		if x:IsA("GuiObject") and not x.Visible then return false end
		if x:IsA("ScreenGui") and not x.Enabled then return false end
		x = x.Parent
	end
	return x == pg
end
local out = { Panel = false, Title = "", Texts = {} }
for _, d in pg:GetDescendants() do
	if d.Name == "PanelsModal" and d:IsA("GuiObject") then
		out.Panel = shown(d)
		local t = d:FindFirstChild("Title", true)
		if t and t:IsA("TextLabel") then out.Title = t.Text end
	end
	if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and shown(d) then
		local low = string.lower(d.Text)
		if string.find(low, "lunch", 1, true) or string.find(low, "bite", 1, true) or string.find(low, "yum", 1, true)
			or string.find(low, "give it back", 1, true) or string.find(low, "gold", 1, true) then
			table.insert(out.Texts, d.Text)
		end
	end
end
return HttpService:JSONEncode(out)
"""
DUMP = r"""
local p = game:GetService("Players"):GetPlayers()[1]
return tostring(game.ServerScriptService.DebugCommand:Invoke(p.Name, "StoryDump", true))
"""


def probe(c, tag):
    raw = psc.lua(c, PROBE, "Client")
    psc.note(f"probe {tag}: {raw[:600]}")
    try:
        return json.loads(raw)
    except Exception:  # noqa: BLE001
        return {}


def lunch_state(c):
    raw = psc.lua(c, DUMP, "Server")
    try:
        st = json.loads(raw)
    except Exception:  # noqa: BLE001
        return raw[:300]

    def as_dict(v):
        return v if isinstance(v, dict) else {}  # an empty Luau table comes back as []
    st = as_dict(st)
    done = st.get("Done")
    done_v = as_dict(done).get("Lunch1") if isinstance(done, dict) else (("Lunch1" in done) if isinstance(done, list) else None)
    return json.dumps({"Lunch1": as_dict(st.get("Subs")).get("Lunch1"), "Pick": as_dict(st.get("Pick")).get("Lunch1"),
                       "Done": done_v}, ensure_ascii=False)[:400]


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
        for _ in range(40):  # the sound collector (the Devour check)
            if psc.lua(c, psc.COLLECT, "Client").startswith("collector ok"):
                break
            time.sleep(0.5)
        s = psc.wait_state(c, lambda x: "DataLoaded=true" in x, 90, 1.0)
        psc.note("loaded: " + s)
        time.sleep(24)
        psc.note(psc.lua(c, psc.FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
        psc.wait_state(c, lambda x: "Faction=Halo" in x, 20)
        psc.note(psc.lua(c, psc.FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"))
        psc.wait_state(c, lambda x: "ClassChosen=true" in x, 20)
        time.sleep(3)
        psc.note(psc.lua(c, psc.FIRE % ("AcceptTutorial", "", "AcceptTutorial"), "Client"))
        psc.wait_state(c, lambda x: "anvilDist=" in x and float(psc.attr(x, "anvilDist")) < 14, 14, 0.5)
        time.sleep(1.5)
        psc.note(psc.lua(c, psc.ANVIL_PROMPT, "Client"))
        psc.wait_state(c, lambda x: "WeaponTier=1" in x, 10, 0.5)
        time.sleep(2.0)
        psc.hunt(c, "hunt 5 slimes", "TutorialKills", 5, 75, "Slime")
        time.sleep(1.5)
        psc.note(psc.lua(c, psc.FIRE % ("ClaimQuest", '"tutorial"', "ClaimQuest"), "Client"))
        time.sleep(4.0)
        before = lunch_state(c)
        psc.note("lunch before: " + before)
        p0 = probe(c, "after claim (the lunchbox card?)")
        psc.save(c, "01_lunch_card")
        bank0 = psc.attr(psc.lua(c, psc.STATE, "Server"), "BankGold")
        # the film call: no quest id (StoryAction("Choose", "Evil"))
        psc.mark(c, "StoryAction without the quest id (the film call)")
        psc.note(psc.lua(c, psc.FIRE % ("StoryAction", '"Choose", "Evil"', "StoryAction"), "Client"))
        time.sleep(1.5)
        mid = lunch_state(c)
        psc.note("lunch after the id-less call: " + mid)
        results["a call without the quest id changes nothing (call problem, not a game bug)"] = mid == before
        time.sleep(0.6)  # the remote's rate limit (0.4 s)
        # the real call
        psc.mark(c, "StoryAction(Lunch1, Choose, Evil) = [One bite!]")
        psc.note(psc.lua(c, psc.FIRE % ("StoryAction", '"Lunch1", "Choose", "Evil"', "StoryAction"), "Client"))
        # the answer comes 0.35 s after the step moved on (the reply-order fix): watch the screen for 3 s
        seen_at, p1, t0 = None, {}, time.time()
        while time.time() - t0 < 3.0:
            p1 = probe(c, "watching for the answer")
            if any("Yum" in t for t in p1.get("Texts", [])):
                seen_at = time.time() - t0
                psc.save(c, "02_answer_on_screen")
                break
            time.sleep(0.2)
        psc.note(f"answer seen after {seen_at} s" if seen_at is not None else "answer never seen in 3 s")
        time.sleep(1.0)
        held = probe(c, "1 s later")
        results["the answer is still on screen 1 s later"] = any("Yum" in t for t in held.get("Texts", []))
        after = lunch_state(c)
        psc.note("lunch after [One bite!]: " + after)
        if seen_at is None:
            psc.save(c, "02_after_bite")
        p1 = {"Texts": ["Yum"]} if seen_at is not None else p1
        bank1 = psc.attr(psc.lua(c, psc.STATE, "Server"), "BankGold")
        psc.note(f"bank gold {bank0} -> {bank1}")
        results["[One bite!] is recorded (Pick Bite) and the card moves on"] = after != before and "Bite" in after
        results["the reply line shows (Yum! ...)"] = any("Yum" in t for t in p1.get("Texts", []))
        try:
            results["+25 bank gold"] = int(bank1) - int(bank0) == 25
        except (TypeError, ValueError):
            results["+25 bank gold"] = False
        rows = []
        start = 0
        raw = psc.lua(c, psc.DUMP % start, "Client")
        try:
            rows = json.loads(raw)
        except Exception:  # noqa: BLE001
            pass
        results["the Devour sound plays with the pick"] = any(r.get("n", "").startswith("Sfx_Devour") for r in rows)
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
