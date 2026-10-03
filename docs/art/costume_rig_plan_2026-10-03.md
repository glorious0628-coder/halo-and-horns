# 직업 아바타 리깅 실행안 — 2026-10-03

기존 18개 모델을 움직이는 R15 아바타로 연결한다. 새 그림/3D 생성은 하지 않는다. 성기사 남성 pilot을 먼저 리깅했고 사용자가 나머지 **17종 전부/최대425크레딧** 진행도 추가 승인했다. 실제 유료 리깅은 신규10종250크레딧으로 종료했다. 게임용 등록은 각 리그의 걷기·점프·전투·OFF 복귀 검증 후에만 한다. 실패/미지원 모델은 자동 유료 재시도를 하지 않는다.

## 최신 결과 (아래 최초 실행 기록보다 우선)

- 나머지17종 중13종325,원본 보존 무료 재검사 뒤 HaloWarriorF/HaloMageM/HaloMageF3종 최초25씩75추가. 전체 실제440,API잔액4560. 승인상한425와 실제325구분.
- 3종 rig ID: HaloWarriorF `9e168902-6a36-4220-9bcd-732502cfd0a2`,HaloMageM `6a773fc7-2504-42a7-9b1f-a6a58c282f50`,HaloMageF `aa27d070-7d4c-479a-b606-dce7e7c61903`. 실제 GLB/ledger 저장. Tripo가 HeadMat을 BodyMat으로 합친 오류 발견으로 이3종 업로드는 원본 UV/재질 복원까지 보류한다.
- HaloArcherF/HornsArcherF/NeutralWarriorF/NeutralArcherM4종은 merged 및 원본raw 무료 검사 모두false/청구0. 수동가능성 조사,유료 재요청/재생성0.
- HornsMageM/F·NeutralArcherF·악궁수Head112면 로컬 보정은 원본 표면/UV/normal을 보존했다. 게임용 등록은 성기사 남성 **1종**만. 기본ON·B메뉴OFF/ON·걷기/점프/FQ기본·진짜죽음후ON 및 원본복귀밀림 해결을 실제 확인했다.
- 현재 상세증거는 `costume_checkpoint_2026-10-03.md`를 따른다. 아래10종250/7무료거절/OFF실패/20:07 문장은 최초 라운드의 역사이며 현재 값이 아니다.

## 최초 실행 기록

## 모델마다 실행할 API 순서

1. `POST /v3/animations/rig-check`: 아래 기존 작업 ID를 `input`으로 전달. 무료. `riggable=true`, `rig_type=biped`일 때만 다음 단계.
2. `POST /v3/animations/rig`: 같은 기존 작업 ID, 모델 별칭 `rig-v1.0` / 실제 값 `v1.0-20240301`, `rig_type=biped`, `spec=mixamo`, `out_format=glb`. 25크레딧.

`py tools/tripo_api.py rig <task_id> Costume_<name> --dry`로 요청 검증 완료 후 승인된 범위만 실행한다. 도구는 재생성·텍스처 변경·애니메이션 유료 요청을 추가하지 않는다.

## 입력

원본 대응 파일: `art/models/costume/fixed/Costume_<name>.glb`. 18개 프리뷰를 직접 확인했으며 옷차림은 단정하다. 아래는 옛 생성 작업 번호이다. 새 계정에서 기존 fixed GLB를 무료로 다시 import한 작업 ID로 검사·리깅했다. 실제 새 import/rig-check/rig ID와 결과는 `art/models/tripo/records.json`을 따른다.

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
- Roblox 3D Importer로 배치당 실제 항목 수 ≤10을 확인하며 가져와 `ServerStorage.CostumePendingRigs.Costume_<name>`에 조립·테스트한다. 모든 검증 통과 후에만 `CostumeRigs`로 승격한다. 정적 코스튬은 `CostumeModels`에만 보관한다.
- 1종 무료 검사+유료 리깅25크레딧. 나머지17종의 **사용자 승인 상한425**와 **실제 청구250**을 구분한다. 신규10종은 리깅 완료,7종은 무료 검사에서 biped/riggable=false로 거절되어 유료 요청0/청구0이다.
- 코스튬 실제 청구는 pilot25+신규250=**275**. 옷 입힌 해골30+왕60까지 합친 누적 실제 청구는 **365**, 마지막 확인 API 잔액은 **4,635**다. 거절/Unknown 작업을 자동 재요청하지 않으며 루트만 API ledger를 쓴다.

## 신규 17종 실제 결과

`tools/costume_r15/rig_batch.py`는 완료/거절 기록 뒤 자동 유료 재요청을 하지 않는다. 무료 거절7종은 루트의 읽기 전용 GET 감사 `build/costume_r15/rejected_7_readonly_audit.json`으로 재확인했다.

| 결과 | 모델 | 후속 상태 |
|---|---|---|
| 유료 리깅 완료·strict R15 변환 완료(8종) | HornsWarriorM, HornsWarriorF, HaloArcherM, HornsArcherM, NeutralWarriorM, NeutralMageM, NeutralMageF, NeutralArcherF | 로컬 파일 준비만 완료; 신규 Roblox 업로드/동작 검증은 미완료 |
| 유료 리깅 완료·변환 보류(2종) | HornsMageM, HornsMageF | 아래 원인 해결 전 자동 변환/등록 금지 |
| 무료 검사 거절(7종) | HaloWarriorF, HaloMageM, HaloMageF, HaloArcherF, HornsArcherF, NeutralWarriorF, NeutralArcherM | biped/riggable=false; 유료 리깅 요청0/청구0 |

