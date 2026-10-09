# 지금 게임에 쓰이는 옛 그림 목록 (이미지 개발, 2026-10-06)
> 기록용(10/06 당시). 지금과 다른 점: 그 뒤 많은 키가 Firefly 그림으로 바뀜 — 지금 상태는 `Config.UIArt`·`art/ui/asset_ids.json`을 볼 것. 메인 Studio 반영은 메인 반영 1 몫(10/08부터), 빌린 그림·아이콘도 제 그림을 새로 그린다(A23-96 `remake_list_2026-10-09.md`).
> 지금 기준: AGENTS.md · SPEC_ADDENDUM A23 · RELEASE_PLAN.

새 Firefly 그림이 승인·업로드되고 Studio에 들어가면 지울 옛 그림 목록이다. 읽기만 해서 만들었다.
- 확인한 것: `Config.luau`(작업 트리), `art/ui/asset_ids.json`, `art/approved.json`, `docs/art/art_cleanup_2026-10-06*.json`, `src/` 사용처.

## 요약
- `Config.UIArt.Parts`(`Config.luau` `Config.UIArt = {`부터):
  - **Id가 있는 키 97개**는 전부 옛 그림이다(GPT·Codex, 10-02~10-04).
  - Id가 빈 키 39개는 화면에서 코드 대체 모양으로 그려진다.
- Firefly 새 그림(10-05/06 승인)은 아직 Config에 하나도 없다.
  - 업로드만 된 것: IconMon* 5, IconCandy, IconPetBabySlime, 메뉴 버튼 5. id는 `asset_ids.json`(커밋 안 됨)에만 있다.
  - 핼러윈 커밋 때 Config에 들어간다.
- 파일 규칙: 키 `X`의 파일은 `art/ui/UIP_X.png`(원본 `art/out/UIP_X.png`)이다.
  - 예외: 새 그림은 `art/ui/<Key>.png`, 지형은 `art/ui/Tex_X.png`, 지도는 `art/ui/UI_MapParchment.png`.

## HUD (옛 그림 → 공통 키트·HUD 부품 묶음으로 교체)
| 키 | 화면 자리 | 주 사용처 |
|---|---|---|
| PanelCard, LevelBadge, PortraitRing | 상태판 틀·레벨 배지·초상 링 | HUD 719, 729, 808 |
| IconCoin, IconPouch | 금고·주머니 줄, 다음 무기 가격, 퀘스트 보상 | HUD 866, 873, 1665 |
| IconStar, IconStarEmpty | 뿔 현상수배 별, 퀘스트 머리 별, 이벤트 응원별 | HUD 896, 1278; EventHUD |
| BarTrack | 모든 바(XP·HP·MP·전쟁·이동·퀘스트·다음 무기·거위 줄다리기) | UIKit `ArtBar` |
| Pill | 전쟁 알약, 받기·교체, 이벤트 칩, 인트로 건너뛰기, 선택 화면 칩 | HUD·EventHUD·Intro·Pickers |
| ShieldHalo, ShieldHorns, Crown | 전쟁 미터 양 끝·왕관, 축복 칩, 자동 버튼 | HUD 1068, 1098, 1622 |
| IconSafe, IconSprout | 안전 지대·새싹 칩 | HUD 1236 |
| RibbonHeader | 퀘스트 머리 | HUD 1264 |
| PanelParchment | 퀘스트 줄·창, 이동 바, 다음 무기 카드, 물약 칸, 행운판, 별명 창 | 여러 곳 |
| IconScroll, IconSlime, IconGoose | 퀘스트 줄 아이콘(IconSlime → 새 IconMonSlime 자리) | HUD 101, 2392 |
| IconClover | 행운판 | EventHUD |
| BtnAttack + IconAttack, BtnSpecial + IconSpecial | 공격·스킬 버튼 | HUD 1549-1576 |
| BtnSquare, IconMap, IconGear | 지도·메뉴·자동 네모 버튼, 원한 유령 버튼 | HUD 1512-1617 |
| IconSword, Weapon_* 27개 | 다음 무기 카드 아이콘(PC) | HUD 1645, 2099 |
| IconPotionHP, IconPotionMP | 물약 칸 | VitalsUI 118 |
| IconLock | **안 쓰임**(src 어디에도 없음) | 바로 지워도 됨 |

## 진영 화면 (FreshTyped → Firefly 진영 화면 6장으로 교체)
- 보이는 것: FactionCard{Halo,Horns,Neutral}FreshTyped, FactionTitleFreshTypedBalanced, FactionPremiseFreshTyped, FactionFooterFreshTyped.
- 안 보이는 것: FactionTitleFreshTyped, FactionE 키 6개. 대체용으로만 남아 있다.

## 전투 효과·감정·지도
- FxShockRing, FxHitSpark, FxMagicBurst, FxSlash, FxDust (Fx.luau)
- EmoOuch, EmoTears, EmoDizzy, EmoAngry, EmoStress (몬스터 머리 옆 감정 스티커)
- MapParchment (세계 지도 배경)

## 지형 텍스처 15장 (Codex 작업 → Firefly 이음새 없는 타일로 교체)
- 키: `Tex_Grass, Tex_LeafyGrass, Tex_HaloTiles, Tex_Ground, Tex_DirtPath, Tex_CrownShardGround, Tex_CrackedLava, Tex_Cobblestone, Tex_Basalt, Tex_WoodPlanks, Tex_Slate, Tex_Sand, Tex_Rock, Tex_Marble, Tex_Limestone`
- 적용: `tools/apply_surface_materials.lua`가 `Config.UIArt.Parts.Tex_*`를 MaterialVariant ColorMap에 넣는다.

## Id가 빈 키 39개 (10-05 커밋 63b95d9에서 비움)
- 해당 키: Card*, ClassCard*, ShieldNeutral, TitleRibbon, Char* 18개, Icon{Exp, Heart, Wings, GoldPile, BloodSword, Gauge, Demon, NoBuff, ShieldBlue, NoLoot, Hammer, Altar, Boot}
- 화면에는 이미 안 보인다. 하지만 PNG와 `asset_ids.json` 기록은 남아 있고, 정리 기록에는 아직 "keep_until_replaced"로 되어 있다.
- 정할 것: `Config.UIArt.CardLayout`은 카드 PNG로 잰 값이다. 파일을 지워도 되는지는 검수가 정한다.

## 지울 때 순서 (AGENTS 규칙)
1. 새 그림이 승인되고 올라간 뒤, Config Id를 바꾼다.
2. 연습 Studio에서 `tools/device_view.py pc phone`으로 확인한다.
3. 게임성 개발이 메인 Studio에 넣는다.
4. 그다음에 옛 `art/ui`·`art/out` 파일과 `asset_ids.json` 기록을 지운다. `deleted <날짜> (was …)`로 남긴다.
