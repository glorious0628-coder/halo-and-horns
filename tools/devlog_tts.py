"""
개발 일지 내레이션: MeloTTS(MIT) 영어 목소리로 줄마다 WAV를 만든다. build/tts/.venv(파이썬 3.10)에서 돈다.

  build/tts/.venv/Scripts/python.exe tools/devlog_tts.py <jobs.json>

jobs.json = [{"id": "0-1", "text": "...", "out": "path.wav", "speaker": "EN-US", "speed": 1.0,
              "noise_scale": 0.6, "noise_scale_w": 0.8, "sdp_ratio": 0.2}, ...]
noise_scale / noise_scale_w / sdp_ratio = MeloTTS 기본값(0.6 / 0.8 / 0.2). 낮추면 발음이 더 고르고 또렷해진다(사용자 2026-10-07:
"발음 더 또렷하게").
같은 글·목소리·속도·설정으로 이미 만든 파일(<out>.txt 내용이 같음)은 다시 만들지 않는다.
"""

import json
import os
import sys

os.environ.setdefault("HF_HUB_DISABLE_SYMLINKS_WARNING", "1")


def key_of(j):
    return "%s|%s|%s|%s|%s|%s" % (j.get("speaker", "EN-US"), j.get("speed", 1.0), j.get("noise_scale", 0.6),
                                  j.get("noise_scale_w", 0.8), j.get("sdp_ratio", 0.2), j["text"])


def main():
    jobs = json.load(open(sys.argv[1], encoding="utf-8"))
    todo = []
    for j in jobs:
        key = key_of(j)
        stamp = j["out"] + ".txt"
        if os.path.exists(j["out"]) and os.path.exists(stamp) and open(stamp, encoding="utf-8").read() == key:
            continue
        todo.append((j, key, stamp))
    if not todo:
        print("tts: all cached")
        return
    from melo.api import TTS
    model = TTS(language="EN", device="cpu")
    ids = model.hps.data.spk2id
    for j, key, stamp in todo:
        os.makedirs(os.path.dirname(j["out"]), exist_ok=True)
        model.tts_to_file(j["text"], ids[j.get("speaker", "EN-US")], j["out"], speed=float(j.get("speed", 1.0)),
                          sdp_ratio=float(j.get("sdp_ratio", 0.2)), noise_scale=float(j.get("noise_scale", 0.6)),
                          noise_scale_w=float(j.get("noise_scale_w", 0.8)), quiet=True)
        open(stamp, "w", encoding="utf-8").write(key)
        print("tts", j["id"], flush=True)


if __name__ == "__main__":
    main()
