# AGENTS.md — Halo & Horns (선악 키우기) / for Codex and any coding agent

Read this file first, then `docs/HANDOFF_CODEX.md` (full state, history and next steps).

**Priorities and dates:** `docs/RELEASE_PLAN.md` (user-confirmed 2026-10-04) overrides the HANDOFF task order.
- Beta: 2026-10-31 11:00 KST.
- Full launch: 2026-12-19.
- Languages: Korean + English in one experience.
- The core design rule is `docs/GDD.md` §0.

## The user (very important)
- Korean-speaking beginner Roblox creator. **Every sentence you write to the user is Korean** (short progress notes too). Code, identifiers, paths and commit-body details may be English; commit titles are short Korean.
- Does **not** want explanations or design theory. Wants a working, playable Roblox Studio game. Report briefly: what changed, what to click/play.
- **All visual design is done with GPT image generation** (you can generate images natively). Generate options, show them one by one, let the user pick, then implement exactly the picked image. Never invent visual styling in code.
- The user has GPT Pro: generate images freely.
- **Cutout quality (user-confirmed 2026-10-04):** Check transparent assets enlarged on both light and dark backgrounds, then in the actual client. Preserve the approved artwork's border and lettering; remove detached fragments, background-colored fringes, and holes. A successful upload is not visual approval. Fix visible cutout defects before reporting completion.
- **Generate UI parts separately (user-confirmed 2026-10-04):** Production cards, title ribbons, description panels, and footer panels must each be generated individually as transparent PNGs from the start. A full-screen mockup is a design reference, not a source sheet to cut apart for production. Show and approve replacement artwork before uploading it.
- **Full redraw when requested (user-confirmed 2026-10-04):** Do not answer a request for complete redraw with partial retouching or old bitmap fragments. Inspect lettering enlarged as well as at game scale; visible mottled glyph fills or ghost outlines are a failed candidate, even if the full panel looks clean when reduced.
- **Approved design stays fixed (user correction, 2026-10-04):** Height, width and text-alignment complaints do not authorize changing approved artwork. The approved faction cards are `art/ui/UIP_FactionCard{Halo,Horns,Neutral}_FreshTyped.png`. Preserve their emblems, frames, ornaments, colors and style. The modular `Aligned` replacement cards were explicitly rejected for changing the design; do not apply them. General permission to keep working does not override this approval.
- **Current design pass (user-confirmed 2026-10-04):** Establish the game's basic visual design before the next story and full-play audit. Inventory the artwork actually used in game, then redraw UI parts individually on transparent backgrounds, starting with faction selection, HUD and shared screens. Keep text as clean separately typeset layers where practical. Report completed/total counts for the current screen, distinguish them from overall gameplay issues, and continue design updates after the baseline is established. This does not authorize paid 3D regeneration or change release dates.
- **Redraw scope clarified (2026-10-04):** The user wants all artwork except the 3D avatars redrawn, explicitly including every class illustration. Keep the established illustrated style. Human class characters must have covered shoulders, torso, midriff and legs; only face/hands may be exposed. No crop tops or revealing outfits. Transparent cutouts apply to standalone sprites/UI; identify tileable terrain/material textures separately rather than making required texture surfaces transparent. Keep the original 3D avatars intact in this design pass.

## Hard rules
1. **Roblox moderation safety.** The user's old Roblox account was suspended on 2026-10-03 for "sexual content" (anime female characters with revealing outfits). Every character/creature image must have modest, kid-friendly clothing (torso fully covered, no cleavage/bare midriff/bare shoulders, skirts knee-length+ with tights, no suggestive poses; avoid gore). Before **any** Roblox upload: look at every image yourself, show the user, upload in small batches (≤ 10, spaced out). **Never upload anything from `art/out/v1/`** (old/rejected/revealing images live there, incl. `art/out/v1/revealing/`).
   - Latest user decision (2026-10-03): monster clothing is not required for non-sexual creatures. Keep Slime and the original shirtless Goblin/GoblinBrute designs. Use the selected clothed Skeleton design; keep human class avatars modest. Do not apply the unused clothed Goblin revisions.
