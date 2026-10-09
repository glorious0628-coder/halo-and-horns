# 개별 투명 PNG 재제작 목록 — 2026-10-04

> 기록용(2026-10-09 검수): 2026-10-04 감사 기록이다. 지금은 모든 그림을 Firefly로 새로 그리고(SPEC A23-7, 후보 Medium·최종 High — A23-47 보강 3) 캐릭터는 치비가 아닌 로블록스 스타일, 글자는 그림에 넣지 않는다(A23-35 정정, 게임 글은 영어만 A23-48). 아래 GPT 절차는 쓰지 않고, 아직 게임에 남은 옛 그림은 Firefly 새 그림이 들어간 뒤 지운다(A23-7).

사용자 최신 기준: **기본 디자인을 먼저 정립한 다음 스토리와 게임 전체를 점검한다. 디자인은 이후에도 계속 업데이트한다.** **3D 아바타 자체 외 디자인 전체를 재제작한다. 직업별2D이미지18개도 모두 새로 만들되 기존 그림체를 유지한다.** 아래 순서는 디자인 내부 작업 순서이며 RELEASE_PLAN의 출시일·베타 범위를 변경하지 않는다.

## 감사 범위와 분모

파일·코드만 읽었다. Studio/화면 제어/업로드/유료 호출/게임 소스 수정은 하지 않았다. `Config.UIArt.Enabled=true`, `FactionE.Enabled=true`인 현 소스를 기준으로 했다.

| 구분 | 개수 | 의미 |
|---|---:|---|
| 등록 Part/PNG | 177 | 실제 파일 존재 확인 |
| 지형 재질 | 15 | UI 분모에서 제외 |
| 등록된 비지형 PNG | 162 | 구버전·미연결 포함, 활성 수 아님 |
| 현재 코드 경로로 호출 가능한 후보 | 102 | 동적 참조·대체 표시 포함, 실클라 로드 성공 수 아님 |
| 구버전/이전 진영 전용/글자 표시 OFF | 60 | 6 + 12 + 42, 현재 작업 분모와 분리 |
| 순수 UI 후보 / 월드 효과 후보 | 92 / 10 | 위102를 용도별로 분리 |
| 폴더에는 있으나 Parts 미등록 | 10 | 아래 별도 목록 |
| 이번 감사의 실제 클라이언트 로드 확인 | 0 | 정적 감사로 대체하지 않음 |

현재 후보102개도 최종 새 제작 장수는 아니다. 공통 부품은 여러 화면에서 공유하며, 코드로만 그린 메뉴·버튼·상점은 PNG 파일 수에 잡히지 않는다. 직업2D18개를 포함해3D아바타 외 디자인은 새 제작 범위이며, 기존 그림체를 유지한다. 재제작 전 과거 그림을 삭제하지 않는다.

최초 조사175개에서 제목·footer 신규2개가 추가되어177개가 됐다. 현재 진영 역할은 여전히6개이며, 이전 제목·footer2개를 구버전으로 이동해 현재 후보102개는 그대로다. 최초 수치와Config SHA는 JSON의 `snapshot_history`에 보존했다.

## 화면별 내부 작업 순서

| 순서/화면 | 현재 재료와 재제작 대상 | 소스 근거 |
|---|---|---|
| 1. 진영 선택 | 제목·세계관 설명·빛/뿔/장인 카드·변경 안내, 정확히6역할 | Config:1389의 FactionE.Parts |
| 2. HUD/물약 수량 | 정보판·3D초상화 링·레벨표·XP/HP/MP틀·공격/발사·메뉴/지도·퀘스트·성장/재화·물약 아이콘 | HUD:585,674,715,1113,1316,1484 / VitalsUI:65,114 |
| 3. 공통 메뉴 | 메뉴·이동·환생·진영변경·직업변경·변경권상점·휴가보상 공통 틀/닫기/뒤로/행/버튼. 현재 대부분 코드 도형 | Panels:815,1103,1182,1262,1364,1483,1568,1597 |
| 3. 직업 선택 | 카드 배경3 + 성별 그림18 + 진영 방패3 + 공통 제목/설명/성별 pill + 글자13 | ClassPicker:631,711,767,1102,1115 |
| 3. 상점 | 변경권상점은 기존 코드행/버튼. 물약 NPC 구매창은 아직 미구현·MerchantEnabled=false; 새 부품 수 미정 | Panels:1568 / Config:33 |
| 3. 닉네임 | PanelParchment/TitleRibbon/BtnSpecial/CardHalo 재사용. 입력문자·중복/금칙어 상태는 동적 텍스트 | Panels:1053–1084 |
| 후속. 지도/이벤트 | 지도 배경·마커/줌/닫기/설명, 거위·괴수·운 이벤트. 현재 재사용 PNG+코드 도형 혼합 | WorldMap:1414 / EventHUD:478,548,672 |

