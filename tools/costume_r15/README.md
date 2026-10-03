# 실제 리깅 코스튬 → R15 준비

유료 Tripo 리깅 결과를 받은 뒤 쓰는 **로컬 Blender 도구**입니다. 생성·업로드·API 호출을 하지 않습니다. 원본 GLB를 수정하지 않고, 새 출력 폴더에 15부위 GLB 묶음과 `joints.json`만 만듭니다.

```powershell
& '<Blender 실행 파일>' --background --factory-startup --python tools/costume_r15/convert.py -- art/models/tripo/Costume_HaloWarriorM_rig_<작업ID>.glb build/costume_r15/Costume_HaloWarriorM --height 5.5 --dry
```

`--height`는 변환 후 전체 높이(스터드)입니다. 검증 결과를 확인한 뒤 `--dry`를 빼면 파일을 만듭니다. 기존 출력 폴더가 있으면 덮어쓰지 않고 중단합니다.

현재 `art/models/costume/fixed/*.glb`는 **리깅이 없는 정적 모델**이므로 입력으로 받지 않습니다. 머리·팔·다리 관절을 높이/바운딩 박스로 추측하거나, 정적 모델을 몸에 붙여 코스튬으로 위장하지 않습니다.

## 검사와 출력

- 실제 스킨과 Armature 1개, Mixamo의 Hips/Spine1/Head 및 양쪽 팔·손·다리·발 뼈와 부모 계층이 있어야 합니다. 손가락·눈은 실제 부모 뼈를 따라 해당 부위로 묶습니다.
- 모든 정점에 유효한 뼈 웨이트가 있어야 합니다. 각 삼각형은 원래 뼈 웨이트의 평균이 가장 큰 부위로 배분합니다. 50% 미만 경계도 진단에 기록합니다. 서로 붙지 않은 부위의 정확한 동률은 기본적으로 거부하며, 실제 뼈 계층의 가까운 부모를 고르는 `--nonadjacent-ties parent-depth`는 별도 검토 후 사용합니다.
- R15 15부위가 모두 비어 있지 않아야 합니다. 다중 재질은 원본 재질별 별도 메시로 보존하고 실제 몸 부위에만 용접합니다. 서로 다른 UV 구성·다른 Armature·추가 변형 모디파이어·블렌드 셰이프는 거부합니다.
- 원본 면을 각 부위에 한 번씩 배분합니다. UV를 다시 펴거나 얼굴을 굽지 않습니다. 부위별 원래 면의 UV 값이 그대로인지 비교하고, GLB 안의 이미지 바이트는 원본 바이트로 보존합니다.
- 방향은 실제 좌우 어깨·머리·골반 뼈로 잡습니다. 관절 위치는 실제 뼈 머리에서 가져옵니다. 부위 CFrame은 메시 중심, Motor6D는 Root/Waist/Neck/Shoulder/Elbow/Wrist/Hip/Knee/Ankle 표준 이름입니다. C0/C1은 같은 실제 관절을 연결하도록 계산합니다.
- GLB는 한 부위당 메시 1개가 되도록 검사합니다. 모델 컨테이너 1개 + 부위 메시 수 + 사용된 이미지/맵 역할 수를 합쳐 묶음당 예상 업로드 에셋을 10개 이하로 나눕니다. ORM 이미지의 Metalness/Roughness는 각각 계산합니다. 실제 Importer 화면의 수량도 확인해야 합니다.
- `joints.json`에 원본 SHA256, 배율, 부위 CFrame, C0/C1, 실제 원본 뼈 이름, 이미지 SHA256, 묶음 목록을 남깁니다. HumanoidRootPart는 별도 투명 Part로 만들며 GLB 업로드에 포함하지 않습니다.

## 아직 보장하지 않는 부분

뼈 웨이트로 면을 나누는 작업은 스킨을 **15개 단단한 부위**로 바꾸는 것입니다. 관절 이음새·치마·망토는 움직여 보면서 확인해야 합니다. Mixamo의 A/T 포즈와 뼈 롤이 Roblox 기본 Animate의 기준과 다를 수 있습니다. 관절 위치가 정확해도 기본 걷기·점프가 자동으로 정확해진다고 보장하지 않습니다.

