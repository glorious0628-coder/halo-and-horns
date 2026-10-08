-- ClientMain.client.luau : the ONLY client entry point.
-- A23-48 English only (검수 2026-10-07): Roblox's automatic translation would show our English text in the player's
-- Roblox language (a Korean account sees Korean). Every GUI object under PlayerGui and in the world gets
-- AutoLocalize = false as it appears (server-made signs and name tags too: translation happens on this client).
-- ProximityPrompts too (검수 audit 2026-10-08: they are no GuiBase2d, so "Switch side" / "Open" still translated).
do
	local function off(inst)
		if inst:IsA("GuiBase2d") or inst:IsA("ProximityPrompt") then inst.AutoLocalize = false end
	end
	local function watch(root)
		root.DescendantAdded:Connect(off)
		for _, d in root:GetDescendants() do off(d) end
	end
	watch(game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"))
	task.spawn(watch, workspace)
end

local ORDER = { "CameraFollow", "UIKit", "Settings", "Keybinds", "Fx", "VitalsUI", "HUD", "EventHUD", "Panels", "SettingsUI", "Intro", "FactionPicker", "ClassPicker", "WorldMap", "MonsterMotion", "Announce", "ChatTags", "Invite", "Passes", "SupporterBoard", "PauseCard", "ComeBack", "KingDiary", "QuestBook", "GrudgeGhost", "ZoneLook", "MiniMap", "PlayerListUI", "MonsterLabels", "PetFollow", "QuestTarget", "QuestMarker", "FirstSteps", "FountainFx", "SkillBar", "Audio" }

local C = {}
for _, name in ORDER do
	C[name] = require(script.Parent:WaitForChild(name))
end
for _, name in ORDER do
	local ok, err = pcall(C[name].Init, C)
	if not ok then
		warn(("[ClientMain] %s.Init failed: %s"):format(name, tostring(err)))
	end
end
for _, name in ORDER do
	local ok, err = pcall(C[name].Start)
	if not ok then
		warn(("[ClientMain] %s.Start failed: %s"):format(name, tostring(err)))
	end
end
print("[ClientMain] client started")
