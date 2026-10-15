"""The party + a kill's quest credit (SPEC A23-201 / A23-204; api party2, 2026-10-15), offline.

PartyService: c->s PartyAction (op "Invite" | "Accept" | "Decline" | "Leave" | "Kick", arg UserId | InviteId), rate-limited,
ready players only, every argument checked; 2~4 players; an invite to a Roblox friend or a player within 60 studs, only by a
lone player or the leader, at most MaxOutgoing open; a single-use InviteId re-checked on accept (inviter here, still the same
party with room), closed after 30 s (InviteGone); leave (the leader passes on), kick (leader only), one member left =
disbanded; leaving the server = leaving the party. QuestCreditService: a real hitter = last hit within 15 s, in the zone,
within 80 studs; a boss needs 2 hits >= 3 s apart; Shared = every real hitter; Personal = the first hitter + that one's
party members near (alive, active within 30 s); outside a party the first hitter only; once per spawn. StoryQuestService.
EventAmount reads info.Credit (obj.Credit "Shared" = joint step); no Credit = as before. WarService / HuntFameService:
normal monsters stay first-hitter (A23-181); info.PartyBoss gives a party boss hitter their own side's crown units
(A23-204). Runs the CURRENT Config, Util, PartyService, QuestCreditService, WarService, HuntFameService and
StoryQuestService on tools/fixtures/dev2_kit.luau + tools/fixtures/dev3_world.luau with tools/fixtures/party_offline.luau;
static checks for the MonsterService / QuestService / BoardService wiring and the client (Party.luau, PlayerListUI, MiniMap).

Usage: py tools/test_party.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-15/offline_party_2026-10-15.json
"""
from __future__ import annotations

import re
import subprocess

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run, strip_comments

SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "PARTY_SOURCE": SSS / "PartyService.luau",
    "CREDIT_SOURCE": SSS / "QuestCreditService.luau",
    "WAR_SOURCE": SSS / "WarService.luau",
    "HUNT_SOURCE": SSS / "HuntFameService.luau",
    "STORY_SOURCE": SSS / "StoryQuestService.luau",
}
P, Q, W, ST = "PARTY_SOURCE", "CREDIT_SOURCE", "WAR_SOURCE", "STORY_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    # --- PartyService
    ("accept ignores the 30 s", P, "if os.clock() - inv.At > num(P.InviteTTL, 30) or not here(from) then", "if not here(from) then"),
    ("the sweep never expires a card", P, "if now - inv.At > ttl or not here(inv.From) or not here(inv.To) then closeInvite(id) end",
     "if not here(inv.From) or not here(inv.To) then closeInvite(id) end"),
    ("the leader never passes on", P, "\t\tparty.Leader = party.Members[1]\n", ""),
    ("no disband at one member", P, "if #party.Members < num(P.MinSize, 2) then", "if #party.Members < 1 then"),
    ("anyone kicks", P, "\tif party.Leader ~= player then\n\t\tnotify(player, TXT.Leader)\n\t\treturn\n\tend\n\tlocal target = nil",
     "\tlocal target = nil"),
    ("any member invites", P, "\tif mine and mine.Leader ~= player then\n\t\tnotify(player, TXT.Leader)\n\t\treturn\n\tend\n", ""),
    ("no invite range", P, "if not near(player, target, num(P.InviteRange, 60)) and not isFriend(player, target) then", "if false then"),
    ("no friend exception", P, "if not near(player, target, num(P.InviteRange, 60)) and not isFriend(player, target) then",
     "if not near(player, target, num(P.InviteRange, 60)) then"),
    ("a fifth member", P, "\tif mine and #mine.Members >= num(P.MaxSize, 4) then\n", "\tif false then\n"),
    ("busy players invited", P, "\tif T.Of[target] then\n\t\tnotify(player, TXT.Busy)\n\t\treturn\n\tend\n", ""),
    ("no outgoing cap", P, "\tif openFrom(player) >= num(P.MaxOutgoing, 3) then return end\n", ""),
    ("extra arguments accepted", P, "\tif n < 1 or n > 2 then return end\n", ""),
    ("no rate limit", P, "\tif not Util.RateLimit(player, \"PartyAction\", num(Config.RateLimits.PartyAction, 0.4)) then return end\n", ""),
    ("a player not ready acts", P, "if P.Enabled == false or not here(player) then return end", "if P.Enabled == false then return end"),
    ("the switch is ignored", P, "if P.Enabled == false or not here(player) then return end", "if not here(player) then return end"),
    ("someone else's card accepted", P, "\tif not inv or inv.To ~= player then return end\n\tcloseInvite(id) -- single use",
     "\tif not inv then return end\n\tcloseInvite(id) -- single use"),
    ("leaving the server keeps the party", P, "\tcloseInvitesOf(player, true)\n\tremoveMember(player)\n", "\tcloseInvitesOf(player, true)\n"),
    ("no State on change", P, "\t\tpushAll(party)\n\t\tfor _, m in party.Members do changed(party, m) end\n\tend\n\treturn true",
     "\t\tfor _, m in party.Members do changed(party, m) end\n\tend\n\treturn true"),
    # --- QuestCreditService
    ("personal credit for every hitter", Q, "\t\t\tif set and set[p] then c.Personal", "\t\t\tif true then c.Personal"),
    ("no party snapshot at the hit", Q, "\t\tfor _, m in party.Members do snap[m] = joinOf(m) or true end\n\t\te.Party, e.Snap = party, snap\n",
     "\t\tfor _, m in party.Members do snap[m] = joinOf(m) or true end\n\t\te.Party, e.Snap = nil, nil\n"),
    ("no epoch check", Q, "return partyOf(p) == party and snap[p] ~= nil and snap[p] == (joinOf(p) or true)",
     "return partyOf(p) == party"),
    ("a rejoin keeps its stamp", P, "\t\tT.NextJoin += 1\n", ""),
    ("proxy basic kills", ST, "\t\tif info.QuestOnly == true and (t == \"BasicKill\" or t == \"AutoKill\" or t == \"SafeKill\") then return 0 end\n", ""),
    ("no credit window", Q, "if type(e) ~= \"table\" or now - num(e.Last, -math.huge) > window then return false end",
     "if type(e) ~= \"table\" then return false end"),
    ("no credit range", Q, "return ok and type(d) == \"number\" and d <= num(P.CreditRange, 80)", "return true"),
    ("a boss on one hit", Q, "\t\tif boss and num(e.Counted) < minHits then return false end\n", ""),
    ("boss hits without a gap", Q, "if now - e.CountedAt >= num(P.BossHitGap, 3) then", "if true then"),
    ("judged twice", Q, "if type(rec) ~= \"table\" or rec._creditDone == true then return nil, {} end",
     "if type(rec) ~= \"table\" then return nil, {} end"),
    ("AFK party riders", Q, "return ok and type(at) == \"number\" and os.clock() - at <= num(P.ActiveWindow, 30)", "return true"),
    ("knocked-out riders", Q, "\tif not hum or num(hum.Health) <= 0 then return false end\n", ""),
    ("party boss for loners", Q, "c.PartyBoss = r and partyOf(p) ~= nil", "c.PartyBoss = r"),
    ("another zone credited", Q, "\tif rec.Owner == nil and rec.ZoneId ~= nil and zoneOf(p) ~= rec.ZoneId then return false end\n", ""),
    ("no extras", Q, "\t\t\t\ttable.insert(extras, p)\n", ""),
    # --- StoryQuestService / WarService
    ("quest steps ignore the credit", ST,
     "\t\tif type(info.Credit) == \"table\" and info.Credit[obj.Credit == \"Shared\" and \"Shared\" or \"Personal\"] ~= true then return 0 end\n", ""),
    ("joint steps read personal credit", ST, "info.Credit[obj.Credit == \"Shared\" and \"Shared\" or \"Personal\"]", "info.Credit[\"Personal\"]"),
    ("no party boss crown", W, "\t\t\t\telseif info.PartyBoss == true then\n", "\t\t\t\telseif false then\n"),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    main = read(SSS / "Main.server.luau")
    init = re.search(r"local INIT_ORDER = \{(.*?)\n\}", main, re.S)
    start = re.search(r"local START_ORDER = \{(.*?)\n\}", main, re.S)
    names = re.compile(r'"(\w+)"')
    init_list = names.findall(init.group(1)) if init else []
    start_list = names.findall(start.group(1)) if start else []
    for svc in ("PartyService", "QuestCreditService"):
        check(init_list.count(svc) == 1 and start_list.count(svc) == 1, f"{svc} is in both server lists once")
        check(svc in start_list and start_list.index(svc) < start_list.index("PlayerService"), f"{svc} starts before PlayerService")
    mon = strip_comments(read(SSS / "MonsterService.luau"))
    check("MonsterService.QuestKill = Util.Signal.new()" in mon, "MonsterService.QuestKill exists")
    check("pcall(S.QuestCreditService.Hit, record, player)" in mon, "DamageMonster feeds the credit ledger (pcall)")
    check("pcall(S.QuestCreditService.Judge, rec, pos, paidList, firstP)" in mon and "if not isPersonal and S and S.QuestCreditService then" in mon,
          "killRecord asks Judge for shared monsters only (personal ones keep the old rules)")
    check("i.Credit = creditOf(e.Player)" in mon and "i.Credit = creditOf(p)" in mon and "MonsterService.QuestKill:Fire(p, i)" in mon,
          "MonsterKilled carries info.Credit; credited players the kill does not pay get QuestKill")
    check("credit[e.Player].PartyBoss == true" in mon, "MonsterKilled carries info.PartyBoss")
    check(mon.count("MonsterKilled:Fire(") == 2, "MonsterKilled still fires once per paid player + free riders (QuestKill pays nothing)")
    quest = strip_comments(read(SSS / "QuestService.luau"))
    check("if type(info.Credit) == \"table\" and info.Credit.Personal ~= true then return end" in quest and "S.MonsterService.QuestKill" in quest,
          "daily jobs: personal credit only, QuestKill counted")
    board = strip_comments(read(SSS / "BoardService.luau"))
    check("S.MonsterService.QuestKill" in board, "BoardService counts QuestKill (EventAmount reads the credit)")
    story = strip_comments(read(SSS / "StoryQuestService.luau"))
    check("S.MonsterService.QuestKill" in story, "StoryQuestService counts QuestKill")
    hunt = strip_comments(read(SSS / "HuntFameService.luau"))
    check("PartyBoss" not in hunt and "Credit" not in hunt, "hunt honor never reads the party credit (A23-181 stays)")
    net = read(SHARED / "Net.luau")
    check('"PartyAction",' in net and '"Party",' in net, "Net has PartyAction and Party")
    cm = read(SPS / "ClientMain.client.luau")
    order = re.search(r"local ORDER = \{([^}]*)\}", cm)
    check(order is not None and '"Party"' in order.group(1), "ClientMain loads Party")
    party = strip_comments(read(SPS / "Party.luau"))
    check("Config.ClientText.Party" in party and "TXT.Join" in party and "TXT.NotNow" in party and "TXT.Leave" in party,
          "the card / frame words come from Config.ClientText.Party")
    check("Toast" not in party and "Notify" not in party, "no banner / toast for party events (A23-191)")
    check('send("Accept", card.Id)' not in party and 'answer("Accept")' in party and 'answer("Decline")' in party,
          "[Join] / [Not now] answer with the card's InviteId")
    lst = strip_comments(read(SPS / "PlayerListUI.luau"))
    check("party.Invite" in lst and "PartyInvite" in lst, "the Tab list row has the [Party] button (Party.Invite)")
    mm = strip_comments(read(SPS / "MiniMap.luau"))
    check("party.Marked" in mm and "T.FriendDot" in mm, "the minimap draws party members / friends bigger")
    # every changed file compiles
    compiler = ROOT / "build/luau_cli_0_741/luau-compile.exe"
    paths = [SPS / "Party.luau", SPS / "PlayerListUI.luau", SPS / "MiniMap.luau", SPS / "ClientMain.client.luau",
             SSS / "MonsterService.luau", SSS / "QuestService.luau", SSS / "BoardService.luau", SSS / "Main.server.luau",
             SHARED / "Net.luau"]
    if compiler.is_file():
        proc = subprocess.run([str(compiler), *(str(p) for p in paths)], cwd=ROOT, stdout=subprocess.DEVNULL,
                              stderr=subprocess.PIPE, text=True, encoding="utf-8", errors="replace", timeout=180)
        check(proc.returncode == 0, "luau-compile: the client modules and the wired services compile " + proc.stderr.strip()[:300])
    else:
        check(False, "luau-compile missing")
    return count, failures


SUITE = Suite(
    mark="PARTY",
    fixture=ROOT / "tools/fixtures/party_offline.luau",
    world=ROOT / "tools/fixtures/dev3_world.luau",
    out=ROOT / "docs/art/verification_2026-10-15/offline_party_2026-10-15.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract=__doc__.split("Usage:")[0].strip(),
    limitations="MonsterService.killRecord's wiring (info.Credit, QuestKill, PartyBoss) is checked statically, not run with "
                "the credit service; the client (Party.luau frames, card, Tab button, minimap dots) is compiled and checked "
                "statically only - its look and phone fit need a Studio Play with 2+ accounts.",
)

if __name__ == "__main__":
    run(SUITE)
