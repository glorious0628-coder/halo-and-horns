# 창 꾸미기 점검표 (이미지 개발, 2026-10-07)

> 기록용(10/07 당시). 지금과 다른 점: RewardRays(뒤에서 도는 빛살)는 없앰 — 빛살 금지, 빛은 둥근 후광·반짝이만(사용자 10/07, AGENTS); 상점은 Robux 패스·치장 상점(ShopUI, 최신: SPEC A23-75). 지금 기준: AGENTS.md · SPEC_ADDENDUM A23 · RELEASE_PLAN.

검수 요청(사용자: 'Vacation Bonus' 창 캡처 "이런 화면도 멋있게 디자인 다시 해야 되는 거 알지?"):
Panels에 등록된 모든 창과 팝업을 훑어서 승인 그림을 안 쓰는 창을 목록으로 만든다.

- 사진(지금 모습): `art/review/window_audit_pc_2026-10-07.jpg`, `art/review/window_audit_phone_2026-10-07.jpg`
  (UiSandbox Play, PC 1280×720·폰 749×361, `tools/window_audit_view.py`; 창 16개 + 확인 상자 + 알림)
- 숫자: `docs/art/verification_2026-10-07/window_audit_2026-10-07.json`
  (창 안에서 보이는 그림 = Config.UIArt 이름, 코드로 칠한 면, 그림 버튼 / 코드 버튼)
- 승인 그림(창에 쓸 것): PanelMain(크림 판·남색 테), PanelCard(남색 판·금 테), RibbonHeader(남색 알약 + 왼쪽 동그라미),
  DialogBox, ListRow·ListRowSelected, BtnPrimary(금)·BtnSecondary(파랑)·BtnConfirm(초록), BtnRound + GlyphClose(X),
  GlyphBack, TabOn·TabOff, BannerGold, RewardRays, Toast, BannerAlert, InputField, ToggleTrack·ToggleKnob

## 한 줄 결론

**Panels의 창 16개가 모두 같은 코드 껍데기 하나를 쓴다.** `Panels.luau` `ensureRoot`(까만 판 + 금색 선 + 제목 글 + 빨간 네모 X +
Back) · `makeButton`(UIKit.Button: 색 칠한 둥근 사각) · `makeCard`(코드 카드)의 세 곳이다. 그래서 창마다 따로 그리지 않고
**이 세 곳을 승인 그림으로 바꾸면 16개 창이 한 번에 바뀐다.** 확인 상자(UIKit.Confirm)·알림(Toast·큰 알림)도 코드 모양이고,
Toast·BannerAlert는 승인 그림이 올라가 있는데 안 쓰고 있다.

## 창별 표 (UiSandbox 2026-10-07, PC 1280×720 / 폰 749×361 같은 숫자)

'그림' = 창 안에 보이는 승인 그림 수, '코드 면' = 그림 없이 색을 칠한 판·버튼·줄 수, '버튼' = 그림 버튼 / 코드 버튼.
창 크기는 PC 624×480 px · 폰 585×264 px로 **내용과 상관없이 같다**(Story만 PC 624×288).

| 창 | 여는 곳 | 그림 | 코드 면 | 버튼 그림/코드 | 보이는 문제 | 판정 |
| --- | --- | --- | --- | --- | --- | --- |
| Story (대화·선택) | 이야기 퀘스트 | 0 | 3 | 0/3 | 까만 판에 글 2줄 + 버튼 1개, 말하는 이 얼굴 없음 | 코드 |
| Welcome (안내자) | 진영 고른 뒤 서버 | 1 (PortraitGuideHalo, PC만) | 5 | 0/5 | 초상만 그림, 버튼 3색 | 코드 |
| Menu | [메뉴]·B | 0 | 12 | 0/11 | 회색 버튼 11개 | 코드 |
| Travel (이동) | 메뉴·이동 칸 | 0 | 12 | 0/6 | 줄 5개 + 파란 Go | 코드 |
| Class (직업 바꾸기) | 설정 | 0 | 5 | 0/4 | 코드 카드 3장 | 코드 |
| Rebirth (환생) | 설정 | 0 | 5 | 0/4 | 색 판 3개(빛·뿔·장인) | 코드 |
| Altar (진영 바꾸기) | 제단 | 0 | 5 | 0/4 | 코드 카드 2장 | 코드 |
| Items (가방) | 가방 칸 | 0 | 2 | 0/1 | 글 4줄, **아래 2/3 빈칸** | 코드 |
| WeaponShop (대장간) | 대장간 NPC | 0 | 2 | 0/1 | 멀리서: 글 3줄, **아래 3/4 빈칸** | **코드 — 상점 1** |
| PotionShop (물약 가게) | 물약 NPC | 0 | 6 | 0/5 | 회녹색 사기 버튼 4개 | **코드 — 상점 2** |
| Shop (바꾸기 표) | 메뉴 | 0 | 6 | 0/3 | 보라 Coming soon 2개 | 코드 |
| Vacation (휴가 보너스) | 접속 때·설정 | 0 | 2 | 0/1 | 보너스 없으면 글 1줄, **창 거의 빔** | **코드 — 사용자 지적** |
| Settings | 설정 칸 | 0 | 25 | 0/14 | 노랑·남색 탭, 회색 줄 10개 | 코드 |
| Help / News | 도움말·새 소식 칸 | 0 | 2~3 | 0/1~2 | 글만(스크롤) | 코드 |
| Nickname | 설정 | 4 (PanelParchment 2, CardHalo, BtnSpecial) | 1 | 2/0 | 제목 띠만 코드(TitleRibbon id 없음) | 그림 |
| 확인 상자 (UIKit.Confirm) | 환생·진영·직업·팔기 | 0 | 3 | 0/2 | 까만 상자 + 회색·초록 버튼 | 코드 |
| Toast (작은 알림) | 어디서나 | 0 | - | - | 까만 판 + 색 선 | 코드 — Toast 그림 있는데 안 씀 |
| 큰 알림 (UIKit.Announce) | 서버 큰 소식·레벨업 | 0 | - | - | 그라데이션 띠 | 코드 — BannerAlert 그림 있는데 안 씀 |

