"""
설계서 '합성 방법' 칸을 코드로 (소리 만들기, 2026-10-07): Firefly가 음높이·리듬 규칙을 못 맞추는 소리의 우리 합성 + Kenney 레시피.
tools/sfx_make.py가 RECIPES로 불러 쓴다(빌드·검사·r4b.json 기록은 그쪽). 출처: docs/design/sound_spec_2026-10-07.md §1 각 줄.
"""

import numpy as np

import sfx_check as SC
import sfx_firefly as FF
from sfx_make import at, drive, env, finish, glide, kenney, osc, secs, svf_bp

SR = FF.SR
N = FF.count


def note_hz(name):
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    return 440.0 * 2 ** ((names[name[0]] + 12 * (int(name[1:]) - 4)) / 12)


def bell(f, dur, decay=6.0, partials=((1.0, 1.0, 1.0), (2.0, 0.35, 1.6), (2.76, 0.18, 2.2), (5.4, 0.06, 3.5))):
    """a struck bell / glass: decaying sine partials (ratio, level, decay multiplier)"""
    n = N(dur)
    t = secs(n)
    out = np.zeros(n)
    for r, a, dm in partials:
        if f * r < SR * 0.45:
            out += a * np.sin(2 * np.pi * f * r * t) * np.exp(-decay * dm * t)
    att = np.minimum(t / 0.0015, 1.0)
    return out * att / max(1e-9, np.abs(out).max())


def marimba(f, dur=0.3, decay=18.0):
    n = N(dur)
    t = secs(n)
    x = (np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * 3.9 * f * t) * np.exp(-30 * t)) * env(n, 0.005, decay)
    return x / max(1e-9, np.abs(x).max())


def tri(freq):
    ph = np.cumsum(freq) / SR
    return 2 * np.abs(2 * (ph - np.floor(ph + 0.5))) - 1


def pulse(freq, duty=0.3):
    ph = np.cumsum(freq) / SR
    return np.where((ph % 1.0) < duty, 1.0, -1.0)


def noise(n, seed):
    return np.random.default_rng(seed).standard_normal(n)


def band(n, f, q, seed):
    x = svf_bp(noise(n, seed), f, q)
    return x / max(1e-9, np.abs(x).max())


def sparkle(dur, grains, lo, hi, level, seed, gdur=0.03):
    rng = np.random.default_rng(seed)
    total = N(dur + gdur)
    out = np.zeros(total)
    for i in range(grains):
        t0 = rng.uniform(0, dur)
        f = rng.uniform(lo, hi)
        g = bell(f, gdur, 60.0, ((1.0, 1.0, 1.0), (2.76, 0.3, 1.5)))
        s = N(t0)
        m = min(len(g), total - s)
        out[s:s + m] += g[:m] * rng.uniform(0.5, 1.0)
    return out / max(1e-9, np.abs(out).max()) * level


def coin(f, dur=0.2):
    """a coin: bell with non-integer partials + a 3 ms click at -12 dB"""
    c = bell(f, dur, 14.0, ((1.0, 1.0, 1.0), (2.41, 0.35, 1.4), (3.83, 0.15, 2.0)))
    click = band(N(0.003), 5000, 1.0, int(f)) * 10 ** (-12 / 20)
    return at([(c, 0, 1.0), (click, 0, 1.0)])


# ---------------------------------------------------------------- batch 2
def gold(order, gap=0.055):
    return finish(at([(coin(note_hz(n)), i * gap, 1.0 - 0.1 * i) for i, n in enumerate(order)]), 400)


def gold_kenney():
    parts = [(kenney("impact/impactMetal_light_001"), 0.0, 0.9), (kenney("impact/impactMetal_light_000"), 0.055, 1.0),
             (kenney("impact/impactMetal_light_004"), 0.11, 0.9)]
    return finish(at([(FF.lowpass(p[0][:N(0.22)], 9000, 2) * np.exp(-np.arange(N(0.22)) / N(0.22) * 3)[:len(p[0][:N(0.22)])], p[1], p[2]) for p in parts]), 400)


def paper(seed, t=0.0):
    n = N(0.035)
    x = band(n, 3500, 0.8, seed) * env(n, 0.002, 90)
    return (x, t, 1.0)


def quest_new(c="C6", g="G6"):
    f1, f2 = note_hz(c), note_hz(g)
    return finish(at([(paper(5)[0], 0.0, 1.4), (paper(6)[0], 0.03, 1.26), (marimba(f1, 0.24, 12), 0.0, 1.0), (marimba(f2, 0.3, 10), 0.07, 0.95)]), 300)


def quest_done(notes=("E6", "G6", "C7"), gap=0.065):
    parts = [(bell(note_hz(notes[0]), 0.22, 10), 0.0, 1.0), (bell(note_hz(notes[1]), 0.22, 10), gap, 0.8),
             (bell(note_hz(notes[2]), 0.45, 5), 2 * gap, 0.75)]
    body = tri(np.full(N(0.4), note_hz("C6"))) * env(N(0.4), 0.004, 7) * 0.2
    parts += [(body, 2 * gap, 1.0), (sparkle(0.15, 3, 3000, 5000, 0.12, 9), 2 * gap + 0.05, 1.0)]
    return finish(at(parts), 300)


def window_close_kenney():
    x = kenney("interface/minimize_009")
    pk = int(np.argmax(np.abs(x)))
    x = x[max(0, pk - N(0.004)):]  # start near the loudest point: loud at the START
    n = min(len(x), N(0.17))
    x = x[:n] * np.exp(-16 * secs(n))
    x[:N(0.004)] *= np.linspace(0, 1, N(0.004))
    return finish(x, 300)


def window_close_synth():
    n = N(0.16)
    x = osc(glide(n, 1550, 1000, 0.8)) * env(n, 0.004, 16) + 0.3 * osc(glide(n, 3100, 2000, 0.8)) * env(n, 0.004, 22)
    return finish(x, 300)


def deny_note(f, d):
    n = N(d)
    fr = np.linspace(f, f * 0.97, n)
    raw = pulse(fr, 0.3)
    bp = svf_bp(raw, 1000, 2.0)
    nasal = 0.75 * osc(fr) + 0.25 * bp / max(1e-9, np.abs(bp).max())
    tail = np.ones(n)
    k = N(0.012)
    tail[-k:] = np.cos(np.linspace(0, np.pi / 2, k)) ** 2  # no click at the note end (it read as a 3rd onset)
    return FF.lowpass(nasal * env(n, 0.004, 12) * tail, 2000, 2)


def deny(f1=622.0, f2=523.0):
    return finish(at([(deny_note(f1, 0.075), 0.0, 1.0), (deny_note(f2, 0.12), 0.105, 1.0)]), 300)


