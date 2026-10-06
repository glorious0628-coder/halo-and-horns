"""
Close the loop of an existing MonsterAnims clip in place (review 8e89d2b): blend a correction over the clip so the
last frame equals the first and remove the linear drift of every translated bone (hips creeping forward).
Same maths as the --loop path of tools/glb_anim_to_luau.py, for clips converted before that fix.

  py tools/anim_close_loop.py src/ReplicatedStorage/MonsterAnims/Goblin_Walk.luau [...]
"""
import math
import re
import sys

sys.path.insert(0, __import__("os").path.dirname(__file__))
from glb_anim_to_luau import qinv, qmul, slerp  # noqa: E402


def nums(values):
    return ",".join(("%.4f" % v).rstrip("0").rstrip(".") if v != 0 else "0" for v in values)


def close(path):
    s = open(path, encoding="utf-8").read()
    frames = int(re.search(r"Frames = (\d+)", s).group(1))
    n = frames - 1
    worst = 0.0

    def fix(m):
        nonlocal worst
        name, rtxt, ptxt = m.group(1), m.group(2), m.group(3)
        r = [float(x) for x in rtxt.split(",")]
        q0, qn = tuple(r[0:4]), tuple(r[4 * n:4 * n + 4])
        corr = qmul(q0, qinv(qn))
        if corr[3] < 0:
            corr = tuple(-x for x in corr)
        worst = max(worst, 2 * math.degrees(math.acos(min(1.0, abs(corr[3]) / (math.sqrt(sum(c * c for c in corr)) or 1)))))
        for f in range(frames):
            c = slerp((0.0, 0.0, 0.0, 1.0), corr, f / n)
            q = qmul(c, tuple(r[4 * f:4 * f + 4]))
            ql = math.sqrt(sum(x * x for x in q)) or 1.0
            q = tuple(x / ql for x in q)
            if q[3] < 0:
                q = tuple(-x for x in q)
            r[4 * f:4 * f + 4] = q
        out = f'["{name}"] = {{ r = {{ {nums(r)} }}'
        if ptxt:
            p = [float(x) for x in ptxt.split(",")]
            drift = [b - a for a, b in zip(p[0:3], p[3 * n:3 * n + 3])]
            for f in range(frames):
                w = f / n
                p[3 * f:3 * f + 3] = [v - d * w for v, d in zip(p[3 * f:3 * f + 3], drift)]
            out += f", p = {{ {nums(p)} }}"
        return out

    s2 = re.sub(r'\["([^"]+)"\] = \{ r = \{ ([^}]*) \}(?:, p = \{ ([^}]*) \})?', fix, s)
    s2 = s2.replace("Loop = false", "Loop = true")
    open(path, "w", encoding="utf-8", newline="\n").write(s2)
    print(f"{path}: closed (largest end mismatch before {worst:.1f} deg)")


for p in sys.argv[1:]:
    close(p)
