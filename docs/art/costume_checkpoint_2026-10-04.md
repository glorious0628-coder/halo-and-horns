# 2026-10-04 아바타·표정 실제 체크포인트

## 최신 무료 눈 검사와 양눈 기본 표정

- fixed18·최신 얼굴후보18·몬스터9·기존 SharpD2, 총47 GLB의 원본/텍스처 SHA와 렌더를 재확인했다. 아바타18종 모두 눈 경계 번짐·거침이 남는다. `verification_2026-10-04/all_3d_eye_audit/` 참조.
- 생산궁수의1254 얼굴은 GPT원본 바이트와 같지만 원본부터 흐리다. 얼굴 고유155704픽셀/9.9016%. raw2048→fixed머리1024의 얼굴 선형 텍셀밀도는69.8559%다. 실제 Automatic/Level21 × 기본12.5/근접3.5stud 캡처에서도 번짐이 남았다.
- 실제 Roblox5텍스처의 EditableImage 결과는1024×1024이나 API제한이 있어 원격저장 원본크기/압축률은 미확정이다. `face_sharpness_audit/`와 `face_runtime_audit/`의 수치/비교/실패 기록을 보존한다.
- 기본 윙크를 없앤 E는 눈 불균형으로 거절, 양눈 균형 F를 사용자 “좋아, 이걸로 해줘”로 승인했다. 승인 F의 원본 픽셀을 직접 쓰는 로컬 얼굴UV/표면 후보는 준비 중이며 생산 교체는 아직0이다. 다른17종은 파일럿 사용자OK 뒤 진행한다.
- 프로필은 최신 요청대로 실제3D ViewportFrame이다. 초기 표시/OFFON/성별fallback/리스폰은 실제 확인했으나 작고 흐리다는 사용자 지적으로 카메라 확대를 추가 수정 중이다. F2D업로드1장 ID130781962577620은 이력만 보존한다.
- 기존 SharpD8K 생성·리그가 이미 존재하며 눈이 더 선명하다. 이번 세션 유료 Tripo0/크레딧0, 아바타 등록수2/18 유지. 아래 과거 저장·완료기록은 당시 상태다.

## 최신 작업 상태 (2026-10-04 05:56 MouthRestored 실제 생산 승격)

