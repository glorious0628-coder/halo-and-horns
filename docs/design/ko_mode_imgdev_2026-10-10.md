# 한국어 모드 — 이미지 개발 준비 (A23-111, 2026-10-10)

> SPEC A23-111: 같은 게임 안에 한국어 모드. 만드는 차례는 빛 마을(①)을 끝낸 뒤이고, 지금은 설계와 준비만 합니다. 이 문서는 이미지 개발 몫 세 가지입니다: ① 나눔고딕 꾸미기(UIKit 글 스타일) ② 한국어 줄바꿈·칸 넓이 ③ 고정 큰 글 목록(이미지 생성 2가 GPT로 글자 그림).
> 예전 조사: `docs/design/text_style_plan_2026-10-06.md`(기록용 — 그때는 영어만이라 쓰지 않음).

## ① 나눔고딕 꾸미기 — 후보 시트

- 시트: `art/review/imgdev/ko_style_candidates_2026-10-10.png`. UiSandbox Edit 화면 1280×720(1.5배로 찍힘)에 지금 영어 모습과 후보 A·B·C를 나란히 놓았습니다. 리본 제목·창 제목·본문·버튼 2개·숫자·메뉴 칸 이름표가 들어 있고, 바탕은 승인된 그림(TitleRibbon·PanelCard·BtnPrimary·BtnConfirm)입니다.
- 글꼴: Nanum Gothic `rbxassetid://12187361718`. Roblox 목록에 있고 한글이 있는 고딕은 이것뿐입니다. 굵기 Regular·Bold·ExtraBold 셋이 실제로 들어 있고, 시트에서 ExtraBold 한글이 진짜로 굵게 나오는 것을 확인했습니다. 지금 영어 글꼴(Denk One·Montserrat)에는 한글이 없어서, 한글은 가는 기본 글꼴로 넘어갑니다.
- 숫자·Lv·골드는 한국어에서도 Denk One을 그대로 씁니다. 영어 화면과 같은 느낌이고 시트에서도 잘 어울립니다. 숫자만 있는 라벨은 Denk One, 한글이 섞인 줄은 나눔고딕으로 합니다.

| 후보 | 제목(리본·창) | 버튼 | 본문 | 메뉴 칸 이름표 |
|---|---|---|---|---|
| A 깔끔 | ExtraBold 흰 글 + 남색 테두리 0.12 | ExtraBold 흰 글 + 갈색 테두리 0.10 | Bold, 줄 높이 1.22 | ExtraBold + 남색 테두리 0.12 |
| B 금빛 제목 | ExtraBold + 크림→금 그라데이션 + 갈색 테두리 0.12 + 그림자(아래 7%, 투명 0.45) | A + 작은 그림자(6%) | Bold, 1.22 | A와 같음 |
| C 장난감 | ExtraBold + 흰→하늘 그라데이션 + 굵은 남색 테두리 0.17 + 진한 그림자(10%) | 테두리 0.14 + 그림자 8% | ExtraBold, 1.22 | 테두리 0.16 |

- 테두리 값은 UIStroke `StrokeSizingMode = ScaledSize`(글자 크기에 대한 비율), `LineJoinMode = Round`, `ApplyStrokeMode = Contextual`입니다.
- 그림자는 같은 글을 하나 더 만들어 아래로 내리는 방식입니다(Roblox에 글자 그림자 기능이 아직 없음). 그라데이션은 UIGradient를 90도로 줍니다.
- **이미지 개발 추천: 제목은 B, 버튼·이름표는 A, 본문은 Bold에 줄 높이 1.22.**
  - B의 금빛 제목은 승인된 금테 그림과 같은 색이고, 남색 창 위에서 가장 눈에 띕니다.
  - 크림색 리본 위에서는 금빛이 약하므로 리본 제목만은 A(흰 글 + 남색 테두리)나 C가 더 잘 읽힙니다.
  - C는 굵어서 잘 읽히지만 영어 화면(Denk One)보다 무겁습니다.
- 정할 것(검수 → 사용자): 후보 하나, 또는 조합(위 추천처럼 자리마다 다르게).

## ② 한국어 줄바꿈·칸 넓이

| 문제 | 시트·코드에서 본 것 | 정할 규칙(만들 때) |
|---|---|---|
| 줄 사이가 좁음 | 줄 높이 1.0이면 한글 받침과 윗줄이 거의 닿음. 1.22로 고쳐 다시 찍은 시트에서 알맞음 | UIKit 글 스타일에 언어별 LineHeight: ko 본문 1.22, 한 줄 제목·버튼은 1.0 |
| 줄바꿈 자리 | Roblox TextWrapped는 띄어쓰기(어절)에서 줄을 바꿔 "…한 번 써 / 보세요."처럼 마지막 줄이 짧아짐 | 지금의 UIKit.BalanceLines(줄 균형)는 언어와 상관없이 글 상자 폭을 줄여 보는 방식이고, 복사본이 원래 FontFace를 그대로 쓰므로 나눔고딕에서도 그대로 동작. 글 표에 붙여 써야 할 말(예: "1번 칸")은 줄 안 바뀌는 공백(U+00A0)을 쓰도록 번역 규칙에 넣음 |
| 글 길이 | 한국어는 글자 수가 영어의 약 0.5~0.8배지만 한 글자가 넓음. 'Ranking'→'순위'처럼 짧아지는 쪽이 많음 | 칸 크기는 영어 기준 그대로. FitText 하한은 한글이 획이 많아 실제 px +1(이름표 10→11, 본문 12→13) |
| 숫자·영어 섞임 | "Lv 12 · 150"은 Denk One이 더 어울림 | 숫자만 있는 라벨은 Denk One. 섞인 줄은 나눔고딕 하나로(RichText 글꼴 섞기는 만들지 않음 — 측정이 어긋남) |
| 테두리 비용 | 테두리·그림자·그라데이션은 큰 글에만 | 본문(남색 판 위)은 테두리 없음, 그림·3D 위의 작은 글만 0.06 |

