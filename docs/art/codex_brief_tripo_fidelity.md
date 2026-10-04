# Codex 작업 지시서 — HaloArcherM 3D 재제작 R2 (승인 2D와 똑같이)

지난 라운드에 95 크레딧을 썼다. 레시피를 어겼고(`pbr:true`), Tripo 썸네일만 보고 끝냈다. 이번에는 **숫자로 증명**한다.
- 시작 조건: 지금 하던 다른 작업(얼굴 감사 `tools/face_runtime_*.py`·`docs/art/verification_2026-10-04/face_*`, 아바타 F/E 시안, `approved.json`·`Config.luau`·`HUD.luau`·`studio_mcp.py` 수정)을 먼저 끝내고 커밋한다. 이번 작업에서 그 파일을 고치지 않고 커밋에도 섞지 않는다.
- 기준 그림은 하나다: `art/out/APose_HaloArcherM_Sharp_D.png` (1254², sha256 649ce86f…). 판정은 Tripo `preview.png`가 아니라 §3 측정으로만 한다.
- 멈추는 지점(순서 고정): **G2** 무료 B0H 시트 + 크레딧 총액 승인(모든 유료 호출 전) → **G1** 입력 뷰 승인 → **G3** 후보 선택. 사용자가 답하기 전에는 다음 단계로 가지 않는다.

## 1. 지난 결과(c22df695 → rig 96aa4858)가 틀린 이유 — 실측
1. **pbr:true는 레시피 위반이다.** README_KO §9.0-6, `HANDOFF_CODEX.md:182`, `tools/tripo_api.py`는 모두 `pbr:false`다. 그런데 CLI `--for toy`로 `pbr:true`를 보냈다.
   - 흰 부츠 발등 전체가 metallic≈1이라 크롬처럼 보인다. 부츠 앞코: preview (210,202,197), 원본 (248,240,238).
   - metallic>0.3 텍셀: 흰 천 15.1%, 피부 19.5%, 갈색 가죽 31.3%. 금색은 56.6%뿐이다. 흰 천 roughness 중앙값은 0.235다.
2. **검증 없이 보고했다.** 사용자 스크린샷은 rig `preview.png`와 바이트까지 같다(sha256 6c3d4eea…, 3/4 원근, PBR 조명).
   - 그 조명에서 금발 채도가 0.365 → 0.089로 떨어진다(흰머리처럼 보임). 정면 정사영, 옆, 뒤 렌더는 하나도 없었다.
3. **헤일로 별이 사라졌다.** 원본은 링 앞 중앙에 약 98px 높이로 똑바로 선 4각 별이다. 3D는 링에 붙은 약 40px 마름모이고, 링 앞쪽이 11.6° 들렸다.
   - 원인(추정): `face_limit 18000`이라 헤일로 위쪽에 약 310 tris뿐이다. 정면 한 장이라 깊이를 모른다. 입력 위 여백이 0이다(별 끝이 0행 x617–622, Tripo가 다시 자르는지는 모름).
4. **효과를 확인하지 않고 비싼 옵션을 썼다.** `geometry_quality detailed`(+20)와 `extreme`(+20, 8192 JPEG)를 썼다.
   - 8K는 R15 경로(`costume_r15/convert.py`, 다시 굽지 않음)에서 Roblox 1024로 줄어 이득이 없다. `fix_face.py` 머리 재굽기에서만 일부 이득이다.
   - 공짜인 것(pbr off, seed, 입력 여백, 후보 여러 개)은 다 건너뛰었다.
5. **재현할 수 없다.** seed 없이 후보 1개만 뽑았다.
6. **지어낸 부분이 있다.** 등에 큰 흰 리본 모양 요크가 생겼다. 손은 손가락이 붙었다. 팔뚝은 11% 굵다(56→62px). 브로치, 구슬, 버클이 뭉개졌다.
7. **기록이 엉망이다.** CLI가 PNG를 JPEG로 올렸다(task.json `file.type: jpeg`, 손실 압축). `records.json`에 c22df695/a532384f/96aa4858가 없다. plan은 `paid_submissions 0`, HANDOFF는 "승인 대기"다. 루트에 `--output`이 생겼다.
8. **유지할 점**: 정면 모양은 괜찮다(IoU 0.885, 머리/전체 0.356 vs 0.348). 리깅이 원인은 아니다(메시·텍스처 동일). 그래서 T1–T5는 R1도 통과한다. 개선 판정에는 못 쓰고 퇴보 방지용이다.

