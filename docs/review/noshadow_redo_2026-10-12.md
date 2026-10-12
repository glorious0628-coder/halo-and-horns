# 그림자 없이 다시 — 목록·순서 (최종 검수 2026-10-12, SPEC A23-150·A23-151)

사용자: "그림자 있게 생성된 물건들 싹 다 폐기하고, 다시 그린 다음에 내가 알려준 방법으로", "이미지 그릴 때 그림자 없이 … 모든것 다!".

- 점검: 3D 물건의 2D 원본을 하나씩 열어 봄(워크플로 41 에이전트, 앞면 기준) + 빠진 것 찾기(물건·몬스터·타일 101개). 세션별 점검은 `docs/review/noshadow_check_<세션>_2026-10-12.md`.
- 결과: **진함 268 · 약간 178 · 없음 9 · 원본 못 찾음 5** (총 460). 약간도 다시(입체 음영·AO가 색 맵에 구워짐). 없음 = 그대로 씀(대부분 바닥·벽 타일).

## 다시 그리는 법 (이미지 생성 2)
1. 확정 그림 = `py tools/codex_image.py --prompt-file art/prompts/<id>.txt --ref <옛 승인 2D> [--ref <같은 것의 새 앞면>] --out art/out/<...>.png` (사용자 ChatGPT 요금제, Codex 앱). 끝 코드 3 = ChatGPT 사용량 끝 → 그 그림은 Firefly 고급. 후보 탐색은 Firefly 중간.
2. 4면(앞·왼·오른·뒤)을 그림. **앞면을 먼저** 그리고, 나머지 3면은 `--ref <옛 그 면> --ref <새 앞면>`으로. 방향은 말로 쓰지 말고 "ref1과 같은 시점·같은 방향"(10/12 시험: "왼쪽을 본다"고 쓰니 방향이 뒤집힘).
3. 프롬프트에 꼭: "flat even shadowless light from every side, no cast/ground/contact shadow, no ambient-occlusion darkening, no darker side, no strong highlights or reflections, plain base colours, plain light grey background". 단정한 옷, 빛살 금지, 글자 없음.
4. 판정(최종 검수): 옛 2D | 새 2D 나란히 — 모양·색 같고 그림자만 빠졌는지. 통과하면 옛 2D는 바로 지움(사용자 고름).
5. 3D = Blender 손보기: 새 4면 → Tripo 스마트 메시 → 가장 잘 나온 흰 모델(사람은 얼굴 빈 것) → 왼쪽 메뉴 텍스처 '조명 없이' 체크, 8K.
6. 건물 장식은 덩어리 목록 `docs/design/house_chunk_decor_2026-10-12.md` 단위로 그림(작은 조각은 한 장에 묶음).

## 순서
1 빛 마을(게임·WorldKit에 쓰는 것 먼저) → 2 사람(MailBoy 4면 먼저: 시험 판 있음) → 3 무기 → 4 꾸미기 → 5 뿔 마을 → 6 몬스터·펫 → 7 다른 구역 → 9 타일 색 맵(게임에 쓰는 것은 새 판을 넣을 때까지 그대로).

### 1 빛 마을(지금 구역) — 181개 (진함 109 · 약간 72 · 없음 0 · 원본 없음 0)

