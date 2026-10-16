# 무기 쥐는 모습 점검 기준 (게임성 개발 1, 2026-10-16)

> 사용자(10/16, 최종 검수 통해): "무기 드는 것 좀 자세히 봐달라고 해. 완전 이상해."
> 최종 검수 순서: ① 레퍼런스 → ② 시험 Studio 사진(전사·마법사·궁수 × T1·T2·T3 + 맨손, 서기·걷기·공격, 앞·옆·뒤) → ③ 체크리스트로 이상한 점 목록 → ④ **고치기 전** 목록을 최종 검수에게.
> 먼저 쓴 참고 `docs/design/grip_reference_2026-10-11.md`(실제 쥐기·Roblox 장비 1,942개 길이·쥐는 점)와 `docs/design/weapon_grip_plan_2026-10-12.md`를 그대로 바탕으로 해요. 그림은 퍼오지 않고 설명만 적어요.

## 1. 새로 찾은 참고 (10/16)
| 무엇 | 핵심 | 출처 |
|---|---|---|
| 한손검 대기·걷기 동작 묶음 | 한손검은 오른손에 든 채로 서기·걷기·달리기·옆걸음·돌기가 한 묶음으로 이어짐(칼을 넣지 않음). 걸을 때도 칼 든 팔은 크게 흔들지 않음 | [Skyrim 한손 동작 모드](https://www.nexusmods.com/skyrim/mods/109608), [Fab "RPG Animations - One Hand Base"](https://www.fab.com/listings/1cb48db6-88d2-4aaa-a0f2-a624ffb1c122) |
| 활 들고 걷기(실제) | 활은 **가운데 손잡이(라이저)** 를 쥐고 몸 옆에 든다. 활대 끝을 쥐지 않는다. 시위는 몸 바깥, 활은 아래나 조금 앞으로. 꽉 쥐지 않고 손바닥에 얹듯 | [BattlBox "how to carry bow while hunting"](https://www.battlbox.com/blogs/hunting/how-to-carry-bow-while-hunting-mastering-the-art-of-bow-transport) |
| 마법사 지팡이 동작 묶음 | 지팡이 하나로 서기·걷기·공격·버프가 한 묶음. 한 손으로 세워 든 채 걷는다 | [Fab "Simple Mage-Staff Animation"](https://www.fab.com/listings/294d8642-8fa6-48db-ace3-59b7fb8c23af), [Funcom 포럼 무기 대기 동작](https://forums.funcom.com/t/idle-weapon-animations/94765) |
| Roblox 도구 + 걷기 | 도구를 들면 기본 Animate가 오른팔을 'toolnone'으로 고정 → 걷기 흔들림과 섞일 때 팔·몸통이 어색해지는 사례. 높은 우선순위 팔 동작이 있어도 걷기 흔들림이 팔에 남는 사례 | [DevForum "AnimationPriority issue with R15"](https://devforum.roblox.com/t/animationpriority-issue-with-r15/190400), [DevForum "R15 weird animation behaviour"](https://devforum.roblox.com/t/r15-weird-animation-behaviour/3404847) |
| (못 찾음) | Roblox 칼싸움 게임(Deepwoken 등)의 대기 칼 각도를 글로 적은 자료는 못 찾음 → 각도는 10/11 참고(실제 쥐기)와 사용자 결정(A23-187 grip-3)을 기준으로 둠 | — |

## 2. 점검 체크리스트 (사진 + 숫자, 한 줄씩 '이상한 점'으로 적음)
숫자는 거들 뿐이고 판정은 사진으로 해요(numbers-are-hints). 숫자는 매 프레임 실제 부품에서 재요(`WeaponPose.Measure`와 같은 식).

| # | 무엇 | 실패 기준 |
|---|---|---|
| C1 | **손잡이가 주먹 안을 지남** | 쥐는 손의 GripAttachment → 손잡이 선 거리 dGrip > 0.2칸, 또는 쥐는 점이 손잡이 밖(point < 0 또는 > 1) |
| C2 | 손잡이 축 = 주먹 축 | 주먹 축(손 -Z)과 손잡이 각도 > 15°(Rest로 일부러 돌린 각도는 빼고 봄) |
| C3 | 팔뚝 위에 얹히지 않음 | 팔뚝과 무기 각도 < 45°(무기가 팔을 따라 누움) |
| C4 | **칼날·머리 방향** | 검: 칼끝이 위·앞(grip-3 SwordReady) 아님 / 몸을 가로지름. 지팡이: 세로에서 15° 넘게 기욺, 구슬이 가슴 앞. 활: 활대가 세로에서 20° 넘게 기욺, 시위가 몸 쪽. 망치: 머리가 어깨 위 아님 |
| C5 | **몸 뚫기** | 무기 부품이 몸통·머리·다리·팔 부품과 겹침(GetPartsInPart) |
| C6 | 땅 뚫기 | 무기 가장 낮은 점이 발바닥보다 아래 |
| C7 | **걸을 때 흔들림** | 걷기 한 주기 동안 무기 방향이 25° 넘게 출렁이거나, 손이 손잡이에서 0.2칸 넘게 벗어남 |
| C8 | **공격 때 손에서 떨어짐** | 공격 동작 중 dGrip 최대 > 0.25칸, 쥐는 연결(RightGrip / BowGrip) 꺼짐, 또는 무기가 손과 따로 튐 |
| C9 | 맨손 | 빈 주먹 모양·팔이 몸에 파묻힘·공격 때 팔이 몸통을 지남 |

## 3. 사진 찍는 법
- 시험 Studio `build/PhoneTest_1015.rbxlx`(main 코드로 맞춤), 장면 명령 `py tools/scene.py`(SceneSetup) + DebugCommand(WeaponOwnedMask / WeaponTier / LootReset 0 = 맨손).
- 카메라 Scriptable, 캐릭터 기준 앞·옆(오른쪽 = 무기 쪽)·뒤, 거리 9칸, 가슴 높이.
- 서기 = 1.5초 쉼 뒤, 걷기 = Humanoid:Move 앞으로 0.7초 뒤, 공격 = F 누르고 0.15·0.35초.
- 도구 `build/dev1_tools/grip1016.py`(git 밖), 결과 `docs/art/verification_2026-10-16/grip_check/`(사진·숫자 JSON·시트).

## 4. 활 전투 대기 (사용자 10/16 "활이 문제인게 이게 대기하는 자세가 이상해")
> 최종 검수가 본 것: 두 팔이 곧게 늘어지고 활이 왼다리 옆에 세로로 매달림 → '막대 든 마네킹', 옆에서는 활이 몸 뒤로 숨음. 사냥꾼 '들고 다니기'(§1 BattlBox)를 맞춘 게 원인 — 게임에서는 쏘는 사람으로 안 읽힘.

| 무엇 | 핵심 | 출처 |
|---|---|---|
| 게임 궁수 동작 묶음 | 일반 대기(out of combat idle)와 활을 든 대기(bow idle, 상체 대기)·조준 걷기를 따로 둠 → 전투 중 대기는 '쏠 준비' 자세 | [Superhive "Stylized Archers Pack"](https://superhivemarket.com/products/stylized-archers-pack---animated-characters-male--female/docs), [kevdev "Human Archer Animations"](https://kevdev.itch.io/human-archer-animations) |
| 2D 궁수 스프라이트 | 활을 드는 각도를 120·90·60·30°로 나눠 그림 — 활은 몸 앞에서 각도를 가진 채 들림 | [Game Developer Studio "Animated Archers"](https://gamedeveloperstudio.itch.io/animated-archers-character-pack) |
| 3D 궁수 자세 모음 | '전투 준비(combat-ready)' 자세 = 활 팔을 몸 앞에 두고 다른 손은 시위·화살 근처 | [PoseMy.Art "Archer Pose Reference"](https://posemy.art/archer-pose-reference/) |
| 화살 걸고 기다리기 | 사냥꾼은 쫓을 때 화살을 걸어 둔 채 활을 낮게 든다(바로 쏠 준비) | [Tactical: carrying arrows nocked](https://emilyleiapp.flothemes.com/when-should-you-carry-arrows-in-the-nocked-position/) |

**목표(최종 검수 10/16):** 왼팔 팔꿈치 60~90° 굽혀 손이 왼쪽 허리~배 앞. 활은 몸 앞쪽으로 비스듬히(위 끝이 앞·바깥 25~40°). 오른손은 시위 근처나 허리. 앞·옆 어디서 봐도 활 모양이 보임.
**안 2개(사진으로 고름):** A = 비스듬히 앞(위 끝 앞·바깥 25~40°) / B = 낮게 몸 앞 가로(배 앞, 거의 수평).

## 5. 싸우지 않을 때 무기 두는 곳 (A23-223, 사용자 10/16: 활은 등에, 칼은 허리에)
| 무엇 | 핵심 | 출처 |
|---|---|---|
| 칼은 왼쪽 허리 | 오른손잡이가 많아서 칼은 보통 왼쪽 허리에 찬다(오른손으로 몸 앞을 가로질러 뽑음) | [Writer's Digest "Where To Carry a Weapon"](https://www.writersdigest.com/where-to-carry-a-weapon-fightwrite) |
| 게임에서 무기를 등에 | 게임 캐릭터가 지팡이·창·활을 등에 메는 모습을 플레이어가 알아보고 이야기함(그 게임은 가로로 멤) | [Steam: Trails of Cold Steel 토론](https://steamcommunity.com/app/538680/discussions/0/1693785669856166482) |
| 플레이어가 원하는 것 | 칼은 허리에, 다른 무기는 등에 보이게 해 달라는 요청과 그걸 해 주는 모드 | [Steam: Baldur's Gate 3 토론](https://steamcommunity.com/app/1086940/discussions/0/3808408747684743306), [Step Mods "sheath weapon from hip"](https://stepmodifications.org/forum/topic/10973-sheat-weapon-from-hip/) |
| (못 찾음) | 활을 '비스듬히' 멘 각도를 숫자로 적은 자료는 못 찾음 → 오른어깨 위 → 왼허리 아래(최종 검수 목표)로, 사진으로 맞춤 | — |

**우리 값(Config.WeaponStow):** 활 = UpperTorso 뒤(몸통 반 두께의 1.3배 뒤), Z −35°(위 끝이 오른어깨 쪽). 칼 = LowerTorso 왼쪽(반 폭의 1.15배), 조금 앞, X 120°(손잡이 앞·위, 칼끝 뒤·아래), Z −8°. 공격하면 그 순간 손으로, 마지막 공격 5초 뒤 다시. 검집은 디자인 재개 때(지금은 칼만).