- **현재 게임용 아바타는 2/18종**이다. 성기사 남성 기존 강체 리그와 빛 궁수 남성 원본23Bone/3표면/BindingSchema1을 실제 등록했다. 남은16종·전체18종 모션/무기·다인 QA는 미완료다. 아래 이전1/18/HOLD 기록은 당시 실패와 후보 증거로 보존하며 현재 궁수는 새 MouthRestored 등록본을 사용한다.
- 새 궁수 GLB SHA `17972af93f7ecd176f96af8db81fdff00c04e055a1d340b9dd9f288196d54584`, 원래 얼굴438면/새 정점·덮개0/Body·UV·JW·23Bone·PNG 보존. 루트가 승인한 입71개 P/N 국소 복원만 exact ledger/manifest SHA로 예외 검증했다. 일반 원본 P/N exact gate는 유지한다. 실제 Import7상황 오프라인1161Python+354Luau, 국소 입 예외 궁수68/마법사68·Union59·기존6표정108검사가 통과했다. 이 로컬 검사는 실제 Native QA를 대체하지 않는다. 마법사347면·입75점 후보는 별도 whitelist/68검사만 통과했고 아직 실제 등록/Native QA 완료가 아니다.
- 실제 새 Import는3Mesh/23Bone/6참조/최대7개, 이전 진지·미소PNG는 exact SHA/ID로 재사용했다. Face Mesh`120232648183385`, 기본`114282379234661`, 진지`130810730029380`, 미소`96983789676579`. 새 Source/별도 Pending 및 이전 union/cap/2표면/강체 후보와 옛 Ready archive는 보존했다.
- 내부 연결은 `HHC_SkinBindingSchema=1`, 같은 CostumeSkin 안 실제 BoneHost→3Mesh InternalWeld3개와 외부 root→host WeldConstraint1개다. 실제 inspect SHA `68787b4a07438f7561bb8393db83d820a56b1e566a7e9dff74332d651eae798d`, **engine matcher691검사 PASS**, 최대 bind 오차0.0000152511stud. 최신 Shared 계약은 실제23검사 PASS이며 disabled/duplicate/이름변경 Neck·schema1·기존 rigid 회귀도 확인했다. 이전19검사는 별도 snapshot으로 보존한다. 기존 외부 graph의 Bone 수치/Preload 성공은 실제 피부 변형 증거가 아니었다는 정정은 유지한다.
- 실제 새 후보 Play **2497프레임/fault0/최대 Bone 오차0.000221093stud**: UI 선택·걷기/점프/F/Q/실제 성장1→2→1/OFF·ON/사망·재연결·3표정/피격·대화 우선순위·로딩을 확인했다. 루트가 Native 기본/진지/미소/큰 HurtBig 네 장에서 원래 입 웃는 홈 제거와 실제 얼굴/팔 변형을 직접 확인하고 생산 CostumeRigs로 승격했다. 단일 클라이언트/진단 고정 pose 범위이며 전체18종 모션 품질 승인으로 쓰지 않는다.
- 승격 후 원래 source로 새15초 Play에서 실제 Halo→Archer 선택만으로 Active/ExpressionReady/new FaceMesh/Binding1을 확인했다. QATrial 없이 생산 경로가 적용됐다. 첫 QA는 UI 초기화 조건 때문에 실패했으며 최종 JSON은 재실행 성공 범위만 보관한다. 그 실패가 없었다고 쓰지 않는다.
- 최신 실제 전체42 Luau compiler PASS→마지막 ExpressionAssets1파일 compile/sync1·41동일→15초 Play Luau 오류0. **2026-10-04 05:56:14 KST /12,071,834바이트**, build/place byte 동일 SHA `6da73478884aebcea934e2dbdb9f931a36c13fa211526da3d505995c2379b677`. 최신 생산 궁수·새 몬스터 Source/CustomModels·ID가 저장됐다.
- **Goblin/GoblinBrute 새 계정 Native 등록·CustomModels 승격·art/models/new_asset_ids.json 기록 및 정상 게임 Native 외형2종 확인 완료**다. Source/옛 모델·ID archive/PBR를 보존했고 높이는 Goblin5/Brute7.5다. Brute 첫 회색·갈색 Native 실패/HOLD는 보존했지만 변경0으로 재확인한 정상 게임에서 초록/원래 갑옷/몽둥이/불투명을 루트가 확인했다. 당시 서버 이동 직후거리13과 실제 Client probe거리597.9/nearbyfalse/Streamingfalse가 달라 근처 이동이 해결 원인이었다고 쓰지 않는다. 회색 원인은 미확정이며 지연 로딩은 추정이다. Mesh instance Success/SA콜백0/맵 문자열4Failure는 구분하고 PBR 제거·재업로드하지 않았다. 나머지 몬스터는 아직 완료가 아니다.
- 증거는 `docs/art/verification_2026-10-04/skin_runtime_v2/`와 `monster_new_account/`의 README/evidence_index를 따른다. 복사본의 중첩 user_id도 제거했고 원본 SHA를 유지했다. Native 표정 JPEG는 **Play-only API로 지속해 UV 확인한 화면; 원래 이벤트 전환은 별도 실제 QA**다. 기존 작은 스냅샷은 정밀모션 증거가 아니다.
- HUD A·물약 상점 GPT 선택/`MerchantEnabled=false` 실제 NPC 구매, 남은16아바타·전체18모션/표정/3D무기, 몬스터 나머지 새 계정 복구/회색 원인 조사, 닉네임 DataStore 영속/다인 QA는 미완료다. Native ActualSize 복원/reset 완료, **GraphicsMode Vulkan→원래 Automatic 최종 복원은 아직 필요**하다. 전체 요청 실제 완료·저장·커밋/push 뒤 종료, 무료 초기화 실제 사용0/자동 유료 구매 없음 조건을 유지한다.

## 이전 내부 연결 체크포인트 (입 외형 HOLD 당시)

현재 실제 게임용 적용 가능 아바타는 **1/18종**, 성기사 남성 기존 강체 리그다. 궁수 legacy 등록본은 보존했지만 BindingSchema1이 없어 새 gate에서 거절한다. 실제 기존 RigReady/Animation/Skin/ExpressionRuntime marker는 false, `HHC_PendingSkinBindingRepair=true`다. 새 FaceUnionBinding 후보는 실제 기계·표면 변형 검증을 통과했으나 Serious의 원래 입3D홈/웃는 음영 때문에 **외형 HOLD·Pending·Ready0**이다. 남은17종과 전체18종 모션 품질은 미완료다.

