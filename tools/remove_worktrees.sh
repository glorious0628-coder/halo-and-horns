#!/bin/bash
# 10/18 최종 검수: Roblox 폴더 정리 — 남길 것 = Game · Parcel · fashion (사용자 10/18).
# 1) Game의 git worktree(Game-dev1*, wt_*) 전부 지움 — 가지는 전부 origin에 push됨(개발 1·2 확인).
# 2) threadbound-art(git, github threadbound에 push됨, 안 push된 커밋 0) · art-test(ThreadboundArt 시험 place 4개) 지움.
# Avatar(4.9 GB, git 아님 — Blender/Meshy 아바타 스크립트·assets)는 이 스크립트가 안 지움: 따로 결정.
cd /c/Users/glori/Documents/Roblox/Game || exit 1
ok=0; fail=0
while read -r wt; do
  [ -z "$wt" ] && continue
  case "$wt" in */Roblox/Game) continue;; esac
  if git worktree remove --force "$wt" >/dev/null 2>&1; then ok=$((ok+1)); else echo "FAIL $wt"; fail=$((fail+1)); fi
done < <(git worktree list --porcelain | awk '/^worktree /{print $2}')
git worktree prune
echo "worktree 지움=$ok 실패=$fail"
cd /c/Users/glori/Documents/Roblox || exit 1
rm -rf threadbound-art art-test && echo "threadbound-art·art-test 지움"
echo "--- 남은 폴더:"; ls
