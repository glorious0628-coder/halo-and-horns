# 직업 아바타 리깅 실행안 — 2026-10-03

기존 18개 모델을 움직이는 R15 아바타로 연결한다. 새 그림/3D 생성은 하지 않는다. 성기사 남성 1종부터 검사하고 실제 걷기·점프·전투·OFF 복귀가 통과하면 나머지 17종을 처리한다. 실패/미지원 모델은 추가 유료 재시도를 하지 않는다.

## 모델마다 실행할 API 순서

1. `POST /v3/animations/rig-check`: 아래 기존 작업 ID를 `input`으로 전달. 무료. `riggable=true`, `rig_type=biped`일 때만 다음 단계.
2. `POST /v3/animations/rig`: 같은 기존 작업 ID, 모델 별칭 `rig-v1.0` / 실제 값 `v1.0-20240301`, `rig_type=biped`, `spec=mixamo`, `out_format=glb`. 25크레딧.

`py tools/tripo_api.py rig <task_id> Costume_<name> --dry`로 요청 검증 완료 후 승인된 범위만 실행한다. 도구는 재생성·텍스처 변경·애니메이션 유료 요청을 추가하지 않는다.

## 입력

원본 대응 파일: `art/models/costume/fixed/Costume_<name>.glb`. 18개 프리뷰를 직접 확인했으며 옷차림은 단정하다. 아래는 옛 생성 작업 번호이다. 새 계정 API에서 옛 작업이 접근되지 않아 성기사 남성 pilot은 기존 fixed GLB를 무료로 재등록한 새 import ID를 사용했다. 나머지 종도 바로 유료 리깅하기 전에 입력 접근 가능 여부를 확인한다.

| 이름 | 기존 작업 ID |
|---|---|
| HaloWarriorM | 3435677c-a096-4a5e-88e2-647aadf9fc8b |
| HaloWarriorF | 8192120d-b75f-4f34-ae97-240b84cb5a56 |
| HaloMageM | 931710ee-8ed4-4736-80a9-02eaed4b2328 |
| HaloMageF | 704e9887-f85a-4504-af1d-396dbaeb869f |
| HaloArcherM | 709d9a90-52e5-4aa0-be80-16f8269a68a6 |
| HaloArcherF | 2ea94b7b-31ed-413b-bb1f-a95014da031a |
| HornsWarriorM | 21c3404a-7521-47f5-9684-81460ca247c7 |
| HornsWarriorF | 02e6ac45-6c1d-468f-baf0-d4e07d273365 |
| HornsMageM | f4181c89-2bbb-449b-8335-d66e494a3ddb |
| HornsMageF | 7825655c-3f1c-4cf5-ae79-3e388f6e5125 |
| HornsArcherM | fa364d62-eed1-44bc-86dc-331e66da64a8 |
| HornsArcherF | 02d21788-5eaa-48dd-87f8-c607af2ed8ca |
| NeutralWarriorM | 071d4ef5-47de-4fa8-8a61-a2fb6775d86f |
| NeutralWarriorF | f8a8ce4b-a236-4a32-ac3b-d684be63b50b |
| NeutralMageM | 87d0d364-98fd-4014-97d3-accc0e3f0259 |
| NeutralMageF | d06a8ba9-17cb-42f7-a070-14d7462bf27b |
| NeutralArcherM | e96a2129-0e0d-4bb4-87ea-49a2a1bb07b5 |
| NeutralArcherF | b77b3ede-d7c4-4dff-ac8e-b20e3bed4e81 |

## 결과와 비용

- 리깅 파일: `art/models/tripo/Costume_<name>_rig_<rig_task_id>.glb`와 `records.json`. 기존 파일은 보존한다.
- 이후 Blender에서 실제 뼈 가중치로 R15 15부위와 관절 JSON을 만든다. 로컬 처리에는 Tripo 비용이 없다.
- Roblox 3D Importer로 작은 배치로 가져와 `ServerStorage.CostumeRigs.Costume_<name>`에 조립하고 테스트한다. 정적 코스튬은 `CostumeModels`에만 보관하며 플레이어 리그로 사용하지 않는다.
- 1종: 무료 검사 + 25크레딧(약 $0.25). 18종 전체: 무료 검사 18회 + 25 × 18 = **최대 450크레딧(약 $4.50)**. 실패·취소 작업은 환불 규칙을 적용한다. 실제 청구량과 잔액은 실행 결과로 다시 기록한다.
- 사용자 API 연결/충전과 인간 코스튬 진행 지시는 확인했다. 성기사 남성 pilot 리깅 **25크레딧 청구 완료**, 나머지 17종은 **425크레딧 계획**이며 아직 실행하지 않았다. 모든 18종 비용 범위가 명시 승인됐다는 근거는 이 기록에 없으므로 추가 실행 전 대화의 승인 범위를 확인한다.

