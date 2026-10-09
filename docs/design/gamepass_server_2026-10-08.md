# A23-75 게임 패스 서버 (게임성 개발 2, 2026-10-08)

스펙: `docs/SPEC_ADDENDUM.md` A23-75(가격은 사용자가 "추천 가격대로" 정함), A23-77(출석 전용 치장).
시험: `py tools/test_gamepass.py`. 증거: `docs/art/verification_2026-10-08/offline_dev2_gamepass_2026-10-08.json`.

## 1. 한 줄 요약

- 경험치 2배(199)·골드 2배(149)·VIP(249) 패스와 진영 치장 4개(각 99)를 서버가 확인해요.
- 플레이어 속성으로 화면에 알려 줘요.
- 2배는 **버는 것에만, 한 번만** 곱해요.
- 능력치는 팔지 않아요.
- 패스 Id가 0인 동안은 Roblox에 묻지 않아요. 화면은 "Coming soon"이에요.

## 2. Config (서버·클라 공용, `src/ReplicatedStorage/Shared/Config.luau`)

| 이름 | 모양 | 뜻 |
|---|---|---|
| `Config.GamePasses[Kind]` | `{ Id, Price, Name, Attr }` | Kind = `XP2`·`Gold2`·`VIP`. Name "2x XP"·"2x Gold"·"VIP". Attr = 아래 속성 이름 |
| `Config.Looks[id]` | `{ Faction, PassId?, Price?, Name, Icon, Order, Unlock? }` | 판매 4개: `HaloIce`·`HaloGold`·`HornsLava`·`HornsShadow`(PassId·Price 99). 출석 전용 6개: `HaloSprout`·`HornsSprout`(14일)·`HaloStarlight`·`HornsStarlight`(50일)·`HaloPlatinum`·`HornsPlatinum`(100일), `Unlock = { Attendance = N }`, 가격 없음 |
| `Config.LookOrder()` | id 배열 | 상점 순서(Order) |
| `Config.PassBoost` | `{ Mult = 2, GoldSources, CheckTries = 3, CheckWait = 1, SupporterStore, SupporterKey, MaxSupporters = 30, RefreshSeconds = 300, WriteGap = 10 }` | 2배 규칙·확인 재시도·후원자 게시판(공용 목록은 한 사람당 10초에 한 번까지 씀) |

- 치장 id는 이미지 개발의 `Config.LookThemes` 세트 이름과 같아요.
- 출석 전용 이름("Sprout Halo"·"Star Halo"·"Plat Halo" 등, 12자 이하)은 화면 쪽에서 바꿔도 돼요.

## 3. 클라가 읽는 신호

**플레이어 속성(서버만 씀):**

| 속성 | 값 |
|---|---|
| `PassXP2` · `PassGold2` · `PassVIP` | true / false. 들어올 때 마지막으로 저장된 답(`PassSeen`, 판매 중인 패스만)으로 시작하고, Roblox 확인이 끝나면 그 답으로 바뀌어요(검수 2026-10-08) |
| `LooksOwned` | 가진 치장 id. 쉼표로 이어 붙이고 상점 순서예요(출석으로 받은 것 포함). 없으면 "" |
| `LookOn` | 지금 입은 치장 id 또는 "". **내 진영 것만** 보여요(진영을 바꾸면 ""가 되고, 돌아오면 다시 보여요) |

- 다른 플레이어의 속성도 복제돼요. 그래서 이름표 왕관(`PassVIP`)과 치장(`LookOn`)은 모두에게 보여요.

