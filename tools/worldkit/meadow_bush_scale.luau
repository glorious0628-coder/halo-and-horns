-- meadow_bush_scale.luau (검수 2026-10-09 request: "덤불은 1.5~2배 크게" — pass 4, 메인 반영)
-- Studio MCP execute_luau, MAIN place, Edit mode only. After meadow_dress.luau (kit) and BEFORE decor_collision.luau:
-- every Kit_M_BushA / Kit_M_BushB model under Map.Decor.MeadowDress is scaled up by FACTOR from its bottom centre
-- (ScaleTo; the pivot is the bottom centre, triangles stay the same, part count stays the same). A bush's factor is cut back
-- so it never reaches a hunting lawn, a road strip (+1), or a non-bush piece (tree trunk post, fence, rock, vignette
-- piece; 0.8 x (r1 + r2) kept); bushes touching each other in a clump overlap on purpose (the concept's blob).
-- Attribute BushScaleWas keeps the old scale (idempotent; MODE "restore" puts it back). MODE "plan" counts only.
local MODE = "__MODE__"
if MODE ~= "plan" and MODE ~= "restore" then MODE = "apply" end
if game:GetService("RunService"):IsRunning() then error("Edit 모드에서만 실행하세요.") end
local FACTOR = 1.6
local dress = workspace.Map.Decor:FindFirstChild("MeadowDress")
if not dress then return "no MeadowDress" end
local LAWNS = {
	{ 250, -104, 328, -30 }, { 252, 30, 318, 110 }, { 348, -104, 500, -30 }, { 524, -104, 608, -30 },
	{ 352, 54, 512, 110 }, { 362, 126, 512, 200 }, { 555, 44, 608, 196 }, { 252, -200, 388, -140 },
	{ 476, -200, 580, -140 },
}
local ROADS = { { 210, -9, 650, 9 }, { 260, -125, 600, -115 }, { 529, 9, 541, 246 } }
local function boxDist(b, x, z)
	local dx = math.max(b[1] - x, 0, x - b[3])
	local dz = math.max(b[2] - z, 0, z - b[4])
	return math.sqrt(dx * dx + dz * dz)
end
local function isBush(m) return m:IsA("Model") and (m.Name == "Kit_M_BushA" or m.Name == "Kit_M_BushB") end
local bushes, others = {}, {}
local function collect(root)
	for _, m in root:GetDescendants() do
		if m:IsA("Model") and m.Name ~= "Big" and m.Name ~= "Small" and not string.find(m.Name, "^Cell_") then
			local cf, sz = m:GetBoundingBox()
			local e = { M = m, X = cf.Position.X, Z = cf.Position.Z, R = math.max(sz.X, sz.Z) / 2 }
			if isBush(m) then table.insert(bushes, e) else table.insert(others, e) end
		end
	end
end
collect(dress)
local kitFolder = workspace.Map.Decor:FindFirstChild("MeadowKit")
if kitFolder then collect(kitFolder) end
local scaled, cut, none, minF, sumF = 0, 0, 0, 9, 0
for _, b in bushes do
	local was = b.M:GetAttribute("BushScaleWas")
	if MODE == "restore" then
		if was then b.M:ScaleTo(was) b.M:SetAttribute("BushScaleWas", nil) scaled += 1 end
		continue
	end
	if was then continue end
	local r0 = b.R
	local f = FACTOR
	for _, L in LAWNS do f = math.min(f, (boxDist(L, b.X, b.Z) - 0.5) / r0) end
	for _, R in ROADS do f = math.min(f, (boxDist(R, b.X, b.Z) - 1) / r0) end
	for _, o in others do
		local dx, dz = o.X - b.X, o.Z - b.Z
		local d2 = dx * dx + dz * dz
		if d2 < (r0 * FACTOR + o.R + 8) ^ 2 then
			f = math.min(f, (math.sqrt(d2) / 0.8 - o.R) / r0)
		end
	end
	if f < 1.05 then none += 1 continue end
	if f < FACTOR then cut += 1 end
	if MODE == "apply" then
		b.M:SetAttribute("BushScaleWas", b.M:GetScale())
		b.M:ScaleTo(b.M:GetScale() * f)
	end
	scaled += 1
	minF = math.min(minF, f)
	sumF += f
end
return string.format("%s: bushes %d, scaled %d (cut back %d, left as is %d), factor min %.2f avg %.2f", MODE, #bushes, scaled, cut, none, minF == 9 and 0 or minF, scaled > 0 and sumF / scaled or 0)