HUD 프로필 안의 아바타는 `ViewportFrame` 실제3D이므로 PNG 제작 대상은 바깥 링/틀이다. 3D 아바타·무기 모델·몬스터·지형·월드 소품은 순수 UI 목록과 분리한다. 2D 무기27개는 HUD 아이콘이며 최종3D무기27종 작업과 다르다.

## 투명도와 글자

등록 비지형 PNG162개 중161개는 RGBA이고 alpha=0인 픽셀이 있다. `UI_MapParchment.png`만 RGB이며 완전 불투명하다. RGBA라는 사실만으로 경계 품질이나 진짜 투명 배경의 완성도를 보증하지 않는다.

현재 진영6개와 TXT42개는 글자가 이미지에 포함된 것으로 코드·메타데이터에서 확인했다. 나머지 파일의 글자 유무는 전수 OCR하지 않았으며 코드에서 text-free로 쓰인 부품과 구분해야 한다. 예를 들어 `UIP_PanelParchment.png`의 부분알파 비율은97.4%지만 보이는 픽셀 중앙 알파는254다. 이것만으로 전체가 반투명하거나 흐리다고 판정하지 않는다.

**TXT42개는 모두 현재 표시 OFF다.** `UIKit.luau:23`의 `FONT.UseTextImages=false`와974행 조기 반환을 확인했다. ClassPicker13개·WorldMap7개는 설정을 다시 켰을 때 가능한 매핑일 뿐이다. HUD·Panels·EventHUD·현 FactionPicker에는 바인딩 호출도 없다. WorldMap의 `황금 거위!`는 등록된 `황금 거위`와 달라 정확 문자열 매칭이 되지 않는다.

## 개별 생성·검증 공통 기준

- GPT에서 부품 한 장씩 투명 PNG로 직접 생성하고 사용자 선택 후 구현. 합성 화면을 다시 잘라내는 생산 흐름은 쓰지 않는다.
- PNG에 alpha 채널 및 alpha=0 배경이 실제 존재하는지 확인. 체크무늬가 RGB에 그려진 가짜 투명도는 별도 육안 검사.
- 원본/확대에서 외곽선 끊김·잘린 금테·잔여 점·글씨 오탈자 확인. 카드 간 높이/버튼 위치 수치 기록.
- 글자를 포함한 이미지면 ko/en 별도 원본과 정확한 문구 기록. 동적 숫자/이름/수량은 실제 텍스트로 보존.
- PC와 폰의 실제 클라이언트에서 기본·확대·스크롤·로드 실패 대체 UI 확인. 파일 알파 검사만으로 합격 처리하지 않는다.
- 이미지를 각각 사용자에게 보여 준 뒤 10개 이하씩 업로드. art/out/v1/ 업로드 금지.

## 정확한 파일 목록

아래 파일은 모두 저장소의 `art/ui/` 아래다. 각 파일의 SHA·크기·알파 비율·정적 참조 위치는 [기계 판독 기록](verification_2026-10-04/ui_redraw_inventory.json)에 있다.

### 공통 틀·HUD 아이콘·현재 대체 표시 — 37개

