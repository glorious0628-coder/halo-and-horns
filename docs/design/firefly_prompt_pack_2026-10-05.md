# Firefly 프롬프트 모음 (2026-10-05)
> 기록용(10/05 당시). 지금과 다른 점: 모델은 Firefly 안의 GPT Image("Image 5 하나만" 아님), 시안 중간·고른 최종은 모두 고급(A23-47 보강 3), 프롬프트 1,000자 아래, 빛살·부채꼴 무늬 금지(AGENTS 10/07 — UIP_RewardRays·UIP_LootRays·UI_HatchRays·UIP_BannerGold 등 빛살·sunburst 문구는 쓰지 않음), 가판대 지붕·파라솔은 줄무늬 없이 단색(`remake_list_2026-10-09.md` P2), 장인(중립) 그림은 베타 뒤(A23-57), 게임 글은 영어만(A23-48, 한/영 두 벌 아님), 스킬은 Lv5·15·25에 저절로 배우고 기본 키 Z·X·C(스킬 선생님 없음, A23-49·A23-71·A23-78), 장소는 시안 묶음(A23-93)·기준 그림(`art/style_anchors/README.md`, A23-80).
> 지금 기준: AGENTS.md · SPEC_ADDENDUM A23 · RELEASE_PLAN.

> **사용 전에 꼭 읽기:** 아래 분야별 문구는 **초안**이다.
> - 쓰기 전에 §1의 REWRITE RULES로 고친다(부정문 삭제, 위험 단어 교체, 배경을 BG_GRAY로).
> - 문구는 §1의 블록(가족 블록 + 안전 줄 + 배경 + WORDLESS)으로 다시 조립하고, 약 700자 이하로 쓴다.
> - 사람은 반드시 MODEST 줄을 넣는다.
> - 브랜드·플랫폼 이름은 쓰지 않는다.
> - 모델은 Firefly Image 5 하나만 쓴다.

## 1. 공통 블록 (영어, 그대로 붙여 쓰기)

```text
HOW TO BUILD EVERY FIREFLY PROMPT (about 700 characters max; paste blocks verbatim so siblings match)
[1] ONE subject sentence, written positively, comes FIRST
+ [2] SAFETY line (MODEST for any human, including portraits, mannequins and sleeved hands; CREATURE for monsters, pets, eggs and pet forms)
+ [3] FACTION/SEASON token, if any
+ [4] ONE FAMILY block below
+ [5] the suffix: ONE background line + WORDLESS.
Model: Firefly Image 5 for the whole project. Content type Art, style presets and effects off, visual intensity medium.
Aspect ratios: 1:1 parts and icons; 16:9 strips and sheets; 3:4 class art, poster and card windows; 9:16 tall cards and banners.

FAMILY BLOCKS
UI_SYM: "Glossy 3D-rendered toy-like mobile game interface piece, chunky rounded shape, polished gold trim, thick even dark navy outline, glossy top highlight and slightly darker bottom bevel, soft light from the top left, crisp clean edges, front orthographic view, perfectly symmetrical, centered."
UI_ASYM (PanelHeader, Toast, StatusPlate, QuestRow, QuestTab, BtnPotion, WarMeterFrame, LogoPlate): same as UI_SYM, but end with "centered, the left and right ends are different exactly as described."
+ SLICE (every stretchable frame): "Even border thickness on all four sides, ornaments only in the four corners, plain straight edges between corners, large flat empty center."
+ LOUD (cards, buttons, banners only): "Bright saturated colors."
+ QUIET (HUD plates): "Muted deep navy tones, minimal ornament."
UI_TINT (Chip, BarFill, Star, Toggle): "Glossy 3D-rendered toy-like mobile game interface piece, chunky rounded shape, crisp clean edges, front orthographic view, centered, plain near-white color with soft light gray shading so it can be recolored in the game."
ICON (weapons, items, scrolls, potions, eggs, status/perk icons, shards): "Glossy 3D-rendered toy-like game icon, chunky rounded shapes with soft bevels, soft glossy toy plastic with polished metal and gem accents, bright saturated kid-friendly colors, soft light from the top left, thick even dark navy outline around the whole silhouette, glow and sparkles painted inside the outline, one object centered filling 80 percent of a square, three-quarter front view."
- Weapons: replace "three-quarter front view" with one fixed line.
  - SWORD: "laid diagonally at 45 degrees, grip bottom-left, blade tip top-right"
  - STAFF: "laid diagonally at 45 degrees, staff foot bottom-left, head top-right"
  - BOW: "laid diagonally at 45 degrees, limbs running bottom-left to top-right, grip at center, taut string on the lower-right side, the bow alone"
- SKILL variant: "...filling 75 percent of a square, sized to sit inside a round button, the effect alone."
- MAP variant: "...slight top-down front view, warm storybook colors that stand out on cream paper."
- BADGE variant: "...front view, symmetrical, bold shapes that read at 24 pixels."
- Jelly, crystal and spirit flame always: "glossy opaque color with white highlights, solid all the way through."
STICKER: "Cute glossy cartoon sticker with a thick white die-cut border and a thin dark navy outline, bold simple shape, centered filling 80 percent of a square."
GLYPH: "Single chunky game interface glyph: white fill, thick even dark navy outline, soft pale gold shading, bold simple silhouette readable at 32 pixels, centered, front view, the glyph alone."
HUMAN: "3D-rendered blocky toy-avatar character with a cube-shaped head, one straight rectangular block torso and rectangular arms and legs, identical body for every character, simple painted cartoon face with dot eyes and a small smile, soft glossy toy plastic, soft even studio light, crisp silhouette, kid-friendly."
MODEST (immediately after the subject): "Wears a modest outfit that fully covers the body: high collar covering the neck, long sleeves to the wrists, gloves, full-length trousers or a knee-length tabard or skirt over full-length trousers, boots; only the face and hands show."
- Female figures: put "one straight rectangular block torso identical to the male version" in the first sentence, and attach the approved male image as Structure reference at about 70.
- Framing lines:
  - CLASS: "Full-body heroic standing pose, slight three-quarter view, whole figure in frame."
  - PORTRAIT: "Head-and-shoulders portrait, slight three-quarter turn, face filling the upper half."
  - TRIPO: "Full-body front view, symmetrical relaxed A-pose, arms angled away from the body, feet apart, props held clear of the body, flat even lighting, whole figure in frame with margin." Leave floating rings and gears out of Tripo inputs; they are built in-game.
CREATURE: "Cute chunky toy-figure creature, round soft shapes, glossy opaque toy-vinyl material, big round eyes with pupils and white shine highlights, small happy smile, rosy cheeks, bright cheerful colors, soft even studio light, crisp silhouette."
SCENE (thumbnails, game icon, loading, welcome, nest, concept scenes): "Bright 3D-rendered toy-like fantasy game scene, chunky rounded props, soft warm light, cozy and cheerful, kid-friendly." Every person in it gets HUMAN + MODEST in short form.
CONCEPT (3D reference sheets; never uploaded or cut apart): "Clean 3D-rendered concept view, flat even studio light, same scale, evenly spaced, each piece fully visible, outline-free." Weapon sheets add: "the sword, the staff and the bow standing upright side by side, flat orthographic side view."
FX: "A single soft glowing shape, pure white." (then BG_BLACK; convert luminance to alpha locally and tint in Roblox)
TILE (the 15 terrain textures): "Seamless tileable square ground texture seen straight from above, even flat lighting, hand-painted stylized toy-like game texture, chunky readable shapes, edges that wrap perfectly on all four sides."

FACTION / SEASON TOKENS
- HALO: "ivory, warm gold and sky-blue, round friendly shapes, a floating gold ring". Use "radiant" or "light knight".
- HORNS: "plum-charcoal, crimson and ember-orange, triangle shapes with rounded tips, two short chunky rounded horns, cheeky prankster grin"
- ARTISAN: "teal, brass and warm wood, boxy practical shapes, a chunky rounded gear"
- HALLOWEEN: "pumpkin orange, purple and lavender, smiling pumpkin faces with big round eyes and a soft curved smile, cozy and cute"
- WINTER: "icy blue, white and pine green with red berries, cozy"

REWRITE RULES (apply to every area prompt before use)
1. Delete every "no X / not X / without X" phrase. Keep those items only as QA notes, or in Firefly's Exclude field if the model shows one.
2. Never write these words, even negated: skull, blood, gore, fang, demon, devil, villain army, occult, sigil, pentagram, altar, rune, holy, cursed, scary, jack-o'-lantern, speech bubble, label, sign, logo, emoji, swoosh, sneaker, brick, minifigure, building-block, transparent, translucent, or any brand or platform name. "skeleton" may appear only in a Skeleton monster's own subject sentence.
3. Swaps:
   - holy knights → light knights
   - cartoon villain army/faction → mischievous prankster crew
   - little-devil form → cheeky imp costume
   - jack-o'-lantern → smiling pumpkin face with big round eyes and a soft curved smile, warm glow
   - (semi-)translucent jelly → glossy opaque jelly with soft inner highlights and white shine spots
   - magic circle → glowing ring of simple dots and circles
   - carved floor sigil → round carved stone floor medallion split straight down the middle
   - stone altar → small rounded stone pedestal
   - stained-glass rose window → round colorful glass medallion with a gold ring and feather pattern
   - fang tooth → big smooth rounded cream tooth
   - Emo_Ouch bubble → white jagged starburst shape with a large flat empty center
   - emoji face → round cartoon face sticker
   - sneaker with swoosh → winged boot with three curved wind lines (one shared speed icon)
   - book → blank pages
   - wax seal → plain unmarked wax seal with a simple raised arrow shape
   - bottle → unlabeled bottle
   - awning → plain striped awning
   - Map_SkeletonRuins → broken pale stone pillars and an archway with a soft purple flame
4. Asset fixes:
   - CON_SkeletonKing: "round toy-like head with big round eyes with pupils and white shine, rosy cheek dots, a grumpy-funny frown, long purple robe covering the body".
   - CON_LittleGhost and CON_PumpkinKing: "big round eyes with pupils and white shine".
   - Thumb_C goblin: "a goblin wearing a purple bat-ear hood and a bat-wing costume cape, holding a pumpkin candy bucket".
   - Thumb_B: "a big blue king slime".
   - Any baby slime: copy the approved Pet_BabySlime description and attach it as reference.
   - Thumb_A and Thumb_B people: "varied everyday blocky toy avatars with small glowing gold rings or small rounded horns, holding a sword, a staff and a bow".
   - UIP_SlotEpic: "amethyst gem with four small gold corner stars".
   - All UIP_Slot inners: the light inner color chosen on the style board.
   - UIP_BannerGold: ribbon only; the rays come from the UIP_RewardRays layer.
   - Skill_Archer_X: "a swirling green wind ring around a single arrow".
   - Pet UI parts: use UI_SYM + SLICE, not the soft-painted brown block.
   - Blank faction cards: attach the approved FreshTyped card with its text regions masked as Structure reference (50-60) and Style reference (about 70); keep 570x954.

BACKGROUND (pick exactly one, verbatim)
- BG_GRAY, the default for every cut-out (UI parts, icons, glyphs, badges, map markers, stickers, creatures, characters, including white, cream and ivory subjects): "Isolated on a plain flat medium gray background with a wide empty margin, soft even light, clean shadowless backdrop."
- BG_WHITE, only for gray, silver, stone, bone or dark-gray subjects: "Isolated on a plain flat pure white background with a wide empty margin, soft even light, clean shadowless backdrop."
- BG_BLACK, only for FX and the sun and moon: "On a plain pure black background, nothing else in the frame."
  - FX: convert luminance to alpha.
  - Sky textures stay on black (additive blend), with no cutout.
- FULL, for opaque scenes, thumbnails, game icon, loading art, map parchment, banners and terrain tiles: "Filling the whole frame edge to edge."
- Never use navy, charcoal or slate behind a dark-outlined subject.

WORDLESS (always the final words): "Wordless, blank unmarked surfaces."

EXCLUDE field (only if the chosen Firefly model shows one): text, letters, numbers, watermark, logo, signature.

FIRST-SESSION CHECK (during the style board)
- Run 2x4 variants on one UI part and one icon: the WORDLESS tail alone vs. WORDLESS plus the Exclude field. Keep the cleaner one verbatim from then on.
- Record the Firefly credit balance.
- Time the first 5 assets end to end and re-plan the beta cut from that rate.
```

## 2. 분야별 그림 목록과 초안 문구

### 2-1. UI·HUD

#### UIP_FactionCardHalo — 진영 카드 – 빛의 기사단 (빈 판)
- 용도: 진영 선택 카드 배경. 이름·한 줄 설명·혜택·'이 편으로' 버튼은 게임 글자/버튼으로 올림. 승인된 FreshTyped 카드(글자 박힘, 옛 '발사' 문구) 대체
- 크기: 570x954 (9:16 생성 후 다듬기) · 투명 · 시점: beta · 3D: False
- 검사·거절: 제외칸: text, letters, people. 거절: 리본·판에 글자 흔적, 세 카드 외곽 크기·리본 높이 불일치, 6px보다 가는 장식이 폰에서 뭉개짐, 누끼 후 검은 테두리 찌꺼기.
```text
Tall vertical game card frame for a holy knights faction: ivory white marble and polished gold frame, a large golden radiant sun emblem with a floating golden halo ring and small white feathered wings at the top, gold laurel leaves, slim gold spires on both sides, an empty cream ribbon banner across the upper third, a large empty cream panel filling the lower half, small empty space at the bottom edge. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background, no ground shadow.
```

#### UIP_FactionCardHorns — 진영 카드 – 뿔 군단 (빈 판)
- 용도: 진영 선택 카드 배경. 해골 문양 대신 만화 뿔 투구(어린이 안전·모더레이션)
- 크기: 570x954 (9:16 생성 후 다듬기) · 투명 · 시점: beta · 3D: False
- 검사·거절: 제외칸: skull, teeth, blood, scary eyes, text. 거절: 무서운 느낌, 해골처럼 보이는 투구, 글자 흔적, 빛 카드와 크기 불일치.
```text
Tall vertical game card frame for a mischievous cartoon villain faction: dark volcanic stone frame with glowing orange lava cracks, crimson and polished gold trim, ruby gems, a big friendly cartoon horned helmet crest at the top with two glossy curved red horns, no skull, not scary, an empty crimson ribbon banner across the upper third, a large empty dark slate panel filling the lower half, small empty space at the bottom edge. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_FactionCardArtisan — 진영 카드 – 장인 길드 (빈 판)
- 용도: 진영 선택 카드 배경(중립 청록·황동·나무, 톱니와 모루)
- 크기: 570x954 (9:16 생성 후 다듬기) · 투명 · 시점: beta · 3D: False
- 검사·거절: 제외칸: text, letters, people. 거절: 판이 회색으로 보임(회색은 '회색 전설' 전용), 다른 두 카드와 크기 불일치.
```text
Tall vertical game card frame for a craftsmen guild faction: warm wooden frame with brass and polished gold trim, teal enamel inlays and teal gems, a shield emblem at the top with a golden gear and a small anvil, two hanging teal pennants with leaf patterns on the sides, an empty cream ribbon banner across the upper third, a large empty cream panel filling the lower half, small empty space at the bottom edge. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_FactionTitle — 진영 화면 제목 리본 (빈 판)
- 용도: '어느 편에 설래?' 제목 바탕. 글자는 게임 글자
- 크기: 1024x210 (16:9 생성, 리본만 작게) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 가운데 무늬(글자 가독성), 꼬리 끝 장식이 잘림, 글자 흔적.
```text
One wide horizontal title ribbon banner with folded tails, warm cream ribbon with polished gold edges, a small cracked golden crown ornament on top center, the left tail tipped with a tiny golden halo ring and the right tail tipped with a tiny red cartoon horn, completely empty flat center. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background, no ground shadow.
```

