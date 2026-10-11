<!-- api_agent job l10n_v3_check · claude-opus-5-5 · done · 27 turns · ~$0.8672 -->
I checked the 11 first-review items and the 6 v2-check problems against `docs/design/l10n_contract_2026-10-11.md` v3 (e270f85a) and the `src/` lines named below. **Verdict: revise.** B1–B4 hold, but a v3 Format rule partly reopens B3 and would show raw keys to English players. I couldn't run any tests in this job.

## 1. Status of the review items

| # | Status | Fixing text (contract line), and what is missing |
|---|---|---|
| B1 | fixed | :8 "`L10n.T(player, …)`/`Fmt`/`Of`/`Lang(player)` … 모두 없음". Superseded marks are in l10n_server :11–50 and l10n_client :11–37. |
| B2 | fixed (gap: new problem 3) | :83 "보내는 글·Fx·속성·저장·ProximityPrompt·… 모두 id나 키만". The rows are at :93–99. |
| B3 | partly fixed | :49 "클라는 Args를 다시 꾸미지 않는다", :58 `%%`, :61 `{1:을}`. The narrower rule 1 at :53 breaks templates with no Args that contain a literal `%` (new problem 1). |
| B4 | fixed | :112 "`L10n.Get`은 `En` = 지금 영어일 때만 한국어". Test 4 is at :129. |
| S5 | fixed | :74 nested message, :79 `Join`, :70 `Named`, :90 `Countless`/`ShortNameKey`, :89 Announce exception / `BanterKey`. |
| S6 | partly fixed | :75 "`{ Who = displayName, Hon = true? }` … `{ Hidden = … }`". The KO Fx `Name` and the Goose/Combat wrappers still send the English string (new problem 2). |
| S7 | fixed | :88 "`Net.NotifyKey` … 약 230곳 … dev2_kit 491-494". Spot check: 14 `Net.NotifyAll(` calls, and the `pcall`/`require().Notify` forms are present. |
| S8 | fixed | :104 "`L10n.T(key, args, L10n.LangOf(player))`". |
| S9 | fixed | :21 "`DataLoaded`/`PlayerReady` 전", :23 "`LocalPlayer.LocaleId`". This fits `PlayerService.luau:544–564`. |
| S10 | fixed | :31 "끝의 `En`은 키에서 뺀다", :34 Register goes into nested tables, :117 one file pair, :128 coverage test. |
| S11 | fixed | :123 "`Config.UIArt.Lettering["HUD.TXT.Bag"] = { IdKo, Size }`". |
| v2-1 | partly fixed | :76 "`PublicName` … **지금처럼 문자열** … 새 `PublicNameArg`", :77 `KaijuHidden`. The real-name leak is gone, but nothing tells the KO Fx or the Goose wrapper to use `PublicNameArg`. |
| v2-2 | fixed, with a regression | :53 "Args와 Named가 둘 다 없고, 틀에 `%`·`{`·조사 표시가 하나도 없을 때만". See new problem 1. |
| v2-3 | partly fixed | :88 "`Text = L10n.Msg({…}, "en")`". Two contradictions remain: :14 still says "예외는 §5-4의 하나뿐", and the English `Text` on quest rows (:90) is not listed as an allowed exception in :83. |
| v2-4 | fixed | :141 "`L10nPseudo = true`, 저장값 아님". Every listed section is marked. The marks say "v2", not "v3", which doesn't matter. |
| v2-5 | partly fixed | :97 lists 17 attributes. It still misses `Nickname`/`NicknameVerified`, which `Util.PlayerDisplayName` reads (`Util.luau:167–173`), and the ghost label's `SackVictimName` (`CharacterVisuals.luau:1006`). |
| v2-6 | fixed | :99 "`Config.PetGrant.Names.<Lean>` 키". This fits `PetService.luau:184,278,287`. |

## 2. New problems

