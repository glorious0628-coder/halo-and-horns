# 영상 효과음 기록 (촬영 편집)

유튜브 수익 영상이라 효과음마다 출처·라이선스를 적는다. 소리 파일은 `build/devlog/sfx/`(git 밖).
쓰면 안 되는 것: Roblox Creator Store 오디오(로블록스 안에서만), 출처 모르는 무료 모음, NC·표기 못 하는 CC-BY, 유명 게임·만화 소리.

## 내려받은 팩 (사용자가 촬영 편집 채팅에서 직접 OK, 2026-10-06)

| 팩 | 파일 | 받은 곳 | 라이선스 | 날짜 |
|---|---|---|---|---|
| Kenney **Impact Sounds** 1.0 (130개) | `kenney_impact-sounds.zip` 800,850 B | https://kenney.nl/assets/impact-sounds (공식 페이지 다운로드 링크) | CC0 1.0 (팩 안 License.txt: 개인·교육·상업 무료, 표기 선택) | 2026-10-06 |
| Kenney **Interface Sounds** (100개) | `kenney_interface-sounds.zip` 834,536 B | https://kenney.nl/assets/interface-sounds (공식 페이지 다운로드 링크) | CC0 1.0 (팩 안 License.txt) | 2026-10-06 |

## 영상에 쓰는 소리 (`tools/devlog_build.py` `SFX_FILES`)

| 이름 | 쓰는 곳 | 파일 | 출처 · 라이선스 |
|---|---|---|---|
| boom(쿵) | 호박 대왕 등장·첫 장면·빨간 X | `impact/Audio/impactSoft_heavy_000.ogg` + 우리 합성 저음 | Kenney Impact Sounds · CC0 / 직접 합성 |
| hit(퍽) | 대왕이 때림·흔들림 컷 | `impact/Audio/impactPunch_heavy_002.ogg` | Kenney Impact Sounds · CC0 |
| pop(뿅) | 3D 모델 등장·변신 | `interface/Audio/drop_002.ogg` | Kenney Interface Sounds · CC0 |
| card(톡) | 팀 카드 일곱 장 등장 | `interface/Audio/drop_003.ogg` | Kenney Interface Sounds · CC0 |
| ding(딩) | 사탕·끝 화면 | `interface/Audio/confirmation_002.ogg` | Kenney Interface Sounds · CC0 |
| tick(틱) | 동전·5분 칩 | `interface/Audio/tick_004.ogg` | Kenney Interface Sounds · CC0 |
| whoosh(휙) | 컷 전환 | 직접 합성(`synth_sfx("whoosh")`, 잡음 필터) | 우리가 만듦 · 저작권 걱정 없음 |

크기: 내레이션보다 약 -18~-11 dB(`SFX_GAIN`), 전체는 -14 LUFS / -1.5 dBTP로 맞춘다. 크레딧은 의무가 아니지만 설명란에 "Sound effects: Kenney (kenney.nl, CC0)" 한 줄을 넣는다.

## 게임 효과음 (이미지 개발, 품질 ①, 2026-10-06 · 검수 효과음 표 lines_pack_2026-10-06 §6)

게임 소리 32개는 위의 Kenney 두 팩(CC0)과 우리가 직접 합성한 소리만 쓴다. Roblox 라이브러리 소리는 없어서 개발 일지 영상에도 그대로 쓸 수 있다.
- 파일: `art/sfx/<이름>.ogg` (48 kHz 모노, 가장 큰 100 ms가 RMS -18 dBFS, 최고점 -3 dBFS 아래, 전투 소리는 150 Hz 아래를 덜어 냄). 만든 도구: `tools/sfx_game.py final`.
- 소리마다 원본 파일·속도·섞은 방법: `art/sfx/sources.json`. 후보 64개 모양 비교: `art/review/sfx_candidates_2026-10-06.jpg`.
- 유명 게임·만화 소리를 흉내 내지 않았다(동전은 종소리 한 음, 레벨 업은 도-미-솔-도 아르페지오, 거위는 직접 합성).

