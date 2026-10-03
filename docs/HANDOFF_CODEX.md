# HANDOFF_CODEX — 지금까지 한 것, 지금 상태, 다음에 할 것 (2026-10-03 기준)

> Codex(또는 다른 에이전트)가 이어서 작업하기 위한 문서. 먼저 루트의 `AGENTS.md`(규칙)를 읽고 이 문서를 읽는다.
> 사용자에게 말할 때는 항상 한국어, 짧게. 설명 대신 결과(스튜디오에서 플레이 가능한 상태)를 보여 준다.

## 최신 작업 상태 (2026-10-03 20:07, 아래 이전 기록보다 우선)

- 사용자 추가 승인: 나머지 남녀 코스튬 **17종 전부, 최대 425크레딧** 리깅. 실제 무료 import/검사 17종, 유료 리깅 성공 10종/250크레딧, 나머지 7종은 biped이지만 riggable=false라 유료 요청하지 않았다. 현재 API 잔액 **4,635**, 이번까지 누적 실제 청구 **365**. 자동 유료 재요청 금지. 루트만 API ledger를 쓴다.
- 10종 중 로컬 R15 strict 분할 성공은 8종. HornsMageM의 Head/왼팔 동일 웨이트 1면과 HornsMageF의 빈 LeftLowerArm은 보류했다. 새로운 17종이 Roblox에 전부 올라갔거나 게임용 등록됐다는 뜻이 아니다. 실행 도구는 tools/costume_r15/rig_batch.py, 실제 작업 번호는 art/models/tripo/records.json이다.
- 성기사 남성 pilot의 3묶음/18메시를 가져와 CostumePendingRigs에 실제 조립했다. 기본 Animate, 걷기, 점프, F/Q 관절 움직임, 죽음 뒤 기본 ON 재생성은 확인했다. OFF에서 소유자 외형을 되찾지만 물리적으로 밀려나는 문제가 재현되어 **CostumeRigs 승격은 보류**한다. 높이 차이 보정은 적용했지만 그것만으로 해결되지 않았다.
- 글꼴은 사용자 새 요청에 따라 **Noto Sans family 12187370747**로 변경했다. UIKit의 고정 글자 PNG 사용을 껐다. HUD/Vitals 글자를 Regular 11~12px, 제목 13px 수준으로 줄이고 칸을 분리했다. 991×475 선택 화면/HUD 실제 TextBounds는 칸 안에 들어온다. 최종 1590 재검증과 라이브러리 소유권 추가는 남아 있다.
- 전체 **39 Luau 실제 Studio 문법 정상**, 동기화 22개/동일17개, 15초 Play **서버23/23·클라이언트9 시작**, Luau 런타임 오류 없음. 기존 Goblin/GoblinBrute/Skeleton TexturePack 경고는 남아 있다. DataStore는 아직 Studio API 미활성으로 메모리 모드다.
- 닉네임 서버: 2~20 UTF-8 글자, Roblox 방송용 필터, 전 서버 UpdateAsync 원자적 중복 방지, 동일 요청 토큰 복구, 검증된 닉네임만 이름표 등에 표시. 실제 서비스 오프라인 **253개 검사** 통과. 실서버 저장/다인 중복 경쟁은 별도 확인한다. 사용자 승인 art/out/Nickname_Form_A.png의 B 메뉴 입력창과 안전 정책은 후속 작업 중이다.
- 표정은 남녀 직업 18종 모두 **Neutral/Serious/SoftSmile 세 개**부터. 평소 기본, 전투·피격 진지, NPC/유저 대화 미소. GPT 시안은 사용자 승인됐으나 기존 열린 입이 모델에 파여 있어 원본 보존한 새 Head/얼굴 UV 복사본을 검증 중이다. ExpressionAssets는 아직 비어 있고 실제 등록 표정은 0종이다. 실패한 기존 Head atlas 파일은 업로드하지 않는다.
- GoodEvil Edit에서 Ctrl+S 저장을 실제 확인했다: build/GoodEvil.rbxlx **20:07:18, 7,457,604바이트**. place/GoodEvil.rbxlx에 복사했다. 이후 소스 변경은 다시 동기화·저장해야 한다. 컴퓨터 제어는 저장 직후 해제했다.

