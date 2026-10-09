-- Offline checks for the client half of "Roblox's chat lines in English" (A23-48, A23-74): the real Announce.luau +
-- Config.luau against small doubles. Roblox's new chat (TextChatService) shows the team line "You are now on the 'X'
-- team." (Metadata Roblox.Team.Success.NowInTeam) in the player's Roblox language; Announce.Incoming turns it into
-- Config.ChatText. A23-74 (user 2026-10-07): the main place reads ChatVersion = LegacyChatService while
-- Chat.IsAutoMigrated = true (the new chat runs anyway), so the hook must not depend on ChatVersion, and it must be set
-- in Init (before any module's Start) so the first team line after joining is covered.
-- Inputs: CONFIG_SOURCE, ANNOUNCE_SOURCE. No Studio / Roblox API calls.
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

-- teams (Player.Team doubles): FactionService's faction teams and the auto-assigned "Choosing a side" team
local knights = { Name = "Knights of Light", TeamColor = { Color = { R = 1, G = 1, B = 0 } }, AutoAssignable = false }
local choosing = { Name = "Choosing a side", TeamColor = { Color = { R = 0.5, G = 0.5, B = 0.5 } }, AutoAssignable = true }
local odd = { Name = "<Bad & Co>", TeamColor = { Color = { R = 1, G = 0, B = 0 } }, AutoAssignable = false }
local TEAM_META = "Roblox.Team.Success.NowInTeam"
local KOREAN = "현재 'Knights of Light'팀에 속해 있어요." -- what the user saw (A23-74)

local W = { Version = enum.ChatVersion.LegacyChatService, Hook = nil, Sets = 0, SetThrows = false, Warned = {},
	Handler = nil }
local localPlayer = { Name = "Kid", Team = nil }
local textChat = setmetatable({}, {
	__index = function(_, k)
		if k == "ChatVersion" then return W.Version end
		if k == "OnIncomingMessage" then error("OnIncomingMessage is a callback member of TextChatService; you can only set the callback value, get is not available") end
		return nil
	end,
	__newindex = function(_, k, v)
		if k ~= "OnIncomingMessage" then error("unexpected TextChatService." .. tostring(k)) end
		if W.SetThrows then error("TextChatService is not available") end
		W.Sets += 1
		W.Hook = v
	end,
})
local configModule, netModule = { __module = "Config" }, { __module = "Net" }
local shared = { WaitForChild = function(_, n)
	if n == "Config" then return configModule end
	if n == "Net" then return netModule end
	error("unexpected Shared child " .. tostring(n))
end }
local net = { Get = function(name)
	assert(name == "Announce", name)
	return { OnClientEvent = { Connect = function(_, fn) W.Handler = fn return {} end } }
end }
local services = {
	Players = { LocalPlayer = localPlayer },
	ReplicatedStorage = { WaitForChild = function(_, n) assert(n == "Shared", n) return shared end },
	TextChatService = textChat,
	StarterGui = { SetCore = function() error("legacy SetCore not expected here") end },
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
	Instance = { new = function(class) return { ClassName = class } end },
	task = { spawn = function(f, ...) f(...) end, delay = function() end, wait = function() end, defer = function(f, ...) f(...) end },
	warn = function(...) table.insert(W.Warned, table.concat({ ... }, " ")) end, print = function() end,
	require = function(m)
		if m == configModule then return Config end
		if m == netModule then return net end
		error("unexpected require " .. tostring(m and m.__module))
	end,
}, { __index = getfenv() })
local cfn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cfn, env)
Config = cfn()

-- a fresh Announce module (the real file) for one client
local function loadAnnounce()
	W.Hook, W.Sets, W.Handler = nil, 0, nil
	local fn = assert(loadstring(ANNOUNCE_SOURCE, "=Announce"))
	setfenv(fn, env)
	return fn()
end

local function hex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
local function line(text, color) return string.format('<font color="%s"><b>%s</b></font>', hex(color), text) end
local function ascii(s) return type(s) == "string" and string.find(s, "[\128-\255]") == nil end
local function show(v)
	if type(v) ~= "table" then return tostring(v) end
	return "{ClassName=" .. tostring(v.ClassName) .. ", Text=" .. tostring(v.Text) .. "}"
end

-- 1. the hook: set in Init whatever ChatVersion says (the main place: LegacyChatService + IsAutoMigrated)
for _, case in { { "LegacyChatService (auto-migrated place)", enum.ChatVersion.LegacyChatService },
	{ "TextChatService", enum.ChatVersion.TextChatService } } do
	W.Version = case[2]
	local mod = loadAnnounce()
	check(W.Hook == nil, case[1] .. ": nothing is hooked before Init", W.Sets)
	local okInit, errInit = pcall(mod.Init, {})
	check(okInit, case[1] .. ": Init runs", errInit)
	check(type(W.Hook) == "function", case[1] .. ": Init sets TextChatService.OnIncomingMessage (before any Start)", W.Sets)
	check(W.Hook == mod.Incoming, case[1] .. ": the hook is Announce.Incoming", tostring(W.Hook))
	local hook = W.Hook
	local okStart, errStart = pcall(mod.Start)
	check(okStart, case[1] .. ": Start runs", errStart)
	check(W.Hook == hook, case[1] .. ": Start keeps the same hook", tostring(W.Hook))
	check(type(W.Handler) == "function", case[1] .. ": Start still listens to the Announce remote", tostring(W.Handler))
end
W.Version = enum.ChatVersion.LegacyChatService

