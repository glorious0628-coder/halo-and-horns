-- slime_prince_body.luau (이미지 생성 1, 2026-10-09; 사용자 "결정석 없애고 왕관만" + "슬라임 얼굴 주름", SPEC A23-84 / A23-92)
-- Studio MCP execute_luau, MAIN place, Edit mode only (메인 반영 runs it; the runner replaces "__MODE__").
-- Gives the slime bodies in ServerStorage.CustomModels the smooth-shaded meshes (tools/blender_slime_smooth.py: no creases round the
-- eyes / cheeks; same silhouette, size and UVs as the back-fixed cube) by MeshPart:ApplyMesh:
--   * BigSlime (the Slime Prince): E8 "SlimePrinceBody4" = NO ore + smooth + the patched blue texture (the new top uses a texture
--     block the old texture has not painted, so the texture changes with the mesh);
--   * Slime (the small Shard Slime): E10 "SlimeBodySmooth" = ore kept + smooth, TextureID unchanged.
-- Only the MeshParts that still use the slime cube mesh (old 101084943554251 or back-fixed 100045743344061) are swapped (the crown,
-- other monsters and PetBabySlime stay). Size, CFrame and TextureID stay (ApplyMesh clears TextureID: put back); the old values are
-- kept in attributes BodyWas / BodyTexWas. This tool never adds or removes a crown (the small crown on the Prince, 0.7x, centred on
-- the head, is slime_backfix_crown.luau's / 메인 반영's job).
-- MODE: "plan" = count only, "apply" (default), "restore" = put the old mesh / texture back. Idempotent.

local MODE = "__MODE__"
if MODE ~= "plan" and MODE ~= "restore" then MODE = "apply" end
if game:GetService("RunService"):IsRunning() then error("Edit 모드에서만 실행하세요.") end
local AssetService = game:GetService("AssetService")

local T = {
	Cube = { "101084943554251", "100045743344061" },
	Targets = {
		{ Model = "BigSlime", Mesh = "rbxassetid://__PRINCEMESH__", Texture = "rbxassetid://101248064145914" }, -- 이미지 개발 upload (asset_ids.json)
		{ Model = "Slime", Mesh = "rbxassetid://__SMALLMESH__", Texture = nil },
	},
}
local function filled(id) return not string.find(id, "__", 1, true) end
for _, tg in T.Targets do
	if MODE ~= "restore" then assert(filled(tg.Mesh), tg.Model .. ": mesh id not filled in yet (import the E8 / E10 glb, then set it)") end
end

local root = game:GetService("ServerStorage"):FindFirstChild("CustomModels")
if not root then return "no ServerStorage.CustomModels" end

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

local swapped, skipped, restored, failed, names = 0, 0, 0, {}, {}
for _, tg in T.Targets do
	local model = root:FindFirstChild(tg.Model)
	if not model then
		table.insert(failed, "no CustomModels." .. tg.Model)
		continue
	end
	local parts = {}
	if model:IsA("MeshPart") then table.insert(parts, model) end
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") then table.insert(parts, d) end
	end
	local newMesh, err
	for _, d in parts do
		local was = d:GetAttribute("BodyWas")
		if MODE == "restore" then
			if type(was) == "string" then
				local oldMp = makeMesh(was)
				if oldMp then
					local size, cf, tex = d.Size, d.CFrame, d.TextureID
					d:ApplyMesh(oldMp)
					local texWas = d:GetAttribute("BodyTexWas")
					d.Size, d.CFrame = size, cf
					d.TextureID = type(texWas) == "string" and texWas or tex
					d:SetAttribute("BodyWas", nil)
					d:SetAttribute("BodyTexWas", nil)
					restored += 1
				end
			end
			continue
		end
		if was then skipped += 1 continue end
		if not isCube(d.MeshId) then continue end
		if MODE == "plan" then swapped += 1 table.insert(names, d:GetFullName()) continue end
		if not newMesh then
			newMesh, err = makeMesh(tg.Mesh)
			if not newMesh then
				table.insert(failed, tg.Model .. " new mesh: " .. tostring(err))
				break
			end
		end
		local size, cf, oldId, tex = d.Size, d.CFrame, d.MeshId, d.TextureID
		local ok, e = pcall(function() d:ApplyMesh(newMesh) end)
		if ok then
			d.Size, d.CFrame = size, cf
			d.TextureID = tg.Texture or tex
			d:SetAttribute("BodyWas", oldId)
			d:SetAttribute("BodyTexWas", tex)
			swapped += 1
			table.insert(names, d:GetFullName())
		else
			table.insert(failed, d:GetFullName() .. ": " .. tostring(e))
		end
	end
end
return string.format("slime bodies %s: swapped %d, skipped %d, restored %d, failed %d %s | %s", MODE, swapped, skipped, restored,
	#failed, table.concat(failed, "; "), table.concat(names, ", "))
