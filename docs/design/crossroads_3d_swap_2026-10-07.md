# 교차로 3D 바꾸기 자리 표 (이미지 생성 1, 2026-10-07 밤)

검수 요청(10/07 21:3x): "교차로 소품 표지판(Kit_M_SignPost)·가로등(Kit_X_Lamp, 가져오기 후) 배치 자리 표 — 메인 Studio는 건드리지 않음, 개발 1이 넣음".

- **자리 출처:** 커밋된 장소 `place/GoodEvil.rbxlx`(ce27afa, 10/07 14:06)의 `Workspace.Map.Decor.CrossroadsKit` 37개(옛 21종 키트 K_*, `tools/worldkit/crossroads_kit_main.luau`가 놓은 것). 메인은 그 뒤에 바뀌었을 수 있으니 **이름으로 찾아서** 그 자리를 쓰세요(표의 좌표는 확인용).
- **놓는 규칙(모두 같음):** 가져온 Tripo 모델은 피벗 = 밑면 가운데, 앞 = -Z. 광장 바닥 y = 0.
  `model:PivotTo(CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(0, 0, 0)))` — 앞이 분수(광장 가운데)를 봄. 크기는 가져온 그대로(스터드).
- **옛 K_ 모델은 지우지 말고** `ServerStorage`로 옮겨 보관(meadow_kit_swap.luau·crossroads_kit_main.luau와 같은 방식). 계약 파트(Landmarks.Fountain·Altar·GoosePerch·ArtisanGuild.Anvil·MarketSign·MostWantedBoard·패드)는 그대로 두고 보이는 부분만 바꿈.
- 새 3D는 가져오기 뒤 `ServerStorage.WorldKit3D`에 있어야 함(`tools/build_kit_from_ids.py`). 아직 안 가져온 묶음(C1·C2·D1·D2)은 그 묶음이 들어온 뒤에.

## 1. 새로 놓기 — 표지판 Kit_M_SignPost (업로드됨, 4.56 × 1.19 × 6.0)
광장에서 나가는 길 3곳, 길 가장자리(길 폭 16 → 길 가운데에서 11 떨어짐), 앞이 광장 쪽:

| 길 | 자리 (x, z) | 바라보는 쪽 | 왜 여기 |
|---|---|---|---|
| 북쪽(빛 마을) | (11, -70) | 분수(남쪽) | 가판대(-12..-47, -20..-53)·빛 깃대(±12, -60)보다 바깥, 길 동쪽 |
| 남쪽(뿔 마을) | (-11, 70) | 분수(북쪽) | 뿔 깃대(±12, 60)·화로(±15, 60)보다 바깥, 길 서쪽 |
| 동쪽(초원·순간이동 패드) | (86, -11) | 분수(서쪽) | 패드(52~76, -32~32) 지나서 초원 가는 길 북쪽 |

초원 입구(Gate_SlimeMeadow (200, -10)) 쪽 표지판은 검수의 초원 장식 바꾸기(⑥)에서.

## 2. 바꾸기 — 옛 K_ → 새 Tripo

