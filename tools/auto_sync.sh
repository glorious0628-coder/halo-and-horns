#!/usr/bin/env bash
# src/ 가 바뀔 때마다 스튜디오에 자동 동기화. build/auto_sync.stop 파일을 만들면 멈춘다.
cd "$(dirname "$0")/.." || exit 1
export PYTHONIOENCODING=utf-8
last=""
rm -f build/auto_sync.stop
while [ ! -f build/auto_sync.stop ]; do
  cur=$(find src -type f -name '*.luau' -printf '%T@ %p\n' 2>/dev/null | sort | md5sum)
  if [ "$cur" != "$last" ]; then
    out=$(timeout 300 py tools/sync_to_studio.py --skip-if-playing 2>&1 | tail -n 3)
    echo "$(date +%H:%M:%S) $out" >> build/auto_sync.log
    case "$out" in *"동기화 완료"*) last="$cur" ;; esac
  fi
  sleep 15
done
echo "$(date +%H:%M:%S) stopped" >> build/auto_sync.log
