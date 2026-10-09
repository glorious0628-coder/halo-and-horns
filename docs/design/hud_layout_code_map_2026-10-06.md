# HUD 배치 코드 지도 (이미지 개발, 2026-10-06)
> 기록용(10/06 당시). 지금과 다른 점: HUD 배치는 A23-74(PC·폰 같은 틀)·A23-81·A23-94(퀘스트 = 왼쪽 가운데 큰 글씨, 지금 퀘스트 하나)·A23-98(UI는 PC 먼저)로 바뀌었고, 아래 줄 번호·크기 값·§6 계획은 낡음 — 지금 `HUD.luau`·`UIKit.luau`를 볼 것.
> 지금 기준: AGENTS.md · SPEC_ADDENDUM A23 · RELEASE_PLAN.

회색 상자 배치 승인본이 오면 바로 `HUD.luau`로 옮기기 위한 메모. 읽기만 해서 만든 지도이고 코드는 아직 안 바꿨다.
측정: 연습 Studio(`build/UiSandbox.rbxlx`)에서 `py tools/device_view.py pc phone`(아래 "도구").

## 1. 단위와 배율
- HUD 숫자는 전부 **논리 단위**(MainGui `UIScale` 적용 전). 실제 px = 논리 × s.
- s(UIScale)는 `UIKit.luau:247-256` `applyScale`:
  - 터치: `clamp(화면높이/720, 0.75, 1.25)` → 폰 749×361은 **0.75**(하한).
  - 마우스: `clamp(화면높이/720 × 0.8, 0.6, 1.0)` → PC 1280×720은 **0.8**.
  - 값은 `Config.UI` (`Config.luau:2155-2160`, ScaleMin/Max, DesktopScaleMult/Min/Max).
- 상단바 inset: `GuiService:GetGuiInset().Y` = 실제 58px(두 화면 모두). MainGui는 inset을 무시하므로 `applyLayout`이 `shift = inset / s`, `minTop = (inset + 8) / s`로 내린다(`HUD.luau:3313-3315`).
- 폰 749×361 장치는 안전 영역 때문에 실제 게임 화면이 **655×340**(좌우 47, 아래 21 빠짐) → 논리 873×453.
- PC 1280×720 → 논리 1600×900.
- 회색 상자 JSON(`tools/render_graybox.py` 형식: `pc:{x,y,w,h}`, `phone:{x,y,w,h}`)이 실제 px라면 옮길 때 `÷ s`. 폰 좌표가 749 기준인지 655(안전 영역) 기준인지 검수에 확인할 것.

## 2. 크기 상수 — `L` 표 (`HUD.luau:48-81`)
| 키 | PC | 터치 | 쓰는 곳 |
|---|---|---|---|
| Attack / Release | 120 / 90 | 136 / 102 | 둥근 공격·스킬 버튼 지름 |
| Square | 60 | 72 | 자동·지도·메뉴 네모 버튼 |
| UpgradeH | 72 | 78 | 다음 무기 카드 높이(폭 = 3×Square + 2×RowGap) |
| BtnGap / RowGap / Edge | 10 / 8 / 16 | 12 / 10 / 24 | 버튼 사이, 줄 사이, 화면 가장자리 |
| StatsW / StatsH | 300 / 132 | 212 / 110 | 상태판(높이는 `L.LayoutStats`가 다시 계산) |
| PotionH | 50 | 64 | 물약 2칸 줄 |
| StarsH | 20 | 22 | 뿔 현상수배 별 줄(상태판 아래에 붙음) |
| QuestW / QuestRowH / QuestHeaderH | 270 / 50 / 28 | 260 / 58 / 32 | 퀘스트 판 |
| OverlayW | 340 | 340 | 터치 퀘스트 펼침 창 |
| WarW / WarH / WarMinW | 380 / 56 / 200 | 같음 | 전쟁 미터 |
| ChipsY / ChipH | 106 / 24 | 106 / 26 | 상태 칩 줄 |
| LuckY / LuckH / LuckW | 52 / 58 / 210 | 같음 | EventHUD 행운판 자리(대체값) |
| StickZoneX | 0.4 | 0.4 | 터치 조이스틱 자리(왼쪽 40%) |
| TouchText | 15 | 15 | 터치 글자 최소(0.75배 → 11px) |
| Row.* | 30/15/40/18/58/15/13 | 40/20/56/22/72/18/15 | 퀘스트 줄 안쪽(배지·교체·버튼·보상·바·글자) |

