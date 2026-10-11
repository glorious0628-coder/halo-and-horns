#!/bin/bash
# usage: tools/halo_props_run.sh [name-filter]   runs tools/prop_build.sh for every line of tools/halo_props_list.txt (one at a time)
cd /c/Users/glori/Documents/Roblox/Game
grep -v '^#' tools/halo_props_list.txt | grep "${1:-.}" | while read -r n fit dec lamp grid front; do
  [ -z "$n" ] && continue
  bash tools/prop_build.sh "$n" "$front" "$fit" "$dec" "$lamp" "$grid" > "art/models/tripo/halo_props/_logs_$n.txt" 2>&1
  echo "$n exit $?"
done
