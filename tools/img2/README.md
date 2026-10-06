# tools/img2 — 이미지 생성 2 세션의 누끼·검사 도구

공용 도구(`tools/cutout_flat.py`, `band_mask.py`, `make_tileable.py`)는 고치지 않고 가져다 쓴다(이미지 생성 1 소유).

- `cut_keep.py <src> <out> --long 512 [--holes --keep-largest --check sheet.png --game-h 60]` — 비율을 지키는 누끼(카드·판·리본·버튼). 1px 떠 있는 점은 `--keep-largest`로 지움.
- `cut_icon.py <src> <out> [--holes --keep-r 4 --fill 0.86 --check sheet.png]` — 정사각 아이콘 누끼 + 본체에서 떨어진 조각 제거(`--keep-r`: 진한 본체에서 R px 밖의 반짝이 조각을 지움). 조각이 여러 개인 그림(퀘스트 마커)에는 쓰지 말고 `tools/cutout_flat.py`를 쓴다.
- `cut_slot.py <src> <out> [--canvas 512 --body 440 --top 40]` — 등급 칸 형제들을 같은 본체 자리(36,40,476,480)에 맞춤. 안쪽 어두운 칸 사각형을 출력.
- `measure_card.py <card.png> faction|class halo|horns|artisan <overlay.png>` — 빈 카드의 글자 칸(이름·설명·구호·특성·버튼 / 초상·이름·본문·버튼)을 분수 좌표로 잼.
- `zoom4.py <img> <out> x,y,w,h ...` — 4배 확대(남색·자홍·흰 바탕) 가장자리 검사.
