"""sound_spec 2026-10-07 §4-1 (game dev 2's server part): every routed notice carries its Sound key, offline + static.

Net.Notify / NotifyAll put an optional Sound key in the payload (the client plays that Config.Audio key; "None" = no
sound; no key = the old kind mapping). This reads the CURRENT sources and checks the route table of the spec:
completions -> QuestDone, goose / chests / kaiju share / PvP bounty -> GoldPickup, NewTitle -> RankUp, weapon buy / equip
-> Equip, potion buy -> Spend, enhance and transfer -> ScrollSuccess / ScrollFail only, things done TO the player
(plundered, sack lost, held by a ghost, entered PvP, travel cut short, bully notice) -> "None" (never Deny), and the
second line of one moment -> "None". Each route is mutated in memory (its Sound removed) and must fail its check.
The story pick's Fx "Choice" { Option } is checked too. No Studio, network or Roblox API calls.

Usage: py tools/test_notify_sound.py [--no-mutations]
Report: docs/art/verification_2026-10-07/offline_dev2_notify_sound_2026-10-07.json
"""
from __future__ import annotations

import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SSS = ROOT / "src/ServerScriptService"
NET = ROOT / "src/ReplicatedStorage/Shared/Net.luau"
REPORT = ROOT / "docs/art/verification_2026-10-07/offline_dev2_notify_sound_2026-10-07.json"

