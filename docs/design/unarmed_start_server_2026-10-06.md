# A23-34 맨손 시작 — 서버 계약 (게임성 개발 2, 2026-10-06)

사용자 결정 A23-34: 새 플레이어는 무기 없이(맨손), 전투력 0으로 시작한다. ~~첫 무기는 메인 M1_1(대장장이 방문)에서 무료로 받는다.~~ → 첫 무기는 첫 임무를 받은 뒤 걸어서 간 대장간 단계(`QuestService.ForgeGift`, 사냥 전)에서 무료로 받고, M1_1 `GiveWeapon`은 안전망이다(A23-74·A23-88). 검수 추가: 맨손이어도 나무 무기(T2) 구매가 되고, 무료 T1과 순서가 꼬이지 않는다(둘 다 OK). 오프라인 검사: `py tools/test_unarmed_start.py` (224검사, 변이 72/72). 자체 검토(찾기 3 + 반박 12) + 검수 3건 반영.

## 1. 저장
- `Config.Data.Defaults`: `WeaponTier = 0`, `WeaponOwnedMask = 0` (0 = 맨손, 가진 무기 없음). Version은 3 그대로.
- DataService `migrate`의 v1/v2 단계: A23-34 이전 세이브는 늘 T1을 가졌으므로(A23-4) 거기서 T1 비트를 넣는다(장착 단계가 없거나 깨졌으면 T1).
- `fillDefaults`: 0을 정상 값으로 받고 어떤 비트도 강제로 켜지 않는다. 깨진 마스크 → 0(+ 장착 단계 비트), 깨진 단계 → `Config.BestUsableWeapon(마스크, 레벨)`(쓸 수 있는 게 없으면 0).
- 버전을 올리지 않은 이유: v3 세이브는 옛 서버가 매번 T1 비트를 써서 저장했으므로 새 서버가 그대로 읽으면 된다. 옛 서버가 새 맨손 세이브를 읽으면 T1을 미리 주는 것뿐(손해 없음), 반면 버전을 올리면 옛 서버(동기화 전 Studio 등)가 세이브를 거부해 킥한다.

## 2. 숫자
- `Config.Combat.Unarmed = { Damage = 4, Range = 7, Interval = 0.8, AimCone = ~~75~~ 90 }`(A23-61 앞쪽 반원, + `PvPRatioMin` 0.4). 주먹 한 대 = 2(슬라임 HP 10 → 5대, 약 3.7초), 모든 직업·진영 같다(직업 배수 없음, 마법사 MP 없음, 가장 가까운 앞쪽 1마리). Range 7 > 몬스터 공격 거리 5.5.
- `Config.WeaponDamage(0, …)` = Unarmed.Damage × 레벨 배수(+N 없음). `Config.SwingHitsToKill(0, …)` = 5(슬라임).
- `Config.CombatPower`: 맨손일 때만 Lv1 주먹 값을 빼서 0부터 센다(Lv1 0, Lv2 12, Lv3 23). 무기가 있으면 숫자가 전과 똑같다(Lv1 T1 283, Lv2 T1 300) → 깡패·대담함 비율(BB4)이 그대로. 0을 나누는 곳 없음(BoldMult는 내 전투력 0이면 ×1).
- `Config.BestUsableWeapon`: 쓸 수 있는 무기가 없으면 0. `Config.WeaponName(0)` = `Config.Text.BareHands`(~~"맨손"/~~"Bare hands", 영어만 A23-48), `Config.WeaponArtKey(0)` = nil.
- 스킬 Q(Lv5에 배움, A23-71)는 맨손이어도 직업 스킬: 직업 사거리·직업 배수(전사 24, 마법사 31, 궁수 13 → 슬라임 한 방).
- PvP(검수): 맨손 공격자의 무기 비율 바닥은 `Config.Combat.Unarmed.PvPRatioMin` 0.4(무기는 `Config.PvP.PowerRatioMin` 0.8). 같은 레벨이면 어떤 상대(맨손~T8)에게도 맨손 주먹의 초당 PvP 피해가 세 직업 T1 평타보다 작고, 맨손 Q도 같은 직업 T1 Q보다 작다(검사: Lv1·15·30 × 상대 T0~T8 × 세 직업 72칸).

