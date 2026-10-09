# 상점(Shop) 화면 배치 — 이미지 개발 1 (2026-10-08, SPEC A23-75)

검수 OK(10/08): 나눔, 카드 4장 = 2x XP · 2x Gold · VIP · 개인 서버 안내. 치장은 그림을 고른 뒤 Shop 안 따로 칸.
코드: `src/StarterPlayer/StarterPlayerScripts/ShopUI.luau`(새 창, Panels.Register "Shop"), HUD [Menu] 펼침 칸, HUD 상태 칩, `CharacterVisuals.luau` 이름표 왕관. 오프라인 시험: `py tools/test_shop_layout.py`(게임 글꼴로 글자 맞춤 + 시안 그림 → `docs/art/verification_2026-10-08/shop_layout_offline_2026-10-08.*`).

## 1. 들어가는 곳
- [Menu] 펼침 칸 맨 앞(새 소식 왼쪽)에 **Shop** 칸. 아이콘은 그려질 때까지 `IconCoin`.
- 창 제목 "Shop", 제목 띠 아이콘도 `IconCoin`(Panels FRAME.Icons.Shop).
- 팝업·시간 제한·"최고 가치" 딱지 없음(A23-75 강요 없음). 창은 플레이어가 열 때만 열린다.

## 2. Shop 창 (PC·폰 같은 배치, 창 780 du 너비)
- **패스 카드 4장을 한 줄로.** 폰(749×361)에서도 한 화면에 다 보이고 스크롤이 없다(카드 175.5 du = 폰 132 px). 칸 너비는 몫보다 1 du 작게(UiSandbox 10/08: 정수 픽셀로 반올림되면서 4번째 카드가 안 보이는 둘째 줄로 밀렸음).
- 카드 하나 = 누르는 곳 하나(카드 전체). 위에서부터:
  - 그림 92 du. **고른 둥근 배지(A23-75 '배지 B')가 올라오면 배지만 보인다**(배지에 테두리가 있어서 사각 칸을 빼요). 그 전에는 테두리 칸 + 대신 그림(칸의 62 %): 2x XP·2x Gold = `RewardSlot`(금), VIP = `SlotLegendary`(왕관 달린 금), 개인 서버 = `SlotRare`(파랑).
  - 이름(Title 글꼴 22 du, 긴 이름은 12 px까지 줄어듦) — "2x XP", "2x Gold", "VIP", "Private Server".
  - 설명 최대 3줄(Body, 최소 크기 StyleMinPx 11 → 폰 15 px·720p PC 14 px; Body 기본 바닥은 폰에서 19 px라 4줄로 넘침) — "Level up twice as fast!", "Get twice the gold!", "Crown name tag, VIP chat and emote.", "Play with just your friends."
  - 아래 캡슐 버튼(40 du, 글자 22 du = 폰 16.5 px): 금 "199 R$" = 사기 / 초록 "Owned" / 흐린 "Coming soon"(패스 Id 0인 동안) / 개인 서버는 파랑 "100 R$ / mo".
- 누르면: 사기 → Roblox 구매 창(MarketplaceService:PromptGamePassPurchase, 확인은 Roblox 창이 함). 가졌으면 "You already have this!". Id 0이면 "Not on sale yet. Check back soon!". 개인 서버는 게임 안에서 살 수 없어서 "Get a private server on the game page: open Servers, then Create."
- (2026-10-09 더함, A23-90) 개인 서버 카드에 `Config.PrivateServer.Text` "Rewards are halved in private servers" 한 줄(거위·왕관전 상자·현상금 보상 절반). 10/09 기준 ShopUI에는 아직 없음.
- 창이 막 열린 0.35 s 동안은 카드 누름을 무시(메뉴 칸 두 번 누름이 카드에 떨어지지 않게).
- **치장(Looks)**: Config.Looks에 하나라도 있으면 "Looks for <진영 이름>" 제목(왼쪽에 치장 묶음 배지 `IconPassLooks`, 올라오면) + 칸 4개씩(패스 카드와 같은 너비, 테두리 `SlotEpic` 84 du, 이름 한 줄, 캡슐 "99 R$" / "Wear" / "Wearing"). 다시 누르면 벗기. 없으면 칸 자체가 안 보인다. 사용자 고름(10/08): 후광 **Ice Halo · Gold Halo**, 뿔 **Lava Horns · Shadow Horns**(모양은 계급 그대로, 색만). 이름은 12자 이하.
- 바꾸기 표(직업·진영) 줄: 표 상품 Id가 생기면 맨 아래에 나온다(10/07 결정 그대로).
- 맨 아래 한 줄: "Always ask a grown-up before you buy."

## 3. 2x 상태 칩
- 위 가운데 상태 칩 줄에 금색 칩 하나: "2x XP" / "2x Gold" / 둘 다면 "2x XP · Gold". 아이콘은 경험치 별(골드만이면 금화 더미).
- 순서: 위험 칩 바로 다음(Zone · Luck · Bully · Wanted · Combat · **Boost** · Rookie · Protected · Blessing · Size · Kaiju). UiSandbox 10/08: 보호 칩 뒤에 두니 마을에서 늘 '+N'으로 접혀서 산 사람이 못 봤음. 자리가 모자라면 다른 칩처럼 '+N'으로 접힌다(PC 3개, 폰 2개: 마을의 폰은 Zone·Luck 다음이라 접힘).

