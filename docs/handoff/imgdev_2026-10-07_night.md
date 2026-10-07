# 이미지 개발 인계 2026-10-07 밤
1. HUD 새 배치(A23-74)는 **main 4f20a8bb**: 폰 엄지 고리(공격 둘레 HP·MP 물약·Q·Z·X), 아래 가운데 묶음(조이스틱 쉼 0.2W와 고리 사이 가운데, 누르는 것 0.3W 밖), [Menu] 위 버튼 줄, PC 아이콘 6칸+물약 한 덩어리 가운데, 좁은 폰 'Lv 25 · 249', 힌트 말풍선 안 잘림(TextBounds·줄 높이 1.4), NEW! 표는 얇은 줄 오른쪽 옆(진영 막대 안 가림). 증거: UiSandbox 사진 검사 55/55 `art/review/hud_frame_2026-10-07/`, 오프라인 54/54. **다음: 개발 1이 main을 메인 Studio에 동기화하고 PC·폰 Play 사진(A23-74 규칙).**
2. 오늘 올린 것: 지형 FF2 9장(30e3d3e), 몬스터 말풍선 12장(270b9c3e — bark2 합칠 때 그 12줄은 main 쪽 유지), 몬스터 텍스처 3장(Slime 71253753467123 · BigSlime 75055792951510 · PumpkinSlime 100144323661916; 개발 1이 메인 Studio에 바꿈, apply_studio_state.py 상수는 개발 1 가지 fix-prompt-locale 2f87076).
3. 남은 일: 알림 그림 확인 2개(폰 보상 토스트 두 줄, 빈 Id 대체 모양), Z·X 스위치가 켜지면 고리 사진(Studio 미리보기 SkillBarPreview), 메인 사진에서 어긋나는 곳 고치기. 확인 도구 `py tools/hud_frame_view.py [pc] [phone] [844]`(UiSandbox 전용, 끝나면 Play 멈춤·기기 흉내 default).
4. 작업 폴더: Game-imgdev(가지 imgdev-hud-wip = main과 같음). Game-imgdev-bark는 끝난 임시 폴더 — 지울 때 먼저 `cmd /c rmdir build`(공유 build 연결만 끊음, /s 금지) 뒤 `git worktree remove`. UiSandbox는 닫음(저장 안 함, 남길 것 없음).
5. 규칙: 기기 흉내는 UiSandbox만·끝나면 default, 창·Play 전 검수 "전달함, 시작", 업로드는 창이 최소화가 아닐 때(최소화면 느려서 시간 초과).
