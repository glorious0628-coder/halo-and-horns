"""A23-113 ① Roblox friends never damage each other (server side), offline.

Runs the CURRENT Config, Util, PvPService, CombatService, SkillService, DamageWindow, LootService, StoryQuestService
(whole modules, the tools/test_skills.py bindings) on tools/fixtures/dev2_combat_world.luau with its PvPService double
swapped for the real PvPService, and the CURRENT PvPService, CombatService, KaijuService, RankingService, GrudgeService,
AnnounceService, TitleService (the tools/test_ranking.py bindings) on tools/fixtures/dev2_world.luau, with
tools/fixtures/friend_pvp_offline.luau and the installed official Luau CLI. No Studio, network, DataStore or Roblox API
calls (IsFriendsWith is the kit's Player double: w.Friends / w.FriendError / w.FriendCalls). Mutations run on in-memory
copies of the sources only.

Spec: docs/SPEC_ADDENDUM.md A23-113 ① (user 2026-10-10).
Usage: py tools/test_friend_pvp.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-11/offline_dev2_friend_pvp_2026-10-11.json
"""
from __future__ import annotations

import re

from dev2_offline import KIT, ROOT, SSS, Suite, function_block, literal, read, run, strip_comments
from test_ranking import FILES as RANKING_FILES, bindings as ranking_bindings
from test_skills import FILES as SKILL_FILES, bindings as skill_bindings

COMBAT_WORLD = ROOT / "tools/fixtures/dev2_combat_world.luau"
RANK_WORLD = ROOT / "tools/fixtures/dev2_world.luau"

FILES = dict(SKILL_FILES)
FILES.update(RANKING_FILES)


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = skill_bindings(sources)
    out.update(ranking_bindings(sources))
    return out


class TwoWorlds(Suite):
    """The fixture uses both shared worlds: the combat world (swings, skills) and the ranking world (kaiju, boards)."""

    def harness(self, sources: dict[str, str]) -> str:
        bound = self.bindings(sources)
        head = "\n".join(f"local {key} = {literal(value)}" for key, value in bound.items())
        return (head + f"\nlocal SUITE_MARK = {literal(self.mark)}\n" + read(KIT) + "\n" + read(COMBAT_WORLD) + "\n"
                + read(RANK_WORLD) + "\n" + read(self.fixture))


P, CO, K, R = "PVP_SOURCE", "COMBAT_SOURCE", "KAIJU_SOURCE", "RANKING_SOURCE"
FRIEND_CHECK = '\tif PvPService.AreFriends(attacker, victim) then\n\t\treturn false, "Friend"\n\tend\n'
GATE = ('\tif pvp and type(pvp.AreFriends) == "function" and pvp.AreFriends(attacker, victim) == true then\n'
        '\t\treturn 0\n\tend\n')

