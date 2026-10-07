"""
글자 타자 효과(UIKit.Typewriter, 품질 ②) 확인: 연습 Studio(UiSandbox) Play의 클라이언트에서 UIKit 사본으로
  1. 한 줄이 1초에 약 38글자씩 나오는지(MaxVisibleGraphemes를 0.25초마다 잰다)
  2. Finish(탭)면 바로 전부 보이는지(-1), 짧은 줄은 저절로 끝나고 OnDone이 불리는지
  3. 같은 칸에 새 줄을 쓰면 앞 줄이 취소되는지
를 잰다(소리는 C.Audio.Talk 몫이라 사본에선 안 남: 효과음 id 올린 뒤 확인). 결과:
docs/art/verification_2026-10-07/typewriter_2026-10-07.json

  py tools/typewriter_view.py
STUDIO_NAME은 UiSandbox로 고정(dv.sandbox가 먼저 확인). 끝나면(오류가 나도) Play를 멈추고 기기 흉내를 끈다.
"""

import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ["STUDIO_NAME"] = "UiSandbox"  # practice Studio only: forced before studio_mcp is imported (via device_view)
import device_view as dv  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPORT = os.path.join(ROOT, "docs", "art", "verification_2026-10-07", "typewriter_2026-10-07.json")
LINE = "Hallie here! Now you know my name. Welcome to the Knights!"

CHECK = r'''
local HttpService = game:GetService("HttpService")
local lp = game.Players.LocalPlayer
local UIKit = require(lp:WaitForChild("PlayerScripts"):WaitForChild("UIKit"))
local sg = Instance.new("ScreenGui")
sg.Name, sg.ResetOnSpawn = "TWProbe", false
sg.Parent = lp:FindFirstChildOfClass("PlayerGui")
local lab = Instance.new("TextLabel")
lab.Size, lab.Position, lab.TextWrapped, lab.TextSize = UDim2.fromOffset(520, 80), UDim2.fromOffset(80, 260), true, 24
lab.Parent = sg
local out = { Speed = UIKit.TypeSpeed.Default, Total = utf8.len("%s") }
local h = UIKit.Typewriter(lab, "%s", { Speaker = "Halo" })
out.Start = lab.MaxVisibleGraphemes
out.Samples = {}
for _ = 1, 4 do -- 1 s: the 58-letter line takes about 1.5 s at 38 letters/s, Finish comes while it types
	task.wait(0.25)
	table.insert(out.Samples, lab.MaxVisibleGraphemes)
end
out.DoneBeforeFinish = h.Done()
h.Finish()
out.AfterFinish = lab.MaxVisibleGraphemes
out.StateAfterFinish = h.State
local called = false
local h2 = UIKit.Typewriter(lab, "Short line.", { OnDone = function() called = true end })
task.wait(1)
out.ShortDone, out.ShortOnDone, out.ShortShown = h2.Done(), called, lab.MaxVisibleGraphemes
local h3 = UIKit.Typewriter(lab, "Line A is long enough to keep typing for a while.", {})
task.wait(0.2)
local h4 = UIKit.Typewriter(lab, "Line B.", {})
out.OldCancelled, out.OldState = h3.Done(), h3.State
task.wait(0.6)
out.NewDone, out.NewText, out.NewShown = h4.Done(), lab.Text, lab.MaxVisibleGraphemes
sg:Destroy()
return HttpService:JSONEncode(out)
'''


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    with dv.sandbox() as c:
        dv.stop_play(c)
        print("device:", dv.luau(c, dv.SET_DEVICE % dv.DEVICES["pc"], "Edit").strip())
        c.call("start_stop_play", {"is_start": True})
        for _ in range(60):
            time.sleep(0.5)
            if "Client" in dv.state(c):
                break
        time.sleep(5)
        raw = dv.luau(c, CHECK % (LINE, LINE), "Client").strip()
    r = json.loads(raw)
    s = [r["Total"] if v == -1 else v for v in r["Samples"]]  # -1 = all shown
    rate = (s[-1] - s[0]) / (0.25 * (len(s) - 1)) if len(s) > 1 else 0
    checks = {
        "starts hidden": r["Start"] == 0,
        "grows every sample": all(b >= a for a, b in zip(s, s[1:])) and s[-1] > s[0],
        "about the set speed (+-25%)": abs(rate - r["Speed"]) <= r["Speed"] * 0.25,
        "not done before Finish": r["DoneBeforeFinish"] is False,
        "Finish shows all": r["AfterFinish"] == -1 and r["StateAfterFinish"] == "done",
        "short line ends by itself + OnDone": r["ShortDone"] is True and r["ShortOnDone"] is True and r["ShortShown"] == -1,
        "a new line cancels the old": r["OldCancelled"] is True and r["OldState"] == "cancelled",
        "the new line finishes": r["NewDone"] is True and r["NewText"] == "Line B." and r["NewShown"] == -1,
    }
    report = {"tool": "tools/typewriter_view.py", "line": LINE, "measuredLettersPerSecond": round(rate, 1),
              "result": r, "checks": checks, "passed": sum(checks.values()), "total": len(checks)}
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    with open(REPORT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    for k, v in checks.items():
        print("OK  " if v else "FAIL", k)
    print("rate", round(rate, 1), "samples", s, "report:", REPORT, report["passed"], "/", report["total"])


if __name__ == "__main__":
    main()