증거 이미지(Claude 측정): `docs/art/verification_2026-10-04/claude_fidelity_r1/`의 `gap_overview.jpg`, `pbr_metal_vs_nometal.jpg`, `pair_halo.jpg`, `approved_top_crop.jpg`
- `gap_overview.jpg`의 2번(albedo만)은 원본과 거의 같다. 사용자가 본 흰머리·크롬은 3번·5번(PBR 맵 + Tripo 미리보기 조명)이다. **텍스처 자체보다 PBR 맵이 범인**이다.

**눈 번짐의 숫자 원인 (최우선 과제와 연결)**
- 8192 base color 아틀라스에서 뜬 눈 폭은 약 320 텍셀이다.
- 몸 전체 아틀라스를 Roblox 한도 1024로 줄이면 눈 폭이 약 40 텍셀이 된다. 그래서 무조건 번진다(UV 섬 339개, 커버리지 58%).
- 해결: 얼굴은 몸 아틀라스에서 빼낸다. 머리 전용 1024 텍스처(`fix_face.py` 방식) 또는 원본 그림 얼굴을 쓴 얼굴 전용 판 텍스처를 쓴다.
- 합격 기준: Roblox에 올라가는 텍스처에서 뜬 눈 폭이 ≥200 텍셀이고, 그 값을 `metrics.json`에 기록한다.

## 2. 새 레시피 (모든 파라미터는 `docs/vendor/tripo_api/` 문서에서 확인함)
**호출 규칙**
- 유료 호출은 `tools/tripo_api.py` REST로만 한다. CLI(`tripo make/redo`, `--for` 프리셋)는 쓰지 않는다. 프리셋은 pbr:true이고, 모델을 안 적고 face≤20000이면 P1이 된다.
- 없는 기능(image-to-multiview, multiview-to-model, models/texture)은 이 도구에 추가한다.
- 모든 유료 POST는 `retries=0`이다(기본 `call()`은 429/5xx에서 5회 재시도). 시간 초과나 결과를 모르면 다시 보내지 않고, `GET /tasks/{id}`와 잔액을 조회해 `unknown`으로 기록한다.
- 그림은 `upload()`로 PNG 그대로 올리고 task.json 입력 `file.type`이 png인지 확인한다. 매 호출 전 `--dry` payload를 `payload.json`으로 저장한다. 장부는 `record()`로만, 제출 직후와 완료 후 두 번 쓴다.

**Step 0 (무료) 기준선 B0와 헤일로 교체 H**
- B0: c22df695 GLB에서 metallicRoughness 텍스처를 빼고 `metallicFactor 0`, `roughnessFactor 0.8`로 바꾼다(기존 fixed 코스튬과 같은 값). `r2/B0/model.glb`로 저장한다.
- H(헤일로 교체): 생성된 링·별 면을 지운다(아호게는 남김). Blender로 원본 측정대로 다시 만든다. 무료이고 모든 후보에 `+H` 변형으로 적용한다.
  - 수평 링(정면 폭 원본 x462–776 비율, 두께 원본 측정, 기울기 0°) + 링 앞 중앙에 똑바로 선 4각 별(높이·폭·솟음 원본 측정값).
  - 별도 객체 `Halo`, ≤1,000 tris. 색은 원본 금색 영역 평균에서 샘플한다(새 색·장식 금지).
- B0H(= B0 + H)를 렌더한 시트(원본 | 정면 flat | 정면 lit | 3/4 lit | 옆 | 뒤)를 G2에서 보여 준다.

**G2 (첫 유료 호출 전)**: `GET /v3/account/balance` 결과, B0H 시트, 아래 총액을 한국어로 짧게 보여 주고 묻는다. "B0H로 충분"이면 유료 0으로 Step 4로 간다. 승인 문구는 새 `docs/art/tripo_sharp_d_r2_plan_2026-10-04.json`에 쓴다.

