-- Announce.luau : A23-15 server-wide chat lines for good drops (AnnounceService -> remote "Announce").
-- Formats Config.Announce.Text[Key] on this client (so it can be localized later) and shows it as a TextChatService
-- system message in RBXGeneral, colored by the weapon grade. Weapon names follow the finder's class and faction.
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

function A.Subject(args, text)
	if args.Hidden == true or type(args.Who) ~= "string" or args.Who == "" then
		local f = Config.Factions[args.Faction]
		return string.format(text.Anon, f and f.Name or "누군가")
	end
	return string.format(text.Subject, escape(args.Who))
end

function A.Format(msg)
	local text = Config.Announce and Config.Announce.Text
	if type(text) ~= "table" or type(msg) ~= "table" or type(msg.Key) ~= "string" then return nil end
	local tmpl = text[msg.Key]
	local args = type(msg.Args) == "table" and msg.Args or {}
	if type(tmpl) ~= "string" then return nil end
	local who = A.Subject(args, text)
	local tier = tonumber(args.Weapon)
	local weapon = tier and Config.WeaponName(math.floor(tier), args.Class, args.Faction) or ""
	if msg.Key == "RareWeapon" then
		local m = Config.MonsterTypes[args.Monster]
		local g = tier and Config.WeaponGrade(math.floor(tier))
		return string.format(tmpl, who, m and (m.Short or m.Name) or "몬스터", g and g.Name or "", weapon)
	elseif msg.Key == "Jackpot" or msg.Key == "FirstMax" then
		return string.format(tmpl, who, weapon)
	elseif msg.Key == "More" then
		return string.format(tmpl, who, math.floor(tonumber(args.Count) or 1))
	end
	return nil
end

function A.Show(msg)
	local ok, line = pcall(A.Format, msg)
	if not ok or type(line) ~= "string" then return end
	local g = Config.WeaponGrades[msg.Grade] or Config.WeaponGrades.Rare
	-- big news is also visible without opening the chat: a banner for Legendary, a toast for Epic (UIKit queues
	-- banners while the opening / pickers own the screen)
	local ui = C and C.UIKit
	if type(ui) == "table" then
		if g.Rank >= 5 and type(ui.Announce) == "function" then
			pcall(ui.Announce, line, 6)
		elseif g.Rank >= 4 and type(ui.Toast) == "function" then
			pcall(ui.Toast, line, "reward", 4)
		end
	end
	-- the place still runs the legacy chat (TextChatService.ChatVersion = LegacyChatService): use its system-message
	-- core call there, and the TextChatService RBXGeneral channel once the place moves to the new chat
	local legacy = false
	pcall(function() legacy = TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService end)
	if legacy then
		local plain = line:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&")
		for _ = 1, 10 do -- the legacy chat registers ChatMakeSystemMessage a moment after join
			if pcall(StarterGui.SetCore, StarterGui, "ChatMakeSystemMessage",
				{ Text = plain, Color = g.Color, Font = Enum.Font.GothamBold, TextSize = 18 }) then return end
			task.wait(0.5)
		end
		return
	end
	local rich = string.format('<font color="%s"><b>%s</b></font>', hex(g.Color), line)
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

function Announce.Init(registry)
	C = registry
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
	print("[Announce] started")
end

-- test aid / reuse: format a payload without showing it
Announce.Format = A.Format

return Announce
