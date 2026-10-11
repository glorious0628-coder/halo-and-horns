-- ChatText.luau : Roblox's own chat lines in English (A23-48: the game shows English only).
-- The place runs the legacy chat (TextChatService.ChatVersion = LegacyChatService). Its server modules send lines such
-- as "You are now on the 'Horn Legion' team." as "{RBX_LOCALIZATION_KEY}key{RBX_LOCALIZATION_DEFAULT}English", and every
-- client turns them into its own Roblox language (a Korean Studio showed the team line in Korean, 검수 2026-10-07).
-- Here, on the server:
--   * the team-change line becomes Config.ChatText.Joined ("You joined the Horn Legion!") in the team colour, sent in
--     the general channel: a Team / System channel line gets a "{Team}" / "{System}" tag the client translates too;
--     the auto-assigned "Choosing a side" team gets no line;
--   * every other keyed line keeps only its English text, and its Team / System lines move to the general channel;
--   * the Team and System channel welcome lines are dropped; the others keep only their English text.
-- (TextChatService, if the place ever switches: Announce.luau rewrites the same team line on the client.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ChatText = {}

local TAG = { Key = "{RBX_LOCALIZATION_KEY}", Default = "{RBX_LOCALIZATION_DEFAULT}", Params = "{RBX_LOCALIZATION_PARAMS}" }
local TEAM_LINE = "GameChat_TeamChat_NowInTeam"
local GENERAL = "All" -- the legacy chat's ChatSettings.GeneralChannelName
local TAGGED = { team = true, system = true } -- channels whose lines show a translated "{Team}" / "{System}" tag

-- "{KEY}k{DEFAULT}English{PARAMS}a=b" -> "English", "k"; any other text comes back as it is (key nil)
function ChatText.English(message)
	if type(message) ~= "string" then return message, nil end
	local _, keyEnd = string.find(message, TAG.Key, 1, true)
	local defStart, defEnd = string.find(message, TAG.Default, 1, true)
	if not keyEnd or not defStart or defStart <= keyEnd then return message, nil end
	local key = string.sub(message, keyEnd + 1, defStart - 1)
	local paramStart = string.find(message, TAG.Params, defEnd + 1, true)
	if paramStart then return string.sub(message, defEnd + 1, paramStart - 1), key end
	return string.sub(message, defEnd + 1), key
end

-- our team line and its colour for this player; nil while on the auto-assigned "Choosing a side" team.
-- Korean mode (contract docs/design/l10n_contract_2026-10-11.md §5-4): a legacy chat line to ONE player is written in
-- that player's language, L10n.T("Config.ChatText.Joined", { team name }, L10n.LangOf(player)) (the team name stays
-- English, §5-4); without the L10n module the English line as before
function ChatText.TeamLine(player)
	local team = player and player.Team
	if not team or team.AutoAssignable then return nil end
	local ok, line = pcall(function()
		local L10n = require(ReplicatedStorage:WaitForChild("Shared"):FindFirstChild("L10n"))
		return L10n.T("Config.ChatText.Joined", { team.Name }, L10n.LangOf(player))
	end)
	if not ok or type(line) ~= "string" or line == "Config.ChatText.Joined" then
		line = string.format(Config.ChatText.Joined, team.Name)
	end
	return line, team.TeamColor.Color
end

-- a legacy Speaker is a plain table: a field on it wins over its shared methods
function ChatText.Speaker(speaker)
	if type(speaker) ~= "table" or speaker.HHC_English or type(speaker.SendSystemMessage) ~= "function" then return end
	local send = speaker.SendSystemMessage
	speaker.HHC_English = true
	speaker.SendSystemMessage = function(self, message, channelName, extraData)
		local text, key = ChatText.English(message)
		if key == nil then return send(self, message, channelName, extraData) end
		if key == TEAM_LINE then
			local line, color = ChatText.TeamLine(self:GetPlayer())
			if not line then return end
			return send(self, line, GENERAL, { ChatColor = color })
		end
		if type(channelName) == "string" and TAGGED[string.lower(channelName)] then channelName = GENERAL end
		return send(self, text, channelName, extraData)
	end
end

function ChatText.Channel(channel)
	if type(channel) ~= "table" or channel.HHC_English then return end
	channel.HHC_English = true
	if type(channel.GetWelcomeMessageForSpeaker) == "function" then
		local welcome = channel.GetWelcomeMessageForSpeaker
		channel.GetWelcomeMessageForSpeaker = function(self, speaker)
			if TAGGED[string.lower(tostring(self.Name))] then return "" end
			return (ChatText.English(welcome(self, speaker)))
		end
	end
	if type(channel.SendSystemMessage) == "function" then -- channel-wide lines (the System channel's filter notice)
		local send = channel.SendSystemMessage
		channel.SendSystemMessage = function(self, message, extraData)
			return send(self, (ChatText.English(message)), extraData)
		end
	end
end

function ChatText.Hook(chat)
	for _, name in chat:GetChannelList() do ChatText.Channel(chat:GetChannel(name)) end
	chat.ChannelAdded:Connect(function(name) ChatText.Channel(chat:GetChannel(name)) end)
	for _, name in chat:GetSpeakerList() do ChatText.Speaker(chat:GetSpeaker(name)) end
	chat.SpeakerAdded:Connect(function(name) ChatText.Speaker(chat:GetSpeaker(name)) end)
end

function ChatText.Init(_S) end

function ChatText.Start()
	local legacy = false
	pcall(function() legacy = TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService end)
	if not legacy then return end
	task.spawn(function()
		local runner = ServerScriptService:WaitForChild("ChatServiceRunner", 60)
		local module = runner and runner:WaitForChild("ChatService", 10)
		local ok, chat = false, nil
		if module then ok, chat = pcall(require, module) end
		if not ok or type(chat) ~= "table" then
			warn("[ChatText] legacy ChatService not found; Roblox chat lines stay in each player's language")
			return
		end
		local hooked, err = pcall(ChatText.Hook, chat)
		if not hooked then warn("[ChatText] " .. tostring(err)) end
	end)
end

return ChatText
