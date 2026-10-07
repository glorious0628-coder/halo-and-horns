"""
Firefly 효과음 후보 다듬기 · 모양 시트 · 듣기판 (소리 만들기, 2026-10-07).
  py tools/sfx_firefly.py prep      build/sfx_firefly/raw/<Key>_<p>-<v>.wav (Firefly 원본, git 밖)
                                    -> build/sfx_firefly/trim/<Key>_<p>-<v>.wav (자르기 · 48 kHz 모노 · 크기 맞춤) + 섞은 후보
  py tools/sfx_firefly.py shapes    art/review/sfx_firefly_2026-10-07.png (+ _row<N>.png, .json): 종류마다 Firefly 상위 후보
                                    + 섞은 후보 + 개발 2 3차 g·h·i(회색 머리) 모양 검사. 시트에 오른 후보는 art/sfx/cand/로 복사
  py tools/sfx_firefly.py board     build/sfx_firefly/board.html: 검수 듣기판(Artifact로 올림)
  py tools/sfx_firefly.py ledger    art/sfx/cand/firefly_r4.json: 프롬프트 · Firefly 애셋 id · 자른 곳 · 섞은 곳 · 크레딧 장부
내려받기: Adobe 연결 도구 asset_search(GenAIAsset, firefly-generation-audio) -> asset_get_presigned_urls(acp)의 downloadUrl을
curl로 받아 build/sfx_firefly/raw/에 둔다(원본 WAV 48 kHz 16비트 스테레오 1초). 이름은 브라우저 안 변형 번호와 sha256으로 맞춘다.
원본: Firefly 효과음 생성(사용자 Adobe 계정, 2026-10-07, 1초 · 변형 4개 · 10크레딧). 프롬프트 art/prompts/SFX_<Key>_<p>.txt,
장부 art/sfx/cand/firefly_r4.json. <p> = 프롬프트 번호, <v> = Firefly 화면의 변형 번호(1-4).
모양 검사 칸과 기준은 개발 2 tools/sfx_game.py `shapes`(dev2 968598b, 검수 목표 모양)와 같다. 점프는 이 파일에서 새로 정했다.
"""

import base64
import json
import os
import shutil
import subprocess
import sys
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(ROOT, "build", "sfx_firefly")
RAW = os.path.join(WORK, "raw")
TRIM = os.path.join(WORK, "trim")
CAND = os.path.join(ROOT, "art", "sfx", "cand")
PROMPTS = os.path.join(ROOT, "art", "prompts")
LEDGER = os.path.join(CAND, "firefly_r4.json")
SHEET = os.path.join(ROOT, "art", "review", "sfx_firefly_2026-10-07.png")
SHEET_JSON = SHEET[:-4] + ".json"
BOARD = os.path.join(WORK, "board.html")
SPEC = os.path.join(WORK, "spec")  # one spectrogram crop (with the target drawn) per sheet tile, for the board
DEV2 = os.path.join(os.path.dirname(ROOT), "Game-dev2", "build", "sfx_game", "cand")
KENNEY = os.path.join(ROOT, "build", "devlog", "sfx")
SR = 48000
FFMPEG = shutil.which("ffmpeg") or "ffmpeg"
LOUD_DB, PEAK_DB = -18.0, -3.0  # same file level as the first 32 (loudest 100 ms RMS, peak); game volumes do the rest
SPAN, LO_HZ, HI_HZ = 0.7, 50.0, 12000.0

# per game key: check kind and how to cut a 1 s Firefly clip down to a short game sound
#   start: the clip starts where the envelope first reaches `on` dB (re its loudest 2 ms), `pre` s earlier, faded in over `fin`
#   end: the last point at `off` dB, at most `max` s after the start, faded out over `fout`; then a `hp` Hz high-pass
KIND = {"SwingArcher": "bow", "SwingMage": "magic", "HitHeavy": "thud", "HitCrit": "crit", "Jump": "jump"}
CUT = {
    "bow": dict(on=-10, pre=0.003, fin=0.005, off=-30, max=0.28, fout=0.045, hp=150, lp=0),
    "magic": dict(on=-15, pre=0.005, fin=0.012, off=-34, max=0.48, fout=0.08, hp=150, lp=0),
    "thud": dict(on=-24, pre=0.001, fin=0.0008, off=-32, max=0.26, fout=0.045, hp=45, lp=0),
    "crit": dict(on=-24, pre=0.001, fin=0.0008, off=-38, max=0.5, fout=0.12, hp=45, lp=0),
    "ting": dict(on=-36, pre=0.001, fin=0.0008, off=-38, max=0.5, fout=0.12, hp=300, lp=0),
    "jump": dict(on=-20, pre=0.003, fin=0.004, off=-30, max=0.28, fout=0.05, hp=120, lp=0),
}
# every raw clip is cut with each of these and the cut closest to the target shape is kept (cuts.json says which)
GRID = {
    "bow": [dict(on=o, max=m) for o in (-12, -8, -5, -3) for m in (0.2, 0.24, 0.28)],
    "magic": [dict(on=o, max=m, lp=lp) for o in (-20, -14, -9) for m in (0.38, 0.46) for lp in (0, 9000, 7000)],
    "thud": [dict(on=o, max=m) for o in (-30, -20, -12) for m in (0.2, 0.25, 0.29)],
    "crit": [dict(on=o, max=m, lp=lp) for o in (-30, -20, -12) for m in (0.42, 0.5) for lp in (0, 7000, 5000)],
    "jump": [dict(on=o, max=m) for o in (-20, -12, -6) for m in (0.22, 0.28)],
    "ting": [dict()],
}
TING = "HitCrit_2"  # prompt 2 of the crit is only the bright 'ting' layer: it is mixed over a 퍽, never used alone
ROWS = [  # (title, target, kind, game key, how many Firefly picks, round-3 comparisons)
    ("활 쏘기 · SwingArcher", "목표: '슉' 바람 소리만 · 시작 5–10 ms · 띠 중심 3–5 kHz → 1–2 kHz로 내려감 · 톤 줄 없음 · 0.15–0.3 s",
     "bow", "SwingArcher", 3, ["SwingBow_g", "SwingBow_h", "SwingBow_i"]),
    ("마법 쏘기 · SwingMage", "목표: 2–6 kHz에서 위로 휘며 올라가는 반짝임 · 부드러운 시작 10–20 ms(딸깍 없음) · 0.3–0.5 s",
     "magic", "SwingMage", 3, ["SwingMagic_g", "SwingMagic_h", "SwingMagic_i"]),
    ("퍽 · HitHeavy", "목표: 60–200 Hz 낮은 쿵(아주 빠른 시작) + 2–4 kHz 딸깍 3–10 ms · 0.15–0.3 s · 긴 울림 없음 · 폰에서 들림",
     "thud", "HitHeavy", 3, ["HitThud_g", "HitThud_h", "HitThud_i"]),
    ("치명타 · HitCrit", "목표: 퍽 + 3–8 kHz 맑은 쇠 울림 줄(0.3–0.5 s 동안 줄어듦) · 확실히 특별하게 · 귀를 찌르지 않게",
     "crit", "HitCrit", 2, ["HitCrit_g", "HitCrit_h", "HitCrit_i"]),
    ("점프 · Jump (새 소리)", "목표: 가볍게 '폴짝' · 시작 10 ms 아래 · 0.15–0.3 s · 폰에서 들림(500 Hz–4 kHz 몸통) · 자주 나니 작고 귀엽게",
     "jump", "Jump", 3, []),
]
KO = {  # easy names for the sheet and the board
    "SwingArcher_1": "화살이 휙 지나감", "SwingArcher_2": "얇고 짧은 바람", "SwingArcher_3": "날아가며 내려가는 바람",
    "SwingArcher_4": "가늘게 휙",
    "SwingMage_1": "작은 방울 반짝", "SwingMage_2": "반짝이며 올라감", "SwingMage_3": "지팡이 휙 + 반짝 올라감",
    "SwingMage_4": "부드러운 휘익 + 반짝",
    "HitHeavy_1": "만화 주먹 쿵", "HitHeavy_2": "푹신하고 통통", "HitHeavy_3": "통통 튀는 퍽", "HitHeavy_4": "가운데 소리 퍽 + 딸깍",
    "HitCrit_1": "퍽 + 쨍", "HitCrit_3": "센 퍽 + 쨍 반짝",
    "Jump_1": "가볍게 휙 올라감", "Jump_2": "통통 튀는 폴짝",
    "SwingBow_g": "3차 g · 짧고 날카로운 슉", "SwingBow_h": "3차 h · 조금 굵은 슉", "SwingBow_i": "3차 i · 두 겹 슉슉",
    "SwingMagic_g": "3차 g · 반짝 줄 휘며 올라감", "SwingMagic_h": "3차 h · 방울 구름 올라감", "SwingMagic_i": "3차 i · 반짝반짝 떨며",
    "HitThud_g": "3차 g · 짧은 퍽", "HitThud_h": "3차 h · 둥근 퍽", "HitThud_i": "3차 i · 단단한 퍽",
    "HitCrit_g": "3차 g · 퍽 + 맑은 쨍", "HitCrit_h": "3차 h · 퍽 + 쨍 + 반짝", "HitCrit_i": "3차 i · 퍽 + 쨍쨍",
}


