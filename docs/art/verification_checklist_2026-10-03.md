# 아트·코스튬·닉네임 실제 검증 체크리스트 — 2026-10-03

> 기록용(2026-10-09 검수): 2026-10-03 체크리스트다. 코스튬 18종·표정·GPT 시안 항목은 치비 코스튬 제거(SPEC A23-5)와 Firefly 전환(A23-7)으로 진행하지 않는다. 지금 할 일은 docs/handoff/role_prompts/에 있다.

이 기록은 `HANDOFF_CODEX.md` 상단 최신 결과와 실제 검증 범위를 구분한다. 그림 승인·소스 준비·로컬 변환·기본 Play 시작을 최종 화면/동작 완료로 대신하지 않는다. 새 시각 디자인은 GPT 그림을 사용자에게 보여 주고 선택받은 뒤 구현한다.

최신 우선순위는 직업 아바타 나머지17종 연동과 남녀18캐릭터 직업별 실제 모션이다. **성기사 남성1종은 게임용 등록과 실제 ON/OFF 안정 검증을 통과했다.** 실패한 ownership0.25초 지연 실험은 현재 소스/Studio에서 제거됐다. 새 HUD와 물약 상점 GPT 시안은 아직 사용자 선택 대기다.

## 현재 확인된 결과

- [x] 새 계정 2D 165개 ID/배치 기록 연결: UI·효과 78, 글자 42, 무기 아이콘 27, 지형 15, 지도 1, 물약 2.
- [x] 지형 MaterialVariant 15개/기본 override 12개/도로 3개 적용. GE_Grass를 새 Instance로 교체한 뒤 해당 TexturePack 경고는 재현되지 않음.
- [x] 최신 기본 검사: 39 Luau 문법 정상, 동기화 변경4/동일35 후 Shop 검증 변경1/동일38, 15초 Play 서버23/23·클라이언트9 시작, Luau 런타임 오류 없음. 이후 변경은 다시 검사·동기화·저장한다.
- [x] 최신 Noto Sans 선택 화면/HUD의 991×475 실제 TextBounds가 각 칸 안에 들어옴. 글자 PNG 사용 OFF, 기존 승인 아트 유지.
- [x] HP/MP 물약 버튼 회복량·종류별10초 deadline·재클릭 deadline 유지 확인. 최신 실제 키 **1=HP/2=MP가 각각 재고2개→1개**를 소비하고 별도 CD를 설정했다. 수량/상태 TextBounds는 칸 안에 들어온다. 자연 회복은 물약 회복과 구분한다. 증거: [키1/2 실제 결과](verification_2026-10-03/reports/potion_native_keys_actual.json), [수량 화면](verification_2026-10-03/potion_stock_keys.jpeg).
- [x] 성기사 남성 `ServerStorage.CostumeRigs.Costume_HaloWarriorM` **게임용1종 승격**: 18메시/15관절/3weld, 검증 R15 Animate. 실제 진영/직업 선택만으로 기본 ON, B메뉴 OFF→본인 아바타→ON, 걷기·점프·F/Q 관절 움직임·죽음 뒤 ON 재생성 확인. 증거: [기본 선택 적용](verification_2026-10-03/reports/production_costume_smoke_actual.json), [ON/OFF·전투·리스폰](verification_2026-10-03/reports/pilot_final_qa_actual.json), [ON 화면](verification_2026-10-03/pilot_on_final.jpeg).
- [x] OFF는 엔진 `LoadCharacterWithHumanoidDescriptionAsync` 복귀로 수정. 실제 `old=false/status=Avatar/t>=5`의 안정 **46샘플/XZ드리프트0/속도1 미만/Running**, 이후 W 걷기 약25stud·점프 정상. 복귀 직후를 포함한 전체64샘플과 안정46샘플을 구분한다. 증거: [OFF 추적·이동](verification_2026-10-03/reports/qa_owner_live_result.json), [OFF 화면](verification_2026-10-03/owner_off_stable.jpeg), [최신 체크포인트](costume_checkpoint_2026-10-03.md). 실제 R6 계정과 나머지17종 복귀는 별도 확인한다.
- [x] 성기사 클라이언트 실제 PreloadAsync **153콜백 모두 Success**. 서버 GetAssetFetchStatus의 None만으로 실패 판정하지 않음. 증거: [실제 클라이언트 로드](verification_2026-10-03/reports/pilot_client_preload_actual.json).
- [x] 사용자 나머지17종 최대425크레딧 승인 중 실제 **13종 리깅/325크레딧**. 기존10종250에 무료 포장 병합 검사로 통과한 HaloWarriorF/HaloMageM/HaloMageF3종75를 추가했다. 남은4종 무료 검사 false/유료 청구0. 누적 실제 청구440, 마지막 API 잔액 **4,560**. 승인 상한425를 실제 청구로 쓰지 않는다. 증거: [추가3종 결과](verification_2026-10-03/reports/merged_three_rig_results.json), [원본4종 무료 검사](verification_2026-10-03/reports/free_raw_four_checks.json).
- [x] 오프라인 실제 소스 검사: 원본 아바타 복귀 **28상황/365개**, 물약·NPC **929개**, 무기·모션 **253개**, 도구 **55개** 통과. 기존 닉네임790개·코스튬 물리86개 통과도 보존한다. 오프라인 통과는 남은 Roblox 실제 동작·영속 저장을 대신하지 않는다. 증거: [복귀 검사](verification_2026-10-03/reports/owner_restore_offline_report.json), [물약 검사](verification_2026-10-03/reports/potion_offline_report.json).
- [x] 승인 `Nickname_Form_A.png`("ㅇㅇ좋아") 실제 B 메뉴 창 열기→성기사별 입력→저장→Unavailable 안내→닫기 재오픈 draft/메시지 유지 통과. `NicknameVerified=false`/확정 값 빈 문자열 유지. 증거 `build/nickname_ui_qa_actual.json`, `verification_2026-10-03/nickname_unavailable_991.jpeg`.
- [x] 물약 구매 서버·NPC 준비·수량 UI 소스 연결: 신규/기존0재고·1/5병·임시각10G·99상한·실회복1병소비·10초CD·저장/mirror. 구매와 G prompt 모두 정확한 `workspace.Map.NPCs.PotionMerchant`/PrimaryPart/Prompt/Enabled·살아 있음·준비 상태·유한 거리12stud·rate를 서버에서 검증한다. **`MerchantEnabled=false`를 유지**하며 상점 GUI/실제 NPC 구매는 미완료다. 임시 가격을 사용자 선택값으로 기록하지 않는다.
- [x] HornsMageM 비인접 웨이트1면·HornsMageF 빈 왼팔·NeutralArcherF 낮은 root 및 HornsArcherM 앞얼굴112면 분류는 원본 표면/UV/normal을 보존하는 로컬 복구를 통과했다. Roblox 실제 동작 완료는 아니다.
- [x] 표정 파일럿 포함7종21장/42프리뷰 로컬 준비 검증. 실제 `ExpressionAssets` 등록은 **0종**이며 업로드/게임 표정 전환 완료로 쓰지 않는다.

