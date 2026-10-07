-- Offline checks for ChatText.luau (Roblox's legacy chat lines in English, A23-48): the real ChatText.luau + Config.luau
-- against small doubles shaped like the legacy chat's ChatService / Speaker / ChatChannel objects (Roblox Studio
-- ExtraContent/scripts/CoreScripts/Modules/Server/ServerChat: Speaker:SendSystemMessage(message, channelName,
-- extraData), ChatChannel:GetWelcomeMessageForSpeaker / SendSystemMessage(message, extraData), lines formatted like
-- ChatLocalization:FormatMessageToSend). Inputs: CONFIG_SOURCE, CHAT_SOURCE. No Studio / Roblox API calls.
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if not ok then
		failed += 1
		print("CHECK_FAIL " .. name .. " :: " .. tostring(detail))
	end
end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({
	ChatVersion = { LegacyChatService = "ChatVersion.Legacy", TextChatService = "ChatVersion.TextChatService" },
}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })

local function signal()
	local s = { Handlers = {} }
	function s:Connect(f) table.insert(self.Handlers, f) return { Disconnect = function() end } end
	function s:Fire(...) for _, f in self.Handlers do f(...) end end
	return s
end

-- the legacy chat's objects (plain tables with shared method tables, like Speaker.lua / ChatChannel.lua)
local sent, posted = {}, {}
local speakerMethods = {}
speakerMethods.__index = speakerMethods
function speakerMethods:SendSystemMessage(message, channelName, extraData)
	table.insert(sent, { Speaker = self.Name, Message = message, Channel = channelName, Extra = extraData })
end
function speakerMethods:GetPlayer() return self.PlayerObj end
local function newSpeaker(name, player) return setmetatable({ Name = name, PlayerObj = player }, speakerMethods) end

local channelMethods = {}
channelMethods.__index = channelMethods
function channelMethods:GetWelcomeMessageForSpeaker(_speaker) return self.WelcomeMessage end
function channelMethods:SendSystemMessage(message, extraData)
	table.insert(posted, { Channel = self.Name, Message = message, Extra = extraData })
end
local function newChannel(name, welcome) return setmetatable({ Name = name, WelcomeMessage = welcome or "" }, channelMethods) end

local function keyed(key, default, paramName, value)
	if paramName and value then
		return "{RBX_LOCALIZATION_KEY}" .. key .. "{RBX_LOCALIZATION_DEFAULT}" .. default
			.. "{RBX_LOCALIZATION_PARAMS}" .. paramName .. "=" .. value
	end
	return "{RBX_LOCALIZATION_KEY}" .. key .. "{RBX_LOCALIZATION_DEFAULT}" .. default
end

local function newChat()
	local chat = { Channels = {}, Speakers = {}, ChannelAdded = signal(), SpeakerAdded = signal() }
	function chat:GetChannelList() local t = {} for n in self.Channels do table.insert(t, n) end table.sort(t) return t end
	function chat:GetChannel(n) return self.Channels[n] end
	function chat:GetSpeakerList() local t = {} for n in self.Speakers do table.insert(t, n) end table.sort(t) return t end
	function chat:GetSpeaker(n) return self.Speakers[n] end
	return chat
end

local red = { R = 1, G = 0, B = 0 }
local horns = { Name = "Horn Legion", TeamColor = { Color = red }, AutoAssignable = false }
local choosing = { Name = "Choosing a side", TeamColor = { Color = { R = 0.5, G = 0.5, B = 0.5 } }, AutoAssignable = true }

-- services
local warned = {}
local chatVersion = enum.ChatVersion.LegacyChatService
local chatModule, configModule = { __module = "ChatService" }, { __module = "Config" }
local W = { RunnerWaits = 0, Chat = nil }
local runner = { WaitForChild = function(_, n) return n == "ChatService" and chatModule or nil end }
local services = {
	ReplicatedStorage = { WaitForChild = function() return { WaitForChild = function() return configModule end } end },
	ServerScriptService = { WaitForChild = function(_, n)
		if n == "ChatServiceRunner" then W.RunnerWaits += 1 return runner end
		return nil
	end },
	TextChatService = setmetatable({}, { __index = function(_, k) if k == "ChatVersion" then return chatVersion end return nil end }),
}
local Config
local env = setmetatable({
	game = { GetService = function(_, n) return assert(services[n], n) end },
	Vector3 = ctor("Vector3"), Vector2 = { new = function(x, y) return { X = x, Y = y } end },
	UDim2 = ctor("UDim2"), UDim = ctor("UDim"),
	Color3 = { new = function(r, g, b) return { R = r, G = g, B = b } end, fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end,
		fromHSV = function() return {} end },
	BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), NumberRange = ctor("NumberRange"),
	NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"),
	ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"), CFrame = ctor("CFrame"), Font = ctor("Font"),
	TweenInfo = { new = function() return {} end }, Enum = enum,
	task = { spawn = function(f, ...) f(...) end, delay = function() end, wait = function() end },
	warn = function(...) table.insert(warned, table.concat({ ... }, " ")) end, print = function() end,
	require = function(m)
		if m == configModule then return Config end
		if m == chatModule then return W.Chat end
		error("unexpected require " .. tostring(m and m.__module))
	end,
}, { __index = getfenv() })
local cfn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cfn, env)
Config = cfn()
local chfn = assert(loadstring(CHAT_SOURCE, "=ChatText"))
setfenv(chfn, env)
local CT = chfn()