## 최신 내부 연결 실제 검증과 이전 판정 정정

- 이전 궁수2/3표면과 중립 전사 여2표면의 Bone/driver 오차·Preload Success는 피부 표면 변형 증거가 아니었다. 원래 Import의 내부 Motor 연결을 제거한 뒤 CostumeSkin 밖 Character.HRP로 모든 part를 연결해 같은 Model 내 Bone→메시 연결이 끊겼다. 고정 HurtBig에서 Bone Transform만 바뀌는 문제가 확인됐고, 같은 CostumeSkin 안 실제 RootPart↔3Mesh 직접 Weld를 넣자 Native 얼굴/팔이 즉시 움직였다. 아래 과거 숫자·승격/실패 기록은 그대로 보존한다.
- 새 GLB SHA `77a99d609d0d7264b2931587ce040bc64d27beca262fd33444bbf8fd31c2734e`: 원래 얼굴438면·606참조정점, 새 정점/덮개0, 원래23Bone/원본 P/N/JW/UV·Body/Head 이미지 보존. 3Mesh/23Bone/6참조 실제 Custom Import7개, 정확한 이전 진지/미소PNG2개 재사용으로 전체9개 이하이다. 새 Source는 `CostumeExpressionSkinImports_FaceUnion_v1.Costume_HaloArcherM`이며 원래 cap 후보/Ready/2표면·강체 Pending은 보존했다.
- `CostumePendingRigs.Costume_HaloArcherM_FaceUnionBindingSkinSchema2Candidate`는 `HHC_SkinBindingSchema=1`, `CostumeSkin.HHC_SkinBindingHost`→실제 RootPart, 외부 HRP→host `CostumeSkinRootWeld` WeldConstraint1개와 내부 host→Mesh `CostumeSkinInternalWeld`3개다. C0는 기존 root-relative bind 상대값/C1 identity이며 실제 source/import SHA 변경0이다.
- 실제 inspect SHA `b0a80449285fbe0d56c4cf8351ee2ea5a6175b0d9e757a1e25f05783482c3180`, 강화 engine matcher **690검사 PASS**, 최대 bone 오차 `0.0000152511`stud/축 오차 `0.00000581145`, root1/internal3을 응답에 기록했다. Shared 계약19 Edit 검사도 Scale1→2→1과 누락·외부 graph·child Model·중복결합·잘못된 C0·물리설정 거절을 통과했다. 임시 검사 clone 제거/source 변경0이다.
- 실제 Play-only trial **2488프레임/fault0/최대0.0002483197stud**: UI 선택·걷기/점프/F/Q/실제 JusticeService 성장1→2→1/OFF/ON/사망·재연결·3표정/피격 우선/대화 복귀와 실제6에셋/표정별 메시 로딩 Success를 확인했다. Edit 후보의 Ready/Runtime/Expression/Animation marker는 false이며, 검증 때 Play-only clone에만 trial marker를 넣었다. 이 결과는 단일 클라이언트 후보 검증이다.
- Native 고정 HurtBig에서 실제 얼굴/팔 표면 변형을 확인했으나 **Serious에서도 입3D홈의 웃는 음영이 남아 외형 승격은 HOLD**다. 표현 담당 조사 중이며 아직 게임용 승격/최종 얼굴 품질 승인0이다. 고정 포즈 JPEG와 원래 전투/대화 이벤트 전환을 구분한다.
- CG와 입 주변 ray6개도 모두 FaceExpression으로 같은 원래 입 음영을 재현했다. 루트가 허용한 좁은 입 곡면 P/N 복원은 별도 후보/strict validator·ledger로 준비 중이다. 새 cap/정점 없이 원래 면을 유지하고 Body/UV/JW/23Bone/PNG는 바꾸지 않는다. 원래 P/N exact 검사가 이 후보를 거절하는 것이 정상이며 예외를 기존 manifest/validator에 묵시적으로 섞지 않는다. union v1과 과거 후보는 보존한다.
- [실제 binding matcher](verification_2026-10-04/skin_runtime_v2/halo_archer_m_face_union_binding_matcher_actual.json), [Shared19검사](verification_2026-10-04/skin_runtime_v2/skin_binding_contract_actual.json), [실제 Play](verification_2026-10-04/skin_runtime_v2/halo_archer_m_face_union_binding_mechanics_actual.json), [Native HurtBig](verification_2026-10-04/skin_runtime_v2/halo_archer_m_face_union_binding_hurtbig_native.jpg), [출처/ID 제거](verification_2026-10-04/skin_runtime_v2/evidence_index.json)를 함께 본다. 오프라인 source 검사981 Python+292 Luau와 원본/변조59검사는 실제 시각 QA를 대체하지 않는다.
- 최신 실제 저장은 **2026-10-04 04:47:24 KST/11,265,486바이트/`place` 동일 복사**다. 전체42 Luau compiler PASS→4변경/38동일 sync→15초 Play 런타임 Luau 오류0, 옛 몬스터 에셋 warning은 남았다. Native Vulkan→Automatic 복원·전체 요청 실제 완료/저장/커밋push 뒤 종료·무료 초기화 실제 사용0 조건을 유지한다.