## 선택 화면·HUD·닉네임

- [ ] 최신 Noto Sans의 1590×637 최종 선택 화면/HUD: 3카드 정적 전체 표시·동일 시각 폭·버튼 기준선·설명 중앙·글자 겹침 없음.
- [ ] 991×475 재검증과 휴대폰/짧은 높이: 최소 물리 11px, 원문/짧은 동일 뜻 문구의 전체 폭·높이, clip/스크롤 범위 확인.
- [ ] 닉네임 Toast 겹침 수정(root.ZIndex96) 이후 현재 이름·제목 가림 없음 재검증. 최종 크기별 넘침/터치44px 전체 버튼 영역 확인.
- [ ] 닉네임 저장 중 연속 요청 차단, remote 없음 메시지, 성공한 검증 값만 HUD/이름표 반영. 저장소 Unavailable/재입력 보존은 위처럼 통과함.
- [ ] 닉네임 필터 실패·영속 저장/재접속·Unknown token 복구·다인/전 서버 동일 이름 경쟁·새 한정 안전 규칙 실검증. 정상 성기사 이름 허용 확인.
- [ ] MP 부족 때 공격/발사 charge·cooldown 보존, dead/kaiju 등 거절, 리스폰과 외형 교체의 mana/재고/물약CD 보존 전 조건 실검증. 실제 키1/2 각각1병 소비와 수량 표시 통과는 위에 분리했다.
- [ ] 새 HUD `UI_Gameplay_Cleanup_A_v2.png` 사용자 선택 후 화면 정리. 미승인 레이아웃은 적용하지 않는다.
- [ ] 물약 `Potion_Shop_A.png` 사용자 선택 후 구매창 연결·상인 활성화. 현재 `MerchantEnabled=false`/GUI 미구현. 기존 승인 성기사 남성 외형을 재사용하며 새 NPC 디자인은 만들지 않는다.
- [ ] 실제 NPC G 열기·1/5병 구매·골드/수량·99상한·위조/거리/비활성 거절·DataStore 재접속 실검증. 수량 UI는 서버 값을 표시하고0개는 '구매'/비활성, 가득 찬 자원은 '가득'/비활성으로 연결됐으나 실구매와 영속 재고는 미확인이다.
- [ ] 최신 소스 전체 문법→동기화→Play→GoodEvil 저장·복사·커밋/push. 미확인 항목을 완료로 기록하지 않음.

## 코스튬·표정

