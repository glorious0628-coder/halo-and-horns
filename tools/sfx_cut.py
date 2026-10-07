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
LOCAL = {
    "Jump": {"tier": "quiet", "volume": 0.25, "say": "폴짝 / 퐁 (hop)", "moment": "my character jumps (user 2026-10-07)",
             "rules": {"durMs": {"range": [150, 260], "hard": [100, 330]}, "attackMs": {"range": [0, 10], "hard": [0, 25]},
                       "peakAtMs": {"range": [0, 40], "hard": [0, 80]}, "phoneDropDb": {"range": [0, 3], "hard": [0, 6]},
                       "lt150": {"range": [0, 0.02], "hard": [0, 0.05]}, "gt8k": [0, 0.05], "harshDb": [0, 10]}},
    "PowerUp": {"tier": "big", "volume": 0.6, "say": "반짝반짝↑ 짠!", "moment": "first weapon at the blacksmith, over the Power count-up (A23-68 #3)",
                "rules": {"durMs": {"range": [1000, 1400], "hard": [800, 1600]}, "firstOnsetMs": [0, 10], "centDir": "up",
                          "phoneDropDb": {"range": [0, 2], "hard": [0, 4]}, "lt150": {"range": [0, 0.01], "hard": [0, 0.03]},
                          "gt8k": [0, 0.08], "harshDb": [0, 12]}},
}


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
    "SwingArrow": (["SwingArcher_"], grid(anchor=["peak"], pre=[0.004, 0.012, 0.025], len=[0.06, 0.07, 0.08], fin=[0.003],
                                         fout=[0.6, 0.8], hp=[400], lp=[6500, 8000])),
    "SwingArcher": (["SwingArcher_"], grid(anchor=["peak"], pre=[0.004, 0.012, 0.025], len=[0.045, 0.055, 0.062], fin=[0.003],
                                          fout=[0.8], hp=[400], lp=[6500, 8000], gap=[0.06, 0.068])),
    "SwingMageHalo": (["SwingMage_", "SwingMageHalo_"], grid(anchor=["onset", "peak"], on=[-20], pre=[0.0, 0.02], len=[0.17, 0.2], fin=[0.008],
                                          tsing=[0, -10, -6], tsingAt=[0.35],
                                          fout=[0.5], hp=[300, 500], lp=[7000, 8500])),
    "HitHeavy": (["HitHeavy_"], grid(anchor=["onset"], on=[-30, -20], pre=[0.0005], len=[0.11, 0.14, 0.18], fin=[0.0005],
                                    fout=[0.6, 0.85], hp=[180, 250, 320], lp=[5000, 8000], punch=[0, 4])),
    "HitCrit": (["HitCrit_1", "HitCrit_3"], grid(anchor=["onset"], on=[-30, -20], pre=[0.0005], len=[0.2, 0.24, 0.27],
                                                fin=[0.0005], fout=[0.6], hp=[200, 300], lp=[9000, 12000])),
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
    if "HitCrit" in keys and any(v["key"] == "HitHeavy" for v in results.values()):
        crit_mixes(results)
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
KO = {"SwingArcher": "활 쏘기 · 두 발 '슉슉'", "SwingArrow": "활 한 발 · 코드가 두 번 틀 때", "SwingMageHalo": "빛 마법 쏘기",
      "SwingMageHorns": "뿔 마법 쏘기", "HitHeavy": "퍽 · 단단한 몬스터 맞힘", "HitCrit": "치명타",
      "Jump": "점프 · 새 소리(사용자 요청)", "PowerUp": "PowerUp · 대장간 첫 무기(A23-68 #3)"}
