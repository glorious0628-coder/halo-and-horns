# Blender 손보기 — 상태 (2026-10-12)

## 10/13 밤 늦게 — 큐 끝 (잔액 1,730)
- 끝·디자인 검수에 보냄: 8K PBR 36종 + 4K PBR 37종(집 덩어리 18·묶음10 7·NEW_ 9·간판 Potion/Bakery/Flower) → art/models/tripo/touchup/<이름>/<이름>_TU.glb, 원본 web/<이름>_SM_tex{8k,4k}_pbr_src.fbx(디스크만), records.json push.
- 남음: **Daisy 다시**(디자인 검수가 형제 7b4845eb·245a153c·c2e4b5db 중 고르면 텍스처 4K → PBR; FBX build/tripo_wm1/HaloFlowerPotHQ_Daisy_wm_*). SignJuice = 계정 2(cb0ab903) 것 씀, 계정 1 Juice는 안 씀. 지금 Daisy_TU 쓰지 않음.
- 새 텍스처 = 4K(20점). 텍스처+PBR = 25점/개, 흰 모델 100점.
- 페이지 함수 = tools/tripo_web_helpers.js(+ hhTexOne = 올리기+누르기 한 번에, 잠금 있음). 브라우저 캐시는 가끔 비워짐 → Adobe presigned URL로 다시 /hh-bundleN에 넣음.

## 10/13 밤 — 숨긴 창에서도 돎 (잔액 3,955)
- **숨긴 창 해결:** 페이지를 새로 열지 말고 `$router.push`로만 이동(새로 열면 숨긴 창에서 안 뜸). 도우미: hhTexUp/hhTexGo(텍스처), hhPbrStep(PBR), hhSmStep('nav'|'prep'|'go')(스마트 메시, 지난 그림 키와 같으면 안 누름). 그림 올릴 땐 input.value='' + 새 파일 이름(같은 이름이면 안 올라감).
- **주소 받기:** 페이지 → 내 PC 직접은 막힘. 주소 목록 텍스트를 Adobe 업로드(PUT)로 보낸 뒤 presigned URL을 curl.
- **끝:** PBR 36개 내려받음 → art/models/tripo/web/<id>_SM_tex8k_pbr_src.fbx(디스크만, 크기 커서 git 안 올림) → touchup/<id>/<id>_TU.glb. records.json 적음. 디자인 검수에 이름+경로 보냄.
- **10/13 밤 추가:** NEW_ 9종(GatherBush·ArmoryBarrels·CandleCrate·Easel·NoticeBoard·WaterBuckets·Beehive·WateringCan·SteppingStone) + 간판 4종(HaloSign_SignBakery·Flower·Juice·Potion) 흰 모델 생성 끝(id 디자인 검수에 보냄). 흰 모델 FBX 152개 = build/tripo_wm1/<이름>_wm_<id8>.fbx (디자인 검수가 봄). **새 텍스처는 4K**(사용자 10/13, 이미 8K는 그대로). 잔액 2,655. 다음 = 디자인 검수가 38종 고르면 hhTexQ 새로 만들어 hhTexUp/hhTexGo → hhPbrQ/hhPbrStep → URL 목록을 Adobe PUT으로 받아 curl → build_glb → 디자인 검수에 이름+경로.
- **흰 모델 고르기 대기(디자인 검수):** 집 덩어리 18종(id 보냄) + 묶음10 7종(Topiary_E·PotFlowers_E·F·A·C·D·Planter_A, id 보냄). 고르면 → 텍스처 → 바로 PBR.
- Blender 손보기 2 몫: Planter_D·FlowerCart_Bouquet·난간 6·NEW_* 5.

