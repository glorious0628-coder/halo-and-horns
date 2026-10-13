-- tripo_props_swap.luau (이미지 생성 3, 10/13): swap the Halo v2 props (Workspace.HaloV2.Props Real / StandIn / Placeholder whose
-- Kit attribute is in KITS) for the Tripo kits in ServerStorage.HaloTripoKits. Same spot: XZ + facing of the old one, feet on the
-- ground under it, height = the old one's height (placeholder Size.Y / stand-in or old kit box), so the plan sizes stay.
-- Old objects are moved to ServerStorage.Parked_PreTripoProps (nothing deleted). Prepend `local KITS = {"A", "B"}`.
if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end
local SS = game:GetService("ServerStorage")
local K = SS.HaloTripoKits
local PARK = SS:FindFirstChild("Parked_PreTripoProps") or Instance.new("Folder"); PARK.Name = "Parked_PreTripoProps"; PARK.Parent = SS
local Props = workspace.HaloV2.Props
local Real = Props.Real
local want = {}
for _, k in KITS do want[k] = true end
local gp = RaycastParams.new(); gp.FilterType = Enum.RaycastFilterType.Include
gp.FilterDescendantsInstances = { workspace.Terrain, workspace.HaloV2:FindFirstChild("Ground"), workspace.HaloV2:FindFirstChild("Buildings") }
local out, n = {}, 0
local todo = {}
for _, fname in { "Real", "StandIn", "Placeholder" } do
	local f = Props:FindFirstChild(fname)
	if f then
		for _, o in f:GetChildren() do
			local kn = o:GetAttribute("Kit")
			if kn and want[kn] and not o:GetAttribute("TripoKit") then table.insert(todo, o) end
		end
	end
end
for _, o in todo do
	local kn = o:GetAttribute("Kit")
	local kit = K:FindFirstChild(kn)
	if not kit then table.insert(out, kn .. " no kit"); continue end
	local pos, rot, h, bottom
	if o:IsA("BasePart") then
		h = o.Size.Y
		pos = o.Position
		rot = o.CFrame.Rotation
		bottom = o.Position.Y - h / 2
	else
		local cf, s = o:GetBoundingBox()
		local pv = o:GetPivot()
		h = s.Y
		pos = pv.Position
		rot = pv.Rotation
		bottom = cf.Position.Y - s.Y / 2
	end
	local m = kit:Clone()
	local _, ks = m:GetBoundingBox()
	m:ScaleTo(h / ks.Y)
	-- ground under the old object (it is parked first so the ray does not hit it)
	o.Parent = PARK
	local hit = workspace:Raycast(Vector3.new(pos.X, bottom + 6, pos.Z), Vector3.new(0, -14, 0), gp)
	local gy = hit and hit.Position.Y or bottom
	m:PivotTo(CFrame.new(pos.X, gy, pos.Z) * rot)
	for k, v in o:GetAttributes() do
		if k ~= "Placeholder" and k ~= "StandIn" then m:SetAttribute(k, v) end
	end
	m:SetAttribute("TripoKit", true)
	m.Name = o.Name
	m.Parent = Real
	n += 1
	table.insert(out, string.format("%s h %.2f g %.2f", o.Name, h, gy))
end
return n .. " swapped | " .. table.concat(out, " | ")