**GameState 속성:**
- `SupporterNames`: VIP 가진 사람 이름을 줄바꿈으로 나눈 목록이에요. 최신순, 최대 30명이에요. 모든 서버가 같은 목록을 써요(DataStore, 5분마다 다시 읽음).
  - 이름 숨김(P5 `HideAnnounceName`)을 켠 사람은 빠져요.
  - 검수 2026-10-08: 올라간 뒤에 숨김을 켜도 이 서버 게시판에서 바로 빠지고, 공용 목록에서도 빠져요. 숨긴 채 다시 들어와도, 환불돼도(Roblox가 "아니요") 빠져요. 숨김을 다시 끄면 VIP는 다시 올라가요.
  - 공용 목록은 한 사람당 `WriteGap`(10초)에 한 번만 써요. 그 사이에 바꾼 건 10초가 끝날 때 마지막 선택으로 한 번 써요(나간 뒤에도). 숨김을 빨리 껐다 켰다 해도 서버 DataStore 예산을 다 쓰지 못해요.
  - 쓰기가 실패하면 `WriteRetries`(3)번까지 10초 간격으로 다시 써요(그 사이 새 선택이 생기면 그걸 써요). 서버가 그 10초 안에 꺼지면 못 쓴 채 끝나요. 그 사람이 다음에 들어올 때 다시 맞춰져요.
  - 이름은 확인된 닉네임(최대 20글자, 80바이트)까지 들어가요.
  - 이 서버에 있는 숨긴 사람은 공용 목록에 아직 남아 있어도 이 서버 게시판에 안 보여요.
  - 이름은 `Util.PlayerDisplayName`(확인된 닉네임 또는 DisplayName)이에요.
  - **검수 2026-10-08(3차):** 닉네임이 나중에 확인되거나 바뀌면(`NicknameVerified`·`Nickname`) 게시판 줄도 바로 바뀌어요. 공용 목록도 바뀌어요(10초 간격 규칙 그대로). 이름이 그대로면 쓰지 않아요.
  - Roblox가 VIP를 아직 "예"라고 확인하지 않은 사람(산 직후 답이 없었던 사람)은 이 서버 게시판에만 올라가요. 숨김을 껐다 켜거나 이름을 바꿔도 마찬가지예요.

**리모트 c→s `SetLook(id)`:**
- 인자는 한 개예요. 가진 치장이면서 내 진영 것인 id, 또는 ""(벗기)만 받아요. 나머지는 조용히 무시해요.
- **중립(Neutral)·진영 없음은 치장을 입을 수 없어요**(후광·뿔이 없어요). 상점은 이들에게 Wear 대신 "Pick a side to wear it" 같은 안내를 보여 주세요. 사는 건 막지 않아요. 나중에 진영을 고르면 입을 수 있어요.
- 0.5초에 한 번이에요. 저장돼요.

**고마움 팝업은 서버 신호가 없어요.** 개발 1의 Passes.luau가 구매 뒤 30초 안에 속성이 false→true로 바뀌거나 `LooksOwned`가 길어지면 띄워요.

## 4. 2배 규칙 (`ProgressionService`)

- `AddXP(player, amount, cap?)`: 모든 경험치 지급이에요.
  - `PassXP2`면 ×2를 한 뒤 `cap`을 적용해요(A23-27의 '신규 플레이어가 대왕을 잡아도 한 레벨치까지'는 2배여도 그대로예요).
  - 실제로 더한 양을 돌려줘요.
- `AddCarriedGold` / `AddBankGold(player, amount, source)`: 아래 출처일 때만 ×2(`PassGold2`)를 하고, 더한 양을 돌려줘요.

**2배가 되는 출처(번 것):** `Monster`(처치), `Quest`(퀘스트·일일·일일 상자·휴가·게시판·스토리), `Event`(거위), `Bounty`(현상금·복수 대행), `War`(전쟁 상자), `Loot`(겹친 무기 골드), `Kaiju`(괴수 처치 보상 중 새로 생기는 몫), `SignOn`(약한 진영 가입 보너스), `Attendance`(A23-77 출석).

**절대 2배가 아닌 출처:** `Sale`(팔기), `Refund`(복수 환불), `Plunder`(뺏기), `KaijuBank`(괴수 생존 때 자기 들고 있던 골드를 은행에 넣는 몫), `KaijuTransfer`(괴수 처치 때 넘겨받는 몫), `KaijuBonus`(괴수 생존 +50% 보너스), `Penalty`, `Other`(테스트 골드), `Choice`(이야기 선택의 골드), `Finisher`(왕 슬라임 마무리 카드 골드, 브랜치 dev2-kingfinish).

- **선택 골드는 2배가 아니에요(검수 2026-10-08, 3차).**
  - 이야기 선택(StoryQuestService `payChoice`)과 마무리 카드의 골드는 2배가 아니에요.
  - 악마 쪽 선택에 골드가 많아요(도시락 One bite 25, M2 금고 192, 마을 선택 60). 2배가 되면 돈을 낸 아이에게 악마 선택이 더 이득이 돼요. GDD §0과 A23-70에 어긋나요.
  - 퀘스트를 끝낸 보상 골드(`GoldN`, `Quest`)는 그대로 2배예요.