## 10/13 오후 — A23-154 방식 (다섯 단계만)
- 스마트 메시 → 디자인 검수가 4개 중 고름 → 텍스처(앞면 한 장·조명 없이·8K) → **바로 PBR** → 내려받아 크기·피벗·방향만 → **디자인 검수에 이름+경로**(그다음 최종 검수 → 이미지 생성 3). 매직 브러시·붓·Blender 색 고침·사이 관문 없음.
- 데스크톱에 뜨는 일(창·다운로드 창·마우스·키보드) 하지 않음 — Blender --background·curl·앱 브라우저 JS만. 사용자 부탁은 최종 검수에게만.
- 앱 브라우저 창이 숨겨지면 Tripo 페이지가 안 뜸(fetch도 멈춤) → 최종 검수에 창 보이게 부탁하고 기다림.
- PBR 남음: JuiceParasol·DomeOnionSlim·BreadStand·FruitStall·DomeBrick(텍스처 끝) + ConeTree(PBR 결과 안 옴, 다시) + 동상 B·분수 C·Daisy·Rose. PBR 끝·내려받기 남음: GateLeaf·DomeOnion·DomeBall·BenchB·DomeOctagon·FlowerCart.
- 디자인 검수 고른 흰 모델 20종(텍스처 30 → 바로 PBR): Greenhouse d148d3bd, ShopSign e96efdb6, Lantern_A 3b8c167c, Lantern_B 4b6f9db9, Lantern_C 096e84f2, Lantern_D 1eed23ce, Lantern_E c102246e, IvyWall 18598e34, IvyBalcony 0352e909, FlowerBushPot 5a5af84d(뒤 구멍 → ⑤에서 초록 공 파트), DomePorchHalf e549329c, DomePavilion bc5097f2, DomeTowerSmall 6d925d8a, BreadDisplay e5467c5f, RoundTree_E 077f2fae, RoundTree_F cc3f527f, RoundTree_G a9395b47, Topiary_C 3e2847ad, Topiary_D 7c673fb4, Planter_E 1021df70. 텍스처 앞면 = bundle8/9 `<이름>_front`.
- **10/13 저녁 진행:** PBR 10 누름(JuiceParasol·DomeOnionSlim·BreadStand·FruitStall·DomeBrick·ConeTree 다시·동상B·분수C·Daisy·Rose). 고른 20종 텍스처: 0~9번 끝(Greenhouse~FlowerBushPot), 10번 DomePorchHalf부터 남음 — 페이지 localStorage hhTexQ/hhTexI + hhTexDo(현재 칸 텍스처 후 다음 칸으로 이동). 사용자 말: 텍스처 지금 방식 그대로(앞면 한 장 → 바로 PBR). 내 세션이 화면(분할 보기)에 떠 있어야 Tripo가 돌아감.
- **이어받기(10/13 밤):** 텍스처 큐 0~10번 끝(Greenhouse d148d3bd·ShopSign e96efdb6·Lantern_A~E·IvyWall 18598e34·IvyBalcony 0352e909·FlowerBushPot 5a5af84d·DomePorchHalf e549329c) → 이 11개 텍스처 끝나면 **바로 PBR**. 남은 텍스처 11~19번: DomePavilion bc5097f2·DomeTowerSmall 6d925d8a·BreadDisplay e5467c5f·RoundTree_E 077f2fae·RoundTree_F cc3f527f·RoundTree_G a9395b47·Topiary_C 3e2847ad·Topiary_D 7c673fb4·Planter_E 1021df70 (페이지 hhTexQ/hhTexI=11, `eval(hhSleepDef); hhTexDo()` 반복).
- PBR 눌렀고 내려받기 남음(16): GateLeaf·DomeOnion·DomeBall·BenchB·DomeOctagon·FlowerCart·JuiceParasol·DomeOnionSlim·BreadStand·FruitStall·DomeBrick·ConeTree·동상B 1a0812be·분수C cd70436c·Daisy c9df2ff9·Rose 9e0487cc → model_url(tripo_texture_*.fbx) curl → art/models/tripo/web/<id>_SM_tex8k_pbr_src.fbx → scratchpad build_glb.py(크기·피벗·방향만) → touchup/<id>/<id>_TU.glb → 디자인 검수에 이름+경로, records.json.
- 페이지 함수가 사라지면 tools/tripo_web_helpers.js 전체를 javascript_exec로 실행. 이 세션 오른쪽 브라우저 칸이 보일 때만 Tripo가 돎(대화만 떠 있고 브라우저 칸이 닫히면 멈춤).
- **나눔(A23-155):** Blender 손보기 2(local_d85ba88a…, 다른 Tripo 계정)에 넘김 = Planter_D·FlowerCart_Bouquet·Balustrade 6종(Var3 E·F, Var4 A·B·C·D)·NEW_* 5종 (10/13 13:40 최종 검수: 간판 4종·NEW_Beehive·NEW_WateringCan·NEW_SteppingStones는 계정 1에 흰 모델이 이미 있어 **1의 몫으로 되돌림**. 계정 1 잔액이 낮아 앞으로 새 스마트 메시는 계정 2 = Blender 손보기 2; 1은 이미 있는 흰 모델의 텍스처 4K·PBR까지.) 내 몫 남은 흰 모델 = HaloChunk_* 18종: bundle11 PotionDisplay·JuiceStand·RoseTrellis·RoseArch·SunflowerBed·Pond, bundle12 StarFinial·CastleHedge·WeatherVane·ChimneyCap·ChimneyLantern·RoundTree, bundle13(21.8 MB) MedalBell·Cauldron·FlowerBuckets·WindowBoxB·CornerFinial·Telescope.
- (옛 줄) 흰 모델 큐 남음: Planter_D·FlowerCart_Bouquet(bundle10), bundle11 12종, bundle12 7종, WeatherVane·ChimneyCap·ChimneyLantern·RoundTree(bundle12 끝에 넣음, 42.1 MB; 아직 Adobe 안 올림).

