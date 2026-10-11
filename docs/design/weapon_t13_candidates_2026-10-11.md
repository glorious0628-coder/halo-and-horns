# 무기 9종 × T1~T3 후보 현황 (이미지 생성 2, 2026-10-11 저녁)

## 결론
- **새 그림체(장난감 3D, 진영 색) 후보: 27칸 모두 없음.** 있는 것은 ① 9종 '고급 앞·뒤·옆' 최종 룩(`art/out/s2/weapons/Weapon_<키>_{front,back,edge}_HQ_src.png`, 단계 T1~T3가 아니라 완성형 한 벌), ② 옛 일반(진영 구분 없는) T1~T6 아이콘 `art/out/s2/Weapon_<Warrior|Mage|Archer|Tamer>_T#_cut.png`(2026-10-06 승인, 옛 그림체 → 'old images redrawn' 대상).
- 대장장이·연금술사는 옛 T1~T3 자체가 없음(직업이 새로 생김, A23-39/127).
- 전사 두 진영은 **한손검만**(A23-128). 옛 `Weapon_Horns_Berserker_front_HQ`는 대검이라 쓰지 않음(뿔 전사 T3 이상 최종 룩도 한손검으로 다시 그려야 함 → 검수 결정 필요).
- 프롬프트 27개 준비됨: `art/prompts/Weapon_<키>_T<n>.txt`(<1000자, 참조 없음, Medium). 생성기 `tools/_weapon_t13_prompts.py`.
- Firefly 브라우저 판이 **로그아웃 상태**라 아직 한 장도 못 그림(사용자가 직접 Adobe 로그인 필요).

## 27칸 표

| 칸 | 새 후보 | 프롬프트 | 옛 일반 T# (옛 그림체) | 내 판정 |
|---|---|---|---|---|
| Halo_Paladin T1 | 없음(생성 대기) | `art/prompts/Weapon_Halo_Paladin_T1.txt` | `Weapon_Warrior_T1_cut.png` | 대기 |
| Halo_Paladin T2 | 없음(생성 대기) | `art/prompts/Weapon_Halo_Paladin_T2.txt` | `Weapon_Warrior_T2_cut.png` | 대기 |
| Halo_Paladin T3 | 없음(생성 대기) | `art/prompts/Weapon_Halo_Paladin_T3.txt` | `art/out/Weapon_Warrior_T3.png` | 대기 |
| Horns_Berserker T1 | 없음(생성 대기) | `art/prompts/Weapon_Horns_Berserker_T1.txt` | `Weapon_Warrior_T1_cut.png` | 대기 |
| Horns_Berserker T2 | 없음(생성 대기) | `art/prompts/Weapon_Horns_Berserker_T2.txt` | `Weapon_Warrior_T2_cut.png` | 대기 |
| Horns_Berserker T3 | 없음(생성 대기) | `art/prompts/Weapon_Horns_Berserker_T3.txt` | `art/out/Weapon_Warrior_T3.png` | 대기 |
| Halo_LightMage T1 | 없음(생성 대기) | `art/prompts/Weapon_Halo_LightMage_T1.txt` | `Weapon_Mage_T1_cut.png` | 대기 |
| Halo_LightMage T2 | 없음(생성 대기) | `art/prompts/Weapon_Halo_LightMage_T2.txt` | `Weapon_Mage_T2_cut.png` | 대기 |
| Halo_LightMage T3 | 없음(생성 대기) | `art/prompts/Weapon_Halo_LightMage_T3.txt` | `Weapon_Mage_T3_cut.png` | 대기 |
| Horns_DarkMage T1 | 없음(생성 대기) | `art/prompts/Weapon_Horns_DarkMage_T1.txt` | `Weapon_Mage_T1_cut.png` | 대기 |
| Horns_DarkMage T2 | 없음(생성 대기) | `art/prompts/Weapon_Horns_DarkMage_T2.txt` | `Weapon_Mage_T2_cut.png` | 대기 |
| Horns_DarkMage T3 | 없음(생성 대기) | `art/prompts/Weapon_Horns_DarkMage_T3.txt` | `Weapon_Mage_T3_cut.png` | 대기 |
| Halo_Ranger T1 | 없음(생성 대기) | `art/prompts/Weapon_Halo_Ranger_T1.txt` | `Weapon_Archer_T1_cut.png` | 대기 |
| Halo_Ranger T2 | 없음(생성 대기) | `art/prompts/Weapon_Halo_Ranger_T2.txt` | `Weapon_Archer_T2_cut.png` | 대기 |
| Halo_Ranger T3 | 없음(생성 대기) | `art/prompts/Weapon_Halo_Ranger_T3.txt` | `Weapon_Archer_T3_cut.png` | 대기 |
| Horns_ShadowHunter T1 | 없음(생성 대기) | `art/prompts/Weapon_Horns_ShadowHunter_T1.txt` | `Weapon_Archer_T1_cut.png` | 대기 |
| Horns_ShadowHunter T2 | 없음(생성 대기) | `art/prompts/Weapon_Horns_ShadowHunter_T2.txt` | `Weapon_Archer_T2_cut.png` | 대기 |
| Horns_ShadowHunter T3 | 없음(생성 대기) | `art/prompts/Weapon_Horns_ShadowHunter_T3.txt` | `Weapon_Archer_T3_cut.png` | 대기 |
| Neutral_Blacksmith T1 | 없음(생성 대기) | `art/prompts/Weapon_Neutral_Blacksmith_T1.txt` | (없음) | 대기 |
| Neutral_Blacksmith T2 | 없음(생성 대기) | `art/prompts/Weapon_Neutral_Blacksmith_T2.txt` | (없음) | 대기 |
| Neutral_Blacksmith T3 | 없음(생성 대기) | `art/prompts/Weapon_Neutral_Blacksmith_T3.txt` | (없음) | 대기 |
| Neutral_Alchemist T1 | 없음(생성 대기) | `art/prompts/Weapon_Neutral_Alchemist_T1.txt` | (없음) | 대기 |
| Neutral_Alchemist T2 | 없음(생성 대기) | `art/prompts/Weapon_Neutral_Alchemist_T2.txt` | (없음) | 대기 |
| Neutral_Alchemist T3 | 없음(생성 대기) | `art/prompts/Weapon_Neutral_Alchemist_T3.txt` | (없음) | 대기 |
| Neutral_PetTamer T1 | 없음(생성 대기) | `art/prompts/Weapon_Neutral_PetTamer_T1.txt` | `Weapon_Tamer_T1_cut.png` | 대기 |
| Neutral_PetTamer T2 | 없음(생성 대기) | `art/prompts/Weapon_Neutral_PetTamer_T2.txt` | `Weapon_Tamer_T2_cut.png` | 대기 |
| Neutral_PetTamer T3 | 없음(생성 대기) | `art/prompts/Weapon_Neutral_PetTamer_T3.txt` | `Weapon_Tamer_T3_cut.png` | 대기 |