- `art/ui/UIP_PanelParchment.png`
- `art/ui/UIP_PanelCard.png`
- `art/ui/UIP_RibbonHeader.png`
- `art/ui/UIP_Pill.png`
- `art/ui/UIP_BarTrack.png`
- `art/ui/UIP_BtnSquare.png`
- `art/ui/UIP_BtnAttack.png`
- `art/ui/UIP_BtnSpecial.png`
- `art/ui/UIP_LevelBadge.png`
- `art/ui/UIP_PortraitRing.png`
- `art/ui/UIP_ShieldHalo.png`
- `art/ui/UIP_ShieldHorns.png`
- `art/ui/UIP_Crown.png`
- `art/ui/UIP_IconCoin.png`
- `art/ui/UIP_IconPouch.png`
- `art/ui/UIP_IconPotionHP.png`
- `art/ui/UIP_IconPotionMP.png`
- `art/ui/UIP_IconSword.png`
- `art/ui/UIP_IconAttack.png`
- `art/ui/UIP_IconSpecial.png`
- `art/ui/UIP_IconLock.png`
- `art/ui/UIP_IconMap.png`
- `art/ui/UIP_IconGear.png`
- `art/ui/UIP_IconGoose.png`
- `art/ui/UIP_IconSafe.png`
- `art/ui/UIP_IconSprout.png`
- `art/ui/UIP_IconStar.png`
- `art/ui/UIP_IconStarEmpty.png`
- `art/ui/UIP_IconClover.png`
- `art/ui/UIP_IconScroll.png`
- `art/ui/UIP_IconSlime.png`
- `art/ui/UIP_CardHalo.png`
- `art/ui/UIP_ShieldNeutral.png`
- `art/ui/UIP_TitleRibbon.png`
- `art/ui/UIP_IconHeart.png`
- `art/ui/UIP_IconAltar.png`
- `art/ui/UIP_IconBoot.png`

### 교체된 진영 E 구버전 — 6개

- `art/ui/UIP_FactionCardHaloE.png`
- `art/ui/UIP_FactionCardHornsE.png`
- `art/ui/UIP_FactionCardNeutralE.png`
- `art/ui/UIP_FactionTitleRibbonE.png`
- `art/ui/UIP_FactionPremisePanelE.png`
- `art/ui/UIP_FactionFooterPanelE.png`

### 현재 진영 선택 6개 — 6개

- `art/ui/UIP_FactionPremise_FreshTyped.png`
- `art/ui/UIP_FactionCardHalo_FreshTyped.png`
- `art/ui/UIP_FactionCardHorns_FreshTyped.png`
- `art/ui/UIP_FactionCardNeutral_FreshTyped.png`
- `art/ui/UIP_FactionTitle_FreshTyped.png`
- `art/ui/UIP_FactionFooter_FreshTyped.png`

### E를 끈 이전 진영 경로 전용 — 12개

- `art/ui/UIP_CardHorns.png`
- `art/ui/UIP_CardNeutral.png`
- `art/ui/UIP_IconExp.png`
- `art/ui/UIP_IconWings.png`
- `art/ui/UIP_IconGoldPile.png`
- `art/ui/UIP_IconBloodSword.png`
- `art/ui/UIP_IconGauge.png`
- `art/ui/UIP_IconDemon.png`
- `art/ui/UIP_IconNoBuff.png`
- `art/ui/UIP_IconShieldBlue.png`
- `art/ui/UIP_IconNoLoot.png`
- `art/ui/UIP_IconHammer.png`

### 직업 카드 배경 — 3개

- `art/ui/UIP_ClassCardHalo.png`
- `art/ui/UIP_ClassCardHorns.png`
- `art/ui/UIP_ClassCardNeutral.png`

### 직업/성별 2D 그림 — 18개

- `art/ui/UIP_CharHaloWarriorM.png`
- `art/ui/UIP_CharHaloWarriorF.png`
- `art/ui/UIP_CharHaloMageM.png`
- `art/ui/UIP_CharHaloMageF.png`
- `art/ui/UIP_CharHaloArcherM.png`
- `art/ui/UIP_CharHaloArcherF.png`
- `art/ui/UIP_CharHornsWarriorM.png`
- `art/ui/UIP_CharHornsWarriorF.png`
- `art/ui/UIP_CharHornsMageM.png`
- `art/ui/UIP_CharHornsMageF.png`
- `art/ui/UIP_CharHornsArcherM.png`
- `art/ui/UIP_CharHornsArcherF.png`
- `art/ui/UIP_CharNeutralWarriorM.png`
- `art/ui/UIP_CharNeutralWarriorF.png`
- `art/ui/UIP_CharNeutralMageM.png`
- `art/ui/UIP_CharNeutralMageF.png`
- `art/ui/UIP_CharNeutralArcherM.png`
- `art/ui/UIP_CharNeutralArcherF.png`

### 월드 이펙트·감정 스티커 — 10개

- `art/ui/UIP_FxSlash.png`
- `art/ui/UIP_FxHitSpark.png`
- `art/ui/UIP_FxShockRing.png`
- `art/ui/UIP_FxMagicBurst.png`
- `art/ui/UIP_FxDust.png`
- `art/ui/UIP_EmoOuch.png`
- `art/ui/UIP_EmoTears.png`
- `art/ui/UIP_EmoDizzy.png`
- `art/ui/UIP_EmoAngry.png`
- `art/ui/UIP_EmoStress.png`

