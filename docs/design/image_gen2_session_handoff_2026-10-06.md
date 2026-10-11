# 이미지 생성 2 세션 인계 (2026-10-06, 검수 작성)

사용자 결정 SPEC A23-31: 이미지 세션을 둘로 나눈다. **이미지 생성**(기존)은 세계·굵직한 그림(지형·하늘·사냥터 분위기·게임 아이콘·썸네일·출시 장식), **이미지 생성 2**(이 세션)는 **자잘한 그림 전부**다.
> 10/11 갱신: 중립(장인 길드)은 12/1 베타에 들어감(A23-119; 아래 '베타에서 빠짐(A23-57)'은 낡음). 호박밭·유령 숲 그림은 내년 10월까지 숨김, 대신 새 구역(수정 동굴·산호 해안) 몬스터·장소 그림(A23-123, 슬라임 없음). 아래 '직업 옷 디자인 시트'는 하지 않는다(치비 의상 없음 — 사람 = 본인 Roblox 아바타 + 직업 무기 + 후광·뿔). 한국어 고정 큰 글은 GPT 글자 그림(A23-111). 할 일 순서는 `role_prompts/07_img2.md`가 기준.
> 2026-10-09 검수: '이미지 생성' = 지금 이름 **이미지 생성 1**. 이미지 생성 2는 자잘한 그림에 더해 빛·뿔 마을·호박밭·유령 숲의 장소 시안 묶음(A23-93)과 큰 물건 앞·옆·뒤 멀티뷰(A23-80)도 그린다. 재활용 그림은 새로(A23-96, `docs/design/remake_list_2026-10-09.md`).

## 먼저 읽을 것
- `AGENTS.md`(Hard rule 1 단정한 옷, Art workflow, Roles)
- `docs/design/image_session_handoff_2026-10-06.md` — Firefly 쓰는 요령(1,024자 제한, 1280×900 창, JS 대기열 `__setPrompt`/`__gen`, `tools/cutout_flat.py --holes`·가장자리 정리, `tools/band_mask.py`)
- `docs/design/visual_direction_2026-10-05.md` §1·§3(묶음 표), `docs/design/firefly_prompt_pack_2026-10-05.md`
- SPEC A23-25(고르기는 네가, 시트로 보여 주기), A23-29~A23-31

## 규칙
- Firefly GPT Image 2.5, ~~**중간 품질만**(크레딧 0). 높음(5크레딧)은 검수에게 먼저.~~ → 고르기용 시안·후보 = 중간(0), 고른 최종 그림은 종류와 관계없이 모두 고급(5)(A23-47 보강 3). 쓴 크레딧·잔액은 기록과 검수 보고에 적는다(사용자에게는 잔액 약 500일 때만, A23-96).
- 회색 바탕에서 받고 `tools/cutout_flat.py`로 누끼. 밝은·어두운 바탕, 실제 크기·4배로 확인. 형제 그림은 한 시트로.
- 글자 없는 빈 판. 브랜드 이름(“Roblox”, “R15” 등) 문구 금지 → "blocky toy-avatar style, square head, simple flat face, chunky limbs".
- 옛 그림은 참조 금지. 승인된 새 마스터(묶음 1: `art/review/b1/`, `art/ui/PanelMain`, `BtnPrimary`, `SlotRare`, `IconPotionHP`)만 스타일 참조로 쓴다. 지금 기준 그림 목록은 `art/style_anchors/README.md`(A23-80).
- 사람 그림: 어깨·몸통·배·다리를 가리고 얼굴·손만 보이게. 업로드 전에 반드시 사용자 확인 — ~~네 채팅에서~~ **검수에게 보내고 검수가 사용자에게 받는다**(사용자에게 직접 묻지 않음, AGENTS Roles).
- `art/approved.json`은 이미지 생성 1과 같이 쓴다: 고치기 직전에 다시 읽고, 내 키만 고치고, 바로 경로 지정으로 올린다 — 공유 트리에서는 ~~`git commit -m "…" -- <경로>`~~ `py tools/push_paths.py -m "제목" <경로>`(AGENTS Hard rule 5).
- 공용 도구(`cutout_flat.py`, `band_mask.py`, `make_tileable.py`)는 이미지 생성만 고친다. 고칠 게 있으면 그 세션에 부탁.
- 검토용 시트는 `art/review/s2/` 아래에 둔다(이미지 생성 시트와 섞이지 않게).
- **브라우저 충돌 방지(이미지 생성 요청):**
  - 이미지 생성의 Firefly 탭은 내장 브라우저 tabId "seed"이고 JS 대기열(`window.__T`/`__runQueue`)이 계속 돈다. 그 탭은 절대 건드리지 말고, `preview_start(url)`로 내 탭을 새로 연다. Firefly 모델·비율 설정은 탭마다 따로 확인한다.
  - `asset_search` 최근 목록에는 두 세션의 생성물이 섞인다. 프롬프트 첫머리(그림 이름)로 구분한다.
  - 다운로드 원본은 `art/out/s2/`에 둔다.
  - 생성 버튼은 이전 장이 끝나기 전에 누르면 조용히 버려진다. 진행 원(`sp-progress-circle`)이 사라진 뒤 누른다.
