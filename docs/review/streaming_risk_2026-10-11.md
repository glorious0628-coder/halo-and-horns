# StreamingEnabled 위험표 + 오프닝 미리 받기 계획 (게임성 개발 1 → 검수, 2026-10-11)

> API 읽기 작업 두 번(Sonnet: dev1_streaming_risk ~$1.49 — 길이 한도로 B표 머리에서 끊김, 이어서 dev1_streaming_risk2 ~$1.23)을 합친 것. 코드는 바꾸지 않았다. [확인] = 줄을 읽음, [추정] = 읽지 않았거나 Roblox 동작을 기억에 의존. **켜기 결정은 검수.**

# StreamingEnabled 위험표 + 오프닝 preload 계획 (게임성 개발 1 → 검수)

파일은 하나도 바꾸지 않았다. 표기는 이렇다.
- **[확인]** 해당 줄을 직접 읽었다.
- **[추정]** 줄을 읽지 않았거나, Roblox 동작을 기억에 의존했다.

## 0. 먼저 읽을 요약

1. **코드가 가장 약한 곳은 "멀리 있는 월드 물체를 가리키는 안내"다.**
   - 대장간 모루(anvil), 이동 패드(pad), 문(gate), 이야기 NPC, 물약 상인, 분수가 해당한다.
   - 지금은 `workspace`가 전부 있다고 믿고 찾는다. 스트리밍이 켜지면 이 물체들은 멀리 있을 때 없다.
   - 대부분 없으면 조용히 `nil`을 돌려준다. 첫 10분의 "대장간 가기" 단계가 그 영향을 받는다.
2. **오프닝(Intro)이 가장 크게 깨진다.**
   - 카메라가 Crown(15,344,-18), Halo(0,16,-410), Horns(0,16,410)로 날아간다 [확인: `Intro.luau:36-45, 237, 250, 256`].
   - 캐릭터는 교차로 스폰(0,0,-25)에 서 있다 [확인: `Config.luau:1636`]. Crown까지 약 345, Halo까지 약 385, Horns까지 약 435 stud다.
   - 스트리밍 반경이 작으면 빈 하늘과 안개가 보일 것이다 [추정: 카메라가 아니라 캐릭터 기준으로 스트리밍한다는 가정].
3. **서버의 이동(`PivotTo`)도 위험하다.**
   - 서버가 캐릭터를 먼 땅으로 옮기는 줄이 있다 [확인: `ZoneService.luau:259`, `PlayerService.luau:498`].
   - 도착 지점이 아직 안 왔으면 떨어질 수 있다 [추정].
   - 서버 쪽이라 게임성 개발 2 몫이지만, 켜기 전에 반드시 필요하다. 클라이언트에서 쓸 수 있는 자리가 있다 (표 T-9).
4. **`ReplicatedFirst`는 없다** [확인: glob 결과 없음]. 옛 계획(`docs/design/beta_basics_2026-10-05.md:1817`)의 `Loading.client.luau`는 만들어지지 않았다. 로딩 커버도 없다.
5. **지금 preload는 오히려 한꺼번에 많이 받는다.**
   - `Audio.Start`가 소리 약 118개를 한 번에 `PreloadAsync`한다 [확인: `Audio.luau:1402-1427`].
   - `UIKit.Start`는 UIArt 28개를 받는다 [확인: `UIKit.luau:242-245, 4025-4032`].
   - 오프닝 중에 UI 그림과 경쟁한다.
6. **`.rbxlx`가 이 체크아웃에 없다** [확인: glob 결과 없음].
   - SurfaceAppearance id와 `Map` 안의 실제 구조(Model인지 Folder인지 Part인지)는 읽지 못했다.
   - 이 부분은 전부 [추정]이다.

## 1. 위험표

심각도는 이렇다.
- **상** = 그 세션 내내 기능이 깨진다.
- **중** = 다시 찾을 때까지 틀리다.
- **하** = 보기만 어색하다.

"방식"은 어떻게 찾는지를 뜻한다.
- 매번 = 호출할 때마다 다시 찾는다.
- 1회 = Init/Start/build 때 한 번만 찾는다.
- 신호 = `DescendantAdded` 같은 이벤트로 받는다.

### A. 오프닝과 첫 10분 (먼저 고칠 것)

