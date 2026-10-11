-- CraftWindow.luau (게임성 개발 4, ③-3 제작 창; SPEC A23-127 · A23-56 · A23-133 · A23-130 · A23-98 · A23-111, design
-- docs/design/craft_server_2026-10-12.md §4 (the screen contract) + hammer_minigame_2026-10-12.md §2): the Panels window
-- "Craft" where an artisan picks one of their role's recipes and starts it.
--   top     : my artisan class and craft level ("Blacksmith Lv 3") with the XP bar to the next (CraftInfo; "Max" at MaxLv)
--   list    : my role's recipes (Config.Craft.Recipes, Role = mine, every material a known item; CraftInfo.On when the
--             server sends it), lowest craft level first: the result in its grade slot, its name, "Lv N" (red while my
--             craft level is lower), a gold check when I can make it now
--   detail  : the picked recipe - big slot, name, grade, attack (weapons), the materials (have / need, red when short), the
--             gold, the craft XP, how many I made, why it can't start (the server's own notice texts, Config.Craft.Text)
--             and [Forge] -> c->s CraftStart(recipeId). The server answers CraftSession: CraftView's ring screen opens
--             and closes this window; after the ring this window opens again on the same recipe
--   bottom  : my gold (bank + carried; a craft spends carried first, then the bank - ProgressionService.SpendGold)
-- Opened by the menu (artisans only, while Config.Features.Crafting is on) and by the server's OpenPanel("Craft") (a
-- workbench's "CraftPrompt": the server's ProximityPrompt on each CraftStation part with ActionText / ObjectText "" and
-- the keys ActionKey / ObjectKey - this module writes its words in my language and shows it only to an artisan of the
-- bench's Role, 개발 3 dev3-craft2).
-- Display only: CraftService.TryStart checks it all again and its refusals come as notices (no second line here, A23-130).
-- Text: short English in TXT (L10n key "CraftWindow.TXT.*", A23-111); names through Config (UIKit.Tx). PC first (A23-98).
-- Public API: CraftWindow.Init(C), CraftWindow.Start(), CraftWindow.IsReady(), CraftWindow.CanOpen(), CraftWindow.Open(id?),
-- CraftWindow.OnInfo(payload), CraftWindow.Forge(id), CraftWindow.Watch(), CraftWindow.RefreshStations(); pure:
-- CraftWindow.Words(actionKey, objectKey, lang), CraftWindow.RoleOf(ctx),
-- CraftWindow.Entries(ctx) -> entries, CraftWindow.Reason(entry, ctx) -> Config.Craft.Text key?, CraftWindow.Detail(entry,
-- ctx) -> view, CraftWindow.LevelView(ctx) -> { Text, Bar, Fraction }
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local L10n = require(Shared:WaitForChild("L10n"))

local CraftWindow = {}
local C = nil
local TAG = "CraftWindow"
local LocalPlayer = Players.LocalPlayer

-- player text (A23-130: short; A23-111: keys "CraftWindow.TXT.<field>"); the refusals are Config.Craft.Text
local TXT = {
	Title = "Crafting",
	Menu = "Crafting",
	Make = { Smith = "Forge", Alch = "Brew", Tame = "Make" }, -- the start button per role
	Level = "%s Lv %d",
	XP = "%s / %s",
	Max = "Max",
	NeedLv = "Lv %d",
	Attack = "Attack %s",
	UseFrom = "Use from Lv %d",
	Count = "×%d",
	Have = "%s / %s",
	GainXP = "+%d craft XP",
	Made = "Made %d",
	Checking = "Checking…",
	None = "Nothing to make yet.",
}
L10n.Register("CraftWindow.TXT", TXT)

-- layout (du = MainGui units) and fixed rules
local L = {
	Window = "Craft",
	Pad = 18, -- Panels FRAME.Pad (window rim -> content, each side)
	ListW = 270, DetailW = 240, Split = 12, -- UiSandbox 10/12: 250 cut "Goblin Thief's…" (names wrap to 2 lines now)
	HeadH = 36, BarH = 40, RowGap = 8,
	RowH = 62, RowSlot = 52, RowSpace = 6, RowRight = 54, -- the row's right column: "Lv N" over the ready check
	Big = 84, MatSlot = 36, MatH = 40, CountW = 72, BtnH = 44, CoinW = 26, XPBarW = 150, XPBarH = 22, CheckW = 20,
	Size = { Name = 19, Row = 17, Body = 16, Small = 15 },
	Inner = { X = 76 / 512, Y = 80 / 512, W = 360 / 512, H = 356 / 512 }, -- the slot parts' icon box (BagUI L.Inner)
	Slot = { Common = "SlotCommon", Fine = "SlotUncommon", Rare = "SlotRare", Epic = "SlotEpic", Legend = "SlotLegendary",
		Mythic = "SlotLegendary" },
	-- the refusals in the server's order (CraftService.TryStart) that the client can see
	Reasons = { "NotArtisan", "Auto", "Far", "NeedLevel", "NeedMats", "NeedGold" },
	GapMargin = 0.15, -- s over Config.RateLimits.CraftStart (the server drops a 2nd start inside it without a reply)
	PendingTimeout = 3, -- s without CraftSession -> the start stops waiting (a refusal came as a notice)
	Poll = 0.25, -- s: the ring watch (reopen after it)
	Anvil = { "Map", "Landmarks", "ArtisanGuild", "Anvil" }, -- the server's fallback bench (ShopService.Anvil)
	Prompt = "CraftPrompt", ActionKey = "ActionKey", ObjectKey = "ObjectKey", -- the bench's prompt (CraftService)
}

