# 이미지 생성 4 — 상태 (2026-10-12 08:30)

## 지금 상태 (10/12 아침)
- **바깥선 껍데기(A23-139, 0.035 안뒤집기 껍데기) 56개**: `build/prop_kit_hull035/<키>_D2_035.obj/.json`, 표 `docs/design/halo_prop_outlines_2026-10-12.md`, 시트 `art/review/img4/outline_hulls_fix_1012.jpg` → 디자인 검수 **통과**. 첫 묶음 10 = 이미지 개발이 올리는 중(최종 검수 승인) → ID 오면 실제 땅 C2c 낮 5·15칸 사진(화면 슬롯은 최종 검수에 신청; WorldKit은 이미지 생성 1이 되살린 뒤).
- 바닥 검은 덩어리 원인 = 키트 부품 두 면이 같은 평면에 겹침 → `tools/prop_kit_coplanar.py`(검사) + `prop_kit.py` `defight()`(작은 부품 면 0.012칸 밀기, 3번까지 반복). 58키트 887면 → 0. **WorldKit HaloPropKits는 아직 옛 키트** → 되살아난 뒤 `py tools/prop_kit.py --all --apply` + halo_props_place + wk_backup (화면 신청).
- 껍데기 바닥 규칙: 맨 아래 아래쪽 면 빼고 바닥 아래 0.01까지만(prop_kit_bake.py `make_hull`, tripo_touchup.py 바깥선 같은 규칙).
- Tripo 소품 39개 손보기 + 바깥선(--outline 0.035) 다시 돌리는 중 → `py tools/tripo_touchup_sheet.py <out> <키…>` 시트 → 디자인 검수.
- **무기 28개 Blender 손보기** (디자인 검수 2단계 통과): `tools/tripo_weapon_touchup.py`(길이 = 개발 1 LEN/tierLen, 피벗 = 손 = 2D 감은 손잡이 가운데 `WRAP` 표, 칼은 날만 y 두께 ≥0.2, `--sym` Paladin T2/T3·LightMage T3·Alchemist T2/T3, 3,500 삼각형, C/N/R/M 1024, `--preview-only`로 렌더만) → `art/models/tripo/weapons/<키>/`(디스크만, 206MB), 시트 `tools/tripo_weapon_sheet.py` → `art/review/img4/weapons_tu_<진영>_1012.jpg`. 쥐는 높이 표 `docs/design/weapon_grip_heights_2026-10-12.md`(감은 곳 아래끝·가운데·위끝 — 개발 1이 고름, 바뀌면 WRAP만 고쳐 다시 굽기). 다음 = 3단계 Roblox 재질(Berserker T3·Paladin T3 밝은 강철, PetTamer T3 짙은 청록, 최종 b 용암 Neon 살짝) 낮·밤 사진.
- **구멍 버그(10/12 고침)**: glTF 가져오기가 UV 이음매에서 점을 나눠서, 점 합치기 전에 '작은 조각'을 지우면 진짜 면이 지워져 구멍. 두 도구 모두 용접 먼저. 검사 `tools/glb_hole_check.py`(투명 필름 실루엣, 밖에서 못 닿는 빈칸 = 구멍; 활시위·고리 같은 원래 틈은 Tripo 원본과 비교).
- Tripo 소품 39개 다시 굽기 끝(바깥선 + 용접 + 생울타리 ontop 높이 = 화단 테두리), 시트 `art/review/img4/tripo_tu_outline_[1-4]_1012.jpg`, records.json blender_touchup 기록. 남은 눈 확인: PotFlowers_F 늘어진 덩굴이 2D보다 적고 받침 근처 잎 조각.
- 껍데기 json 중심값: bound_box 캐시가 늦어 0.018 낮았음 → OBJ에서 다시 계산(56개). 첫 묶음 10 ID = `art/models/worldkit/prop_hull_assets.json`(이미지 개발).
- WorldKit 백업: build/wk_backup/20261012_013528 (HaloPropKits, 가마솥 Slate 포함, 겹친 면 밀기 전).
- 남은 것: records.json 손보기 기록(touchup 이벤트), Rose 화분 몸통이 2D보다 좁음, CSG 합치기로 파트 수 줄이기.

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
