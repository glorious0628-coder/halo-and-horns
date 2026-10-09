"""Toast queue static check (검수 2026-10-09, UI clutter review ②: "one notice at a time, 3 seconds").

UIKit.Toast shows one toast at a time for at most NOTIFY.ShowSeconds (3); while one shows, new words wait in
NOTIFY.Queue (the same words never twice, at most QueueMax waiting: the oldest waiting one is dropped); removeToast
shows the next waiting one. The team line (Announce, Config.ChatText.TeamToast) is covered by tools/test_chat_text.py.
UIKit.luau needs the Roblox GUI engine, so this is a static check of the rules (the live look is a Studio photo); each
mutation must make a check fail.

Usage: py tools/test_toast_queue.py
Report: docs/art/verification_2026-10-09/offline_toast_queue_2026-10-09.json
"""
from __future__ import annotations

import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
UIKIT = ROOT / "src/StarterPlayer/StarterPlayerScripts/UIKit.luau"
OUT = ROOT / "docs/art/verification_2026-10-09/offline_toast_queue_2026-10-09.json"

RULES = [
    ("one toast at a time, 3 s, at most 3 waiting",
     ["\tOneAtATime = true,\n", "\tShowSeconds = 3,\n", "\tQueueMax = 3,\n", "local DEFAULT_TOAST_SECONDS = 3 "]),
    ("a toast is shown for at most ShowSeconds",
     ["\tif NOTIFY.OneAtATime then duration = math.min(duration, NOTIFY.ShowSeconds) end\n"]),
    ("while one shows, new words wait (the same words once), the oldest waiting one dropped past QueueMax",
     ["\tif NOTIFY.OneAtATime and #toasts > 0 then\n",
      "\t\t\tif q.Text == text then return end\n",
      "\t\ttable.insert(NOTIFY.Queue, { Text = text, Kind = kind, Duration = duration, Icon = icon })\n",
      "\t\twhile #NOTIFY.Queue > NOTIFY.QueueMax do table.remove(NOTIFY.Queue, 1) end\n"]),
    ("the same words on screen are refreshed before queueing",
     None),  # order check below
    ("a removed toast brings the next waiting one",
     ["\tNOTIFY.ShowNext()\nend\n", "\tif #toasts > 0 or #NOTIFY.Queue == 0 then return end\n",
      "\tlocal q = table.remove(NOTIFY.Queue, 1)\n", "\ttask.defer(UIKit.Toast, q.Text, q.Kind, q.Duration, q.Icon)\n"]),
]

MUTATIONS = [
    ("stacked again", "\tOneAtATime = true,\n", "\tOneAtATime = false,\n"),
    ("long toasts", "\tShowSeconds = 3,\n", "\tShowSeconds = 8,\n"),
    ("no cap on the waiting line", "\t\twhile #NOTIFY.Queue > NOTIFY.QueueMax do table.remove(NOTIFY.Queue, 1) end\n", ""),
    ("the next one never shows", "\tNOTIFY.ShowNext()\nend\n", "end\n"),
    ("the same words wait twice", "\t\t\tif q.Text == text then return end\n", ""),
    ("the newest waiting one dropped", "\t\twhile #NOTIFY.Queue > NOTIFY.QueueMax do table.remove(NOTIFY.Queue, 1) end\n",
     "\t\twhile #NOTIFY.Queue > NOTIFY.QueueMax do table.remove(NOTIFY.Queue) end\n"),
    ("the duration cap gone", "\tif NOTIFY.OneAtATime then duration = math.min(duration, NOTIFY.ShowSeconds) end\n", ""),
]


def checks(src: str) -> list[tuple[str, bool]]:
    out = []
    for name, needles in RULES:
        if needles is None:
            toast = src[src.find("function UIKit.Toast("):]
            refresh = toast.find("\t\t\tscheduleToast(t, duration)\n")
            queue = toast.find("\tif NOTIFY.OneAtATime and #toasts > 0 then\n")
            out.append((name, 0 <= refresh < queue))
        else:
            out.append((name, all(src.count(n) == 1 for n in needles)))
    return out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = UIKIT.read_text(encoding="utf-8")
    res = checks(src)
    for name, ok in res:
        print(("CHECK_OK " if ok else "CHECK_FAIL ") + name)
    muts = []
    for name, old, new in MUTATIONS:
        hits = src.count(old)
        caught = hits == 1 and not all(ok for _, ok in checks(src.replace(old, new)))
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    passed = all(ok for _, ok in res) and all(m["caught"] for m in muts)
    status = "passed" if passed else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": [{"name": n, "ok": ok} for n, ok in res], "mutations": muts, "status": status},
                              indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {sum(ok for _, ok in res)}/{len(res)}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
