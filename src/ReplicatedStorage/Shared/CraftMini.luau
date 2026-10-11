-- CraftMini.luau (게임성 개발 4, ③ 망치질 미니게임; SPEC A23-56 · A23-127 · A23-133, design docs/design/hammer_minigame_2026-10-12.md,
-- server contract 개발 3 craft_server_2026-10-12.md §4 + 게임성 검수 10/12): the hammer minigame's numbers and pure rules in ONE
-- place - the server (CraftService) grades with it, the screen (the ring window) draws with it. No services, no state.
--   schedule : ring i appears at StartAt + (i-1)*(Ring+Rest) and touches the centre at T_i = StartAt + i*Ring + (i-1)*Rest
--              (fixed: a press never moves the next ring); a ring that was not pressed is a Miss once its Good window
--              closes (Closes)
--   grade    : e = |ms - Lag| (ms = press time - T_i in ms, + = late; Lag = the input delay forgiven) -> Perfect <= 70,
--              Great <= 130, Good <= 200, else Miss
--   score    : Perfect 3 · Great 2 · Good 1 · Miss 0; sum >= 13 -> +2, >= 9 -> +1, else +0 (never a failure, A23-56)
--   check    : the server's own offset (when the strike arrived - T_i) minus the client's ms must lie in
--              [-Early, Late + JitterMul * ping ms], else that strike is a Miss (a made-up ms is caught by its arrival)
-- No random part: the same timing always gives the same result.
local CraftMini = {}

CraftMini.T = {
	Strikes = 5, Ring = 1.2, Rest = 0.35, Lead = 0.8, -- s; Lead = from the session to the first ring
	Lag = 40, -- ms forgiven: input / frame delay (The Forge players: "click a bit early")
	Windows = { { "Perfect", 70 }, { "Great", 130 }, { "Good", 200 } }, -- ms around T_i after Lag, best first
	Points = { Perfect = 3, Great = 2, Good = 1, Miss = 0 },
	PlusAt = { { 2, 13 }, { 1, 9 } }, -- { +N, points needed }, best first; below them +0
	MaxMs = 400, -- |ms| a client may report for a strike
	Early = 50, Late = 250, -- ms: the server offset may be this much below / above the client's
	JitterMul = 1.5, -- × the player's ping (ms) added to Late
	Timeout = 20, -- s after StartAt: the server finishes the session at +0
	Grades = { "Perfect", "Great", "Good", "Miss" },
}

local T = CraftMini.T

local function finite(v)
	return type(v) == "number" and v == v and v > -math.huge and v < math.huge
end

-- when ring i appears / touches the centre / stops taking a press (server-time seconds)
function CraftMini.Appear(startAt, i)
	return startAt + (i - 1) * (T.Ring + T.Rest)
end

function CraftMini.Target(startAt, i)
	return startAt + i * T.Ring + (i - 1) * T.Rest
end

function CraftMini.Closes(startAt, i)
	return CraftMini.Target(startAt, i) + (T.Windows[#T.Windows][2] + T.Lag) / 1000
end

-- the last ring's close: the whole minigame is over
function CraftMini.Ends(startAt)
	return CraftMini.Closes(startAt, T.Strikes)
end

-- the live ring at time t (1..Strikes) and how far it has shrunk (0 = just appeared, 1 = on the centre, > 1 = past it),
-- or nil between rings / before / after
function CraftMini.Live(startAt, t)
	if not (finite(startAt) and finite(t)) then return nil, 0 end
	for i = 1, T.Strikes do
		if t >= CraftMini.Appear(startAt, i) and t < CraftMini.Closes(startAt, i) then
			return i, (t - CraftMini.Appear(startAt, i)) / T.Ring
		end
	end
	return nil, 0
end

-- one strike's grade from its offset in ms (+ = late); anything not a real number in range = Miss
function CraftMini.Grade(ms)
	if not finite(ms) or math.abs(ms) > T.MaxMs then return "Miss" end
	local e = math.abs(ms - T.Lag)
	for _, w in T.Windows do
		if e <= w[2] then return w[1] end
	end
	return "Miss"
end

-- the points of the grades (missing ones count as Miss) and the +N they make
function CraftMini.Score(grades)
	local points = 0
	for i = 1, T.Strikes do
		local g = type(grades) == "table" and grades[i] or nil
		points += T.Points[g] or 0
	end
	for _, row in T.PlusAt do
		if points >= row[2] then return points, row[1] end
	end
	return points, 0
end

-- ping (ms) as the check uses it: the bigger of the strike's and the session start's (게임성 검수 10/12: GetNetworkPing is a
-- round trip and jumps - a phone / wifi player must not get a Miss from one quiet moment), clamped to 0..1000
function CraftMini.Ping(pingMs, startPingMs)
	local a = finite(pingMs) and math.clamp(pingMs, 0, 1000) or 0
	local b = finite(startPingMs) and math.clamp(startPingMs, 0, 1000) or 0
	return math.max(a, b)
end

-- the server's check of one strike: its own offset (serverMs) against the client's (ms), widened by the ping
function CraftMini.Check(ms, serverMs, pingMs, startPingMs)
	if not (finite(ms) and finite(serverMs)) then return false end
	local ping = CraftMini.Ping(pingMs, startPingMs)
	local d = serverMs - ms
	return d >= -T.Early and d <= T.Late + T.JitterMul * ping
end

-- the server's grades of a session: strikes[i] = { Ms = the client's offset, At = when the server received it, Ping = the
-- ping (ms) then, optional } for the strikes that came (each checked against the previous one: At_i >= At_(i-1) + Rest);
-- pingMs = the ping now, startPingMs = at the session start (the bigger one counts). Returns the grades (Strikes
-- long), the points and the +N
function CraftMini.Accept(strikes, startAt, pingMs, startPingMs)
	local grades = {}
	local prevAt = -math.huge
	for i = 1, T.Strikes do
		local s = type(strikes) == "table" and strikes[i] or nil
		local g = "Miss"
		if type(s) == "table" and finite(s.Ms) and finite(s.At) and finite(startAt) then
			local serverMs = (s.At - CraftMini.Target(startAt, i)) * 1000
			local ping = math.max(CraftMini.Ping(pingMs, startPingMs), CraftMini.Ping(s.Ping))
			if s.At >= prevAt + T.Rest and CraftMini.Check(s.Ms, serverMs, ping) then g = CraftMini.Grade(s.Ms) end
			prevAt = s.At
		end
		grades[i] = g
	end
	local points, plus = CraftMini.Score(grades)
	return grades, points, plus
end

return CraftMini
