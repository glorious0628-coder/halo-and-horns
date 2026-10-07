"""
Firefly 원본을 검수 설계표에 맞춰 자르기 (소리 만들기, 2026-10-07).
  py tools/sfx_cut.py search [Key ...]   build/sfx_firefly/raw의 원본을 키마다 여러 방식으로 잘라
                                         tools/sfx_check.py의 측정·판정(tools/sfx_spec.json 규칙)에 가장 가까운 것을 원본마다 하나 남긴다
                                         -> build/sfx_firefly/r4b/<Key>__<원본>.wav + r4b.json
  py tools/sfx_cut.py pick [N]           키마다 상위 N개(기본 3, 한 프롬프트에서 둘까지, FAIL 빼고)를 art/sfx/cand/<Key>_<p>-<v>.wav로
                                         옮기고 공식 검사기 시트를 build/sfx_check_r4b/에 만든다(+ art/review/sfx_check_r4b_2026-10-07/)
  py tools/sfx_cut.py board              build/sfx_firefly/board_r4b.html: 검수 듣기판(공식 판정 + 스펙트로그램 + 재생 + 프롬프트 + 추천)
자르기 = (고역·저역 통과) -> 기준점(시작 또는 가장 큰 곳)에서 창 자르기 + 들어감·나감 -> 크기 맞춤(K 가중 가장 큰 100 ms = -17 LUFS,
최고점 -2.5 dBFS 아래). 설계표에 없는 키(Jump, PowerUp)는 아래 LOCAL 규칙을 쓴다(소리 만들기 안).
"""

import glob
import json
import os
import shutil
import subprocess
import sys

import numpy as np

import sfx_check as SC
import sfx_firefly as FF

ROOT = FF.ROOT
RAW = FF.RAW
OUT = os.path.join(FF.WORK, "r4b")
REPORT = os.path.join(OUT, "r4b.json")
SPEC_PATH = os.path.join(ROOT, "tools", "sfx_spec.json")
CHECK_OUT = os.path.join(ROOT, "build", "sfx_check_r4b")
REVIEW = os.path.join(ROOT, "art", "review", "sfx_check_r4b_2026-10-07")
TARGET_LUFS, PEAK_CAP = -17.0, -2.5
RANK = {"PASS": 2, "WARN": 1, "FAIL": 0}

# keys that tools/sfx_spec.json does not have yet: rules in the same form (소리 만들기 2026-10-07)
LOCAL = {}  # Jump / PowerUp / Equip now live in tools/sfx_spec.json (소리 만들기 keeps that file in step with sound_spec)


def load_spec():
    with open(SPEC_PATH, encoding="utf-8") as fh:
        spec = json.load(fh)
    for k, v in LOCAL.items():
        spec["keys"].setdefault(k, v)
    return spec


SPEC = load_spec()


def judge(key, y):
    m = SC.measure(y)
    checks = SC.check_metrics(m, SC.rule_list(SPEC, key), SPEC["keys"][key].get("volume"))
    return SC.verdict(checks), SC.score(checks), checks, m


def level(y):
    y = np.asarray(y, dtype=np.float64)
    y = y * 10 ** ((TARGET_LUFS - SC.lufs_window(SC.k_weight(y), 0.1)) / 20)
    pk, cap = np.abs(y).max(), 10 ** (PEAK_CAP / 20)
    return y * (cap / pk) if pk > cap else y


def prefilter(x, hp=0, lp=0):
    y = FF.highpass(x, hp, 4) if hp else x
    return FF.lowpass(y, lp, 4) if lp else y


def anchor(x, how, on_db=-20):
    t, d = FF.env_db(x)
    return float(t[int(np.argmax(d))]) if how == "peak" else float(t[int(np.argmax(d >= on_db))])


def window(x, t0, length, fin=0.001, fout=0.6):
    s, n = max(0, FF.count(t0)), FF.count(length)
    y = x[s:s + n].copy()
    if len(y) < n:
        y = np.pad(y, (0, n - len(y)))
    fi = max(1, FF.count(fin))
    y[:fi] *= np.linspace(0, 1, fi)
    fo = max(1, int(len(y) * fout))
    y[-fo:] *= np.linspace(1, 0, fo) ** 2
    return y


def cut(x, p):
    xf = prefilter(x, p.get("hp", 0), p.get("lp", 0))
    t0 = anchor(xf, p.get("anchor", "onset"), p.get("on", -20)) - p.get("pre", 0.0)
    y = window(xf, t0, p["len"], p.get("fin", 0.001), p.get("fout", 0.6))
    if p.get("punch"):  # lift the first few ms (a sharper '퍽' start): +punch dB fading out with a 4 ms time constant
        t = np.arange(len(y)) / FF.SR
        y = y * (1 + (10 ** (p["punch"] / 20) - 1) * np.exp(-t / 0.004))
    if p.get("tsing"):  # our own thin 'tsing' layer (spec critique: one short inharmonic tsing at about -8 dB)
        y = y + tsing(len(y), p.get("tsingAt", 0.4)) * np.abs(y).max() * 10 ** (p["tsing"] / 20)
    return level(y)


def tsing(n, at=0.4, f=3200.0):
    """a short inharmonic 'tsing' (two partials 1 : 1.53, gliding up 3 %, 3 ms attack, 22 ms decay) starting at `at` of n"""
    t = np.arange(n) / FF.SR
    t0 = at * n / FF.SR
    u = np.clip(t - t0, 0, None)
    env = np.where(t >= t0, np.minimum(u / 0.003, 1) * np.exp(-u / 0.022), 0.0)
    glide = 1 + 0.03 * np.minimum(u / 0.08, 1)
    ph1 = 2 * np.pi * np.cumsum(f * glide) / FF.SR
    ph2 = 2 * np.pi * np.cumsum(f * 1.53 * glide) / FF.SR
    return env * (np.sin(ph1) + 0.5 * np.sin(ph2)) / 1.5


