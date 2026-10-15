"""Quest data checks (최종 검수 10/15; contract docs/design/quest_data_contract_2026-10-15.md).

Loads Config.luau + every quest data pack in src/ReplicatedStorage/Shared/Quests/*.luau the way the game does
(Config.AddQuests, name order) with the stub engine of tools/test_story_text.py and the installed Luau CLI, then checks:

  all quests (old Config ones too)      ids and lists agree (Main / Subs / Defs / Kind), Requires ids exist and never form a
                                        cycle, step Obj.Type is a known one, an Offer NPC has a body (TownNpcs Story id),
                                        Reward keys and items are known, no reward ever sells a stat
  pack quests (the strict contract)     Type (the main action) from the list, Title + ShortName, an Offer (NPC + lines) for
                                        every sub and main, every step has a Guide or an Npc, Count steps count, consecutive
                                        main quests of one side's chain never share a Type, a Variant covers every step
  repeat requests (A23-205 / A23-206)   Config.StoryQuests.RepeatDailyMax = 5, at most 12 kinds, each pays a different kind
                                        of reward (no Codex progress, no stat), bound to the character

The example pack tools/fixtures/quest_pack_example.luau is loaded on top: it must pass, and each broken copy of it in
SELF_TESTS must be caught (the checker's own mutations). Text rules (lengths, words) stay in tools/test_story_text.py, which
loads the same packs.

Usage: py tools/test_quest_data.py [--src path/to/src] [--luau luau.exe]
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import test_story_text as ST  # noqa: E402  (its loader + stub engine)

EXAMPLE = ROOT / "tools/fixtures/quest_pack_example.luau"
MARK = "QUESTDATA"

STEP_TYPES = {"Kill", "BasicKill", "SafeKill", "AutoKill", "SkillHit", "Trials", "WarPoints", "EarnGold", "WarChest", "Goose",
              "Gather", "Craft", "SellMat", "Talk", "Choice", "State", "Event", "Level", "Enter", "Near", "Pickup", "Deliver",
              "Practice", "Emote", "Match", "Timing", "Learn", "Skip", "Escort", "Chase"}
COUNT_TYPES = {"Kill", "BasicKill", "SafeKill", "AutoKill", "SkillHit", "WarPoints", "EarnGold", "WarChest", "Goose", "Gather",
               "Craft", "SellMat"}
# bible §3 '유형은 주로 하는 행동': the main action of a quest (Type)
QUEST_TYPES = {"Combat", "Skill", "Gather", "Craft", "Sell", "Investigate", "Recover", "Deliver", "Repair", "Install", "Escort",
               "Rescue", "Defend", "Claim", "Boast", "Prank", "Command", "Lure", "Tame", "Choice", "Display", "Test", "Visit"}
REWARD_KEYS = {"Gold", "XP", "GoldN", "XPBar", "Item", "Potion", "N", "BagSlots", "Title", "TitleBy", "EquipCrafted", "Pet"}
# A23-207 (user 10/15) the harder, the better the reward: what each difficulty may pay at most (items by tier; Gold / XP in hunt
# units, GoldN exact gold, XPBar a share of the level's bar), and what Hard / Challenge must pay at least
DIFFICULTIES = ("Easy", "Normal", "Hard", "Challenge")
ITEM_TIER = {  # 0 = common (anyone), 1 = Hard and up, 2 = Challenge only
    "HP": 0, "MP": 0, "Herb": 0, "CopperOre": 0, "OakLog": 0, "Jelly": 0, "Petal": 0, "SeaShell": 0, "Bone": 0, "Candy": 0,
    "SlimeCore": 0, "PetTreat": 0, "GoblinTooth": 0, "BruteHorn": 0,
    "Enh10": 1, "Enh30": 1, "Enh70": 1, "Move10": 1, "Move30": 1, "Move70": 1, "Glowcap": 1, "IronOre": 1, "SilverOre": 1,
    "KnightCrest": 1, "CrystalShard": 1, "MightTonic": 1, "GuardTonic": 1, "LuckyTonic": 1, "WisdomTonic": 1, "CaptainBadge": 1,
    "MoonCrystal": 2, "ClatterGem": 2, "KingJelly": 2, "CrownDust": 2, "GoldenEgg": 2, "GooseFeather": 2,
}
CAPS = {  # difficulty -> (highest item tier, Gold/XP units, GoldN, XPBar, may give a title / pet)
    "Easy": (0, 1, 60, 0.25, False),
    "Normal": (0, 2, 150, 0.5, False),
    "Hard": (1, 4, 400, 1.0, False),
    "Challenge": (2, 99, 99999, 9.0, True),
}
STAT_WORDS = re.compile(r"(?i)\b(attack|atk|defen[cs]e|def|maxhp|power|stat|crit|speed)\b")
REPEAT_MAX_KINDS = 12
GUIDE_EXTRA = {"Bag", "OwnTown", "Blacksmith", "Crossroads", "HaloBridge", "HornsBridge", "Fountain"}


def arr(v) -> list:
    """a Luau array from the tree (dict with int keys, or a list) as a list"""
    if isinstance(v, list):
        return v
    if isinstance(v, dict):
        keys = sorted(k for k in v if isinstance(k, int) or (isinstance(k, str) and k.isdigit()))
        return [v[k] for k in keys]
    return []


def get(d, *path):
    for p in path:
        if not isinstance(d, dict):
            return None
        d = d.get(p, d.get(str(p)) if isinstance(p, int) else None)
    return d


def load(luau: Path, src: Path, work: Path, name: str, extra: list[tuple[str, str]] | None = None):
    source = (src / ST.CONFIG_REL).read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    packs = ST.quest_packs(src) + (extra or [])
    return ST.load_config(luau, source, work, name, packs)


def pack_ids(packs: list[tuple[str, str]]) -> set[str]:
    """quest ids a pack defines (read from its Defs table by name: '\\tId = {' lines inside Defs)"""
    ids: set[str] = set()
    for _, text in packs:
        m = re.search(r"\n\tDefs = \{\n(.*?)\n\t\},?\n", text, re.S)
        if m:
            ids.update(re.findall(r"^\t\t([A-Za-z_][\w]*) = \{", m.group(1), re.M))
    return ids


def check(tree: dict, strict: set[str]) -> list[tuple[str, str, str]]:
    """(rule, where, text) of every problem"""
    out: list[tuple[str, str, str]] = []
    sq = tree.get("StoryQuests") or {}
    defs = sq.get("Defs") or {}
    main, subs = arr(sq.get("Main")), arr(sq.get("Subs"))
    landmarks = set((sq.get("Landmarks") or {}).keys())
    zones = set((tree.get("Zones") or {}).keys())
    bodies = {e.get("Story") for e in arr(get(tree, "TownNpcs", "List")) if isinstance(e, dict) and e.get("Story")}
    items = set((get(tree, "Loot", "Items") or {}).keys()) | {"HP", "MP"}
    guides = landmarks | zones | GUIDE_EXTRA | set((get(tree, "StoryQuests", "AnvilSpots") or {}).keys())

    def add(rule, where, text):
        out.append((rule, where, text))

    # ---- lists and kinds
    for i in main:
        if i not in defs:
            add("main-missing", i, "listed in Main, no def")
        elif get(defs, i, "Kind") != "Main":
            add("main-kind", i, "in Main but Kind is not Main")
    for i in subs:
        if i not in defs:
            add("sub-missing", i, "listed in Subs, no def")
        elif get(defs, i, "Kind") != "Sub":
            add("sub-kind", i, "in Subs but Kind is not Sub")
    for i, d in defs.items():
        kind = d.get("Kind") if isinstance(d, dict) else None
        if kind == "Main" and i not in main and i in strict:
            add("main-unlisted", i, "Kind Main, not in Main")
        if kind == "Sub" and i not in subs and i in strict:
            add("sub-unlisted", i, "Kind Sub, not in Subs")
    # ---- requirements: ids exist, no cycle
    graph: dict[str, list[str]] = {}
    for i, d in defs.items():
        req = d.get("Requires") if isinstance(d, dict) else None
        if not isinstance(req, dict):
            continue
        needs = arr(req.get("Done")) + arr(req.get("DoneAny"))
        for n in needs + arr(req.get("NotDone")):
            if n not in defs:
                add("requires-unknown", i, f"Requires names {n}, no such quest")
        pick = req.get("Pick")
        if isinstance(pick, dict) and pick.get("Id") not in defs:
            add("requires-unknown", i, f"Requires.Pick names {pick.get('Id')}")
        graph[i] = [n for n in arr(req.get("Done")) if n in defs]
    state: dict[str, int] = {}

    def visit(n, stack):
        if state.get(n) == 1:
            add("requires-cycle", n, " -> ".join(stack + [n]))
            return
        if state.get(n) == 2:
            return
        state[n] = 1
        for m in graph.get(n, []):
            visit(m, stack + [n])
        state[n] = 2
    for n in list(graph):
        visit(n, [])
    # ---- steps, offers, rewards
    for i, d in defs.items():
        if not isinstance(d, dict):
            continue
        is_pack = i in strict
        steps = arr(d.get("Steps"))
        if not steps:
            add("steps-empty", i, "no steps")
        for si, st in enumerate(steps, 1):
            variants = [st] + [st[f] for f in ("Halo", "Horns", "Neutral") if isinstance(st.get(f), dict)]
            for v in variants:
                obj = v.get("Obj") if isinstance(v.get("Obj"), dict) else st.get("Obj")
                t = obj.get("Type") if isinstance(obj, dict) else None
                if t not in STEP_TYPES:
                    add("step-type", f"{i}.{si}", f"unknown Obj.Type {t}")
                if t in ("Escort", "Chase") and len(arr(get(tree, "StoryQuests", "Paths", obj.get("Path")))) < 2:
                    add("step-path", f"{i}.{si}", f"{t} needs Path = a StoryQuests.Paths key with 2+ waypoints")
                if is_pack:
                    if t in COUNT_TYPES and not (isinstance(obj.get("Count"), int) and obj.get("Count") > 0) and t != "Trials":
                        add("step-count", f"{i}.{si}", f"{t} needs a whole Count > 0")
                    guide, npc = v.get("Guide", st.get("Guide")), v.get("Npc", st.get("Npc"))
                    card = (v.get("Panel", st.get("Panel")) is True) and npc is None
                    if not guide and not npc and not card:
                        add("step-guide", f"{i}.{si}", "no Guide or Npc (A23-199)")
                    if guide and guide not in guides:
                        add("step-guide-unknown", f"{i}.{si}", f"Guide {guide} is no landmark / zone / guide spot")
                    if npc and npc not in bodies:
                        add("step-npc-body", f"{i}.{si}", f"Npc {npc} has no body (TownNpcs Story)")
                    if not v.get("Text") and not st.get("Text"):
                        add("step-text", f"{i}.{si}", "no Text")
        offer = d.get("Offer")
        if isinstance(offer, dict):
            npcs = offer.get("Npc")
            for n in (npcs.values() if isinstance(npcs, dict) else [npcs]):
                if n is not None and n not in bodies:
                    add("offer-npc-body", i, f"Offer NPC {n} has no body (TownNpcs Story)")
        reward = d.get("Reward")
        if isinstance(reward, dict):
            for k in reward:
                if k not in REWARD_KEYS:
                    add("reward-key", i, f"Reward.{k} is not a known reward")
            if reward.get("Item") is not None and reward.get("Item") not in items:
                add("reward-item", i, f"Reward.Item {reward.get('Item')} is no item")
            if any(STAT_WORDS.search(str(k)) for k in reward):
                add("reward-stat", i, "a reward sells a stat (A23-75)")
        if is_pack:
            diff = d.get("Difficulty")
            if diff not in DIFFICULTIES:
                add("difficulty", i, f"Difficulty {diff} is not Easy / Normal / Hard / Challenge (A23-207)")
            elif isinstance(reward, dict):
                tier_max, units, gold_n, bar, special = CAPS[diff]
                item = reward.get("Item") or reward.get("Potion")
                tier = ITEM_TIER.get(item, 1) if item else -1
                if tier > tier_max:
                    add("difficulty-reward", i, f"{diff} pays {item} (a tier-{tier} item: too good for it)")
                if max(reward.get("Gold") or 0, reward.get("XP") or 0) > units or (reward.get("GoldN") or 0) > gold_n \
                        or (reward.get("XPBar") or 0) > bar:
                    add("difficulty-reward", i, f"{diff} pays more gold / XP than its cap")
                if (reward.get("Title") or reward.get("TitleBy") or reward.get("Pet")) and not special:
                    add("difficulty-reward", i, f"{diff} gives a title / pet (Challenge only)")
                if diff == "Hard" and tier < 1 and max(reward.get("Gold") or 0, reward.get("XP") or 0) < 2 \
                        and (reward.get("GoldN") or 0) < 150:
                    add("difficulty-reward-low", i, "Hard pays a scroll / rare material or more gold than Normal")
                if diff == "Challenge" and tier < 2 and not (reward.get("Title") or reward.get("TitleBy") or reward.get("Pet")):
                    add("difficulty-reward-low", i, "Challenge pays a rare item, a title or a pet")
            # A23-208 story fields: the situation before the ask, something found on the way, the last words, the last scene, the
            # next hook (the chain's last quest says Last = true instead)
            limits = get(tree, "StoryQuests", "StoryLimits") or {}
            scenes = get(tree, "StoryQuests", "SceneKeys") or {}
            before = offer.get("Before") if isinstance(offer, dict) else None
            by = offer.get("BeforeBy") if isinstance(offer, dict) else None
            befores = list(before.values()) if isinstance(before, dict) else [before]
            if isinstance(by, dict):
                # 10/15: BeforeBy = { Flag, [value] = line, Default = the first visit's line } (Config.QuestBefore)
                if not isinstance(by.get("Flag"), str) or not 0 < len(by["Flag"]) <= 24:
                    add("story-before", i, "BeforeBy.Flag is a personal result key (1~24 letters)")
                if not isinstance(by.get("Default"), str) or not by.get("Default"):
                    add("story-before", i, "BeforeBy.Default (the line before the flag is set) is needed")
                befores = [v for k, v in by.items() if k != "Flag"]
            if not befores or any(not isinstance(b, str) or not b for b in befores):
                add("story-before", i, "Offer.Before (the situation, one line before the ask) is needed (A23-208)")
            for b in befores:
                if isinstance(b, str) and len(b) > (limits.get("Before") or 70):
                    add("story-length", i, f"Offer.Before {len(b)} characters (phone limit {limits.get('Before') or 70})")
            finds = [st.get("Find") for st in steps if isinstance(st, dict) and st.get("Find") is not None]
            if not finds:
                add("story-find", i, "at least one step has Find (what the player finds on the way, A23-208)")
            for f in finds:
                if not isinstance(f, str) or len(f) > (limits.get("Find") or 40):
                    add("story-length", i, f"Find must be a line of at most {limits.get('Find') or 40} characters: {f!r}")
            for si, st in enumerate(steps, 1):
                if not isinstance(st, dict):
                    continue
                if st.get("On") is not None and st.get("On") != "Self":
                    add("story-on", f"{i}.{si}", f"On must be \"Self\" (the player's own avatar), not {st.get('On')!r}")
                for v in [st] + [st[f] for f in ("Halo", "Horns", "Neutral") if isinstance(st.get(f), dict)]:
                    if v.get("Scene", st.get("Scene")) and not v.get("Npc", st.get("Npc")) and st.get("On") != "Self":
                        add("story-scene", f"{i}.{si}", "a Scene on a step with no Npc needs On = \"Self\" (who plays it?)")
            last = steps[-1] if steps and isinstance(steps[-1], dict) else {}
            if not (last.get("Lines") or last.get("LinesBy")):
                add("story-end", i, "the last step has the closing words (Lines / LinesBy, A23-208)")
            if not last.get("Scene"):
                add("story-scene", i, "the last step has a Scene (what the people do at the end, A23-208)")
            for st in steps:
                sc = st.get("Scene") if isinstance(st, dict) else None
                if sc is not None and sc not in scenes:
                    add("story-scene", i, f"Scene {sc} is not in StoryQuests.SceneKeys")
            if d.get("Last") is not True:
                nxt = d.get("Next")
                fs = d.get("Factions") if isinstance(d.get("Factions"), dict) else {}
                sides = [f for f in ("Halo", "Horns", "Neutral") if fs.get(f)] or ["Halo", "Horns", "Neutral"]
                if isinstance(nxt, dict) and nxt.get("Id") is None and any(isinstance(nxt.get(f), dict) for f in sides):
                    for f in sides:  # 10/15: a side's own hook (Variants[id].Next)
                        if not isinstance(nxt.get(f), dict):
                            add("story-next", i, f"Next has no hook for {f} (each side of the quest needs one)")
                elif not isinstance(nxt, dict) or not nxt.get("Id") or not isinstance(nxt.get("Line"), str):
                    add("story-next", i, "Next = { Id, Line } (the hook to the next quest; the chain's last quest: Last = true)")
        # ---- every Next written (a shared one, or a side's): a real quest that waits for this one, a short line
        nxt = d.get("Next")
        hooks = [nxt] if isinstance(nxt, dict) and nxt.get("Id") is not None else \
            [v for f, v in (nxt.items() if isinstance(nxt, dict) else []) if f in ("Halo", "Horns", "Neutral") and isinstance(v, dict)]
        limits = get(tree, "StoryQuests", "StoryLimits") or {}
        for h in hooks:
            if not h.get("Id") or not isinstance(h.get("Line"), str):
                add("story-next", i, "Next = { Id, Line }")
                continue
            if len(h["Line"]) > (limits.get("NextLine") or 60):
                add("story-length", i, f"Next.Line {len(h['Line'])} characters (phone limit {limits.get('NextLine') or 60})")
            target = defs.get(h["Id"])
            if not isinstance(target, dict):
                add("story-next", i, f"Next.Id {h['Id']} is no quest")
            else:
                treq = target.get("Requires") if isinstance(target.get("Requires"), dict) else {}
                if i not in arr(treq.get("Done")) + arr(treq.get("DoneAny")) and h["Id"] not in main:
                    add("story-next", i, f"Next.Id {h['Id']} does not wait for {i} (Requires.Done) and is no main")
        if is_pack:
            if d.get("Type") not in QUEST_TYPES:
                add("quest-type", i, f"Type {d.get('Type')} is not on the list (bible §3)")
            if not d.get("Title") or not d.get("ShortName"):
                add("quest-title", i, "Title and ShortName are needed")
            if not isinstance(offer, dict) or offer.get("Npc") is None or not offer.get("Lines"):
                add("quest-offer", i, "every quest is asked by an NPC: Offer = { Npc, Lines } (rule 1)")
    # ---- one side's main chain: consecutive mains never share a Type
    for side in ("Halo", "Horns", "Neutral"):
        prev = None
        for i in main:
            d = defs.get(i)
            if not isinstance(d, dict):
                continue
            fs = d.get("Factions")
            if isinstance(fs, dict) and not fs.get(side):
                continue
            t = d.get("Type")
            if t and prev and t == prev[1] and (i in strict or prev[0] in strict):
                add("chain-type", f"{side}:{prev[0]}->{i}", f"two {t} quests in a row (bible §3)")
            prev = (i, t) if t else None
    # ---- repeat requests (A23-205 / A23-206)
    repeats = [i for i, d in defs.items() if isinstance(d, dict) and d.get("Repeat") is not None]
    if get(tree, "StoryQuests", "RepeatDailyMax") != 5:
        add("repeat-max", "StoryQuests.RepeatDailyMax", "must be 5 (A23-205)")
    if len(repeats) > REPEAT_MAX_KINDS:
        add("repeat-kinds", "Repeat", f"{len(repeats)} repeat requests (at most {REPEAT_MAX_KINDS})")
    seen: dict[str, str] = {}
    for i in repeats:
        d = defs[i]
        if d.get("Repeat") != "Daily":
            add("repeat-kind", i, "Repeat must be \"Daily\"")
        r = d.get("Reward") if isinstance(d.get("Reward"), dict) else {}
        if not r:
            add("repeat-reward", i, "a repeat request pays something (A23-206)")
            continue
        sig = r.get("Item") or r.get("Potion") or ("Gold" if r.get("Gold") or r.get("GoldN") else "XP")
        if sig in seen:
            add("repeat-reward-same", i, f"pays {sig} like {seen[sig]} (A23-206: every repeat a different kind)")
        seen[sig] = i
        if "Codex" in str(r):
            add("repeat-reward-codex", i, "no codex progress as a reward (A23-206)")
    # (A23-206 bound reward items: checked here once LootService keeps bound counts - save v7, the next step)
    return out


# broken copies of the example pack: (name, old, new, the rule that must catch it)
SELF_TESTS = [
    ("no Offer", "\t\t\tOffer = { Npc = \"Bright\", Before = \"The cart wobbles.", "\t\t\tOffer_ = { Npc = \"Bright\", Before = \"The cart wobbles.", "quest-offer"),
    ("no Type", "Kind = \"Main\", Chapter = 2, Type = \"Escort\",", "Kind = \"Main\", Chapter = 2,", "quest-type"),
    ("a step without a guide", "ShortName = \"To the bridge\", Guide = \"HaloBridge\",", "ShortName = \"To the bridge\",", "step-guide"),
    ("an unknown guide", "Guide = \"HaloBridge\"", "Guide = \"Nowhere\"", "step-guide-unknown"),
    ("an NPC with no body", "{ Text = \"Show Otto the ribbon\", ShortName = \"To Otto\", Npc = \"Otto\"", "{ Text = \"Show Otto the ribbon\", ShortName = \"To Otto\", Npc = \"Ghost\"", "step-npc-body"),
    ("an unknown step type", "Obj = { Type = \"Deliver\" }", "Obj = { Type = \"Teleport\" }", "step-type"),
    ("a requirement that does not exist", "Requires = { Done = { \"H_Band\", \"HX_Guard\" }, Level = 4 }", "Requires = { Done = { \"H_Nope\", \"HX_Guard\" }, Level = 4 }", "requires-unknown"),
    ("a requirement cycle", "Requires = { Done = { \"H_Band\", \"HX_Guard\" }, Level = 4 }", "Requires = { Done = { \"HX_Ribbon\", \"HX_Guard\" }, Level = 4 }", "requires-cycle"),
    ("an unknown reward key", "Reward = { GoldN = 40 }", "Reward = { GoldN = 40, Gems = 5 }", "reward-key"),
    ("a stat for sale", "Reward = { GoldN = 40 }", "Reward = { GoldN = 40, Attack = 5 }", "reward-stat"),
    ("a sub not in Subs", "Subs = { \"HX_Ribbon\", \"HX_DailyLamp\" }", "Subs = { \"HX_DailyLamp\" }", "sub-unlisted"),
    ("a repeat that is not daily", "Repeat = \"Daily\"", "Repeat = \"Weekly\"", "repeat-kind"),
    ("no difficulty", "Kind = \"Sub\", Type = \"Deliver\", Difficulty = \"Easy\",", "Kind = \"Sub\", Type = \"Deliver\",", "difficulty"),
    ("an easy quest that pays a scroll", "Reward = { GoldN = 40 }", "Reward = { GoldN = 40, Item = \"Enh70\", N = 1 }", "difficulty-reward"),
    ("an easy quest with a title", "Reward = { GoldN = 40 }", "Reward = { GoldN = 40, Title = \"Helper\" }", "difficulty-reward"),
    ("a hard quest that pays like an easy one", "Reward = { Item = \"Enh70\", N = 1 }", "Reward = { GoldN = 40 }", "difficulty-reward-low"),
    ("no situation line", "Offer = { Npc = \"Bright\", Before = \"The cart wobbles. The bridge planks creak.\",", "Offer = { Npc = \"Bright\",", "story-before"),
    ("a long situation line", "Before = \"The cart wobbles. The bridge planks creak.\",", "Before = \"The cart wobbles. The bridge planks creak. Everyone in town is watching the cart now.\",", "story-length"),
    ("nothing found on the way", "Find = \"A tiny sock is stuck on the wheel!\",", "", "story-find"),
    ("no last scene", "Scene = \"Wave\",", "", "story-scene"),
    ("an unknown scene", "Scene = \"Wave\",", "Scene = \"Dab\",", "story-scene"),
    ("no next hook", "Next = { Id = \"HX_Ribbon\", Line = \"Bright: Oh! My ribbon got crumpled on the cart...\" },", "", "story-next"),
    ("a hook to a quest that does not wait", "Next = { Id = \"HX_Ribbon\"", "Next = { Id = \"HX_DailyLamp\"", "story-next"),
    ("a scene on the road with no one", "Find = \"A tiny sock is stuck on the wheel!\", On = \"Self\", Scene = \"Cheer\",",
     "Find = \"A tiny sock is stuck on the wheel!\", Scene = \"Cheer\",", "story-scene"),
    ("an On that is not Self", "On = \"Self\", Scene = \"Cheer\",", "On = \"Bright\", Scene = \"Cheer\",", "story-on"),
    ("a remembered line with no first-visit line", "\n\t\t\t\tDefault = \"The town lamp flickers again tonight.\" },", " },", "story-before"),
    ("a remembered line too long", "Moth = \"The moth is back. It brought a friend.\",",
     "Moth = \"The moth is back. It brought a friend. And another. And their whole family too.\",", "story-length"),
    ("a side's hook to nowhere", "Next = { Id = \"M2_3\", Line", "Next = { Id = \"M9_9\", Line", "story-next"),
    ("a side's hook to a quest that does not wait", "Next = { Id = \"M2_3\", Line", "Next = { Id = \"HX_Ribbon\", Line", "story-next"),
    ("a side's hook missing for its own side", "Next = { Id = \"HX_Ribbon\", Line = \"Bright: Oh! My ribbon got crumpled on the cart...\" },",
     "Next = { Horns = { Id = \"HX_Ribbon\", Line = \"Bright: Oh! My ribbon got crumpled on the cart...\" } },", "story-next"),
    ("two mains of one type in a row", "Kind = \"Main\", Chapter = 2, Type = \"Escort\"", "Kind = \"Main\", Chapter = 2, Type = \"Choice\"", "chain-type"),
]


FN_CHECKS = r"""
local function ok(c, m) print((c and "FN_OK " or "FN_FAIL ") .. m) end
local shared = { Next = { Id = "A", Line = "x" } }
ok(Config.QuestNext(shared, "Horns").Id == "A", "a shared Next for every side")
local side = { Next = { Halo = { Id = "H", Line = "h" }, Horns = { Id = "R", Line = "r" } } }
ok(Config.QuestNext(side, "Horns").Id == "R" and Config.QuestNext(side, "Neutral") == nil, "a side's own Next")
ok(Config.QuestNext({}, "Halo") == nil and Config.QuestNext(nil, "Halo") == nil, "no Next")
ok(Config.QuestBefore({ Offer = { Before = { Halo = "hb", Horns = "rb" } } }, "Horns", {}) == "rb", "a side's own Before")
local e = { Offer = { Before = "plain", BeforeBy = { Flag = "K", Moth = "again", Default = "first" } } }
ok(Config.QuestBefore(e, "Halo", {}) == "first" and Config.QuestBefore(e, "Halo", nil) == "first", "BeforeBy: first visit = Default")
ok(Config.QuestBefore(e, "Halo", { K = "Moth" }) == "again", "BeforeBy: the remembered result's line")
ok(Config.QuestBefore(e, "Halo", { K = "Other" }) == "first", "BeforeBy: a value with no line = Default")
ok(Config.QuestBefore(e, "Halo", { K = "Flag" }) == "first", "BeforeBy: the Flag key itself is no line")
ok(Config.QuestBefore({ Offer = { Before = "plain" } }, "Halo", nil) == "plain", "a plain Before")
"""
FN_COUNT = 9


def check_functions(luau: Path, src: Path, work: Path) -> int:
    """Config.QuestNext / Config.QuestBefore (pure) cut out of Config and run alone; returns the number of problems"""
    text = (src / ST.CONFIG_REL).read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    fns = [m.group(0) for m in re.finditer(r"\nfunction Config\.(QuestNext|QuestBefore)\(.*?\nend\n", text, re.S)]
    if len(fns) != 2:
        print("CHECK_FAIL Config.QuestNext / Config.QuestBefore not found")
        return 1
    path = work / "fn.luau"
    path.write_text("local Config = {}\n" + "".join(fns) + FN_CHECKS, encoding="utf-8")
    out = subprocess.run([str(luau), str(path)], capture_output=True, timeout=60).stdout.decode("utf-8", "replace")
    good = out.count("FN_OK ")
    for line in out.splitlines():
        if line.startswith("FN_FAIL"):
            print("CHECK_FAIL " + line)
    if good == FN_COUNT:
        print(f"CHECK_OK Config.QuestNext / QuestBefore {good}/{FN_COUNT}")
        return 0
    print(f"CHECK_FAIL Config.QuestNext / QuestBefore {good}/{FN_COUNT}")
    return 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", type=Path, default=ROOT / "src")
    ap.add_argument("--luau", type=Path, default=ROOT / "build/luau_cli_0_741/luau.exe")
    args = ap.parse_args()
    src = args.src.resolve()
    real = ST.quest_packs(src)
    example = EXAMPLE.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    failed = 0
    with tempfile.TemporaryDirectory(prefix="quest_data_") as tmp:
        work = Path(tmp)
        tree, err = load(args.luau, src, work, "real")
        if tree is None:
            print(f"{MARK}_FAILED Config + packs did not load: {err}")
            return 1
        strict = pack_ids(real)
        problems = check(tree, strict)
        hard = [p for p in problems if p[2] and (p[1].split(".")[0].split(":")[-1] in strict or p[0] in
                ("main-missing", "sub-missing", "main-kind", "sub-kind", "requires-unknown", "requires-cycle", "step-type",
                 "offer-npc-body", "reward-key", "reward-item", "reward-stat", "repeat-max", "repeat-kinds", "bound"))]
        print(f"packs: {len(real)} ({', '.join(n for n, _ in real) or 'none yet'}); quests checked: "
              f"{len(tree['StoryQuests']['Defs'])}; strict (pack) quests: {len(strict)}")
        for rule, where, text in hard:
            print(f"CHECK_FAIL {rule} :: {where} :: {text}")
        failed += len(hard)
        # the example pack passes
        ex_tree, ex_err = load(args.luau, src, work, "example", [("Example", example)])
        if ex_tree is None:
            print(f"CHECK_FAIL example :: the example pack did not load :: {ex_err}")
            failed += 1
        else:
            ex_strict = strict | pack_ids([("Example", example)])
            ex = [p for p in check(ex_tree, ex_strict) if p[1].split(".")[0].split(":")[-1].split("->")[-1] in ex_strict
                  or p[0] in ("chain-type", "repeat-reward-same", "repeat-max", "bound")]
            for rule, where, text in ex:
                print(f"CHECK_FAIL example :: {rule} :: {where} :: {text}")
            failed += len(ex)
            if not ex:
                print("CHECK_OK the example pack passes every check")
        # each broken copy is caught
        caught = 0
        for i, (name, old, new, rule) in enumerate(SELF_TESTS):
            if example.count(old) != 1:
                print(f"MUTATION NOT APPLIED {name} (pattern matched {example.count(old)} times)")
                failed += 1
                continue
            bad = example.replace(old, new, 1)
            b_tree, b_err = load(args.luau, src, work, f"bad{i}", [("Example", bad)])
            if b_tree is None:
                ok = rule == "load"
                print(("MUTATION caught  " if ok else "MUTATION MISSED ") + f"{name} (load error: {b_err})")
                caught += 1 if ok else 0
                failed += 0 if ok else 1
                continue
            rules = {p[0] for p in check(b_tree, strict | pack_ids([("Example", bad)]))}
            if rule in rules:
                caught += 1
                print(f"MUTATION caught  {name}")
            else:
                failed += 1
                print(f"MUTATION MISSED {name} (wanted {rule}; got {sorted(rules)})")
        print(f"MUTATIONS caught={caught}/{len(SELF_TESTS)}")
        failed += check_functions(args.luau, src, work)
        # a duplicate id across packs is refused at load (Config.AddQuests)
        d_tree, d_err = load(args.luau, src, work, "dup", [("Example", example), ("Example2", example)])
        if d_tree is None and "defined already" in (d_err or ""):
            print("CHECK_OK a quest id defined twice stops the load (never overwritten)")
        else:
            print("CHECK_FAIL a quest id defined twice must stop the load")
            failed += 1
    print(f"{MARK} {'passed' if failed == 0 else 'failed'} problems={failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
