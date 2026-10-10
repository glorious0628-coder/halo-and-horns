"""
Lv5 Q 스킬 6개의 시전·맞음 소리 + 공통 신호 4개 후보 (소리 만들기, 2026-10-10; docs/design/skills18_2026-10-10.md). 직접 합성(크레딧 0).
  Cast<Skill>   스킬을 쓴 순간부터 끝까지 한 파일(0초 = 버튼). 맞는 순간(전사 0.24초·마법사 0.35초·궁수 0.18/0.4초)에 큰 소리가 오도록 안에서 시간을 맞춤
  Hit<Skill>    맞은 몬스터마다 나는 짧은 소리(0.1~0.25초)
  Sig<...>      공통 신호: HealSparkle(빛 치유) · LifeSteal(뿔 흡혈 슈욱) · MpPing(MP 띵) · GuardPop(빛 가드 '뽀옹'; b = 뿔 가드 낮은 '웅')
  빛 = 맑은 종·깃털 바람, 뿔 = 낮은 붕·불씨 탁탁. 비명·짐승 소리 없음. 같은 슬롯 빛·뿔 짝은 크기를 같게(finish 가 같은 -18 dB RMS 로 맞춤).
  py tools/sfx_skillq.py            -> build/sfx_skillq/cand/<Key>_<a|b>.wav
  py tools/sfx_skillq.py sheet OUT.png
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import sfx_game as G  # noqa: E402

SR = G.SR
OUT = os.path.join(G.ROOT, "build", "sfx_skillq", "cand")


def tone(freq, dur, shape="sine", decay=15.0, attack=0.003, bend=0.0):
    n = G.count(dur)
    t = G.secs(n)
    f = freq * (1 + bend * (t / dur))
    return G.osc(f, shape) * np.clip(t / attack, 0, 1) * np.exp(-t * decay)


def nz(dur, lo, hi, decay, seed, attack=0.002):
    r = np.random.default_rng(seed)
    n = G.count(dur)
    t = G.secs(n)
    x = G.svf(G.svf(r.standard_normal(n), lo, 0.707, "hp"), hi, 0.707, "lp")
    return x * np.clip(t / attack, 0, 1) * np.exp(-t * decay)


def bellx(f, d, decay, partials=((1, 1.0, 1.0), (2.0, 0.2, 1.8), (3.0, 0.06, 2.6))):
    return G.bell(f, d, decay=decay, partials=partials)


def air_sweep(dur, f0, f1, seed, level=1.0):
    """a soft band-passed 'whoo' that sweeps f0 -> f1 with a rise-and-fall arc"""
    r = np.random.default_rng(seed)
    n = G.count(dur)
    x = r.standard_normal(n)
    y = np.zeros(n)
    steps = 6
    for k in range(steps):
        a, b = k * n // steps, (k + 1) * n // steps
        fc = f0 * (f1 / f0) ** ((k + 0.5) / steps)
        seg = G.svf(G.svf(x[a:b], fc * 0.6, 0.707, "hp"), fc * 1.6, 0.707, "lp")
        y[a:b] = seg
    return y * (np.sin(np.pi * np.linspace(0, 1, n)) ** 1.4) * level


def crackle(dur, rate, seed, level=1.0, lo=1800, hi=6500):
    r = np.random.default_rng(seed)
    out = np.zeros(G.count(dur) + G.count(0.03))
    t = 0.0
    while t < dur:
        m = G.count(r.uniform(0.003, 0.012))
        tt = G.secs(m)
        click = G.svf(G.svf(r.standard_normal(m), lo, 0.707, "hp"), hi, 0.707, "lp") * np.exp(-tt * r.uniform(250, 700))
        i = int(t * SR)
        out[i:i + m] += click * level * r.uniform(0.3, 1.0)
        t += r.exponential(1.0 / rate)
    return out


M = G.mix


# ------------------------------------------------------------------ 1. Halo Slam (Light warrior Q, contact 0.24 s)
def cast_halo_slam(v):
    clang = M([(nz(0.08, 1500, 6000, 55, 1), 0, 1.0), (bellx(1760 if v == "a" else 1568, 0.5, 8.0, ((1, 1.0, 1.0), (2.76, 0.4, 1.4), (5.4, 0.12, 2.2))), 0, 0.5)])
    ding = bellx(1046.5, 0.8, 5.0) * 0.8  # a clear high C bell
    ring = air_sweep(0.32, 600, 3600, 5, 0.8)
    wind = air_sweep(0.22, 500, 1500, 6, 0.35)
    parts = [(wind, 0.0, 1.0), (clang, 0.24, 1.0), (ding, 0.25, 1.0), (ring, 0.26, 1.0), (G.sparkle(0.4, 8, 3200, 6000, seed=7, level=0.12), 0.34, 1.0)]
    return M(parts)


def hit_halo_slam(v):
    return M([(bellx(1568 if v == "a" else 1397, 0.25, 14.0), 0, 0.8), (G.sparkle(0.12, 3, 3500, 6000, seed=8, level=0.16), 0.02, 1.0)])


# ------------------------------------------------------------------ 2. Crater Smash (Horns warrior Q, contact 0.24 s)
def cast_crater_smash(v):
    heave = air_sweep(0.22, 300, 900, 11, 0.4)
    boom = M([(tone(340 if v == "a" else 300, 0.4, "sine", decay=7, bend=-0.35), 0, 1.0), (tone(680, 0.3, "sine", decay=10, bend=-0.3), 0, 0.9), (tone(1020, 0.2, "sine", decay=14), 0, 0.4),
              (nz(0.22, 600, 3200, 14, 12), 0, 1.0)])
    crumble = M([(nz(0.1, 600, 3000, 22, 13 + k), 0.04 * k, 0.5) for k in range(5)])
    embers = crackle(0.6, 22, 14, 0.5)
    return M([(heave, 0.0, 1.0), (boom, 0.24, 1.0), (crumble, 0.27, 1.0), (embers, 0.3, 1.0)])


def hit_crater_smash(v):
    return M([(tone(520 if v == "a" else 450, 0.15, "sine", decay=24, bend=-0.4), 0, 0.9), (tone(1040, 0.08, "sine", decay=36), 0, 0.4), (nz(0.06, 800, 3000, 50, 15), 0, 0.7),
              (crackle(0.15, 40, 16, 0.5), 0.02, 1.0)])


# ------------------------------------------------------------------ 3. Star Fall (Light mage Q, contact 0.35 s)
def cast_star_fall(v):
    notes = [784, 988, 1175, 1568, 1976] if v == "a" else [880, 1047, 1319, 1760, 2093]
    rise = [(bellx(f, 0.3, 10.0, ((1, 1.0, 1.0), (3.0, 0.15, 2.0))), 0.065 * i, 0.55) for i, f in enumerate(notes)]
    pom = tone(520, 0.2, "sine", decay=16, bend=0.4) * 0.8
    glass = bellx(2093, 0.7, 6.5, ((1, 1.0, 1.0), (2.4, 0.3, 1.6))) * 0.5
    return M(rise + [(pom, 0.35, 1.0), (glass, 0.36, 1.0), (G.sparkle(0.5, 12, 3000, 6200, seed=20, level=0.14), 0.4, 1.0)])


def hit_star_fall(v):
    return M([(bellx(2349 if v == "a" else 2093, 0.3, 12.0), 0, 0.7), (G.sparkle(0.15, 4, 3500, 6200, seed=21, level=0.14), 0.01, 1.0)])


# ------------------------------------------------------------------ 4. Purple Pop (Horns mage Q, contact 0.35 s)
def cast_purple_pop(v):
    parts = []
    t = 0.0
    k = 0
    while t < 0.33:  # bubbling that climbs
        f = 220 + 520 * (t / 0.33)
        parts.append((tone(f, 0.07, "sine", decay=30, bend=0.8), t, 0.45))
        t += 0.075 - 0.04 * (t / 0.33)
        k += 1
    pong = tone(340 if v == "a" else 300, 0.3, "sine", decay=9, bend=1.6) + 0.35 * tone(680, 0.3, "sine", decay=13, bend=1.6)
    hiss = nz(0.14, 3500, 7500, 30, 22) * 0.35
    return M(parts + [(pong, 0.35, 0.95), (hiss, 0.35, 1.0), (crackle(0.35, 26, 23, 0.25), 0.4, 1.0)])


def hit_purple_pop(v):
    return M([(tone(380 if v == "a" else 330, 0.12, "sine", decay=24, bend=1.3), 0, 0.9), (nz(0.05, 3000, 7000, 70, 24), 0.0, 0.2)])


# ------------------------------------------------------------------ 5. Feather Rain (Light archer Q, shot 0.18 s, arrows land from 0.4 s)
def cast_feather_rain(v):
    shot = M([(air_sweep(0.2, 900, 4200, 30, 0.7), 0.0, 1.0), (tone(1760 if v == "a" else 1568, 0.25, "sine", decay=20) * 0.12, 0.17, 1.0)])
    up = air_sweep(0.3, 700, 2600, 31, 0.5)
    rain = crackle(0.8, 18 if v == "a" else 26, 32, 0.6, lo=2400, hi=7500)
    feather = M([(air_sweep(0.35, 1200, 2200, 33 + k, 0.3), 0.0 + 0.07 * k, 1.0) for k in range(4)])
    return M([(shot, 0.0, 1.0), (up, 0.12, 0.8), (rain, 0.4, 1.0), (feather, 0.45, 1.0)])


def hit_feather_rain(v):
    return M([(tone(1175 if v == "a" else 1047, 0.08, "sine", decay=45), 0, 0.7), (air_sweep(0.12, 1400, 2800, 34, 0.35), 0.0, 1.0)])


# ------------------------------------------------------------------ 6. Spark Shower (Horns archer Q, two quick shots, smoke puffs 0.4 s+)
def cast_spark_shower(v):
    shots = [(nz(0.1, 700, 3200, 28, 40 + k) * 0.8, 0.18 + 0.12 * k, 1.0) for k in range(2)]
    low = [(tone(240, 0.1, "sine", decay=30, bend=-0.3) * 0.5, 0.18 + 0.12 * k, 1.0) for k in range(2)]
    puffs = [(M([(nz(0.12, 400, 1800, 24, 50 + k), 0, 1.0), (tone(420 if v == "a" else 380, 0.1, "sine", decay=30, bend=-0.4), 0, 0.5)]), 0.4 + 0.08 * k, 0.8) for k in range(4)]
    embers = crackle(0.6, 20, 55, 0.5)
    return M(shots + low + puffs + [(embers, 0.42, 1.0)])


def hit_spark_shower(v):
    return M([(nz(0.09, 400, 1800, 36, 60), 0, 1.0), (tone(460 if v == "a" else 410, 0.08, "sine", decay=34, bend=-0.4), 0, 0.5), (crackle(0.1, 50, 61, 0.4), 0.02, 1.0)])


# ------------------------------------------------------------------ shared signals
def sig_heal(v):
    notes = [784, 988, 1175, 1568] if v == "a" else [880, 1175, 1397, 1760]
    return M([(bellx(f, 0.22, 12.0, ((1, 1.0, 1.0), (2.0, 0.18, 2.0))), 0.07 * i, 0.55) for i, f in enumerate(notes)]
             + [(G.sparkle(0.3, 6, 3200, 6000, seed=70, level=0.12), 0.1, 1.0)])


def sig_steal(v):
    suck = air_sweep(0.3, 1800 if v == "a" else 1400, 450, 71, 0.9)
    tick = tone(520, 0.08, "sine", decay=40, bend=0.5) * 0.5
    return M([(suck, 0, 1.0), (tick, 0.27, 1.0)])


def sig_mp(v):
    parts = [(tone(500 + 140 * i, 0.06, "sine", decay=34, bend=0.7), 0.05 * i, 0.4) for i in range(4)]
    ping = bellx(1760 if v == "a" else 1568, 0.3, 12.0) * 0.8
    return M(parts + [(ping, 0.2, 1.0)])


def sig_guard(v):
    if v == "a":  # Halo: a glass 'ppo-ong' bubble + a tiny sparkle
        pop = tone(520, 0.14, "sine", decay=14, bend=1.0) + 0.4 * tone(1040, 0.14, "sine", decay=18, bend=1.0)
        return M([(pop, 0, 0.9), (bellx(1760, 0.4, 9.0), 0.1, 0.4), (G.sparkle(0.2, 4, 3500, 6000, seed=72, level=0.12), 0.12, 1.0)])
    base = tone(400, 0.3, "sine", decay=9, bend=0.2) + 0.8 * tone(800, 0.3, "sine", decay=11, bend=0.2)  # Horns: a low round 'wung'
    return M([(base, 0, 0.9), (nz(0.06, 400, 1500, 50, 73), 0, 0.3)])


KINDS = {
    "CastHaloSlam": cast_halo_slam, "HitHaloSlam": hit_halo_slam,
    "CastCraterSmash": cast_crater_smash, "HitCraterSmash": hit_crater_smash,
    "CastStarFall": cast_star_fall, "HitStarFall": hit_star_fall,
    "CastPurplePop": cast_purple_pop, "HitPurplePop": hit_purple_pop,
    "CastFeatherRain": cast_feather_rain, "HitFeatherRain": hit_feather_rain,
    "CastSparkShower": cast_spark_shower, "HitSparkShower": hit_spark_shower,
    "SigHealSparkle": sig_heal, "SigLifeSteal": sig_steal, "SigMpPing": sig_mp, "SigGuardPop": sig_guard,
}
MAKERS = {}
for _k, _fn in KINDS.items():
    for _v in ("a", "b"):
        MAKERS["%s_%s" % (_k, _v)] = (lambda fn=_fn, v=_v: fn(v))


def render(fn):
    return G.finish(fn(), hp=150.0)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in MAKERS.items():
        x = render(fn)
        G.write_wav(os.path.join(OUT, name + ".wav"), x)
        m = G.metrics(x)
        print(name, m["sec"], "s centroid", m["centroidHz"], "phoneDrop", m["phoneDropDb"], "peak", m["peakDb"])


def sheet(path):
    from PIL import Image, ImageDraw
    from scipy.signal import spectrogram
    names = list(MAKERS)
    W, H = 600, 96
    cols = 2
    rows = (len(names) + cols - 1) // cols
    img = Image.new("RGB", (W * cols, H * rows), (250, 250, 250))
    d = ImageDraw.Draw(img)
    for i, name in enumerate(names):
        x = render(MAKERS[name])
        m = G.metrics(x)
        cx, cy = (i % cols) * W, (i // cols) * H
        d.text((cx + 6, cy + 2), "%s %.2fs c%dHz phone-%sdB" % (name, len(x) / SR, m["centroidHz"], m["phoneDropDb"]), fill=(0, 0, 0))
        hop = max(1, len(x) // (W // 2 - 14))
        n = len(x) // hop
        env_ = np.abs(x[:n * hop]).reshape(n, hop).max(axis=1)
        for k, v in enumerate(env_):
            px = cx + 6 + int(k / n * (W // 2 - 14))
            hh = int(v * (H / 2 - 14))
            d.line([(px, cy + H // 2 + 8 - hh), (px, cy + H // 2 + 8 + hh)], fill=(60, 90, 200))
        f, t, S = spectrogram(x, fs=SR, nperseg=512, noverlap=450)
        S = np.clip((10 * np.log10(S[:100] + 1e-13) + 110) / 60, 0, 1)
        im = Image.fromarray((255 - S[::-1] * 255).astype(np.uint8)).resize((W // 2 - 10, H - 18)).convert("RGB")
        img.paste(im, (cx + W // 2 + 4, cy + 16))
    img.save(path)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "sheet":
        sheet(sys.argv[2] if len(sys.argv) > 2 else os.path.join(G.ROOT, "build", "sfx_skillq", "sheet.png"))
    else:
        main()
