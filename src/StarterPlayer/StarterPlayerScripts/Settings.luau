-- Settings.luau : BB2 (docs/design/beta_basics_2026-10-05.md) client side of the saved settings (server: SettingsService).
-- Holds the current settings (Config.SanitizeSettings shape: V, Keys, Sfx, Shake, DmgNum, Tags, KeyBadges, Lang,
-- BagSort), pulls the saved blob once at Start ("SetSettings" with no arguments) and sends changes:
--   * one pending blob, sent at max(now, lastSent + Config.RateLimits.SetSettings + 0.05) (the server silently drops a
--     second call inside its limit); Flush() (window close) goes through the same slot, so nothing is sent twice
--     inside the limit;
--   * the newest blob stays "in flight" until an echo with its Seq (or newer) arrives. The server measures its limit on
--     arrival, so network jitter can squeeze two sends under 1 s and it drops the second without an answer: when no
--     echo came ST.EchoWait s after the slot, the fields of that blob are marked unsent again and go out through the
--     same slot (a blob is always the full value, so a resend is harmless). So the last change is never lost;
--   * nothing is sent before the first server value arrived (changes made before it are re-applied on top of it);
--   * a "Settings" echo with a Seq lower than the newest Seq sent is ignored; otherwise the server value wins, except
--     the fields changed here that are still waiting to be sent.
-- API: Get(key) (copy), All() (copy), Set(key, value) -> bool, SetKeys(sparse), Flush(), Loaded(),
--      Changed (Util.Signal: (settings copy, fromServer)). Other modules read it lazily through the registry (C.Settings).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local Settings = {}
local TAG = "Settings"
local ST = {
	Value = Config.SanitizeSettings(nil), -- current settings (defaults until the server answers)
	Dirty = {}, -- [field] = true: changed here and not sent yet
	Local = {}, -- [field] = the local value of a Dirty field (re-applied over a server value)
	Seq = 0, -- newest Seq sent
	LastSent = -math.huge, -- os.clock() of the last SetSettings call (pull included)
	Timer = false, -- a delayed send is scheduled
	InFlight = false, -- { Seq, Fields } the newest blob sent and not answered yet (re-sent when no echo comes)
	EchoWait = 2, -- s after the send slot without an echo of the newest blob -> the server dropped it: send again
	Resends = 0, -- resends in a row without any answer
	MaxResends = 5, -- then stop (the server keeps silent, e.g. its data is gone) until the next change
	Loaded = false, -- the first server value arrived
	Remotes = {}, -- [name] = RemoteEvent once found
	Started = false,
}

Settings.Changed = Util.Signal.new() -- (settings copy, fromServer)

