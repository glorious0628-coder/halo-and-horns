"""
Roblox Studio MCP(StudioMCP.exe)와 직접 대화하는 작은 클라이언트.

  py tools/studio_mcp.py list                       -> 사용 가능한 도구 목록
  py tools/studio_mcp.py call <tool> '<json args>'  -> 도구 호출
  py tools/studio_mcp.py call <tool> @args.json     -> 인자를 파일에서 읽기

studio_id 를 생략하면 이름에 STUDIO_NAME이 들어간 스튜디오 창(또는 STUDIO_ID로 고정한 창)을 고른다.

안전 규칙 (검수 2026-10-10, 메인 Play 중 진영·직업이 저절로 골라진 사고):
  * STUDIO_NAME과 STUDIO_ID가 둘 다 없으면 오류다 (예전 기본값 "GoodEvil"은 없앴다). 연습 Studio는 STUDIO_NAME=UiSandbox 처럼 꼭 정한다.
  * 메인 Studio(창 이름에 GoodEvil 또는 81671223175574)는 환경변수 HH_MAIN_STUDIO=1 이 있을 때만 고른다 (메인 반영 1 전용).
    HH_MAIN_STUDIO=1 만 있고 이름이 없으면 메인을 고른다:  HH_MAIN_STUDIO=1 py tools/sync_to_studio.py
  * 이 규칙은 이 파일의 Client.studio_id()에 있어서 sync_to_studio.py · playtest.py · luau_check.py 처럼 Client를 쓰는 도구는 모두 따른다.
"""

import json
import os
import subprocess
import sys
import threading
import queue

MCP_BAT = os.path.join(os.environ["LOCALAPPDATA"], "Roblox", "mcp.bat")
TIMEOUT = float(os.environ.get("STUDIO_MCP_TIMEOUT", "120"))

# the main Studio: the GoodEvil local file, or the published private experience (Darugi_S2 private place 81671223175574, 2026-10-06).
# 2026-10-12: the user published the open main Studio as a new place in the same experience ("Darugi_S2의 장소: 10122026_1",
# PlaceId 79345022650204, user: "무시해도 돼") - the same game, so it counts as the main Studio too.
MAIN_NAMES = ("GoodEvil", "81671223175574", "79345022650204", "10122026_1")


def is_main_name(name):
    return any(m.lower() in (name or "").lower() for m in MAIN_NAMES)


def pick_studio(studios, name, pin, allow_main):
    """One Studio window of list_roblox_studios, or None while it has not connected yet (the caller asks again).
    name = STUDIO_NAME ("a|b" = any of them), pin = STUDIO_ID (an id or its prefix), allow_main = HH_MAIN_STUDIO == "1".
    Raises RuntimeError for: nothing chosen (no name, no id, no HH_MAIN_STUDIO), two windows matching one name, and
    a main-Studio window without HH_MAIN_STUDIO=1."""
    name, pin = (name or "").strip(), (pin or "").strip()
    if not name and not pin:
        if not allow_main:
            raise RuntimeError("STUDIO_NAME을 정하세요 (연습 Studio는 STUDIO_NAME=UiSandbox 처럼, 메인 Studio는 HH_MAIN_STUDIO=1 — 메인 반영 1 전용)")
        name = "|".join(MAIN_NAMES)
    chosen = None
    if pin:
        chosen = next((s for s in studios if (s.get("id") or "").startswith(pin)), None)
    else:
        hits = [s for s in studios if any(w.lower() in (s.get("name") or "").lower() for w in name.split("|") if w.strip())]
        if len(hits) > 1:
            raise RuntimeError("같은 장소 Studio 창이 여러 개예요: "
                               + ", ".join(f"{s['id'][:8]} {s.get('name')}" for s in hits)
                               + " — STUDIO_ID=<id 앞자리>로 하나를 고르세요")
        chosen = hits[0] if hits else None
    if chosen is not None and is_main_name(chosen.get("name")) and not allow_main:
        raise RuntimeError(f"'{chosen.get('name')}'은 메인 Studio예요: 메인은 HH_MAIN_STUDIO=1 이 있을 때만 건드려요 "
                           "(메인 반영 1 전용). 연습 Studio라면 STUDIO_NAME=UiSandbox 처럼 정하세요")
    return chosen["id"] if chosen is not None else None


