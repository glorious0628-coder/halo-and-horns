# 직업 아바타 표정 오프라인 도구

사용자가 고른 기본·진지·미소 3종을 준비한다. GPT가 만든 PNG만 사용하며, 이 도구는 이미지 픽셀을 수정하거나 Studio·유료 API·업로드를 실행하지 않는다.

현재 파일 상태는 각 아바타의 `expressions_manifest.json`과 `validation.json`을 기준으로 확인한다. 승인한 표정은 기본·미소·진지 3개이며 목표는 18종 × 3장이다. 로컬 표정 준비, R15 조립, Roblox 업로드, 실제 게임 검증을 각각 구별한다.

## 실행 순서

Blender 실제 경로: `C:\Users\glori\Tools\blender-5.2.2\blender.exe`

1. `prepare_face_uv.py -- <원본 fixed GLB> <build 출력 폴더> [검토한 프로필 JSON]`
2. 출력 `FaceExpression_source.png`를 확인한 뒤 GPT 그림 편집으로 기본·진지·미소 PNG를 만든다. UV 좌표에 쓰이므로 얼굴 위치와 구도는 고정한다.
3. `align_head_r15.py -- <prepared GLB> <GPT 기본 PNG> <기존 R15 joints.json> <새 HeadExpressions_R15.glb>`
4. `render_prepared_expression.py -- <새 R15 GLB> <렌더 PNG> <표정 PNG> source-front <새 GLB와 같은 이름의 JSON> <기존 joints.json>`으로 정면, `source-quarter`로 30도 측면을 각각 확인한다. 새 Head JSON의 원본 정면 벡터·위쪽 벡터·실제 사용 정점 범위에 맞춰 카메라를 잡는다. 마지막 인자는 원본 몸·보존할 Head 보조 메시를 함께 렌더해 머리 경계를 검증한다. 이전 고정 정면 모델의 숫자 각도 `180`·`150`도 지원한다.
5. `py tools/costume_expressions/validate_expression_assets.py <expressions_manifest.json>`으로 파일·UV·원본·PNG·렌더 연결을 확인한다.

위 1·3·4번은 Blender의 `--background --factory-startup --python <스크립트> -- <인자>` 형태로 실행한다. 원본을 출력 경로로 쓰지 않는다.

## 프로필과 검증 범위

성기사 이외에는 검토한 JSON 프로필을 반드시 전달한다. `mouth_center_screen`은 768px 정면 좌표의 입 중심, `screen_scale`은 성기사 대비 얼굴 크기, `crop_start_fraction`은 머리 구도 시작 높이다. `eye_boxes`·`brow_boxes`는 같은 정면 좌표의 실제 눈·눈썹 영역이다. `skin_hsv`는 앞머리와 피부를 구별하며, 아래 얼굴 그림자는 별도로 좁은 중앙 범위에서 확인한다. 색상으로 누락되는 원본 눈썹 면은 `trace_front_pixels.py`로 UV 대응을 확인한 후 `verified_eyebrow_face_indices`에만 추가한다. `mouth_flatten_radius`·`mouth_cap_radius`는 열린 입의 실제 범위에 맞춰 새 복사본에서 조정한다.

열린 입은 새 복사본에만 피부 곡면을 맞추고 얇은 입 표면을 추가해 닫는다. 머리카락·귀·뒷머리와 몸의 원본 UV를 보존한다. 앞머리에 가려져 삼각형 중심만 안 보이는 눈썹 피부도 표정 UV에 포함해야 진지 표정에 옛 눈썹이 겹치거나 새 눈썹이 끊기지 않는다.

기존 R15 뼈 가중치의 실제 Head 경계를 UV 삼각형으로 대조한다. 높이를 추측해 몸 일부를 Head에 넣지 않는다. fixed GLB와 rig GLB는 같은 UV라도 배율이 약 1.023배 다를 수 있다. 원본끼리 UV 삼각형 꼭짓점을 대조해 affine 변환을 구하며 최대 오차 0.00001 이상이면 거절한다. 준비된 표정 표면 좌표로 이 변환을 추정하지 않는다. `HeadBase`와 `FaceExpression` 모두 UV는 `TEXCOORD_0` 한 개다. 원본 Head PNG와 GPT 기본 PNG의 바이트를 그대로 넣는다.

최종 GLB는 메시 2개 + 텍스처 2개 + 모델 1개로 예상 임포트 에셋 5개다. 별도 미소·진지 PNG 2장까지 새로 올리면 전체 최대 7개다. 임포트 후 `HeadBase`를 기존 Head 자리에서 Head로 사용하고, `FaceExpression`은 같은 상대 위치를 유지해 Head에 붙인다. JSON의 `retained_existing_head_auxiliary_meshes`에 기재한 원본 BodyMat Head 보조 메시·UV·weld는 보존한다. 정상 Head 분할에서는 몸 재임포트가 필요 없다. 기본은 평소, 진지는 공격/피격, 미소는 NPC/유저 대화일 때 표정 텍스처를 바꾼다. 오프라인 검증만으로 실제 게임 적용 완료를 표시하지 않는다.

