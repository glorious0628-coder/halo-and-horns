# 한국어 모드 계약 검토 (검수 워크플로 2026-10-11, 서버·클라·반박 3관점 + 종합)

대상: docs/design/l10n_contract_2026-10-11.md (main 4a4b702f). 판정: **고쳐서 승인**(막는 것 4·고칠 것 7). 아래는 종합 에이전트의 원문(영어, 코드 확인됨).

Verdict: approve-with-changes. The contract is not ready for code yet: 4 blockers and 7 should-fix items. I re-checked every finding against origin/main 5f049f94, and the claims below were confirmed in the code.

BLOCKERS
1. Header, §3 and §5: the contract conflicts with l10n_server_2026-10-10 §2, §4 and §7-2, and that document is still in force (the contract only replaces l10n_client §2, §3 and §6). The server doc defines L10n.T(player, key), L10n.Fmt / Of / Lang(player) and the server-side Translate safety net. Dev 2 following it would pass a Player where §3 expects the key. Change: in the header, say that l10n_server §2, §4 and §7-2 are replaced, that there is no server-side translation, and that the L10n API is only the five §3 functions. Dev 3 marks those sections as superseded.
2. §5-2: server-made text has no channel. These were checked:
   - ProximityPrompt ActionText / ObjectText: MapBuilder 662, 816, 847; TownNpcs 142, 145; ShopService 183.
   - The Fx "KO" payload sends English: Name is the monster name and Tip is the English joke line (CombatService 1421; sendFirstKO 1446).
   - Attributes hold English: Bark (BarkService 91) and SessionTitle (KaijuService 459).
   - Default pet names are saved to the DataStore in English (PetService 197, 278).
   - The nametag joins about 10 optional English parts plus RichText (CharacterVisuals 334-402). Other labels: "Golden " .. Name (MonsterService 1022), "Wanted Board", "Zzz", "'s grudge".
   - One TextKey + TextArgs per label cannot build these, and the server's later .Text writes overwrite the client's Korean.
   
   Change: add a rule that any server value a player reads (payloads, Fx, attributes, saves, prompts, Gui text) holds ids or keys, never English sentences. Then add these rows:
   - Prompts: attributes ActionKey / ObjectKey. The client sets the text in the PromptShown hook that already exists in Keybinds (line 515).
   - Fx KO: send Kind plus a tip index (FunTip must return its index too).
   - Bark becomes a line key or index; SessionTitle becomes a title id.
   - Nametag, monster bar and wanted board: the client builds them from attributes it already gets (Level, Class, Faction, TitleSel, Rookie, BullyStacks, Bounty, WantedStars, Outlaw, MonsterKind, Golden). The server creates only the empty Gui.
   - Static signs: TextKey plus a CollectionService tag. The server never rewrites .Text, and the client re-applies text when the tag is added (this also covers streaming).
   - Pets: save "" for default names, with a one-time migration on load that clears saved names equal to a known English default.
3. §4, §5-1, the §6 example and test 2: the number rule is wrong.
   - Util.FormatNumber gives "12.3K"; commas come from Util.FormatInt. GooseReward is "+%s gold +%s XP", but the Korean example uses %d. string.format("%d", "12.3K") throws, and a raw 12000 in a %s slot shows "12000". Both checked with luau.exe.
   - 31 strings contain a literal % ("Enhance Scroll 10%", "+25% gold"). string.format on them throws "missing argument #2".
   - Config.Plural is applied on the server today (LootService 576, QuestService 283, StoryQuestService 897). After the move nothing applies it, so English players see "1 items".
   
   Change:
   - The server keeps pre-formatting display amounts and sends them as strings for %s slots. Raw numbers go only to %d and %.1f. The client never re-formats Args.
   - Format returns the template unchanged when there are no Args. Otherwise it runs inside pcall, falls back to the English template and then to the key, and fills missing args with "". For "en" it runs Config.Plural.
   - Templates that take Args write a literal % as %%.
   - Test 2 compares the ordered list of placeholder types (%s / %d / %.1f), not just how many there are.
   - Fix the GooseReward example to use %s.
   - Fix the Korean particle rule (을/를, 이/가) before the first translation batch: either a josa marker such as {1:을} handled by Format, or a glossary rule that no particle follows a slot directly.
4. §6 and §7: TextKo does not keep the English it was translated from. 925 of the 1,916 keys are array indexes (692 of them in StoryQuests). Inserting one quest step shifts every later key, so the old Korean shows on the wrong step, and tests 1 and 2 still pass. The same happens when the English is edited. Change:
   - Each strings_ko.json row keeps the English it was translated from, and l10n_apply writes that into TextKo.
   - L10n.Get uses the Korean only when that stored English equals the current English; otherwise it shows English.
   - A new test fails and lists the stale keys for 검수.

SHOULD-FIX
5. §5-1 message shape cannot express several current server texts:
   - Board goals use named tokens {Unit} / {Camp} / {Big}, which the server fills with English monster names (BoardService 225).
   - The server fills {Auto} key tokens before toasts go out (StoryQuestService 72).
   - Quest rows strip "%d/%d" from the template and wrap the step in SkillLater, which needs a nested message with Args (StoryQuestService 889-893).
   - Reward lists are joined with " · " and have a varying number of parts (ChoiceCard 194, FinisherService 144, LostFoundService 291, StoryQuestService 1119).
   - Announce sends Args as a dictionary, not an array, and Broadcast drops table values, so a Banter sent as {Key} would disappear without a warning.
   - Quest rows also carry ShortName in English (the phone row).
   
   Change:
   - A nested argument may be a full {Key, Args} message.
   - Lists become {Join = {msg, ...}}, with the separator taken from a key per language.
   - Add an optional Named = {Unit = ...} next to Args. It must not go inside Args (mixed tables lose keys over remotes), and Args never holds nil.
   - Key tokens such as {Auto} stay raw in every language; the client runs Config.FillKeys after Format.
   - Quest rows send Countless = true and the client strips the counter from the chosen language's template. Add a test that every Korean ShowProgress template keeps %d/%d. Quest rows also get a key for ShortName.
   - Announce is an exception: it keeps its dictionary Args and its client composer, and Banter is sent as a BanterKey string.
   - Test 2 also compares named tokens.