- **괴수 생존 보너스(검수 2026-10-08):** 보너스는 주머니 골드의 절반이에요. 주머니는 처치할 때 이미 2배로 받았어요. 그래서 보너스는 다시 곱하지 않고(`KaijuBonus`), **상한만** 2배예요(`HuntValue(레벨, 20분) × PassMult`). 같은 사냥이면 패스가 있는 사람이 보너스를 2배 받아요(4배가 아니에요). 상한에 닿아도 2배예요.

- `GetXPMult` / `GetGoldMult`에는 패스가 없어요. 그래서 두 번 곱해지는 일이 없어요.
- 2배로 얻은 레벨·골드는 레벨 상한과 랭킹에 그대로 들어가요(사용자: "그래야 사지").
- **보상 줄은 실제로 더한 양을 보여 줘요.** 처치 Fx `Reward`(Gold·XP), 퀘스트·일일·상자·휴가·게시판·스토리·거위·현상금·전쟁·괴수·가입 보너스 알림 모두 그래요.
- **골드 모으기 목표도 빨라져요(검수 2026-10-08: 이대로, 2배 패스는 '속도 상품'):** 'Earn gold'·'Hunting gold' 같은 목표(퀘스트·게시판·스토리)는 `GoldEarned`의 더한 양으로 세요. 그래서 2배 골드면 목표가 두 배 빨리 차요. 그 퀘스트 보상 골드는 다시 2배가 되고요. 일일 퀘스트는 하루 개수가 정해져 있어서 하루 총량은 그대로예요. 퀘스트 보상 중 **아이템(주문서·젤리·물약·재료)은 2배가 아니에요**(아이템 지급은 패스를 읽지 않아요, `test_gamepass` 정적 검사).
- **최대 레벨에서** 막대가 꽉 찼으면 `AddXP`는 0을 돌려줘요. 더해지지 않은 경험치는 보상 줄에 안 보여요.
- **미리보기 숫자는 기본값이에요.** 퀘스트 목록·게시판 카드의 `RewardGold`/`RewardXP`는 패스 전 값이에요. 화면에서 2배로 보여 주려면 `PassGold2`/`PassXP2`일 때 `Config.PassBoost.Mult`를 곱하면 돼요(퀘스트는 2배가 되는 출처예요).

## 5. 소유 확인 (`MonetizationService`, 서버에서 MarketplaceService를 쓰는 유일한 곳)

- **들어올 때(PlayerReady):**
  - 판매 중인(Id > 0) 패스·치장마다 `UserOwnsGamePassAsync`를 불러요.
  - 실패하면 1초, 2초를 기다리며 3번까지 시도해요.
  - 답을 받으면 `data.PassSeen`에 저장해요.
  - 3번 다 실패하면 **마지막으로 받은 답(저장값)**을 써요. Roblox 장애 때 산 사람이 손해 보지 않게 하려는 거예요.
  - **검수 2026-10-08:** Roblox 답을 기다리는 동안에도 저장값이 바로 쓰여요(판매 중인 패스만). `PlayerReady` 때 MonetizationService가 먼저 넣어 둬요. 그래서 `PlayerReady` 안에서 주는 보상(QuestService 하루 확인의 끝난 일일·상자 자동 지급, 출석)도, Roblox가 느리거나 멈춘 동안 주는 보상도 2배가 돼요.
  - 환불되면 다음 확인에서 false로 바뀌어요(저장값보다 Roblox 답이 이겨요).
- **산 직후(검수 2026-10-08 3차):** `PromptGamePassPurchaseFinished`(purchased = true)의 값은 클라 쪽 구매 창에서 와요. 그래서 서버가 `UserOwnsGamePassAsync`로 **다시 물어봐요**(같은 3번 재시도).
  - "예": 켜고 저장해요(`PassSeen`). VIP면 공용 후원자 목록에 올리고 `PassBought`를 쏴요. 그 세션에서는 늦게 온 "아니요"가 다시 끄지 않아요.
  - 답이 없음(3번 실패): 이번 접속에서만 켜요. 저장, 공용 목록, `PassBought`는 없고 이 서버 게시판에만 올라가요. 다음에 들어올 때 다시 물어봐요.
  - "아니요": 아무것도 하지 않고 경고(`Util.Warn`)만 남겨요. 위조된 신호예요.
