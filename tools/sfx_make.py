"""
Firefly가 못 만드는 소리를 Kenney CC0 + 우리 합성으로 만들기 (소리 만들기, 2026-10-07; A23-67 순서: Firefly → Kenney → 합성).
  py tools/sfx_make.py [Key ...]   RECIPES의 후보를 build/sfx_firefly/r4b/<Key>__<이름>.wav로 만들고 설계표 검사기로 재서
                                    build/sfx_firefly/r4b/r4b.json에 더한다(그다음 sfx_cut.py pick이 다른 후보와 함께 고른다)
재료: build/devlog/sfx/{impact,interface}/Audio (Kenney Impact / Interface Sounds, CC0). 사용자가 좋아했던 파일은 복사하지 않고
'좋아한 방향'(설계서 §1-1)만 따라 다른 재료·다른 값으로 새로 만든다.
"""

import json
import os
import sys

import numpy as np

import sfx_check as SC
import sfx_cut as CUT
import sfx_firefly as FF

SR = FF.SR
OUT = CUT.OUT


def secs(n):
    return np.arange(n) / SR


def env(n, attack=0.003, decay=10.0):
    t = secs(n)
    return np.minimum(t / max(attack, 1e-6), 1.0) * np.exp(-decay * np.maximum(t - attack, 0))


def glide(n, f0, f1, curve=1.0):
    u = np.linspace(0, 1, n) ** curve
    return f0 * (f1 / f0) ** u


def osc(freq):
    return np.sin(2 * np.pi * np.cumsum(freq) / SR)


def svf_bp(x, fc, q):
    """time-varying band-pass (TPT state-variable filter); fc may be an array"""
    fc = np.broadcast_to(np.clip(np.asarray(fc, dtype=np.float64), 20, SR * 0.45), x.shape)
    g = np.tan(np.pi * fc / SR)
    k = 1.0 / q
    ic1 = ic2 = 0.0
    y = np.empty_like(x)
    for i in range(len(x)):
        a1 = 1.0 / (1.0 + g[i] * (g[i] + k))
        v3 = x[i] - ic2
        v1 = a1 * ic1 + g[i] * a1 * v3
        v2 = ic2 + g[i] * v1
        ic1, ic2 = 2 * v1 - ic1, 2 * v2 - ic2
        y[i] = v1
    return y


def drive(x, k=3.0):
    pk = max(1e-9, np.abs(x).max())
    return np.tanh(k * x / pk) / np.tanh(k)


def kenney(name, speed=1.0):
    pack, base = name.split("/")
    x = FF.decode(os.path.join(FF.KENNEY, pack, "Audio", base + ".ogg"))
    return SC.respeed(x, speed) if abs(speed - 1) > 1e-6 else x


def fade(x, seconds, depth=5.0):
    n = min(len(x), FF.count(seconds))
    y = x[:n].copy()
    y *= np.exp(-np.arange(n) / max(1, n) * depth)
    return y


def at(parts, total=None):
    n = total or max(FF.count(t) + len(x) for x, t, _ in parts)
    out = np.zeros(n)
    for x, t, g in parts:
        s = FF.count(t) if t > 0 else 0
        m = min(len(x), n - s)
        out[s:s + m] += x[:m] * g
    return out


def blob(seed, f0=1500, f1=420, s0=260, s1=170, wob=20.0, dur=0.16):
    """the jelly blob (liked direction, new values): noise through a falling resonance + a soft wobbling low sine"""
    n = FF.count(dur)
    t = secs(n)
    wet = svf_bp(np.random.default_rng(seed).standard_normal(n), glide(n, f0, f1, 2.0), 3.5) * env(n, 0.002, 22)
    wet /= max(1e-9, np.abs(wet).max())
    low = osc(glide(n, s0, s1) * (1 + 0.08 * np.sin(2 * np.pi * wob * t))) * env(n, 0.004, 20)
    return at([(wet, 0, 0.8), (low, 0, 0.6)])


def coin(sample, speed1, speed2, gap, ring1=0.07, ring2=0.28, g1=0.8):
    """'짤-랑': the same money sample twice, the second a little higher (sound_spec §1-2 ComboCoin)"""
    c1 = fade(kenney(sample, speed1), ring1)
    c2 = fade(kenney(sample, speed2), ring2, 3.0)
    return at([(c1, 0, g1), (c2, gap, 1.0)])