-- state: Info = the last CraftInfo (validated); Sel = the picked recipe id; Await = a start sent { Id, At, Phase =
-- "sent" | "ring" } (the ring screen opened -> this window comes back after it); ReadyAt = os.clock() of the next start
local S = { Ready = false, Info = nil, InfoVer = 0, Sel = nil, Await = nil, ReadyAt = 0, LastArg = nil, Started = false,
	Stations = {} } -- [bench part] = its ChildAdded connection (the prompt the server adds)
local VIEW = {} -- the open window: Kit, Parent, Head, Body, Bottom, List, Detail, Sig

---------------------------------------------------------------------------------------------------- small helpers
local function num(v, d)
	v = tonumber(v)
	if v == nil or v ~= v or v == math.huge or v == -math.huge then return d end
	return v
end

local function attr(name, d)
	local v = LocalPlayer and LocalPlayer:GetAttribute(name)
	if v == nil then return d end
	return v
end

local function tx(t, key, ...)
	local ui = C and C.UIKit
	if type(ui) == "table" and type(ui.Tx) == "function" then
		local ok, s = pcall(ui.Tx, t, key, ...)
		if ok and type(s) == "string" then return s end
	end
	local s = t[key .. "En"] or t[key]
	if type(s) ~= "string" then return "" end
	if select("#", ...) > 0 then
		local ok, out = pcall(string.format, s, ...)
		return ok and out or s
	end
	return s
end

local function gradeDef(id)
	return Config.WeaponGrades[id] or Config.WeaponGrades.Common
end

local function weaponGradeId(tier)
	local info = Config.WeaponInfo[tier]
	return (info and Config.WeaponGrades[info.Grade]) and info.Grade or "Common"
end

---------------------------------------------------------------------------------------------------- the model (pure)
-- my craft role: an artisan (faction Neutral, class chosen) -> Config.Craft.Roles[class]; else nil (CraftService.roleOf)
function CraftWindow.RoleOf(ctx)
	ctx = type(ctx) == "table" and ctx or {}
	if ctx.Faction ~= "Neutral" or ctx.ClassChosen ~= true then return nil end
	return Config.Craft.Roles[ctx.Class]
end

-- my craft level / XP / XP to the next (CraftInfo when it is for my role; Lv 1 before it came)
local function levelOf(ctx, role)
	local info = type(ctx.Info) == "table" and ctx.Info or {}
	if info.Role ~= role then return 1, 0, Config.CraftXPToNext(1) end
	local lv = math.clamp(math.floor(num(info.Lv, 1)), 1, Config.Craft.MaxLv)
	return lv, math.max(0, math.floor(num(info.XP, 0))), math.max(0, math.floor(num(info.Need, Config.CraftXPToNext(lv))))
end

local function onList(info, id)
	local on = type(info) == "table" and info.On or nil
	if type(on) ~= "table" then return true end -- the server did not say: every recipe the client can read
	return on[id] == true or table.find(on, id) ~= nil
end

-- the materials in Config.Loot.Order (then by id), each { Id, Need, Have, Name, Color, Short }
local function matsOf(r, items)
	local order = Config.Loot.Order or {}
	local list = {}
	for item, n in r.Mats do
		local def = Config.Loot.Items[item]
		local need = math.max(0, math.floor(num(n, 0)))
		local have = math.max(0, math.floor(num(items[item], 0)))
		table.insert(list, { Id = item, Need = need, Have = have, Name = tx(def, "Name"), Color = def.Color, Short = have < need,
			Rank = table.find(order, item) or 1e6 })
	end
	table.sort(list, function(a, b)
		if a.Rank ~= b.Rank then return a.Rank < b.Rank end
		return a.Id < b.Id
	end)
	return list
end

-- one recipe as the window shows it, or nil when it can't be shown (a material / result the client doesn't know; Gear
-- has no names yet, A23-133: those rows come with the gear data)
local function entryOf(id, r, ctx, lv, made)
	if type(r.Mats) ~= "table" then return nil end
	for item in r.Mats do
		if not Config.Loot.Items[item] then return nil end
	end
	local e = { Id = id, Kind = r.Kind, Lv = math.max(1, math.floor(num(r.Lv, 1))), Gold = math.max(0, math.floor(num(r.Gold, 0))),
		XP = math.max(0, math.floor(num(r.XP, 0))), Made = math.max(0, math.floor(num(made[id], 0))), N = 1 }
	if r.Kind == "Weapon" then
		local tier = math.floor(num(r.Tier, 0))
		if not Config.Weapons[tier] then return nil end
		e.Tier, e.Grade = tier, weaponGradeId(tier)
		e.Name = Config.WeaponName(tier, ctx.Class, ctx.Faction)
		e.Icon = Config.WeaponArtKey(tier, ctx.Class, ctx.Faction)
		e.Color = gradeDef(e.Grade).Color
	elseif r.Kind == "Item" then
		local def = type(r.Item) == "string" and Config.Loot.Items[r.Item] or nil
		if not def then return nil end
		e.Item, e.N = r.Item, math.max(1, math.floor(num(r.N, 1)))
		e.Grade = (type(def.Grade) == "string" and Config.WeaponGrades[def.Grade]) and def.Grade or "Common"
		e.Name, e.Icon, e.Color = tx(def, "Name"), r.Item, def.Color or gradeDef(e.Grade).Color
	else
		return nil
	end
	local items = type(ctx.Items) == "table" and ctx.Items or {}
	e.Mats = matsOf(r, items)
	e.MatsShort = false
	for _, m in e.Mats do
		if m.Short then e.MatsShort = true end
	end
	e.GoldShort = math.max(0, math.floor(num(ctx.Gold, 0))) < e.Gold
	e.Locked = lv < e.Lv
	e.Ready = not e.Locked and not e.MatsShort and not e.GoldShort
	return e
