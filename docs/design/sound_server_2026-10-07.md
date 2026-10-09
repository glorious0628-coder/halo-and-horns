# 소리 서버 몫 (게임성 개발 2, 2026-10-07 밤)

근거: `docs/design/sound_gaps_2026-10-07.md`(소리 만들기 대조) C1·B2·B6·B11·C3, 경로표는 `docs/design/sound_spec_2026-10-07.md` §4-2. 서버는 **키 이름만** 보낸다. 소리를 고르고 내는 것은 클라(개발 1, `Audio.luau`·`Config.Audio`)다.

## 1. C1 — "reward" 알림의 Sound (QuestDone은 퀘스트·이야기·일일·게시판 완료만)

| 줄 | Sound |
|---|---|
| 같은 무기가 또 나와 금으로 바뀜(LootService DuplicateWeapon) | GoldPickup |
| 대박 무기(JackpotSelf)·희귀 무기 드롭(RareWeapon)·첫 무기가 가방으로(FirstWeaponBag) | Equip |
| 맨손에서 바로 장착(JackpotEquip·RareWeapon+BareEquip·FirstWeapon) | None — HUD의 첫 무기 순간이 PowerUp을 낸다(겹침 없앰) |
| 첫 주문서 안내(FirstScroll / FirstScrollBare) | None — 떨어지는 소리는 Fx Loot 몫 |
| 펫 받음(PetGot)·조련사 안내(Became / BecameFree) | None |
| 새싹 보호 끝(GraduateStart)·대담함 x2(BoldStrong) | None |
| 약탈 이득(PlunderGain)·자루 지급(SackPaid)·복수 보너스(AvengerBonus)·약자 진영 보너스(UnderdogSignOn) | GoldPickup |
| 명예·악명 오름(HonorGain)·장인 명성(ArtisanGain)·주간 상위 3명 칭호(RankingService) | RankUp |
| Robux 구매(MonetizationService)·환생(RebirthDone) | None |

C3: 괴롭힘·무법자로 자동 전투가 강제로 꺼질 때의 'bad' 알림은 Sound "None"(AutoOff 소리만, Deny 없음).

## 2. B2 — 약탈 Fx

- `Net.Fx(nil, "Plunder", { From, To, Amount, Victim = 뺏긴 사람 UserId, Thief = 뺏은 사람 UserId })` — 모두에게. 클라: 내가 Victim이면 **Plunder**, Thief면 GoldPickup(알림 줄이 이미 GoldPickup이니 겹치지 않게).
- 원한 자루 되찾기(GrudgeService, 뺏긴 사람에게만): `{ From, To, Amount, Victim, Thief, Refund = true }` — 돈이 돌아옴: GoldPickup(Plunder 아님). Thief는 **뺏은 사람**(복수해 준 사람이 아님, 검수 2026-10-07 고침), 동전은 뺏은 사람 자리에서 날아온다.

## 3. B6 — 전쟁 한 판 끝

`Net.NotifyAll(WarWin[winner], nil, nil, "CrownHalo" | "CrownHorns")`, 비김은 `"None"`. 상자 보상(WarChest, GoldPickup)은 클라가 1.5초 미룬다(경로표 11).

## 4. B11 — 왕을 쓰러뜨림

`Net.Fx(nil, "KingDefeat", { Key = "PumpkinKing" | "GhostKing"(HalloweenService의 Key; 지금은 필드 보스 `"SlimeKing"`·`"Clatter"`도 FieldBossService가 같은 Fx로 보냄 + `Share`, A23-84·`captain_clatter_2026-10-09.md`), Kind, Pos(몸이 없으면 nil), Contributors = { 보상 받은 사람 UserId… } })` — 모두에게, **쓰러뜨렸을 때만**(그냥 떠나면 안 옴). 클라: Contributors에 내가 있으면 0.65 볼륨 + 내 KillPop·동전 0.25초 뒤, 아니면 0.45.
- Contributors = 이번 처치가 보상을 준 사람(MonsterService의 eligible: 120초 안, 3번 이상, 0.5% 이상)의 UserId, 작은 순서.
- 검수 2026-10-07 고침: MonsterService가 기여 표를 비운 **뒤에** HalloweenService가 읽어서 늘 빈 목록이었어요. 이제 처치할 때 기록에 `PaidUserIds`로 남기고, HalloweenService는 그것을 읽어요. 시험: `tools/test_halloween.py` king-rewards(Mid·Ace·Bo 세 명).

## 5. 검사

`py tools/test_notify_sound.py` — 경로표 전체(위 줄 포함) + Plunder Victim/Thief/Refund, Crown 키, KingDefeat(쓰러뜨렸을 때만, Contributors)를 소스에서 확인하고, 줄마다 소리를 빼거나 옛 글로 되돌리는 변이를 모두 잡는다.
