-- slime_backfix_crown.luau (검수 2026-10-08, SPEC A23-81 — user: "킹슬라임 아직도 뒤에 얼굴 자국 있잖아")
-- Studio MCP execute_luau, MAIN place, Edit mode only.
-- 1) Every MeshPart under ServerStorage.CustomModels that still uses the old slime cube mesh (OLD) gets the back-flattened
--    mesh (NEW, 이미지 생성 2 art/models/tripo/MonsterSlimeCube_backfix.glb, WorldKit import 2026-10-08) via
--    MeshPart:ApplyMesh; TextureID, Size, CFrame and every other property stay. Old id kept in attribute BackfixWas.
-- 2) BigSlime (the King Slime) gets the gold crown mesh welded on its body (docs/design/king_slime_crown_2026-10-08.md):
--    Size = (0.458, 0.379, 0.457) * H, centre = body centre + body-local (-0.036, 0.384, -0.147) * H, H = body Size.Y;
--    Color (255, 153, 15), SmoothPlastic, unanchored + Massless, no collision / query / touch, WeldConstraint to the body.
-- MODE "plan" counts only, "apply" (default) writes, "restore" puts the old mesh back and removes the crown.
-- Idempotent: parts already swapped (BackfixWas) and an existing KingCrown are skipped.

local MODE = "__MODE__"
local ADD_CROWN = true -- 2026-10-09 (later) user: the Slime Prince (BigSlime) wears a crown, not ore (the ore-free body mesh comes from 이미지 생성 1); the real King Slime has its own 3D
local CROWN_SCALE = 0.7 -- the Prince crown is smaller than the King crown (the one the King model carries); 1 = the old size
if MODE ~= "plan" and MODE ~= "restore" then MODE = "apply" end
if game:GetService("RunService"):IsRunning() then error("Edit 모드에서만 실행하세요.") end
local AssetService = game:GetService("AssetService")

local T = {
	Old = "101084943554251",
	New = "rbxassetid://100045743344061",
	Crown = "rbxassetid://125576465588998",
	King = "BigSlime",
	CrownSize = Vector3.new(0.458, 0.379, 0.457),
	CrownOffset = Vector3.new(-0.036, 0.384, -0.147),
	CrownColor = Color3.fromRGB(255, 153, 15),
}

local root = game:GetService("ServerStorage"):FindFirstChild("CustomModels")
if not root then return "no ServerStorage.CustomModels" end

local function makeMesh(id)
	local ok, mp = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromUri(id)) end)
	if not ok then ok, mp = pcall(function() return AssetService:CreateMeshPartAsync(id) end) end
	return ok and mp or nil, (not ok) and tostring(mp) or nil
end

local out, swapped, skipped, restored, failed = {}, 0, 0, 0, {}
local newMesh, err
for _, d in root:GetDescendants() do
	if not d:IsA("MeshPart") then continue end
	local was = d:GetAttribute("BackfixWas")
	if MODE == "restore" then
		if type(was) == "string" then
			local oldMp = makeMesh(was)
			if oldMp then
				local size, cf = d.Size, d.CFrame
				local texId = d.TextureID
				d:ApplyMesh(oldMp)
				d.Size, d.CFrame = size, cf
				d.TextureID = texId
				d:SetAttribute("BackfixWas", nil)
				restored += 1
			end
		end
		continue
	end
	if was then skipped += 1 continue end
	if not string.find(d.MeshId, T.Old, 1, true) then continue end
	if MODE == "plan" then swapped += 1 continue end
	if not newMesh then
		newMesh, err = makeMesh(T.New)
		if not newMesh then table.insert(failed, "new mesh: " .. tostring(err)) break end
	end
	local size, cf, oldId = d.Size, d.CFrame, d.MeshId
	-- 2026-10-09 fix: MeshPart:ApplyMesh clears TextureID (the slimes went colourless in Play): keep it and put it back
	local texId = d.TextureID
	local ok, e = pcall(function() d:ApplyMesh(newMesh) end)
	if ok then
		d.Size, d.CFrame = size, cf
		d.TextureID = texId
		d:SetAttribute("BackfixWas", oldId)
		swapped += 1
		table.insert(out, d:GetFullName())
	else
		table.insert(failed, d:GetFullName() .. ": " .. tostring(e))
	end
end

-- the crown on the King Slime
local king = root:FindFirstChild(T.King)
local crownNote = "no " .. T.King
if king then
	local existing = king:FindFirstChild("KingCrown", true)
	if MODE == "restore" then
		if existing then existing:Destroy() crownNote = "crown removed" else crownNote = "no crown" end
	elseif not ADD_CROWN then
		crownNote = existing and "crown left (ADD_CROWN off)" or "no crown (ADD_CROWN off)"
	elseif existing then
		crownNote = "crown already there"
	else
		local body
		for _, d in king:GetDescendants() do
			if d:IsA("MeshPart") and (not body or d.Size.Magnitude > body.Size.Magnitude) then body = d end
		end
		if not body then
			crownNote = "no body MeshPart"
		elseif MODE == "plan" then
			crownNote = "would add crown on " .. body:GetFullName()
		else
			local crown, cerr = makeMesh(T.Crown)
			if not crown then
				table.insert(failed, "crown mesh: " .. tostring(cerr))
				crownNote = "crown failed"
			else
				local H = body.Size.Y
				crown.Name = "KingCrown"
				crown.Size = T.CrownSize * H * CROWN_SCALE
				-- the crown base stays on the body: bottom y = offset.y - half height (unscaled), the centre follows the smaller height
				local half = T.CrownSize.Y / 2
				-- 검수 10/09: the Prince crown sits in the MIDDLE of the head (x = z = 0; the old ore spot offset is gone)
				local off = Vector3.new(0, (T.CrownOffset.Y - half) + half * CROWN_SCALE, 0)
				crown.CFrame = body.CFrame * CFrame.new(off * H)
				crown.Color = T.CrownColor
				crown.Material = Enum.Material.SmoothPlastic
				crown.Anchored = false
				crown.Massless = true
				crown.CanCollide, crown.CanQuery, crown.CanTouch = false, false, false
				crown.CastShadow = true
				crown.Parent = body.Parent
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = body, crown
				w.Parent = crown
				crownNote = "crown added on " .. body:GetFullName() .. string.format(" (H %.2f)", H)
			end
		end
	end
end

return string.format("%s: meshes swapped %d, already swapped %d, restored %d | %s%s%s", MODE, swapped, skipped, restored,
	crownNote, #failed > 0 and (" | FAILED: " .. table.concat(failed, "; ")) or "", #out > 0 and ("\n" .. table.concat(out, "\n")) or "")
