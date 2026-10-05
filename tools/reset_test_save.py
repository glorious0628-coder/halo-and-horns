"""Reset ONE allow-listed test account's player save in the private test place, for fresh first-session tests.

  py tools/reset_test_save.py <userId>

Safety (reviewer item 8, 2026-10-06):
  * Only userIds in TEST_ACCOUNTS can be reset; any other id is refused before Studio is contacted.
  * Refuses unless Studio's get_studio_state says "Current Studio Mode: Edit" (checked before the read and
    again right before the removal), so it can never run while anyone plays. It never stops Play itself.
  * Reads the record first and writes a JSON backup to
    docs/art/verification_2026-10-06/save_backups/<userId>_<timestamp>.json. RemoveAsync runs only after that
    file is written and read back, and only while the record still has the backed-up version.
Only Config.Data (player progress) of that userId is removed; nicknames and other stores are untouched.
To restore by hand (Edit mode): store:SetAsync(key, backup.value, backup.userIds, backup.metadata).
"""
import json, os, re, sys
from datetime import datetime, timedelta, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from studio_mcp import Client

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BACKUP_DIR = os.path.join(ROOT, "docs", "art", "verification_2026-10-06", "save_backups")
# userId -> account name. Add an id here only for a test account the user named in chat.
TEST_ACCOUNTS = {11753301316: "Darugi_S2"}
EDIT_MARK = "Current Studio Mode: Edit"
KST = timezone(timedelta(hours=9))

LUA_HEAD = r'''
if game:GetService("RunService"):IsRunning() then error("reset_test_save: Edit mode only") end
local Http = game:GetService("HttpService")
local Config = require(game.ReplicatedStorage.Shared.Config:Clone())
local store = game:GetService("DataStoreService"):GetDataStore(Config.Data.StoreName)
local key = Config.Data.KeyPrefix .. "__UID__"
local opts = nil
pcall(function() local o = Instance.new("DataStoreGetOptions"); o.UseCache = false; opts = o end)
local value, info = store:GetAsync(key, opts)
'''

READ_LUA = LUA_HEAD + r'''
local out = { store = Config.Data.StoreName, key = key, exists = value ~= nil, value = value }
if info then
	out.version, out.createdTime, out.updatedTime = info.Version, info.CreatedTime, info.UpdatedTime
	local okU, uids = pcall(function() return info:GetUserIds() end)
	if okU then out.userIds = uids end
	local okM, meta = pcall(function() return info:GetMetadata() end)
	if okM then out.metadata = meta end
end
return Http:JSONEncode(out)
'''

REMOVE_LUA = LUA_HEAD + r'''
local expected = "__VERSION__"
if value == nil then return Http:JSONEncode({ removed = false, reason = "no record any more" }) end
local current = info and info.Version or nil
if current ~= expected then
	return Http:JSONEncode({ removed = false, reason = "record changed after the backup", version = current })
end
local old = store:RemoveAsync(key)
return Http:JSONEncode({ removed = true, key = key, removedValue = old })
'''


def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))


def parse_json(raw):
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        if "{" in raw and "}" in raw:
            return json.loads(raw[raw.index("{"):raw.rindex("}") + 1])
        raise


def require_edit(client, when):
    state = text_of(client.call("get_studio_state", {}))
    if EDIT_MARK not in state:
        sys.exit(f"refused ({when}): Studio is not in Edit mode (someone may be playing). "
                 f"Nothing was changed. Studio state: {state.strip()[:200]}")


def run_luau(client, code, what):
    res = client.call("execute_luau", {"code": code, "datamodel_type": "Edit"})
    raw = text_of(res)
    if res.get("isError"):
        sys.exit(f"{what} failed in Studio; nothing removed: {raw[:300]}")
    return parse_json(raw)


def write_backup(uid, record):
    os.makedirs(BACKUP_DIR, exist_ok=True)
    stamp = datetime.now(KST).strftime("%Y%m%d-%H%M%S")
    for n in range(100):
        path = os.path.join(BACKUP_DIR, f"{uid}_{stamp}{'' if n == 0 else f'_{n}'}.json")
        try:
            with open(path, "x", encoding="utf-8") as fh:  # never overwrite an earlier backup
                json.dump(record, fh, ensure_ascii=False, indent=1)
                fh.write("\n")
            break
        except FileExistsError:
            continue
    else:
        sys.exit("could not pick a new backup file name; nothing removed")
    with open(path, encoding="utf-8") as fh:
        back = json.load(fh)
    if back.get("value") != record.get("value") or back.get("version") != record.get("version"):
        sys.exit(f"backup read-back mismatch ({path}); nothing removed")
    return path


def main(argv=None, client_factory=Client):
    sys.stdout.reconfigure(encoding="utf-8")
    args = sys.argv[1:] if argv is None else argv
    if len(args) != 1 or not re.fullmatch(r"[1-9][0-9]{0,15}", args[0]):
        sys.exit(__doc__)
    uid = int(args[0])
    if uid not in TEST_ACCOUNTS:
        sys.exit(f"refused: userId {uid} is not an allow-listed test account {sorted(TEST_ACCOUNTS)}; nothing changed")
    account = TEST_ACCOUNTS[uid]

    client = client_factory()
    try:
        client.start()
        require_edit(client, "before reading")
        got = run_luau(client, READ_LUA.replace("__UID__", str(uid)), "reading the save")
        if not got.get("exists"):
            print(f"{account} ({uid}): no save under {got.get('key')}; nothing to back up or remove")
            return 0
        version = got.get("version")
        if not isinstance(version, str) or not re.fullmatch(r"[A-Za-z0-9._:+/=-]{1,128}", version):
            sys.exit(f"refused: record version unavailable or unexpected ({version!r}); cannot guard the removal")
        record = {
            "tool": "tools/reset_test_save.py",
            "kind": "player save backup taken before RemoveAsync",
            "userId": uid, "account": account,
            "taken_at_kst": datetime.now(KST).isoformat(timespec="seconds"),
            "studio_mode": "Edit",
            "store": got.get("store"), "key": got.get("key"),
            "version": version, "createdTime": got.get("createdTime"), "updatedTime": got.get("updatedTime"),
            "userIds": got.get("userIds"), "metadata": got.get("metadata"),
            "value": got.get("value"),
        }
        path = write_backup(uid, record)
        print(f"backup written: {os.path.relpath(path, ROOT)}")

        require_edit(client, "before removing")
        res = run_luau(client, REMOVE_LUA.replace("__UID__", str(uid)).replace("__VERSION__", version), "removing the save")
        if not res.get("removed"):
            sys.exit(f"not removed: {res.get('reason')} (backup kept at {os.path.relpath(path, ROOT)})")
        if res.get("removedValue") != record["value"]:
            extra = path[:-5] + "_removed.json"
            with open(extra, "x", encoding="utf-8") as fh:
                json.dump(dict(record, kind="value actually removed (differed from the backup)",
                               value=res.get("removedValue")), fh, ensure_ascii=False, indent=1)
                fh.write("\n")
            print(f"WARNING: removed value differed from the backup; it was saved to {os.path.relpath(extra, ROOT)}")
        print(f"removed {res.get('key')} for {account} ({uid})")
        return 0
    finally:
        client.close()


if __name__ == "__main__":
    raise SystemExit(main())
