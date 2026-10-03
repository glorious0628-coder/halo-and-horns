-- Globally unique, broadcast-filtered game nicknames. Roblox account names are never modified.
-- A user directory + durable operation token recover uncertain writes without blind retries.
-- Old claims remain owned by that user: no delayed rollback can free somebody else's name.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local NicknameService = {}
local S = nil
local store = nil
local states = {}
local MESSAGES = {
	Active = "닉네임을 저장했어요.", Available = "닉네임을 정할 수 있어요.",
	Invalid = "닉네임은 2~20글자로 입력해 주세요. 숨은 문자·줄바꿈·#·<·>·&는 사용할 수 없어요.",
	Filtered = "이 닉네임은 사용할 수 없어요. 다른 이름을 입력해 주세요.",
	Taken = "이미 사용 중인 닉네임이에요.", Busy = "닉네임을 확인하고 있어요.",
	Unknown = "저장 결과를 확인하지 못했어요. 기존 닉네임을 유지했어요. 다시 누르면 먼저 확인해요.",
	Unavailable = "닉네임 저장소에 연결할 수 없어요. 기존 닉네임을 유지했어요.",
	FilterUnavailable = "닉네임 필터에 연결할 수 없어요. 잠시 뒤 다시 시도해 주세요.",
	Recovered = "이전 저장 결과를 확인했어요. 변경하려면 다시 눌러 주세요.",
	Cooldown = "잠시 뒤 닉네임을 다시 변경해 주세요.", Loading = "닉네임을 불러오고 있어요.",
}

local function live(player, st)
	return states[player] == st and player.Parent == Players and S.PlayerService.IsReady(player)
end

local function status(player, code)
	if player.Parent == Players then player:SetAttribute("NicknameStatus", code) end
end

local function reply(player, code)
	if player.Parent ~= Players then return end
	status(player, code)
	Net.Get("NicknameResult"):FireClient(player, {
		Status = code, Message = MESSAGES[code] or MESSAGES.Unavailable,
		Nickname = player:GetAttribute("NicknameVerified") == true and player:GetAttribute("Nickname") or "",
	})
end

local function tokenValid(token)
	return type(token) == "string" and #token >= 16 and #token <= 80 and not string.find(token, "[^%w%-]")
end

local function identityValid(identity, active)
	if type(identity) ~= "table" or not Util.ValidateNickname(identity.Text)
		or identity.Canonical ~= Util.NicknameCanonical(identity.Text) or not tokenValid(identity.Token) then return false end
	return not active or tokenValid(identity.ClaimToken)
end

local function directoryValid(directory, userId)
	return type(directory) == "table" and directory.Version == 1 and directory.UserId == userId
		and type(directory.Revision) == "number" and directory.Revision >= 0
		and directory.Revision == math.floor(directory.Revision) and directory.Revision < 1e12
		and (directory.Active == nil or identityValid(directory.Active, true))
		and (directory.Pending == nil or identityValid(directory.Pending, false))
end

local function newDirectory(userId)
	return { Version = 1, UserId = userId, Revision = 0 }
end

local function userKey(userId)
	return "U_" .. tostring(userId)
end

