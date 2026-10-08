-- gate_faces_hide.luau (게임성 개발 1, 2026-10-08; 검수 style drift #9: "관문 원시 파트의 Neon 눈·해골·턱 숨기기", no faces on
-- props): Studio MCP execute_luau, main place, Edit mode. The zone gates (Map.Gates, built by MapBuilder.buildGate /
-- preview_map) keep their pillars, lintel and contract parts; their face parts become invisible: Gate_SlimeMeadow's slime
-- statue and its two eyes, Gate_GoblinWoods' TotemEyes, Gate_HornsTown's two neon eyes, Gate_SkeletonRuins' skull, its
-- two eyes (and the eye light) and the jaw. Invisible = Transparency 1, no collision / query / touch / shadow, lights off,
-- attribute StyleHidden = true (so a later tool can tell; nothing is destroyed). The new 3D gates replace the whole gate
-- later (검수's zone placing). Idempotent. MODE = "survey" only lists what it would hide.
local MODE = "apply"
local HIDE = {
	Gate_SlimeMeadow = { SlimeStatue = true, Eye = true },
	Gate_GoblinWoods = { TotemEyes = true },
	Gate_HornsTown = { Eye = true },
	Gate_SkeletonRuins = { Skull = true, SkullEye = true, Jaw = true },
}
local gates = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Gates")
assert(gates, "Map.Gates missing")
local out, n = {}, 0
for gateName, names in HIDE do
	local gate = gates:FindFirstChild(gateName)
	if not gate then
		table.insert(out, gateName .. ": not in the place")
		continue
	end
	local hidden = {}
	for _, d in gate:GetDescendants() do
		if d:IsA("BasePart") and names[d.Name] then
			if MODE == "apply" then
				d.Transparency = 1
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.CastShadow = false
				d:SetAttribute("StyleHidden", true)
				for _, l in d:GetDescendants() do
					if l:IsA("Light") then l.Enabled = false end
				end
			end
			table.insert(hidden, d.Name)
			n += 1
		end
	end
	table.sort(hidden)
	table.insert(out, string.format("%s: %s", gateName, #hidden > 0 and table.concat(hidden, ", ") or "nothing to hide"))
end
table.sort(out)
return string.format("%s %d face parts\n%s", MODE == "apply" and "hid" or "would hide", n, table.concat(out, "\n"))
