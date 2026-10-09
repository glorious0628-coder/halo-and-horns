# 고급(High) 다시 받기 후보 표 — 이미 중간으로 게임에 들어간 최종 (2026-10-07, 이미지 생성 2)

> 기록용(2026-10-07 당시). 지금과 다른 점: PTR_TownSmokey = 뿔 소굴 망보기, PTR_TownBright = 빛 마을 경비 견습(대장장이·물약 상인 초상 아님, 최신: SPEC A23-59 · `Config.StoryQuests.Portraits`); 다른 칸 그림을 빌린 아이콘은 다시 받기가 아니라 제 그림을 새로(A23-96, `remake_list_2026-10-09.md` P5). 지금 기준: AGENTS.md · SPEC_ADDENDUM A23 · RELEASE_PLAN.

규칙(사용자 2026-10-07, SPEC A23-47 보강 3): 고른 최종은 고급. 이 표는 **이미 중간으로 게임에 들어간 것**을 다시 받을지 고르는 용도예요(검수가 고름, 고른 것만 그림).
- 대상: approved.json에서 Firefly 중간으로 만든 art/ui 그림 중 **Config.UIArt에 Id가 있는 것 246개**(origin/main 기준, 이미지 생성 1 그림 일부 포함 — WorldMapV2 등은 그쪽과 상의).
- 다시 받는 방법: 지금 그림을 참조로 '같은 물건을 더 깔끔하게'(모양·색 유지) → 누끼 → **layout·slice 다시 재기** → 업로드 → Config Id 교체(이미지 개발). 크레딧 5/장. 사람 초상은 표정이 바뀌지 않게 참조 2장(그림체 + 그 인물).
- 화면 크기는 코드·메모에서 본 대략값(du/px, 추정). 화면에서 64px 아래로만 보이는 것 = '이득 적음'.

## 1. 이득 큼 — 크게 보이는 창·카드·초상 (18개 = 90크레딧)
| 이름 | 무엇 | 화면 크기 | 고급으로 좋아질 점 | 크레딧 |
|---|---|---|---|---|
| PanelMain | 기본 창 틀(9조각) | 300~900 폭 | 테 반사·사파이어 모서리 또렷(모든 창에 보임) | 5 |
| DialogBox | 대화창(9조각) | 600~900 폭 | 테·모서리 또렷, NPC 대화마다 보임 | 5 |
| LogoPlate | 로고 판 | 큰 화면 | 가장자리·광택 | 5 |
| EventBannerHalloween | 핼러윈 이벤트 띠 | 약 900×280 | 장식 또렷 | 5 |
| MapParchment | 지도 양피지 바탕(불투명) | 전체 지도 창 | 종이 결 — 바탕이라 이득 중간 | 5 |
| PortraitFrame | 초상 틀 | 약 180~260 | 테 또렷 | 5 |
| PetCard | 펫 카드 | 약 230×380 | 테·장식 | 5 |
| WorldMapV2 | 세계 지도 그림 | 전체 지도 창 | 지형 그림 또렷(이미지 생성 1과 상의) | 5 |
| PTR_TownTiny | 교차로 NPC 초상 티니 | 대화창 약 180~260 | 얼굴·옷 결 또렷(사람 그림 — 표정 바뀌지 않게 참조로) | 5 |
| PTR_TownSmokey | 대장장이 초상 스모키 | 대화창 약 180~260 | 같음 | 5 |
| PTR_TownBright | 물약 상인 초상 브라이트 | 대화창 약 180~260 | 같음 | 5 |
| FactionPickHalo | 진영 고르기 카드(빛) | 약 330×545 | 금테·문장 선이 또렷, 큰 화면에서 흐림 줄어듦 | 5 |
| FactionPickHorns | 진영 고르기 카드(뿔) | 약 330×545 | 같음 | 5 |
| ClassPickHalo | 직업 카드 틀(빛) | 약 230×420 | 테·장식 또렷 | 5 |
| ClassPickHorns | 직업 카드 틀(뿔) | 약 230×420 | 같음 | 5 |
| FactionPickTitle | 진영 고르기 제목 띠 | 약 620×225 | 리본 결·금테 또렷 | 5 |
| JobBoard | 사냥터 게시판 창 | 약 1040×650 | 나무결·이름판 또렷 | 5 |
| JobCard | 의뢰 카드 | 약 200×300(폰 2장) | 종이 결·핀 | 5 |

