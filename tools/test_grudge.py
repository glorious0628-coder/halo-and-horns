"""Grudge sack (A), P3 grudge mail (B) and the A23-18 ghost hold (C), run offline (735419e + review fixes 08d6f44).

Runs the CURRENT Config, Net (remote names), Util, GrudgeService and PlayerService.PairReady (extracted) sources,
injected into tools/fixtures/grudge_offline.luau, with the installed official Luau CLI (build/luau_cli_0_741).
No Studio, network, DataStore or Roblox API calls: Players, the grudge-mail DataStore (in memory, with failure
modes), task (a clock-driven scheduler) and the pay / notice sinks are doubles. Every check is named and collected.

Runs:
  1. "real": the repository sources as they are. This run decides pass / fail.
  2. "patched": a temporary copy of GrudgeService with the SRC_PATCHES fixes applied (never src/), so the rules behind
     a crashing src bug are still verified. Only made while SRC_PATCHES match the source.
  3. mutations: in-memory copies of the (patched) GrudgeService with one rule broken each, run from a temporary
     directory; each must make at least one check fail that passes on its baseline.

Usage: py tools/test_grudge.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/offline_grudge_2026-10-06.json
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tools/fixtures/grudge_offline.luau"
OUT = ROOT / "docs/art/verification_2026-10-06/offline_grudge_2026-10-06.json"
GRUDGE_REL = "src/ServerScriptService/GrudgeService.luau"
FILES = {
    "CONFIG_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
    "NET_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Net.luau",
    "UTIL_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Util.luau",
    "GRUDGE_SOURCE": ROOT / GRUDGE_REL,
    # only PlayerService.PairReady is extracted (make_harness); the whole file is hashed and read by the static checks
    "PLAYER_SOURCE": ROOT / "src/ServerScriptService/PlayerService.luau",
}
EXTRACTED_ONLY = ("PLAYER_SOURCE",)
STATIC_ONLY = {
    "GHOST_CLIENT": ROOT / "src/StarterPlayer/StarterPlayerScripts/GrudgeGhost.luau",
    "CLIENT_MAIN": ROOT / "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau",
    "SERVER_MAIN": ROOT / "src/ServerScriptService/Main.server.luau",
    "VISUALS": ROOT / "src/ServerScriptService/CharacterVisuals.luau",
    "PVP": ROOT / "src/ServerScriptService/PvPService.luau",
    "COMBAT": ROOT / "src/ServerScriptService/CombatService.luau",
    "PROGRESSION": ROOT / "src/ServerScriptService/ProgressionService.luau",
}

# Real src bugs that stop the offline run from reaching the rest of the rules: (name, report, [(old, new), ...]).
# The real run still decides pass / fail; the patched copy only lets the other rules be verified.
# Remove an entry once src/ is fixed (the runner reports a patch that no longer matches).
SRC_PATCHES = [
]

# (name, exact text, replacement) in the mutation baseline GrudgeService: each must match exactly once
MUTATIONS = [
    # sound_gaps B2 (검수 2026-10-07): the refund Fx names the one who stole, never the avenger
    ("the refund Fx names the avenger as the thief", "Thief = thief.UserId, Refund = true })",
     "Thief = killer.UserId, Refund = true })"),
    ("avenge always pays 100%",
     "local refund = math.floor(entry.Amount * (bonusOk and G.AvengeRefundRate or G.ReturnRate))",
     "local refund = math.floor(entry.Amount * G.ReturnRate)"),
    ("avenge refund bonus ignores the per-victim cooldown",
     "local bonusOk = pairReady(victim, 0, \"refund\", G.RefundBonusCooldown)", "local bonusOk = true"),
    ("avenger bonus every time",
     "if pairReady(killer, 0, \"avenge\", Config.PvP.PairRewardCooldown) then", "if true then"),
    ("Neutral killer avenges",
     "S.FactionService.GetFaction(killer) == \"Halo\"", "S.FactionService.GetFaction(killer) ~= \"Horns\""),
    ("countdown ticks outside PvP zones",
     "if not S.ZoneService.IsPvPZone(thief) then", "if false then"),
    ("dead carrier keeps ticking",
     "if not Util.IsAlive(thief) then\n\t\treturn\n\tend", "if false then\n\t\treturn\n\tend"),
    ("server hitch not clamped",
     "math.clamp(tonumber(elapsed) or Config.Grudge.Tick, 0, MAX_TICK_STEP)", "math.max(tonumber(elapsed) or Config.Grudge.Tick, 0)"),
    ("new steal keeps the running countdown",
     "sack.Remaining = math.max(sack.Remaining, Config.Grudge.SackSeconds + sack.Held)",
     "sack.Remaining = sack.Remaining > 0 and sack.Remaining or Config.Grudge.SackSeconds + sack.Held"),
    ("new steal drops the held seconds",
     "sack.Remaining = math.max(sack.Remaining, Config.Grudge.SackSeconds + sack.Held)",
     "sack.Remaining = Config.Grudge.SackSeconds"),
    ("Returned refunds across a rebirth",
     "if victim and sameLife(victim, entry) then\n\t\t\tlocal amount", "if victim then\n\t\t\tlocal amount"),
    ("Returned pays 120%",
     "local amount = math.floor(entry.Amount * Config.Grudge.ReturnRate)",
     "local amount = math.floor(entry.Amount * Config.Grudge.AvengeRefundRate)"),
    ("rebirth does not reset the older share",
     "entry.Amount = 0 -- the older share", "entry.Amount = entry.Amount -- the older share"),
    ("CanSteal ignores the resteal window",
     "return pairReady(victim, thief.UserId, \"steal\", Config.Grudge.RestealWindow, false)", "return true"),
    ("leaving thief is paid",
     "if sacks[player] then\n\t\treturnSack(player, false)", "if sacks[player] then\n\t\tpay(player, sacks[player])"),
    ("Paid adds no infamy",  # BB10: the stat goes through PlayerService.GrantFame (+ the sack's fair RankInfamy)
     "S.PlayerService.GrantFame(thief, \"Infamy\", sack.Infamy, { RankPoints = sack.RankInfamy or 0 })",
     "local _ = sack.Infamy"),
    ("no mail on Returned",
     "MAIL.Send(userId, entry, \"Returned\", sack.Id .. \":Returned\")", "local _ = entry"),
    ("no mail on Avenged",
     "MAIL.Send(userId, entry, \"Avenged\", sack.Id .. \":Avenged\")", "local _ = entry"),
    ("present victims get mail too",
     "elseif not victim then\n\t\t\tMAIL.Send(userId, entry, \"Avenged\"", "end\n\t\tdo\n\t\t\tMAIL.Send(userId, entry, \"Avenged\""),
    ("other-life present victims get mail",
     "elseif not victim then\n\t\t\tMAIL.Send(userId, entry, \"Returned\"", "else\n\t\t\tMAIL.Send(userId, entry, \"Returned\""),
    ("mailbox keeps more than MailMax",
     "while #out > Config.Grudge.MailMax do",
     "while #out > Config.Grudge.MailMax + 5 do"),
    ("mailbox drops the newest letter",
     "\t\tlocal drop = 1\n",
     "\t\tlocal drop = #out\n"),
    ("letter kind lost", "K = kind, T = os.time()", "K = \"Avenged\", T = os.time()"),
    ("letter rebirths lost", "R = tonumber(entry.Rebirths) or 0", "R = 0"),
    ("letter without its Id", "{ Id = letterId, A = amount", "{ A = amount"),
    ("mail key without the M_ prefix (send)",
     "store.UpdateAsync, store, \"M_\" .. tostring(userId)", "store.UpdateAsync, store, \"M\" .. tostring(userId)"),
    ("retried send appends the same letter again",
     "if type(m) == \"table\" and m.Id == letterId then return nil end", "if false then return nil end"),
    ("mail send never retried",
     "\t\tfor attempt = 1, 4 do\n\t\t\tif not store then break end",
     "\t\tfor attempt = 1, 1 do\n\t\t\tif not store then break end"),
    ("mail retry without the back-off wait",
     "(\"grudge mail send %d/4 failed: %s\"):format(attempt, tostring(err)))\n\t\t\tif attempt < 4 then task.wait(2 ^ (attempt - 1)) end",
     "(\"grudge mail send %d/4 failed: %s\"):format(attempt, tostring(err)))\n\t\t\tif attempt < 4 then task.wait(0) end"),
    ("MailPending never goes down", "\t\tMAIL.Pending -= 1", "\t\tMAIL.Pending -= 0"),
    ("MailPending not counted",
     "\tMAIL.Pending += 1\n\ttask.spawn(function()",
     "\tMAIL.Pending += 0\n\ttask.spawn(function()"),
    ("mailbox not cleared at join",
     "if #letters == 0 then return nil end\n\t\treturn keep",
     "if #letters == 0 then return nil end\n\t\treturn old"),
    ("empty mailbox written at join", "if #letters == 0 then return nil end", "if #letters == 0 then return {} end"),
    ("mailbox read without canPay", "if not store or not canPay(victim) then return end", "if not store then return end"),
    ("victim who left is still paid",
     "\tif not canPay(victim) then\n\t\tMAIL.WriteBack(store, key, letters)",
     "\tif false then\n\t\tMAIL.WriteBack(store, key, letters)"),
    ("taken letters not written back",
     "\t\tMAIL.WriteBack(store, key, letters)\n\t\treturn",
     "\t\treturn"),
    ("write-back not capped",
     "\t\t\treturn tidy(list)\n\t\tend)\n\t\tif ok then return end",
     "\t\t\treturn list\n\t\tend)\n\t\tif ok then return end"),
    ("write-back puts new letters first",
     "if type(m) == \"table\" and (m.Id == nil or not ids[m.Id]) then table.insert(list, m) end",
     "if type(m) == \"table\" and (m.Id == nil or not ids[m.Id]) then table.insert(list, 1, m) end"),
    ("write-back failure not warned",
     "Util.Warn(TAG, (\"grudge mail write-back %d/4 failed: %s\")",
     "print((\"grudge mail write-back %d/4 failed: %s\")"),
    ("store failure not warned", "Util.Warn(TAG, \"grudge mail store unavailable: \"", "print(\"grudge mail store unavailable: \""),
    ("taken letter leaves no tombstone",
     "if m.Id ~= nil then table.insert(keep, { Id = m.Id, Done = true, T = os.time() }) end -- tombstone",
     "-- (no tombstone)"),
    ("mail ignores sameLife",
     "if amount > 0 and not seen[id] and (tonumber(m.R) or 0) == rebirths then",
     "if amount > 0 and not seen[id] then"),
    ("mail bonus ignores the refund cooldown",
     "and not bonusUsed and pairReady(victim, 0, \"refund\", Config.Grudge.RefundBonusCooldown) then", "and not bonusUsed then"),
    ("every mailed Avenged letter gets 120%",
     "if m.K == \"Avenged\" and not bonusUsed and pairReady(victim, 0, \"refund\", Config.Grudge.RefundBonusCooldown) then",
     "if m.K == \"Avenged\" then"),
    ("Returned letters can get the bonus", "if m.K == \"Avenged\" and not bonusUsed", "if m.K ~= nil and not bonusUsed"),
    ("mail paid with a wrong source",
     "S.ProgressionService.AddBankGold(victim, total, \"Refund\")", "S.ProgressionService.AddBankGold(victim, total, \"Mail\")"),
    ("mail notice per letter",
     "\t\t\ttotal += math.floor(amount * rate)",
     "\t\t\ttotal += math.floor(amount * rate)\n\t\t\tnotify(victim, fmt(\"GrudgeMail\", \"x\"), \"good\")"),
    ("ghost hold accepts arguments", "if select(\"#\", ...) ~= 0 or not isPlaying(victim)", "if not isPlaying(victim)"),
    ("ghost hold by a dead victim", "if not Util.IsAlive(victim) then return end", "if false then return end"),
    ("ghost hold without the rate limit",
     "if not Util.RateLimit(victim, \"GhostHold\", Config.RateLimits.GhostHold or Config.Grudge.HoldCooldown) then return end",
     "if false then return end"),
    ("ghost hold rate limit = the 3 s client cooldown",
     "Config.RateLimits.GhostHold or Config.Grudge.HoldCooldown", "Config.Grudge.HoldCooldown"),
    ("ghost hold without readiness check",
     "or not S.PlayerService.IsReady(victim) then return end", "then return end"),
    ("ghost hold without the +10 s cap", "local room = G.HoldMaxSeconds - (sack.Held or 0)", "local room = math.huge"),
    ("ghost hold ignores the room left", "local add = math.min(G.HoldAddSeconds, room)", "local add = G.HoldAddSeconds"),
    ("ghost hold across a rebirth", "if not entry or not sameLife(victim, entry) then", "if not entry then"),
    ("ghost hold for anyone pointing at the thief",
     "local entry = sack and sack.Entries[victim.UserId]",
     "local entry = sack and (sack.Entries[victim.UserId] or { Rebirths = victim:GetAttribute(\"Rebirths\") })"),
    ("stale hold does not fix the button", "pointVictim(victim) -- stale target", "local _ = victim -- stale target"),
    ("ghost hold not published", "sack.Remaining += add\n\tpublish(thief, sack)", "sack.Remaining += add"),
    ("ghost glow never switched off",
     "and thief:GetAttribute(\"SackHeldUntil\") == glowUntil then thief:SetAttribute(\"SackHeldUntil\", 0) end",
     "and false then thief:SetAttribute(\"SackHeldUntil\", 0) end"),
    ("older glow timer switches off a newer glow",
     "and thief:GetAttribute(\"SackHeldUntil\") == glowUntil then", "then"),
    ("ghost hold tells the thief nothing", "\tnotify(thief, fmt(\"GhostHeld\"), \"bad\", \"None\")\n", "\tlocal _ = thief\n"),
    ("the victim's press line back (A23-130)", "\tnotify(thief, fmt(\"GhostHeld\"), \"bad\", \"None\")\n",
     "\tnotify(victim, fmt(\"GhostHoldOk\", add, G.HoldMaxSeconds), \"good\")\n\tnotify(thief, fmt(\"GhostHeld\"), \"bad\", \"None\")\n"),
    ("AddToSack does not set the hold target",
     "victim:SetAttribute(\"GrudgeThiefId\", thief.UserId) -- A23-18", "local _ = thief -- A23-18"),
    ("closeSack hides the button instead of moving it",
     "if v then pointVictim(v) end", "if v then v:SetAttribute(\"GrudgeThiefId\", 0) end"),
    ("closeSack leaves the button", "if v then pointVictim(v) end", "local _ = v"),
    ("pointVictim counts thieves who left",
     "if entry and isPlaying(thief) and sameLife(victim, entry)", "if entry and sameLife(victim, entry)"),
    ("pointVictim ignores sameLife",
     "if entry and isPlaying(thief) and sameLife(victim, entry)", "if entry and isPlaying(thief)"),
    ("rebirth does not move the button",
     "S.ProgressionService.Rebirthed:Connect(function(player) pcall(pointVictim, player) end)", "local _ = pointVictim"),
    ("rejoin does not restore the hold target",
     "pointVictim(player) -- a rejoin on THIS server", "local _ = player -- a rejoin on THIS server"),
    ("closeSack keeps the glow", "if isPlaying(thief) then thief:SetAttribute(\"SackHeldUntil\", 0) end", ""),
]


def literal(value: str) -> str:
    eq = "===="
    while "]" + eq + "]" in value:
        eq += "="
    return "[" + eq + "[" + value + "]" + eq + "]"


def function_block(text: str, start: str) -> str:
    """`start` up to and including the first top-level `end` line after it (a whole function)."""
    first = text.find(start)
    last = text.find("\nend\n", first) if first >= 0 else -1
    if first < 0 or last < 0:
        raise ValueError(f"Source boundary changed: {start!r}; update the test extractor.")
    return text[first:last + 5]


def make_harness(sources: dict[str, str]) -> str:
    bindings = {key: value for key, value in sources.items() if key not in EXTRACTED_ONLY}
    pair = function_block(sources["PLAYER_SOURCE"], "function PlayerService.PairReady(")
    bindings["PAIR_READY_SOURCE"] = ("local PlayerService = {}\nlocal S, PAIR, prunePairCD, loopWarn = ...\n" + pair
                                     + "\nreturn PlayerService")
    head = "\n".join(f"local {key} = {literal(value)}" for key, value in bindings.items())
    return head + "\n" + FIXTURE.read_text(encoding="utf-8")


def run_harness(binary: Path, harness_text: str, directory: Path, name: str) -> dict:
    path = directory / name
    path.write_text(harness_text, encoding="utf-8")
    proc = subprocess.run([str(binary), str(path)], cwd=ROOT, capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=600)
    result = None
    for line in proc.stdout.splitlines():
        if line.startswith("GRUDGE_RESULT_JSON "):
            result = json.loads(line[len("GRUDGE_RESULT_JSON "):])
    return {"returncode": proc.returncode, "stdout": proc.stdout, "stderr": proc.stderr, "result": result}


def failing_keys(result: dict | None) -> set[str]:
    if not result:
        return set()
    return {f"{n['Group']} :: {n['Name']}" for n in result.get("Named", []) if n.get("Fail", 0) > 0}


def apply_patches(text: str) -> tuple[str, list[dict]]:
    applied = []
    for name, report, edits in SRC_PATCHES:
        hits = [text.count(old) for old, _ in edits]
        if all(h == 1 for h in hits):
            for old, new in edits:
                text = text.replace(old, new, 1)
            applied.append({"bug": name, "report": report, "applied": True})
        else:
            applied.append({"bug": name, "report": report, "applied": False,
                            "note": f"patch text matched {hits} times: fixed in src or changed; update SRC_PATCHES"})
    return text, applied


# Roblox engine globals the standalone analyzer does not know (not bugs)
ROBLOX_GLOBALS = {
    "game", "workspace", "script", "plugin", "shared", "task", "Enum", "Instance", "Vector3", "Vector2", "CFrame", "Color3",
    "UDim", "UDim2", "Rect", "TweenInfo", "Ray", "RaycastParams", "OverlapParams", "NumberRange", "NumberSequence",
    "NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint", "BrickColor", "Random", "DateTime", "Font",
    "PhysicalProperties", "Region3", "Axes", "Faces", "typeof", "warn", "tick", "time", "wait", "delay", "spawn", "elapsedTime",
}


def unknown_globals(analyzer: Path, path: Path) -> list[str]:
    """luau-analyze on GrudgeService alone: an UnknownGlobal (other than a Roblox engine global) is a name used before
    its local declaration or never declared."""
    if not analyzer.is_file():
        return ["luau-analyze missing"]
    proc = subprocess.run([str(analyzer), str(path)], cwd=ROOT, capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=120)
    out = []
    for line in (proc.stdout + proc.stderr).splitlines():
        m = re.search(r"\((\d+),(\d+)\): \w+: Unknown global '(\w+)'", line)
        if m and m.group(3) not in ROBLOX_GLOBALS:
            out.append(f"GrudgeService.luau:{m.group(1)}:{m.group(2)} unknown global '{m.group(3)}'")
    return out


def static_checks(sources: dict[str, str], analyzer: Path) -> tuple[int, list[str], list[str]]:
    """Wiring the offline GrudgeService run cannot reach (the server rules themselves are run above)."""
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    globals_found = unknown_globals(analyzer, FILES["GRUDGE_SOURCE"])
    check(not globals_found, "luau-analyze: GrudgeService uses no unknown globals (every local is declared before use): "
          + "; ".join(globals_found))
    read = {key: path.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for key, path in STATIC_ONLY.items()}
    ghost = read["GHOST_CLIENT"]
    check('Net.Get("GhostHold"):FireServer()' in ghost,
          "GrudgeGhost client fires GhostHold with no arguments (the server refuses any argument)")
    check('GetAttribute("GrudgeThiefId")' in ghost and 'GetAttributeChangedSignal("GrudgeThiefId")' in ghost,
          "GrudgeGhost shows the hold button from the server attribute GrudgeThiefId")
    check("Config.Grudge.HoldCooldown" in ghost, "GrudgeGhost client cooldown reads Config.Grudge.HoldCooldown")
    check(re.search(r'GhostButton\s*=', sources["CONFIG_SOURCE"]) is not None
          and re.search(r'GhostWait\s*=', sources["CONFIG_SOURCE"]) is not None,
          "Config.Text has the client button texts GhostButton / GhostWait")
    check('"GrudgeGhost"' in read["CLIENT_MAIN"], "ClientMain loads GrudgeGhost")
    check(read["SERVER_MAIN"].count('"GrudgeService"') >= 2, "Main.server lists GrudgeService in both module lists")
    check('SackHeldUntil' in read["VISUALS"], "CharacterVisuals draws the hold glow from SackHeldUntil")
    pvp = read["PVP"]
    can, add = pvp.find("S.GrudgeService.CanSteal(killer, victim)"), pvp.find("S.GrudgeService.AddToSack(killer, victim")
    check(0 <= can < add, "PvPService checks GrudgeService.CanSteal before AddToSack")
    check("S.GrudgeService.OnCarrierDown" in read["COMBAT"], "CombatService death pipeline calls GrudgeService.OnCarrierDown")
    check("M.Rebirthed = Util.Signal.new()" in read["PROGRESSION"] and "M.Rebirthed:Fire(player" in read["PROGRESSION"],
          "ProgressionService.Rebirthed exists and fires with the player first (GrudgeService re-points the hold button)")
    player = sources["PLAYER_SOURCE"]
    mirror = player.find("for _, key in Config.Data.Mirrored do")
    ready = player.find("PlayerService.PlayerReady:Fire(player, data)")
    check(0 <= mirror < ready, "PlayerService mirrors attributes (Rebirths) before PlayerReady (MAIL.Receive reads Rebirths)")
    check('{ "Grudge", "RefundBonusCooldown" }' in player,
          "PlayerService keeps PairCD refund:0 at least RefundBonusCooldown (PAIR.KeepFrom)")
    check("MailPending" in player and "BindToClose" in player,
          "PlayerService BindToClose waits for GrudgeService.MailPending() (in-flight letters)")
    check(re.search(r'"Rebirths"', sources["CONFIG_SOURCE"]) is not None, "Rebirths is a mirrored attribute in Config.Data")
    return count, failures, globals_found


def summarize(result: dict | None) -> dict:
    named = result.get("Named", []) if result else []
    failing = [n for n in named if n.get("Fail", 0) > 0]
    return {
        "checks": result.get("Checks", 0) if result else 0,
        "failedChecks": result.get("Failed", 0) if result else 0,
        "namedChecks": len(named),
        "namedChecksFailing": len(failing),
        "failing": [{"group": n["Group"], "check": n["Name"], "failures": n["Fail"], "passes": n["Pass"],
                     "firstFailure": n.get("FirstFailure")} for n in failing],
    }


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", type=Path, default=ROOT / "build/luau_cli_0_741/luau.exe")
    parser.add_argument("--no-mutations", action="store_true")
    args = parser.parse_args()
    binary = args.luau.resolve()
    compiler = binary.with_name("luau-compile" + binary.suffix)
    analyzer = binary.with_name("luau-analyze" + binary.suffix)
    if not binary.is_file() or not compiler.is_file():
        print("Installed Luau CLI missing; this test never downloads tools.", file=sys.stderr)
        return 1
    raw = {key: path.read_bytes() for key, path in FILES.items()}
    sources = {key: value.decode("utf-8-sig").replace("\r\n", "\n") for key, value in raw.items()}
    fixture_raw = FIXTURE.read_bytes()

    compiled = subprocess.run([str(compiler), str(FILES["CONFIG_SOURCE"]), str(FILES["UTIL_SOURCE"]),
                               str(FILES["GRUDGE_SOURCE"]), str(FIXTURE)], cwd=ROOT,
                              stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True,
                              encoding="utf-8", errors="replace", timeout=120)
    static_count, static_failures, globals_found = static_checks(sources, analyzer)
    patched_text, patches = apply_patches(sources["GRUDGE_SOURCE"])
    patched_any = any(p["applied"] for p in patches)

    with tempfile.TemporaryDirectory(prefix="grudge_offline_") as tmp:
        tmpdir = Path(tmp)
        real_run = run_harness(binary, make_harness(sources), tmpdir, "grudge_real.luau")
        base_sources = sources
        patched_run = None
        if patched_any:
            base_sources = dict(sources)
            base_sources["GRUDGE_SOURCE"] = patched_text
            patched_run = run_harness(binary, make_harness(base_sources), tmpdir, "grudge_patched.luau")
        base_run = patched_run or real_run
        baseline = failing_keys(base_run["result"])
        mutations = []
        if not args.no_mutations:
            jobs = []
            for name, old, new in MUTATIONS:
                hits = base_sources["GRUDGE_SOURCE"].count(old)
                if hits != 1:
                    mutations.append({"mutation": name, "file": GRUDGE_REL, "applied": False,
                                      "caught": False, "note": f"pattern matched {hits} times; update MUTATIONS"})
                    continue
                mutated = dict(base_sources)
                mutated["GRUDGE_SOURCE"] = base_sources["GRUDGE_SOURCE"].replace(old, new, 1)
                jobs.append((name, make_harness(mutated)))

            def work(index_job):
                index, (name, text) = index_job
                out = run_harness(binary, text, tmpdir, f"grudge_mutant_{index:02d}.luau")
                new_fail = sorted(failing_keys(out["result"]) - baseline)
                crashed = out["result"] is None
                return {"mutation": name, "file": GRUDGE_REL, "applied": True,
                        "caught": crashed or bool(new_fail), "crashed": crashed,
                        "newFailingChecks": new_fail[:6], "newFailingCount": len(new_fail)}

            with ThreadPoolExecutor(max_workers=6) as pool:
                mutations.extend(pool.map(work, enumerate(jobs)))

    changed = [p.relative_to(ROOT).as_posix() for key, p in FILES.items() if p.read_bytes() != raw[key]]
    if FIXTURE.read_bytes() != fixture_raw:
        changed.append(FIXTURE.relative_to(ROOT).as_posix())
    real = summarize(real_run["result"])
    patched = summarize(patched_run["result"]) if patched_run else None
    real_ok = (real_run["result"] is not None and real["namedChecksFailing"] == 0
               and re.search(r"GRUDGE_OFFLINE_OK checks=(\d+) Studio/API calls=0", real_run["stdout"]) is not None)
    patched_ok = patched_run is not None and patched_run["result"] is not None and patched["namedChecksFailing"] == 0
    caught = sum(1 for m in mutations if m.get("caught"))
    applied = sum(1 for m in mutations if m.get("applied"))
    mutations_ok = all(m.get("applied") and m.get("caught") for m in mutations)
    # the analyzer's unknown global IS the patched bug: it does not count as an extra harness failure
    other_static = [m for m in static_failures if not (m.startswith("luau-analyze") and patched_any)]
    harness_ok = compiled.returncode == 0 and not other_static and not changed and mutations_ok
    if harness_ok and real_ok and not static_failures:
        status = "passed-no-mutations" if args.no_mutations else "passed"
    elif harness_ok and patched_ok:
        status = "failed (src bugs only)"
    else:
        status = "failed"
    src_bugs = [{"bug": p["bug"], "report": p["report"]} for p in patches if p["applied"]]
    report = {
        "status": status,
        "mutationsSkipped": args.no_mutations,
        "srcBugs": src_bugs,
        "patches": patches,
        "real": real,
        "patched": patched,
        "named": [{"group": n["Group"], "check": n["Name"], "pass": n["Pass"], "fail": n["Fail"]}
                  for n in (base_run["result"] or {}).get("Named", [])],
        "namedFrom": "patched" if patched_run else "real",
        "findings": (base_run["result"] or {}).get("Findings", []),
        "staticChecks": static_count,
        "staticFailures": static_failures,
        "analyzerUnknownGlobals": globals_found,
        "mutations": {"baseline": "patched" if patched_run else "real", "total": len(MUTATIONS), "applied": applied,
                      "caught": caught, "results": mutations},
        "compileOk": compiled.returncode == 0,
        "compileErrors": compiled.stderr.strip(),
        "runtimeError": None if real_run["result"] else (real_run["stderr"].strip() or real_run["stdout"].strip())[-2000:],
        "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(raw[key]).hexdigest() for key, p in FILES.items()},
        "fixtureSHA256": hashlib.sha256(fixture_raw).hexdigest(),
        "sourcesChangedDuringRun": changed,
        "studioCalls": 0, "apiCalls": 0,
        "contract": "Grudge sack (TECH_SPEC 4.14 + CR-M4/M6/L6): one sack per thief, shares per victim, 45 s countdown only "
                    "in PvP zones (1 s max per hitch), a new steal restarts at 45 s + held seconds, Paid -> carried gold + "
                    "infamy, Avenged by a present Halo killer -> 120% once per victim per 600 s (else 100%) + avenger 100 "
                    "once per 300 s, Returned (other death, leave, faction change) -> 100%, no refund across a rebirth. "
                    "P3 grudge mail: absent victims get { Id = <thief>:<sack start>:<kind>, A, R, K, T } in DataStore "
                    "HaloHorns_GrudgeMail_v1 key M_<userId> (max 20, oldest dropped), 4 tries (1/2/4 s back-off), a "
                    "letter Id is never appended twice, MailPending counts in-flight sends; at join (only if the victim "
                    "can be paid) the mailbox is cleared first, then same-life letters are paid to the bank (Refund), "
                    "only the first Avenged letter at 120% if the refund cooldown allows, one GrudgeMail notice; if the "
                    "victim can no longer be paid the letters are written back (capped); DataStore errors caught. "
                    "A23-18 ghost hold: GrudgeThiefId set by AddToSack, re-pointed by pointVictim (open sack of a "
                    "present thief with a same-life share) at close / join / rebirth / stale press; GhostHold (no args) "
                    "for a ready, alive, same-life victim of that sack, server rate limit 2.7 s, +2 s up to +10 s per "
                    "sack, SackHeldUntil glow for 3 s, GhostHoldOk / GhostHeld / GhostHoldMax notices.",
        "limitations": "Offline doubles: Players / characters, an in-memory DataStore whose calls never yield (no real "
                       "UpdateAsync retries, throttling or concurrent writers), task.spawn runs at once, task.wait / "
                       "task.delay / the 0.25 s loop are driven by a fixture clock (os.clock = server time), Net sends "
                       "and ProgressionService are recorders. PvPService (who may steal, how much), CombatService (death "
                       "pipeline order), the GrudgeGhost client and BindToClose are only checked statically. Studio "
                       "play, real multi-server mail and several clients are not certified here.",
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if compiled.returncode:
        print(compiled.stderr, end="")
    for label, run in (("REAL", real_run), ("PATCHED", patched_run)):
        if not run:
            continue
        shown = 0
        for line in run["stdout"].splitlines():
            if line.startswith("GRUDGE_OFFLINE"):
                print(f"{label} {line}")
            elif line.startswith("CHECK_FAIL") and shown < 40:
                shown += 1
                print(f"{label} {line}")
        if not run["result"]:
            print(run["stderr"], end="")
    for message in static_failures:
        print(f"STATIC_FAILURE {message}")
    print(f"STATIC checks={static_count} failed={len(static_failures)}")
    for p in patches:
        print(f"SRC_BUG {'(patched copy) ' if p['applied'] else '(patch not applied) '}{p['bug']}")
    for m in mutations:
        print(f"MUTATION {'caught ' if m.get('caught') else 'MISSED'} {m['mutation']}"
              + ("" if m.get("applied") else f" ({m.get('note')})"))
    if mutations:
        print(f"MUTATIONS caught={caught}/{applied} (of {len(MUTATIONS)}, baseline {report['mutations']['baseline']})")
    if args.no_mutations:
        print("MUTATIONS SKIPPED")
    print(f"REAL named checks: {real['namedChecks'] - real['namedChecksFailing']} passed, {real['namedChecksFailing']} failing; "
          f"assertions {real['checks'] - real['failedChecks']}/{real['checks']}")
    if patched:
        print(f"PATCHED named checks: {patched['namedChecks'] - patched['namedChecksFailing']} passed, "
              f"{patched['namedChecksFailing']} failing; assertions {patched['checks'] - patched['failedChecks']}/{patched['checks']}")
    print(f"Status: {status}")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if status in ("passed", "passed-no-mutations") else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(f"Grudge offline check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