**Step 1 입력 → G1**
- 정면: 원본을 리샘플 없이 흰 1380² 캔버스의 (x+63, y+100)에 붙여 `art/out/APose_HaloArcherM_Sharp_D_pad.png`로 저장한다. 디자인은 바꾸지 않는다.
- 1b(필수, 10cr): 패딩 정면으로 `POST /v3/generation/image-to-multiview` 1회. 감은 눈(캐릭터 오른쪽 눈)이 `left_view`와 `right_view` 중 어디 나오는지로 좌우 규칙을 정해 `r2/inputs/align_check.json`에 쓴다. 판정할 수 없으면 C1은 취소한다.
- 옆·뒤: **패딩 정면을 참조로** GPT 이미지 생성으로 left, right, back 3장을 만든다.
  - 정면과 **같은 렌더 스타일, 같은 부드러운 조명**으로 그린다. 문서상 멀티뷰 입력은 조명이 같아야 한다. 평면 조명은 금지다.
  - 같은 캔버스, 같은 T-포즈, 정확히 90° 옆과 뒤, 흰 배경, 뒷면엔 얼굴 없음. 모든 뷰에 수평 링과 똑바로 선 4각 금별, 색·재질은 정면과 같다.
  - 노출 없음(얼굴과 손만, 다리는 갈색 레깅스). 윙크는 캐릭터 오른쪽 눈이라 오른쪽 옆모습은 감은 눈, 왼쪽 옆모습은 뜬 눈이다.
- 정렬: 옆·뒤는 PIL 배율·이동으로 맞춰도 된다(정면은 리샘플 금지). 기준은 발바닥 행 ±4px, 헤일로 꼭대기 행 ±8px, 높이 ±2%다. 모양이 틀린 뷰만 다시 그린다(최대 3회).
- 1c(선택): `edit-multiview` 5cr/장, 최대 4장.
- **G1**: 실제로 넣을 모든 그림(GPT 뷰, Tripo 뷰)을 직접 보고 노출을 검사한다. 사용자에게 한 장씩 보여 주고, 승인 문구와 파일 sha256을 `approvals.json`에 쓴다. 승인 안 된 그림은 넣지 않는다.

**Step 2 (유료) 모양 후보 3개**: 각 60cr = 30 + HD 텍스처 10 + HD geometry 20. 공통 파라미터:
```json
{"model":"v3.1-20260211","texture":true,"pbr":false,"texture_version":"v3.5-20260815",
 "texture_quality":"detailed","texture_alignment":"original_image","delight":false,
 "geometry_quality":"detailed","face_limit":25000,"model_seed":<고정·기록>,"texture_seed":<고정·기록>}
```
- C1: `multiview-to-model`, `[{"front":F},{"left":L},{"back":B},{"right":R}]`(1b 규칙대로)
- C2: `multiview-to-model`, front+back만, C1과 다른 seed
- C3: `image-to-model`, 패딩 정면만(대조군)
- 보내지 않는 키: `enable_image_autofix`, `orientation`, `auto_size`, `export_orientation`, `compress`(README §9.0-8)
- 금지: `pbr:true`, `extreme`, `smart_low_poly`, `quad`, `generate_parts`, `/mesh/decimate`, P1/P2(P1은 ≤20k 저폴리라 세부가 줄고, P2는 110cr 이상)
- detailed geometry를 쓰는 이유는 얇은 별과 손 보존이다. C1–C3 결과로 효과를 기록한다.
- face_limit 25000이어도 된다. Roblox 한도는 **메시마다** 20k이고, 리깅 경로에서는 `convert.py`가 15부위로 나눈다(T11).

**Step 3 (유료·선택) 재텍스처**: G3 뒤 사용자가 허락할 때만 한다. `POST /v3/models/texture`, 20cr × 최대 2회.
- 파라미터: `model v3.5-20260815`, `texture_quality detailed`, `pbr:false`, `texture_alignment original_image`, `delight` true/false A/B, `texture_seed` 기록
- 참조 그림: `texture_prompt`에 `{"image":F}` 또는 `{"images":[F,L,B,R]}`(정확히 4장)

**Step 4 리깅**: G3에서 고른 1개만 한다.
- 순서: `rig-check`(0) → `rig`(25, `v1.0-20240301`, biped, mixamo, glb) 1회.
- 입력: 생성 task_id를 쓴다(문서상 task_id 입력은 생성 task만). 재텍스처했으면 그 GLB를 file_token으로 넣는다. B0H를 고르면 기존 rig 96aa4858을 다시 쓴다(0cr).
- 로컬 수정(H, metallic 0)은 리깅 **뒤에** 적용한다. 남은 면의 웨이트는 유지하고 `Halo` 정점은 `mixamorig:Head` 1.0이다. 리깅된 GLB에 `fix_face.py`는 쓰지 않는다(`tools/costume_r15/README.md`). `convert.py --dry`로 T11을 확인한다.

