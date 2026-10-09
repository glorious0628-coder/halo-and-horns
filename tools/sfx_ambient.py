"""
Weather / night ambience loops, synthesized (소리 만들기, A23-105; credits 0).
  py tools/sfx_ambient.py                  -> build/ambient/cand/<Key>_<a|b>.wav  (mono 48 kHz, 25 s, seamless loop)
  py tools/sfx_ambient.py sheet OUT.png    -> one PNG: waveform, spectrogram and numbers per candidate
Keys: Rain (light rain), Night (crickets + a soft wind), WinterWind (snow-time wind).
Every loop is built 2 s longer and its tail is cross-faded (equal power) into the head: no tick at the loop point.
Level: -30 LUFS (Rain -28), peak well under -6 dBFS; the game's Volume decides the rest. Kids' game: nothing scary.
"""
import os
import sys

import numpy as np
from scipy.signal import butter, sosfilt

sys.path.insert(0, os.path.dirname(__file__))
import bgm_tools as B  # noqa: E402

SR = B.SR
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "build", "ambient", "cand")
SECONDS = 25.0
XF = int(2.0 * SR)


def band(x, lo, hi, order=2):
    sos = butter(order, [lo / (SR / 2), hi / (SR / 2)], btype="band", output="sos")
    return sosfilt(sos, x)


def lowp(x, hi, order=2):
    return sosfilt(butter(order, hi / (SR / 2), btype="low", output="sos"), x)


