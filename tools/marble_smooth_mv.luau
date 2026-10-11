-- marble_smooth_mv (이미지 개발 2026-10-11): (re)create the MaterialVariant HH_HaloMarbleSmooth_Cream in an EDIT-mode practice place
-- (WorldKit: STUDIO_NAME=WorldKit, execute_luau; never the main Studio). Idempotent. Round 3 maps (디자인 검수 10/11 passed).
-- Use after a place is rebuilt / reopened without it. Parts: Material Marble + MaterialVariant "HH_HaloMarbleSmooth_Cream" + Color (255,244,222).
if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end
local MS = game:GetService("MaterialService")
local mv = MS:FindFirstChild("HH_HaloMarbleSmooth_Cream")
local made = false
if not (mv and mv:IsA("MaterialVariant")) then
	mv = Instance.new("MaterialVariant")
	mv.Name = "HH_HaloMarbleSmooth_Cream"
	made = true
end
mv.BaseMaterial = Enum.Material.Marble
mv.MaterialPattern = Enum.MaterialPattern.Regular
mv.StudsPerTile = 8
mv.ColorMap = "rbxassetid://140510838680155"
mv.NormalMap = "rbxassetid://131597673772642"
mv.RoughnessMap = "rbxassetid://76093268063395"
mv.MetalnessMap = "rbxassetid://87489921567476"
mv.Parent = MS
return string.format("made=%s color %s rough %s", tostring(made), mv.ColorMap, mv.RoughnessMap)
