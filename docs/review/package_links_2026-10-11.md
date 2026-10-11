# PackageLink 점검 — 2026-10-11 (메인 반영 1)

근거: SPEC A23-136, `docs/design/roblox_publish_rules_2026-10-11.md` 보안 점검 5. 메인 Studio(place 81671223175574) Edit에서 읽기만 함. 아무것도 지우거나 바꾸지 않음.

## 결과
- PackageLink **99개**, 서로 다른 PackageId **27개**.
- **전부 소유자 = User 11753301316 (Darugi_S2)** = 이 place의 만든 사람(`game.CreatorId`, CreatorType User)과 같은 계정. 다른 사람·그룹 소유 0개. 전부 AssetTypeId 10(Model), 이름 "Roblox Generated Object".
- AutoUpdate: 파일(`build/GoodEvil.rbxlx`) 기준 **99개 모두 false**. (Studio 스크립트에선 AutoUpdate·Status를 못 읽음: RobloxScript 권한 없음.) 버전 번호는 전부 1.
- 안에 스크립트 없음(규칙 목록 5의 이전 확인과 같음, 이번엔 재확인 안 함).

## 위치별 개수
- `ServerStorage/CrossroadsKOld`: 52개
- `ServerStorage/KitStage`: 27개
- `Workspace/Map/Decor/HauntedHollow`: 20개

## PackageId 표

