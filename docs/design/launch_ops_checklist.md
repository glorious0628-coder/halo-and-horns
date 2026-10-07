# 게시(Publish) 체크리스트 — 검수 관리 (2026-10-08 시작)

게시는 **사용자 OK 뒤에만** 한다(AGENTS 규칙 3). 아래 줄은 그 게시에 들어가는 묶음마다 확인한다.

## 이번 묶음: 무기 먼저(A23-74) + 스탯 1단계(스위치 꺼짐) + 소리 서버
- [ ] **모든 서버 종료**: TutorialStep 3(대장간 단계)을 쓰는 저장을 옛 빌드가 읽으면 3을 99로 바꿔 첫 임무를 건너뛴다(dev2 검토 minor 1, `docs/design/weapon_first_server_2026-10-07.md` §6). Creator Dashboard → 체험 → 서버 → "모든 서버 종료"는 사용자가 누른다.
- [ ] dev2-sound와 wtc-weapon-client가 **같은 라운드**에 들어갔는지(따로 들어가면 새 플레이어가 대장간 단계에서 길을 잃음).
- [ ] 저장 Version은 3 그대로(스탯 Stats는 더하기 필드).
- [ ] 메인 Studio에서 PC·폰 직접 Play 사진: 진영·직업 → 대장간 앞 착지 → 모루 → 첫 무기 → 초원 → 슬라임 5 → [Claim] 150골드(A23-74 검사 규칙).
- [ ] place/GoodEvil.rbxlx = build/GoodEvil.rbxlx(시간·해시), src와 같은지.
- [ ] 화면 글자 한글 0개: `py tools/test_place_english.py`(30ccc2d 고친 판).
- [ ] Creator Dashboard 한국어 자동 번역 끄기(사용자).
- [ ] Config.Features.StatPoints = false(스탯 2단계 검토 전)인지.
- [ ] 새 계정 흐름 세부(개발 2): [Accept] → 3초 페이드 → 교차로 모루 앞 착지 → E/탭 → "Otto: …" + 첫 무기 Power 0 → N(Stronger!) → 3초 뒤 초원 → 슬라임 5 → [Claim] 150골드 → M1_1 대장간에서 상점 창. 착지가 이상하면 Config.Tutorial.Forge.Landing = "Spawn".
- [ ] `py tools/test_place_english.py --place build/GoodEvil.rbxlx` passed(자체 시험 포함).
- 문서: dev2-sound 892fa28에서 stat_points·stats_server의 버전·서버 종료 문구 정리됨.
