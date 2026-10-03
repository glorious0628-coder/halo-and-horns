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
