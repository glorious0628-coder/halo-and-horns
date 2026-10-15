-- PartyService.luau : SPEC A23-201 the party, server side (게임성 개발 2 / api party2, 2026-10-15; docs/design/
-- party_guild_2026-10-15.md §1, party chunk only). Server-authoritative, nothing saved (a party lives on this server only).
--   * c->s "PartyAction"(op, arg), Config.RateLimits.PartyAction, ready players only, every argument checked:
--     "Invite"(userId): a ready player on this server, not me, not in a party; I am alone or my party's leader; the party
--       has room (members + nothing else counted); a Roblox friend (IsFriendsWith, pcall, cached) or within
--       Config.Party.InviteRange studs; at most MaxOutgoing open invites of mine, one per target. The target gets
--       { Kind = "Invite", Id, From, TTL } (a card); the invite lives InviteTTL s.
--     "Accept"(inviteId): mine, not expired; used up at once (single use), then everything is checked again (the inviter
--       still here, I am still alone, the inviter's party is the one it was and has room). A lone inviter + me = a new party
--       with the inviter as leader.
--     "Decline"(inviteId): mine -> gone. "Leave"(): out of my party (the leader passes to the next member). "Kick"(userId):
--       the leader only, a member of the party. One member left = the party is disbanded.
--   * s->c "Party": { Kind = "State", Id, Leader, Members } to every member on each change ({ Id = 0 } = no party),
--     { Kind = "InviteGone", Id } when a card closes (expired / declined / used / the inviter left).
--   * Read API (QuestCreditService, the client state): PartyOf(player) -> the party table { Id, Leader, Members } or nil,
--     SameParty(a, b), Members(player) -> a copy of the member list, JoinSeq(player) -> the membership stamp (a new number on
--     every join, nil outside a party: a member who left and came back is a new membership, docs §1-2 epoch).
--     PartyService.Changed(party or nil, player) fires for every player whose party changed.
-- Failure lines only (A23-191: Kind "bad", Config.Party.Text); no banner, no toast for joining or leaving.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local PartyService = {}
PartyService.Changed = Util.Signal.new() -- (party or nil, player)

local TAG = "PartyService"
local S = nil
local P = Config.Party or {}
local TXT = P.Text or {}

local T = {
	Parties = {}, -- [id] = { Id, Leader = Player, Members = { Player } }
	Of = {}, -- [Player] = party
	Invites = {}, -- [inviteId] = { Id, From = Player, To = Player, At = os.clock(), PartyId = number or 0 }
	Friend = {}, -- ["<low>:<high>"] = true / false (cached for the server's life)
	NextParty = 0,
	NextInvite = 0,
	Join = {}, -- [Player] = membership stamp (docs §1-2 epoch: QuestCreditService never credits a membership newer than the hit)
	NextJoin = 0,
}

-- the one place a membership starts or ends (party nil = out); a join takes a new stamp
local function setOf(player, party)
	T.Of[player] = party
	if party then
		T.NextJoin += 1
		T.Join[player] = T.NextJoin
	else
		T.Join[player] = nil
	end
end

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function isPlayer(p)
	return typeof(p) == "Instance" and p:IsA("Player")
end

local function here(p)
	return isPlayer(p) and p.Parent ~= nil and S.PlayerService.IsReady(p)
end

local function notify(player, text)
	if type(text) ~= "string" or text == "" then return end
	local ok, err = pcall(Net.Notify, player, text, "bad")
	if not ok then Util.Warn(TAG, "notify: " .. tostring(err)) end
end

local function send(player, payload)
	if not isPlayer(player) or player.Parent == nil then return end
	local ok, err = pcall(function() Net.Get("Party"):FireClient(player, payload) end)
	if not ok then Util.Warn(TAG, "send: " .. tostring(err)) end
end

local function wholeId(v)
	return type(v) == "number" and v == v and v >= 1 and v <= 2 ^ 52 and v == math.floor(v)
end

------------------------------------------------------------------ state
local function pushState(party, player)
	if party == nil then
		send(player, { Kind = "State", Id = 0, Leader = 0, Members = {} })
		return
	end
	local ids = {}
	for _, m in party.Members do table.insert(ids, m.UserId) end
	send(player, { Kind = "State", Id = party.Id, Leader = party.Leader.UserId, Members = ids })
end

local function pushAll(party)
	for _, m in party.Members do pushState(party, m) end
end

local function changed(party, player)
	local ok, err = pcall(function() PartyService.Changed:Fire(party, player) end)
	if not ok then Util.Warn(TAG, "changed: " .. tostring(err)) end
end

local function closeInvite(id)
	local inv = T.Invites[id]
	if not inv then return end
	T.Invites[id] = nil
	send(inv.To, { Kind = "InviteGone", Id = id })
end

-- every open invite from or to a player (leaving, joining)
local function closeInvitesOf(player, fromToo)
	for id, inv in T.Invites do
		if inv.To == player or (fromToo and inv.From == player) then closeInvite(id) end
	end
end

local function disband(party)
	T.Parties[party.Id] = nil
	for _, m in party.Members do
		setOf(m, nil)
		pushState(nil, m)
		changed(nil, m)
	end
	party.Members = {}
	-- the leader's open invites point at a party that is gone
	for id, inv in T.Invites do
		if inv.PartyId == party.Id then closeInvite(id) end
	end
end

-- a member goes out (leave / kick / left the server); the leader passes on; 1 left = disbanded
local function removeMember(player)
	local party = T.Of[player]
	if not party then return false end
	local i = table.find(party.Members, player)
	if i then table.remove(party.Members, i) end
	setOf(player, nil)
	pushState(nil, player)
	changed(nil, player)
	if party.Leader == player then
		party.Leader = party.Members[1]
		for id, inv in T.Invites do -- the old leader's invites go with them
			if inv.From == player then closeInvite(id) end
		end
	end
	if #party.Members < num(P.MinSize, 2) then
		disband(party)
	else
		pushAll(party)
		for _, m in party.Members do changed(party, m) end
	end
	return true
end

------------------------------------------------------------------ checks
local function pairKey(a, b)
	if a > b then a, b = b, a end
	return tostring(a) .. ":" .. tostring(b)
end

local function isFriend(a, b)
	local key = pairKey(a.UserId, b.UserId)
	if T.Friend[key] == nil then
		local ok, res = pcall(a.IsFriendsWith, a, b.UserId)
		if not ok then return false end -- not cached: asked again next time
		T.Friend[key] = res == true
	end
	return T.Friend[key] == true
end

local function near(a, b, range)
	local ra, rb = Util.GetRoot(a), Util.GetRoot(b)
	if not ra or not rb then return false end
	local okD, d = pcall(function() return (ra.Position - rb.Position).Magnitude end)
	return okD and type(d) == "number" and d <= range
end

local function openFrom(player)
	local n = 0
	for _, inv in T.Invites do
		if inv.From == player then n += 1 end
	end
	return n
end

------------------------------------------------------------------ actions
local function invite(player, userId)
	if not wholeId(userId) or userId == player.UserId then return end
	local target = Players:GetPlayerByUserId(userId)
	if not target or target == player or not here(target) then return end
	local mine = T.Of[player]
	if mine and mine.Leader ~= player then
		notify(player, TXT.Leader)
		return
	end
	if T.Of[target] then
		notify(player, TXT.Busy)
		return
	end
	if mine and #mine.Members >= num(P.MaxSize, 4) then
		notify(player, TXT.Full)
		return
	end
	for _, inv in T.Invites do
		if inv.From == player and inv.To == target then return end -- the card is already open
	end
	if openFrom(player) >= num(P.MaxOutgoing, 3) then return end
	if not near(player, target, num(P.InviteRange, 60)) and not isFriend(player, target) then
		notify(player, TXT.Far)
		return
	end
	T.NextInvite += 1
	local id = T.NextInvite
	T.Invites[id] = { Id = id, From = player, To = target, At = os.clock(), PartyId = mine and mine.Id or 0 }
	send(target, { Kind = "Invite", Id = id, From = player.UserId, TTL = num(P.InviteTTL, 30) })
end

local function accept(player, id)
	if not wholeId(id) then return end
	local inv = T.Invites[id]
	if not inv or inv.To ~= player then return end
	closeInvite(id) -- single use: gone whatever happens next
	local from = inv.From
	if os.clock() - inv.At > num(P.InviteTTL, 30) or not here(from) then
		notify(player, TXT.Gone)
		return
	end
	if T.Of[player] then return end
	local party = T.Of[from]
	if (party and party.Id or 0) ~= inv.PartyId or (party and party.Leader ~= from) then
		notify(player, TXT.Gone)
		return
	end
	if party and #party.Members >= num(P.MaxSize, 4) then
		notify(player, TXT.Full)
		return
	end
	if not party then
		T.NextParty += 1
		party = { Id = T.NextParty, Leader = from, Members = { from } }
		T.Parties[party.Id] = party
		setOf(from, party)
		-- the inviter's other open invites now bring people into this party
		for _, other in T.Invites do
			if other.From == from then other.PartyId = party.Id end
		end
	end
	table.insert(party.Members, player)
	setOf(player, party)
	closeInvitesOf(player, true) -- my own cards and the ones I sent
	if #party.Members >= num(P.MaxSize, 4) then
		for oid, other in T.Invites do
			if other.PartyId == party.Id then closeInvite(oid) end
		end
	end
	pushAll(party)
	for _, m in party.Members do changed(party, m) end
	S.PlayerService.MarkActive(player)
end

local function decline(player, id)
	if not wholeId(id) then return end
	local inv = T.Invites[id]
	if not inv or inv.To ~= player then return end
	closeInvite(id)
end

local function kick(player, userId)
	if not wholeId(userId) or userId == player.UserId then return end
	local party = T.Of[player]
	if not party then return end
	if party.Leader ~= player then
		notify(player, TXT.Leader)
		return
	end
	local target = nil
	for _, m in party.Members do
		if m.UserId == userId then target = m end
	end
	if not target then return end
	removeMember(target)
end

local OPS = {
	Invite = function(player, arg) invite(player, arg) end,
	Accept = function(player, arg) accept(player, arg) end,
	Decline = function(player, arg) decline(player, arg) end,
	Leave = function(player, arg)
		if arg ~= nil then return end
		removeMember(player)
	end,
	Kick = function(player, arg) kick(player, arg) end,
}

local function onAction(player, ...)
	local n = select("#", ...)
	if n < 1 or n > 2 then return end
	local op, arg = ...
	if type(op) ~= "string" or OPS[op] == nil then return end
	if arg ~= nil and type(arg) ~= "number" then return end
	if P.Enabled == false or not here(player) then return end
	if not Util.RateLimit(player, "PartyAction", num(Config.RateLimits.PartyAction, 0.4)) then return end
	OPS[op](player, arg)
end

-- expired invites close (the card goes away on the client)
local function sweep()
	local now = os.clock()
	local ttl = num(P.InviteTTL, 30)
	for id, inv in T.Invites do
		if now - inv.At > ttl or not here(inv.From) or not here(inv.To) then closeInvite(id) end
	end
end

local function onLeaving(player)
	closeInvitesOf(player, true)
	removeMember(player)
	for key in T.Friend do -- the cache keyed by this player's id is dropped (small table)
		local a, b = string.match(key, "^(%d+):(%d+)$")
		if tonumber(a) == player.UserId or tonumber(b) == player.UserId then T.Friend[key] = nil end
	end
end

------------------------------------------------------------------ lifecycle
function PartyService.Init(registry)
	S = registry
end

function PartyService.Start()
	Net.Get("PartyAction").OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(onAction, player, ...)
		if not ok then Util.Warn(TAG, "PartyAction: " .. tostring(err)) end
	end)
	S.PlayerService.PlayerLeaving:Connect(function(player)
		local ok, err = pcall(onLeaving, player)
		if not ok then Util.Warn(TAG, "leave: " .. tostring(err)) end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(sweep)
			if not ok then Util.Warn(TAG, "sweep: " .. tostring(err)) end
		end
	end)
	print("[PartyService] started")
end

------------------------------------------------------------------ read API
function PartyService.PartyOf(player)
	return T.Of[player]
end

function PartyService.SameParty(a, b)
	local pa = T.Of[a]
	return pa ~= nil and a ~= b and pa == T.Of[b]
end

function PartyService.JoinSeq(player)
	return T.Join[player]
end

function PartyService.Members(player)
	local party = T.Of[player]
	return party and table.clone(party.Members) or {}
end

return PartyService