local function sameValue(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in a do
		if not sameValue(v, b[k]) then return false end
	end
	for k in b do
		if a[k] == nil then return false end
	end
	return true
end

-- calls fn(remote) now or once the remote exists (never yields the caller; same pattern as Panels ITEMS.Bind)
local function withRemote(name, fn)
	local r = ST.Remotes[name]
	if not r then
		local folder = ReplicatedStorage:FindFirstChild("Remotes")
		r = folder and folder:FindFirstChild(name)
		if r and r:IsA("RemoteEvent") then ST.Remotes[name] = r else r = nil end
	end
	if r then
		fn(r)
		return
	end
	task.spawn(function()
		local f = ReplicatedStorage:WaitForChild("Remotes", 30)
		local rr = f and f:WaitForChild(name, 30)
		if rr and rr:IsA("RemoteEvent") then
			ST.Remotes[name] = rr
			fn(rr)
		else
			Util.Warn(TAG, "remote missing: " .. name)
		end
	end)
end

local function interval()
	local rl = Config.RateLimits
	local v = type(rl) == "table" and tonumber(rl.SetSettings) or nil
	if v == nil or v ~= v or v < 0 then v = 1 end
	return v + 0.05
end

-- one SetSettings call (the pull has no blob); every call takes the send slot
local function fire(blob)
	ST.LastSent = os.clock()
	withRemote("SetSettings", function(r)
		local ok, err = pcall(function()
			if blob == nil then r:FireServer() else r:FireServer(blob) end
		end)
		if not ok then Util.Warn(TAG, "send failed: " .. tostring(err)) end
	end)
end

local schedule -- forward

local function sendNow()
	if not ST.Loaded or next(ST.Dirty) == nil then return end
	ST.Seq += 1
	local blob = Util.DeepCopy(ST.Value)
	blob.Seq = ST.Seq
	-- an unanswered older blob is replaced: this one carries its fields too (every blob is the full value)
	local fields = ST.InFlight and ST.InFlight.Fields or {}
	for k in ST.Dirty do fields[k] = true end
	local flight = { Seq = ST.Seq, Fields = fields }
	ST.InFlight = flight
	table.clear(ST.Dirty)
	table.clear(ST.Local)
	fire(blob)
	task.delay(interval() + ST.EchoWait, function()
		if ST.InFlight ~= flight then return end -- answered, or a newer blob took over
		ST.InFlight = false
		if ST.Resends >= ST.MaxResends then return end
		ST.Resends += 1
		for k in flight.Fields do
			if not ST.Dirty[k] then -- a field changed again meanwhile is already waiting with its newer value
				ST.Dirty[k] = true
				ST.Local[k] = Util.DeepCopy(ST.Value[k])
			end
		end
		schedule()
	end)
end

-- the pending blob goes out at max(now, lastSent + limit + 0.05); one timer at a time
function schedule()
	if ST.Timer or not ST.Loaded or next(ST.Dirty) == nil then return end
	local wait = ST.LastSent + interval() - os.clock()
	if wait <= 0 then
		sendNow()
		return
	end
	ST.Timer = true
	task.delay(wait, function()
		ST.Timer = false
		if os.clock() < ST.LastSent + interval() then
			schedule() -- another call took the slot meanwhile
		else
			sendNow()
		end
	end)
end

local function onSettings(payload)
	if type(payload) ~= "table" or type(payload.Settings) ~= "table" then return end
	local seq = tonumber(payload.Seq) or 0
	if seq ~= seq or seq < ST.Seq then return end -- an older echo: a newer blob is on its way
	if ST.InFlight and seq >= ST.InFlight.Seq then -- the newest blob arrived
		ST.InFlight = false
		ST.Resends = 0
	end
	local value = Config.SanitizeSettings(payload.Settings)
	for k in ST.Dirty do value[k] = Util.DeepCopy(ST.Local[k]) end -- my unsent changes stay
	local first = not ST.Loaded
	local changed = not sameValue(value, ST.Value)
	ST.Value = value
	ST.Loaded = true
	if changed or first then Settings.Changed:Fire(Util.DeepCopy(ST.Value), true) end
	if first then schedule() end -- changes made before the first server value go out now
end

function Settings.Get(key)
	return Util.DeepCopy(ST.Value[key])
end

function Settings.All()
	return Util.DeepCopy(ST.Value)
end

function Settings.Loaded()
	return ST.Loaded
end

-- key = a Config.Settings.Defs field or "Keys"; the value is sanitized like the server does. false = unknown key.
function Settings.Set(key, value)
	if key ~= "Keys" and not (Config.Settings.Defs[key]) then return false end
	local probe = Util.DeepCopy(ST.Value)
	probe[key] = Util.DeepCopy(value)
	local clean = Config.SanitizeSettings(probe)[key]
	if sameValue(clean, ST.Value[key]) then return true end
	ST.Value[key] = clean
	ST.Dirty[key] = true
	ST.Local[key] = Util.DeepCopy(clean)
	ST.Resends = 0
	Settings.Changed:Fire(Util.DeepCopy(ST.Value), false)
	schedule()
	return true
end

-- sparse Keys (Keybinds.SetLocal / Clear / Reset)
function Settings.SetKeys(sparse)
	return Settings.Set("Keys", type(sparse) == "table" and sparse or {})
end

-- window close: the pending blob goes out through the same slot (now when allowed, else at the slot time)
function Settings.Flush()
	schedule()
end

function Settings.Init(_registry)
	withRemote("Settings", function(r)
		r.OnClientEvent:Connect(function(payload)
			local ok, err = pcall(onSettings, payload)
			if not ok then Util.Warn(TAG, "settings update error: " .. tostring(err)) end
		end)
	end)
end

function Settings.Start()
	if ST.Started then return end
	ST.Started = true
	fire(nil) -- "send me mine" (the server also sends it once on PlayerReady)
	print("[Settings] started")
end

return Settings
