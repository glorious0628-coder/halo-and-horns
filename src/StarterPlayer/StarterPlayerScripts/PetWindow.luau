-- PetWindow.luau (게임성 개발 1, PET-5 펫 창; server = 게임성 개발 2's PET-2 PetService, contract
-- docs/design/pet4_lost_baby_slime_2026-10-09.md "PET-2"): the Panels window "Pet" the HUD's Pet tile opens.
--   s->c "PetList" (owner only, at join / grant / equip / pet XP): { Equipped = uid | "", List = { { Uid, Sp, Lv, XP,
--   Need, Name, Lean } }, CanPutAway? }. One row per pet: its icon, name (the story name, else the species name), Lv,
--   the walk speed it gives (Config.PetSpeedBonus) and an XP bar (XP / Need; MAX at Config.Pets.MaxLv). The pet that
--   follows says so and has [Put away]; the others have [Follow me]. c->s "EquipPet"(uid | "") - one press per Gap s,
--   the server's next PetList redraws the window.
--   검수 10/09 (docs/review/pet2_verify_2026-10-09.md M1): the tamer's pet is its weapon, so a tamer never sees
--   [Put away] (Config.IsTamer, or PetList CanPutAway = false once the server sends it).
--   The tamer's summons (게임성 개발 4, 2026-10-12; server 개발 3 dev3-tamer, docs/design/tamer_server_2026-10-12.md §7):
--   a PetList row's Roll = { Spd } (a summoned pet's walk speed roll, whole %; the follower's is the attribute PetRoll)
--   goes into Config.PetSpeedBonus(sp, lv, roll) and shows as "Born with +N% speed" (no line without a Roll). While
--   research is on (Config.Features.Research) each pet has [Feed (n)] = c->s FeedPet(uid): one Pet Treat
--   (Config.Research.Treat) for pet XP; off at the top level or with no treats (n = the bag's count, live).
-- PC first (A23-98); no new art: the approved pet icon (Config.UIArt IconPetBabySlime) and the Panels kit. Game text:
-- English only (A23-48), short and easy. Presentation only: the server owns every pet, level and equip.
-- Public API: PetWindow.Init(C), PetWindow.Start(), PetWindow.IsReady(), PetWindow.Open(), PetWindow.OnList(payload),
-- PetWindow.Rows(payload, ctx) -> rows (pure; ctx = { Class, Faction, EquippedPet, PetLv }), PetWindow.Equip(uid) -> bool,
-- PetWindow.FollowerName() -> my following pet's story name or nil (PetFollow's tag), PetWindow.Feed(uid) -> bool,
-- PetWindow.PaintFeeds(n).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local LocalPlayer = Players.LocalPlayer

local PetWindow = {}
local C = nil
local TAG = "PetWindow"

local T = {
	Window = "Pet",
	Remote = "EquipPet",
	FeedRemote = "FeedPet",
	Gap = 0.6, -- s: one press at a time (Config.RateLimits.EquipPet 0.5 + a margin; FeedPet 0.5 too)
	Icon = 72, ButtonW = 132, ButtonH = 40, BarH = 20, BarText = 15, -- 검수 10/10: the XP numbers >= 15 px
	DefaultIcon = "IconPetBabySlime",
	-- game text: English only (A23-48)
	Text = Config.ClientText.PetWindow, -- the words: Config.ClientText.PetWindow (moved 10/14)
}
local S = { Ready = false, List = nil, Sig = "", Shape = "", PressAt = -math.huge, FeedAt = -math.huge }
-- Bars[uid] = { Set = setFraction, Text = its TextLabel } and Feeds[uid] = { Button, Max } of the open window
local VIEW = { Kit = nil, Bars = {}, Feeds = {} }

local function num(v, d)
	v = tonumber(v)
	if v == nil or v ~= v or v == math.huge or v == -math.huge then return d end
	return v
end

local function speciesDef(sp)
	local P = type(Config.Pets) == "table" and Config.Pets or {}
	local list = type(P.Species) == "table" and P.Species or {}
	return type(sp) == "string" and type(list[sp]) == "table" and list[sp] or nil
end

local function speciesName(sp)
	local def = speciesDef(sp)
	if def and type(def.Name) == "string" and def.Name ~= "" then return def.Name end
	return type(sp) == "string" and sp or "?"
end