200 지역변수 한도 때문에 새 상수는 `L` 표 안에 넣는다.

## 3. 요소별 — 만드는 곳 / 자리 정하는 곳 / 지금 측정값(실제 px)
| 요소(Name) | 만드는 곳 | 자리 정하는 곳 (`applyLayout` `HUD.luau:3297-3440`) | PC 1280×720 | 폰 749×361(655×340) |
|---|---|---|---|---|
| 상태판 `Stats` | `buildStats` 717 (레벨 배지 729, 초상 787(PC만), 이름·직업 823-846, XP 852, 금고·주머니 866-873, HP/MP는 `VitalsUI.BuildStats`) | 3318-3322: x=12, y=max(12+shift, minTop, PC 채팅창 아래); 내부 줄 높이 `L.LayoutStats` 923-973 | 10,67 240×106 | 9,67 159×98 |
| 물약 `Potions` | `VitalsUI.BuildPotions` (VitalsUI.luau:110), HUD 876에서 호출 | 3351: 상태판 바로 아래 +4 | 10,177 240×40 | 9,167 159×48 |
| 퀘스트 `Quests` | `buildQuests` 1247 (머리 1264, 줄 `makeQuestRow` 2368, 줄 배치 `L.LayoutQuestRow` 2335) | 3352: 상태판 아래 + PotionH + 10 | 10,222 216×66 | 9,220 195×24 |
| 터치 퀘스트 창 `QuestOverlay` | 1316 | 3355-3360: 조이스틱 칸 오른쪽, 위쪽 | — | 열 때만 |
| 전쟁 미터 `WarMeter` | `buildWar` 1000 (방패 1098, 왕관 1068, 알약 1124-1127) | 3323-3342: 가운데, 폭은 상태판·행운판 사이에 맞춤 → `HUD.TopCenterX/W` 공개 | 488,66 304×45 | 210,66 285×42 |
| 상태 칩 `StatusChips` | `buildChips` 1210 | 3345-3347: 전쟁 미터 열, EventHUD 띠 아래 | 256,148 768×24 | 210,143 285×24 |
| 이동 바 `Travel` | `buildTravel` 1385 | 만들 때 고정(화면 0.5, PC 0.6 / 터치 0.42) | 숨김 | 숨김 |
| 공격 `Attack` | `buildButtons` 1549 | 3364-3397: 터치 = 점프 버튼 왼쪽 위, PC = 오른쪽 아래 모서리 | 1090,610 96×96 | 449,213 102×102 |
| 스킬 `Release` | 1574 | 3398-3405: PC = 공격 오른쪽, 터치 = 공격 왼쪽 | 1194,634 72×72 | 363,239 77×77 |
| 지도·메뉴·자동 `Map/Menu/Auto` | `squareButton` 1511, 1614-1630 | 3407-3419: 오른쪽 정렬 한 줄. PC = 행운판 아래 기둥, 터치 = 공격 위 | 1167/1222,182 48×48 | 530/592,150 54×54 |
| 다음 무기 `Upgrade` | 1634-1701 | 3420: 네모 줄 바로 위 | 1113,118 157×58 | 469,84 177×59 |

`HUD.Layout = { W, H, Scale, ClusterTop, ClusterLeft, TopCenterX, TopCenterW }`(3431)은 오른쪽 아래 버튼 묶음의 위·왼쪽 끝이다. 배치를 바꿔도 이 값은 계속 채운다.

## 4. 다른 파일이 HUD 자리를 따라가는 곳 (배치를 바꾸면 같이 확인)
- **EventHUD.luau**(게임성 개발 파일, 읽기만):
  - `EventStrip`(호박 대왕·거위 띠): `WarMeter` 아래 + `HUD.TopCenterX/W` 폭(855-914).
  - `LuckCorner`(행운판, PC 오른쪽 위): `LUCK_Y`, `BottomY` 속성을 HUD가 읽어 오른쪽 기둥을 그 아래에 둔다(HUD 3332, 3383).
  - `Personal` 줄: PC는 `ClusterTop` 위, 터치는 `StatusChips` 아래(887-903).