## 새 그림이 필요한가

- **공통 틀: 새 그림 0.** 있는 승인 그림으로 된다. 남색 PanelCard를 몸통으로 쓰면 지금의 흰 글자를 그대로 읽을 수 있어
  창 안 내용(16개 창의 글·줄)을 다시 쓰지 않아도 된다. 크림 PanelMain은 남색 글자가 필요해서 창 안 글색을 모두 바꿔야 한다
  (나중에 창별로 고를 수 있게 둔다).
- **보상 팝업:** 이미지 생성 2가 그리는 중(보상 판·띠 빛/뿔, 아이템 칸, 빛무리, 반짝이; 프롬프트 ba2186e). 오기 전에는
  BannerGold + RewardRays + PanelCard로 틀을 만든다.
- Nickname 제목 띠(TitleRibbon)는 옛 계정 그림이 지워져 코드 대체 중 → 공통 제목(RibbonHeader)으로 바꾸면 해결.

## 고치는 순서(제안)

1. 공통 껍데기: PanelCard 몸통(9조각) + RibbonHeader 제목(위 테두리에 걸침, 왼쪽 동그라미에 창 아이콘) + 오른쪽 위 BtnRound X
   (늘 같은 자리) + Back = GlyphBack 둥근 버튼. **창 높이 = 내용 높이**(최대 화면 안, 넘치면 스크롤).
2. 버튼: makeButton 색 → 그림(초록 Free·확인 = BtnConfirm, 금 Buy = BtnPrimary, 파랑·기본 = BtnSecondary, 꺼짐 = 흐리게).
3. 카드·줄: makeCard·줄 → ListRow / ListRowSelected(크림, 남색 글) 또는 PanelCard 안쪽 판.
4. 상점 2개(무기·물약)를 먼저 사진으로 확인 → 나머지 창.
5. 확인 상자 → DialogBox 판 + 승인 버튼 2개.
6. 알림: Toast 그림, 큰 알림 BannerAlert.
7. 보상 팝업 하나(휴가 보너스·일일 상자·이벤트 보상·레벨업): BannerGold 제목 + RewardRays + 숫자 굴러 올라감 + 큰 Claim(BtnConfirm).

## 고친 뒤 (공통 틀, 2026-10-07 저녁)

- 사진: `art/review/window_audit_after_pc_2026-10-07.jpg`, `art/review/window_audit_after_phone_2026-10-07.jpg`
  (`py tools/window_audit_view.py pc phone --tag after`: 같은 창 16개 + 확인 상자 + 보상 팝업 견본 + 스킬 없는 전투 버튼,
  Vacation은 보너스 2일로 열어 새 보상 팝업; 숫자 `docs/art/verification_2026-10-07/window_audit_after_2026-10-07.json`)
- **공통 틀(Panels 껍데기):** 남색 PanelCard 판(9조각) + 위 테두리에 걸친 RibbonHeader 제목(왼쪽 동그라미에 창 아이콘:
  IconTravel·IconBag·IconHammer·IconPotionHP·IconSettings …) + 오른쪽 위 BtnRound + GlyphClose X(늘 같은 자리), 다른 창에서
  열었으면 왼쪽 위 BtnRound + GlyphBack. 창 높이 = 내용 높이(내용이 늘거나 줄면 다시 맞춤, 화면보다 길면 스크롤).
  그림이 없으면 예전 코드 모양(IMG-R4).
- **버튼:** makeButton이 승인 캡슐(UIKit.ArtTextButton): 초록(Free·Good) = BtnConfirm, 금(Buy·선택·켜짐) = BtnPrimary,
  나머지 = BtnSecondary(파랑). 글자는 버튼 안에 맞춰 12px까지 줄어듦. btn.Text 대입·꺼짐(흐리게)은 그대로 동작.
- **확인 상자:** 크림 DialogBox 판 + 남색 글 + Cancel(파랑)·OK(초록).
- **보상 팝업 하나(UIKit.RewardPopup):** BannerGold 제목 + 뒤에서 도는 RewardRays + SlotCommon 칸(코인·XP 아이콘, 숫자가 0부터
  굴러 올라감) + 큰 Claim(BtnConfirm) + 선택 Later. 화면보다 크면 맞게 줄임(폰). 진영 보상 판·띠(이미지 생성 2 고급)가
  오면 Config 키(RewardPanelHalo/Horns, RewardRibbonHalo/Horns, RewardSlot)만 채우면 바뀜. **Vacation Bonus**가 첫 사용처.
- **같이 고친 것(검수):** 장인 진영 숨김(Rebirth 버튼·Altar 카드: Config.Pickable = Features.NeutralFaction), 메뉴의 티켓
  상점 숨김(상품 id가 생기면 다시 보임), 창·팝업 그림 미리 불러오기(첫 확인 상자가 빈 판으로 1초 보이던 것).
- **남은 것:** 카드·줄(makeCard·Row)은 아직 코드 모양(남색 판 위라 읽기는 됨) → ListRow 그림은 창별로. 작은 알림(Toast)·
  큰 알림(BannerAlert) 그림 입히기, '창이 열려 있으면 알림이 창 위 한 줄로'(UI 2회차 #4).

