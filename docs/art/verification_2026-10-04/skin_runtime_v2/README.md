# Skin Runtime Schema2 실제 증거

> 기록용(2026-10-09 검수): 2026-10-04 기록이다. '현재 게임용 2/18종'은 당시 숫자이고, 치비 코스튬은 그 뒤 게임에서 빠졌다(SPEC A23-5).

## 최신 MouthRestored 실제 승격·생산 확인

현재 게임용 **2/18종**: 성기사 남 기존 강체+빛 궁수 남 BindingSchema1/23Bone/3표면. 새 MouthRestored SHA `17972af9…`는 원래438면/Body/UV/JW/Bone/PNG를 보존하고 승인된 입71개 P/N만 별도 strict manifest/ledger로 복원했다. 일반 exact P/N gate는 유지한다.

최신 Shared 실제23검사(1→2→1·disabled/duplicate/이름변경 Neck·schema1·rigid 회귀)와 새 실제 engine691검사(root1/internal3), Play2497프레임/fault0/최대0.000221093stud, 성장1→2→1/OFF·ON/사망·3표정 실제 이벤트를 통과했다. 루트가 Native 기본/진지/미소/HurtBig에서 웃는 입 홈 제거와 피부 변형을 직접 확인해 생산 승격했다. 실제 production source의 새15초 Play에서도 QATrial 없이 실제 Halo/Archer 선택→Active/ExpressionReady/새 Mesh120232648183385/Binding1을 확인했다. 단일 클라이언트/진단 고정 pose 범위다.

`skin_binding_contract_actual.json`은 최신23검사다. 이전19검사는 `skin_binding_contract_19_actual_legacy.json`에 원래 SHA로 보존했다. 아래 당시19검사 언급은 역사적 결과이며 최신파일과 구분한다.

`halo_archer_m_face_union_mouth_binding_*`는 새 Import/inspect/조립/691matcher/표정ID 재사용/Play/Native 검토/생산 승격/원래 source smoke 증거다. `*_promotion_actual.json.scale_contract=[1,2,1]`는 새 Edit 구조 계약이며 trial 이벤트는 별도 mechanics다. 중첩 user_id 제거 후에도 원래 QA/inspection SHA를 덮어쓰지 않았다. 첫 UI 초기화 조건 실패는 최종 JSON 재실행 전 사건으로 별도 남기며 성공 JSON에서 실패 전체 결과를 복원할 수 없다고 명시한다.

새 [기본](halo_archer_m_face_union_mouth_binding_neutral_native.jpg), [진지](halo_archer_m_face_union_mouth_binding_serious_native.jpg), [미소](halo_archer_m_face_union_mouth_binding_softsmile_native.jpg), [HurtBig](halo_archer_m_face_union_mouth_binding_hurtbig_native.jpg)는 **Play-only API로 지속해 UV 확인한 화면; 원래 이벤트 전환은 별도 실제 QA**다. 이 사진만으로 전투 시간·전체18종 모션·활/손/무기 품질을 완료로 쓰지 않는다.

최신 저장 2026-10-04 05:56:14 KST/12,071,834바이트/build-place byte 동일 SHA `6da73478884aebcea934e2dbdb9f931a36c13fa211526da3d505995c2379b677`, 전체42 compiler→ExpressionAssets1compile/sync1·41동일→15초 Play Luau오류0. [몬스터 실제 증거](../monster_new_account/README.md)는 두 모델의 정상 게임 Native 재확인과 Brute의 초기 회색 실패/미확정 원인을 구분한다. Native Vulkan→Automatic 최종 복원·전체 요청 완료 뒤 종료·무료 초기화 사용0은 유지한다.

## 이전 FaceUnionBinding HOLD 및 legacy 증거

아래1/18/HOLD는 새 MouthRestored 승격 전 판정이다. 기존 source/Native/실패는 보존하며 현재 상태는 위2/18을 따른다.

현재 실제 게임 적용 가능 아바타는 **1/18종**, 기존 빛 기사 남 강체 리그다. 이전 궁수 registry 모델은 보존하되 BindingSchema1 미달로 gate에서 거절하고, RigReady/Animation/Skin/ExpressionRuntime=false와 PendingSkinBindingRepair=true를 기록했다. 새 FaceUnionBinding 후보는 실제 표면 변형·생명주기·표정 이벤트를 통과했지만 Serious 입3D홈의 웃는 음영 때문에 **외형 HOLD·Pending·Ready0**이다.

## 내부 연결 오류 정정

원래 Import의 내부 Motor 연결을 지우고 모든 mesh/BoneHost를 다른 Model인 Character.HRP에 직접 Weld한 기존 graph는 같은 CostumeSkin 내부 스킨 연결을 끊었다. 기존2표면 궁수/중립 전사 여 및 cap3표면 궁수의 실제 Bone 프레임 오차·Preload Success·attribute/표정 전환은 그 숫자/상태만 검증하며 **실제 피부 표면 변형을 증명하지 않았다**. 고정 큰 HurtBig에서 Bone은 움직이고 Native 얼굴/팔은 거의 정지했으며, 내부 RootPart↔3Mesh 연결을 넣자 실제 표면이 움직였다. 이전 성공/실패/승격 원본은 삭제하거나 바꾸지 않았다.