| 이름 | 판정 | 쓰는 곳 | 그림자 메모 | 다른 문제 | 옛 2D |
|---|---|---|---|---|---|
| HaloDeco_RoundWindow | 진함 | Uploaded flat decoration plate (SA). No placement found in saved main or WorldKit. | 금테 강한 반사광, 유리 하이라이트·구름 반사, 대리석 테 틈 어두움 | other: 평판 장식, 3D 아님 | `art/out/s2/halo/deco/HaloDecoHQ_RoundWindow_src.png` |
| Halo_Balustrade | 진함 | main,main_storage,worldkit | 금 돔·대리석 기둥 강한 반사광, 기둥 사이 틈 어두움, 오른쪽 면 어두움 | 정면 아님(3/4 각도) | `art/out/s2/halo/HaloProp_Balustrade_front_HQ_src.png` |
| Halo_Cathedral | 진함 | main,main_storage,worldkit | 큰 금 돔 강한 반사광(흰 하이라이트), 발광 고리, 덤불 틈 어두움 | 건물+나무·꽃밭 여러 물체 한 장 | `art/out/s2/halo/HaloProp_Cathedral_front_HQ_src.png` |
| Halo_CloudBush | 진함 | main,main_storage,worldkit | 왼쪽 위 따뜻한 빛, 구름 덩이 아래·오른쪽 어둡고 틈 어두움, 광택 |  | `art/out/s2/halo/HaloProp_CloudBush_front_v2_HQ_src.png` |
| Halo_DomeHouseA | 진함 | main,main_storage,worldkit | 금 돔 강한 반사광, 등불 발광이 벽에 비침, 차양 밑 어두움 |  | `art/out/s2/halo/HaloProp_DomeHouseA_front_HQ_src.png` |
| Halo_DomeHouseB | 진함 | main,main_storage,worldkit | 금 돔 강한 반사광, 등불 발광, 발코니·차양 밑 어두움 |  | `art/out/s2/halo/HaloProp_DomeHouseB_front_HQ_src.png` |
| Halo_FarArch | 진함 | main,main_storage,worldkit | 금 돔 강한 반사광, 바위 틈 어두움, 아치 안쪽 그늘 | 바위·물결 받침 포함, 정면 아님(비스듬) | `art/out/s2/halo/HaloProp_FarArch_front_HQ_src.png` |
| Halo_Gate | 진함 | main,main_storage,worldkit | 금 돔 강한 반사광, 발광 고리·등불 빛, 탑 아래쪽 약간 어두움 |  | `art/out/s2/halo/HaloProp_Gate_front_HQ_src.png` |
| Halo_Islet | 진함 | main,main_storage,worldkit | 금 돔 반사광, 바위 틈 짙게 어두움, 덤불 그늘 | 섬+탑+집 여러 물체, 위에서 본 각도(정면 아님) | `art/out/s2/halo/HaloProp_Islet_front_HQ_src.png` |
| Halo_Planter | 진함 | main,main_storage,worldkit | 금 장식 강한 반사광, 왼쪽 밝고 오른쪽 면 어두움, 잎 틈 어두움 | 정면 아님(3/4 위 각도) | `art/out/s2/halo/HaloProp_Planter_front_HQ_src.png` |
| Halo_PotFlowers | 진함 | main,main_storage,worldkit | 바닥 그림자 없음, 금테 강한 반사광, 잎 사이 틈 어두움, 꽃잎 하이라이트 |  | `art/out/s2/halo/HaloProp_PotFlowers_front_HQ_src.png` |
| Halo_RoundTree | 진함 | main,main_storage,worldkit | 왼쪽 위 빛, 잎 덩어리 아래·안쪽 어두움(틈 AO), 줄기 오른쪽 어두움 | 잔디 받침 포함 | `art/out/s2/halo/HaloProp_RoundTree_front_v2_HQ_src.png` |
| Halo_Shop | 진함 | main,main_storage,worldkit | 금 돔 강한 반사광, 등불 발광, 진열칸·차양 아래 어두움 | 화분·덩굴·간판 등 여러 물체 한 그림 | `art/out/s2/halo/HaloProp_Shop_front_HQ_src.png` |
| Halo_Stairs | 진함 | main,main_storage,worldkit | 기둥·난간 오른쪽 면 어두움, 계단 턱 그림자, 금 돔 반사광 | 정면 아닌 사선 시점 | `art/out/s2/halo/HaloProp_Stairs_front_HQ_src.png` |
| Halo_Statue | 진함 | main,main_storage,worldkit,planned_halo_v2 | 금 장식 강한 반사광, 투구 틈·팔 아래 어두움, 대리석 은은한 음영 |  | `art/out/s2/halo/HaloProp_Statue_front_HQ_src.png` |
| Halo_Topiary | 진함 | main,main_storage,worldkit | 잎 사이 틈 어두움, 오른쪽 아래 잎 어두움, 금테 강한 반사광 |  | `art/out/s2/halo/HaloProp_Topiary_front_HQ_src.png` |
| Town_Halo_Bakery | 진함 | main_storage,worldkit | 크루아상 지붕 아래 그림자, 빵 광택 반사, 창문 안 발광, 구름 틈 어두움 | 여러 소품(수레·바구니) 한 그림에 포함 | `art/out/town/Town_Halo_Bakery_1.png` |
| Town_Halo_Castle | 진함 | main_storage,worldkit | 탑 사이 틈 어두움, 아치 안쪽 그림자, 창문 발광, 구름 아래 음영 |  | `art/out/town/Town_Halo_Castle_1.png` |
| Town_Halo_Fountain | 진함 | main,main_storage,worldkit | 금장식·흰 구름 표면 강한 광택 반사광, 아랫단 구름 사이 어두움, 물 반짝임·발광 |  | `art/out/hq/HQ_Town_Halo_Fountain.png` |
| Town_Halo_HouseA | 진함 | main_storage,worldkit | 지붕 처마 아래 그림자, 아래 바닥 그림자 흐림, 창문 발광, 구름 틈 어두움 |  | `art/out/town/Town_Halo_HouseA_1.png` |
| Town_Halo_HouseB | 진함 | main_storage,worldkit | 지붕·발코니 아래 그림자, 계단 쪽 어두움, 창문 발광, 금속 반사 |  | `art/out/town/Town_Halo_HouseB_1.png` |
| Town_Halo_JuiceBar | 진함 | main_storage,worldkit | 아래 바닥 그림자, 차양 아래 어두움, 전등·창문 발광, 강한 반사광 | 과일 상자·의자 등 여러 소품 포함 | `art/out/town/Town_Halo_JuiceBar_1.png` |
| Town_Halo_KnightStatue | 진함 | main_storage,worldkit | 받침 아래 바닥 그림자, 망토 안쪽 어두움, 갑옷 광택 반사 |  | `art/out/hq/HQ_Town_Halo_KnightStatue.png` |
| Town_Halo_Potion | 진함 | main_storage,worldkit | 바닥 그림자, 차양·창 안쪽 어두움, 유리병 강한 반사광, 등불 발광 | 상자·화분 등 여러 소품 포함 | `art/out/town/Town_Halo_Potion_2.png` |
| Town_Halo_Smithy | 진함 | main_storage,worldkit | 바닥 그림자, 처마 아래·대장간 안쪽 어두움, 틈 AO, 금속 반사광 | 여러 물건 함께(칼·방패·통·연기) | `art/out/town/Town_Halo_Smithy_2.png` |
| Town_Halo_Spawn | 진함 | main_storage | 구름 아래 어두움, 틈 AO, 금 반사광 강함, 발광 | 정면 아님(위에서 비스듬히) | `art/out/town3/Town_Halo_Spawn_src.png` |
| Town_Halo_Tree | 진함 | main_storage | 잎 뭉치 아래 어두운 음영, 화분 아래 바닥 그림자, 반사광 |  | `art/out/town3/Town_Halo_Tree_src.png` |
| Town_Halo_WallTower | 진함 | main_storage,worldkit | 오른쪽 면 어두움, 지붕 아래 그림자, 금 반사광 |  | `art/out/hq/HQ_Town_Halo_WallTower.png` |
| HaloDeco_AwningStripes | 약간 | Uploaded flat decoration plate (SA). No placement found in saved main or WorldKit. | 금봉·테두리 반사광, 천 면은 거의 평평, 바닥 그림자 없음 | other: 평판 장식 | `art/out/s2/halo/deco/HaloDecoHQ_AwningStripes_src.png` |
| HaloDeco_BannerEmblem | 약간 | WorldKit ImportHold Gate_Assembled_v3 (main 아님) | 천 평면색, 금 막대·고리 반사광, 보석 하이라이트, 고리 아래 옅은 음영 | other 카테고리: 평판 ColorMap | `art/out/s2/halo/deco/HaloDecoHQ_BannerEmblem_src.png` |
| HaloDeco_BannerPlain | 약간 | WorldKit ImportHold Gate_Assembled_v3, TowerC_Assembled (main 아님) | 천은 거의 평면색, 금 막대·공 반사광, 막대 아래 옅은 그림자 | other 카테고리: 평판 ColorMap으로 직접 사용 | `art/out/s2/halo/deco/HaloDecoHQ_BannerPlain_src.png` |
| Halo_ArchBridge | 약간 | main,main_storage,worldkit | 아치 안쪽·난간 밑 어두움, 금색 약한 반사광, 바닥 그림자 없음 |  | `art/out/s2/halo/HaloProp_ArchBridge_front_HQ_src.png` |
| Halo_BannerPole | 약간 | main,main_storage,worldkit | 금 돔 반사광, 기둥 오른쪽 약간 어두움, 바닥 그림자 없음 | 정면 아님(살짝 비스듬) | `art/out/s2/halo/HaloProp_BannerPole_front_HQ_src.png` |
| Halo_Lantern | 약간 | main,main_storage,worldkit | 등불 발광, 금 지붕 반사광, 기둥 오른쪽 약간 어두움 | 정면 아님(살짝 비스듬) | `art/out/s2/halo/HaloProp_Lantern_front_HQ_src.png` |
| Halo_Tower | 약간 | main,main_storage,worldkit | 원기둥 가장자리 약한 음영, 금 돔 하이라이트, 창문 발광 | 후광 떠 있음 | `art/out/s2/halo/HaloProp_Tower_front_HQ_src.png` |
| Town_Halo_Bridge | 약간 | main_storage,worldkit | 다리 아래 구름 쪽 부드러운 음영, 금속 반사광, 바닥 그림자 없음 | 정면 아닌 비스듬한 시점 | `art/out/hq/HQ_Town_Halo_Bridge.png` |
| Town_Halo_Fountain3 | 약간 | main,main_storage,worldkit,planned_halo_v2 | 그릇 아래 약한 음영, 금 공 반사광, 물 반짝임 | 정면 아닌 위쪽 사선 시점, 물줄기 포함 | `art/out/s2/halo/HaloProp_Fountain_front_HQ_src.png` |
| Town_Halo_Gate | 약간 | main_storage | 날개·구름 아래쪽 부드러운 음영, 금속 반사 약함, 바닥 그림자 없음 |  | `art/out/town3/Town_Halo_Gate_src.png` |
| Town_Halo_HouseC | 약간 | main_storage,worldkit | 지붕 처마·발코니 아래 부드러운 음영, 금속 반사, 바닥 그림자 없음 |  | `art/out/hq/HQ_Town_Halo_HouseC.png` |
| Town_Halo_Wall | 약간 | main_storage | 구름 아래·벽돌 틈 약한 음영, 금 반사광, 바닥 그림자 없음 | 정면 아님(비스듬히) | `art/out/town3/Town_Halo_Wall_src.png` |
| HaloArmory | 진함 | Halo v2 training yard: Studio part skeleton already built in WorldKit (tools/skeleton_civic.py). No Tripo decor yet; the 2D is the look reference. | 바닥 그림자 없음. 벽 등불이 켜져 벽에 노란 빛이 번짐(조명 박힘), 처마 아래·창 안쪽 어두움, 금 장식 반사광 | 건물 앞에 무기걸이·상자·통 등 소품 같이 그려짐 | `art/out/s2/halo/houses_new/HaloArmory_front.png` |
| HaloBushHQ_HedgeBlue | 진함 | On hold, no 3D. | 잎 사이 틈 어두움(AO), 아랫부분 어두움, 잎 광택 |  | `art/out/s2/halo/bushes_hq/HaloBushHQ_HedgeBlue.png` |
| HaloBushHQ_HedgePink | 진함 | On hold, no 3D. | 잎 사이 틈 어두움, 아래쪽 어두움, 잎 광택 | 정면 아님(살짝 위·옆에서 본 각도) | `art/out/s2/halo/bushes_hq/HaloBushHQ_HedgePink.png` |
| HaloBushHQ_Hydrangea | 진함 | On hold, no 3D. | 잎 강한 광택 반사광, 꽃송이 아래·잎 사이 어두움 |  | `art/out/s2/halo/bushes_hq/HaloBushHQ_Hydrangea.png` |
| HaloBushHQ_Rose | 진함 | On hold: High front only, deliberately not sent to Tripo (multiview-only rule). May be superseded by NEW_FlowerBush / NEW_Hedge. | 잎 사이 깊은 틈 어두움(AO), 잎 광택 반사, 꽃잎 음영 |  | `art/out/s2/halo/bushes_hq/HaloBushHQ_Rose.png` |
| HaloBushHQ_WhiteBlossom | 진함 | On hold, no 3D. | 덤불 안쪽 틈 짙게 어두움, 잎 광택 |  | `art/out/s2/halo/bushes_hq/HaloBushHQ_WhiteBlossom.png` |
| HaloCastle_C2 | 진함 | Halo v2 Castle (-176,-574) skeleton only | 탑·지붕 오른쪽 면 어두움, 문 안쪽·틈 어두운 AO, 창문 발광, 날개 음영 | 물체 여러 개(성 전체+나무+계단+받침) 한 장, 정면 아닌 살짝 위 시점 | `art/out/s2/halo/castle6/HaloCastle_C2_front_HQ_src.png` |
| HaloCastle_C2_GateLeaf | 진함 | - | 금속 강한 반사광 줄·하이라이트, 홈 안쪽 어두운 음영 |  | `art/out/s2/halo/castle6/HaloCastle_C2_gateleaf_HQ_src.png` |
| HaloDeco_DoorHalo | 진함 | WorldKit ImportHold Cath_Assembled_v2 | 금 고리 강한 반사광, 안쪽·아래 어두운 음영, 소용돌이 장식 음영 | other 카테고리: 평판 ColorMap; 물체 여러 개(고리+양쪽 깃발) | `art/out/s2/halo/deco/HaloDecoHQ_DoorHalo_src.png` |
| HaloDeco_ShieldEmblem | 진함 | WorldKit ImportHold Gate_Assembled_v3 | 금 방패 강한 반사광·하이라이트, 아래쪽 어두운 음영, 보석 반사 | other 카테고리: 평판 ColorMap | `art/out/s2/halo/deco/HaloDecoHQ_ShieldEmblem_src.png` |
| HaloDomeHouse_02 | 진함 | import_hold,planned_halo_v2 | 금 돔 강한 하이라이트·반사, 차양 아래·틈 어두움, 등불 빛남 |  | `art/out/s2/halo/houses/HaloDomeHouse_02_front_HQ_recolor.png` |
| HaloDomeHouse_03 | 진함 | import_hold,planned_halo_v2 | 금 돔 강한 반사광, 원통 벽 양옆 어두움, 틈 AO |  | `art/out/s2/halo/houses/HaloDomeHouse_03_front_HQ_src.png` |
| HaloDomeHouse_04 | 진함 | import_hold,planned_halo_v2 | 양파 돔 강한 반사광·명암, 틈 어두움 |  | `art/out/s2/halo/houses/HaloDomeHouse_04_front_HQ_src.png` |
| HaloDomeHouse_06 | 진함 | import_hold,planned_halo_v2 | 금 돔 강한 반사광, 원통 벽 옆 어두움, 발코니 아래 그늘 | 차양 색 얼룩(recolor 흔적) | `art/out/s2/halo/houses/HaloDomeHouse_06_front_HQ_recolor.png` |
| HaloDomeHouse_08 | 진함 | import_hold,planned_halo_v2 | 금 돔 2개 강한 반사광, 발코니·틈 어두움 |  | `art/out/s2/halo/houses/HaloDomeHouse_08_front_HQ_src.png` |
| HaloDomeHouse_09 | 진함 | import_hold,planned_halo_v2 | 금 돔 강한 하이라이트, 원통 벽 양옆 어두움, 덩굴 아래 그늘 |  | `art/out/s2/halo/houses/HaloDomeHouse_09_front_HQ_src.png` |
| HaloDomeHouse_10 | 진함 | import_hold,planned_halo_v2 | 금 돔 반사광, 발코니 아래·틈 어두움, 등불 빛남 | 차양 색 얼룩(recolor 흔적) | `art/out/s2/halo/houses/HaloDomeHouse_10_front_HQ_recolor.png` |
| HaloFlagpole_1 | 진함 | built_parts_only,planned_halo_v2 | 받침 오른쪽 면 어두움, 금 공 강한 반사광 | 정면 아닌 3/4 시점 | `art/out/s2/halo/poles/HaloFlagpole_1_front_HQ_src.png` |
| HaloFlagpole_3 | 진함 | built_parts_only,planned_halo_v2 | 받침 계단 오른쪽 면 어두움, 금 공 강한 반사광 | 정면 아닌 3/4 시점 | `art/out/s2/redo/HaloFlagpole_3_front_v2.png` |
| HaloNewHouse_Cliff6 | 진함 | - | 발코니·처마 아래 어두운 틈, 등불 발광, 금 반사광 |  | `art/out/s2/halo/houses_new4/HaloNewHouse_Cliff6_front.png` |
| HaloNewHouse_Cliff7 | 진함 | - | 지붕 아래·문틀 틈 어두움, 등불 발광, 금 반사광 |  | `art/out/s2/halo/houses_new4/HaloNewHouse_Cliff7_front.png` |
| HaloNewHouse_Cliff8 | 진함 | - | 차양·처마 아래 어두움, 등불 발광, 금 반사광 | 창문에 바다 풍경 그림 | `art/out/s2/halo/houses_new4/HaloNewHouse_Cliff8_front.png` |
| HaloNewHouse_Garden5 | 진함 | - | 차양 아래·덩굴 틈 어두움, 등불 발광, 금 반사광 |  | `art/out/s2/halo/houses_new4/HaloNewHouse_Garden5_front.png` |
| HaloNewHouse_Garden6 | 진함 | - | 처마·차양 아래 어두움, 등불 발광, 금 반사광 |  | `art/out/s2/halo/houses_new4/HaloNewHouse_Garden6_front.png` |
| HaloNewHouse_Garden7 | 진함 | - | 층 띠 아래·발코니 아래 어두움, 등불 발광, 금 반사광 |  | `art/out/s2/halo/houses_new4/HaloNewHouse_Garden7_front.png` |
| HaloNewHouse_Hill4 | 진함 | - | 처마·차양 아래 틈 어두움, 등불 발광, 금장식 강한 반사광 |  | `art/out/s2/halo/houses_new4/HaloNewHouse_Hill4_front.png` |
| HaloPart_CathDome | 진함 | import_hold,planned_halo_v2 | 금 돔 강한 반사광·하이라이트, 처마 아래 어두움, 밑면 회색 음영 |  | `art/out/s2/halo/parts/HaloPart_CathDome_v2_front_HQ_src.png` |
| HaloPart_GateDomeL | 진함 | import_hold,planned_halo_v2 | 금 돔 강한 반사광 점·밝고 어두운 면 뚜렷 |  | `art/out/s2/halo/parts/HaloPart_GateDomeL_front_HQ_src.png` |
| HaloPart_GateDomeR | 진함 | import_hold,planned_halo_v2 | 금 돔 강한 반사광 점·밝고 어두운 면 뚜렷 |  | `art/out/s2/halo/parts/HaloPart_GateDomeR_front_HQ_src.png` |
| HaloPart_GateLantern | 진함 | import_hold,planned_halo_v2 | 등불 빛(발광) 그려짐, 금 강한 반사광 |  | `art/out/s2/halo/parts/HaloPart_GateLantern_v2_front_HQ_src.png` |
| HaloPart_GateTowerL | 진함 | import_hold,planned_halo_v2 | 창 안에 불빛(발광) 그려짐, 원통 측면 음영, 금 띠 광택 |  | `art/out/s2/halo/parts/HaloPart_GateTowerL_front_HQ_src.png` |
| HaloPart_TowerDome | 진함 | import_hold,planned_halo_v2 | 금 돔에 강한 반사광 점과 하이라이트, 아래 띠 어두운 반사 |  | `art/out/s2/halo/parts/HaloPart_TowerDome_v2_front_HQ_src.png` |
| HaloProp_GateLantern (gate pedestal lamp head) | 진함 | - | 지붕 왼쪽 면 어두움, 금 강한 반사광, 받침 아래 어두움, 안쪽 발광 | 정면 아닌 살짝 위 시점 | `art/out/s2/halo/HaloProp_GateLantern_front_HQ_src.png` |
| HaloReasonHQ_GuardPost | 진함 | built_parts_only,planned_halo_v2 | 금 돔에 강한 반사광, 차양 아래 그늘, 등불 발광 | 초소+빈 간판 두 물체가 한 그림 | `art/out/s2/halo/reason_hq/HaloReasonHQ_GuardPost.png` |
| HaloReasonHQ_PhotoDisc | 진함 | built_parts_only,planned_halo_v2 | 금 원판 강한 반사광, 앞·오른쪽 옆면 어두움 | 위에서 본 아이소 각도, 정면 아님 | `art/out/s2/halo/reason_hq/HaloReasonHQ_PhotoDisc.png` |
| HaloShop_Bakery | 진함 | import_hold,planned_halo_v2 | 차양이 창에 그림자 드리움, 등불 발광, 창 안·덩굴 틈 어두움, 금 반사광 |  | `art/out/s2/halo/shops/HaloShop_Bakery_front_HQ_src.png` |
| HaloShop_Flower | 진함 | import_hold,planned_halo_v2 | 차양 아래 그늘, 등불 발광, 덩굴·화분 틈 어두움, 유리지붕 반사 |  | `art/out/s2/halo/roofs/HaloShop_Flower_roof_v2.png` |
| HaloShop_Juice | 진함 | import_hold,planned_halo_v2 | 차양 아래 가게 안 어두움, 등불 발광, 덩굴 틈 어두움, 금 반사광 |  | `art/out/s2/halo/roofs/HaloShop_Juice_roof_v2.png` |
| HaloShop_Potion | 진함 | import_hold,planned_halo_v2 | 금 돔 강한 반사광, 등불·물약 발광, 차양 아래·창 안 어두움 |  | `art/out/s2/halo/shops/HaloShop_Potion_front_HQ_src.png` |
| HaloSign_Bakery | 진함 | MAIN + WorldKit | 금색 반사광 강함, 빵 아래쪽과 테두리 틈 어두움, 팔걸이 아래 음영 | 회색 배경, 표지판+팔걸이+사슬이 한 장에 같이 있음 | `art/out/s2/halo/HaloSign_Bakery_front_HQ_src.png` |
| HaloSign_Flower | 진함 | MAIN + WorldKit | 금속에 반사광, 꽃잎 아래와 잎 사이 틈 어두움, 팔걸이 아래 음영 | 회색 배경, 표지판+팔걸이+사슬이 한 장에 같이 있음 | `art/out/s2/halo/HaloSign_Flower_front_HQ_src.png` |
| HaloSign_Juice | 진함 | MAIN + WorldKit | 금속 공과 테두리에 강한 반사광, 기둥 오른쪽 면 어두움, 유리잔 반사 | 회색 배경, 표지판+팔걸이+사슬이 한 장에 같이 있음 | `art/out/s2/halo/HaloSign_Juice_front_HQ_src.png` |
| HaloSign_Potion | 진함 | MAIN + WorldKit | 금속 장식과 유리병에 강한 반사광, 팔걸이 아래와 기둥 틈 어두움, 공에 음영 | 회색 배경, 표지판+팔걸이+사슬이 한 장에 같이 있음 | `art/out/s2/halo/HaloSign_Potion_front_v2_HQ_src.png` |
| HaloStairs_3 | 진함 | built_parts_only,planned_halo_v2 | 수풀 틈 진한 그늘(AO), 금 장식 반사광, 바닥 그림자 없음 | 계단+화단+나무 여러 물체 한 장 | `art/out/s2/halo/stairs/HaloStairs_3_front_HQ_src.png` |
| HaloStairs_5 | 진함 | built_parts_only,planned_halo_v2 | 수풀 틈 진한 그늘, 계단 옆면 어둡게, 금 반사광 | 계단+화단+나무 여러 물체, 정면 아님 | `art/out/s2/redo/HaloStairs_5_front.png` |
| HaloVar3_Balustrade_E | 진함 | built_parts_only,planned_halo_v2 | 금 돔 강한 반사·어두운 아랫면, 아치 안쪽·받침 틈 어둡게 | 정면 아님(3/4 시점) | `art/out/s2/halo/variants/HaloVar3_Balustrade_E_HQ_src.png` |
| HaloVar3_Balustrade_F | 진함 | built_parts_only,planned_halo_v2 | 잎 틈 진한 그늘(AO), 금 돔 강한 반사, 기둥 사이 어둡게 | 정면 아님(3/4 시점) | `art/out/s2/halo/variants/HaloVar3_Balustrade_F_HQ_src.png` |
| HaloVar3_CloudBush_E | 진함 | built_parts_only,on_hold | 구름 공 사이 틈 어두움, 화분 아래쪽·안쪽 그림자, 금속 강한 반사광 |  | `art/out/s2/halo/variants/HaloVar3_CloudBush_E_HQ_src.png` |
| HaloVar3_CloudBush_F | 진함 | built_parts_only,on_hold | 공 사이 틈 어두움(AO), 화분 아래 어두움, 금테 강한 반사광 |  | `art/out/s2/halo/variants/HaloVar3_CloudBush_F_HQ_src.png` |
| HaloVar3_Lantern_E | 진함 | built_parts_only,planned_halo_v2 | 금 지붕 강한 반사광·어두운 띠, 창 발광, 받침 단 아래 약간 어둡게 | 정면 아님(3/4 시점) | `art/out/s2/halo/variants/HaloVar3_Lantern_E_HQ_src.png` |
| HaloVar3_Planter_E | 진함 | built_parts_only,planned_halo_v2 | 잎 틈 진한 그늘, 금 돔·테두리 강한 반사, 위층 아래 어둡게 | 정면 아님(3/4 시점) | `art/out/s2/halo/variants/HaloVar3_Planter_E_HQ_src.png` |
| HaloVar3_PotFlowers_E | 진함 | built_parts_only,planned_halo_v2 | 잎 틈 진한 그늘, 화분 아랫부분 어둡게, 금 테 강한 반사 |  | `art/out/s2/halo/variants/HaloVar3_PotFlowers_E_HQ_src.png` |
| HaloVar3_PotFlowers_F | 진함 | built_parts_only,planned_halo_v2 | 덩굴 잎 틈 진한 그늘, 화분 양옆 어둡게, 금 반사광 |  | `art/out/s2/halo/variants/HaloVar3_PotFlowers_F_HQ_src.png` |
| HaloVar3_RoundTree_E | 진함 | import_hold,planned_halo_v2 | 잎 뭉치 아래·틈 진한 그늘, 열매 반사광, 금 테 반사 |  | `art/out/s2/halo/variants/HaloVar3_RoundTree_E_HQ_src.png` |
| HaloVar3_RoundTree_F | 진함 | built_parts_only,planned_halo_v2 | 왼쪽 위 햇빛 방향광, 잎 사이 틈 어두움, 화분 금테 강한 반사광 | 정면 아님(살짝 위에서 본 3/4) | `art/out/s2/halo/variants/HaloVar3_RoundTree_F_HQ_src.png` |
| HaloVar3_RoundTree_G | 진함 | built_parts_only,planned_halo_v2 | 잎 덩어리 아래·오른쪽 어두움, 잎 틈 어두움, 금테 반사광 | 정면 아님(위에서 본 각도) | `art/out/s2/halo/variants/HaloVar3_RoundTree_G_HQ_src.png` |
| HaloVar3_Topiary_C | 진함 | built_parts_only,planned_halo_v2 | 잎 공 아래쪽 어둡고 틈 어두움, 왼쪽 위 밝은 빛, 금테 반사광 |  | `art/out/s2/halo/variants/HaloVar3_Topiary_C_HQ_src.png` |
| HaloVar3_Topiary_D | 진함 | built_parts_only,planned_halo_v2 | 나선 잎 아래 어두움, 잎 틈 어두움, 금 장식 강한 반사광 | 정면 아님(위에서 본 3/4) | `art/out/s2/halo/variants/HaloVar3_Topiary_D_HQ_src.png` |
| HaloVar3_Topiary_E | 진함 | built_parts_only,planned_halo_v2 | 왼쪽 밝고 오른쪽 면 어두움, 잎 틈 어두움, 금 장식 반사광 | 정면 아님(3/4 위 각도) | `art/out/s2/halo/variants/HaloVar3_Topiary_E_HQ_src.png` |
| HaloVar4_Lantern_B | 진함 | built_parts_only,planned_halo_v2 | 구형 등 강한 빛 번짐·광택, 금 강한 반사광, 받침 아래 단 어두움 | 정면 아님(위 3/4 각도) | `art/out/s2/halo/variants4/HaloVar4_Lantern_B_HQ_src.png` |
| HaloVar4_Lantern_D | 진함 | built_parts_only,planned_halo_v2 | 금색 강한 반사광, 옆면·아래쪽 어둡게 음영, 바닥 그림자 없음 | 정면 아님(3/4 각도) | `art/out/s2/halo/variants4/HaloVar4_Lantern_D_HQ_src.png` |
| HaloVar4_Planter_A | 진함 | built_parts_only,planned_halo_v2 | 잎 사이 틈 어두움(AO), 화분 오른쪽·아래 면 어두움, 금색 강한 반사광 | 정면 아님(3/4 위에서 본 각도) | `art/out/s2/halo/variants4/HaloVar4_Planter_A_HQ_src.png` |
| HaloVar4_Planter_D | 진함 | built_parts_only,planned_halo_v2 | 잎 사이 틈 어두움, 오른쪽 아래 잎 어둡게, 금색 반사광 | 정면 아님(살짝 위에서 본 각도) | `art/out/s2/halo/variants4/HaloVar4_Planter_D_HQ_src.png` |
| HaloVar4_PotFlowers_A | 진함 | built_parts_only,planned_halo_v2 | 잎 틈 어두움, 화분 아래쪽 음영, 금색 강한 반사광 |  | `art/out/s2/halo/variants4/HaloVar4_PotFlowers_A_HQ_src.png` |
| HaloVar4_PotFlowers_C | 진함 | built_parts_only,planned_halo_v2 | 잎 틈 어두움, 항아리 둥근 면 음영, 금색 강한 반사광 |  | `art/out/s2/halo/variants4/HaloVar4_PotFlowers_C_HQ_src.png` |
| HaloVar4_PotFlowers_D | 진함 | built_parts_only,planned_halo_v2 | 잎 틈 어두움, 그릇 아래쪽 음영, 금색 강한 반사광 |  | `art/out/s2/halo/variants4/HaloVar4_PotFlowers_D_HQ_src.png` |
| NEW_BellFrame | 진함 | Halo v2 (cliff homes): the wooden frame is a part kit in WorldKit. Only the bell is already Tripo'd (NEW_BellFrame_Bell, in the list). Frame 4-view exists, no Tripo yet. | 바닥 그림자 없음. 종·금 장식에 강한 반사광(거울 같은 하이라이트와 어두운 반사), 종 안쪽 어두움 | 비스듬한 시점, 종이 같이 그려짐(종은 따로 Tripo됨) | `art/out/s2/halo/kits_mv/HaloKit_BellFrame_front_HQ_src.png` |
| NEW_BellFrame_Bell | 진함 | - | 금 종 강한 반사광·하이라이트, 종 안쪽·양옆 어두움 |  | `art/out/s2/halo/kits_mv3/HaloKit_BellOnly_front_HQ_src.png` |
| NEW_BreadBasket | 진함 | - | 빵 사이·바구니 엮은 틈 어둡게, 금 반사광, 바구니 아래쪽 어두움 |  | `art/out/s2/halo/kits_mv2/HaloKit_BreadBasket_front_HQ_src.png` |
| NEW_CafeTable | 진함 | Halo v2 (market alley): part kit in WorldKit. Tripo planned, not made. | 바닥 그림자 없음. 대리석 상판 왼쪽 흰 반사점, 금 테두리 강한 광택 반사, 기둥 아래 약간 어두움 |  | `art/out/s2/halo/kits_new/HaloKit_CafeTable_front.png` |
| NEW_Cauldron | 진함 | Halo v2 (potion shop): part kit in WorldKit. Tripo planned, not made. | 솥 몸통 위쪽 하이라이트·아래쪽 어두운 음영, 다리 밑 받침에 어두운 접촉 그림자, 물약 표면 반사광·빛남 |  | `art/out/s2/halo/kits_new/HaloKit_Cauldron_front.png` |
| NEW_FlowerBush | 진함 | - | 잎 강한 광택 반사광, 잎 사이 틈 어두움 |  | `art/out/s2/halo/kits_mv/HaloKit_FlowerBush_front_HQ_src.png` |
| NEW_GatherBush | 진함 | - | 잎 사이 틈 어둡게, 금속 강한 반사광, 화분 아래쪽 어두움 |  | `art/out/s2/halo/kits_mv/HaloKit_GatherBush_front_HQ_src.png` |
| NEW_Hedge | 진함 | - | 잎 사이 틈 진하게 어둡고 아래쪽 어두움, 잎 광택 |  | `art/out/s2/halo/kits_mv2/HaloKit_Hedge_front_HQ_src.png` |
| NEW_Telescope | 진함 | Halo v2 (cliff homes): part kit in WorldKit. 4-view 2D is ready, no Tripo yet. | 바닥 그림자 없음. 렌즈 유리 강한 반사광, 금 링 거울 같은 반사, 다리 나무 한쪽 어두움 | 비스듬한 시점 | `art/out/s2/halo/kits_mv/HaloKit_Telescope_front_HQ_src.png` |
| NEW_WallLamp | 진함 | - | 금속 강한 반사광, 촛불 빛, 팔 아래쪽 어두움 | 앞면이 아닌 비스듬한 각도 | `art/out/s2/halo/kits_mv/HaloKit_WallLamp_front_HQ_src.png` |
| NEW_WallLamp_Head | 진함 | - | 금 테두리 강한 반사광, 안쪽 촛불 발광 칠해짐, 아래 테 어두움 |  | `art/out/s2/halo/kits_mv3/HaloKit_WallLampHead_front.png` |
| NEW_WateringCan | 진함 | - | 금 부분 강한 반사광, 몸통 오른쪽·밑 어두움 |  | `art/out/s2/halo/kits_mv2/HaloKit_WateringCan_front_HQ_src.png` |
| NEW_WhiteRock_a | 진함 | - | 면마다 밝기 차이(오른쪽·아래 면 어두움), 균열 틈 어두움, 광택 |  | `art/out/s2/halo/kits_mv2/HaloKit_WhiteRock_a_front_HQ_src.png` |
| NEW_WhiteRock_b | 진함 | - | 왼쪽 위 빛, 아래·오른쪽 면 어두움, 틈 어두움, 광택 |  | `art/out/s2/halo/kits_mv2/HaloKit_WhiteRock_b_front_HQ_src.png` |
| NEW_WhiteRock_c | 진함 | - | 바위 사이 틈·아래쪽 어두움, 면 명암 뚜렷, 광택 | 바위 3개가 한 이미지 | `art/out/s2/halo/kits_mv2/HaloKit_WhiteRock_c_front_HQ_src.png` |
| HaloBridge_1 | 약간 | built_parts_only,planned_halo_v2 | 바닥 그림자 없음, 블록 틈·아치 안쪽 약한 음영, 금 구슬 반사광 | 정면 아닌 옆/위 시점 | `art/out/s2/halo/bridges/HaloBridge_1_side_HQ_src.png` |
| HaloBridge_2 | 약간 | built_parts_only,planned_halo_v2 | 바닥 그림자 없음, 계단·블록 틈 약한 음영, 금 구슬 반사광 |  | `art/out/s2/redo/HaloBridge_2_side_v2.png` |
| HaloBridge_3 | 약간 | built_parts_only,planned_halo_v2 | 바닥 그림자 없음, 돌 턱 아래·틈 약한 어두움, 금구슬 반사광 | 정면 아닌 옆면 이미지 | `art/out/s2/halo/bridges/HaloBridge_3_side_HQ_src.png` |
| HaloDomeHouse_01 | 약간 | import_hold,planned_halo_v2 | 바닥 그림자 없음, 원통 벽 양끝 어두움, 틈 AO, 금장식 반사광, 등불 빛남 |  | `art/out/s2/halo/roofs/HaloDomeHouse_01_roof_v2.png` |
| HaloDomeHouse_05 | 약간 | import_hold,planned_halo_v2 | 바닥 그림자 없음, 차양·턱 아래 약한 어두움, 금 반사광, 등불 빛남 |  | `art/out/s2/halo/roofs/HaloDomeHouse_05_roof_v2.png` |
| HaloDomeHouse_07 | 약간 | import_hold,planned_halo_v2 | 파란 기와 광택 하이라이트, 벽 옆 약한 어두움, 틈 AO, 등불 빛남 |  | `art/out/s2/halo/roofs/HaloDomeHouse_07_roof_v2.png` |
| HaloDomeHouse_11 | 약간 | import_hold,planned_halo_v2 | 파란 기와 광택 하이라이트, 처마 아래 약한 그늘, 금 반사광 |  | `art/out/s2/halo/roofs/HaloDomeHouse_11_roof_v2.png` |
| HaloDomeHouse_12 | 약간 | import_hold,planned_halo_v2 | 바닥 그림자 없음, 금 장식 반사광·틈 약간 어두움, 등불 발광 | 건물+화분·덩굴 여러 요소 한 장 | `art/out/s2/halo/roofs/HaloDomeHouse_12_roof_v2.png` |
| HaloFlagpole_2 | 약간 | built_parts_only,planned_halo_v2 | 기둥 가장자리 부드러운 음영, 금 반사광 | 약간 위에서 본 시점 | `art/out/s2/halo/poles/HaloFlagpole_2_front_HQ_src.png` |
| HaloFloor_Medallion_A | 약간 | MAIN + WorldKit | 바닥 그림자는 없음. 금색 링과 잎에 반사광과 약한 볼륨 음영이 있고 대리석은 평평함 | 회색 배경 모서리(원 밖) | `art/out/s2/halo/HaloFloor_Medallion_A_HQ_src.png` |
| HaloFlowerPotHQ_Daisy | 약간 | built_parts_only,planned_halo_v2 | 잎 사이 틈 어두움, 금 반사광, 바닥 그림자 없음 | 위에서 본 3/4 시점 | `art/out/s2/halo/flowerpots_hq/HaloFlowerPotHQ_Daisy.png` |
| HaloFlowerPotHQ_Lavender | 약간 | built_parts_only,planned_halo_v2 | 화병 광택 반사광, 가장자리 약한 음영 |  | `art/out/s2/halo/flowerpots_hq/HaloFlowerPotHQ_Lavender.png` |
| HaloFlowerPotHQ_Rose | 약간 | built_parts_only,planned_halo_v2 | 잎 사이 틈 어두움, 화분 광택 반사광 |  | `art/out/s2/halo/flowerpots_hq/HaloFlowerPotHQ_Rose.png` |
| HaloFlowerPotHQ_Sunflower | 약간 | built_parts_only,planned_halo_v2 | 잎 아래 틈 어두움, 금띠 반사광 |  | `art/out/s2/halo/flowerpots_hq/HaloFlowerPotHQ_Sunflower.png` |
| HaloFlowerPotHQ_Tulip | 약간 | built_parts_only,planned_halo_v2 | 오른쪽 면 약간 어두움, 잎 틈 음영, 금 반사광 | 모서리 정면(3/4) 시점 | `art/out/s2/halo/flowerpots_hq/HaloFlowerPotHQ_Tulip.png` |
| HaloPart_CathBody | 약간 | import_hold,planned_halo_v2 | 기둥 옆·창 안쪽 약한 음영, 금 반사광 |  | `art/out/s2/halo/parts/HaloPart_CathBody_v2_front_HQ_src.png` |
| HaloPart_CathDoorFrame | 약간 | import_hold,planned_halo_v2 | 아치 안쪽·받침 틈 약한 음영, 금 반사광 |  | `art/out/s2/halo/parts/HaloPart_CathDoorFrame_front_HQ_src.png` |
| HaloPart_CathDoorLeaf | 약간 | import_hold,planned_halo_v2 | 바닥 그림자 없음, 금속 테두리 반사광·부드러운 음영 |  | `art/out/s2/halo/parts/HaloPart_CathDoorLeaf_front_HQ_src.png` |
| HaloPart_CathStairs | 약간 | import_hold,planned_halo_v2 | 바닥 그림자 없음, 계단 아랫면·틈 약간 어두움, 금 장식 반사광 | 정면이 아닌 약간 위에서 본 시점 | `art/out/s2/halo/parts/HaloPart_CathStairs_front_HQ_src.png` |
| HaloPart_CathTowerA | 약간 | import_hold,planned_halo_v2 | 원통 양옆 음영, 금 돔 반사광, 바닥 그림자 없음 |  | `art/out/s2/halo/parts/HaloPart_CathTowerA_v2_front_HQ_src.png` |
| HaloPart_CathTowerB | 약간 | import_hold,planned_halo_v2 | 원통 측면 음영, 금 돔 강한 반사광, 바닥 그림자 없음 |  | `art/out/s2/halo/parts/HaloPart_CathTowerB_v2_front_HQ_src.png` |
| HaloPart_CathWindow | 약간 | import_hold,planned_halo_v2 | 유리 반사 하이라이트, 금 테두리 광택, 바닥 그림자 없음 |  | `art/out/s2/halo/parts/HaloPart_CathWindow_front_HQ_src.png` |
| HaloPart_GateArch | 약간 | import_hold,planned_halo_v2 | 아치 안쪽 벽 약간 어두움, 금 띠 광택, 바닥 그림자 없음 |  | `art/out/s2/halo/parts/HaloPart_GateArch_front_HQ_src.png` |
| HaloPart_GateDoorLeafL | 약간 | import_hold,planned_halo_v2 | 금 경첩·고리 광택, 부드러운 음영, 바닥 그림자 없음 |  | `art/out/s2/halo/parts/HaloPart_GateDoorLeafL_front_HQ_src.png` |
| HaloPart_GateDoorLeafR | 약간 | import_hold,planned_halo_v2 | 금 경첩·고리 광택, 부드러운 음영, 바닥 그림자 없음 | 문짝에 돌 테두리까지 붙어 있음(L과 모양 다름) | `art/out/s2/halo/parts/HaloPart_GateDoorLeafR_front_HQ_src.png` |
| HaloPart_GateTowerR | 약간 | import_hold,planned_halo_v2 | 바닥 그림자 없음, 원통 오른쪽·아래 면 약간 어두움, 금 띠 반사광 |  | `art/out/s2/halo/parts/HaloPart_GateTowerR_v2_front_HQ_src.png` |
| HaloPart_TowerBody | 약간 | import_hold,planned_halo_v2 | 바닥 그림자 없음, 원통 가장자리 약한 음영, 금 장식 반사광, 아치 안쪽 약간 어두움 |  | `art/out/s2/halo/parts/HaloPart_TowerBody_front_HQ_src.png` |
| HaloPart_TowerDoorFrame | 약간 | import_hold,planned_halo_v2 | 바닥 그림자 없음, 금 기둥 반사광, 기둥 옆면 약한 음영 |  | `art/out/s2/halo/parts/HaloPart_TowerDoorFrame_v2_front_HQ_src.png` |
| HaloPart_TowerDoorLeaf | 약간 | import_hold,planned_halo_v2 | 바닥 그림자 없음, 금 테두리 광택, 판자 틈 약간 어두움 |  | `art/out/s2/halo/parts/HaloPart_TowerDoorLeaf_front_HQ_src.png` |
| HaloPart_TowerWindow | 약간 | import_hold,planned_halo_v2 | 바닥 그림자 없음, 유리 반사 하이라이트, 금 틀 약한 광택 |  | `art/out/s2/halo/parts/HaloPart_TowerWindow_front_HQ_src.png` |
| HaloProp_GatePedestal | 약간 | - | 기둥 사이 틈 옅게 어두움, 블록 아래 가장자리 음영, 금 반사광, 바닥 그림자 없음 | 랜턴 포함 물체 여러 개(기둥+난간+랜턴) | `art/out/s2/halo/HaloProp_GatePedestal_front_m1.png` |
| HaloReasonHQ_BenchA | 약간 | built_parts_only,planned_halo_v2 | 바닥 그림자 없음, 기둥 옆면 약간 어두움, 금구슬 반사광, 등판 아래 틈 어두움 | 정면 아님(3/4 각도) | `art/out/s2/halo/reason_hq/HaloReasonHQ_BenchA.png` |
| HaloReasonHQ_BenchB | 약간 | built_parts_only,planned_halo_v2 | 바닥 그림자 없음, 좌석 아래·화분 아래 약간 어두움, 금 반사광 | 정면 아님(3/4 각도), 화분+벤치 함께 | `art/out/s2/halo/reason_hq/HaloReasonHQ_BenchB.png` |
| HaloReasonHQ_BenchC | 약간 | built_parts_only,planned_halo_v2 | 바닥 그림자 없음, 좌석 아래 면 어두움, 금구슬 강한 광택 | 정면 아님(3/4 각도) | `art/out/s2/halo/reason_hq/HaloReasonHQ_BenchC.png` |
| HaloReasonHQ_BreadStand | 약간 | built_parts_only,planned_halo_v2 | 바닥 그림자 없음, 바구니 아래·선반 틈 어두움, 빵·금 광택 | 정면 아님(3/4 각도), 빵 여러 개 | `art/out/s2/halo/reason_hq/HaloReasonHQ_BreadStand.png` |
| HaloReasonHQ_Clothesline | 약간 | built_parts_only,planned_halo_v2 | 바닥 그림자 없음, 기둥 옆면·수건 주름 약한 음영, 금구슬 광택 | 정면 아님(3/4 각도), 빨래 바구니 따로 있음(여러 물체) | `art/out/s2/halo/reason_hq/HaloReasonHQ_Clothesline.png` |
| HaloReasonHQ_FlowerCart | 약간 | built_parts_only,planned_halo_v2 | 바닥 그림자 없음, 수레 아래·뒷바퀴 어두움, 금구슬 광택 | 정면 아님(3/4 각도) | `art/out/s2/halo/reason_hq/HaloReasonHQ_FlowerCart.png` |
| HaloReasonHQ_FruitStall | 약간 | built_parts_only,planned_halo_v2 | 바닥 그림자 없음, 차양 아래·상자 틈 약간 어두움, 금장식 반사광 | 정면 아닌 3/4 비스듬한 각도 | `art/out/s2/halo/reason_hq/HaloReasonHQ_FruitStall.png` |
| HaloReasonHQ_PotionCrate | 약간 | built_parts_only,planned_halo_v2 | 유리병 반사광, 상자 틈 약간 어두움, 바닥 그림자 없음 | 상자+간판 기둥 붙어 있음, 3/4 각도 | `art/out/s2/halo/reason_hq/HaloReasonHQ_PotionCrate.png` |
| HaloReasonHQ_RackShieldSword | 약간 | built_parts_only,planned_halo_v2 | 금 장식 반사광, 방패 가장자리 약한 음영, 바닥 그림자 없음 |  | `art/out/s2/halo/reason_hq/HaloReasonHQ_RackShieldSword.png` |
| HaloReasonHQ_Scarecrow | 약간 | built_parts_only,planned_halo_v2 | 머리·몸 오른쪽 약간 어두움, 받침대 반사광, 바닥 그림자 없음 | 뒷모습처럼 보임(얼굴 없음), 약간 비스듬 | `art/out/s2/halo/reason_hq/HaloReasonHQ_Scarecrow.png` |
| HaloReasonHQ_VegGarden | 약간 | built_parts_only,planned_halo_v2 | 흙·잎 사이 틈 어두움, 대리석 옆면 약한 음영, 바닥 그림자 없음 | 화단+물뿌리개 함께, 아이소 각도 | `art/out/s2/halo/reason_hq/HaloReasonHQ_VegGarden.png` |
| HaloReasonHQ_Woodpile | 약간 | built_parts_only,planned_halo_v2 | 지붕 아래·통나무 사이 약간 어두움, 금구슬 반사광 | 3/4 각도 | `art/out/s2/halo/reason_hq/HaloReasonHQ_Woodpile.png` |
| HaloStairs_1 | 약간 | built_parts_only,planned_halo_v2 | 바닥 그림자 없음, 계단 틈 약간 어둡게, 금 장식 반사광 |  | `art/out/s2/halo/stairs/HaloStairs_1_front_HQ_src.png` |
| HaloStairs_2 | 약간 | built_parts_only,planned_halo_v2 | 바닥 그림자 없음, 난간 안쪽 살짝 어둡게, 금 구슬 강한 반사 |  | `art/out/s2/halo/stairs/HaloStairs_2_front_HQ_src.png` |
| HaloStairs_4 | 약간 | built_parts_only,planned_halo_v2 | 바닥 그림자 없음, 난간 안쪽 곡면 살짝 어둡게, 금 반사광 | 정면 아님(비스듬한 시점) | `art/out/s2/redo/HaloStairs_4_front.png` |
| HaloVar4_Balustrade_A | 약간 | built_parts_only,planned_halo_v2 | 난간 아래·기둥 사이 약한 어두움, 금 구슬 반사광, 바닥 그림자 없음 | 정면 아님(3/4 각도) | `art/out/s2/halo/variants4/HaloVar4_Balustrade_A_HQ_src.png` |
| HaloVar4_Balustrade_B | 약간 | built_parts_only,planned_halo_v2 | 레일 아래·기둥 옆면 약한 어두움, 금 반사광, 바닥 그림자 없음 | 정면 아님(3/4 각도) | `art/out/s2/halo/variants4/HaloVar4_Balustrade_B_HQ_src.png` |
| HaloVar4_Balustrade_C | 약간 | built_parts_only,planned_halo_v2 | 모서리 안쪽·레일 아래 약한 어두움, 금 구슬 반사광 | 정면 아님(코너 위 각도) | `art/out/s2/halo/variants4/HaloVar4_Balustrade_C_HQ_src.png` |
| HaloVar4_Balustrade_D | 약간 | built_parts_only,planned_halo_v2 | 레일 아래·받침 약한 어두움, 금 구슬 반사광 | 정면 아님(3/4 각도) | `art/out/s2/halo/variants4/HaloVar4_Balustrade_D_HQ_src.png` |
| HaloVar4_Lantern_A | 약간 | built_parts_only,planned_halo_v2 | 기둥 오른쪽 면 약간 어두움, 등불 안 빛 번짐, 금 반사광 | 정면 아님(3/4 각도) | `art/out/s2/halo/variants4/HaloVar4_Lantern_A_HQ_src.png` |
| HaloVar4_Lantern_C | 약간 | built_parts_only,planned_halo_v2 | 기둥 옆면 약한 어두움, 등 안 빛 번짐, 금 반사광 | 정면 아님(3/4 각도) | `art/out/s2/halo/variants4/HaloVar4_Lantern_C_HQ_src.png` |
| Halo_Tower_v2 | 약간 | planned_halo_v2 | 원통 양옆 약한 음영, 금 돔 반사광, 바닥 그림자 없음 |  | `art/out/s2/halo/HaloProp_Tower_v2_front_HQ_src.png` |
| NEW_ArmoryBarrels | 약간 | Halo v2 (training yard): in WorldKit HaloV2.Props now as a Studio part kit (prop_kit.py). The kit doc plans 2D 4-view -> Tripo, not made yet. | 바닥 그림자 없음. 금색 띠 반사광, 통 사이 틈 약간 어두움, 아래쪽 은은한 음영 | 한 장에 물건 여러 개(큰 통·작은 통·상자·천), 비스듬한 시점(정면 아님) | `art/out/s2/halo/kits_new/HaloKit_ArmoryBarrels_front.png` |
| NEW_Beehive | 약간 | Halo v2 (garden homes): part kit in WorldKit now. 4-view 2D is ready for Tripo, which has not been run. | 바닥 그림자 없음. 금색 반사광, 지붕 아래·구멍 안쪽 약간 어두움, 전체는 고른 빛 | 비스듬한 3/4 시점 | `art/out/s2/halo/kits_mv/HaloKit_Beehive_front_HQ_src.png` |
| NEW_CandleCrate | 약간 | Halo v2 (cathedral hill / cliff homes): part kit in WorldKit. Tripo planned, not made. | 바닥 그림자 없음. 상자 안 촛불 사이 틈 어두움(AO), 금 장식 반사광, 양초 은은한 음영 | 비스듬한 3/4 시점 | `art/out/s2/halo/kits_new/HaloKit_CandleCrate_front.png` |
| NEW_Easel | 약간 | Halo v2 (cliff homes): part kit in WorldKit. 4-view 2D is ready, no Tripo yet. | 바닥 그림자 없음. 금 장식 반사광, 다리 안쪽 약간 어두움, 전체는 대체로 고른 빛 | 비스듬한 시점, 캔버스에 바다 그림 들어 있음 | `art/out/s2/halo/kits_mv/HaloKit_Easel_front_HQ_src.png` |
| NEW_NoticeBoard | 약간 | Halo v2 (garden homes): part kit in WorldKit. Tripo planned, not made. | 바닥 그림자 없음. 지붕 아래·기둥 받침 약간 어두움, 금 장식 반사광 | 비스듬한 3/4 시점 | `art/out/s2/halo/kits_new/HaloKit_NoticeBoard_front.png` |
| NEW_SteppingStones | 약간 | Halo v2 (garden pond): part kit / placeholder in WorldKit. Tripo planned, not made. | 바닥 그림자 없음. 돌 옆면·아랫면 은은하게 어두움, 윗면 약한 광택 | 한 장에 돌 5개, 위에서 비스듬히 본 시점(정면 아님) | `art/out/s2/halo/kits_new/HaloKit_SteppingStones_front.png` |
| NEW_WaterBuckets | 약간 | Halo v2 (cliff homes, W3): part kit in WorldKit. Tripo planned, not made. | 바닥 그림자 없음. 양동이 안쪽 어두움, 겹친 부분 약간 어두움, 금 장식 반사광 | 한 장에 물건 여러 개(양동이 2개+갈퀴) | `art/out/s2/halo/kits_new/HaloKit_WaterBuckets_front.png` |