- 8종은 각 `build/costume_r15/Costume_<name>/`에 15부위·15관절과3개 import 배치를 준비했다. dry 검사 후 live 로컬 변환했으며 원본 SHA256/UV/내장 이미지 바이트 보존, 배치별 메시+이미지+wrapper 항목 수≤10을 확인했다. 기존 출력/원본을 덮지 않았다. 낮은 신뢰 웨이트가 남는 모델은 실제 관절·의상 찢어짐 검증이 필요하다.
- HornsMageM: Body face622의 정점이 Head/LeftArm/LeftForeArm에 나뉘어 평균 가중치가 동률이다. Head와 LeftUpperArm의 parent-depth도 같아 이름 순서 선택을 근거로 live 변환하지 않았다. `build/costume_r15/dry_checks/HornsMageM_tie_face622.json`과 dry 결과만 보관한다.
- HornsMageF: LeftLowerArm 분할이 비어 strict 검사에서 중단됐다. 임의 관절/메시를 만들거나 빈 부위를 정상으로 처리하지 않는다.
- 무료 거절7종의 메시/포즈/다중 오브젝트 구조 원인 분석은 보류다. 원본 보존한 구조 검토부터 하고 무료 재검사는 루트가 담당한다. 새 디자인/의상 변경/3D 재생성/유료 재리깅은 시작하지 않았다.

## 실제 pilot 실행 기록

`art/models/tripo/records.json`의 완료 이벤트를 기준으로 한다. API 키는 `.env` 밖에 기록하지 않는다.

| 단계 | 실제 작업 ID | 완료/청구 |
|---|---|---|
| 옛 작업 입력 검사 | `3435677c-a096-4a5e-88e2-647aadf9fc8b` | 접근 실패 기록; 완료 유료 리깅으로 집계하지 않음 |
| fixed GLB 무료 import | `af2c7c6e-e1cb-4b82-be54-e725e475468e` | 완료 / 0크레딧 |
| rig-check | `c38a6735-52aa-41df-8369-d66a6b19184d` | biped, riggable=true / 0크레딧 |
| Mixamo GLB rig | `117c8bcf-b2f2-4c24-a95c-dc420db14658` | 완료 / 25크레딧 |

- 결과 파일: `art/models/tripo/Costume_HaloWarriorM_rig_117c8bcf-b2f2-4c24-a95c-dc420db14658.glb` (3,932,968바이트).
- 로컬 R15 분할/관절/3개 import 배치는 `build/costume_r15/Costume_HaloWarriorM/`에 준비했다. 이후 **3묶음18메시 모두 파일 Importer로 가져와 `CostumePendingRigs`에 실제 조립**했다. 기본 Animate/걷기/점프/F·Q 관절 움직임/죽음 뒤 ON 재생성을 확인했다.
- **OFF는 소유자 외형으로 돌아오지만 여전히 밀림/날아감이 남아 `CostumeRigs` 승격0종**이다. 높이 보정·OFF 원본 root.CanCollide 보존 이후 실제 Play도 실패했다. ownership 실험은 실패하여 소스를 되돌렸다. 코스튬 물리 오프라인86개 검사 통과는 실Play 성공과 구분한다. 위치/속도·원본 RigType·HP/MP/물약CD·보호/이동 검증 상태까지 통과해야 한다.
- Halo/Mage/F의 MissingTemplate와 당시3개 폴더 부재는 이전 진단이다. 현재 검증 R15 controller와 pilot 대기 리그가 있다. 다른 직업의 템플릿 누락은 계속 기존 아바타로 표시하며 ON 선택값만으로 적용 완료라고 하지 않는다.
- Batch01 임시 clone의 9개 에셋 로딩과 얼굴·눈·갑옷 텍스처는 나중에 성공 확인했다. 이 확인은 움직이는 코스튬 완성 확인이 아니다. 화면: `verification_2026-10-03/costume_texture_studio.jpeg`.
- 기본 R15 Animate 원본은 캡처·검사·engine Source 바이트 일치 및 vendor 저장 후 **root가 --apply 실제 설치·검증 완료**했다. 대상 `ServerStorage.CostumeAnimationControllers.R15`, 전체61노드/Source28,802자, SHA256 `49eab7530cfc33b8af13b995ae1fa87f482a489b6d108ec2410d12dd19b720f0`. `build/costume_r15/animate_install_20261003T073704Z_4ef76cd9.json` complete 기록과 일치한다. controller 설치와 게임용 코스튬 승격은 별도다.
- EditableMesh 무료 원본 검사는 통과했다: 기존 LeftLowerArm431면/UV 오차0/위치 최대 오차1.237e-7, LeftLowerLeg850 vertices/596 faces/모든 오차0. 실제 `CreateAssetAsync`1회는 **"CreateAssetAsync and CreateAssetVersionAsync are not available yet"** 예외로 현 Studio 미지원이 확인됐다. **이 API 경로의 성공0/재시도0**와 ledger Unknown은 보존한다. 이후 파일 Importer의18메시 성공과 구분하며 해당 API를 반복하지 않는다.
- 최신 기록된 기본 검증은 **39 Luau 문법·sync22/17·15초 서버23/23/클라이언트9·Luau 오류 없음**이다. 닉네임 오프라인790개와 실제 입력/Unavailable/재오픈 보존도 이후 통과했다. Toast 겹침 수정 재검증, 키1/2·MP 부족·리스폰/외형 교체 자원 보존·최종3직업 모션은 남아 있으며 임시 무기/활 모션도 미충족이다. 이후 최신 소스는 다시 Studio 검증·저장한다.
- 비용 최신값은 **누적365/잔액4,635**다. 나머지17종 승인 상한425, 실제 리깅10종250, 무료거절7종0을 섞어 쓰지 않는다.
