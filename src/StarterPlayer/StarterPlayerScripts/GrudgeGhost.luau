-- GrudgeGhost.luau : A23-18 "원한 유령 붙잡기". While a thief carries a grudge sack with MY plundered gold
-- (server attribute GrudgeThiefId), a button (and the Keybinds "GhostHold" key on keyboards, default T; BB1 moved it off
-- G, which opens the bag) lets me hold the sack: each press adds 2 s to the time the thief must survive (server: rate
-- limit 2.7 s, max +10 s per sack). Display only; the server decides.
-- Its own module so HUD.luau (near the 200-locals limit) stays untouched. Uses the approved BtnSquare part through
-- UIKit.ArtButton (code fallback otherwise), sits left of the HUD's bottom-right button cluster (HUD.Layout) above
-- the HUD layer, and is at least 44 real px on every screen (review of 735419e).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local GrudgeGhost = {}
local C = nil
local G = { Button = nil, Label = nil, ReadyAt = 0, Size = 76, Z = 8 }
local me = Players.LocalPlayer

local function alive()
	local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function active()
	return (tonumber(me:GetAttribute("GrudgeThiefId")) or 0) > 0 and alive()
end

local function keyboard() -- review of 27246d1: the same key-display rule as Keybinds / HUD
	local kb = C and C.Keybinds
	if type(kb) == "table" and type(kb.ShowsKeys) == "function" then return kb.ShowsKeys() end
	return UserInputService.KeyboardEnabled
end

function G.Press()
	if not active() or os.clock() < G.ReadyAt then return end
	G.ReadyAt = os.clock() + (Config.Grudge.HoldCooldown or 3)
	pcall(function() Net.Get("GhostHold"):FireServer() end)
	G.Refresh()
end

-- logical size so the real size is >= 44 px under the MainGui UIScale
function G.LogicalSize(gui)
	local sc = gui and gui:FindFirstChildOfClass("UIScale")
	local s = (sc and sc.Scale > 0) and sc.Scale or 1
	return math.max(G.Size, math.ceil(44 / s))
end

function G.Ensure()
	if G.Button and G.Button.Parent then return G.Button end
	local ui = C and C.UIKit
	local gui = ui and ui.Gui
	if not gui then return nil end
	local size = G.LogicalSize(gui)
	local b
	if type(ui.ArtButton) == "function" then
		local ok, made = pcall(ui.ArtButton, "BtnSquare", {
			Name = "GrudgeGhostHold", AnchorPoint = Vector2.new(1, 1),
			Size = UDim2.fromOffset(size, size), ZIndex = G.Z, Parent = gui,
		}, G.Press, { CornerRadius = UDim.new(0, 12) })
		if ok and typeof(made) == "Instance" then b = made end
	end
	if not b then
		b = Instance.new("TextButton")
		b.Name = "GrudgeGhostHold"
		b.AnchorPoint = Vector2.new(1, 1)
		b.Size = UDim2.fromOffset(size, size)
		b.ZIndex = G.Z
		b.Text = ""
		local theme = ui and ui.Theme
		b.BackgroundColor3 = (type(theme) == "table" and typeof(theme.Panel) == "Color3") and theme.Panel
			or Color3.fromRGB(35, 35, 48) -- ART_DIRECTION 2.3 Panel
		b.Activated:Connect(G.Press)
		b.Parent = gui
	end
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -8, 1, -8)
	label.Position = UDim2.fromOffset(4, 4)
	label.ZIndex = G.Z + 1
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(66, 40, 18) -- the HUD's ink colour on parchment squares
	label.Parent = b
	b.Visible = false
	G.Button, G.Label = b, label
	return b
end

-- left of the bottom-right cluster (dock / square buttons), level with its top edge; follows every HUD re-layout
function G.Place(b)
	local hud = C and C.HUD
	local layout = type(hud) == "table" and hud.Layout or nil
	if type(layout) == "table" and tonumber(layout.ClusterLeft) and tonumber(layout.ClusterTop) then
		b.Position = UDim2.fromOffset(layout.ClusterLeft - 10, layout.ClusterTop + b.Size.Y.Offset)
	else
		b.Position = UDim2.new(1, -16, 1, -250)
	end
end

function G.Refresh()
	local b = G.Ensure()
	if not b then return end
	local on = active()
	b.Visible = on
	if not on then return end
	G.Place(b)
	local wait = math.ceil(G.ReadyAt - os.clock())
	G.Label.Text = wait > 0 and string.format(Config.Text.GhostWait, wait) or G.ButtonText()
end

-- "유령으로 붙잡기 ({GhostHold})": the current key only where there is a keyboard and the action has a key (BB1)
function G.ButtonText()
	local text = Config.Text.GhostButton
	local kb = C and C.Keybinds
	if type(kb) ~= "table" or type(kb.Fill) ~= "function" then
		return (string.gsub(text, "%s?%([^()]-{%w+}[^()]-%)", ""))
	end
	if not keyboard() then return kb.StripKeys(text) end
	return kb.Fill(text, true)
end

function GrudgeGhost.Init(registry)
	C = registry
end

function GrudgeGhost.Start()
	me:GetAttributeChangedSignal("GrudgeThiefId"):Connect(G.Refresh)
	-- BB1: the hold key comes from Keybinds (Keybinds forwards every key press, plus its Dispatch test inputs)
	local keys = C and C.Keybinds
	if type(keys) == "table" and type(keys.Began) == "table" then
		keys.Began:Connect(function(input, processed)
			if processed or keys.IsCapturing() or UserInputService:GetFocusedTextBox() then return end
			if keys.ActionFor(input) == "GhostHold" then G.Press() end
		end)
		keys.Changed:Connect(function() pcall(G.Refresh) end)
	end
	task.spawn(function()
		while true do
			task.wait(0.5)
			pcall(G.Refresh)
		end
	end)
	print("[GrudgeGhost] started")
end

return GrudgeGhost
