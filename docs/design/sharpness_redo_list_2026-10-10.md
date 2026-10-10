> 검수 3D 점검 워크플로 wf_14e90401-7f8(2026-10-10) 결과 + 비판자 고침(아래 '비판자 고침'이 위 본문보다 새것) + **검수 결정**(맨 아래). 재질 점검 워크플로 결과가 오면 '재질' 칸을 고친다.

# A23-107 다시 할 목록: 선명도 + 재질 (2026-10-10, 검수 감사)

## 0. 사용자 질문: "빛 마을도 재질이 안 들어가지 않았냐"
**네, 맞습니다. 세 군데가 비어 있습니다.**
1. **쪼갠 조각이 회색으로 나옵니다.** 연습장 사진(10:47~10:57, `art/review/world/halo_new/split/split_before_after.jpg`)에서 문·대성당·탑·조각상·다리 바닥·분수에 회색 조각이 있고, 돔집 A는 거의 전부 회색입니다.
   - 같은 색 그림을 `MeshPart.TextureID`로 넣으면 보이고(`house_texid.png`), SurfaceAppearance로 넣으면 회색입니다. 색 맵 하나만 넣어도(`house_color.png`), 부품 색을 빨강으로 바꿔도(`house_red.png`) 마찬가지입니다.
   - 그래서 그림이 아니라 SurfaceAppearance를 붙이는 방식이 문제입니다. 원인은 아직 모릅니다. 11:01의 jpg 시험(`house_jpg2.png`)은 결과가 커밋에 없습니다.
   - 08:43~09:05에 대성당 전체가, 09:09에 돔집 A 4채가 회색이었던 것은 09:15에 고쳐졌습니다.
2. **작은 소품 8종은 재질 맵을 일부러 뺐습니다.** `tools/worldkit/halo_props.luau` 3317줄 `SMALL = {Balustrade, Lantern, Planter, BannerPole, PotFlowers, CloudBush, Topiary, RoundTree} -- color map only`이고, 3468~3474줄이 배치할 때 NormalMap과 RoughnessMap을 지웁니다(금속도 맵만 남음).
   - A23-107의 "조각마다 4장" 규칙에 어긋납니다.
   - 길가와 정원에 수백 개 깔린 소품입니다(난간 49, 구름 덤불 121, 토피어리 84 등, 감사 때 배치표 기준).
3. **메인 place는 아직 옛 빛 마을입니다.** HaloCastle 9조각과 Town_Halo_Tree 5그루는 색 한 장뿐입니다(번들 GLB 기준). 새 키트를 적용하면 지워질 모델입니다.
- 나머지 큰 모델 12종(문·대성당·탑·집 2종·가게·다리·계단·분수·조각상·섬·먼 아치)은 4장(색·노멀·금속·거칠기)이 다 붙어 있습니다(`build/halo_new/kit_args_halo.json`). 금이 실제로 반짝이는지는 Studio를 보지 않아 **확인하지 못했습니다**.

---

## 읽는 법
- **px/stud:** "단순 / 실제" 순서입니다.
  - 단순 = min(질감, 1024) ÷ 가장 긴 변(스터드).
  - 실제 = UV 채움을 반영한 값으로, 흐림과 더 잘 맞습니다. 목표는 실제 25 이상입니다.
  - 숫자는 네 감사 묶음 보고(hh/, cm/, wr/, hw_sheets/)에서 가져왔습니다.
- **재질** = 번들 GLB(`build/import*/*.glb`)의 맵입니다. 내 스캔 결과는 `audit3d/pbr_scan.json`이고, 빛 마을 키트는 kit_args_halo.json에서 읽었습니다.
  - **4** = 색·노멀·금속/거칠기가 다 있음
  - **C** = 색 한 장뿐(A23-107에 따라 다시 할 목록)
  - **C\*** = 맵은 있지만 배치 도구가 노멀·거칠기를 지움
  - **?** = 모름
  - Studio 안의 상태는 이와 다를 수 있습니다.
- **우선:**
  - **P1** = 사람이 지나가거나 밟거나 바로 옆에 서는 것
  - **P2** = 길가나 몇 스터드 거리에서 보이는 것
  - **P3** = 키트에만 있거나, 멀리 있거나, 이미 선명한 것
- **(추정)** = 내 추측입니다. 검수가 확인해야 합니다.
- 부품 이름은 빛 마을 문·대성당·탑·왕관만 `docs/design/halo_parts_plan_2026-10-10.md`에서 가져왔습니다. 나머지는 시안 그림을 보고 붙인 추정입니다.

## 공통 막힘 (쪼개기 전에)
1. **SurfaceAppearance 회색 문제를 먼저 풀어야 합니다(위 0-1).** 지금 방식으로 쪼개면 회색 조각이 늘어날 뿐입니다.
2. **`tools/split_uv_tiles.py`는 공간이 아니라 UV 영역으로 자릅니다.** 조각마다 모델 전체 크기가 되고(대성당 조각 ≈ 65×52×61), 3×3으로 잘라도 대성당은 실제 ≈ 15 px/stud에 그칩니다.
   - A23-107의 쪼개기는 **공간 조각**(탑·벽·지붕처럼)마다 새 UV와 1024 굽기입니다.
3. **부품 계획서와 사용자 규칙이 어긋납니다.** 부품 계획서(09:57)에는 "탑 몸통 2 (좌우 복사 가능)"와 "작은 탑 4 (1종)"가 있습니다.
   - 그 뒤 A23-107 보강(133559c7, 10:44)은 "재사용 절대 불가 — 좌우 거울 복사 금지, 왼·오른 탑도 각각"입니다. 계획서를 고쳐야 합니다.
4. **원본이 1024뿐인 모델은 쪼개도 선명해지지 않습니다.** web_fixed 원본이 1024인 모델이 여기에 해당합니다: X_NoticeBoard, X_GooseNest, X_MarketArch, X_Altar, X_HouseA/B, X_TreeB, Town_Halo_Fountain, Crown_Broken_B, W_Tree_C. 조각마다 Tripo로 다시 질감을 입히거나 새로 만들어야 합니다.
5. **문·성·대성당처럼 아주 큰 것은 2D 부품 그림부터 시작합니다.** A23-107 큰 구조물 조항입니다. 질감만 나누지 않고 2D 부품 그림 → 부품별 Tripo → WorldKit 조립으로 갑니다. 문은 A23-106에 따라 문틀 + 문짝과 진짜 뚫린 입구, 창은 유리 부품으로 따로 둡니다.

---

## 1. 빛 마을 (Halo town) — 지금 구역
새 키트 20종은 연습장에만 있습니다. 메인 place는 옛 모델입니다(아래 "지울 것").