ORDER = ["SwingArcher", "SwingArrow", "SwingMageHalo", "SwingMageHorns", "HitHeavy", "HitCrit", "Jump", "PowerUp"]
PICK = {  # 소리 만들기 추천 (검수가 고른다)
    "SwingArcher": ("SwingArcher_3-1", "두 발 간격 61 ms, 중심 3.4 kHz(설계표 비평: 4.7 kHz는 1분 240번이면 쉭쉭 거슬림), 줄 소리 없음."),
    "SwingArrow": ("SwingArrow_SwingArcher-3-1", "위 3-1과 같은 화살 한 발(57 ms). 코드가 +0.068 s에 1.10배로 한 번 더 틀면 위와 같은 '슉슉'."),
    "SwingMageHalo": ("SwingMageHalo_SwingMage-3-4", "'슝' 위로 휘는 반짝(4.6 → 6.4 kHz), 0.17 s. 남은 경고는 잡음 정도(flat 0.05)뿐."),
    "SwingMageHorns": ("SwingMageHorns_1-1", "'푸슉-파직' 불꽃 세 번 탁탁, 중심 1.6 kHz, 0.17 s, 낮은 웅 소리 없음."),
    "HitHeavy": ("HitHeavy_3-2", "'퍽' 한 번, 0.10 s, 폰에서 2.6 dB만 줄어요(설계표 3 dB 아래). 남은 경고는 가장 큰 곳 5.5 ms(목표 5)."),
    "HitCrit": ("HitCrit_mix-3-2+2-1", "추천 퍽 3-2 위에 Firefly '쨍'을 얹은 '빡! 캉★' 0.20 s. 퍽과 같은 타격이라 이어 들려요."),
    "Jump": ("Jump_2-2", "통통 '폴-짝' 0.19 s, 폰 -0.8 dB, 낮은 소리 없음."),
    "PowerUp": ("PowerUp_1-2", "0.7 → 2 → 4.9 kHz로 쭉 올라가는 반짝 1.05 s, 끝에 반짝 마무리."),
}


def prompt_for(src):
    """'SwingArcher_3-1' -> its Firefly prompt; mixes -> how they were made"""
    if src.startswith("mix"):
        return ""
    p = os.path.join(ROOT, "art", "prompts", "SFX_" + src.split("-")[0] + ".txt")
    return open(p, encoding="utf-8").read().strip() if os.path.exists(p) else ""


