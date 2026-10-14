"""A23-156 offline test (user 10/13): the private test server's switch. The real Config.luau loaded with engine doubles:
Config.TestServer (Enabled, Skills = { ZEnabled = true } only, GooseEvery 600, PassSales) and Config.ApplyTestServer()
(once; Z on while X / PvPZX stay off, Goose.Schedule.Every 600 with the KST offset kept, the PassSales switch default;
Enabled = false = the real rules). Static: Main.server.luau calls Config.ApplyTestServer() right after requiring Config and
before Net.CreateAll / the service lists; Net.GameStateDefaults.PrivateServer = false and Net.CreateAll sets it from
game.PrivateServerId (게임성 개발 1 10/13: the client cannot read it). ClientMain's own call (게임성 개발 1) is reported as a
finding only.
Status "passed" only when the fixture and the static checks pass AND every mutation was applied and caught.
Report: docs/art/verification_2026-10-13/offline_test_server_2026-10-13.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
MAIN = ROOT / "src/ServerScriptService/Main.server.luau"
NET = ROOT / "src/ReplicatedStorage/Shared/Net.luau"
CLIENT = ROOT / "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau"
FIXTURE = ROOT / "tools/fixtures/test_server_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-13/offline_test_server_2026-10-13.json"

APPLY_LINE = "Config.ApplyTestServer() -- A23-156"
PRIVATE_SET = 'gs:SetAttribute("PrivateServer", okP and type(privateId) == "string" and privateId ~= "")'

# (name, source, exact text, replacement)
MUTATIONS = [
    ("the switch off", "CONFIG", "Config.TestServer = {\n\tEnabled = true,", "Config.TestServer = {\n\tEnabled = false,"),
    ("X turned on too", "CONFIG", "Skills = { ZEnabled = true },", "Skills = { ZEnabled = true, XEnabled = true },"),
    ("Z on players too", "CONFIG", "Skills = { ZEnabled = true },", "Skills = { ZEnabled = true, PvPZX = true },"),
    ("the goose stays every 4 hours", "CONFIG", "\t\tConfig.Goose.Schedule.Every = math.floor(every)\n", ""),
    ("the goose every 60 s", "CONFIG", "\tGooseEvery = 600,", "\tGooseEvery = 60,"),
    ("applied twice", "CONFIG", "if type(T) ~= \"table\" or T.Enabled ~= true or T.Applied == true then return false end",
     "if type(T) ~= \"table\" or T.Enabled ~= true then return false end"),
    ("the sales value ignored", "CONFIG", "defs.PassSales.Default = T.PassSales == true", "defs.PassSales.Default = true"),
    ("on the Live game too", "CONFIG", '\tif type(Config.EnvName) == "function" and Config.EnvName() == "Live" then return false end\n', ""),
    # (the moved client words, Config.ClientText, now sit between ApplyTestServer and the module's end)
    ("applied by Config itself", "CONFIG", "\n\nreturn Config\n", "\nConfig.ApplyTestServer()\n\nreturn Config\n"),
    ("Main never applies", "MAIN", APPLY_LINE, "-- A23-156"),
    ("Main applies after Net.CreateAll", "MAIN",
     APPLY_LINE + ": the private test server's settings (Config.TestServer), before any service reads them\nNet.CreateAll()",
     "Net.CreateAll()\n" + APPLY_LINE + ": the private test server's settings (Config.TestServer), before any service reads them"),
    ("no PrivateServer default", "NET", "\tPrivateServer = false,\n", ""),
    ("PrivateServer never set", "NET", "\t" + PRIVATE_SET + "\n", ""),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(config: str, name: str):
    path = ROOT / f"build/test_server_offline{name}.luau"
    path.write_text("local CONFIG_SOURCE = " + lua_str(config) + "\n" + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"TEST_SERVER_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def static(main: str, net: str):
    fails = []
    req = main.find('local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))')
    call = main.find(APPLY_LINE)
    create = main.find("\nNet.CreateAll()")
    init = main.find("local INIT_ORDER")
    if not (0 <= req < call and 0 <= call < create and call < init):
        fails.append("STATIC_FAIL Main.server.luau calls Config.ApplyTestServer() right after requiring Config, before "
                     "Net.CreateAll and the service lists")
    defaults = net[net.find("Net.GameStateDefaults = {"):net.find("function Net.CreateAll()")]
    if "\tPrivateServer = false,\n" not in defaults:
        fails.append("STATIC_FAIL Net.GameStateDefaults.PrivateServer = false")
    body = net[net.find("function Net.CreateAll()"):net.find("function Net.Get(")]
    if PRIVATE_SET not in body or "pcall(function() return game.PrivateServerId end)" not in body \
            or body.find(PRIVATE_SET) > body.find("gs.Parent = ReplicatedStorage"):
        fails.append("STATIC_FAIL Net.CreateAll sets PrivateServer from game.PrivateServerId (pcall) before GameState is shown")
    return fails


def main():
    src = {"CONFIG": CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n"),
           "MAIN": MAIN.read_text(encoding="utf-8-sig").replace("\r\n", "\n"),
           "NET": NET.read_text(encoding="utf-8-sig").replace("\r\n", "\n")}
    ok, checks, fails, result = run(src["CONFIG"], "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    sfails = static(src["MAIN"], src["NET"])
    for line in sfails:
        print(line)
    client = CLIENT.read_text(encoding="utf-8-sig") if CLIENT.exists() else ""
    calls = re.search(r"\bConfig\.ApplyTestServer\b", client) is not None  # Config.ApplyTestServer() or pcall(Config.ApplyTestServer)
    finding = ("ClientMain calls Config.ApplyTestServer" if calls
               else "ClientMain does not call Config.ApplyTestServer() yet (게임성 개발 1's line): the client reads Z off")
    print("FINDING " + finding)
    rows = []
    for name, key, old, new in MUTATIONS:
        applied = src[key].count(old) == 1
        caught, why = False, []
        if applied:
            mut = dict(src)
            mut[key] = src[key].replace(old, new)
            if key == "CONFIG":
                m_ok, _, why, _ = run(mut["CONFIG"], "_mut")
                caught = not m_ok
            else:
                why = static(mut["MAIN"], mut["NET"])
                caught = len(why) > 0
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    passed = ok and not sfails and all(r["applied"] and r["caught"] for r in rows)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails + sfails, "finding": finding,
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in (CONFIG, MAIN, NET)},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "contract": __doc__.split("Status")[0].strip(),
              "limitations": "Data and source text only: the goose schedule itself is tools/test_golden_egg.py (its Every = 600 "
                             "world), the Z skill is tools/test_skills.py (ZEnabled worlds); the client call is 게임성 개발 1's."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
