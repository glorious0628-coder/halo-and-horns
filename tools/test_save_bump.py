"""The save-version bump is ready (게시 준비 운영 ④, 게임성 개발 2, 2026-10-15), static.

The next bump (v7: the Adventure Club's Guild / GuildInventory, docs/design/party_guild_2026-10-15.md) must not be half done.
Checks on the CURRENT sources:
  * Config.Data.Version == Config.Data.Defaults.Version (a fresh record is the newest format)
  * DataService.migrate has one `if (tonumber(d.Version) or 1) < N then ... d.Version = N end` step for every N in 2..Version,
    in order (a bump without its step would save new-format data under the old number)
  * loadLocked refuses a newer record without writing or locking it (the CR-L3 guard, return nil inside UpdateAsync) and the
    player is kicked rather than given a blank save (Load returns nil -> the LoadFailed kick)
  * tools/fixtures/onboarding_offline.luau runs the real refusal for Version + 1 (the newer-record loop names it) and pins the
    current Version (so a bump has to touch the offline proof too)
No Studio, no Luau run. The two-server rehearsal on the Beta place is a checklist step (docs/design/launch_ops_checklist.md).

Usage: py tools/test_save_bump.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
DATA = ROOT / "src/ServerScriptService/DataService.luau"
ONBOARD = ROOT / "tools/fixtures/onboarding_offline.luau"


def problems(config: str, data: str, onboard: str) -> tuple[int, list[str]]:
    out: list[str] = []
    m = re.search(r"^Config\.Data\s*=\s*\{(.*?)^\}", config, re.M | re.S)
    body = m.group(1) if m else ""
    vm = re.search(r"^\tVersion\s*=\s*(\d+)", body, re.M)
    version = int(vm.group(1)) if vm else 0
    dm = re.search(r"\bDefaults\s*=\s*\{.*?\bVersion\s*=\s*(\d+)", body, re.S)
    if not version:
        out.append("Config.Data.Version not found")
    if not dm or int(dm.group(1)) != version:
        out.append(f"Config.Data.Defaults.Version ({dm.group(1) if dm else '?'}) is not Config.Data.Version ({version})")
    mig = re.search(r"local function migrate\(d, player\)(.*?)\nend\n", data, re.S)
    steps = [int(n) for n in re.findall(r"if \(tonumber\(d\.Version\) or 1\) < (\d+) then", mig.group(1))] if mig else []
    if steps != list(range(2, version + 1)):
        out.append(f"migrate steps {steps} are not 2..{version} in order (a bump needs its own step)")
    if mig:
        for n in range(2, version + 1):
            if not re.search(rf"\bd\.Version = {n}\b", mig.group(1)):
                out.append(f"migrate step < {n} never sets d.Version = {n}")
    guard = re.search(r"if type\(old\) == \"table\" and \(tonumber\(old\.Version\) or 1\) > Config\.Data\.Version then"
                      r"\s*tooNew, storedVersion = true, old\.Version\s*locked, captured = false, nil\s*return nil", data)
    if not guard:
        out.append("loadLocked has no CR-L3 guard (a newer record returns nil inside UpdateAsync: no write, no lock)")
    if not re.search(r"if tooNew then.*?return nil", data, re.S):
        out.append("a refused newer record does not end the load with nil (the LoadFailed kick)")
    if f"cfg.Data.Version == {version}" not in onboard:
        out.append(f"onboarding_offline.luau does not pin Config.Data.Version == {version}")
    loop = re.search(r"for _, version in \{([\d, ]+)\} do\s*local newer", onboard)
    if not loop or str(version + 1) not in [s.strip() for s in loop.group(1).split(",")]:
        out.append(f"onboarding_offline.luau's newer-record refusal does not try Version {version + 1}")
    return version, out


MUTATIONS = [
    ("data", "\tif (tonumber(d.Version) or 1) < 7 then\n", "\tif (tonumber(d.Version) or 1) < 77 then\n"),
    ("data", "\t\td.Version = 7\n", "\t\td.Version = 6\n"),
    ("config", "\n\tVersion = 7,", "\n\tVersion = 8,"),
    ("data", "\t\t\t\treturn nil\n\t\t\tend\n\t\t\tif not final and", "\t\t\tend\n\t\t\tif not final and"),
    ("onboard", "for _, version in { 8, 99 } do", "for _, version in { 99 } do"),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    src = {"config": CONFIG.read_text(encoding="utf-8-sig"), "data": DATA.read_text(encoding="utf-8-sig"),
           "onboard": ONBOARD.read_text(encoding="utf-8-sig")}
    version, out = problems(src["config"], src["data"], src["onboard"])
    for p in out:
        print("BUMP_FAIL " + p)
    print(f"SAVEBUMP version={version} failures={len(out)}")
    caught = 0
    for key, old, new in MUTATIONS:
        if src[key].count(old) != 1:
            print(f"MUTATION NOT APPLIED {key}: {old.strip()[:50]}")
            continue
        bad = dict(src)
        bad[key] = src[key].replace(old, new)
        hit = len(problems(bad["config"], bad["data"], bad["onboard"])[1]) > len(out)
        caught += 1 if hit else 0
        print(("MUTATION caught  " if hit else "MUTATION MISSED ") + f"{key}: {old.strip()[:50]}")
    print(f"MUTATIONS caught={caught}/{len(MUTATIONS)}")
    ok = not out and caught == len(MUTATIONS)
    print(f"SAVEBUMP {'passed' if ok else 'failed'}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