def rank_down(notes=("E5", "D5", "C5"), gap=0.055):
    parts = [(marimba(note_hz(n), 0.22, 18), i * gap, 10 ** (-1.5 * i / 20)) for i, n in enumerate(notes)]
    return finish(FF.lowpass(at(parts), 4000, 2), 400)


def scroll_fail():
    n = N(0.22)
    puff = FF.lowpass(svf_bp(noise(n, 21), glide(n, 3500, 900, 1.0), 1.2), 6000, 4)
    puff = puff / max(1e-9, np.abs(puff).max()) * np.minimum(secs(n) / 0.012, 1) * np.exp(-6 * secs(n))
    m = N(0.12)
    plop = (osc(glide(m, 659, 523, 0.6)) + 0.3 * osc(glide(m, 1318, 1046, 0.6))) * env(m, 0.003, 22)
    spark = at([(bell(2400, 0.03, 60), 0.0, 1.0), (bell(2800, 0.03, 60), 0.05, 0.8)])
    return finish(at([(puff, 0, 1.0), (plop, 0.10, 0.4), (spark, 0.2, 0.1)]), 300)


def skill_halo(seed=31):
    n = N(0.2)
    wind = svf_bp(noise(n, seed), glide(n, 1200, 5000, 1.0), 1.4)
    wind = wind / max(1e-9, np.abs(wind).max()) * np.sin(np.pi * np.linspace(0, 1, n)) ** 1.5
    rng = np.random.default_rng(seed)
    chimes = [(bell(rng.uniform(1200, 2000), 0.25, 9, ((1.0, 1.0, 1.0), (2.76, 0.3, 1.6))), rng.uniform(0.04, 0.2), 0.22) for _ in range(5)]
    return finish(FF.lowpass(at([(wind, 0, 1.0), *chimes, (sparkle(0.22, 12, 3500, 7000, 0.6, seed + 1), 0.08, 1.0)]), 9000, 2), 800)