## 10/13 낮 — 로그인 뒤 진행 (잔액 6,505)
- 매직 브러시 = 버림(A23-154). PBR 7 누름(ConeTree 결과 늦게 옴, 확인 필요). 텍스처 5 누름(JuiceParasol·DomeOnionSlim·BreadStand·FruitStall·DomeBrick).
- 흰 모델 생성 끝 26종: 묶음8 10종 + 묶음9 10종(id 목록 디자인 검수에 보냄) + 묶음10 Topiary_E 48713e59·PotFlowers_E de342b72·PotFlowers_F a35f95c9·PotFlowers_A 20715701·PotFlowers_C 79825b6e·PotFlowers_D de8064f2·Planter_A e72c4f22 (URL id; 형제 3개는 에셋 목록에서 이웃 4개 묶음, project_name으로 확인).
- 남음: 묶음10 Planter_D·FlowerCart_Bouquet, 묶음11 12종, 묶음12 7종(올리기 전). 창이 숨겨지면 페이지가 멈춤(타이머) → 창 보이게 하고 이어서. 함수: hhPrepFn(넣기+빈 칸 다시) → hhGoFn(누르기) 두 번에 나눠 호출(45초 제한), 매 호출 앞에 eval(localStorage.hhSleepDef).

## 10/13 아침 — PC 다시 켬
- 9종+WingR 이미지 생성 3에 넘김(메시지). **Tripo 로그아웃됨**(재부팅 뒤 401, localStorage·Cache 비어짐) → 사용자 로그인 기다림(비밀번호 입력 금지).
- 페이지 함수는 `tools/tripo_web_helpers.js`에 저장 → 로그인 뒤 그 파일 내용을 javascript_exec로 한 번 실행하면 hhTexFn/hhSetFn/hhGoFn/hhPbrFn 다시 생김.
- 디자인 검수 10/13 아침 판정: **PBR OK** ConeTree 2bbbd641·DomeBall 66894770·BenchB b8de1d3c·DomeOctagon f9e91fe2·FlowerCart af2e2b5f(수레 몸만; 꽃은 이미지 생성 3이 'FlowerCart_Bouquet' 4면 따로 → Tripo 135 → Studio에서 얹음). **JuiceParasol = 6ec4d75d-24b6-4474-9400-36e4fc7a9848 텍스처 OK.** Greenhouse·ShopSign·Lantern 흰 모델 나오면 id 디자인 검수에.
- 다음 묶음 bundle8(scratchpad, 51.0 MB — 50 MB 블록 한도 근처, 다음 추가는 bundle9, 키 `<이름>_<면>`): Greenhouse·ShopSign·Lantern_A·B·C·D·E·IvyWall·IvyBalcony·FlowerBushPot 4면 + 텍스처용 앞면 DomeOnionSlim·BreadStand·FruitStall·DomeBrick·JuiceParasol. 로그인 뒤 Adobe 올림 → /hh-bundle8, hhIdx8. bundle9(18.1 MB): DomePorchHalf 4면(반쪽 돔 — 온 돔이면 탈락), DomePavilion 4면(아치 뚫림 — 막힌 벽이면 탈락), DomeTowerSmall 4면(둥글기·바닥 막힘), BreadDisplay 4면(빵 선반마다 따로), 식물 RoundTree_E·F·G, Topiary_C·D, Planter_E (49.8 MB). bundle10(51.8 MB): Topiary_E, PotFlowers_E·F(Var3), PotFlowers_A·C·D(Var4), Planter_A·D(Var4), FlowerCart_Bouquet. bundle11: PotionDisplay, JuiceStand, RoseTrellis(격자 뚫림 우선), RoseArch(아치 안 뚫림 — 막히면 탈락), Balustrade_E·F(Var3)·A(Var4), SunflowerBed, Pond(물 면 둥글고 꽉 참 — 네모/구멍 탈락), Balustrade_B·D(Var4), Balustrade_C(ㄱ자 — 일자·ㄷ자 탈락) (41.6 MB). bundle12(25.8 MB): StarFinial, NEW_BellFrame·BreadBasket·CafeTable·FlowerBush·Cauldron, CastleHedge(양끝 평평 — 이어 붙임) (27.1 MB). 흰 모델 큐 49개(≈6,615점). 추가는 scratchpad addb.py <S> bundle9 <rel>.

