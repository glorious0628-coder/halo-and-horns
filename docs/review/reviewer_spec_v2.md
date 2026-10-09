[검수 2차] TECH_SPEC v2 교차검수 결과 — HIGH 5건 / MED 27건 / LOW 19건

> 기록용(2026-10-09 검수): 2026-10-02 TECH_SPEC v2 교차검수 기록이다. 충전·발사·자동 공격·장인 진영 같은 옛 규칙이 들어 있고, 지금 기준은 SPEC_ADDENDUM A23(번호가 클수록 새것)이다.

## HIGH

**[H1] 활성 괴수가 진영 마을(특히 자기 HornsTown)에 들어가면 무적이 되고 생존이 확정됨** (G1·G3·G4·G8)
근거: SPEC_ADDENDUM.md:57-59, 123-124 / TECH_SPEC.md:401, 643-645, 779-781, 1659, 1821-1822, 1954-1956, 2065, 2076-2087, 2205, 2891 / GDD.md:134, 157
문제/실패: A3-L1은 HornsTown에 들어온 Halo만 튕기고, 괴수가 자기 마을에 들어가는 것은 막지 않는다. 별 5 괴수가 HornsTown 중앙으로 가면 쫓던 Halo는 튕겨 나가고, 경계에서는 사거리 35/30으로 닿지 않는다. 이 상태에서 마을 재생 10%/s가 MaxHealth ×20에 붙고 마을 BankAll도 돈다. 그래서 120초 뒤 Survived(금고 ×1.5, 칭호, Horns +150)가 매번 확정된다.
수정:
- G3 ZoneService 존 루프: 존이 바뀌었는지와 관계없이 매 틱, 레벨 게이트 바로 뒤에서 검사한다. `kstate(p) == "Active"`이고 현재 존이 HaloTown 또는 HornsTown이면 `character:PivotTo(GetSpawnCFrame("Crossroads"))`를 하고 notify `KaijuNoTown`("bad", 3초에 1회)을 보낸다.
- Crossroads는 계속 들어갈 수 있다. Halo가 따라 들어올 수 있고 CanAttack 괴수 예외도 그대로라서 2891 규칙이 유지된다. A3-L1은 바꾸지 않는다.
- G4 CombatService 재생: `kstate(p) == "Active"`이면 `pct = 0`.
- G8 ProgressionService 1초 루프: `kstate(p)`가 "Siren" 또는 "Active"이면 마을 BankAll을 건너뛴다.
- G1: `Config.Text.KaijuNoTown = "괴수는 진영 마을에 들어갈 수 없어요!"`를 추가한다.
- 공개 API는 바뀌지 않는다.

**[H2] 기사단 발사의 '동료 +10 스택'이 무한히 순환함** (G1·G4)
근거: TECH_SPEC.md:411, 419-421, 993, 1792, 1799, 1801-1803, 2864 / SPEC_ADDENDUM.md:63, 169-171
문제/실패: MinRelease와 HaloAllyStacks가 둘 다 10이고, 1801-1803은 맞힌 대상이 0이어도 +10을 준다. 따라서 Halo 2명이 9칸 안에서 Q를 번갈아 누르면 10스택이 영원히 오간다. 3명이면 약 2초 만에 캡 150에 닿아 PERFECT를 연발하고, PvP는 1초 안에 처치되며 괴수도 즉사한다.
수정:
- G1: `Config.Charge.HaloAllyStackCooldown = 5`를 추가한다.
- G4 Release 6단계: 동료 스택은 `total > 0`일 때만 준다. 받는 동료 `a`마다 `os.clock() - (lastAllyStackAt[a] or -math.huge) >= HaloAllyStackCooldown`일 때만 `addCharge(a, HaloAllyStacks)`를 실행하고 시각을 기록한다. 기록은 PlayerLeaving 때 지운다.
- 치유 식은 그대로 둔다.

**[H3] SwitchFaction에 목표 진영 인자가 없어 3진영(A6) 제단 변경이 성립하지 않음** (G1·G6·G12)
근거: TECH_SPEC.md:1106-1107, 1864-1874, 2509-2514, 2567 / SPEC_ADDENDUM.md:25-28, 107-108, 127-129, 161-164
문제/실패: 페이로드는 `useTicket` 하나이고 서버는 `new = other`로 목표를 정한다. G12가 `("Neutral", false)`를 보내면 1864의 boolean 검사에서 조용히 무시되어 제단 전체가 먹통이 된다. boolean만 보내면 장인 길드로 갈 방법이 없고, 중립 플레이어의 'other'는 정의되지 않는다. 또 손실이 0인데도 `useTicket=true`면 79R$ 변경권이 그냥 소모된다.
수정:
- 시그니처: `SwitchFaction(useTicket: boolean, targetFaction: string?)`. 첫 인자를 유지하므로 A2와 호환된다. §4.10과 §5(2567)를 갱신한다.
- G6 검사 순서:
  1. ready → `type(useTicket)=="boolean"`이고 (`targetFaction==nil` 또는 string)
  2. rate limit → faction ~= "None"
  3. 목표 결정: nil이면 Halo↔Horns로 하고, 현재가 Neutral이면 조용히 무시한다. 값이 있으면 {Halo, Horns, Neutral} 중 하나이고 현재 진영과 달라야 하며, 아니면 조용히 무시한다.
  4. 제단 거리 → 기존 차단(자루·괴수·별·전투·쿨다운)
  5. 무료 경로에 손실이 없으면 `useTicket=false`로 강제한다. 손실 없음 = Neutral에서 떠남, Honor 0으로 Halo에서 떠남, Infamy 0으로 Horns에서 떠남.
  6. useTicket일 때만 `UseTicket` → 성공 처리
- 무료 변경 손실: Halo에서 떠나면 Honor=0, Horns에서 떠나면 Infamy=0, Neutral에서 떠나면 손실 없음.
- 알림: `SwitchDoneFree` / `SwitchDoneTicket` / 손실 0이면 `SwitchDoneNoLoss`. G1이 `SwitchDoneNoLoss = "%s(으)로 진영을 바꿨어요!"`를 추가한다. 이후 `SetFaction(p, target, "Altar")`와 Respawn을 한다.
- G12 Altar 패널: 현재 진영을 뺀 목표 카드 2장(목표 진영의 Perks·FactionLore)을 보여 준다. 다음으로 A7-4의 [무료]/[티켓]을 보여 주되, 손실이 0이면 티켓·구매 버튼을 숨기고 "잃는 것 없음"을 표시한다. 전송은 항상 `SwitchFaction:FireServer(useTicket, targetId)`.

**[H4] ChooseFaction 검증이 Halo/Horns만 허용해 장인 길드를 고른 신규 유저가 피커에 갇힘** (G6·G12)
근거: TECH_SPEC.md:43, 1850, 1856, 1860-1863, 2534-2538, 2544, 2560, 2608, 2827 / SPEC_ADDENDUM.md:27-28, 107, 114, 125-126
문제/실패: §4.10과 §5의 검증 집합과 Faction 타입이 2진영 그대로다. 장인 길드 카드를 누르면 `ChooseFaction("Neutral")`이 조용히 거부되고 Faction이 "None"으로 남는다. 피커가 닫히지 않은 채 버튼이 2초마다 다시 켜지고, ClassPicker와 튜토리얼이 시작되지 않는다.
수정:
- 1860과 2560의 검증을 `factionId ∈ {"Halo","Horns","Neutral"}`로 바꾼다.
- 1850, §6.1(2608), §6.2의 Faction 타입에 "Neutral"을 넣는다. Team은 3개로 만들고 색은 A9-1을 따른다.
- wasWeaker 로직은 그대로 둔다. GetWeakerFaction이 Neutral을 돌려주지 않으므로 +300은 자동으로 Halo/Horns 전용이 된다.
- GetCounts는 (halo, horns)를 유지한다.
- FactionPicker는 `Config.PlayableFactions`(M2) 순서로 카드 3장을 보여 주고, 폰에서 카드 폭은 화면의 30% 이하로 한다.

**[H5] 누르고 있는 수동 공격이 쿨다운 경합과 지터로 대부분 버려짐(자동 ON 상태에서 PvP 반격 불가)** (G4)
근거: SPEC_ADDENDUM.md:39-41, 53-54 / TECH_SPEC.md:348, 363, 402, 993, 1757-1759, 1763-1764, 1810, 1816-1818, 2421, 2562
문제/실패: HUD는 정확히 SwingInterval마다 요청을 보내고, 서버는 nextSwingAt 전에 도착한 요청을 조용히 버린다. A3-H3의 1.0초 창은 마법사 간격 1.25초보다 짧다. 그래서 0.1초 틱 자동 루프가 쿨다운을 먼저 쓰고, 이후 수동 요청은 계속 조금씩 일찍 도착해 버려진다. 결과적으로 사람에게 주는 피해는 0, 충전은 +1만 쌓인다.
수정(G4 내부만, 계약·HUD는 그대로):
- (1) Swing 리모트 핸들러에서 ready와 rate limit을 통과하면, 쿨다운 검사 전에 `lastManualAt[p]=os.clock()`를 기록한다.
- (2) 자동 루프 건너뛰기 조건을 `os.clock()-(lastManualAt[p] or -math.huge) < c.SwingInterval + 0.3`으로 바꾼다. A3-H3의 1.0초 창을 대체한다.
- (3) 수동 스윙만 `if now < nextSwingAt - 0.15 then return end; nextSwingAt = math.max(now, nextSwingAt) + c.SwingInterval`. 자동 스윙은 기존 `now >= nextSwingAt` 그대로.