def board():
    import base64
    import html as H
    summ = json.load(open(os.path.join(REVIEW, "summary.json"), encoding="utf-8"))
    results = json.load(open(REPORT, encoding="utf-8"))
    by_cand = {cand_name(k): v for k, v in results.items() if v.get("cand")}
    thumbs = os.path.join(OUT, "thumbs")
    os.makedirs(thumbs, exist_ok=True)
    secs = []
    for key in ORDER:
        rows = summ["keys"].get(key, [])
        if not rows:
            continue
        ks = SPEC["keys"][key]
        rec, why = PICK.get(key, ("", ""))
        tiles = []
        for r in rows:
            name = r["name"]
            v = by_cand.get(name, {})
            wav = os.path.join(FF.CAND, name + ".wav")
            x = FF.read_wav(wav)
            span = 1.4 if key == "PowerUp" else 0.35
            FF.SPAN = span
            jpg = os.path.join(thumbs, name + ".jpg")
            FF.spec_image(x, 430, 140).save(jpg, quality=86)
            FF.SPAN = 0.7
            misses = "".join(f'<li class="l{1 if m["level"] == "warn" else 0}">{H.escape(m["name"])} {m["value"]} (목표 {m["want"]})</li>'
                             for m in r["misses"]) or '<li class="l2">모든 검사 통과</li>'
            src = v.get("source", "")
            pr = prompt_for(src)
            how = ""
            if src.startswith("mix"):
                how = f'<p class="prompt">섞음: {H.escape(src[4:])} (Firefly 두 겹)</p>'
            elif v.get("params", {}).get("tsing"):
                how = '<p class="prompt">+ 우리 합성 “샤랑” 한 겹(아주 얇게)</p>'
            chip = '<span class="pick">추천</span>' if name == rec else ""
            m = r["metrics"]
            tiles.append(
                f'<article class="tile {r["verdict"].lower()}{" rec" if name == rec else ""}">'
                f'<header><code>{H.escape(name)}</code><span class="vd {r["verdict"].lower()}">{r["verdict"]} {r["score"]}</span>{chip}</header>'
                f'<p class="ko">{m["durMs"]:g} ms · 중심 {m["centroidHz"]} Hz · 폰 -{m["phoneDropDb"]:g} dB</p>'
                f'<img class="spec" alt="{H.escape(name)} 스펙트로그램" src="data:image/jpeg;base64,{base64.b64encode(open(jpg, "rb").read()).decode()}">'
                f'<audio controls preload="none" src="data:audio/wav;base64,{base64.b64encode(open(wav, "rb").read()).decode()}"></audio>'
                f'<ul>{misses}</ul>' + (f'<p class="prompt">“{H.escape(pr)}”</p>' if pr else "") + how + '</article>')
        recline = f'<p class="rec-line"><span class="pick">추천</span> <code>{H.escape(rec)}</code> — {H.escape(why)}</p>' if rec else ""
        secs.append(f'<section><h2>{H.escape(KO.get(key, key))} <code class="key">{key}</code></h2>'
                    f'<p class="target">{H.escape(ks.get("say", ""))} · {H.escape(ks.get("moment", ""))}</p>{recline}'
                    f'<div class="grid">{"".join(tiles)}</div></section>')
    page = BOARD_HTML.replace("{{BODY}}", "".join(secs))
    out = os.path.join(FF.WORK, "board_r4b.html")
    with open(out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(page)
    print(out, round(os.path.getsize(out) / 1e6, 2), "MB")


BOARD_HTML = FF.BOARD_HTML.replace(
    "<h1>효과음 4차 듣기판</h1>", "<h1>효과음 4차 듣기판</h1>").replace(
    """<p class="lead">검수용입니다. 종류마다 하나를 골라 주세요. 위 띠 색: 청록 = Firefly 생성, 보라 = 섞은 것, 회색 = 개발 2 3차(비교). 그림은 스펙트로그램(세로 50 Hz–12 kHz, 가로 0–0.7 s)이고 하늘색 점선이 목표 모양이에요.
Firefly 1초 클립을 잘라 48 kHz 모노로 맞췄어요(가장 큰 100 ms = -18 dBFS). 2026-10-07 · Firefly 17번 생성(170크레딧).</p>""",
    """<p class="lead">검수용입니다. 종류마다 하나를 골라 주세요. 판정은 설계표 검사기(tools/sfx_check.py + tools/sfx_spec.json)의 것이에요:
PASS = 먼저 들어 볼 것, WARN = 작은 벗어남만 있음. 불합격은 뺐어요. 그림은 스펙트로그램(세로 50 Hz–12 kHz, 가로 0–0.35 s, PowerUp은 0–1.4 s).
Firefly 원본을 잘라 48 kHz 모노, K 가중 -17 LUFS로 맞췄어요. 2026-10-07 · Firefly 25번 생성(250크레딧).</p>""").replace(
    ".tile.mix{border-top-color:var(--mix)}.tile.dev2{border-top-color:var(--ref)}",
    ".tile.warn{border-top-color:var(--near)}.tile.pass{border-top-color:var(--ok)}"
    ".vd{font-size:.72rem;font-weight:600;border-radius:999px;padding:1px 7px;border:1px solid currentColor}"
    ".vd.pass{color:var(--ok)}.vd.warn{color:var(--near)}code.key{font-size:.8rem;color:var(--muted)}")


def ledger(board_url="", generations=25, balance_before=9640):
    """art/sfx/cand/firefly_r4.json: prompts, Firefly asset ids, credits, the checker verdicts and cuts of the candidates"""
    results = json.load(open(REPORT, encoding="utf-8"))
    assets = json.load(open(os.path.join(FF.WORK, "raw_assets.json"), encoding="utf-8"))
    prompts = {f[4:-4]: open(os.path.join(FF.PROMPTS, f), encoding="utf-8").read().strip()
               for f in sorted(os.listdir(FF.PROMPTS)) if f.startswith("SFX_") and f.endswith(".txt")}
    book = {
        "round": "4b", "date": "2026-10-07", "by": "소리 만들기",
        "made": "Adobe Firefly 'Generate sound effects' (firefly.adobe.com, the user's Adobe account): 1 s (PowerUp 1.5 s), 4 variations per generation",
        "license": "Firefly generation (Adobe: commercially safe output); our edit = cut, mono 48 kHz, high/low-pass, level; "
                   "SwingMageHalo candidates may carry our own thin synthesized 'tsing' (tools/sfx_cut.py tsing())",
        "credits": {"generations": generations, "perGeneration": 10, "used": generations * 10, "balanceBefore": balance_before,
                    "balanceAfter": balance_before - generations * 10},
        "spec": "tools/sfx_spec.json (+ LOCAL rules for Jump / PowerUp in tools/sfx_cut.py)", "checker": "tools/sfx_check.py",
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
