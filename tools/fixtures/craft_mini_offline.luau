-- ③ 망치질 판정 (게임성 개발 4, 2026-10-12): runs the real Shared/CraftMini.luau (tools/test_craft_mini.py). Input: MINI_SOURCE.
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then
		print("CHECK_OK " .. name)
	else
		failed += 1
		print("CHECK_FAIL " .. name .. " :: " .. tostring(detail))
	end
end
local M = assert(loadstring(MINI_SOURCE, "=CraftMini"))()
local T = M.T

-- 0. the agreed numbers (design §2, 게임성 검수 10/12)
check(T.Strikes == 5 and T.Ring == 1.2 and T.Rest == 0.35 and T.Lag == 40, "5 strikes, 1.2 s rings, 0.35 s rest, 40 ms forgiven")
check(T.Windows[1][1] == "Perfect" and T.Windows[1][2] == 70 and T.Windows[2][2] == 130 and T.Windows[3][2] == 200,
	"windows Perfect 70 / Great 130 / Good 200 ms")
check(T.Timeout == 20, "the server finishes an unfinished session after 20 s")

-- 1. schedule (fixed)
local S = 100
check(math.abs(M.Target(S, 1) - 101.2) < 1e-9 and math.abs(M.Target(S, 2) - 102.75) < 1e-9 and math.abs(M.Target(S, 5) - 107.4) < 1e-9,
	"T_i = StartAt + i*Ring + (i-1)*Rest", M.Target(S, 5))
check(math.abs(M.Appear(S, 2) - 101.55) < 1e-9, "ring 2 appears Rest after ring 1 touched", M.Appear(S, 2))
check(math.abs(M.Closes(S, 1) - 101.44) < 1e-9 and math.abs(M.Ends(S) - 107.64) < 1e-9, "a ring closes at T + (Good + Lag)", M.Ends(S))
local i, f = M.Live(S, 100.6)
check(i == 1 and math.abs(f - 0.5) < 1e-9, "half way through ring 1", tostring(i) .. " " .. tostring(f))
i = M.Live(S, 101.5)
check(i == nil, "the rest between rings has no live ring", i)
i = M.Live(S, 101.6)
check(i == 2, "ring 2 live after the rest", i)
check(M.Live(S, 107.7) == nil and M.Live(S, 99) == nil, "nothing before / after")

-- 2. grades (boundaries, +40 forgiven)
local cases = { { 40, "Perfect" }, { 110, "Perfect" }, { 111, "Great" }, { -30, "Perfect" }, { -31, "Great" }, { 170, "Great" },
	{ 171, "Good" }, { 240, "Good" }, { 241, "Miss" }, { -90, "Great" }, { -91, "Good" }, { -160, "Good" }, { -161, "Miss" } }
for _, c in cases do
	check(M.Grade(c[1]) == c[2], "grade " .. c[1] .. " ms = " .. c[2], M.Grade(c[1]))
end
check(M.Grade(nil) == "Miss" and M.Grade(false) == "Miss" and M.Grade(0 / 0) == "Miss" and M.Grade(math.huge) == "Miss" and M.Grade(401) == "Miss",
	"no press / not a number / out of range = Miss")

-- 3. score -> +N
local function sc(g) local p, n = M.Score(g) return p, n end
local p, n = sc({ "Perfect", "Perfect", "Perfect", "Perfect", "Great" })
check(p == 14 and n == 2, "14 points = +2", p)
p, n = sc({ "Perfect", "Perfect", "Perfect", "Great", "Great" })
check(p == 13 and n == 2, "13 points = +2 (the line)", p)
p, n = sc({ "Perfect", "Perfect", "Great", "Great", "Great" })
check(p == 12 and n == 1, "12 points = +1", p)
p, n = sc({ "Perfect", "Perfect", "Perfect", "Miss", "Miss" })
check(p == 9 and n == 1, "9 points = +1 (the line)", p)
p, n = sc({ "Great", "Great", "Great", "Good", "Good" })
check(p == 8 and n == 0, "8 points = +0", p)
p, n = sc({})
check(p == 0 and n == 0, "all Miss = +0, still made (never a failure)", p)
p, n = sc({ "Perfect", "Bogus" })
check(p == 3 and n == 0, "unknown grades count as Miss", p)

-- 4. the server's check (a made-up ms is caught by when it arrived)
check(M.Check(40, 100, 0), "arrived 60 ms after the press: fine")
check(M.Check(40, -5, 0) and not M.Check(40, -11, 0), "at most 50 ms earlier than the client said", M.Check(40, -11, 0))
check(M.Check(40, 290, 0) and not M.Check(40, 291, 0), "at most 250 ms later without ping")
check(M.Check(40, 430, 100) and not M.Check(40, 441, 100), "ping 100 ms widens it by 150", M.Check(40, 441, 100))
check(not M.Check(nil, 100, 0) and not M.Check(40, 0 / 0, 0), "no number = no")

-- 5. a whole session on the server
local function at(i, ms, lag) return { Ms = ms, At = M.Target(S, i) + (ms + (lag or 60)) / 1000 } end
local g, pts, plus = M.Accept({ at(1, 40), at(2, 60), at(3, 20), at(4, 90), at(5, 0) }, S, 50)
check(table.concat(g, ",") == "Perfect,Perfect,Perfect,Perfect,Perfect" and plus == 2, "a real good player: all Perfect, +2", table.concat(g, ","))
g, pts, plus = M.Accept({ at(1, 40), nil, at(3, 200), at(4, 300) }, S, 50)
check(g[2] == "Miss" and g[3] == "Good" and g[4] == "Miss" and g[5] == "Miss", "missing strikes are Miss, late ones graded", table.concat(g, ","))
-- a script that sends 'Perfect' numbers at the wrong times (all at once right after the start)
local fake = {}
for k = 1, 5 do fake[k] = { Ms = 40, At = S + 0.1 + k * 0.4 } end
g, pts, plus = M.Accept(fake, S, 50)
check(plus == 0 and g[1] == "Miss" and g[5] == "Miss", "made-up Perfect numbers sent at the wrong times = Miss, +0", table.concat(g, ","))
-- the right times but numbers that do not match them (claims 40 ms, really pressed 300 ms late)
fake = {}
for k = 1, 5 do fake[k] = { Ms = 40, At = M.Target(S, k) + 0.36 } end
g = M.Accept(fake, S, 0)
check(g[1] == "Miss" and g[3] == "Miss", "a claimed offset that its arrival disproves = Miss", table.concat(g, ","))
-- two strikes too close together
local close = { at(1, 40), { Ms = 40, At = at(1, 40).At + 0.1 } }
g = M.Accept(close, S, 0)
check(g[1] == "Perfect" and g[2] == "Miss", "a strike less than Rest after the previous = Miss", table.concat(g, ","))
check(select(3, M.Accept(nil, S, 0)) == 0 and select(3, M.Accept({}, nil, 0)) == 0, "no strikes / no start = +0 (Skip)")

print(string.format("CRAFT_MINI_SUMMARY checks=%d failed=%d", checks, failed))