| 옛 | 개수 | 자리 (x, z) — 커밋된 장소 | 새 3D | 묶음 / 상태 | 새 크기 폭 × 깊이 × 높이 | 메모 |
|---|---|---|---|---|---|---|
| K_Fountain | 1 | (-0.01, -0.02) → **(0, 0) lookAt 없이 `CFrame.new(0, 0, 0)`** | Town_Halo_Fountain (② 분수) | 가져오기 A (1_first) | 21.0 × 20.89 × 16.3 | Landmarks.Fountain은 계약(분수 빛·퀘스트) — 지우지 말고 옛 파트만 투명·CanCollide false(crossroads_kit_main.luau 방식) |
| K_CrownShard | 1 | (0, -0.01) | 그대로 | — | — | 이야기 조각, 새 분수 꼭대기(16.3)보다 위 23.4에 떠 있어 그대로 둠 |
| K_Bench | 4 | (-17.99, -17.99); (17.99, -17.99); (-17.99, 17.99); (17.99, 17.99) | Kit_X_Bench | 가져오기 C1 (2_second) | 6.5 × 3.12 × 4.31 | 분수를 바라보게 |
| K_Lamp | 8 | (-12.21, -29.61); (-12.2, 29.62); (-29.62, -12.2); (-29.61, 12.21); (12.2, -29.62); (12.21, 29.61); (29.61, -12.21); (29.62, 12.2) | Kit_X_Lamp | 가져오기 C1 (2_second) | 5.1 × 2.81 × 11.0 | 옛 K_Lamp 4개에 붙은 PointLight는 새 등의 등불 쪽으로 옮김(지도 빛 예산 40) |
| K_StallRed | 2 | (-12.19, -52.79); (-46.69, -20.31) | Kit_X_StallRed | 가져오기 C1 (2_second) | 10.0 × 7.48 × 12.91 | 옛보다 3스터드 높음 |
| K_StallBlue | 1 | (-22.39, -42.7) | Kit_X_StallBlue | 가져오기 C2 (2_second) — 10/08 | 10.0 × 7.48 × 12.91 | 빨강 가판대에서 차양만 파랑으로(0포인트) |
| K_StallGreen | 1 | (-36.6, -34.52) | Kit_X_StallGreen | 가져오기 C2 (2_second) — 10/08 | 10.0 × 7.48 × 12.91 | 차양만 짙은 초록으로(0포인트) |
| K_Potion | 1 | (11.98, -40) | Kit_X_PotionCart | 가져오기 C1 (2_second) | 5.73 × 4.25 × 7.5 |  |
| K_Guild2 | 1 | (44.08, 59.77) | X_GuildHall | 업로드됨(3a, id 138481942116141) | 24.0 × 23.91 × 22.48 | 옛(높이 16.2)보다 6스터드 높음 |
| K_Gear | 1 | (44, 48.59) | **빼기**(검수 OK 10/08) | — | — | X_GuildHall 앞면에 크리스털 박힌 큰 금 톱니·톱니 깃발·간판이 이미 있음 |
| K_Anvil | 1 | (39, 44.99) | Kit_X_Anvil | 가져오기 C2 (2_second) | 4.5 × 3.61 × 4.15 | ArtisanGuild.Anvil 계약 파트는 그대로(투명) |
| K_Forge | 1 | (49, 44.99) | Kit_X_Forge | 가져오기 C2 (2_second) | 6.0 × 5.88 × 6.92 |  |
| K_Altar | 1 | (-0.01, 44.99) | X_Altar (HD) | 가져오기 D1 (3_third) | 9.0 × 8.55 × 7.83 | Landmarks.Altar + AltarPrompt 계약은 그대로(투명) |
| K_Brazier | 2 | (-15.01, 60.01); (14.99, 60.01) | Kit_X_Brazier | 가져오기 C2 (2_second) | 3.8 × 3.8 × 4.0 | 옛 화로 1개의 PointLight 옮김 |
| K_Nest | 1 | (-30.01, 29.96) | X_GooseNest (HD) | 가져오기 D2 (3_third) | 12.0 × 11.11 × 7.57 | Landmarks.GoosePerch 계약은 그대로 |
| K_MarketArch | 1 | (-26.98, -27) | X_MarketArch (HD) | 가져오기 D2 (3_third) | 12.0 × 2.91 × 10.36 | 아치는 길을 가로지르게 — 앞이 분수 쪽 |
| K_PoleHalo | 2 | (-12.01, -60.01); (11.99, -60.01) | Kit_X_BannerHalo | 가져오기 C1 (2_second) | 5.54 × 2.14 × 14.0 | 북쪽 길(빛 마을) 양옆 |
| K_PoleHorns | 2 | (-11.98, 60.01); (12.02, 60.01) | Kit_X_BannerHorns | 가져오기 C1 (2_second) | 5.66 × 1.79 × 14.0 | 남쪽 길(뿔 마을) 양옆 |
| K_NoticeBoard2 | 1 | (-57.47, -0.01) | X_NoticeBoard (HD) | 가져오기 D2 (3_third) | 16.0 × 7.04 × 15.44 | MostWantedBoard 계약(SurfaceGui)은 새 게시판 판 앞에 맞춤 |
| K_PadBase | 3 | (51.99, -24.01); (51.99, 23.99); (67.99, 23.99) | X_PadBase | 업로드됨(3a, id 76623876473099) | 12.0 × 12.09 × 5.19 | 옛(3.1)보다 2스터드 높음 → 패드 TopY 속성(MapBuilder.placePad) 다시 맞추기 |
| PlazaCurb/Curb | 16 | 반지름 28.5, 각도 -156, -144, -132, -120, -60, -48, -36, -24, 24, 36, 48, 60, 120, 132, 144, 156 (도, x축에서 z쪽으로) | Kit_X_Curb | 가져오기 C2 (2_second) | 6.0 × 2.78 × 1.48 | 길 4곳(0·90·180·270도)은 비움. 각 조각도 분수를 보게 놓으면 길이 방향이 둘레를 따라감 |