#### UIP_FactionPremise — 세계관 설명판 (빈 판)
- 용도: 오프닝 세 줄 이야기 판. 9조각
- 크기: 1024x174 (16:9 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 곧은 변에 장식(늘이면 늘어남), 가운데 질감·그라데이션 얼룩.
```text
One wide horizontal story plaque, deep navy blue panel with polished gold border, small glowing golden crown-shard gems in the four corners. Even border thickness on all four sides, ornaments only in the four corners, plain straight edges between corners, large completely empty flat center. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_FactionFooter — 진영 화면 하단 안내 띠 (빈 판)
- 용도: '나중에 제단에서 바꿀 수 있어요' 안내 바탕
- 크기: 1024x126 (16:9 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 테두리 두께 불균일, 끝 보석이 몸통보다 커서 9조각 모서리가 너무 넓어짐.
```text
One very wide slim footer bar, deep navy capsule with thin polished gold border and a tiny sapphire gem at each end, completely empty flat center. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_ClassCardHalo — 직업 카드 – 빛 (빈 판)
- 용도: 직업 선택 카드 배경. 창 안에 직업 그림(캐릭터 분야), 이름은 게임 글자
- 크기: 640x1024 (9:16 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 제외칸: people, text. 거절: 창 안에 인물·풍경이 그려짐, 세 장 창 위치 불일치.
```text
Tall vertical character selection card frame: ivory and polished gold frame with a small golden halo ring at the top, a large empty arched window in the upper two thirds filled with a soft pale sky-blue gradient, an empty gold-edged name plate below the window, a small empty cream strip at the bottom. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background, no ground shadow.
```

#### UIP_ClassCardHorns — 직업 카드 – 뿔 (빈 판)
- 용도: 직업 선택 카드 배경(뿔 진영)
- 크기: 640x1024 (9:16 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 제외칸: skull, people, text. 거절: 무서운 장식, 다른 카드와 창 위치 불일치.
```text
Tall vertical character selection card frame: dark slate stone and crimson frame with polished gold trim and two small cute red cartoon horns at the top, a large empty arched window in the upper two thirds filled with a soft deep plum gradient, an empty crimson name plate below the window, a small empty dark strip at the bottom. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_ClassCardArtisan — 직업 카드 – 장인 (빈 판)
- 용도: 직업 선택 카드 배경(장인 길드)
- 크기: 640x1024 (9:16 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 제외칸: people, text. 거절: 다른 카드와 창 위치 불일치.
```text
Tall vertical character selection card frame: warm wood, brass and teal frame with a small golden gear at the top, a large empty arched window in the upper two thirds filled with a soft teal gradient, an empty teal name plate below the window, a small empty cream strip at the bottom. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_PanelMain — 기본 창 틀
- 용도: 모든 창(상점·대장간·아이템·환생·제단·직업 변경·휴가 보상·환영·닉네임) 공통 바탕. Parts.PanelParchment 키 자리에 넣으면 코드 수정 최소
- 크기: 768x576 (4:3 생성, 9조각 모서리 >= 96) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 크림 속지에 종이 질감·얼룩(늘이면 번짐), 네 변 두께 다름, 곧은 변 장식.
```text
One rectangular game menu window frame with rounded corners: thick deep navy blue rim with a polished gold trim line, small sapphire gem studs in the four corners, warm cream inner panel. Even border thickness on all four sides, ornaments only in the four corners, plain straight edges between corners, large completely empty flat center. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_PanelDark — 어두운 판
- 용도: HUD 카드·목록 영역·초상화 뒤 바탕. Parts.PanelCard 대체
- 크기: 512x384 (4:3 생성, 9조각) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 장식 과다(HUD는 얇게), 가운데 광택 줄이 늘이면 이상하게 보임.
```text
One rounded rectangle dark navy blue plate with a thin polished gold edge and a slightly lighter navy inner area, minimal and clean. Even border thickness on all four sides, ornaments only in the four corners, plain straight edges between corners, large completely empty flat center. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_PanelHeader — 창 머리띠
- 용도: 창 제목 줄. 왼쪽 동그라미에 진영 문장/아이콘, 제목은 게임 글자. Parts.RibbonHeader 대체
- 크기: 1024x160 (16:9 생성, 가로 9조각) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 동그라미 안에 그림, 오른쪽 끝에도 동그라미(좌우 대칭 강요), 글자 흔적.
```text
One wide horizontal header bar for a menu window: deep navy capsule with polished gold border, a round empty gold-rimmed socket on the left end for a badge, completely plain flat navy center stretching to the right end. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_TitleRibbon — 제목 리본
- 용도: 큰 제목(레벨 업·환생·닉네임·축하). Parts.TitleRibbon 대체
- 크기: 1024x200 (16:9 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 리본 가운데 주름·그림자(글자 가림).
```text
One wide horizontal ribbon banner with folded tails on both ends, warm cream ribbon with polished gold edges, completely empty flat center. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background, no ground shadow.
```

#### UIP_TabOn — 탭 – 선택됨
- 용도: 아이템/무기/펫 같은 창 안 탭. 글자는 게임 글자
- 크기: 256x112 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 아래 변이 둥금(창 머리에 붙지 않음), 꺼짐 탭과 모양 다름.
```text
One single menu tab shape with rounded top corners and a flat bottom edge, bright golden yellow face with a glossy highlight, completely empty face. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_TabOff — 탭 – 꺼짐
- 용도: 선택 안 된 탭
- 크기: 256x112 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 켜짐 탭과 외곽 모양·크기 불일치.
```text
One single menu tab shape with rounded top corners and a flat bottom edge, muted slate blue matte face with a thin gold edge, completely empty face. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_BtnPrimary — 주요 버튼 (금색)
- 용도: 사기·확인·장착 등 주요 행동. 글자는 게임 글자. 가로 9조각
- 크기: 512x176 (16:9 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 제외칸: text, icon. 거절: 얼굴에 무늬, 다른 두 색 버튼과 모양·두께 다름.
```text
One single wide capsule game button: bright golden yellow face with a warm orange lower edge, glossy white highlight strip along the top, chunky 3D bottom lip, completely empty face. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_BtnSecondary — 보조 버튼 (파랑)
- 용도: 취소·뒤로·보조 행동
- 크기: 512x176 (16:9 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 금색 버튼과 모양 다름.
```text
One single wide capsule game button: friendly sky blue face with a deeper blue lower edge, glossy white highlight strip along the top, chunky 3D bottom lip, completely empty face. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_BtnConfirm — 받기 버튼 (초록)
- 용도: 퀘스트 보상 받기·완료
- 크기: 512x176 (16:9 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 금색 버튼과 모양 다름.
```text
One single wide capsule game button: fresh grass green face with a deeper green lower edge, glossy white highlight strip along the top, chunky 3D bottom lip, completely empty face. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_BtnSquare — 네모 아이콘 버튼
- 용도: 오른쪽 위 [가방][지도][메뉴] 줄, 메뉴 격자 버튼 바탕. Parts.BtnSquare 대체
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 가운데 아이콘·무늬, 너무 화려한 모서리(HUD용).
```text
One single rounded square game icon button: deep navy blue face, polished gold rim, glossy top highlight, chunky 3D bottom lip, completely empty face. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_BtnRound — 동그라미 작은 버튼
- 용도: 닫기(X)·뒤로(←)·정보 버튼 바탕. 글리프를 위에 얹음
- 크기: 160x160 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 원이 찌그러짐, 네모 버튼과 테두리 굵기 다름.
```text
One single small round game button: deep navy blue face, polished gold rim, glossy top highlight, chunky 3D bottom lip, completely empty face. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_ListRow — 목록 줄
- 용도: 상점·대장간·아이템·펫 줄 바탕(아이콘 칸+이름+가격은 위에 얹음). 가로 9조각
- 크기: 1024x160 (16:9 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 줄 안 칸 나눔·무늬, 크림이 노랗게 번짐.
```text
One very wide horizontal list row plate with rounded corners: warm cream face with a thin soft tan border and a slight inner shadow. Even border thickness on all four sides, ornaments only in the four corners, plain straight edges between corners, large completely empty flat center. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background, no ground shadow.
```

#### UIP_ListRowSelected — 목록 줄 – 선택됨
- 용도: 고른 줄·장착 중 표시
- 크기: 1024x160 (16:9 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 기본 줄과 외곽 크기 다름, 빛이 가운데까지 번짐.
```text
One very wide horizontal list row plate with rounded corners: warm cream face with a bright glowing golden border and a soft golden inner glow. Even border thickness on all four sides, ornaments only in the four corners, plain straight edges between corners, large completely empty flat center. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background, no ground shadow.
```

#### UIP_InputField — 입력 칸
- 용도: 닉네임 입력(TextBox 바탕)
- 크기: 1024x160 (16:9 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 연필·커서 그림, 글자 흔적.
```text
One very wide text input box with rounded corners: clean white inner field with a soft inset shadow, deep navy outline and a thin polished gold rim, completely empty. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background, no ground shadow.
```

#### UIP_Chip — 칩 (색 입히는 알약)
- 용도: 상태 칩(안전 초록/PvP 주황/극한 빨강/새싹 하늘), 지역 이름, 가격표, 등급 이름. 게임에서 색 입힘. Parts.Pill 대체
- 크기: 512x128 (16:9 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 색이 들어감(색 입히기 불가), 금테가 붙음.
```text
One small wide capsule label chip: plain very light gray face with a white glossy highlight and a dark navy outline, completely empty. Glossy casual mobile game UI asset, chunky rounded toy-like shape, crisp clean vector-like rendering, front orthographic view, centered, symmetrical, plain neutral light colors so it can be recolored in the game. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background, no ground shadow.
```

#### UIP_BadgeDot — 새 소식 점
- 용도: 새 버튼·받을 보상·새 아이템 표시. 숫자는 게임 글자
- 크기: 96x96 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 빨간색(빨강은 위험·뿔 전용), 느낌표 박힘.
```text
One small round notification badge: bright orange-gold circle with a white rim and a dark navy outline, glossy, completely empty center. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_Toast — 알림 줄
- 용도: 화면 위 가운데 알림(획득·퀘스트 갱신·좋은 아이템). 왼쪽 동그라미에 아이콘
- 크기: 1024x128 (16:9 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 몸통이 너무 두꺼움(화면 가림), 동그라미 안 그림.
```text
One very wide slim notification capsule: deep navy blue body with a thin polished gold edge, a round empty gold-rimmed socket on the left end for an icon, plain flat center. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_BannerGold — 큰 축하 배너
- 용도: 레벨 업·지역 들어가기·해금·희귀 획득 등 큰 순간. 글자는 게임 글자
- 크기: 1536x384 (16:9 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 빛살이 누끼 후 검은 테두리로 남음(빛살은 따로 RewardRays로 대체 가능), 가운데 무늬.
```text
One wide celebratory announcement banner: polished golden ribbon with small white wings on both ends and soft golden light rays fanning out behind it, completely empty flat center for a message. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background, no ground shadow.
```

#### UIP_BannerAlert — 경고 배너 (빨강)
- 용도: 괴수 출현 사이렌·PvP 지역 경고·현상수배. 빨강은 위험 전용
- 크기: 1536x320 (16:9 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 제외칸: skull, blood. 거절: 해골·피 장식, 글자 흔적.
```text
One wide alert announcement banner: bold crimson red ribbon with a dark navy outline, polished gold edges and small orange warning chevrons at both ends, completely empty flat center. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_RewardRays — 보상 빛살
- 용도: 드랍 팝업·펫 얻기·레벨 업 뒤에서 천천히 도는 빛살(등급색으로 칠할 수 있음)
- 크기: 512x512 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 빛살 간격 불균일(돌릴 때 흔들려 보임), 누끼 후 빛 끝이 검게 남음 — 필요하면 밝기 기준 알파로 따로 만든다.
```text
One radiant circular sunburst of soft golden light rays with tiny white sparkles, evenly spaced rays, empty center. Glossy casual fantasy mobile game effect, front view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background, no ground shadow.
```

#### UIP_SlotCommon — 아이템 칸 – 일반
- 용도: 아이템·무기·드랍 팝업 칸(등급 B1·B2). 아이콘은 위에 얹음
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 다섯 등급 칸의 바깥 크기·안쪽 구멍 크기 다름.
```text
One rounded square item slot frame: plain silver gray rim, dark navy recessed inner area, completely empty inside. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_SlotUncommon — 아이템 칸 – 고급
- 용도: 고급(초록) 등급 칸, 잎 장식
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 일반 칸과 크기 다름, 장식이 안쪽 구멍을 가림.
```text
One rounded square item slot frame: bright green rim with two small leaf studs on the top corners, dark navy recessed inner area, completely empty inside. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_SlotRare — 아이템 칸 – 희귀
- 용도: 희귀(파랑) 등급 칸, 사파이어
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 다른 등급 칸과 크기 다름.
```text
One rounded square item slot frame: bright blue rim with a small sapphire gem at the top center, dark navy recessed inner area, completely empty inside. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_SlotEpic — 아이템 칸 – 영웅
- 용도: 영웅(보라) 등급 칸, 자수정과 작은 날개
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 날개가 칸 밖으로 너무 나감(목록 간격 깨짐).
```text
One rounded square item slot frame: vivid purple rim with an amethyst gem at the top center and tiny wing tips on the upper corners, dark navy recessed inner area, completely empty inside. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_SlotLegendary — 아이템 칸 – 전설
- 용도: 전설(주황) 등급 칸, 왕관과 반짝임. 게임에서 반짝임 그라데이션 추가
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 왕관이 너무 커서 아이콘을 가림, 다른 등급과 크기 다름.
```text
One rounded square item slot frame: radiant orange-gold rim with a small golden crown at the top center and four tiny star sparkles on the corners, dark navy recessed inner area, completely empty inside. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_SlotEmpty — 빈 아이템 칸
- 용도: 빈 장착 칸·잠긴 칸·펫 도감 빈자리
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 등급 칸과 크기 다름.
```text
One rounded square empty item slot: dark navy recessed inset with a soft inner shadow and a thin muted gold edge, completely empty inside. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_StarFull — 별 (채움)
- 용도: 무기 희귀도 별 1~5. IconStar 대체
- 크기: 128x128 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 빈 별과 모양 다름, 끝이 뾰족해 작게 보면 가시처럼 보임.
```text
One single chunky five-point star: glossy golden yellow with a bright highlight and a dark navy outline. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_StarEmpty — 별 (빈)
- 용도: 남은 희귀도 자리. IconStarEmpty 대체
- 크기: 128x128 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 채움 별과 외곽 크기 다름.
```text
One single chunky five-point star shape: dull dark gray-blue face, dark navy outline, matte, no shine. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_DialogBox — 대화창
- 용도: 이야기 퀘스트 대화(장 시작·장 끝·선택). 선택 버튼은 BtnPrimary/Secondary
- 크기: 1536x360 (16:9 생성, 9조각) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 말풍선 꼬리(위치 고정됨), 종이 질감.
```text
One very wide dialogue box with rounded corners: warm cream panel with a deep navy rim, a thin polished gold trim line and small gold corner studs. Even border thickness on all four sides, ornaments only in the four corners, plain straight edges between corners, large completely empty flat center. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_NameTag — 이름표
- 용도: 대화창 위 말하는 이 이름·펫 이름·NPC 이름. 진영색 글자는 게임에서
- 크기: 512x112 (16:9 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 끝 장식이 커서 짧은 이름에 9조각 안 맞음.
```text
One small wide name plate capsule: deep navy face with a polished gold rim, completely empty. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_PortraitFrame — 초상화 틀
- 용도: 대화창 왼쪽 NPC 초상화 자리(NPC 그림이 생기는 정식부터)
- 크기: 384x384 (1:1 생성) · 투명 · 시점: launch · 3D: False
- 검사·거절: 제외칸: people, face. 거절: 창 안에 인물.
```text
One rounded square portrait frame: polished gold rim with small sapphire studs in the corners, an empty window filled with a soft pale blue gradient. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_StatusPlate — HUD 상태판
- 용도: 왼쪽 위 내 상태판: 왼쪽 동그라미에 3D 얼굴 링+레벨 배지, 오른쪽에 HP·MP·XP 바와 골드. 가로 9조각
- 크기: 768x224 (16:9 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 판이 두껍고 화려해 세상을 가림, 바 자리가 그려져 있음(바는 따로).
```text
One wide rounded rectangle status plate for a game HUD: dark navy blue body with a thin polished gold edge, a large round empty gold-rimmed socket on the left end, plain flat center area to the right. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_BarTrack — 바 틀
- 용도: HP·MP·XP·퀘스트·강화 진행 바의 빈 틀. Parts.BarTrack 대체
- 크기: 1024x96 (16:9 생성, 가로 9조각) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 안에 눈금·채움색, 끝 장식이 커서 짧은 바에 안 맞음.
```text
One very wide empty progress bar track: dark navy recessed capsule groove with a thin polished gold rim, completely empty inside. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_BarFill — 바 채움 (흰색, 색 입힘)
- 용도: 바 채움 하나를 HP 초록(30% 아래 빨강)·MP 파랑·XP 하늘·전쟁 금/빨강으로 칠해 씀
- 크기: 1024x64 (16:9 생성, 가로 9조각) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 색이 들어감, 외곽선 있음(틀 안에 겹쳐 두꺼워짐).
```text
One very wide progress bar fill capsule: plain white to light gray with a glossy white highlight along the top and soft gray shading at the bottom, no outline. Glossy casual mobile game UI asset, chunky rounded toy-like shape, crisp clean vector-like rendering, front orthographic view, centered, symmetrical, plain neutral light colors so it can be recolored in the game. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background, no ground shadow.
```

#### UIP_LevelBadgeHalo — 레벨 배지 – 빛
- 용도: 상태판 레벨 숫자 바탕(빛의 기사단). 숫자는 게임 글자
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 가운데 원이 작아 'Lv 100' 세 자리가 안 들어감, 다른 진영 배지와 원 크기 다름.
```text
One round level badge medallion: ivory and polished gold with a floating golden halo ring above it and tiny white wings on both sides, a large empty flat ivory center circle. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background, no ground shadow.
```

#### UIP_LevelBadgeHorns — 레벨 배지 – 뿔
- 용도: 레벨 숫자 바탕(뿔 군단)
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 제외칸: skull. 거절: 무서운 느낌, 원 크기 불일치.
```text
One round level badge medallion: dark slate stone with a crimson ring and polished gold rim, two small glossy red cartoon horns on top, a large empty flat dark center circle. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_LevelBadgeArtisan — 레벨 배지 – 장인
- 용도: 레벨 숫자 바탕(장인 길드)
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 톱니가 가늘어 작게 보면 지저분함, 원 크기 불일치.
```text
One round level badge medallion shaped like a golden gear: teal enamel ring and brass rim, a large empty flat teal center circle. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_LevelBadge — 레벨 배지 – 무소속
- 용도: 진영 고르기 전·공용 레벨 배지. Parts.LevelBadge 대체
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 진영 배지들과 원 크기 다름.
```text
One round level badge medallion: deep navy with a polished gold rim and four small sapphire studs, a large empty flat navy center circle. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_PortraitRing — 얼굴 링
- 용도: 상태판의 3D 아바타 ViewportFrame 테두리. Parts.PortraitRing 대체
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 가운데가 채워져 누끼 후 구멍이 안 뚫림 — 구멍 안 흰색을 반드시 제거 확인.
```text
One round portrait ring frame: polished gold ring with a deep navy outer edge and four tiny sapphire studs, completely empty see-through center hole. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_BtnAttack — 공격 버튼
- 용도: 오른쪽 아래 큰 공격 버튼(150). 위에 직업 글리프(칼/지팡이/활). Parts.BtnAttack 대체
- 크기: 512x512 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 제외칸: sword, icon, text. 거절: 칼이 박힘, 빨간색(뿔·위험 전용), 스킬 버튼과 테두리 다름.
```text
One large round action button: glossy warm orange-gold face with a bright highlight on top, thick polished gold rim, chunky 3D bottom lip, completely empty face. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_BtnSkill — 스킬 버튼 (Q·Z)
- 용도: MP 스킬 버튼(96). 파랑 = MP와 같은 색. 쿨다운 부채꼴은 게임에서. Parts.BtnSpecial 대체
- 크기: 384x384 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 공격 버튼과 테두리 굵기·광택 방향 다름, 아이콘 박힘.
```text
One round skill button: glossy royal blue face with a bright highlight on top, polished gold rim, chunky 3D bottom lip, completely empty face. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_BtnPotion — 물약 칸 버튼
- 용도: 공격 버튼 왼쪽 HP·MP 물약 칸(72). 물약 아이콘은 아이콘 분야, 오른쪽 아래 작은 원에 남은 개수
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 개수 원이 버튼 밖으로 너무 나감, 물약 그림 박힘.
```text
One small round quick-slot button: deep navy recessed face, polished gold rim, a tiny empty round socket on the lower right edge, completely empty face. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_AutoRingOn — 자동 켜짐 고리
- 용도: 자동 전투가 켜지면 자동 버튼 둘레에서 도는 금빛 화살 고리(A23-1)
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 고리가 원이 아님(돌리면 흔들림), 가운데 막힘.
```text
One circular ring made of two glowing golden curved arrows chasing each other, small sparkles, completely empty center hole. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background, no ground shadow.
```

#### UIP_WarMeterFrame — 전쟁 미터 틀
- 용도: 위 가운데 빛↔뿔 줄다리기 미터. 채움은 BarFill 금/빨강, 숫자·타이머는 게임 글자
- 크기: 1536x192 (16:9 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 끝 문장이 너무 커서 폰 360px 폭에서 트랙이 짧아짐, 트랙 안 채움색.
```text
One very wide tug-of-war meter frame for a game HUD: long empty dark navy capsule track with a polished gold rim, a golden halo ring emblem cap on the left end and a cute red cartoon horns emblem cap on the right end, a small empty diamond notch at the exact center. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_WarCrownPip — 전쟁 미터 왕관 표시
- 용도: 전쟁 미터 위 현재 균형점 표시
- 크기: 128x128 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 32px에서 왕관으로 안 읽힘.
```text
One small chunky golden crown marker with a short pointer underneath, glossy. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_QuestRow — 퀘스트 줄
- 용도: 오른쪽 가운데 퀘스트 판의 한 줄(왼쪽 목표 아이콘, 가운데 글+진행, 오른쪽 받기 자리)
- 크기: 1024x176 (16:9 생성, 가로 9조각) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 줄이 두꺼워 폰에서 2줄이 안 들어감, 소켓 안 그림.
```text
One wide rounded quest tracker row plate: dark navy blue body with a thin polished gold edge, a round empty icon socket on the left end and a small empty capsule socket on the right end, plain flat center. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_QuestTab — 퀘스트 판 머리 탭
- 용도: 퀘스트 판 접기/펴기 탭('퀘스트' 글자는 게임 글자)
- 크기: 384x96 (16:9 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 화살표가 가운데(글자 자리 침범).
```text
One small wide header tab: polished golden capsule with a small downward chevron on the right end, completely empty center. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_NpcMarkerBubble — NPC 머리 위 표시 말풍선
- 용도: 안내자·상점·스킬 선생님·물약 상인 머리 위 금빛 말풍선(안에 ! 또는 가방·물약·별 아이콘). 첫 10분 길 찾기
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 꼬리가 옆으로 휨, 안에 기호 박힘.
```text
One round floating marker bubble with a short pointer at the bottom: glossy golden yellow face with a white rim and dark navy outline, completely empty center. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_GlyphSword — 흰 아이콘 – 칼 (전사 공격)
- 용도: 전사 공격 버튼 위 글리프
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 32px로 줄였을 때 안 읽힘, 다른 글리프와 외곽선 굵기 다름, 피 묻음.
```text
A short broad sword pointing diagonally up to the right. Single chunky game UI icon glyph: white fill, thick dark navy outline, soft pale gold shading, bold simple silhouette readable at 32 pixels, centered, front view, no background shapes. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background.
```

#### UIP_GlyphStaff — 흰 아이콘 – 지팡이 (마법사 공격)
- 용도: 마법사 공격 버튼 위 글리프
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 너무 가늘어 작게 보면 선 하나로 보임.
```text
A magic staff with a round gem on top and a small sparkle. Single chunky game UI icon glyph: white fill, thick dark navy outline, soft pale gold shading, bold simple silhouette readable at 32 pixels, centered, front view, no background shapes. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background.
```

#### UIP_GlyphBow — 흰 아이콘 – 활 (궁수 공격)
- 용도: 궁수 공격 버튼 위 글리프
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 활시위가 끊김, 작게 보면 안 읽힘.
```text
A curved bow with a nocked arrow pointing up to the right. Single chunky game UI icon glyph: white fill, thick dark navy outline, soft pale gold shading, bold simple silhouette readable at 32 pixels, centered, front view, no background shapes. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background.
```

#### UIP_GlyphBag — 흰 아이콘 – 가방
- 용도: 오른쪽 위 [가방] 버튼(아이템 창 바로 열기)
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 세부가 많아 작게 보면 덩어리.
```text
A chunky adventurer backpack with a buckle flap. Single chunky game UI icon glyph: white fill, thick dark navy outline, soft pale gold shading, bold simple silhouette readable at 32 pixels, centered, front view, no background shapes. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background.
```

#### UIP_GlyphMap — 흰 아이콘 – 지도
- 용도: [지도] 버튼
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 지도 위 글자·숫자.
```text
A folded treasure map with a small dotted path. Single chunky game UI icon glyph: white fill, thick dark navy outline, soft pale gold shading, bold simple silhouette readable at 32 pixels, centered, front view, no background shapes. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background.
```

#### UIP_GlyphMenu — 흰 아이콘 – 메뉴
- 용도: [메뉴] 버튼(2×2 격자 모양)
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 네 칸 크기 다름.
```text
Four rounded squares arranged in a two by two grid. Single chunky game UI icon glyph: white fill, thick dark navy outline, soft pale gold shading, bold simple silhouette readable at 32 pixels, centered, front view, no background shapes. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background.
```

#### UIP_GlyphQuest — 흰 아이콘 – 퀘스트
- 용도: 퀘스트 판 탭·완료 알림
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 종이 위 글자 줄.
```text
A rolled paper scroll with a bold check mark. Single chunky game UI icon glyph: white fill, thick dark navy outline, soft pale gold shading, bold simple silhouette readable at 32 pixels, centered, front view, no background shapes. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background.
```

#### UIP_GlyphAuto — 흰 아이콘 – 자동 전투
- 용도: 자동 버튼 위 글리프(동그란 화살 + 칼)
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 제외칸: AUTO, letters. 거절: 글자 AUTO가 그려짐.
```text
Two curved arrows forming a circle around a small upright sword. Single chunky game UI icon glyph: white fill, thick dark navy outline, soft pale gold shading, bold simple silhouette readable at 32 pixels, centered, front view, no background shapes. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background.
```

#### UIP_GlyphClose — 흰 아이콘 – 닫기 X
- 용도: 모든 창 오른쪽 위 닫기
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 두 획 굵기 다름.
```text
A bold X cross with rounded ends. Single chunky game UI icon glyph: white fill, thick dark navy outline, soft pale gold shading, bold simple silhouette readable at 32 pixels, centered, front view, no background shapes. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background.
```

#### UIP_GlyphBack — 흰 아이콘 – 뒤로
- 용도: 창 왼쪽 위 뒤로 가기
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 닫기 X와 굵기 다름.
```text
A bold left-pointing arrow with rounded ends. Single chunky game UI icon glyph: white fill, thick dark navy outline, soft pale gold shading, bold simple silhouette readable at 32 pixels, centered, front view, no background shapes. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background.
```

#### UIP_GlyphLock — 흰 아이콘 – 자물쇠
- 용도: 잠긴 퀘스트 줄('Lv10 · 고블린 숲')·잠긴 칸
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 열쇠 구멍이 너무 작음.
```text
A chunky padlock. Single chunky game UI icon glyph: white fill, thick dark navy outline, soft pale gold shading, bold simple silhouette readable at 32 pixels, centered, front view, no background shapes. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background.
```

#### UIP_GlyphCheck — 흰 아이콘 – 체크
- 용도: 완료 표시·장착 중 표시
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 붓글씨처럼 가늘어짐.
```text
A bold check mark with rounded ends. Single chunky game UI icon glyph: white fill, thick dark navy outline, soft pale gold shading, bold simple silhouette readable at 32 pixels, centered, front view, no background shapes. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background.
```

#### UIP_GlyphExclaim — 흰 아이콘 – 느낌표
- 용도: NPC 머리 위 퀘스트 표시(말풍선 안)
- 크기: 256x256 (1:1 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 다른 글자가 같이 그려짐.
```text
A bold exclamation mark shape with a round dot, chunky and friendly. Single chunky game UI icon glyph: white fill, thick dark navy outline, soft pale gold shading, bold simple silhouette readable at 32 pixels, centered, front view, no background shapes. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background.
```

#### UIP_GlyphGear — 흰 아이콘 – 설정
- 용도: 설정 창(소리·버튼 크기·언어) — 정식
- 크기: 256x256 (1:1 생성) · 투명 · 시점: launch · 3D: False
- 검사·거절: 거절: 톱니가 많아 작게 보면 뭉개짐.
```text
A chunky gear wheel with six teeth. Single chunky game UI icon glyph: white fill, thick dark navy outline, soft pale gold shading, bold simple silhouette readable at 32 pixels, centered, front view, no background shapes. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background.
```

#### UIP_GlyphPaw — 흰 아이콘 – 펫 발자국
- 용도: 정식 [펫] 버튼(베타는 아이템 창 맨 위 펫 줄)
- 크기: 256x256 (1:1 생성) · 투명 · 시점: launch · 3D: False
- 검사·거절: 거절: 발가락 개수 이상.
```text
A cute pet paw print. Single chunky game UI icon glyph: white fill, thick dark navy outline, soft pale gold shading, bold simple silhouette readable at 32 pixels, centered, front view, no background shapes. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background.
```

#### UIP_ToggleTrack — 켜기/끄기 스위치 길
- 용도: 설정 창 스위치(정식). 켜짐 색은 게임에서
- 크기: 256x128 (16:9 생성) · 투명 · 시점: launch · 3D: False
- 검사·거절: 거절: 손잡이가 같이 그려짐(따로 필요).
```text
One horizontal toggle switch track: light gray recessed capsule groove with a dark navy outline, completely empty. Glossy casual mobile game UI asset, chunky rounded toy-like shape, crisp clean vector-like rendering, front orthographic view, centered, symmetrical, plain neutral light colors so it can be recolored in the game. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background, no ground shadow.
```

#### UIP_ToggleKnob — 스위치 손잡이
- 용도: 스위치 둥근 손잡이(정식)
- 크기: 128x128 (1:1 생성) · 투명 · 시점: launch · 3D: False
- 검사·거절: 거절: 원이 찌그러짐.
```text
One round toggle switch knob: glossy white ball with a dark navy outline and soft gray shading. Glossy casual mobile game UI asset, chunky rounded toy-like shape, crisp clean vector-like rendering, front orthographic view, centered, symmetrical, plain neutral light colors so it can be recolored in the game. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background, no ground shadow.
```

#### UIP_MapBoard — 세계 지도 그림 (글자 없음)
- 용도: 지도 창 배경. 지역 이름·내 위치·퀘스트 표시는 게임 글자/표시. MapParchment 대체. Config.Zones 배치(북 빛 성채, 남 뿔 소굴, 동쪽으로 초원→숲→유적)와 맞는지 확인
- 크기: 1536x1024 (4:3 생성) · 불투명 · 시점: beta · 3D: False
- 검사·거절: 제외칸: text, labels, compass letters. 거절: 지역 순서·방향이 게임과 다름, 가짜 글자, 너무 어두워 표시가 안 보임.
```text
Illustrated top-down fantasy world map on soft parchment, no labels: a round cobblestone town plaza with a fountain in the center, a white-and-gold castle island to the north linked by a bridge, a dark volcanic island with lava streams to the south linked by a bridge, to the east a bright green flower meadow with small ponds, further east a dense dark green forest, farthest east pale ancient stone ruins, one dirt road running from the town east through all three areas, blue sea around the islands, cute hand-painted casual game map style, soft colors. No text, no letters, no compass lettering, no watermark.
```

#### UIP_WelcomeArt — 환영 창 머리 그림
- 용도: 환영·이야기 시작 창 위쪽 그림(정식)
- 크기: 1536x512 (16:9 생성 후 자르기) · 불투명 · 시점: launch · 3D: False
- 검사·거절: 제외칸: people, text. 거절: 왕관 대신 다른 물체, 가짜 글자.
```text
Wide header illustration for a welcome window: a giant cracked golden crown floating in a bright blue sky above a cobblestone town fountain, glowing shards drifting left toward a white castle and right toward a dark volcanic peak, soft clouds, painterly casual mobile game art, no characters. No text, no letters, no watermark.
```

#### UIP_PetCard — 펫 카드 틀
- 용도: 정식 펫 창·도감 카드(펫 그림은 펫 분야). 이름·별·능력은 게임 글자
- 크기: 384x480 (3:4 생성) · 투명 · 시점: launch · 3D: False
- 검사·거절: 제외칸: animals, pets. 거절: 창 안에 동물이 그려짐.
```text
One vertical rounded pet collection card frame: warm cream body with a polished gold rim, a large empty round window filled with a soft mint-green gradient in the upper part, an empty name plate below. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background, no ground shadow.
```

#### UIP_EggNestBg — 알 둥지 부화 배경
- 용도: 정식 골드 랜덤 알 둥지 부화 화면 배경(확률표는 게임 글자)
- 크기: 1536x1024 (4:3 생성) · 불투명 · 시점: launch · 3D: False
- 검사·거절: 제외칸: people, animals, text. 거절: 알이 그려짐(알은 따로), 가짜 글자 간판.
```text
Cozy pet hatchery interior background: a big round straw nest on a small wooden stage, soft warm lantern light, teal and gold hanging banners, wooden beams, an empty glowing center spot for an egg, cute casual mobile game background art, no characters. No text, no letters, no watermark.
```

#### UIP_LogoPlate — 로고 바탕 문장
- 용도: 썸네일·로딩·환영 창 로고 바탕. 'Halo & Horns'·'선악 키우기' 글자는 글꼴로 한/영 두 벌
- 크기: 1024x512 (16:9 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 가운데 띠에 글자, 해골, 실제 브랜드 로고와 닮음.
```text
One game logo backing emblem: a wide rounded shield-shaped plaque split down the middle, left half ivory and gold with a glowing golden halo ring above it, right half deep crimson and gold with one small cute red cartoon horn on top, a cracked glowing golden crown at the top center, a completely empty wide center band for a title. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### GameIcon_A_SplitHero — 게임 아이콘 1안 – 후광·뿔 반쪽 아이
- 용도: Roblox 게임 아이콘 후보(512 이상 정사각, 150px에서도 읽혀야 함)
- 크기: 1024x1024 생성 → 512x512 · 불투명 · 시점: beta · 3D: False
- 검사·거절: 제외칸: text, logo, skull, revealing clothes, anime. 거절: 치비·애니 얼굴, 맨살 노출, 150px에서 얼굴·후광·뿔이 안 읽힘, 특정 플랫폼/브랜드 로고 닮음.
```text
Square game icon: close-up of a cheerful hero kid drawn as a blocky toy-avatar style character with a cube-shaped head, rectangular block body and arms, and a simple friendly cartoon face, a glowing golden halo floating over the left side of the head and one small cute red cartoon horn on the right side, holding up a glowing golden crown shard, background split diagonally into warm gold sky on the left and deep crimson sunset on the right, wearing a modest full-coverage adventurer outfit: long sleeves, high collar, full-length trousers, gloves and boots, shoulders, torso, midriff and legs fully covered, only face and hands visible, big readable shapes, strong silhouette. Glossy casual fantasy mobile game key art, bright saturated kid-friendly colors, soft warm lighting, clean bold shapes, playful and not scary, no blood. No text, no letters, no logo, no watermark.
```

#### GameIcon_B_Crown — 게임 아이콘 2안 – 반반 왕관
- 용도: 게임 아이콘 후보(인물 없이 세계관 상징)
- 크기: 1024x1024 생성 → 512x512 · 불투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 150px에서 왕관 모양이 뭉개짐, 너무 어두움.
```text
Square game icon: a cracked glowing golden crown floating in the center, its left half bright gold with a halo ring and small white feathers, its right half deep crimson with two small cute red cartoon horns, sparkles and light beams, rich gradient background from gold on the left to crimson on the right, bold simple shapes readable at small size. Glossy casual fantasy mobile game key art, bright saturated kid-friendly colors, soft warm lighting, clean bold shapes, playful and not scary, no blood. No text, no letters, no logo, no watermark.
```

#### GameIcon_C_BabySlime — 게임 아이콘 3안 – 아기 슬라임
- 용도: 게임 아이콘 후보(귀여운 펫 중심, 베타 펫과 일치)
- 크기: 1024x1024 생성 → 512x512 · 불투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 게임 속 슬라임과 너무 다른 모양·색, 150px에서 표정 안 읽힘.
```text
Square game icon: a round cute baby green jelly slime pet with big shiny eyes and a happy smile, wearing a tiny golden halo on one side and tiny red cartoon horns on the other, sitting on a glowing golden crown shard, bright background split into gold and crimson, bold simple shapes readable at small size. Glossy casual fantasy mobile game key art, bright saturated kid-friendly colors, soft warm lighting, clean bold shapes, playful and not scary, no blood. No text, no letters, no logo, no watermark.
```

#### Thumb_A_FactionClash — 썸네일 1 – 빛 vs 뿔 대치
- 용도: 대표 썸네일(1920x1080). 로고는 위 가운데에 나중에 얹음
- 크기: 1920x1080 (16:9 생성) · 불투명 · 시점: beta · 3D: False
- 검사·거절: 제외칸: text, logo, blood, skull, revealing clothes, anime. 거절: 맨어깨·배·다리 노출, 치비/애니 얼굴, 실제 게임 장면과 너무 다름.
```text
Wide game key art: a sunny fantasy town plaza with a stone fountain, a giant cracked golden crown floating in the sky shedding glowing shards; on the left a team of blocky toy-avatar style characters with cube-shaped heads, rectangular block bodies and limbs, and simple friendly cartoon faces in white and gold armor with floating golden halos, on the right a team of the same blocky toy-avatar style characters in dark crimson armor with small cute red horns, facing each other playfully with a sword, a staff and a bow raised, every character wears a modest full-coverage outfit: long sleeves, high collar, full-length trousers or long skirt with opaque tights, gloves and boots, shoulders, torso, midriff and legs fully covered, only face and hands visible, empty sky space at the top center for a logo, dynamic but readable composition. Glossy casual fantasy mobile game key art, bright saturated kid-friendly colors, soft warm lighting, clean bold shapes, playful and not scary, no blood. No text, no letters, no logo, no watermark.
```

#### Thumb_B_HuntLoot — 썸네일 2 – 슬라임 사냥과 희귀 무기
- 용도: 사냥 → 전리품 재미를 보여 주는 썸네일
- 크기: 1920x1080 (16:9 생성) · 불투명 · 시점: beta · 3D: False
- 검사·거절: 거절: 노출 의상, 슬라임이 무섭게 그려짐, 게임에 없는 무기·괴물.
```text
Wide game key art: a bright flower meadow with bouncy round green jelly slimes and one big king slime wearing a small crooked crown; a hero drawn as a blocky toy-avatar style character with a cube-shaped head, rectangular block body and limbs, and a simple friendly cartoon face, in white and gold adventurer armor, swings a glowing sword, gold coins burst out and a glowing rare sword drops with a tall light beam, a tiny baby slime pet bounces behind the hero, the hero wears a modest full-coverage outfit: long sleeves, high collar, full-length trousers, gloves and boots, shoulders, torso, midriff and legs fully covered, only face and hands visible, empty space at the top left for a logo. Glossy casual fantasy mobile game key art, bright saturated kid-friendly colors, soft warm lighting, clean bold shapes, playful and not scary, no blood. No text, no letters, no logo, no watermark.
```

#### Thumb_C_Halloween — 썸네일 3 – 핼러윈 몬스터
- 용도: 10/31 베타 핼러윈 썸네일(시즌 끝나면 내림)
- 크기: 1920x1080 (16:9 생성) · 불투명 · 시점: beta · 3D: False
- 검사·거절: 제외칸: skull, blood, gore, revealing clothes. 거절: 무서운 표정·어두운 공포, 핼러윈 몬스터 승인 시안과 다른 생김새.
```text
Wide game key art at a cozy twilight meadow: blocky toy-avatar style characters with cube-shaped heads, rectangular block bodies and limbs, and simple friendly cartoon faces battle cute seasonal monsters: an orange pumpkin slime with a jack-o-lantern smile, a small friendly white ghost, and a little goblin with bat wings, glowing pumpkin lanterns, candy drops, purple and orange sky, every character wears a modest full-coverage costume: long sleeves, high collar, full-length trousers or long skirt with opaque tights, gloves and boots, shoulders, torso, midriff and legs fully covered, only face and hands visible, empty space at the top center for a logo, playful not scary, no skulls. Glossy casual fantasy mobile game key art, bright saturated kid-friendly colors, soft warm lighting, clean bold shapes, playful and not scary, no blood. No text, no letters, no logo, no watermark.
```

#### Thumb_D_Pets — 썸네일 4 – 펫 진화
- 용도: 정식 펫 업데이트 썸네일(천사·악마·균형 진화)
- 크기: 1920x1080 (16:9 생성) · 불투명 · 시점: launch · 3D: False
- 검사·거절: 거절: 펫 분야 승인 디자인과 다름, 노출 의상.
```text
Wide game key art: a happy hero drawn as a blocky toy-avatar style character with a cube-shaped head, rectangular block body and limbs, and a simple friendly cartoon face, surrounded by cute pets: a baby green jelly slime, an angel slime with a golden halo and tiny white wings, a devil slime with tiny red horns and a little pointed tail, a balance slime with a teal gear charm, and a golden egg glowing in a straw nest, sunny town background, the hero wears a modest full-coverage outfit: long sleeves, high collar, full-length trousers, gloves and boots, shoulders, torso, midriff and legs fully covered, only face and hands visible, empty space at the top for a logo. Glossy casual fantasy mobile game key art, bright saturated kid-friendly colors, soft warm lighting, clean bold shapes, playful and not scary, no blood. No text, no letters, no logo, no watermark.
```

#### UIP_LoadingArt — 로딩 화면 그림
- 용도: 정식 사용자 로딩 화면 배경(아래에 BarTrack 진행 바와 한/영 팁)
- 크기: 1920x1080 (16:9 생성) · 불투명 · 시점: launch · 3D: False
- 검사·거절: 제외칸: people, text. 거절: 아래 띠가 복잡해 진행 바·팁이 안 보임.
```text
Wide loading screen illustration: view from a cobblestone town plaza looking up at a giant cracked golden crown floating in a bright sky, glowing shards drifting toward a white castle island on the left and a dark volcanic island on the right, soft clouds, painterly casual mobile game background, no characters, calm uncluttered band at the bottom for a progress bar. No text, no letters, no watermark.
```

#### UIP_EventBannerHalloween — 핼러윈 이벤트 배너
- 용도: 핼러윈 몬스터 출현·이벤트 알림 배너(베타, 늦으면 가장 먼저 뺌)
- 크기: 1536x384 (16:9 생성) · 투명 · 시점: beta · 3D: False
- 검사·거절: 제외칸: skull, blood, text. 거절: 무서운 호박 얼굴, 가운데 장식.
```text
One wide cute Halloween event banner: orange and purple ribbon with small smiling jack-o-lantern pumpkins and tiny cartoon bats at both ends, a few candies, completely empty flat center, playful not scary. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat pure white background, no ground shadow.
```

#### UIP_EventBannerWinter — 겨울 이벤트 배너
- 용도: 정식 크리스마스 꾸밈 알림 배너
- 크기: 1536x384 (16:9 생성) · 투명 · 시점: launch · 3D: False
- 검사·거절: 거절: 종교 상징, 가운데 장식, 글자.
```text
One wide cozy winter event banner: icy blue and white ribbon with soft snow caps, small pine branches and red berries at both ends, completely empty flat center. Glossy casual fantasy mobile game UI asset, chunky rounded toy-like shapes, polished gold trim, thick clean dark navy outline, glossy top highlight, subtle darker bottom bevel, bright saturated colors, crisp clean vector-like rendering, front orthographic view, centered, symmetrical. No text, no letters, no numbers, no watermark. Isolated on a plain flat solid dark charcoal background, no ground shadow.
```

### 2-2. 펫

#### Pet_BabySlime — 아기 슬라임 (펫 원화+아이콘)
- 용도: Beta pet (P1 quest). Locks the shared pet style: generate options A (low-poly faceted) and B (smooth vinyl) and the user picks one. Must look clearly different from the hostile meadow slimes. The approved colour plus sprout guide the beta 3D (existing slime mesh at 0.35 scale, tinted, plus a small sprout part). The pet-row icon comes from this image.
- 크기: 1024x1024 concept -> 256x256 icon (UIArt key PetIconBabySlime) · 투명 · 시점: beta · 3D: True
- 검사·거절: Not the enemy slime green (95,205,95) or BigSlime blue. No tongue or drool, no dripping goo, no crown (the crown is the later legendary CrownJelly). The sprout must be attached to the body, not floating.
```text
A tiny baby jelly slime pet, drop-shaped bouncy round body, glossy semi-translucent pale mint-white jelly with soft peach blush cheeks, one small fresh green leaf sprout growing on top of its head, big sparkly eyes, small happy open smile, cute low-poly toy figurine pet for a kids game, chunky rounded shapes with soft subtle facets, smooth matte vinyl look, big round head on a small body, glossy black oval eyes with one white highlight, soft pastel colors with simple gradient shading, bold clean silhouette, three-quarter front view, full body, centered, isolated on a plain pure white background, soft even lighting, no ground shadow, no text, no letters, no logo, no watermark
```

#### UI_RarityFrame_Common — 등급 테두리 - 일반
- 용도: Slot backplate behind pet and weapon icons (pet row, drop popup, codex). Shared with the beta weapon grades (B2 display), so generate once. Colour 200,200,200.
- 크기: 256x256 · 투명 · 시점: beta · 3D: False
- 검사·거절: The inner area stays empty (icons are overlaid in game). No dark grey; this is the common tier, not the grey-legend aura. Wait until the HUD style is approved and use it as the style reference.
```text
Blank square item slot tile with rounded corners, soft cream inner backplate, simple smooth light silver-white rim, no ornaments, plain and clean, blank game UI part for a kids fantasy RPG, soft painted toy style, crisp clean edges, symmetrical, front view, flat, isolated on a plain medium grey background, no shadow, no text, no letters, no numbers, no icons inside
```

#### UI_RarityFrame_Uncommon — 등급 테두리 - 고급
- 용도: Uncommon tier frame, colour 90,200,90. Shape cue: two leaves. Shared with weapons.
- 크기: 256x256 · 투명 · 시점: beta · 3D: False
- 검사·거절: Same silhouette and inner size as the Common frame (they swap in place). No glow.
```text
Blank square item slot tile with rounded corners, soft cream inner backplate, fresh green rim with two tiny leaf ornaments at the top corners, blank game UI part for a kids fantasy RPG, soft painted toy style, crisp clean edges, symmetrical, front view, flat, isolated on a plain medium grey background, no shadow, no text, no letters, no numbers, no icons inside
```

#### UI_RarityFrame_Rare — 등급 테두리 - 희귀
- 용도: Rare tier frame, colour 70,140,255. Shape cue: one gem. Shared with weapons. The baby slime is rare.
- 크기: 256x256 · 투명 · 시점: beta · 3D: False
- 검사·거절: Keep the same inner area as the other frames. The gem must not cover the inner backplate.
```text
Blank square item slot tile with rounded corners, soft cream inner backplate, bright blue rim with one small round blue gem at the top center, blank game UI part for a kids fantasy RPG, soft painted toy style, crisp clean edges, symmetrical, front view, flat, isolated on a plain medium grey background, no shadow, no text, no letters, no numbers, no icons inside
```

#### UI_RarityFrame_Epic — 등급 테두리 - 영웅
- 용도: Epic tier frame, colour 170,90,230. Shape cue: four corner stars. Shared with weapons.
- 크기: 256x256 · 투명 · 시점: beta · 3D: False
- 검사·거절: No dark or spooky look. Stars stay small, inside the 256 square.
```text
Blank square item slot tile with rounded corners, soft cream inner backplate, rich purple rim with small golden star ornaments at the four corners, blank game UI part for a kids fantasy RPG, soft painted toy style, crisp clean edges, symmetrical, front view, flat, isolated on a plain medium grey background, no shadow, no text, no letters, no numbers, no icons inside
```

#### UI_RarityFrame_Legendary — 등급 테두리 - 전설
- 용도: Legendary tier frame, colour 255,160,40. Shape cue: a tiny crown and sparkles. The animated shimmer (UIGradient) is applied only to this tier, in game. Shared with weapons.
- 크기: 256x256 · 투명 · 시점: beta · 3D: False
- 검사·거절: The crown is a simple toy crown, not the broken Crown of Balance shard (that one is story-specific). No red.
```text
Blank square item slot tile with rounded corners, soft cream inner backplate, warm orange-gold rim slightly thicker than usual, a tiny golden crown at the top center and a few small sparkles on the rim, blank game UI part for a kids fantasy RPG, soft painted toy style, crisp clean edges, symmetrical, front view, flat, isolated on a plain medium grey background, no shadow, no text, no letters, no numbers, no icons inside
```

#### UI_PetNameTag — 펫 이름표 판
- 용도: BillboardGui plate above the pet showing a live text name such as '아기 슬라임 · 착한 친구' plus the lean badge. Beta: the design doc says the name tag shows the P1 choice. 9-slice horizontally like Pill.
- 크기: 512x128 (9-slice, ends about 48 px) · 투명 · 시점: beta · 3D: False
- 검사·거절: The center must be flat and empty for live text. Keep the paw notch small, so it does not break the 9-slice middle.
```text
Blank small rounded name plate banner for a floating pet name, wide horizontal pill shape, soft cream center, thin warm brown outline, a tiny paw print notch on the left end, blank game UI part for a kids fantasy RPG, soft painted toy style, crisp clean edges, symmetrical, front view, flat, isolated on a plain medium grey background, no shadow, no text, no letters, no numbers, no icons inside
```

#### Badge_LeanCare — 선택 배지 - 보살펴요 (천사 쪽)
- 용도: Shows the [보살펴요] P1 pick on the name tag and pet row (beta). At launch it doubles as the angel-form corner badge on pet icons.
- 크기: 128x128 · 투명 · 시점: beta · 3D: False
- 검사·거절: Must read at 24 px. No wings, which would clutter it.
```text
Small round badge, a soft pink heart with a tiny golden halo ring floating above it, cute game UI icon for a kids fantasy RPG, single object, bold simple shape, soft cel shading with gentle gradient, clean dark rim outline, centered, fills about 80 percent of the square, isolated on a plain pure white background, no shadow, no text, no letters, no logo
```

#### Badge_LeanTame — 선택 배지 - 길들여요 (악마 쪽)
- 용도: Shows the [길들여요] P1 pick ('장난꾸러기 졸개') on the name tag and pet row (beta). At launch it doubles as the devil-form badge.
- 크기: 128x128 · 투명 · 시점: beta · 3D: False
- 검사·거절: No face with fangs, no fire, no skull, no sharp spikes. It should look mischievous, not evil.
```text
Small round badge, a plum-purple circle with two tiny rounded red horn nubs on top and a small cheeky wink sparkle, friendly and playful, cute game UI icon for a kids fantasy RPG, single object, bold simple shape, soft cel shading with gentle gradient, clean dark rim outline, centered, fills about 80 percent of the square, isolated on a plain pure white background, no shadow, no text, no letters, no logo
```

#### Badge_LeanGuild — 선택 배지 - 장인 (균형)
- 용도: Artisan Guild P1 pick (같이 다녀요 / 길드에 데려가요) on the name tag (beta). At launch it doubles as the balance-form badge.
- 크기: 128x128 · 투명 · 시점: beta · 3D: False
- 검사·거절: Teal 40,200,190 family only. It should not resemble the settings gear icon: rounder, with a brass rim.
```text
Small round badge, a teal gear with a polished brass rim and a tiny sparkle, cute game UI icon for a kids fantasy RPG, single object, bold simple shape, soft cel shading with gentle gradient, clean dark rim outline, centered, fills about 80 percent of the square, isolated on a plain pure white background, no shadow, no text, no letters, no logo
```

#### Icon_PetPaw — 펫 아이콘 (발바닥)
- 용도: Section header '내 펫' in Menu > 아이템 (beta). At launch it becomes the Menu '펫' button icon and the pet toasts icon.
- 크기: 256x256 · 투명 · 시점: beta · 3D: False
- 검사·거절: No claws. No red; the heart pad is pink or peach.
```text
A chubby paw print with a small heart-shaped main pad and four round toe pads, soft peach and cream colors, cute game UI icon for a kids fantasy RPG, single object, bold simple shape, soft cel shading with gentle gradient, clean dark rim outline, centered, fills about 80 percent of the square, isolated on a plain pure white background, no shadow, no text, no letters, no logo
```

#### Icon_PetStatSpeed — 펫 능력 아이콘 - 이동 속도
- 용도: Buff icon on the pet row ('이동 +7%') and the level-up toast (beta, baby slime speed). Can be shared if the general icon pass makes a speed icon.
- 크기: 256x256 · 투명 · 시점: beta · 3D: False
- 검사·거절: No brand-like sneaker logo or swoosh mark on the shoe. No gold wings (gold reads as Halo).
```text
A small pastel sky-blue sneaker boot with tiny white wings on the heel and three soft speed swoosh lines behind it, cute game UI icon for a kids fantasy RPG, single object, bold simple shape, soft cel shading with gentle gradient, clean dark rim outline, centered, fills about 80 percent of the square, isolated on a plain pure white background, no shadow, no text, no letters, no logo
```

#### Pet_FluffChick — 솜털 병아리
- 용도: Meadow egg, common, MonsterXP. Concept for Tripo, plus pet panel and codex icon. Size class tiny (1.5 studs), ground hopper.
- 크기: 1024x1024 concept -> 256x256 icon · 투명 · 시점: launch · 3D: True
- 검사·거절: Butter yellow, not Halo gold. No realistic feathers, no open beak or tongue, no eggshell on its head.
```text
A round fluffy baby chick pet, butter-yellow puffball body, tiny stubby wings, small orange beak, rosy pink cheeks, two tiny orange feet, one curly feather tuft on top of its head, cute low-poly toy figurine pet for a kids game, chunky rounded shapes with soft subtle facets, smooth matte vinyl look, big round head on a small body, glossy black oval eyes with one white highlight, small happy mouth, soft pastel colors with simple gradient shading, bold clean silhouette, three-quarter front view, full body, centered, isolated on a plain pure white background, soft even lighting, no ground shadow, no text, no letters, no logo, no watermark
```

#### Pet_JellySnail — 젤리 달팽이
- 용도: Meadow egg, common, MPRegen. Silhouette hook: spiral jelly shell. Size class tiny, ground.
- 크기: 1024x1024 concept -> 256x256 icon · 투명 · 시점: launch · 3D: True
- 검사·거절: No slime trail or drool, no realistic snail skin, no eyes on stalk tips. Avoid teal (Artisan colour).
```text
A small pastel snail pet, soft lavender body, round translucent sky-blue jelly shell with a white spiral swirl and a soft inner glow, two short antennae with round tips, big eyes on its face, gentle smile, cute low-poly toy figurine pet for a kids game, chunky rounded shapes with soft subtle facets, smooth matte vinyl look, big round head on a small body, glossy black oval eyes with one white highlight, soft pastel colors with simple gradient shading, bold clean silhouette, three-quarter front view, full body, centered, isolated on a plain pure white background, soft even lighting, no ground shadow, no text, no letters, no logo, no watermark
```

#### Pet_CloverBunny — 클로버 토끼
- 용도: Meadow egg, uncommon, MoveSpeed. Silhouette hook: long clover-tipped ears. Size class small (2 studs), hopper.
- 크기: 1024x1024 concept -> 256x256 icon · 투명 · 시점: launch · 3D: True
- 검사·거절: Grey background because the subject is white. No buck teeth, no realistic fur, and the scarf stays a plain knit (no patterns or letters).
```text
A small white bunny pet, long upright rounded ears with little green four-leaf-clover tips, a short green knit scarf, round fluffy tail, pink nose, cute low-poly toy figurine pet for a kids game, chunky rounded shapes with soft subtle facets, smooth matte vinyl look, big round head on a small body, glossy black oval eyes with one white highlight, small happy mouth, soft pastel colors with simple gradient shading, bold clean silhouette, three-quarter front view, full body, centered, isolated on a plain medium grey background, soft even lighting, no ground shadow, no text, no letters, no logo, no watermark
```

#### Pet_AcornSquirrel — 도토리 다람쥐
- 용도: Forest egg, uncommon, MonsterGold. Silhouette hook: big curled tail plus a hugged acorn. Size class small.
- 크기: 1024x1024 concept -> 256x256 icon · 투명 · 시점: launch · 3D: True
- 검사·거절: The acorn must touch the paws (one solid piece for Tripo). No teeth, no claws.
```text
A chubby chestnut-brown squirrel pet hugging a shiny golden acorn with both paws, big curled fluffy tail, cream belly patch, cute low-poly toy figurine pet for a kids game, chunky rounded shapes with soft subtle facets, smooth matte vinyl look, big round head on a small body, glossy black oval eyes with one white highlight, small happy mouth, soft pastel colors with simple gradient shading, bold clean silhouette, three-quarter front view, full body, centered, isolated on a plain pure white background, soft even lighting, no ground shadow, no text, no letters, no logo, no watermark
```

#### Pet_MushroomFrog — 버섯 개구리 (새로 추가)
- 용도: Forest egg, uncommon, MonsterXP (proposal). Silhouette hook: mushroom-cap hat. Size class small, hopper.
- 크기: 1024x1024 concept -> 256x256 icon · 투명 · 시점: launch · 3D: True
- 검사·거절: No red-and-white toadstool (red is reserved for Horns). No warts, slime or tongue. Spring green, not goblin green.
```text
A small round spring-green frog pet sitting upright, wearing a soft orange mushroom cap with cream spots like a hat, wide happy closed-mouth smile, tiny round toes, cute low-poly toy figurine pet for a kids game, chunky rounded shapes with soft subtle facets, smooth matte vinyl look, big round head on a small body, glossy black oval eyes with one white highlight, soft pastel colors with simple gradient shading, bold clean silhouette, three-quarter front view, full body, centered, isolated on a plain pure white background, soft even lighting, no ground shadow, no text, no letters, no logo, no watermark
```

#### Pet_MossTurtle — 이끼 거북
- 용도: Forest egg, rare, MPRegen. Silhouette hook: dome shell with mushroom and sprout. Size class medium (2.5 studs).
- 크기: 1024x1024 concept -> 256x256 icon · 투명 · 시점: launch · 3D: True
- 검사·거절: No realistic scales, no beak teeth, no snapping-turtle look.
```text
A tiny turtle pet, rounded dome shell covered in soft green moss with one small orange-capped mushroom and a tiny sprout on top, olive-green skin, sleepy happy half-closed eyes, short stubby legs, cute low-poly toy figurine pet for a kids game, chunky rounded shapes with soft subtle facets, smooth matte vinyl look, big round head on a small body, soft pastel colors with simple gradient shading, bold clean silhouette, three-quarter front view, full body, centered, isolated on a plain pure white background, soft even lighting, no ground shadow, no text, no letters, no logo, no watermark
```

#### Pet_FireflyFox — 반딧불 여우
- 용도: Forest egg, epic, MoveSpeed. Silhouette hook: oversized tail with a glowing tip (the epic tier gets a light feature). Size class medium.
- 크기: 1024x1024 concept -> 256x256 icon · 투명 · 시점: launch · 3D: True
- 검사·거절: Orange, not red. No sharp teeth. The glow is part of the tail, with no separate floating fireflies (Tripo needs one solid piece).
```text
A small orange fox kit pet, oversized fluffy tail whose tip glows soft warm yellow like a firefly, cream chest and muzzle, big rounded ears, cute low-poly toy figurine pet for a kids game, chunky rounded shapes with soft subtle facets, smooth matte vinyl look, big round head on a small body, glossy black oval eyes with one white highlight, small happy mouth, soft pastel colors with simple gradient shading, bold clean silhouette, three-quarter front view, full body, centered, isolated on a plain pure white background, soft even lighting, no ground shadow, no text, no letters, no logo, no watermark
```

#### Pet_PebbleSprite — 꼬마 돌정령
- 용도: Ruins egg, rare, MonsterDamage. Floats 2 studs up. Silhouette hook: round stone with stubby arms and glowing eyes. Size class small.
- 크기: 1024x1024 concept -> 256x256 icon · 투명 · 시점: launch · 3D: True
- 검사·거절: Not grey (grey is reserved for the grey-legend aura). No angry brow, no cracks that look broken, no detached floating rocks.
```text
A palm-sized round stone buddy pet made of warm sandstone beige, a few soft moss patches, two friendly glowing violet eyes, tiny stubby stone arms attached to its sides, hovering slightly, cute low-poly toy figurine pet for a kids game, chunky rounded shapes with soft subtle facets, smooth matte vinyl look, soft pastel colors with simple gradient shading, bold clean silhouette, three-quarter front view, full body, centered, isolated on a plain pure white background, soft even lighting, no ground shadow, no text, no letters, no logo, no watermark
```

#### Pet_RuneKitten — 룬 고양이 (새로 추가)
- 용도: Ruins egg, rare, MoveSpeed (proposal). Silhouette hook: kitten ears, curled tail and a gem charm. Size class small.
- 크기: 1024x1024 concept -> 256x256 icon · 투명 · 시점: launch · 3D: True
- 검사·거절: The stripes are simple shapes, never letters or symbols. No claws, no slit-pupil cat eyes.
```text
A small lilac kitten pet with a round head, a soft violet glowing stripe pattern on its back, a little crystal-blue gem charm on a ribbon collar, curled tail, cute low-poly toy figurine pet for a kids game, chunky rounded shapes with soft subtle facets, smooth matte vinyl look, big round head on a small body, glossy black oval eyes with one white highlight, small happy mouth, soft pastel colors with simple gradient shading, bold clean silhouette, three-quarter front view, full body, centered, isolated on a plain pure white background, soft even lighting, no ground shadow, no text, no letters, no logo, no watermark
```

#### Pet_StarOwl — 별빛 부엉이
- 용도: Ruins egg, epic, MonsterXP. A flyer. Silhouette hook: round body with ear tufts and wings.
- 크기: 1024x1024 concept -> 256x256 icon · 투명 · 시점: launch · 3D: True
- 검사·거절: No talons, no realistic feathers. The eyes look friendly, not staring.
```text
A round owl chick pet, navy-blue feathers with tiny white star-shaped freckles, big round golden eyes, small tufted ears, stubby rounded wings slightly open, cute low-poly toy figurine pet for a kids game, chunky rounded shapes with soft subtle facets, smooth matte vinyl look, big round head on a small body, small happy beak, soft pastel colors with simple gradient shading, bold clean silhouette, three-quarter front view, full body, centered, isolated on a plain pure white background, soft even lighting, no ground shadow, no text, no letters, no logo, no watermark
```

#### Pet_DawnLamb — 새벽 양 (빛의 기사단)
- 용도: Halo faction egg (새벽 알), epic, MPRegen. It must read as Halo at a glance. Size class medium.
- 크기: 1024x1024 concept -> 256x256 icon · 투명 · 시점: launch · 3D: True
- 검사·거절: Grey background because the subject is white. For the Tripo input, remove the floating halo with generative fill (the halo becomes the shared halo mesh). No wings at base form (wings belong to the angel form).
```text
A fluffy white lamb pet with cloud-like curly wool, soft cream face, a small gold bell on a pale sky-blue ribbon collar, a tiny golden halo ring floating just above its head, warm gentle glow, cute low-poly toy figurine pet for a kids game, chunky rounded shapes with soft subtle facets, smooth matte vinyl look, big round head on a small body, glossy black oval eyes with one white highlight, small happy mouth, soft pastel colors with simple gradient shading, bold clean silhouette, three-quarter front view, full body, centered, isolated on a plain medium grey background, soft even lighting, no ground shadow, no text, no letters, no logo, no watermark
```

#### Pet_LittleBat — 꼬마 박쥐 (뿔 군단)
- 용도: Horns faction egg (저주받은 알), epic, MonsterDamage. A flyer. It must read as Horns at a glance while staying cute.
- 크기: 1024x1024 concept -> 256x256 icon · 투명 · 시점: launch · 3D: True
- 검사·거절: No fangs, no blood, no red glowing eyes, no sharp wing claws, no vampire theme. It should be cute and mischievous, never scary.
```text
A round plum-purple baby bat pet, big soft rounded wings, two tiny rounded red horn nubs on its head, cheeky closed-mouth grin, big friendly eyes, tiny pointed tail, cute low-poly toy figurine pet for a kids game, chunky rounded shapes with soft subtle facets, smooth matte vinyl look, big round head on a small body, glossy black oval eyes with one white highlight, soft pastel colors with simple gradient shading, bold clean silhouette, three-quarter front view, full body, centered, isolated on a plain pure white background, soft even lighting, no ground shadow, no text, no letters, no logo, no watermark
```

#### Pet_ClockBeetle — 태엽 딱정벌레 (장인 길드)
- 용도: Artisan Guild pet: a proposed 톱니 알 at launch for parity with the faction eggs (user question Q2); the fallback is later crafting. Epic, MonsterGold. Hovers.
- 크기: 1024x1024 concept -> 256x256 icon · 투명 · 시점: launch · 3D: True
- 검사·거절: No realistic insect detail, mandibles or long antennae, and no spider look. Teal 40,200,190 plus brass 205,165,85 only.
```text
A small round clockwork beetle pet, glossy teal enamel shell, a brass gear on its back and a little brass wind-up key, short stubby brass legs, friendly round eyes, cute low-poly toy figurine pet for a kids game, chunky rounded shapes with soft subtle facets, smooth matte vinyl look, big round head on a small body, small happy mouth, soft pastel colors with simple gradient shading, bold clean silhouette, three-quarter front view, full body, centered, isolated on a plain pure white background, soft even lighting, no ground shadow, no text, no letters, no logo, no watermark
```

#### PetForm_Angel_Ref — Lv10 천사 모습 (기준 시안)
- 용도: Sets the angel-form language for all pets. The shared Blender accessory (halo ring plus two tiny wings on PetHeadTop and PetBack) and the warm sparkle are made from this. Cosmetic only.
- 크기: 1024x1024 · 투명 · 시점: launch · 3D: True
- 검사·거절: Use the approved Pet_BabySlime as the Structure and Style Reference. The halo is a simple ring, not a sun-ray crown. Wings stay tiny so they do not block the avatar.
```text
The same tiny baby jelly slime pet with pale mint-white jelly and a leaf sprout on its head, now in an angel form: a small floating golden halo ring above its head, two tiny white feathered wings on its back, a soft warm golden glow and a few small sparkles around it, cute low-poly toy figurine pet for a kids game, chunky rounded shapes with soft subtle facets, smooth matte vinyl look, glossy black oval eyes with one white highlight, small happy mouth, soft pastel colors, bold clean silhouette, three-quarter front view, full body, centered, isolated on a plain pure white background, soft even lighting, no ground shadow, no text, no letters, no logo
```

#### PetForm_Devil_Ref — Lv10 악마 모습 (기준 시안)
- 용도: Sets the devil-form language: the shared Blender accessory (two horn nubs plus a tiny arrow tail) and the purple-pink mischief sparkle. Cosmetic only.
- 크기: 1024x1024 · 투명 · 시점: launch · 3D: True
- 검사·거절: No fangs, fire, dark smoke, red glowing eyes, pitchfork or bat wings. Mischievous, never scary.
```text
The same tiny baby jelly slime pet with pale mint-white jelly and a leaf sprout on its head, now in a playful little-devil form: two tiny rounded red horn nubs on its head, a tiny plum-purple arrow-tip tail, a mischievous wink and cheeky grin, a few small purple-pink swirl sparkles around it, cute low-poly toy figurine pet for a kids game, chunky rounded shapes with soft subtle facets, smooth matte vinyl look, soft pastel colors, bold clean silhouette, three-quarter front view, full body, centered, isolated on a plain pure white background, soft even lighting, no ground shadow, no text, no letters, no logo
```

#### PetForm_Balance_Ref — Lv10 균형 모습 (기준 시안)
- 용도: Sets the balance-form language: the shared Blender accessory (a teal gear crest plus an orbiting brass mini gear) and teal sparks. Cosmetic only.
- 크기: 1024x1024 · 투명 · 시점: launch · 3D: True
- 검사·거절: Teal and brass only, with no gold halo or red. The gear has rounded teeth.
```text
The same tiny baby jelly slime pet with pale mint-white jelly and a leaf sprout on its head, now in a balance form: a small teal gear crest with a brass rim on top of its head, one tiny brass gear floating beside it, soft teal sparkles around it, calm content smile, cute low-poly toy figurine pet for a kids game, chunky rounded shapes with soft subtle facets, smooth matte vinyl look, soft pastel colors, bold clean silhouette, three-quarter front view, full body, centered, isolated on a plain pure white background, soft even lighting, no ground shadow, no text, no letters, no logo
```

#### FX_PetSparkleHalo — 천사 모습 반짝이 (파티클)
- 용도: ParticleEmitter texture for the angel form and the Halo pet cheer when its owner heals. Tinted 255,225,130 in game.
- 크기: 128x128 · 투명 · 시점: launch · 3D: False
- 검사·거절: Convert brightness to alpha locally. No lens-flare streaks or extra stars.
```text
A single soft four-point sparkle star with a gentle round glow, pure white on a plain pure black background, centered, simple, particle texture for a game, no text
```

#### FX_PetSparkleHorns — 악마 모습 반짝이 (파티클)
- 용도: ParticleEmitter texture for the devil form and the Horns pet hop when a grudge sack pays out. Tinted purple-pink in game.
- 크기: 128x128 · 투명 · 시점: launch · 3D: False
- 검사·거절: Not smoke and not fire.
```text
A single small curly swirl puff shape with a soft glow, like a playful magic swirl, pure white on a plain pure black background, centered, simple, particle texture for a game, no text
```

#### FX_PetSparkleGear — 균형 모습 반짝이 (파티클)
- 용도: ParticleEmitter texture for the balance form and the Artisan pet cheer on an upgrade success. Tinted teal in game.
- 크기: 128x128 · 투명 · 시점: launch · 3D: False
- 검사·거절: Keep it simple so it reads at 16 px.
```text
A single tiny gear-shaped spark with rounded teeth and a soft glow, pure white on a plain pure black background, centered, simple, particle texture for a game, no text
```

#### Egg_Meadow — 말랑 알
- 용도: Meadow egg: drops from Slime and BigSlime, and is sold at the nest. Used as the icon in rows and the nest panel, as the codex Meadow tab, and as the 3D egg for the nest display and hatch animation.
- 크기: 1024x1024 concept -> 256x256 icon · 투명 · 시점: launch · 3D: True
- 검사·거절: Not slime-enemy green: keep it pastel mint. No cracks (cracking is done in code during the hatch).
```text
A pastel mint-green pet egg with soft cream polka spots and a tiny painted four-leaf clover, cute fantasy pet egg, smooth glossy toy egg, slightly chubby egg shape standing upright, three-quarter front view, centered, isolated on a plain pure white background, soft even lighting, no ground shadow, no text, no letters, no logo
```

#### Egg_Forest — 숲 알
- 용도: Forest egg: drops from Goblin and GoblinBrute, and comes from the first M3-3 clear. Icon, codex Forest tab and 3D egg.
- 크기: 1024x1024 concept -> 256x256 icon · 투명 · 시점: launch · 3D: True
- 검사·거절: No goblin face or spikes. Keep it warm and friendly.
```text
An acorn-brown pet egg with a leafy green band around the top and a few tiny cream mushroom spots, cute fantasy pet egg, smooth glossy toy egg, slightly chubby egg shape standing upright, three-quarter front view, centered, isolated on a plain pure white background, soft even lighting, no ground shadow, no text, no letters, no logo
```

#### Egg_Ruins — 유적 알
- 용도: Ruins egg: drops from Skeleton and SkeletonKnight. Icon, codex Ruins tab and 3D egg. Uses the ruins palette (sandstone plus soul-fire violet 150,110,255).
- 크기: 1024x1024 concept -> 256x256 icon · 투명 · 시점: launch · 3D: True
- 검사·거절: No skulls, bones or letter-like runes. Not grey.
```text
A warm sandstone pet egg with softly glowing violet line patterns of simple swirls and dots, cute fantasy pet egg, smooth glossy toy egg, slightly chubby egg shape standing upright, three-quarter front view, centered, isolated on a plain pure white background, soft even lighting, no ground shadow, no text, no letters, no logo
```

#### Egg_Dawn — 새벽 알 (빛)
- 용도: Halo faction egg sold in HaloTown at rank 2. Icon and 3D egg.
- 크기: 1024x1024 concept -> 256x256 icon · 투명 · 시점: launch · 3D: True
- 검사·거절: Grey background because the subject is white. The halo floats, so for the 3D egg reuse the shared halo mesh instead.
```text
A pearl-white pet egg with a shiny gold band, a small soft sunrise pattern, and a tiny golden halo ring floating just above it, cute fantasy pet egg, smooth glossy toy egg, slightly chubby egg shape standing upright, three-quarter front view, centered, isolated on a plain medium grey background, soft even lighting, no ground shadow, no text, no letters, no logo
```

#### Egg_Cursed — 저주받은 알 (뿔)
- 용도: Horns faction egg sold in HornsTown at rank 2. Icon and 3D egg. Kid-safe 'cheeky' look.
- 크기: 1024x1024 concept -> 256x256 icon · 투명 · 시점: launch · 3D: True
- 검사·거절: No skull, eyes, fangs, cracks, dark smoke or flames.
```text
A plum-purple pet egg with two tiny rounded red horn nubs on top and a cheeky crescent-moon and little star pattern, cute fantasy pet egg, smooth glossy toy egg, slightly chubby egg shape standing upright, three-quarter front view, centered, isolated on a plain pure white background, soft even lighting, no ground shadow, no text, no letters, no logo
```

#### Egg_Gear — 톱니 알 (장인 길드)
- 용도: Proposed Artisan egg at the Crossroads guild, Artisan rank 2, which gives the Clock Beetle (user question Q2). Icon and 3D egg.
- 크기: 1024x1024 concept -> 256x256 icon · 투명 · 시점: launch · 3D: True
- 검사·거절: Teal and brass only. Do not generate until Q2 is answered A.
```text
A teal enamel pet egg with a polished brass gear band around the middle, small brass rivets, and a tiny wind-up key on the side, cute fantasy pet egg, smooth glossy toy egg, slightly chubby egg shape standing upright, three-quarter front view, centered, isolated on a plain pure white background, soft even lighting, no ground shadow, no text, no letters, no logo
```

#### Icon_Incubator — 부화기 아이콘
- 용도: Incubator row in the pet panel ('말랑 알 · 37/60 처치'). Eggs hatch by kills, not timers.
- 크기: 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: No clock or timer imagery (hatching is kill-based). No egg inside; the live egg icon overlays it.
```text
A cozy round straw nest basket with a soft warm lamp glow above it and an empty hollow in the middle, cute game UI icon for a kids fantasy RPG, single object, bold simple shape, soft cel shading with gentle gradient, clean dark rim outline, centered, fills about 80 percent of the square, isolated on a plain pure white background, no shadow, no text, no letters, no logo
```

#### UI_HatchRays — 부화 빛줄기
- 용도: Spinning ray burst behind the newly hatched pet in the hatch popup. Tinted with the rarity colour in game.
- 크기: 512x512 · 투명 · 시점: launch · 3D: False
- 검사·거절: Convert brightness to alpha. Do not let the rays touch the edges (prevents a hard square cutoff while spinning).
```text
Soft radial light ray burst, twelve gentle rays fading outward from the center, pure white on a plain pure black background, centered, symmetrical, simple, no text
```

#### FX_HatchConfetti — 부화 색종이 (별·하트 2장)
- 용도: Two particle textures, a small rounded star and a small heart, for the hatch pop. Generate each separately with the same prompt and swap the subject.
- 크기: 64x64 each · 투명 · 시점: launch · 3D: False
- 검사·거절: Convert brightness to alpha. Colour comes from the ParticleEmitter (pastel rarity tints).
```text
A single small rounded star shape with soft edges, pure white on a plain pure black background, centered, simple, particle texture for a game, no text (second image: a single small rounded heart shape)
```

#### UI_PetCard — 펫 상세 카드 (빈 판)
- 용도: Pet detail view: a big portrait window (the icon or a ViewportFrame of the 3D pet), live text name, stars and stat strip. Stays blank so text is KO/EN live.
- 크기: 512x640 · 투명 · 시점: launch · 3D: False
- 검사·거절: Generate only after the shared panel style is approved, and use it as the style reference. The portrait window must be empty.
```text
Blank vertical pet profile card, rounded rectangle, soft cream parchment inside, a large empty circular portrait window near the top, an empty horizontal ribbon band near the bottom, thin warm brown border with small paw-print ornaments in the corners, blank game UI part for a kids fantasy RPG, soft painted toy style, crisp clean edges, symmetrical, front view, flat, isolated on a plain medium grey background, no shadow, no text, no letters, no numbers, no icons inside
```

#### UI_CodexBook — 펫 도감 책 (빈 펼침면)
- 용도: Background for the pet codex (sticker-book feel). Slots, silhouettes, names and hints are laid out in code on top.
- 크기: 1024x640 · 투명 · 시점: launch · 3D: False
- 검사·거절: Keep the pages clean and flat (no printed grid or fake writing). The center fold should be subtle.
```text
Blank open storybook spread for a pet sticker album, two empty cream pages, a soft blue ribbon bookmark, small paw-print decorations in the page corners, rounded warm brown cover edges, blank game UI part for a kids fantasy RPG, soft painted toy style, crisp clean edges, symmetrical, front view, flat, isolated on a plain medium grey background, no shadow, no text, no letters, no numbers, no icons inside
```

#### UI_CodexSlotUnknown — 도감 빈칸 (아직 못 찾음)
- 용도: Codex slot for a pet not yet found. The dark silhouette of the approved icon is laid over it in UI, with a live-text hint below.
- 크기: 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: No question-mark glyph (keep it language-free). Same outer size as the rarity frames.
```text
An empty rounded square sticker slot with a dashed soft brown outline and a faint paw print watermark in the middle, blank game UI part for a kids fantasy RPG, soft painted toy style, crisp clean edges, symmetrical, front view, flat, isolated on a plain medium grey background, no shadow, no text, no letters, no numbers
```

#### UI_CodexStamp — 도감 발견 도장
- 용도: Stamp that pops onto a codex slot the first time a species is found, and a region-complete stamp.
- 크기: 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Amber, not red (red is reserved for Horns or danger). No words on the stamp ring.
```text
A round rubber-stamp style badge with a paw print and a small star in the center, warm amber ink look with slightly uneven stamped edges, cute game UI icon for a kids fantasy RPG, single object, bold simple shape, centered, fills about 80 percent of the square, isolated on a plain pure white background, no shadow, no text, no letters, no logo
```

#### Icon_CodexMedal — 도감 완성 메달
- 용도: Reward icon for completing a region page or the whole codex (pairs with a title such as '초원 펫 박사').
- 크기: 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: No numbers or engraving.
```text
A round golden medal with a paw print in the center hanging from a soft sky-blue ribbon, cute game UI icon for a kids fantasy RPG, single object, bold simple shape, soft cel shading with gentle gradient, clean dark rim outline, centered, fills about 80 percent of the square, isolated on a plain pure white background, no shadow, no text, no letters, no logo
```

#### Icon_PetStatDamage — 펫 능력 아이콘 - 몬스터 공격
- 용도: MonsterDamage buff icon (PvE only). The Gold and XP stat icons reuse the general coin and XP icons from the icon pass.
- 크기: 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: No claws, scratches or blood. Warm orange-peach, not red.
```text
A cute rounded paw swipe with three soft curved motion arcs and a tiny sparkle, cute game UI icon for a kids fantasy RPG, single object, bold simple shape, soft cel shading with gentle gradient, clean dark rim outline, centered, fills about 80 percent of the square, isolated on a plain pure white background, no shadow, no text, no letters, no logo
```

#### Icon_PetStatMP — 펫 능력 아이콘 - MP 회복
- 용도: MPRegen buff icon.
- 크기: 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: It must not look like the MP potion icon: no bottle.
```text
A glossy blue mana droplet with a small sparkle and a soft circular refresh arrow around it, cute game UI icon for a kids fantasy RPG, single object, bold simple shape, soft cel shading with gentle gradient, clean dark rim outline, centered, fills about 80 percent of the square, isolated on a plain pure white background, no shadow, no text, no letters, no logo
```

#### Prop_PetNest — 펫 둥지 (교차로 건물)
- 용도: World landmark at Crossroads where the gold egg nest is sold, and a photo spot. The concept goes to Tripo (or a parts build matched to it).
- 크기: 1024x1024 · 투명 · 시점: launch · 3D: True
- 검사·거절: No faction colours (Crossroads is neutral): no red, teal or Halo gold trim. No sign text; use a live BillboardGui.
```text
A big cozy pet nest stall for a kids fantasy village, a giant round straw nest on a low wooden platform with three large pastel eggs resting in it (mint, acorn-brown and sandstone), a small wooden awning with soft cream and leaf-green striped cloth, a little flower garland, chunky low-poly toy style, three-quarter view, centered, isolated on a plain pure white background, soft even lighting, no ground shadow, no text, no sign lettering, no logo
```

#### NPC_NestKeeper — 펫 둥지 지기 NPC
- 용도: Final look for the egg-nest keeper (temporary default Roblox NPC until approved). Used for the dialog portrait, and the HumanoidDescription colours and clothing are matched to it.
- 크기: 1024x1024 · 투명 · 시점: launch · 3D: False
- 검사·거절: No anime or chibi proportions. No exposed shoulders, midriff or legs. No brand marks.
```text
A friendly egg keeper character in blocky toy-avatar style, square head, simple flat smiling face, chunky limbs, long-sleeve cream shirt, full-length brown overalls covering the legs, sturdy boots, work gloves, wide straw hat, holding a small basket of pastel eggs, fully covered shoulders torso midriff and legs, modest kid-friendly outfit, full body, front three-quarter view, centered, isolated on a plain pure white background, soft even lighting, no ground shadow, no text, no letters, no logo
```

#### Story_P1_LostBabySlime — P1 퀘스트 삽화 (길 잃은 아기 슬라임)
- 용도: Illustration for the P1 story panel. Launch, or beta stretch only if the Story panel already supports an image slot. It sets up the cute care-or-tame moment.
- 크기: 1024x576 · 불투명 · 시점: launch · 3D: False
- 검사·거절: Nothing scary: the big slimes are teasing, not attacking. Match the approved Pet_BabySlime look exactly (use it as the Style Reference).
```text
Storybook illustration for a kids game: a tiny pale mint-white baby jelly slime with a leaf sprout on its head hiding behind a big flower in a sunny pastel meadow, three bigger green jelly slimes bouncing nearby looking mischievous, soft painted toy style with chunky rounded low-poly shapes, bright cheerful lighting, wide shot, no people, no text, no letters, no logo
```

#### Pet_CrownJelly — 왕관 젤리 (전설)
- 용도: Legendary pet from the Skeleton King boss (later). Special material tier: translucent gold jelly with a rainbow glint.
- 크기: 1024x1024 concept -> 256x256 icon · 투명 · 시점: later · 3D: True
- 검사·거절: It must differ from the baby slime (gold, no sprout). The crown shard touches the head (one piece).
```text
A jelly slime pet with a pale golden translucent body and a soft rainbow shimmer inside, wearing a tiny broken golden crown shard tilted on its head, proud happy smile, cute low-poly toy figurine pet for a kids game, chunky rounded shapes with soft subtle facets, glossy black oval eyes with one white highlight, soft pastel colors with simple gradient shading, bold clean silhouette, three-quarter front view, full body, centered, isolated on a plain pure white background, soft even lighting, no ground shadow, no text, no letters, no logo, no watermark
```

#### Acc_PetHats_Set — 펫 모자 장식 세트 (8종)
- 용도: Cosmetic head-top accessories from quests and codex milestones, never sold and with no stats. Generate one per subject: flower crown (meadow), acorn cap (forest), silver knight helmet with a tiny gold halo crest (Halo), plum bandana with tiny horn bumps (Horns), brass goggles with teal lenses (Artisan), pumpkin hat (Halloween), green-and-white winter pom-pom hat (Christmas), knit scarf. Each is an icon plus a small Blender mesh on PetHeadTop.
- 크기: 256x256 icon each · 투명 · 시점: later · 3D: True
- 검사·거절: No red Santa hat (red is reserved; use green and white). No weapons as accessories.
```text
A tiny flower crown of pink and yellow daisies as a pet accessory, cute game UI icon for a kids fantasy RPG, single object, bold simple shape, soft cel shading with gentle gradient, clean dark rim outline, centered, fills about 80 percent of the square, isolated on a plain pure white background, no shadow, no text, no letters, no logo (swap the subject for each of the 8 accessories)
```

#### Icon_PetTricks_Set — 펫 재주 아이콘 세트 (5종)
- 용도: Buttons for pet tricks unlocked by pet level: Lv1 hop, Lv3 sit, Lv5 spin, Lv7 cheer jump, Lv10 form pose. The animation is code-only (no rig).
- 크기: 128x128 each · 투명 · 시점: later · 3D: False
- 검사·거절: No letters such as Zzz or words. Keep them generic so they suit every species.
```text
A small curved hop arrow bouncing over a tiny cushion, cute game UI icon for a kids fantasy RPG, single object, bold simple shape, soft cel shading, clean dark rim outline, centered, isolated on a plain pure white background, no shadow, no text, no letters (other subjects: a soft sitting cushion, a circular spin arrow, a cheering pom-pom with sparkles, a small trophy podium with a star)
```

#### Bubble_PetMood_Set — 펫 기분 말풍선 세트 (6종)
- 용도: Small bubbles that pop above a pet: heart (owner gets a good item), music note (kill streak), star (owner levels up), blue sweat drop (owner low HP), moon with stars (idle long), yellow spark (pet levels up). Language-free.
- 크기: 128x128 each · 투명 · 시점: later · 3D: False
- 검사·거절: No letters or punctuation glyphs. Grey background because the bubble is white.
```text
A round white speech bubble with a small tail containing a pink heart, cute game UI icon for a kids fantasy RPG, single object, bold simple shape, soft cel shading, clean dark rim outline, centered, isolated on a plain medium grey background, no shadow, no text, no letters (swap the inner symbol: music note, yellow star, blue sweat drop, crescent moon with tiny stars, yellow lightning spark)
```

#### Pet_Seasonal_Set — 계절 펫 (호박 슬라임 아기 · 눈송이 펭귄)
- 용도: Seasonal egg pets that return every year (no 'last chance' wording): Halloween pumpkin slimelet, Christmas snow penguin. Concepts plus icons plus Tripo.
- 크기: 1024x1024 concept -> 256x256 icon (each) · 투명 · 시점: later · 3D: True
- 검사·거절: No carved scary jack-o-lantern face; the pumpkin slime has normal cute eyes. No grey penguin; use navy.
```text
A tiny pumpkin-orange jelly slime pet with a little green stem and curly leaf on top, friendly smile, cute low-poly toy figurine pet for a kids game, chunky rounded shapes with soft subtle facets, smooth matte vinyl look, glossy black oval eyes with one white highlight, soft pastel colors, bold clean silhouette, three-quarter front view, full body, centered, isolated on a plain pure white background, soft even lighting, no ground shadow, no text, no letters, no logo (second: a round navy-and-white baby penguin pet wearing a small green knit scarf, same style)
```

#### Egg_Seasonal_Set — 계절 알 (호박 알 · 눈꽃 알)
- 용도: Eggs for the seasonal pets: a Halloween harvest egg and a Christmas snowflake egg. They return yearly.
- 크기: 1024x1024 concept -> 256x256 icon (each) · 투명 · 시점: later · 3D: True
- 검사·거절: No spooky faces. The snowflakes are simple shapes.
```text
A pumpkin-orange pet egg with soft vertical ridges and a little green stem cap, cute fantasy pet egg, smooth glossy toy egg, slightly chubby egg shape standing upright, three-quarter front view, centered, isolated on a plain pure white background, soft even lighting, no ground shadow, no text, no letters, no logo (second: a pale icy-blue egg with white snowflake patterns)
```

### 2-3. 무기

#### Weapon_Warrior_T3 — 철 검 아이콘 (무기 스타일 기준 1장)
- 용도: 무기 아이콘 전체의 스타일 기준. 승인되면 모든 무기 아이콘의 Style reference로 쓰고, 검 아이콘의 Composition reference로도 쓴다. Config.UIArt.Weapon_Warrior_T3 교체 (고급★2, 대장간 800골드)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: beta · 3D: False
- 검사·거절: no text/letters/runes/logo/watermark, no frame or rarity glow outside outline, no hands, no scenery, no cast shadow, no checkerboard, no second weapon, no realistic gritty metal, no blood; reject if outline is broken or thinner than ~3% width
```text
A sturdy iron sword: straight broad steel-gray blade with a bright beveled edge, simple dark iron crossguard with square ends, dark blue leather grip, round iron pommel. Solid and dependable. Laid diagonally at 45 degrees, grip bottom-left, blade tip top-right. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Warrior_T8 — 젤리 왕관 검 아이콘
- 용도: 새 키 Weapon_Warrior_T8. 지금은 그림이 없어 IconSword로 대신 보임. 슬라임 대박 전설★5 (베타에 이미 있는 기능)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: beta · 3D: False
- 검사·거절: no teal/cyan jelly (teal = Neutral), no slime face on the weapon, no see-through holes after cutout, no text, no frame, no outer glow haze, no hands
```text
A legendary jelly crown sword: chunky rounded blade of bright slime-green jelly with little bubbles inside and a glossy wobbly surface, a tiny shiny gold crown sitting on the crossguard, gold grip with a round green jelly pommel. Cute, bouncy, special treasure. Jelly painted as solid opaque green with white highlights, no see-through areas. Laid diagonally at 45 degrees, grip bottom-left, blade tip top-right. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Mage_T8 — 젤리 왕관 지팡이 아이콘
- 용도: 새 키 Weapon_Mage_T8. 슬라임 대박 전설★5 (지금 그림 없음)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: beta · 3D: False
- 검사·거절: no face on the jelly orb, no teal, no see-through holes, no text, no frame, no hands
```text
A legendary jelly crown staff: gold shaft topped with a round bright slime-green jelly orb wearing a tiny shiny gold crown, little bubbles inside the orb, a jelly drip curling down the shaft. Cute, bouncy, special treasure. Jelly painted as solid opaque green with white highlights, no see-through areas. Laid diagonally at 45 degrees, staff foot bottom-left, head top-right. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Archer_T8 — 젤리 왕관 활 아이콘
- 용도: 새 키 Weapon_Archer_T8. 슬라임 대박 전설★5 (지금 그림 없음)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: beta · 3D: False
- 검사·거절: no arrow, no teal, no see-through holes, no text, no frame, no hands
```text
A legendary jelly crown bow: bouncy limbs of bright slime-green jelly with little bubbles inside, gold caps on both tips, a tiny shiny gold crown above the grip, gold string. Cute, bouncy, special treasure. Jelly painted as solid opaque green with white highlights, no see-through areas. Laid diagonally at 45 degrees, limbs running bottom-left to top-right, grip at center, taut string on the lower-right side, no arrow. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Warrior_T1 — 나뭇가지 아이콘 (전사 시작 무기)
- 용도: Config.UIArt.Weapon_Warrior_T1 교체. 첫 10분 HUD 무기 칸·아이템 목록 (일반★1)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: beta · 3D: False
- 검사·거절: no metal, no gems, no glow (lowest tier must look humble), no text, no frame, no hands, no extra loose leaves floating
```text
A sturdy crooked tree branch used as a beginner's sword: brown bark stick, one small fork near the grip wrapped with pale twine, two bright green leaves near the tip. Humble, cute, simple. Laid diagonally at 45 degrees, grip bottom-left, blade tip top-right. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Mage_T1 — 마른 지팡이 아이콘
- 용도: Config.UIArt.Weapon_Mage_T1 교체 (일반★1)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: beta · 3D: False
- 검사·거절: no gems, no metal, no strong glow, no text, no frame, no hands
```text
A dry wooden beginner's staff: thin knobby pale-brown branch, the top curls into a small spiral holding a smooth round river pebble with a faint pale-blue shine, a tiny green leaf below the spiral. Humble and simple. Laid diagonally at 45 degrees, staff foot bottom-left, head top-right. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Archer_T1 — 새총 활 아이콘
- 용도: Config.UIArt.Weapon_Archer_T1 교체 (일반★1). 게임 속 3D가 활 모양이라 Y자 새총이 아닌 '나뭇가지로 구부린 작은 활'로 그림
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: beta · 3D: False
- 검사·거절: no Y-shaped slingshot with pouch (in-game model is a bow), no arrow, no metal, no text, no frame, no hands
```text
A tiny beginner's bow bent from a forked twig: knobby brown wood, pale twine string, the grip wrapped with a scrap of tan cloth, one small green leaf tied to the upper limb. Humble, cute, simple. Laid diagonally at 45 degrees, limbs running bottom-left to top-right, grip at center, taut string on the lower-right side, no arrow. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Warrior_T2 — 나무 검 아이콘
- 용도: Config.UIArt.Weapon_Warrior_T2 교체 (일반★1, 대장간 150골드, 첫 쇼핑)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: beta · 3D: False
- 검사·거절: no metal blade, no gems, no glow, no text, no frame, no hands
```text
A wooden practice sword: smooth light-oak blade with a rounded tip, simple flat wooden crossguard, grip wrapped in brown rope, round wooden pommel. Clean and friendly, two materials only. Laid diagonally at 45 degrees, grip bottom-left, blade tip top-right. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Mage_T2 — 참나무 지팡이 아이콘
- 용도: Config.UIArt.Weapon_Mage_T2 교체 (일반★1)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: beta · 3D: False
- 검사·거절: no gems, no metal, no glow, no text, no frame, no hands
```text
An oak wizard staff: straight polished light-oak shaft, the top grows into a rounded knot cradling a big shiny acorn, a ring of brown rope tied below the head. Clean and friendly. Laid diagonally at 45 degrees, staff foot bottom-left, head top-right. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Archer_T2 — 나무 활 아이콘
- 용도: Config.UIArt.Weapon_Archer_T2 교체 (일반★1)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: beta · 3D: False
- 검사·거절: no arrow, no metal, no gems, no text, no frame, no hands
```text
A wooden hunting bow: smooth light-oak limbs with gently curled tips, brown leather grip wrap, cream string. Clean and friendly, two materials only. Laid diagonally at 45 degrees, limbs running bottom-left to top-right, grip at center, taut string on the lower-right side, no arrow. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Mage_T3 — 철 지팡이 아이콘
- 용도: Config.UIArt.Weapon_Mage_T3 교체 (고급★2)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: beta · 3D: False
- 검사·거절: no gold, no strong glow, no text, no frame, no hands
```text
An iron-bound staff: dark wood shaft with steel bands, the head is a small iron cage of four prongs holding a smooth pale-blue stone. Solid and dependable. Laid diagonally at 45 degrees, staff foot bottom-left, head top-right. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Archer_T3 — 철 활 아이콘
- 용도: Config.UIArt.Weapon_Archer_T3 교체 (고급★2)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: beta · 3D: False
- 검사·거절: no arrow, no gold, no text, no frame, no hands
```text
An iron-reinforced bow: dark wood limbs with steel caps and steel bands near both tips, dark blue leather grip, taut cream string. Solid and dependable. Laid diagonally at 45 degrees, limbs running bottom-left to top-right, grip at center, taut string on the lower-right side, no arrow. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Warrior_T4 — 숲도둑 황금 검 아이콘
- 용도: Config.UIArt.Weapon_Warrior_T4 교체 (희귀★3, 고블린 드랍, 이름 '황금' → '숲도둑 황금')
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: beta · 3D: False
- 검사·거절: no blood, no jagged realistic serration, no goblin face, no sapphire-and-gold royal look (that was the old design), no text, no frame, no hands
```text
A goblin-made golden sword of stolen treasure: wide chunky gold blade with a playful hooked notch near the tip, mismatched patches and big round rivets, crossguard of two curled gold hooks, grip wrapped in forest-green cloth, a small cream goblin-tooth charm dangling on a cord. Gaudy, mischievous, lumpy hand-made look. Laid diagonally at 45 degrees, grip bottom-left, blade tip top-right. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Mage_T4 — 숲도둑 황금 지팡이 아이콘
- 용도: Config.UIArt.Weapon_Mage_T4 교체 (희귀★3)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: beta · 3D: False
- 검사·거절: no symbols or letters stamped on the coin, no goblin face, no text, no frame, no hands
```text
A goblin-made golden staff: crooked gold shaft with lumpy hand-hammered bands, the top is a big shiny gold coin held in a curled gold claw, a forest-green cloth tassel and a small cream goblin-tooth charm hanging below. Gaudy and mischievous. Laid diagonally at 45 degrees, staff foot bottom-left, head top-right. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Archer_T4 — 숲도둑 황금 활 아이콘
- 용도: Config.UIArt.Weapon_Archer_T4 교체 (희귀★3)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: beta · 3D: False
- 검사·거절: no arrow, no goblin face, no text, no frame, no hands
```text
A goblin-made golden bow: asymmetric gold limbs with hooked tips and big round rivets, forest-green cloth grip, a small cream goblin-tooth charm and a green leaf tied to the grip. Gaudy, mischievous, lumpy hand-made look. Laid diagonally at 45 degrees, limbs running bottom-left to top-right, grip at center, taut string on the lower-right side, no arrow. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Warrior_T5 — 옛 왕국 수정 검 아이콘
- 용도: Config.UIArt.Weapon_Warrior_T5 교체 (희귀★3, 해골 유적 드랍, 이름 '크리스탈' → '옛 왕국 수정')
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: beta · 3D: False
- 검사·거절: no runes or letter-like engravings, no see-through crystal holes after cutout, no silver-and-navy copy of the old icon, no text, no frame, no hands
```text
An ancient kingdom crystal sword: long faceted ice-blue crystal blade, carved ivory-white stone hilt with smooth swirl grooves, crossguard shaped like a small crown, round blue gem in the pommel. Elegant, old and noble. Crystal painted as solid opaque color with white highlights, no see-through areas. Laid diagonally at 45 degrees, grip bottom-left, blade tip top-right. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Mage_T5 — 옛 왕국 수정 지팡이 아이콘
- 용도: Config.UIArt.Weapon_Mage_T5 교체 (희귀★3)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: beta · 3D: False
- 검사·거절: no runes, no see-through holes, no text, no frame, no hands
```text
An ancient kingdom crystal staff: tall carved ivory-white stone shaft with smooth swirl grooves, the head is a crown-shaped stone claw holding a large faceted ice-blue crystal. Elegant, old and noble. Crystal painted as solid opaque color with white highlights, no see-through areas. Laid diagonally at 45 degrees, staff foot bottom-left, head top-right. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Archer_T5 — 옛 왕국 수정 활 아이콘
- 용도: Config.UIArt.Weapon_Archer_T5 교체 (희귀★3)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: beta · 3D: False
- 검사·거절: no arrow, no runes, no see-through holes, no text, no frame, no hands
```text
An ancient kingdom crystal bow: carved ivory-white stone limbs with smooth swirl grooves, faceted ice-blue crystal tips on both ends, a small crown ornament above the grip, pale blue string. Elegant, old and noble. Crystal painted as solid opaque color with white highlights, no see-through areas. Laid diagonally at 45 degrees, limbs running bottom-left to top-right, grip at center, taut string on the lower-right side, no arrow. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Warrior_T6 — 수호령 검 아이콘
- 용도: Config.UIArt.Weapon_Warrior_T6 교체 (영웅★4, 해골 기사 드랍, 이름 '네온' → '수호령'). 청록 대신 연보라
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: beta · 3D: False
- 검사·거절: no skulls, no ghost faces, no mint/teal flame (teal = Neutral), no see-through flame holes, no smoke outside outline, no text, no frame, no hands
```text
A friendly guardian spirit sword: blade made of soft lavender spirit flame with gentle swirls, set in an old dark-silver knight hilt with a small round shield-shaped crest on the crossguard, violet leather grip. Magical and calm, not scary. Flame painted as solid opaque lavender with white highlights, no see-through areas. Laid diagonally at 45 degrees, grip bottom-left, blade tip top-right. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Mage_T6 — 수호령 지팡이 아이콘
- 용도: Config.UIArt.Weapon_Mage_T6 교체 (영웅★4)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: beta · 3D: False
- 검사·거절: no skulls, no faces in the flame, no teal, no see-through holes, no text, no frame, no hands
```text
A friendly guardian spirit lantern staff: dark-silver knight shaft, the head is an old lantern frame holding a cheerful round lavender spirit flame, a small violet ribbon tied below the lantern. Magical and calm, not scary. Flame painted as solid opaque lavender with white highlights, no see-through areas. Laid diagonally at 45 degrees, staff foot bottom-left, head top-right. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Archer_T6 — 수호령 활 아이콘
- 용도: Config.UIArt.Weapon_Archer_T6 교체 (영웅★4)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: beta · 3D: False
- 검사·거절: no arrow, no skulls, no teal, no see-through holes, no text, no frame, no hands
```text
A friendly guardian spirit bow: old dark-silver knight bow limbs with feather-shaped tips, the string is a glowing lavender light line, a soft lavender spirit flame wisp curls around the grip. Magical and calm, not scary. Painted as solid opaque color with white highlights, no see-through areas. Laid diagonally at 45 degrees, limbs running bottom-left to top-right, grip at center, taut string on the lower-right side, no arrow. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### UIP_GradeSlotBack — 등급 칸 바탕판 (공용)
- 용도: 아이템 목록·대장간·드랍 팝업의 무기 아이콘 뒤 빈 칸. 한 장을 모든 등급이 공유(펫 칸과도 공유 가능). 등급 표시 B2(베타 확정)용
- 크기: 512x512 (generate 2048 1:1, downscale) · 투명 · 시점: beta · 3D: False
- 검사·거절: no item drawn inside, no border color (rim is a separate tintable layer), no text, no drop shadow, no perspective tilt
```text
A blank square game inventory slot tile with rounded corners: deep navy-blue rounded square with a soft inner gradient, lighter at the top, and a subtle beveled inner edge. Chunky toy-like 3D game UI part, glossy, clean. Straight front view, centered, fills 90% of the square. Isolated on a plain pure white background, no shadow. Completely empty inside: no item, no icon, no text, no letters, no numbers.
```

#### UIP_GradeSlotRim — 등급 칸 테두리 (색 입히는 용)
- 용도: 바탕판 위에 겹치는 테두리. 거의 흰색으로 만들고 코드가 ImageColor3로 등급 5색을 입힘(전설만 UIGradient 반짝임). 그림 전에는 UIStroke 대체 그림으로 작동
- 크기: 512x512 (generate 2048 1:1, downscale) · 투명 · 시점: beta · 3D: False
- 검사·거절: no colored tint (must stay near-white so code tint works), check hollow center is fully transparent after cutout (cut locally with a rounded-rect mask if not), no text, no perspective
```text
A blank rounded-square frame ring for a game inventory slot: thick beveled rim in near-white pearl with soft light-gray shading and one glossy highlight on the top edge, rounded corners, completely hollow empty center. Chunky toy-like 3D game UI part, clean. Straight front view, centered, fills 90% of the square. Isolated on a plain flat mid-gray background, no shadow. No ornaments, no gems, no text, no letters, no numbers.
```

#### UIP_GradeStar — 등급 별 (색 입히는 용)
- 용도: 무기 이름 옆 ★1~5. 거의 흰 별 한 장을 등급색으로 입히고, 빈 별은 같은 그림을 어둡게. HUD 영역의 별과 하나로 합쳐도 됨
- 크기: 256x256 (generate 2048 1:1, downscale) · 투명 · 시점: beta · 3D: False
- 검사·거절: no gold/yellow fill (must be near-white for tinting), no sparkles outside outline, no text
```text
A single chunky five-point star icon with rounded points, near-white pearl fill with soft light-gray shading and a glossy highlight, thick dark navy outline. Chunky toy-like 3D game UI icon. Straight front view, centered, fills 85% of the square. Isolated on a plain flat mid-gray background, no shadow. Exactly one star, no sparkles around it, no text, no letters, no numbers.
```

#### Fx_TrailRibbon — 휘두르기 궤적 텍스처 (흑백)
- 용도: Feel.slashTrail·화살 꼬리 Trail.Texture. 희귀 이상·강화 +7/+10 궤적. 색은 Trail.Color로 등급색. 강화 빛과 함께 정식(베타는 질문 Q2 답에 따름)
- 크기: 1024x256 (generate 16:9, crop) · 투명 · 시점: launch · 3D: False
- 검사·거절: no color (tinted in code), no hard rectangle edges, no objects; convert luminance→alpha locally, keep RGB white
```text
A horizontal soft light streak texture for a sword swing trail: bright solid white at the left edge fading smoothly to pure black at the right edge, slightly wavy soft top and bottom edges, a few tiny white sparkle dots along it. White and gray only, no color. On a plain pure black background, the streak spans the full width of the frame. No objects, no text, no letters.
```

#### Fx_Sparkle4 — 네 갈래 반짝이 (흑백)
- 용도: 영웅 이상 무기 상시 반짝이, 강화 +10 무기 주위를 도는 별, 강화 성공 연출. ParticleEmitter.Texture, 색은 코드로
- 크기: 256x256 (generate 2048 1:1, downscale) · 투명 · 시점: launch · 3D: False
- 검사·거절: no color, no multiple stars, no lens-flare rings; convert luminance→alpha locally
```text
A single four-point twinkle star sparkle with crisp tapered rays and a tiny round glow at the center, pure white on a plain pure black background, centered, fills 80% of the square. No color, no other objects, no text.
```

#### Fx_GlowSoft — 부드러운 빛 공 (흑백)
- 용도: 무기 머리·강화 빛 후광 입자, 드랍 빛 바탕. (PIL 원형 그라데이션으로 대신 만들어도 됨: 그림 스타일이 아닌 기술 텍스처)
- 크기: 256x256 (generate 2048 1:1, downscale) · 투명 · 시점: launch · 3D: False
- 검사·거절: no rings, no banding, no color; convert luminance→alpha locally
```text
A single perfectly round soft glow orb: bright white center fading smoothly to pure black at the edges, no rings, no rays, centered on a plain pure black background, fills 90% of the square. No color, no objects, no text.
```

#### Fx_LightPillar — 드랍 빛기둥 (흑백)
- 용도: 희귀 이상 무기가 떨어진 자리의 빛기둥(Beam/빌보드). 높이·색은 등급별로 코드가
- 크기: 256x1024 (generate 9:16, crop) · 투명 · 시점: launch · 3D: False
- 검사·거절: no color, no ground, no objects; convert luminance→alpha locally
```text
A vertical beam of light texture: a soft white column, brightest at the bottom and fading upward to pure black at the top, soft blurry side edges, a few tiny rising white sparkle dots. White and gray only. On a plain pure black background, the column centered and filling the full height. No objects, no text.
```

#### UIP_LootRays — 보상 팝업 빛살 (흑백)
- 용도: 희귀 이상 무기 획득 팝업·새 무기 자랑 화면 뒤에서 천천히 도는 빛살. 등급색으로 입힘
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: launch · 3D: False
- 검사·거절: no color, no item in the center, no uneven ray spacing; convert luminance→alpha locally
```text
A soft radial burst of light rays for a game reward popup: 16 wide rays fanning out evenly from the center, bright white center fading to pure black at the edges, a few small sparkle dots between the rays. White and gray only. Straight front view, centered on a plain pure black background. No objects, no text, no letters.
```

#### UIP_WeaponShowcase — 새 무기 자랑 받침대
- 용도: 희귀 이상 첫 획득 때 1.5초 '자랑 화면'에서 무기 아이콘을 올려 두는 빈 받침대. 빛살과 함께 씀
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: launch · 3D: False
- 검사·거절: no item on the pedestal, no gold or rarity color (code adds grade color), no characters, no text, no stage curtains
```text
An empty game reward display pedestal: a short round warm-cream stone pedestal with one simple pale trim ring, seen from the front slightly above, a soft spotlight from above, nothing on top. Chunky toy-like 3D game UI art, bright kid-friendly colors. Pedestal sits in the lower third, empty space above it for an item. Isolated on a plain pure white background, no shadow, no text, no letters.
```

#### Weapon_Warrior_T7_Halo — 여명의 검 아이콘 (빛의 기사단)
- 용도: Config.UIArt.Weapon_Warrior_T7_Halo 교체 (전설★5, 정식 장인 제작)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: launch · 3D: False
- 검사·거절: no religious symbols, no light rays outside the outline, no red, no text, no frame, no hands
```text
A holy dawn sword of the halo knights: gleaming white marble-and-gold blade with a warm golden edge, crossguard shaped like small spread white wings, a thin floating golden halo ring circling the hilt, sunrise-orange gem in the pommel. Radiant, heroic, clean. Laid diagonally at 45 degrees, grip bottom-left, blade tip top-right. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Mage_T7_Halo — 여명의 지팡이 아이콘
- 용도: Config.UIArt.Weapon_Mage_T7_Halo 교체 (전설★5)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: launch · 3D: False
- 검사·거절: no religious symbols, no rays outside outline, no text, no frame, no hands
```text
A holy dawn staff of the halo knights: white marble shaft with gold bands, the head is a glowing warm-gold sun orb encircled by a thin floating golden halo ring, two small white wings below the orb. Radiant and heroic. Laid diagonally at 45 degrees, staff foot bottom-left, head top-right. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Archer_T7_Halo — 여명의 활 아이콘
- 용도: Config.UIArt.Weapon_Archer_T7_Halo 교체 (전설★5)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: launch · 3D: False
- 검사·거절: no arrow, no loose floating feathers, no text, no frame, no hands
```text
A holy dawn bow of the halo knights: limbs shaped like long white feathered wings with gold trim, a thin golden halo ring floating above the grip, warm gold string. Radiant and heroic. Laid diagonally at 45 degrees, limbs running bottom-left to top-right, grip at center, taut string on the lower-right side, no arrow. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Warrior_T7_Horns — 파멸의 검 아이콘 (뿔 군단)
- 용도: Config.UIArt.Weapon_Warrior_T7_Horns 교체 (전설★5)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: launch · 3D: False
- 검사·거절: no skulls, no blood, no demon faces, no flames leaving the outline, no spikes thinner than the outline, no text, no frame, no hands
```text
A cartoon villain sword of the horns legion: dark charcoal-stone blade with glowing orange lava cracks, crossguard made of two curled dark horns, crimson cloth grip, small ember-orange gem in the pommel. Mischievous cartoon villain style, bold and fun, not scary. Laid diagonally at 45 degrees, grip bottom-left, blade tip top-right. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Mage_T7_Horns — 파멸의 지팡이 아이콘
- 용도: Config.UIArt.Weapon_Mage_T7_Horns 교체 (전설★5)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: launch · 3D: False
- 검사·거절: no skulls, no eyes in the orb, no blood, no text, no frame, no hands
```text
A cartoon villain staff of the horns legion: dark charcoal-stone shaft with crimson bands, the head is two curled dark horns cradling a glowing ember-orange orb, faint orange lava cracks along the shaft. Mischievous cartoon villain style, bold and fun, not scary. Laid diagonally at 45 degrees, staff foot bottom-left, head top-right. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Archer_T7_Horns — 파멸의 활 아이콘
- 용도: Config.UIArt.Weapon_Archer_T7_Horns 교체 (전설★5)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: launch · 3D: False
- 검사·거절: no arrow, no skulls, no blood, no text, no frame, no hands
```text
A cartoon villain bow of the horns legion: limbs shaped like two long curled dark horns with glowing orange lava cracks, crimson cloth grip, ember-orange string. Mischievous cartoon villain style, bold and fun, not scary. Laid diagonally at 45 degrees, limbs running bottom-left to top-right, grip at center, taut string on the lower-right side, no arrow. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Warrior_T7_Neutral — 왕관 조각 검 아이콘 (장인 길드)
- 용도: Config.UIArt.Weapon_Warrior_T7_Neutral 교체 (전설★5)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: launch · 3D: False
- 검사·거절: no gray-only palette (gray = gray legend), no red, no tiny gear teeth thinner than outline, no text, no frame, no hands
```text
A master artisan's crown-shard sword: precise brass-and-steel blade with a glowing teal crown-shard crystal set in its center, crossguard shaped like a brass gear, dark brown leather grip, small brass pommel. Crafted, precise, clean workshop quality. Crystal painted as solid opaque color with white highlights, no see-through areas. Laid diagonally at 45 degrees, grip bottom-left, blade tip top-right. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Mage_T7_Neutral — 왕관 조각 지팡이 아이콘
- 용도: Config.UIArt.Weapon_Mage_T7_Neutral 교체 (전설★5)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: launch · 3D: False
- 검사·거절: no red, no gray-only palette, no text, no frame, no hands
```text
A master artisan's crown-shard staff: brass shaft with neat steel rivets, the head holds a glowing teal crown-shard crystal inside two floating brass gear rings. Crafted, precise, clean workshop quality. Crystal painted as solid opaque color with white highlights, no see-through areas. Laid diagonally at 45 degrees, staff foot bottom-left, head top-right. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Archer_T7_Neutral — 왕관 조각 활 아이콘 (보류)
- 용도: Config.UIArt.Weapon_Archer_T7_Neutral. 장인 길드 궁수가 펫 훈련사로 바뀔 수 있어(A23-13) 결정 뒤에 만든다
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: later · 3D: False
- 검사·거절: hold until pet-trainer class decision; no arrow, no red, no text, no frame, no hands
```text
A master artisan's crown-shard bow: brass and dark-wood limbs with small brass gear pulleys at both tips, a glowing teal crown-shard crystal set above the grip, steel string. Crafted, precise, clean workshop quality. Crystal painted as solid opaque color with white highlights, no see-through areas. Laid diagonally at 45 degrees, limbs running bottom-left to top-right, grip at center, taut string on the lower-right side, no arrow. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### WeaponConcept_Start — 3D 시안: 시작 무기 계열 (나뭇가지·마른 지팡이·새총 활)
- 용도: 정식 3D 무기(Tripo) 전 모양 승인용 시트. 승인 뒤 같은 문구로 무기 1개씩 2048 측면 렌더를 다시 뽑아 Tripo 입력으로 씀
- 크기: 16:9 largest (about 2688x1536); Tripo inputs 2048x2048 each · 불투명 · 시점: launch · 3D: True
- 검사·거절: no outline (bakes into 3D texture), no perspective tilt, no overlapping weapons, no labels, no hands
```text
Weapon design concept sheet for one matching beginner set: a crooked brown branch sword with twine wrap and two green leaves, a knobby dry-wood staff with a spiral top holding a smooth pebble, a tiny twig bow with twine string and a leaf charm. The sword, the staff and the bow stand upright side by side, flat orthographic side view, evenly spaced, same scale, each fully visible. Chunky toy-like 3D render, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, even soft studio lighting, no outline, no strong reflections. Plain solid light-gray background, no shadow, no ground. No hands, no characters, no text, no labels, no letters.
```

#### WeaponConcept_Wood — 3D 시안: 나무 계열
- 용도: 정식 3D 무기 시안 (T2, 일반★1)
- 크기: 16:9 largest (about 2688x1536); Tripo inputs 2048x2048 each · 불투명 · 시점: launch · 3D: True
- 검사·거절: no outline, no perspective, no labels, no hands
```text
Weapon design concept sheet for one matching wooden set: a light-oak practice sword with rope-wrapped grip and round wooden pommel, an oak staff whose top knot cradles a big shiny acorn, a light-oak hunting bow with curled tips and brown leather grip. The sword, the staff and the bow stand upright side by side, flat orthographic side view, evenly spaced, same scale, each fully visible. Chunky toy-like 3D render, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, even soft studio lighting, no outline, no strong reflections. Plain solid light-gray background, no shadow, no ground. No hands, no characters, no text, no labels, no letters.
```

#### WeaponConcept_Iron — 3D 시안: 철 계열
- 용도: 정식 3D 무기 시안 (T3, 고급★2)
- 크기: 16:9 largest (about 2688x1536); Tripo inputs 2048x2048 each · 불투명 · 시점: launch · 3D: True
- 검사·거절: no outline, no mirror-like chrome reflections, no labels, no hands
```text
Weapon design concept sheet for one matching iron set: a broad steel-gray sword with square-ended dark iron crossguard and dark blue grip, a dark wood staff with steel bands and a four-prong iron cage holding a pale-blue stone, a dark wood bow with steel caps and bands. The sword, the staff and the bow stand upright side by side, flat orthographic side view, evenly spaced, same scale, each fully visible. Chunky toy-like 3D render, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, even soft studio lighting, no outline, no strong reflections. Plain solid light-gray background, no shadow, no ground. No hands, no characters, no text, no labels, no letters.
```

#### WeaponConcept_ForestThief — 3D 시안: 숲도둑 황금 계열
- 용도: 정식 3D 무기 시안 (T4, 희귀★3, 고블린 테마)
- 크기: 16:9 largest (about 2688x1536); Tripo inputs 2048x2048 each · 불투명 · 시점: launch · 3D: True
- 검사·거절: no goblin faces, no blood, no symbols on the coin, no labels, no hands
```text
Weapon design concept sheet for one matching goblin-made stolen-gold set: a wide lumpy gold sword with a hooked notch, big rivets, curled hook crossguard, green cloth grip and goblin-tooth charm; a crooked gold staff topped with a big gold coin in a curled claw and a green tassel; an asymmetric gold bow with hooked tips, rivets and a tooth charm. The sword, the staff and the bow stand upright side by side, flat orthographic side view, evenly spaced, same scale, each fully visible. Chunky toy-like 3D render, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, even soft studio lighting, no outline, no strong reflections. Plain solid light-gray background, no shadow, no ground. No hands, no characters, no text, no labels, no letters.
```

#### WeaponConcept_OldKingdom — 3D 시안: 옛 왕국 수정 계열
- 용도: 정식 3D 무기 시안 (T5, 희귀★3)
- 크기: 16:9 largest (about 2688x1536); Tripo inputs 2048x2048 each · 불투명 · 시점: launch · 3D: True
- 검사·거절: no runes, no transparent glass (breaks 3D texture), no labels, no hands
```text
Weapon design concept sheet for one matching ancient kingdom crystal set: a sword with a long faceted ice-blue crystal blade, carved ivory-white stone hilt and small crown-shaped crossguard; a tall ivory stone staff whose crown-shaped claw holds a big faceted ice-blue crystal; an ivory stone bow with crystal tips and a small crown above the grip. Crystal painted as solid opaque color with highlights. The sword, the staff and the bow stand upright side by side, flat orthographic side view, evenly spaced, same scale, each fully visible. Chunky toy-like 3D render, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, even soft studio lighting, no outline, no strong reflections. Plain solid light-gray background, no shadow, no ground. No hands, no characters, no text, no labels, no letters.
```

#### WeaponConcept_GuardianSpirit — 3D 시안: 수호령 계열
- 용도: 정식 3D 무기 시안 (T6, 영웅★4). 3D에서는 불꽃 부분을 Neon 파트+입자로 나눌 수 있게 모양을 단순하게
- 크기: 16:9 largest (about 2688x1536); Tripo inputs 2048x2048 each · 불투명 · 시점: launch · 3D: True
- 검사·거절: no skulls, no ghost faces, no teal, no wispy smoke detail, no labels, no hands
```text
Weapon design concept sheet for one matching friendly guardian spirit set: a sword with a soft lavender spirit-flame blade in an old dark-silver knight hilt with a round shield crest; a dark-silver lantern staff holding a round lavender spirit flame; a dark-silver knight bow with feather-shaped tips and a lavender light string. Flames are smooth solid shapes. Magical, calm, not scary. The sword, the staff and the bow stand upright side by side, flat orthographic side view, evenly spaced, same scale, each fully visible. Chunky toy-like 3D render, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, even soft studio lighting, no outline, no strong reflections. Plain solid light-gray background, no shadow, no ground. No hands, no characters, no text, no labels, no letters.
```

#### WeaponConcept_Dawn — 3D 시안: 여명 계열 (빛의 기사단)
- 용도: 정식 3D 진영 무기 시안 (T7, 전설★5)
- 크기: 16:9 largest (about 2688x1536); Tripo inputs 2048x2048 each · 불투명 · 시점: launch · 3D: True
- 검사·거절: no religious symbols, no light rays, no labels, no hands
```text
Weapon design concept sheet for one matching holy dawn set of the halo knights: a white marble-and-gold sword with small white wing crossguard and a thin gold halo ring around the hilt; a white marble staff with a warm-gold sun orb inside a gold halo ring and two small wings; a bow with white feathered-wing limbs, gold trim and a halo ring above the grip. The sword, the staff and the bow stand upright side by side, flat orthographic side view, evenly spaced, same scale, each fully visible. Chunky toy-like 3D render, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, even soft studio lighting, no outline, no strong reflections. Plain solid light-gray background, no shadow, no ground. No hands, no characters, no text, no labels, no letters.
```

#### WeaponConcept_Ruin — 3D 시안: 파멸 계열 (뿔 군단)
- 용도: 정식 3D 진영 무기 시안 (T7, 전설★5)
- 크기: 16:9 largest (about 2688x1536); Tripo inputs 2048x2048 each · 불투명 · 시점: launch · 3D: True
- 검사·거절: no skulls, no blood, no demon faces, horns at least chunky (min ~2 studs in 3D), no labels, no hands
```text
Weapon design concept sheet for one matching cartoon villain set of the horns legion: a dark charcoal-stone sword with orange lava cracks, curled horn crossguard and crimson grip; a charcoal staff whose curled horns cradle an ember-orange orb; a bow with long curled dark horn limbs and lava cracks. Mischievous cartoon villain style, not scary. The sword, the staff and the bow stand upright side by side, flat orthographic side view, evenly spaced, same scale, each fully visible. Chunky toy-like 3D render, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, even soft studio lighting, no outline, no strong reflections. Plain solid light-gray background, no shadow, no ground. No hands, no characters, no text, no labels, no letters.
```

#### WeaponConcept_CrownShard — 3D 시안: 왕관 조각 계열 (장인 길드)
- 용도: 정식 3D 진영 무기 시안 (T7, 전설★5). 활은 펫 훈련사 결정에 따라 빠질 수 있음
- 크기: 16:9 largest (about 2688x1536); Tripo inputs 2048x2048 each · 불투명 · 시점: launch · 3D: True
- 검사·거절: no red, no gray-only palette, no tiny gear teeth, no labels, no hands
```text
Weapon design concept sheet for one matching master artisan set: a precise brass-and-steel sword with a teal crown-shard crystal set in the blade and a brass gear crossguard; a brass staff with a teal crown-shard crystal inside two brass gear rings; a brass and dark-wood bow with small gear pulleys at the tips and a teal shard above the grip. Crafted, precise, clean workshop quality. The sword, the staff and the bow stand upright side by side, flat orthographic side view, evenly spaced, same scale, each fully visible. Chunky toy-like 3D render, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, even soft studio lighting, no outline, no strong reflections. Plain solid light-gray background, no shadow, no ground. No hands, no characters, no text, no labels, no letters.
```

#### WeaponConcept_JellyCrown — 3D 시안: 젤리 왕관 계열 (대박 전설)
- 용도: 정식 3D 무기 시안 (T8, 전설★5). 원래 27종에 빠져 있던 3종
- 크기: 16:9 largest (about 2688x1536); Tripo inputs 2048x2048 each · 불투명 · 시점: launch · 3D: True
- 검사·거절: no teal, no slime faces, no transparent glass, no labels, no hands
```text
Weapon design concept sheet for one matching legendary jelly crown set: a chunky rounded slime-green jelly sword with bubbles inside and a tiny gold crown on the crossguard; a gold staff topped with a round slime-green jelly orb wearing a tiny gold crown; a bouncy slime-green jelly bow with gold tips and a tiny crown above the grip. Jelly as smooth solid glossy color. Cute, bouncy, special. The sword, the staff and the bow stand upright side by side, flat orthographic side view, evenly spaced, same scale, each fully visible. Chunky toy-like 3D render, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, even soft studio lighting, no outline, no strong reflections. Plain solid light-gray background, no shadow, no ground. No hands, no characters, no text, no labels, no letters.
```

#### WeaponConcept_SleepingKing — 3D 시안: 잠든 왕 계열 (새 영웅, 보스 드랍)
- 용도: 정식 새 계열 #10 (영웅★4, 해골왕 보스 드랍) 모양 제안. 이야기: 무덤에서 왕관을 부르는 '잠든 왕'
- 크기: 16:9 largest (about 2688x1536); Tripo inputs 2048x2048 each · 불투명 · 시점: launch · 3D: True
- 검사·거절: no skulls, no coffins, no zombie or undead imagery, no labels, no hands
```text
Weapon design concept sheet for one matching sleepy old king's royal set: midnight-blue and silver with soft crescent moon and star motifs and royal purple velvet grips; a long silver sword with a starry blue groove and a crescent moon crossguard; a staff topped with a silver crescent moon cradling a pale glowing star; a bow with crescent-moon shaped limbs and a small star charm. Dreamy, regal, calm, not spooky. The sword, the staff and the bow stand upright side by side, flat orthographic side view, evenly spaced, same scale, each fully visible. Chunky toy-like 3D render, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, even soft studio lighting, no outline, no strong reflections. Plain solid light-gray background, no shadow, no ground. No hands, no characters, no text, no labels, no letters.
```

#### WeaponConcept_BubbleJelly — 3D 시안: 말랑 방울 계열 (선택 새 고급 무기)
- 용도: 설계 B7/L3 #9 말랑 방울(고급★2, 왕 슬라임 1%) 모양 제안. 젤리 왕관보다 단순·연한 초록, 왕관 없음
- 크기: 16:9 largest (about 2688x1536); Tripo inputs 2048x2048 each · 불투명 · 시점: launch · 3D: True
- 검사·거절: no crown or gold (that is the legendary jelly crown), no teal, no labels, no hands
```text
Weapon design concept sheet for one matching simple bubble jelly set: a sword with a rounded light-green jelly blade lined with round bubble beads and a plain wooden grip; a wooden staff topped with a cluster of light-green jelly bubbles; a bow with bead-like light-green jelly limbs and a wooden grip. Soft, squishy, simple, less shiny than treasure, no crown. The sword, the staff and the bow stand upright side by side, flat orthographic side view, evenly spaced, same scale, each fully visible. Chunky toy-like 3D render, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, even soft studio lighting, no outline, no strong reflections. Plain solid light-gray background, no shadow, no ground. No hands, no characters, no text, no labels, no letters.
```

#### WeaponConcept_PumpkinLantern — 3D 시안: 호박 등불 계열 (핼러윈, 내년)
- 용도: 핼러윈 이벤트 무기 계열 제안(희귀★3). 올해 베타의 핼러윈 몬스터는 설계대로 기존 무기 줄과 사탕 재료만 떨어뜨림
- 크기: 16:9 largest (about 2688x1536); Tripo inputs 2048x2048 each · 불투명 · 시점: later · 3D: True
- 검사·거절: no scary carved faces, no skulls, no bats with fangs, no blood, no labels, no hands
```text
Weapon design concept sheet for one matching friendly harvest pumpkin set: a curved orange pumpkin-skin sword with soft ridges, curled green vine crossguard and a tiny smiling jack-o'-lantern pommel; a twisted vine staff topped with a small smiling jack-o'-lantern glowing warm yellow and a wrapped candy charm; a bow of curled pumpkin vines with two tiny smiling lantern charms and purple string. Cute festival treat style, not scary. The sword, the staff and the bow stand upright side by side, flat orthographic side view, evenly spaced, same scale, each fully visible. Chunky toy-like 3D render, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, even soft studio lighting, no outline, no strong reflections. Plain solid light-gray background, no shadow, no ground. No hands, no characters, no text, no labels, no letters.
```

#### Weapon_Warrior_Pumpkin — 호박 등불 검 아이콘 (핼러윈, 내년)
- 용도: 핼러윈 계열 아이콘(희귀★3). 계열을 Config.Weapons 뒤에 붙일 때 키 이름은 그때 WeaponArtKey 규칙에 맞춤
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: later · 3D: False
- 검사·거절: no scary face, no skulls, no blood, no text, no frame, no hands
```text
A friendly harvest pumpkin sword: curved orange pumpkin-skin blade with soft ridges, crossguard of curled green vines with a small leaf, a tiny smiling jack-o'-lantern pommel glowing warm yellow, purple ribbon on the grip. Cute festival treat style, not scary. Laid diagonally at 45 degrees, grip bottom-left, blade tip top-right. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Mage_Pumpkin — 호박 등불 지팡이 아이콘 (핼러윈, 내년)
- 용도: 핼러윈 계열 아이콘(희귀★3)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: later · 3D: False
- 검사·거절: no scary face, no skulls, no text, no frame, no hands
```text
A friendly harvest pumpkin lantern staff: twisted green vine shaft, the head is a small smiling jack-o'-lantern glowing warm yellow, a purple ribbon and a wrapped candy charm hanging below. Cute festival treat style, not scary. Laid diagonally at 45 degrees, staff foot bottom-left, head top-right. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### Weapon_Archer_Pumpkin — 호박 등불 활 아이콘 (핼러윈, 내년)
- 용도: 핼러윈 계열 아이콘(희귀★3)
- 크기: 1024x1024 (generate 2048 1:1, downscale) · 투명 · 시점: later · 3D: False
- 검사·거절: no arrow, no scary face, no text, no frame, no hands
```text
A friendly harvest pumpkin bow: limbs of curled green pumpkin vine with small leaves, two tiny smiling jack-o'-lantern charms at the tips, purple string. Cute festival treat style, not scary. Laid diagonally at 45 degrees, limbs running bottom-left to top-right, grip at center, taut string on the lower-right side, no arrow. Chunky toy-like 3D game item icon, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, soft studio light from the top-left, thick dark navy outline around the whole silhouette, any glow painted inside the outline. Centered, fills about 80% of the square. Isolated on a plain pure white background, no shadow, no ground. Exactly one weapon, no hands, no characters, no text, no letters, no numbers, no frame, no border.
```

#### WeaponConcept_Snowflake — 3D 시안: 눈꽃 결정 계열 (겨울 이벤트 선택)
- 용도: 설계 L3 #11 눈꽃(희귀★3, 12/19~1/4 이벤트, 선택) 모양 제안. 크리스마스 꾸밈과 함께 사용자가 원할 때
- 크기: 16:9 largest (about 2688x1536); Tripo inputs 2048x2048 each · 불투명 · 시점: later · 3D: True
- 검사·거절: must not look like the Old Kingdom crystal line (snowflake shapes, white-dominant), no labels, no hands
```text
Weapon design concept sheet for one matching cozy winter snowflake set: frosty white and pale-blue snowflake crystal shapes; a sword with an icy pale-blue blade and a six-point snowflake crossguard; a staff topped with a big six-point snowflake; a bow with icicle-shaped tips and a small snowflake charm above the grip. Crystal as smooth solid color with highlights. Cozy and festive. The sword, the staff and the bow stand upright side by side, flat orthographic side view, evenly spaced, same scale, each fully visible. Chunky toy-like 3D render, blocky low-poly shapes with soft rounded bevels, smooth matte plastic, polished metal and glossy gem materials, bright saturated kid-friendly colors, even soft studio lighting, no outline, no strong reflections. Plain solid light-gray background, no shadow, no ground. No hands, no characters, no text, no labels, no letters.
```

#### FxKill_Coin — 처치 효과 입자: 금화 (숲도둑 황금)
- 용도: 숲도둑 황금 무기로 몬스터를 처치하면 금화가 팡 튀는 효과(몬스터만, PvP 처치에는 안 씀)
- 크기: 256x256 (generate 2048 1:1, downscale) · 투명 · 시점: later · 3D: False
- 검사·거절: no currency symbols or letters, no stack of coins, no text
```text
A single shiny chunky gold coin, slightly tilted, rounded rim, a simple embossed star in the middle. Chunky toy-like 3D game particle sprite, bright saturated colors, soft studio light from the top-left, thin dark navy outline. Centered, fills 80% of the square. Isolated on a plain pure white background, no shadow. Exactly one coin, no text, no letters, no numbers.
```

#### FxKill_Crystal — 처치 효과 입자: 수정 조각 (옛 왕국 수정)
- 용도: 옛 왕국 수정 무기 처치 효과
- 크기: 256x256 (generate 2048 1:1, downscale) · 투명 · 시점: later · 3D: False
- 검사·거절: no see-through holes, no cluster, no text
```text
A single small faceted ice-blue crystal shard with a bright white highlight, painted as solid opaque color, no see-through areas. Chunky toy-like 3D game particle sprite, soft studio light from the top-left, thin dark navy outline. Centered, fills 80% of the square. Isolated on a plain pure white background, no shadow. Exactly one shard, no text.
```

#### FxKill_Wisp — 처치 효과 입자: 연보라 불씨 (수호령)
- 용도: 수호령 무기 처치 효과(작은 불씨가 위로 올라감)
- 크기: 256x256 (generate 2048 1:1, downscale) · 투명 · 시점: later · 3D: False
- 검사·거절: no face or eyes, no teal, no skull, no text
```text
A single small friendly lavender spirit flame wisp with a soft curl at the top, painted as solid opaque lavender with white highlights. Chunky toy-like 3D game particle sprite, soft studio light, thin dark navy outline. Centered, fills 80% of the square. Isolated on a plain pure white background, no shadow. No face, no text.
```

#### FxKill_Feather — 처치 효과 입자: 흰 깃털 (여명)
- 용도: 여명 무기 처치 효과
- 크기: 256x256 (generate 2048 1:1, downscale) · 투명 · 시점: later · 3D: False
- 검사·거절: cut out on white bg is hard for a white feather: if fringe appears, regenerate on plain flat mid-gray; no text
```text
A single small soft white feather with a warm golden tip. Chunky toy-like 3D game particle sprite, soft studio light from the top-left, thin dark navy outline. Centered, fills 80% of the square. Isolated on a plain pure white background, no shadow. Exactly one feather, no text.
```

#### FxKill_Ember — 처치 효과 입자: 만화 불티 (파멸)
- 용도: 파멸 무기 처치 효과(귀여운 만화 불티)
- 크기: 256x256 (generate 2048 1:1, downscale) · 투명 · 시점: later · 3D: False
- 검사·거절: no realistic fire, no smoke, no face, no text
```text
A single small cartoon ember spark: rounded flame shape, bright yellow-orange center with a crimson rim. Chunky toy-like 3D game particle sprite, thin dark navy outline. Centered, fills 80% of the square. Isolated on a plain pure white background, no shadow. No face, no text.
```

#### FxKill_Gear — 처치 효과 입자: 황동 톱니 (왕관 조각)
- 용도: 왕관 조각 무기 처치 효과
- 크기: 256x256 (generate 2048 1:1, downscale) · 투명 · 시점: later · 3D: False
- 검사·거절: no thin teeth, no text, no extra gears
```text
A single small chunky brass gear with eight rounded teeth and a teal gem in the center. Chunky toy-like 3D game particle sprite, soft studio light from the top-left, thin dark navy outline. Centered, fills 80% of the square. Isolated on a plain pure white background, no shadow. Exactly one gear, no text.
```

#### FxKill_JellyDrop — 처치 효과 입자: 젤리 방울 (젤리 왕관·말랑 방울)
- 용도: 젤리 계열 처치 효과(젤리 방울이 통통 튐)
- 크기: 256x256 (generate 2048 1:1, downscale) · 투명 · 시점: later · 3D: False
- 검사·거절: no face, no teal, no see-through holes, no text
```text
A single small bright slime-green jelly droplet with a glossy white highlight, painted as solid opaque green, no see-through areas. Chunky toy-like 3D game particle sprite, thin dark navy outline. Centered, fills 80% of the square. Isolated on a plain pure white background, no shadow. No face, no text.
```

#### FxKill_Candy — 처치 효과 입자: 사탕 (호박 등불)
- 용도: 핼러윈 계열 처치 효과
- 크기: 256x256 (generate 2048 1:1, downscale) · 투명 · 시점: later · 3D: False
- 검사·거절: no brand-like wrapper prints, no text
```text
A single wrapped candy with orange and purple stripes and twisted wrapper ends. Chunky toy-like 3D game particle sprite, soft studio light from the top-left, thin dark navy outline. Centered, fills 80% of the square. Isolated on a plain pure white background, no shadow. Exactly one candy, no text, no letters.
```

#### Ref_GripPoses — 무기 잡는 손 자세 참고 시트
- 용도: RELEASE_PLAN 메모 '무기 쥔 손 모양 이상함·공격 모션 단조로움' 고칠 때 쓸 참고 그림(업로드 안 함). 블록 장난감 아바타, 옷 완전히 가림
- 크기: 16:9 largest (about 2688x1536) · 불투명 · 시점: later · 3D: False
- 검사·거절: no bare skin except face and hands, no crop tops or shorts, no anime/chibi proportions, no brand logos or platform name, no weapons pointed at viewer
```text
Pose reference sheet: three identical blocky toy-avatar figures with square heads, simple flat friendly faces and chunky limbs, each wearing a fully covered adventurer outfit: long-sleeved tunic covering the shoulders and torso, no bare midriff, full-length trousers, boots and gloves. Left figure grips a sword in a closed fist in a ready stance; middle figure holds a staff upright with the fist wrapped around the shaft; right figure draws a bow, front fist on the grip, back hand at the string. Side by side, front three-quarter view, same scale, even soft studio light. Plain solid light-gray background, no shadow. No text, no logos, no labels.
```

### 2-4. 캐릭터·NPC·몬스터

#### CLS_HaloWarrior_M — 직업 그림 · 빛 전사(성기사) 남
- 용도: 직업 선택 카드 그림(CharHaloWarriorM 교체). 이 그림을 스타일 기준(앵커)으로 먼저 4안 제작
- 크기: Firefly 3:4 (약 1792x2240) → 누끼·다듬기 → 원본 1024 높이 보관, 게임용 약 420x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject: anime/chibi oversized eyes, realistic human proportions, bare neck/shoulders/forearms, brick-toy studs or C-shaped claw hands, letters or emblems that look like text, logos, weapon pointed at viewer, halo ring filled in after cutout.
```text
Holy paladin hero, male, short golden-blond hair, warm confident smile. Modest fully covered outfit with only face and hands visible: white padded tunic with high collar and long sleeves, rounded gold shoulder guards, sky-blue tabard, gold belt, full-length white trousers, gold-trimmed boots, white gloves. Holds a gold-hilted broadsword upright beside a round white shield with a sunburst ring emblem. Thick golden halo ring floating above the head. White, gold and sky-blue palette, round friendly shapes. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body heroic standing pose, slight three-quarter view, whole figure in frame, isolated on a plain flat light-gray background with wide empty margin.
```

#### CLS_HaloWarrior_F — 직업 그림 · 빛 전사(성기사) 여
- 용도: 직업 선택 카드 그림(CharHaloWarriorF). 남 그림을 구도 참조로
- 크기: Firefly 3:4 → 누끼 → 게임용 약 420x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject: curvy or shaped torso (must match male block body), short skirt, bare legs, anime eyes, lipstick-heavy face, text, logos.
```text
Holy paladin hero, female, long golden ponytail, determined smile. Modest fully covered outfit with only face and hands visible: white padded tunic with high collar and long sleeves, rounded gold shoulder guards, knee-length sky-blue tabard over full-length white trousers, gold belt, gold-trimmed boots, white gloves. Holds a gold-hilted broadsword and a round white shield with a sunburst ring emblem. Thick golden halo ring floating above the head. White, gold and sky-blue palette, round friendly shapes. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body heroic standing pose, slight three-quarter view, whole figure in frame, isolated on a plain flat light-gray background with wide empty margin.
```

#### CLS_HaloMage_M — 직업 그림 · 빛의 마법사 남
- 용도: 직업 선택 카드 그림(CharHaloMageM)
- 크기: Firefly 3:4 → 누끼 → 게임용 약 420x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject: wizard beard cliché that hides the face, glowing runes that look like letters, anime eyes, open-chest robe, text.
```text
Light mage hero, male, neat light-brown hair, gentle smile. Modest fully covered outfit with only face and hands visible: ankle-length white robe with high collar and long sleeves, gold trim, sky-blue sash, white trousers and boots underneath, white gloves. Holds a tall white staff topped with a glowing golden star orb, small golden sparkles around it. Thick golden halo ring floating above the head. White, gold and sky-blue palette, round friendly shapes. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body casting pose with the staff raised, slight three-quarter view, whole figure in frame, isolated on a plain flat light-gray background with wide empty margin.
```

#### CLS_HaloMage_F — 직업 그림 · 빛의 마법사 여
- 용도: 직업 선택 카드 그림(CharHaloMageF)
- 크기: Firefly 3:4 → 누끼 → 게임용 약 420x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject: shaped torso, off-shoulder or slit robe, anime eyes, rune letters, text.
```text
Light mage hero, female, long wavy pale-blonde hair with a small sky-blue ribbon, bright smile. Modest fully covered outfit with only face and hands visible: ankle-length white robe with high collar and long sleeves, gold trim, sky-blue sash, white trousers and boots underneath, white gloves. Holds a tall white staff topped with a glowing golden star orb, small golden sparkles around it. Thick golden halo ring floating above the head. White, gold and sky-blue palette, round friendly shapes. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body casting pose with the staff raised, slight three-quarter view, whole figure in frame, isolated on a plain flat light-gray background with wide empty margin.
```

#### CLS_HaloArcher_M — 직업 그림 · 빛 궁수(레인저) 남
- 용도: 직업 선택 카드 그림(CharHaloArcherM)
- 크기: Firefly 3:4 → 누끼 → 게임용 약 420x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject: arrow aimed at the viewer, sleeveless tunic, anime eyes, bowstring gap filled by cutout, text.
```text
Ranger hero, male, tousled sandy hair, friendly grin. Modest fully covered outfit with only face and hands visible: white long-sleeve tunic with high collar, short sky-blue hooded capelet covering the shoulders, brown leather belt, back quiver, full-length tan trousers, knee-high boots, archery gloves. Holds a gold-trimmed wooden longbow with an arrow nocked and aimed upward. Thick golden halo ring floating above the head. White, gold and sky-blue palette, round friendly shapes. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body heroic standing pose, slight three-quarter view, whole figure in frame, isolated on a plain flat light-gray background with wide empty margin.
```

#### CLS_HaloArcher_F — 직업 그림 · 빛 궁수(레인저) 여
- 용도: 직업 선택 카드 그림(CharHaloArcherF). 옛 윙크 그림 참조 금지
- 크기: Firefly 3:4 → 누끼 → 게임용 약 420x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject: wink pose copied from old chibi art, crop top, shorts, shaped torso, anime eyes, text.
```text
Ranger hero, female, two golden braids, cheerful grin. Modest fully covered outfit with only face and hands visible: white long-sleeve tunic with high collar, short sky-blue hooded capelet covering the shoulders, brown leather belt, back quiver, full-length tan trousers, knee-high boots, archery gloves. Holds a gold-trimmed wooden longbow with an arrow nocked and aimed upward. Thick golden halo ring floating above the head. White, gold and sky-blue palette, round friendly shapes. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body heroic standing pose, slight three-quarter view, whole figure in frame, isolated on a plain flat light-gray background with wide empty margin.
```

#### CLS_HornsWarrior_M — 직업 그림 · 뿔 전사(광전사) 남
- 용도: 직업 선택 카드 그림(CharHornsWarriorM)
- 크기: Firefly 3:4 → 누끼 → 게임용 약 420x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject: bare muscular arms or chest, fangs, sharp realistic spikes, skulls, blood-like red splashes, menacing glare, text.
```text
Berserker hero from a cartoon villain army, male, spiky black hair, two short chunky curved red horns, cheeky grin. Modest fully covered outfit with only face and hands visible: charcoal padded jacket with high collar and long sleeves, crimson shoulder guards with blunt rounded spikes, crimson belt, full-length dark trousers, heavy boots, black gloves. Rests a big chunky dark sword with a blunt zigzag edge and ember-orange glow lines on his shoulder. Charcoal, crimson and ember-orange palette, triangle shapes with rounded tips, playful cartoon mischief. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body heroic standing pose, slight three-quarter view, whole figure in frame, isolated on a plain flat light-gray background with wide empty margin.
```

#### CLS_HornsWarrior_F — 직업 그림 · 뿔 전사(광전사) 여
- 용도: 직업 선택 카드 그림(CharHornsWarriorF)
- 크기: Firefly 3:4 → 누끼 → 게임용 약 420x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject: armor bikini or cut-outs, shaped torso, fangs, scary glare, text.
```text
Berserker hero from a cartoon villain army, female, short messy dark-red bob hair, two short chunky curved red horns, confident smirk. Modest fully covered outfit with only face and hands visible: charcoal padded jacket with high collar and long sleeves, crimson shoulder guards with blunt rounded spikes, crimson belt, full-length dark trousers, heavy boots, black gloves. Rests a big chunky dark sword with a blunt zigzag edge and ember-orange glow lines on her shoulder. Charcoal, crimson and ember-orange palette, triangle shapes with rounded tips, playful cartoon mischief. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body heroic standing pose, slight three-quarter view, whole figure in frame, isolated on a plain flat light-gray background with wide empty margin.
```

#### CLS_HornsMage_M — 직업 그림 · 흑마법사 남
- 용도: 직업 선택 카드 그림(CharHornsMageM)
- 크기: Firefly 3:4 → 누끼 → 게임용 약 420x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject: occult symbols, pentagrams, skulls on staff, glowing runes like letters, shadowed scary face, text.
```text
Dark mage hero from a cartoon villain army, male, messy black hair, two short curved red horns poking out of a hood, mischievous grin. Modest fully covered outfit with only face and hands visible: ankle-length crimson-and-charcoal hooded robe with high collar and long sleeves, ember-orange trim, dark trousers and boots underneath, black gloves. Holds a crooked dark-wood staff topped with a glowing ember-orange crystal, tiny ember sparks floating. Charcoal, crimson and ember-orange palette, triangle shapes with rounded tips, playful cartoon mischief. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body casting pose with the staff raised, slight three-quarter view, whole figure in frame, isolated on a plain flat light-gray background with wide empty margin.
```

#### CLS_HornsMage_F — 직업 그림 · 흑마법사 여
- 용도: 직업 선택 카드 그림(CharHornsMageF)
- 크기: Firefly 3:4 → 누끼 → 게임용 약 420x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject: old revealing Horns mage design, slit robe, bare legs, shaped torso, occult symbols, text.
```text
Dark mage hero from a cartoon villain army, female, long straight black hair with one crimson streak, two short curved red horns, sly smile. Modest fully covered outfit with only face and hands visible: ankle-length crimson-and-charcoal hooded robe with high collar and long sleeves, ember-orange trim, dark trousers and boots underneath, black gloves. Holds a crooked dark-wood staff topped with a glowing ember-orange crystal, tiny ember sparks floating. Charcoal, crimson and ember-orange palette, triangle shapes with rounded tips, playful cartoon mischief. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body casting pose with the staff raised, slight three-quarter view, whole figure in frame, isolated on a plain flat light-gray background with wide empty margin.
```

#### CLS_HornsArcher_M — 직업 그림 · 그림자 사냥꾼 남
- 용도: 직업 선택 카드 그림(CharHornsArcherM)
- 크기: Firefly 3:4 → 누끼 → 게임용 약 420x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject: ninja mask hiding whole face, assassin dagger poses, arrow at viewer, scary glare, text.
```text
Shadow hunter hero from a cartoon villain army, male, charcoal hood with two short chunky red horns poking through, crimson scarf wrapped up to the chin, sly confident eyes. Modest fully covered outfit with only face and hands visible: charcoal long-sleeve jacket with crimson trim, full-length dark trousers, boots, gloves, back quiver with crimson-fletched arrows. Holds a dark recurve bow with glowing ember-orange tips. Charcoal, crimson and ember-orange palette, triangle shapes with rounded tips, playful cartoon mischief. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body heroic standing pose, slight three-quarter view, whole figure in frame, isolated on a plain flat light-gray background with wide empty margin.
```

#### CLS_HornsArcher_F — 직업 그림 · 그림자 사냥꾼 여
- 용도: 직업 선택 카드 그림(CharHornsArcherF)
- 크기: Firefly 3:4 → 누끼 → 게임용 약 420x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject: bodysuit, shaped torso, bare legs, ninja mask, text.
```text
Shadow hunter hero from a cartoon villain army, female, long dark ponytail falling from a charcoal hood with two short chunky red horns poking through, crimson scarf wrapped up to the chin, sly confident eyes. Modest fully covered outfit with only face and hands visible: charcoal long-sleeve jacket with crimson trim, full-length dark trousers, boots, gloves, back quiver with crimson-fletched arrows. Holds a dark recurve bow with glowing ember-orange tips. Charcoal, crimson and ember-orange palette, triangle shapes with rounded tips, playful cartoon mischief. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body heroic standing pose, slight three-quarter view, whole figure in frame, isolated on a plain flat light-gray background with wide empty margin.
```

#### CLS_ArtisanWarrior_M — 직업 그림 · 장인 전사(대장장이) 남
- 용도: 직업 선택 카드 그림(CharNeutralWarriorM)
- 크기: Firefly 3:4 → 누끼 → 게임용 약 420x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject: rolled-up sleeves showing forearms, bare neck skin, gray-dominant outfit, gear emblem fused to head, text.
```text
Blacksmith hero of an artisan guild, male, short brown hair, work goggles pushed up on the forehead, calm proud smile. Modest fully covered outfit with only face and hands visible: long-sleeve brown work shirt with high collar, teal leather apron from chest to knees, brass buckles, full-length canvas trousers, sturdy boots, thick work gloves. Holds a sturdy steel broadsword, a small smithing hammer hanging from the belt. Chunky teal gear emblem floating above the head. Teal, brass and warm brown palette, boxy practical shapes. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body heroic standing pose, slight three-quarter view, whole figure in frame, isolated on a plain flat light-gray background with wide empty margin.
```

#### CLS_ArtisanWarrior_F — 직업 그림 · 장인 전사(대장장이) 여
- 용도: 직업 선택 카드 그림(CharNeutralWarriorF)
- 크기: Firefly 3:4 → 누끼 → 게임용 약 420x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject: open collar showing neck skin (old design had this), shaped torso, text.
```text
Blacksmith hero of an artisan guild, female, curly auburn hair tied up under a teal bandana, work goggles on the forehead, calm proud smile. Modest fully covered outfit with only face and hands visible: long-sleeve brown work shirt with high collar, teal leather apron from chest to knees, brass buckles, full-length canvas trousers, sturdy boots, thick work gloves. Holds a sturdy steel broadsword, a small smithing hammer hanging from the belt. Chunky teal gear emblem floating above the head. Teal, brass and warm brown palette, boxy practical shapes. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body heroic standing pose, slight three-quarter view, whole figure in frame, isolated on a plain flat light-gray background with wide empty margin.
```

#### CLS_ArtisanMage_M — 직업 그림 · 장인 마법사(연금술사) 남
- 용도: 직업 선택 카드 그림(CharNeutralMageM)
- 크기: Firefly 3:4 → 누끼 → 게임용 약 420x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject: goggles covering the eyes, labels on vials, smoke that looks toxic, mad-scientist grimace, text.
```text
Alchemist hero of an artisan guild, male, short dark hair, round brass goggles resting on the forehead, curious friendly smile. Modest fully covered outfit with only face and hands visible: ankle-length teal coat with high collar and long sleeves, brass buttons, belt lined with small colorful potion vials, full-length trousers, boots, gloves. Holds a brass staff topped with a glass flask of glowing teal liquid with rising bubbles. Chunky teal gear emblem floating above the head. Teal, brass and warm brown palette, boxy practical shapes. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body casting pose with the staff raised, slight three-quarter view, whole figure in frame, isolated on a plain flat light-gray background with wide empty margin.
```

#### CLS_ArtisanMage_F — 직업 그림 · 장인 마법사(연금술사) 여
- 용도: 직업 선택 카드 그림(CharNeutralMageF)
- 크기: Firefly 3:4 → 누끼 → 게임용 약 420x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject: shaped torso, labels on vials, text.
```text
Alchemist hero of an artisan guild, female, dark bob hair with round brass goggles on top, painted freckles, curious friendly smile. Modest fully covered outfit with only face and hands visible: ankle-length teal coat with high collar and long sleeves, brass buttons, belt lined with small colorful potion vials, full-length trousers, boots, gloves. Holds a brass staff topped with a glass flask of glowing teal liquid with rising bubbles. Chunky teal gear emblem floating above the head. Teal, brass and warm brown palette, boxy practical shapes. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body casting pose with the staff raised, slight three-quarter view, whole figure in frame, isolated on a plain flat light-gray background with wide empty margin.
```

#### CLS_ArtisanArcher_M — 직업 그림 · 장인 궁수(사냥꾼) 남
- 용도: 직업 선택 카드 그림(CharNeutralArcherM). 어깨 위 작은 새는 나중 '펫 훈련사' 전환을 이어 주는 장치
- 크기: Firefly 3:4 → 누끼 → 게임용 약 420x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject: animal pelts or trophies, hunting a cute animal, arrow at viewer, text.
```text
Hunter hero of an artisan guild, male, fur-trimmed brown hood, teal scarf, relaxed smile. Modest fully covered outfit with only face and hands visible: long-sleeve brown leather jacket with brass buttons, full-length canvas trousers, boots, gloves, back quiver. Holds a sturdy wooden bow with brass fittings. A tiny round teal songbird perched on his shoulder. Chunky teal gear emblem floating above the head. Teal, brass and warm brown palette, boxy practical shapes. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body heroic standing pose, slight three-quarter view, whole figure in frame, isolated on a plain flat light-gray background with wide empty margin.
```

#### CLS_ArtisanArcher_F — 직업 그림 · 장인 궁수(사냥꾼) 여
- 용도: 직업 선택 카드 그림(CharNeutralArcherF)
- 크기: Firefly 3:4 → 누끼 → 게임용 약 420x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject: shaped torso, shorts, text.
```text
Hunter hero of an artisan guild, female, short brown braids under a fur-trimmed brown hood, teal scarf, relaxed smile. Modest fully covered outfit with only face and hands visible: long-sleeve brown leather jacket with brass buttons, full-length canvas trousers, boots, gloves, back quiver. Holds a sturdy wooden bow with brass fittings. A tiny round teal songbird perched on her shoulder. Chunky teal gear emblem floating above the head. Teal, brass and warm brown palette, boxy practical shapes. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body heroic standing pose, slight three-quarter view, whole figure in frame, isolated on a plain flat light-gray background with wide empty margin.
```

#### PTR_GuideHalo — 대화 초상 · 빛의 안내자(기사단장, 여)
- 용도: 환영 3쪽 대화의 170px 초상(지금은 직업 그림을 빌려 씀), M1-4·M2-7 대화. 따뜻하고 반듯한 해요체 기사
- 크기: Firefly 1:1 (약 2048²) → 누끼 → 512x512 (표시 170x170) · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject: looks identical to the player paladin card (needs circlet, bun, cape brooch), anime eyes, bare neck, text. Must read at 170px.
```text
Head-and-shoulders portrait of a friendly knight-captain guide, female, golden hair in a neat low bun, gentle warm smile, thin gold circlet, white high-collar padded armor with rounded gold shoulder guards, sky-blue cape clasped at the chest with a round gold brooch, thick golden halo ring floating above the head. White, gold and sky-blue palette, round friendly shapes. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Slight three-quarter turn toward the viewer, face filling the upper half, square 1:1, isolated on a plain flat light-gray background.
```

#### PTR_GuideHorns — 대화 초상 · 뿔 군단 안내자(장난꾸러기 선배, 남)
- 용도: 환영 대화·뿔 진영 대화 초상. '신입' 부르는 반말 선배
- 크기: Firefly 1:1 → 누끼 → 512x512 (표시 170x170) · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject: fangs, sneer that reads as bullying, dagger, skull motifs, text.
```text
Head-and-shoulders portrait of a playful rogue guide from a cartoon villain army, male, shaggy black hair, two short chunky curved red horns, wide cheeky grin, one eyebrow raised, crimson bandana around the neck, charcoal high-collar hooded jacket with crimson trim, the strap of a lumpy coin sack across the chest. Charcoal, crimson and ember-orange palette, triangle shapes with rounded tips, playful cartoon mischief. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Slight three-quarter turn toward the viewer, face filling the upper half, square 1:1, isolated on a plain flat light-gray background.
```

#### PTR_GuideArtisan — 대화 초상 · 길드 안내자(말수 적은 장인, 여)
- 용도: 환영 대화·N1·N2 장인 길드 대화 초상
- 크기: Firefly 1:1 → 누끼 → 512x512 (표시 170x170) · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject: sleepy look that reads as sad, gray-dominant colors, text.
```text
Head-and-shoulders portrait of a quiet craftswoman guide of an artisan guild, female, short dark bob hair, calm half-lidded eyes with a tiny smirk, work goggles on the forehead, a pencil tucked behind one ear, long-sleeve brown high-collar shirt under teal apron straps with brass buckles, chunky teal gear emblem floating above the head. Teal, brass and warm brown palette, boxy practical shapes. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Slight three-quarter turn toward the viewer, face filling the upper half, square 1:1, isolated on a plain flat light-gray background.
```

#### CON_PumpkinSlime — 핼러윈 몬스터 · 호박 슬라임
- 용도: 말랑 초원 핼러윈 기간 슬라임 일부 대체(A23-15). 승인 그림 = Tripo 입력. Q2-A면 기존 슬라임 모양에 이 색·꼭지만 입힘
- 크기: Firefly 1:1 (약 2048²) → Tripo: 흰 1380² 캔버스, 위 여백 100px 이상 · 불투명 · 시점: beta · 3D: True
- 검사·거절: Reject: triangle jack-o-lantern eyes, jagged carved mouth, inner fire glare, flat thin pancake shape (user complaint about current slime), red tones, text.
```text
Cute pumpkin jelly slime monster for a kids game: plump round dome body as deep front-to-back as it is wide, glossy semi-translucent orange jelly with soft pumpkin ridges, short green stem and one curly vine leaf on top, big round shiny eyes, happy open smile with one tiny rounded tooth, rosy cheeks. Chunky stylized toy-figure monster, simple rounded shapes, smooth glossy vinyl material, bright cheerful Halloween colors, soft even studio lighting, crisp silhouette, cute and friendly. Front view, symmetrical, whole body in frame with margin, isolated on a plain flat light-gray background, square 1:1.
```

#### CON_LittleGhost — 핼러윈 몬스터 · 꼬마 유령
- 용도: 고블린 숲 핼러윈 밤 분위기 몬스터. 다리 없이 떠다녀 뼈대 대신 슬라임처럼 통통 움직임으로 처리 가능(리깅비 절약)
- 크기: Firefly 1:1 → Tripo: 흰 1380² 캔버스(유령이 흰색이라 승인용은 어두운 배경, Tripo 넣기 전 연회색으로 교체) · 불투명 · 시점: beta · 3D: True
- 검사·거절: Reject: hollow black eyes, drooping melting face, chains, tattered shroud, open screaming mouth, transparency so strong the face disappears, text.
```text
Cute little ghost monster for a kids game: small round puffy body like a soft blanket with a gently wavy hem, pale lavender-white color, big friendly dark eyes, rosy cheeks, tiny smile, small striped nightcap, tiny stubby arms holding a little glowing candy lantern, floating. Chunky stylized toy-figure monster, simple rounded shapes, smooth matte vinyl material, soft warm glow, crisp silhouette, cute and friendly. Front view, symmetrical, whole body in frame with margin, isolated on a plain flat dark slate-blue background, square 1:1.
```

#### CON_BatGoblin — 핼러윈 몬스터 · 박쥐 고블린
- 용도: 고블린 숲, 박쥐 분장을 한 '사탕 받으러 다니는' 고블린. 기존 고블린 뼈대·동작 재사용. Q2-A면 기존 고블린 모델에 망토·두건만 덧입힘
- 크기: Firefly 1:1 → Tripo: 흰 1380² 캔버스, 위 여백 100px 이상 · 불투명 · 시점: beta · 3D: True
- 검사·거절: Use a front render of art/models/Goblin.glb (tools/render_front.py) as Structure/Style reference so it matches the kept original goblin. Reject: real bat wings growing from the body, fangs, claws, blood-red cape, menacing face, text.
```text
Mischievous cartoon goblin dressed up for a Halloween costume party: green skin, big pointy ears, short stocky body, cheeky grin with small rounded teeth, purple hood with two round bat ears, purple bat-wing cape with scalloped rounded edges hanging from the shoulders, brown cloth trousers, holding an orange pumpkin candy bucket in one hand and a wooden spoon club in the other. Chunky stylized toy-figure monster, simple rounded shapes, smooth matte vinyl material, bright cheerful colors, soft even studio lighting, crisp silhouette, cute and friendly. Front view, relaxed A-pose, arms angled away from the body, feet apart, props held clear of the body, whole body in frame with margin, isolated on a plain flat light-gray background, square 1:1.
```

#### CON_PumpkinKing — 핼러윈 미니보스 · 호박 대왕 슬라임
- 용도: 말랑 초원에 정해진 시간마다 나오는 함께 잡는 미니보스(거위 방식, 사탕 재료 보상). 슬라임 형태 재사용. Q3에서 '네'면 beta로 올림
- 크기: Firefly 1:1 → Tripo: 흰 1380² 캔버스(또는 호박 슬라임 모델 2.5배 + 부품 촛불 왕관) · 불투명 · 시점: later · 3D: True
- 검사·거절: Reject: angry carved face, triangle eyes, fire spewing, dark smoke, red tones, text.
```text
Giant cute pumpkin king slime boss for a kids game: huge plump round glossy orange jelly body with deep soft pumpkin ridges, friendly lantern face with big round glowing eyes and a wide happy smile, warm golden candle-light glow inside, crooked golden crown made of little lit candles on top, curly green vine leaves draped like a royal cape, a few wrapped candies orbiting around it. Chunky stylized toy-figure monster, simple rounded shapes, smooth glossy vinyl material, bright cheerful Halloween colors, soft even studio lighting, crisp silhouette, cute and friendly. Front view, symmetrical, whole body in frame with margin, isolated on a plain flat light-gray background, square 1:1.
```

#### PTR_CrownShard — 대화 초상 · 왕관 조각(호기심 많은 아이)
- 용도: S0 '내 싸움을 배우는 왕관 조각'·S4 대화 초상(지금은 이름만). 베타로 당겨도 싼 그림
- 크기: Firefly 1:1 → 누끼 → 512x512 (표시 170x170) · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject: sharp blade-like shard, arms/legs, realistic gemstone, glow halo that bleeds into the background after cutout, text.
```text
Cute magical crown-shard character: a small floating golden crystal shard with a simple happy face, two big round eyes and a tiny open smile, soft golden glow, little sparkles around it, curious playful mood, smooth glossy gem material, stylized toy-like 3D render, soft even studio lighting, crisp silhouette, wordless plain surfaces, kid-friendly. Centered, square 1:1, isolated on a plain flat light-gray background.
```

#### PTR_FountainShard — 대화 초상 · 분수의 조각(차분한 반말)
- 용도: M2-3 '균형의 분수' 선택 대화 초상
- 크기: Firefly 1:1 → 누끼 → 512x512 · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject: creepy blank eyes, cracks that look broken or sad, droplets that look like tears, text.
```text
Serene magical fountain-shard character: a tall crystal shard of pale gold with soft aqua highlights, calm closed eyes and a gentle small smile, soft glow, tiny water droplets orbiting in a ring around it, peaceful wise mood, smooth glossy gem material, stylized toy-like 3D render, soft even studio lighting, crisp silhouette, wordless plain surfaces, kid-friendly. Centered, square 1:1, isolated on a plain flat dark slate-blue background.
```

#### FB_GuideHalo — 전신 · 빛의 안내자
- 용도: 빛의 성채 입구에 실제로 세울 안내자(지금은 월드 안내자 없음). Q1-A면 R15 조립 참고, Q1-B면 Tripo 입력. 후광은 게임 부품으로 붙임
- 크기: Firefly 1:1 (약 2048²) → 참고용 또는 Tripo 흰 1380² 캔버스 · 불투명 · 시점: launch · 3D: True
- 검사·거절: Generate with the approved PTR_GuideHalo as reference image. Reject: floating halo fused to head (added in-game), cape covering the arms, text.
```text
Friendly knight-captain guide NPC, female, golden hair in a neat low bun, gentle smile, thin gold circlet. Modest fully covered outfit with only face and hands visible: white high-collar padded armor with rounded gold shoulder guards, sky-blue cape, gold belt, knee-length white tabard over full-length white trousers, gold-trimmed boots, white gloves. Holds a rolled parchment map. White, gold and sky-blue palette, round friendly shapes. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body front view, symmetrical relaxed A-pose, arms angled away from the body, feet apart, props held clear of the body, flat even lighting, whole figure in frame with margin, isolated on a plain flat light-gray background, square 1:1.
```

#### FB_GuideHorns — 전신 · 뿔 군단 안내자
- 용도: 뿔 소굴 입구 안내자 NPC 외형
- 크기: Firefly 1:1 → 참고용 또는 Tripo 흰 1380² 캔버스 · 불투명 · 시점: launch · 3D: True
- 검사·거절: Generate with approved PTR_GuideHorns as reference. Reject: thin needle horns (Tripo loses them), weapon, sack fused to back, text.
```text
Playful rogue guide NPC from a cartoon villain army, male, lanky, shaggy black hair, two short chunky curved red horns, cheeky grin. Modest fully covered outfit with only face and hands visible: charcoal high-collar hooded jacket with crimson trim, long striped crimson-and-charcoal scarf, full-length dark trousers, boots, black gloves, lumpy brown coin sack slung over one shoulder. Charcoal, crimson and ember-orange palette, triangle shapes with rounded tips, playful cartoon mischief. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body front view, symmetrical relaxed A-pose, arms angled away from the body, feet apart, props held clear of the body, flat even lighting, whole figure in frame with margin, isolated on a plain flat light-gray background, square 1:1.
```

#### FB_GuideArtisan — 전신 · 길드 안내자
- 용도: 교차로 장인 길드 앞 안내자 NPC 외형
- 크기: Firefly 1:1 → 참고용 또는 Tripo 흰 1380² 캔버스 · 불투명 · 시점: launch · 3D: True
- 검사·거절: Generate with approved PTR_GuideArtisan as reference. Silhouette must differ from merchant C (tall + wrench vs stocky + hammer + mug). Reject: floating cog fused to head, text.
```text
Quiet craftswoman guide NPC of an artisan guild, female, tall, short dark bob hair, calm half-lidded eyes, work goggles on the forehead. Modest fully covered outfit with only face and hands visible: long-sleeve brown shirt with high collar, long teal work coat to the knees, tool-roll belt with brass buckles, full-length canvas trousers, boots, work gloves. Holds a big brass wrench resting on her shoulder. Teal, brass and warm brown palette, boxy practical shapes. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body front view, symmetrical relaxed A-pose, arms angled away from the body, feet apart, props held clear of the body, flat even lighting, whole figure in frame with margin, isolated on a plain flat light-gray background, square 1:1.
```

#### PTR_SkillTeacher — 대화 초상 · 스킬 선생님
- 용도: 교차로 스킬 선생님(Z 스킬 Lv5·100골드) 배우기 창 초상. 진영 중립, 금·빨강 반반 목도리 = 균형
- 크기: Firefly 1:1 → 누끼 → 512x512 · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject: long wizard beard covering the face, pointed wizard hat (reads as mage class), lettering on book or cap, text.
```text
Head-and-shoulders portrait of a kindly old skill teacher, male, white tufted hair and bushy white eyebrows, big round spectacles, warm encouraging smile, square academic cap with a gold tassel, deep indigo high-collar robe with tiny silver star dots, scarf half gold and half crimson. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Slight three-quarter turn toward the viewer, face filling the upper half, square 1:1, isolated on a plain flat light-gray background.
```

#### FB_SkillTeacher — 전신 · 스킬 선생님
- 용도: 임시 기본 NPC 교체용 최종 외형(학사모 + 큰 책 실루엣)
- 크기: Firefly 1:1 → 참고용 또는 Tripo 흰 1380² 캔버스 · 불투명 · 시점: launch · 3D: True
- 검사·거절: Reject: readable writing on book pages (use plain colored blocks), stick that looks like a weapon, text.
```text
Kindly old skill teacher NPC, male, white tufted hair, big round spectacles, warm smile, square academic cap with a gold tassel. Modest fully covered outfit with only face and hands visible: ankle-length deep indigo robe with high collar and long sleeves, tiny silver star dots, scarf half gold and half crimson, boots, gloves. Holds a big open book under one arm and a wooden pointer stick in the other hand. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body front view, symmetrical relaxed A-pose, arms angled away from the body, feet apart, props held clear of the body, flat even lighting, whole figure in frame with margin, isolated on a plain flat light-gray background, square 1:1.
```

#### PTR_MerchantC — 대화 초상 · 장비 상인 C(지친 베테랑 대장장이)
- 용도: 대장간 구매·판매 창 초상과 상황별 반응('흠…'). 옛 치비 승인 원화를 로블록스 스타일로 다시 그림
- 크기: Firefly 1:1 → 누끼 → 512x512 · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject: grumpy or angry face, scars, red bandana (red is reserved for Horns), coffee-cup branding, text on mug.
```text
Head-and-shoulders portrait of a tired veteran blacksmith merchant, male, middle-aged, bushy gray-streaked mustache and thick eyebrows, sleepy half-lidded eyes, small easygoing smile, rust-orange bandana on the head, a smudge of soot on one cheek, dark-brown high-collar long-sleeve shirt under thick leather apron straps, small teal gear pin on the apron strap, holding a steaming mug of cocoa near his chin. Warm brown, iron and soot palette, sturdy square shapes. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Slight three-quarter turn toward the viewer, face filling the upper half, square 1:1, isolated on a plain flat light-gray background.
```

#### FB_MerchantC — 전신 · 장비 상인 C
- 용도: 교차로 대장간 모루 옆 NPC 최종 외형(큰 망치 + 코코아 머그)
- 크기: Firefly 1:1 → 참고용 또는 Tripo 흰 1380² 캔버스 · 불투명 · 시점: launch · 3D: True
- 검사·거절: Generate with approved PTR_MerchantC as reference. Reject: rolled sleeves, bare forearms, red colors, text.
```text
Tired veteran blacksmith merchant NPC, male, stocky, middle-aged, bushy gray-streaked mustache, sleepy half-lidded eyes, rust-orange bandana. Modest fully covered outfit with only face and hands visible: dark-brown high-collar long-sleeve shirt, heavy leather apron from chest to knees with a small teal gear pin, full-length canvas trousers, steel-capped boots, thick work gloves. Rests a big smithing hammer on one shoulder and holds a steaming mug of cocoa in the other hand. Warm brown, iron and soot palette, sturdy square shapes. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body front view, symmetrical relaxed A-pose, arms angled away from the body, feet apart, props held clear of the body, flat even lighting, whole figure in frame with margin, isolated on a plain flat light-gray background, square 1:1.
```

#### PTR_PotionMerchant — 대화 초상 · 물약 상인
- 용도: 물약 상점(25골드) 창 초상. 지금 NPC 색(초록 몸·갈색 다리)을 그대로 이어받음
- 크기: Firefly 1:1 → 누끼 → 512x512 · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject: labels on bottles, bubbling green toxic look, mad-scientist face, text.
```text
Head-and-shoulders portrait of a cheerful potion merchant, male, young adult, curly ginger hair, painted freckles, round glasses, big friendly smile, forest-green high-collar long coat, leather backpack straps with round glass bottles of red and blue potion peeking over the shoulders. Forest green, warm brown and bright potion colors, round friendly shapes. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Slight three-quarter turn toward the viewer, face filling the upper half, square 1:1, isolated on a plain flat light-gray background.
```

#### FB_PotionMerchant — 전신 · 물약 상인
- 용도: 교차로 스폰 옆 물약 상인 최종 외형(병 가득 든 배낭 실루엣)
- 크기: Firefly 1:1 → 참고용 또는 Tripo 흰 1380² 캔버스 · 불투명 · 시점: launch · 3D: True
- 검사·거절: Generate with approved PTR_PotionMerchant as reference. Backpack must stay readable from the front (bottles above shoulders). Reject: labels, text.
```text
Cheerful potion merchant NPC, male, curly ginger hair, painted freckles, round glasses, big smile. Modest fully covered outfit with only face and hands visible: forest-green long coat with high collar and long sleeves, brown belt with small pouches, full-length brown trousers, boots, gloves. Wears a large wooden-frame backpack rack filled with round glass bottles of red and blue potion, holds one red potion bottle up in one hand. Forest green, warm brown and bright potion colors, round friendly shapes. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body front view, symmetrical relaxed A-pose, arms angled away from the body, feet apart, props held clear of the body, flat even lighting, whole figure in frame with margin, isolated on a plain flat light-gray background, square 1:1.
```

#### PTR_NestKeeper — 대화 초상 · 알 둥지지기
- 용도: 정식 골드 랜덤 알 둥지(확률 표시) 창 초상
- 크기: Firefly 1:1 → 누끼 → 512x512 · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject: chick cropped off by hat edge, gambling/casino vibe, text.
```text
Head-and-shoulders portrait of a gentle pet-egg nest keeper, female, warm smile, rosy cheeks, brown braid, wide straw hat with a small twig nest on the brim where a fluffy yellow chick sits, mustard-yellow high-collar long-sleeve shirt under denim-blue overall straps. Warm yellow, denim blue and straw palette, round friendly shapes. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Slight three-quarter turn toward the viewer, face filling the upper half, square 1:1, isolated on a plain flat light-gray background.
```

#### FB_NestKeeper — 전신 · 알 둥지지기
- 용도: 교차로 알 둥지 NPC 최종 외형(둥지 모자 + 알 바구니). 알 3색 = 말랑·숲·유적 알
- 크기: Firefly 1:1 → 참고용 또는 Tripo 흰 1380² 캔버스 · 불투명 · 시점: launch · 3D: True
- 검사·거절: Generate with approved PTR_NestKeeper as reference. Reject: basket fused to body, text.
```text
Gentle pet-egg nest keeper NPC, female, brown braid, rosy cheeks, warm smile, wide straw hat with a small twig nest on the brim and a fluffy yellow chick in it. Modest fully covered outfit with only face and hands visible: mustard-yellow long-sleeve shirt with high collar, denim-blue overalls with full-length legs, rubber boots, garden gloves. Carries a woven basket holding three large speckled eggs in mint green, mossy brown and stone gray. Warm yellow, denim blue and straw palette, round friendly shapes. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body front view, symmetrical relaxed A-pose, arms angled away from the body, feet apart, props held clear of the body, flat even lighting, whole figure in frame with margin, isolated on a plain flat light-gray background, square 1:1.
```

#### CON_SlimeRound — 몬스터 다시 디자인 · 동글동글 슬라임
- 용도: 사용자 메모 '슬라임이 옆에서 보면 납작함' 해결용 새 슬라임(폭=두께). 호박 슬라임과 같은 Tripo 묶음으로 만들면 절약. 왕 슬라임은 같은 모델 파란색
- 크기: Firefly 1:1 → Tripo 흰 1380² 캔버스(+옆모습 1장 멀티뷰 권장) · 불투명 · 시점: launch · 3D: True
- 검사·거절: Reject: flat pancake shape, drippy melting slime, gooey strands, text. Match Config Slime color 95,205,95 family.
```text
Cute crown-shard slime monster for a kids game: plump round dome body as deep front-to-back as it is wide, glossy semi-translucent mint-green jelly, a tiny golden crystal sparkle floating inside, big round shiny eyes, small happy smile, rosy cheeks, soft highlights. Chunky stylized toy-figure monster, simple rounded shapes, smooth glossy vinyl material, bright cheerful colors, soft even studio lighting, crisp silhouette, cute and friendly. Front view, symmetrical, whole body in frame with margin, isolated on a plain flat light-gray background, square 1:1.
```

#### CON_SkeletonKing — 보스 · 해골왕
- 용도: 정식 해골왕 보스(해골 유적 최종). 왕관에 빈 홈 = 조각을 잃은 왕(이야기 연결). 겁주지 않는 '근엄하고 우스운' 왕
- 크기: Firefly 1:1 → Tripo 흰 1380² 캔버스 · 불투명 · 시점: launch · 3D: True
- 검사·거절: Reject: realistic skull, cracked bones, gore, dark red, hollow black sockets, menacing pose, thin finger bones (Tripo loses them). Check against existing SkeletonKing.glb only for scale.
```text
Cartoon skeleton king boss for a kids game: chunky rounded bones like smooth toy pieces, round skull with big round eye sockets glowing soft purple, stern but goofy expression, long royal purple robe with high collar and long sleeves covering the body, golden trim, cracked golden crown with one empty gem slot, holding a golden scepter topped with a soft purple flame. Chunky stylized toy-figure monster, simple rounded shapes, smooth matte vinyl material, soft even studio lighting, crisp silhouette, regal and goofy, kid-friendly. Front view, relaxed A-pose, arms angled away from the body, feet apart, props held clear of the body, whole body in frame with margin, isolated on a plain flat light-gray background, square 1:1.
```

#### BAN_Halo — 진영 깃발 · 빛의 성채
- 용도: 빛의 성채 영웅의 길·관문 깃발 천 데칼(ART_DIRECTION 깃발 0.2x8x4)
- 크기: Firefly 9:16 → 누끼 → 576x1024 데칼 · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject: letters, heraldic mottos, cross symbols, pole drawn into the image, perspective tilt.
```text
Vertical hanging cloth banner for a fantasy town, sky-blue fabric with a thick gold border, large golden halo-ring and sunburst emblem in the center, rounded scalloped bottom edge with small gold tassels, loops along the top hem, soft fabric folds, flat front view, stylized painted game texture, bright clean colors, wordless plain surfaces, isolated on a plain flat light-gray background, vertical 9:16.
```

#### BAN_Horns — 진영 깃발 · 뿔 소굴
- 용도: 뿔 소굴 기둥·관문 깃발 데칼(아래가 찢긴 모양)
- 크기: Firefly 9:16 → 누끼 → 576x1024 데칼 · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject: skulls, pentagrams, demonic faces, letters, burned holes that look violent.
```text
Vertical hanging cloth banner for a cartoon villain fortress, deep crimson fabric with a charcoal border, large emblem of two curved horns with an ember-orange glow, bottom edge cut into three pointed tatters with rounded tips, loops along the top hem, soft fabric folds, flat front view, stylized painted game texture, playful cartoon mischief, wordless plain surfaces, isolated on a plain flat light-gray background, vertical 9:16.
```

#### BAN_Artisan — 진영 깃발 · 장인 길드
- 용도: 교차로 장인 길드 건물·대장간 깃발 데칼
- 크기: Firefly 9:16 → 누끼 → 576x1024 데칼 · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject: gray-dominant fabric, letters, tool brand marks.
```text
Vertical hanging cloth banner for a craftsmen guild hall, teal canvas fabric with a brass rivet border, large brass-and-teal gear emblem in the center, straight bottom edge weighted by a brass bar, loops along the top hem, soft fabric folds, flat front view, stylized painted game texture, warm practical colors, wordless plain surfaces, isolated on a plain flat light-gray background, vertical 9:16.
```

#### BAN_Crossroads — 교차로 깃발 · 부서진 균형의 왕관
- 용도: 교차로 분수 광장 깃발. 전쟁 결과에 따라 이긴 편 색으로 빛나게(코드 틴트)
- 크기: Firefly 9:16 → 누끼 → 576x1024 데칼 · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject: real-world royal crests, letters, gray fabric.
```text
Vertical hanging cloth banner for a neutral crossroads town, cream fabric with a border split into gold on one side and crimson on the other, central emblem of a broken golden crown split into a gold half and a crimson half with one small glowing shard floating between them, scalloped bottom edge, loops along the top hem, soft fabric folds, flat front view, stylized painted game texture, wordless plain surfaces, isolated on a plain flat light-gray background, vertical 9:16.
```

#### UI_WantedPoster — 현상수배 포스터 빈 틀
- 용도: 게시판에 진짜 로블록스 아바타 얼굴(GetUserThumbnailAsync)을 끼우는 빈 포스터. 이름·별·현상금은 게임 글자
- 크기: Firefly 3:4 → 누끼 + 가운데 창 투명 처리(PIL) → 768x1024 · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject: any letters or 'WANTED'-like headline, bullet holes, blood, real currency symbols; the window must stay a clean flat area so it can be cut out.
```text
Blank fantasy wanted-poster frame for a kids game: aged parchment sheet with slightly torn edges, pinned at the corners with four round crimson pins, a large empty plain cream rectangle in the upper middle for a picture, small crimson horn ornaments in the top corners, a row of five empty star outlines along the bottom, flat front view, stylized painted game UI art, wordless plain surfaces, isolated on a plain flat light-gray background, vertical 3:4.
```

#### CRW_MarketVendor — 마을 주민 · 교차로 장터 상인
- 용도: 교차로 장터 4곳을 채우는 분위기 NPC(판매 기능 없음, 한 줄 말). R15 조립 참고
- 크기: Firefly 1:1 → 참고용(R15 조립) · 불투명 · 시점: later · 3D: True
- 검사·거절: Reject: faction colors (crowd must stay neutral), price tags or letters, text.
```text
Cheerful town market vendor NPC, female, rosy cheeks, patterned headscarf, big smile. Modest fully covered outfit with only face and hands visible: long-sleeve striped shirt with high collar, long apron, ankle-length skirt over full-length leggings, boots. Holds a wooden tray of round bread buns. Warm cream, terracotta and leaf-green palette, round friendly shapes. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body front view, symmetrical relaxed A-pose, arms angled away from the body, feet apart, props held clear of the body, whole figure in frame with margin, isolated on a plain flat light-gray background, square 1:1.
```

#### CRW_HaloPatrol — 마을 주민 · 빛의 성채 순찰 기사
- 용도: 빛의 성채 영웅의 길 순찰(클라이언트 전용). 빛 승리 때 환호 동작
- 크기: Firefly 1:1 → 참고용(R15 조립) · 불투명 · 시점: later · 3D: True
- 검사·거절: Reject: closed visor hiding face, sharp spear point, text.
```text
Halo town patrol knight NPC, male, round white helmet with a small gold crest and an open face, friendly smile. Modest fully covered outfit with only face and hands visible: white-and-gold padded armor with long sleeves, sky-blue short cape, full-length white trousers, boots, gloves. Holds a long ceremonial spear with a rounded gold tip and a small round shield. White, gold and sky-blue palette, round friendly shapes. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body front view, symmetrical relaxed A-pose, arms angled away from the body, feet apart, props held clear of the body, whole figure in frame with margin, isolated on a plain flat light-gray background, square 1:1.
```

#### CRW_HornsLookout — 마을 주민 · 뿔 소굴 망보기
- 용도: 뿔 소굴 감시탑·화로 옆 분위기 NPC. 뿔 승리 때 춤 동작
- 크기: Firefly 1:1 → 참고용(R15 조립) · 불투명 · 시점: later · 3D: True
- 검사·거절: Reject: weapons, menacing glare, fangs, text.
```text
Horns den lookout NPC from a cartoon villain army, stocky, crimson hood with two short chunky horns poking through, cheeky grin. Modest fully covered outfit with only face and hands visible: charcoal padded long-sleeve coat with crimson trim, full-length dark trousers, boots, gloves. Holds a big brass spyglass and a small lantern with an ember-orange glow. Charcoal, crimson and ember-orange palette, triangle shapes with rounded tips, playful cartoon mischief. 3D-rendered blocky toy-avatar character, building-block game figure, squarish head with softly rounded corners, simple painted cartoon face, rectangular torso and block-shaped limbs shared by every character, smooth matte plastic, soft even studio lighting, crisp clean silhouette, wordless plain surfaces, kid-friendly. Full-body front view, symmetrical relaxed A-pose, arms angled away from the body, feet apart, props held clear of the body, whole figure in frame with margin, isolated on a plain flat light-gray background, square 1:1.
```

### 2-5. 더 많이(성장 표식·배지·아이템·지도·시즌)

#### Item_Jelly — 슬라임 젤리 (재료)
- 용도: Loot item Jelly: drop toast, menu > 아이템 list, blacksmith material sale (A23-12)
- 크기: Firefly 1:1 -> cutout -> 512x512 (shown 56-80 px) · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject letters/numbers, a face on the jelly (it is a material, not a monster), puddles or extra blobs, and a halo of white fringe left inside the translucent edge after cutout. First approved item becomes the Style Reference for all Item_* icons.
```text
A wobbly cube of translucent lime-green slime jelly with a big glossy shine spot and one small drip. Chunky glossy 3D cartoon game icon, toy-like proportions, smooth plastic and painted materials, soft light from the top left, thick dark plum outline, bold simple silhouette, bright kid-friendly colors, one object centered in three-quarter view filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Item_SlimeCore — 왕 슬라임 핵 (재료)
- 용도: Loot item SlimeCore (king slime drop)
- 크기: 1:1 -> 512x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject glow haze outside the outline, and a core that is green (must read differently from Jelly at 32 px). Use Item_Jelly as Style Reference.
```text
A glowing sky-blue round core gem inside a clear jelly shell, the light painted inside the outline. Chunky glossy 3D cartoon game icon, toy-like proportions, smooth plastic and painted materials, soft light from the top left, thick dark plum outline, bold simple silhouette, bright kid-friendly colors, one object centered in three-quarter view filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Item_GoblinTooth — 고블린 이빨 (재료)
- 용도: Loot item GoblinTooth
- 크기: 1:1 -> 512x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject blood, gums, a jaw, rot or realistic dental detail. Dark background on purpose (cream subject). Check the cutout on white so no navy rim remains.
```text
One big smooth cream-colored cartoon fang tooth, clean and shiny, with a tiny leather cord tied around its root. Chunky glossy 3D cartoon game icon, toy-like proportions, smooth plastic and painted materials, soft light from the top left, thick dark plum outline, bold simple silhouette, bright kid-friendly colors, one object centered in three-quarter view filling 80% of a square, isolated on a plain solid dark navy background, no shadow, no text, no letters, no numbers.
```

#### Item_BruteHorn — 우두머리 뿔 (재료)
- 용도: Loot item BruteHorn
- 크기: 1:1 -> 512x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Must be brown and natural. Reject crimson or glowing horns, which would read as the Horns faction mark. No blood at the broken end.
```text
One chunky curved brown horn piece with a chipped tip and a leather strap wrapped near its base. Chunky glossy 3D cartoon game icon, toy-like proportions, smooth plastic and painted materials, soft light from the top left, thick dark plum outline, bold simple silhouette, bright kid-friendly colors, one object centered in three-quarter view filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Item_Bone — 낡은 뼛조각 (재료)
- 용도: Loot item Bone (skeleton drop)
- 크기: 1:1 -> 512x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject a skull, a skeleton, realistic anatomy, dirt or stains that look like blood. Keep it a single classic cartoon bone.
```text
One old pale ivory cartoon bone with rounded knobby ends and one small crack, clean and cute. Chunky glossy 3D cartoon game icon, toy-like proportions, smooth plastic and painted materials, soft light from the top left, thick dark plum outline, bold simple silhouette, bright kid-friendly colors, one object centered in three-quarter view filling 80% of a square, isolated on a plain solid dark navy background, no shadow, no text, no letters, no numbers.
```

#### Item_KnightCrest — 녹슨 기사 문장 (재료)
- 용도: Loot item KnightCrest (skeleton knight drop, rarest material)
- 크기: 1:1 -> 512x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject any heraldic letters, numbers or skull motifs on the shield. Must not look like a faction or rank badge: use rust and wear, no gold, no halo, no horns.
```text
A rusty steel knight crest badge, a gray-violet metal shield shape with orange rust spots and a faded purple ribbon. Chunky glossy 3D cartoon game icon, toy-like proportions, smooth plastic and painted materials, soft light from the top left, thick dark plum outline, bold simple silhouette, bright kid-friendly colors, one object centered in three-quarter view filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Item_Candy — 핼러윈 사탕 (재료)
- 용도: Halloween monster drop material, sold for gold (design doc section 4); returns each year
- 크기: 1:1 -> 512x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject piles of candy, brand-like wrapper prints, and faces or spooky symbols on the wrapper.
```text
One wrapped candy with a twisted orange-and-purple striped wrapper and a shiny round sweet in the middle. Chunky glossy 3D cartoon game icon, toy-like proportions, smooth plastic and painted materials, soft light from the top left, thick dark plum outline, bold simple silhouette, bright kid-friendly colors, one object centered in three-quarter view filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Item_Enh70 — 강화 주문서 70%
- 용도: Enhance scroll Enh70; the 70% label is a live TextLabel badge
- 크기: 1:1 -> 512x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject writing or runes that look like letters on the paper, and '%' or numbers anywhere. This is the base design for all 3 enhance scrolls; the other two differ only in ribbon/seal color and gem.
```text
A rolled parchment scroll tied with a light blue ribbon and a light blue wax seal stamped with an upward arrow over a small sword. Chunky glossy 3D cartoon game icon, toy-like proportions, smooth plastic and painted materials, soft light from the top left, thick dark plum outline, bold simple silhouette, bright kid-friendly colors, one object centered in three-quarter view filling 80% of a square, isolated on a plain solid dark navy background, no shadow, no text, no letters, no numbers.
```

#### Item_Enh30 — 강화 주문서 30%
- 용도: Enhance scroll Enh30
- 크기: 1:1 -> 512x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Use Item_Enh70 as Style Reference (strength about 70). Same scroll shape and angle; only color and gem change.
```text
A rolled parchment scroll tied with a purple ribbon and a purple wax seal stamped with an upward arrow over a small sword, one small purple gem set in the seal. Chunky glossy 3D cartoon game icon, toy-like proportions, smooth plastic and painted materials, soft light from the top left, thick dark plum outline, bold simple silhouette, bright kid-friendly colors, one object centered in three-quarter view filling 80% of a square, isolated on a plain solid dark navy background, no shadow, no text, no letters, no numbers.
```

#### Item_Enh10 — 강화 주문서 10%
- 용도: Enhance scroll Enh10 (rarest, biggest gain)
- 크기: 1:1 -> 512x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Sparkles must stay inside the outline (no floating specks after cutout). Style Reference: Item_Enh70.
```text
A rolled parchment scroll tied with a golden ribbon and a shining gold wax seal stamped with an upward arrow over a small sword, a gold gem in the seal and tiny sparkles painted inside the outline. Chunky glossy 3D cartoon game icon, toy-like proportions, smooth plastic and painted materials, soft light from the top left, thick dark plum outline, bold simple silhouette, bright kid-friendly colors, one object centered in three-quarter view filling 80% of a square, isolated on a plain solid dark navy background, no shadow, no text, no letters, no numbers.
```

#### Item_Move70 — 강화 옮기기 주문서 70%
- 용도: Transfer scroll Move70
- 크기: 1:1 -> 512x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: The seal symbol must clearly differ from the enhance upward arrow at 48 px. Style Reference: Item_Enh70.
```text
A rolled parchment scroll tied with a mint-green ribbon and a mint-green wax seal stamped with two curved arrows circling between two small swords. Chunky glossy 3D cartoon game icon, toy-like proportions, smooth plastic and painted materials, soft light from the top left, thick dark plum outline, bold simple silhouette, bright kid-friendly colors, one object centered in three-quarter view filling 80% of a square, isolated on a plain solid dark navy background, no shadow, no text, no letters, no numbers.
```

#### Item_Move30 — 강화 옮기기 주문서 30%
- 용도: Transfer scroll Move30
- 크기: 1:1 -> 512x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Lilac must stay distinguishable from Enh30 purple. If it is too close, push toward pink-lilac. Style Reference: Item_Move70.
```text
A rolled parchment scroll tied with a lilac ribbon and a lilac wax seal stamped with two curved arrows circling between two small swords, one small lilac gem set in the seal. Chunky glossy 3D cartoon game icon, toy-like proportions, smooth plastic and painted materials, soft light from the top left, thick dark plum outline, bold simple silhouette, bright kid-friendly colors, one object centered in three-quarter view filling 80% of a square, isolated on a plain solid dark navy background, no shadow, no text, no letters, no numbers.
```

#### Item_Move10 — 강화 옮기기 주문서 10%
- 용도: Transfer scroll Move10
- 크기: 1:1 -> 512x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Style Reference: Item_Move70. Sparkles inside the outline only.
```text
A rolled parchment scroll tied with a yellow-gold ribbon and a shining yellow-gold wax seal stamped with two curved arrows circling between two small swords, a gold gem in the seal and tiny sparkles painted inside the outline. Chunky glossy 3D cartoon game icon, toy-like proportions, smooth plastic and painted materials, soft light from the top left, thick dark plum outline, bold simple silhouette, bright kid-friendly colors, one object centered in three-quarter view filling 80% of a square, isolated on a plain solid dark navy background, no shadow, no text, no letters, no numbers.
```

#### Item_PotionHP — 체력 물약
- 용도: HP potion: HUD potion slot, potion shop, drops (replaces the old active IconPotionHP)
- 크기: 1:1 -> 512x512 (old part was 197x256) · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject labels with writing, crosses (medical symbol), skulls, and dark-red liquid that reads as blood. If the HUD redraw session already made potions, use theirs instead (avoid a duplicate).
```text
A round glass potion bottle with a cork stopper, filled with bright red liquid, a small heart-shaped bubble inside and a shine highlight. Chunky glossy 3D cartoon game icon, toy-like proportions, smooth plastic and painted materials, soft light from the top left, thick dark plum outline, bold simple silhouette, bright kid-friendly colors, one object centered in three-quarter view filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Item_PotionMP — 마나 물약
- 용도: MP potion: HUD slot, shop, drops (replaces the old active IconPotionMP)
- 크기: 1:1 -> 512x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Same bottle shape as Item_PotionHP (use it as Style Reference). Reject labels with writing.
```text
A round glass potion bottle with a cork stopper, filled with bright blue liquid, a small star-shaped bubble inside and a shine highlight. Chunky glossy 3D cartoon game icon, toy-like proportions, smooth plastic and painted materials, soft light from the top left, thick dark plum outline, bold simple silhouette, bright kid-friendly colors, one object centered in three-quarter view filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Shard_Base — 왕관 조각 (기본)
- 용도: Story/quest item: S0 '내 싸움을 배우는 왕관 조각' dialog and reward toast, intro/next-goal line, map crown marker
- 크기: 1:1 -> 512x512 · 투명 · 시점: beta · 3D: True
- 검사·거절: Reject multiple shards, a whole crown, and glow haze outside the outline. This is the master shard; the three variants use it as Style Reference so the silhouette stays identical.
```text
One jagged faceted golden-amber crystal shard broken from a crown, a sliver of gold crown band still attached at its base, warm light glowing inside, one zig-zag crack. Chunky glossy 3D cartoon game icon, toy-like proportions, smooth plastic and painted materials, soft light from the top left, thick dark plum outline, bold simple silhouette, bright kid-friendly colors, one object centered in three-quarter view filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Shard_Purified — 정화된 왕관 조각
- 용도: S0 choice A result (정화, Halo-leaning) and later Halo crafting material
- 크기: 1:1 -> 512x512 · 투명 · 시점: launch · 3D: True
- 검사·거절: Same shard silhouette as Shard_Base. Keep the halo ring attached visually, not a separate floating speck that the cutout drops.
```text
One faceted crown shard crystal glowing pure white and gold, a tiny gold halo ring floating just above it, soft sparkles painted inside the outline. Chunky glossy 3D cartoon game icon, toy-like proportions, smooth plastic and painted materials, soft light from the top left, thick dark plum outline, bold simple silhouette, bright kid-friendly colors, one object centered in three-quarter view filling 80% of a square, isolated on a plain solid dark navy background, no shadow, no text, no letters, no numbers.
```

#### Shard_Swallowed — 삼킨 왕관 조각
- 용도: S0 choice B result (삼켜요, Horns-leaning) and later Horns crafting material
- 크기: 1:1 -> 512x512 · 투명 · 시점: launch · 3D: True
- 검사·거절: Reject dripping liquid, a face, eyes or anything that looks like blood. Same silhouette as Shard_Base.
```text
One faceted crown shard crystal turned deep crimson and plum with glowing ember-orange cracks and two tiny horn-like spikes on top, mischievous, not scary. Chunky glossy 3D cartoon game icon, toy-like proportions, smooth plastic and painted materials, soft light from the top left, thick dark plum outline, bold simple silhouette, bright kid-friendly colors, one object centered in three-quarter view filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Shard_Refined — 다듬은 왕관 조각 (장인)
- 용도: Artisan Guild path ('조각을 줍지 않고 다듬는다'): Neutral S0 result, later crafting input
- 크기: 1:1 -> 512x512 · 투명 · 시점: launch · 3D: True
- 검사·거절: Must still read as 'the same shard, shaped': similar proportions to Shard_Base. Reject a plain round gem.
```text
One crown shard cut into a neat polished teal-and-gold gem, set in a small brass gear-shaped mount. Chunky glossy 3D cartoon game icon, toy-like proportions, smooth plastic and painted materials, soft light from the top left, thick dark plum outline, bold simple silhouette, bright kid-friendly colors, one object centered in three-quarter view filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Skill_Warrior_Q — 전사 Q 스킬 (충격파)
- 용도: Q button icon for Warrior (current basic skill: self-centered shockwave). Replaces the shared winged-star IconSpecial so Q and Z differ.
- 크기: 1:1 -> 512x512 (inside round BtnSpecial, about 100-136 px) · 투명 · 시점: beta · 3D: False
- 검사·거절: First skill icon = Style Reference for all 9 skills. Reject a hand or character holding the sword, flying debris specks that break the cutout, and a circular frame baked in (the button provides it).
```text
A sword stuck point-down in cracked ground releasing one round golden-orange shockwave ring. Chunky glossy 3D cartoon skill icon, glow painted inside a thick dark plum outline with no haze outside it, soft light from the top left, simple readable silhouette, centered filling 75% of a square to fit a round button, isolated on a plain solid dark navy background, no character, no hands, no text, no letters, no numbers.
```

#### Skill_Mage_Q — 마법사 Q 스킬 (메테오)
- 용도: Q button icon for Mage (meteor on nearest target)
- 크기: 1:1 -> 512x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject a planet, a realistic fireball with smoke haze, or a burning town. Style Reference: Skill_Warrior_Q.
```text
A round cartoon meteor with a glowing violet and orange trail falling diagonally. Chunky glossy 3D cartoon skill icon, glow painted inside a thick dark plum outline with no haze outside it, soft light from the top left, simple readable silhouette, centered filling 75% of a square to fit a round button, isolated on a plain solid dark navy background, no character, no hands, no text, no letters, no numbers.
```

#### Skill_Archer_Q — 궁수 Q 스킬 (화살비)
- 용도: Q button icon for Archer (arrow rain on target)
- 크기: 1:1 -> 512x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Count must be about three; reject a dense cloud of thin arrows that turns to noise at 100 px. Style Reference: Skill_Warrior_Q.
```text
Three arrows falling downward in a fan with bright green light trails. Chunky glossy 3D cartoon skill icon, glow painted inside a thick dark plum outline with no haze outside it, soft light from the top left, simple readable silhouette, centered filling 75% of a square to fit a round button, isolated on a plain solid dark navy background, no character, no hands, no text, no letters, no numbers.
```

#### Skill_Warrior_Z — 전사 Z 스킬 (대지 가르기)
- 용도: Z button icon, Warrior '대지 가르기' (22x10 forward band, pulls monsters; design doc section 3)
- 크기: 1:1 -> 512x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Must read differently from Skill_Warrior_Q at button size: line vs ring. Style Reference: Skill_Warrior_Q.
```text
A broad sword slash carving one glowing orange-gold straight line along the ground, with small rocks popping up beside it. Chunky glossy 3D cartoon skill icon, glow painted inside a thick dark plum outline with no haze outside it, soft light from the top left, simple readable silhouette, centered filling 75% of a square to fit a round button, isolated on a plain solid dark navy background, no character, no hands, no text, no letters, no numbers.
```

#### Skill_Mage_Z — 마법사 Z 스킬 (마력 사슬)
- 용도: Z button icon, Mage '마력 사슬' (chain lightning bouncing 3-4 times)
- 크기: 1:1 -> 512x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject metal chains, which read as a prison/torture motif. It must be lightning linking orbs. Style Reference: Skill_Warrior_Q.
```text
A zig-zag chain of violet-blue lightning linking three small glowing orbs. Chunky glossy 3D cartoon skill icon, glow painted inside a thick dark plum outline with no haze outside it, soft light from the top left, simple readable silhouette, centered filling 75% of a square to fit a round button, isolated on a plain solid dark navy background, no character, no hands, no text, no letters, no numbers.
```

#### Skill_Archer_Z — 궁수 Z 스킬 (꿰뚫는 화살)
- 용도: Z button icon, Archer '꿰뚫는 화살' (straight piercing line)
- 크기: 1:1 -> 512x512 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject anything pierced that is a creature or person. Style Reference: Skill_Warrior_Q.
```text
One long arrow piercing straight through two glowing rings, leaving a bright green streak behind it. Chunky glossy 3D cartoon skill icon, glow painted inside a thick dark plum outline with no haze outside it, soft light from the top left, simple readable silhouette, centered filling 75% of a square to fit a round button, isolated on a plain solid dark navy background, no character, no hands, no text, no letters, no numbers.
```

#### Skill_Warrior_X — 전사 X 스킬 (수호 함성)
- 용도: X button icon, Warrior '수호 함성' (launch skill)
- 크기: 1:1 -> 512x512 · 투명 · 시점: launch · 3D: False
- 검사·거절: Keep the shield plain (no halo or horn emblem); the faction shows on the button frame. Style Reference: Skill_Warrior_Q.
```text
A round shield with soft golden sound-wave arcs radiating outward. Chunky glossy 3D cartoon skill icon, glow painted inside a thick dark plum outline with no haze outside it, soft light from the top left, simple readable silhouette, centered filling 75% of a square to fit a round button, isolated on a plain solid dark navy background, no character, no hands, no text, no letters, no numbers.
```

#### Skill_Mage_X — 마법사 X 스킬 (느림 마법진)
- 용도: X button icon, Mage '느림 마법진' (slow field, monsters only)
- 크기: 1:1 -> 512x512 · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject pentagrams or occult-looking star symbols in the circle (moderation risk). Use simple rings and dots. Style Reference: Skill_Warrior_Q.
```text
A glowing violet magic circle seen at an angle with a small cute snail shape in its center. Chunky glossy 3D cartoon skill icon, glow painted inside a thick dark plum outline with no haze outside it, soft light from the top left, simple readable silhouette, centered filling 75% of a square to fit a round button, isolated on a plain solid dark navy background, no character, no hands, no text, no letters, no numbers.
```

#### Skill_Archer_X — 궁수 X 스킬 (바람 걸음)
- 용도: X button icon, Archer '바람 걸음' (speed buff)
- 크기: 1:1 -> 512x512 · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject a leg inside the boot and any logo-like swoosh. Style Reference: Skill_Warrior_Q.
```text
A small winged boot with swirling green wind lines. Chunky glossy 3D cartoon skill icon, glow painted inside a thick dark plum outline with no haze outside it, soft light from the top left, simple readable silhouette, centered filling 75% of a square to fit a round button, isolated on a plain solid dark navy background, no character, no hands, no text, no letters, no numbers.
```

#### Emo_Ouch — 감정 스티커: 아야! (말풍선)
- 용도: Replaces active EmoOuch. Blank burst bubble; '아야!/Ouch!' becomes a live TextLabel on top (Fx EMO_HURT/EMO_BIG).
- 크기: 1:1 -> 256x256 (overhead billboard about 60-90 px) · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject any lettering, including fake scribbles, inside the bubble. The empty center must be at least 55% of the width for the label. First approved sticker = Style Reference for all Emo_*.
```text
A blank white comic burst speech bubble with jagged edges and small red stress marks around it, the center left empty for text. Cute glossy cartoon sticker with a thick white die-cut border and a thin dark outline, bold simple shape, centered filling 80% of a square, isolated on a plain solid dark navy background, no text, no letters, no numbers.
```

#### Emo_Tears — 감정 스티커: 눈물
- 용도: Replaces active EmoTears (hit reaction)
- 크기: 1:1 -> 256x256 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject a crying face or eyes; just the drops. Style Reference: Emo_Ouch.
```text
Two big cartoon teardrops in bright blue with white shine spots. Cute glossy cartoon sticker with a thick white die-cut border and a thin dark outline, bold simple shape, centered filling 80% of a square, isolated on a plain solid dark navy background, no text, no letters, no numbers.
```

#### Emo_Dizzy — 감정 스티커: 어지러움
- 용도: Replaces active EmoDizzy (big-hit reaction)
- 크기: 1:1 -> 256x256 · 투명 · 시점: beta · 3D: False
- 검사·거절: Stars must not resemble the red wanted-star icon: keep them yellow and round-tipped. Style Reference: Emo_Ouch.
```text
A swirling ring of three yellow cartoon stars with curved motion lines. Cute glossy cartoon sticker with a thick white die-cut border and a thin dark outline, bold simple shape, centered filling 80% of a square, isolated on a plain solid dark navy background, no text, no letters, no numbers.
```

#### Emo_Angry — 감정 스티커: 화남
- 용도: Replaces active EmoAngry (hit reaction)
- 크기: 1:1 -> 256x256 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject a medical cross or a plus-sign look; it must be the classic popping-vein comic mark. Style Reference: Emo_Ouch.
```text
A red cartoon anger mark made of four bulging curved segments forming a cross shape. Cute glossy cartoon sticker with a thick white die-cut border and a thin dark outline, bold simple shape, centered filling 80% of a square, isolated on a plain solid dark navy background, no text, no letters, no numbers.
```

#### Emo_Stress — 감정 스티커: 당황
- 용도: Replaces active EmoStress (was '!!' text)
- 크기: 1:1 -> 256x256 · 투명 · 시점: beta · 3D: False
- 검사·거절: Reject exclamation marks drawn as glyphs if they look like typed text. Style Reference: Emo_Ouch.
```text
Three short red jagged burst lines fanning outward like a surprised shout. Cute glossy cartoon sticker with a thick white die-cut border and a thin dark outline, bold simple shape, centered filling 80% of a square, isolated on a plain solid dark navy background, no text, no letters, no numbers.
```

#### UI_MapParchment — 세계 지도 양피지 (빈 판)
- 용도: Replaces active UI_MapParchment behind WorldMap; zones, roads and names are drawn by code/TextLabels on top
- 크기: Firefly 16:9 -> 1024x576, opaque (no cutout) · 불투명 · 시점: beta · 3D: False
- 검사·거절: Reject visible land shapes, borders/frames, perspective or a desk behind it. Check that the center is even enough for 11 px labels; the top/bottom 8% may be cropped.
```text
Blank old parchment paper texture filling the entire canvas edge to edge, flat front view, warm cream center fading to honey tones, subtle paper fibers and faint watercolor stains, gently darkened brown edges, a large clean even center area. No drawings, no land, no compass, no table, no curled corners, no text, no letters, no numbers.
```

#### Map_Crossroads — 지도 아이콘: 교차로 마을
- 용도: World map town icon (replaces glyph); can double as the zone-entry banner icon
- 크기: 1:1 -> 256x256 (shown 28-40 px) · 투명 · 시점: launch · 3D: False
- 검사·거절: First approved map icon = Style Reference for all Map_*. Reject tiny houses or people that vanish at 32 px.
```text
A small round town plaza with a fountain under a floating broken golden crown. Chunky cartoon map marker icon, slight top-down front view, thick dark plum outline, soft simple shading, warm storybook colors that stand out on cream paper, one object centered filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Map_HaloCastle — 지도 아이콘: 빛의 성채
- 용도: World map faction town icon
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Dark background on purpose (white subject). Reject religious symbols such as crosses on the dome.
```text
A white-and-gold castle tower with a round dome and a floating golden halo ring above it. Chunky cartoon map marker icon, slight top-down front view, thick dark plum outline, soft simple shading, warm storybook colors that stand out on cream paper, one object centered filling 80% of a square, isolated on a plain solid dark navy background, no shadow, no text, no letters, no numbers.
```

#### Map_HornsDen — 지도 아이콘: 뿔 소굴
- 용도: World map faction town icon
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject skulls, demonic faces and flames bigger than the tower.
```text
A dark plum rocky fortress tower leaning slightly, with two curved crimson horns on top and glowing ember windows, cartoon villain style, not scary. Chunky cartoon map marker icon, slight top-down front view, thick dark plum outline, soft simple shading, warm storybook colors that stand out on cream paper, one object centered filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Map_ArtisanGuild — 지도 아이콘: 장인 길드
- 용도: World map guild icon (replaces '장' glyph)
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: The gear must be the dominant shape (it is the Artisan silhouette).
```text
A sturdy stone-and-wood workshop with a big teal-glowing brass gear on its roof. Chunky cartoon map marker icon, slight top-down front view, thick dark plum outline, soft simple shading, warm storybook colors that stand out on cream paper, one object centered filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Map_SlimeMeadow — 지도 아이콘: 말랑 초원
- 용도: World map hunting zone icon
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Keep the slime close to the in-game slime colors (rounder is fine).
```text
A cute round green slime with big friendly eyes sitting on a little grassy hill with flowers. Chunky cartoon map marker icon, slight top-down front view, thick dark plum outline, soft simple shading, warm storybook colors that stand out on cream paper, one object centered filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Map_GoblinWoods — 지도 아이콘: 고블린 숲
- 용도: World map PvP zone icon
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject goblin faces with blood or weapons with gore.
```text
Two dark green pine trees beside a small patched tent with crossed wooden spears. Chunky cartoon map marker icon, slight top-down front view, thick dark plum outline, soft simple shading, warm storybook colors that stand out on cream paper, one object centered filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Map_SkeletonRuins — 지도 아이콘: 해골 유적
- 용도: World map PvP-extreme zone icon
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject skulls, bones and graves despite the zone name. Pale stone needs the dark background.
```text
Broken pale stone pillars and a crumbling archway with a soft purple spirit flame, no skulls. Chunky cartoon map marker icon, slight top-down front view, thick dark plum outline, soft simple shading, warm storybook colors that stand out on cream paper, one object centered filling 80% of a square, isolated on a plain solid dark navy background, no shadow, no text, no letters, no numbers.
```

#### Map_Altar — 지도 아이콘: 운명의 제단
- 용도: World map service icon (replaces ◆)
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject candles, sacrificial imagery and religious symbols.
```text
A small stone altar whose top glows half warm gold and half crimson. Chunky cartoon map marker icon, slight top-down front view, thick dark plum outline, soft simple shading, warm storybook colors that stand out on cream paper, one object centered filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Map_Market — 지도 아이콘: 장터
- 용도: World map service icon (replaces '상')
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject signboards with writing.
```text
A small market stall with a striped awning and wooden crates. Chunky cartoon map marker icon, slight top-down front view, thick dark plum outline, soft simple shading, warm storybook colors that stand out on cream paper, one object centered filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Map_Blacksmith — 지도 아이콘: 대장간
- 용도: World map service icon for the weapon shop/enhance
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Sparks stay attached to the shape (no loose specks).
```text
An iron anvil with a hammer resting on it and bright orange sparks. Chunky cartoon map marker icon, slight top-down front view, thick dark plum outline, soft simple shading, warm storybook colors that stand out on cream paper, one object centered filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Map_PotionShop — 지도 아이콘: 물약 상인
- 용도: World map service icon
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Bottle shape should echo Item_PotionHP/MP once approved (use as Style Reference).
```text
Two potion bottles side by side, one red and one blue, with cork stoppers. Chunky cartoon map marker icon, slight top-down front view, thick dark plum outline, soft simple shading, warm storybook colors that stand out on cream paper, one object centered filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Map_SkillTeacher — 지도 아이콘: 스킬 선생님
- 용도: World map service icon for the Z-skill teacher NPC
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject visible writing or runes on the pages; keep them blank or with simple dots.
```text
An open glowing spell book with a small golden star rising from its pages. Chunky cartoon map marker icon, slight top-down front view, thick dark plum outline, soft simple shading, warm storybook colors that stand out on cream paper, one object centered filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Map_PetNest — 지도 아이콘: 펫 알 둥지
- 용도: World map service icon for the launch egg nest
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Must read differently from Map_Goose: no goose, no gold.
```text
A cozy straw nest holding two spotted eggs. Chunky cartoon map marker icon, slight top-down front view, thick dark plum outline, soft simple shading, warm storybook colors that stand out on cream paper, one object centered filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Map_TeleportPad — 지도 아이콘: 이동 발판
- 용도: World map pad icon (replaces ▣)
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Pad rim color is neutral (the code tints by danger color); avoid red or orange.
```text
A glowing round teleport pad with three upward light arrows. Chunky cartoon map marker icon, slight top-down front view, thick dark plum outline, soft simple shading, warm storybook colors that stand out on cream paper, one object centered filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Map_Goose — 지도 아이콘: 황금 거위
- 용도: Live world-map marker while the goose event is active (replaces ✪)
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Should resemble the in-game golden goose model (orange beak, gold body).
```text
A plump golden goose with a glowing crown shard crystal on its back. Chunky cartoon map marker icon, slight top-down front view, thick dark plum outline, soft simple shading, warm storybook colors that stand out on cream paper, one object centered filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Map_Kaiju — 지도 아이콘: 괴수
- 용도: Live world-map marker for the active kaiju (replaces '괴')
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject claws with blood and monster faces.
```text
A giant cartoon monster footprint with small orange flames around it, not scary. Chunky cartoon map marker icon, slight top-down front view, thick dark plum outline, soft simple shading, warm storybook colors that stand out on cream paper, one object centered filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Map_GrudgeSack — 지도 아이콘: 원한 돈자루
- 용도: Live marker shown only to Halo players for sack carriers (replaces ◈)
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject currency symbols (dollar signs) on the sack. The wisp must stay attached for a clean cutout.
```text
A purple money sack tied with rope, with a faint pale ghost wisp curling above it, cute not scary. Chunky cartoon map marker icon, slight top-down front view, thick dark plum outline, soft simple shading, warm storybook colors that stand out on cream paper, one object centered filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Map_PvP — 지도 아이콘: PvP 위험
- 용도: PvP zone marker on the map and optional zone-chip icon
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Orange, not red (danger ladder: PvP orange, extreme red is a code tint).
```text
Two crossed swords with a bright orange glow. Chunky cartoon map marker icon, slight top-down front view, thick dark plum outline, soft simple shading, warm storybook colors that stand out on cream paper, one object centered filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Map_Compass — 지도 나침반
- 용도: Decoration in a corner of the world map
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject N/E/S/W letters (they will be live TextLabels if needed).
```text
A cartoon compass rose with four big points and four small points in gold and brown ink, a tiny golden crown in the center. Chunky cartoon map marker icon, slight top-down front view, thick dark plum outline, soft simple shading, warm storybook colors that stand out on cream paper, one object centered filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Badge_HaloR1 — 칭호 배지: 견습 기사
- 용도: Halo rank 1 badge beside the nametag title and in the profile/HUD
- 크기: 1:1 -> 256x256 (shown 24-40 px) · 투명 · 시점: launch · 3D: False
- 검사·거절: Generate R5 first and get it approved, then use it as Style Reference for R1-R4 so all five share the same shield base. Reject crosses and religious symbols.
```text
A small round ivory-and-gold shield badge with a thin golden halo ring emblem in its center. Chunky glossy 3D cartoon rank badge, front view, symmetrical, thick dark plum outline, bold simple shapes that still read at 24 pixels, soft light from the top left, centered filling 80% of a square, isolated on a plain solid dark navy background, no shadow, no text, no letters, no numbers.
```

#### Badge_HaloR2 — 칭호 배지: 기사
- 용도: Halo rank 2 badge
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Must look one step richer than R1 at 24 px (the ribbon is the tell).
```text
A round ivory shield badge with a thick gold rim, a golden halo ring emblem and a small sky-blue ribbon below. Chunky glossy 3D cartoon rank badge, front view, symmetrical, thick dark plum outline, bold simple shapes that still read at 24 pixels, soft light from the top left, centered filling 80% of a square, isolated on a plain solid dark navy background, no shadow, no text, no letters, no numbers.
```

#### Badge_HaloR3 — 칭호 배지: 성기사
- 용도: Halo rank 3 badge
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Rays stay inside the outline.
```text
An ornate round ivory shield badge with a thick gold rim, a golden halo ring emblem with short light rays and a sky-blue ribbon below. Chunky glossy 3D cartoon rank badge, front view, symmetrical, thick dark plum outline, bold simple shapes that still read at 24 pixels, soft light from the top left, centered filling 80% of a square, isolated on a plain solid dark navy background, no shadow, no text, no letters, no numbers.
```

#### Badge_HaloR4 — 칭호 배지: 성자
- 용도: Halo rank 4 badge (first wings)
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Feathers should be chunky; reject thin individual feathers that blur at 24 px.
```text
An ornate round ivory-and-gold shield badge with a glowing halo ring emblem and a small pair of white feathered wings spreading from its sides. Chunky glossy 3D cartoon rank badge, front view, symmetrical, thick dark plum outline, bold simple shapes that still read at 24 pixels, soft light from the top left, centered filling 80% of a square, isolated on a plain solid dark navy background, no shadow, no text, no letters, no numbers.
```

#### Badge_HaloR5 — 칭호 배지: 대천사
- 용도: Halo rank 5 badge (master of the Halo badge family)
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Generate this first (4 candidates). Reject human figures and angel faces; it is an emblem only.
```text
A grand radiant ivory-and-gold shield badge with a sunburst halo emblem, large white-and-gold feathered wings spreading from its sides and a small gold crown on top. Chunky glossy 3D cartoon rank badge, front view, symmetrical, thick dark plum outline, bold simple shapes that still read at 24 pixels, soft light from the top left, centered filling 80% of a square, isolated on a plain solid dark navy background, no shadow, no text, no letters, no numbers.
```

#### Badge_HornsR1 — 칭호 배지: 불량배
- 용도: Horns rank 1 badge
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Generate R5 first, then use it as Style Reference. Reject pentagrams, skulls and devil faces.
```text
A small angular plum-black shield badge with two tiny stubby crimson horn nubs on top, cute cartoon villain style. Chunky glossy 3D cartoon rank badge, front view, symmetrical, thick dark plum outline, bold simple shapes that still read at 24 pixels, soft light from the top left, centered filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Badge_HornsR2 — 칭호 배지: 약탈자
- 용도: Horns rank 2 badge
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject loot/money symbols (keep the title meaning in text only).
```text
An angular plum-black shield badge with a crimson rim and two short curved red horns on top, cartoon villain style. Chunky glossy 3D cartoon rank badge, front view, symmetrical, thick dark plum outline, bold simple shapes that still read at 24 pixels, soft light from the top left, centered filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Badge_HornsR3 — 칭호 배지: 군벌
- 용도: Horns rank 3 badge
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Spikes at least as thick as the outline (ART_DIRECTION: horns/spikes are never thin).
```text
A spiky angular plum-black shield badge with dark iron studs and two curling ram-style crimson horns, cartoon villain style. Chunky glossy 3D cartoon rank badge, front view, symmetrical, thick dark plum outline, bold simple shapes that still read at 24 pixels, soft light from the top left, centered filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Badge_HornsR4 — 칭호 배지: 공포의 군주
- 용도: Horns rank 4 badge (first wings)
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject menacing eyes or faces on the shield.
```text
A spiky plum-black shield badge with big swept-back crimson horns showing glowing ember cracks and small dark bat-style wings spreading from its sides, cartoon villain style, not scary. Chunky glossy 3D cartoon rank badge, front view, symmetrical, thick dark plum outline, bold simple shapes that still read at 24 pixels, soft light from the top left, centered filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Badge_HornsR5 — 칭호 배지: 마왕
- 용도: Horns rank 5 badge (master of the Horns badge family)
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Generate this first (4 candidates). Mirror the Halo R5 composition so both factions feel equally prestigious.
```text
A grand spiky plum-black shield badge crowned with four crimson horns with glowing ember tips and large bat-style wings with crimson membranes, cheeky cartoon villain style, not scary. Chunky glossy 3D cartoon rank badge, front view, symmetrical, thick dark plum outline, bold simple shapes that still read at 24 pixels, soft light from the top left, centered filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Badge_Artisan — 칭호 배지: 장인 길드
- 용도: Neutral players' nametag badge (they have no rank title yet)
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Must not look like a Halo or Horns badge: hexagon, teal and brass only.
```text
A hexagon teal-and-brass badge with a brass gear emblem, a small crossed hammer and wrench, and a warm wood rim. Chunky glossy 3D cartoon rank badge, front view, symmetrical, thick dark plum outline, bold simple shapes that still read at 24 pixels, soft light from the top left, centered filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Badge_GrayLegend — 칭호 배지: 회색 전설
- 용도: Title badge for players with 3+ Fall and 3+ Redeem marks
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject yin-yang symbols (cultural/religious). The halo-with-horns is our own symbol.
```text
A round silver-gray badge with a halo ring emblem that has two small curved horns on its sides, the ring half warm gold and half crimson, soft gray mist painted inside the outline. Chunky glossy 3D cartoon rank badge, front view, symmetrical, thick dark plum outline, bold simple shapes that still read at 24 pixels, soft light from the top left, centered filling 80% of a square, isolated on a plain solid dark navy background, no shadow, no text, no letters, no numbers.
```

#### Badge_LegendVillain — 칭호 배지: 전설의 악당
- 용도: Session title badge after surviving 120 s as kaiju
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Star must not copy the red wanted-star icon; use a medal disc with a star shape inside.
```text
A crimson-and-gold star medal with two tiny horns on top and a flame-shaped orange ribbon, cheeky cartoon villain style. Chunky glossy 3D cartoon rank badge, front view, symmetrical, thick dark plum outline, bold simple shapes that still read at 24 pixels, soft light from the top left, centered filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Mark_Fall — 표식 아이콘: 타락
- 용도: Fall-mark icon for profile/rebirth screen and nametag tooltip; the count (1-5) is a live label
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: No body inside the cape. Must match Concept_FallCape once that is approved (use it as Style Reference).
```text
A small torn dark charcoal cape with ember-red lining and a jagged hem, folded neatly as an emblem. Chunky glossy 3D cartoon rank badge, front view, symmetrical, thick dark plum outline, bold simple shapes that still read at 24 pixels, soft light from the top left, centered filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Mark_Redeem — 표식 아이콘: 구원
- 용도: Redeem-mark icon for profile/rebirth screen; count is a live label
- 크기: 1:1 -> 256x256 · 투명 · 시점: launch · 3D: False
- 검사·거절: Gold seams must be thick enough to see at 24 px. Match Concept_RedeemHalo.
```text
A white-gold halo ring with cracks mended by shining gold seams. Chunky glossy 3D cartoon rank badge, front view, symmetrical, thick dark plum outline, bold simple shapes that still read at 24 pixels, soft light from the top left, centered filling 80% of a square, isolated on a plain solid dark navy background, no shadow, no text, no letters, no numbers.
```

#### Concept_HaloGrowth — 후광 성장 5단계 + 날개 시안
- 용도: Design reference for rank-scaled Halo marks on the player's own avatar (GDD section 0 '겉모습으로 보인다', RELEASE_PLAN launch item). Rebuilt as 3D parts/MeshParts after approval; replaces the single Neon disc scaled by MarkScalePerRank.
- 크기: Firefly 16:9 reference only (not uploaded, not cut apart) · 불투명 · 시점: launch · 3D: True
- 검사·거절: Check that there are exactly five stages in the right order. If Firefly merges or miscounts them, generate one stage per image with the same mannequin. Wings must stay smaller than the body (camera and crowd clearance). Reject angel faces, robes with exposed skin and religious symbols.
```text
Five identical gray blocky mannequins in a row, three-quarter back view, each with a floating halo that grows from left to right: a thin plain gold ring; a thicker gold ring with four pearl studs; a double gold ring with short light rays; an ornate feathered ring plus small folded white feathered wings on the back; a radiant sunburst halo plus larger open white-and-gold feathered wings. Clean 3D cartoon concept render in blocky toy-avatar style: square head, simple flat face, chunky limbs, not anime, not chibi. Mannequins wear plain gray long-sleeved high-collared tunics, gloves, long trousers and boots, with shoulders, torso, midriff and legs fully covered. Even studio light, plain light gray background, kid-friendly, no text, no letters, no numbers.
```

#### Concept_HornsGrowth — 뿔 성장 5단계 + 날개 시안
- 용도: Design reference for rank-scaled Horns marks (replaces the two Neon wedges); Horns mirror of Concept_HaloGrowth
- 크기: Firefly 16:9 reference only · 불투명 · 시점: launch · 3D: True
- 검사·거절: Reject demon faces, fangs, tails with spikes, and any gore. Horn thickness stays at least 2 studs scale-equivalent (ART_DIRECTION kid rule). Use Concept_HaloGrowth as the Composition Reference so both sheets line up.
```text
Five identical gray blocky mannequins in a row, three-quarter back view, each with crimson horns that grow from left to right: tiny stubby nubs; short curved horns; long ram-curl horns with dark iron bands; big swept-back horns with glowing ember cracks plus small plum-black bat-style wings; a four-horn crown with glowing ember tips plus larger bat-style wings with crimson membranes. Cheeky cartoon villain look, not scary. Clean 3D cartoon concept render in blocky toy-avatar style: square head, simple flat face, chunky limbs, not anime, not chibi. Mannequins wear plain gray long-sleeved high-collared tunics, gloves, long trousers and boots, with shoulders, torso, midriff and legs fully covered. Even studio light, plain light gray background, kid-friendly, no text, no letters, no numbers.
```

#### Concept_ArtisanGear — 장인 톱니 성장 3단계 시안
- 용도: Future Artisan '장인 명성' growth of the teal gear mark (phase 2)
- 크기: Firefly 16:9 reference only · 불투명 · 시점: later · 3D: True
- 검사·거절: Only when the Artisan reputation system is designed; do not build earlier.
```text
Three identical gray blocky mannequins in a row, front view, each with a floating artisan emblem above the head that grows from left to right: a small brass gear; a brass gear with a glowing teal gem; two interlocking brass gears with teal glow and a tiny floating hammer and wrench. Clean 3D cartoon concept render in blocky toy-avatar style: square head, simple flat face, chunky limbs, not anime, not chibi. Mannequins wear plain gray long-sleeved high-collared tunics, gloves, long trousers and boots, with shoulders, torso, midriff and legs fully covered. Even studio light, plain light gray background, kid-friendly, no text, no letters, no numbers.
```

#### Concept_FallCape — 타락 표식: 찢어진 검은 망토 시안
- 용도: Design reference for the MarkCape accessory (Fall mark) currently drawn as a plain fabric part
- 크기: Firefly 16:9 reference only · 불투명 · 시점: launch · 3D: True
- 검사·거절: The cape must sit over the clothing, not replace it. Reject hoods that hide the face and skull clasps.
```text
One gray blocky mannequin shown in front and back view wearing a short dark charcoal cape with a jagged torn hem, ember-red inner lining and small glowing crimson stitches, cartoon villain style, not scary. Clean 3D cartoon concept render in blocky toy-avatar style: square head, simple flat face, chunky limbs, not anime, not chibi. Mannequins wear plain gray long-sleeved high-collared tunics, gloves, long trousers and boots, with shoulders, torso, midriff and legs fully covered. Even studio light, plain light gray background, kid-friendly, no text, no letters, no numbers.
```

#### Concept_RedeemHalo — 구원 표식: 금으로 이은 후광 시안
- 용도: Design reference for the MarkHalo (Redeem) accessory; turns the gray 'cracked halo' into a story: broken and mended with gold
- 크기: Firefly 16:9 reference only · 불투명 · 시점: launch · 3D: True
- 검사·거절: Must stay distinguishable from the normal Halo rank ring (the seams are the tell). Note: changing CrackedHaloColor from gray to gold seams is a look change that needs user approval of this image first.
```text
One gray blocky mannequin in front and three-quarter view with a cracked white-gold halo floating above the head, the cracks mended with shining gold seams, soft warm glow. Clean 3D cartoon concept render in blocky toy-avatar style: square head, simple flat face, chunky limbs, not anime, not chibi. Mannequins wear plain gray long-sleeved high-collared tunics, gloves, long trousers and boots, with shoulders, torso, midriff and legs fully covered. Even studio light, plain light gray background, kid-friendly, no text, no letters, no numbers.
```

#### Concept_GrayLegend — 회색 전설: 뿔 달린 회색 후광 + 안개 시안
- 용도: Design reference for the Gray Legend look (title plus the gray aura already in code)
- 크기: Firefly 16:9 reference only · 불투명 · 시점: launch · 3D: True
- 검사·거절: The mist must not hide the avatar (keep it low and thin). Badge_GrayLegend should match the approved ring.
```text
One gray blocky mannequin in front and three-quarter view with a silver-gray halo ring floating above the head, two small curved horns attached to the ring's sides, the ring half warm gold and half crimson, a soft swirling silver-gray mist aura around the body. Clean 3D cartoon concept render in blocky toy-avatar style: square head, simple flat face, chunky limbs, not anime, not chibi. Mannequins wear plain gray long-sleeved high-collared tunics, gloves, long trousers and boots, with shoulders, torso, midriff and legs fully covered. Even studio light, plain light gray background, kid-friendly, no text, no letters, no numbers.
```

#### Concept_SkyCrown — 하늘의 부서진 왕관 3상태 시안
- 용도: Reference for rebuilding CrownOfBalance (sky weenie at about y350, opening shot) with war-state glow: neutral / Dawn / Eclipse
- 크기: Firefly 16:9 reference only · 불투명 · 시점: launch · 3D: True
- 검사·거절: Crown shape must match Shard_Base facets (shards visibly come from it). Glow states are later done with Lighting/Neon colors, not three separate models.
```text
A giant broken golden crown floating in the sky above a fantasy town fountain, missing jagged pieces, glowing amber cracks, small crystal shards orbiting it. Show three versions side by side: warm neutral gold daylight; golden dawn with a bright halo-like glow; crimson eclipse night with ember glow. Chunky stylized 3D cartoon render with blocky toy-like props, kid-friendly, no people, no text, no letters, no numbers.
```

#### Sky_SunDawn — 하늘: 금빛 새벽 해 (빛 승리)
- 용도: Sky.SunTextureId while the Dawn preset is active (Halo won the war round)
- 크기: 1:1 -> 512x512, black background kept (additive blend) · 불투명 · 시점: launch · 3D: False
- 검사·거절: The background must be truly black (#000), not dark blue, or a square shows in the sky. Reject faces in the sun. Test at SunAngularSize 14 in Studio.
```text
A stylized golden sun shaped like a glowing halo ring with soft radiant rays, bright warm gold and pale yellow, centered, on a pure black background, nothing else in the image, no text, no letters, no numbers.
```

#### Sky_MoonEclipse — 하늘: 핏빛 월식 달 (뿔 승리)
- 용도: Sky.MoonTextureId while the Eclipse preset is active (Horns won)
- 크기: 1:1 -> 512x512, black background kept (additive) · 불투명 · 시점: launch · 3D: False
- 검사·거절: Additive blending makes dark plum invisible, so judge it by the ring. Reject blood drips and faces. Check against MoonAngularSize 18 and the Eclipse fog.
```text
A stylized crimson eclipse moon: a dark plum disc inside a glowing crimson-orange ring of light, with two soft flares curving upward like small horns, calm and pretty, not scary, centered, on a pure black background, nothing else in the image, no text, no letters, no numbers.
```

#### Banner_Halo — 교차로 승리 깃발: 빛
- 용도: Decal swapped onto Crossroads plaza flags for 10 min after a Halo war win; also used in the Halo town
- 크기: Firefly 9:16 -> 576x1024 Decal, opaque · 불투명 · 시점: launch · 3D: False
- 검사·거절: Reject folds/waves that bake in lighting (the 3D flag provides shape), and crosses or religious symbols. The first banner = Style Reference for the other three.
```text
Sky-blue fabric with wide gold trim borders and a large golden halo ring emblem with small feather shapes in the center. Flat front-on cloth banner texture filling the entire canvas edge to edge, straight edges, no pole, no perspective, soft fabric weave, hand-painted cartoon game texture, no text, no letters, no numbers.
```

#### Banner_Horns — 교차로 승리 깃발: 뿔
- 용도: Decal for Crossroads flags after a Horns war win; also used in the Horns den
- 크기: 9:16 -> 576x1024 · 불투명 · 시점: launch · 3D: False
- 검사·거절: Reject pentagrams, skulls and goat heads; horns only.
```text
Crimson fabric with plum-black trim borders, a zig-zag pattern painted along the bottom and a large pair of curved horns emblem outlined in ember orange in the center. Flat front-on cloth banner texture filling the entire canvas edge to edge, straight edges, no pole, no perspective, soft fabric weave, hand-painted cartoon game texture, no text, no letters, no numbers.
```

#### Banner_Crossroads — 교차로 깃발: 무승부·평소 (왕관)
- 용도: Default Crossroads flag decal and the draw result
- 크기: 9:16 -> 576x1024 · 불투명 · 시점: launch · 3D: False
- 검사·거절: The crown must match Concept_SkyCrown once approved.
```text
Cream fabric with brown trim borders and a large cracked golden crown emblem in the center, its left half glowing gold and its right half glowing crimson. Flat front-on cloth banner texture filling the entire canvas edge to edge, straight edges, no pole, no perspective, soft fabric weave, hand-painted cartoon game texture, no text, no letters, no numbers.
```

#### Banner_Artisan — 장인 길드 깃발
- 용도: Artisan Guild hall flags (replaces gray cloth with a brass disc)
- 크기: 9:16 -> 576x1024 · 불투명 · 시점: launch · 3D: False
- 검사·거절: Keep it teal (gray alone is reserved for Gray Legend/cracked meaning).
```text
Teal-gray fabric with brass trim borders and a large brass gear emblem with a teal gem in the center. Flat front-on cloth banner texture filling the entire canvas edge to edge, straight edges, no pole, no perspective, soft fabric weave, hand-painted cartoon game texture, no text, no letters, no numbers.
```

#### Decal_AltarSigil — 운명의 제단 바닥 문양
- 용도: Top-face decal of the Altar of Fate (faction switch); reusable as the rebirth panel emblem
- 크기: 1:1 -> 1024x1024 Decal · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject yin-yang curves and occult circles with runes or stars. Keep a split straight down the middle.
```text
A round carved floor sigil seen straight from above: a circle split down the middle, left half warm gold with a halo ring, right half crimson with a pair of small horns, a small cracked golden crown in the center, carved stone with a soft inner glow, chunky cartoon game style, isolated on a plain solid white background, no text, no letters, no numbers.
```

#### Decal_HaloWindow — 빛의 성채 장미창
- 용도: Decal for the Halo cathedral drum and gate (town identity)
- 크기: 1:1 -> 1024x1024 Decal · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject saints, figures and crosses. It must be ornamental only.
```text
A round stained-glass rose window, flat front view, gold lead lines, sky-blue and warm gold glass pieces, a golden halo ring with feather patterns in the center, chunky cartoon game style, isolated on a plain solid white background, no text, no letters, no numbers.
```

#### UI_WantedPoster — 현상수배 빈 포스터
- 용도: Background card for the bounty board TOP 3 (SurfaceGui); the name, stars, bounty and 'WANTED/현상수배' are live text
- 크기: 3:4 -> 768x1024 · 투명 · 시점: launch · 3D: False
- 검사·거절: Reject any fake writing, mugshot silhouettes, bullet holes and blood. The empty areas must be large enough for 3 lines of live text.
```text
A blank cartoon wanted poster: an aged cream parchment sheet with nail holes in the corners, slightly curled edges, an empty frame area in the upper middle and an empty space below, a red wax seal with a tiny horn shape at the bottom, flat front view, chunky cartoon game style, isolated on a plain solid dark navy background, no text, no letters, no numbers.
```

#### Egg_Slime — 슬라임 알
- 용도: Launch monster-drop egg (Slime/BigSlime) icon; hatch-by-kills incubator
- 크기: 1:1 -> 512x512 · 투명 · 시점: launch · 3D: True
- 검사·거절: The first egg = Style Reference for all Egg_*; same egg shape, only the pattern changes. Reject cracks with creatures peeking out.
```text
A round egg with soft lime-green jelly spots and a glossy shine. Chunky glossy 3D cartoon game icon, toy-like proportions, smooth plastic and painted materials, soft light from the top left, thick dark plum outline, bold simple silhouette, bright kid-friendly colors, one object centered in three-quarter view filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Egg_Goblin — 고블린 알
- 용도: Launch monster-drop egg (Goblin/Brute)
- 크기: 1:1 -> 512x512 · 투명 · 시점: launch · 3D: True
- 검사·거절: Must read differently from Egg_Slime at 48 px: darker olive with a leaf pattern versus round lime spots.
```text
A sturdy olive-green egg with a leafy pattern and a little twine band around it. Chunky glossy 3D cartoon game icon, toy-like proportions, smooth plastic and painted materials, soft light from the top left, thick dark plum outline, bold simple silhouette, bright kid-friendly colors, one object centered in three-quarter view filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Egg_Dawn — 새벽 알 (빛 진영 알)
- 용도: Halo faction egg (rank 2, GDD v1.2)
- 크기: 1:1 -> 512x512 · 투명 · 시점: launch · 3D: True
- 검사·거절: The halo ring stays close to the egg (the cutout must not drop it).
```text
A pearly ivory egg with soft gold sunrise stripes and a tiny glowing gold halo ring floating just above it. Chunky glossy 3D cartoon game icon, toy-like proportions, smooth plastic and painted materials, soft light from the top left, thick dark plum outline, bold simple silhouette, bright kid-friendly colors, one object centered in three-quarter view filling 80% of a square, isolated on a plain solid dark navy background, no shadow, no text, no letters, no numbers.
```

#### Egg_Night — 장난꾸러기 밤 알 (뿔 진영 알, 기존 '저주받은 알')
- 용도: Horns faction egg (rank 2). The visual is cute mischief, not a curse.
- 크기: 1:1 -> 512x512 · 투명 · 시점: launch · 3D: True
- 검사·거절: Reject eyes in the cracks, smoke and anything ominous. The name may stay '저주받은 알' in text; the art stays playful.
```text
A deep plum egg with zig-zag crimson cracks glowing ember orange and two tiny round horn nubs on top, cute and mischievous, not scary. Chunky glossy 3D cartoon game icon, toy-like proportions, smooth plastic and painted materials, soft light from the top left, thick dark plum outline, bold simple silhouette, bright kid-friendly colors, one object centered in three-quarter view filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Egg_Nest — 골드 랜덤 알 (알 둥지)
- 용도: Gold-bought random egg at the launch egg nest (odds shown, A23-15)
- 크기: 1:1 -> 512x512 · 투명 · 시점: launch · 3D: True
- 검사·거절: Reject question marks and slot-machine or casino motifs (kid-safe random-item presentation).
```text
A shiny golden egg with swirling rainbow-gold patterns and tiny sparkles painted inside the outline. Chunky glossy 3D cartoon game icon, toy-like proportions, smooth plastic and painted materials, soft light from the top left, thick dark plum outline, bold simple silhouette, bright kid-friendly colors, one object centered in three-quarter view filling 80% of a square, isolated on a plain solid white background, no shadow, no text, no letters, no numbers.
```

#### Emo_Thanks — 스티커: 고마워
- 용도: Player sticker wheel (new feature, later): thank a helper. This is the Halo-flavored reaction.
- 크기: 1:1 -> 256x256 · 투명 · 시점: later · 3D: False
- 검사·거절: Style Reference: Emo_Ouch. Reject hearts that read as romance (no kissing or pink love motifs); keep it gold and friendly.
```text
A golden heart with a tiny glowing halo ring above it. Cute glossy cartoon sticker with a thick white die-cut border and a thin dark outline, bold simple shape, centered filling 80% of a square, isolated on a plain solid dark navy background, no text, no letters, no numbers.
```

#### Emo_Help — 스티커: 도와줘
- 용도: Sticker wheel: call for help (e.g., grudge sack chase, goose rescue)
- 크기: 1:1 -> 256x256 · 투명 · 시점: later · 3D: False
- 검사·거절: Bare arm must not show (sleeve to the glove). Reject rude hand gestures.
```text
A raised blocky toy-avatar hand in a long gloved sleeve waving, with small blue motion lines. Cute glossy cartoon sticker with a thick white die-cut border and a thin dark outline, bold simple shape, centered filling 80% of a square, isolated on a plain solid dark navy background, no text, no letters, no numbers.
```

#### Emo_Cheeky — 스티커: 메롱
- 용도: Sticker wheel: Horns-flavored playful taunt
- 크기: 1:1 -> 256x256 · 투명 · 시점: later · 3D: False
- 검사·거절: Reject fangs and evil grins. Taunts get a server cooldown so they cannot be spammed at a victim.
```text
A round crimson imp face emoji with two tiny horns, winking and playfully sticking out its tongue, cute not scary. Cute glossy cartoon sticker with a thick white die-cut border and a thin dark outline, bold simple shape, centered filling 80% of a square, isolated on a plain solid dark navy background, no text, no letters, no numbers.
```

#### Emo_Revenge — 스티커: 복수다!
- 용도: Sticker wheel: ties to the orange revenge arrow (GDD 5-7)
- 크기: 1:1 -> 256x256 · 투명 · 시점: later · 3D: False
- 검사·거절: Same orange as the revenge arrow, not red.
```text
A bold orange arrow hitting the center of a round target with a little spark. Cute glossy cartoon sticker with a thick white die-cut border and a thin dark outline, bold simple shape, centered filling 80% of a square, isolated on a plain solid dark navy background, no text, no letters, no numbers.
```

#### Emo_GG — 스티커: 좋아!
- 용도: Sticker wheel: good game / nice
- 크기: 1:1 -> 256x256 · 투명 · 시점: later · 3D: False
- 검사·거절: Reject 'GG' letters; the meaning is the gesture.
```text
A blocky toy-avatar hand in a long gloved sleeve giving a thumbs up, with gold sparkles. Cute glossy cartoon sticker with a thick white die-cut border and a thin dark outline, bold simple shape, centered filling 80% of a square, isolated on a plain solid dark navy background, no text, no letters, no numbers.
```

#### Emo_Sorry — 스티커: 미안해
- 용도: Sticker wheel: apology (helps after accidental PvP)
- 크기: 1:1 -> 256x256 · 투명 · 시점: later · 3D: False
- 검사·거절: Must look like our own emoji, not a copy of a platform emoji set.
```text
A round yellow face emoji with an apologetic smile and a big blue sweat drop. Cute glossy cartoon sticker with a thick white die-cut border and a thin dark outline, bold simple shape, centered filling 80% of a square, isolated on a plain solid dark navy background, no text, no letters, no numbers.
```

#### Season_HaloHalloween — 핼러윈 후광 스킨 (호박빛 고리)
- 용도: Free yearly Halloween skin for the Halo mark; the ring silhouette is kept
- 크기: 1:1 reference only (3D accessory build after approval) · 불투명 · 시점: later · 3D: True
- 검사·거절: It must still read as a ring from 30 studs away (Silhouette Law). No scary carved faces. It would only make 10/31 if the user adds it to the beta.
```text
Head and shoulders of one gray blocky mannequin with a floating halo ring made of glowing pumpkin-orange light, decorated with three tiny cute smiling pumpkins, front and three-quarter view. Clean 3D cartoon concept render in blocky toy-avatar style: square head, simple flat face, chunky limbs, not anime, not chibi. Mannequins wear plain gray long-sleeved high-collared tunics, gloves, long trousers and boots, with shoulders, torso, midriff and legs fully covered. Even studio light, plain light gray background, kid-friendly, no text, no letters, no numbers.
```

#### Season_HornsHalloween — 핼러윈 뿔 스킨 (사탕 줄무늬 뿔)
- 용도: Free yearly Halloween skin for the Horns mark
- 크기: 1:1 reference only · 불투명 · 시점: later · 3D: True
- 검사·거절: Keep exactly two horns in the base pose so faction reading holds. The bat is optional decor.
```text
Head and shoulders of one gray blocky mannequin with two curved horns striped purple and orange like candy corn and a tiny cute bat sitting on one horn, cheeky not scary, front and three-quarter view. Clean 3D cartoon concept render in blocky toy-avatar style: square head, simple flat face, chunky limbs, not anime, not chibi. Mannequins wear plain gray long-sleeved high-collared tunics, gloves, long trousers and boots, with shoulders, torso, midriff and legs fully covered. Even studio light, plain light gray background, kid-friendly, no text, no letters, no numbers.
```

#### Season_GearHalloween — 핼러윈 장인 톱니 스킨
- 용도: Free yearly Halloween skin for the Artisan gear mark
- 크기: 1:1 reference only · 불투명 · 시점: later · 3D: True
- 검사·거절: The gear stays teal-rimmed so Neutral still reads.
```text
Head and shoulders of one gray blocky mannequin with a floating brass gear above the head decorated with tiny purple candles and a warm orange glow, front and three-quarter view. Clean 3D cartoon concept render in blocky toy-avatar style: square head, simple flat face, chunky limbs, not anime, not chibi. Mannequins wear plain gray long-sleeved high-collared tunics, gloves, long trousers and boots, with shoulders, torso, midriff and legs fully covered. Even studio light, plain light gray background, kid-friendly, no text, no letters, no numbers.
```

#### Season_HaloChristmas — 크리스마스 후광 스킨 (눈꽃 고리)
- 용도: Free winter skin for the Halo mark (could join the 12/19 Christmas decor if the user wants)
- 크기: 1:1 reference only · 불투명 · 시점: later · 3D: True
- 검사·거절: Keep the gold readable under the frost (the faction color must survive).
```text
Head and shoulders of one gray blocky mannequin with a floating halo ring of frosty snowflake crystals with holly leaves and red berries, front and three-quarter view. Clean 3D cartoon concept render in blocky toy-avatar style: square head, simple flat face, chunky limbs, not anime, not chibi. Mannequins wear plain gray long-sleeved high-collared tunics, gloves, long trousers and boots, with shoulders, torso, midriff and legs fully covered. Even studio light, plain light gray background, kid-friendly, no text, no letters, no numbers.
```

#### Season_HornsChristmas — 크리스마스 뿔 스킨 (지팡이 사탕 뿔)
- 용도: Free winter skin for the Horns mark
- 크기: 1:1 reference only · 불투명 · 시점: later · 3D: True
- 검사·거절: Red stripes dominate so Horns still reads; reject an all-white horn.
```text
Head and shoulders of one gray blocky mannequin with two curved horns striped red and white like candy canes and a tiny golden bell on each tip, front and three-quarter view. Clean 3D cartoon concept render in blocky toy-avatar style: square head, simple flat face, chunky limbs, not anime, not chibi. Mannequins wear plain gray long-sleeved high-collared tunics, gloves, long trousers and boots, with shoulders, torso, midriff and legs fully covered. Even studio light, plain light gray background, kid-friendly, no text, no letters, no numbers.
```

#### Season_GearChristmas — 크리스마스 장인 톱니 스킨 (생강빵 톱니)
- 용도: Free winter skin for the Artisan gear mark
- 크기: 1:1 reference only · 불투명 · 시점: later · 3D: True
- 검사·거절: Add a teal icing rim so Neutral still reads.
```text
Head and shoulders of one gray blocky mannequin with a floating gingerbread gear above the head with white icing and tiny colored candy buttons, front and three-quarter view. Clean 3D cartoon concept render in blocky toy-avatar style: square head, simple flat face, chunky limbs, not anime, not chibi. Mannequins wear plain gray long-sleeved high-collared tunics, gloves, long trousers and boots, with shoulders, torso, midriff and legs fully covered. Even studio light, plain light gray background, kid-friendly, no text, no letters, no numbers.
```

#### Concept_XmasCrossroads — 교차로 크리스마스 꾸밈 시안
- 용도: Reference for the launch 'Christmas decor' (RELEASE_PLAN 12/19), built with parts and Neon around the fountain/crown
- 크기: Firefly 16:9 reference only · 불투명 · 시점: launch · 3D: True
- 검사·거절: Reject a Santa character or brand-like mascots. Keep both faction colors equally present (the hub is neutral).
```text
A cozy winter fantasy town plaza: a three-tier marble fountain topped by a decorated pine tree with a glowing gold crown star, warm string lights, gift boxes, snow on rooftops, gold and crimson banners with snowflakes, a giant broken golden crown floating in the sky. Chunky stylized 3D cartoon render with blocky toy-like props, kid-friendly, no people, no text, no letters, no numbers.
```

#### Concept_HalloweenCrossroads — 교차로 핼러윈 꾸밈 시안
- 용도: Optional Halloween dressing of the hub for the 10/31 beta weekend (needs user OK, otherwise next year)
- 크기: Firefly 16:9 reference only · 불투명 · 시점: later · 3D: True
- 검사·거절: Reject gravestones, skeletons, cobwebs with spiders and blood. Must stay Minimal-maturity friendly.
```text
A fantasy town plaza at dusk dressed for a cute harvest festival: smiling pumpkin lanterns around a three-tier fountain, purple and orange string lights, friendly little ghost-shaped paper lanterns, candy bowls, a giant broken golden crown floating in the sky. Chunky stylized 3D cartoon render with blocky toy-like props, cozy and cute, not scary, no people, no text, no letters, no numbers.
```
