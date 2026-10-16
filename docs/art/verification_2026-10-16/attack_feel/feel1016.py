"""Basic-attack feel measurements (계획 5번 D) in MY test Studio (STUDIO_NAME=PhoneTest_1015). Per class: fresh save,
skip the intro, Halo + the class, a tier-2 weapon (Debug), next to slimes; a client logger records press / swing / fx /
HurtSeq / damage number / beaten / XP; presses go in by Studio MCP virtual keys (F), never the OS mouse or keyboard.
Usage: py feel1016.py [Warrior Mage Archer] [--bare]"""
import json, os, re, sys, time
GAME = r"C:\\Users\\glori\\Documents\\Roblox\\Game"
sys.path.insert(0, os.path.join(GAME, "tools"))
from studio_mcp import Client  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(GAME, "docs", "art", "verification_2026-10-16", "attack_feel")
os.makedirs(OUT, exist_ok=True)
LOGGER = open(os.path.join(HERE, "feel_logger.luau"), encoding="utf-8").read()
PACKMODE = "false"
INTERVAL = {"Warrior": 1.0, "Mage": 1.1, "Archer": 0.5, "Bare": 0.8}


def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))


def lua(c, code, dm):
    try:
        return text_of(c.call("execute_luau", {"code": code, "datamodel_type": dm}))
    except Exception as e:  # noqa: BLE001
        return "ERR " + str(e)[:300]


def keys(c, actions):
    try:
        return text_of(c.call("user_keyboard_input", {"actions": actions, "datamodel_type": "Client"}))
    except Exception as e:  # noqa: BLE001
        return "ERR " + str(e)[:300]


STATE = r'''
local p = game:GetService("Players"):GetPlayers()[1]
if not p then return "no player" end
return tostring(p:GetAttribute("DataLoaded")) .. " " .. tostring(p:GetAttribute("Faction")) .. " " .. tostring(p:GetAttribute("Class")) .. " " .. p.Name
'''
SETUP = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local dbg = game.ServerScriptService:FindFirstChild("DebugCommand")
local out = {}
for _, kv in { { "Level", 3 }, { "WeaponTier", %d } } do
	table.insert(out, kv[1] .. "=" .. tostring(dbg and dbg:Invoke(p.Name, kv[1], kv[2])))
end
return table.concat(out, " ") .. " tier=" .. tostring(p:GetAttribute("WeaponTier"))
'''
GO = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if not hrp then return "no char" end
local best, bd = nil, math.huge
local live = {}
for _, m in workspace.Monsters:GetChildren() do
	local r = m.PrimaryPart
	if r and not r.Anchored and m:GetAttribute("MonsterKind") == "Slime" and m:GetAttribute("OwnerUserId") == nil then
		table.insert(live, m)
	end
end
local PACK = %s
for _, m in live do
	local r = m.PrimaryPart.Position
	local score = (r - hrp.Position).Magnitude
	if PACK then
		local n = 0
		for _, o in live do if o ~= m and (o.PrimaryPart.Position - r).Magnitude <= 10 then n += 1 end end
		score = -n * 1000 + score
	end
	if score < bd then best, bd = m, score end
end
if not best then return "none" end
local r = best.PrimaryPart.Position
local stand = %s
local from = r + Vector3.new(0, 0, stand)
hrp.CFrame = CFrame.lookAt(Vector3.new(from.X, r.Y + 2.5, from.Z), Vector3.new(r.X, r.Y + 2.5, r.Z))
return string.format("score %%.0f stand %%s", bd, tostring(stand))
'''
READ = 'local v = workspace:FindFirstChild("HH_FeelLog") return v and v.Value or "-"'


def press_pattern(gap_ms, n):
    acts = []
    for _ in range(n):
        acts.append({"action": "keyPress", "key_code": "F"})
        acts.append({"action": "wait", "wait_time_ms": gap_ms})
    return acts


def analyse(raw, label):
    ev = []
    for line in raw.splitlines():
        m = re.match(r"([\d.]+) (\S+) ?(.*)", line)
        if m:
            ev.append((float(m[1]), m[2], m[3]))
    presses = [t for t, k, _ in ev if k == "press"]
    rows = []
    for i, t in enumerate(presses):
        nxt = presses[i + 1] if i + 1 < len(presses) else t + 3

        def first(kinds, cond=lambda d: True):
            for tt, k, d in ev:
                if t <= tt < nxt and k in kinds and cond(d):
                    return round((tt - t) * 1000)
            return None
        rows.append({"whoosh_ms": first(("whoosh",)), "swing_ms": first(("swing",)), "swing_src": next((d.split()[0] for tt, k, d in ev if t <= tt < nxt and k == "swing"), None), "fx_ms": first(("fx",)), "hurt_ms": first(("hurt",)),
                     "num_ms": first(("num",))})
    return {"label": label, "presses": len(presses), "rows": rows,
            "hurts": sum(1 for _, k, _ in ev if k == "hurt"), "beaten": sum(1 for _, k, _ in ev if k == "beaten"),
            "events": len(ev)}


