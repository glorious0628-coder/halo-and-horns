"""Rough proportion check of weapon 2D candidates (gray bg). Swords: blade/(total) ~0.67, guard width/L ~0.33, blade width/L ~1/7. Hammer: head width/L ~0.5."""
import numpy as np, sys
from PIL import Image
D = 'art/out/s2/weapons_t13_v2/Weapon_'
def mask(p):
    a = np.asarray(Image.open(p).convert('RGB')).astype(int)
    bg = np.median(np.concatenate([a[:8].reshape(-1, 3), a[-8:].reshape(-1, 3), a[:, :8].reshape(-1, 3), a[:, -8:].reshape(-1, 3)]), axis=0)
    return (np.abs(a - bg).sum(axis=2) > 45)
def sword(m):
    ys = np.where(m.any(axis=1))[0]; y0, y1 = ys[0], ys[-1]; L = y1 - y0 + 1
    w = m.sum(axis=1)
    gy = y0 + np.argmax(w[y0:y0 + int(L * .45)])  # guard = widest row in the top part (pommel up)
    guard_w = w[gy]
    blade = y1 - gy
    bw = np.median(w[gy + int(blade * .3): gy + int(blade * .7)])
    return L, blade / L, guard_w / L, bw / L
def staff(m):
    ys = np.where(m.any(axis=1))[0]; L = ys[-1] - ys[0] + 1; w = m.sum(axis=1)
    shaft = np.median(w[ys[0] + int(L * .5): ys[0] + int(L * .8)])
    big = np.where(w > shaft * 2.0)[0]
    return L, (big.max() - big.min() + 1) / L if len(big) else 0
def hammer(m):
    ys = np.where(m.any(axis=1))[0]; xs = np.where(m.any(axis=0))[0]
    return ys[-1] - ys[0] + 1, (xs[-1] - xs[0] + 1) / (ys[-1] - ys[0] + 1)
for k in ['Halo_Paladin', 'Horns_Berserker']:
    for t in (1, 2, 3):
        L, bf, gw, bw = sword(mask(f'{D}{k}_T{t}_v2.png')); print(f'{k} T{t}: L={L} blade/L={bf:.2f} guard/L={gw:.2f} bladeW/L={bw:.2f}')
for x in 'abc':
    L, bf, gw, bw = sword(mask(f'{D}Horns_Berserker_final_{x}.png')); print(f'Berserker final {x}: L={L} blade/L={bf:.2f} guard/L={gw:.2f} bladeW/L={bw:.2f}')
for k in ['Halo_LightMage', 'Horns_DarkMage', 'Neutral_Alchemist', 'Neutral_PetTamer']:
    for t in (1, 2, 3):
        L, o = staff(mask(f'{D}{k}_T{t}_v2.png')); print(f'{k} T{t}: L={L} head/L={o:.2f}')
for t in (1, 2, 3):
    L, r = hammer(mask(f'{D}Neutral_Blacksmith_T{t}_v2.png')); print(f'Blacksmith T{t}: L={L} width/L={r:.2f}')