1. **BLOCKER: Format rule 1 breaks templates that have a literal `%` and no Args.**
   - Rule 1 (:53) now sends every template containing `%` through steps 2–5. Step 3 then "fills missing slots with ''", but :58 says templates without Args keep a single `%`. The contract contradicts itself.
   - Scenario: the contract's own example key `Config.Factions.Halo.Perks.1` = "XP +30% (level up faster)" (`Config.luau:803`); also "Gold +25% (get rich faster)" (:825).
   - If step 3 runs `string.format`, "% (" is an invalid conversion. The pcall fails, the English fallback fails the same way, and every player, English included, sees "Config.Factions.Halo.Perks.1".
   - If it scans for slots instead, "+25% gold" reads "% g" as a slot and garbles the text.
   - Fix: "No Args → never run `string.format` and leave `%` untouched; still do `{n}`, Named and josa."
2. **Hidden names on the KO screen and the Goose line stay English.**
   - :76 keeps the string-only wrappers. The KO Fx row (:94) only adds `Kind`/`TipIndex`, while `Name = publicName(killer)` and `publicName(k)` for the kaiju stay strings (`CombatService.luau:1394–1406,1421`). This also breaks the :83 "Fx: ids/keys only" rule.
   - Scenario: a hidden Halo player knocks out a Korean player, whose KO screen shows "A member of the Knights of Light". `Config.Text.RareAnnounce` (`GooseService.luau:592`) has the same problem.
   - Fix: KO Fx sends `Name = PublicNameArg(killer)` (Fx payloads can carry tables), and the wrapper rule becomes "switch wrappers that feed messages or Fx to `PublicNameArg`".
3. **The crossroads Most Wanted board has no channel.**
   - `PvPService.luau:878–937` rewrites `BoardText.Text` on a loop. It builds the text from `RankingService.ServerTop` weekly rows plus English `Config.Ranking.Text.Board` strings and `publicName` names; the label is created in `MapBuilder.luau:721`.
   - :97 says this board is built "from attributes", but the weekly ranking rows are not attributes. :98 (TextKey + TextArgs) can't hold a variable list of names.
   - Scenario: dev 2 leaves the board as it is, so Korean players get English. Or dev 2 blanks it per :97, and nobody sees the board.
   - Fix: add a row. The server puts the rows as a JSON attribute on the label (`{Board, Rank, Name = nameArg, Value, Outlaw}`), and the client renders it under the `L10nText` tag.
4. **The Announce exception leaves the client composer in English.**
   - :89 keeps the "client composer", which reads `Config.Announce.Text[Key]` directly and picks `…En` variants through `A.English()`. It also uses `Config.WeaponName`, the monster `Name`/`Short` and the faction `Name` (`Announce.luau:42–67`).
   - Section §10 gives the composer to nobody. Korean players get English rare-drop and boss lines.
   - The `HiddenFaction` rename (:78) is not needed: `who()` already sends `Faction` and `Who = ""` (`AnnounceService.luau:55–66`), and `A.Subject` falls back on `Who == ""`.
   - Fix: add a task to §10 — the composer uses `L10n.T("Config.Announce.Text."..Key)` plus the name-key helpers. Drop the rename.
5. **Plural only runs when `lang == "en"` (:56).** A Korean player whose translation is missing or stale falls back to the English template without Plural and sees "1 items". Fix: run Plural whenever the template used is the English one.
6. **Prompt keys have no table entries yet.** "Switch side", "Altar of Fate", "Look at jobs"/"Job Board", "Talk" and "Buy potions" are inline literals (`MapBuilder.luau:662–663,816,847`; `TownNpcs.luau:142,145`), not table fields. Test 5's "every `NotifyKey` key resolves" check doesn't cover `ActionKey`/`ObjectKey`, so a wrong key reaches the prompt as raw key text for English players too. Fix: move these strings into `Config.Text` first, and extend test 5 to check that prompt keys resolve.

**Inferred, not run:** how new problem 1 fails depends on how step 3 gets implemented. Both readings above produce a visible break.

## 3. Verdict: revise
B1, B2 and B4 are fixed. New problem 1 partly reopens B3 and would show key text to English players. Fixing it with the one-line rule above, plus problems 2–4, should be enough for approve-with-notes. Problems 5–6 and the two partly-fixed list items (v2-3, v2-5) are small.
