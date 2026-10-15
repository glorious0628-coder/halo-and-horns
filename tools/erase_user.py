"""Erase ONE Roblox user's data from every store of the game (BB40 / 게시 준비 운영 ⑤, 게임성 개발 2, 2026-10-15).

When Roblox sends a "Right to Erasure" request (a message with the userId), the user runs:

  py tools/erase_user.py <userId>                 plan only: what would be deleted / scrubbed (reads, never writes)
  py tools/erase_user.py <userId> --yes           do it (prints every change; an erasure can not be undone)
  options: --env Dev,Beta,Live (default all three) --scan-saves (also scrub the id out of OTHER players' saves: PairCD /
           Market pair counters / weekly PvP victims; slow: reads every save) --weeks FROM:TO (ranking weeks; default
           the week of 2026-10-01 .. this week) --universe ID (default GAME_ID)

Open Cloud key: ROBLOX_OPENCLOUD_KEY (or OPEN_CLOUD_KEY) in the git-ignored .env, never printed; it needs the DataStore
(read / write / list / delete, ordered too) and Memory Store permissions of the universe. Store map (inventory 10/15, every
name with its environment suffix: Dev = base, Beta = base_Beta, Live = base_Live; Dev also base_STUDIO where a service adds it):
  HaloHorns_Player_v1        P_<uid>                 delete
  HaloHorns_NotifyAsked_v1   <uid>                   delete
  HaloHorns_GrudgeMail_v1    M_<uid>                 delete; every other M_* letter whose Id starts "<uid>:" removed
  HaloHorns_Nicknames_v1     U_<uid> + N_* claims    delete U_<uid>; every N_* claim with UserId = uid deleted
  HaloHorns_Supporters_v1    List                    entries with U = uid removed
  HaloHorns_Market_v1        L_<guid> rows           Buyer = uid -> 0; Seller = uid on a finished row (Paid / Cancel /
                                                     Expired) -> 0; an Open / Sold-unpaid row of theirs is reported
                                                     (run again after it expires) - nothing else in it names them
  HHMktSold (memory)         <uid>                   deleted (the HHMkt_* listings expire by themselves within 73 h)
  HH_Rank_<season>_<board>_W<week> (ordered)  U_<uid>     deleted in every season x board x week
  HH_RankSettle_<season>     W<week>                 uid removed from Boards[b] with its Ranks[b] entry
  (--scan-saves) HaloHorns_Player_v1 P_*            PairCD "<kind>:<uid>", Market["P<uid>"], Rank.Victims["U<uid>"]
Nothing else stores a userId (Health / Errors / Switches / TestMetrics / VillageFund / News: sums, no ids). Every write uses
the entry's version (matchVersion): a store changed in between is skipped and reported (run again).
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
GAME_ID = 10769445522
ENVS = {"Dev": "", "Beta": "_Beta", "Live": "_Live"}
BOARDS = ["Honor", "Infamy", "Artisan", "PvP"]  # Config.Ranking.Order
SEASONS = ["PRE"]  # Config.Ranking.Season + SeasonHistory (add "B1" when the beta season starts)
STUDIO_TOO = {"HaloHorns_Supporters_v1"}  # MonetizationService adds _STUDIO in Studio
FIRST_WEEK_TIME = 1759276800  # 2026-10-01 00:00 UTC
FINISHED = {"Paid", "Cancel", "Expired"}
BASE = "https://apis.roblox.com"


def week_index(t: float) -> int:  # Config.WeekIndex (Monday 00:00 KST)
    return int((t + 9 * 3600 + 3 * 86400) // 604800)


class Cloud:
    """the Open Cloud calls this tool makes (a test passes a double with the same methods)"""

    def __init__(self, universe: int, key: str):
        self.u, self.key = universe, key

    def _call(self, method: str, url: str, body: bytes | None = None, headers: dict | None = None):
        h = {"x-api-key": self.key}
        h.update(headers or {})
        req = urllib.request.Request(url, data=body, headers=h, method=method)
        for attempt in range(4):
            try:
                with urllib.request.urlopen(req, timeout=60) as r:
                    return r.status, r.read(), dict(r.headers)
            except urllib.error.HTTPError as e:
                if e.code == 429 and attempt < 3:
                    time.sleep(2 + attempt * 3)
                    continue
                return e.code, e.read(), dict(e.headers or {})
        return 429, b"", {}

    def _std(self, path: str, **q) -> str:
        return f"{BASE}/datastores/v1/universes/{self.u}/standard-datastores{path}?" + urllib.parse.urlencode(q)

    def list_keys(self, store: str, prefix: str = "") -> list[str]:
        keys, cursor = [], ""
        while True:
            q = {"datastoreName": store, "limit": 100}
            if prefix:
                q["prefix"] = prefix
            if cursor:
                q["cursor"] = cursor
            code, body, _ = self._call("GET", self._std("/datastore/entries", **q))
            if code == 404:
                return keys
            if code != 200:
                raise RuntimeError(f"list {store}: HTTP {code} {body[:200]!r}")
            data = json.loads(body or b"{}")
            keys += [k.get("key") for k in data.get("keys") or [] if k.get("key")]
            cursor = data.get("nextPageCursor") or ""
            if not cursor:
                return keys

    def get(self, store: str, key: str):
        code, body, headers = self._call("GET", self._std("/datastore/entries/entry", datastoreName=store, entryKey=key))
        if code in (204, 404):
            return None, None
        if code != 200:
            raise RuntimeError(f"get {store}/{key}: HTTP {code}")
        version = {k.lower(): v for k, v in headers.items()}.get("roblox-entry-version")
        return json.loads(body), version

    def set(self, store: str, key: str, value, version: str | None) -> bool:
        body = json.dumps(value, separators=(",", ":")).encode()
        q = {"datastoreName": store, "entryKey": key}
        if version:
            q["matchVersion"] = version
        md5 = base64.b64encode(hashlib.md5(body).digest()).decode()
        code, _, _ = self._call("POST", self._std("/datastore/entries/entry", **q), body,
                                {"content-md5": md5, "content-type": "application/json"})
        return code == 200

    def delete(self, store: str, key: str) -> bool:
        code, _, _ = self._call("DELETE", self._std("/datastore/entries/entry", datastoreName=store, entryKey=key))
        return code in (200, 204, 404)

    def ordered_delete(self, store: str, key: str) -> bool:
        url = (f"{BASE}/ordered-data-stores/v1/universes/{self.u}/orderedDataStores/{urllib.parse.quote(store)}"
               f"/scopes/global/entries/{urllib.parse.quote(key)}")
        code, _, _ = self._call("DELETE", url)
        return code in (200, 204, 404)

    def memory_delete(self, sorted_map: str, key: str) -> bool:
        url = (f"{BASE}/cloud/v2/universes/{self.u}/memory-store/sorted-maps/{urllib.parse.quote(sorted_map)}"
               f"/items/{urllib.parse.quote(key)}")
        code, _, _ = self._call("DELETE", url)
        return code in (200, 204, 404)


def scrub_save(value, uid: int) -> bool:
    """removes uid from another player's save in place: PairCD "<kind>:<uid>", Market["P<uid>"], Rank.Victims["U<uid>"]"""
    if not isinstance(value, dict):
        return False
    changed = False
    pcd = value.get("PairCD")
    if isinstance(pcd, dict):
        for k in [k for k in pcd if str(k).endswith(f":{uid}")]:
            del pcd[k]
            changed = True
    m = value.get("Market")
    if isinstance(m, dict) and f"P{uid}" in m:
        del m[f"P{uid}"]
        changed = True
    vic = (value.get("Rank") or {}).get("Victims") if isinstance(value.get("Rank"), dict) else None
    if isinstance(vic, dict) and f"U{uid}" in vic:
        del vic[f"U{uid}"]
        changed = True
    return changed