### 등록됐지만 현재 글자 바인딩 미확인 — 22개

- `art/ui/TXT_Attack.png`
- `art/ui/TXT_Release.png`
- `art/ui/TXT_Menu.png`
- `art/ui/TXT_Map.png`
- `art/ui/TXT_Claim.png`
- `art/ui/TXT_Reroll.png`
- `art/ui/TXT_Quests.png`
- `art/ui/TXT_Light.png`
- `art/ui/TXT_Horn.png`
- `art/ui/TXT_Safe.png`
- `art/ui/TXT_Rookie.png`
- `art/ui/TXT_Regular.png`
- `art/ui/TXT_CheerStars.png`
- `art/ui/TXT_Next.png`
- `art/ui/TXT_PickFaction.png`
- `art/ui/TXT_ThisSide.png`
- `art/ui/TXT_Halo.png`
- `art/ui/TXT_Horns.png`
- `art/ui/TXT_LevelUp.png`
- `art/ui/TXT_GoldenGoose.png`
- `art/ui/TXT_SafeZone.png`
- `art/ui/TXT_PvPZone.png`

### 직업 글자 잠재 매핑 — 13개, 현재 표시 OFF

- `art/ui/TXT_PickClass.png`
- `art/ui/TXT_ThisClass.png`
- `art/ui/TXT_Paladin.png`
- `art/ui/TXT_LightMage.png`
- `art/ui/TXT_Ranger.png`
- `art/ui/TXT_Berserker.png`
- `art/ui/TXT_DarkMage.png`
- `art/ui/TXT_ShadowHunter.png`
- `art/ui/TXT_Blacksmith.png`
- `art/ui/TXT_Alchemist.png`
- `art/ui/TXT_Hunter.png`
- `art/ui/TXT_Male.png`
- `art/ui/TXT_Female.png`

### 지도 글자 잠재 매핑 — 7개, 현재 표시 OFF

- `art/ui/TXT_Neutral.png`
- `art/ui/TXT_Crossroads.png`
- `art/ui/TXT_HaloTown.png`
- `art/ui/TXT_HornsTown.png`
- `art/ui/TXT_Meadow.png`
- `art/ui/TXT_GoblinWoods.png`
- `art/ui/TXT_SkeletonRuins.png`

### 성장 HUD의 2D 무기 아이콘 — 27개

- `art/ui/Weapon_Warrior_T1.png`
- `art/ui/Weapon_Warrior_T2.png`
- `art/ui/Weapon_Warrior_T3.png`
- `art/ui/Weapon_Warrior_T4.png`
- `art/ui/Weapon_Warrior_T5.png`
- `art/ui/Weapon_Warrior_T6.png`
- `art/ui/Weapon_Warrior_T7_Halo.png`
- `art/ui/Weapon_Warrior_T7_Horns.png`
- `art/ui/Weapon_Warrior_T7_Neutral.png`
- `art/ui/Weapon_Mage_T1.png`
- `art/ui/Weapon_Mage_T2.png`
- `art/ui/Weapon_Mage_T3.png`
- `art/ui/Weapon_Mage_T4.png`
- `art/ui/Weapon_Mage_T5.png`
- `art/ui/Weapon_Mage_T6.png`
- `art/ui/Weapon_Mage_T7_Halo.png`
- `art/ui/Weapon_Mage_T7_Horns.png`
- `art/ui/Weapon_Mage_T7_Neutral.png`
- `art/ui/Weapon_Archer_T1.png`
- `art/ui/Weapon_Archer_T2.png`
- `art/ui/Weapon_Archer_T3.png`
- `art/ui/Weapon_Archer_T4.png`
- `art/ui/Weapon_Archer_T5.png`
- `art/ui/Weapon_Archer_T6.png`
- `art/ui/Weapon_Archer_T7_Halo.png`
- `art/ui/Weapon_Archer_T7_Horns.png`
- `art/ui/Weapon_Archer_T7_Neutral.png`

### 지형 재질 PNG — UI 제외 — 15개

