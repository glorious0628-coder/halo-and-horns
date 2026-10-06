-- DataService.luau : DataStore load/save with a session lock, retries, autosave, v1 -> v2 -> v3 migration and an
-- in-memory fallback for Studio sessions without API access. BindToClose is owned by PlayerService.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local TAG = "DataService"

local DataService = {}

local S = nil -- registry (unused at runtime; kept for the service pattern)

local store = nil -- GlobalDataStore, set by the probe in Start
local memoryMode = false
local probeDone = false

local cache = {} -- [Player] = live session table
local releasing = {} -- [Player] = true while Release() runs
local foreignLock = {} -- [Player] = true once another server owns the record (further saves are refused)
-- CR-M1: [userId] = { token, ... } FIFO of DataStore operations for that user; q[1] holds the slot (serializes
-- writes in request order, so a fast rejoin's Load can never jump ahead of the previous session's Release)
local slotQueue = {}
-- [Player] = GUID this session wrote into the stored record at Load (field SessionToken). A save only lands while the
-- stored token is still ours, so a delayed write of an old session can never overwrite a newer session's record.
local sessionTokens = {}

local PROBE_TIMEOUT = 30 -- seconds Load waits for the Start probe before giving up
local SLOT_TIMEOUT = 90 -- seconds a writer waits for the previous writer of the same user
local RELEASE_WAIT = 60 -- seconds a second Release() call waits for the first one

local TUTORIAL_NEW = (Config.Tutorial and Config.Tutorial.Steps and Config.Tutorial.Steps.Kill) or 0
local TUTORIAL_DONE = (Config.Tutorial and Config.Tutorial.Steps and Config.Tutorial.Steps.Done) or 99

------------------------------------------------------------------ helpers
local function keyFor(userId)
	return Config.Data.KeyPrefix .. tostring(userId)
end

-- per-user write slot: an older copy must never land after a newer one (autosave vs forced save vs release).
-- CR-M1: first come, first served. nil = the slot was not reached within SLOT_TIMEOUT (the caller fails; it never
-- writes without the slot)
local function acquireSlot(userId)
	local q = slotQueue[userId]
	if not q then
		q = {}
		slotQueue[userId] = q
	end
	local token = {}
	table.insert(q, token)
	local t0 = os.clock()
	while q[1] ~= token do
		if os.clock() - t0 >= SLOT_TIMEOUT then
			local i = table.find(q, token)
			if i then table.remove(q, i) end
			if #q == 0 and slotQueue[userId] == q then slotQueue[userId] = nil end
			return nil
		end
		task.wait(0.1)
	end
	return token
end

local function releaseSlot(userId, token)
	local q = slotQueue[userId]
	if not q then return end
	local i = table.find(q, token)
	if i then table.remove(q, i) end
	if #q == 0 and slotQueue[userId] == q then slotQueue[userId] = nil end
end

-- CR-M1: true while another Player object of this user (a fast rejoin to this server) still has a cached session
local function hasOtherSession(player)
	local userId = player.UserId
	for p in cache do
		if p ~= player and p.UserId == userId then return true end
	end
	return false
end

local function isLock(lock)
	return type(lock) == "table" and type(lock.JobId) == "string"
end

-- a lock held by ANOTHER server that is still considered alive
local function isLiveForeignLock(lock)
	if not isLock(lock) or lock.JobId == game.JobId then return false end
	local t = tonumber(lock.Time)
	if not t then return false end
	return os.time() - t < Config.Data.LockTimeout
end

-- true if the stored value holds real player data (not just nothing / a bare session lock + token)
local function hasStoredData(old)
	if type(old) ~= "table" then return false end
	for k in old do
		if k ~= "SessionLock" and k ~= "SessionToken" then return true end
	end
	return false
end