end

-- my role's recipes, lowest craft level first (then tier, id). ctx = { Faction, Class, ClassChosen, Items, Gold, Info }
function CraftWindow.Entries(ctx)
	ctx = type(ctx) == "table" and ctx or {}
	local role = CraftWindow.RoleOf(ctx)
	local out = {}
	if not role then return out end
	local lv = levelOf(ctx, role)
	local info = type(ctx.Info) == "table" and ctx.Info or {}
	local made = type(info.Made) == "table" and info.Made or {}
	for id, r in Config.Craft.Recipes do
		if type(id) == "string" and type(r) == "table" and r.Role == role and onList(info, id) then
			local e = entryOf(id, r, ctx, lv, made)
			if e then table.insert(out, e) end
		end
	end
	table.sort(out, function(a, b)
		if a.Lv ~= b.Lv then return a.Lv < b.Lv end
		if (a.Tier or 0) ~= (b.Tier or 0) then return (a.Tier or 0) < (b.Tier or 0) end
		return a.Id < b.Id
	end)
	return out
end

-- why a start would be refused, in the server's order (the client can't see Busy / Full: those come as notices).
-- ctx.Auto = auto combat on, ctx.Far = a bench is in sight and too far
function CraftWindow.Reason(e, ctx)
	ctx = type(ctx) == "table" and ctx or {}
	local why = {
		NotArtisan = CraftWindow.RoleOf(ctx) == nil or type(e) ~= "table",
		Auto = ctx.Auto == true,
		Far = ctx.Far == true,
		NeedLevel = type(e) == "table" and e.Locked == true,
		NeedMats = type(e) == "table" and e.MatsShort == true,
		NeedGold = type(e) == "table" and e.GoldShort == true,
	}
	for _, key in L.Reasons do
		if why[key] then return key end
	end
	return nil
end

-- the header: "Blacksmith Lv 3" and the XP bar ("120 / 250", "Max" at MaxLv)
function CraftWindow.LevelView(ctx)
	ctx = type(ctx) == "table" and ctx or {}
	local role = CraftWindow.RoleOf(ctx)
	if not role then return nil end
	local lv, xp, need = levelOf(ctx, role)
	local cls = Config.Classes[ctx.Class] or Config.Classes.Warrior
	local name = tx(cls.Names, "Neutral") -- the artisan class name (Blacksmith / Alchemist / Pet Tamer)
	if lv >= Config.Craft.MaxLv or need <= 0 then
		return { Text = tx(TXT, "Level", name, lv), Bar = tx(TXT, "Max"), Fraction = 1 }
	end
	return { Text = tx(TXT, "Level", name, lv), Bar = tx(TXT, "XP", Util.FormatInt(xp), Util.FormatInt(need)),
		Fraction = math.clamp(xp / need, 0, 1) }
end

