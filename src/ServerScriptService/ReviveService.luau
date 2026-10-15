-- ReviveService.luau : 99N G (계획 8, 최종 검수 10/14) helping a friend up (게임성 개발 2, server only).
-- A KO'd player (Halo / Horns / Neutral) with a living friend of the same side within Config.Revive.WaitNear studs waits
-- Wait s instead of the usual RespawnTime (PlayerService asks GetUp, after FirstKOService), and the body gets a
-- ProximityPrompt (Config.Revive.PromptName, G, HoldDuration Hold, MaxActivationDistance Range; attributes Side and
-- ReviveUserId: the client shows it to the same side only). A friend of the same side who holds it Hold s (the server
-- keeps when the hold began: ProximityPromptService.PromptButtonHoldBegan, so a quick Triggered is refused), stands
-- within Range (+ RangeSlack) of the body, is alive, past their Cooldown and has an HP potion: the potion is used, the
-- KO'd player gets up there (PlayerService.Respawn; GetUp gives the spot) with HPPct of MaxHealth and the spawn
-- shield cut to Shield s, and the helper gets Fame Honor (Halo) / Infamy (Horns) like hunting (PlayerService.GrantFame,
-- ctx { Revive = true }; Neutral: none). Another side is always refused (also in PvP). The KO'd player may get up in
-- town at once (c->s ReviveSkip, no arguments).
--   Attribute (KO'd player): ReviveUntil = server time the wait ends (0 = none).
--   Fx: "ReviveWait" { Sec } to the KO'd player (a friend is near); "Revived" { By = UserId } to the one helped.
--   ReviveService.Revived(helper, target)  ReviveService.Try(helper, target) -> true | reason  GetUp(player)
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local ReviveService = {}
ReviveService.Revived = Util.Signal.new() -- (helper, target)

local S = nil
local TAG = "ReviveService"
local R = Config.Revive or {}
local SIDES = { Halo = true, Horns = true, Neutral = true }
local STAT = { Halo = "Honor", Horns = "Infamy" }
-- Down[player] = { Character, Pos, Prompt, Side, Until = os.clock(), Revived }; Hold[helper] = { Prompt, At };
-- LastAt[helper] = os.clock() of the last help
local ST = {
	Down = setmetatable({}, { __mode = "k" }),
	Hold = setmetatable({}, { __mode = "k" }),
	LastAt = setmetatable({}, { __mode = "k" }),
}

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function isPlayer(x)
	return typeof(x) == "Instance" and x:IsA("Player")
end

local function on()
	return R.Enabled == true
end

local function sideOf(player)
	local fs = S.FactionService
	if type(fs) ~= "table" or type(fs.GetFaction) ~= "function" then return "None" end
	local ok, f = pcall(fs.GetFaction, player)
	return ok and type(f) == "string" and f or "None"
end

local function rootOf(character)
	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function alive(player)
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0 and rootOf(character) ~= nil
end

-- a living friend of the same side within WaitNear studs of pos (not the KO'd player)
local function friendNear(player, side, pos)
	for _, other in Players:GetPlayers() do
		if other ~= player and sideOf(other) == side and alive(other)
			and (rootOf(other.Character).Position - pos).Magnitude <= num(R.WaitNear, 40) then
			return true
		end
	end
	return false
end

local function clear(player)
	local d = ST.Down[player]
	ST.Down[player] = nil
	if d and d.Prompt then pcall(d.Prompt.Destroy, d.Prompt) end
	if d and player.Parent then player:SetAttribute("ReviveUntil", 0) end
end

-- PlayerService's get-up (after FirstKOService): the wait while a friend may help, the body's spot once helped
function ReviveService.GetUp(player)
	local d = ST.Down[player]
	if not d then return nil end
	if d.Revived then return { Delay = 0, CFrame = CFrame.new(d.Pos + Vector3.new(0, 3, 0)) } end
	return { Delay = num(R.Wait, 10) }
end

local function firstKOHolds(player)
	local svc = S.FirstKOService
	if type(svc) ~= "table" or type(svc.GetUp) ~= "function" then return false end
	local ok, g = pcall(svc.GetUp, player)
	return ok and g ~= nil
end

local function onDied(player, character)
	clear(player)
	if not on() or not isPlayer(player) or firstKOHolds(player) then return end
	local side = sideOf(player)
	local root = rootOf(character)
	if not SIDES[side] or not root then return end
	local pos = root.Position
	if not friendNear(player, side, pos) then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = R.PromptName
	prompt.ActionText = R.Text.Action
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = num(R.Hold, 3)
	prompt.MaxActivationDistance = num(R.Range, 6)
	prompt.KeyboardKeyCode = Enum.KeyCode.G
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Side", side)
	prompt:SetAttribute("ReviveUserId", player.UserId)
	prompt.Parent = root
	local wait = num(R.Wait, 10)
	ST.Down[player] = { Character = character, Pos = pos, Prompt = prompt, Side = side, Until = os.clock() + wait }
	player:SetAttribute("ReviveUntil", workspace:GetServerTimeNow() + wait)
	Net.Fx(player, "ReviveWait", { Sec = wait })
end

-- the KO'd player of a prompt (nil = not one of ours)
local function targetOf(prompt)
	for p, d in ST.Down do
		if d.Prompt == prompt then return p end
	end
	return nil
end

-- the help itself (every rule checked here; the prompt only says who and when)
function ReviveService.Try(helper, target)
	if not on() then return "Off" end
	if not isPlayer(helper) or not isPlayer(target) or helper == target or helper.Parent ~= Players then return "Bad" end
	if not S.PlayerService.IsReady(helper) then return "Bad" end
	local d = ST.Down[target]
	if not d or d.Revived or target.Parent ~= Players or os.clock() > d.Until then return "Gone" end
	if sideOf(helper) ~= d.Side then return "Side" end -- another side never (in PvP too)
	if not alive(helper) then return "Bad" end
	if (rootOf(helper.Character).Position - d.Pos).Magnitude > num(R.Range, 6) + num(R.RangeSlack, 2) then return "Far" end
	local now = os.clock()
	local left = num(R.Cooldown, 10) - (now - (ST.LastAt[helper] or -math.huge))
	if left > 0 then
		Net.Notify(helper, string.format(R.Text.Cooldown, math.ceil(left)), "bad")
		return "Cooldown"
	end
	local key = Config.PotionStockKey(R.Potion or "HP")
	local data = S.PlayerService.GetData(helper)
	local have = type(data) == "table" and math.floor(num(data[key])) or 0
	if not key or have < 1 then
		Net.Notify(helper, R.Text.NoPotion, "bad")
		return "NoPotion"
	end
	S.PlayerService.SetStat(helper, key, have - 1)
	ST.LastAt[helper] = now
	d.Revived = true
	if d.Prompt then pcall(d.Prompt.Destroy, d.Prompt) end
	d.Prompt = nil
	target:SetAttribute("ReviveUntil", 0)
	S.PlayerService.Respawn(target)
	local stat = STAT[d.Side]
	local fame = math.max(0, math.floor(num(R.Fame, 1)))
	if stat and fame > 0 then
		S.PlayerService.GrantFame(helper, stat, fame, { Revive = true })
		Net.Notify(helper, string.format(R.Text["Helped" .. stat], target.DisplayName, fame), "reward")
	else
		Net.Notify(helper, string.format(R.Text.Helped, target.DisplayName), "reward")
	end
	Net.Notify(target, string.format(R.Text.HelpedBy, helper.DisplayName), "reward")
	Net.Fx(target, "Revived", { By = helper.UserId })
	-- feedback_audit #8 (최종 검수 10/15): the helper's side of the same moment
	pcall(Net.Fx, helper, "ReviveDone", { Target = target.UserId })
	ReviveService.Revived:Fire(helper, target)
	return true
end

local function onHoldBegan(prompt, helper)
	if typeof(prompt) ~= "Instance" or prompt.Name ~= R.PromptName or not isPlayer(helper) then return end
	ST.Hold[helper] = { Prompt = prompt, At = os.clock() }
end

local function onTriggered(prompt, helper)
	if typeof(prompt) ~= "Instance" or prompt.Name ~= R.PromptName or not isPlayer(helper) then return end
	local h = ST.Hold[helper]
	ST.Hold[helper] = nil
	-- the hold must really have lasted (a Triggered fired without holding is refused)
	if not h or h.Prompt ~= prompt or os.clock() - h.At < num(R.Hold, 3) - num(R.HoldSlack, 0.25) then return end
	local target = targetOf(prompt)
	if target then ReviveService.Try(helper, target) end
end

-- the next real spawn: helped = HPPct of MaxHealth and the spawn shield cut to Shield s; else nothing (a normal one)
local function onSpawned(player, character, humanoid, cosmetic)
	if cosmetic then return end
	local d = ST.Down[player]
	if not d then return end
	clear(player)
	if not d.Revived or not humanoid then return end
	humanoid.Health = math.max(1, math.floor(humanoid.MaxHealth * math.clamp(num(R.HPPct, 0.3), 0.05, 1) + 0.5))
	local pvp = S.PvPService
	if type(pvp) == "table" and type(pvp.BreakProtection) == "function" then
		task.delay(num(R.Shield, 3), function()
			if player.Character == character then pcall(pvp.BreakProtection, player) end
		end)
	end
end

local function onSkip(player, ...)
	if select("#", ...) ~= 0 or not isPlayer(player) then return end
	if not Util.RateLimit(player, "ReviveSkip", num(R.Rate, 0.5)) then return end
	local d = ST.Down[player]
	if not d or d.Revived then return end
	clear(player)
	S.PlayerService.Respawn(player)
end

local function guard(name, fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok then Util.Warn(TAG, name .. ": " .. tostring(err)) end
	end
end

function ReviveService.Init(registry)
	S = registry
end

function ReviveService.Start()
	local ps = S.PlayerService
	ps.CharacterDied:Connect(guard("died", onDied))
	ps.CharacterSpawned:Connect(guard("spawned", onSpawned))
	ps.PlayerLeaving:Connect(guard("leaving", function(player)
		clear(player)
		ST.Hold[player], ST.LastAt[player] = nil, nil
	end))
	ProximityPromptService.PromptButtonHoldBegan:Connect(guard("hold", onHoldBegan))
	ProximityPromptService.PromptTriggered:Connect(guard("triggered", onTriggered))
	Net.Get("ReviveSkip").OnServerEvent:Connect(guard("ReviveSkip", onSkip))
end

return ReviveService