따라서 출력은 `rig_ready_for_game=false`, `requires_studio_animation_validation=true`로 남깁니다. Studio에서 조립한 뒤 걷기·뛰기·점프·팔 움직임을 확인하기 전에는 CostumeRigs에 플레이용 템플릿으로 등록하지 않습니다. 이 도구는 애니메이션 리타깃이나 포즈 보정을 임의로 수행하지 않습니다.

기존 `tools/fix_face.py`는 메시를 합치고 transform_apply를 한 뒤 높이로 머리를 자릅니다. Armature 모디파이어·바인드 행렬·웨이트 보존을 검사하지 않으므로 **리깅 후 그대로 사용하지 않습니다**. 원본 정적 코스튬용으로만 유지합니다. 얼굴 보정 텍스처를 리깅 결과에 다시 붙이는 작업도 메시/UV 대응이 검증되기 전에는 하지 않습니다.

```powershell
py -m unittest discover -s tools/costume_r15 -p test_constraints.py
```

위 검사는 실제 뼈 이름/계층, 빈 웨이트, NaN, 불명확한 경계, 업로드 묶음 상한을 확인합니다. 실제 Tripo 리깅 결과와 Studio 애니메이션 검증은 별도로 필요합니다.

## 실제 가져오기 검사와 조립

`assemble.py`는 무료 로컬 JSON/Luau 생성기입니다. Studio 실행·업로드·API 호출·게임용 리그 등록은 하지 않습니다. 가져온 각 묶음을 `ServerStorage.CostumeImports.Costume_HaloWarriorM` 아래에 넣습니다. Importer가 붙이는 `Mesh` 접미사를 처리하며, 원본 조각은 그대로 둡니다.

```powershell
py tools/costume_r15/assemble.py build/costume_r15/Costume_HaloWarriorM/joints.json
py tools/studio_mcp.py call execute_luau @build/costume_r15/Costume_HaloWarriorM/inspect_imports.json
```

두 번째 명령은 **읽기만** 합니다. 반환된 JSON을 `actual_imports.json`으로 저장한 뒤 실행용 조립 JSON을 만듭니다.

```powershell
py tools/costume_r15/assemble.py build/costume_r15/Costume_HaloWarriorM/joints.json --mode assemble --inspection build/costume_r15/Costume_HaloWarriorM/actual_imports.json
py tools/studio_mcp.py call execute_luau @build/costume_r15/Costume_HaloWarriorM/assemble_pending.json
```

- 모든 GLB·텍스처 SHA256와 실제 MeshId/Size/MeshSize/CFrame/PivotOffset를 검사합니다. 실제 가져오기가 반영한 회전은 각 묶음의 모든 중심·크기에 동시에 맞는 24개 정회전 중 하나로 확인합니다. 반사·불명확한 회전·비균등 크기 변경·설명되지 않는 피벗은 거부합니다.
- GPT 원본과 같은 방향·위치를 복원합니다. 재질 조각의 경계 중심 차이와 Importer의 메시 회전을 함께 보정하고, 실제 뼈 관절의 C0/C1도 각 보정된 MeshPart 좌표계로 다시 계산합니다. 원본 UV·텍스처·메시는 변경하지 않습니다.
- 검사 후 import 속성이나 텍스처가 바뀌면 실행을 거부합니다. 15개 Motor6D·30개 관절 Attachment·R15 Humanoid/Animator·투명 RootPart를 만들고, 부가 재질 메시를 원래 몸 부위에만 용접합니다. HipHeight는 실제 발 최저점으로 계산합니다.
- 결과는 `ServerStorage.CostumePendingRigs`에만 생성합니다. 이미 같은 대기 리그가 있으면 덮어쓰지 않습니다. 걷기·뛰기·점프·전투·OFF 복원과 관절 틈을 실제로 확인한 후에만 별도 작업으로 `CostumeRigs`에 등록합니다.

```powershell
py -m unittest discover -s tools/costume_r15 -p 'test_*.py'
```

## Importer 대신 원본 EditableMesh 업로드

**2026-10-03 실제 확인:** 무료 원본 비교와 `LeftLowerLeg` 미리보기는 통과했습니다(850정점·596삼각형, 위치·노멀·UV·경계 오차 0). 실제 `CreateAssetAsync` 1회 호출은 현재 Studio에서 `CreateAssetAsync and CreateAssetVersionAsync are not available yet`로 중단되었고, 업로드 성공은 0개입니다. `editable_upload_ledger.json`에는 `Unknown`으로 즉시 기록했습니다. 이 항목을 지우거나 다시 업로드하지 않습니다.

