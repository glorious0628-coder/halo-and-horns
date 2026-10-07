"""
전투 장면 렌더 (소리 만들기, 2026-10-07, 소리 설계서 §4-1 '장면 렌더'): 후보를 실제 게임 타이밍으로 겹쳐 들어 본다.
  py tools/sfx_scene.py [--out DIR] [--seconds S] [--phone] scene[:tag] [Key=path ...] [scene ...]
    scene = archer | warrior_slime | warrior_goblin | mage_halo | mage_horns
    Key=path 로 그 장면의 소리 파일을 바꾼다(예: SwingArrow=art/sfx/cand/SwingArrow_SwingArcher-3-1.wav).
    주지 않은 키는 BASE(지금 추천 후보 또는 지금 게임 파일)를 쓴다. 결과: <out>/<scene>[_<tag>].wav + .mp3 (+ _phone)
타이밍(게임 코드 그대로): CombatService 휘두름 Plan — 전사 타격 0.23 s(1.0 s마다), 마법사 발사 0.24 s·타격 0.44 s(1.1 s마다),
궁수 발사 0.22 s·타격 0.37 s(0.5 s마다 = 120발/분). 설계서 §4-2 고친 타이밍: 처치 '뽕' = 타격 + 0.04 s, 동전 = 뽕 + 0.05 s,
여러 마리를 한 번에 잡으면 뽕 1번 + 동전 70 ms 물결(최대 4개, 한 칸씩 위로), 콤보 기념 = 동전 + 0.15 s(x10).
궁수: 대상 2 이상이면 화살 한 발 파일을 +0.068 s에 1.10배·0.85 볼륨으로 한 번 더. 같은 재질 3마리 이상 = 1.25 볼륨·0.95 속도.
치명타(HitCrit) = 첫 대상이 치명일 때 재질 타격 위에 얹는 층(Gap 1.5 s). 마법사 소리는 가장 큰 곳이 발사 순간에 오게 앞당김.
크기: 모든 파일을 K가중 -17 LUFS(가장 큰 100 ms)로 맞춘 뒤 설계표(tools/sfx_spec.json) 계획 Volume을 곱한다.
폰판 = 400 Hz 4차 고역 통과(설계서 폰 모델), 같은 마스터 크기라 폰에서 작아지는 만큼 그대로 들린다.
"""

import json
import os
import shutil
import subprocess
import sys

import numpy as np

import sfx_check as SC

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR = 48000
FFMPEG = shutil.which("ffmpeg") or "ffmpeg"
SPEC = json.load(open(os.path.join(ROOT, "tools", "sfx_spec.json"), encoding="utf-8"))
OUT = os.path.join(ROOT, "build", "sfx_scene")
TARGET_LUFS = -17.0

# the files a scene uses unless the command line names others (soon: the picked candidates; today's game files meanwhile)
BASE = {  # batch 1 recommendations (소리 만들기 2026-10-07) + today's game files for keys not remade yet
    "SwingArrow": "art/sfx/cand/SwingArrow_SwingArcher-2-4.wav",
    "SwingWarrior": "art/sfx/SwingWarrior.ogg",
    "SwingMageHalo": "art/sfx/cand/SwingMageHalo_SwingMage-3-4.wav",
    "SwingMageHorns": "art/sfx/cand/SwingMageHorns_1-1.wav",
    "HitSoft": "art/sfx/cand/HitSoft_kB.wav",
    "HitHeavy": "art/sfx/cand/HitHeavy_3-2.wav",
    "HitCrit": "art/sfx/cand/HitCrit_sB3.wav",
    "KillPop": "art/sfx/KillPop.ogg",
    "ComboCoin": "art/sfx/cand/ComboCoin_kA.wav",
    "ComboMilestone": "art/sfx/ComboMilestone.ogg",
}
# speeds (Config.Audio ranges, sound_spec where it set new ones)
SPEED = {"SwingArrow": (0.95, 1.05), "SwingWarrior": (0.92, 1.05), "SwingMageHalo": (1.0, 1.1), "SwingMageHorns": (1.0, 1.1),
         "HitSoft": (0.95, 1.10), "HitHeavy": (0.90, 1.00), "HitCrit": (1.0, 1.0), "KillPop": (0.95, 1.12),
         "ComboCoin": (1.0, 1.0), "ComboMilestone": (1.0, 1.0)}
COMBO = {"Base": 0.8, "Top": 1.6, "Steps": [0, 2, 4, 5, 7, 9, 11, 12]}
CLASS = {  # interval s, launch s (None = melee), contact s, swing key, hit kind
    "archer": (0.5, 0.22, 0.37, "SwingArrow"),
    "warrior": (1.0, None, 0.23, "SwingWarrior"),
    "mage_halo": (1.1, 0.24, 0.44, "SwingMageHalo"),
    "mage_horns": (1.1, 0.24, 0.44, "SwingMageHorns"),
}
SCENES = {  # class, hit key, targets per swing, a kill every N swings, a crit every N swings
    "archer": ("archer", "HitSoft", 2, 3, 5),
    "warrior_slime": ("warrior", "HitSoft", 3, 2, 4),
    "warrior_goblin": ("warrior", "HitHeavy", 3, 3, 4),
    "mage_halo": ("mage_halo", "HitHeavy", 1, 3, 4),
    "mage_horns": ("mage_horns", "HitHeavy", 1, 3, 4),
}


def volume(key):
    v = SPEC["keys"].get(key, {}).get("volume")
    return float(v) if v else {"ComboCoin": 0.29, "KillPop": 0.39}.get(key, 0.35)


_cache = {}


