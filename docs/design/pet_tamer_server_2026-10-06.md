# A23-39 펫 조련사 — 서버 계약 (게임성 개발 2, 2026-10-06)

사용자 결정 A23-39: 장인 길드의 3번째 직업 '사냥꾼(궁수)'을 **펫 조련사**로 바꾼다. 내부 직업 id는 그대로 `Archer`, 장인 길드(`Neutral`)일 때만 이름·모습·공격 연출이 바뀐다. 수치는 궁수 표 그대로(균형 변화 없음). 오프라인 검사: `py tools/test_tamer.py`(93검사, 변이 36/36, 자체 검토 확인 4건 반영), 맨손 시작 검사와 같은 가짜 세계(`tools/fixtures/dev2_combat_world.luau`)를 쓴다.

> 2026-10-09 검수: 지금은 장인 길드 진영이 꺼져 있어(`Config.Features.NeutralFaction = false`, A23-57) 새 플레이어는 조련사를 고를 수 없다. (10/11 A23-119: 공개 베타 12/1에는 장인 길드(중립)가 **함께 들어가므로** 이 스위치는 그때 켠다 — '베타에선 꺼짐'은 낡음.) 아기 슬라임 펫은 누구나 이야기 서브 'The Lost Baby Slime'(`Pet1`, PET-4, main ae1fa582)로 받는다. 게임 글은 영어만(A23-48).

## 1. 판정
- `Config.IsTamer(classId, factionId)` = `Archer` + `Neutral`일 때만 true. 설정은 `Config.Tamer`(Config 끝 블록).
- 평타·스킬 Q·자동 전투: 궁수와 똑같은 사거리·간격·대상 수·피해·MP·재사용(빛 궁수와 피해가 같은 것을 검사). 맨손이면 A23-34 주먹 규칙(사거리 7, 1마리, 2 피해).
- `Config.AttackProfile("Archer", tier, "Neutral")` = 궁수 행(무기) 또는 주먹(맨손)에 `Style = "PetHeadbutt"`만 더한 캐시 표.
- 펫은 서버 물체가 아니므로 무엇의 대상도 아니다(클라이언트가 만드는 펫 모델은 몬스터·플레이어 대상 폴더에 넣지 않는다).

## 2. 이름·무기
- `Config.Classes.Archer.Names.Neutral` = ~~"펫 조련사"~~ → "Pet Tamer"(A23-48 영어만).
- 무기 줄: `Config.WeaponNames.Tamer`(~~나뭇가지 지휘봉 … 젤리 왕관 지휘봉~~ → "Twig Baton" … 영어 이름, `WeaponNamesEn`은 이제 같은 표, A23-48). `Config.WeaponName(tier, "Archer", "Neutral")`이 자동으로 이 줄을 쓴다(모든 서버 알림·대장간·전체 알림 같은 길).
- 아이콘: `Config.WeaponArtKey(1~6, "Archer", "Neutral")` = `Weapon_Tamer_T1`~`T6`(이미지 생성 2 묶음 15·16, approved). T7·T8은 그림이 생길 때까지 궁수 키. **이미지 개발: Weapon_Tamer_T1~T6을 Config.UIArt에 올려 주세요**(키가 없으면 지금처럼 대체 그림).
- 직업 카드 글: `Config.ClassCard(classId, factionId)` → 조련사면 `Config.Tamer.Card`({Desc, DescEn, PickLine, PickLineEn, Stats, StatsEn}), 아니면 직업 행의 Desc/PickLine/Stats.
- 손: CharacterVisuals가 조련사에게는 활 대신 오른손 짧은 지휘봉(코드 모양, WeaponModel `Class = "Archer"`, AttackMuzzle = 지휘봉 끝)을 만든다. 맨손이면 아무것도 없다.

