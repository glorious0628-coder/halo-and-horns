"""A23-9 IntroSeen: run current Config/Net/DataService/QuestService offline and statically check every writer.

Contract: IntroSeen is a saved, mirrored flag that only the server sets, once, through the zero-argument remote
"IntroSeen" (QuestService.onIntroSeen, rate limited); any argument is rejected; clients never write it.
No Studio, network or live DataStore calls. Usage: py tools/test_intro_seen.py
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
FILES = {
    "CONFIG_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
    "NET_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Net.luau",
    "DATA_SOURCE": ROOT / "src/ServerScriptService/DataService.luau",
    "QUEST_SOURCE": ROOT / "src/ServerScriptService/QuestService.luau",
}
INTRO = ROOT / "src/StarterPlayer/StarterPlayerScripts/Intro.luau"
FIXTURE = ROOT / "tools/fixtures/intro_seen_offline.luau"
OUT = ROOT / "docs/art/verification_2026-10-06/offline_intro_seen_2026-10-06.json"


def quote_lua(value: str) -> str:
    eq = "===="
    while f"]{eq}]" in value:
        eq += "="
    return f"[{eq}[{value}]{eq}]"


def static_checks() -> tuple[int, list[str]]:
    """Every source that mentions IntroSeen: only QuestService's server SetStat writes it; the client fires with no args."""
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    writers = []
    write = re.compile(r'(SetStat\([^)]*"IntroSeen"|SetAttribute\(\s*"IntroSeen"|(?<!RateLimits)\.IntroSeen\s*=[^=]|\["IntroSeen"\]\s*=[^=])')
    for path in sorted((ROOT / "src").rglob("*.luau")):
        text = path.read_text(encoding="utf-8-sig")
        for match in write.finditer(text):
            line = text.count("\n", 0, match.start()) + 1
            writers.append(f"{path.relative_to(ROOT).as_posix()}:{line}")
    quest = FILES["QUEST_SOURCE"].read_text(encoding="utf-8-sig")
    check(len(writers) == 1 and writers[0].startswith("src/ServerScriptService/QuestService.luau:"),
          f"IntroSeen must have exactly one writer (QuestService SetStat); found {writers}")
    check('S.PlayerService.SetStat(player, "IntroSeen", true)' in quest, "QuestService does not set IntroSeen through SetStat")
    check('Net.Get("IntroSeen").OnServerEvent:Connect(onIntroSeen)' in quest, "IntroSeen remote is not handled by QuestService")
    handler = re.search(r"local function onIntroSeen\(player, \.\.\.\)(.*?)\nend\n", quest, re.S)
    check(handler is not None and 'select("#", ...) ~= 0' in handler.group(1), "onIntroSeen does not reject arguments")
    intro = INTRO.read_text(encoding="utf-8-sig")
    fires = re.findall(r'Net\.Get\("IntroSeen"\):FireServer\(([^)]*)\)', intro)
    check(fires == [""], f"client must fire IntroSeen exactly once with no arguments; found {fires}")
    check('not state.Replay and player:GetAttribute("IntroSeen") ~= true' in intro,
          "client fires IntroSeen on menu replays or after it is already saved")
    client_writes = [w for w in writers if w.startswith("src/StarterPlayer/")]
    check(not client_writes, f"client code writes IntroSeen: {client_writes}")
    # A23-74 (user 2026-10-07: "프롤로그 3d 영상도 무슨 위아래 까만색"): no letterbox at all, PC and phone; the subtitle
    # keeps contrast over the open 3D view with the UIKit dark-world text rim, and stays in the device-safe IntroGui
    bars = [name for name in ("IntroBars", "BARS", "state.Bars", '"TopBar"', '"BottomBar"') if name in intro]
    check(not bars, f"the opening still draws letterbox bars: {bars}")
    black = re.findall(r"BackgroundColor3[^\n]*Color3\.new\(0, 0, 0\)", intro)
    check(not black, f"the opening still makes black frames: {black}")
    check('pcall(UIKit.StyleText, sub, "Title")' in intro,
          "the subtitle has no UIKit Title rim (unreadable over the bright sky without the bars)")
    check('sub:FindFirstChild("StyleStroke")' in intro and "{ Transparency = 0 }" in intro,
          "say() does not fade the subtitle rim in with its text (UIKit contract: tween StyleStroke with TextTransparency)")
    check("gui.IgnoreGuiInset, gui.ResetOnSpawn, gui.DisplayOrder = true, false, 60" in intro
          and "gui.ScreenInsets" not in intro,
          "the subtitle / skip ScreenGui left the device-safe area (IgnoreGuiInset, no ScreenInsets None)")
    check("local CROWN_SHOT = { Down = math.rad(25), Side = math.rad(30)" in intro
          and "look(crown + dir * c.To, crown), 5.5)" in intro,
          "the first shot does not show the crown front three-quarter (25 deg below, 30 deg to the side)")
    return count, failures


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    binary = ROOT / "build/luau_cli_0_741/luau.exe"
    compiler = binary.with_name("luau-compile.exe")
    if not binary.is_file() or not compiler.is_file():
        print("Installed Luau CLI missing; this test never downloads tools.", file=sys.stderr)
        return 1
    raw = {key: path.read_bytes() for key, path in FILES.items()}
    harness = ROOT / "build/intro_seen_offline_test.luau"
    harness.parent.mkdir(exist_ok=True)
    # normalize CRLF (editor line endings) before embedding
    text = {key: raw[key].decode("utf-8-sig").replace("\r\n", "\n") for key in FILES}
    harness.write_text("\n".join(f"local {key} = {quote_lua(text[key])}" for key in FILES)
                       + "\n" + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    compiled = subprocess.run([str(compiler), *(str(p) for p in FILES.values()), str(INTRO), str(FIXTURE)], cwd=ROOT,
                              stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, encoding="utf-8",
                              errors="replace", timeout=60)
    result = subprocess.run([str(binary), str(harness)], cwd=ROOT, capture_output=True,
                            text=True, encoding="utf-8", errors="replace", timeout=60)
    static_count, static_failures = static_checks()
    print(result.stdout, end="")
    print(compiled.stderr + result.stderr, end="")
    for message in static_failures:
        print(f"STATIC_FAILURE {message}")
    marker = re.search(r"INTRO_SEEN_OFFLINE_OK checks=(\d+) Studio/API calls=0", result.stdout)
    changed = [p.relative_to(ROOT).as_posix() for key, p in FILES.items() if p.read_bytes() != raw[key]]
    ok = compiled.returncode == 0 and result.returncode == 0 and marker and not static_failures and not changed
    report = {
        "status": "passed" if ok else "failed",
        "checks": int(marker[1]) if marker else 0,
        "staticChecks": static_count,
        "staticFailures": static_failures,
        "failure": None if marker else (result.stderr.strip().splitlines() or ["no output"])[0],
        "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(raw[key]).hexdigest() for key, p in FILES.items()},
        "introSHA256": hashlib.sha256(INTRO.read_bytes()).hexdigest(),
        "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(),
        "sourcesChangedDuringRun": changed,
        "studioCalls": 0, "networkCalls": 0,
        "coverage": ["Net registry has one IntroSeen; default false; mirrored",
                     "remote with any argument (incl. explicit nil, false, extra args) rejected before the rate limit",
                     "unready and rate-limited (1 s per player) requests rejected",
                     "a client attribute is not the saved flag",
                     "zero-argument remote sets IntroSeen exactly once via SetStat, mirrored, survives save/reload, never rewritten",
                     "tutorial/quest/claim/reroll/vacation remotes never write IntroSeen",
                     "corrupt saved values (string/number/table) load as unseen",
                     "static: the only writer in src/ is QuestService SetStat; client Intro.luau fires once, no args, not on replay"],
        "limitations": "Offline store and scheduler doubles; the client opening itself, skip/replay UI and live reconnect are not certified here.",
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if ok else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(f"IntroSeen offline check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