| # | 파일:줄 | 무엇을 찾나 | 방식 | 없으면 무슨 일이 | 심각도 | 고치는 법 |
|---|---|---|---|---|---|---|
| T-1 | `Intro.luau:220-229`, `231-280` | `Map.Landmarks.CrownOfBalance`, 그리고 카메라가 가는 Crown/Halo/Horns 풍경 | 매번(`crownPos`). 풍경은 스트리밍 몫 | 위치는 `SPOT.Crown` 폴백이 있어 맞다 [확인]. 하지만 모델 자체와 두 성(castle)이 안 와서 하늘·안개·빈 땅만 보일 수 있다 [추정] | **상** (오프닝 전체) | `Intro.Play`(`:311`)에서 `task.spawn`으로 `Player:RequestStreamAroundAsync`를 Crown, Halo, Horns에 건다(timeout 있음, `pcall`). 스트리밍이 꺼져 있으면 에러가 나므로 `workspace.StreamingEnabled`를 먼저 확인한다. 옛 로그에 이 에러가 있다 [확인: `docs/art/verification_2026-10-08/crossroads_check/pc/log.txt:31`]. 그래도 비면 Crown 모델만 Persistent |
| T-2 | `HUD.luau:4850-4856` (`L.BlacksmithTarget`), 쓰는 곳 `4863, 4968, 5059, 5084` | `Map.Landmarks.ArtisanGuild.Anvil` | 매번 | 안 오면 `nil`. `showGuide`가 `false`를 돌려 안내가 안 생긴다 [확인: `:4749-4750`]. `ForgeTarget`은 "교차로로 가는 길" 안내로 바뀐다 [확인: `:4863-4865`] | **상** (첫 10분 Forge 단계) | 모루 위치를 Config에서 가져와 `QuestTarget.Anchor`로 폴백한다. 길찾기 위치는 Config 값으로, 눈에 보이는 안내만 월드 물체에 붙인다. `ArtisanGuild`는 Persistent 후보 |
| T-3 | `QuestTarget.luau:343-347`, `427-451` (`Blacksmith`, `BlacksmithMark`, `smithWalk`, `smithFrom`) | 같은 모루 | 매번 | `smithWalk`가 false가 되어 "걸어서 가는 곳"이 "이동(trip)"으로 바뀐다 [확인: `:436-438`]. 모루가 오면 표시가 바뀐다 | **상→중** | T-2와 같은 폴백을 한 곳에 둔다(한 함수 `anvilPos()`) |
| T-4 | `HUD.luau:4748-4838` (`showGuide`) | 안내 대상 `part` | 한 번 잡고 계속 씀 | 빔 `Beam`(`:4775`), `Attachment`(`:4757`), `BillboardGui`(`:4816`)를 월드 파트의 자식으로 만든다. 그 파트가 스트림아웃되면 안내도 같이 사라진다. `Heartbeat`는 지워진 파트의 `Position`을 계속 읽는다(`:4821`) [추정: 지워진 뒤의 동작은 읽지 않았다] | **중~상** | 안내 시각 요소는 클라가 만든 앵커(`localAnchor`, `:4680-4696`)에 붙이고, 대상 `Position`을 복사해 쓴다 |
| T-5 | `HUD.luau:4699-4717` (`findTravelTarget`), `QuestTarget.luau:310-339` (`Travel`) | `Map.Pads.Pad_<zone>`, `Map.Gates.Gate_<zone>`, `Map.Decor.Bridge_*` | 매번 | 둘 다 없으면 스폰 위치 앵커로 폴백해 안전하다 [확인: `HUD:4716`, `QuestTarget:338`]. 하지만 하나만 오면 그것만 고른다 (pad↔gate 거리 비교가 틀림 [확인: `QuestTarget:330-336`]) | 중 | 폴백은 좋다. pad/gate 선택은 Config 위치 기준으로 한다 |
| T-6 | `FountainFx.luau:256-274`, `130-147` | 이름이 `SPECS`에 있는 분수 모델(`K_Fountain`, `Town_Halo_Fountain`, `Town_Halo_Fountain3`) | 신호(`DescendantAdded`) + 시작 때 `GetDescendants` | `task.defer`로 한 프레임 뒤 만들고, `GetBoundingBox` 전에 `S.Built[model]=true`를 먼저 켠다 [확인: `:131-133`, `:258-263`]. 모델이 일부만 왔으면 물줄기 위치와 크기가 틀리고 다시 안 만든다(스트림아웃 후 새 인스턴스일 때만 다시 만든다). 또 `S.Emitters`(`:67`)는 강한 참조이고 지우지 않는다 [확인: `:107`] | **중~상** (분수는 오프닝 2번 샷 + 광장 중심) | 분수 모델을 `Atomic`으로 하거나 스폰 쪽 하나는 Persistent. 빌드는 `PrimaryPart`/자식이 다 온 뒤에 한다. `S.Emitters`는 `Parent == nil`일 때 지운다 |
| T-7 | `MonsterMotion.luau:107-155`, `182-199` | `workspace.Monsters` 안 모델의 `MonsterKind`, `CustomVisual`, `Bone`들, `HumanoidRootPart` | 매 프레임 훑되 모델당 1회 추적 | 처음 볼 때 `CustomVisual`이나 뼈대가 아직 없으면 `track`이 `false`를 돌려주고, 그 모델은 나갈 때까지 다시 시도하지 않는다 [확인: `:192-198`]. `Root`도 `nil`로 굳는다(`:121`, `:200`). 몬스터가 처음부터 멈춘 자세로 보일 수 있다 | **중~상** (보이는 모든 몬스터) | 서버가 몬스터 모델 `ModelStreamingMode = Atomic`을 켠다(게임성 개발 2). 클라는 `false`를 캐시하지 않고 `ChildAdded`로 다시 시도하며, `Root`를 매번 다시 찾는다 |
| T-8 | `QuestTarget.luau:212-225` (`StoryNpc`), 쓰는 곳 `:528-540` (`npcEntry`), `HUD.luau:5301-5309` | 태그 `StoryNpc`(`CollectionService:GetTagged`)가 붙은 NPC | 매번 | 클라의 `GetTagged`는 지금 와 있는 것만 돌려준다 [추정]. NPC가 멀면 `nil` → 마커가 안 생긴다 [확인: `:529-530`]. 멀리 있는 대화 NPC 퀘스트는 가리킬 곳이 없다 | **중~상** | 위치를 Config 목록(`Config.TownNpcs.List`, `TownReact.luau:40`)으로 폴백한다 [추정: 위치가 들어 있는지는 못 읽음]. 핵심 NPC 1~2명만 Persistent |
| T-9 | 서버: `ZoneService.luau:259`, `PlayerService.luau:498`. 클라 연결점: `FirstSteps.luau:131-152`, `239-243` | 이동할 도착지 땅 | — | 서버가 `PivotTo`만 하고 스트리밍을 기다리지 않는다. 도착지가 안 왔으면 떨어질 수 있다 [추정] | **상** | `StreamingIntegrityMode = PauseOutsideLoadedArea`. 클라는 Fx `Travel`(검은 화면 `TRAVEL.Start`, `data.To`)에서 `RequestStreamAroundAsync(Config.Zones[To].Spawn)`을 건다. 서버도 이동 전에 `Player:RequestStreamAroundAsync`를 건다(게임성 개발 2) |