MUTATIONS = [
    # --- PvPService.CanAttack
    ("CanAttack ignores friends", P, FRIEND_CHECK, ""),
    ("the kaiju exception wins over friends", P, "\tif PvPService.AreFriends(attacker, victim) then\n",
     '\tif PvPService.AreFriends(attacker, victim) and not (fa == "Halo" and kstate(victim) == "Active") then\n'),
    # --- PvPService friend cache
    ("nobody asks at the join", P, "\tlocal okFriends, errFriends = pcall(FRIEND.Join, player)\n",
     "\tlocal okFriends, errFriends = true, nil\n"),
    ("a failed call counts as friends", P, "FRIEND.Pairs[key] = ok and res == true", "FRIEND.Pairs[key] = not ok or res == true"),
    ("the answer is never kept", P, "FRIEND.Pairs[key] = ok and res == true", "FRIEND.Pairs[key] = nil"),
    ("a failed answer is not stored", P, "FRIEND.Pairs[key] = ok and res == true",
     "if ok then FRIEND.Pairs[key] = res == true end"),
    ("FRIEND.Ask's presence / ready guard removed", P,
     "\tif not isPlaying(newcomer) or not isPlaying(other) or not PS.IsReady(newcomer) or not PS.IsReady(other) then return end\n",
     ""),
    ("a known pair is asked again", P,
     "\tif FRIEND.Pairs[key] ~= nil or FRIEND.Asking[key] ~= nil then return end -- once per pair\n", ""),
    ("the pair key depends on who joined last", P, "\tlocal key = engageKey(newcomer, other)\n",
     '\tlocal key = tostring(newcomer.UserId) .. ":" .. tostring(other.UserId)\n'),
    ("before the answer the pair counts as friends", P, "return FRIEND.Pairs[engageKey(a, b)] == true",
     "return FRIEND.Pairs[engageKey(a, b)] ~= false"),
    ("a late answer after a leave is kept", P,
     "\tif FRIEND.Asking[key] ~= token then return end -- one of them left meanwhile\n", ""),
    ("a leave keeps the pair", P, "\tFRIEND.Drop(player) -- A23-113 ①: a rejoin asks again\n", ""),
    ("a leave drops only the lower id's pairs", P, "if lo == id or hi == id then list[key] = nil end",
     "if lo == id then list[key] = nil end"),
    ("all calls at once on a full server", P,
     "if wave == 0 then task.spawn(run) else task.delay(wave * FRIEND.Gap, run) end", "task.spawn(run)"),
    ("the later waves never run", P,
     "if wave == 0 then task.spawn(run) else task.delay(wave * FRIEND.Gap, run) end", "if wave == 0 then task.spawn(run) end"),
    # --- CombatService.DamagePlayer (the last gate)
    ("DamagePlayer lets friends hit", CO, GATE, ""),
    # --- KaijuService
    ("the stomp hits the kaiju's friends", K,
     "\n\t\t\t\tand not friendOfKaiju(p, v) then -- A23-113 ①: in every zone, also where the stomp credits nobody", " then"),
    ("the kaiju's HP counts its friends", K, " and not friendOfKaiju(p, v) then\n\t\t\t\tn += 1", " then\n\t\t\t\tn += 1"),
    ("the stomp spares the friend but marks the event contested", K,
     "\n\t\t\t\tand not friendOfKaiju(p, v) then -- A23-113 ①: in every zone, also where the stomp credits nobody\n"
     "\t\t\t\tlocal hum = Util.GetHumanoid(v)\n",
     " then\n\t\t\t\tif friendOfKaiju(p, v) then contested = true end\n"
     "\t\t\t\tlocal hum = not friendOfKaiju(p, v) and Util.GetHumanoid(v) or nil\n"),
    ("KaijuService never sees friends", K, "\tlocal ok, yes = pcall(pvp.AreFriends, p, v)\n\treturn ok and yes == true\nend",
     "\treturn false\nend"),
    # --- RankingService stays as it was (its own cache, the opposite failure rule)
    ("RankingService: a failed call is no longer friends", R, "\tif not ok then return true end\n",
     "\tif not ok then return false end\n"),
    ("RankingService: friend KOs score", R,
     'if RankingService.EffectiveSeason() ~= "STUDIO" and friends(killer, victim, facts.NoYield == true) then',
     "if false then"),
]