- **Studio에서 산 시험 구매:** `DebugSetPass` 길로 가요.
  - 이번 세션에만 켜지고, 저장되지 않아요(`PassSeen` 없음, 저장본에 `DebugTainted`).
  - 이 서버 게시판에만 올라가고, `PassBought`도 없어요. 메인 Studio는 DataStore가 켜진 진짜 장소이기 때문이에요.
  - Studio의 공용 후원자 목록은 `HaloHorns_Supporters_v1_STUDIO`라는 따로 된 사본을 써요(RankingService의 STUDIO 시즌처럼).
- **Id 0:** 묻지 않고 꺼진 상태예요. 화면은 "Coming soon"이에요.
- **화면이 쓰는 구매 창:** 클라가 `MarketplaceService:PromptGamePassPurchase(player, Id)`를 부르면 돼요. 서버 리모트는 필요 없어요.

## 6. 저장 (덧붙이는 필드만, 버전 3 그대로)

- `Looks = { Owned = { [id] = os.time() }, On = "" }`: Owned는 패스 없이 얻은 치장(출석)이에요.
- `PassSeen = { [kind 또는 치장 id] = true/false }`: 마지막으로 받은 Roblox 답이에요.
- `Config.SanitizeLooks`가 불러올 때 고쳐요. 모르는 id와 깨진 값은 버려요.
- 이전 버전 저장도 그대로 불러와요. 이 묶음만으로는 게시 때 **모든 서버 종료가 필요 없어요**(덧붙이는 필드라 v3 서버도 보존해요).

## 7. 서버 API (다른 서비스용)

- `MonetizationService.HasPass(player, key)`: key는 `XP2`·`Gold2`·`VIP` 또는 판매 치장 id예요.
- `MonetizationService.OwnsLook(player, id)` / `LooksOwned(player)`
- `MonetizationService.GrantLook(player, id)`: **A23-77 출석용**이에요. `Unlock`이 있는 치장만 되고, 새로 얻었을 때 true를 돌려줘요.
- 신호 `MonetizationService.PassBought (player, key)`: 진짜 구매 한 번마다 한 번 쏴요. 패스가 켜진 뒤에 쏴요. key는 kind 또는 판매 치장 id예요. 들어올 때 확인·Studio 덮어쓰기·Id 0에는 안 쏴요(개발 3의 측정 PassShop Bought용).

## 7-1. 개발 3에게 (A23-77 출석·A23-79에서 2배를 쓸 때)

- **골드:** `S.ProgressionService.AddBankGold(player, amount, "Attendance")`(또는 `AddCarriedGold`). 출처 `"Attendance"`는 `Config.PassBoost.GoldSources`에 이미 있어요.
  - 2배는 함수 안에서 한 번만 곱해져요. **부르는 쪽에서 곱하지 마세요.**
  - 돌려받은 값이 실제로 더한 양이에요. 알림에는 그 값을 쓰세요.
  - 새 출처가 필요하면(번 것이면) `GoldSources`에 한 줄 더하면 돼요. 옮겨지는 골드는 넣지 마세요.
