# PET-4 길 잃은 아기 슬라임 — 서버 계약 (게임성 개발 2, 2026-10-09)

근거: `docs/design/content_beyond_10min_2026-10-08.md` §2 B, A23-86 결정 4(속도 +7~10% 그대로). 가지 `dev2-pet4`.

## 서버(끝)
- 이야기 서브 `Pet1` "The Lost Baby Slime"(M1_1 뒤): 초원 슬라임 8마리 → 선택 카드(기존 이야기 선택 창 그대로).
  - 빛: [Take care of it] 명예 +1 / [Make it my minion] 명예 −1. 뿔: 반대(A23-58, 0 바닥). 중립: A/B 기록만.
- 고르면 어느 쪽이든 아기 슬라임 펫이 와요(`PetService.GrantPet`, 일반용). 알림 "A Baby Slime joined you! It hops along behind you."(조련사 문구 아님, 용어집 대문자 — PET-2b L5). 고른 뒤 0.5초 늦게 와요(PET-2b L3: 퀘스트 줄이 먼저, 창이 열려 있으면 알림은 한 줄씩이라 마지막 줄로).
  - 펫 기록 `Lean` = Good / Evil, `Name` = "Good Buddy" / "Little Minion"(`Config.PetGrant.Names`). 이미 아기 슬라임이 있는 조련사는 새로 받지 않고 Lean·이름만 채워요.
  - 걷기 속도 보너스는 그대로예요(`Config.PetSpeedBonus`).
- `GiveTamerPet`은 이제 `GrantPet`을 불러요(조련사 문구 그대로).

## 개발 1 몫(클라)
1. 이름표 `Good Buddy` / `Little Minion`은 **내 펫에만**(PetFollow). 이름은 `data.Pets.List[uid].Name`(지금 공개 속성은 EquippedPet/PetLv/PetForm뿐이라, 이름이 필요하면 서버가 `PetName` 속성을 더할게요 — 말해 주세요). → 내 펫 이름은 이제 PET-2 `PetList`의 `Name`으로 받을 수 있음(아래).
2. 폰: 남의 펫은 가까운 6마리, Range 80까지만 그리기.
3. Lean 모습(은고리 / 작은 뿔)은 그림이 오면.

## 아직 아님
- ~~펫 끄기(EquipPet 원격·숨기기, PET-5)는 다음.~~ → EquipPet 원격(`""` = 넣어 두기)은 아래 PET-2로 끝남(main ae1fa582). 남은 건 PET-5 펫 창(장착·넣어 두기 버튼) = 개발 1.

## 시험
`py tools/test_tamer.py` — "lost baby slime" 묶음 13개 포함 113개, 변이 48/48.

# PET-2 펫 서버 (게임성 개발 2, 2026-10-09, 같은 가지)

- 펫 XP: 주인이 보상받는 처치마다(자동 전투 포함) 장착한 펫 +1(`Config.Pets.XPPerKill`). Lv n → n+1에 15 × n(`XPPerLv`), 최대 Lv10. 레벨이 오르면 걷기 속도 다시 계산(+7% → +10%, `Config.PetSpeedBonus`).
- c→s `EquipPet(uid)`: 내 펫(아는 종류 = `Config.Pets.Species`)을 따라오게, `""`면 넣어 두기. 인자 1개만, 0.5초 간격(`Config.RateLimits.EquipPet`). 넣어 둔 펫은 XP를 안 받아요. 넣어 두기는 저장돼요(`Pets.Away`, PET-2b). **테이머의 `""`는 무시**(펫이 곧 무기).
- s→c `PetList`(주인만): `{ Equipped, List = { { Uid, Sp, Lv, XP, Need, Name, Lean } }, CanPutAway }` — 접속·지급·장착·레벨업·직업/진영 바뀜 때 바로, XP만 바뀐 건 1초에 한 번으로 묶어서(`Config.Pets.ListEvery`, PET-2b L4). `CanPutAway = false`면(테이머) 펫 창이 넣어 두기 버튼을 숨겨요.
- 따라잡기: Pet1을 끝내고 선택이 저장됐는데 아기 슬라임이 **없을 때만**(옛 저장·끊김) 접속 때 조용히 지급. 이미 있는 펫은 그대로(넣어 둔 것도).
- 펫 XP는 보상받는 처치만: 무임승차 몫(`info.Minor`)은 0(PET-2b L1).
- 개발 1 몫: 펫 창(목록·장착/넣어 두기 버튼)과 Lv·XP 막대는 `PetList`·`EquipPet`로.
  - → 검수 10/09: 펫 창의 넣어 두기 버튼 전에 PET-2b(개발 2 → 개발 3 검증 → 검수 병합)가 먼저예요 — 넣어 둔 펫이 다시 접속하면 다시 나오는 것(M1) 고침, **테이머는 넣어 두기 불가**(PetList 표시로 버튼 숨김). 근거 `docs/review/pet2_verify_2026-10-09.md`.
  - → PET-2b(가지 `dev2-pet2b`): 위 내용대로 고침. 펫 창은 `CanPutAway`로 버튼을 숨기고, 넣어 둔 뒤 다시 접속해도 넣어 둔 채로 와요(`Equipped = ""`).

시험: `py tools/test_tamer.py` — "pet levels and equip" 묶음 포함 129개, 변이 59/59.
PET-2b 뒤(가지 `dev2-pet2b`): "put away" 묶음(넣어 둠 → 다시 접속, 테이머 무시·CanPutAway, 따라잡기) 포함 163개, 변이 86/86. 전체 오프라인 시험 103개 중 102개 통과(`test_intro_seen`은 origin/main에서도 같은 QuestService 오류 — 이 가지와 무관). `test_story_text` 경고 34 → 31.
