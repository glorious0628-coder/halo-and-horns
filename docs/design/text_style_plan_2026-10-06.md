> 검수 세션 웹 조사(2026-10-06, 조사 3갈래 + 반박 검증). 사용자 결정 A23-35(정정: 그림 글자 취소, 모든 글자는 TextLabel)가 이 문서보다 우선한다 — 아래 ⑥ 그림 글씨는 하지 않는다.
> 이미지 개발 견본(art/review/font_samples_2026-10-06.png)은 'Roblox 기본 가족'만 봤고 Nanum Gothic(12187361718)은 넣지 않았다. 다음 비교에 넣는다.

# 한글 글씨 개선 계획 (2026-10-06)

> 기록용(10/06 당시). 지금과 다른 점: 게임 글은 영어만(A23-48), 글꼴 = Denk One(제목·버튼·숫자) + Montserrat(본문)(A23-63); (당시: 영어만이라 Nanum Gothic·한글 글꼴 고르기는 하지 않음 → **지금은 한국어 모드가 같은 게임 안에 들어옴: 바뀌는 글 = 꾸민 나눔고딕, 고정 큰 글 = Firefly GPT 글자 그림, 빛 마을 뒤 시작**, SPEC A23-111(A23-89 '한국어판 따로'보다 새것), 준비 `ko_mode_imgdev_2026-10-10.md`). 날짜 '영어판(12/19)'은 낡음(A23-119). 지금 기준: AGENTS.md · SPEC_ADDENDUM A23 · RELEASE_PLAN.

**결론:** 지금 게임 속 한글은 우리가 고른 폰트로 그려지지 않습니다. Roblox에 숨어 있는 보통 굵기 폰트 하나로만 나와서 가늘고 밋밋합니다. 그래서 두 가지를 하겠습니다. 첫째, 글씨 테두리와 크기를 바로잡습니다(바로 가능). 둘째, 한글이 진짜로 굵게 나오는 Nanum Gothic ExtraBold를 다시 비교해 보고 사용자가 고르게 합니다.

## 1) 왜 못생겨 보이나

- 지금 폰트인 Noto Sans(12187370747)에는 한글 글자가 하나도 없습니다(글자표 직접 확인, 오늘). 그래서 한글은 Roblox 기본 폰트인 "NotoSansCJK Fallback"으로 넘어갑니다. 이 폰트는 **보통 굵기(400) 하나뿐**입니다(PC 클라이언트 파일 `NotoSansCJKFallback.json`, `NotoSansCJKjp-Regular.otf` 확인, 2026-10-06). 그래서 제목을 ExtraBold로 해도 숫자와 영어만 굵어지고 한글은 가늘게 남습니다. 한 줄 안에서 굵기가 뒤섞여 보입니다.
- 테두리가 거의 보이지 않습니다. `HUD.luau:426/447`가 두께 0.4, 투명도 0.65입니다. 나머지 49곳은 1px짜리 옛 `TextStrokeTransparency`를 씁니다. 여기에 화면 축소(UIScale 0.75~0.8)까지 걸려서 테두리가 머리카락처럼 가늘어집니다.
- 글씨가 너무 작고 크기가 제각각입니다. 최소 11px이고 HUD는 12~13px로 묶여 있습니다. `TextScaled`를 쓰는 곳이 46곳이라 라벨마다 크기가 다르게 나옵니다.
- 이름표, 몬스터 이름, 표지판, 데미지 숫자는 서버에서 따로 만듭니다. 이 글씨들은 UIKit을 거치지 않아 영어와 숫자가 Montserrat(2024-05-28부터 Gotham 대신 쓰이는 폰트)이나 FredokaOne으로 나옵니다. 그래서 HUD와 서로 다른 글씨체가 됩니다.

## 2) 할 수 있는 것 (효과 큰 순서)

**① 글씨 모양 정리 (결정이 필요 없음, 가장 크게 좋아짐)**
- 옛 `TextStrokeTransparency`를 모두 `UIStroke`로 바꿉니다. 설정은 `ApplyStrokeMode=Contextual`, `LineJoinMode=Round`, `StrokeSizingMode=ScaledSize`입니다. ScaledSize는 테두리 두께가 글자 크기에 맞춰 같이 커지는 기능으로, 2025-12-04에 정식 출시됐습니다.
- `TextScaled`를 줄이고, 역할마다 크기를 정해 둡니다. 긴 글은 `AutomaticSize`와 `TextWrapped`로 줄을 바꾸고, 넘치면 `TextTruncate.AtEnd`로 자릅니다. Roblox 문서도 `TextScaled`를 피하라고 권합니다. 또 `TextScaled` 글씨는 플레이어의 글자 크기 설정(2025-08-25부터 모두에게 적용)을 따르지 않습니다.
- 최소 크기를 올립니다. 화면에 실제로 보이는 크기 기준으로 본문 14px 이상, 작은 글씨 12px 이상입니다(KRDS 2025-01-15 본문 16~17px 권장). 여러 줄 한글 설명에는 `LineHeight` 1.2를 줍니다.