## 이전 legacy 승격 판정 (내부 연결 오류 발견 전)

당시 게임용 아바타 기술적 연결을 2/18로 집계했다. 성기사 강체 리그와 궁수 원본23Bone/3표면 등록 기록은 보존하지만 궁수의 실제 표면 변형 완료 판정은 위 증거로 정정했다. 현재 적용 가능 수는 1/18이며 기존 궁수는 새 gate를 통과하지 못한다.

## 최신 빛 궁수 남성 승격

- 최종3표면 GLB SHA `f23871e89b092cb69eb0547c2c77180ff4150ffbb8593eb47a220ac87aff060a`, 실제 Custom Import3Mesh/23Bone/6에셋 참조. Importer 최대7개+별도 표정2PNG로 전체9개이며 원래2표면 Import/Pending과 강체 Pending을 보존했다.
- 공유 RootPart/Bone 전체 계층을 복제하고 투명 R15proxy15개/15Motor/Root host weld4개로 별도 Pending에 조립했다. 628검사 matcher 통과는 **루트 실제 실행 보고**이며 별도 응답 JSON은 아직 없다. 실제 Import 원본과 준비 payload를 실제 matcher 응답으로 대신하지 않는다.
- 실제 생산 `SkinRetargetClient`로 UI 진영/궁수 선택·걷기/점프·F/Q·JusticeService 성장1→2→1·B메뉴 OFF/ON·사망 재연결을 확인했다. driver 누적2495프레임, 기록 최대 Bone 오차 약`0.000338063`stud, fault0이다. 단일 실제 클라이언트 결과다.
- 기본/진지/미소 실제 메시/텍스처 Preload는 모두 Success. 공격/피격 진지·대화 미소·피격 우선·남은 대화 미소 복귀·종료 기본, OFF 얼굴 없음·ON/리스폰 기본을 실제 이벤트 QA로 확인했다. 표정 ID는 기본`114282379234661`/진지`130810730029380`/미소`96983789676579`, Face mesh`88405558388221`이다.
- 실제 Edit1→2→1 구조 계약은 승격 기록의 `scale_contract`다. `ServerStorage.CostumeRigs.Costume_HaloArcherM`에 승격했으며 Pending을 보존했다. 새 큰 피격 얼굴 패치 경계의 Native 확인과 개선 후보 검증은 별도 진행 중이다.
- [실제 승격](verification_2026-10-04/skin_runtime_v2/halo_archer_m_expression_promotion_actual.json), [실제 기계·표정 QA](verification_2026-10-04/skin_runtime_v2/halo_archer_m_expression_mechanics_actual.json), [실제 Import](verification_2026-10-04/skin_runtime_v2/halo_archer_m_expression_import_actual.json), [원본SHA/개인정보 제거 목록](verification_2026-10-04/skin_runtime_v2/evidence_index.json)을 보관했다.

## 원래2표면 생산 모듈 실제 검증