## MED

**[M1] 환생 목표에 Neutral이 허용되지 않고, 보너스 식이 Neutral 출발·목표를 처리하지 못함** (G8·G12)
근거: TECH_SPEC.md:741-743, 762-767, 1852, 2213-2226, 2503-2508, 2566 / SPEC_ADDENDUM.md:60-62, 107-108, 119-120, 126-129 / GDD.md:246, 265
문제/실패: `Rebirth("Neutral")`은 (false, nil)을 돌려받아 아무 반응이 없다. 허용만 하면 Halo 6명·Horns 2명인 서버에서 horns 인원이 계산에 쓰여 영구 +40%가 붙는다(정답은 +25%). 중립 출발이면 '현재 진영 −1'이 horns를 잘못 깎는다.
수정:
- 목표는 {Halo, Horns, Neutral}이다.
- 2단계: `halo,horns=GetCounts()`; `if old=="Halo" then halo=math.max(0,halo-1) elseif old=="Horns" then horns=math.max(0,horns-1) end`; `bonus = factionId=="Neutral" and Config.Rebirth.BonusNormal or Config.RebirthBonusFor(factionId=="Halo" and halo or horns, halo+horns)`.
- 표식은 Halo↔Horns에만 준다. 환생은 Honor/Infamy를 바꾸지 않는다(A3-L2). A6:128의 무료/티켓 규칙은 제단에만 적용된다.
- 환생 패널은 버튼 3개로 한다. 장인 길드 버튼은 "+25%" 고정이고 표식 미리보기를 보여 주지 않는다.

**[M2] A6 중립 Config 명세가 불완전해 그대로 복사하는 G1과 소비 측 키가 어긋남** (G1·G12)
근거: TECH_SPEC.md:148, 202-212, 342-393, 435-497, 1020-1023, 2509, 2536, 2545-2546 / SPEC_ADDENDUM.md:110-115, 125, 157-160, 183-185
문제/실패: A6에는 "same shape"만 있고 Perks/Pitch/RegenPerSec 값, 스토리 줄 키, Names.Neutral이 없다. PickLine은 누가 추가할지 정해져 있지 않다. 그래서 피커가 nil을 TextLabel.Text에 넣다가 카드 생성이 중단되거나, 직업명이 "전사"로 표시된다.
수정:
- G1이 다음 블록을 그대로 추가한다: `Config.Factions.Neutral = { Id="Neutral", Name="장인 길드", Short="장인", Emblem="⚙", TeamName="장인 길드", TeamColor=BrickColor.new(Color3.fromRGB(40,200,190)), Color=Color3.fromRGB(40,200,190), XPBonus=0, GoldBonus=0, DamageBonus=0, MaxHPMult=1.0, RegenPerSec=0.01, Lifesteal=0, LifestealCapPct=0, AutoBankInterval=0, AutoBankFraction=0, PartyAuraPerAlly=0, PartyAuraMaxAllies=0, PartyAuraRadius=0, CanBeWanted=false, ChargeCap=150, ReleaseSupport=false, Perks={"싸움 버프 없음","PvP 없음: 누구도 때리거나 맞지 않아요","제작 특화 (곧 추가)"}, Pitch="싸움 버프 없음 · PvP 없음 · 제작 특화(곧 추가)" }`
- 함께 추가할 키:
  - `Config.Story.FactionLore.Neutral = "조각을 줍지 않고, 다듬기로 한 자들."`
  - `Config.Classes.Warrior/Mage/Archer.Names.Neutral = "대장장이"/"연금술사"/"사냥꾼"`
  - `Config.Classes.*.PickLine` (A7-4 값)
  - `Config.PlayableFactions = {"Halo","Horns","Neutral"}`
- FactionOrder는 {Halo, Horns}로 그대로 둔다.
- G12는 새 키를 `or ""`로 읽는다.

**[M3] TutorialStep이 Defaults/Mirrored에 없고 '신규' 판정 기준이 모호함** (G1·G2·G8·G10)
근거: TECH_SPEC.md:148, 241-279, 1509-1532, 1551, 1574, 2598-2633, 2844 / SPEC_ADDENDUM.md:50, 67-68, 73-75, 93-96, 136, 153
문제/실패: SetStat은 Mirrored에 있는 키만 속성으로 쓴다. 그래서 HUD 1단계 빔이 뜨지 않고, Studio 메모리 모드에서는 값이 nil이라 튜토리얼이 시작되지 않는다. 첫 저장에 실패하면 저장소에 `{SessionLock}`만 남아, 다음 접속 때 기존 계정으로 판정되어 99가 된다.
수정:
- G1: `Defaults.TutorialStep = 0`, Mirrored에 "TutorialStep"을 추가한다.
- G2 Load transform: `isNew = old==nil or SessionLock 외 키 없음`.
  - isNew면 0으로 두고 migrate와 로그를 생략한다.
  - 아니면 기본값을 채우기 전에, 필드가 없을 때 99로 한다.
  - 메모리 모드는 신규(0)로 본다.
- G8은 SetStat으로만 쓰고, G10은 `UIKit.Attr("TutorialStep", 99)`로 읽는다.
- §6.1에 행을 추가한다.

**[M4] 튜토리얼 0단계를 시작할 신호가 없음** (G5·G8)
근거: SPEC_ADDENDUM.md:69-72, 91-94, 206 / TECH_SPEC.md:1573-1584, 1697, 1860-1863, 1882, 1888-1892, 2265, 2825-2828
문제/실패: ChooseClass는 리스폰을 일으키지 않는다. C4를 문자 그대로 구현하면 진영 선택 전에 교차로에 슬라임이 생긴다. 이후 섬 마을로 리스폰돼도 이미 슬라임이 있어 다시 만들지 않으므로 120초 타임아웃으로 0단계가 사라진다. 반대로 'ClassChosen 스폰'에서만 시작하면 첫 사망 전까지 시작되지 않는다.
수정:
- G8: `ClassService.ClassChanged`를 구독한다. ClassChosen, Faction≠"None", TutorialStep==0이고 살아 있는 개인 슬라임이 없으면 `task.defer`로 루트 앞 8칸에 SpawnPersonal을 한다.
- CharacterSpawned에서의 C4 재시작은 Faction≠"None"이고 ClassChosen일 때만 한다. 기존 개인 슬라임이 30칸보다 멀면 제거하고 앞에 다시 만든다.
- G5 opts: 외형과 보상 배수는 황금 그대로, MaxHP=opts.HP(황금 배수 적용 뒤에 덮어씀), WarPoints=0, 퀘스트 진행은 인정한다.

**[M5] 세션 속성의 초기값·리셋 담당이 없어 nil 비교 오류, 직업 변경 잠김, 지난 라운드 WarPoints 표시가 생김** (G3·G5·G7·G9·G10·G11·G12)
근거: TECH_SPEC.md:1962-1969, 1986-1987, 2036-2037, 2053, 2068, 2126, 2135-2136, 2152-2154, 2167-2168, 2320-2325, 2340-2344, 2398, 2412, 2470-2484, 2517-2518, 2664, 2822-2824
문제/실패: Panels의 `KaijuState ~= "None"`은 nil일 때 참이 되어, 괴수가 된 적 없는 모든 플레이어의 직업 변경이 잠긴다. EventHUD에서 다른 플레이어의 `SackGold > 0`을 비교하면 매 프레임 오류가 난다. 라운드가 끝난 뒤에도 HUD의 WarPoints는 이전 값을 보여 준다.
수정:
- 각 서비스가 PlayerReady에서 기록한다.
  - G7 Grudge: SackGold=0, SackSeconds=0, SackVictimName=""
  - G7 PvP: WantedStars=0, Bounty=0, Rookie=IsRookie(p), Protected=false, RevengeTargetId=0, RevengeUntil=0
  - G9 Kaiju: KaijuState="None", SessionTitle=""
  - G9 Goose: GooseCount=0
