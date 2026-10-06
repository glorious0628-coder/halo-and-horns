"""
개발 일지 촬영 도우미 (촬영 편집 세션, A23-42). 녹화 연습 장소 FilmSet Studio만 쓴다.

  py tools/devlog_film.py state                         -> FilmSet Play 상태와 플레이어 속성 몇 개
  py tools/devlog_film.py lua <Server|Client|Edit> <code|@file>
  py tools/devlog_film.py debug <Key> <Value>           -> ServerScriptService.DebugCommand (Studio 테스트 도구)
  py tools/devlog_film.py grab <out.png>                -> FilmSet 창에서 게임 화면(뷰포트)만 한 장
  py tools/devlog_film.py rec <name> <seconds>          -> FilmSet 창 뷰포트만 녹화 → build/devlog/raw/<name>.mp4
  py tools/devlog_film.py minimize                      -> 다 찍은 뒤 FilmSet 창을 다시 최소화(활성화 없음)

규칙(AGENTS Hard rule 6 촬영 예외, SPEC A23-42):
- 대상은 이름에 FilmSet이 들어간 Studio 창 하나뿐이다(STUDIO_NAME=FilmSet 고정). 메인 Studio·UiSandbox·WorldKit은 건드리지 않는다.
- ffmpeg gfxcapture(Windows 창 캡처)로 그 창의 픽셀만 잡는다: 다른 창이 위에 있어도 그 창 내용은 찍히지 않고, 커서도 안 그린다.
  뷰포트만 잘라 저장한다(오른쪽 위 계정 그림·창 제목·탐색기는 영상에 들어가지 않는다). 한 번에 60초 이하.
- 창이 최소화돼 있으면 활성화하지 않고 맨 뒤에 펼친다(사용자 화면을 가리지 않음). 다 찍으면 `minimize`로 다시 접는다.
- 마우스·키보드는 건드리지 않는다. 캐릭터는 우리 테스트 Play 안에서 Studio MCP로만 움직인다. 끝나면 Play를 멈춘다.
- 원본은 build/devlog/raw/(git 밖).
- 창을 펼치거나 녹화하기 전에 검수에게 "촬영 편집 — 무엇 — 몇 초"를 보내고 검수의 "전달함, 시작" 답을 받은 뒤에만 한다, 끝나면 "끝"(2026-10-06 사용자 규칙). 그 답 뒤에만 FILM_OK=1.
"""

import base64
import json
import os
import subprocess
import sys
import time

os.environ["STUDIO_NAME"] = "FilmSet"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from studio_mcp import Client  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "build", "devlog", "raw")
TITLE = os.path.join(ROOT, "build", "FilmSet.rbxlx") + " - Roblox Studio"
MAX_SECONDS = 60
PAD = (188, 190, 200)  # Studio's gray around the emulated 16:9 viewport


def ffmpeg_exe():
    base = os.path.join(os.environ["LOCALAPPDATA"], "Microsoft", "WinGet", "Packages")
    for d in os.listdir(base):
        if d.startswith("Gyan.FFmpeg"):
            for root, _, files in os.walk(os.path.join(base, d)):
                if "ffmpeg.exe" in files:
                    return os.path.join(root, "ffmpeg.exe")
    return "ffmpeg"


FFMPEG = ffmpeg_exe()


def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))