## 3. `Config.AttackProfile(classId, tier, factionId)` (서버·클라이언트 공용)
- 무기 있음 → `Config.Classes[classId]` 그 자체. 맨손 → 캐시된 표 `{ Id, Style = "Punch", Unarmed = true, Pattern = "Multi", Targets = 1, Splash = 0, Range = 7, SwingInterval = 0.8, AimCone = ~~75~~ 90(Unarmed.AimCone), Damage = 1, Ranged = false, PvPMult = 1 }`.
- CombatService.Swing·자동 전투가 이것으로 평타 모양(사거리·간격·대상·MP)을 정한다. factionId는 A23-39(펫 조련사)용으로 미리 받는다.

## 4. 첫 무기 (M1_1)
> 2026-10-09 검수: 지금 첫 무기는 대장간 단계(`QuestService.ForgeGift`, 사냥 전)에서 같은 `GrantFirstWeapon`으로 줌(A23-74·A23-88); M1_1 `GiveWeapon`은 안전망. 첫 임무 [Claim]은 이제 늘 `BlacksmithVisited`를 false로 되돌림. 알림 글은 영어만(A23-48).
- `Config.StoryQuests.Defs.M1_1.GiveWeapon = 1` → StoryQuestService `complete`가 이야기 줄 다음에 `LootService.GrantFirstWeapon(player, 1)`.
- GrantFirstWeapon: T1을 이미 가지면 아무것도 안 함(옛 세이브·두 번째 호출). 아니면 T1 소유 → 맨손이면 바로 장착 + "첫 무기 [나뭇가지]를 받았어요! 전투력 12 → 300"(실제 이전 값) + Fx `Upgrade {Tier=1}`, 이미 무기를 들고 있으면(T2를 먼저 산 경우) 가방에만 + "대장장이가 [나뭇가지]도 챙겨 줬어요…".
- 대장간 모루 ~~E~~ → G(상호작용 키, A23-78)(onBlacksmithPrompt)는 `StoryQuestService.Refresh`를 먼저 불러, 상점 창이 열릴 때 무기가 이미 손에 있다.
- 첫 임무 받기(QuestService.claimTutorial)는 (T1이 없을 때만) `BlacksmithVisited`를 false로 되돌린다: 첫 임무 전에 모루를 눌렀어도 M1_1은 '젤리를 들고' 대장간에 다시 가야 끝난다(받기 알림 '교차로 대장간에서 첫 무기를 받아요'와 같게). 이 부분은 QuestService(게임성 개발 1 파일)라 병합 때 알림. T1을 이미 가진 세이브(A23-34 전)는 방문을 그대로 두고 '첫 무기' 약속 없는 문구(`ClaimedArmed`·`AutoClaimedArmed`·`VisitBlacksmithArmed`, KO/EN)를 받는다(검수). M1_1 단계 글은 원래대로 '대장장이에게 젤리 보이기'.
- 접속 순간(StoryQuestService의 PlayerReady가 LootService보다 먼저) 받은 첫 무기도 '얻은 순'에 한 번만 적힌다(감시가 아직 없을 때만 직접 기록).
- 접속 때 안전망: `Story.Done.M1_1`인데 T1이 없으면 그때 준다.
- 맨손일 때 얻은 무기(대박 T8 등)는 레벨이 되면 바로 장착 + "[이름] 장착! 전투력 X → Y"(대박이면 한 줄 "전설 무기 [이름] 장착! 전투력 X → Y", '메뉴에서 장착해요' 줄은 안 보냄). 맨손 첫 왕 슬라임 주문서 안내는 FirstScrollBare("첫 무기는 대장장이가 줘요…").
- 환생·Lv5+ 무료 직업 변경으로 레벨이 내려가 가진 무기를 하나도 못 쓰게 되면(예: M1_1 전에 철 무기만 산 경우) 맨손으로 돌아가지 않고 무료 T1을 주고 장착한다(A23-34 '맨손으로 돌아가지 않는다'). 그 뒤 M1_1은 조용히 끝난다.

