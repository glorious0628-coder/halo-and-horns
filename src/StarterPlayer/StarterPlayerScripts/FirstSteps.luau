-- FirstSteps.luau : A23-68 (user 2026-10-07 "ㅇㅇ 모두 좋다 구현하자"; docs/design/early_churn_research_2026-10-07.md)
-- the first minutes' helpers on this client.
--   #1 after the guide's [Accept] the server sends Fx "Travel" { UserId, To, T } and moves me to the meadow entrance T s
--      later, then always Fx "TravelDone" { UserId } (dev2 324055a, docs/design/early_churn_server_2026-10-07.md): a
--      centre line "Off to Squishy Meadow! 3", 2, 1; the screen fades to black from T - Fade s and back in on
--      TravelDone (T + MaxExtra s at the latest); open windows close. Input is never blocked here (the server ignores
--      attacks until it moved me).
--   #2 during the first mission (TutorialStep 1..98): Idle s within my reach of a monster without a swing of mine -> the
--      attack button hint (C.HUD.Hint "Attack"); in the meadow before my first kill (my first Reward Fx) a small marker
--      over the nearest monster (C.QuestMarker.Focus). Each at most once per session. The "Try your skill!" hint moved
--      to the moment Q is learned (A23-71, SkillBar). The looks are image dev's: every call is pcall'd, so a missing
--      function just skips the hint.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local FirstSteps = {}
local LocalPlayer = Players.LocalPlayer
local C = nil

-- Forge: A23-74 weapon first, the walk to Otto's anvil (Fx "Travel" { To = "Crossroads", Spot = "Forge" })
local TXT = { Travel = "Off to %s!", Count = "%s  %d", Place = "the meadow", Forge = "the Forge" }

-- 최종 검수 10/14 (A23-179: Roblox's automatic translation matches whole drawn sentences, so a line with a number or a
-- name stayed English): a sentence with %-slots by its table key (UIKit.Tx -> UIKit.Tr: the localization table by key;
-- English exactly as before); without UIKit (offline tests) string.format; a failed format = the words as they are
local function trx(t, key, ...)
	local f = type(t) == "table" and (t[key .. "En"] or t[key]) or nil
	if type(f) ~= "string" then return nil end
	local kit = C and C.UIKit
	if type(kit) == "table" and type(kit.Tx) == "function" then
		local ok, out = pcall(kit.Tx, t, key, ...)
		if ok and type(out) == "string" then return out end
	end
	local ok, out = pcall(string.format, f, ...)
	return ok and out or f
end
-- FocusUp / Again: 검수 2026-10-08 - after the server moves me (TravelDone) the camera stayed where it was, often in front
-- of my face (CameraFollow never recenters a camera my body faces: its backpedal rule), so under the black it goes round
-- behind my back once (same distance and height over the focus), and once more Again s later (the move may replicate late)
local TRAVEL = { Fade = 0.4, MaxExtra = 1.5, FadeIn = 0.5, Token = 0, Gui = nil, Black = nil, Line = nil, Done = false,
	FocusUp = 1.5, Again = 0.15 }
-- MarkAfter / MeadowSince: 검수 10/09 (UI clutter review ④, "help only when stuck") - the marker comes only after MarkAfter s
-- in the meadow during the first mission without a kill (the time keeps counting across a trip out and back)
local HINT = { Idle = 5, Tick = 0.25, Search = 120, MarkerGap = 0.5, NearSince = nil, MarkAfter = 45, MeadowSince = nil,
	AttackShown = false, Killed = false, MarkerAt = -math.huge, Marked = nil }

local function attr(key, default)
	local v = LocalPlayer:GetAttribute(key)
	if v == nil then return default end
	return v
end

local function call(mod, fn, ...)
	local m = C and C[mod]
	local f = type(m) == "table" and m[fn] or nil
	if type(f) ~= "function" then return false end
	return pcall(f, ...)
end

local function mine(data)
	return type(data) == "table" and data.UserId == LocalPlayer.UserId
end