## 10/13 정리 (사용자 "정리하고 컴퓨터 꺼줘") — 다음 세션은 여기부터
- **잔액 9,385.** 도는 Tripo 일 없음(전부 끝남). 브라우저 탭 seed = Tripo 로그인 그대로, localStorage 함수 hhTexFn/hhSetFn/hhGoFn/hhPbrFn + Cache 'hh' /hh-bundle3~7(hhIdx3~7; 다시 열면 캐시가 없을 수 있음 → 4면 묶음 다시 올림).
- **끝·넘길 것:** 9종 PBR 완성 + WingR 거울 = 디자인 검수 통과 → **이미지 생성 3에 넘기기(아직 메시지 안 보냄)**: `art/models/tripo/touchup/<id>/<id>_TU.glb` (DoorSingle·LampArm·CastleWingL·CastleWingR·DomeRibbed·DoorDouble·WindowBoxA·BenchA·BenchC·CastleRose). 메모: CastleRose 뒤 파란 원판, WindowBoxA DoubleSided, LampArm 유리 칸 = Studio 유리 파트. records.json 기록 완료, src FBX push.
- **PBR 누르기(5) — OK 받음:** GateLeaf 2bc07ecc(텍스처 6bb26988), DomeOnion 414b871a(텍스처 c6d08561) → hhPbrFn → 내려받기 → build_glb.py → 이미지 생성 3.
- **PBR 판정 대기(디자인 검수 다음 세션 첫 일):** 텍스처 끝 ConeTree 2bbbd641, DomeOctagon f9e91fe2, DomeBall 66894770, FlowerCart af2e2b5f(흰 모델 꽃 화분이 작고 성김), BenchB b8de1d3c. 내 확인 시트 scratchpad tex_b5/b5_tex.jpg(지워질 수 있음).
- **텍스처 누르기(30) — OK 받음, 아직 안 누름:** DomeOnionSlim 40dad418-dbd3-4840-a282-ff632a7a9acf, BreadStand 00dac363-0f24-4b60-acff-44c9dce79e52, FruitStall 568b5b8e-f20d-4c23-b79e-332bda8067be, DomeBrick 46f0bb09-49cb-4426-a380-60ae02ae07ea (앞면 슬라이스 /hh-bundle6, hhIdx6; 키 `<이름>_front`). **텍스처 전에 내가 흰 모델 직접 확인**(아직 못 봄).
- **JuiceParasol 흰 모델 4개(100 씀):** 6ec4d75d / 52b68046 / 46c0419e / 89bac495 → 디자인 검수가 다음 세션에 고름(내 의견 6ec4d75d). 텍스처 누르지 말 것.
- **스마트 메시(100) 대기 — 4면 통과:** HaloChunk_Greenhouse(chunks/), HaloChunk_ShopSign(chunks/), HaloVar4_Lantern_A, HaloVar4_Lantern_C, HaloVar4_Lantern_D, HaloVar3_Lantern_E (art/out/s2/noshadow/…_{front,left,right,back}_ns.png). 관문: 금 틀·가는 팔·사슬 끊김, 유리 막힘/뚫림, 꼭대기 공, ShopSign 판 가운데 평평. Lantern_B는 받침 손질 뒤. IvyWall은 안 함(다시 그림).
- 매직 브러시 5곳(동상 B·분수 C·Daisy·Rose) = **버림**(SPEC A23-154: 붓 칠하기 없음). 동상 B 1a0812be·분수 C cd70436c·Daisy c9df2ff9·Rose 9e0487cc는 텍스처 그대로 바로 PBR.
- MailBoy(사람) = 맨 마지막.

