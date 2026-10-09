# 안내용 알림 목록 (게임성 개발 1, 2026-10-09)

사용자: "너무 친절해" — 진영 가입 알림(13e4d041)과 "Daily quests are open!"(이번 커밋)을 껐어요.
검수가 고르면 `Config.Nudges.<Id> = false`로 하나씩 끌 수 있게 만들게요(클라 것은 개발 1, 서버 것은 그 파일 주인).
**보상·위험·실패 알림은 이 목록에 넣지 않았어요**: 골드·전리품·레벨 업, 'Not enough MP', 'No potions left', 이동 막힘, PvP 경고, 벌칙 같은 것.

> 2026-10-09 검수: 결정 끝, `Config.Nudges`에 들어감 — 끔: WarIntro·ZoneStoryLine·SackLore·HuntSlimes·KeysTip·GuideLabel·GuideBeam(땅 위 금빛 길 줄), 서버 GuideDone·EnteredSafe·DailyReady·WeaponUsableNow. 켬: PadGlow·TravelPulse(A23-88). 나머지 '남기기'·'판단 필요' 줄은 그대로.

## A. 이미 끈 것
| Id | 글 | 언제 | 파일 |
|---|---|---|---|
| JoinToast | You joined the Knights of Light! / Horn Legion! | 진영을 처음 고를 때 | Announce.luau (`Config.ChatText.JoinToast = false`) |
| DailiesOpened | Daily quests are open! Try them along with your first mission. | 첫 [Claim] 뒤 일일 퀘스트 줄이 펼쳐질 때 | HUD.luau parseQuests (`Config.Nudges.DailiesOpened = false`) |

## B. 클라 안내 (개발 1 파일 — 고르면 바로 끌 수 있어요)
| 제안 | Id(가칭) | 글 | 언제 | 파일 |
|---|---|---|---|---|
| 끄기 추천 | WarIntro | Crown War: win points for your side! | 대장간 뒤 왕관전 막대가 처음 나올 때(오늘 4c7dfb24) | HUD.ApplyFold |
| 끄기 추천 | ZoneStoryLine | A Crown Shard calls from beyond the woods… / A big shard sleeps in the old kingdom's tomb. | 레벨 업으로 새 구역이 열릴 때(레벨 업 배너 1.2초 뒤, 리버스 전만) | Fx.luau 레벨 업 |
| 끄기 추천 | SackLore | Stolen gold carries a grudge. If a knight catches the thief, it comes back at 120%! | 원한 자루를 처음 볼 때 | EventHUD.luau |
| 끄기 추천 | HuntSlimes | Hunt slimes and big slimes for XP. | 초원 안내(퀘스트 목표 없을 때) | HUD.luau |
| 남기기 추천 | SmithTravel / SmithWalk | Go to the Crossroads and find the Forge anvil. / Walk to the Forge anvil and press its button. | 대장간 줄을 눌렀을 때(내가 누른 것에 대한 답) | HUD.luau L.Smith |
| 남기기 추천 | NewSkill (배너) | New skill! <name> | 스킬을 배우는 순간(보상 성격) | SkillBar.luau |
| 남기기 추천 | Stronger (배너) | Stronger! | 첫 무기를 받을 때(보상 성격) | HUD.luau |
| 남기기 추천 | LuckTap | Rare drops come a bit more often today! | Lucky 칩을 눌렀을 때만 | HUD.luau |
| 남기기 추천 | SkillLater | Skills come at Lv 5 | 스킬 키를 Lv5 전에 눌렀을 때만 | SkillBar.luau |
| 남기기 추천 | TileSoon | Coming soon! | 아직 없는 칸을 눌렀을 때만 | HUD.luau |
| 남기기 추천 | MyWay | Your way: <name> | 내 이야기 선택으로 이름이 붙을 때(보상 성격) | ComeBack.luau |
| 남기기 추천 | FriendJoined | Your friend <name> joined! | 초대한 친구가 들어왔을 때 | Invite.luau |
| 판단 필요 | PvPCards | PvP 구역 첫 입장 카드 3장 | 처음 한 번(오늘 44cdd61c, 검수 요청) | FirstSteps.luau |
| 판단 필요 | KeysTip | Tip: You can change your keys in Settings! (카드) | 첫 스킬 뒤 PC만 한 번 | SkillBar.luau |

## C. 서버 안내 (개발 2·3 파일 — 끄려면 그쪽에 `Config.Nudges` 확인을 부탁)
| 제안 | 글 | 언제 | 파일 |
|---|---|---|---|
| 끄기 추천 | That's all from me! Now hunt and get stronger. | 첫 임무 안내가 끝날 때 | QuestService.luau:823 |
| 끄기 추천 | Safe zone. | 안전 구역에 들어올 때마다 | ZoneService.luau (EnteredSafe) |
| 끄기 추천 | Daily quest done! Press [Claim]. | 일일 퀘스트를 다 했을 때(줄에 Done!·[Claim]이 이미 보임) | Config.Text.DailyReady |
| 판단 필요 | You got a scroll! Enhance your weapon from your Bag. (…) | 첫 주문서(6초) | LootService.luau FirstScroll |
| 판단 필요 | You can now use %s! Equip it at the Forge or from your Bag. | 무기 레벨 제한이 풀릴 때 | Config.Text.WeaponUsableNow |
| 판단 필요 | The Blacksmith gives you your first weapon for free. Take the Guide's first quest! | 무기 없이 대장간을 쓸 때 | Config.Text.WeaponFromQuest |
| 판단 필요 | Cheer Star +1 (%d/5): at 5, your next goose reward is rare! | 거위 응원 | Config.Text.GooseCheer |
| 남기기 추천 | PvP zone! Watch out for the other sides. | PvP 구역 입장(위험) | ZoneService.luau |
| 남기기 추천 | Bonus for joining the smaller side: +%d gold! | 약한 쪽 첫 선택(보상) | Config.Text.UnderdogSignOn |

검수가 "끄기"로 정해 주면 B는 바로 끄고 시험을 붙일게요. C는 `Config.Nudges` 키 이름만 맞춰 서버 주인에게 넘길게요.