## 1. 게임 한 줄 요약
"뇌 빼고 하는" 귀여운 로블록스 MMORPG **선악 키우기: 헤일로 & 혼즈**. 진영 3개(빛의 기사단 Halo / 뿔 군단 Horns / 장인 길드 Neutral, 청록 40,200,190) × 직업 3개(전사/마법사/궁수, 진영별 이름). 엘든 링 풍 대륙(교차로 → 말랑 초원 → 고블린 숲 → 해골 유적) + 진영 섬. 전체 맵은 지도(M)로만 본다.

### 바꾸면 안 되는 사용자 결정
- 변경 규칙: 무료 = 진행도 손실(직업 Lv1, 진영 점수 0), 로벅스 티켓 = 유지. 능력치/뽑기 판매 금지.
- 일일 퀘스트 유지 + 안 하면 휴가 보너스 70%.
- 독창성 7개: 덩치 저울, 원한 돈자루, 자동 장전/손 발사, 수배범 괴수화, 황금 거위 줄다리기(+단골 행운), 전향 환생, 휴가 보너스.
- 1:1 직접 거래 금지. 2단계 경제: 재료 드랍 → 전부 팔기 → 원버튼 제작 → 서버 간 거래소(판매 등록 + 예약 구매, 최소 10골드, 수수료).
- 모든 디자인은 GPT 그림으로 먼저(사용자가 고름) → 그대로 구현.
- 아바타: 진영·직업을 고르면 **3D 직업 코스튬**을 입힘(기본 켜짐, 설정에서 끄면 원래 로블록스 아바타).
- 메뉴 키 B (Esc는 로블록스 예약), 키 힌트는 키보드 기기에서만.

## 2. 지금 상태
### 코드 (`src/`, 약 2.6만 줄)
- 이번 저장 라운드는 **부분 완료**다. 최신 전체 **36개 Luau 문법 정상**, 동기화 **0개 변경/36개 동일**, 15초 Play에서 **서버21/21·클라이언트9 정상 시작**, Luau 런타임 오류 없음. 처음의 36개 검사 Play/Edit 충돌은 해결됐으며 문법 오류가 아니었다. HP/MP 물약 실제 UI 회복·중복 클릭 방지는 아래처럼 통과했지만 키1/2·자원 거절/리스폰 보존·3직업 모션·최종 작은 화면·place 저장/커밋은 아직 완료로 간주하지 않는다.
- 완료된 큰 작업 (자세한 계약은 SPEC_ADDENDUM):
  - A12 지도(WorldMap), A14 컴팩트 HUD, **GPT HUD 재디자인**(양피지+장난감, `Config.UIArt` + UIKit 아트 도우미)
  - **진영/직업 고르기 화면 재디자인**(GPT 카드, 남/여 전환, 능력치 5칸: 성기사 4/3/2, 마법사 2/4/3, 레인저 3/2/4)
  - **A15 타격감 + 아파하는 반응**(몬스터 예비 동작 `WindupAt`, 피격 `HurtSeq`, 플레이어 `Pain` Fx, 밀려나기, 베기 궤적, 히트스톱, 스티커)
  - 진영 고르기 전 팀 "진영 고르는 중"
  - **A17 새 계정 그림 연결 + 코스튬 코드**: UI/효과/스티커 78개, 고정 글자 42개, 무기 아이콘 27개, 지형 텍스처 15개, 지도 양피지 1개 = 새 ID **163개**를 기록하고 Config에 연결했다. GPT C 글자는 `UIKit.BindArtText`로 연결하며 이미지가 실제 로드된 때만 원래 글자/외곽선을 감춘다. 글자 중복 표시를 수정하고 실제 플레이 화면을 사용자에게 공유했다. 무기 업그레이드 아이콘은 현재 직업·다음 티어·진영을 따른다.
  - 코스튬 선택/기본 ON/B 메뉴 OFF/서버 교체 코드는 준비됐지만, **움직이며 플레이 가능한 코스튬은 0개**다. 템플릿이 없으면 기존 Roblox 아바타로 플레이한다. `WaitingAppearance`, 검증된 RigType별 Animate fallback/설치 시 자동 재시도, B 메뉴 준비 중/처리 대기 표시 보강 후 전체 문법/기본 시작을 다시 확인했다. 실제 코스튬 ON/OFF 교체 검증과 구분한다.
  - 사용자가 선택 화면 균형 **GPT A안**과 **나눔고딕**을 선택했다. A 구도를 Studio에 반영하고 family `12187361718`을 실제 UI에서 확인했다. 기존 GPT 그림 글자는 유지한다. 작은 화면 잘림 수정은 진행 중.
  - **A18 HP/MP·물약**: 사용자 승인 `UI_HUD_Vitals_A.png`대로 XP 아래 HP/MP, 카드 아래 HP/MP 물약, 그 아래 퀘스트. 키1=HP/2=MP 또는 물약 버튼. 물약 방식 질문에 별도 답이 없어 이번 기본값은 **무료 재사용·종류별10초 CD**, HP 최대치30%/MP 최대치40% 회복이다(방식 자체를 사용자 선택으로 쓰지 않는다). MP100·초당4 회복, 마법사 기본 공격3MP·모든 직업 발사20MP. 부족하면 charge/공격 cooldown을 소비하지 않는 계약이며 해당 거절 검증은 아직 대기.
    - 실제 Halo/Mage 선택→Studio DebugCommand로 HP19.2/최대96·MP20 설정→HP/MP 버튼 각각 클릭. HP물약 +28.8, MP물약 +40 및 각 now+10초 deadline 확인. 자연 회복을 포함해 첫 확인 HP68/MP64, 반복 클릭 뒤 HP78/MP68.1이었다. 두 deadline은 반복 전후 같고 추가 물약 회복 없이 자연 회복만 계속됐다. 두 버튼에 "9초" 표시. 증거 `build/vitals_play_verify_result.json`. **키1/2는 아직 미검증**이며 나머지 거절/MP 비용/리스폰·외형 보존도 별도 확인한다.
  - **A19 직업별 모션**: 사용자 승인 `Motion_Class_Attacks_A.png`대로 전사 베기/내려찍기, 궁수 왼손 활·오른손 시위 당기기/연사, 마법사 왼손 기 모으기·오른손 지팡이 발사/운석 모션 코드 준비. 발사 순간 현재 무기 muzzle을 읽고 캐릭터/직업/진영 변경 시 오래된 지연 동작을 취소한다. 기존 서버 피해/타겟/charge 판정은 유지하며 MP 규칙만 A18을 따른다. 실제 3직업 모션은 아직 최종 플레이 검증 미완료.
