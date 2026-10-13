# 디자인 검수 — 상태 (2026-10-13 오전 10시)

세션 local_2137d284(10/12 밤 새로). 보고처: 이미지 생성 2·3·Blender 손보기 → 나 → 최종 검수(local_8166f268). 옛 10/12 점심 큐(돔·NPC de-light·바깥선)는 끝난 기록(git log).

## 판정 규칙
- 최종 검수 상시(사용자 10/12 22:30): **이미지 → Tripo 먼저**, 4면·흰 모델 관문이 다른 판정보다 먼저. 크레딧 모자라면 밀린 일. 사용자 클릭이 필요한 것은 최종 검수에게만.
- 사용자(내 창): **"시트 보지 말고 너가 직접 트리포에서 봐"** → 흰 모델·텍스처·PBR은 내가 직접. 창이 숨겨지면 Tripo가 안 그려짐 → `tools/design_review/` (README) 로 FBX 받아 Blender 렌더. 점수 버튼·좌표 클릭 금지, Blender의 `seed` 탭 안 건드림, 내 탭은 끝나면 닫음.
- 2D 4면: 한 장씩 전체 크기 + 옛 그림(`art/review/img3/chunk_refs/`, 옛 승인 2D) 옆, 물체 높이 재기(PIL bbox). 그림자·어두운 한쪽 없음, 같은 카메라·같은 물체 높이, 좌우 옆면 서로 맞음(비대칭이면 각각 그림), 옆 = 끝에서 수평, 둥근 것은 4면 같은 폭, 옛과 개수·색 같음, 빛살 없음, 게임에서 쓰는 법.
- **3D로 될 그림인지**: 작은 알갱이 수백 개(잎·꽃 알갱이)는 스마트 메시가 못 따라감(ConeTree 1차 4개 전부 탈락) → 큰 덩어리 10~15개로.
- 고칠 때는 새 생성보다 PIL(뒤집기·복사·크기·색 보정) 먼저. 키운 결과가 캔버스 밖이면 반대로 다른 면을 줄임(Greenhouse).
- 흰 모델 관문: 후보 4개 사방·위·아래 → 바닥 뚫림·속 조각·얇은 장식 끊김·뒷면 찍힘 비교 → 고른 것 + 이유 + 탈락 이유를 Blender 손보기에.
- **순서 = SPEC A23-154(사용자 10/13 낮) 다섯 단계뿐:** ① 그림자 없는 2D 4면 → 스마트 메시 ② **내가 흰 모델 4개 중 고름** ③ 텍스처(앞 1장·조명 없이·8K) ④ PBR(텍스처 끝나면 Blender 손보기가 바로, 내 관문 없음) ⑤ Roblox 재질 더 좋게(2D 옆 낮·밤) → **내가 사진 판정**. 매직 브러시·붓 칠·Blender 색 고치기·다시 올리기 **없음**("붓질 하지 말라고 했는데?"). 얼룩은 ⑤ 재질에서 좋게 하거나 그대로; 모양이 정말 망가졌으면 ②에서 다른 흰 모델. Blender = 크기·피벗·방향(대칭 짝 뒤집기)만. 내 일 = 2D 4면 판정 + ② + ⑤.
- 점수: 빛 마을 목록(`docs/review/noshadow_redo_2026-10-12.md` 빛 마을 줄 + `art/prompts/house_chunks_queue_2026-10-13.json`) 안 = 내가 OK(135/개, 다시 하기도), 밖 = 최종 검수. 사람(NPC·주민·MailBoy)은 맨 마지막(보지도 않음).

