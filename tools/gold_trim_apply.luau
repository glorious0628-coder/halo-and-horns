-- gold_trim_apply (이미지 개발 2026-10-11): HH_HaloGoldTrim -> metal 0.5 + rough 0.15 + part Color (255,195,45).
-- 검수 10/11 night: final working gold (art/review/imgdev/gold_candidates_sheet2_2026-10-11.jpg, building_variants_halo.json).
-- Run with Studio MCP execute_luau in an EDIT-mode place (WorldKit; STUDIO_NAME=WorldKit). Saves nothing, no Play, no window changes.
--   MODE "survey": list the MaterialVariant maps + every part using HH_HaloGoldTrim, change nothing.
--   "apply": MV MetalnessMap/RoughnessMap -> new values, those parts' Color -> NEW_COLOR.
--   "undo": MV maps and part Color back to the old values (0.7 / 0.35 / 255,175,25).
-- Only touches the MaterialVariant named HH_HaloGoldTrim and parts whose MaterialVariant == "HH_HaloGoldTrim".
local MODE = "survey"
local ALLOW_MAIN = false -- 메인 반영 1: true only for the main place
if (game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil")) and not ALLOW_MAIN then
	error("WRONG STUDIO: main (ALLOW_MAIN is false)")
end
local NEW = { metal = "rbxassetid://137160255192059", rough = "rbxassetid://109029776386025", color = Color3.fromRGB(255, 195, 45) }
local OLD = { metal = "rbxassetid://139091750772198", rough = "rbxassetid://128833041727597", color = Color3.fromRGB(255, 175, 25) }
local NAME = "HH_HaloGoldTrim"
local MS = game:GetService("MaterialService")
local function c255(c) return string.format("%d,%d,%d", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255)) end
local mv = MS:FindFirstChild(NAME)
if not (mv and mv:IsA("MaterialVariant")) then error(NAME .. " not found in MaterialService") end
local out = {}
table.insert(out, string.format("MV before: metal %s | rough %s | color %s | normal %s", mv.MetalnessMap, mv.RoughnessMap, mv.ColorMap, mv.NormalMap))
local target = MODE == "apply" and NEW or (MODE == "undo" and OLD or nil)
if target then
	mv.MetalnessMap = target.metal
	mv.RoughnessMap = target.rough
	table.insert(out, string.format("MV after:  metal %s | rough %s", mv.MetalnessMap, mv.RoughnessMap))
end
local n, changed, colours = 0, 0, {}
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and d.MaterialVariant == NAME then
		n += 1
		if target and d.Color ~= target.color then
			d.Color = target.color
			changed += 1
		end
		local k = c255(d.Color)
		colours[k] = (colours[k] or 0) + 1
	end
end
local parts = {}
for k, v in colours do table.insert(parts, k .. " x" .. v) end
table.insert(out, string.format("MODE %s: %d parts use %s, %d colour changed; colours now: %s", MODE, n, NAME, changed, table.concat(parts, ", ")))
return table.concat(out, "\n")
