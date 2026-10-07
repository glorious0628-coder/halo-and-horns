# tools/img2 — 이미지 생성 2 세션의 누끼·검사 도구

공용 도구(`tools/cutout_flat.py`, `band_mask.py`, `make_tileable.py`)는 고치지 않고 가져다 쓴다(이미지 생성 1 소유).

- `cut_keep.py <src> <out> --long 512 [--holes --keep-largest --check sheet.png --game-h 60]` — 비율을 지키는 누끼(카드·판·리본·버튼). 1px 떠 있는 점은 `--keep-largest`로 지움.
- `cut_icon.py <src> <out> [--holes --keep-r 4 --fill 0.86 --check sheet.png]` — 정사각 아이콘 누끼 + 본체에서 떨어진 조각 제거(`--keep-r`: 진한 본체에서 R px 밖의 반짝이 조각을 지움). 조각이 여러 개인 그림(퀘스트 마커)에는 쓰지 말고 `tools/cutout_flat.py`를 쓴다.
- `cut_slot.py <src> <out> [--canvas 512 --body 440 --top 40]` — 등급 칸 형제들을 같은 본체 자리(36,40,476,480)에 맞춤. 안쪽 어두운 칸 사각형을 출력.
- `measure_card.py <card.png> faction|class halo|horns|artisan <overlay.png>` — 빈 카드의 글자 칸(이름·설명·구호·특성·버튼 / 초상·이름·본문·버튼)을 분수 좌표로 잼.
- `zoom4.py <img> <out> x,y,w,h ...` — 4배 확대(남색·자홍·흰 바탕) 가장자리 검사.
- `hq_fit.py <old art/ui png> <new src> <out> --mode keep|icon|opaque [-- <cut options>]` — 고급(High) 다시 그린 그림을 게임에 있는 중간판과 같은 캔버스에 맞춤(비율 차이 3% 이하면 같은 크기로). 지금 그림과 겹침(IoU)을 찍어 모양이 바뀌었는지 봄.
- `measure_slice.py <part.png> [--kind panel|pill|ribbon|slot] [--blur 3 --tol 9] [--overlay o.png]` — 9조각 slice 재기. 가운데 줄과 같은 줄만 늘리는 칸에 넣어, 둥근 모서리·장식은 모서리 칸 안에 남김. 알약·리본은 (끝 폭, H/2-1, W-끝 폭, H/2+1). 나뭇결·코르크·광택은 `--blur 3 --tol 9`.
- `lum_alpha.py <src> <out> [--size 512 --center]` — 검은 바탕에 흰색으로 그린 빛무리·반짝이 → 흰색 + 밝기 = 알파(게임에서 ImageColor3로 칠함).