- **GrudgeGhost.luau**: `HUD.Layout`의 버튼 묶음 왼쪽.
- **UIKit 토스트**: 위 가운데 `TOAST_Y = 152` + inset(`UIKit.luau:65`).
- **VitalsUI**: 상태판 안 HP/MP 줄(`LayoutStats`)과 물약 칸 모양.

## 5. 지금 보이는 배치 문제 (측정 + 캡처 `build/device_view/{pc,phone}.jpeg`)
1. 폰: 물약(y 167-215)과 퀘스트 줄(y 220-244)이 조이스틱 자리(왼쪽 40% × 아래 45%, y≥187)에 들어간다. 검수 지적과 같다.
2. 폰: 전투력은 상태판 안 금고 아래 줄(BB5). `+N` 팝업(`L.PowerPopup` 645)이 바로 위 금고 줄로 22 올라가며 덮는다.
3. 폰·PC: 호박 대왕 띠(EventHUD)가 상태판 오른쪽에 걸쳐 일부 가려진다. 핼러윈 커밋에서 게임성 개발이 고친다.
4. 좁은 PC 창(791×475, s 0.6): 다음 무기 카드 글자가 오른쪽에서 잘린다("무기 선택 · 구매 · 판"). 1280×720에서는 다 보인다.
5. 계획 배치(`visual_direction` "화면 배치")와 다른 점:
   - 지금 퀘스트는 왼쪽 아래(상태판 밑)인데, 계획은 **오른쪽 가운데**.
   - 지금 물약은 상태판 밑인데, 계획은 **공격 버튼 왼쪽**(72).
   - 계획은 **오른쪽 위 [가방][지도][메뉴]**인데, 지금은 [자동][지도][메뉴]가 다음 무기 카드 밑에 있다. [가방]은 아직 HUD에 없다(BB7/BB13 메뉴 화면은 게임성 개발).
   - 계획은 공격 150 / 스킬 96 / 물약 72 / 메뉴 64인데, 지금 PC는 공격 96 / 스킬 72 / 네모 48(실제 px)이다.

## 6. 승인본이 오면 옮기는 방법 (계획)
1. 승인 JSON의 항목 id → 위 표의 요소에 짝을 짓는다. 새 요소([가방] 등)가 있으면 게임성 개발과 누가 만드는지 먼저 정한다(창 기능은 게임성 개발, HUD 버튼 자리·모양은 이미지 개발).
2. `L` 표에 `Slots = { PC = {...}, Touch = {...} }`를 넣는다(논리 단위, 화면 가장자리 기준 앵커). 화면 크기가 바뀌어도 맞도록 "오른쪽에서 몇, 아래에서 몇"으로 적는다.
3. `applyLayout`의 위치 계산만 슬롯을 읽게 바꾼다. 터치 점프 버튼 기준(H5), inset·minTop, `HUD.Layout`/`HUD.TopCenterX/W` 공개는 그대로 둔다.
4. 높이 560 미만 규칙(퀘스트 1줄 접기, 스킬 부채꼴, 행운판 칩 줄로)은 슬롯 표에 `Short` 변형으로 둔다.
5. 확인: `py tools/device_view.py pc phone 844` → 캡처를 회색 상자 그림과 겹쳐 비교, 겹침·조이스틱 자리 침범 0.

## 도구
- `py tools/device_view.py pc|phone|844 [...] [--faction Horns] [--out <폴더>] [--keep]`
  - 연습 Studio에서 기기 흉내(StudioDeviceSimulatorService)를 켜고 Play를 시작한다.
  - 서버에서 진영·직업 선택 상태와 인트로 끝을 만든다. 그다음 화면 캡처(`.jpeg`)와 MainGui 판 사각형(`.json`)을 저장한다.
  - 끝나면 기기 흉내를 끈다(default).
  - game.Name에 `UiSandbox`가 없으면 아무것도 바꾸지 않는다. 메인 Studio는 건드리지 않는다.