**② 한글 폰트 다시 고르기 (사용자 선택 필요)**
- **Nanum Gothic `12187361718`**: Roblox에서 한글이 있는 고딕 폰트는 이것 하나뿐입니다. 굵기는 Regular 400(`12187293183`), Bold 700(`12187269190`), ExtraBold 800(`12187255449`) 세 가지가 실제로 들어 있습니다. UIKit의 굵기 3단계와 딱 맞아서 `UIKit.luau:23`의 `FONT.Id` 한 줄만 바꾸면 됩니다.
- 예전에 사용자가 나눔 대신 Noto Sans를 골랐습니다(SPEC_ADDENDUM:927-928). 그런데 그때 한글은 실제로는 위의 숨은 보통 굵기 폰트였고, 나눔도 보통 굵기로 비교했을 가능성이 큽니다. 그래서 **ExtraBold에 굵은 테두리를 넣고 나란히 비교**한 뒤 다시 고르게 합니다.
- 참고로 Noto Serif HK `12187366846`도 한글이 있고 굵기가 200~900까지 있습니다. 하지만 명조(붓글씨 느낌)라 아이들용 장난감 느낌 UI에는 맞지 않을 것 같습니다.

**③ 숫자와 영어는 둥근 폰트로 (검수 확인 필요)**
- 지금은 UIKit이 `Number=FredokaOne` 설정까지 Noto Sans로 바꿔 버립니다(`UIKit.luau:131-156`). 숫자 역할만 **Fredoka One**이나 **Luckiest Guy**를 쓰게 하면 골드, Lv, 데미지 숫자가 장난감 느낌이 납니다. 둘 다 Roblox에 기본으로 있는 폰트입니다.
- 이 두 폰트에는 한글이 없습니다. 그래서 숫자만 따로 있는 라벨에만 씁니다. 한글과 섞을 때는 RichText `<font family=…>`를 우리 글 표에 넣어서 씁니다.
- 영어판(12/19)은 나눔에도 영어 글자가 있어서 그대로 써도 됩니다. 영어 제목만 Fredoka로 바꾸고 싶으면 `Player.LocaleId` 언어별 표로 바꿉니다. Roblox에는 언어별 폰트 설정이 없어서 스크립트로 해야 합니다(DevForum 요청 2026-04-09, Roblox 답변 없음).

**④ 월드 글씨 통일:** 이름표, 몬스터 이름, 표지판, 데미지 숫자가 같은 글씨 규칙(아래 표)을 쓰게 합니다.

**글씨 역할별 레시피.** 크기는 화면에 실제로 보이는 px이고, 코드에 넣는 TextSize는 px ÷ UIScale입니다. 테두리 값은 시작값이니 Studio에서 맞춥니다.

| 역할 | 폰트·굵기 | 크기 | 테두리(UIStroke ScaledSize) | 그라데이션·그림자 |
|---|---|---|---|---|
| 큰 제목·배너 | 한글 폰트 ExtraBold 800 | 24~32 | 0.12, 짙은 남색 또는 금테 갈색, 불투명 | 흰 글씨 + UIGradient 크림→금색(색 6개 이하), 뒤에 같은 글씨 복사본을 글자 크기의 6~8%만큼 아래로, 투명도 0.4 |
| 버튼 | ExtraBold 800 | 18~22 | 0.10, 버튼보다 어두운 색 | 그림자는 작게 하거나 생략 |
| 본문·설명 | Bold 700 | 14~16, LineHeight 1.2 | 남색 판 위에서는 없음, 그림이나 3D 위에서만 0.06 | 없음 |
| 작은 글씨 | Bold 700 | 12 이상 | 0.06 | 없음 |
| 숫자(골드·Lv·타이머) | Fredoka One 또는 Luckiest Guy | 16~28 | 0.12~0.14 | 골드에만 금색 그라데이션 |
| 이름표·몬스터 이름 | 한글 폰트 Bold 700 | 고정 크기 + `UITextSizeConstraint` | 0.12, 거의 검은 남색 | 없음 |
| 데미지 숫자 | Fredoka One 또는 Luckiest Guy | 크게 | 0.14 | 흰색→노랑. 튀는 효과는 UIScale로(TextSize·Thickness는 tween 금지) |

