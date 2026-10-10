-- One NEW! at a time (검수 10/10; tools/test_new_tag.py): runs the real UIKit.NewTag / UIKit.NextNewTag (cut out of
-- UIKit.luau, input NEWTAG_SOURCE) on doubles: GuiObjects with a parent chain, a hand clock, a task.delay queue and a
-- UIKit.ShowNewTag that records the parts it tagged. Every check is named and counted.
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then
		print("CHECK_OK " .. name)
	else
		failed += 1
		print("CHECK_FAIL " .. name .. " :: " .. tostring(detail))
	end
end
local NOW = 100
local DELAYS = {}
local function gui(name, parent)
	local o = { __kind = "Instance", Name = name, Parent = parent or { Name = "Gui" }, Visible = true }
	function o.IsA(_, c) return c == "GuiObject" end
	function o.IsDescendantOf(self, other)
		local p = self.Parent
		while type(p) == "table" do
			if p == other then return true end
			p = p.Parent
		end
		return false
	end
	return o
end
local SHOWN = {}
local UIKit = { ShowNewTag = function(t) table.insert(SHOWN, t.Name) return { Name = "NewTag" } end }
local NOTIFY = { NewTag = { Seconds = 6, Gap = 0.4 }, NewQ = { Active = nil, Until = 0, Queue = {}, Draining = false } }
local env = setmetatable({
	UIKit = UIKit, NOTIFY = NOTIFY,
	typeof = function(v) return type(v) == "table" and rawget(v, "__kind") or type(v) end,
	os = { clock = function() return NOW end },
	task = { delay = function(t, fn, ...) table.insert(DELAYS, { At = NOW + t, Fn = fn, Args = table.pack(...) }) end },
}, { __index = getfenv() })
local f = assert(loadstring(NEWTAG_SOURCE, "=NewTag"))
setfenv(f, env)
f()
local function advance(sec)
	NOW += sec
	local again = true
	while again do
		again = false
		for i, d in DELAYS do
			if d.At <= NOW then
				table.remove(DELAYS, i)
				d.Fn(table.unpack(d.Args, 1, d.Args.n))
				again = true
				break
			end
		end
	end
end
local function shown() return table.concat(SHOWN, ",") end

local war = gui("War")
local info = gui("Info", war)
local lines = gui("Lines")
local goose = gui("Goose")
check(UIKit.NewTag(war) ~= nil and shown() == "War", "the first part gets its tag at once", shown())
check(UIKit.NewTag(info) == nil and shown() == "War", "a part inside the tagged one gets none (the same thing)", shown())
check(UIKit.NewTag(lines) == nil and shown() == "War", "a different part waits while one shows", shown())
check(UIKit.NewTag(goose) == nil, "a third part waits too", shown())
check(UIKit.NewTag(lines) == nil and #NOTIFY.NewQ.Queue == 2, "a part already waiting is not queued twice", #NOTIFY.NewQ.Queue)
advance(3)
check(shown() == "War", "nothing new while the first tag shows", shown())
advance(3.5)
check(shown() == "War,Lines", "when it goes (+ the gap) the next one gets its tag", shown())
advance(6.5)
check(shown() == "War,Lines,Goose", "... then the one after it", shown())
advance(10)
check(#NOTIFY.NewQ.Queue == 0 and not NOTIFY.NewQ.Draining, "the queue ends empty", #NOTIFY.NewQ.Queue)
check(UIKit.NewTag(info) ~= nil and shown() == "War,Lines,Goose,Info", "after all of them a part gets its tag at once again",
	shown())
check(UIKit.NewTag(info) ~= nil and shown() == "War,Lines,Goose,Info,Info", "the same part again restarts its tag", shown())
local hidden = gui("Hidden")
local after = gui("After")
UIKit.NewTag(hidden)
UIKit.NewTag(after)
hidden.Visible = false
advance(7)
check(shown() == "War,Lines,Goose,Info,Info,After", "a waiting part hidden by its turn is skipped", shown())
check(UIKit.NewTag({ __kind = "Instance", IsA = function() return false end }) == nil, "not a GuiObject: nothing", "")
print(("NEW_TAG_SUMMARY checks=%d failed=%d"):format(checks, failed))
