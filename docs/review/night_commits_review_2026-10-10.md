# 10/09 밤 커밋 검수 (검수 워크플로 wf_bf75d850-1af, 2026-10-10 아침)

검사관 1 + 반박 1씩. 결과:

| 커밋 | 무엇 | 판정 | 고칠 것 → 담당 |
|---|---|---|---|
| e8c3bc31 | 출시 운영표 연결 + test_pet_speed 변이 패턴 | 통과 | — |
| a2c30908 | 펫 창(PET-5) | 통과(작은 것) | XP만 바뀔 땐 막대만 갱신(누르던 버튼이 사라짐), XP 글자 13 → 15+, 쉬는 펫 'Walk speed' 문구 → 개발 1. UiIds에 Pet·Diary → 개발 3 |
| 0efa4259 | 빛 마을 3단 분수 FountainFx | **고쳐야 함** | 새 분수 표시가 build_kit_from_ids로는 안 생김 + 'Town_Halo_Fountain'은 메인에서 교차로 분수 이름(--replace하면 교차로에 빛 마을 분수, A23-96 위반) → 새 키트 이름(예 Town_Halo_Fountain3) + SPECS 키, 분출 Jet가 금공 안 → 개발 1·이미지 생성 1 |
| 798d4003 | 건강 보고 서버 | 통과(작은 것) | 치장 패스 퍼널 키, 클라 지표 시간당 한 번, GooseRewarded Mode, 읽기 전용 DebugCommand 오염 표시 → 개발 3 |

시험은 검사관이 직접 돌림(test_pet_window 29·변이 14/14, test_fountain_fx 18·변이 10/10, test_health 147·변이 121/121, test_pet_speed 40·변이 15/15). 덮어쓴 보고 파일은 되돌림.
