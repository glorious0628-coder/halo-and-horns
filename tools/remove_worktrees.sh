#!/bin/bash
# 10/18 최종 검수: Halo & Horns 멈춤 → Roblox 폴더의 git worktree(Game-dev1*, wt_*) 전부 지움.
# 가지는 전부 origin에 push돼 있음(개발 1·2 확인). 바뀐 파일 = 시험이 다시 쓰는 docs/art/verification_*만.
# Game 폴더 자체·Avatar·Parcel·fashion·threadbound-art·art-test는 건드리지 않음(worktree가 아님).
cd /c/Users/glori/Documents/Roblox/Game || exit 1
ok=0; fail=0
while read -r wt; do
  [ -z "$wt" ] && continue
  case "$wt" in */Roblox/Game) continue;; esac
  if git worktree remove --force "$wt" >/dev/null 2>&1; then ok=$((ok+1)); else echo "FAIL $wt"; fail=$((fail+1)); fi
done < <(git worktree list --porcelain | awk '/^worktree /{print $2}')
git worktree prune
echo "지움=$ok 실패=$fail"
git worktree list
ls /c/Users/glori/Documents/Roblox
