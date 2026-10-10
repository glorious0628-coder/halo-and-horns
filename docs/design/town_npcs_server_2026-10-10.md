# 빛 마을 NPC 몸 (서버) — 게임성 개발 3, 2026-10-10

검수 점검표 #22·#24~#27·#30·#34. 코드: `src/ServerScriptService/TownNpcs.luau` (MapBuilder `ensureStoryNpcs`가 부름), 설정 `Config.TownNpcs`, 대화 연결 `StoryQuestService.TalkToNpc`. 시험: `tools/test_town_npcs.py`(122 확인, 변이 74/74), `tools/test_town_quests.py`의 "npc-talk" 묶음(변이 9개 포함, 총 145/145).

## 누가 어디에
| Id | 무엇 | 자리 (X, Z) | 태그 / 속성 / 프롬프트 |
|---|---|---|---|
| Bright | 이야기 NPC | (18, -452) | `StoryNpc`, NpcId=Bright, "Talk" 프롬프트(G), StoryNpcId=Bright |
| Gleam | 이야기 NPC (Sir Gleam) | (-10, -372) | 위와 같음, NpcId=Gleam |
| Folk1~4 | 주민 (서 있기만) | 광장 단(Y 20): Folk1 주스(34,-546), Folk2 꽃집(-34,-584), Folk3 빵집(-34,-546) — 각자 가게 앞 3스터드, Folk4 분수 옆(16,-560) | `TownFolk`, FolkId=Folk1~4, 프롬프트 없음 |
| PotionHalo | 빛 마을 물약 상인 | 물약 가게 앞(34, -584), 광장 단 | `PotionMerchant`, HHC_PotionMerchant, 프롬프트=`Config.Vitals.PotionMerchantPrompt`. **Enabled=false** (개발 2의 ShopService 다중 상인이 들어오면 켠다) |
| Otto | 대장장이 (Crossroads, 장식) | 모루 뒤 4 | 가게 프롬프트는 모루에 그대로 |

- 몸은 기본 HumanoidDescription(옷 색만 다름, 가리는 옷·새 그림 없음)으로 만들고 앵커·충돌 없음·스크립트 없음. 나중에 재제작 P4 모델이 오면 같은 Name으로 갈아 끼운다(같은 이름이 이미 있으면 재사용하고 태그·속성·프롬프트만 고친다, 자기 것(HHC_TownNpc)만 다룬다).
- 높이: X/Z만 설정에 있고 Y는 위에서 아래로 쏘는 ray로 찾는다. 경사·벽이면 "땅 없음" → 그 NPC는 건너뛰고 경고. **기대 높이(`Y`)가 있는 칸(광장 단 20)은 그 ±`YTol`(4) 안의 바닥만 땅으로 본다**: 지붕·발코니·받침대 윗면·벽 옆면은 그 아래로 ray를 다시 쏜다(0.5 아래부터, 최대 `RayTries` 8번). 기대 높이가 없는 칸(브라이트·글림)은 처음 맞은 바닥이 땅.
- 몸 만들기(`CreateHumanoidModelFromDescription`)가 실패하거나 준비가 실패하면 `RetryDelay`(5초) 뒤 다시, 모두 `Retries`(3)번까지(땅이 없거나 이름이 남의 것이면 다시 안 함). 끝내 못 만들면 "given up" 경고.
- 자리 근거: `docs/design/halo_layout_plan_2026-10-10.json`(가게 4곳: 빵집 (-44,-546)·주스 (44,-546)·꽃집 (-44,-584)·물약 (44,-584), 가게 앞면은 x ±37). 시험이 이 json을 읽어 각 사람이 자기 가게 앞 2~8스터드에 서 있는지 본다.
- `MapBuilder.Build`는 멈추지 않는다: 아바타 만들기는 Build가 끝난 뒤 한 작업에서 한다.

## 대화 연결
- 프롬프트가 눌리면(`ProximityPromptService.PromptTriggered`) 서버가 속성 `StoryNpcId`를 읽어 `StoryQuestService.TalkToNpc(player, npcId)`를 부른다. `Config.RateLimits.StoryAction`(0.4초)에 한 번만(속도 제한 "StoryNpcTalk", 사람마다).
- `TalkToNpc`는 Main → 하위 퀘스트(새것부터) 순서로 "Panel 단계이고 `step.Npc == npcId`이고 그 NPC 곁(NpcRange 16)"인 첫 줄의 대화를 연다. 보상 받기([Claim]) 단계와 클래스 고르기 전은 건너뛴다. 맞는 줄이 없으면 아무 일도 없다.
- 개발 1(클라): 프롬프트는 서버가 처리한다. 열 줄이 없을 때 프롬프트를 숨기는 것, 다이아몬드·'!'·말풍선은 클라 몫.
- 개발 2: 주민 반응 대사는 `TownFolk` 태그와 FolkId로 붙인다. 물약 상인은 `Config.Vitals.PotionMerchantTag`(있으면)로 태그하고, 개발 2의 ShopService 다중 상인(dev2-halo2 #34)이 main에 들어오면 `PotionHalo`의 `Enabled = false`만 지운다.
- Sir Gleam: H3 첫 카드('Talk to Sir Gleam')에 `Npc = "Gleam"`를 붙였다(프롬프트 G로 열림). 선택 카드(4단계)는 NPC 없이 마을 안에서 저절로 열리므로 그대로.
