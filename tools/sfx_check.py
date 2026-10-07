"""
Sound-candidate checker: filter game SFX candidates by waveform / spectrum BEFORE a person listens.

  py tools/sfx_check.py <folder|file ...> [--spec tools/sfx_spec.json] [--out DIR] [--keys K1,K2] [--map stem=Key,...]
                        [--no-png] [--dump]

Input names: <Key>[_<variant>].wav|ogg (also Key1/Key2 = variants 1/2, and the aliases in the spec, e.g. KingBell ->
PumpkinKing + GhostKing). Every file is decoded to 48 kHz mono (wav: scipy/wave; ogg/mp3/flac: soundfile if installed,
else ffmpeg) and measured as it would play (leading silence counts).

Writes to --out (default build/sfx_check/):
  <Key>.png          one sheet per key: waveform + dB envelope + spectrogram + average spectrum + metrics with pass/fail
  pairs.png          'distinct' and 'match' pair rules
  summary.json/.txt  every metric, every check, verdict per candidate (PASS / WARN = soft misses only / FAIL = a hard miss)

Metrics (all on the file as played, speed 1.0 unless a speed check says otherwise):
  durMs        audible length: first to last sample above -50 dB of the peak (same rule as sfx_game finish())
  leadMs       silence before the sound starts (it delays the sound in game)
  attackMs     10 % -> 90 % rise of the 3 ms amplitude envelope (to its first 90 % point)
  peakAtMs     loudest 10 ms (RMS), from the start
  peakDb       sample peak dBFS; truePeakDb 4x oversampled; clip = samples at full scale
  lufs         K-weighted (ITU-R BS.1770) loudness of the loudest 100 ms, zero padded (short sounds count over 100 ms)
  lufsI        BS.1770-4 integrated (400 ms blocks, gated, padded) - for information
  effLufs      lufs + 20 log10(game Volume): how loud it is in the game next to the other sounds
  rms100Db     loudest 100 ms plain RMS (the old sfx_game normaliser)
  phoneDropDb  how much quieter through a phone speaker (4th-order 400 Hz high-pass, as sfx_game metrics)
  lt150/lt300/gt8k   energy share below 150 Hz / below 300 Hz / above 8 kHz
  centroidHz   spectral centroid of the whole sound; centStartHz / centMidHz / centEndHz = energy-weighted centroid of
               the first / middle / last quarter of the loud part; sweepOct = log2(end / start)
  pitchStartHz / pitchEndHz / pitchMinHz  strongest partial path (tonal frames only); pitchSemis = end vs start
  flat         spectral flatness 100 Hz-10 kHz of the whole sound (0 tone .. 1 white noise; sfx_game 'noisy')
  tonalShare   share of the energy in narrow spectral peaks (0 noise .. 1 pure tones)
  periodicity  energy-weighted autocorrelation peak at 1-8 ms lags (pitched = near 1, noise = near 0)
  ringMs/ringHz  longest steady tonal peak (a 'ting' / string ring) and its frequency
  harshDb/harshHz  prominence of the strongest narrow peak in 2-5 kHz that is within 6 dB of the loudest part of
               the spectrum (1/12-octave vs 1-octave smoothing); share2to5 = energy share 2-5 kHz
  onsets       attack times (spectral flux peaks); gapMs = 1st -> 2nd onset; gapDipDb = envelope dip between them
"""

import argparse
import json
import math
import os
import re
import shutil
import subprocess
import sys
import wave

import numpy as np

try:
    from scipy import signal as sps
    from scipy.io import wavfile
except ImportError:  # the checker needs scipy for filters and resampling
    sps = None
    wavfile = None

try:
    import soundfile  # optional
except ImportError:
    soundfile = None

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR = 48000
FFMPEG = shutil.which("ffmpeg") or "ffmpeg"
DEFAULT_SPEC = os.path.join(ROOT, "tools", "sfx_spec.json")
DEFAULT_OUT = os.path.join(ROOT, "build", "sfx_check")
AUDIO_EXT = (".wav", ".ogg", ".mp3", ".flac")


