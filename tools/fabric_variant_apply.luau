-- fabric_variant_apply (이미지 개발 2026-10-11): put the HH_Fabric MaterialVariant on every Enum.Material.Fabric part.
-- Why: Fabric's built-in albedo is dark grey and ignores Part.Color (about 25 % of the colour, see
-- art/review/imgdev/hh_fabric_test_2026-10-11.jpg); HH_Fabric (near-white weave) takes the colour (96 % of SmoothPlastic).
-- Run tools/building_variants_main_fabric.luau FIRST (it makes the variant), then this. Edit mode, execute_luau.
--   MODE "survey": list the Fabric parts, change nothing.  "apply": MaterialVariant = "HH_Fabric" (+ COLOR_SCALE).
--   "undo": MaterialVariant = "" and Color divided by COLOR_SCALE again (use the same scale you applied).
-- COLOR_SCALE 1 keeps every Part.Color; use e.g. 0.85 only if the photo shows the cloth too bright.
-- Never changes anything but MaterialVariant (and Color when COLOR_SCALE ~= 1; undo is exact to +-1 of 255 by rounding).
local ALLOW_MAIN = false -- 메인 반영 1: true only for the main place
local MODE = "survey"
local COLOR_SCALE = 1
local SCOPE = workspace -- an Instance: only its descendants (tests use a temporary model)
if (game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil")) and not ALLOW_MAIN then
	error("WRONG STUDIO: main (ALLOW_MAIN is false)")
end
local MS = game:GetService("MaterialService")
if MODE ~= "survey" and not (MS:FindFirstChild("HH_Fabric") and MS.HH_Fabric:IsA("MaterialVariant")) then
	error("HH_Fabric is not in MaterialService yet: run tools/building_variants_main_fabric.luau first")
end
local function c255(c) return string.format("%d,%d,%d", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255)) end
local out, n, changed = {}, 0, 0
for _, d in SCOPE:GetDescendants() do
	if d:IsA("BasePart") and d.Material == Enum.Material.Fabric then
		n += 1
		local before, bv = d.Color, d.MaterialVariant
		if MODE == "apply" then
			if d.MaterialVariant ~= "HH_Fabric" then changed += 1 end
			d.MaterialVariant = "HH_Fabric"
			if COLOR_SCALE ~= 1 then
				d.Color = Color3.new(math.min(1, before.R * COLOR_SCALE), math.min(1, before.G * COLOR_SCALE), math.min(1, before.B * COLOR_SCALE))
			end
		elseif MODE == "undo" then
			if d.MaterialVariant == "HH_Fabric" then changed += 1 end
			d.MaterialVariant = ""
			if COLOR_SCALE ~= 1 then
				d.Color = Color3.new(math.min(1, before.R / COLOR_SCALE), math.min(1, before.G / COLOR_SCALE), math.min(1, before.B / COLOR_SCALE))
			end
		end
		table.insert(out, string.format("%s | var '%s' -> '%s' | colour %s -> %s", d:GetFullName(), bv, d.MaterialVariant, c255(before), c255(d.Color)))
	end
end
table.insert(out, 1, string.format("MODE %s, COLOR_SCALE %g: %d Fabric parts, %d changed", MODE, COLOR_SCALE, n, changed))
return table.concat(out, "\n")
