"""
게임 효과음 후보 (품질 ①, docs/design/quality_ideas_2026-10-06.md §1): Kenney CC0 팩 + 이 파일이 직접 합성한 소리.
  py tools/sfx_game.py scan [family ...]   Kenney 파일의 길이·밝기·크기 표 (후보 고르기용)
  py tools/sfx_game.py build [Name ...]    build/sfx_game/cand/<Name>_<v>.ogg (+ .wav), build/sfx_game/cand.json
  py tools/sfx_game.py sheet               art/review/sfx_candidates_2026-10-06.jpg (모양·주파수 한눈에)
  py tools/sfx_game.py pick Name=v ...     art/sfx/<Name>.ogg + art/sfx/sources.json (출처 장부)
  py tools/sfx_game.py final               FINAL 표대로 art/sfx를 다시 만든다(검수 lines_pack §6의 사건 키, 남는 옛 파일은 지움)
원본: build/devlog/sfx/{impact,interface}/Audio (Kenney Impact / Interface Sounds, CC0 1.0, docs/devlog/sfx_licenses.md).
합성 소리는 아래 함수가 만든다(우리 것). 모두 48 kHz 모노: 앞뒤 무음 자르기, 80 Hz 아래 덜기(전투 소리는 150 Hz,
검수 lines_pack_2026-10-06 §6), 가장 큰 100 ms가 -18 dBFS(RMS)가 되게 맞추고 최고점은 -3 dBFS 아래.
소리끼리의 크기는 게임 안 Volume 표(Config.Audio, 검수 §6)가 정한다.
"""

import json
import os
import shutil
import subprocess
import sys
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# build/ is git-ignored: a second worktree (Game-imgdev) reads the packs from the main Game folder
KENNEY = next((p for p in (os.path.join(ROOT, "build", "devlog", "sfx"),
                           os.path.join(os.path.dirname(ROOT), "Game", "build", "devlog", "sfx")) if os.path.isdir(p)),
              os.path.join(ROOT, "build", "devlog", "sfx"))
OUT = os.path.join(ROOT, "build", "sfx_game")
CAND = os.path.join(OUT, "cand")
FINAL_DIR = os.path.join(ROOT, "art", "sfx")
SHEET = os.path.join(ROOT, "art", "review", "sfx_candidates_2026-10-06.jpg")
SR = 48000
FFMPEG = shutil.which("ffmpeg") or "ffmpeg"
LOUD_DB = -18.0  # the loudest 100 ms (RMS) of every candidate (검수 lines_pack §6: files at RMS ~ -18 dB)
PEAK_DB = -3.0
# combat sounds get a 150 Hz high-pass (§6: phones play almost nothing below ~200 Hz; PCs would boom)
COMBAT_HP = ("Swing", "Hit", "KillPop", "Coin", "ComboCoin", "Skill")
PACKS = {"impact": "Kenney Impact Sounds 1.0", "interface": "Kenney Interface Sounds"}


# ------------------------------------------------------------------ sources
_kcache = {}