-- 1. reading a keyed line
local text, key = CT.English(keyed("GameChat_TeamChat_NowInTeam", "You are now on the 'Horn Legion' team.", "RBX_NAME", "Horn Legion"))
check(text == "You are now on the 'Horn Legion' team." and key == "GameChat_TeamChat_NowInTeam", "a keyed line with a parameter keeps its English text", tostring(text) .. " / " .. tostring(key))
text, key = CT.English(keyed("GameChat_ChatCommandsTeller_AllChannelWelcomeMessage", "Chat '/?' or '/help' for a list of chat commands."))
check(text == "Chat '/?' or '/help' for a list of chat commands." and key == "GameChat_ChatCommandsTeller_AllChannelWelcomeMessage", "a keyed line without a parameter keeps its English text", text)
text, key = CT.English("Hello there")
check(text == "Hello there" and key == nil, "a plain line comes back unchanged", tostring(key))
check(CT.English(nil) == nil, "nil passes through", "")
check(type(Config.ChatText) == "table" and string.format(Config.ChatText.Joined, "Horn Legion") == "You joined the Horn Legion!", "Config.ChatText.Joined is the English team line", Config.ChatText and Config.ChatText.Joined)

-- 2. a speaker's system lines
local player = { Name = "Kid", Team = horns }
local sp = newSpeaker("Kid", player)
CT.Speaker(sp)
local wrapped = sp.SendSystemMessage
CT.Speaker(sp)
check(sp.SendSystemMessage == wrapped, "a speaker is wrapped only once", "")
sp:SendSystemMessage(keyed("GameChat_TeamChat_NowInTeam", "You are now on the 'Horn Legion' team.", "RBX_NAME", "Horn Legion"), "Team")
local last = sent[#sent]
check(#sent == 1 and last.Message == "You joined the Horn Legion!", "the team line is our English line", last and last.Message)
check(last and last.Channel == "All", "the team line goes to the general channel (no translated {Team} tag)", last and last.Channel)
check(last and type(last.Extra) == "table" and last.Extra.ChatColor == red, "the team line is in the team colour", last and last.Extra)

player.Team = choosing
local before = #sent
sp:SendSystemMessage(keyed("GameChat_TeamChat_NowInTeam", "You are now on the 'Choosing a side' team.", "RBX_NAME", "Choosing a side"), "Team")
check(#sent == before, "no team line for the auto-assigned 'Choosing a side' team", #sent - before)
player.Team = nil
sp:SendSystemMessage(keyed("GameChat_TeamChat_NowInTeam", "You are now on the '' team.", "RBX_NAME", ""), "Team")
check(#sent == before, "no team line without a team", #sent - before)
player.Team = horns

sp:SendSystemMessage(keyed("GameChat_TeamChat_CannotTeamChatIfNotInTeam", "You cannot team chat if you are not on a team!"), "Team", { ChatColor = "err" })
last = sent[#sent]
check(last.Message == "You cannot team chat if you are not on a team!" and last.Channel == "All", "other Team-channel lines: English, general channel", last.Message .. " @ " .. tostring(last.Channel))
check(last.Extra and last.Extra.ChatColor == "err", "other lines keep their own colour data", last.Extra)
sp:SendSystemMessage(keyed("GameChat_FriendChatNotifier_JoinMessage", "Your friend Pal has joined the game.", "RBX_NAME", "Pal"), "System")
last = sent[#sent]
check(last.Message == "Your friend Pal has joined the game." and last.Channel == "All", "System-channel lines: English, general channel", last.Message .. " @ " .. tostring(last.Channel))
sp:SendSystemMessage(keyed("GameChat_ChatFloodDetector_MessageDisplaySeconds", "You must wait 3 seconds before sending another message!", "RBX_NUMBER", "3"), "All")
last = sent[#sent]
check(last.Message == "You must wait 3 seconds before sending another message!" and last.Channel == "All", "general-channel lines: English, same channel", last.Message)
sp:SendSystemMessage(keyed("GameChat_PrivateMessaging_CannotChat", "You are not able to chat with Pal"), "To Pal")
last = sent[#sent]
check(last.Channel == "To Pal" and last.Message == "You are not able to chat with Pal", "a whisper channel line stays in its channel, in English", tostring(last.Channel))
sp:SendSystemMessage("A plain game line", "System")
last = sent[#sent]
check(last.Message == "A plain game line" and last.Channel == "System", "a plain (unkeyed) line passes through untouched", tostring(last.Channel))

-- 3. channels
local all = newChannel("All", keyed("GameChat_ChatCommandsTeller_AllChannelWelcomeMessage", "Chat '/?' or '/help' for a list of chat commands."))
local team = newChannel("Team", keyed("GameChat_TeamChat_WelcomeMessage", "This is a private channel between you and your team members."))
local system = newChannel("System", keyed("GameChat_ChatServiceRunner_SystemChannelWelcomeMessage", "This channel is for system and game notifications."))
for _, ch in { all, team, system } do CT.Channel(ch) end
check(all:GetWelcomeMessageForSpeaker(sp) == "Chat '/?' or '/help' for a list of chat commands.", "the general welcome line is English", all:GetWelcomeMessageForSpeaker(sp))
check(team:GetWelcomeMessageForSpeaker(sp) == "", "no Team channel welcome line", team:GetWelcomeMessageForSpeaker(sp))
check(system:GetWelcomeMessageForSpeaker(sp) == "", "no System channel welcome line", system:GetWelcomeMessageForSpeaker(sp))
all.WelcomeMessage = keyed("GameChat_PrivateMessaging_NowChattingWith", "You are now privately chatting with Pal.", "RBX_NAME", "Pal")
check(all:GetWelcomeMessageForSpeaker(sp) == "You are now privately chatting with Pal.", "a welcome line set later is English too", all:GetWelcomeMessageForSpeaker(sp))
system:SendSystemMessage(keyed("GameChat_ChatService_ChatFilterIssues", "The chat filter is currently experiencing issues and messages may be slow to appear."), { ChatColor = "err" })
check(posted[#posted].Message == "The chat filter is currently experiencing issues and messages may be slow to appear.", "channel-wide lines are English", posted[#posted].Message)
local channelWelcome = team.GetWelcomeMessageForSpeaker
CT.Channel(team)
check(team.GetWelcomeMessageForSpeaker == channelWelcome, "a channel is wrapped only once", "")

-- 4. Start + Hook: existing and later channels / speakers
local chat = newChat()
chat.Channels.All = newChannel("All", keyed("GameChat_ChatCommandsTeller_AllChannelWelcomeMessage", "Chat '/?' or '/help' for a list of chat commands."))
chat.Channels.Team = newChannel("Team", keyed("GameChat_TeamChat_WelcomeMessage", "This is a private channel between you and your team members."))
chat.Speakers.Early = newSpeaker("Early", { Name = "Early", Team = horns })
W.Chat = chat
chatVersion = enum.ChatVersion.TextChatService
CT.Start()
check(W.RunnerWaits == 0, "TextChatService: the legacy hook stays off", W.RunnerWaits)
chatVersion = enum.ChatVersion.LegacyChatService
CT.Start()
check(W.RunnerWaits == 1, "legacy chat: waits for ChatServiceRunner", W.RunnerWaits)
check(chat.Channels.Team:GetWelcomeMessageForSpeaker(nil) == "", "legacy chat: an existing Team channel is hooked", chat.Channels.Team:GetWelcomeMessageForSpeaker(nil))
before = #sent
chat.Speakers.Early:SendSystemMessage(keyed("GameChat_TeamChat_NowInTeam", "You are now on the 'Horn Legion' team.", "RBX_NAME", "Horn Legion"), "Team")
check(#sent == before + 1 and sent[#sent].Message == "You joined the Horn Legion!", "legacy chat: an existing speaker is hooked", sent[#sent] and sent[#sent].Message)
chat.Speakers.Late = newSpeaker("Late", { Name = "Late", Team = horns })
chat.SpeakerAdded:Fire("Late")
chat.Speakers.Late:SendSystemMessage(keyed("GameChat_TeamChat_NowInTeam", "You are now on the 'Horn Legion' team.", "RBX_NAME", "Horn Legion"), "Team")
check(sent[#sent].Message == "You joined the Horn Legion!" and sent[#sent].Channel == "All", "legacy chat: a speaker added later is hooked", sent[#sent].Message)
chat.Channels.System = newChannel("System", keyed("GameChat_ChatServiceRunner_SystemChannelWelcomeMessage", "This channel is for system and game notifications."))
chat.ChannelAdded:Fire("System")
check(chat.Channels.System:GetWelcomeMessageForSpeaker(nil) == "", "legacy chat: a channel added later is hooked", chat.Channels.System:GetWelcomeMessageForSpeaker(nil))
W.Chat = nil
CT.Start()
check(#warned >= 1 and string.find(warned[#warned], "ChatText", 1, true) ~= nil, "a missing ChatService only warns", warned[#warned])

print(string.format("CHAT_TEXT_SUMMARY checks=%d failed=%d", checks, failed))