# (file, a unique piece of the notify statement, the Sound it must carry)
ROUTES = [
    ("QuestService.luau", "string.format(TUT_CLAIMED_TEXT, Util.FormatNumber(gotGold)), \"reward\"", "QuestDone"),
    ("QuestService.luau", "Config.Text.QuestDone, Util.FormatNumber(gotGold)", "QuestDone"),
    ("QuestService.luau", "Config.Text.DailyAutoPaid", "QuestDone"),
    ("QuestService.luau", "Config.Text.DailyClaimed", "QuestDone"),
    ("QuestService.luau", "Config.Text.DailyChest,", "GoldPickup"),
    ("QuestService.luau", "Config.Text.DailyChestTicket", "None"),
    ("QuestService.luau", "Config.Text.VacationClaimed", "GoldPickup"),
    # A23-130: the quest-end reward line itself carries QuestDone (def.Finish lore lines are not sent)
    ("StoryQuestService.luau", "notify(player, msg, \"reward\", \"QuestDone\")", "QuestDone"),
    ("StoryQuestService.luau", "notify(player, TXT.Unlocked", "None"),
    ("StoryQuestService.luau", "if line then notify(player, line", "None"),
    ("StoryQuestService.luau", "TXT.NewTitle, Config.TitleDefs[titleId].Name", "RankUp"),
    ("StoryQuestService.luau", "notify(player, table.concat(parts, \" · \")", "None"),
    ("BoardService.luau", "T.Done or \"Job done!", "QuestDone"),
    ("BoardService.luau", "T.Bonus or \"%s\"", "None"),
    ("GooseService.luau", "Net.Notify(p, msg, \"reward\", nil", "GoldPickup"), # GooseReward / CoopReward (+ Cheer Star)
    ("WarService.luau", "Config.Text.WarChest", "GoldPickup"),
    ("KaijuService.luau", "Config.Text.KaijuReward", "GoldPickup"),
    ("KaijuService.luau", "Config.Text.KaijuSurviveReward", "GoldPickup"),
    ("PvPService.luau", "fmt(\"BullyBountyGain\"", "GoldPickup"),
    ("PvPService.luau", "notify(killer, fmt(\"BountyGain\"", "GoldPickup"),
    ("PvPService.luau", "notify(a, fmt(\"BountyGain\"", "GoldPickup"),
    ("PvPService.luau", "fmt(\"BullyKO\"", "None"),
    ("GrudgeService.luau", "fmt(\"SackLost\")", "None"),
    ("GrudgeService.luau", "fmt(\"GhostHeld\")", "None"),
    ("ZoneService.luau", "fmt(\"EnteredPvP\")", "None"),
    ("ZoneService.luau", "\tnotify(player, fmt(\"TravelCancelled\"), \"bad\", \"None\")", "None"),
    ("ZoneService.luau", "fmt(\"WaterRescue\")", "None"),
    ("ShopService.luau", "alreadyOwned and \"\" or string.format(Config.Text.WeaponBought", "Equip"),
    # A23-130: a potion buy has no text any more, the Spend sound stays (empty-text Notify)
    ("ShopService.luau", "Net.Notify(player, \"\", \"good\", nil", "Spend"),
    ("AttendanceService.luau", "notify(player, \"\", \"reward\"", "RankUp"),
    ("DiaryService.luau", "pcall(Net.Notify, player, \"\", \"reward\"", "RankUp"),
    # A23-130: enhance / transfer results and a Bag equip have no toast (the Items window shows the result line);
    # their sounds come from Fx Enhance (ScrollSuccess / ScrollFail) and Fx Upgrade (Equip) in Audio.luau
    # sound_gaps_2026-10-07 C1: no "reward" line outside the quest ends may fall back to QuestDone
    ("LootService.luau", "TXT.DuplicateWeapon, weaponName(player, tier)", "GoldPickup"),
    ("LootService.luau", "TXT.FirstWeapon, name", "None"),
    ("LootService.luau", "TXT.FirstWeaponBag, name", "Equip"),
    ("LootService.luau", "pcall(Net.Notify, player, line, \"reward\", num(first.NoticeSeconds, 6)", "None"),
    ("PetService.luau", "notify(player, text, \"reward\"", "None"),
    ("PetService.luau", "TXT.BecameFree or TXT.Became", "None"),
    ("PvPService.luau", "fmt(\"GraduateStart\")", "None"),
    ("PvPService.luau", "fmt(\"BoldStrong\")", "None"),
    ("PvPService.luau", "fmt(\"PlunderGain\"", "GoldPickup"),
    ("PvPService.luau", "fmt(\"HonorGain\", honor)", "RankUp"),
    ("GrudgeService.luau", "fmt(\"SackPaid\"", "GoldPickup"),
    ("GrudgeService.luau", "fmt(\"AvengerBonus\"", "GoldPickup"),
    ("RankingService.luau", "TXT.ArtisanGain, gain", "RankUp"),
    ("RankingService.luau", "pcall(Net.Notify, p, text, \"reward\", 8", "RankUp"),
    ("MonetizationService.luau", "string.format(Config.Text[textKey]), \"reward\"", "None"),
    ("ProgressionService.luau", "Config.Text.RebirthDone", "None"),
    ("FactionService.luau", "Config.Text.UnderdogSignOn", "GoldPickup"),
    # C3: auto combat switched off by a bully penalty: the AutoOff sound only, no Deny
    ("CombatService.luau", "outlawOnly and Config.Ranking.Text.OutlawAutoOff or Config.Text.BullyAutoOff", "None"),
]
# sound_gaps B2 / B6 / B11 and the weapon lines whose sound depends on the moment: (file, unique piece, description,
# the old text). Each is checked as written; putting the old text back must fail the check.
SPECIAL = [
    ("LootService.luau", "or string.format(TXT.JackpotSelf, name), \"reward\", before and \"None\" or \"Equip\")",
     "a jackpot weapon: Equip, or None when it is equipped from bare hands (the HUD's power-up moment sounds it)",
     "or string.format(TXT.JackpotSelf, name), \"reward\")"),
    ("LootService.luau", "Config.WeaponGrade(tier).Name, name), \"reward\", before and \"None\" or \"Equip\")",
     "a rare weapon drop: Equip, or None when equipped from bare hands",
     "Config.WeaponGrade(tier).Name, name), \"reward\")"),
    ("PvPService.luau", "Net.Fx(nil, \"Plunder\", { From = from, To = to, Amount = stolen, Victim = victim.UserId, Thief = killer.UserId })",
     "B2: the Plunder Fx says who was robbed (Victim) and by whom (Thief)",
     "Net.Fx(nil, \"Plunder\", { From = from, To = to, Amount = stolen })"),
    ("GrudgeService.luau", "Amount = refund, Victim = victim.UserId,\n\t\t\t\t\t\tThief = thief.UserId, Refund = true })",
     "B2: the grudge refund Fx is marked Refund (the robbed player gets gold back: GoldPickup, not Plunder); "
     "Thief = the one who stole (검수 2026-10-07, never the avenger)",
     "Amount = refund })"),
    ("WarService.luau", "local sound = winner == \"Halo\" and \"CrownHalo\" or \"CrownHorns\"",
     "B6: the war winner line carries CrownHalo / CrownHorns (A23-130: the text to the winners, the sound to all)",
     "local sound = nil"),
    ("HalloweenService.luau", "local ok, err = pcall(Net.Fx, nil, \"KingDefeat\", { Key = b.Key, Kind = rec.Kind,",
     "B11: a beaten king sends Fx KingDefeat to everyone (Key, Kind, Pos, Contributors)",
     "local ok, err = true, nil local _ = ({ Key = b.Key, Kind = rec.Kind,"),
]
# the wrappers that must pass the sound on, and the payload
WRAPPERS = [
    ("StoryQuestService.luau", "local function notify(player, text, kind, sound)", "kind or \"info\", nil, sound)"),
    ("BoardService.luau", "local function notify(player, text, kind, sound)", "kind or \"info\", nil, sound)"),
    ("LootService.luau", "local function notify(player, text, kind, sound)", "kind or \"info\", nil, sound)"),
    ("PvPService.luau", "local function notify(p, text, kind, sound)", "Net.Notify(p, text, kind, nil, sound)"),
    ("GrudgeService.luau", "local function notify(p, text, kind, sound)", "Net.Notify(p, text, kind, nil, sound)"),
    ("ZoneService.luau", "local function notify(player, text, kind, sound)", "Net.Notify(player, text, kind, nil, sound)"),
    ("PetService.luau", "local function notify(player, text, kind, sound)", "kind or \"info\", nil, sound)"),
]


