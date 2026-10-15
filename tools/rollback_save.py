"""Roll ONE player's save back to an older DataStore version (게시 준비 운영 ②, 게임성 개발 2, 2026-10-15).

  py tools/rollback_save.py <userId>                     list the record's versions (newest first) with level / gold / save
                                                         version of the newest few (read only)
  py tools/rollback_save.py <userId> --to <version>      dry run: back the current record up, show what would change
  py tools/rollback_save.py <userId> --to <version> --yes   back up, then put that version back as the newest record

Runs through tools/studio_mcp.py in a Studio of the game's place (API access on). The main game Studio needs
HH_MAIN_STUDIO=1 (메인 반영 1 / 최종 검수 only); STUDIO_NAME / STUDIO_ID pick another. The store is the one Config.StoreName
gives in that place (Dev / Beta / Live: the place decides, launch_ops_checklist), printed before anything is written.

Safety:
  * Edit mode only (checked before the read and again right before the write): never while anyone plays in that Studio.
  * The current record is written to docs/art/verification_2026-10-06/save_backups/<userId>_<time>_before_rollback.json and read
    back before the write; the write happens only while the record still has the backed-up version (UpdateAsync: a save that
    landed in between aborts it), never while a live server holds the player's session lock (the player is online: ask them to
    leave the game first), never for a version with a newer save format than Config.Data.Version (an older Studio).
  * The restored record has no SessionLock (an old version's lock would block the player for LockTimeout).
  * Nothing is deleted: the rolled-over record stays in the version history (this tool can roll forward to it again).
To undo by hand: run it again with --to <the version printed as 'before'>.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timedelta, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BACKUP_DIR = os.path.join(ROOT, "docs", "art", "verification_2026-10-06", "save_backups")
EDIT_MARK = "Current Studio Mode: Edit"
KST = timezone(timedelta(hours=9))

HEAD = r'''
if game:GetService("RunService"):IsRunning() then error("rollback_save: Edit mode only") end
local Http = game:GetService("HttpService")
local Config = require(game.ReplicatedStorage.Shared.Config:Clone())
local name = Config.StoreName(Config.Data.StoreName)
local store = game:GetService("DataStoreService"):GetDataStore(name)
local key = Config.Data.KeyPrefix .. "__UID__"
local function fresh()
	local opts = nil
	pcall(function() local o = Instance.new("DataStoreGetOptions"); o.UseCache = false; opts = o end)
	return store:GetAsync(key, opts)
end
'''

LIST = HEAD + r'''
local out = { store = name, key = key, versions = {} }
local pages = store:ListVersionsAsync(key, Enum.SortDirection.Descending, nil, nil, __LIMIT__)
for i, v in pages:GetCurrentPage() do
	local row = { version = v.Version, created = v.CreatedTime, deleted = v.IsDeleted }
	if not v.IsDeleted and i <= __PEEK__ then
		local ok, value = pcall(function() return store:GetVersionAsync(key, v.Version) end)
		if ok and type(value) == "table" then
			row.level, row.gold, row.saveVersion, row.playtime = value.Level, value.Gold, value.Version, value.PlaytimeSeconds
		end
	end
	table.insert(out.versions, row)
end
return Http:JSONEncode(out)
'''

READ = HEAD + r'''
local value, info = fresh()
local out = { store = name, key = key, exists = value ~= nil, value = value }
if info then
	out.version = info.Version
	local okU, uids = pcall(function() return info:GetUserIds() end)
	if okU then out.userIds = uids end
end
local okT, old = pcall(function() return store:GetVersionAsync(key, "__TARGET__") end)
out.targetFound = okT and type(old) == "table"
if out.targetFound then
	out.target = { level = old.Level, gold = old.Gold, saveVersion = old.Version, playtime = old.PlaytimeSeconds }
end
return Http:JSONEncode(out)
'''

RESTORE = HEAD + r'''
local function say(t) return Http:JSONEncode(t) end
local expected = "__CURRENT__" -- the version that was backed up ("" = there was no record)
local okT, old = pcall(function() return store:GetVersionAsync(key, "__TARGET__") end)
if not okT or type(old) ~= "table" then return say({ restored = false, reason = "that version has no record" }) end
if (tonumber(old.Version) or 0) > (tonumber(Config.Data.Version) or 0) then
	return say({ restored = false, reason = "that version has a newer save format than this Studio's Config.Data.Version" })
end
old.SessionLock = nil -- an old lock would keep the player out for LockTimeout
local cur, info = fresh()
if ((info and info.Version) or "") ~= expected then
	return say({ restored = false, reason = "the record changed after the backup", version = info and info.Version or "" })
end
local lock = type(cur) == "table" and cur.SessionLock or nil
if type(lock) == "table" and type(lock.JobId) == "string" and lock.JobId ~= "" and lock.Studio ~= true
	and os.time() - (tonumber(lock.Time) or 0) < (tonumber(Config.Data.LockTimeout) or 0) then
	return say({ restored = false, reason = "the player is on a live server now (ask them to leave the game first)" })
end
local userIds = { tonumber("__UID__") }
if info then
	local okU, uids = pcall(function() return info:GetUserIds() end)
	if okU and type(uids) == "table" and #uids > 0 then userIds = uids end
end
local wrote = false
local okW, err = pcall(function()
	store:UpdateAsync(key, function(_, nowInfo)
		if ((nowInfo and nowInfo.Version) or "") ~= expected then return nil end -- a save landed in between: abort
		wrote = true
		return old, userIds
	end)
end)
if not okW then return say({ restored = false, reason = "write failed: " .. tostring(err) }) end
if not wrote then return say({ restored = false, reason = "the record changed during the write" }) end
local now, nowInfo = fresh()
local same = type(now) == "table" and Http:JSONEncode(now) == Http:JSONEncode(old)
return say({ restored = same, reason = (not same) and "read-back differs" or nil, version = nowInfo and nowInfo.Version or "" })
'''


def fill(code: str, **values) -> str:
    for k, v in values.items():
        code = code.replace(f"__{k}__", str(v))
    return code


def list_lua(uid: int, limit: int = 20, peek: int = 8) -> str:
    return fill(LIST, UID=uid, LIMIT=max(1, min(100, limit)), PEEK=max(0, peek))


def read_lua(uid: int, target: str) -> str:
    return fill(READ, UID=uid, TARGET=target)


def restore_lua(uid: int, target: str, current: str) -> str:
    return fill(RESTORE, UID=uid, TARGET=target, CURRENT=current)


def text_of(res: dict) -> str:
    return "".join(p.get("text", "") for p in res.get("content", []))


def parse_json(raw: str) -> dict:
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        if "{" in raw and "}" in raw:
            return json.loads(raw[raw.index("{"):raw.rindex("}") + 1])
        raise


def require_edit(client, when: str) -> None:
    state = text_of(client.call("get_studio_state", {}))
    if EDIT_MARK not in state:
        raise SystemExit(f"refused ({when}): Studio is not in Edit mode (someone may be playing). Nothing was changed. "
                         f"Studio state: {state.strip()[:200]}")


def run_luau(client, code: str) -> dict:
    return parse_json(text_of(client.call("execute_luau", {"code": code, "datamodel_type": "Edit"})))


def stamp(ms) -> str:
    try:
        return datetime.fromtimestamp(int(ms) / 1000, KST).strftime("%m-%d %H:%M:%S")
    except (TypeError, ValueError, OSError):
        return "?"


def run(client, uid: int, target: str | None, yes: bool, limit: int, backup_dir: str = BACKUP_DIR) -> int:
    require_edit(client, "before reading")
    if not target:
        out = run_luau(client, list_lua(uid, limit))
        print(f"store {out.get('store')} key {out.get('key')}: {len(out.get('versions') or [])} versions (newest first)")
        for v in out.get("versions") or []:
            extra = "" if v.get("level") is None else \
                f"  Lv{v.get('level')} gold {v.get('gold')} save v{v.get('saveVersion')} play {v.get('playtime')}s"
            print(f"  {v.get('version')}  {stamp(v.get('created'))} KST{'  (deleted)' if v.get('deleted') else ''}{extra}")
        return 0
    cur = run_luau(client, read_lua(uid, target))
    if not cur.get("targetFound"):
        print(f"refused: version {target} has no record (deleted or not this key). Nothing was changed.")
        return 1
    os.makedirs(backup_dir, exist_ok=True)
    when = datetime.now(KST).strftime("%Y%m%d_%H%M%S")
    path = os.path.join(backup_dir, f"{uid}_{when}_before_rollback.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(cur, f, ensure_ascii=False, indent=1)
    with open(path, encoding="utf-8") as f:
        if json.load(f).get("version") != cur.get("version"):
            print("refused: the backup did not read back. Nothing was changed.")
            return 1
    before = cur.get("version") or ""
    print(f"store {cur.get('store')} key {cur.get('key')}")
    print(f"backup: {path}")
    print(f"before: version {before or '(no record)'}  "
          f"Lv{(cur.get('value') or {}).get('Level')} gold {(cur.get('value') or {}).get('Gold')}")
    t = cur.get("target") or {}
    print(f"to:     version {target}  Lv{t.get('level')} gold {t.get('gold')} save v{t.get('saveVersion')}")
    if not yes:
        print("dry run: add --yes to write it (the player must be out of the game).")
        return 0
    require_edit(client, "right before the write")
    res = run_luau(client, restore_lua(uid, target, before))
    if res.get("restored"):
        print(f"restored: the record is version {target}'s data again (new version {res.get('version')}). "
              f"Undo: --to {before}")
        return 0
    print(f"not restored: {res.get('reason')}. The backup stays at {path}.")
    return 1


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("userId", type=int)
    ap.add_argument("--to", dest="target")
    ap.add_argument("--yes", action="store_true")
    ap.add_argument("--limit", type=int, default=20)
    a = ap.parse_args()
    if a.userId <= 0:
        print("a userId is a positive number")
        return 2
    if not (os.environ.get("HH_MAIN_STUDIO") or os.environ.get("STUDIO_NAME") or os.environ.get("STUDIO_ID")):
        print("Studio 창을 정하세요: 게임 Studio = HH_MAIN_STUDIO=1 (메인 반영 1 / 최종 검수만)", file=sys.stderr)
        return 2
    sys.path.insert(0, HERE)
    from studio_mcp import Client  # noqa: E402
    client = Client()
    try:
        client.start()
        return run(client, a.userId, a.target, a.yes, a.limit)
    finally:
        client.close()


if __name__ == "__main__":
    raise SystemExit(main())
