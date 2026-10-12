-- night_lamps_apply (이미지 개발 2026-10-12, 최종 검수 결정): the town lamp PointLights = colour (255,214,160), Brightness 0.5, Range 10;
-- lamps on a house that has many lamps close together (HaloDomeHouse_08) = Range 8. Practice place only (WorldKit, Edit, execute_luau).
-- MODE "survey" lists, "apply" sets, "undo" puts back 255,214,140 / 0.7 / 12. Enabled is left as found (lamps are switched on by WeatherFx in the game).
local MODE = "__MODE__"
if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end
local n, r8, seen = 0, 0, {}
for _, d in workspace.SkeletonTest:GetDescendants() do
	if d:IsA("PointLight") and d.Parent and d.Parent:GetAttribute("LampLight") then
		n += 1
		local range = 10
		local a = d.Parent
		while a and a ~= workspace do
			if string.find(a.Name, "HaloDomeHouse_08", 1, true) then range = 8 end
			a = a.Parent
		end
		-- the rows sit at x = 2940 + 36 * index (08 = index 6 -> x 3156, z 60): also by position in case the part names do not carry the house
		local p = d.Parent:IsA("BasePart") and d.Parent.Position or nil
		if p and math.abs(p.X - 3156) < 22 and math.abs(p.Z - 60) < 40 then range = 8 end
		if range == 8 then r8 += 1 end
		local key = string.format("%d,%d,%d|%.2f|%.1f", math.round(d.Color.R * 255), math.round(d.Color.G * 255), math.round(d.Color.B * 255), d.Brightness, d.Range)
		seen[key] = (seen[key] or 0) + 1
		if MODE == "apply" then
			d.Color = Color3.fromRGB(255, 214, 160)
			d.Brightness = 0.5
			d.Range = range
		elseif MODE == "undo" then
			d.Color = Color3.fromRGB(255, 214, 140)
			d.Brightness = 0.7
			d.Range = 12
		end
	end
end
local out = {}
for k, v in seen do table.insert(out, k .. " x" .. v) end
return string.format("MODE %s: %d lamps (%d with range 8); before: %s", MODE, n, r8, table.concat(out, ", "))