- G3 WarService: personal을 0으로 만드는 모든 곳(PlayerReady, FactionChanged, 라운드 종료 시 모든 ready 플레이어)에서 WarPoints 속성도 0으로 쓴다.
- §7.3 목록에 Grudge/Kaiju/Goose를 추가한다.
- 클라이언트와 CharacterVisuals: 다른 플레이어 속성은 `(p:GetAttribute(k) or 기본값)`, 자기 속성은 `UIKit.Attr(k, 기본값)`으로 읽는다.

**[M6] MonsterKilled가 기여자마다 WarPoints를 실어 보내 진영 풀이 인원수만큼 불어남** (G3·G5)
근거: TECH_SPEC.md:446, 662-663, 855, 1670-1673, 1711-1712, 2151, 2154, 2158 / GDD.md:164-165
문제/실패: 같은 진영 4명이 몬스터 하나를 함께 잡으면 처치 1회에 4점(황금 몬스터는 20점)이 들어간다. 처치 수가 같아도 뭉쳐 다니는 진영의 1인당 점수가 4배가 되어 왕관전과 축복을 독차지한다.
수정:
- G5: 기여자마다 info를 복제하고 `info.WarShare = WarPoints / (보상받는 기여자 중 같은 진영 수)`를 넣는다.
- G3: 진영 풀에는 `info.WarShare or info.WarPoints`, 개인 점수에는 `info.WarPoints`를 더한다. 그래야 상자 기준 30점이 유지된다.

**[M7] 전쟁 1인당 점수의 분모가 종료 순간 인원이라 승패가 뒤집힘** (G3)
근거: TECH_SPEC.md:1852, 1877-1878, 2145, 2151-2168 / SPEC_ADDENDUM.md:119-120, 127-128
문제/실패: 뿔 5명 700점 대 기사 5명 750점에서, 종료 10초 전에 뿔 4명이 나가면 700/1 대 150이 되어 뿔이 이긴다. 재접속한 사람도 축복을 받는다. 악명 0인 뿔 1명이 중립으로 무료 전환해도 결과가 뒤집힌다.
수정:
- Tick마다 `presence[f] += count`, `ticks += 1`을 누적한다.
- 1인당 점수 = `points[f] / math.max(1, presence[f]/math.max(1,ticks))`. 표시와 종료 판정에 같은 식을 쓴다.
- Siege/Idle 판정은 평균 인원 0.5 미만을 0명으로 본다.
- 라운드를 리셋할 때 presence와 ticks도 초기화한다.

**[M8] 덩치 저울 합산에 잠수·새싹·부계정이 그대로 들어감** (G2·G6)
근거: TECH_SPEC.md:551-560, 1586-1589, 1746-1748, 1910, 1916-1923, 2065, 2125 / GDD.md:180
문제/실패: Lv70·무기 7 계정을 상대 진영 마을에 세워 두기만 해도 뿔 본계정의 S가 1.6이 된다. 그러면 PvE 피해, 거위 카운트, 괴수 HP가 모두 ×1.6이 된다.
수정:
- G2: 추가형 API `PlayerService.GetLastActive(player) -> number`를 더한다(lastActive의 os.clock, 없으면 0).
- G6 Recompute: 합과 인원에는 다음을 모두 만족하는 플레이어만 넣는다. 새싹이 아님, 120초 안에 활동함, 마을에 연속 60초 미만 머묾(ZoneChanged로 townSince 추적).
- 제외된 플레이어도 자기 진영의 S는 받는다.

**[M9] 황금 거위 진행 중 진영을 바꿔 승리 보상을 가로챔** (G9)
근거: TECH_SPEC.md:586, 684-689, 704-710, 816, 1864-1874, 2123-2138, 2152, 2224-2225 / SPEC_ADDENDUM.md:121, 127-128 / GDD.md:174
문제/실패: finish는 종료 시점의 진영으로 won을 판정한다. 악명 0인 뿔이 밀렵하다 종료 직전 7칸 떨어진 제단에서 무료로 Halo로 바꾸면, 패자 몫 40% 대신 승자 몫 100%를 받는다. 제단 쿨다운과 거위 주기가 둘 다 600초라 매번 반복할 수 있다.
수정: FactionChanged를 구독한다. 거위가 진행 중이면 PlayerLeaving(2138)과 똑같이 counts[p]를 제거하고(진영별 합계는 유지) GooseCount=0으로 한다.

**[M10] 괴수 담합 파밍으로 부계정 주머니가 통째로 옮겨지고 골드가 새로 생김(1:1 거래 금지 우회)** (G1·G7·G9)
근거: TECH_SPEC.md:599, 611, 618-624, 650-652, 1944, 1977-1984, 1993, 2006-2008, 2084-2093, 2205 / GDD.md:150, 158
문제/실패: 기사 부계정 3명이 B·C·D·B·C 순서로 죽어 주면 뿔 부계정이 별 5개가 된다. 이를 본계정 기사 혼자 처치하면 주머니 약 5.8만과 22,500(깡패면 45,000)이 약 5분마다 본계정 금고로 들어간다. 반대로 일부러 안 때리면 Survived ×1.5로 골드가 새로 생긴다.
수정:
- G9: 풀에 들어가는 주머니 몫 = `math.min(TakeCarriedGold(victim,all), PlunderCapPerLevel*Level)`. 초과분은 소멸한다.
- G1: `Config.Kaiju.PairRewardCooldown = 1800`을 추가한다. G9는 참가자–괴수 쌍마다 30분에 1회만 몫을 지급한다(그 외에는 0이지만 인원 계산에는 포함).
- Survived 금액 = `c + math.min(math.floor(c*(SurviveBankMult-1)), PlunderCapPerLevel*Level)`.
- G7 HandleKO 6단계: `addStar`는 pairOk일 때만 실행한다.

**[M11] 휴가 보너스(70%)가 '접속해서 일일을 일부만 한 날'보다 크고, 자정 자동 지급이 상자 집계에서 빠짐** (G8·G12)
근거: TECH_SPEC.md:912-938, 2257-2264, 2273-2278 / GDD.md:80, 238
문제/실패: Lv30 기준으로 결석한 날은 13,650을 받는데, 5분 접속해 일일 1개를 하면 7,800, 출석만 하면 0이다. 잠깐이라도 들어오면 손해다. 또 3개를 다 하고 마지막을 받지 않은 채 자정을 넘기면 자동 지급이 DailyClaims를 올리지 않아 상자를 잃는다.
수정:
- Day check 순서를 2→1→3으로 바꾼다.
- 2단계 자동 지급도 `DailyClaims += 1`을 하고, Slots에 도달하면 상자를 준다(티켓 확률 포함).
- 1단계: `if DailyDay > 0 then f = (math.min(DailyClaims,Slots)*QuestMinutes + (DailyClaims>=Slots and ChestMinutes or 0)) / (QuestMinutes*Slots + ChestMinutes); missed = (1-f) + math.max(0, today-DailyDay-1); days = math.min(VacationMaxDays, VacationDays + missed) end` (소수 일수 허용).
- 접속한 날의 총가치는 0.7V+0.3fV가 되어, 일일을 할수록 항상 이득이다.
- G12 패널은 `math.ceil(VacationDays)`로 표시한다.

**[M12] 깡패 판정 (b) 부활 15초와 (c) 3회 반복에 미끼 예외가 없음** (G7)
근거: TECH_SPEC.md:562-577, 618-624, 1746, 1825-1838, 1936-1940, 1977-1991, 2002-2009, 2081-2082, 2089, 2875-2877 / GDD.md:186-190
문제/실패: 먼저 공격하다 10분 안에 3번 죽어 주면 정당방위를 한 쪽이 깡패가 된다(공격 −15%, 현상금 ×2). 괴수에게 발구르기를 맞고 15초 안에 리셋하기를 3번 하면 괴수가 깡패가 되어 풀이 ×2가 된다.
수정:
- `baited`는 M13의 정의를 쓴다.
- `baited and (fresh or repeated)`이면 깡패 KO가 아니라 무보상 KO로 처리한다. `info={Kind="Defense", Bully=false, VictimStars=starsBefore, Stolen=0, Bounty=0, Rewarded=false}`이고 스택·별·약탈·명예/악명·현상금을 모두 생략한다. 복수 표식과 koLog 기록은 유지한다.
- 1938의 Kind 열거에 "Defense"를 추가한다.
- `kstate(killer) ~= "None"`이면 `bully=false`.

**[M13] 수동 공격이 사거리 안의 적 플레이어를 자동으로 포함해, 초보의 의도치 않은 1타로 약자 보호가 꺼짐** (G1·G7)
근거: TECH_SPEC.md:564, 1146-1149, 1756-1759, 1766-1777, 1965, 1980, 2421 / SPEC_ADDENDUM.md:53-54 / GDD.md:187, 277-278
문제/실패: Lv16 초보가 공격 버튼을 누르고 있을 때 Lv30 뿔이 10칸 안으로 걸어오면 자동으로 1타가 나간다. 그러면 1980의 미끼 예외가 켜져, 그 뒤 KO가 깡패 KO가 아닌 정상 약탈(20%와 별 +1)이 된다.
수정:
- G1: `Config.Bully.BaitMinPct = 0.2`를 추가한다.
- G7: PlayerDamaged가 올 때마다 `dmgLog[attacker][victim]`에 {시각, 양}을 쌓고, BaitWindow가 지난 항목은 버린다.
- `baited` = 피해자가 BaitWindow 안에 킬러에게 준 피해 합 ≥ `BaitMinPct * Config.MaxHealth(kLevel,kFaction,kClass)`.
- 1980과 M12 모두 이 `baited`를 쓴다.

