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
	Active = "Nickname saved.", Available = "You can set a nickname.",
	Invalid = "Nicknames need 2-20 characters. Hidden characters, line breaks, #, <, > and & are not allowed.",
	Filtered = "This nickname can't be used. Please try another one.",
	Taken = "That nickname is already taken.", Busy = "Checking the nickname...",
	Unknown = "We couldn't confirm the save, so your old nickname stays. Tap again to check first.",
	Unavailable = "Can't reach the nickname storage, so your old nickname stays.",
	FilterUnavailable = "Can't reach the nickname filter. Please try again soon.",
	Recovered = "We found your last save result. Tap again to change it.",
	Cooldown = "Please wait a bit before changing your nickname again.", Loading = "Loading your nickname...",
}

-- A bounded supplemental policy, not a language model or a replacement for Roblox filtering.
-- Match complete risky phrases or an explicit target + abusive action. Never ban syllables such
-- as 성/신/교, ordinary affection, fantasy class names, or a religion's name alone.
-- Sources: https://create.roblox.com/docs/ui/text-filtering
--          https://about.roblox.com/community-standards
local POLICY = {
	Korean = {
		"성관계", "성행위", "성매매", "음란물", "야동", "포르노", "섹스", "강간",
		"알몸사진", "벗은사진", "누드사진", "나체사진", "야한사진보내", "미성년자성착취",
		"예수믿어", "예수를믿", "예수믿으", "예수믿자", "예수천국", "불신지옥",
		"하나님믿", "하느님믿", "알라믿", "부처믿", "교회오세요", "교회나와",
		"종교가입해", "종교가입하", "개종해라", "개종하세요", "개종하라",
		"무료로벅스", "공짜로벅스", "로벅스무료", "로벅스공짜", "로벅스복사",
		"비밀번호입력", "비번입력", "비밀번호알려", "비번알려", "인증번호줘", "토큰보내",
		"전화번호줘", "폰번호줘", "카톡아이디", "디코아이디", "인스타아이디",
		"디스코드와", "디코로와", "카톡으로와", "우리집주소", "집주소는", "계좌번호",
		"공식운영자", "진짜운영자", "공식관리자", "공식개발자", "공식GM",
		"로블록스운영", "로블록스관리", "로블록스직원", "로블록스본사",
		"깜둥이", "짱깨", "씨발", "자살해라", "자살하세요", "자해해라",
	},
	KoreanTargets = {
		"기독교", "불교", "천주교", "이슬람", "힌두교", "유대인", "무슬림",
		"흑인", "백인", "아시아인", "여자", "남자", "장애인", "동성애자",
	},
	KoreanAbuse = { "죽어", "죽여", "죽이자", "박멸", "추방", "꺼져", "쓰레기", "열등", "멸종" },
	EnglishWords = { "sex", "porn", "porno", "nudes", "rape", "rapist", "nigger", "faggot" },
	EnglishPhrases = {
		"sex master", "sex slave", "sex king", "sex queen", "porn star", "porn hub", "child porn",
		"send nudes", "nudes please", "want nudes", "nude photos", "naked photos", "jesus saves", "believe in jesus", "accept jesus",
		"convert to islam", "convert to christ", "join my church", "join our church", "join my religion",
		"free robux", "robux generator", "send password", "give password", "password please",
		"send otp", "send token", "add me discord", "discord me", "kill yourself", "hurt yourself",
		"official admin", "official developer", "official moderator", "real admin", "roblox staff",
		"roblox admin", "roblox moderator", "roblox employee", "game admin", "game moderator",
	},
	EnglishTargets = { "christians", "muslims", "jews", "hindus", "buddhists", "black people", "white people", "asians", "women", "men", "gay people", "disabled people" },
	EnglishAbuse = { "kill", "exterminate", "death to" },
	EnglishDegrade = { "die", "are trash", "are inferior" },
	Reserved = { "운영자", "관리자", "개발자", "게임운영자", "공식운영자", "gm", "admin", "moderator", "developer", "gamemaster" },
	Domains = { "com", "net", "org", "gg", "io", "kr", "me" },
}

