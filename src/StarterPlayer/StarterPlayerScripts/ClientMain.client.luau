-- ClientMain.client.luau : the ONLY client entry point.
local ORDER = { "CameraFollow", "UIKit", "Fx", "VitalsUI", "HUD", "EventHUD", "Panels", "Intro", "FactionPicker", "ClassPicker", "WorldMap", "MonsterMotion", "Announce", "GrudgeGhost" }

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