-- one row per pet, the one that follows first (then by uid). payload = the last PetList (nil = none yet: the follower
-- from the public attributes, without XP or buttons). Pure
-- a summoned pet's walk speed roll (whole %), nil for none
local function rollOf(v)
	local n = num(type(v) == "table" and v.Spd or v, 0)
	return n > 0 and math.floor(n) or nil
end

-- A23-194 (pure): a pet's own bonus line { Type, Pct } (Pct = % with one decimal), nil for Speed (its own lines) / None
function PetWindow.BonusOf(sp, lv)
	local def = speciesDef(sp)
	local kind = type(def) == "table" and type(def.Bonus) == "table" and def.Bonus.Type or nil
	if type(kind) ~= "string" or kind == "Speed" or kind == "None" or type(Config.PetBonus) ~= "function" then return nil end
	local v = tonumber(Config.PetBonus(sp, lv, kind)) or 0
	if v <= 0 then return nil end
	return { Type = kind, Pct = math.floor(v * 1000 + 0.5) / 10 }
end

function PetWindow.Rows(payload, ctx)
	ctx = type(ctx) == "table" and ctx or {}
	local maxLv = math.max(1, math.floor(num(type(Config.Pets) == "table" and Config.Pets.MaxLv, 10)))
	local tamer = Config.IsTamer(ctx.Class, ctx.Faction)
	local feed = type(ctx.Feed) == "table" and ctx.Feed.On == true and ctx.Feed or nil -- { On, Count }: research on
	local rows = {}
	if type(payload) ~= "table" or type(payload.List) ~= "table" then
		local sp = ctx.EquippedPet
		if type(sp) == "string" and sp ~= "" then
			local lv = math.clamp(math.floor(num(ctx.PetLv, 1)), 1, maxLv)
			local roll = rollOf(ctx.PetRoll)
			table.insert(rows, { Uid = nil, Species = sp, Name = speciesName(sp), Lv = lv, Max = lv >= maxLv, Fill = 0,
				XP = nil, Need = nil, Equipped = true, Speed = math.floor(Config.PetSpeedBonus(sp, lv, roll) * 100 + 0.5),
				Roll = roll, CanFollow = false, CanPutAway = false, Icon = (speciesDef(sp) or {}).Icon or T.DefaultIcon,
				Bonus = PetWindow.BonusOf(sp, lv) })
		end
		return rows
	end
	local equipped = type(payload.Equipped) == "string" and payload.Equipped or ""
	local canPut = payload.CanPutAway ~= false and not tamer
	for _, p in payload.List do
		if type(p) == "table" and type(p.Uid) == "string" and p.Uid ~= "" then
			local sp = type(p.Sp) == "string" and p.Sp or ""
			local lv = math.clamp(math.floor(num(p.Lv, 1)), 1, maxLv)
			local need = math.max(0, math.floor(num(p.Need, 0)))
			local xp = math.max(0, math.floor(num(p.XP, 0)))
			local isMax = lv >= maxLv or need <= 0
			local on = p.Uid == equipped
			local roll = rollOf(p.Roll)
			table.insert(rows, {
				Uid = p.Uid, Species = sp,
				Name = (type(p.Name) == "string" and p.Name ~= "") and p.Name or speciesName(sp),
				Lv = lv, XP = xp, Need = need, Max = isMax, Fill = isMax and 1 or math.clamp(xp / math.max(1, need), 0, 1),
				Equipped = on, Speed = math.floor(Config.PetSpeedBonus(sp, lv, roll) * 100 + 0.5), Roll = roll,
				CanFollow = not on and speciesDef(sp) ~= nil, CanPutAway = on and canPut,
				Icon = (speciesDef(sp) or {}).Icon or T.DefaultIcon, Bonus = PetWindow.BonusOf(sp, lv),
				-- [Feed (n)]: off at the top level or with no treat
				Feed = feed and { Count = math.max(0, math.floor(num(feed.Count, 0))), Enabled = not isMax and num(feed.Count, 0) >= 1 } or nil,
			})
		end
	end
	table.sort(rows, function(a, b)
		if a.Equipped ~= b.Equipped then return a.Equipped end
		return a.Uid < b.Uid
	end)
	return rows
end