# every DamagePlayer call site in the server (A23-113 ① report): a new one must be checked for the friend rule
DAMAGE_SITES = {
    "CombatService.luau": 2,  # Swing (players from playersNear -> CanAttack), Release / Q (same); attacker = the player
    "SkillService.luau": 1,  # Z / X player hits (kit.PlayersNear -> CanAttack); attacker = the caster
    "KaijuService.luau": 1,  # the stomp: attacker = the kaiju in PvP zones, nil outside (friendOfKaiju skips friends)
    "FirstKOService.luau": 3,  # the King Slime's hits (a monster: attacker nil)
    "MonsterService.luau": 2,  # monster melee / ranged shots (attacker nil)
}


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    pvp = read(SSS / "PvPService.luau")
    can = function_block(pvp, "function PvPService.CanAttack(")
    i_same, i_friend = can.find('return false, "SameFaction"'), can.find('return false, "Friend"')
    i_kaiju, i_neutral = can.find('kstate(victim) == "Active"'), can.find('return false, "Neutral"')
    check(0 <= i_neutral < i_same < i_friend < i_kaiju, "CanAttack: Self / NotReady / Dead / Neutral / SameFaction, then "
          "Friend, then the kaiju exception")
    friend_part = strip_comments(pvp[pvp.find("-- friends (A23-113"):pvp.find("-- public API")])
    check("IsFriendsWith" in friend_part and "pcall(function() return newcomer:IsFriendsWith(other.UserId) end)" in friend_part,
          "the one IsFriendsWith call is wrapped in pcall")
    check("Notify" not in friend_part and "Config.Text" not in friend_part, "no player-facing text for the friend rule")
    are = function_block(pvp, "function PvPService.AreFriends(")
    check("IsFriendsWith" not in are and "task." not in are, "AreFriends reads the cache only (never yields)")
    check(strip_comments(pvp).count("IsFriendsWith") == 1, "PvPService calls IsFriendsWith in one place")

    combat = read(SSS / "CombatService.luau")
    dmg = function_block(combat, "function CombatService.DamagePlayer(")
    g = dmg.find("pvp.AreFriends(attacker, victim)")
    check(0 <= g < dmg.find("lastPvPAttacker[victim] =") and g < dmg.find("hum:TakeDamage(") and g < dmg.find("PlayerDamaged:Fire"),
          "DamagePlayer: the friend gate comes before the combat tag, the damage and PlayerDamaged")

    kaiju = read(SSS / "KaijuService.luau")
    check("friendOfKaiju(p, v)" in function_block(kaiju, "local function stomp("), "the stomp skips the kaiju's friends")
    check("friendOfKaiju(p, v)" in function_block(kaiju, "local function countNearbyHalo("),
          "the kaiju's HP count skips its friends")

    ranking = read(SSS / "RankingService.luau")
    fr = function_block(ranking, "local function friends(")
    check("if not ok then return true end" in fr and "if noYield then return true end" in fr,
          "RankingService's friend rule is unchanged (a failed / unknown pair counts as friends for the boards)")

    for name, want in DAMAGE_SITES.items():
        code = strip_comments(read(SSS / name))
        n = len(re.findall(r"DamagePlayer\(", code)) + len(re.findall(r'"DamagePlayer"', code))
        n -= code.count("function CombatService.DamagePlayer(")
        check(n == want, f"{name}: {want} DamagePlayer call site(s) (found {n}); a new one needs the friend check")
    others = []
    for path in sorted(SSS.glob("*.luau")):
        if path.name in DAMAGE_SITES:
            continue
        code = strip_comments(read(path))
        if re.search(r'DamagePlayer\(|"DamagePlayer"|:TakeDamage\(', code):
            others.append(path.name)
    check(not others, f"no other server file damages players ({others})")
    for name in ("PvPService.luau", "CombatService.luau", "KaijuService.luau"):
        check("<const>" not in read(SSS / name), f"{name}: no <const> locals")
    return count, failures


SUITE = TwoWorlds(
    mark="FRIEND_PVP",
    fixture=ROOT / "tools/fixtures/friend_pvp_offline.luau",
    world=COMBAT_WORLD,
    out=ROOT / "docs/art/verification_2026-10-11/offline_dev2_friend_pvp_2026-10-11.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-113 ①: Roblox friends never damage each other, on different sides and inside PvP areas: manual swings, "
             "Q / Z / X (line, chain, roar, hop wind; fields never hit players) and the kaiju's stomp (in every zone). "
             "PvPService asks Player:IsFriendsWith once per pair in the background when the second of the two is ready "
             "(join order free; 5 calls in a row, the next 5 one second later), pcall, a failed call = not friends, not "
             "friends until the answer; the answer is kept until one of them leaves (a rejoin asks again; a late answer "
             "after a leave is dropped). PvPService.AreFriends reads the cache only. CanAttack returns false, 'Friend' "
             "after Self / NotReady / Dead / Neutral / SameFaction and before the Halo-vs-Active-kaiju exception; "
             "CombatService.DamagePlayer is the last gate (a friend's hit = 0: no combat tag, no KO credit, no "
             "PlayerDamaged). KaijuService's stomp skips the kaiju's friends and its HP count does not count them. "
             "RankingService is unchanged (its own cache; a failed call counts as friends there, friend KOs score nothing).",
    limitations="The real IsFriendsWith web call, its timing and Roblox's own throttling are not run offline (the kit's "
                "Player double answers at once; a call in flight is simulated by a leave inside the double). A friend "
                "KO can still happen from hits that landed before the answer arrived (a few seconds after the second "
                "join); it stays off the boards as before. The client (aim hints, hit numbers) is unchanged.",
)

if __name__ == "__main__":
    run(SUITE)
