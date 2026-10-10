#!/bin/bash
# terrain dump -> layout plan -> rules check (이미지 생성 1)
cd /c/Users/glori/Documents/Roblox/Game
sed 's/^local DUMP = false/local DUMP = true/' tools/worldkit/halo_terrain.luau > build/halo_new/halo_terrain_dump.luau
build/luau_cli_0_741/luau.exe build/halo_new/halo_terrain_dump.luau > build/halo_new/halo_dump.txt || { tail -5 build/halo_new/halo_dump.txt; exit 1; }
head -1 build/halo_new/halo_dump.txt
py tools/halo_layout.py "$@" && py tools/halo_rules_check.py
