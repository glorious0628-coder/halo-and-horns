# 무기 9종 × T1~T3 후보 현황 (이미지 생성 2, 2026-10-11 저녁)

## 결론
- **(오늘 오전까지) 새 그림체 후보는 27칸 모두 없었음 → 저녁에 27장 생성.** 그 전에 있던 것은 ① 9종 '고급 앞·뒤·옆' 최종 룩(`art/out/s2/weapons/Weapon_<키>_{front,back,edge}_HQ_src.png`, 단계 T1~T3가 아니라 완성형 한 벌), ② 옛 일반(진영 구분 없는) T1~T6 아이콘 `art/out/s2/Weapon_<Warrior|Mage|Archer|Tamer>_T#_cut.png`(2026-10-06 승인, 옛 그림체 → 'old images redrawn' 대상).
- 대장장이·연금술사는 옛 T1~T3 자체가 없음(직업이 새로 생김, A23-39/127).
- 전사 두 진영은 **한손검만**(A23-128). 옛 `Weapon_Horns_Berserker_front_HQ`는 대검이라 쓰지 않음(뿔 전사 T3 이상 최종 룩도 한손검으로 다시 그려야 함 → 검수 결정 필요).
- 프롬프트 27개 준비됨: `art/prompts/Weapon_<키>_T<n>.txt`(<1000자, 참조 없음, Medium). 생성기 `tools/_weapon_t13_prompts.py`.
- Firefly 로그인 뒤(저녁) **27장 Medium(0크레딧) 생성 완료**. 파일 `art/out/s2/weapons_t13/Weapon_<키>_T<n>.png`(1024², 회색 배경), 시트 `art/review/s2/weapons_t13_{warrior,mage,archer,neutral}.jpg`. 100% 크롭 확인(손잡이·머리·활 끝·끈): 조각 깨짐·구멍·떠 있는 조각 없음, 레이 없음, 글자 없음.
- 공통 판정: HQ 9종(장난감 통통)보다 **현실적·가는 결**(특히 빛/뿔 T3 검·활). 고급(High)으로 올릴 때 HQ 앞면 시트를 참조로 걸어 통통하게 맞추길 권함.

## 벤치 B left2 (등불·벤치 재작업)
- 시트 `art/review/s2/halo_benchB_left2_cands.jpg`: 참조 없이 Medium 4장(m1~m4) = 모두 불합격(조각이 떠 있거나 분리). **앞면+right2 합성 참조를 건 Medium 2장(r1,r2)** = 화분이 앞, 뒤 기둥·등받이, 좌석이 받침 위에서 옆으로 나온 진짜 옆면. **r2 추천**(등받이 곡선·좌석 다리 보임). 파일 `art/out/s2/halo/props4/HaloProp4_BenchB_left2_{r1,r2}.png`. **High 1장(5크레딧, 검수 OK) 완료: `HaloProp4_BenchB_left2_HQ.png`**(r2 구도, 참조 = 앞면+right2 합성). 시트 `art/review/s2/halo_benchB_left2_HQ.jpg`(왼 right2, 오 새 left2). 내 판정: 화분 앞·기둥 금 공·등받이 뒤·좌석이 마블 받침 위, 떠 있는 조각 없음 → 통과.

## 27칸 표

