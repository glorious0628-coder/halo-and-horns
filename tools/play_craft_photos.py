"""③-2 hammer ring photos (게임성 개발 4): own test Play in the practice Studio with a FRESH in-memory save (ServerStorage
StudioFreshSave, Studio only; nothing is saved). Faction / class through the remotes, then the Studio-only practice
session (LocalPlayer attribute CraftPractice = true: no server, graded on the client with CraftMini), photos of the ring
shrinking, a strike (Studio's own input: user_mouse_input on the ring screen in my test Play, no desktop mouse), the
grade word and the result line, probes of the screen's words, the console's errors, then Play stops (finally).
Usage: STUDIO_ID=<UiSandbox id> py tools/play_craft_photos.py [outdir-name]   (own test Play only: 최종 검수 approves first)
Out: docs/art/verification_2026-10-12/craft_ring/<outdir-name or pc>/"""
import base64
import io
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-12", "craft_ring", sys.argv[1] if len(sys.argv) > 1 else "pc")
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
for _, k in { "DataLoaded", "Faction", "Class", "ClassChosen" } do table.insert(out, k .. "=" .. tostring(p:GetAttribute(k))) end
return table.concat(out, " ")
"""

FIRE = r"""
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
R:WaitForChild("%s"):FireServer(%s)
return "fired %s"
"""

PRACTICE = r"""
game:GetService("Players").LocalPlayer:SetAttribute("CraftPractice", true)
return string.format("practice at %.2f", workspace:GetServerTimeNow())
"""

# client: what the ring screen shows now
PROBE = r"""
local HttpService = game:GetService("HttpService")
local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
local root = nil
for _, d in pg:GetDescendants() do if d.Name == "CraftRing" then root = d end end
if not root then return "no ring screen" end
local out = { Words = {}, Dots = {} }
for _, d in root:GetDescendants() do
	if d:IsA("TextLabel") and d.Text ~= "" then table.insert(out.Words, d.Name .. ":" .. d.Text) end
	if string.sub(d.Name, 1, 3) == "Dot" then
		local c = d.BackgroundColor3
		table.insert(out.Dots, string.format("%s=%d,%d,%d", d.Name, c.R * 255, c.G * 255, c.B * 255))
	end
end
local ring = root:FindFirstChild("Ring")
out.Ring = ring and string.format("visible=%s size=%.0f", tostring(ring.Visible), ring.AbsoluteSize.X) or "none"
out.Screen = string.format("%.0fx%.0f", root.AbsoluteSize.X, root.AbsoluteSize.Y)
return HttpService:JSONEncode(out)
"""


def wait_state(c, cond, timeout, every=1.0):
    t0 = time.time()
    last = ""
    while time.time() - t0 < timeout:
        last = lua(c, STATE, "Server")
        if cond(last):
            return last
        time.sleep(every)
    return last


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
        # run 1: photos of the ring shrinking, a strike near the touch, the word, the result
        t0 = time.time()
        note(lua(c, PRACTICE, "Client"))
        time.sleep(max(0, 0.8 + 0.45 - (time.time() - t0)))
        note("probe ring: " + lua(c, PROBE, "Client"))
        save(c, "01_ring_shrinking")
        time.sleep(max(0, 0.8 + 1.2 - 0.15 - (time.time() - t0)))  # the click lands about at the touch
        c.call("user_mouse_input", {"datamodel_type": "Client", "actions": [
            {"action": "moveTo", "instance_path": "LocalPlayer.PlayerGui.MainGui.CraftRing"},
            {"action": "mouseButtonClick", "mouse_button": "left"}]})
        note("probe strike: " + lua(c, PROBE, "Client"))
        save(c, "02_strike_word")
        time.sleep(max(0, 0.8 + 7.4 + 0.5 - (time.time() - t0)))
        note("probe end: " + lua(c, PROBE, "Client"))
        save(c, "03_result")
        time.sleep(2.5)
        note("after: " + lua(c, PROBE, "Client"))
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
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", nil) return "fresh off"', "Edit"))
        os.makedirs(OUT, exist_ok=True)
        with open(os.path.join(OUT, "log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")


if __name__ == "__main__":
    main()
