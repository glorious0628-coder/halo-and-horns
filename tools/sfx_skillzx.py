"""
Z·X 스킬 12개의 시전·맞음 소리 후보 (소리 만들기, 2026-10-10; docs/design/skills18_2026-10-10.md). 직접 합성(크레딧 0).
  Cast<Skill> 0초 = 버튼, 맞는 순간(Z·X 0.24초)에 큰 소리   Hit<Skill> 맞은 몬스터마다(틱 스킬은 시전보다 -6 dB 로 작게)
  Z: GlowLasso(빛 전사) FireRake(뿔 전사) BirdieBounce(빛 마법사) FlappyZigzag(뿔 마법사) CometArrow(빛 궁수) MoonShot(뿔 궁수)
  X: GuardianRoar RageRoar SunCircle HexCircle LightStep ShadowStep
  BirdieBounce·FlappyZigzag 의 Hit 은 음 하나('짹-딩'/'찍'): 게임에서 Speed 로 4음(도-미-솔-도 = 1, 1.26, 1.5, 2 / 내려가는 쪽 1, 0.84, 0.67, 0.56)을 만든다.
  py tools/sfx_skillzx.py [only]  -> build/sfx_skillzx/cand/<Key>_<a|b>.wav     py tools/sfx_skillzx.py sheet OUT.png
빛 = 맑은 종·깃털 바람, 뿔 = 낮은 붕·불씨 탁탁. 비명·짐승 소리 없음. 폰에서 줄지 않게 몸통 400 Hz 위.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import sfx_game as G  # noqa: E402
import sfx_skillq as Q  # noqa: E402

SR = G.SR
OUT = os.path.join(G.ROOT, "build", "sfx_skillzx", "cand")
tone, nz, bellx, air, crackle, M = Q.tone, Q.nz, Q.bellx, Q.air_sweep, Q.crackle, Q.M


def pulses(dur, rate, f0, f1, seed, level=1.0):
    """a rapid 'dr-r-r-r' (reeling / flapping): short noise ticks whose pitch climbs"""
    out = np.zeros(G.count(dur + 0.03))
    t = 0.0
    k = 0
    n = int(dur * rate)
    for k in range(n):
        f = f0 * (f1 / f0) ** (k / max(1, n - 1))
        d = 0.012
        m = G.count(d)
        tt = G.secs(m)
        x = np.sin(2 * np.pi * f * tt) * np.exp(-tt * 260)
        i = int(k / rate * SR)
        out[i:i + m] += x * level
    return out


def harp(notes, step, decay=11.0, level=0.55, start=0.0):
    return [(bellx(f, 0.35, decay, ((1, 1.0, 1.0), (2.0, 0.16, 2.0))), start + step * i, level) for i, f in enumerate(notes)]


# ---------------------------------------------------------------- Z
def cast_glow_lasso(v):
    notes = [523, 659, 784, 1047, 1319, 1568, 2093] if v == "a" else [587, 740, 880, 1175, 1480, 1760, 2349]
    return M([(air(0.26, 600, 3000, 80, 0.6), 0.0, 1.0)] + harp(notes, 0.035, start=0.02)
             + [(bellx(2600, 0.25, 16.0, ((1, 1.0, 1.0), (2.76, 0.5, 1.5))), 0.26, 0.45),
                (pulses(0.4, 36, 700, 1500, 81, 0.35), 0.34, 1.0), (bellx(1568, 0.5, 8.0), 0.78, 0.7)])


def hit_glow_lasso(v):
    return M([(bellx(2600 if v == "a" else 2349, 0.22, 16.0, ((1, 1.0, 1.0), (2.76, 0.4, 1.5))), 0, 0.6), (G.sparkle(0.12, 3, 3500, 6000, seed=82, level=0.14), 0.01, 1.0)])


def cast_fire_rake(v):
    scrape = nz(0.2, 1500, 4200, 9, 90, attack=0.02) * 0.7
    hum = M([(tone(260 if v == "a" else 230, 0.5, "sine", decay=5, attack=0.03), 0, 0.6), (tone(520, 0.5, "sine", decay=6, attack=0.03), 0, 0.5), (nz(0.45, 500, 1600, 6, 91), 0, 0.5)])
    return M([(scrape, 0.2, 1.0), (hum, 0.26, 1.0), (crackle(0.6, 20, 92, 0.5), 0.3, 1.0), (air(0.3, 2200, 700, 93, 0.5), 0.46, 1.0)])


def hit_fire_rake(v):
    return M([(air(0.12, 1800, 700, 94, 0.5), 0, 1.0), (crackle(0.12, 60, 95, 0.5), 0.02, 1.0), (tone(420, 0.08, "sine", decay=36), 0, 0.4)])


def cast_birdie_bounce(v):
    notes = [523, 659, 784, 1047] if v == "a" else [587, 740, 880, 1175]
    parts = []
    for i, f in enumerate(notes):
        at = 0.24 + 0.14 * i
        parts.append((tone(2600, 0.05, "sine", decay=40, bend=0.5), at, 0.35))  # chirp
        parts.append((bellx(f * 2, 0.3, 10.0), at + 0.03, 0.6))  # ding
        parts.append((nz(0.05, 1500, 4000, 40, 100 + i) * 0.25, at + 0.06, 1.0))  # wing flap
    return M(parts)


def hit_birdie_bounce(v):
    f = 1046 if v == "a" else 1175
    return M([(tone(2600, 0.05, "sine", decay=40, bend=0.5), 0, 0.35), (bellx(f, 0.28, 10.0), 0.03, 0.7), (nz(0.05, 1500, 4000, 40, 110) * 0.25, 0.05, 1.0)])


def cast_flappy_zigzag(v):
    notes = [1047, 880, 698, 587] if v == "a" else [988, 830, 659, 554]
    parts = []
    for i, f in enumerate(notes):
        at = 0.24 + 0.14 * i
        parts.append((tone(f, 0.07, "tri", decay=26, bend=0.3), at, 0.55))  # a little 'chik'
        parts.append((nz(0.06, 800, 3000, 36, 120 + i) * 0.35, at + 0.02, 1.0))  # flap
    parts.append((tone(380, 0.14, "sine", decay=22, bend=-0.4), 0.82, 0.8))  # the closing 'puk'
    return M(parts)


def hit_flappy_zigzag(v):
    f = 1047 if v == "a" else 988
    return M([(tone(f, 0.07, "tri", decay=26, bend=0.3), 0, 0.6), (nz(0.06, 800, 3000, 36, 130) * 0.35, 0.02, 1.0)])


def cast_comet_arrow(v):
    creak = air(0.2, 400, 1100, 140, 0.5)
    whoom = air(0.5, 500, 3200, 141, 0.9)
    tail = bellx(1568 if v == "a" else 1397, 1.0, 4.5) * 0.45
    return M([(creak, 0.02, 1.0), (whoom, 0.22, 1.0), (tail, 0.3, 1.0), (G.sparkle(0.5, 8, 3000, 6000, seed=142, level=0.1), 0.45, 1.0)])


def hit_comet_arrow(v):
    return M([(tone(900 if v == "a" else 780, 0.07, "sine", decay=40), 0, 0.8), (nz(0.04, 1000, 3500, 70, 143) * 0.5, 0, 1.0)])


def cast_moon_shot(v):
    creak = air(0.22, 350, 1000, 150, 0.6)
    shuk = nz(0.1, 2800, 7000, 36, 151) * 0.6
    woom = M([(tone(420 if v == "a" else 370, 0.5, "sine", decay=6, bend=-0.35), 0, 0.9), (tone(840, 0.35, "sine", decay=9, bend=-0.35), 0, 0.5)])
    return M([(creak, 0.02, 1.0), (shuk, 0.22, 1.0), (woom, 0.26, 1.0), (crackle(0.4, 14, 152, 0.3), 0.4, 1.0)])


def hit_moon_shot(v):
    return M([(nz(0.08, 400, 1800, 40, 153), 0, 0.9), (tone(480 if v == "a" else 430, 0.08, "sine", decay=34, bend=-0.4), 0, 0.5)])


# ---------------------------------------------------------------- X
def cast_guardian_roar(v):
    brass = lambda f, d: G.svf(G.osc(np.full(G.count(d), float(f)), "saw") * np.exp(-G.secs(G.count(d)) * 7) * np.clip(G.secs(G.count(d)) / 0.01, 0, 1), 2400, 0.707, "lp")
    ta = brass(523 if v == "a" else 494, 0.16) * 0.6
    dan = brass(784 if v == "a" else 740, 0.3) * 0.7
    shield = bellx(1400, 0.4, 9.0, ((1, 1.0, 1.0), (2.76, 0.6, 1.3), (5.4, 0.25, 2.0))) * 0.5
    choir = M([(tone(f, 0.55, "sine", decay=3.5, attack=0.12) * (1 + 0.15 * np.sin(2 * np.pi * 5.5 * G.secs(G.count(0.55)))), 0, 0.3) for f in (523, 659, 784, 1047)])
    return M([(ta, 0.1, 1.0), (dan, 0.24, 1.0), (shield, 0.3, 1.0), (choir, 0.32, 1.0)])


def hit_guardian_roar(v):
    return M([(bellx(1175 if v == "a" else 1047, 0.2, 14.0), 0, 0.6), (nz(0.04, 1500, 4500, 80, 160) * 0.3, 0, 1.0)])


def cast_rage_roar(v):
    n = G.count(0.5)
    t = G.secs(n)
    f = (320 + 220 * np.sin(np.pi * np.clip(t / 0.5, 0, 1))) * (1 if v == "a" else 0.9)  # a rising-falling cartoon 'yaa-aah' (synth, not a voice)
    saw = G.osc(f, "saw") * np.clip(t / 0.03, 0, 1) * np.exp(-t * 3.2)
    roar = G.svf(G.svf(saw, 3000, 0.707, "lp"), 250, 0.707, "hp") * 0.7
    drums = [(M([(tone(340, 0.18, "sine", decay=18, bend=-0.4), 0, 1.0), (tone(680, 0.1, "sine", decay=30), 0, 0.5), (nz(0.08, 700, 3000, 40, 170 + k), 0, 0.5)]), 0.24 + 0.16 * k, 0.9) for k in range(2)]
    return M([(roar, 0.18, 1.0)] + drums + [(crackle(0.5, 20, 171, 0.4), 0.4, 1.0)])


def hit_rage_roar(v):
    return M([(tone(380, 0.14, "sine", decay=24, bend=-0.4), 0, 0.8), (tone(760, 0.08, "sine", decay=36), 0, 0.4), (Q.tone(1760, 0.2, "sine", decay=16) * 0.25, 0.04, 1.0)])


def cast_sun_circle(v):
    ch = [523, 659, 784] if v == "a" else [587, 740, 880]
    pad = M([(tone(f, 0.9, "sine", decay=2.2, attack=0.22) * (1 + 0.1 * np.sin(2 * np.pi * 5 * G.secs(G.count(0.9)))), 0, 0.3) for f in ch + [f * 2 for f in ch]])
    return M(harp(ch + [ch[0] * 2], 0.08, start=0.24, level=0.5) + [(pad, 0.2, 1.0), (bellx(1568, 0.5, 8.0), 1.0, 0.45), (G.sparkle(0.4, 8, 3000, 6000, seed=180, level=0.12), 1.0, 1.0)])


def hit_sun_circle(v):
    return M([(bellx(1568 if v == "a" else 1397, 0.2, 16.0), 0, 0.35)])  # a tick: -6 dB under the cast


def cast_hex_circle(v):
    base = M([(tone(330 if v == "a" else 290, 0.9, "sine", decay=3.2, attack=0.15), 0, 0.8), (tone(660, 0.8, "sine", decay=3.8, attack=0.15), 0, 0.5)])
    bub = [(tone(260 + 40 * k, 0.07, "sine", decay=28, bend=0.8), 0.45 + 0.1 * k, 0.4) for k in range(5)]
    return M([(base, 0.2, 1.0)] + bub)


def hit_hex_circle(v):
    return M([(tone(420 if v == "a" else 370, 0.1, "sine", decay=30, bend=0.9), 0, 0.4)])


def cast_light_step(v):
    wind = air(0.45, 400, 1900, 190, 0.8)
    feather = M([(air(0.3, 1100, 2400, 191 + k, 0.25), 0.07 * k, 1.0) for k in range(4)])
    ting = bellx(1976 if v == "a" else 1760, 0.3, 12.0) * 0.5
    land = tone(520, 0.1, "sine", decay=34, bend=-0.4)
    return M([(wind, 0.1, 1.0), (feather, 0.2, 1.0), (ting, 0.45, 1.0), (land, 0.75, 0.8)])


def hit_light_step(v):
    return M([(air(0.12, 900, 2400, 195, 0.4), 0, 1.0), (tone(1300, 0.06, "sine", decay=50), 0, 0.3)])


def cast_shadow_step(v):
    pung = M([(tone(340 if v == "a" else 300, 0.26, "sine", decay=9, bend=1.5), 0, 0.9), (tone(680, 0.2, "sine", decay=13, bend=1.5), 0, 0.4), (nz(0.1, 3000, 7000, 30, 200), 0, 0.3)])
    bats = [(M([(tone(2500, 0.03, "sine", decay=70, bend=0.4), 0, 0.5), (nz(0.04, 1500, 4000, 50, 201 + k), 0, 0.3)]), 0.2 + 0.07 * k, 1.0) for k in range(4)]
    land = tone(500, 0.1, "sine", decay=34, bend=-0.4)
    mp = [(tone(560 + 140 * k, 0.06, "sine", decay=34, bend=0.7), 0.85 + 0.06 * k, 0.4) for k in range(3)]
    return M([(pung, 0.24, 1.0)] + bats + [(land, 0.72, 0.8)] + mp)


def hit_shadow_step(v):
    return M([(nz(0.08, 700, 2800, 45, 205), 0, 0.8), (tone(480 if v == "a" else 430, 0.08, "sine", decay=34, bend=-0.4), 0, 0.5)])


KINDS = {
    "CastGlowLasso": cast_glow_lasso, "HitGlowLasso": hit_glow_lasso, "CastFireRake": cast_fire_rake, "HitFireRake": hit_fire_rake,
    "CastBirdieBounce": cast_birdie_bounce, "HitBirdieBounce": hit_birdie_bounce, "CastFlappyZigzag": cast_flappy_zigzag, "HitFlappyZigzag": hit_flappy_zigzag,
    "CastCometArrow": cast_comet_arrow, "HitCometArrow": hit_comet_arrow, "CastMoonShot": cast_moon_shot, "HitMoonShot": hit_moon_shot,
    "CastGuardianRoar": cast_guardian_roar, "HitGuardianRoar": hit_guardian_roar, "CastRageRoar": cast_rage_roar, "HitRageRoar": hit_rage_roar,
    "CastSunCircle": cast_sun_circle, "HitSunCircle": hit_sun_circle, "CastHexCircle": cast_hex_circle, "HitHexCircle": hit_hex_circle,
    "CastLightStep": cast_light_step, "HitLightStep": hit_light_step, "CastShadowStep": cast_shadow_step, "HitShadowStep": hit_shadow_step,
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


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "sheet":
        Q.MAKERS = MAKERS
        Q.render = render
        Q.sheet(sys.argv[2] if len(sys.argv) > 2 else os.path.join(G.ROOT, "build", "sfx_skillzx", "sheet.png"))
    else:
        main()
