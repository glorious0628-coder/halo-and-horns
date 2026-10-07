"""
새 효과음이 Studio에서 실제로 불러와지는지 재기 (소리 만들기, 2026-10-07). 개발 1이 연결한 뒤, 옛 id·ogg를 지우기 전에 쓴다.
  py tools/sfx_loadcheck.py [--dm Edit|Client] [--print]
art/sfx/asset_ids.json "ids"(+ "kept")의 id마다 SoundService 아래 임시 Sound를 만들어 IsLoaded·TimeLength를 재고(최대 15 s) 바로 지운다.
결과를 picks_r4.json 길이(durMs)와 견준다: 못 불러옴(권한·잘못된 id) / 길이 차이 50 ms 넘음 = 문제.
메인 Studio를 쓰므로 실행 전에 검수의 '전달함, 시작'을 받는다(AGENTS 화면·Studio 규칙). --print는 Luau만 출력하고 실행하지 않는다.
"""

import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LUAU = r'''
local SoundService = game:GetService("SoundService")
local ids = { %s }
local folder = Instance.new("Folder")
folder.Name = "HH_SfxLoadCheck"
folder.Parent = SoundService
local sounds = {}
for k, id in ids do
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = 0
	s.Parent = folder
	sounds[k] = s
end
local t0 = os.clock()
while os.clock() - t0 < 15 do
	local all = true
	for _, s in sounds do
		if not s.IsLoaded then all = false break end
	end
	if all then break end
	task.wait(0.25)
end
local out = {}
for k, s in sounds do
	table.insert(out, string.format("%%s|%%s|%%.3f", k, tostring(s.IsLoaded), s.TimeLength))
end
folder:Destroy()
table.sort(out)
return table.concat(out, "\n")
'''


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    dm = sys.argv[sys.argv.index("--dm") + 1] if "--dm" in sys.argv else "Edit"
    doc = json.load(open(os.path.join(ROOT, "art", "sfx", "asset_ids.json"), encoding="utf-8"))
    ids = dict(doc.get("ids", {}))
    ids.update((doc.get("kept") or {}).get("ids", {}))
    picks = json.load(open(os.path.join(ROOT, "art", "sfx", "picks_r4.json"), encoding="utf-8"))["picks"]
    code = LUAU % ", ".join(f'{k} = "{v}"' for k, v in sorted(ids.items()))
    if "--print" in sys.argv:
        print(code)
        return
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as fh:
        json.dump({"code": code, "datamodel_type": dm}, fh)
        args = fh.name
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "studio_mcp.py"), "call", "execute_luau", "@" + args],
                       capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=180)
    os.remove(args)
    text = r.stdout + r.stderr
    rows = {}
    for line in text.replace("\\n", "\n").splitlines():
        parts = line.strip().strip('"').split("|")
        if len(parts) == 3 and parts[0] in ids:
            rows[parts[0]] = (parts[1] == "true", float(parts[2]))
    if not rows:
        print("Studio 답을 못 읽음:\n" + text[-1500:])
        sys.exit(1)
    bad = 0
    for k in sorted(ids):
        loaded, length = rows.get(k, (False, 0.0))
        want = (picks.get(k, {}).get("durMs") or 0) / 1000
        note = ""
        if not loaded:
            note = "못 불러옴"
        elif want and abs(length - want) > 0.05:
            note = f"길이 {length:.3f}s (파일 {want:.3f}s)"
        if note:
            bad += 1
        print(f"{'!!' if note else 'ok'} {k:15s} {length:6.3f}s {note}")
    print(f"{len(rows)}개 중 문제 {bad}개")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