-- the detail column of a recipe. ctx += { Level (hunting), Pending (a start waiting), Gap (the start's interval) }
function CraftWindow.Detail(e, ctx)
	ctx = type(ctx) == "table" and ctx or {}
	-- Lines above the cost (attack, the level to use it), Notes below it (craft XP, how many made)
	local view = { Lines = {}, Mats = {}, Notes = {} }
	local function line(text, color) table.insert(view.Lines, { Text = text, Color = color }) end
	local function note(text) table.insert(view.Notes, { Text = text, Color = "Sub" }) end
	local role = CraftWindow.RoleOf(ctx)
	if not role then
		view.Status = { Text = tx(Config.Craft.Text, "NotArtisan"), Color = "Bad" }
		return view
	end
	if type(e) ~= "table" then
		view.Status = { Text = tx(TXT, "None"), Color = "Sub" }
		return view
	end
	local g = gradeDef(e.Grade)
	view.Title, view.Icon, view.Grade, view.Color = e.Name, e.Icon, e.Grade, e.Color
	view.Count = e.N > 1 and e.N or nil
	view.Sub = string.rep("★", g.Stars or 1) .. " " .. tx(g, "Name")
	view.SubColor = g.Color
	local level = math.max(1, math.floor(num(ctx.Level, 1)))
	if e.Kind == "Weapon" then
		line(tx(TXT, "Attack", Util.FormatInt(math.floor(Config.WeaponDamage(e.Tier, level, 0)))))
		if not Config.WeaponUsable(e.Tier, level) then
			line(tx(TXT, "UseFrom", math.floor(num(Config.Weapons[e.Tier].MinLevel, 1))), "Sub")
		end
	end
	for _, m in e.Mats do
		table.insert(view.Mats, { Id = m.Id, Name = m.Name, Color = m.Color, Text = tx(TXT, "Have", Util.FormatInt(m.Have),
			Util.FormatInt(m.Need)), Short = m.Short })
	end
	view.Gold = { Text = Util.FormatInt(e.Gold), Short = e.GoldShort }
	local lv = levelOf(ctx, role)
	if lv < Config.Craft.MaxLv and e.XP > 0 then note(tx(TXT, "GainXP", e.XP)) end
	if e.Made > 0 then note(tx(TXT, "Made", e.Made)) end
	local why = CraftWindow.Reason(e, ctx)
	if why then view.Status = { Text = tx(Config.Craft.Text, why), Color = "Bad" } end
	local text = tx(TXT.Make, role)
	if text == "" then text = tx(TXT.Make, "Smith") end
	if ctx.Pending then
		view.Action = { Text = tx(TXT, "Checking"), Enabled = false }
	else
		view.Action = { Text = text, Enabled = why == nil and ctx.Gap ~= true }
	end
	return view
end

---------------------------------------------------------------------------------------------------- data
-- s->c CraftInfo { Role, Lv, XP, Need, Made = { [recipeId] = n }, On? = { recipeIds } | { [recipeId] = true } }
function CraftWindow.OnInfo(payload)
	if type(payload) ~= "table" or type(payload.Role) ~= "string" then return end
	local made = {}
	for id, n in type(payload.Made) == "table" and payload.Made or {} do
		if type(id) == "string" and num(n, 0) >= 1 then made[id] = math.floor(n) end
	end
	local on = nil
	if type(payload.On) == "table" then
		on = {}
		for k, v in payload.On do
			if type(v) == "string" then on[v] = true elseif type(k) == "string" and v == true then on[k] = true end
		end
	end
	local lv = math.clamp(math.floor(num(payload.Lv, 1)), 1, Config.Craft.MaxLv)
	S.Info = { Role = payload.Role, Lv = lv, XP = math.max(0, math.floor(num(payload.XP, 0))),
		Need = math.max(0, math.floor(num(payload.Need, Config.CraftXPToNext(lv)))), Made = made, On = on }
	S.InfoVer += 1
	if VIEW.Kit then CraftWindow.Redraw() end
end

local function items()
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.LastInventory) ~= "function" then return {} end
	local ok, payload = pcall(panels.LastInventory)
	return (ok and type(payload) == "table" and type(payload.Items) == "table") and payload.Items or {}
end

local function part(root, path)
	local node = root
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	return node
end

-- a bench of my role in sight and farther than Config.Craft.Range (the server's nearest CraftStation with my Role, else
-- the Crossroads anvil); nothing in sight = not far (the server decides)
local function far(role)
	local okRoot, root = pcall(Util.GetRoot, LocalPlayer)
	if not okRoot or not root then return false end
	local best = nil
	local ok, list = pcall(function() return CollectionService:GetTagged(Config.Craft.StationTag) end)
	for _, p in ok and list or {} do
		if p:IsA("BasePart") and p:GetAttribute("Role") == role then
			local d = (p.Position - root.Position).Magnitude
			if not best or d < best then best = d end
		end
	end
	if not best then
		local anvil = part(workspace, L.Anvil)
		if anvil and anvil:IsA("BasePart") then best = (anvil.Position - root.Position).Magnitude end
	end
	return best ~= nil and best > Config.Craft.Range
end

local function pending()
	return S.Await ~= nil and S.Await.Phase == "sent"
end

local function context()
	local class = attr("Class")
	local ctx = { Faction = attr("Faction"), ClassChosen = attr("ClassChosen") == true,
		Class = (type(class) == "string" and Config.Classes[class]) and class or "Warrior", Items = items(),
		Gold = math.max(0, num(attr("BankGold"), 0)) + math.max(0, num(attr("CarriedGold"), 0)), Info = S.Info,
		Level = num(attr("Level"), 1),
		Auto = attr("AutoCombatUnlocked") == true and attr("AutoCombatEnabled") == true,
		Pending = pending(), Gap = os.clock() < S.ReadyAt }
	local role = CraftWindow.RoleOf(ctx)
	ctx.Far = role ~= nil and far(role)
	return ctx
end

-- artisans while crafting is on (the menu entry)
function CraftWindow.CanOpen()
	if not (type(Config.Features) == "table" and Config.Features.Crafting == true) then return false end
	return CraftWindow.RoleOf({ Faction = attr("Faction"), ClassChosen = attr("ClassChosen") == true, Class = attr("Class") }) ~= nil
end

---------------------------------------------------------------------------------------------------- drawing
local function ui() return C and C.UIKit end

local function label(parent, text, size, color, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = VIEW.Kit and VIEW.Kit.Font or Enum.Font.GothamMedium
	l.TextSize = size
	l.TextColor3 = color
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	for k, v in props or {} do
		if k ~= "Style" then l[k] = v end
	end
	l.Parent = parent
	local kit = ui()
	if props and props.Style == false then
		-- a tight caption scaled down to fit its box, at most `size` (UiSandbox 10/12: the styled text floor made
		-- "Lv 20" run into the name and cut "Rusty Knight Crest")
		l.TextScaled = true
		local tc = Instance.new("UITextSizeConstraint")
		tc.MaxTextSize = size
		tc.Parent = l
		return l
	end
	if type(kit) == "table" and type(kit.StyleText) == "function" then
		pcall(kit.StyleText, l, (props and props.Style) or "Body")
		l.TextColor3 = color
	end
	return l
end

local function colorOf(name)
	local kit = VIEW.Kit
	local th = kit and kit.Theme or {}
	if name == "Gold" then return th.Gold end
	if name == "Good" then return th.Good end
	if name == "Bad" then return th.Bad end
	if name == "Sub" then return th.SubText end
	return th.Text
end

-- one approved grade slot with the icon in its Inner box (the bag's look); no icon art = the name's first letter
local function slot(parent, gradeId, icon, size, name, mark)
	local kit = ui()
	local box = kit.ArtFrame(gradeId and L.Slot[gradeId] or "SlotEmpty", { Name = name or "Slot", Size = UDim2.fromOffset(size, size),
		Parent = parent }, { BackgroundColor3 = Color3.fromRGB(16, 20, 40), CornerRadius = UDim.new(0, 10),
		StrokeColor = gradeId and gradeDef(gradeId).Color or Color3.fromRGB(60, 66, 96), StrokeThickness = 2 })
	if icon then
		local props = { Name = "Icon", Position = UDim2.fromScale(L.Inner.X, L.Inner.Y), Size = UDim2.fromScale(L.Inner.W, L.Inner.H),
			ScaleType = Enum.ScaleType.Fit, ZIndex = (tonumber(box.ZIndex) or 1) + 1 }
		local img = kit.ItemIcon(icon, props)
		if img then
			img.Parent = box
		elseif type(mark) == "table" and type(mark.Text) == "string" then
			label(box, string.upper(string.match(mark.Text, "%w") or "?"), math.floor(size * 0.42),
				typeof(mark.Color) == "Color3" and mark.Color or Color3.new(1, 1, 1), { Name = "Letter", AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(L.Inner.W, L.Inner.H),
					TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, ZIndex = props.ZIndex, Style = "Number" })
		end
	end
	return box
end

local function rim(box)
	local f = Instance.new("Frame")
	f.Name = "Picked"
	f.BackgroundTransparency = 1
	f.Position = UDim2.fromOffset(1, 1)
	f.Size = UDim2.new(1, -2, 1, -2)
	f.ZIndex = (tonumber(box.ZIndex) or 1) + 4
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = f
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = colorOf("Gold")
	st.Thickness = 3
	st.Parent = f
	f.Parent = box
end

local function clear(frame)
	if not frame then return end
	for _, ch in frame:GetChildren() do
		if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
	end
end

local function listLayout(frame, gap, center)
	local list = frame:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, gap)
	if center then list.HorizontalAlignment = Enum.HorizontalAlignment.Center end
	list.Parent = frame
	return list
end

local function drawHead(head, ctx)
	clear(head)
	local v = CraftWindow.LevelView(ctx)
	if not v then return end
	label(head, v.Text, L.Size.Name, colorOf("Gold"), { Name = "Level", AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, -(L.XPBarW + 10), 1, 0), TextWrapped = false, Style = "Title" })
	local kit = ui()
	local ok, bar, set = pcall(kit.ArtBar, { Name = "XPBar", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(L.XPBarW, L.XPBarH), Text = v.Bar, TextSize = L.Size.Small, Parent = head })
	if ok and type(set) == "function" then set(v.Fraction) end
	VIEW.XPBar = ok and bar or nil
end

local function drawRow(list, e, i)
	local row = Instance.new("TextButton")
	row.Name = "Row_" .. e.Id
	row.Text = ""
	row.AutoButtonColor = false
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, L.RowH)
	row.LayoutOrder = i
	row.Parent = list
	row.Activated:Connect(function() CraftWindow.Pick(e.Id) end)
	local z = (tonumber(row.ZIndex) or 1) + 1
	local box = slot(row, e.Grade, e.Icon, L.RowSlot, "Slot", { Text = e.Name, Color = e.Color })
	box.Position = UDim2.fromOffset(5, (L.RowH - L.RowSlot) / 2)
	if e.Locked then
		local icon = box:FindFirstChild("Icon")
		if icon then icon.ImageTransparency = 0.5 end
	end
	-- the name in up to two lines next to the slot (UiSandbox 10/12: one line cut every long weapon name), the level and
	-- the ready check in a narrow column on the right
	local x = L.RowSlot + 12
	label(row, e.Name, L.Size.Row, e.Color or colorOf("Text"), { Name = "Name", Position = UDim2.fromOffset(x, 4),
		Size = UDim2.new(1, -(x + L.RowRight), 1, -8), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = z })
	label(row, tx(TXT, "NeedLv", e.Lv), L.Size.Small, e.Locked and colorOf("Bad") or colorOf("Sub"), { Name = "Lv",
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 8), Size = UDim2.fromOffset(L.RowRight - 8, 18),
		TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, ZIndex = z, Style = false })
	if e.Ready then
		local check = ui().ArtImage("GlyphCheck", { Name = "Ready", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -8),
			Size = UDim2.fromOffset(L.CheckW, L.CheckW), ImageColor3 = colorOf("Gold"), ZIndex = z })
		if check then check.Parent = row end
	end
	if e.Id == S.Sel then rim(row) end
	return row
