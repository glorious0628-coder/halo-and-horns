"""시험 숫자판 (A23-160 ④, 게임성 개발 2, 2026-10-13): the private test's numbers as tables.

Reads the round document TestMetricsService writes (Config.TestMetrics: store Config.StoreName(Store), key = Round; no names or
UserIds in it) and, optionally, Creator Hub's onboarding funnel numbers. Prints markdown tables: the first screen (intro / side
picked), the 10-minute run (Lv5, the first dropped weapon, the first mission claim, all three), the test's pass lines
(gameplay_plan 1-B: Lv5 within 5 min, Lv10 within 15, the first dropped weapon within 4), sides, devices, passes bought and still
working after a rejoin. Contract: docs/design/test_metrics_2026-10-13.md.

Ways to get the document:
  --studio        run the reader in a Studio (Edit mode, API access on) through tools/studio_mcp.py. The main game Studio needs
                  HH_MAIN_STUDIO=1 (메인 반영 1 / 최종 검수 only); it reads, never writes. --save keeps the raw JSON.
  --json FILE     a document saved before (--save), or the reader's printed JSON pasted into a file.
  --print-luau    print the reader (paste it into Studio's command bar; copy the TESTMETRICS_JSON line into a file).
  --studio-copy   read the "_STUDIO" copy (what Studio Play sessions wrote: a dry run of the whole road before the test).
  --hub FILE.csv  Creator Hub (Analytics > Funnels > Onboarding) numbers: any CSV with a step name and a user count per row
                  (an export, or two columns typed by hand: step,users).
Usage: py tools/test_metrics_board.py (--studio | --json FILE) [--round PT1] [--studio-copy] [--hub FILE.csv] [--save FILE]
       [--out FILE.md]
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
MARK = "TESTMETRICS_JSON "
STEPS = ["IntroDone", "Faction", "Class", "FirstMissionAccept", "ForgeArrive", "FirstWeapon", "MeadowArrive", "FirstHit",
         "FirstKill", "FirstMissionDone", "FirstSkillHit", "AutoUnlocked", "Level10"]  # Config.Analytics.Steps
TEN = 10  # Config.TestMetrics.TenMinutes
LINES = [("Lv5", 5, "Lv5 5분 이하"), ("Lv10", 15, "Lv10 15분 이하"), ("Weapon", 4, "첫 무기(대장간 T1) 4분 이하")]  # gameplay_plan 1-B
LINES.append(("DropWeapon", 8, "첫 드롭 무기(첫 Prince T2) 8분 이하"))  # GPT review ④ (10/14): its own milestone


def reader_luau(round_name: str | None, studio_copy: bool) -> str:
    """the Studio reader: Config.TestMetrics' store through Config.StoreName (+ _STUDIO for the copy); read only"""
    rnd = "nil" if not round_name else json.dumps(round_name)
    suffix = '"_STUDIO"' if studio_copy else '""'
    return f"""local Http = game:GetService("HttpService")
local DSS = game:GetService("DataStoreService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local M = Config.TestMetrics
local name = Config.StoreName(M.Store) .. {suffix}
local round = {rnd} or M.Round
local ok, doc = pcall(function() return DSS:GetDataStore(name):GetAsync(round) end)
local out = Http:JSONEncode({{ Store = name, Round = round, Ok = ok, Error = (not ok) and tostring(doc) or nil,
	Doc = ok and doc or nil, At = os.time() }})
print("{MARK}" .. out)
return out
"""


def from_studio(code: str) -> dict:
    sys.path.insert(0, str(HERE))
    from studio_mcp import Client  # noqa: E402
    c = Client()
    try:
        c.start()
        res = c.call("execute_luau", {"code": code, "datamodel_type": "Edit"})
    finally:
        c.close()
    text = "".join(p.get("text", "") for p in res.get("content", []))
    return parse(text)