class Client:
    def __init__(self):
        self.proc = subprocess.Popen(
            ["cmd.exe", "/c", MCP_BAT],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        self.q = queue.Queue()
        self.next_id = 1
        threading.Thread(target=self._reader, daemon=True).start()
        threading.Thread(target=self._drain_err, daemon=True).start()

    def _reader(self):
        for line in self.proc.stdout:
            line = line.decode("utf-8", "replace").strip()
            if line:
                try:
                    self.q.put(json.loads(line))
                except json.JSONDecodeError:
                    pass

    def _drain_err(self):
        for _ in self.proc.stderr:
            pass

    def send(self, msg):
        self.proc.stdin.write((json.dumps(msg) + "\n").encode("utf-8"))
        self.proc.stdin.flush()

    def request(self, method, params=None):
        rid = self.next_id
        self.next_id += 1
        self.send({"jsonrpc": "2.0", "id": rid, "method": method, "params": params or {}})
        while True:
            msg = self.q.get(timeout=TIMEOUT)
            if msg.get("id") == rid:
                if "error" in msg:
                    raise RuntimeError(json.dumps(msg["error"], ensure_ascii=False))
                return msg["result"]

    def start(self):
        self.request("initialize", {
            "protocolVersion": "2025-06-18",
            "capabilities": {},
            "clientInfo": {"name": "game-builder", "version": "1.0"},
        })
        self.send({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def call(self, name, args):
        if name != "list_roblox_studios" and "studio_id" not in args:
            args = dict(args, studio_id=self.studio_id())
        return self.request("tools/call", {"name": name, "arguments": args})

    def studio_id(self):
        # 스튜디오는 프록시가 뜬 뒤 몇 초 지나야 접속하므로 잠깐 기다리며 다시 묻는다
        import time
        # STUDIO_ID (an id or its prefix from list_roblox_studios) pins one window. Without it, two windows matching the
        # name (e.g. the user opened the place a second time, 2026-10-06) is an error: never guess which one to sync /
        # play, since that window may be the user's own play. No name and no id is an error too, and the main Studio
        # needs HH_MAIN_STUDIO=1 (pick_studio): a session that forgot STUDIO_NAME must never land in the main Studio.
        name = os.environ.get("STUDIO_NAME", "")
        pin = os.environ.get("STUDIO_ID", "")
        allow_main = os.environ.get("HH_MAIN_STUDIO", "").strip() == "1"
        pick_studio([], name, pin, allow_main)  # the missing-name error comes at once, before any waiting
        studios = []
        for _ in range(30):
            res = self.request("tools/call", {"name": "list_roblox_studios", "arguments": {}})
            studios = json.loads(res["content"][0]["text"])["studios"]
            found = pick_studio(studios, name, pin, allow_main)
            if found:
                return found
            time.sleep(0.5)
        want = pin.strip() or name.strip() or "GoodEvil"
        raise RuntimeError(f"'{want}' 스튜디오 창을 찾지 못했습니다: {[s.get('name') for s in studios]}")

    def close(self):
        try:
            self.proc.stdin.close()
            self.proc.terminate()
        except Exception:
            pass


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    c = Client()
    try:
        c.start()
        if sys.argv[1] == "list":
            for t in c.request("tools/list")["tools"]:
                print("==", t["name"])
                print(t.get("description", "").strip())
                print(json.dumps(t.get("inputSchema", {}), ensure_ascii=False))
                print()
        elif sys.argv[1] == "call":
            raw = sys.argv[3] if len(sys.argv) > 3 else "{}"
            if raw.startswith("@"):
                with open(raw[1:], encoding="utf-8") as f:
                    raw = f.read()
            res = c.call(sys.argv[2], json.loads(raw))
            for i, part in enumerate(res.get("content", [])):
                if part.get("type") == "image":
                    import base64
                    ext = part.get("mimeType", "image/png").split("/")[-1]
                    path = os.path.join(os.environ.get("TEMP", "."), f"studio_capture_{i}.{ext}")
                    with open(path, "wb") as f:
                        f.write(base64.b64decode(part["data"]))
                    print(f"[image saved: {path}]")
                else:
                    print(part.get("text", json.dumps(part, ensure_ascii=False)))
            if res.get("isError"):
                sys.exit(1)
    finally:
        c.close()


if __name__ == "__main__":
    main()
