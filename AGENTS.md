# AGENTS.md — Halo & Horns (선악 키우기) / for Codex and any coding agent

Read this file first, then `docs/HANDOFF_CODEX.md` (full state, history and next steps).

## The user (very important)
- Korean-speaking beginner Roblox creator. **Every sentence you write to the user is Korean** (short progress notes too). Code, identifiers, paths and commit-body details may be English; commit titles are short Korean.
- Does **not** want explanations or design theory. Wants a working, playable Roblox Studio game. Report briefly: what changed, what to click/play.
- **All visual design is done with GPT image generation** (you can generate images natively). Generate options, show them one by one, let the user pick, then implement exactly the picked image. Never invent visual styling in code.
- The user has GPT Pro: generate images freely.

## Hard rules
1. **Roblox moderation safety.** The user's old Roblox account was suspended on 2026-10-03 for "sexual content" (anime female characters with revealing outfits). Every character/creature image must have modest, kid-friendly clothing (torso fully covered, no cleavage/bare midriff/bare shoulders, skirts knee-length+ with tights, no suggestive poses; avoid gore). Before **any** Roblox upload: look at every image yourself, show the user, upload in small batches (≤ 10, spaced out). **Never upload anything from `art/out/v1/`** (old/rejected/revealing images live there, incl. `art/out/v1/revealing/`).
   - Latest user decision (2026-10-03): monster clothing is not required for non-sexual creatures. Keep Slime and the original shirtless Goblin/GoblinBrute designs. Use the selected clothed Skeleton design; keep human class avatars modest. Do not apply the unused clothed Goblin revisions.
2. The user now uses a **new Roblox account**. Assets uploaded by the old account (ids in `art/ui/asset_ids.json`, Tripo meshes in the place's `ServerStorage.CustomModels`, MaterialService `GE_Grass`) must be re-uploaded/re-imported under the new account — from the files already on disk (no need to regenerate). The user explicitly authorized starting today, 2026-10-03 ("아니야 오늘부터 해도 돼"), overriding the original 2026-10-04 start date.
3. Never touch the user's other place `somssi-dev.rbxlx`. The game place is `build/GoodEvil.rbxlx` (Studio saves there; `place/GoodEvil.rbxlx` is the committed copy).
4. Secrets: the Tripo API key lives only in the git-ignored `.env` (`TRIPO_API_KEY=`). Never print it, never ask the user to paste it in chat.
5. Commit + push to `main` after each meaningful round (`https://github.com/glorious0628-coder/halo-and-horns`, private). `build/` is ignored.

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