- `art/ui/Tex_Grass.png`
- `art/ui/Tex_LeafyGrass.png`
- `art/ui/Tex_HaloTiles.png`
- `art/ui/Tex_Ground.png`
- `art/ui/Tex_DirtPath.png`
- `art/ui/Tex_CrownShardGround.png`
- `art/ui/Tex_CrackedLava.png`
- `art/ui/Tex_Cobblestone.png`
- `art/ui/Tex_Basalt.png`
- `art/ui/Tex_WoodPlanks.png`
- `art/ui/Tex_Slate.png`
- `art/ui/Tex_Sand.png`
- `art/ui/Tex_Rock.png`
- `art/ui/Tex_Marble.png`
- `art/ui/Tex_Limestone.png`

### 세계 지도 배경 — 1개

- `art/ui/UI_MapParchment.png`

### Parts 미등록 PNG — 10개

- `art/ui/UIP_CharHaloArcher.png`
- `art/ui/UIP_CharHaloMage.png`
- `art/ui/UIP_CharHaloWarrior.png`
- `art/ui/UIP_CharHornsArcher.png`
- `art/ui/UIP_CharHornsMage.png`
- `art/ui/UIP_CharHornsWarrior.png`
- `art/ui/UIP_CharNeutralArcher.png`
- `art/ui/UIP_CharNeutralMage.png`
- `art/ui/UIP_CharNeutralWarrior.png`
- `art/ui/UIP_PortraitHaloArcherM.png`

무성별 구직업9개와2D궁수초상화1개. 새Footer/Title은 현재등록6역할에포함.

## 직업18개 원본·그림체·노출 기준

얼굴·손 외 신체를 옷으로 가린다. 목·어깨·가슴·배·등·다리 노출 없음. 긴 소매·긴 바지 또는 긴 치마와 불투명 타이츠·신발. 기존 그림체만 참조하고 과거 노출 의상은 복제하지 않는다. 기존 비성적 Slime/Goblin/GoblinBrute 의복 예외는 유지. 인간형 직업에는 적용하지 않음.

기존 그림체는 큰 머리와 작은 몸의 치비, 동그란 반짝이는 눈, 부드러운 머리카락, 입체 장난감 느낌, 진영별 흰색/금색·검붉은색·청록/갈색을 유지한다. 새 장식·의상 디자인은 GPT 개별 원화로 검토한다. 기존 배꼽티/노출 의상은 참고하지 않고 `art/out/v1/` 전체를 생성·업로드 참조에서 제외한다.

| 게임 PNG | 기존 승인 원본 |
|---|---|
| `art/ui/UIP_CharHaloWarriorM.png` | `art/out/UIP_CharHaloWarriorM.png` |
| `art/ui/UIP_CharHaloWarriorF.png` | `art/out/UIP_CharHaloWarriorF.png` |
| `art/ui/UIP_CharHaloMageM.png` | `art/out/UIP_CharHaloMageM.png` |
| `art/ui/UIP_CharHaloMageF.png` | `art/out/UIP_CharHaloMageF.png` |
| `art/ui/UIP_CharHaloArcherM.png` | `art/out/UIP_CharHaloArcherM.png` |
| `art/ui/UIP_CharHaloArcherF.png` | `art/out/UIP_CharHaloArcherF.png` |
| `art/ui/UIP_CharHornsWarriorM.png` | `art/out/UIP_CharHornsWarriorM.png` |
| `art/ui/UIP_CharHornsWarriorF.png` | `art/out/UIP_CharHornsWarriorF.png` |
| `art/ui/UIP_CharHornsMageM.png` | `art/out/UIP_CharHornsMageM.png` |
| `art/ui/UIP_CharHornsMageF.png` | `art/out/UIP_CharHornsMageF.png` |
| `art/ui/UIP_CharHornsArcherM.png` | `art/out/UIP_CharHornsArcherM.png` |
| `art/ui/UIP_CharHornsArcherF.png` | `art/out/UIP_CharHornsArcherF.png` |
| `art/ui/UIP_CharNeutralWarriorM.png` | `art/out/UIP_CharNeutralWarriorM.png` |
| `art/ui/UIP_CharNeutralWarriorF.png` | `art/out/UIP_CharNeutralWarriorF.png` |
| `art/ui/UIP_CharNeutralMageM.png` | `art/out/UIP_CharNeutralMageM.png` |
| `art/ui/UIP_CharNeutralMageF.png` | `art/out/UIP_CharNeutralMageF.png` |
| `art/ui/UIP_CharNeutralArcherM.png` | `art/out/UIP_CharNeutralArcherM.png` |
| `art/ui/UIP_CharNeutralArcherF.png` | `art/out/UIP_CharNeutralArcherF.png` |

