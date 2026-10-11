"""halo_fixed_points.py (이미지 생성 1, 2026-10-11): the 6th-stage fixed-point table of the new Halo island, from the plan JSON.

  py -X utf8 tools/halo_fixed_points.py     -> docs/design/halo_fixed_points_v2_2026-10-11.md

One page for 메인 반영 1 / 게임성 개발: what stays, what moves to where (Config line + new value), what grows (zone rectangle, land,
bounds), what is redrawn (big map, minimap) and which tests to rerun. Numbers come from docs/design/halo_plan_v2_2026-10-11.json
(positions already include the 1.5x grow of stage 3 / 3rd round)."""
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = json.load(open(os.path.join(ROOT, "docs", "design", "halo_plan_v2_2026-10-11.json"), encoding="utf-8"))
OUT = os.path.join(ROOT, "docs", "design", "halo_fixed_points_v2_2026-10-11.md")
land = P["land"]
x0, x1 = min(p[0] for p in land), max(p[0] for p in land)
z0, z1 = min(p[1] for p in land), max(p[1] for p in land)
M = 10                                        # margin round the land for the zone rectangle
ZX0, ZX1, ZZ0, ZZ1 = math.floor(x0 - M), math.ceil(x1 + M), math.floor(z0 - M), -330   # north bound = the gate line (as before)
ZC = ((ZX0 + ZX1) / 2, (ZZ0 + ZZ1) / 2)
ZS = (ZX1 - ZX0, ZZ1 - ZZ0)
BND_MINX, BND_MINZ = ZX0 - 10, ZZ0 - 10
OUT_X0, OUT_X1, OUT_Z0, OUT_Z1 = BND_MINX, 1840, BND_MINZ, 720        # Outskirts must cover the whole world
OC = ((OUT_X0 + OUT_X1) / 2, (OUT_Z0 + OUT_Z1) / 2)
OS = (OUT_X1 - OUT_X0, OUT_Z1 - OUT_Z0)
mv = {m["name"]: m for m in P["fixed_points"]["move"]}
falls = {f["id"]: f for f in P["water"]["falls"]}
B = {b["id"]: b for b in P["buildings"]}
pools = {w["id"]: w for w in P["water"]["pools"]}


def v(x, y, z):
    return "Vector3.new(%s, %s, %s)" % (fm(x), fm(y), fm(z))


def fm(n):
    s = ("%.2f" % n).rstrip("0").rstrip(".")
    return "0" if s in ("", "-0") else s


def new_xyz(name):
    n = mv[name]["new_xyz"]
    return n


L = []
a = L.append
a("# 빛 마을 v2 — 6단계 고정점 표 (새 섬에서 어디로 가나)")
a("")
a("> 이미지 생성 1, 2026-10-11. `py -X utf8 tools/halo_fixed_points.py`로 계획 JSON에서 다시 만든다(손으로 고치지 말 것). "
  "계획의 좌표는 3단계 3차(1.5배 키움)가 이미 반영된 최종 값이다. **6단계(메인에 한 번에) 직전에 이 표대로 Config·시험을 일괄로 고친다.**")
