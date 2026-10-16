#!/bin/bash
# 최종 검수 merge gate (10/16): build the merge of branch tips onto origin/main in build/review_chain/tree,
# luau-compile every src file, then run the listed offline tests. Nothing is pushed.
#   TESTS="town_quests skills" bash tools/review_chain.sh <sha>="병합 제목" [<sha>="제목" ...]
# Then, if it all passes:  py tools/merge_chain.py push <FINAL sha printed here> <same sha="제목" list>
#   git fetch -q origin; git merge-base --is-ancestor <sha> origin/main && echo MERGED; git reset -q --keep origin/main
# Some tests take no --no-mutations flag (quest_data, weapon_motion): run them by hand in the tree.
ROOT=/c/Users/glori/Documents/Roblox/Game
MC="$ROOT/build/review_chain"
cd "$ROOT" || exit 1
git fetch -q origin
py tools/merge_chain.py build "$MC" "$@" 2>&1 | tail -6
mkdir -p "$MC/tree/build/luau_cli_0_741" "$MC/tree/place" "$MC/tree/art/models/tripo/weapons"
cp build/luau_cli_0_741/* "$MC/tree/build/luau_cli_0_741/"
cp build/*.luau "$MC/tree/build/" 2>/dev/null
cp place/GoodEvil.rbxlx "$MC/tree/place/" 2>/dev/null
cp art/models/tripo/weapons/weapons_fit_manifest.json "$MC/tree/art/models/tripo/weapons/" 2>/dev/null
cd "$MC/tree" || exit 1
n=0
while IFS= read -r f; do
  if ! build/luau_cli_0_741/luau-compile.exe "$f" >/dev/null 2>&1; then echo "COMPILE FAIL $f"; n=$((n+1)); fi
done < <(find src -name '*.luau')
echo "compile_fail=$n"
for name in $TESTS; do
  t="tools/test_$name.py"; echo "=== $name"
  if [ ! -f "$t" ]; then echo "(no test)"; continue; fi
  timeout 900 py -X utf8 "$t" --no-mutations 2>&1 | tail -2
done
echo REVIEW_CHAIN_DONE