| # (§6) | 이름 | 쓰는 곳 | 원본 | 라이선스 |
|---|---|---|---|---|
| 1 | SwingWarrior | 전사 휘두르기(맨손 1.3배) | 직접 합성(짧은 바람 0.18초) | 우리 것 |
| 2 | SwingMage | 마법사 쏘기 | 직접 합성(올라가는 마법음 + 반짝) | 우리 것 |
| 3 | SwingArcher | 궁수 쏘기 | 직접 합성(활줄 퉁 + 화살 바람) | 우리 것 |
| — | SwingTamer | 펫 조련사 휘파람(표에 없음, 펫 공격용) | 직접 합성('휘-휙' 두 번, 2026-10-07 사용자 B) | 우리 것 |
| 4 | HitSoft1 · HitSoft2 | 맞힘 약(슬라임·유령·호박) | 2026-10-07 사용자 '말랑 B': Kenney Impact `impactSoft_medium_001` / `impactSoft_medium_003`(포화) + 직접 합성 물컹 | CC0 + 우리 것 |
| 5 | HitHeavy1 · HitHeavy2 | 맞힘 강(고블린·우두머리·치명타), #27 내가 세게 맞음도 같이 씀 | Kenney Impact `impactGeneric_light_002`+`impactPunch_medium_000` / `impactPunch_medium_001`+`impactGeneric_light_000` (주먹은 150 Hz 하이패스 + 포화) | CC0 |
| 6 | KillPop | 처치 '뽕' | Kenney Interface `drop_002` | CC0 |
| 7 | ComboCoin | 연속 처치 동전(한 음씩 올라감) | 직접 합성('동전 두 개' 종 두 음, 2026-10-07 사용자) | 우리 것 |
| 8 | ComboMilestone | 콤보 기념 x10·25·50·100 | Kenney Interface `confirmation_003` | CC0 |
| 9 | LevelUp | 레벨 업 팡파르 | 직접 합성(도-미-솔-도 종 + 반짝) | 우리 것 |
| 10 | WindowOpen | 창 열기 | Kenney Interface `maximize_009` | CC0 |
| 11 | WindowClose | 창 닫기 | Kenney Interface `minimize_009` | CC0 |
| 12 | Deny | 안 돼요 | 직접 합성('어-어' 두 음) | 우리 것 |
| 13 | AutoOn | 자동 켜기 | 직접 합성(삑삑 올라감) | 우리 것 |
| 14 | AutoOff | 자동 끄기 | 직접 합성(삑삑 내려감) | 우리 것 |
| 15 | Purify | 정화 '찰랑' | 직접 합성(반짝이는 종소리) | 우리 것 |
| 16 | Devour | 삼킴 '꿀꺽' | Kenney Interface `bong_001`(0.9배) + `drop_004`(0.75배) 섞음 | CC0 |
| 17 · 17b | KingBell | 호박 대왕(0.9~0.95배)·유령 왕(1.0~1.05배) 등장, 같은 파일 | Kenney Impact `impactBell_heavy_000` + Interface `maximize_006` 섞음 | CC0 |
| 18 | GooseHonk | 거위 '꽥' | 직접 합성(꽥꽥 0.15초×2) | 우리 것 |
| 19 | QuestDone | 퀘스트 완료 | Kenney Interface `confirmation_001` | CC0 |
| 20 | GoldPickup | 처치 밖 골드(보상·금고) | 직접 합성('동전 두 개', ComboCoin과 같은 파일, 2026-10-07 사용자) | 우리 것 |
| 21 | ScrollSuccess | 주문서 성공 | Kenney Interface `confirmation_004` + `glass_004` 섞음 | CC0 |
| 22 | ScrollFail | 주문서 실패('아쉬워') | Kenney Interface `back_002` | CC0 |
| 23 | Tap | 버튼 누름 | Kenney Interface `select_002` | CC0 |
| 25 | SkillHalo | X 스킬 빛 층 | Kenney Interface `glass_005` | CC0 |
| 26 | SkillHorns | X 스킬 뿔 층 | Kenney Interface `bong_001`(1.5배 포화 + 3배) 섞음 | CC0 |
| 28 | Potion | 물약 마시기 | Kenney Interface `glass_003` | CC0 |
| 29 | QuestNew | 새 퀘스트 받기 | Kenney Interface `select_003` | CC0 |
| 30 | RankDown | 내 편 점수 내려감(작게) | Kenney Interface `back_004` | CC0 |
| — | TalkBlip | 대화 글자 '삑'(품질 ②, 표에 없음) | 직접 합성 | 우리 것 |

#14·#17b·#24·#27은 다른 줄의 파일을 다시 써서 따로 올리지 않는다(#24 스킬 시전 = 내 직업 휘두르기 0.85배).

