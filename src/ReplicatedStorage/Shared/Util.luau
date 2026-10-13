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

-- 1052 -> "1,052" (whole numbers with thousands separators; BB4 power, ranking, Tab list)
function Util.FormatInt(n)
	n = math.floor((tonumber(n) or 0) + 0.5)
	local sign = n < 0 and "-" or ""
	local s = tostring(math.abs(n))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	if string.sub(out, 1, 1) == "," then out = string.sub(out, 2) end
	return sign .. out
end

-- 125 -> "2:05"; an hour or more -> "1:57:23" (최종 검수 10/13: the goose chip said "117:23")
function Util.FormatTime(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, seconds // 60 % 60, seconds % 60)
	end
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

-- CR-L44 (moved from HUD glyphSafe): false when the text has a symbol Gotham / the Korean fallback font lacks
-- (⚙ ⚔ ↻ render as tofu boxes). Only these symbols of the U+2190..U+2BFF block are known to render: ← → ▲ ▶ ▼ ★ ☆.
local GLYPH_SAFE_SYMBOLS = { [0x2190] = true, [0x2192] = true, [0x25B2] = true, [0x25B6] = true, [0x25BC] = true,
	[0x2605] = true, [0x2606] = true }
function Util.GlyphSafe(text)
	if type(text) ~= "string" then return false end
	local ok, safe = pcall(function()
		for _, cp in utf8.codes(text) do
			if cp >= 0x2190 and cp <= 0x2BFF and not GLYPH_SAFE_SYMBOLS[cp] then return false end
		end
		return true
	end)
	return ok and safe == true
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
-- Nicknames count Unicode codepoints, never UTF-8 bytes. Reject invisible/control and markup inputs.
function Util.ValidateNickname(text)
	if type(text) ~= "string" or #text > 80 then return false end
	local ok, count = pcall(utf8.len, text)
	if not ok or not count or count < 2 or count > 20 then return false end
	if string.find(text, "[#<>&]") or string.sub(text, 1, 1) == " "
		or string.sub(text, -1) == " " or string.find(text, "  ", 1, true) then return false end
	local valid = pcall(function()
		for _, cp in utf8.codes(text) do
			if cp < 0x20 or (cp >= 0x7F and cp <= 0x9F) or (cp >= 0xD800 and cp <= 0xDFFF)
				or cp > 0x10FFFF or cp == 0xA0 or cp == 0xAD or cp == 0x1680 or cp == 0x180E
				or (cp >= 0x2000 and cp <= 0x200F) or (cp >= 0x2028 and cp <= 0x202F)
				or (cp >= 0x205F and cp <= 0x206F) or cp == 0x3000 or cp == 0xFEFF
				or (cp >= 0xFFF9 and cp <= 0xFFFB) or (cp >= 0xE0000 and cp <= 0xE007F) then
				error("invalid nickname codepoint")
			end
		end
	end)
	return valid, count
end

function Util.NicknameCanonical(text)
	return (string.gsub(text, "[A-Z]", string.lower)) -- ASCII casefold only; Unicode bytes remain intact
end

function Util.PlayerDisplayName(player)
	if not player then return "" end
	local nickname = player:GetAttribute("Nickname")
	-- Only NicknameService publishes the server-filtered, globally confirmed attribute.
	if player:GetAttribute("NicknameVerified") == true and Util.ValidateNickname(nickname) then return nickname end
	return player.DisplayName
end

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

-- 빛 마을 점검 #2: where a placed marker puts a named spot. A workspace instance tagged `tag` with the attribute Spot = key
-- (a Model: its pivot, a Part: its position) -> that position, else nil. The server (StoryQuestService) and the client
-- (QuestTarget / HUD guides) use this one rule: Util.TaggedSpot(Config.StoryQuests.LandmarkTag, key) or
-- Config.StoryQuests.Landmarks[key], so a marker moves the spot for both at once. Tags replicate; never throws.
function Util.TaggedSpot(tag, key)
	if type(tag) ~= "string" or type(key) ~= "string" then return nil end
	local okTag, tagged = pcall(function()
		return game:GetService("CollectionService"):GetTagged(tag)
	end)
	if not okTag or type(tagged) ~= "table" then return nil end
	for _, inst in tagged do
		local okPos, pos = pcall(function()
			if inst:GetAttribute("Spot") ~= key or not inst:IsDescendantOf(workspace) then return nil end
			if inst:IsA("Model") then return inst:GetPivot().Position end
			return inst.Position
		end)
		if okPos and typeof(pos) == "Vector3" then return pos end
	end
	return nil
end

-- every instance carrying the CollectionService tag (e.g. Config.Ground.Tag "WalkGround" for the servers' ground rays,
-- Config.GroundRoots); {} on any failure, never throws
function Util.Tagged(tag)
	if type(tag) ~= "string" then return {} end
	local ok, list = pcall(function()
		return game:GetService("CollectionService"):GetTagged(tag)
	end)
	return (ok and type(list) == "table") and list or {}
end

-- (pure) A23-121 stage 6: a polyline road (Config.Map.RoadPaths) as straight pieces for the 2D maps: each piece's
-- centre (X, Z), its Length (+ the width, so the round ends overlap at the bends), Width and its turn in degrees (the
-- maps: +X right, +Z down, so atan2(dz, dx) = GuiObject.Rotation, clockwise); zero-length pieces are skipped
function Util.PathSegments(points, width)
	local out = {}
	if type(points) ~= "table" then return out end
	width = math.max(0, tonumber(width) or 0)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		if typeof(a) == "Vector3" and typeof(b) == "Vector3" then
			local dx, dz = b.X - a.X, b.Z - a.Z
			local len = math.sqrt(dx * dx + dz * dz)
			if len > 1e-3 then
				table.insert(out, { X = (a.X + b.X) / 2, Z = (a.Z + b.Z) / 2, Length = len + width, Width = width,
					Rotation = math.deg(math.atan2(dz, dx)) })
			end
		end
	end
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