-- stepwise v1 -> v2 -> v3 (each step idempotent; a record runs every step it has not reached yet)
local function migrate(d, player)
	if (tonumber(d.Version) or 1) < 2 then
		d.WeaponTier = d.WeaponTier or d.SwordTier or 1 -- v1 field SwordTier is renamed
		d.SwordTier = nil
		d.RebirthBonus = (tonumber(d.Rebirths) or 0) * Config.Rebirth.BonusNormal
		d.Class = "Warrior"
		d.ClassChosen = false -- migrated players get one free class pick (keeps their level)
		d.Quests = {} -- QuestService regenerates (DailyDay = 0 -> fresh dailies, no vacation)
		d.Version = 2
		print("[DataService] migrated v1 -> v2 for " .. player.Name)
	end
	-- B4 (A23-12): v3 adds weapon tier 8 (slime legendary, mask bit 7) and the Items / WeaponEnhance / LootFlags
	-- tables. No field changes: the new tables come from the defaults and fillDefaults normalizes the weapon fields.
	-- The bump exists so an older v2 server refuses these records (CR-L3 guard in loadLocked) instead of clamping an
	-- equipped tier 8 down to tier 7 and saving it (a free 90,000-gold weapon once the record is back on new code).
	if (tonumber(d.Version) or 1) < 3 then
		-- A23-34: every v1 / v2 record is from before the bare-handed start, when tier 1 was always owned (A23-4). Keep
		-- that here, because fillDefaults no longer forces bit 1: a missing / broken tier is tier 1 and bit 1 stays owned.
		-- v3 records written by older servers already carry bit 1 (their fillDefaults wrote it on every load).
		local tier = d.WeaponTier
		if type(tier) ~= "number" or tier ~= math.floor(tier) or tier < 1 or tier > Config.MaxWeaponTier then
			d.WeaponTier = 1
		end
		local mask = d.WeaponOwnedMask
		if type(mask) ~= "number" or mask ~= mask or mask < 0 or mask ~= math.floor(mask)
			or mask >= bit32.lshift(1, Config.MaxWeaponTier) then mask = 0 end
		d.WeaponOwnedMask = bit32.bor(mask, 1)
		d.Version = 3
	end
end

-- add missing keys from the defaults and repair obviously corrupted values
local function fillDefaults(d, playerName)
	for k, v in Config.Data.Defaults do
		local cur = d[k]
		if cur == nil then
			d[k] = Util.DeepCopy(v)
		elseif type(cur) ~= type(v) then
			Util.Warn(TAG, ("%s: field %s had type %s, reset to default"):format(playerName, k, type(cur)))
			d[k] = Util.DeepCopy(v)
		end
	end

	-- table default Tickets: also fill missing sub-keys
	if type(d.Tickets) ~= "table" then d.Tickets = {} end
	for _, kind in { "Class", "Faction" } do
		local n = tonumber(d.Tickets[kind])
		d.Tickets[kind] = (n and n == n and n > 0) and math.floor(n) or 0
	end

	-- receipts: array of strings, at most MaxReceiptsKept (oldest dropped)
	local receipts = {}
	if type(d.ProcessedReceipts) == "table" then
		for _, id in d.ProcessedReceipts do
			if type(id) == "string" or type(id) == "number" then table.insert(receipts, tostring(id)) end
		end
	end
	while #receipts > Config.Tickets.MaxReceiptsKept do
		table.remove(receipts, 1)
	end
	d.ProcessedReceipts = receipts

	-- ids that other services branch on
	if not Config.Factions[d.Faction] then d.Faction = "None" end
	if not Config.Classes[d.Class] then d.Class = "Warrior" end
	-- Appearance preferences are additive save fields; older records do not need a version reset.
	if d.CharacterGender ~= "M" and d.CharacterGender ~= "F" then d.CharacterGender = "M" end
	-- Never re-save a cached name before today's filter and global claim check. The separate directory is authoritative.
	d.Nickname = ""
	for _, key in { "HPPotionCount", "MPPotionCount" } do
		d[key] = Config.NormalizePotionCount(d[key])
	end
	d.Level = math.clamp(math.floor(tonumber(d.Level) or 1), 1, Config.Levels.MaxLevel)
	-- A23-34: 0 is valid for both weapon fields (bare hands, nothing owned) and no bit is forced any more; records from
	-- before the bare-handed start got their tier-1 bit in migrate (v1 / v2) or already saved it (v3).
	-- B4 + review: a mask that is not an integer mask of the weapon tiers (non-number, NaN, +-inf, < 0, fraction, or
	-- above validMask = any bit beyond MaxWeaponTier) is corrupted -> nothing owned (plus the equipped tier below).
	-- v3 records never carry higher bits (an older server refuses v3, a v2 server reset them), so keeping the low bits
	-- of e.g. 0xFFFFFFFF would hand out every weapon incl. T7 and the never-sold legendary.
	local owned = d.WeaponOwnedMask
	local validMask = bit32.lshift(1, Config.MaxWeaponTier) - 1
	if type(owned) ~= "number" or owned ~= owned or owned < 0 or owned > validMask
		or owned ~= math.floor(owned) then
		owned = 0
	end
	-- B4: a stored tier that is not an integer in 0..MaxWeaponTier is corrupted -> the best owned weapon usable at this
	-- level (0 = bare hands). Never clamp: clamping turned e.g. tier 9 into the last tier (8 = the never-sold legendary).
	local weaponTier = d.WeaponTier
	if type(weaponTier) ~= "number" or weaponTier ~= math.floor(weaponTier) or weaponTier < 0
		or weaponTier > Config.MaxWeaponTier then -- NaN fails the floor test, +-inf the range test
		weaponTier = Config.BestUsableWeapon(owned, d.Level)
	end
	d.WeaponTier = weaponTier
	-- Older saves only prove ownership of the equipped weapon. Preserve it, including rare tiers, without granting
	-- speculative earlier purchases.
	d.WeaponOwnedMask = weaponTier >= 1 and bit32.bor(owned, bit32.lshift(1, weaponTier - 1)) or owned
	-- Additive onboarding progress. Do not re-open a claimed/legacy tutorial or erase an unclaimed 5/5.
	local steps = Config.Tutorial and Config.Tutorial.Steps or { Kill = 0, Guide = 1, Quest = 2, Done = 99 }
	if d.TutorialStep ~= steps.Kill and d.TutorialStep ~= steps.Guide
		and d.TutorialStep ~= steps.Quest and d.TutorialStep ~= steps.Done then
		d.TutorialStep = TUTORIAL_DONE
	end
	local kills = d.TutorialKills
	if type(kills) ~= "number" or kills ~= kills or math.abs(kills) == math.huge then kills = 0 end
	local target = (Config.Tutorial and Config.Tutorial.QuestKills) or 5
	d.TutorialKills = math.clamp(math.floor(kills), 0, target)
	-- BB2: additive settings blob (Version stays 3): unknown / broken fields fall back to the defaults, keys are checked
	d.Settings = Config.SanitizeSettings(d.Settings)
	-- BB10 weekly ranking fields (additive): repaired, and an older week's points start over (written at the last leave).
	-- (Guarded: some offline suites load a cut-down Config without the ranking block.)
	if Config.SanitizeRank then Config.SanitizeRank(d, os.time()) end
	-- A23-32 bag '얻은 순' numbers (additive; an old save starts with 0 everywhere)
	if Config.SanitizeItemSeq then Config.SanitizeItemSeq(d) end
