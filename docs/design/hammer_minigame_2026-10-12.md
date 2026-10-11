# 망치질 미니게임 설계 (게임성 개발 4, 2026-10-12) — 참고 게임 검색 먼저(A23-133)

근거: SPEC A23-56(줄어드는 고리가 가운데 원에 딱 맞을 때 클릭/탭, Perfect/Great/Good/Miss, 넉넉한 판정, 실패해도 재료 안 잃음, 자동 전투·매크로 불가, 품질 차이 작게), A23-127(제작은 장인만), A23-133(동작은 참고부터), A23-130(설명 글 줄이기), A23-98(PC 먼저). 서버 쪽 = 게임성 개발 3(CraftService, 두드림 간격 검사), 설계 `crafting_market_2026-10-11.md` §4(Good +0 / Great +1 / Perfect +2, 약 10초, 대기 타이머 없음).

## 1. 찾아본 참고 (무엇을 가져오나)
| 참고 | 본 것 | 가져오는 것 |
|---|---|---|
| **The Forge**(Roblox, 2025~, 베타) | 망치 단계 = 큰 고리가 작은 안쪽 원으로 줄어들고 맞을 때 클릭. 판정 Bad(빨강)·Ok·Good·Great·Perfect(금). 여러 미니게임 중 망치 단계가 품질을 가장 크게 정함. 공략들이 "입력이 살짝 늦게 먹으니 일찍 눌러라"라고 함 | 같은 모양(줄어드는 금빛 고리 → 가운데 원), 판정 글자 색, **입력 늦음은 우리가 보정**(플레이어가 배우게 하지 않음) |
| **Jacksmith**(웹, 아이용) | 칼날의 점마다 줄어드는 고리가 겹칠 때 톡 | 아이도 바로 아는 "고리가 닿을 때 톡" 하나만 |
| **osu!**(리듬) | 고리 판정 창: OD5 기준 300 = ±50ms, 100 = ±100ms, 50 = ±150ms(공식 위키 공식 80−6×OD 등) | 숫자 감각 — 우리는 더 넉넉하게(아이·폰·네트워크) |
| Mabinogi·Fable 대장장이 | 막대/게이지 안 초록 구간에 맞추기, 리듬 망치 | 몇 번(5번) 두드리고 합쳐서 품질 |
| Wartales 대장장이 | 같은 결과에 다른 품질 → "운"으로 느껴져 불만, 반복이 지루하다는 불만 | **품질은 타이밍만으로 정함(무작위 없음)**, 한 번에 짧게(약 6초) |
| 타격감 글들(hit stop·flash·shake) | 맞는 순간 수십 ms 멈춤, 50~100ms 번쩍, 작은 흔들림, 불꽃 20~30개, 소리는 판정마다 음높이 다르게, 20ms 넘게 어긋나면 늦게 느낌 | Perfect일수록 크게(멈춤·번쩍·불꽃·소리), Good은 작게. 흔들림은 설정 '화면 흔들림' 끄면 없음 |
| 망치 동작 참고(애니메이션 분해, 80.lv 타격 원칙) | 들기(예비) → 위에서 잠깐 멈춤 → 2~3프레임에 내려침 → 맞는 순간 짧은 반동 → 돌아오기, 한 번 0.8~1.2초 | 캐릭터 몸짓 박자(§4) |

## 2. 규칙 (화면)
- 장소: 장인 길드 모루(G). 제작 창에서 레시피 고르고 [Forge] → 화면 가운데 모루 위 달군 쇠 그림 + 고리.
- **5번 두드림.** 한 번 = 바깥 금빛 고리가 1.2초 동안 가운데 원으로 줄어듦 → 맞을 때 클릭(PC 왼쪽 클릭 또는 Space) / 폰 아무 데나 탭. 누르면 바로 다음 고리(0.35초 쉼). 전체 약 8초.
- **판정(넉넉, 입력 늦음 보정 +40ms):** Perfect ±70ms · Great ±130ms · Good ±200ms · 그 밖 Miss. 아무것도 안 누르고 고리가 다 줄면 Miss로 넘어감(멈추지 않음).
- **점수:** Perfect 3 · Great 2 · Good 1 · Miss 0, 5번 합 15점 만점. **13 이상 = Perfect(+2), 9 이상 = Great(+1), 그 밖 = Good(+0).** Miss가 많아도 물건은 +0으로 완성, 재료 안 잃음(A23-56).
- 무작위 없음: 같은 타이밍이면 같은 결과(Wartales 불만).
- 글: 판정 단어 4개(Perfect/Great/Good/Miss)와 끝 결과 한 줄("+1 Iron Sword")만. 설명 카드·팁 없음(A23-130) — 고리 자체가 설명.
- 자동 전투 중엔 시작 안 됨(서버 검사), 창이 열려 있는 동안만 입력 받음.