### 2 사람(NPC·주민) — 15개 (진함 1 · 약간 14 · 없음 0 · 원본 없음 0)

| 이름 | 판정 | 쓰는 곳 | 그림자 메모 | 다른 문제 | 옛 2D |
|---|---|---|---|---|---|
| NPC_HaloSirGleam | 진함 | worldkit,planned_halo_v2 | 은색 갑옷 강한 금속 반사광, 망토 안쪽·다리 사이 어두움 |  | `art/out/s2/npc/NPC_HaloSirGleam_A_src.png` |
| NPC_HaloBakerGranny | 약간 | worldkit,import_hold,planned_halo_v2 | 옷 주름·팔 아래 약한 음영, 가벼운 광택, 바닥 그림자 없음 |  | `art/out/s2/npc/NPC_HaloBakerGranny_A_src.png` |
| NPC_HaloBright | 약간 | worldkit,planned_halo_v2 | 금 장식·투구 반사광, 다리 사이 약한 음영, 바닥 그림자 없음 |  | `art/out/s2/npc/NPC_HaloBright_A_src.png` |
| NPC_HaloFlowerGirl | 약간 | worldkit,planned_halo_v2 | 치마 주름·머리카락 틈 약한 음영, 바닥 그림자 없음 |  | `art/out/s2/npc/NPC_HaloFlowerGirl_C_src.png` |
| NPC_HaloJuiceMan | 약간 | worldkit,planned_halo_v2 | 앞치마 아래·팔 옆 약한 음영, 바닥 그림자 없음 |  | `art/out/s2/npc/NPC_HaloJuiceMan_A_src.png` |
| NPC_HaloBellElder | 약간 | - | 옷 주름·소매 아래 부드러운 음영, 부츠 약한 반사광, 바닥 그림자 없음 |  | `art/out/s2/npc2_hq/NPC_HaloBellElder_front_HQ_src.png` |
| NPC_HaloFlowerFarmer | 약간 | - | 모자 챙 아래·멜빵 주변 부드러운 음영, 부츠 반사광, 바닥 그림자 없음 |  | `art/out/s2/npc2_hq/NPC_HaloFlowerFarmer_front_HQ_src.png` |
| NPC_HaloFolk4 | 약간 | - | 치마 아래·머리카락 틈 부드러운 음영, 부츠 반사광, 바닥 그림자 없음 |  | `art/out/s2/npc2_hq/NPC_HaloFolk4_front_HQ_src.png` |
| NPC_HaloHerbHusband | 약간 | - | 앞치마·모자 챙 아래 부드러운 음영, 부츠 반사광, 바닥 그림자 없음 |  | `art/out/s2/npc2_hq/NPC_HaloHerbHusband_front_HQ_src.png` |
| NPC_HaloHerbWife | 약간 | - | 등 바구니 뒤·앞치마 아래 부드러운 음영, 부츠 반사광, 바닥 그림자 없음 |  | `art/out/s2/npc2_hq/NPC_HaloHerbWife_front_HQ_src.png` |
| NPC_HaloMailBoy | 약간 | - | 모자 챙·가방 아래 부드러운 음영, 부츠 반사광, 바닥 그림자 없음 |  | `art/out/s2/npc2_hq/NPC_HaloMailBoy_front_HQ_src.png` |
| NPC_HaloOldSailor | 약간 | - | 코트 자락 아래·모자 챙 음영, 검은 부츠 강한 반사광, 바닥 그림자 없음 |  | `art/out/s2/npc2_hq/NPC_HaloOldSailor_front_HQ_src.png` |
| NPC_HaloPondAngler | 약간 | - | 조끼 주머니·모자 챙 아래 음영, 장화 광택 반사광, 바닥 그림자 없음 |  | `art/out/s2/npc2_hq/NPC_HaloPondAngler_front_HQ_src.png` |
| NPC_HaloPotionMerchant | 약간 | - | 코트 주름·팔 아래 부드러운 음영, 약한 하이라이트, 바닥 그림자 없음 |  | `art/out/s2/npc/NPC_HaloPotionMerchant_front_HQ_src.png` |
| NPC_HaloStarScholar | 약간 | - | 로브 앞트임 안쪽 어두움, 머리 틈 음영, 부츠 반사광, 바닥 그림자 없음 |  | `art/out/s2/npc2_hq/NPC_HaloStarScholar_front_HQ_src.png` |