| PackageId | 개수 | 소유자(Creator) | 이름 | 부모 경로 |
|---|---|---|---|---|
| 81141808643475 | 2 | User 11753301316 (Darugi_S2) | Roblox Generated Object | Workspace.Map.Decor.HauntedHollow.GF_Arch<br>ServerStorage.KitStage.GF_Arch |
| 77208112814877 | 8 | User 11753301316 (Darugi_S2) | Roblox Generated Object | ServerStorage.KitStage.GF_Tree<br>Workspace.Map.Decor.HauntedHollow.GF_Tree |
| 110430139947138 | 3 | User 11753301316 (Darugi_S2) | Roblox Generated Object | Workspace.Map.Decor.HauntedHollow.GF_Willow<br>ServerStorage.KitStage.GF_Willow |
| 108323582216945 | 4 | User 11753301316 (Darugi_S2) | Roblox Generated Object | Workspace.Map.Decor.HauntedHollow.GF_Lantern<br>ServerStorage.KitStage.GF_Lantern |
| 129965433460141 | 5 | User 11753301316 (Darugi_S2) | Roblox Generated Object | Workspace.Map.Decor.HauntedHollow.GF_Mushrooms<br>ServerStorage.KitStage.GF_Mushrooms |
| 75847264531193 | 4 | User 11753301316 (Darugi_S2) | Roblox Generated Object | ServerStorage.KitStage.GF_Rock<br>Workspace.Map.Decor.HauntedHollow.GF_Rock |
| 76556272343060 | 2 | User 11753301316 (Darugi_S2) | Roblox Generated Object | ServerStorage.KitStage.K_Fountain<br>ServerStorage.CrossroadsKOld.K_Fountain |
| 138150055823518 | 2 | User 11753301316 (Darugi_S2) | Roblox Generated Object | ServerStorage.CrossroadsKOld.K_CrownShard<br>ServerStorage.KitStage.K_CrownShard |
| 134680201973665 | 5 | User 11753301316 (Darugi_S2) | Roblox Generated Object | ServerStorage.KitStage.K_Bench<br>ServerStorage.CrossroadsKOld.K_Bench |
| 83198252324794 | 9 | User 11753301316 (Darugi_S2) | Roblox Generated Object | ServerStorage.CrossroadsKOld.K_Lamp<br>ServerStorage.KitStage.K_Lamp |
| 129560971369618 | 3 | User 11753301316 (Darugi_S2) | Roblox Generated Object | ServerStorage.CrossroadsKOld.K_StallRed<br>ServerStorage.KitStage.K_StallRed |
| 130455047391717 | 2 | User 11753301316 (Darugi_S2) | Roblox Generated Object | ServerStorage.KitStage.K_StallBlue<br>ServerStorage.CrossroadsKOld.K_StallBlue |
| 132658338267168 | 2 | User 11753301316 (Darugi_S2) | Roblox Generated Object | ServerStorage.CrossroadsKOld.K_StallGreen<br>ServerStorage.KitStage.K_StallGreen |
| 83996745517766 | 2 | User 11753301316 (Darugi_S2) | Roblox Generated Object | ServerStorage.KitStage.K_Potion<br>ServerStorage.CrossroadsKOld.K_Potion |
| 136224445139337 | 2 | User 11753301316 (Darugi_S2) | Roblox Generated Object | ServerStorage.CrossroadsKOld.K_Guild2<br>ServerStorage.KitStage.K_Guild2 |
| 132536329142416 | 2 | User 11753301316 (Darugi_S2) | Roblox Generated Object | ServerStorage.KitStage.K_Gear<br>ServerStorage.CrossroadsKOld.K_Gear |
| 82446744618801 | 2 | User 11753301316 (Darugi_S2) | Roblox Generated Object | ServerStorage.CrossroadsKOld.K_Anvil<br>ServerStorage.KitStage.K_Anvil |
| 86664671339999 | 2 | User 11753301316 (Darugi_S2) | Roblox Generated Object | ServerStorage.CrossroadsKOld.K_Forge<br>ServerStorage.KitStage.K_Forge |
| 121777078323302 | 2 | User 11753301316 (Darugi_S2) | Roblox Generated Object | ServerStorage.KitStage.K_Altar<br>ServerStorage.CrossroadsKOld.K_Altar |
| 136257412466235 | 3 | User 11753301316 (Darugi_S2) | Roblox Generated Object | ServerStorage.KitStage.K_Brazier<br>ServerStorage.CrossroadsKOld.K_Brazier |
| 110136633746885 | 4 | User 11753301316 (Darugi_S2) | Roblox Generated Object | ServerStorage.CrossroadsKOld.K_PadBase<br>ServerStorage.KitStage.K_PadBase |
| 101705985682378 | 2 | User 11753301316 (Darugi_S2) | Roblox Generated Object | ServerStorage.KitStage.K_Nest<br>ServerStorage.CrossroadsKOld.K_Nest |
| 127080708298829 | 3 | User 11753301316 (Darugi_S2) | Roblox Generated Object | ServerStorage.CrossroadsKOld.K_PoleHalo<br>ServerStorage.KitStage.K_PoleHalo |
| 139687601212418 | 3 | User 11753301316 (Darugi_S2) | Roblox Generated Object | ServerStorage.KitStage.K_PoleHorns<br>ServerStorage.CrossroadsKOld.K_PoleHorns |
| 109900161242056 | 2 | User 11753301316 (Darugi_S2) | Roblox Generated Object | ServerStorage.KitStage.K_MarketArch<br>ServerStorage.CrossroadsKOld.K_MarketArch |
| 133123107676921 | 2 | User 11753301316 (Darugi_S2) | Roblox Generated Object | ServerStorage.KitStage.K_NoticeBoard2<br>ServerStorage.CrossroadsKOld.K_NoticeBoard2 |
| 71401040660667 | 17 | User 11753301316 (Darugi_S2) | Roblox Generated Object | ServerStorage.KitStage.K_Curb<br>ServerStorage.CrossroadsKOld.Curb |

## 판정(검수 결정용)
- 지금 계정 것이 아닌 PackageId: **0개** → 지우거나 끊을 것 없음.
- 참고: 이 패키지들은 Studio 'Generate'로 만든 모델이 패키지로 저장된 것으로 보임(이름 Roblox Generated Object). 숨긴 구역(HauntedHollow)·옛 소품 보관(CrossroadsKOld, KitStage)에 있음.
- 추가로 하려면: 베타 전에 패키지 링크를 끊어(Unlink) 외부 갱신 가능성 자체를 없앨 수 있음(검수 결정).

방법: `game:GetDescendants()`의 ClassName=PackageLink → PackageId·VersionNumber, `MarketplaceService:GetProductInfo(id, Asset).Creator`; AutoUpdate는 rbxlx 파싱.
