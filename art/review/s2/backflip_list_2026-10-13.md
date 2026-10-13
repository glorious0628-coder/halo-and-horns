# 빛 마을 4면: 뒤 = 앞 좌우 뒤집기로 바꾼 것 (이미지 생성 2, 2026-10-13 밤, 최종 검수 새 규칙)

규칙: 앞·뒤가 거의 같은 물건(덤불·화분·양동이·대칭 소품)은 뒤 = 앞 PIL 좌우 뒤집기(꽃 수·배치가 앞과 같게). 옆면은 그대로.
고른 법: 대칭 종류 66세트 중 '뒤 vs 앞 뒤집기' 차이 점수 ≥14인 37개를 앞|뒤|뒤집기 시트로 눈으로 봄. 점수 <14 는 이미 뒤집기(0 근처)이거나 차이가 작음.
옛 뒤 백업: `build/img2_next/pil_orig/backflip_1013/` (git 밖).

## 바꿈 (30)
- 소품 `art/out/s2/noshadow/`: NEW_FlowerBush · NEW_GatherBush · HaloFlowerPotHQ_Daisy · HaloFlowerPotHQ_Rose · HaloFlowerPotHQ_Lavender · HaloVar4_PotFlowers_A/C/D · HaloVar3_PotFlowers_E/F · HaloVar4_Planter_A/D · HaloVar3_RoundTree_E/F/G · HaloVar3_Topiary_C/D
- 덩어리 `art/out/s2/noshadow/chunks/`: HaloChunk_FlowerBuckets · Pond · RoundTree · ConeTree · Cauldron · DomeTowerSmall · DomeOnion · DomeOnionSlim · DomeRibbed · DomeBall · CornerFinial · StarFinial · ChimneyLantern

## 안 바꿈 (앞뒤가 원래 다름, 8)
- HaloChunk_SunflowerBed, HaloFlowerPotHQ_Sunflower: 해바라기가 앞을 봄 → 뒤는 꽃 뒷면이 맞음
- HaloChunk_FlowerBushPot: 앞에만 꽃(뒤는 잎)
- HaloVar4_Balustrade_C: L자 모서리 난간, 뒤는 안쪽 모서리
- NEW_Beehive: 앞에만 드나드는 구멍
- HaloVar3_Planter_E: 앞에 낮은 단이 있는 2단 화단
- NEW_ArmoryBarrels: 통·상자 무리, 뒤에서 가림 순서가 다름
- HaloChunk_DomePorchHalf: 반쪽 돔, 뒤는 평평한 자른 면

## 주의
- 이미 Tripo로 만든 모델은 그대로(2D만 바뀜). 앞으로 Meshy 리텍스처(A23-168) 때 이 뒤를 씀.
