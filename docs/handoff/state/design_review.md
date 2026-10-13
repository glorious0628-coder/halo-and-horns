# 디자인 검수 — 상태 (2026-10-13 낮 12시 반, 스스로 클리어 전 정리)

세션 local_2137d284. 보고처: 이미지 생성 2(local_aeaed629)·이미지 생성 3(local_d54578c7)·Blender 손보기 1(local_1bcb35c4) → 나 → 최종 검수(local_8166f268). **Blender 손보기 2(local_d85ba88a) 몫 12종의 흰 모델·PBR 첫 검수 = 디자인 검수 2(local_11c9d705)**; 빛 마을 전체 놓기 사진 판정은 나(최종 검수 10/13 짝 정리).

## 다시 시작하면 바로 할 일 (기다리는 것)
1. **이미지 생성 3 ⑤ 고친 사진 2차**(12:30 판정, 메시지 d280b30a) → 통과면 ⑤ 묶음 1을 최종 검수에 보고:
   - 통과: Tulip 3곳, Lavender P083, BenchA P056·065·068·105, BenchC P064·121, 해바라기 색 맵, 날개
   - CastleRose: 파란 판 지름 5.93 → 약 6.65(금 테 안쪽 바깥 칸이 크림 벽으로 보였음)
   - Sunflower: 얼굴이 집 쪽 → 세 곳 Y 180°
   - Lavender P022: 카메라가 다른 보라 꽃 속 → 무엇인지 + 다시 찍기
   - BenchA P015: 줄무늬 물체가 가림 → 다시
   - P026·048·049 땅: 보이는 땅이 물리 땅보다 높음 → 3~5초 기다려 다시 찍기 → CanQuery 꺼진 땅 메시 검사 → 그래도면 Studio 다시 열기(최종 검수 먼저)
2. **이미지 생성 2 4면** — 빛 마을 소품 NEW_ 11종이 한 종씩 옴:
   - 소품: GatherBush·Hedge·WallLamp·WateringCan·ArmoryBarrels·Beehive·CandleCrate·Easel·NoticeBoard·SteppingStones·WaterBuckets
   - 그다음 가게 간판 4종
   - 통과하면 Blender 손보기 1 흰 모델 큐에 넣음(135점/개, 내 OK)
3. **Blender 손보기 1 PBR 결과** → PBR 관문(아래 방법). 통과만 최종 검수에 보냄(이름 + 파일 경로 + ⑤ 메모).
   - 대기 중: 동상 B 1a0812be, 분수 C cd70436c, Daisy, Rose
   - GateLeaf, DomeOnion, ConeTree, DomeOctagon, DomeBall, BenchB, FlowerCart(수레 몸)
   - JuiceParasol, DomeOnionSlim, BreadStand, FruitStall, DomeBrick
   - 흰 모델 20종(아래)의 PBR
4. **Blender 손보기 1 흰 모델 새 묶음** → 내가 고름. 지금 큐 순서:
   - 식물: Topiary_E·PotFlowers E/F·Var4 PotFlowers A/C/D·Planter_A·PotionDisplay·JuiceStand·RoseTrellis·RoseArch·SunflowerBed·Pond·StarFinial·CastleHedge
   - 집 덩어리: WeatherVane·ChimneyCap·ChimneyLantern·RoundTree·MedalBell·Cauldron·FlowerBuckets·WindowBoxB·CornerFinial·Telescope
   - Blender 손보기 2로 간 것은 빠짐

## 판정 규칙
- **3D = SPEC A23-154 다섯 단계뿐:** ① 그림자 없는 2D 4면 → 스마트 메시 ② **내가 흰 모델 4개 중 고름** ③ 텍스처(앞 1장·조명 없이·8K) ④ PBR(텍스처 끝나면 바로) ⑤ Roblox 재질(2D 옆 낮·밤) **내가 사진 판정**. 매직 브러시·붓 칠·Blender 색 고치기·다시 올리기 없음. 얼룩은 ⑤에서 좋게 하거나 그대로, 모양이 망가졌으면 ②에서 다른 흰 모델. Blender = 크기·피벗·방향(대칭 짝 뒤집기)만.
- **PBR 관문(사용자 10/13):** PBR 끝난 모델 = 내가 먼저(`tools/design_review/pbr_gate.py` 700 2048 → `pbr_gate_sheet.py`: 2D 4면 | 해+하늘 렌더 앞·옆·뒤·옆·위3/4 같은 배율 | 디테일 100% 크롭 3) → 통과만 최종 검수에 → 최종 검수 통과 뒤 이미지 생성 3. 묶음 1(13종) = 최종 통과(`art/review/design/pbr_gate_1013/`).
- **화면에 뜨는 일(앱 브라우저 창·다운로드·Blender 창·마우스·키보드) = 매번 최종 검수에 신청 → "전달함, 시작" 뒤에만.** 렌더는 Blender --background만. 사용자에게 할 말은 최종 검수에게만; 이미지 생성 2·3·Blender 손보기가 사용자에게 직접 말하면 최종 검수에 알림.
- 흰 모델은 내가 직접 봄(사용자 "시트 보지 말고 직접"). 창이 숨겨지면 Tripo가 안 그려짐 → 내 탭(창 신청 뒤)에서 Tripo 자산 목록 API로 model_url 모아 FBX 받고 점토 7면 렌더(`tools/design_review/README.md` 7번). 점수 버튼·좌표 클릭 금지, 다른 세션 탭 안 건드림, 내 localStorage 키 지우고 탭 닫기.
- 2D 4면: 한 장씩 + 옛 그림(`art/review/img3/chunk_refs/`) 옆, 물체 높이 재기(PIL bbox). 그림자·어두운 한쪽·어두운 틈 없음, 같은 카메라·같은 높이, 좌우 옆면 서로 맞음, 둥근 것은 4면 같은 폭, 옛과 개수·색 같음, 빛살 없음. 옆면 방향: `_left` = 앞이 화면 오른쪽, `_right` = 앞이 화면 왼쪽.
- 3D로 될 그림인지: 작은 알갱이 수백 개는 스마트 메시가 못 따라감 → 큰 덩어리.
- 고칠 때는 PIL(뒤집기·크기·색) 먼저.
- 점수: 빛 마을 목록(`docs/review/noshadow_redo_2026-10-12.md` 빛 마을 줄 + `art/prompts/house_chunks_queue_2026-10-13.json`) 안 = 내가 OK(135/개), 밖 = 최종 검수. 사람(NPC·주민·MailBoy)은 맨 마지막.
- 목록에서 뺀 것: NEW_Cauldron·NEW_Telescope(HaloChunk판만, 최종 검수 OK 10/13), NEW_WhiteRock a/b/c·BellFrame_Bell·WallLamp_Head(버림).