| 칸 | 새 후보 | 프롬프트 | 옛 일반 T# (옛 그림체) | 내 판정 |
|---|---|---|---|---|
| Halo_Paladin T1 | `art/out/s2/weapons_t13/Weapon_Halo_Paladin_T1.png` | `art/prompts/Weapon_Halo_Paladin_T1.txt` | `Weapon_Warrior_T1_cut.png` | 통과(가지 검, 흰 천) |
| Halo_Paladin T2 | `art/out/s2/weapons_t13/Weapon_Halo_Paladin_T2.png` | `art/prompts/Weapon_Halo_Paladin_T2.txt` | `Weapon_Warrior_T2_cut.png` | 통과(나무 연습검) |
| Halo_Paladin T3 | `art/out/s2/weapons_t13/Weapon_Halo_Paladin_T3.png` | `art/prompts/Weapon_Halo_Paladin_T3.txt` | `art/out/Weapon_Warrior_T3.png` | 통과, 다소 현실적·가는 날 |
| Horns_Berserker T1 | `art/out/s2/weapons_t13/Weapon_Horns_Berserker_T1.png` | `art/prompts/Weapon_Horns_Berserker_T1.txt` | `Weapon_Warrior_T1_cut.png` | 통과(가시 가지 검, 붉은 천 끝 늘어짐) |
| Horns_Berserker T2 | `art/out/s2/weapons_t13/Weapon_Horns_Berserker_T2.png` | `art/prompts/Weapon_Horns_Berserker_T2.txt` | `Weapon_Warrior_T2_cut.png` | 통과(톱니 나무 검, 뿔 날개) |
| Horns_Berserker T3 | `art/out/s2/weapons_t13/Weapon_Horns_Berserker_T3.png` | `art/prompts/Weapon_Horns_Berserker_T3.txt` | `art/out/Weapon_Warrior_T3.png` | 통과(어두운 한손검, 현실적) |
| Halo_LightMage T1 | `art/out/s2/weapons_t13/Weapon_Halo_LightMage_T1.png` | `art/prompts/Weapon_Halo_LightMage_T1.txt` | `Weapon_Mage_T1_cut.png` | 통과(깃털 지팡이) |
| Halo_LightMage T2 | `art/out/s2/weapons_t13/Weapon_Halo_LightMage_T2.png` | `art/prompts/Weapon_Halo_LightMage_T2.txt` | `Weapon_Mage_T2_cut.png` | 통과(흰 굽은 지팡이) |
| Halo_LightMage T3 | `art/out/s2/weapons_t13/Weapon_Halo_LightMage_T3.png` | `art/prompts/Weapon_Halo_LightMage_T3.txt` | `Weapon_Mage_T3_cut.png` | 통과(날개 금 감옥 구슬) |
| Horns_DarkMage T1 | `art/out/s2/weapons_t13/Weapon_Horns_DarkMage_T1.png` | `art/prompts/Weapon_Horns_DarkMage_T1.txt` | `Weapon_Mage_T1_cut.png` | 통과(고리 가지) |
| Horns_DarkMage T2 | `art/out/s2/weapons_t13/Weapon_Horns_DarkMage_T2.png` | `art/prompts/Weapon_Horns_DarkMage_T2.txt` | `Weapon_Mage_T2_cut.png` | 통과(보라 구슬 갈고리) |
| Horns_DarkMage T3 | `art/out/s2/weapons_t13/Weapon_Horns_DarkMage_T3.png` | `art/prompts/Weapon_Horns_DarkMage_T3.txt` | `Weapon_Mage_T3_cut.png` | 통과(쇠 고리+붉은 천 늘어짐) |
| Halo_Ranger T1 | `art/out/s2/weapons_t13/Weapon_Halo_Ranger_T1.png` | `art/prompts/Weapon_Halo_Ranger_T1.txt` | `Weapon_Archer_T1_cut.png` | 통과(잎 가지 활) |
| Halo_Ranger T2 | `art/out/s2/weapons_t13/Weapon_Halo_Ranger_T2.png` | `art/prompts/Weapon_Halo_Ranger_T2.txt` | `Weapon_Archer_T2_cut.png` | 통과(흰 줄무늬 장궁) |
| Halo_Ranger T3 | `art/out/s2/weapons_t13/Weapon_Halo_Ranger_T3.png` | `art/prompts/Weapon_Halo_Ranger_T3.txt` | `Weapon_Archer_T3_cut.png` | 통과(쇠판 활, 현 하늘색) |
| Horns_ShadowHunter T1 | `art/out/s2/weapons_t13/Weapon_Horns_ShadowHunter_T1.png` | `art/prompts/Weapon_Horns_ShadowHunter_T1.txt` | `Weapon_Archer_T1_cut.png` | 통과(뿔 이빨 가지 활) |
| Horns_ShadowHunter T2 | `art/out/s2/weapons_t13/Weapon_Horns_ShadowHunter_T2.png` | `art/prompts/Weapon_Horns_ShadowHunter_T2.txt` | `Weapon_Archer_T2_cut.png` | 통과(상아 가시 활) |
| Horns_ShadowHunter T3 | `art/out/s2/weapons_t13/Weapon_Horns_ShadowHunter_T3.png` | `art/prompts/Weapon_Horns_ShadowHunter_T3.txt` | `Weapon_Archer_T3_cut.png` | 통과(쇠판, 다소 복잡) |
| Neutral_Blacksmith T1 | `art/out/s2/weapons_t13/Weapon_Neutral_Blacksmith_T1.png` | `art/prompts/Weapon_Neutral_Blacksmith_T1.txt` | (없음) | 통과(돌 망치) |
| Neutral_Blacksmith T2 | `art/out/s2/weapons_t13/Weapon_Neutral_Blacksmith_T2.png` | `art/prompts/Weapon_Neutral_Blacksmith_T2.txt` | (없음) | 통과(작은 쇠 망치) |
| Neutral_Blacksmith T3 | `art/out/s2/weapons_t13/Weapon_Neutral_Blacksmith_T3.png` | `art/prompts/Weapon_Neutral_Blacksmith_T3.txt` | (없음) | 통과(쐐기 쇠 망치+고리) |
| Neutral_Alchemist T1 | `art/out/s2/weapons_t13/Weapon_Neutral_Alchemist_T1.png` | `art/prompts/Weapon_Neutral_Alchemist_T1.txt` | (없음) | 통과(플라스크 지팡이+작은 병·막대; HQ와 같은 해석) |
| Neutral_Alchemist T2 | `art/out/s2/weapons_t13/Weapon_Neutral_Alchemist_T2.png` | `art/prompts/Weapon_Neutral_Alchemist_T2.txt` | (없음) | 통과(같은 구성) |
| Neutral_Alchemist T3 | `art/out/s2/weapons_t13/Weapon_Neutral_Alchemist_T3.png` | `art/prompts/Weapon_Neutral_Alchemist_T3.txt` | (없음) | 통과(놋쇠 숟가락 막대) |
| Neutral_PetTamer T1 | `art/out/s2/weapons_t13/Weapon_Neutral_PetTamer_T1.png` | `art/prompts/Weapon_Neutral_PetTamer_T1.txt` | `Weapon_Tamer_T1_cut.png` | 통과(호루라기 가지) |
| Neutral_PetTamer T2 | `art/out/s2/weapons_t13/Weapon_Neutral_PetTamer_T2.png` | `art/prompts/Weapon_Neutral_PetTamer_T2.txt` | `Weapon_Tamer_T2_cut.png` | 통과(청록 리본·발바닥 장식) |
| Neutral_PetTamer T3 | `art/out/s2/weapons_t13/Weapon_Neutral_PetTamer_T3.png` | `art/prompts/Weapon_Neutral_PetTamer_T3.txt` | `Weapon_Tamer_T3_cut.png` | 통과(쇠 공 끝·호루라기) |