### B. 지도·분위기·소리·나머지 (이어 쓴 판)
#### B 표 (T-10 … T-27)

방식: 매번 = 프레임·주기 반복 / 1회 = 한 번만 / 신호 = 이벤트.
[확인] = 코드를 직접 읽음. [추정] = 코드로 알 수 없어 짐작함.

| # | 파일:줄 | 무엇을 찾나 | 방식 | 없으면 | 심각도 | 고치는 법 |
|---|---|---|---|---|---|---|
| T-10 | MiniMap.luau:751-758, 1126-1129 | `Map.Landmarks.ArtisanGuild.Anvil` (대장간 아이콘) | 1Hz | 아이콘이 안 보임. 한 번 본 뒤엔 `S.smithPos`가 위치를 기억함 [확인] | 하 | 좌표를 Config에 둔다. WorldMap.luau:86에 `GUILD_FALLBACK`이 이미 있음. 같은 값을 쓴다. |
| T-10b | MiniMap.luau:734-749 | 물약 상인 | 1Hz | Config 좌표 대체가 있어 문제 없음 [확인] | 하 | 그대로 둔다. |
| T-10c | MiniMap.luau:1096-1117 | `Map.Pads` 중 `TravelTo`가 있는 마을 패드 | 1Hz | 안 보이다가 가까이 가면 나타남 [확인] | 하 | 패드 좌표를 Config에 둔다. 또는 패드를 작은 Persistent 모델로 만든다. |
| T-11 | MiniMap.luau:773-790, 877-910 | 다른 플레이어 캐릭터 `HumanoidRootPart`, `workspace.Monsters` 자식 | 매번(주기) | 멀리 있는 점·몬스터가 안 보임 [추정]. 로컬 캐릭터는 항상 있음. | 하 | 그대로 둔다. 멀리 있는 점은 안 보여도 된다. |
| T-12 | WorldMap.luau:903-909, 1450-1451, 1674 | `Map.Pads` (마을 패드 글리프) | **1회** (`build()`는 `built` 플래그로 한 번만) | 첫 M 키 때 패드가 스트리밍되지 않았으면, 이번 접속 동안 마을 패드 아이콘이 안 생김 [확인] | **중** | 패드 그리기를 `refreshLandmarks`(1679, 열 때마다 호출)로 옮긴다. 또는 Config 좌표 목록을 쓴다. |
| T-13 | WorldMap.luau:592-603, 1679-1682 | `Landmarks.MarketSign`, `ArtisanGuild` | 열 때마다 | 길드는 `GUILD_FALLBACK`이 있음. `MarketSign`은 대체가 없음. 멀면 `placeMovable(...nil)`이라 안 그려질 것 [추정] | 하 | `MarketSign` 좌표를 Config에 추가한다. |
| T-13b | WorldMap.luau:605-620 | `Effects.GoldenGoose` | 열린 동안 10Hz | Config 둥지 좌표로 대체됨 [확인] | 하 | 그대로 둔다. |
| T-14 | WorldMap.luau:295-301, 1743-1752, 1758-1763 | 괴수 플레이어·원한 자루 운반자의 `Character.HumanoidRootPart` | 열린 동안 10Hz | 그 플레이어가 멀면 `rootOf`가 nil이라 마커가 사라짐. 괴수 위치를 못 봄 [확인] | **중** | 서버가 위치를 속성으로 쓴다 (`GameState.KaijuPos`, 플레이어 `SackPos`, 1~2초마다). 게임성 개발 2 몫. |
| T-15 | Panels.luau:2036-2060 (`WSHOP.Access`) | `Map→Landmarks→ArtisanGuild→Anvil`, 모루의 `HHC_BlacksmithPrompt` | 창 열 때 + 구매 전 | 하나라도 없으면 `T.WeaponFar`. 길드 모델이 먼저 오고 모루 파트가 늦게 오면 가까이 서도 "멀다"고 나옴 [추정]. 허용 거리는 `Distance = 12` (269줄) | **중** | 길드 모델을 Atomic으로 만든다. 모루 파트는 길드 모델 안에 둔다. MinRadius를 12보다 크게 잡는다. |
| T-16 | Panels.luau:2064-2082 (`ShowWay`) | 교차로에서 모루 | 버튼 누를 때 | 모루가 멀면 target이 nil이라 `false`. "길 보여줘"가 가장 필요한 때에 실패함 [확인] | **중** | T-2와 같은 뿌리. 모루 좌표 Config 로컬 앵커를 쓴다. HUD에 `localAnchor`가 이미 있다. |
| T-16b | Panels.luau:873-881 | `Landmarks.Altar` | 윤회 창 열 때 | nil이면 거리 검사를 건너뛰고, 서버가 다시 검사함 [확인] | 하 | 그대로 둔다. |
| T-17 | VitalsUI.luau:70-91 | 교차로의 `Map.NPCs.<PotionMerchant>` | 물약 0개로 누를 때 | 상인이 멀면 아무 일도 안 일어남 (조용히 실패) [확인] | **중** | MiniMap.luau:743-747과 같이 `Crossroads.Spawn + PotionMerchantOffset`으로 로컬 앵커를 만든다. |
| T-18 | StoryNpcs.luau:89-111, 23, 27 | 태그 `StoryNpc` 모델 + 안의 `ProximityPrompt` | 0.5초마다 | NPC가 들어온 뒤 최대 0.5초 동안 "!"와 프롬프트가 서버 기본값임. G키로 누를 수 있음 [추정]. "!"는 90스터드까지 보이는데(27줄), 스트리밍은 NPC가 가까울 때만 보내 줌 | 중~하 | `CollectionService:GetInstanceAddedSignal(tag)`에서 바로 `Refresh`한다. MinRadius를 100 이상으로 둔다. NPC 모델은 Persistent 후보. |
| T-19 | TownReact.luau:48-66, 107-127, 143 | 태그 `NPC`/`TownFolk` 모델, `GetPivot`, `Head` | 1초마다 | 반경 30 안에 NPC가 안 오면 말풍선이 없음. `Head`가 아직 없으면 `Say`가 그냥 return함 [확인] | 하 | MinRadius가 30보다 크면 문제 없음. |
| T-20 | WeatherFx.luau:254-259, 262-283, 382-389, 224-234 | 태그/속성 `LampLight` 조명, 카메라 위 지붕 레이 | 1회 + 신호 + 레이 주기 | 늦게 오는 램프는 `DescendantAdded`와 `GetInstanceAddedSignal`로 처리됨 [확인]. 지붕이 안 왔으면 "지붕 없음"이라 판단해 비가 실내에도 보일 수 있음 [추정] | 하 | 지붕 파트는 카메라 바로 위라 MinRadius 안에 들어옴. 그대로 둔다. |
| T-21 | Shared/Ground.luau:28-41; Config.luau:1725-1760 | Include 필터: Terrain, `Map.Ground`, `Decor.Bridge_*`, `*Props` 셀의 Bridge, 태그 `WalkGround` | 레이 때마다. 필터는 5초 캐시 | `Dirty`는 태그 변화로만 켜짐. 새로 스트리밍된 다리 셀은 최대 5초 동안 레이에 안 잡히고, 이펙트가 땅에서 뜸 [추정]. 레이 실패 시 `pos-3` 또는 원래 위치로 대체 (LandShadow:71, SkillFx:148) [확인]. 서버도 같은 모듈을 쓰지만 서버는 스트리밍 영향이 없다. | 하~중 | 다리에 `WalkGround` 태그를 붙인다 (이미 신호 처리됨). 또는 `Map.Decor.DescendantAdded`에서 이름에 "Bridge"가 있으면 `Dirty`를 켠다. |
| T-21b | LandShadow.luau:166-171, 105-132; SkillFx.luau:50-60; Fx.luau:750 | `workspace.Monsters`(`WaitForChild` 30초), 클라이언트가 만든 폴더 | 신호 | `DropPos`는 서버가 주므로 의존이 적음. 클라이언트가 만든 `LandShadows`/`SkillFx` 폴더는 스트리밍과 무관함 [확인] | 하 | 그대로 둔다. |
| T-22 | PetFollow.luau:42-67, 223-226, 214-260 | 클라이언트가 만든 `ClientPets`, 주인 `HumanoidRootPart`, 땅 레이 (Exclude 필터) | 매 프레임 | 남의 펫은 주인이 스트리밍 밖이면 `(0,-500,0)`으로 숨음 (자연스러움) [확인]. 레이가 안 맞으면 nil [확인]. 그때의 높이 처리는 안 읽음. | 하 | 그대로 둔다. |
| T-23 | Audio.luau:912-949 | `Map.Decor`의 `*Waterfall` 모델 (`GetBoundingBox`) + Config `Spots` 6개 | 신호 (`ChildAdded`) | 파트가 부분만 왔을 때 `GetBoundingBox`로 위치가 틀어짐. `done[m]=true`라 고쳐지지 않음 [추정]. 스트리밍 아웃 후 다시 들어오면 새 인스턴스라 `anchor`가 또 생겨 **물소리가 겹침** [확인: done이 인스턴스 키]. Spots 소리는 클라이언트가 만든 파트라 안전함 [확인] | **중** | 위치를 Config `Spots`로 옮기고 모델 스캔은 끈다. 쓰려면 `done`을 이름+좌표 키로 바꾼다. 점검: `workspace.AudioAmbient` 안 `WaterfallSound` 개수. |
| T-24 | Audio.luau:984-998, 1213-1227; Fx.luau:1236, 1422, 4678-4684; MonsterLabels.luau:274-304; FirstSteps.luau:170-187; HUD.luau:5236-5267 | `workspace.Monsters` 자식 | 매번(주기) | 멀리 있는 몬스터는 안 보임. 모델이 부분만 왔을 땐 `bb`/루트 null 검사로 건너뜀 [확인]. 공격 사거리(≤~30)는 MinRadius 안이라 괜찮음 [추정] | 하 | MinRadius ≥ 100이면 사실상 문제 없음. |
| T-25 | ClientMain.client.luau:15; Keybinds.luau:516-523; ShopUI.luau:503-504, 485-486; WeatherFx.luau:382; FountainFx.luau:273-274 | `workspace.DescendantAdded` 리스너 5개 + 시작 때 `GetDescendants` | 신호 | 스트리밍 땐 파트가 들어올 때마다 리스너 5개가 돈다 (매번 `IsA` 한 번이라 가벼움). `CROWN.Watched`가 강한 키 테이블이라 이름표가 들락날락하면 계속 쌓임 [확인] | 하 | `Watched`를 `{__mode="k"}` 약한 키로 바꾼다. 리스너는 한 곳(디스패처)으로 합친다. |
| T-26 | SupporterBoard.luau:134-153 | 태그 `SupporterBoard` 파트 | 1회 + 신호 | `GetInstanceAddedSignal`로 처리됨. 스트리밍 아웃 시 SurfaceGui이 사라지고 다시 들어오면 새로 그려짐 [확인] | 없음 | 그대로 둔다. |
| T-27 | HUD.luau:5373-5397 | `Landmarks.CrownShard`/`Fountain` (스토리 안내) | 안내 요청 때 | 없으면 Config 좌표로 임시 앵커를 만듦 [확인] | 하 | 그대로 둔다. |

