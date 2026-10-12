# 디자인 검수 — 상태 (2026-10-12 밤, 새 세션 local_2137d284)

보고처: 이미지 생성 2·3·Blender 손보기 → 나 → 최종 검수(local_8166f268). 옛 10/12 점심 큐(돔·NPC de-light·바깥선)는 다 바뀜 = 기록일 뿐(git log 참고).

## 판정 규칙 (최종 검수 10/12 밤 + 사용자)
- **사용자(내 창에 직접): "시트 보지 말고 너가 직접 트리포에서 봐 내장 웹에서"** → 흰 모델·텍스처는 앱 브라우저 **내 탭**에서 직접 돌려 봄(Blender의 seed 탭은 건드리지 않음, 끝나면 seed 앞으로 + 내 탭 닫기). 조작: canvas에 JS PointerEvent(왼 = 돌리기, 오른 = 옮기기), WheelEvent ±240 = 한 칸 확대, 아래 바 x≈613 버튼 = 선(와이어) 끄기, 창 숨김이면 스샷 전마다 1440x900 다시.
- 2D 4면: 한 장씩 전체 크기, 그림자·어두운 면 없음, 4면 같은 카메라 높이, 한쪽 보는 것(꽃·얼굴·방패) 방향 맞음, 옛 그림과 모양·개수·색 같음, 빛살 없음, 게임에서 쓰는 법(분수 물줄기 = FountainFx).
- Tripo 흰 모델 관문: 후보 4개 약한 곳(받침 옆·얇은 장식·물 면·구멍) + 고른 것 사방·위·아래 → 내 통과 뒤 텍스처.
- 순서(SPEC A23-150 2번, 1cd1bf4c): 텍스처(앞면 1장·조명 제거·8K, 30) → 고장은 Tripo 안에서(스마트 메시 수정·다시 뽑기) → 내 확인 → PBR 맨 마지막(5) → Blender는 크기·피벗·방향만. 색 고친 곳은 전·후 100%.
- 사람(NPC·주민·MailBoy)은 맨 마지막(보지도 않음).
- 점수: 빛 마을 승인 목록(noshadow_redo 빛 마을 줄 + art/prompts/house_chunks_queue_2026-10-13.json) 안이면 내가 OK(하나 135, 다시 하기도), 밖은 최종 검수.

