-- SwitchService.luau : the live switchboard (시스템 점검 1회차 "더할 것 ②", 게임성 개발 3, 2026-10-09; contract
-- docs/design/ops_safety_server_2026-10-09.md, commands docs/ops/switchboard_2026-10-09.md). One DataStore document
-- (Config.StoreName(Config.Switches.Store), key Config.Switches.Key) holds { Set = { [switch] = value }, At = os.time() }. Every
-- Interval seconds each server reads it and applies ONLY the switches listed in Config.Switches.Defs, with the value cut
-- to the def's type and range (a Bool is true / false, a Number is clamped to Min..Max, anything else is ignored). A failed
-- read keeps the last answer (the first failed read keeps the defaults). Writing is ours, from the Studio command bar (no key,
-- no account page): see the ops doc. Nothing here is a purchase or a stat; a switch only turns a feature off (or back on).
--   SwitchService.On(key)    -> true while the switch is on (default: the def's Default; unknown key: true)
--   SwitchService.Value(key) -> the current value (Bool: true / false)
--   GameState SwitchPassSales / SwitchHalloween / SwitchCrownWar / SwitchGoose (the screen hides what is off)
--   Halloween: Config.Halloween.Enabled follows the switch (HalloweenService checks it every tick); CrownWar: WarService stops
--   counting points and rounds; Goose: GooseService starts no new goose; PassSales: the screen's [Buy] buttons (game dev 1)
--   Signal SwitchService.Changed(key, value)
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local SwitchService = {}
SwitchService.Changed = Util.Signal.new() -- (key, value)

local TAG = "SwitchService"
local S = nil
local W = Config.Switches or {}
local VALUES = {} -- [key] = the applied value
local ORIGINAL = {} -- values the config had before a switch touched them (Halloween.Enabled)
local STORE = nil
local READ = false -- true after this server's first good read of the board (until then a def's Unread, if any, applies)

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function defs()
	return type(W.Defs) == "table" and W.Defs or {}
end

-- one value cut to its def (nil = not acceptable: the def's default stays)
function SwitchService.Sanitize(def, v)
	if type(def) ~= "table" then return nil end
	if def.Type == "Number" then
		if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return nil end
		return math.clamp(v, num(def.Min, 0), num(def.Max, 1))
	end
	if type(v) ~= "boolean" then return nil end
	return v
end

-- a document (any shape) -> { [key] = value } for the listed switches only
function SwitchService.Parse(doc)
	local out = {}
	local set = type(doc) == "table" and type(doc.Set) == "table" and doc.Set or {}
	for key, def in defs() do
		local v = SwitchService.Sanitize(def, set[key])
		if v ~= nil then out[key] = v end
	end
	return out
end

-- a switch's value while nothing better is known: its Unread until the first good read (if it has one), else its Default
local function fallback(def)
	if not READ and def.Unread ~= nil then return def.Unread end
	return def.Default
end

function SwitchService.Value(key)
	local def = defs()[key]
	if def == nil then return true end
	local v = VALUES[key]
	if v == nil then return fallback(def) end
	return v
end

-- true once this server has read the board (an empty board counts: every switch on its Default)
function SwitchService.HasRead()
	return READ
end

function SwitchService.On(key)
	local v = SwitchService.Value(key)
	if type(v) == "boolean" then return v end
	return v ~= 0
end

local function publish(key)
	local ok, gs = pcall(Net.GameState)
	if ok and gs then gs:SetAttribute("Switch" .. key, SwitchService.Value(key)) end
end

-- what a switch does to the server's own config (the rest are read through SwitchService.On by their services)
local function apply(key)
	-- ⑤ (최종 검수 10/14): a def with a Feature turns that build switch off on this server while it is false
	local def = defs()[key]
	if type(def) == "table" and type(def.Feature) == "string" then
		Config.LiveOff = type(Config.LiveOff) == "table" and Config.LiveOff or {}
		Config.LiveOff[def.Feature] = (SwitchService.On(key) == false) or nil
	end
	if key == "Halloween" and type(Config.Halloween) == "table" then
		if ORIGINAL.Halloween == nil then ORIGINAL.Halloween = Config.Halloween.Enabled end
		Config.Halloween.Enabled = SwitchService.On("Halloween") and ORIGINAL.Halloween == true
	end
end

-- applies a parsed document: every listed switch gets its new value or goes back to its default
function SwitchService.Apply(parsed)
	for key, def in defs() do
		local new = parsed[key]
		if new == nil then new = def.Default end
		if VALUES[key] ~= new then
			VALUES[key] = new
			apply(key)
			publish(key)
			SwitchService.Changed:Fire(key, new)
			print(("[SwitchService] %s = %s"):format(key, tostring(new)))
		end
	end
end

local function store()
	if STORE == nil then
		local name = Config.StoreName and Config.StoreName(W.Store or "HaloHorns_Switches_v1") or (W.Store or "HaloHorns_Switches_v1")
		if RunService:IsStudio() then name ..= "_STUDIO" end
		local ok, st = pcall(DataStoreService.GetDataStore, DataStoreService, name)
		STORE = ok and st or false
	end
	return STORE or nil
end

-- one read: a failed read changes nothing (the last answer stays)
function SwitchService.Refresh()
	local st = store()
	if not st then return false end
	local ok, doc = pcall(st.GetAsync, st, W.Key or "Live")
	if not ok then
		Util.Warn(TAG, "read: " .. tostring(doc))
		return false
	end
	READ = true
	SwitchService.Apply(SwitchService.Parse(doc))
	return true
end

function SwitchService.Init(registry)
	S = registry
end

function SwitchService.Start()
	for key, def in defs() do
		VALUES[key] = fallback(def)
		publish(key)
	end
	task.spawn(function()
		while true do
			local ok, err = pcall(SwitchService.Refresh)
			if not ok then Util.Warn(TAG, "refresh: " .. tostring(err)) end
			task.wait(math.max(10, num(W.Interval, 60)))
		end
	end)
	print("[SwitchService] started")
end

return SwitchService
