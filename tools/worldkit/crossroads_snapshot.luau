-- crossroads_snapshot.luau (게임성 개발 1, 2026-10-08; 검수 watch 3: "Edit에서 swap을 두 번 돌려도 게시판이 그대로인지"):
-- Studio MCP execute_luau, main place, Edit mode, read only. Returns JSON: every Map.Decor.Crossroads3D child's name and
-- pivot (rounded to 0.01), the X_SupporterBoard / SupporterFace pivots, sizes, tag and gold ColorMap, and the
-- MostWantedBoard part's size / CFrame / transparency - the before / after of crossroads_3d_swap.luau runs.
local CS = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local map = workspace:FindFirstChild("Map")
local c3 = map and map:FindFirstChild("Decor") and map.Decor:FindFirstChild("Crossroads3D")
local out = { Children = {}, Count = 0 }
local function r(v) return math.floor(v * 100 + 0.5) / 100 end
local function cf(c)
	local rx, ry, rz = c:ToEulerAnglesYXZ()
	return { r(c.Position.X), r(c.Position.Y), r(c.Position.Z), r(math.deg(rx)), r(math.deg(ry)), r(math.deg(rz)) }
end
if c3 then
	for _, ch in c3:GetChildren() do
		out.Count += 1
		local key = ch.Name
		local n = 1
		while out.Children[key] do
			n += 1
			key = ch.Name .. "#" .. n
		end
		local ok, pv = pcall(function() return ch:GetPivot() end)
		out.Children[key] = ok and cf(pv) or "no pivot"
	end
	local sb = c3:FindFirstChild("X_SupporterBoard")
	if sb then
		local face = sb:FindFirstChild("SupporterFace")
		local mesh = sb:FindFirstChild("X_NoticeBoard_Gold")
		local sa = mesh and mesh:FindFirstChildWhichIsA("SurfaceAppearance")
		out.Supporter = { Pivot = cf(sb:GetPivot()), Face = face and cf(face.CFrame) or nil,
			FaceSize = face and { r(face.Size.X), r(face.Size.Y), r(face.Size.Z) } or nil,
			Tagged = face and CS:HasTag(face, "SupporterBoard") or false, ColorMap = sa and tostring(sa.ColorMap) or nil }
	end
end
local board = map and map:FindFirstChild("Landmarks") and map.Landmarks:FindFirstChild("MostWantedBoard")
if board then
	out.Bounty = { CFrame = cf(board.CFrame), Size = { r(board.Size.X), r(board.Size.Y), r(board.Size.Z) },
		Transparency = board.Transparency, CanCollide = board.CanCollide }
end
return HttpService:JSONEncode(out)