def finish(x, hp=150, lp=0):
    y = FF.highpass(x - np.mean(x), hp, 2)
    if lp:
        y = FF.lowpass(y, lp, 2)
    a = np.abs(y)
    on = np.nonzero(a > a.max() * 10 ** (-50 / 20))[0]
    y = y[max(0, on[0] - FF.count(0.0005)):on[-1] + FF.count(0.005)]
    fo = min(FF.count(0.02), len(y) // 3)
    y[-fo:] *= np.linspace(1, 0, fo)
    return CUT.level(y)


def pang(seed, f=2500.0, dur=0.012):
    """a 10 ms 'pang': a band-passed noise burst 1.5-4 kHz with an instant start"""
    n = FF.count(dur)
    x = svf_bp(np.random.default_rng(seed).standard_normal(n), f, 1.0) * env(n, 0.0004, 220)
    return x / max(1e-9, np.abs(x).max())


def stars(seed, n_grains=8, f0=7000.0, f1=3000.0, span=0.2, gdur=0.03):
    """little star grains falling 7 -> 3 kHz (each a short decaying sine with a small inharmonic partial)"""
    rng = np.random.default_rng(seed)
    total = FF.count(span + gdur)
    out = np.zeros(total)
    for i in range(n_grains):
        u = i / max(1, n_grains - 1)
        t0 = u * span + rng.uniform(-0.008, 0.008)
        f = f0 * (f1 / f0) ** u * rng.uniform(0.94, 1.06)
        n = FF.count(gdur)
        g = (osc(np.full(n, f)) + 0.3 * osc(np.full(n, f * 2.76))) * env(n, 0.001, 90) * (1 - 0.6 * u)
        s = max(0, FF.count(t0))
        m = min(n, total - s)
        out[s:s + m] += g[:m]
    return out / max(1e-9, np.abs(out).max())


def jing(dur=0.06):
    n = FF.count(dur)
    return osc(glide(n, 1200, 2400, 0.7)) * env(n, 0.003, 30)


RECIPES = {
    "HitCrit": {
        "sB": ("B (no metal), our synthesis: 12 ms 'pang' 2.5 kHz + 8 star grains falling 7 -> 3 kHz + 'jing' 1.2 -> 2.4 kHz at -10 dB",
               lambda: finish(at([(pang(61), 0, 1.0), (stars(62), 0.008, 0.55), (jing(), 0.004, 0.32)]), 300, 7500)),
        "sB2": ("B (no metal), our 'pang' + Firefly HitCrit_6-1 star tail low-passed 6 kHz",
                lambda: finish(at([(pang(63, 2200), 0, 1.0),
                                   (FF.lowpass(FF.read_wav(os.path.join(FF.RAW, "HitCrit_6-1.wav"))[FF.count(0.02):FF.count(0.26)], 6000, 4), 0.006, 0.6),
                                   (jing(), 0.004, 0.25)]), 300, 7500)),
        "sB3": ("B (no metal), our synthesis, a wider pang 1.8 kHz + 10 star grains 6.5 -> 2.8 kHz",
                lambda: finish(at([(pang(65, 1800, 0.014), 0, 1.0), (stars(66, 10, 6500, 2800, 0.19), 0.006, 0.6), (jing(0.05), 0.003, 0.3)]), 300, 7500)),
    },
    "ComboCoin": {
        "kA": ("Kenney impactMetal_light_000 0.891x (D7) 70 ms x0.8 + 1.0x @45 ms 200 ms (sound_spec recipe)",
               lambda: finish(coin("impact/impactMetal_light_000", 0.891, 1.0, 0.045))),
        "kB": ("same money sample, coins 50 ms apart, softer first coin, 230 ms ring",
               lambda: finish(coin("impact/impactMetal_light_000", 0.891, 1.0, 0.050, 0.06, 0.26, 0.7))),
        "kC": ("money sample a whole tone lower pair (0.84x -> 0.94x), 50 ms apart",
               lambda: finish(coin("impact/impactMetal_light_000", 0.84, 0.94, 0.050))),
    },
    "HitSoft": {
        "kA": ("Kenney impactSoft_medium_002 saturated (HP 220) + jelly blob (1500->420 Hz, 320->220 Hz, 20 Hz wobble) + soft 'po'",
               lambda: finish(at([(drive(FF.highpass(kenney("impact/impactSoft_medium_002"), 220, 2), 4.0), 0, 0.7),
                                  (blob(41, 1500, 420, 320, 220), 0, 0.7),
                                  (osc(glide(FF.count(0.08), 600, 540)) * env(FF.count(0.08), 0.002, 35), 0.003, 0.35)]), 180)),
        "kB": ("Kenney impactSoft_medium_004 saturated + a brighter blob (1700->450 Hz, 280->180 Hz) + a soft 550 Hz 'po' for phones",
               lambda: finish(at([(drive(FF.highpass(kenney("impact/impactSoft_medium_004"), 220, 2), 4.0), 0, 0.7),
                                  (blob(43, 1700, 450, 340, 230, 24.0), 0, 0.7),
                                  (osc(glide(FF.count(0.08), 560, 500)) * env(FF.count(0.08), 0.002, 30), 0.0, 0.4)]), 180)),
        "kC": ("Firefly HitSoft_2-3 (cut) + a low jelly blob",
               lambda: finish(at([(FF.read_wav(os.path.join(OUT, "HitSoft__HitSoft_2-3.wav")), 0, 0.8),
                                  (blob(47, 1300, 380, 240, 160, 18.0, 0.15), 0, 0.6)]), 150, 4000)),
    },
}


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    import sfx_recipes  # the sound_spec synthesis recipes (it imports helpers from this file)
    allr = {k: dict(v) for k, v in RECIPES.items()}
    for k, v in sfx_recipes.RECIPES.items():
        allr.setdefault(k, {}).update(v)
    keys = sys.argv[1:] or list(allr)
    report = json.load(open(CUT.REPORT, encoding="utf-8")) if os.path.exists(CUT.REPORT) else {}
    for key in keys:
        for name, (note, make) in allr[key].items():
            y = make()
            v, s, checks, m = CUT.judge(key, y)
            out = f"{key}__{key}_{name}"
            FF.write_wav(os.path.join(OUT, out + ".wav"), y)
            report[out] = {"key": key, "source": f"{key}_{name}", "verdict": v, "score": s, "params": {"recipe": note},
                           "misses": [c for c in checks if c["level"] != "ok"], "durMs": m.get("durMs"),
                           "centroidHz": m.get("centroidHz"), "phoneDropDb": m.get("phoneDropDb")}
            print(f"{key:10s} {name} {v:4s} {s:3d}", ", ".join(f"{c['name']}={c['value']}" for c in checks if c["level"] != "ok")[:170])
    with open(CUT.REPORT, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(report, fh, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