### 3 무기 — 28개 (진함 13 · 약간 14 · 없음 1 · 원본 없음 0)

| 이름 | 판정 | 쓰는 곳 | 그림자 메모 | 다른 문제 | 옛 2D |
|---|---|---|---|---|---|
| Weapon_Halo_LightMage_T3 | 진함 | - | 바닥 그림자 없음, 은색 금속 강한 반사광, 유리구슬 하이라이트 |  | `art/out/s2/weapons_t13_4v/Weapon_Halo_LightMage_T3_front.png` |
| Weapon_Halo_Paladin_T3 | 진함 | - | 바닥 그림자 없음, 칼날 강한 금속 반사광·한쪽 면 어두움, 홈 어두움 |  | `art/out/s2/weapons_t13_4v/Weapon_Halo_Paladin_T3_front.png` |
| Weapon_Halo_Ranger_T3 | 진함 | - | 바닥 그림자 없음, 금속 판 강한 반사광·어두운 면, 테두리 틈 어두움 |  | `art/out/s2/weapons_t13_4v/Weapon_Halo_Ranger_T3_front.png` |
| Weapon_Horns_Berserker_T2 | 진함 | - | 바닥 그림자 없음, 칼날 광택 반사광, 한쪽 면 어두움 |  | `art/out/s2/weapons_t13_4v/Weapon_Horns_Berserker_T2_front.png` |
| Weapon_Horns_Berserker_T3 | 진함 | - | 바닥 그림자 없음, 금속 칼날 반사광·중앙 홈 어두움, 손잡이 금속 광택 |  | `art/out/s2/weapons_t13_4v/Weapon_Horns_Berserker_T3_front.png` |
| Weapon_Horns_DarkMage_T3 | 진함 | - | 보석 구슬 강한 반사광, 금속 띠 하이라이트, 틈 어두움, 바닥 그림자 없음 |  | `art/out/s2/weapons_t13_4v/Weapon_Horns_DarkMage_T3_front.png` |
| Weapon_Horns_ShadowHunter_T3 | 진함 | - | 금속 장갑판 강한 반사광, 판 틈 어두움, 바닥 그림자 없음 |  | `art/out/s2/weapons_t13_4v/Weapon_Horns_ShadowHunter_T3_front.png` |
| Weapon_Neutral_Alchemist_T2 | 진함 | - | 유리 플라스크 강한 반사광, 나무 광택 하이라이트 |  | `art/out/s2/weapons_t13_4v/Weapon_Neutral_Alchemist_T2_front.png` |
| Weapon_Neutral_Alchemist_T3 | 진함 | - | 유리·황동 장식 강한 반사광, 금속 구 하이라이트 |  | `art/out/s2/weapons_t13_4v/Weapon_Neutral_Alchemist_T3_front.png` |
| Weapon_Neutral_Blacksmith_T1 | 진함 | - | 돌 머리 틈 어두움(AO), 끈 아래 그림자, 왼쪽 위 조명 음영 |  | `art/out/s2/weapons_t13_4v/Weapon_Neutral_Blacksmith_T1_front.png` |
| Weapon_Neutral_Blacksmith_T2 | 진함 | - | 쇠 머리 금속 반사광, 모서리 하이라이트, 손잡이 감은 틈 어두움 |  | `art/out/s2/weapons_t13_4v/Weapon_Neutral_Blacksmith_T2_front.png` |
| Weapon_Neutral_Blacksmith_T3 | 진함 | - | 금속 머리·리벳 강한 반사광, 띠 틈 어두움 |  | `art/out/s2/weapons_t13_4v/Weapon_Neutral_Blacksmith_T3_front.png` |
| Weapon_Neutral_PetTamer_T3 | 진함 | - | 금속 구슬·링에 강한 반사광, 왼쪽 밝고 오른쪽 어두움 |  | `art/out/s2/weapons_t13_4v/Weapon_Neutral_PetTamer_T3_front.png` |
| Weapon_Halo_LightMage_T1 | 약간 | - | 바닥 그림자 없음, 나무 지팡이 옆면 부드러운 음영, 옹이 틈 약간 어두움 |  | `art/out/s2/weapons_t13_4v/Weapon_Halo_LightMage_T1_front.png` |
| Weapon_Halo_LightMage_T2 | 약간 | - | 바닥 그림자 없음, 부드러운 음영, 보석·금속에 반사광 |  | `art/out/s2/weapons_t13_4v/Weapon_Halo_LightMage_T2_front.png` |
| Weapon_Halo_Paladin_T1 | 약간 | - | 나무 옹이·가장자리 부드러운 명암, 약한 하이라이트, 바닥 그림자 없음 |  | `art/out/s2/weapons_t13_4v/Weapon_Halo_Paladin_T1_front.png` |
| Weapon_Halo_Ranger_T1 | 약간 | - | 바닥 그림자 없음, 나무 활 옆면 부드러운 음영, 붕대 틈 약간 어두움 |  | `art/out/s2/weapons_t13_4v/Weapon_Halo_Ranger_T1_front.png` |
| Weapon_Halo_Ranger_T2 | 약간 | - | 바닥 그림자 없음, 부드러운 음영과 약한 광택 |  | `art/out/s2/weapons_t13_4v/Weapon_Halo_Ranger_T2_front.png` |
| Weapon_Horns_Berserker_T1 | 약간 | - | 바닥 그림자 없음, 가지 틈 어두움, 부드러운 음영 |  | `art/out/s2/weapons_t13_4v/Weapon_Horns_Berserker_T1_front.png` |
| Weapon_Horns_Berserker_final_b | 약간 | - | 칼날 한쪽 면 약간 어두움, 부드러운 하이라이트, 바닥 그림자 없음 |  | `art/out/s2/weapons_t13_4v/Weapon_Horns_Berserker_final_b_front.png` |
| Weapon_Horns_DarkMage_T1 | 약간 | - | 바닥 그림자 없음, 나무 결 틈 어두움, 부드러운 음영 |  | `art/out/s2/weapons_t13_4v/Weapon_Horns_DarkMage_T1_front.png` |
| Weapon_Horns_DarkMage_T2 | 약간 | - | 바닥 그림자 없음, 부드러운 음영, 보라 구슬·금속 고리 반사광 |  | `art/out/s2/weapons_t13_4v/Weapon_Horns_DarkMage_T2_front.png` |
| Weapon_Horns_ShadowHunter_T1 | 약간 | - | 나무 활대 부드러운 음영과 약한 하이라이트, 바닥 그림자 없음 |  | `art/out/s2/weapons_t13_4v/Weapon_Horns_ShadowHunter_T1_front.png` |
| Weapon_Horns_ShadowHunter_T2 | 약간 | - | 활대 가장자리 어두운 음영, 은은한 광택, 바닥 그림자 없음 |  | `art/out/s2/weapons_t13_4v/Weapon_Horns_ShadowHunter_T2_front.png` |
| Weapon_Neutral_Alchemist_T1 | 약간 | - | 유리병 반사광, 나무 부드러운 음영, 바닥 그림자 없음 |  | `art/out/s2/weapons_t13_4v/Weapon_Neutral_Alchemist_T1_front.png` |
| Weapon_Neutral_PetTamer_T1 | 약간 | - | 나무 결 부드러운 음영, 감은 천 틈 약간 어두움, 바닥 그림자 없음 |  | `art/out/s2/weapons_t13_4v/Weapon_Neutral_PetTamer_T1_front.png` |
| Weapon_Neutral_PetTamer_T2 | 약간 | - | 나무 몽둥이 광택 하이라이트와 가장자리 음영, 바닥 그림자 없음 |  | `art/out/s2/weapons_t13_4v/Weapon_Neutral_PetTamer_T2_front.png` |
| Weapon_Halo_Paladin_T2 | 없음 | - | 거의 평평한 조명, 칼날 가장자리 아주 약한 밝기 차만 |  | `art/out/s2/weapons_t13_4v/Weapon_Halo_Paladin_T2_front.png` |