## 2. 이득 중간 — 버튼·줄·스킬·무기·칸 (80개 = 400크레딧)
| 이름 | 무엇 | 화면 크기 | 고급으로 좋아질 점 | 크레딧 |
|---|---|---|---|---|
| AutoRingOn | 자동 전투 켜짐 고리 | 약 60~90 | 고리 광택 | 5 |
| BannerAlert | 창·줄·띠 부품(9조각) | 100~600 폭 | 테·광택 또렷 — 화면에 자주 보임 | 5 |
| BarFill | 창·줄·띠 부품(9조각) | 100~600 폭 | 테·광택 또렷 — 화면에 자주 보임 | 5 |
| BarTrack | 창·줄·띠 부품(9조각) | 100~600 폭 | 테·광택 또렷 — 화면에 자주 보임 | 5 |
| BarkBubble | 몬스터 말풍선(9조각) | 약 120~300×52 | 테 또렷 | 5 |
| BtnAttack | 공격 버튼(둥근) | 폰 약 100~120 | 광택·아이콘 — 폰에서 크게 보임 | 5 |
| BtnConfirm | 버튼(가로 9조각) | 50~110 높이 | 광택·테 또렷 — 화면에 자주 보임 | 5 |
| BtnKind | 버튼(가로 9조각) | 50~110 높이 | 광택·테 또렷 — 화면에 자주 보임 | 5 |
| BtnPotion | 물약 버튼(둥근) | 폰 약 70~90 | 광택 — 폰에서 크게 보임 | 5 |
| BtnPrimary | 버튼(가로 9조각) | 50~110 높이 | 광택·테 또렷 — 화면에 자주 보임 | 5 |
| BtnRound | 버튼(가로 9조각) | 50~110 높이 | 광택·테 또렷 — 화면에 자주 보임 | 5 |
| BtnSecondary | 버튼(가로 9조각) | 50~110 높이 | 광택·테 또렷 — 화면에 자주 보임 | 5 |
| BtnSneaky | 버튼(가로 9조각) | 50~110 높이 | 광택·테 또렷 — 화면에 자주 보임 | 5 |
| BtnSquare | 버튼(가로 9조각) | 50~110 높이 | 광택·테 또렷 — 화면에 자주 보임 | 5 |
| Chip | 창·줄·띠 부품(9조각) | 100~600 폭 | 테·광택 또렷 — 화면에 자주 보임 | 5 |
| GradeSlotBack | 등급 칸 뒷판 | 64~80 | 단색 판 — 이득 적은 편 | 5 |
| InputField | 창·줄·띠 부품(9조각) | 100~600 폭 | 테·광택 또렷 — 화면에 자주 보임 | 5 |
| ListRow | 창·줄·띠 부품(9조각) | 100~600 폭 | 테·광택 또렷 — 화면에 자주 보임 | 5 |
| ListRowSelected | 창·줄·띠 부품(9조각) | 100~600 폭 | 테·광택 또렷 — 화면에 자주 보임 | 5 |
| MenuTile | 메뉴 칸 판 | 약 90~120 | 판 광택 | 5 |
| MinimapFrame | 미니맵 네모 테 | 약 180 | 테 광택 | 5 |
| MinimapRing | 둥근 미니맵 테 | 96~180 | 테 광택 — 늘 보임 | 5 |
| NameTag | 창·줄·띠 부품(9조각) | 100~600 폭 | 테·광택 또렷 — 화면에 자주 보임 | 5 |
| NpcMarkerBubble | NPC 머리 위 말풍선 표시 | 약 40~60 | 작아서 이득 적은 편 | 5 |
| PortraitRing | 초상 원 테 | 약 70~100 | 테 광택 | 5 |
| QuestRow | 창·줄·띠 부품(9조각) | 100~600 폭 | 테·광택 또렷 — 화면에 자주 보임 | 5 |
| QuestTab | 창·줄·띠 부품(9조각) | 100~600 폭 | 테·광택 또렷 — 화면에 자주 보임 | 5 |
| Skill_Alchemist_X | 스킬 아이콘 | 64~96 | 그림 속 효과 선명 | 5 |
| Skill_Archer_Q | 스킬 아이콘 | 64~96 | 그림 속 효과 선명 | 5 |
| Skill_Archer_X | 스킬 아이콘 | 64~96 | 그림 속 효과 선명 | 5 |
| Skill_Archer_Z | 스킬 아이콘 | 64~96 | 그림 속 효과 선명 | 5 |
| Skill_Blacksmith_X | 스킬 아이콘 | 64~96 | 그림 속 효과 선명 | 5 |
| Skill_Mage_Q | 스킬 아이콘 | 64~96 | 그림 속 효과 선명 | 5 |
| Skill_Mage_X | 스킬 아이콘 | 64~96 | 그림 속 효과 선명 | 5 |
| Skill_Mage_Z | 스킬 아이콘 | 64~96 | 그림 속 효과 선명 | 5 |
| Skill_Tamer_Q | 스킬 아이콘 | 64~96 | 그림 속 효과 선명 | 5 |
| Skill_Tamer_X | 스킬 아이콘 | 64~96 | 그림 속 효과 선명 | 5 |
| Skill_Tamer_Z | 스킬 아이콘 | 64~96 | 그림 속 효과 선명 | 5 |
| Skill_Warrior_Q | 스킬 아이콘 | 64~96 | 그림 속 효과 선명 | 5 |
| Skill_Warrior_X | 스킬 아이콘 | 64~96 | 그림 속 효과 선명 | 5 |
| Skill_Warrior_Z | 스킬 아이콘 | 64~96 | 그림 속 효과 선명 | 5 |
| SlotCommon | 가방 등급 칸 | 64~80 | 테만 있음 — 이득 적은 편 | 5 |
| SlotEmpty | 가방 등급 칸 | 64~80 | 테만 있음 — 이득 적은 편 | 5 |
| SlotEpic | 가방 등급 칸 | 64~80 | 테만 있음 — 이득 적은 편 | 5 |
| SlotLegendary | 가방 등급 칸 | 64~80 | 테만 있음 — 이득 적은 편 | 5 |
| SlotRare | 가방 등급 칸 | 64~80 | 테만 있음 — 이득 적은 편 | 5 |
| SlotUncommon | 가방 등급 칸 | 64~80 | 테만 있음 — 이득 적은 편 | 5 |
| StatusPlate | 창·줄·띠 부품(9조각) | 100~600 폭 | 테·광택 또렷 — 화면에 자주 보임 | 5 |
| TabOff | 창·줄·띠 부품(9조각) | 100~600 폭 | 테·광택 또렷 — 화면에 자주 보임 | 5 |
| TabOn | 창·줄·띠 부품(9조각) | 100~600 폭 | 테·광택 또렷 — 화면에 자주 보임 | 5 |
| Toast | 창·줄·띠 부품(9조각) | 100~600 폭 | 테·광택 또렷 — 화면에 자주 보임 | 5 |
| ToggleKnob | 설정 스위치 손잡이 | 약 30~40 | 작아서 이득 적은 편 | 5 |
| ToggleTrack | 설정 스위치 길 | 약 60×24 | 작아서 이득 적은 편 | 5 |
| WarMeterFrame | 창·줄·띠 부품(9조각) | 100~600 폭 | 테·광택 또렷 — 화면에 자주 보임 | 5 |
| Weapon_Archer_T1 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |
| Weapon_Archer_T2 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |
| Weapon_Archer_T3 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |
| Weapon_Archer_T4 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |
| Weapon_Archer_T5 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |
| Weapon_Archer_T6 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |
| Weapon_Archer_T8 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |
| Weapon_Mage_T1 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |
| Weapon_Mage_T2 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |
| Weapon_Mage_T3 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |
| Weapon_Mage_T4 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |
| Weapon_Mage_T5 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |
| Weapon_Mage_T6 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |
| Weapon_Mage_T8 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |
| Weapon_Tamer_T1 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |
| Weapon_Tamer_T2 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |
| Weapon_Tamer_T3 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |
| Weapon_Tamer_T4 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |
| Weapon_Tamer_T5 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |
| Weapon_Tamer_T6 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |
| Weapon_Warrior_T1 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |
| Weapon_Warrior_T2 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |
| Weapon_Warrior_T4 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |
| Weapon_Warrior_T5 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |
| Weapon_Warrior_T6 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |
| Weapon_Warrior_T8 | 무기 아이콘 | 64~96(상점·가방) | 날·장식 선명 | 5 |