승인 기록은 `art/approved.json:ClassCharacters`, 가공 경로는 `tools/prep_ui.py`의 `art/out`→`art/ui`다. 원본18개 존재와SHA를 JSON에 기록했다.

- `art/out/UI_Class_A.png`: 직업 선택 화면의 기존 장난감 같은 치비/양피지/금색 틀 기준. 이번 감사에서 이미지 재열람 안 함.
- `art/out/UIP_CharHaloArcherF.png`: 큰 머리·동그란 눈·부드러운 금발·입체 장난감 표현·흰색/금색. 긴 소매/장갑/다리 전체 옷. 기본표정으로 윙크를 그대로 요구하지 않는다.
- `art/out/UIP_CharHornsMageF.png`: 동일한 치비 얼굴/입체 표현·검붉은 긴 옷·작은 뿔·긴 소매·긴 바지·신발. 얼굴과 손 외 옷으로 가려짐.
- `art/out/UIP_CharNeutralWarriorF.png`: 동일 치비 비율·청록/갈색·고글/톱니/망치·긴 소매/장갑/긴 바지/부츠. 목의 일부 피부도 새 제작에서는 가리기.

## UI 밖 디자인 — 별도 집계

- 현재3D아바타: 이번 전면 재제작에서 제외. HUD 안3D아바타도 그대로3D이며 바깥 링만UI 대상이다.
- 지형 재질15PNG: 위목록대로 별도 재제작/검증. 타일 재질은 정상적으로 불투명할 수 있으므로 투명배경 기준을 강제하지 않는다.
- 3D무기/몬스터/건물/소품: 별도 모델·재질 작업. UI92개 또는효과10개와 합산하지 않는다. 이번 감사로 전체 운영개수는 확정하지 않았다.
- 2D아이콘·엠블럼·게임대표이미지 후보: 다음13파일이 `art/out`에 존재한다. Parts외부이며 실제게임·홍보 연결은 별도 확인한다.

- `art/out/Emblem_Halo.png`
- `art/out/Emblem_Horns.png`
- `art/out/Emblem_Neutral.png`
- `art/out/GameIcon.png`
- `art/out/Icon_CheerStar.png`
- `art/out/Icon_ClassTicket.png`
- `art/out/Icon_CrownShard.png`
- `art/out/Icon_FactionTicket.png`
- `art/out/Icon_Gold.png`
- `art/out/Icon_GrudgeSack.png`
- `art/out/Icon_RewardChest.png`
- `art/out/Icon_XP.png`
- `art/out/Thumbnail_Kaiju.png`

최상위 `art/models`에서 확인한 비아바타 GLB7개(운영 모델 수 아님):

- `art/models/Goblin.glb`
- `art/models/GoblinBrute.glb`
- `art/models/GoldenGoose.glb`
- `art/models/Skeleton.glb`
- `art/models/SkeletonKing.glb`
- `art/models/SkeletonKnight.glb`
- `art/models/Slime.glb`

## 확인 한계

- 정적 리터럴 참조가 없다고 미사용으로 판정하지 않는다. Char/ClassCard/Shield/Weapon/물약/텍스트는 문자열 조합 또는 매핑 경로가 있다.
- 102개 후보는 현재 코드 경로로 호출 가능한 집합이며 동시에 보이는 수·실제 로드 성공 수·최종 제작 장수와 다르다.
- 메뉴·물약 상점 등 현재 PNG 없는 코드 도형은 이 이미지 수에 들어 있지 않다. GPT 승인 시 부품 분할에 따라 새 제작 장수가 늘 수 있다.
- 글자 TXT42개 전부 UseTextImages=false로 표시 OFF. ClassPicker13/WorldMap7은 재활성화 때의 잠재 경로이며 현재 활성 수가 아니다.
- 2D 직업18개를 포함해3D아바타 외 디자인은 전면 재제작 범위. Bitmap이 아닌3D무기·몬스터·소품과 타일 재질은 별도 작업형식으로 분리한다. 기존 모델을 평면PNG로 바꾸라는 뜻으로 해석하지 않는다.
- 알파 1..254 픽셀 다수는 중앙값253~254일 수 있어 흐림/전체 반투명 문제로 단정하지 않는다.
- 본 감사 중 모든 원화에 대한 육안·한글 OCR·안전 전수 검토를 하지 않았다. 업로드 전에 각각 필요하다.
