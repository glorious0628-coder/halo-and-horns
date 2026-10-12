# 게임성 개발 2 — 상태 (2026-10-12 저녁 정리)

## 10/12 저녁 정리 (사용자: "모든 세션 여기까지만 하고 정리")
- 새 결정 A23-152: 베타 7구역(빛·뿔·장인 마을·교차로·슬라임·고블린·해골), NewZones는 베타 뒤,
  **거위 광장 = 교차로 쌍둥이, 거기선 거위 게임만**(서버 계약 workspace.GooseSquare 그대로).
- **fix/goose-square-floor 448b72ff**(origin/main 기준): 바닥(보이고 밟히는 Floor/StandInFloor) 없는 GooseSquare 모델엔 임시 바닥 추가,
  Join 때 광장 없으면 먼저 만듦, 만들 때 로그 한 줄. test_goose_square 91/91·변형 51/51. **최종 검수 시험 중.**
- 거위 광장 '하늘색/회색 허공': 메인 반영 1 읽기 → 서버 바닥 정상(6000,198,6000, 투명 0, 밟힘, 경고 없음). 그런데 Leave 뒤 마을 사진(04)도
  화면 전체 회색 → 광장 아닌 순간이동 뒤 **클라이언트 화면** 문제로 추측. 메인 반영 1에 클라이언트 읽기 부탁함(카메라 Type/Subject/CFrame/Focus,
  HRP, Lighting 안개·효과, 전체화면 GUI) + Lunchbox 카드 닫은 사진. **결과 기다림** → 범인 따라 개발 1(클라이언트) 또는 나.
  사진: docs/art/verification_2026-10-12/main_apply/goose_square2/.
- **C2 = dev2-c2 f1a2cbe9 (push함, 아직 보고 안 함)**: 491ef614(드롭표 다시 맞춤, FirstWeaponDrop BigSlime T2, 겹친 무기 → AddSpare + SpareWeapon,
  DuplicateWeaponGold 15/80, LootFlags.FirstWeapon) + main 병합. test_loot --no-mutations 574 통과. **전체 시험은 중간에 멈춤 → 다시 돌리고**
  실패(new_zones 무기 줄 비교, 경제·첫 10분 시험 등) 고친 뒤 숫자와 함께 최종 검수 보고. A23-152로 NewZones 몬스터 줄은 베타 뒤라 그대로 둠.
- 열린 가지: fix/goose-square-floor, dev2-c2, dev2-bubbles c1c70fce(개발 1 스티커 화면과 병합 대기), fix/lesstext-server 8c8dc44d(병합 확인 안 함).
- worktree: wt_goose_square(fix/goose-square-floor), wt_c2(dev2-c2), wt_stickers, wt_c1, wt_famecap, wt_lesstext_server(병합된 것 지우기).

서버 전용·Studio 금지·main에 코드 push 금지(검수가 병합). **보고처 = '최종 검수'**(10/12 게임성 검수 쉼; id는 list_sessions).
보고는 묶음마다 한 번. 대화가 길어지면 이 파일 적고 push → clear_session("self").
- **API(api_agent) 거의 바닥(10/12 남은 약 $22, 최종 검수: 최종 병합 검토용으로 남김) → 큰 일도 앱에서 직접.** 충전되면 최종 검수가 알림.
  도구 버그 고침: edit_file이 파일 전체 크기를 쓰기 한도에 세던 것 → main 476362b(새 글만 셈).

## 보고함 / 검토 대기 (최종 검수)
- main에 들어감(10/12): C1(9단계·v4·Spares), fix/fame-cap, fix/c1-minor(보스 재료 Feature Crafting, v3 마스크 band, gear_slots 식),
  dev2-stickers(스티커 패스 99·SendSticker). dev2-bubbles c1c70fce(말풍선 패스 99·진영 무료·SetBubble·BubbleOn) = 개발 1 스티커 화면과 같이 병합 예정.
- **거위 광장 한 끝 = dev2-goose-square df4d3d47** (황금 알 1차 + 광장 서버 + main 74f1dd79 + 개발 1 fix/goose-square 합침).
  최종 검수가 API 반박 검토 → 병합 → 메인 반영 1 사진(Join·Leave·어두워짐·알 줍기·귀환). 큰 지도 = 개발 1(병합 뒤 한 줄).
- **fix/lesstext-server 8c8dc44d** — 강화 결과 토스트 5개 되살림 등(아직 병합 확인 안 됨).
- worktree: wt_goose_square·wt_stickers(dev2-bubbles)·wt_c1·wt_famecap·wt_lesstext_server — 병합되면 지우기.

## 다음 큐
1. **C2**: 드롭표 + 첫 Prince T2 + 중복 무기 → Spares(save_v4·crafting_market §3·§7). C1 병합 뒤.
2. 거래소 서버(C-5/C-7): 개발 4 계약 `origin/dev4-market` `docs/design/market_window_2026-10-12.md` §6 합의(MarketIndex 30초 캐시·요약 맵,
   무기 키 "T:P", Pages·Paid·Today, Gate { Buy, List, ListIn }, 거래소 퀘스트 3개는 내 몫, 거절 키 + TooFast·Off).
3. `api/dev2-l10n-a` 필수 시험·보완 → 병합 요청. 제작 설계 `api/dev2-crafting-design` ea0ce9bc 정리(A23-127).
4. 한국어 서버 B·C(알림 → NotifyKey 등). 5. A23-138 영어 밈 서버 쪽(fix/meme-en-server).
- 알아 둘 것: 개발 3이 내 파일에 넣은 줄 — 연금 물약 BuffService.Mult 4줄(Combat·Loot·Progression), 조련사 PetService(SummonPet·AddPetXP·
  PetRoll, findSpecies는 소환 펫 제외), 장비 api/dev3-gear(gearAtk/gearHp/petGear/gearOf + GearRem 펫 XP 나머지) — 모두 검토 OK.
  보스 재료도 행운 물약에 오름(빼려면 `def.Source == nil`, 게임성 검수 결정 대기). WeekCap.Artisan 100(개발 3, OK).

## worktree·도구
- 가벼운 worktree: `git worktree add --no-checkout -b <가지> ../wt_<이름> origin/main` → `MSYS_NO_PATHCONV=1 git sparse-checkout set
  --no-cone /src/ /tools/ /docs/ /AGENTS.md` → `git read-tree -mu HEAD` → `cp -r ../Game/build/luau_cli_0_741 build/`.
  worktree 안에서 `git commit -m … -- <경로>`. 지금 내 worktree: wt_lesstext_server, wt_goose_square.
- 고치기: 스크래치에 python 정확 치환 스크립트(CRLF 맞춤: 파일에 \r\n 있으면 옛·새 글도 \r\n). heredoc 안 `\n` 주의.
- 전체 시험: 스크래치 run_all_tests.py `<worktree> <outdir> <동시 수> [시험 이름…]`(a23_14는 --no-mutations). **시험 도는 중엔 그
  worktree 파일을 고치지 말 것**(sourcesChangedDuringRun 실패). 커밋 전 `git checkout -- docs/art`.
- 원래 있던 실패: costume_physics·skin_binding(은퇴), halloween·shop_layout(그림 필요), place_english(place 필요), rank_marks,
  ops_safety 변이 "Halloween is not applied".