## v2 (10/11 밤): HQ 앞면을 스타일 참조로 건 Medium 재생성 — 27칸 + 뿔 전사 최종 3장
- v1(참조 없음)은 그림체가 HQ와 안 맞아 보류. v2 = 같은 진영·직업 HQ 앞면을 '스타일 참조만'으로 걸고 모양은 v1 유지(뿔 전사는 한손검이라 빛 성기사 HQ 검을 참조, 연금술사는 펫조련사 HQ 지팡이 참조). 단계 문구: T1 금·금속 거의 없음 / T2 나무·천 / T3 둔한 강철·작은 장식.
- 대장장이 T3: 금 띠·고리 뺌(쇠 띠만). 연금술사 T1~T3: 지팡이 하나(병은 위에 달림/끼움, 옆에 따로 없음).
- 파일 `art/out/s2/weapons_t13_v2/Weapon_<키>_T<n>_v2.png`, 프롬프트 `art/prompts/Weapon_<키>_T<n>_v2.txt`, 생성기 `tools/_weapon_t13_v2_prompts.py`, 시트 `tools/_weapon_t13_v2_sheets.py`.
- 시트 `art/review/s2/weapons_t13v2_{warrior,mage,archer,neutral}.jpg`, 뿔 전사 최종 `weapons_t13v2_berserker_final.jpg`(a 잎모양 넓은 날 / b 톱니 곧은 날+주황 보석 / c 두꺼운 식칼형). 내 추천 **b**(HQ의 톱니·용암 금·뿔 가드 결, 한손검).
- 100% 크롭(대장장이 T2 머리·연금술사 T1 병·뿔 최종 b 가드): 조각 깨짐·떠 있는 조각·글자·레이 없음. 모두 통과 판정(내 눈). Halo_Paladin_T1_v2 한 장만 실수로 High(5크레딧)로 나감, 나머지 29장 Medium(0).
