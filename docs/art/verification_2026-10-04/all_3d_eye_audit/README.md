# 전체 3D 눈 재검사 — 2026-10-04

무료 로컬 검사만 진행했다. 원본·생산 변경, Studio 호출, 업로드, 유료 요청은 0회다.

확인 범위는 fixed 아바타18개, 각 expression 폴더 최신 얼굴후보18개, 기존 몬스터7개, 옷 입힌 해골2개, 기존 SharpD 생성본·리그2개로 총47개 GLB다. 중간 보관 후보를 중복 집계하지 않는다.

`inventory.json`에 파일·내장 이미지 SHA와 크기·재질·리그 정보를 기록했다. 최신 얼굴후보16개의 기존 정면 렌더는 실제 최신 GLB SHA와 같았다. 남은 HaloMageM/NeutralMageF는 최신 파일로 새 정면 렌더를 만들었다. 18개 모두 현재1254 얼굴 PNG 바이트가 기존 검토본과 같다. 이미지·렌더를 직접 본 판정은 `visual_findings.json`에 개별 기록했다.

아바타18종은 모두 눈 경계·반사점·속눈썹의 번짐 또는 거침이 남는다. 특히 HaloMageM 최신 MouthRestored_v2의 입 위·아래 검은 삼각 틈, NeutralWarriorF의 입 역삼각형, NeutralMageM의 눈 면 경계는 텍스처와 별도로 표면 수정이 필요하다. NeutralMageF 최신 Winding_v2에서는 이전 입 끝 삼각 음영이 줄었지만 눈 번짐은 남는다.

몬스터는 같은 정도의 문제가 아니다. Goblin은 홍채 외곽의 미세한 거침, GoblinBrute는 작은 눈 세부 손실이 보인다. Slime·해골 계열·GoldenGoose는 현재 정면에서 눈 형태와 주요 반사점이 식별돼 불필요한 재생성을 권하지 않는다. 실제 게임 거리 확인은 별도다.

**SharpD 생성본과 리그가 실제로 존재한다.** 두 파일의 컬러8192×8192, ORM4096×4096, Normal4096×4096 이미지 SHA가 모두 같다. 무조명 정면에서 현재 생산궁수보다 눈·윙크·하이라이트가 훨씬 선명하고 헤일로 별도 있다. 따라서 유료 재생성부터 진행할 근거가 없다. PBR은 켜져 있으며 실제 흰옷 광택은 별도 재질 비교가 필요하다. 밝고 무채색인 atlas 영역의 거칠기 G 중앙값61/255는 낮지만, 이는 옷 영역만 분리한 검사가 아니므로 흰옷 전체가 금속이라고 단정하지 않는다.

수정 순서는 승인 GPT 원화의 얼굴 직접 UV 적용 → HaloArcherM 근접/기본 거리 확인 → 사용자 승인 → 나머지17종이다. 입 삼각 틈은 별도 무료 Blender 후보로 고친다. 고블린 원래 디자인·복장은 유지한다.

렌더 재현은 `tools/render_eye_audit_batch.py`를 Blender로 실행하고 `py tools/inventory_all_3d_eye_audit.py`를 실행한다. 최초 축 방향만 사용한 `_face_unlit.png` 파일은 측면/부정확한 rig 범위 진단으로 보존했다. 최종 판단에는 `_front_face_unlit.png`와 `monster_sharpd_render_manifest_v2.json`을 사용한다. SharpD rig는 bind 범위와 실제 표시 영역이 달라 확인된 실제 머리 높이로 근접 카메라를 잡았으며, 원본 모델을 바꾸지 않았다.
