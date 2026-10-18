"""Chapter 2 press-through (최종 검수 10/16, main ff1b809b dev2-ch2-story): M1_4 end -> M2_1 giver '!' + 'Talk to ...' row +
way marker -> [Accept] -> M2_3 at the fountain: Tiny's bubble (On = "Tiny") -> M2_4 gold run ends: Clatter's 'Tools' scene.
Scene commands (SceneSetup) to jump; Studio MCP keys / clicks in MY test Play only (STUDIO_NAME=PhoneTest_1015 / STUDIO_ID).
Usage: py ch2_1016.py <Halo|Horns> [--keep]   (--keep: leave Play running for the grip check)"""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from h1016 import (Client, log, save_log, lua, key, click, shot, debug, scene, story, main_of, panel_buttons, close,  # noqa: E402
                   press_until, console_errors, start_play, pick, stop_play, NPC_STATE, GO_TO, FIND_TEXT, MARKER, WORDS, GAME)
import json  # noqa: E402

SIDE = sys.argv[1] if len(sys.argv) > 1 else "Halo"
KEEP = "--keep" in sys.argv
N = {"Halo": dict(m14="Bright", m21="Bright", m23="Tiny", m24="Tiny", find23="Bright tied mine"),
     "Horns": dict(m14="Smokey", m21="Smokey", m23="Tiny", m24="Tiny", find23="Bright kept my bad knot")}[SIDE]
OUT = os.path.join(GAME, "docs", "art", "verification_2026-10-16", "ch2_flow")
os.makedirs(OUT, exist_ok=True)
TAG = SIDE.lower()


def S(c):
    return main_of(story(c)) + " offers=" + lua(c, 'return tostring(game.Players:GetPlayers()[1]:GetAttribute("StoryOffers"))', "Server")


def talk(c, npc, label):
    log(label, "go:", lua(c, GO_TO % npc, "Server"))
    time.sleep(1.8)
    st = lua(c, NPC_STATE % npc, "Client")
    log(label, npc + ":", st)
    k = "G"
    for tok in st.split("key=")[1:]:
        k = tok.split(" ")[0].split("|")[0].strip() or "G"
        break
    key(c, k)
    time.sleep(2.5)
    log(label, "window:", panel_buttons(c)[0], list(panel_buttons(c)[1]), "|", lua(c, WORDS, "Client"))


def accept(c, npc, label, tries=4, want=None):
    """talk until the npc's OFFER window shows (a story page first = read it to its end, then talk again), then [Accept]"""
    for n in range(tries):
        talk(c, npc, label + "#%d" % (n + 1))
        _, b = panel_buttons(c)
        if "OfferAccept" in b or "OfferNext" in b:
            got = press_until(c, label + " ->", ("OfferAccept",))
            time.sleep(1.5)
            log(label, "after Accept:", got, S(c))
            close(c)
            if want and (story(c).get("Main") or {}).get("Id") != want:
                log(label, "accepted something else (not", want + ") - talking again")
                time.sleep(1.0)
                continue
            return got
        log(label, "not an offer window first:", lua(c, WORDS, "Client"))
        for _ in range(5):
            _, b = panel_buttons(c)
            nxt = next((b[x] for x in ("StoryNext", "StoryOk") if x in b), None)
            if not nxt:
                break
            click(c, nxt)
            time.sleep(1.2)
        close(c)
        time.sleep(1.0)
    log(label, "no offer window after", tries, "talks", S(c))
    return None


CLAIM_FIND = r'''
local pg = game.Players.LocalPlayer.PlayerGui
local function shown(d)
	local x = d
	while x and not x:IsA("LayerCollector") do
		if x:IsA("GuiObject") and not x.Visible then return false end
		x = x.Parent
	end
	return x == nil or x.Enabled
end
for _, d in pg:GetDescendants() do
	if d.Name == "Claim" and d:IsA("GuiObject") and shown(d) then
		if d:IsA("GuiButton") then return d:GetFullName() end
		local b = d:FindFirstAncestorWhichIsA("GuiButton")
		if b then return b:GetFullName() end
	end
end
return "none"
'''


def claim(c, label):
    for n in range(4):
        st = story(c)
        m = st.get("Main") or {}
        if not (m.get("Claim") is True):
            return
        time.sleep(2.0)
        ch = lua(c, CLAIM_FIND, "Client")
        log(label, "claim try", n + 1, ch, click(c, ch) if ch != "none" else "")
        time.sleep(2.0)
        close(c)
    log(label, "claim still pending:", main_of(story(c)))


