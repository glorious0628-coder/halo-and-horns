-- Panels.luau : modal panels — Menu, Travel, Rebirth (turncoat), Altar, Class, Shop (tickets), Vacation.
-- Client only. Reads player / GameState attributes, sends intents through RemoteEvents (the server re-validates
-- everything) and prompts Developer Product purchases. One panel at a time; irreversible choices go through
-- UIKit.Confirm. Factions handled: "Halo", "Horns", "Neutral" (playable) and "None" (not chosen yet).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local Panels = {}

local TAG = "Panels"
local player = Players.LocalPlayer

local FACTION_IDS = { "Halo", "Horns", "Neutral" }
local TICKET_ATTR = { Class = "ClassTickets", Faction = "FactionTickets" }
-- attribute changes that change a panel's STRUCTURE (rebuild); everything else is polled by the update loop
local REBUILD_ATTRS = { DataLoaded = true, Faction = true, Class = true, ClassChosen = true, VacationDays = true, HideAnnounceName = true }
local UPDATE_INTERVAL = 0.25
local VACATION_DELAY = 2 -- seconds after both pickers are closed
local WINDOW_MAX_W, WINDOW_MAX_H = 780, 600
local ZINDEX = 50
-- 창 꾸미기 (검수 2026-10-07, user: "이런 화면도 멋있게"): one frame for every window - the navy PanelCard plate (gold rim;
-- the builders' white words stay readable), the RibbonHeader title hanging over its top edge (the window's icon in the
-- ribbon's round disc), the round BtnRound + GlyphClose X always in the top-right corner, the round GlyphBack in the
-- top-left one (only when the window was opened from another), approved button capsules (FRAME.Part) and a height that
-- follows the content (no empty lower half; a long list still scrolls inside the screen). Every part falls back to the
-- old code look when its art is missing (IMG-R4)
local FRAME = {
	Body = "PanelCard", Title = "RibbonHeader", Round = "BtnRound", CloseGlyph = "GlyphClose", BackGlyph = "GlyphBack",
	TitleH = 46, -- du: the ribbon; half of it hangs above the plate
	TitleSize = 24, -- du: its words ("Title" style, >= 16 real px)
	TitleMinW = 220, -- du
	Disc = 0.94, -- the ribbon's round disc + gap: the words start at RibbonHeader Inner 114 / 121 of the height
	RoundSize = 46, -- du: the X / back discs (touch: >= GUARD.TouchTarget real px)
	Pad = 18, -- du: from the plate's rim to the content
	MinH = 190, -- du: the shortest window
	Bottom = 16, -- du: under the content
	Icons = { Menu = "IconSettings", Travel = "IconTravel", Class = "IconClassChange", Rebirth = "IconRebirth",
		Altar = "IconAltar", Items = "IconBag", WeaponShop = "IconHammer", PotionShop = "IconPotionHP", Shop = "IconCoin",
		Vacation = "IconVacation", Settings = "IconSettings", Help = "IconHelp", News = "IconNews", Welcome = "IconNews",
		Story = "IconNews", Diary = "IconDiary", Skills = "IconSkills", Bag = "IconBag", Craft = "IconHammer",
			Character = "IconCharacter" },
	Fit = { H = nil, Queued = false }, -- the last content height the window was fitted to (du)
	RailGap = 8, RailMinRoom = 300, -- du: the window stops this far above the HUD icon row, if it keeps this much height
}
local BODY_FONT = Enum.Font.GothamMedium
local WARN_INTERVAL = 10
-- review R1 tunables
local GUARD = {
	FixedTextMin = 15, -- CR-L40: non-scaled text stays >= 11 real px under a 0.75 phone UIScale
	InputAfterRender = 0.35, -- CR-L26: a fast 2nd tap must not hit the panel that just opened under the finger
	TouchTarget = 44, -- CR-L41: real px of the X / back buttons on touch screens
	TouchGap = 12, -- CR-L41: real px between the X and back buttons on touch screens
}

-- layout rules from Config.UI (addendum A3-H4 / M1)
local UI_CFG = type(Config.UI) == "table" and Config.UI or {}
local MIN_TEXT = type(UI_CFG.MinTextSize) == "number" and UI_CFG.MinTextSize or 11
local TOP_PAD = type(UI_CFG.TopInsetPad) == "number" and UI_CFG.TopInsetPad or 8
local TOP_FALLBACK = type(UI_CFG.TopInsetFallback) == "number" and UI_CFG.TopInsetFallback or 64

-- Neutral faction fallbacks (SPEC_ADDENDUM A6 / A7-4 / A9-1 teal), used only if Config lacks the entries
local NEUTRAL_FALLBACK = {
	Id = "Neutral", Name = "Artisan Guild", Short = "Artisan", Emblem = "A", -- no ⚙ glyph in Gotham
	Color = Color3.fromRGB(40, 200, 190), Perks = {}, Pitch = "",
}
local NEUTRAL_LORE = "Those who chose to shape the shards, not take them."
local NEUTRAL_NOTE = "No fight buffs · No PvP · Crafting focus (coming soon)"
local NEUTRAL_CLASS_NAMES = { Warrior = "Blacksmith", Mage = "Alchemist", Archer = "Hunter" }
local PICK_LINES = {
	Warrior = "Get close and smash everyone around you",
	Mage = "Stand back and blast a wide area",
	Archer = "Shoot them one by one from far away",
}

-- player-facing strings used only by these panels (Korean). Keys ending in F go through string.format.
local T = {
	Titles = {
		Menu = "Menu", Travel = "Travel", Rebirth = "Rebirth", Altar = "Altar of Fate",
		Class = "Change Class", Shop = "Change Ticket Shop", Vacation = "Vacation Bonus",
		Nickname = "Nickname", WeaponShop = "Forge", Welcome = "Guide · Take Back the Supply Road", PotionShop = "Potion Shop",
		Items = "Items",
	},
	Back = "← Menu",
	Close = "X",
	-- menu
	MenuTravel = "Travel",
	MenuRebirth = "Rebirth",
	MenuRebirthReady = "Rebirth (ready!)",
	MenuClass = "Change Class",
	MenuShop = "Ticket Shop",
	MenuVacation = "Vacation Bonus",
	MenuNickname = "Nickname",
	MenuWelcome = "Meet the Guide",
	MenuItems = "Items",
	MenuBag = "Bag", -- H-1
	MenuMap = "Map",
	WelcomePrevious = "Back",
	WelcomeNext = "Next",
	WelcomeFirst = "From the Start",
	WelcomeAccept = "I'm In!",
	WelcomeMore = "▶", -- 검수 10/09: the small next-page button (Skip ▶ uses the same glyph)
	WelcomePending = "Checking...",
	WelcomeRetry = "We couldn't confirm that. Please tap again.",
	WelcomeUnavailable = "Pick a class first, then talk to the Guide again.",
	MenuAltarHint = "Change sides at the Altar of Fate in the Crossroads!",
	-- travel
	TravelGo = "Go",
	TravelNoGo = "Locked",
	TravelBusy = "Traveling",
	TravelNeedLevelF = "Needs Lv %d",
	TravelInfoF = "Lv %d+ · %s",
	TravelHere = " · You are here",
	TravelRecommendF = "  <font color=\"#FFD23C\">★ %s</font>",
	Recommended = "Recommended",
	Safe = "Safe",
	PvP = "PvP",
	-- rebirth
	RebirthInfoF = "Rebirths: %d · Needs Lv %d (now Lv %d)",
	RebirthCountsF = "This server: Knights %d : Legion %d",
	RebirthBonusF = "+%d%%",
	RebirthBonusUnderdogF = "+%d%%! (smaller side)",
	RebirthCurrent = "(your side)",
	-- A23-14 (user 2026-10-05): rebirth resets the level (and XP) only; gold, weapons, enhancement and items stay
	RebirthResets = "Resets: only your level (XP too)",
	RebirthKeeps = "Keeps: gold, weapons, enhancements, items, class, Honor/Mischief, rebirth bonus, marks, tickets",
	RebirthConfirmTitle = "Rebirth",
	RebirthConfirmBodyF = "Be reborn as %s?\nOnly your level starts over. Gold, weapons and items stay.\nKept: class, Honor/Mischief, rebirth bonus, marks, tickets",
	RebirthConfirmOk = "Rebirth!",
	-- altar
	AltarCurrentF = "Your side: %s → Which side will you join?",
	AltarRules = "You need: 0 Wanted stars · no Grudge Sack · not a Kaiju · not in a fight",
	AltarCooldownRuleF = "You can change sides once every %d min",
	AltarCooldownF = "Ready in %s",
	AltarFar = "You can only change sides near the Altar of Fate.",
	AltarConfirmTitle = "Change Side",
	AltarConfirmFreeF = "Switch to %s?\nFree: %s",
	AltarConfirmTicketF = "Use 1 Change Ticket to switch to %s?\nYour Honor and Mischief both stay.",
	Honor = "Honor",
	Infamy = "Mischief", -- A23-166
	LossScoreF = "%s %s resets",
	BetrayalSuffix = " (price of betrayal)",
	-- shared change options (A7-4)
	Selected = "Selected",
	FreeButton = "Change for Free",
	TicketButtonF = "Use a Ticket (you have %d)",
	TicketKeepAll = "Keep everything",
	TicketBuyHint = "You have 0 · after buying, tap again to change",
	LossNone = "You lose nothing",
	ConfirmChange = "Change",
	-- class
	ClassPickFirst = "Pick a class first.",
	ClassHint = "Tap the class card you want.",
	ClassCurrent = "Current",
	ClassHeaderF = "Change to %s",
	ClassLossLevelF = "Lv %d → Lv 1",
	ClassLossXPF = "%d XP resets",
	ClassKeeps = "Gold, weapons, items and rebirth bonus stay",
	ClassFreeKeepF = "Your level stays before Lv%d", -- A23-14 fallback for Config.Text.ClassFreeKeepLevelF
	ClassConfirmTitle = "Change Class",
	ClassConfirmFreeF = "Change to %s?\nFree: %s",
	ClassConfirmTicketF = "Use 1 Change Ticket to change to %s?\nYour level stays.",
	-- shop
	ShopRowF = "%s — you have %d",
	ShopNote = "Change Tickets are not stats. They keep your progress when you switch. You can always switch for free too!",
	ProductPending = "Coming soon",
	ProductBuyF = "Buy with Robux (%s R$)",
	WeaponLocation = "Crossroads → Artisan Guild anvil · interact up close",
	WeaponFar = "Come close to the Forge anvil to buy.", -- UI round 2 #3: the list still shows from afar (look only)
	WeaponShowWay = "Show me the way",
	WeaponWayLabel = "Forge",
	WeaponLoading = "Check again once your character is ready.",
	WeaponNote = "Pick a basic weapon to buy. Weapons you own can be equipped again for free.",
	-- A23-127 (plan 10/13 §1-A #2): while the Forge sells no weapon (WSHOP.Sells) - monsters drop them
	WeaponNoteDrop = "Monsters drop weapons. Equip yours here for free, or sell them.",
	WeaponFarDrop = "Come close to the Forge anvil to equip or sell.",
	WeaponFromF = "Get it: %s", -- (Config.WeaponSource)
	WeaponLevelF = "Needs Lv %d · Now Lv %d",
	WeaponCurrentF = "Current weapon: %s",
	WeaponPriceF = "Price %s gold · Needs Lv %d · Now Lv %d",
	WeaponEffectF = "Slime in %d basic hits → %d hits",
	WeaponEffectNowF = "Slime in %d basic hits",
	WeaponGoldF = "You have %s gold (Vault %s + Pouch %s)",
	WeaponShortF = "You need %s more gold.",
	WeaponBuyF = "Buy · %s gold",
	WeaponSellF = "Sell · %s gold",
	WeaponEquip = "Equip (free)",
	WeaponEquipped = "Equipped",
	WeaponOwned = "Owned",
	WeaponUnowned = "Not owned",
	WeaponStarter = "First weapon · free to re-equip · can't be sold", -- A23-34 (A23-48 English)
	WeaponStarterNoSell = "The first weapon can't be sold",
	WeaponFromSmith = "From the Blacksmith", -- A23-34: tier 1 is a gift (M1_1), never bought
	WeaponNoSell = "You can only sell weapons you own",
	WeaponSaleNoteF = "Sells for %s gold (1/10 of the price)",
	WeaponSaleEquipped = "Sell the weapon in your hand and you switch to your best other weapon (or bare hands).",
	WeaponSellTitle = "Sell Weapon",
	WeaponSellConfirmF = "Sell %s for %s gold?\nIt leaves your weapon list.",
	WeaponSellConfirm = "Sell",
	WeaponUnavailable = "The Forge doesn't sell this weapon.",
	WeaponInvalid = "We can't read the weapon info. Please open it again in a moment.",
	WeaponChanged = "Your weapons changed. Please check the list again.",
	WeaponSent = "Checking the trade...",
	WeaponSlow = "No answer for the trade yet. Check the alerts and tap again.",
	WeaponPending = "Checking...",
	WeaponByeBrowse = "Nothing you like? Take your time!",
	WeaponByeBuy = "Good choice. Try it out and come back!",
	WeaponByeSell = "Got your weapon. Come back when you need something!",
	WeaponByeEquip = "That one fits your hand. Stay safe out there!",
	WeaponByePending = "Check how the trade went. Come back soon!",
	-- vacation
	VacationHeaderF = "Vacation Bonus! You were away %d days. That's okay!", -- 검수 10/10: shorter (Config.Plural: 1 day)
	VacationRewardF = "+%s gold · +%s XP",
	VacationNoteF = "Even on breaks you get %d%% of a day's rewards. Playing gives 100%%!",
	VacationClaim = "Claim",
	VacationNone = "No vacation bonus to claim.",
	VacationAwayF = "You were away %d days. That's okay!", -- the reward popup's first line (창 꾸미기 ③; 검수 10/10: shorter)
	VacationLater = "Later",
	-- fallbacks for Config.Text keys added in review R1
	WaitRespawn = "You can do this after you respawn.", -- CR-L30
	BlockedBully = "You can join the Artisan Guild after all your Bully stacks are gone.", -- CR-L9
}

local DEFAULT_THEME = {
	Bg = Color3.fromRGB(25, 25, 35),
	Text = Color3.new(1, 1, 1),
	SubText = Color3.fromRGB(200, 200, 210),
	Good = Color3.fromRGB(80, 220, 120),
	Bad = Color3.fromRGB(255, 80, 80),
	Gold = Color3.fromRGB(255, 210, 60),
	XP = Color3.fromRGB(90, 170, 255),
	Font = Enum.Font.GothamBold,
}
local PALETTE = {
	Button = Color3.fromRGB(62, 66, 96),
	Card = Color3.fromRGB(42, 44, 62),
	CardSelected = Color3.fromRGB(80, 84, 128),
	Row = Color3.fromRGB(40, 42, 58),
	Free = Color3.fromRGB(44, 150, 82),
	Ticket = Color3.fromRGB(50, 112, 205),
	Buy = Color3.fromRGB(150, 78, 200),
	Close = Color3.fromRGB(190, 60, 60),
	Disabled = Color3.fromRGB(70, 70, 80),
	DarkText = Color3.fromRGB(30, 26, 18),
}

------------------------------------------------------------------ state
local C = nil
local UIKit = nil
local theme = table.clone(DEFAULT_THEME)

local fallbackGui = nil
local root, window, titleLabel, backButton, closeButton, content = nil, nil, nil, nil, nil, nil
local currentId = nil
local currentUpdate = nil
local openedFromMenu = false
local pendingFromMenu = false
local selectedClass = nil
local selectedTarget = nil
local rebuildQueued = false
local vacationShown = false
local pickersClosedSince = nil
local orderCounter = 0
local inputGuardUntil = 0 -- CR-L26: os.clock() before which panel buttons / cards ignore clicks
local lastWarnAt = -math.huge
local cameraConn = nil
local scaleConn = nil
local NICK = { UI = nil, Draft = nil, Message = "", Pending = false, Request = 0,
	Rule = "2-20 letters · must be unique", Unavailable = "Please check the save connection." }
local WSHOP = { Distance = 12, PromptName = "HHC_BlacksmithPrompt",
	PendingTimeout = 5, SlowNoteSeconds = 4, -- s: an unanswered trade unlocks the row, then T.WeaponSlow shows
	-- UI ideas round 2 #8 (검수 2026-10-07): a weapon of ConfirmAt gold or more buys on a second press within
	-- ConfirmSeconds (the first press turns the button into "Tap again to buy"); cheaper ones and equips stay one press
	ConfirmAt = 100, ConfirmSeconds = 3,
	AgainTouch = "Tap again to buy", AgainMouse = "Click again to buy" }
local WELCOME = { PendingOpen = false }

-- quality 2 (UIKit.Typewriter, image dev adc7311; 검수 2026-10-07): a dialogue line types in at Speed letters / s with the
-- speaker's blips (C.Audio.Talk; silent until the sound ids exist); a tap on the line, or [Next] / an answer button
-- while it still types, first shows the whole line. One state table per open window: { Key, Handle }.
local TYPE = { Speed = 40 }
-- shows `text` on `label`; the same key on a refresh (update runs often) leaves the running / finished line alone
function TYPE.Show(state, label, text, speaker, key)
	key = tostring(key) .. "|" .. text
	if state.Key == key and state.Label == label then return end
	state.Key, state.Label, state.Handle = key, label, nil
	if UIKit and type(UIKit.Typewriter) == "function" then
		local ok, h = pcall(UIKit.Typewriter, label, text, { Speed = TYPE.Speed, Speaker = speaker })
		if ok and type(h) == "table" then
			state.Handle = h
			return
		end
	end
	label.Text = text
end
-- true when the line was still typing (now shown whole): that tap is used up
function TYPE.Finish(state)
	local h = state.Handle
	if type(h) == "table" and type(h.Done) == "function" and not h.Done() then
		h.Finish()
		return true
	end
	return false
end
-- an invisible button over the line: a tap there finishes the line
function TYPE.Tap(state, label)
	local b = Instance.new("TextButton")
	b.Name = "TypeTap"
	b.BackgroundTransparency = 1
	b.Text = ""
	b.AutoButtonColor = false
	b.Size = UDim2.fromScale(1, 1)
	b.ZIndex = label.ZIndex + 1
	b.Parent = label
	b.Activated:Connect(function() TYPE.Finish(state) end)
end
local ITEMS -- A23-12 item list state + helpers (assigned below the blacksmith helpers; the menu reads ITEMS.Hint)
local RENDER = { Reset = false } -- B14: a queued rebuild resets the scroll (user / structure) unless only data changed
-- BB13 windows other client modules register (Panels.Register): Opts[id] = { Build, Title, FixedBody, Rebuild,
-- Cleanup }; Built = the registered window whose Build ran last (its Cleanup runs before the next build and on close);
-- AttrFns = its kit.OnAttr callbacks; Arg = the arg of the last Panels.Open; Fixed = the plain body of FixedBody windows
local REG = { Opts = {}, Built = nil, AttrFns = {}, Arg = nil, Fixed = nil }

local disabledButtons = setmetatable({}, { __mode = "k" })
local baseColors = setmetatable({}, { __mode = "k" })
local textColors = setmetatable({}, { __mode = "k" })

------------------------------------------------------------------ attribute helpers
local function attr(name, default)
	local v = player:GetAttribute(name)
	if v == nil then return default end
	return v
end

local function num(name)
	local v = player:GetAttribute(name)
	return type(v) == "number" and v or 0
end

local function gameAttr(name)
	local gs = ReplicatedStorage:FindFirstChild("GameState")
	if not gs then return nil end
	return gs:GetAttribute(name)
end

local function gameNum(name)
	local v = gameAttr(name)
	return type(v) == "number" and v or 0
end

local function myFaction()
	local f = player:GetAttribute("Faction")
	return type(f) == "string" and f or "None"
end

local function currentClass()
	local c = player:GetAttribute("Class")
	if type(c) == "string" and Config.Classes[c] then return c end
	return "Warrior"
end

local function kaijuState()
	local k = player:GetAttribute("KaijuState")
	return type(k) == "string" and k or "None"
end

local function inCombat()
	return num("InCombatUntil") > Util.Now()
end

-- CR-L30: dead (or no character yet) -> travel / class / rebirth / altar wait for the respawn
local function isDead()
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not hum then return true end
	return hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead
end

local function fmtText(key, ...)
	local s = Config.Text[key]
	if type(s) ~= "string" then return tostring(key) end
	local ok, out = pcall(string.format, s, ...)
	return ok and out or s
end

-- Config.Text[key] when G1 provides it (addendum A7-3/A7-4 keys), else the private fallback format
local function cfgFmt(key, fallback, ...)
	local s = Config.Text[key]
	if type(s) ~= "string" then s = fallback end
	local ok, out = pcall(string.format, s, ...)
	if ok then return out end
	local ok2, out2 = pcall(string.format, fallback, ...)
	return ok2 and out2 or fallback
end

local function warnThrottled(msg)
	local t = os.clock()
	if t - lastWarnAt < WARN_INTERVAL then return end
	lastWarnAt = t
	Util.Warn(TAG, msg)
end

------------------------------------------------------------------ faction / class display helpers
local function factionDef(id)
	local f = Config.Factions[id]
	if type(f) == "table" then return f end
	if id == "Neutral" then return NEUTRAL_FALLBACK end
	return Config.Factions.None
end

local function factionColor(id)
	local f = factionDef(id)
	if typeof(f.Color) == "Color3" then return f.Color end
	if typeof(f.TeamColor) == "BrickColor" then return f.TeamColor.Color end
	return Color3.fromRGB(200, 200, 200)
end

local function factionLore(id)
	local lore = Config.Story.FactionLore and Config.Story.FactionLore[id]
	if type(lore) == "string" and lore ~= "" then return lore end
	if id == "Neutral" then return NEUTRAL_LORE end
	return ""
end

local function perksText(id)
	local def = factionDef(id)
	local lines = {}
	if type(def.Perks) == "table" then
		for _, p in def.Perks do
			table.insert(lines, "• " .. tostring(p))
		end
	end
	if id == "Neutral" and #lines == 0 then
		table.insert(lines, "• " .. ((type(def.Note) == "string" and def.Note) or NEUTRAL_NOTE))
	end
	return table.concat(lines, "\n")
end

local function className(classId, factionId)
	local c = Config.Classes[classId] or Config.Classes.Warrior
	if factionId == "Neutral" and (type(c.Names) ~= "table" or c.Names.Neutral == nil) then
		return NEUTRAL_CLASS_NAMES[classId] or Config.ClassName(classId, "None")
	end
	return Config.ClassName(classId, factionId)
end

local function genericClassName(classId)
	local c = Config.Classes[classId] or Config.Classes.Warrior
	return (type(c.Names) == "table" and c.Names.None) or classId
end

local function pickLine(classId)
	-- A23-39: the Artisan Guild's archer is the pet tamer (Config.ClassCard gives its own card lines)
	local card = type(Config.ClassCard) == "function" and Config.ClassCard(classId, myFaction()) or nil
	if type(card) == "table" and type(card.PickLine) == "string" and card.PickLine ~= "" then return card.PickLine end
	local c = Config.Classes[classId]
	if c and type(c.PickLine) == "string" and c.PickLine ~= "" then return c.PickLine end
	return PICK_LINES[classId] or ""
end

local function markPreview(fromId, toId)
	if fromId == "Halo" and toId == "Horns" then return string.format(Config.Story.Fall) end
	if fromId == "Horns" and toId == "Halo" then return string.format(Config.Story.Redeem) end
	return nil
end

-- dark text on bright fills (Halo gold, Neutral teal A9-1), white on darker ones (Horns red, green)
local function contrastText(c)
	local lum = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
	return lum > 0.55 and PALETTE.DarkText or Color3.new(1, 1, 1)
end

-- exact digits with thousands separators (A7-4: "show the exact loss as numbers", e.g. "명예 12,345 초기화")
local function exactNumber(n)
	n = math.floor(tonumber(n) or 0)
	local digits = tostring(math.abs(n))
	local grouped = string.reverse((string.gsub(string.reverse(digits), "(%d%d%d)", "%1,")))
	if string.sub(grouped, 1, 1) == "," then grouped = string.sub(grouped, 2) end
	return (n < 0 and "-" or "") .. grouped
end

------------------------------------------------------------------ UI infrastructure
local function loadTheme()
	local src = UIKit and UIKit.Theme
	if type(src) ~= "table" then return end
	for k, def in DEFAULT_THEME do
		local v = src[k]
		if v ~= nil and typeof(v) == typeof(def) then theme[k] = v end
	end
end

local function getGui()
	if UIKit and typeof(UIKit.Gui) == "Instance" then return UIKit.Gui end
	if fallbackGui and fallbackGui.Parent then return fallbackGui end
	local pg = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 5)
	if not pg then return nil end
	fallbackGui = Instance.new("ScreenGui")
	fallbackGui.Name = "PanelsGui"
	fallbackGui.ResetOnSpawn = false
	fallbackGui.IgnoreGuiInset = true
	fallbackGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	fallbackGui.DisplayOrder = 11
	fallbackGui.Parent = pg
	Util.Warn(TAG, "UIKit.Gui missing; using a fallback ScreenGui")
	return fallbackGui
end

-- virtual canvas (w, h) inside the UIScale'd gui and the first safe Y below the top bar (H4)
local function canvas(gui)
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	if vp.X < 2 or vp.Y < 2 then vp = Vector2.new(1280, 720) end
	local sc = gui and gui:FindFirstChildOfClass("UIScale")
	local s = sc and sc.Scale or 1
	if type(s) ~= "number" or s < 0.05 then s = 1 end
	local insetY = 0
	local ok, topLeft = pcall(function()
		return GuiService:GetGuiInset()
	end)
	if ok and typeof(topLeft) == "Vector2" then insetY = topLeft.Y end
	local top = ((insetY > 0) and (insetY + TOP_PAD) or TOP_FALLBACK) / s
	return vp.X / s, vp.Y / s, top, s
end

local function constrainText(obj, maxSize)
	local c = Instance.new("UITextSizeConstraint")
	c.MinTextSize = MIN_TEXT
	c.MaxTextSize = math.max(MIN_TEXT, maxSize or 64)
	c.Parent = obj
end

local function corner(obj, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = obj
	return c
end

local function nextOrder()
	orderCounter += 1
	return orderCounter
end

-- auto-height wrapped text in a list layout
local function addText(parent, text, opts)
	opts = opts or {}
	local l = Instance.new("TextLabel")
	l.Name = opts.Name or "Text"
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Size = opts.Width or UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.Font = opts.Font or BODY_FONT
	l.TextSize = math.max(opts.Size or 18, GUARD.FixedTextMin) -- CR-L40
	l.TextColor3 = opts.Color or theme.Text
	l.TextWrapped = true
	l.RichText = opts.Rich == true
	l.TextXAlignment = opts.Align or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Text = text or ""
	l.LayoutOrder = nextOrder()
	if l.TextScaled then constrainText(l) end -- CR-L40: the constraint only matters for scaled text
	l.Parent = parent
	-- 이미지 개발 10/10 (검수: no word alone on a line): centred text keeps its lines even (UIKit.BalanceLines)
	if l.TextXAlignment == Enum.TextXAlignment.Center and UIKit and type(UIKit.BalanceLines) == "function" then
		UIKit.BalanceLines(l)
	end
	return l
end

-- absolutely positioned single-line label
local function placeLabel(parent, text, size, color, pos, dim, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Position = pos
	l.Size = dim
	l.Font = theme.Font
	l.TextSize = math.max(size, GUARD.FixedTextMin) -- CR-L40
	l.TextColor3 = color
	l.TextWrapped = true
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Text = text or ""
	constrainText(l)
	l.Parent = parent
	return l
end

local function addRow(parent, height, padding)
	local f = Instance.new("Frame")
	f.Name = "Row"
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = UDim2.new(1, 0, 0, height or 0)
	if not height or height <= 0 then f.AutomaticSize = Enum.AutomaticSize.Y end
	f.LayoutOrder = nextOrder()
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, padding or 10)
	list.Parent = f
	f.Parent = parent
	return f
end

local function addColumn(parent, scaleX, offsetX, padding)
	local f = Instance.new("Frame")
	f.Name = "Column"
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = UDim2.new(scaleX, offsetX, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.LayoutOrder = nextOrder()
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, padding or 6)
	list.Parent = f
	f.Parent = parent
	return f
end

-- 검수 2026-10-07 (window audit): the factions a window offers - the ones a player may newly pick (A23-57: the artisan
-- guild only while Config.Features.NeutralFaction is on) plus `keep` (my own, an old Neutral save keeps it)
function FRAME.Factions(keep)
	local list = {}
	for _, id in FACTION_IDS do
		if id == keep or type(Config.Pickable) ~= "function" or Config.Pickable(id) then table.insert(list, id) end
	end
	return list
end

-- the change tickets can be bought (a product id is set); until then the menu hides the ticket shop (no "Coming soon"
-- for kids, 검수 2026-10-07)
function FRAME.TicketsOnSale()
	for _, kind in { "Class", "Faction" } do
		local prod = Config.ProductByKind(kind)
		if prod and tonumber(prod.Id) and prod.Id ~= 0 then return true end
	end
	return false
end

-- the approved capsule for a button colour: green Free / Good = BtnConfirm, purple Buy and gold = BtnPrimary (gold),
-- the rest (blue Ticket, the default) = BtnSecondary
function FRAME.Part(color)
	if color == PALETTE.Free or color == theme.Good then return "BtnConfirm" end
	-- gold = 'on' / selected / ready in the windows (Settings tabs and toggles, the ready rebirth) and Buy
	if color == PALETTE.Buy or color == theme.Gold then return "BtnPrimary" end
	return "BtnSecondary"
end

local function applyButtonState(btn)
	local enabled = not disabledButtons[btn]
	if btn:GetAttribute("ArtButton") then -- 창 꾸미기: UIKit.ButtonArtState dims the art and the words
		btn.AutoButtonColor = false
		btn:SetAttribute("Disabled", not enabled)
		return
	end
	local base = baseColors[btn] or PALETTE.Button
	btn.BackgroundColor3 = enabled and base or base:Lerp(PALETTE.Disabled, 0.75)
	btn.TextColor3 = textColors[btn] or theme.Text
	btn.TextTransparency = enabled and 0 or 0.4
	btn.AutoButtonColor = false -- UIKit's press-shrink is the feedback
	btn:SetAttribute("Disabled", not enabled) -- UIKit.Button skips its click sound / tween while disabled
end

local function paintButton(btn, color, textColor)
	local tc = textColor or theme.Text
	if baseColors[btn] == color and textColors[btn] == tc then return end
	if btn:GetAttribute("ArtButton") and UIKit and type(UIKit.SetButtonArt) == "function" then
		baseColors[btn], textColors[btn] = color, tc
		pcall(UIKit.SetButtonArt, btn, FRAME.Part(color))
		applyButtonState(btn)
		return
	end
	baseColors[btn] = color
	textColors[btn] = tc
	applyButtonState(btn)
end

local function setEnabled(btn, enabled)
	local wasDisabled = disabledButtons[btn] == true
	if wasDisabled == not enabled then return end
	disabledButtons[btn] = (not enabled) or nil
	applyButtonState(btn)
end

local function playClick()
	local fx = C and C.Fx
	if fx and type(fx.PlaySound) == "function" then
		pcall(fx.PlaySound, "Click")
	end
end

-- UIKit.Button (click sound, press tween) with a local fallback; clicks are ignored while disabled
local function makeButton(parent, text, color, size, onClick, textColor)
	local btn = nil
	local function handler()
		if os.clock() < inputGuardUntil then return end -- CR-L26
		if not btn or disabledButtons[btn] then return end
		local ok, err = pcall(onClick)
		if not ok then Util.Warn(TAG, "button handler error: " .. tostring(err)) end
	end
	-- 창 꾸미기: the approved capsule for the colour (its words mirror btn.Text), else the coloured code button
	if UIKit and type(UIKit.ArtTextButton) == "function" then
		local ok, b = pcall(UIKit.ArtTextButton, FRAME.Part(color), {
			Name = "Button", Text = text, Size = size, TextSize = 20, Parent = parent,
		}, handler)
		if ok and typeof(b) == "Instance" and b:IsA("GuiButton") then btn = b end
	end
	if not btn and UIKit and type(UIKit.Button) == "function" then
		local ok, b = pcall(UIKit.Button, {
			Name = "Button", Text = text, Size = size, Color = color,
			TextColor = textColor or theme.Text, TextSize = 20, Parent = parent,
		}, handler)
		if ok and typeof(b) == "Instance" and b:IsA("GuiButton") then btn = b end
	end
	if not btn then
		local b = Instance.new("TextButton")
		b.Size = size
		b.Font = theme.Font
		b.TextSize = 20
		b.BorderSizePixel = 0
		corner(b, 10)
		b.Activated:Connect(function()
			if b:GetAttribute("NoClick") ~= true then playClick() end -- NoClick: the button's own sound (UIKit wirePress)
			handler()
		end)
		btn = b
	end
	btn.Name = "Button"
	btn.Text = text
	btn.TextWrapped = true
	btn.LayoutOrder = nextOrder()
	if not btn:FindFirstChildOfClass("UITextSizeConstraint") then constrainText(btn, 28) end
	baseColors[btn] = nil
	paintButton(btn, color, textColor)
	btn.Parent = parent
	return btn
end

-- selectable card (own TextButton so the border stroke is fully controlled)
local function makeCard(parent, size, accent, onClick)
	local card = Instance.new("TextButton")
	card.Name = "Card"
	card.Text = ""
	card.AutoButtonColor = true
	card.BackgroundColor3 = PALETTE.Card
	card.BorderSizePixel = 0
	card.Size = size
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.LayoutOrder = nextOrder()
	constrainText(card)
	corner(card, 12)
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = accent
	st.Thickness = 2
	st.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = card
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = card
	card.Activated:Connect(function()
		if os.clock() < inputGuardUntil then return end -- CR-L26
		playClick()
		local ok, err = pcall(onClick)
		if not ok then Util.Warn(TAG, "card handler error: " .. tostring(err)) end
	end)
	card.Parent = parent
	return card, st
end

local function toast(text, kind, duration)
	if UIKit and type(UIKit.Toast) == "function" then
		pcall(UIKit.Toast, text, kind, duration)
	end
end

local function confirm(title, body, okText, onConfirm)
	if UIKit and type(UIKit.Confirm) == "function" then
		local ok, err = pcall(UIKit.Confirm, title, body, okText, onConfirm)
		if not ok then Util.Warn(TAG, "UIKit.Confirm failed: " .. tostring(err)) end
	else
		Util.Warn(TAG, "UIKit.Confirm is unavailable")
	end
end

-- fire a client -> server intent without ever blocking the caller
local function fire(remoteName, ...)
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = pcall(function()
			Net.Get(remoteName):FireServer(table.unpack(args, 1, args.n))
		end)
		if not ok then Util.Warn(TAG, "could not send " .. remoteName .. ": " .. tostring(err)) end
	end)
end

local function productLabel(kind)
	local p = Config.ProductByKind(kind)
	if not p or p.Id == 0 then return T.ProductPending end
	return string.format(T.ProductBuyF, tostring(p.PriceHint))
end

-- never consumes a ticket: buying only adds one (the server toast confirms); the player must click again to use it
local function buy(kind)
	local p = Config.ProductByKind(kind)
	if p and p.Id ~= 0 then
		local ok, err = pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, player, p.Id)
		if not ok then Util.Warn(TAG, "PromptProductPurchase failed: " .. tostring(err)) end
	else
		toast(fmtText("ProductNotReady"), "info")
	end
