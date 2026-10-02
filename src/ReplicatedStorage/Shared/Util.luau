-- Util.luau : small helpers shared by server and client.
local Players = game:GetService("Players")

local Util = {}

------------------------------------------------------------------ Signal
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

-- returns a connection { Disconnect = function() }
function Signal:Connect(fn)
	local entry = { fn = fn, connected = true }
	table.insert(self._handlers, entry)
	local handlers = self._handlers
	return {
		Disconnect = function()
			entry.connected = false
			local idx = table.find(handlers, entry)
			if idx then table.remove(handlers, idx) end
		end,
	}
end

-- synchronous; each handler runs in pcall so one failure does not stop the others
function Signal:Fire(...)
	for _, entry in table.clone(self._handlers) do
		if entry.connected then
			local ok, err = pcall(entry.fn, ...)
			if not ok then warn("[Signal] handler error: " .. tostring(err)) end
		end
	end
end

Util.Signal = Signal

------------------------------------------------------------------ logging
function Util.Log(tag, msg)
	print("[" .. tostring(tag) .. "] " .. tostring(msg))
end

function Util.Warn(tag, msg)
	warn("[" .. tostring(tag) .. "] " .. tostring(msg))
end

------------------------------------------------------------------ time / random
Util.Random = Random.new()

function Util.Now()
	return workspace:GetServerTimeNow()
end

------------------------------------------------------------------ formatting
local SUFFIXES = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }

function Util.FormatNumber(n)
	n = tonumber(n) or 0
	local sign = n < 0 and "-" or ""
	n = math.abs(n)
	for _, s in SUFFIXES do
		if n >= s[1] then
			local v = n / s[1]
			local str
			if v >= 100 then
				str = tostring(math.floor(v))
			else
				str = string.format("%.1f", math.floor(v * 10) / 10)
				str = string.gsub(str, "%.0$", "")
			end
			return sign .. str .. s[2]
		end
	end
	return sign .. tostring(math.floor(n))
end

function Util.FormatTime(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- 0.1075 -> "10.75", 0.05 -> "5", 0.125 -> "12.5"
function Util.FormatPercent(fraction)
	local v = math.floor((fraction or 0) * 10000 + 0.5) / 100
	return string.format("%g", v)
end

-- final rounding for every damage / heal number
function Util.RoundDamage(x)
	return math.max(1, math.floor((x or 0) + 0.5))
end

------------------------------------------------------------------ rate limit (server)
local lastCall = {} -- [Player] = { [key] = os.clock() }

-- true if this call is allowed (and records it); false if called again within minInterval seconds
function Util.RateLimit(player, key, minInterval)
	local now = os.clock()
	local p = lastCall[player]
	if not p then
		p = {}
		lastCall[player] = p
	end
	local last = p[key]
	if last and now - last < minInterval then return false end
	p[key] = now
	return true
end

function Util.ClearPlayer(player)
	lastCall[player] = nil
end

------------------------------------------------------------------ characters
function Util.GetCharacter(player)
	local c = player and player.Character
	if c and c.Parent then return c end
	return nil
end

function Util.GetHumanoid(player)
	local c = Util.GetCharacter(player)
	if not c then return nil end
	return c:FindFirstChildOfClass("Humanoid")
end

function Util.GetRoot(player)
	local c = Util.GetCharacter(player)
	if not c then return nil end
	return c:FindFirstChild("HumanoidRootPart")
end

function Util.IsAlive(player)
	local h = Util.GetHumanoid(player)
	return h ~= nil and h.Health > 0 and Util.GetRoot(player) ~= nil
end

-- first existing child among names (R15 name first, then R6), or nil
function Util.FindPart(character, ...)
	if not character then return nil end
	for _, name in { ... } do
		local p = character:FindFirstChild(name)
		if p and p:IsA("BasePart") then return p end
	end
	return nil
end

function Util.FlatDistance(a, b)
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

-- Model:ScaleTo wrapped in pcall; ignores invalid scales. Returns true on success.
function Util.SafeScaleTo(model, scale)
	if not model or not model.Parent or type(scale) ~= "number" or scale <= 0 then return false end
	local ok = pcall(model.ScaleTo, model, scale)
	return ok
end

------------------------------------------------------------------ instances
function Util.GetFolder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

-- props: any Part properties plus optional ClassName (default "Part") and Parent (applied last)
function Util.MakePart(props)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "Parent" and k ~= "ClassName" then
			p[k] = v
		end
	end
	if props.Parent then p.Parent = props.Parent end
	return p
end

-- welds part1 to part0 at their CURRENT relative position (WeldConstraint parented to part1)
function Util.Weld(part0, part1)
	local w = Instance.new("WeldConstraint")
	w.Part0 = part0
	w.Part1 = part1
	w.Parent = part1
	return w
end

function Util.RandomPointInZone(zone, inset)
	inset = inset or 0
	local hx = math.max(1, zone.Size.X / 2 - inset)
	local hz = math.max(1, zone.Size.Z / 2 - inset)
	return Vector3.new(
		zone.Center.X + Util.Random:NextNumber(-hx, hx),
		0,
		zone.Center.Z + Util.Random:NextNumber(-hz, hz)
	)
end

function Util.DeepCopy(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in t do out[k] = Util.DeepCopy(v) end
	return out
end

function Util.PlayersExcept(player)
	local out = {}
	for _, p in Players:GetPlayers() do
		if p ~= player then table.insert(out, p) end
	end
	return out
end

return Util
