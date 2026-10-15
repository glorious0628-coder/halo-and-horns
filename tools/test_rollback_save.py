"""tools/rollback_save.py offline (게시 준비 운영 ②, 게임성 개발 2, 2026-10-15).

Runs the tool's own run() with a fake Studio client whose execute_luau runs the tool's REAL Luau snippets in the installed Luau
CLI against a versioned in-memory DataStore double (ListVersionsAsync / GetVersionAsync / GetAsync / UpdateAsync, key info with
Version and GetUserIds). The store survives between calls (JSON in, JSON out). Checks: the version list, the dry run (backup,
no write), the rollback (a new newest version = the old data, SessionLock dropped, read back), every refusal (Play mode before the
read / before the write, an unknown version, a newer save format, the player on a live server, a save landing between the backup
and the write), and that a refusal never writes. Then each mutation of the tool must be caught.

Usage: py tools/test_rollback_save.py [--no-mutations] [--luau path/to/luau.exe]
"""
from __future__ import annotations

import argparse
import contextlib
import importlib.util
import io
import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools/rollback_save.py"
EDIT = "Current Studio Mode: Edit"

WORLD = r'''
local function enc(v)
	local t = type(v)
	if t == "number" then
		if v == math.floor(v) and math.abs(v) < 1e15 then return string.format("%d", v) end
		return string.format("%.10g", v)
	elseif t == "string" then
		return '"' .. string.gsub(v, '[%c"\\]', function(c) return string.format("\\u%04x", string.byte(c)) end) .. '"'
	elseif t == "boolean" then
		return v and "true" or "false"
	elseif t == "table" then
		local n = #v
		local count = 0
		for _ in v do count += 1 end
		if n > 0 and count == n then
			local parts = {}
			for i = 1, n do parts[i] = enc(v[i]) end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local keys = {}
		for k in v do table.insert(keys, tostring(k)) end
		table.sort(keys)
		local parts = {}
		for _, k in keys do
			local val = v[k]
			if val == nil then val = v[tonumber(k)] end
			table.insert(parts, enc(k) .. ":" .. enc(val))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return "null"
end
local function copy(v)
	if type(v) ~= "table" then return v end
	local c = {}
	for k, x in v do c[k] = copy(x) end
	return c
end
local CONFIG = { Data = { StoreName = "HaloHorns_Player_v1", KeyPrefix = "P_", Version = 6, LockTimeout = 600 },
	StoreName = function(base) return base .. (STATE.suffix or "") end }
STATE.calls = STATE.calls or {}
local function newest()
	for i = #STATE.versions, 1, -1 do
		if not STATE.versions[i].Deleted then return STATE.versions[i] end
	end
	return nil
end
local function infoOf(row)
	if not row then return nil end
	return { Version = row.Version, GetUserIds = function() return copy(row.UserIds or {}) end }
end
local function append(value, uids)
	local row = { Version = "v" .. tostring(#STATE.versions + 1), CreatedTime = 1760500000000 + #STATE.versions * 60000,
		Value = copy(value), UserIds = copy(uids or {}) }
	table.insert(STATE.versions, row)
	return row
end
local store = {}
function store:GetAsync(key, opts)
	table.insert(STATE.calls, "Get:" .. key)
	local row = newest()
	if not row then return nil, nil end
	return copy(row.Value), infoOf(row)
end
function store:GetVersionAsync(key, ver)
	table.insert(STATE.calls, "GetVersion:" .. key .. ":" .. tostring(ver))
	for _, row in STATE.versions do
		if row.Version == ver and not row.Deleted then return copy(row.Value), infoOf(row) end
	end
	return nil, nil
end
function store:ListVersionsAsync(key, dir, minDate, maxDate, limit)
	table.insert(STATE.calls, "List:" .. key .. ":" .. tostring(dir))
	local page = {}
	for i = #STATE.versions, 1, -1 do
		if #page >= limit then break end
		local row = STATE.versions[i]
		table.insert(page, { Version = row.Version, CreatedTime = row.CreatedTime, IsDeleted = row.Deleted == true })
	end
	return { GetCurrentPage = function() return page end }
end
function store:UpdateAsync(key, fn)
	table.insert(STATE.calls, "Update:" .. key)
	if STATE.landBefore then -- a game server saved between the tool's check and its write
		append(STATE.landBefore, { 7 })
		STATE.landBefore = nil
	end
	local row = newest()
	local value, uids = fn(row and copy(row.Value) or nil, infoOf(row))
	if value ~= nil then append(value, uids) end
	return value
end
local services = {
	RunService = { IsRunning = function() return STATE.running == true end },
	HttpService = { JSONEncode = function(_, v) return enc(v) end },
	DataStoreService = { GetDataStore = function(_, name)
		STATE.storeName = name
		return store
	end },
}
local game = { GetService = function(_, n) return services[n] end,
	ReplicatedStorage = { Shared = { Config = { Clone = function() return "ConfigModule" end } } } }
local require = function() return CONFIG end
local Instance = { new = function() return {} end }
local Enum = { SortDirection = { Descending = "Descending" } }
if STATE.lockAge then -- the player's session lock (a live server unless lockStudio)
	local row = newest()
	if row then row.Value.SessionLock = { JobId = STATE.lockStudio and "" or "job-123", Time = os.time() - STATE.lockAge } end
	STATE.lockAge = nil
end
local okRun, result = pcall(function()
__SNIPPET__
end)
print("RESULT_JSON " .. (okRun and tostring(result) or enc({ error = tostring(result) })))
print("STATE_JSON " .. enc(STATE))
'''


