-- line-of-sight check from the gate photo camera (이미지 생성 1): what blocks the view to the rule-7 targets
local cam = Vector3.new(0, 10, -346)
local out = {}
local function check(name, t)
	local rp = RaycastParams.new()
	local ex = {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and (d.Transparency >= 0.9 or d.Name == "Wall") then table.insert(ex, d) end
	end
	rp.FilterDescendantsInstances = ex
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local r = workspace:Raycast(cam, t - cam, rp)
	if not r then
		table.insert(out, name .. ": clear")
		return
	end
	local top = r.Instance
	while top.Parent and top.Parent ~= workspace and not top.Parent:IsA("Folder") do
		top = top.Parent
	end
	table.insert(out, string.format("%s: hit %s at %.0f,%.0f,%.0f (target %.0f away, hit %.0f)", name, top:GetFullName(), r.Position.X, r.Position.Y, r.Position.Z, (t - cam).Magnitude, (r.Position - cam).Magnitude))
end
__TARGETS__
return table.concat(out, "\n")
