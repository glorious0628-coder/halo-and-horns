# 이미지 생성 2 상태 (2026-10-06)

규칙·할 일 순서: `docs/design/image_gen2_session_handoff_2026-10-06.md`. 크레딧: 지금까지 0(Firefly GPT Image 2.5 Sunburst, 중간만).

## 브라우저
- 내 Firefly 탭은 내장 브라우저 **tabId "tab-1"**. "seed"는 이미지 생성 1의 탭이라 절대 건드리지 않는다(11:27~11:40 KST에 실수로 같이 쓴 적 있음, 양쪽 결과물 이상 없음 확인).
- tab-1 JS 함수는 `window.__s2_*` 접두어만 쓴다: `__s2_run(queue)`(항목 `{tag, a: 비율 라벨, t: 문구}`, 진행 원·pending이 사라진 뒤 누름), `__s2_Q`(대기열, 돌면서 push 가능), `__s2_log`, `__s2_stop=true`(멈춤).
- 비율 라벨: '정사각형 (1:1)', '와이드 (3:2)', '긴 (2:3)'. 모델·품질은 탭을 새로 열 때마다 확인(Sunburst = value `gpt-image-2.5-prism`, 품질 `medium`).
- 다운로드: `asset_search`(GenAIAsset, createDate desc) → 이름 첫머리 + 시간으로 내 것 찾기 → `asset_get_presigned_urls` → `curl -sL` → `art/out/s2/<Key>_<안>_src.png`.

## 끝난 것
- **묶음 2 진영 화면 9장** — 커밋 5d16034, 시트 `art/review/s2/b2_faction_sheet.png`, 검수 OK. 이미지 개발에 파일·키·글자 칸 분수(approved.json `layout`/`slice`/`textRect`) 보냄.
  - FactionCardHalo/Horns/Artisan, FactionTitle, FactionPremise(9조각 Rect 120,120,904,314), FactionFooter(Rect 100,0,924,142), ClassCardHalo/Horns/Artisan(→ Config 키 ClassCardNeutral).

## 진행 중
- 묶음 4·5: IconSafe·IconHammer·IconBoot·IconAttack + PanelDark·PanelHeader·TitleRibbon·BtnSecondary·BtnConfirm·BtnSquare·BtnRound·ListRow·Chip·DialogBox·GlyphClose·StatusPlate·BarTrack·BarFill (각 2안). 아이콘은 1차에 떠 있는 반짝이가 붙어 나와 'glow and sparkles' 줄을 뺀 문구로 2안 더 뽑는 중.
- 묶음 7 (A23-32 사용자 결정 반영): 등급 칸 6장은 **어두운 남색 안쪽 + 얇은 등급색 테**(크림 칸 아님), 글리프 Bow·Bag·Map·Menu + Shrink·Expand·Sort.

## 남은 순서
1. 묶음 8·9: UIP_Star(흰색), Item_PotionMP, 주문서(흰 본체+띠 마스크), Weapon_{Warrior,Mage,Archer}_T8, Icon_Coin, Icon_Sprout, Icon_WantedStar
2. 묶음 14 Q 스킬 아이콘 3
3. 묶음 10 직업 그림 9 + 11a 안내자 초상 3 (사람 — 한 장씩 단정함 확인, 업로드 전 사용자에게)
4. 묶음 12·13, 15·16(무기 T1~T6), 17(펫 배지·감정 스티커), 19
5. 상점 NPC 최종 모습, 옷·방어구·액세서리, 몬스터 콘셉트

## 작업 도구 (scratchpad, 공용 도구는 안 고침)
- `cut_keep.py`(비율 유지 누끼, tools/cutout_flat의 cutout·edge_fix 사용), `cut_icon.py`(정사각 아이콘 + 떨어진 조각 제거 `--keep-r`), `measure_card.py`(카드 글자 칸 측정), `zoom4.py`(4배 확대 검사). 필요하면 이미지 생성 세션에 공용 도구로 넣어 달라고 부탁.
- 안 고른 원본(`art/out/s2/*_src.png` 중 커밋 안 된 것)은 로컬에만 둔다.