## 3. 이득 적음 — 64px 아래 아이콘·글리프·배지·지도 표시 (141개 = 705크레딧)
화면에서 16~56px로만 보여서 고급 차이가 거의 안 보여요. 다시 받지 않음 권장(앞으로 새로 만드는 최종만 고급).

BadgeArtisan, BadgeDot, BadgeGrayLegend, BadgeHaloR1, BadgeHaloR2, BadgeHaloR3, BadgeHaloR4, BadgeHaloR5, BadgeHornsR1, BadgeHornsR2, BadgeHornsR3, BadgeHornsR4, BadgeHornsR5, BadgeLeanCare, BadgeLeanGuild, BadgeLeanTame, EmoAngry, EmoDizzy, EmoOuch, EmoStress, EmoTears, GlyphAuto, GlyphBack, GlyphBag, GlyphBow, GlyphCheck, GlyphClose, GlyphExclaim, GlyphExpand, GlyphGear, GlyphKindWing, GlyphLock, GlyphMap, GlyphMenu, GlyphQuest, GlyphShrink, GlyphSneakyHorns, GlyphSort, GlyphStaff, GlyphSword, IconAltar, IconAnnounce, IconAttack, IconBag, IconBloodSword, IconBone, IconBoot, IconBruteHorn, IconCandy, IconCharacter, IconCharacterF, IconChipGhostKing, IconChipPumpkinKing, IconClassChange, IconClover, IconCoin, IconDemon, IconExp, IconGoblinTooth, IconGoldGuard, IconGoldPile, IconGoose, IconHammer, IconHeart, IconHelp, IconJelly, IconKnightCrest, IconMedalBronze, IconMedalGold, IconMedalSilver, IconMonBatGoblin, IconMonBigSlime, IconMonGhostKing, IconMonGhostMinion, IconMonGoblin, IconMonGoblinBrute, IconMonLittleGhost, IconMonPumpkinKing, IconMonPumpkinSlime, IconMonSkeleton, IconMonSkeletonKnight, IconMonSlime, IconNews, IconNickname, IconNoBuff, IconNoLoot, IconOpening, IconPetBabySlime, IconPetPaw, IconPotionHP, IconPotionMP, IconPouch, IconQuestMarker, IconQuestMarkerArrow, IconRankArtisan, IconRankHonor, IconRankInfamy, IconRankPvP, IconRanking, IconRebirth, IconSafe, IconScrollEnh, IconScrollMove, IconSettings, IconShieldBlue, IconSkills, IconSlimeCore, IconSprout, IconTravel, IconVacation, IconWantedStar, IconWings, JobTag, LevelBadge, LevelBadgeArtisan, LevelBadgeHalo, LevelBadgeHorns, MapAltar, MapArrowHalo, MapArrowHorns, MapArtisanGuild, MapBlacksmith, MapCrossroads, MapGooseNest, MapGrudgeSack, MapHaloTown, MapHornsTown, MapHuntEntrance, MapKaiju, MapPlayerArrow, MapPotionShop, MapPvP, MapQuestTarget, MapZoneGoblinWoods, MapZoneHauntedHollow, MapZoneMeadow, MapZonePumpkinField, MapZoneSkeletonRuins, ShardBase, Star, WarCrownPip

