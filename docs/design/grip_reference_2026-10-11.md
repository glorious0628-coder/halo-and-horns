# 무기 쥐기 자세 참고 (게임성 개발 1, 2026-10-11)

> 사용자(10/11): "대검을 잡는 게 이상한데? 손바닥 위에 올려놓은 느낌임" + "앞으로는 물건 쥐는 거를 자세 검색해서 할 수 있게 해줘".
> 검수 규칙(10/11): **모든 쥐기·자세는 먼저 참고를 찾고, 그 기준을 숫자 검사로 만든다.** 그림은 퍼오지 않고 설명만 적는다.

## 1. 찾은 참고 (핵심만)
| 무엇 | 핵심 | 출처 |
|---|---|---|
| 실제 두 손 검(롱소드) 쥐기 | 오른손은 날밑 바로 아래, 왼손은 손 하나~반 개 길이 아래 자루 끝(폼멜) 쪽. 오른손은 자루 위에서 거의 고정, 왼손은 기술에 따라 움직임. 보통 두 손은 거의 붙어 있음 | [ARMA 포럼 "Proper Parrying Technique"](https://www.thearma.org/forum/viewtopic.php?p=3239), [ARMA "Gripping the Pommel"](https://www.thearma.org/forum/viewtopic.php?p=26488), [Guy Windsor, Fiore 번역 #9 "The Six Grips"](https://www.guywindsor.net/?p=4359) |
| 게임 대검 대기 자세 | 무거운 대검은 칼날을 어깨에 걸치고 두 손으로 자루를 잡음. 왼팔이 늘어지면 어색해서 고친 사례가 있고, 대기 동작은 크게 흔들지 않음 | [Unreal 마켓 Greatsword Anims](https://docs.unrealengine.com/marketplace/ja/product/greatsword-anims), [Fab 대검 애니메이션 묶음](https://www.fab.com/listings/0dc2f903-17ce-4db0-9200-576cae9c1b47), [게임 대기 애니메이션 학생 블로그](https://yufeizheng.myblog.arts.ac.uk/?p=1024) |
| Roblox 도구 쥐기 | 도구 손잡이는 손의 그립 지점(R15 `RightGripAttachment`)에 맞춰 붙고, 방향은 `Tool.Grip`(GripPos·GripForward…) 한 CFrame이 정함. 좋은 값은 도구마다 직접 맞춰 봐야 함 | [Roblox 문서 "In-game tools"](https://create.roblox.com/docs/en-us/players/tools), [Tool.GripForward](https://create.roblox.com/docs/reference/engine/classes/Tool/GripForward), [DevForum "Tool grip is sideways"](https://devforum.roblox.com/t/tool-grip-is-sideways/1584419) |

**우리 place에서 잰 값(`place/GoodEvil.rbxlx` R15):** `RightGripAttachment` = 손 안 (0, -0.158, 0), 방향 Angles(-90°, 0, 0). 어깨 관절은 UpperTorso (±0.972, 0.598, 0)에 있어요. 위팔은 0.92, 아래팔은 0.81. 우리 무기는 `CharacterVisuals.fist()`로 손의 -Z(주먹을 꿰뚫는 축)를 따라 붙어요.

## 2. 이 참고로 정한 숫자 기준 (시험 `tools/test_two_hand_grip.py`)
1. **자루가 주먹을 지난다:** 손의 그립 지점과 손 중심에서 자루 선까지 거리가 0.2칸 이하예요.
2. **자루 축 = 손 쥐기 축:** 손의 -Z와 자루 방향 사이 각도가 10° 이하예요.
3. **팔뚝 위에 얹히지 않는다:** 아래팔 축과 자루 사이 각도가 45~135°예요. 지난 사진의 '손바닥 위에 올려놓은 느낌'은 자루가 팔뚝을 따라 누운 모습이었어요.
4. **두 손 위치:** 오른손이 날밑 쪽, 왼손이 그 아래 폼멜 쪽이에요. 두 손 간격은 손 크기만큼(0.45~0.8칸)이에요. 자루는 왼손보다 0.1칸 이상 길어요.
5. **대검 자세:** 칼자루는 가슴 앞에 있어요. 칼날은 위·뒤로 115~145° 올라가서 오른 어깨 바로 위(몸통 위 0.8보다 높게)를 지나요.
6. **팔이 닿는다:** 손목까지 거리가 팔 길이의 92% 이하예요(키 1·0.85 아바타, 큰 손·작은 손 모두). 안 닿으면 두 손 자세를 하지 않아요.

## 3. 만드는 법 (WeaponPose)
- 자세를 팔 각도에서 시작하지 않아요. **칼 위치에서 시작해요:** `Config.ClassGrips.Warrior_Horns.TwoHand` = { Hilt(오른손 그립 지점), Aim(칼날 방향) — 몸통 기준 }.
- 두 팔 모두 Fx의 두 마디 팔 계산(활과 같은 계산, 아바타의 실제 뼈 길이)으로 손을 그 자리에 놓아요. 손의 -Z는 칼날을 따라가고, +Y(손목 쪽)는 자기 어깨 쪽을 향해요.
- Studio 측정: 플레이어 속성 `GripProbe = true`이면 Studio에서만 2초마다 콘솔에 `[WeaponPose] probe <조합> | Right dHand=… dGrip=… axis=… fore=… | Left …`가 찍혀요(실제 부품에서 잼).

## 4. 다음 (같은 기준으로)
- A23-108 쥐기 9조합을 같은 probe로 다시 재고, 이상한 것 목록을 만들어요(fore가 45° 아래 = 팔뚝을 따라 누움, dHand가 0.2 넘음).
- 공격·스킬 몸짓의 쥐기도 같은 기준이에요.
