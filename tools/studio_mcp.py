"""
Roblox Studio MCP(StudioMCP.exe)와 직접 대화하는 작은 클라이언트.

  py tools/studio_mcp.py list                       -> 사용 가능한 도구 목록
  py tools/studio_mcp.py call <tool> '<json args>'  -> 도구 호출
  py tools/studio_mcp.py call <tool> @args.json     -> 인자를 파일에서 읽기

studio_id 를 생략하면 이름에 STUDIO_NAME(기본값 "GoodEvil")이 들어간 스튜디오 창을 자동으로 고른다.
"""

import json
import os
import subprocess
import sys
import threading
import queue

MCP_BAT = os.path.join(os.environ["LOCALAPPDATA"], "Roblox", "mcp.bat")
TIMEOUT = float(os.environ.get("STUDIO_MCP_TIMEOUT", "120"))


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
        # GoodEvil local file, or the published private experience (Darugi_S2 private place 81671223175574, 2026-10-06)
        want = os.environ.get("STUDIO_NAME", "GoodEvil|81671223175574")
        studios = []
        for _ in range(30):
            res = self.request("tools/call", {"name": "list_roblox_studios", "arguments": {}})
            studios = json.loads(res["content"][0]["text"])["studios"]
            for s in studios:
                if any(w.lower() in (s.get("name") or "").lower() for w in want.split("|")):
                    return s["id"]
            time.sleep(0.5)
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