def median(xs):
    xs = sorted(x for x in xs if x is not None)
    return xs[len(xs) // 2] if xs else None


def run_class(c, cls, bare):
    res = {"class": cls, "bare": bare}
    print(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh"', "Edit"))
    c.call("start_stop_play", {"is_start": True})
    try:
        t0 = time.time()
        while time.time() - t0 < 90:
            s = lua(c, STATE, "Server")
            if s.startswith("true"):
                break
            time.sleep(1.5)
        print("loaded", s)
        time.sleep(2.2)
        keys(c, [{"action": "keyPress", "key_code": "Return"}])  # skip the opening
        time.sleep(2)
        print(lua(c, 'local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes") R:WaitForChild("ChooseFaction"):FireServer("Halo") task.wait(2.5) R:WaitForChild("ChooseClass"):FireServer("%s", "M") task.wait(2.5) return "picked"' % cls, "Client"))
        print(lua(c, SETUP % (0 if bare else 2), "Server"))
        time.sleep(1.5)
        stand = {"Warrior": 6, "Mage": 18, "Archer": 16}[cls] if not bare else 5
        print(lua(c, GO % (PACKMODE, stand), "Server"))
        time.sleep(1.5)
        print(lua(c, LOGGER, "Client"))
        iv = INTERVAL["Bare" if bare else cls]
        # A1 / A2: single presses well apart
        for _ in range(6):  # each press next to a live slime (a tier-2 weapon beats one in 2 hits)
            lua(c, GO % (PACKMODE, stand), "Server")
            time.sleep(0.4)
            keys(c, [{"action": "keyPress", "key_code": "F"}])
            time.sleep(iv + 0.6)
        single = lua(c, READ, "Client")
        res["single"] = analyse(single, "single")
        res["single_raw"] = single
        # A3: a fast burst (8 presses 120 ms apart): how many became hits
        print(lua(c, LOGGER, "Client"))
        print(lua(c, GO % (PACKMODE, stand), "Server"))
        time.sleep(1.2)
        print("burst", keys(c, press_pattern(120, 8))[:80])
        time.sleep(2.0)
        braw = lua(c, READ, "Client")
        res["burst"] = analyse(braw, "burst")
        res["burst_raw"] = braw
        # 15: slimes beaten in ~40 s of steady pressing (re-placed next to the nearest slime every 8 s)
        print(lua(c, LOGGER, "Client"))
        t1 = time.time()
        while time.time() - t1 < 40:  # two presses per placement (a slime takes about 2)
            lua(c, GO % (PACKMODE, stand), "Server")
            keys(c, press_pattern(int(iv * 1000) + 50, 2))
        sraw = lua(c, READ, "Client")
        res["steady"] = analyse(sraw, "steady")
        res["steady_raw"] = sraw
        res["steady"]["seconds"] = round(time.time() - t1, 1)
    finally:
        try:
            c.call("start_stop_play", {"is_start": False})
        except Exception as e:  # noqa: BLE001
            print("stop", e)
        time.sleep(3)
    s = res.get("single", {}).get("rows", [])
    res["summary"] = {"whoosh_ms": median([r["whoosh_ms"] for r in s]), "swing_ms": median([r["swing_ms"] for r in s]), "fx_ms": median([r["fx_ms"] for r in s]),
                      "hurt_ms": median([r["hurt_ms"] for r in s]), "num_ms": median([r["num_ms"] for r in s]),
                      "burst_presses": res.get("burst", {}).get("presses"), "burst_hurts": res.get("burst", {}).get("hurts"),
                      "steady_beaten": res.get("steady", {}).get("beaten"), "steady_s": res.get("steady", {}).get("seconds")}
    print(cls, "bare" if bare else "", json.dumps(res["summary"]))
    return res


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    bare = "--bare" in sys.argv
    global PACKMODE
    PACKMODE = "true" if "--pack" in sys.argv else "false"
    c = Client()
    c.start()
    out = []
    for cls in args or ["Warrior", "Mage", "Archer"]:
        out.append(run_class(c, cls, bare))
    name = "feel_%s%s_%s.json" % ("bare" if bare else "armed", "_pack" if PACKMODE == "true" else "", "_".join(args or ["all"]))
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
        json.dump(out, f, indent=1, ensure_ascii=False)
    print("saved", name)


main()