def main():
    c = Client()
    c.start()
    if "--running" not in sys.argv:
        start_play(c)
    try:
        if "--running" not in sys.argv:
            log("0 pick:", pick(c, SIDE), S(c))
        # A. M1_4's last step (back to the townsperson) -> chapter 1 ends
        log("A scene:", scene(c, {"Faction": SIDE, "Class": "Warrior", "Level": 8, "Tutorial": "Done", "Done": ["M1_1", "M1_3"],
                                  "Main": "M1_4:3"}))
        time.sleep(1.5)
        log("A", S(c))
        talk(c, N["m14"], "A1")
        if panel_buttons(c)[0] != "panel=true":
            log("A1 no window on the first G - again")
            talk(c, N["m14"], "A1b")
        for _ in range(6):
            _, b = panel_buttons(c)
            nxt = next((b[n] for n in ("StoryNext", "StoryOk", "OfferNext") if n in b), None)
            if not nxt:
                break
            click(c, nxt)
            time.sleep(1.2)
        close(c)
        time.sleep(1.5)
        st = story(c)
        log("A2 after the talk:", main_of(st))
        claim(c, "A2")
        log("A3 chapter 1 done:", S(c))
        # B. M2_1's giver: '!' + the 'Talk to ...' row + the way marker, then [Accept]
        time.sleep(1.5)
        log("B1", N["m21"] + ":", lua(c, NPC_STATE % N["m21"], "Client"))
        log("B1 rows:", lua(c, FIND_TEXT % json.dumps("Talk to"), "Client"))
        log("B1 marker:", lua(c, MARKER, "Client"))
        shot(c, os.path.join(OUT, f"{TAG}_B1_after_ch1.png"))
        accept(c, N["m21"], "B2", want="M2_1")
        if "--only-ab" in sys.argv:
            return
        # C. M2_3: the offer at Tiny, the fountain, Tiny's line
        log("C scene:", scene(c, {"Done": ["M1_1", "M1_3", "M1_4", "M2_1", "M2_2"]}))
        time.sleep(1.5)
        log("C", S(c))
        log("C1", N["m23"] + ":", lua(c, NPC_STATE % N["m23"], "Client"))
        log("C1 rows:", lua(c, FIND_TEXT % json.dumps("Talk to"), "Client"))
        accept(c, N["m23"], "C2", want="M2_3")
        log("C3 to the fountain:", scene(c, {"At": "Landmark:Fountain"}))
        time.sleep(3)
        log("C3", S(c))
        log("C3 Tiny's line:", lua(c, FIND_TEXT % json.dumps(N["find23"]), "Client"))
        log("C3 Tiny:", lua(c, NPC_STATE % "Tiny", "Client"))
        shot(c, os.path.join(OUT, f"{TAG}_C3_fountain.png"))
        key(c, "G")
        time.sleep(2.5)
        state, b = panel_buttons(c)
        log("C4 G at the fountain:", state, list(b), lua(c, WORDS, "Client"))
        if "StoryChoiceGood" not in b and "StoryNext" not in b:
            close(c)
            talk(c, "Tiny", "C4 (by Tiny)")
        log("C4 words:", lua(c, WORDS, "Client"))
        got = press_until(c, "C4 choice ->", ("StoryChoiceGood",))
        time.sleep(1.5)
        for _ in range(4):
            _, b = panel_buttons(c)
            nxt = next((b[n] for n in ("StoryNext", "StoryOk") if n in b), None)
            if not nxt:
                break
            click(c, nxt)
            time.sleep(1.2)
        close(c)
        log("C5 after the fountain:", got, S(c))
        # D. M2_4: the offer at Tiny, the gold run, Clatter's 'Tools' scene when step 1 ends
        st = story(c)
        if not (st.get("Main") or {}).get("Id") == "M2_4" and "M2_4" not in str(lua(c, 'return tostring(game.Players:GetPlayers()[1]:GetAttribute("StoryOffers"))', "Server")):
            log("D scene:", scene(c, {"Done": ["M1_1", "M1_3", "M1_4", "M2_1", "M2_2", "M2_3"]}))
            time.sleep(1.5)
        log("D", S(c))
        accept(c, N["m24"], "D1", want="M2_4")
        log("D2 field:", scene(c, {"At": "Zone:SlimeMeadow", "Monsters": [{"Kind": "Slime", "N": 10, "Dist": 10, "Anchor": True}]}))
        time.sleep(2)
        seen = False
        for i in range(40):
            r = debug(c, "Scene", "Kill")
            if "no scene monster" in r:
                scene(c, {"Monsters": [{"Kind": "Slime", "N": 10, "Dist": 10, "Anchor": True}]})
                time.sleep(1)
                continue
            time.sleep(0.6)
            m = (story(c).get("Main") or {})
            if i % 5 == 0:
                log("D2 kill", i, r, "->", m.get("Id"), m.get("St"), m.get("P"))
            if m.get("Id") != "M2_4" or (m.get("St") or 1) >= 2:
                log("D2 step 1 done after", i + 1, "kills:", main_of(story(c)))
                break
        for _ in range(10):
            f = lua(c, 'local f = workspace:FindFirstChild("HH_ClatterScene") return tostring(f ~= nil)', "Client")
            if f == "true":
                seen = True
                break
            time.sleep(0.4)
        log("D3 Clatter scene on screen:", seen)
        log("D3 line:", lua(c, FIND_TEXT % json.dumps("carry my tools"), "Client"))
        log("D3 saved flag:", (story(c).get("First") or {}).get("ClatterTools"))
        time.sleep(1.2)
        shot(c, os.path.join(OUT, f"{TAG}_D3_clatter_tools.png"))
        log("D4 to town:", scene(c, {"At": "Npc:" + N["m14"]}))
        time.sleep(3)
        log("D4", S(c))
        close(c)
        console_errors(c)
    finally:
        if not KEEP:
            stop_play(c)
        save_log(os.path.join(OUT, f"{TAG}_log.txt"))


main()
