<!-- api_agent job l10n_v4_check · claude-opus-5-5 · done · 20 turns · ~$0.6729 -->
**한국어 모드 계약 v4 확인 결과 (5cdd810c, `docs/design/l10n_contract_2026-10-11.md`)**

v3 확인에서 막는 것으로 본 1번은 고쳐졌습니다. 문제 2~6번과 v2-3·v2-5도 거의 다 반영됐고, 덜 된 것은 현상수배판의 수배 줄 하나입니다. 확인은 문서 차이와 `src/` 코드를 직접 읽어서 했고, 시험은 이번 작업에서 실행할 수 없었습니다.

**1. 항목별 판정**

| # | 판정 | 근거 |
|---|---|---|
| 1 (막는 것, `%`) | 반영됨 | :55 "Args가 없으면 `string.format`을 절대 부르지 않는다", :60 Args 없는 틀은 그대로 둠, 시험 6 :140에 "XP +30% …" 사례가 들어감. :56의 pcall과 :57의 "빈 자리 ''"은 Args가 있을 때만 적용되므로 v3의 자기모순이 풀림. |
| 2 (숨긴 이름) | 반영됨 | :81 KO Fx `Name`과 거위 줄(GooseService 592)을 `PublicNameArg`로 바꿈, :97 Fx 행, :162 개발 2 담당. 코드 대조: `CombatService.luau:1394-1406`, `GooseService.luau:73-79,592`. Grudge·Kaiju·Progression·PvP의 같은 래퍼(`GrudgeService.luau:389`, `ProgressionService.luau:492` 등)는 :81의 "등"으로만 묶임. |
| 3 (교차로 현상수배판) | 일부 | :101 `BoardRows` JSON + `L10nText`, :154/:163 담당, 시험 5 :137 있음. 하지만 판은 주간 랭킹 줄과 **수배 줄** 두 부분인데(`PvPService.luau:889-901`, `:904-931`), `{Board, Rank, Name, Value, Outlaw}` 모양에는 수배 줄의 별 수(`Stars`)와 괴롭힘 표시(`Bully`)를 담을 칸이 없음. `Value`를 서버가 미리 꾸민 글로 보내는지 날 숫자로 보내는지(§4 :51과의 관계)도 정하지 않음. |
| 4 (Announce 조합기) | 반영됨 | :92 조합기를 `L10n.T`와 이름 키 도우미로 바꿈, :155 개발 1 담당. :80에서 `HiddenFaction` 이름 바꾸기 취소. 코드 대조: `AnnounceService.luau:55-66`, `Announce.luau:42-73`. |
| 5 (Plural) | 반영됨 | :58 "쓴 틀이 영어 틀이면", 시험 6 :140에 "ko에서 영어로 떨어진 경우 포함". |
| 6 (프롬프트 글) | 반영됨 | :96 글을 먼저 `Config.Text.Prompts.*`로 옮김, 시험 5 :138 `ActionKey`/`ObjectKey` 풀림 검사, :163 담당. 코드의 박힌 글과 일치: `MapBuilder.luau:662,663,816,847`, `TownNpcs.luau:142,145`. |
| v2-3 (영어 사본 예외) | 반영됨 | :16과 :86 두 곳 모두 "알림 대체 `Text` + 퀘스트 줄 기록용 `Text`"를 허용 예외로 적음. |
| v2-5 (이름표 속성) | 반영됨 | :100에 Nickname·NicknameVerified·SackVictimName 추가. `Util.luau:167-173`과 일치. `CharacterVisuals.luau:334-402`가 실제로 읽는 속성과도 맞음(Faction·Class는 :126-131). 줄 번호만 어긋남: SackVictimName은 1006이 아니라 `CharacterVisuals.luau:1014`(라벨 글은 :1029). |

**2. 새 문제 (v4 기준)**

1. **"Args 없음"이 무엇인지 정하지 않음.** `nil`인지 빈 표 `{}`인지 :55에 없습니다. 추측: `NotifyKey(p, key, {})`처럼 빈 표가 오면 :56 쪽으로 가서 막는 것 1번과 같은 깨짐이 다시 납니다. ":55의 Args 없음 = nil 또는 #Args == 0" 한 줄과 시험 6 사례 하나가 필요합니다.
2. **현상수배판 칸 부족** (위 3번의 나머지). 수배 줄 칸(`Stars`, `Bully`, `Board = "Wanted"`)을 넣고 `Value` 형식을 정해야 합니다.
3. **`L10nText` 태그 하나가 두 가지 일을 함.** :102는 `TextKey`로 글을 다시 넣는 일, :101은 `BoardRows`로 판을 그리는 일입니다. 클라 처리기가 어떻게 나눌지, 속성이 바뀔 때 다시 그리는지 정해지지 않았습니다. 또 `MapBuilder.luau:721`의 처음 `.Text = "Wanted Board"`를 키로 바꾼다는 말이 :101에 없습니다(:100 목록에 글자만 있음).
4. **시험 이름이 없는 규칙들.** 다음 서버 쪽 규칙은 §9의 어느 시험에도 나오지 않습니다(시험 5 :135-138은 알림·프롬프트·간판·이름표·판만 다룸).
   - KO Fx의 `Name`이 표인지, `TipIndex`가 있는지
   - `Bark` 줄 키, `SessionTitle` id
   - `KaijuHidden`
   - 펫 기본 이름 `""`과 옛 이름 옮기기
   - 퀘스트 `TextKey`/`Countless`
5. **클라 담당이 비어 있음.** 개발 2가 바꾸는 값(KO 화면의 `Name` 표·`Kind`·`TipIndex`, `Bark`, `SessionTitle`, `KaijuHidden`, 퀘스트 `TextKey`/`Countless`, 게시판 `Named`, 펫 종 이름 키)을 클라가 받아 그리는 일이 §10 개발 1 목록(:150-156)에 따로 없습니다. :164의 "첫 10분 화면부터"에 들어간다고 볼 수도 있습니다(추측). 하지만 KO 화면과 말풍선은 순서 밖이라 한쪽이 빈 채로 남을 수 있습니다.
6. **데이터에서 오는 프롬프트 ObjectText의 키를 정하지 않음.** `TownNpcs.luau:142,145`의 `entry.Label`, `PotionMerchantLabel`(`Config.luau:76`, "Fizzby")가 그렇습니다. :145는 Label이 없으면 `entry.Story` id를 그대로 띄웁니다. :96은 박힌 글만 옮기라고 합니다. 이름을 `keep_en`에 둘지, 표 경로를 키로 쓸지 정해야 합니다.
7. **기록이 틀림.** :3에 v3 확인을 "메모 붙여 승인"이라고 적었지만, 실제 판정은 revise입니다(`docs/review/l10n_contract_v3_check_2026-10-11.md:2,53`). 이력 문서라 고쳐 두는 편이 좋습니다.

**3. 맺음**

남은 것은 모두 칸 하나, 문장 하나를 더하는 크기입니다. 코드를 시작하기 전에 새 문제 1~3번을 계약에 넣으면 충분하고, 4~7번은 구현하면서 메워도 됩니다.

최종 판정: **approve-with-notes** — 막는 것(Args 없는 `%`)과 문제 2·4·5·6, v2-3·v2-5는 반영됐고, 현상수배판 수배 줄 칸, "Args 없음" 정의, 시험·클라 담당 빈칸 같은 작은 보완만 남았습니다.