- **코드 리뷰 R1 수정(HIGH 2 / MED 27 / LOW 51)**: 2026-10-03 GoodEvil에서 전체 33개 Luau 문법 정상 → 동기화 29개/동일 4개 → 15초 플레이 테스트를 완료했다. 서버 19/19와 ClientMain 클라이언트 8개 모듈이 정상 시작했으며 이번 검증에서 Luau 런타임 오류는 없었다.
  - 실제 UI로 빛의 기사단·성기사 선택, B 메뉴의 말랑 초원 이동, M 지도 열기/닫기·확대·내 위치, F 수동 전투, Q 발사, R 자동 공격, 안내 퀘스트 받기 중복 방지, 거위 공격, 괴수 Siren→Active를 확인했다. 거위 시작·괴수 별 5개·자동 공격용 레벨 5는 Studio 디버그로 설정했다.
  - 결과와 화면은 `docs/review/r1_studio_verify_2026-10-03.md`, 원본 체크리스트는 `docs/review/reviewer_code_r1.md`, 계약은 `docs/SPEC_ADDENDUM.md` A16을 본다.
  - 당시 DataStore API 미활성으로 메모리 모드였다. 저장·재접속/PairCD·다인 PvP·괴수 퇴장 정산·이동 오탐 조건 전체는 여전히 미검증이다. 새 계정 2D/지형은 이후 별도로 연결했지만 3D 전체 복구는 미완료다. 최신 Play에서 GE_Grass TexturePack 경고는 없어졌고 Goblin/GoblinBrute/Skeleton 에셋 경고는 남아 있다. Developer Product ID 0 해결은 확인하지 않았다.
  - CR-H2(위치 검증)는 `Config.AntiCheat.Enforce = false`(로그만)를 유지한다. 메뉴 이동·리스폰·낙하 구조·덩치 변화·적 마을 튕김 등 오탐 조건 전체를 확인한 뒤 켠다.