end

local function matRow(frame, m, order)
	local row = Instance.new("Frame")
	row.Name = "Mat_" .. m.Id
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, L.MatH)
	row.LayoutOrder = order
	row.Parent = frame
	local box = slot(row, nil, m.Id, L.MatSlot, "Slot", { Text = m.Name, Color = m.Color })
	box.AnchorPoint = Vector2.new(0, 0.5)
	box.Position = UDim2.new(0, 0, 0.5, 0)
	-- UiSandbox 10/12: "Copper…" / "Rusty…" were cut and "5 / 30" ran under the scroll bar: the name wraps, the count
	-- has its own column
	label(row, m.Name, L.Size.Small, colorOf("Text"), { Name = "Name", AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, L.MatSlot + 8, 0.5, 0), Size = UDim2.new(1, -(L.MatSlot + 8 + L.CountW + 4), 1, -4), Style = false })
	label(row, m.Text, L.Size.Body, m.Short and colorOf("Bad") or colorOf("Good"), { Name = "Count", AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, L.CountW, 1, 0), TextXAlignment = Enum.TextXAlignment.Right,
		TextWrapped = false, Style = "Number" })
end

local function goldRow(frame, gold, order)
	local row = Instance.new("Frame")
	row.Name = "Gold"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, L.MatH)
	row.LayoutOrder = order
	row.Parent = frame
	local coin = ui().ArtImage("IconCoin", { Name = "Coin", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 5, 0.5, 0),
		Size = UDim2.fromOffset(L.CoinW, L.CoinW) })
	if coin then coin.Parent = row end
	label(row, gold.Text, L.Size.Body, gold.Short and colorOf("Bad") or colorOf("Gold"), { Name = "Cost", AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(1, -(L.MatSlot + 8), 1, 0), TextXAlignment = Enum.TextXAlignment.Right,
		TextWrapped = false, Style = "Number" })