## 지금 어디까지 (Tripo 잔액 Blender 손보기 마지막 보고 9,635 → 그 뒤 텍스처 더 씀)
**끝(PBR 통과 → Blender 마무리 → 이미지 생성 3에 넘김):** 화분 Lavender·Tulip·Sunflower(시트 `art/review/design/pots3_pbr_*_1012.jpg`), DoorSingle, LampArm, CastleWingL, **CastleWingR(= WingL Blender 거울, 최종 검수 OK, 통과)**, DomeRibbed, DoorDouble, WindowBoxA, BenchA, BenchC, CastleRose(시트 `chunks9_pbr_vs_flat_1013.jpg`).
**텍스처 PBR OK, PBR 결과 아직 안 봄:** GateLeaf(흰 2bc07ecc), DomeOnion(414b871a).
**(10/13 아침) PBR OK:** ConeTree 2bbbd641, DomeOctagon f9e91fe2(지붕 위 가는 틈, 그대로), DomeBall 66894770, BenchB b8de1d3c, FlowerCart af2e2b5f(수레 몸만) — 시트 `art/review/design/batch56_tex_1013.jpg`. **FlowerCart 꽃 = 새 조각 HaloReasonHQ_FlowerCart_Bouquet**(꽃 짐만, 이미지 생성 3 4면 → Tripo 135, 수레 위에 얹어 작은 꽃·떠 있는 잎 덮음; 비교 `flowercart_2d_vs_tex_1013.jpg`). JuiceParasol 흰 모델 = 6ec4d75d → 텍스처.
**흰 모델 고름 → 텍스처 중:** DomeOnionSlim 40dad418, BreadStand 00dac363, FruitStall 568b5b8e, DomeBrick 46f0bb09.
**4면 통과 → 흰 모델 대기:** Greenhouse, ShopSign, Lantern_A·B(10/13 다시 그림 통과)·C·D·E. (JuiceParasol 흰 모델은 10/13 아침 6ec4d75d로 고름.)
**(매직 브러시 계획 취소 — A23-154):** 동상 B·분수 C·Daisy·Rose 얼룩은 칠하지 않음 → PBR 바로, ⑤ Roblox 재질 사진에서 판정(크롭 `art/review/design/*_tex_*_1012.jpg` = 얼룩 자리 참고).
**IvyWall 큼직 잎 판 4면 통과 → 흰 모델 큐(로그인 뒤).** 10/13 오전 4면 통과 → 흰 모델 큐: IvyBalcony, FlowerBushPot(right = flip left), DomePorchHalf(뒤 = 평평한 금 단면, **반쪽으로 나와야 함**), DomePavilion(left = front), DomeTowerSmall, BreadDisplay. JuiceStand 왼쪽 다시(초록 사과·컵 끝). **흰 모델 큐(로그인 뒤) = Greenhouse·ShopSign·Lantern A~E·IvyWall·IvyBalcony·FlowerBushPot·DomePorchHalf·DomePavilion·DomeTowerSmall·BreadDisplay (15) + 이미지 생성 3 식물 15종(RoundTree_E·F·G, Topiary_C·D·E, PotFlowers_E·F, Var4 PotFlowers_A·C·D, Planter_A·D, Var3 Planter_E, FlowerCart_Bouquet) = 30개 ≈ 4,050점.** + PotionDisplay·JuiceStand·RoseTrellis·RoseArch·Balustrade_E·F·Var4_A = 37개 + SunflowerBed·Pond·Var4_Balustrade_B·C·D·StarFinial = 43개 + NEW_BellFrame·BreadBasket·CafeTable·FlowerBush·Cauldron = **48개 ≈ 6,480점(잔액 9,385)**. NEW_ 남은 12종 = 이미지 생성 3 Firefly 고급(≈150 크레딧, 내 OK, 창·로그인은 최종 검수). CastleHedge = 최종 검수 결정: 골격 아니오 → **이어 붙이는 한 토막만 Tripo**(PIL로 덩어리 3 + 받침 잘라 4면, 통과, 큐 49개 ≈6,615점). 빛 성 C2 골격 v4 통과. 성 벽 재질 = **B HH_HaloMarbleSmooth_Cream + 흰 255,255,255**, 받침 248,244,236 (시트 art/review/img3/houses/castle_C2_marble_v2/castle_marble_test.jpg) → **10/13 적용 사진 통과**(`art/review/img3/houses/castle_C2_wk_v4b/castle_C2_wk_day.jpg`·`_night.jpg`: 해 쪽 ≈248,234,207, 그늘 쪽 회색 = 해 방향, 밤 푸르스름한 흰색). 밤 창 빛 = 장식/빛 단계 Studio 파트. 마을 배치 때 정문이 낮에 해 받는지 사진 확인. 이미지 생성 2 ChatGPT 사용량 끝 → Firefly 고급(앱 브라우저 + Adobe 로그인 필요, 최종 검수). **NEW_WhiteRock a/b/c·BellFrame_Bell·WallLamp_Head = 버림 목록(그리지 않음)** — 이미지 생성 3에 알림. sidefix 구멍 점검(갇힌 바탕 픽셀 자홍 칠) = 잎 사이 틈 수준, 이상 없음. **10/13 오전 사용자 Tripo·Firefly 로그인 → Tripo 다시 돎(Blender 손보기: 매직 브러시 → PBR 7 → 텍스처 5 → 흰 모델 큐). 사용자 "자잘한 디자인은 나중, 지금은 빛 마을에 집중" → 관문은 빛 마을 것만(지금 큐 그대로).** 옆면 방향 규칙: `_left` = 앞이 화면 오른쪽, `_right` = 앞이 화면 왼쪽(BenchB·IvyWall 기준).
**다시 그리는 중:** IvyBalcony(앞면 좋음, 4면 대기), FlowerCart_Bouquet(이미지 생성 3). (끝난 것: Lantern_B)(받침 금테 판 = 면마다 1개, 지금 2개). 이미지 생성 2 큐 19 IvyWall부터(잎 큼직하게 미리 말함). 이미지 생성 3 소품 큐: 벤치 3·가판대 3·등불 5 끝 → 다음은 `docs/review/halo_redo_split_2026-10-12.md` '그릴 것' 순서.

## 넣을 때 메모 (이미지 생성 3에 보냄)
- CastleRose: 바깥 유리 칸이 3D에서 빔 → 금 틀 바로 뒤 진한 파랑 얇은 원판 파트(≈34,90,180).
- LampArm: 유리 칸 빔 → LampGlass/LampCore 파트. 등불 A~E 유리·밤빛도 Studio 파트로 덮을 수 있음.
- WindowBoxA·꽃 화분 잎: DoubleSided.
- Sunflower 잎 금속 0.3·Lavender 거칠기 낮음 → Roblox 낮 사진에서 번쩍이면 거칠기만 올림.
- DomeBrick 바닥 뚫림 = 빵집 지붕 위라 안 보임. DoorSingle 뒤 고리 = 생성 버릇, 그대로.

## 교훈
- 옛 그림이 3/4면이면 '보이는 두 면'을 정면 하나로 합쳐 그리는 실수(Lantern_B 판 2개, BenchA 옆) → 면마다 개수 세기.
- 4면 흔한 고장: 좌우 옆면이 다름 / 옆이 1.2~1.3배 크게 / 한 면만 연한 빛 띠 / 옆이 비스듬한 옛 시점 / 둥근 것 옆을 반쪽으로.
- 흰 모델 흔한 고장: 바닥 뚫림·속 조각, 뒷면에 앞 장식 찍힘, 가운데 큰 덩어리 하나(꽃 수레·과일), 띠 갈라짐.
- Blender 손보기에 보낸 메시지가 밀려 '못 받았다'고 할 때가 있음 → 다음 메시지에 메시지 id로 다시 적어 줌.