`build_local_candidate.py`는 검토한 프로필로 기본 후보를 준비하며, `render_local_variants.py`는 이미 생성한 미소·진지 후보를 원본 몸과 함께 렌더한다. 모든 6장을 직접 본 뒤에만 `finalize_local_assets.py`로 검증본·manifest를 저장한다. 이 도구는 이미지 픽셀을 바꾸거나 새 디자인을 선택하지 않는다.

HornsArcherM은 원래 얼굴 일부가 UpperTorso로 잘못 분할되어 있었다. `excluded_expression_faces`에 실제 앞얼굴 UV signature를 따로 기록하며, 원본 HeadMat 전체를 Head로 옮기면 어깨까지 움직일 수 있으므로 금지한다. 정확한 원본 면·뼈·UV를 대조한 별도 R15 분할 수정 후 새 joints로 다시 내보내고 정면·측면·움직임을 확인한다. 최종 분할은 입 모서리의 원래 면까지 포함한 115면이며 기존 112면 버전은 중간본이다. `facial_profile.json`의 `existing_joints_override`가 이 검증한 새 plan을 선택한다. 내보내기와 전체 몸 CG 렌더 모두 joints의 `mechanical_surface_partition` 정책을 원본 복사 장면에서 동일하게 재현하고 signature SHA 및 면 수가 달라지면 거절한다. 이 아바타는 Head 교체와 함께 새 plan의 UpperTorso 재임포트가 필요하다. `body_reimport_required`와 `body_parts_reimport_required`를 반드시 확인한다.

입 또는 눈썹의 작은 원래 삼각형이 색상 검사에서 빠지면 `trace_front_pixels.py`로 실제 렌더 픽셀→원래 UV→원래 면을 먼저 증명한다. 입·피부 면은 `verified_expression_face_indices`, 눈썹 면은 `verified_eyebrow_face_indices`에 대조한 원래 인덱스만 추가한다. Head 외부로 제외되는 실제 얼굴 면은 기계적 분할 수정 없이 준비 완료로 표시하지 않는다. `inspect_excluded_partition.py`는 제외 면의 원본 UV와 실제 Head 관절 위치를 대조한다. 원래 목 피부가 UpperTorso에 남는 경우는 별도 분류한다. 밝은 후드 털은 피부 색상 검사에 잡힐 수 있으므로 `render_excluded_original_faces.py`로 정확한 원래 면만 진단 재질로 강조해 정면·측면에서 직접 확인한다. 실제 후드 장식임이 확인된 면만 프로필의 `reviewed_non_facial_excluded_regions`에 원래 UV·진단 JSON SHA·확인 기록을 넣고 원래 UpperTorso·UV·가중치를 유지한다. 관절 단면 위라는 이유만으로 피부라고 판정하지 않는다. 최종 `excluded_face_partition_review.json`의 Head SHA·원본 rig SHA·면 수가 현재 결과와 맞아야 검증을 통과한다.

HornsWarriorM의 턱 1면과 HaloMageF의 턱 3면도 원본 UV signature와 실제 관절 경계를 검증해 Head로 되돌렸다. 이 두 모델도 새 plan의 UpperTorso를 함께 다시 임포트해야 한다. HornsArcherM 115면과 합쳐 세 모델의 원래 표면·UV·normal은 보존하며 몸의 기존 얼굴 잔여 면만 제거한다.

HaloWarriorF·HaloMageM·HaloMageF의 Tripo rig는 원래 Head 재질을 Body 재질로 합친 오류가 있었다. `restored_material_sources`의 검증한 복사본과 `material_front_fixed` plan을 사용하며, HaloMageF는 추가 턱 보정을 포함한 `material_front_face_fixed` plan을 사용한다. 이 plan의 `source_frame_policy=gltf-positive-z`를 Head 내보내기와 전체 몸 렌더 모두 재현한다. 해당 정책은 source `.recovery.json`의 SHA, 원래 모든 방향성 삼각형의 일대일 대응, 실제 뼈·웨이트·정점 보존 증거가 있을 때만 허용한다. 이전 suffix 없는 plan과 `material_fixed` 중간본은 최종 표정용으로 쓰지 않는다.

NeutralArcherF는 원래 Head·관절·표면 좌표를 유지한 채 조립에서 `--root-reference lower-torso-y`로 투명 HumanoidRootPart 위치를 보정해야 한다. 해당 조건을 프로필·Head JSON·manifest의 `assembly_requirements`에 함께 기록한다. 표정 프리뷰가 통과하더라도 실제 조립·보행 검증을 완료로 표시하지 않는다.

`write_local_index.py`는 각 검증 파일과 manifest의 Head SHA가 일치하는 로컬 목록만 `local_index.json`에 집계한다. 목표 18종·54장과 실제 로컬 결과, 업로드·게임 검증 수를 따로 기록한다.

`export_expression_head.py`는 원래 좌표의 진단용 분리만 수행하므로 R15 업로드 파일로 사용하지 않는다. 실패한 원본 atlas 편집 PNG와 검증용 sparse bake PNG도 업로드하지 않는다.


## 수동 continuous skin 후보 4종