def parse(text: str) -> dict:
    for line in text.splitlines():
        if MARK in line:
            return json.loads(line.split(MARK, 1)[1])
    start, end = text.find("{"), text.rfind("}")
    if start >= 0 and end > start:
        data = json.loads(text[start:end + 1])
        return data if "Doc" in data else {"Doc": data}
    raise SystemExit("no TESTMETRICS_JSON in the reader's output:\n" + text[:400])


def pct(n: float, d: float) -> str:
    return f"{100 * n / d:.0f}%" if d else "-"


def minutes(doc: dict, milestone: str) -> dict[int, int]:
    raw = (doc.get("Min") or {}).get(milestone) or {}
    return {int(k): int(v) for k, v in raw.items() if re.fullmatch(r"\d+", str(k))}


def within(hist: dict[int, int], limit: int) -> int:
    return sum(v for k, v in hist.items() if k < limit)


def median(hist: dict[int, int]) -> str:
    total = sum(hist.values())
    if not total:
        return "-"
    seen = 0
    for k in sorted(hist):
        seen += hist[k]
        if seen * 2 >= total:
            return f"{k}분"
    return "-"


def table(head: list[str], rows: list[list]) -> list[str]:
    out = ["| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
    out += ["| " + " | ".join(str(c) for c in r) + " |" for r in rows]
    return out + [""]


def board(meta: dict) -> list[str]:
    doc = meta.get("Doc") or {}
    new = int(doc.get("New") or 0)
    lines = [f"# 시험 숫자판 — {meta.get('Round', '?')} ({meta.get('Store', '?')})", ""]
    if meta.get("Ok") is False:
        lines += [f"읽기 실패: {meta.get('Error')}", ""]
    if not doc:
        return lines + ["아직 기록 없음 (문서가 비어 있음).", ""]
    lines += [f"계정 {int(doc.get('Players') or 0)}명 (그중 새 계정 {new}명), 접속 {int(doc.get('Joins') or 0)}번.", ""]
    lines.append("## 첫 화면 (새 계정)")
    lines += table(["무엇", "명", "비율"], [
        ["인트로 끝", int(doc.get("Intro") or 0), pct(doc.get("Intro") or 0, new)],
        ["진영 고름 (첫 화면 통과)", int(doc.get("Faction") or 0), pct(doc.get("Faction") or 0, new)],
    ])
    lines.append(f"## 10분 완주 (새 계정, 플레이 {TEN}분 안)")
    rows = []
    for m, label in (("Lv5", "Lv5"), ("Weapon", "첫 무기(대장간 T1)"), ("Claim", "첫 미션 Claim")):
        h = minutes(doc, m)
        rows.append([label, within(h, TEN), pct(within(h, TEN), new), sum(h.values()), median(h)])
    hd = minutes(doc, "DropWeapon")  # GPT review ④: the first Slime Prince's tier 2, apart from the Forge's first weapon
    rows.append(["첫 드롭 무기(Prince T2)", within(hd, TEN), pct(within(hd, TEN), new), sum(hd.values()), median(hd)])
    rows.append(["셋 다 (10분 완주)", int(doc.get("Ten") or 0), pct(doc.get("Ten") or 0, new), "", ""])
    lines += table(["무엇", f"{TEN}분 안", "비율", "언젠가 닿음", "중간값"], rows)
    lines.append("## 합격선 (게임성 계획 1-B)")
    rows = []
    for m, limit, label in LINES:
        h = minutes(doc, m)
        rows.append([label, within(h, limit), pct(within(h, limit), new), median(h)])
    lines += table(["선", "명", "비율(새 계정)", "중간값"], rows)
    side, dev = doc.get("Side") or {}, doc.get("Device") or {}
    if side or dev:
        lines.append("## 진영·기기 (새 계정)")
        lines += table(["무엇", "명"], [[f"진영 {k}", int(v)] for k, v in sorted(side.items())]
                       + [[f"기기 {k}", int(v)] for k, v in sorted(dev.items())])
    xp = doc.get("XP") or {}
    if xp:  # Codex B6: how much of the way to Lv5 / Lv10 came from hunting vs quests / dailies (new accounts)
        lines.append("## 경험치 출처 (새 계정, 그 레벨까지)")
        rows = []
        for m in ("Lv5", "Lv10"):
            r = xp.get(m) or {}
            hunt, other, n = float(r.get("Hunt") or 0), float(r.get("Other") or 0), int(r.get("N") or 0)
            rows.append([m, n, f"{hunt / n:.0f}" if n else "-", f"{other / n:.0f}" if n else "-", pct(hunt, hunt + other)])
        lines += table(["레벨", "명", "사냥 XP(평균)", "퀘스트·일일 XP(평균)", "사냥 비율"], rows)
    passes = doc.get("Pass") or {}
    lines.append("## 패스 (산 뒤 다시 접속했을 때 혜택이 남았나)")
    if passes:
        rows = []
        for k in sorted(passes):
            p = passes[k] or {}
            back, kept, unknown = int(p.get("Back") or 0), int(p.get("Kept") or 0), int(p.get("Unknown") or 0)
            answered = back - unknown  # Roblox answered on that join (Unknown = no answer yet: not a loss)
            rows.append([k, int(p.get("Bought") or 0), back, kept, unknown, pct(kept, answered) if answered > 0 else "-"])
        lines += table(["패스", "삼", "다시 접속", "혜택 남음", "확인 못 함", "유지율"], rows)
    else:
        lines += ["아직 산 패스 없음.", ""]
    return lines


def hub(path: Path) -> list[str]:
    counts: dict[str, int] = {}
    with open(path, encoding="utf-8-sig", newline="") as f:
        for row in csv.reader(f):
            step = next((c.strip() for c in row if c.strip() in STEPS), None)
            nums = [c.replace(",", "").strip() for c in row]
            value = next((int(float(n)) for n in nums if re.fullmatch(r"\d+(\.\d+)?", n)), None)
            if step and value is not None and step not in counts:
                counts[step] = value
    if not counts:
        return [f"Creator Hub 파일에서 단계 이름을 못 찾음: {path}", ""]
    first = counts.get(STEPS[0]) or max(counts.values())
    rows = [[s, counts[s], pct(counts[s], first)] for s in STEPS if s in counts]
    return ["## Creator Hub 온보딩 퍼널 (참고: 하루쯤 늦게 쌓임)"] + table(["단계", "명", "첫 단계 대비"], rows)


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    src = ap.add_mutually_exclusive_group()
    src.add_argument("--studio", action="store_true")
    src.add_argument("--json", type=Path)
    src.add_argument("--print-luau", action="store_true")
    ap.add_argument("--round")
    ap.add_argument("--studio-copy", action="store_true")
    ap.add_argument("--hub", type=Path)
    ap.add_argument("--save", type=Path)
    ap.add_argument("--out", type=Path)
    a = ap.parse_args()
    code = reader_luau(a.round, a.studio_copy)
    if a.print_luau:
        print(code)
        return 0
    lines: list[str] = []
    if a.studio or a.json:
        if a.studio:
            if not (os.environ.get("HH_MAIN_STUDIO") or os.environ.get("STUDIO_NAME") or os.environ.get("STUDIO_ID")):
                print("Studio 창을 정하세요: 게임 Studio = HH_MAIN_STUDIO=1 (메인 반영 1 / 최종 검수만)", file=sys.stderr)
                return 2
            meta = from_studio(code)
        else:
            meta = parse(a.json.read_text(encoding="utf-8-sig"))
        if a.save:
            a.save.write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        lines += board(meta)
    if a.hub:
        lines += hub(a.hub)
    if not lines:
        ap.print_help()
        return 2
    text = "\n".join(lines)
    print(text)
    if a.out:
        a.out.write_text(text + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