## 4. 다시 받지 않음 권장 (7개)
- FactionTitle — (옛) 진영 화면 제목: 새 진영 화면으로 바뀌면 안 씀 — 다시 받지 않음 권장
- FactionPremise — (옛) 진영 화면 설명판: 같음 — 권장 안 함
- FactionFooter — (옛) 진영 화면 아래판: 같음 — 권장 안 함
- ClassCardHalo — (옛) 직업 카드(빛): 새 ClassPick로 대체 — 권장 안 함
- ClassCardHorns — (옛) 직업 카드(뿔): 새 ClassPick로 대체 — 권장 안 함
- BannerGold — 축하 배너(금 리본 + 날개): 보상 팝업 새 부품과 겹침 — 새로 그리면 다시 받지 않음
- RewardRays — 보상 빛살(흰색, 칠해서 돌림): 빛 그림이라 고급 차이 거의 없음 — 권장 안 함

## 합계
- 이득 큼만: 18개 = **90크레딧** / + 이득 중간 전부: 98개 = 490크레딧 / 전부(4번 빼고): 239개 = 1195크레딧.
- 추천: **1번 표 전부** + 2번에서 늘 보이는 버튼 7개(BtnPrimary·BtnSecondary·BtnConfirm·BtnSquare·BtnRound·BtnAttack·BtnPotion)와 MinimapRing = 26개 = **130크레딧**.