------------------------------------------------------------------ #1 travel fade
function TRAVEL.Build()
	if TRAVEL.Gui and TRAVEL.Gui.Parent then return end
	local gui = Instance.new("ScreenGui")
	gui.Name = "TravelFade"
	gui.IgnoreGuiInset, gui.ResetOnSpawn, gui.DisplayOrder = true, false, 75
	pcall(function() gui.ScreenInsets = Enum.ScreenInsets.None end)
	local black = Instance.new("Frame")
	black.Name = "Black"
	black.BackgroundColor3, black.BorderSizePixel, black.BackgroundTransparency = Color3.new(0, 0, 0), 0, 1
	black.Size = UDim2.fromScale(1, 1)
	black.Parent = gui
	local line = Instance.new("TextLabel")
	line.Name = "Line"
	line.AnchorPoint, line.Position, line.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.38), UDim2.new(0.8, 0, 0, 56)
	line.BackgroundTransparency, line.TextScaled, line.Text = 1, true, ""
	line.TextColor3, line.TextStrokeTransparency = Color3.fromRGB(255, 236, 170), 0.2
	line.Font = Enum.Font.GothamBold
	line.ZIndex = 2
	line.Parent = gui
	local kit = C and C.UIKit
	if type(kit) == "table" and type(kit.StyleText) == "function" then pcall(kit.StyleText, line, "Title") end
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	TRAVEL.Gui, TRAVEL.Black, TRAVEL.Line = gui, black, line
end

local function fade(to, seconds)
	if not TRAVEL.Black then return end
	TweenService:Create(TRAVEL.Black, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ BackgroundTransparency = to }):Play()
end

-- where the camera goes after a server move: behind rootPos (against my facing, flat), as far from and as high over the
-- new focus as it was over the old one; nil when the camera sits on its focus or I face straight up / down
function TRAVEL.BehindSpot(camPos, focusPos, rootPos, look)
	local ox, oy, oz = camPos.X - focusPos.X, camPos.Y - focusPos.Y, camPos.Z - focusPos.Z
	local dist = math.sqrt(ox * ox + oz * oz)
	local lx, lz = look.X, look.Z
	local ll = math.sqrt(lx * lx + lz * lz)
	if dist < 0.5 or ll < 0.1 then return nil end
	lx, lz = lx / ll, lz / ll
	local focus = Vector3.new(rootPos.X, rootPos.Y + TRAVEL.FocusUp, rootPos.Z)
	return Vector3.new(focus.X - lx * dist, focus.Y + oy, focus.Z - lz * dist), focus
end

function TRAVEL.Behind()
	local cam = workspace.CurrentCamera
	local character = LocalPlayer and LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (cam and root) or cam.CameraType ~= Enum.CameraType.Custom then return false end
	local pos, focus = TRAVEL.BehindSpot(cam.CFrame.Position, cam.Focus.Position, root.Position, root.CFrame.LookVector)
	if not pos then return false end
	cam.CFrame = CFrame.lookAt(pos, focus)
	return true
end

-- back in (TravelDone or the time limit): the black lifts, then the gui goes; moved = the server's TravelDone (I was
-- moved): the camera goes behind my back first
function TRAVEL.Finish(token, moved)
	if token ~= TRAVEL.Token or TRAVEL.Done then return end
	TRAVEL.Done = true
	if TRAVEL.Line then TRAVEL.Line.Text = "" end
	if moved then
		pcall(TRAVEL.Behind)
		task.delay(TRAVEL.Again, function()
			if token == TRAVEL.Token then pcall(TRAVEL.Behind) end
		end)
	end
	fade(1, TRAVEL.FadeIn)
	task.delay(TRAVEL.FadeIn + 0.1, function()
		if token == TRAVEL.Token and TRAVEL.Gui then
			TRAVEL.Gui:Destroy()
			TRAVEL.Gui, TRAVEL.Black, TRAVEL.Line = nil, nil, nil
		end
	end)
end

function TRAVEL.Start(data)
	TRAVEL.Token += 1
	local token = TRAVEL.Token
	TRAVEL.Done = false
	local t = math.clamp(tonumber(data.T) or 3, 0.5, 10)
	local zone = type(data.To) == "string" and Config.Zones[data.To] or nil
	local place = (data.Spot == "Forge" and TXT.Forge) or (zone and zone.Name) or TXT.Place
	TRAVEL.Build()
	call("Panels", "Close", false) -- the guide window: the walk is over before it could be read
	local whole = math.floor(t + 0.5)
	for i = 0, whole - 1 do
		task.delay(i, function()
			if token == TRAVEL.Token and not TRAVEL.Done and TRAVEL.Line then
				TRAVEL.Line.Text = trx(TXT, "Count", trx(TXT, "Travel", place), whole - i)
			end
		end)
	end
	task.delay(math.max(0, t - TRAVEL.Fade), function()
		if token == TRAVEL.Token and not TRAVEL.Done then fade(0, TRAVEL.Fade) end
	end)
	task.delay(t + TRAVEL.MaxExtra, function() TRAVEL.Finish(token) end)
