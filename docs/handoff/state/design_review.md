# 디자인 검수 — 상태 (2026-10-13 새벽 2시, 사용자 "정리하고 컴퓨터 꺼줘")

세션 local_2137d284(10/12 밤 새로). 보고처: 이미지 생성 2·3·Blender 손보기 → 나 → 최종 검수(local_8166f268). 옛 10/12 점심 큐(돔·NPC de-light·바깥선)는 끝난 기록(git log).

## 판정 규칙
- 최종 검수 상시(사용자 10/12 22:30): **이미지 → Tripo 먼저**, 4면·흰 모델 관문이 다른 판정보다 먼저. 크레딧 모자라면 밀린 일. 사용자 클릭이 필요한 것은 최종 검수에게만.
- 사용자(내 창): **"시트 보지 말고 너가 직접 트리포에서 봐"** → 흰 모델·텍스처·PBR은 내가 직접. 창이 숨겨지면 Tripo가 안 그려짐 → `tools/design_review/` (README) 로 FBX 받아 Blender 렌더. 점수 버튼·좌표 클릭 금지, Blender의 `seed` 탭 안 건드림, 내 탭은 끝나면 닫음.
- 2D 4면: 한 장씩 전체 크기 + 옛 그림(`art/review/img3/chunk_refs/`, 옛 승인 2D) 옆, 물체 높이 재기(PIL bbox). 그림자·어두운 한쪽 없음, 같은 카메라·같은 물체 높이, 좌우 옆면 서로 맞음(비대칭이면 각각 그림), 옆 = 끝에서 수평, 둥근 것은 4면 같은 폭, 옛과 개수·색 같음, 빛살 없음, 게임에서 쓰는 법.
- **3D로 될 그림인지**: 작은 알갱이 수백 개(잎·꽃 알갱이)는 스마트 메시가 못 따라감(ConeTree 1차 4개 전부 탈락) → 큰 덩어리 10~15개로.
- 고칠 때는 새 생성보다 PIL(뒤집기·복사·크기·색 보정) 먼저. 키운 결과가 캔버스 밖이면 반대로 다른 면을 줄임(Greenhouse).
- 흰 모델 관문: 후보 4개 사방·위·아래 → 바닥 뚫림·속 조각·얇은 장식 끊김·뒷면 찍힘 비교 → 고른 것 + 이유 + 탈락 이유를 Blender 손보기에.
- 순서(SPEC A23-150 2번): 흰 모델(100) → 텍스처(앞 1장·조명 제거·8K, 30) → 고장은 Tripo 안에서 → 내 확인 → PBR(5) → 내 PBR 확인(빛 넣은 렌더) → Blender 크기·피벗·방향만 → 이미지 생성 3.
- 점수: 빛 마을 목록(`docs/review/noshadow_redo_2026-10-12.md` 빛 마을 줄 + `art/prompts/house_chunks_queue_2026-10-13.json`) 안 = 내가 OK(135/개, 다시 하기도), 밖 = 최종 검수. 사람(NPC·주민·MailBoy)은 맨 마지막(보지도 않음).

## 지금 어디까지 (Tripo 잔액 Blender 손보기 마지막 보고 9,635 → 그 뒤 텍스처 더 씀)
**끝(PBR 통과 → Blender 마무리 → 이미지 생성 3에 넘김):** 화분 Lavender·Tulip·Sunflower(시트 `art/review/design/pots3_pbr_*_1012.jpg`), DoorSingle, LampArm, CastleWingL, **CastleWingR(= WingL Blender 거울, 최종 검수 OK, 통과)**, DomeRibbed, DoorDouble, WindowBoxA, BenchA, BenchC, CastleRose(시트 `chunks9_pbr_vs_flat_1013.jpg`).
**텍스처 PBR OK, PBR 결과 아직 안 봄:** GateLeaf(흰 2bc07ecc), DomeOnion(414b871a).
**흰 모델 고름 → 텍스처 중(텍스처 결과 아직 안 봄):** ConeTree 2bbbd641(2차, 큰 잎 뭉치), DomeOctagon f9e91fe2, DomeBall 66894770, FlowerCart af2e2b5f, BenchB b8de1d3c, DomeOnionSlim 40dad418, BreadStand 00dac363, FruitStall 568b5b8e, DomeBrick 46f0bb09.
**4면 통과 → 흰 모델 대기:** JuiceParasol, Greenhouse, ShopSign, Lantern_A·C·D·E.
**매직 브러시 보류(창 보일 때 Blender 손보기가, 한 번 30점 이하):** 동상 B(뒤 앞치마 파랑 → 흰, 발 사이 얼룩), 분수 C(2단 물 위 크림·주황 번짐), Daisy(주황·살구 꽃 → 빨강/흰), Rose(윗면 탁한 갈색). 크롭 `art/review/design/*_tex_*_1012.jpg`. 끝나면 내가 보고 PBR.
**다시 그리는 중:** IvyWall(가는 줄기·성긴 잎이라 큼직 잎 판으로 다시, 지금 판은 Tripo 안 넘김), IvyBalcony(큼직 잎 문구로 생성 중, 미판정). Lantern_B(받침 금테 판 = 면마다 1개, 지금 2개). 이미지 생성 2 큐 19 IvyWall부터(잎 큼직하게 미리 말함). 이미지 생성 3 소품 큐: 벤치 3·가판대 3·등불 5 끝 → 다음은 `docs/review/halo_redo_split_2026-10-12.md` '그릴 것' 순서.

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