def load(path):
    """mono at SR, K-weighted loudest 100 ms = -17 LUFS (as every file will be)"""
    if path not in _cache:
        x = SC.load(os.path.join(ROOT, path))
        x = x - x.mean()
        x = x * 10 ** ((TARGET_LUFS - SC.lufs_window(SC.k_weight(x), 0.1)) / 20)
        _cache[path] = x
    return _cache[path]


def peak_time(x):
    env, hop = SC.win_ms(x, 10.0, 1.0)
    return int(np.argmax(env)) * hop / SR


def render(scene, files, seconds=20.0, seed=7):
    cls, hit_key, targets, kill_every, crit_every = SCENES[scene]
    interval, launch, contact, swing_key = CLASS[cls]
    rng = np.random.default_rng(seed)
    out = np.zeros(int((seconds + 2) * SR))
    events = []

    def put(key, at, vol_mul=1.0, speed=None):
        path = files.get(key) or ""
        if not path:
            return
        lo, hi = SPEED.get(key, (1.0, 1.0))
        sp = speed if speed is not None else float(rng.uniform(lo, hi))
        x = SC.respeed(load(path), sp) if abs(sp - 1) > 1e-6 else load(path)
        s = int(round(at * SR))
        if s < 0 or s >= len(out):
            return
        n = min(len(x), len(out) - s)
        out[s:s + n] += x[:n] * volume(key) * vol_mul
        events.append({"key": key, "at": round(at, 3), "speed": round(sp, 3), "vol": round(volume(key) * vol_mul, 3)})

    combo, last_crit, t, i = 0, -9.0, 0.3, 0
    while t < seconds:
        i += 1
        # the swing / cast / shot
        if swing_key == "SwingArrow":
            put("SwingArrow", t + launch)
            if targets >= 2:  # the code plays the one-arrow file again (sound_spec §1-1)
                put("SwingArrow", t + launch + 0.068, 0.85, 1.10)
        elif launch is not None:  # mage: the loudest point of the cast lands on the launch
            x = load(files[swing_key])
            put(swing_key, t + max(0.0, launch - peak_time(x)))
        else:
            put(swing_key, t)
        # the hit (one sound per swing), the crit layer, the kill
        hit_t = t + contact
        many = targets >= 3
        put(hit_key, hit_t, 1.25 if many else 1.0, (0.95 if many else None))
        if crit_every and i % crit_every == 0 and hit_t - last_crit >= 1.5:
            put("HitCrit", hit_t)
            last_crit = hit_t
        if kill_every and i % kill_every == 0:
            kills = targets if targets >= 2 else 1
            pop = hit_t + 0.04
            put("KillPop", pop)
            for k in range(min(4, kills)):
                step = COMBO["Steps"][min(combo, len(COMBO["Steps"]) - 1)]
                sp = min(COMBO["Top"], COMBO["Base"] * 2 ** (step / 12))
                put("ComboCoin", pop + 0.05 + 0.07 * k, 1.0, sp)
                combo += 1
                if combo in (10, 25, 50, 100):
                    put("ComboMilestone", pop + 0.05 + 0.07 * k + 0.15)
        t += interval
    return out[:int(seconds * SR) + SR // 2], events


def phone(x):
    from scipy.signal import butter, sosfilt
    return sosfilt(butter(4, 400, "highpass", fs=SR, output="sos"), x)


def write(path, x, gain):
    from scipy.io import wavfile
    y = np.clip(x * gain, -1, 1)
    wavfile.write(path, SR, (y * 32767).astype(np.int16))
    mp3 = path[:-4] + ".mp3"
    subprocess.run([FFMPEG, "-v", "error", "-y", "-i", path, "-codec:a", "libmp3lame", "-b:a", "80k", mp3], check=True)
    return mp3


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    args = sys.argv[1:]
    out_dir, seconds, want_phone = OUT, 20.0, False
    jobs, cur = [], None
    while args:
        a = args.pop(0)
        if a == "--out":
            out_dir = os.path.join(ROOT, args.pop(0))
        elif a == "--seconds":
            seconds = float(args.pop(0))
        elif a == "--phone":
            want_phone = True
        elif "=" in a and cur is not None:
            k, v = a.split("=", 1)
            cur[2][k] = v
        else:
            name, _, tag = a.partition(":")
            cur = (name, tag, {})
            jobs.append(cur)
    os.makedirs(out_dir, exist_ok=True)
    report = {}
    for name, tag, over in jobs:
        files = {**BASE, **over}
        mix, events = render(name, files, seconds)
        pk = np.abs(mix).max()
        # master: the whole scene at about -20 LUFS for listening, peak at most -1 dBFS; the phone file uses the same gain
        gain = 10 ** ((-20.0 - SC.lufs_integrated(SC.k_weight(mix))) / 20)
        gain = min(gain, 10 ** (-1 / 20) / pk) if pk > 0 else 1.0
        stem = os.path.join(out_dir, name + (f"_{tag}" if tag else ""))
        mp3 = write(stem + ".wav", mix, gain)
        item = {"files": {k: v for k, v in files.items() if v}, "events": len(events), "masterGainDb": round(20 * np.log10(gain), 1),
                "lufs": round(SC.lufs_integrated(SC.k_weight(mix * gain)), 1), "mp3": os.path.relpath(mp3, ROOT).replace("\\", "/")}
        if want_phone:
            ph = phone(mix)
            item["phoneMp3"] = os.path.relpath(write(stem + "_phone.wav", ph, gain), ROOT).replace("\\", "/")
            item["phoneLufs"] = round(SC.lufs_integrated(SC.k_weight(ph * gain)), 1)
        report[os.path.basename(stem)] = item
        print(os.path.basename(stem), item["events"], "events", item["lufs"], "LUFS", item.get("phoneLufs", ""))
    path = os.path.join(out_dir, "scenes.json")
    old = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
    old.update(report)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(old, fh, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
