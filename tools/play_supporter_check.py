"""Supporter board check (SPEC A23-75; 검수 2026-10-08 12:25: one board at the crossroads fountain plaza, opposite the
bounty board, not blocking pads / roads / stalls, facing the fountain, gold) in the main Studio.
Edit (pc only): two shots of Map.Decor.Crossroads3D.X_SupporterBoard (tools/worldkit/supporter_board_place.luau).
Own test Play with a FRESH in-memory save: the client (SupporterBoard.luau) draws SupporterGui on the tagged
SupporterFace; an empty list shows the plain thank-you line; a test list set on the server's GameState attribute
SupporterNames (this test Play only - nothing is saved) shows in rows of three; 30 names still fit; no button on the
board. Captures + probes; the attribute goes back and Play stops in finally (device back to default).
Usage: py tools/play_supporter_check.py pc|phone   Out: docs/art/verification_2026-10-08/supporter_board/<mode>/"""
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
OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-08", "supporter_board", MODE)
LOG = []
psc.OUT, psc.LOG = OUT, LOG
pcc.OUT = OUT

SEVEN = ["LunaStar", "Mika_99", "BraveToast", "Kai", "PixelPanda", "SunnyDays", "Rowan"]
THIRTY = SEVEN + ["CaptainNoodle", "Hana", "ZoeTheBrave", "Milo", "StarlightSam", "Ivy_2014", "Jun", "TacoKnight",
                  "Pip", "AuroraWings", "Bo", "MossyMushroom", "Nia", "Dash", "ThisNameIsWayTooLongToFit", "Kiko",
                  "Ollie", "RubyRaccoon", "Tess", "Gale", "Yuna", "Finn", "Lark"]
EMPTY = "Thank you for playing!"

# client: every tagged board's gui, as JSON
BOARD = r"""
local CS = game:GetService("CollectionService")
local out = { Boards = {} }
for _, part in CS:GetTagged("SupporterBoard") do
	local gui = part:FindFirstChild("SupporterGui")
	local names = gui and gui:FindFirstChild("Names", true)
	local title = gui and gui:FindFirstChild("Title", true)
	local buttons = 0
	if gui then
		for _, d in gui:GetDescendants() do
			if d:IsA("GuiButton") then buttons += 1 end
		end
	end
	table.insert(out.Boards, {
		Pos = { part.Position.X, part.Position.Y, part.Position.Z }, Size = { part.Size.X, part.Size.Y },
		Look = { part.CFrame.LookVector.X, part.CFrame.LookVector.Z },
		Gui = gui ~= nil, Face = gui and gui.Face.Name or "", Sizing = gui and gui.SizingMode.Name or "",
		PPS = gui and gui.PixelsPerStud or 0, Canvas = gui and { gui.AbsoluteSize.X, gui.AbsoluteSize.Y } or { 0, 0 },
		Title = title and title.Text or "", Text = names and names.Text or "", Fits = names and names.TextFits or false,
		Buttons = buttons,
	})
end
return game:GetService("HttpService"):JSONEncode(out)
"""
# server: the test list on GameState (this Play only)
SRV_NAMES = r"""
local gs = game:GetService("ReplicatedStorage"):WaitForChild("GameState")
if gs:GetAttribute("HH_TestSupporterPrev") == nil then
	gs:SetAttribute("HH_TestSupporterPrev", gs:GetAttribute("SupporterNames") or "")
end
gs:SetAttribute("SupporterNames", %s)
return "SupporterNames = " .. string.sub(tostring(gs:GetAttribute("SupporterNames")), 1, 60)
"""
SRV_BACK = r"""
local gs = game:GetService("ReplicatedStorage"):WaitForChild("GameState")
local prev = gs:GetAttribute("HH_TestSupporterPrev")
if prev ~= nil then
	gs:SetAttribute("SupporterNames", prev ~= "" and prev or nil)
	gs:SetAttribute("HH_TestSupporterPrev", nil)
end
return "SupporterNames back"
"""


def rows(names):
    return "\n".join("    ".join(names[i:i + 3]) for i in range(0, len(names), 3))


def board(c):
    raw = psc.lua(c, BOARD, "Client")
    try:
        found = json.loads(raw or "{}").get("Boards", [])
    except ValueError:
        psc.note("board probe: " + raw[:300])
        return None
    psc.note("board: " + json.dumps(found, ensure_ascii=False)[:600])
    return found[0] if found else None


def set_names(c, names):
    value = "nil" if names is None else json.dumps("\n".join(names))
    psc.note(psc.lua(c, SRV_NAMES % value, "Server"))
    time.sleep(1.0)


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
            pcc.edit_shot(c, "00_edit_front", [21, 10, -21], [36, 7, -36])
            pcc.edit_shot(c, "00_edit_plaza", [-10, 16, 10], [36, 6, -36])
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
        b = board(c)
        results["the tagged face gets SupporterGui on its Front face"] = bool(b and b["Gui"] and b["Face"] == "Front")
        if not b:
            return
        px, py_, pz = b["Pos"]
        lx, lz = b["Look"]
        w, h = b["Size"]
        cw, ch = b["Canvas"]
        results["the canvas keeps the face's shape (PixelsPerStud 40)"] = (
            b["Sizing"] == "PixelsPerStud" and ch > 0 and abs(cw / ch - w / h) < 0.05)
        # 1) whatever the server lists now (dev2 has not filled SupporterNames yet -> the thank-you line)
        set_names(c, None)
        b = board(c)
        results["no supporters -> the plain thank-you line"] = bool(b and b["Text"] == EMPTY)
        results["no button on the board (no pressure)"] = bool(b and b["Buttons"] == 0)
        pcc.stand(c, px + lx * 13, pz + lz * 13, px, pz)
        time.sleep(1.2)
        psc.save(c, "01_board_empty")
        # 2) seven names
        set_names(c, SEVEN)
        b = board(c)
        results["seven names in rows of three"] = bool(b and b["Text"] == rows(SEVEN))
        psc.save(c, "02_board_seven")
        # 3) thirty names (a very long one is cut)
        set_names(c, THIRTY)
        b = board(c)
        results["thirty names, the long one cut, the text fits"] = bool(
            b and b["Text"].count("\n") == 9 and "ThisNameIsWayTooLong…" in b["Text"] and b["Fits"])
        psc.save(c, "03_board_thirty")
        # 4) from the fountain: the board is in sight
        set_names(c, SEVEN)
        pcc.stand(c, 6, -6, px, pz)
        time.sleep(1.2)
        psc.save(c, "04_from_fountain")
        con = psc.text_of(c.call("get_console_output", {}))
        errs = [ln for ln in con.splitlines() if any(k in ln.lower() for k in ("error", "failed", "infinite yield"))
                and "DataStore" not in ln]
        psc.note("console: " + "\n".join(errs[-20:]))
        results["no SupporterBoard error in the console"] = not any("SupporterBoard" in ln for ln in errs)
    finally:
        try:
            psc.note(psc.lua(c, SRV_BACK, "Server"))
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