end

-- One UpdateAsync write of `data` (deep-copied now). The caller holds the user's write slot.
-- `sessionToken` = the token this session wrote at Load; the write is cancelled unless the stored record still carries it.
-- Returns (ok, abortedByForeignLock).
local function writeRecord(userId, data, release, label, sessionToken)
	if not store then return false, false end
	if type(sessionToken) ~= "string" then
		Util.Warn(TAG, ("save of %s refused: no session token"):format(label))
		return false, true
	end
	local copy = Util.DeepCopy(data)
	if release then
		copy.SessionLock = nil
	else
		copy.SessionLock = { JobId = game.JobId, Time = os.time() }
	end
	copy.SessionToken = sessionToken

	local key = keyFor(userId)
	local attempts = 1 + math.max(0, Config.Data.SaveRetries)
	for attempt = 1, attempts do
		local foreign = false
		local ok, err = pcall(store.UpdateAsync, store, key, function(old)
			-- a newer session (this or another server) loaded the record after ours, or it was deleted: never
			-- overwrite it, even when that session already released its lock
			if type(old) ~= "table" or old.SessionToken ~= sessionToken then
				foreign = true
				return nil
			end
			if isLock(old.SessionLock) and old.SessionLock.JobId ~= game.JobId then
				foreign = true
				return nil -- another server owns this record: cancel the write
			end
			foreign = false
			return copy
		end)
		if ok then
			if foreign then
				Util.Warn(TAG, ("save of %s aborted: a newer session owns this data"):format(label))
				return false, true
			end
			return true, false
		end
		Util.Warn(TAG, ("save attempt %d/%d failed for %s: %s"):format(attempt, attempts, label, tostring(err)))
		if attempt < attempts then
			task.wait(2 ^ (attempt - 1)) -- 1, 2, 4 s
		end
	end
	return false, false
end

local function waitForProbe()
	local t0 = os.clock()
	while not probeDone do
		if os.clock() - t0 > PROBE_TIMEOUT then return false end
		task.wait()
	end
	return true
end

------------------------------------------------------------------ public API
function DataService.Init(registry)
	S = registry
end

