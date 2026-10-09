# 몬스터 / 보스 이미지 프롬프트 (GPT 이미지 → Tripo 3D용)

> 기록용(2026-10-02 무렵 GPT·Codex 그림 시절). 지금과 다른 점: 그림은 Adobe Firefly(시안 Medium, 최종 High), 큰 것은 앞·옆·뒤 그림 → Tripo, 재활용 금지, 빛살 금지('light rays' 쓰지 않음), 지형 텍스처도 Firefly 타일, BigSlime = 지금 Slime Prince·King Slime은 새 보스, 장인 길드는 베타에 없음 (최신: SPEC A23-7·47·57·80·84·96).
> 지금 기준: AGENTS.md(Art workflow) · SPEC_ADDENDUM A23 · RELEASE_PLAN. 프롬프트는 `art/prompts/<id>.txt`에 쓴다.

Tripo 3D가 잘 만들려면: **캐릭터 1명, 전신, 정면, 흰 배경, 그림자 없음, 팔 벌린 자세(A-포즈)**.
모든 프롬프트 앞에 아래 **공통 스타일**을 붙여서 돌리면 그림체가 통일돼요.

## 공통 스타일 (모든 프롬프트 앞에 붙이기)

```
Single game character, full body, front view, centered, standing in a relaxed A-pose with arms slightly away from the body, plain pure white background, no shadow, no text, no frame. Stylized chunky 3D game art, cute but slightly mischievous, big readable silhouette, simple shapes, smooth hand-painted textures, soft studio lighting, Roblox-friendly proportions (large head, short limbs), clean edges, suitable for image-to-3D conversion.
```

## 말랑 초원 (Lv 1+)

**말랑 슬라임** (`Slime`)
```
A small round green jelly slime monster, glossy translucent body with a tiny glowing crown-shard fragment floating inside, two big shiny cartoon eyes and a goofy open smile, slight drip at the bottom, bouncy squishy look.
```

**왕 슬라임** (`BigSlime`)
```
A large blue king slime monster, wobbly translucent jelly body, a small crooked golden crown sitting on top, a glowing crown-shard fragment visible inside the body, smug half-closed eyes and puffed cheeks, chubby and heavy-looking.
```

## 고블린 숲 (Lv 10+, PvP)

**고블린** (`Goblin`)
```
A short sneaky green goblin, big pointy ears, oversized grin with one tooth, ragged brown leather vest, holding a small wooden club, a stolen gold coin pouch tied to the belt, mischievous yellow eyes.
```

**고블린 우두머리** (`GoblinBrute`)
```
A big muscular dark-green goblin chieftain, tusks, war paint, crude iron shoulder armor made of pot lids, a necklace of shiny crown-shard pieces, holding a huge spiked wooden club, angry but comical expression.
```

## 해골 유적 (Lv 25+, PvP)

**해골 병사** (`Skeleton`)
```
A cartoon skeleton soldier, ivory bones, glowing cyan eye lights, rusty dented helmet a bit too big for its skull, cracked round wooden shield and a chipped short sword, clumsy but loyal look.
```

**해골 기사** (`SkeletonKnight`)
```
An armored skeleton knight, dark steel armor with purple glowing cracks, tattered dark-violet cape, horned helmet, wielding a long cursed greatsword, glowing violet eye lights, imposing heroic-villain silhouette.
```

## 이벤트 / 보스

**황금 거위** (`GoldenGoose`, 10분마다 교차로 마을에 등장. 기사단은 구조, 악당은 밀렵)
```
A sacred giant golden goose, shimmering gold feathers, a glowing crown-shard gem on its forehead, proud chest, wings slightly open, wearing a tiny royal red ribbon, magical sparkles, majestic and cute.
```

**해골왕** (`SkeletonKing`, 나중 업데이트용 월드 보스)
```
A huge skeleton king world boss, massive skull wearing a broken half of a giant golden crown (the Crown of Balance), long royal purple robe in tatters, bone throne-like shoulder spikes, holding a scepter with a cracked glowing crown shard, menacing but stylized.
```

## Tripo에서 받을 파일

- 형식: **FBX** 또는 **GLB**
- 폴리곤: 낮게 (로블록스 메시 1개당 최대 2만 삼각형, 5천~1만 권장)
- 텍스처 포함
- 이름은 위 괄호 안 영어 이름으로 (예: `Slime.fbx`). 그대로 게임 코드의 모델 자리에 끼워요.

---

# 캐릭터 말고 필요한 이미지 (우선순위 순)

이미지가 오면 Studio MCP의 `upload_image`로 로블록스에 올리고, 받은 `rbxassetid`를 Config에 넣어요. 그러면 코드가 쓰는 곳에 자동으로 들어가요.
아이콘은 **투명 배경 PNG, 정사각형 1024×1024**로 뽑아 주세요.

