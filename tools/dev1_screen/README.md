# dev1 screen check tools (moved from build/dev1_tools on the old PC, 10/18)

Game dev 1's Studio check scripts (test Studio only: STUDIO_ID / STUDIO_NAME, never the main Studio). They import each
other from this folder and `tools/studio_mcp.py`; `h1016.py` has `GAME = r"C:\Users\glori\Documents\Roblox\Game"` -
change it on a new PC. On main they belong under `build/dev1_tools/` (git-ignored); this branch only carries them.

- check1020.py = the screen pass ④ (A dialog box, E codex [Go], S sword in hand, W water hides the weapon, P potion
  cooldown press), photos + log to docs/art/verification_2026-10-20/screen_1020/
- check1019.py (codex [Go], KO row, King glow, staff), check1018.py, press1017b.py, tune1016.py ... = the helpers it uses
