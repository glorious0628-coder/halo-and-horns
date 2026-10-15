-- party_offline.luau : SPEC A23-201 / A23-204 the party + a kill's quest credit (api party2, 2026-10-15). tools/test_party.py
-- binds CONFIG_SOURCE, UTIL_SOURCE, PARTY_SOURCE, CREDIT_SOURCE, WAR_SOURCE, HUNT_SOURCE and STORY_SOURCE in front of
-- dev2_kit.luau + dev3_world.luau; this file follows. The REAL PartyService (remote PartyAction: invite / accept / decline /
-- expire / leave / kick / disband, every argument checked), the REAL QuestCreditService (Hit ledger + Judge: real hitter
-- 15 s / 80 studs / zone, boss 2 hits >= 3 s apart, personal = first hitter + that one's party near, once per spawn), the
-- REAL StoryQuestService.EventAmount (info.Credit: Personal / Shared steps; no Credit = as before), the REAL WarService and
-- HuntFameService (normal monsters stay first-hitter, A23-181; a party boss gives each real hitter's own side its units,
-- A23-204). Doubles: characters (a root part + a Humanoid in a folder), Lighting / TweenService for WarService's sky.

local function partyWorld(o)
	o = o or {}
	local w = dev3World(o)
	local Signal = w.Util.Signal
	local lighting = newInstance("Lighting", w)
	lighting.ClockTime = 14
	w.Services.Lighting = lighting
	w.Services.TweenService = { Create = function(_, inst, info, goal)
		return { Play = function() end, Cancel = function() end, Inst = inst, Goal = goal }
	end }
	w.Counts = { 1, 1 }
	w.Reg.FactionService.GetFaction = function(p) return p:GetAttribute("Faction") or "None" end
	w.Reg.FactionService.GetCounts = function() return w.Counts[1], w.Counts[2] end
	w.Reg.PvPService = { PlayerKO = Signal.new(), ScalePoints = function(points, mult) return math.floor(points * mult + 0.5) end }
	w.Fame = {}
	function w.Reg.PlayerService.GrantFame(p, stat, n, ctx)
		table.insert(w.Fame, { P = p, Stat = stat, N = n, Ctx = ctx })
		w.PS.AddStat(p, stat, n)
	end
	local function load(name, src)
		local env = w:Env()
		env.task = setmetatable({ wait = function(t) return coroutine.yield(t) end }, { __index = env.task })
		local ws = type(env.workspace) == "table" and env.workspace or {}
		env.workspace = setmetatable({ Terrain = newInstance("Terrain", w) }, { __index = ws })
		local inst = env.Instance
		env.Instance = { new = function(cn)
			local x = inst.new(cn)
			if cn == "NumberValue" then x.Changed = Signal.new() end
			return x
		end }
		local m = execute(name, src, env)
		w.Reg[name] = m
		return m
	end
	w.Party = load("PartyService", PARTY_SOURCE)
	w.Credit = load("QuestCreditService", CREDIT_SOURCE)
	w.War = load("WarService", WAR_SOURCE)
	w.Hunt = load("HuntFameService", HUNT_SOURCE)
	w.Story = load("StoryQuestService", STORY_SOURCE) -- EventAmount only (never Init / Start here)
	for _, n in { "PartyService", "QuestCreditService", "WarService", "HuntFameService" } do w.Reg[n].Init(w.Reg) end
	for _, n in { "PartyService", "QuestCreditService", "WarService", "HuntFameService" } do w.Reg[n].Start() end
	w:StartLoops()
	w.Folder = newInstance("Folder", w)
	return w
end

-- a ready hero with a character at (x, z) in `zone`
local function hero(w, id, faction, x, zone)
	local p = w:Arrive(id, { Data = { Faction = faction or "Halo", Class = "Warrior", ClassChosen = true, Level = 5 } })
	local char = newInstance("Model", w)
	char.Parent = w.Folder
	local root = newInstance("Part", w)
	root.Name = "HumanoidRootPart"
	root.Position = vec(x or 0, 0, 0)
	root.Parent = char
	local hum = newInstance("Humanoid", w)
	hum.Health, hum.MaxHealth = 100, 100
	hum.Parent = char
	p.Character = char
	p.Attrs.ZoneId = zone or "SlimeMeadow"
	p.Root, p.Hum = root, hum
	return p
end

local function moveTo(p, x) p.Root.Position = vec(x, 0, 0) end

-- the "Party" payloads sent to p (newest last)
local function sent(w, p, kind)
	local out = {}
	for _, f in w.Fired do
		if f.Remote == "Party" and f.Player == p and (kind == nil or f.Payload.Kind == kind) then table.insert(out, f.Payload) end
	end
	return out
end
local function last(w, p, kind)
	local list = sent(w, p, kind)
	return list[#list]
end
local function act(w, p, ...) w:Remote("PartyAction", p, ...) end
local function lastNotice(w, p)
	local list = w:NoticesFor(p)
	return list[#list]
end
local function ids(payload)
	if type(payload) ~= "table" or type(payload.Members) ~= "table" then return "-" end
	return table.concat(payload.Members, ",")
end
-- a invites b, b accepts: true when b joined
local function join(w, a, b)
	act(w, a, "Invite", b.UserId)
	local inv = last(w, b, "Invite")
	if not inv then return false end
	act(w, b, "Accept", inv.Id)
	return w.Party.SameParty(a, b)
end

------------------------------------------------------------------ config
runGroup("config", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local P = C.Party
	check(type(P) == "table" and P.MinSize == 2 and P.MaxSize == 4 and P.InviteRange == 60 and P.InviteTTL == 30, "party 2~4, invite 60 studs, 30 s", show(P))
	check(P.CreditWindow == 15 and P.CreditRange == 80 and P.BossMinHits == 2 and P.BossHitGap == 3, "credit 15 s / 80 studs, boss 2 hits 3 s apart", show(P))
	check(type(C.RateLimits.PartyAction) == "number" and C.RateLimits.PartyAction > 0, "PartyAction is rate-limited", C.RateLimits.PartyAction)
	local T = C.ClientText.Party
	check(type(T) == "table" and T.Join == "Join" and T.NotNow == "Not now" and type(T.Leave) == "string" and type(T.Invite) == "string",
		"the client's words sit in Config.ClientText.Party", show(T))
	for k, v in P.Text do
		check(type(v) == "string" and #v > 0 and #v <= 40 and not string.find(v, "[\128-\255]"), "the failure lines are short English", k)
	end
end)

------------------------------------------------------------------ invite / accept / decline / expire
runGroup("invite and accept", function()
	local w = partyWorld()
	local a, b = hero(w, 1, "Halo", 0), hero(w, 2, "Horns", 10)
	act(w, a, "Invite", 2)
	local inv = last(w, b, "Invite")
	check(inv ~= nil and inv.From == 1 and type(inv.Id) == "number" and inv.TTL == 30, "an invite card goes to the target (From, Id, TTL)", show(inv))
	check(#sent(w, a, "Invite") == 0 and w.Party.PartyOf(a) == nil, "no party before the accept", "")
	act(w, b, "Accept", inv.Id)
	check(w.Party.SameParty(a, b) and w.Party.PartyOf(a).Leader == a, "accepted: one party, the inviter leads", "")
	local sa, sb = last(w, a, "State"), last(w, b, "State")
	check(sa and sb and ids(sa) == "1,2" and ids(sb) == "1,2" and sa.Leader == 1 and sa.Id > 0, "both get the State (members, leader)", show(sb))
	check(last(w, b, "InviteGone") and last(w, b, "InviteGone").Id == inv.Id, "the card closes on accept", "")
	check(#w:NoticesFor(a) == 0 and #w:NoticesFor(b) == 0, "no line for joining (A23-191)", show(w:NoticesFor(b)))
	-- a third player can not use someone else's card
	local c = hero(w, 3, "Halo", 20)
	act(w, c, "Accept", inv.Id)
	check(w.Party.PartyOf(c) == nil, "another player's InviteId does nothing", "")
	-- a member who is not the leader can not invite
	act(w, b, "Invite", 3)
	check(last(w, c, "Invite") == nil and lastNotice(w, b) == w.Config.Party.Text.Leader, "only the leader invites", show(w:NoticesFor(b)))
	-- the leader invites a third
	check(join(w, a, c) and #w.Party.Members(a) == 3, "a third joins the same party", #w.Party.Members(a))
	-- busy: someone in a party
	local d = hero(w, 4, "Halo", 30)
	local e = hero(w, 5, "Halo", 40)
	check(join(w, d, e), "another party of two", "")
	act(w, a, "Invite", 4)
	check(#sent(w, d, "Invite") == 0 and lastNotice(w, a) == w.Config.Party.Text.Busy, "a player in another party: Busy", show(w:NoticesFor(a)))
end)

runGroup("single use and range", function()
	local w = partyWorld()
	local a, b = hero(w, 1, "Halo", 0), hero(w, 2, "Halo", 10)
	act(w, a, "Invite", 2)
	local inv = last(w, b, "Invite")
	act(w, b, "Accept", inv.Id)
	check(w.Party.SameParty(a, b), "joined", "")
	local c = hero(w, 3, "Halo", 15)
	check(join(w, a, c), "a third joins", "")
	act(w, b, "Leave")
	check(w.Party.PartyOf(b) == nil, "left", "")
	act(w, b, "Accept", inv.Id)
	check(w.Party.PartyOf(b) == nil, "the same InviteId again: single use, nothing", "")
	-- range: a stranger 100 studs away
	local far = hero(w, 4, "Halo", 100)
	act(w, a, "Invite", 4)
	check(#sent(w, far, "Invite") == 0 and lastNotice(w, a) == w.Config.Party.Text.Far, "a stranger farther than 60 studs: no card, Far", show(w:NoticesFor(a)))
	moveTo(far, 55)
	act(w, a, "Invite", 4)
	check(#sent(w, far, "Invite") == 1, "within 60 studs: the card goes", "")
	-- a Roblox friend anywhere on the server
	local w2 = partyWorld({ Friends = { ["1:2"] = true } })
	local f1, f2 = hero(w2, 1, "Halo", 0), hero(w2, 2, "Halo", 900)
	act(w2, f1, "Invite", 2)
	check(#sent(w2, f2, "Invite") == 1, "a friend 900 studs away gets the card", "")
end)

runGroup("decline and expire", function()
	local w = partyWorld()
	local a, b = hero(w, 1, "Halo", 0), hero(w, 2, "Halo", 10)
	act(w, a, "Invite", 2)
	local inv = last(w, b, "Invite")
	act(w, b, "Decline", inv.Id)
	check(last(w, b, "InviteGone") and last(w, b, "InviteGone").Id == inv.Id and w.Party.PartyOf(a) == nil, "declined: the card closes, no party", "")
	act(w, b, "Accept", inv.Id)
	check(w.Party.PartyOf(b) == nil, "a declined invite can not be accepted", "")
	act(w, a, "Invite", 2)
	local inv2 = last(w, b, "Invite")
	check(inv2 and inv2.Id ~= inv.Id, "a new invite has a new Id", show(inv2))
	w:Advance(31) -- no sweep yet: the accept itself checks the time
	act(w, b, "Accept", inv2.Id)
	check(w.Party.PartyOf(b) == nil and lastNotice(w, b) == w.Config.Party.Text.Gone, "accepted after 30 s: Gone", show(w:NoticesFor(b)))
	act(w, a, "Invite", 2)
	local inv3 = last(w, b, "Invite")
	local before = #sent(w, b, "InviteGone")
	w:Tick(31)
	check(#sent(w, b, "InviteGone") == before + 1 and last(w, b, "InviteGone").Id == inv3.Id, "30 s later the sweep closes the card", "")
	-- at most MaxOutgoing open invites
	local others = {}
	for i = 3, 7 do others[i] = hero(w, i, "Halo", i) end
	for i = 3, 7 do act(w, a, "Invite", i) end
	local n = 0
	for i = 3, 7 do n += #sent(w, others[i], "Invite") end
	check(n == w.Config.Party.MaxOutgoing, "at most MaxOutgoing open invites", n)
	-- the inviter joined someone else before the accept: re-checked, Gone
	local w2 = partyWorld()
	local x, y, z = hero(w2, 1, "Halo", 0), hero(w2, 2, "Halo", 5), hero(w2, 3, "Halo", 10)
	act(w2, x, "Invite", 2)
	local cardY = last(w2, y, "Invite")
	check(join(w2, z, x), "the inviter joins another party", "")
	act(w2, y, "Accept", cardY.Id)
	check(w2.Party.PartyOf(y) == nil, "the inviter is no longer a lone leader: the card is gone", "")
end)

------------------------------------------------------------------ leave / kick / disband / full
runGroup("leave kick disband", function()
	local w = partyWorld()
	local a, b, c, d = hero(w, 1, "Halo", 0), hero(w, 2, "Halo", 5), hero(w, 3, "Horns", 10), hero(w, 4, "Halo", 15)
	check(join(w, a, b) and join(w, a, c) and join(w, a, d) and #w.Party.Members(a) == 4, "a party of four", #w.Party.Members(a))
	local e = hero(w, 5, "Halo", 20)
	act(w, a, "Invite", 5)
	check(#sent(w, e, "Invite") == 0 and lastNotice(w, a) == w.Config.Party.Text.Full, "a fifth: Full, no card", show(w:NoticesFor(a)))
	act(w, b, "Kick", 3)
	check(w.Party.SameParty(a, c) and lastNotice(w, b) == w.Config.Party.Text.Leader, "a member can not kick", show(w:NoticesFor(b)))
	act(w, a, "Kick", 3)
	check(w.Party.PartyOf(c) == nil and last(w, c, "State").Id == 0 and #w.Party.Members(a) == 3, "the leader kicks: out, State Id 0", ids(last(w, a, "State")))
	act(w, a, "Kick", 99)
	check(#w.Party.Members(a) == 3, "kicking a stranger: nothing", "")
	act(w, a, "Leave")
	local party = w.Party.PartyOf(b)
	check(w.Party.PartyOf(a) == nil and party and party.Leader == b and last(w, d, "State").Leader == 2, "the leader leaves: the next member leads",
		party and party.Leader and party.Leader.UserId)
	act(w, d, "Leave")
	check(w.Party.PartyOf(b) == nil and last(w, b, "State").Id == 0, "one member left: disbanded", ids(last(w, b, "State")))
	-- leaving the server = leaving the party; that player's cards close
	check(join(w, a, b) and join(w, a, c), "a new party of three", "")
	act(w, a, "Invite", 4)
	local cardD = last(w, d, "Invite")
	w:Leave(a)
	check(w.Party.SameParty(b, c) and w.Party.PartyOf(b).Leader == b and last(w, d, "InviteGone").Id == cardD.Id,
		"the leader left the server: b leads, a's card to d closed", "")
	w:Leave(c)
	check(w.Party.PartyOf(b) == nil, "then one left: disbanded", "")
end)

------------------------------------------------------------------ remote validation
runGroup("remote validation", function()
	local w = partyWorld()
	local a, b = hero(w, 1, "Halo", 0), hero(w, 2, "Halo", 10)
	local bad = {
		{ "Explode", 2 }, { "Invite", "2" }, { "Invite", 2.5 }, { "Invite", 0 / 0 }, { "Invite", -2 }, { "Invite", 1 },
		{ "Invite", math.huge }, { "Invite", 2, 3 }, { "Invite", { 2 } }, {}, { 7 }, { "Leave", 5 }, { "Accept", "1" },
	}
	for _, args in bad do act(w, a, table.unpack(args)) end
	check(#sent(w, b) == 0 and #sent(w, a) == 0 and #w:NoticesFor(a) == 0, "bad arguments: nothing sent, no line", show(sent(w, b)))
	-- rate limit: two calls in one moment
	w.Net.Get("PartyAction").OnServerEvent:Fire(a, "Invite", 2)
	local c = hero(w, 3, "Halo", 5)
	w.Net.Get("PartyAction").OnServerEvent:Fire(a, "Invite", 3)
	check(#sent(w, b, "Invite") == 1 and #sent(w, c, "Invite") == 0, "a second call within the rate limit is dropped", "")
	-- not ready
	local d = hero(w, 4, "Halo", 6)
	w.Ready[d] = nil
	act(w, d, "Invite", 3)
	check(#sent(w, c, "Invite") == 0, "a player not ready yet: nothing", "")
	act(w, a, "Invite", 4)
	check(#sent(w, d, "Invite") == 0, "inviting a player not ready: nothing", "")
	-- switched off
	local w2 = partyWorld({ EditConfig = function(C) C.Party.Enabled = false end })
	local x, y = hero(w2, 1, "Halo", 0), hero(w2, 2, "Halo", 5)
	act(w2, x, "Invite", 2)
	check(#sent(w2, y) == 0, "Config.Party.Enabled = false: nothing", "")
end)

------------------------------------------------------------------ quest credit
local function mob(o)
	o = o or {}
	return { Id = o.Id or 1, ZoneId = o.Zone or "SlimeMeadow", Def = { Boss = o.Boss == true }, Owner = o.Owner }
end
local KILL = vec(0, 0, 0)

runGroup("credit outside a party", function()
	local w = partyWorld()
	local Q = w.Credit
	local a, b, c = hero(w, 1, "Halo", 0), hero(w, 2, "Horns", 10), hero(w, 3, "Halo", 20)
	local r = mob()
	Q.Hit(r, a)
	w:Advance(1)
	Q.Hit(r, b)
	Q.Hit(r, c)
	moveTo(c, 120)
	local cr, extras = Q.Judge(r, KILL, { a, b, c }, a)
	check(cr and cr[a].Personal and cr[a].Shared, "the first hitter: personal + shared", show(cr and cr[a]))
	check(cr[b].Personal == false and cr[b].Shared == true, "another hitter outside a party: shared only (no personal credit)", show(cr[b]))
	check(cr[c].Shared == false and cr[c].Personal == false, "a hitter 120 studs away: nothing", show(cr[c]))
	check(#extras == 0, "no extras", #extras)
	check(Q.Judge(r, KILL, { a, b }, a) == nil, "once per spawn: a second Judge answers nothing", "")
	-- the window: last hit 16 s ago
	local r2 = mob({ Id = 2 })
	Q.Hit(r2, a)
	Q.Hit(r2, b)
	w:Advance(16)
	Q.Hit(r2, a)
	local cr2 = Q.Judge(r2, KILL, { a, b }, a)
	check(cr2[b].Shared == false and cr2[a].Shared == true, "a last hit 16 s ago is no real hit (CreditWindow 15)", show(cr2[b]))
	-- another zone
	local r3 = mob({ Id = 3 })
	Q.Hit(r3, a)
	Q.Hit(r3, b)
	b.Attrs.ZoneId = "GoblinWoods"
	local cr3 = Q.Judge(r3, KILL, { a, b }, a)
	check(cr3[b].Shared == false, "a hitter now in another zone: no credit", show(cr3[b]))
	b.Attrs.ZoneId = "SlimeMeadow"
	-- a real hitter the kill does not pay (under the damage bar) still gets shared credit, as an extra
	local r4 = mob({ Id = 4 })
	Q.Hit(r4, a)
	Q.Hit(r4, b)
	local cr4, ex4 = Q.Judge(r4, KILL, { a }, a)
	check(#ex4 == 1 and ex4[1] == b and cr4[b].Shared and not cr4[b].Personal, "an unpaid real hitter: an extra with shared credit", show(cr4[b]))
end)

runGroup("credit inside a party", function()
	local w = partyWorld()
	local Q = w.Credit
	local a, b, c, d = hero(w, 1, "Halo", 0), hero(w, 2, "Horns", 10), hero(w, 3, "Halo", 20), hero(w, 4, "Halo", 30)
	check(join(w, a, b) and join(w, a, c), "a party of a, b, c", "")
	local r = mob()
	Q.Hit(r, a)
	Q.Hit(r, b)
	Q.Hit(r, d)
	w.PS.MarkActive(c)
	local cr, extras = Q.Judge(r, KILL, { a, b, d }, a)
	check(cr[b].Personal == true, "a party member who hit: personal credit", show(cr[b]))
	check(cr[d].Personal == false and cr[d].Shared == true, "a hitter outside the party: shared only", show(cr[d]))
	check(#extras == 1 and extras[1] == c and cr[c].Personal == true and cr[c].Shared == false,
		"a member near the kill who did not hit (active): personal credit as an extra", show(cr[c]))
	-- the member is far / idle / down
	local r2 = mob({ Id = 2 })
	Q.Hit(r2, a)
	moveTo(c, 200)
	local cr2, ex2 = Q.Judge(r2, KILL, { a }, a)
	check(cr2[c] == nil and table.find(ex2, c) == nil and cr2[b] and cr2[b].Personal == true and cr2[b].Shared == false,
		"a member 200 studs away: nothing (b, near and active since joining, still gets it)", show(cr2[c]))
	moveTo(c, 20)
	w:Advance(40)
	local r3 = mob({ Id = 3 })
	Q.Hit(r3, a)
	local cr3 = Q.Judge(r3, KILL, { a }, a)
	check(cr3[c] == nil, "a member idle for 40 s: nothing (no AFK riders)", show(cr3[c]))
	w.PS.MarkActive(c)
	c.Hum.Health = 0
	local r4 = mob({ Id = 4 })
	Q.Hit(r4, a)
	local cr4 = Q.Judge(r4, KILL, { a }, a)
	check(cr4[c] == nil, "a member knocked out: nothing", show(cr4[c]))
	c.Hum.Health = 100
	-- the first hitter is outside the party: the party's own hits get no personal credit
	local r5 = mob({ Id = 5 })
	Q.Hit(r5, d)
	Q.Hit(r5, a)
	Q.Hit(r5, b)
	local cr5 = Q.Judge(r5, KILL, { d, a, b }, d)
	check(cr5[d].Personal and not cr5[a].Personal and not cr5[b].Personal and cr5[a].Shared,
		"another first hitter: the party members get shared credit only", show(cr5))
end)

runGroup("boss credit", function()
	local w = partyWorld()
	local Q = w.Credit
	local a, b, c, d = hero(w, 1, "Halo", 0), hero(w, 2, "Horns", 10), hero(w, 3, "Halo", 20), hero(w, 4, "Horns", 30)
	check(join(w, a, b), "a party of a (Halo) and b (Horns)", "")
	local r = mob({ Boss = true })
	Q.Hit(r, a) -- a: one hit only
	Q.Hit(r, b)
	Q.Hit(r, c)
	Q.Hit(r, d)
	w:Advance(1)
	Q.Hit(r, c) -- c: 2 hits 1 s apart = 1 counted
	w:Advance(2)
	Q.Hit(r, b) -- b: 2 hits 3 s apart
	Q.Hit(r, d)
	local cr = Q.Judge(r, KILL, { a, b, c, d }, a)
	check(cr[a].Personal == false and cr[a].Shared == false, "a boss: one hit is no credit, first hitter or not", show(cr[a]))
	check(cr[c].Shared == false, "two hits 1 s apart count as one", show(cr[c]))
	check(cr[b].Personal and cr[b].Shared and cr[b].PartyBoss, "two hits 3 s apart in a party: credit + PartyBoss", show(cr[b]))
	check(cr[d].Personal and cr[d].Shared and cr[d].PartyBoss == false, "a real hitter outside a party: credit, no PartyBoss", show(cr[d]))
end)

------------------------------------------------------------------ quest steps read the credit
runGroup("quest steps", function()
	local w = partyWorld()
	local p = hero(w, 1, "Halo", 0)
	local personal = { Type = "Kill", Kind = "Slime", Count = 5 }
	local joint = { Type = "Kill", Kind = "Slime", Count = 5, Credit = "Shared" }
	local function amount(obj, credit)
		return w.Story.EventAmount(p, obj, { Kind = "Kill", Info = { Kind = "Slime", ZoneId = "SlimeMeadow", WarPoints = 1, Credit = credit } })
	end
	check(amount(personal, nil) == 1 and amount(joint, nil) == 1, "no Credit (old callers, personal monsters): counts as before", "")
	check(amount(personal, { Personal = true, Shared = true }) == 1 and amount(joint, { Personal = true, Shared = true }) == 1, "credited both ways: counts", "")
	check(amount(personal, { Personal = false, Shared = true }) == 0, "a personal step: no personal credit = 0", "")
	check(amount(joint, { Personal = false, Shared = true }) == 1, "a joint step: shared credit = 1", "")
	check(amount(joint, { Personal = true, Shared = false }) == 0, "a joint step: a member who never hit = 0", "")
	local crown = { Type = "WarPoints", Count = 15 }
	check(amount(crown, { Personal = false, Shared = true }) == 0 and amount(crown, { Personal = true, Shared = false }) == 1,
		"a crown step is a personal step too", "")
end)

------------------------------------------------------------------ crown units and hunt honor
runGroup("crown and honor", function()
	local w = partyWorld()
	local C = w.Config
	local a, b, c = hero(w, 1, "Halo", 0), hero(w, 2, "Horns", 10), hero(w, 3, "Halo", 20)
	local function fire(p, o)
		w.Reg.MonsterService.MonsterKilled:Fire(p, { Kind = "Slime", ZoneId = "SlimeMeadow", WarPoints = C.War.MonsterPoints,
			WarShare = o.Share or C.War.MonsterPoints, First = o.First, PartyBoss = o.PartyBoss, Credit = o.Credit })
	end
	-- a normal monster: still the first hitter's (A23-181), whatever the quest credit says
	fire(a, { First = true, Credit = { Personal = true, Shared = true } })
	fire(b, { First = false, Credit = { Personal = true, Shared = true } })
	check(w.War.GetKillUnits(a) == C.War.MonsterPoints and w.War.GetKillUnits(b) == 0, "normal monster: crown units to the first hitter only",
		show({ w.War.GetKillUnits(a), w.War.GetKillUnits(b) }))
	local da, db = w.Data[a], w.Data[b]
	check((da.HuntFame or 0) == 1 and (db.HuntFame or 0) == 0, "normal monster: hunt honor to the first hitter only", show({ da.HuntFame, db.HuntFame }))
	-- a party boss: each real hitter in a party gets the units for their own side; hunt honor stays first-hitter
	fire(b, { First = false, PartyBoss = true, Share = 0.5 })
	check(w.War.GetKillUnits(b) == C.War.MonsterPoints and (db.HuntFame or 0) == 0, "party boss: a Horns member gets Horns' crown units, no hunt honor",
		show({ w.War.GetKillUnits(b), db.HuntFame }))
	fire(c, { First = false })
	check(w.War.GetKillUnits(c) == 0, "a boss hitter outside a party (no PartyBoss): nothing, as before", w.War.GetKillUnits(c))
end)

finish()