### 4 꾸미기(밈·후광·뿔) — 15개 (진함 13 · 약간 1 · 없음 0 · 원본 없음 1)

| 이름 | 판정 | 쓰는 곳 | 그림자 메모 | 다른 문제 | 옛 2D |
|---|---|---|---|---|---|
| Acc_HaloR3 | 진함 | main,main_storage | 금속 링 강한 반사광, 안쪽·아랫면 어두움 | 정면 아님(3/4 시점) | `art/out/acc/HaloR3_34.png` |
| Acc_HaloR4 | 진함 | main,main_storage | 금속 링 강한 반사광, 날개 틈 어두움 | 정면 아님(3/4 시점) | `art/out/acc/HaloR4_34.png` |
| Acc_HaloR5 | 진함 | main,main_storage | 강한 금색 발광·반사광, 링 안쪽 어두운 그림자 | 정면 아님(3/4 시점), 해 모양 장식 뾰족 방사 형태 | `art/out/acc/HaloR5_34.png` |
| Acc_HornsR3 | 진함 | main,main_storage | 광택 반사광, 한쪽 면 어둡게 음영 | 정면 아님(3/4 시점), 두 개 물체 | `art/out/acc/HornsR3_34.png` |
| Acc_HornsR4 | 진함 | main,main_storage | 강한 광택 반사광, 아랫면 어두움, 붉은 발광 테두리 | 정면 아님(3/4 시점), 두 개 물체 | `art/out/acc/HornsR4_34.png` |
| Acc_HornsR5 | 진함 | main,main_storage | 강한 광택 반사광, 홈 사이 어두움, 불꽃 발광 | 정면 아님(3/4 시점), 두 개 물체 | `art/out/acc/HornsR5_34.png` |
| Acc_HaloR1 | 진함 | MAIN | 은색 금속 링에 강한 반사광, 아랫면과 안쪽 어두움 (현재 메시는 Blender 팔레트라서 반영 안 됨, Tripo 다시 만들 때는 이 2D를 쓰면 안 됨) |  | `art/out/acc/HaloR1.png` |
| Acc_HaloR2 | 진함 | MAIN | 금색 광택 반사광이 강함, 별과 링 아래쪽 어두움 (현재 메시에는 반영 안 됨) |  | `art/out/acc/HaloR2.png` |
| Acc_HornsR1 | 진함 | MAIN | 빨간 뿔에 강한 반사광, 오른쪽 면과 밑동 어두움 (현재 메시에는 반영 안 됨) | 한 이미지에 뿔 두 개 | `art/out/acc/HornsR1.png` |
| Acc_HornsR2 | 진함 | MAIN | 광택 반사광, 아래로 갈수록 어두운 그라데이션, 밑동 링 어두움 (현재 메시에는 반영 안 됨) | 한 이미지에 뿔 두 개 | `art/out/acc/HornsR2.png` |
| Meme_DonutHalo | 진함 | - | 아이싱·날개 광택 반사광, 도넛 아랫면 어두움 | 남색 외곽선 포함 | `art/out/s2/memes_4v/Meme_DonutHalo_front_HQ.png` |
| Meme_PixelHorns | 진함 | - | 큐브 옆면·아랫면 어두움, 윗모서리 강한 흰 반사광 | 뿔 두 개가 따로 떨어진 한 장, 남색 외곽선 포함 | `art/out/s2/memes_4v/Meme_PixelHorns_front_HQ.png` |
| Meme_TwistHorns | 진함 | - | 꼬임 틈 어두움, 강한 광택 반사광 | 뿔 두 개 따로, 남색 외곽선 포함 | `art/out/s2/memes_4v/Meme_TwistHorns_front_HQ.png` |
| Meme_PixelHalo | 약간 | - | 블록 모서리 약한 밝음/어두움 베벨, 바닥 그림자 없음 | 떠 있는 조각 여러 개 | `art/out/s2/memes_4v/Meme_PixelHalo_front_HQ.png` |
| AccTheme_* Looks (HaloIce/Gold/Sprout/Starlight/Platinum, HornsLava/Shadow/Sprout/Starlight/Platinum) | 원본 없음 | MAIN | 자체 2D 없음, 색만 바꾼 텍스처. R3~R5 색 버전은 Acc_*R3~R5 Tripo 텍스처의 그림자를 그대로 물려받음 |  | `` |

### 5 뿔 마을 — 23개 (진함 21 · 약간 2 · 없음 0 · 원본 없음 0)

| 이름 | 판정 | 쓰는 곳 | 그림자 메모 | 다른 문제 | 옛 2D |
|---|---|---|---|---|---|
| H_TreeArch | 진함 | main_storage,worldkit | 줄기 틈 어두움(AO), 뿌리 아래 어두움, 등불 발광 |  | `art/out/hq/HQ_H_TreeArch.png` |
| H_TreeTwisted | 진함 | main_storage,worldkit | 잎 덩어리 아래·줄기 틈 어두움, 뿌리 광택 |  | `art/out/hq/HQ_H_TreeTwisted.png` |
| H_Willow | 진함 | main_storage,worldkit | 잎 사이·줄기 틈 어두움, 줄기 광택 반사 |  | `art/out/hq/HQ_H_Willow.png` |
| Town_Horns_Bakery | 진함 | main_storage,worldkit | 바닥 그림자, 틈 AO 어두움, 빵 하이라이트, 용암 발광 | 여러 물건 함께(수레·통·연기) | `art/out/town/Town_Horns_Bakery_1.png` |
| Town_Horns_Brazier | 진함 | main_storage,worldkit | 돌 틈 AO 어두움, 뿔 강한 반사광, 불빛 조명 |  | `art/out/hq/HQ_Town_Horns_Brazier.png` |
| Town_Horns_Bridge | 진함 | main_storage,worldkit | 앞쪽 면·아래 어두움, 틈 AO, 반사광 | 정면 아님(위에서 비스듬히) | `art/out/hq/HQ_Town_Horns_Bridge.png` |
| Town_Horns_Castle (v3) | 진함 | main_storage,worldkit | 바닥 그림자, 탑·벽 틈 AO, 옆면 어두움 | 정면 아님(위에서 비스듬히) | `art/out/hq/HQ_Town_Horns_Castle_v3N2.png` |
| Town_Horns_Castle_v4 | 진함 | main_storage | 바위 틈 AO 강함, 옆면 어두움, 용암 발광 조명 | 정면 아님(위에서 비스듬히), 매우 복잡 | `art/out/hq/HQ_Town_Horns_Castle_v4B.png` |
| Town_Horns_Castle_v6mv | 진함 | main,main_storage,worldkit | 바위 틈 진한 어두움(AO), 용암 발광 조명, 벽 면 음영 차이 | 성·바위산·용암 여러 물체, 위쪽 사선 시점 | `art/out/hq/HQ_Town_Horns_Castle_v4B.png` |
| Town_Horns_HouseA | 진함 | main_storage,worldkit | 바닥 그림자, 지붕 아래·돌 틈 AO, 오른쪽 면 어두움 |  | `art/out/town/Town_Horns_HouseA_2.png` |
| Town_Horns_HouseB | 진함 | main_storage,worldkit | 바닥 그림자, 계단·틈 어두움, 용암·창문 발광 반사광 |  | `art/out/town/Town_Horns_HouseB_1.png` |
| Town_Horns_HouseC | 진함 | main_storage,worldkit | 지붕 아래·틈 어두움, 용암 발광 반사광, 약한 바닥 그림자 | 정면 아닌 3/4 시점 | `art/out/hq/HQ_Town_Horns_HouseC.png` |
| Town_Horns_JuiceBar | 진함 | main_storage,worldkit | 바닥 그림자, 차양 아래·문 안쪽 어두움, 발광 반사광 | 의자·상자 등 여러 물체 포함 | `art/out/town/Town_Horns_JuiceBar_1.png` |
| Town_Horns_Potion | 진함 | main_storage,worldkit | 바닥 그림자, 차양 아래 어두움, 유리병 강한 반사광 | 상자·항아리 등 여러 물체 포함 | `art/out/town/Town_Horns_Potion_1.png` |
| Town_Horns_Smithy | 진함 | main_storage,worldkit | 바닥 그림자, 차양 아래·화덕 틈 어두움, 불빛 반사광 | 무기걸이·방패·모루 등 여러 물체, 위 불꽃 잘림 | `art/out/town/Town_Horns_Smithy_1.png` |
| Town_Horns_Spawn | 진함 | main_storage | 아래 기단·틈 어두움, 불꽃·용암 발광 반사광 | 위에서 본 시점 | `art/out/town3/Town_Horns_Spawn_src.png` |
| Town_Horns_SpikeRock | 진함 | main_storage,worldkit | 광택 반사광 강함, 돌 사이 틈 어두움, 약한 바닥 그림자 |  | `art/out/hq/HQ_Town_Horns_SpikeRock.png` |
| Town_Horns_Wall | 진함 | main_storage | 바닥 그림자, 오른쪽 면 어두움, 돌 틈 어두움, 뿔 반사광 | 정면 아닌 비스듬한 시점 | `art/out/town3/Town_Horns_Wall_src.png` |
| Town_Horns_WallTower | 진함 | main_storage,worldkit | 지붕 아래·돌 틈 어두움, 뿔 광택 반사광, 발광 창문 |  | `art/out/hq/HQ_Town_Horns_WallTower.png` |
| Town_Horns_Gate | 약간 | main_storage | 아치 안쪽·돌 틈 약한 음영, 뿔 반사광, 바닥 그림자 없음 |  | `art/out/town3/Town_Horns_Gate_src.png` |
| Town_Horns_Tree | 약간 | main_storage | 잎 아래 부드러운 음영, 화분 안쪽 약간 어두움, 바닥 그림자 거의 없음 |  | `art/out/town3/Town_Horns_Tree_src.png` |
| Town_Horns_Castle | 진함 | - | 발광 용암·창문 빛, 틈 어두움, 오른쪽 아래 바닥 그림자 | 비스듬한 각도, 건물 여러 개 한 덩어리 | `art/out/town/Town_Horns_Castle_1.png` |
| Town_Horns_Castle_nowin | 진함 | - | 발광 용암·횃불 빛, 틈 어두움, 바닥 그림자 | 비스듬한 각도, 가운데 탑 지운 자국 흐림 | `art/out/town/Town_Horns_Castle_1_nowin.png` |

### 6 몬스터·펫 — 26개 (진함 15 · 약간 10 · 없음 0 · 원본 없음 1)