## 4. VIP 왕관 (이름표)
- 이름표 첫 줄 "[칭호] 이름" **바로 왼쪽**. 높이 = 이름 글자 크기의 0.8, 너비 = 그림 비율, 첫 글자와 3 px. 왕관+이름이 한 묶음으로 가운데.
- 긴 이름은 TextScaled로 줄어드는데, 왕관도 같이 줄고 따라 움직인다. 서버는 왕관(숨김)과 여백만 넣고, **각 화면(클라이언트)이 자기 화면에 그려진 이름 폭(TextBounds)으로 크기·자리를 맞춘다**(ShopUI). UiSandbox 10/08: 서버가 잰 폭은 화면 글꼴과 달라서 왕관이 "[S" 위에 겹쳤음.
- 그림: `IconVipCrown`이 생기면 그것, 없으면 지금 승인된 `Crown`.
- 자기 이름표는 자기에게 안 보인다(2026-10-06 결정 그대로) — 다른 사람 화면에서 보인다.

## 5. 서버가 주는 것 (게임성 개발 2, docs/design/gamepass_server_2026-10-08.md에서 확정)
- `Config.GamePasses[Kind] = { Id, Price, Name, Attr }`, Kind = XP2 · Gold2 · VIP.
- Player 속성(bool): `PassXP2` · `PassGold2` · `PassVIP`. 치장: `LooksOwned`("a,b"), `LookOn`(입은 id 또는 "").
- `Config.Looks[id] = { Faction = "Halo"|"Horns", PassId, Price, Name, Icon = Config.UIArt 키, Order }` — id = 세트 이름(개발 2 확정): 판매 HaloIce · HaloGold · HornsLava · HornsShadow(PassId, Price 99), 출석 전용 HaloSprout · HornsSprout(14일) · HaloStarlight · HornsStarlight(50일) · HaloPlatinum · HornsPlatinum(100일)은 `Unlock = { Attendance = N }`(팔지 않음). Shop의 Looks 칸은 **판매품 + 이미 가진 것**만 보여 준다(출석 치장은 받은 뒤 여기서 입기).
- 입은 치장 = 계급 장식(후광·뿔) 메시의 TextureID만 세트 텍스처로(`Config.LookThemes`, 이미지 생성 2 dd217fc, R1·R2는 64 px 색판 하나), 후광 빛 = Glow, R5 반짝이 = Sparkle. 모양은 계급 그대로(산 모양 ≠ 번 모양).
- 입기 리모트 `SetLook`(id, ""면 벗기) — Net.Names에 생기기 전에는 화면이 "Coming soon"만 띄운다.
- 화면이 쓰는 이름은 Config에서 읽고, 없으면 위 제안 이름을 쓴다.

## 6. 필요한 그림 (이미지 생성 2, 검수 통해) — 생기기 전에는 괄호 안 그림을 대신 씀
(2026-10-09 검수: `IconPassXP2`·`IconPassGold2`·`IconPassVIP`·`IconPassLooks`·`IconPrivateServer`는 `Config.UIArt`에 들어감. `IconShop`·`IconVipCrown`은 아직 없음.)
| 키 | 어디 | 크기·주의 |
|---|---|---|
| `IconShop` | [Menu] Shop 칸, 창 제목 띠 | 512, 메뉴 칸 안 60 %에서 읽혀야 함 (`IconCoin`) |
| `IconPassXP2` | 2x XP 카드 | 고른 '경험치 2배 B' 둥근 배지 512 (`IconExp`) |
| `IconPassGold2` | 2x Gold 카드 | 고른 '골드 2배 B' 512 (`IconGoldPile`) |
| `IconPassVIP` | VIP 카드 | 고른 'VIP 왕관 B' 512 (`Crown`) |
| `IconPassLooks` | Looks 칸 제목 왼쪽 | 고른 '치장 묶음 B' 512 (없으면 글자만) |
| `IconPrivateServer` | 개인 서버 카드 | ~~**새로 필요**~~ → 있음(`Config.UIArt.IconPrivateServer`, 이미지 생성 2 c5150fa): 같은 둥근 배지 틀, 친구끼리 노는 느낌(초록이나 하늘색 바탕) (`IconTravel`) |
| `IconVipCrown` | 이름표 왕관 | 256, **18 px 높이에서도 읽히게** 굵은 테두리·단순한 모양, 가로로 넓은 비율 OK (`Crown`) |
| 치장 아이콘 | Looks 칸 | 512, 진영별 후광·뿔 그림(사용자가 고른 뒤) |

모든 아이콘: 투명 배경, 글자 없음, 햇살·부채꼴 빛줄기 무늬 금지(10/07 규칙).
