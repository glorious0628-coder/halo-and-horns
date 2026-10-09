# API mode start (2026-10-09, 검수)

Why: weekly plan usage hit 98% (resets 2026-10-12 21:00 KST). The user moved the desktop app to Console API billing ($200 credits). In that mode the old sessions are not listed, so new sessions continue from files. Project memory (`MEMORY.md`) and `AGENTS.md` load by themselves in this folder.

## Budget rule in API mode
- $200 goes fast at API rates. Run only the 4 sessions below, model **Sonnet**, effort **medium** (검수 may use high for reviews). No Workflow / ultracode, no big subagent sweeps.
- Dev sessions (게임성 개발 1·2·3) wait for the plan reset on 10/12 21:00.
- 검수 checks spend on the Console usage page and tells the user at ~$40 left.

## First message to paste into each new session (Code tab, folder `C:\Users\glori\Documents\Roblox\Game`)
- **검수:** `너는 '모든 것 검수'야. docs/handoff/api_mode_start_2026-10-09.md 와 docs/handoff/review_handoff_2026-10-09.md 맨 아래 §7을 읽고 이어서 해. 사용자에겐 한국어로 짧게.`
- **메인 반영 1:** `너는 '메인 반영 1'이야. docs/handoff/api_mode_start_2026-10-09.md 의 '메인 반영 1' 줄을 읽고 이어서 해. 보고는 검수에게.`
- **이미지 생성 1:** `너는 '이미지 생성 1'이야. docs/handoff/api_mode_start_2026-10-09.md 의 '이미지 생성 1' 줄을 읽고 이어서 해. 보고는 검수에게.`
- **이미지 생성 2:** `너는 '이미지 생성 2'야. docs/handoff/api_mode_start_2026-10-09.md 의 '이미지 생성 2' 줄을 읽고 이어서 해. 보고는 검수에게.`
After they start, 검수 finds their ids with list_sessions and talks to them with send_message.

## Rules made today (all in SPEC_ADDENDUM)
- A23-96: every reused / recoloured / placeholder asset gets its own new model or image (`docs/design/remake_list_2026-10-09.md`). Credits: tell the user only at ~500 left (AGENTS 11afcf3).
- A23-97: one zone at a time, user order **Halo town → Horns town → Crossroads → Slime Meadow → Goblin Woods → (Skeleton Ruins) → Pumpkin Patch → Haunted Hollow**. Now = **Halo town**.
- A23-98: UI is designed and finished on PC first; phone gets only a "still playable" check until the phone round (before 10/17).

## Queues
- **메인 반영 1:** (1) if the user saved the main Studio before the switch (File → Save to Roblox + Ctrl+S), copy `build/GoodEvil.rbxlx` → `place/`, push with `py tools/push_paths.py`, run `py tools/test_place_english.py`. (2) Camera A23-91 (c3be8e44) check ③ only: diagonal, back walk, 1.5 s after right-drag (PC) + one phone "not blocked" shot. (3) Then Halo town: apply `tools/worldkit/halo_terrain.luau` + new Halo models together when 이미지 생성 1 hands them over; photos at the same angles as `art/review/s2/place_HaloTown_sheet.jpg`. Other zones' zone_swap stay off.
- **이미지 생성 1:** Halo town per `docs/design/halo_town_plan_2026-10-09.md` (20 new Tripo models, buildings first; Tripo web 25,000-pt account). Terrain tool done (f04e51c), not yet in main. **Fix first:** f04e51c rewrote `tools/studio_shot.py` and the main-Studio shot now fails ("request _meta … protocolVersion"); restore the old Edit-camera mode (226a13f6) as the default and keep the new cam/look mode behind arguments or in a separate file. Meadow concept set (b12987f) and meadow props list are kept for the meadow turn.
- **이미지 생성 2:** Halo town prop 2D (High) from the plan above: multiviews first (gate, tower, cathedral, dome houses A/B, shops with 4 awning colours and no lettering, knight statue, 3-tier fountain, arch stone bridge), then single images (railing, big stairs, gold lamp post, flower bed, cloud bush, cone topiary, round tree, pot, flagpole, far island + lighthouse, far arch rock). Hand them to 이미지 생성 1. Firefly pane: the user presses Ctrl+Shift+B in this session's window once. Slime multiviews (Prince, Flower, Shard) and the pink King multiview come before the meadow turn.
- **Waiting (no session now):** dev2 branch `dev2-a2392` 03582a38 (nudges off + King 3.2 + review fixes: Mobs3Ranged=false, FlowerPatch off, WindupTime, PvP toast 20 s, EnteredSafe) needs 게임성 개발 3 verification, then 검수 merges. 게임성 개발 1 queue: King stomp shake → auto-facing refinement → ruins/woods boundary rope → King/Clatter client → dev2 client half (MonsterShot Fx, Hidden/PopAt, Card Fx, ZoneHasPvP labels). 이미지 개발: faction background + mascots done (e7587530); next the P5 icons when drawn.

## Back to the plan on 10/12 21:00
The user chooses the Anthropic sign-in on the sign-in screen (or turns third-party inference off). The old sessions should show again; if not, start them the same way from `docs/handoff/review_handoff_2026-10-09.md`.