NeutralWarriorF·NeutralArcherM·HaloArcherF·HornsArcherF는 실제 Tripo 뼈가 아닌 추정한 수동 skin이다. 원본 2메시 GLB를 읽기만 하고 `skin_export.py <원래 skin GLB> <prepare_report.json> <GPT 기본 PNG> <새 versioned GLB>`로 Body·HeadBase·FaceExpression 3메시 복사본을 만든다. 원래 POSITION/NORMAL/JOINTS/WEIGHTS와 skin/inverse bind, 원래 HeadBase UV, Body primitive와 원래 두 PNG 바이트를 보존한다. 원래 입 홈 정점도 바꾸지 않고 원래 얼굴 삼각형의 barycentric 웨이트를 쓰는 얇은 129정점·224면 cover만 추가한다. Blender UV signature는 glTF의 V를 1-V로 읽어 정확히 대조하며 원래 UV 바이트는 바꾸지 않는다.

각 3표정의 실제 전체 skin 정면·측면 6장을 직접 확인하고 `finalize_skin_assets.py <새 GLB> --prepare-report <보고서> --reviewed`로 `skin_expressions_manifest.json`과 `skin_validation.json`을 저장한다. `--validate-only`는 이미지를 쓰지 않는 원본·UV·웨이트·면·이미지 바이트 검사다. 3메시+3내장 PNG+모델은 7개, 별도 미소·진지까지 최대9개다. 기존 rigid14 목록과 따로 집계하며 실제 엔진 완료 전 ready=false다.

원래 bone 포즈 진단은 `render_prepared_expression.py` 마지막에 `--pose-json <임시 포즈 JSON>`을 붙인다. JSON에는 현재 GLB SHA와 `bone_local_euler_degrees.Head` 3각도가 필요하다. 원본 skeleton의 Head에만 35도 이하 임시 CG 회전을 주며 원본 파일은 쓰지 않는다. 실제 Roblox 모션 검증을 대신하지 않는다.

continuous skin의 FaceExpression을 움직이는 Head proxy에 직접 weld하면 이중 변환된다. 실제 importer의 공통 Bone host와 root weld를 유지하고 별도 생산 검증 마커가 필요하다. root 구현 제안은 `skin_runtime_contract.json`에 있으며 현재 ExpressionService·ExpressionAssets를 자동 수정하지 않는다.

## 실제 임포트한 파일럿의 Pending graft

`graft_expression.py`는 `--manifest`, `--actual-imports`, `--texture-ledger`, `--assembly-manifest`, `--original-imports`, `--output`을 받는다. 실제 두 메시의 비퇴화 Size/MeshSize와 세 축에서 모두 0이 아닌 중심 차이로 24개 proper axis bake 중 단 하나만 허용한다. 기존 primary Head 바운딩 중심·크기·기존 bake도 일치해야 Neck C0/C1·Head CFrame·attachments·보조 weld를 그대로 유지한다. 실제 MeshID/TextureID/현재 import CFrame을 다시 확인하는 Edit payload를 생성할 뿐 Studio를 호출하지 않는다. 목적지는 원래 Ready의 복사본 `CostumePendingExpressions`이고 Config·원래 Ready는 수정하지 않는다. 실제 게임 검증 전 runtime=false다.

## 로컬 제작과 실제 등록 목록

`write_skin_index.py`는 원본 skin·UV·웨이트·뼈·현재 PNG와 6장 렌더를 검증한 수동4종을 `skin_local_index.json`에 저장한다. `expression_inventory.json`은 rigid14 비교본과 skin4 후보의 중복 없는 18명·54장·기본 프리뷰108장을 집계한다. 추가 Head 포즈8장은 baseline 수에 합치지 않는다. 유료14종의 continuous 표현 포장은 이후 검증본만 교체 후보로 추가하며 rigid 비교본을 보존한다.

`record_actual_registration.py`는 실제 root가 저장한 graft·Ready 승격·공격/피격/만료·대화/피격 우선·OFF/ON/재생성·MeshPart 기반 preload·ExpressionAssets 등록 증거를 읽어 `roblox_registrations/<avatar>.json`을 별도로 만든다. Head/PNG SHA·실제 메시/텍스처 ID·Neck 보존·각 상태가 모두 맞아야 실제 QA 시점의 등록을 기록한다. 원본 manifest, Ready 모델, 소스는 수정하지 않고 Studio도 호출하지 않는다. 현재 파일럿 실제 등록1종과 로컬 제작18종을 혼동하지 않는다. `--help`에서 필수 증거 인자를 확인한다. 기록 파일은 현재 Studio를 새로 조회한 결과가 아닌 검증 당시의 SHA 연결된 증거다.

수동 skin 원본15뼈는 추정뼈이고, 유료 원본23뼈는 실제 원래 계층을 보존할 때만 구별해 표시한다. 성장 중 bind 비교는 복제되는 HumanoidRootPart.Size와 검증한 원래 Root 크기의 균일비율 q를 사용한다. bind 회전은 유지하며 위치만 q배로 확인한다. `Model.Scale` 또는 성장 전 CFrame 전체의 그대로 비교는 사용하지 않는다.
