-- GrudgeGhost.luau : A23-18 "원한 유령 붙잡기". While a thief carries a grudge sack with MY plundered gold
-- (server attribute GrudgeThiefId), a button (and the G key) lets me hold the sack: each press adds 2 s to the time the
-- thief must survive (server: 3 s cooldown, max +10 s per sack). Display only; the server decides everything.
-- Its own module so HUD.luau (near the 200-locals limit) stays untouched. Uses the existing UIKit button.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local GrudgeGhost = {}
local C = nil
local G = { Button = nil, ReadyAt = 0 }
local me = Players.LocalPlayer

local function alive()
	local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function active()
	return (tonumber(me:GetAttribute("GrudgeThiefId")) or 0) > 0 and alive()
end

function G.Press()
	if not active() or os.clock() < G.ReadyAt then return end
	G.ReadyAt = os.clock() + (Config.Grudge.HoldCooldown or 3)
	pcall(function() Net.Get("GhostHold"):FireServer() end)
	G.Refresh()
end

function G.Ensure()
	if G.Button and G.Button.Parent then return G.Button end
	local ui = C and C.UIKit
	local gui = ui and ui.Gui
	if not gui then return nil end
	local b
	if type(ui.Button) == "function" then
		local ok, made = pcall(ui.Button, {
			Name = "GrudgeGhostHold", Text = Config.Text.GhostButton,
			Size = UDim2.fromOffset(190, 52), Color = Color3.fromRGB(110, 140, 210), TextSize = 18, Parent = gui,
		}, G.Press)
		if ok and typeof(made) == "Instance" then b = made end
	end
	if not b then
		b = Instance.new("TextButton")
		b.Name = "GrudgeGhostHold"
		b.Size = UDim2.fromOffset(190, 52)
		b.Text = Config.Text.GhostButton
		b.Activated:Connect(G.Press)
		b.Parent = gui
	end
	b.AnchorPoint = Vector2.new(1, 1)
	b.Position = UDim2.new(1, -16, 1, -250) -- above the attack / skill buttons
	b.Visible = false
	G.Button = b
	return b
end

function G.Refresh()
	local b = G.Ensure()
	if not b then return end
	local on = active()
	b.Visible = on
	if not on then return end
	local wait = math.ceil(G.ReadyAt - os.clock())
	b.Text = wait > 0 and string.format(Config.Text.GhostWait, wait) or Config.Text.GhostButton
end

function GrudgeGhost.Init(registry)
	C = registry
end

function GrudgeGhost.Start()
	me:GetAttributeChangedSignal("GrudgeThiefId"):Connect(G.Refresh)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.G then return end
		G.Press()
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			pcall(G.Refresh)
		end
	end)
	print("[GrudgeGhost] started")
end

return GrudgeGhost
