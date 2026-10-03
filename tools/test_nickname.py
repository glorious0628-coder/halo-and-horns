"""Execute the real NicknameService/Util Luau against deterministic offline service doubles.

Requires the official Luau CLI (--luau), never contacts Studio or Roblox services.
Two server instances share the same atomic fake DataStore; failure injection commits before throwing.
"""
from pathlib import Path
import argparse
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
HARNESS = r'''
local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, item in value do out[key] = copy(item) end
    return out
end
local checks = 0
local function check(condition, message)
    assert(condition, message)
    checks += 1
end
local function execute(source, env)
    local fn, err = loadstring(source)
    assert(fn, err)
    setfenv(fn, setmetatable(env, { __index = getfenv() }))
    return fn()
end
local function makeDatabase()
    local db = { Rows = {}, Reads = 0, Writes = 0, Pause = false }
    function db:GetAsync(key, options)
        check(options.UseCache == false, "recovery read used cached data")
        self.Reads += 1
        if self.Pause then coroutine.yield() end
        if self.ReadFailure then error("read unavailable") end
        return copy(self.Rows[key])
    end
    function db:UpdateAsync(key, transform)
        if self.Pause then coroutine.yield() end
        local old = copy(self.Rows[key])
        local new = transform(old)
        local stage = string.sub(key, 1, 2) == "N_" and "claim" or "other"
        if stage == "other" and new then
            if new.Pending and (not old or not old.Pending) then stage = "begin"
            elseif old and old.Pending and not new.Pending then
                stage = new.Active and new.Active.Token == old.Pending.Token and "commit" or "clear"
            end
        end
        self.Writes += 1
        if self.BeforeUpdate then self.BeforeUpdate(key, stage) end
        if self.FailStage == stage and self.FailWhen == "before" then
            self.FailStage = nil
            error("response failed before write")
        end
        if new ~= nil then self.Rows[key] = copy(new) end
        if self.FailStage == stage and self.FailWhen == "after" then
            self.FailStage = nil
            error("write committed but response lost")
        end
        return copy(new)
    end
    return db
end
local function server(db, userId)
    local players = {}
    local attrs = {}
    local player = { UserId = userId, DisplayName = "Account" .. userId, Parent = players }
    function player:GetAttribute(key) return attrs[key] end
    function player:SetAttribute(key, value) attrs[key] = value end
    local fixture = { Player = player, Data = { Nickname = "UNTRUSTED_SAVED_VALUE" }, Config = {
        Nickname = { StoreName = "Test", ChangeInterval = 0 },
    }, GUID = 0, Persistent = true }
    local remotes = {}
    local enum = { TextFilterContext = { PublicChat = "PublicChat" } }
    local instance = { new = function(kind)
        assert(kind == "DataStoreGetOptions", "unexpected native object")
        return {}
    end }
    local shared = { Config = "Config", Util = "Util", Net = "Net" }
    local services = { Players = players, ReplicatedStorage = { Shared = shared },
        HttpService = { GenerateGUID = function()
            fixture.GUID += 1
            return string.format("test-token-%08d-%08d", userId, fixture.GUID)
        end },
        DataStoreService = { GetDataStore = function() return db end },
        TextService = { FilterStringAsync = function(_, raw, fromUserId, context)
            assert(fromUserId == userId and context == "PublicChat")
            fixture.FilterCalls = (fixture.FilterCalls or 0) + 1
            if fixture.FilterFailure then error("filter unavailable") end
            return { GetNonChatStringForBroadcastAsync = function()
                if fixture.BroadcastFailure then error("broadcast filter unavailable") end
                return fixture.FilterMap and fixture.FilterMap[raw] or raw
            end }
        end },
    }
    local game = { GetService = function(_, name) assert(services[name], name); return services[name] end }
    local util = execute(UTIL_SOURCE, { game = game, Random = { new = function() return {} end } })
    local net = { Get = function(name)
        if not remotes[name] then remotes[name] = {
            OnServerEvent = util.Signal.new(),
            FireClient = function(_, recipient, packet)
                assert(recipient == player)
                fixture.Result = packet
                if packet.Nickname ~= "" then check(util.ValidateNickname(packet.Nickname), "unsafe result") end
            end,
        } end
        return remotes[name]
    end }
    local registry = { PlayerService = {
        IsReady = function(p) return p == player and player.Parent == players end,
        SetStat = function(_, key, value)
            if fixture.SetStatFailure then error("player cache unavailable") end
            fixture.Data[key] = value
        end,
        PlayerReady = util.Signal.new(), PlayerLeaving = util.Signal.new(), CharacterSpawned = util.Signal.new(),
    }, DataService = { IsPersistentReady = function() return fixture.Persistent end } }
    local module = execute(SERVICE_SOURCE, { game = game, Enum = enum, Instance = instance,
        require = function(name)
            if name == "Config" then return fixture.Config end
            if name == "Util" then return util end
            if name == "Net" then return net end
            error("unexpected require")
        end,
        task = { spawn = function(fn, ...) fn(...) end },
    })
    module.Init(registry)
    module.Start()
    fixture.Service, fixture.Util, fixture.Registry = module, util, registry
    function fixture:Load() registry.PlayerService.PlayerReady:Fire(player) end
    function fixture:Change(text) module.SetNickname(player, text) end
    function fixture:Name() return util.PlayerDisplayName(player) end
    fixture:Load()
    return fixture
end
local function active(db, id) return db.Rows["U_" .. id] and db.Rows["U_" .. id].Active end
local function claimCount(db)
    local count = 0
    for key in db.Rows do if string.sub(key, 1, 2) == "N_" then count += 1 end end
    return count
end

-- Actual UTF-8 validation: boundaries, malformed bytes, hidden/control text and emoji.
do
    local s = server(makeDatabase(), 1)
    for _, name in { "홍길동", "별😀", "Knight", string.rep("가", 20), string.rep("😀", 20), "용 기사" } do
        check(s.Util.ValidateNickname(name), "valid Unicode rejected: " .. name)
    end
    for _, name in { "가", string.rep("가", 21), string.rep("😀", 21), "가\n나", "가\0나",
        "가" .. string.char(255) .. "나", "가" .. string.char(0xC0,0xAF) .. "나",
        "가" .. string.char(0xED,0xA0,0x80) .. "나", "가" .. utf8.char(0x200B) .. "나", "가" .. utf8.char(0x202E) .. "나",
        "##", "<b>가</b>", " 가나", "가나 ", "가  나" } do
        check(not s.Util.ValidateNickname(name), "invalid nickname accepted")
    end
    check(s.Util.NicknameCanonical("ALICE가Ä") == "alice가Ä", "canonical folded non-ASCII")
    check(s:Name() == s.Player.DisplayName and s.Data.Nickname == "", "unverified saved nickname leaked")
end

-- Supplemental policy runs against the real service, before/after broadcast filtering and on reload.
-- Positive examples protect ordinary Korean syllables, fantasy names and ASCII substring boundaries.
do
    local db = makeDatabase()
    local s = server(db, 2)
    for _, name in {
        "성기사", "천사", "사랑", "예수금", "신의검", "빛의사제", "교차로", "성수기사",
        "성장왕", "신나는기사", "교복전사", "하나님의검", "기독교", "불교", "예수", "알라딘",
        "하느님", "자유의여신", "불교의역사", "남자의검", "눈사람기사", "몬스터죽여",
        "죽어도용사", "노출없는기사", "시발점", "전화기전사", "숫자1234567890", "Knight+2026",
        "출생2000-01-01", "가방관리자", "초보개발자", "천사😀", "NakedMoleRat", "XXX기사",
        "HolyKnight", "DarkAngel", "GodSlayer", "LoveKnight", "Christian", "Essex", "Scunthorpe",
        "Sexton", "GrapeKnight", "Administrate", "SnowmenAreTrash", "Ａｎｇｅｌ", "９９용사",
    } do
        s:Change(name)
        check(s.Result.Status == "Active" and s:Name() == name, "context-safe nickname rejected: " .. name)
        check(active(db,2).Canonical == s.Util.NicknameCanonical(name), "policy normalization changed ownership")
    end
    local oldName, writes, calls = s:Name(), db.Writes, s.FilterCalls
    for _, name in {
        "성관계", "성행위", "성매매왕", "음란물", "야동기사", "포르노", "섹스", "강간",
        "알몸사진", "벗은사진", "누드사진", "나체사진", "야한사진보내",
        "예수믿어", "예 수 믿 어", "예수천국", "불신지옥", "교회오세요", "개종하라",
        "하나님믿으세요", "알라믿어", "기독교꺼져", "불교는쓰레기", "무슬림을죽여",
        "흑인박멸", "여자는열등", "장애인꺼져", "짱깨", "씨발", "자살해라",
        "sex", "S.e.x", "Porn123", "send nudes", "NudePhotos", "rape", "SexMaster",
        "JesusSaves", "believe in jesus", "convert to islam", "join my church", "KillJews",
        "death to muslims", "men are trash", "kill black people", "KillYourself",
        "무료로벅스", "공짜로벅스", "로벅스복사", "free robux", "ＲｏｂｕｘＧｅｎｅｒａｔｏｒ",
        "비밀번호알려", "인증번호줘", "send password", "카톡아이디", "전화번호줘", "우리집주소",
        "디스코드와", "add me discord", "abc@example.com", "https://evil.gg", "evil.gg", "www.evil.io",
        "０１０１２３４５６７８", "010-1234-5678", "123-456-7890", "+821012345678", "990101-1234567",
        "4111-1111-1111-1111", "공식운영자", "로블록스직원", "운영자123", "Ａｄｍｉｎ", "GM99",
        "official moderator", "RobloxStaff", "＃＃", "＜b＞가＜/b＞",
    } do
        s:Change(name)
        check(s.Result.Status == "Filtered" and s:Name() == oldName, "risky nickname accepted: " .. name)
        check(db.Writes == writes and s.FilterCalls == calls, "raw policy rejection performed external work")
    end
    -- A safe raw name cannot bypass the local policy when Roblox's returned text changes its meaning.
    for _, rejected in { "예수믿어", "send nudes", "관리자", "01012345678", "evil.gg", "여자죽어" } do
        s.FilterMap = { SafeInput = rejected }
        s:Change("SafeInput")
        check(s.Result.Status == "Filtered" and s:Name() == oldName and db.Writes == writes,
            "unsafe broadcast result was stored or exposed: " .. rejected)
    end
    s.FilterMap = nil
    -- Today's policy also protects stored names. Simulate a legacy row while retaining a genuine
    -- claim key/token; reads substitute that key's response without inventing a new reservation.
    s:Change("이전버전이름")
    local key
    for candidate, value in db.Rows do
        if string.sub(candidate,1,2) == "N_" and value.Canonical == "이전버전이름" then key = candidate end
    end
    local get = db.GetAsync
    db.Rows.U_2.Active.Text, db.Rows.U_2.Active.Canonical = "예수믿어", "예수믿어"
    function db:GetAsync(candidate, options)
        if string.sub(candidate,1,2) == "N_" then
            local claim = copy(self.Rows[key]); claim.Canonical = "예수믿어"
            check(options.UseCache == false, "legacy policy read used cache")
            return claim
        end
        return get(self,candidate,options)
    end
    s.Registry.PlayerService.PlayerLeaving:Fire(s.Player)
    s.Player:SetAttribute("Nickname", ""); s.Player:SetAttribute("NicknameVerified", false)
    writes, calls = db.Writes, s.FilterCalls
    s:Load()
    check(s:Name() == s.Player.DisplayName and s.Player:GetAttribute("NicknameStatus") == "Filtered",
        "legacy unsafe nickname exposed at join")
    check(db.Writes == writes and s.FilterCalls == calls, "legacy policy rejection changed durable claims")
end

-- Two independent server instances race for the same canonical name, including filter aliases.
for _, alias in { false, true } do
    local db = makeDatabase()
    local a, b = server(db, 10), server(db, 20)
    if alias then a.FilterMap = { AlphaInput = "홍길동" }; b.FilterMap = { BetaInput = "홍길동" } end
    db.Pause = true
    local tasks = {
        coroutine.create(function() a:Change(alias and "AlphaInput" or "Alice") end),
        coroutine.create(function() b:Change(alias and "BetaInput" or "alice") end),
    }
    for _ = 1, 30 do
        for _, co in tasks do
            if coroutine.status(co) ~= "dead" then local ok, err = coroutine.resume(co); assert(ok, err) end
        end
    end
    for _, co in tasks do check(coroutine.status(co) == "dead", "race did not complete") end
    check((a.Player:GetAttribute("NicknameVerified") == true) ~= (b.Player:GetAttribute("NicknameVerified") == true),
        "two players exposed the same name")
    check(claimCount(db) == 1, "same canonical produced multiple claims")
    check((a.Result.Status == "Taken") ~= (b.Result.Status == "Taken"), "loser not rejected")
end

-- An error can occur before or after each durable write. Existing names survive; recovery uses the saved token.
for _, stage in { "begin", "claim", "commit" } do
    for _, when in { "before", "after" } do
        local db = makeDatabase()
        local s = server(db, 30)
        s:Change("첫이름")
        check(s:Name() == "첫이름", "setup failed")
        db.FailStage, db.FailWhen = stage, when
        s:Change("새이름")
        check(s.Result.Status == "Unknown" and s:Name() == "첫이름", "ambiguous write changed the visible nickname")
        local pending = db.Rows.U_30.Pending
        local operationToken = pending and pending.Token or active(db, 30).Token
        s:Change("다른요청")
        check(s.Result.Status == "Recovered", "unknown response was not resolved first")
        check(s:Name() ~= "다른요청", "recovery started a new intent blindly")
        if stage ~= "begin" or when == "after" then
            check(s:Name() == "새이름" and active(db, 30).Token == operationToken, "recovery did not retain operation token")
        else check(s:Name() == "첫이름", "non-committed begin changed name") end
        local other = server(db, 31)
        other:Change("첫이름")
        check(other.Result.Status == "Taken", "old alias was freed during uncertain recovery")
    end
end

-- Filtering or unavailable stores never reserve a nickname. A filter containing # is never shown.
do
    local db = makeDatabase()
    local s = server(db, 40)
    s:Change("기존이름")
    local writes = db.Writes
    s.FilterMap = { NewInput = "####", PartialInput = "홍#동" }
    for _, raw in { "NewInput", "PartialInput" } do
        s:Change(raw)
        check(s.Result.Status == "Filtered" and s:Name() == "기존이름", "filtered placeholder exposed")
    end
    s.FilterFailure = true
    s:Change("다른이름")
    check(s.Result.Status == "FilterUnavailable" and db.Writes == writes, "filter failure reserved a name")
    s.FilterFailure = false; s.BroadcastFailure = true
    s:Change("다른이름")
    check(s.Result.Status == "FilterUnavailable" and db.Writes == writes, "broadcast failure reserved a name")
    s.BroadcastFailure = false; s.Persistent = false
    s:Change("다른이름")
    check(s.Result.Status == "Unavailable" and s:Name() == "기존이름" and db.Writes == writes,
        "Studio memory mode pretended to reserve a nickname")
end

-- Rejoin re-filters the directory; a now-filtered name is hidden and never reused under a changed canonical.
do
    local db = makeDatabase()
    local s = server(db, 50)
    s:Change("저장이름")
    s.Registry.PlayerService.PlayerLeaving:Fire(s.Player)
    s.Player:SetAttribute("Nickname", ""); s.Player:SetAttribute("NicknameVerified", false)
    s.FilterMap = { ["저장이름"] = "변형이름" }
    s:Load()
    check(s:Name() == s.Player.DisplayName and s.Player:GetAttribute("NicknameStatus") == "Filtered",
        "rejoin exposed transformed text without its own canonical claim")
end

-- Unknown claim + subsequent policy rejection clears only the exact pending intent, never a claim.
for _, rejected in { "###", "예수믿어", "free robux", "01012345678" } do
    local db = makeDatabase()
    local s = server(db, 60)
    s:Change("옛이름")
    db.FailStage, db.FailWhen = "claim", "after"
    s:Change("새이름")
    s.FilterMap = { ["새이름"] = rejected }
    s:Change("다른이름")
    check(s.Result.Status == "Filtered" and db.Rows.U_60.Pending == nil, "rejected recovery intent got stuck")
    check(claimCount(db) == 2 and s:Name() == "옛이름", "recovery removed a durable claim")
    s:Change("허용이름")
    check(s.Result.Status == "Active" and s:Name() == "허용이름", "cleared intent blocked future changes")
end

-- Player-save/cache failures cannot free globally committed names or expose an unconfirmed value.
do
    local db = makeDatabase()
    local s = server(db, 70)
    s:Change("이전이름")
    s.SetStatFailure = true
    s:Change("완료이름")
    check(s.Result.Status == "Unknown" and s:Name() == "이전이름", "cache failure changed visible nickname")
    s.SetStatFailure = false
    s:Change("무시이름")
    check(s.Result.Status == "Recovered" and s:Name() == "완료이름", "authoritative directory could not recover")
    local other = server(db, 71)
    other:Change("완료이름")
    check(other.Result.Status == "Taken", "cache failure allowed duplicate claim")
end

-- Malformed or colliding claims fail closed and are never overwritten.
do
    local db = makeDatabase()
    local s = server(db, 80)
    s:Change("검사이름")
    local claimKey
    for key in db.Rows do if string.sub(key, 1, 2) == "N_" then claimKey = key end end
    db.Rows[claimKey].Canonical = "다른정규값"
    s:Change("검사이름")
    check(s.Result.Status == "Taken" and db.Rows[claimKey].Canonical == "다른정규값", "hash collision overwrote claim")
end

-- Same-owner aliases are reusable without overwriting the immutable claim token.
do
    local db = makeDatabase()
    local s = server(db, 90)
    s:Change("Alice")
    local firstClaimToken = active(db, 90).ClaimToken
    s:Change("둘째이름")
    s:Change("ALICE")
    check(s:Name() == "ALICE" and active(db, 90).ClaimToken == firstClaimToken and claimCount(db) == 2,
        "own alias could not be reused safely")
    local other = server(db, 91)
    other:Change("alice")
    check(other.Result.Status == "Taken", "reused alias allowed a duplicate")
end

-- Reentrant remote requests are refused while a yielding operation owns the local slot.
do
    local db = makeDatabase()
    local s = server(db, 100)
    local called = false
    db.BeforeUpdate = function(_, stage)
        if stage == "begin" and not called then
            called = true
            s:Change("겹친요청")
            check(s.Result.Status == "Busy", "reentrant remote bypassed busy slot")
        end
    end
    s:Change("첫요청")
    check(called and s:Name() == "첫요청" and claimCount(db) == 1, "reentrant request wrote another name")
end

-- Execute the actual standing-height/cosmetic-pivot helpers; each placement starts from the same base pivot.
do
    local vec = { new = function(x,y,z) return { X=x, Y=y, Z=z } end }
    local mt = { __add = function(p,v) return setmetatable({ X=p.X+v.X, Y=p.Y+v.Y, Z=p.Z+v.Z, Yaw=p.Yaw }, getmetatable(p)) end }
    local env = { Enum = { HumanoidRigType = { R15="R15", R6="R6" } }, Vector3=vec }
    local helpers = execute(HEIGHT_SOURCE .. "\nreturn { standingHeight, cosmeticPivot }", env)
    local height, pivot = helpers[1], helpers[2]
    local character = { FindFirstChild = function(_,name)
        if name == "Left Leg" then return { Size={Y=2}, IsA=function() return true end } end
    end }
    local root = { Size={Y=2}, IsA=function() return true end }
    local original = { HipHeight=2.2, RigType="R15" }
    local pilot = { HipHeight=0.811379075050354, RigType="R15" }
    check(math.abs(height(character, original, root)-3.2)<1e-9, "R15 standing height incorrect")
    check(height(character, {HipHeight=0,RigType="R6"}, root)==3, "R6 standing height omitted leg")
    local context = { OriginalPivot=setmetatable({X=14,Y=3.277,Z=-7,Yaw=1.2},mt), StandingHeight=3.2 }
    local first = pivot(character,pilot,root,context)
    local repeated = pivot(character,pilot,root,context)
    check(first.Y==repeated.Y and first.X==14 and first.Z==-7 and first.Yaw==1.2, "height adjustment accumulated or moved XZ/facing")
    check(math.abs(first.Y-(3.277+0.811379075050354+1-3.2))<1e-9, "pilot Y correction incorrect")
    local returnContext = {OriginalPivot=first,StandingHeight=height(character,pilot,root)}
    local back = pivot(character,original,root,returnContext)
    check(math.abs(back.Y-3.277)<1e-9, "ON/OFF pair changed the feet's height")
    local noHeight = {OriginalPivot=context.OriginalPivot}
    check(pivot(character,pilot,root,noHeight).Y==3.277, "missing standing snapshot altered normal spawn")
    pilot.HipHeight *= 2; root.Size.Y *= 2
    local scaled = pivot(character,pilot,root,context)
    check(math.abs(scaled.Y-(3.277+height(character,pilot,root)-3.2))<1e-9, "post-spawn scaling used stale standing height")
end
print("NICKNAME_OFFLINE_OK checks=" .. checks .. " Studio/API calls=0")
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--luau', type=Path, default=ROOT / 'build/luau_cli_0_741/luau.exe')
    args = parser.parse_args()
    if not args.luau.is_file():
        parser.error('Pass --luau with an installed official Luau CLI; this test never downloads tools.')
    sources = {
        'UTIL_SOURCE': ROOT / 'src/ReplicatedStorage/Shared/Util.luau',
        'SERVICE_SOURCE': ROOT / 'src/ServerScriptService/NicknameService.luau',
    }
    out = ROOT / 'build/nickname_offline_test.luau'
    out.parent.mkdir(exist_ok=True)
    declarations = '\n'.join(f'local {name} = {json.dumps(path.read_text(encoding="utf-8"), ensure_ascii=False)}'
                             for name, path in sources.items())
    player_source = (ROOT / 'src/ServerScriptService/PlayerService.luau').read_text(encoding='utf-8')
    height_source = player_source[player_source.index('-- Humanoid.HipHeight uses'):player_source.index('local function onCharacterAdded')]
    declarations += '\nlocal HEIGHT_SOURCE = ' + json.dumps(height_source, ensure_ascii=False)
    out.write_text(declarations + '\n' + HARNESS, encoding='utf-8')
    completed = subprocess.run([str(args.luau.resolve()), str(out)], cwd=ROOT, capture_output=True, text=True,
                               encoding='utf-8', errors='replace')
    print(completed.stdout, end='')
    print(completed.stderr, end='')
    return completed.returncode


if __name__ == '__main__':
    raise SystemExit(main())