2. The user now uses a **new Roblox account**. Assets uploaded by the old account (ids in `art/ui/asset_ids.json`, Tripo meshes in the place's `ServerStorage.CustomModels`, MaterialService `GE_Grass`) must be re-uploaded/re-imported under the new account — from the files already on disk (no need to regenerate). The user explicitly authorized starting today, 2026-10-03 ("아니야 오늘부터 해도 돼"), overriding the original 2026-10-04 start date.
3. Never touch the user's other place `somssi-dev.rbxlx`. The game place is `build/GoodEvil.rbxlx` (Studio saves there; `place/GoodEvil.rbxlx` is the committed copy).
4. Secrets: the Tripo API key lives only in the git-ignored `.env` (`TRIPO_API_KEY=`). Never print it, never ask the user to paste it in chat.
5. Commit + push to `main` after each meaningful round (`https://github.com/glorious0628-coder/halo-and-horns`, private). `build/` is ignored.
6. **No screen control by default (user complaint, 2026-10-04).** Do NOT use computer-use / desktop screen control (mouse, keyboard, desktop screenshots) for work that tools can do. Use these instead:
   - files, `py`/PIL and the Blender CLI for checks and renders;
   - `tools/studio_mcp.py` for Studio (`execute_luau`, `screen_capture`, `start_stop_play`, `multi_edit`).
   - If a step truly needs a GUI no tool can reach:
     1. Ask the user first, in Korean, saying what you will click and for how long.
     2. Wait for OK, then do it in one short burst.
     3. Release control immediately.
   - Never keep screen control on while doing file checks or other work.

## Code conventions (Luau, Roblox)
- `src/` is a Rojo-style tree (no Rojo installed): `*.server.luau` = Script, `*.client.luau` = LocalScript, `*.luau` = ModuleScript. Services follow `Init(S)` / `Start()`; entry points `src/ServerScriptService/Main.server.luau` and `src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau`.
- Specs: `docs/TECH_SPEC.md` (contracts), **`docs/SPEC_ADDENDUM.md` (authoritative; A1–A21)**, `docs/GDD.md` (Korean design), `docs/ART_DIRECTION.md`.
- Luau only: `continue`, `+=`, type annotations OK; **no `local x <const>`**. Use `task.*` (not `wait/spawn/delay`). pcall anything that can throw. Server-authoritative; validate every remote. Player-facing text is Korean.
- **Luau limit: 200 locals per function scope, including the file's top-level chunk.** `Fx.luau` and `HUD.luau` are close to it — put new constants/state into tables (e.g. `MOTION`, `L`, `COL`, `TXT`).
- UI art goes through `Config.UIArt.Parts` + `UIKit.ArtImage / ArtButton / ArtFrame`; an empty `Id = ""` means "draw the code fallback" (IMG-R4) — keep fallbacks working.

## Tools (Windows; use `py` for Python)
- `py tools/studio_mcp.py call <tool> '<json>'` — talks to Roblox Studio MCP directly (spawns `%LOCALAPPDATA%\Roblox\mcp.bat`; picks the Studio window whose name contains `GoodEvil`). Studio must be open with the GoodEvil place and MCP enabled.
- `py tools/luau_check.py [files...]` — real Roblox compiler syntax check (Studio must be in **Edit** mode, not Play).
- `py tools/sync_to_studio.py` — push `src/` into the open Studio (stops Play first).
- `py tools/playtest.py 15 [--keep]` / `py tools/playtest.py --stop` — play N seconds and print console.
- `tools/preview_map.lua` — builds the world map/terrain in Edit mode (`studio_mcp.py call execute_luau @file.json`).
- `bash tools/gen_images.sh <ids...>` (Git Bash) — Codex image batch: prompt `art/prompts/<id>.txt` → `art/out/<id>.png`; `REFS="a.png b.png"` attaches style references. (You can also just generate images natively.)
- `py tools/prep_ui.py [UIP_...]` — trims/resizes UI parts to `art/ui/`, measures 9-slice → `art/ui/ui_meta.json`.
- `py tools/tripo_api.py balance | gen <img> <name> [--recipe character|monster|boss] [--rig] [--dry] | batch <list.json> | task <id>` — Tripo 3D API v3 (see `docs/vendor/tripo_api/README_KO.md`).
- Blender 5.2: `%LOCALAPPDATA%\Programs\blender-5.2.2-windows-x64\blender.exe --background --factory-startup --python tools/fix_face.py -- in_2k.glb out.glb` (head split + 1024 head texture + sharpen); `tools/render_front.py` renders a front preview.
- Uploading images to Roblox: serve `art/ui/` with `py -m http.server 8765 --bind 127.0.0.1` (from inside `art/ui`), then `studio_mcp.py call upload_image '{"imagePaths":["http://127.0.0.1:8765/<file>.png"]}'` → `rbxassetid://…`; record ids in `art/ui/asset_ids.json` and `Config.UIArt.Parts`.