end

------------------------------------------------------------------ rules mirrored from the server (display only)
local function travelBlock(destId, zone, level, faction)
	if isDead() then return cfgFmt("WaitRespawn", T.WaitRespawn), T.TravelNoGo end -- CR-L30
	if num("TravelingUntil") > Util.Now() then return fmtText("Traveling"), T.TravelBusy end
	if destId == "Home" and faction == "None" then return fmtText("NeedFaction"), T.TravelNoGo end
	if level < zone.MinLevel then
		return fmtText("NeedLevel", math.floor(zone.MinLevel)), string.format(T.TravelNeedLevelF, math.floor(zone.MinLevel))
	end
	local k = kaijuState()
	if k == "Siren" or k == "Active" then return fmtText("TravelBlockedKaiju"), T.TravelNoGo end
	if num("SackGold") > 0 then return fmtText("TravelBlockedSack"), T.TravelNoGo end
	if num("WantedStars") >= Config.PvP.NoTravelStars then return fmtText("TravelBlockedStars"), T.TravelNoGo end
	if inCombat() then return fmtText("TravelBlockedCombat"), T.TravelNoGo end
	return nil, nil
end

-- same order as ProgressionService.TryRebirth; targetId (optional) adds the per-target bully check (CR-L9)
local function rebirthBlock(level, req, targetId)
	if isDead() then return cfgFmt("WaitRespawn", T.WaitRespawn) end -- CR-L30
	if level < req then return fmtText("RebirthNeed", math.floor(req)) end
	if num("WantedStars") > 0 then return fmtText("BlockedStars") end
	if num("SackGold") > 0 then return fmtText("BlockedSack") end
	if kaijuState() ~= "None" then return fmtText("BlockedKaiju") end
	if inCombat() then return fmtText("TravelBlockedCombat") end
	if targetId == "Neutral" and num("BullyStacks") > 0 then return cfgFmt("BlockedBully", T.BlockedBully) end -- CR-L9
	return nil
end

-- CR-L7: the server's underdog counts (no rookies, no 120 s idlers); HaloCount / HornsCount until they are published.
-- Returns halo, horns, selfIn: whether I am inside those counts. HaloCount/HornsCount always include me; the
-- underdog counts only when FactionService marked me eligible (UnderdogCounted, published with the same recount).
local function underdogCounts()
	local halo, horns = gameAttr("UnderdogHalo"), gameAttr("UnderdogHorns")
	if type(halo) ~= "number" or type(horns) ~= "number" then
		return gameNum("HaloCount"), gameNum("HornsCount"), true
	end
	return halo, horns, player:GetAttribute("UnderdogCounted") ~= false
end

-- underdog ratio counts Halo vs Horns only (A6); Neutral always gets the normal bonus
local function rebirthBonus(targetId, othersHalo, othersHorns)
	if targetId == "Halo" then return Config.RebirthBonusFor(othersHalo, othersHalo + othersHorns) end
	if targetId == "Horns" then return Config.RebirthBonusFor(othersHorns, othersHalo + othersHorns) end
	return Config.Rebirth.BonusNormal
end

local function altarDistance()
	local map = workspace:FindFirstChild("Map")
	local landmarks = map and map:FindFirstChild("Landmarks")
	local altar = landmarks and landmarks:FindFirstChild("Altar")
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not (altar and altar:IsA("BasePart") and hrp and hrp:IsA("BasePart")) then return nil end
	return Util.FlatDistance(altar.Position, hrp.Position)
end

-- returns (reasonText?, shortCooldownText?); same order as FactionService.onSwitchFaction
local function altarBlock(target)
	if isDead() then return cfgFmt("WaitRespawn", T.WaitRespawn), nil end -- CR-L30
	local d = altarDistance()
	if d and d > Config.Switch.AltarRange then return T.AltarFar, nil end
	if num("SackGold") > 0 then return fmtText("BlockedSack"), nil end
	if kaijuState() ~= "None" then return fmtText("BlockedKaiju"), nil end
	if num("WantedStars") > 0 then return fmtText("BlockedStars"), nil end
	if inCombat() then return fmtText("TravelBlockedCombat"), nil end
	if target == "Neutral" and num("BullyStacks") > 0 then return cfgFmt("BlockedBully", T.BlockedBully), nil end -- CR-L9
	local last = num("LastSwitchTime")
	local remaining = last + Config.Switch.Cooldown - Util.Now()
	if last > 0 and remaining > 0 then
		local t = Util.FormatTime(math.ceil(remaining))
		return fmtText("SwitchCooldown", t), string.format(T.AltarCooldownF, t)
	end
	return nil, nil
end

-- the score of the faction being LEFT on a free switch ("배신의 대가"); Neutral has none (A6)
local function leftScore(fromId)
	if fromId == "Halo" then return T.Honor, math.floor(num("Honor")) end
	if fromId == "Horns" then return T.Infamy, math.floor(num("Infamy")) end
	return nil, 0
end

local function altarLossText(fromId)
	local scoreName, amount = leftScore(fromId)
	if scoreName and amount > 0 then
		return cfgFmt("LossScore", T.LossScoreF, scoreName, exactNumber(amount)) .. T.BetrayalSuffix, true
	end
	return T.LossNone, false
end

-- same checks and order as ClassService.onChangeClass (PvP zone, sack, kaiju, combat tag)
local function classBlock()
	if isDead() then return cfgFmt("WaitRespawn", T.WaitRespawn) end -- CR-L30
	if player:GetAttribute("ZonePvP") == true then return fmtText("ClassNeedSafe") end
	if num("SackGold") > 0 then return fmtText("BlockedSack") end
	if kaijuState() ~= "None" then return fmtText("BlockedKaiju") end
	if inCombat() then return fmtText("TravelBlockedCombat") end
	return nil
end

-- A23-14: below Lv Config.ClassChange.FreeKeepLevelBelow a free change keeps level and XP (nothing is lost, so the
-- ticket option is hidden; the server never spends a ticket there). From that level on: free = back to Lv 1.
local function classLossText()
	local level, xp = math.floor(num("Level")), math.floor(num("XP"))
	local keepBelow = type(Config.ClassChange) == "table" and tonumber(Config.ClassChange.FreeKeepLevelBelow) or nil
	if keepBelow and type(Config.ClassChangeKeepsLevel) == "function" and Config.ClassChangeKeepsLevel(math.max(1, level)) then
		return cfgFmt("ClassFreeKeepLevelF", T.ClassFreeKeepF, math.floor(keepBelow)), false
	end
	if level > 1 then return cfgFmt("LossLevel", T.ClassLossLevelF, level), true end
	if xp > 0 then return string.format(T.ClassLossXPF, xp), true end
	return T.LossNone, false
end

local function pickerOpen()
	if not C then return false end
	for _, name in { "Intro", "FactionPicker", "ClassPicker" } do
		local m = C[name]
		if type(m) == "table" and type(m.IsOpen) == "function" then
			local ok, open = pcall(m.IsOpen)
			if ok and open then return true end
		end
	end
	return false
end

------------------------------------------------------------------ 창 꾸미기 frame parts
-- the title: the RibbonHeader art (navy capsule, the round disc on its left holds the window icon) as wide as its words
-- (AutomaticSize X between FRAME.TitleMinW and the room between the corner discs), centred on the plate's top edge.
-- titleLabel stays the words (render writes its Text). Missing art: the old gold title words in the plate's top left
function FRAME.BuildTitle()
	local th = FRAME.TitleH
	local ribbon = UIKit and type(UIKit.ArtImage) == "function" and UIKit.ArtImage(FRAME.Title, {
		Name = "TitleRibbon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(0, th),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 4,
		Active = false,
		Parent = window,
	}) or nil
	if not ribbon then
		titleLabel = placeLabel(window, "", 26, theme.Gold, UDim2.fromOffset(18, 10), UDim2.new(1, -140, 0, 44))
		return
	end
	FRAME.Ribbon = ribbon
	-- [disc with the icon][words][rounded end] in a row: AutomaticSize X adds them up (RibbonHeader: the disc is ~0.8 of
	-- the height wide, centred at 0.40; the words start at 114 / 121 = 0.94 of the height; the round end ~0.45)
	UIKit.Create("UISizeConstraint", { MinSize = Vector2.new(FRAME.TitleMinW, th), MaxSize = Vector2.new(600, th),
		Parent = ribbon })
	UIKit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = ribbon })
	local disc = UIKit.Create("Frame", { Name = "Disc", Size = UDim2.new(0, math.floor(th * FRAME.Disc), 1, 0),
		BackgroundTransparency = 1, LayoutOrder = 1, Active = false, Parent = ribbon })
	FRAME.Icon = UIKit.Create("ImageLabel", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, th * 0.40, 0.5, 0),
		Size = UDim2.fromOffset(th * 0.52, th * 0.52),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 5,
		Active = false,
		Parent = disc,
	})
	titleLabel = UIKit.StyledLabel({
		Name = "Title",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = FRAME.TitleSize,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 2,
		ZIndex = 5,
		Parent = ribbon,
	}, "Title")
	FRAME.TitleCap = UIKit.Create("UISizeConstraint", { MaxSize = Vector2.new(400, th), Parent = titleLabel })
	UIKit.Create("Frame", { Name = "End", Size = UDim2.new(0, math.floor(th * 0.45), 1, 0), BackgroundTransparency = 1,
		LayoutOrder = 3, Active = false, Parent = ribbon })
end

-- the window's icon in the ribbon's disc (FRAME.Icons; hidden for a window without one)
function FRAME.SetIcon(id)
	local icon = FRAME.Icon
	if not icon then return end
	local key = FRAME.Icons[id or ""]
	local art = key and UIKit and type(UIKit.ArtId) == "function" and UIKit.ArtId(key) or nil
	icon.Image = art or ""
	icon.Visible = art ~= nil
end

-- a round disc button (BtnRound) with a glyph (GlyphClose / GlyphBack) at 60 %; missing art: the old coloured words
function FRAME.RoundButton(name, glyph, words, onClick)
	local def = UIKit and type(UIKit.ArtPart) == "function" and UIKit.ArtPart(FRAME.Round) or nil
	if def and type(UIKit.ArtButton) == "function" and UIKit.ArtId(FRAME.Round) then
		local b = UIKit.ArtButton(FRAME.Round, { Name = name, Size = UDim2.fromOffset(FRAME.RoundSize, FRAME.RoundSize),
			ZIndex = 6, Parent = window }, onClick)
		UIKit.ArtImage(glyph, {
			Name = "Glyph",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.58, 0.58),
			ZIndex = 7,
			Active = false,
			Parent = b,
		})
		return b
	end
	return makeButton(window, words, name == "Close" and PALETTE.Close or PALETTE.Button,
		UDim2.fromOffset(52, 44), onClick)
end