**문제 없음 [확인]**
- ZoneLook: Terrain의 `Clouds`와 Lighting/속성만 읽는다 (ZoneLook.luau:297). Terrain은 항상 있다.
- LightCap: `Players:GetPlayers()`로 온 캐릭터만 돈다 (LightCap.luau:46-50).
- CameraFollow: `CurrentCamera`와 내 캐릭터만 쓴다.
- Audio의 구역 음악·날씨 루프: `ZoneId` 속성과 `GameState`만 읽는다 (Audio.luau:1447-1448, 843-891).

**빠뜨린 것 / 미확인**
- HUD.luau:4699-4893의 패드·문 찾기는 T-5와 같은 뿌리라 새 행을 만들지 않았다.
- QuestMarker는 목표를 HUD에서 받는다 (QuestMarker.luau:844-858). 이는 T-3 몫이고, 이번엔 중복해서 읽지 않았다.
- PetFollow의 레이 실패 처리는 줄 125 이후만 훑었고 그 부분은 읽지 않았다.

## Persistent 후보 (모델 단위, 작은 것만)

Persistent는 접속 때 항상 로드된다. 큰 건물에 쓰면 접속이 느려진다. 먼저 Config 좌표로 해결하고, 그래도 필요한 작은 모델에만 쓴다.