## 3. 서버와 계약 (개발 3에 제안)
- c->s `CraftStart(recipeId)` → 서버: 장인·레벨·재료·골드·모루 거리 확인 → 재료를 **잠깐 맡아 둠**(끝나거나 시간 넘으면 정산) → s->c `CraftSession { Id, Recipe, Strikes = 5, Ring = 1.2, Rest = 0.35, StartAt = 서버 시각 + 0.8 }`.
- c->s `CraftFinish(Id, hits)` — hits = 5개 숫자, 각 고리에서 누른 때의 어긋남(ms, 누르지 않음 = false). 서버가 다시 점수를 셈(클라 점수는 안 믿음) → 결과 `CraftResult { Id, Tier, Plus, Grades = { "Perfect", … } }` + 가방(Spares) 넣기.
- **매크로 막기(서버):** 받은 때가 StartAt + 5×(Ring+Rest) − 여유보다 이르면 거절, 세션 하나에 Finish 한 번, 세션 수 제한(분당 몇 번), 5번이 모두 0ms·모두 같은 값이면 사람 아닌 것으로 보고 Good 처리(+0)·기록. 타이밍은 클라가 재므로 '완벽한 매크로'를 다 막지는 못함 — 품질 차이가 +0~+2로 작아(A23-56) 감수.
- 시간 넘음(StartAt + 20초 안에 Finish 없음): Good(+0)로 완성.

## 4. 그림·소리·몸짓 (먼저 필요한 것)
- **그림(디자인 검수 → 이미지 생성 2):** 금빛 고리(얇은 원 테, 투명 PNG), 가운데 원 표적, 달군 쇠·모루 윗면(위에서 본 2D), 판정 글자는 TextLabel(그림 아님). 그림 전까지는 UIKit 대체(UICorner 원 + UIStroke) — 새 기능 화면 예외 범위.
- **소리(소리 만들기):** 쇠 치는 소리 3단(Good·Great·Perfect 음높이 다르게), Miss 둔탁한 소리, 완성 짧은 팡파르. 맞는 순간과 20ms 안에.
- **타격감:** Perfect = 화면 멈춤 60ms + 번쩍 80ms + 불꽃 25개 + 작은 흔들림(설정 끄면 없음), Great = 불꽃 12개, Good = 불꽃 5개, Miss = 연기 한 번.
- **캐릭터 몸짓(A23-133, 참고 §1):** 누를 때마다 망치 내려침 — 들기 0.35초(고리 줄어드는 동안 미리 들어 있음) → 내려침 0.1초(누른 순간 맞음) → 반동 0.15초 → 다음 고리 동안 다시 들기. 망치 3D(대장장이 무기와 다른 '대장간 망치')는 3D 파이프라인(Tripo → Blender → 재질). 쥐기는 개발 1 쥐기 규칙(참고 → 주먹-손잡이 사진).

## 5. 만드는 순서 (개발 4)
1. 오프라인: 판정·점수 순수 함수(`CraftMini.Grade(offsetMs)`, `.Score(grades)`) + 시험(경계값 ±70/130/200, 13/9 점, Miss 넘어감, 보정 +40).
2. 화면: 고리 창(대체 모양) + 입력(PC 클릭·Space, 폰 탭) + 판정 글자 + 결과 줄, UiSandbox 사진.
3. 서버 계약 합의 뒤 CraftStart/Finish 연결, 그림·소리 오면 바꿔 끼움.

출처: [The Forge 망치 단계 공략(roonby)](https://roonby.com/2025/11/27/how-to-get-masterwork-crafting-quality-the-forge-roblox-guide/amp/), [The Forge 시작 안내(PC Gamer)](https://www.pcgamer.com/roblox/the-forge-tips/), [Jacksmith](https://www.seeles.ai/games/simulation/jacksmith-the-fantasy-blacksmith-adventure), [osu! Overall difficulty](https://osu.ppy.sh/wiki/en/Beatmap/Overall_difficulty), [Wartales 대장장이 토론](https://steamcommunity.com/app/1527950/discussions/0/3803900924524303775), [타격감: flash·shake·particle](https://eastondev.com/blog/en/posts/dev/20260521-game-feedback-feel/), [Unity hit stop 입문](https://uhiyama-lab.com/en/notes/unity/unity-game-feel-hit-feedback/), [공격 애니메이션 분해(slynyrd)](https://www.slynyrd.com/blog/2025/5/23/pixelblog-56-top-down-character-attack-animation), [타격 애니메이션 원칙(80.lv)](https://80.lv/articles/separation-compensation-principle-in-strikes-animation?amp=1), [Mabinogi 대장장이](https://wiki.mabinogiworld.com/view/Blacksmith).
