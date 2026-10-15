# 개인정보 삭제 요청 처리 (BB40, 게임성 개발 2, 2026-10-15)

Roblox가 'Right to Erasure'(삭제 요청) 메시지를 보내면, 그 안의 **userId** 한 사람의 데이터를 모든 저장소에서 지운다. 보통 30일 안에 처리해야 한다.

## 준비 (한 번만)
- Creator Hub → Open Cloud → API Keys에서 이 게임(universe 10769445522)에 **DataStore(읽기·쓰기·목록·삭제, Ordered 포함)** + **Memory Store** 권한이 있는 키를 만든다.
- 키는 git에 안 올라가는 `.env`에 `ROBLOX_OPENCLOUD_KEY=...` 한 줄로만 넣는다. 채팅에 붙여 넣지 않는다.

## 처리
1. 미리보기(아무것도 안 바뀜): `py tools/erase_user.py <userId>`
   - 무엇을 지우고 고칠지 한 줄씩 나온다. `DEFERRED` = 그 사람이 거래소에 올려 둔 물건이 아직 팔리는 중(끝나면 다시 실행).
2. 실행: `py tools/erase_user.py <userId> --yes` (되돌릴 수 없음)
   - 다른 사람 저장 안의 흔적(약탈 쿨다운·거래 횟수·주간 PvP 상대)까지 지우려면 `--scan-saves`를 붙인다(모든 저장을 읽어서 느림).
3. 마지막 줄 `skipped` 가 0이 아니면(그 사이 게임이 같은 칸을 저장함) 같은 명령을 한 번 더 실행한다.
4. 처리한 날짜와 userId만 따로 적어 둔다(이름·내용은 적지 않음).

## 지우는 것 (Dev / Beta / Live 세 환경 모두)
| 저장소 | 무엇 |
|---|---|
| HaloHorns_Player_v1 `P_<id>` | 그 사람 저장 전체 삭제 |
| HaloHorns_NotifyAsked_v1 `<id>` | 알림 동의 물어본 기록 삭제 |
| HaloHorns_GrudgeMail_v1 | 그 사람 우편함 삭제 + 다른 사람 우편함 속 그 사람이 보낸 편지 삭제 |
| HaloHorns_Nicknames_v1 | 이름 목록 + 예전 이름 표까지 모두 삭제 |
| HaloHorns_Supporters_v1 | 후원자 목록에서 그 사람 줄 삭제 |
| HaloHorns_Market_v1 | 거래 기록의 구매자/판매자 칸을 0으로(끝난 거래만; 진행 중인 판매는 DEFERRED) |
| HHMktSold (Memory Store) | 판매 알림 대기 줄 삭제 |
| HH_Rank_… (주간 랭킹, Ordered) | 모든 시즌·판·주의 그 사람 줄 삭제 |
| HH_RankSettle_… | 주간 정산 기록에서 그 사람과 그 순위 삭제 |

숫자만 모으는 저장소(Health, Errors, Switches, TestMetrics, VillageFund, News)에는 userId가 없다.
시험: `py tools/test_erase_user.py`(가짜 Open Cloud로 전부 확인, 네트워크 없음).