새 연결은 모델 `HHC_SkinBindingSchema=1`, CostumeSkin의 `HHC_SkinBindingHost` ObjectValue→실제 RootPart, 외부 RootWeldConstraint1개와 같은 CostumeSkin 안 host→3Mesh InternalWeld3개다. C0는 원래 bind 상대값/C1 identity이고 원본 계층/메시/UV/PNG/Bone SHA를 유지한다. [Roblox 공식 Bone 계약](https://roblox.github.io/avatar-evolution/api/class/Bone)은 연결된 같은 Model의 Bone을 사용하며 자식 Model을 별개로 취급한다.

## 증거 범위

| 대상 | 실제 구조 검사 | 실제 생산 모듈 Play | 현재 상태 |
|---|---|---|---|
| 빛 궁수 남 원래2표면 | 23Bone·2Mesh·15proxy·15Motor·외부3weld,595검사 | 누적2059프레임·fault0·기록 최대0.00022694stud | 과거 수치/Preload 증거만; 피부 변형 증거 아님; 원본 보존 |
| 중립 전사 여 원래2표면 | 15Bone·2Mesh·15proxy·15Motor·외부3weld,455검사 | 누적2247프레임·fault0·기록 최대0.0000080252stud | 과거 수치/Preload 증거만; 내부 연결/최종표정 QA 필요; Pending |
| 빛 궁수 남 cap3표면 legacy | 23Bone·3Mesh·15proxy·15Motor·외부4weld,628검사 | 누적2495프레임·fault0·기록 최대0.000338063stud | 과거 승격 기록 보존; 현재 gate 거절/marker false |
| 빛 궁수 남 FaceUnionBinding3표면 | 23Bone·3Mesh·15proxy·15Motor·root1/internal3,690검사·Shared19검사 | 누적2488프레임·fault0·기록 최대0.0002483197stud | Native 큰 HurtBig 실제 얼굴/팔 변형 확인; 입 외형 HOLD/Ready0 |

628검사 성공은 **루트 실제 실행 보고**다. 별도 matcher 응답 파일은 복사하지 않았으며 `evidence_index.json.root_report_only`에 그 차이를 명시했다. 나머지595/455검사는 실제 응답 원본의 복사본이다. 뼈 위치 정합 오차는 driver 동기화 검사이며, 활·손·무기/옷/얼굴의 모든 동작 품질 승인으로 쓰지 않는다.

기계적 Play 기록들은 실제 UI 선택·걷기/점프·F/Q·JusticeService 성장1→2→1·OFF 원래 아바타/driver 해제·ON 재연결·사망 재생성을 포함한다. 성장 목표 배율은 Play-only 진영 설정으로 준비하고 실제 JusticeService가 적용했다. 원래2표면 두 모델의 실제4에셋과3표면의 실제6에셋/별도 표정 로딩 Success는 에셋 로딩 증거다. 실제 표면 변형은 새 Binding 후보의 Native 진단이 추가로 확인했다. 모두 단일 클라이언트 기록이며 새 Edit 후보 marker는 false, trial marker는 Play-only clone에만 넣었다.

legacy3표면 Edit1→2→1 구조 계약은 `halo_archer_m_expression_promotion_actual.json.scale_contract`의 과거 기록이다. 승격의 `qa_sha256`는 수정 전 실제 mechanics 원본 SHA를 가리킨다. 공격/피격 진지·대화 미소·피격 우선·대화 복귀·기본 복귀·OFF 얼굴 없음·ON/리스폰 기본은 상태 전환 기록으로 보존한다. 새 Binding 후보도 해당 실제 이벤트를 다시 통과했으며 Shared 계약의 Scale1→2→1/16개 부정 상황과 강화 matcher690 응답을 별도로 보관했다.

## 파일

- `halo_archer_m_two_surface_*`와 `neutral_warrior_f_two_surface_*`: 실제 Import 전체 Bone/메시 계층, 조립, matcher, 생산 모듈 Play.
- `halo_archer_m_expression_import_actual.json` 및 `halo_archer_m_expression_importer_ledger_actual.json`: 최종3표면의 실제 원본 ID/23Bone/6참조, 정확한 GLB SHA, 완료 기록. 네이티브 최대7에셋+별도 표정2PNG=전체9개다.
- `halo_archer_m_expression_mechanics_actual.json`: 최종3표면 실제 Play 기계·표정·로딩·생명주기 기록.
- `halo_archer_m_expression_promotion_actual.json`: `ServerStorage.CostumeRigs.Costume_HaloArcherM` 승격과 Pending 보존, 원본GLB/QA SHA,3표정 ID/Face MeshId.
- `halo_archer_m_face_union_import_actual.json`, `halo_archer_m_face_union_importer_ledger_actual.json`, `halo_archer_m_face_union_inspection_actual.json`: 원래 얼굴438면/새 정점·덮개0 GLB SHA `77a99d60…`, 실제3Mesh/23Bone/6참조 및 inspect SHA `b0a80449…`. 기존 원본 및 cap import 기록과 다른 별도 회차다.
- `halo_archer_m_face_union_binding_assembly_actual.json`, `halo_archer_m_face_union_binding_matcher_actual.json`: 별도 `_FaceUnionBindingSkinSchema2Candidate` 조립/690검사, BindingSchema1·root1/internal3·Ready/Runtime/Animation=false. Import/검사 SHA는 원본파일 참조다.
- `skin_binding_contract_actual.json`: Shared 실제19검사. 같은 Model 내부 연결·Scale1→2→1은 허용하고 누락 schema/참조·옛 외부 graph·child Model·잘못된 C0/중복·물리설정은 거절했다. 임시 clone 제거/source 변경0.
- `halo_archer_m_face_union_binding_mechanics_actual.json`: 새 Play-only 후보의2488프레임/기계·3표정·로딩·성장·생명주기 기록. Edit 후보는 승격하지 않았다.
- `halo_archer_m_face_union_binding_held_hurt_actual.json`과 `*_binding_*_native.jpg`: 새 내부 연결의 고정 큰 HurtBig/표정 화면과 진단 상태. Serious 입3D홈/웃는 음영 외형 문제를 보존한다.
- `*_initial_matcher_failed.txt`: 첫 matcher가 WeldConstraint를 일반 Constraint로 세어 실패한 실제 원문. 수정 후595/455 통과와 함께 보존한다. 확장자가 `.json`이던 원본은 JSON이 아닌 오류 문자열이라 복사본은 `.txt`다.
- `halo_archer_m_initial_direct_scale_failed.json`: 최초 직접ScaleTo2 probe가 실제 JusticeService의 정상 배율 복귀와 충돌한 이전 기록. 이후 실제 JusticeService 성장 검증이 이를 대체한다.
- `evidence_index.json`: 모든 복사본의 원래 workspace 경로/원본 SHA/복사본 SHA/사용자 ID 제거 개수. 원본을 수정하지 않았다.

중첩 JSON 문자열의 `user_id`/`UserId`/`userId`도 제거했다. 따라서 일부 mechanics 복사본 SHA는 원본과 다르다. 기존 matcher의 `inspection_sha256`와 승격의 `qa_sha256`는 원본 파일 SHA이며, privacy 처리가 끝난 파일의 SHA로 덮어쓰지 않았다.

## 화면 해석

[기본 얼굴](../halo_archer_m_skin_expression_neutral_actual.jpg), [미소 얼굴](../halo_archer_m_skin_expression_softsmile_actual.jpg), [진지 얼굴 확대](../halo_archer_m_skin_expression_serious_close_actual.jpg)는 **Play-only API로 지속해 UV 확인한 화면; 원래 이벤트 전환은 별도 실제 QA**다. 화면을 찍기 위해 표정 상태를 지속했으므로 그 JPEG만으로 원래 공격/대화 시간·우선순위를 증명하지 않는다. 원래 이벤트 전환 증거는 mechanics 기록에 있다.

[작은 정면 스냅샷](../halo_archer_m_skin_front_actual.jpg)과 [공격 후 스냅샷](../halo_archer_m_skin_after_attack_actual.jpg)은 정밀모션 증거가 아니다. Native/HurtBig 추가 화면과 원본보존 개선 후보는 별도 검증 후 기록한다.

새 Binding 후보의 [고정 HurtBig](halo_archer_m_face_union_binding_hurtbig_native.jpg), [기본](halo_archer_m_face_union_binding_neutral_native.jpg), [진지](halo_archer_m_face_union_binding_serious_native.jpg), [미소](halo_archer_m_face_union_binding_softsmile_native.jpg) 역시 **Play-only API로 지속해 UV 확인한 화면; 원래 이벤트 전환은 별도 실제 QA**다. HurtBig는 Animator를 identity로 둔 key0.06 진단 고정이며 실제 피부 변형을 확인하는 화면이다. 이벤트 전체 타이밍/모든 자세/최종 얼굴 품질 완료를 의미하지 않는다. Serious에도 입3D홈 웃는 음영이 보여 승격을 보류했다.

최신 루트 저장 보고는 **2026-10-04 04:47:24 KST / 11,265,486바이트** 및 place 동일 복사,42파일 compiler PASS/4변경·38동일 sync/15초 Play Luau 오류0다. 옛 몬스터 에셋 warning, 나머지17종·전체18모션/무기·HUD/상점 선택·닉네임 영속 등은 남았다. 몬스터 preflight는 metadata 준비만 했으며 실제 새 업로드/색/PBR 변경0이다. Native Vulkan→Automatic 최종 복원과 전체 완료/저장/커밋push 후 종료 조건, 무료 초기화 실제 사용0을 유지한다.