end

local function drawDetail(frame, e, ctx)
	clear(frame)
	local kit = VIEW.Kit
	local view = CraftWindow.Detail(e, ctx)
	listLayout(frame, 6, true)
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	if view.Title then
		local big = slot(frame, view.Grade, view.Icon, L.Big, "Big", { Text = view.Title, Color = view.Color })
		big.LayoutOrder = nextOrder()
		if view.Count then
			label(big, tostring(view.Count), L.Size.Body, Color3.new(1, 1, 1), { Name = "Count", AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -4, 1, -1), Size = UDim2.new(1, -8, 0, 18), TextXAlignment = Enum.TextXAlignment.Right,
				TextWrapped = false, ZIndex = (tonumber(big.ZIndex) or 1) + 3, Style = "Number" })
		end
		label(frame, view.Title, L.Size.Name, view.Color or colorOf("Text"), { Name = "Name", Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = nextOrder(), Style = "Title" })
		label(frame, view.Sub, L.Size.Small, view.SubColor or colorOf("Sub"), { Name = "Grade", Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = nextOrder() })
	end
	for i, ln in view.Lines do
		label(frame, ln.Text, ln.Color == "Sub" and L.Size.Small or L.Size.Body, colorOf(ln.Color), { Name = "Line" .. i,
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = nextOrder() })
	end
	for _, m in view.Mats do matRow(frame, m, nextOrder()) end
	if view.Gold then goldRow(frame, view.Gold, nextOrder()) end
	for i, ln in view.Notes do
		label(frame, ln.Text, L.Size.Small, colorOf(ln.Color), { Name = "Note" .. i, Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = nextOrder() })
	end
	if view.Status then
		label(frame, view.Status.Text, L.Size.Body, colorOf(view.Status.Color), { Name = "Status", Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = nextOrder() })
	end
	if view.Action and type(e) == "table" then
		local palette = kit.Palette or {}
		local id = e.Id
		local b = kit.Button(frame, view.Action.Text, palette.Buy or palette.Button, UDim2.new(1, 0, 0, L.BtnH), function()
			CraftWindow.Forge(id)
		end)
		b.Name = "Forge"
		b.LayoutOrder = nextOrder()
		kit.SetEnabled(b, view.Action.Enabled)
	end
	return view
end

local function drawBottom(bottom)
	clear(bottom)
	local kit = ui()
	local gold = math.max(0, math.floor(num(attr("BankGold"), 0) + num(attr("CarriedGold"), 0)))
	local coin = kit.ArtImage("IconCoin", { Name = "Coin", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(L.CoinW, L.CoinW) })
	if coin then coin.Parent = bottom end
	label(bottom, Util.FormatInt(gold), L.Size.Body, colorOf("Gold"), { Name = "Gold", AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, L.CoinW + 6, 0.5, 0), Size = UDim2.new(0.5, 0, 1, 0), TextWrapped = false, Style = "Number" })
end

-- what the window shows depends on (the redraw signature: the update redraws when it changes)
local function sigOf(ctx, list)
	local parts = { tostring(ctx.Faction), tostring(ctx.Class), tostring(ctx.ClassChosen), S.InfoVer, ctx.Gold, ctx.Level,
		tostring(ctx.Auto), tostring(ctx.Far), tostring(ctx.Pending), tostring(ctx.Gap), tostring(S.Sel) }
	for _, e in list do
		table.insert(parts, e.Id)
		for _, m in e.Mats do table.insert(parts, m.Have) end
	end
	return table.concat(parts, "|")
end