| 모델 | 크기(stud) | 질감 px | px/stud | 재질 | 할 일 | 우선 |
|---|---|---|---|---|---|---|
| Halo_Gate | 50.4 | 1024 | 20.3 / ~7 | 4 (조각은 회색) | **부품별 Tripo**(계획서 §1). 부품: 왼 탑 몸통 / 오른 탑 몸통 / 왼 돔 / 오른 돔(좌우 따로) / 입구 뚫린 아치벽 / 문짝 ×2 / 후광 고리(Neon 또는 금속) / 등불 기둥. 장식 따로: 파란 깃발 ×2(탑), 금 방패 문장(아치) — 둘 다 이미 그려 올림(1465af55). 바닥 길은 계획서에 없음(추정: 지형/Part + 메달리온) | P1 지나감 |
| Halo_Stairs | 30 (3벌, ×1.3~1.5) | 1024 | 34.1 / ~12 | 4 | **4조각**(추정): 계단 / 왼 옆벽 / 오른 옆벽 / 금 뚜껑 기둥들. 장식 따로: 기둥 깃발 ×4. 금 띠는 메시 그대로 | P1 밟음 |
| Halo_ArchBridge | 42 (14개, ×0.7~1.4) | 1024 | 24.4 / ~10 | 4 (조각 바닥 회색) | **4조각**(추정): 다리 바닥 + 난간 / 아치 / 왼쪽 끝 기둥 / 오른쪽 끝 기둥. 장식 따로: 기둥 깃발 ×4. 금 등불 유리는 Neon 부품 | P1 밟음 |
| Halo_Cathedral | 63 | 1024 | 16.3 / ~5 | 4 (회색 이력) | **부품별 Tripo**(계획서 §3). 부품: 앞 계단 + 바닥판 / 입구 뚫린 몸통 / 큰 금 돔 / 모서리 탑 ×4(계획서는 "1종", 재사용 금지라 몇 종인지 검수가 정함) / 정문 문틀 + 문짝 2 / 아치 유리창(Glass) / 장미창. 장식 따로: 둥근 창·문 위 후광 장식(그려 올림), 정면·탑 깃발, 계단 기둥 깃발 | P1 대표 건물 |
| Halo_Tower | 36 (8개) | 1024 | 28.4 / ~22 | 4 | **부품별 Tripo**. 새 Tower_v2 4면 그림(사람 키 문)으로, 계획서 §4. 부품: 3층 몸통(입구 뚫림) / 돔 + 후광 / 문틀 + 문짝 / 유리창. 장식 따로: 긴 파란 깃발 | P1 바로 옆 |
| Halo_Shop | 27.1 (×1.9, 4개) | 1024 | 37.8 / ~14 | 4 | **3조각**(지붕·몸통·바닥, A23-106): 금 돔 / 열린 가게 앞 몸통 / 받침 + 계단 + 화분. 문은 따로. 장식 따로: 걸이 깃발 1, 차양(그려 올림), 진열 물건(추정: 실내용 3D 선반). 간판 HaloSign_*은 이미 따로 ✓ | P1 다가감 |
| Halo_DomeHouseA | 28.7 (×1.9, 6채) | 1024 | 35.7 / ~14 | 4 (쪼갠 것은 거의 전부 회색) | **3조각**: 금 돔 / 둥근 몸통 / 받침 + 계단 + 화분. 문(문틀 + 고리 달린 나무 문)은 따로, 아치 창은 유리 부품, 벽 등불은 Neon. 장식 따로: 차양 | P2 길가 |
| Halo_DomeHouseB | 34.6 (×2.0, 6채) | 1024 | 29.6 / ~11 | 4 | **4조각**(추정): 돔 + 위층 / 발코니 바닥 + 난간 / 1층 몸통 / 앞 계단 + 화분. 두 짝 문은 따로, 창은 유리. 장식 따로: 옆 깃발 ×2, 차양 | P2 |
| Halo_Planter | 6 (41개) | 512 | 85.3 | C\* | **Tripo 새로**. 잎이 깨지고 금 장식이 수정처럼 변함. 잎은 15k 이상으로 만든 뒤 줄이고, 1024로 올리고, 3~5종(반복 소품 규칙) | P2 |
| Halo_BannerPole | 12 | 512 | 42.7 | C\* | 깃발 천을 얇은 판으로 따로 뗌(그려 둔 깃발). 기둥은 1024 + 4장으로 다시 올림 | P2 |
| Halo_Balustrade | 8 (49개) | 512 | 64 | C\* | 1024로 다시 올림 + 노멀·거칠기 되살림. 3~5종. 작은 삼각기는 판으로(선택) | P2 길가 |
| Halo_Lantern | 7 (20개) | 512 | 73.1 | C\* | 1024로 다시 올림 + 맵 되살림. 작은 깃발은 판으로(선택), 유리는 Neon | P2 |
| Halo_CloudBush / Topiary / RoundTree / PotFlowers | 3~12.3 (121 / 84 / 36 / 32개) | 512 | 42~171 | C\* | 1024로 다시 올림 + 노멀·거칠기 되살림. 각각 3~5종(반복 소품 규칙) | P3 |
| Halo_Islet / Halo_FarArch | 48 / 42 (먼 바다) | 512 | 10.7 / 12.2 | 4 | 멀리 놓는 한 괜찮음. 1024로 다시 올림. 길 가까이 놓게 되면 쪼갬 | P3 |
| Town_Halo_Fountain3 | 16 | 1024 | 64 / ~25 | 4 | 괜찮음. 한 덩어리로 둠. split2판은 회색이니 버림. 금 광택은 확대 크롭으로 확인 | — |
| Halo_Statue | 13 | 1024 | 78.8 / ~40 | 4 | 괜찮음. Statue_v2_split2는 버림 | — |

감사 안 함: 빛 마을 NPC 5명(원본 4096).

## 2. 뿔 마을 (Horns town)
놓인 3D는 HornsCastle 하나뿐입니다. s2/horns 그림 세트(4면 11종 + 한 장 12종)는 아직 3D가 아니므로, 처음 만들 때부터 이 규칙대로 만듭니다.

| 모델 | 크기(stud) | 질감 px | px/stud | 재질 | 할 일 | 우선 |
|---|---|---|---|---|---|---|
| HornsCastle (Town_Horns_Castle_v6mv_T9, 놓임) | 84 | 1024 | 12.2 / 조각당 12~15 | 4 | **부품별 Tripo**. HornsProp_Castle 4면 그림을 부품 그림으로 다시 그림. 부품(추정): 본관 / 왼 탑 / 오른 탑(따로) / 성벽 조각들 / 성문(문틀 + 징 박은 문짝) / 지붕 / 앞 계단. 불 그릇은 Neon 불꽃. 장식 따로: 붉은 깃발(황소 문장, 금 테) 여러 장 | P1 |
| HornsProp_Gate (Town_Horns_Gate 대신) | ~30 (옛 것 기준) | — | — | — | **부품별 Tripo**: 왼 기둥 / 오른 기둥 / 아치 위. 깃발 따로. 4면 그림 있음 | P1 |
| HornsProp_StoneBridge | ? | — | — | — | 15 stud가 넘으면 바닥 / 아치 / 끝 기둥으로 나눔(추정) | P1 밟음 |
| HornsProp_WatchTower | ~24 (옛 것) | — | — | — | 2~3조각(받침 / 몸통 / 꼭대기) 또는 부품별. 깃발 따로, 문 부품 | P2 |
| HornsProp_HouseA / HouseB | ? | — | — | — | 지붕 / 몸통 / 바닥 따로, 문·창 따로(A23-106) | P2 |
| HornsProp_Stall Bread / Juice / Potion / Snack (+ Smith는 앞면만) | ? | — | — | — | 작음. 간판·천 면은 따로. Smith 뒤·좌·우는 검수 결정 대기 | P2 |
| HornsProp_WarTent | ? | — | — | — | 15 stud가 넘으면 나눔. 문장 천 조각은 따로 | P2 |
| 한 장짜리 12종 (BannerPole, Barrel, Bonfire, Brazier, Crate, Lantern, Pine, RockColumnA/B/C, SpikeFence, Table) | 작음 | — | — | — | 4장 재질로 만듦. BannerPole 천은 따로. 반복 소품은 3~5종 | P3 |