- 끝난 묶음마다: 커밋 → **이미지 개발**에 파일·키 → **검수**에 해시+시트 경로. 업로드·Config.UIArt는 이미지 개발이 한다.

## 할 일 순서 (베타 필수 먼저)
> 2026-10-09 검수: 이 절은 낡음(10/06 순서). 지금 할 일은 `docs/handoff/role_prompts/07_img2.md`, `docs/design/halo_town_plan_2026-10-09.md`(빛 마을 멀티뷰), remake_list P5 아이콘. 중립(장인)은 베타에서 빠짐(A23-57), 스킬은 Lv5·15·25(A23-71), Tripo 3D는 사용자 상시 OK·검수 승인(A23-47 보강 4).

1. (이미 처리) `IconNoBuff` 다시 자르기는 이미지 생성이 끝냄(3f1716b), `IconGoldGuard`도 이미지 생성이 하는 중. 네 첫 일은 2번이다.
2. **묶음 2 진영 화면**: 빈 진영 카드 3(빛·뿔·장인), 제목 판, 설명 판, 하단 판, 직업 카드 틀 3(3:4 아치). 문구는 이미 있음: `art/prompts/UIP_FactionCard{Halo,Horns,Artisan}.txt`, `UIP_Faction{Title,Premise,Footer}.txt`, `UIP_ClassCard{Halo,Horns,Artisan}.txt`(뿔 카드는 귀여운 뿔 투구 B안). 특성 줄 칸이 들어갈 자리를 비워 둔다(새 특성 아이콘 10장이 코드로 올라감).
3. 묶음 4·5 공통 창: Icon_Safe·Hammer·StatSpeed·StatAttack, 9-slice 부품(PanelDark, PanelHeader, TitleRibbon, BtnSecondary, BtnConfirm, BtnSquare, BtnRound, ListRow, Chip, DialogBox, GlyphClose, StatusPlate, BarTrack, 흰 BarFill). 가운데는 평평하게, 좌우 대칭.
4. 묶음 7: GlyphBow·Bag·Map·Menu + 등급 칸 5(Common~Legendary) + 빈 칸(가방 BB7에 바로 쓰임).
5. 묶음 8·9: UIP_Star(흰색, 코드로 색), Item_PotionMP, 주문서는 흰 본체+띠(이미 있는 띠 마스크 방식), Weapon_{Warrior,Mage,Archer}_T8, Icon_Coin, Icon_Sprout, Icon_WantedStar.
6. 묶음 14 Q 스킬 아이콘 3(Z는 베타에서 꺼 둠 → 뒤로).
7. 묶음 10 직업 그림 9장 + 11a 안내자 초상 3장(사람 그림 — 한 장씩 단정함 확인, 사용자에게 먼저).
8. 묶음 12·13 추가 HUD·창 부품, 묶음 15·16 무기 T1~T6, 묶음 17 펫 배지·감정 스티커, 묶음 19 직업 그림 나머지 9.
9. 상점 NPC 최종 모습(물약 상인·장비 상인, 블록 아바타 스타일, 단정한 옷).
10. 베타 필수 다음: **옷·방어구·액세서리**(정식 기능용 아이콘과 직업 옷 디자인 시트), 새 사냥터 몬스터 콘셉트(3D는 Tripo 유료라 검수가 사용자에게 먼저 물음), 그 밖에 빠진 작은 그림을 찾아 검수에게 목록으로.

## 상태 기록
- 멈출 때 `docs/handoff/image_gen2_status_2026-10-06.md`(새 날짜면 날짜만 바꿔서)에 끝난 것·커밋·남은 것·크레딧을 적는다.