**[M14] 깡패 단계와 현상수배 별이 세션 전용이라 재접속하면 벌칙이 풀림** (G1·G6·G7)
근거: TECH_SPEC.md:571, 605, 613, 1930-1933, 1966-1969, 2014-2015, 2211-2212, 2632-2633
문제/실패: 깡패 3단계(공격 ×0.55, 해제까지 15분)인 플레이어가 마을에서 15초 기다렸다가 재접속하면 0단계·별 0으로 돌아온다. 그러면 현상금과 Hunt 대상도 사라진다.
수정:
- G1: Defaults에 `SavedBully=0, SavedBullyAt=0, SavedStars=0, SavedStarsAt=0`을 추가한다(Mirrored 아님).
- PlayerLeaving(p, data)에서 G6이 SavedBully*, G7이 SavedStars*를 data에 직접 기록한다(시각은 os.time).
- PlayerReady 복원: `깡패 = max(0, SavedBully - floor(경과/DecaySeconds))`, `별 = min(Config.Kaiju.StarsNeeded-1, max(0, SavedStars - floor(경과/StarDecaySeconds)))`.
- 2632의 세션 전용 목록에서 이 둘을 뺀다.

**[M15] 괴수·수배범이 로그아웃으로 도주하면 레이드·현상금 보상이 사라짐** (G7·G9)
근거: TECH_SPEC.md:602, 613, 1114-1117, 1842-1843, 2006, 2014-2015, 2089, 2102, 2211-2212, 2632
문제/실패: Active 괴수가 나가면 Cancelled 처리되어 풀, Halo +150, Hunt가 모두 없다. 괴수 본인은 25%만 잃으므로 지고 있을 때는 나가는 쪽이 항상 이득이다. 수배범도 마찬가지로 기사단의 현상금과 Hunt 진행을 지워 버린다.
수정:
- G9 PlayerLeaving: Active이고 피해 합이 0보다 크면 Defeated로 처리한다. 풀은 `BountyPoolMult*Config.Bounty(Level,stars,bully)`만 쓰고 주머니는 건드리지 않는다. 이어서 M17 규칙으로 분배하고, Halo +150과 `KaijuEnded(p,"Defeated",participants)`를 처리한다. finish 안의 캐릭터 접근은 pcall로 감싼다.
- G7 PlayerLeaving: stars ≥ 1이고 IsInCombat이고 `GetLastPvPAttacker(p)`가 Halo면, pair 쿨다운을 확인한 뒤 `Config.Bounty(Level,stars,bully)`를 그 공격자 금고에 지급하고 BountyGain을 알린다.

**[M16] 발사 PvP 상한이 '현재' MaxHealth의 35%라서 괴수 HP ×20과 근처 기사 보정이 의미 없음** (G1·G4)
근거: TECH_SPEC.md:418, 643-645, 1149, 1750, 1754, 1789, 1799, 1910, 2065 / GDD.md:137
문제/실패: 높은 스택에서는 HP 배수와 관계없이 꽉 찬 발사 3발이면 처치된다(L50 괴수 24,544, 1발 8,590). 149스택을 미리 모아 둔 기사 3명이면 120초 레이드가 1초에 끝난다.
수정:
- G1: `Config.Kaiju.ReleaseCapPct = 0.08`을 추가한다.
- G4 Release 5단계: `kstate(v)=="Active"`인 피해자에게만 상한을 ReleaseCapPct로 하고, 일반 플레이어는 35%를 유지한다.

**[M17] 괴수 보상 분배식의 totalDmg가 정의되지 않아 nil 산술 오류나 NaN이 금고에 저장됨** (G8·G9)
근거: TECH_SPEC.md:2084, 2088-2093, 2099-2101, 2182
문제/실패: 치유만 한 참가자는 `dmg[p]`가 nil이라 산술 오류가 나고, HandleKaijuDeath가 중단되어 finish가 실행되지 않는다. 피해를 준 사람이 모두 나간 뒤라면 0/0=NaN이 BankGold에 들어가 DataStore까지 퍼진다.
수정:
- G9:
  - `totalDmg = Σdmg[q]`. 이번 이벤트에 기록된 모든 Halo를 퇴장자까지 포함해 합산한다.
  - `dmgPart = totalDmg>0 and math.floor(pool*DamageShare*(dmg[p] or 0)/totalDmg) or 0`.
  - totalDmg가 0이면 pool 전체를 참가자 수로 균등 분배한다.
- G8: AddBankGold/AddCarriedGold/AddXP는 NaN이나 ±inf가 들어오면 무시하고 Util.Warn을 남긴다.

**[M18] 전향 환생으로 +40%를 받고 바로 제단에서 무료로 돌아감** (G1·G8)
근거: TECH_SPEC.md:258, 586, 741-743, 762-767, 1864-1874, 2218-2225, 2513, 2618
문제/실패: 환생은 LastSwitchTime을 갱신하지 않고, 환생 직후에는 떠나는 진영 점수가 0이다. 그래서 약한 편으로 환생해 +40%와 표식을 받은 뒤 즉시 원래 진영으로 돌아가는 것을 환생마다 반복할 수 있다.
수정:
- G1: `Config.Rebirth.StayLock = 1800`을 추가한다.
- G8 5단계: `factionId ~= old`이면 `SetStat(p,"LastSwitchTime", os.time()+StayLock-Config.Switch.Cooldown)`. 기존 제단 쿨다운 검사(1867)와 표시(2513)가 그대로 30분 잠금으로 작동한다.
- §6.1의 LastSwitchTime 작성자 목록을 갱신한다.

**[M19] 깡패 현상금 ×2 담합** (G7)
근거: TECH_SPEC.md:572, 611, 618-624, 1930-1931, 1981, 1983, 2002-2003, 2006
문제/실패: 기사 부계정이 뿔 본계정을 3~5번 KO해 스스로 깡패 3단계가 된다. 그 뒤 본계정이 5분 간격으로 부계정을 잡으면 회당 9,000, 10분에 18,000을 받는다. 이는 해골 유적 사냥 수입의 2.3배다.
수정:
- 깡패 현상금(2002, 2006에서 bullyBefore>0인 경우)은 `koLog[victim][killer]`에 RepeatWindow 안의 항목이 있으면 지급하지 않는다. 일반 약탈·명예 처리는 그대로 한다.
- 같은 깡패에 대한 깡패 현상금은 서버 전체에서 `Config.Bully.DecaySeconds`에 한 번만 준다(`lastBullyBounty[victim]`).

**[M20] 활성 괴수도 레벨업 때 체력이 꽉 참** (G8)
근거: TECH_SPEC.md:643, 1554, 2076-2078, 2202-2204, 2273-2277
문제/실패: 체력이 10% 남은 괴수가 미수령 일일 퀘스트를 받으면(XP 3,900, Lv25~32에서 레벨업 확정) 수만 HP가 즉시 가득 찬다.
수정: AddXP의 레벨업 처리를 `S.PlayerService.RefreshCharacter(p, S.KaijuService.GetState(p) ~= "Active")`로 바꾼다. Activate의 풀 회복은 그대로 둔다.

**[M21] ProcessReceipt 저장 실패 처리가 TECH_SPEC과 A7-4에서 정반대라, 결제 1회로 티켓을 2회 씀** (G2)
근거: TECH_SPEC.md:1535, 1868, 1896-1897, 2291-2295, 2298-2308 / SPEC_ADDENDUM.md:166-168
문제/실패: A7-4대로 롤백하면 다음이 일어난다. 저장이 1+2+4초 동안 기다리는 사이 플레이어가 새 티켓을 쓴다. 저장이 실패하면 롤백 −1은 0에서 막혀 회수되지 않고 PurchaseId만 지워진다. Roblox가 재시도하면 티켓이 다시 +1 된다.
수정: A7-4 문장을 §4.21로 대체한다.
- 신규 PurchaseId면 기록하고 +1한다.
- 신규든 이미 처리된 영수증이든 `Save(player,false)`가 true일 때만 PurchaseGranted를 돌려준다.
- 실패하면 지급과 PurchaseId를 메모리에 남긴 채 NotProcessedYet을 돌려준다. 롤백은 금지한다.
- 토스트는 신규일 때만 보낸다.