class Film:
    def __init__(self):
        self.c = Client()
        self.c.start()

    def close(self):
        self.c.close()

    def call(self, tool, args):
        res = self.c.call(tool, args)
        if res.get("isError"):
            raise RuntimeError(text_of(res))
        return text_of(res)

    def lua(self, code, dm="Server"):
        return self.call("execute_luau", {"code": code, "datamodel_type": dm})

    def debug(self, key, value):
        return self.lua("local p=game:GetService('Players'):GetPlayers()[1];"
                        "return game.ServerScriptService.DebugCommand:Invoke(p.Name,%s,%s)"
                        % (json.dumps(key), json.dumps(value)))

    def state(self):
        return self.call("get_studio_state", {})

    # --- client camera / HUD helpers (our own test Play only) ---
    def hud(self, on):
        """game HUD + Roblox top bar on/off (clean world shots)"""
        return self.lua("local pg=game.Players.LocalPlayer.PlayerGui; for _,g in pg:GetChildren() do "
                        "if g:IsA('ScreenGui') and g.Name~='Freecam' then g.Enabled=%s end end; "
                        "pcall(function() game:GetService('StarterGui'):SetCore('TopbarEnabled', %s) end); return 'hud %s'"
                        % (str(on).lower(), str(on).lower(), on), "Client")

    def orbit(self, center, r, h, a0, a1, dur, look_y=0.0, target=None, front=False):
        """Scriptable camera orbit (degrees a0 -> a1, eased) around a point, or around `target` (Lua expression for an
        instance, or 'char' = my character) each frame; front=True: the angles count from the target's facing
        (0 = straight in front of it). Restores the Custom camera when it ends"""
        tgt = "nil"
        if target == "char":
            tgt = "function() local c=game.Players.LocalPlayer.Character; local h=c and c:FindFirstChild('HumanoidRootPart'); return h and h.Position end"
        elif target:
            tgt = ("function() local o=%s; if not o then return nil end; local cf=o:IsA('Model') and o:GetPivot() or o.CFrame; "
                   "return cf.Position, cf.LookVector end" % target)
        code = """
local RS=game:GetService('RunService'); local cam=workspace.CurrentCamera
local center=Vector3.new(%f,%f,%f); local r,h,dur=%f,%f,%f; local a0,a1=math.rad(%f),math.rad(%f); local lookY=%f
local tgt=%s
local front=%s
_G.__filmTok=(_G.__filmTok or 0)+1; local tok=_G.__filmTok
cam.CameraType=Enum.CameraType.Scriptable
local t0=os.clock(); local name='HHC_Film'..tok
local function stop() pcall(RS.UnbindFromRenderStep, RS, name) end
RS:BindToRenderStep(name, Enum.RenderPriority.Last.Value, function()
  if _G.__filmTok~=tok then stop(); return end
  if cam.CameraType~=Enum.CameraType.Scriptable then cam.CameraType=Enum.CameraType.Scriptable end
  local t=math.clamp((os.clock()-t0)/dur,0,1); local e=t*t*(3-2*t)
  local a=a0+(a1-a0)*e
  local c=center; local base=0
  if tgt then local ok,p,lv=pcall(tgt); if ok and p then c=p; if front and lv then base=math.atan2(lv.Z,lv.X) end end end
  a=a+base
  cam.CFrame=CFrame.lookAt(c+Vector3.new(math.cos(a)*r,h,math.sin(a)*r), c+Vector3.new(0,lookY,0))
  if t>=1 then stop(); task.delay(0.3,function() if _G.__filmTok==tok then cam.CameraType=Enum.CameraType.Custom end end) end
end)
return 'orbit'
""" % (center[0], center[1], center[2], r, h, dur, a0, a1, look_y, tgt, "true" if front else "false")
        return self.lua(code, "Client")

    def dolly(self, p0, p1, l0, l1, dur):
        """Scriptable camera move from p0 to p1 while looking from l0 to l1 (eased); restores Custom at the end"""
        code = """
local RS=game:GetService('RunService'); local cam=workspace.CurrentCamera
local p0,p1=Vector3.new(%f,%f,%f),Vector3.new(%f,%f,%f); local l0,l1=Vector3.new(%f,%f,%f),Vector3.new(%f,%f,%f); local dur=%f
_G.__filmTok=(_G.__filmTok or 0)+1; local tok=_G.__filmTok
cam.CameraType=Enum.CameraType.Scriptable
local t0=os.clock(); local name='HHC_Film'..tok
local function stop() pcall(RS.UnbindFromRenderStep, RS, name) end
RS:BindToRenderStep(name, Enum.RenderPriority.Last.Value, function()
  if _G.__filmTok~=tok then stop(); return end
  if cam.CameraType~=Enum.CameraType.Scriptable then cam.CameraType=Enum.CameraType.Scriptable end
  local t=math.clamp((os.clock()-t0)/dur,0,1); local e=t*t*(3-2*t)
  cam.CFrame=CFrame.lookAt(p0:Lerp(p1,e), l0:Lerp(l1,e))
  if t>=1 then stop(); task.delay(0.3,function() if _G.__filmTok==tok then cam.CameraType=Enum.CameraType.Custom end end) end
end)
return 'dolly'
""" % (*p0, *p1, *l0, *l1, dur)
        return self.lua(code, "Client")

    def hide_korean(self):
        """test-Play only, client side: make every text that contains Hangul invisible (HUD, name tags, popups, signs)
        and hide the chat window, so English videos show no Korean (user 2026-10-06). The game code is not changed."""
        code = r"""
if _G.__filmHideKo then return 'already' end
_G.__filmHideKo = true
local function hasHangul(s)
	local ok, res = pcall(function()
		for _, c in utf8.codes(s) do
			if (c >= 0xAC00 and c <= 0xD7A3) or (c >= 0x3130 and c <= 0x318F) or (c >= 0x1100 and c <= 0x11FF) then return true end
		end
		return false
	end)
	return ok and res
end
local function fix(o)
	if o:IsA('TextLabel') or o:IsA('TextButton') or o:IsA('TextBox') then
		if hasHangul(o.Text) then
			o.TextTransparency = 1
			o.TextStrokeTransparency = 1
		end
	end
end
local function watch(o)
	if o:IsA('TextLabel') or o:IsA('TextButton') or o:IsA('TextBox') then
		fix(o)
		o:GetPropertyChangedSignal('Text'):Connect(function() fix(o) end)
		o:GetPropertyChangedSignal('TextTransparency'):Connect(function() if hasHangul(o.Text) and o.TextTransparency < 1 then o.TextTransparency = 1 end end)
	end
end
local roots = { game.Players.LocalPlayer:WaitForChild('PlayerGui'), workspace }
for _, r in roots do
	for _, d in r:GetDescendants() do watch(d) end
	r.DescendantAdded:Connect(watch)
end
pcall(function()
	local tcs = game:GetService('TextChatService')
	tcs.ChatWindowConfiguration.Enabled = false
	tcs.ChatInputBarConfiguration.Enabled = false
end)
pcall(function() game:GetService('StarterGui'):SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false) end)
return 'korean hidden'
"""
        return self.lua(code, "Client")

    def cam_reset(self):
        return self.lua("_G.__filmTok=(_G.__filmTok or 0)+1; workspace.CurrentCamera.CameraType=Enum.CameraType.Custom; return 'cam reset'", "Client")

    def walk(self, points, speed=None):
        """client Humanoid:MoveTo through waypoints (runs in the background, returns at once)"""
        pts = ",".join("Vector3.new(%f,%f,%f)" % tuple(p) for p in points)
        sp = "hum.WalkSpeed=%f;" % speed if speed else ""
        code = ("local c=game.Players.LocalPlayer.Character; local hum=c and c:FindFirstChildOfClass('Humanoid'); if not hum then return 'nohum' end; %s"
                "task.spawn(function() for _,p in {%s} do hum:MoveTo(p); hum.MoveToFinished:Wait() end end); return 'walk'" % (sp, pts))
        return self.lua(code, "Client")

    def teleport(self, pos, look=None):
        look = look or (pos[0], pos[1], pos[2] - 1)
        return self.lua("local p=game.Players:GetPlayers()[1]; local h=p.Character and p.Character:FindFirstChild('HumanoidRootPart'); "
                        "if not h then return 'nochar' end; h.CFrame=CFrame.lookAt(Vector3.new(%f,%f,%f),Vector3.new(%f,%f,%f)); return 'tp'"
                        % (*pos, *look), "Server")


