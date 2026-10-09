> **RETIRED 2026-10-06: costumes removed, A23-5.** 치비 3D 코스튬 도구(`tools/costume_r15`)와 함께 은퇴. 아래 설치(`install_animate.py --apply`)는 하지 않는다. 기록용으로만 남긴다.

# 기본 R15 Animate 보존 기록

2026-10-03 GoodEvil의 Play 서버에서 로블록스가 기본 생성한 R15 캐릭터의 `Animate`를 직접 읽어 보존했다. 코스튬/원복 표시가 없었으며 `StarterCharacter`와 `StarterCharacterScripts.Animate` 사용자 정의도 없었다. 기본 Animate를 사용자 정의 LocalScript로 교체하는 규칙은 [Roblox 공식 문서](https://create.roblox.com/docs/reference/engine/classes/StarterCharacterScripts)에 있다.

- `RobloxR15Animate.client.luau`: 캡처 Source 원문 28,802자. 내용을 수정하지 않았다.
- `RobloxR15Animate.tree.json`: Source를 제외한 원래 이름·클래스·Archivable·속성·Attributes·자식 구조. 노드 61개(루트 1개와 자식 60개)다.
- `RobloxR15Animate.provenance.json`: 파일 해시, 기본 캐릭터 확인 조건, 검토 결과, engine 원본 일치 증거다.

Source SHA256은 `49eab7530cfc33b8af13b995ae1fa87f482a489b6d108ec2410d12dd19b720f0`이다. 설치된 Roblox `version-76e1a02649ad4f35`의 `content/avatar/scripts/humanoidAnimateR15_DEPRECATED_20260813.rbxm`에서 Source를 추출해 캡처와 바이트·SHA256이 완전히 일치함을 확인했다. RBXM 파일 SHA256은 `2a8c520427d460cdb790c68786aa064957eea12f00cccb2fd389c0f588ccb515`다. 같은 배포 폴더의 새 `humanoidAnimateR15.lua`는 32,209자의 다른 개정판이므로 그 파일과 동일하다고 주장하지 않는다.

원문 전체를 읽었다. Humanoid 상태에 따른 로컬 애니메이션과 emote 제어 코드이며 외부 `require`, HTTP 요청, Remote 호출, DataStore 코드는 없다. `wait`, 구형 이벤트 표기 등 engine 원문도 그대로 보존했다. 커뮤니티 스크립트나 Toolbox 소스를 가져오지 않았다. 기본 애니메이션 자식 경로는 [Roblox 공식 설명](https://create.roblox.com/docs/tutorials/use-case-tutorials/animation/play-character-animations)과 일치한다.

## 재현

```powershell
py tools/costume_r15/capture_animate.py --player Darugi_S2
py tools/costume_r15/verify_engine_animate.py
py tools/costume_r15/install_animate.py --dry
```

캡처는 현재 기본 R15 캐릭터를 읽기만 하고 Play를 정지하지 않는다. engine 검증은 로컬 Roblox 배포 파일을 읽기만 한다. 설치 도구의 기본값과 `--dry`는 파일·해시·노드 검증만 하며 Studio에 연결하지 않는다.

## 설치

GoodEvil을 **Edit** 모드로 둔 뒤 root가 실행한다.

```powershell
py tools/costume_r15/install_animate.py --apply --studio-id <현재 GoodEvil ID>
```

대상은 `ServerStorage.CostumeAnimationControllers.R15`로 고정된다. GoodEvil 인스턴스가 하나인지 확인하고 Play 모드면 실패하며 Play를 정지하거나 동기화하지 않는다. Folder가 없으면 만들고 LocalScript Source는 `multi_edit`로 설치한다. 이후 Animation 27개, StringValue 20개, NumberValue 12개, BindableFunction 1개를 캡처 값대로 재구성한다. 기존 R15 Source가 검토 원본과 다르면 덮어쓰지 않는다.

설치 뒤 Source 해시와 모든 자식 이름·클래스·속성·개수를 확인한다. `CaptureSourceSHA256`, `CaptureRigType`, `CaptureOrigin`, `CaptureNodeCount` Attributes를 남기고 이전 상태와 결과를 `build/costume_r15/animate_install_*.json`에 기록한다. 이 도구는 Config·다른 Script·UI·에셋 업로드·Git을 변경하지 않는다. 실제 코스튬의 걷기·뛰기·점프 검증은 root가 설치 후 Play에서 진행한다.