a("> 코드는 plan JSON을 읽지 않는다. 고정점은 Config 값·이름·태그다. 줄 번호는 이 표를 만들 때(origin/main) 기준이라 조금 어긋날 수 있으니 이름으로 찾는다.")
a("")
a("## A. 그대로 (건드리지 않음)")
a("")
a("| 무엇 | 값 | 어디 |")
a("|---|---|---|")
a("| 다리 Bridge_Halo | (0,0,-150) → (0,0,-330), 폭 22, 갑판 Y ~0.2 | `Config.Map` Bridges `Halo` (Config 1810) |")
a("| 성문 Gate_HaloTown | 위치 (0,0,-330), PrimaryPart `Lintel` (새 골격의 Lintel 앞 반쪽 금 코니스가 (0,-330)에 앵커) | `Config.Map` Gates (1784), MapBuilder `placeGate`가 매번 맞춤 |")
a("| 스폰 / 보는 쪽 | Spawn (0,0,-420), SpawnLook (0,0,-330) | `Config.Zones.HaloTown` (1640~1641) |")
a("| 스폰-문 통로 | 가운데 x ±12 안, z -330..-432와 (0,-420) 반경 12는 비움 | plan 검사 `스폰-문 통로 막음` 0건 |")
a("| 길잡이 Bright | At (18,0,-424), Look (18,0,-380) | `Config.TownNpcs` (3722) |")
a("| 이동 발판 | Pad_Halo_SlimeMeadow (-24,0.7,-357), Pad_Halo_GoblinWoods (24,0.7,-357) | `Map.Pads`, 가운데(x ±40 안) 안 |")
a("| 오프닝 조각 착지 | SPOT.Halo (0,16,-410) | `Intro.luau` 40 |")
a("| 큰 지도 라벨 | HaloTown (0,0,-400) | `WorldMap.luau` 77 |")
a("| 분수 이름 | `Town_Halo_Fountain3` (FountainFx), 등불 `LampLight`, 충돌 그룹 `DecorPlayerOnly` | 이름 규칙 |")
a("")
a("## B. 옮김 (Config 줄 → 새 값)")
a("")
a("| 무엇 | 지금 | 새 값 | 어디 |")
a("|---|---|---|---|")
hs = new_xyz("영웅상 HeroStatue")
a("| 영웅상 HeroStatue | (0,0,-370) | `%s` (큰 길 통로 x ±12 안 밖; 높은 층이면 `StoryLandmark` 태그 + `Spot=\"HeroStatue\"`) | `Config.StoryQuests.Landmarks.HeroStatue` (3538); H6 Near 16 |" % v(*hs))
g = new_xyz("Sir Gleam")
a("| Sir Gleam | At (-10,0,-372) Look (0,0,-372) | At `%s`, Look 큰 길 쪽 `%s` | `Config.TownNpcs` Gleam (3724) |" % (v(*g), v(0, 0, g[2])))
for nm, cid, line in (("물약 상인 PotionHalo", "PotionHalo", 3735), ("Folk3 빵집", "Folk3", 3730), ("Folk1 주스", "Folk1", 3726),
                      ("Folk2 꽃", "Folk2", 3728), ("Folk4 분수", "Folk4", 3732)):
    n = new_xyz(nm)
    now = mv[nm]["now"]
    a("| %s | At (%s,0,%s) | At `%s` (Y %s; 12칸 안에서 팜/말함) | `Config.TownNpcs` %s (%d) — Look도 문 쪽으로 같이 |" % (nm, fm(now[0]), fm(now[1]), v(n[0], 0, n[2]), fm(n[1]), cid, line))
tr = new_xyz("훈련장 (새)")
a("| 훈련장 표시 (새) | 없음 | `%s` (Landmark `TrainingYard` + 허수아비 표적; 첫 기술 퀘스트가 여기를 가리킴) | 새 Landmark, 게임성 개발 |" % v(*tr))
wf = ["W1", "W2", "W3"]
ys = {"W1": 1, "W2": 20, "W3": 10}
spots = ", ".join(v(falls[w]["at"][0], ys[w], falls[w]["at"][1]) for w in wf)
a("| 폭포 소리 | 6곳 (±188,3,-493) (±190,7,-582) (±190,11,-660) | 3곳 `%s` (W1 성문 서쪽 1단 → 바다, W2 계단 폭포 3단, W3 동쪽 절벽 2단) — 또는 `Map.Decor` 바로 아래 이름이 `…Waterfall`인 것 | `Config.Audio.Ambient.Waterfall.Spots` (5576) |" % spots)
a("| 분수 | (22,..) 옛 | 풀 중심 `%s`, 반지름 %s (2단, 이름 `Town_Halo_Fountain3`) | 새 분수 모델(5단계) |" % (v(pools['fountain']['at'][0], pools['fountain']['y'], pools['fountain']['at'][1]), pools['fountain']['r']))
a("")
a("## C. 넓힘 (땅이 커졌다: x %s..%s, z %s..%s)" % (fm(x0), fm(x1), fm(z0), fm(z1)))
a("")
a("섬이 이웃 땅과 안 겹침(초원 z -240..240, 십자로 ±150; 빛 마을은 z -330보다 남쪽). 가장 높은 땅 Y %s < 물 구조 MaxRise 42 그대로." % fm(max(d['y'] for d in P['districts'])))
a("")
a("| 무엇 | 지금 | 새 값 | 어디 |")
a("|---|---|---|---|")
a("| HaloTown 구역 상자 (PvP 안전·마을 음악·Enter 퀘스트·적 진영 튕겨내기·몬스터 추적 한계) | Center (0,0,-515) Size (400,0,370) | Center `%s` Size `%s` (x %s..%s, z %s..%s) | `Config.Zones.HaloTown` (1638) |" % (
    v(ZC[0], 0, ZC[1]), v(ZS[0], 0, ZS[1]), fm(ZX0), fm(ZX1), fm(ZZ0), fm(ZZ1)))