------------------------------------------------------------------ modal root
-- title / back / X row and the content below it. CR-L41: on touch screens the buttons are >= 44 real px tall
-- (canvas px = real px / UIScale) and kept apart, and the content moves down with them
-- 창 꾸미기: the X / back discs sit on the plate's top corners (a quarter outside), the ribbon on the top edge's middle,
-- the content under the ribbon inside the rim. CR-L41: on touch screens the discs are >= 44 real px
local function layoutChrome(s)
	if not (closeButton and backButton and titleLabel and content) then return end
	local d = FRAME.RoundSize
	if UserInputService.TouchEnabled then d = math.max(d, math.ceil(GUARD.TouchTarget / s)) end
	closeButton.AnchorPoint = Vector2.new(0.5, 0.5)
	closeButton.Size = UDim2.fromOffset(d, d)
	closeButton.Position = UDim2.new(1, -d * 0.2, 0, d * 0.2)
	backButton.AnchorPoint = Vector2.new(0.5, 0.5)
	backButton.Size = UDim2.fromOffset(d, d)
	backButton.Position = UDim2.new(0, d * 0.2, 0, d * 0.2)
	local ribbon = FRAME.Ribbon
	if ribbon then
		local th = FRAME.TitleH
		ribbon.Size = UDim2.fromOffset(0, th)
		local cap = ribbon:FindFirstChildOfClass("UISizeConstraint")
		-- never under the corner discs; long words end in "..." inside the ribbon
		local maxW = math.max(FRAME.TitleMinW, window.Size.X.Offset - 2 * (d * 0.8 + 6))
		if cap then cap.MaxSize = Vector2.new(maxW, th) end
		if FRAME.TitleCap then
			FRAME.TitleCap.MaxSize = Vector2.new(math.max(40, maxW - math.floor(th * FRAME.Disc) - math.floor(th * 0.45)), th)
		end
	end
	local contentTop = FRAME.TitleH / 2 + 8
	content.Position = UDim2.fromOffset(FRAME.Pad, contentTop)
	content.Size = UDim2.new(1, -2 * FRAME.Pad, 1, -(contentTop + FRAME.Bottom))
	if REG.Fixed then
		REG.Fixed.Position = content.Position
		REG.Fixed.Size = content.Size
	end
end

-- UI round 2 #4: UIKit keeps the toasts off the open window (one line above / below it); nil = no window
function FRAME.TellNotify(open)
	if not (UIKit and type(UIKit.SetNotifyAvoid) == "function") then return end
	if not (open and window and window.Visible) then
		pcall(UIKit.SetNotifyAvoid, nil)
		return
	end
	local pos, size = window.Position, window.Size -- MainGui du, AnchorPoint (0.5, 0.5)
	local hang = FRAME.Ribbon and FRAME.TitleH / 2 or 0
	pcall(UIKit.SetNotifyAvoid, { X = pos.X.Offset - size.X.Offset / 2, Y = pos.Y.Offset - size.Y.Offset / 2 - hang,
		W = size.X.Offset, H = size.Y.Offset + hang })
end

-- the content's height (du): the list plus its padding, nil before it was laid out
function FRAME.ContentH(s)
	local list = content and content:FindFirstChildOfClass("UIListLayout")
	local pad = content and content:FindFirstChildOfClass("UIPadding")
	if not list or list.AbsoluteContentSize.Y < 1 then return nil end
	local extra = pad and (pad.PaddingTop.Offset + pad.PaddingBottom.Offset) or 0
	return list.AbsoluteContentSize.Y / s + extra
end

local function layoutRoot()
	if not root or not window then return end
	local w, h, top, s = canvas(root.Parent)
	root.Position = UDim2.fromOffset(0, 0)
	root.Size = UDim2.fromOffset(w, h)
	if currentId == "Nickname" and NICK.UI then
		NICK.Layout(w, h, top, s)
		FRAME.TellNotify(false)
		return
	end
	-- the ribbon hangs half above the plate: keep it under the top bar
	local hang = FRAME.TitleH / 2
	local availH = math.max(220, h - top - 12 - hang)
	-- 게임성 검수 10/12 (UiSandbox 1920x656): the window ends above the HUD's icon row (Bag · Map · Hero …) when that
	-- still leaves a usable window (HUD.Layout.Rects.tiles)
	-- 최종 검수 10/12: HUD.Layout is in these same MainGui units (no rescaling), and touch layouts keep their full window
	-- (the phone round decides the rail there: a 844x390 phone lost 21% and a bigger phone got a smaller window)
	local hl = C and type(C.HUD) == "table" and C.HUD.Layout or nil
	local tiles = type(hl) == "table" and type(hl.Rects) == "table" and hl.Rects.tiles or nil
	if not UserInputService.TouchEnabled and type(tiles) == "table" and type(tiles.Y) == "number" then
		local room = tiles.Y - FRAME.RailGap - (top + hang)
		if room >= FRAME.RailMinRoom and room < availH then availH = room end
	end
	local winW = math.max(280, math.min(WINDOW_MAX_W, w - 24))
	-- H-1 (게임성 개발 4): a registered window may ask for its own width (the bag's narrow / wide), never past the max
	local want = currentId ~= nil and REG.Opts[currentId] ~= nil and REG.Opts[currentId].Width or nil
	if type(want) == "function" then
		local ok, v = pcall(want)
		want = ok and v or nil
	end
	if type(want) == "number" and want == want then winW = math.max(280, math.min(want, WINDOW_MAX_W, w - 24)) end
	-- 창 꾸미기: the plate is as tall as its content (a story page, a shop with two rows ... keeps the world visible
	-- around it); registered fixed-body windows (tabs) keep the full height
	local maxH = math.min(WINDOW_MAX_H, availH)
	local winH = maxH
	local fixed = currentId ~= nil and REG.Opts[currentId] ~= nil and REG.Opts[currentId].FixedBody == true
	local ch = (not fixed) and FRAME.ContentH(s) or nil
	if ch then winH = math.clamp(math.ceil(hang + 8 + ch + FRAME.Bottom), FRAME.MinH, maxH) end
	FRAME.Fit.H = ch
	window.Size = UDim2.fromOffset(winW, winH)
	window.Position = UDim2.fromOffset(w / 2, top + hang + availH / 2)
	layoutChrome(s)
	FRAME.TellNotify(root.Visible and currentId ~= nil)
end

local function ensureRoot()
	if root and root.Parent then return true end
	local gui = getGui()
	if not gui then return false end
	if root then root:Destroy() end

	root = Instance.new("Frame")
	root.Name = "PanelsModal"
	root.BackgroundColor3 = Color3.new(0, 0, 0)
	root.BackgroundTransparency = 0.45
	root.BorderSizePixel = 0
	root.Active = true -- sinks clicks so the HUD's attack input ignores them
	root.ZIndex = ZINDEX
	root.Visible = false

	-- 창 꾸미기: the navy PanelCard plate (else the old dark code frame with its gold line)
	if UIKit and type(UIKit.ArtFrame) == "function" then
		window = UIKit.ArtFrame(FRAME.Body, { Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Active = true },
			{ BackgroundColor3 = theme.Bg, BackgroundTransparency = 0.04, CornerRadius = UDim.new(0, 16),
				StrokeColor = theme.Gold, StrokeThickness = 2, StrokeTransparency = 0.3 })
	else
		window = Instance.new("Frame")
		window.Name = "Window"
		window.AnchorPoint = Vector2.new(0.5, 0.5)
		window.BackgroundColor3 = theme.Bg
		window.BackgroundTransparency = 0.04
		window.BorderSizePixel = 0
		window.Active = true
		corner(window, 16)
	end
	window.Parent = root

	FRAME.BuildTitle()

	local function guarded(fn)
		return function()
			if os.clock() < inputGuardUntil then return end -- CR-L26
			local ok, err = pcall(fn)
			if not ok then Util.Warn(TAG, "button handler error: " .. tostring(err)) end
		end
	end
	closeButton = FRAME.RoundButton("Close", FRAME.CloseGlyph, T.Close, guarded(function()
		Panels.Close(true) -- only an explicit close gets the merchant's situational farewell
	end))
	backButton = FRAME.RoundButton("Back", FRAME.BackGlyph, T.Back, guarded(function()
		Panels.Open(type(openedFromMenu) == "string" and openedFromMenu or "Menu") -- BB13: the window it came from
	end))
	backButton.Visible = false

	content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Position = UDim2.fromOffset(14, 64)
	content.Size = UDim2.new(1, -28, 1, -76)
	content.CanvasSize = UDim2.new(0, 0, 0, 0)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.ScrollingDirection = Enum.ScrollingDirection.Y
	content.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	content.ScrollBarThickness = 6
	content.ScrollBarImageColor3 = theme.SubText
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 10)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = content
	-- 창 꾸미기: the plate follows the content height (one relayout per frame at most; tiny changes ignored)
	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		if FRAME.Fit.Queued or not (root and root.Visible) then return end
		FRAME.Fit.Queued = true
		task.defer(function()
			FRAME.Fit.Queued = false
			local _, _, _, s = canvas(root.Parent)
			local h = FRAME.ContentH(s)
			if h and (FRAME.Fit.H == nil or math.abs(h - FRAME.Fit.H) > 2) then layoutRoot() end
		end)
	end)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 2)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = content
	content.Parent = window

	-- BB13 FixedBody: a plain frame in the content's place (no scroll, no list), so a registered window's tabs stay put
	REG.Fixed = Instance.new("Frame")
	REG.Fixed.Name = "FixedBody"
	REG.Fixed.BackgroundTransparency = 1
	REG.Fixed.BorderSizePixel = 0
	REG.Fixed.ClipsDescendants = true
	REG.Fixed.Position = content.Position
	REG.Fixed.Size = content.Size
	REG.Fixed.Visible = false
	REG.Fixed.Parent = window

	root.Parent = gui
	layoutRoot()
	return true
end

local function clearContent()
	if not content then return end
	for _, ch in content:GetChildren() do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	if REG.Fixed then
		for _, ch in REG.Fixed:GetChildren() do ch:Destroy() end
	end
end

-- BB13: the registered window that was built last says goodbye (its Cleanup, e.g. a running key capture) before the
-- content goes away or another window is built; its kit.OnAttr callbacks end with it
function REG.CleanupBuilt()
	local id = REG.Built
	REG.Built = nil
	table.clear(REG.AttrFns)
	local o = id and REG.Opts[id]
	if o and type(o.Cleanup) == "function" then
		local ok, err = pcall(o.Cleanup)
		if not ok then Util.Warn(TAG, "cleanup of " .. tostring(id) .. ": " .. tostring(err)) end
	end
end

-- BB13: registered windows rebuild only on the attributes they list (opts.Rebuild); the built-in ones on REBUILD_ATTRS
function REG.WantsRebuild(id, name)
	local o = REG.Opts[id]
	if not o then return REBUILD_ATTRS[name] == true end
	return type(o.Rebuild) == "table" and o.Rebuild[name] == true
end

-- a window opened from another one (the menu, BB13 the settings window) gets a back button to it
local function openSub(id, arg)
	pendingFromMenu = currentId or "Menu"
	Panels.Open(id, arg)
end

------------------------------------------------------------------ panel builders: build(parent) -> update()?
local BUILDERS = {}

-- User-approved Nickname_Form_A. Reuse the existing parchment/ribbon and the empty gold card button;
-- input stays private to this client, and only the verified server attribute supplies the current name.
function NICK.Fit(label, pixels, bold, wrapped, scale)
	UIKit.ApplyFont(label, bold and Enum.FontWeight.Bold or Enum.FontWeight.Regular)
	label.RichText = false
	label.TextWrapped = wrapped == true
	label.TextStrokeTransparency = 1
	label:SetAttribute("PickerMeasureWhole", true)
	label:SetAttribute("PickerOutlineThickness", 0)
	local outline = label:FindFirstChild("Outline")
	if outline and outline:IsA("UIStroke") then outline.Transparency = 1 end
	local minimum = math.max(1, math.min(MIN_TEXT, math.floor(MIN_TEXT / scale)))
	UIKit.FitText(label, minimum, math.max(minimum, math.floor(pixels / scale)))
end

function NICK.Destroy()
	if NICK.UI then
		NICK.UI.Frame:Destroy()
		NICK.UI = nil
	end
end

function NICK.Layout(w, h, top, s)
	local u = NICK.UI
	if not u then return end
	local width = math.max(1, math.min(520, w * s - 24))
	local available = math.max(1, (h - top) * s - 16)
	local height = math.min(360, available)
	local gutter = math.min(22, width * 0.055)
	local bodyWidth = math.max(1, width - gutter * 2)
	local textWidth = math.max(1, bodyWidth - 6) -- leave room for the touch overflow scrollbar
	local titleWidth = math.max(1, math.min(width * 0.66, width - 116))
	local rs = ((Config.UIArt.Parts or {}).TitleRibbon or {}).Size -- the ribbon art's aspect (512 x 135)
	local titleHeight = titleWidth / ((typeof(rs) == "Vector2" and rs.Y > 0) and rs.X / rs.Y or 256 / 63)
	local bodyTop = math.max(68, titleHeight + 10)
	local currentText = "Current name: " .. Util.PlayerDisplayName(player)
	local noteText = u.Note.Text
	local currentHeight = math.max(24, select(1, UIKit.MeasureText(currentText, 14,
		u.Current.FontFace, textWidth)) + 3)
	local noteHeight = math.max(22, select(1, UIKit.MeasureText(noteText, 12,
		u.Note.FontFace, textWidth)) + 3)
	-- Font loading may yield; a closed/rebuilt dialog must not receive an obsolete layout.
	if NICK.UI ~= u or not u.Frame.Parent or u.Note.Text ~= noteText or u.Current.Text ~= currentText then return end
	local saveWidth = math.min(bodyWidth, math.max(180, width * 0.56))
	local saveHeight = math.max(48, saveWidth / 4)
	local inputY = currentHeight + 14
	local inputHeight = 64
	local noteY = inputY + inputHeight + 14
	local saveY = noteY + noteHeight + 16
	local bodyHeight = saveY + saveHeight + 10
	u.Frame.Size = UDim2.fromOffset(width / s, height / s)
	u.Frame.Position = UDim2.fromOffset(w / 2, top + available / (2 * s))
	u.TitleArt.Size = UDim2.fromOffset(titleWidth / s, titleHeight / s)
	u.TitleArt.Position = UDim2.new(0.5, 0, 0, 0)
	u.Close.Size = UDim2.fromOffset(48 / s, 48 / s)
	u.Close.Position = UDim2.new(1, -10 / s, 0, 12 / s)
	u.Scroll.Position = UDim2.fromOffset(gutter / s, bodyTop / s)
	u.Scroll.Size = UDim2.fromOffset(bodyWidth / s, math.max(1, height - bodyTop - 14) / s)
	u.Body.Size = UDim2.new(1, -6 / s, 0, bodyHeight / s)
	u.Current.Size = UDim2.new(1, 0, 0, currentHeight / s)
	u.InputArt.Position = UDim2.fromOffset(0, inputY / s)
	u.InputArt.Size = UDim2.new(1, 0, 0, inputHeight / s)
	u.Input.Position = UDim2.fromOffset(14 / s, 6 / s)
	u.Input.Size = UDim2.new(1, -28 / s, 1, -12 / s)
	u.Note.Position = UDim2.fromOffset(0, noteY / s)
	u.Note.Size = UDim2.new(1, 0, 0, noteHeight / s)
	u.Save.Position = UDim2.new(0.5, 0, 0, saveY / s)
	u.Save.Size = UDim2.fromOffset(saveWidth / s, saveHeight / s)
	u.Scroll.ScrollBarThickness = bodyHeight > height - bodyTop - 14 and math.ceil(4 / s) or 0
	u.Frame:SetAttribute("OverflowScroll", bodyHeight > height - bodyTop - 14)
	NICK.Fit(u.Title, 26, true, false, s)
	NICK.Fit(u.Current, 14, false, true, s)
	NICK.Fit(u.Input, 20, false, false, s)
	NICK.Fit(u.Note, 12, false, true, s)
	NICK.Fit(u.SaveLabel, 22, true, false, s)
	NICK.Fit(u.CloseLabel, 26, true, false, s)
end

function NICK.Update()
	local u = NICK.UI
	if not u then return end
	u.Current.Text = "Current name: " .. Util.PlayerDisplayName(player)
	local busy = NICK.Pending or player:GetAttribute("NicknameStatus") == "Busy"
	u.Save:SetAttribute("Disabled", busy)
	u.Save.Active = not busy
	u.SaveLabel.Text = busy and "Saving..." or "Save"
	u.Input.TextEditable = not busy
	local message = NICK.Message ~= "" and NICK.Message or NICK.Rule
	if u.Note.Text ~= message then
		u.Note.Text = message
		layoutRoot()
	end
end

function NICK.BindResult()
	if NICK.ResultConnection then return true end
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local result = folder and folder:FindFirstChild("NicknameResult")
	if not result or not result:IsA("RemoteEvent") then return false end
	NICK.ResultConnection = result.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or type(payload.Status) ~= "string"
			or type(payload.Message) ~= "string" or #payload.Message > 800 then return end
		NICK.Pending = false
		NICK.Request += 1 -- retire the local timeout; no retries are sent automatically
		NICK.Message = payload.Message
		-- Never turn the unfiltered draft into an attribute/HUD name, or replace a failed draft.
		NICK.Update()
	end)
	return true
end

function NICK.Submit()
	if os.clock() < inputGuardUntil or NICK.Pending
		or player:GetAttribute("NicknameStatus") == "Busy" then return end
	local draft = NICK.Draft or ""
	local ok, length = pcall(utf8.len, draft)
	if not ok or not length or length < 2 or length > 20 then
		NICK.Message = "Please enter 2-20 letters."
		NICK.Update()
		return
	end
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local intent = folder and folder:FindFirstChild("SetNickname")
	if not intent or not intent:IsA("RemoteEvent") or not NICK.BindResult() then
		NICK.Message = NICK.Unavailable
		NICK.Update()
		return
	end
	NICK.Request += 1
	local request = NICK.Request
	NICK.Pending = true
	NICK.Message = "Saving..."
	NICK.Update()
	local sent = pcall(function() Net.Get("SetNickname"):FireServer(draft) end)
	if not sent then
		NICK.Pending = false
		NICK.Message = player:GetAttribute("NicknameStatus") == "Busy" and "Checking the save..." or NICK.Unavailable
		NICK.Update()
		return
	end
	task.delay(15, function()
		if NICK.Request ~= request or not NICK.Pending then return end
		-- Busy remains server-owned. An absent listener must not leave the form locked forever.
		NICK.Pending = false
		NICK.Message = player:GetAttribute("NicknameStatus") == "Busy" and "Checking the save..." or NICK.Unavailable
		NICK.Update()
	end)
end

function NICK.Build()
	NICK.Destroy()
	if NICK.Draft == nil then
		NICK.Draft = player:GetAttribute("NicknameVerified") == true and Util.PlayerDisplayName(player) or ""
	end
	local u = {}
	u.Frame = UIKit.ArtFrame("PanelMain", { Name = "NicknameWindow", Parent = root,
		AnchorPoint = Vector2.new(0.5, 0.5), Active = true, ZIndex = ZINDEX + 1 })
	u.TitleArt = UIKit.ArtFrame("TitleRibbon", { Name = "TitleRibbon", Parent = u.Frame,
		AnchorPoint = Vector2.new(0.5, 0), ZIndex = ZINDEX + 2 })
	local rect = ((Config.UIArt.Parts or {}).TitleRibbon or {}).TextRect -- the words inside the ribbon's front band
	rect = type(rect) == "table" and rect or { 0.17, 0.18, 0.66, 0.63 }
	u.Title = UIKit.InkText({ Name = "Title", Parent = u.TitleArt, Text = T.Titles.Nickname,
		Position = UDim2.fromScale(rect[1], rect[2]), Size = UDim2.fromScale(rect[3], rect[4]), Outline = false })
	u.Close, u.CloseLabel = UIKit.ArtButton("BtnSpecial", { Name = "Close", Parent = u.Frame,
		Text = "X", TextStyle = "ink", AnchorPoint = Vector2.new(1, 0), ZIndex = ZINDEX + 3 }, function()
		if os.clock() >= inputGuardUntil then Panels.Close() end
	end)
	u.Scroll = UIKit.Create("ScrollingFrame", { Name = "NicknameContents", Parent = u.Frame,
		BackgroundTransparency = 1, BorderSizePixel = 0, Active = true, ClipsDescendants = true,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 0,
		ScrollBarImageColor3 = (Config.UIArt.Colors or {}).Ink or PALETTE.DarkText })
	u.Body = UIKit.Create("Frame", { Name = "Body", Parent = u.Scroll, BackgroundTransparency = 1 })
	u.Current = UIKit.InkText({ Name = "CurrentName", Parent = u.Body,
		Text = "Current name: " .. Util.PlayerDisplayName(player), Outline = false })
	u.InputArt = UIKit.ArtFrame("InputField", { Name = "InputFrame", Parent = u.Body })
	u.Input = UIKit.Create("TextBox", { Name = "NicknameInput", Parent = u.InputArt,
		BackgroundTransparency = 1, BorderSizePixel = 0, ClearTextOnFocus = false, MultiLine = false,
		Text = NICK.Draft, PlaceholderText = "StarKnight", RichText = false,
		TextColor3 = (Config.UIArt.Colors or {}).Ink or PALETTE.DarkText,
		PlaceholderColor3 = (Config.UIArt.Colors or {}).InkSoft or PALETTE.DarkText,
		TextXAlignment = Enum.TextXAlignment.Left })
	u.Note = UIKit.InkText({ Name = "NicknameStatus", Parent = u.Body,
		Text = NICK.Message ~= "" and NICK.Message or NICK.Rule, Outline = false })
	u.Save, u.SaveLabel = UIKit.ArtButton("CardHalo", { Name = "SaveNickname", Parent = u.Body,
		Text = "Save", TextStyle = "ink", AnchorPoint = Vector2.new(0.5, 0), ScaleType = Enum.ScaleType.Fit }, NICK.Submit,
		{ Color = (Config.UIArt.Colors or {}).Gold or theme.Gold, CornerRadius = UDim.new(0.5, 0) })
	if u.Save:IsA("ImageButton") then
		-- The existing text-free CardHalo bitmap's complete gold button, with its original aspect ratio.
		u.Save.ImageRectOffset = Vector2.new(94, 876)
		u.Save.ImageRectSize = Vector2.new(448, 112)
	end
	NICK.UI = u
	u.Input:GetPropertyChangedSignal("Text"):Connect(function()
		NICK.Draft = u.Input.Text
		if not NICK.Pending and NICK.Message ~= "" then NICK.Message = ""; NICK.Update() end
	end)
	u.Input.FocusLost:Connect(function(enterPressed)
		if enterPressed then NICK.Submit() end
	end)
	NICK.BindResult()
	NICK.Update()
	return NICK.Update
end

BUILDERS.Nickname = function() return NICK.Build() end

function WELCOME.Definition()
	local config = Config.Tutorial and Config.Tutorial.Welcome
	return type(config) == "table" and config[myFaction()] or nil
end

function WELCOME.Ready()
	return attr("DataLoaded", false) == true and attr("ClassChosen", false) == true
		and num("TutorialStep") == 0 and type(WELCOME.Definition()) == "table"
		and Config.Classes[attr("Class", "")] ~= nil and not isDead()
end

