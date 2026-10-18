"""손맛 G2 check with a network lag (최종 검수 10/17): in MY test Play (STUDIO_ID = PhoneTest_1015) beside slimes, per class
(Warrior, Archer, Mage; Halo T1) 6 single presses at lag 0, then the same at Studio IncomingReplicationLag 0.15 s:
press -> the first damage number (ms) via feel_logger.luau (workspace.HH_FeelLog). G2 = the number stays near the body's
contact frame (Warrior 230 / Archer ~370 / Mage ~440 ms) with the lag; without G2 it would come ~150 ms later.
A photo at the contact moment per class x lag. The lag goes back to 0 at the end, even after an error.
Usage: STUDIO_ID=... py lag1017.py [--running]"""
import json, os, re, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from h1016 import Client, log, save_log, lua, key, shot, debug, scene, start_play, pick, stop_play, close, GAME  # noqa: E402
from measure_common import FACE_SLIME  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(GAME, "docs", "art", "verification_2026-10-17", "lag_feel")
os.makedirs(OUT, exist_ok=True)
LOGGER = open(os.path.join(HERE, "feel_logger.luau"), encoding="utf-8").read()
CONTACT = {"Warrior": 230, "Archer": 370, "Mage": 440}


def set_lag(c, v):
    for dm in ("Edit", "Client", "Server"):
        r = lua(c, "local ok, e = pcall(function() settings().Network.IncomingReplicationLag = %s end) return tostring(ok) .. ' ' .. tostring(e)" % v, dm)
        log("  lag", v, dm, r[:60])


def read_log(c):
    raw = lua(c, 'local l = workspace:FindFirstChild("HH_FeelLog") return l and l.Value or ""', "Client")
    rows = []
    for line in raw.splitlines():
        m = re.match(r"([\d.]+) (\S+) ?(.*)", line)
        if m:
            rows.append((float(m[1]), m[2], m[3]))
    return rows


def first_num_ms(rows):
    out = []
    presses = [t for t, k, _ in rows if k == "press"]
    for i, t in enumerate(presses):
        nxt = presses[i + 1] if i + 1 < len(presses) else t + 2
        nums = [tt for tt, k, _ in rows if k == "num" and t < tt < nxt]
        out.append(round((nums[0] - t) * 1000) if nums else None)
    return out


def run_class(c, cls, lag, res):
    log("==", cls, "lag", lag, debug(c, "Class", cls))
    time.sleep(2.5)
    close(c)
    lua(c, LOGGER, "Client")
    for i in range(6):
        log("  ", lua(c, FACE_SLIME, "Server"))
        time.sleep(0.5)
        key(c, "F")
        if i == 2:
            time.sleep(CONTACT[cls] / 1000)
            shot(c, os.path.join(OUT, f"{cls}_lag{int(lag * 1000)}.png"))
        time.sleep(1.4)
    ms = first_num_ms(read_log(c))
    vals = [v for v in ms if v is not None]
    res.append({"class": cls, "lag": lag, "press_to_number_ms": ms,
                "median": sorted(vals)[len(vals) // 2] if vals else None, "contact_ms": CONTACT[cls]})
    log("  ", json.dumps(res[-1]))


def main():
    c = Client()
    c.start()
    if "--running" not in sys.argv:
        start_play(c)
        log("pick:", pick(c, "Halo", "Warrior"))
    res = []
    try:
        log("scene", scene(c, {"Faction": "Halo", "Class": "Warrior", "Level": 30, "Tutorial": "Done",
                               "Done": ["M1_1", "M1_2", "M1_3", "M1_4"], "At": "Zone:SlimeMeadow"}))
        time.sleep(3)
        close(c)
        debug(c, "WeaponOwnedMask", 7)
        debug(c, "WeaponTier", 1)
        for lag in (0, 0.15):
            set_lag(c, lag)
            time.sleep(1.0)
            for cls in ("Warrior", "Archer", "Mage"):
                try:
                    run_class(c, cls, lag, res)
                except Exception as e:  # noqa: BLE001
                    log("  failed", cls, lag, str(e)[:200])
    finally:
        set_lag(c, 0)
        with open(os.path.join(OUT, "lag_feel.json"), "w", encoding="utf-8") as f:
            json.dump(res, f, ensure_ascii=False, indent=1)
        save_log(os.path.join(OUT, "log.txt"))
        stop_play(c)


if __name__ == "__main__":
    main()
