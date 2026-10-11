# 게임성 개발 2 — 상태 (2026-10-11, 세션 새로 열기 인계)

서버 전용(개발 3 휴식 → 서버는 개발 2 혼자). Studio 금지, main에 push 금지. 새 일 = origin/main에서 새 가지, worktree에서 pathspec 커밋.
검증·병합은 검수: 가지가 준비되면 검수에 "가지·커밋·시험 명령·결과 파일"을 보낸다.
시험은 동시에 3~4개까지만(PC 메모리). 변이 있는 긴 시험(test_a23_14 20~40분)은 혼자, 되도록 복사본 폴더에서. 시험이 덮어쓴 docs/art/verification_* 보고서는 `git checkout -- <파일>`로 하나씩 되돌린 뒤 커밋.

## 병합 끝(10/10~11)
quickslot, daycycle(+ZoneLook), firstko(b031b67d), hint(cc7ea4bd), skillq(515a1207).

## 검증 기다림
1. **친구 PvP 0(A23-113 ①)** — origin/dev2-friendpvp = 29c0aad5 (worktree Game-dev2). 기능 eb623013 + 검토 시험 보강(3건 끝, 커밋됨) + main 병합. 커밋 안 된 것 없음.
   - PvPService FRIEND 캐시(접속 때 IsFriendsWith 한 번, pcall, 실패·모름 = 친구 아님, 나가면 지움) + AreFriends + CanAttack "Friend"(괴수 예외보다 먼저), CombatService.DamagePlayer 최종 관문, KaijuService 발구르기·countNearbyHalo에서 친구 뺌. RankingService 그대로.
   - 시험: `py tools/test_friend_pvp.py`(95 체크·18 정적·22/22). 관련 31묶음 통과(eb623013 때, 하나씩): ranking, kaiju_town, skills, skills_x, swing_aim, grudge, town_quests, board, unarmed_start, tamer, first_ko_king, first_ko 등.
   - 결과 파일: docs/art/verification_2026-10-11/offline_dev2_friend_pvp_2026-10-11.json
   - 검수 판단 거리: 괴수 체력·'맞붙음'에서 친구를 뺀 것(친구는 괴수를 못 때리니까), 친구 답 오기 전 몇 초 안의 KO는 평소처럼 처리(순위는 원래 제외).

## 다음 큐(순서)
2. 필드 보스 체력 = 근처 사람 수(A23-113 ③): King·클래터 대장만(호박 대왕 빠짐, A23-119). 혼자 약 2분(Lv5~8, 1~2단계 무기), 둘레 1명당 더함(괴수 +15% 방식), 기여 보상 규칙 그대로.
3. 바닥 그림자 원(A23-113 ②): King 착지(+클래터 대장 큰 공격) 약 1초 전 원, 원 밖이면 안 맞음(서버 판정), 위치·시간은 클라로(개발 1 그림). KO1 1단계 개인 King은 따라 뛰어 결국 맞힘, 재대결은 원 피하면 이김(FirstKOService·MonsterService landAttack 위에).
4. 개발 3 인계분: origin/dev3 0e1ed92c `docs/handoff/dev3_to_dev2_2026-10-11.md` §3 — 한국어 모드 서버(A23-111, 빛 마을 뒤 + 개발 1 계약 먼저), 선택 거리 켜기 판단(Board·잃어버린 물건·킬 카드, 클라 창 먼저), 10/17 시험 뒤 지표 보기, 새 구역 몬스터 표. 같은 문서 §2: PvPService가 PlayerKO info.Stolen을 바꾸면 개발 3 쪽 SackMet이 읽음.
5. 걷는 바닥 태그 서버(검수 큐, 자세한 건 검수에게).
- 나중: 장인 서버(채집·제작·장비 칸·물약·펫 연구)는 빛 마을 끝난 뒤. 작은 것: PetService onEquip이 거절(조련사·0.5 s·준비 전)될 때도 PetList 한 번 보내기(개발 1 보고).
- 사용자 결정 기다림(A23-116 공정 1·2): 빛 자기 회복 상한 3%/3초, Q 치유 중심 = 나 기준 12칸 → 정해지면 CombatService.SKILL.Heal / Config.BasicSkill.HaloHealCapPct.
- IDEA-TITLE 칭호 쌍 초안: 공유 노트 dev2_idea_title_draft_2026-10-09.md, 검수 확정 대기.

## worktree
Game-dev2 = dev2-friendpvp(위), Game-dev2-ci = dev2-skillq(병합됨, 다음 일에 재사용), Game-dev2-hint = dev2-hint(병합됨), Game-dev2-pet = dev2-quickslot(병합됨). 각 worktree에 build/luau_cli_0_741 있음(hint는 복사본).

## 참고
- 하루·날씨 계약: 공유 노트 dev2_daycycle_zonelook_contract_2026-10-10.md. 긴 기록: 공유 노트 dev2_handover_2026-10-09_night.md.
- 서버 글은 Config 글 표에서 키로(이어 붙이기 금지, 이름은 Name/Short/Title) — A23-111 대비.
