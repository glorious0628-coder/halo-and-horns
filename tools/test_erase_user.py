"""tools/erase_user.py offline (BB40 / 게시 준비 운영 ⑤, 게임성 개발 2, 2026-10-15).

Runs erase() against an in-memory Open Cloud double (standard stores with versions, ordered stores, memory sorted maps) filled
like a real Live universe for user 42 and others: the plan changes nothing; --yes deletes 42's own keys, scrubs 42 out of
shared rows (mail letter ids, nickname claims, supporters, market Buyer / finished Seller, settle boards with their ranks),
leaves other users and an open listing of 42's alone (deferred), never writes over a store that changed in between
(matchVersion), stays inside the environments asked for. Then each mutation of the tool must be caught. No network.

Usage: py tools/test_erase_user.py [--no-mutations]
"""
from __future__ import annotations

import copy
import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools/erase_user.py"
UID = 42
CONFIG_TEXT = (ROOT / "src/ReplicatedStorage/Shared/Config.luau").read_text(encoding="utf-8-sig")


class FakeCloud:
    def __init__(self, std: dict, ordered: dict, memory: dict, race: set | None = None):
        self.std = std  # store -> key -> [value, version]
        self.ordered = ordered  # store -> {key: score}
        self.memory = memory  # map -> {key: value}
        self.race = race or set()  # (store, key): a game write lands between our get and set
        self.writes: list[tuple] = []

    def list_keys(self, store, prefix=""):
        return sorted(k for k in self.std.get(store, {}) if k.startswith(prefix))

    def get(self, store, key):
        row = self.std.get(store, {}).get(key)
        return (copy.deepcopy(row[0]), row[1]) if row else (None, None)

    def set(self, store, key, value, version):
        if (store, key) in self.race:
            self.race.discard((store, key))
            self.std[store][key] = [self.std[store][key][0], self.std[store][key][1] + "x"]
        row = self.std.setdefault(store, {}).get(key)
        if version is not None and (row is None or row[1] != version):
            return False
        self.std[store][key] = [copy.deepcopy(value), (row[1] if row else "v") + "+"]
        self.writes.append(("set", store, key))
        return True

    def delete(self, store, key):
        self.writes.append(("delete", store, key))
        self.std.get(store, {}).pop(key, None)
        return True

    def ordered_delete(self, store, key):
        self.writes.append(("odelete", store, key))
        self.ordered.get(store, {}).pop(key, None)
        return True

    def memory_delete(self, m, key):
        self.writes.append(("mdelete", m, key))
        self.memory.get(m, {}).pop(key, None)
        return True


def world(sfx="_Live"):
    s = lambda d: {k: [v, "v1"] for k, v in d.items()}  # noqa: E731
    std = {
        "HaloHorns_Player_v1" + sfx: s({
            "P_42": {"Level": 9},
            "P_7": {"Level": 3, "PairCD": {"steal:42": 100, "steal:9": 50}, "Market": {"P42": 2, "P9": 1},
                    "Rank": {"Victims": {"U42": 1, "U9": 1}}},
        }),
        "HaloHorns_NotifyAsked_v1" + sfx: s({"42": {"At": 1}, "7": {"At": 2}}),
        "HaloHorns_GrudgeMail_v1" + sfx: s({"M_42": [{"Id": "7:1:Avenged"}],
                                             "M_7": [{"Id": "42:5:Returned", "A": 1}, {"Id": "9:6:Avenged"}],
                                             "M_9": [{"Id": "7:2:Avenged"}]}),
        "HaloHorns_Nicknames_v1" + sfx: s({"U_42": {"UserId": 42, "Active": {"Text": "Bob"}},
                                            "N_aaa_3": {"UserId": 42, "Canonical": "bob"},
                                            "N_old_5": {"UserId": 42, "Canonical": "bobby"},
                                            "N_ccc_3": {"UserId": 7, "Canonical": "amy"}}),
        "HaloHorns_Supporters_v1" + sfx: s({"List": [{"U": 42, "N": "Bob"}, {"U": 7, "N": "Amy"}]}),
        "HaloHorns_Market_v1" + sfx: s({
            "L_1": {"Seller": 7, "Buyer": 42, "St": "Paid"},
            "L_2": {"Seller": 42, "Buyer": 7, "St": "Paid"},
            "L_3": {"Seller": 42, "St": "Open"},
            "L_4": {"Seller": 7, "Buyer": 9, "St": "Paid"},
        }),
        "HH_RankSettle_PRE" + sfx: s({"W2911": {"Boards": {"Honor": [7, 42, 9], "PvP": [9]}, "Ranks": {"Honor": [1, 2, 3], "PvP": [1]}}}),
    }
    ordered = {f"HH_Rank_PRE{sfx}_Honor_W2911": {"U_42": 500, "U_7": 300}, f"HH_Rank_PRE{sfx}_PvP_W2912": {"U_42": 10}}
    memory = {"HHMktSold" + sfx: {"42": ["L_9"], "7": ["L_1"]}}
    return std, ordered, memory