## 실제 pilot 실행 기록

`art/models/tripo/records.json`의 완료 이벤트를 기준으로 한다. API 키는 `.env` 밖에 기록하지 않는다.

| 단계 | 실제 작업 ID | 완료/청구 |
|---|---|---|
| 옛 작업 입력 검사 | `3435677c-a096-4a5e-88e2-647aadf9fc8b` | 접근 실패 기록; 완료 유료 리깅으로 집계하지 않음 |
| fixed GLB 무료 import | `af2c7c6e-e1cb-4b82-be54-e725e475468e` | 완료 / 0크레딧 |
| rig-check | `c38a6735-52aa-41df-8369-d66a6b19184d` | biped, riggable=true / 0크레딧 |
| Mixamo GLB rig | `117c8bcf-b2f2-4c24-a95c-dc420db14658` | 완료 / 25크레딧 |

- 결과 파일: `art/models/tripo/Costume_HaloWarriorM_rig_117c8bcf-b2f2-4c24-a95c-dc420db14658.glb` (3,932,968바이트).
- 로컬 R15 분할/관절/3개 import 배치는 `build/costume_r15/Costume_HaloWarriorM/`에 준비했다. Studio에는 Batch01 **7 MeshPart만** 들어왔으며 나머지 배치/전체 R15 조립/걷기·점프·전투·OFF 복귀 검증은 미완료다.
- 마지막 실제 플레이 진단은 Halo/Mage/F, ClassChosen=true, CostumeEnabled=true이지만 CostumeStatus=MissingTemplate. 당시 `CostumeRigs`, `CostumePendingRigs`, `CostumeAnimationControllers`가 없었다. 이후 R15 Animate만 설치됐으며 **플레이 가능한 코스튬은 여전히 0개**.
- Batch01 임시 clone의 9개 에셋 로딩과 얼굴·눈·갑옷 텍스처는 나중에 성공 확인했다. 이 확인은 움직이는 코스튬 완성 확인이 아니다. 화면: `verification_2026-10-03/costume_texture_studio.jpeg`.
- 기본 R15 Animate 원본은 캡처·검사·engine Source 바이트 일치 및 vendor 저장 후 **root가 --apply 실제 설치·검증 완료**했다. 대상 `ServerStorage.CostumeAnimationControllers.R15`, 전체 61노드/Source 28,802자, SHA256 `49eab7530cfc33b8af13b995ae1fa87f482a489b6d108ec2410d12dd19b720f0`. `build/costume_r15/animate_install_20261003T073704Z_4ef76cd9.json` complete 기록과 일치한다. 움직이는 코스튬은 여전히 0개다.
- EditableMesh 무료 원본 검사는 통과했다: 기존 LeftLowerArm 431면/UV 오차 0/위치 최대 오차 1.237e-7, LeftLowerLeg 프리뷰 850 vertices/596 faces/모든 오차 0. 실제 `CreateAssetAsync` 1회는 **"CreateAssetAsync and CreateAssetVersionAsync are not available yet"** 예외로 현 Studio 미지원이 확인됐다. 새 메시 업로드 성공 **0개**, 재시도 **0회**. `build/costume_r15/Costume_HaloWarriorM/editable_upload_ledger.json`의 Unknown을 보존한다. 해당 API를 반복하지 말고 파일 Importer로 나머지 Batch02/03 **11조각**을 가져와 조립·플레이 검증한다.
- 코스튬 대기/검증 controller fallback/설치 자동 재시도·메뉴 표시, 승인 `Motion_Class_Attacks_A.png`의 3직업 모션과 `UI_HUD_Vitals_A.png`의 HP/MP·물약(A18/A19) 반영 후 **36 Luau 문법·sync0/36·15초 서버21/21/클라이언트9·Luau 오류 없음**을 확인했다. 물약 UI 회복/재클릭 CD 유지도 통과했다. 적용할 리그가 아직 없으므로 코스튬 ON/OFF 움직임이나 자원 보존 검증은 아니다. 키1/2·MP 부족/리스폰·외형 교체 보존·3직업 모션 최종 검증은 남아 있다.
- 해골 30+왕 60+pilot 25 = **실제 총 115크레딧**, 마지막 확인 API 잔액 **4,885**. 무료 단계는 위 표와 같다. 나머지 425를 사용한 것으로 쓰지 않는다.
