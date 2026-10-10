# 스킬 18개 이름·글 (게임성 개발 3, 2026-10-10, SPEC A23-116)

설계: `docs/design/skills18_2026-10-10.md`. 이 문서는 그중 개발 3 몫(Config 이름·글 + 오프라인 검사)이다. 피해·비용 숫자는 하나도 바꾸지 않았다.

## 바뀐 것 (`Config.Skills`)
- **전사·마법사·궁수의 Q·Z 6칸**에 `Halo` / `Horns` 표를 더했다. 표에는 `NameEn`·`DescEn`만 있다(문서 "한눈에 표"의 글 그대로). 숫자(Shape·Mult·MP·CD·Push/Pull·Auto)는 칸 하나에 한 벌이고 두 진영이 같이 쓴다.
- 바탕 Q·Z의 `NameEn`·`DescEn`은 지웠다. 진영이 없으면(`None`·`nil`, 진영 고르는 중) `Config.SkillDef`가 X처럼 **Halo 이름**을 돌려준다.
- `Config.Skills.Text`에 `QZHalo = "Halo: your hits heal friends"`, `QZHorns = "Horns: your hits steal HP"`를 더했다(스킬 창 진영 줄 글, X의 `XHalo`·`XHorns` 짝).
- 장인 길드(Blacksmith·Alchemist·Tamer) 아홉 이름은 그대로다.

| 직업 | 칸 | Halo | Horns |
|---|---|---|---|
| 전사 | Q | Halo Slam | Crater Smash |
| 전사 | Z | Glow Lasso | Fire Rake |
| 전사 | X | Guardian Roar | Rage Roar |
| 마법사 | Q | Star Fall | Purple Pop |
| 마법사 | Z | Birdie Bounce | Flappy Zigzag |
| 마법사 | X | Sun Circle | Hex Circle |
| 궁수 | Q | Feather Rain | Spark Shower |
| 궁수 | Z | Comet Arrow | Moon Shot |
| 궁수 | X | Light Step | Shadow Step |

## 클라이언트가 할 일 (개발 1)
- 없다. `SkillBar.defOf`는 이미 `Config.SkillDef(class, faction, slot)`을 먼저 부르고, 그 안에서 진영 표가 바탕 위에 합쳐진다. 스킬 창이 `Config.Skills.Defs`를 직접 읽는 곳이 있으면 `Config.SkillDef`로 바꿔야 한다(바탕에는 이름이 없다).
- 진영 줄은 `Config.Skills.Text.QZHalo` / `QZHorns`(Q·Z), `XHalo` / `XHorns`(X), `XArtisan`(장인)이다.

## 시험 (`py tools/test_skill_kit.py`, 113 체크, 변이 23/23)
- 18개 이름이 모두 다르고, 13글자 이하이며, 설명은 100글자 이하이고 진영에 맞다(빛 Q·Z = "heal", 뿔 Q·Z = "steal HP", X는 기존 규칙 "guarded / less damage" · "Steal MP").
- 낱말은 X 짝(Roar·Circle·Step)말고는 겹치지 않는다. 장인 길드 이름과도 겹치지 않는다.
- **새 Q·Z 12개**는 몬스터·패스·치장 이름의 낱말과 겹치지 않는다(Bat·Lava·Gold·Drop 등). 예외로 놓은 낱말은 `Star`·`Halo`·`Horns`(진영 낱말, 출석 전용 `Star Halo`) 뿐이다.
- 같은 칸의 빛·뿔 Shape·Mult·MP·CD·Push·Pull·크기·Auto가 같다. Q·Z 진영 표는 `NameEn`·`DescEn`만 가진다.
- 진영 없는 저장(`None`·`nil`)은 Halo 이름을 보인다. 옛 이름(Shockwave·Earth Cleave·Meteor·Chain Bolt·Arrow Rain·Pierce Shot)은 없다.
- 옛 이름을 찾던 시험은 고쳤다(`skill_kit_offline` NAMES, `test_skill_kit` 변이 앵커).
- 다른 시험(`aim_cone`·`skills`·`skill_learn`·`tile_reveal`·`potions`·`keys_settings`·`onboarding`·`town_quests`)도 변경 뒤 그대로 통과한다.

## 검수에게 알림
- **옛 X 이름 `Shadow Step`은 99 R$ 치장 `Shadow Horns`와 낱말 `Shadow`가 겹친다**(설계 문서의 겹침 확인 목록에는 Lava·Bat·Gold·Drop만 있다). X는 A23-116에서 바꾸지 않아 시험은 새 Q·Z에만 이 규칙을 건다. 바꾸려면 X 이름 한 곳(`Config.Skills.Defs.Archer.X.Horns.NameEn`)이다.
- 공정 결정 1·2(빛 자기 회복 상한 3%/3초, Q 치유 중심)는 서버 숫자라 이 작업에 넣지 않았다. 정해지면 DescEn 두 줄("...Heals you and friends.")만 바꾸면 된다.
