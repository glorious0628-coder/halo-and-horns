-- Offline checks for SupporterBoard.luau (SPEC A23-75: the VIP supporters board). The runner (tools/test_supporter_board.py)
-- prepends BOARD_SOURCE. Roblox is replaced by small doubles: CollectionService (tagged parts, an added signal),
-- GameState with the SupporterNames attribute and its change signal, Instance.new building plain tables that support
-- FindFirstChild (recursive), Util.Warn. Every check is named; no Studio, Roblox API or network calls.
local checks, failed = 0, 0
local function check(name, ok, detail)
	checks += 1
	if not ok then
		failed += 1
		print(("CHECK_FAIL %s :: %s"):format(name, tostring(detail or "")))
	end
end
local function signal()
	local s = { Fns = {} }
	function s:Connect(fn) table.insert(self.Fns, fn); return { Disconnect = function() end } end
	function s:Fire(...) for _, fn in self.Fns do fn(...) end end
	return s
end

local function newInst(class)
	local o = { __kind = "Instance", ClassName = class, Name = class, Children = {} }
	function o:IsA(c) return c == self.ClassName or (c == "BasePart" and self.ClassName == "Part") or c == "Instance" end
	function o:FindFirstChild(n, recursive)
		for _, ch in self.Children do
			if ch.Name == n then return ch end
			if recursive then
				local found = ch:FindFirstChild(n, true)
				if found then return found end
			end
		end
		return nil
	end
	return setmetatable(o, { __newindex = function(t, k, v)
		if k == "Parent" then
			rawset(t, "_parent", v)
			if v then table.insert(v.Children, t) end
			return
		end
		rawset(t, k, v)
	end, __index = function(t, k) if k == "Parent" then return rawget(t, "_parent") end return nil end })
end
local GS = { Attr = {}, Signals = {} }
function GS:GetAttribute(k) return self.Attr[k] end
function GS:GetAttributeChangedSignal(k)
	self.Signals[k] = self.Signals[k] or signal()
	return self.Signals[k]
end
local function setNames(v)
	GS.Attr.SupporterNames = v
	if GS.Signals.SupporterNames then GS.Signals.SupporterNames:Fire() end
end
local TAGGED = {}
local ADDED = signal()
local CS = { GetTagged = function(_, tag) if tag == "SupporterBoard" then return TAGGED end return {} end,
	GetInstanceAddedSignal = function(_, tag) return ADDED end }
local env = setmetatable({
	game = { GetService = function(_, n)
		if n == "CollectionService" then return CS end
		if n == "ReplicatedStorage" then return { WaitForChild = function() return { WaitForChild = function(_, m) return { __module = m } end } end } end
		return {}
	end },
	typeof = function(v) return type(v) == "table" and rawget(v, "__kind") or type(v) end,
	Instance = { new = newInst },
	Enum = setmetatable({}, { __index = function(_, t) return setmetatable({}, { __index = function(_, i) return t .. "." .. i end }) end }),
	Vector2 = { new = function(x, y) return { X = x, Y = y } end },
	Color3 = { fromRGB = function(r, g, b) return { R = r, G = g, B = b } end },
	UDim2 = { new = function(...) return { ... } end, fromScale = function(...) return { ... } end,
		fromOffset = function(...) return { ... } end },
	task = { spawn = function(fn, ...) fn(...) end },
	require = function(m)
		if m.__module == "Net" then return { GameState = function() return GS end } end
		return { Warn = function() end }
	end,
}, { __index = getfenv() })
local fn = assert(loadstring(BOARD_SOURCE, "=SupporterBoard"))
setfenv(fn, env)
local Board = fn()

-- pure helpers
local n = Board.Names("Ann\nBo\n\n   \n  Cy  \n<b>Dee</b>")
check("Names: lines trimmed, empty and blank lines dropped, brackets removed", #n == 4 and n[1] == "Ann" and n[3] == "Cy" and n[4] == "bDee/b",
	table.concat(n, "|"))
local many = {}
for i = 1, 40 do table.insert(many, "P" .. i) end
check("Names: at most 30 (newest first kept)", #Board.Names(table.concat(many, "\n")) == 30 and Board.Names(table.concat(many, "\n"))[1] == "P1")
check("Names: a very long name is cut with …", Board.Names(string.rep("x", 40))[1] == string.rep("x", 20) .. "…", Board.Names(string.rep("x", 40))[1])
check("Names: not a string -> empty", #Board.Names(nil) == 0 and #Board.Names(5) == 0)
check("Text: no supporters -> the plain thank-you line (no buy button, no pressure)", Board.Text({}) == "Thank you for playing!")
check("Text: names in rows of three", Board.Text({ "A", "B", "C", "D" }) == "A    B    C\nD", Board.Text({ "A", "B", "C", "D" }))

-- the boards
local part = newInst("Part")
table.insert(TAGGED, part)
GS.Attr.SupporterNames = "Ann\nBo"
Board.Init({})
Board.Start()
local gui = part:FindFirstChild("SupporterGui")
local body = part:FindFirstChild("Names", true)
local title = part:FindFirstChild("Title", true)
check("a tagged board gets the SurfaceGui with the title and the names", gui ~= nil and gui.ClassName == "SurfaceGui"
	and title and title.Text == "Thank you, supporters!" and body and body.Text == "Ann    Bo", body and body.Text)
setNames("Cy\nAnn\nBo")
check("the list changes -> the board redraws (newest first)", body.Text == "Cy    Ann    Bo", body.Text)
local count = #part.Children
setNames("Cy")
check("a redraw reuses the same SurfaceGui (no pile-up)", #part.Children == count and body.Text == "Cy", #part.Children)
local late = newInst("Part")
table.insert(TAGGED, late)
ADDED:Fire(late)
local lateBody = late:FindFirstChild("Names", true)
check("a board that streams in later draws at once", lateBody ~= nil and lateBody.Text == "Cy", lateBody and lateBody.Text)
setNames("")
check("an empty list -> the thank-you line on every board", body.Text == "Thank you for playing!" and lateBody.Text == "Thank you for playing!")

print(("SUPPORTER_BOARD_SUMMARY checks=%d failed=%d"):format(checks, failed))
if failed == 0 then print("SUPPORTER_BOARD_OFFLINE_OK") end
