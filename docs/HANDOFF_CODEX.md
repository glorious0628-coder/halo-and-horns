# HANDOFF_CODEX — 지금까지 한 것, 지금 상태, 다음에 할 것 (2026-10-04 기준)

## R2 무료 기준선 G2 준비 (유료 승인 전)

- 기존 작업을 `0f7549e`, `79ddb8b`로 분리해 push한 뒤 R2를 시작했다. R2 기준은 SHA `649ce86f...`의 `APose_HaloArcherM_Sharp_D.png` 한 장이며 F/E·HUD·Config·Studio MCP·얼굴 감사 파일을 고치지 않았다.
- R1 실제 GET 검사: 생성70 + rig-check0 + rig25 = **95cr**. 기존 장부에 3건을 `record()`로 보완했고 R1 plan의 실제 제출2건/사용95를 보정했다. 아래 예전 '95 승인 대기/유료0'는 당시 기록이다. 현재 잔액 **4465cr**, R2 사용 **0cr**.
- B0는 MR 맵 연결을 제거하고 metallic0/roughness0.8로 만들었다. B0H는 기존 링·별288면만 제거하고 별도 Halo784면으로 교체했다. 아호게와 나머지 원본 attribute/image bytes는 보존했다. 두 GLB는 제외 폴더 `art/models/costume/raw/r2/`에 있다.
- 실제 Blender 정면·옆·뒤·3/4, flat/lit, 귀·손 확대와 측정은 `art/models/costume/redraw/r2/`에 있다. G2 복사본은 `docs/art/verification_2026-10-04/r2_g2/`이다. B0H 실루엣 IoU0.8922, 별 돌출66px/원본54px, 연결 금색93px/원본103px, 옆 링 기울기 약0.35도, 실효 metallic0이다. 판정에 Tripo preview를 쓰지 않았다.
- **최종 합격은 아니다.** T10 lit 금발 채도 약0.142로0.25 미달, 얼굴200텍셀 분리와 선택 리그의 T11 변환 검증은 대기다. 귀·손·등은 사람 검토 대상이다. Workbench와 EEVEE 차이를 숨기지 않는다. 정면 정사영의 수평 링은 옆면으로 보이며 원화의 타원 원근과 다르다. 링 깊이는 원본 정면만으로 확정할 수 없어 원형으로 둔 가정을 기록했다.
- G2에서 무료 B0H로 계속할지, 새 후보 기본215/최대275cr 한도를 승인할지 사용자 답변을 기다린다. 답 전 Step1·GPT 입력뷰·유료 호출·리깅·Roblox 업로드 금지. 순서 G2→G1→G3를 지킨다. REST 신규 endpoint 및 모든 유료 POST retries0 검증은 유료 진행을 선택하면 제출 전에 완성해야 한다.
- 루트 `--output`은 삭제하지 않고 `r2/records/r1_cli_output.json`으로 이동했다. 실제 내용은 Tripo CLI 출력이 아닌 HornsMageM 입 웨이트 관련 메타데이터였으며 출처·SHA를 함께 기록했다.


## R2 시작 전 기존 작업 정리

