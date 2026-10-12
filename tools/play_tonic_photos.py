"""연금 물약 화면 photos (게임성 개발 4): own test Play in the practice Studio with a FRESH in-memory save (ServerStorage
StudioFreshSave, Studio only; nothing is saved). The Studio must hold a PHOTO-ONLY sync of this branch with
Config.Features.Tonics switched on in that throwaway tree (never committed). Faction / class through the remotes, the
server's Studio DebugCommand gives tonics; OpenPanel("Bag", { Tab = "Use", Select = "I:<tonic>" }) shows a tonic's detail;
the client fires UseTonic itself (the real BuffService answers: Buff_<id> attributes) so the HUD's buff tiles show (one,
then two), and a third tonic's detail shows the two-at-a-time line. No mouse, no keyboard. Probes + photos, the console's
errors, then Play stops (finally) and the fresh-save flag is cleared.
Usage: STUDIO_ID=<UiSandbox id> py tools/play_tonic_photos.py [outdir-name]   (own test Play only: 최종 검수 approves first)
Out: docs/art/verification_2026-10-12/tonics/<outdir-name or pc>/"""
import base64
import io
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-12", "tonics", sys.argv[1] if len(sys.argv) > 1 else "pc")
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
for _, k in { "DataLoaded", "Faction", "Class", "ClassChosen", "Buff_MightTonic", "Buff_GuardTonic", "Buff_LuckyTonic" } do
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

OPEN = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
R:WaitForChild("OpenPanel"):FireClient(p, %s)
return "open %s"
"""

CLOSE = r"""
local p = game:GetService("Players").LocalPlayer
for _, d in p:FindFirstChildOfClass("PlayerGui"):GetDescendants() do
	if d.Name == "PanelsModal" and d:IsA("Frame") then d.Visible = false end
end
return "closed (client view only)"
"""

PROBE = r"""
local HttpService = game:GetService("HttpService")
local p = game:GetService("Players").LocalPlayer
local pg = p:FindFirstChildOfClass("PlayerGui")
local out = { Words = {}, Cut = {}, Buff = {} }
for _, d in pg:GetDescendants() do
	if d.Name == "BuffBar" and d:IsA("Frame") then
		out.BuffBar = string.format("visible=%s %.0fx%.0f at %.0f,%.0f", tostring(d.Visible), d.AbsoluteSize.X, d.AbsoluteSize.Y,
			d.AbsolutePosition.X, d.AbsolutePosition.Y)
		for _, t in d:GetDescendants() do
			if t:IsA("TextLabel") and t.Text ~= "" then table.insert(out.Buff, t.Name .. ":" .. t.Text) end
		end
	end
end
local modal = nil
for _, d in pg:GetDescendants() do
	if d.Name == "PanelsModal" and d:IsA("Frame") then modal = d end
end
if modal and modal.Visible then
	local win = modal:FindFirstChild("Window")
	for _, d in win:GetDescendants() do
		if d.Name ~= "" and (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and d.Visible
			and d:FindFirstAncestor("Detail") then
			table.insert(out.Words, d.Name .. ":" .. d.Text)
			if d:IsA("TextLabel") and not d.TextFits then table.insert(out.Cut, d.Name .. ":" .. d.Text) end
		end
	end
end
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
        gives = [f'{{ "Item", "{x}" }}' for x in ("MightTonic:3", "GuardTonic:2", "LuckyTonic:1", "WisdomTonic:1")]
        note("debug: " + lua(c, DEBUG % ", ".join(gives), "Server"))
        note(lua(c, OPEN % ('"Bag", { Tab = "Use", Select = "I:MightTonic" }', "bag Might"), "Server"))
        shot(c, "01_bag_tonic_ready")
        note(lua(c, FIRE % ("UseTonic", '"MightTonic"', "UseTonic Might"), "Client"))
        note("after Might: " + wait_state(c, lambda x: "Buff_MightTonic=0" not in x and "Buff_MightTonic=nil" not in x, 10, 0.5))
        shot(c, "02_bag_tonic_running")
        time.sleep(1.2)  # the rate limit (1 s) before the next tonic
        note(lua(c, FIRE % ("UseTonic", '"GuardTonic"', "UseTonic Guard"), "Client"))
        note("after Guard: " + wait_state(c, lambda x: "Buff_GuardTonic=0" not in x and "Buff_GuardTonic=nil" not in x, 10, 0.5))
        note(lua(c, OPEN % ('"Bag", { Tab = "Use", Select = "I:LuckyTonic" }', "bag Lucky"), "Server"))
        shot(c, "03_bag_two_running_third_blocked")
        note(lua(c, CLOSE, "Client"))
        shot(c, "04_hud_two_buff_tiles", 1.0)
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
