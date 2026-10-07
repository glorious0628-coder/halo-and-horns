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
}
