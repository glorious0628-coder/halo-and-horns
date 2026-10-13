# 디자인 검수 2 — 상태 (2026-10-13 오후)

역할(최종 검수 지시 10/13): **이미지 생성 2(local_aeaed629)의 2D 4면 판정 전부** + **Blender 손보기 2(local_9a2805c9, 사용자 Chrome·Tripo 계정 2)의 흰 모델 고르기·PBR 첫 검수**. 디자인 검수 1(local_2137d284) = Blender 손보기 1(local_1bcb35c4) 흰 모델·PBR + 이미지 생성 3 놓기 사진. 보고 = 최종 검수(local_8166f268)만. 빛 마을만. 판정 규칙·교훈은 `state/design_review.md`와 같음.

## 다시 시작하면 기다리는 것
1. **8K vs 4K 텍스처 비교**(사용자 결정: 텍스처 4K, 두 계정): Blender 손보기 2가 첫 1개를 8K·4K 둘 다 만들어 보냄 → 같은 자리 100% 크롭 나란히, 게임 크기 1024에서도 차이 보이는지 → 최종 검수에.
2. **(10/13 13시 판정: 9종 PBR 통과 → 최종 검수, 시트 `art/review/design2/pbr_gate_1013/`. FlowerBush 떨어짐 → 7cafd99b로 다시, Planter_D 4K PBR 대기)** Blender 손보기 2 PBR 결과 11종 → PBR 첫 검수(`tools/design_review/pbr_gate.py` 700 2048 → `pbr_gate_sheet.py`) → 통과만 최종 검수(이름 + 파일 경로 + ⑤ 메모).
   - 고른 흰 모델: Planter_D 105124b0 · FlowerCart_Bouquet 82912694 · Bal_E 781e6f4e · Bal_F 934efdb9 · Bal_A bcaca51e · Bal_B add2a937 · Bal_C 531c8172 · Bal_D 71359ce0 · NEW_FlowerBush 6e6bd726 · NEW_WallLamp 8ec1b5e1 · NEW_Hedge 67f8ae44
   - ⑤ 메모: Bouquet 4개 다 꽃 뒤 빈 껍데기 → 꽃 DoubleSided, 뒤를 수레 안/벽 쪽. Bal_C ㄱ 안쪽에 받침 높이 세모 바닥판 → 땅에 살짝 묻기. FlowerBush는 꽃 원판 자리 = 앞면 2D 꽃 자리라 고름.
   - 흰 모델 FBX `art/models/tripo/wm2_1013/<이름>/<id8>.fbx`, 시트 `art/review/blender2/wm_1013/<이름>.jpg`.
3. **이미지 생성 2 큰 지도 그림** 판정.

## 2D 4면 판정 끝(10/13)
- 통과 → Blender 손보기 1: GatherBush·CandleCrate·Easel·NoticeBoard·ArmoryBarrels·WaterBuckets(디자인 검수 1 먼저 판정 따름).
- 통과 → **Blender 손보기 2로 옮김(최종 검수 10/13)**: 간판 Bakery·Flower·Juice·Potion, NEW_Beehive, NEW_WateringCan, NEW_SteppingStone(돌 하나; 옛 5개 줄 NEW_SteppingStones는 안 씀). 텍스처 4K → 1개 125점, 점수 승인·흰 모델·PBR 판정 = 나.
- 통과 → Blender 손보기 2: NEW_Hedge, NEW_WallLamp(_left/_right 이름 맞바꿈 6bfc4ff 뒤).

## 교훈
- 판정이 두 검수에서 겹치면 먼저 내려간 판정을 따르고, 정정은 관련 세션 모두에 한 번에(메시지가 엇갈림).
- 벽에 붙는 물건(벽 등불·간판): `_left` = 앞이 화면 오른쪽 → 벽판/기둥은 화면 왼쪽. 파일 이름 거꾸로 흔함.
- 옆면에서 앞면 볼록(그림 부조)은 판의 앞쪽 한쪽에만, 판은 팔·기둥 축 가운데. 측정: 판 아래 끝 가운데 x vs 기둥 꼭대기 가운데 x.
- 지붕 박공이 앞에 있으면 옆면은 경사 지붕면(박공·구멍 없음). 옆면을 앞면 복사로 그리는 고장 흔함.
- 여러 개 같은 돌·조각 줄은 하나만 4면으로(같은 카메라), Studio에서 여러 번 놓기.
- 덤불·잎 흰 모델은 **뒷면 안 지운 흰 실루엣(검은 바탕)으로 앞·옆 비침 검사** 먼저(점토 렌더는 뒷면을 지워 구멍이 안 보임) — FlowerBush 6e6bd726 실수. 스크립트: 스크래치 `holes.py`와 같은 방법(Workbench FLAT 흰색, backface culling 끔).
- 흰 모델은 `clay_views.py`로 직접 크게(창 없이) — 아래(low)에서 받침 갈라짐이 잘 보임. 앞면 2D 무늬 자리와 모양 자리가 맞는 흰 모델을 고르면 텍스처가 제자리에 앉음.