1. **`Map.Pads` 패드 파트** (작음). 길 안내(T-5), 미니맵·세계지도 아이콘(T-10c, T-12)에 쓰인다.
2. **`StoryNpc` 모델** (몇 개). 퀘스트 안내와 "!"가 멀리서도 필요하다 (T-18, T-8).
3. **`ArtisanGuild.Anvil`**. 큰 길드 모델 전체가 아니라, 모루만 작은 별도 모델/파트로 분리해서 Persistent로 둔다. 길드 건물은 Atomic. 이유: T-2, T-15, T-16. 좌표 Config 대체가 쉬우면 Persistent는 필요 없다.
4. **황금 거위 `Effects.GoldenGoose`** (선택). 지금도 Config 둥지 좌표 대체가 있다. 가능하면 안 쓴다.
5. **교차로 물약 상인 NPC** (선택). Config 오프셋으로 대체하면 필요 없다 (T-17).

**Persistent로 하지 않는 것**
- 폭포 모델: 소리는 Config Spots로 해결한다.
- 분수, 지붕, 램프, 다리 셀, 큰 건물 일반.

## 2. Preload 계획

**현재 상태 [확인]**
- `UIKit.Start`는 `NOTIFY.PreloadArt` 28개를 `task.spawn`으로 미리 불러온다 (UIKit.luau:242-245, 4025-4032). 창·알림용 그림만이고, **HUD 기본 틀은 안 들어 있다.**
- `Audio.Start`는 `FILES` 전부 + 음악 8 + 보스 4 + 구역 소리 2 + 날씨 4, 약 118개를 한꺼번에 `PreloadAsync`한다 (Audio.luau:1402-1427). `task.spawn`이라 시작을 막지는 않는다. `Audio`는 ORDER의 맨 끝이다.
- 캐릭터 초상은 별도로 미리 불러온다 (HUD.luau:3177). 내 캐릭터라 스트리밍과 무관하다.
- `Config.UIArt` 전체는 약 300개 이상이다 [추정: 5686-6147 구간 grep이 약 300줄에서 잘림].
- 첫 몬스터(슬라임, 큰 슬라임, 고블린)는 `Shape = "Slime"/"Humanoid"` 코드 도형이라 메시 에셋이 없다 [확인: Config.luau:1988-1995].

