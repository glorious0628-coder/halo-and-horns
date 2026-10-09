"""slime_backfix_crown.luau must keep MeshPart.TextureID across ApplyMesh and must not add the crown by default (2026-10-09)."""
import re
import sys

src = open("tools/worldkit/slime_backfix_crown.luau", encoding="utf-8").read()
checks = {
    "texture saved before ApplyMesh (apply)": re.search(r"local texId = d\.TextureID\s+local ok, e = pcall\(function\(\) d:ApplyMesh\(newMesh\)", src),
    "texture restored after apply": re.search(r"d\.Size, d\.CFrame = size, cf\s+d\.TextureID = texId\s+d:SetAttribute\(\"BackfixWas\", oldId\)", src),
    "texture kept on restore": re.search(r"local texId = d\.TextureID\s+d:ApplyMesh\(oldMp\)\s+d\.Size, d\.CFrame = size, cf\s+d\.TextureID = texId", src),
    "crown off by default": "local ADD_CROWN = false" in src and "elseif not ADD_CROWN then" in src,
}
bad = [k for k, v in checks.items() if not v]
print("OK" if not bad else "FAIL: " + ", ".join(bad))
sys.exit(1 if bad else 0)