## 3. 개발 1이 붙여 쓸 자리 데이터 (Luau)
```lua
-- 교차로 Tripo 자리(커밋된 장소 14:06). 밑면 y = 0, 앞은 분수(0, 0, 0)를 봄.
local CROSS_SWAP = {
	{ old = "K_Bench", new = "Kit_X_Bench", at = { {-17.99, -17.99}, {17.99, -17.99}, {-17.99, 17.99}, {17.99, 17.99} } },
	{ old = "K_Lamp", new = "Kit_X_Lamp", at = { {-12.21, -29.61}, {-12.2, 29.62}, {-29.62, -12.2}, {-29.61, 12.21}, {12.2, -29.62}, {12.21, 29.61}, {29.61, -12.21}, {29.62, 12.2} } },
	{ old = "K_StallRed", new = "Kit_X_StallRed", at = { {-12.19, -52.79}, {-46.69, -20.31} } },
	{ old = "K_StallBlue", new = "Kit_X_StallBlue", at = { {-22.39, -42.7} } },
	{ old = "K_StallGreen", new = "Kit_X_StallGreen", at = { {-36.6, -34.52} } },
	{ old = "K_Potion", new = "Kit_X_PotionCart", at = { {11.98, -40} } },
	{ old = "K_Guild2", new = "X_GuildHall", at = { {44.08, 59.77} } },
	{ old = "K_Anvil", new = "Kit_X_Anvil", at = { {39, 44.99} } },
	{ old = "K_Forge", new = "Kit_X_Forge", at = { {49, 44.99} } },
	{ old = "K_Altar", new = "X_Altar", at = { {-0.01, 44.99} } },
	{ old = "K_Brazier", new = "Kit_X_Brazier", at = { {-15.01, 60.01}, {14.99, 60.01} } },
	{ old = "K_Nest", new = "X_GooseNest", at = { {-30.01, 29.96} } },
	{ old = "K_MarketArch", new = "X_MarketArch", at = { {-26.98, -27} } },
	{ old = "K_PoleHalo", new = "Kit_X_BannerHalo", at = { {-12.01, -60.01}, {11.99, -60.01} } },
	{ old = "K_PoleHorns", new = "Kit_X_BannerHorns", at = { {-11.98, 60.01}, {12.02, 60.01} } },
	{ old = "K_NoticeBoard2", new = "X_NoticeBoard", at = { {-57.47, -0.01} } },
	{ old = "K_PadBase", new = "X_PadBase", at = { {51.99, -24.01}, {51.99, 23.99}, {67.99, 23.99} } },
	{ old = "Curb", new = "Kit_X_Curb", at = { {14.24, 24.67}, {19.06, 21.17}, {23.04, 16.75}, {26.02, 11.59}, {26.02, -11.58}, {23.05, -16.74}, {19.06, -21.17}, {14.25, -24.67}, {-14.24, -24.67}, {-19.06, -21.17}, {-23.04, -16.75}, {-26.02, -11.59}, {-26.02, 11.58}, {-23.05, 16.74}, {-19.06, 21.17}, {-14.25, 24.67} } },
	{ old = nil, new = "Kit_M_SignPost", at = { {11, -70}, {-11, 70}, {86, -11} } },
}
-- 분수(② Town_Halo_Fountain)는 가운데라 lookAt 없이: fountain:PivotTo(CFrame.new(0, 0, 0)) — 정문(앞 -Z)이 북쪽(빛 마을 길)을 봄. 옛 K_Fountain 자리 (-0.01, -0.02).
-- 예: for _, s in CROSS_SWAP do for _, p in s.at do local m = kit[s.new]:Clone(); m:PivotTo(CFrame.lookAt(Vector3.new(p[1], 0, p[2]), Vector3.zero)); m.Parent = out end end
```

## 4. 확인할 것
- 새 등(Kit_X_Lamp)·화로에 옛 PointLight 옮긴 뒤 지도 빛 개수 40 넘지 않게.
- X_PadBase가 옛보다 2스터드 높음 → 순간이동 패드 TopY·밟는 높이 확인.
- X_GuildHall·Kit_X_StallRed가 옛보다 높음 → 카메라·길 막힘 확인(폰 화면 포함).
- 파랑·초록 가판대: 10/08 Kit_X_StallBlue/Green 만듦(C2). 광장 돌 난간 담·계단 2조각은 만드는 중(검수 OK).
