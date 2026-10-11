# 이미지 생성 4 — 상태 (2026-10-12 00:30)

## 지금 상태 한 줄
**10/12 01시: 기본 B 적용(58종 모든 파트 그림자, 마을 다시 배치). C·C+ 버림. ★ 선 비교(B | 얇게 0.035 | 굵게 0.06, EditableMesh 임시 = 안 올림) `art/review/img4/star_1012_sheet.jpg` → 디자인 검수 → 최종 검수 → 사용자 고름. '다시' 6개 Studio 사진 `studio_redo_1012.jpg` 디자인 검수 판정 기다림. 사용자가 선을 고르면 그 굵기 4개(build/prop_kit_hull/<Kit>_D2_<035|060>.obj)만 이미지 개발에 넘김.**

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
- 방법: scratchpad `tripo_srv.py`(8766)·`tripo_dl.py`(8767) — 세션 끝나면 사라짐. 단계는 메모리 tripo-web-in-app-browser + 위 묶음 기록.

## 다음
1. 디자인 검수 답 → 최종 검수 올리기 승인 → 이미지 개발 올림 → `prop_compare_shots.py --cols C,D2 --assets` (화면 슬롯) + 다시 찍을 칸 + 다시 6개 Studio 사진.
2. Tripo 모델 Blender 손보기(등불 머리 갈빗대·고리 정확히, 대칭, 조각 제거, C/N/R/M, records.json) → 이미지 개발 올리기.
3. 재질별 CSG 합치기로 파트 수 줄이기(등불 56 ≈ 4천 파트, Woodpile 146).
4. 약한 곳: Lavender 항아리 달걀형, Planter_E 옆 그림자 줄.