# ------------------------------------------------------------------ audio basics
def count(d):
    return max(1, int(round(d * SR)))


def read_wav(path):
    """any PCM wav -> mono float64 at SR"""
    with wave.open(path, "rb") as w:
        ch, sw, sr, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(n)
    if sw == 2:
        x = np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0
    elif sw == 3:
        b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3)
        x = ((b[:, 0].astype(np.int32) | (b[:, 1].astype(np.int32) << 8) | (b[:, 2].astype(np.int32) << 16)) << 8 >> 8) / 8388608.0
    elif sw == 4:
        x = np.frombuffer(raw, dtype="<i4").astype(np.float64) / 2147483648.0
    else:
        raise ValueError(f"{path}: {sw * 8}-bit")
    x = x.reshape(-1, ch).mean(axis=1)
    if sr != SR:
        x = np.interp(np.arange(0, len(x), sr / SR), np.arange(len(x)), x)
    return x


def write_wav(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).round().astype("<i2").tobytes())


def decode(path):
    r = subprocess.run([FFMPEG, "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"], capture_output=True, check=True)
    return np.frombuffer(r.stdout, dtype=np.float32).astype(np.float64)


def highpass(x, fc, order=2):
    from scipy.signal import butter, sosfilt
    return sosfilt(butter(order, fc, "highpass", fs=SR, output="sos"), x)


def bandpass(x, lo, hi):
    from scipy.signal import butter, sosfiltfilt
    return sosfiltfilt(butter(4, [lo, hi], "bandpass", fs=SR, output="sos"), x)


def kweight(x):
    """ITU-R BS.1770 K-weighting at 48 kHz"""
    from scipy.signal import lfilter
    y = lfilter([1.53512485958697, -2.69169618940638, 1.19839281085285], [1.0, -1.69065929318241, 0.73248077421585], x)
    return lfilter([1.0, -2.0, 1.0], [1.0, -1.99004745483398, 0.99007225036621], y)


def loudest(x, win=0.1):
    w = min(len(x), count(win))
    c = np.concatenate([[0.0], np.cumsum(x * x)])
    rms = np.sqrt(np.maximum(c[w:] - c[:-w], 0) / w)
    return 20 * np.log10(max(rms.max(), 1e-9))


def env_db(x, win=0.002, hop=0.0005, peak=False):
    """(times, dB re the loudest block): RMS (or max |x|) of `win` blocks every `hop`"""
    w, h = count(win), count(hop)
    starts = np.arange(0, max(1, len(x) - w), h)
    if peak:
        a = np.array([np.abs(x[s:s + w]).max() for s in starts])
    else:
        c = np.concatenate([[0.0], np.cumsum(x * x)])
        a = np.sqrt(np.maximum(c[starts + w] - c[starts], 0) / w)
    db = 20 * np.log10(a + 1e-12)
    return (starts + w / 2) / SR, db - db.max()


def level(x):
    """loudest 100 ms RMS -> LOUD_DB, then the peak below PEAK_DB"""
    x = x * 10 ** ((LOUD_DB - loudest(x)) / 20)
    lim = 10 ** (PEAK_DB / 20)
    peak = np.abs(x).max()
    return x * (lim / peak) if peak > lim else x


def lowpass(x, fc, order=2):
    from scipy.signal import butter, sosfilt
    return sosfilt(butter(order, fc, "lowpass", fs=SR, output="sos"), x)