- 색은 새로 만들지 않고 승인된 금테·남색 아트의 기존 Config 색에서 가져옵니다.
- 옛 `TextStroke`와 `UIGradient`는 같이 쓰지 않습니다(UIGradient 문서에 성능 경고).
- 글씨 그림자는 UIKit의 함수 하나로 만들어 둡니다. 나중에 Roblox 기본 기능이 나오면 바꾸기 쉽습니다(RDC26 2026-09-11에 "text shadows"를 2026년 말로 예고).

**⑤ 지금 Roblox로는 안 되는 것**
- 폰트 파일(Jua, 배민체 같은 TTF/OTF)을 올려서 쓸 수 없습니다(DevForum 2025-05-22, 2026-07-11).
- 귀엽고 둥근 한글 폰트는 Roblox에 없습니다. M PLUS Rounded 1c도 한글이 0자입니다(오늘 확인).
- 숨은 한글 폰트를 굵게 만들 수 없습니다. `<b>`나 `FontWeight`를 줘도 한글은 보통 굵기 그대로입니다. 엔진이 가짜 굵게를 그려 주는지는 아직 확인하지 못했고, 3)번 테스트에서 확인합니다.
- 글자 모양을 따라가는 그림자 기능은 아직 없습니다. `UIShadow`(2026-06-23)는 네모 칸에만 그림자를 줍니다.
- 자간(글자 사이 간격)은 조절할 수 없습니다(요청만 있음, 2025-09~2026-09).
- 글씨 하나에 테두리는 하나만 붙습니다.
- Text+ 같은 그림 글자 모듈로 한글 전체를 만들 수는 없습니다. 한글은 11,172자라 그림이 수십 장 필요하고, 자동 번역도 인식하지 못합니다(Text+ 2025-03-04).

**⑥ 그림 글씨 (선택, 베타 뒤에 고려)**
- 게임 로고, "어느 편에 설래?", 레벨 업/승리 같은 **큰 제목 10개 이하**만 해당합니다.
- OFL 무료 폰트(Jua, Black Han Sans, Do Hyeon)로 PC에서 직접 그립니다. Firefly는 한글이 부정확해서 쓰지 않습니다.
- 한국어판과 영어판이 따로 있어야 해서 제목 하나에 두 장씩 필요합니다. Roblox 자동 번역은 그림 속 글자를 번역하지 않습니다(문서 확인 2026-10-06).
- 문구를 바꿀 때마다 다시 그려 올려야 하고, 그림 속 글자는 심사도 받습니다.
- 로고 계획(판 그림 + 폰트 글씨, KO/EN)은 이미 있으니 그대로 두고, 나머지는 ①~④ 결과를 보고 정합니다.

## 3) Studio 테스트: 글씨 샘플 판

- **어디서:** `build/UiSandbox.rbxlx`(이미지 개발 세션의 두 번째 Studio). 화면은 휴대폰 749×361과 PC 두 가지로 봅니다.
- **폰트:**
  - A: 지금 쓰는 Noto Sans(12187370747) Regular / ExtraBold
  - B: Nanum Gothic 400 / 700 / 800
  - C: Noto Serif HK 900 (참고용)
  - 숫자: Fredoka One, Luckiest Guy, Nunito Black
- **문장:** "어느 편에 설래?", "Lv 12 전사", "150 골드 받기", "고블린 대장을 처치하세요 (3/5)", "스킬 MP 20 · 3초", "Which side are you on?", "Level Up!", "12,345", "+150G"
- **크기:** 화면 기준 12 / 14 / 16 / 20 / 28 / 40px
- **테두리 비교:** 지금 HUD(0.4/0.65), 옛 TextStroke, UIStroke 고정 2px, ScaledSize 0.08 / 0.12. 각각 그라데이션과 그림자를 넣은 것과 뺀 것을 같이 봅니다.
- **배경:** 승인된 남색 패널, 금색 버튼, 밝은 배경, 어두운 3D 필드
- **판단 기준:**
  1. 한글 굵기가 숫자·영어와 맞는가
  2. 휴대폰에서 12px 작은 글씨가 읽히는가
  3. 테두리가 끊기거나 뾰족하지 않은가
  4. 밝은 배경과 어두운 배경 둘 다에서 읽히는가
  5. 금테·남색 아트와 어울리는가
  6. A Regular와 A ExtraBold의 한글이 똑같이 보이는가 (똑같으면 가짜 굵게가 없다는 뜻)
- 2배로 확대한 화면도 함께 봅니다. 휴대폰 화면도 꼭 봅니다. 2026-07~08에 Windows에서만 글씨 간격이 깨지는 Roblox 버그가 보고됐습니다(DevForum 2026-08-31 기준 미해결).
- 최종 후보 2~3개를 캡처해서 사용자에게 보여 주고 고르게 합니다. 고른 결과는 검수가 SPEC_ADDENDUM에 기록합니다.

