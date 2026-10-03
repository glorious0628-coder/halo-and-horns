# 2026-10-04 아바타·표정 실제 체크포인트

게임용 아바타는 성기사 남성 **1/18종**이다. 이번 변경은 해당 아바타의 기본·진지·미소 표정 연결과 나머지 코스튬의 준비 작업이다.

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

HUD/물약 상점 선택, 나머지17아바타와 전체18종 무기/모션·표정, 몬스터 새 계정 복구, DataStore·다인 QA를 계속한다.