옛 Town_Horns_* 키트(놓인 것 0, 대부분 C)는 새 것이 들어오면 지웁니다.

## 3. 교차로 (Crossroads)
| 모델 | 크기(stud) | 질감 px | px/stud | 재질 | 할 일 | 우선 |
|---|---|---|---|---|---|---|
| X_GuildHall (오토의 대장간, 놓임) | 24 | 1024 | 42.7 / 11.1 | C | **부품별 Tripo**(2D 부품 그림부터). 부품(추정): 1층 + 화덕(진짜 뚫린 문, A23-106) / 2층 벽 / 지붕 / 굴뚝. 창은 유리 부품. 장식 따로: 박공 톱니 + 보석 문장, 톱니 깃발 ×2, 걸이 간판. 앞쪽 메시에 구멍 있음 | P1 |
| 교차로 분수: 지금은 Town_Halo_Fountain 재사용(놓임) → X_Fountain(키트, 원본 4096)으로 | 21 | 1024 | 48.8 / 19.4~20.9 | 4 / X_Fountain C | X_Fountain **3조각**: 수반 테 / 단 / 꼭대기 수정(Glass/Neon). 4장으로 굽고, 톱니 판은 얇은 판으로 따로. 시안과 안 맞으면 새 Tripo(추정) | P1 광장 가운데 |
| Kit_X_StallRed / Blue / Green (놓임) | 12.9 | 1024 | 79.3 / 33.4 | C | **Tripo 새로 3종**(Blue·Green은 색만 바꾼 것, A23-96). 지붕은 한 색(쐐기 줄무늬 = 빛살 금지 규칙). 앞 톱니 메달은 판으로 | P1 시장 |
| X_NoticeBoard (놓임) | 16 | 1024 | 64 / 26.4 | 4 | 장식 따로: 판자 면(글씨는 SurfaceGui 그대로), 위 톱니 + 수정 문장. 등불 유리 Neon. 원본 1024 | P1 읽음 |
| X_SupporterBoard (놓임, NoticeBoard 메시 + 금 SA) | 16.3 | 1024 | 62.9 / 25.9 | (금 SA) | **Tripo 새로**(자기 모델). 판자 면 + 문장(붉은 보석·날개)은 따로 | P1 |
| X_GooseNest (놓임, ×1.36) | 16.3 | 1024 | 62.7 / 22.6 | 4 | **2조각**: 돌 받침 테 / 둥지 + 알. 알은 반짝이는 금 부품. 장식 따로: 청록 삼각기(금 V자), 뒤 왕관 보석 메달, 작은 깃발 ×4, 톱니 문장. 원본 1024라 조각마다 Tripo 질감을 다시 입히거나 12 stud로 줄임 | P2 |
| CrownOfBalance (하늘, 160) + Crown_Broken_B (오프닝·키트, 40) | 160 / 40 | 1024 | 6.4 / 3.1 · 25.6 / 12.4 | C | **부품별 Tripo**(2D 이미 있음: `art/out/s2/crown/` 앞 6 + 뒤·옆 9). 부품: 금 반쪽 / 붉은 반쪽 / 루비·사파이어(Glass/Neon) / 후광 고리 / 금 간 자국(Neon). 둘 다 대신함 | P2 (멀리, 오프닝 근접) |
| Kit_X_BannerHalo / Kit_X_BannerHorns (놓임) | 14 | 1024 | 73.1 | C | 천을 얇은 판으로(앞·뒤): 파랑 + 금 후광 고리 / 빨강 + 검은 뿔. 기둥·꼭대기는 메시, 고리는 금 광택 | P2 |
| Kit_M_SignPost ×3 (초원 것을 씀) | 6.6 | 1024 | 155.9 | C | **Tripo 새로**(교차로 자기 이정표, A23-96). 판 면은 따로(그림 또는 SurfaceGui) | P2 |
| X_Altar (놓임) | 9 | 1024 | 113.8 | 4 | 장식 따로: 붉은 방패 문장(톱니·보석). 수정은 Glass/Neon | P2 |
| X_MarketArch (놓임) | 10.5 | 1024 | 97.2 | 4 | 장식 따로: 육각 판, 톱니 + 수정 메달(뒤), 줄 삼각기. 질감은 선명 | P3 |
| Kit_X_PotionCart | 7.5 | 1024 | 136.5 | C | 장식 따로: 방패 판(물약 문장). 병은 유리 | P3 |
| X_HouseA / X_HouseB (키트) | 14 | 1024 | ~24~29 실제 | 4 | 쓰게 되면 지붕 / 몸통 / 바닥, 문·창 따로 | P3 |
| X_SpawnPlaza (키트) | 16 | 1024 | 64 / 26.7 | C | 밟는 곳이 되면 바닥 / 기둥으로 나눔 | P3 |

선명도는 괜찮은 것: K_CrownShard_v2(4), X_PadBase(C), Kit_X_Lamp(C), Forge(C), Anvil(C), Brazier(C), Bench(C), Curb(C), PlazaWall(4), PlazaStairs(4), FruitCart(C), Barrel(C), Crate(C), Fence(C), FlowerPot(C), Bush(C), X_TreeA(C), X_TreeB(4), GoldenGoose(?). **C인 것은 재질만 다시 합니다(아래 "재질만").**

