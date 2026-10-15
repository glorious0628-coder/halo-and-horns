# 시험 숫자판 매일 뽑기 (10/17~20, 최종 검수용, 게임성 개발 2 10/14)
- 매일 저녁 한 줄(게임 Studio가 Edit로 열려 있고 'Studio에서 API 접근' 켬; 읽기만, Play 안 함 = 화면 안 씀): `HH_MAIN_STUDIO=1 py tools/test_metrics_board.py --studio --save build/test_metrics_PT1_1017.json --out build/test_metrics_PT1_1017.md` (날짜만 바꿈; Creator Hub 퍼널 CSV가 있으면 `--hub 파일.csv` 추가).
- 첫 화면 통과율 = '첫 화면' 표 '진영 고름' 비율(새 계정 기준, 인트로 끝 수도 같이).
- 10분 완주율 = '10분 완주' 표 '셋 다' 비율(Lv5 + 첫 드롭 무기 + 첫 미션 Claim을 플레이 10분 안에).
- Lv5까지 분 = '합격선' 표 'Lv5 5분 이하' 줄의 중간값(합격 5분; Lv10 15분·첫 무기 4분도 같은 표). 2배 XP가 너무 빠르면 EarlyXP 값 결정 근거.
- 폰 프레임·메모리 = '기기 성능' 표 Phone 줄(평균 FPS·가장 낮은 초·메모리 MB·끊김 비율; 10/15 추가).
- 패스 구매 = '패스' 표 '삼'; 재접속 혜택 = 같은 표 '유지율'(다시 들어오고 20초 뒤 Roblox 답). 100% 아니면 사고, '확인 못 함'만 있으면 다시 접속해 봄.
- 0명이면: 시험 전 `--studio --studio-copy`로 길 확인, 그래도 0이면 Health live의 Joins·ServerError 비교. 뜻·예외 전부: `docs/design/test_metrics_2026-10-13.md`.
- 10/14 점검: main 89255e8b에서 `test_test_metrics.py` 69/69·변이 46/46, 숫자판 `--json`+`--hub` 가짜 문서로 표 6개 정상, `--print-luau` 정상(인자 없이 = 도움말 rc 2, 시험 아님).