def double(y, gap, speed=1.10, gain=0.85):
    """two arrows: the file + itself 10 % higher and a little quieter `gap` s later ('슉-슉')"""
    y2 = SC.respeed(y, speed) * gain
    g = FF.count(gap)
    out = np.zeros(max(len(y), g + len(y2)))
    out[:len(y)] += y
    out[g:g + len(y2)] += y2
    return level(out)


def mixdown(a, b, gain_db):
    n = max(len(a), len(b))
    out = np.zeros(n)
    out[:len(a)] += a
    out[:len(b)] += b * 10 ** (gain_db / 20)
    return level(out)


def grid(**axes):
    keys = list(axes)
    out = [{}]
    for k in keys:
        out = [{**o, k: v} for o in out for v in axes[k]]
    return out


# per key: the raw prompt groups it comes from and the cuts to try
PLAN = {
    "SwingArrow": (["SwingArcher_"], grid(anchor=["peak"], pre=[0.004, 0.012, 0.025], len=[0.07, 0.08, 0.09], fin=[0.003],
                                         fout=[0.6, 0.8], hp=[400], lp=[6500, 8000])),
    "SwingArcher": (["SwingArcher_"], grid(anchor=["peak"], pre=[0.004, 0.012, 0.025], len=[0.045, 0.055, 0.062], fin=[0.003],
                                          fout=[0.8], hp=[400], lp=[6500, 8000], gap=[0.06, 0.068])),
    "SwingMageHalo": (["SwingMage_", "SwingMageHalo_"], grid(anchor=["onset", "peak"], on=[-20], pre=[0.0, 0.02], len=[0.17, 0.2], fin=[0.008],
                                          tsing=[0, -10, -6], tsingAt=[0.35],
                                          fout=[0.5], hp=[300, 500], lp=[7000, 8500])),
    "HitHeavy": (["HitHeavy_"], grid(anchor=["onset"], on=[-30, -20], pre=[0.0005], len=[0.11, 0.14, 0.18], fin=[0.0005],
                                    fout=[0.6, 0.85], hp=[180, 250, 320], lp=[5000, 8000], punch=[0, 4])),
    # 치명타 = a LAYER over the material hit (sound_spec §1-1): strong high-pass so no body is left
    "HitCrit": (["HitCrit_"], grid(anchor=["onset"], on=[-30, -20], pre=[0.0005], len=[0.19, 0.22, 0.25],
                                   fin=[0.0008], fout=[0.6], hp=[600, 900, 1300], lp=[9000, 12000])),
    "ComboCoin": (["ComboCoin_"], grid(anchor=["onset"], on=[-30, -20], pre=[0.0005], len=[0.2, 0.23, 0.26], fin=[0.0008],
                                       fout=[0.5], hp=[600, 1000], lp=[9000, 12000])),
    "SwingTamer": (["SwingTamer_"], grid(anchor=["onset"], on=[-20], pre=[0.002], len=[0.17, 0.19, 0.21], fin=[0.004],
                                         fout=[0.4], hp=[400, 800], lp=[6000, 8000])),
    "HitSoft": (["HitSoft_"], grid(anchor=["onset"], on=[-30, -20], pre=[0.0005], len=[0.15, 0.18, 0.21], fin=[0.0008],
                                   fout=[0.6], hp=[120, 180, 250], lp=[5000, 8000])),
    # batch 2 (sound_spec §4-1: broken or backwards sounds + P0 Equip / SkillReady / HurtBig)
    "GoldPickup": (["GoldPickup_"], grid(anchor=["onset"], on=[-30, -20], pre=[0.001], len=[0.26, 0.3], fin=[0.001], fout=[0.4],
                                         hp=[400, 700], lp=[8000, 10000])),
    "QuestNew": (["QuestNew_"], grid(anchor=["onset"], on=[-30, -20], pre=[0.001], len=[0.36, 0.42], fin=[0.002], fout=[0.4],
                                     hp=[300, 600], lp=[8000])),
    "QuestDone": (["QuestDone_"], grid(anchor=["onset"], on=[-30, -20], pre=[0.001], len=[0.48, 0.56], fin=[0.002], fout=[0.35],
                                       hp=[300, 600], lp=[9000])),
    "WindowClose": (["WindowClose_"], grid(anchor=["peak", "onset"], on=[-20], pre=[0.0, 0.003], len=[0.15, 0.17], fin=[0.002],
                                           fout=[0.7], hp=[300, 600], lp=[6000, 8000])),
    "Deny": (["Deny_"], grid(anchor=["onset"], on=[-30, -20], pre=[0.001], len=[0.21, 0.24], fin=[0.002], fout=[0.4],
                             hp=[300], lp=[2500, 4000])),
    "RankDown": (["RankDown_"], grid(anchor=["onset"], on=[-30, -20], pre=[0.001], len=[0.27, 0.32], fin=[0.002], fout=[0.4],
                                     hp=[300, 400], lp=[4000])),
    "ScrollFail": (["ScrollFail_"], grid(anchor=["onset"], on=[-30, -20], pre=[0.001], len=[0.27, 0.32], fin=[0.012], fout=[0.45],
                                         hp=[300], lp=[6000])),
    "SkillHalo": (["SkillHalo_"], grid(anchor=["onset", "peak"], on=[-25], pre=[0.0, 0.08], len=[0.32, 0.38, 0.42], fin=[0.02], fout=[0.4],
                                       hp=[800], lp=[7000, 9000])),
    "SkillHorns": (["SkillHorns_"], grid(anchor=["onset", "peak"], on=[-25], pre=[0.0, 0.05], len=[0.27, 0.32], fin=[0.01], fout=[0.4],
                                         hp=[250, 400], lp=[5000, 7000])),
    "Purify": (["Purify_"], grid(anchor=["onset"], on=[-30, -20], pre=[0.002], len=[0.88, 0.95], fin=[0.01], fout=[0.35],
                                 hp=[300, 600], lp=[9000])),
    "Devour": (["Devour_"], grid(anchor=["onset"], on=[-30, -20], pre=[0.001], len=[0.62, 0.7], fin=[0.002], fout=[0.35],
                                 hp=[300], lp=[6000, 8000])),
    "Potion": (["Potion_"], grid(anchor=["onset"], on=[-30, -20], pre=[0.001], len=[0.37, 0.42], fin=[0.002], fout=[0.4],
                                 hp=[450], lp=[6000, 8000])),
    "AutoOn": (["AutoOn_"], grid(anchor=["onset"], on=[-30, -20], pre=[0.001], len=[0.23, 0.26], fin=[0.002], fout=[0.4],
                                 hp=[300, 600], lp=[6000])),
    "AutoOff": (["AutoOff_"], grid(anchor=["onset"], on=[-30, -20], pre=[0.001], len=[0.18, 0.2], fin=[0.002], fout=[0.45],
                                   hp=[300, 400], lp=[3000, 4000])),
    "TalkBlip": (["TalkBlip_"], grid(anchor=["onset", "peak"], on=[-20], pre=[0.0, 0.002], len=[0.03, 0.035], fin=[0.002], fout=[0.5],
                                     hp=[300], lp=[3000])),
    "Equip": (["Equip_"], grid(anchor=["onset"], on=[-30, -20], pre=[0.0005], len=[0.26, 0.29], fin=[0.001], fout=[0.4],
                               hp=[300], lp=[8000])),
    "SkillReady": (["SkillReady_"], grid(anchor=["onset", "peak"], on=[-20], pre=[0.0, 0.002], len=[0.05, 0.07], fin=[0.002], fout=[0.5],
                                         hp=[300], lp=[4000])),
    "HurtBig": (["HurtBig_"], grid(anchor=["onset"], on=[-30, -20], pre=[0.0005], len=[0.13, 0.16], fin=[0.001], fout=[0.5],
                                   hp=[250], lp=[3000, 5000])),
    # batch 3 (Halloween beta week, P0): the files are named KingPumpkin / KingGhost (sound_spec), the spec keys are the events
    "PumpkinKing": (["KingPumpkin_"], grid(anchor=["onset"], on=[-30, -20], pre=[0.002], len=[1.25, 1.35], fin=[0.003], fout=[0.3],
                                          hp=[150, 300], lp=[9000])),
    "GhostKing": (["KingGhost_"], grid(anchor=["onset"], on=[-30, -20], pre=[0.002], len=[1.35, 1.45], fin=[0.003], fout=[0.3],
                                       hp=[300, 400], lp=[9000])),
    "GooseArrive": (["GooseArrive_"], grid(anchor=["onset"], on=[-30, -20], pre=[0.002], len=[0.95, 1.05], fin=[0.003], fout=[0.3],
                                           hp=[400], lp=[9000])),
    "GooseHonk": (["GooseHonk_"], grid(anchor=["onset", "peak"], on=[-20], pre=[0.0, 0.01], len=[0.15, 0.17], fin=[0.003], fout=[0.4],
                                       hp=[450], lp=[5000])),
    "Jump": (["Jump_"], grid(anchor=["onset"], on=[-20, -12], pre=[0.002], len=[0.16, 0.2, 0.24], fin=[0.003], fout=[0.6],
                            hp=[200, 300], lp=[9000])),
    "SwingMageHorns": (["SwingMageHorns_"], grid(anchor=["onset", "peak"], on=[-20], pre=[0.0, 0.02], len=[0.18, 0.2, 0.22],
                                                fin=[0.006], fout=[0.5], hp=[350, 550, 800], lp=[5000, 7000])),
    "PowerUp": (["PowerUp_"], grid(anchor=["onset"], on=[-30, -20], pre=[0.002], len=[1.0, 1.15, 1.3], fin=[0.004], fout=[0.35],
                                  hp=[200, 300], lp=[9000, 11000])),
}