def kenney(name, speed=1.0):
    """'interface/open_001' -> mono float at SR (speed > 1 = higher and shorter, like Sound.PlaybackSpeed)"""
    if name not in _kcache:
        pack, base = name.split("/")
        path = os.path.join(KENNEY, pack, "Audio", base + ".ogg")
        r = subprocess.run([FFMPEG, "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                           capture_output=True, check=True)
        _kcache[name] = np.frombuffer(r.stdout, dtype=np.float32).astype(np.float64)
    return respeed(_kcache[name].copy(), speed)


def respeed(x, speed):
    if abs(speed - 1.0) < 1e-6 or len(x) < 2:
        return x
    if speed > 1.0:  # keep what would fold over the new Nyquist out
        x = svf(x, SR / 2 / speed * 0.9, 0.707, "lp")
    pos = np.arange(0, len(x) - 1, speed)
    return np.interp(pos, np.arange(len(x)), x)


# ------------------------------------------------------------------ building blocks
def secs(n):
    return np.arange(n) / SR


def count(d):
    return max(1, int(round(d * SR)))


def svf(x, fc, q=0.707, mode="bp"):
    """Zavalishin TPT state-variable filter (stable for any cutoff); fc may change per sample"""
    x = np.asarray(x, dtype=np.float64)
    fc = np.broadcast_to(np.clip(np.asarray(fc, dtype=np.float64), 10, SR * 0.45), x.shape)
    g = np.tan(np.pi * fc / SR)
    k = 1.0 / q
    a1 = 1.0 / (1.0 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    out = np.empty_like(x)
    ic1 = ic2 = 0.0
    for i in range(len(x)):
        v3 = x[i] - ic2
        v1 = a1[i] * ic1 + a2[i] * v3
        v2 = ic2 + a2[i] * ic1 + a3[i] * v3
        ic1 = 2 * v1 - ic1
        ic2 = 2 * v2 - ic2
        out[i] = v1 if mode == "bp" else (v2 if mode == "lp" else x[i] - k * v1 - v2)
    return out


def glide(n, f0, f1, curve=1.0):
    """exponential frequency path f0 -> f1 over n samples (curve > 1 = faster at the start)"""
    u = np.linspace(0, 1, n) ** (1.0 / curve)
    return f0 * (f1 / f0) ** u


def osc(freq, shape="sine", duty=0.5):
    """saw / pulse are summed from harmonics below 0.45 * SR (no aliasing whistles when the pitch moves)"""
    freq = np.asarray(freq, dtype=np.float64)
    ph = np.cumsum(freq) / SR
    if shape == "sine":
        return np.sin(2 * np.pi * ph)
    if shape == "tri":  # harmonics fall as 1/k^2: the naive shape is clean enough
        return 1 - 4 * np.abs(ph % 1.0 - 0.5)
    if shape not in ("saw", "pulse"):
        raise ValueError(shape)
    top = SR * 0.45
    out = np.zeros_like(ph)
    for k in range(1, min(200, int(top / max(freq.min(), 1.0))) + 1):
        fade = np.clip((top - k * freq) / (SR * 0.04), 0, 1)
        if not fade.any():
            break
        if shape == "saw":
            out += fade * ((-1) ** (k + 1)) * np.sin(2 * np.pi * k * ph) / k * (2 / np.pi)
        else:
            out += fade * np.sin(np.pi * k * duty) * np.cos(2 * np.pi * k * (ph - duty / 2)) / k * (4 / np.pi)
    return out


def env(n, attack=0.003, decay=10.0, hold=0.0):
    t = secs(n)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = np.exp(-np.maximum(t - attack - hold, 0) * decay)
    return a * d


def mix(parts):
    """[(signal, at_seconds, gain), ...] -> one signal"""
    end = max(int(round(at * SR)) + len(s) for s, at, _ in parts)
    out = np.zeros(end)
    for s, at, g in parts:
        i = int(round(at * SR))
        out[i:i + len(s)] += s * g
    return out


def rng(seed):
    return np.random.default_rng(seed)


def bell(freq, dur, decay=6.0, partials=((1, 1.0, 1.0), (2.0, 0.35, 1.6), (2.76, 0.18, 2.2), (5.4, 0.06, 3.5)),
         attack=0.0015):
    """struck bell / chime: (ratio, gain, decay multiplier) partials"""
    n = count(dur)
    t = secs(n)
    out = np.zeros(n)
    for ratio, gain, dm in partials:
        out += np.sin(2 * np.pi * freq * ratio * t) * gain * np.exp(-t * decay * dm)
    return out * np.clip(t / attack, 0, 1)


def sparkle(dur, grains=12, lo=2500, hi=6500, seed=1, level=0.15, gdur=0.03):
    r = rng(seed)
    out = np.zeros(count(dur + gdur))
    for _ in range(grains):
        at = r.uniform(0, dur)
        f = r.uniform(lo, hi)
        g = bell(f, gdur, decay=1 / gdur * 3, partials=((1, 1.0, 1.0),)) * level * r.uniform(0.5, 1.0)
        i = int(at * SR)
        out[i:i + len(g)] += g
    return out


# ------------------------------------------------------------------ synthesized sounds (ours)
def whoosh(dur=0.24, f0=600, f1=3200, f2=1400, q=1.4, peak=0.45, shing=0.0, seed=2):
    """swing: band-passed noise whose centre sweeps f0 -> f1 (at peak) -> f2; shing = a faint steel ring"""
    n = count(dur)
    u = np.linspace(0, 1, n)
    fc = np.where(u < peak, f0 * (f1 / f0) ** (u / peak), f1 * (f2 / f1) ** ((u - peak) / (1 - peak)))
    a = np.where(u < peak, (u / peak) ** 1.8, ((1 - u) / (1 - peak)) ** 2.2)
    y = svf(rng(seed).standard_normal(n), fc, q) * a
    if shing > 0:
        at = dur * peak * 0.8
        ring = mix([(bell(3150, 0.35, 9, ((1, 1, 1), (1.5, 0.6, 1.3), (1.99, 0.45, 1.6), (2.51, 0.3, 2.0))), at, 1.0)])
        y = mix([(y / max(1e-9, np.abs(y).max()), 0, 1.0), (ring / max(1e-9, np.abs(ring).max()), 0, shing)])
    return y


def magic(dur=0.34, f0=520, f1=1560, seed=4, zap=False):
    """cast: a rising (or falling 'zap') wobbly tone + sparkles + a soft air band"""
    n = count(dur)
    t = secs(n)
    f = glide(n, f1 * 1.5, f0 * 0.8, 0.6) if zap else glide(n, f0, f1, 1.6)
    f = f * (1 + 0.03 * np.sin(2 * np.pi * 9 * t))
    tone = osc(f) + 0.3 * osc(f * 2)
    if zap:
        tone = np.tanh(tone * 2.2)
    tone *= env(n, 0.015, 6.0 if not zap else 9.0)
    air = svf(rng(seed).standard_normal(n), glide(n, 1500, 4200), 1.2) * np.sin(np.pi * np.linspace(0, 1, n)) * 0.25
    sp = sparkle(dur * 0.85, 14, 2500, 6500, seed=seed, level=0.22)
    return mix([(tone, 0, 0.8), (air, 0, 1.0), (sp, 0.04, 1.0)])


def pluck_string(f0=165, dur=0.32, loss=0.996, seed=5):
    """Karplus-Strong string (the bow's twang)"""
    n = count(dur)
    period = int(SR / f0)
    buf = rng(seed).uniform(-1, 1, period)
    buf = svf(buf, 3000, 0.7, "lp")
    out = np.zeros(n)
    for i in range(n):
        j = i % period
        nxt = buf[(j + 1) % period]
        out[i] = buf[j]
        buf[j] = loss * 0.5 * (buf[j] + nxt)
    return out


def bow(f0=165, seed=5):
    twang = pluck_string(f0, 0.3, 0.982, seed) * env(count(0.3), 0.001, 7)
    thwip = svf(rng(seed + 1).standard_normal(count(0.05)), 3800, 1.5) * env(count(0.05), 0.001, 70)
    tail = whoosh(0.18, 1200, 3000, 1500, q=1.3, seed=seed + 2)
    return mix([(twang, 0, 1.0), (thwip, 0, 0.6), (tail, 0.025, 0.3)])


def whistle(two=False, seed=7):
    """the tamer's 'go!' whistle (pet attack)"""
    def note(f0, f1, d, hold_f=None):
        n = count(d)
        t = secs(n)
        f = glide(n, f0, f1, 2.5)
        if hold_f:
            f = np.minimum(f, hold_f)
        f = f * (1 + 0.015 * np.sin(2 * np.pi * 7 * t))
        breath = svf(rng(seed).standard_normal(n), 2800, 2.0) * 0.12
        a = np.clip(t / 0.01, 0, 1) * np.clip((d - t) / 0.04, 0, 1)
        return (osc(f) + breath) * a
    if two:
        return mix([(note(1500, 1700, 0.08), 0, 1.0), (note(2000, 2500, 0.09), 0.1, 1.0)])
    return note(1300, 2300, 0.22, 2250)


def pop(kind="bubble"):
    if kind == "bubble":  # rising bubble pop
        n = count(0.12)
        y = osc(glide(n, 380, 1250, 3.0)) * env(n, 0.001, 38)
        click = svf(rng(9).standard_normal(count(0.004)), 4000, 0.8, "hp") * 0.5
        return mix([(y, 0, 1.0), (click, 0, 1.0)])
    if kind == "plop":  # falling plop
        n = count(0.14)
        f = glide(n, 1100, 420, 2.5)
        y = (osc(f) + 0.25 * osc(f * 2)) * env(n, 0.001, 30)
        return y
    raise ValueError(kind)


def coin(kind="ting"):
    if kind == "ting":  # one bright bell; the game raises it a semitone per combo kill (PlaybackSpeed)
        return bell(1318.5, 0.5, 8.0, ((1, 1.0, 1.0), (2.0, 0.4, 1.4), (3.0, 0.15, 2.0), (4.16, 0.08, 3.0)))
    if kind == "ching":  # two quick coins
        a = bell(1318.5, 0.18, 14.0, ((1, 1.0, 1.0), (2.0, 0.4, 1.4), (3.0, 0.15, 2.0)))
        b = bell(1975.5, 0.5, 8.0, ((1, 1.0, 1.0), (2.0, 0.4, 1.4), (3.0, 0.15, 2.0), (4.16, 0.08, 3.0)))
        return mix([(a, 0, 0.7), (b, 0.055, 1.0)])
    raise ValueError(kind)


def fanfare(chip=False, seed=11):
    """level up: C5 E5 G5 C6 arpeggio, the last note rings with a little vibrato, sparkles on top"""
    notes = [523.25, 659.25, 783.99, 1046.5]
    parts = []
    for i, f in enumerate(notes):
        last = i == len(notes) - 1
        d = 0.75 if last else 0.2
        n = count(d)
        t = secs(n)
        ff = f * (1 + (0.012 * np.sin(2 * np.pi * 6 * t) * np.clip((t - 0.25) / 0.2, 0, 1) if last else np.zeros(n)))
        if chip:
            tone = osc(ff, "pulse", 0.25) * 0.6
            tone = svf(tone, 5000, 0.7, "lp")
        else:
            tone = osc(ff) + 0.35 * osc(ff * 2) + 0.12 * osc(ff * 3)
        tone *= env(n, 0.004, 3.2 if last else 9.0)
        parts.append((tone, i * 0.075, 1.0 if last else 0.85))
    rise = svf(rng(seed).standard_normal(count(0.3)), glide(count(0.3), 1000, 5000), 1.2) * np.sin(np.pi * np.linspace(0, 1, count(0.3)))
    parts.append((rise, 0.0, 0.18))
    parts.append((sparkle(0.45, 12, 3000, 7000, seed=seed, level=0.25), 0.25, 1.0))
    return mix(parts)


def chime(seed=13, soft=False):
    """purify: a shimmering E-major chime cluster ('찰랑')"""
    notes = [1318.5, 1661.2, 1975.5, 2637.0] if not soft else [2637.0, 1975.5, 1661.2, 1975.5, 2637.0]
    parts = []
    for i, f in enumerate(notes):
        parts.append((bell(f, 1.0, 3.6, ((1, 1.0, 1.0), (2.0, 0.25, 1.5), (3.0, 0.08, 2.0))), i * (0.045 if not soft else 0.07), 1.0))
    parts.append((sparkle(0.5, 16, 3500, 8000, seed=seed, level=0.2, gdur=0.04), 0.05, 1.0))
    return mix(parts)


def gulp(seed=17, wah=False):
    """devour: a cartoon slurp + wobbling 'bwomp' down-sweep + a little gulp (harmonics so phones hear it)"""
    n = count(0.4)
    t = secs(n)
    f = glide(n, 330, 115, 1.4) * (1 + 0.06 * np.sin(2 * np.pi * 13 * t))
    body = osc(f) + 0.55 * osc(f * 2) + 0.3 * osc(f * 3) + 0.12 * osc(f * 4)
    if wah:
        body = svf(osc(f, "saw"), glide(n, 1400, 380, 1.5), 3.0) * 1.6
    body *= env(n, 0.02, 3.0) * np.clip((0.4 - t) / 0.06, 0, 1)
    body = svf(body, 2600, 0.7, "lp")
    m = count(0.09)
    slurp = svf(rng(seed).standard_normal(m), glide(m, 500, 1800), 4.0) * np.sin(np.pi * np.linspace(0, 1, m))
    k = count(0.06)
    gl = osc(glide(k, 260, 140)) * env(k, 0.002, 40) + 0.4 * osc(glide(k, 520, 280)) * env(k, 0.002, 40)
    return mix([(slurp, 0, 0.45), (body, 0.05, 1.0), (gl, 0.42, 0.7)])


def boom(dur=0.9):
    n = count(dur)
    t = secs(n)
    f = 110 * np.exp(-t * 2.5) + 55
    low = (osc(f) + 0.5 * osc(f * 2) + 0.25 * osc(f * 3)) * env(n, 0.004, 4.0)
    rumble = svf(rng(19).standard_normal(n), 240, 0.8, "lp") * env(n, 0.01, 3.0) * 2.0
    return low + rumble


def brass_hits(seed=23):
    """king (synth only): 'dun... DUN' low brass + a bell ring"""
    def hit(f, d, g):
        n = count(d)
        t = secs(n)
        tone = osc(np.full(n, f), "saw") + 0.7 * osc(np.full(n, f * 1.5), "saw")
        tone = svf(tone, 900 + 900 * np.exp(-t * 6), 1.2, "lp") * env(n, 0.012, 3.5) * g
        return tone
    ring = bell(392.0, 1.4, 2.2, ((1, 1.0, 1.0), (2.0, 0.4, 1.5), (2.76, 0.25, 2.0), (5.4, 0.08, 3.0)))
    return mix([(hit(98, 0.35, 0.7), 0, 1.0), (hit(98, 0.9, 1.0), 0.38, 1.0), (ring, 0.38, 0.5), (boom(0.8), 0.38, 0.5)])


def honk(two=False, seed=29):
    """goose: a rough nasal saw through three formants"""
    def one(f0, d):
        n = count(d)
        t = secs(n)
        f = glide(n, f0, f0 * 0.86, 1.2)
        src = osc(f, "saw") * (1 + 0.25 * np.sin(2 * np.pi * 34 * t))
        y = svf(src, 950, 3.0) + 0.7 * svf(src, 1750, 4.0) + 0.35 * svf(src, 2700, 5.0)
        a = np.clip(t / 0.012, 0, 1) * np.clip((d - t) / 0.05, 0, 1)
        return y * a
    if two:
        return mix([(one(450, 0.16), 0, 0.9), (one(490, 0.2), 0.22, 1.0)])
    return one(470, 0.26)


def blip(kind="tri"):
    """talk blips (Audio.Talk changes PlaybackSpeed per speaker)"""
    if kind == "tri":
        n = count(0.05)
        y = osc(glide(n, 540, 500), "tri") * env(n, 0.003, 45)
        return svf(y, 3000, 0.7, "lp")
    if kind == "boop":
        n = count(0.04)
        return osc(glide(n, 760, 830)) * env(n, 0.002, 55)
    if kind == "square":
        n = count(0.045)
        y = osc(np.full(n, 440.0), "pulse", 0.5) * env(n, 0.003, 50)
        return svf(y, 2200, 0.7, "lp")
    raise ValueError(kind)


def squish(seed=31):
    """slime hit alternative: a wet blob (noise through a falling resonance + a soft low wobble)"""
    n = count(0.16)
    t = secs(n)
    wet = svf(rng(seed).standard_normal(n), glide(n, 1600, 380, 2.0), 3.5) * env(n, 0.002, 22)
    wob = osc(glide(n, 240, 150) * (1 + 0.08 * np.sin(2 * np.pi * 22 * t))) * env(n, 0.004, 20)
    return mix([(wet, 0, 0.8), (wob, 0, 0.6)])


def drive(x, k=3.0):
    """soft saturation: gives a bass thud harmonics a phone speaker can play"""
    x = np.asarray(x, dtype=np.float64)
    pk = max(1e-9, np.abs(x).max())
    return np.tanh(k * x / pk) / np.tanh(k)


def snap(seed=37, f=2400, d=0.02):
    n = count(d)
    return svf(rng(seed).standard_normal(n), f, 1.2) * env(n, 0.0005, 160)


def uh_uh():
    """'no': two short falling notes (soft square)"""
    def note(f, d):
        n = count(d)
        y = osc(glide(n, f, f * 0.94), "pulse", 0.5) * env(n, 0.004, 14) * np.clip((d - secs(n)) / 0.02, 0, 1)
        return svf(y, 1800, 0.7, "lp")
    return mix([(note(466.2, 0.1), 0, 1.0), (note(349.2, 0.16), 0.13, 1.0)])


def two_blips(up=True):
    """auto ON (up) / OFF (down)"""
    lo, hi = 1046.5, 1568.0
    a, b = (lo, hi) if up else (hi, lo)

    def note(f, d):
        n = count(d)
        return (osc(np.full(n, f)) + 0.3 * osc(np.full(n, 2 * f))) * env(n, 0.002, 30)
    return mix([(note(a, 0.07), 0, 0.9), (note(b, 0.12), 0.075, 1.0)])


# ------------------------------------------------------------------ the candidate list
def K(name, speed=1.0):
    return lambda: kenney(name, speed)


def KS(name, speed=1.0):
    pack, base = name.split("/")
    return f"{PACKS[pack]} · {base}.ogg (CC0)" + ("" if speed == 1.0 else f" · speed {speed}")


SYN = "synth · tools/sfx_game.py (ours)"

# Name -> [(variant, note, make(), [sources])]; the game uses Name (Audio.luau SOUNDS)
SPEC = {}


def add(name, v, note, make, sources):
    SPEC.setdefault(name, []).append((v, note, make, sources))


def honk_pair():
    """§6: a nasal 'honk' 0.15 s x 2, 500-700 Hz, the end falling"""
    def one(f0, d):
        n = count(d)
        tt = secs(n)
        f = glide(n, f0, f0 * 0.82, 1.4)
        src = osc(f, "saw") * (1 + 0.2 * np.sin(2 * np.pi * 30 * tt))
        y = svf(src, 1000, 3.0) + 0.7 * svf(src, 1800, 4.0) + 0.3 * svf(src, 2800, 5.0)
        a = np.clip(tt / 0.01, 0, 1) * np.clip((d - tt) / 0.04, 0, 1)
        return y * a
    return mix([(one(620, 0.15), 0, 0.9), (one(680, 0.15), 0.21, 1.0)])


def KL(name, speed=1.0, k=None, hp=None):
    """a Kenney file; hp = high-pass first (Hz), k = saturate (so a bass thud keeps a body a phone can play)"""
    x = kenney(name, speed)
    if hp:
        x = svf(x, hp, 0.707, "hp")
    return drive(x, k) if k else x


add("SwingBlade", "a", "steel swish (Warrior; Blacksmith 0.85x, Punch 1.3x)", lambda: whoosh(0.24, 600, 3200, 1400, q=1.6, shing=0.18, seed=2), [SYN])
add("SwingBlade", "b", "airy swish, no ring", lambda: whoosh(0.30, 420, 2100, 700, q=0.9, seed=3), [SYN])
add("SwingBlade", "c", "double swish", lambda: mix([(whoosh(0.16, 700, 3000, 1200, q=1.4, seed=5), 0, 0.8), (whoosh(0.2, 600, 2600, 900, q=1.2, seed=6), 0.07, 1.0)]), [SYN])
add("SwingMagic", "a", "rising wobble + sparkles (Mage; Alchemist 0.9x)", lambda: magic(), [SYN])
add("SwingMagic", "b", "falling zap + sparkles", lambda: magic(zap=True), [SYN])
add("SwingMagic", "c", "short bright rise", lambda: magic(0.26, 700, 2100, seed=8), [SYN])
add("SwingBow", "a", "string twang + arrow swish (Archer)", lambda: bow(165), [SYN])
add("SwingBow", "b", "higher twang", lambda: bow(220, seed=6), [SYN])
add("SwingBow", "c", "Kenney pluck low + swish", lambda: mix([(KL("interface/pluck_002", 0.55), 0, 1.0), (whoosh(0.18, 1200, 3000, 1500, q=1.3, seed=9), 0.02, 0.35)]),
    [KS("interface/pluck_002", 0.55), SYN])
add("SwingWhistle", "a", "one rising whistle (Tamer pet attack)", lambda: whistle(), [SYN])
add("SwingWhistle", "b", "two-note 'fwee-fwit'", lambda: whistle(two=True), [SYN])

add("HitThud", "a", "punch + wooden tok on top (goblins, players)", lambda: mix([(KL("impact/impactPunch_medium_001", k=3.0, hp=200), 0, 1.0), (KL("impact/impactGeneric_light_000"), 0, 1.0)]),
    [KS("impact/impactPunch_medium_001") + " · saturated", KS("impact/impactGeneric_light_000")])
add("HitThud", "b", "punch + snap", lambda: mix([(KL("impact/impactPunch_medium_003", k=3.0, hp=200), 0, 1.0), (snap(), 0, 0.7), (KL("impact/impactTin_medium_001"), 0, 0.5)]),
    [KS("impact/impactPunch_medium_003") + " · saturated", SYN, KS("impact/impactTin_medium_001")])
add("HitThud", "c", "light tok + soft punch", lambda: mix([(KL("impact/impactGeneric_light_002"), 0, 1.0), (KL("impact/impactPunch_medium_000", k=2.0, hp=140), 0, 0.5)]),
    [KS("impact/impactGeneric_light_002"), KS("impact/impactPunch_medium_000") + " · saturated"])
add("HitSquish", "a", "wet blob (slimes)", lambda: squish(), [SYN])
add("HitSquish", "b", "soft thud saturated + blob", lambda: mix([(KL("impact/impactSoft_medium_001", k=4.0, hp=120), 0, 0.8), (squish(seed=33), 0, 0.7)]),
    [KS("impact/impactSoft_medium_001") + " · saturated", SYN])
add("HitSquish", "c", "low bloop + soft thud", lambda: mix([(KL("interface/drop_003", 0.7), 0, 0.8), (KL("impact/impactSoft_medium_002", k=4.0, hp=120), 0, 0.6)]),
    [KS("interface/drop_003", 0.7), KS("impact/impactSoft_medium_002") + " · saturated"])
add("HitClack", "a", "dry wood knock, higher (skeletons)", lambda: KL("impact/impactWood_light_000", 1.25), [KS("impact/impactWood_light_000", 1.25)])
add("HitClack", "b", "wood + tin rattle", lambda: mix([(KL("impact/impactWood_light_002", 1.4), 0, 1.0), (KL("impact/impactTin_medium_000", 1.2), 0.012, 0.45)]),
    [KS("impact/impactWood_light_002", 1.4), KS("impact/impactTin_medium_000", 1.2)])
add("HitClack", "c", "light tok, higher", lambda: KL("impact/impactGeneric_light_003", 1.2), [KS("impact/impactGeneric_light_003", 1.2)])
add("HitCrit", "a", "heavy punch + tok + snap (critical hit)", lambda: mix([(KL("impact/impactPunch_heavy_002", k=3.0, hp=200), 0, 1.0), (KL("impact/impactGeneric_light_001"), 0, 1.0), (snap(seed=41, f=3000), 0, 0.8)]),
    [KS("impact/impactPunch_heavy_002") + " · saturated", KS("impact/impactGeneric_light_001"), SYN])
add("HitCrit", "b", "heavy punch + tin clank", lambda: mix([(KL("impact/impactPunch_heavy_000", k=3.0, hp=200), 0, 1.0), (KL("impact/impactTin_medium_003"), 0, 1.0)]),
    [KS("impact/impactPunch_heavy_000") + " · saturated", KS("impact/impactTin_medium_003")])
add("HitCrit", "c", "heavy punch + metal ring", lambda: mix([(KL("impact/impactPunch_heavy_003", k=3.0, hp=200), 0, 1.0), (KL("impact/impactMetal_light_001"), 0, 0.6), (KL("impact/impactGeneric_light_004"), 0, 0.7)]),
    [KS("impact/impactPunch_heavy_003") + " · saturated", KS("impact/impactMetal_light_001"), KS("impact/impactGeneric_light_004")])

add("KillPop", "a", "rising bubble pop", lambda: pop("bubble"), [SYN])
add("KillPop", "b", "Kenney bloop", lambda: KL("interface/drop_002"), [KS("interface/drop_002")])
add("KillPop", "c", "falling plop", lambda: pop("plop"), [SYN])
add("Coin", "a", "one bright ting (combo raises it a semitone per kill)", lambda: coin("ting"), [SYN])
add("Coin", "b", "two quick coins", lambda: coin("ching"), [SYN])
add("Coin", "c", "Kenney glass clink", lambda: KL("interface/glass_001"), [KS("interface/glass_001")])
add("LevelUp", "a", "bell arpeggio C-E-G-C + sparkles", lambda: fanfare(), [SYN])
add("LevelUp", "b", "chiptune arpeggio + sparkles", lambda: fanfare(chip=True), [SYN])
add("LevelUp", "c", "Kenney rising confirmation + sparkles", lambda: mix([(KL("interface/confirmation_004"), 0, 1.0), (sparkle(0.4, 10, 3000, 7000, seed=12, level=0.25), 0.2, 1.0)]),
    [KS("interface/confirmation_004"), SYN])

add("WindowOpen", "a", "soft rising blip 1.1-1.5 kHz", lambda: KL("interface/maximize_009"), [KS("interface/maximize_009")])
add("WindowOpen", "b", "bright rising blip 2.2-2.9 kHz", lambda: KL("interface/maximize_007"), [KS("interface/maximize_007")])
add("WindowOpen", "c", "low rising bwoop", lambda: KL("interface/maximize_008", k=2.0), [KS("interface/maximize_008") + " · saturated"])
add("WindowClose", "a", "soft falling blip", lambda: KL("interface/minimize_009"), [KS("interface/minimize_009")])
add("WindowClose", "b", "bright falling blip", lambda: KL("interface/minimize_007"), [KS("interface/minimize_007")])
add("WindowClose", "c", "low falling bwoop", lambda: KL("interface/minimize_008", k=2.0), [KS("interface/minimize_008") + " · saturated"])
add("No", "a", "'uh-uh' two falling notes", lambda: uh_uh(), [SYN])
add("No", "b", "Kenney two-tone error", lambda: KL("interface/error_007"), [KS("interface/error_007")])
add("No", "c", "Kenney short buzz", lambda: KL("interface/error_004"), [KS("interface/error_004")])
add("AutoOn", "a", "two rising blips", lambda: two_blips(True), [SYN])
add("AutoOn", "b", "Kenney rising toggle", lambda: KL("interface/toggle_002"), [KS("interface/toggle_002")])
add("AutoOff", "a", "two falling blips", lambda: two_blips(False), [SYN])
add("AutoOff", "b", "Kenney toggle, lower", lambda: KL("interface/toggle_001", 0.75), [KS("interface/toggle_001", 0.75)])
add("Click", "a", "Kenney high blip", lambda: KL("interface/select_001"), [KS("interface/select_001")])
add("Click", "b", "Kenney short click", lambda: KL("interface/click_002"), [KS("interface/click_002")])
add("Click", "c", "Kenney soft pop", lambda: KL("interface/back_004"), [KS("interface/back_004")])
add("Reward", "a", "Kenney three rising notes (quest reward)", lambda: KL("interface/confirmation_001"), [KS("interface/confirmation_001")])
add("Reward", "b", "Kenney bright rising chime", lambda: KL("interface/confirmation_003"), [KS("interface/confirmation_003")])

add("Purify", "a", "shimmering E-major chime", lambda: chime(), [SYN])
add("Purify", "b", "softer twinkle down-up", lambda: chime(seed=14, soft=True), [SYN])
add("Purify", "c", "Kenney glass jingle", lambda: mix([(KL("interface/glass_001"), 0, 1.0), (KL("interface/glass_005", 1.2), 0.06, 0.8), (KL("interface/glass_006", 1.5), 0.12, 0.7)]),
    [KS("interface/glass_001"), KS("interface/glass_005", 1.2), KS("interface/glass_006", 1.5)])
add("Devour", "a", "slurp + wobbly 'bwomp' + gulp", lambda: gulp(), [SYN])
add("Devour", "b", "wah 'bwoomp'", lambda: gulp(seed=18, wah=True), [SYN])
add("KingArrive", "a", "deep bell + boom (Pumpkin / Ghost King appears)", lambda: mix([(KL("impact/impactBell_heavy_000", 0.8), 0, 1.0), (KL("impact/impactBell_heavy_000", 1.6), 0.004, 0.45), (boom(), 0, 0.5)]),
    [KS("impact/impactBell_heavy_000", 0.8), KS("impact/impactBell_heavy_000", 1.6), SYN])
add("KingArrive", "b", "'dun... DUN' low brass + bell", lambda: brass_hits(), [SYN])
add("KingArrive", "c", "two deep bells + boom", lambda: mix([(KL("impact/impactBell_heavy_003", 0.75), 0, 1.0), (KL("impact/impactBell_heavy_000", 0.6), 0.03, 0.8), (boom(), 0, 0.5)]),
    [KS("impact/impactBell_heavy_003", 0.75), KS("impact/impactBell_heavy_000", 0.6), SYN])
add("GooseHonk", "a", "one nasal honk", lambda: honk(), [SYN])
add("GooseHonk", "b", "'honk-honk'", lambda: honk(two=True), [SYN])
add("TalkBlip", "a", "soft triangle blip (speakers change its pitch)", lambda: blip("tri"), [SYN])
add("TalkBlip", "b", "sine 'boop'", lambda: blip("boop"), [SYN])
add("TalkBlip", "c", "Kenney low blip", lambda: KL("interface/select_002"), [KS("interface/select_002")])

# ---- 검수 lines_pack_2026-10-06 §6 (the table's event keys): recipes the first round did not have
add("SwingWarrior", "a", "short airy whoosh 0.18 s, 500-3000 Hz (§6 #1)", lambda: whoosh(0.18, 500, 3000, 900, q=1.1, seed=3), [SYN])
add("HitSoft", "b", "wet blob, second take (§6 #4 variant)", lambda: squish(seed=47), [SYN])
add("Devour", "c", "bong 0.9x + drop 0.75x, a pleasant gulp (§6 #16)",
    lambda: mix([(KL("interface/bong_001", 0.9), 0, 1.0), (KL("interface/drop_004", 0.75), 0.05, 0.8)]),
    [KS("interface/bong_001", 0.9), KS("interface/drop_004", 0.75)])
add("KingBell", "a", "playful big bell + a little pop at the end (§6 #17 / 17b)",
    lambda: mix([(KL("impact/impactBell_heavy_000"), 0, 1.0), (KL("interface/maximize_006"), 1.15, 0.45)]),
    [KS("impact/impactBell_heavy_000"), KS("interface/maximize_006")])
add("GooseHonk", "c", "two nasal honks 0.15 s, 620 / 680 Hz falling (§6 #18)", lambda: honk_pair(), [SYN])
add("GoldPickup", "a", "Kenney tick (§6 #20, the devlog coin)", lambda: KL("interface/tick_004"), [KS("interface/tick_004")])
add("ScrollSuccess", "a", "rising confirmation + glass sparkle (§6 #21)",
    lambda: mix([(KL("interface/confirmation_004"), 0, 1.0), (KL("interface/glass_004"), 0.22, 0.35)]),
    [KS("interface/confirmation_004"), KS("interface/glass_004")])
add("ScrollFail", "a", "small 'aw' (§6 #22)", lambda: KL("interface/back_002"), [KS("interface/back_002")])
add("Tap", "a", "soft low blip (§6 #23)", lambda: KL("interface/select_002"), [KS("interface/select_002")])
add("SkillHalo", "a", "glass ping, the Halo layer of X (§6 #25)", lambda: KL("interface/glass_005"), [KS("interface/glass_005")])
add("SkillHorns", "a", "bong, the Horns layer of X (§6 #26)", lambda: KL("interface/bong_001"), [KS("interface/bong_001")])
add("SkillHorns", "b", "bong with a body phones can play (saturated + an octave up)",
    lambda: mix([(KL("interface/bong_001", 1.5, k=2.5), 0, 1.0), (KL("interface/bong_001", 3.0), 0, 0.4)]),
    [KS("interface/bong_001", 1.5) + " · saturated", KS("interface/bong_001", 3.0)])
add("Potion", "a", "glass clink (§6 #28)", lambda: KL("interface/glass_003"), [KS("interface/glass_003")])
add("QuestNew", "a", "rising select chime (§6 #29)", lambda: KL("interface/select_003"), [KS("interface/select_003")])
add("RankDown", "a", "small soft pop (§6 #30)", lambda: KL("interface/back_004"), [KS("interface/back_004")])

# game event key (Config.Audio.Sounds, 검수 §6) -> the candidate it uses ("Name:v")
FINAL = {
    "SwingWarrior": "SwingWarrior:a", "SwingMage": "SwingMagic:c", "SwingArcher": "SwingBow:a", "SwingTamer": "SwingWhistle:a",
    "HitSoft1": "HitSquish:a", "HitSoft2": "HitSoft:b", "HitHeavy1": "HitThud:c", "HitHeavy2": "HitThud:a",
    "KillPop": "KillPop:b", "ComboCoin": "Coin:a", "ComboMilestone": "Reward:b", "LevelUp": "LevelUp:a",
    "WindowOpen": "WindowOpen:a", "WindowClose": "WindowClose:a", "Deny": "No:a", "AutoOn": "AutoOn:a", "AutoOff": "AutoOff:a",
    "Purify": "Purify:a", "Devour": "Devour:c", "KingBell": "KingBell:a", "GooseHonk": "GooseHonk:c",
    "QuestDone": "Reward:a", "GoldPickup": "GoldPickup:a", "ScrollSuccess": "ScrollSuccess:a", "ScrollFail": "ScrollFail:a",
    "Tap": "Tap:a", "SkillHalo": "SkillHalo:a", "SkillHorns": "SkillHorns:b", "Potion": "Potion:a", "QuestNew": "QuestNew:a",
    "RankDown": "RankDown:a", "TalkBlip": "TalkBlip:a",
}


# ------------------------------------------------------------------ analysis / output
def finish(x, hp=80.0):
    x = np.asarray(x, dtype=np.float64)
    x = x - np.mean(x)
    x = svf(x, hp, 0.707, "hp")
    a = np.abs(x)
    if a.max() <= 0:
        return x
    thr = a.max() * 10 ** (-50 / 20)
    idx = np.nonzero(a > thr)[0]
    x = x[max(0, idx[0] - count(0.001)):idx[-1] + count(0.01)]
    fi, fo = count(0.002), min(count(0.025), len(x) // 3)
    x[:fi] *= np.linspace(0, 1, fi)
    x[-fo:] *= np.linspace(1, 0, fo)
    loud = loudest(x)
    x = x * 10 ** ((LOUD_DB - loud) / 20)
    peak = np.abs(x).max()
    lim = 10 ** (PEAK_DB / 20)
    if peak > lim:
        x = x * (lim / peak)
    return x


def loudest(x, win=0.1):
    w = min(len(x), count(win))
    c = np.concatenate([[0.0], np.cumsum(x * x)])
    rms = np.sqrt((c[w:] - c[:-w]) / w)
    return 20 * np.log10(max(rms.max(), 1e-9))


def metrics(x):
    """loudness, brightness, phone audibility (a phone speaker gives almost nothing below ~400 Hz) and the pitch path"""
    x = np.asarray(x, dtype=np.float64) - np.mean(x)
    spec = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    spec[fr < 20] = 0
    tot = spec.sum() + 1e-12
    loud = loudest(x)
    phone = loudest(svf(svf(x, 400, 0.707, "hp"), 400, 0.707, "hp"))
    flat = np.exp(np.mean(np.log(spec[(fr > 100) & (fr < 10000)] + 1e-12))) / (np.mean(spec[(fr > 100) & (fr < 10000)]) + 1e-12)
    return {
        "sec": round(len(x) / SR, 3),
        "peakDb": round(20 * np.log10(max(np.abs(x).max(), 1e-9)), 1),
        "loud100Db": round(loud, 1),
        "phoneDropDb": round(loud - phone, 1),  # how much quieter on a phone speaker (high-passed at 400 Hz)
        "centroidHz": int((fr * spec).sum() / tot),
        "below300": round(float(spec[fr < 300].sum() / tot), 3),
        "above8k": round(float(spec[fr > 8000].sum() / tot), 3),
        "noisy": round(float(flat), 3),  # spectral flatness 100 Hz-10 kHz: ~0 = tone, ~1 = noise
        "peakAt": round(float(np.argmax(np.abs(x)) / SR), 3),
        "pitch": pitch_path(x),
    }


def pitch_path(x, frame=2048, hop=480):
    """the strongest frequency (100 Hz - 8 kHz) at 10 %, 50 % and 90 % of the sound's loud part"""
    if len(x) < frame:
        x = np.pad(x, (0, frame - len(x)))
    win = np.hanning(frame)
    fr = np.fft.rfftfreq(frame, 1 / SR)
    band = (fr > 100) & (fr < 8000)
    frames = []
    for i in range(0, len(x) - frame + 1, hop):
        s = np.abs(np.fft.rfft(x[i:i + frame] * win)) ** 2
        frames.append((s.sum(), fr[band][np.argmax(s[band])]))
    if not frames:
        return []
    e = np.array([f[0] for f in frames])
    keep = [f for f in frames if f[0] > e.max() * 10 ** (-25 / 10)]
    return [int(keep[min(len(keep) - 1, int(len(keep) * q))][1]) for q in (0.1, 0.5, 0.9)]


def write_wav(path, x):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def to_ogg(wav, ogg):
    subprocess.run([FFMPEG, "-v", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "6", ogg], check=True)


def scan(families):
    rows = []
    for pack in ("impact", "interface"):
        d = os.path.join(KENNEY, pack, "Audio")
        for f in sorted(os.listdir(d)):
            base = f[:-4]
            fam = base.rsplit("_", 1)[0]
            if families and fam not in families and base not in families:
                continue
            x = kenney(f"{pack}/{base}")
            m = metrics(x)
            rows.append((f"{pack}/{base}", m))
            print(f"{pack}/{base:28s} {m['sec']:6.3f}s loud {m['loud100Db']:6.1f} phone-{m['phoneDropDb']:4.1f} "
                  f"centroid {m['centroidHz']:5d} <300 {m['below300']:.2f} >8k {m['above8k']:.2f} noisy {m['noisy']:.2f} "
                  f"peakAt {m['peakAt']:.3f} pitch {m['pitch']}")
    return rows


def build(names):
    os.makedirs(CAND, exist_ok=True)
    meta_path = os.path.join(OUT, "cand.json")
    meta = {}
    if os.path.exists(meta_path):
        with open(meta_path, encoding="utf-8") as f:
            meta = json.load(f)
    for name, variants in SPEC.items():
        if names and name not in names:
            continue
        meta[name] = []
        for v, note, make, sources in variants:
            x = finish(make(), hp=150.0 if name.startswith(COMBAT_HP) else 80.0)
            stem = os.path.join(CAND, f"{name}_{v}")
            write_wav(stem + ".wav", x)
            to_ogg(stem + ".wav", stem + ".ogg")
            m = metrics(x)
            meta[name].append({"v": v, "note": note, "sources": sources, "file": os.path.relpath(stem + ".ogg", ROOT).replace("\\", "/"),
                               "oggBytes": os.path.getsize(stem + ".ogg"), **m})
            print(f"{name}_{v}: {m['sec']}s phone-{m['phoneDropDb']} centroid {m['centroidHz']} <300 {m['below300']} "
                  f"noisy {m['noisy']} pitch {m['pitch']} | {note}")
    with open(meta_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)
    return meta


def read_wav(path):
    with wave.open(path) as w:
        return np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768.0


def spectro_tile(x, w=300, h=96, lo=100.0, hi=12000.0):
    """log-frequency spectrogram (dB, 60 dB range) with the waveform envelope in white; time spans max(sound, 0.6 s)"""
    from PIL import Image, ImageDraw
    span = max(len(x), count(0.6))
    x = np.pad(x, (0, span - len(x)))
    frame = 1024
    hop = max(1, (span - frame) // w)
    fr = np.fft.rfftfreq(frame, 1 / SR)
    rows = np.geomspace(lo, hi, h)[::-1]
    img = np.zeros((h, w))
    win = np.hanning(frame)
    xp = np.pad(x, (0, frame))
    for c in range(w):
        s = np.abs(np.fft.rfft(xp[c * hop:c * hop + frame] * win))
        img[:, c] = np.interp(rows, fr, s)
    db = 20 * np.log10(img + 1e-9)
    db = np.clip((db - (db.max() - 60)) / 60, 0, 1)
    rgb = np.stack([db ** 0.7 * 255, db ** 1.6 * 200, (1 - db) * 60 + db * 40], -1).astype(np.uint8)
    im = Image.fromarray(rgb, "RGB")
    d = ImageDraw.Draw(im)
    env_pts = []
    for c in range(w):
        seg = x[c * hop:c * hop + hop]
        a = np.abs(seg).max() if len(seg) else 0
        env_pts.append((c, h - 1 - a * (h - 4)))
    d.line(env_pts, fill=(255, 255, 255), width=1)
    for f in (300, 1000, 3000, 8000):
        y = int(np.interp(f, rows[::-1], np.arange(h)[::-1]))
        d.line([(0, y), (6, y)], fill=(150, 220, 255))
    return im


def sheet():
    from PIL import Image, ImageDraw, ImageFont
    with open(os.path.join(OUT, "cand.json"), encoding="utf-8") as f:
        meta = json.load(f)
    tw, th, lab = 300, 96, 34
    names = list(meta)
    cols = max(len(v) for v in meta.values())
    out = Image.new("RGB", (140 + cols * (tw + 8), len(names) * (th + lab + 6) + 30), (14, 16, 26))
    d = ImageDraw.Draw(out)
    try:
        font = ImageFont.truetype("arial.ttf", 13)
        big = ImageFont.truetype("arialbd.ttf", 15)
    except OSError:
        font = big = ImageFont.load_default()
    d.text((8, 6), "game SFX candidates: log-frequency 100 Hz-12 kHz (ticks 300/1k/3k/8k), white = loudness; 0.6 s min width",
           fill=(220, 220, 230), font=font)
    for r, name in enumerate(names):
        y = 30 + r * (th + lab + 6)
        d.text((8, y + 40), name, fill=(255, 230, 140), font=big)
        for c, cand in enumerate(meta[name]):
            x0 = 140 + c * (tw + 8)
            wav = os.path.join(ROOT, cand["file"][:-4] + ".wav")
            if not os.path.exists(wav):
                continue
            out.paste(spectro_tile(read_wav(wav), tw, th), (x0, y + lab))
            d.text((x0, y), f'{cand["v"]}  {cand["sec"]}s  phone -{cand["phoneDropDb"]} dB', fill=(255, 255, 255), font=font)
            d.text((x0, y + 16), cand["note"][:46], fill=(170, 180, 200), font=font)
    os.makedirs(os.path.dirname(SHEET), exist_ok=True)
    out.save(SHEET, quality=90)
    return SHEET


def license_of(sources):
    parts = []
    if any("Kenney" in s for s in sources):
        parts.append("CC0 1.0 (Kenney.nl packs, License.txt in the zip)")
    if any(s == SYN for s in sources):
        parts.append("our own synthesis (no third-party material)")
    return " + ".join(parts)


def pick(choices):
    """Name=v ... -> art/sfx/<Name>.ogg (the candidate's file) + art/sfx/sources.json (provenance per game sound)"""
    with open(os.path.join(OUT, "cand.json"), encoding="utf-8") as f:
        meta = json.load(f)
    os.makedirs(FINAL_DIR, exist_ok=True)
    src_path = os.path.join(FINAL_DIR, "sources.json")
    book = {}
    if os.path.exists(src_path):
        with open(src_path, encoding="utf-8") as f:
            book = json.load(f)
    for arg in choices:
        name, v = arg.split("=")
        src_name, v = v.split(":") if ":" in v else (name, v)
        cand = next((c for c in meta.get(src_name, []) if c["v"] == v), None)
        if not cand:
            raise SystemExit(f"no candidate {src_name}_{v}")
        dst = os.path.join(FINAL_DIR, name + ".ogg")
        shutil.copyfile(os.path.join(ROOT, cand["file"]), dst)
        book[name] = {"file": os.path.relpath(dst, ROOT).replace("\\", "/"), "candidate": f"{src_name}_{v}", "note": cand["note"],
                      "sources": cand["sources"], "license": license_of(cand["sources"]),
                      "sec": cand["sec"], "phoneDropDb": cand["phoneDropDb"], "bytes": os.path.getsize(dst),
                      "made": "tools/sfx_game.py build (48 kHz mono, -14 dBFS loudest 100 ms, peak <= -1 dBFS)"}
        print(name, "<-", v, cand["note"])
    with open(src_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(dict(sorted(book.items())), f, ensure_ascii=False, indent=1)
    return book


def final():
    """art/sfx = exactly the FINAL table: rebuild the book, drop files of keys no longer used"""
    os.makedirs(FINAL_DIR, exist_ok=True)
    src_path = os.path.join(FINAL_DIR, "sources.json")
    if os.path.exists(src_path):
        os.remove(src_path)
    pick([f"{k}={v}" for k, v in FINAL.items()])
    keep = {k + ".ogg" for k in FINAL} | {"sources.json"}
    for f in os.listdir(FINAL_DIR):
        if f not in keep:
            os.remove(os.path.join(FINAL_DIR, f))
            print("removed", f)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    args = sys.argv[2:]
    if cmd == "scan":
        scan(set(args))
    elif cmd == "build":
        build(set(args))
    elif cmd == "sheet":
        print(sheet())
    elif cmd == "pick":
        pick(args)
    elif cmd == "final":
        final()
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
