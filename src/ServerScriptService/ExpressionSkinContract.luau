-- Verified skinned face attachment: root-owned material surface, shared original Head Bone.
local HttpService = game:GetService("HttpService")
local M = {}
local MARKERS = { "HHC_RigReady", "HHC_AnimationValidated", "HHC_SkinRuntimeValidated", "HHC_ExpressionSkinValidated", "HHC_ExpressionRuntimeValidated" }

local function hash(value)
	return type(value) == "string" and #value == 64 and value:match("^[0-9a-fA-F]+$") ~= nil
end

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function objectValue(mesh, name, class)
	local value = mesh:FindFirstChild(name)
	local target = value and value:IsA("ObjectValue") and value.Value
	return target and target:IsA(class) and target or nil
end

local function closeFrame(actual, bind, scale)
	if typeof(bind) ~= "CFrame" then return false end
	local expected = CFrame.new(bind.Position * scale) * bind.Rotation
	local a, b = { actual:GetComponents() }, { expected:GetComponents() }
	for i = 1, 12 do
		if not finite(a[i]) or math.abs(a[i] - b[i]) > math.max(0.001, scale * 0.001) then return false end
	end
	return true
end

local function scaleOf(root, model)
	local bind = model:GetAttribute("HHC_SkinRootBindSize")
	if typeof(bind) ~= "Vector3" or math.min(bind.X, bind.Y, bind.Z) <= 0 then return nil end
	local q = root.Size.X / bind.X
	if not finite(q) or q < 0.01 or q > 100 then return nil end
	for _, value in { root.Size.Y / bind.Y, root.Size.Z / bind.Z } do
		if not finite(value) or math.abs(value - q) > math.max(0.001, q * 0.001) then return nil end
	end
	return q
end

function M.IsReady(ctx)
	if type(ctx) ~= "table" then return false end
	local model, mesh, root, skin, bone, host, weld = ctx.Model, ctx.Mesh, ctx.Root, ctx.Skin, ctx.Bone, ctx.Host, ctx.Weld
	if not model.Parent or skin.Parent ~= model or root.Parent ~= model or mesh.Parent == nil
		or not mesh:IsDescendantOf(skin) or not host:IsDescendantOf(skin) or not bone:IsDescendantOf(skin)
		or bone.Parent ~= ctx.BoneParent or bone.Name ~= "Head" or mesh.Name ~= ctx.MeshName
		or model:GetAttribute("HHC_SkinRuntimeSchema") ~= 2 or model:GetAttribute("HHC_ExpressionSkinRuntimeSchema") ~= 1
		or model:GetAttribute("HHC_SkinRetargetRequired") ~= true then return false end
	for _, key in MARKERS do if model:GetAttribute(key) ~= true then return false end end
	if model:GetAttribute("HHC_SkinSourceSHA256") ~= ctx.SHA or model:GetAttribute("HHC_SkinManifest") ~= ctx.Manifest
		or model:GetAttribute("HHC_ExpressionInspectionSHA256") ~= ctx.InspectionSHA
		or mesh:GetAttribute("HHC_SkinSourceSHA256") ~= ctx.SHA or mesh:GetAttribute("HHC_ExpressionMeshValidated") ~= true
		or mesh:GetAttribute("HHC_ExpressionSkinValidated") ~= true or mesh:GetAttribute("HHC_ExpressionSkinMeshId") ~= ctx.MeshId
		or mesh.MeshId ~= ctx.MeshId or mesh.Anchored or not mesh.Massless or mesh.CanCollide
		or mesh:FindFirstChildOfClass("SurfaceAppearance") or objectValue(mesh, "HHC_ExpressionSkinBoneHost", "BasePart") ~= host
		or objectValue(mesh, "HHC_ExpressionSkinHeadBone", "Bone") ~= bone
		or objectValue(mesh, "HHC_ExpressionSkinRootWeld", "WeldConstraint") ~= weld then return false end
	if not weld.Parent or not weld:IsDescendantOf(skin) or not weld.Enabled or weld.Part0 ~= root or weld.Part1 ~= mesh
		or bone:GetAttribute("HHC_SkinPrincipal") ~= true or bone:GetAttribute("HHC_SkinBonePart") ~= "Head"
		or bone:GetAttribute("HHC_SkinSourceSHA256") ~= ctx.SHA then return false end
	local q = scaleOf(root, model)
	return q ~= nil and closeFrame(bone.CFrame, ctx.BoneBind, q)
		and closeFrame(root.CFrame:ToObjectSpace(mesh.CFrame), ctx.MeshBind, q)
		and closeFrame(root.CFrame:ToObjectSpace(host.CFrame), ctx.HostBind, q)
