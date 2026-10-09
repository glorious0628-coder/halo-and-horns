# HUD 실제 3D 아바타 초상화

> 기록용(2026-10-09 검수): 2026-10-04 기록이다. 치비 코스튬은 게임에서 빠졌고(SPEC A23-5) HUD 초상은 본인 아바타의 3D 모습이다(크기는 머리+어깨, A23-81).

최신 사용자 정정은 **프로필도 실제 3D여야 한다**이다. 아래 2D 크롭 자료는 이전 구현의 증거로만 보존하며 생산 HUD에는 사용하지 않는다. `Config.UIArt.Parts`에 임시로 추가했던 18종 `PortraitRect`와 전용 `PortraitHaloArcherM` 항목은 제거했다. 이미 업로드한 F 이미지의 ID와 이력은 별도 에셋 장부에 보존한다.

현재 HUD 소스는 기존 금색 링 안에 `AvatarPortrait3D` ViewportFrame과 WorldModel을 배치한다. 현재 실제 Character를 복제하므로 코스튬 ON/OFF 모두 화면 속 아바타와 같은 모델을 사용한다. Scripts·GUI·효과·물리힘은 복제본을 부모에 넣기 전에 제거하고 Bone/Motor6D Transform 및 스킨 내부 Weld·ObjectValue 연결은 보존한다. 움직일 때마다 복제하지 않으며 외형 변경·리스폰·선택·성장 시에만 짧게 모아서 다시 만든다. 실제 얼굴 TextureID와 SurfaceAppearance는 변경 신호로 복사한다.

카메라는 실제 `Character.Head`와 HumanoidRootPart의 앞방향을 사용한다. 스킨 MeshPart의 rest CFrame을 머리 위치로 쓰지 않는다. 계정 썸네일은 캐릭터가 없거나 모델을 불러오는 동안에만 대체한다. 실제 Studio 컴파일·렌더·전환 결과는 별도 실제 증거를 따른다.

## 이전 2D 크롭 시도

- 기존 승인 `UIP_Char<Faction><Class><M|F>.png` 18종과 이미 업로드된 ID를 재사용한다. 원본 그림 변경·신규 업로드·유료 작업은 0이다.
- `Config.UIArt.Parts`의 `PortraitRect`는 원본 픽셀 좌표다. 18개 모두 실제 이미지 경계 안이며 `portrait_crop_measurements.json`에 크기·SHA256·기존 ID를 남겼다.
- `approved_art_crops_contact.png`는 원형 창에서 잘리는 영역을 확인한 로컬 비교 그림이다. 실제 Roblox 렌더 결과로 취급하지 않는다.
- 선택된 진영·직업·성별을 따르며, 선택 전·코스튬 OFF·그림 누락/미로딩에서는 기존 Roblox 계정 초상화를 유지한다. 성별 이미지가 없으면 반대 성별을 임의로 표시하지 않는다.
- `Portrait<Faction><Class><M|F>` 부품이 있으면 전용 초상화를 우선한다. 전용 부품도 승인된 그림과 실제 업로드 ID가 있어야 등록하며, `PortraitRect`가 없으면 이미지 전체를 사용한다.
- 기존 빛 궁수 남녀/장인 궁수 여성의 선택 그림 자체에는 윙크가 있다. 이 원본 표현을 코드로 고쳐 그리지 않았다. 빛 궁수 남성 기본 표정 교정 및 전용 초상화 선택·업로드 결과는 별도 실제 기록을 따른다.

실제 3D 검증 조건: 빛 궁수 남성의 얼굴 정면·내부 Bone/메시 보존, 진영·직업·성별 전환, OFF→ON, 사망·리스폰, 기본/진지/미소 변경, 로딩 대체 표시, 기존 금색 링 유지. Studio 컴파일·Play·화면 확인은 주 담당자가 실행하며 이 로컬 측정 기록만으로 완료 판정하지 않는다.

## 실제 검사와 제한

최종 소스는 Roblox 컴파일 통과 및 Studio 동기화1변경/41동일. 실제Play의 OFF/ON·성별 누락템플릿 대체·리스폰·3종 TextureID 신호복사/원복을 통과했다. 최신 카메라 span1.557018stud, 필수머리 Preload Success4/Failure0. `hud3d_runtime_actual.json`이 결과다. 최초 서비스 직접호출은 Neutral만 관찰돼 표정전환 증거로 무효화하고 별도실패자료에 남겼다.

초기 `face_runtime_audit/hud3d_initial.jpeg`는 실제3D가 보인다. 이후 확대캡처 `hud3d_verified.jpeg`, `hud3d_zoom_final.jpeg`는 Studio배경/Viewport가 비어 있어 확대 시각합격 증거로 사용하지 않는다. 사용자 전면표시 요청 대기다. UI숫자 통과를 최종선명도 합격으로 간주하지 않는다. Face F7은 아직 로컬후보이므로 HUD에도 기존생산 텍스처가 표시된다.