## 10/13 새벽 — 진행판 (보고처 = 디자인 검수 local_2137d284…, 점수 승인도)
- 순서: 4면 → 스마트 메시(100) → 흰 모델 id를 디자인 검수에(Tripo에서 직접 봄) → 나도 받아서 봄, 다르면 상의 → 텍스처 첫 칸 앞면 한 장+조명 제거+8K(30) → 디자인 검수 확인 → (고칠 곳은 Tripo 편집/매직 브러시, 창 보여야 함) → PBR 한 번(5) → 내려받기 → Blender 크기·피벗·방향만.
- 동상 B 1a0812be·분수 C cd70436c: 텍스처 끝, 매직 브러시 3곳 대기(창 숨김) → 그 뒤 PBR. Daisy c9df2ff9·Rose 9e0487cc도 매직 브러시 대기. Lavender·Tulip·Sunflower PBR 돌림.
- 흰 모델 디자인 검수 답 대기: DoorSingle·ConeTree(내 의견 나무 4개 다 별로 → 다시 뽑기), LampArm·CastleWingL·DomeRibbed·DoorDouble·WindowBoxA·BenchA·BenchC·CastleRose. CastleWingR = WingL 완성판 Blender 좌우 뒤집기(메시에 굽기·노멀·UV 그대로).
- 잔액 10,075 (10/13 새벽). PBR 끝·받음(디스크): Lavender·Tulip·Sunflower → art/models/tripo/web/HaloFlowerPotHQ_<n>_SM_tex8k_pbr_src.fbx. PBR 돌림: DoorSingle d61f68e6. 텍스처 끝·PBR OK 대기: 묶음 2·3 8종(LampArm 6895c425, CastleWingL 10bf8543, DomeRibbed 2f0b12f2, DoorDouble d28f2316, WindowBoxA 82c8a278, BenchA bbf6251c, BenchC f12d3f90, CastleRose e51189a5). 텍스처 돌림: GateLeaf 2bc07ecc, DomeOnion 414b871a. 흰 모델 고르기 대기: ConeTree(새)·DomeOctagon·DomeBall·FlowerCart·BenchB.
- 페이지 localStorage: hhTexFn(텍스처 함수), hhSetFn/hhGoFn(스마트 메시 넣기/누르기), hhIdx3~7 + Cache 'hh' /hh-bundle3~7.
- **10/13 오전 갱신 (잔액 9,385):** 9종 PBR 끝·받음(touchup/<id>/<id>_TU.glb + WingR 뒤집기) → 디자인 검수 금속·WingR OK 대기 후 이미지 생성 3에 넘김. GateLeaf·DomeOnion 텍스처 끝 → PBR OK 대기. 묶음 5·6 텍스처 끝(ConeTree 2bbbd641, DomeOctagon f9e91fe2, DomeBall 66894770, FlowerCart af2e2b5f(화분 작음 — 모양), BenchB b8de1d3c) → PBR OK 대기. 흰 모델 고르기 대기: DomeOnionSlim·BreadStand·FruitStall·DomeBrick, JuiceParasol(내 의견 6ec4d75d; 46c0419e 빈 상자, 52b68046 뒤 막힘, 89bac495 지붕 처짐). Greenhouse 4면 있음 — 통과 여부 물음.
- **요령:** 브라우저 호출은 전부 tabId "seed"(디자인 검수가 같은 창에 자기 탭을 엶). 32장 같은 많은 그림은 한 파일(bundle)로 묶어 Adobe에 한 번 올리고 페이지 Cache API('hh')에 넣어 slice로 칸에 넣음. 에셋 목록 20개 넘으면 `fetch('https://api.tripo3d.ai/v2/studio/assets/v2?asset_type=mine&locale=ko&offset=20&size=40&type=all',{credentials:'include'})` → data.projects(id·model_url). 점수 버튼은 경로 id·상태 확인 후 JS click, 앞뒤 잔액 비교.