## 4) 누가 무엇을 (대략적인 시간)

- **이미지 개발** (UIKit 모양과 HUD 담당)
  - 샘플 판 만들기와 캡처: 1~2시간
  - 사용자가 고른 뒤 적용: 반나절~1일
    - UIKit에 역할별 글씨 규칙(제목/버튼/본문/작은 글씨/숫자)과 언어별 폰트 표 만들기
    - ScaledSize 테두리 함수와 그림자 함수 만들기
    - 옛 TextStroke 49곳 바꾸기
    - `HUD.luau:426/447`의 0.4/0.65와 12~13px 제한 풀기
    - `Config.UI.MinTextSize`를 12로 올리고 본문은 14로
- **게임성 개발 2** (서버): 월드 글씨를 공용 글씨 규칙으로 바꾸기, 2~3시간. 대상은 `MapBuilder`, `CharacterVisuals`, `MonsterService`, `GooseService`, `CombatService`(데미지 숫자)입니다. 공용 모듈(`ReplicatedStorage/Shared`)을 누가 맡을지는 검수가 정합니다.
- **게임성 개발:** 본 Studio에 넣고 직접 플레이로 확인, 30분
- **검수:** 사용자에게 고르게 하기(Noto Sans 그대로 vs Nanum ExtraBold), 결과 기록, 캡처 증거 확인
- **이미지 생성 2:** ⑥ 그림 제목을 하기로 정했을 때만, 베타 뒤에 합니다. 제목 10개 × 2개 언어를 PC에서 폰트로 직접 그리며, Firefly 크레딧은 들지 않습니다.
- **전체:** 세션 작업 1.5~2일 정도입니다. 사용자가 할 일은 샘플 캡처 2~3장 중에서 하나 고르는 것뿐입니다.

이번 조사에서는 저장소 파일과 Studio를 바꾸지 않았습니다. 확인한 위치는 `C:\Users\glori\Documents\Roblox\Game\src\StarterPlayer\StarterPlayerScripts\UIKit.luau`(23, 131-156)와 `HUD.luau`(426, 447)입니다.

