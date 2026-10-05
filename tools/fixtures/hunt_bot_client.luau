-- ============================================================================================================
-- TEST-ONLY HUNT BOT -- ONLY FOR THE WORKER'S OWN TEST PLAY (reviewer item 8, 2026-10-06)
-- GUARD: never run this while the user is playing. It moves the character (Humanoid:MoveTo) and fires the
--   Swing / Release remotes by itself, which counts as moving the user's game (AGENTS.md hard rule 6).
--   Start it only in a Play session the worker started for its own test; poll it with
--   `py tools/bot_wait.py --mine` (that tool refuses to run without --mine).
-- RESULTS: a scripted, perfectly efficient hunter -> report every number ONLY as a "bot upper bound".
--   Never use these numbers to change rewards, prices, XP or drop rates; those need real human play data.
-- ============================================================================================================
-- Test-only "efficient human" hunter for kill-rate measurements (run in MY test Play via execute_luau, Client).
-- Walks to the nearest living meadow monster, presses attack once per class SwingInterval when in reach and the
-- skill when MP / cooldown allow and a monster is near -- the same remotes the F / Q keys fire. Never targets players.
-- _G.HHC_BOT = { Running, Log = {...} }; stop with _G.HHC_BOT.Running = false
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Net = require(RS.Shared.Net)
local Config = require(RS.Shared.Config)
local me = Players.LocalPlayer
local SECONDS = tonumber(_G.HHC_BOT_SECONDS) or 180
_G.HHC_BOT = { Running = true, Log = {} }
local bot = _G.HHC_BOT
local function attr(k, d) local v = me:GetAttribute(k); if v == nil then return d end return v end
task.spawn(function()
	local t0 = os.clock()
	local k0, g0, x0, l0 = attr("TotalKills", 0), attr("BankGold", 0) + attr("CarriedGold", 0), attr("XP", 0), attr("Level", 1)
	local nextSwing, swings, skills = 0, 0, 0
	local firstHitAt = nil
	while bot.Running and os.clock() - t0 < SECONDS do
		local char = me.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local def = Config.Classes[attr("Class", "Warrior")] or Config.Classes.Warrior
		if root and hum and hum.Health > 0 then
			local best, bd = nil, math.huge
			local folder = workspace:FindFirstChild("Monsters")
			for _, m in ipairs(folder and folder:GetChildren() or {}) do
				local r = m:FindFirstChild("HumanoidRootPart")
				local mh = m:FindFirstChildOfClass("Humanoid")
				if r and (not mh or mh.Health > 0) and (m.Name == "Slime" or m.Name == "BigSlime") then
					local d = (r.Position - root.Position).Magnitude
					if d < bd then best, bd = r, d end
				end
			end
			local reach = math.max(3, (def.Range or 10) - 2)
			if best then
				if bd > reach then
					hum:MoveTo(best.Position)
				else
					hum:MoveTo(root.Position)
					if os.clock() >= nextSwing then
						Net.Get("Swing"):FireServer()
						swings += 1
						firstHitAt = firstHitAt or (os.clock() - t0)
						nextSwing = os.clock() + (def.SwingInterval or 1) + 0.05
					end
					local cost = (Config.BasicSkill and Config.BasicSkill.ManaCost) or 20
					if attr("Mana", 0) >= cost and workspace:GetServerTimeNow() >= attr("SkillReadyAt", 0) then
						Net.Get("Release"):FireServer()
						skills += 1
					end
				end
			end
		end
		task.wait(0.1)
	end
	local mins = (os.clock() - t0) / 60
	bot.Result = {
		Kind = "bot upper bound", -- never a human measurement; never use it to change rewards/prices
		Class = attr("Class", "?"), Minutes = mins,
		Kills = attr("TotalKills", 0) - k0, KPM = (attr("TotalKills", 0) - k0) / mins,
		Gold = attr("BankGold", 0) + attr("CarriedGold", 0) - g0, LevelFrom = l0, LevelTo = attr("Level", 1),
		Swings = swings, Skills = skills, FirstSwingAt = firstHitAt,
	}
	bot.Running = false
end)
return "bot started"
