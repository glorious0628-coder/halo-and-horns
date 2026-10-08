-- castles_3d_swap.luau (검수 2026-10-08, A23-74 "저거 성 왜 저래?" + 사용자 "섞은 판 하자"): puts the 9-tile castles from
-- ServerStorage.WorldKit3D (import_first_assets_2026-10-08.json via tools/build_kit_from_ids.py) into the town landmarks:
--   Landmarks.HaloCastle  : Town_Halo_Castle (one mesh)      -> Town_Halo_Castle_T9 (9 tiles)
--   Landmarks.HornsCastle : Town_Horns_Castle_v4 (one mesh)  -> Town_Horns_Castle_v6mv (9 tiles, ③ mixed front/back)
-- The new tiles take the old mesh's bottom centre and rotation (front -Z like every kit model). The old mesh moves to
-- ServerStorage.CastleOld (kept). Missing new model = old one stays. Studio MCP execute_luau, MAIN place, Edit mode.
-- Idempotent: the first spot is remembered on the landmark (attribute Swap3DTarget) and old tiles are rebuilt each run.
if game:GetService("RunService"):IsRunning() then error("Edit 모드에서만 실행하세요.") end
local SS = game:GetService("ServerStorage")
local kit = SS:FindFirstChild("WorldKit3D")
assert(kit, "ServerStorage.WorldKit3D missing")
local L = workspace.Map.Landmarks
local store = SS:FindFirstChild("CastleOld") or Instance.new("Folder")
store.Name = "CastleOld"
store.Parent = SS

local SWAPS = {
	{ landmark = "HaloCastle", old = "Town_Halo_Castle", new = "Town_Halo_Castle_T9" },
	{ landmark = "HornsCastle", old = "Town_Horns_Castle_v4", new = "Town_Horns_Castle_v6mv" },
}
local log = {}
for _, s in SWAPS do
	local lm = L:FindFirstChild(s.landmark)
	local src = kit:FindFirstChild(s.new)
	if not (lm and src) then
		table.insert(log, s.landmark .. ": " .. (lm and ("MISSING " .. s.new) or "no landmark"))
		continue
	end
	local old = lm:FindFirstChild(s.old)
	if old and old:IsA("BasePart") then
		lm:SetAttribute("Swap3DTarget", CFrame.new(old.Position - Vector3.new(0, old.Size.Y / 2, 0)) * old.CFrame.Rotation)
		lm:SetAttribute("Swap3DCollide", old.CanCollide)
		old:SetAttribute("OrigParent", lm:GetFullName())
		old.Parent = store
	end
	local target = lm:GetAttribute("Swap3DTarget")
	if not target then
		table.insert(log, s.landmark .. ": old mesh not found, nothing done")
		continue
	end
	for _, c in lm:GetChildren() do
		if c:GetAttribute("Swap3D") then c:Destroy() end
	end
	local m = src:Clone()
	m:PivotTo(target)
	local first = nil
	local collide = lm:GetAttribute("Swap3DCollide")
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = collide ~= false
			p:SetAttribute("Swap3D", true)
			first = first or p
		end
	end
	for _, p in m:GetChildren() do p.Parent = lm end
	m:Destroy()
	if lm:IsA("Model") and (not lm.PrimaryPart or lm.PrimaryPart.Parent ~= lm) then lm.PrimaryPart = first end
	local cf, sz = lm:GetBoundingBox()
	table.insert(log, string.format("%s: %s tiles at (%.1f, %.1f, %.1f), box %.0f x %.0f x %.0f", s.landmark, s.new,
		cf.Position.X, cf.Position.Y - sz.Y / 2, cf.Position.Z, sz.X, sz.Y, sz.Z))
end
return table.concat(log, " | ")
