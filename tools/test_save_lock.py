"""DataService save-lock retries + the StudioFreshSave guard, offline (A23-48 batch, 검수 2026-10-06).

Runs the CURRENT DataService, Config and Util on tools/fixtures/dev2_kit.luau (DataStore double) with
tools/fixtures/save_lock_offline.luau and the installed official Luau CLI. task.wait yields a coroutine and the driver
advances the clocks, so the 6 s retries cost no real time. No Studio, network, DataStore or Roblox API calls; mutations
run on in-memory copies of the sources only.

Usage: py tools/test_save_lock.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/offline_dev2_save_lock_2026-10-06.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "DATA_SOURCE": SSS / "DataService.luau",
}
C, D = "CONFIG_SOURCE", "DATA_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    ("retry delay back to 3 s", C, "\tLoadRetryDelay = 6,\n", "\tLoadRetryDelay = 3,\n"),
    ("the waiting text is missing", C, '\tSaveLoading = "Loading your save…",', '\tSaveLoadingX = "Loading your save…",'),
    ("no notice while waiting", D, 'require(ReplicatedStorage.Shared.Net).Notify(player, Config.Text.SaveLoading, "info")',
     "local _ = player"),
    ("the mark is never set", D, '\t\t\t\tplayer:SetAttribute("SaveLoading", true)\n', ""),
    ("the notice repeats every try", D, '\t\t\tif player:GetAttribute("SaveLoading") ~= true then\n',
     "\t\t\tif true then\n"),
    ("the mark is never cleared", D,
     '\tif player:GetAttribute("SaveLoading") ~= nil then player:SetAttribute("SaveLoading", nil) end -- the wait is over\n', ""),
    ("Studio locks block live servers", D,
     '\tif (lock.JobId == "" or lock.Studio == true) and not RunService:IsStudio() then return false end\n', ""),
    ("the Studio mark is ignored", D, '(lock.JobId == "" or lock.Studio == true) and not', '(lock.JobId == "") and not'),
    ("the lock forgets the Studio mark", D, "Studio = RunService:IsStudio() or nil }", "Studio = nil }"),
    ("no wait between the tries", D, "\t\t\ttask.wait(Config.Data.LoadRetryDelay)\n", "\t\t\ttask.wait(0)\n"),
    ("the last try never takes the lock", D, "local final = (attempt == retries)", "local final = false"),
    ("old locks still block", D, "\treturn os.time() - t < Config.Data.LockTimeout\n", "\treturn true\n"),
    ("StudioFreshSave read on a live server", D, "\t\tif RunService:IsStudio() then\n", "\t\tif true then\n"),
    ("StudioFreshSave ignored in Studio", D,
     'return game:GetService("ServerStorage"):GetAttribute("StudioFreshSave") == true', "return false"),
    ("the player leaving is not noticed", D, "\t\tif player.Parent == nil then\n\t\t\treturn nil\n\t\tend\n\t\tlocal final",
     "\t\tlocal final"),
    # review 2026-10-06 evening: the SessionToken alone must stop a stopped session once the record has no lock
    ("token guard removed", D, 'if type(old) ~= "table" or old.SessionToken ~= sessionToken then',
     'if type(old) ~= "table" then'),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    data = read(SSS / "DataService.luau")
    load = function_block(data, "local function loadLocked(")
    check(load.count("newLock()") == 1 and function_block(data, "local function writeRecord(").count("newLock()") == 1,
          "every lock DataService writes comes from newLock() (load + save)")
    check("SessionLock = {" not in data, "no hand-built lock tables left")
    check("local Net = require" not in data, "Net is required only on the waiting path (offline harnesses load DataService alone)")
    player = read(SSS / "PlayerService.luau")
    check("S.DataService.Load, player" in player and "Config.Text.LoadFailed" in player,
          "PlayerService still loads through DataService.Load and kicks with Config.Text.LoadFailed")
    return count, failures


SUITE = Suite(
    mark="SAVE_LOCK",
    fixture=ROOT / "tools/fixtures/save_lock_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-06/offline_dev2_save_lock_2026-10-06.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="DataService loads retry every Config.Data.LoadRetryDelay = 6 s, LoadRetries = 5 tries; the 5th takes a live "
             "lock (~24 s). The first retry wait sets the player attribute SaveLoading = true and sends one Notify "
             "Config.Text.SaveLoading ('Loading your save…', kind info); DataService.Load clears the attribute (nil) on "
             "every outcome. Locks carry Studio = true when written by Studio; a lock with JobId '' or Studio = true is "
             "never live for a non-Studio server (no wait), while Studio still waits for live locks. StudioFreshSave "
             "(ServerStorage attribute) is read only when RunService:IsStudio(): a live server never reads it and never "
             "enters memory mode because of it.",
    limitations="DataStore double (no real latency, throttling or UpdateAsync conflicts beyond the scripted ones); "
                "Studio's real JobId and the live Studio Play / publish flow are not exercised here.",
)

if __name__ == "__main__":
    run(SUITE)
