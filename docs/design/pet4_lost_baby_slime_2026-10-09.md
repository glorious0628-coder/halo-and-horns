# PET-4 길 잃은 아기 슬라임 — 서버 계약 (게임성 개발 2, 2026-10-09)

근거: `docs/design/content_beyond_10min_2026-10-08.md` §2 B, A23-86 결정 4(속도 +7~10% 그대로). 가지 `dev2-pet4`.

## 서버(끝)
- 이야기 서브 `Pet1` "The Lost Baby Slime"(M1_1 뒤): 초원 슬라임 8마리 → 선택 카드(기존 이야기 선택 창 그대로).
  - 빛: [Take care of it] 명예 +1 / [Make it my minion] 명예 −1. 뿔: 반대(A23-58, 0 바닥). 중립: A/B 기록만.
- 고르면 어느 쪽이든 아기 슬라임 펫이 와요(`PetService.GrantPet`, 일반용). 알림 "A baby slime joined you! It hops along behind you."(조련사 문구 아님).
  - 펫 기록 `Lean` = Good / Evil, `Name` = "Good Buddy" / "Little Minion"(`Config.PetGrant.Names`). 이미 아기 슬라임이 있는 조련사는 새로 받지 않고 Lean·이름만 채워요.
  - 걷기 속도 보너스는 그대로예요(`Config.PetSpeedBonus`).
- `GiveTamerPet`은 이제 `GrantPet`을 불러요(조련사 문구 그대로).

## 개발 1 몫(클라)
1. 이름표 `Good Buddy` / `Little Minion`은 **내 펫에만**(PetFollow). 이름은 `data.Pets.List[uid].Name`(지금 공개 속성은 EquippedPet/PetLv/PetForm뿐이라, 이름이 필요하면 서버가 `PetName` 속성을 더할게요 — 말해 주세요).
2. 폰: 남의 펫은 가까운 6마리, Range 80까지만 그리기.
3. Lean 모습(은고리 / 작은 뿔)은 그림이 오면.

## 아직 아님
- 펫 끄기(EquipPet 원격·숨기기, PET-5)는 다음.

## 시험
`py tools/test_tamer.py` — "lost baby slime" 묶음 13개 포함 113개, 변이 48/48.

# PET-2 펫 서버 (게임성 개발 2, 2026-10-09, 같은 가지)

- 펫 XP: 주인이 보상받는 처치마다(자동 전투 포함) 장착한 펫 +1(`Config.Pets.XPPerKill`). Lv n → n+1에 15 × n(`XPPerLv`), 최대 Lv10. 레벨이 오르면 걷기 속도 다시 계산(+7% → +10%, `Config.PetSpeedBonus`).
- c→s `EquipPet(uid)`: 내 펫(아는 종류)을 따라오게, `""`면 넣어 두기. 인자 1개만, 0.5초 간격(`Config.RateLimits.EquipPet`). 넣어 둔 펫은 XP를 안 받아요.
- s→c `PetList`(주인만): `{ Equipped, List = { { Uid, Sp, Lv, XP, Need, Name, Lean } } }` — 접속·지급·장착·XP 때.
- 따라잡기: Pet1을 끝내고 선택이 저장됐는데 펫이 없으면(옛 저장·끊김) 접속 때 조용히 지급.
- 개발 1 몫: 펫 창(목록·장착/넣어 두기 버튼)과 Lv·XP 막대는 `PetList`·`EquipPet`로.

시험: `py tools/test_tamer.py` — "pet levels and equip" 묶음 포함 129개, 변이 59/59.
