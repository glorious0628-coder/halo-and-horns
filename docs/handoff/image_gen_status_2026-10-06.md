# 이미지 생성 인계 상태 (2026-10-06 10:30, 사용자 지시로 멈춤)

- 요령은 `docs/design/image_session_handoff_2026-10-06.md`(1,024자 제한, 1280×900 창, `cutout_flat.py --holes`·가장자리 정리, `band_mask.py`, JS 대기열 `__setPrompt`/`__gen`). 크레딧 사용 0(전부 중간 품질).
- **끝·이미지 개발에 넘김:** 메뉴 5(8875c87) · 재료 6 + IconCharacterF(5fa385b) · 몬스터 머리 5 · 주문서 2+띠 마스크 · 랭킹 탭(9fc955c, 3b24812, 79ccaae, bd5f456 PvP 다시) · 묶음 3 특성 10(2da3a4d, e7aff22 하트 다시). 이미지 개발이 업로드·적용 중(938c230 등).
- **승인 대기:** 묶음 1 스타일 보드 `art/review/styleboard_b1_preview.png` — 추천 창 1·버튼 2·희귀 칸 크림·검 1·물약 1, 빛 전사는 블록 아바타 B2(`art/review/styleboard_b1_knight_blocky.png`). 원본 `art/out/styleboard/`(미커밋). 사용자 "좋아" 받으면 approved.json·커밋·전달.
- **그리던 것(묶음 6):** 문구 `art/prompts/UIP_{PortraitRing,MinimapFrame,BtnAttack,BtnSkill,BtnPotion,LevelBadge,LevelBadgeHalo,LevelBadgeHorns,LevelBadgeArtisan}.txt`. 받은 원본 `art/out/b6/`: PortraitRing_1·2, MinimapFrame_1·2, BtnAttack_1(누끼·검사 전). 나머지는 미생성.
- **써 둔 문구(묶음 2, 옛 그림 참조 없음):** `art/prompts/UIP_FactionCard{Halo,Horns,Artisan}.txt`, `UIP_FactionTitle/Premise/Footer.txt`, `UIP_ClassCard{Halo,Horns,Artisan}.txt`. 뿔 카드는 귀여운 뿔 투구 문장(B안)으로 씀.
- 주의: `UIP_BtnAttack/ClassCardHalo/ClassCardHorns/LevelBadge/PortraitRing.txt`는 옛 추적 문구를 새 문구로 덮음(옛 내용은 git 기록).
- **다음 순서:** 묶음 6 나머지 생성·누끼(얼굴 링 가운데 --holes 확인) → 시트 → 이미지 개발 → 묶음 2 → 4·5 → 7~21(모두 베타, A23-25). 사람 그림은 업로드 전 사용자에게 꼭 보여 줌.
- 커밋은 `git commit -m … -- <경로>`만.