def film_hwnd():
    """the FilmSet Studio window (exact title); restored behind other windows if minimized, never activated"""
    import ctypes
    u = ctypes.windll.user32
    h = u.FindWindowW(None, TITLE)
    if not h:
        raise RuntimeError("FilmSet Studio 창을 찾지 못했습니다: " + TITLE)
    if u.IsIconic(h):
        # 2026-10-06 rule: restoring the window or recording needs 검수's OK first ("촬영 편집 — 무엇 — 몇 초")
        if os.environ.get("FILM_OK") != "1":
            raise RuntimeError("FilmSet 창이 최소화돼 있어요. 검수에게 \"촬영 편집 — 무엇 — 몇 초\"를 보내고 \"전달함, 시작\" 답을 받은 뒤 FILM_OK=1 로 다시 실행하세요.")
        u.ShowWindow(h, 4)  # SW_SHOWNOACTIVATE
        u.SetWindowPos(h, 1, 0, 0, 0, 0, 0x0013)  # HWND_BOTTOM, NOSIZE | NOMOVE | NOACTIVATE
        time.sleep(1.0)
    return h


def minimize_film():
    import ctypes
    h = ctypes.windll.user32.FindWindowW(None, TITLE)
    if h:
        ctypes.windll.user32.ShowWindow(h, 7)  # SW_SHOWMINNOACTIVE