function CraftWindow.Redraw()
	local body = VIEW.Body
	if not (VIEW.Kit and body and body.Parent) then return end
	local keptY = VIEW.List and VIEW.List.Parent and VIEW.List.CanvasPosition.Y or 0
	local ctx = context()
	local list = CraftWindow.Entries(ctx)
	local picked = nil
	for _, e in list do
		if e.Id == S.Sel then picked = e end
	end
	if not picked then
		for _, e in list do
			if e.Ready then picked = e break end
		end
		picked = picked or list[1]
		S.Sel = picked and picked.Id or nil
	end
	VIEW.Sig = sigOf(ctx, list)
	if VIEW.Head then drawHead(VIEW.Head, ctx) end
	clear(body)
	VIEW.List, VIEW.Detail = nil, nil
	if VIEW.Bottom then drawBottom(VIEW.Bottom) end
	if #list == 0 then
		-- nothing to list (not an artisan, no recipe yet): one line in the middle (UiSandbox 10/12: it sat in the right
		-- column of an empty window)
		local view = CraftWindow.Detail(nil, ctx)
		local st = view.Status or { Text = tx(TXT, "None"), Color = "Sub" }
		label(body, st.Text, L.Size.Body, colorOf(st.Color), { Name = "Status", AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.3, 0), Size = UDim2.new(0.8, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			TextXAlignment = Enum.TextXAlignment.Center })
		return
	end
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "List"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.new(0, L.ListW, 1, 0)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ScrollBarThickness = 6
	scroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	scroll.Parent = body
	listLayout(scroll, L.RowSpace, false)
	VIEW.List = scroll
	for i, e in list do drawRow(scroll, e, i) end
	scroll.CanvasPosition = Vector2.new(0, keptY)
	local detail = Instance.new("ScrollingFrame")
	detail.Name = "Detail"
	detail.BackgroundTransparency = 1
	detail.BorderSizePixel = 0
	detail.Position = UDim2.fromOffset(L.ListW + L.Split, 0)
	detail.Size = UDim2.new(1, -(L.ListW + L.Split), 1, 0)
	detail.CanvasSize = UDim2.new()
	detail.AutomaticCanvasSize = Enum.AutomaticSize.Y
	detail.ScrollingDirection = Enum.ScrollingDirection.Y
	detail.ScrollBarThickness = 4
	detail.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar -- the counts never sit under the bar (UiSandbox 10/12)
	detail.Parent = body
	VIEW.Detail = detail
	drawDetail(detail, picked, ctx)
end

function CraftWindow.Pick(id)
	if type(id) ~= "string" or id == S.Sel then return end
	S.Sel = id
	CraftWindow.Redraw()
end

-- [Forge]: c->s CraftStart(recipeId) once per interval while nothing waits and the client sees no reason against it
function CraftWindow.Forge(id)
	local kit = VIEW.Kit
	local now = os.clock()
	if not kit or S.Await or now < S.ReadyAt then return false end
	local ctx = context()
	local e = nil
	for _, x in CraftWindow.Entries(ctx) do
		if x.Id == id then e = x end
	end
	if not e or CraftWindow.Reason(e, ctx) then return false end
	kit.Fire("CraftStart", id)
	S.ReadyAt = now + math.max(0, num(Config.RateLimits.CraftStart, 3)) + L.GapMargin
	S.Await = { Id = id, At = now, Phase = "sent" }
	CraftWindow.Redraw()
	return true
end

-- the start's answer: the ring screen opened (-> after it closes, this window opens again on the recipe) or nothing
-- came (a refusal: its notice is on screen; the button comes back)
function CraftWindow.Watch()
	local a = S.Await
	if not a then return end
	local view = C and C.CraftView
	local ok, open = false, false
	if type(view) == "table" and type(view.IsOpen) == "function" then ok, open = pcall(view.IsOpen) end
	open = ok and open == true
	if a.Phase == "sent" then
		if open then
			a.Phase = "ring"
		elseif os.clock() - a.At >= L.PendingTimeout then
			S.Await = nil
			if VIEW.Kit then CraftWindow.Redraw() end
		end
	elseif not open then
		S.Await = nil
		local panels = C and C.Panels
		if type(panels) ~= "table" or type(panels.Open) ~= "function" then return end
		local okOpen, busy = pcall(function() return type(panels.IsOpen) == "function" and panels.IsOpen() end)
		if okOpen and not busy and Util.IsAlive(LocalPlayer) then pcall(panels.Open, L.Window, { Select = a.Id }) end
	end
end

local function build(parent, kit, arg)
	VIEW = { Kit = kit, Parent = parent }
	-- Panels hands every rebuild the arg of its last Open: one arg table is applied once
	if arg == S.LastArg then arg = nil else S.LastArg = arg end
	if type(arg) == "table" and type(arg.Select) == "string" and Config.Craft.Recipes[arg.Select] then S.Sel = arg.Select end
	local head = Instance.new("Frame")
	head.Name = "Head"
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, L.HeadH)
	head.Parent = parent
	VIEW.Head = head
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, L.HeadH + L.RowGap)
	body.Size = UDim2.new(1, 0, 1, -(L.HeadH + L.BarH + 2 * L.RowGap))
	body.Parent = parent
	VIEW.Body = body
	local bottom = Instance.new("Frame")
	bottom.Name = "Bottom"
	bottom.BackgroundTransparency = 1
	bottom.AnchorPoint = Vector2.new(0, 1)
	bottom.Position = UDim2.new(0, 0, 1, 0)
	bottom.Size = UDim2.new(1, 0, 0, L.BarH)
	bottom.Parent = parent
	VIEW.Bottom = bottom
	kit.OnAttr(function(name)
		if not CraftWindow.Watched[name] or VIEW.Queued then return end
		VIEW.Queued = true
		task.defer(function()
			VIEW.Queued = false
			if VIEW.Kit == kit then CraftWindow.Redraw() end
		end)
	end)
	CraftWindow.Redraw()
	-- Panels' 0.25 s update: new materials (the Inventory push), the distance to the bench, the start's wait / interval
	return function()
		if VIEW.Kit ~= kit then return end
		local ctx = context()
		if sigOf(ctx, CraftWindow.Entries(ctx)) ~= VIEW.Sig then CraftWindow.Redraw() end
	end
end

-- attributes that redraw the open window
CraftWindow.Watched = { Faction = true, Class = true, ClassChosen = true, Level = true, BankGold = true, CarriedGold = true,
	AutoCombatEnabled = true, AutoCombatUnlocked = true }

local function cleanup()
	VIEW = {}
end