### 아트 (`art/`)
- `art/prompts/<id>.txt` = 프롬프트, `art/out/<id>.png` = GPT 결과, `art/approved.json` = 사용자 승인 기록.
- UI 부품: `art/out/UIP_*` → 다듬은 것 `art/ui/UIP_*.png`, 크기/9-slice `art/ui/ui_meta.json`. UI 68개+효과/스티커 10개는 새 계정 업로드·ID 연결 완료(`art/ui/asset_ids.json`, `Config.UIArt.Parts`).
- 그림 글자(사용자가 고른 **C 스타일 = 금색 판타지 로고**): 42개를 새 계정으로 업로드·연결했다. `art/ui/text_labels.json`의 단어와 현재 글자가 정확히 일치할 때만 이미지를 사용한다. 숫자·동적 문구·미로딩은 원래 글자로 표시한다.
- 효과/스티커: `UIP_Fx*`(베기, 불꽃, 링, 마법, 먼지), `UIP_Emo*`(아야!, 눈물, 어지러움, 화남, 스트레스). 새 ID 연결 완료, 코드 대체 그림도 유지.
- 무기 아이콘 27개 `Weapon_<Class>_<T1..T6|T7_Halo|T7_Horns|T7_Neutral>.png`: 원본 그대로 새 ID 연결 완료. `Config.WeaponArtKey` + HUD 업그레이드 카드 코드 준비. 상점 등 전체 화면 적용 완료로 간주하지 않는다.
- **지형 텍스처 15개 + 지도 양피지 1개 업로드/ID 연결 완료**: 이전 `texture_01` unknown 10개는 종료된 Studio 확인 및 retryHistory를 남긴 뒤 명시 재시도 도구로 모두 complete. `texture_02` 5개, `map_01` 1개도 complete. 실제 응답으로 `Tex_Grass=78282434254609`, `Tex_LeafyGrass=97617252360457`, 지도=`133911744102396` 확정. 공개 썸네일의 픽셀 비교로 정한 값이 아니다. **MaterialVariant 15개/기본 재질 override 12개/도로 3개 실제 적용 완료**. 옛 GE_Grass를 새 Instance로 교체(GrassReplaced=true)한 뒤 이번 Play에서 GE_Grass TexturePack 경고가 없어졌다. 왕슬라임은 아직 새 계정 3D 연결 미완료.
- 직업 캐릭터 그림 18장 `UIP_Char<Faction><Class><M|F>.png` (뿔 6명·빛 여궁수는 노출 없게 다시 그림), 코스튬용 차렷 자세 `APose_*.png` 18장.
- 승인된 시안: `UI_HUD_Final.png`(HUD), `UI_Faction_B.png`(진영), `UI_Class_A.png`(직업), `UI_Lettering_C.png`(글자).
- 추가 승인: `UI_Faction_Layout_A.png`(최신 중앙 균형 구도), `UI_HUD_Vitals_A.png`("어휴 너무 좋지"), `Motion_Class_Attacks_A.png`("좋았으"). HP/MP 병 2장은 root가 한 장씩 확인·사용자 표시 후 업로드했다. `Config.UIArt.Parts.IconPotionHP=100061379621289`, `IconPotionMP=133725941898063`이며 기존163+2=새 계정 **2D165개**다.
- `docs/art/verification_2026-10-03/faction_a_nanum_1590.jpeg`는 수정 도중 실패 화면 기록이며 최종 완료 사진이 아니다. 데스크톱 스크롤/짧은 문구/폰트 적합성 후속 수정과 최종 확인이 남아 있다.
- **`art/out/v1/` 은 버린 그림. 절대 업로드 금지** (특히 `art/out/v1/revealing/`).

