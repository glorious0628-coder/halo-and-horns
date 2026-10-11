# 디자인 검수 — 상태 (2026-10-12 새벽)

- 역할: `role_prompts/13_design_review.md`. 보고처 = 최종 검수('모든 것 검수'). 세션 id는 list_sessions로.
- 확정값(최종 검수): 금 (255,168,36), 금속 0.5·거칠기 0.15.
- 판정 기준 추가(사용자 10/11 "그림자가 없어서 이상한 건가, 뭔가 선이 없어 보여"): 파트 소품은 2D처럼 가장자리 어둠·홈 그늘·선이 보여야 함.
- Tripo 4면 판정 기준: 4장 모두 똑바른 정면 카메라·같은 높이·같은 방향(무기 손잡이 아래). 옆면이 앞면 복사거나 3/4 비스듬이면 다시.

## 끝난 판정
- 이미지 생성 1: 땅·길 3차 통과(5단계로: 계단 발치 흰 번짐, 계단 옆 바위면, 턱 → 옹벽). 턱 = 높이 4 넘는 곳만 Limestone. 집·가게 골격 16채 자리 통과(`art/review/world/halo_v2/houses/sheet_houses.jpg`). h_05 검은 땅 = 겉 잔디 1칸 밑 Rock 비침 → 2칸(897d329) 통과.
- 이미지 개발: 매끈 크림 대리석 3판 통과(WorldKit MV `HH_HaloMarbleSmooth_Cream`), HH_Fabric v2 WorldKit 적용 통과. 기록: 천 v2 배너가 멀리서 모눈처럼 보임 → 나중 v3 후보(낮은 우선).
- 이미지 생성 2: 키트 4면 1~3차 통과분 → Tripo 묶음 1·2(이미지 생성 4). Planter_E 왼쪽 = 오른쪽 좌우 뒤집기. 무기 High 앞면 28장 통과. 무기 4면: 전사 7(+돌린 앞면 5)·궁수 6 통과, 마법사 LightMage T2·T3·DarkMage T3 통과.
- 이미지 생성 4: 파트 소품 Studio 시트 5장 — 통과 다수, 다시 = 칠한 흰 나무 회색 결(벌통·게시판·무기고·양초 상자), 장작, 방패 걸이(바퀴처럼), 솥(순검정·물약), 벽등 뒤.

## 기다리는 것
- 이미지 생성 2: 가방 아이콘 High 11(Petal m1·CaptainBadge m1·SeaShell m1·CrystalShard m1·MeadowHerb m1·CopperOre m1·OakLog m1·IronOre m1·SilverOre m1·MoonCrystal m2·CrownDust m1) + Glowcap 새 후보 2(1UP 버섯 닮음 피하기) → 잘라내기 시트. 망치질 CraftRing·CraftTarget·CraftIngot(후보 → High 15). 마법사 옆면 6장 다시(LightMage T1·DarkMage T1·T2 left/right, 30). 중립 무기 27장. 새 집 7채 21장. 게임 아이콘 Medium 후보.
- 업로드 승인 요청(최종 검수): 아이콘 12 + 망치질 3 = 15개(잘라내기 시트 확인 뒤).
- 이미지 생성 4: 다시 한 소품 줄 사진 + 밋밋함 비교 시트(2D|A|B 메인 C2c 빛|C Blender 곡률·AO SurfaceAppearance|D1 Highlight|D2 뒤집힌 껍데기). C·D2 올리기 약 9개 승인 여부는 최종 검수.
- 이미지 생성 3: Tripo HD 장식 Blender 손보기(A23-125 세 단계·12항목).
