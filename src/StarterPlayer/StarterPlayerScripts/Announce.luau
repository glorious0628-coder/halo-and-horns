-- Announce.luau : A23-15 server-wide chat lines for good drops (AnnounceService -> remote "Announce").
-- Formats Config.Announce.Text[Key] on this client (so it can be localized later) and shows it as a TextChatService
-- system message in RBXGeneral, colored by the weapon grade. Weapon names follow the finder's class and faction.
-- Event lines (AnnounceService.Broadcast, Config.Announce.Events: e.g. the Pumpkin King) are plain Text[Key] lines
-- (Text[Key .. "En"] when the language setting is English) in the event's Color, optionally also a toast. A king's
-- appear line may carry Args.Banter (lines_pack 12, the day's king vs king line, built by the server): one more chat
-- line in the same colour, never a toast.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local Announce = {}
local C = nil
local A = { Channel = nil }

local function hex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function escape(s)
	return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- English lines (A23-48: UIKit.Lang decides, the game shows English; the Settings value is the older fallback)
function A.English()
	local kit = C and C.UIKit
	if type(kit) == "table" and type(kit.Lang) == "function" then
		local okLang, lang = pcall(kit.Lang)
		if okLang then return lang == "en" end
	end
	local st = C and C.Settings
	if type(st) ~= "table" or type(st.Get) ~= "function" then return false end
	local ok, lang = pcall(st.Get, "Lang")
	return ok and lang == "en"
end

function A.Subject(args, text)
	if args.Hidden == true or type(args.Who) ~= "string" or args.Who == "" then
		local f = Config.Factions[args.Faction]
		return string.format(text.Anon, f and f.Name or "Someone")
	end
	return string.format(text.Subject, escape(args.Who))
end

function A.Format(msg)
	local text = Config.Announce and Config.Announce.Text
	if type(text) ~= "table" or type(msg) ~= "table" or type(msg.Key) ~= "string" then return nil end
	local tmpl = text[msg.Key]
	local args = type(msg.Args) == "table" and msg.Args or {}
	if type(tmpl) ~= "string" then return nil end
	local events = Config.Announce.Events
	if type(events) == "table" and events[msg.Key] ~= nil then
		local en = A.English() and text[msg.Key .. "En"]
		return escape(type(en) == "string" and en or tmpl) -- a plain line: no finder, no name
	end
	local who = A.Subject(args, text)
	local tier = tonumber(args.Weapon)
	local weapon = tier and Config.WeaponName(math.floor(tier), args.Class, args.Faction) or ""
	if msg.Key == "RareWeapon" then
		local m = Config.MonsterTypes[args.Monster]
		local g = tier and Config.WeaponGrade(math.floor(tier))
		return string.format(tmpl, who, m and (m.Short or m.Name) or "a monster", g and g.Name or "", weapon)
	elseif msg.Key == "Jackpot" or msg.Key == "FirstMax" then
		return string.format(tmpl, who, weapon)
	elseif msg.Key == "More" then
		return Config.Plural(string.format(tmpl, who, math.floor(tonumber(args.Count) or 1))) -- "1 more great item"
	end
	return nil
end

function A.Show(msg)
	local ok, line = pcall(A.Format, msg)
	if not ok or type(line) ~= "string" then return end
	local g = Config.WeaponGrades[msg.Grade] or Config.WeaponGrades.Rare
	local ev = type(msg) == "table" and type(Config.Announce.Events) == "table" and Config.Announce.Events[msg.Key] or nil
	-- art left of the toast / banner text (UIKit.ItemIcon; nil = text only): the event's Icon, or the monster's head
	-- for a rare drop (IconMon<Monster>)
	local args = type(msg.Args) == "table" and msg.Args or {}
	local icon = (type(ev) == "table" and type(ev.Icon) == "string" and ev.Icon)
		or (msg.Key == "RareWeapon" and type(args.Monster) == "string" and "IconMon" .. args.Monster) or nil
	if type(ev) == "table" then
		-- event line: its own colour; the toast is skipped (not held) while the opening / a picker / the first
		-- mission holds banners: by then the news is old, the chat line stays
		g = { Rank = 0, Color = typeof(ev.Color) == "Color3" and ev.Color or g.Color }
		local ui = C and C.UIKit
		if ev.Toast == true and type(ui) == "table" and type(ui.Toast) == "function" then
			local hold = false
			if type(ui.ShouldHoldBanners) == "function" then
				local okH, h = pcall(ui.ShouldHoldBanners)
				hold = okH and h == true
			end
			if not hold then pcall(ui.Toast, (line:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&")), "reward", 5, icon) end
		end
	end
	-- big news is also visible without opening the chat: a banner for Legendary, a toast for Epic. Not for the
	-- finder (they already got their own toast) and never over the opening / pickers / first mission: then a
	-- Legendary banner / Epic toast waits in UIKit.HeldBanners (max 2, like Notify) until FlushBanners.
	local ui = C and C.UIKit
	if type(ui) == "table" and msg.Self ~= true and g.Rank >= 4 then
		local hold = false
		if type(ui.ShouldHoldBanners) == "function" then
			local okH, h = pcall(ui.ShouldHoldBanners)
			hold = okH and h == true
		end
		if g.Rank >= 5 then
			if hold then
				if type(ui.HeldBanners) ~= "table" then ui.HeldBanners = {} end
				table.insert(ui.HeldBanners, { line, 6, nil, icon })
				if #ui.HeldBanners > 2 then table.remove(ui.HeldBanners, 1) end
			elseif type(ui.Announce) == "function" then
				pcall(ui.Announce, line, 6, icon)
			end
		elseif hold then
			-- A23-15: deferred, not dropped: shown as a toast by UIKit.FlushBanners after the opening / first mission
			if type(ui.HeldBanners) ~= "table" then ui.HeldBanners = {} end
			table.insert(ui.HeldBanners, { line, 4, "toast", icon })
			if #ui.HeldBanners > 2 then table.remove(ui.HeldBanners, 1) end
		elseif type(ui.Toast) == "function" then
			pcall(ui.Toast, line, "reward", 4, icon)
		end
	end
	A.Chat(line, g.Color)
	-- lines_pack 12: the kings' banter of the day, right under the appear line, same colour, chat only
	if type(ev) == "table" and type(args.Banter) == "string" and args.Banter ~= "" then
		A.Chat(escape(args.Banter), g.Color)
	end
end

-- one chat line (rich-text escaped) in a colour. The place still runs the legacy chat (TextChatService.ChatVersion =
-- LegacyChatService): use its system-message core call there, and the TextChatService RBXGeneral channel once the
-- place moves to the new chat
function A.Chat(line, color)
	local legacy = false
	pcall(function() legacy = TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService end)
	if legacy then
		local plain = line:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&")
		for _ = 1, 10 do -- the legacy chat registers ChatMakeSystemMessage a moment after join
			if pcall(StarterGui.SetCore, StarterGui, "ChatMakeSystemMessage",
				{ Text = plain, Color = color, Font = Enum.Font.GothamBold, TextSize = 18 }) then return end
			task.wait(0.5)
		end
		return
	end
	local rich = string.format('<font color="%s"><b>%s</b></font>', hex(color), line)
	local channel = A.Channel
	if not channel then
		local channels = TextChatService:FindFirstChild("TextChannels")
		channel = channels and channels:FindFirstChild("RBXGeneral")
		A.Channel = channel
	end
	if channel and channel:IsA("TextChannel") then
		pcall(channel.DisplaySystemMessage, channel, rich)
	end
end

-- New chat (TextChatService; ChatText.luau covers the legacy chat on the server): Roblox's team line ("You are now on
-- the ... team.", Metadata Roblox.Team.Success.NowInTeam) comes in the player's Roblox language -> our English line.
-- Every other message goes to ChatTags.Incoming (A23-75 the VIP tag, 게임성 개발 1) - nil when nothing changes.
function A.Incoming(message)
	if message.Metadata ~= "Roblox.Team.Success.NowInTeam" then
		local tags = C and C.ChatTags -- A23-75: the other lines go to ChatTags; Announce keeps the one callback
		if type(tags) == "table" and type(tags.Incoming) == "function" then
			local ok, props = pcall(tags.Incoming, message)
			if ok then return props end
		end
		return nil
	end
	local props = Instance.new("TextChatMessageProperties")
	-- 검수 10/09 (UI clutter review ②: the line stayed over the joystick on phones): with TeamToast the chat gets no team
	-- line (empty text); A.WatchTeam shows "You joined ...!" as one 3 s toast instead
	if Config.ChatText.TeamToast == true then
		props.Text = ""
		return props
	end
	local team = Players.LocalPlayer.Team
	local text = Config.ChatText.Choosing
	if team and not team.AutoAssignable then text = string.format(Config.ChatText.Joined, team.Name) end
	local color = team and team.TeamColor.Color or Color3.new(1, 1, 1)
	props.Text = string.format('<font color="%s"><b>%s</b></font>', hex(color), escape(text))
	return props
end

-- A23-74 (user 2026-10-07: the Korean team line still showed): the place says ChatVersion = LegacyChatService but
-- Chat.IsAutoMigrated = true, so Roblox runs the new chat anyway and hides the legacy window. The hook no longer asks
-- ChatVersion (unused when the new chat is off) and is set in Init, before any module's Start, for the first team line.
function A.HookTeamLine()
	local ok, err = pcall(function() TextChatService.OnIncomingMessage = A.Incoming end)
	if not ok then warn("[Announce] team line hookup failed: " .. tostring(err)) end
end

-- the toast for a team change (pure): only the first side pick (the auto-assigned "Choosing a side" team -> a side);
-- the login (nil -> my side) shows nothing, a later switch has its own notice (FactionService)
function A.JoinToast(was, team)
	if Config.ChatText.TeamToast ~= true then return nil end
	if not team or team.AutoAssignable or not (was and was.AutoAssignable) then return nil end
	return string.format(Config.ChatText.Joined, team.Name)
end

function A.WatchTeam()
	local lp = Players.LocalPlayer
	if typeof(lp) ~= "Instance" then return end -- test doubles without a player
	local last = lp.Team
	lp:GetPropertyChangedSignal("Team"):Connect(function()
		local was = last
		last = lp.Team
		local text = A.JoinToast(was, last)
		local kit = C and C.UIKit
		if text and type(kit) == "table" and type(kit.Toast) == "function" then pcall(kit.Toast, text, "good") end
	end)
end

function Announce.Init(registry)
	C = registry
	A.HookTeamLine()
end

function Announce.Start()
	task.spawn(function()
		local ok, err = pcall(function()
			Net.Get("Announce").OnClientEvent:Connect(function(msg)
				task.spawn(A.Show, msg) -- may wait for the legacy chat to be ready
			end)
		end)
		if not ok then warn("[Announce] hookup failed: " .. tostring(err)) end
	end)
	local okTeam, errTeam = pcall(A.WatchTeam)
	if not okTeam then warn("[Announce] team toast hookup failed: " .. tostring(errTeam)) end
	print("[Announce] started")
end

-- test aid / reuse: format a payload without showing it
Announce.Format = A.Format
Announce.Incoming = A.Incoming -- test aid
Announce.JoinToast = A.JoinToast -- test aid

return Announce