현재 진행 경로는 **기존 네이티브 3D Importer**입니다. 이미 가져온 Batch01의 7개 메시를 유지하고, 필요할 때 `batch_02.glb`의 7개·`batch_03.glb`의 4개를 한 묶음씩 가져옵니다. 각 Importer 화면에서 실제 업로드 수량이 10개 이하인지 확인하고, 각각 `ServerStorage.CostumeImports.Costume_HaloWarriorM.Batch02`·`Batch03`에 보관합니다. 총 18개 실제 메시가 준비되면 위 `assemble.py` 검사·대기 리그 조립·움직임 검증 순서로 이어갑니다. 아래 EditableMesh 업로드 명령은 기능 지원이 확인된 이후를 위한 도구 설명이며, 현재 재실행할 단계가 아닙니다.

`editable_upload.py`의 기본 실행은 파일만 만듭니다. GLB 원본 정점·삼각형·노멀·UV·텍스처 SHA를 검사하고, 실제 Batch01 텍스처 ID를 같은 이미지에 재사용합니다. 형태 단순화·UV 재배치·이미지 다시 굽기는 하지 않습니다. [공식 AssetService](https://create.roblox.com/docs/reference/engine/classes/AssetService)와 [EditableMesh](https://create.roblox.com/docs/reference/engine/classes/EditableMesh) API를 사용하며, 실제 업로드 가능 여부는 현재 로컬 플러그인 권한으로 확인해야 합니다.

먼저 이미 가져온 원본 Mesh를 무료로 읽어 GLB와 비교합니다. 수치 확인이 끝나면 임시 EditableMesh를 폐기하며 업로드하지 않습니다.

```powershell
py tools/costume_r15/editable_upload.py build/costume_r15/Costume_HaloWarriorM/joints.json
py tools/studio_mcp.py call execute_luau @build/costume_r15/Costume_HaloWarriorM/editable_probe_reference.json
```

반환 JSON을 `editable_probe_reference_result.json`에 저장합니다. 원본 삼각형 방향과 UV 방향이 검증되어야 다음 파일을 생성할 수 있습니다.

```powershell
py tools/costume_r15/editable_upload.py build/costume_r15/Costume_HaloWarriorM/joints.json --mode preview --mesh LeftLowerLeg --probe-result build/costume_r15/Costume_HaloWarriorM/editable_probe_reference_result.json
py tools/studio_mcp.py call execute_luau @build/costume_r15/Costume_HaloWarriorM/editable_preview_LeftLowerLeg.json
```

이 단계도 업로드하지 않습니다. `ServerStorage.CostumeMeshPreviews`에 원본 배열과 완전히 같은 1조각을 만들고 모든 면·정점·노멀·UV를 다시 읽어 확인합니다. 실제 Importer에서 검증한 Y180 메시 좌표계를 유지하며, CFrame으로 원본 방향을 복원합니다. 같은 원본이고 업로드한 적이 없는 임시 미리보기만 재검사 후 교체할 수 있습니다. 반환 JSON을 `editable_preview_LeftLowerLeg_result.json`에 저장합니다.

검토한 1조각의 실제 업로드는 다음과 같이 **명시적으로 `--execute`를 붙일 때만** 수행합니다. 이 옵션을 빼면 검토할 JSON만 생성합니다.

```powershell
py tools/costume_r15/editable_upload.py build/costume_r15/Costume_HaloWarriorM/joints.json --mode upload --mesh LeftLowerLeg --probe-result build/costume_r15/Costume_HaloWarriorM/editable_probe_reference_result.json --preview-result build/costume_r15/Costume_HaloWarriorM/editable_preview_LeftLowerLeg_result.json --execute
```

- 호출마다 실제 메시 1개만 업로드합니다. 원래 GLB 묶음은 7개·4개입니다. 사용자에게 원본을 보여 주고 10개 이하씩 나누어 진행합니다.
- 호출 전 `editable_upload_ledger.json`에 요청을 기록하고 파일 잠금을 겁니다. 성공한 ID는 추가 작업 전에 바로 디스크에 저장합니다. 성공 ID를 다시 요청하면 재사용하고, `Submitting`·`Unknown`·`Failed`나 남은 잠금이 있으면 자동 재시도하지 않습니다.
- Studio 미리보기도 요청 전 상태를 기록합니다. 응답을 잃으면 고유 `asset_name`과 원본 fingerprint로 실제 업로드 여부를 확인한 뒤 정리합니다. 확인되지 않은 항목을 임의로 지우거나 다시 업로드하지 않습니다.
- AssetService가 현재 실행 권한을 지원하지 않으면 반복 호출하지 않고 기존 Importer 방법으로 진행합니다.

성공 ID를 로컬 ledger에 저장한 뒤 별도로 게임의 import 보관 폴더에 연결합니다. 이 단계는 새 업로드를 하지 않습니다.

```powershell
py tools/costume_r15/editable_upload.py build/costume_r15/Costume_HaloWarriorM/joints.json --mode attach --mesh LeftLowerLeg --probe-result build/costume_r15/Costume_HaloWarriorM/editable_probe_reference_result.json
py tools/studio_mcp.py call execute_luau @build/costume_r15/Costume_HaloWarriorM/editable_attach_LeftLowerLeg.json
```

연결된 메시의 실제 경계·CFrame·피벗은 기존 `assemble.py` 검사와 호환됩니다. 모든 조각을 연결한 뒤에도 리그는 대기 폴더에서 움직임을 검증해야 합니다. 임시 EditableMesh를 플레이어 캐릭터로 사용하지 않습니다.

업로드 후 `--mode verify --mesh LeftLowerLeg --probe-result <원본 probe 결과>`로 생성한 payload는 저장된 실제 메시 ID를 무료로 읽어 원본 면·정점·UV·노멀을 다시 비교합니다. 새 업로드를 수행하지 않습니다.

## 원본 보존 기계적 복구 (2026-10-03)

아래 옵션은 기본 strict 변환에서 실제 확인된 제한만 명시적으로 복구합니다. 원본 GLB는 쓰지 않으며, 출력은 새 `build/` 폴더에만 만듭니다. 각 묶음은 메시와 텍스처를 합쳐 10개 이하입니다. 출력의 `rig_ready_for_game=false`는 유지하며, 실제 Importer·관절 움직임·ON/OFF 검증 전에는 게임용 리그로 승격하지 않습니다.

| 대상 | 확인한 제한 | 원본 보존 복구 |
|---|---|---|
| HornsMageM | Body 622번 면의 Head/왼팔 세 웨이트 동률 | `--split-weight-ties`: 원래 면 위의 웨이트 경계로 1면을 6면으로 세분화. 위치·UV·노멀을 원래 면에서 보간하고 기존 정점은 그대로 유지 |
| HornsMageF | LeftLowerArm의 최댓값 웨이트 영역이 없음 | `--recover-empty-left-forearm`: 실제 팔꿈치/손목 뼈 단면 사이에 완전히 들어오는 원래 팔 면 415개만 재귀속. 단면을 가로지르는 면과 모든 정점·UV·노멀은 그대로 유지 |
| HaloWarriorF | LeftFoot의 평균 웨이트 영역이 없음 | `--recover-empty-left-foot`: 실제 무릎→발목 축에서 발목 아래에 완전히 들어오는 원래 발 웨이트 면 56개만 재귀속 |
| HornsArcherM | 실제 앞얼굴 115면이 UpperTorso에 귀속됨 | `--restore-head-face-signatures`: UV 서명·원본 fixed 면 좌표·검증된 affine·실제 Head 관절면을 모두 대조한 115면만 Head로 재귀속. 최초 112면 후보에서 확인된 입 가장자리 3면을 추가. 머리 재질의 다른 몸/어깨 면은 그대로 유지 |
| HornsWarriorM / HaloMageF | 실제 턱 1면 / 피부 3면이 UpperTorso에 귀속됨 | 각 `verified_head_face_reassignment.json`으로 원래 면만 Head에 복원. 실제 Head joint 아래 목 피부는 옮기지 않음 |
| NeutralArcherF | 원본 투명 Root의 높이로 계산한 HipHeight가 음수 | `assemble.py --root-reference lower-torso-y`: 투명 Root의 Y만 실제 LowerTorso 중심으로 옮김. XZ·크기·보이는 메시·실제 뼈의 월드 관절 위치는 그대로 유지 |

HornsMageM의 원래 14,031면은 14,036면이 됩니다. 보간 후 노멀 정규화 차이는 최대 약 0.06552°이며, 이 차이를 기록합니다. HornsMageF와 HaloWarriorF는 원래 면 수와 면 자체가 변하지 않습니다. 변환기는 각 원본 corner normal을 메시 경계에도 보존합니다. Blender의 custom-normal 저장 오차는 별도 `maximum_normal_export_error`에 기록하며 0.0001을 넘으면 거절합니다. 원본 이미지 byte SHA256·UV·정점·삼각형 방향·15관절 관계도 출력 때 검증합니다.

현재 사용 가능한 Blender는 `C:/Users/glori/Tools/blender-5.2.2/blender.exe`입니다. 다음 명령은 새 폴더에만 출력합니다. 이미 출력이 있으면 임의 덮어쓰지 않습니다.

```powershell
& 'C:/Users/glori/Tools/blender-5.2.2/blender.exe' --background --factory-startup --python-exit-code 2 --python tools/costume_r15/convert.py -- art/models/tripo/Costume_HornsMageM_rig_c607eae7-d06e-4e2d-a95f-05b429771ec7.glb build/costume_r15/Costume_HornsMageM --height 5.5 --split-weight-ties
& 'C:/Users/glori/Tools/blender-5.2.2/blender.exe' --background --factory-startup --python-exit-code 2 --python tools/costume_r15/convert.py -- art/models/tripo/Costume_HornsMageF_rig_1d458a15-2257-4e35-9980-cdf5cac63f05.glb build/costume_r15/Costume_HornsMageF --height 5.5 --recover-empty-left-forearm
& 'C:/Users/glori/Tools/blender-5.2.2/blender.exe' --background --factory-startup --python-exit-code 2 --python tools/costume_r15/convert.py -- art/models/tripo/Costume_HornsArcherM_rig_1c4762a2-29bd-4e14-baca-488d2d44a98b.glb build/costume_r15/Costume_HornsArcherM_face_fixed_v2 --height 5.5 --restore-head-face-signatures build/expr_qa/Costume_HornsArcherM/face_reassignment_candidates_v2.json
py tools/costume_r15/assemble.py build/costume_r15/Costume_HornsArcherM_face_fixed_v2/joints.json --name Costume_HornsArcherM
py tools/costume_r15/assemble.py build/costume_r15/Costume_NeutralArcherF/joints.json --root-reference lower-torso-y --output build/costume_r15/Costume_NeutralArcherF/inspect_imports_root_fixed.json
```

NeutralArcherF의 높이 옵션은 이후 `--mode assemble --inspection ...`에도 동일하게 전달합니다. source 기본값은 음수 HipHeight를 계속 거절합니다. 실제 출력을 원본으로 재분석하는 별도 도구는 `mechanical_surface_partition`의 옵션과 얼굴 서명 파일을 같은 순서로 재적용해야 합니다. 원래 웨이트만 재분석하면 복구된 면 배정과 일치하지 않습니다.

`render_surface_comparison.py joints.json 새출력폴더`는 동일한 실제 뼈 좌표·카메라로 원본/출력의 평면 텍스처와 조명 렌더를 비교합니다. 최종 두 Horns 마법사는 평면 렌더 오차가 255단계 기준 평균 0.00005 이하, 조명 렌더 평균 오차가 0.014 이하였습니다. 새 Halo 3종은 아래 원본 재질 복구 후 정지 렌더·이미지·UV·corner normal 검증을 통과했습니다. 이는 정지 외형 보존 검사이며 Studio 애니메이션 통과를 뜻하지 않습니다. `preliminary_local_20261003/`와 아래 사용 금지 중간 출력은 Importer에 사용하지 않습니다.

## 무료 리깅 검사 후보와 원본 형상 비교

`merge_preserved.py`는 Head/Body가 있는 정적 GLB를 하나의 mesh node/원래 두 primitive로 포장합니다. 원본 바이너리·accessor·material·이미지·UV를 유지하며 메시 용접·형상 변경을 하지 않습니다. 정적 메시가 이미 리깅되었다고 표시하지 않으며, API를 호출하지 않습니다.

```powershell
py tools/costume_r15/merge_preserved.py art/models/costume/fixed/Costume_HaloWarriorF.glb --output-directory build/costume_r15/merge_candidates/Costume_HaloWarriorF
py tools/costume_r15/compare_static_surface.py art/models/costume/fixed/Costume_HaloArcherF.glb art/models/costume/raw/C2k_HaloArcherF.glb
```

실제 무료 검사에서 병합 후보 7종 중 HaloWarriorF/HaloMageM/HaloMageF만 리깅 가능했습니다. 나머지 HaloArcherF/HornsArcherF/NeutralWarriorF/NeutralArcherM은 병합 및 원본 raw2k 무료 검사 모두 거절됐습니다. 네 raw2k는 fixed와 원래 oriented triangle/월드 정점 형상이 같지만, 원본 2K PBR UV/이미지와 fixed의 1K 얼굴 UV는 다릅니다. 이 형상 비교를 리깅 성공이나 얼굴 텍스처 호환으로 해석하지 않습니다. 자동 유료 재시도는 하지 않습니다.

## Tripo가 누락한 원래 머리 재질 복구

실제 병합 리깅 3종의 반환 GLB는 2개의 원래 primitive/material 중 HeadMat을 누락하고 전체 표면에 BodyMat 하나를 적용했습니다. UV는 원래 fixed와 정확히 같았지만 머리에 몸 텍스처가 표시됐습니다. 원래 corner normal도 병합 과정에서 바뀌었습니다. `restore_material_regions.py`는 original fixed와 실제 rig의 모든 oriented triangle을 좌표로 1회씩 대조하여 원래 재질/UV/노멀/이미지를 새 복사본에 되돌립니다. 실제 rig의 POSITION/JOINTS/WEIGHTS·뼈·bind·animation과 원래 바이너리 prefix는 그대로 유지합니다. 맞지 않는 면·뒤집힌 면·겹치는 면·불명확한 좌표 대응·새 노드 변환은 거절합니다.

```powershell
py -B tools/costume_r15/restore_material_regions.py art/models/costume/fixed/Costume_HaloWarriorF.glb art/models/tripo/Costume_HaloWarriorF_rig_9e168902-6a36-4220-9bcd-732502cfd0a2.glb --output build/costume_r15/restored_material_sources/Costume_HaloWarriorF_rig_material_restored.glb
& 'C:/Users/glori/Tools/blender-5.2.2/blender.exe' --background --factory-startup --python-exit-code 2 --python tools/costume_r15/convert.py -- build/costume_r15/restored_material_sources/Costume_HaloWarriorF_rig_material_restored.glb build/costume_r15/Costume_HaloWarriorF_material_front_fixed --height 5.5 --recover-empty-left-foot --source-frame gltf-positive-z
py tools/costume_r15/assemble.py build/costume_r15/Costume_HaloWarriorF_material_front_fixed/joints.json --name Costume_HaloWarriorF
```

변환된 원본과 rig의 uniform scale/translation 대응은 최대 0.000000842 좌표 오차였고 모든 원래 삼각형의 방향·코너를 정확히 1회 대응했습니다. 원본이 +Z를 보는 glTF Y-up임을 직접 렌더로 확인한 뒤 `--source-frame gltf-positive-z`로 Roblox의 -Z 정면에 맞춥니다. 이 옵션은 실제 source SHA와 일치하는 `.recovery.json` 또는 명시된 수동 후보가 있어야 허용합니다. 모든 보이는 면과 실제 source joint도 같은 좌표 변환을 거치므로 형상은 바꾸지 않습니다. 기본 뼈 축 옵션은 그대로입니다. 외부 표정/렌더 도구도 `source_frame_policy`를 재적용해야 합니다.

최종 출력은 다음과 같습니다. 접미사 없는 3종은 재질 누락을 보존했던 중간 출력이고, `_material_fixed`는 옛 뼈 축으로 정면이 틀어진 중간 출력이므로 사용하지 않습니다.

| 최종 폴더 (`build/costume_r15/`) | 메시 | 묶음별 최대 자산 수 |
|---|---:|---|
| Costume_HaloWarriorF_material_front_fixed | 18 | 10 / 10 / 5 |
| Costume_HaloMageM_material_front_fixed | 17 | 10 / 10 / 4 |
| Costume_HaloMageF_material_front_face_fixed | 19 | 10 / 10 / 7 |

HaloMageF 최종본은 `art/models/costume/expressions/Costume_HaloMageF/verified_head_face_reassignment.json`으로 실제 Head joint 위 3면만 추가 복원한 것입니다. HornsWarriorM은 `Costume_HornsWarriorM_face_fixed`, HornsArcherM은 `Costume_HornsArcherM_face_fixed_v2`를 사용합니다. `build/`는 ignored이므로 최종 복구 source GLB와 provenance 보관은 별도 자산 저장 단계에서 수행해야 합니다.

## 무료 검사 거절 4종의 수동 관절 후보

원래 정적 GLB에 없는 뼈를 원본 뼈로 표시하지 않습니다. 승인 원본의 정면/측면, 실제 장갑·팔 단면·무릎판·부츠·비율을 읽고 관절 중심을 추정했습니다. `manual_archer.py`와 `manual_neutral.py`는 모든 면의 부위 배정·15관절 좌표·원본 표면 근거 JSON을 준비합니다. `manual_bind.py`는 이 명시적 입력을 새 skin으로 만듭니다. 원래 POSITION/NORMAL/UV/material/image byte와 면 방향은 그대로이며 모든 원래 면이 정확히 한 부위에 배정됩니다. 새 얼굴·옷·무기 디자인을 만들지 않습니다.

```powershell
py -B tools/costume_r15/manual_archer.py HaloArcherF --output build/manual_partition_audit/HaloArcherF_manual_landmarks.json
py -B tools/costume_r15/manual_bind.py build/manual_partition_audit/HaloArcherF_manual_landmarks.json build/manual_partition_candidates/HaloArcherF/Costume_HaloArcherF_manual.glb
& 'C:/Users/glori/Tools/blender-5.2.2/blender.exe' --background --factory-startup --python-exit-code 2 --python tools/costume_r15/convert.py -- build/manual_partition_candidates/HaloArcherF/Costume_HaloArcherF_manual.glb build/manual_partition_candidates/HaloArcherF/r15 --height 5.5 --allow-inferred-manual --source-frame gltf-positive-z
& 'C:/Users/glori/Tools/blender-5.2.2/blender.exe' --background --factory-startup --python-exit-code 2 --python tools/costume_r15/render_manual_motion.py -- build/manual_partition_candidates/HaloArcherF/r15/joints.json build/manual_partition_candidates/HaloArcherF/motion_qa
```

수동 입력은 `schema=1`, `coordinates=gltf_world_y_up`, `rig_origin=inferred_manual_candidate`, `rig_ready_for_game=false`와 15개의 `landmarks`/`landmark_evidence`를 요구합니다. `triangle_owners`는 `{mesh, primitive, owners}` 목록이며 owners 길이는 각 원래 indices/3과 같아야 합니다. 누락·중복·빈 부위·근거 없는 위치는 거절합니다. 변환에는 `--allow-inferred-manual`이 필요하고, 생성된 대기 모델에도 수동 후보 표시를 남깁니다.

로컬 후보는 휴식·걷기 양쪽·팔 굽힘·공격 스트레스·머리 돌리기 각각 정면/측면 12장과 실제 위치의 관절 gizmo로 점검합니다. FK 관절 연결 오차 검사는 움직임이 분리되는 기술 오류만 확인하며, 승인 공격의 실제 타이밍·엔진 물리·걷기·OFF 복원을 대신하지 않습니다. 초기 후보의 잘못 움직이는 장갑/긴 머리 및 작은 분리 면은 원래 면 귀속만 보정했습니다. 강체 경계의 틈·옷/골반의 일부 분리는 남아 있으므로 **모든 수동 후보는 아직 게임 등록 보류**입니다. 최신 각 후보의 `visual_review.json`/`motion_qa.json`을 확인합니다. 중간 후보를 최종 통과로 주장하지 않습니다.

```powershell
py -B -m unittest discover -s tools/costume_r15 -p 'test_*.py'
```

## 원래 skin을 유지하는 별도 시각 후보 (2026-10-04)

강체 분할의 관절 틈을 피하려면 원래 skin을 보존해야 합니다. `preserve_skin.py`는 실제 Tripo skin의 POSITION/NORMAL/UV/JOINTS/WEIGHTS/inverse-bind/이미지 바이너리를 그대로 복사합니다. 실제 principal 15개 bone의 이름만 R15 이름으로 바꾸고 Root/Spine/Neck/Shoulder/Toe 등의 보조 bone은 삭제하지 않습니다. 기존 `joints.json`의 실제 15관절 위치와 1회 similarity 변환을 대조한 scene wrapper만 추가합니다. 원래 골격·가중치·표면을 다시 설계하지 않습니다.

```powershell
py -B tools/costume_r15/preserve_skin.py build/costume_r15/Costume_HaloArcherM/joints.json build/costume_r15/skin_candidates/Costume_HaloArcherM_v2/Costume_HaloArcherM_skin.glb
& 'C:/Users/glori/Tools/blender-5.2.2/blender.exe' --background --factory-startup --python-exit-code 2 --python tools/costume_r15/render_skin_comparison.py -- build/costume_r15/skin_candidates/Costume_HaloArcherM_v2/Costume_HaloArcherM_skin.skin.json build/costume_r15/skin_candidates/Costume_HaloArcherM_v2/motion_qa
```

기존 출력이면 덮어쓰지 않으므로 재생성 때는 새 폴더를 지정합니다. 현재 최종 HaloArcherM 후보는 위 `_v2` 경로입니다. 두 시각 surface의 node와 mesh 이름은 모두 `CostumeSkinBody`/`CostumeSkinHead`입니다. 23개 실제 bone·14,384면을 유지하며 업로드 추정은 model 1 + mesh 2 + texture 2 = 5개입니다. 원래 바이너리 전체가 동일하고 실제 proxy joint 위치 오차는 0.000000662 이하였습니다. 실제 Blender Armature 변형과 독립 LBS의 비교 오차는 0.00000229 이하였으며, 동일한 휴식·걷기·팔 굽힘·공격 스트레스·머리 회전의 skin/강체 앞/옆 비교 24장을 생성했습니다. 소스의 잘못된 가중치까지 고쳤다는 뜻은 아닙니다.

수동 후보 4종에는 원본 정적 accessor를 그대로 두고 공유 정점에 동일한 연속 가중치를 추가하는 `manual_neutral.py --bind-continuous`를 사용합니다. 여자 궁수는 `manual_archer.py <name> --bind-continuous <검토된 landmarks.json> <새 GLB> --canonical-height 5.5`로 같은 binder를 호출합니다. 기존 삼각형·geometry·UV·노멀·재질·이미지는 그대로이며, 15개 관절은 계속 **추정 관절**입니다. 최신 skin 출력은 `build/manual_partition_candidates/NeutralWarriorF_skin_v3/`, `NeutralArcherM_skin_v3/`, `HaloArcherF_skin_v1/`, `HornsArcherF_skin_v1/`입니다. 원래 강체 후보의 큰 틈과 떠 있는 면은 로컬 연속 skin 움직임에서 개선됐고, 소매·옷의 굴곡 압축은 실제 동작에서도 점검해야 합니다.

이 GLB를 기존 `convert.py`나 강체 `assemble.py`에 넣으면 skin을 잃으므로 사용하지 않습니다. 실제 Importer가 생성한 bone/Size/bind를 먼저 검사하고 별도의 15부위 R15 물리 proxy와 연결해야 합니다. sidecar의 `source_to_game_affine`는 glTF column-major 16값이며, 원래 Bone hierarchy와 보조 bone을 모두 보존합니다. 각 proxy의 현재/rest delta를 실제 bone bind에 적용하고, 부모 bone의 현재 transform을 반영해 local `Bone.Transform`을 계산합니다. 공식 [Bone 문서](https://create.roblox.com/docs/reference/engine/classes/Bone)는 Transform이 복제되지 않는다고 명시하므로 모든 클라이언트의 animation 이후 갱신과 실제 ON/OFF·무기·표정·충돌 검증이 필요합니다. [Rigging 문서](https://create.roblox.com/docs/art/modeling/rigging)에 따라 bone은 시각 표면을 변형하며 충돌 형상을 바꾸지 않습니다.

모든 새 skin은 `rig_ready_for_game=false`입니다. 로컬 렌더 통과를 실제 게임 등록이나 Studio 통과로 표시하지 않습니다. 코드와 최종 source GLB/sidecar/추정 landmark 입력을 함께 보관해야 하며, ignored `build/`에만 남긴 출력은 Git 체크포인트에 포함되지 않습니다.
