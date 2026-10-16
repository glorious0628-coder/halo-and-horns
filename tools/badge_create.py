"""Create game badges via Open Cloud with expectedCost=0 (never spends Robux: a paid badge fails with error 18).
usage: py badge_create.py <Key> [<Key> ...]   (keys from the table below)
Prints: key -> badge id. Never prints the API key."""
import sys, json, urllib.request, uuid, os

ROOT = "C:/Users/glori/Documents/Roblox/Game/"
UNIVERSE = 10769445522
B = {
    "ChoseSide": ("Chose a Side", "You picked your side: Halo, Horns or the Artisans.", "BadgeChoseSide.png"),
    "FirstSlime": ("First Slime", "You beat your very first monster.", "BadgeFirstSlime.png"),
    "LostLunchbox": ("Lost Lunchbox", "You found Tiny's lunchbox and brought it home.", "BadgeLunchbox.png"),
    "Stronger": ("Stronger!", "You got a better weapon than your first one.", "BadgeStronger.png"),
    "FirstSkill": ("First Skill", "Your teacher taught you your first skill.", "BadgeFirstSkill.png"),
    "ShardChoice": ("Shard Choice", "Your crown shard learned to fight with you.", "BadgeShardChoice.png"),
    "Rank2": ("Rank 2", "Your halo or horns grew to rank 2.", "BadgeRank2.png"),
}


def key():
    for line in open(ROOT + ".env", encoding="utf-8"):
        if line.startswith("ROBLOX_OPENCLOUD_KEY="):
            return line.split("=", 1)[1].strip()
    sys.exit("no key")


def create(k):
    name, desc, img = B[k]
    bnd = uuid.uuid4().hex
    parts = []
    for fname, val in (("name", name), ("description", desc), ("paymentSourceType", "1"), ("expectedCost", "0"), ("isActive", "true")):
        parts.append(f"--{bnd}\r\nContent-Disposition: form-data; name=\"{fname}\"\r\n\r\n{val}\r\n".encode())
    data = open(ROOT + "art/ui/" + img, "rb").read()
    parts.append(f"--{bnd}\r\nContent-Disposition: form-data; name=\"files\"; filename=\"{img}\"\r\nContent-Type: image/png\r\n\r\n".encode() + data + b"\r\n")
    parts.append(f"--{bnd}--\r\n".encode())
    body = b"".join(parts)
    req = urllib.request.Request(f"https://apis.roblox.com/legacy-badges/v1/universes/{UNIVERSE}/badges", data=body, method="POST",
                                 headers={"x-api-key": key(), "Content-Type": f"multipart/form-data; boundary={bnd}"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            res = json.loads(r.read().decode())
            print(k, "->", res.get("id"), res.get("name"))
            return res.get("id")
    except urllib.error.HTTPError as e:
        print(k, "HTTP", e.code, e.read().decode()[:300])
        return None


out = {}
for k in sys.argv[1:]:
    out[k] = create(k)
print(json.dumps(out))