## 올린 기록 (2026-10-07, 이미지 개발)
- 32개 모두 Roblox Creator Hub(계정 Darugi_S2, 사용자 크롬)에서 하나씩 올림. 이름 `HH SFX <키>`, 설명에 출처(Kenney CC0 / 직접 합성).
- **올린 형식: wav**(art/sfx/*.ogg 원본을 ffmpeg로 16비트 PCM wav로 풀어서 올림, 소리 내용은 같음). 크롬 도구가 .ogg 파일 종류를 못 넘겨 Creator Hub가 "잘못된 형식"으로 거절했기 때문(검수 OK).
- 업로드마다 "오디오 업로드 라이선스 계약" 동의 칸 체크: 사용자 허락("응, 대신 체크해도 돼", 검수 전달 2026-10-07).
- 공개 범위: 제한(본인·허락된 체험만). 크리에이터 상점 배포는 안 함.
- id: `art/sfx/asset_ids.json`, 게임 코드 `Config.Audio.Files`. Studio(UiSandbox)에서 32개 모두 불러오기 성공(PreloadAsync Success, 길이 0.04~1.5초).
- 이후 소리(새로 만들기·올리기·Audio.luau·크기 조절)는 게임성 개발 1 몫(사용자 결정 2026-10-07).

## 3차 후보 (게임성 개발 2, 2026-10-07 — 사용자: 마법 쏘기·활 쏘기·퍽·치명타 '별로', 활은 "팅 말고 슉")

검수가 목표 모양(파형 + 스펙트로그램, `art/review/sfx_shapes_2026-10-07.png`, `py tools/sfx_game.py shapes`)을 정하고, 그 모양에 맞춰 새로 만든 12개 중 2개씩 골라 듣기판에 올렸다: https://claude.ai/artifact/YZjYSiYdK8RHXoL2Z9DmiR. 8개 모두 직접 합성(남의 소리 없음)이다. 사용자가 고르면 위 표의 줄을 바꾼다. 2차 후보(d·e·f)는 목표 모양 전에 만든 것이라 쓰지 않는다.

| 후보 | 듣기판 이름 | 원본 | 라이선스 |
|---|---|---|---|
| SwingMagic g | 마법 쏘기 1 반짝 줄 | 직접 합성(2→5.6 kHz로 휘는 사인 줄 + 반짝 알갱이, 부드러운 시작) | 우리 것 |
| SwingMagic h | 마법 쏘기 2 방울 구름 | 직접 합성(2→6 kHz로 오르는 작은 종 44개 + 바람 띠) | 우리 것 |
| SwingBow g | 활 쏘기 1 날카로운 슉 | 직접 합성(좁은 바람 띠 4.8→1.3 kHz) | 우리 것 |
| SwingBow h | 활 쏘기 2 굵은 슉 | 직접 합성(넓은 바람 띠 3.8→0.95 kHz) | 우리 것 |
| HitThud g | 퍽 1 짧은 퍽 | 직접 합성(쿵 175→62 Hz + 650 Hz 몸통 + 3 kHz 딸깍) | 우리 것 |
| HitThud i | 퍽 2 단단한 퍽 | 직접 합성(쿵 220→75 Hz + 700 Hz 몸통 + 3.5 kHz 딸깍) | 우리 것 |
| HitCrit g | 치명타 1 맑은 쨍 | 직접 합성(퍽 1 + 3.3–7.6 kHz 쇠 울림) | 우리 것 |
| HitCrit i | 치명타 2 쨍쨍 | 직접 합성(퍽 1 + 쇠 울림 두 번) | 우리 것 |

## 게임 효과음 4차 — Firefly 생성 (소리 만들기, 2026-10-07)

사용자 결정(A23-67): 소리 만들기 세션이 Adobe Firefly '효과음 생성'으로 만든다. 모든 소리를 다시 만든다(사용자 "그대로 두는 것도 다시 다!").
기준은 `docs/design/sound_spec_2026-10-07.md`(검수, 9d911c2)와 `tools/sfx_spec.json` / `tools/sfx_check.py`.
- **만든 곳:** firefly.adobe.com 효과음 생성(사용자 Adobe 계정, 앱 안 브라우저). 1번 생성 = 10크레딧, 변형 4개, 길이 1초(PowerUp 1.5초).
  Adobe 안내: Firefly 모델로 만든 결과물은 상업용으로 써도 안전. 유명 게임·브랜드 이름은 프롬프트에 넣지 않았다.
- **크레딧:** 72번 × 10 = 720 (11/4 초기화): 1번 묶음 35번, 2번 묶음 18번, 3번 묶음(할로윈) 7번, 4번 묶음 12번(검수 '4번은 시작하지 마'가
  대기열에 있어 늦게 도착하기 전에 만듦, 아직 고르지 않음). 계정은 이미지 세션과 같이 써서, 4번 묶음 직전 화면 잔액 8,750 → 지금 약 8,630.
  사용자 "크레딧은 걱정마슈", 검수 묶음 OK.
- **프롬프트:** `art/prompts/SFX_<키>_<번호>.txt` 72개.
- **원본:** Firefly 생성 기록에서 내려받은 WAV 48 kHz 16비트 스테레오 288개(`build/sfx_firefly/raw`, git 밖, 사용자 OK "이번 세션 계속 받아").
  애셋 id·sha256은 `art/sfx/cand/firefly_r4.json`, 받는 도구 `tools/sfx_fetch.py`.
- **우리 손질:** 설계서 검사기의 판정을 목표로 원본마다 여러 자리·길이·고역/저역 통과를 시험해 가장 잘 맞는 자르기를 남김
  (`tools/sfx_cut.py`). 48 kHz 모노, K 가중 가장 큰 100 ms = -17 LUFS, 최고점 -2.5 dBFS 아래.
- **Firefly가 못 맞춘 소리(A23-67 순서대로 Kenney → 합성, `tools/sfx_make.py`):**
  - 동전 ComboCoin k*: Kenney Impact `impactMetal_light_000`(CC0)을 두 번(설계서 레시피, 좋아했던 '동전 두 개' 방향, 복사 아님).
  - 말랑 HitSoft k*: Kenney Impact `impactSoft_medium_002` / `_004`(CC0, 포화) + 우리 합성 젤리 덩어리(새 값) + 폰용 작은 '뽀'. kC는 Firefly 말랑 + 합성 덩어리.
  - 치명타 B HitCrit sB*: 금속 없는 층 = 우리 합성 '팡' + 떨어지는 별 알갱이 + '징'(설계서 B 레시피).
  - 빛 마법 후보 일부에는 우리 합성 '샤랑'(두 부분음, 22 ms 감쇠)을 아주 얇게 얹었다.
- **2·3번 묶음 레시피(`tools/sfx_recipes.py`, 이름 s* = 합성, k* = Kenney):** Firefly는 음높이·리듬 규칙(동전, 마림바, 종, '어-어', 고무 거위)을
  못 맞춰서 설계서 '합성 방법' 칸대로 만들었다. 쓴 Kenney 파일(모두 CC0 1.0, 길이·속도·필터를 바꿔 새로 섞음):
  - Impact Sounds: `impactMetal_light_000/001/004`(GoldPickup kA), `impactWood_light_000`(SkillHorns '토독'),
    `impactBell_heavy_003` 2.0배(두 왕의 같은 왕 종), `impactWood_medium_002` 1.3배(호박 왕 '뻥'), `impactGlass_light_003` 2.4배(사탕),
    `impactGlass_medium_001`(유령 왕 유리), `footstep_grass_001` 1.6~1.8배(거위 날갯짓).
  - Interface Sounds: `switch_002`(AutoOn/AutoOff/Equip 딸깍), `glass_002`(거위 금 반짝).
  - 나머지(동전·종·마림바·삼각파·고무 거위 포먼트·바람·거품·불꽃 잡음)는 우리 합성. 진짜 동물 녹음·유명 게임 소리 흉내 없음.
- **장면 렌더:** `tools/sfx_scene.py`(실제 휘두름 → 타격 → 처치 → 동전 타이밍, 설계표 볼륨). 추천 조합 장면과 폰판을
  `art/review/sfx_scene_2026-10-07/`에 둔다.
- **시트·듣기판:** 공식 검사기 시트 `art/review/sfx_check_r4b_2026-10-07/<키>.png`(+ `summary.json`), 검수 듣기판
  https://claude.ai/artifact/EEwW3ounewa6BWPrFMFD2P . 후보 파일 `art/sfx/cand/*.wav`. 4차 첫 판(개발 2 모양 기준) 시트
  `art/review/sfx_firefly_2026-10-07*.png`은 기록으로만 둔다.
- **검수 고름(2026-10-07):** 1번 묶음은 장면 렌더 뒤 확정(화살 2-4, 빛 3-4, 뿔 1-1, 퍽 3-2, 치명타 sB3, 동전 kA, 말랑 kB,
  PowerUp 1-2, Jump 2-2), 2·3번 묶음은 추천 그대로 확정. 게임용 파일 32개 = `art/sfx/<키>.wav`(후보를 바이트 그대로 복사,
  `tools/sfx_final.py`). 키마다 sha256·출처·라이선스(Firefly / 우리 합성 / Kenney CC0 파일 이름)·볼륨·바꾸는 옛 파일은
  `art/sfx/picks_r4.json`. Purify는 설계서대로 두 버전(Purify, Purify_b)을 번갈아 쓴다.
- **업로드: 아직(다음 계정 1순위).** 올리면 id를 `art/sfx/asset_ids.json` "ids"와 이 절에 적고, 개발 1이 연결한 뒤 옛
  `art/sfx/*.ogg`를 지운다.
