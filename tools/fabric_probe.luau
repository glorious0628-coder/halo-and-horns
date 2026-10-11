-- read-only (이미지 개발 2026-10-11): why does Enum.Material.Fabric render black? Run in Edit via execute_luau; changes nothing.
local MS = game:GetService("MaterialService")
local out = { "place " .. game.Name .. " id " .. tostring(game.PlaceId) }
local function tryget(o, k) local ok, v = pcall(function() return o[k] end) return ok and tostring(v) or "n/a" end
for _, k in { "Use2022Materials", "AutomaticCoverage" } do table.insert(out, "MaterialService." .. k .. " = " .. tryget(MS, k)) end
-- every override of a base material (MaterialService children and properties named like a material)
local n = 0
for _, c in MS:GetChildren() do
	n += 1
	if c:IsA("MaterialVariant") then
		table.insert(out, string.format("MV %-28s base %-14s studs %g color %s normal %s metal %s rough %s", c.Name, tostring(c.BaseMaterial), c.StudsPerTile,
			c.ColorMap ~= "" and "Y" or "-", c.NormalMap ~= "" and "Y" or "-", c.MetalnessMap ~= "" and "Y" or "-", c.RoughnessMap ~= "" and "Y" or "-"))
	else
		table.insert(out, "child " .. c.ClassName .. " " .. c.Name)
	end
end
table.insert(out, "MaterialService children: " .. n)
-- Fabric overrides: the property of the base-material name, if the engine exposes it
for _, m in { "Fabric", "SmoothPlastic", "Plastic" } do
	local ok, v = pcall(function() return MS:GetBaseMaterialOverride(Enum.Material[m]) end)
	table.insert(out, "BaseMaterialOverride " .. m .. " = " .. (ok and tostring(v) or "n/a"))
	local ok2, v2 = pcall(function() return MS[m .. "Name"] end)
end
-- variants whose name collides with a base material name, or whose base is Fabric
for _, c in MS:GetChildren() do
	if c:IsA("MaterialVariant") and (c.BaseMaterial == Enum.Material.Fabric or pcall(function() return Enum.Material[c.Name] end)) then
		table.insert(out, "!! variant on/like Fabric: " .. c.Name .. " base " .. tostring(c.BaseMaterial))
	end
end
-- all parts that are Fabric: their MaterialVariant and Colour
local fab, byVar = 0, {}
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and d.Material == Enum.Material.Fabric then
		fab += 1
		local key = (d.MaterialVariant ~= "" and d.MaterialVariant or "(none)") .. " | " .. tostring(d.Color)
		byVar[key] = (byVar[key] or 0) + 1
		if fab <= 6 then table.insert(out, "Fabric part " .. d:GetFullName() .. " var '" .. d.MaterialVariant .. "' colour " .. tostring(d.Color) .. " tex? " .. tostring(d:FindFirstChildOfClass("SurfaceAppearance") ~= nil)) end
	end
end
table.insert(out, "Fabric parts in workspace: " .. fab)
for k, v in byVar do table.insert(out, "  " .. v .. " x " .. k) end
-- lighting that could blacken it
local L = game:GetService("Lighting")
table.insert(out, string.format("Lighting spec %.2f diff %.2f B %.2f clock %.1f", L.EnvironmentSpecularScale, L.EnvironmentDiffuseScale, L.Brightness, L.ClockTime))
return table.concat(out, "\n")