- 빛 궁수 남성23Bone/2Mesh는 Edit matcher595검사, 실제 driver2059프레임/기록 최대약`0.00022694`stud/fault0을 통과했다.
- 중립 전사 여성15Bone/2Mesh는 Edit matcher455검사, 실제 driver2247프레임/기록 최대약`0.0000080252`stud/fault0을 통과했다. 실제 생산 모듈·걷기/점프/F/Q/성장1→2→1/OFF·ON/사망 재연결·실제4에셋 Preload Success까지 확인했지만, 최종3표면·표정/시각 품질 확인과 Ready 승격은 남았다.
- 처음 matcher의 WeldConstraint 개수 오류와 직접ScaleTo probe 실패는 삭제하지 않고 성공 결과와 함께 보존했다. [증거 범위와 파일](verification_2026-10-04/skin_runtime_v2/README.md)을 따른다. 사용자 ID는 중첩 JSON 문자열까지 제거했고 원래 SHA 참조는 유지했다.
- 얼굴 native JPEG는 **Play-only API로 지속해 UV 확인한 화면; 원래 이벤트 전환은 별도 실제 QA**다. 기존 작은 정면/공격 후 스냅샷은 정밀모션 증거가 아니다. Bone 정합 수치만으로 최종 활 시위·손/무기·옷/얼굴의 전체 동작 품질을 승인하지 않는다.

## 이전 02:09 체크포인트

아래는 성기사 남성1종 Ready와 초기 중립 전사 여성 trial 당시 기록이다. 현재 등록 수·생산 모듈·성장 검증은 위 최신 결과가 우선하며, 이전 실패·검증 범위는 보존한다.

## 성기사 남성 표정

- 새 Head/Face 실제 Importer 5에셋, 별도 진지·미소 2PNG 업로드 완료. 원본 GLB SHA는 `d8000e76a841f1d4675a8dbfc202168ec938551fdcf6e4e6bbeccff41c974611`이다.
- `ExpressionAssets.Costumes.Costume_HaloWarriorM`: 기본 `121674541725480`, 진지 `104677901335263`, 미소 `133057889021878`. 새 Head `89786211556898`, Face `129632625883192`, 원래 Head atlas `96103784237092`다.
- 기존 Head CFrame·Neck C0/C1·부착점·보조 메시를 보존하여 19메시/15Motor로 조립했다. 실제 Import의 Proper 회전 bake와 UV 검증을 사용했다.
- 실제 F 공격과 HP 감소는 진지로 바뀌고 종료 후 기본으로 돌아왔다. 승인된 기존 성기사 복사본의 Play 전용 NPC/G 프롬프트는 미소를 켰다. 대화 중 피격은 진지를 우선하고, 피격 종료 뒤 남은 대화 시간에는 미소, 대화 종료 후 기본이었다. 검증용 프롬프트는 `HoldDuration=0`; 실제 물약 상점 활성·구매 검증은 아니다.
- 실제 B 메뉴 OFF는 원래 계정 아바타로 복귀하며 `FaceExpression`이 없었다. ON·사망 후 재생성은 기본 표정/`ExpressionReady=true`였다.
- 처음의 단순 ID 문자열 Preload에서는 Failure가 나왔다. 이후 실제 MeshPart 및 진지/미소를 넣은 MeshPart의 Preload는 모든 새 메시·텍스처 Success였다. 최초 결과는 보존했으며 재업로드하지 않았다.
- `CostumeRigs.Costume_HaloWarriorM`에 표정 검증본을 승격했다. 이전 Ready는 `CostumeRigArchive.Costume_HaloWarriorM_beforeExpressions_20261004`에 보존했다.

[실제 기본 얼굴](verification_2026-10-04/pilot_expression_neutral_close_actual.png), [전환/우선순위](verification_2026-10-04/pilot_expression_talk_actual.json), [OFF·ON·사망](verification_2026-10-04/pilot_expression_lifecycle_actual.json), [실제 메시 로딩](verification_2026-10-04/pilot_expression_instance_preload_actual.json), [승격](verification_2026-10-04/pilot_expression_promotion_actual.json)을 함께 본다. 빠르게 찍은 공격/미소 사진은 표정 변경의 렌더 지연 때문에 정확한 상태 타이밍을 보증하지 않아 단독 증거로 쓰지 않는다. MCP `screen_capture`는 Edit 화면만 캡처하므로 Play 증거로 쓰지 않았다.

## 나머지 아바타