end

------------------------------------------------------------------ #2 hints in place
-- the slime part of the first mission (A23-74: not the Forge step before it, the hints are about hitting monsters)
local function firstMission()
	local step = tonumber(attr("TutorialStep", 0)) or 0
	local steps = type(Config.Tutorial) == "table" and type(Config.Tutorial.Steps) == "table" and Config.Tutorial.Steps or {}
	return step >= 1 and step < 99 and step ~= (tonumber(steps.Forge) or 3)
end

local function myRoot()
	local ch = LocalPlayer.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then return root end
	return nil
end

-- the nearest live monster (mine first: the first mission's slimes are personal) within `limit` studs
function HINT.Nearest(pos, limit)
	local folder = workspace:FindFirstChild("Monsters")
	if not folder then return nil, math.huge end
	local best, bestD, bestMine = nil, limit, false
	for _, m in folder:GetChildren() do
		local r = m:IsA("Model") and (m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")) or nil
		local hum = m:FindFirstChildOfClass("Humanoid")
		if r and (not hum or hum.Health > 0) then
			local d = (r.Position - pos).Magnitude
			local owner = m:GetAttribute("OwnerUserId")
			local isMine = owner == LocalPlayer.UserId
			if d <= limit and (best == nil or (isMine and not bestMine) or (isMine == bestMine and d < bestD)) then
				best, bestD, bestMine = m, d, isMine
			end
		end
	end
	return best, best and bestD or math.huge
end

function HINT.Reach()
	local p = Config.AttackProfile(attr("Class", "Warrior"), tonumber(attr("WeaponTier", 0)) or 0, attr("Faction", "None"))
	return (type(p) == "table" and tonumber(p.Range) or 7) + 2 -- a little slack: standing at the edge counts
end

function HINT.Mark(model)
	if HINT.Marked == model then return end
	HINT.Marked = model
	call("QuestMarker", "Focus", model)
end

function HINT.Step(now)
	if not firstMission() then
		HINT.NearSince = nil
		if HINT.Marked then HINT.Mark(nil) end
		return
	end
	local root = myRoot()
	if not root then return end
	-- the attack hint: Idle s within reach without a swing of mine (a swing restarts the wait); A23-130: off while
	-- Config.Nudges.AttackHint = false
	if not HINT.AttackShown and (Config.Nudges or {}).AttackHint ~= false then
		local _, d = HINT.Nearest(root.Position, HINT.Reach())
		if d < math.huge then
			HINT.NearSince = HINT.NearSince or now
			if now - HINT.NearSince >= HINT.Idle then
				HINT.AttackShown = true
				call("HUD", "Hint", "Attack")
			end
		else
			HINT.NearSince = nil
		end
	end
	-- the marker over the nearest monster, in the meadow, until my first kill
	if HINT.Killed or attr("ZoneId", "") ~= "SlimeMeadow" then
		if HINT.Marked then HINT.Mark(nil) end
	elseif now - (HINT.MeadowSince or now) < HINT.MarkAfter or not HINT.MeadowSince then
		HINT.MeadowSince = HINT.MeadowSince or now -- the first moment in the meadow on the first mission
	elseif now - HINT.MarkerAt >= HINT.MarkerGap then
		HINT.MarkerAt = now
		HINT.Mark((HINT.Nearest(root.Position, HINT.Search)))
	end
end

function HINT.Kill()
	if HINT.Killed then return end
	HINT.Killed = true
	if HINT.Marked then HINT.Mark(nil) end
end

------------------------------------------------------------------ wiring
function FirstSteps.OnFx(kind, data)
	if kind == "Travel" and mine(data) then
		TRAVEL.Start(data)
	elseif kind == "TravelDone" and mine(data) then
		TRAVEL.Finish(TRAVEL.Token, true)
	elseif (kind == "Swing" or kind == "Release" or kind == "Skill") and mine(data) then
		HINT.NearSince = nil
	elseif kind == "Reward" then -- sent only to the killer (ProgressionService)
		HINT.Kill()
	end
end

function FirstSteps.Init(registry)
	C = registry
	pcall(function() C.UIKit.L10n.Register("FirstSteps.TXT", TXT) end) -- 10/14: the words' keys "FirstSteps.TXT.<key>" (trx)
end

----------------------------------------------------------------- 검수 10/09 (system review ②) the first PvP zone
-- the first time I walk into a PvP zone (not the Artisan Guild: nobody can fight it), one calm card (PauseCard "Tip", it
-- waits for a calm screen; 검수 10/11 A23-130: the three cards became one - the danger line + one short line); once it
-- is closed the Settings flag PvPCards (saved with my account) keeps it from coming again. Shown only from the place: no
-- button sends me anywhere
local PVP = { Title = "PvP zone", Why = "PvPIntro", Step = 0,
	Text = "Other players can fight you here!\nKnocked out? You can lose pocket gold. Towns keep it safe." }

-- the card would open for me now (not the Guild, my Settings loaded, PvPCards not set yet)
function PVP.Wanted()
	if attr("Faction", "") == "Neutral" then return false end
	local st = C and C.Settings
	if type(st) ~= "table" or type(st.Get) ~= "function" or (type(st.Loaded) == "function" and not st.Loaded()) then return false end
	local ok, seen = pcall(st.Get, "PvPCards")
	return ok and seen ~= true
end

function PVP.Check()
	if PVP.Step > 0 or attr("ZonePvP", false) ~= true or not PVP.Wanted() then return end
	PVP.Step = 1
	PVP.Show()
end

-- 게임성 검수 10/12 (A23-130, one explanation at a time): the server's "PvP zone!" line (Config.Text.EnteredPvP) does not
-- come with my first PvP card - while it waits / is open (Step 1) or when this entry opens it (the line may arrive before
-- ZonePvP); from the next entry on (the card seen) the line shows as before. A UIKit.NotifyFilters entry.
function PVP.SkipToast(payload, text)
	local line = type(Config.Text) == "table" and Config.Text.EnteredPvP or nil
	if not ((line ~= nil and text == line) or (type(payload) == "table" and payload.Key == "EnteredPvP")) then return false end
	if PVP.Step == 1 then return true end
	return PVP.Step == 0 and PVP.Wanted()
end

function PVP.Show()
	call("PauseCard", "Show", "Tip", { Title = PVP.Title, Text = PVP.Text, Why = PVP.Why })
end

-- my card was closed (PauseCard.Shown: kind, button, why): the flag, once
function PVP.OnShown(_kind, _button, why)
	if why ~= PVP.Why or PVP.Step ~= 1 then return end
	PVP.Step = 2
	call("Settings", "Set", "PvPCards", true)
end

function FirstSteps.Start()
	local okPvp, errPvp = pcall(function()
		LocalPlayer:GetAttributeChangedSignal("ZonePvP"):Connect(PVP.Check)
		local card = C and C.PauseCard
		if type(card) == "table" and type(card.Shown) == "table" then card.Shown:Connect(PVP.OnShown) end
		local ui = C and C.UIKit
		if type(ui) == "table" and type(ui.NotifyFilters) == "table" then table.insert(ui.NotifyFilters, PVP.SkipToast) end
	end)
	if not okPvp then warn("[FirstSteps] PvP cards hookup failed: " .. tostring(errPvp)) end
	task.spawn(function()
		local ok, err = pcall(function() Net.Get("Fx").OnClientEvent:Connect(FirstSteps.OnFx) end)
		if not ok then warn("[FirstSteps] Fx hookup failed: " .. tostring(err)) end
	end)
	task.spawn(function()
		while true do
			task.wait(HINT.Tick)
			local ok, err = pcall(HINT.Step, os.clock())
			if not ok then warn("[FirstSteps] " .. tostring(err)) task.wait(5) end
		end
	end)
end

-- test aids
FirstSteps.Travel, FirstSteps.Hint, FirstSteps.Text, FirstSteps.PvP = TRAVEL, HINT, TXT, PVP

return FirstSteps