## 10/12 밤 늦게 — 바뀐 순서(사용자) + 대기 중
- 흰 모델 4개는 **디자인 검수가 Tripo에서 직접 보고 고름**(시트 보내지 않음). 나도 따로 보고, 다르면 이유 말하고 상의.
- 고장은 Blender가 아니라 Tripo 안에서(더 나은 흰 모델/스마트 메시 수정/다시 뽑기). PBR은 맨 끝 한 번. Blender는 크기·피벗·방향만.
- 동상·분수: 앞서 Blender로 색 고친 판(touchup/*_TU*)·다시 올린 분수(2451f3d9, PBR 5 나감)는 안 씀. 디자인 검수 답 기다림(동상 D는 받침대 옆면 찢김 — 사용자 지적).
- 꽃 화분 5종 흰 모델 생성 끝(각 100): Daisy c9df2ff9…, Lavender 3d8a7ade…, Rose aa0225fb…, Sunflower 5f8780fb…, Tulip f75480d2… (형제 id는 디자인 검수에 보낸 메시지). 잔액 12,335.

## 10/12 밤 — 빛 마을 동상·분수 (끝: 받음 + 최소 손보기, push 7035c69)
- **확정 방법(사용자 10/12 밤 직접 보여 줌):** 스마트 메시 4면 → 흰 모델 고름 → 왼쪽 메뉴 '텍스처' → **첫 칸(그림 한 장 탭)에 앞면 2D 한 장 업로드** → 조명 제거 켬 → 8K → 텍스처 생성(30) → **PBR 생성(5) 한 번** → (Roblox에서 2D에 더 가깝게 재질 한 번 더). 가운데 칸(멀티뷰 탭)은 쓰지 않음. 물건 하나 = 135점.
- 동상 `Halo_Statue` 흰 모델 D = f4fcec0d(방패 별 4갈래), 분수 `Town_Halo_Fountain3` 흰 모델 D = 16be0d85(기둥이 2D보다 45° 돌아감 → 배치 yaw +45). 시트 `art/review/blender/halo_statue_tex_compare_1012.jpg`, `town_fountain3_tex_compare_1012.jpg`.
- 내려받은 뒤 고칠 것: 분수 큰 그릇 안쪽 벽 주황·갈색 + 기둥 둘레 물 얼룩 → 색만 흰 대리석/하늘색; 동상 받침대 오른쪽 아래 어두운 틈.
- Tripo 잔액 12,840(오늘 13,230에서 390).
- **내려받기는 이제 묻지 않음**(사용자 10/12 22:05). 받는 법: 페이지 `$pinia…['feature-workspace'].current.latest.model_url`(마지막 판 FBX, 8K 색 + PBR 맵) → curl. 손본 판 `art/models/tripo/touchup/<id>/<id>_TU.glb`(디스크만), 스크립트(uvmask·extract_fbx·build_glb·render_views·fix_*) 같은 폴더에.
- **조작 요령:** 앱 창이 숨겨지면 화면 캡처가 잘림 → 최종 검수에 "창 보이게". Tripo 화면에서 좌표 클릭·드래그 금지(엉뚱한 버튼 맞음). 버튼은 요소 확인 뒤 JS, 3D 시점은 canvas에 JS PointerEvent 드래그·WheelEvent. 사용자가 창에서 같이 누르는 중이면 손 뗌.

## 10/12 저녁 정리 (사용자 "모든 세션 다 여기까지만 하고 정리해줘")
- **새 3D 방법 (SPEC A23-150)**: 그림자 없는 3D 렌더 2D **4면**(앞·왼·오른·뒤) → Tripo 웹 **스마트 메시**(4면 입력, 흰 모델 4개 = 100점) → 가장 잘 나온 흰 모델(사람은 **얼굴 빈 것**) → **왼쪽 메뉴 '텍스처'**(붙은 그림 그대로) **'조명 없이' 체크** → **8K**(30점) → 최소 Blender(A23-147) → records.json → 이미지 생성 4가 Roblox에. 물건 하나 = **130점**. 바깥선 없음.
- **Tripo 잔액 13,230점**(25k 계정, 앱 안 브라우저에 로그인돼 있음). **130점 아래가 되면 사용자에게 바로 알림**(다음 하나를 못 만듦 → 사용자가 계정 바꿈).
- **MailBoy = 사람이라 맨 마지막**(사용자 "인물은 맨 마지막에"). 새 4면 `art/out/s2/noshadow/npc/NPC_HaloMailBoy_{front,back,left,right}_ns.png` 준비됨(그림자 없음·단정 확인), 아직 생성 안 함.
- **남길 파일**: `art/models/tripo/web/NPC_HaloMailBoy_SM_tex8k_src.glb`(앞면 한 장으로 만든 시험 판, 기록 `NPC_HaloMailBoy_web_sm_tex8k`, 시트 `art/review/blender/mailboy_sm_tex8k_1012.jpg`) — 새 MailBoy 4면 판이 통과할 때까지 비교용으로 둠, 그다음 지움.
- **다음**: 최종 검수가 통과시켜 보내는 **빛 마을 물건** 4면 묶음부터(순서 `docs/review/noshadow_redo_2026-10-12.md`). 새 Tripo 생성은 묶음이 올 때까지 시작하지 않음.

## 앱 안 브라우저에서 Tripo에 그림 넣기 (10/12 밤 시험 통과)
- Adobe에 올리기(`asset_initialize_file_upload` → `curl -X PUT --data-binary @파일` → `asset_finalize_file_upload`) → Tripo 페이지에서 `fetch(presignedAssetUrl)` → File → DataTransfer로 칸에 넣기. base64를 JS에 붙이지 말 것(너무 무거움).
- 스마트 메시 탭 → 큐브(멀티뷰) 아이콘. `input[type=file]` 순서 0 앞 · 1 왼쪽 · 2 오른쪽 · 3 뒷면. **왼쪽 칸 = 캐릭터의 왼쪽이 보이는 그림(화면 왼쪽을 봄, 우리 `_right` 파일)**, 오른쪽 칸 ← `_left`.
- 창이 좁으면 왼쪽 패널이 잘림 → 보기 크기 1280x832로 맞추고 작업, 끝나면 되돌림.
- 내보내기(GLB)는 사용자 허락 뒤. Tripo Studio 내보내기는 앞 = Blender -y, 바닥 가운데 피벗 → `tools/view_match_2d.py --front -y`.

## 실패해서 버린 것 (다시 하지 말 것)
- Blender로 Tripo 얼굴 면 펴기(평면 맞추기·라플라스·구멍 메우기·나누기): 접힌 선, 머리카락이 얼굴에 들어감. 얼굴 2D 투영 칠은 3D 조각된 눈·이 자리와 어긋나 빛 받으면 이가 두 동강.
- Tripo 매직 브러시를 합성 입력으로: 확대만 되고 화면 이동·생성 모드 붓은 안 먹힘.

## 도구 (10/12)
- `tools/view_match_2d.py` — GLB를 2D 4면과 같은 틀로 찍기(`--front -y` = Tripo Studio 내보내기). 2D | 옛 | 새 시트에 씀.
- `tools/face_clean_bl.py` + `tools/face_clean_2d.py` — 얼굴만 떼어 평면 UV로 굽고 2D 기준으로 다시 그리기(실험, 위 이유로 안 씀).
- `tools/blender_view.py` — 2D | Tripo | 새 판을 Blender 창에 띄우는 보기 전용 스크립트. (`tools/blender_live.py` = 파일로 Blender 창을 조종하는 리스너, 로컬만, 올리지 않음.)
