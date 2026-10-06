"""
개발 일지 내레이션: MeloTTS(MIT) 영어 목소리로 줄마다 WAV를 만든다. build/tts/.venv(파이썬 3.10)에서 돈다.

  build/tts/.venv/Scripts/python.exe tools/devlog_tts.py <jobs.json>

jobs.json = [{"id": "0-1", "text": "...", "out": "path.wav", "speaker": "EN-US", "speed": 1.0}, ...]
같은 글·목소리·속도로 이미 만든 파일(<out>.txt 내용이 같음)은 다시 만들지 않는다.
"""

import json
import os
import sys

os.environ.setdefault("HF_HUB_DISABLE_SYMLINKS_WARNING", "1")


def main():
    jobs = json.load(open(sys.argv[1], encoding="utf-8"))
    todo = []
    for j in jobs:
        key = "%s|%s|%s" % (j.get("speaker", "EN-US"), j.get("speed", 1.0), j["text"])
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
        model.tts_to_file(j["text"], ids[j.get("speaker", "EN-US")], j["out"], speed=float(j.get("speed", 1.0)), quiet=True)
        open(stamp, "w", encoding="utf-8").write(key)
        print("tts", j["id"], flush=True)


if __name__ == "__main__":
    main()
