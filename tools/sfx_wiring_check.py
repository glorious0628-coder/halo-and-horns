"""
효과음 연결 대조 (소리 만들기, 2026-10-07): Config.Audio(Files·Sounds)가 art/sfx/asset_ids.json의 새 id와 맞는지 본다. 읽기만 한다.
  py tools/sfx_wiring_check.py [--ref origin/main]   (--ref 없으면 작업 폴더의 src를 읽음)
나오는 것: 맞음 / 옛 id 그대로 / 빈 id / Files에 없음(이벤트 연결 필요) / Sounds 볼륨 차이(설계표) / 이제 아무 데도 안 쓰는 옛 id(지워도 되는 후보 —
개발 1 연결 + Play 확인 뒤에만 지움).
"""

import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG = "src/ReplicatedStorage/Shared/Config.luau"


def read_src(path, ref):
    if ref:
        return subprocess.run(["git", "show", f"{ref}:{path}"], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                              check=True).stdout
    return open(os.path.join(ROOT, path), encoding="utf-8").read()


def block(text, start_pat):
    """the text of the first { ... } table that follows start_pat (brace matching)"""
    m = re.search(start_pat, text)
    if not m:
        return ""
    i = text.index("{", m.end() - 1)
    depth = 0
    for j in range(i, len(text)):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                return text[i:j + 1]
    return ""


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ref = sys.argv[sys.argv.index("--ref") + 1] if "--ref" in sys.argv else None
    cfg = read_src(CONFIG, ref)
    audio = block(cfg, r"Config\.Audio\s*=\s*\{")
    files_txt = block(audio, r"\n\tFiles\s*=\s*\{")
    sounds_txt = block(audio, r"\n\tSounds\s*=\s*\{")
    files = dict(re.findall(r'(\w+)\s*=\s*"(rbxassetid://\d*|)"', files_txt))
    sounds = {}
    for name, body in re.findall(r"\n\t\t(\w+)\s*=\s*(\{[^\n]*\})", sounds_txt):
        f = re.search(r'File\s*=\s*"(\w+)"', body)
        fs = re.search(r"Files\s*=\s*\{([^}]*)\}", body)
        vol = re.search(r"Volume\s*=\s*([\d.]+)", body)
        sounds[name] = {"files": re.findall(r'"(\w+)"', fs.group(1)) if fs else ([f.group(1)] if f else []),
                        "volume": float(vol.group(1)) if vol else None}

    ids_doc = json.load(open(os.path.join(ROOT, "art", "sfx", "asset_ids.json"), encoding="utf-8"))
    new = ids_doc.get("ids", {})
    old = (ids_doc.get("old") or {}).get("ids", {})
    old_set = {v: k for k, v in old.items()}
    picks = json.load(open(os.path.join(ROOT, "art", "sfx", "picks_r4.json"), encoding="utf-8"))["picks"]

    ok, stale, empty, missing = [], [], [], []
    for k in picks:
        want = new.get(k)
        have = files.get(k)
        if want is None:
            missing.append((k, "아직 업로드 안 됨"))
        elif have is None:
            missing.append((k, "Files에 키 없음 → 이벤트 연결 필요"))
        elif have == want:
            ok.append(k)
        elif have == "":
            empty.append((k, want))
        else:
            stale.append((k, have, want, old_set.get(have, "?")))

    print(f"[{ref or '작업 폴더'}] Config.Audio.Files {len(files)}개 · 새 소리 {len(picks)}개")
    print(f"  맞음 {len(ok)}: {', '.join(ok)}")
    for k, have, want, was in stale:
        print(f"  옛 id 그대로  {k}: {have} (옛 {was}) → {want}")
    for k, want in empty:
        print(f"  빈 id         {k}: \"\" → {want}")
    for k, why in missing:
        print(f"  없음          {k}: {why}" + (f" ({new[k]})" if k in new else ""))

    # Sounds that point at a file whose id is old / empty, and volume vs the spec
    print("  Sounds 확인:")
    for name, s in sorted(sounds.items()):
        notes = []
        for f in s["files"]:
            fid = files.get(f)
            if fid is None:
                notes.append(f"File '{f}'가 Files에 없음")
            elif fid == "":
                notes.append(f"'{f}' 빈 id(무음)")
            elif fid in old_set and f in new:
                notes.append(f"'{f}' 옛 id")
        pv = picks.get(name, {}).get("volume")
        if pv is not None and s["volume"] is not None and abs(pv - s["volume"]) > 0.051:
            notes.append(f"볼륨 {s['volume']} (설계표 {pv})")
        if notes:
            print(f"    {name}: " + "; ".join(notes))

    # old ids nobody uses any more (candidates to retire after the Play check)
    src_all = []
    for dp, _, fns in os.walk(os.path.join(ROOT, "src")):
        for fn in fns:
            if fn.endswith(".luau"):
                rel = os.path.relpath(os.path.join(dp, fn), ROOT).replace("\\", "/")
                try:
                    src_all.append(read_src(rel, ref))
                except subprocess.CalledProcessError:
                    pass
    blob = "\n".join(src_all)
    unused = [k for k, v in old.items() if v.split("//")[-1] not in blob]
    used = [k for k, v in old.items() if v.split("//")[-1] in blob]
    print(f"  옛 id 아직 쓰는 것 {len(used)}: {', '.join(used)}")
    print(f"  옛 id 이제 안 쓰는 것 {len(unused)} (Play 확인 뒤 정리 후보): {', '.join(unused)}")


if __name__ == "__main__":
    main()
