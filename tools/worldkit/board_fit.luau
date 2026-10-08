-- board_fit.luau (게임성 개발 1, 2026-10-08; 검수: "게시판 위에 검은 상자 'Board' 글자가 떠 있음")
-- Studio MCP execute_luau, main place, Edit mode. crossroads_3d_swap.luau moved Map.Landmarks.MostWantedBoard (the
-- bounty list: a 1 x 12 x 20 part, SurfaceGui BoardGui on its +X face, MapBuilder ensureBoardGui) onto the new
-- X_NoticeBoard's front face at its OLD size, so its top sticks out above the smaller 3D board. This fits the part into
-- the new board's face: the part becomes invisible (Transparency 1, no collision - only the SurfaceGui shows), its
-- height / width are fractions of the 3D board's box (FitH / FitW) around FitY of its height, its face stays where the
-- swap put it. Idempotent (the size comes from the 3D board every run). MODE = "survey" only reports the boxes.
local MODE = "apply"
local T = { FitH = 0.42, FitW = 0.72, FitY = 0.48, Depth = 0.2 } -- the panel under the 3D board's roof (10/08 photo)
local map = workspace:FindFirstChild("Map")
local board = map and map:FindFirstChild("Landmarks") and map.Landmarks:FindFirstChild("MostWantedBoard")
local c3 = map and map:FindFirstChild("Decor") and map.Decor:FindFirstChild("Crossroads3D")
local nb = c3 and c3:FindFirstChild("X_NoticeBoard")
assert(board and board:IsA("BasePart"), "Map.Landmarks.MostWantedBoard missing")
assert(nb and nb:IsA("Model"), "Map.Decor.Crossroads3D.X_NoticeBoard missing")
local cf, size = nb:GetBoundingBox()
local bottom = cf.Position.Y - size.Y / 2
local out = {
	string.format("3D board box: centre (%.1f, %.1f, %.1f) size %.1f x %.1f x %.1f (bottom %.1f)", cf.Position.X, cf.Position.Y,
		cf.Position.Z, size.X, size.Y, size.Z, bottom),
	string.format("bounty part before: pos (%.1f, %.1f, %.1f) size %.1f x %.1f x %.1f transp %.2f", board.Position.X, board.Position.Y,
		board.Position.Z, board.Size.X, board.Size.Y, board.Size.Z, board.Transparency),
}
if MODE == "apply" then
	if board:GetAttribute("FitPrevSize") == nil then
		board:SetAttribute("FitPrevSize", board.Size)
		board:SetAttribute("FitPrevCF", board.CFrame)
	end
	-- the 3D board's long side is its width (the panel faces across it)
	local width = math.max(size.X, size.Z) * T.FitW
	local height = size.Y * T.FitH
	local y = bottom + size.Y * T.FitY
	-- keep the +X face (the SurfaceGui) where the swap put it: a thinner part moves its centre back by half the change
	local shift = (board.Size.X - T.Depth) / 2
	local rot = board.CFrame.Rotation
	board.Size = Vector3.new(T.Depth, height, width)
	board.CFrame = CFrame.new(board.Position.X, y, board.Position.Z) * rot * CFrame.new(shift, 0, 0)
	board.Transparency = 1
	board.CanCollide = false
	board.CastShadow = false
	for _, post in board:GetChildren() do
		if post:IsA("BasePart") and post.Name == "BoardPost" then
			post.Transparency = 1
			post.CanCollide = false
		end
	end
	table.insert(out, string.format("bounty part after: pos (%.1f, %.1f, %.1f) size %.1f x %.1f x %.1f, invisible (only its SurfaceGui)",
		board.Position.X, board.Position.Y, board.Position.Z, board.Size.X, board.Size.Y, board.Size.Z))
end
return table.concat(out, "\n")