def lua_literal(v) -> str:
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, list):
        return "{" + ", ".join(lua_literal(x) for x in v) + "}"
    if isinstance(v, dict):
        return "{" + ", ".join(f"[{json.dumps(str(k))}] = {lua_literal(x)}" for k, x in v.items()) + "}"
    raise TypeError(type(v))


class FakeStudio:
    """a Studio double: get_studio_state answers modes in order; execute_luau runs the snippet in the Luau CLI on the store"""

    def __init__(self, luau: Path, work: Path, state: dict, modes: list[str] | None = None):
        self.luau, self.work, self.state = luau, work, state
        self.modes = list(modes or [])
        self.runs: list[str] = []

    def call(self, tool: str, args: dict) -> dict:
        if tool == "get_studio_state":
            mode = self.modes.pop(0) if self.modes else "Edit"
            return {"content": [{"text": f"Current Studio Mode: {mode}\nPlace: test"}]}
        if tool != "execute_luau":
            raise AssertionError(tool)
        code = args["code"]
        self.runs.append(code)
        self.state["running"] = False
        script = "local STATE = " + lua_literal(self.state) + "\n" + WORLD.replace("__SNIPPET__", code)
        path = self.work / f"run_{len(self.runs)}.luau"
        path.write_text(script, encoding="utf-8")
        proc = subprocess.run([str(self.luau), str(path)], capture_output=True, timeout=60)
        out = proc.stdout.decode("utf-8", "replace")
        result = state = None
        for line in out.splitlines():
            if line.startswith("RESULT_JSON "):
                result = line[len("RESULT_JSON "):]
            elif line.startswith("STATE_JSON "):
                state = json.loads(line[len("STATE_JSON "):])
        if state is None:
            raise AssertionError("the Luau run failed:\n" + proc.stderr.decode("utf-8", "replace")[-1500:] + out[-1500:])
        state["versions"] = state.get("versions") or []
        if isinstance(state["versions"], dict):
            state["versions"] = [state["versions"][k] for k in sorted(state["versions"], key=int)]
        self.state.clear()
        self.state.update(state)
        return {"content": [{"text": result or ""}]}