def gfx_src(hwnd):
    # Windows Graphics Capture: only this window's own pixels (other windows on top are never recorded), no cursor
    return "gfxcapture=hwnd=%d:capture_cursor=0:max_framerate=30,hwdownload,format=bgra" % hwnd


def grab_window(out_png):
    subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "error", "-y", "-filter_complex", gfx_src(film_hwnd()),
                    "-frames:v", "1", out_png], check=True)


def viewport_rect(png):
    """the emulated viewport inside the Studio window = the block surrounded by Studio's gray pad"""
    from PIL import Image
    im = Image.open(png).convert("RGB")
    W, H = im.size
    px = im.load()

    def is_pad(p):
        return max(abs(a - b) for a, b in zip(p, PAD)) <= 6

    y = H // 2
    xs = [x for x in range(W // 5, W - 30) if not is_pad(px[x, y])]
    # the viewport run is the longest non-pad run on the middle row right of the side panels
    runs, start = [], None
    for x in range(W // 5, W - 30):
        if not is_pad(px[x, y]):
            start = x if start is None else start
        elif start is not None:
            runs.append((start, x - 1)); start = None
    if start is not None:
        runs.append((start, W - 31))
    x0, x1 = max(runs, key=lambda r: r[1] - r[0])
    xm = (x0 + x1) // 2
    ys = []
    start = None
    for yy in range(0, H):
        if not is_pad(px[xm, yy]):
            start = yy if start is None else start
        elif start is not None:
            ys.append((start, yy - 1)); start = None
    if start is not None:
        ys.append((start, H - 1))
    y0, y1 = max(ys, key=lambda r: r[1] - r[0])
    w, h = (x1 - x0 + 1) // 2 * 2, (y1 - y0 + 1) // 2 * 2
    return x0, y0, w, h


def crop_now():
    os.makedirs(RAW, exist_ok=True)
    probe = os.path.join(RAW, "_probe.png")
    grab_window(probe)
    return viewport_rect(probe)


def grab_viewport(out_png):
    from PIL import Image
    x, y, w, h = crop_now()
    Image.open(os.path.join(RAW, "_probe.png")).crop((x, y, x + w, y + h)).save(out_png)
    return out_png


def start_rec(name, seconds):
    if os.environ.get("FILM_OK") != "1":
        raise RuntimeError("녹화 전에 검수에게 \"촬영 편집 — 무엇 — 몇 초\"를 보내고 \"전달함, 시작\" 답을 받은 뒤 FILM_OK=1 로 실행하세요(끝나면 \"끝\").")
    seconds = min(float(seconds), MAX_SECONDS)
    x, y, w, h = crop_now()
    out = os.path.join(RAW, name + ".mp4")
    cmd = [FFMPEG, "-hide_banner", "-loglevel", "error", "-y", "-filter_complex",
           gfx_src(film_hwnd()) + ",crop=%d:%d:%d:%d,fps=30,format=yuv420p" % (w, h, x, y),
           "-t", str(seconds), "-c:v", "libx264", "-preset", "veryfast", "-crf", "16", out]
    return subprocess.Popen(cmd), out


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    cmd = sys.argv[1]
    if cmd == "grab":
        print(grab_viewport(os.path.abspath(sys.argv[2])))
        return
    if cmd == "minimize":
        minimize_film()
        return
    if cmd == "rec":
        p, out = start_rec(sys.argv[2], sys.argv[3])
        p.wait()
        print(out)
        return
    f = Film()
    try:
        if cmd == "state":
            print(f.state())
        elif cmd == "lua":
            code = sys.argv[3]
            if code.startswith("@"):
                with open(code[1:], encoding="utf-8") as fh:
                    code = fh.read()
            print(f.lua(code, sys.argv[2]))
        elif cmd == "debug":
            v = sys.argv[3]
            try:
                v = json.loads(v)
            except ValueError:
                pass
            print(f.debug(sys.argv[2], v))
        else:
            sys.exit(__doc__)
    finally:
        f.close()


if __name__ == "__main__":
    main()