end

function M.Bind(model, head, mesh, def)
	if type(def) ~= "table" or def.SkinSchema ~= 1 or not hash(def.SkinSourceSHA256)
		or type(def.MeshId) ~= "string" or not def.MeshId:match("^rbxassetid://[1-9]%d*$") then return nil end
	local skin, root = model:FindFirstChild("CostumeSkin"), model:FindFirstChild("HumanoidRootPart")
	if not skin or not skin:IsA("Model") or not root or not root:IsA("BasePart") or head.Parent ~= model then return nil end
	local bone, host = objectValue(mesh, "HHC_ExpressionSkinHeadBone", "Bone"), objectValue(mesh, "HHC_ExpressionSkinBoneHost", "BasePart")
	local weld = objectValue(mesh, "HHC_ExpressionSkinRootWeld", "WeldConstraint")
	if not bone or not host or not weld then return nil end
	local actualHost = bone.Parent
	while actualHost and actualHost ~= skin and not actualHost:IsA("BasePart") do actualHost = actualHost.Parent end
	if actualHost ~= host then return nil end
	-- A second Head-proxy joint would deform the face twice. WeldConstraint is an Instance, not a Constraint subclass.
	for _, object in model:GetDescendants() do
		if object:IsA("JointInstance") or object:IsA("WeldConstraint") then
			if object ~= weld and (object.Part0 == mesh or object.Part1 == mesh) then return nil end
		elseif object:IsA("Constraint") then
			local a, b = object.Attachment0, object.Attachment1
			if (a and a:IsDescendantOf(mesh)) or (b and b:IsDescendantOf(mesh)) then return nil end
		end
	end
	local encoded, inspection = model:GetAttribute("HHC_SkinManifest"), model:GetAttribute("HHC_ExpressionInspectionSHA256")
	if type(encoded) ~= "string" or #encoded > 64000 or not hash(inspection) then return nil end
	local ok, manifest = pcall(HttpService.JSONDecode, HttpService, encoded)
	if not ok or type(manifest) ~= "table" or manifest.schema ~= 2 or manifest.mesh_instances ~= 3
		or manifest.skin_sha256 ~= def.SkinSourceSHA256 or manifest.name ~= model:GetAttribute("HHC_CostumeId")
		or type(manifest.meshes) ~= "table" or #manifest.meshes ~= 3 then return nil end
	local found = false
	for _, entry in manifest.meshes do
		local object = skin
		if type(entry.path) ~= "table" or #entry.path < 1 or #entry.path > 32 then return nil end
		for _, name in entry.path do
			if type(name) ~= "string" or not object then return nil end
			object = object:FindFirstChild(name)
		end
		if not object or not object:IsA("MeshPart") or object.MeshId ~= entry.mesh_id then return nil end
		if object == mesh then if found or entry.mesh_id ~= def.MeshId then return nil end; found = true end
	end
	if not found then return nil end
	local ctx = { Model = model, Mesh = mesh, Root = root, Skin = skin, Bone = bone, BoneParent = bone.Parent,
		Host = host, Weld = weld, SHA = def.SkinSourceSHA256, MeshId = def.MeshId, MeshName = def.MeshName,
		Manifest = encoded, InspectionSHA = inspection, BoneBind = bone:GetAttribute("HHC_SkinBindLocal"),
		MeshBind = mesh:GetAttribute("HHC_SkinHostBindRoot"), HostBind = host:GetAttribute("HHC_SkinHostBindRoot") }
	return M.IsReady(ctx) and ctx or nil
end

return M