def erase(cloud, uid: int, envs: list[str], weeks: range, yes: bool, scan_saves: bool, out=print) -> dict:
    """plans (yes = False) or does (yes = True) the erasure; returns counts. Every line names store / key / action"""
    stats = {"delete": 0, "scrub": 0, "skipped": 0, "deferred": 0}

    def act(kind: str, store: str, key: str, fn) -> None:
        if not yes:
            out(f"  would {kind:<7} {store} / {key}")
            stats[kind] += 1
            return
        ok = fn()
        stats[kind if ok else "skipped"] += 1
        out(f"  {kind if ok else 'SKIPPED':<7} {store} / {key}" + ("" if ok else "  (changed in between or refused: run again)"))

    def remove_key(store: str, key: str) -> None:
        if cloud.get(store, key)[0] is not None:
            act("delete", store, key, lambda: cloud.delete(store, key))

    def rewrite(store: str, key: str, edit) -> None:
        value, version = cloud.get(store, key)
        if value is None:
            return
        if edit(value):
            act("scrub", store, key, lambda: cloud.set(store, key, value, version))

    for env in envs:
        sfx = ENVS[env]
        out(f"[{env}]")
        remove_key("HaloHorns_Player_v1" + sfx, f"P_{uid}")
        remove_key("HaloHorns_NotifyAsked_v1" + sfx, str(uid))
        mail = "HaloHorns_GrudgeMail_v1" + sfx
        remove_key(mail, f"M_{uid}")
        for key in cloud.list_keys(mail, "M_"):
            if key == f"M_{uid}":
                continue

            def drop_letters(v):
                if not isinstance(v, list):
                    return False
                keep = [e for e in v if not (isinstance(e, dict) and str(e.get("Id", "")).startswith(f"{uid}:"))]
                if len(keep) == len(v):
                    return False
                v[:] = keep
                return True
            rewrite(mail, key, drop_letters)
        nick = "HaloHorns_Nicknames_v1" + sfx
        remove_key(nick, f"U_{uid}")
        for key in cloud.list_keys(nick, "N_"):
            value, _ = cloud.get(nick, key)
            if isinstance(value, dict) and value.get("UserId") == uid:
                act("delete", nick, key, lambda k=key: cloud.delete(nick, k))
        for store in ["HaloHorns_Supporters_v1" + sfx] + (["HaloHorns_Supporters_v1_STUDIO"] if env == "Dev" else []):
            def drop_supporter(v):
                if not isinstance(v, list):
                    return False
                keep = [e for e in v if not (isinstance(e, dict) and e.get("U") == uid)]
                if len(keep) == len(v):
                    return False
                v[:] = keep
                return True
            rewrite(store, "List", drop_supporter)
        market = "HaloHorns_Market_v1" + sfx
        for key in cloud.list_keys(market, "L_"):
            value, version = cloud.get(market, key)
            if not isinstance(value, dict):
                continue
            changed = False
            if value.get("Buyer") == uid:
                value["Buyer"] = 0
                changed = True
            if value.get("Seller") == uid:
                if value.get("St") in FINISHED:
                    value["Seller"] = 0
                    changed = True
                else:
                    stats["deferred"] += 1
                    out(f"  DEFERRED {market} / {key}  (their {value.get('St')} row: run again after it ends)")
            if changed:
                act("scrub", market, key, lambda k=key, v=value, ver=version: cloud.set(market, k, v, ver))
        act("delete", "HHMktSold" + sfx + " (memory)", str(uid), lambda: cloud.memory_delete("HHMktSold" + sfx, str(uid)))
        seasons = [s + sfx for s in SEASONS] + (["STUDIO"] if env == "Dev" else [])
        for season in seasons:
            for board in BOARDS:
                for w in weeks:
                    store = f"HH_Rank_{season}_{board}_W{w}"
                    if yes:
                        act("delete", store + " (ordered)", f"U_{uid}", lambda s=store: cloud.ordered_delete(s, f"U_{uid}"))
            if not yes:
                out(f"  would delete HH_Rank_{season}_<{'/'.join(BOARDS)}>_W{weeks.start}..W{weeks.stop - 1} (ordered) / U_{uid}")
                stats["delete"] += 1
            settle = f"HH_RankSettle_{season}"
            for key in cloud.list_keys(settle, "W"):
                def drop_rank(v):
                    if not isinstance(v, dict) or not isinstance(v.get("Boards"), dict):
                        return False
                    hit = False
                    for b, ids in v["Boards"].items():
                        if isinstance(ids, list) and uid in ids:
                            i = ids.index(uid)
                            ids.pop(i)
                            ranks = (v.get("Ranks") or {}).get(b)
                            if isinstance(ranks, list) and i < len(ranks):
                                ranks.pop(i)
                            hit = True
                    return hit
                rewrite(settle, key, drop_rank)
        if scan_saves:
            saves = "HaloHorns_Player_v1" + sfx
            for key in cloud.list_keys(saves, "P_"):
                if key != f"P_{uid}":
                    rewrite(saves, key, lambda v: scrub_save(v, uid))
    return stats


