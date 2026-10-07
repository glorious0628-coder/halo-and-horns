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
    ("QuestService.luau", "string.format(text, Util.FormatNumber(TUT_GOLD)), \"reward\"", "QuestDone"),
    ("QuestService.luau", "Config.Text.QuestDone, Util.FormatNumber(q.RewardGold)", "QuestDone"),
    ("QuestService.luau", "Config.Text.DailyAutoPaid", "QuestDone"),
    ("QuestService.luau", "Config.Text.DailyClaimed", "QuestDone"),
    ("QuestService.luau", "Config.Text.DailyChest,", "GoldPickup"),
    ("QuestService.luau", "Config.Text.DailyChestTicket", "None"),
    ("QuestService.luau", "Config.Text.VacationClaimed", "GoldPickup"),
    ("StoryQuestService.luau", "notify(player, def.Finish or msg", "QuestDone"),
    ("StoryQuestService.luau", "if def.Finish then notify(player, msg", "None"),
    ("StoryQuestService.luau", "notify(player, TXT.Unlocked", "None"),
    ("StoryQuestService.luau", "if line then notify(player, line", "None"),
    ("StoryQuestService.luau", "TXT.NewTitle, Config.TitleDefs[titleId].Name", "RankUp"),
    ("StoryQuestService.luau", "notify(player, table.concat(parts, \" · \")", "None"),
    ("BoardService.luau", "T.Done or \"Job done!", "QuestDone"),
    ("BoardService.luau", "T.Bonus or \"%s\"", "None"),
    ("GooseService.luau", "Config.Text.GooseReward", "GoldPickup"),
    ("WarService.luau", "Config.Text.WarChest", "GoldPickup"),
    ("KaijuService.luau", "Config.Text.KaijuReward", "GoldPickup"),
    ("KaijuService.luau", "Net.Notify(p, string.format(text, Util.FormatNumber(amount))", "GoldPickup"),
    ("PvPService.luau", "fmt(\"BullyBountyGain\"", "GoldPickup"),
    ("PvPService.luau", "notify(killer, fmt(\"BountyGain\"", "GoldPickup"),
    ("PvPService.luau", "notify(a, fmt(\"BountyGain\"", "GoldPickup"),
    ("PvPService.luau", "fmt(\"Plundered\"", "None"),
    ("PvPService.luau", "fmt(\"BullyKO\"", "None"),
    ("GrudgeService.luau", "fmt(\"SackLost\")", "None"),
    ("GrudgeService.luau", "fmt(\"GhostHeld\")", "None"),
    ("ZoneService.luau", "fmt(\"EnteredPvP\")", "None"),
    ("ZoneService.luau", "\tnotify(player, fmt(\"TravelCancelled\"), \"bad\", \"None\")", "None"),
    ("ShopService.luau", "alreadyOwned and equipFmt or Config.Text.WeaponBought", "Equip"),
    ("ShopService.luau", "Config.Text.PotionBought", "Spend"),
    ("LootService.luau", "TXT.EnhanceOk", "ScrollSuccess"),
    ("LootService.luau", "TXT.EnhanceFailDown", "ScrollFail"),
    ("LootService.luau", "TXT.EnhanceFailKeep", "ScrollFail"),
    ("LootService.luau", "TXT.MoveOk", "ScrollSuccess"),
    ("LootService.luau", "TXT.MoveFail", "ScrollFail"),
    ("LootService.luau", "string.format(TXT.Equip, weaponName(player, tier))", "Equip"),
]
# the wrappers that must pass the sound on, and the payload
WRAPPERS = [
    ("StoryQuestService.luau", "local function notify(player, text, kind, sound)", "kind or \"info\", nil, sound)"),
    ("BoardService.luau", "local function notify(player, text, kind, sound)", "kind or \"info\", nil, sound)"),
    ("LootService.luau", "local function notify(player, text, kind, sound)", "kind or \"info\", nil, sound)"),
    ("PvPService.luau", "local function notify(p, text, kind, sound)", "Net.Notify(p, text, kind, nil, sound)"),
    ("GrudgeService.luau", "local function notify(p, text, kind, sound)", "Net.Notify(p, text, kind, nil, sound)"),
    ("ZoneService.luau", "local function notify(player, text, kind, sound)", "Net.Notify(player, text, kind, nil, sound)"),
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
    return count, failures


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    names = sorted({r[0] for r in ROUTES} | {w[0] for w in WRAPPERS})
    sources = {n: (SSS / n).read_text(encoding="utf-8") for n in names}
    net = NET.read_text(encoding="utf-8")
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