def sort_key(r):
    return (RANK[r["verdict"]], r["score"])


def raws(prefixes):
    return sorted(f[:-4] for f in os.listdir(RAW) if f.endswith(".wav") and any(f.startswith(p) for p in prefixes))


def search_key(key, results):
    prefixes, cuts = PLAN[key]
    for name in raws(prefixes):
        x = FF.read_wav(os.path.join(RAW, name + ".wav"))
        best = None
        for p in cuts:
            q = {k: v for k, v in p.items() if k != "gap"}
            y = cut(x, q)
            if key == "SwingArcher":
                y = double(y, p["gap"])
            v, s, checks, m = judge(key, y)
            r = {"verdict": v, "score": s, "params": p, "misses": [c for c in checks if c["level"] != "ok"],
                 "durMs": m.get("durMs"), "centroidHz": m.get("centroidHz"), "phoneDropDb": m.get("phoneDropDb")}
            if best is None or sort_key(r) > sort_key(best[0]):
                best = (r, y)
        r, y = best
        out = f"{key}__{name}"
        FF.write_wav(os.path.join(OUT, out + ".wav"), y)
        results[out] = {"key": key, "source": name, **r}
        print(f"{key:14s} {name:16s} {r['verdict']:4s} {r['score']:3d}", ", ".join(f"{c['name']}={c['value']}" for c in r["misses"])[:150])


def crit_mixes(results):
    """치명타 = the best new 퍽 (HitHeavy) + a Firefly 'ting' (HitCrit_2) layer, judged as HitCrit"""
    hits = sorted((r for r in results.values() if r["key"] == "HitHeavy"), key=sort_key, reverse=True)[:3]
    tings = raws(["HitCrit_2"])
    for h in hits:
        base = FF.read_wav(os.path.join(OUT, f"HitHeavy__{h['source']}.wav"))
        best = None
        for t in tings:
            tx = FF.read_wav(os.path.join(RAW, t + ".wav"))
            for ln in (0.2, 0.24, 0.27):
                ting = cut(tx, {"anchor": "onset", "on": -30, "len": ln, "fin": 0.0008, "fout": 0.75, "hp": 2000, "lp": 12000})
                for g in (-9, -6, -3, 0):
                    y = mixdown(np.pad(base, (0, max(0, len(ting) - len(base)))), ting, g)
                    v, s, checks, m = judge("HitCrit", y)
                    r = {"verdict": v, "score": s, "params": {"hit": h["source"], "ting": t, "len": ln, "tingDb": g},
                         "misses": [c for c in checks if c["level"] != "ok"], "durMs": m.get("durMs"),
                         "centroidHz": m.get("centroidHz"), "phoneDropDb": m.get("phoneDropDb")}
                    if best is None or sort_key(r) > sort_key(best[0]):
                        best = (r, y)
        r, y = best
        out = f"HitCrit__mix-{h['source'].split('_', 1)[1]}+{r['params']['ting'].split('_', 1)[1]}"
        FF.write_wav(os.path.join(OUT, out + ".wav"), y)
        results[out] = {"key": "HitCrit", "source": f"mix {h['source']} + {r['params']['ting']}", **r}
        print(f"{'HitCrit mix':14s} {out:30s} {r['verdict']:4s} {r['score']:3d}", ", ".join(f"{c['name']}={c['value']}" for c in r["misses"])[:150])