## 4. 슬라임 초원 (Slime Meadow)
| 모델 | 크기(stud) | 질감 px | px/stud | 재질 | 할 일 | 우선 |
|---|---|---|---|---|---|---|
| Kit_M_MeadowArch (구역 문, 지금은 Part 문) | 40 | 1024 | 25.6 / 12.3 | 4 | 문이므로 **부품별 Tripo**가 맞음: 왼 기둥 / 오른 기둥 / 가로대. 아니면 4096 HD 원본을 이 3조각으로 나눔. 걸린 판은 그림 판(큰 장소 글씨 없음, A23-36). 등불은 Glass/Neon | P1 지나감 |
| CrownShrine (놓임, 왕 슬라임 언덕) | 21 | 1024 | 48.8 / 20.3 | 4 | **Tripo 새로**(뚜껑 땜질). 부품: 풀 받침 / 돌 벽 테 / 왕관 끝. 문은 문틀 + 문짝 부품 | P1 |
| 초원 나무 (W_Tree_A/B/C 재사용, 90그루, 17~35.6) | 35.6 | 1024 | 28.8 / 14.6~20.3 | C | **Tripo 새로**: 초원 자기 나무 3~5종. 줄기 / 잎 조각마다 질감, 잎은 15k 이상 → 줄임 | P2 |
| Kit_M_BushA / BushB (122 + 85, ~19까지 키움) | 19 | 1024 | 54 / 22.5~25.9 | C | **Tripo 새로**: 큰 덤불 모델(잎 15k 이상, LOD) 3~5종. 아니면 ~8 stud로 제한 | P2 |
| Kit_M_SignPost ×5 | 6.6 | 1024 | 155.9 | C | **Tripo 새로**(구멍 땜질). 판 면은 따로 | P2 |
| Kit_M_JobBoard (키트) | 16 | 1024 | 64 / 27.6 | C | 장식 따로: 판자 면, 잎 + 보석 문장 | P2 (놓을 때) |
| W_Boulder_A/B 재사용 (32개, 4~12) | 12.2 | 1024 | 83.9 | C | **Tripo 새로**: 초원 자기 바위(재사용 규칙 때문, 질감은 괜찮음) | P3 |
| Kit_W_StepStones 재사용 (6개) | 7.9 | 1024 | 129.6 | 4 | **Tripo 새로**: 초원 자기 징검돌(재사용 규칙 때문) | P3 |
| Kit_M_Bridge (키트, 지금은 Part) | 12 | 1024 | 85.3 | C | 15 stud 이하면 괜찮음. 강을 건너게 늘리면 바닥 / 난간 / 끝 기둥 | P3 |
| Kit_M_Mushrooms (최대 13) | 13.2 | 1024 | 77.8 | C | 10 stud 이하로 둠 | P3 |