function DataService.Start()
	-- DataStore probe (memory mode only ever in Studio)
	task.spawn(function()
		local okStore, result = pcall(function()
			return DataStoreService:GetDataStore(Config.Data.StoreName)
		end)
		if okStore and result then
			store = result
		end
		if RunService:IsStudio() then
			-- Studio test aid (game dev 1, 2026-10-06): ServerStorage attribute StudioFreshSave = true -> in-memory data, i.e. a
			-- brand-new save that is never written, for first-session checks without touching the tester's real save
			local okFresh, freshTest = pcall(function()
				return game:GetService("ServerStorage"):GetAttribute("StudioFreshSave") == true
			end)
			freshTest = okFresh and freshTest == true
			local usable = false
			if store and not freshTest then
				usable = pcall(function()
					store:GetAsync("__probe")
				end)
			end
			if not usable then
				memoryMode = true
				warn(freshTest and "[DataService] StudioFreshSave is on: fresh in-memory data; nothing will be saved."
					or "[DataService] DataStore unavailable (enable Studio Access to API Services). Using in-memory data; nothing will be saved.")
			end
		elseif not store then
			Util.Warn(TAG, "GetDataStore failed: " .. tostring(result))
		end
		probeDone = true
	end)

	-- autosave
	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveInterval)
			if probeDone and not memoryMode then
				local list = {}
				for player in cache do
					if not releasing[player] and not foreignLock[player] and player.Parent ~= nil then
						table.insert(list, player)
					end
				end
				for _, player in list do
					task.spawn(DataService.Save, player, false)
				end
			end
		end
	end)

	print("[DataService] started")
end

-- Load body; the caller holds the user's write slot. nil = failed or the player left
local function loadLocked(player)
	local userId = player.UserId
	local key = keyFor(userId)
	-- one token per Load (retries reuse it, so a committed-but-errored attempt is still recognised as ours)
	local sessionToken = HttpService:GenerateGUID(false)

	local loaded, fresh = nil, false
	local retries = math.max(1, Config.Data.LoadRetries)
	local warnedLock = false
	local tooNew, storedVersion = false, nil
	for attempt = 1, retries do
		if player.Parent == nil then
			return nil
		end
		local final = (attempt == retries) -- the final attempt steals the lock (dead-server recovery)
		local locked, captured, capturedFresh = false, nil, false
		local ok, err = pcall(store.UpdateAsync, store, key, function(old)
			tooNew = false
			-- CR-L3: a record saved by a newer data version is never rewritten (or locked) by this older server
			if type(old) == "table" and (tonumber(old.Version) or 1) > Config.Data.Version then
				tooNew, storedVersion = true, old.Version
				locked, captured = false, nil
				return nil
			end
			if not final and type(old) == "table" and isLiveForeignLock(old.SessionLock) then
				locked, captured = true, nil
				return nil -- cancel the write and retry later
			end
			locked = false
			capturedFresh = not hasStoredData(old)
			local d = (type(old) == "table") and old or {}
			d.SessionLock = { JobId = game.JobId, Time = os.time() }
			d.SessionToken = sessionToken
			captured = d
			return d
		end)
		if ok and tooNew then
			break
		end
		if ok and captured and not locked then
			loaded, fresh = captured, capturedFresh
			break
		end
		if not ok then
			Util.Warn(TAG, ("load attempt %d/%d failed for %s: %s"):format(attempt, retries, player.Name, tostring(err)))
		elseif locked and not warnedLock then
			warnedLock = true
			Util.Warn(TAG, ("data of %s is locked by another server; retrying"):format(player.Name))
		end
		if not final then
			task.wait(Config.Data.LoadRetryDelay)
		end
	end

	if tooNew then
		-- CR-L3: kicked with LoadFailed; the player rejoins a server running the newer version
		Util.Warn(TAG, ("data of %s has version %s (> %d): saved by a newer server; refusing to load"):format(
			player.Name, tostring(storedVersion), Config.Data.Version))
		return nil
	end
	if not loaded then
		return nil
	end

	local d = Util.DeepCopy(loaded)
	d.SessionLock = nil
	d.SessionToken = nil -- kept in sessionTokens, never in the session table

	-- A4 / A5-C5: onboarding step BEFORE the generic default fill
	if fresh then
		d.TutorialStep = TUTORIAL_NEW
	elseif type(d.TutorialStep) ~= "number" then
		d.TutorialStep = TUTORIAL_DONE
	end

	if not fresh then
		migrate(d, player) -- a brand-new record gets everything from the defaults below
	end
	fillDefaults(d, player.Name)
	d.Version = Config.Data.Version
	if (tonumber(d.FirstJoinTime) or 0) == 0 then
		d.FirstJoinTime = os.time()
	end

	if player.Parent == nil then
		-- left during the load: write it back unlocked; nothing is cached
		writeRecord(userId, d, true, player.Name, sessionToken)
		return nil
	end

	sessionTokens[player] = sessionToken
	cache[player] = d
	return d