## 지금 (10/12 23시쯤)
- 동상 흰 모델 = **B 1a0812be 통과**, 분수 = **C cd70436c 통과**(D 네모 물·B 바닥 없음·A 물 높음) → Blender 손보기 텍스처 중 → PBR 전에 내가 Tripo에서 금 공·물 색 확인.
- 화분 5종 흰 모델 통과: Daisy c9df2ff9, Lavender fd15be73, Rose 9e0487cc, Sunflower 5f8780fb, Tulip f75480d2 → 텍스처 OK, PBR 전 내가 다시 봄. (창 숨김이면 Tripo가 안 그려짐 → store의 model_url로 FBX 받아 Blender 7면 렌더로 판정, 최종 검수 OK 방법.) 잎 한쪽 면 → Roblox DoubleSided(이미지 생성 3에 알림).
- 최종 검수 상시(사용자 10/12 22:30): 이미지→Tripo 먼저, 4면·흰 모델 관문이 다른 판정보다 먼저. 4면 공급 = 이미지 생성 2(집 덩어리 43 큐) + 이미지 생성 3(빛 마을 소품: 벤치부터).
- 텍스처: 동상 B(뒤 앞치마 파랑→흰, 발 사이 얼룩)·분수 C(2단 물 번짐) → Tripo 편집 30점 이하 OK, 고친 뒤 내가 보고 PBR. 크롭 art/review/design/*_tex_*_1012.jpg.
- 4면 판정: BenchA 왼·오른 손질(오른 기준 크기 770px, 왼=뒤집기). 덩어리: DoorSingle·ConeTree 통과→Blender 넘김. LampArm(right=flip left)·WingL(right=flip left)·DomeRibbed(left=front)·DoorDouble(front=flip back)·WindowBoxA(right=flip left + 옆 높이 1015px) 손질 뒤 통과. WingR = **WingL 완성 3D를 Blender 좌우 뒤집기(최종 검수 OK)** — 메시에 굽기 + 노멀 재계산, 앞·위 3/4로 면 뒤집힘·텍스처 늘어남 내가 확인. CastleRose 4면 대기.
- (23시 넘어) Tripo로 넘긴 것: 묶음1 DoorSingle·ConeTree, 묶음2 LampArm·WingL·DomeRibbed·DoorDouble·WindowBoxA, 묶음3 BenchA·BenchC·CastleRose. BenchB 다시(뒤 판자 4→3, 옆 = 끝에서 수평 진짜 옆모습, 비대칭이라 각각).
- 화분 텍스처: Lavender·Tulip·Sunflower PBR OK. Daisy(주황·살구 꽃 → 빨강/흰)·Rose(윗면 탁한 갈색 장미) 편집 뒤 PBR, 총 30점 넘으면 먼저 알림.
- 흰 모델: DoorSingle d61f68e6 통과(뒤 고리는 생성 버릇, 그대로). ConeTree 4개 다 탈락(가시·별 찌그러짐·옥수수·속 빔) → 이미지 생성 2가 큰 잎 뭉치 12~15개로 4면 다시 → 다시 뽑기 100점.
- 흰 모델 통과(→ 텍스처): LampArm 6895c425(유리 칸 빔), WingL 10bf8543, DomeRibbed 2f0b12f2, DoorDouble d28f2316, WindowBoxA 82c8a278, BenchA bbf6251c, BenchC f12d3f90, CastleRose e51189a5. 4면 통과 → Blender: GateLeaf·DomeOnion. DomeOctagon(right = front 복사 뒤 통과), ConeTree(색 R×0.62 G×0.80 뒤 3면), BreadStand(왼쪽 따로 그림) 대기. PBR 판(Lavender·Tulip·Sunflower) 결과 아직 안 봄.
- (23시 반) 흰 모델: GateLeaf 2bc07ecc, DomeOnion 414b871a 통과. DoorSingle 텍스처 f60f57e3 PBR OK. 4면 통과 → Blender 묶음 5: ConeTree(다시 뽑기), DomeOctagon, DomeBall. FruitStall 옆 두 장 다시(비스듬 → 끝에서 수평, 좌우 따로). BreadStand 왼쪽 다시. BenchB 뒤·왼 다시.
- (23시 40분) 텍스처 9개 PBR OK: LampArm·WingL·DomeRibbed·DoorDouble·WindowBoxA·BenchA·BenchC·CastleRose + DoorSingle. 4면 통과 → 묶음 6 FlowerCart·BenchB. **넣을 때 메모(이미지 생성 3에 보냄)**: CastleRose 바깥 유리 칸 비어 있음 → 금 틀 뒤 진한 파랑 원판 파트(≈34,90,180), LampArm 유리 = LampGlass/LampCore, WindowBoxA·화분 잎 DoubleSided.
- PBR 판 확인법: scratchpad pbr_maps.py(맵 추출) + pbr_look.py(EEVEE 해+하늘, PBR vs 색만). 화분 Lavender·Tulip·Sunflower PBR 통과(시트 art/review/design/pots3_pbr_*_1012.jpg). DomeOnionSlim 통과 → Blender. DomeBrick 옆 두 장 다시(둥근 반구라 옆도 앞과 같은 폭, 크림 띠 = 가운데 세로 띠).
- (23시 50분) BreadStand·FruitStall 4면 통과 → 묶음 6 = FlowerCart·BenchB·BreadStand·FruitStall. 최종 검수 보고 4 보냄. 다음: 등불 A~E(이미지 생성 3), 집 덩어리 16 JuiceParasol~(이미지 생성 2), DomeBrick 옆, 묶음 5·6 흰 모델, 매직 브러시 4곳(창 보일 때).
- (자정) 흰 모델 묶음 5·6: ConeTree 2bbbd641(이번엔 됨), DomeOctagon f9e91fe2, DomeBall 66894770, FlowerCart af2e2b5f, BenchB b8de1d3c → 텍스처. DomeBrick 4면 통과 → 묶음 7. JuiceParasol 오른쪽 다시(가까운 상자 = 빨간 사과).
- **교훈: 4면 관문에서 '3D로 될 그림인지'도 봄** — 작은 알갱이 수백 개(잎·꽃 알갱이)는 스마트 메시가 못 따라감 → 큰 덩어리로 단순하게.
- 흰 모델 보는 법(창 숨김일 때): 뒤 탭(tabs_create)에서 store의 model_url → 날짜·uuid·서명만 뽑아 scratchpad tripo_dl.py로 받기(Policy는 다시 만듦) → pot_views.py 7면 점토 렌더.
- 4면 흔한 고장: 좌우 옆면이 서로 다름 / 옆면이 1.2~1.3배 크게 그려짐 / 한 면만 연한 빛 띠 → PIL 뒤집기·복사·크기로 고침(새 생성 X).
- 이미지 생성 3: 동상·분수·화분 새 판 모이면 3D 가져오기(최종 검수 경유) → SA → WorldKit 자리·재질·낮밤 사진. 낮 빛 = 위도 35 + 따뜻한 OA.
