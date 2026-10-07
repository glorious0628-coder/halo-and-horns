"""
Firefly 효과음 원본 받기 (소리 만들기, 2026-10-07).
  py tools/sfx_fetch.py <batch.tsv>
batch.tsv 한 줄 = 'asset [<프롬프트 키>] <Adobe 애셋 urn> <downloadUrl>'(키를 빼면 sha256으로 정함) 또는 'hash <프롬프트 키> <변형 번호> <sha256 앞 24글자>'.
  - asset 줄: Adobe 연결 도구 asset_search(GenAIAsset, firefly-generation-audio) -> asset_get_presigned_urls(acp)의 downloadUrl
  - hash 줄: Firefly 화면의 변형 1-4 blob을 브라우저 안에서 crypto.subtle.digest('SHA-256')로 잰 값
받은 WAV를 build/sfx_firefly/raw/<키>-<변형>.wav로 두고 build/sfx_firefly/raw_assets.json에 애셋 id를 더한다.
내려받기는 사용자 OK(2026-10-07, "이번 세션 계속 받아")가 있을 때만 쓴다.
"""

import hashlib
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(ROOT, "build", "sfx_firefly")
RAW = os.path.join(WORK, "raw")
ASSETS = os.path.join(WORK, "raw_assets.json")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    rows = [ln.split() for ln in open(sys.argv[1], encoding="utf-8") if ln.strip() and not ln.startswith("#")]
    hashes = {r[3]: (r[1], int(r[2])) for r in rows if r[0] == "hash"}
    book = json.load(open(ASSETS, encoding="utf-8")) if os.path.exists(ASSETS) else {}
    os.makedirs(RAW, exist_ok=True)
    done, miss = 0, []
    for r in (r for r in rows if r[0] == "asset"):
        key, urn, url = (r[1], r[2], r[3]) if len(r) == 4 else (None, r[1], r[2])  # 'asset <urn> <url>': the hash names it
        tmp = os.path.join(RAW, f"_fetch_{urn.rsplit(':', 1)[1][:8]}.wav")
        subprocess.run(["curl", "-sL", "-m", "60", "-o", tmp, url], check=True)
        data = open(tmp, "rb").read()
        h = hashlib.sha256(data).hexdigest()[:24]
        if data[:4] != b"RIFF" or h not in hashes or (key and hashes[h][0] != key):
            miss.append((key, urn, h))
            os.remove(tmp)
            continue
        name = f"{hashes[h][0]}-{hashes[h][1]}.wav"
        os.replace(tmp, os.path.join(RAW, name))
        book[name] = {"assetId": urn, "sha256_24": h}
        done += 1
    with open(ASSETS, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(dict(sorted(book.items())), fh, indent=1)
    print("fetched", done, "missing", miss)


if __name__ == "__main__":
    main()