end

-- yields. nil = failed (caller kicks) or the player left during the load
function DataService.Load(player)
	if cache[player] then return cache[player] end
	if not waitForProbe() then
		Util.Warn(TAG, "DataStore probe did not finish; cannot load " .. player.Name)
		return nil
	end
	if player.Parent == nil then return nil end

	if memoryMode then
		local d = Util.DeepCopy(Config.Data.Defaults)
		d.TutorialStep = TUTORIAL_NEW -- always a fresh record in memory mode (A5-C5)
		d.Version = Config.Data.Version
		d.FirstJoinTime = os.time()
		cache[player] = d
		return d
	end
	if not store then
		Util.Warn(TAG, "no DataStore available; cannot load " .. player.Name)
		return nil
	end

	local userId = player.UserId
	-- CR-M1: a previous session of this user on this server (fast rejoin) must finish its Release first; its final
	-- save may not have queued for the slot yet (PlayerLeaving handlers still running)
	local tWait = os.clock()
	while hasOtherSession(player) do
		if player.Parent == nil then return nil end
		if os.clock() - tWait >= SLOT_TIMEOUT then
			Util.Warn(TAG, "the previous session of " .. player.Name .. " is still saving; cannot load")
			return nil
		end
		task.wait(0.1)
	end
	if player.Parent == nil then return nil end

	-- holding the slot also waits for any queued save of this user (autosave retries, release) to finish first
	local token = acquireSlot(userId)
	if not token then
		Util.Warn(TAG, "a previous save of " .. player.Name .. " is still running; cannot load")
		return nil
	end
	-- the slot is always released, even if the body throws (a leaked slot would block every later load / save)
	local okBody, result = pcall(loadLocked, player)
	releaseSlot(userId, token)
	if not okBody then
		Util.Warn(TAG, "load error for " .. player.Name .. ": " .. tostring(result))
		return nil
	end
	return result
end

-- the live session table (mutable)
function DataService.Get(player)
	return cache[player]
end

-- yields; safe to call concurrently (writes of one user are serialized)
function DataService.Save(player, release)
	release = (release == true)
	if not cache[player] then return false end
	if memoryMode then return true end
	if not store or foreignLock[player] then return false end

	local userId = player.UserId
	local token = acquireSlot(userId)
	if not token then
		Util.Warn(TAG, "save of " .. player.Name .. " skipped: the previous save is still running")
		return false
	end
	local data = cache[player]
	-- re-check after waiting: the session may have been released, or a release may be in progress
	if not data or foreignLock[player] or (releasing[player] and not release) then
		releaseSlot(userId, token)
		return false
	end
	-- pcall: the slot must be released even if the write throws (CR-M1)
	local okCall, ok, foreign = pcall(writeRecord, userId, data, release, player.Name, sessionTokens[player])
	releaseSlot(userId, token)
	if not okCall then
		Util.Warn(TAG, "save error for " .. player.Name .. ": " .. tostring(ok))
		return false
	end
	if foreign then
		foreignLock[player] = true
	end
	return ok == true
end

-- yields; sets LastLogoutTime, final unlocked save, drops the cache. Idempotent.
function DataService.Release(player)
	if releasing[player] then
		local t0 = os.clock()
		while releasing[player] and os.clock() - t0 < RELEASE_WAIT do
			task.wait(0.1)
		end
		return
	end
	local data = cache[player]
	if not data then return end

	releasing[player] = true
	data.LastLogoutTime = os.time()
	local ok, result = pcall(DataService.Save, player, true)
	if not ok then
		Util.Warn(TAG, "final save error for " .. player.Name .. ": " .. tostring(result))
	elseif not result and not memoryMode then
		Util.Warn(TAG, "final save failed for " .. player.Name)
	end
	cache[player] = nil
	sessionTokens[player] = nil
	foreignLock[player] = nil
	releasing[player] = nil
end

function DataService.IsMemoryMode()
	return memoryMode
end

function DataService.IsPersistentReady()
	return probeDone and not memoryMode and store ~= nil
end

return DataService