def load_tool(source: str):
    spec = importlib.util.spec_from_loader("erase_user_under_test", loader=None)
    mod = importlib.util.module_from_spec(spec)
    mod.__file__ = str(TOOL)
    exec(compile(source, str(TOOL), "exec"), mod.__dict__)
    return mod


def scenarios(tool) -> list[tuple[bool, str]]:
    out: list[tuple[bool, str]] = []

    def check(ok, name):
        out.append((bool(ok), name))

    lines: list[str] = []
    weeks = range(2911, 2913)
    # the plan
    std, ordered, memory = world()
    before = copy.deepcopy((std, ordered, memory))
    cloud = FakeCloud(std, ordered, memory)
    stats = tool.erase(cloud, UID, ["Live"], weeks, False, True, out=lines.append)
    check(not cloud.writes and (std, ordered, memory) == before, "plan: nothing written")
    text = "\n".join(lines)
    check("would delete  HaloHorns_Player_v1_Live / P_42" in text and "N_old_5" in text and "DEFERRED" in text,
          "plan: lists the save, the old nickname claim and the open listing")
    check(stats["delete"] > 0 and stats["scrub"] > 0, "plan: counts")
    # the erasure
    std, ordered, memory = world()
    cloud = FakeCloud(std, ordered, memory)
    lines.clear()
    stats = tool.erase(cloud, UID, ["Live"], weeks, True, True, out=lines.append)
    g = lambda st, k: std.get(st, {}).get(k, [None])[0]  # noqa: E731
    check(g("HaloHorns_Player_v1_Live", "P_42") is None and g("HaloHorns_NotifyAsked_v1_Live", "42") is None
          and g("HaloHorns_GrudgeMail_v1_Live", "M_42") is None and g("HaloHorns_Nicknames_v1_Live", "U_42") is None,
          "own keys deleted (save, notify, mailbox, nickname directory)")
    check(g("HaloHorns_NotifyAsked_v1_Live", "7") is not None and g("HaloHorns_Player_v1_Live", "P_7") is not None,
          "other users' keys stay")
    p7 = g("HaloHorns_Player_v1_Live", "P_7")
    check(p7["PairCD"] == {"steal:9": 50} and p7["Market"] == {"P9": 1} and p7["Rank"]["Victims"] == {"U9": 1},
          "scan-saves: 42 scrubbed from another save, the rest kept")
    m7 = g("HaloHorns_GrudgeMail_v1_Live", "M_7")
    check(m7 == [{"Id": "9:6:Avenged"}] and g("HaloHorns_GrudgeMail_v1_Live", "M_9") == [{"Id": "7:2:Avenged"}],
          "mail: 42's letters removed from others' boxes, others' kept")
    nk = std["HaloHorns_Nicknames_v1_Live"]
    check("N_aaa_3" not in nk and "N_old_5" not in nk and "N_ccc_3" in nk, "nicknames: every claim of 42 (old ones too), not 7's")
    check(g("HaloHorns_Supporters_v1_Live", "List") == [{"U": 7, "N": "Amy"}], "supporters: 42 removed")
    mk = std["HaloHorns_Market_v1_Live"]
    check(mk["L_1"][0]["Buyer"] == 0 and mk["L_2"][0]["Seller"] == 0 and mk["L_3"][0]["Seller"] == 42
          and mk["L_4"][0] == {"Seller": 7, "Buyer": 9, "St": "Paid"}, "market: buyer / finished seller -> 0, open row kept")
    check(stats["deferred"] == 1, "market: the open listing is reported (deferred)")
    st = g("HH_RankSettle_PRE_Live", "W2911")
    check(st["Boards"]["Honor"] == [7, 9] and st["Ranks"]["Honor"] == [1, 3] and st["Boards"]["PvP"] == [9],
          "settle: 42 and its rank removed together")
    check("U_42" not in ordered["HH_Rank_PRE_Live_Honor_W2911"] and "U_7" in ordered["HH_Rank_PRE_Live_Honor_W2911"]
          and "U_42" not in ordered["HH_Rank_PRE_Live_PvP_W2912"], "ordered boards: 42 deleted in every week, 7 kept")
    check("42" not in memory["HHMktSold_Live"] and "7" in memory["HHMktSold_Live"], "memory: HHMktSold 42 deleted")
    check(stats["skipped"] == 0, "nothing skipped")
    # a store changed between our read and write: skipped, not overwritten
    std, ordered, memory = world()
    cloud = FakeCloud(std, ordered, memory, race={("HaloHorns_Supporters_v1_Live", "List")})
    stats = tool.erase(cloud, UID, ["Live"], weeks, True, False, out=lambda *_: None)
    check(stats["skipped"] == 1 and std["HaloHorns_Supporters_v1_Live"]["List"][0] == [{"U": 42, "N": "Bob"}, {"U": 7, "N": "Amy"}],
          "a race: the write is refused (matchVersion), reported as skipped")
    # only the environments asked for
    live = world("_Live")
    dev = world("")
    std = {**live[0], **dev[0]}
    ordered = {**live[1], **dev[1]}
    memory = {**live[2], **dev[2]}
    cloud = FakeCloud(std, ordered, memory)
    tool.erase(cloud, UID, ["Dev"], weeks, True, False, out=lambda *_: None)
    check(std["HaloHorns_Player_v1"].get("P_42") is None and std["HaloHorns_Player_v1_Live"].get("P_42") is not None,
          "--env Dev: the Dev store erased, Live untouched")
    check(all(w[1].endswith("(memory)") is False for w in cloud.writes) and not any("_Live" in w[1] for w in cloud.writes),
          "--env Dev: no write names a Live store")
    # the real Open Cloud requests (captured, never sent)
    sent: list[tuple] = []
    real = tool.Cloud(123, "KEY")
    real._call = lambda method, url, body=None, headers=None: (sent.append((method, url, body, headers)) or (200, b"{}", {}))
    real.set("S_Live", "P_42", {"a": 1}, "08D1")
    real.delete("S_Live", "P_42")
    real.ordered_delete("HH_Rank_PRE_Live_Honor_W2911", "U_42")
    real.memory_delete("HHMktSold_Live", "42")
    m0, u0, b0, h0 = sent[0]
    check(m0 == "POST" and "matchVersion=08D1" in u0 and "datastoreName=S_Live" in u0 and "entryKey=P_42" in u0
          and h0.get("content-md5") and b0 == b'{"a":1}', "set: POST with matchVersion, content-md5 and the JSON body")
    check(sent[1][0] == "DELETE" and "/universes/123/standard-datastores/datastore/entries/entry?" in sent[1][1],
          "delete: the standard entry URL")
    check(sent[2][1].endswith("/ordered-data-stores/v1/universes/123/orderedDataStores/HH_Rank_PRE_Live_Honor_W2911/scopes/global/entries/U_42"),
          "ordered delete: the ordered entry URL")
    check(sent[3][1].endswith("/cloud/v2/universes/123/memory-store/sorted-maps/HHMktSold_Live/items/42"), "memory delete URL")
    check(tool.week_index(1759276800) == 2909 and tool.week_index(1760886000) == 2912
          and "(unixTime + Config.Daily.TimezoneOffset + 3 * 86400) / 604800" in CONFIG_TEXT
          and "TimezoneOffset = 9 * 3600" in CONFIG_TEXT, "week_index = Config.WeekIndex (Monday 00:00 KST, the same formula)")
    return out


