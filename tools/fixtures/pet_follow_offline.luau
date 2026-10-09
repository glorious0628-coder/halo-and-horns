-- Real PetFollow (PET-3) + engine doubles. Review 2026-10-06: after a headbutt the pet runs back to its owner over
-- P.Back seconds instead of jumping there in one frame. Also: it follows behind-right, reaches the target at the contact
-- time, Has / Attack / Dash answers. Input: SOURCE.
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if not ok then
		failed += 1
		print("CHECK_FAIL " .. name .. " :: " .. tostring(detail))
	end
end
local function signal()
	local rows, s = {}, {}
	function s:Connect(fn) table.insert(rows, fn); return { Disconnect = function() end } end
	function s:Fire(...) for _, fn in table.clone(rows) do fn(...) end end
	return s
end
local vmt = {}
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vmt) end
vmt.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
vmt.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vmt.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
vmt.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Unit" then local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z); return vec(v.X / m, v.Y / m, v.Z / m) end
	if k == "Lerp" then return function(a, b, t) return vec(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t) end end
	if k == "Cross" then return function(a, b) return vec(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end end
	return nil
end
local function cfAt(p, look) return { Position = p, LookVector = look or vec(0, 0, -1) } end
local CF = { new = function(x, y, z)
	if type(x) == "table" then return cfAt(x) end
	return cfAt(vec(x, y, z))
end, lookAt = function(at, target) return cfAt(at, (target - at).Unit) end }
local W = { clock = 10 }
local render = nil
local owner = { UserId = 7, Name = "Owner", Attrs = { EquippedPet = "BabySlime" }, Sigs = {} }
owner.Parent = true
local root = { Position = vec(0, 3, 0), CFrame = cfAt(vec(0, 3, 0), vec(0, 0, -1)) }
owner.Character = { FindFirstChild = function(_, n) if n == "HumanoidRootPart" then return root end end }
function owner:GetAttribute(k) return self.Attrs[k] end
function owner:GetAttributeChangedSignal(k) self.Sigs[k] = self.Sigs[k] or signal(); return self.Sigs[k] end
local made = {}
local function newModel()
	local m = { Name = "BabySlime", Pivot = nil, Attrs = {} }
	function m:IsA(c) return c == "Model" end
	function m:Clone() local c = newModel(); table.insert(made, c); return c end
	function m:GetDescendants() return {} end
	function m:GetBoundingBox() return cfAt(vec(0, 0, 0)), vec(1.8, 1.8, 1.8) end
	function m:GetScale() return 1 end
	function m:ScaleTo() end
	function m:SetAttribute(k, v) self.Attrs[k] = v end
	function m:PivotTo(cf) self.Pivot = cf end
	function m:Destroy() self.Parent = nil end
	return m
end
local template = newModel()
local petModels = { ChildAdded = signal(), FindFirstChild = function(_, n) if n == "BabySlime" then return template end end }
local RS = { FindFirstChild = function(_, n) if n == "PetModels" then return petModels end end,
	WaitForChild = function(_, n) if n == "PetModels" then return petModels end end }
local folder = { Name = "ClientPets" }
local WS = { CurrentCamera = { CFrame = { Position = vec(0, 10, 20) } },
	FindFirstChild = function(_, n) if n == "ClientPets" then return folder end end, Raycast = function() return nil end }
local UIS = { TouchEnabled = false, KeyboardEnabled = true }
local PLAYERS = { owner }
local INSTS = {}
local REG = { PetWindow = { FollowerName = function() return W.name end }, UIKit = { Theme = {} } }
local services = {
	Players = { LocalPlayer = owner, PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return PLAYERS end },
	UserInputService = UIS,
	ReplicatedStorage = RS,
	RunService = { RenderStepped = { Connect = function(_, fn) render = fn; return {} end } },
}
local fn = assert(loadstring(SOURCE))
setfenv(fn, setmetatable({
	game = { GetService = function(_, n) return assert(services[n], n) end }, workspace = WS,
	Vector3 = { new = vec, yAxis = vec(0, 1, 0) }, CFrame = CF,
	RaycastParams = { new = function() return {} end }, Enum = { RaycastFilterType = { Exclude = "Exclude" }, Font = { GothamBold = "GothamBold" } },
	Instance = { new = function(c) local o = { ClassName = c } table.insert(INSTS, o) return o end },
	UDim2 = { fromOffset = function(x, y) return { X = x, Y = y } end, fromScale = function(x, y) return { SX = x, SY = y } end },
	Color3 = { new = function(r, g, b) return { r, g, b } end },
	os = { clock = function() return W.clock end },
	task = { defer = function(f, ...) f(...) end, spawn = function(f, ...) f(...) end },
	warn = function(...) print("WARN", ...) end, print = function() end,
	typeof = function(v) if getmetatable(v) == vmt then return "Vector3" end return type(v) end,
}, { __index = getfenv() }))
local PF = fn()
PF.Init(REG)
PF.Start()
check(type(render) == "function", "PetFollow draws on RenderStepped")
local pet = made[1]
check(pet ~= nil and pet.Name == "Pet_7" and pet.Parent == folder and PF.Has(7) == true, "the owner's EquippedPet is drawn in workspace.ClientPets",
	pet and pet.Name)
local DT = 1 / 60
local function frame() W.clock += DT; render(DT) end
for _ = 1, 120 do frame() end
local p = pet.Pivot.Position
-- behind-right of an owner looking along -Z: +X and +Z
check(p.X > 1.5 and p.Z > 1.5 and math.abs(p.X - 2.6) < 0.3 and math.abs(p.Z - 2.4) < 0.3,
	"it settles behind-right of its owner (2.6 right, 2.4 back)", { p.X, p.Z })
-- a headbutt: reach the target at the contact time, then run back over P.Back
local target = vec(0, 3, -12)
check(PF.Attack(7, { target }, 0.3) == true, "Attack: the drawn pet takes the move")
local hitAt, maxStep, backSteps, prev = nil, 0, 0, pet.Pivot.Position
local runFrames = math.floor(0.3 / DT + 0.5)
for i = 1, runFrames do
	frame()
	local q = pet.Pivot.Position
	if (vec(q.X, 0, q.Z) - vec(target.X, 0, target.Z)).Magnitude < 1 and not hitAt then hitAt = i * DT end
	prev = q
end
check(hitAt ~= nil and hitAt >= 0.15, "it reaches the target at about the contact time (0.3 s), not at once", hitAt)
for _ = 1, math.floor((0.12 + 0.3) / DT + 0.5) + 2 do
	frame()
	local q = pet.Pivot.Position
	local step = (vec(q.X, 0, q.Z) - vec(prev.X, 0, prev.Z)).Magnitude
	if step > 0.01 then backSteps += 1 end
	maxStep = math.max(maxStep, step)
	prev = q
end
local home = pet.Pivot.Position
check(maxStep < 4 and backSteps >= 10, "it runs back over P.Back (no one-frame jump of ~14 studs)", { maxStep, backSteps })
check(math.abs(home.X - 2.6) < 1 and math.abs(home.Z - 2.4) < 1, "and ends back behind-right of its owner", { home.X, home.Z })
check(PF.Dash(7, vec(5, 3, -5), 0.35) == true and PF.Attack(99, { target }, 0.3) == false and PF.Dash(7, "x", 0.3) == false,
	"Dash runs one move; no pet / bad position -> false (the punch shows instead)")
-- PET-4 (검수 2026-10-09): the name tag over MY pet only, the phone limit on other players' pets
local r = PF.Rank({ { Uid = 1, D = 50 }, { Uid = 2, D = 10 }, { Uid = 3, D = 90 }, { Uid = 4, D = 30 } }, 2, 80)
check(r[2] and r[4] and not r[1] and not r[3], "Rank: the nearest `max` within `range` only")
local r2 = PF.Rank({ { Uid = 1, D = 85 }, { Uid = 2, D = 90 } }, 6, 80)
check(next(r2) == nil, "Rank: nothing past `range`, however few")
local function tagOf(m)
	for _, o in INSTS do if o.ClassName == "BillboardGui" and o.Parent == m then return o end end
	return nil
end
local function labelOf(tag)
	for _, o in INSTS do if o.ClassName == "TextLabel" and o.Parent == tag then return o end end
	return nil
end
W.name = nil
for _ = 1, 40 do frame() end
check(tagOf(pet) == nil, "no story name (a tamer's plain Baby Slime): no tag over my pet")
W.name = "Good Buddy"
for _ = 1, 40 do frame() end
local tag = tagOf(pet)
local label = tag and labelOf(tag)
check(tag and tag.Enabled == true and label and label.Text == "Good Buddy" and tag.MaxDistance == 60 and label.TextSize >= 16,
	"my pet's story name floats over it (only near, readable)", label and label.Text)
W.name = "Little Minion"
for _ = 1, 40 do frame() end
check(label and label.Text == "Little Minion" and #(function() local n = {} for _, o in INSTS do if o.ClassName == "BillboardGui" then table.insert(n, o) end end return n end)() == 1,
	"... a new name updates the same tag (no second one)", label and label.Text)
W.name = nil
for _ = 1, 40 do frame() end
check(tag.Enabled == false, "... and hides when the pet has no story name any more")
-- other players: 9 pets at 10..90 studs from the camera (0, 10, 20)
local others = {}
for i = 1, 9 do
	local d = i * 10
	local o = { UserId = 100 + i, Name = "P" .. i, Attrs = { EquippedPet = "BabySlime" }, Sigs = {}, Parent = true }
	local rr = { Position = vec(d, 10, 20), CFrame = cfAt(vec(d, 10, 20), vec(0, 0, -1)) }
	o.Character = { FindFirstChild = function(_, n) if n == "HumanoidRootPart" then return rr end end }
	function o:GetAttribute(k) return self.Attrs[k] end
	function o:GetAttributeChangedSignal(k) self.Sigs[k] = self.Sigs[k] or signal(); return self.Sigs[k] end
	table.insert(PLAYERS, o)
	services.Players.PlayerAdded:Fire(o)
	table.insert(others, o)
end
local function petOf(uid)
	for _, m in made do if m.Name == "Pet_" .. uid and m.Parent then return m end end
	return nil
end
local function shown(uid)
	local m = petOf(uid)
	return m ~= nil and m.Pivot ~= nil and m.Pivot.Position.Y > -400
end
for _ = 1, 60 do frame() end
local pcAll = true
for _, o in others do if not shown(o.UserId) then pcAll = false end end
check(pcAll, "PC: every other pet within Range shows (no phone limit)")
UIS.TouchEnabled, UIS.KeyboardEnabled = true, false
for _ = 1, 60 do frame() end
local near6, farHidden = true, true
for i, o in others do
	if i <= 6 and not shown(o.UserId) then near6 = false end
	if i > 6 and shown(o.UserId) then farHidden = false end
end
check(near6 and farHidden, "phone: only the nearest 6 other pets within 80 studs show (70 / 80 / 90 hidden)")
check(shown(7), "phone: my own pet always shows")
others[1].Character = nil -- the nearest one leaves: the 7th nearest (70) comes in
for _ = 1, 60 do frame() end
check(shown(others[7].UserId) and not shown(others[8].UserId) and not shown(others[9].UserId),
	"phone: re-ranked every RankEvery s (the next one in, 80 / 90 still out)")
UIS.TouchEnabled, UIS.KeyboardEnabled = false, true
print("PET_FOLLOW_SUMMARY checks=" .. checks .. " failed=" .. failed)