-- research on (the feed button; 개발 3 dev3-tamer's switch + its table + the treat item)
local function feedOn()
	local R = type(Config.Research) == "table" and Config.Research or nil
	return type(Config.FeatureOn) == "function" and Config.FeatureOn("Research") == true and R ~= nil
		and type(R.Treat) == "string" and Config.Loot.Items[R.Treat] ~= nil
end

-- how many Pet Treats the bag holds (Panels' copy of the Inventory push)
local function treats()
	local panels = C and C.Panels
	if not feedOn() or type(panels) ~= "table" or type(panels.LastInventory) ~= "function" then return 0 end
	local ok, payload = pcall(panels.LastInventory)
	local items = ok and type(payload) == "table" and type(payload.Items) == "table" and payload.Items or {}
	return math.max(0, math.floor(num(items[Config.Research.Treat], 0)))
end

local function context()
	return { Class = LocalPlayer:GetAttribute("Class"), Faction = LocalPlayer:GetAttribute("Faction"),
		EquippedPet = LocalPlayer:GetAttribute("EquippedPet"), PetLv = LocalPlayer:GetAttribute("PetLv"),
		PetRoll = LocalPlayer:GetAttribute("PetRoll"), Feed = feedOn() and { On = true, Count = treats() } or nil }
end

-- c->s EquipPet(uid); "" = put the follower away. One press per Gap s
function PetWindow.Equip(uid)
	if type(uid) ~= "string" or os.clock() - S.PressAt < T.Gap then return false end
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = folder and folder:FindFirstChild(T.Remote)
	if not remote or not remote:IsA("RemoteEvent") then return false end
	S.PressAt = os.clock()
	return (pcall(remote.FireServer, remote, uid))
end

-- c->s FeedPet(uid): one Pet Treat for that pet (research on, a treat in the bag, below the top level). One press per Gap s
function PetWindow.Feed(uid)
	if type(uid) ~= "string" or uid == "" or not feedOn() or os.clock() - S.FeedAt < T.Gap then return false end
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = folder and folder:FindFirstChild(T.FeedRemote)
	if not remote or not remote:IsA("RemoteEvent") then return false end
	S.FeedAt = os.clock()
	return (pcall(remote.FireServer, remote, uid))
end

-- style = a UIKit text style (게임성 검수 10/12: the small lines took the UIKit floor like every other window's)
local function label(kit, parent, text, size, color, width, style)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = width or UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.Font = kit.Font
	l.TextSize = size
	l.TextColor3 = color
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.LayoutOrder = kit.NextOrder()
	l.Parent = parent
	local ui = C and C.UIKit
	if style and type(ui) == "table" and type(ui.StyleText) == "function" then
		pcall(ui.StyleText, l, style)
		l.TextColor3 = color
	end
	return l
end

local function list(parent, gap, horizontal)
	local l = Instance.new("UIListLayout")
	l.FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, gap)
	l.Parent = parent
end

local function icon(kit, parent, row)
	local size = UDim2.fromOffset(T.Icon, T.Icon)
	local ui = C and C.UIKit
	local img = nil
	if type(ui) == "table" and type(ui.ArtImage) == "function" then
		local ok, made = pcall(ui.ArtImage, row.Icon, { Name = "Icon", Size = size })
		if ok then img = made end
	end
	if not img then -- code fallback: a round tile
		img = Instance.new("Frame")
		img.Name = "Icon"
		img.Size = size
		img.BackgroundColor3 = kit.Palette.Button
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = img
	end
	img.LayoutOrder = kit.NextOrder()
	img.Parent = parent
end

local function petRow(kit, parent, row)
	local f = Instance.new("Frame")
	f.Name = "Pet_" .. tostring(row.Uid or row.Species)
	f.BackgroundColor3 = kit.Palette.Button
	f.BackgroundTransparency = row.Equipped and 0.45 or 0.65
	f.BorderSizePixel = 0
	-- the row grows with its words / buttons (the styled lines and [Feed] made it taller than the icon)
	f.Size = UDim2.new(1, 0, 0, T.Icon + 20)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.LayoutOrder = kit.NextOrder()
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = f
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	pad.Parent = f
	list(f, 12, true)
	f.Parent = parent
	icon(kit, f, row)
	-- middle: name, Lv + speed, the XP bar
	local mid = Instance.new("Frame")
	mid.Name = "Info"
	mid.BackgroundTransparency = 1
	mid.Size = UDim2.new(1, -(T.Icon + T.ButtonW + 24), 0, 0)
	mid.AutomaticSize = Enum.AutomaticSize.Y
	mid.LayoutOrder = kit.NextOrder()
	list(mid, 4)
	mid.Parent = f
	local name = label(kit, mid, row.Name, 20, row.Equipped and kit.Theme.Gold or kit.Theme.Text)
	name.Font = Enum.Font.GothamBold
	name.TextWrapped = false
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local line = string.format(T.Text.Level, row.Lv)
	if row.Speed > 0 then line ..= " · " .. string.format(row.Equipped and T.Text.Speed or T.Text.SpeedRest, row.Speed) end
	local words = type(T.Text.Bonus) == "table" and row.Bonus and T.Text.Bonus[row.Bonus.Type] or nil
	if type(words) == "string" then line ..= " · " .. string.format(words, string.format("%g", row.Bonus.Pct)) end
	local lineLabel = label(kit, mid, line, 16, kit.Theme.SubText, nil, "Body")
	-- A23-194: the following pet's bonus does nothing in a PvP zone (PetService uses 0 there): its line dims
	if row.Equipped and row.Bonus and LocalPlayer and LocalPlayer:GetAttribute("ZonePvP") == true then
		lineLabel.TextTransparency = 0.55
	end
	if row.Roll then label(kit, mid, string.format(T.Text.Born, row.Roll), 16, kit.Theme.SubText, nil, "Body") end
	if row.XP ~= nil or row.Max then
		local ui = C and C.UIKit
		if type(ui) == "table" and type(ui.Bar) == "function" then
			local ok, bar, setFill, text = pcall(ui.Bar, { Name = "XP", Size = UDim2.new(1, 0, 0, T.BarH), TextSize = T.BarText,
				Color = kit.Theme.Gold, Text = PetWindow.BarText(row) })
			if ok and bar then
				bar.LayoutOrder = kit.NextOrder()
				setFill(row.Fill)
				bar.Parent = mid
				if row.Uid then VIEW.Bars[row.Uid] = { Set = setFill, Text = text } end
			end
		end
	end
	-- right: the follower says so (+ [Put away] unless a tamer); the others [Follow me]
	local right = Instance.new("Frame")
	right.Name = "Actions"
	right.BackgroundTransparency = 1
	right.Size = UDim2.new(0, T.ButtonW, 0, 0)
	right.AutomaticSize = Enum.AutomaticSize.Y
	right.LayoutOrder = kit.NextOrder()
	list(right, 4)
	right.Parent = f
	if row.Equipped then
		local tag = label(kit, right, T.Text.Following, 16, kit.Theme.Gold, nil, "Body")
		tag.TextXAlignment = Enum.TextXAlignment.Center
	end
	local text, uid, color = nil, nil, nil
	if row.CanPutAway then
		text, uid, color = T.Text.PutAway, "", kit.Palette.Button
	elseif row.CanFollow then
		text, uid, color = T.Text.Follow, row.Uid, kit.Theme.Good
	end
	if text then
		local b = kit.Button(right, text, color, UDim2.fromOffset(T.ButtonW, T.ButtonH), function()
			PetWindow.Equip(uid)
		end)
		-- sound_gaps 2026-10-10 / 13차: both buttons sound when the server's PetList says it happened (Audio: PetCall /
		-- PetStow), no Click
		pcall(b.SetAttribute, b, "NoClick", true)
		b.LayoutOrder = kit.NextOrder()
	end
	if row.Feed and row.Uid then
		local uid = row.Uid
		local b = kit.Button(right, string.format(T.Text.Feed, row.Feed.Count), kit.Palette.Button,
			UDim2.fromOffset(T.ButtonW, T.ButtonH), function() PetWindow.Feed(uid) end)
		b.Name = "Feed"
		b.LayoutOrder = kit.NextOrder()
		if type(kit.SetEnabled) == "function" then kit.SetEnabled(b, row.Feed.Enabled) end
		VIEW.Feeds[uid] = { Button = b, Max = row.Max }
	end
end

local function build(parent, kit)
	VIEW.Kit = kit
	VIEW.Bars, VIEW.Feeds = {}, {}
	local rows = PetWindow.Rows(S.List, context())
	S.Sig, S.Shape = PetWindow.Sig(rows), PetWindow.Sig(rows, true)
	if #rows == 0 then
		local l = label(kit, parent, T.Text.Empty, 18, kit.Theme.SubText)
		l.TextXAlignment = Enum.TextXAlignment.Center
		return nil
	end
	for _, row in rows do petRow(kit, parent, row) end
	-- Panels' 0.25 s update: the treat count on the feed buttons, in place (a treat made / eaten)
	local shown = treats()
	return function()
		if VIEW.Kit ~= kit or next(VIEW.Feeds) == nil then return end
		local n = treats()
		if n == shown then return end
		shown = n
		PetWindow.PaintFeeds(n)
	end
end

-- the feed buttons' words and on / off for n treats (the open window)
function PetWindow.PaintFeeds(n)
	local kit = VIEW.Kit
	for _, f in VIEW.Feeds do
		f.Button.Text = string.format(T.Text.Feed, n)
		if kit and type(kit.SetEnabled) == "function" then kit.SetEnabled(f.Button, n >= 1 and not f.Max) end
	end
end

-- the XP bar's words of a row
function PetWindow.BarText(row)
	return row.Max and T.Text.Max or string.format(T.Text.XP, row.XP or 0, row.Need or 0)
end

-- what the window shows (a PetList with nothing new for it skips the redraw); shapeOnly = without the XP numbers (an
-- XP-only change updates the bars in place: a rebuild would drop a button press in progress, 검수 10/10)
function PetWindow.Sig(rows, shapeOnly)
	local parts = {}
	for _, r in rows do
		table.insert(parts, table.concat({ tostring(r.Uid), r.Name, r.Lv, tostring(r.Max), tostring(r.Equipped),
			tostring(r.CanPutAway), tostring(r.CanFollow), tostring(r.Roll), tostring(r.Feed ~= nil),
			shapeOnly and "" or tostring(r.XP), shapeOnly and "" or tostring(r.Need) }, "|"))
	end
	return table.concat(parts, ";")
end

local function cleanup()
	VIEW.Kit, VIEW.Bars, VIEW.Feeds = nil, {}, {}
end

function PetWindow.IsReady()
	return S.Ready
end

function PetWindow.Open()
	local panels = C and C.Panels
	if not S.Ready or type(panels) ~= "table" or type(panels.Open) ~= "function" then return false end
	return (pcall(panels.Open, T.Window))
end

-- the last PetList and the one before it (Audio: a remote fired before a second listener connects reaches only the
-- first one, so Audio may have missed the join list - it reads it here)
function PetWindow.Lists()
	return S.List, S.Prev
end

-- PET-4: my following pet's story name (Good Buddy / Little Minion) for the tag over it (PetFollow); nil without one
function PetWindow.FollowerName()
	local p = S.List
	if type(p) ~= "table" or type(p.List) ~= "table" or type(p.Equipped) ~= "string" or p.Equipped == "" then return nil end
	for _, e in p.List do
		if type(e) == "table" and e.Uid == p.Equipped and type(e.Name) == "string" and e.Name ~= "" then return e.Name end
	end
	return nil
end

-- the owner's "PetList": kept; the open window redraws when what it shows changed (XP only: the bars in place)
function PetWindow.OnList(payload)
	if type(payload) ~= "table" or type(payload.List) ~= "table" then return false end
	S.Prev, S.List = S.List, payload
	local kit = VIEW.Kit
	local panels = C and C.Panels
	local open = kit ~= nil and type(panels) == "table" and type(panels.CurrentId) == "function" and panels.CurrentId() == T.Window
	if not open then return false end
	local rows = PetWindow.Rows(payload, context())
	local sig = PetWindow.Sig(rows)
	if sig == S.Sig then return false end
	if PetWindow.Sig(rows, true) == S.Shape then -- only XP moved: the bars, in place
		for _, r in rows do
			local b = r.Uid and VIEW.Bars[r.Uid]
			if b then
				pcall(b.Set, r.Fill)
				if b.Text then b.Text.Text = PetWindow.BarText(r) end
			end
		end
		S.Sig = sig
		return true
	end
	pcall(kit.Rebuild, true)
	return true
end

function PetWindow.Init(registry)
	C = registry
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.Register) ~= "function" then
		Util.Warn(TAG, "Panels.Register is missing; the pet window is off")
		return
	end
	S.Ready = panels.Register(T.Window, {
		Title = T.Text.Title,
		Rebuild = { EquippedPet = true, PetLv = true, PetRoll = true, Class = true, Faction = true, ZonePvP = true },
		Build = build,
		Cleanup = cleanup,
	}) == true
end

function PetWindow.Start()
	task.spawn(function()
		local ok, err = pcall(function()
			Net.Get("PetList").OnClientEvent:Connect(function(payload)
				pcall(PetWindow.OnList, payload)
			end)
		end)
		if not ok then Util.Warn(TAG, "remote hookup failed: " .. tostring(err)) end
	end)
end

return PetWindow