**[M22] DataService가 저장 순서를 보장하지 않아 Release 뒤 Save 재시도가 옛 사본과 잠금을 다시 쓰고, 같은 서버 재접속 때 옛 레코드를 읽음** (G2)
근거: TECH_SPEC.md:236-239, 1498-1501, 1510-1519, 1533-1536, 1555, 2306 / SPEC_ADDENDUM.md:32-34, 166-168
문제/실패: 실패한 오토세이브 재시도가 Release(잠금 nil) 뒤에 도착하면 퇴장 시점의 변경이 되돌아가고 잠금이 다시 걸린다. 그러면 다른 서버로 재접속할 때 약 12초 지연된다. 같은 서버로 재접속하면 이전 Release가 끝나기 전에 같은 JobId로 옛 레코드를 받아 롤백이 확정된다(약탈 직후라면 골드 복제).
수정:
- (1) 같은 UserId의 Load/Save/Release는 재시도를 포함해 UserId별 큐 하나에서 차례로 실행한다.
- (2) 저장 사본은 호출 시점이 아니라 실제로 실행될 때, 그리고 재시도마다 캐시에서 새로 뜬다.
- (3) Release는 첫 줄(yield 전)에서 `releasing[player]=true`로 둔다. release=false 저장은 releasing 상태이거나 캐시가 없으면 I/O 없이 false를 돌려준다.
- (4) release=false transform은 `old.SessionLock==nil`이거나 JobId가 다르면 nil을 돌려 쓰기를 취소한다.
- (5) 캐시 키는 Player 객체로 한다.

**[M23] FinalizeLeave가 PlayerRemoving과 BindToClose에서 동시에 불려 PlayerLeaving이 2번 발생하거나 셧다운 저장이 유실되고, 셧다운 때 전투 이탈 페널티가 적용됨** (G2·G8)
근거: TECH_SPEC.md:1543-1544, 1555, 1569-1571, 1852, 1917, 2050-2052, 2102, 2211-2212, 2300
문제/실패: ready를 마지막에 내리면 PlayerLeaving이 2번 발생해 자루 환불이 200%가 되고 페널티도 2번 적용된다. ready를 먼저 내리면 BindToClose가 진행 중인 저장을 기다리지 않는다. 또 업데이트로 서버가 닫히면 PvP 중이던 플레이어가 25%를 잃고, 자루 환불이 이미 복사된 피해자 데이터에 들어가지 않는다.
수정:
- G2: Player 키 `leaving[p]`와 완료 신호를 둔다.
- FinalizeLeave 첫 줄: 이미 leaving이면 완료될 때까지 기다린 뒤 return한다. 아니면 leaving=true → (ready였다면) PlayerLeaving:Fire 1회 → ready=false → Release → ClearPlayer → 완료 순으로 진행한다.
- 추가형 API `PlayerService.IsShuttingDown()`을 둔다.
- BindToClose:
  1. shuttingDown=true로 둔다.
  2. leaving이 아닌 ready 플레이어 전원에게 leaving=true와 PlayerLeaving:Fire를 동기로 모두 실행한다.
  3. 그다음 ready=false로 내린다.
  4. Release를 각각 task.spawn하고, 진행 중인 모든 leave가 끝날 때까지 최대 25초 기다린다.
- G8: 페널티 조건을 `IsInCombat(p) and not S.PlayerService.IsShuttingDown()`으로 바꾼다.

**[M24] 상단 레이아웃: A3-H4 인셋 규칙이 절대 y 슬롯 표와 충돌하고 실제 px/기준 px 단위가 정해지지 않음** (G10·G11)
근거: SPEC_ADDENDUM.md:42-49 / TECH_SPEC.md:1575-1577, 2363-2380, 2384, 2394, 2402, 2470-2474
문제/실패: G10만 War meter를 내리고 G11의 Event strip(72–110)은 그대로라서 둘이 겹친다. 실제 px 인셋을 오프셋으로 쓰면 UIScale 0.75에서 상단바 밑에 깔리고, JumpButton.AbsolutePosition을 그대로 쓰면 공격 버튼이 화면 중앙 쪽으로 간다.
수정:
- UIKit Init에서 MainGui의 자식으로 투명 `Top` 프레임(Size (1,0,0,400))을 만든다. `Top.Position = UDim2.fromOffset(0, math.ceil((GetGuiInset().Y+8)/uiScale.Scale))`이고, 인셋을 얻지 못하면 64를 쓴다. UIScale이나 ViewportSize가 바뀌면 다시 계산한다.
- Top 기준 위치(기준 px):

| 블록 | 위치 |
|---|---|
| Stats | (12, 0), 300×150 |
| War meter | 중앙, 0–58 |
| Event strip | 중앙, 64–118 |
| Status chips | 124–154 |
| Toasts | 160부터 |
| Quest rows | (12, 158) |
| Luck corner | 오른쪽 12, y 0 (터치가 없는 기기는 화면 왼쪽 아래 (12, 높이−64)) |

- G11은 `C.UIKit.Gui:WaitForChild("Top")`을 쓴다.
- 점프 버튼 기준 위치는 `(jump.AbsolutePosition - UIKit.Gui.AbsolutePosition)/s`, 크기는 `jump.AbsoluteSize/s`로 계산한다. 폴백 (-200,-170)은 기준 px다.
- UIScale 하한은 0.75로 한다(2402의 0.6을 정정).

**[M25] 왼쪽 퀘스트 행 버튼이 모바일 조이스틱(DynamicThumbstick) 영역 안에 있음** (G10)
근거: TECH_SPEC.md:2367, 2375, 2402, 2416-2419, 2927-2928 / SPEC_ADDENDUM.md:42-43, 48-49, 75-77, 97-98
문제/실패: 844×390 폰에서 퀘스트 행은 실제 x 9~234, y 150~336으로, 조이스틱 영역(왼쪽 40% × 아래 2/3) 안에 있다. 이동하려고 엄지를 대면 확인 없이 ↻가 눌려 진행 중인 일일 퀘스트가 교체되고, 이동도 시작되지 않는다.
수정:
- 터치 기기에서는 그 영역에 Active=true인 GuiObject를 두지 않는다. 퀘스트 행은 읽기 전용으로 바꾼다.
- 받기와 ↻는 Top 영역(Stats 오른쪽)의 '퀘스트' 칩을 눌렀을 때 열리는 오버레이(x ≥ 40%)에서만 누를 수 있게 한다.
- ↻는 모든 기기에서 `UIKit.Confirm`을 거친다.

**[M26] '공격' 누르고 있기 반복이 버튼 밖에서 손을 떼면 멈추지 않음** (G10)
근거: TECH_SPEC.md:1586-1589, 1758, 1779, 1810, 2421, 2430 / SPEC_ADDENDUM.md:39-41 / GDD.md:136
문제/실패: MouseButton1Up은 버튼 위에서 떼야만 발생하고, InputEnded에도 gameProcessed 필터를 걸면 종료 입력이 버려진다. 그러면 20분 킥까지 수동 스윙이 계속되어 지나가는 적을 때리고(GDD:136 위반) 충전과 단골 운도 계속 오른다.
수정:
- 반복을 시작할 때 InputObject를 저장하고, 매 회 `UserInputState`가 Begin/Change가 아니면 멈춘다.
- 정지 판정에는 gameProcessed 필터를 쓰지 않는다.
- WindowFocusReleased, TextBoxFocused, 자기 캐릭터 사망·리스폰, 피커·패널이 열릴 때도 멈춘다.

**[M27] A1 커스텀 모델: 없는 키 `Config.Monsters[Id].Scale`을 참조하고, weld 뒤 ScaleTo/PivotTo로 루트가 끌려가며, 거위 구조와도 모순됨** (G5·G9)
근거: SPEC_ADDENDUM.md:8-23 / TECH_SPEC.md:848-871, 1352-1359, 1690-1695, 2111, 2119-2122
문제/실패: CustomModels에 Slime을 넣는 순간 nil 인덱스 오류로 MonsterService.Start가 실패해 맵에 몬스터가 하나도 없다. 키를 고쳐도 A1 순서대로 하면 보이는 몸과 판정 루트가 어긋나고, bob 트윈 때마다 몬스터가 튄다.
수정:
- 순서: clone → 속성 설정 → `ScaleTo(목표높이/GetExtentsSize().Y)` → PivotTo(바닥은 루트 아래 지면) → `Util.Weld(root, part)` → parent.
- 목표 높이: `s = Config.MonsterTypes[Id].Scale`일 때 Slime형은 3s, Humanoid형은 5s.
- weld된 파트를 직접 트윈하지 않는다. bob이 필요하면 VisualRoot를 만들어 `Weld.C0`만 트윈한다.
- 거위: 클론의 모든 파트를 Anchored=true, CanCollide/CanQuery/CanTouch=false로 두고, ScaleTo 뒤 `GetPosition()`으로 PivotTo한다. 동작은 v2 그대로다.
- 전체를 pcall로 감싸고, 실패하면 기존 절차형 몸통을 쓴다.
- 로그는 각 서비스 태그로 남긴다.

