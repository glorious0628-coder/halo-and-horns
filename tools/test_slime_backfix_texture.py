"""slime_backfix_crown.luau must keep MeshPart.TextureID across ApplyMesh and adds the smaller Prince crown (CROWN_SCALE 0.7) on BigSlime (2026-10-09)."""
import re
import sys

src = open("tools/worldkit/slime_backfix_crown.luau", encoding="utf-8").read()
checks = {
    "texture saved before ApplyMesh (apply)": re.search(r"local texId = d\.TextureID\s+local ok, e = pcall\(function\(\) d:ApplyMesh\(newMesh\)", src),
    "texture restored after apply": re.search(r"d\.Size, d\.CFrame = size, cf\s+d\.TextureID = texId\s+d:SetAttribute\(\"BackfixWas\", oldId\)", src),
    "texture kept on restore": re.search(r"local texId = d\.TextureID\s+d:ApplyMesh\(oldMp\)\s+d\.Size, d\.CFrame = size, cf\s+d\.TextureID = texId", src),
    "Prince crown on, smaller than the King crown": "local ADD_CROWN = true" in src and "local CROWN_SCALE = 0.7" in src and "T.CrownSize * H * CROWN_SCALE" in src,
}
bad = [k for k, v in checks.items() if not v]
print("OK" if not bad else "FAIL: " + ", ".join(bad))
sys.exit(1 if bad else 0)