- 얼굴 감사·F/E 승인 기록과47GLB 검사는 `0f7549e`로 별도 커밋·push했다. F7 양눈 얼굴은 로컬 보존 검사20개/특징ray16점/UV뒤집힘0 통과 후보로 저장하며 Roblox에 적용하지 않았다. 최신 R2는 APose Sharp D만 기준으로 쓰므로 F/E를 섞지 않는다.
- HUD는 실제 캐릭터3D를 표시하며 코스튬 얼굴 카메라 span을1.13→0.65, 초점을 아래0.23HeadY로 확대했다. 필수 머리 에셋4개 Success/실패0, OFFON·성별fallback·리스폰·3TextureID 반영을 실제 확인했다. 표정 TextureID 테스트와 원래 게임 이벤트 검증은 구분한다.
- 확대 전 실제3D 표시 화면은 확인했다. 확대 뒤 최종 캡처는 Studio 창이 뒤에 있어 3D가 빈 화면이므로 **시각 합격 증거가 아니다**. 사용자에게 전면 표시를 요청했다. 현재 원본얼굴 번짐은 남아 있고 새 얼굴 Roblox 적용은 후속이다.
- `tools/update_place_sources.py --apply`로 GoodEvil 두 파일에 HUD Source만 실질 변경했다(Config 동일).4500인스턴스/521에셋필드/나머지bytes 보존, 두 파일SHA `f060d91989bec14cb757723a764bec094a8ce4704616f92e383ccc57a8432f04`.
- 활 휴대 검색: 대기/걷기/달리기/조준을 구분하는 자료를 확인했다(https://ludo.ai/tools/animation-presets/weapons). 현재 왼손고정+일반이동 모션이며 활 이동자세 교정은 별도미착수다. R2 지시의 무료B0H→G2를 우선한다.
- 위 작업은 R2 이전 변경으로만 커밋한다. R2에서 HUD/Config/Studio MCP/얼굴감사/F/E 파일을 다시 고치지 않는다. 화면 제어·새 유료요청0.

> Codex(또는 다른 에이전트)가 이어서 작업하기 위한 문서. 먼저 루트의 `AGENTS.md`(규칙)를 읽고 이 문서를 읽는다.
> 사용자에게 말할 때는 항상 한국어, 짧게. 설명 대신 결과(스튜디오에서 플레이 가능한 상태)를 보여 준다.

## 최신 눈 번짐 검사·기본 표정·3D 프로필 (2026-10-04 새 세션)

- 시작 시 남은 `AGENTS.md`의 화면 제어 금지 규칙만 검토 후 `cbc3b74`로 커밋·push하고 pull했다. 기존 미추적 `--output`, `.tripo/`는 삭제·수정·stage하지 않는다.
- 파일과 Blender로 **47 GLB**(fixed18·최신 얼굴후보18·몬스터9·기존 SharpD 생성/rig2)를 검사했다. 아바타18종 모두 눈 번짐/거침이 남는다. 몬스터는 Goblin 경미한 외곽 거침, Brute 작은 눈 세부손실을 따로 기록했으며 나머지에 불필요한 재생성을 권하지 않는다. `verification_2026-10-04/all_3d_eye_audit/`의 SHA·렌더·개별 판정을 따른다.
- 아래 오래된 'SharpD 생성 대기' 문구와 달리 **기존 SharpD 생성·리그 GLB가 이미 존재**한다. 실제8192 컬러,4096 ORM/Normal이며 두 단계 이미지 SHA가 같다. 눈은 현재 생산궁수보다 선명하다. 이번 세션 유료 Tripo 요청·크레딧은 **0**이다.
- HaloArcherM raw2k 얼굴 UV17119.125px²→fixed1024 8353.862px², 선형밀도69.8559%다. 현재 별도1254 얼굴 PNG는 원본과 바이트가 같지만 원본부터 눈 경계가 흐리다. 얼굴 고유사용155704픽셀(전체9.9016%)이다. `face_sharpness_audit/source_audit.json`에 범위·방법·한계를 남겼다.
- 실제 Studio `Automatic`/`Level21` × 거리12.5/3.5stud 네 v2 캡처를 저장했다. 최고 품질에서도 번짐이 남는다. 캡처1586×950/engine viewport793×475이며 눈의 어두운 연결영역은 기본거리 약10.5~11×8~8.5 논리픽셀이다. 초기 하얀 실패 캡처도 보존했다. `face_runtime_audit/`와 `face_sharpness_audit/production_v2_reference_comparison.png`를 따른다.
- Roblox 실제 MeshPart의 텍스처5개는 EditableImage에서1024×1024로 읽혔다. **API의 크기 제한 때문에 서버에 저장된 원본 크기를 증명하지 못한다.** 공개assetdelivery403·캐시 명시ID연결0이므로 원격 원본 해상도/압축 손실량은 미확정이다. GraphicsMode/Quality/EditQuality Automatic과 FRM 설정은 복원했다.
- 기본표정 윙크 수정: E는 눈 크기 불균형으로 거절, **양눈 균형 F를 “좋아, 이걸로 해줘”로 승인**했다. `art/out/Avatar_HaloArcherM_Neutral_Balanced_F.png`가 최신 얼굴 원화다. 무료 로컬 얼굴UV/좁은 표면 수정 후보를 검증 중이며 아직 Roblox 생산 적용은 아니다. 파일럿 사용자 OK 전 나머지17종 적용 금지.
- 승인 F를 2D 프로필용으로1장 표시·검토 후 업로드해 ID `130781962577620`을 기록했지만, 최신 사용자 정정으로 **프로필도 실제3D**를 사용한다. 해당2D ID는 장부에 보존하되 최종HUD에서는 미사용이다. HUD ViewportFrame은 현재 캐릭터를 복제하며 실제 표시/OFF·ON/성별 fallback/리스폰을 확인했다. 사용자가 얼굴이 작고 흐리다고 지적해 **카메라 확대를 추가 수정 중이며 최종 저장·완료 전**이다.
- 실제등록 아바타는2/18 그대로다. 새3D 제작·전체18모션/무기/표정·왕슬라임/해골·닉네임 영속검증 완료로 확대 해석하지 않는다.

## 이전 재검증과 얼굴 재디자인 (2026-10-04)

- 사용자 최신 지시: **질문할 때 컴퓨터 제어를 중지하고 묻는다.** 실제 Native 제어를 reset한 상태에서 그림 선택을 물었으며, 응답 대기 중 Studio 입력·설정 변경을 하지 않는다.
- `git pull` 최신 확인 후 전체 **42개 Luau 문법 정상**, 소스 동기화 **0변경/42동일**, 화면 활성화 후 `py tools/playtest.py 15` 재시도 **exit0/서버23/클라이언트10/Luau 오류0**. 첫 Play는 실제 시작됐지만 MCP 시간 초과였으므로 실패 기록을 보존한다. A16은 이미 있어 중복 추가하지 않았다.
- 실제 Halo/Warrior 선택·F 전투·Q 발사·R 자동 공격·안내5/5·받기2회에도120G 한 번만 지급·M 지도/확대/내 위치를 확인했다. 별도 새 Play에서 Halo/Archer 생산 외형과 F 전투를 확인했다. 상세 수치와 Native 화면6장은 `docs/review/r1_studio_verify_2026-10-04.md`와 결과 JSON에 있다. DataStore 메모리 모드/닉네임 영속·다인 검증은 여전히 미완료다.
- 실제 초록 슬라임 MeshPart `Transparency=0`, `LocalTransparencyModifier=0`과 불투명 Native 화면을 확인했다. **왕슬라임 복구·옷 입힌 해골/왕 업로드 완료는 아니다.**
- 1077×475 Native 얼굴 확대에도 눈 번짐이 남았다. 임시 Level21/Bloom OFF 비교 후 **QualityLevel Automatic/Bloom true 원복**, Play 종료. **GraphicsMode는 처음 읽을 때 이미 Automatic이었고 이번에 바꾸지 않았다.** 아래 과거 Vulkan 복원 필요 기록은 당시 상태이며 현재 확인과 구분한다.
- 기존 머리1024 재굽기는 raw2k 대비 실제 선형 텍셀 밀도57.6~78.2%였다. 반면 생산 궁수의 별도 얼굴1254 PNG는 GPT 원본 바이트가 보존돼 있다. 재굽기2048 후보는 로컬 진단용이며 업로드0/생산 변경0이다.
- 사용자에게 보여 준 눈 부분수정 A/B는 모두 거절됐다. 전체 새 시안 C도 **“우리 스타일이랑 너무 달라졌잖아”**로 거절됐다. 최신 요청은 **기존 승인3D 꼬마 스타일·원래 캐릭터를 유지하며 부분수정 대신 전체를 처음부터 또렷하게 다시 그리기**다. 승인 APose/직업 그림을 참조한 전체 재작업 **D를 “ㅇㅋㅇㅋ 좋아!”로 승인**했다. `art/out/Avatar_HaloArcherM_FullRedraw_D.png`와 승인 기록을 보존했다.
- 사용자가 **Tripo 실제3D 제작**과 **가장 좋은 모델**, 먼저 **아바타18종 전부 눈·세부 검토**를 요청했다. D는 원화이며 새3D 완료가 아니다. 기존1254 얼굴UV와 눈/입 위치가 약300/340px 달라 직접 덮지 않는다. D스타일의 **전신 T포즈** `art/out/APose_HaloArcherM_Sharp_D.png`를 새로 만들고 모든 다리를 불투명 바지로 가렸다. Tripo CLI0.5.1 doctor 정상/잔액4560·frozen0, 최고품질 dry-run valid=true. 계획은 **H3.1/HD지오메트리/18,000면/8K텍스처70→무료rig-check→사람형Mixamo리깅25, 최대95크레딧/우선1종**이며 전체 아바타 검토·비용 승인 대기다. 이전75 계획은 사용자 최고품질 요청 전 견적이다. 유료재생성·재시도·새Roblox업로드·생산 변경은0이다. 세부 실행 계획은 `docs/art/tripo_sharp_d_plan_2026-10-04.json`을 따른다.
- 사용자 첨부의 **황금 조각먹은 슬라임이 공중에 떠 보이고 너무 허연 문제**를 후속 우선순위에 추가했다. 먼저18종 아바타 검토, 이후 슬라임 접지 높이·그림자·색 대비·조명/후처리를 실제 Native에서 확인한다. 현재 원인은 미확정이며 승인된 슬라임 디자인을 임의 변경하거나 문제를 해결 완료로 쓰지 않는다. 첨부는 `docs/art/verification_2026-10-04/slime_ground_color_user.png`에 보존한다.
- **전체18종 직접 이미지 점검 완료**: root의 같은768카메라 fixed 정면18장과 담당자별 원화/얼굴/최신CG 빛19·뿔30·장인24장을 실제로 봤다. 18종 모두 눈 번짐/경계 거침이 남고 일부 최신 후보의 삼각형 입·볼/턱 이음·눈 늘어짐을 보류로 기록했다. 전신 원화 중 빛 마법사 여·장인 궁수 여의 하의는 현 복장 규칙 확인/교정이 필요하다. 이 결과는 Native18종 연결/모션 승인이나 새3D 제작완료가 아니다. `docs/art/avatar_quality_review_2026-10-04.md`의 개별표·이미지SHA를 따르며 최고품질 **우선1종95크레딧**의 실행 승인을 기다린다.
- 현재 완료 수는 **새 계정2D165개/생산 아바타2/18종** 그대로다. 무기 아이콘27개는 새 ID와 일치하지만 실제 최종3D 무기 로컬 파일은0개이며 Part 임시 무기와 구분한다. 이번 재검증은 게임 소스·생산 에셋을 변경하지 않았고 기존 미커밋 준비 변경을 보존했다.

## 최신 작업 상태 (2026-10-04 05:56 MouthRestored 실제 생산 승격)

- **현재 게임용 아바타는 2/18종**이다. 성기사 남성 기존 강체 리그와 빛 궁수 남성 원본23Bone/3표면/BindingSchema1을 실제 등록했다. 남은16종·전체18종 모션/무기·다인 QA는 미완료다. 아래 이전1/18/HOLD 기록은 당시 실패와 후보 증거로 보존하며 현재 궁수는 새 MouthRestored 등록본을 사용한다.
- 새 궁수 GLB SHA `17972af93f7ecd176f96af8db81fdff00c04e055a1d340b9dd9f288196d54584`, 원래 얼굴438면/새 정점·덮개0/Body·UV·JW·23Bone·PNG 보존. 루트가 승인한 입71개 P/N 국소 복원만 exact ledger/manifest SHA로 예외 검증했다. 일반 원본 P/N exact gate는 유지한다. 실제 Import7상황 오프라인1161Python+354Luau, 국소 입 예외 궁수68/마법사68·Union59·기존6표정108검사가 통과했다. 이 로컬 검사는 실제 Native QA를 대체하지 않는다. 마법사347면·입75점 후보는 별도 whitelist/68검사만 통과했고 아직 실제 등록/Native QA 완료가 아니다.
- 실제 새 Import는3Mesh/23Bone/6참조/최대7개, 이전 진지·미소PNG는 exact SHA/ID로 재사용했다. Face Mesh`120232648183385`, 기본`114282379234661`, 진지`130810730029380`, 미소`96983789676579`. 새 Source/별도 Pending 및 이전 union/cap/2표면/강체 후보와 옛 Ready archive는 보존했다.
- 내부 연결은 `HHC_SkinBindingSchema=1`, 같은 CostumeSkin 안 실제 BoneHost→3Mesh InternalWeld3개와 외부 root→host WeldConstraint1개다. 실제 inspect SHA `68787b4a07438f7561bb8393db83d820a56b1e566a7e9dff74332d651eae798d`, **engine matcher691검사 PASS**, 최대 bind 오차0.0000152511stud. 최신 Shared 계약은 실제23검사 PASS이며 disabled/duplicate/이름변경 Neck·schema1·기존 rigid 회귀도 확인했다. 이전19검사는 별도 snapshot으로 보존한다. 기존 외부 graph의 Bone 수치/Preload 성공은 실제 피부 변형 증거가 아니었다는 정정은 유지한다.
- 실제 새 후보 Play **2497프레임/fault0/최대 Bone 오차0.000221093stud**: UI 선택·걷기/점프/F/Q/실제 성장1→2→1/OFF·ON/사망·재연결·3표정/피격·대화 우선순위·로딩을 확인했다. 루트가 Native 기본/진지/미소/큰 HurtBig 네 장에서 원래 입 웃는 홈 제거와 실제 얼굴/팔 변형을 직접 확인하고 생산 CostumeRigs로 승격했다. 단일 클라이언트/진단 고정 pose 범위이며 전체18종 모션 품질 승인으로 쓰지 않는다.
- 승격 후 원래 source로 새15초 Play에서 실제 Halo→Archer 선택만으로 Active/ExpressionReady/new FaceMesh/Binding1을 확인했다. QATrial 없이 생산 경로가 적용됐다. 첫 QA는 UI 초기화 조건 때문에 실패했으며 최종 JSON은 재실행 성공 범위만 보관한다. 그 실패가 없었다고 쓰지 않는다.
- 최신 실제 전체42 Luau compiler PASS→마지막 ExpressionAssets1파일 compile/sync1·41동일→15초 Play Luau 오류0. **2026-10-04 05:56:14 KST /12,071,834바이트**, build/place byte 동일 SHA `6da73478884aebcea934e2dbdb9f931a36c13fa211526da3d505995c2379b677`. 최신 생산 궁수·새 몬스터 Source/CustomModels·ID가 저장됐다.
- **Goblin/GoblinBrute 새 계정 Native 등록·CustomModels 승격·art/models/new_asset_ids.json 기록 및 정상 게임 Native 외형2종 확인 완료**다. Source/옛 모델·ID archive/PBR를 보존했고 높이는 Goblin5/Brute7.5다. Brute 첫 회색·갈색 Native 실패/HOLD는 보존했지만 변경0으로 재확인한 정상 게임에서 초록/원래 갑옷/몽둥이/불투명을 루트가 확인했다. 당시 서버 이동 직후거리13과 실제 Client probe거리597.9/nearbyfalse/Streamingfalse가 달라 근처 이동이 해결 원인이었다고 쓰지 않는다. 회색 원인은 미확정이며 지연 로딩은 추정이다. Mesh instance Success/SA콜백0/맵 문자열4Failure는 구분하고 PBR 제거·재업로드하지 않았다. 나머지 몬스터는 아직 완료가 아니다.
- 증거는 `docs/art/verification_2026-10-04/skin_runtime_v2/`와 `monster_new_account/`의 README/evidence_index를 따른다. 복사본의 중첩 user_id도 제거했고 원본 SHA를 유지했다. Native 표정 JPEG는 **Play-only API로 지속해 UV 확인한 화면; 원래 이벤트 전환은 별도 실제 QA**다. 기존 작은 스냅샷은 정밀모션 증거가 아니다.
- HUD A·물약 상점 GPT 선택/`MerchantEnabled=false` 실제 NPC 구매, 남은16아바타·전체18모션/표정/3D무기, 몬스터 나머지 새 계정 복구/회색 원인 조사, 닉네임 DataStore 영속/다인 QA는 미완료다. Native ActualSize 복원/reset 완료, **GraphicsMode Vulkan→원래 Automatic 최종 복원은 아직 필요**하다. 전체 요청 실제 완료·저장·커밋/push 뒤 종료, 무료 초기화 실제 사용0/자동 유료 구매 없음 조건을 유지한다.

## 이전 작업 상태 (2026-10-04 내부 스킨 연결 수정·입 외형 HOLD 당시)

- **현재 실제 게임용 적용 가능 아바타는 1/18종이다.** 성기사 남성 기존 강체 리그만 사용 가능하다. 기존 `CostumeRigs.Costume_HaloArcherM` 등록본은 보존했지만 `HHC_SkinBindingSchema=1`이 없어 새 서버/client gate가 거절한다. 실제 기존 궁수의 RigReady/Animation/Skin/ExpressionRuntime marker를 false로 낮추고 `HHC_PendingSkinBindingRepair=true`를 기록했다. 새 궁수 후보도 외형 HOLD/Pending/Ready0이며 남은17종은 아직 게임용 완료가 아니다.
- 이전 궁수23Bone/중립 전사 여15Bone의 **Bone 오차·driver 프레임·Preload Success·상태 전환은 실제 피부 표면 변형을 증명하지 못했다.** 조립에서 원래 내부 Motor 연결을 지우고 `CostumeSkin` 밖 Character.HRP로 모든 메시/host를 직접 연결해, 같은 Model 안의 Bone→메시 스킨 연결이 끊겼다. 큰 HurtBig를 고정한 Native 화면에서 Bone은 변하지만 얼굴/팔은 거의 정지했고, 내부 연결을 추가하자 실제 표면이 즉시 움직였다. 아래 기존 수치와 승격 기록은 이 오류 발견 전 기록으로 보존하며 최종 모션 성공으로 집계하지 않는다.
- 새 후보는 `CostumePendingRigs.Costume_HaloArcherM_FaceUnionBindingSkinSchema2Candidate`다. GLB SHA `77a99d609d0d7264b2931587ce040bc64d27beca262fd33444bbf8fd31c2734e`, 원래 얼굴438면/새 정점·덮개0/원본23Bone·UV·PNG 보존. 실제3Mesh/23Bone/6참조로 가져왔으며 Importer 최대7개, 기존 진지/미소2PNG는 정확한 SHA/ID 확인 후 재사용했다. 기존 cap 후보·Ready·원본2표면·강체 Pending은 덮어쓰지 않았다.
- **내부 연결 계약은 `HHC_SkinBindingSchema=1`**: `CostumeSkin.HHC_SkinBindingHost` ObjectValue→실제 BoneHost RootPart, 외부 HRP→host WeldConstraint1개, 같은 CostumeSkin Model 안 host→3Mesh의 `CostumeSkinInternalWeld`3개(C0 원래 bind 상대/C1 identity). 실제 inspect SHA `b0a80449285fbe0d56c4cf8351ee2ea5a6175b0d9e757a1e25f05783482c3180`을 사용했고 source/import SHA는 바꾸지 않았다. 실제 강화 matcher690검사와 Shared 계약19검사(Scale1→2→1·누락/외부연결/중복/잘못된 C0·물리설정 거절)가 통과했다.
- 새 실제 Play-only 후보는 **2488프레임/fault0/최대 Bone 오차0.00024832stud**였다. 걷기·점프·F/Q·실제 JusticeService 성장1→2→1·OFF 원래 아바타/driver 해제·ON·사망 재연결, 기본/진지/미소·피격 우선/대화 복귀를 확인했다. Native 고정 HurtBig에서 실제 얼굴/팔 변형도 확인했다. 단일 클라이언트/진단 pose 범위이며 전체18종 모션·활 시위·무기 품질 완료는 아니다. Edit 후보 검증 marker는 false이고 Play-only clone에만 trial marker를 넣었다.
- **궁수 승격은 HOLD**: Serious PNG를 써도 원래 입3D홈의 웃는 음영이 남는다. 표현 담당의 CG/입 주변 ray6개가 모두 FaceExpression이라 누락 면 문제가 아니다. 루트가 허용한 국소 입 곡면 P/N 복원은 별도 후보/strict validator로 준비 중이다. 원래438면·Body/UV/JW/23Bone/PNG는 보존하고 좁은 입 P/N 예외만 기록해야 하며 기존 P/N exact validator를 우회하지 않는다. 아직 새 외형 승인/게임용 승격은 없고 union v1은 보존한다.
- 새 실제 응답·Play 기록·Native 화면은 `docs/art/verification_2026-10-04/skin_runtime_v2/README.md`와 `evidence_index.json`을 따른다. 복사본에서 중첩 JSON 문자열의 사용자 ID를 제거하고 원본 SHA를 유지했다. 진단 고정 표정/HurtBig JPEG는 이벤트 시간·전체 모션 타이밍의 증거가 아니다.
- 오프라인 source 기반 검사981 Python+292 Luau, FaceUnion 원본/변조59검사, 기존6종 표정108검사와 앞선 client341검사는 로컬 검사다. `skin_runtime_v2.py --binding-schema 1`로 새 Pending을 준비한다. legacy schema0/과거 Ready 기록은 보존용이며 새 production gate를 통과하지 못한다. SPEC의 최신 내부 연결 계약은 루트가 갱신한다.
- 몬스터는 **준비 metadata만** 있다: 승인된 기존 Goblin/GoblinBrute/Slime/GoldenGoose와 선택된 SkeletonClothed/SkeletonKingClothed6원본 GLB·내장 이미지 원본을 보존해 1모델 최대6에셋/총10이하 목록을 만들었다. BigSlime GLB는 없어 HOLD다. `build/monster_import_preflight_20261004/ledger_prepared.json`의 직접 검토·사용자 표시·업로드·승격 표시는 모두 false이고, 새 import/CustomModels 복구나 PBR 제거는 아직 하지 않았다. `art/out/v1`/미선택 고블린 옷 수정본은 제외한다.
- HUD A·물약 상점 GPT 선택, `MerchantEnabled=false` 실제 NPC 구매, 나머지17종 아바타·전체18종 모션/표정·최종3D무기, 몬스터 새 계정 복구, 닉네임 DataStore 영속/다인 QA는 미완료다. 최근 API 리깅13신규325/잔액4560/무료거절4는 유지하며 이번 오프라인 준비에서 유료 요청은 없었다.
- 최신 실제 Studio 저장은 **2026-10-04 04:47:24 KST / 11,265,486바이트**, `place/GoodEvil.rbxlx`에 동일 복사했다. 전체42 Luau compiler PASS→4변경/38동일 sync→15초 Play에서 Luau 런타임 오류0이며 옛 몬스터 에셋 warning은 남았다. Native GraphicsMode **Vulkan→원래 Automatic 복원**, 전체 요청 실제 완료·저장·커밋/push 뒤 종료 조건을 유지한다. 무료 초기화 실제 사용0, 유료 구매 승인 아님.

## 이전 작업 상태 (2026-10-04 빛 궁수 남 legacy skin 승격; 위 binding 정정이 우선)

아래 2/18 판정과 표면 변형을 포함한 듯한 표현은 내부 연결 오류 발견 전 기록이다. 실제 수치/상태·에셋 로딩 기록을 보존하며 현재 적용 가능 수는 위 1/18을 따른다.

- **게임용 아바타 기술적 연결은 2/18종이다.** `CostumeRigs.Costume_HaloWarriorM`은 기존 강체 리그+3표정, `CostumeRigs.Costume_HaloArcherM`은 원본23Bone+연속 skin 3표면+3표정이다. 남은16종과 전체18종 모션 품질은 미완료다. 새 큰 피격 자세 렌더에서 궁수 얼굴 패치 경계가 보고돼 **Native/HurtBig 품질 추가 검증 중**이며, Ready2를 전체 피격모션 품질 승인으로 쓰지 않는다.
- 빛 궁수 남 최종 GLB SHA `f23871e89b092cb69eb0547c2c77180ff4150ffbb8593eb47a220ac87aff060a`: 실제 Custom Import3메시/23Bone/6에셋 참조, Importer 최대7개+진지/미소2PNG=전체9개. 원래 공유 RootPart/Bone 계층을 그대로 보존해 투명 R15proxy15개/15Motor/Root host weld4개로 별도 Pending에 조립했다. 628검사 matcher 성공은 **루트 실제 실행 보고**이며 별도 응답 JSON은 아직 없다. 원래2표면 Import/Pending과 강체 Pending은 보존했다.
- 궁수 최종 실제 Play에서 걷기·점프·F/Q·JusticeService 성장1→2→1·OFF 원래 계정 아바타/driver 해제·ON 재연결·죽음 뒤 재생성을 확인했다. 실제 클라이언트 driver 누적2495프레임, 기록 최대 Bone 오차 약`0.000338063`stud, fault0. 기본/진지/미소 실제 메시·텍스처 로딩 모두 Success, 공격·피격 진지/대화 미소·피격 우선·종료 복귀를 확인했다. 실제 Edit1→2→1 구조 계약은 승격 기록의 `scale_contract`다. 최종 기본`114282379234661`/진지`130810730029380`/미소`96983789676579`, Face mesh`88405558388221`.
- **궁수 원래2표면23Bone와 중립 전사 여2표면15Bone도 생산 `SkinRetargetClient`로 실제 기계적 QA를 통과했다.** 궁수2059프레임/최대약`0.00022694`stud, 중립 전사 여2247프레임/최대약`0.0000080252`stud, 모두 fault0. 걷기·점프·F/Q·실제 성장1→2→1·OFF/ON·사망 재연결 및 각각 실제4에셋 Preload Success. Edit matcher595/455검사 통과. 중립 전사 여는 최종3표면/표정·시각 품질 검증과 승격이 남아 **Ready가 아니다**. 단일 실제 클라이언트 결과를 다인 완료로 쓰지 않는다.
- 증거는 `docs/art/verification_2026-10-04/skin_runtime_v2/README.md`와 `evidence_index.json`에 보관했다. 사용자 ID는 중첩 JSON 문자열까지 제거했고 원본 SHA 참조는 유지했다. 얼굴 native JPEG는 **Play-only API로 지속해 UV 확인한 화면; 원래 이벤트 전환은 별도 실제 QA**다. 기존 작은 스냅샷은 정밀모션 증거가 아니다.
- 원본 연속 skin 로컬18종·표정 최종6종 준비와 실제 등록을 구분한다. `skin_import_batch.py`는 검증된 manifest/SHA로 inspect를 만들고, 실제 import의 정확한 ID/Bone/축/크기가 있어야 조립 payload를 만든다. 6종 준비 결과 실제1종/실제자료 대기5종, 오프라인66검사·payload8개 컴파일 정상. 교정 웨이트 후보는 원본 패키지와 별도 계약이며 자동 유료 재요청·추정 ID 연결·자동 승격은 금지한다.
- 최신 기록된 전체41 Luau 문법과 생산 client/ExpressionSkinContract 연결은 루트 검증 범위다. 옛 몬스터 에셋 경고/BigSlime 누락, HUD A·상점 GPT 선택, `MerchantEnabled=false` 실제 NPC 구매, 최종3D무기/전체18모션·표정, DataStore 닉네임 영속/다인 QA는 미완료다. API 리깅13신규325/최근 잔액4560/무료거절4는 이전 최신 수치를 유지하며 이번 skin 준비·검사는 로컬 무료 작업이다.
- **최신 실제 저장은 2026-10-04 03:49:02 KST / 10,505,779바이트**이며 `place/GoodEvil.rbxlx`에 동일 복사했다. 궁수 생산 등록의 새 Play에서 원래 source로 UI 선택→기본/공격 진지 `ExpressionReady=true`를 확인했고 Play-only trial 플래그는 없었다. Stop으로 QA 카메라/NPC/실험 복사본은 제거했다. 다른 place는 건드리지 않는다.
- Studio 백색 화면 복구용 **Native GraphicsMode Vulkan은 최종 종료 전에 원래 Automatic으로 복원해야 한다.** 전체 요청의 실제 완료·저장·커밋/push 전에는 Shutdown하지 않는다. 사용자 조건부 무료 초기화는 현재 **실제 사용0**이며 사용량3% 조건 전 사용하지 않는다. 유료 구매 승인은 아니다.

## 이전 작업 상태 (2026-10-04 02:09; 위 최신 기록이 우선)

- **게임용 아바타 1/18종이며 성기사 남성 표정 3종이 실제 연결됐다.** 기본121674541725480/진지104677901335263/미소133057889021878, Face mesh129632625883192/Head89786211556898. 실제 F·HP 감소→진지→기본, 임시 검증 NPC의 G 대화→미소, 대화 중 피격 진지 우선→미소 복귀→기본, OFF 원래 얼굴·ON/사망 뒤 기본을 확인했다. NPC는 승인된 기존 성기사 복사본/Play 전용/검증 HoldDuration0이며 실제 물약 상점 활성 완료는 아니다. 새 Head/Face를 기존 Ready에 승격하고 옛 Head 리그는 CostumeRigArchive에 보존했다.
- 단순 ID 문자열 Preload의 최초 Failure와 실제 MeshPart Preload를 구분한다. 실제 Head/Face/기본 atlas와 진지·미소를 적용한 별도 MeshPart는 모두 Success였다. 잘못된 문자열 검사를 삭제하거나 재업로드로 덮지 않았고 원기록도 남겼다. 실제 화면 기본 얼굴은 확인했으며 빠르게 캡처한 공격/미소 화면은 정확한 표정 타이밍을 보증하지 않아 단독 상태 증거로 쓰지 않는다.
- **HaloArcherM 3배치 가져오기·강체 Pending 조립은 완료했으나 시각 QA에서 관절 틈이 보여 승격하지 않았다.** 18메시15motor3weld, 실제 걷기/F/Q/OFF·ON/사망 복귀 기계적 검증과 외형 품질 검증은 별개다.
- **NeutralWarriorF 연속 skin 실제 가져오기·Pending 조립·단일 클라이언트 trial이 통과했다.** 원래2메시/2텍스처/14710면, 수동15bone+투명15R15proxy+15motor. 실제 Preload4개 Success, 걷기·점프·F/Q·OFF 원래 아바타·ON·사망 복귀/driver 재연결, 정면 외형을 확인했다. 최대 bone 오차 약1.19e-5stud. 아직 생산 모듈·성장/다른 클라이언트 QA 전이므로 Ready 승격0이다.
- 기존 유료 원본14종과 무료 거절4종을 합해 **연속 skin 로컬 후보18종**을 준비했다. 원본 위치·UV·재질 PNG/원래 웨이트를 보존한14종 실제 Blender6자세 검증은 독립LBS 최대1.908e-6stud였다. HornsMageF 뒤머리/코트·HornsArcherM 망토·NeutralArcherF 땋은 머리의 원래 웨이트 끌림은 별도 교정/실제 QA 필요. prepared 23패키지138파일133.624MB, 원본 복구3종 증거 포함. 로컬 통과를 게임 완료로 집계하지 않는다.
- **표정 rigid14종42PNG/84렌더 로컬 검증**, 별도 manual skin4종12PNG/24렌더는 눈썹 면 보강 중이다. 실제 업로드/게임 연결은 위 성기사 남성1종뿐이다. local_index는 로컬 목록이며 실제 상태는 본 문서와 actual 기록이 우선한다.
- 전체39 Luau 문법 정상→source1변경/38동일→15초 Play 서버23/23·클라이언트9 시작, Luau 오류 없음. 옛 몬스터 TexturePack/mesh 경고·BigSlime 누락·DataStore API 비활성·Developer Product2개 ID0는 남는다.
- **GoodEvil 실제 저장 2026-10-04 02:09:31, 9,005,089바이트**, place/GoodEvil.rbxlx 동일 복사. Pending/Import/Archive와 표정 Source가 저장됐고 Play 전용 QA clone/카메라/NPC는 Stop으로 제거됐다. 세부 증거: docs/art/costume_checkpoint_2026-10-04.md.
- Studio 엔진 화면이 백색으로 남아 네이티브 GraphicsMode를 임시 Vulkan으로 바꾸고 재시작해 정상화했다. **원래 Automatic을 최종 종료 전에 네이티브 설정으로 복원해야 한다.** emulator ActualSize는 복원했다. 제어는 필요한 화면 입력 직후 reset. 다른 place/Windows 설정은 건드리지 않는다.
- 사용자 지시: 전체 요청 실제 완료/저장/커밋/push 뒤 컴퓨터 종료, 미완료 종료 금지. 사용량3%일 때 보유 무료 초기화1회 조건부 승인(10월4일 만료분 우선 요청, 도구에 날짜 선택 없음). 현재 남은86%·무료4회·사용0, 유료 구매 승인 아님.
- HUD/물약 상점 GPT 선택, 나머지17종 실제 avatar/전체18모션/표정, 몬스터 복구, 무기 최종3D, DataStore·다인 QA 등 미완료 요청은 아래 다음 단계대로 계속한다.

## 이전 작업 상태 (2026-10-03 성기사 남성 연동 당시)

- 사용자 지시: 전체 요청을 계속하고, 모두 실제 검증·저장·커밋/push한 뒤 컴퓨터를 종료한다. 미완료 상태에서 종료하지 않는다. 남은 Codex 사용량3% 때 보유 무료 초기화1회 사용을 조건부 승인했다(10월4일 만료분 우선 요청; 도구는 날짜 선택 필드가 없어 확인 필요). 최근 남은95%/무료 초기화4회, 실제 사용0. 유료 크레딧 구매 승인은 아니다.
- **성기사 남성1종은 게임용 `ServerStorage.CostumeRigs.Costume_HaloWarriorM`에 승격됐다.** 18메시/15관절/3weld, 검증 Animate. 실제 진영·직업 선택만으로 기본 ON 적용, F/Q 관절 동작, 죽음 뒤 ON 재생성, B메뉴 OFF→원래 계정 아바타→ON을 확인했다. 남녀18종 전체 완료는 아니다.
- **OFF 밀림은 엔진 `LoadCharacterWithHumanoidDescriptionAsync` 복귀로 수정했다.** 실제 OFF 안정46샘플/XZ드리프트0/속도<1/Running, 이후 걷기25stud·점프 정상. HP/MP 자연 회복과 외형 변경 초기화를 구분한다. 28개 오프라인 상황365검사는 원본 RigType·HP/MP/재고/CD/기존 ForceField·이동기록, 지연·실패·퇴장·죽음·중복 리스폰을 확인했다. 실제 R6 계정은 별도 확인 필요. 실패한0.25초 ownership 실험은 현재 소스/Studio에서 제거됐다.
- 실제 성기사 클라이언트 PreloadAsync는 **153콜백 전부 Success**였다. 서버 GetAssetFetchStatus의None은 실패 증거가 아니다. 실제 텍스처/ON·OFF 화면 및 상세 결과: `docs/art/costume_checkpoint_2026-10-03.md`.
- 나머지17종 리깅 승인 상한425 중 **13종 성공325크레딧**. Head/Body 오브젝트 포장만 합친 무료 재검사로 HaloWarriorF/HaloMageM/HaloMageF3종이 통과해 최초 리깅75를 추가했다. API 최근 잔액4,560, 실제 누적440(해골30+왕60+pilot25+신규325). 승인 상한을 실제 청구로 집계하지 않는다.
- 남은 HaloArcherF/HornsArcherF/NeutralWarriorF/NeutralArcherM4종은 merged 및 원본raw2k 무료 검사도 false/청구0. 승인 원본을 보존하는 수동 R15 가능성 조사 중. 자동 유료 재요청/재생성하지 않는다. API ledger writer는 루트만.
- HornsMageM 비인접 웨이트1면·HornsMageF 빈 왼팔·NeutralArcherF 낮은 root는 원본 UV/표면/normal을 보존한 로컬 복구를 통과했다. HornsArcherM의 앞얼굴112면 잘못된 body 분류도 별도 복사본에서 바로잡았다. **신규 Halo3은 Tripo rig에서 Head 재질이 Body 재질로 합쳐진 오류 발견으로 업로드 보류**, 원본 fixed의 실제 면 대응으로 UV/재질 복원 중이다. 로컬 변환/정지 렌더를 Roblox 동작 완료로 쓰지 않는다.
- 물약 재고/구매 서버·NPC 준비·수량 UI 소스는 연결됐다. 신규/기존0개,99상한,HP30%/MP40%,종류별10초CD,서버 정확한 NPC/prompt/활성/12stud·1/5병·임시각10G·실제 회복 때만1개 소비. 실제 소스 오프라인929검사 통과. **상인 `MerchantEnabled=false`, 구매 화면 미구현**이며 가격/화면 GPT 선택 대기다. 현재 무료 재사용으로 표시하지 않는다.
- **실제 키1/2로 HP/MP 각2개→1개**, 각각CD설정·수량/상태 표시·TextBounds 정상 확인.0개는'구매'/비활성,가득 찼을 때'가득'/비활성. 실제 NPC 구매·영속 재접속·죽음/괴수 등 전 조건 실검증은 아직이다.
- 새 HUD `UI_Gameplay_Cleanup_A_v2.png`와 상점 `Potion_Shop_A.png`는 사용자에게 표시했지만 선택 대기. 선택 전 새 화면 스타일/레이아웃을 적용하지 않는다.
- 표정 파일럿 포함7종21장/42프리뷰가 로컬 검증됐다. 파일럿 최종 Head SHA `d8000e76a841f1d4675a8dbfc202168ec938551fdcf6e4e6bbeccff41c974611`, 실제 rig 좌표 최대 오차1.1845e-7. **ExpressionAssets 실제 등록0종**, 새 얼굴 업로드·실제 전투/피격/대화 전환은 남았다. 신규Halo3 표정은 UV복구 뒤 진행한다.
- 무기 Fx/CharacterVisuals는 실제 관절/왼손활/오른손당김·현재 muzzle을 보강했고 실제 소스 오프라인253검사 통과. 그러나 **임시3D 무기와 남녀18종의 최종 모션은 사용자 요구 미완료**다. 아이콘27개 연결·파일럿 F/Q 움직임만으로 완성 처리하지 않는다.
- 전체39 Luau 문법 통과, 최신 sync는4변경/35동일 후 Shop검증1변경/38동일.15초 Play 서버23/23·클라이언트9, Luau 오류 없음. Goblin/GoblinBrute/Skeleton 옛 에셋 경고·BigSlime 새 계정 모델 누락은 남았다. 슬라임fallback 투명도0은 소스 수정됐고 최종 실제 화면 확인 필요.
- Noto Sans12187370747/글자PNG OFF/991×475 글자 범위, 닉네임790오프라인 및 실제 Unavailable·draft 재오픈은 이전 통과. DataStore API는 Studio에서 아직 꺼져 영속 저장·전 서버 중복 경쟁은 미검증. 닉네임Toast root.ZIndex96 수정·1590 최종화면·폰트 소유권 추가도 후속 확인한다.
- 아래20:07 상태는 **이전 기록**이다. 현재 게임용1종/리깅325/잔액4560/물약929가 우선한다. 저장본 시각·용량은 최신 체크포인트 문서에 기록한다.
- 컴퓨터 제어는 실제 화면 입력 때만 켜고 곧바로 reset한다. Codex 질문 알림이 Import 버튼을 가려 직접 닫기 요청 중이다. 미리보기는 일단 닫아 소스 검증을 계속하며 첫 HaloArcherM 배치는 아직 업로드0. 다른 place는 건드리지 않는다.

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

## 2. 이전 구현 기록 (20:07 당시; 최신 상태는 문서 상단)
### 코드 (`src/`, 약 2.6만 줄)
- 이번 작업 라운드는 **부분 완료**다. 최신 기록된 기본 검증은39 Luau 문법, 동기화22개 변경/17개 동일,15초 Play 서버23/23·클라이언트9 정상 시작, Luau 런타임 오류 없음이다. 이후 닉네임 입력/Unavailable 안내/재오픈 보존은 실제 통과했고 오프라인 닉네임790개·코스튬 물리86개 검사는 통과했다. HP/MP 버튼 회복·중복 클릭 방지와991×475 선택/HUD 글자 범위도 통과했다. Toast 겹침 ZIndex96 패치, 키1/2·자원 거절/리스폰 보존·3직업 최종 모션·1590 최종 화면·OFF 밀림·최신 소스 저장/커밋은 남아 있다.
- 완료된 큰 작업 (자세한 계약은 SPEC_ADDENDUM):
  - A12 지도(WorldMap), A14 컴팩트 HUD, **GPT HUD 재디자인**(양피지+장난감, `Config.UIArt` + UIKit 아트 도우미)
  - **진영/직업 고르기 화면 재디자인**(GPT 카드, 남/여 전환, 능력치 5칸: 성기사 4/3/2, 마법사 2/4/3, 레인저 3/2/4)
  - **A15 타격감 + 아파하는 반응**(몬스터 예비 동작 `WindupAt`, 피격 `HurtSeq`, 플레이어 `Pain` Fx, 밀려나기, 베기 궤적, 히트스톱, 스티커)
  - 진영 고르기 전 팀 "진영 고르는 중"
  - **A17 새 계정 그림 연결 + 코스튬 코드**: UI/효과/스티커 78개, 고정 글자 42개, 무기 아이콘 27개, 지형 텍스처 15개, 지도 양피지 1개 = 새 ID **163개**를 기록하고 Config에 연결했다(이후 물약 2개로 165개). 글자 이미지 ID와 `UIKit.BindArtText` 로드 실패 대체 계약은 보존하되, 사용자 새 글꼴 요청에 따라 현재 `UseTextImages=false`로 실제 글자를 표시한다. 무기 업그레이드 아이콘은 현재 직업·다음 티어·진영을 따른다.
  - 코스튬 선택/기본 ON/B 메뉴 OFF/서버 교체와 준비 상태 표시는 준비됐다. 성기사 남성 pilot 18메시를 `CostumePendingRigs`에 조립하여 걷기·점프·F/Q 관절 움직임·죽음 뒤 ON 재생성을 확인했다. **OFF 외형 복귀 때 물리적 밀림이 남아 게임용 `CostumeRigs` 승격은 0종**이다. 누락된 템플릿은 기존 Roblox 아바타로 플레이한다.
  - 선택 화면은 사용자 승인 **GPT A안**의 중앙 구도·동일 시각 카드 폭·버튼 기준선을 따른다. 초기 나눔고딕 선택은 이후 사용자 요청으로 **Noto Sans `12187370747`**로 대체했다. 설명 중앙 정렬·Regular 본문·Bold 제목·짧은 동일 뜻 문구와 최소 물리 11px를 적용했다. 991×475 실제 글자 범위는 통과했으며 1590 최종 확인은 남아 있다.
  - **A18 HP/MP·물약**: 승인 HUD의 XP 아래 HP/MP·카드 아래 물약·그 아래 퀘스트를 유지한다. 키1/2 또는 버튼 사용, HP30%/MP40% 회복·종류별10초CD다. 처음의 무료 재사용 기본값은 **최신 사용자 NPC 구매/수량 표시 요청으로 대체**했다. 구매형 서버 소스는 로컬 준비됐고 NPC·수량UI·실구매는 아직 미연결이다. MP100·초당4 회복, 마법사 공격3MP·모든 직업 발사20MP와 부족 MP의 charge/CD 보존은 유지한다.
    - 실제 Halo/Mage 선택→Studio DebugCommand로 HP19.2/최대96·MP20 설정→HP/MP 버튼 각각 클릭. HP물약 +28.8, MP물약 +40 및 각 now+10초 deadline 확인. 자연 회복을 포함해 첫 확인 HP68/MP64, 반복 클릭 뒤 HP78/MP68.1이었다. 두 deadline은 반복 전후 같고 추가 물약 회복 없이 자연 회복만 계속됐다. 두 버튼에 "9초" 표시. 증거 `build/vitals_play_verify_result.json`. **키1/2는 아직 미검증**이며 나머지 거절/MP 비용/리스폰·외형 보존도 별도 확인한다.
  - **A19 직업별 모션**: 사용자 승인 `Motion_Class_Attacks_A.png`대로 전사 베기/내려찍기, 궁수 왼손 활·오른손 시위 당기기/연사, 마법사 왼손 기 모으기·오른손 지팡이 발사/운석 모션 코드 준비. 발사 순간 현재 무기 muzzle을 읽고 캐릭터/직업/진영 변경 시 오래된 지연 동작을 취소한다. 기존 서버 피해/타겟/charge 판정은 유지하며 MP 규칙만 A18을 따른다. 실제 3직업 모션은 아직 최종 플레이 검증 미완료.
  - **A20 표정**: Neutral/Serious/SoftSmile을 서버 전투·피격·대화 조건에 연결했다. 검증 표시가 있는 별도 얼굴 메시와 UV별 3개 ID가 필요하다. 원본 Head atlas를 덮지 않으며 **실제 등록 0종**이다.
  - **A21 게임 닉네임**: Unicode2~20글자·방송 필터·전 서버 중복 예약·불확실 token 복구·한정 안전 규칙과790개 오프라인 검사를 통과했다. B 메뉴 실제 입력/Unavailable 안내/닫기 재오픈 보존은 통과했다. 원문은 다른 사용자/HUD에 노출하지 않는다. Toast 겹침 수정 재검증과 영속 저장/다인 경쟁은 남아 있다.
- **코드 리뷰 R1 수정(HIGH 2 / MED 27 / LOW 51)**: 2026-10-03 GoodEvil에서 전체 33개 Luau 문법 정상 → 동기화 29개/동일 4개 → 15초 플레이 테스트를 완료했다. 서버 19/19와 ClientMain 클라이언트 8개 모듈이 정상 시작했으며 이번 검증에서 Luau 런타임 오류는 없었다.
  - 실제 UI로 빛의 기사단·성기사 선택, B 메뉴의 말랑 초원 이동, M 지도 열기/닫기·확대·내 위치, F 수동 전투, Q 발사, R 자동 공격, 안내 퀘스트 받기 중복 방지, 거위 공격, 괴수 Siren→Active를 확인했다. 거위 시작·괴수 별 5개·자동 공격용 레벨 5는 Studio 디버그로 설정했다.
  - 결과와 화면은 `docs/review/r1_studio_verify_2026-10-03.md`, 원본 체크리스트는 `docs/review/reviewer_code_r1.md`, 계약은 `docs/SPEC_ADDENDUM.md` A16을 본다.
  - 당시 DataStore API 미활성으로 메모리 모드였다. 저장·재접속/PairCD·다인 PvP·괴수 퇴장 정산·이동 오탐 조건 전체는 여전히 미검증이다. 새 계정 2D/지형은 이후 별도로 연결했지만 3D 전체 복구는 미완료다. 최신 Play에서 GE_Grass TexturePack 경고는 없어졌고 Goblin/GoblinBrute/Skeleton 에셋 경고는 남아 있다. Developer Product ID 0 해결은 확인하지 않았다.
  - CR-H2(위치 검증)는 `Config.AntiCheat.Enforce = false`(로그만)를 유지한다. 메뉴 이동·리스폰·낙하 구조·덩치 변화·적 마을 튕김 등 오탐 조건 전체를 확인한 뒤 켠다.

### 아트 (`art/`)
- `art/prompts/<id>.txt` = 프롬프트, `art/out/<id>.png` = GPT 결과, `art/approved.json` = 사용자 승인 기록.
- UI 부품: `art/out/UIP_*` → 다듬은 것 `art/ui/UIP_*.png`, 크기/9-slice `art/ui/ui_meta.json`. UI 68개+효과/스티커 10개는 새 계정 업로드·ID 연결 완료(`art/ui/asset_ids.json`, `Config.UIArt.Parts`).
- 그림 글자(이전에 승인한 **C 스타일 = 금색 판타지 로고**): 새 계정 업로드/ID 연결 42개는 보존했다. 사용자의 최신 글꼴 변경 요청으로 현재 `UseTextImages=false`이며 Noto Sans 실제 글자를 표시한다. 향후 이미지 사용 시에도 정확한 단어 일치·실제 로드 성공만 원글자를 숨기고 숫자·동적 문구·미로딩은 원문을 유지한다.
- 효과/스티커: `UIP_Fx*`(베기, 불꽃, 링, 마법, 먼지), `UIP_Emo*`(아야!, 눈물, 어지러움, 화남, 스트레스). 새 ID 연결 완료, 코드 대체 그림도 유지.
- 무기 아이콘 27개 `Weapon_<Class>_<T1..T6|T7_Halo|T7_Horns|T7_Neutral>.png`: 원본 그대로 새 ID 연결 완료. `Config.WeaponArtKey` + HUD 업그레이드 카드 코드 준비. 상점 등 전체 화면 적용 완료로 간주하지 않는다.
- **지형 텍스처 15개 + 지도 양피지 1개 업로드/ID 연결 완료**: 이전 `texture_01` unknown 10개는 종료된 Studio 확인 및 retryHistory를 남긴 뒤 명시 재시도 도구로 모두 complete. `texture_02` 5개, `map_01` 1개도 complete. 실제 응답으로 `Tex_Grass=78282434254609`, `Tex_LeafyGrass=97617252360457`, 지도=`133911744102396` 확정. 공개 썸네일의 픽셀 비교로 정한 값이 아니다. **MaterialVariant 15개/기본 재질 override 12개/도로 3개 실제 적용 완료**. 옛 GE_Grass를 새 Instance로 교체(GrassReplaced=true)한 뒤 이번 Play에서 GE_Grass TexturePack 경고가 없어졌다. 왕슬라임은 아직 새 계정 3D 연결 미완료.
- 직업 캐릭터 그림 18장 `UIP_Char<Faction><Class><M|F>.png` (뿔 6명·빛 여궁수는 노출 없게 다시 그림), 코스튬용 차렷 자세 `APose_*.png` 18장.
- 승인된 시안: `UI_HUD_Final.png`(HUD), `UI_Faction_B.png`(진영), `UI_Class_A.png`(직업), `UI_Lettering_C.png`(글자).
- 추가 승인: `UI_Faction_Layout_A.png`(최신 중앙 균형 구도), `UI_HUD_Vitals_A.png`("어휴 너무 좋지"), `Motion_Class_Attacks_A.png`("좋았으"), **`Nickname_Form_A.png`("ㅇㅇ좋아")**. HP/MP 병 2장은 root가 한 장씩 확인·사용자 표시 후 업로드했다. `Config.UIArt.Parts.IconPotionHP=100061379621289`, `IconPotionMP=133725941898063`이며 기존163+2=새 계정 **2D165개**다. 닉네임 시안 자체는 업로드하지 않고 기존 승인 부품을 재사용했다.
- `docs/art/verification_2026-10-03/faction_a_nanum_1590.jpeg`는 수정 도중 실패 화면이다. 이후 중앙 정적 카드·짧은 문구·물리 11px/전체 FontFace 문장 측정을 보강하고 Noto Sans로 바꿨다. 최신 991×475 선택/HUD TextBounds는 칸 안에 들어오며 Noto 적용 후 최종 1590 화면 확인은 남아 있다.
- **`art/out/v1/` 은 버린 그림. 절대 업로드 금지** (특히 `art/out/v1/revealing/`).

### 3D (`art/models/`)
- 몬스터 Tripo 모델: Slime, Goblin, GoblinBrute, Skeleton, SkeletonKnight, GoldenGoose(심술궂은 v2), SkeletonKing(보스, 게임에 아직 없음).
- Slime과 기존 Goblin/GoblinBrute 디자인은 유지한다. 해골만 사용자가 고른 옷 입힌 그림으로 교체한다. 옷 입힌 해골·왕 GLB 생성은 완료했지만 Roblox 가져오기/게임 연결 완료로 기록하지 않는다.
- 직업 코스튬 18명: `art/models/costume/fixed/Costume_<Faction><Class><M|F>.glb` (Tripo 2k → `tools/fix_face.py`: 머리 분리 + 머리 전용 1024 텍스처 + 샤픈). 원본 2k는 `raw/`(깃 제외), Tripo 작업 번호는 `tripo_tasks.json`.
- 성기사 남성 pilot은 무료 재등록·무료 rig-check·25크레딧 biped/Mixamo 리깅 후 3배치 **18메시 모두 Importer로 가져와 `CostumePendingRigs`에 조립**했다. 걷기·점프·F/Q 관절 움직임·죽음 뒤 ON 재생성은 확인했으나 OFF 복귀 때 밀림이 남아 게임용 `CostumeRigs` 승격은 **0종**이다.
- 이전 `Darugi_S2` Halo/Mage/F의 `MissingTemplate` 진단은 당시 폴더가 없던 과거 결과다. 현재 검증 controller와 pilot 대기 리그가 있다. 다른 직업 템플릿이 없으면 계속 원래 아바타를 사용하며 기본 ON은 실제 적용을 뜻하지 않는다.
- 사용자 추가 승인한 나머지 **17종/최대425**는 무료 import/검사 완료, 유료 리깅 **10종/250** 완료, **7종 riggable=false/0청구**다. 신규 10종 중 strict R15 분할 **8종**은 로컬 준비됐고 HornsMageM(Head/왼팔 동일 웨이트 1면), HornsMageF(빈 LeftLowerArm) **2종은 보류**했다. 이 신규 결과의 Roblox 업로드·조립·승격을 완료로 쓰지 않는다. 세부 목록은 `docs/art/costume_rig_plan_2026-10-03.md`.
- Batch01 임시 clone은 이후 9개 에셋 PreloadAsync 성공, 얼굴·눈·갑옷 텍스처 정상 표시를 확인했다(`docs/art/verification_2026-10-03/costume_texture_studio.jpeg`). 이것은 정적 메시/텍스처 확인이며 R15 움직임 검증이 아니다.
- 기본 R15 Animate는 실제 기본 캐릭터에서 캡처 후 설치된 Roblox engine의 `.rbxm` Source와 **바이트 일치**를 확인했다. vendor 보존/오프라인 검사 후 root의 `install_animate.py --apply`가 **실제 설치·검증 완료**: `ServerStorage.CostumeAnimationControllers.R15`, 전체 61노드/Source 28,802자, SHA256 `49eab7530cfc33b8af13b995ae1fa87f482a489b6d108ec2410d12dd19b720f0`. 감사 기록은 `build/costume_r15/animate_install_20261003T073704Z_4ef76cd9.json`(complete). 이것만으로 코스튬 리그는 완성되지 않는다.
- EditableMesh 무료 검사: 기존 LeftLowerArm 431면/UV 최대 오차0/위치 최대 오차1.237e-7, LeftLowerLeg 850 vertices/596 faces/모든 오차0. **CreateAssetAsync 실제1회는 "CreateAssetAsync and CreateAssetVersionAsync are not available yet" 예외**다. 이 API 경로의 성공0/재시도0/ledger Unknown은 보존하고 반복하지 않는다. 이후 **파일 Importer 경로로 pilot18메시를 모두 가져왔다**. 두 경로의 결과를 혼동하지 않는다. 사용자 요청대로 별도 Sky 창은 열지 않았다.
- 몬스터는 스튜디오 place의 `ServerStorage.CustomModels.<Id>`에 넣으면 `MonsterService`가 자동으로 겉모습으로 씀(A1). 3D 가져오기: 스튜디오 3D Importer → 이름 정확히 → 크기 맞추고(슬라임 ~5, 고블린 5.5, 우두머리 8, 기사 7) 정면이 -Z인지 확인 → `ServerStorage.CustomModels`로 이동 → 저장(ctrl+s) → `build/GoodEvil.rbxlx`를 `place/`로 복사해 커밋.
- **마지막 확인 저장본**: GoodEvil Edit에서 2026-10-03 **20:07:18**, `build/GoodEvil.rbxlx` 7,457,604바이트를 확인하고 `place/GoodEvil.rbxlx`로 복사했다. 이때 controller/pilot 대기 조립을 저장했다. 이후 닉네임 창/정책 등 최신 소스 변경은 재동기화·검증·저장·복사가 필요하다. 몬스터 전체 새 계정 복구 완료로 쓰지 않는다.

### 계정 / 업로드 상황 (중요)
- 2026-10-03 옛 로블록스 계정 1일 정지(노출 그림). 사용자는 **새 계정을 계속 쓰기로 함**.
- 옛 계정이 올린 것은 새 계정 게임에서 안 보일 수 있다 → **같은 파일을 새 계정으로 다시 업로드/가져오기**(새로 만들 필요 없음). 사용자가 **2026-10-03 오늘부터 허용**했다("아니야 오늘부터 해도 돼"). 원래 10-04 제한은 해제됐다.
  - UI78+그림 글자42+무기27+텍스처15+지도1+물약2 = **2D165개 업로드/ID 연결 완료**, `Config.UIArt.Parts`와 `art/ui/asset_ids.json` 새 ID 반영. HP/MP UI와 물약 gameplay 완료는 별도 검증한다.
  - MaterialService 15종/override 12종/도로 3개 새 ID 적용 완료. 나머지 몬스터/코스튬의 완전한 3D 가져오기·플레이 연결은 미완료.
  - 업로드 전 한 장씩 확인 → 사용자에게 보여 주기 → 10장 이하씩 나눠서.

## 3. 다음에 할 일 (최신 사용자 우선순위)

1. 궁수 FaceUnionBinding 후보의 Serious 입3D홈/웃는 음영 외형 HOLD를 먼저 해결·확인한다. 남은17종 직업 코스튬은 승인 원본 연속 skin/최종3표면을 한 장씩 확인·표시한 뒤10개 이하 Importer→실제 ID/Bone/축/크기→BindingSchema1 같은 Model 내부 그래프→별도 Pending→걷기/점프/F/Q/성장1→2→1/ON·OFF/사망·Native 실제 표면 변형/얼굴 품질 QA→승격한다. 성기사 Ready와 궁수 legacy 등록본/원본2표면·강체 Pending을 보존하며 legacy를 새 gate에 우회 연결하지 않는다. 교정 웨이트3종은 별도 원본/교정 SHA 계약으로 검증한다.
2. 남녀18종 전체 전사·궁수·마법사 최종 무기/활 시위·당김·발사·지팡이 실제 muzzle/원본 Animate 공존 검증. 임시 무기 시각 요구를 완료로 처리하지 않는다.
3. 승인된 기본/진지/미소 얼굴을 남은17종 모델별 UV·실제 큰 피격 표면 변형·표정 외형 검사→한 장씩 표시→소량 업로드→ExpressionAssets 등록→전투/피격/대화 우선·OFF 얼굴 복귀 검증. Bone/Preload 수치나 과거 Ready2 기록을 얼굴/모션 품질 승인으로 간주하지 않는다. 악 궁수는 원본 앞얼굴112면과 교정 웨이트 계약도 함께 확인한다.
4. 사용자 HUD A/물약 상점 GPT 선택 답변 후 정확히 구현. NPC 활성/실제 G→1·5병 구매/거리·돈·99상한·회복소비·버튼/단축키/CD·재접속 확인. 준비중 가격을 사용자 확정 가격으로 쓰지 않는다.
5. Goblin/GoblinBrute/선택된 옷입힌 Skeleton/BigSlime 새 계정 복구, 실제 불투명 슬라임 화면. SkeletonKing은 파일 준비됐지만 보스 게임 설계는 아직 후속이다.
6. 선택·HUD1590/991/짧은 높이·터치44px·닉네임Toast/필터/영속 저장·전 서버중복 경쟁. Studio API 보안 설정은 사용자 직접 작업 필요(컴퓨터 제어 규칙). R1 다인PvP/PairCD·괴수퇴장·이동오탐 후 AntiCheat.Enforce 활성 여부 검토.
7. 기존 다음 설계: 해골왕 보스,재료/제작/거래소2단계경제는 ADDENDUM 계약부터. 실제 요청과 완료 경계를 유지한다.
8. 라운드별 GoodEvil/Edit→문법/동기화/Play→저장→place복사→커밋/push. 모든 요청이 실제 완료된 뒤에만 사용자의 종료 지시를 실행한다. 사용량3% 조건일 때만 승인된 무료 초기화1회 사용, 자동 유료 구매 금지.

## 4. 그림 → 게임 파이프라인
1. 프롬프트 `art/prompts/<id>.txt` 작성(캐릭터는 단정한 옷차림 문구 필수) → 생성 → `art/out/<id>.png`.
2. 사용자에게 보여 주고 고르게 함 → `art/approved.json` 기록.
3. UI 부품이면 `py tools/prep_ui.py <id>` → `art/ui/` → 업로드(로컬 http 서버 + `upload_image`) → `Config.UIArt.Parts`에 `{ Id, Size, Slice }`.
4. 3D면 Tripo(API: `tools/tripo_api.py`, 웹: studio.tripo3d.ai) → 텍스처 2k로 → `tools/fix_face.py`(캐릭터) → 스튜디오 3D Importer.

## 5. 이전 Tripo 실행 기록 (최신 비용은 문서 상단)
- 마지막 확인 API 잔액 **4,635크레딧**, 누적 실제 청구 **365 = 옷 입힌 해골30 + 왕60 + pilot25 + 추가10종×25**. 신규17종 무료 import/rig-check와7종 riggable=false 거절에는 청구가 없다. 웹 스튜디오 과거 잔액과 별개다. API 키는 git 제외 `.env`에만 보관한다.
- 나머지17종 최대425는 사용자 명시 승인을 받았으며 실제 유료 실행은10종250으로 종료했다. **승인 상한425를 실제 청구량으로 쓰지 않는다.** 완료/거절/불확실 상태는 `art/models/tripo/records.json`, `build/costume_r15/rejected_7_readonly_audit.json`, `docs/art/costume_rig_plan_2026-10-03.md`를 따른다. 자동 유료 재요청 금지, API/업로드 ledger writer는 하나만 둔다.
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