## LOW

- **[L1] GetNearest에 forPlayer 필터가 없음** (G4·G5) — SPEC_ADDENDUM.md:86-90 / TECH_SPEC.md:1676-1679, 1765-1780, 1794-1795, 1817 — 남의 튜토리얼 슬라임에 가짜 명중·충전·흡혈이 생기고 마법사가 헛스윙한다 → `GetNearest(position, radius, maxCount?, forPlayer?)`(Owner==nil 또는 Owner==forPlayer)로 하고, CombatService는 세 함수 모두에 공격자를 넘긴다. DamageMonster 반환값은 그대로 둔다.
- **[L2] 거위 RegisterHit에 반환값이 없고 GetPosition이 좌우 이동을 반영하지 않음** (G4·G9) — TECH_SPEC.md:1760-1761, 1778, 1781, 2111-2112, 2122-2126, 2448 / SPEC_ADDENDUM.md:121 — 중립이나 초당 상한 초과에도 "+2"가 표시되고, 구슬이 최대 6칸 어긋난다 → `RegisterHit(player,isManual) -> counted`(무시면 0, 아니면 S를 곱한 값). n==0이면 G 히트를 넣지 않고, 아니면 A=n(소수 1자리). `GetPosition() = Position + (xOffset, HoverHeight, 0)`.
- **[L3] 진영 변경 때 완료했지만 받지 않은 일일 퀘스트가 재생성되어 보상이 사라지고, 환생 시 Lv1 기준으로 다시 계산됨** (G8) — TECH_SPEC.md:905-908, 2222-2225, 2253, 2262, 2272, 2284-2285 → FactionChanged 때 완료된 Daily는 유지한다. 미완료이면서 템플릿이 맞지 않는 슬롯만 재생성하고, 기존 RewardGold/RewardXP는 유지한다.
- **[L4] 튜토리얼 고정 퀘스트의 Kind·배지·받기 조건이 정해지지 않음** (G1·G8·G10) — TECH_SPEC.md:866, 2244-2246, 2257-2263, 2270-2276, 2375, 2416-2419 / SPEC_ADDENDUM.md:75-77, 97-103 — 받기 버튼이 없어 2단계에 고정되거나, DailyClaims가 +1 된다 → 항목은 `{Id="tutorial", Kind="Tutorial", Slot=nil, Pinned=true, Target=5, RewardGold=120, RewardXP=0}`이고 TutorialStep==2일 때만 맨 앞에 둔다. HUD는 '처음' 배지와 받기(`"tutorial"`, M25 규칙)를 두고 ↻는 없으며 4행으로 그린다. 서버는 DailyClaims와 상자를 건드리지 않고, SlimeMeadow의 개인 몬스터가 아닌 처치만 센다. G1: `Config.Text.TutorialQuest = "말랑 초원 슬라임 %d마리 잡기"`.
- **[L5] Swing Fx의 Pos/Targets가 비어 있을 수 있음** (G4·G11) — TECH_SPEC.md:1765-1773, 1782-1783, 2442-2448, 2581 — 마법사가 헛스윙하면 모든 클라이언트의 OnClientEvent가 오류를 낸다 → 헛스윙이면 center=자기 root, Around와 헛스윙은 `Targets={}`로 한다. Fx는 Targets가 비면 작은 퍼프만 그리고, 거리 컬링은 Pos가 있을 때만 한다.
- **[L6] PERFECT 창 끝에서 자동 발사와 수동 발사가 경합함** (G1·G4) — TECH_SPEC.md:404, 415, 429-432, 1072, 1792-1793, 1805, 1819-1820, 2423-2424 / SPEC_ADDENDUM.md:39-41 → G1: `Config.Charge.PerfectGrace = 0.25`. 감시 루프는 `Now() >= PerfectUntil + PerfectGrace`일 때 자동 발사하고, 수동 perfect도 같은 유예를 준다. 자동 발사 후 1초 안에 들어온 n<MinRelease 수동 요청은 ReleaseNeed 없이 무시한다.
- **[L7] 알림 중복(레벨업 3번, 금고 토스트 2장, 사이렌 배너 2개)과 A7-3의 담당·문구 키 없음** (G1·G8·G9·G10·G11·G12) — TECH_SPEC.md:1058-1141, 2074, 2204, 2207, 2209, 2394, 2426-2427, 2455-2457, 2475-2476, 2584 / SPEC_ADDENDUM.md:133, 145-156 → 자기 레벨업 배너는 Fx 하나만(A7-3 문구) 띄우고, G8의 notify LevelUp은 삭제한다. Fx Bank는 소리와 '+N G'만 내고, G9의 사이렌 NotifyAll은 삭제한다. HUD는 업그레이드 2줄, 펄스, ShowGuide를 맡고 Fx Reward를 직접 구독한다. 몬스터 이름은 `Config.MonsterTypes[Config.ZoneMainMonster[Config.QuestZoneForLevel(Level)]].Name`, '추천' 배지는 Panels가 맡는다. G1 추가 키: `LevelUpNext = "레벨 업! Lv %d · 다음 해금: Lv %d %s"`, `Unlocked = "해금! %s"`, `UpgradeKillsMore = "%s %d마리 더!"`, `UpgradeAffordable = "%s 살 수 있어요!"`.
- **[L8] 피커 IsOpen 변경을 알릴 방법이 없음** (G10·G11·G12) — TECH_SPEC.md:2432-2433, 2489, 2523-2524, 2532-2544, 2797, 2817-2818 → IsOpen은 속성 조건(2534, 2544)으로 즉시 계산한다. HUD·EventHUD·Panels는 0.2초 루프에서 폴링해 숨김과 휴가 팝업 타이머를 갱신한다.
- **[L9] A3-M3 '공격받는 중!' 토스트의 담당과 키가 없음** (G1·G4) — SPEC_ADDENDUM.md:53-54 / TECH_SPEC.md:1824-1828, 2581 → DamagePlayer에서 attacker가 있고, 피해자의 AutoAttack이 true이고, 그 피해자에게 마지막으로 보낸 지 60초가 지났으면 `Net.Notify(victim, Config.Text.AfkPvPHint, "bad")`. G1: `AfkPvPHint = "공격받는 중! 공격 버튼으로 반격하세요"`. 클라이언트는 구현하지 않는다.
- **[L10] 깡패 상태로 중립 전환해 벌칙을 피하고, 잡을 수 없는 현상금과 복수 화살표가 남음** (G1·G6·G7·G12) — TECH_SPEC.md:1864-1869, 1930-1932, 1966-1969, 2013-2019, 2323-2324, 2477-2479 / SPEC_ADDENDUM.md:116-118 → 목표가 Neutral인 SwitchFaction·TryRebirth에 `GetBullyStacks(p)>0 → BlockedBully` 차단을 넣는다(G1: `"깡패 단계가 모두 풀린 뒤에 장인 길드로 갈 수 있어요."`, Altar 조건 줄에도 표시). 1초 루프는 Neutral이면 Bounty=0으로 쓴다. Neutral로 바뀔 때 자기 복수와, 자기를 대상으로 한 남의 복수를 모두 지운다.
- **[L11] PvP 안내·새싹 표시·거위 힌트가 PvP 면역인 중립에게도 나옴** (G1·G3·G7·G10·G11) — TECH_SPEC.md:1061, 1660-1661, 1968, 2323, 2413, 2473 / SPEC_ADDENDUM.md:116-122 → 중립에게는 `EnteredPvPNeutral = "PvP 지역이지만 장인 길드는 공격받지 않아요."`("info")를 보낸다. HUD 칩은 "PvP 면역"으로 바꾼다. Rookie 속성은 `faction~="Neutral" and IsRookie(p)`로 쓴다. 거위 힌트는 `GooseHintNeutral = "장인 길드는 줄다리기에 참여하지 않아요"`.
- **[L12] GDD에 중립 진영이 전혀 없음** (리드) — GDD.md:9, 133-135, 170-175, 244-247, 291-300 → '5-8 장인 길드' 절을 추가한다(버프 없음, PvP 면역, 전쟁·저울 제외, 홈은 교차로, 직업명, 제작은 페이즈2). 1장은 '세 편'으로, 5-5는 목적지 선택·중립 이탈 무손실로, 9장은 환생 버튼 3개(+25%, 표식은 빛↔뿔만)로, 12장 교차로는 부활 장소로 고친다.
- **[L13] 안전지대에서 발구르기를 맞은 뒤 몬스터에게 죽어도 PvP KO(약탈)로 처리됨** (G9) — TECH_SPEC.md:443, 597, 649, 1824-1838, 1993-2000, 2081-2083 / GDD.md:192 → `DamagePlayer(v, amount, S.ZoneService.IsPvPZone(v) and p or nil)`.
- **[L14] 약한 편 가입 보너스 +300을 받고 곧바로 무료 전환할 수 있음** (G6) — TECH_SPEC.md:258, 545, 1860-1863, 1867-1868, 2618 / GDD.md:181 → SignOnGold를 지급할 때만 `SetStat(p,"LastSwitchTime",os.time())`을 함께 쓴다.
- **[L15] 직업 변경에서 잃을 것이 없는데(Lv1, XP 0)도 티켓이 차감됨** (G6·G12) — TECH_SPEC.md:1893-1898, 2510-2519 / SPEC_ADDENDUM.md:161-164 → `Level==1 and XP==0`이면 서버는 useTicket을 무시하고 무료로 처리한다. 패널은 티켓·구매 버튼을 숨기고 "잃는 것 없음"을 표시한다. 진영 쪽은 H3에 포함됐다.
- **[L16] UIScale 하한과 UITextSizeConstraint가 효과 없음** (G10·G11·G12) — SPEC_ADDENDUM.md:48-49 / TECH_SPEC.md:2390-2392, 2402 → TextScaled=false인 텍스트는 TextSize ≥ 15로 한다(UIKit은 `math.max(props.TextSize or 18, 15)`). UITextSizeConstraint는 TextScaled=true인 텍스트에만 쓴다. 2402의 0.6을 0.75로 고친다.
- **[L17] 가이드 빔이 리스폰 때 사라지고 다시 생기지 않음** (G10) — SPEC_ADDENDUM.md:73-74, 93-94, 153-155 → HUD가 현재 가이드(part, text)를 기억하고, CharacterAdded마다 새 HRP에 Attachment0을 다시 연결한다.
- **[L18] 콤보 'x12'의 화면 슬롯이 없어 폰에서 버튼 군과 겹침** (G11) — TECH_SPEC.md:2363-2380, 2463-2464 / SPEC_ADDENDUM.md:44-47 → 슬롯 표에 `Combo | Fx | x 50%, y 66%, 높이 ≤ 24, Active=false`를 추가한다.
- **[L19] 폰에서 토스트 스택이 이동 바와 개인 라인을 덮음** (G10) — TECH_SPEC.md:2371, 2376-2377, 2394 / SPEC_ADDENDUM.md:42-43 → 뷰포트 높이가 500 미만이면 토스트는 최대 2개, 폭은 화면의 45% 이하, TextWrapped=true로 한다.

