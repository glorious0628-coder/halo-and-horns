"""
Evaluate Firefly music candidates and cut them into seamless loops (소리 만들기, A23-100).

  py tools/bgm_eval.py --glob "art/sfx/bgm/cand/HaloTown_t2_*.wav" --bars 16 --bpm-range 60 110 --sheet OUT.png

For every file: estimates the beat rate, finds the best loop start/length (tools/bgm_tools.auto_loop), writes
<name>_loop.wav (-24 LUFS), measures the seam and the loudness swing, and draws one sheet (envelope + spectrogram).
Files starting with a Firefly 'Track' have no BPM grid, so the BPM is only a guess that sets the loop length.
"""
import argparse, glob, json, os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import bgm_tools as B
from scipy.signal import stft, spectrogram
from PIL import Image, ImageDraw


def precise_bpm(x, lo, hi):
    m = x.mean(axis=1)
    hop = 128
    f, t, Z = stft(m, fs=B.SR, nperseg=1024, noverlap=1024 - hop)
    mag = np.log1p(20 * np.abs(Z))
    e = np.maximum(np.diff(mag, axis=1), 0).sum(axis=0)
    e = e - e.mean()
    h = hop / B.SR
    ac = np.correlate(e, e, "full")[len(e) - 1:]
    ac /= ac[0]
    best = (-1, None)
    for bpm in np.arange(lo, hi, 0.05):
        T = 60 / bpm / h
        s = c = 0
        for k in range(1, 17):
            p = k * T
            if p >= len(ac) - 2:
                break
            i = int(p)
            s += ac[i] * (1 - (p - i)) + ac[i + 1] * (p - i)
            c += 1
        if s / c > best[0]:
            best = (s / c, bpm)
    return best[1], best[0]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--glob", required=True)
    ap.add_argument("--bars", type=int, default=16)
    ap.add_argument("--beats", type=int, default=4)
    ap.add_argument("--bpm-range", nargs=2, type=float, default=[60, 110])
    ap.add_argument("--sheet", required=True)
    a = ap.parse_args()
    files = sorted(f for f in glob.glob(a.glob) if not f.endswith("_loop.wav"))
    W, H = 900, 170
    sheet = Image.new("RGB", (W * 2, H * len(files)), (250, 250, 250))
    d = ImageDraw.Draw(sheet)
    res = {}
    for row, fn in enumerate(files):
        x = B.read_wav(fn)
        bpm, bs = precise_bpm(x, *a.bpm_range)
        sc, s0, N = B.auto_loop(x, bpm, beats=a.beats, bars=a.bars, xfade_s=2.0)
        nbpm = a.bars * a.beats * 60 / N
        y = B.make_loop(x, nbpm, a.bars, a.beats, s0, 2.0)
        y = y * 10 ** ((-24 - B.lufs(y)) / 20)
        pk = np.abs(y).max()
        if pk > 0.9:
            y = y * 0.9 / pk
        out = fn[:-4] + "_loop.wav"
        B.write_wav(out, y)
        chk = B.seam_check(y)
        m = y.mean(axis=1)
        w = B.SR * 2
        r = [20 * np.log10(np.sqrt(np.mean(m[k:k + w] ** 2)) + 1e-9) for k in range(0, len(m) - w, w)]
        chk.update(score=round(sc, 3), start=s0, loopBpm=round(float(nbpm), 1), swingDb=round(float(max(r) - min(r)), 1),
                   minDb=round(float(min(r)), 1))
        res[os.path.basename(fn)] = chk
        print(os.path.basename(fn), chk)
        y0 = row * H
        hop = int(0.02 * B.SR)
        n = len(m) // hop
        env = np.abs(m[:n * hop]).reshape(n, hop).max(axis=1)
        for k, v in enumerate(env):
            px = int(k / n * (W - 20)) + 10
            hh = int(v * (H / 2 - 10))
            d.line([(px, y0 + H // 2 - hh), (px, y0 + H // 2 + hh)], fill=(60, 90, 200))
        f, tt, S = spectrogram(m, fs=B.SR, nperseg=2048, noverlap=1024)
        S = np.clip((10 * np.log10(S[:150] + 1e-12) + 100) / 60, 0, 1)
        img = Image.fromarray((255 - S[::-1] * 255).astype(np.uint8)).resize((W - 20, H - 30))
        sheet.paste(img.convert("RGB"), (W + 10, y0 + 20))
        d.text((10, y0 + 2), "%s loop %.1fs bpm~%.1f swing %sdB seam %s lufs %s" % (
            os.path.basename(fn), N, nbpm, chk["swingDb"], chk["jumpAtLoop"], chk["lufs"]), fill=(0, 0, 0))
        d.text((W + 10, y0 + 2), "spectrogram 0-3.5 kHz", fill=(0, 0, 0))
    sheet.save(a.sheet)
    json.dump(res, open(a.sheet[:-4] + ".json", "w"), indent=1)


if __name__ == "__main__":
    main()
