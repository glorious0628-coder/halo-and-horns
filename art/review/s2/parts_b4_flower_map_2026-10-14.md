# 빛 마을 ④ 화분·꽃 부품 — 물건마다 꽃 (이미지 생성 2, 10/14)

시트: `art/review/s2/parts_b4_pots_flowers_2026-10-14.jpg`. 파일: `art/out/s2/noshadow/parts/<이름>_{front,left,right,back}_ns.png`.
꽃은 공유 부품(같은 2D = 모델 하나, 크기만 바꿔 여러 번 꽂음, A23-150 #5). 개수는 승인 앞·뒤 그림에서 센 둘레 전체 어림값(합칠 때 잎 덩어리 위에 고르게).

| 물건 | 그릇/바탕 부품 | 잎 부품 | 꽃 (공유 부품 × 개수) |
|---|---|---|---|
| HaloFlowerPotHQ_Daisy | `_Pot` | `_Leaves` | RedDaisy × 7(큰), WhiteDaisy × 10, RedBud × 12 |
| HaloFlowerPotHQ_Rose | `_Bowl` | `_Leaves` | PinkRose × 14, RoseBud × 12 |
| HaloVar3_PotFlowers_F | `_Vase` | `_Vines` | WhiteDaisy × 16(작게, 덩굴 위·끝) |
| HaloVar4_PotFlowers_A | `_Bowl` | `_Leaves` | WhiteDaisy × 10, Blue5 × 8 |
| HaloVar4_PotFlowers_C | `_Urn` | `_Leaves` | Blue5 × 12 |
| HaloChunk_FlowerBuckets | `_WoodBucket`, `_SilverBucket` | — | 나무 통: TulipWhite × 3, TulipBlue × 2 / 은 통: Hydrangea(⑤ 묶음에서 그림) 흰 1·파랑 1 송이 |
| HaloChunk_FlowerBushPot | — | `_Leaves` | WhiteDaisy × 6, Blue5 × 4 (작은 노란 꽃 4개는 뺌 — 최종 검수 OK 10/14) |
| NEW_FlowerBush | — | `_Leaves` | WhiteDaisy × 8, Lilac × 10 |

공유 꽃 9종: WhiteDaisy·Blue5·Lilac·RedDaisy·PinkRose = 앞·옆·뒤 4면(오른 면 = 왼 면 뒤집기). RedBud·RoseBud = 돌려도 같아 앞 1장 → 4면 복사. TulipWhite·TulipBlue = 옆면 따로(잎이 앞뒤로 겹친 좁은 모습, 10/14 다시), 뒤 = 앞 뒤집기.
꽃 4면 방향: 앞 = 꽃 얼굴, 옆 = 꽃이 화면 오른쪽(왼 면)을 봄, 뒤 = 꽃받침·줄기 끝.
