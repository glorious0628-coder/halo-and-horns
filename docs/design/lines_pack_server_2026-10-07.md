# 대사 묶음(lines_pack 63e661f) 서버 쪽 — ⑫ 대왕 9일 · ⑪ 다섯 명 이름 (게임성 개발 2, 2026-10-07)

설계: `docs/design/lines_pack_2026-10-06.md` §4(⑫)·§1(⑪). 게임 글은 영어(A23-48). 검사: `py tools/test_banter.py`(104검사, 변이 10/10), `py tools/test_english.py` 'the five names' 그룹(86검사, 변이 21/21).

## 1. ⑫ 호박 대왕 vs 유령 왕 9일 말다툼
- `Config.Halloween.Banter` = lines_pack §4 코드 블록 그대로(DayOneStart 1793372400 = 10/31 00:00 KST, Format `%s: "%s"`, Days 1~9, GhostKingZero).
- **HalloweenService:** 왕이 나올 때(`appear`, 일정·DebugSpawn 같은 길) 그날 줄을 만들어 **`<Key>Appear` 방송의 `Args.Banter`**로 실어 보낸다(방송은 지금처럼 하나).
  - 날: `floor((Config.SeasonNow() - DayOneStart) / 86400) + 1`을 1~9로 자름(10/31 전 시험 서버 = Day 1, 11/08 뒤 = Day 9). KST 날짜 기준(11/03 08:00·23:59 KST 모두 Day 4).
  - Day 9 유령 왕 `%d`는 **먼저** 이 서버에서 쓰러진 대왕 수로 채우고(메모리만, 집에 간 왕은 안 셈, 0이면 `GhostKingZero`), **그다음** Format에 `MonsterTypes[kind].Short`와 함께 넣는다. 화면에 "%d"가 나갈 길 없음(검사).
  - 줄 예: `Pumpkin King: "Happy Halloween! Just so you know, the best king here is me."`
- **게임성 개발 1에게(Announce.luau, 1~2줄):** 이벤트 줄을 보여 준 뒤 `msg.Args.Banter`가 문자열이면 **같은 색(`Events[Key].Color`)으로 채팅 줄 하나 더**(토스트 없음). 옛 클라이언트는 Args를 안 보니 아무것도 안 바뀜(안전).
- halloween 검사의 '이벤트 payload Args = {}' 기대를 'Args에는 Banter(문자열)만'으로 고침(tools/fixtures/halloween_offline.luau 1903 근처 6줄 — 개발 1 작업 트리에 이 파일 수정 중이면 병합 때 이 부분만 합쳐 주세요).

## 2. ⑪ 늘 만나는 다섯 명 이름
| 인물 | Config | 비고 |
|---|---|---|
| 빛 안내자 **Hallie** | `Tutorial.Welcome.Halo.Name = "Hallie"`, `Title = "Guide of Light"` | 환영 1쪽 "Hallie here! Now you know my name. Welcome to the Knights!", M1_4 1쪽 "Hallie here! Now you know my name." |
| 뿔 안내자 **Magpie**(어른) | `Welcome.Horns.Name = "Magpie"`, `Title = "Horn Legion Guide"` | 환영 1쪽 "Finders keepers! HA! You're with us now. I'm Magpie.", M1_4 1쪽 "Finders keepers! HA!" |
| 길드 안내자 **Kit**(베타 숨김) | `Welcome.Neutral.Name = "Kit"`, `Title = "Guild Guide"`, `StoryQuests.Speakers.Guild = "Kit"` | 환영 1쪽 "Fix first. Talk later. I'm Kit. Welcome to the Guild!", M1_4 1쪽 "Fix first. Talk later.", N1·N2 Start "Kit: …" |
| 대장장이 **Otto** | `Speakers.Smith = "Otto"` | M1_1 끝 "Otto: Clang, clang… done. Cocoa time.\nOtto: That's crown shard dust! …" |
| 물약 상인 **Fizzby** | `Vitals.PotionMerchantLabel = "Fizzby"`(MapBuilder 프롬프트 ObjectText), `Speakers.Potion = "Fizzby"` | 모델 이름 `PotionMerchant`는 그대로 |

- A23-58 알림을 안내자가 말함(토스트 하나): `OffSideHalo` "Hallie: Hmm… not very angel-like! Honor -%d" / `OffSideHorns` "Magpie: Too nice for a devil! Your call. Infamy -%d".
- **역할 이름 그대로:** 퀘스트 줄("Report to the Guide"), 도움말, 시스템 줄("The Blacksmith gives you…", `BlacksmithPromptObject = "Forge"`, `PotionShopFar` "…Potion Seller…") — 검사가 지킴.
- 환영 대화는 4쪽(말버릇 + 기존 3쪽), onboarding 검사 기대값을 4로 고침. potions 검사의 프롬프트 글자 기대값을 "Fizzby"로 고침.
- **게임성 개발 1에게:**
  1. 대장간 창(WeaponShop) 맨 위에 `Config.Text.ForgeGreeting` "Otto: Clang, clang… done. Cocoa time.", 물약 창(PotionShop) 맨 위에 `Config.Text.PotionGreeting` "Fizzby: Glug, glug, feel better!" 한 줄(재촉하는 말 없음).
  2. 안내자 창 제목은 지금처럼 `Welcome[f].Name`(이제 이름). 이름표 둘째 줄이 필요하면 `Welcome[f].Title`(역할).
- 아직 안 한 것(검수 몫): glossary_en 추가 줄, story_depth M5_7·H2 줄(정식).