A23-107은 아니지만 다시 만들기 목록에 있는 것: SlimeKing(모양 문제 P1 #5, 4), Slime Prince/BigSlime(자기 모델 P1 #1, 몸통 C).
선명도는 괜찮은 것: PuddleRim, FlowerCart, JellyRock, Stump, Fence, LogBench, Pinwheel, FlowersA/B, CrystalPile, PicnicBasket(모두 C → 재질만), Slime, PetBabySlime(?).

## 5. 할로윈 (호박밭 + 유령 골짜기)
호박밭은 Part로 지었고, 유령 골짜기는 무료 generate_mesh 모델 GF_* 20개를 씁니다. Tripo 키트 P_/Kit_P_/H_/Kit_H_는 보관만 되어 있고(놓인 것 0) 모두 재질 4장입니다. 4096 원본(`*_HD_src.glb`)이 디스크에 있어 **새 크레딧 없이 쪼갤 수 있습니다.**

| 모델 | 크기(stud) | 질감 px | px/stud | 재질 | 할 일 | 우선 |
|---|---|---|---|---|---|---|
| P_Cliff_A | 32 | 1024 | 32 | 4 | **2조각**: 왼쪽 / 오른쪽. HD 원본에서 다시 굽기 | P1 길가 |
| Kit_P_EntranceSign | 16 | 1024 | 64 | 4 | 걸린 판을 얇은 판으로: 호박 문장, 글씨 없음(A23-36) | P1 입구 |
| H_TreeArch (GF_Arch 대신) | 36 | 1024 | 28.4 | 4 | **3조각**: 왼 줄기 / 오른 줄기 / 위 잎. 등불 유리 Neon | P1 지나감 |
| P_Cliff_B | 26 | 1024 | 39.4 | 4 | **2조각**: 위 / 아래 | P2 |
| P_TreeAutumn_A | 26.2 | 1024 | 39.1 | 4 | **2조각**: 줄기 / 잎(HD 원본). 잎 15k 이상(지금 6k LOD는 깨짐) | P2 |
| P_TreeAutumn_B | 30 | 1024 | 34.1 | 4 | 위와 같음 | P2 |
| H_TreeTwisted (GF_Tree ×7 대신) | 35.5 | 1024 | 28.9 | 4 | **2~3조각**: 줄기 + 뿌리 / 잎(/ 잎 2). 잎 15k 이상. 7그루라 3~5종(반복 규칙, 추정) | P2 |
| H_Willow (GF_Willow ×2 대신) | 26 | 1024 | 39.4 | 4 | **2조각**: 줄기 / 늘어진 잎 | P2 |
| GF_Rock ×3 (놓인 임시 모델) | 11.2 | ? | ? | ? | **Tripo 새로**: 골짜기 이끼 바위(W_Boulder를 쓰면 A23-96 위반) | P2 |
| GF_Tree ×7 / GF_Willow ×2 / GF_Arch / GF_Lantern ×3 / GF_Mushrooms ×4 (놓임) | — | ? | — | ? | 위 쪼개기 뒤 H_* / Kit_H_*로 바꿔 끼우고 GF_*는 지움 | 구역 차례 |
| Kit_P_Sunflowers | 6 | 1024 | 170.7 | 4 | 질감은 괜찮음. HD에서 15k 이상으로 다시 줄임(잎 규칙) | P3 |
| P_Pine | 22 | 1024 | 46.5 | 4 | 괜찮음(쪼개기는 선택) | — |

괜찮은 것: HayBales, PumpkinCart, PumpkinCluster, Kit_H_LanternPost, StumpTable, GlowShrooms, PumpkinKing, GhostKing, PumpkinSlime, LittleGhost, GhostMinion.

## 6. 고블린 숲 (Goblin Woods)
| 모델 | 크기(stud) | 질감 px | px/stud | 재질 | 할 일 | 우선 |
|---|---|---|---|---|---|---|
| W_Boulder_A / B (숲·고개·바다·초원에 157개, 최대 50) | 50 | 1024 | 20.5 / 8.3 | C | **Tripo 새로**: 구역마다 실제 크기의 큰 바위·절벽. 이 모델은 14 stud 이하로만. 고개·바다도 자기 것이 필요하지만 구역 목록에는 없음 | P1 (사진에서 카메라가 번진 바위 속) |
| W_GateOpen (E9 번들, 분석한 place에는 없음) | 48 | 1024 | 21.3 / 14.4 | 4 | 문이므로 부품별 Tripo, 또는 4096 HD를 나눔: 왼 울타리 + 기둥 / 오른 울타리 + 기둥 / 위 가로대. 고블린 얼굴 문장은 따로 | P1 지나감 |
| W_GiantTree (랜드마크) | 80 | 1024 | 12.8 / 5.3 | C | **부품별 Tripo**: 뿌리 + 줄기 / 나무집 1 / 나무집 2 / 사다리 + 줄다리 / 잎 덩이들 | P1 |
| W_Tree_A/B/C (숲 99그루, 36~55) | 54.6 | 1024 | 18.8~21.3 / 10.6~11.9 | C | **Tripo HD 새로**(15k 이상 → LOD). 줄기 / 잎 조각, 3~5종 | P2 |
| Kit_W_BushA (35개, 19~32) | 32.2 | 1024 | 31.8 / 14.2 | 4 | **3~4덩이**로 나눠 4096 HD(9.5k 면)에서 다시 굽기. 아니면 ~12 stud로 제한 | P2 |
| Kit_W_Banner (6개) | 8 | 1024 | 128 | 4 | 천을 얇은 판 + 그림으로(시안의 해골 문장은 만화풍, 무섭지 않게) | P2 |
| W_BridgeWood (키트) | 33.6 | 1024 | 30.4 / 13.5 | C | **Tripo 새로**: 숲 자기 다리(바닥 / 왼 난간 / 오른 난간). 지금은 분위기가 안 맞음 | P2 (놓을 때) |
| Kit_W_JobBoard (키트) | 16 | 1024 | 64 / 27.4 | C | **Tripo 새로**(구멍 땜질). 판자 면은 따로 | P3 |
| W_Gate (키트, W_GateOpen이 대신할 듯) | 24 | 1024 | 42.7 / 24.8 | C | 남기면 왼 기둥 / 오른 기둥 / 가로대, 판은 따로 | P3 |

선명도는 괜찮은 것: W_Tent_A/B(C), W_Totem(C), Kit_W_Awning(4), SignPost(C), LanternPost(C), CampFence(C, 끝을 손으로 칠한 것이라 A23-96에 따라 어차피 새로), Campfire_Fire(C), Crates(C), LootSack(C), FallenLog(C), Stump(C), LogStool(4), StepStones(4), BushB(4, 22 이하), Fern(4), MossRock(4, 14 이하), Mushrooms(4). 숲에 놓인 초원 꽃 70개는 숲 자기 꽃으로 바꿉니다(A23-96).

## 7. 해골 유적 (Skeleton Ruins)
R_* 교체 전이라 지금은 Part입니다. R_*는 모두 재질 4장입니다.

| 모델 | 크기(stud) | 질감 px | px/stud | 재질 | 할 일 | 우선 |
|---|---|---|---|---|---|---|
| R_Gate | 48 | 1024 | 21.3 / 11.9 | 4 | 문이므로 부품별, 또는 4096 HD를 나눔: 왼 탑 / 오른 탑 / 아치 + 판. 찢긴 보라 깃발 ×2는 얇은 판. 돌 판의 큰 장소 이름은 A23-36과 겹침(확인) | P1 지나감 |
| R_Arch_A | 19.5 | 1024 | 52.6 / 24.6 | 4 | **2조각**: 서 있는 기둥 + 아치 / 무너진 쪽. 보라 천은 판 | P2 |
| R_Arch_B | 19.3 | 1024 | 53.1 / 26.5 | 4 | **2조각**: 왼 기둥 / 오른 기둥 + 아치. 천은 판 | P2 |
| Kit_R_Banner | 12 | 1024 | 85.3 | 4 | 보라 깃발 + 금 왕관 문장을 얇은 판으로 | P2 |
| Kit_R_PillarA | 8 (교체 때 최대 17.6) | 1024 | 128 | 4 | zone_swap 배율 상한을 ~1.6배로 | P3 |

괜찮은 것: PillarB, StoneMarker, SpiritBowl. A23-107은 아님: 클래터 대장 자기 모델(P1 #4).

## 지울 것 (새것으로 대체됨, 고치지 않음)
- **빛 마을, 메인 place에 놓인 것:** HaloCastle(Town_Halo_Castle 9조각, C), Town_Halo_Tree ×5(C), Town_Halo_WallTower ×4, Town_Halo_KnightStatue ×6. `halo_props.luau`를 적용하면 치워집니다.
- **빛 마을 키트만 있는 것:** Town_Halo_Gate, Town_Halo_Castle 백업, Town_Halo_Spawn/Wall/Bridge/HouseA/B/C/Potion/Smithy/Bakery/JuiceBar.
- **뿔 마을:** 옛 Town_Horns_* 키트 전부(새 뿔 세트가 들어온 뒤).
- **교차로·초원:** KitStage K_*, CrossroadsKOld, MapV1Backup, MeadowTerrainStore, MeadowDressBackup, CrownShrineBackup(백업 묶음).

## 재질만 (선명도는 괜찮고 맵이 모자란 것)
- **빛 마을 8종(C\*):** `halo_props.luau`의 SMALL 목록에서 노멀·거칠기를 지우는 줄을 빼고, 1024 질감으로 다시 올립니다. 1순위입니다.
- **나머지 구역 C 39종:**
  - 교차로 15: PadBase, Lamp, Forge, Anvil, Brazier, Bench, Curb, FruitCart, Barrel, Crate, Fence, FlowerPot, Bush, X_TreeA, SpawnPlaza
  - 초원 13: PuddleRim, FlowerCart, JellyRock, Stump, Fence, LogBench, Pinwheel, FlowersA, FlowersB, CrystalPile, PicnicBasket, Mushrooms, Bridge
  - 숲 11: W_Tent_A, W_Tent_B, W_Totem, SignPost, LanternPost, CampFence, Campfire_Fire, Crates, LootSack, FallenLog, Stump
  - 할 일: Blender에서 색 마스크로 노멀·거칠기·금속도를 구워 SurfaceAppearance 4장을 만듭니다(A23-107).
- **구역 밖 C:** Acc_HaloR1~5 / Acc_HornsR1~5(후광·뿔 장식, 금이 반짝여야 함).

## 반복 소품 여러 종류 (A23-107, 10:44)
한 모델을 여러 번 복제하지 않고 3~5종을 새로 만들어 섞습니다.
- 빛 마을: 화분·난간·등불·구름 덤불·토피어리·둥근 나무·꽃 화분
- 초원: 덤불·버섯·꽃
- 숲: 덤불·고사리·이끼 바위·버섯·울타리
- 할로윈: 뒤틀린 나무·호박 무더기
- 탑(빛 마을 8개)이 이 규칙에 드는지는 **추정이라 검수가 정합니다.**

---

## 이미지 생성 2가 그릴 목록
구역 안에서는 같은 장식을 하나로 묶었습니다. 다른 구역끼리는 묶지 않습니다(A23-96). 모두 고급, 앞·뒤, 글씨 없음입니다.
- **담당:** A23-107은 "장식 그림 = 이미지 생성 2(빛·뿔 마을) / 이미지 생성 1(나머지 구역 큰 그림)"입니다. 3~7번 구역의 작은 장식을 누가 그릴지는 검수가 확인해야 합니다.
- **같은 그림을 여러 곳에 다는 문제:** A23-107(10:44) "재사용 절대 불가"가 같은 깃발 그림을 여러 건물에 다는 것까지 막는지는 정해지지 않았습니다(검수 결정). 엄격하게 읽으면 건물마다 깃발을 새로 그립니다.

**빛 마을** (✅ = 그려서 자르고 올림, 1465af55 11:15)
- ✅ BannerEmblem: 문 탑 ×2, 탑 ×8, 대성당 정면·탑, 돔집 B ×2, 가게 걸이, BannerPole
- ✅ BannerPlain: 계단 기둥 ×4, 다리 끝 기둥 ×4, 대성당 계단 기둥(어디에 어느 깃발을 달지는 추정)
- ✅ ShieldEmblem(금 방패): 문 아치
- ✅ RoundWindow: 대성당 장미창
- ✅ DoorHalo: 대성당 문 위 후광 장식
- ✅ AwningStripes: 돔집 A, 돔집 B, 가게
- ✅ 이미 있음: HaloSign_* 4종(가게 간판), HaloFloor_Medallion_A
- **새로 그릴 것 — 문짝 5종** (얇은 판 그림으로 할지 Tripo로 할지는 이미지 생성 1이 정함): 문(파랑 + 금, 2짝) / 대성당(금, 2짝) / 돔집 A(고리 달린 나무 문) / 돔집 B(나무 두 짝 문) / 탑(작은 문)
- 선택: 가게 진열 물건 배경(추정, 3D 선반으로 하면 필요 없음), 난간·등불용 작은 삼각기
- 엄격하게 읽으면 추가: 건물마다 자기 깃발(문·탑·대성당·돔집 B·가게·다리·계단·깃대) 최대 ~6장

**뿔 마을** (아무것도 그리지 않음. 큐에 "뿔 성채 부품·붉은 깃발·황소 문장"이 있음)
- 붉은 깃발(황소 문장, 금 테): 성채, 문, 감시탑, (성벽)
- 황소 방패 문장: 성채 정문·본관(추정)
- 징 박은 붉은 문짝: 성채(문에 문짝이 있으면 문도)
- 따로: 성채·문 부품 멀티뷰 그림(큰 구조물 조항). 부품표는 halo_parts_plan처럼 이미지 생성 1과 먼저 맞춥니다.
- 선택: 천막 문장 천 조각, 노점 간판 면(추정)

**교차로**
- 톱니 + 수정 메달: 노점 ×3 앞, 게시판 위, 시장 아치 뒤, X_Fountain 수반 판, 거위 둥지 톱니
- 대장간 박공 문장(톱니 + 보석): 위 메달과 같은 그림으로 될 수도 있음(추정)
- 빛 쪽 깃발 천(파랑 + 금 후광 고리): Kit_X_BannerHalo
- 뿔 쪽 깃발 천(빨강 + 검은 뿔): Kit_X_BannerHorns
- 대장간 톱니 깃발: GuildHall ×2
- 대장간 걸이 간판(톱니·망치, 글씨 없음): GuildHall
- 게시판 판자 면: X_NoticeBoard
- 후원자 게시판 판자 면: X_SupporterBoard
- 후원자 게시판 문장(붉은 보석 + 날개): X_SupporterBoard
- 거위 둥지 청록 삼각기(금 V자): GooseNest 앞
- 거위 둥지 작은 깃발: GooseNest ×4
- 거위 둥지 왕관 보석 메달: GooseNest 뒤
- 제단 붉은 방패(톱니 + 보석): X_Altar. 빛 쪽 파란 짝이 있는지는 추정이라 확인
- 물약 방패 판: Kit_X_PotionCart
- 시장 아치 육각 판: X_MarketArch
- 시장 아치 줄 삼각기: X_MarketArch
- 이정표 판 면: 새 교차로 이정표

**슬라임 초원**
- 초원 문 걸이 판(그림, 큰 장소 글씨 없음): Kit_M_MeadowArch
- 일거리 게시판 판자 면 + 잎·보석 문장(2장): Kit_M_JobBoard
- 이정표 판 면: 새 초원 이정표
- 왕관 사당 문짝: CrownShrine(그림으로 할 경우)

**할로윈**
- 호박밭 입구 판(호박 문장, 글씨 없음): Kit_P_EntranceSign

**고블린 숲**
- 고블린 야영지 깃발 천(누덕누덕 갈색·초록, 만화풍 문장): Kit_W_Banner ×6
- 숲 일거리 게시판 판자 면: Kit_W_JobBoard 새것
- 선택: 고블린 문 얼굴 문장(3D 조각 대신 그림으로 할 경우), W_Gate 판(남길 경우)

**해골 유적**
- 보라 깃발 + 금 왕관 문장: Kit_R_Banner, R_Gate 탑 ×2(찢긴 판. 엄격하게 읽으면 따로 그림)
- 보라 천 휘장: R_Arch_A, R_Arch_B
- 선택: R_Gate 돌 판

---

## 개수
- **쪼갤 모델 20개:** 지금 메시 또는 HD 원본을 쓰고, 새 Tripo가 필요 없습니다.
  - 빛 마을 5: 계단, 다리, 가게, 돔집 A, 돔집 B
  - 교차로 2: X_Fountain, 거위 둥지
  - 초원 1: MeadowArch
  - 할로윈 7: 절벽 A·B, 가을 나무 A·B, 나무 아치, 뒤틀린 나무, 버드나무
  - 숲 2: W_GateOpen, BushA
  - 유적 3: R_Gate, R_Arch_A, R_Arch_B
  - MeadowArch·W_GateOpen·R_Gate는 문 조항에 따라 부품별 Tripo로 바뀔 수 있습니다.
- **장식만 떼어 낼 모델 11개:**
  - 빛 마을: BannerPole
  - 교차로: NoticeBoard, BannerHalo, BannerHorns, Altar, MarketArch, PotionCart
  - 초원: JobBoard
  - 할로윈: EntranceSign
  - 숲: Kit_W_Banner
  - 유적: Kit_R_Banner
- **Tripo 새로 / 부품별 최소 31개:**
  - 빛 마을 4: 문, 대성당, 탑, 화분
  - 뿔 마을 1: 성채. 새 뿔 세트 23종은 처음부터 규칙대로 만들므로 따로 셉니다.
  - 교차로 7: 대장간, 노점 ×3, 후원자 게시판, 왕관 세트, 이정표
  - 초원 10: 사당, 나무 ×3, 큰 덤불 ×2, 이정표, 바위 ×2, 징검돌. 이 중 바위·징검돌 3개는 재사용 때문에 다시 만드는 것입니다.
  - 할로윈 1: 골짜기 바위
  - 숲 8: 큰 나무, 나무 ×3, 큰 바위 ×2, 다리, 게시판
  - 반복 소품 3~5종 규칙을 적용하면 더 늘어납니다.
- **새로 그릴 장식 최소 35장:** 빛 마을 5(문짝) + 뿔 3 + 교차로 17 + 초원 5 + 할로윈 1 + 숲 2 + 유적 2.
  - 빛 마을 6장은 이미 그려서 올렸습니다.
  - 선택 6장이 더 있고, 깃발을 엄격하게 읽으면 빛 마을에 최대 ~6장이 더 붙습니다.
- **재질만 47개:** 빛 마을 C\* 8 + 다른 구역 C 39. 구역 밖 장식 C 10개는 따로입니다.
- **먼저 할 것:** 빛 마을의 SurfaceAppearance 회색 문제와 SMALL 맵을 지우는 줄입니다. 이 둘을 풀지 않으면 위 빛 마을 작업이 그대로 회색이거나 무광으로 나옵니다.


---
## 비판자 고침 (본문보다 새것)
**A23-107 다시 할 목록 초안: 고칠 점**

초안의 근거가 11:28 커밋 5726f07b보다 앞서 있어서, 빛 마을 재질 답(§0)부터 낡았습니다.

**A. 11:28 커밋 뒤로 낡은 부분 (§0, §1, "먼저 할 것")**

1. **§0-2와 "재질만 빛 마을 C\* 8종"은 이미 처리됐습니다.**
   - `C:/Users/glori/Documents/Roblox/Game/tools/worldkit/halo_props.luau`의 `clean()`에서 노멀·거칠기를 지우는 줄이 빠졌습니다(3468~3474줄은 이제 주석뿐).
   - 3317줄의 `-- color map only` 주석만 낡은 채 남아 있습니다.
   - 작은 소품도 `metal=true`가 되어 `tools/pbr_from_color.py` 색 마스크로 만든 금속·거칠기 맵을 받습니다.
   - 남은 일은 색 질감이 512라는 점뿐입니다.
2. **§0-1 "쪼갠 조각은 회색, 원인 모름"이 낡았습니다.**
   - `art/review/world/halo_new/split/` 사진 기준입니다. 11:14 `gate_pbr.png`, 11:22~11:24 `gatec_/shopc_/fountc_/cathc_pbr.png`, 11:25 `material_2d_matte_pbr.jpg`에서는 문·대성당 조각과 같은 사진의 집·분수 조각이 색과 PBR로 나옵니다.
   - **아직 회색인 것은 돔집 A입니다.** `gatec_pbr.png`(11:22)와 `gate_spec_compare.jpg`(11:26)에서 문 뒤에 거의 전부 회색으로 보입니다.
   - 같은 붙이는 방식으로 다른 조각은 보이므로, "SA를 붙이는 방식이 문제"라는 결론은 약해졌습니다. 돔집 A 조각 질감만의 문제일 가능성이 있습니다(추정).
3. **§1의 판정이 11:28 반입과 어긋납니다.**
   - `art/models/worldkit/import_halo_split_assets_2026-10-10.json`이 다리·분수(Fountain3)·조각상도 2×2 조각으로 키트에 넣어 한 덩어리 모델을 대신했습니다(문·대성당은 3×3).
   - 그래서 "Fountain3 한 덩어리로 둠, split2 버림"과 "Statue_v2_split2 버림"은 지금 상태와 맞지 않습니다.
   - 표의 px/stud도 쪼개기 전 값입니다. 2×2는 약 2배, 3×3은 약 3배이므로 다시 재야 합니다.
4. **"09:15에 고쳐졌다"는 회색만 고친 것입니다.**
   - `build/halo_new/kit_args_fix.json`이 대성당과 돔집 A 한 덩어리 키트를 TextureID 하나로 다시 만들었고, SA는 없습니다.
   - `import_halo_town_assets` json에서도 `sa=[]`, `tex=Y`입니다. 둘 다 "4"가 아니라 **C**입니다.
5. **"큰 모델 12종은 4장이 다 붙어 있다"는 틀렸습니다.** `kit_args_halo.json`의 코드는 MetalnessMap을 한 번도 넣지 않습니다(10/08 규칙). 실제로는 3장이었고, 금속 맵은 11:28부터 `metal=true`인 것에만 들어갑니다.

**B. 다른 구역의 재질 판정**

6. **빛 마을 밖의 "4"는 게임 안에서 모두 3장입니다.**
   - `materials_table.json`에서 SA가 있는 모델은 전부 pbr_no_metalness입니다. 키트 빌더가 `metal=true`가 없으면 금속 맵을 버리기 때문입니다.
   - 금이나 금속이 있는 것은 "재질만" 목록에 넣고 `pbr_from_color.py`로 금속 맵을 만들어야 합니다: X_NoticeBoard, X_SupporterBoard, X_GooseNest, X_Altar, X_MarketArch, K_CrownShard_v2, 교차로 Town_Halo_Fountain, CrownShrine, Kit_M_MeadowArch, Kit_R_Banner, Kit_H_LanternPost, GoldenGoose, SlimeKing.
7. **HornsCastle은 "4"가 아니라 C입니다.** 놓인 9조각 모두 TextureID만 쓰고 SA가 없습니다. 원본에는 PBR 맵이 있지만 쓰지 않았습니다.
8. **몬스터·NPC·무기가 빠졌습니다.** A23-107 재질 조항은 이것들을 명시적으로 포함합니다.
   - 게임에서 색 한 장뿐인 몬스터는 PumpkinKing, PumpkinSlime, LittleGhost, GhostMinion, GhostKing, BatGoblin, PetBabySlime, BigSlime입니다. 초안은 할로윈 몬스터를 "괜찮은 것"에 넣었습니다.
   - Slime과 Skeleton은 원본에 맵이 있는데 TextureID만 씁니다.
   - GoldenGoose "(?)"는 금 거위인데 금속 맵이 없습니다.
   - PotionMerchant(TextureID + 질감 없는 부품 14개)는 목록에 없습니다.
9. **노멀은 색 마스크로 만들 수 없습니다.** `pbr_from_color.py`는 금속·거칠기만 만듭니다. 색 한 장뿐인 39종은 노멀 맵을 다른 곳(Tripo HD로 질감 다시 입히기 등)에서 받아야 합니다.

**C. 빠진 큰 구조물 (Part로 지었지만 15 stud가 넘음)**

10. **Bridge_Halo**
    - Part 55개, 22×22×184, z -332~-148.
    - `halo_props.luau` 7줄이 "NEVER touched"로 보호하는, 빛 마을에서 걸어 나가는 유일한 다리입니다. P1인데 목록에 없고 담당 구역도 없습니다.
    - Bridge_Horns도 똑같이 184입니다. 그래서 HornsProp_StoneBridge의 크기 "?"는 약 184이고, "15 stud가 넘으면 나눔"이 아니라 서로 다른 여러 구간으로 지어야 합니다.
11. **뿔 마을의 Part 자리 표시**
    - "놓인 3D는 HornsCastle 하나뿐"은 메시 기준으로만 맞습니다.
    - Gate_HornsTown(24×27), HornTower ×2(높이 약 28), Spike가 놓여 있으니 바꿀 목록이나 지울 목록에 넣어야 합니다.
12. **Bridge_Meadow(x≈180)와 Bridge_Goblin(x≈680)**
    - 둘 다 Part 64×22이고 큰길 위에 있습니다.
    - Kit_M_Bridge(12, P3)와 W_BridgeWood(33.6, "놓을 때")는 너무 짧습니다. 약 64 stud를 여러 조각으로 만들어야 하고 우선은 P1입니다.
13. **바다 바위(W_Boulder 26개)**
    - (249,-592)와 (238,-416)은 빛 마을 영역(MaxX 212)에서 약 37 stud 밖입니다.
    - (54,248)과 (-155,291)은 뿔 마을로 가는 길 옆입니다.
    - 숲 차례(6번째)가 아니라 빛 마을·뿔 마을 차례에 처리해야 합니다(재사용 금지).
14. **지울 목록에 빠진 것:** Kit_M_CrownShrine(키트 16), Town_Halo_Castle_T9, Town_Horns_Castle_v4(키트와 CastleOld).

**D. 장식 그림의 중복과 누락**

15. **교차로 깃발 3장은 이미 있는 그림입니다.**
    - Banner_Halo, Banner_Horns, Banner_Crossroads, Banner_Artisan이 `art/ui/`에 있습니다(10/06 고름, 중간 품질, 683×1024 불투명 천).
    - `world_kit_2026-10-06.md`와 `manifest.json`에서 교차로 진영 깃발용으로 정해 둔 것입니다.
    - 초안의 "빛 쪽 깃발 천 / 뿔 쪽 깃발 천 / 대장간 톱니 깃발"은 이것들을 고급으로 다시 그리고 뒷면만 더하면 됩니다. 새 디자인이 아닙니다.
    - Banner_Artisan의 황동 톱니 + 청록 보석은 "톱니 + 수정 메달"과 같은 무늬입니다.
    - 뿔 깃발 설명도 고쳐야 합니다. "빨강 + 검은 뿔"이 아니라, 진홍 천에 끝이 둥근 짧은 뿔 두 개, 주황 테두리입니다.
16. **누락된 장식**
    - 뿔 마을 노점 간판 5장(Bread·Juice·Potion·Snack·Smith): HaloSign_\*에 해당하고 간판은 규칙 ②라서 "선택"이 아니라 필수입니다.
    - 뿔 마을 HouseA·B와 WatchTower의 문짝(A23-106).
    - 빛 마을 "문짝 5종"에 가게 문이 빠졌습니다. `halo_props`의 DOOR 표에 Shop 문이 있습니다.
17. **HornsProp_Gate는 부품 그림부터 그려야 합니다.** 지금 4면 통그림이 아니라, 아주 큰 구조물 조항과 거울 복사 금지에 따라 왼 기둥과 오른 기둥을 따로 그립니다.

**E. 재사용 규칙의 일관성**

18. 초안은 탑 8개만 재사용 규칙 질문에 올렸습니다. 그런데 "한 모델 복제, 크기만 바꾸기 금지"는 다음에도 똑같이 걸립니다. 모두 검수 결정 목록에 올려야 합니다.
    - 다리 ×14(0.7~1.4배로 크기만 바꿈)
    - 계단 ×3(1.3~1.5배)
    - 돔집 A ×6, 돔집 B ×6
    - 가게 ×4(모양 하나를 같이 씀)
    - 부품 계획서의 "등불 기둥 4 (1종)"과 "창 1종 × 여러 개"

**F. 구역 순서**

19. 순서는 맞습니다(A23-102: 빛 마을 → 뿔 마을 → 교차로 → 초원 → 할로윈 → 숲 → 유적). 다만 Bridge_Halo, Bridge_Horns, 바다·고개 바위, 하늘의 CrownOfBalance는 들어갈 구역 차례가 없으니 정해 줘야 합니다.

**"먼저 할 것" 고침:** 작은 소품 맵 지우기는 끝났습니다. 남은 것은 아래 넷입니다.
- 돔집 A 회색 조각
- 대성당·돔집 A 한 덩어리 키트가 TextureID만 씀(조각판으로 바꾸면 사라짐)
- 빛 마을 밖 키트의 금속 맵 빠짐
- 작은 소품 색 질감 512 → 1024

확인에 쓴 스크립트와 그림은 `C:/Users/glori/AppData/Local/Temp/claude/C--Users-glori-Documents-Roblox-Game/b2930c75-ef84-4cbc-952a-619ee0ded1b8/scratchpad/audit3d/crit/`에 있습니다(`grey_house_zoom.jpg`, `house_sheet.jpg`, `parts.py`, `pos.py`, `mat.py`).

---
## 검수 결정 (2026-10-10 오후, 사용자 "재사용 절대 불가", "매의 눈")
1. **질감 UV 쪼개기는 임시 개선일 뿐**: UV 영역으로 잘라서 조각마다 모델 전체 크기라 큰 건물은 3×3도 실제 약 15 px/stud. 큰 구조물(문·대성당·성·탑·다리·관문·큰 나무)은 **2D 부품 그림 → 부품별 Tripo → 조립**이 진짜 해결(A23-107). 원본이 1024뿐인 모델(X_NoticeBoard·X_GooseNest·X_MarketArch·X_Altar·X_HouseA/B·X_TreeB·Town_Halo_Fountain·Crown_Broken_B·W_Tree_C)은 쪼개도 안 좋아지니 새로 만든다.
2. **재사용 금지 적용 범위**: 마을 건물(집·가게·탑·다리 중 큰 것)은 놓는 자리마다 **각각 다른 모델**(집 12채 = 12종, 가게 4 = 4종, 계단 3 = 3종). 작은 반복 소품(나무·덤불·화분·난간·등불·작은 다리)은 **종류 3~5개**를 섞음. 한 건물 안에서 같은 창·기둥이 되풀이되는 것은 건축이라 OK. 다른 구역 것을 가져다 쓰기·크기만 바꾸기·거울 복사는 금지.
3. **Part로 지은 큰 구조물도 3D로**: Bridge_Halo(184)·Bridge_Horns(184)·Bridge_Meadow·Bridge_Goblin(64)·Gate_HornsTown·HornTower 등 — 여러 구간 부품으로 새로. 차례: Bridge_Halo = 빛 마을(지금), Bridge_Horns·바다 바위(뿔 쪽) = 뿔 마을, 빛 마을 앞 바다 바위 = 빛 마을, Bridge_Meadow = 초원, Bridge_Goblin = 숲.
4. **하늘의 균형의 왕관(160스터드, 오프닝·교차로)** = 지금(새 왕관 부품 진행 중).
5. **몬스터·NPC·무기도 재질 4장**: 원본에 맵이 있는 것(Slime·Skeleton 등)은 바로 연결, 없는 것은 그 구역 차례에 새로(Tripo PBR).
6. **이미 있는 깃발 그림**(art/ui/Banner_Halo/Horns/Crossroads/Artisan, 10/06 중간 품질)은 고급으로 다시 그리고 뒷면 추가 — 새 디자인 아님.
