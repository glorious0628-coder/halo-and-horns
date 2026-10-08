-- Offline checks for ChatTags.luau (SPEC A23-75 the VIP pass: the gold [VIP] in the chat). The runner
-- (tools/test_chat_tags.py) prepends TAGS_SOURCE (the current ChatTags.luau text). Roblox is replaced by small doubles:
-- Players:GetPlayerByUserId, players with attributes, Instance.new("TextChatMessageProperties"). Every check is named
-- and collected, never asserted. No Studio, Roblox API or network calls.
local checks, failed = 0, 0
local function check(name, ok, detail)
	checks += 1
	if not ok then
		failed += 1
		print(("CHECK_FAIL %s :: %s"):format(name, tostring(detail or "")))
	end
end

local function player(userId, name, attrs)
	local p = { __kind = "Instance", ClassName = "Player", UserId = userId, Name = name, Attr = attrs or {} }
	function p:IsA(c) return c == "Player" or c == "Instance" end
	function p:GetAttribute(k) return self.Attr[k] end
	return p
end
local VIP = player(1, "Vee", { PassVIP = true })
local PLAIN = player(2, "Pat", {})
local LATE = player(3, "Lee", { PassVIP = false })
local BY_ID = { [1] = VIP, [2] = PLAIN, [3] = LATE }
local PLAYERS = { GetPlayerByUserId = function(_, id) return BY_ID[id] end }
local MADE = 0

local env = setmetatable({
	game = { GetService = function(_, n)
		if n == "Players" then return PLAYERS end
		return {}
	end },
	typeof = function(v) return type(v) == "table" and rawget(v, "__kind") or type(v) end,
	Instance = { new = function(class)
		MADE += 1
		return { __kind = "Instance", ClassName = class }
	end },
}, { __index = getfenv() })
local fn = assert(loadstring(TAGS_SOURCE, "=ChatTags"))
setfenv(fn, env)
local Tags = fn()

local function msg(userId, prefix, metadata)
	return { TextSource = userId and { UserId = userId } or nil, PrefixText = prefix, Metadata = metadata or "", Text = "hi" }
end

-- Prefix
local p = Tags.Prefix(VIP, "Vee")
check("a VIP's prefix gets a gold [VIP] in front of the name", p == '<font color="#FFD24A">[VIP]</font> Vee', p)
check("no pass: no prefix change", Tags.Prefix(PLAIN, "Pat") == nil)
check("PassVIP false: no prefix change", Tags.Prefix(LATE, "Lee") == nil)
check("not a player: nil", Tags.Prefix(nil, "x") == nil and Tags.Prefix({}, "x") == nil and Tags.Prefix("Vee", "x") == nil)
check("a name with its own rich text stays after the tag",
	Tags.Prefix(VIP, '<font color="#FF0000">Vee</font>') == '<font color="#FFD24A">[VIP]</font> <font color="#FF0000">Vee</font>')
check("a missing prefix is still tagged", Tags.Prefix(VIP, nil) == '<font color="#FFD24A">[VIP]</font> ')

-- Incoming (what Announce hands over)
local props = Tags.Incoming(msg(1, "Vee"))
check("a VIP's chat line: TextChatMessageProperties with the tagged prefix", props ~= nil and props.ClassName == "TextChatMessageProperties"
	and props.PrefixText == '<font color="#FFD24A">[VIP]</font> Vee', props and props.PrefixText)
local made = MADE
check("a plain player's line: unchanged (nil, nothing made)", Tags.Incoming(msg(2, "Pat")) == nil and MADE == made)
check("a system line (no TextSource): unchanged", Tags.Incoming(msg(nil, "")) == nil)
check("a player who left (unknown id): unchanged", Tags.Incoming(msg(99, "Gone")) == nil)
check("no message: nil", Tags.Incoming(nil) == nil)
LATE.Attr.PassVIP = true
local late = Tags.Incoming(msg(3, "Lee"))
check("a pass bought mid-game shows on the next line (read per message)", late ~= nil and string.find(late.PrefixText, "[VIP]", 1, true) ~= nil,
	late and late.PrefixText)
check("the module never sets OnIncomingMessage itself (Announce owns the callback)",
	not string.find(TAGS_SOURCE, "OnIncomingMessage%s*="), "")

print(("CHAT_TAGS_SUMMARY checks=%d failed=%d"):format(checks, failed))
if failed == 0 then print("CHAT_TAGS_OFFLINE_OK") end
