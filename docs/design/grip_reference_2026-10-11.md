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
