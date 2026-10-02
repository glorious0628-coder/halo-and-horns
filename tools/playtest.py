"""
스튜디오에서 Play를 눌러 잠깐 돌려 보고 콘솔 출력(에러 포함)을 보여준다.

  py tools/playtest.py              -> 15초 플레이 후 정지, 콘솔 출력
  py tools/playtest.py 30           -> 30초
  py tools/playtest.py 20 --keep    -> 끝나도 플레이 상태 유지 (이어서 execute_luau 로 검사할 때)
  py tools/playtest.py --stop       -> 플레이 정지만

미리 py tools/sync_to_studio.py 로 최신 코드를 넣어 둘 것.
"""

import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from studio_mcp import Client  # noqa: E402


def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    keep = "--keep" in sys.argv
    seconds = float(args[0]) if args else 15.0
    c = Client()
    try:
        c.start()
        state = text_of(c.call("get_studio_state", {}))
        if "--stop" in sys.argv:
            if "Current Studio Mode: Edit" not in state:
                c.call("start_stop_play", {"is_start": False})
            print("정지함")
            return
        if "Current Studio Mode: Edit" not in state:
            c.call("start_stop_play", {"is_start": False})
            time.sleep(2)
        before = text_of(c.call("get_console_output", {}))
        c.call("start_stop_play", {"is_start": True})
        time.sleep(seconds)
        after = text_of(c.call("get_console_output", {}))
        new = after[len(before):] if after.startswith(before) else after
        print(new.strip() or "(콘솔 출력 없음)")
        if not keep:
            c.call("start_stop_play", {"is_start": False})
    finally:
        c.close()


if __name__ == "__main__":
    main()