def skill_horns(seed=41):
    n = N(0.22)
    fire = np.tanh(2.0 * svf_bp(noise(n, seed), np.concatenate([glide(n // 2, 400, 1200), glide(n - n // 2, 1200, 600)]), 1.6))
    fire = fire / max(1e-9, np.abs(fire).max()) * np.sin(np.pi * np.linspace(0, 1, n) ** 0.6)  # peaks at ~70 ms
    m = N(0.11)
    bwomp = osc(glide(m, 440, 260)) * env(m, 0.005, 20)
    crack = sparkle(0.2, 10, 1800, 4200, 0.3, seed + 2, 0.01)
    tok1 = kenney("impact/impactWood_light_000", 1.6)
    tok2 = kenney("impact/impactWood_light_000", 1.35)
    return finish(at([(fire, 0, 0.8), (crack, 0.03, 1.0), (bwomp, 0.02, 0.5), (tok1, 0.2, 0.5), (tok2, 0.26, 0.45)]), 250)


def purify(seed=51):
    rng = np.random.default_rng(seed)
    scale = [note_hz(n) for n in ("C6", "D6", "E6", "G6", "A6", "C7")]
    chimes = [(bell(f, 0.5, 6), t, 0.32) for f, t in zip(rng.permutation(np.sort(scale)), np.sort(rng.uniform(0, 0.25, 6)))]
    n = N(0.45)
    air = svf_bp(noise(n, seed + 1), glide(n, 1500, 6000), 1.0)
    air = air / max(1e-9, np.abs(air).max()) * np.sin(np.pi * np.linspace(0, 1, n)) ** 0.7 * 0.5
    m = N(0.7)
    pad = sum(osc(np.full(m, note_hz(x) * 2 ** (c / 1200))) for x, c in (("C6", -3), ("E6", 2), ("G6", 3))) * env(m, 0.08, 3.0) * 0.08
    return finish(at([*chimes, (air, 0.0, 1.0), (pad, 0.22, 1.0), (sparkle(0.7, 18, 4000, 8000, 0.45, seed + 2), 0.2, 1.0)]), 300)


def crunch(seed, span=0.12, k=6):
    """the 'am' bite: short bright grains, the first one at t = 0 and the loudest (instant attack, bright start)"""
    rng = np.random.default_rng(seed)
    ts = np.concatenate([[0.0], np.sort(rng.uniform(0.015, span, k - 1))])
    return at([(bell(rng.uniform(2200, 5500), 0.014, 120.0, ((1.0, 1.0, 1.0), (1.7, 0.6, 1.2), (2.9, 0.4, 1.6))), t,
                 1.0 if i == 0 else rng.uniform(0.35, 0.7)) for i, t in enumerate(ts)])


def devour(seed=61):
    n = N(0.06)
    glk1 = osc(glide(n, 720, 480)) * env(n, 0.004, 25)
    glk2 = osc(glide(n, 600, 400)) * env(n, 0.004, 25)
    m = N(0.09)
    pop = osc(glide(m, 900, 1800, 0.7)) * env(m, 0.003, 18)
    crackles = sparkle(0.2, 6, 2500, 5500, 0.35, seed + 3, 0.012)
    # bright bite -> low gulps (middle) -> pop + ember crackles going up (a happy ending: centDir down-up)
    return finish(at([(crunch(seed), 0, 1.0), (glk1, 0.17, 0.5), (glk2, 0.27, 0.5), (pop, 0.40, 0.55), (crackles, 0.48, 0.6)]), 300)


def potion(seed=71):
    n = N(0.025)
    cork = osc(glide(n, 1400, 500)) * env(n, 0.001, 60)
    click = band(N(0.003), 4000, 1.0, seed) * 0.3
    rng = np.random.default_rng(seed)
    bubbles = []
    for i in range(7):
        f = (700 * (1800 / 700) ** (i / 6)) * rng.uniform(0.92, 1.08)
        m = N(0.04)
        bubbles.append((osc(glide(m, f, f * 1.25)) * env(m, 0.002, 45), 0.06 + i * 0.045, 0.6))
    return finish(at([(cork, 0, 1.0), (click, 0, 1.0), *bubbles]), 450)


def auto_on(f0=800.0, f1=2200.0, beep=2349.0, bl=0.11, bd=18.0):
    """latch + a bright motor going up + a high triangle beep: ON ends high and bright (OFF ends low and dry)"""
    latch = kenney("interface/switch_002")
    n = N(0.09)
    saw = FF.lowpass(np.tanh(3 * osc(glide(n, f0, f1))), 6000, 2) * env(n, 0.005, 8) * 10 ** (-6 / 20)
    m = N(bl)
    b = tri(np.full(m, beep)) * env(m, 0.003, bd)
    return finish(at([(latch, 0, 0.8), (saw, 0.03, 1.0), (b, 0.13, 0.9)]), 300)


def auto_off():
    latch = kenney("interface/switch_002")
    n = N(0.1)
    motor = FF.lowpass(np.tanh(3 * osc(glide(n, 1300, 420))), 1500, 2) * env(n, 0.005, 10) * 10 ** (-6 / 20)
    m = N(0.05)
    tok = (osc(np.full(m, 523.0)) + 0.2 * osc(np.full(m, 1569.0))) * env(m, 0.002, 55)
    return finish(at([(latch, 0, 0.8), (motor, 0.025, 1.0), (tok, 0.13, 0.9)]), 300)


def talk_blip(f0=620.0, f1=595.0):
    n = N(0.034)
    x = tri(np.linspace(f0, f1, n)) * env(n, 0.002, 95)
    return finish(FF.lowpass(x, 3000, 2), 300)


def equip(seed=81):
    clicks = [(band(N(0.004), 3000, 1.2, seed + i) * env(N(0.004), 0.0005, 400), i * 0.025, 1.0 - 0.15 * i) for i in range(3)]
    latch = FF.highpass(kenney("interface/switch_002", 0.9), 300, 2)
    latch = latch / max(1e-9, np.abs(latch).max())
    return finish(at([*clicks, (latch, 0.08, 0.45), (sparkle(0.16, 6, 3000, 6000, 0.3, seed + 5), 0.11, 1.0)]), 300)


def skill_ready(f0=1400.0, f1=1600.0):
    n = N(0.05)
    return finish(osc(glide(n, f0, f1)) * env(n, 0.003, 50), 300)


def hurt_big(seed=91):
    n = N(0.15)
    bump = svf_bp(noise(n, seed), glide(n, 600, 300), 1.2)
    bump = bump / max(1e-9, np.abs(bump).max()) * env(n, 0.0008, 22)
    m = N(0.08)
    chirp = osc(glide(m, 1100, 600)) * env(m, 0.003, 30)
    return finish(FF.lowpass(at([(drive(bump, 2.0), 0, 1.0), (chirp, 0.01, 0.35)]), 2500, 2), 250)


# ---------------------------------------------------------------- batch 3 (Halloween P0)
def harm(fr, top=7000.0):
    """band-limited saw: harmonics 1/k up to `top` Hz"""
    ph = 2 * np.pi * np.cumsum(fr) / SR
    out = np.zeros(len(fr))
    for k in range(1, 16):
        out += (k * fr < top).astype(float) * np.sin(k * ph) / k
    return out


def honk_toy(f=600.0, dur=0.16, seed=101, att=0.009):
    """ONE toy rubber honk: a 20 ms rising rubber squeak into a nasal body (formants 1.0 / 1.8 / 2.8 kHz) + 10 % breath;
    up, then a little down at the very end (one note, not the falling two-note 'uh-uh' of Deny)"""
    n = N(dur)
    k = N(0.02)
    fr = np.full(n, f * 1.03)
    fr[:k] = np.linspace(f * 0.93, f * 1.03, k)
    j = int(n * 0.65)
    fr[j:] = np.linspace(f * 1.03, f * 0.99, n - j)
    src = harm(fr)
    body = svf_bp(src, 1000, 4.0) + 0.7 * svf_bp(src, 1800, 5.0) + 0.4 * svf_bp(src, 2800, 6.0) + 0.25 * src
    body /= max(1e-9, np.abs(body).max())
    t = secs(n)
    e = np.minimum(t / att, 1.0) * np.where(t > dur - 0.035, np.cos(np.clip((t - (dur - 0.035)) / 0.035, 0, 1) * np.pi / 2) ** 2, 1.0)
    return (body + 0.1 * band(n, 2000, 0.7, seed)) * e


def king_bells():
    """the shared king bell, twice @0 / 150 ms (Kenney impactBell_heavy_003 2.0x = 650 Hz, HP 380 so phones keep it)"""
    b = kenney("impact/impactBell_heavy_003", 2.0)
    n = min(len(b), N(0.55))
    b = FF.highpass(b[:n] * np.exp(-secs(n) * 2.5), 380, 4)
    return at([(b, 0.0, 1.0), (b, 0.15, 0.85)])


def pumpkin_king(seed=111, nc=34, wood_hp=400, wood_g=0.5, tok_g=0.35):
    """bells -> @330 ms hollow 'bonk' (Kenney wood 1.3x driven + our 445 Hz 'tok') -> 34 candy clicks falling in pitch + sparkle"""
    rng = np.random.default_rng(seed)
    wood = drive(FF.highpass(kenney("impact/impactWood_medium_002", 1.3), 150, 2), 2.5)
    wood = FF.highpass(wood[:N(0.25)], wood_hp, 2)
    m = N(0.09)
    tok = osc(glide(m, 445, 425)) * env(m, 0.002, 30)
    glass = kenney("impact/impactGlass_light_003", 2.4)[:N(0.025)]
    glass = glass * np.linspace(1, 0, len(glass)) ** 2
    candy = []
    for t0 in 0.40 + (np.arange(nc) + rng.uniform(-0.3, 0.3, nc)) * (0.84 / nc):  # evenly spread: no hole in the 'sa-reu-reu'
        u = (t0 - 0.40) / 0.84
        g = SC.respeed(glass, 0.55 ** u) if u > 0.002 else glass
        candy.append((g, t0, rng.uniform(0.3, 0.5) * (1 - 0.45 * u)))
    parts = [(king_bells(), 0, 1.0), (wood, 0.33, wood_g), (tok, 0.33, tok_g), *candy, (sparkle(0.25, 8, 3000, 6000, 0.3, seed + 1), 0.62, 1.0)]
    return finish(at(parts), 150)


def ghost_king(seed=121, wl=0.7):
    """the same bells -> @300 ms a breathy rising 'whoo?' (50 % breath BP 700 + 50 % tone 620 -> 740 Hz, +-15 cent, LP 2 k,
    60 ms attack) -> @650 ms glass (Kenney impactGlass_medium_001) + sparkles"""
    n = N(wl)
    t = secs(n)
    fr = glide(n, 620, 740, 1.0) * 2 ** (15 / 1200 * np.sin(2 * np.pi * 5.5 * t))
    tone = 0.5 * (osc(fr) + 0.6 * harm(fr, 2000))
    breath = svf_bp(noise(n, seed), 700, 1.5)
    whoo = FF.lowpass(0.5 * tone / max(1e-9, np.abs(tone).max()) + 0.5 * breath / max(1e-9, np.abs(breath).max()), 2000, 2)
    whoo *= np.minimum(t / 0.06, 1.0) * np.where(t > wl - 0.18, np.cos(np.clip((t - (wl - 0.18)) / 0.18, 0, 1) * np.pi / 2) ** 2, 1.0)
    glass = kenney("impact/impactGlass_medium_001")
    gn = min(len(glass), N(0.7))
    glass = glass[:gn] * np.exp(-secs(gn) * 4)
    mix = at([(king_bells(), 0, 1.0), (whoo, 0.30, 0.7), (glass, 0.65, 0.6), (sparkle(0.65, 12, 3000, 7000, 0.3, seed + 1), 0.70, 1.0)])
    return finish(FF.highpass(mix, 380, 4), 150)


def flap(speed=1.6):
    x = FF.highpass(kenney("impact/footstep_grass_001", speed), 400, 2)
    return x / max(1e-9, np.abs(x).max())


def goose_arrive(seed=131, f1=560.0, f2=665.0):
    """3 wing flaps (Kenney footstep_grass_001 1.6-1.8x, HP 400) -> honk @250 ms + honk 3 semitones up @470 ms -> gold sparkle"""
    g = kenney("interface/glass_002")
    g = g / max(1e-9, np.abs(g).max())
    return finish(at([(flap(1.6), 0.0, 0.8), (flap(1.7), 0.08, 0.7), (flap(1.8), 0.16, 0.65),
                      (honk_toy(f1, seed=seed), 0.25, 1.0), (honk_toy(f2, seed=seed + 1), 0.47, 1.0),
                      (g, 0.64, 0.4), (sparkle(0.3, 6, 3000, 7000, 0.3, seed + 2), 0.66, 1.0)]), 150)


# ---------------------------------------------------------------- batch 4 (P1 crown / king / war, P2, then the rest)
def norm(x):
    return x / max(1e-9, np.abs(x).max())


def fade_out(x, sec):
    k = min(len(x), N(sec))
    y = x.copy()
    y[-k:] *= np.cos(np.linspace(0, np.pi / 2, k)) ** 2
    return y


def rate_sparkle(dur, r0, r1, lo, hi, seed, gdur=0.03, level=1.0):
    """sparkle grains whose rate goes r0 -> r1 per second (r1 > r0 = a swell) and that get louder as they go"""
    rng = np.random.default_rng(seed)
    total = N(dur + gdur)
    out = np.zeros(total)
    t = 0.0
    while t < dur:
        u = t / dur
        g = bell(rng.uniform(lo, hi), gdur, 60.0, ((1.0, 1.0, 1.0), (2.76, 0.3, 1.5)))
        s = N(t)
        m = min(len(g), total - s)
        out[s:s + m] += g[:m] * rng.uniform(0.5, 1.0) * (0.3 + 0.7 * u)
        t += rng.exponential(1.0 / (r0 + (r1 - r0) * u))
    return norm(out) * level


def crown_halo(seed=141):
    """swell 0-700 ms (sparkles 25 -> 60/s + air 1.5 -> 5 kHz) -> @700 ms A major glass chord A5-C#6-E6 + Kenney glass -> sparkle tail"""
    n = N(0.7)
    t = secs(n)
    air = norm(svf_bp(noise(n, seed), glide(n, 1500, 5000, 1.0), 1.3)) * (0.25 + 0.75 * (t / 0.7) ** 1.6) * 0.4
    swell = rate_sparkle(0.7, 25, 60, 2500, 7000, seed + 1, level=0.6)
    chord = sum(bell(f, 1.0, 3.2, ((1.0, 1.0, 1.0), (2.0, 0.3, 1.5), (2.76, 0.12, 2.2))) for f in (880.0, 1108.7, 1318.5))
    glass = norm(kenney("impact/impactGlass_medium_000", 0.989))
    tail = rate_sparkle(0.8, 40, 12, 3000, 7000, seed + 2, level=0.35)
    mix = at([(air, 0, 1.0), (swell, 0, 1.0), (norm(chord), 0.7, 1.0), (glass, 0.7, 0.45), (tail, 0.72, 1.0)])
    return finish(FF.lowpass(FF.highpass(mix, 400, 4), 8000, 2), 150)


def crown_horns(seed=151):
    """fire flare 300 -> 2500 Hz + embers 20 -> 70/s -> @600 ms wood drum (Kenney impactWood_medium_002 1.8x, driven, HP 450)
    + ember burst + a low fire bed -> tail embers + 'to-dok' (Kenney impactWood_light_000 1.6x / 1.35x)"""
    n = N(0.6)
    t = secs(n)
    flare = norm(np.tanh(2.0 * svf_bp(noise(n, seed), glide(n, 300, 2500, 1.0), 1.4))) * (0.2 + 0.8 * (t / 0.6) ** 1.4)
    embers = rate_sparkle(0.6, 20, 70, 1200, 3500, seed + 1, 0.012, 0.3)
    snow = FF.highpass(kenney("impact/footstep_snow_000"), 200, 2)
    drum = fade_out(drive(FF.highpass(kenney("impact/impactWood_medium_002", 1.8), 450, 2), 2.5)[:N(0.45)], 0.2)
    burst = rate_sparkle(0.25, 60, 25, 1200, 3500, seed + 2, 0.012, 0.35)
    m = N(0.9)
    bed = norm(svf_bp(noise(m, seed + 4), 900, 0.9)) * np.exp(-secs(m) * 3.0) * 0.35
    tail = rate_sparkle(0.6, 35, 12, 1200, 3200, seed + 3, 0.012, 0.25)
    mix = at([(flare, 0, 0.75), (embers, 0, 1.0), (norm(snow), 0.55, 0.25), (norm(drum), 0.6, 1.0), (burst, 0.6, 1.0),
              (bed, 0.6, 1.0), (tail, 0.85, 1.0), (norm(kenney("impact/impactWood_light_000", 1.6)), 0.98, 0.45),
              (norm(kenney("impact/impactWood_light_000", 1.35)), 1.08, 0.4)])
    return finish(FF.lowpass(FF.highpass(mix, 300, 4), 5000, 2), 150)


def king_defeat(seed=161, span=1.0):
    """pinata 'crack' (our tok + 40 ms paper tear) -> 52 candies bouncing 2-3 times (Kenney impactGlass_light_003 2.0-2.6x)
    -> @350 ms Kenney confirmation_002"""
    rng = np.random.default_rng(seed)
    m = N(0.06)
    crack = at([(osc(glide(m, 1300, 900)) * env(m, 0.001, 70), 0, 0.8), (band(N(0.04), 3500, 0.8, seed) * env(N(0.04), 0.001, 60), 0, 0.6)])
    glass = kenney("impact/impactGlass_light_003")
    rain = []
    for _ in range(52):
        t0 = 0.03 + (span - 0.03) * rng.uniform(0, 1) ** 1.25
        g = SC.respeed(glass, rng.uniform(2.0, 2.6))[:N(0.025)]
        g = g * np.linspace(1, 0, len(g)) ** 2
        for b in range(rng.integers(2, 4)):  # each candy bounces 2-3 times, smaller and sooner
            rain.append((g, t0 + b * 0.07 * (0.7 ** b), rng.uniform(0.25, 0.55) * 0.55 ** b))
    return finish(FF.highpass(at([(crack, 0, 1.0), *rain, (norm(kenney("interface/confirmation_002")), 0.35, 0.55)]), 300, 4), 150)


def war_final30(f=3200.0):
    """a bicycle bell: 3.2 kHz (+ a 15 Hz-off twin) + 1.04 kHz body, the clapper trill = 3 strikes 55 ms apart, rung twice @0 / 250 ms"""
    r = norm(bell(f, 0.16, 18, ((1.0, 1.0, 1.0), (2.1, 0.2, 1.6))) + bell(f + 15, 0.16, 18, ((1.0, 1.0, 1.0),))
             + 0.4 * bell(1040, 0.16, 14, ((1.0, 1.0, 1.0), (2.0, 0.2, 1.4))))
    trill = at([(r, 0, 1.0), (r, 0.055, 0.85), (r, 0.11, 0.75)])
    return finish(FF.highpass(at([(trill, 0, 0.8), (trill, 0.25, 1.0)]), 800, 4), 150)


def count_tick(seed=181, dec=36.0):
    """a wood block 'tok': 1.6 kHz + 2.76x partial, 3 ms click (the game plays it 1.0 / 1.12 / 1.26x for 3-2-1)"""
    b = bell(1600, 0.08, dec, ((1.0, 1.0, 1.0), (2.76, 0.3, 1.5)))
    click = band(N(0.003), 3000, 1.0, seed) * env(N(0.003), 0.0003, 600)
    return finish(FF.highpass(at([(b, 0, 1.0), (click, 0, 0.35)]), 600, 4), 150)


def goose_end(seed=191):
    """5 wing flaps flying away (Kenney footstep_grass_001, quieter each) + one happy honk 2 semitones up + 4 feather drifts"""
    rng = np.random.default_rng(seed)
    fl = [(flap(1.5 + 0.08 * i), 0.11 * i, 1.0 - 0.13 * i) for i in range(5)]
    drift = []
    for i in range(4):
        n = N(0.12)
        d = svf_bp(noise(n, seed + 10 + i), glide(n, rng.uniform(1500, 2500), rng.uniform(3000, 4000), 1.0), 1.2)
        drift.append((norm(d) * np.sin(np.pi * np.linspace(0, 1, n)), 0.5 + 0.13 * i, 0.45 - 0.06 * i))
    return finish(FF.highpass(at([*fl, (honk_toy(600 * 2 ** (2 / 12), seed=seed), 0.15, 0.55), *drift]), 400, 2), 150)


def stomp_mix(seed=201, wg=0.9, dg=0.5, sq_db=-5.0):
    """the big rubber boot: Kenney wood body (driven, HP 450 so phones keep it) + snow crunch + dust puff 1.3 -> 0.4 kHz
    + the rubber 'bwoong' 900 -> 600 Hz"""
    wood = FF.highpass(fade_out(drive(FF.highpass(kenney("impact/impactWood_medium_002"), 300, 2), 3.0)[:N(0.45)], 0.28), 450, 2)
    snow = FF.highpass(kenney("impact/footstep_snow_000"), 300, 2)
    n = N(0.32)
    dust = norm(svf_bp(noise(n, seed), glide(n, 1300, 400, 1.0), 0.8)) * env(n, 0.002, 8.0)
    m = N(0.05)
    squonk = osc(glide(m, 900, 600)) * env(m, 0.003, 25)
    return FF.lowpass(at([(norm(wood), 0, wg), (norm(snow), 0, 0.25), (dust, 0.0, dg), (squonk, 0.0, 10 ** (sq_db / 20))]), 3500, 2)


def kaiju_stomp(seed=201):
    return finish(stomp_mix(seed), 150)


def kaiju_siren(seed=211):
    """a rolling rumble 600 / 900 Hz noise with a 14 Hz wobble, -24 -> -6 dB over 0.9 s -> two boot stomps @0.95 / 1.3 s + dust
    + a few embers (not a siren, not a roar)"""
    n = N(1.0)
    t = secs(n)
    rumble = svf_bp(noise(n, seed), 600, 0.7) + 0.6 * svf_bp(noise(n, seed + 1), 900, 0.8)
    rumble = fade_out(norm(rumble) * (0.65 + 0.35 * np.sin(2 * np.pi * 14 * t)) * 10 ** ((-24 + 18 * np.minimum(t / 0.9, 1)) / 20), 0.1)
    st = norm(stomp_mix(seed + 2, 0.6, 0.9))
    m = N(0.5)
    dust = norm(svf_bp(noise(m, seed + 5), 800, 0.7)) * np.exp(-secs(m) * 4) * 0.3
    embers = rate_sparkle(0.55, 16, 8, 1500, 4000, seed + 3, 0.012, 0.12)
    return finish(FF.highpass(at([(rumble, 0, 1.0), (st, 0.95, 1.0), (dust, 0.98, 1.0), (st, 1.3, 1.0), (dust, 1.33, 1.0),
                                  (embers, 1.3, 1.0)]), 150, 4), 150)


def zone_enter_pvp(seed=221):
    """two pitched toms 400 Hz -> 530 Hz 130 ms apart ('du-dum!' going up), each with a small skin click"""
    def tom(f):
        n = N(0.26)
        x = osc(glide(n, f * 1.05, f)) + 0.4 * osc(glide(n, 1.5 * f * 1.05, 1.5 * f))
        click = band(N(0.006), 2500, 1.0, seed + int(f)) * env(N(0.006), 0.0003, 400)
        return at([(x * env(n, 0.003, 13), 0, 1.0), (click, 0, 0.3)])
    return finish(FF.highpass(at([(tom(400), 0, 1.0), (tom(530), 0.13, 1.0)]), 250, 4), 150)


def golden_spot(seed=234):
    """sparkle grains slowly rising 2.5 -> 4.5 kHz (no steps) -> @280 ms Kenney glass_002 'ping' (LP 4.5 k) + a 4.4 kHz ring"""
    rng = np.random.default_rng(seed)
    total = N(0.33)
    out = np.zeros(total)
    t = 0.0
    while t < 0.3:
        g = bell(2500 * 2 ** (t / 0.3 * 0.85) * rng.uniform(0.94, 1.06), 0.03, 60.0, ((1.0, 1.0, 1.0), (2.76, 0.15, 1.5)))
        s = N(t)
        m = min(len(g), total - s)
        out[s:s + m] += g[:m] * rng.uniform(0.6, 1.0)
        t += rng.exponential(1 / 45)
    g2 = fade_out(norm(FF.lowpass(FF.highpass(kenney("interface/glass_002"), 2500, 2), 4500, 4))[:N(0.2)], 0.1)
    ring = bell(4400, 0.22, 10.0, ((1.0, 1.0, 1.0),))
    return finish(FF.lowpass(FF.highpass(at([(norm(out), 0, 0.8), (g2, 0.28, 0.5), (ring, 0.28, 0.45)]), 1500, 4), 6000, 2), 150)


def scroll_success(seed=241):
    """a glint sweep 2 -> 7 kHz (80 ms) -> G7 3.1 kHz ring with a 1.05 kHz body partial -> Kenney glass_004 @150 ms -> high sparkles"""
    n = N(0.08)
    glint = norm(svf_bp(noise(n, seed), glide(n, 2000, 7000, 1.0), 2.0)) * np.sin(np.pi * np.linspace(0, 1, n)) ** 0.5
    ring = bell(3136, 0.5, 6, ((1.0, 1.0, 1.0), (0.335, 0.5, 2.5), (2.0, 0.15, 1.2)))
    sp = rate_sparkle(0.45, 20, 30, 4500, 7500, seed + 1, level=0.35)
    return finish(FF.highpass(at([(glint, 0, 0.5), (ring, 0.05, 1.0), (norm(kenney("interface/glass_004")), 0.15, 0.5), (sp, 0.25, 1.0)]),
                              500, 4), 150)


def rank_up(notes=("C5", "D5", "E5"), gap=0.055):
    """the mirror of RankDown: the same marimba going up C5-D5-E5"""
    parts = [(marimba(note_hz(n), 0.22, 18), i * gap, 10 ** (-1.0 * i / 20)) for i, n in enumerate(notes)]
    return finish(FF.lowpass(at(parts), 4000, 2), 400)


def spend(gap=0.05):
    """the GoldPickup coins going DOWN: E7 -> D7, quietly"""
    return finish(at([(coin(note_hz("E7")), 0.0, 1.0), (coin(note_hz("D7")), gap, 0.85)]), 400)


def plunder():
    """coins scattering away: G7-E7-D7-C7-A6, each quieter and later, getting duller (further away)"""
    t, parts = 0.0, []
    for i, nm in enumerate(("G7", "E7", "D7", "C7", "A6")):
        parts.append((coin(note_hz(nm)), t, 0.9 ** (i * 2)))
        t += 0.045 + 0.02 * i
    y = at(parts)
    w = np.linspace(0, 1, len(y)) ** 0.8
    return finish(y * (1 - w) + FF.lowpass(y, 2500, 2) * w, 400)


def ko(seed=261):
    """cartoon dizzy: a soft bump + 'boing' -> three warbling tweet-stars 2.4 -> 2.9 kHz + a soft whirl (no sad jingle)"""
    n = N(0.12)
    bump = norm(svf_bp(noise(n, seed), glide(n, 800, 400), 1.2)) * env(n, 0.001, 25)
    m = N(0.06)
    boing = osc(glide(m, 700, 520)) * env(m, 0.003, 30)
    stars = []
    for i in range(3):
        k = N(0.16)
        f = glide(k, 2400, 2900, 1.0) * (1 + 0.04 * np.sin(2 * np.pi * 22 * secs(k)))
        stars.append((osc(f) * np.sin(np.pi * np.linspace(0, 1, k)) ** 1.2, 0.17 + 0.18 * i, 0.4 - 0.05 * i))
    w = N(0.7)
    whirl = norm(svf_bp(noise(w, seed + 3), 2600 + 300 * np.sin(2 * np.pi * 5 * secs(w)), 4.0)) * np.sin(np.pi * np.linspace(0, 1, w)) * 0.08
    return finish(FF.lowpass(at([(bump, 0, 1.0), (boing, 0.005, 0.5), *stars, (whirl, 0.12, 1.0)]), 6000, 2), 250)


def respawn():
    """a short 'ppyong!' 620 -> 1300 Hz with an octave layer"""
    n = N(0.16)
    x = osc(glide(n, 620, 1300, 0.7)) * env(n, 0.004, 11) + 0.25 * osc(glide(n, 1240, 2600, 0.7)) * env(n, 0.004, 14)
    return finish(FF.highpass(x, 450, 4), 300)


def coin_roll(f0, n_b, g0, g1, fall, lp):
    """one coin rolling away: taps whose gaps shrink g0 -> g1 (s), each quieter and duller"""
    t, parts = 0.0, []
    for i in range(n_b):
        u = i / max(1, n_b - 1)
        parts.append((coin(f0 * (1 - 0.03 * u), 0.08), t, fall ** i))
        t += g0 + (g1 - g0) * u
    y = at(parts)
    w = np.linspace(0, 1, len(y))
    return y * (1 - w) + FF.lowpass(y, lp, 2) * w


def plunder_roll(notes=("G7", "E7", "C7", "A6"), gap=0.03, rollf="D6", nb=4, lp=1800):
    """'jjal-geu-rang~ tto-reu-reu': a quick clatter of our coins falling down, then one coin rolls away (sA was too close
    to GoldPickup: pair score 0.81 < 1.0)"""
    clat = at([(coin(note_hz(nm)), i * gap, 0.92 ** (i * 2)) for i, nm in enumerate(notes)])
    y = at([(clat, 0, 1.0), (coin_roll(note_hz(rollf), nb, 0.055, 0.02, 0.8, lp), len(notes) * gap + 0.03, 0.55)])
    w = np.linspace(0, 1, len(y)) ** 0.6
    return finish(y * (1 - w) + FF.lowpass(y, lp, 2) * w, 400)


def respawn_high(f0=1000.0, f1=2200.0):
    """a higher 'ppyong!' 1.0 -> 2.2 kHz with an octave layer (sA was too close to Jump: pair score 0.73 < 1.0)"""
    n = N(0.17)
    x = osc(glide(n, f0, f1, 0.7)) * env(n, 0.003, 12) + 0.2 * osc(glide(n, 2 * f0, 2 * f1, 0.7)) * env(n, 0.003, 16)
    return finish(FF.highpass(x, 600, 4), 400, 7000)


def jackpot_other(seed=281):
    """a 30 ms confetti pop (noise 2 kHz) + a rising glass ping 2.2 -> 2.9 kHz + sparkles"""
    pop = band(N(0.03), 2000, 1.0, seed) * env(N(0.03), 0.0005, 80)
    n = N(0.5)
    ping = osc(glide(n, 2200, 2900, 0.8)) * env(n, 0.002, 5.0)
    sp = rate_sparkle(0.45, 25, 15, 3000, 6000, seed + 1, level=0.4)
    return finish(FF.highpass(at([(pop, 0, 0.8), (ping, 0.02, 1.0), (sp, 0.12, 1.0)]), 400, 4), 150)


# ---------------------------------------------------------------- SkillLearn (A23-71: Lv5 / 15 / 25)
def button_pop(f0=700.0, f1=1600.0, dur=0.03, seed=11):
    """the skill button pops in: a fast sine up-glide + a tiny click"""
    n = N(dur)
    x = osc(glide(n, f0, f1, 0.5)) * env(n, 0.001, 70)
    return at([(x, 0, 1.0), (band(N(0.003), 3000, 1.0, seed), 0, 0.3)])


def glass_run(notes, gap, gdur=0.06):
    """a quick sparkle run of tiny glass grains (heard as one flourish, not a melody)"""
    return at([(bell(note_hz(nm), gdur, 40.0, ((1.0, 1.0, 1.0), (2.76, 0.25, 1.6))), i * gap, 0.55 + 0.08 * i)
               for i, nm in enumerate(notes)])


def shimmer_chord(notes, dur=0.55, trem=7.0, depth=0.35, body=0.25, decay=4.5):
    """one held bright chord (sine + triangle) with a slow shimmer tremolo and a small octave-down body for phones"""
    n = N(dur)
    t = secs(n)
    x = np.zeros(n)
    for i, nm in enumerate(notes):
        f = note_hz(nm)
        x += (0.7 * np.sin(2 * np.pi * f * t) + 0.3 * tri(np.full(n, f))) / (1 + 0.4 * i)
    x += body * np.sin(2 * np.pi * note_hz(notes[0]) / 2 * t)
    am = 1 - depth * (0.5 - 0.5 * np.cos(2 * np.pi * trem * t))
    return x * am * np.minimum(t / 0.004, 1.0) * np.exp(-decay * t)


def skill_learn(run_notes=("A6", "C7", "D7", "E7", "G7"), gap=0.022, chord=("A6", "E7"), at_chord=0.15):
    """'ppok! sha-ra-rak~ tiing~': the button pop (loudest, so the start is crisp) -> a glass sparkle run -> one held
    shimmering chord. Not PowerUp's sweep, not LevelUp's fanfare, not QuestDone's bell steps"""
    parts = [(button_pop(), 0, 2.2), (glass_run(run_notes, gap), 0.035, 0.55), (shimmer_chord(chord), at_chord, 0.8)]
    return finish(FF.lowpass(at(parts), 7000, 2), 400)


RECIPES = {
    "GoldPickup": {"sA": ("our coins D7-E7-G7 stepping up, 55 ms apart (sound_spec)", lambda: gold(("D7", "E7", "G7"))),
                   "sB": ("our coins E7-D7-G7 (the other order, sound_spec)", lambda: gold(("E7", "D7", "G7"))),
                   "kA": ("Kenney impactMetal_light_001 -> 000 -> 004 stepping (money samples)", gold_kenney)},
    "QuestNew": {"sA": ("paper flick x2 + marimba C6 -> G6 (open fifth)", lambda: quest_new()),
                 "sB": ("paper flick x2 + marimba D6 -> A6", lambda: quest_new("D6", "A6"))},
    "QuestDone": {"sA": ("bells E6-G6-C7 65 ms apart + C6 triangle body + sparkle", lambda: quest_done()),
                  "sB": ("bells E6-G6-C7 55 ms apart, last rings longer", lambda: quest_done(gap=0.055))},
    "WindowClose": {"sA": ("our mirror of WindowOpen: 1550 -> 1000 Hz, 4 ms attack", window_close_synth)},
    "Deny": {"sA": ("two nasal rubber notes 622 -> 523 Hz (pulse 30 % + 1 kHz band, LP 2.5 k)", lambda: deny()),
             "sB": ("same, a little lower 587 -> 494 Hz", lambda: deny(587.0, 494.0))},
    "RankDown": {"sA": ("marimba E5-D5-C5 55 ms apart, each 1.5 dB quieter, LP 4 k", lambda: rank_down()),
                 "sB": ("marimba E5-D5-C5 65 ms apart", lambda: rank_down(gap=0.065))},
    "ScrollFail": {"sA": ("'pfff' noise 3.5 -> 0.9 kHz + 'plop' E5 -> C5 + two fading sparkles", scroll_fail)},
    "SkillHalo": {"sA": ("rising wind 1.2 -> 5 kHz + glass chime cluster 1.2-2 kHz + sparkles 3.5-7 kHz", lambda: skill_halo()),
                  "sB": ("same recipe, another seed", lambda: skill_halo(33))},
    "SkillHorns": {"sA": ("fire whoosh 400 -> 1200 -> 600 Hz + crackles + 'bwomp' + Kenney wood 'to-dok'", lambda: skill_horns()),
                   "sB": ("same recipe, another seed", lambda: skill_horns(43))},
    "Purify": {"sA": ("glass wind chimes (C major, random order) + rising air + C-E-G pad + sparkles", lambda: purify()),
               "sB": ("same, another order (two rotating versions, sound_spec)", lambda: purify(53))},
    "Devour": {"sA": ("bright 'am' bite grains + gulp x2 (720 -> 480, 600 -> 400 Hz) + 'pop' 900 -> 1800 Hz + ember crackles", lambda: devour()),
               "sB": ("same recipe, another seed", lambda: devour(63))},
    "Potion": {"sA": ("cork 1400 -> 500 Hz + 7 bubbles rising 700 -> 1800 Hz", lambda: potion()),
               "sB": ("same recipe, another seed", lambda: potion(73))},
    "AutoOn": {"sA": ("latch (Kenney switch_002) + bright motor up 800 -> 2200 Hz + triangle beep D7 2349 Hz", lambda: auto_on()),
               "sB": ("same latch + motor up 700 -> 2000 Hz + a longer beep C7 2093 Hz", lambda: auto_on(700.0, 2000.0, 2093.0, 0.13, 14.0))},
    "AutoOff": {"sA": ("same latch + motor down 1300 -> 420 Hz + wooden 'tok' 523 Hz", auto_off)},
    "TalkBlip": {"sA": ("triangle 620 -> 595 Hz, 34 ms, LP 3 k", lambda: talk_blip()),
                 "sB": ("triangle 660 -> 630 Hz, 34 ms", lambda: talk_blip(660.0, 630.0))},
    "Equip": {"sA": ("ratchet clicks x3 + latch (Kenney switch_002 0.9x) + small sparkle", lambda: equip()),
              "sB": ("same recipe, another seed", lambda: equip(85))},
    "SkillReady": {"sA": ("soft sine pip 1.4 -> 1.6 kHz, 50 ms", lambda: skill_ready()),
                   "sB": ("soft sine pip 1.2 -> 1.45 kHz", lambda: skill_ready(1200.0, 1450.0))},
    "HurtBig": {"sA": ("muffled bump 700 -> 300 Hz + falling chirp 1.1 -> 0.6 kHz, 150 ms", lambda: hurt_big()),
                "sB": ("same recipe, another seed", lambda: hurt_big(93))},
    "PumpkinKing": {"sA": ("king bells x2 (Kenney impactBell_heavy_003 2.0x) + hollow 'bonk' (Kenney wood + our 445 Hz tok) + 34 candy clicks (Kenney glass 2.4x falling) + sparkle", lambda: pumpkin_king()),
                    "sB": ("same, a louder wood bonk (HP 500) and another candy order", lambda: pumpkin_king(113, wood_hp=500, wood_g=0.6, tok_g=0.35))},
    "GhostKing": {"sA": ("the same king bells + breathy rising 'whoo?' 620 -> 740 Hz + glass (Kenney impactGlass_medium_001) + sparkles", lambda: ghost_king()),
                  "sB": ("same recipe, another breath / sparkle seed", lambda: ghost_king(123))},
    "GooseArrive": {"sA": ("3 wing flaps (Kenney footstep_grass_001 1.6-1.8x) + toy honk 560 Hz + honk 665 Hz (3 semitones up) + gold sparkle (Kenney glass_002)", lambda: goose_arrive()),
                    "sB": ("same, honks 600 -> 713 Hz", lambda: goose_arrive(133, 600.0, 713.0))},
    "GooseHonk": {"sA": ("ONE toy rubber honk 600 Hz: rising 20 ms squeak + nasal body (formants 1.0 / 1.8 / 2.8 kHz) + 10 % breath", lambda: finish(honk_toy(600.0), 300)),
                  "sB": ("same honk at 620 Hz", lambda: finish(honk_toy(620.0, seed=103), 300))},
    "CrownHalo": {"sA": ("swell (sparkles 25 -> 60/s + air 1.5 -> 5 kHz) -> A major glass chord + Kenney impactGlass_medium_000 0.989x -> sparkle tail", lambda: crown_halo()),
                  "sB": ("same recipe, another sparkle seed", lambda: crown_halo(143))},
    "CrownHorns": {"sA": ("fire flare 300 -> 2500 Hz + embers -> Kenney wood drum 1.8x (driven, HP 450) + burst + fire bed -> 'to-dok' (Kenney wood light 1.6x / 1.35x)", lambda: crown_horns()),
                   "sB": ("same recipe, another fire seed", lambda: crown_horns(153))},
    "KingDefeat": {"sA": ("pinata crack (tok + paper tear) + 52 bouncing candies (Kenney impactGlass_light_003 2.0-2.6x) + Kenney confirmation_002 @350 ms", lambda: king_defeat()),
                   "sB": ("same recipe, another candy rain", lambda: king_defeat(163))},
    "WarFinal30": {"sA": ("bicycle bell: 3.2 kHz + 1.04 kHz body, clapper trill 3 strikes 55 ms apart, rung twice @0 / 250 ms", lambda: war_final30()),
                   "sB": ("same bell a little lower (3.0 kHz)", lambda: war_final30(3000.0))},
    "CountTick": {"sA": ("wood block 'tok' 1.6 kHz + 2.76x partial + 3 ms click (game: 1.0 / 1.12 / 1.26x)", lambda: count_tick()),
                  "sB": ("same block, a slightly longer ring", lambda: count_tick(183, 32.0))},
    "GooseEnd": {"sA": ("5 flaps flying away (Kenney footstep_grass_001) + one happy toy honk +2 semitones + 4 feather drifts", lambda: goose_end()),
                 "sB": ("same recipe, other feathers", lambda: goose_end(193))},
    "KaijuSiren": {"sA": ("rolling rumble 600 / 900 Hz noise, 14 Hz wobble, -24 -> -6 dB -> two rubber-boot stomps + dust + embers", lambda: kaiju_siren()),
                   "sB": ("same recipe, another rumble", lambda: kaiju_siren(213))},
    "KaijuStomp": {"sA": ("Kenney wood body (driven, HP 450) + Kenney snow crunch + dust puff 1.3 -> 0.4 kHz + rubber 'bwoong' 900 -> 600 Hz", lambda: kaiju_stomp()),
                   "sB": ("same boot, another dust puff", lambda: kaiju_stomp(203))},
    "ZoneEnterPvP": {"sA": ("two pitched toms 400 -> 530 Hz, 130 ms apart, small skin clicks", lambda: zone_enter_pvp())},
    "GoldenSpot": {"sA": ("rising sparkle grains 2.5 -> 4.5 kHz (no steps) + Kenney glass_002 ping (LP 4.5 k) + 4.4 kHz ring", lambda: golden_spot())},
    "ScrollSuccess": {"sA": ("glint 2 -> 7 kHz + G7 ring with a 1.05 kHz body + Kenney glass_004 @150 ms + high sparkles", lambda: scroll_success()),
                      "sB": ("same recipe, other sparkles", lambda: scroll_success(243))},
    "RankUp": {"sA": ("marimba C5-D5-E5 55 ms apart (RankDown's mirror)", lambda: rank_up()),
               "sB": ("marimba C5-D5-E5 65 ms apart", lambda: rank_up(gap=0.065))},
    "Spend": {"sA": ("our coins E7 -> D7 going down, 50 ms apart (GoldPickup's coins)", lambda: spend()),
              "sB": ("same coins 60 ms apart", lambda: spend(0.06))},
    "Plunder": {"sA": ("coins scattering away G7-E7-D7-C7-A6, quieter, later and duller", plunder),
                "sB": ("clatter G7-E7-C7-A6 30 ms apart + one D6 coin rolling away (4 taps, gaps 55 -> 20 ms), LP 1.8 k", lambda: plunder_roll())},
    "KO": {"sA": ("soft bump + 'boing' + three warbling tweet-stars 2.4 -> 2.9 kHz + soft whirl", lambda: ko()),
           "sB": ("same recipe, another bump", lambda: ko(263))},
    "Respawn": {"sA": ("'ppyong!' 620 -> 1300 Hz with an octave layer, 0.16 s", respawn),
                "sB": ("higher 'ppyong!' 1.0 -> 2.2 kHz with an octave layer, 0.17 s", lambda: respawn_high()),
                "sC": ("'ppyong!' 0.9 -> 2.0 kHz with an octave layer, 0.17 s", lambda: respawn_high(900.0, 2000.0))},
    "JackpotOther": {"sA": ("confetti pop + rising glass ping 2.2 -> 2.9 kHz + sparkles", lambda: jackpot_other()),
                     "sB": ("same recipe, other sparkles", lambda: jackpot_other(283))},
    "SkillLearn": {"sA": ("button pop 700 -> 1600 Hz + glass run A6-C7-D7-E7-G7 22 ms apart + held A6+E7 chord, 7 Hz shimmer", lambda: skill_learn()),
                   "sB": ("button pop + shorter run C7-E7-G7 35 ms apart + the same chord at 130 ms",
                          lambda: skill_learn(("C7", "E7", "G7"), 0.035, ("A6", "E7"), 0.13)),
                   "sC": ("button pop + run A6-D7-E7-G7 30 ms apart + a lower E6+B6 chord (phones)",
                          lambda: skill_learn(("A6", "D7", "E7", "G7"), 0.03, ("E6", "B6"), 0.14))},
}
