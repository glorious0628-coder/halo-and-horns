# 스위치판 쓰기 — Studio 명령창에 붙여넣기 (게임성 개발 3, 2026-10-09)

Roblox Studio에서 **게임 장소(Beta 또는 Live)를 연 상태로** 하단 Command Bar에 한 줄씩 붙여넣어요(Play 필요 없음; Studio 설정 > Security에서 Studio Access to API Services가 켜져 있어야 해요). `ENV`는 그 장소의 환경: 개발 장소는 빈 문자열 `""`, 베타는 `"_Beta"`, 정식은 `"_Live"`. 서버가 60초 안에 읽어요.

```lua
-- 패스 판매 끄기 (PassSales / Halloween / CrownWar / Goose 중 하나)
local ENV = "_Live"; local KEY = "PassSales"; local VALUE = false
game:GetService("DataStoreService"):GetDataStore("HaloHorns_Switches_v1" .. ENV):UpdateAsync("Live", function(old) old = type(old) == "table" and old or {}; old.Set = type(old.Set) == "table" and old.Set or {}; old.Set[KEY] = VALUE; old.At = os.time(); return old end)
```

```lua
-- 지금 상태 보기
local ENV = "_Live"
print(game:GetService("HttpService"):JSONEncode(game:GetService("DataStoreService"):GetDataStore("HaloHorns_Switches_v1" .. ENV):GetAsync("Live")))
```

```lua
-- 모두 기본값으로 되돌리기 (문서를 비움)
local ENV = "_Live"
game:GetService("DataStoreService"):GetDataStore("HaloHorns_Switches_v1" .. ENV):SetAsync("Live", { Set = {}, At = os.time() })
```

- 허용된 키(PassSales, Halloween, CrownWar, Goose)와 true/false 말고는 서버가 무시해요(철자가 틀리면 아무 일도 안 일어남).
- 읽기가 실패한 서버는 마지막 값을 유지해요. 끈 것이 풀리려면 `VALUE = true`로 쓰거나 문서를 비워요.
- 서버 오류 보기: 게임을 Play한 Studio에서 `game.ServerScriptService.DebugCommand:Invoke("Player1", "Errors", "live")`.