## 3. 펫 (PetService, 새 서버 모듈)
- 저장 `data.Pets = { List = { [uid] = { Sp, Lv, XP, Name, Lean, Bound } }, Equipped = { uid }, Next }`(PET-2 계약 그대로, uid = "P1", "P2" …). 접속 때 정리(깨진 항목 버림, 모르는 종은 남기되 장착 안 함, Lv 1~10, 장착 1마리).
- 속성(모든 클라이언트): `EquippedPet`(종 id, 없으면 ""), `PetLv`(없으면 0), `PetForm`(지금은 "").
- 조련사가 되는 순간(직업 고르기 `ClassChanged`, 직업 변경, 제단 진영 변경 `FactionChanged`, 또는 조련사로 접속) 아기 슬라임(`BabySlime`)을 **한 번** 준다: Lv1, Bound, 장착 중인 펫이 없으면 장착, 알림 `Config.Tamer.Text.PetGot`. 이미 가진 아기 슬라임은 다시 주지 않는다(조련사를 그만둬도 펫은 남는다). 신호 `PetService.PetGranted(player, uid, species)`(PET-6 알림용).
- A23-39 전의 장인 사냥꾼 세이브(`TamerNotice`가 없음): 첫 접속 한 번 `Config.Tamer.Text.Became` 알림 + **직업 변경권 1장**(`MonetizationService.AddTickets(player, "Class", 1)`, 레벨 유지 변경) + 펫. 세션 안에서 조련사를 고른 사람은 `TamerNotice = true`만(변경권 없음).
- 새 원격은 없다(펫 목록 원격·EquipPet은 PET-2).

## 4. 게임성 개발 1에게: 연출 원격 계약 (10/15)
1. Fx `Swing`(기존 원격): 조련사면 `Style = "PetHeadbutt"`. `Class = "Archer"` 그대로. 무기가 있으면 `Targets` = 맞은 대상 최대 2(궁수와 같음), 헛치면 앞쪽 한 점. `ContactDelay = 0.3`(펫이 닿는 때, 서버 밀림도 0.3), `LaunchDelay`·`FlightTime` = nil(화살 없음). 맨손이면 주먹 규칙 그대로 `Targets` 1, 같은 `Style`. 클라이언트: 펫(내 `EquippedPet`)이 각 대상에게 뛰어가 박치기하고 돌아온다. 펫이 아직 없으면(지급 전 한 틱) 주먹 연출로 대신(검수 결정).
2. Fx `Release`(기존 원격): 조련사면 `Style = "PetDash"`, `ContactDelay = 0.35`, `LaunchDelay` = nil. `Pos`·`Radius`는 궁수 Q와 같다(대상 주변). 클라이언트: 화살비 대신 펫 돌진.
3. 펫 따라다니기(PET-3): 모든 플레이어의 `EquippedPet`·`PetLv`·`PetForm` 속성을 읽어 `CustomModels.PetBabySlime`(0.35배)을 따라다니게. 대상 폴더 밖에.
4. 직업 카드·내 캐릭터 창: `Config.ClassName(class, faction)`과 `Config.ClassCard(class, faction)`을 쓰기(장인 궁수 = 펫 조련사 글). 무기 이름·아이콘은 `Config.WeaponName/WeaponArtKey(tier, class, faction)` 그대로(진영을 꼭 넘기기).
5. 무료 변경권: 베타는 변경권 상품을 팔지 않지만(A23-28), 이 1장은 Lv5 이상에서 직업 변경 창의 '변경권 쓰기'로 레벨을 유지하며 바꿀 수 있어야 한다(Lv5 미만은 원래 무료 변경이 레벨을 유지하므로 알림도 BecameFree '무료로 바꿀 수 있어요')(`ClassTickets` 속성 ≥ 1이면 그 선택지가 보임 — Panels 1608·1691이 이미 이 속성을 읽음, 베타에서 숨긴 상점과 별개인지 확인).
6. 알림 문구(서버가 보냄, ~~KO/EN~~ 영어만 A23-48): `Config.Tamer.Text.PetGot`, `Became`.