## 5. 대장간 (ShopService)
- 맨손(단계 0·마스크 0, 또는 T1 없는 마스크)도 T2·T3 구매·판매 가능. T1은 팔지 않음 → `Config.Text.WeaponFromQuest` 안내.
- 장착 중인 무기를 팔면 `BestUsableWeapon(남은 마스크, 레벨)`(없으면 맨손). 예전처럼 갖지 않은 T1을 주지 않는다.

## 6. 게임성 개발 1에게: 클라이언트 계약
1. `WeaponTier`·`WeaponOwnedMask` 속성은 0일 수 있다(기본값도 0으로 읽기). 고칠 곳: HUD.luau 607(전투력 계산 clamp 0..Max), Panels.luau 1763~1767(대장간: tier 0·mask 0 허용, `Owns(mask, 1)` 검사 빼기), 2180(아이템 목록: mask를 1로 바꾸지 않기, 맨손이면 '맨손' 표시), 2543(T1을 안 가졌으면 구매 버튼 없이 "첫 임무 뒤 대장장이가 줘요"), 텍스트 166/167/170('시작 무기' → '첫 무기', 장착 무기를 팔면 '다른 무기(없으면 맨손)로'), ClassPicker.luau 107/1064('시작 무기: %s' → 예: '첫 무기: %s (대장장이가 줘요)').
2. HUD 2120: `Config.WeaponArtKey(0)`가 nil → 지금처럼 대체 아이콘(UIKit.ArtId(nil)은 안전).
3. Fx `Swing` 패킷에 `Style` 추가: 맨손이면 `"Punch"`(무기 있으면 nil). `Class`는 진짜 직업 그대로. Punch일 때 `From` = 오른손 위치, `ContactDelay` = 0.15, `LaunchDelay`·`FlightTime` = nil, `Radius` = 0, `Targets` = 맞은 대상 1개 또는 헛치면 앞 7스터드 한 점, `Hits` 형식 같음. 클라이언트: 투사체·베기 없이 오른손 잽(R15 절차 클립, 약 0.45초), 접촉 때 숫자·멈춤, 무기 자세(weaponMotion/archerPose/staffPose)는 건너뛰기, 타이밍은 `Config.AttackProfile(...).SwingInterval`(0.8).
4. HUD 자동 방향 돌리기(FaceTarget): 평타는 `Config.AttackProfile(class, WeaponTier, faction).Range/AimCone`(맨손 7/~~75~~ 90), 스킬 Q는 직업 값 그대로.
5. 새 원격 없음. 알림 문구는 서버가 보낸다(FirstWeapon·FirstWeaponBag·BareEquip, ~~KO/EN 표~~ 영어만 A23-48).
6. A23-39 예약: 장인 궁수(펫 조련사)는 `Style = "PetHeadbutt"`(맨손이면 주먹 수치 + 펫 박치기 연출).
7. Studio 사냥 봇 `tools/fixtures/hunt_bot_client.luau`는 직업 사거리·간격을 쓴다 → 맨손 신규 플레이어 측정 때는 AttackProfile 값으로.

## 7. 알려진 것
- `tools/gameplay_blacksmith_check.py`는 main에서 A23-28 뒤로 실패하던 검사(레벨 미달 무기 재장착을 '무료로 된다'고 기대)를 A23-28 규칙(EquipNeedLevel 거절)으로 고쳐 이제 통과한다(1483). A23-34 몫: 기본 0/0, 맨손·T1 없는 마스크 구매 허용, 음수 단계 거절, 범위 밖 마스크는 258(T2 비트 포함)로 사고·팔기 두 검사 모두 확인.
- `tools/test_costume_physics.py`는 은퇴(A23-5).
