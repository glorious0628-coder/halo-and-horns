"""시스템 점검 1회차 - the environments (Config.StoreName), the server error record (ServerErrorService) and the live
switchboard (SwitchService) (게임성 개발 3, 2026-10-09), offline.

Runs the CURRENT Config, Util, ServerErrorService and SwitchService on tools/fixtures/dev2_kit.luau +
tools/fixtures/dev3_world.luau with tools/fixtures/ops_safety_offline.luau and the installed official Luau CLI
(ScriptContext, Heartbeat and the analytics log are doubles). Static checks: every DataStore name goes through
Config.StoreName, the services are listed, the hooks (Goose / CrownWar) read the switchboard, nothing sold, English only. No
Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies only.

Usage: py tools/test_ops_safety.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-09/offline_dev3_ops_safety_2026-10-09.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "ERR_SOURCE": SSS / "ServerErrorService.luau",
    "SWITCH_SOURCE": SSS / "SwitchService.luau",
}
C, E, W = "CONFIG_SOURCE", "ERR_SOURCE", "SWITCH_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    # --- environments
    ("Dev gets a suffix", C, "\tif env == \"Beta\" or env == \"Live\" then return base .. \"_\" .. env end\n\treturn base", "\treturn base .. \"_\" .. env"),
    ("Beta has no suffix", C, "if env == \"Beta\" or env == \"Live\" then return base .. \"_\" .. env end", "if env == \"Live\" then return base .. \"_\" .. env end"),
    ("Live has no suffix", C, "if env == \"Beta\" or env == \"Live\" then return base .. \"_\" .. env end", "if env == \"Beta\" then return base .. \"_\" .. env end"),
    ("any name is an environment", C, "\tif name == \"Beta\" or name == \"Live\" then return name end\n\treturn Config.Env.Default", "\tif name ~= nil then return name end\n\treturn Config.Env.Default"),
    ("the place id is ignored", C, "local name = ok and type(id) == \"number\" and Config.Env.Names[id] or nil", "local name = Config.Env.Names[81671223175574]"),
    ("the build label is old", C, "Config.BuildLabel = \"private-test 2026.10.16\"", "Config.BuildLabel = \"beta-prep 2026.10.09\""),
    ("5 errors become 50 a minute", C, "ServerErrors = { MaxPerMinute = 5,", "ServerErrors = { MaxPerMinute = 50,"),
    ("a switch is added", C, "\t\tGoose = { Type = \"Bool\", Default = true }, -- no new goose\n", "\t\tGoose = { Type = \"Bool\", Default = true }, -- no new goose\n\t\tAdmin = { Type = \"Bool\", Default = false },\n"),
    # review 10/14: PioneerTitle answers its Unread (off) until the first good read
    ("PioneerTitle without Unread", C, "PioneerTitle = { Type = \"Bool\", Default = true, Unread = false },",
     "PioneerTitle = { Type = \"Bool\", Default = true },"),
    ("Unread ignored", W, "\tif not READ and def.Unread ~= nil then return def.Unread end\n", ""),
    ("the first read never counts", W, "\tREAD = true\n\tSwitchService.Apply(", "\tSwitchService.Apply("),
    ("a failed read counts as read", W, "\tlocal ok, doc = pcall(st.GetAsync, st, W.Key or \"Live\")\n",
     "\tREAD = true\n\tlocal ok, doc = pcall(st.GetAsync, st, W.Key or \"Live\")\n"),
    ("the start ignores Unread", W, "\t\tVALUES[key] = fallback(def)\n", "\t\tVALUES[key] = def.Default\n"),
    # --- the error text
    ("digits are kept", E, "\ttext = string.gsub(text, \"%d%d%d+\", \"#\")\n", ""),
    ("control characters are kept", E, "\ttext = string.gsub(text, \"[%c]+\", \" \")\n", ""),
    ("no trimming", E, "\ttext = string.match(text, \"^%s*(.-)%s*$\") or \"\"\n", ""),
    ("no cut", E, "\tif #text > max then text = string.sub(text, 1, max) end\n", ""),
    # --- the record
    ("no minute limit", E, "\tif not limitOk(os.time()) then return false end\n", ""),
    ("the limit never resets", E, "\tif WINDOW.At ~= minute then WINDOW.At, WINDOW.N = minute, 0 end\n", ""),
    ("limit off by one", E, "if WINDOW.N >= math.max(0, math.floor(num(E.MaxPerMinute, 5))) then return false end", "if WINDOW.N > math.max(0, math.floor(num(E.MaxPerMinute, 5))) then return false end"),
    ("the limit counts nothing", E, "\tWINDOW.N += 1\n\treturn true\n", "\treturn true\n"),
    ("no analytics call", E, "\t\tlocal ok, err = pcall(t.Custom, p, \"ServerError\", math.max(1, math.floor(num(value, 1))), entry.S, entry.M, entry.K)\n", "\t\tlocal ok, err = true, nil\n"),
    ("the event has another name", E, "t.Custom, p, \"ServerError\",", "t.Custom, p, \"Server_Error\","),
    ("the value is always 1", E, "math.max(1, math.floor(num(value, 1))), entry.S", "1, entry.S"),
    ("fields swapped", E, "math.floor(num(value, 1))), entry.S, entry.M, entry.K)", "math.floor(num(value, 1))), entry.K, entry.M, entry.S)"),
    ("not cleaned", E, "S = ServerErrorService.Clean(scriptName, E.ScriptMax or 40),\n\t\tM = ServerErrorService.Clean(message, E.MessageMax or 80)", "S = tostring(scriptName),\n\t\tM = tostring(message)"),
    ("no duplicate rows", E, "if top and same(top, entry) and entry.T - top.T <= 60 then", "if false then"),
    ("duplicates forever", E, "and entry.T - top.T <= 60 then", "then"),
    ("the ring never trims", E, "\t\twhile #RING > math.max(1, math.floor(num(E.Keep, 50))) do table.remove(RING) end\n", ""),
    ("oldest first", E, "\t\ttable.insert(RING, 1, entry)\n", "\t\ttable.insert(RING, entry)\n"),
    ("Recent is the live table", E, "\tfor i, e in RING do out[i] = { T = e.T, K = e.K, S = e.S, M = e.M, N = e.N } end\n", "\tfor i, e in RING do out[i] = e end\n"),
    # --- the hooks
    ("script errors are not recorded", E, "\tScriptContext.Error:Connect(function(message, _trace, scriptInstance)\n\t\tlocal ok, err = pcall(ServerErrorService.Record, \"Error\"", "\tScriptContext.Error:Connect(function(message, _trace, scriptInstance)\n\t\tlocal ok, err = pcall(function() end, \"Error\""),
    ("the script name is not used", E, "scriptInstance and scriptInstance.Name or \"?\"", "\"?\""),
    ("slow ticks are not recorded", E, "\t\tif dt > num(E.SlowSeconds, 0.5) and", "\t\tif false and"),
    ("a half second is slow", E, "if dt > num(E.SlowSeconds, 0.5) and", "if dt >= num(E.SlowSeconds, 0.5) and"),
    ("the start is not ignored", E, "and os.clock() - startAt > num(E.SlowIgnoreFirst, 30) then", "then"),
    ("slow value is seconds", E, "string.format(\"tick %d ms\", math.floor(dt * 1000)), dt * 1000)", "string.format(\"tick %d ms\", math.floor(dt * 1000)), dt)"),
    ("no last flush at the close", E, "\tgame:BindToClose(function()\n\t\tpcall(ServerErrorService.Flush)\n\tend)\n", ""),
    # --- the saved document
    ("Studio writes the real store", E, "\t\tif RunService:IsStudio() then name ..= \"_STUDIO\" end\n\t\tlocal ok, st = pcall(DataStoreService.GetDataStore, DataStoreService, name)\n\t\tSTORE", "\t\tlocal ok, st = pcall(DataStoreService.GetDataStore, DataStoreService, name)\n\t\tSTORE"),
    ("the store ignores the environment", E, "\t\tlocal name = Config.StoreName and Config.StoreName(base) or base\n\t\tif RunService:IsStudio()", "\t\tlocal name = base\n\t\tif RunService:IsStudio()"),
    ("a flush with nothing saves", E, "\tif not DIRTY or #PENDING == 0 then return false end\n", ""),
    ("a failed save drops the pending", E, "\tUtil.Warn(TAG, \"save: \" .. tostring(err))\n\treturn false", "\tPENDING = {}\n\tDIRTY = false\n\treturn false"),
    ("the document is replaced, not merged", E, "\t\treturn ServerErrorService.Merge(old, mine)\n", "\t\treturn ServerErrorService.Merge({}, mine)\n"),
    ("the merge keeps everything", E, "\twhile #all > math.max(1, math.floor(num(E.Keep, 50))) do table.remove(all) end\n\treturn all", "\treturn all"),
    ("the merge puts the oldest first", E, "\ttable.sort(all, function(a, b) return a.T > b.T end)\n", "\ttable.sort(all, function(a, b) return a.T < b.T end)\n"),
    ("the merge trusts junk rows", E, "if type(e) == \"table\" and type(e.T) == \"number\" and type(e.S) == \"string\" and type(e.M) == \"string\" then", "if type(e) == \"table\" then"),
    ("'live' reads Studio's copy", E, "\tif which ~= \"live\" and RunService:IsStudio() then name ..= \"_STUDIO\" end\n", "\tif RunService:IsStudio() then name ..= \"_STUDIO\" end\n"),
    # --- the switchboard
    ("any key is applied", W, "\tfor key, def in defs() do\n\t\tlocal v = SwitchService.Sanitize(def, set[key])\n\t\tif v ~= nil then out[key] = v end\n\tend", "\tfor key, v in set do out[key] = v end"),
    ("a wrong type is a value", W, "\tif type(v) ~= \"boolean\" then return nil end\n\treturn v", "\treturn v"),
    ("numbers are not clamped", W, "\t\treturn math.clamp(v, num(def.Min, 0), num(def.Max, 1))\n", "\t\treturn v\n"),
    ("NaN is a number", W, "if type(v) ~= \"number\" or v ~= v or v == math.huge or v == -math.huge then return nil end", "if type(v) ~= \"number\" then return nil end"),
    ("an unknown key is off", W, "\tif def == nil then return true end\n", "\tif def == nil then return false end\n"),
    ("a switch not set keeps its old value", W, "\t\tif new == nil then new = def.Default end\n", "\t\tif new == nil then new = VALUES[key] end\n"),
    ("nothing is published", W, "\tif ok and gs then gs:SetAttribute(\"Switch\" .. key, SwitchService.Value(key)) end\n", ""),
    ("no change signal", W, "\t\t\tSwitchService.Changed:Fire(key, new)\n", ""),
    ("the signal fires every read", W, "\t\tif VALUES[key] ~= new then\n", "\t\tif true then\n"),
    ("a failed read applies defaults", W, "\tif not ok then\n\t\tUtil.Warn(TAG, \"read: \" .. tostring(doc))\n\t\treturn false\n\tend\n", "\tif not ok then\n\t\tSwitchService.Apply({})\n\t\treturn false\n\tend\n"),
    ("a failed read is silent", W, "\t\tUtil.Warn(TAG, \"read: \" .. tostring(doc))\n", ""),
    ("Halloween is not applied", W, "\tif key == \"Halloween\" and type(Config.Halloween) == \"table\" then", "\tif false then"),
    ("Halloween on forces it on", W, "Config.Halloween.Enabled = SwitchService.On(\"Halloween\") and ORIGINAL.Halloween == true", "Config.Halloween.Enabled = SwitchService.On(\"Halloween\")"),
    ("the original is forgotten", W, "\t\tif ORIGINAL.Halloween == nil then ORIGINAL.Halloween = Config.Halloween.Enabled end\n", "\t\tORIGINAL.Halloween = true\n"),
    ("the store ignores the environment (switches)", W, "\t\tlocal name = Config.StoreName and Config.StoreName(W.Store or \"HaloHorns_Switches_v1\") or (W.Store or \"HaloHorns_Switches_v1\")\n", "\t\tlocal name = W.Store or \"HaloHorns_Switches_v1\"\n"),
    ("Studio reads the real switches", W, "\t\tif RunService:IsStudio() then name ..= \"_STUDIO\" end\n\t\tlocal ok, st = pcall(DataStoreService.GetDataStore, DataStoreService, name)\n\t\tSTORE = ok and st or false", "\t\tlocal ok, st = pcall(DataStoreService.GetDataStore, DataStoreService, name)\n\t\tSTORE = ok and st or false"),
    ("the loop reads once", W, "\t\t\ttask.wait(math.max(10, num(W.Interval, 60)))\n", "\t\t\ttask.wait(1e9)\n"),
    ("the loop reads every second", W, "\t\t\ttask.wait(math.max(10, num(W.Interval, 60)))\n", "\t\t\ttask.wait(1)\n"),
    ("the defaults are not published at the start", W, "\tfor key, def in defs() do\n\t\tVALUES[key] = fallback(def)\n\t\tpublish(key)\n\tend\n", ""),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    main = read(SSS / "Main.server.luau")
    init = re.search(r"local INIT_ORDER = \{(.*?)\n\}", main, re.S)
    start = re.search(r"local START_ORDER = \{(.*?)\n\}", main, re.S)
    names = re.compile(r'"(\w+)"')
    init_list = names.findall(init.group(1)) if init else []
    start_list = names.findall(start.group(1)) if start else []
    for name in ("ServerErrorService", "SwitchService"):
        check(init_list.count(name) == 1 and start_list.count(name) == 1, f"{name} is in both lists once")
        check(start_list.index(name) < start_list.index("PlayerService") and start_list[-1] == "PlayerService", f"{name} starts before PlayerService")
        check((SSS / f"{name}.luau").is_file(), f"{name}.luau exists")
    check(sorted(init_list) == sorted(start_list), "every service is in both lists")
    # every DataStore name goes through the environment (Config.StoreName), whatever the store
    bare = []
    for path in sorted(SSS.glob("*.luau")):
        code = strip_comments(read(path))
        for m in re.finditer(r"(GetDataStore|GetOrderedDataStore)\s*[(,][^\n]*", code):
            line = m.group(0)
            if path.name == "RankingService.luau":
                continue  # its names are built from the season (EffectiveSeason carries the environment, checked below)
            if "StoreName" not in line and "name" not in line:
                bare.append(f"{path.name}: {line.strip()[:70]}")
    check(not bare, "every DataStore name goes through Config.StoreName: " + "; ".join(bare))
    for path in ("DataService", "NicknameService", "GrudgeService", "ReturnService", "MonetizationService", "ServerErrorService", "SwitchService"):
        check("Config.StoreName" in read(SSS / f"{path}.luau"), f"{path} uses Config.StoreName")
    ranking = read(SSS / "RankingService.luau")
    check("return Config.StoreName(R.Season)" in ranking, "the ranking season carries the environment")
    goose = read(SSS / "GooseService.luau")
    war = read(SSS / "WarService.luau")
    check("sw.On(\"Goose\")" in goose, "GooseService starts no new goose while the Goose switch is off")
    check(war.count("warOff()") >= 4 and "sw.On(\"CrownWar\")" in war, "WarService counts no points and ends no round while CrownWar is off")
    net = read(SHARED / "Net.luau")
    for key in ("SwitchPassSales", "SwitchHalloween", "SwitchCrownWar", "SwitchGoose"):
        check(net.count(key) == 1, f"GameState default {key}")
    for label, path in (("ServerErrorService", SSS / "ServerErrorService.luau"), ("SwitchService", SSS / "SwitchService.luau")):
        code = "\n".join(l.split("--", 1)[0] for l in read(path).splitlines())
        check(not re.search(r"[가-힣]", code), f"{label}: no Korean outside comments")
        check("MarketplaceService" not in code and "AddBankGold" not in code and "AddStat" not in code and "GrantItem" not in code, f"{label}: nothing sold, nothing paid")
    tel = strip_comments(read(SSS / "TelemetryService.luau"))
    check("ServerError" not in tel, "the 'ServerError' event name is used once (ServerErrorService), not by TelemetryService")
    return count, failures


SUITE = Suite(
    mark="OPSSAFETY",
    fixture=ROOT / "tools/fixtures/ops_safety_offline.luau",
    world=ROOT / "tools/fixtures/dev3_world.luau",
    out=ROOT / "docs/art/verification_2026-10-09/offline_dev3_ops_safety_2026-10-09.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="Environments: Config.EnvName() from the place id (Config.Env.Names; unknown = Dev), Config.StoreName(base): Dev "
             "keeps the name, Beta / Live append _Beta / _Live; DataService, Nickname, Grudge mail, the supporter list, the "
             "notification list and the ranking season use it. ServerErrorService: ScriptContext.Error and a Heartbeat over "
             "0.5 s (not in the first 30 s) -> ONE analytics event 'ServerError' (value 1 / ms, fields script / message / kind), "
             "at most 5 a minute, digit runs cleaned, no player = record only; the last 50 kept (a run of the same finding = "
             "one row with a count) and merged into a DataStore document every 120 s and at the close; Studio's own _STUDIO "
             "copy; DebugCommand('Errors'[, 'stored' | 'live']). SwitchService: one document read every 60 s, only the listed "
             "switches (PassSales, Halloween, CrownWar, Goose), values cut to type / range, a switch not set = its default, a "
             "failed read keeps the last answer, GameState Switch<Key>, Changed signal; Halloween follows Config.Halloween."
             "Enabled (never turns on a season the config has off), Goose starts no new goose, CrownWar counts no points and "
             "ends no round.",
    limitations="WarService / GooseService / the screen's [Buy] buttons are read through SwitchService.On: their hooks are "
                "checked as source (static), not run in this world. Real DataStore limits, ScriptContext and AnalyticsService "
                "are doubles; the analytics call is TelemetryService.Custom (pcall-wrapped). Moving old saves between "
                "environments is not done (Dev keeps the existing names) - see the ops doc.",
)

if __name__ == "__main__":
    run(SUITE)