## 아이콘 공통 스타일 (아이콘 프롬프트 앞에 붙이기)
```
Game UI icon, single object centered, slight 3/4 angle, bold clean silhouette, thick dark outline, soft cel shading, vibrant colors, transparent background, no text, no frame, square, readable at 64x64 pixels, cute chunky fantasy style matching a Roblox game.
```

## 1순위 — 게임 아이콘 + 썸네일 (로블록스 노출에 제일 중요)

**게임 아이콘** (512×512, 정사각형, 배경 있음)
```
Roblox game icon, square, bold and readable at small size. A cute chunky knight with a glowing golden halo and a cute chunky villain with red horns face each other, grinning; between them floats a cracked golden crown shard shining. Gold vs crimson split background with sparkles. Cartoon 3D style, vibrant, high contrast, no text.
```

**썸네일 1** (1920×1080, 가로)
```
Wide game thumbnail, epic but cute. A giant broken golden crown floats in a sunset sky above a fantasy world of valleys and cliffs. On the left a small army of chunky golden-halo knights, on the right chunky red-horned villains; a villain runs away carrying a huge glowing sack of gold coins. Golden haze, dramatic light rays, Roblox-like chunky 3D cartoon style, no text.
```

**썸네일 2** (1920×1080, 괴수화)
```
Wide game thumbnail. A gigantic red-horned villain player transformed into a kaiju boss, glowing red, stomping in a dark forest, while a crowd of small chunky golden-halo heroes charge at it with swords, staffs and bows. Big damage numbers popping. Roblox-like chunky 3D cartoon style, high contrast, no text.
```

## 2순위 — 진영 문장 3개 (깃발·UI·이름표용)
```
Fantasy heraldry emblem, flat-shaded badge, symmetrical, bold shapes, transparent background, no text: [아래 하나]
- a radiant golden halo ring above a white shield with soft light rays (good faction "Knights of Light")
- a pair of curved crimson demon horns over a black spiked shield with ember glow (evil faction "Horn Legion")
- a teal cogwheel crossed with a hammer and a crown shard, warm brass rim (neutral faction "Artisan Guild")
```

## 3순위 — 무기 아이콘 21개 (직업 3 × 등급 7)
아이콘 공통 스타일 + 아래 문장. `[무기]` 자리에 넣어서 7번 돌리면 돼요(등급이 올라갈수록 더 화려하게).
```
a [무기] weapon icon, tier [N] of 7 — tier 1 is crude and plain, tier 7 is legendary with glowing crown-shard gems.
```
| 등급 | 전사(검) | 마법사(지팡이) | 궁수(활) |
|---|---|---|---|
| 1 | 나뭇가지 (a crooked tree branch used as a sword) | 마른 지팡이 (a dry twig staff) | 새총 활 (a slingshot-like tiny bow) |
| 2 | 나무 검 (wooden sword) | 참나무 지팡이 (oak staff) | 나무 활 (wooden bow) |
| 3 | 철 검 (iron sword) | 철 지팡이 (iron staff with a metal orb) | 철 활 (iron-reinforced bow) |
| 4 | 황금 검 (golden sword) | 황금 지팡이 (golden staff) | 황금 활 (golden bow) |
| 5 | 크리스탈 검 (ice-blue crystal sword) | 크리스탈 지팡이 (crystal staff) | 크리스탈 활 (crystal bow) |
| 6 | 네온 검 (glowing mint neon sword) | 네온 지팡이 (neon staff) | 네온 활 (neon bow) |
| 7 | 여명의 검 (white-gold, halo) / 파멸의 검 (black-crimson, horns) | 여명/파멸의 지팡이 | 여명/파멸의 활 |

## 4순위 — 화폐·아이템 아이콘
아이콘 공통 스타일 + 아래 각 줄.
```
- a shiny stack of gold coins (gold)
- a glowing blue experience orb (XP)
- a small sparkling cheer star (응원별)
- a golden ticket with a sword-staff-bow symbol (직업 변경권)
- a golden ticket with half halo / half horns symbol (진영 변경권)
- a bulging burlap sack overflowing with gold coins (원한 돈자루)
- a cracked golden crown shard crystal (왕관 조각)
- a wooden treasure chest bursting with light (보상 상자)
```

## 나중에 (거래소·제작 2단계 때) — 재료 아이콘
슬라임 점액, 고블린 송곳니, 해골 조각, 저주받은 천, 황금 깃털(거위), 광석 등. 재료 목록이 정해지면 프롬프트를 드릴게요.

## 지형 텍스처는 지금은 필요 없어요
로블록스 기본 지형 재질로 충분히 예뻐요. 나중에 "왕관 조각이 박힌 땅" 같은 특별한 바닥이 필요해지면 **이음새 없이 반복되는(tileable) 텍스처**로 따로 요청할게요.