**순서 (왼쪽이 먼저)**

| 순서 | 무엇 | 개수 | 언제 |
|---|---|---|---|
| P0 | UIKit 28개를 진영 변형만 골라 26개로 (RewardPanel/Ribbon Halo·Horns 중 내 쪽만). 여기에 **HUD 기본 틀**을 더한다: BtnAttack, BtnSpecial, 직업 Glyph(Sword/Staff/Bow), LevelBadge(+내 진영), PortraitRing, BarTrack, BarFill, MinimapFrame, MinimapRing, BtnPotion, QuestRow, NpcMarkerBubble, IconQuestMarker(+Arrow), IconPotionHP/MP 등 | 약 45~50 | `Start` 직후 (인트로가 도는 동안) |
| P1 | 인트로 중 진영·직업 선택 그림: FactionPickTitle/Halo/Horns/Soon, ClassPick 2, CLS 카드 12, Char* 12 (Neutral 6은 잠겨 있어 뺀다) | 약 30 | 인트로 시작 때 |
| P2 | 빛 마을 스폰 시야 (스폰 (0,0,-420), 마을 중심 (0,0,-515) [확인: Config.luau:1638-1641]). 서버가 스폰 전에 `Player:RequestStreamAroundAsync`로 그 주변을 미리 요청한다 (API는 문서로 확인 필요 [추정]). 클라이언트는 반경 150 안 MeshPart·SurfaceAppearance를 `PreloadAsync`한다. 개수는 이 저장소에서 센 적이 없다. Studio에서 센 값을 적는다. | 미정 [추정] | 스폰 직전 로딩 화면 |
| P3 | 첫 몬스터·첫 퀘스트 아이콘: IconMonSlime, IconMonBigSlime, IconJelly, IconSlimeCore, BarkBubble, BarkBubbleSlime, BarkBubbleBigSlime, IconCoin, IconExp, IconPotionHP, IconStar, GlyphExclaim | 약 12 | P0 직후 |
| P4 | 첫 소리 (Audio 1단계): 내 직업 Swing, Hit Soft/Heavy/Crit + 직업 Hit 3, KillPop, DieSlime, 금화·보상·QuestNew·QuestDone, WindowOpen, Deny, LevelUp, PowerUp, TalkBlip, BlipBright/Gleam, **HaloTown 음악 + HaloDay 소리** | 약 25 | `Audio.Start` 즉시 |
| P5 | 나머지 소리 (2단계): 나머지 `Files`, Night 루프 | 약 50 | `ClassChosen` 후 10초 뒤, 10개씩 `task.wait(0.5)` 간격 |
| P6 | 나머지 UI 그림 (세계지도 1024, MapTiles, 스킬 아이콘, 배지 등) | 필요한 만큼 | 첫 퀘스트 완료 뒤 한가할 때, 또는 창을 열기 직전 |