| 단계 | 1b 필수 | 1c 선택 | 2 (후보 3) | 3 재텍스처 | 4 rig | **기본 / 최대** |
|---|---|---|---|---|---|---|
| 한도(cr) | 10 | ≤20 | 180 | ≤40 | 25 | **215 / 275** ($2.15 / $2.75) |
- 단계별 한도를 넘지 않는다. **실패해도 자동 유료 재시도는 0회다.** 멈추고 보고한다(실패 task는 환불).

## 3. 자동 합격 기준 (`tools/fidelity_check.py` + Blender 렌더 스크립트)
**렌더**
- Blender: `%LOCALAPPDATA%\Programs\blender-5.2.2-windows-x64\blender.exe --background --factory-startup`. 권한 오류가 나면 `C:/Users/glori/AppData/Local/Temp/claude/blender-run/blender.exe`를 쓴다.
- glTF import → Workbench(`TEXTURE`, `FLAT`, `Standard`), 흰 배경, 정사영, 1254². 정면은 yaw 0/90/180/270 중 IoU가 가장 높은 쪽이다(R1은 +X).
- 추가: 옆 ±90, 뒤, 3/4(yaw+30) flat. EEVEE lit 정면·3/4(`5.2/datafiles/studiolights/world/studio.exr`, strength 1, GLB 재질 그대로).

**정렬과 측정 규칙**
- 배율은 R1과 같게 아호게 끝(y71)–발바닥(y1203) 높이로 맞추고, 발바닥 행과 몸 중심 x로 이동한다. 손끝 폭은 측정만 한다.
- 원본 마스크는 Σ|RGB−255| > 30이다. **원본도 같은 함수로 재서 기준값으로 쓴다.** 아래 숫자는 참고값이다.
- `regions_on_source.png`에 영역을 표시한다: hair, skin, sleeve, boot toe, leggings, gold, 뜬 눈(±20px 탐색), halo. 아호게·턱은 `landmarks_<후보>.png`에 표시한다.
- 금색 마스크는 HSV H 25–50°, S≥0.5, V≥0.5다(금발 S≈0.3과 구분됨).

| # | 항목 (★=필수) | 원본(참고) | 합격 |
|---|---|---|---|
| T1★ | 정면 flat 실루엣 IoU | (R1 0.885) | ≥0.87 (퇴보 방지) |
| T2 | 머리/전체 높이 | 0.348 | ±0.015 (퇴보 방지) |
| T3 | 뜬 눈 높이/머리 높이 | 0.173 | ±0.015 (퇴보 방지) |
| T4 | 머리 폭/어깨 장식 폭 | 1.066 | ±0.04 (퇴보 방지) |
| T5 | 다리/전체 | 0.295 | ±0.015 (퇴보 방지) |
| T6★ | 정면 별: 별 축 ±12px 금색 최상단이 링 상단(축에서 80–150px 떨어진 열의 중앙값)보다 솟은 높이, 위에서 이어지는 금색 길이 | 같은 함수로 잰 원본값 | 둘 다 ≥ 원본의 0.65배 |
| T7★ | 옆 ortho: 링 기울기, 별 돌출 | 수평 | 기울기 ≤5°, 돌출 ≥ 전체 높이 1.5% |
| T8★ | 실효 metallic = metallicFactor(키 없으면 1.0) × MR B채널 | 금색 외 0 | 흰·크림·피부·갈색 텍셀 중 >0.1 비율 ≤1% |
| T9 | flat 정면 영역 평균 RGB | hair (241,197,153), skin (254,224,210), sleeve (246,240,239), boot (248,240,238), leggings (141,91,62) | 채널 ±15, hair 채도 0.30–0.43, boot 채도 ≤0.08 |
| T10 | EEVEE lit 정면 hair 채도 | 0.365 | ≥0.25 |
| T11★ | Roblox로 가는 메시마다 삼각형 수: 리깅은 `convert.py --dry` 15부위, 정적은 fix_face Head/Body | – | 각 ≤20,000 |
| T12 | 귀(yaw ±60 확대), 손, 뒤·옆 시트 | 둥근 사람 귀, 손가락 구분 | 이미지 저장(사람이 판정) |
| T13 | (C1·C2) 옆·뒤 flat 실루엣 vs G1 승인 뷰 IoU | – | ≥0.85 (뒷면 지어내기 방지) |
| T14 | 얼굴 크롭(x560–800, y300–480) 평균 \|ΔRGB\| | R1 값 | 순위용, R1보다 작을 것 |

