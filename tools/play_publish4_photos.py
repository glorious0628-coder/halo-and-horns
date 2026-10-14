"""publish4 HUD photos in the MAIN Studio (메인 반영 1, 2026-10-14; HH_MAIN_STUDIO=1 STUDIO_ID=<id>; fresh in-memory save):
crown-war bar (nothing under it, time inside), goose chip, goal chip (3 rows), outlaw chip (attribute Outlaw, this Play only),
attendance window with 28 days (AttendDays, this Play only). PC or `phone` (device emulation restored at the end).
Out: docs/art/verification_2026-10-14/publish4/<dev>_*.png + crops + log_<dev>.txt"""
import os, sys, time
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import play_first_look_photos as plp  # noqa: E402
from studio_mcp import Client  # noqa: E402
from PIL import Image  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-14", "publish4")
LOG = []
plp.OUT, plp.LOG = OUT, LOG
lua, note, save = plp.lua, plp.note, plp.save
OPEN = 'game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("OpenPanel"):FireClient(game:GetService("Players"):GetPlayers()[1], "%s") return "open %s"'
ATTR = 'local p = game:GetService("Players"):GetPlayers()[1] %s return "attrs set"'
TEXTS = r'''
local out = {}
local mg = game:GetService("Players").LocalPlayer.PlayerGui.MainGui
for _, d in mg:GetDescendants() do
	if d:IsA("TextLabel") and d.Visible and d.Text ~= "" and d.AbsolutePosition.Y < 330 and d.AbsolutePosition.X < 1400 then
		table.insert(out, string.format("%s='%s' bounds(%d,%d) abs(%d,%d) size(%d,%d)", d.Name, d.Text, d.TextBounds.X, d.TextBounds.Y,
			d.AbsolutePosition.X, d.AbsolutePosition.Y, d.AbsoluteSize.X, d.AbsoluteSize.Y))
	end
end
return table.concat(out, "\n")
'''


def crop(name, box):
    p = os.path.join(OUT, name + ".png")
    if os.path.exists(p):
        im = Image.open(p)
        w, h = im.size
        b = (int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h))
        im.crop(b).resize(((b[2] - b[0]) * 2, (b[3] - b[1]) * 2), Image.LANCZOS).save(os.path.join(OUT, name + "_crop.png"))


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    os.makedirs(OUT, exist_ok=True)
    dev = "phone" if "phone" in sys.argv[1:] else "pc"
    c = Client(); c.start()
    try:
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
        plp.wait_state(c, lambda x: "ClassChosen=true" in x, 20)
        note(lua(c, plp.FIRE % ("AcceptTutorial", "", "AcceptTutorial"), "Client"))
        time.sleep(2); note(lua(c, plp.CLAIMED, "Server")); time.sleep(5)
        note("hud texts:\n" + lua(c, TEXTS, "Client"))
        save(c, f"{dev}_01_hud"); crop(f"{dev}_01_hud", (0.30, 0.0, 0.62, 0.22))
        note(lua(c, ATTR % 'p:SetAttribute("Outlaw", true)', "Server")); time.sleep(2.5)
        note("outlaw texts:\n" + lua(c, TEXTS, "Client"))
        save(c, f"{dev}_02_outlaw"); crop(f"{dev}_02_outlaw", (0.25, 0.0, 0.75, 0.25))
        note(lua(c, ATTR % 'p:SetAttribute("Outlaw", false) p:SetAttribute("AttendDays", 27) p:SetAttribute("AttendReady", true)', "Server")); time.sleep(1)
        note(lua(c, OPEN % ("Attendance", "Attendance"), "Server")); time.sleep(3)
        save(c, f"{dev}_03_attendance28")
        con = plp.text_of(c.call("get_console_output", {}))
        errs = [l for l in con.splitlines() if any(k in l.lower() for k in ("error", "failed", "infinite yield")) and "DataStore" not in l and "publish this place" not in l]
        note("console errors: " + (" || ".join(errs[-15:]) if errs else "0"))
    finally:
        try:
            c.call("start_stop_play", {"is_start": False}); note("play stopped")
        except Exception as e:  # noqa: BLE001
            note("stop failed " + str(e))
        if dev == "phone":
            time.sleep(3); note("device: " + lua(c, plp.RESTORE, "Edit"))
        with open(os.path.join(OUT, f"log_{dev}.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")


if __name__ == "__main__":
    main()