def slow(rng, n, rate, depth):
    """a slow random 'breathing' curve around 1 (smoothed noise)"""
    k = max(2, int(SR / rate))
    pts = rng.standard_normal(n // k + 3)
    c = np.interp(np.arange(n), np.arange(len(pts)) * k, pts)
    c = lowp(c, rate * 2, 1)
    c = c / (np.abs(c).max() + 1e-9)
    return 1.0 + depth * c


def finish(y, lufs):
    n = len(y) - XF
    t = np.linspace(0, np.pi / 2, XF)
    body = y[:n].copy()
    body[:XF] = body[:XF] * np.sin(t) + y[n:] * np.cos(t)
    body = body - body.mean()
    body = body * 10 ** ((lufs - B.lufs(np.stack([body, body], axis=1))) / 20)
    pk = np.abs(body).max()
    if pk > 0.5:
        body = body * 0.5 / pk
    return body


def rain(variant):
    rng = np.random.default_rng(31 if variant == "a" else 32)
    n = int(SECONDS * SR) + XF
    white = rng.standard_normal(n)
    sheet = band(white, 1800, 9000) * 0.6 + band(white, 600, 1800) * 0.25
    sheet *= slow(rng, n, 0.15, 0.18)
    drops = np.zeros(n)
    count = int((SECONDS + 2) * (35 if variant == "a" else 70))
    for _ in range(count):  # single drops on leaves / ground
        pos = int(rng.uniform(0, n - 1500))
        f = rng.uniform(2200, 6500)
        tt = np.arange(900) / SR
        drops[pos:pos + 900] += np.sin(2 * np.pi * f * tt) * np.exp(-tt * rng.uniform(250, 600)) * rng.uniform(0.08, 0.45)
    y = sheet * (0.55 if variant == "a" else 0.35) + drops * (0.5 if variant == "a" else 1.0) * sheet.std() * 4
    return finish(y, -28.0)


def cricket_track(rng, n, f0, rate, pulses=3, gain=1.0):
    """one cricket: a burst of `pulses` fast pulses (about 28 Hz) of a ~f0 sine, repeating `rate` times a second"""
    y = np.zeros(n)
    period = int(SR / rate * rng.uniform(0.9, 1.1))
    phase = rng.integers(0, period)
    chirp_len = int(0.045 * pulses * SR)
    t = np.arange(chirp_len) / SR
    pulse = np.sin(2 * np.pi * 28 * t) ** 2 * (t < 0.04 * pulses)
    tone = np.sin(2 * np.pi * f0 * t + 3 * np.sin(2 * np.pi * 9 * t) * 0.1) * pulse
    tone *= np.minimum(t / 0.004, 1.0)
    for s in range(int(phase), n - chirp_len, period):
        y[s:s + chirp_len] += tone * gain * rng.uniform(0.7, 1.0)
        if rng.random() < 0.12:
            s += period  # a skipped beat now and then keeps it alive
    return y


def night(variant):
    rng = np.random.default_rng(41 if variant == "a" else 42)
    n = int(SECONDS * SR) + XF
    crickets = np.zeros(n)
    nc = 5 if variant == "a" else 3
    for i in range(nc):
        crickets += cricket_track(rng, n, rng.uniform(4100, 5000), rng.uniform(1.1, 1.9), pulses=3 + i % 2,
                                  gain=rng.uniform(0.5, 1.0))
    wind = lowp(rng.standard_normal(n), 520) * slow(rng, n, 0.09, 0.6)
    wind = band(wind, 120, 520) * (1.0 if variant == "a" else 1.6)
    air = band(rng.standard_normal(n), 6500, 9500) * 0.04 * slow(rng, n, 0.2, 0.5)
    y = crickets * 0.30 + wind * 1.0 + air
    # 검수 10/10: nothing above ~6 kHz that tires the ear on a long listen (a 2nd-order low-pass at 5.8 kHz + the air band halved)
    y = lowp(y - air * 0.5, 5800, 2)
    return finish(y, -31.0)


def winter(variant):
    rng = np.random.default_rng(51 if variant == "a" else 52)
    n = int(SECONDS * SR) + XF
    white = rng.standard_normal(n)
    gust = slow(rng, n, 0.12, 0.85)
    gust = np.clip(gust, 0.15, None)
    base = band(white, 180, 900) * gust
    mid = band(white, 700, 2200) * np.clip(slow(rng, n, 0.17, 0.9), 0.1, None) * 0.55
    y = base + mid
    if variant == "b":  # a thin whistle: a narrow resonance that drifts 650 -> 1050 Hz with the gust
        drift = 850 + 200 * np.sin(2 * np.pi * 0.07 * np.arange(n) / SR + 1.0)
        whistle = np.zeros(n)
        ph = np.cumsum(drift) / SR
        whistle = np.sin(2 * np.pi * ph) * 0.05 * gust ** 2
        y = y * 0.8 + whistle * y.std() * 6
    return finish(y, -29.0)


MAKERS = {"Rain_a": lambda: rain("a"), "Rain_b": lambda: rain("b"), "Night_a": lambda: night("a"), "Night_b": lambda: night("b"),
          "WinterWind_a": lambda: winter("a"), "WinterWind_b": lambda: winter("b")}


def seam(x):
    d = np.abs(np.diff(x))
    return round(float(abs(x[0] - x[-1])), 4), round(float(np.percentile(d, 99.9)), 4)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in MAKERS.items():
        x = fn()
        B.write_wav(os.path.join(OUT, name + ".wav"), np.stack([x, x], axis=1))
        print(name, "%.1fs" % (len(x) / SR), "seam step vs p99.9 step", seam(x), "peak %.2f" % np.abs(x).max())


def sheet(path):
    from PIL import Image, ImageDraw
    from scipy.signal import spectrogram
    W, H = 760, 150
    img = Image.new("RGB", (W * 2, H * len(MAKERS)), (250, 250, 250))
    d = ImageDraw.Draw(img)
    for row, (name, fn) in enumerate(MAKERS.items()):
        x = fn()
        y0 = row * H
        s = seam(x)
        d.text((8, y0 + 3), "%s  %.0fs loop  seam step %s (typical max %s)  lufs %.1f" % (
            name, len(x) / SR, s[0], s[1], B.lufs(np.stack([x, x], axis=1))), fill=(0, 0, 0))
        hop = max(1, len(x) // (W - 20))
        n = len(x) // hop
        env_ = np.abs(x[:n * hop]).reshape(n, hop).max(axis=1)
        for k, v in enumerate(env_):
            px = 10 + int(k / n * (W - 20))
            hh = int(v / 0.5 * (H / 2 - 22))
            d.line([(px, y0 + H // 2 + 8 - hh), (px, y0 + H // 2 + 8 + hh)], fill=(60, 90, 200))
        f, tt, S = spectrogram(x, fs=SR, nperseg=2048, noverlap=1024)
        S = np.clip((10 * np.log10(S[:230] + 1e-14) + 120) / 60, 0, 1)
        im = Image.fromarray((255 - S[::-1] * 255).astype(np.uint8)).resize((W - 20, H - 28)).convert("RGB")
        img.paste(im, (W + 10, y0 + 22))
    img.save(path)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "sheet":
        sheet(sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "build", "ambient", "sheet.png"))
    else:
        main()