local function hook(name, fn)
	local function on(r)
		r.OnClientEvent:Connect(function(payload)
			local ok, err = pcall(fn, payload)
			if not ok then Util.Warn(TAG, name .. ": " .. tostring(err)) end
		end)
	end
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local r = folder and folder:FindFirstChild(name)
	if r and r:IsA("RemoteEvent") then
		on(r)
		return
	end
	task.spawn(function()
		local f = ReplicatedStorage:WaitForChild("Remotes", 60)
		local rr = f and f:WaitForChild(name, 60)
		if rr and rr:IsA("RemoteEvent") then on(rr) end -- no remote = crafting is off on this server
	end)
end

---------------------------------------------------------------------------------------------------- workbench prompts
-- the prompt's two words from its keys (a missing / empty / unknown key = no word; GatherView.Words' rule)
function CraftWindow.Words(actionKey, objectKey, language)
	local function word(key)
		if type(key) ~= "string" or key == "" then return "" end
		local ok, out = pcall(L10n.T, key, nil, language)
		if not ok or type(out) ~= "string" or out == key then return "" end -- an unknown key comes back as itself
		return out
	end
	return word(actionKey), word(objectKey)
end

local function lang()
	local ui = C and C.UIKit
	if type(ui) == "table" and type(ui.Lang) == "function" then
		local ok, l = pcall(ui.Lang)
		if ok and (l == "ko" or l == "en") then return l end
	end
	local ok, l = pcall(L10n.LangOf, LocalPlayer)
	return ok and l or "en"
end

-- one workbench: its prompt's words, and the prompt only for an artisan of the bench's role (another player would only
-- get the NotArtisan notice from it)
local function applyStation(part)
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") then return end
	local prompt = part:FindFirstChild(L.Prompt)
	if not (prompt and prompt:IsA("ProximityPrompt")) then return end
	local action, object = CraftWindow.Words(prompt:GetAttribute(L.ActionKey), prompt:GetAttribute(L.ObjectKey), lang())
	if action ~= "" and prompt.ActionText ~= action then prompt.ActionText = action end
	if object ~= "" and prompt.ObjectText ~= object then prompt.ObjectText = object end
	local mine = CraftWindow.RoleOf({ Faction = attr("Faction"), ClassChosen = attr("ClassChosen") == true, Class = attr("Class") })
	local show = mine ~= nil and mine == part:GetAttribute("Role")
	if prompt.Enabled ~= show then prompt.Enabled = show end
end

-- every workbench again (my faction / class or the language changed)
function CraftWindow.RefreshStations()
	local ok, list = pcall(function() return CollectionService:GetTagged(Config.Craft.StationTag) end)
	for _, part in ok and list or {} do
		local okPart, err = pcall(applyStation, part)
		if not okPart then Util.Warn(TAG, "station: " .. tostring(err)) end
	end
end

-- a bench that streams in / is tagged later, and its prompt that the server adds after the tag
local function watchStation(part)
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") or S.Stations[part] then return end
	S.Stations[part] = part.ChildAdded:Connect(function(child)
		if child.Name == L.Prompt then pcall(applyStation, part) end
	end)
	pcall(applyStation, part)
end

local function watchStations()
	local tag = Config.Craft.StationTag
	local ok, list = pcall(function() return CollectionService:GetTagged(tag) end)
	for _, part in ok and list or {} do watchStation(part) end
	pcall(function()
		CollectionService:GetInstanceAddedSignal(tag):Connect(watchStation)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(part)
			local conn = S.Stations[part]
			if conn then pcall(function() conn:Disconnect() end) end
			S.Stations[part] = nil
		end)
	end)
	for name in CraftWindow.RoleAttrs do
		LocalPlayer:GetAttributeChangedSignal(name):Connect(CraftWindow.RefreshStations)
	end
	local ui = C and C.UIKit
	if type(ui) == "table" and ui.LangChanged and type(ui.LangChanged.Connect) == "function" then
		ui.LangChanged:Connect(CraftWindow.RefreshStations)
	end
end

-- the attributes that decide my craft role (the prompts follow them)
CraftWindow.RoleAttrs = { Faction = true, Class = true, ClassChosen = true }

function CraftWindow.IsReady()
	return S.Ready
end

-- opens the window (on a recipe)
function CraftWindow.Open(id)
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.Open) ~= "function" then return end
	panels.Open(L.Window, type(id) == "string" and { Select = id } or nil)
end

function CraftWindow.Init(registry)
	C = registry
	hook("CraftInfo", CraftWindow.OnInfo) -- before any Start: the join's CraftInfo is never missed
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.Register) ~= "function" then
		Util.Warn(TAG, "Panels.Register is missing; the craft window is off")
		return
	end
	S.Ready = panels.Register(L.Window, {
		Build = build,
		Title = function() return tx(TXT, "Title") end,
		FixedBody = true,
		Rebuild = false,
		Width = function() return 2 * L.Pad + L.ListW + L.Split + L.DetailW end,
		Menu = function() return CraftWindow.CanOpen() and tx(TXT, "Menu") or nil end,
		Cleanup = cleanup,
	}) == true
end

function CraftWindow.Start()
	if S.Started then return end
	S.Started = true
	watchStations()
	task.spawn(function()
		while true do
			task.wait(L.Poll)
			local ok, err = pcall(CraftWindow.Watch)
			if not ok then Util.Warn(TAG, "watch: " .. tostring(err)) end
		end
	end)
end

-- offline tests
CraftWindow._T = { TXT = TXT, L = L, S = S, View = function() return VIEW end }

return CraftWindow