def cut(x, kind, **over):
    """a 1 s Firefly clip -> the short game sound (see CUT; `over` replaces some of the settings)"""
    c = {**CUT[kind], **over}
    x = np.asarray(x, dtype=np.float64)
    x = x - x.mean()
    t, db = env_db(x)
    i0 = int(np.argmax(db >= c["on"]))
    s = max(0, count(t[i0] - c["pre"]))
    live = np.nonzero((db >= c["off"]) & (t >= t[i0]))[0]
    e = min(len(x), count(t[live[-1]] + 0.002) if len(live) else len(x), s + count(c["max"]))
    y = x[s:e].copy()
    fi, fo = count(c["fin"]), min(count(c["fout"]), len(y) // 2)
    y[:fi] *= np.linspace(0, 1, fi) ** 2 if kind in ("magic",) else np.linspace(0, 1, fi)
    y[-fo:] *= np.linspace(1, 0, fo) ** 1.5
    y = highpass(y, c["hp"])
    if c["lp"]:
        y = lowpass(y, c["lp"])
    y[:fi] *= np.linspace(0, 1, fi)  # the filter can lift the first samples: keep the start clean
    return level(y), {"startSec": round(s / SR, 3), "endSec": round(e / SR, 3), "on": c["on"], "max": c["max"], "lp": c["lp"]}


# ------------------------------------------------------------------ measuring (same as dev2 tools/sfx_game.py shapes)
def stft(x, frame=2048, hop=480):
    win = np.hanning(frame)
    xp = np.pad(x, (frame // 2, frame))
    starts = np.arange(0, len(x), hop)
    return np.array([np.abs(np.fft.rfft(xp[s:s + frame] * win)) ** 2 for s in starts]), np.fft.rfftfreq(frame, 1 / SR), starts / SR


def band_path(x, lo, hi):
    S, fr, _ = stft(x, 1024, 240)
    sel = (fr >= lo) & (fr <= hi)
    e = S[:, sel].sum(axis=1)
    loud = np.nonzero(e >= e.max() * 0.01)[0]
    cen = (S[loud][:, sel] * fr[sel]).sum(axis=1) / (e[loud] + 1e-12)
    return [int(cen[min(len(cen) - 1, int(len(cen) * q))]) for q in (0.1, 0.5, 0.9)]


def line_prominence(x, lo, hi, t0=0.0, t1=9.0):
    S, fr, ts = stft(x)
    sel = np.nonzero((fr >= lo) & (fr <= hi))[0]
    e = S[:, sel].sum(axis=1)
    idx = np.arange(len(fr))
    out = []
    for i in np.nonzero((e >= e.max() * 0.01) & (ts >= t0) & (ts <= t1))[0]:
        s = S[i]
        j = sel[np.argmax(s[sel])]
        nb = (fr >= fr[j] / 2 ** (1 / 3)) & (fr <= fr[j] * 2 ** (1 / 3)) & (np.abs(idx - j) > 3)
        out.append(10 * np.log10(s[j] / (np.median(s[nb]) + 1e-20)))
    return round(float(np.median(out)), 1) if out else 0.0


def narrow_spike(x):
    S, fr, _ = stft(x)
    top = S.max()
    sel = np.nonzero((fr >= 2000) & (fr <= 5000))[0]
    idx = np.arange(len(fr))
    best, run, prev = (0, 0.0), 0, None
    for s in S:
        j = sel[np.argmax(s[sel])]
        nb = (fr >= fr[j] / 2 ** (1 / 3)) & (fr <= fr[j] * 2 ** (1 / 3)) & (np.abs(idx - j) > 3)
        hit = 10 * np.log10(s[j] / (np.median(s[nb]) + 1e-20)) >= 20 and s[j] >= top * 10 ** (-1.2)
        run = (run + 1 if prev is not None and abs(j - prev) <= 2 else 1) if hit else 0
        prev = j if hit else None
        if run > best[0]:
            best = (run, float(fr[j]))
    return int(best[1]), round(best[0] * 480 / SR, 3)


def phone_drop(x):
    """how much quieter on a phone speaker (two 400 Hz high-passes), dB"""
    return round(loudest(x) - loudest(highpass(highpass(x, 400), 400)), 1)


def pitch_path(x, frame=2048, hop=480):
    if len(x) < frame:
        x = np.pad(x, (0, frame - len(x)))
    win = np.hanning(frame)
    fr = np.fft.rfftfreq(frame, 1 / SR)
    band = (fr > 100) & (fr < 8000)
    frames = []
    for i in range(0, len(x) - frame + 1, hop):
        s = np.abs(np.fft.rfft(x[i:i + frame] * win)) ** 2
        frames.append((s.sum(), fr[band][np.argmax(s[band])]))
    e = np.array([f[0] for f in frames])
    keep = [f for f in frames if f[0] > e.max() * 10 ** (-25 / 10)]
    return [int(keep[min(len(keep) - 1, int(len(keep) * q))][1]) for q in (0.1, 0.5, 0.9)]


def shape_metrics(x, kind):
    m = {"sec": round(len(x) / SR, 3)}
    t, db = env_db(x)
    on = np.nonzero(db >= -40)[0]
    m["audibleSec"] = round(float(t[on[-1]] - t[on[0]]), 3)
    tp, pdb = env_db(x, 0.0005, 0.00025, peak=True)
    t40 = tp[np.argmax(pdb >= -40)]
    top = pdb[tp <= t40 + 0.08].max()
    m["attackMs"] = round(float(tp[np.argmax(pdb >= top - 3)] - t40) * 1000, 1)
    m["peakDb"] = round(20 * np.log10(np.abs(x).max() + 1e-12), 1)
    m["rms100Db"] = round(loudest(x), 1)
    m["k100Lufs"] = round(loudest(kweight(x)) - 0.691, 1)
    m["phoneDropDb"] = phone_drop(x)
    spec = np.abs(np.fft.rfft(x)) ** 2
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    m["above100"] = round(float(spec[fr > 100].sum() / (spec[fr > 20].sum() + 1e-12)), 3)
    m["spikeHz"], m["spikeSec"] = narrow_spike(x)
    if kind in ("magic", "bow"):
        m["bandKHz"] = [round(c / 1000, 1) for c in band_path(x, 500 if kind == "bow" else 1200, 12000 if kind == "bow" else 9000)]
        m["lineDb"] = line_prominence(x, 800, 8000)
    if kind in ("thud", "crit"):
        head = x[:count(0.1)]
        m["thumpShare"] = round(float((bandpass(head, 60, 200) ** 2).sum() / ((head ** 2).sum() + 1e-12)), 2)
        cl = bandpass(x, 2000, 4000)[:count(0.04)]
        _, cdb = env_db(cl, 0.0005, 0.00025, peak=True)
        m["tickMs"] = round(float(np.count_nonzero(cdb >= -20) * 0.25), 1)
        m["tickDb"] = round(20 * np.log10(np.abs(cl).max() / (np.abs(x).max() + 1e-12) + 1e-12), 1)
    if kind == "crit":
        ring = bandpass(x, 3000, 8000)
        tr, rdb = env_db(ring, 0.005, 0.0025)
        live = np.nonzero(rdb >= -40)[0]
        m["ringSec"] = round(float(tr[live[-1]] - tr[live[0]]), 3)
        m["ringVsThumpDb"] = round(20 * np.log10(np.abs(ring).max() / (np.abs(bandpass(x, 60, 200)).max() + 1e-12)), 1)
        m["ringLineDb"] = line_prominence(x, 3000, 8000, 0.05, 0.3)
    if kind == "jump":
        m["pitchHz"] = pitch_path(x)
        m["lineDb"] = line_prominence(x, 300, 6000)
    return m


def shape_checks(m, kind, kref):
    """[(level, text)]: 2 = on target, 1 = close, 0 = off, -1 = information"""
    def lv(ok, near):
        return 2 if ok else (1 if near else 0)

    def band(lo, hi, v, slack):
        return lv(lo <= v <= hi, lo - slack <= v <= hi + slack)
    a, aud = m["attackMs"], m["audibleSec"]
    rows = []
    if kind == "magic":
        c = m["bandKHz"]
        rises = c[2] >= c[0] * 1.5
        rows.append((band(10, 20, a, 6), f"시작 {a:g} ms (목표 10–20, 딸깍 없이)"))
        rows.append((lv(rises and 1.7 <= c[0] and c[2] <= 6.8, rises), f"띠 {c[0]:g} → {c[1]:g} → {c[2]:g} kHz (2–6에서 위로)"))
        rows.append((band(0.3, 0.5, aud, 0.05), f"들리는 길이 {aud:g} s (0.3–0.5)"))
    elif kind == "bow":
        c = m["bandKHz"]
        rows.append((min(band(5, 10, a, 4), band(0.15, 0.3, aud, 0.04)), f"시작 {a:g} ms (5–10) · 들리는 길이 {aud:g} s (0.15–0.3)"))
        rows.append((lv(2.8 <= c[0] <= 5.3 and 0.9 <= c[2] <= 2.2, c[2] <= c[0] / 1.5), f"띠 중심 {c[0]:g} → {c[2]:g} kHz (3–5 → 1–2)"))
        rows.append((lv(m["lineDb"] < 15, m["lineDb"] < 20), f"톤 줄 {'없음' if m['lineDb'] < 15 else '있음'} (줄 뾰족함 {m['lineDb']:g} dB, 15 아래 = 바람)"))
    elif kind == "jump":
        p = m["pitchHz"]
        rows.append((min(band(0, 10, a, 6), band(0.15, 0.3, aud, 0.06)), f"시작 {a:g} ms (10 아래) · 들리는 길이 {aud:g} s (0.15–0.3)"))
        rows.append((-1, f"음높이 {p[0]} → {p[1]} → {p[2]} Hz ({'올라감' if p[2] > p[0] * 1.15 else ('내려감' if p[2] < p[0] / 1.15 else '평평')}) · 톤 {m['lineDb']:g} dB"))
    else:
        rows.append((min(lv(m["thumpShare"] >= 0.4, m["thumpShare"] >= 0.25), band(0, 5, a, 5)),
                     f"쿵 60–200 Hz 몫 {round(m['thumpShare'] * 100)}% · 시작 {a:g} ms (5 아래)"))
        if kind == "thud":
            rows.append((min(band(3, 10, m["tickMs"], 3), lv(m["tickDb"] >= -24, m["tickDb"] >= -30)),
                         f"딸깍 2–4 kHz {m['tickMs']:g} ms (3–10) · 크기 {m['tickDb']:g} dB"))
            rows.append((band(0.15, 0.3, aud, 0.04), f"들리는 길이 {aud:g} s (0.15–0.3, 긴 울림 없이)"))
        else:
            rows.append((min(band(0.3, 0.5, m["ringSec"], 0.08), lv(m["ringLineDb"] >= 20, m["ringLineDb"] >= 14)),
                         f"쇠 울림 3–8 kHz {m['ringSec']:g} s (0.3–0.5) · 줄 뚜렷함 {m['ringLineDb']:g} dB"))
            rows.append((lv(m["ringVsThumpDb"] <= -10, m["ringVsThumpDb"] <= -8),
                         f"쇠 울림 크기 = 쿵 최대 {m['ringVsThumpDb']:g} dB (-10 아래) · 길이 {aud:g} s"))
    pk = m["peakDb"]
    rows.append((min(lv(pk <= -1.0, pk <= -0.1), lv(m["above100"] >= 0.3, m["above100"] >= 0.15),
                     lv(m["phoneDropDb"] <= 10, m["phoneDropDb"] <= 14)),
                 f"최대 {pk:g} dBFS · 100 Hz 위 {round(m['above100'] * 100)}% · 폰 -{m['phoneDropDb']:g} dB (10 아래)"))
    dk = round(m["k100Lufs"] - kref, 1)
    spike = m["spikeSec"] >= 0.12
    rows.append((min(lv(abs(dk) <= 2, abs(dk) <= 3), lv(not spike, False)),
                 f"크기 K {m['k100Lufs']:g} (같은 줄 평균 {dk:+g} dB) · 2–5 kHz 뾰족 줄 "
                 + (f"{m['spikeHz']} Hz {m['spikeSec']:g} s" if spike else "없음")))
    return rows


def score(checks):
    lv = [c for c, _ in checks if c >= 0]
    return sum(lv) - 2 * lv.count(0)


# ------------------------------------------------------------------ prep: cut every raw clip + the mixes
def kenney(name):
    pack, base = name.split("/")
    return decode(os.path.join(KENNEY, pack, "Audio", base + ".ogg"))


def mix(parts):
    n = max(len(x) + count(d) for x, d, _ in parts)
    out = np.zeros(n)
    for x, d, g in parts:
        s = count(d) if d > 0 else 0
        out[s:s + len(x)] += x * g
    return out


AIM = {"bow": 0.22, "magic": 0.4, "thud": 0.22, "crit": 0.42, "jump": 0.24, "ting": 0.45}  # tie-break: audible length


def best_cut(x, kind):
    """try every GRID cut, keep the one whose shape checks (all but loudness) score best"""
    best = None
    for g in GRID[kind]:
        y, info = cut(x, kind, **g)
        if kind == "ting":
            return y, info
        m = shape_metrics(y, kind)
        s = (score(shape_checks(m, kind, m["k100Lufs"])[:-1]), -abs(m["audibleSec"] - AIM[kind]))
        if best is None or s > best[0]:
            best = (s, y, {**info, "shapeScore": s[0]})
    return best[1], best[2]


def prep():
    os.makedirs(TRIM, exist_ok=True)
    cuts = {}
    for f in sorted(os.listdir(RAW)):
        if not f.endswith(".wav"):
            continue
        name = f[:-4]
        key = name.rsplit("_", 1)[0]
        kind = "ting" if name.startswith(TING + "-") else KIND[key]
        y, info = best_cut(read_wav(os.path.join(RAW, f)), kind)
        write_wav(os.path.join(TRIM, f), y)
        cuts[name] = {"kind": kind, **info}
    with open(os.path.join(WORK, "cuts.json"), "w", encoding="utf-8") as fh:
        json.dump(cuts, fh, indent=1)
    print("cut", len(cuts))
    return cuts


def best_of(names, kind):
    xs = {n: read_wav(os.path.join(TRIM, n + ".wav")) for n in names}
    ms = {n: shape_metrics(x, kind) for n, x in xs.items()}
    kref = float(np.mean([m["k100Lufs"] for m in ms.values()]))
    ranked = sorted(names, key=lambda n: -score(shape_checks(ms[n], kind, kref)))
    return ranked, xs, ms


def make_mixes():
    """퍽 + a thin Kenney punch (phone body) and 치명타 = the best 퍽 + the best Firefly 'ting' layer"""
    for f in os.listdir(TRIM):
        if "_mix-" in f:
            os.remove(os.path.join(TRIM, f))
    thuds = sorted(f[:-4] for f in os.listdir(TRIM) if f.startswith("HitHeavy_"))
    ranked, xs, ms = best_of(thuds, "thud")
    # the Kenney layer is for phone body: put it under the best 퍽 that is weak on a phone (else under the best one)
    base = next((r for r in ranked[:5] if ms[r]["phoneDropDb"] > 8), ranked[0])
    out = {}

    def mid_share(name):
        x = kenney(name)
        x = x[:count(0.2)]
        return float((bandpass(x, 500, 4000) ** 2).sum() / ((x ** 2).sum() + 1e-12))
    layer = max([f"impact/impactPunch_medium_00{i}" for i in range(5)] + [f"impact/impactGeneric_light_00{i}" for i in range(5)], key=mid_share)
    punch = highpass(kenney(layer), 300, 4)
    punch = punch[np.argmax(np.abs(punch) > np.abs(punch).max() * 0.05):]
    pick = None
    for g_db in (-16, -13, -10, -7, -4, -2):
        y = level(mix([(xs[base], 0, 1.0), (punch * np.abs(xs[base]).max() / np.abs(punch).max(), 0.0, 10 ** (g_db / 20))]))
        y = y[:len(xs[base])]
        y[-count(0.03):] *= np.linspace(1, 0, count(0.03))
        pick = (g_db, level(y))
        if phone_drop(pick[1]) <= 7:
            break
    name = f"HitHeavy_mix-{base.split('_', 1)[1]}+kenney"
    write_wav(os.path.join(TRIM, name + ".wav"), pick[1])
    out[name] = {"kind": "thud", "from": [base, f"Kenney Impact Sounds · {layer.split('/')[1]} (CC0) · 300 Hz high-pass"],
                 "punchDb": pick[0], "phoneDropDb": [ms[base]["phoneDropDb"], phone_drop(pick[1])]}
    tings = sorted(f[:-4] for f in os.listdir(TRIM) if f.startswith(TING + "-"))
    tm = {n: read_wav(os.path.join(TRIM, n + ".wav")) for n in tings}
    tbest = max(tings, key=lambda n: line_prominence(tm[n], 3000, 8000, 0.02, 0.3) - 6 * abs(len(tm[n]) / SR - 0.45))

    def own_ring(n):  # how loud the 퍽's own 3-8 kHz is (its click): the ring layer needs room above it
        return 20 * np.log10(np.abs(bandpass(xs[n], 3000, 8000)).max() / (np.abs(bandpass(xs[n], 60, 200)).max() + 1e-12) + 1e-12)
    # the best 퍽 (so 퍽 and 치명타 can share one hit) + the 퍽 with the quietest own click
    bases = [ranked[0]] + [r for r in sorted(ranked[:6], key=own_ring) if r != ranked[0]][:1]
    for b in bases:
        thump = lowpass(xs[b], 2500, 4)  # in the crit the 'ting' is the bright part: the 퍽's own click steps back
        ring = tm[tbest][:count(0.5)].copy()
        ring[-count(0.12):] *= np.linspace(1, 0, count(0.12)) ** 1.5
        lo = np.abs(bandpass(thump, 60, 200)).max() + 1e-9
        unit = lo / (np.abs(bandpass(ring, 3000, 8000)).max() + 1e-9)
        best = None
        for g_db in range(-20, -5):  # the loudest ring that stays >= 10 dB under the thump, clear line preferred
            y = level(mix([(thump, 0, 1.0), (ring, 0.002, unit * 10 ** (g_db / 20))]))
            m = shape_metrics(y, "crit")
            key = (m["ringVsThumpDb"] <= -10, m["ringLineDb"] >= 20, g_db if m["ringVsThumpDb"] <= -10 else -abs(m["ringVsThumpDb"] + 10))
            if best is None or key > best[0]:
                best = (key, y, g_db)
        name = f"HitCrit_mix-{b.split('_', 1)[1]}+{tbest.split('_', 1)[1]}"
        write_wav(os.path.join(TRIM, name + ".wav"), best[1])
        out[name] = {"kind": "crit", "from": [b, tbest], "ringDb": best[2]}
    with open(os.path.join(WORK, "mixes.json"), "w", encoding="utf-8") as fh:
        json.dump(out, fh, ensure_ascii=False, indent=1)
    print("mixes", list(out))
    return out


# ------------------------------------------------------------------ drawing (same cells as dev2 shapes)
def _font(size, bold=False):
    from PIL import ImageFont
    for name in ("malgunbd.ttf" if bold else "malgun.ttf", "arialbd.ttf" if bold else "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def _cmap(v):
    pts = [(0.0, (10, 10, 24)), (0.3, (72, 22, 112)), (0.55, (186, 54, 92)), (0.78, (248, 142, 44)), (1.0, (255, 248, 200))]
    out = np.zeros(v.shape + (3,))
    for c in range(3):
        out[..., c] = np.interp(v, [p[0] for p in pts], [p[1][c] for p in pts])
    return out.astype(np.uint8)


def _fy(f, h):
    return (np.log(HI_HZ) - np.log(f)) / (np.log(HI_HZ) - np.log(LO_HZ)) * (h - 1)


def spec_image(x, w, h):
    from PIL import Image
    span = count(SPAN)
    x = np.pad(x, (0, max(0, span - len(x))))[:span]
    rows = np.exp(np.log(HI_HZ) - np.arange(h) / (h - 1) * (np.log(HI_HZ) - np.log(LO_HZ)))
    centres = ((np.arange(w) + 0.5) * span / w).astype(int)
    layers = []
    for frame in (2048, 1024, 512):
        win = np.hanning(frame)
        xp = np.pad(x, (frame // 2, frame // 2))
        fr = np.fft.rfftfreq(frame, 1 / SR)
        mag = np.array([np.interp(rows, fr, np.abs(np.fft.rfft(xp[c:c + frame] * win))) for c in centres]).T / win.sum()
        layers.append(20 * np.log10(mag + 1e-9))
    lf = np.log(rows)
    w_lo = np.clip((np.log(400) - lf) / (np.log(400) - np.log(250)), 0, 1)
    w_hi = np.clip((lf - np.log(1200)) / (np.log(2000) - np.log(1200)), 0, 1)
    db = (layers[0] * w_lo[:, None] + layers[1] * ((1 - w_lo) * (1 - w_hi))[:, None] + layers[2] * w_hi[:, None])
    v = np.clip((db - (db.max() - 70)) / 70, 0, 1)
    return Image.fromarray(_cmap(v), "RGB")


def wave_image(x, w, h, seconds, colour=(150, 200, 255)):
    from PIL import Image, ImageDraw
    im = Image.new("RGB", (w, h), (18, 20, 32))
    d = ImageDraw.Draw(im)
    mid = (h - 1) / 2
    d.line([(0, mid), (w, mid)], fill=(50, 54, 74))
    n = count(seconds)
    for c in range(w):
        seg = x[int(c * n / w):max(int(c * n / w) + 1, int((c + 1) * n / w))]
        if len(seg):
            d.line([(c, mid - seg.max() * mid), (c, mid - seg.min() * mid)], fill=colour)
    return im


def _dashed(d, pts, fill, width=1, dash=5, gap=4):
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        length = max(1e-6, ((x1 - x0) ** 2 + (y1 - y0) ** 2) ** 0.5)
        s = 0.0
        while s < length:
            e = min(length, s + dash)
            d.line([(x0 + (x1 - x0) * s / length, y0 + (y1 - y0) * s / length), (x0 + (x1 - x0) * e / length, y0 + (y1 - y0) * e / length)],
                   fill=fill, width=width)
            s += dash + gap


def _targets(d, kind, x0, y0, w, h):
    def px(t):
        return x0 + t / SPAN * w

    def py(f):
        return y0 + _fy(f, h)

    def box(t0, t1, f0, f1):
        _dashed(d, [(px(t0), py(f1)), (px(t1), py(f1)), (px(t1), py(f0)), (px(t0), py(f0)), (px(t0), py(f1))], (90, 230, 255))
    if kind == "magic":
        box(0, 0.5, 2000, 6000)
        marks = (0.3, 0.5)
    elif kind == "bow":
        _dashed(d, [(px(0), py(5000)), (px(0.3), py(2000))], (90, 230, 255), 2)
        _dashed(d, [(px(0), py(3000)), (px(0.3), py(1000))], (90, 230, 255), 2)
        marks = (0.15, 0.3)
    elif kind == "jump":
        box(0, 0.3, 500, 4000)
        marks = (0.15, 0.3)
    else:
        box(0, 0.3, 60, 200)
        if kind == "thud":
            box(0, 0.012, 2000, 4000)
            marks = (0.15, 0.3)
        else:
            box(0, 0.5, 3000, 8000)
            marks = (0.3, 0.5)
    for t in marks:
        d.line([(px(t), y0), (px(t), y0 + 5)], fill=(255, 255, 255), width=2)
        d.line([(px(t), y0 + h - 6), (px(t), y0 + h - 1)], fill=(255, 255, 255), width=2)


def prompt_of(name):
    """'SwingArcher_3-2' -> the prompt text of art/prompts/SFX_SwingArcher_3.txt"""
    p = os.path.join(PROMPTS, "SFX_" + name.split("-")[0] + ".txt")
    return open(p, encoding="utf-8").read().strip() if os.path.exists(p) else ""


def label_of(name):
    if name.startswith(("HitHeavy_mix", "HitCrit_mix")):
        parts = name.split("-", 1)[1].split("+")
        if name.startswith("HitHeavy_mix"):
            return f"섞음 · 퍽 {parts[0]} + Kenney 주먹 얇게"
        return f"섞음 · 퍽 {parts[0]} + 쨍 {parts[1]}"
    if name in KO:
        return KO[name]
    return f"{name.split('_', 1)[1]} · {KO.get(name.split('-')[0], '')}"


def collect():
    """the rows of the sheet: per kind the best Firefly cuts (two at most from one prompt) + mixes + dev2 round 3"""
    mixes = json.load(open(os.path.join(WORK, "mixes.json"), encoding="utf-8"))
    rows = []
    for title, target, kind, key, n, dev2 in ROWS:
        names = sorted(f[:-4] for f in os.listdir(TRIM) if f.startswith(key + "_") and not f.startswith(TING + "-") and "_mix-" not in f)
        ranked, xs, ms = best_of(names, kind)
        chosen, per = [], {}
        for r in ranked:
            p = r.split("-")[0]
            if per.get(p, 0) >= 2:
                continue
            chosen.append(r)
            per[p] = per.get(p, 0) + 1
            if len(chosen) >= n:
                break
        items = [(r, os.path.join(TRIM, r + ".wav"), "firefly") for r in chosen]
        items += [(m, os.path.join(TRIM, m + ".wav"), "mix") for m, v in mixes.items() if v["kind"] == kind]
        items += [(g, os.path.join(DEV2, g + ".wav"), "dev2") for g in dev2 if os.path.exists(os.path.join(DEV2, g + ".wav"))]
        rows.append((title, target, kind, key, items, {r: ms[r] for r in names}))
    return rows


def shapes():
    from PIL import Image, ImageDraw
    rows = collect()
    tw, wh, inset, sh = 430, 62, 104, 156
    tile_h = 44 + wh + 8 + sh + 18 + 6 * 19 + 40
    row_h = 52 + tile_h + 14
    ncol = max(len(r[4]) for r in rows)
    width = 20 + ncol * (tw + 16)
    img = Image.new("RGB", (width, 64 + len(rows) * row_h), (12, 13, 22))
    d = ImageDraw.Draw(img)
    f_title, f_row, f_head, f_txt, f_small = _font(22, True), _font(18, True), _font(15, True), _font(14), _font(11)
    d.text((20, 12), "효과음 4차 후보 (Firefly 생성) — 파형 + 스펙트로그램 (2026-10-07, 소리 만들기)", fill=(240, 240, 250), font=f_title)
    d.text((20, 40), "스펙트로그램: 세로 = 음높이(아래 50 Hz → 위 12 kHz, 로그), 가로 = 0–0.7 s, 밝을수록 큼 · 하늘색 점선 = 목표 모양 · 흰 눈금 = 목표 길이 · "
           "점: 초록 = 목표 안, 노랑 = 조금 벗어남, 빨강 = 벗어남, 회색 = 참고 · 회색 머리 = 개발 2 3차(비교) · 맨 아래 = Firefly 프롬프트",
           fill=(170, 176, 200), font=f_small)
    report = {"rows": []}
    crops = []
    for r, (title, target, kind, key, items, _all) in enumerate(rows):
        ry = 64 + r * row_h
        d.text((20, ry), title, fill=(255, 226, 140), font=f_row)
        d.text((20, ry + 26), target, fill=(150, 225, 255), font=f_txt)
        xs = {n: read_wav(p) for n, p, _ in items}
        ms = {n: shape_metrics(x, kind) for n, x in xs.items()}
        kref = float(np.mean([m["k100Lufs"] for m in ms.values()]))
        rep = {"title": title, "target": target, "kind": kind, "candidates": []}
        for c, (name, path, src) in enumerate(items):
            x0, y0 = 20 + c * (tw + 16), ry + 52
            x, m = xs[name], ms[name]
            checks = shape_checks(m, kind, kref)
            head = (60, 62, 76) if src == "dev2" else ((70, 52, 110) if src == "mix" else (32, 70, 60))
            d.rectangle([x0 - 6, y0 - 4, x0 + tw + 6, y0 + tile_h], fill=(20, 22, 36), outline=(44, 48, 70))
            d.rectangle([x0 - 6, y0 - 4, x0 + tw + 6, y0 + 18], fill=head)
            tag = {"firefly": "Firefly", "mix": "섞음", "dev2": "3차(개발 2)"}[src]
            d.text((x0, y0 - 2), f"{name if src != 'dev2' else name} · {tag}", fill=(255, 255, 255), font=f_head)
            d.text((x0, y0 + 21), f"{label_of(name)} · 길이 {m['sec']:g} s · 최대 {m['peakDb']:g} dBFS", fill=(205, 210, 228), font=f_txt)
            wy = y0 + 44
            img.paste(wave_image(x, tw - inset - 8, wh, SPAN), (x0, wy))
            img.paste(wave_image(x, inset, wh, 0.04, (255, 210, 150)), (x0 + tw - inset, wy))
            d.text((x0 + tw - inset + 3, wy + 1), "첫 40 ms", fill=(255, 210, 150), font=f_small)
            sy = wy + wh + 8
            img.paste(spec_image(x, tw, sh), (x0, sy))
            for f, lab in ((100, "100"), (300, "300"), (1000, "1k"), (3000, "3k"), (8000, "8k")):
                yy = sy + _fy(f, sh)
                d.line([(x0, yy), (x0 + 5, yy)], fill=(200, 230, 255))
                d.text((x0 + 7, yy - 7), lab, fill=(200, 230, 255), font=f_small)
            _targets(d, kind, x0, sy, tw, sh)
            for k in range(8):
                tx = x0 + k * 0.1 / SPAN * tw
                d.line([(tx, sy + sh), (tx, sy + sh + 4)], fill=(150, 156, 180))
                d.text((tx + 2, sy + sh + 2), f"{k / 10:g}" + (" s" if k == 7 else ""), fill=(150, 156, 180), font=f_small)
            os.makedirs(SPEC, exist_ok=True)
            img.crop((x0, sy, x0 + tw, sy + sh + 16)).save(os.path.join(SPEC, name + ".jpg"), quality=86)
            cy = sy + sh + 20
            for lvl, text in checks:
                col = {2: (80, 210, 120), 1: (240, 196, 60), 0: (240, 80, 80), -1: (130, 134, 150)}[lvl]
                d.ellipse([x0, cy + 5, x0 + 9, cy + 14], fill=col)
                d.text((x0 + 15, cy), text, fill=(225, 228, 240) if lvl >= 0 else (170, 174, 190), font=f_txt)
                cy += 19
            note = prompt_of(name) if src == "firefly" else ("Kenney CC0 한 겹 + Firefly" if "kenney" in name else ("Firefly 두 겹" if src == "mix" else "우리 합성(개발 2)"))
            d.text((x0, cy + 2), (f"“{note}”" if src == "firefly" else note)[:70], fill=(150, 225, 255) if src == "firefly" else (170, 174, 190), font=f_small)
            rep["candidates"].append({"name": name, "source": src, "label": label_of(name), "file": os.path.relpath(path, ROOT).replace("\\", "/"),
                                      "prompt": prompt_of(name) if src == "firefly" else "", **m, "score": score(checks),
                                      "checks": [[lvl, t] for lvl, t in checks]})
        report["rows"].append(rep)
        crops.append((ry - 8, ry + row_h - 6))
    os.makedirs(os.path.dirname(SHEET), exist_ok=True)
    img.save(SHEET, optimize=True)
    for i, (a, b) in enumerate(crops, 1):
        img.crop((0, a, width, b)).save(f"{SHEET[:-4]}_row{i}.png", optimize=True)
    with open(SHEET_JSON, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(report, fh, ensure_ascii=False, indent=1)
    os.makedirs(CAND, exist_ok=True)
    for row in report["rows"]:
        for c in row["candidates"]:
            if c["source"] != "dev2":
                shutil.copyfile(os.path.join(ROOT, c["file"]), os.path.join(CAND, c["name"] + ".wav"))
    print(SHEET)
    return report


# ------------------------------------------------------------------ the 검수 listening board
# 소리 만들기의 추천(검수가 고른다). 숫자는 시트 .json 값이다.
RECOMMEND = {
    "bow": ("SwingArcher_1-1", "높은 바람이 5.5 → 2.1 kHz로 내려가는 '슉' 모양이 목표에 가장 가깝고 톤 줄이 없어요(0.23 s, 시작 9 ms)."),
    "magic": ("SwingMage_3-4", "3.0 → 4.8 kHz로 위로 휘며 올라가는 반짝임, 부드러운 시작 14 ms, 0.37 s. 검사가 모두 초록이에요."),
    "thud": ("HitHeavy_4-4", "낮은 쿵(44 %) + 딸깍 6.5 ms, 0.23 s, 폰에서 -6.5 dB만 줄어요. 검사가 모두 초록이에요."),
    "crit": ("HitCrit_mix-4-4+2-1", "추천 퍽(4-4) 위에 맑은 쨍(0.45 s, 쿵보다 10 dB 작게)을 얹었어요. 퍽과 같은 타격이라 이어서 들려요."),
    "jump": ("Jump_2-2", "짧고 통통한 '퐁'(0.21 s, 시작 3 ms). 톤이 약해서 자주 들어도 덜 거슬려요."),
}


def _b64(path):
    return base64.b64encode(open(path, "rb").read()).decode()


def board():
    import html as H
    report = json.load(open(SHEET_JSON, encoding="utf-8"))
    sections = []
    for row in report["rows"]:
        rec, why = RECOMMEND.get(row["kind"], ("", ""))
        tiles = []
        for c in row["candidates"]:
            dots = "".join(f'<li class="l{lvl}">{H.escape(t)}</li>' for lvl, t in c["checks"])
            src = {"firefly": "Firefly", "mix": "섞음", "dev2": "3차 · 개발 2"}[c["source"]]
            prompt = f'<p class="prompt">“{H.escape(c["prompt"])}”</p>' if c["prompt"] else ""
            spec = os.path.join(SPEC, c["name"] + ".jpg")
            img = f'<img class="spec" alt="{H.escape(c["name"])} 스펙트로그램" src="data:image/jpeg;base64,{_b64(spec)}">' if os.path.exists(spec) else ""
            chip = '<span class="pick">추천</span>' if c["name"] == rec else ""
            tiles.append(
                f'<article class="tile {c["source"]}{" rec" if c["name"] == rec else ""}">'
                f'<header><code>{H.escape(c["name"])}</code><span class="src">{src}</span>{chip}</header>'
                f'<p class="ko">{H.escape(c["label"])} · {c["audibleSec"]:g} s</p>{img}'
                f'<audio controls preload="none" src="data:audio/wav;base64,{_b64(os.path.join(ROOT, c["file"]))}"></audio>'
                f'<ul>{dots}</ul>{prompt}</article>')
        recline = f'<p class="rec-line"><span class="pick">추천</span> <code>{H.escape(rec)}</code> — {H.escape(why)}</p>' if rec else ""
        sections.append(f'<section><h2>{H.escape(row["title"])}</h2><p class="target">{H.escape(row["target"])}</p>{recline}'
                        f'<div class="grid">{"".join(tiles)}</div></section>')
    page = BOARD_HTML.replace("{{BODY}}", "".join(sections))
    with open(BOARD, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(page)
    print(BOARD, round(os.path.getsize(BOARD) / 1e6, 2), "MB")


BOARD_HTML = """<title>효과음 4차 듣기판</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans+KR:wght@400;600&display=swap">
<style>
/* layout: one column of sound kinds; each kind = target line + a wrapping grid of candidate tiles (spectrogram, player, checks) */
:root{--bg:#f3f4f7;--surface:#ffffff;--ink:#1b1d24;--muted:#5a5f6e;--line:#dde0e8;--accent:#1d7487;--mix:#6a4fb0;--ref:#868b98;
--ok:#2b9656;--near:#b07d0c;--off:#c8463d;--pickbg:#e3f3f6;
--sans:"IBM Plex Sans KR","Malgun Gothic","Apple SD Gothic Neo",system-ui,sans-serif;--mono:"IBM Plex Mono",ui-monospace,Consolas,monospace}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--bg:#121419;--surface:#1b1e26;--ink:#e8eaf1;--muted:#a1a6b4;--line:#2c303b;--accent:#5bc2d4;--mix:#a48df0;--ref:#9a9fac;--ok:#4cca82;--near:#e2b33f;--off:#ee665e;--pickbg:#183139;color-scheme:dark}}
:root[data-theme="dark"]{--bg:#121419;--surface:#1b1e26;--ink:#e8eaf1;--muted:#a1a6b4;--line:#2c303b;--accent:#5bc2d4;--mix:#a48df0;--ref:#9a9fac;--ok:#4cca82;--near:#e2b33f;--off:#ee665e;--pickbg:#183139;color-scheme:dark}
body{background:var(--bg);color:var(--ink);font:15px/1.55 var(--sans)}
main{max-width:1240px;margin:0 auto;padding-inline:16px;padding-block:24px 48px;display:flex;flex-direction:column;gap:30px}
h1{font-size:1.5rem;margin:0;text-wrap:balance}h2{font-size:1.15rem;margin:0;text-wrap:balance}
.lead{margin:6px 0 0;color:var(--muted);max-width:70ch}
.legend{display:flex;flex-wrap:wrap;gap:6px 16px;margin:10px 0 0;padding:0;list-style:none;font-size:.82rem;color:var(--muted)}
section{display:flex;flex-direction:column;gap:6px}
.target{margin:0;color:var(--muted);font-size:.86rem}
.rec-line{margin:2px 0 6px;font-size:.9rem}
code{font-family:var(--mono);font-size:.85em}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:14px}
.tile{min-width:0;background:var(--surface);border:1px solid var(--line);border-radius:10px;padding:12px;display:flex;flex-direction:column;gap:8px;border-top:4px solid var(--accent)}
.tile.mix{border-top-color:var(--mix)}.tile.dev2{border-top-color:var(--ref)}
.tile.rec{box-shadow:0 0 0 2px var(--accent)}
.tile header{display:flex;align-items:baseline;gap:8px;flex-wrap:wrap}
.src{font-size:.75rem;color:var(--muted);letter-spacing:.02em}
.pick{display:inline-block;font-size:.72rem;font-weight:600;color:var(--accent);background:var(--pickbg);border-radius:999px;padding:1px 8px}
.ko{margin:0;font-size:.9rem}
.spec{width:100%;max-width:100%;height:auto;border-radius:6px;display:block}
audio{width:100%}
ul.checks,.tile ul{list-style:none;margin:0;padding:0;font-size:.78rem;display:flex;flex-direction:column;gap:2px;font-variant-numeric:tabular-nums}
.tile li,.legend li{position:relative;padding-left:15px}
.tile li:before,.legend li:before{content:"";position:absolute;left:0;top:.45em;width:9px;height:9px;border-radius:50%;background:var(--ref)}
li.l2:before{background:var(--ok)}li.l1:before{background:var(--near)}li.l0:before{background:var(--off)}
.prompt{margin:0;font-size:.8rem;color:var(--muted);font-style:italic}
@media (prefers-reduced-motion: reduce){*{scroll-behavior:auto}}
</style>
<main>
<header>
<h1>효과음 4차 듣기판</h1>
<p class="lead">검수용입니다. 종류마다 하나를 골라 주세요. 위 띠 색: 청록 = Firefly 생성, 보라 = 섞은 것, 회색 = 개발 2 3차(비교). 그림은 스펙트로그램(세로 50 Hz–12 kHz, 가로 0–0.7 s)이고 하늘색 점선이 목표 모양이에요.
Firefly 1초 클립을 잘라 48 kHz 모노로 맞췄어요(가장 큰 100 ms = -18 dBFS). 2026-10-07 · Firefly 17번 생성(170크레딧).</p>
<ul class="legend"><li class="l2">목표 안</li><li class="l1">조금 벗어남</li><li class="l0">벗어남</li><li>참고</li></ul>
</header>
{{BODY}}
</main>
"""


def ledger(credits=170, balance_before=9640, board_url=""):
    assets = json.load(open(os.path.join(WORK, "raw_assets.json"), encoding="utf-8"))
    cuts = json.load(open(os.path.join(WORK, "cuts.json"), encoding="utf-8"))
    mixes = json.load(open(os.path.join(WORK, "mixes.json"), encoding="utf-8"))
    sheet = json.load(open(SHEET_JSON, encoding="utf-8"))
    shown = [c["name"] for r in sheet["rows"] for c in r["candidates"] if c["source"] != "dev2"]
    prompts = {f[4:-4]: open(os.path.join(PROMPTS, f), encoding="utf-8").read().strip()
               for f in sorted(os.listdir(PROMPTS)) if f.startswith("SFX_") and f.endswith(".txt")}
    book = {
        "round": 4, "date": "2026-10-07", "by": "소리 만들기",
        "made": "Adobe Firefly 'Generate sound effects' (firefly.adobe.com, the user's Adobe account): 1 s, 4 variations per generation",
        "license": "Firefly generation (Adobe: commercially safe output); our edit = cut, mono 48 kHz, high-pass/low-pass, level",
        "credits": {"generations": credits // 10, "perGeneration": 10, "used": credits, "balanceBefore": balance_before,
                    "balanceAfter": balance_before - credits},
        "prompts": {k: v for k, v in prompts.items()},
        "sheet": os.path.relpath(SHEET, ROOT).replace("\\", "/"), "board": board_url,
        "recommend": {k: v[0] for k, v in RECOMMEND.items()},
        "onSheet": shown,
        "clips": {n[:-4]: {**assets.get(n, {}), **cuts.get(n[:-4], {})} for n in sorted(assets)},
        "mixes": mixes,
    }
    with open(LEDGER, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(book, fh, ensure_ascii=False, indent=1)
    keep = {n + ".wav" for n in shown} | {os.path.basename(LEDGER)}
    for f in os.listdir(CAND):
        if f not in keep:
            os.remove(os.path.join(CAND, f))
    print(LEDGER, len(shown), "candidates kept in art/sfx/cand")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    cmd = sys.argv[1] if len(sys.argv) > 1 else "prep"
    if cmd == "prep":
        prep()
        make_mixes()
    elif cmd == "mixes":
        make_mixes()
    elif cmd == "shapes":
        shapes()
    elif cmd == "board":
        board()
    elif cmd == "ledger":
        ledger(board_url=sys.argv[2] if len(sys.argv) > 2 else "")
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