**미리 불러오지 않는 것**
- 숨은 구역 음악 3개: PumpkinPatch, HauntedHollow, SkeletonRuins (AGENTS: 숨김).
- 보스 레이어 4개 (구역에 들어갈 때 불러온다).
- 내 반대 진영의 마을 음악·소리 (Halo인 사람은 Horns 것 불필요).
- Rain / WinterWind 루프 (날씨가 바뀔 때 불러온다. 25초 루프라 늦게 시작해도 1.5초 페이드가 가린다 [추정]).
- 다른 진영 카드·캐릭터 그림, 스킬 아이콘 중 내 직업 외, Look·패스·메달 아이콘.

**나눌까, 미룰까**
- **Audio ~118: 나누고 미룬다.** 스트리밍이 켜지면 접속 직후 지형·메시와 118개 사운드가 네트워크를 함께 쓴다. 위 P4→P5→(구역 입장 때)로 나눈다. 구현 메모: Config에 소리 이름별 단계 표를 두고, `Audio.Start`는 1단계만 돌린다.
- **UIKit 28: 나누지 않는다.** 개수가 적고 작은 그림이다. 대신 진영 변형 선택 + HUD 기본 틀 추가가 효과가 크다. 지연은 필요 없다.
- 순서를 바꾸지는 않는다 (ClientMain ORDER는 그대로). `Audio`는 이미 맨 끝에서 시작한다 [확인: ClientMain.client.luau:18].