| 이름 | 판정 | 쓰는 곳 | 그림자 메모 | 다른 문제 | 옛 2D |
|---|---|---|---|---|---|
| Goblin | 진함 | main,main_storage,worldkit | 발 밑 바닥 그림자, 다리 사이·옷 틈 어두움, 입체 음영 | 맨배(조끼 열림) - 고블린이라 허용 | `art/out/s2/monsters4/HaloMon_Goblin_front.png` |
| GoblinBrute | 진함 | main,main_storage,worldkit | 발 밑 바닥 그림자, 팔·다리 아래쪽 어두움, 금속 반사 | 상의 없음 - 비성적 몬스터라 허용 | `art/out/s2/monsters4/HaloMon_GoblinBrute_front.png` |
| PetBabySlime | 진함 | main,worldkit | 바닥 그림자, 오른쪽 면 어두움, 강한 광택 | 정면 아님(3/4 각도) | `art/out/Pet_BabySlime.png` |
| Skeleton | 진함 | main,worldkit | 발 밑 바닥 그림자, 모자 아래 얼굴 어두움, 옷 주름 음영 | 원래 front(Skeleton_Clothed.png) 없음 - monsters4 정면으로 대체 | `art/out/s2/monsters4/HaloMon_Skeleton_front.png` |
| SkeletonArcher | 진함 | main,worldkit | 모자 아래 얼굴 어두움, 옷 주름·틈 어두움, 입체 조명 음영 | 약간 비스듬한 각도 | `art/out/s2/mon3/hq/MON_SkeletonArcherB_HQ_src.png` |
| Slime / BigSlime (SlimeCube) | 진함 | main,worldkit | 강한 젤리 반사광, 오른쪽 면·아랫부분 어두움 | 정면 아님(3/4 시점) | `art/out/CON_SlimeCube.png` |
| SlimeKing (King Slime) | 진함 | main,worldkit | 강한 광택 반사광(몸·왕관), 가장자리 어두움 |  | `art/out/s2/king/KingSlimeMV_front_HQ_src.png` |
| GoldenGoose | 약간 | main,worldkit | 바닥 그림자 없음, 외곽선 만화풍, 왕관·몸 광택 하이라이트 약간 | 원래 front 경로 없음 - Goose 정면으로 대체 확인 | `art/out/s2/monsters4/HaloMon_Goose_front.png` |
| SkeletonKnight | 약간 | main,worldkit | 그림자 없음, 갑옷 틈·아랫면 약간 어두움, 부드러운 음영 | 목록 front 없음, glob으로 찾음 | `art/out/s2/monsters4/HaloMon_SkeletonKnight_front.png` |
| CaveBat | 진함 | New zone, borrows LittleGhost. Own Tripo queued, not made. | 발 아래 바닥 그림자, 크리스탈 날개 강한 반사광, 털 음영 |  | `art/out/s2/zones_set/monsters/crystal_views/Crys_Bat_front.png` |
| CoralCrab | 진함 | New zone (replaces Pumpkin/Haunted for beta). Inert in Config, borrows the Goblin model. Own Tripo queued, not made. | 몸 아래 바닥 그림자, 집게·껍질 광택 반사, 집게 안쪽 어두움 |  | `art/out/s2/zones_set/monsters/coral_views/CoralA_Crab_front.png` |
| CrystalGolem | 진함 | New zone, borrows SkeletonKnight. Own Tripo queued, not made. | 발 밑 바닥 그림자, 돌 틈 어두움(AO), 수정 반사광과 발광 |  | `art/out/s2/zones_set/monsters/crystal_views/Crys_Golem_front.png` |
| CrystalHedgehog (pet) | 진함 | New-zone pet. Not in game yet, Tripo queued with the 8 new-zone monsters. | 발 밑 옅은 접촉 그림자, 몸 아래쪽 어두움, 수정 강한 반사광 |  | `art/out/s2/zones_set/monsters/crystal_views/Crys_Hedgehog_front.png` |
| CrystalLizard | 진함 | New zone, borrows Goblin. Own Tripo queued, not made. | 발 밑 부드러운 바닥 그림자, 다리·배 아래 어두움, 수정 하이라이트 |  | `art/out/s2/zones_set/monsters/crystal_views/Crys_Lizard_front.png` |
| FlowerSlime | 진함 | In game with the borrowed Slime model (purple tint). Own Tripo model planned, not made. Not Halo town. | 젤리 몸 강한 반사광, 아래쪽 어두움, 꽃 아래 접촉 그림자 |  | `art/out/s2/mon3/hq/MON_FlowerSlime_HQ_src.png` |
| GlowMushroom | 진함 | New zone, borrows GoblinBrute. Own Tripo queued, not made. | 발 밑 바닥 그림자, 갓 아래 어두움, 강한 발광 수정과 반사광 |  | `art/out/s2/zones_set/monsters/crystal_views/Crys_Mushroom_front.png` |
| HermitCrab | 진함 | New zone, borrows GoblinBrute. Own Tripo queued, not made. | 바닥 그림자, 껍데기 입구 안 어두움, 광택 반사 |  | `art/out/s2/zones_set/monsters/coral_views/CoralA_Hermit_front.png` |
| Jellyfish | 약간 | New zone, borrows LittleGhost. Own Tripo queued, not made. | 반투명 젤리 하이라이트, 약한 음영, 아래 아주 옅은 바닥 그림자 | 반투명 재질이라 3D 텍스처 어려움 | `art/out/s2/zones_set/monsters/coral_views/CoralA_Jelly_front.png` |
| MonsterBatGoblin_src | 약간 | - | 부드러운 음영, 하이라이트 약간, 발밑 약한 그림자 | 레코드는 옛 raw glb 가져오기(2D 출처 불확실) | `art/out/s2/monsters4/HaloMon_BatGoblin_front.png` |
| MonsterGoblinBrute_src | 약간 | - | 부드러운 음영, 아래쪽·가장자리 살짝 어두움, 바닥 그림자 약하게 | 레코드는 옛 GoblinBrute.glb 가져오기(2D 출처 불확실), 셔츠 없음(몬스터라 허용) | `art/out/s2/monsters4/HaloMon_GoblinBrute_front.png` |
| MonsterGoblin_src | 약간 | - | 부드러운 음영, 바닥 그림자 없음 | front 미지정, 3D 렌더 참고 이미지로 추정; 작고 위쪽에 치우침 | `art/out/s2/monsters4/refs/MonsterGoblin_front3d.png` |
| MonsterSkeleton | 약간 | - | 부드러운 음영, 투구 아래 얼굴 어두움, 발밑 약한 그림자 | 정확한 앞면 파일 없음, 가장 가까운 것 사용 | `art/out/s2/monsters4/HaloMon_Skeleton_front.png` |
| MonsterSkeletonKnight_src | 약간 | - | 갑옷 틈 약간 어두움, 부드러운 음영, 바닥 그림자 없음 | 레코드는 옛 glb 가져오기(2D 출처 불확실) | `art/out/s2/monsters4/HaloMon_SkeletonKnight_front.png` |
| MonsterSkeleton_src | 약간 | - | 부드러운 음영, 투구 아래 얼굴 어두움, 발밑 약한 그림자 | 레코드는 옛 glb 가져오기(2D 출처 불확실) | `art/out/s2/monsters4/HaloMon_Skeleton_front.png` |
| SkeletonKing | 약간 | glb_only | 부드러운 음영, 발 아래 약한 접지 그늘 | 원래 front(SkeletonKing_Clothed.png) 없음, 대체 이미지 | `art/out/s2/monsters4/HaloMon_SkeletonKing_front.png` |
| KingCrown | 원본 없음 | MAIN | Blender 절차 생성 메시(tools/img2/slime_crown.py), 2D 원본 없음 |  | `` |

### 7 다른 구역(교차로·초원·숲·폐허·왕관·기타) — 127개 (진함 81 · 약간 43 · 없음 0 · 원본 없음 3)

