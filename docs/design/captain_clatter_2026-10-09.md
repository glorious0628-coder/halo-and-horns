# Captain Clatter — 서버 계약 (게임성 개발 2, 2026-10-09)

근거: `docs/design/content_beyond_10min_2026-10-08.md` §2 J·FB, §3 TOP ④ (검수 OK 2026-10-09). 가지 `dev2-clatter`.

## 1. 무엇이 들어갔나 (서버)

| 무엇 | 값 | 어디 |
|---|---|---|
| 보스 종류 | `CaptainClatter` "Captain Clatter", 유적, HP 20000, 공격 30, XP·Gold 3900(기여자마다), 크기 2.2, 해골 기사 모델·동작 빌림(`ModelFrom`/`AnimFrom = "SkeletonKnight"`), 보상 자격 A23-27(직접 3번 + **피해 몫 2%**, 검수 2026-10-09). 3번 이상 때렸지만 2% 미만이면 **XP·골드 15%만**(`MinorShare`, `info.Minor`: 드롭·무기·배지·칭호·왕관전 점수·카드 없음) | `Config.MonsterTypes` |
| 일정 | 시작 5분 뒤 첫 자리 → 나온 때부터 20분마다, 유적에 준비된 사람이 있을 때, 6분 머묾. 자리는 `ClatterSpawn` 표시(검수 도구) → 없으면 유적 보통 스폰 자리 | `Config.FieldBosses.Clatter` |
| 드롭(기여자마다) | Knight Crest ×3(100%), Enh30 20%, Enh10 5%, HP·MP 물약 50%, 무기 T5 3%·T6 0.5%(레벨 모자라면 Crest +2) | `Config.Loot.Tables.CaptainClatter` |
| 주간 배지 | 그 주 첫 처치에 Captain's Badge 1개. 받지 않은 주는 최대 2개까지 쌓임. 가방이 꽉 차면 다음 처치로 미룸 | `Weekly`, 저장 `data.FieldBoss.Clatter = { Kills, Week, Owed }` |
| 칭호 | Clatter Stopper(1번) · Clatter Stopper 10 · Clatter Stopper 50 | `Titles`, `Config.TitleDefs` |
| 왕관전 | 기여자마다 개인 +20, **진영 풀에는 한 번 처치에 진영별 20만**(`AddPoints(p, 20, 20 / 같은 편 기여자 수)`, CR-M18 방식, 검수 2026-10-09; 한 편만 있으면 포위전 점수로 셈, 중립은 0) | `War = 20` |
| 편별 피해 몫 | `KingDefeat` Fx에 `Share = { Halo = %, Horns = % }`(합 100, 아무 편도 안 때렸으면 없음) | MonsterService `rec.FactionDamage` |
| 마무리 카드 | [Let him rest] Enh70 ×1(가방이 꽉 차면 Worth 300골드) / [Count the old treasure!] 300 은행 골드. 같은 크기, 점수 A23-58 | `Config.Finisher.Cards.CaptainClatter` |
| 알림 | Appear(토스트) "Captain Clatter is on patrol in the ruins!", Defeat "Captain Clatter sat down at last. \"Is my shift over?\"", Leave "Captain Clatter marched off. Still on duty!" | `Config.Announce` |
| 말풍선 | Spot "HALT!!"/"Who's next?", Hit "CLATTER!"/"Bones! Ow!", Low "Nap time…"/"Off duty?", Idle "300 years…"/"Still here." | `Config.Barks.Lines` |
| GameState | `ClatterNextAt / ClatterActive / ClatterEndsAt` | `Net.GameStateDefaults` |
| Studio | `DebugCommand:Invoke("Player1", "Clatter")` — 지금 바로 나옴 | Main |

## 2. 마무리 카드 데이터 모양 (2026-10-09부터)

- `Config.Finisher.Cards[kind] = { Help = { Item, N, Worth? }, Tickle = { Gold }, Text = { Title, Help, Tickle, HelpDone, TickleDone } }`.
- 공용 글(점수 줄, 힌트)만 `Config.Finisher.Text`에 남았어요. 앞서 알린 `Text.Title[kind]`는 **`Cards[kind].Text.Title`로 옮겼어요.**
- FinisherService 함수 모양은 그대로예요(보스별 차이는 데이터만). 개발 3의 공용 선택 카드(CC)로 옮길 때 이 표를 그대로 쓰면 돼요.
- 점수는 아직 `ScoreBudget`이에요. 하루 장부(Deeds)가 생기면 바꿀 자리에 TODO 한 줄을 남겼어요.

## 3. 개발 1 몫 (클라)

1. 칩 'Captain Clatter in m:ss': `ClatterNextAt / Active / EndsAt`, **Lv `Config.FieldBosses.Clatter.MinLevel`(25) 이상만** 보이기.
2. `MonsterMotion`에 `def.AnimFrom`(없으면 `ModelFrom`) 별칭 1줄.
3. 마무리 카드 글은 `Config.Finisher.Cards[card.Kind].Text`에서 읽기.
4. 처치 뒤 비율 줄: `KingDefeat` Fx의 `Share`가 있으면 "Halo 62% · Horns 38%".
5. 아이콘(이미지 생성 2 → 이미지 개발): `IconCaptainBadge`, 말풍선 `BarkBubbleCaptainClatter`(없는 동안 해골 말풍선), 몬스터 머리 아이콘(없는 동안 해골 기사 것).

## 4. 아직 아님 / 확인할 것

- 혼자·셋 실측(시험 주 10/25~30): 6분 안에 혼자 못 잡으면 머묾 8분.
- 카드 값 300골드 = Enh70 1장은 제안값이에요(검수가 정해 주세요).
- 오토의 의뢰 T6 줄(배지 사용)은 개발 3(TOP ⑤).
