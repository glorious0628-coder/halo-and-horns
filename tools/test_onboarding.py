"""Run real onboarding/DataService Luau with an offline datastore and event scheduler.

No Studio, network, downloads, or live player records. This is not a live reconnect test.
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
    "DATA_SOURCE": ROOT / "src/ServerScriptService/DataService.luau",
    "QUEST_SOURCE": ROOT / "src/ServerScriptService/QuestService.luau",
    "NET_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Net.luau",
    # A23-68 #1: PlayerService's respawn zone (stat + respawnZoneId are cut out by the fixture)
    "PLAYER_SOURCE": ROOT / "src/ServerScriptService/PlayerService.luau",
}
FIXTURE = ROOT / "tools/fixtures/onboarding_offline.luau"


def quote_lua(value: str) -> str:
    eq = "===="
    while f"]{eq}]" in value:
        eq += "="
    return f"[{eq}[{value}]{eq}]"


def main() -> int:
    binary = ROOT / "build/luau_cli_0_741/luau.exe"
    compiler = binary.with_name("luau-compile.exe")
    if not binary.is_file() or not compiler.is_file():
        raise FileNotFoundError("Installed Luau CLI missing; this test never downloads tools.")
    harness = ROOT / "build/onboarding_offline_test.luau"
    harness.parent.mkdir(exist_ok=True)
    source_bytes = {key: path.read_bytes() for key, path in FILES.items()}
    fixture_bytes = FIXTURE.read_bytes()
    harness.write_text("\n".join(f"local {key} = {quote_lua(source_bytes[key].decode('utf-8-sig'))}"
                                 for key in FILES) + "\n" + fixture_bytes.decode("utf-8"), encoding="utf-8")
    compiled = subprocess.run([str(compiler), *(str(p) for p in FILES.values())], cwd=ROOT,
                              stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, encoding="utf-8", timeout=60)
    if compiled.returncode:
        print(compiled.stderr)
        return compiled.returncode
    result = subprocess.run([str(binary), str(harness)], cwd=ROOT, capture_output=True,
                            text=True, encoding="utf-8", errors="replace", timeout=60)
    marker = re.search(r"ONBOARDING_OFFLINE_OK checks=(\d+)", result.stdout)
    failed_marker = re.search(r"ONBOARDING_OFFLINE_FAILED checks=(\d+) failures=(\d+)", result.stdout)
    contract_failures = re.findall(r"^CONTRACT_FAILURE (.*)$", result.stdout, re.M)
    changed = [str(path.relative_to(ROOT)).replace("\\", "/")
               for key, path in FILES.items() if path.read_bytes() != source_bytes[key]]
    if FIXTURE.read_bytes() != fixture_bytes:
        changed.append(str(FIXTURE.relative_to(ROOT)).replace("\\", "/"))
    report = {
        "status": "passed" if result.returncode == 0 and marker and not changed else "failed",
        "checks": int(marker[1]) if marker else int(failed_marker[1]) if failed_marker else 0,
        "contractFailures": contract_failures,
        "sourceSHA256": {str(p.relative_to(ROOT)).replace("\\", "/"): hashlib.sha256(source_bytes[key]).hexdigest()
                         for key, p in FILES.items()},
        "fixtureSHA256": hashlib.sha256(fixture_bytes).hexdigest(),
        "sourcesChangedDuringRun": changed,
        "studioCalls": 0, "networkCalls": 0,
        "prologueScope": {"serverOpenPanel": "Welcome", "requestRemote": "RequestTutorial",
                          "acceptRemote": "AcceptTutorial", "remoteArgumentCount": 0,
                          "dialoguePagesPerFaction": 3, "worldNpcCreated": False,
                          "newArtOrUploads": 0, "clientPanelAndLiveEngineVerification": "pending_root"},
        "a23Facts": {"firstMissionRewardGold": 150, "nextGoalAfterBlacksmith": ["NextSkillIron", "NextIronLevel", "NextIronGold", "NextSkill", "NextZone", "GuideDone"],
                     "skillQuestCounts": "manual Released with MonstersHit >= 1 only (Auto ~= true)"},
        "coverage": ["real Net registry includes unique RequestTutorial/AcceptTutorial names",
                     "faction guide three-page dialogue, once per session automatic open, explicit reopen/accept",
                     "no-argument remotes reject extra/nil payload, unready/dead/invalid choices and rate-limit denial",
                     "closed guide stays pending; zone/kill/respawn/watchdog cannot bypass acceptance",
                     "accepted step1/2/99 and pending step0 save/reload preserved without duplicate reward",
                     "welcome/travel pinned rows", "first accepted meadow kill", "personal/wrong-zone exclusion",
                     "four/five kills save-release-load", "claim twice/reconnect no duplicate", "legacy/corrupt counters",
                     "death/respawn/faction/class changes retain progress",
                     "A23-3 reward is 150 gold and covers the wood weapon price",
                     "A23-3 pinned next-goal row after the visit: NextSkillIron (A23-71 S16, no Q yet; NextIronLevel when Q was kept) -> "
                     "NextIronGold (live gold) -> NextSkill (SKL-3: iron owned, the next skill before the next zone; Z / X only "
                     "with their switch) -> NextZone -> removed with one GuideDone toast; GoalKind SkillIron / IronLevel / Skill",
                     "next-goal row is never claimable, pays nothing, survives save/rejoin and keeps all ordinary quest slots",
                     "A23-3 pre-acceptance quest completion is paid quietly and never accepts the first mission",
                     "saved daily/extra Release quests migrate MinStacks50 to no stack gate and skill wording",
                     "A23-1 skill quests: auto, whiff (MonstersHit 0/absent), player-only and malformed MonstersHit rejected; one or many monsters count exactly once",
                     "skill quest wording equals the Config template after migration and reconnect (contract check)",
                     "migrated skill quest progress/rewards survive real DataService save/release/load",
                     "new ownership and mirrored fields", "post-sale ownership save/release/load without item resurrection",
                     "legacy tier4 preserved without inventing earlier purchases", "invalid/nonfinite mask, tier and visit repair",
                     "B4 8 weapon tiers (Config.MaxWeaponTier, tier 8 = legendary bit 7): a mask outside 1..255 or with any "
                     "bit above tier 8 resets to the starter (+ equipped bit), a tier outside 1..8 or fractional becomes 1 (never clamped)",
                     "B4 Data Version 3 (A23-69's Stats is additive: a record without it gains { Auto ON, nothing picked }; a "
                     "picked build saves and comes back repaired, A-Z kept): fresh/v2/v1 records load and save as Version 3 "
                     "with no other field changes (v2 legendary, "
                     "enhancement, items, loot flags kept); records with Version > 3 are refused without a write or lock",
                     "finite-value save serialization guard and migration idempotence",
                     "F10-4 safety net: step 2 at 5/5 unclaimed is paid QuestRewardGold once with Text.AutoClaimed exactly "
                     "Tutorial.AutoClaimSeconds (60) after this server first sees it; 4/5 never; a manual claim first pays the "
                     "Claimed line and clears the timer; kills < 5 reset it; PlayerLeaving clears it; a rejoin starts it again; "
                     "never outside step 2; the paid state saves and a late claim/rejoin pays nothing more",
                     "A23-74 weapon first (the mutations: tools/test_weapon_first.py): a bare-handed [Accept] -> step 3 "
                     "(the Forge row, Fx Travel To = Crossroads / Spot = Forge, the instant Crossroads travel); meadow kills "
                     "before the gift count nothing; QuestService.ForgeGift -> Otto's line + step 1 (2 in the meadow), once; "
                     "Forge.TravelDelay later the meadow trip -> the hunt; a save owning tier 1 -> step 1 as before; every "
                     "claim clears BlacksmithVisited, Claimed = the next weapon unless a better one is owned "
                     "(ClaimedArmed); step 3 survives save/reload (4 = invalid -> 99); RequestTutorial at step 3 = the "
                     "forge trip; a KO at step 3 respawns at home"],
        "limitations": "Offline store with finite-value serialization guard, scheduler, combat and reward doubles; post-sale states are fixtures. Actual DataService runs, but live DataStore/reconnect is not verified here. "
                       "F10-4 timing uses an os.clock double for QuestService only (one tutorial-loop tick per simulated second); "
                       "'claim clears' and 'PlayerLeaving clears' are white-box checks (step set back to 2 / the same Player object seen again).",
    }
    target = ROOT / "docs/art/verification_2026-10-06/offline_onboarding_2026-10-06.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="")
    print(f"Report: {target.relative_to(ROOT).as_posix()}")
    return 0 if report["status"] == "passed" else result.returncode or 1


if __name__ == "__main__":
    raise SystemExit(main())
