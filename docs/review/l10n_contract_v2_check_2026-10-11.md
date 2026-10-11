<!-- api_agent job l10n_v2_check · claude-opus-5-5 · done · 22 turns · ~$0.8093 -->
**L10n contract v2 review (docs/design/l10n_contract_2026-10-11.md, a5187ad7)**

All 4 blockers are fixed as written, but v2 adds a new blocker: the hidden-name shape from S6 doesn't fit the code that uses it. Verdict is **revise**.

**1. Status of the review items**
| # | Status | Fixing text (contract) |
|---|---|---|
| B1 | fixed | :6 "`l10n_server` §2·§4·§7-2 … `L10n.T(player,…)`/`Fmt`/`Of`/`Lang(player)` … 모두 없음"; marked in l10n_server:11, :25, :48. Leftovers in that doc are new problem 4. |
| B2 | fixed | :78 "보내는 글·Fx·속성·저장·ProximityPrompt·… `.Text` 모두 id나 키만"; the rows are at :88–94. |
| B3 | fixed | :47 "클라는 Args를 다시 꾸미지 않는다"; :50–56 (Format rules, `%%`); :59 particle marker `{1:을}`; :122 placeholder-type order. |
| B4 | fixed | :107 "`L10n.Get`은 `En` = 지금 영어일 때만 한국어"; test 4 at :126. |
| S5 | fixed | :72–74 nested message / `Join`; :68 `Named`; :85 `Countless`/`ShortNameKey`; :84 Announce exception. |
| S6 | partly fixed | :73 "`{ Who = displayName }` 또는 `{ Hidden = factionId \| "None" }`". Missing: (a) an honorific flag, since `PublicName(p, true)` and `PublicName(p)` give different text; (b) KaijuName can't hold this shape (new problem 1). |
| S7 | fixed | :83 "새 `Net.NotifyKey` … `Text = L10n.T(key, args, "en")` … dev2_kit 491-494". Count checked: about 51 `Net.Notify(` in src/ServerScriptService. |
| S8 | fixed | :99 "`L10n.T(key, args, L10n.LangOf(player))`" (legacy chat lines and Kick only). |
| S9 | fixed | :19 "**`DataLoaded`/`PlayerReady` 전**에 한다". This fits PlayerService.luau:544–564 (Mirrored loop → DataLoaded → PlayerReady). |
| S10 | fixed | :29 "끝의 `En`은 키에서 뺀다 … 없으면 `Name .. "En"`"; :32 Register goes into nested tables; :112 one file pair; test 3 at :123. |
| S11 | fixed | :118 "`Config.UIArt.Lettering["HUD.TXT.Bag"] = { IdKo, Size }`". |

**2. New problems in v2**
1. **BLOCKER: the hidden-name table breaks every caller and leaks real names.** :73 says `PublicName` returns `{Who}`/`{Hidden}`. But all the local `publicName` wrappers only accept a string and otherwise fall back to the real name:
   - GooseService.luau:77–79 and CombatService.luau:1397–1399 fall back to `Util.PlayerDisplayName(p)`. Scenario: a player with HideAnnounceName kills someone; the KO screen (and the Goose "rare reward" line) shows the killer's real name.
   - RankingService.luau:136–138 falls back to the English hidden name.
   - KaijuName is a GameState string attribute (Net.luau:77, KaijuService.luau:126). An attribute can't hold a table.
   - Fix: leave `PublicName` returning a string (log/fallback only). Add `PublicNameArg(p, honorific)` that returns `{Who=…, Hon=true}` / `{Hidden=…}`, and switch the wrappers to it. Split KaijuName into the string `KaijuName` plus a `KaijuHidden` attribute holding the faction id. Also note that Announce already sends `Hidden` as a boolean (AnnounceService.luau:59–61); rename one of the two fields.
2. **Rule 1 of Format skips `Named` and particle markers.** :51 says "Args가 없으면 틀을 그대로" (no Args → return the template unchanged). Board messages send only `Named` (:86), so Korean and English players both see a raw `{Unit}`. A template with slots sent without Args shows raw `%s`/`%%`, which contradicts rule 3 (:53). Fix: return the template unchanged only when Args and Named are both nil **and** the template has no `%`, `{` or particle marker.
3. **The fallback `Text` on notifications is built wrongly.** :40 defines `T` as `Format(Get(…))`, and only `Msg` renders nested messages, names and `Join` (:41). So `Text = L10n.T(key, args, "en")` (:83) drops `Named` and turns table args into "table: 0x…". The 38 dev2_kit fixtures that read `.Text` would get that, and the Studio "key must resolve" error doesn't check nested keys. Fix: `Text = L10n.Msg({Key=key, Args=args, Named=named}, "en")`. In :78, also say that the English `Text` fields on notifications and quest rows (:85) are allowed fallbacks; right now they contradict "no English sentences".
4. **Other docs and Config still contradict the contract.**
   - Parts of l10n_server are not marked superseded and still read as in force: §3 (TextKo as plain strings, `L10n.Fmt`, l10n_server:20–21), §5 ("표에 있기만 하면 B가 번역해 준다", :35), §6 (`strings_server_ko.json`, :42) and §7-1 (Lang set in SettingsService, Translate, :47). §7-1 directly conflicts with contract §1. Fix: mark those four sections superseded too.
   - The pseudo-locale `Lang = "xx"` (:136) is not one of Config's options for `Settings.Lang` ("Auto"/"ko"/"en", Config.luau:4583). I infer, without opening the sanitizer, that the setting would be sanitized back to Auto. Fix: use a Studio-only flag instead of a save value.
5. **The nametag attribute list is incomplete** (:92). `updateNametag` also reads Honor, Infamy, FallMarks, RedeemMarks, SessionTitle, Rebirths, TitlesOwned and GraduateGraceUntil (CharacterVisuals.luau:338–368). A client built only from the listed attributes would show wrong titles or drop the Rebirth/Sprout Grace parts for everyone, English players included. Fix: "every attribute `updateNametag` reads today", with the full list.
6. **Saving `""` for pet names loses the choice-based name.** Default names come from `Config.PetGrant.Names[lean]` (PetService.luau:278, :287), not from the species. Under :94 the client would show the species name, so an English player's "Good"/"Evil" pet name changes after the migration. Fix: when `Name == ""` and the species is the PetGrant species, show the key `Config.PetGrant.Names.<Lean>`; otherwise show the species name.

**3. Verdict: revise.** B1–B4 are fixed. New problem 1 is a blocker: it leaks hidden players' names, and KaijuName can't hold the shape. Problem 2 shows raw `{Unit}` on the job board to every player. Fixing problems 1–3 should be enough to approve with notes; 4–6 are small.

**Checked vs. inferred.** I read each code reference above in src/ (Keybinds.luau:515 `PromptShown`→`applyPrompt` exists; dev2_kit.luau:493–496 Notify double; PlayerService order). I could not run tests in this job. The real-name leak is inferred from the fallback code paths, not reproduced.