- [ ] **남녀18종 전체 아바타 연동**: 현재 실제 게임용은 성기사 남성1종. 나머지는 원본 표면/UV/텍스처와15부위·관절·웨이트 경계·의상 찢어짐을 확인한 뒤 Importer 실제 항목 수 ≤10씩 가져오기→대기 조립→걷기/점프/전투/OFF→승격 순서로 진행한다. 로컬 변환이나 정지 렌더만으로 등록하지 않는다.
- [ ] 실제 R6 본인 아바타 및 모든 직업/진영/성별 교체에서 원래 RigType·위치·속도·HP/MP·물약CD/재고·기존 ForceField 객체/기한·이동 기록 보존 확인. 로드 중 사망/퇴장/timeout·중복 리스폰은 오프라인365개와 실제 엔진 검증을 구분한다.
- [ ] **신규 HaloWarriorF/HaloMageM/HaloMageF3종 Head UV/재질 오류로 업로드 보류.** Tripo rig가 Head 재질을 Body 재질로 합친 문제를 원본 fixed 실제 면 대응으로 복원한 뒤 검사한다. 깨진 얼굴/상체 결과는 업로드하지 않는다.
- [ ] 무료 거절 **HaloArcherF/HornsArcherF/NeutralWarriorF/NeutralArcherM4종** 원본 보존 수동 R15 가능성 검토. merged와 원본raw2k 무료 검사 모두 false/청구0. 관절 위치를 추측해 검증 완료라 하지 않으며 자동 유료 재리깅/재생성 금지, 무료 재검사는 루트만 진행한다.
- [ ] 승인 표정 Neutral/Serious/SoftSmile의 UV별 별도 메시/원본 Head 보존 검사. MeshName 유일성·Head 연결·`HHC_ExpressionMeshValidated=true` 확인 후 ID 등록(현재 실제 등록 0종).
- [ ] 표정 실제 표시·공격/피격 우선·대화 미소·만료·OFF 원래 얼굴 복귀 검증. 실패 atlas 업로드 금지.

## 사용자 지적한 무기·모션 — 미충족/보류

- [ ] **현재 임시 3D 무기는 최종 요구 미충족.** 무기 아이콘 27개 연결이나 시안 승인으로 실제 손에 든 최종 모델/텍스처가 완료됐다고 하지 않음.
- [ ] **활 공격 모션이 어색하다는 사용자 지적은 해결 확인 전 보류.** 왼손 활/오른손 시위, 실제 화살 장전·당김·발사·연사, 활 크기/그립과 실제 muzzle 확인.
- [ ] 전사 F 베기/Q 내려찍기와 마법사 기 모으기/지팡이 발사/Q 운석의 최종 실제 동작 확인. pilot F/Q 관절 움직임은 기본 검사만 의미함.
- [ ] 기본 Animate·걷기/점프·피격과의 충돌, 직업/진영/캐릭터 교체·죽음 때 지연 동작 취소, 서버 피해와 시각 타이밍 확인.
- [ ] 새 무기/동작의 시각 변경이 필요하면 사용자 선택한 GPT 시안을 정확히 따름. 검사 중 임의 디자인을 추가하지 않음.

기존 Goblin/GoblinBrute/Skeleton TexturePack 경고·BigSlime 새 계정 모델 누락·몬스터 전체 복구, A16의 다인 PvP/저장/이동 오탐 검증도 별도 남아 있다. `art/out/v1/`은 어떤 배치에도 넣지 않는다.

- [ ] 사용자 지적한 슬라임 반투명 표시: fallback 투명도0 소스 수정은 됐으나 최종 실제 화면 확인 전 완료로 기록하지 않는다.

## 이전 실패·검사 기록 — 최신 상태와 구분

- 20:07 당시 pilot의 높이/원본 root.CanCollide 보정 후에도 OFF 밀림·날아감이 재현됐고 게임용 승격0종이었다. ownership0.25초 지연 실험도 실패해 원복했다. 이후 엔진 복귀 수정과 실제 안정 검사로 **현재1종** 승격됐으며 옛 실험은 현재 소스/Studio에 남아 있지 않다.
- 당시 추가17종의 첫 실행은10종/250크레딧·무료 거절7종·strict8종/보류2종, 잔액4,635였다. 이후 원본 포장 병합 무료 검사와 첫 유료 리깅3종75를 추가해 **현재13종/325·무료 거절4종·잔액4,560**이 됐다. 보류였던 두 HornsMage 결과는 원본 보존 로컬 복구를 통과했다.
- 초기 구매 서버 오프라인560개(이후562개)와 물리86개만으로 실제 구매/복귀를 완료 처리하지 않았다. 현재 물약929개·복귀365개와 실제 pilot OFF·키1/2 결과를 각각 별도 기록한다.
- 이전 기본 동기화는22변경/17동일이었다. GoodEvil/Edit **20:07:18,7,457,604바이트** 저장과 place 복사는 그 시점 기록이며 현재 최종 저장본이라는 뜻이 아니다. 최신 소스의 저장 시각/용량 확인·place 복사·커밋/push는 루트 체크포인트로 마감한다.