- HaloArcherM 강체18메시/15Motor/3Weld는 3배치 가져오기와 Pending 조립을 마쳤다. 실제 걷기·F/Q·OFF/ON·사망 복귀는 통과했으나 화면에서 관절 틈/팔 자세 문제가 보여 승격하지 않았다.
- NeutralWarriorF는 원본2메시/2텍스처/14710면을 유지한 연속 skin으로 가져왔다. 공유 RootPart 아래15Bone, 투명 R15proxy15개/15Motor/host weld3개로 Pending 조립했다. 실제4에셋 Preload Success, 걷기·점프·F/Q, OFF/ON·사망 뒤 trial 재연결이 통과했다. 최대 Bone 위치 오차는 약 `1.19e-5`stud였다. 정면 외형도 확인했다.
- NeutralWarriorF는 생산용 driver·다른 클라이언트·성장/괴수 QA 전이므로 Ready가 아니다. [실제 조립](verification_2026-10-04/neutral_warrior_f_skin_assembly_actual.json), [입력](verification_2026-10-04/neutral_warrior_f_skin_input_actual.json), [생명주기](verification_2026-10-04/neutral_warrior_f_skin_lifecycle_actual.json)가 해당 범위다.
- 기존 유료 원본14종과 수동4종의 로컬 연속 skin 후보를 준비했다. 원본 Tripo14종의 실제 Blender6자세/독립LBS는 최대 `1.908e-6`stud였다. HornsMageF 코트/뒤머리, HornsArcherM 망토, NeutralArcherF 땋은 머리의 원래 웨이트 끌림은 추가 교정 중이다. 원본 geometry·UV·PNG·웨이트가 보존됐다는 사실과 최종 동작 품질은 구별한다.
- 로컬 표정 rigid14종42PNG/84프리뷰, manual skin4종은 눈썹 범위 보강 중이다. 실제 게임 표정 완료는 성기사 남성1종뿐이다.

## 저장과 남은 작업

전체39 Luau 문법→source1변경/38동일→15초 Play에서 서버23/23·클라이언트9 모듈이 시작했고 Luau 오류는 없었다. 옛 몬스터 에셋 경고/BigSlime 누락, DataStore API 비활성, Developer Product2개 ID0는 남았다.

실제 GoodEvil 저장은 **2026-10-04 02:09:31 / 9,005,089바이트**이며 `place/GoodEvil.rbxlx`에 복사했다. Play 전용 카메라/NPC/Ready 시험 복제본은 Stop으로 제거됐다. 가져온 모델·Pending·표정 Ready/Archive·소스는 저장됐다.

Studio 엔진 백색 화면 복구를 위해 GraphicsMode를 임시 Vulkan으로 바꿨다. **최종 종료 전에 원래 Automatic으로 네이티브 복원**해야 한다. emulator ActualSize는 복원했으며 컴퓨터 제어는 reset했다. 현재 사용량86%/무료 초기화4회, 사용0이다. 전체 요청 미완료이므로 아직 컴퓨터를 종료하지 않는다.

아래는 03:49 저장 시점의 이전 집계다. 02:09 당시에는 나머지17아바타였고 legacy 궁수 승격 직후16종으로 집계했지만, 현재는 위 binding 정정으로17종이 남았다. HUD/물약 상점 GPT 선택과 `MerchantEnabled=false` 실제 NPC 구매, 전체18종 최종3D무기/모션 품질·나머지 표정, 몬스터 새 계정 복구, 닉네임 DataStore 영속·다인 QA는 미완료다. 궁수 legacy 승격 포함 저장은 2026-10-04 03:49:02 KST / 10,505,779바이트였으며 place/GoodEvil.rbxlx에 동일 복사했다. 당시 Play의 원래 source로 진영/궁수 선택과 기본·공격 진지 전환 상태를 확인했으나 피부 표면 변형 증거는 아니었다. Native Vulkan→원래 Automatic 복원은 종료 전 필수이고 전체 종료 조건 전 Shutdown하지 않는다. 보유 무료 초기화 실제 사용은0회다.


현재 무료 초기화 사용0회, 남은 사용량80%다. 원본14+수동4의 오프라인 FK/무기 수학 검사는18/18 및5671검사 통과했으며, 실제 Studio 모션 품질 완료는0종 판정이다. `weapon_motion_offline_schema2.json`에 과거 잘못된 목표 거리 진단과 실제/오프라인 경계를 보존했다.
