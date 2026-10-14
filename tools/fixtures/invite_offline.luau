-- Offline checks for Invite.luau (SPEC A23-79 #3: [Invite a friend] + "Your friend joined! [Go to friend]"). The runner
-- (tools/test_invite.py) prepends INVITE_SOURCE. Roblox is replaced by small doubles: SocialService (CanSendGameInviteAsync,
-- PromptGameInvite recorded), Players (PlayerAdded fired by hand, LocalPlayer:IsFriendsWith), a Humanoid, the Panels
-- current window, UIKit.Toast, the Remotes folder, Util.Signal / Warn / PlayerDisplayName, os.clock moved by hand.
local checks, failed = 0, 0
local function check(name, ok, detail)
	checks += 1
	if not ok then
		failed += 1
		print(("CHECK_FAIL %s :: %s"):format(name, tostring(detail or "")))
	end
end

local function signal()
	local s = { Fns = {} }
	function s:Connect(fn) table.insert(self.Fns, fn); return { Disconnect = function() end } end
	function s:Fire(...) for _, fn in self.Fns do fn(...) end end
	return s
end

local CLOCK = { T = 100 }
local HUM = { Health = 100, IsA = function(_, c) return c == "Humanoid" end }
local CHAR = { FindFirstChildOfClass = function(_, c) if c == "Humanoid" then return HUM end return nil end }
local FRIENDS = { [22] = true, [33] = true }
local function player(id, name)
	local p = { __kind = "Instance", ClassName = "Player", UserId = id, Name = name, DisplayName = name, Parent = nil }
	function p:IsA(c) return c == "Player" or c == "Instance" end
	return p
end
local ME = player(11, "Me")
ME.Character = CHAR
function ME:IsFriendsWith(id) return FRIENDS[id] == true end
local PLAYERS = { LocalPlayer = ME, PlayerAdded = signal() }
ME.Parent = PLAYERS
local SOCIAL = { Can = true, Prompts = {}, GameInvitePromptClosed = signal() }
function SOCIAL:CanSendGameInviteAsync(p) return self.Can end
function SOCIAL:PromptGameInvite(p, options)
	if self.Fail then error("prompt failed") end
	table.insert(self.Prompts, { Player = p, Options = options })
end
local FIRED = {}
local REMOTE = { __kind = "Instance", ClassName = "RemoteEvent" }
function REMOTE:IsA(c) return c == "RemoteEvent" or c == "Instance" end
function REMOTE:FireServer(...) table.insert(FIRED, table.pack(...)) end
local REMOTES = { Items = {} }
function REMOTES:FindFirstChild(n) return self.Items[n] end
local FX = { OnClientEvent = signal() }
local RS = { FindFirstChild = function(_, n) if n == "Remotes" then return REMOTES end return nil end,
	WaitForChild = function() return { WaitForChild = function(_, n) return { __module = n } end } end }
local TOASTS = {}
local WINDOW = { Id = nil }
local Util = { Signal = { new = signal }, Warn = function() end,
	PlayerDisplayName = function(p) return p.DisplayName end }
local Net = { Get = function(n) if n == "Fx" then return FX end error("no remote " .. tostring(n)) end }

local env = setmetatable({
	game = { GetService = function(_, n)
		if n == "Players" then return PLAYERS end
		if n == "ReplicatedStorage" then return RS end
		if n == "SocialService" then return SOCIAL end
		return {}
	end },
	typeof = function(v) return type(v) == "table" and rawget(v, "__kind") or type(v) end,
	Instance = { new = function(class) return { ClassName = class } end },
	os = { clock = function() return CLOCK.T end },
	task = { spawn = function(fn, ...) fn(...) end },
	require = function(m)
		if m.__module == "Net" then return Net end
		if m.__module == "Config" then -- 10/14: the words sit in Config.ClientText.Invite
			return { ClientText = { Invite = { Joined = "Your friend %s joined!", Message = "Come play Halo & Horns with me!" } } }
		end
		return Util
	end,
}, { __index = getfenv() })
local fn = assert(loadstring(INVITE_SOURCE, "=Invite"))
setfenv(fn, env)
local Invite = fn()
local METRICS = {}
local C = { UIKit = { Toast = function(text, kind, secs) table.insert(TOASTS, { text, kind, secs }) end },
	Panels = { CurrentId = function() return WINDOW.Id end },
	ComeBack = { Metric = function(id, arg) table.insert(METRICS, { id, arg }) return true end } }
local function lastMetric() local m = METRICS[#METRICS] return m and (tostring(m[1]) .. ":" .. tostring(m[2])) or "none" end
Invite.Init(C)
Invite.Start()

-- CanShow / Prompt
check("a calm moment: the invite button may show", Invite.CanShow() == true)
check("Prompt opens Roblox's invite window", Invite.Prompt("Menu") == true and #SOCIAL.Prompts == 1, #SOCIAL.Prompts)
check("an opened invite window counts (InvitePrompt + its source)", #METRICS == 1 and lastMetric() == "InvitePrompt:Menu", lastMetric())
local opts = SOCIAL.Prompts[1] and SOCIAL.Prompts[1].Options
check("the LaunchData is my UserId (the server finds the inviter)", opts and opts.LaunchData == "11" and opts.ClassName == "ExperienceInviteOptions",
	opts and opts.LaunchData)
check("the invite message is short English", opts and type(opts.PromptMessage) == "string" and not opts.PromptMessage:find("[\234-\237]"),
	opts and opts.PromptMessage)
SOCIAL.Can = false
check("Roblox says no invites (CanSendGameInviteAsync false): nothing opens", Invite.Prompt("Menu") == false and #SOCIAL.Prompts == 1)
check("... and nothing is counted", #METRICS == 1, lastMetric())
SOCIAL.Can = true
HUM.Health = 0
check("knocked out: no invite button (A23-79)", Invite.CanShow() == false and Invite.Prompt("Tab") == false and #SOCIAL.Prompts == 1)
HUM.Health = 100
Invite.OnFx("Enhance", { Success = false })
check("right after a failed scroll: no invite button", Invite.CanShow() == false)
CLOCK.T += 3
check("... still 3 s later", Invite.CanShow() == false)
CLOCK.T += 4
check("... back 7 s later", Invite.CanShow() == true)
Invite.OnFx("Enhance", { Success = true })
check("a scroll that worked does not hide it", Invite.CanShow() == true)
FX.OnClientEvent:Fire("Enhance", { Success = false })
check("the real Fx remote moves the clock too", Invite.CanShow() == false)
CLOCK.T += 10
WINDOW.Id = "Shop"
check("the Shop window (passes) is open: no invite button", Invite.CanShow() == false)
WINDOW.Id = "Items"
check("another window is fine", Invite.CanShow() == true)
WINDOW.Id = nil

-- a friend joins
local friend = player(22, "Bo")
friend.Parent = PLAYERS
local joined = {}
Invite.FriendJoined:Connect(function(p) table.insert(joined, p) end)
PLAYERS.PlayerAdded:Fire(friend)
check("a friend joins: FriendJoined fires, no line (A23-191)", #joined == 1 and joined[1] == friend and #TOASTS == 0,
	TOASTS[1] and TOASTS[1][1])
PLAYERS.PlayerAdded:Fire(friend)
check("the same friend again (rejoin): FriendJoined not again this session", #joined == 1 and #TOASTS == 0)
local stranger = player(44, "Zed")
stranger.Parent = PLAYERS
PLAYERS.PlayerAdded:Fire(stranger)
check("a stranger joins: nothing", #joined == 1 and #TOASTS == 0)
PLAYERS.PlayerAdded:Fire(ME)
check("my own join: nothing", #joined == 1)
-- a friend card of its own (이미지 개발) switches the plain line off: the signal still fires, no second line
Invite.DefaultLine = false
local friend2 = player(33, "Cy")
friend2.Parent = PLAYERS
PLAYERS.PlayerAdded:Fire(friend2)
check("DefaultLine false: FriendJoined fires, no line", #joined == 2 and joined[2] == friend2 and #TOASTS == 0,
	#TOASTS)
Invite.DefaultLine = true

-- Go to friend
check("no GoToFriend remote yet: GoTo does nothing", Invite.GoTo(friend) == false and #FIRED == 0)
REMOTES.Items.GoToFriend = REMOTE
check("with the server's remote: GoTo asks it with the friend's UserId", Invite.GoTo(friend) == true and #FIRED == 1 and FIRED[1][1] == 22,
	FIRED[1] and FIRED[1][1])
friend.Parent = nil
check("a friend who left: nothing sent", Invite.GoTo(friend) == false and #FIRED == 1)
check("not a player: nothing", Invite.GoTo({}) == false and Invite.GoTo(nil) == false)

-- beta metrics (A23-79 Social funnel): the button seen, the window closed with friends picked
METRICS = {}
check("a button shown: InviteSeen with its source", Invite.Seen("Menu") == true and lastMetric() == "InviteSeen:Menu", lastMetric())
check("the same source again this session: not counted twice", Invite.Seen("Menu") == false and #METRICS == 1)
check("another source counts once too", Invite.Seen("PlayerList") == true and lastMetric() == "InviteSeen:PlayerList" and #METRICS == 2)
check("no source: nothing", Invite.Seen(nil) == false and #METRICS == 2)
METRICS = {}
SOCIAL.GameInvitePromptClosed:Fire(ME, { 101, 102, 103 })
check("the invite window closed with 3 friends: InviteSent 3", lastMetric() == "InviteSent:3", lastMetric())
SOCIAL.GameInvitePromptClosed:Fire(ME, {})
check("closed with nobody picked: nothing", #METRICS == 1, lastMetric())
SOCIAL.GameInvitePromptClosed:Fire(friend, { 101 })
check("someone else's window: nothing", #METRICS == 1, lastMetric())
local many = {}
for i = 1, 70 do many[i] = i end
check("70 friends picked: counted as 50 (the server's 1..50)", Invite.Closed(ME, many) == 50 and lastMetric() == "InviteSent:50", lastMetric())
METRICS = {}
SOCIAL.Prompts = {}
check("a prompt without a source opens but counts nothing", Invite.Prompt(nil) == true and #SOCIAL.Prompts == 1 and #METRICS == 0, lastMetric())
SOCIAL.Fail = true
check("Roblox's window failed to open: not counted", Invite.Prompt("Menu") == false and #METRICS == 0, lastMetric())
SOCIAL.Fail = false

print(("INVITE_SUMMARY checks=%d failed=%d"):format(checks, failed))
if failed == 0 then print("INVITE_OFFLINE_OK") end