a("| 섬 땅 IslandHalo | MinX -200 MaxX 200 MinZ -700 MaxZ -330 | MinX %s MaxX %s MinZ %s MaxZ %s (실제 해안은 `plan.land` 다각형; Terrain은 5·6단계 블록아웃 지형) | `Config.Map.Lands` (1801) |" % (fm(ZX0), fm(ZX1), fm(ZZ0), fm(ZZ1)))
a("| 세계 경계 Bounds | MinX -260 MaxX 1840 MinZ -720 MaxZ 720 | MinX %s MinZ %s (MaxX·MaxZ 그대로: 뿔 마을은 그대로라 남북이 비대칭) | `Config.Map.Bounds` (1766) |" % (fm(BND_MINX), fm(BND_MINZ)))
a("| Outskirts (그 밖 전부) | Center (790,0,0) Size (2100,0,1440) | Center `%s` Size `%s` (세계 전체를 덮어야 함) | `Config.Zones.Outskirts` (1674) |" % (v(OC[0], 0, OC[1]), v(OS[0], 0, OS[1])))
a("| 미니맵 띠 RoadNorthIsland | x -8..8, z -600..-330 (곧은 띠) | 새 큰 길은 굽어 있어 곧은 띠로는 안 맞음 → 미니맵 타일을 새 지형에서 다시 찍고, 이 띠는 `plan.roads[main]` 꼭짓점을 따라 이은 여러 사각형으로 바꾸거나 지움(게임성 개발·메인 반영 1 확인) | `Config.Map` (1825, 1845) |")
a("| 마을 음악 / 안전 구역 | 구역 상자를 따름 | 위 구역 상자로 자동 | |")
a("")
a("## D. 다시 그림")
a("")
a("- **큰 지도 그림**(WorldMapV2 94679214685541): 섬 모양·크기가 그림에 박혀 있어 새 섬으로 다시 그린다(이미지 생성 2). 라벨 위치는 위 A.")
a("- **미니맵 Halo MapTiles**: 새 지형에서 다시 찍는다(메인 반영 1). 타일 범위는 구역 상자와 같게.")
a("")
a("## E. 건물·장식이 들어가며 따라 바뀌는 것 (참고)")
a("")
a("| 건물 | 새 자리 (x, z) | 지반 Y |")
a("|---|---|---|")
for bid in ("Gate", "Tower_GateEast", "Shop_Potion", "Shop_Bakery", "Shop_Juice", "Shop_Flower", "Armory", "Castle", "Cathedral", "Tower_Lookout"):
    b = B[bid]
    a("| %s | (%s, %s) | %s |" % (bid, fm(b["x"]), fm(b["z"]), fm(b["ground_y"])))
a("")
a("## F. 6단계에서 다시 돌릴 시험 (옛 json 경로가 박힌 것은 v2 json으로)")
a("")
a("- 지도·마을 퀘스트·NPC: `test_map_v2`, `test_town_quests`, `test_town_npcs` (옛 `halo_layout_plan_2026-10-10.json` 경로 → `halo_plan_v2_2026-10-11.json`)")
a("- 스폰·분수: `test_spawn_look`, `test_fountain_fx`")
a("- 땅·물: `test_ground_rays`, `water_rescue`")
a("- 소리·퀘스트 표시·복귀·카이주: `audio_offline`(폭포 소리 3곳), `quest_target_offline`(Pad), `return_offline`, `kaiju_town_offline`")
a("")
a("## G. 메모")
a("")
a("- 걷는 바닥은 `WalkGround` 태그(Config.Ground.Tag) 또는 Terrain: 전망 탑 발코니 바닥(`BalconyFloor`)은 이미 태그가 달려 있고, 길·광장·마당·계단·다리 파트 골격은 새 생성기에서 전부 태그를 단다.")
a("- 성문 모델 이름은 지금 `Gate`(회색 상자 자리). 6단계에서 `Gate_HaloTown`으로 바꾸고 `Map.Gates` 아래로 옮긴다(PrimaryPart `Lintel`).")
a("- 떠 있는 섬: 둘레 20칸 물 띠 + 낮은 바위 테, 그 밖은 하늘. 메인에 넣을 때 하늘·구름이 같은 규칙인지(메인 반영 1과 확인).")
open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(L) + "\n")
print("wrote", OUT, "zone Center", ZC, "Size", ZS)