local function policyForms(text)
	-- Only the comparison copy folds full-width ASCII/camel case/separators. Display and the
	-- global canonical stay unchanged; no Unicode normalization changes ownership semantics.
	local chars = {}
	for _, cp in utf8.codes(text) do
		if cp >= 0xFF01 and cp <= 0xFF5E then cp -= 0xFEE0 end
		chars[#chars + 1] = utf8.char(cp)
	end
	local folded = table.concat(chars)
	local words = string.gsub(folded, "(%l)(%u)", "%1 %2")
	words = string.lower(words)
	words = string.gsub(words, "[ _%.%-]+", " ")
	local compact = string.lower(string.gsub(folded, "[ _%.%-]+", ""))
	return string.lower(folded), words, compact
end

local function englishPhrase(text, phrase)
	-- ASCII letter boundaries avoid the classic substring false positives (Essex/Scunthorpe).
	-- Numeric decorations do not make an explicit phrase safe.
	local from = 1
	while true do
		local first, last = string.find(text, phrase, from, true)
		if not first then return false end
		local before, after = string.sub(text, first - 1, first - 1), string.sub(text, last + 1, last + 1)
		if not string.find(before, "[a-z]") and not string.find(after, "[a-z]") then return true end
		from = last + 1
	end
end

local function englishRisk(words, compact, phrase)
	return englishPhrase(words, phrase) or englishPhrase(compact, string.gsub(phrase, " ", ""))
end

local function policyAllowed(text)
	local folded, words, compact = policyForms(text)
	if not Util.ValidateNickname(folded) then return false end
	for _, phrase in POLICY.Korean do
		if string.find(compact, string.lower(phrase), 1, true) then return false end
	end
	for _, target in POLICY.KoreanTargets do
		for _, abuse in POLICY.KoreanAbuse do
			if string.find(compact, target .. abuse, 1, true)
				or string.find(compact, target .. "는" .. abuse, 1, true)
				or string.find(compact, target .. "은" .. abuse, 1, true)
				or string.find(compact, target .. "을" .. abuse, 1, true)
				or string.find(compact, target .. "를" .. abuse, 1, true) then return false end
		end
	end
	for _, phrase in POLICY.EnglishWords do if englishRisk(words, compact, phrase) then return false end end
	for _, phrase in POLICY.EnglishPhrases do if englishRisk(words, compact, phrase) then return false end end
	for _, target in POLICY.EnglishTargets do
		for _, abuse in POLICY.EnglishAbuse do
			if englishRisk(words, compact, abuse .. " " .. target) then return false end
		end
		for _, abuse in POLICY.EnglishDegrade do
			if englishRisk(words, compact, target .. " " .. abuse) then return false end
		end
	end
	for _, role in POLICY.Reserved do
		if compact == role or string.match(compact, "^" .. role .. "%d+$") then return false end
	end
	-- Match contact/credential shapes, not all long numeric nicknames or all mentions of a phone.
	if string.find(folded, "%S+@%S+%.%w+") or string.find(folded, "https?://")
		or string.find(folded, "www%.") then return false end
	for phone in string.gmatch(folded, "%+%d[%d %.%-]+%d") do
		local digits = string.gsub(phone, "%D", "")
		if #digits >= 8 and #digits <= 15 then return false end
	end
	for _, domain in POLICY.Domains do
		if string.find(folded, "[%w%-]+%." .. domain .. "%f[^a-z]") then return false end
	end
	for number in string.gmatch(compact, "%d+") do
		if #number == 11 and string.match(number, "^01[016789]") then return false end
	end
	if string.find(folded, "%d%d%d[%s%.%-]%d%d%d%d?[%s%.%-]%d%d%d%d")
		or string.find(folded, "%d%d%d%d%d%d%-[1-4]%d%d%d%d%d%d")
		or string.find(folded, "%d%d%d%d[%s%-]%d%d%d%d[%s%-]%d%d%d%d[%s%-]%d%d%d%d") then return false end
	return true
end

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
	if not policyAllowed(raw) then return nil, "Filtered" end
	local ok, text = pcall(function()
		local result = TextService:FilterStringAsync(raw, player.UserId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then return nil, "FilterUnavailable" end
	-- Use the broadcast result for both the visible text and the global canonical claim.
	if not Util.ValidateNickname(text) or not policyAllowed(text) then return nil, "Filtered" end
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