# ------------------------------------------------------------------ loading
def load(path):
    """-> mono float64 at SR"""
    ext = os.path.splitext(path)[1].lower()
    x, sr = None, None
    if soundfile is not None:
        try:
            x, sr = soundfile.read(path, dtype="float64", always_2d=True)
            x = x.mean(axis=1)
        except Exception:
            x = None
    if x is None and ext == ".wav":
        try:
            sr, d = wavfile.read(path)
            if d.dtype.kind in "iu":
                d = d.astype(np.float64) / float(np.iinfo(d.dtype).max + 1)
            x = np.asarray(d, dtype=np.float64)
            if x.ndim == 2:
                x = x.mean(axis=1)
        except Exception:
            with wave.open(path) as w:
                sr = w.getframerate()
                raw = w.readframes(w.getnframes())
                x = np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768.0
                if w.getnchannels() > 1:
                    x = x.reshape(-1, w.getnchannels()).mean(axis=1)
    if x is None:
        r = subprocess.run([FFMPEG, "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                           capture_output=True, check=True)
        return np.frombuffer(r.stdout, dtype=np.float32).astype(np.float64)
    if sr != SR:
        g = math.gcd(int(sr), SR)
        x = sps.resample_poly(x, SR // g, int(sr) // g)
    return np.asarray(x, dtype=np.float64)


def respeed(x, speed):
    """Sound.PlaybackSpeed: speed > 1 = higher and shorter (resampled, same SR)"""
    if abs(speed - 1.0) < 1e-6:
        return x.copy()
    from fractions import Fraction
    fr = Fraction(1.0 / speed).limit_denominator(200)
    return sps.resample_poly(x, fr.numerator, fr.denominator)


# ------------------------------------------------------------------ filters
def k_weight(x):
    """ITU-R BS.1770 K-weighting (shelf + RLB high-pass), coefficients for any rate"""
    fs = SR
    G, f0, Q = 3.999843853973347, 1681.974450955533, 0.7071752369554196
    K = math.tan(math.pi * f0 / fs)
    Vh = 10 ** (G / 20)
    Vb = Vh ** 0.4996667741545416
    a0 = 1 + K / Q + K * K
    b1 = [(Vh + Vb * K / Q + K * K) / a0, 2 * (K * K - Vh) / a0, (Vh - Vb * K / Q + K * K) / a0]
    a1 = [1.0, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0]
    f0, Q = 38.13547087602444, 0.5003270373238773
    K = math.tan(math.pi * f0 / fs)
    a0 = 1 + K / Q + K * K
    b2 = [1.0, -2.0, 1.0]
    a2 = [1.0, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0]
    return sps.lfilter(b2, a2, sps.lfilter(b1, a1, x))


def phone(x):
    """the phone-speaker model of sfx_game metrics(): two 2nd-order 400 Hz high-passes (Q 0.707)"""
    b, a = sps.butter(2, 400, "highpass", fs=SR)
    return sps.lfilter(b, a, sps.lfilter(b, a, x))


# ------------------------------------------------------------------ helpers
def db(v, floor=1e-12):
    return 10 * np.log10(np.maximum(v, floor))


def win_ms(x, ms, hop_ms=1.0):
    """centred RMS envelope (linear) with window ms, hop hop_ms; returns (env, hop_samples)"""
    w = max(1, int(SR * ms / 1000))
    h = max(1, int(SR * hop_ms / 1000))
    p = np.pad(x * x, (w // 2, w - w // 2))
    c = np.concatenate([[0.0], np.cumsum(p)])
    idx = np.arange(0, len(x), h)
    return np.sqrt(np.maximum((c[idx + w] - c[idx]) / w, 0)), h


def loudest_rms_db(x, win=0.1):
    """sfx_game loudest(): RMS of the loudest window (window = min(len, 100 ms))"""
    w = min(len(x), int(SR * win))
    c = np.concatenate([[0.0], np.cumsum(x * x)])
    rms = np.sqrt(np.maximum((c[w:] - c[:-w]) / w, 0))
    return 20 * np.log10(max(rms.max(), 1e-9))


def lufs_window(y_k, win=0.1):
    """loudest win-second K-weighted window, zero padded (LUFS)"""
    w = int(SR * win)
    p = np.pad(y_k * y_k, (w, w))
    c = np.concatenate([[0.0], np.cumsum(p)])
    ms = (c[w:] - c[:-w]) / w
    return -0.691 + 10 * math.log10(max(ms.max(), 1e-12))


def lufs_integrated(y_k):
    """BS.1770-4: 400 ms blocks, 75 % overlap, -70 LUFS absolute and -10 LU relative gates (padded to 400 ms)"""
    n = int(SR * 0.4)
    y = y_k if len(y_k) >= n else np.pad(y_k, (0, n - len(y_k)))
    hop = n // 4
    z = np.array([np.mean(y[i:i + n] ** 2) for i in range(0, len(y) - n + 1, hop)])
    l = -0.691 + db(z)
    z = z[l > -70]
    if not len(z):
        return -70.0
    rel = -0.691 + 10 * math.log10(z.mean()) - 10
    z2 = z[(-0.691 + db(z)) > rel]
    return -0.691 + 10 * math.log10((z2 if len(z2) else z).mean())


def stft_power(x, n, hop):
    """frames x bins power spectrogram (Hann), frame i centred at i*hop"""
    w = np.hanning(n)
    xp = np.pad(x, (n // 2, n // 2 + n))
    frames = range(0, len(x), hop)
    out = np.empty((len(frames), n // 2 + 1))
    for j, i in enumerate(frames):
        out[j] = np.abs(np.fft.rfft(xp[i:i + n] * w)) ** 2
    return out, np.fft.rfftfreq(n, 1 / SR)


def smooth_oct(fr_log, val_db, width_oct):
    """moving mean (in dB) over a log-frequency grid"""
    step = fr_log[1] - fr_log[0]
    k = max(1, int(round(width_oct / step)))
    ker = np.ones(k) / k
    return np.convolve(np.pad(val_db, (k // 2, k - 1 - k // 2), mode="edge"), ker, mode="valid")


# ------------------------------------------------------------------ the measurements
def measure(x, full=True):
    x = np.asarray(x, dtype=np.float64)
    x = x - np.mean(x)
    m = {}
    n_all = len(x)
    a = np.abs(x)
    pk = a.max() if n_all else 0.0
    if pk <= 0:
        return {"silent": True, "fileMs": round(n_all / SR * 1000, 1)}
    thr = pk * 10 ** (-50 / 20)
    on = np.nonzero(a > thr)[0]
    s0, s1 = int(on[0]), int(on[-1])
    m["fileMs"] = round(n_all / SR * 1000, 1)
    m["leadMs"] = round(s0 / SR * 1000, 1)
    m["durMs"] = round((s1 - s0) / SR * 1000, 1)
    xs = x[s0:s1 + 1]

    # level
    m["peakDb"] = round(20 * math.log10(pk), 2)
    up = sps.resample_poly(x, 4, 1)
    m["truePeakDb"] = round(20 * math.log10(max(np.abs(up).max(), 1e-12)), 2)
    m["clip"] = int(np.sum(a >= 0.999))
    yk = k_weight(x)
    m["lufs"] = round(lufs_window(yk, 0.1), 2)
    m["lufsI"] = round(lufs_integrated(yk), 2)
    loud = loudest_rms_db(x)
    m["rms100Db"] = round(loud, 2)
    m["phoneDropDb"] = round(loud - loudest_rms_db(phone(x)), 2)
    m["phoneLufs"] = round(lufs_window(k_weight(phone(x)), 0.1), 2)

    # envelope / time
    e3, h = win_ms(xs, 3.0, 0.5)
    e10, h10 = win_ms(xs, 10.0, 0.5)
    m["peakAtMs"] = round(int(np.argmax(e10)) * h10 / SR * 1000, 1)
    mx = e3.max()
    i10 = np.nonzero(e3 >= 0.1 * mx)[0][0]
    i90 = np.nonzero(e3 >= 0.9 * mx)[0][0]
    m["attackMs"] = round(max(0, i90 - i10) * h / SR * 1000, 1)
    lin_e3 = e3
    e3db = 20 * np.log10(np.maximum(e3 / mx, 1e-6))
    above30 = np.nonzero(e3db > -30)[0]
    m["dur30Ms"] = round((above30[-1] - above30[0]) * h / SR * 1000, 1) if len(above30) else 0.0
    # holeMs: the longest near-silence (35 dB under the peak) inside the loud part (two sounds glued together)
    loud20 = np.nonzero(e3db > -20)[0]
    hole = 0
    if len(loud20) > 1:
        quiet = e3db[loud20[0]:loud20[-1] + 1] < -35
        run = 0
        for qv in quiet:
            run = run + 1 if qv else 0
            hole = max(hole, run)
    m["holeMs"] = round(hole * h / SR * 1000, 1)

    # whole-sound spectrum (sfx_game style)
    spec = np.abs(np.fft.rfft(xs * np.hanning(len(xs)))) ** 2 if len(xs) > 8 else np.ones(5)
    fr = np.fft.rfftfreq(len(xs), 1 / SR) if len(xs) > 8 else np.linspace(0, SR / 2, 5)
    spec[fr < 20] = 0
    tot = spec.sum() + 1e-20
    m["lt150"] = round(float(spec[fr < 150].sum() / tot), 4)
    m["lt300"] = round(float(spec[fr < 300].sum() / tot), 4)
    m["gt8k"] = round(float(spec[fr > 8000].sum() / tot), 4)
    m["share2to5"] = round(float(spec[(fr >= 2000) & (fr <= 5000)].sum() / tot), 4)
    m["centroidHz"] = int((fr * spec).sum() / tot)
    band = (fr > 100) & (fr < 10000)
    sb = spec[band] + 1e-20
    m["flat"] = round(float(np.exp(np.mean(np.log(sb))) / np.mean(sb)), 4)

    # frame analysis: centroid path, pitch path, tonal share, ring
    n, hop = 2048, 240
    P, f = stft_power(xs, n, hop)
    E = P[:, (f > 100) & (f < 16000)].sum(axis=1)
    Emax = E.max() + 1e-20
    act = E >= Emax * 10 ** (-30 / 10)
    idx = np.nonzero(act)[0]
    ib = (f > 100) & (f < 16000)
    cen = (P[:, ib] * f[ib]).sum(axis=1) / (P[:, ib].sum(axis=1) + 1e-20)
    if len(idx):
        lo_i, hi_i = idx[0], idx[-1]
        span = max(1, hi_i - lo_i + 1)

        def wmean_log(sel):
            sel = sel[act[sel]]
            if not len(sel):
                return None
            w = E[sel]
            return float(2 ** (np.sum(w * np.log2(np.maximum(cen[sel], 1))) / w.sum()))
        q = max(1, span // 4)
        m["centStartHz"] = int(wmean_log(np.arange(lo_i, lo_i + q)) or 0)
        mid0 = lo_i + span // 2 - q // 2
        m["centMidHz"] = int(wmean_log(np.arange(mid0, mid0 + q)) or 0)
        m["centEndHz"] = int(wmean_log(np.arange(hi_i - q + 1, hi_i + 1)) or 0)
        m["centPeakHz"] = int(cen[int(np.argmax(E))])
        m["sweepOct"] = round(math.log2(max(m["centEndHz"], 1) / max(m["centStartHz"], 1)), 3)
    m["centPath"] = [int(c) for c in cen[act][:: max(1, int(act.sum() // 24) or 1)]][:30]

    # tonal peaks per frame: >= 12 dB over the 1/3-octave local median and within 20 dB of the frame max
    Pdb = db(P)
    tonal_e = 0.0
    total_e = 0.0
    peaks_per_frame = []
    nb = len(f)
    # local floor: running median over +-8 bins (+-190 Hz) or 1/3 octave, whichever is wider
    from scipy.ndimage import median_filter
    MED = np.maximum(median_filter(Pdb, size=(1, 17), mode="nearest"),
                     median_filter(Pdb, size=(1, 41), mode="nearest") * (f >= 1500) + (-1e9) * (f < 1500))
    for j in range(len(P)):
        if not act[j]:
            peaks_per_frame.append([])
            continue
        row = Pdb[j]
        # local median via a coarse log-band median
        med = MED[j]
        cand = np.nonzero((row[1:-1] > row[:-2]) & (row[1:-1] >= row[2:]))[0] + 1
        cand = cand[(f[cand] > 100) & (f[cand] < 12000)]
        top = row[ib].max()
        good = [c for c in cand if row[c] - med[c] >= 12 and row[c] >= top - 20]
        peaks_per_frame.append(good)
        pw = P[j]
        tot_j = pw[ib].sum()
        te = 0.0
        for c in good:
            te += pw[max(0, c - 2):c + 3].sum()
        tonal_e += min(te, tot_j)
        total_e += tot_j
    m["tonalShare"] = round(tonal_e / (total_e + 1e-20), 3)

    # ring: longest run of a steady peak (within 3 %) across frames
    best_run, best_hz = 0, 0
    runs = {}
    for j, good in enumerate(peaks_per_frame):
        new = {}
        for c in good:
            fc = f[c]
            hit = None
            for k_, (st, fk) in runs.items():
                if abs(fk - fc) <= 0.03 * fk:
                    hit = k_
                    break
            if hit is not None:
                st, _ = runs[hit]
                new[c] = (st, fc)
            else:
                new[c] = (j, fc)
            r = j - new[c][0] + 1
            if r > best_run:
                best_run, best_hz = r, fc
        runs = new
    ring_ms = best_run * hop / SR * 1000 - 0.5 * n / SR * 1000 if best_run > 1 else 0.0
    m["ringMs"] = round(max(0.0, ring_ms), 1)
    m["ringHz"] = int(best_hz)

    # pitch path: strongest peak in tonal frames within 20 dB of the loudest frame
    pf = []
    for j, good in enumerate(peaks_per_frame):
        if good and E[j] >= Emax * 0.01:
            c = max(good, key=lambda c_: Pdb[j][c_])
            if 0 < c < nb - 1:  # parabolic refine
                al, be, ga = Pdb[j][c - 1], Pdb[j][c], Pdb[j][c + 1]
                dlt = 0.5 * (al - ga) / (al - 2 * be + ga + 1e-12)
                pf.append((j, (c + dlt) * SR / n))
            else:
                pf.append((j, f[c]))
    if len(pf) >= 2 and m["tonalShare"] >= 0.25:  # no pitch for noise
        ps = np.array([p for _, p in pf])
        k4 = max(1, min(len(ps) // 4, int(0.08 * SR / hop)))  # first / last quarter, at most 80 ms
        m["pitchStartHz"] = int(np.median(ps[:k4]))
        m["pitchEndHz"] = int(np.median(ps[-k4:]))
        m["pitchMinHz"] = int(np.percentile(ps, 5))
        m["pitchMaxHz"] = int(np.percentile(ps, 95))
        m["pitchSemis"] = round(12 * math.log2(m["pitchEndHz"] / max(m["pitchStartHz"], 1)), 1)
    else:
        m["pitchStartHz"] = m["pitchEndHz"] = m["pitchMinHz"] = m["pitchMaxHz"] = None
        m["pitchSemis"] = None

    # periodicity (Boersma-normalised autocorrelation, lags 1-8 ms)
    nf, hf = 1024, 240
    wv = np.hanning(nf)
    rw = np.fft.irfft(np.abs(np.fft.rfft(wv, 2 * nf)) ** 2)[:nf]
    rw = rw / rw[0]
    l0, l1 = int(SR * 0.001), int(SR * 0.008)
    xp = np.pad(xs, (0, nf))
    pe, we = 0.0, 0.0
    fe = []
    for i in range(0, len(xs), hf):
        fr_ = xp[i:i + nf] * wv
        e = float(np.sum(fr_ ** 2))
        fe.append(e)
    fe = np.array(fe)
    emx = fe.max() + 1e-20
    for k_, i in enumerate(range(0, len(xs), hf)):
        if fe[k_] < emx * 1e-3:
            continue
        fr_ = xp[i:i + nf] * wv
        r = np.fft.irfft(np.abs(np.fft.rfft(fr_, 2 * nf)) ** 2)[:nf]
        if r[0] <= 0:
            continue
        rn = (r / r[0]) / np.maximum(rw, 1e-3)
        pv = float(np.clip(rn[l0:min(l1, nf // 2)].max(), 0, 1))
        pe += pv * fe[k_]
        we += fe[k_]
    m["periodicity"] = round(pe / (we + 1e-20), 3)

    # harshness: narrow peak in 2-5 kHz near the top of the long-term spectrum
    Pm = P[act].mean(axis=0) if act.any() else P.mean(axis=0)
    grid = np.geomspace(60, 16000, 48 * 8 + 1)
    lg = np.log2(grid)
    S = np.interp(grid, f, Pm)
    Sdb = db(S)
    nar = smooth_oct(lg, Sdb, 1 / 12)
    wid = smooth_oct(lg, Sdb, 1.0)
    prom = nar - wid
    zone = (grid >= 2000) & (grid <= 5000) & (nar >= nar.max() - 6)
    if zone.any():
        zi = np.nonzero(zone)[0]
        j = zi[int(np.argmax(prom[zi]))]
        m["harshDb"] = round(float(max(0.0, prom[j])), 1)
        m["harshHz"] = int(grid[j])
    else:
        m["harshDb"], m["harshHz"] = 0.0, 0

    # onsets: an envelope rise of >= 6 dB within 15 ms (one per rising stretch) or a spike of new spectral energy
    # (log-spectral flux >= 3x its neighbourhood); either must reach within 12 dB of the loudest point
    ons = onset_times(xs)
    m["onsets"] = ons
    m["firstOnsetMs"] = ons[0] if ons else 0.0
    m["nOnsets"] = len(ons)
    if len(ons) >= 2:
        m["gapMs"] = round(ons[1] - ons[0], 1)
        a_i, b_i = int(ons[0] / 1000 * SR / h), int(ons[1] / 1000 * SR / h)
        seg = lin_e3[a_i:max(a_i + 1, b_i)]
        pk1 = int(np.argmax(seg)) + a_i
        valley = lin_e3[pk1:max(pk1 + 1, b_i + int(0.003 * SR / h))]
        m["gapDipDb"] = round(20 * math.log10(lin_e3[pk1] / max(valley.min(), 1e-9)), 1)
    else:
        m["gapMs"] = 0.0
        m["gapDipDb"] = 0.0

    if full:
        m["_env"] = e3db.tolist()
        m["_envHop"] = h
        m["_start"] = s0
        m["_x"] = x
        m["_spec"] = (grid, nar, wid)
        m["_cenPath"] = [(j * hop / SR, float(cen[j])) for j in range(len(cen)) if act[j]]
    return m


def onset_times(xs, pad=0.02):
    """attack times in ms from the start of the sound"""
    xs = np.concatenate([np.zeros(int(pad * SR)), xs])
    e, h = win_ms(xs, 6.0, 0.5)
    ed = np.maximum(20 * np.log10(np.maximum(e / e.max(), 1e-5)), -60)
    look = int(0.015 * SR / h)
    fwd = int(0.03 * SR / h)
    from scipy.ndimage import minimum_filter1d
    mins = minimum_filter1d(ed, size=look + 1, origin=look // 2, mode="nearest")
    rise = ed - mins
    ev = []
    mask = rise >= 6
    i = 0
    last_peak = None  # loudest level since the last accepted rise
    last_end = 0
    while i < len(mask):
        if not mask[i]:
            i += 1
            continue
        j = i
        while j < len(mask) and mask[j]:
            j += 1
        a = max(0, i - look)
        t_min = a + int(np.argmin(ed[a:i + 1]))
        # a new event must start from a valley >= 4 dB under the previous event's peak (a swell is one event)
        fresh = last_peak is None or ed[min(last_end, t_min):t_min + 1].min() <= last_peak - 4
        if ed[i:j + fwd].max() >= -12 and fresh:
            above = np.nonzero(ed[t_min:j + 1] >= ed[t_min] + 3)[0]
            ev.append((t_min + (above[0] if len(above) else 0)) * h / SR)
            k5 = j + int(0.005 * SR / h)
            last_peak = ed[i:k5].max()
            last_end = int(np.argmax(ed[i:k5])) + i
        elif last_peak is not None and ed[i:j].max() > last_peak:
            last_peak = ed[i:j].max()
            last_end = int(np.argmax(ed[i:j])) + i
        i = j + int(0.01 * SR / h)
    n2, h2 = 512, 96
    P2, f2 = stft_power(xs, n2, h2)
    sel = (f2 > 150) & (f2 < 12000)
    L = db(P2[:, sel])
    L = np.maximum(L, L.max() - 50)
    d = np.vstack([np.zeros((1, L.shape[1])), np.maximum(0, np.diff(L, axis=0))])
    flux = d.sum(axis=1) / sel.sum()
    fp, _ = sps.find_peaks(flux, height=0.3, distance=max(1, int(0.025 * SR / h2)))
    w, g = int(0.04 * SR / h2), int(0.006 * SR / h2)
    for p in fp:
        nb = np.concatenate([flux[max(0, p - w):max(0, p - g)], flux[p + g + 1:p + w + 1]])
        bg = float(np.median(nb)) if len(nb) else 0.0
        t = max(0.0, (p * h2 - n2 / 2) / SR)
        k = int(t * SR / h)
        # a spike of new partials (a new note) also counts when the sound has already decayed (arpeggios)
        if (flux[p] >= 3 * bg and ed[k:k + fwd].max() >= -12) or                 (flux[p] >= 0.5 and flux[p] >= 4 * bg and ed[k:k + fwd].max() >= -30):
            ev.append(t)
    out = []
    for t in sorted(ev):
        if not out or t - out[-1] > 0.02:
            out.append(t)
    return [round(float(max(0.0, t - pad)) * 1000, 1) for t in out]


# ------------------------------------------------------------------ spec + checks
CHECK_UNITS = {
    "durMs": "ms", "leadMs": "ms", "attackMs": "ms", "peakAtMs": "ms", "peakDb": "dBFS", "truePeakDb": "dBTP",
    "clip": "", "lufs": "LUFS", "effLufs": "LUFS", "phoneDropDb": "dB", "lt150": "", "lt300": "", "gt8k": "",
    "centroidHz": "Hz", "centStartHz": "Hz", "centMidHz": "Hz", "centEndHz": "Hz", "sweepOct": "oct",
    "pitchStartHz": "Hz", "pitchEndHz": "Hz", "pitchMinHz": "Hz", "pitchMaxHz": "Hz", "pitchSemis": "st",
    "flat": "", "tonalShare": "", "periodicity": "", "ringMs": "ms", "harshDb": "dB", "share2to5": "",
    "nOnsets": "", "gapMs": "ms", "gapDipDb": "dB", "dur30Ms": "ms", "firstOnsetMs": "ms", "holeMs": "ms",
    "likedFile": "",
}
# spec range keys -> metric
RANGE_KEYS = ["durMs", "dur30Ms", "leadMs", "attackMs", "peakAtMs", "peakDb", "truePeakDb", "clip", "lufs", "effLufs",
              "phoneDropDb", "lt150", "lt300", "gt8k", "share2to5", "centroidHz", "centStartHz", "centMidHz",
              "centEndHz", "sweepOct", "pitchStartHz", "pitchEndHz", "pitchMinHz", "pitchMaxHz", "pitchSemis", "flat",
              "tonalShare", "periodicity", "ringMs", "harshDb", "nOnsets", "firstOnsetMs", "gapMs", "gapDipDb",
              "holeMs"]


def load_spec(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def tier_band(spec, key):
    """in-game loudness band of the key's tier: file target + 20 log10(tier Volume range) +- tolerance"""
    ks = spec["keys"][key]
    lo = spec.get("loudness", {})
    t = spec.get("tiers", {}).get(ks.get("tier", ""))
    if not t or "fileTargetLufs" not in lo:
        return None
    v0, v1 = t["volume"]
    tol = lo.get("tolerance", 1.5)
    return [round(lo["fileTargetLufs"] + 20 * math.log10(v0) - tol, 1), round(lo["fileTargetLufs"] + 20 * math.log10(v1) + tol, 1)]


def rule_list(spec, key):
    """merged rules for a key: defaults, then the key. A rule = metric: [lo, hi] (null = open; a miss is soft) or
    {"range": [lo, hi], "hard": [lo, hi]}: a miss of 'range' is soft (WARN), a miss of 'hard' is FAIL.
    effLufs (in-game loudness) comes from the key's tier; 'null' in a key removes a default rule."""
    d = spec.get("defaults", {}).get("rules", {})
    k = spec["keys"][key].get("rules", {})
    out = {}
    band = tier_band(spec, key)
    if band and spec["keys"][key].get("volume"):
        out["effLufs"] = {"range": band}
    for src in (d, k):
        for name, r in src.items():
            if r is None:
                out.pop(name, None)
                continue
            out[name] = r
    return out


def _in(v, rng):
    lo, hi = rng
    return (lo is None or v >= lo) and (hi is None or v <= hi)


def check_metrics(m, rules, volume=None):
    """-> list of {name, value, range, hard, ok, level}"""
    res = []
    if volume:
        m["effLufs"] = round(m["lufs"] + 20 * math.log10(volume), 2)
    for name, r in rules.items():
        if name == "centDir" or name == "pitchDir" or name.startswith("_"):
            continue
        if name not in m or m[name] is None:  # e.g. no pitch in a noise sound
            continue
        v = m[name]
        if isinstance(r, dict):
            soft, hard = r.get("range"), r.get("hard")
        else:
            soft, hard = r, None
        hard_ok = True if hard is None else _in(v, hard)
        soft_ok = True if soft is None else _in(v, soft)
        level = "ok" if (hard_ok and soft_ok) else ("fail" if not hard_ok else "warn")
        res.append({"name": name, "value": v, "range": soft, "hard": hard, "level": level})
    for dname, metric in (("centDir", "sweepOct"), ("pitchDir", "pitchSemis")):
        if dname in rules:
            want = rules[dname]
            hard = False
            if isinstance(want, dict):
                hard = bool(want.get("hard"))
                want = want.get("want")
            v = m.get(metric)
            if v is None:
                continue
            thr = 0.25 if metric == "sweepOct" else 1.5
            if metric == "sweepOct" and want in ("updown", "downup"):
                s, mid, e = m.get("centStartHz", 1), m.get("centMidHz", 1), m.get("centEndHz", 1)
                ok = (mid > s * 1.19 and mid > e * 1.19) if want == "updown" else (mid < s / 1.19 and mid < e / 1.19)
                v = f"{s}>{mid}>{e}"
            elif want == "up":
                ok = v >= thr
            elif want == "down":
                ok = v <= -thr
            elif want == "flat":
                ok = abs(v) < thr
            elif want == "notup":
                ok = v < thr
            elif want == "notdown":
                ok = v > -thr
            else:
                ok = True
            res.append({"name": dname, "value": v, "range": want, "hard": want if hard else None,
                        "level": "ok" if ok else ("fail" if hard else "warn")})
    return res


def verdict(checks):
    if any(c["level"] == "fail" for c in checks):
        return "FAIL"
    if any(c["level"] == "warn" for c in checks):
        return "WARN"
    return "PASS"


def score(checks):
    if not checks:
        return 0
    pts = sum(1.0 if c["level"] == "ok" else (0.5 if c["level"] == "warn" else 0.0) for c in checks)
    return int(round(100 * pts / len(checks)))


# ------------------------------------------------------------------ pair features
def features(x):
    """coarse 'what kind of sound' features: half-octave band spectrum, centroid path, envelope, length"""
    x = np.asarray(x, dtype=np.float64)
    a = np.abs(x)
    on = np.nonzero(a > a.max() * 10 ** (-40 / 20))[0]
    xs = x[on[0]:on[-1] + 1]
    n, hop = 1024, 240
    P, f = stft_power(xs, n, hop)
    edges = 150 * 2 ** (np.arange(14) / 2)  # 13 half-octave bands, 150 Hz - 9.6 kHz
    bands = np.stack([P[:, (f >= edges[i]) & (f < edges[i + 1])].sum(axis=1) for i in range(13)], axis=1)
    E = bands.sum(axis=1)
    act = E >= E.max() * 10 ** (-30 / 10)
    spec = db(bands[act].sum(axis=0))
    spec = np.maximum(spec - spec.max(), -30)  # 0 dB = loudest band, floor -30 dB (inaudible detail ignored)
    cen = (bands * np.sqrt(edges[:-1] * edges[1:])).sum(axis=1) / (E + 1e-20)
    cpath = np.log2(np.maximum(cen[act], 1))
    contour = np.interp(np.linspace(0, 1, 10), np.linspace(0, 1, max(2, len(cpath))),
                        cpath if len(cpath) > 1 else np.repeat(cpath, 2))
    env, _ = win_ms(xs, 5.0, 2.0)
    env = env / (env.max() + 1e-12)
    envs = np.interp(np.linspace(0, 1, 24), np.linspace(0, 1, len(env)), env)
    return {"timbre": spec, "contour": contour, "env": envs, "dur": len(xs) / SR}


def compare(fa, fb):
    """timbreDb: RMS gap of the half-octave spectra (bands within 30 dB of either top); registerOct: how far apart
    the average brightness is; contourOct: difference of the brightness paths' shapes (up vs down);
    envDist: loudness-shape difference (0..1); durOct: length ratio in octaves; score = the clearest of them"""
    keep = (fa["timbre"] > -30) | (fb["timbre"] > -30)
    t = float(np.sqrt(np.mean((fa["timbre"][keep] - fb["timbre"][keep]) ** 2))) if keep.any() else 0.0
    c = float(np.sqrt(np.mean(((fa["contour"] - fa["contour"].mean()) - (fb["contour"] - fb["contour"].mean())) ** 2)))
    reg = float(abs(fa["contour"].mean() - fb["contour"].mean()))
    e = float(np.sqrt(np.mean((fa["env"] - fb["env"]) ** 2)))
    d = float(abs(math.log2(max(fa["dur"], 1e-3) / max(fb["dur"], 1e-3))))
    s = max(t / 8.0, c / 0.5, reg / 0.7, e / 0.3, d / 1.0)
    return {"timbreDb": round(t, 2), "contourOct": round(c, 3), "registerOct": round(reg, 3), "envDist": round(e, 3),
            "durOct": round(d, 3), "score": round(s, 2)}


# ------------------------------------------------------------------ collecting candidates
def key_of(stem, keys, aliases):
    if stem in aliases:
        return [(k, stem) for k in aliases[stem]]
    if stem in keys:
        return [(stem, "")]
    if "_" in stem:
        base, v = stem.rsplit("_", 1)
        if base in keys:
            return [(base, v)]
        if base in aliases:
            return [(k, stem) for k in aliases[base]]
    mt = re.match(r"^(.*?)(\d+)$", stem)
    if mt and mt.group(1) in keys:
        return [(mt.group(1), mt.group(2))]
    return []


def collect(paths, spec, forced):
    files = []
    for p in paths:
        if os.path.isdir(p):
            for fn in sorted(os.listdir(p)):
                if fn.lower().endswith(AUDIO_EXT):
                    files.append(os.path.join(p, fn))
        elif os.path.isfile(p):
            files.append(p)
    # prefer .wav over .ogg of the same stem (the .ogg is the lossy copy)
    by_stem = {}
    for fp in files:
        st = os.path.splitext(os.path.basename(fp))[0]
        if st not in by_stem or fp.lower().endswith(".wav"):
            by_stem[st] = fp
    keys = spec["keys"]
    aliases = spec.get("aliases", {})
    cands = []
    for st, fp in by_stem.items():
        targets = [(k, st) for k in forced[st]] if st in forced else key_of(st, keys, aliases)
        for k, label in targets:
            cands.append({"key": k, "name": st if label in ("", st) else f"{st}", "file": fp, "stem": st})
    return cands, [st for st in by_stem if st not in forced and not key_of(st, keys, aliases)]


# ------------------------------------------------------------------ drawing (PIL)
def font(size, bold=False, korean=False):
    from PIL import ImageFont
    names = (["malgunbd.ttf", "malgun.ttf"] if korean and bold else ["malgun.ttf"]) if korean else \
        (["arialbd.ttf", "DejaVuSans-Bold.ttf"] if bold else ["arial.ttf", "DejaVuSans.ttf"])
    for nm in names:
        for d in ("", "C:/Windows/Fonts/"):
            try:
                return ImageFont.truetype(d + nm, size)
            except OSError:
                continue
    return ImageFont.load_default()


COL = {"bg": (16, 18, 28), "panel": (26, 29, 44), "grid": (60, 66, 90), "text": (225, 228, 238), "dim": (150, 158, 180),
       "ok": (90, 205, 120), "warn": (245, 190, 70), "fail": (240, 85, 85), "wave": (120, 190, 255),
       "env": (255, 255, 255), "accent": (255, 225, 140)}
F_LO, F_HI = 60.0, 16000.0


def draw_wave(d, box, x, start, tmax, m, rules):
    x0, y0, w, h = box
    d.rectangle([x0, y0, x0 + w, y0 + h], fill=COL["panel"])
    nspan = int(tmax * SR)
    seg = np.pad(x, (0, max(0, nspan - len(x))))[:nspan]
    cols = np.array_split(seg, w)
    mid = y0 + h / 2
    sc = (h / 2 - 3) / max(1e-9, np.abs(x).max())
    for c, s in enumerate(cols):
        if len(s):
            d.line([(x0 + c, mid - s.max() * sc), (x0 + c, mid - s.min() * sc)], fill=COL["wave"])
    tx = lambda t: x0 + int(t / tmax * w)  # noqa: E731
    dr = rules.get("durMs")
    if dr:
        rr = dr.get("range") if isinstance(dr, dict) else dr
        if rr:
            lo = (rr[0] or 0) / 1000 + start / SR
            hi = (rr[1] or tmax * 1000) / 1000 + start / SR
            d.rectangle([tx(lo), y0 + h - 6, tx(min(hi, tmax)), y0 + h - 2], fill=(60, 140, 80))
    for t, colr in ((start / SR, COL["ok"]), (start / SR + m["peakAtMs"] / 1000, COL["accent"]),
                    (start / SR + m["durMs"] / 1000, COL["fail"])):
        d.line([(tx(t), y0), (tx(t), y0 + h)], fill=colr)
    for o in m["onsets"]:
        t = start / SR + o / 1000
        d.polygon([(tx(t) - 4, y0), (tx(t) + 4, y0), (tx(t), y0 + 7)], fill=(120, 230, 255))
    for k in range(0, int(tmax * 1000) + 1, 50):
        d.line([(tx(k / 1000), y0 + h), (tx(k / 1000), y0 + h + (5 if k % 100 == 0 else 2))], fill=COL["dim"])


def draw_env(d, box, m, tmax, f_small):
    x0, y0, w, h = box
    d.rectangle([x0, y0, x0 + w, y0 + h], fill=COL["panel"])
    for dbl in (-12, -30, -50):
        y = y0 + int(-dbl / 60 * h)
        d.line([(x0, y), (x0 + w, y)], fill=COL["grid"])
        d.text((x0 + w + 3, y - 6), f"{dbl}", fill=COL["dim"], font=f_small)
    env, hop, st = m["_env"], m["_envHop"], m["_start"]
    pts = []
    for i, v in enumerate(env):
        t = (st + i * hop) / SR
        if t > tmax:
            break
        pts.append((x0 + t / tmax * w, y0 + min(h, -max(v, -60) / 60 * h)))
    if len(pts) > 1:
        d.line(pts, fill=COL["env"], width=1)


def draw_spectro(d, img, box, x, tmax, m, f_small):
    from PIL import Image
    x0, y0, w, h = box
    nspan = int(tmax * SR)
    seg = np.pad(x, (0, max(0, nspan - len(x)) + 2048))
    n = 2048
    hop = max(1, nspan // w)
    fr = np.fft.rfftfreq(n, 1 / SR)
    rows = np.geomspace(F_LO, F_HI, h)[::-1]
    a = np.zeros((h, w))
    win = np.hanning(n)
    for c in range(w):
        i = max(0, c * hop - n // 2)
        s = np.abs(np.fft.rfft(seg[i:i + n] * win))
        a[:, c] = np.interp(rows, fr, s)
    dbv = 20 * np.log10(a + 1e-9)
    dbv = np.clip((dbv - (dbv.max() - 70)) / 70, 0, 1)
    rgb = np.stack([np.clip(dbv * 1.6, 0, 1) ** 0.8 * 255, np.clip(dbv * 1.3 - 0.35, 0, 1) * 235,
                    (np.clip(0.5 - np.abs(dbv - 0.35), 0, 0.5) * 2) * 170 + 20], -1).astype(np.uint8)
    img.paste(Image.fromarray(rgb, "RGB"), (x0, y0))
    fy = lambda fq: y0 + int((1 - math.log(fq / F_LO) / math.log(F_HI / F_LO)) * (h - 1))  # noqa: E731
    for fq, colr, lab in ((150, (255, 90, 90), "150"), (400, (255, 160, 60), "400 phone"), (2000, (220, 110, 255), "2k"),
                          (5000, (220, 110, 255), "5k"), (8000, (110, 170, 255), "8k"), (1000, COL["grid"], "1k")):
        y = fy(fq)
        for xx in range(x0, x0 + w, 6):
            d.line([(xx, y), (xx + 3, y)], fill=colr)
        d.text((x0 + w + 3, y - 6), lab, fill=colr, font=f_small)
    st = m["_start"] / SR
    for t, c in m["_cenPath"]:
        tt = st + t
        if tt <= tmax and F_LO < c < F_HI:
            xx, yy = x0 + int(tt / tmax * w), fy(c)
            d.ellipse([xx - 1, yy - 1, xx + 1, yy + 1], fill=(255, 255, 255))


def draw_avgspec(d, box, m, f_small):
    x0, y0, w, h = box
    d.rectangle([x0, y0, x0 + w, y0 + h], fill=COL["panel"])
    grid, nar, wid = m["_spec"]
    top = nar.max()
    fx = lambda fq: x0 + int(math.log(fq / F_LO) / math.log(F_HI / F_LO) * (w - 1))  # noqa: E731
    d.rectangle([fx(2000), y0, fx(5000), y0 + h], fill=(48, 34, 64))
    d.rectangle([x0, y0, fx(150), y0 + h], fill=(58, 30, 36))
    for fq in (150, 400, 1000, 2000, 5000, 8000):
        d.line([(fx(fq), y0), (fx(fq), y0 + h)], fill=COL["grid"])
    for arr, colr in ((wid, (120, 130, 160)), (nar, COL["wave"])):
        pts = [(fx(g), y0 + min(h, (top - v) / 60 * h)) for g, v in zip(grid, arr)]
        d.line(pts, fill=colr, width=1)
    if m.get("harshHz"):
        xx = fx(m["harshHz"])
        d.line([(xx, y0), (xx, y0 + h)], fill=COL["warn"])


def fmt(v):
    if isinstance(v, float):
        if abs(v) >= 100:
            return f"{v:.0f}"
        if abs(v) >= 10:
            return f"{v:.1f}"
        return f"{v:.3g}" if abs(v) < 1 else f"{v:.2f}"
    return str(v)


def fmt_range(r):
    if r is None:
        return ""
    if isinstance(r, str):
        return r
    lo, hi = r
    if lo is None:
        return f"<= {fmt(hi)}"
    if hi is None:
        return f">= {fmt(lo)}"
    return f"{fmt(lo)}..{fmt(hi)}"


def render_key(key, kspec, rows, out_path, band=None):
    from PIL import Image, ImageDraw
    f_s, f_m, f_b, f_t = font(11), font(13), font(14, True), font(20, True)
    f_k = font(14, korean=True)
    W = 1990
    notes = kspec.get("notes", {})
    head = 112 + 15 * min(4, len(notes))
    heights = [max(330, 60 + 15 * ((len(r["checks"]) + 1) // 2) + 12) for r in rows]
    img = Image.new("RGB", (W, head + sum(heights) + 10), COL["bg"])
    d = ImageDraw.Draw(img)
    d.text((14, 10), key, fill=COL["accent"], font=f_t)
    d.text((14 + d.textlength(key, font=f_t) + 16, 15), kspec.get("say", ""), fill=COL["text"], font=f_k)
    meta = f'tier {kspec.get("tier", "?")}  Volume {kspec.get("volume", "?")}'
    if band:
        meta += f'  (in-game loudness band {band[0]}..{band[1]} LUFS)'
    meta += f'  |  repeats {kspec.get("repeat", "?")}  |  {kspec.get("status", "")}'
    d.text((14, 40), meta[:260], fill=COL["dim"], font=f_m)
    d.text((14, 60), (kspec.get("moment", "") or "")[:260], fill=COL["dim"], font=f_s)
    yy = 76
    for nk, nv in list(notes.items())[:4]:
        d.text((14, yy), f"- {nk}: {nv}"[:280], fill=(190, 200, 225), font=font(11, korean=True))
        yy += 15
    d.text((14, yy + 2), "verdict: FAIL = a hard limit missed (skip, do not listen)   WARN = soft misses only (listen with "
                         "these in mind)   PASS = listen first.  Squares: red hard miss, amber soft miss, green ok.",
           fill=COL["dim"], font=f_s)
    tmax = max(0.3, min(2.5, max(r["m"]["fileMs"] for r in rows) / 1000 * 1.08))
    rr = kspec.get("rules", {}).get("durMs")
    if rr:
        hr = rr.get("hard") if isinstance(rr, dict) else rr
        if hr and hr[1]:
            tmax = max(tmax, min(2.5, hr[1] / 1000 * 1.1))
    order = {n: k for k, n in enumerate(RANGE_KEYS + ["centDir", "pitchDir"])}
    y = head
    for r, row_h in zip(rows, heights):
        m, checks = r["m"], r["checks"]
        v = r["verdict"]
        vc = COL["ok"] if v == "PASS" else (COL["warn"] if v == "WARN" else COL["fail"])
        d.rectangle([8, y + 2, W - 8, y + row_h - 6], outline=COL["grid"])
        d.rectangle([8, y + 2, 16, y + row_h - 6], fill=vc)
        nf = sum(c["level"] == "fail" for c in checks)
        nw = sum(c["level"] == "warn" for c in checks)
        title = f'{r["name"]}   {v}   score {r["score"]}   ({nf} hard miss, {nw} soft miss)'
        d.text((24, y + 8), title, fill=vc, font=f_b)
        src = os.path.relpath(r["file"], ROOT) if r["file"].startswith(ROOT) else r["file"]
        if r.get("speed", 1.0) != 1.0:
            src += f'  played at {r["speed"]:g}x'
        d.text((24, y + 28), src, fill=COL["dim"], font=f_s)
        x = r["x"]
        st = m["_start"]
        draw_wave(d, (24, y + 46, 560, 110), x, st, tmax, m, kspec.get("rules", {}))
        d.text((24, y + 162), f"0 .. {int(tmax * 1000)} ms (ticks 50 ms) | green start, yellow loudest, red end, "
                              f"cyan onsets, green bar = allowed length", fill=COL["dim"], font=f_s)
        draw_env(d, (24, y + 178, 560, 70), m, tmax, f_s)
        d.text((24, y + 252), "envelope dB (3 ms), lines -12 / -30 / -50", fill=COL["dim"], font=f_s)
        draw_spectro(d, img, (612, y + 46, 470, 160), x, tmax, m, f_s)
        d.text((612, y + 210), "spectrogram 60 Hz-16 kHz (log), white dots = centroid path", fill=COL["dim"], font=f_s)
        draw_avgspec(d, (612, y + 228, 470, 72), m, f_s)
        d.text((612, y + 303), "avg spectrum: blue 1/12 oct, grey 1 oct, red zone < 150 Hz, purple 2-5 kHz, amber = harsh peak",
               fill=COL["dim"], font=f_s)
        d.text((24, y + 272), f'lufs {m["lufs"]}  effLufs {m.get("effLufs", "-")}  rms100 {m["rms100Db"]} dB  '
                              f'phoneLufs {m["phoneLufs"]}  lufsI {m["lufsI"]}  onsets {m["onsets"][:8]}',
               fill=COL["dim"], font=f_s)
        d.text((24, y + 288), f'pitch {m.get("pitchStartHz")} -> {m.get("pitchEndHz")} Hz  ring {m["ringMs"]} ms @ '
                              f'{m["ringHz"]} Hz  harsh {m["harshDb"]} dB @ {m["harshHz"]} Hz  cent {m.get("centStartHz")} '
                              f'/ {m.get("centMidHz")} / {m.get("centEndHz")} Hz', fill=COL["dim"], font=f_s)
        # metrics table, two columns
        srt = sorted(checks, key=lambda c_: (0 if c_["level"] == "fail" else 1 if c_["level"] == "warn" else 2,
                                             order.get(c_["name"].split("@")[0], 99)))
        half = (len(srt) + 1) // 2
        for j, c in enumerate(srt):
            tx0 = 1150 + (j // half) * 420
            ty = y + 46 + (j % half) * 15
            colr = COL[c["level"]]
            d.rectangle([tx0, ty + 3, tx0 + 8, ty + 11], fill=colr)
            unit = CHECK_UNITS.get(c["name"].split("@")[0], "")
            rng = fmt_range(c["range"])
            hard = c.get("hard")
            hs = f' | hard {fmt_range(hard)}' if hard and not isinstance(hard, str) else (" (hard)" if hard else "")
            val = c["value"] if isinstance(c["value"], str) else f'{fmt(c["value"])} {unit}'
            d.text((tx0 + 13, ty), c["name"][:17], fill=colr, font=f_s)
            d.text((tx0 + 118, ty), str(val)[:16], fill=COL["text"], font=f_s)
            d.text((tx0 + 210, ty), f'{rng}{hs}'[:38], fill=COL["dim"], font=f_s)
        y += row_h
    img.save(out_path)
    return out_path


def render_pairs(results, out_path):
    from PIL import Image, ImageDraw
    f_s, f_b = font(12, korean=True), font(18, True)
    lh = 18
    W = 1900
    order = {"fail": 0, "warn": 1, "ok": 2}
    results = sorted(results, key=lambda r_: (order[r_["level"]], r_["kind"]))
    img = Image.new("RGB", (W, 70 + lh * (len(results) + 1)), COL["bg"])
    d = ImageDraw.Draw(img)
    d.text((14, 10), "pair rules: distinct = kids must tell them apart; match = same in-game loudness on PC and phone; "
                     "louder = in-game order", fill=COL["accent"], font=f_b)
    d.text((14, 34), "distinct score = clearest of timbre/8 dB, register/0.7 oct, contour/0.5 oct, envelope/0.3, length/1 oct "
                     "(>= 1 = clearly different). Red = hard rule or same file, amber = soft miss.", fill=COL["dim"], font=f_s)
    y = 58
    for r in results:
        colr = COL["ok"] if r["level"] == "ok" else (COL["warn"] if r["level"] == "warn" else COL["fail"])
        d.rectangle([14, y + 4, 22, y + 12], fill=colr)
        d.text((30, y), f'{r["kind"]:8s} {r["a"]} vs {r["b"]}'[:82], fill=colr, font=f_s)
        d.text((560, y), r["detail"][:210], fill=COL["text"], font=f_s)
        y += lh
    img.save(out_path)
    return out_path


# ------------------------------------------------------------------ main flow
def run(paths, spec_path, out_dir, only_keys, forced, png=True, dump=False):
    spec = load_spec(spec_path)
    keys = spec["keys"]
    cands, unknown = collect(paths, spec, forced)
    cache = {}
    for c in cands:
        if c["file"] not in cache:
            cache[c["file"]] = load(c["file"])
    # reuse keys: a key that plays another key's file at given speeds
    for key, ks in keys.items():
        re_ = ks.get("reuse")
        if not re_:
            continue
        srcs = [c for c in cands if c["key"] in re_["keys"] and not c.get("derived")]
        for s in srcs:
            for sp in re_["speeds"]:
                cands.append({"key": key, "name": f'{s["name"]}@{sp:g}x', "file": s["file"], "stem": s["stem"],
                              "speed": sp, "derived": True})
    if only_keys:
        cands = [c for c in cands if c["key"] in only_keys]
    os.makedirs(out_dir, exist_ok=True)
    results = {}
    for c in cands:
        ks = keys[c["key"]]
        x = cache[c["file"]]
        sp = c.get("speed", 1.0)
        xx = respeed(x, sp) if sp != 1.0 else x
        m = measure(xx)
        rules = rule_list(spec, c["key"])
        checks = check_metrics(m, rules, ks.get("volume"))
        # speed checks: the same file at the game's other PlaybackSpeeds
        for sc in ks.get("speedChecks", []):
            s2 = sc["speed"] * sp
            m2 = measure(respeed(x, s2), full=False)
            sub = check_metrics(m2, {k: v for k, v in sc.items() if k != "speed"}, ks.get("volume"))
            for ch in sub:
                ch["name"] = f'{ch["name"]}@{sc["speed"]:g}x'
            checks += sub
        # the file the user liked (exact bytes): any other file is only a challenger for an A/B against it
        lk = ks.get("liked")
        if lk and not c.get("derived"):
            import hashlib
            with open(c["file"], "rb") as fh:
                hsh = hashlib.sha256(fh.read()).hexdigest()
            same = hsh in lk.get("sha256", [])
            checks.append({"name": "likedFile", "value": "yes" if same else "no", "range": f'same bytes as {lk["file"]}',
                           "hard": None, "level": "ok" if same else "warn"})
        res = {"key": c["key"], "name": c["name"], "file": c["file"], "speed": sp, "m": m, "x": xx, "checks": checks,
               "verdict": verdict(checks), "score": score(checks)}
        results.setdefault(c["key"], []).append(res)
        if dump:
            print(c["key"], c["name"], {k: v for k, v in m.items() if not k.startswith("_") and k != "centPath"})
    # pair rules
    feats = {}
    pair_res = []

    def feat(r_, win):
        fk = (r_["name"], r_["file"], r_.get("speed", 1), win)
        if fk not in feats:
            xx = r_["x"]
            if win:
                st = r_["m"]["_start"]
                xx = xx[st:st + int(SR * win / 1000)]
            feats[fk] = features(xx)
        return feats[fk]

    def in_game(r_, key, phone_=False):
        v = keys[key].get("volume", 1.0)
        return (r_["m"]["phoneLufs"] if phone_ else r_["m"]["lufs"]) + 20 * math.log10(v)

    for pr in spec.get("pairs", []):
        A = results.get(pr["a"], [])
        B = results.get(pr["b"], [])
        kind = pr["kind"]
        for ra in A:
            for rb in B:
                base = {"kind": kind, "a": ra["name"] if ra["name"] == pr["a"] else f'{ra["name"]} [{pr["a"]}]',
                        "b": rb["name"] if rb["name"] == pr["b"] else f'{rb["name"]} [{pr["b"]}]',
                        "ka": pr["a"], "kb": pr["b"], "why": pr.get("why", "")}
                same_file = ra["file"] == rb["file"] and ra.get("speed", 1) == rb.get("speed", 1)
                if kind == "distinct":
                    if same_file:
                        pair_res.append({**base, "level": "fail", "detail": "the same file plays both | " + base["why"]})
                        continue
                    cm = compare(feat(ra, pr.get("windowMs")), feat(rb, pr.get("windowMs")))
                    # the rejected-magic problem: two pitched glides going the same way over overlapping pitches
                    ma, mb = ra["m"], rb["m"]
                    glide = 0
                    if ma.get("periodicity", 0) >= 0.8 and mb.get("periodicity", 0) >= 0.8 and                             ma.get("pitchSemis") is not None and mb.get("pitchSemis") is not None and                             abs(ma["pitchSemis"]) >= 3 and abs(mb["pitchSemis"]) >= 3 and                             (ma["pitchSemis"] > 0) == (mb["pitchSemis"] > 0):
                        lo_a, hi_a = sorted((ma["pitchStartHz"], ma["pitchEndHz"]))
                        lo_b, hi_b = sorted((mb["pitchStartHz"], mb["pitchEndHz"]))
                        glide = 1 if min(hi_a, hi_b) >= max(lo_a, lo_b) else 0
                    cm["sameGlide"] = glide
                    req = dict(pr.get("require", {"score": 1.0}))
                    mode = pr.get("mode", "all")
                    oks = [cm[k] >= v for k, v in req.items()]
                    ok = all(oks) if mode == "all" else any(oks)
                    if pr.get("noSameGlide") and glide:
                        ok = False
                    lvl = "ok" if ok else ("fail" if pr.get("hard") else "warn")
                    det = (" and " if mode == "all" else " or ").join(f"{k} {cm[k]} (>= {v})" for k, v in req.items())
                    if pr.get("noSameGlide"):
                        det += f" | same pitched glide: {'YES' if glide else 'no'}"
                    if "score" not in req:
                        det += f" | score {cm['score']}"
                    det += f" | {base['why']}"
                    pair_res.append({**base, "level": lvl, "metrics": cm, "detail": det})
                elif same_file:  # loudness rules between one file and itself say nothing
                    continue
                elif kind == "match":  # equal loudness in game, on PC and on a phone
                    de = abs(in_game(ra, pr["a"]) - in_game(rb, pr["b"]))
                    dp = abs(in_game(ra, pr["a"], True) - in_game(rb, pr["b"], True))
                    ok = de <= pr.get("lufsTol", 1.0) and dp <= pr.get("phoneTol", 2.0)
                    lvl = "ok" if ok else ("fail" if pr.get("hard") else "warn")
                    pair_res.append({**base, "level": lvl, "metrics": {"dLufsInGame": round(de, 2), "dPhoneInGame": round(dp, 2)},
                                     "detail": f"in-game loudness gap {de:.1f} LU (<= {pr.get('lufsTol', 1.0)}), phone gap "
                                               f"{dp:.1f} LU (<= {pr.get('phoneTol', 2.0)}) | {base['why']}"})
                elif kind == "louder":  # a must be at least minDb louder than b in game
                    dd = in_game(ra, pr["a"]) - in_game(rb, pr["b"])
                    ok = dd >= pr.get("minDb", 1.0)
                    lvl = "ok" if ok else ("fail" if pr.get("hard") else "warn")
                    pair_res.append({**base, "level": lvl, "metrics": {"dInGame": round(dd, 2)},
                                     "detail": f"{pr['a']} is {dd:+.1f} LU vs {pr['b']} in game (need >= +{pr.get('minDb', 1.0)})"
                                               f" | {base['why']}"})
    # outputs
    pngs = []
    for key, rows in results.items():
        rows.sort(key=lambda r: (-{"PASS": 2, "WARN": 1, "FAIL": 0}[r["verdict"]], -r["score"]))
        if png:
            pngs.append(render_key(key, keys[key], rows, os.path.join(out_dir, f"{key}.png"), tier_band(spec, key)))
    if png and pair_res:
        pngs.append(render_pairs(pair_res, os.path.join(out_dir, "pairs.png")))
    summary = {"spec": os.path.relpath(spec_path, ROOT) if spec_path.startswith(ROOT) else spec_path,
               "inputs": paths, "unknownFiles": unknown, "keys": {}, "pairs": pair_res}
    for key, rows in results.items():
        summary["keys"][key] = [{
            "name": r["name"], "file": r["file"], "speed": r["speed"], "verdict": r["verdict"], "score": r["score"],
            "misses": [{"name": c["name"], "value": c["value"], "want": c["range"], "hard": c.get("hard"),
                        "level": c["level"]} for c in r["checks"] if c["level"] != "ok"],
            "metrics": {k: v for k, v in r["m"].items() if not k.startswith("_")},
            "gainToTargetDb": round(spec.get("loudness", {}).get("fileTargetLufs", -17.0) - r["m"]["lufs"], 1),
        } for r in rows]
    with open(os.path.join(out_dir, "summary.json"), "w", encoding="utf-8", newline="\n") as fh:
        json.dump(summary, fh, ensure_ascii=False, indent=1, default=float)
    lines = []
    for key, rows in results.items():
        for r in rows:
            miss = "; ".join(f'{c["name"]}={fmt(c["value"]) if not isinstance(c["value"], str) else c["value"]}'
                             f' (want {fmt_range(c["range"])}{" HARD " + fmt_range(c["hard"]) if c.get("hard") and not isinstance(c.get("hard"), str) else ""})'
                             for c in r["checks"] if c["level"] == "fail")
            warn = "; ".join(f'{c["name"]}={fmt(c["value"]) if not isinstance(c["value"], str) else c["value"]}'
                             f' (want {fmt_range(c["range"])})' for c in r["checks"] if c["level"] == "warn")
            lines.append(f'{key:15s} {r["name"]:24s} {r["verdict"]:4s} {r["score"]:3d}  FAIL: {miss or "-"}  |  '
                         f'WARN: {warn or "-"}')
    lines.append("")
    for p in pair_res:
        lines.append(f'{p["kind"]:8s} {p["level"]:4s} {p["a"]} vs {p["b"]}: {p["detail"]}')
    if unknown:
        lines.append("")
        lines.append("not matched to a key: " + ", ".join(unknown))
    with open(os.path.join(out_dir, "summary.txt"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    return results, pair_res, pngs, unknown


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--spec", default=DEFAULT_SPEC)
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--keys", default="")
    ap.add_argument("--map", default="", help="stem=Key[+Key2],stem2=Key ... (force a file onto keys)")
    ap.add_argument("--no-png", action="store_true")
    ap.add_argument("--dump", action="store_true")
    a = ap.parse_args()
    if sps is None:
        sys.exit("needs scipy (py -m pip install scipy)")
    forced = {}
    for kv in filter(None, a.map.split(",")):
        st, ks = kv.split("=")
        forced[st] = ks.split("+")
    only = set(filter(None, a.keys.split(",")))
    results, pairs, pngs, unknown = run(a.paths, a.spec, a.out, only, forced, png=not a.no_png, dump=a.dump)
    n = {"PASS": 0, "WARN": 0, "FAIL": 0}
    for rows in results.values():
        for r in rows:
            n[r["verdict"]] += 1
    print(f'{sum(n.values())} candidate checks: PASS {n["PASS"]}, WARN {n["WARN"]}, FAIL {n["FAIL"]}; '
          f'pairs {sum(p["level"] == "ok" for p in pairs)}/{len(pairs)} ok')
    print("out:", a.out)
    if unknown:
        print("not matched to a key:", ", ".join(unknown))


if __name__ == "__main__":
    main()