MUTATIONS = [
    ("letters kept", 'str(e.get("Id", "")).startswith(f"{uid}:")', 'str(e.get("Id", "")).startswith(f"{uid}::")'),
    ("open listings scrubbed", 'if value.get("St") in FINISHED:', "if True:"),
    ("no matchVersion", '        if version:\n            q["matchVersion"] = version\n', ""),
    ("ranks left behind", "                                ranks.pop(i)\n", "                                pass\n"),
    ("plan writes", "        if not yes:\n            out(f\"  would {kind:<7}", "        if False:\n            out(f\"  would {kind:<7}"),
    ("old nickname claims kept", 'for key in cloud.list_keys(nick, "N_"):', 'for key in cloud.list_keys(nick, "N_none"):'),
    ("other saves keep the id", "        del m[f\"P{uid}\"]\n", "        pass\n"),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    source = TOOL.read_text(encoding="utf-8")
    results = scenarios(load_tool(source))
    failed = [n for ok, n in results if not ok]
    for ok, n in results:
        print(("ok   " if ok else "FAIL ") + n)
    print(f"ERASE checks={len(results)} failed={len(failed)}")
    caught = 0
    if "--no-mutations" not in sys.argv:
        for name, old, new in MUTATIONS:
            if source.count(old) != 1:
                print(f"MUTATION NOT APPLIED {name}")
                continue
            try:
                hit = any(not ok for ok, _ in scenarios(load_tool(source.replace(old, new, 1))))
            except Exception as e:  # noqa: BLE001 - a crash is a catch
                hit, name = True, f"{name} (crashed: {type(e).__name__})"
            caught += 1 if hit else 0
            print(("MUTATION caught  " if hit else "MUTATION MISSED ") + name)
        print(f"MUTATIONS caught={caught}/{len(MUTATIONS)}")
    ok = not failed and ("--no-mutations" in sys.argv or caught == len(MUTATIONS))
    print(f"ERASE {'passed' if ok else 'failed'}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
