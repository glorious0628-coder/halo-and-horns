# 무기 쥐기 자세 참고 (게임성 개발 1, 2026-10-11)

> 사용자(10/11): "대검을 잡는 게 이상한데? 손바닥 위에 올려놓은 느낌임" + "앞으로는 물건 쥐는 거를 자세 검색해서 할 수 있게 해줘".
> 검수 규칙(10/11): **모든 쥐기·자세는 먼저 참고를 찾고, 그 기준을 숫자 검사로 만든다.** 그림은 퍼오지 않고 설명만 적는다.

## 1. 찾은 참고 (핵심만)
| 무엇 | 핵심 | 출처 |
|---|---|---|
| 실제 두 손 검(롱소드) 쥐기 | 오른손은 날밑 바로 아래, 왼손은 손 하나~반 개 길이 아래 자루 끝(폼멜) 쪽. 오른손은 자루 위에서 거의 고정, 왼손은 기술에 따라 움직임. 보통 두 손은 거의 붙어 있음 | [ARMA 포럼 "Proper Parrying Technique"](https://www.thearma.org/forum/viewtopic.php?p=3239), [ARMA "Gripping the Pommel"](https://www.thearma.org/forum/viewtopic.php?p=26488), [Guy Windsor, Fiore 번역 #9 "The Six Grips"](https://www.guywindsor.net/?p=4359) |
| 게임 대검 대기 자세 | 무거운 대검은 칼날을 어깨에 걸치고 두 손으로 자루를 잡음. 왼팔이 늘어지면 어색해서 고친 사례가 있고, 대기 동작은 크게 흔들지 않음 | [Unreal 마켓 Greatsword Anims](https://docs.unrealengine.com/marketplace/ja/product/greatsword-anims), [Fab 대검 애니메이션 묶음](https://www.fab.com/listings/0dc2f903-17ce-4db0-9200-576cae9c1b47), [게임 대기 애니메이션 학생 블로그](https://yufeizheng.myblog.arts.ac.uk/?p=1024) |
| Roblox 도구 쥐기 | 도구 손잡이는 손의 그립 지점(R15 `RightGripAttachment`)에 맞춰 붙고, 방향은 `Tool.Grip`(GripPos·GripForward…) 한 CFrame이 정함. 좋은 값은 도구마다 직접 맞춰 봐야 함 | [Roblox 문서 "In-game tools"](https://create.roblox.com/docs/en-us/players/tools), [Tool.GripForward](https://create.roblox.com/docs/reference/engine/classes/Tool/GripForward), [DevForum "Tool grip is sideways"](https://devforum.roblox.com/t/tool-grip-is-sideways/1584419) |
| 지팡이(빛·어둠 마법사) | 지팡이는 몸 가까이 곧게 세워 든다("팔의 연장처럼", 바깥으로 비스듬히 두지 않음). 손은 손목~가슴 높이, 팔꿈치는 조금 굽힘. 마법사 지팡이는 가운데보다 조금 위를 쥐고, 발끝은 땅 가까이 둔다 | [Cherry Tree "10 tips on using a hiking staff"](https://www.cherrytreecountryclothing.com/resources/10-useful-tips-on-using-a-hiking-staff/), [Wilderness "holding your walking pole"](https://www.wildernessmag.co.nz/?p=2859), [Walking stick guide](https://sftp.thewrap.com/post/walking-stick-guide-proper-use) |
| 플라스크(연금술사) | 병은 목을 손가락으로 감싸 쥔다(full wrap). 몸통을 손바닥에 얹는 쥐기는 '보여 주기'용이라 쥔 느낌이 약하다. 손목을 조금 굽혀 병이 손에 붙어 떠 보이지 않게 한다 | [바텐더 병 목 잡기(ShortList)](https://www.shortlist.com/news/how-to-spin-and-pour-a-bottle-like-a-barman) — 그림 참고는 못 찾음, 손 쥐기 일반 설명 |
| 검+방패 대기(팔라딘) | 평소 대기는 칼과 방패를 낮게, 전투 대기는 몸 앞에 든다. 방패 팔은 가슴 앞 45° 쯤, 칼 손은 방패 뒤 | [ORK 대기 동작 안내](https://forum.orkframework.com/d/5215-tutorial-ork-animations-using-mecanim-my-all-new-comprehensive-guide), [Nexus 검+방패 요청](https://forums.nexusmods.com/topic/4666325-armour-or-animations), [MocapOnline 대기 동작](https://mocaponline.com/blogs/mocap-news/idle-animation-game-dev-guide) |
| 한 손 허리(대장장이·연금술사·조련사) | 손등이나 손바닥이 허리 옆에 닿고, 손목은 엉덩이뼈 위로 살짝 앞, 팔꿈치는 바깥으로(팔과 허리 사이 삼각형) | [Hand on hip drawing reference](https://library.peoplespharmacy.com/hand-hip-drawing-reference), [Fashion Drawing For Dummies](https://www.dummies.com/article/academics-the-arts/art-architecture/drawing/fashion-drawing/how-to-draw-hands-on-your-fashion-figures-171483) |
| 활 대기(레인저·그림자 사냥꾼) | 대기 자세는 활을 옆에 세워 든다(당기지 않음). 3인칭은 활을 세워서 | [PoseMyArt 궁수 자세](https://posemy.art/blog/drawing-archer-poses/), [Kotaku 게임 궁술](https://kotaku.com/video-game-characters-are-terrible-at-archery-1836615271) |
| §1-8 한손검(A23-128, 두 전사) | 한손검은 주먹이 자루를 감싼다(해머 쥐기, 또는 엄지·검지 쪽을 조금 세운 악수 쥐기). 무거운 칼일수록 손목을 고정하는 해머 쥐기. 한손 무기 대기 동작은 칼을 오른손 옆에 두고 걷기·서기가 이어짐. 대결 자세에서는 칼 쪽이 앞, 빈손은 뒤로 — 우리 대기에서는 빈손을 그냥 내림 | [Virtus Martialis "Gripping swords"](https://virtusmartialis.substack.com/p/gripping-swords), [sword-site "handshake grip"](https://sword-site.com/thread/114/hold-sword-handshake-grip-nonsense), [Skyrim 한손 대기 동작 모드](https://www.nexusmods.com/skyrim/mods/109608), [Steam 한손검 자세 토론](https://steamcommunity.com/app/362490/discussions/0/4039228198241300759) — 칼을 옆에 든 대기 그림 참고는 못 찾음, 쥐기 설명 + 대기 동작 목록 |
| §1-9 한 손 망치 내려치기(대장장이 Q, 게임성 검수 10/11) | 한 손 망치는 머리 위 어깨 뒤에서 앞쪽으로 세로로 내려친다. 빈손은 두 번째 때리는 팔이 아니라 앞쪽 받침이나 균형을 잡는 팔이다(두 손을 모으는 것은 두 손 도끼 이야기) | [Vintage Story 포럼 '한 손 망치 동작'](https://www.vintagestory.at/forums/topic/17784-proposed-change-to-the-hammer-animation-for-realism-and-seizure-avoidance/), [AGS 포럼 '도끼·망치 동작'](https://www.adventuregamestudio.co.uk/forums/index.php?msg=521318) — 그림 참고는 못 찾음, 설명만 |

**우리 place에서 잰 값(`place/GoodEvil.rbxlx` R15):** `RightGripAttachment` = 손 안 (0, -0.158, 0), 방향 Angles(-90°, 0, 0). 어깨 관절은 UpperTorso (±0.972, 0.598, 0)에 있어요. 위팔은 0.92, 아래팔은 0.81. 우리 무기는 `CharacterVisuals.fist()`로 손의 -Z(주먹을 꿰뚫는 축)를 따라 붙어요.

## 2. 이 참고로 정한 숫자 기준 (시험 `tools/test_two_hand_grip.py`)
1. **자루가 주먹을 지난다:** 손의 그립 지점과 손 중심에서 자루 선까지 거리가 0.2칸 이하예요.
2. **자루 축 = 손 쥐기 축:** 손의 -Z와 자루 방향 사이 각도가 10° 이하예요.
3. **팔뚝 위에 얹히지 않는다:** 아래팔 축과 자루 사이 각도가 45~135°예요. 지난 사진의 '손바닥 위에 올려놓은 느낌'은 자루가 팔뚝을 따라 누운 모습이었어요.
4. **두 손 위치:** 오른손이 날밑 쪽, 왼손이 그 아래 폼멜 쪽이에요. 두 손 간격은 손 크기만큼(0.45~0.8칸)이에요. 자루는 왼손보다 0.1칸 이상 길어요.
5. **대검 자세:** 칼자루는 가슴 앞에 있어요. 칼날은 위·뒤로 115~145° 올라가서 오른 어깨 바로 위(몸통 위 0.8보다 높게)를 지나요.
6. **팔이 닿는다:** 손목까지 거리가 팔 길이의 92% 이하예요(키 1·0.85 아바타, 큰 손·작은 손 모두). 안 닿으면 두 손 자세를 하지 않아요.

**지팡이·플라스크 숫자 기준(시험 `tools/test_one_hand_grips.py`):**
- 지팡이는 곧게 선다. 빛은 5° 이하, 어둠은 앞으로 15° 이하로 기울고, 옆으로는 기울지 않는다.
- 손은 몸통 바깥에 있고, 지팡이 선이 몸통을 지나지 않는다.
- 6칸 이하 지팡이는 발끝에서 절반 이상 위를 쥔다(`STAFF.Grip` 0.55). 긴 지팡이는 땅에 박히지 않게 손-발끝 거리를 3.3칸까지만 둔다. 발끝은 땅 위 0~1.3칸이다.
- 플라스크는 주먹이 목을 감싸고, 몸통은 주먹 아래, 코르크는 위에 있다. 병은 곧게 가슴 앞에 든다.
- 그립점-선 0.2 이하, 축 10° 이하, 팔뚝-무기 45~135°, 팔 닿기 92% 이하(대검과 같음).

**한손검 숫자 기준(A23-128, 같은 시험; 대검·두 손 쥐기는 뺌 — `test_two_hand_grip.py`가 다시 생기지 않는지 봄):**
- 빛 전사 = 곧은 칼(Sword), 뿔 전사 = 어두운 한손검(DarkSword). 두 손 쥐기(TwoHand)·대검 없음.
- 손은 오른쪽 옆, 내린 팔 줄(x 1.47) 바로 바깥(손잡이 x 1.4~1.75), 허리 높이(y -1.0~-0.6), 조금 앞(z -0.9~-0.4).
- 칼끝은 앞·위 40~50°(빛·뿔 모두 45°, 뿔은 조금 바깥). 몸을 가로지르지 않음(x 0~0.3), 칼 선이 몸통을 지나지 않음.
- 팔꿈치는 아래로, 내린 팔 줄 가까이(Pole, x 1.3~1.55 — 안으로 접지 않음, 손보다 위·뒤). 왼손은 비우고 내림(OffHand·왼팔 각도 없음).
- 그립점-선 0.2 이하, 축 10° 이하, 팔뚝-칼 45~135°, 팔 닿기 92% 이하.
- 검수 10/11(fix/onehand 반박 검증): 팔뚝(팔꿈치→손목 선)은 몸통·엉덩이 상자에서 0.4칸 이상(내린 팔이 0.47), 손(손목→손 아래)은 0.45칸 이상 떨어짐. 손목 꺾임(팔뚝 축 vs 손 위쪽) 30° 이하. 손잡이+폼멜(두께 0.21)과 손은 ±40° 흔들리는 오른 허벅지(place R15: 엉덩이 관절 (0.5, -1.2, 0), 허벅지 0.99×1.36×0.97)에 닿지 않음. 어두운 한손검 모양 = buildSword와 같은 손잡이·칼날 크기·자리(모든 단계 길이), 날밑 같은 높이·비슷한 폭, 작은 둥근 폼멜.
- 지금 값: 빛 Hilt (1.65, -0.85, -0.6)·Aim (0.05, 0.7, -0.7)·Pole (0.6, -0.6, 0.8) → 팔꿈치 x 1.46, 손목 22.6°, 팔뚝 0.46·손 0.52, 칼-허벅지 0.41. 뿔 Hilt (1.65, -0.85, -0.65)·Aim (0.1, 0.7, -0.7)·같은 Pole → 1.46, 23.7°, 0.46·0.52, 0.35.
- 스킬 동작(빛 Q, 뿔 Q·Z·X): 빈 왼주먹으로 칼을 같이 쥐는 흉내 없음 — 왼팔은 PaladinSwing처럼 균형 잡는 팔(`tools/test_side_clips.py`).

**빈 손 숫자 기준(같은 시험):**
- 빈 손은 몸 위 점으로 간다(OffHand: 허리 = (-1.25, -0.65, 0.1), 가슴 앞 주먹, 가슴 앞 손바닥).
- 팔은 35~92% 뻗는다. 손 중심은 몸통 상자 밖 0.15칸 이상이다(파고들지 않음).
- 허리 손은 허리 옆에서 0.45칸 안에 닿는다.
- 목표점은 아바타 몸 크기(어깨 관절 거리)에 맞춰 줄고 는다.

## 3. 만드는 법 (WeaponPose)
- 자세를 팔 각도에서 시작하지 않아요. **칼 위치에서 시작해요:** 두 손 무기는 `TwoHand` = { Hilt(오른손 그립 지점), Aim(칼날 방향) — 몸통 기준 }(A23-128로 지금은 쓰는 줄 없음, 코드만 남김). 한 손 무기는 `OneHand` = { Hilt, Aim, Pole(팔꿈치 굽는 쪽, 없으면 아래·바깥) }(두 전사, 빛·어둠 마법사, 연금술사)이고, 같은 계산으로 오른팔만 놓아요(왼팔은 각도 표 그대로).
- 두 팔 모두 Fx의 두 마디 팔 계산(활과 같은 계산, 아바타의 실제 뼈 길이)으로 손을 그 자리에 놓아요. 손의 -Z는 칼날을 따라가고, +Y(손목 쪽)는 자기 어깨 쪽을 향해요.
- Studio 측정: 플레이어 속성 `GripProbe = true`이면 Studio에서만 2초마다 콘솔에 `[WeaponPose] probe <조합> | Right dHand=… dGrip=… axis=… fore=… | Left …`가 찍혀요(실제 부품에서 잼).

## 4. 다음 (같은 기준으로)
- A23-108 쥐기 9조합을 같은 probe로 다시 재고, 이상한 것 목록을 만들어요(fore가 45° 아래 = 팔뚝을 따라 누움, dHand가 0.2 넘음).
- 공격·스킬 몸짓의 쥐기도 같은 기준이에요.

## 5. 무기 길이 (A23-133, 2026-10-11 밤)
> 사용자: "지금은 무기가 너무 길어서 잡는 위치가 이상해" + "캐릭터가 뭔가를 하는 것들은 자세 같은 것들 다 검색해서".
> 검수: 아바타 키 대비 무기 길이·날:손잡이 비율·손 위치를 검·지팡이·활·망치마다 숫자로 정하고 시험으로 지킨다. 이미지 생성 2의 무기 High 그림 비율도 이 숫자를 쓴다.

### 5-1. 아바타 키 (우리 place에서 잼)
- `place/GoodEvil.rbxlx`의 기본 R15(Workspace NPCs `PotionMerchant`)를 쟀어요. 발바닥 0, UpperTorso 가운데 3.21, 어깨 관절 3.81, 머리 꼭대기 **5.18칸**(크기 1). 아래에서 **H = 5.2칸**으로 써요.
- 공개 자료도 비슷해요. 기본 Roblox 캐릭터 키는 약 5~5.5칸이고, R15 키 조절은 95~105%예요([DevForum "Fetch Player Height"](https://devforum.roblox.com/t/fetch-player-height/2205072), [Roblox 문서 Body scale](https://create.roblox.com/docs/art/accessories/body-scale)).
- 고친 것: 한 손 시험(`test_one_hand_grips`)은 몸통 가운데를 3.9칸으로 어림했어요. 실제는 3.21칸이에요. 그래서 긴 지팡이는 발끝이 땅에 0.2~0.5칸 박혔을 수 있어요. 손이 지팡이를 쥐는 자리를 발끝에서 2.8칸까지로 줄였어요(`STAFF.FootMax` 3.4 → 2.8). 이제 발끝은 땅 위 약 0.06칸이에요.
- 게임성 검수 10/11: 그 2.8칸은 기본 R15에만 맞아요. 이제 서버가 지팡이를 만들 때 **그 아바타 몸으로 손 높이를 재요** (`CharacterVisuals.staffHandHeight` = HipHeight + 뿌리 절반 + 뿌리→윗몸통 쉬는 자리 + 손잡이 높이 × 몸 비율). 발끝은 땅 위 0.08칸(`STAFF.FootGap`), 손은 막대의 50~80% 높이 안. 몸을 못 읽으면(R6·옷 모델) 옛 2.8칸. 시험: 기본·긴 다리·키 0.9(좁은 어깨)·키 1.05 아바타 모두 발끝 0.08~0.25칸. 쓰지 않던 `STAFF.Grip`·`FootMin`은 지움.
- **바로잡기 (10/12, 메인 반영 1 사진 grips_low):** 위의 '3.21·3.81·5.18'은 `PotionMerchant`의 **낡은 부품 위치**로 잰 값이었어요. 이 NPC는 몸 크기가 약 1.06배 커져 있는데, 저장된 부품 위치는 커지기 전 그대로예요. 관절 연결점(RigAttachment)으로 다시 재면 윗몸통 가운데 **3.441**, 어깨 4.04, 머리 꼭대기 **5.46칸**이에요. HipHeight 식도 3.441로 같아요. 크기 1로 줄이면 약 5.15칸이라 무기 길이 기준 **H = 5.2칸은 그대로** 써요.
- 사진에서 지팡이 끝이 발바닥 위 0.27칸(빛)·0.26칸(뿔) 떠 있었어요(목표 0.08). 서버 추정은 쉬는 자세로는 맞고, 게임 중 자세(Animator 대기 동작·손 IK)가 손을 조금 더 높게 잡아요. 그래서 **화면이 맞춰요:** `WeaponPose.StaffStep`이 매 프레임 막대(Shaft) 아래 끝에서 땅까지 재고, 손 목표만 차이의 절반씩 올리고 내려요(±0.4칸까지, 뛸 때처럼 땅이 없으면 0으로).

### 5-2. 찾은 참고
| 무엇 | 숫자 | 출처 |
|---|---|---|
| **Roblox 공식 장비(gear) 1,942개** | Roblox가 GitHub에 올린 장비 파일에서 손잡이 파트(Handle) 길이와 `Tool.Grip` 위치를 쟀어요(파트 상자 기준이라 그림보다 조금 클 수 있어요). **칼 249개:** 길이 중간값 5.0칸(4.0~5.25가 가운데 절반), 손은 자루 끝에서 12%(9~16%). **지팡이 55개:** 5.4칸, 손은 가운데 근처(가까운 끝에서 44%). **활 34개(석궁 뺌):** 5.25칸, 손은 한가운데(50%). **마법봉 22개:** 2.8칸. **망치 12개(전투 망치):** 4.75칸, 손은 자루 끝에서 27% | [Roblox/Catalog (GitHub)](https://github.com/Roblox/Catalog) |
| **Roblox Linked Sword**(기본 칼, 가장 많이 쓰인 칼) | 손잡이 파트 1 × 0.8 × **4칸**, 그립 위치 (0, 0, -1.5) → 손이 자루 끝에서 0.5칸 = **12.5%**. 키 5칸 아바타의 0.8배 | [Catalog 125013769.rbxmx](https://github.com/Roblox/Catalog/blob/master/Items/Gear/125013769.rbxmx), [DevForum Linked Sword 해설](https://devforum.roblox.com/t/attempting-to-decipher-the-script-of-the-linked-sword-default-sword/2388604) |
| 실제 한손검(아밍 소드) | 전체 95cm 안팎(사람 키의 약 0.53배), 날이 전체의 약 80%, 손잡이는 약 10cm(손 하나 폭) | [Kult of Athena Lockwood Type XV](https://www.kultofathena.com/product/lockwood-swords-type-xv-arming-sword/), [Reliks Angus Trim Arming Sword](https://www.reliks.com/Products.aspx?pid=3009) |
| 실제 두 손 검 | 겨드랑이 높이 = 키의 약 0.76배(Vadi). 한손검은 이보다 짧아요 | [Guy Windsor "Size Matters"](https://guywindsor.net/2012/08/size-matters-longsword-length/) |
| 지팡이 | 걷는 지팡이·막대는 어깨~눈 높이(키의 0.8~0.95배), 쿼터스태프는 키 + 손 하나 | [Home of Poi "Staff length"](https://www.homeofpoi.com/en/community/forums/topics/869476/Staff-length-question), [Wikipedia Quarterstaff](https://en.wikipedia.org/wiki/Quarterstaff) |
| 활 | 리커브 활은 어른에게 62~70인치(키의 약 0.9~1.0배). 손은 한가운데 손잡이 | [Sportsman's 리커브 활 길이 표](https://www.sportsmans.com/recurve-bow-length-size-chart) |
| 게임 무기 크기 정하기 | 기준 무기 하나를 캐릭터 키와 나란히 놓고 정한다. 정확한 길이보다 손잡이·날 자리가 맞는 게 더 중요하다. 두 손 무기는 한 손 무기보다 크게 | [Beyond Skyrim 무기 그림 안내](https://wiki.beyondskyrim.org/wiki/Arcane_University:Weapons_(2D)) |

- **못 찾은 것:** Swordburst·Dungeon Quest·World // Zero 같은 인기 Roblox RPG의 무기 크기 숫자는 공개 자료가 없었어요. 그래서 Roblox 공식 장비 실측을 'Roblox 게임 기준'으로 썼어요. 애니메이션 쥐는 자리는 §1(실제 쥐기·대기 동작 자료)과 같아요.
- **Roblox 손이 커요:** 우리 아바타 주먹은 손잡이 방향으로 1.03칸이에요(키의 20%, 실제 사람은 약 5%). 그래서 손잡이는 1.2칸보다 짧게 못 해요. 날:손잡이부 비율은 실제 칼(4:1)보다 작은 1.4~2.1 : 1이 돼요. 그래도 Roblox 칼처럼 보여요(Linked Sword도 손잡이부가 전체의 약 1/4).

### 5-3. 정한 숫자 (H = 5.2칸; 시험 `tools/test_one_hand_grips.py` A23-133 줄)
| 무기 | 길이 (H 대비) | 손 위치 | 그 밖 |
|---|---|---|---|
| 한손검(빛 전사 Sword) | 자루 끝~칼끝 **0.74~0.88H**(3.85~4.55칸; 1단계 ≈ Linked Sword) | 자루 끝에서 13~16% | 날:손잡이부 1.7~2.1 : 1, 날밑 폭 1.2칸(전체의 약 1/3), 날 폭 0.6칸(약 1/7) |
| 어두운 한손검(뿔 전사 DarkSword) | 폼멜 포함 **0.80~0.93H**(4.13~4.83칸) | 18~21% | 날:손잡이부 1.4~1.8 : 1 |
| 지팡이(빛·어둠 마법사) | 구슬 포함 **0.85~1.0H**(막대 3.95~4.45칸; 10/12 4.5 → 4.45, 7단계가 1.008H였음) | 발끝에서 55~70%(10/12 §5-6; 예전 62~71%) | 구슬 지름 0.55~0.9칸(길이의 약 1/8), 발끝은 땅 위 약 0.06칸 |
| 활(레인저) | **0.6~0.95H**(3.1~4.9칸) | 한가운데 | — |
| 짧은 활(그림자 사냥꾼) | 활의 0.75배 = **0.45~0.71H** | 한가운데 | 15° 기울임 |
| 대장장이 망치 | **0.42H**(자루 1.9 + 머리 반 0.3) | 자루 아래에서 26% | 머리 폭 1.1칸(전체의 1/2) |
| 조련사 막대 | **0.41~0.45H** | 자루 아래에서 30% | — |
- 시험 범위: 검 0.72~0.95H·손 10~22%·날 1.3~2.5배, 지팡이 0.82~1.03H·손 52~70%(10/12), 활 0.55~0.97H·짧은 활 0.72H 이하, 망치 0.35~0.55H·손 15~33%, 막대 0.3~0.6H. 단계가 올라가도 길이가 줄지 않아요.
- 만드는 법: `Config.Weapons` Length(3~6.5)는 단계 순서로만 쓰고, `CharacterVisuals`의 `LEN` 표가 무기마다 칸 수로 줄여요(`tierLen`). 바꾸기 전 검은 4.45~7.95칸(0.86~1.53H), 지팡이는 구슬 포함 0.93~1.19H, 활은 0.58~1.25H였어요.

### 5-4. 그림(이미지 생성 2 무기 High)에 쓰는 비율
- 검: 전체 길이 = 키의 0.75~0.9배. 날 : 손잡이부(손잡이+날밑+폼멜) ≈ **2 : 1**. 날밑 폭 ≈ 전체의 1/3, 날 폭 ≈ 전체의 1/7. 손잡이는 주먹 하나보다 조금 길게.
- 지팡이: 구슬 포함 키의 0.85~1.0배, 구슬 ≈ 길이의 1/8, 쥐는 자리 = 발끝에서 약 2/3.
- 활: 키의 0.6~0.95배(짧은 활 0.45~0.7배), 쥐는 자리 = 한가운데.
- 대장장이 망치: 키의 0.4~0.5배, 머리 폭 ≈ 전체의 1/2, 쥐는 자리 = 자루 아래 1/4.

### 5-5. 시험 빈 곳 메움 (게임성 검수 10/11)
- 위팔: 한 손 쥐기마다 위팔 아래쪽 절반(가운데→팔꿈치)이 몸통·엉덩이 상자에서 0.15칸 이상 떨어져요(내린 팔은 0.22). 연금술사 플라스크 팔이 0.14로 옆구리에 붙어서 팔꿈치를 아래·바깥으로(`Pole` (1, -0.8, 0)) 돌려 0.19로 고쳤어요.
- 두 손 간격: 한손 동작(빛·뿔 전사, 대장장이)의 모든 순간에 두 손 잡는 점이 1.2칸 이상 떨어져요(관절 각도로 손 위치를 계산; 같은 손잡이를 두 주먹이 같이 쥐면 약 1칸). 지금 가장 가까운 순간은 PaladinZ 1.75칸.
- 대장장이 Q(`WarriorRelease`): 왼팔이 오른팔과 똑같이 머리 위로 올라가 두 손으로 쥔 것처럼 보였어요 → §1-9대로 왼팔은 앞 아래 받침 → 옆으로 균형.

### 5-6. 지팡이를 더 낮게 쥐기 (최종 검수 10/12 결정 (a), 게임성 개발 1)
- 요청: 승인 2D의 감은 손잡이 가운데(아래서 30~45%)를 쥐고, 끝은 땅에 닿고, 길이는 0.85~1.0H(A23-133) 그대로. 우선순위 = 길이 > 끝 땅 닿기 > 감은 곳 쥐기. 그러려면 손이 엉덩이 높이(≈2.1칸)여야 함.
- 참고:
  - 주먹 쥐기(power grip)는 손잡이가 아래팔과 거의 직각 — NJIT 손도구 강의(web.njit.edu/~sengupta/IE665/Hand%20tools.pdf). 긴 자루를 손목 곧게 쥐려고 손잡이를 15~25° 꺾는 특허(빗자루)·19° 꺾은 망치 자루(Bennett)가 있을 만큼, 곧은 막대는 손목이 꺾여야 맞음.
  - 손목 옆 꺾임: 엄지 쪽(radial) 보통 15~25°(성인 120명 평균 18.6°), 새끼 쪽(ulnar) 30~45°; 일상 동작에 필요한 건 엄지 쪽 17°·새끼 쪽 40°(Mayo Clinic 기능 범위 연구 등).
  - 걷는 막대는 팔꿈치 90°·아래팔 수평일 때 손 = 허리(REI) — 우리 R15에서는 그게 바로 예전 자세(손 2.9칸).
- 우리 R15로 계산(`tools/test_one_hand_grips.py`와 같은 팔 풀이): 곧게 선 지팡이를 주먹에 끼우면 손의 쥐는 축이 위를 보니 아래팔이 수평에서 10° 내려갈 때마다 손목이 엄지 쪽으로 10° 꺾여요. 손 2.1칸이면 팔이 다 펴지고(닿기 99~100%) 손목 약 70° → 불가. 엄지 쪽 20° 안에서 가장 낮은 곳 = 빛 2.66~2.71칸(곧게), 뿔 2.5~2.56칸(앞으로 11° 기울임).
- 정한 것: 빛 마법사 손 2.71칸(Hilt (1.4, -0.5, -0.8), 3°, Pole (0.2, -0.2, 0.6)), 연금술사 2.66칸(6°), 뿔 마법사 2.56칸(11°). 손은 몸통 밖 옆·조금 앞, 팔꿈치는 뒤로. 손목 엄지 쪽 17~19°·앞뒤 26~31°, 아래팔·손이 몸통에서 0.27~0.29칸(예전 0.00~0.02 = 몸통에 붙었음). 진영 차이: 빛 가장 높고 곧게, 뿔 가장 낮고 기울임.
- 그래서 쥐는 곳은 지팡이 발끝에서 55~70% → 2D 감은 곳(30~45%)보다 위. 감은 곳 위끝(b)으로도 LightMage T2·DarkMage T2 말고는 안 맞음 → 메시의 감은 부분을 위로 옮기기(이미지 생성 4·디자인 검수, 최종 검수 순서 (c)). 코드 지팡이는 시험 범위 52~70%.
- 연금술사 = 승인 2D(art/out/s2/weapons_t13_4v/Weapon_Neutral_Alchemist_T1~T3_front)대로 플라스크 달린 지팡이(`SHAPES.FlaskStaff`): 나무 막대 + 손을 감싼 가죽(0.7칸) + 위 받침 두 갈래 + 둥근 유리 플라스크(단계 색) + 목·코르크. 막대는 목·코르크만큼 짧아 전체 높이 = 구슬 지팡이와 같음(0.85~1.0H; 최종 검수 10/12: 막대 위 끝 4.5 → 4.45로 7단계 1.008H → 0.9985H, 시험 범위도 규칙 그대로 0.85~1.0).