### 3D (`art/models/`)
- 몬스터 Tripo 모델: Slime, Goblin, GoblinBrute, Skeleton, SkeletonKnight, GoldenGoose(심술궂은 v2), SkeletonKing(보스, 게임에 아직 없음).
- Slime과 기존 Goblin/GoblinBrute 디자인은 유지한다. 해골만 사용자가 고른 옷 입힌 그림으로 교체한다. 옷 입힌 해골·왕 GLB 생성은 완료했지만 Roblox 가져오기/게임 연결 완료로 기록하지 않는다.
- 직업 코스튬 18명: `art/models/costume/fixed/Costume_<Faction><Class><M|F>.glb` (Tripo 2k → `tools/fix_face.py`: 머리 분리 + 머리 전용 1024 텍스처 + 샤픈). 원본 2k는 `raw/`(깃 제외), Tripo 작업 번호는 `tripo_tasks.json`.
- 성기사 남성 1종은 무료 파일 재등록·무료 rig-check·25크레딧 biped/Mixamo 리깅 완료. R15 분할/관절 JSON 및 3개 import 배치는 `build/costume_r15/Costume_HaloWarriorM/`에 준비했다. 실제 Studio에는 `ServerStorage.CostumeImports`의 Batch01 **7 MeshPart만** 있다. Batch02/03 및 전체 관절 조립·애니메이션·플레이 검증은 남아 있다.
- 마지막 플레이 진단: `Darugi_S2`, Faction=`Halo`, Class=`Mage`, CharacterGender=`F`, ClassChosen=`true`, CostumeEnabled=`true`, CostumeStatus=`MissingTemplate`. 당시 `CostumeRigs`, `CostumePendingRigs`, `CostumeAnimationControllers` 폴더 전부 없었다. 이후 Animate만 아래처럼 설치됐으며 playable `CostumeRigs`는 여전히 0개. 기본 ON은 선택값이며 코스튬이 적용됐다는 뜻이 아니다.
- Batch01 임시 clone은 이후 9개 에셋 PreloadAsync 성공, 얼굴·눈·갑옷 텍스처 정상 표시를 확인했다(`docs/art/verification_2026-10-03/costume_texture_studio.jpeg`). 이것은 정적 메시/텍스처 확인이며 R15 움직임 검증이 아니다.
- 기본 R15 Animate는 실제 기본 캐릭터에서 캡처 후 설치된 Roblox engine의 `.rbxm` Source와 **바이트 일치**를 확인했다. vendor 보존/오프라인 검사 후 root의 `install_animate.py --apply`가 **실제 설치·검증 완료**: `ServerStorage.CostumeAnimationControllers.R15`, 전체 61노드/Source 28,802자, SHA256 `49eab7530cfc33b8af13b995ae1fa87f482a489b6d108ec2410d12dd19b720f0`. 감사 기록은 `build/costume_r15/animate_install_20261003T073704Z_4ef76cd9.json`(complete). 이것만으로 코스튬 리그는 완성되지 않는다.
- EditableMesh 무료 검사: 기존 LeftLowerArm 원본 비교 431면, UV 최대 오차 0, 위치 최대 오차 1.237e-7, verified=true. LeftLowerLeg 로컬 프리뷰는 850 vertices/596 faces, 모든 비교 오차 0. **CreateAssetAsync 실제 1회 호출은 "CreateAssetAsync and CreateAssetVersionAsync are not available yet" 예외**, 현 Studio에서 미지원이다. 새 메시 업로드 성공 **0개**, 재시도 **0회**, ledger 상태 Unknown을 보존(`build/costume_r15/Costume_HaloWarriorM/editable_upload_ledger.json`). API를 반복하지 말고 나머지 **11조각은 파일 3D Importer**로 가져와야 한다. 사용자 요청대로 별도 Sky 창은 열지 않았다.
- 몬스터는 스튜디오 place의 `ServerStorage.CustomModels.<Id>`에 넣으면 `MonsterService`가 자동으로 겉모습으로 씀(A1). 3D 가져오기: 스튜디오 3D Importer → 이름 정확히 → 크기 맞추고(슬라임 ~5, 고블린 5.5, 우두머리 8, 기사 7) 정면이 -Z인지 확인 → `ServerStorage.CustomModels`로 이동 → 저장(ctrl+s) → `build/GoodEvil.rbxlx`를 `place/`로 복사해 커밋.
- **저장 place 최신화 미완료**: 마지막 확인한 `build/GoodEvil.rbxlx`는 2026-10-03 **14:53:38**, 6,606,409바이트다. 이 파일 기준 새 계정 재가져오기는 Slime/GoldenGoose/SkeletonKnight 3종뿐이다. 현재 Studio의 임시 import/최신 src가 이 파일이나 `place/GoodEvil.rbxlx`에 저장됐다고 간주하지 않는다.