6. §5-1 names: "player name = plain string" breaks for hidden names.
   - AnnounceService.PublicName and RankingService.hiddenName return English text ("A member of the %s", "Someone", Unknown). They feed the bounty, rebirth and kaiju lines, the KO Fx, KaijuName and ranking rows.
   - Weapon, class and title names are computed by Config.WeaponName / ClassName / DisplayTitle, so they have no key path to send.
   
   Change: a name argument is {Who = displayName} or {Hidden = factionId | "None"}, and the client renders the hidden form, Someone and the Honorific itself. Ranking rows send Hidden instead of text, and KaijuName uses the same shape. Add key helpers Config.WeaponNameKey / ClassNameKey / TitleKey / MonsterNameKey that both sides use.
7. §5-2 Notify row, §7-3 and §8: there are about 230 notify call sites, not 65.
   - 51 Net.Notify, 14 NotifyAll, 27 pcall(Net.Notify…), the require(...).Notify call in DataService 421, and about 140 calls through 17 local notify / fmt / say wrappers that receive finished strings.
   
   Change:
   - The §7-3 gate must match all of these forms, and the wrappers change to (player, key, args, ...).
   - NotifyKey also sends Text = L10n.T(key, args, "en"), so a mistyped key never shows "Config.Text.X" to English players. In Studio, NotifyKey raises an error when a key does not resolve.
   - Add NotifyKey / NotifyAllKey to the offline Net double in tools/fixtures/dev2_kit.luau (lines 491-494), so the 38 fixtures that read .Text keep passing.
8. §5-2 chat row and "예외 없음" are wrong for this place.
   - The place runs LegacyChatService. The server module ChatText.luau, written for the English-only rule A23-48, strips Roblox's localized lines to English and sends the Config.ChatText.Joined line from the server.
   - player:Kick(Config.Text.LoadFailed) can only be server text.
   
   Change: allow one exception. Server-only surfaces sent to one player (legacy chat system lines through speaker:GetPlayer(), and Kick) use L10n.T(key, args, L10n.LangOf(player)), where LangOf falls back to player.LocaleId. ChatText stops stripping Roblox's keyed lines. State that Team.Name and the leaderstats names stay English.
9. §1 when Lang is set and which source it reads. If Lang is set in SettingsService's PlayerReady handler, the FactionService and QuestService handlers run first (START_ORDER), so the first notices are drawn without it. The client fallback reads LocalizationService.RobloxLocaleId while the server reads player.LocaleId. Change:
   - PlayerService sets Lang at PlayerAdded and again right after the load, next to the Mirrored loop and before DataLoaded / PlayerReady.
   - The client fallback uses LocalPlayer.LocaleId.
   - A Settings click applies the new language on the client at once.
   - Queued notices and banners store {Key, Args} and render when shown.
10. §2, §6 and §7 coverage.
   - tools/l10n_export.py drops names: 4 of 32 weapon names, every class name (Paladin and the rest), and every skill NameEn (Halo Slam and the rest). It also emits 28 keys ending in "En", although §2 says keys drop "En".
   - Get cannot find "...Halo.Name" when only NameEn exists.
   - There is no extractor for client tables, and the file names disagree across the three docs (strings_en / strings_server_ko / strings_ko).
   - Test 1 only checks one direction, so a missing translation passes silently.
   - UIKit.Tx(table, key) knows only tables registered through Register, so Config.Text and nested tables (for example SkillBook T.Text) stay English.
   
   Change:
   - One tool and one file pair, strings_en.json / strings_ko.json, covering Config and the registered client tables.
   - Key = path without a trailing "En"; lookup tries the leaf, then leaf .. "En". The export treats *En fields and name tables as text.
   - Coverage test: every key has a TextKo entry or is listed in docs/l10n/keep_en.json.
   - L10n registers Config's subtables itself, and Register recurses into nested tables.
   - No player-facing text outside a registered table; a phone/PC variant becomes two keys.
   - Add a Studio pseudo-locale that marks every Get result, so leaked English is easy to spot.
11. §6, last line: one IdKo per art part cannot hold lettering. RibbonHeader, TitleRibbon and LogoPlate are shared wordless panels that carry every window title as a TextLabel, so one IdKo cannot be both 가방 and 상점. Change: key lettering images by text key, for example Config.UIArt.Lettering["HUD.TXT.Bag"] = {IdKo, Size}. When the language is ko and an entry exists, show the image and blank the label.

Dropped findings and why:
- Mixed client and server versions during a rolling update: a Roblox server always sends its own client scripts, so only saved data matters, and that is covered by item 2 (pets).
- Bitmap-font metrics and the single text-writing function: already in l10n_client §5, which the contract keeps. The byte-length width fallbacks are bugs to fix while converting screens.
- Payload size and per-message cost: {Key, Args} is smaller than the full text.
- TextService filtering: player-made text still goes as plain strings.
- Key-rename tooling and the SPEC "두 칸" wording: nice-to-have only.
