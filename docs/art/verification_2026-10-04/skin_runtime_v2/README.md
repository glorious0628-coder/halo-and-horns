# Skin Runtime Schema2 실제 증거

게임용 기술적 연결은 **2/18종**이다. 기존 빛 기사 남 강체 리그와 최종 빛 궁수 남23Bone/3표면 skin이 Ready다. 전체18종 모션/큰 피격 품질·다인 QA 완료를 뜻하지 않는다. 새 큰 피격 자세 렌더의 궁수 얼굴 패치 경계는 Native/HurtBig 추가 검증 중이다.

## 증거 범위

| 대상 | 실제 구조 검사 | 실제 생산 모듈 Play | 현재 상태 |
|---|---|---|---|
| 빛 궁수 남 원래2표면 | 23Bone·2Mesh·15proxy·15Motor·3host weld,595검사 | 누적2059프레임·fault0·기록 최대0.00022694stud | 최종3표면 전 비교 기준; 원본 Import/Pending 보존 |
| 중립 전사 여 원래2표면 | 15Bone·2Mesh·15proxy·15Motor·3host weld,455검사 | 누적2247프레임·fault0·기록 최대0.0000080252stud | Pending; 최종표정·시각 품질 검증/승격 미완료 |
| 빛 궁수 남 최종3표면 | 23Bone·3Mesh·15proxy·15Motor·4host weld,628검사 | 누적2495프레임·fault0·기록 최대0.000338063stud | 실제 승격; 큰 피격 얼굴 경계 추가 검증 |

628검사 성공은 **루트 실제 실행 보고**다. 별도 matcher 응답 파일은 복사하지 않았으며 `evidence_index.json.root_report_only`에 그 차이를 명시했다. 나머지595/455검사는 실제 응답 원본의 복사본이다. 뼈 위치 정합 오차는 driver 동기화 검사이며, 활·손·무기/옷/얼굴의 모든 동작 품질 승인으로 쓰지 않는다.

세 기계적 Play 기록은 실제 UI 선택·걷기/점프·F/Q·JusticeService 성장1→2→1·OFF 원래 아바타/driver 해제·ON 재연결·사망 재생성을 포함한다. 성장 목표 배율은 Play-only 진영 설정으로 준비하고 실제 JusticeService가 적용했다. 원래2표면 두 모델은 실제4에셋 모두 Preload Success, 최종3표면은 실제6에셋과 별도 진지/미소 메시·텍스처 모두 Success다. 단일 클라이언트 기록이다.

최종3표면 Edit1→2→1 구조 계약은 `halo_archer_m_expression_promotion_actual.json.scale_contract`에 저장돼 있다. 승격의 `qa_sha256`는 수정 전 실제 mechanics 원본 SHA를 가리킨다. 실제 공격/피격 진지·대화 미소·피격 우선·대화 복귀·기본 복귀·OFF 얼굴 없음·ON/리스폰 기본도 같은 mechanics 기록의 개별 결과다.

## 파일

- `halo_archer_m_two_surface_*`와 `neutral_warrior_f_two_surface_*`: 실제 Import 전체 Bone/메시 계층, 조립, matcher, 생산 모듈 Play.
- `halo_archer_m_expression_import_actual.json` 및 `halo_archer_m_expression_importer_ledger_actual.json`: 최종3표면의 실제 원본 ID/23Bone/6참조, 정확한 GLB SHA, 완료 기록. 네이티브 최대7에셋+별도 표정2PNG=전체9개다.
- `halo_archer_m_expression_mechanics_actual.json`: 최종3표면 실제 Play 기계·표정·로딩·생명주기 기록.
- `halo_archer_m_expression_promotion_actual.json`: `ServerStorage.CostumeRigs.Costume_HaloArcherM` 승격과 Pending 보존, 원본GLB/QA SHA,3표정 ID/Face MeshId.
- `*_initial_matcher_failed.txt`: 첫 matcher가 WeldConstraint를 일반 Constraint로 세어 실패한 실제 원문. 수정 후595/455 통과와 함께 보존한다. 확장자가 `.json`이던 원본은 JSON이 아닌 오류 문자열이라 복사본은 `.txt`다.
- `halo_archer_m_initial_direct_scale_failed.json`: 최초 직접ScaleTo2 probe가 실제 JusticeService의 정상 배율 복귀와 충돌한 이전 기록. 이후 실제 JusticeService 성장 검증이 이를 대체한다.
- `evidence_index.json`: 모든 복사본의 원래 workspace 경로/원본 SHA/복사본 SHA/사용자 ID 제거 개수. 원본을 수정하지 않았다.

중첩 JSON 문자열의 `user_id`/`UserId`/`userId`도 제거했다. 따라서 일부 mechanics 복사본 SHA는 원본과 다르다. 기존 matcher의 `inspection_sha256`와 승격의 `qa_sha256`는 원본 파일 SHA이며, privacy 처리가 끝난 파일의 SHA로 덮어쓰지 않았다.

## 화면 해석

[기본 얼굴](../halo_archer_m_skin_expression_neutral_actual.jpg), [미소 얼굴](../halo_archer_m_skin_expression_softsmile_actual.jpg), [진지 얼굴 확대](../halo_archer_m_skin_expression_serious_close_actual.jpg)는 **Play-only API로 지속해 UV 확인한 화면; 원래 이벤트 전환은 별도 실제 QA**다. 화면을 찍기 위해 표정 상태를 지속했으므로 그 JPEG만으로 원래 공격/대화 시간·우선순위를 증명하지 않는다. 원래 이벤트 전환 증거는 mechanics 기록에 있다.

[작은 정면 스냅샷](../halo_archer_m_skin_front_actual.jpg)과 [공격 후 스냅샷](../halo_archer_m_skin_after_attack_actual.jpg)은 정밀모션 증거가 아니다. Native/HurtBig 추가 화면과 원본보존 개선 후보는 별도 검증 후 기록한다.
