-- BoardService.luau : E11 hunting-field job boards (docs/design/quest_volume_2026-10-06.md §3-3 / §4, 검수 OK
-- 2026-10-07). Config.Board: each field's board (Meadow, Woods) shows this player Cards cards built from the J1..J10
-- templates with the field's own values; a card is taken as [Kind] or [Sneaky] (the side is only counted in
-- data.Story.N: no honor / infamy / ranking points, A23-23 D1); a player carries up to Hold jobs. A finished job pays
-- at once (HuntValue(the board's Level, 1); x AfterMult after FullPerDay jobs a KST day; the BonusAt-th job of a day
-- also gives BonusItem, once) and says which way the shard leaned. A taken or swapped card is replaced by a template
-- that is not one of that board's last two. Nothing ever times out, fails or disappears (kid-friendly).
-- Enabled = false (until game dev 1's board window ships): the remote does nothing and QuestService keeps its extra
-- quests; on, a claimed daily slot stays empty and the boards take that role (QuestService.extraOrEmpty).
-- data.Board = { Day, Done, Bonus, RerollAt, Held = { { Id, Board, Side, Target, P } }, Cards = { [board] = { id.. } },
--   Recent = { [board] = { id, id } } }
-- Remote c->s "BoardAction"(boardId, "Open" | "Take" | "Reroll", slot 1..Cards, side "Kind" | "Sneaky"): the player
-- must stand within Range of the board spot (Config.StoryQuests.Landmarks[board.Spot]). s->c "Board": the payload of
-- payloadFor (owner only).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local BoardService = {}
local S = nil
local TAG = "BoardService"
local B = Config.Board or {}
local TICK = 1
-- J10 Near.Stay: [Player] = { [job id .. ":" .. board] = os.clock() when the player came inside } (session only)
local stays = {}

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function on()
	return B.Enabled == true
end

local function getData(player)
	local ok, data = pcall(S.PlayerService.GetData, player)
	return ok and type(data) == "table" and data or nil
end

local function notify(player, text, kind, sound)
	if type(text) == "string" and text ~= "" then pcall(Net.Notify, player, text, kind or "info", nil, sound) end
end

local function dirty(player)
	if S.QuestService and type(S.QuestService.MarkDirty) == "function" then pcall(S.QuestService.MarkDirty, player) end
end

------------------------------------------------------------------ data
local function jobDef(id)
	for _, j in B.Jobs or {} do
		if j.Id == id then return j end
	end
	return nil
end

local function state(data)
	local st = data.Board
	if type(st) ~= "table" then
		st = {}
		data.Board = st
	end
	if type(st.Held) ~= "table" then st.Held = {} end
	if type(st.Cards) ~= "table" then st.Cards = {} end
	if type(st.Recent) ~= "table" then st.Recent = {} end
	st.Done = math.max(0, math.floor(num(st.Done)))
	st.Bonus = st.Bonus == true
	-- a new KST day: the full-reward count and the bonus start again (held jobs and cards stay)
	local today = Config.DayIndex(os.time())
	if num(st.Day) ~= today then
		st.Day, st.Done, st.Bonus = today, 0, false
	end
	return st
end

-- drop unknown boards / jobs and bad numbers (an old or edited save never breaks the board)
local function sanitize(data)
	local st = state(data)
	local held = {}
	for _, h in st.Held do
		if type(h) == "table" and jobDef(h.Id) and type(B.Boards) == "table" and B.Boards[h.Board]
			and (h.Side == "Kind" or h.Side == "Sneaky") and #held < num(B.Hold, 3) then
			h.Target = math.max(1, math.floor(num(h.Target, 1)))
			h.P = math.clamp(num(h.P), 0, h.Target)
			table.insert(held, h)
		end
	end
	st.Held = held
	for id, cards in st.Cards do
		if type(B.Boards) ~= "table" or not B.Boards[id] or type(cards) ~= "table" then st.Cards[id] = nil end
	end
end

------------------------------------------------------------------ cards
-- the job's objective with this board's values ("$Unit", "$Big", "$Arrival", "$Camp", "$Gate")
local function objFor(job, board)
	local o = {}
	for k, v in job.Obj do
		if type(v) == "string" and string.sub(v, 1, 1) == "$" then
			o[k] = board[string.sub(v, 2)]
		else
			o[k] = v
		end
	end
	return o
end

local function countFor(job, boardId)
	local c = type(job.Count) == "table" and job.Count[boardId] or job.Count
	return math.max(1, math.floor(num(c, 1)))
end

-- a template this player can do at all: Auto Battle unlocked for NeedAuto, A23-71 a skill learned for NeedSkill (the
-- first skill comes at Lv5)
local function canDo(player, job)
	if job.NeedAuto and player:GetAttribute("AutoCombatUnlocked") ~= true then return false end
	return not job.NeedSkill or Config.SkillLearned(player:GetAttribute("SkillSlots"), player:GetAttribute("Level"),
		player:GetAttribute("Rebirths"))
end

-- a template this player can do on this board, not shown already and not one of its last two
local function eligible(player, job, boardId, avoid)
	if avoid[job.Id] then return false end
	if not canDo(player, job) then return false end
	local only = job.Boards
	return only == nil or only[boardId] == true
end

local function pick(player, boardId, avoid)
	local pool, total = {}, 0
	for _, job in B.Jobs or {} do
		if eligible(player, job, boardId, avoid) then
			table.insert(pool, job)
			total += math.max(0, num(job.Weight, 3))
		end
	end
	if #pool == 0 then return nil end
	local r = Util.Random:NextNumber() * total
	for _, job in pool do
		local w = math.max(0, num(job.Weight, 3))
		if r < w then return job.Id end
		r -= w
	end
	return pool[#pool].Id
end

local function avoidSet(st, boardId, cards, except)
	local avoid = {}
	for i, id in cards do
		if i ~= except then avoid[id] = true end
	end
	for _, id in st.Recent[boardId] or {} do avoid[id] = true end
	return avoid
end

local function remember(st, boardId, id)
	local recent = st.Recent[boardId] or {}
	table.insert(recent, 1, id)
	while #recent > 2 do table.remove(recent) end
	st.Recent[boardId] = recent
end

-- a board with SafeIds (the PvP woods) always keeps at least one card that is done outside the PvP zone
local function keepSafe(player, st, boardId, cards)
	local safe = B.Boards[boardId].SafeIds
	if type(safe) ~= "table" then return end
	for _, id in cards do
		if safe[id] then return end
	end
	local avoid = avoidSet(st, boardId, cards, #cards)
	for id in safe do avoid[id] = nil end
	local choices = {}
	for _, job in B.Jobs or {} do
		if safe[job.Id] and eligible(player, job, boardId, avoid) then table.insert(choices, job.Id) end
	end
	table.sort(choices)
	if #choices > 0 then cards[#cards] = choices[Util.Random:NextInteger(1, #choices)] end
end

local function cardsOf(player, st, boardId)
	local cards = st.Cards[boardId]
	if type(cards) ~= "table" then cards = {} end
	-- saved cards stay while the player can do them (A23-71 S11: a 'Hit 3 at once' card saved before the first skill is
	-- swapped for another job)
	local valid = {}
	for _, id in cards do
		local job = jobDef(id)
		if job and canDo(player, job) and #valid < num(B.Cards, 4) then table.insert(valid, id) end
	end
	cards = valid
	while #cards < num(B.Cards, 4) do
		local id = pick(player, boardId, avoidSet(st, boardId, cards, 0))
		if not id then break end
		table.insert(cards, id)
	end
	keepSafe(player, st, boardId, cards)
	st.Cards[boardId] = cards
	return cards
end

-- the card in `slot` is replaced by a new template (not on the board, not one of the last two)
local function replaceCard(player, st, boardId, slot)
	local cards = cardsOf(player, st, boardId)
	local old = cards[slot]
	if old then remember(st, boardId, old) end
	local id = pick(player, boardId, avoidSet(st, boardId, cards, slot))
	if id then cards[slot] = id end
	keepSafe(player, st, boardId, cards)
end

------------------------------------------------------------------ rewards
local function reward(boardId, done)
	local board = B.Boards[boardId]
	local g, x = Config.HuntValue(math.max(1, num(board.Level, 1)), 1)
	if done >= num(B.FullPerDay, 10) then
		g, x = math.floor(g * num(B.AfterMult, 0.5)), math.floor(x * num(B.AfterMult, 0.5))
	end
	return math.max(1, math.floor(g)), math.max(1, math.floor(x))
end

local function goalText(job, board, h)
	local t = string.gsub(job.Goal or job.Id, "{(%w+)}", function(key)
		local id = board[key]
		local m = type(id) == "string" and Config.MonsterTypes[id]
		return (m and (m.Short or m.Name)) or (type(board[key .. "Name"]) == "string" and board[key .. "Name"]) or tostring(id)
	end)
	local ok, text = pcall(string.format, t, math.floor(num(h.P)), h.Target)
	return ok and text or t
end

local function finish(player, data, index)
	local st = state(data)
	local h = st.Held[index]
	if not h then return end
	-- saved first: the job leaves the list before anything is paid, so it can never pay twice
	table.remove(st.Held, index)
	if stays[player] then stays[player][h.Id .. ":" .. h.Board] = nil end
	local g, x = reward(h.Board, st.Done)
	st.Done += 1
	-- A23-75: what was really added (the 2x passes) is what the line below shows
	g = S.ProgressionService.AddBankGold(player, g, "Quest") or g
	x = S.ProgressionService.AddXP(player, x) or x
	local story = type(data.Story) == "table" and data.Story or {}
	data.Story = story
	if type(story.N) ~= "table" then story.N = {} end
	story.N[h.Side] = math.floor(num(story.N[h.Side])) + 1
	local T = B.Text or {}
	notify(player, string.format(T.Done or "Job done! +%s gold · +%s XP", Util.FormatNumber(g), Util.FormatNumber(x)), "reward",
		"QuestDone")
	notify(player, h.Side == "Kind" and T.LeanKind or T.LeanSneaky, "info")
	if st.Done == num(B.BonusAt, 5) and not st.Bonus then
		st.Bonus = true -- saved before the scroll
		local loot = S.LootService
		if type(loot) == "table" and type(loot.GrantItem) == "function" and type(B.BonusItem) == "string" then
			local ok, given = pcall(loot.GrantItem, player, B.BonusItem, 1)
			if not ok then Util.Warn(TAG, "GrantItem: " .. tostring(given)) end
			local item = Config.Loot.Items[B.BonusItem]
			if ok and num(given) > 0 then
				notify(player, string.format(T.Bonus or "%s", item and item.Name or B.BonusItem), "reward", "None")
			end
		end
	end
	dirty(player)
end

------------------------------------------------------------------ progress
local function feed(player, ev)
	if not on() then return end
	local data = getData(player)
	if not data then return end
	local st = state(data)
	local story = S.StoryQuestService
	if type(story) ~= "table" or type(story.EventAmount) ~= "function" then return end
	for i = #st.Held, 1, -1 do
		local h = st.Held[i]
		local job = jobDef(h.Id)
		local board = job and B.Boards[h.Board]
		if job and board and job.Obj.Type ~= "Near" then
			local ok, add = pcall(story.EventAmount, player, objFor(job, board), ev)
			if ok and num(add) > 0 then
				h.P = math.min(h.Target, num(h.P) + num(add))
				dirty(player)
				if h.P >= h.Target then finish(player, data, i) end
			end
		end
	end
end

-- J10: stand within Radius of the spot for Target seconds in one go (leaving starts again)
local function tickStays(player)
	local data = getData(player)
	if not data then return end
	local st = state(data)
	local root = Util.GetRoot(player)
	local mine = stays[player]
	for i = #st.Held, 1, -1 do
		local h = st.Held[i]
		local job = jobDef(h.Id)
		local board = job and B.Boards[h.Board]
		if job and board and job.Obj.Type == "Near" then
			local o = objFor(job, board)
			local spot = Config.StoryQuests.Landmarks[o.Spot]
			local key = h.Id .. ":" .. h.Board
			local inside = spot ~= nil and root ~= nil and Util.FlatDistance(root.Position, spot) <= num(o.Radius, 14)
			if inside then
				if not mine then
					mine = {}
					stays[player] = mine
				end
				mine[key] = mine[key] or os.clock()
				local held = math.min(h.Target, math.floor(os.clock() - mine[key]))
				if held ~= num(h.P) then
					h.P = held
					dirty(player)
				end
				if held >= h.Target then finish(player, data, i) end
			else
				if mine then mine[key] = nil end
				if num(h.P) ~= 0 then
					h.P = 0
					dirty(player)
				end
			end
		end
	end
end

------------------------------------------------------------------ the board payload + remote
local function payloadFor(player, data, boardId)
	local st = state(data)
	local board = B.Boards[boardId]
	local cards = {}
	local g, x = reward(boardId, st.Done)
	for i, id in cardsOf(player, st, boardId) do
		local job = jobDef(id)
		local kindText = type(job.Kind) == "table" and (job.Kind[boardId] or job.Kind.All) or job.Kind
		local sneakyText = type(job.Sneaky) == "table" and (job.Sneaky[boardId] or job.Sneaky.All) or job.Sneaky
		table.insert(cards, { Slot = i, Id = id, Kind = kindText, Sneaky = sneakyText,
			Goal = goalText(job, board, { P = 0, Target = countFor(job, boardId) }), Target = countFor(job, boardId),
			RewardGold = g, RewardXP = x })
	end
	local n = type(data.Story) == "table" and type(data.Story.N) == "table" and data.Story.N or {}
	return { Board = boardId, Cards = cards, Held = #st.Held, Hold = num(B.Hold, 3), Done = st.Done,
		FullPerDay = num(B.FullPerDay, 10), Kind = math.floor(num(n.Kind)), Sneaky = math.floor(num(n.Sneaky)),
		RerollAt = num(st.RerollAt) }
end

local function send(player, data, boardId)
	local ok, err = pcall(function()
		Net.Get("Board"):FireClient(player, payloadFor(player, data, boardId))
	end)
	if not ok then Util.Warn(TAG, "Board send: " .. tostring(err)) end
end

local function nearBoard(player, board)
	local spot = Config.StoryQuests.Landmarks[board.Spot]
	local root = Util.GetRoot(player)
	return spot ~= nil and root ~= nil and Util.FlatDistance(root.Position, spot) <= num(B.Range, 14)
end

local function onBoardAction(player, boardId, action, slot, side, ...)
	if not on() then return end
	if select("#", ...) ~= 0 or type(boardId) ~= "string" or type(action) ~= "string" then return end
	if not S.PlayerService.IsReady(player) then return end
	if not Util.RateLimit(player, "BoardAction", (Config.RateLimits and Config.RateLimits.BoardAction) or 0.3) then return end
	local board = type(B.Boards) == "table" and B.Boards[boardId] or nil
	local data = getData(player)
	if not board or not data or not nearBoard(player, board) then return end
	local st = state(data)
	if action == "Open" then
		send(player, data, boardId)
		return
	end
	if type(slot) ~= "number" or slot ~= slot or slot % 1 ~= 0 or slot < 1 or slot > num(B.Cards, 4) then return end
	local cards = cardsOf(player, st, boardId)
	if not cards[slot] then return end
	if action == "Take" then
		if side ~= "Kind" and side ~= "Sneaky" then return end
		if #st.Held >= num(B.Hold, 3) then
			notify(player, (B.Text or {}).Full, "info")
			return
		end
		local job = jobDef(cards[slot])
		table.insert(st.Held, { Id = job.Id, Board = boardId, Side = side, Target = countFor(job, boardId), P = 0 })
		st.Seen = true -- the hint row goes away
		replaceCard(player, st, boardId, slot)
		dirty(player)
		send(player, data, boardId)
	elseif action == "Reroll" then
		if side ~= nil then return end
		local now = os.time()
		if now < num(st.RerollAt) then return end
		replaceCard(player, st, boardId, slot)
		st.RerollAt = now + num(B.RerollCooldown, 60)
		send(player, data, boardId)
	end
end

------------------------------------------------------------------ public
-- the held jobs as quest-list rows (QuestService.publish; Kind "Job", no [Claim]: a job pays when it is done)
function BoardService.JobRows(player, data)
	if not on() or type(data) ~= "table" then return {} end
	local st = state(data)
	local rows = {}
	-- quest_volume §4: after M1_4 one "Job Board · tap for directions" row guides to the meadow board until the first
	-- job is taken (st.Seen)
	local done = type(data.Story) == "table" and type(data.Story.Done) == "table" and data.Story.Done or {}
	if st.Seen ~= true and #st.Held == 0 and done[B.HintAfter or "M1_4"] and type(B.HintBoard) == "string"
		and B.Boards[B.HintBoard] then
		table.insert(rows, { Id = "job:board", Kind = "Job", Pinned = false, Text = (B.Text or {}).Hint or "Job Board",
			ShortName = (B.Text or {}).HintShort,
			Progress = 0, Target = 1, RewardGold = 0, RewardXP = 0, CanClaim = false, ShowProgress = false,
			Job = { Board = B.HintBoard, Guide = B.Boards[B.HintBoard].Spot } })
	end
	for i, h in st.Held do
		local job = jobDef(h.Id)
		local board = job and B.Boards[h.Board]
		if job and board then
			local g, x = reward(h.Board, st.Done)
			table.insert(rows, {
				Id = "job:" .. i, Kind = "Job", Pinned = false, Text = goalText(job, board, h), ShortName = job.ShortName,
				Progress = math.floor(num(h.P) * 10) / 10, Target = h.Target, RewardGold = g, RewardXP = x,
				CanClaim = false, ShowProgress = h.Target > 1,
				Job = { Board = h.Board, Side = h.Side, Card = h.Id, Guide = board.Zone },
			})
		end
	end
	return rows
end

function BoardService.IsOn()
	return on()
end

local function connect(serviceName, signalName, fn)
	local service = S[serviceName]
	local signal = service and service[signalName]
	if type(signal) == "table" and type(signal.Connect) == "function" then
		signal:Connect(fn)
	else
		Util.Warn(TAG, "missing signal " .. serviceName .. "." .. signalName)
	end
end

function BoardService.Init(registry)
	S = registry
end

function BoardService.Start()
	Net.Get("BoardAction").OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(onBoardAction, player, ...)
		if not ok then Util.Warn(TAG, "BoardAction: " .. tostring(err)) end
	end)
	connect("MonsterService", "MonsterKilled", function(player, info)
		if type(info) == "table" and typeof(player) == "Instance" and player:IsA("Player") then
			feed(player, { Kind = "Kill", Info = info })
		end
	end)
	connect("CombatService", "Released", function(player, info)
		if type(info) == "table" then feed(player, { Kind = "Skill", Info = info }) end
	end)
	connect("ProgressionService", "GoldEarned", function(player, amount, source)
		feed(player, { Kind = "Gold", Amount = amount, Source = source })
	end)
	connect("PlayerService", "PlayerReady", function(player)
		local data = getData(player)
		if data then pcall(sanitize, data) end
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			if on() then
				for _, p in S.PlayerService.GetReadyPlayers() do
					local ok, err = pcall(tickStays, p)
					if not ok then Util.Warn(TAG, "stay: " .. tostring(err)) end
				end
			end
			for p in stays do
				if p.Parent == nil then stays[p] = nil end
			end
		end
	end)
	print("[BoardService] started" .. (on() and "" or " (off: Config.Board.Enabled = false)"))
end

return BoardService
