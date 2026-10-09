"""
Background-music tools (소리 만들기, A23-100).

  py tools/bgm_tools.py boss  --bpm 96 --bars 32 [--beats 4] [--root 98] --out art/sfx/bgm/BossLayer_96.wav
  py tools/bgm_tools.py loop  IN.wav --bpm 96 --bars 32 [--beats 4] [--start 0.0] --out OUT.wav [--xfade 2.0]
  py tools/bgm_tools.py tempo IN.wav            # estimate BPM + loop-length candidates
  py tools/bgm_tools.py check OUT.wav           # seam check: jump at the loop point, loudness

boss: a drum+bass layer made by synthesis, exactly bars*beats beats long, with every tail wrapped around the end
      (circular add), so it loops with no click and stays on the grid of a song of the same BPM / bar count.
loop: cuts a generated track to a whole number of bars and joins its end to its start with an equal-power
      crossfade, so Sound.Looped = true has no tick.  48 kHz stereo 16-bit.
"""

import argparse
import json
import math
import sys
import wave

import numpy as np

SR = 48000


# ---------- io ----------
def read_wav(path):
    try:
        import soundfile as sf
        x, sr = sf.read(path, always_2d=True)
        x = x.astype(np.float64)
    except Exception:
        with wave.open(path, "rb") as w:
            sr = w.getframerate()
            n = w.getnframes()
            ch = w.getnchannels()
            sw = w.getsampwidth()
            raw = w.readframes(n)
        if sw == 2:
            x = np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0
        elif sw == 3:
            b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3)
            v = (b[:, 0].astype(np.int32) | (b[:, 1].astype(np.int32) << 8) | (b[:, 2].astype(np.int32) << 16))
            v = np.where(v >= 1 << 23, v - (1 << 24), v)
            x = v.astype(np.float64) / (1 << 23)
        else:
            raise SystemExit("unsupported sample width %d" % sw)
        x = x.reshape(-1, ch)
    if sr != SR:
        from scipy.signal import resample_poly
        g = math.gcd(sr, SR)
        x = resample_poly(x, SR // g, sr // g, axis=0)
    if x.shape[1] == 1:
        x = np.repeat(x, 2, axis=1)
    return x[:, :2]


def write_wav(path, x):
    x = np.clip(x, -1.0, 1.0)
    pcm = (x * 32767.0).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def lufs(x):
    """BS.1770 K-weighted loudness of the whole signal (ungated, for comparisons)."""
    from scipy.signal import sosfilt, butter
    hs = butter(2, 1500 / (SR / 2), btype="high", output="sos")  # rough shelf stand-in
    hp = butter(2, 38 / (SR / 2), btype="high", output="sos")
    y = sosfilt(hp, x, axis=0)
    y = y + 0.4 * sosfilt(hs, y, axis=0)
    ms = float(np.mean(y ** 2))
    return -0.691 + 10 * math.log10(max(ms, 1e-12))


# ---------- boss layer ----------
def add_circ(buf, sig, pos):
    """Add sig into buf at pos; the part past the end wraps to the start (seamless loop)."""
    n = len(buf)
    pos %= n
    end = pos + len(sig)
    if end <= n:
        buf[pos:end] += sig
    else:
        k = n - pos
        buf[pos:] += sig[:k]
        rest = sig[k:]
        while len(rest):
            m = min(len(rest), n)
            buf[:m] += rest[:m]
            rest = rest[m:]


def kick(len_s=0.45):
    t = np.arange(int(SR * len_s)) / SR
    f = 45 + 95 * np.exp(-t * 28)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 9) * 0.9


def tom(freq, len_s=0.35):
    t = np.arange(int(SR * len_s)) / SR
    f = freq * (1 + 0.5 * np.exp(-t * 22))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 11) * 0.55


def wood(len_s=0.12, seed=1):
    """Soft rim/wood tap: a short band-passed noise burst with a pitched click."""
    from scipy.signal import butter, sosfilt
    rng = np.random.default_rng(seed)
    n = int(SR * len_s)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    sos = butter(2, [1400 / (SR / 2), 4200 / (SR / 2)], btype="band", output="sos")
    return sosfilt(sos, noise) * np.exp(-t * 55) * 0.35 + np.sin(2 * np.pi * 900 * t) * np.exp(-t * 80) * 0.2


def bass_note(freq, len_s):
    t = np.arange(int(SR * len_s)) / SR
    env = np.minimum(t / 0.01, 1.0) * np.exp(-t * (1.0 / max(len_s, 0.05)) * 3.0)
    s = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * 2 * freq * t)
    return s * env * 0.4