### 계정 / 업로드 상황 (중요)
- 2026-10-03 옛 로블록스 계정 1일 정지(노출 그림). 사용자는 **새 계정을 계속 쓰기로 함**.
- 옛 계정이 올린 것은 새 계정 게임에서 안 보일 수 있다 → **같은 파일을 새 계정으로 다시 업로드/가져오기**(새로 만들 필요 없음). 사용자가 **2026-10-03 오늘부터 허용**했다("아니야 오늘부터 해도 돼"). 원래 10-04 제한은 해제됐다.
  - UI78+그림 글자42+무기27+텍스처15+지도1+물약2 = **2D165개 업로드/ID 연결 완료**, `Config.UIArt.Parts`와 `art/ui/asset_ids.json` 새 ID 반영. HP/MP UI와 물약 gameplay 완료는 별도 검증한다.
  - MaterialService 15종/override 12종/도로 3개 새 ID 적용 완료. 나머지 몬스터/코스튬의 완전한 3D 가져오기·플레이 연결은 미완료.
  - 업로드 전 한 장씩 확인 → 사용자에게 보여 주기 → 10장 이하씩 나눠서.

## 3. 다음에 할 일 (우선순위)
1. **R1 기본 스튜디오 검증 완료**: 전체 문법·동기화·시작·진영/직업·전투·퀘스트·지도·거위·괴수 기본 동작 확인 완료(위 기록). 남은 다인 PvP/PairCD 저장·재접속/괴수 퇴장 정산/이동 오탐 전체 조건은 별도 검증한다. `AntiCheat.Enforce`는 아직 끄고 둔다.
2. **새 계정 2D 재업로드 완료**: 165개 새 ID와 SHA256/배치 결과를 유지한다. 3D 미완료 몬스터/코스튬을 이어서 처리한다. `--record-result`는 받은 결과만 복구하며, `--retry-disconnected-unknown --reason ...`은 이전 Studio 종료·대상 증거·retryHistory가 필요한 실제 재업로드다. ledger writer는 반드시 하나만 둔다.
3. **글자/선택 화면 후속 검증**: 고정 그림 글자 42개와 사용자 선택 A 구도·나눔고딕 반영 완료. 실제 991×511에서 글자가 잘려 수정 중이므로 수정 후 문법·동기화·크기별 플레이 화면을 재확인한다. 내장 Laptop 1590×637 설정/기존 device·방향·배율 원복 payload는 `build/device_session_*.json`, 생성기는 `build/prepare_device_session.py`다. custom device는 만들지 않는다. 숫자·동적 문구·로딩 실패 대체 글자도 확인한다.
4. **직업 코스튬 시스템**(기본 켜짐, 설정에서 끄기):
   - 계획: Tripo 자동 리깅(biped, mixamo 뼈, 25크레딧) → 블렌더에서 뼈 가중치로 메시를 R15 15조각(Head, UpperTorso, LowerTorso, Left/RightUpperArm, LowerArm, Hand, Upper/LowerLeg, Foot)으로 나누고 관절 위치 JSON 출력 → 스튜디오에서 조각을 MeshPart로 가져와 커스텀 R15 리그(Motor6D를 관절 위치에)로 조립 → 스폰 때 `player.Character`로. 로블록스 기본 걷기/점프 애니메이션이 그대로 돈다. (로블록스 자동 아바타 설정은 치비 비율이라 실패함.)
   - 현재 성기사(남) 리깅, Batch01 7개, 기본 Animate 설치까지 완료. CreateAssetAsync는 현 Studio 미지원이므로 재호출하지 않는다. 파일 Importer로 남은 Batch02/03 11조각(각 배치 ≤10개) 입력→전체 R15 조립→걷기/점프/F·Q 공격/죽음·리스폰/OFF 원본 복귀/피해·보호 상태 보존을 실제 플레이로 검증한다. 통과 전 playable `CostumeRigs`로 승격하지 않는다.
   - 나머지 17종 리깅은 **425크레딧 계획**이며 아직 실행하지 않았다. 이번 기록으로 18종 전체 비용 범위를 승인받았다고 추정하지 말고 대화에서 명시 범위를 확인한다(`docs/art/costume_rig_plan_2026-10-03.md`).
5. **무기/지형/지도/왕슬라임 연결 후속**: 무기 27개 ID와 HUD 코드, 지도 양피지 코드, 지형 15종/override 12종/도로 3개 적용 완료. 직업·진영·티어별 무기 표시와 실제 지형/지도 화면을 확인한다. 왕슬라임은 새 계정 `CustomModels.BigSlime` 미완료.
   - 선택 화면 A 구도/나눔고딕과 **전사·궁수·마법사별 모션 시안**은 사용자 선택/승인 완료, 코드 준비됐다. 다음은 3직업 F/Q 모션·현재 muzzle·직업/진영/캐릭터 변경 취소를 실제로 확인한다. A18 HP/MP바·키1/2·버튼·종류별 CD·부족 MP 거절·리스폰/외형 변경 보존도 함께 검증한다.
