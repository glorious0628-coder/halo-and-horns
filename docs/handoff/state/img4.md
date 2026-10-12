# 이미지 생성 4 — 상태 (2026-10-12 저녁)

## ★ 10/12 A23-149 골격 먼저 — BakerGranny 시험 (ddb6ca1, 최종 검수 답 기다림)
- `tools/npc_block_body.py` (Blender): R15 15부품 블록 몸 + 팔레트 단색 입히기 + Tripo 원본에서 모자·머리·리본 잘라 쓰기 + 정확한 후광, 얼굴 비움. 출력 `art/models/npc_block/BakerGranny/` (glb, palette, rig.json = Roblox 좌표 관절 15개). 시트 `art/review/img4/npc_block_BakerGranny_1012.jpg`.
- 남은 흠: 리본 끈 옆으로 삐짐, 모자 아래 금띠 조각. 다음 = OK 받으면 WorldKit Import(화면 슬롯) → Humanoid R15 + Motor6D 스크립트 → 기본 걷기 1회.
- 바깥선(A23-148): WorldKit 껍데기 6개 ServerStorage.Parked_Outlines로 치움(삭제 X).

## ★ 10/12 저녁 전환 — SPEC A23-147 (사용자: Blender판이 원본을 망침 → 전부 Tripo 원본에서 새로)
- **Blender 손보기는 이제 'Blender 손보기' 세션(local_fa73201d…, role 15_blender.md) 담당.** 이미지 생성 4 = Tripo 생성 + 통과한 GLB를 Roblox(WorldKit)에 넣기(Import·재질·바깥선 껍데기·낮밤 사진). 보고 = 최종 검수.
- 규칙(A23-147): 고장 없는 모델은 크기·방향·쥐는 점·꼭 필요한 대칭만, **메시·색 맵 그대로**(de-light·다시 굽기·면 줄이기·2D 얼굴 데칼 없음). 얼굴 = Tripo 디자인 그대로 번진 곳만 깨끗하게(Blender 세션).
- **내 Blender판(art/models/tripo/touchup/*, art/models/tripo/weapons/*)은 폐기 대상** — WorldKit에 들어간 적 없음(Tripo 손보기 GLB는 아직 Roblox에 안 올림). 원본만 쓸 것.

### Tripo 원본 GLB (전부 art/models/tripo/web/, 기록 art/models/tripo/records.json 키 <이름>_web_hd_mv4 / NPC 5명은 _web_hd)
- 4면 HD (_MV4_HD_src.glb) 82개: 소품 40(Halo 화분·나무·등불·가판대·벤치 B·허수아비·덤불·흰 바위 등, 목록 tools/tripo_touchup_halo.sh), 무기 28(Weapon_*), NPC PotionMerchant, 밈 4(Meme_PixelHalo·PixelHorns·DonutHalo·TwistHorns), 주민 9(NPC_HaloBellElder·FlowerFarmer·Folk4·HerbHusband·HerbWife·MailBoy·OldSailor·PondAngler·StarScholar — 10/12 오후 생성 끝, 495점, 잔액 13,865→13,370).
- 10/10 NPC 5명(이미지 생성 1): NPC_Halo{Bright,SirGleam,BakerGranny,FlowerGirl,JuiceMan}_HD_src.glb (4면 HD, 디자인 검수가 그대로 쓰기로 판정).
- Tripo 앞 = +X(Blender). 2D 옆 이름은 보는 사람 기준 → Tripo 왼쪽 칸 = 2D *_right (소품·NPC·밈), 무기는 무기 자신 기준.
- PixelHalo는 Tripo가 납작한 막대로 만듦(옆 4면뿐) → 내가 tools/meme_voxel.py로 2D 색 블록 고리를 새로 짠 판(art/models/tripo/touchup/Meme_PixelHalo)이 최종 검수 통과; PixelHorns도 2D 블록판 통과. 새 규칙에서 쓸지 최종 검수 판단.

### 지팡이 9개 (A23-142, 개발 1 68bef0e7) — 원본 색 그대로, 길이·쥐는 점만
길이(구슬·장식 꼭대기까지) T1 3.38 / T2 3.64 / T3 3.90칸(0.65/0.70/0.75 × H5.2). 손 = 감은 곳 가운데 = 발끝에서 43% = 피벗(긴 축 +Y, 앞 -Z). 원본에서 감은 곳 위치(높이 비율, 원본 Tripo 메시 기준): LightMage T1 0.365–0.515, T2 0.385–0.61, T3 0.235–0.455 / DarkMage T1 0.295–0.515, T2 0.42–0.675, T3 0.265–0.495 / Alchemist T1 0.245–0.495, T2 0.235–0.455, T3 0.135–0.385. 감은 곳을 43%로 옮긴 방법·결과는 tools/tripo_weapon_touchup.py MOVE·move_wrap(통과했던 판) — 새 규칙에선 "옮김"이 메시 수정이라 Blender 세션·최종 검수 판단. 표: docs/design/weapon_grip_heights_2026-10-12.md 맨 아래.
- 다른 무기 손 = 2D 감은 손잡이 가운데(WRAP 표, 같은 문서).

### WorldKit (STUDIO_ID 535fc5fe 기준, 최종 검수가 알려 줌)
- ServerStorage.HaloPropKits = 파트 키트 58개(prop_kit.py, Tripo 아님) — 겹친 면 고친 판(백업 build/wk_backup/20261012_092142). HaloV2.Props는 이미지 생성 1이 halo_props_place로 놓음.
- 바깥선 껍데기: 56개 중 50개 ID(art/models/worldkit/prop_hull_assets.json, 이미지 개발), 묶음 6(6개) 사용자 Import 대기. 놓기 = 키트 피벗 × CFrame.new(centre) × CFrame.Angles(0, π, 0). 껍데기는 **파트 키트 모양** 기준이라 Tripo 판과 무관; '(가+나)' 몸통 키트 위에 얹는 Tripo 식물·머리는 새 판이 오면 위치 맞는지만 확인.
- Tripo 손보기 GLB는 WorldKit에 아직 하나도 안 넣음.

## 지금 상태 (10/12 오후)
- **보고 길 바뀜(10/12 오후, 사용자 결정):** 디자인 검수 쉼 → 시트·판정 요청은 전부 **최종 검수**로(규칙·대기 목록 docs/handoff/state/design_review.md).
- **밈 후광·뿔 4개**: Tripo 220점(잔액 13,920), 손보기 tools/meme_voxel.py(PixelHalo = 2D 색 블록 고리, PixelHorns = 2D 블록 하나씩) + tripo_touchup(Donut·Twist 거울+de-light), 시트 meme_touchup_1012.jpg → 최종 검수 판정 대기.
- **de-light**(tools/proj_bake.py delight): NPC·무기 끝, 소품 39 굽는 중.
- **바깥선 껍데기 56개**: 첫 묶음 10 통과(C2c 사진 art/review/img4/outline_hull1_fix_c2c_1012.jpg). 2~6묶음 최종 검수 승인 — 길: 이미지 개발이 build/hull_import 준비 → 나는 최종 검수에 "묶음 N 가져오기 준비됨 + 폴더" → 사용자 Import 3D → 이미지 개발이 ID 읽음(art/models/worldkit/prop_hull_assets.json). 묶음 목록 = docs/design/halo_prop_outlines_2026-10-12.md '묶음' 열. 묶음 2 ID 받음, 묶음 3 이미지 개발 준비 중. **놓기 = 키트 피벗 × CFrame.new(centre) × CFrame.Angles(0, π, 0)** (Import 3D가 OBJ를 세로축 180° 돌림). 다음 사진 비교 자리는 새 평지로(옛 자리 -24,0.2,-440은 지형 바뀌어 15칸이 언덕에 가림).
- **키트 겹친 면**: tools/prop_kit_coplanar.py + prop_kit.py defight() → 58키트 0. WorldKit HaloPropKits 다시 넣음(백업 build/wk_backup/20261012_092142), HaloV2.Props는 이미지 생성 1이 다시 놓음 — 키트 바꾸면 halo_props_place 직접 돌려도 됨(STUDIO_ID 83b32720).
- **무기 28개**: tools/tripo_weapon_touchup.py. 지팡이 9개 = SPEC A23-142 확정판(개발 1 68bef0e7): 길이 0.65/0.70/0.75H, 손 = 감은 곳 가운데 43% = 피벗, 감은 곳 통째 옮김(빈 자리는 막대 복사, 내려갈 땐 위쪽 막대). 표 docs/design/weapon_grip_heights_2026-10-12.md 맨 아래, 시트 staff_a23_142_1012.jpg(tools/staff_sheet.py). 디자인 검수 통과(Alchemist T1 매단 병 그대로). 다음 = 3단계 Roblox 재질(밝은 강철·짙은 청록·용암 Neon), 메인 반영 1 사진에서 같이.
- **Tripo 소품 39개**: 바깥선(식물은 굵은 voxel = 덩어리만) + 용접 + keep-green + Lantern A 머리(--head-from)·C/D(--head-footprint)·PotFlowers_F 덩굴. 시트 tripo_tu_organic_1/2·goods·heads_1012.jpg. 식물 잎 어두움 = 3단계(C2c 낮)에서 색 맵 밝기.
- **NPC 6명**: 5명은 10/10 Tripo 그대로(디자인 검수), PotionMerchant 새로(55점, 잔액 14,170). tools/tripo_touchup_npc.sh(후광 정확한 고리 0.38, Bright/SirGleam 아래 대칭, 머리 UV ×2.2) → 시트 npc_touchup_1012.jpg(tools/npc_sheet.py --prev build/npc_prev, 렌더 tools/glb_preview4.py — Blender 경로는 절대경로로!). 디자인 검수 판정 기다림.

## 배운 것 (10/12)
- 실제 땅 C2c 빛에서 어두운 회색(Metal·SmoothPlastic)은 하늘빛을 받아 남색으로 보임 → 숯 회색은 거친 Slate + 따뜻한 회색(110,100,92).
- Neon은 하얗게 번짐 → 물약 같은 빛나는 면은 한 단계 진한 색(60,196,170)으로.
- 최종 검수 10/12: 짧은 확인 사진도 규칙 6대로 매번 최종 검수에 짧게 신청(잠깐 준 '묻지 말고' 허락은 취소됨 — 다른 세션의 WorldKit 사용을 알 수 없음).
- Blender 미리보기 해 그림자가 통나무 옆면을 꼬인 띠로 보이게 함 → 판정은 Studio 사진으로.

## 비교 시험 (사용자 "그림자가 없어서 이상한 건가, 뭔가 선이 없어 보여")
- 시트: `art/review/img4/compare_1011_sheet.jpg` (사진 64장 `art/review/img4/compare_1011/`, 디스크만). 소품 4 = BenchA·Lantern_A·Beehive·Planter_D__Body.
- 도구: `tools/prop_compare_shots.py`(WorldKit 사진, 화면 허락 뒤; `--dry`는 화면 없이 배치 확인; `--cols C,D2 --assets assets.json`은 올린 뒤), `tools/prop_compare_sheet.py`, `tools/prop_kit_bake.py`(C 색 굽기 `--tag C|Cs`, D2 껍데기 `--hull`, `--preview`), 공통 빌더 `tools/prop_kit_bl.py`. 결과물 `build/prop_kit_bake/` (OBJ = Roblox 축, `<키>_<tag>_bake.json`에 메시 중심 = 키트 피벗 기준).
- 내 추천: 기본 B(모든 파트 CastShadow), 다음 D2 + C+를 Studio에서 확인 — 올리기 8개 제안(D2 4 + C+ BenchA·Beehive 메시·맵). B2(Diffuse 0.3) 이득 없음. D1은 31개 한도.
- 다시 찍을 칸: Lantern_A B 밤5, Planter B 낮5 등(카메라 이동 중 첫 장) → 도구에 버리는 첫 장 넣음.
- 자리: 스폰 근처 돌길+잔디 (-24, 0.2, -440), 키트 yaw 25도(낮 해가 앞면을 비스듬히).

## 디자인 검수 "다시" 6개 (10/12 0시 적용, b73ac2c)
- 칠한 흰 나무 → `pcream`(SmoothPlastic 242,233,214) + `seam()` 판 줄(`groove` 212,198,176): Beehive·NoticeBoard·ArmoryBarrels(통널 8줄·상자)·CandleCrate. Easel·Telescope 등 통과한 키트의 `woodcream`은 그대로.
- Woodpile 주황 통나무 + 나이테 고리, 나무 바닥 + 대리석 발, 파란 박공(쐐기 2개, 지붕 채움 밖 W/2+0.14).
- RackShieldSword 방패: `stripes_disc` 축 버그 고침(기울인 면에서 Y가 법선과 직교 안 됨).
- Cauldron `ironblue`(60,64,78 Metal 반사 0.08), 물약 면 금 테 위.
- WallLamp 받침 `chamfer_slab()` 긴 팔각 대리석 + 금 테(안쪽 팔각 자르개) + 파란 띠.
- Clothesline 수건 2D대로 4개, 바구니 1개, 줄 황갈색. Lantern A 머리 비율은 Tripo 머리 올 때.
- WorldKit: `py tools/prop_kit.py <9키> --apply` → `py tools/worldkit/halo_props_place.py --mode apply`(Real 103) → `wk_backup.py save --only ServerStorage.HaloPropKits` (20261012_001756).

## Tripo
- 묶음 1: 26개 1,430점(records `<키>_web_hd_mv4`). 묶음 2: 14개 770점(종만·벽등 머리·물뿌리개·화분꽃 A/C/D/E/F·화단 D·흰 바위 a/b/c·빵바구니·생울타리), 잔액 15,765, 원본 시트 `art/review/img4/tripo_b2_raw.jpg`. 파일 `art/models/tripo/web/<키>_HD_src.glb`. Tripo GLB 앞 = Blender +x(tools/compare_3d_render.py 주석).
- 남은 것: Planter_A·Planter_E·Balustrade_F 덤불 — 이미지 생성 2 2D 끝(kits_mv3), 디자인 검수 통과 확인 + 최종 검수 승인 뒤.
- **파일 이름(10/12):** 4면 결과 = `art/models/tripo/web/<키>_MV4_HD_src.glb` (40개). 처음 받을 때 `<키>_HD_src.glb`로 저장해 옛 단일면 결과 29개를 덮어씀 → git에 있던 12개는 HEAD에서, 없던 17개는 Tripo 계정(옛 task)에서 다시 받아 되살림. 앞으로 내려받기 이름에 꼭 `_MV4` 같은 꼬리.
- 방법: scratchpad `tripo_srv.py`(8766)·`tripo_dl.py`(8767) — 세션 끝나면 사라짐. 단계는 메모리 tripo-web-in-app-browser + 위 묶음 기록.

## 다음
1. 디자인 검수 답 → 최종 검수 올리기 승인 → 이미지 개발 올림 → `prop_compare_shots.py --cols C,D2 --assets` (화면 슬롯) + 다시 찍을 칸 + 다시 6개 Studio 사진.
2. Tripo 모델 Blender 손보기(등불 머리 갈빗대·고리 정확히, 대칭, 조각 제거, C/N/R/M, records.json) → 이미지 개발 올리기.
3. 재질별 CSG 합치기로 파트 수 줄이기(등불 56 ≈ 4천 파트, Woodpile 146).
4. 약한 곳: Lavender 항아리 달걀형, Planter_E 옆 그림자 줄.