-- Existing panel, portrait and buttons only. Pages never advance the quest; only the final intent can.
BUILDERS.Welcome = function(parent)
	local def = WELCOME.Definition()
	if type(def) ~= "table" or type(def.Lines) ~= "table" or #def.Lines == 0 then
		addText(parent, T.WelcomeUnavailable, { Align = Enum.TextXAlignment.Center })
		return nil
	end
	local faction, page, pending, sentAt = myFaction(), 1, false, 0
	-- short phone screens (e.g. 749x361): a small face (round 3 #2: 64 px, so the guide still has a face) and smaller
	-- text, so Next / I'm In! never need a scroll
	local cam = workspace.CurrentCamera
	local short = cam ~= nil and cam.ViewportSize.Y < 520
	local face = short and 64 or 170
	local portraitRow = addRow(parent, face, 0)
	portraitRow.Name = "WelcomePortrait"
	if UIKit and type(UIKit.ArtImage) == "function" then
		-- the faction's guide (Config.UIArt PortraitGuide*: the Artisan guild guide for Neutral)
		local guide = "PortraitGuide" .. (faction == "Neutral" and "Artisan" or faction)
		local ok, portrait = pcall(UIKit.ArtImage, guide, {
			Name = "Guide", Parent = portraitRow, Size = UDim2.fromOffset(face, face), ScaleType = Enum.ScaleType.Fit,
		})
		if not ok then Util.Warn(TAG, "welcome portrait failed: " .. tostring(portrait)) end
	end
	addText(parent, def.Name, { Name = "WelcomeName", Size = short and 18 or 24, Color = theme.Gold,
		Align = Enum.TextXAlignment.Center, Font = theme.Font })
	local pageLabel = addText(parent, "", { Name = "WelcomePage", Size = short and 13 or 16, Color = theme.SubText,
		Align = Enum.TextXAlignment.Center })
	local line = addText(parent, "", { Name = "WelcomeLine", Size = short and 16 or 22, Align = Enum.TextXAlignment.Center })
	local typing = {}
	TYPE.Tap(typing, line)
	local status = addText(parent, "", { Name = "WelcomeStatus", Size = 16, Color = theme.SubText,
		Align = Enum.TextXAlignment.Center })
	local actions = addRow(parent, 64, 10)
	local readMore, nextButton, update
	-- 함께할게요 is there from page 1 (no forced reading); ▶ still pages through the lines; closing never accepts
	-- 검수 2026-10-09 (UI clutter review ⑤): one big [I'm In!] + a small ▶ (the next page, back to page 1 after the
	-- last); 'Later' is gone - the window's X does the same (closing never accepts)
	readMore = makeButton(actions, T.WelcomeMore, PALETTE.Button, UDim2.new(0, 64, 0, 60), function()
		if pending or TYPE.Finish(typing) then return end
		page = (page % #def.Lines) + 1; status.Text = ""; update()
	end)
	readMore.Name = "WelcomeReadMore"
	readMore.LayoutOrder = 2
	nextButton = makeButton(actions, T.WelcomeAccept, PALETTE.Free, UDim2.new(1, -74, 0, 60), function()
		if pending or currentId ~= "Welcome" or faction ~= myFaction() then return end
		if WELCOME.Ready() then
			pending, sentAt = true, os.clock()
			fire("AcceptTutorial") -- exact zero arguments; the server owns the saved step
			update()
		end
	end)
	nextButton.Name = "WelcomeNext"
	nextButton.LayoutOrder = 1
	update = function()
		if currentId ~= "Welcome" or not line.Parent then return end
		if num("TutorialStep") ~= 0 then Panels.Close(); return end
		if pending and os.clock() - sentAt >= 5 then
			pending = false; status.Text = T.WelcomeRetry
		end
		TYPE.Show(typing, line, tostring(def.Lines[page]), faction == "Neutral" and "Guild" or faction, page)
		pageLabel.Text = string.format("%d / %d", page, #def.Lines)
		nextButton.Text = pending and T.WelcomePending or T.WelcomeAccept
		setEnabled(readMore, not pending and #def.Lines > 1)
		setEnabled(nextButton, not pending and faction == myFaction() and WELCOME.Ready())
		if not pending and isDead() then status.Text = T.WaitRespawn
		elseif status.Text == T.WaitRespawn then status.Text = "" end
	end
	return update
end

BUILDERS.Menu = function(parent)
	local entries = {
		{ Text = T.MenuTravel, Id = "Travel" },
		-- 게임성 검수 10/12: the menu opens the bag once it exists (one item window); the old list only without it
		BUILDERS.Bag and { Text = T.MenuBag, Id = "Bag" } or { Text = T.MenuItems, Id = "Items" },
		{ Text = T.MenuRebirth, Id = "Rebirth" },
		{ Text = T.MenuClass, Id = "Class" },
		{ Text = T.MenuShop, Id = "Shop" },
		{ Text = T.MenuMap, Id = "Map" },
		{ Text = T.MenuNickname, Id = "Nickname" },
		{ Text = "Replay Opening", Id = "Intro" },
		-- P5: hide / show my name in server-wide chat announcements (server-saved, HideAnnounceName attribute)
		{ Text = attr("HideAnnounceName", false) == true and Config.Announce.Text.MenuHide or Config.Announce.Text.MenuShow,
			Id = "AnnounceName" },
	}
	-- BB13: a registered window with opts.Menu (fn -> its button text, or nil while it is not for this player) gets an
	-- entry after the bag (③-3: Crafting for artisans while crafting is on)
	local extra = {}
	for rid, o in REG.Opts do
		if type(o.Menu) == "function" and BUILDERS[rid] then
			local ok, text = pcall(o.Menu)
			if ok and type(text) == "string" and text ~= "" then table.insert(extra, { Text = text, Id = rid }) end
		end
	end
	table.sort(extra, function(a, b) return a.Id < b.Id end)
	for i, e in extra do table.insert(entries, 2 + i, e) end
	if not FRAME.TicketsOnSale() then -- 검수 2026-10-07: no "Coming soon" shop for kids until a ticket is on sale
		for i = #entries, 1, -1 do
			if entries[i].Id == "Shop" then table.remove(entries, i) end
		end
	end
	if num("TutorialStep") == 0 and attr("ClassChosen", false) == true and type(WELCOME.Definition()) == "table" then
		table.insert(entries, 1, { Text = T.MenuWelcome, Id = "Welcome" })
	end
	if num("VacationDays") > 0 then
		table.insert(entries, { Text = T.MenuVacation, Id = "Vacation" })
	end
	local rows = math.ceil(#entries / 2)
	local grid = Instance.new("Frame")
	grid.Name = "MenuGrid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Size = UDim2.new(1, 0, 0, rows * 70 + (rows - 1) * 14)
	grid.LayoutOrder = nextOrder()
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.fromOffset(200, 70)
	gl.CellPadding = UDim2.fromOffset(14, 14)
	gl.FillDirection = Enum.FillDirection.Horizontal
	gl.FillDirectionMaxCells = 2
	gl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = grid
	grid.Parent = parent

	local rebirthBtn, itemsBtn = nil, nil
	for _, e in entries do
		local id = e.Id
		local color = (id == "Vacation") and PALETTE.Free or PALETTE.Button
		local b = makeButton(grid, e.Text, color, UDim2.fromOffset(200, 70), function()
			if id == "Welcome" then
				if WELCOME.Ready() then fire("RequestTutorial") end
			elseif id == "AnnounceName" then
				fire("SetAnnounceName", attr("HideAnnounceName", false) ~= true) -- the menu redraws on the attribute
			elseif id == "Map" then
				local wm = C and C.WorldMap
				if wm and wm.Open then wm.Open() end
			elseif id == "Intro" then
				-- A23-9: replay only inside a town (safe and calm), never mid-fight
				local intro = C and C.Intro
				if attr("ZoneTown", false) ~= true or isDead() then
					toast("You can replay the opening inside a town.", "bad")
				elseif type(intro) == "table" and type(intro.Play) == "function" then
					Panels.Close()
					intro.Play(true)
				end
			else
				openSub(id)
			end
		end)
		b.TextSize = 22
		if id == "Rebirth" then rebirthBtn = b end
		if id == "Items" or id == "Bag" then itemsBtn = b end
	end

	addText(parent, T.MenuAltarHint, { Color = theme.Gold, Align = Enum.TextXAlignment.Center, Font = theme.Font })
	addText(parent, Config.Story.MarkLore, { Color = theme.SubText, Size = 16, Align = Enum.TextXAlignment.Center })

	return function()
		-- B14: '아이템' glows gold while I hold a scroll and have not opened the item list this session
		if itemsBtn then
			local hint = ITEMS.Hint()
			paintButton(itemsBtn, hint and theme.Gold or PALETTE.Button, hint and PALETTE.DarkText or theme.Text)
		end
		if not rebirthBtn then return end
		local ready = num("Level") >= Config.RebirthLevel(num("Rebirths"))
		rebirthBtn.Text = ready and T.MenuRebirthReady or T.MenuRebirth
		if ready then
			paintButton(rebirthBtn, theme.Gold, PALETTE.DarkText)
		else
			paintButton(rebirthBtn, PALETTE.Button, theme.Text)
		end
	end
end

BUILDERS.Travel = function(parent)
	local faction = myFaction()
	local rows = {}
	for _, dest in Config.Travel.Destinations do
		local destId = dest.Id
		-- CR-L28: 장인 길드's home IS Crossroads; the "Home" row already lists it
		if destId == "Crossroads" and faction ~= "None" and Config.HomeZoneId(faction) == "Crossroads" then continue end
		local zoneId = (destId == "Home") and Config.HomeZoneId(faction) or destId
		local zone = Config.Zones[zoneId]
		if zone then
			local row = Instance.new("Frame")
			row.Name = "Row_" .. destId
			row.BackgroundColor3 = PALETTE.Row
			row.BorderSizePixel = 0
			row.Size = UDim2.new(1, 0, 0, 68)
			row.LayoutOrder = nextOrder()
			corner(row, 10)
			row.Parent = parent

			local title = dest.Name
			if destId == "Home" and faction ~= "None" then title = dest.Name .. " (" .. zone.Name .. ")" end
			local nameLabel = placeLabel(row, title, 20, theme.Text, UDim2.fromOffset(14, 6), UDim2.new(1, -184, 0, 30))
			nameLabel.RichText = true
			local infoLabel = placeLabel(row, "", 15, theme.SubText, UDim2.fromOffset(14, 38), UDim2.new(1, -184, 0, 24))
			infoLabel.Font = BODY_FONT

			local btn = makeButton(row, T.TravelGo, PALETTE.Ticket, UDim2.fromOffset(156, 48), function()
				-- CR-L30: re-check at click time (the row refreshes only every UPDATE_INTERVAL)
				local reason = travelBlock(destId, zone, num("Level"), faction)
				if reason then
					toast(reason, "bad")
					return
				end
				fire("Travel", destId)
				Panels.Close()
			end)
			btn.AnchorPoint = Vector2.new(1, 0.5)
			btn.Position = UDim2.new(1, -10, 0.5, 0)

			table.insert(rows, {
				DestId = destId, ZoneId = zoneId, Zone = zone, Title = title,
				Name = nameLabel, Info = infoLabel, Button = btn,
			})
		end
	end

	return function()
		local level = num("Level")
		local recommended = Config.QuestZoneForLevel(math.max(1, level))
		local here = attr("ZoneId", "")
		for _, r in rows do
			local base = string.format(T.TravelInfoF, math.floor(r.Zone.MinLevel), r.Zone.PvP and T.PvP or T.Safe)
			if here == r.ZoneId then base ..= T.TravelHere end
			local reason, short = travelBlock(r.DestId, r.Zone, level, faction)
			r.Info.Text = reason or base
			r.Info.TextColor3 = reason and theme.Bad or theme.SubText
			r.Button.Text = short or T.TravelGo
			setEnabled(r.Button, reason == nil)
			local isRec = r.DestId ~= "Home" and r.ZoneId == recommended
			local badge = string.format(T.TravelRecommendF, cfgFmt("Recommended", T.Recommended))
			r.Name.Text = isRec and (r.Title .. badge) or r.Title
		end
	end
end

local function confirmRebirth(targetId)
	local reason = rebirthBlock(num("Level"), Config.RebirthLevel(num("Rebirths")), targetId)
	if reason then
		toast(reason, "bad")
		return
	end
	local body = string.format(T.RebirthConfirmBodyF, factionDef(targetId).Name)
	local mark = markPreview(myFaction(), targetId)
	if mark then body = body .. "\n" .. mark end
	confirm(T.RebirthConfirmTitle, body, T.RebirthConfirmOk, function()
		fire("Rebirth", targetId)
		Panels.Close()
	end)
end

BUILDERS.Rebirth = function(parent)
	local mine = myFaction()
	addText(parent, string.format(Config.Story.RebirthIntro), { Size = 19, Font = theme.Font })
	local infoLabel = addText(parent, "", { Color = theme.SubText, Size = 17 })
	local countLabel = addText(parent, "", { Color = theme.SubText, Size = 17 })

	local row = addRow(parent, 0, 10)
	local cols = {}
	local offered = FRAME.Factions(mine)
	for _, id in offered do
		local def = factionDef(id)
		local color = factionColor(id)
		local col = addColumn(row, 1 / #offered, -7, 4)
		local btn = makeButton(col, def.Name, color, UDim2.new(1, 0, 0, 64), function()
			confirmRebirth(id)
		end, contrastText(color))
		local bonus = addText(col, "", { Size = 17, Color = theme.Gold, Align = Enum.TextXAlignment.Center, Font = theme.Font })
		if id == mine then
			addText(col, T.RebirthCurrent, { Size = 15, Color = theme.SubText, Align = Enum.TextXAlignment.Center })
		end
		local mark = markPreview(mine, id)
		if mark then
			addText(col, mark, { Size = 15, Color = theme.SubText, Align = Enum.TextXAlignment.Center })
		end
		cols[id] = { Button = btn, Bonus = bonus }
	end

	addText(parent, T.RebirthResets, { Size = 16 })
	addText(parent, T.RebirthKeeps, { Size = 16 })
	local reasonLabel = addText(parent, "", { Color = theme.Bad, Size = 17, Font = theme.Font })

	return function()
		local level, reb = num("Level"), num("Rebirths")
		local req = Config.RebirthLevel(reb)
		infoLabel.Text = string.format(T.RebirthInfoF, math.floor(reb), math.floor(req), math.floor(level))

		local halo, horns = math.floor(gameNum("HaloCount")), math.floor(gameNum("HornsCount"))
		countLabel.Text = string.format(T.RebirthCountsF, halo, horns) -- Halo vs Horns only (A6)

		-- "others" = the underdog counts minus me (CR-L7: same counts as ProgressionService.rebirthBonusFor, which
		-- marks me active first and then subtracts me; an idle / just-joined me is not in the published counts)
		local uHalo, uHorns, selfIn = underdogCounts()
		local oHalo, oHorns = math.max(0, math.floor(uHalo)), math.max(0, math.floor(uHorns))
		if selfIn and mine == "Halo" then
			oHalo = math.max(0, oHalo - 1)
		elseif selfIn and mine == "Horns" then
			oHorns = math.max(0, oHorns - 1)
		end
		for id, col in cols do
			local bonus = rebirthBonus(id, oHalo, oHorns)
			local pct = math.floor(bonus * 100 + 0.5)
			if bonus > Config.Rebirth.BonusNormal + 1e-6 then
				col.Bonus.Text = string.format(T.RebirthBonusUnderdogF, pct)
			else
				col.Bonus.Text = string.format(T.RebirthBonusF, pct)
			end
		end

		local reason = rebirthBlock(level, req)
		local shown = reason
		for id, col in cols do
			local colReason = reason or rebirthBlock(level, req, id) -- CR-L9: only 장인 길드 waits for the bully stacks
			setEnabled(col.Button, colReason == nil)
			if shown == nil then shown = colReason end
		end
		reasonLabel.Text = shown or ""
		reasonLabel.Visible = shown ~= nil
	end
end

local function altarFree()
	local target = selectedTarget
	if not target then return end
	local reason = altarBlock(target)
	if reason then
		toast(reason, "bad")
		return
	end
	local lossText = altarLossText(myFaction())
	confirm(T.AltarConfirmTitle, string.format(T.AltarConfirmFreeF, factionDef(target).Name, lossText), T.ConfirmChange, function()
		fire("SwitchFaction", false, target)
		Panels.Close()
	end)
end

local function altarTicket()
	if num("FactionTickets") <= 0 then
		buy("Faction")
		return
	end
	local target = selectedTarget
	if not target then return end
	local reason = altarBlock(target)
	if reason then
		toast(reason, "bad")
		return
	end
	confirm(T.AltarConfirmTitle, string.format(T.AltarConfirmTicketF, factionDef(target).Name), T.ConfirmChange, function()
		fire("SwitchFaction", true, target)
		Panels.Close()
	end)
end

BUILDERS.Altar = function(parent)
	local cur = myFaction()
	if cur == "None" then
		addText(parent, fmtText("NeedFaction"), { Color = theme.Bad })
		return nil
	end
	local targets = {}
	for _, id in FRAME.Factions(nil) do
		if id ~= cur then table.insert(targets, id) end
	end
	if not selectedTarget or not table.find(targets, selectedTarget) then selectedTarget = targets[1] end

	addText(parent, string.format(T.AltarCurrentF, factionDef(cur).Name), { Size = 20, Font = theme.Font })

	local cardRow = addRow(parent, 0, 12)
	local cards = {}
	for _, id in targets do
		local def = factionDef(id)
		local color = factionColor(id)
		local card, st = makeCard(cardRow, UDim2.new(1 / #targets, -6, 0, 0), color, function()
			selectedTarget = id
			if currentUpdate then currentUpdate() end
		end)
		addText(card, def.Name, { Size = 22, Color = color, Align = Enum.TextXAlignment.Center, Font = theme.Font })
		if type(def.Pitch) == "string" and def.Pitch ~= "" then
			addText(card, def.Pitch, { Size = 15, Color = theme.SubText, Align = Enum.TextXAlignment.Center })
		end
		local sel = addText(card, T.Selected, { Size = 15, Color = theme.Gold, Align = Enum.TextXAlignment.Center, Font = theme.Font })
		cards[id] = { Card = card, Stroke = st, Selected = sel }
	end

	-- CR-L27: reason + [무료]/[티켓] right under the cards so they are on the first screen of a phone
	local reasonLabel = addText(parent, "", { Color = theme.Bad, Size = 17, Font = theme.Font })
	local optRow = addRow(parent, 0, 14)
	local freeCol = addColumn(optRow, 0.5, -7, 4)
	local freeBtn = makeButton(freeCol, cfgFmt("ChangeFree", T.FreeButton), PALETTE.Free, UDim2.new(1, 0, 0, 58), altarFree)
	local freeSub = addText(freeCol, "", { Size = 15, Align = Enum.TextXAlignment.Center })
	local ticketCol = addColumn(optRow, 0.5, -7, 4)
	local ticketBtn = makeButton(ticketCol, "", PALETTE.Ticket, UDim2.new(1, 0, 0, 58), altarTicket)
	local ticketSub = addText(ticketCol, "", { Size = 15, Align = Enum.TextXAlignment.Center })

	local loreLabel = addText(parent, "", { Color = theme.SubText, Size = 16 })
	local perksLabel = addText(parent, "", { Size = 16 })
	addText(parent, T.AltarRules, { Size = 15, Color = theme.SubText })
	addText(parent, string.format(T.AltarCooldownRuleF, math.max(1, math.floor(Config.Switch.Cooldown / 60 + 0.5))),
		{ Size = 15, Color = theme.SubText })

	return function()
		for id, c in cards do
			local isSel = id == selectedTarget
			c.Card.BackgroundColor3 = isSel and PALETTE.CardSelected or PALETTE.Card
			c.Stroke.Thickness = isSel and 4 or 2
			c.Selected.Visible = isSel
		end
		local target = selectedTarget
		local lore = factionLore(target)
		loreLabel.Text = lore
		loreLabel.Visible = lore ~= ""
		local perks = perksText(target)
		perksLabel.Text = perks
		perksLabel.Visible = perks ~= ""

		local lossText, loses = altarLossText(cur)
		freeSub.Text = lossText
		ticketCol.Visible = loses -- A7-4: free path loses nothing -> no ticket button

		local tickets = math.floor(num("FactionTickets"))
		if tickets > 0 then
			ticketBtn.Text = cfgFmt("ChangeTicket", T.TicketButtonF, tickets)
			ticketSub.Text = cfgFmt("KeepAll", T.TicketKeepAll)
			paintButton(ticketBtn, PALETTE.Ticket)
		else
			ticketBtn.Text = productLabel("Faction")
			ticketSub.Text = T.TicketBuyHint
			paintButton(ticketBtn, PALETTE.Buy)
		end

		local reason, short = altarBlock(target)
		reasonLabel.Text = reason or ""
		reasonLabel.Visible = reason ~= nil
		freeBtn.Text = short or cfgFmt("ChangeFree", T.FreeButton)
		setEnabled(freeBtn, reason == nil)
		setEnabled(ticketBtn, tickets <= 0 or reason == nil) -- buying stays possible; using follows the same rules
	end
end

local function classFree()
	local target = selectedClass
	if not target or target == currentClass() then return end
	local reason = classBlock()
	if reason then
		toast(reason, "bad")
		return
	end
	local lossText = classLossText()
	confirm(T.ClassConfirmTitle, string.format(T.ClassConfirmFreeF, className(target, myFaction()), lossText), T.ConfirmChange, function()
		fire("ChangeClass", target, false)
		Panels.Close()
	end)
end

local function classTicket()
	if num("ClassTickets") <= 0 then
		buy("Class")
		return
	end
	local target = selectedClass
	if not target or target == currentClass() then return end
	local reason = classBlock()
	if reason then
		toast(reason, "bad")
		return
	end
	confirm(T.ClassConfirmTitle, string.format(T.ClassConfirmTicketF, className(target, myFaction())), T.ConfirmChange, function()
		fire("ChangeClass", target, true)
		Panels.Close()
	end)
end

BUILDERS.Class = function(parent)
	if player:GetAttribute("ClassChosen") ~= true then
		addText(parent, T.ClassPickFirst, { Color = theme.SubText })
		return nil
	end
	local faction = myFaction()
	local cur = currentClass()
	if selectedClass == cur or (selectedClass ~= nil and Config.Classes[selectedClass] == nil) then selectedClass = nil end
	local accent = factionColor(faction)

	local cardRow = addRow(parent, 0, 10)
	local cards = {}
	local count = #Config.ClassOrder
	for _, id in Config.ClassOrder do
		local def = Config.Classes[id]
		if def then
			local card, st = makeCard(cardRow, UDim2.new(1 / count, -7, 0, 0), accent, function()
				if id == currentClass() then return end
				selectedClass = id
				if currentUpdate then currentUpdate() end
			end)
			addText(card, className(id, faction), { Size = 21, Color = theme.Gold, Align = Enum.TextXAlignment.Center, Font = theme.Font })
			addText(card, "(" .. genericClassName(id) .. ")", { Size = 15, Color = theme.SubText, Align = Enum.TextXAlignment.Center })
			addText(card, pickLine(id), { Size = 16, Align = Enum.TextXAlignment.Center, Font = theme.Font })
			addText(card, def.Desc or "", { Size = 15, Color = theme.SubText, Align = Enum.TextXAlignment.Center })
			if type(def.Stats) == "table" then
				addText(card, table.concat(def.Stats, "\n"), { Size = 15, Align = Enum.TextXAlignment.Center })
			end
			local badge = addText(card, "", { Size = 16, Color = theme.Gold, Align = Enum.TextXAlignment.Center, Font = theme.Font })
			cards[id] = { Card = card, Stroke = st, Badge = badge }
		end
	end

	local hint = addText(parent, T.ClassHint, { Color = theme.SubText, Align = Enum.TextXAlignment.Center })
	local options = addColumn(parent, 1, 0, 8)
	local header = addText(options, "", { Size = 19, Align = Enum.TextXAlignment.Center, Font = theme.Font })
	local reasonLabel = addText(options, "", { Color = theme.Bad, Size = 17, Align = Enum.TextXAlignment.Center, Font = theme.Font })
	local optRow = addRow(options, 0, 14)
	local freeCol = addColumn(optRow, 0.5, -7, 4)
	local freeBtn = makeButton(freeCol, cfgFmt("ChangeFree", T.FreeButton), PALETTE.Free, UDim2.new(1, 0, 0, 58), classFree)
	local freeSub = addText(freeCol, "", { Size = 15, Align = Enum.TextXAlignment.Center })
	local ticketCol = addColumn(optRow, 0.5, -7, 4)
	local ticketBtn = makeButton(ticketCol, "", PALETTE.Ticket, UDim2.new(1, 0, 0, 58), classTicket)
	local ticketSub = addText(ticketCol, "", { Size = 15, Align = Enum.TextXAlignment.Center })

	return function()
		local curNow = currentClass()
		if selectedClass == curNow then selectedClass = nil end
		for id, c in cards do
			local isCur = id == curNow
			local isSel = id == selectedClass
			c.Badge.Text = isCur and T.ClassCurrent or T.Selected
			c.Badge.Visible = isCur or isSel
			c.Card.BackgroundColor3 = isSel and PALETTE.CardSelected or PALETTE.Card
			c.Stroke.Thickness = isSel and 4 or 2
		end
		local sel = selectedClass
		hint.Visible = sel == nil
		options.Visible = sel ~= nil
		if not sel then return end

		header.Text = string.format(T.ClassHeaderF, className(sel, faction))
		local lossText, loses = classLossText()
		freeSub.Text = loses and (lossText .. "\n" .. T.ClassKeeps) or lossText
		ticketCol.Visible = loses -- A7-4: free path loses nothing -> no ticket button

		local tickets = math.floor(num("ClassTickets"))
		if tickets > 0 then
			ticketBtn.Text = cfgFmt("ChangeTicket", T.TicketButtonF, tickets)
			ticketSub.Text = cfgFmt("KeepAll", T.TicketKeepAll)
			paintButton(ticketBtn, PALETTE.Ticket)
		else
			ticketBtn.Text = productLabel("Class")
			ticketSub.Text = T.TicketBuyHint
			paintButton(ticketBtn, PALETTE.Buy)
		end

		local reason = classBlock()
		reasonLabel.Text = reason or ""
		reasonLabel.Visible = reason ~= nil
		setEnabled(freeBtn, reason == nil)
		setEnabled(ticketBtn, tickets <= 0 or reason == nil)
	end
end

-- Display-side checks only: ShopService repeats the exact-instance and 3D distance checks on every purchase.
function WSHOP.Finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function WSHOP.Access()
	if attr("DataLoaded", false) ~= true then return T.WeaponLoading end
	if isDead() then return cfgFmt("WaitRespawn", T.WaitRespawn) end
	if attr("ClassChosen", false) ~= true then return T.ClassPickFirst end
	local map = workspace:FindFirstChild("Map")
	local landmarks = map and map:FindFirstChild("Landmarks")
	local guild = landmarks and landmarks:FindFirstChild("ArtisanGuild")
	local anvil = guild and guild:FindFirstChild("Anvil")
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not map or (not map:IsA("Folder") and not map:IsA("Model")) or map.Parent ~= workspace
		or not landmarks or not landmarks:IsA("Folder") or landmarks.Parent ~= map
		or not guild or not guild:IsA("Model") or guild.Parent ~= landmarks
		or not anvil or not anvil:IsA("BasePart") or anvil.Parent ~= guild or not anvil.Anchored
		or not character or not character:IsDescendantOf(workspace)
		or not hrp or not hrp:IsA("BasePart") then return T.WeaponFar end
	local prompt = anvil:FindFirstChild(WSHOP.PromptName)
	if not prompt or not prompt:IsA("ProximityPrompt") or prompt.Parent ~= anvil or not prompt.Enabled then
		return T.WeaponFar
	end
	local limit, distance = prompt.MaxActivationDistance, (hrp.Position - anvil.Position).Magnitude
	if not WSHOP.Finite(limit) or limit <= 0 or not WSHOP.Finite(distance)
		or distance > math.min(WSHOP.Distance, limit) then return T.WeaponFar end
	return nil
end

-- UI round 2 #3 (검수 2026-10-07): [Show me the way] in the forge window opened from afar: a guide beam to the anvil
-- in the Crossroads, else to the way into the Crossroads (QuestTarget.Travel); the window closes so the beam shows
function WSHOP.ShowWay()
	local hud, qt = C and C.HUD, C and C.QuestTarget
	if type(hud) ~= "table" or type(hud.ShowGuide) ~= "function" then return false end
	local zone = attr("ZoneId", "")
	local target = nil
	if zone == "Crossroads" then
		local map = workspace:FindFirstChild("Map")
		local landmarks = map and map:FindFirstChild("Landmarks")
		local guild = landmarks and landmarks:FindFirstChild("ArtisanGuild")
		local anvil = guild and guild:FindFirstChild("Anvil")
		if anvil and anvil:IsA("BasePart") then target = anvil end
	elseif type(qt) == "table" and type(qt.Travel) == "function" then
		local ok, part = pcall(qt.Travel, "Crossroads", zone)
		if ok and typeof(part) == "Instance" and part:IsA("BasePart") then target = part end
	end
	if not target then return false end
	local ok = pcall(hud.ShowGuide, target, T.WeaponWayLabel)
	if ok then Panels.Close() end
	return ok
end

function WSHOP.CatalogLimit()
	local shop = Config.WeaponShop
	local cap = type(shop) == "table" and shop.MaxSoldTier
	if not WSHOP.Finite(cap) or cap ~= math.floor(cap) or cap < 1
		or cap > 3 or cap > Config.MaxWeaponTier then return nil end
	return cap
end

-- A23-127 (plan 10/13 §1-A #2): the Forge sells weapons only while Config.WeaponShop.Buy ~= false (게임성 개발 2's switch;
-- MaxSoldTier still lists the tiers, so enhancing / selling / equipping stay). Off: a weapon I do not own shows where it
-- comes from (Config.WeaponSource) and no buttons; an owned one keeps [Equip] / [Sell]
function WSHOP.Sells()
	local shop = Config.WeaponShop
	return not (type(shop) == "table" and shop.Buy == false)
end

function WSHOP.Owns(mask, tier)
	return bit32.band(mask, bit32.lshift(1, tier - 1)) ~= 0
end

-- B6/B14: re-equipping AND buying (a purchase always equips) wait for the PvP combat tag (the server refuses both)
function WSHOP.EquipBlock()
	if not inCombat() then return nil end
	local tx = Config.Loot and Config.Loot.Text
	return (tx and type(tx.EquipCombat) == "string" and tx.EquipCombat) or ITEMS.T.EquipCombatLong
end

function WSHOP.Offer(selectedTier)
	local cap = WSHOP.CatalogLimit()
	if not cap then return nil, T.WeaponInvalid end
	if not WSHOP.Finite(selectedTier) or selectedTier ~= math.floor(selectedTier)
		or selectedTier < 1 or selectedTier > cap then return nil, T.WeaponUnavailable end
	-- A23-34: 0 = bare hands / nothing owned yet (tier 1 is owned only after the M1_1 gift)
	local tier, level, ownedMask = attr("WeaponTier", 0), attr("Level"), attr("WeaponOwnedMask", 0)
	if not WSHOP.Finite(tier) or tier ~= math.floor(tier) or tier < 0 or tier > Config.MaxWeaponTier
		or not WSHOP.Finite(level) or level < 1 or not WSHOP.Finite(ownedMask)
		or ownedMask ~= math.floor(ownedMask) or ownedMask < 0
		or ownedMask > bit32.lshift(1, Config.MaxWeaponTier) - 1 then
		return nil, T.WeaponInvalid
	end
	local def = Config.Weapons[selectedTier]
	if type(def) ~= "table" or not WSHOP.Finite(def.Price) or def.Price < 0
		or (selectedTier > 1 and def.Price == 0) or def.Price ~= math.floor(def.Price)
		or not WSHOP.Finite(def.MinLevel) or def.MinLevel < 1 then return nil, T.WeaponInvalid end
	local bank, carried = attr("BankGold"), attr("CarriedGold")
	if not WSHOP.Finite(bank) or bank < 0 or not WSHOP.Finite(carried) or carried < 0 then
		return nil, T.WeaponInvalid
	end
	local total, faction = bank + carried, myFaction()
	if not WSHOP.Finite(total) then return nil, T.WeaponInvalid end
	local info = {
		Tier = selectedTier, Price = def.Price, SellPrice = math.floor(def.Price / 10),
		MinLevel = def.MinLevel, Level = level, Owned = WSHOP.Owns(ownedMask, selectedTier),
		Equipped = tier == selectedTier, EquippedTier = tier,
		Bank = bank, Carried = carried, Total = total,
		CurrentName = Config.WeaponName(tier, currentClass(), faction),
		Name = Config.WeaponName(selectedTier, currentClass(), faction),
	}
	local sellReason = selectedTier == 1 and T.WeaponStarterNoSell or (not info.Owned and T.WeaponNoSell or nil)
	if info.Equipped then return info, T.WeaponEquipped, sellReason end
	-- A23-34: tier 1 is never sold here; the blacksmith gives it after the first mission (ShopService says the same)
	if selectedTier == 1 and not info.Owned then return info, fmtText("WeaponFromQuest"), sellReason end
	if def.RequiresFaction and faction ~= "Halo" and faction ~= "Horns" and faction ~= "Neutral" then
		return info, fmtText("NeedFaction"), sellReason
	end
	-- A23-28 (user 2026-10-06): MinLevel gates buying AND equipping, an owned weapon too (server: ShopService /
	-- LootService); selling an owned weapon stays allowed below it
	if not Config.WeaponUsable(selectedTier, level) then
		return info, fmtText(info.Owned and "EquipNeedLevel" or "WeaponNeedLevel", def.MinLevel), sellReason
	end
	if not info.Owned and total < def.Price then
		return info, string.format(T.WeaponShortF, exactNumber(def.Price - total)), sellReason
	end
	return info, nil, sellReason
end

-- These are fixed situational lines, not a connection to an AI dialogue service.
-- A request alone is not a completed transaction: wait for the authoritative attributes.
function WSHOP.Reconcile(session)
	local pending = session and session.Pending
	if not pending then return end
	local info = WSHOP.Offer(pending.Tier)
	if not info then return end
	local done = (pending.Action == "Buy" and info.Owned and info.Equipped)
		or (pending.Action == "Equip" and info.Owned and info.Equipped)
		or (pending.Action == "Sell" and not info.Owned and not info.Equipped)
	if done then
		-- Re-equipping after a purchase/sale does not erase that visit's completed trade.
		if pending.Action ~= "Equip" or not session.LastAction then session.LastAction = pending.Action end
		session.Pending = nil
		session.CooldownUntil = math.max(session.CooldownUntil or 0, os.clock() + 0.4)
	end
end

function WSHOP.Farewell()
	local session = WSHOP.Session
	if not session or session.Class ~= currentClass() or session.Faction ~= myFaction() or WSHOP.Access() then return nil end
	WSHOP.Reconcile(session)
	if session.Pending then return T.WeaponByePending end
	if session.LastAction == "Buy" then return T.WeaponByeBuy end
	if session.LastAction == "Sell" then return T.WeaponByeSell end
	if session.LastAction == "Equip" then return T.WeaponByeEquip end
	return T.WeaponByeBrowse
end

-- A23-12 item list (menu → 아이템): owned weapons (+N, equip), scrolls (use → pick weapon(s) → confirm with the
-- success rate and the failure result before anything is sent), materials (sold at the blacksmith anvil).
-- Display only: the server re-checks everything. B11: items and per-tier +N arrive only on the owner's "Inventory"
-- remote ({ Items = { [id] = n }, Enhance = { [tier] = n } }); the last payload is cached in ITEMS.Data (empty until the
-- first one). A new payload or a weapon attribute change rebuilds the open list in place (scroll kept, no input
-- guard); the chosen scroll step (ITEMS.Mode) survives those rebuilds and a scroll use, so the next try is one tap.
ITEMS = {
	Mode = nil, -- nil | { Item = id, Tier?, From?, To? }
	Rebuild = function(_keep) end, -- set to queueRebuild below (defined later in this file)
	Attrs = { WeaponOwnedMask = true, WeaponTier = true, Level = true }, -- data rebuilds of the open list
	Data = { Items = {}, Enhance = {}, Seen = {} }, -- last "Inventory" payload (validated)
	Version = 0, -- +1 per payload
	-- { Kind = "Use", SentAt, ReadyAt, Item, Count, Answered? } | { Kind = "Equip", SentAt, ReadyAt, Tier, WeaponTier, Answered? }
	Pending = nil,
	-- review: the server drops a 2nd UseItem / EquipWeapon inside Config.RateLimits[key] WITHOUT a reply, so the client
	-- never sends inside that interval (+ GapMargin for network jitter): os.clock() when the next send is allowed
	ReadyAt = { UseItem = 0, EquipWeapon = 0 },
	GapMargin = 0.15,
	SellPending = nil, -- { SentAt, Ver } for the blacksmith "재료 팔기"
	PendingTimeout = 3, -- s without an answer -> T.Slow (a refused request only gets the server toast)
	Result = nil, -- last scroll result from the Fx "Enhance" payload (Panels.OnEnhanceResult)
	ResultAt = 0,
	Note = nil, -- one-off status line (timeout)
	Seen = false, -- the item list was opened this session (menu '아이템' glow until then)
	T = {
		-- B14 / B9 (2026-10-05 loot review)
		Pending = "Checking the result…",
		Slow = "No result yet. Check the alerts and tap again.",
		UseCombat = "You can't use scrolls during a fight.", -- fallback for Config.Loot.Text.UseCombat
		EquipPending = "Checking…",
		EquipCombat = "In a fight",
		EquipLevelF = "From Lv %d", -- A23-28: owned but below the weapon's MinLevel (the server refuses the equip)
		EquipCombatLong = "You can't change weapons during a fight.", -- fallback for Config.Loot.Text.EquipCombat
		FailDownF = "On a fail there's a %d%% chance it drops one step. Weapons never break!", -- Config.Loot.FailDropChance
		FailKeep = "Nothing changes on a fail. Weapons never break!",
		OverflowF = "Max is +%d, so it only goes up +%d", -- (MaxEnhance = 10 → "+10이라")
		MoveOverflowF = "The extra +%d stays on the sending weapon (no enhancement is ever lost)",
		MoveSafe = "No enhancement is ever lost",
		SellPending = "Checking the sale…",
		SellKeepEnhF = "Your +%d is saved (you get it back if you own it again)",
		Plus = " +%d",
		Weapons = "My Weapons", Scrolls = "Scrolls", Materials = "Materials",
		-- A23-34 / A23-74 weapon first: Otto hands it over right after the Guide's first quest
		NoWeapons = "Bare hands for now. Accept the Guide's first quest and Otto gives you your first weapon.",
		Drops = "What Monsters Drop", DropsNone = "Defeat monsters to see what they drop here.", -- P7
		DropLine = "%s: %s", DropPart = "%s %s", DropJackpot = "★Legendary weapon (jackpot) 1 in %s", DropPotion = "%s potion",
		DropWeapon = "%s weapon",
		DropsNowF = "Your drops now: ×%s (%s)", -- 검수 10/10: (multiplier, reasons) - only when it is not x1
		DropCount = "%s ×%d", -- a row that gives N > 1 at once (the king's 8 candies); symbols only, same in English
		NoScrolls = "None yet. Monsters drop them sometimes!",
		NoMaterials = "None yet. Monsters drop them!",
		Equipped = "Equipped", Equip = "Equip",
		Use = "Use", Cancel = "Cancel",
		Legend = "★ ",
		Strongest = " · strongest",
		ScrollEnh = "%s ×%d · +%d on success",
		ScrollMove = "%s ×%d · move all of a weapon's + to another",
		MaterialLine = "%s ×%d · %d gold each",
		MaterialHint = "Sell your materials all at once at the Forge anvil.",
		PickEnhance = "Pick the weapon to enhance.",
		PickFrom = "Pick the weapon to send its + from (+1 or more).",
		PickTo = "Pick the weapon to get +%d.",
		Enhance = "Enhance", Max = "Max", From = "Send", To = "Receive",
		ConfirmEnh = "%s +%d → +%d on success (attack %d%%)\nChance %d%% · %s",
		FailZero = "Stays at +0 on a fail. Weapons never break!",
		-- B9: no particle after the number ("+%d이" was wrong for +2/+4/+5/+9)
		ConfirmMove = "%s +%d → %s +%d\nChance %d%% · on success the receiving weapon becomes +%d · on a fail nothing changes",
		Go = "Enhance", GoMove = "Move",
		SellMat = "Sell materials · %d → %s gold", SellNone = "No materials to sell",
	},
}

-- B11: the owner's "Inventory" payload. Only ids of Config.Loot.Items with a count >= 1 and tiers 1..MaxWeaponTier
-- (+0..MaxEnhance) are kept; anything else is ignored (the server keeps unknown ids in the save, the list hides them).
function ITEMS.OnInventory(payload)
	if type(payload) ~= "table" then return end
	ITEMS.Raw = payload -- H-1: the bag (BagUI) takes this copy when its own listener came too late (Panels.LastInventory)
	local loot = Config.Loot
	local items, enh = {}, {}
	if type(payload.Items) == "table" then
		for id, n in payload.Items do
			if type(id) == "string" and loot.Items[id] ~= nil and type(n) == "number" and n == n and n >= 1 and n < math.huge then
				items[id] = math.floor(n)
			end
		end
	end
	local src = payload.Enhance
	if type(src) == "table" then
		for tier = 1, Config.MaxWeaponTier do
			local n = src[tier]
			if n == nil then n = src[tostring(tier)] end
			if type(n) == "number" and n == n and n > -math.huge and n < math.huge then
				enh[tier] = math.clamp(math.floor(n), 0, loot.MaxEnhance)
			end
		end
	end
	local seen = {}
	if type(payload.Seen) == "table" then
		for kind, v in payload.Seen do
			if type(kind) == "string" and v == true and loot.Tables[kind] then seen[kind] = true end
		end
	end
	ITEMS.Data = { Items = items, Enhance = enh, Seen = seen }
	ITEMS.Version += 1
	ITEMS.CheckPending()
	if currentId == "Items" then ITEMS.Rebuild(true) end -- the blacksmith polls ITEMS.Data in its update
end

-- H-1 bag: the last "Inventory" payload as it came (BagUI validates it; nil before the first one)
function Panels.LastInventory()
	return ITEMS.Raw
end

-- A23-79: another window's look at the cached "Inventory" payload (KingDiary's candy jar): the count of one item id
function Panels.ItemCount(id)
	local n = ITEMS.Data and ITEMS.Data.Items and ITEMS.Data.Items[id]
	return type(n) == "number" and n or 0
end

-- binds the owner-only remote early (Init) so the first payload after PlayerReady is never missed; an old server
-- without the remote leaves the cache empty
function ITEMS.Bind()
	local function hook(r)
		r.OnClientEvent:Connect(function(payload)
			local ok, err = pcall(ITEMS.OnInventory, payload)
			if not ok then warnThrottled("inventory update error: " .. tostring(err)) end
		end)
	end
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = folder and folder:FindFirstChild("Inventory")
	if remote and remote:IsA("RemoteEvent") then
		hook(remote)
		return
	end
	task.spawn(function()
		local f = ReplicatedStorage:WaitForChild("Remotes", 30)
		local r = f and f:WaitForChild("Inventory", 30)
		if r and r:IsA("RemoteEvent") then hook(r) else Util.Warn(TAG, "remote missing: Inventory") end
	end)
end

-- seconds between two sends of one remote: the server's rate limit + ITEMS.GapMargin
function ITEMS.Gap(key)
	local rl = Config.RateLimits
	local v = type(rl) == "table" and tonumber(rl[key]) or nil
	if v == nil or v ~= v or v < 0 then v = (key == "EquipWeapon") and 0.3 or 0.4 end
	return v + ITEMS.GapMargin
end

-- fires UseItem / EquipWeapon and records the pending request; false when the server would still drop it
function ITEMS.Send(key, pending, ...)
	local now = os.clock()
	if ITEMS.Pending or now < (ITEMS.ReadyAt[key] or 0) then return false end
	fire(key, ...)
	pending.SentAt, pending.ReadyAt = now, now + ITEMS.Gap(key)
	ITEMS.ReadyAt[key] = pending.ReadyAt
	ITEMS.Pending, ITEMS.Note = pending, nil
	return true
end

-- clears a pending request once its answer is visible AND the server's rate-limit interval has passed (or after
-- PendingTimeout); true when something changed. An answered request keeps the confirm / equip button busy until
-- ReadyAt, so the next tap is never dropped silently (the 0.25 s update rebuilds once it clears).
function ITEMS.CheckPending()
	local now, changed = os.clock(), false
	local p = ITEMS.Pending
	if p then
		local done = p.Answered == true
		if not done then
			if p.Kind == "Use" then
				done = ITEMS.Count(ITEMS.Data.Items, p.Item) ~= p.Count or ITEMS.ResultAt > p.SentAt
			elseif p.Kind == "Equip" then
				done = math.floor(num("WeaponTier")) ~= p.WeaponTier
			end
			if done then p.Answered, changed = true, true end
		end
		if done then
			if now >= (p.ReadyAt or 0) then ITEMS.Pending, changed = nil, true end
		elseif now - p.SentAt >= ITEMS.PendingTimeout then
			ITEMS.Pending, ITEMS.Note, changed = nil, ITEMS.T.Slow, true
		end
	end
	local sp = ITEMS.SellPending
	if sp and (ITEMS.Version ~= sp.Ver or now - sp.SentAt >= ITEMS.PendingTimeout) then
		ITEMS.SellPending, changed = nil, true
	end
	return changed
end

function ITEMS.HasScroll()
	for id, n in ITEMS.Data.Items do
		local def = Config.Loot.Items[id]
		if def and def.Kind ~= "Material" and type(n) == "number" and n >= 1 then return true end
	end
	return false
end

-- B14: the menu '아이템' (and the HUD 메뉴 square) glow while I hold a scroll and have not opened the list this session
function ITEMS.Hint()
	return not ITEMS.Seen and ITEMS.HasScroll()
end

-- B14: tap height in canvas px. Touch: >= GUARD.TouchTarget real px (60 canvas = 45 px at the 0.75 phone UIScale).
function ITEMS.TapH(desktop)
	if not UserInputService.TouchEnabled then return desktop or 44 end
	local _, _, _, s = canvas(root and root.Parent)
	return math.max(60, math.ceil(GUARD.TouchTarget / s))
end

function ITEMS.PlusText(n)
	return n > 0 and string.format(ITEMS.T.Plus, n) or ""
end

function ITEMS.Count(items, id)
	local n = items[id]
	return (type(n) == "number" and n == n) and math.floor(n) or 0
end

function ITEMS.Enh(enh, tier)
	local n = enh[tier] or enh[tostring(tier)]
	return (type(n) == "number" and n == n) and math.clamp(math.floor(n), 0, Config.Loot.MaxEnhance) or 0
end

function ITEMS.Owns(mask, tier)
	return bit32.btest(mask, bit32.lshift(1, tier - 1))
end

-- what the blacksmith's sell-all really sells: monster materials only (게임성 검수 10/12, LootService: a thing with a Source -
-- gathered "Gather", boss "Boss" - is sold one at a time later, never in the sell-all), so the count / gold match the pay
function ITEMS.MaterialValue(items)
	local count, gold = 0, 0
	for id, def in Config.Loot.Items do
		if def.Kind == "Material" and def.Source == nil then
			local n = ITEMS.Count(items, id)
			count += n
			gold += n * def.Sell
		end
	end
	return count, gold
end

-- one list row: label on the left, an optional button on the right (B14: button = ITEMS.TapH, row = button + 14)
function ITEMS.Row(parent, text, color, buttonText, buttonColor, enabled, onClick, sub, icon)
	local tapH = ITEMS.TapH(44)
	local row = Instance.new("Frame")
	row.Name = "ItemRow"
	row.BackgroundColor3 = PALETTE.Row
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, 0, 0, tapH + 14)
	row.LayoutOrder = nextOrder()
	corner(row, 10)
	row.Parent = parent
	local hasButton = buttonText ~= nil
	-- optional item art on a light tile; the text moves right of it. `icon` = a Config.Loot.Items id (its Icon, plus the
	-- scroll Band tinted in the item's colour) or a plain Config.UIArt key (UIKit.ItemIcon)
	local img = type(icon) == "string" and UIKit.ItemIcon(icon, {
		Name = "Icon",
		Position = UDim2.fromScale(0.08, 0.08),
		Size = UDim2.fromScale(0.84, 0.84),
		ScaleType = Enum.ScaleType.Fit,
	}) or nil
	local left = 14
	if img then
		local side = tapH
		local tile = Instance.new("Frame")
		tile.Name = "IconTile"
		tile.BackgroundColor3 = Color3.fromRGB(246, 238, 220) -- cream: keeps the icons' navy rim visible
		tile.BorderSizePixel = 0
		tile.AnchorPoint = Vector2.new(0, 0.5)
		tile.Position = UDim2.new(0, 8, 0.5, 0)
		tile.Size = UDim2.fromOffset(side, side)
		corner(tile, 8)
		tile.Parent = row
		img.Parent = tile
		left = 8 + side + 10
	end
	local w = UDim2.new(1, (hasButton and -170 or -28) - (left - 14), sub and 0.58 or 1, 0)
	placeLabel(row, text, 18, color or theme.Text, UDim2.fromOffset(left, 0), w)
	if sub then
		-- second line: grade · where it comes from (design §1 B1/B4)
		placeLabel(row, sub, 14, theme.SubText, UDim2.new(0, left, 0.52, 0),
			UDim2.new(1, (hasButton and -170 or -28) - (left - 14), 0.42, 0))
	end
	local b = nil
	if hasButton then
		b = makeButton(row, buttonText, buttonColor or PALETTE.Button, UDim2.fromOffset(140, tapH), onClick)
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -8, 0.5, 0)
		b.TextSize = 18
		setEnabled(b, enabled ~= false)
	end
	return row, b
end

function ITEMS.WeaponName(tier)
	return Config.WeaponName(tier, currentClass(), myFaction())
end

-- "★★★ 숲도둑 황금 지팡이" in the grade color; stars are rarity, not power
function ITEMS.GradeLabel(tier)
	local g = Config.WeaponGrade(tier)
	return Config.WeaponStars(tier) .. " " .. ITEMS.WeaponName(tier), g.Color, g
end

-- the chosen step, dropped back to its last still-valid part (used-up scroll, weapon at +Max, empty source, sold)
function ITEMS.ValidMode(items, enh, owns)
	local m = ITEMS.Mode
	local def = m and Config.Loot.Items[m.Item]
	if not m or not def or def.Kind == "Material" or ITEMS.Count(items, m.Item) < 1 then
		ITEMS.Mode = nil
		return nil
	end
	local max = Config.Loot.MaxEnhance
	if def.Kind == "Enhance" then
		if m.Tier and (not owns(m.Tier) or ITEMS.Enh(enh, m.Tier) >= max) then m = { Item = m.Item } end
	else
		if m.From and (not owns(m.From) or ITEMS.Enh(enh, m.From) <= 0) then m = { Item = m.Item } end
		if m.To and (not owns(m.To) or m.To == m.From or ITEMS.Enh(enh, m.To) >= max) then
			m = { Item = m.Item, From = m.From }
		end
	end
	ITEMS.Mode = m
	return m
end

-- the last scroll result in the server's own words (Config.Loot.Text), or nil
function ITEMS.ResultText()
	local r = ITEMS.Result
	if not r then return nil end
	local TX = (Config.Loot and Config.Loot.Text) or {}
	local function f(key, ...)
		local s = TX[key]
		if type(s) ~= "string" then return nil end
		local ok, out = pcall(string.format, s, ...)
		return ok and out or nil
	end
	local name = ITEMS.WeaponName(r.Tier)
	if r.Move then
		local fromName = r.From and ITEMS.WeaponName(r.From) or ""
		local left = r.From and ITEMS.Enh(ITEMS.Data.Enhance, r.From) or 0
		if r.Success then return f("MoveOk", fromName, left, name, r.After) end
		return f("MoveFail", fromName, left)
	end
	if r.Success then
		return f("EnhanceOk", name, r.Before, r.After, math.floor(Config.EnhanceMult(r.Before) * 100 + 0.5),
			math.floor(Config.EnhanceMult(r.After) * 100 + 0.5))
	end
	if r.After < r.Before then return f("EnhanceFailDown", name, r.Before, r.After) end
	return f("EnhanceFailKeep", name, r.Before)
end

-- the failure line of the enhance confirm (B9: the chance comes from Config.Loot.FailDropChance)
function ITEMS.FailText(before)
	if before <= 0 then return ITEMS.T.FailZero end
	local chance = tonumber(Config.Loot.FailDropChance) or 0
	if chance <= 0 then return ITEMS.T.FailKeep end
	return string.format(ITEMS.T.FailDownF, math.floor(math.clamp(chance, 0, 1) * 100 + 0.5))
end

BUILDERS.Items = function(parent)
	local L, loot = ITEMS.T, Config.Loot
	if attr("DataLoaded", false) ~= true then
		addText(parent, T.WeaponLoading, { Name = "ItemsLoading", Color = theme.SubText })
		return nil -- DataLoaded is a REBUILD_ATTRS key: the list appears once the save is loaded
	end
	ITEMS.CheckPending()
	local items, enh = ITEMS.Data.Items, ITEMS.Data.Enhance
	local mask = math.max(0, math.floor(num("WeaponOwnedMask"))) -- A23-34: 0 = nothing owned yet (bare hands)
	local equipped = math.floor(num("WeaponTier"))
	local level = math.max(1, math.floor(num("Level")))
	local function owns(tier)
		return type(tier) == "number" and tier >= 1 and tier <= Config.MaxWeaponTier
			and (ITEMS.Owns(mask, tier) or tier == equipped)
	end
	local mode = ITEMS.ValidMode(items, enh, owns)
	local def = mode and loot.Items[mode.Item]
	local pending = ITEMS.Pending
	local combat = inCombat()
	local tapH = ITEMS.TapH(52)
	local function setMode(m)
		ITEMS.Mode, ITEMS.Note = m, nil
		ITEMS.Rebuild()
	end

	-- B14: waiting for the server / the last scroll result / a timeout note, above everything else.
	-- B6 review: a chosen scroll during the PvP combat tag says why it cannot be used (the server refuses it too)
	local status, statusColor = nil, theme.SubText
	if pending and pending.Kind == "Use" and not pending.Answered then
		status, statusColor = L.Pending, theme.Gold
	elseif combat and mode and def then
		local tx = loot.Text
		status, statusColor = (type(tx) == "table" and type(tx.UseCombat) == "string" and tx.UseCombat) or L.UseCombat, theme.Bad
	elseif ITEMS.Note then
		status, statusColor = ITEMS.Note, theme.Bad
	else
		status = ITEMS.ResultText()
		if status and ITEMS.Result and ITEMS.Result.Success then statusColor = theme.Good end
	end
	if status then addText(parent, status, { Name = "ItemStatus", Color = statusColor, Size = 17 }) end
	-- A23-109 (game dev 1): the quick items (the potions) with [1] [2] [3] = which quick slot holds them (QuickSlots.luau)
	if not mode and C and type(C.QuickSlots) == "table" and type(C.QuickSlots.BagRows) == "function" then
		addText(parent, "Quick slots", { Name = "QuickTitle", Size = 18, Color = theme.Gold })
		pcall(C.QuickSlots.BagRows, parent, REG.Kit())
	end

	-- the chosen scroll's step + confirmation (rate and failure result shown before sending)
	if mode and def then
		local text, go = nil, nil
		if def.Kind == "Enhance" then
			if mode.Tier then
				local before = ITEMS.Enh(enh, mode.Tier)
				local plus = math.max(0, math.floor(tonumber(def.Plus) or 0))
				local after = math.min(loot.MaxEnhance, before + plus)
				text = string.format(L.ConfirmEnh, ITEMS.WeaponName(mode.Tier), before, after,
					math.floor(Config.EnhanceMult(after) * 100 + 0.5), math.floor(def.Chance * 100 + 0.5),
					ITEMS.FailText(before))
				-- B9: +8/+9 with a +3/+5 scroll stops at the cap
				if before + plus > loot.MaxEnhance then
					text ..= "\n" .. string.format(L.OverflowF, loot.MaxEnhance, after - before)
				end
				local item, tier = mode.Item, mode.Tier
				go = { item, tier } -- UseItem args
			else
				text = L.PickEnhance
			end
		elseif mode.From and mode.To then
			local amount, target = ITEMS.Enh(enh, mode.From), ITEMS.Enh(enh, mode.To)
			local after = math.min(loot.MaxEnhance, target + amount)
			text = string.format(L.ConfirmMove, ITEMS.WeaponName(mode.From), amount, ITEMS.WeaponName(mode.To),
				target, math.floor(def.Chance * 100 + 0.5), after)
			-- B9: what does not fit under the cap stays on the source (LootService "손해 0" rule)
			local left = amount - (after - target)
			text ..= "\n" .. (left > 0 and string.format(L.MoveOverflowF, left) or L.MoveSafe)
			local item, from, to = mode.Item, mode.From, mode.To
			go = { item, from, to } -- UseItem args
		elseif mode.From then
			text = string.format(L.PickTo, ITEMS.Enh(enh, mode.From))
		else
			text = L.PickFrom
		end
		addText(parent, def.Name .. "\n" .. text, { Name = "ItemStep", Color = theme.Gold, Size = 18 })
		local actions = addRow(parent, tapH + 4, 10)
		if go then
			local b = makeButton(actions, def.Kind == "Enhance" and L.Go or L.GoMove, PALETTE.Free, UDim2.new(0.5, -5, 0, tapH), function()
				if ITEMS.Pending or inCombat() then return end
				-- B14: the scroll and weapon(s) stay chosen; the next try is one tap once the answer is in (and the
				-- server's UseItem interval has passed: ITEMS.Send refuses earlier taps instead of losing them)
				if ITEMS.Send("UseItem", { Kind = "Use", Item = mode.Item, Count = ITEMS.Count(ITEMS.Data.Items, mode.Item) },
					table.unpack(go)) then
					ITEMS.Rebuild(true)
				end
			end)
			b.Name = "ItemConfirm"
			if pending then
				b.Text = L.Pending
				setEnabled(b, false)
			elseif combat then
				b.Text = L.EquipCombat -- "전투 중": the server refuses scrolls in PvP combat (status line says why)
				setEnabled(b, false)
			end
		end
		local cancel = makeButton(actions, L.Cancel, PALETTE.Button, UDim2.new(0.5, -5, 0, tapH), function() setMode(nil) end)
		cancel.Name = "ItemCancel"
	end

	-- weapons (legendary first, then highest tier)
	addText(parent, L.Weapons, { Color = theme.Gold, Font = theme.Font, Size = 20 })
	local order = {}
	for tier = Config.MaxWeaponTier, 1, -1 do
		if owns(tier) then table.insert(order, tier) end
	end
	if #order == 0 then addText(parent, L.NoWeapons, { Size = 17, Color = theme.SubText }) end
	-- strongest first (real damage at my level with each weapon's own +N); stars are only rarity
	local power = {}
	for _, t in order do power[t] = Config.WeaponDamage(t, level, ITEMS.Enh(enh, t)) end
	table.sort(order, function(a, b)
		if power[a] ~= power[b] then return power[a] > power[b] end
		return a > b
	end)
	for i, tier in order do
		local plus = ITEMS.Enh(enh, tier)
		local name, color, grade = ITEMS.GradeLabel(tier)
		local label = name .. (plus > 0 and string.format("  +%d", plus) or "")
		local sub = grade.Name .. " · " .. Config.WeaponSource(tier) .. (i == 1 and #order > 1 and L.Strongest or "")
		local bText, bColor, enabled, click = nil, PALETTE.Button, true, nil
		if mode and def and def.Kind == "Enhance" then
			bText = plus >= loot.MaxEnhance and L.Max or L.Enhance
			enabled = plus < loot.MaxEnhance
			bColor = mode.Tier == tier and PALETTE.CardSelected or PALETTE.Ticket
			click = function() setMode({ Item = mode.Item, Tier = tier }) end
		elseif mode and def and def.Kind == "Transfer" then
			if not mode.From then
				bText, enabled, bColor = L.From, plus > 0, PALETTE.Ticket
				click = function() setMode({ Item = mode.Item, From = tier }) end
			elseif tier == mode.From then
				bText, enabled, bColor = L.From, true, PALETTE.CardSelected
				click = function() setMode({ Item = mode.Item }) end
			else
				bText = plus >= loot.MaxEnhance and L.Max or L.To
				bColor = mode.To == tier and PALETTE.CardSelected or PALETTE.Free
				enabled = plus < loot.MaxEnhance
				click = function() setMode({ Item = mode.Item, From = mode.From, To = tier }) end
			end
		elseif tier == equipped then
			bText, enabled = L.Equipped, false
		elseif not Config.WeaponUsable(tier, level) then
			-- A23-28 (user 2026-10-06): equipping keeps the weapon's MinLevel, an owned one too (server: LootService /
			-- ShopService refuse it), so the row says from which level instead of offering a dead [장착]
			bText, enabled = string.format(L.EquipLevelF, math.floor(tonumber(Config.Weapons[tier].MinLevel) or 1)), false
		elseif pending and pending.Kind == "Equip" and pending.Tier == tier then
			bText, enabled = L.EquipPending, false
		elseif combat then
			-- B14: the server refuses a weapon swap during PvP combat; say so instead of a dead button
			bText, enabled = L.EquipCombat, false
		else
			bText, bColor, enabled = L.Equip, PALETTE.Free, pending == nil
			click = function()
				if inCombat() then return end
				if ITEMS.Send("EquipWeapon", { Kind = "Equip", Tier = tier, WeaponTier = equipped }, tier) then
					ITEMS.Rebuild(true)
				end
			end
		end
		local row = ITEMS.Row(parent, label, color, bText, bColor, enabled, click or function() end, sub)
		row.Name = "Weapon" .. tostring(tier)
	end

	-- scrolls
	addText(parent, L.Scrolls, { Color = theme.Gold, Font = theme.Font, Size = 20 })
	local anyScroll = false
	for _, id in loot.Order do
		local d = loot.Items[id]
		local n = ITEMS.Count(items, id)
		if d and d.Kind ~= "Material" and n > 0 then
			anyScroll = true
			local text = d.Kind == "Enhance" and string.format(L.ScrollEnh, d.Name, n, d.Plus)
				or string.format(L.ScrollMove, d.Name, n)
			local chosen = mode and mode.Item == id
			local row = ITEMS.Row(parent, text, d.Color, chosen and L.Cancel or L.Use,
				chosen and PALETTE.Button or PALETTE.Buy, true, function()
					if chosen then setMode(nil) else setMode({ Item = id }) end
				end, nil, id)
			row.Name = "Scroll_" .. id
		end
	end
	if not anyScroll then addText(parent, L.NoScrolls, { Color = theme.SubText, Size = 16 }) end

	-- materials
	addText(parent, L.Materials, { Color = theme.Gold, Font = theme.Font, Size = 20 })
	local anyMat = false
	for _, id in loot.Order do
		local d = loot.Items[id]
		local n = ITEMS.Count(items, id)
		if d and d.Kind == "Material" and n > 0 then
			anyMat = true
			local row = ITEMS.Row(parent, string.format(L.MaterialLine, d.Name, n, d.Sell), d.Color, nil, nil, nil, nil, nil, id)
			row.Name = "Material_" .. id
		end
	end
	addText(parent, anyMat and L.MaterialHint or L.NoMaterials, { Color = theme.SubText, Size = 16 })

	-- P7: what each monster I have defeated can drop (text only; the picture book comes after launch)
	addText(parent, L.Drops, { Color = theme.Gold, Font = theme.Font, Size = 20 })
	local anyDrop = false
	for _, kind in Config.MonsterTypeOrder do -- seasonal kinds only while their season is on (Config.MonsterActive)
		local rows = loot.Tables[kind]
		if rows and ITEMS.Data.Seen and ITEMS.Data.Seen[kind] and Config.MonsterActive(kind) then
			anyDrop = true
			local parts = {}
			for _, row in rows do
				-- A23-27: below that weapon's MinLevel a weapon row pays its BelowLevel item on every kill instead
				-- (LootService.rollRows: the king's T4 row -> 3 candies), so the list shows what I would really get
				local r, p = row, row.P
				if row.Weapon and type(row.BelowLevel) == "table" and not Config.WeaponUsable(row.Weapon, level) then
					r, p = row.BelowLevel, 1
				end
				local name
				if r.Item and loot.Items[r.Item] then
					name = loot.Items[r.Item].Name
					local n = math.floor(tonumber(r.N) or 1)
					if n > 1 then name = string.format(L.DropCount, name, n) end
				elseif r.Potion then name = string.format(L.DropPotion, r.Potion)
				elseif r.Weapon then name = string.format(L.DropWeapon, Config.WeaponGrade(r.Weapon).Name) end
				if name then table.insert(parts, string.format(L.DropPart, name, Util.FormatPercent(p) .. "%")) end
			end
			local jp = loot.Jackpot
			if jp and jp.Monsters and jp.Monsters[kind] then
				table.insert(parts, string.format(L.DropJackpot, Util.FormatNumber(math.floor(1 / jp.Chance + 0.5))))
			end
			local m = Config.MonsterTypes[kind]
			addText(parent, string.format(L.DropLine, m and (m.Short or m.Name) or kind, table.concat(parts, " · ")),
				{ Name = "Drops_" .. kind, Size = 15 })
		end
	end
	if not anyDrop then addText(parent, L.DropsNone, { Color = theme.SubText, Size = 16 }) end
	-- 검수 10/10: my drop multiplier right now (Config.DropsNow: outlaw / bully x0.5, top 3 x1.1); no line at x1
	local dm, why = Config.DropsNow({ BullyStacks = player:GetAttribute("BullyStacks"), Outlaw = player:GetAttribute("Outlaw"),
		RankReward = player:GetAttribute("RankReward") })
	if math.abs(dm - 1) > 1e-6 then
		addText(parent, string.format(L.DropsNowF, string.format("%g", math.floor(dm * 100 + 0.5) / 100), table.concat(why, " · ")),
			{ Name = "DropsNow", Color = dm < 1 and theme.SubText or theme.Gold, Size = 15 })
	end

	-- 0.25 s: a pending request that got its answer / timed out, or the PvP combat tag flipping, rebuilds in place
	return function()
		if currentId ~= "Items" then return end
		if ITEMS.CheckPending() or inCombat() ~= combat then ITEMS.Rebuild(true) end
	end
end

-- blacksmith add-on: one "sell every material" button (server re-checks the anvil distance and the counts)
function ITEMS.SellButton(parent)
	local row = addRow(parent, 64, 10)
	row.Name = "SellMaterials"
	local b = nil
	b = makeButton(row, "", PALETTE.Free, UDim2.new(1, -20, 0, 60), function()
		if ITEMS.SellPending or ITEMS.MaterialValue(ITEMS.Data.Items) <= 0 then return end
		ITEMS.SellPending = { SentAt = os.clock(), Ver = ITEMS.Version }
		fire("SellMaterials")
		b.Text = ITEMS.T.SellPending
		setEnabled(b, false)
	end)
	b.Name = "SellMaterialsButton"
	return function()
		ITEMS.CheckPending()
		if ITEMS.SellPending then
			b.Text = ITEMS.T.SellPending
			setEnabled(b, false)
			return
		end
		local count, gold = ITEMS.MaterialValue(ITEMS.Data.Items)
		b.Text = count > 0 and string.format(ITEMS.T.SellMat, count, exactNumber(gold)) or ITEMS.T.SellNone
		setEnabled(b, count > 0)
	end
end

BUILDERS.WeaponShop = function(parent)
	local session = WSHOP.Session
	if not session or session.Class ~= currentClass() or session.Faction ~= myFaction() then
		session = { Class = currentClass(), Faction = myFaction() }
		WSHOP.Session = session
	end
	-- lines_pack 11: Otto's calm hello on top (no hurry / sale words next to the buy buttons)
	local hello = Config.Text and Config.Text.ForgeGreeting
	if type(hello) == "string" and hello ~= "" then addText(parent, hello, { Name = "ShopGreeting", Size = 18 }) end
	addText(parent, T.WeaponLocation, { Name = "BlacksmithLocation", Color = theme.SubText })
	local accessLabel = addText(parent, "", { Name = "BlacksmithAccess", Color = theme.Bad })
	local wayRow = addRow(parent, 60, 10) -- UI round 2 #3: shown while far from the anvil
	wayRow.Name = "ForgeWay"
	local wayButton = makeButton(wayRow, T.WeaponShowWay, PALETTE.Free, UDim2.new(1, 0, 0, 60), function() WSHOP.ShowWay() end)
	wayButton.Name = "ForgeShowWay"
	local details = addColumn(parent, 1, 0, 10)
	details.Name = "WeaponCatalog"
	addText(details, WSHOP.Sells() and T.WeaponNote or T.WeaponNoteDrop, { Name = "WeaponNote", Size = 16, Color = theme.SubText })
	local current = addText(details, "", { Name = "CurrentWeapon", Size = 18 })
	local gold = addText(details, "", { Name = "WeaponGold", Size = 18 })
	local status = addText(details, "", { Name = "WeaponTransaction", Color = theme.SubText, Size = 16 })
	local sellUpdate = ITEMS.SellButton(details) -- A23-12: materials are sold here (crafting comes with the full launch)
	local rows, update = {}, nil
	local function live()
		return currentId == "WeaponShop" and WSHOP.Session == session and details.Parent ~= nil
			and session.Class == currentClass() and session.Faction == myFaction()
	end
	local function send(tier, action, expectedEquipped)
		if not live() or session.Pending or os.clock() < (session.CooldownUntil or 0) then return end
		if action ~= "Buy" and action ~= "Equip" and action ~= "Sell" then return end
		if action == "Buy" and tier > 1 and not WSHOP.Sells() then return end -- A23-127: the Forge sells no weapon
		local access = WSHOP.Access()
		local info, buyReason, sellReason = WSHOP.Offer(tier)
		local reason = buyReason
		if action == "Sell" then reason = sellReason end
		-- B6/B14: same rule as 아이템 → 장착; a purchase equips too, so the server refuses it in PvP combat as well
		if (action == "Equip" or action == "Buy") and reason == nil then reason = WSHOP.EquipBlock() end
		-- Never turn an old 'equip' click into a paid purchase after ownership changed.
		if info and ((action == "Buy" and info.Owned) or (action == "Equip" and not info.Owned)
			or (action == "Sell" and expectedEquipped ~= info.EquippedTier)) then reason = T.WeaponChanged end
		if access or reason or not info then
			toast(access or reason or T.WeaponInvalid, "bad")
			update()
			return
		end
		session.Pending = { Tier = tier, Action = action, SentAt = os.clock() }
		update()
		fire(action == "Sell" and "SellWeapon" or "UpgradeWeapon", tier)
	end
	local cap = WSHOP.CatalogLimit()
	for tier = 1, cap or 0 do
		local row = addColumn(details, 1, 0, 5)
		row.Name = "WeaponTier" .. tostring(tier)
		local ui = {
			Tier = tier,
			Name = addText(row, "", { Size = 22, Color = theme.Gold, Font = theme.Font }),
			Price = addText(row, "", { Size = 16 }),
			Effect = addText(row, "", { Size = 16, Color = theme.Good or theme.Text }),
			Sale = addText(row, "", { Size = 16, Color = theme.SubText }),
			Reason = addText(row, "", { Size = 16, Color = theme.Bad }),
		}
		local buttons = addRow(row, 60, 10)
		ui.Buttons = buttons -- A23-127: hidden for a weapon the Forge does not sell and I do not own
		ui.Buy = makeButton(buttons, "", PALETTE.Free, UDim2.new(0.5, -5, 0, 60), function()
			local action = ui.DisplayedAction
			if action == "Buy" and not session.Pending then
				local info = WSHOP.Offer(tier)
				if info and (tonumber(info.Price) or 0) >= WSHOP.ConfirmAt and os.clock() >= (ui.ArmedUntil or 0) then
					ui.ArmedUntil = os.clock() + WSHOP.ConfirmSeconds -- first press: arm, the second one buys
					update()
					task.delay(WSHOP.ConfirmSeconds + 0.05, function() if live() then update() end end)
					return
				end
			end
			ui.ArmedUntil = nil
			send(tier, action)
		end)
		ui.Buy.Name = "BuyOrEquipWeapon" .. tostring(tier)
		ui.Sell = makeButton(buttons, "", PALETTE.Button, UDim2.new(0.5, -5, 0, 60), function()
			if not live() or session.Pending or os.clock() < (session.CooldownUntil or 0) then return end
			local info, _, reason = WSHOP.Offer(tier)
			local access = WSHOP.Access()
			if access or reason or not info then
				toast(access or reason or T.WeaponInvalid, "bad")
				update()
				return
			end
			local plus = ITEMS.Enh(ITEMS.Data.Enhance, tier)
			local body = string.format(T.WeaponSellConfirmF, info.Name .. ITEMS.PlusText(plus), exactNumber(info.SellPrice))
			if info.Equipped then body ..= "\n" .. T.WeaponSaleEquipped end
			-- B14: the tier's +N stays in the save (A23-12) and comes back when the weapon is owned again
			if plus > 0 then body ..= "\n" .. string.format(ITEMS.T.SellKeepEnhF, plus) end
			confirm(T.WeaponSellTitle, body, T.WeaponSellConfirm, function()
				send(tier, "Sell", info.EquippedTier)
			end)
		end)
		ui.Sell.Name = "SellWeapon" .. tostring(tier)
		setEnabled(ui.Buy, false)
		setEnabled(ui.Sell, false)
		table.insert(rows, ui)
	end
	update = function()
		WSHOP.Reconcile(session)
		-- a request the server refused silently (or a lost answer) must never freeze every button: after
		-- WSHOP.PendingTimeout the row unlocks and the status says to check the toast (no double charge: a repeated
		-- 'Buy' of a weapon that turned out owned is refused by the client and only re-equips on the server)
		local stale = session.Pending
		if stale and os.clock() - stale.SentAt >= WSHOP.PendingTimeout then
			session.Pending = nil
			session.SlowUntil = os.clock() + WSHOP.SlowNoteSeconds
		end
		local access = WSHOP.Access()
		accessLabel.Text, accessLabel.Visible = access or "", access ~= nil
		local far = access == T.WeaponFar -- loaded, alive, class picked, just not at the anvil: look but do not buy
		if far and not WSHOP.Sells() then accessLabel.Text = T.WeaponFarDrop end -- A23-127: nothing to buy here
		details.Visible = access == nil or far
		wayRow.Visible = far
		local first = WSHOP.Offer(1)
		local enh = ITEMS.Data.Enhance -- B11: per-tier scroll +N from the owner's Inventory payload (A23-12)
		current.Visible, gold.Visible = first ~= nil, first ~= nil
		if first then
			current.Text = string.format(T.WeaponCurrentF, first.CurrentName .. ITEMS.PlusText(ITEMS.Enh(enh, first.EquippedTier)))
			gold.Text = string.format(T.WeaponGoldF, exactNumber(first.Total), exactNumber(first.Bank), exactNumber(first.Carried))
		end
		local pending = session.Pending
		status.Text = not first and T.WeaponInvalid or (pending and T.WeaponSent)
			or (os.clock() < (session.SlowUntil or 0) and T.WeaponSlow) or ""
		status.Visible = status.Text ~= ""
		local blocked = access ~= nil or pending ~= nil or os.clock() < (session.CooldownUntil or 0)
		local sells = WSHOP.Sells()
		for _, ui in rows do
			local info, buyReason, sellReason = WSHOP.Offer(ui.Tier)
			if info and buyReason == nil then buyReason = WSHOP.EquipBlock() end -- buy or re-equip (both equip)
			ui.Name.Text = info and (Config.WeaponStars(ui.Tier) .. " " .. info.Name .. ITEMS.PlusText(ITEMS.Enh(enh, ui.Tier))
				.. " · " .. (info.Equipped and T.WeaponEquipped or (info.Owned and T.WeaponOwned or T.WeaponUnowned))) or T.WeaponInvalid
			ui.Name.TextColor3 = Config.WeaponGrade(ui.Tier).Color -- design §1 B2: grade color everywhere a weapon is listed
			ui.Price.Visible, ui.Sale.Visible = info ~= nil, info ~= nil
			-- A23-127: a weapon I do not own and the Forge does not sell = where it comes from, no buttons
			local dropOnly = info ~= nil and not sells and not info.Owned and ui.Tier > 1
			ui.Buttons.Visible = not dropOnly
			if dropOnly then buyReason = nil end -- (its "buy from Lv N" line is not for this Forge)
			if info then
				ui.DisplayedAction = info.Owned and "Equip" or (not dropOnly and "Buy" or nil)
				ui.Price.Text = ui.Tier == 1 and T.WeaponStarter
					or (sells and string.format(T.WeaponPriceF, exactNumber(info.Price), info.MinLevel, info.Level))
					or (dropOnly and string.format(T.WeaponFromF, Config.WeaponSource(ui.Tier)))
					or string.format(T.WeaponLevelF, info.MinLevel, info.Level)
				ui.Sale.Text = ui.Tier == 1 and "" or (string.format(T.WeaponSaleNoteF, exactNumber(info.SellPrice))
					.. (info.Equipped and ("\n" .. T.WeaponSaleEquipped) or ""))
				ui.Sale.Visible = ui.Tier > 1 and not dropOnly
				local cls = currentClass()
				local now = Config.SwingHitsToKill(info.EquippedTier, info.Level, cls, "Slime", myFaction(), ITEMS.Enh(enh, info.EquippedTier))
				local with = Config.SwingHitsToKill(ui.Tier, info.Level, cls, "Slime", myFaction(), ITEMS.Enh(enh, ui.Tier))
				ui.Effect.Text = (now and with) and (info.Equipped and Config.Plural(string.format(T.WeaponEffectNowF, now))
					or Config.Plural(string.format(T.WeaponEffectF, now, with))) or "" -- "1 hits" -> "1 hit"
				ui.Effect.Visible = ui.Effect.Text ~= ""
				ui.Buy.Text = info.Equipped and T.WeaponEquipped or (info.Owned and T.WeaponEquip
					or (ui.Tier == 1 and T.WeaponFromSmith) or string.format(T.WeaponBuyF, exactNumber(info.Price)))
				ui.Sell.Text = ui.Tier == 1 and T.WeaponStarterNoSell
					or string.format(T.WeaponSellF, exactNumber(info.SellPrice))
			else
				ui.DisplayedAction = nil
				ui.Buy.Text, ui.Sell.Text = T.WeaponInvalid, T.WeaponNoSell
			end
			if pending and pending.Tier == ui.Tier then
				if pending.Action == "Sell" then ui.Sell.Text = T.WeaponPending else ui.Buy.Text = T.WeaponPending end
			elseif ui.DisplayedAction == "Buy" and os.clock() < (ui.ArmedUntil or 0) then
				ui.Buy.Text = UserInputService.TouchEnabled and WSHOP.AgainTouch or WSHOP.AgainMouse
			end
			ui.Reason.Text = (buyReason ~= T.WeaponEquipped and buyReason) or ""
			ui.Reason.Visible = ui.Reason.Text ~= ""
			setEnabled(ui.Buy, info ~= nil and not blocked and buyReason == nil)
			setEnabled(ui.Sell, info ~= nil and not blocked and sellReason == nil)
		end
	end
	return function()
		update()
		sellUpdate()
	end
end

-- story quest dialogue (StoryQuestService): speaker + quest title, 1-2 short lines per page, then [알겠어요] for a
-- Talk step or two choice buttons for a Choice step. Closing is never a choice; the quest row reopens it.
-- 검수 2026-10-07: the speaker's portrait (STORY.Talk) sits left of the words when that speaker has art.
-- B15: a server auto-open never covers a fight or another window. Then the page waits in STORY.Pending, the HUD quest
-- row shows STORY.Text.Row* with a gentle pulse, and tapping that row (HUD → Panels.ExpectStory + StoryAction "Open")
-- opens it even mid-fight. "Fight" = PvP combat tag, dead, or my own attack / hurt Fx within CalmSeconds.
local STORY = { Arg = nil, Pending = nil, ForceUntil = 0, ForceSeconds = 4, CalmSeconds = 4, Toasted = nil,
	Face = { Size = 104, Short = 68, Gap = 12 }, -- portrait width (px): PC / short phone screens (height < 520)
	Text = {
		RowShard = "Your shard is talking", -- A23-130: shorter (was "... — tap to see")
		RowOther = "Someone wants to talk",
		HintLean = "No points.", -- E5: both picks 0 points (A23-130: shorter)
		HintHave = " (you have %d)", -- round 3 #5: my own side's points now, after the hint
	},
}

function STORY.Label(id)
	local defs = Config.StoryQuests and Config.StoryQuests.Defs
	local def = defs and defs[id]
	local shard = type(def) == "table" and (def.Speaker == "Shard" or def.Speaker == "Fountain")
	return shard and STORY.Text.RowShard or STORY.Text.RowOther
end

function STORY.Busy()
	if currentId ~= nil and currentId ~= "Story" then return true end
	local wm = C and C.WorldMap
	if type(wm) == "table" and type(wm.IsOpen) == "function" then
		local ok, open = pcall(wm.IsOpen)
		if ok and open then return true end
	end
	if inCombat() or isDead() then return true end
	local fx = C and C.Fx
	local last = type(fx) == "table" and fx.LastFightAt or nil
	return type(last) == "number" and os.clock() - last < STORY.CalmSeconds
end

function STORY.Queue(arg)
	STORY.Pending = { Id = arg.Id, St = arg.St, Var = arg.Var }
	local key = arg.Id .. "|" .. tostring(arg.St)
	-- 검수 10/10 (user "이거는 언제쯤 없애는 거야?", A23-99 less hand-holding): no toast any more - the quest row's pulse
	-- and its 'Someone wants to talk' line are the hint
	STORY.Toasted = key
end

function STORY.Def()
	local arg = STORY.Arg
	local defs = Config.StoryQuests and Config.StoryQuests.Defs
	return arg and defs and defs[arg.Id], arg
end

function STORY.Title()
	local def = STORY.Def()
	if not def then return "" end
	local sq = Config.StoryQuests
	local speaker = def.Speaker and sq.Speakers[def.Speaker]
	if not speaker then
		local w = Config.Tutorial.Welcome[myFaction()]
		speaker = w and w.Name or "Guide"
	end
	return string.format(sq.Text.Title, speaker, def.Title)
end

-- E2 (town_quests_server 8): the server's Var picks a step's lines by an earlier choice (LinesBy[Var], else Default);
-- a step without LinesBy keeps its Lines. f = my faction (Lines[f], else Lines.All)
function STORY.Lines(step, f, var)
	local src = (type(step.LinesBy) == "table" and (step.LinesBy[var] or step.LinesBy.Default)) or step.Lines
	return (type(src) == "table" and (src[f] or src.All)) or {}
end

-- the line under the two choice buttons (what a pick does, before picking). A23-58: a pick against my side lowers my
-- own score (Halo: Honor +Good / -Evil, Horns: Infamy -Good / +Evil); E5: two 0-point picks only lean the shard
-- have = my own side's points now (Halo: Honor, Horns: Infamy; nil = unknown -> the plain hint). Round 3 #5
-- (ideas_first10 §3): the minus side shows what really goes - my points never go below 0 (A23-58), so with 0 it says
-- "-0" - and the hint ends with "(you have N)"
function STORY.Hint(obj, f, have)
	local TXT = Config.StoryQuests.Text
	if f ~= "Halo" and f ~= "Horns" then return TXT.ChoiceHintNeutral end
	local good, evil = (obj.Good and obj.Good.Points) or 0, (obj.Evil and obj.Evil.Points) or 0
	if good <= 0 and evil <= 0 then return STORY.Text.HintLean end
	local own = TXT["ChoiceHint" .. f]
	local fmt = type(own) == "string" and own or TXT.ChoiceHint
	if type(have) ~= "number" or have ~= have then return string.format(fmt, good, evil) end
	have = math.max(0, math.floor(have))
	if f == "Halo" then evil = math.min(evil, have) else good = math.min(good, have) end
	return string.format(fmt, good, evil) .. string.format(STORY.Text.HintHave, have)
end

-- round 3 #10 (ideas_first10 §3): a choice is the kind / sneaky art button with the wing / horns glyph left of its
-- words (the shape tells the sides apart, also for red-green colour blindness); without the art: the old button
function STORY.ChoiceButton(parent, side, text, size, onClick)
	local art = side == "Good" and "BtnKind" or "BtnSneaky"
	local glyph = side == "Good" and "GlyphKindWing" or "GlyphSneakyHorns"
	local hasArt = UIKit and type(UIKit.ArtTextButton) == "function" and type(UIKit.ArtPart) == "function"
		and UIKit.ArtPart(art) ~= nil
	if not hasArt then
		return makeButton(parent, text, side == "Good" and PALETTE.Free or (PALETTE.Ticket or PALETTE.Button), size, onClick)
	end
	local btn = nil
	btn = UIKit.ArtTextButton(art, { Name = "Button", Text = text, Size = size, TextSize = 20, Parent = parent }, function()
		if os.clock() < inputGuardUntil then return end -- the same guards as makeButton
		if not btn or disabledButtons[btn] then return end
		local ok, err = pcall(onClick)
		if not ok then Util.Warn(TAG, "button handler error: " .. tostring(err)) end
	end)
	if type(UIKit.ArtImage) == "function" then
		pcall(UIKit.ArtImage, glyph, {
			Name = "Glyph", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.48, 0),
			Size = UDim2.fromScale(0.5, 0.5), SizeConstraint = Enum.SizeConstraint.RelativeYY, ZIndex = btn.ZIndex + 1,
			Active = false, Parent = btn,
		})
		local label = btn:FindFirstChild("Label")
		if label then -- the words move right of the glyph
			label.Position = UDim2.new(0.5, 16, 0.48, 0)
			label.Size = UDim2.new(1, -58, 1, -8)
		end
	end
	return btn
end

-- 검수 2026-10-07 (window audit: 'Story = code, no face'): the speaker's art key (Config.StoryQuests.Portraits) when its
-- art is really there (UIKit.ArtPart: a valid id), else nil = no portrait slot
function STORY.PortraitKey(voice)
	local map = Config.StoryQuests.Portraits
	local key = type(map) == "table" and map[voice] or nil
	if type(key) ~= "string" or not UIKit or type(UIKit.Portrait) ~= "function" then return nil end
	if type(UIKit.ArtPart) == "function" and not UIKit.ArtPart(key) then return nil end
	return key
end

-- the row for the words: [PortraitFrame with the speaker | the words, left-aligned]. Returns the words' parent and
-- their alignment; without a portrait it is the window itself with centred words, as before.
function STORY.Talk(parent, voice)
	local key = STORY.PortraitKey(voice)
	if not key then return parent, Enum.TextXAlignment.Center end
	local cam = workspace.CurrentCamera
	local face = (cam ~= nil and cam.ViewportSize.Y < 520) and STORY.Face.Short or STORY.Face.Size
	local row = addRow(parent, 0, STORY.Face.Gap)
	row.Name = "StoryTalk"
	local list = row:FindFirstChildOfClass("UIListLayout")
	if list then list.VerticalAlignment = Enum.VerticalAlignment.Center end
	local ok, holder = pcall(UIKit.Portrait, key, {
		Name = "StoryPortrait", Size = UDim2.fromOffset(face, math.floor(face * 498 / 512)), Parent = row,
	})
	if not ok or not holder then
		Util.Warn(TAG, "story portrait failed: " .. tostring(holder))
		row:Destroy()
		return parent, Enum.TextXAlignment.Center
	end
	holder.LayoutOrder = 0 -- left of the words (the column takes the next order)
	local words = addColumn(row, 1, -(face + STORY.Face.Gap), 4)
	words.Name = "StoryWords"
	local wordsList = words:FindFirstChildOfClass("UIListLayout")
	if wordsList then wordsList.HorizontalAlignment = Enum.HorizontalAlignment.Left end
	return words, Enum.TextXAlignment.Left
end

-- my own side's points for STORY.Hint (nil before the save loads)
function STORY.Points(f)
	return tonumber(attr(f == "Halo" and "Honor" or "Infamy", nil))
end

BUILDERS.Story = function(parent)
	local def, arg = STORY.Def()
	local step = def and def.Steps[arg.St]
	if not step or not step.Panel then
		addText(parent, "", {})
		return nil
	end
	local f = myFaction()
	local over = step[f]
	local obj = (type(over) == "table" and over.Obj) or step.Obj
	local lines = STORY.Lines(step, f, arg.Var)
	local TXT = Config.StoryQuests.Text
	local page = 1
	local voice = def.Speaker or (f == "Neutral" and "Guild" or f) -- no speaker = my faction's guide
	local talk, align = STORY.Talk(parent, voice)
	local line = addText(talk, "", { Name = "StoryLine", Size = 22, Align = align })
	local typing = {}
	TYPE.Tap(typing, line)
	local pageLabel = addText(talk, "", { Name = "StoryPage", Size = 15, Color = theme.SubText, Align = align })
	local actions = addRow(parent, 64, 10)
	-- what a pick does, shown with the choice buttons on the last page (user 2026-10-05: the flow must explain itself)
	local hint = nil
	if obj.Type == "Choice" then
		hint = addText(parent, STORY.Hint(obj, f, STORY.Points(f)),
			{ Name = "StoryChoiceHint", Size = 16, Color = theme.Gold, Align = Enum.TextXAlignment.Center })
	end
	local buttons = {}
	local update
	local function send(option)
		if TYPE.Finish(typing) then return end -- the first tap while the line types shows it whole
		-- B15: an answer may unlock the next dialogue step at once; it continues even if auto combat is fighting
		STORY.ForceUntil = os.clock() + STORY.ForceSeconds
		if obj.Type == "Talk" then
			fire("StoryAction", arg.Id, "Talk")
		else
			fire("StoryAction", arg.Id, "Choose", option)
		end
		Panels.Close()
	end
	local last = function() return page >= #lines end
	local nextBtn = makeButton(actions, TXT.Next, PALETTE.Button, UDim2.new(1 / 3, -7, 0, 60), function()
		if TYPE.Finish(typing) then return end
		if not last() then page += 1; update() end
	end)
	nextBtn.Name = "StoryNext"
	if obj.Type == "Choice" then
		local isNeutral = f ~= "Halo" and f ~= "Horns"
		local left = isNeutral and (obj.Neutral and obj.Neutral.A) or obj.Good.Label
		local right = isNeutral and (obj.Neutral and obj.Neutral.B) or obj.Evil.Label
		buttons[1] = STORY.ChoiceButton(actions, "Good", left, UDim2.new(0.5, -5, 0, 60), function()
			if last() then send(isNeutral and "A" or "Good") end
		end)
		buttons[1].Name = "StoryChoiceGood"
		buttons[2] = STORY.ChoiceButton(actions, "Evil", right, UDim2.new(0.5, -5, 0, 60), function()
			if last() then send(isNeutral and "B" or "Evil") end
		end)
		buttons[2].Name = "StoryChoiceEvil"
	else
		buttons[1] = makeButton(actions, TXT.Ok, PALETTE.Free, UDim2.new(1 / 3, -7, 0, 60), function()
			if last() then send(nil) end
		end)
		buttons[1].Name = "StoryOk"
		local later = makeButton(actions, TXT.Later, PALETTE.Button, UDim2.new(1 / 3, -7, 0, 60), function()
			Panels.Close()
		end)
		later.Name = "StoryLater"
	end
	update = function()
		if currentId ~= "Story" or not line.Parent then return end
		TYPE.Show(typing, line, tostring(lines[page] or ""), voice, page)
		pageLabel.Text = #lines > 1 and string.format("%d / %d", page, #lines) or ""
		-- one thing to press at a time: [다음] while reading, the answer buttons only on the last page
		nextBtn.Visible = not last()
		for _, b in buttons do
			b.Visible = last()
			setEnabled(b, last())
		end
		if hint then hint.Visible = last() end
	end
	return update
end

-- A23-6 / beta 3: potion shop at the temporary default NPC (Crossroads). Blacksmith-style screen: price, my gold,
-- stock, 1 / 5 bottles, the server's answer (stock / gold attributes) and why a purchase failed (server toasts).
local POTION = {
	Gold = "You have %s gold",
	Stock = "You have %d / %d",
	Name = { HP = "HP Potion ({PotionHP})", MP = "MP Potion ({PotionMP})" }, -- BB1: key part only on keyboards
	Effect = { HP = "Heals %d%% of max HP", MP = "Restores %d%% of max MP" },
	Buy = "%d · %s gold",
	Pending = "Checking the purchase…",
	Full = "Full",
	Short = "Not enough gold",
}

BUILDERS.PotionShop = function(parent)
	local tune = Config.Vitals or {}
	if tune.MerchantEnabled ~= true then
		addText(parent, "The potion shop is coming soon.", { Align = Enum.TextXAlignment.Center })
		return nil
	end
	-- lines_pack 11: Fizzby's hello on top
	local hello = Config.Text and Config.Text.PotionGreeting
	if type(hello) == "string" and hello ~= "" then addText(parent, hello, { Name = "ShopGreeting", Size = 18 }) end
	local gold = addText(parent, "", { Name = "PotionGold", Size = 18 })
	local rows, pending = {}, nil
	local update
	for _, kind in { "HP", "MP" } do
		local key = Config.PotionStockKey(kind)
		local col = addColumn(parent, 1, 0, 5)
		col.Name = "Potion" .. kind
		local ui = { Kind = kind, Key = key }
		local kb = C and C.Keybinds
		local name = POTION.Name[kind]
		if type(kb) == "table" and type(kb.Fill) == "function" then
			name = kb.Fill(name, true)
		else
			name = (string.gsub(name, "%s?%([^()]-{%w+}[^()]-%)", ""))
		end
		ui.Name = addText(col, name, { Size = 22, Color = theme.Gold, Font = theme.Font })
		local pct = math.floor(((kind == "HP" and tune.HPRecovery or tune.MPRecovery) or 0) * 100 + 0.5)
		addText(col, string.format(POTION.Effect[kind], pct), { Size = 16 })
		ui.Stock = addText(col, "", { Size = 16, Color = theme.SubText })
		local buttons = addRow(col, 60, 10)
		ui.Buttons = {}
		for _, amount in { 1, 5 } do
			local b = makeButton(buttons, "", PALETTE.Free, UDim2.new(0.5, -5, 0, 60), function()
				if pending then return end
				local price = (tune.PotionPrices or {})[kind] or 0
				local have = num(key)
				if have + amount > (tune.PotionInventoryCap or 99) then toast(POTION.Full, "bad"); return end
				if num("BankGold") + num("CarriedGold") < price * amount then toast(POTION.Short, "bad"); return end
				pending = { Kind = kind, From = have, At = os.clock() }
				fire("BuyPotion", kind, amount) -- the server re-checks distance, stock cap and gold
				update()
			end)
			b.Name = "Buy" .. kind .. amount
			ui.Buttons[amount] = b
		end
		table.insert(rows, ui)
	end
	update = function()
		if currentId ~= "PotionShop" or not gold.Parent then return end
		if pending and (num(Config.PotionStockKey(pending.Kind)) ~= pending.From or os.clock() - pending.At > 3) then
			pending = nil -- the stock changed (bought) or the server refused (its toast says why)
		end
		local bank, carried = num("BankGold"), num("CarriedGold")
		gold.Text = string.format(POTION.Gold, exactNumber(bank + carried))
		for _, ui in rows do
			local cap = tune.PotionInventoryCap or 99
			local have = num(ui.Key)
			ui.Stock.Text = string.format(POTION.Stock, have, cap)
			local price = (tune.PotionPrices or {})[ui.Kind] or 0
			for amount, b in ui.Buttons do
				local busy = pending ~= nil
				b.Text = (busy and pending.Kind == ui.Kind) and POTION.Pending or string.format(POTION.Buy, amount, exactNumber(price * amount))
				setEnabled(b, not busy and have + amount <= cap and bank + carried >= price * amount)
			end
		end
	end
	return update
end

BUILDERS.Shop = function(parent)
	local rows = {}
	for _, kind in { "Class", "Faction" } do
		local p = Config.ProductByKind(kind)
		local row = Instance.new("Frame")
		row.Name = "Row_" .. kind
		row.BackgroundColor3 = PALETTE.Row
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, 72)
		row.LayoutOrder = nextOrder()
		corner(row, 10)
		row.Parent = parent
		local label = placeLabel(row, "", 20, theme.Text, UDim2.fromOffset(14, 0), UDim2.new(1, -270, 1, 0))
		local btn = makeButton(row, productLabel(kind), PALETTE.Buy, UDim2.fromOffset(240, 52), function()
			buy(kind)
		end)
		btn.AnchorPoint = Vector2.new(1, 0.5)
		btn.Position = UDim2.new(1, -10, 0.5, 0)
		table.insert(rows, { Kind = kind, Label = label, Name = (p and p.Name) or kind })
	end
	addText(parent, T.ShopNote, { Color = theme.SubText, Size = 16 })

	return function()
		for _, r in rows do
			r.Label.Text = string.format(T.ShopRowF, r.Name, math.floor(num(TICKET_ATTR[r.Kind])))
		end
	end
end

BUILDERS.Vacation = function(parent)
	local rawDays = num("VacationDays")
	if rawDays <= 0 then
		addText(parent, T.VacationNone, { Color = theme.SubText, Align = Enum.TextXAlignment.Center })
		return nil
	end
	-- CR-M21: a partly played day adds a fraction of a day; show whole days rounded up (0.5 -> 1)
	local days = math.max(1, math.ceil(rawDays - 1e-6))
	vacationShown = true -- seen this session (manual open counts too)
	addText(parent, Config.Plural(string.format(T.VacationHeaderF, days)), { Size = 24, Align = Enum.TextXAlignment.Center, Font = theme.Font })
	local reward = addText(parent, "", { Size = 22, Color = theme.Gold, Align = Enum.TextXAlignment.Center, Font = theme.Font })
	addText(parent, string.format(T.VacationNoteF, math.floor(Config.Daily.VacationRate * 100 + 0.5)),
		{ Size = 15, Color = theme.SubText, Align = Enum.TextXAlignment.Center })
	local row = addRow(parent, 64, 0)
	makeButton(row, T.VacationClaim, PALETTE.Free, UDim2.fromOffset(240, 60), function()
		fire("ClaimVacation")
		Panels.Close()
	end)

	return function()
		reward.Text = string.format(T.VacationRewardF, Util.FormatNumber(num("VacationGold")), Util.FormatNumber(num("VacationXP")))
	end
end

------------------------------------------------------------------ render / open / close
-- keep = true: a data refresh of the same panel (B14) keeps the scroll position and skips the input guard
-- BB13: a window's title (a registered window's opts.Title may be a function, e.g. Korean / English)
function REG.Title(id)
	local o = REG.Opts[id]
	local t = o and o.Title
	if type(t) == "function" then
		local ok, v = pcall(t)
		t = ok and v or nil
	end
	if type(t) == "string" then return t end
	return T.Titles[id] or ""
end

local function render(keep)
	if not currentId or not ensureRoot() then return end
	local fixed = REG.Opts[currentId] ~= nil and REG.Opts[currentId].FixedBody == true
	local keptY = (keep == true and content and not fixed) and content.CanvasPosition.Y or 0
	if currentId == "Nickname" then
		window.Visible = false
	else
		NICK.Destroy()
		window.Visible = true
	end
	layoutRoot()
	REG.CleanupBuilt()
	clearContent()
	content.Visible = not fixed
	REG.Fixed.Visible = fixed
	orderCounter = 0
	currentUpdate = nil
	titleLabel.Text = REG.Title(currentId)
	local backTo = type(openedFromMenu) == "string" and openedFromMenu ~= currentId and openedFromMenu or nil
	backButton.Visible = backTo ~= nil
	if backTo and backButton:IsA("TextButton") then backButton.Text = "← " .. REG.Title(backTo) end
	FRAME.SetIcon(currentId)
	if currentId == "Story" then titleLabel.Text = STORY.Title() end
	local ok, result = pcall(BUILDERS[currentId], fixed and REG.Fixed or content)
	if not ok then
		Util.Warn(TAG, "failed to build " .. tostring(currentId) .. ": " .. tostring(result))
		return
	end
	if REG.Opts[currentId] then REG.Built = currentId end
	if type(result) == "function" then
		currentUpdate = result
		local ok2, err = pcall(result)
		if not ok2 then Util.Warn(TAG, "update error in " .. tostring(currentId) .. ": " .. tostring(err)) end
	end
	if currentId == "Nickname" then layoutRoot() end
	if keep == true then
		if fixed then return end -- a fixed body keeps its own tab / scroll state
		-- the rebuilt list has about the same height: stay where the player was (re-applied once the new canvas
		-- size is known, clamped to it)
		local id, frame = currentId, content
		frame.CanvasPosition = Vector2.new(0, keptY)
		task.defer(function()
			if currentId ~= id or content ~= frame or not frame.Parent then return end
			local maxY = frame.AbsoluteCanvasSize.Y - frame.AbsoluteWindowSize.Y
			if maxY <= 0 then return end -- not measured yet (or no scroll): the engine's own clamp is enough
			local y = math.min(keptY, maxY)
			if math.abs(frame.CanvasPosition.Y - y) > 0.5 then frame.CanvasPosition = Vector2.new(0, y) end
		end)
		return
	end
	content.CanvasPosition = Vector2.new(0, 0)
	-- CR-L26: the 2nd tap of a double tap on a menu entry must not press what just appeared under the finger
	inputGuardUntil = os.clock() + GUARD.InputAfterRender
end

-- keep = true only for data refreshes (B14); any other queued rebuild in the same frame resets the scroll
local function queueRebuild(keep)
	if keep ~= true then RENDER.Reset = true end
	if rebuildQueued then return end
	rebuildQueued = true
	task.defer(function()
		rebuildQueued = false
		local reset = RENDER.Reset
		RENDER.Reset = false
		if not currentId then return end
		if pickerOpen() then
			Panels.Close()
			return
		end
		render(not reset)
	end)
end
ITEMS.Rebuild = queueRebuild

-- BB5: callers that open a window which may not exist yet (e.g. "Character" before BB8) check first
function Panels.Has(id)
	return type(id) == "string" and BUILDERS[id] ~= nil
end
Panels.IsRegistered = Panels.Has -- BB13 name; BB1 Keybinds: a window key is live once its window is registered

-- BB1: id of the open window, or nil (a window key closes its own window and switches from any other)
function Panels.CurrentId()
	return currentId
end

-- BB13: what a registered window's Build(parent, kit, arg) gets to work with (the same buttons, texts and rules as the
-- built-in windows). kit.Open opens another window with a back button to this one; kit.OnAttr(fn) calls fn(name) on
-- every player attribute change while this window is open (cleared with it)
function REG.Kit()
	return {
		Button = makeButton, Text = addText, Row = addRow, Column = addColumn, Toast = toast, Fire = fire, Confirm = confirm,
		Palette = PALETTE, Theme = theme, Font = BODY_FONT, NextOrder = nextOrder, SetEnabled = setEnabled, Paint = paintButton,
		Attr = attr, Num = num, GameAttr = gameAttr, IsDead = isDead,
		Rebuild = function(keep) queueRebuild(keep) end,
		Close = function() Panels.Close(true) end,
		Open = function(id, arg) openSub(id, arg) end,
		OnAttr = function(fn)
			if type(fn) == "function" then table.insert(REG.AttrFns, fn) end
		end,
	}
end

-- BB13: another client module adds its window. opts = { Build = fn(parent, kit, arg) -> update?, Title = string |
-- fn() -> string, FixedBody = bool (a plain frame instead of the scrolling list), Rebuild = { [attr] = true } | false,
-- KeepScroll = bool (a Rebuild attribute keeps the scroll), Cleanup = fn(), Width = du | fn() -> du (H-1: the window's own
-- width, at most the usual one), Menu = fn() -> text? (③-3: a menu entry while it returns its text) }. Call it in the module's Init (ClientMain ORDER after "Panels"): window keys go live at
-- Keybinds.Start, the HUD [메뉴] squares show once their window is registered
function Panels.Register(id, opts)
	if type(id) ~= "string" or type(opts) ~= "table" or type(opts.Build) ~= "function" then
		Util.Warn(TAG, "Register needs an id and opts.Build: " .. tostring(id))
		return false
	end
	REG.Opts[id] = opts
	BUILDERS[id] = function(parent)
		return opts.Build(parent, REG.Kit(), REG.Arg)
	end
	local kb = C and C.Keybinds
	if type(kb) == "table" and type(kb.Refresh) == "function" then pcall(kb.Refresh) end
	return true
end

-- 창 꾸미기 ③ (검수 2026-10-07; user on the 'Vacation Bonus' window: "이런 화면도 멋있게"): a vacation bonus to claim
-- shows in the shared reward popup (UIKit.RewardPopup: the banner, a soft glow, gold / XP counting up, a big
-- Claim); without a bonus the plain window keeps its one line. Returns true when the popup took over
function FRAME.VacationPopup()
	if num("VacationDays") <= 0 or pickerOpen() then return false end
	if not (UIKit and type(UIKit.RewardPopup) == "function") then return false end
	local shown = FRAME.Reward
	if shown and shown.Frame and shown.Frame.Parent then return true end -- already on screen
	if currentId then Panels.Close() end
	local days = math.max(1, math.ceil(num("VacationDays") - 1e-6)) -- CR-M21: a part day counts as a day
	vacationShown = true
	local ok, popup = pcall(UIKit.RewardPopup, {
		Title = REG.Title("Vacation"),
		Lines = { Config.Plural(string.format(T.VacationAwayF, days)),
			string.format(T.VacationNoteF, math.floor(Config.Daily.VacationRate * 100 + 0.5)) },
		Rewards = { { Icon = "IconCoin", Amount = num("VacationGold") }, { Icon = "IconExp", Amount = num("VacationXP") } },
		Button = T.VacationClaim,
		OnClaim = function() fire("ClaimVacation") end,
		Second = T.VacationLater,
		Faction = myFaction(),
	})
	FRAME.Reward = ok and popup or nil
	if not ok then Util.Warn(TAG, "reward popup failed: " .. tostring(popup)) end
	return FRAME.Reward ~= nil
end

function Panels.Open(id, arg)
	local fromMenu = pendingFromMenu
	pendingFromMenu = false
	if type(id) ~= "string" or BUILDERS[id] == nil then
		Util.Warn(TAG, "unknown panel id: " .. tostring(id))
		return
	end
	if id == "Vacation" and FRAME.VacationPopup() then return end
	if id == "Welcome" then
		local step = player:GetAttribute("TutorialStep")
		if type(step) == "number" and step ~= 0 then WELCOME.PendingOpen = false; return end
		if pickerOpen() or not WELCOME.Ready() then WELCOME.PendingOpen = true; return end
		WELCOME.PendingOpen = false
		if currentId == "Welcome" then return end -- duplicate server opens must not rewind a page
	end
	if id == "Story" then
		-- B15: the opening / pickers, another window or a fight own the screen: the page waits (STORY.Pending) and the
		-- HUD quest row pulses until the player taps it (that tap sets ForceUntil, so the reply opens even mid-fight)
		if type(arg) ~= "table" or type(arg.Id) ~= "string" then return end
		local forced = os.clock() < STORY.ForceUntil
		if pickerOpen() or (not forced and STORY.Busy()) then
			STORY.Queue(arg)
			return
		end
		STORY.ForceUntil = 0
		if STORY.Pending and STORY.Pending.Id == arg.Id then STORY.Pending = nil end
		STORY.Arg = arg
	end
	if pickerOpen() then return end -- the full-screen pickers own the screen
	if not ensureRoot() then return end
	if id ~= currentId then
		selectedClass = nil
		selectedTarget = nil
		ITEMS.Mode = nil
		ITEMS.Result, ITEMS.Note = nil, nil -- a fresh item list starts without an old result line
		WSHOP.Session = nil -- switching panels is not a manual shop farewell
	end
	if id == "Items" or id == "Bag" then ITEMS.Seen = true end -- B14: the menu glow stops once the list (H-1: the bag) was seen
	openedFromMenu = fromMenu
	REG.Arg = arg -- BB13: a registered window's Build gets it (e.g. Settings { Tab = "Keys" })
	currentId = id
	Panels.Metric(id)
	-- A23-79 beta metrics: every Shop opening starts / keeps a shop visit (ClientMetric "ShopOpen", ComeBack.luau)
	if id == "Shop" and C and type(C.ComeBack) == "table" then pcall(C.ComeBack.Metric, "ShopOpen") end
	-- The nickname result is displayed in its own panel; transient game tips stay behind it.
	root.ZIndex = id == "Nickname" and 96 or ZINDEX
	root.Visible = true
	render()
end

function Panels.Close(manual)
	-- A23-130: the merchant's farewell toast is off while Config.Nudges.ShopFarewell = false
	local farewell = manual == true and currentId == "WeaponShop" and (Config.Nudges or {}).ShopFarewell ~= false
		and WSHOP.Farewell() or nil
	-- A picker's automatic close must not discard an earlier server welcome waiting on replicated attributes.
	if currentId == "Welcome" or manual == true or not pickerOpen() then WELCOME.PendingOpen = false end
	currentId = nil
	currentUpdate = nil
	WSHOP.Session = nil
	ITEMS.Mode = nil
	openedFromMenu = false
	selectedClass = nil
	selectedTarget = nil
	if root then root.Visible = false end
	FRAME.TellNotify(false) -- the toasts go back to their column (before the farewell line)
	NICK.Destroy()
	REG.CleanupBuilt()
	REG.Arg = nil
	clearContent()
	if farewell then toast(farewell, "info", 4) end
end

function Panels.IsOpen()
	return currentId ~= nil
end

-- BB38 beta metrics (dev2 cfef90c, docs/design/metrics_server_2026-10-07.md section 5): a window opening counts once per
-- session per window (server WindowOpen_<id>, RateLimits.UiMetric 2 s). Only Config.Analytics.UiIds; the ids go out
-- one at a time Gap s apart, so a quick burst of windows never loses one. Also used by HUD ([메뉴] fold), WorldMap and
-- PlayerListUI (the Tab list).
local METRIC = { Sent = {}, Queue = {}, Busy = false, Gap = 2.1 }
function Panels.Metric(id)
	local ids = Config.Analytics and Config.Analytics.UiIds
	if type(id) ~= "string" or METRIC.Sent[id] or type(ids) ~= "table" or not table.find(ids, id) then return end
	METRIC.Sent[id] = true
	table.insert(METRIC.Queue, id)
	if METRIC.Busy then return end
	METRIC.Busy = true
	task.spawn(function()
		while #METRIC.Queue > 0 do
			fire("UiMetric", table.remove(METRIC.Queue, 1))
			task.wait(METRIC.Gap)
		end
		METRIC.Busy = false
	end)
end

-- B15: the story page waiting for a calm moment ({ Id, St, Label } copy) or nil; HUD pulses that quest row
function Panels.StoryPending()
	local p = STORY.Pending
	if not p then return nil end
	return { Id = p.Id, St = p.St, Label = STORY.Label(p.Id, false) }
end

-- B15: the player tapped that story's quest row: the server's reply opens it even mid-fight
function Panels.ExpectStory(id)
	if type(id) ~= "string" then return end
	STORY.ForceUntil = os.clock() + STORY.ForceSeconds
end

-- B14: true while the HUD 메뉴 square / menu '아이템' should glow (a scroll and the list not opened this session)
function Panels.ItemsHint()
	return ITEMS.Hint()
end

function Panels.ItemsSeen()
	return ITEMS.Seen == true
end

-- B14: my scroll result (Fx "Enhance" payload { Tier, Before, After, Success, Move?, From? }) for the item list
function Panels.OnEnhanceResult(data)
	if type(data) ~= "table" then return end
	local function tierOf(v)
		if type(v) ~= "number" or v ~= v or v < 1 or v > Config.MaxWeaponTier then return nil end
		return math.floor(v)
	end
	local function enhOf(v)
		if type(v) ~= "number" or v ~= v then return nil end
		return math.clamp(math.floor(v), 0, Config.Loot.MaxEnhance)
	end
	local r = { Success = data.Success == true, Move = data.Move == true, Tier = tierOf(data.Tier), From = tierOf(data.From),
		Before = enhOf(data.Before), After = enhOf(data.After) }
	if not r.Tier or not r.Before or not r.After then return end
	ITEMS.Result, ITEMS.ResultAt, ITEMS.Note = r, os.clock(), nil
	ITEMS.CheckPending()
	if currentId == "Items" then ITEMS.Rebuild(true) end
end

-- H-1 bag (BagUI): the last scroll result (the table above) and when it came (os.clock), nil before the first one
function Panels.LastEnhance()
	if not ITEMS.Result then return nil, nil end
	return table.clone(ITEMS.Result), ITEMS.ResultAt
end

------------------------------------------------------------------ loops / wiring
local function checkVacationAuto()
	if vacationShown then return end
	if player:GetAttribute("DataLoaded") ~= true or pickerOpen() then
		pickersClosedSince = nil
		return
	end
	local t = os.clock()
	if not pickersClosedSince then
		pickersClosedSince = t
		return
	end
	if t - pickersClosedSince >= VACATION_DELAY and num("VacationDays") > 0 and currentId == nil then
		vacationShown = true
		Panels.Open("Vacation")
	end
end

local function relayoutIfVisible()
	if root and root.Visible then layoutRoot() end
end

local function hookCamera()
	if cameraConn then
		cameraConn:Disconnect()
		cameraConn = nil
	end
	local cam = workspace.CurrentCamera
	if cam then
		cameraConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(relayoutIfVisible)
	end
end

local function hookScale()
	if scaleConn then
		scaleConn:Disconnect()
		scaleConn = nil
	end
	local gui = root and root.Parent
	local sc = gui and gui:FindFirstChildOfClass("UIScale")
	if sc then
		scaleConn = sc:GetPropertyChangedSignal("Scale"):Connect(relayoutIfVisible)
	end
end

function Panels.Init(c)
	C = c
	UIKit = c and c.UIKit
	loadTheme()
	ITEMS.Bind() -- B11: before any Start, so the first Inventory payload is never missed
end

function Panels.Start()
	loadTheme()
	ensureRoot()
	NICK.BindResult()
	hookCamera()
	hookScale()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookCamera)

	player.AttributeChanged:Connect(function(name)
		if currentId and REG.Built == currentId then -- BB13 kit.OnAttr: the registered window refreshes itself
			for _, fn in table.clone(REG.AttrFns) do
				local ok, err = pcall(fn, name)
				if not ok then warnThrottled("OnAttr error in " .. tostring(currentId) .. ": " .. tostring(err)) end
			end
		end
		if currentId == "Welcome" and name == "TutorialStep" and currentUpdate then
			local ok, err = pcall(currentUpdate)
			if not ok then warnThrottled("welcome update error: " .. tostring(err)) end
		elseif currentId == "Menu" and name == "TutorialStep" then
			queueRebuild()
		elseif currentId and REG.WantsRebuild(currentId, name) then
			-- 검수 10/11: a registered window with KeepScroll redraws its data where the player was (a level up while
			-- the skill window is scrolled down kept jumping it to the top)
			local o = REG.Opts[currentId]
			queueRebuild(o ~= nil and o.KeepScroll == true)
		elseif currentId == "Items" and ITEMS.Attrs[name] then
			ITEMS.CheckPending() -- an equip answer is the WeaponTier change itself
			queueRebuild(true) -- B14: data refresh: scroll kept, no input guard
		elseif currentId == "Nickname" and (name == "Nickname" or name == "NicknameVerified" or name == "NicknameStatus") then
			NICK.Update()
		end
	end)

	-- BB13: Esc opens Roblox's own menu (GuiService.MenuOpened) and closes the open game window, like the world map; the
	-- pad's B closes it too
	pcall(function()
		GuiService.MenuOpened:Connect(function()
			if currentId then Panels.Close(true) end
		end)
	end)
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.ButtonB and currentId then Panels.Close(true) end
	end)

	task.spawn(function()
		local ok, err = pcall(function()
			Net.Get("OpenPanel").OnClientEvent:Connect(function(panelId, arg)
				if type(panelId) == "string" then Panels.Open(panelId, arg) end
			end)
		end)
		if not ok then Util.Warn(TAG, "OpenPanel hookup failed: " .. tostring(err)) end
	end)

	task.spawn(function()
		while true do
			task.wait(UPDATE_INTERVAL)
			if WELCOME.PendingOpen then
				local ok, err = pcall(Panels.Open, "Welcome")
				if not ok then warnThrottled("welcome open error: " .. tostring(err)) end
			end
			if currentId and currentUpdate then
				local ok, err = pcall(currentUpdate)
				if not ok then warnThrottled("update error in " .. tostring(currentId) .. ": " .. tostring(err)) end
			end
			local ok, err = pcall(checkVacationAuto)
			if not ok then warnThrottled("vacation check error: " .. tostring(err)) end
		end
	end)

	print("[Panels] started")
end

return Panels