| 이름 | 판정 | 쓰는 곳 | 그림자 메모 | 다른 문제 | 옛 2D |
|---|---|---|---|---|---|
| BatGoblin | 진함 | main,worldkit | 발 밑 바닥 그림자, 광택 반사광 강함, 배·호박 바구니 하이라이트 | 맨배(조끼 열림) - 고블린이라 허용 | `art/out/CON_BatGoblin.png` |
| Crown_Broken_B | 진함 | main,main_storage | 바닥 그림자 있음, 금속 강한 반사광, 갈라진 틈 빛 | 왕관+떠 있는 후광 고리 분리 | `art/out/hq/HQ_Crown_Broken_B.png` |
| GhostKing | 진함 | main | 아래 바닥 그림자, 몸 광택 반사, 망토 안쪽 어두움, 홀 발광 |  | `art/out/s2/CON_GhostKing_A2_src.png` |
| K_CrownShard_v2 | 진함 | main,main_storage,worldkit | 바닥 그림자 있음, 강한 광택 반사광, 갈라진 틈 빛남 | 떠 있는 작은 파편 조각 | `art/out/hq/HQ_K_CrownShard.png` |
| Kit_H_GlowShrooms | 진함 | main_storage,worldkit | 버섯 강한 발광·광택 반사, 이끼 틈 어두움, 돌 아래 어두움 | 버섯 여러 개 한 덩어리 | `art/out/hq/HQ_Kit_H_GlowShrooms.png` |
| Kit_H_LanternPost | 진함 | main_storage,worldkit | 보라색 조명, 기둥 오른쪽 면 어두움, 등불 푸른 발광 반사 |  | `art/out/hq/HQ_Kit_H_LanternPost.png` |
| Kit_H_StumpTable | 진함 | main_storage,worldkit | 통나무 밑·틈 어두운 AO, 아래쪽 면 어둡고 광택 반사 | 여러 물체(그루터기+통나무 3개) | `art/out/hq/HQ_Kit_H_StumpTable.png` |
| Kit_M_Bridge | 진함 | main_storage | 광택 반사광 강함, 판자 틈·아래면 어두움, 오른쪽 면 음영 |  | `art/out/hq/HQ_Meadow_Bridge.png` |
| Kit_M_BushA | 진함 | main,main_storage | 덩어리 사이 틈 진하게 어두움, 아래쪽 어두움, 광택 반사광 |  | `art/out/kit/meadow/BushA_src.png` |
| Kit_M_CrownShrine | 진함 | main,main_storage,worldkit | 돌 틈 AO 진함, 오른쪽 면 어두움, 문 위 그늘, 공 장식 반사광 | 잔디 받침·돌·꽃 붙어 있음 | `art/out/hq/HQ_M_CrownShrine_front.png` |
| Kit_M_CrystalPile | 진함 | main,main_storage | 아래 돌 받침 어두움, 크리스털 강한 발광·하이라이트, 돌 반사광 |  | `art/out/kit/meadow/CrystalPile_src.png` |
| Kit_M_FlowerCart | 진함 | main,main_storage | 수레 안쪽·바퀴 뒤 틈 어두움, 화분 사이 AO, 광택 | 화분·꽃 여러 개 한 그림, 정면 아님 | `art/out/kit/meadow/FlowerCart_src.png` |
| Kit_M_JellyRock | 진함 | main,main_storage | 젤리 윗부분 강한 반사광(광택), 아래쪽 어두움 |  | `art/out/hq/HQ_Meadow_JellyRock.png` |
| Kit_M_MeadowArch | 진함 | main_storage,worldkit | 기둥 아래 바닥 그림자, 잎 틈 어두움 |  | `art/out/hq/HQ_Kit_M_MeadowArch.png` |
| Kit_M_PicnicBasket | 진함 | main,main_storage | 엮은 틈 어두움(AO), 사과 광택 반사광, 아래쪽 어두움 | 비스듬한 각도 | `art/out/kit/meadow/PicnicBasket_src.png` |
| Kit_M_PuddleRim | 진함 | main,main_storage | 돌 광택 반사광, 물에 빛 무늬(코스틱) 그려짐, 돌 틈 어두움 | 위에서 본 비스듬한 각도 | `art/out/hq/HQ_Meadow_PuddleRim.png` |
| Kit_P_EntranceSign | 진함 | main_storage,worldkit | 강한 광택 반사, 판자 틈·아래 어두움, 등불 발광 | 호박·풀 함께 붙음 | `art/out/hq/HQ_Kit_P_EntranceSign.png` |
| Kit_P_PumpkinCart | 진함 | main_storage,worldkit | 호박·나무 강한 광택 반사, 수레 안쪽·바퀴 틈 어두움 |  | `art/out/hq/HQ_Kit_P_PumpkinCart.png` |
| Kit_P_PumpkinCluster | 진함 | main_storage,worldkit | 호박 밑 흙에 그림자, 아래쪽 어두움, 광택 반사 | 흙 바닥 포함, 배경 밝은 회색 | `art/out/hq/HQ_Kit_P_PumpkinCluster.png` |
| Kit_R_Banner | 진함 | main_storage,worldkit | 돌 틈 어두움(AO), 오른쪽 면 어두움, 깃발 아래 그늘 |  | `art/out/kit/ruins/Banner_HQ.png` |
| Kit_R_PillarA | 진함 | main_storage,worldkit | 홈·틈 어두움, 오른쪽 면 어두움, 반질한 반사광 | 배경 잘라낸 가장자리에 색 노이즈 조각 | `art/out/kit/ruins/PillarA_B_HQ.png` |
| Kit_R_PillarB | 진함 | main_storage,worldkit | 홈 어두움, 왼쪽 면 어두움, 반사광 |  | `art/out/kit/ruins/PillarB_B_HQ.png` |
| Kit_R_SpiritBowl | 진함 | main_storage,worldkit | 돌 틈 어두움, 강한 반사광, 안쪽 보라 발광 | 배경 잘라낸 가장자리에 파란 노이즈 조각 | `art/out/kit/ruins/SpiritBowl_B_HQ.png` |
| Kit_R_StoneMarker | 진함 | main_storage,worldkit | 돌 틈 어두움, 오른쪽 면 어두움, 강한 반사광 |  | `build/ruins_r1/Kit_R_StoneMarker.png` |
| Kit_W_Awning | 진함 | main_storage,worldkit | 차양 아래 그림자, 상자 아래·틈 어두움, 사실적 조명 | 자루 2개 함께 있음 | `art/out/hq/HQ_Kit_W_Awning.png` |
| Kit_W_BushA | 진함 | main,main_storage,worldkit | 잎 겹친 틈·아래쪽 진하게 어두움(AO), 위쪽만 밝음 | 덤불 여러 덩이 | `art/out/hq/HQ_Kit_W_BushA.png` |
| Kit_W_BushB | 진함 | main,main_storage,worldkit | 잎 사이 틈 진하게 어두움(AO), 아래쪽 어두움 |  | `art/out/hq/HQ_Kit_W_BushB.png` |
| Kit_W_CampFence | 진함 | main,main_storage | 3D 렌더풍, 왼쪽 위 조명으로 오른쪽 면 어두움, 홈 틈 AO 진함, 윗면 반사광 | 기둥 4개 묶음, 정면 아닌 비스듬한 시점 | `art/out/kit/woods/CampFence_HQ_src.png` |
| Kit_W_Campfire_Fire | 진함 | main,main_storage,worldkit | 불빛이 통나무·돌에 주황 반사광, 돌 아래쪽 어둡고 틈 AO 진함, 광택 하이라이트 | 불꽃+통나무+돌 여러 덩어리, 위에서 본 시점 | `art/out/hq/HQ_Woods_Campfire_FB2.png` |
| Kit_W_Crates | 진함 | main,main_storage | 오른쪽 면 어두움, 판자 틈 AO 진함, 모서리·금속 강한 반사광 | 상자 2개+통 1개 한 그림, 비스듬한 시점 | `art/out/kit/woods/Crates_HQ_src.png` |
| Kit_W_FallenLog | 진함 | main,main_storage | 아래쪽 면 어둡고 속 빈 안쪽 진한 그림자, 나무결 틈 AO, 모서리 반사광 | 비스듬한 시점 | `art/out/kit/woods/FallenLog_HQ_src.png` |
| Kit_W_Fern | 진함 | main,main_storage,worldkit | 잎 겹친 아래 어두운 AO, 잎 광택 하이라이트, 바위 아래쪽 어두움 | 위에서 본 시점 | `art/out/hq/HQ_Kit_W_Fern.png` |
| Kit_W_LanternPost | 진함 | main,main_storage | 등불 발광, 기둥 오른쪽 어둡고 틈 AO, 금속·나무 강한 반사광 | 비스듬한 시점 | `art/out/kit/woods/LanternPost_HQ_src.png` |
| Kit_W_LogStool | 진함 | main,main_storage,worldkit | 껍질 틈 진한 AO, 아래쪽 어두움, 윗면 밝은 반사광 | 위에서 본 시점 | `art/out/hq/HQ_Kit_W_LogStool.png` |
| Kit_W_LootSack | 진함 | main,main_storage | 자루 입구 안쪽 진한 그림자, 오른쪽 아래 어두움, 동전·천 강한 광택 | 자루+동전 여러 개, 비스듬한 시점 | `art/out/kit/woods/LootSack_HQ_src.png` |
| Kit_W_Mushrooms | 진함 | main,main_storage,worldkit | 갓 아래 진한 그림자, 갓 표면 강한 광택 반사광 | 버섯 3개 묶음 | `art/out/hq/HQ_Kit_W_Mushrooms.png` |
| Kit_W_SignPost | 진함 | main,main_storage | 판자 아래 기둥에 드리운 그림자, 판자 모서리 강한 반사광, 나무 틈 AO | 비스듬한 시점 | `art/out/kit/woods/SignPost_HQ_src.png` |
| Kit_W_StepStones | 진함 | main,main_storage,worldkit | 돌 아래 바닥 그림자 살짝, 돌 옆면 어두움, 윗면 반사광 | 돌 4개 여러 덩어리, 위에서 본 비스듬한 시점 | `art/out/hq/HQ_Kit_W_StepStones.png` |
| Kit_W_Stump | 진함 | main,main_storage | 갈라진 틈·뿌리 사이 어두움, 오른쪽 면 어두움, 광택 반사광 |  | `art/out/kit/woods/Stump_HQ_src.png` |
| Kit_X_Anvil | 진함 | main,main_storage,worldkit | 쇠 모루 강한 반사·밑면 어두움, 나무 틈 어두움, 금띠 반사광 | 사선 시점 | `art/out/kit/crossroads/X_Anvil_src.png` |
| Kit_X_Crate | 진함 | main_storage,worldkit | 오른쪽 면 어두움, 틈 어두움(AO), 위쪽 하이라이트 |  | `art/out/kit/crossroads/X_Crate_src.png` |
| Kit_X_Fence | 진함 | main_storage,worldkit | 기둥 원통 음영 강함, 가로대 아래 어두움, 광택 반사 |  | `art/out/kit/crossroads/X_Fence_src.png` |
| Kit_X_FruitCart | 진함 | main_storage,worldkit | 수레 안쪽·바퀴 어두움, 과일 광택 반사, 측면 음영 |  | `art/out/kit/crossroads/X_FruitCart_src.png` |
| Kit_X_PlazaStairs | 진함 | main_storage,worldkit | 계단 단 사이 그림자, 벽돌 틈 어두움, 위쪽 따뜻한 햇빛 |  | `art/out/hq/HQ_Kit_X_PlazaStairs.png` |
| Kit_X_PlazaWall | 진함 | main_storage,worldkit | 벽돌 틈 어두움, 윗면 밝고 앞면 어두운 방향광, 광택 |  | `art/out/hq/HQ_Kit_X_PlazaWall.png` |
| Kit_X_PotionCart | 진함 | main,main_storage,worldkit | 차양 아래·수레 안쪽 틈 어둡게 칠해짐(AO), 바퀴 안쪽 어두움, 유리병 강한 반사광 |  | `art/out/kit/crossroads/X_PotionCart_src.png` |
| LittleGhost | 진함 | main,worldkit | 몸 광택 반사, 아래쪽·손 밑 어두운 음영, 등불 발광 |  | `art/out/CON_LittleGhost.png` |
| P_Cliff_A | 진함 | main_storage,worldkit | 따뜻한 방향광, 바위 틈 어두움, 아래쪽 면 어두움 |  | `art/out/hq/HQ_P_Cliff_A.png` |
| P_Cliff_B | 진함 | main_storage,worldkit | 왼쪽 위 따뜻한 빛, 오른쪽·아래 면 어두움, 틈 어두움 |  | `art/out/hq/HQ_P_Cliff_B.png` |
| P_Pine | 진함 | main_storage,worldkit | 왼쪽 노란 림라이트, 강한 광택 반사, 층 밑 어두움 |  | `art/out/hq/HQ_P_Pine.png` |
| P_TreeAutumn_A | 진함 | main_storage,worldkit | 잎 덩어리 안쪽·아래 어두움, 줄기 왼쪽 밝고 오른쪽 어두움 |  | `art/out/hq/HQ_P_TreeAutumn_A.png` |
| P_TreeAutumn_B | 진함 | main_storage,worldkit | 잎 사이 깊은 음영, 줄기 오른쪽 어두움, 잎 밑 어두움 |  | `art/out/hq/HQ_P_TreeAutumn_B.png` |
| PumpkinKing | 진함 | main,worldkit | 바닥 그림자, 강한 광택 반사, 홈 사이 어두움, 촛불 발광 | 작은 호박 2개 함께 있음(여러 물체) | `art/out/CON_PumpkinKing.png` |
| PumpkinSlime | 진함 | main,worldkit | 바닥 그림자, 강한 광택 반사광, 홈 사이 어두움 |  | `art/out/CON_PumpkinSlime.png` |
| W_Boulder_A | 진함 | main,main_storage,worldkit | 아래쪽·틈 어두움(AO), 위쪽 밝고 아래 어둡게 방향광 |  | `art/out/hq/HQ_W_Boulder_A.png` |
| W_Boulder_B | 진함 | main,main_storage,worldkit | 두 바위 사이 틈 진하게 어두움, 버섯 아래 그림자, 아래쪽 어두움 | 바위 2개+버섯 한 그림 | `art/out/hq/HQ_W_Boulder_B.png` |
| W_BridgeWood | 진함 | main_storage | 다리 아래 바닥 그림자, 난간 아래 어두움, 금속 광택 | 정면 아님(사선 위 시점) | `art/out/town3/W_BridgeWood_src.png` |
| W_GiantTree | 진함 | main,main_storage | 잎 덩어리 아래·줄기 틈 어두움, 뿌리 사이 AO, 광택 반사광 | 나무+집 2채+다리+사다리 한 덩어리 | `art/out/hq/HQ_W_GiantTree.png` |
| W_Tent_B | 진함 | main,main_storage | 입구 안쪽 진하게 어두움, 차양 아래 그림자, 오른쪽 면 어두움 |  | `art/out/hq/HQ_W_Tent_B.png` |
| W_Tree_A | 진함 | main,main_storage | 잎 층 아래 어둡게, 오른쪽 면 어두움, 줄기 위 잎 그림자, 광택 반사광 |  | `art/out/hq/HQ_W_Tree_A.png` |
| W_Tree_B | 진함 | main,main_storage | 잎 덩어리 아래쪽 진하게 어두움, 줄기 위 그림자, 위 밝고 아래 어두움 |  | `art/out/hq/HQ_W_Tree_B.png` |
| W_Tree_C | 진함 | main,main_storage | 잎 아래 어두움, 줄기 꼬임 틈 AO, 광택 반사광 |  | `art/out/hq/HQ_W_Tree_C.png` |
| X_Altar | 진함 | main,main_storage,worldkit | 수정 청록 발광이 윗면에 번짐, 뿔 주변 주황 빛번짐, 금속 광택, 받침 아래 어두움 |  | `art/out/hq/HQ_X_Altar.png` |
| X_Fountain | 진함 | main_storage | 그릇 아래 그림자, 물 반사광, 크리스탈 발광 |  | `art/out/town3/X_Fountain_src.png` |
| X_GooseNest | 진함 | main,main_storage,worldkit | 황금알 강한 반사광, 지푸라기 틈 어둡게(AO), 받침 아래쪽 어두움 |  | `art/out/hq/HQ_X_GooseNest.png` |
| X_GuildHall | 진함 | main,main_storage | 바닥 그림자, 실내 안쪽 어두움, 틈 AO 진함, 불빛 발광 | 건물에 소품 여러 개(작업대·통·상자) 붙음 | `art/out/town3/X_GuildHall_src.png` |
| X_HouseA | 진함 | main_storage,worldkit | 지붕 처마 아래 그림자, 창문 발광, 금속 광택 |  | `art/out/hq/HQ_X_HouseA.png` |
| X_HouseB | 진함 | main_storage,worldkit | 처마·발코니 아래 그림자, 창문·등불 발광, 오른쪽 면 어두움 |  | `art/out/hq/HQ_X_HouseB.png` |
| X_TreeA | 진함 | main_storage | 잎 덩어리 아래 어두움, 잎 광택 하이라이트, 줄기 위 그림자 |  | `art/out/town3/X_TreeA_src.png` |
| X_TreeB | 진함 | main_storage,worldkit | 잎층 아래 어두움, 잎 광택, 줄기 그림자 |  | `art/out/hq/HQ_X_TreeB.png` |
| GhostMinion | 약간 | main | 바닥 그림자 없음, 부드러운 음영 + 위쪽 광택 하이라이트 | 물체가 작게 그려짐(여백 큼) | `art/out/s2/CON_GhostMinion_A1_src.png` |
| Kit_M_BushB | 약간 | main,main_storage | 덩어리 아래·틈 부드럽게 어두움, 약한 광택 |  | `art/out/kit/meadow/BushB_src.png` |
| Kit_M_Fence | 약간 | main,main_storage | 기둥·가로대 아래쪽 약간 어두움, 부드러운 광택 | 정면 아님(비스듬한 각도) | `art/out/hq/HQ_Meadow_Fence.png` |
| Kit_M_FlowersA | 약간 | main,main_storage,worldkit | 꽃잎 아래·잎 사이 부드럽게 어두움, 약한 광택 |  | `art/out/kit/meadow/FlowersA_src.png` |
| Kit_M_FlowersB | 약간 | main,main_storage,worldkit | 꽃잎·받침 아래쪽 약간 어두움, 부드러운 반사광, 바닥 그림자 없음 |  | `art/out/kit/meadow/FlowersB_src.png` |
| Kit_M_JobBoard | 약간 | main_storage,worldkit | 지붕 아래·기둥 틈 약한 어두움, 보석 하이라이트, 바닥 그림자 없음 |  | `art/out/hq/HQ_Meadow_JobBoard.png` |
| Kit_M_LogBench | 약간 | main,main_storage | 통나무 아래쪽·다리 틈 약간 어두움, 윗면 밝음, 바닥 그림자 없음 | 정면 아닌 비스듬한 각도 | `art/out/hq/HQ_Meadow_LogBench.png` |
| Kit_M_Mushrooms | 약간 | main,main_storage | 갓 아래·줄기 틈 약간 어두움, 받침 아래 어두움, 바닥 그림자 없음 |  | `art/out/kit/meadow/Mushrooms_src.png` |
| Kit_M_Pinwheel | 약간 | main,main_storage | 날개 광택 반사광, 아래쪽 약간 어두움, 바닥 그림자 없음 |  | `art/out/hq/HQ_Meadow_Pinwheel.png` |
| Kit_M_SignPost | 약간 | main,main_storage | 젤리 큐브 광택, 테두리 아래쪽 약간 어두움, 바닥 그림자 없음 |  | `art/out/hq/HQ_Meadow_SignPost.png` |
| Kit_P_HayBales | 약간 | main_storage,worldkit | 아래쪽 면 살짝 어둡고 짚 사이 약한 음영 | 여러 물체(건초 3개) | `art/out/hq/HQ_Kit_P_HayBales.png` |
| Kit_P_Sunflowers | 약간 | main_storage,worldkit | 잎 겹친 곳 약한 음영, 잎 광택 |  | `art/out/hq/HQ_Kit_P_Sunflowers.png` |
| Kit_W_Banner | 약간 | main,main_storage,worldkit | 막대·받침 약한 음영과 반사광, 바닥 그림자 없음 |  | `art/out/hq/HQ_Kit_W_Banner.png` |
| Kit_W_JobBoard | 약간 | main_storage,worldkit | 지붕 아래·돌 틈 어두움, 등불 발광, 바닥 그림자 없음 |  | `art/out/hq/HQ_Woods_JobBoard.png` |
| Kit_W_MossRock | 약간 | main,main_storage,worldkit | 이끼 아래 살짝 어두움, 이끼 광택 반사광, 바닥 그림자 없음 |  | `art/out/hq/HQ_Kit_W_MossRock.png` |
| Kit_X_BannerHalo | 약간 | main,main_storage,worldkit | 깃발·기둥 약한 음영, 금 공 하이라이트, 바닥 그림자 없음 | 날개·후광 떠 있음, 약간 사선 | `art/out/kit/crossroads/X_BannerHalo_src.png` |
| Kit_X_BannerHorns | 약간 | main,main_storage,worldkit | 깃발 주름 약한 음영, 뿔 아래쪽 어두움, 바닥 그림자 없음 | 약간 사선 시점 | `art/out/kit/crossroads/X_BannerHorns_src.png` |
| Kit_X_Barrel | 약간 | main_storage,worldkit | 가장자리·아래 부드러운 음영, 금속 띠 약한 반사광, 바닥 그림자 없음 |  | `art/out/kit/crossroads/X_Barrel_src.png` |
| Kit_X_Bench | 약간 | main,main_storage,worldkit | 바닥 그림자 없음; 좌석 아래·다리 사이 어두움, 놋쇠 징 반사광 약간 |  | `art/out/kit/crossroads/X_Bench_src.png` |
| Kit_X_Brazier | 약간 | main,main_storage,worldkit | 바닥 그림자 없음; 그릇 아랫면 어두움, 불빛이 그릇 안쪽을 주황으로 물들임(발광 반사) |  | `art/out/kit/crossroads/X_Brazier_src.png` |
| Kit_X_Bush | 약간 | main_storage,worldkit | 잎 겹침·아래쪽 부드러운 어두움, 바닥 그림자 없음 | 위에서 본 시점 | `art/out/kit/crossroads/X_Bush_src.png` |
| Kit_X_Curb | 약간 | main,main_storage,worldkit | 바닥 그림자 없음; 블록 틈·아랫면 살짝 어두움, 부드러운 음영 |  | `art/out/kit/crossroads/X_Curb_src.png` |
| Kit_X_FlowerPot | 약간 | main_storage,worldkit | 잎 사이 약한 어두움, 화분 아래쪽 부드러운 음영 |  | `art/out/kit/crossroads/X_FlowerPot_src.png` |
| Kit_X_Forge | 약간 | main,main_storage,worldkit | 바닥 그림자 없음; 오른쪽 면 약간 어두움, 화덕 불빛 주황 반사, 금속 반사광 |  | `art/out/kit/crossroads/X_Forge_src.png` |
| Kit_X_Lamp | 약간 | main,main_storage,worldkit | 바닥 그림자 없음; 기둥 오른쪽 살짝 어두움, 금속 띠 반사광, 유리구슬 발광 |  | `art/out/kit/crossroads/X_Lamp_src.png` |
| Kit_X_StallBlue | 약간 | main,main_storage,worldkit | 전용 원본 없음(빨강 노점 원본 공유, art/out/retex/에 재색칠 텍스처만); 차양 아래·카운터 아래 약간 어두움, 바닥 그림자 없음 | 빨강 노점 재색칠본(A23-96 재색칠 금지 대상) | `art/out/kit/crossroads/X_StallRed_src.png` |
| Kit_X_StallGreen | 약간 | main,main_storage,worldkit | 전용 원본 없음(빨강 노점 원본 공유, art/out/retex/에 재색칠 텍스처만); 차양 아래·카운터 아래 약간 어두움, 바닥 그림자 없음 | 빨강 노점 재색칠본(A23-96 재색칠 금지 대상) | `art/out/kit/crossroads/X_StallRed_src.png` |
| Kit_X_StallRed | 약간 | main,main_storage,worldkit | 바닥 그림자 없음; 차양 아래·카운터 아래 약간 어두움, 과일·놋쇠 반사광 약간 |  | `art/out/kit/crossroads/X_StallRed_src.png` |
| R_Arch_A | 약간 | main_storage,worldkit | 아래쪽 면 살짝 어두움, 틈 약한 그늘, 바닥 그림자 없음 |  | `art/out/hq/HQ_R_Arch_A.png` |
| R_Arch_B | 약간 | main_storage,worldkit | 아래쪽·옆면 부드러운 음영, 바닥 그림자 없음 |  | `art/out/hq/HQ_R_Arch_B.png` |
| R_Gate | 약간 | main_storage,worldkit | 벽돌 틈·창 안 어두움, 부드러운 음영, 바닥 그림자 없음 |  | `art/out/hq/HQ_R_Gate.png` |
| SlingshotGoblin | 약간 | main,worldkit | 바닥 그림자 없음, 모자 아래 얼굴·팔다리 아랫면 약한 음영 |  | `art/out/s2/mon3/hq/MON_SlingshotGoblin_HQ_src.png` |
| W_Gate | 약간 | main_storage | 나무 둥근 면 음영, 밧줄 틈 어두움, 바닥 그림자 없음 | 정면 아님(약간 사선) | `art/out/hq/HQ_W_Gate.png` |
| W_Tent_A | 약간 | main,main_storage | 천 주름 음영, 안쪽 약간 어두움, 바닥 그림자 없음 |  | `art/out/hq/HQ_W_Tent_A.png` |
| W_Totem | 약간 | main,main_storage | 층 사이·조각 홈 약한 음영, 금속 왕관 반사광, 바닥 그림자 없음 |  | `art/out/hq/HQ_W_Totem.png` |
| X_MarketArch | 약간 | main,main_storage,worldkit | 아래쪽·틈 약간 어두움, 금속 반사광, 바닥 그림자 없음 |  | `art/out/hq/HQ_X_MarketArch.png` |
| X_NoticeBoard | 약간 | main,main_storage,worldkit | 지붕 밑 처마 그림자, 틈 약간 어두움, 금속 반사광 |  | `art/out/hq/HQ_X_NoticeBoard.png` |
| X_PadBase | 약간 | main,main_storage | 옆면 아래쪽 어두움, 금속 반사광, 발광 링 |  | `art/out/town3/X_PadBase_src.png` |
| X_SpawnPlaza | 약간 | main_storage | 테두리 아래 약한 음영, 크리스탈 발광, 금속 광택 |  | `art/out/town3/X_SpawnPlaza_src.png` |
| X_SupporterBoard | 약간 | main | 게시판과 같은 그림: 처마 그림자, 틈 약간 어두움, 금속 반사광 | 전용 그림 없음, 게시판 그림 재사용 | `art/out/hq/HQ_X_NoticeBoard.png` |
| Bakery_tripoP1 | 진함 | - | 빵 지붕 강한 반사광, 창문 안 빛, 틈 어두움, 바닥 그림자 | 여러 물건 한 그림(수레·바구니·구름 받침), 비스듬한 각도 | `art/out/town/Town_Halo_Bakery_1.png` |
| CastlePartHigh_Rose | 진함 | - | 테두리 돌 아래쪽 어두움, 금테 강한 반사광, 유리 발광·하이라이트 |  | `art/out/s2/halo/castle6/parts_high/CastlePartHigh_Rose_front.png` |
| CastlePartHigh_Spire | 진함 | - | 첨탑 왼쪽 면 어둡고 오른쪽 밝음(방향광), 금 강한 반사광, 탑 아래 틈 어두움 | 정면 아닌 살짝 위 시점 | `art/out/s2/halo/castle6/parts_high/CastlePartHigh_Spire_front.png` |
| Crown_CrackSeam | 진함 | Planned crown part, no 3D yet. | 광택 반사광과 발광, 주황 어두운 가장자리 | 떠 있는 작은 구슬 여러 개 함께 그려짐 | `art/out/s2/crown/Crown_CrackSeam_front_HQ_src.png` |
| Crown_GemBlue | 진함 | Planned crown part, no 3D yet. | 바닥 그림자 없음, 금테 강한 반사광, 보석 반짝임·명암 |  | `art/out/s2/crown/Crown_GemBlue_front_HQ_src.png` |
| Crown_GemRed | 진함 | Planned part of the new Crown of Balance (the in-game CrownOfBalance). Crown_GoldHalf and Crown_RedHalf are already Tripo'd and in the list; this part has no 3D. | 바닥 그림자 없음, 보석·금테에 강한 반사광과 반짝임, 면마다 명암 큼 |  | `art/out/s2/crown/Crown_GemRed_front_HQ_src.png` |
| Crown_GoldHalf | 진함 | glb_only | 금속 강한 반사광, 안쪽 어두움 |  | `art/out/s2/crown/Crown_GoldHalf_front_HQ_src.png` |
| Crown_HaloRing | 진함 | Planned crown part, no 3D yet. | 강한 광택 반사광, 바깥 발광, 안쪽 어두움 |  | `art/out/s2/crown/Crown_HaloRing_front_HQ_src.png` |
| Crown_RedHalf | 진함 | glb_only | 강한 광택 반사광, 안쪽·아래 어두움 |  | `art/out/s2/crown/Crown_RedHalf_front_HQ_src.png` |
| Kit_W_Campfire | 진함 | - | 불빛이 통나무·돌 비춤, 돌 강한 반사광, 틈 어두움 | 위에서 본 비스듬한 각도 | `art/out/kit/woods/Campfire_HQ_src.png` |
| W_Tree_C3k | 진함 | - | 잎 덩어리 아래 진한 그림자, 줄기 틈 어두움, 방향광 |  | `art/out/hq/HQ_W_Tree_C.png` |
| CastlePartHigh_WingL | 약간 | - | 깃털 겹침 부분 옅은 회색 음영, 금테 반사광, 바닥 그림자 없음 |  | `art/out/s2/halo/castle6/parts_high/CastlePartHigh_WingL_front.png` |
| CastlePartHigh_WingR | 약간 | - | 깃털 겹침 옅은 음영, 몸통 쪽 광택 하이라이트, 바닥 그림자 없음 |  | `art/out/s2/halo/castle6/parts_high/CastlePartHigh_WingR_front.png` |
| W_GateOpen | 약간 | glb_only | 기둥 둥근 음영, 밧줄 틈 약간 어두움, 바닥 그림자 없음 |  | `art/out/s2/gate/GoblinGateOpen_front_HQ_src.png` |
| GF_* HauntedHollow placeholders (GF_Tree x7, GF_Mushrooms x4, GF_Lantern x3, GF_Rock x3, GF_Willow x2, GF_Arch x1) | 원본 없음 | MAIN | Studio generate_mesh 텍스트로 만든 임시 모델, 2D 없음 (구역 숨김, H_* 모델로 교체 예정) | object3d | `` |
| halo_houses15_deco_tripo_2026-10-12 | 원본 없음 | - | 묶음 기록(집별 Tripo HD 멀티뷰 parts.glb에서 장식 잘라냄), 단일 앞면 2D 없음 | 개별 물체가 아니라 집 15채 장식 묶음 기록; 원본은 각 집 멀티뷰 이미지 확인 필요 | `` |
| halo_houses_deco_extras_2026-10-12 | 원본 없음 | - | 앞면 2D 이미지 못 찾음 |  | `` |

