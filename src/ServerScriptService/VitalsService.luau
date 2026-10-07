-- Server-owned mana and purchased HP/MP potion stock. Appearance changes preserve session cooldowns and saved stock.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Util = require(ReplicatedStorage.Shared.Util)

local VitalsService = {}
local S = nil
local states = {}
local TUNE = Config.Vitals

local function publish(player, st)
	player:SetAttribute("MaxMana", TUNE.MaxMana)
	player:SetAttribute("Mana", math.floor(st.Mana * 10 + 0.5) / 10)
	player:SetAttribute("HPPotionReadyAt", st.HPReadyAt)
	player:SetAttribute("MPPotionReadyAt", st.MPReadyAt)
end

local function ready(player)
	return player.Parent == Players and S.PlayerService.IsReady(player)
		and player:GetAttribute("ClassChosen") == true and Util.IsAlive(player)
end

function VitalsService.TrySpendMana(player, amount, silent)
	if type(amount) ~= "number" or amount ~= amount or amount < 0 or amount > TUNE.MaxMana then return false end
	if not ready(player) then return false end
	local st = states[player]
	if not st then return false end
	if st.Mana + 0.0001 < amount then
		local now = workspace:GetServerTimeNow()
		if not silent and now - st.NoticeAt >= 2 then
			st.NoticeAt = now
			Net.Notify(player, (TUNE.MerchantEnabled == true and "Not enough MP. Drink an MP potion!") or "Not enough MP. Wait a moment and it refills.", "bad")
		end
		return false
	end
	st.Mana = math.max(0, st.Mana - amount)
	publish(player, st)
	return true
end

-- SKL-3 MP steal (SkillService): adds up to `amount` MP (never past MaxMana); returns the MP really added
function VitalsService.AddMana(player, amount)
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount == math.huge then return 0 end
	if not ready(player) then return 0 end
	local st = states[player]
	if not st then return 0 end
	local before = st.Mana
	st.Mana = math.min(TUNE.MaxMana, before + amount)
	if st.Mana <= before then return 0 end
	publish(player, st)
	return st.Mana - before
end

local function usePotion(player, kind)
	if kind ~= "HP" and kind ~= "MP" then return end
	if not ready(player) or not Util.RateLimit(player, "UsePotion" .. kind, Config.RateLimits.UsePotion) then return end
	local st = states[player]
	if not st then return end
	if player:GetAttribute("KaijuState") == "Active" or player:GetAttribute("KaijuState") == "Siren" then
		Net.Notify(player, "You can't use potions as a Kaiju.", "bad")
		return
	end
	local now = workspace:GetServerTimeNow()
	local key = kind .. "ReadyAt"
	if now < st[key] then return end
	local stockKey = Config.PotionStockKey(kind)
	local data = S.PlayerService.GetData(player)
	local count = type(data) == "table" and data[stockKey]
	if type(count) ~= "number" or count ~= count or count < 1 or count > TUNE.PotionInventoryCap
		or count ~= math.floor(count) then
		Net.Notify(player, (TUNE.MerchantEnabled == true and "No potions left. Buy some from the Potion Seller.") or "No potions left. The potion shop isn't open yet.", "bad")
		return
	end
	local humanoid = Util.GetHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then return end
	if kind == "HP" then
		if humanoid.Health >= humanoid.MaxHealth then
			Net.Notify(player, "HP is full.", "info")
			return
		end
		local before = humanoid.Health
		humanoid.Health = math.min(humanoid.MaxHealth, before + humanoid.MaxHealth * TUNE.HPRecovery)
		if humanoid.Health <= before then return end -- a failed/no-op heal consumes neither stock nor the deadline
	else
		if st.Mana >= TUNE.MaxMana then
			Net.Notify(player, "MP is full.", "info")
			return
		end
		local before = st.Mana
		st.Mana = math.min(TUNE.MaxMana, before + TUNE.MaxMana * TUNE.MPRecovery)
		if st.Mana <= before then return end
	end
	-- No yields between actual restoration, saved stock decrement and the independent session deadline.
	S.PlayerService.SetStat(player, stockKey, count - 1)
	st[key] = now + TUNE.PotionCooldown
	publish(player, st)
	S.PlayerService.MarkActive(player)
	Net.Notify(player, "Used a " .. kind .. " potion!", "good")
end

-- Studio-only resource setup, invoked through Main's existing DebugCommand BindableFunction.
function VitalsService.DebugSetMana(player, value)
	if not game:GetService("RunService"):IsStudio() or type(value) ~= "number" or value ~= value then return false end
	local st = states[player]
	if not st then return false end
	st.Mana = math.clamp(value, 0, TUNE.MaxMana)
	publish(player, st)
	return true
end

function VitalsService.Init(registry)
	S = registry
	S.PlayerService.PlayerReady:Connect(function(player)
		local st = { Mana = TUNE.MaxMana, HPReadyAt = 0, MPReadyAt = 0, NoticeAt = -math.huge }
		states[player] = st
		publish(player, st)
	end)
	S.PlayerService.CharacterSpawned:Connect(function(player, _, _, cosmetic)
		local st = states[player]
		if st and not cosmetic then
			st.Mana = TUNE.MaxMana
			publish(player, st)
		end
	end)
	S.PlayerService.PlayerLeaving:Connect(function(player) states[player] = nil end)
end

function VitalsService.Start()
	Net.Get("UsePotion").OnServerEvent:Connect(function(player, kind)
		local ok, err = pcall(usePotion, player, kind)
		if not ok then Util.Warn("VitalsService", tostring(err)) end
	end)
	task.spawn(function()
		local last = workspace:GetServerTimeNow()
		while true do
			task.wait(0.5)
			local now = workspace:GetServerTimeNow()
			local dt = math.clamp(now - last, 0, 1)
			last = now
			for player, st in states do
				if ready(player) and st.Mana < TUNE.MaxMana then
					st.Mana = math.min(TUNE.MaxMana, st.Mana + TUNE.ManaRegen * dt)
					publish(player, st)
				end
			end
		end
	end)
	print("[VitalsService] started")
end

return VitalsService