-- 2. the team line itself (through the hook the engine would call); the chat line as it was before TeamToast
Config.ChatText.TeamToast = false
local mod = loadAnnounce()
mod.Init({})
local hook = W.Hook
local function incoming(meta, text)
	local ok, res = pcall(hook, { Metadata = meta, Text = text })
	if not ok then return "ERROR " .. tostring(res) end
	return res
end
if type(hook) == "function" then
	localPlayer.Team = knights
	local props = incoming(TEAM_META, KOREAN)
	check(type(props) == "table" and props.ClassName == "TextChatMessageProperties", "the team line gets TextChatMessageProperties", show(props))
	local want = line("You joined the Knights of Light!", knights.TeamColor.Color)
	check(type(props) == "table" and props.Text == want, "the Korean team line becomes our English line in the team colour", show(props) .. " want " .. want)
	check(type(props) == "table" and ascii(props.Text), "the team line has no Hangul (A23-48)", show(props))

	localPlayer.Team = choosing
	props = incoming(TEAM_META, "현재 'Choosing a side'팀에 속해 있어요.")
	want = line(Config.ChatText.Choosing, choosing.TeamColor.Color)
	check(type(props) == "table" and props.Text == want, "the auto-assigned 'Choosing a side' team gets the pick hint", show(props) .. " want " .. want)

	localPlayer.Team = nil
	props = incoming(TEAM_META, "")
	want = line(Config.ChatText.Choosing, { R = 1, G = 1, B = 1 })
	check(type(props) == "table" and props.Text == want, "no team: the pick hint in white", show(props) .. " want " .. want)

	localPlayer.Team = odd
	props = incoming(TEAM_META, "x")
	check(type(props) == "table" and type(props.Text) == "string"
		and string.find(props.Text, "You joined the &lt;Bad &amp; Co&gt;!", 1, true) ~= nil, "a team name is rich-text escaped", show(props))

	localPlayer.Team = knights
	check(incoming("", "hello everyone") == nil, "a player's chat line is untouched (nil)", show(incoming("", "hello everyone")))
	check(incoming("Roblox.Team.Error.CannotTeamChatIfNotInTeam", "x") == nil, "another system line is untouched (nil)",
		show(incoming("Roblox.Team.Error.CannotTeamChatIfNotInTeam", "x")))
	check(incoming("Roblox.ChatTranslation.ChatWindow.SystemMessage", "x") == nil, "the translation notice is untouched (nil)",
		show(incoming("Roblox.ChatTranslation.ChatWindow.SystemMessage", "x")))
else
	check(false, "the team line can be tested (Init set no hook)", tostring(hook))
end

-- 2b. 검수 10/09 (UI clutter review ②): TeamToast - no team line in the chat, one toast on the first side pick
Config.ChatText.TeamToast = true
local realJoinToast = Config.ChatText.JoinToast
Config.ChatText.JoinToast = true -- the toast rule itself (the real Config has it off)
do
	local m2 = loadAnnounce()
	m2.Init({})
	localPlayer.Team = knights
	local okH, props = pcall(W.Hook, { Metadata = TEAM_META, Text = KOREAN })
	check(okH and type(props) == "table" and props.Text == "", "TeamToast: the chat's team line is emptied (not drawn)", show(props))
	local okO, other = pcall(W.Hook, { Metadata = "", Text = "hi" })
	check(okO and other == nil, "TeamToast: other chat lines untouched", show(other))
	local J = m2.JoinToast
	check(J(choosing, knights) == "You joined the Knights of Light!", "the first pick (Choosing -> a side): the toast", tostring(J(choosing, knights)))
	check(J(nil, knights) == nil, "the login (no team -> my side): no toast")
	check(J(knights, choosing) == nil and J(nil, choosing) == nil and J(choosing, choosing) == nil, "to the auto-assigned team: no toast")
	check(J(knights, odd) == nil, "a switch between sides: no toast here (FactionService has its own notice)")
	check(J(choosing, nil) == nil, "no team: no toast")
	Config.ChatText.TeamToast = false
	check(J(choosing, knights) == nil, "TeamToast off: no toast")
	Config.ChatText.TeamToast = true
end
check(Config.ChatText.TeamToast == true and type(Config.ChatText.Joined) == "string", "Config: TeamToast on by default (the real Config)")
-- 검수 10/09 (user: "too kind"): the real Config shows no join toast at all, for either side
Config.ChatText.JoinToast = realJoinToast
do
	local m3 = loadAnnounce()
	m3.Init({})
	check(realJoinToast == false and m3.JoinToast(choosing, knights) == nil and m3.JoinToast(choosing, odd) == nil,
		"the real Config: no 'You joined ...!' toast for any side", tostring(realJoinToast))
	localPlayer.Team = knights
	local okH, props = pcall(W.Hook, { Metadata = TEAM_META, Text = KOREAN })
	check(okH and type(props) == "table" and props.Text == "", "the real Config: the chat team line stays empty", show(props))
end

-- 3. a TextChatService that refuses the callback: Init only warns
W.SetThrows = true
mod = loadAnnounce()
local before = #W.Warned
local okInit, errInit = pcall(mod.Init, {})
check(okInit, "a refused hookup does not break Init", errInit)
check(#W.Warned > before and string.find(W.Warned[#W.Warned], "[Announce]", 1, true) ~= nil, "a refused hookup warns once", W.Warned[#W.Warned])
local okStart = pcall(mod.Start)
check(okStart, "Start still runs after a refused hookup", "")
W.SetThrows = false

print(string.format("TEAM_LINE_SUMMARY checks=%d failed=%d", checks, failed))
