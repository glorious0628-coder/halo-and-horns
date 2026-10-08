-- ChatTags.luau (게임성 개발 1, SPEC A23-75 the VIP pass: "채팅 VIP 표시"): in the chat, a player whose PassVIP attribute is
-- true (the server sets it from UserOwnsGamePassAsync / PromptGamePassPurchaseFinished - 게임성 개발 2,
-- docs/design/gamepass_server_2026-10-08.md) gets a gold [VIP] before the name. The client's one
-- TextChatService.OnIncomingMessage callback belongs to Announce.luau (its A23-74 team line, hooked in Init); Announce
-- hands every other message to ChatTags.Incoming, so this module never sets the callback itself. System lines (no
-- TextSource) are left alone; the attribute is read per message, so a pass bought mid-game shows on the next line.
-- Presentation only.
-- Public API: ChatTags.Init(C), ChatTags.Start(), ChatTags.Prefix(player, prefixText) -> the new prefix text or nil,
-- ChatTags.Incoming(message) -> TextChatMessageProperties or nil (both pure apart from the Instance; the offline test
-- drives them).
local Players = game:GetService("Players")

local ChatTags = {}
local C = nil

local T = {
	Attr = "PassVIP", -- the server's VIP flag (dev2)
	Tag = "VIP", -- game text: English only (A23-48)
	Color = "#FFD24A", -- the gold of the VIP crown
}

-- the prefix (the name part of a chat line) with the VIP tag in front, or nil when the player has no VIP pass
function ChatTags.Prefix(player, prefixText)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return nil end
	if player:GetAttribute(T.Attr) ~= true then return nil end
	return string.format('<font color="%s">[%s]</font> %s', T.Color, T.Tag, type(prefixText) == "string" and prefixText or "")
end

-- one incoming chat message: the properties to show it with, or nil (unchanged)
function ChatTags.Incoming(message)
	local source = message and message.TextSource
	if not source then return nil end
	local player = Players:GetPlayerByUserId(source.UserId)
	local prefix = ChatTags.Prefix(player, message.PrefixText)
	if not prefix then return nil end
	local props = Instance.new("TextChatMessageProperties")
	props.PrefixText = prefix
	return props
end

function ChatTags.Init(registry)
	C = registry
end

function ChatTags.Start() end

return ChatTags
