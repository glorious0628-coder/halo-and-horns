-- slime_prince_body.luau (이미지 생성 1, 2026-10-09; 사용자 "결정석(광석) 없애고 왕관만", SPEC A23-84 / king_slime_crown)
-- Studio MCP execute_luau, MAIN place, Edit mode only (메인 반영 runs it; the runner replaces "__MODE__").
-- Slime Prince (BigSlime) gets the ore-free body: every MeshPart under ServerStorage.CustomModels.BigSlime that uses the slime cube
-- mesh (old 101084943554251 or the back-fixed 100045743344061) gets the no-ore mesh (art/models/tripo/MonsterSlimeCube_noore.glb,
-- WorldKit import E8 "SlimePrinceBody2", same axes / bounding box as the back-fixed one) by MeshPart:ApplyMesh. Size, CFrame and
-- TextureID stay (ApplyMesh clears TextureID: put back); the old id is kept in the attribute PrinceBodyWas.
-- The small Shard Slime ("Slime") and PetBabySlime keep their ore: only the model named T.Model is touched.
-- The small crown on the Prince is slime_backfix_crown.luau's job (ADD_CROWN) / 메인 반영; this tool never adds or removes a crown.
-- MODE: "plan" = count only, "apply" (default), "restore" = put the old mesh back from PrinceBodyWas. Idempotent.

local MODE = "__MODE__"
if MODE ~= "plan" and MODE ~= "restore" then MODE = "apply" end
if game:GetService("RunService"):IsRunning() then error("Edit 모드에서만 실행하세요.") end
local AssetService = game:GetService("AssetService")

local T = {
	Model = "BigSlime",
	-- the E8 import's mesh id (MeshPart SlimePrinceBody2 in the WorldKit place): filled in by the id ledger
	NewMesh = "rbxassetid://__NEWMESH__",
	Cube = { "101084943554251", "100045743344061" },
}
assert(not string.find(T.NewMesh, "__NEWMESH__", 1, true), "T.NewMesh is not filled in yet: import E8_SlimePrinceBody.glb, then set the mesh id")

local root = game:GetService("ServerStorage"):FindFirstChild("CustomModels")
local model = root and root:FindFirstChild(T.Model)
if not model then return "no ServerStorage.CustomModels." .. T.Model end

local function makeMesh(id)
	local ok, mp = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromUri(id)) end)
	if not ok then ok, mp = pcall(function() return AssetService:CreateMeshPartAsync(id) end) end
	return ok and mp or nil, (not ok) and tostring(mp) or nil
end
local function isCube(meshId)
	for _, c in T.Cube do
		if string.find(meshId, c, 1, true) then return true end
	end
	return false
end

local parts = {}
if model:IsA("MeshPart") then table.insert(parts, model) end
for _, d in model:GetDescendants() do
	if d:IsA("MeshPart") then table.insert(parts, d) end
end

local swapped, skipped, restored, failed, names = 0, 0, 0, {}, {}
local newMesh, err
for _, d in parts do
	local was = d:GetAttribute("PrinceBodyWas")
	if MODE == "restore" then
		if type(was) == "string" then
			local oldMp = makeMesh(was)
			if oldMp then
				local size, cf, tex = d.Size, d.CFrame, d.TextureID
				d:ApplyMesh(oldMp)
				d.Size, d.CFrame, d.TextureID = size, cf, tex
				d:SetAttribute("PrinceBodyWas", nil)
				restored += 1
			end
		end
		continue
	end
	if was then skipped += 1 continue end
	if not isCube(d.MeshId) then continue end -- the crown mesh and anything else stay
	if MODE == "plan" then swapped += 1 table.insert(names, d:GetFullName()) continue end
	if not newMesh then
		newMesh, err = makeMesh(T.NewMesh)
		if not newMesh then table.insert(failed, "new mesh: " .. tostring(err)) break end
	end
	local size, cf, oldId, tex = d.Size, d.CFrame, d.MeshId, d.TextureID
	local ok, e = pcall(function() d:ApplyMesh(newMesh) end)
	if ok then
		d.Size, d.CFrame, d.TextureID = size, cf, tex
		d:SetAttribute("PrinceBodyWas", oldId)
		swapped += 1
		table.insert(names, d:GetFullName())
	else
		table.insert(failed, d:GetFullName() .. ": " .. tostring(e))
	end
end
return string.format("slime_prince_body %s: swapped %d, skipped %d, restored %d, failed %d %s | %s", MODE, swapped, skipped, restored,
	#failed, table.concat(failed, "; "), table.concat(names, ", "))