def boss_layer(bpm, bars, beats=4, root=98.0):
    beat = 60.0 / bpm
    total = int(round(bars * beats * beat * SR))
    buf = np.zeros(total)
    k = kick()
    t1 = tom(110.0)
    t2 = tom(150.0)
    w = wood()
    # chord-root pulse follows a gentle 4-bar pattern: root, root, fourth, fifth
    ratios = [1.0, 1.0, 4 / 3, 3 / 2]
    for bar in range(bars):
        r = ratios[(bar // 2) % 4] if bars >= 8 else 1.0
        f = root * r
        for b in range(beats):
            pos = int(round((bar * beats + b) * beat * SR))
            # kick on 1 and (4/4) 3, tom answer on 4's offbeat; waltz = kick on 1 only
            if b == 0 or (beats == 4 and b == 2):
                add_circ(buf, k, pos)
            else:
                add_circ(buf, w, pos)
            # eighth-note bass pulse (two per beat), the offbeat softer
            for h in range(2):
                p2 = pos + int(round(h * beat * SR / 2))
                note = bass_note(f, beat / 2 * 0.9) * (1.0 if h == 0 else 0.6)
                add_circ(buf, note, p2)
        # a tom fill on the last beat of every 4th bar
        if bar % 4 == 3:
            base = (bar * beats + (beats - 1)) * beat
            add_circ(buf, t1, int(round((base + 0.0) * SR)))
            add_circ(buf, t2, int(round((base + beat / 2) * SR)))
    peak = float(np.max(np.abs(buf)))
    buf = buf / peak * 0.5  # -6 dBFS peak; game Volume sets the real level
    return np.stack([buf, buf], axis=1)


# ---------- loop cutter ----------
def make_loop(x, bpm, bars, beats, start_s, xfade_s):
    beat = 60.0 / bpm
    loop_n = int(round(bars * beats * beat * SR))
    xf = int(round(xfade_s * SR))
    s0 = int(round(start_s * SR))
    need = s0 + loop_n + xf
    if len(x) < need:
        raise SystemExit("source too short: have %.2fs, need %.2fs (start %.2f + loop %.2f + xfade %.2f)"
                         % (len(x) / SR, need / SR, start_s, loop_n / SR, xfade_s))
    body = x[s0:s0 + loop_n].copy()
    tail = x[s0 + loop_n:s0 + loop_n + xf]  # the music that would follow the loop end
    t = np.linspace(0, math.pi / 2, xf)[:, None]
    # the loop's first xf samples are replaced by (tail fading out) + (start fading in)
    head = body[:xf]
    body[:xf] = head * np.sin(t) + tail * np.cos(t)
    return body


def tempo(x):
    from scipy.signal import stft
    m = x.mean(axis=1)
    f, tt, Z = stft(m, fs=SR, nperseg=2048, noverlap=2048 - 512)
    mag = np.abs(Z)
    flux = np.maximum(np.diff(mag, axis=1), 0).sum(axis=0)
    flux = flux - flux.mean()
    hop = 512 / SR
    ac = np.correlate(flux, flux, "full")[len(flux) - 1:]
    lo, hi = int(60 / 180 / hop), int(60 / 60 / hop)
    seg = ac[lo:hi]
    order = np.argsort(seg)[::-1][:5]
    return [(round(60 / ((lo + i) * hop), 1), float(seg[i] / ac[0])) for i in order]


def seam_check(x):
    n = len(x)
    a = x[-2048:].mean(axis=1)
    b = x[:2048].mean(axis=1)
    jump = abs(float(x[-1].mean() - x[0].mean()))
    slope_end = float(a[-1] - a[-2])
    d = abs(float(b[0]) - float(a[-1]))
    return {"seconds": round(n / SR, 3), "jumpAtLoop": round(d, 5), "stepEnd": round(abs(slope_end), 5),
            "lufs": round(lufs(x), 1), "peakDb": round(20 * math.log10(max(np.max(np.abs(x)), 1e-9)), 1)}


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("boss")
    b.add_argument("--bpm", type=float, required=True)
    b.add_argument("--bars", type=int, required=True)
    b.add_argument("--beats", type=int, default=4)
    b.add_argument("--root", type=float, default=98.0)
    b.add_argument("--out", required=True)
    l = sub.add_parser("loop")
    l.add_argument("inp")
    l.add_argument("--bpm", type=float, required=True)
    l.add_argument("--bars", type=int, required=True)
    l.add_argument("--beats", type=int, default=4)
    l.add_argument("--start", type=float, default=0.0)
    l.add_argument("--xfade", type=float, default=2.0)
    l.add_argument("--out", required=True)
    t = sub.add_parser("tempo")
    t.add_argument("inp")
    c = sub.add_parser("check")
    c.add_argument("inp")
    a = ap.parse_args()
    if a.cmd == "boss":
        y = boss_layer(a.bpm, a.bars, a.beats, a.root)
        write_wav(a.out, y)
        print(json.dumps(seam_check(y)))
    elif a.cmd == "loop":
        y = make_loop(read_wav(a.inp), a.bpm, a.bars, a.beats, a.start, a.xfade)
        write_wav(a.out, y)
        print(json.dumps(seam_check(y)))
    elif a.cmd == "tempo":
        x = read_wav(a.inp)
        print("length %.2fs" % (len(x) / SR))
        for bpm, s in tempo(x):
            print("  %.1f BPM  score %.3f" % (bpm, s))
    else:
        print(json.dumps(seam_check(read_wav(a.inp))))


if __name__ == "__main__":
    sys.exit(main())