def env_key() -> str:
    path = os.path.join(ROOT, ".env")
    if os.path.isfile(path):
        with open(path, encoding="utf-8") as f:
            for line in f:
                for name in ("ROBLOX_OPENCLOUD_KEY=", "OPEN_CLOUD_KEY="):
                    if line.startswith(name) and line.strip() != name.strip():
                        return line.split("=", 1)[1].strip()
    sys.exit("no ROBLOX_OPENCLOUD_KEY in .env (Creator Hub > Open Cloud > API Keys; DataStore + Memory Store permissions)")


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("userId", type=int)
    ap.add_argument("--yes", action="store_true")
    ap.add_argument("--env", default="Dev,Beta,Live")
    ap.add_argument("--scan-saves", action="store_true")
    ap.add_argument("--weeks")
    ap.add_argument("--universe", type=int, default=GAME_ID)
    a = ap.parse_args()
    envs = [e.strip() for e in a.env.split(",") if e.strip()]
    if a.userId <= 0 or any(e not in ENVS for e in envs):
        print("a positive userId; --env from Dev, Beta, Live")
        return 2
    if a.weeks:
        lo, hi = (int(x) for x in a.weeks.split(":"))
    else:
        lo, hi = week_index(FIRST_WEEK_TIME), week_index(time.time())
    cloud = Cloud(a.universe, env_key())
    print(f"user {a.userId}, universe {a.universe}, {', '.join(envs)}, weeks W{lo}..W{hi}, "
          f"{'ERASING' if a.yes else 'plan only (add --yes to erase)'}")
    stats = erase(cloud, a.userId, envs, range(lo, hi + 1), a.yes, a.scan_saves)
    print(f"done: {stats}")
    if not a.yes:
        print("nothing was changed.")
    return 0 if stats["skipped"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
