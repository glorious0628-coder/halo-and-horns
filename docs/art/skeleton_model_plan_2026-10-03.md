# 옷 입힌 해골 3D 실행안

사용자 선택: 해골은 옷을 입히고, 고블린·우두머리는 기존 모습 그대로. 슬라임은 변경하지 않는다.

입력은 대화에 표시한 GPT 수정 그림이며 새 계정 업로드 전 결과를 다시 직접 확인한다.

| 대상 | 입력 | 설정 | 예상 비용 |
|---|---|---|---|
| Skeleton | `art/out/Skeleton_Clothed.png` | monster: 12,000 faces, standard texture | 30크레딧 |
| SkeletonKing | `art/out/SkeletonKing_Clothed.png` | boss: 20,000 faces, detailed texture/geometry | 60크레딧 |

모델: H3.1 / 별칭 `v3.1`, API 값 `v3.1-20260211`. 텍스처 `v3.5-20260815`, 원본 그림 정렬, PBR 꺼짐, delight 꺼짐. 리깅·리타깃·유료 변환은 추가하지 않는다.

각 대상의 API 순서:
1. `POST /v3/files`: 검토된 PNG만 업로드, 무료.
2. `POST /v3/generation/image-to-model`: 위 설정으로 3D 생성, 각각 30/60크레딧.
3. `GET /v3/tasks/<id>`: 무료 조회·GLB/미리보기 다운로드.

결과: `art/models/tripo/SkeletonClothed_raw.glb`, `SkeletonKingClothed_raw.glb`, 미리보기 PNG 및 `records.json`. 기존 파일 보존. 재시도 없음. 실패·취소는 비용 환불 규칙 적용.

사용자는 옷 입힌 해골·왕의 **90크레딧 범위** 실행을 승인했다. 두 생성은 완료했으며 실제 청구는 예상과 같은 **30+60=90크레딧**이다. 기존 모델은 보존했고 추가 유료 재시도는 실행하지 않았다.

## 실제 생성 기록 (2026-10-03)

`art/models/tripo/records.json`의 완료 이벤트 기준:

| 대상 | 실제 작업 ID | 완료 청구 | 파일 |
|---|---|---|---|
| Skeleton | `7933a6c8-84d2-441a-974a-f9d30c436611` | 30크레딧 | `art/models/tripo/SkeletonClothed_raw.glb` (1,130,332바이트) |
| SkeletonKing | `f5de205f-58fa-4519-b054-55e5ad6d616d` | 60크레딧 | `art/models/tripo/SkeletonKingClothed_raw.glb` (2,949,608바이트) |

파일 생성 완료이며 새 계정 Roblox import·게임 적용 완료는 아니다. 해골 왕 보스의 게임 기획/추가도 아직 남아 있다.
성기사 남성 pilot 리깅 25를 포함하면 이번 API 실제 총 청구는 **115크레딧**, 마지막 확인 잔액은 **4,885**다.
인간 코스튬 전체 비용 승인은 별도 범위이며 이 해골 90 승인으로 추가 425크레딧을 승인받았다고 해석하지 않는다.