def base_state() -> dict:
    return {"versions": [
        {"Version": "v1", "CreatedTime": 1760400000000, "Value": {"Version": 6, "Level": 9, "Gold": 500, "PlaytimeSeconds": 3000},
         "UserIds": [42]},
        {"Version": "v2", "CreatedTime": 1760410000000, "Value": {"Version": 6, "Level": 10, "Gold": 800, "PlaytimeSeconds": 3600,
                                                                  "SessionLock": {"JobId": "old-job", "Time": 1}}, "UserIds": [42]},
        {"Version": "v3", "CreatedTime": 1760420000000, "Value": {"Version": 6, "Level": 1, "Gold": 0, "PlaytimeSeconds": 3700},
         "UserIds": [42]},  # the broken save the test player wants undone
    ]}


def load_tool(source: str):
    spec = importlib.util.spec_from_loader("rollback_save_under_test", loader=None)
    mod = importlib.util.module_from_spec(spec)
    mod.__file__ = str(TOOL)
    exec(compile(source, str(TOOL), "exec"), mod.__dict__)
    return mod


def scenarios(tool, luau: Path) -> list[tuple[bool, str]]:
    out: list[tuple[bool, str]] = []

    def check(ok, name):
        out.append((bool(ok), name))

    with tempfile.TemporaryDirectory(prefix="rollback_") as tmp:
        work = Path(tmp)
        backups = work / "backups"

        def go(state, target=None, yes=False, modes=None):
            fake = FakeStudio(luau, work, state, modes)
            buf = io.StringIO()
            code = None
            with contextlib.redirect_stdout(buf):
                try:
                    code = tool.run(fake, 42, target, yes, 20, backup_dir=str(backups))
                except SystemExit as e:
                    code = ("exit", str(e))
            return code, buf.getvalue(), fake

        def newest(state):
            return state["versions"][-1]

        def writes(fake):
            return sum(1 for c in fake.state.get("calls", []) if str(c).startswith("Update:"))

        # 1. the list
        st = base_state()
        code, text, fake = go(st)
        check(code == 0 and text.index("  v3  ") < text.index("  v2  ") < text.index("  v1  "), "list: newest first")
        check("Lv9 gold 500 save v6" in text and "store HaloHorns_Player_v1 key P_42" in text, "list: level / gold / save version, store and key")
        check(writes(fake) == 0 and len(st["versions"]) == 3, "list: nothing written")
        # 2. the dry run
        st = base_state()
        code, text, fake = go(st, "v1")
        files = sorted(backups.glob("42_*_before_rollback.json"))
        check(code == 0 and "dry run" in text and len(files) == 1, "dry run: a backup, no write")
        check(writes(fake) == 0 and len(st["versions"]) == 3, "dry run: the store is untouched")
        saved = json.loads(files[-1].read_text(encoding="utf-8")) if files else {}
        check(saved.get("version") == "v3" and (saved.get("value") or {}).get("Level") == 1, "the backup holds the current record (v3)")
        # 3. the rollback
        st = base_state()
        code, text, fake = go(st, "v2", True)
        top = newest(st)
        check(code == 0 and "restored" in text and "Undo: --to v3" in text, "rollback: restored, undo hint names the old newest")
        check(len(st["versions"]) == 4 and top["Value"].get("Level") == 10 and top["Value"].get("Gold") == 800, "rollback: v4 = v2's data")
        check("SessionLock" not in top["Value"], "rollback: the old session lock is dropped")
        check(top.get("UserIds") == [42], "rollback: the record keeps its user ids")
        check(st["versions"][2]["Value"]["Level"] == 1, "rollback: nothing deleted (v3 stays in the history)")
        # 4. refusals
        st = base_state()
        code, text, fake = go(st, "v9", True)
        check(code == 1 and "no record" in text and len(st["versions"]) == 3, "refused: an unknown version")
        st = base_state()
        st["versions"][0]["Value"]["Version"] = 7
        code, text, fake = go(st, "v1", True)
        check(code == 1 and "newer save format" in text and len(st["versions"]) == 3, "refused: a newer save format")
        st = base_state()
        st["lockAge"] = 30
        code, text, fake = go(st, "v1", True)
        check(code == 1 and "live server" in text and len(st["versions"]) == 3, "refused: the player is online (a live lock)")
        st = base_state()
        st["lockAge"] = 30
        st["lockStudio"] = True
        code, text, fake = go(st, "v1", True)
        check(code == 0 and len(st["versions"]) == 4, "a Studio test lock does not block it")
        st = base_state()
        st["lockAge"] = 5000
        code, text, fake = go(st, "v1", True)
        check(code == 0 and len(st["versions"]) == 4, "an old lock (past LockTimeout) does not block it")
        st = base_state()
        st["landBefore"] = {"Version": 6, "Level": 2, "Gold": 5}
        code, text, fake = go(st, "v1", True)
        check(code == 1 and "changed" in text and len(st["versions"]) == 4 and newest(st)["Value"]["Level"] == 2,
              "refused: a save landed between the backup and the write (the game's save stays)")
        st = base_state()
        before = len(list(backups.glob("*.json")))
        code, text, fake = go(st, "v1", True, modes=["Play"])
        check(isinstance(code, tuple) and len(st["versions"]) == 3 and len(fake.runs) == 0
              and len(list(backups.glob("*.json"))) == before, "refused: Play mode before the read (nothing read, no backup)")
        st = base_state()
        code, text, fake = go(st, "v1", True, modes=["Edit", "Play"])
        check(isinstance(code, tuple) and len(st["versions"]) == 3 and writes(fake) == 0, "refused: Play mode right before the write")
        st = base_state()
        st["running"] = True
        fake = FakeStudio(luau, work, st)
        res = tool.run_luau(fake, tool.restore_lua(42, "v1", "v3").replace(
            'if game:GetService("RunService"):IsRunning()', 'if true or game:GetService("RunService"):IsRunning()'))
        check("Edit mode only" in str(res.get("error")) and len(st["versions"]) == 3, "the snippet itself refuses a running game")
    return out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--luau", type=Path, default=ROOT / "build/luau_cli_0_741/luau.exe")
    ap.add_argument("--no-mutations", action="store_true")
    a = ap.parse_args()
    if not a.luau.is_file():
        print("Installed Luau CLI missing; this test never downloads tools.", file=sys.stderr)
        return 1
    source = TOOL.read_text(encoding="utf-8")
    results = scenarios(load_tool(source), a.luau)
    failed = [n for ok, n in results if not ok]
    for ok, n in results:
        print(("ok   " if ok else "FAIL ") + n)
    print(f"ROLLBACK checks={len(results)} failed={len(failed)}")
    mutations = [
        ("no live-lock check", "and os.time() - (tonumber(lock.Time) or 0) < (tonumber(Config.Data.LockTimeout) or 0) then",
         "and false then"),
        ("no version check in the write", "if ((nowInfo and nowInfo.Version) or \"\") ~= expected then return nil end", ""),
        ("the old lock kept", "old.SessionLock = nil -- an old lock", "local _ = nil -- an old lock"),
        ("no second Edit check", "    require_edit(client, \"right before the write\")\n", ""),
        ("no format check", "if (tonumber(old.Version) or 0) > (tonumber(Config.Data.Version) or 0) then", "if false then"),
        ("writes without --yes", "    if not yes:\n", "    if False:\n"),
        ("no backup", "        json.dump(cur, f, ensure_ascii=False, indent=1)\n", "        f.write('{}')\n"),
        ("user ids dropped", "\t\treturn old, userIds\n", "\t\treturn old\n"),
    ]
    caught = 0
    if not a.no_mutations:
        for name, old, new in mutations:
            if source.count(old) != 1:
                print(f"MUTATION NOT APPLIED {name}")
                continue
            try:
                res = scenarios(load_tool(source.replace(old, new, 1)), a.luau)
                hit = any(not ok for ok, _ in res)
            except Exception as e:  # noqa: BLE001 - a crash is a catch
                hit = True
                name += f" (crashed: {type(e).__name__})"
            caught += 1 if hit else 0
            print(("MUTATION caught  " if hit else "MUTATION MISSED ") + name)
        print(f"MUTATIONS caught={caught}/{len(mutations)}")
    ok = not failed and (a.no_mutations or caught == len(mutations))
    print(f"ROLLBACK {'passed' if ok else 'failed'}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
