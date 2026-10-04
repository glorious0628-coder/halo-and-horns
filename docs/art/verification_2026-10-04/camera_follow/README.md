# 카메라 추적 수정 — 2026-10-04

사용자 보고: 플레이하면 카메라가 캐릭터를 잘 따라가지 않는다.

## 원인과 변경

실제 실행 중 `CameraType=Custom`인데 `CameraSubject`는 Workspace에서 제거된 이전 `Darugi_S2.Humanoid`였다. 현재 `Player.Character`의 Humanoid와 달랐다. 서버 `PlayerService.installCharacter`는 코스튬으로 캐릭터를 교체하지만 클라이언트 추적 대상을 다시 연결하는 코드가 없었다.

`CameraFollow.luau`를 ClientMain의 첫 모듈로 등록했다. 현재 캐릭터/카메라 변경, 늦게 도착한 Humanoid, Custom 모드 복귀 때 현재 캐릭터의 Humanoid를 연결한다. 이전 이벤트는 해제한다. CFrame·줌·회전·충돌 처리는 Roblox 기본 카메라가 담당하며 Scriptable은 보존한다. 사망 중에도 현재 캐릭터 추적을 유지한다.

API 확인: [Roblox Camera.CameraSubject](https://create.roblox.com/docs/reference/engine/classes/Camera#CameraSubject)의 현재 플레이어 Humanoid 연결 예시를 참고했다.

## 실제 Studio 결과

| 항목 | 수정 전 | 수정 후 |
|---|---:|---:|
| 걷기 이동 거리 | 11.626 stud | 11.667 stud |
| 카메라 초점 이동 | 0 stud | 11.667 stud |
| 정지 후 수평 추적 오차 | 11.833 stud | 0 stud |
| 걷기 12회 표본의 현재 Humanoid 추적 | 0/12 | 12/12 |

수정 후 최초 아바타, 코스튬 ON→OFF→ON, 점프·착지, 정상 사망·부활, 잘못된 대상 복구, CurrentCamera 교체, Scriptable 보존과 Custom 복귀를 확인했다. `metrics.json`의 **18/18 검사 통과**, Luau 2파일 문법 통과. 소스 동기화 2개 변경/41개 유지/삭제 0이다.

`before.png`와 `after.png`는 Studio MCP가 현재 플레이 화면을 캡처했다. 화면 제어는 사용하지 않았다. 테스트 이동은 클라이언트 Humanoid:MoveTo이며, 코스튬은 실제 SetCostume 요청, 사망은 테스트 서버 Humanoid.Health=0에서 정상 부활 경로를 거쳤다. 가상 장치 입력·모바일 터치·다인 시각 검증까지 완료했다고 확대하지 않는다.

## 저장과 범위

- `place_update.json`: build/place 두 GoodEvil에 ClientMain Source 갱신과 CameraFollow 모듈 추가만 반영. 기존 XML 바이트·에셋 필드 보존 및 두 파일 동일성 검사.
- 기존 에셋 다운로드 경고와 Studio DataStore 메모리 모드는 카메라 문제와 별개로 남는다.
- 눈·3D 프로필·활·글씨·첫 화면 수정 완료를 뜻하지 않는다.
- Roblox 업로드 0, 유료 호출 0, 사용 크레딧 0.
