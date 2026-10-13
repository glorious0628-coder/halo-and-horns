# 디자인 검수 도구 (10/13)

Tripo 흰 모델·텍스처·PBR 판정용. 창(앱 브라우저)이 숨겨져 Tripo 화면이 안 그려질 때도 씀. 점수 쓰는 버튼은 누르지 않음(보기만).

1. 후보 id 묶음 JSON(`{"이름":[id,…]}`) → `py tools/design_review/mkbatch.py <out_dir> <tabId> <groups.json>` → `bb_0.json …`(앱 브라우저 browser_batch용, 내 탭에서 각 모델 페이지의 store `model_url`을 모으고 마지막에 `날짜 uuid 만료 서명` 줄을 ` ;; `로 이어 돌려줌). Blender 손보기의 `seed` 탭은 쓰지 않음(tabs_create로 내 탭).
2. 그 결과를 텍스트 파일로 → `py tools/design_review/rawlines.py <out_dir> <groups.json> <raw.txt> <lines.txt>` → `py tools/design_review/tripo_dl.py <lines.txt> <dl_dir>` (서명된 URL을 다시 만들어 FBX 받기, 우리 Tripo 결과 내려받기는 사용자 상시 OK).
3. 흰 모델: `blender --background --factory-startup --python tools/design_review/clay_views.py -- <out> <fbx…>` (앞 = +X, 7면 점토: 앞·45·옆·뒤·옆·위·아래 3/4, 뒷면 안 그림 → 구멍이 비쳐 보임) → `py tools/design_review/sheets.py <dir> <render_dir> <prefix> <이름…>`.
4. 텍스처 색: `tex_views.py -- <out> <px> <fbx…>` (평평한 빛 = 색 맵 그대로).
5. PBR: `pbr_maps.py`(맵 추출·크기) + `pbr_look.py`(EEVEE 해 + 하늘, PBR 그대로 vs 색만).
6. **PBR 관문(A23-154, PBR 끝난 모델 = 디자인 검수 → 최종 검수):** `blender … --python tools/design_review/pbr_gate.py -- <out> 700 2048 <file.glb|fbx>[:front] …` (해+하늘 빛, 해는 카메라 따라감; 앞·fr(앞이 화면 오른쪽 = 2D `_left`)·뒤·fl(= 2D `_right`)·위 3/4, 네 면 같은 배율 + 2048 앞면) → `py tools/design_review/pbr_gate_sheet.py <out> <sheet_dir> <렌더이름>=<2D 앞 경로에서 _front_ns.png 뺀 것> …` (1줄 2D 4면, 2줄 렌더, 3줄 디테일 많은 곳 100% 크롭 3개). 색 비교 힌트: `color_compare.py <2D 앞> <렌더>`. GLB(build_glb.py) 앞 = -y, Tripo FBX 앞 = +x.
7. **많을 때(10/13, 80개):** 페이지마다 이동하지 말고 내 탭(Tripo 로그인 상태)에서 `fetch('https://api.tripo3d.ai/v2/studio/assets/v2?asset_type=mine&locale=ko&offset=<0,40,…>&size=40&type=all',{credentials:'include'})` → `data.projects[].id`(앞 8자리로 찾기)·`model_url` → `id8 날짜 uuid 파일 만료 서명` 줄로 바꿔 localStorage에 두고 27줄씩 읽어 파일로 → 이름 붙여 `tripo_dl.py`. 끝나면 내가 넣은 localStorage 키 지우고 탭 닫기. (페이지 → localhost 전송은 앱 브라우저가 막음.)

8. **흰 모델 모든 면(사용자 10/13: 위·아래·앞·뒤·양옆 다 볼 것):** `blender --background --factory-startup --python tools/design_review/wm_six.py -- <out_dir> <sheet.jpg> <fbx…>` → 한 장 시트(줄 = 후보, 칸 = 앞·옆·뒤·옆·**바로 위**·**바로 아래**·3/4, 뒷면도 그려 구멍·비침이 보임). 고른 이유에 '위·아래 확인함'을 적음. 덤불·잎은 같은 시트에서 비침도 봄. (Bal_C 531c8172: 옆은 ㄱ, 위는 닫힌 세모였음.)