## 3. 켜는 순서

1. **연습 Studio에서만 먼저 켠다.** `UiSandbox`나 `WorldKit` 복사본을 쓴다. 메인 Studio는 메인 반영 1 소유이고, 장소 설정 변경은 AGENTS 6번상 메인 반영 1의 권한 밖이므로 검수와 사용자 OK를 거친다.
2. **설정값은 아래 순서로 시도한다 (속성 이름·값은 Roblox 문서로 확인 필요 [추정]).**
   - 1차: `StreamingEnabled = true`, `StreamingMinRadius = 160`, `StreamingTargetRadius = 512`, `StreamOutBehavior = Default`, `StreamingIntegrityMode = Default`. 이유: 스토리 NPC "!" 90스터드(StoryNpcs.luau:27), 폭포 소리 40스터드(Config.luau:5575), 몬스터 공격 사거리 30 안팎을 모두 덮는다.
   - 2차: MinRadius 128 → 200, TargetRadius 768 → 1024 (기본값)로 바꿔 가며 팝인 거리와 메모리를 비교한다.
   - 3차: `StreamOutBehavior = LowMemory`와 `Opportunistic`을 폰 에뮬레이터에서만 비교한다.
   - 4차: `StreamingIntegrityMode`를 `MinimumRadiusPause`와 `PauseOutsideLoadedArea`로 바꿔 본다. 안 불러온 땅 위에서 캐릭터가 멈추는지 확인한다.
3. **main에 반영하기 전에 끝나야 할 T행** (첫 10분 흐름에 걸리는 것):
   - A표: T-1 (인트로), T-2 (대장간 안내), T-3/T-4 (퀘스트 목표·안내선), T-5 (패드·문), T-8 (스토리 NPC), T-9 (서버 `PivotTo`와 `RequestStreamAroundAsync`).
   - B표: T-12, T-14, T-15, T-16, T-17, T-23. T-14는 서버 작업(게임성 개발 2)이 필요하다.
   - 나머지(T-6, T-7, T-10, T-11, T-13, T-18~T-22, T-24~T-27)는 켠 뒤 고쳐도 된다. 단, T-6/T-7은 A표의 심각도를 기준으로 다시 판단한다.
4. **측정할 것**
   - 접속부터 캐릭터가 움직일 수 있을 때까지 시간 (스트리밍 on/off 비교).
   - 스폰 후 5초·20초에 보이는 건물·바닥 (팝인 거리), 로딩 화면이 걷히는 시점.
   - 클라이언트 메모리와 인스턴스 수 (F9 개발자 콘솔 Memory, `Stats`), 폰 에뮬레이터 FPS.
   - `warn`/`[tag]` 로그 수. 대부분 모듈이 `pcall`로 감싸져 있어 조용히 실패하므로 로그를 일부러 센다.
   - T-23: `workspace.AudioAmbient` 안 `WaterfallSound` 개수 (겹침 확인).
   - T-12: 접속 직후 M을 열었을 때 마을 패드 아이콘이 있는지.
   - 구역 이동 (교차로→마을, 교차로→초원): 도착 직후 땅이 있는지, 안내선이 끊기지 않는지, 이펙트가 땅에서 뜨지 않는지 (T-21).
   - 느린 네트워크: Studio의 Incoming Replication Lag을 올려서 같은 시나리오를 다시 한다.

**확인한 것 / 추정한 것 요약**
- 확인: 위 표의 코드 줄 인용, 28개 `PreloadArt`, Audio 사전 로드 구조 (개수 118은 요청문 수치를 코드 구조로 뒷받침함), 몬스터가 코드 도형인 점, 여러 모듈의 Config 대체 좌표 유무.
- 추정: 스트리밍이 켜졌을 때의 실제 동작 (부분 스트리밍 모델, 팝인, 새 인스턴스 재생성), Roblox 속성 이름·값·기본값, `RequestStreamAroundAsync` 호출 위치, 에셋 개수(3D·UIArt 전체), 사운드 단계 분류의 세부 이름.
