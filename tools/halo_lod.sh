#!/bin/bash
B="C:/Users/glori/Tools/blender-5.2.2-windows-x64/blender.exe"
cd /c/Users/glori/Documents/Roblox/Game
# name src target
lod() { "$B" --background --factory-startup --python-exit-code 1 --python tools/glb_decimate.py -- art/models/tripo/web/$1 art/models/tripo/web/$2 $3 --weld 1e-5 2>&1 | grep -E "decimate\] (in|ratio|wrote)|Error"; }
lod Halo_Fountain_HD_plain.glb Halo_Fountain_HD_LOD.glb 10000
lod Halo_Tower_HD_plain.glb Halo_Tower_HD_LOD.glb 7000
lod Halo_DomeHouseA_HD_plain.glb Halo_DomeHouseA_HD_LOD.glb 8000
lod Halo_DomeHouseB_HD_plain.glb Halo_DomeHouseB_HD_LOD.glb 8000
lod Halo_Shop_HD_plain.glb Halo_Shop_HD_LOD.glb 8000
echo ALLDONE
