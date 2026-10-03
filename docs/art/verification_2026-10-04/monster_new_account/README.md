# 몬스터 새 계정 실제 등록·승격 증거

Goblin과 GoblinBrute는 실제 Native Import→원본/PBR 검사→CustomModels 승격→새 계정 ID 기록을 마쳤다. Source와 옛 CustomModels/ID는 보존했다. 단순 준비 metadata가 아니며, 승격과 최종 게임 외형 확인을 구분한다.

- Goblin: 원래 초록 몸·의상·PBR·불투명 Native 확인, 실제 일반 MonsterService spawn 높이5와 새 ID 확인, 정상 게임 Native 외형도 루트가 확인했다.
- GoblinBrute: raw Native와 승격 후 실제 일반 게임 재확인 모두 원래 초록 몸·갑옷·몽둥이·불투명 외형을 루트가 확인했다. 정상 clone 높이7.5/동일 새 MeshId/SA4맵/Transparency0도 유지됐다. 첫 회색·갈색 Native 실패 사진과 당시 HOLD 판정은 보존한다. Source/PBR 변경0으로 다시 정상 색이 보였으며 **이전 회색 원인은 미확정**이다. 지연 로딩은 추정일 뿐이다.
- actual MeshPart preload Success와 SA 콜백/개별 맵 문자열 결과를 구분한다. 실제 SA의 네 맵 문자열은 Failure였고 SA instance 콜백0은 네 맵 성공 증거가 아니다. Native 원래 색·음영 표시가 확인됐으므로 문자열 실패만으로 PBR 제거/재업로드하지 않는다.
- MonsterService는 전체 CustomModels clone→Pivot 원래 회전→bodyHeight ScaleTo→지면/XZ 중심 보정·Part flags만 적용한다. 새 SA/Color를 덮어쓰지 않는다. Goblin5/Brute7.5는 게임 치수이며 5.5stud 진단 preview와 구분한다.
- Skeleton/선택된 SkeletonKing/Slime/Goose 후속 복구, BigSlime 원본 누락은 남았다. art/out/v1과 미선택 옷입힌 Goblin 수정본은 제외한다.

각 actual JSON/Native 사진의 원본 경로·원본 SHA·복사본 SHA·user_id 제거 개수는 evidence_index.json을 따른다. 원본은 변경하지 않았다. 이번 복사는 Studio/API/업로드 호출0이다.

## 재확인 거리와 로딩 진단

서버 QA 이동 직후 거리12.99998stud였지만 실제 Client probe는 거리약597.9/nearby=false/StreamingEnabled=false였다. 이동 후 원래 위치로 복귀했을 가능성은 추정이며, 가까워져 문제가 해결됐다는 주장은 하지 않는다. 실제 Client MeshPart 콜백1개 Success, SA instance 콜백0, 맵 문자열4개 Failure는 그대로다. 정상 Native 재확인과 개별 callback 자료는 별개다. 원래 source/PBR/ID를 변경하거나 다시 업로드하지 않았다.