- **경험치:** `S.ProgressionService.AddXP(player, amount)`. 경험치는 모두 2배 대상이에요. 돌려받은 값을 표시하세요. 세 번째 인자 `cap`을 주면 2배 뒤의 최대치예요.
- **들어올 때(`PlayerReady`) 주는 출석 보상(검수 2026-10-08):** 저장된 패스 답이 그때 이미 적용돼 있어야 2배가 돼요. MonetizationService가 `PlayerReady`에 먼저 연결돼 있어서 돼요(Main `INIT_ORDER`에서 앞). 출석 서비스는 `INIT_ORDER`에서 **MonetizationService 뒤**에 넣으세요. `task.spawn`이나 `task.defer`로 미루지 않아도 돼요.
- **패스 확인이 따로 필요할 때:** `S.MonetizationService.HasPass(player, "XP2" | "Gold2" | "VIP")`(서버의 진짜 값)이에요. 배수 값은 `S.ProgressionService.PassMult(player, "XP2" | "Gold2")`(1 또는 2)예요. 플레이어 속성(`PassXP2` 등)은 화면용이라 서버 판단에 쓰지 마세요.
- **출석 치장(14·50·100일):** `S.MonetizationService.GrantLook(player, "HaloSprout")` 등이에요(`Config.Looks`에서 `Unlock.Attendance`가 있는 id만). 진영에 맞는 쪽을 골라 주세요.
- **Config / DataService:** 이 묶음의 표는 `Config.luau`의 `----- A23-75 game passes` 블록 하나(`GamePasses`·`PassBoost`·`Looks`·`LookOrder`·`SanitizeLooks`)와 `Defaults`의 `Looks`·`PassSeen` 두 줄, `DataService.fillDefaults` 끝의 `SanitizeLooks` 한 줄이에요. 출석 표·필드는 따로 블록으로 두면 겹치지 않아요.

## 8. Studio 테스트 키 (DebugCommand, Studio 전용)

- `DebugCommand:Invoke("Player1", "Pass", "XP2:on")`: on / off / clear(Roblox 답으로 되돌림)이에요.
  - 이번 세션에만 적용돼요. 저장되지 않고 공용 후원자 목록에도 안 올라가요(이 서버 게시판에만 보여요).
  - `Gold2`, `VIP`, 판매 치장 id도 돼요.
- `DebugCommand:Invoke("Player1", "LookGrant", "HaloSprout")`: 출석 치장을 열어요(저장돼요).
- 모든 DebugCommand와 마찬가지로 그 저장본에 `DebugTainted`가 붙어서 정식 랭킹에 안 들어가요.

## 9. 게시할 때 (사용자, `docs/design/launch_ops_checklist.md`)

1. create.roblox.com → 게임 → Monetization → Passes에서 패스 7개를 만들어요.
   - 2x XP 199, 2x Gold 149, VIP 249, 치장 4개 각 99
   - 아이콘은 이미지 생성 2가 만든 512 그림이에요.
2. 각 Id를 `Config.GamePasses[Kind].Id`와 `Config.Looks[id].PassId`에 붙여 넣어요.
3. 개인 서버: Creator Dashboard에서 켜고 한 달 100 Robux로 해요(코드 없음).

## 10. 화면 몫 (개발 1·이미지 개발 1)

- **상점 탭:** 패스 카드 4개(4번째는 개인 서버 안내 카드), 치장 칸(판매품 + `LooksOwned`에 있는 출석 치장, Wear = `SetLook`)이에요. Id 0이면 "Coming soon"이에요.
- **상태 칩:** 상태 칩 '2x XP / 2x Gold'(속성)이에요.
- **VIP:** 이름표 왕관(이미지 개발, `CharacterVisuals`의 `PassVIP`), 채팅 VIP(개발 1, main 6aa5ba1), 전용 감정 표현(클라에서 `PassVIP` 확인), 후원자 게시판 글자판(`SupporterNames`)이에요.
- **치장 겉모습:** 이미지 개발 `LookThemes`가 `LookOn`을 읽어 계급 메시의 TextureID만 바꿔요.

## 11. 한계

- MarketplaceService·DataStore·플레이어는 오프라인 대역이에요.
- 실제 패스 Id, 구매 창, 여러 서버 사이의 후원자 목록은 사용자가 패스를 만든 뒤 Studio·게시 시험에서 확인해야 해요.
- 지급하는 곳(`tools/test_gamepass.py` EXPECTED 목록) 중 `ProgressionService`와 괴수 생존(`KaijuService` survive) 바깥은 소스 글자로 확인했어요(출처, 표시 금액이 실제로 더한 양인지). 직접 돌리지는 않았어요.
- 같은 패스 Id를 두 칸에 넣으면 한 번 사서 둘 다 켜져요. 서버가 시작할 때 경고만 해요.
  - 예외: 괴수 생존 보상(`KaijuService` survive)은 함수를 꺼내 진짜 ProgressionService 위에서 돌려요(검수 2026-10-08). 괴수 이벤트 나머지는 대역이에요.