local function claimKey(canonical)
	-- Bounded ASCII key (<50 bytes). Hash collisions fail closed via the full canonical value below.
	-- Both products stay below 2^53, preserving exact integer arithmetic in Luau numbers.
	local a, b = 5381, 0
	for i = 1, #canonical do
		local byte = string.byte(canonical, i)
		a = (a * 33 + byte) % 4294967296
		b = (b * 131 + byte) % 4294967296
	end
	return string.format("N_%08x%08x_%d", a, b, #canonical)
end

local function readFresh(key)
	-- No cached read may decide whether an uncertain write happened.
	return pcall(function()
		local options = Instance.new("DataStoreGetOptions")
		options.UseCache = false
		return store:GetAsync(key, options)
	end)
end

local function update(key, transform)
	-- Exactly one call. An exception is Unknown, never proof that the write failed.
	return pcall(store.UpdateAsync, store, key, transform)
end

local function filtered(player, raw)
	if not Util.ValidateNickname(raw) then return nil, "Invalid" end
	local ok, text = pcall(function()
		local result = TextService:FilterStringAsync(raw, player.UserId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then return nil, "FilterUnavailable" end
	-- Use the broadcast result for both the visible text and the global canonical claim.
	if not Util.ValidateNickname(text) then return nil, "Filtered" end
	return text
end

local function claimMatches(claim, userId, canonical, token)
	return type(claim) == "table" and claim.Version == 1 and claim.UserId == userId
		and claim.Canonical == canonical and tokenValid(claim.Token) and (token == nil or claim.Token == token)
end

local function applyName(player, st, text)
	if not live(player, st) then return end
	S.PlayerService.SetStat(player, "Nickname", text or "") -- filtered cache only, not the uniqueness authority
	player:SetAttribute("Nickname", text or "")
	player:SetAttribute("NicknameVerified", text ~= nil)
	local humanoid = Util.GetHumanoid(player)
	if humanoid then pcall(function() humanoid.DisplayName = Util.PlayerDisplayName(player) end) end
end

local function showActive(player, st, active)
	if not active then applyName(player, st, nil); return "Available" end
	local ok, claim = readFresh(claimKey(active.Canonical))
	if not ok then return "Unavailable" end
	if not claimMatches(claim, player.UserId, active.Canonical, active.ClaimToken) then return "Unavailable" end
	local text, why = filtered(player, active.Text)
	if not text then return why end
	-- If today's filter transforms an old name, do not display it under somebody else's canonical claim.
	if text ~= active.Text then return "Filtered" end
	applyName(player, st, text)
	return "Active"
end

local function clearPending(player, pending)
	local ok, directory = update(userKey(player.UserId), function(old)
		if not directoryValid(old, player.UserId) then return nil end
		if not old.Pending or old.Pending.Token ~= pending.Token then return old end
		local nextDirectory = Util.DeepCopy(old)
		nextDirectory.Pending = nil
		nextDirectory.Revision += 1
		return nextDirectory
	end)
	return ok and directoryValid(directory, player.UserId) and directory.Pending == nil
end

local function finishPending(player, st, pending)
	-- Recovery re-filters persisted text. Only a still-identical broadcast result may complete this intent.
	local text, why = filtered(player, pending.Text)
	if not text then
		if why == "Filtered" or why == "Invalid" then
			return clearPending(player, pending) and "Filtered" or "Unknown"
		end
		return why
	end
	if text ~= pending.Text then
		return clearPending(player, pending) and "Filtered" or "Unknown"
	end
	local key = claimKey(pending.Canonical)
	local okRead, claim = readFresh(key)
	if not okRead then return "Unknown" end
	if claim == nil then
		local okClaim
		okClaim, claim = update(key, function(old)
			if old ~= nil then return old end
			return { Version = 1, UserId = player.UserId, Canonical = pending.Canonical, Token = pending.Token }
		end)
		if not okClaim then return "Unknown" end
	end
	if not claimMatches(claim, player.UserId, pending.Canonical) then
		-- Cancel only this user's exact intent. Claims themselves are never removed or overwritten.
		return clearPending(player, pending) and "Taken" or "Unknown"
	end
	local okCommit, directory = update(userKey(player.UserId), function(old)
		if not directoryValid(old, player.UserId) then return nil end
		if not old.Pending or old.Pending.Token ~= pending.Token then return old end
		if old.Pending.Canonical ~= pending.Canonical or old.Pending.Text ~= pending.Text then return nil end
		local nextDirectory = Util.DeepCopy(old)
		nextDirectory.Active = {
			Text = text, Canonical = pending.Canonical, Token = pending.Token, ClaimToken = claim.Token,
		}
		nextDirectory.Pending = nil
		nextDirectory.Revision += 1
		return nextDirectory
	end)
	if not okCommit or not directoryValid(directory, player.UserId) or directory.Pending ~= nil
		or not directory.Active or directory.Active.Token ~= pending.Token
		or directory.Active.ClaimToken ~= claim.Token or directory.Active.Canonical ~= pending.Canonical then
		return "Unknown"
	end
	applyName(player, st, text)
	return "Active"
end

local function resolve(player, st)
	local ok, directory = readFresh(userKey(player.UserId))
	if not ok then return "Unknown" end
	if directory == nil then directory = newDirectory(player.UserId) end
	if not directoryValid(directory, player.UserId) then return "Unknown" end
	local activeStatus = showActive(player, st, directory.Active)
	if directory.Pending then return finishPending(player, st, directory.Pending) end
	return activeStatus
end

local function available()
	return store ~= nil and S.DataService.IsPersistentReady()
end

function NicknameService.SetNickname(player, raw)
	if not S.PlayerService.IsReady(player) or player.Parent ~= Players then return end
	local st = states[player]
	if not st or not st.Loaded then reply(player, "Loading"); return end
	if not Util.ValidateNickname(raw) then reply(player, "Invalid"); return end
	if st.Busy then reply(player, "Busy"); return end
	if not Util.RateLimit(player, "SetNickname", Config.Nickname.ChangeInterval) then reply(player, "Cooldown"); return end
	if not available() then reply(player, "Unavailable"); return end
	st.Busy = true
	status(player, "Busy")
	local ok, code = pcall(function()
		if st.Unknown then
			-- Resolve the previous token first. This call never starts the newly supplied request.
			local result = resolve(player, st)
			st.Unknown = result == "Unknown" or result == "FilterUnavailable"
			return (result == "Active" or result == "Available") and "Recovered" or result
		end
		local text, why = filtered(player, raw)
		if not text then return why end
		local okRead, directory = readFresh(userKey(player.UserId))
		if not okRead then return "Unavailable" end
		if directory == nil then directory = newDirectory(player.UserId) end
		if not directoryValid(directory, player.UserId) then st.Unknown = true; return "Unknown" end
		if directory.Pending then
			st.Unknown = true
			return "Unknown" -- an existing intent is resolved on the next explicit request
		end
		local pending = { Text = text, Canonical = Util.NicknameCanonical(text), Token = HttpService:GenerateGUID(false) }
		local revision = directory.Revision
		local okBegin, result = update(userKey(player.UserId), function(old)
			if old == nil then old = newDirectory(player.UserId) end
			if not directoryValid(old, player.UserId) then return nil end
			if old.Pending or old.Revision ~= revision then return old end
			local nextDirectory = Util.DeepCopy(old)
			nextDirectory.Pending = pending -- contains only the filtered broadcast text
			nextDirectory.Revision += 1
			return nextDirectory
		end)
		if not okBegin or not directoryValid(result, player.UserId) or not result.Pending
			or result.Pending.Token ~= pending.Token then st.Unknown = true; return "Unknown" end
		local final = finishPending(player, st, result.Pending)
		st.Unknown = final == "Unknown" or final == "FilterUnavailable"
		return final
	end)
	if not ok then st.Unknown = true; code = "Unknown" end
	st.Busy = false
	if live(player, st) then reply(player, code) end
end

local function load(player)
	local st = { Busy = true, Loaded = false, Unknown = false }
	states[player] = st
	local code = "Unavailable"
	if available() then
		local ok, result = pcall(resolve, player, st)
		code = ok and result or "Unknown"
		st.Unknown = code == "Unknown" or code == "FilterUnavailable"
	end
	st.Busy = false
	st.Loaded = true
	if live(player, st) then status(player, code) end
end

function NicknameService.Init(registry)
	S = registry
	S.PlayerService.PlayerReady:Connect(function(player) task.spawn(load, player) end)
	S.PlayerService.PlayerLeaving:Connect(function(player) states[player] = nil end)
	S.PlayerService.CharacterSpawned:Connect(function(player, _, humanoid)
		pcall(function() humanoid.DisplayName = Util.PlayerDisplayName(player) end)
	end)
end

function NicknameService.Start()
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, Config.Nickname.StoreName)
	if ok then store = result end
	Net.Get("SetNickname").OnServerEvent:Connect(NicknameService.SetNickname)
	print("[NicknameService] started")
end

return NicknameService