- T8: 텍스처도 metallicFactor 키도 없으면 기본값 1.0이라 불합격이다. 그때는 `model_fixed.glb`(metallic 0, roughness 0.8)를 만들어 둘 다 보고한다.
- 모든 후보를 raw와 `+H`로 두 번 채점한다. `metrics.json`에는 값, 합격 여부, 정렬 배율·오프셋을 넣는다.
- 리깅 후 확인: 정점·UV가 입력과 같다. `Halo` 정점은 Head 100%다. 다시 T1–T11을 돌린다.

## 4. 후보 선택 (G3)
- B0, B0H, C1–C3(각 raw/+H)를 같은 스크립트로 채점한다 → `r2/eval/metrics.json`, `r2/eval/scoreboard.png`
- 순위: ★ 전부 통과 → T13 → 비★ 통과 개수 → T1.
- 시트(원본 | 정면 flat | 정면 lit | 3/4 lit | 옆 | 뒤)는 유료 상위 2개 + B0H(무료 기준)로 만든다. 사용자에게 **한 장씩** 보여 주고 사용자가 고른다. Codex가 대신 고르지 않는다. `preview.png`는 판정 자료가 아니다.
- (선택·무료) 원본 얼굴을 정면 카메라에서 우승 머리 텍스처에 투영한 변형 F를 `r2/` 안에서만 만들 수 있다. T14와 함께 보여 준다. 얼굴 감사 도구 파일은 고치지 않는다.

## 5. Claude 독립 검증용 납품물 (`art/models/costume/redraw/r2/`)
- `inputs/`: front_pad, left, right, back PNG, 1b 결과, `align_check.json`, `approvals.json`
- `<B0|C1|C2|C3>/`: `model.glb`(선택된 것만), (`model_fixed.glb`), `task.json`, `payload.json`, `preview.png`(참고용)
- 떨어진 후보와 B0의 GLB는 깃 제외 폴더 `art/models/costume/raw/r2/`에 둔다(이미 .gitignore, 개당 약 16MB).
- `<후보>/eval/`: 렌더, `overlay_front.png`(빨강=원본만, 파랑=3D만), `landmarks.png`, 귀·손 확대, `+H` 렌더
- `eval/`: `metrics.json`, `scoreboard.png`, `regions_on_source.png`, 시트. `rigged/`: `model.glb`, `task.json`, `convert_dry.json`
- 스크립트: `tools/fidelity_check.py`, 렌더 스크립트, 헤일로 스크립트
- 기록: `records.json`(R1 95cr 3건 + 이번 전부, 시작·끝 잔액), R1 plan의 실제 값, 새 R2 plan, `docs/HANDOFF_CODEX.md` 상태, `art/approved.json`의 T-포즈 그림 항목.
- 루트 `--output`은 지우지 말고 `r2/records/r1_cli_output.json`으로 옮긴다.

Claude는 이 파일로 **처음부터 다시 측정**한다. Codex 수치가 Claude 재측정과 어긋나면 그 후보의 보고는 무효다.

## 6. 규칙 재확인
- 사용자에게는 한국어로 짧게 말한다: 무엇을 바꿨고, 무엇을 보면 되는지.
- 모든 그림과 Tripo가 만든 뷰는 노출 없는 의상이다(몸통 가림, 다리 레깅스). `art/out/v1/`은 입력으로도 업로드로도 절대 쓰지 않는다.
- Roblox 업로드는 이번 범위가 아니다. 나중에 올릴 때는 직접 보고, 사용자에게 보여 준 뒤 10개 이하씩 올린다.
- API 키는 `.env`에만 둔다. 출력하지도, 요청하지도 않는다. `somssi-dev.rbxlx`는 건드리지 않는다.
- 화면 제어(컴퓨터 사용)는 하지 않는다(AGENTS.md 규칙 6). 렌더·검사는 Blender CLI와 PIL로, 스튜디오는 `tools/studio_mcp.py`로 한다.
- 커밋: G 지점마다 `git add`에는 R2 경로와 이번에 고친 파일만 명시한다(`-A` 금지). `.tripo/`와 얼굴 감사 파일은 넣지 않는다. 제목은 한국어로 쓰고 `main`에 push한다.