## 그룹별 체크리스트

- **G1**: H1, H2, H3, M2, M3, M10, M13, M14, M16, M18, L4, L6, L7, L9, L10, L11
- **G2**: M3, M8, M21, M22, M23
- **G3**: H1, M5, M6, M7, L11
- **G4**: H1, H2, H5, M16, L1, L2, L5, L6, L9
- **G5**: M4, M5, M6, M27, L1
- **G6**: H3, H4, M8, M14, L10, L14, L15
- **G7**: M5, M10, M12, M13, M14, M15, M19, L10, L11
- **G8**: H1, M1, M3, M4, M11, M17, M18, M20, M23, L3, L4, L7
- **G9**: M5, M9, M10, M15, M17, M27, L2, L7, L13
- **G10**: M3, M5, M24, M25, M26, L4, L7, L8, L11, L16, L17, L19
- **G11**: M5, M24, L5, L7, L8, L11, L16, L18
- **G12**: H3, H4, M1, M2, M5, M11, L7, L8, L10, L15, L16
- **리드(문서)**: L12, 아래 A13 반영

## SPEC_ADDENDUM에 넣을 문장

SPEC_ADDENDUM에는 이미 A9~A12가 있어서, 아래 내용은 **A13**으로 추가한다.

```
## A13. Cross-review round 2 (authoritative; overrides TECH_SPEC and A1–A12 where they conflict)

- A13-H1 Kaiju vs towns (G1,G3,G4,G8): ZoneService zone loop, every tick (not only on zone change), right after the level gate:
  if kstate(p) == "Active" and the zone is HaloTown or HornsTown → character:PivotTo(GetSpawnCFrame("Crossroads")) + notify
  KaijuNoTown ("bad", max once per 3 s). Crossroads stays allowed (the CanAttack kaiju exception applies there). A3-L1 unchanged.
  CombatService regen: pct = 0 while kstate(p) == "Active". ProgressionService 1 s loop: skip the town BankAll while kstate(p)
  is "Siren" or "Active". G1 adds Config.Text.KaijuNoTown = "괴수는 진영 마을에 들어갈 수 없어요!".
- A13-H2 Halo ally stacks (G1,G4): Config.Charge.HaloAllyStackCooldown = 5. Release step 6 grants HaloAllyStacks only if total > 0,
  and to each ally a only if os.clock() - (lastAllyStackAt[a] or -math.huge) >= HaloAllyStackCooldown (then record; clear on leave).
- A13-H3 SwitchFaction (G1,G6,G12): payload SwitchFaction(useTicket: boolean, targetFaction: string?). Order: ready →
  type(useTicket)=="boolean" and (targetFaction==nil or string) → rate limit → faction ~= "None" → target (nil ⇒ Halo↔Horns,
  silent if current is Neutral; else must be Halo/Horns/Neutral and ≠ current, silent otherwise) → altar range → existing blocks →
  if the free path loses nothing (leaving Neutral, Halo with Honor 0, Horns with Infamy 0) force useTicket = false → UseTicket only
  if useTicket → success. Free: leaving Halo ⇒ Honor 0, Horns ⇒ Infamy 0, Neutral ⇒ nothing. Notify SwitchDoneFree /
  SwitchDoneTicket / SwitchDoneNoLoss (G1: "%s(으)로 진영을 바꿨어요!"). Altar panel: two target cards → [무료]/[티켓]
  (ticket and buy buttons hidden when nothing is lost) → always FireServer(useTicket, targetId).
- A13-H4 ChooseFaction (G6,G12): accept "Halo" | "Horns" | "Neutral" (§4.10, §5); add "Neutral" to the Faction type (GetFaction,
  §6.1, §6.2); three Teams. wasWeaker unchanged. GetCounts stays (halo, horns). FactionPicker: three cards in
  Config.PlayableFactions order, card width <= 30% of the screen on phones.
- A13-H5 Manual swing (G4 only; replaces the 1.0 s window of A3-H3): Swing remote sets lastManualAt[p] = os.clock() after ready +
  rate limit and before the cooldown check; auto loop skips while os.clock() - lastManualAt[p] < c.SwingInterval + 0.3; manual:
  if now < nextSwingAt - 0.15 then return end; nextSwingAt = math.max(now, nextSwingAt) + c.SwingInterval. Auto unchanged.
- A13-M1 Rebirth (G8,G12): target ∈ Halo/Horns/Neutral. halo, horns = GetCounts(); subtract 1 (min 0) only from the player's
  current faction if it is Halo or Horns; bonus = target=="Neutral" and Config.Rebirth.BonusNormal or
  Config.RebirthBonusFor(target=="Halo" and halo or horns, halo+horns). Marks Halo↔Horns only. Rebirth never changes
  Honor/Infamy; A6's free/ticket rule is altar-only. Panel: 3 buttons, 장인 길드 shows fixed "+25%", no mark preview.
- A13-M2 Neutral config (G1 pastes verbatim): Config.Factions.Neutral = { Id="Neutral", Name="장인 길드", Short="장인",
  Emblem="⚙", TeamName="장인 길드", TeamColor=BrickColor.new(Color3.fromRGB(40,200,190)), Color=Color3.fromRGB(40,200,190),
  XPBonus=0, GoldBonus=0, DamageBonus=0, MaxHPMult=1.0, RegenPerSec=0.01, Lifesteal=0, LifestealCapPct=0, AutoBankInterval=0,
  AutoBankFraction=0, PartyAuraPerAlly=0, PartyAuraMaxAllies=0, PartyAuraRadius=0, CanBeWanted=false, ChargeCap=150,
  ReleaseSupport=false, Perks={"싸움 버프 없음","PvP 없음: 누구도 때리거나 맞지 않아요","제작 특화 (곧 추가)"},
  Pitch="싸움 버프 없음 · PvP 없음 · 제작 특화(곧 추가)" }; Config.Story.FactionLore.Neutral = "조각을 줍지 않고, 다듬기로 한 자들.";
  Config.Classes.Warrior/Mage/Archer.Names.Neutral = "대장장이"/"연금술사"/"사냥꾼"; Config.Classes.*.PickLine (A7-4 values);
  Config.PlayableFactions = {"Halo","Horns","Neutral"}. FactionOrder unchanged. Consumers read new string keys with `or ""`.
- A13-M3 TutorialStep (G1,G2,G8,G10): Defaults TutorialStep = 0; Mirrored "TutorialStep". DataService: new record = old == nil or
  a table with no key other than SessionLock → 0, skip migrate and its log; otherwise a missing field → 99 before filling
  defaults; memory mode = new. QuestService writes it only via SetStat; HUD reads UIKit.Attr("TutorialStep", 99).
- A13-M4 Tutorial start (G5,G8): QuestService subscribes ClassService.ClassChanged; when ClassChosen, Faction ~= "None",
  TutorialStep == 0 and no living personal slime → task.defer SpawnPersonal 8 studs in front of the root. The C4 restart on
  CharacterSpawned runs only when Faction ~= "None" and ClassChosen; a personal slime > 30 studs away is replaced in front.
  SpawnPersonal opts: golden look/reward, MaxHP = opts.HP (after the golden multiplier), WarPoints 0, counts for quests.
- A13-M5 Session attributes (G3,G5,G7,G9,G10,G11,G12): on PlayerReady write SackGold=0, SackSeconds=0, SackVictimName="",
  WantedStars=0, Bounty=0, Rookie=IsRookie(p), Protected=false, RevengeTargetId=0, RevengeUntil=0, KaijuState="None",
  SessionTitle="", GooseCount=0, WarPoints=0. WarService also writes WarPoints=0 on FactionChanged and at round end for every
  ready player. Clients read other players' attributes as (p:GetAttribute(k) or default), own ones via UIKit.Attr(k, default).
- A13-M6 War points per kill (G3,G5): MonsterService clones info per contributor and sets info.WarShare = WarPoints / (rewarded
  contributors of the same faction). WarService adds info.WarShare or info.WarPoints to the faction pool, info.WarPoints to personal.
- A13-M7 War denominator (G3): every Tick presence[f] += count, ticks += 1; per-capita = points[f] / math.max(1, presence[f] /
  math.max(1, ticks)) for display and the result; Siege/Idle treat an average < 0.5 as 0; reset with the round.
- A13-M8 Size Justice activity (G2,G6): PlayerService.GetLastActive(player) -> number (os.clock, 0 if none). JusticeService sums and
  counts only non-rookies active within 120 s and not continuously in a town for >= 60 s (ZoneChanged). Excluded players keep their S.
- A13-M9 Goose (G9): subscribe FactionChanged; while a goose is active drop the player's counts (side totals stay), GooseCount = 0.
- A13-M10 Kaiju collusion (G1,G7,G9): pool carried part = math.min(TakeCarriedGold(victim, all), PlunderCapPerLevel * Level);
  Config.Kaiju.PairRewardCooldown = 1800 per participant–kaiju UserId pair (others get 0, still counted); Survived amount =
  c + math.min(math.floor(c * (SurviveBankMult - 1)), PlunderCapPerLevel * Level); HandleKO step 6 calls addStar only when pairOk.
- A13-M11 Vacation (G8,G12): run day-check step 2 before step 1; auto-paid dailies also add DailyClaims and pay the chest at Slots.
  Step 1: if DailyDay > 0 then f = (min(DailyClaims,Slots)*QuestMinutes + (DailyClaims >= Slots and ChestMinutes or 0)) /
  (QuestMinutes*Slots + ChestMinutes); days = min(VacationMaxDays, VacationDays + (1 - f) + max(0, today - DailyDay - 1))
  (fractional). Panel shows math.ceil(VacationDays).
- A13-M12/M13 Bait (G1,G7): Config.Bully.BaitMinPct = 0.2. baited = the victim's damage to the killer within BaitWindow (logged from
  PlayerDamaged) >= BaitMinPct * Config.MaxHealth(killer level, faction, class). Use it for the weak exception. If baited and
  (fresh or repeated): no bully, KO info Kind = "Defense" (no stack/stars/plunder/honor/infamy/bounty, Rewarded = false; revenge
  and koLog kept). A killer with kstate ~= "None" is never a bully.
- A13-M14 Penalties persist (G1,G6,G7): Defaults SavedBully, SavedBullyAt, SavedStars, SavedStarsAt (not mirrored), written to data
  in PlayerLeaving, restored on PlayerReady with offline decay (DecaySeconds / StarDecaySeconds); stars capped at StarsNeeded - 1.
- A13-M15 Logout escape (G7,G9): an Active kaiju leaving with total damage > 0 resolves as Defeated (pool = BountyPoolMult *
  Config.Bounty(Level, stars, bully), carried gold untouched, Halo +150, KaijuEnded; pcall character access). A wanted Horns
  leaving while IsInCombat with a Halo GetLastPvPAttacker pays Config.Bounty(Level, stars, bully) to that attacker (pair cooldown).
- A13-M16 Kaiju release cap (G1,G4): Config.Kaiju.ReleaseCapPct = 0.08 replaces PvPCapPct when the victim's kstate is "Active".
- A13-M17 Kaiju split (G8,G9): totalDmg = sum of dmg over all Halo recorded this event (leavers included); dmgPart = totalDmg > 0
  and floor(pool * DamageShare * (dmg[p] or 0) / totalDmg) or 0; totalDmg == 0 ⇒ split the whole pool equally.
  AddBankGold/AddCarriedGold/AddXP ignore NaN/inf with Util.Warn.
- A13-M18 Rebirth stay lock (G1,G8): Config.Rebirth.StayLock = 1800; on a faction-changing rebirth
  SetStat LastSwitchTime = os.time() + StayLock - Config.Switch.Cooldown.
- A13-M19 Bully bounty (G7): no bully bounty if koLog[victim][killer] has an entry within RepeatWindow; at most one bully bounty per
  bully per Config.Bully.DecaySeconds server-wide.
- A13-M20 Level-up heal (G8): AddXP level-up calls RefreshCharacter(p, S.KaijuService.GetState(p) ~= "Active").
- A13-M21 ProcessReceipt (G2; replaces the A7-4 ProcessReceipt sentence): follow §4.21 — new PurchaseId: record + AddTickets;
  new or already, return PurchaseGranted only if Save(player, false) succeeds, else keep grant and id in memory and return
  NotProcessedYet. Never roll back.
- A13-M22 DataService ordering (G2): serialize Load/Save/Release (incl. retries) per UserId in one queue; build the save copy
  from the cache when the job runs and on every retry; Release sets releasing[player] = true before yielding; non-release
  Save returns false without I/O if releasing or uncached; the non-release transform aborts if old.SessionLock is nil or
  owned by another JobId. Cache keyed by Player.
- A13-M23 Leave/shutdown (G2,G8): FinalizeLeave sets leaving[p] synchronously first; if already leaving, wait for completion;
  else Fire PlayerLeaving once → ready = false → Release → ClearPlayer → done. Add PlayerService.IsShuttingDown(). BindToClose:
  shuttingDown = true; fire PlayerLeaving synchronously for every ready, not-leaving player; then set ready = false; then spawn
  all Releases and wait (<= 25 s) for every in-progress leave. Combat-log penalty only when not shutting down.
- A13-M24 Top layout (G10,G11): UIKit creates frame "Top" under MainGui at
  fromOffset(0, ceil((GetGuiInset().Y + 8) / UIScale.Scale)) (64 if unavailable), recomputed on UIScale/viewport change.
  Top-relative reference px: Stats (12,0) 300x150; War meter 0–58; Event strip 64–118; Status chips 124–154; Toasts from 160;
  Quest rows (12,158); Luck corner right 12, y 0 (non-touch: bottom-left (12, H-64)). EventHUD parents into Top. Jump-button
  anchoring uses (jump.AbsolutePosition - UIKit.Gui.AbsolutePosition) / scale; fallback (-200,-170) is reference px.
  UIScale min 0.75.
- A13-M25 Touch quest rows (G10): on touch devices nothing Active in the left 40% x bottom 2/3; quest rows read-only; claim and
  reroll live in an overlay (x >= 40%) opened by a "퀘스트" chip in Top; reroll always goes through UIKit.Confirm.
- A13-M26 Hold repeat (G10): store the InputObject; stop when its UserInputState is not Begin/Change, on WindowFocusReleased,
  TextBoxFocused, own death/respawn, picker/panel open. No gameProcessedEvent filter on end/stop.
- A13-M27 A1 order (G5,G9; replaces A1's order and Scale source): clone → set properties → ScaleTo(targetHeight /
  GetExtentsSize().Y) → PivotTo → Util.Weld(root, part) → parent. targetHeight from Config.MonsterTypes[Id].Scale (Slime 3s,
  Humanoid 5s). Never tween welded parts directly (VisualRoot + Weld.C0 if bob is wanted). Goose clone: all parts Anchored,
  CanCollide/CanQuery/CanTouch false, PivotTo(GetPosition()). Whole override in pcall, fallback to the procedural body.
```

참고 파일: C:/Users/glori/Documents/Game/docs/TECH_SPEC.md, C:/Users/glori/Documents/Game/docs/SPEC_ADDENDUM.md, C:/Users/glori/Documents/Game/docs/GDD.md