- UIKit 쪽 할 일(만들 때): `FONT.Sets.ko = { Head = Nanum ExtraBold, Body = Nanum Bold }`. FONT.Lang은 개발 1의 L10n 장치가 정합니다. 그다음 TextStyles에 언어별 Stroke·Gradient·Shadow·LineHeight를 넣고, 측정(UIKit.MeasureText·BalanceLines 복사본)이 언어별 FontFace를 쓰는지 확인합니다.

## ③ 고정 큰 글 목록 (이미지 생성 2 — GPT 글자 그림)

- 규칙(A23-89·A23-111): 늘 같은 큰 글만 그림으로 합니다. 퀘스트·알림·숫자 들어간 글처럼 바뀌는 글은 ①의 나눔고딕입니다.
  - 그림 한 장 = 낱말 하나, 투명 PNG, 글자 높이 약 160px(배너는 256px).
  - 스타일은 ①에서 고른 것(제목 = 금빛 B 등)과 같게 그립니다.
  - 후보는 중간, 고른 것은 고급으로 만들고, 한 글자씩 크게 확대해 틀린 글자를 검사합니다.
- 메뉴 칸 이름표처럼 실제 13~15px로 작은 글은 그림으로 하지 않고 나눔고딕 글로 둡니다. 그림을 줄이면 오히려 흐려집니다.
- 한국어 낱말은 이미지 개발이 낸 초안입니다. 쉬운 한국어로 썼고, 용어집과 최종 검토는 검수가 합니다.

| 묶음 | 영어(지금) | 한국어 초안 | 쓰는 곳 |
|---|---|---|---|
| 게임 | Halo & Horns | 헤일로 & 혼스 | 로고·오프닝·진영 고르기 |
| 진영 | Halo / Horns / Neutral(Artisan) | 빛 / 뿔 / 장인 | 진영 카드·순위·전쟁 게이지 |
| 고르기 | Which side will you join? / Pick a class! / I'm In! | 어느 편에 설래? / 직업을 골라! / 좋아, 할래! | 오프닝·진영·직업 카드·안내 대화 |
| 직업 | Warrior / Mage / Archer | 전사 / 마법사 / 궁수 | 직업 카드 |
| 진영 직업 | Halo Paladin · Light Mage · Ranger / Berserker · Dark Mage · Shadow Hunter / Blacksmith · Alchemist · Pet Tamer | 빛의 기사 · 빛 마법사 · 레인저 / 광전사 · 어둠 마법사 · 그림자 사냥꾼 / 대장장이 · 연금술사 · 펫 조련사 | 직업 카드·내 캐릭터 창 |
| 창 제목 | Hero · Bag · Skills · World Map · Ranking · Pets · Settings · Shop · News · King Diary · Travel · Help · Quests · Menu · Quick slots · Rebirth · Lost & Found · Sell Weapon · Scrolls | 영웅 · 가방 · 스킬 · 세계 지도 · 순위 · 펫 · 설정 · 상점 · 새 소식 · 왕의 일기 · 이동 · 도움말 · 퀘스트 · 메뉴 · 퀵슬롯 · 환생 · 분실물 · 무기 팔기 · 주문서 | 창 리본 제목 |
| 버튼 | Claim · OK · Buy · Sell · Close · Back · Cancel · Equip · Use · Enhance · Upgrade · Skip · Next · Yes · No | 받기 · 확인 · 사기 · 팔기 · 닫기 · 뒤로 · 취소 · 장착 · 쓰기 · 강화 · 업그레이드 · 건너뛰기 · 다음 · 네 · 아니요 | 버튼 그림 위 |
| 전투 | Attack · Skill · Auto ON · Auto OFF | 공격 · 스킬 · 자동 켬 · 자동 끔 | 공격·자동 버튼 |
| 배너 | Level Up! · KO! · Victory! · Quest Complete! · Crown War · Welcome back! · Saved! | 레벨 업! · KO! · 승리! · 퀘스트 완료! · 왕관 전쟁 · 다시 왔구나! · 저장됨! | 큰 알림·상단 바 |

- 수: 낱말 약 70개입니다. 버튼 단어 15개는 금색·초록 버튼 둘 다에 쓰므로 그림은 흰 글 하나로 만들고 색은 버튼이 줍니다.
- Roblox 자동 번역은 그림 속 글자를 번역하지 않습니다. 그래서 같은 자리에 영어 그림 id와 한국어 그림 id를 두고, 클라가 자기 언어 것을 고릅니다(A23-111).