## 출처 확인 결과(요약)
- [font-system] The project's current font, Noto Sans 12187370747, has no Korean (Hangul) characters, so all Korean text falls back to Roblox's default CJK font — https://assetdelivery.roblox.com/v1/asset/?id=12187370747 (font file read directly), UIKit.luau:23 2026-10-06 (checked live) — 확인
- [font-system] Roblox draws Korean with a hidden fallback family, 'NotoSansCJK Fallback', which has only one Regular (400) face, Noto Sans CJK JP Regular — %LOCALAPPDATA%/Roblox/Versions/version-02c37bc51a384b8f/content/fonts/families/NotoSansCJKFallback.json; RobloxPlayerBeta.exe strings; https://assetdelivery.roblox.com/v1/asset/?id=123924484074402 2026-10-06 (client 0.741 on disk, installed 2026-10-04) — 틀림: The single-face part is right: NotoSansCJKFallback.json in both installs has one Regular 400 face, rbxassetid://123924484074402, with loadStrategy sameFamilyOnl
- [font-system] Roblox staff confirmed in 2020 that the client ships Noto Sans CJK JP and uses HarfBuzz 'locl' to switch regional glyph forms by player locale — https://devforum.roblox.com/t/humanoid-names-do-not-render-with-correct-cjk-glyphs/674438 2020-07-16 / 2020-07-21 — 틀림: Misattributed. In thread 674438 the details (ships Noto Sans CJK JP v1.004, HarfBuzz, locl switching by locale) come from the opening post by community member i
- [font-system] Only two of all Roblox font families contain full Korean, Nanum Gothic and Noto Serif HK. There is no rounded or cute Korean font. — https://apis.roblox.com/toolbox-service/v1/marketplace/73 + /v1/items/details + assetdelivery face files (scan); Creator Store page https://create.roblox.com/store/asset/12187361718/Nanum-Gothic 2026-10-06 (checked live) — 확인
- [font-system] Switching UIKit's FONT.Id to Nanum Gothic (12187361718) is a one-line change. It gives real bold Korean and one matching design for Korean, Latin and digits, but it reverses the user's earlier font choice. — https://assetdelivery.roblox.com/v1/asset/?id=12187361718 (family JSON + faces); https://devforum.roblox.com/t/fonts-in-creator-marketplace-81-new-fonts/2164977 (lists NanumGothic 12187361718 as the Korean font) 2026-10-06 (checked); announcement 2023-01-25 — 확인
- [font-system] Gotham (Enum.Font.Gotham/GothamMedium/GothamBold/GothamBlack) was removed on 2024-05-28 and now maps to Montserrat, which has no Hangul — https://devforum.roblox.com/t/introducing-builder-font-deprecating-gotham-and-arial/2868222 ; https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/enums/Font.yaml 2024-03-07 / 2024-05-15 update; docs checked 2026-10-06 — 확인
- [font-system] As of Oct 2026, creators still cannot upload their own font files (TTF/OTF). Only Roblox-uploaded Creator Store families can be used. — https://devforum.roblox.com/t/can-we-upload-custom-fonts/3634261 ; https://devforum.roblox.com/t/uploading-custom-fonts-or-workarounds/4731886 ; https://devforum.roblox.com/t/how-to-actually-load-custom-font-files-ttfotf-in-studio-and-use-them/4524733 ; https://devforum.roblox.com/t/creator-roadmap-2026-spring-update/4625473 ; https://devforum.roblox.com/t/new-font-ui-live/1967004 2025-05-22, 2026-03-15, 2026-05, 2026-07-11; catalog dates checked 2026-10-06 — 확인
- [font-system] How the font API works: FontFace (the Font type) replaced the Enum.Font property, families are asset IDs, and TextService can list a family's real weights — https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/datatypes/Font.yaml ; .../classes/TextLabel.yaml ; https://create.roblox.com/docs/reference/engine/classes/TextService ; https://devforum.roblox.com/t/gettextboundsasync-claims-preloadasync-can-be-used-to-make-sure-font-is-loaded-this-is-inaccurate/2984263 docs checked 2026-10-06; staff reply 2024-05-28 — 확인
- [font-system] Rich text can switch font family and weight, and add a stroke, inside one label, but translated strings lose all rich text tags — https://create.roblox.com/docs/ui/rich-text ; https://devforum.roblox.com/t/fonts-in-creator-marketplace-81-new-fonts/2164977 docs checked 2026-10-06; announcement 2023-01-25 — 확인
- [font-system] Roblox has no per-language font setting. If English (12/19) should use a different font, a script has to swap fonts by the player's language. — https://devforum.roblox.com/t/add-more-cjk-fonts-as-well-as-different-font-properties-for-each-language/4566304 ; https://devforum.roblox.com/t/request-for-multilingual-font-support-in-roblox/3262360 2026-04-09; 2024-11-17 — 확인
- [font-system] UI Styling (StyleSheet/StyleRule/tokens/themes) has been out of beta since 2026-01-20 and can set FontFace on all text labels and buttons from one place — https://devforum.roblox.com/t/full-release-ui-styling-is-officially-released/4275082 ; https://create.roblox.com/docs/ui/styling ; https://create.roblox.com/docs/ui/styling/compatibility 2026-01-20; docs checked 2026-10-06 — 확인
- [font-system] Sprite (bitmap) font modules can show any TTF look, but they are impractical for full Korean and do not work with automatic translation — https://devforum.roblox.com/t/text-custom-fonts-advanced-control/3521684 ; https://devforum.roblox.com/t/fancytext-a-flexible-text-rendering-module-with-custom-fonts-effects-and-inline-icons/4750182 ; https://devforum.roblox.com/t/can-we-upload-custom-fonts/3634261 2025-03-02/04; 2026-07-22; 2025-05-22 — 확인
- [font-system] Automatic translation into Korean has had a confirmed bug since Aug 2025 (broken letters, mixed-in Chinese characters). It is a translation-quality problem, not a font problem. — https://devforum.roblox.com/t/automatic-translation-issue-when-translated-into-korean-the-letters-are-broken-or-chinese-characters-are-mixed/3900944 ; https://devforum.roblox.com/t/creator-roadmap-2026-spring-update/4625473 ; https://devforum.roblox.com/t/creator-roadmap-2025-end-of-year-recap/4156739 ; https://create.roblox.com/docs/production/localization/automatic-translations 2025-08-26 / 2026-03-26; roadmap May 2026 — 확인
- [styling] A big reason Korean looks plain or 'ugly': every Hangul glyph comes from one Regular-weight fallback font, whatever font or weight we pick. — Local file %LOCALAPPDATA%/Roblox/Versions/version-02c37bc51a384b8f/content/fonts/families/NotoSansCJKFallback.json (same in version-76e1a02649ad4f35); docs/art/verification_2026-10-04/faction_e/font_support.md; https://devforum.roblox.com/t/fonts-in-creator-marketplace-81-new-fonts/2164977 ; https://devforum.roblox.com/t/humanoid-names-do-not-render-with-correct-cjk-glyphs/674438 Local install checked 2026-10-06; Creator Store fonts post 2023-01-25; CJK fallback staff note 2020 — 확인
- [styling] Swapping the legacy 1px TextStroke for UIStroke with StrokeSizingMode=ScaledSize is the cheapest big quality win. — https://devforum.roblox.com/t/full-release-uistroke-improvements-scaling-offsets-and-more/3958036 ; https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/enums/StrokeSizingMode.yaml ; https://create.roblox.com/docs/ui/appearance-modifiers ; https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/TextLabel.yaml ; https://devforum.roblox.com/t/gradient-thickness-support-for-textstrokes/899101 ; https://devforum.roblox.com/t/uiscale-incorrectly-scaling-uistroke-thickness/4157250 UIStroke update 2025-09-25 → full release 2025-12-04; docs fetched 2026-10-06; legacy stroke limitation thread 2020-12-01; UIScale bug 2025-12-17 / dup closed 2026-03-26 — 확인
- [styling] The 'toy game' title look can be built from live text: gradient fill + gradient outline + offset shadow label. There is no native glyph shadow until late 2026. — https://create.roblox.com/docs/ui/appearance-modifiers ; https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/UIGradient.yaml ; https://devforum.roblox.com/t/full-release-new-ui-capabilities-shadows-individual-corners/4636263 ; https://devforum.roblox.com/t/uitextshadow-instance/4526595 ; https://devforum.roblox.com/t/rdc26-what-we-announced/4865880 ; https://devforum.roblox.com/t/9shadows-%E2%80%94-a-better-way-to-add-shadows-to-text/4811475 UIShadow 2026-05-14 beta / 2026-06-23 full; UITextShadow request 2026-03-18; RDC26 2026-09-11; 9Shadows 2026-08-14; docs fetched 2026-10-06 — 확인
- [styling] Heavy TextScaled use makes text sizes inconsistent. Roblox now advises fixed sizes + AutomaticSize, and TextScaled also ignores the player's text-size setting. — https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/TextLabel.yaml ; https://devforum.roblox.com/t/introducing-text-scaling-setting-studio-beta/3136967 ; https://create.roblox.com/docs/production/publishing/accessibility ; https://robloxapi.github.io/ref/enum/TextTruncate.html ; https://devforum.roblox.com/t/textlabels-and-other-text-displaying-gui-instances-with-textscaled-property-can-make-text-blurry/3077582 Docs fetched 2026-10-06; PreferredTextSize 2024-08-27 beta → 2025-08-25 live; TextTruncate.SplitWord 2024-04; TextScaled+RichText blur fix 2026-04-28 — 확인
- [styling] Our 11 real-px minimum is too small for Hangul on phones; use at least 14px for body, 12px for captions, and add LineHeight for multi-line Korean. — https://www.krds.go.kr/html/site/style/style_03.html ; https://brunch.co.kr/@bommade/14 ; https://create.roblox.com/docs/production/publishing/accessibility ; https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/TextLabel.yaml KRDS v1.0.0 updated 2025-01-15; Roblox docs fetched 2026-10-06; brunch article undated — 확인
- [styling] Keep text crisp: keep text out of CanvasGroups, avoid fractional pixel positions under UIScale, and re-check text after engine text updates. — https://devforum.roblox.com/t/the-still-existing-dpi-scale-issue-blurry-alike-fxaa-ui-text-on-studio-and-client/3189504 ; https://devforum.roblox.com/t/canvasgroups-content-is-blurred/3817152 ; https://devforum.roblox.com/t/quality-of-ui-elements-who-are-descendants-of-a-canvasgroup-degrades-with-low-graphics-quality/2312514 ; https://devforum.roblox.com/t/font-rendering-weird-after-latest-update/4316161 DPI blur 2024-10-10 → Studio fix 2025-05-30; CanvasGroup threads 2023–2025; text-library change 2026-01-30 / staff 2026-05-01 — 확인
- [styling] Rich text gives in-line styling (stroke, weight, color, features) without extra labels, but translations lose the tags. — https://create.roblox.com/docs/ui/rich-text ; https://devforum.roblox.com/t/introducing-opentypefeatures/3065736 ; https://devforum.roblox.com/t/missing-the-ability-to-change-letter-spacing-on-textlabels/3932796 Rich text docs fetched 2026-10-06; OpenTypeFeatures 2024-07-12; letter-spacing request 2025-09 to 2026-09 — 확인
- [styling] The UI Styling system (StyleSheets with tokens) can enforce one consistent text style everywhere, but only one contextual UIStroke per object. — https://devforum.roblox.com/t/full-release-ui-styling-is-officially-released/4275082 ; https://create.roblox.com/docs/ui/styling ; https://devforum.roblox.com/t/introducing-builder-font-deprecating-gotham-and-arial/2868222 ; https://devforum.roblox.com/t/support-nested-uigradient-selector/4401739 UI Styling full release 2026-01-20; Gotham removal 2024-05-28 (announced 2024-03) — 확인
- [styling] Numbers can get a cuter look cheaply: the 'Number' role is currently forced into Noto Sans. — C:/Users/glori/Documents/Roblox/Game/src/StarterPlayer/StarterPlayerScripts/UIKit.luau (lines 23-27, 131-156); C:/Users/glori/Documents/Roblox/Game/docs/art/video_reference_notes_2026-10-04.md:585; C:/Users/glori/Documents/Roblox/Game/docs/art/verification_2026-10-04/faction_e/font_support.md Repo state 2026-10-06 — 확인
- [styling] Sprite and bitmap fonts (for example Text+) are not viable for Korean body text, at most for a digits-only display font. — https://devforum.roblox.com/t/text-custom-fonts-advanced-control/3521684 ; https://alexxander.gitbook.io/textplus/custom-fonts/font-to-xml.md ; https://devforum.roblox.com/t/compression-of-pixelated-imagelabels-on-mobile-unavoidably-ruins-our-games-aesthetic-graphics/2506241 ; https://github.com/Roblox/creator-docs/blob/main/content/en-us/parts/textures-decals.md ; https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud/guides/usage-assets.md ; https://devforum.roblox.com/t/uploading-custom-fonts-or-workarounds/4731886 ; https://github.com/TandyRum1024/hangul-johab-render-gms ; https://devforum.roblox.com/t/what-are-the-rules-for-whats-allowed-on-images/1127960 Text+ 2025-03-02/04; mobile compression report 2023-08-04, staff reply 2025-07; custom-font answer 2026-07-11; RDC26 2026-09-11; syllable count from repo 2026-10-06; moderation threads ~2021 (older) — 확인
- [styling] Pre-rendered heading images per language give the best look, but only for a handful of fixed hero titles, and each needs a live-text fallback. — https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/localization/automatic-translations.md ; https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/localization/localize-with-scripting.md ; https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud/guides/usage-assets.md ; https://devforum.roblox.com/t/is-it-possible-to-keep-the-original-resolution-of-an-image-when-uploading/3482714 ; https://figbloxui.dev/image-moderation/ Roblox docs fetched 2026-10-06; image resolution thread 2025-02-17; figbloxui page undated — 확인
- [real-games] Roblox draws all Hangul that the chosen font lacks with a single Regular-weight Noto Sans CJK JP face, so changing the font, or setting Bold or Black, has almost no effect on Korean. — Local files C:\Users\glori\AppData\Local\Roblox\Versions\version-02c37bc51a384b8f\content\fonts\families\NotoSansCJKFallback.json and ...\PlatformContent\pc\fonts\NotoSansCJKjp-Regular.otf; https://devforum.roblox.com/t/humanoid-names-do-not-render-with-correct-cjk-glyphs/674438 ; https://thebook.io/080255/0286/ local install 2026-10-01/04; DevForum 2020-07-16/21; book page undated — 확인
- [real-games] Nanum Gothic (asset 12187361718) is the only Roblox font with real Hangul glyphs and real Bold/ExtraBold weights. Noto Sans KR, Jua, Do Hyeon and Black Han Sans are not on Roblox. — https://assetdelivery.roblox.com/v1/asset/?id=12187361718 (fetched 2026-10-06); https://create.roblox.com/store/asset/12187361718/Nanum-Gothic ; https://devforum.roblox.com/t/fonts-in-creator-marketplace-81-new-fonts/2164977 ; https://bloxodes.com/catalog/roblox-font-ids 2023-01-25 announcement; asset created 2023-01-17; list updated 2026-08-05; JSON fetched 2026-10-06 — 틀림: Wrong as stated. Noto Serif HK (12187366846) also has real Hangul (11,172 syllables in both the Regular and ExtraBold faces) and real weights 200-900, including
- [real-games] Developers still cannot upload their own TTF/OTF fonts, and the font catalog has barely changed since 2023, so Jua and similar cute Korean fonts are not available as live fonts. — https://devforum.roblox.com/t/bring-the-full-google-fonts-catalog-to-roblox/4128957 ; https://devforum.roblox.com/t/can-we-upload-custom-fonts/3634261 ; https://devforum.roblox.com/t/uploading-custom-fonts-or-workarounds/4731886 2025-12-08; 2025-05-22; 2026-07-11 — 확인
- [real-games] Developers who localize into CJK languages report the same problem: stylish Latin fonts do not carry over, and CJK text drops to a plain default font. — https://devforum.roblox.com/t/request-for-multilingual-font-support-in-roblox/3262360 ; https://devforum.roblox.com/t/add-more-cjk-fonts-as-well-as-different-font-properties-for-each-language/4566304 2024-11-17; 2026-04-09/10 — 확인
- [real-games] Two known Korean localization bugs: Roblox auto-translation into Korean can produce broken text mixed with Chinese characters, and localized strings lose their rich text tags. — https://devforum.roblox.com/t/automatic-translation-issue-when-translated-into-korean-the-letters-are-broken-or-chinese-characters-are-mixed/3900944 ; https://devforum.roblox.com/t/rich-text-doesnt-work-on-other-languages/3539197 2025-08-26 (still open 2026-03-26); 2025-03-09 — 확인
- [real-games] Cute and simulator hits mostly use a few chunky built-in Latin fonts: Fredoka One, Luckiest Guy, Comic Neue Angular, Gotham/Montserrat or Builder. None of them contains Hangul. — https://devforum.roblox.com/t/whats-a-good-font-face-to-use-as-a-general-theme-for-a-game/2538479 ; https://resources.oreate.ai/updates/best-free-fonts-for-roblox-ui-design-and-personal-customization ; https://growagarden.fandom.com/f/p/4400000000000060606 ; https://devforum.roblox.com/t/introducing-builder-font-deprecating-gotham-and-arial/2868222 ; local Roblox content/fonts folder 2023-08-19; 2024-03-07; 2025 (fandom); local install 2026-10 — 확인
- [real-games] The biggest Korean-made Roblox hit, Sol's RNG, sidesteps the Hangul font problem: its UI is in English, and its look comes from Latin display fonts. — https://www.sedaily.com/article/14089942 ; https://www.gametoc.co.kr/news/articleView.html?idxno=104153 ; https://sol-rng.fandom.com/wiki/Sovereign ; https://sol-rng.fandom.com/wiki/Layers ; https://namu.wiki/w/분류:Roblox/게임/한국 게임 2025 (Sedaily); 2025-01 (Gametoc); fandom pages undated — 확인
- [real-games] Workaround A (live text, localizable): pick the font per language. Korean uses Nanum Gothic Bold/ExtraBold; English and numbers use Fredoka One or Luckiest Guy. Rich text lets both share one label. — https://create.roblox.com/docs/production/localization/localize-with-scripting ; https://create.roblox.com/docs/ui/rich-text ; https://devforum.roblox.com/t/add-more-cjk-fonts-as-well-as-different-font-properties-for-each-language/4566304 docs current 2026; DevForum 2026-04-10 — 확인
- [real-games] Workaround B (same font, styled better): the toy/simulator look comes from a thick round dark outline, a fake drop shadow, white text with a gradient, and bigger sizes. Roblox's new UIShadow does not shadow text glyphs. — https://devforum.roblox.com/t/full-release-uistroke-improvements-scaling-offsets-and-more/3958036 ; https://devforum.roblox.com/t/full-release-new-ui-capabilities-shadows-individual-corners/4636263 ; https://devforum.roblox.com/t/uistroke-not-working-with-uigradient/2393178 ; https://create.roblox.com/docs/ui/appearance-modifiers 2025-09-25 beta / 2025-12-04 full; 2026-05-14 beta / 2026-06-23 full — 확인
- [real-games] Workaround C (fixed titles only): bake lettering into images in a cute Korean font (Jua, Black Han Sans, Do Hyeon; OFL), one KO and one EN version. Text+ can render any TTF as bitmap glyphs, but it is impractical for general Korean text. — https://devforum.roblox.com/t/text-custom-fonts-advanced-control/3521684 ; https://github.com/AlexanderLindholt/TextPlus ; https://alexxander.gitbook.io/textplus/custom-fonts/font-to-xml.md 2025-03-02 / 2025-03-04 — 확인
- [real-games] Some of the ugliness may come from Roblox's own 2026 text-rendering changes on Windows, so judge text on a phone as well as in Studio or the PC client. — https://devforum.roblox.com/t/font-rendering-weird-after-latest-update/4316161 ; https://devforum.roblox.com/t/new-font-rendering-issue-after-latest-update/4751547 2026-01-30 to 2026-08; 2026-07-22 to 2026-08-31 — 확인
- [real-games] Small sizes and auto-fit shrinking hurt both looks and performance. Older DevForum guidance is to avoid TextScaled, keep few font/size variants, use roughly 20+ px for readability, and test on a phone. — https://devforum.roblox.com/t/all-about-text-best-practices/1515743 ; https://devforum.roblox.com/t/design-mobile-first/3029532 2021-10-19; 2024-06-19 — 확인