### 9 타일 색 맵 — 45개 (진함 15 · 약간 22 · 없음 8 · 원본 없음 0)

| 이름 | 판정 | 쓰는 곳 | 그림자 메모 | 다른 문제 | 옛 2D |
|---|---|---|---|---|---|
| GE_Cobblestone (Tex_Cobblestone_FF2) | 진함 | YES main place: Cobblestone override (town cobbles) | 둥근 돌 위 밝고 아래 가장자리 어두움, 줄눈에 돌 아래 접촉 그림자 | texture_tile | `art/ui/Tex_Cobblestone_FF2.png` |
| GE_CrackedLava (Tex_CrackedLava_FF) | 진함 | YES main place: CrackedLava override (Horns) | 바위 덩어리 아래쪽 어둡고 용암 빛이 돌 가장자리에 칠해짐, 틈 진한 어둠 | texture_tile | `art/ui/Tex_CrackedLava_FF.png` |
| GE_LeafyGrass (Tex_LeafyGrass_FF3) | 진함 | YES main place: Terrain LeafyGrass override (woods floor) | 이끼 덩어리 위 밝고 사이 틈 어두움(AO), 참나무 잎 아래 그림자 | texture_tile | `art/out/terrain_v3/Tex_LeafyGrass_FF3.png` |
| GE_PumpkinSoil (Tex_PumpkinSoil_FF2) | 진함 | YES main place: Mud override (Pumpkin Patch, zone hidden for beta) | 이랑 위 밝고 골 어두움, 흙덩이 아래 그림자, 덩굴잎 음영 | texture_tile; zone hidden for beta | `art/ui/Tex_PumpkinSoil_FF2.png` |
| GE_Rock (Tex_Rock_FF2) | 진함 | YES main place: Rock override (every cliff) | 바위 위쪽 밝고 아래·옆면 어두움, 깊은 틈 진한 어둠(방향광+AO) | texture_tile | `art/ui/Tex_Rock_FF2.png` |
| GE_Sand (Tex_Sand_FF) | 진함 | YES main place: Sand override (beaches) | 모래 물결 한쪽 밝고 반대쪽 어두움(방향광), 분홍 자갈 반사광 | texture_tile | `art/ui/Tex_Sand_FF.png` |
| GE_TreeBark (Tex_TreeBark) | 진함 | YES main place: 46 tree trunk parts | 껍질 융기 밝은/어두운 면, 깊은 홈 어두움, 옹이 음영 | texture_tile | `art/ui/Tex_TreeBark.png` |
| GE_TreeLeaves (Tex_TreeLeaves) | 진함 | YES main place: 92 tree leaf-ball parts | 앞 잎 덩어리 흰색, 뒤/사이 진회색 AO | texture_tile | `art/ui/Tex_TreeLeaves.png` |
| GE_WoodPlanks (Tex_WoodPlanks_FF) | 진함 | YES main place: WoodPlanks override (bridges/benches) | 판자 윗모서리 밝고 아랫모서리 어두움, 틈 진한 그림자 | texture_tile | `art/ui/Tex_WoodPlanks_FF.png` |
| GE_Basalt (Tex_Basalt_FF2) | 약간 | YES main place: Basalt override (Horns lair floor/hills) | 판 가장자리 밝은 테두리 + 틈 쪽 어두운 가장자리, 용암 빛 반사 약간 | texture_tile | `art/ui/Tex_Basalt_FF2.png` |
| GE_DirtPath (Tex_DirtPath_FF2) | 약간 | YES main place: 8 road parts + meadow path | 자갈 윗면 반사광 + 아래쪽 옅은 어두운 테두리, 흙 얼룩은 기본색 | texture_tile | `art/ui/Tex_DirtPath_FF2.png` |
| GE_Grass (Tex_Grass_FF3) | 약간 | YES main place: Terrain Grass override (meadow); also UiSandbox | 밝은 풀 덩어리 + 어두운 녹색 얼룩이 명암처럼 보임, 바닥 그림자 없음 | texture_tile | `art/ui/Tex_Grass_FF3.png` |
| GE_Ground (Tex_Ground_FF) | 약간 | YES main place: Terrain Ground override (ruins/fields soil) | 납작돌 아래·오른쪽 가장자리 약간 어둡고 윗면 밝음, 바닥 그림자는 약함 | texture_tile | `art/ui/Tex_Ground_FF.png` |
| GE_HaloPave (Halo floor Marble B) | 약간 | YES main place + WorldKit: Concrete override (Halo paved terrain) | 판 모서리 베벨, 회색 줄눈 음영, 금테 명암; 드리운 그림자 없음 | texture_tile | `art/out/s2/halo_floor/Marble_B_high.png` |
| GE_HauntedFloor (Tex_HauntedFloor_FF2) | 약간 | YES main place: Asphalt override (Haunted Hollow, zone hidden for beta) | 덤불 덩어리 주변 옅게 어두움, 그림자 없음, 작은 빛 점 하나 | texture_tile; zone hidden for beta | `art/ui/Tex_HauntedFloor_FF2.png` |
| GE_Limestone (Tex_Limestone_FF2) | 약간 | YES main place: Limestone override (Halo cliffs/floor) | 돌 윗가장자리 밝고 줄눈 쪽 옅은 접촉 그림자, 전체로는 밝고 평평 | texture_tile | `art/ui/Tex_Limestone_FF2.png` |
| GE_MeadowDirt (Tex_MeadowDirt_FF3code) | 약간 | YES main place: Terrain Pavement override (meadow dirt) | 자갈 위쪽 밝고 아래쪽 어두운 테두리(약한 접촉 그늘), 흙 얼룩은 평평; 기존 판정 strong보다 약하게 보임 | texture_tile | `art/ui/Tex_MeadowDirt_FF3code.png` |
| GE_MeadowFlowers (Tex_MeadowFlowers_FF3) | 약간 | YES main place: Terrain Salt override (meadow flower patches) | Grass_FF3와 같은 밝은/어두운 얼룩 바탕, 꽃은 평평(약한 테두리 그늘) | texture_tile | `art/ui/Tex_MeadowFlowers_FF3.png` |
| GE_MeadowShade (Tex_GrassShade_FF3) | 약간 | YES main place: Terrain Sandstone override (meadow shade) | 어두운 풀 바탕에 밝은 덩어리와 진한 얼룩, 바닥 그림자 없음 | texture_tile | `art/ui/Tex_GrassShade_FF3.png` |
| GE_Slate (Tex_RuinsFlagstone_FF2) | 약간 | YES main place: Slate override (ruins flagstones, road parts) | 판석 왼쪽 위 가장자리 밝은 베벨, 틈 어두움(옅은 AO), 바닥 그림자 없음 | texture_tile | `art/ui/Tex_RuinsFlagstone_FF2.png` |
| HH_HaloMarbleBlock_Cream (Halo wall marble block) | 약간 | YES WorldKit only (13,258 parts); not in main | 블록마다 약한 베벨(윗변 밝고 아랫변 어두움), 줄눈 살짝 음영 | texture_tile | `art/ui/halo_tile/Halo_TowerMarbleBlockCream_color.png` |
| Halo_WaterfallStreaks (Halo waterfall Beam) | 약간 | YES WorldKit only (Halo waterfall Beams); not in main | 물줄기 가운데 진한 하늘색, 거품 방울 반짝임 하이라이트; 바닥 그림자 없음 | texture_tile (Beam용 알파), 세로 줄무늬 무늬 | `art/ui/Halo_WaterfallStreaks.png` |
| OLD Tex_Grass (WorldKit stale GE_Grass) | 약간 | WorldKit only, stale pre-Firefly id (main uses FF3) | 풀 덤불 사이 진한 초록 깊이감, 잎끝 밝음 | texture_tile | `art/ui/Tex_Grass.png` |
| Tex_WaterfallFlow_FF2 (waterfall Texture) | 약간 | YES main place: meadow waterfall faces; WorldKit 4 | 광택 하이라이트 줄, 거품 반사광; 그림자 없음 | texture_tile | `art/ui/Tex_WaterfallFlow_FF2.png` |
| GE_Marble (Tex_Marble_FF) | 없음 | YES main place: Marble override (fountain/bridge/Halo parts) | 평평한 크림 대리석 + 금/파랑 결, 그림자 없음 | texture_tile | `art/ui/Tex_Marble_FF.png` |
| HH_Fabric (Halo_Fabric v3b) | 없음 | YES main place 11 Fabric parts; WorldKit 983 parts | 거의 흰색 직조 무늬, 명암 없음 | texture_tile | `art/ui/halo_tile/fabric_v3/b/Halo_Fabric_color.png` |
| HH_HaloGoldTrim (Halo gold trim) | 없음 | YES WorldKit only (18,956 parts); not in main | 거의 흰색 평면, 옅은 가로 붓결만 | texture_tile | `art/ui/halo_tile/Halo_GoldTrim_color.png` |
| HH_HaloMarbleSmooth_Cream (smooth marble) | 없음 | YES WorldKit only (1,309 parts); not in main | 평평한 크림색, 옅은 결만 | texture_tile | `art/ui/halo_tile/marble_smooth/Halo_MarbleSmoothCream_color.png` |
| GE_CrownShardGround (Tex_CrownShardGround) | 진함 | PRESENT but unused (0 parts) | 금 결정 밝은/어두운 면, 흙덩이 가장자리 음영, 틈 어두움 | texture_tile | `art/ui/Tex_CrownShardGround.png` |
| OLD Tex_Basalt (WorldKit stale GE_Basalt) | 진함 | WorldKit only, stale | 각진 바위 면마다 밝은 면/어두운 면, 검은 틈 그림자 | texture_tile | `art/ui/Tex_Basalt.png` |
| OLD Tex_CrackedLava (WorldKit stale GE_CrackedLava) | 진함 | WorldKit only, stale | 울퉁불퉁 바위 덩어리 명암, 용암 틈 옆 어두운 테두리, 그려 넣은 발광 | texture_tile | `art/ui/Tex_CrackedLava.png` |
| OLD Tex_LeafyGrass (WorldKit stale GE_LeafyGrass) | 진함 | WorldKit only, stale pre-Firefly id | 클로버 덩어리 사이 어두운 AO 틈, 잎 겹친 곳 진한 그림자 | texture_tile | `art/ui/Tex_LeafyGrass.png` |
| OLD Tex_Rock (WorldKit stale GE_Rock) | 진함 | WorldKit only, stale | 각진 바위 면마다 밝은 윗면·어두운 옆면, 틈새 어두운 그림자 | texture_tile | `art/ui/Tex_Rock.png` |
| Tex_LeafyGrass_FF2 (FilmSet stale GE_LeafyGrass) | 진함 | FilmSet only, stale | 이끼 둔덕 입체 음영, 잎·돌 아래 드롭 그림자 |  | `art/ui/Tex_LeafyGrass_FF2.png` |
| HH_HaloMarbleBlock (v1 tower marble block) | 약간 | PRESENT WorldKit/UiSandbox MV, 0 parts | 블록 모서리 베벨: 위쪽 밝고 아래·오른쪽 가장자리 약간 어두움, 줄눈 살짝 어두움 | texture_tile | `art/ui/halo_tile/Halo_TowerMarbleBlock_color.png` |
| OLD Tex_Cobblestone (WorldKit stale GE_Cobblestone) | 약간 | WorldKit only, stale | 돌 위쪽 약간 밝고 줄눈 어두움, 부드러운 명암 | texture_tile | `art/ui/Tex_Cobblestone.png` |
| OLD Tex_DirtPath (WorldKit stale GE_DirtPath) | 약간 | WorldKit only, stale (WorldKit 3 parts use GE_DirtPath) | 자갈에 아주 작은 그림자, 전체는 거의 평평한 빛 | texture_tile | `art/ui/Tex_DirtPath.png` |
| OLD Tex_Ground (WorldKit stale GE_Ground) | 약간 | WorldKit only, stale | 갈라진 틈 어두움, 작은 자갈 아래 작은 그림자 | texture_tile, 작은 뼈 조각 무늬 있음 | `art/ui/Tex_Ground.png` |
| OLD Tex_Sand (WorldKit stale GE_Sand) | 약간 | WorldKit only, stale | 모래 물결 밝은 면/어두운 면 부드러운 명암 | texture_tile | `art/ui/Tex_Sand.png` |
| OLD Tex_Slate (WorldKit stale GE_Slate) | 약간 | WorldKit only, stale | 판석 위 가장자리 밝은 베벨, 아래 가장자리 약간 어두움 | texture_tile | `art/ui/Tex_Slate.png` |
| Tex_Grass_FF2 (FilmSet stale GE_Grass) | 약간 | FilmSet only, stale | 밝은 풀덤불 + 어두운 얼룩 덩어리(그림자처럼 보임), 바닥 그림자는 없음 |  | `art/ui/Tex_Grass_FF2.png` |
| GE_HaloTiles (Tex_HaloTiles) | 없음 | PRESENT but unused (clone source of GE_HaloPave) | 평평한 모래색 얼룩, 작은 구멍만 | texture_tile | `art/ui/Tex_HaloTiles.png` |
| OLD Tex_Limestone (WorldKit stale GE_Limestone) | 없음 | WorldKit only, stale | 평평한 얼룩 석회암, 작은 구멍에 아주 약한 음영만 |  | `art/ui/Tex_Limestone.png` |
| OLD Tex_Marble (WorldKit stale GE_Marble) | 없음 | WorldKit only, stale | 평평한 대리석 무늬, 빛 방향 없음 |  | `art/ui/Tex_Marble.png` |
| OLD Tex_WoodPlanks (WorldKit stale GE_WoodPlanks) | 없음 | WorldKit only, stale | 평평한 판자, 얇은 이음선과 못 점만 | texture_tile | `art/ui/Tex_WoodPlanks.png` |

