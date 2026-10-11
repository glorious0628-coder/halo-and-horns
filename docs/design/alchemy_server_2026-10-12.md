# 연금 버프 물약 서버 BuffService (게임성 개발 3, 2026-10-12)

근거: SPEC A23-133(버프 물약 = 모두 거래소에서 사서 마심, 몬스터 상대만, 3분, 한 번에 2병까지, 빠르기 물약은 베타 뒤)·A23-127(연금술사가 만듦)·A23-115·A23-75(능력치 판매 없음), `crafting_market_2026-10-11.md` §4(물약 4종 안), `craft_server_2026-10-12.md`(레시피 표·망치질), `save_v4_tables_2026-10-11.md`(Buffs 표). 코드 = 가지 `dev3-alchemy`. 스위치 `Config.Features.Tonics = false`(장인 길드 켜기와 같이, 검수).

## 1. 물약 4종 (`Config.Alchemy.Tonics`, 아이템 `Config.Loot.Items`)
| 아이템 id | 이름 | 효과(Stat × Mult) | 제작(연금술사) |
|---|---|---|---|
| MightTonic | Might Tonic | 몬스터에게 주는 모든 타격 ×1.10 (`MonsterDamage`) | A1: 제작 Lv1, 20골드, Herb 3·Jelly 5 |
| GuardTonic | Guard Tonic | 몬스터에게 받는 타격 ×0.90 (`MonsterHurt`) | A2: Lv3, 30골드, Herb 3·SlimeCore 2·CopperOre 2 |
| LuckyTonic | Lucky Tonic | 처치 드롭의 **재료 줄**만 확률 ×1.25 (`MaterialDrop`; 무기·주문서·물약·대박 줄 아님) | A3: Lv8, 60골드, Glowcap 3·Petal 5 |
| WisdomTonic | Wisdom Tonic | 몬스터 처치 XP ×1.10 (`HuntXP`; 퀘스트 XP 아님) | A4: Lv12, 100골드, Glowcap 4·GoblinTooth 5·Bone 3 |
- 아이템: `Kind = "Tonic"`, `Source = "Craft"`(오토 한 번에 팔기에서 빠짐), 아이콘 키 `Icon<id>`(이름은 디자인 검수가 정하면 바꿈).
- 레시피는 `Kind = "Item"`, `N = 1` → **병 수 = N + 망치질 +N**(1~3병). 같은 규칙이 Pet Treat(⑤) 등 다른 Item 레시피에도 적용(시작할 때 N+2 자리 확인).
- 바뀜(설계 §4 대비): SeaShell·CrystalShard(새 구역 하나만 베타) 대신 채집 약초·빛버섯.

## 2. 마시기 (c->s `UseTonic(itemId)`)
- 준비된·살아 있는 플레이어, 그 물약 1병 이상, **다른 물약이 2개 미만** 돌고 있을 때. 같은 물약을 또 마시면 **시간만 처음부터(180초)**, 겹치지 않음. 1초에 1번.
- 1병 빠짐(`LootService.TakeItem`) → `data.Buffs[id] = os.time() + 180` → 속성 `Buff_<id>` = 끝나는 서버 시각(0 = 없음, 모든 클라가 볼 수 있음) → 끝나면 0으로·저장에서 지움. 들어올 때 돌던 것은 다시 보이고 제때 끝남(저장 고치기 `Config.SanitizeBuffs`가 180초 넘는 끝을 자름).
- 거절 글은 키만: `Config.Alchemy.Text.TwoMax`·`NoTonic`. 마실 때마다 Telemetry `TonicUse`(a = 물약 id).

## 3. 효과를 거는 곳 (한 줄씩, 다른 파일)
- `CombatService.damageMonster`: `dealt *= BuffService.Mult(player, "MonsterDamage")` — 몬스터 타격이 모두 지나는 한 곳(PvP 아님).
- `CombatService.DamagePlayer`: 공격자 없음 + 몬스터 종류일 때(가드 스킬과 같은 조건)만 `amount *= Mult(victim, "MonsterHurt")`.
- `LootService.RollKill`: `info.MatMult = Mult(player, "MaterialDrop")`, `rollRows`가 재료 줄에만 곱함.
- `ProgressionService.onMonsterKilled`: 처치 XP에 `Mult(player, "HuntXP")`(2배 XP 패스와 곱).
- `BuffService.Mult(player, stat)`은 던지지 않음, 스위치가 꺼지면 늘 1.

## 4. 화면 계약 (게임성 개발 4 가방 / 개발 1 퀵슬롯)
- 가방의 Tonic 칸에 [Drink] → `UseTonic(id)`. 돌고 있는 물약은 `Buff_<id>` 속성(서버 시각 끝)으로 작은 아이콘·남은 시간.
- 퀵슬롯에 물약을 넣는 것은 QuickSlotService(개발 2)·퀵슬롯 화면(개발 1)이 `Config.QuickSlots.Items`에 Tonic을 더할 때(베타 전, 검수가 순서).

## 5. 시험 `tools/test_alchemy.py`
53 named·변이 30/30: 표·효과 숫자·레시피, 마시기 규칙(꺼짐·아닌 아이템·준비/KO·병 없음·2개 제한·같은 것 다시·병 빠짐·끝 시각·속성·만료·텔레메트리), Mult(종류별·다른 사람·꺼짐·만료·플레이어 아님), 들어올 때(돌던 것·이미 끝난 것), 원격(인자·속도), Lucky가 재료 줄만(LootService 원본으로 슬라임 처치). CombatService·ProgressionService 줄은 정적 검사.
