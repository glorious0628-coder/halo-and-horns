# 남은 아바타·무기 로컬 조사 (2026-10-04)

> 기록용(2026-10-09 검수): 2026-10-04 조사 기록이다. '남은 16종 아바타'는 치비 코스튬 제거(SPEC A23-5)로 그만뒀고, 손에 든 무기는 지금 docs/design/remake_list_2026-10-09.md P3(A23-96) 기준이다.

기존 소스·Studio·API·업로드·승인 기록은 변경하지 않았다. 아래 목록은 준비 파일이며 완료/승격 승인이 아니다.

**HANDOFF 기준 게임용 2/18종, 남은16종. 무기 PNG 아이콘27개/새 ID27개는 존재하고 Config와 일치한다. 로컬 최종3D무기 파일 확인0개다.**

자세한 절대 경로·현재 SHA256·GPT 원본/프롬프트·manifest 기대 SHA 일치는 `remaining_asset_inventory_20261004.json`에 기록했다.

## 남은16종

| 순서 | 아바타 | 원본 GLB | 표정3PNG | 연속skin후보/별도 보류 |
|---:|---|---|---:|---|
| 1 | Costume_NeutralWarriorM | Costume_NeutralWarriorM.glb | 3 | 원본보존/cap 이후 union 후보는 별도 검토 |
| 2 | Costume_NeutralMageM | Costume_NeutralMageM.glb | 3 | 원본보존/cap 이후 union 후보는 별도 검토 |
| 3 | Costume_NeutralMageF | Costume_NeutralMageF.glb | 3 | 원본보존/cap 이후 union 후보는 별도 검토 |
| 4 | Costume_HornsWarriorF | Costume_HornsWarriorF.glb | 3 | 얼굴·머리 웨이트 교정 후보 있음, 최종 얼굴 원본 선택 대기 |
| 5 | Costume_HornsWarriorM | Costume_HornsWarriorM.glb | 3 | 얼굴·머리 웨이트 교정 후보 있음, 최종 얼굴 원본 선택 대기 |
| 6 | Costume_HaloWarriorF | Costume_HaloWarriorF.glb | 3 | 얼굴·머리 웨이트 교정 후보 있음, 최종 얼굴 원본 선택 대기 |
| 7 | Costume_NeutralWarriorF | Costume_NeutralWarriorF.glb | 3 | 원본보존/cap 이후 union 후보는 별도 검토 |
| 8 | Costume_NeutralArcherM | Costume_NeutralArcherM.glb | 3 | 원본보존/cap 이후 union 후보는 별도 검토 |
| 9 | Costume_HaloArcherF | Costume_HaloArcherF.glb | 3 | 원본보존/cap 이후 union 후보는 별도 검토 |
| 10 | Costume_HornsArcherF | Costume_HornsArcherF.glb | 3 | 원본보존/cap 이후 union 후보는 별도 검토 |
| 11 | Costume_HaloMageM | Costume_HaloMageM.glb | 3 | 허벅지 색띠가 피부인지 스타킹인지 업로드 전 직접 검토 필요 |
| 12 | Costume_HornsMageM | Costume_HornsMageM.glb | 3 | 원본 위팔 바인드·모션 문제, 별도 바인드·얼굴 웨이트 교정 증거 필요; 별도교정 후보 있음 |
| 13 | Costume_HornsMageF | Costume_HornsMageF.glb | 3 | 머리카락·코트 끌림, 승인된 별도 교정 후보 선택 필요; 별도교정 후보 있음 |
| 14 | Costume_NeutralArcherF | Costume_NeutralArcherF.glb | 3 | 땋은머리 v7 교정 후보 있음, 별도 원본 계약과 맞는 얼굴 후보 필요; 별도교정 후보 있음 |
| 15 | Costume_HornsArcherM | Costume_HornsArcherM.glb | 3 | 망토·얼굴 웨이트 교정 및 입 union/winding 후보의 별도 정확한 계약 필요; 별도교정 후보 있음 |
| 16 | Costume_HaloMageF | Costume_HaloMageF.glb | 3 | 단정함 검토 보류: 짧은 치마·피부색 허벅지 띠, 업로드 전 루트 확인 필요 |

기존 `build/remaining_16_costumes_20261004_v2/index.json`은 원본/cap 준비 목록이다. PASS_EXACT_CANONICAL은 최신 mouth-union/winding/교정 후보의 승인이나 실제 등록을 뜻하지 않는다. 후보별 SHA와 각 예외 계약을 확인해 루트가 최종 파일을 정해야 한다.

HornsMageF는 머리 표정 파일과 별도 교정 skin만 있으며 기존 index의 연속표정 manifest가 없다. HornsArcherM도 최신 union/winding GLB는 있지만 일반 skin manifest가 없다. NeutralArcherF의 기존 index gate는 REFUSED다. 임의로 일반 원본 경로에 합치면 안 된다.

각 모델의 GPT 원본 직업 그림·APose·Tripo 원본 task id와 세 표정 PNG의 builtin GPT 생성출처/프롬프트를 연결했다. 이 조사에서는 그림을 직접 보거나 사용자에게 표시하지 않았으며 업로드 허용 표시도 만들지 않았다.

실제 사용 전 루트의 한 장씩 확인·사용자 표시→최대9에셋 한 모델 Import→실제 ID/Bone/축/크기→별도 Pending/BindingSchema1→Native 표면·표정·F/Q·걷기/점프·성장·ON/OFF·사망 검증→승격이 필요하다.

## 무기27종

전사·마법사·궁수 각각 T1~T6와 T7_Halo/Horns/Neutral의9종이다. `art/out/Weapon_*.png`와 `art/ui/Weapon_*.png`는27개 모두 바이트가 동일하다. 원본 생성 로그/프롬프트/새 ID/Config 연결은 JSON에서 개별 확인할 수 있다.

현재 `CharacterVisuals.luau`의 buildSword/buildStaff/buildBow가 Part로 임시 무기를 만든다. 최종무기 GLB/FBX/OBJ 등은 `art/models/**`와 `build/**`에서 이름 기준으로0개 확인됐다. 아이콘이 실제3D모델이라고 집계하지 않는다.

개별27무기 디자인 승인키는 `art/approved.json`에 없고 HANDOFF의 원본 아이콘 연결완료 기록이 있다. 별도 무기 유료3D제작 승인 기록은 확인하지 못했다. 이 조사에서 API0/업로드0/Studio호출0이며 새 유료실행을 하지 않았다.