6. **해골 왕 보스**: 아직 게임에 없음(기획 확인 후 추가).
7. 2단계 경제(재료/제작/거래소) — ADDENDUM에 설계 먼저.
8. **저장/커밋 마감**: 단일 GoodEvil Edit 창 확인→최신 src 동기화/검증→Studio에서 `build/GoodEvil.rbxlx` 저장→파일 시각·내용 확인→`place/GoodEvil.rbxlx` 복사→커밋/push. 지금 남은 부분을 완료한 것으로 쓰지 않는다.

## 4. 그림 → 게임 파이프라인
1. 프롬프트 `art/prompts/<id>.txt` 작성(캐릭터는 단정한 옷차림 문구 필수) → 생성 → `art/out/<id>.png`.
2. 사용자에게 보여 주고 고르게 함 → `art/approved.json` 기록.
3. UI 부품이면 `py tools/prep_ui.py <id>` → `art/ui/` → 업로드(로컬 http 서버 + `upload_image`) → `Config.UIArt.Parts`에 `{ Id, Size, Slice }`.
4. 3D면 Tripo(API: `tools/tripo_api.py`, 웹: studio.tripo3d.ai) → 텍스처 2k로 → `tools/fix_face.py`(캐릭터) → 스튜디오 3D Importer.

## 5. Tripo 3D
- 사용자 API 연결/충전 완료. 마지막 확인 잔액 **4,885크레딧**, 실제 완료 청구 **115 = 옷 입힌 해골 30 + 왕 60 + 성기사 남성 리깅 25**. 무료 import/rig-check는 각각 0. 웹 스튜디오 과거 잔액 약 70은 현재 확인한 API 잔액과 별개이며 재확인하지 않았다. API 키는 git 제외 `.env`에만 보관한다.
- 해골 90크레딧 및 인간 코스튬 진행 지시는 확인했다. 이미 청구한 pilot 25와 이후 17종 최대 425는 구분한다. 추가 425의 명시 비용 범위 승인은 이 기록으로 확정하지 않는다. 실제 ID/비용은 `art/models/tripo/records.json`, `docs/art/*_plan_2026-10-03.md` 참고.
- 문서 전체 사본 `docs/vendor/tripo_api/*.md` + 한국어 정리 `docs/vendor/tripo_api/README_KO.md`(추천 레시피 9장).
- 추천 설정(캐릭터): H3.1 `v3.1-20260211`, `texture_quality: detailed`, `texture_version: v3.5-20260815`, `texture_alignment: original_image`, `pbr: false`, `face_limit: 18000`. 따로 리토폴로지 금지(다시 구우면서 흐려짐). 약 40크레딧(+리깅 25).
- 조사 결론: Tripo 유지가 최선(Meshy 7.1만 비교 후보).

## 6. 로블록스/스튜디오 함정
- `Terrain:FillBlock`은 요청보다 2스터드 높게 채움 → 모든 채우기를 2 낮춤(preview_map.lua 반영됨).
- Atmosphere 금지(WarService가 Fog를 트윈함). 조명: ClockTime 16.8, Brightness 1.8, Fog 120/650.
- 스크립트 만들기는 MCP `multi_edit`로만(execute_luau 샌드박스는 스크립트를 부모로 못 붙임). `sync_to_studio.py`가 처리.
- `luau_check.py`는 Edit 모드에서만. Play 중이면 `playtest.py --stop` 먼저.
- 스튜디오 화면 캡처는 창이 앞에 있어야 함(최소화면 흰 화면).
- 3D Importer 이름 칸에 Tab을 치면 이름에 탭이 들어감 → 클릭으로 확정.
- 로블록스 업로드 정지 중에는 자기 에셋(이미지/메시/텍스처)이 전부 403으로 안 불러와져 화면이 깨져 보임.

## 7. 문서 지도
- `AGENTS.md` 규칙 · `docs/GDD.md` 기획 · `docs/TECH_SPEC.md` 계약 · `docs/SPEC_ADDENDUM.md` 최신 결정(우선) · `docs/ART_DIRECTION.md` · `docs/review/` 리뷰 · `docs/vendor/tripo_api/` Tripo API.
