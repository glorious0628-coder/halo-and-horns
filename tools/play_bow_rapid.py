"""(tools/play_bow_rapid.py) A23-150 7 (최종 검수 10/13 review, 메인 반영 1): five rapid archer shots in the main Studio test Play
(own Play, fresh save). Halo Archer with the first bow: the Swing remote five times, 0.12 s apart, sampled every frame -
how many times the bow's Handle moves between the hands (RightGrip weld vs the client's BowGrip weld; expected: it goes
left once, stays through the burst, back right after MOTION.BOW_HOLD), the Handle's distance to each hand, how often the
HUD portrait's WorldModel loses / gains children (flicker = rebuilds), plus two photos (mid-burst, after).
Usage: HH_MAIN_STUDIO=1 py tools/play_bow_rapid.py [outdir-name]
Out: docs/art/verification_2026-10-12/main_apply/<outdir>/ (default bow_rapid): bow_*.png, log.txt"""
import base64
import io
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402
from PIL import Image  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-12", "main_apply", sys.argv[1] if len(sys.argv) > 1 else "bow_rapid")
os.makedirs(OUT, exist_ok=True)
LOG = []


def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))


def lua(c, code, dm):
    try:
        return text_of(c.call("execute_luau", {"code": code, "datamodel_type": dm}))
    except Exception as e:  # noqa: BLE001
        return "ERR " + str(e)[:200]


def note(m):
    print(m, flush=True)
    LOG.append(m)


def save(c, name):
    res = c.call("screen_capture", {"capture_id": name})
    for part in res.get("content", []):
        if part.get("type") == "image":
            Image.open(io.BytesIO(base64.b64decode(part["data"]))).convert("RGB").save(os.path.join(OUT, name + ".png"))
            note("saved " + name)
            return
    note("capture failed " + name)


STATE = r"""
local p = game:GetService("Players"):GetPlayers()[1]
if not p then return "no player" end
local out = {}
for _, k in { "DataLoaded", "Faction", "Class", "ClassChosen", "Level", "WeaponTier" } do table.insert(out, k .. "=" .. tostring(p:GetAttribute(k))) end
return table.concat(out, " ")
"""
FIRE = r"""
game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("%s"):FireServer(%s)
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
# one burst of N Swing remotes, sampled each frame; the answer is a summary line
BURST = r"""
local Players = game:GetService("Players")
local p = Players.LocalPlayer
local ch = p.Character
local wm = ch and ch:FindFirstChild("WeaponModel")
local handle = wm and wm:FindFirstChild("Handle")
local rh, lh = ch and ch:FindFirstChild("RightHand"), ch and ch:FindFirstChild("LeftHand")
if not (handle and rh and lh) then return "no bow / hands: wm=" .. tostring(wm and wm.Name) end
local right = rh:FindFirstChild("RightGrip")
local view
for _, d in p.PlayerGui:GetDescendants() do if d.Name == "AvatarPortrait3D" then view = d break end end
local world = view and view:FindFirstChildOfClass("WorldModel")
local ev = { added = 0, removed = 0 }
local conns = {}
if world then
	table.insert(conns, world.ChildAdded:Connect(function() ev.added += 1 end))
	table.insert(conns, world.ChildRemoved:Connect(function() ev.removed += 1 end))
end
local samples, flips, last, leftFrames, rightFrames, maxBoth = 0, 0, nil, 0, 0, 0
local seq = {}
local fire = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Swing")
local t0 = os.clock()
local nextShot, shots = 0, 0
while os.clock() - t0 < %s do
	local t = os.clock() - t0
	if shots < %d and t >= nextShot then
		fire:FireServer()
		shots += 1
		nextShot += %s
	end
	local bg = handle:FindFirstChild("BowGrip")
	local onLeft = bg ~= nil and bg:IsA("JointInstance") and bg.Enabled
	local onRight = right ~= nil and right.Enabled and right.Part1 == handle
	local side = (onLeft and "L" or "") .. (onRight and "R" or "")
	if side == "" then side = "-" end
	if side == "LR" then maxBoth += 1 end
	if side ~= last then
		flips += (last ~= nil) and 1 or 0
		table.insert(seq, string.format("%%s@%%.2f", side, t))
		last = side
	end
	if onLeft then leftFrames += 1 elseif onRight then rightFrames += 1 end
	samples += 1
	task.wait()
end
for _, c in conns do c:Disconnect() end
local welds = 0
for _, d in handle:GetChildren() do if d.Name == "BowGrip" then welds += 1 end end
local dl = (handle.Position - lh.Position).Magnitude
local dr = (handle.Position - rh.Position).Magnitude
return string.format("shots=%%d samples=%%d hand flips=%%d seq=%%s | frames left=%%d right=%%d both=%%d | BowGrip welds=%%d | end dist left=%%.2f right=%%.2f | portrait world=%%s added=%%d removed=%%d",
	shots, samples, flips, table.concat(seq, " "), leftFrames, rightFrames, maxBoth, welds, dl, dr, tostring(world ~= nil), ev.added, ev.removed)
"""
SPAWN_BURST = r"""
task.spawn(function()
	local fire = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Swing")
	for i = 1, 5 do fire:FireServer() task.wait(0.12) end
end)
return "burst started"
"""


def wait_state(c, cond, timeout, every=1.0):
    t0, last = time.time(), ""
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
        time.sleep(26)
        note(lua(c, FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
        wait_state(c, lambda x: "Faction=Halo" in x, 20)
        note(lua(c, FIRE % ("ChooseClass", '"Archer", "M"', "ChooseClass"), "Client"))
        note("chosen: " + wait_state(c, lambda x: "ClassChosen=true" in x, 20))
        note(lua(c, FIRE % ("AcceptTutorial", "", "AcceptTutorial"), "Client"))
        time.sleep(1)
        note("gear: " + lua(c, DEBUG % '{ "Level", 30 }, { "WeaponOwnedMask", 511 }', "Server"))
        time.sleep(2)
        note(lua(c, FIRE % ("EquipWeapon", "3", "EquipWeapon 3"), "Client"))
        time.sleep(3)
        note("state: " + lua(c, STATE, "Server"))
        for label, secs, shots, gap in (("rapid 5 shots 0.12 s", "2.6", 5, "0.12"), ("rapid 5 shots 0.06 s", "2.4", 5, "0.06"), ("single shot", "1.6", 1, "1")):
            note(f"burst [{label}]: " + lua(c, BURST % (secs, shots, gap), "Client"))
            time.sleep(1.5)
        note(lua(c, SPAWN_BURST, "Client"))
        time.sleep(0.35)
        save(c, "bow_mid_burst")
        time.sleep(0.2)
        save(c, "bow_mid_burst2")
        time.sleep(2.5)
        save(c, "bow_after")
        con = text_of(c.call("get_console_output", {}))
        errs = [ln for ln in con.splitlines() if any(k in ln.lower() for k in ("error", "failed", "infinite yield")) and "DataStore" not in ln]
        note("console errors (DataStore notes left out): " + "\n".join(errs[-30:]))
        note("portrait warnings: " + "\n".join(ln for ln in con.splitlines() if "ortrait" in ln)[-1500:])
    finally:
        try:
            c.call("start_stop_play", {"is_start": False})
            note("play stopped")
        except Exception as e:  # noqa: BLE001
            note("stop failed " + str(e))
        time.sleep(2)
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh kept on"', "Edit"))
        with open(os.path.join(OUT, "log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")


if __name__ == "__main__":
    main()