def search(keys):
    os.makedirs(OUT, exist_ok=True)
    results = json.load(open(REPORT, encoding="utf-8")) if os.path.exists(REPORT) else {}
    keys = keys or list(PLAN)
    for key in keys:
        for k in [k for k, v in results.items() if v["key"] == key]:
            results.pop(k)
        search_key(key, results)
    # crit_mixes() (퍽 + ting in one file) is no longer used: sound_spec plays HitCrit as a layer over the material hit
    with open(REPORT, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(results, fh, ensure_ascii=False, indent=1)


def cand_name(out):
    """'HitHeavy__HitHeavy_4-2' -> 'HitHeavy_4-2'; 'SwingArrow__SwingArcher_1-1' -> 'SwingArrow_SwingArcher-1-1' (the source
    prompt group is named when it is not the key's own); mixes keep their tag"""
    key, src = out.split("__", 1)
    if src.startswith("mix-"):
        return f"{key}_{src}"
    group, pv = src.split("_", 1)
    return f"{key}_{pv}" if group == key else f"{key}_{group}-{pv}"


def pick(n=3):
    results = json.load(open(REPORT, encoding="utf-8"))
    chosen = {}
    for key in sorted({v["key"] for v in results.values()}):
        rows = sorted(((k, v) for k, v in results.items() if v["key"] == key), key=lambda kv: sort_key(kv[1]), reverse=True)
        per, out = {}, []
        for k, v in rows:
            if v["verdict"] == "FAIL":  # a hard miss: nobody needs to listen to it
                continue
            group = v["source"].split("-")[0] if not v["source"].startswith("mix") else "mix"
            if per.get(group, 0) >= 2:
                continue
            out.append(k)
            per[group] = per.get(group, 0) + 1
            if len(out) >= n:
                break
        chosen[key] = out
    os.makedirs(FF.CAND, exist_ok=True)
    for f in os.listdir(FF.CAND):
        if f.endswith(".wav"):
            os.remove(os.path.join(FF.CAND, f))
    for v in results.values():
        v.pop("cand", None)
    files = []
    for key, outs in chosen.items():
        for k in outs:
            dst = os.path.join(FF.CAND, cand_name(k) + ".wav")
            shutil.copyfile(os.path.join(OUT, k + ".wav"), dst)
            files.append(dst)
            results[k]["cand"] = os.path.relpath(dst, ROOT).replace("\\", "/")
    with open(REPORT, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(results, fh, ensure_ascii=False, indent=1)
    # the official sheets (one per key) for the chosen files; Jump / PowerUp are not in the spec file -> their own tmp spec
    tmp_spec = os.path.join(FF.WORK, "spec_with_local.json")
    with open(tmp_spec, "w", encoding="utf-8") as fh:
        json.dump(SPEC, fh, ensure_ascii=False)
    maps = ",".join(f"{os.path.basename(f)[:-4]}={os.path.basename(f).split('_', 1)[0]}" for f in files)
    subprocess.run([sys.executable, "-W", "ignore", os.path.join(ROOT, "tools", "sfx_check.py"), *files, "--spec", tmp_spec,
                    "--out", CHECK_OUT, "--map", maps], check=True)
    os.makedirs(REVIEW, exist_ok=True)
    for f in os.listdir(CHECK_OUT):
        if f.endswith(".png") or f in ("summary.json", "summary.txt"):
            shutil.copyfile(os.path.join(CHECK_OUT, f), os.path.join(REVIEW, f))
    for key, outs in chosen.items():
        print(key, [f"{cand_name(k)} {results[k]['verdict']} {results[k]['score']}" for k in outs])
    return chosen


# ------------------------------------------------------------------ the 검수 listening board (round 4b)
KO = {"SwingArcher": "활 두 발 파일(선택) · '슉슉'", "SwingArrow": "활 · 화살 한 발(코드가 두 번 틀 수 있음)", "SwingMageHalo": "빛 마법 쏘기",
      "SwingMageHorns": "뿔 마법 쏘기", "HitHeavy": "퍽 · 단단한 몬스터 맞힘", "HitCrit": "치명타 · 재질 타격 위에 얹는 층",
      "ComboCoin": "동전 두 개 '짤-랑'", "HitSoft": "말랑 · 슬라임·유령 맞힘",
      "Jump": "점프 · 새 소리(사용자 요청)", "PowerUp": "PowerUp · 대장간 첫 무기(A23-68 #3)",
      "GoldPickup": "골드 받기 · 은행·택배·거위(처치 밖)", "QuestNew": "새 퀘스트 '띠링?'", "QuestDone": "퀘스트 완료 '짜잔~'",
      "WindowClose": "창 닫기", "Deny": "안 돼요 '어-어' (MP 부족·잠김)", "RankDown": "등급 내려감", "ScrollFail": "강화 실패 '푸스스 퐁'",
      "SkillHalo": "빛 스킬", "SkillHorns": "뿔 스킬", "Purify": "정화 · 빛 선택", "Devour": "먹기 · 뿔 선택 '앙! 꿀꺽 뽕!'",
      "Potion": "물약 마시기", "AutoOn": "자동 전투 켜기", "AutoOff": "자동 전투 끄기", "TalkBlip": "대화 글자 '톡'",
      "Equip": "장비 끼기 '착'", "SkillReady": "스킬 준비됨 '삥'", "HurtBig": "크게 맞음",
      "PumpkinKing": "호박 왕 등장", "GhostKing": "유령 왕 등장", "GooseArrive": "황금 거위 착지", "GooseHonk": "거위 맞힘 '꽉!' 한 번"}
ORDER = ["SwingArrow", "SwingMageHalo", "SwingMageHorns", "HitHeavy", "HitCrit", "ComboCoin", "HitSoft", "SwingArcher",
         "GoldPickup", "QuestNew", "QuestDone", "WindowClose", "Deny", "RankDown", "ScrollFail", "SkillHalo", "SkillHorns", "Purify", "Devour",
         "Potion", "AutoOn", "AutoOff", "TalkBlip", "Equip", "SkillReady", "HurtBig", "PowerUp", "Jump",
         "PumpkinKing", "GhostKing", "GooseArrive", "GooseHonk"]
BATCH = {k: 1 for k in ORDER[:8]}
BATCH.update({k: 2 for k in ORDER[8:28]})
BATCH.update({k: 3 for k in ORDER[28:]})
BATCH_TITLE = {1: "1번 묶음 · 전투 (지난번과 같은 후보)", 2: "2번 묶음 · UI·스킬·선택·새 소리", 3: "3번 묶음 · 할로윈 P0"}
SCENE_OF = {"SwingArrow": "archer", "SwingMageHalo": "mage_halo", "SwingMageHorns": "mage_horns", "HitHeavy": "warrior_goblin",
            "HitCrit": "warrior_goblin", "ComboCoin": "warrior_slime", "HitSoft": "warrior_slime"}
PICK = {  # 소리 만들기 추천 (검수가 고른다)
    "SwingArrow": ("SwingArrow_SwingArcher-2-4", "화살 한 발 73 ms, 중심 3.9 kHz(설계서 시제품 3.83), 줄 소리 없음. 궁수 장면에서 두 발이 '슉-슉'으로 떨어져 들려요."),
    "SwingMageHalo": ("SwingMageHalo_SwingMage-3-4", "'슝' 위로 휘는 반짝 0.17 s + 아주 얇은 합성 '샤랑'. 남은 경고는 잡음 정도(flat 0.05)뿐."),
    "SwingMageHorns": ("SwingMageHorns_1-1", "'푸슉-파직' 불꽃 탁탁, 중심 1.6 kHz, 0.17 s, 낮은 '웅' 없음."),
    "HitHeavy": ("HitHeavy_3-2", "'퍽' 한 번 0.10 s, 폰에서 2.6 dB만 줄어요. 더 둥글고 낮은 쪽을 원하면 1-2(중심 0.7 kHz, 폰 4 dB)."),
    "HitCrit": ("HitCrit_sB3", "B(금속 없음): '팡' + 떨어지는 별 + 작은 '징', 0.19 s. 사용자가 거절한 치명타가 모두 금속이었으니 B를 먼저. 금속 A는 1-2."),
    "ComboCoin": ("ComboCoin_kA", "설계서 레시피(같은 돈 소리 두 번, 두 번째가 2반음 위, 45 ms). 좋아했던 '동전 두 개' 방향. kC는 검사 모두 통과."),
    "HitSoft": ("HitSoft_kB", "푹신한 '말랑' + 젤리 '뽀용' + 폰용 작은 '뽀'. 좋아했던 B 방향(새 재료). 폰 -5.1 dB라 실제 폰 확인 필요."),
    "PowerUp": ("PowerUp_1-2", "0.7 → 2 → 4.9 kHz로 쭉 올라가는 반짝 1.05 s, 끝에 반짝 마무리."),
    "Jump": ("Jump_2-2", "통통 '폴-짝' 0.19 s, 폰 -0.8 dB, 낮은 소리 없음."),
    "SwingArcher": ("SwingArcher_2-1", "선택: 두 발을 파일 하나로 올릴 때(코드가 두 번 틀면 필요 없음)."),
    "GoldPickup": ("GoldPickup_sB", "우리 동전 3개 E7→D7→G7, 55 ms 간격, 0.31 s. 처치 동전(ComboCoin)보다 길고 한 음 더. 폰 손실 0."),
    "QuestNew": ("QuestNew_sA", "종이 '팔락' + 마림바 C6→G6 '띠링?' 0.37 s. 동전 음(E7)보다 아래라 돈 소리와 안 겹쳐요."),
    "QuestDone": ("QuestDone_sA", "종 E6-G6-C7 65 ms 간격 + 작은 반짝 '짜잔' 0.58 s. LevelUp보다 한 옥타브 위, 폰 손실 0.1 dB."),
    "WindowClose": ("WindowClose_sA", "창 열기의 거울: 1.55 → 1.0 kHz로 내려가는 '쏙' 0.16 s, 시작이 제일 커요."),
    "Deny": ("Deny_sA", "고무 같은 두 음 622 → 523 Hz(단3도 아래, 꾸중 아님) 0.22 s, 두 음 사이 99 ms."),
    "RankDown": ("RankDown_sA", "마림바 E5-D5-C5 55 ms 간격, 하나씩 조금 작게 0.32 s. 슬프지 않은 '또르르'."),
    "ScrollFail": ("ScrollFail_sA", "'푸스스' 바람 3.5 → 0.9 kHz + '퐁' E5 → C5 0.28 s. 딸깍 없는 부드러운 시작(18 ms)."),
    "SkillHalo": ("SkillHalo_sA", "위로 오르는 바람 1.2 → 5 kHz + 유리 차임 + 반짝 0.36 s. 뿔 스킬과 점수 차이 충분."),
    "SkillHorns": ("SkillHorns_sA", "불꽃 '화르륵' 400 → 1200 → 600 Hz + 탁탁 + '봄' + 나무 '토독' 0.32 s, 폰 -1 dB."),
    "Purify": ("Purify_sA", "유리 바람 종(C장조, 순서 랜덤) + 오르는 공기 + 반짝 0.92 s. 설계서대로 sB를 둘째 버전으로 번갈아 써도 돼요. 조각 기울기(ShardLean) 1.12배 재사용도 통과."),
    "Devour": ("Devour_sA", "바삭 '앙' → 낮은 '꿀꺽' 두 번 → '뽕' 900 → 1800 Hz + 불씨 0.69 s. 정화와 크기 차이 1 LU 안(어느 쪽도 더 '좋은' 소리 아님)."),
    "Potion": ("Potion_sA", "코르크 '뽁' 1.4 → 0.5 kHz + 오르는 거품 7개 0.37 s."),
    "AutoOn": ("AutoOn_sA", "딸깍 + 밝게 올라가는 모터 + 높은 '삑'(D7) 0.24 s. 끄기(AutoOff_sA)와 같은 딸깍이라 짝이 맞아요(짝 검사 통과)."),
    "AutoOff": ("AutoOff_sA", "같은 딸깍 + 내려가는 모터 + 나무 '톡'(C5) 0.18 s. 켜기는 높게 끝나고 끄기는 낮게 끝나요."),
    "TalkBlip": ("TalkBlip_sB", "삼각파 '톡' 660 → 630 Hz, 33 ms, 글자마다 나도 귀가 안 아픈 소리. 몬스터 말풍선(BarkPop)이 이 파일을 0.8배로 쓸 때도 통과(sA는 폰 -3.1 dB로 살짝 넘음)."),
    "Equip": ("Equip_sA", "톱니 '차르륵' 3번 + 걸쇠 '착' + 작은 반짝 0.29 s."),
    "SkillReady": ("SkillReady_sA", "부드러운 '삥' 1.4 → 1.6 kHz, 49 ms. 전투 중에도 거슬리지 않게 짧게."),
    "HurtBig": ("HurtBig_sA", "막힌 '쿵' 700 → 300 Hz + 내려가는 짧은 '끽' 0.15 s. 피·비명 없음, 폰 -1.3 dB."),
    "PumpkinKing": ("PumpkinKing_sA", "왕 종 두 번(650 Hz) → 속 빈 '뻥' → 사탕 34알 '사르르' 1.24 s. 중간 빈 구멍 없음(36 ms), 폰 -2.5 dB."),
    "GhostKing": ("GhostKing_sA", "호박 왕과 같은 왕 종 두 번 → 숨 섞인 '후우?'(위로, 질문 모양) → 유리 '찰랑' 1.33 s. Firefly 1-1·2-3도 통과지만 종이 달라요."),
    "GooseArrive": ("GooseArrive_sA", "날갯짓 3번 → '꽥' 560 Hz → '꽥' 3반음 위 → 금 반짝 0.98 s. 꽥은 GooseHonk와 같은 목소리."),
    "GooseHonk": ("GooseHonk_sA", "장난감 고무 거위 '꽉!' 한 번 0.16 s, 600 Hz, 위로 살짝 꺾임. 두 음이 내려가는 Deny와 다르게."),
}


def span_of(key):
    """spectrogram time span (s): long keys get a longer picture"""
    r = SPEC["keys"].get(key, {}).get("rules", {}).get("durMs")
    hi = (r.get("hard") or r.get("range")) if isinstance(r, dict) else r
    hi = (hi[1] if hi and hi[1] else 300) / 1000
    return next(v for v in (0.35, 0.7, 1.0, 1.4, 1.8) if v >= hi + 0.05 or v == 1.8)


def prompt_for(src):
    """'SwingArcher_3-1' -> its Firefly prompt; mixes -> how they were made"""
    if src.startswith("mix"):
        return ""
    p = os.path.join(ROOT, "art", "prompts", "SFX_" + src.split("-")[0] + ".txt")
    return open(p, encoding="utf-8").read().strip() if os.path.exists(p) else ""


def board():
    """build/sfx_firefly/board/index.html + a/*.wav, i/*.jpg, s/*.mp3 (published as files beside the page)"""
    import html as H
    summ = json.load(open(os.path.join(REVIEW, "summary.json"), encoding="utf-8"))
    results = json.load(open(REPORT, encoding="utf-8"))
    by_cand = {cand_name(k): v for k, v in results.items() if v.get("cand")}
    root = os.path.join(FF.WORK, "board")
    scenes_dir = os.path.join(ROOT, "build", "sfx_scene")
    shutil.rmtree(root, ignore_errors=True)
    for d in ("a", "i", "s"):
        os.makedirs(os.path.join(root, d), exist_ok=True)
    files = []

    def add(src, rel):
        shutil.copyfile(src, os.path.join(root, rel))
        files.append(rel)
        return rel

    def scene_audio(stem, label):
        mp3 = os.path.join(scenes_dir, stem + ".mp3")
        if not os.path.exists(mp3):
            return ""
        rel = add(mp3, f"s/{stem}.mp3")
        return f'<div class="scene"><span>{H.escape(label)}</span><audio controls preload="none" src="{rel}"></audio></div>'

    secs = []
    last = None
    for key in ORDER:
        rows = summ["keys"].get(key, [])
        if not rows:
            continue
        if BATCH.get(key) != last:
            last = BATCH.get(key)
            secs.append(f'<h2 class="bhead" id="b{last}">{H.escape(BATCH_TITLE.get(last, ""))}</h2>')
        ks = SPEC["keys"][key]
        rec, why = PICK.get(key, ("", ""))
        scene = SCENE_OF.get(key)
        tiles = []
        for r in rows:
            name = r["name"]
            v = by_cand.get(name, {})
            wav = os.path.join(FF.CAND, name + ".wav")
            x = FF.read_wav(wav)
            FF.SPAN = span_of(key)
            jpg = os.path.join(root, "i", name + ".jpg")
            FF.spec_image(x, 430, 140).save(jpg, quality=86)
            FF.SPAN = 0.7
            files.append(f"i/{name}.jpg")
            misses = "".join(f'<li class="l{1 if m["level"] == "warn" else 0}">{H.escape(m["name"])} {m["value"]} (목표 {m["want"]})</li>'
                             for m in r["misses"]) or '<li class="l2">모든 검사 통과</li>'
            src = v.get("source", "")
            pr = prompt_for(src)
            params = v.get("params", {})
            how = ""
            if "recipe" in params:
                how = f'<p class="prompt">{H.escape(params["recipe"])}</p>'
            elif params.get("tsing"):
                how = '<p class="prompt">Firefly + 우리 합성 “샤랑” 한 겹(아주 얇게)</p>'
            chip = '<span class="pick">추천</span>' if name == rec else ""
            m = r["metrics"]
            sc = scene_audio(f"{scene}_{name}", "장면 20초") if scene else ""
            tiles.append(
                f'<article class="tile {r["verdict"].lower()}{" rec" if name == rec else ""}">'
                f'<header><code>{H.escape(name)}</code><span class="vd {r["verdict"].lower()}">{r["verdict"]} {r["score"]}</span>{chip}</header>'
                f'<p class="ko">{m["durMs"]:g} ms · 중심 {m["centroidHz"]} Hz · 폰 -{m["phoneDropDb"]:g} dB</p>'
                f'<img class="spec" alt="{H.escape(name)} 스펙트로그램" src="i/{H.escape(name)}.jpg">'
                f'<audio controls preload="none" src="{add(wav, "a/" + name + ".wav")}"></audio>{sc}'
                f'<ul>{misses}</ul>' + (f'<p class="prompt">“{H.escape(pr)}”</p>' if pr else "") + how + '</article>')
        recline = f'<p class="rec-line"><span class="pick">추천</span> <code>{H.escape(rec)}</code> — {H.escape(why)}</p>' if rec else ""
        recscene = ""
        if scene:
            recscene = ('<div class="recscene"><b>추천 조합 장면</b>' + scene_audio(f"{scene}_rec", "보통 스피커")
                        + scene_audio(f"{scene}_rec_phone", "폰 스피커(400 Hz 고역 통과)") + '</div>')
        tag = f'<span class="batch">그림 0–{span_of(key):g} s</span>'
        secs.append(f'<section><h3>{H.escape(KO.get(key, key))} <code class="key">{key}</code> {tag}</h3>'
                    f'<p class="target">{H.escape(ks.get("say", ""))} · {H.escape(ks.get("moment", ""))}</p>{recline}{recscene}'
                    f'<div class="grid">{"".join(tiles)}</div></section>')
    page = BOARD_HTML.replace("{{BODY}}", "".join(secs))
    with open(os.path.join(root, "index.html"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(page)
    with open(os.path.join(root, "files.json"), "w", encoding="utf-8", newline="\n") as fh:
        json.dump(sorted(set(files)), fh, indent=0)
    size = sum(os.path.getsize(os.path.join(root, f)) for f in set(files))
    print(root, len(set(files)), "files", round(size / 1e6, 1), "MB")


BOARD_HTML = """<title>효과음 4차 듣기판</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans+KR:wght@400;600&display=swap">
<style>
/* layout: one column of sound keys; each key = target line + recommended scene + a wrapping grid of candidate tiles */
:root{--bg:#f3f4f7;--surface:#ffffff;--ink:#1b1d24;--muted:#5a5f6e;--line:#dde0e8;--accent:#1d7487;--ok:#2b9656;--near:#b07d0c;--off:#c8463d;
--ref:#868b98;--pickbg:#e3f3f6;--sans:"IBM Plex Sans KR","Malgun Gothic","Apple SD Gothic Neo",system-ui,sans-serif;--mono:"IBM Plex Mono",ui-monospace,Consolas,monospace}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--bg:#121419;--surface:#1b1e26;--ink:#e8eaf1;--muted:#a1a6b4;--line:#2c303b;--accent:#5bc2d4;--ok:#4cca82;--near:#e2b33f;--off:#ee665e;--ref:#9a9fac;--pickbg:#183139;color-scheme:dark}}
:root[data-theme="dark"]{--bg:#121419;--surface:#1b1e26;--ink:#e8eaf1;--muted:#a1a6b4;--line:#2c303b;--accent:#5bc2d4;--ok:#4cca82;--near:#e2b33f;--off:#ee665e;--ref:#9a9fac;--pickbg:#183139;color-scheme:dark}
body{background:var(--bg);color:var(--ink);font:15px/1.55 var(--sans)}
main{max-width:1240px;margin:0 auto;padding-inline:16px;padding-block:24px 48px;display:flex;flex-direction:column;gap:30px}
h1{font-size:1.5rem;margin:0;text-wrap:balance}h3{font-size:1.15rem;margin:0;text-wrap:balance}
h2.bhead{font-size:1.3rem;margin:12px 0 -12px;padding-top:14px;border-top:2px solid var(--line);text-wrap:balance}
nav.jump{display:flex;flex-wrap:wrap;gap:8px;margin:12px 0 0}
nav.jump a{color:var(--accent);font-size:.88rem;border:1px solid var(--line);border-radius:999px;padding:3px 12px;text-decoration:none;background:var(--surface)}
.lead{margin:6px 0 0;color:var(--muted);max-width:75ch}
.legend{display:flex;flex-wrap:wrap;gap:6px 16px;margin:10px 0 0;padding:0;list-style:none;font-size:.82rem;color:var(--muted)}
section{display:flex;flex-direction:column;gap:6px}
.target{margin:0;color:var(--muted);font-size:.86rem}.rec-line{margin:2px 0 4px;font-size:.9rem}
code{font-family:var(--mono);font-size:.85em}code.key{font-size:.8rem;color:var(--muted)}
.batch{font-size:.72rem;color:var(--muted);border:1px solid var(--line);border-radius:999px;padding:1px 8px;vertical-align:middle}
.recscene{display:flex;flex-wrap:wrap;gap:8px 16px;align-items:center;background:var(--surface);border:1px solid var(--line);border-radius:10px;padding:10px 12px;font-size:.85rem}
.scene{display:flex;flex-direction:column;gap:2px;min-width:0;flex:1 1 240px}.scene span{font-size:.75rem;color:var(--muted)}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:14px}
.tile{min-width:0;background:var(--surface);border:1px solid var(--line);border-radius:10px;padding:12px;display:flex;flex-direction:column;gap:8px;border-top:4px solid var(--ok)}
.tile.warn{border-top-color:var(--near)}.tile.rec{box-shadow:0 0 0 2px var(--accent)}
.tile header{display:flex;align-items:baseline;gap:8px;flex-wrap:wrap}
.vd{font-size:.72rem;font-weight:600;border-radius:999px;padding:1px 7px;border:1px solid currentColor}.vd.pass{color:var(--ok)}.vd.warn{color:var(--near)}
.pick{display:inline-block;font-size:.72rem;font-weight:600;color:var(--accent);background:var(--pickbg);border-radius:999px;padding:1px 8px}
.ko{margin:0;font-size:.85rem;font-variant-numeric:tabular-nums}
.spec{width:100%;max-width:100%;height:auto;border-radius:6px;display:block}
audio{width:100%}
.tile ul{list-style:none;margin:0;padding:0;font-size:.78rem;display:flex;flex-direction:column;gap:2px;font-variant-numeric:tabular-nums}
.tile li,.legend li{position:relative;padding-left:15px}
.tile li:before,.legend li:before{content:"";position:absolute;left:0;top:.45em;width:9px;height:9px;border-radius:50%;background:var(--ref)}
li.l2:before{background:var(--ok)}li.l1:before{background:var(--near)}li.l0:before{background:var(--off)}
.prompt{margin:0;font-size:.8rem;color:var(--muted);font-style:italic}
</style>
<main>
<header>
<h1>효과음 4차 듣기판</h1>
<p class="lead">검수용입니다. 키마다 하나를 골라 주세요. 판정은 설계서 검사기(tools/sfx_check.py + tools/sfx_spec.json): PASS = 먼저 들어 볼 것, WARN = 작은 벗어남만 있음, 불합격은 뺐어요.
'장면 20초'는 실제 게임 타이밍(휘두름 → 타격 → 처치 '뽕' → 동전)과 설계표 볼륨으로 겹친 소리예요. 맨 위 '추천 조합 장면'은 보통 스피커와 폰 스피커 두 가지.
그림은 스펙트로그램(세로 50 Hz–12 kHz, 가로는 키 제목 옆에 적은 길이). 이름 끝이 sA·sB·kA인 것은 설계서 레시피대로 만든 우리 합성(+ Kenney CC0), 1-2 같은 숫자는 Firefly예요.
2026-10-07 · Firefly 60번 생성(600크레딧: 1번 묶음 35 + 2·3번 묶음 25) + Kenney CC0 + 우리 합성. 1번 묶음은 지난번과 같은 후보예요.</p>
<nav class="jump" aria-label="묶음"><a href="#b1">1번 묶음 · 전투</a><a href="#b2">2번 묶음 · UI·스킬</a><a href="#b3">3번 묶음 · 할로윈</a></nav>
<ul class="legend"><li class="l2">목표 안</li><li class="l1">조금 벗어남</li><li class="l0">벗어남</li><li>참고</li></ul>
</header>
{{BODY}}
</main>
"""


def ledger(board_url="", generations=60, balance_before=9640):
    """art/sfx/cand/firefly_r4.json: prompts, Firefly asset ids, credits, the checker verdicts and cuts of the candidates"""
    results = json.load(open(REPORT, encoding="utf-8"))
    assets = json.load(open(os.path.join(FF.WORK, "raw_assets.json"), encoding="utf-8"))
    prompts = {f[4:-4]: open(os.path.join(FF.PROMPTS, f), encoding="utf-8").read().strip()
               for f in sorted(os.listdir(FF.PROMPTS)) if f.startswith("SFX_") and f.endswith(".txt")}
    book = {
        "round": "4b / batches 1-3", "date": "2026-10-07", "by": "소리 만들기",
        "made": "Adobe Firefly 'Generate sound effects' (firefly.adobe.com, the user's Adobe account): 1 s (PowerUp 1.5 s), 4 variations per generation; "
                "where Firefly could not meet the spec: Kenney CC0 + our synthesis (tools/sfx_make.py RECIPES: ComboCoin k*, HitSoft k*, HitCrit sB*; "
                "tools/sfx_recipes.py: the sound_spec recipes for batches 2-3, names s* / k*)",
        "license": "Firefly generation (Adobe: commercially safe output); Kenney Impact Sounds + Interface Sounds (CC0 1.0); our own synthesis. Our edit = cut, "
                   "mono 48 kHz, high/low-pass, level; SwingMageHalo candidates may carry our own thin synthesized 'tsing' (tools/sfx_cut.py tsing())",
        "credits": {"generations": generations, "perGeneration": 10, "used": generations * 10, "balanceBefore": balance_before,
                    "balanceAfter": balance_before - generations * 10},
        "spec": "tools/sfx_spec.json (Jump / PowerUp / Equip added by 소리 만들기)", "checker": "tools/sfx_check.py", "scenes": "tools/sfx_scene.py",
        "level": "K-weighted loudest 100 ms = -17 LUFS, peak <= -2.5 dBFS",
        "sheets": os.path.relpath(REVIEW, ROOT).replace("\\", "/"), "board": board_url,
        "recommend": {k: v[0] for k, v in PICK.items()},
        "candidates": {cand_name(k): {f: v[f] for f in ("key", "source", "verdict", "score", "params", "durMs", "centroidHz", "phoneDropDb")}
                       for k, v in sorted(results.items()) if v.get("cand")},
        "prompts": prompts,
        "clips": assets,
        "superseded": "round 4 first cut (dev2 shape targets): art/review/sfx_firefly_2026-10-07*.png, commit 58b7026",
    }
    with open(FF.LEDGER, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(book, fh, ensure_ascii=False, indent=1)
    print(FF.LEDGER, len(book["candidates"]), "candidates,", len(assets), "clips")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    cmd = sys.argv[1] if len(sys.argv) > 1 else "search"
    if cmd == "search":
        search(sys.argv[2:])
    elif cmd == "pick":
        pick(int(sys.argv[2]) if len(sys.argv) > 2 else 3)
    elif cmd == "board":
        board()
    elif cmd == "ledger":
        ledger(sys.argv[2] if len(sys.argv) > 2 else "")
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
