-- Skinning resolves named bones through joints inside the same nearest Model.
local M = {}

local function finite(v)
	return type(v) == "number" and v == v and math.abs(v) < math.huge
end

local function close(a, b, q)
	if typeof(a) ~= "CFrame" or typeof(b) ~= "CFrame" then return false end
	local aa, bb = { a:GetComponents() }, { b:GetComponents() }
	for i = 1, 12 do
		if not finite(aa[i]) or not finite(bb[i]) or math.abs(aa[i] - bb[i]) > math.max(0.001, q * 0.001) then return false end
	end
	return true
end

local function scaled(cf, q)
	return CFrame.new(cf.Position * q) * cf.Rotation
end

function M.Validate(model, q)
	if not model or model:GetAttribute("HHC_SkinBindingSchema") ~= 1 or not finite(q) or q < 0.01 or q > 100 then return false end
	local skin, root = model:FindFirstChild("CostumeSkin"), model:FindFirstChild("HumanoidRootPart")
	if not skin or not skin:IsA("Model") or not root or not root:IsA("BasePart") then return false end
	local rootSize = model:GetAttribute("HHC_SkinRootBindSize")
	if typeof(rootSize) ~= "Vector3" or math.min(rootSize.X, rootSize.Y, rootSize.Z) <= 0 then return false end
	for _, ratio in { root.Size.X / rootSize.X, root.Size.Y / rootSize.Y, root.Size.Z / rootSize.Z } do
		if not finite(ratio) or math.abs(ratio - q) > math.max(0.001, q * 0.001) then return false end
	end
	local ref = skin:FindFirstChild("HHC_SkinBindingHost")
	local host = ref and ref:IsA("ObjectValue") and ref.Value
	if not host or not host:IsA("BasePart") or host:FindFirstAncestorOfClass("Model") ~= skin then return false end
	local hostBind = host:GetAttribute("HHC_SkinHostBindRoot")
	if typeof(hostBind) ~= "CFrame" then return false end
	local rootWeld = host:FindFirstChild("CostumeSkinRootWeld")
	if not rootWeld or not rootWeld:IsA("WeldConstraint") or not rootWeld.Enabled or rootWeld.Part0 ~= root or rootWeld.Part1 ~= host then return false end
	local accepted, parts, meshes, bones = { [rootWeld] = true }, {}, 0, 0
	for _, part in skin:GetDescendants() do
		if part:IsA("BasePart") then
			if part:FindFirstAncestorOfClass("Model") ~= skin or part.Anchored or not part.Massless or part.CanCollide then return false end
			parts[part] = true
			if part:IsA("MeshPart") then meshes += 1 end
			local bind = part:GetAttribute("HHC_SkinHostBindRoot")
			if typeof(bind) ~= "CFrame" or not close(root.CFrame:ToObjectSpace(part.CFrame), scaled(bind, q), q) then return false end
			if part ~= host then
				local weld = part:FindFirstChild("CostumeSkinInternalWeld")
				if not weld or not weld:IsA("Weld") or not weld.Enabled or weld.Part0 ~= host or weld.Part1 ~= part
					or not close(weld.C0, scaled(hostBind:Inverse() * bind, q), q) or not close(weld.C1, CFrame.identity, q) then return false end
				accepted[weld] = true
			end
		elseif part:IsA("Bone") then
			bones += 1
			if part:FindFirstAncestorOfClass("Model") ~= skin then return false end
		end
	end
	if not parts[host] or (meshes ~= 2 and meshes ~= 3) or bones < 15 then return false end
	-- Extra joints can bind a mesh to the moving proxy a second time or escape the internal skeleton.
	for _, joint in model:GetDescendants() do
		if joint:IsA("JointInstance") or joint:IsA("WeldConstraint") then
			if (parts[joint.Part0] or parts[joint.Part1]) and not accepted[joint] then return false end
		elseif joint:IsA("Constraint") then
			local a, b = joint.Attachment0, joint.Attachment1
			if (a and a:IsDescendantOf(skin)) or (b and b:IsDescendantOf(skin)) then return false end
		end
	end
	return true, host, rootWeld
end

return M