## 끝난 것 (10/13까지)
- **PBR 최종 통과 → 이미지 생성 3 놓음:** DoorSingle·DoorDouble·LampArm·CastleWingL/R·DomeRibbed·WindowBoxA·CastleRose·BenchA·BenchC·Lavender·Tulip·Sunflower(⑤에서 고칠 것 위 1번).
- **흰 모델 20종 고름(10/13, 시트 `art/review/design/wm_1013/`):**
  - Greenhouse d148d3bd, ShopSign e96efdb6
  - Lantern_A 3b8c167c, Lantern_B 4b6f9db9, Lantern_C 096e84f2, Lantern_D 1eed23ce, Lantern_E c102246e
  - IvyWall 18598e34, IvyBalcony 0352e909
  - **FlowerBushPot 5a5af84d**: 4개 다 뒤가 빔 → ⑤ 덤불 속 초록 공 파트 또는 뒤를 벽 쪽
  - DomePorchHalf e549329c, DomePavilion bc5097f2, DomeTowerSmall 6d925d8a, BreadDisplay e5467c5f
  - RoundTree_E 077f2fae, RoundTree_F cc3f527f, RoundTree_G a9395b47
  - Topiary_C 3e2847ad, Topiary_D 7c673fb4, Planter_E 1021df70
- 그 전에 고른 흰 모델:
  - 화분 5, DoorSingle, LampArm, WingL, DomeRibbed, DoorDouble, WindowBoxA, BenchA·C, CastleRose
  - GateLeaf 2bc07ecc, DomeOnion 414b871a, ConeTree 2bbbd641, DomeOctagon f9e91fe2, DomeBall 66894770, FlowerCart af2e2b5f, BenchB b8de1d3c
  - DomeOnionSlim 40dad418, BreadStand 00dac363, FruitStall 568b5b8e, DomeBrick 46f0bb09, JuiceParasol 6ec4d75d
- 집 덩어리 그림 1~43 끝(이미지 생성 2). 34~43 판정 끝, 흰 모델 큐에 들어감.
- 빛 성 C2 골격 v4 통과. 벽 재질 B(HH_HaloMarbleSmooth_Cream + 255,255,255) 적용 사진 통과. 밤 창 빛 = 장식/빛 단계. 마을 배치 때 정문이 낮에 해 받는지 확인.

## 넣을 때 메모 (이미지 생성 3에 보낸 것)
- 장식 파트:
  - CastleRose = 뒤 진한 파랑 원판(34,90,180)
  - LampArm·등불 = LampGlass/LampCore 파트
- 재질·면:
  - 화분 잎·창 화분 = DoubleSided
  - 돔 SurfaceAppearance.Color 255,222,180, 쌍문 255,236,214
  - Tripo 금은 2D보다 어둡고 레몬빛 → ⑤에서 맞춤
- 그대로 둘 것: DomeBrick 바닥 뚫림(지붕 위라 안 보임), DoorSingle 뒤 고리

## 교훈
- 옛 그림이 3/4면이면 '보이는 두 면'을 정면 하나로 합쳐 그리는 실수 → 면마다 개수 세기.
- 4면 흔한 고장:
  - 좌우 옆면이 서로 다름
  - 옆이 1.05~1.3배 크게 / 둥근 것 옆이 좁게
  - 한 면만 연한 빛 띠
  - 비스듬한 옛 시점
  - 아치 안 어두운 갈색
- 흰 모델 흔한 고장:
  - 바닥 뚫림, 속 조각, 떠 있는 조각
  - 뒷면에 앞 장식 찍힘, 잎이 한쪽 면이라 뒤가 빈 판
  - 가운데 큰 공 덩어리
  - 얇은 받침 두 겹 틈, 장식판 빠짐
- 시트 크롭이 맞닿으면 가짜 이음선처럼 보임 → 크롭 사이 틈(도구 고침).
- 메시지가 밀려 '못 받았다'고 하면 메시지 id로 다시 적어 줌.
