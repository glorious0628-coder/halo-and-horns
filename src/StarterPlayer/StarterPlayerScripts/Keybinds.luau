-- Keybinds.luau : BB1 (docs/design/beta_basics_2026-10-05.md) the one place that knows which key does what.
-- A23-21: PC keyboard keys can be changed (saved through BB2 Settings.Keys), the gamepad layout is fixed (Config
-- .Keybinds Pad; PadWired = the pad buttons that work today, BB21 wires the rest) and touch-only devices show button
-- names instead of keys. The map is Config.KeyMap(saved sparse keys, live set): an action is live when its Flag is on
-- and, for the Window group, its Panels window is registered (call Keybinds.Refresh() after registering a window).
-- Every UserInputService press / release is forwarded through Keybinds.Began / Keybinds.Ended (HUD, VitalsUI and
-- GrudgeGhost listen there), so Keybinds.Dispatch(fakeInput) reaches the same handlers as a real key.
-- API: Get(action) -> Enum.KeyCode? | KeyName(action) -> name or "" | ActionFor(input) -> action id? | Label(action)
--   (key label, or the button name on touch-only devices) | PadFor(action) -> Enum.KeyCode? | WindowFor(action) -> Panels
--   id? | Fill(text, keyOnly?) / StripKeys(text) ('{Auto}' tokens) | Changed (Util.Signal: (map copy)) | Apply(sparse)
--   | SetLocal(action, key) -> ok, reason?, other? (swaps with the live holder, which gets my old key or ""; a non-live
--   action's saved entry on that key is dropped back to its default) | Clear(action)
--   | Reset() | IsCapturing() | Capture(action, cb) / EndCapture(reason) (BB3: next key press, 5 s) | Collisions()
--   | IsLive(action) | Refresh() | Dispatch(fakeInput) (test hook; in Studio also script.Dispatch:Invoke(fakeInput)).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local Keybinds = {}
local C = nil
local TAG = "Keybinds"
local KB = Config.Keybinds
local K = {
	Sparse = {}, -- saved explicit keys (Settings.Keys)
	Map = {}, -- [action id] = key name or ""
	ByKey = {}, -- [key name] = action id (live actions only)
	ByPad = {}, -- [pad button name] = action id (live + PadWired only)
	Live = {}, -- [action id] = true
	Collisions = {}, -- live default-only actions left without a key (BB2 collision rule)
	Toasted = {}, -- [action id] = true: the collision toast was shown this session
	Capture = nil, -- { Action, Cb } while a key is being captured (BB3)
	Prompts = setmetatable({}, { __mode = "k" }), -- ProximityPrompts whose keyboard key follows "Interact"
	Started = false,
	CaptureAction = "HH_KeyCapture",
	CapturePriority = 4000, -- above WorldMap (High + 10) and Intro (3000)
	CaptureSeconds = 5,
}

Keybinds.Changed = Util.Signal.new() -- (map copy) after the effective keys changed
Keybinds.Began = Util.Signal.new() -- (input, gameProcessed) every UserInputService.InputBegan + Dispatch
Keybinds.Ended = Util.Signal.new() -- (input, gameProcessed) every UserInputService.InputEnded + Dispatch

-- the one rule for key badges / key hints (HUD, VitalsUI, GrudgeGhost, WorldMap, Intro, quest texts): a keyboard is
-- there (touch laptops too). Review B5: no other device test decides whether a key is shown.
function Keybinds.ShowsKeys()
	return UserInputService.KeyboardEnabled == true
end

-- no keyboard: key labels become button names, "(… {Action} …)" groups go
local function touchOnly()
	return not Keybinds.ShowsKeys()
end

-- A23-43: UIKit.Lang decides (saved setting, else the Roblox language; English by default)
local function english()
	local kit = C and C.UIKit
	if type(kit) == "table" and type(kit.Lang) == "function" then
		local ok, lang = pcall(kit.Lang)
		if ok then return lang == "en" end
	end
	local st = C and C.Settings
	if type(st) ~= "table" or type(st.Get) ~= "function" then return false end
	local ok, lang = pcall(st.Get, "Lang")
	return ok and lang == "en"
end

local function text(key, ...)
	local t = Config.Settings.Text
	local s = (english() and t[key .. "En"]) or t[key] or ""
	if select("#", ...) > 0 then
		local ok, out = pcall(string.format, s, ...)
		return ok and out or s
	end
	return s
end

local function toast(msg, kind, seconds)
	local kit = C and C.UIKit
	if type(kit) == "table" and type(kit.Toast) == "function" and msg ~= "" then pcall(kit.Toast, msg, kind or "info", seconds or 4) end
end

local function actionName(def)
	return english() and def.LabelEn or def.Label
end

local function keyCode(name)
	if type(name) ~= "string" or name == "" then return nil end
	local ok, code = pcall(function() return Enum.KeyCode[name] end)
	return ok and code or nil
end

local function sameMap(a, b)
	for k, v in a do
		if b[k] ~= v then return false end
	end
	for k in b do
		if a[k] == nil then return false end
	end
	return true
end

local function liveSet()
	local panels = C and C.Panels
	local set = {}
	for _, def in KB.Actions do
		if Config.KeyFlagOn(def) then
			if def.Group ~= "Window" then
				set[def.Id] = true
			elseif type(panels) == "table" and type(panels.Has) == "function" then
				local ok, has = pcall(panels.Has, def.Window)
				if ok and has then set[def.Id] = true end
			end
		end
	end
	return set
end

-- once per action per session, keyboards only: a new action's default key was already one of my keys
local function toastCollisions()
	if not K.Started or touchOnly() then return end
	for _, id in K.Collisions do
		local def = KB.ById[id]
		if def and not K.Toasted[id] then
			K.Toasted[id] = true
			toast(text("KeyCollision", actionName(def), Config.KeyLabel(def.Key, english())), "info", 7)
		end
	end
end

local function applyPrompt(prompt)
	if typeof(prompt) ~= "Instance" or not prompt:IsA("ProximityPrompt") then return end
	K.Prompts[prompt] = true
	-- Interact can never be empty (NoClear) and only holds keys the prompt UI draws; E is the safety fallback
	local code = Keybinds.Get("Interact") or Enum.KeyCode.E
	if prompt.KeyboardKeyCode ~= code then prompt.KeyboardKeyCode = code end
end

local function recompute(silent)
	local live = liveSet()
	local map, collisions = Config.KeyMap(K.Sparse, live)
	local changed = not sameMap(map, K.Map)
	K.Live, K.Map, K.Collisions = live, map, collisions
	K.ByKey, K.ByPad = {}, {}
	for id, key in map do
		if key ~= "" then K.ByKey[key] = id end
	end
	for _, def in KB.Actions do
		if live[def.Id] and KB.PadWired[def.Id] and def.Pad ~= "" then K.ByPad[def.Pad] = def.Id end
	end
	toastCollisions()
	if changed and not silent then
		for prompt in K.Prompts do
			if prompt.Parent then pcall(applyPrompt, prompt) end
		end
		Keybinds.Changed:Fire(table.clone(map))
	end
end

local function cleanKeys(sparse)
	return Config.SanitizeSettings({ Keys = type(sparse) == "table" and sparse or {} }).Keys
end

-- new explicit keys: applied here at once, saved through BB2 Settings
local function commit(sparse)
	K.Sparse = cleanKeys(sparse)
	recompute(false)
	local st = C and C.Settings
	if type(st) == "table" and type(st.SetKeys) == "function" then
		local ok, err = pcall(st.SetKeys, K.Sparse)
		if not ok then Util.Warn(TAG, "save failed: " .. tostring(err)) end
	end
end

------------------------------------------------------------------ lookups
function Keybinds.Get(action)
	return keyCode(K.Map[action])
end

function Keybinds.KeyName(action)
	local key = K.Map[action]
	return type(key) == "string" and key or ""
end

function Keybinds.IsLive(action)
	return K.Live[action] == true
end

-- the action of a key press (keyboard: the player's keys; Gamepad1: the fixed pad buttons that are wired), or nil
function Keybinds.ActionFor(input)
	if input == nil then return nil end
	local ok, kind, code = pcall(function() return input.UserInputType, input.KeyCode end)
	if not ok or typeof(code) ~= "EnumItem" then return nil end
	if kind == Enum.UserInputType.Keyboard then return K.ByKey[code.Name] end
	if kind == Enum.UserInputType.Gamepad1 then return K.ByPad[code.Name] end
	return nil
end

-- key label ("F", "1", "Ctrl", "Num1", "없음"); on touch-only devices the button name instead (A23-21)
function Keybinds.Label(action)
	local def = KB.ById[action]
	if not def then return "" end
	local en = english()
	if touchOnly() then return en and def.ButtonEn or def.Button end
	return Config.KeyLabel(K.Map[action] or "", en)
end

-- the fixed gamepad button of an action (A23-21: not remappable in the beta), or nil
function Keybinds.PadFor(action)
	local def = KB.ById[action]
	return def and keyCode(def.Pad) or nil
end

-- the Panels id a window key opens (Group "Window"), or nil
function Keybinds.WindowFor(action)
	local def = KB.ById[action]
	return def and def.Group == "Window" and def.Window or nil
end

function Keybinds.Collisions()
	return table.clone(K.Collisions)
end

-- "(… {Action} …)" groups removed (touch-only device or a text that shows keys only on keyboards)
function Keybinds.StripKeys(s)
	if type(s) ~= "string" then return s end
	return (string.gsub(s, "%s?%([^()]-{%w+}[^()]-%)", function(group)
		for id in string.gmatch(group, "{(%w+)}") do
			if KB.ById[id] then return "" end
		end
		return nil
	end))
end

-- '{Auto}' -> Label("Auto"). keyOnly: a "(… {Action} …)" group stays only on keyboards and only when that action has a
-- key (e.g. "유령으로 붙잡기 ({GhostHold})" -> "유령으로 붙잡기 (T)" / "유령으로 붙잡기")
function Keybinds.Fill(s, keyOnly)
	if type(s) ~= "string" or not string.find(s, "{", 1, true) then return s end
	if keyOnly then
		if touchOnly() then
			s = Keybinds.StripKeys(s)
		else
			s = string.gsub(s, "%s?%([^()]-{%w+}[^()]-%)", function(group)
				for id in string.gmatch(group, "{(%w+)}") do
					if KB.ById[id] and Keybinds.KeyName(id) == "" then return "" end
				end
				return nil
			end)
		end
	end
	return (string.gsub(s, "{(%w+)}", function(id)
		if not KB.ById[id] then return nil end
		return Keybinds.Label(id)
	end))
end

------------------------------------------------------------------ changes
-- the saved sparse keys (BB2 server value); recomputes and fires Changed only when the effective keys changed
function Keybinds.Apply(sparse)
	K.Sparse = cleanKeys(sparse)
	recompute(false)
end

-- live set again (a Panels window registered later, BB13 Panels.Register calls this)
function Keybinds.Refresh()
	recompute(false)
end

-- key = KeyCode name or Enum.KeyCode. A key another live action holds is swapped: that action gets my old key (or "").
-- Returns ok, reason ("NotLive" | "Reserved" | "NotAllowed" | "Swap" | nil), the other action (on "Swap").
function Keybinds.SetLocal(action, key)
	if not KB.ById[action] or not K.Live[action] then return false, "NotLive" end
	if typeof(key) == "EnumItem" then key = key.Name end
	if type(key) ~= "string" then return false, "NotAllowed" end
	if Config.KeyReserved(key) then return false, "Reserved" end
	if not Config.KeyAllowedFor(action, key) then return false, "NotAllowed" end
	local old = Keybinds.KeyName(action)
	if old == key then return true end
	local holder = K.ByKey[key]
	-- a swap may not hand the other action a key it cannot hold (Interact: prompt keys only, never empty)
	if holder and holder ~= action and not Config.KeyAllowedFor(holder, old) then return false, "NotAllowed" end
	local sparse = table.clone(K.Sparse)
	sparse[action] = key
	if holder and holder ~= action then sparse[holder] = old end
	-- a non-live action holds no key: its saved key (a window not built / registered yet, a save from another build)
	-- must not take this key from a live action (SanitizeSettings keeps one key per action in Actions order), so that
	-- stale entry goes back to its default (the BB2 collision rule handles it once the action is live)
	for id, v in K.Sparse do
		if not K.Live[id] and v ~= "" and (v == key or (holder and holder ~= action and v == old)) then sparse[id] = nil end
	end
	commit(sparse)
	if holder and holder ~= action then return true, "Swap", holder end
	return true
end

-- the action keeps no key ("없음"); its old key does nothing
function Keybinds.Clear(action)
	if not KB.ById[action] or not K.Live[action] then return false end
	if not Config.KeyAllowedFor(action, "") then return false, "NoClear" end -- Interact always keeps a key
	local sparse = table.clone(K.Sparse)
	sparse[action] = ""
	commit(sparse)
	return true
end

-- every key back to the defaults
function Keybinds.Reset()
	commit({})
end

------------------------------------------------------------------ capture (BB3 settings window)
function Keybinds.IsCapturing()
	return K.Capture ~= nil
end

-- ends the running capture; cb(result, keyName?, otherAction?) with result "Set" | "Swap" | "Reserved" | "NotAllowed" |
-- "Timeout" | "Cancel"
function Keybinds.EndCapture(result, key, other)
	local cap = K.Capture
	if not cap then return end
	K.Capture = nil
	pcall(function()
		ContextActionService:UnbindAction(K.CaptureAction)
	end)
	if cap.Prompts ~= nil then
		pcall(function() ProximityPromptService.Enabled = cap.Prompts end) -- the interact prompts work again
	end
	if type(cap.Cb) == "function" then
		local ok, err = pcall(cap.Cb, result or "Cancel", key, other)
		if not ok then Util.Warn(TAG, "capture callback: " .. tostring(err)) end
	end
end

local function onCapture(cap, input)
	if K.Capture ~= cap then return end
	local code = input.KeyCode
	if code == Enum.KeyCode.Unknown then return end
	local name = code.Name
	if code == Enum.KeyCode.Escape then
		Keybinds.EndCapture("Cancel")
	elseif Config.KeyReserved(name) then
		toast(text("Reserved"), "bad", 3)
		Keybinds.EndCapture("Reserved", name)
	elseif not Config.KeyAllowedFor(cap.Action, name) then
		toast(text("NotAllowed"), "bad", 3)
		Keybinds.EndCapture("NotAllowed", name)
	else
		local old = Keybinds.KeyName(cap.Action)
		local ok, reason, other = Keybinds.SetLocal(cap.Action, name)
		if ok and reason == "Swap" then
			toast(text("Swapped", Config.KeyLabel(name, english()), Config.KeyLabel(old, english())), "info", 3)
			Keybinds.EndCapture("Swap", name, other)
		elseif ok then
			Keybinds.EndCapture("Set", name)
		else
			Keybinds.EndCapture(reason == "NotLive" and "Cancel" or (reason or "NotAllowed"), name)
		end
	end
end

-- the next keyboard key becomes the action's key (5 s; Esc / the Roblox menu / EndCapture cancel). The capture sinks
-- every keyboard key at priority 4000, so M / B / the game keys do nothing meanwhile (IsCapturing is a second guard).
function Keybinds.Capture(action, cb)
	Keybinds.EndCapture("Cancel")
	if not KB.ById[action] or not K.Live[action] then return false end
	local cap = { Action = action, Cb = cb, Prompts = nil }
	K.Capture = cap
	pcall(function() -- the pressed key must not also open a shop / altar prompt
		cap.Prompts = ProximityPromptService.Enabled
		ProximityPromptService.Enabled = false
	end)
	local ok, err = pcall(function()
		ContextActionService:BindActionAtPriority(K.CaptureAction, function(_, state, input)
			if K.Capture ~= cap then return Enum.ContextActionResult.Pass end
			if state == Enum.UserInputState.Begin then
				local okKey, errKey = pcall(onCapture, cap, input)
				if not okKey then
					Util.Warn(TAG, "capture: " .. tostring(errKey))
					Keybinds.EndCapture("Cancel")
				end
			end
			return Enum.ContextActionResult.Sink
		end, false, K.CapturePriority, Enum.UserInputType.Keyboard)
	end)
	if not ok then
		K.Capture = nil
		if cap.Prompts ~= nil then pcall(function() ProximityPromptService.Enabled = cap.Prompts end) end
		Util.Warn(TAG, "capture bind failed: " .. tostring(err))
		return false
	end
	task.delay(K.CaptureSeconds, function()
		if K.Capture == cap then Keybinds.EndCapture("Timeout") end
	end)
	return true
end

------------------------------------------------------------------ test hook
-- runs the game's key handlers for a fake input: { KeyCode = Enum.KeyCode.G, UserInputType = Enum.UserInputType.Keyboard
-- (default) | Gamepad1, State = "Begin" | "End" | nil (= press and release), GameProcessed = bool }. Returns the action.
function Keybinds.Dispatch(fake)
	if type(fake) ~= "table" or typeof(fake.KeyCode) ~= "EnumItem" then return nil end
	local input = {
		KeyCode = fake.KeyCode,
		UserInputType = fake.UserInputType or Enum.UserInputType.Keyboard,
		UserInputState = Enum.UserInputState.Begin,
		Position = Vector3.zero,
		Delta = Vector3.zero,
		Fake = true,
	}
	local action = Keybinds.ActionFor(input)
	if fake.State ~= "End" then Keybinds.Began:Fire(input, fake.GameProcessed == true) end
	if fake.State ~= "Begin" then
		local ended = table.clone(input)
		ended.UserInputState = Enum.UserInputState.End
		Keybinds.Ended:Fire(ended, fake.GameProcessed == true)
	end
	return action
end

------------------------------------------------------------------ lifecycle
function Keybinds.Init(registry)
	C = registry
	local st = C and C.Settings
	if type(st) == "table" and type(st.Get) == "function" then
		local ok, keys = pcall(st.Get, "Keys")
		if ok then K.Sparse = cleanKeys(keys) end
	end
	recompute(true) -- HUD / VitalsUI build their key badges from this in their Init
	if RunService:IsStudio() then
		-- execute_luau / command bar (client): PlayerScripts.Keybinds.Dispatch:Invoke({ KeyCode = Enum.KeyCode.G })
		local bf = Instance.new("BindableFunction")
		bf.Name = "Dispatch"
		bf.OnInvoke = function(fake) return Keybinds.Dispatch(fake) end
		bf.Parent = script
	end
end

function Keybinds.Start()
	if K.Started then return end
	K.Started = true
	recompute(false) -- every window registered in an Init is live now
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		Keybinds.Began:Fire(input, gameProcessed)
	end)
	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		Keybinds.Ended:Fire(input, gameProcessed)
	end)
	local st = C and C.Settings
	if type(st) == "table" and type(st.Changed) == "table" then
		st.Changed:Connect(function(settings)
			if type(settings) == "table" then Keybinds.Apply(settings.Keys) end
		end)
	end
	-- Interact: every ProximityPrompt (blacksmith / altar / potion merchant) uses the player's Interact key
	ProximityPromptService.PromptShown:Connect(function(prompt) pcall(applyPrompt, prompt) end)
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") then pcall(applyPrompt, d) end
	end)
	task.spawn(function()
		for _, d in workspace:GetDescendants() do
			if d:IsA("ProximityPrompt") then pcall(applyPrompt, d) end
		end
	end)
	pcall(function()
		GuiService.MenuOpened:Connect(function() Keybinds.EndCapture("Cancel") end) -- Esc belongs to Roblox
	end)
	toastCollisions()
	print("[Keybinds] started")
end

return Keybinds
