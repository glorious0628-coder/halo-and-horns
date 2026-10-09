# 이미지 개발 인계 2026-10-07 저녁

> 기록용(2026-10-09 검수): 10/07 저녁 기록이에요. 메인 Studio에 넣기는 개발 1이 아니라 지금 '메인 반영 1' 몫이고, 할 일은 `docs/handoff/role_prompts/05_imgdev.md`예요.

1. 지형 타일 9장(Tex_*_FF2, 검수 OK, 직접 확인·2×2 이음새 OK): `art/ui/Tex_*_FF2.png`에 올려 둠. 업로드는 MCP 120초 시간 초과로 **결과 모름**(`build/ui_upload_662807b578a56df31995.json`, ledger inflight 9개). Chrome 확장이 끊겨 Creator Hub 확인 못 함 → Creator Hub에 Tex_*_FF2가 있으면 그 id로 `--record-result`, 없으면 inflight 9개 정리 후 `STUDIO_MCP_TIMEOUT=600`으로 한 장씩 다시(`build/terrain_ff2_batch.json`, Tex_Slate ← RuinsFlagstone). Config Tex_* id는 아직 옛것 → 바꾼 뒤 개발 1에 apply_surface_materials 알림.
2. HUD 새 배치(A23-74)는 가지 `origin/imgdev-hud-wip`(워크트리 Game-imgdev, main 위 커밋 1개): 폰 엄지 고리(공격 둘레 HP·MP 물약·Q·Z·X, 한 덩어리로 작은 폰에서도 60du), 아래 가운데 묶음, [Menu] 위 줄, PC 아이콘 6칸+물약 붙여 가운데, 좁은 폰 'Lv 25 · 249', 알림 그림(Toast/BannerAlert), FullMerchantC 삭제, VitalsUI.PlacePotions Cells. 오프라인 검사 통과(54/54), 사진 `art/review/hud_ring_2026-10-07/`.
3. 남은 HUD 고침(검수 10/07): ③ 힌트 말풍선 글자 잘림("Tap the new buttor") — HUD `L.PlaceHint`/TextW0(UIKit.MeasureText) 대신 TextBounds로 재서 절대 안 잘리게. ④ 폰 749 아래 묶음을 조이스틱(≈0.2W)과 고리 사이 가운데로: 폭 = limit − 0.4W, left = 0.2W + (limit − 0.2W − 폭)/2, 누르는 것은 0.3W 밖(검사 STICK도 0.3W로).
4. 그다음: 고친 사진 시트(PC·749·844) → 검수 → main에 push → 개발 1이 메인 Studio에 넣음. 알림 그림 남은 확인 2개(폰 보상 토스트 두 줄, 빈 Id 대체 모양).
5. 규칙: 기기 흉내는 UiSandbox만·끝나면 default, 창·Play 전 검수 "전달함, 시작", 작업은 Game-imgdev 워크트리(build/는 공유 폴더 링크).