def statement(src: str, piece: str) -> str | None:
    """the whole notify call that contains `piece` (from the line start to the call's closing parenthesis)"""
    at = src.find(piece)
    if at < 0 or src.find(piece, at + 1) >= 0:
        return None
    start = src.rfind("\n", 0, at) + 1
    depth, i, opened = 0, start, False
    while i < len(src):
        ch = src[i]
        if ch == "(":
            depth += 1
            opened = True
        elif ch == ")":
            depth -= 1
            if opened and depth == 0:
                return src[start:i + 1]
        i += 1
    return None


def check_all(sources: dict[str, str], net: str) -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    def fn_block(src: str, header: str) -> str:
        at = src.find(header)
        return src[at:src.find("\nend\n", at)] if at >= 0 else ""

    check("Sound = sound" in fn_block(net, "function Net.Notify(player, text, kind, duration, sound)"),
          "Net.Notify puts Sound in the payload")
    check("Sound = sound" in fn_block(net, "function Net.NotifyAll(text, kind, duration, sound)"),
          "Net.NotifyAll puts Sound in the payload too")
    for name, header, call in WRAPPERS:
        src = sources[name]
        at = src.find(header)
        body = src[at:src.find("\nend\n", at)] if at >= 0 else ""
        check(at >= 0 and call in body, f"{name}: notify(...) passes the sound on")
    for name, piece, sound in ROUTES:
        st = statement(sources[name], piece)
        check(st is not None and f"\"{sound}\")" in st.replace("\n", "").replace("\t", ""),
              f"{name}: '{piece[:50]}' carries Sound \"{sound}\"")
    story = sources["StoryQuestService.luau"]
    check("pcall(Net.Fx, player, \"Choice\", { Option = option })" in story
          and story.count("choiceFx(player, ") >= 2, "a story pick sends Fx Choice { Option } (Halo / Horns and Neutral)")
    for name, piece, what, _ in SPECIAL:
        check(sources[name].count(piece) == 1, f"{name}: {what}")
    finish = fn_block(sources["HalloweenService.luau"], "local function finish(b, defeated)")
    check("if defeated and type(rec) == \"table\" then" in finish and "Contributors = ids" in finish
          and "rec.PaidUserIds" in finish and "rec._contributors" not in finish,
          "B11: KingDefeat only for a beaten king (not one that leaves), with the paid players' UserIds (MonsterService keeps "
          "them on the record before it clears the tallies; behavior: test_halloween)")
    return count, failures


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    names = sorted({r[0] for r in ROUTES} | {w[0] for w in WRAPPERS} | {s[0] for s in SPECIAL})
    # LF-normalized (a Windows checkout with core.autocrlf has CRLF files)
    sources = {n: (SSS / n).read_text(encoding="utf-8").replace("\r\n", "\n") for n in names}
    net = NET.read_text(encoding="utf-8").replace("\r\n", "\n")
    count, failures = check_all(sources, net)
    mutations = []
    if "--no-mutations" not in sys.argv:
        for name, piece, sound in ROUTES:
            st = statement(sources[name], piece)
            if st is None:
                mutations.append({"mutation": f"{name}: {piece[:40]}", "caught": False, "note": "statement not found"})
                continue
            plain = st.replace(f", \"{sound}\")", ")").replace(f",\n\t\t\"{sound}\")", ")").replace(f",\n\t\t\t\"{sound}\")", ")")
            if plain == st:
                mutations.append({"mutation": f"{name}: {piece[:40]}", "caught": False, "note": "sound literal not found"})
                continue
            mutated = dict(sources)
            mutated[name] = sources[name].replace(st, plain, 1)
            _, fails = check_all(mutated, net)
            mutations.append({"mutation": f"{name}: no {sound} on '{piece[:40]}'", "caught": bool(fails)})
        mutated_net = net.replace("Duration = duration, Sound = sound }", "Duration = duration }", 1)
        _, fails = check_all(sources, mutated_net)
        mutations.append({"mutation": "Net.Notify drops Sound", "caught": bool(fails)})
        for name, piece, what, old in SPECIAL:
            if sources[name].count(piece) != 1:
                mutations.append({"mutation": f"{name}: {what[:40]}", "caught": False, "note": "piece not found"})
                continue
            mutated = dict(sources)
            mutated[name] = sources[name].replace(piece, old, 1)
            _, fails = check_all(mutated, net)
            mutations.append({"mutation": f"{name}: {what[:60]}", "caught": bool(fails)})
        mutated = dict(sources)
        mutated["HalloweenService.luau"] = sources["HalloweenService.luau"].replace(
            "\tif defeated and type(rec) == \"table\" then\n\t\tlocal ids = {}", "\tif type(rec) == \"table\" then\n\t\tlocal ids = {}", 1)
        _, fails = check_all(mutated, net)
        mutations.append({"mutation": "HalloweenService: KingDefeat also when a king leaves", "caught": bool(fails)})
    caught = sum(1 for m in mutations if m["caught"])
    status = "passed" if not failures and caught == len(mutations) else "failed"
    for f in failures:
        print("CHECK_FAIL " + f)
    for m in mutations:
        if not m["caught"]:
            print("MUTATION MISSED " + m["mutation"] + (" :: " + m.get("note", "") if m.get("note") else ""))
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps({"status": status, "checks": count, "failures": failures,
                                  "mutations": {"total": len(mutations), "caught": caught, "results": mutations},
                                  "studioCalls": 0, "apiCalls": 0}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"NOTIFY_SOUND_OFFLINE_{'OK' if status == 'passed' else 'FAILED'} checks={count} failed={len(failures)} "
          f"MUTATIONS caught={caught}/{len(mutations)}")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
