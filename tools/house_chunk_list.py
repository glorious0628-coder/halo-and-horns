"""Chunk decoration list per house (이미지 생성 3, 10/12; SPEC A23-150: decor = shadow-free 2D 4 views -> Tripo Smart Mesh ->
texture 'no lighting', made by the Blender 손보기 session; tiny bits are drawn and made as ONE chunk: dome + finial, door
leaf + hinges + knocker, lantern + arm, ...).

  py tools/house_chunk_list.py  -> docs/design/house_chunk_decor_2026-10-12.md

Reads tools/house_specs/<house>.json (window boxes, pots, awning, shop window, sign, roof extras) and the skeleton slot file
build/skel_rows/<house>_ornaments.json (domes, door leaves, knockers, hinges, lanterns, tower windows), and writes, per
house: chunk | what is drawn together | where it sits on the Studio skeleton (part / slot name, skeleton frame x, y = front,
z up, studs) | size (studs) | count. Sizes are the skeleton slot sizes, so the 2D for a chunk can be drawn at the right
proportions and the Tripo piece scaled onto the slot.
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OLD = ["HaloDomeHouse_%02d" % i for i in range(1, 13) if i != 7] + ["HaloShop_Bakery", "HaloShop_Flower", "HaloShop_Juice", "HaloShop_Potion"]
NEW = ["HaloNewHouse_" + h for h in ("Hill4", "Cliff6", "Cliff7", "Cliff8", "Garden5", "Garden6", "Garden7")]
# what the 2D shows that the skeleton has no part for (read off the 2D 4 views, 10/12 그림자 점검 sheets)
EXTRA_2D = {
    "HaloDomeHouse_01": ["지붕 화분 3개(상자 꽃)"],
    "HaloDomeHouse_05": ["지붕 동그란 나무 4", "지붕 유리 채광창"],
    "HaloDomeHouse_06": ["발코니 담쟁이·꽃"],
    "HaloDomeHouse_08": ["발코니 담쟁이 2", "현관 반돔"],
    "HaloDomeHouse_09": ["돔과 왼쪽 벽을 덮는 담쟁이"],
    "HaloDomeHouse_10": ["발코니 담쟁이(앞·옆)"],
    "HaloDomeHouse_12": ["지붕 퍼걸러 덩굴", "발코니 담쟁이"],
    "HaloShop_Bakery": ["간판 판", "빵 진열", "벽돌 돔 + 굴뚝 등", "벽 담쟁이 2"],
    "HaloShop_Flower": ["온실 지붕 + 식물", "벽 격자 장미 2", "문 앞 꽃 양동이"],
    "HaloShop_Juice": ["간판 판", "과일·주스 가판", "지붕 파라솔 + 과일 상자", "벽 담쟁이 2"],
    "HaloShop_Potion": ["간판 판", "물약 선반 진열", "문 앞 가마솥", "벽 담쟁이 3"],
    "HaloNewHouse_Hill4": ["굴뚝 연통"],
    "HaloNewHouse_Cliff6": ["별 꼭지"],
    "HaloNewHouse_Cliff7": ["문 위 금 메달 + 종"],
    "HaloNewHouse_Cliff8": ["돌출 발코니 망원경", "바다 창 그림"],
    "HaloNewHouse_Garden5": ["문 둘레 장미 아치", "해바라기 화단(앞·옆)"],
    "HaloNewHouse_Garden6": ["앞 왼쪽 모서리 연꽃 연못(+고사리)"],
    "HaloNewHouse_Garden7": ["별 + 화살 바람개비"],
}


def load(p):
    try:
        return json.load(open(p, encoding="utf-8"))
    except (OSError, ValueError):
        return None


def f2(v):
    return "%.1f" % v


L = ["# 덩어리 장식 목록 — 집 22채 (이미지 생성 3, 2026-10-12)", "",
     "SPEC A23-150: 벽·문틀·층·지붕 = Studio 파트 골격(그대로). 장식 = 그림자 없는 2D 4면 → Tripo 스마트 메시 → 텍스처 '조명 없이' "
     "(Blender 손보기 세션). **아주 작은 조각은 한 덩어리로 묶어 한 장에 그림**(돔+꼭지, 문짝+경첩+문고리, 등불+팔 …).",
     "", "- 자리 = 골격 파트/자리 이름 (골격 좌표: x 가로, y = 앞, z 위, 칸). 크기 = 그 자리 크기(2D 비율·Tripo 크기 맞출 때 기준).",
     "- 만드는 도구: `py tools/house_chunk_list.py` (스펙 tools/house_specs/*.json + 골격 자리 build/skel_rows/*_ornaments.json).",
     "- 집 07은 따로 만든 골격(tools/skeleton_house07.py) — 자리 이름 House07_*.", ""]
tot = {}
for h in OLD + ["House07"] + NEW:
    spec = load(os.path.join(ROOT, "tools", "house_specs", (h if h != "House07" else "HaloDomeHouse_07") + ".json")) or {}
    orn = load(os.path.join(ROOT, "build", "skel_rows", h + "_ornaments.json")) or load(os.path.join(ROOT, "build", "skel_%s_ornaments.json" % h)) or {"items": []}
    items = orn.get("items", [])
    rows = []
    # 1 domes (+ ribs + finial)
    for it in items:
        if it["type"] == "dome":
            nm = it["name"].split("_")[-1]
            hh = it.get("h", it["R"])
            rows.append(("돔 + 꼭지", "돔 + 갈빗대 + 꼭지(공·뾰족)", "%s (중심 %s, 바닥 z %s)" % (it["name"], ", ".join(f2(c) for c in it["pos"][:2]), f2(it["pos"][2])),
                         "지름 %s × 높이 %s (+꼭지)" % (f2(2 * it["R"]), f2(hh)), 1))
    # 2 door: leaf/leaves + hinges + knocker/knobs
    leaves = [it for it in items if it["type"] == "leaf"]
    if leaves or spec.get("door"):
        dw = spec.get("door", {}).get("w", 4.0)
        dh = spec.get("door", {}).get("h", 7.0)
        nh = sum(1 for it in items if it["type"] == "hinge")
        nk = sum(1 for it in items if it["type"] == "knocker")
        dbl = spec.get("door", {}).get("double", len(leaves) > 1)
        rows.append(("문", "문짝%s + 경첩 %d + 문고리 %d" % (" 2장" if dbl else "", nh, nk), "DoorFront 뒤 문 구멍 (Door_Leaf 자리, 앞면 y %s)" % (
            f2(leaves[0]["front"]) if leaves else "?"), "폭 %s × 높이 %s × 두께 0.3" % (f2(dw), f2(dh)), 1))
    # 3 lanterns: shade top + curved arm on the part lantern
    lans = [it for it in items if it["type"] == "lantern"]
    if lans:
        w_ = lans[0].get("w", 0.9)
        rows.append(("등불 + 팔", "둥근 갓 꼭지 + 굽은 벽 팔 (파트 등불 LampCap 위 · LampArm 자리)", "LampCap0..%d / LampArm0..%d" % (len(lans) - 1, len(lans) - 1),
                     "폭 %s × 높이 %s (갓 포함 ~2.0)" % (f2(w_ + 0.3), f2(lans[0].get("hgt", 1.15) + 0.9)), len(lans)))
    # 4 tower / drum arched window frames (small gold): one chunk per window kind
    aw = [it for it in items if it["type"] == "arch_window"]
    if aw:
        rows.append(("탑·드럼 창틀", "아치 창 금틀 + 창살", ", ".join(sorted({it["name"].split("_")[-1].rstrip("0123456789") for it in aw})),
                     "창 폭 %s" % f2(aw[0]["W"]), len(aw)))
    # 5 window-box planting (Tripo plant lump as is, A23-149 ④)
    wb = spec.get("window_boxes")
    if wb:
        rows.append(("창 화분 식물", "창 상자 위 꽃·잎 덩어리 (상자 = 골격)", "WBox_*_Soil (골격 흙판 위)", "상자 폭 ≈ 창 폭 + 0.6, 높이 ~1.0", "창마다"))
    # 6 pots
    for k, pt in enumerate(spec.get("pots", [])):
        rows.append(("화분 식물", "화분 위 나무·꽃 (화분 = 골격)", "Pot%d (x %s, y %s)" % (k, f2(pt[0]), f2(pt[1])), "화분 지름 %s, 식물 높이 ~%s" % (f2(pt[2]), f2(pt[2] * 1.2)), 1))
    # 7 shop
    if spec.get("shopwin"):
        sw = spec["shopwin"]
        rows.append(("진열", "진열창 안 물건 덩어리", "Shop_Glass 뒤 (u %s)" % sw.get("u", 0.5), "폭 %s × 높이 %s" % (f2(sw["w"]), f2(sw["h"])), 1))
    if spec.get("awning"):
        rows.append(("차양", "(골격 파트 천 — 장식 아님)", "Awning_*", "폭 %s" % f2(spec["awning"].get("w", 0)), "-"))
    # 8 roof extras from the spec
    top = spec.get("top", {})
    if top.get("hip", {}).get("chimney"):
        rows.append(("굴뚝 꼭대기", "굴뚝 갓·연통 덩어리", "Chimney_Cap 위", "폭 %s" % f2(top["hip"]["chimney"][2]), 1))
    if top.get("cupola") and not any(it["type"] == "dome" and "Cupola" in it["name"] for it in items):
        rows.append(("정자 돔", "작은 돔 + 공 꼭지 (정자 기둥 = 골격)", "Cupola 위", "지름 %s" % f2(2 * top["cupola"]["r"] + 0.7), 1))
    if top.get("topiary"):
        rows.append(("지붕 화분", "지붕 위 동그란 나무", "Topiary 자리 %d곳" % len(top["topiary"]), "지름 ~1.4", len(top["topiary"])))
    for e in EXTRA_2D.get(h if h != "House07" else "HaloDomeHouse_07", []):
        rows.append(("2D 장식", e, "(2D 그대로 자리 정함)", "-", "-"))
    tot[h] = len(rows)
    L += ["## %s" % h, "", "| 덩어리 | 한 장에 같이 그리는 것 | 붙는 곳 (골격) | 크기 (칸) | 수 |", "|---|---|---|---|---|"]
    for r in rows:
        L.append("| %s | %s | %s | %s | %s |" % r)
    L.append("")
L += ["## 빛 성 C2 (tools/skeleton_castle.py, 자리 build/skel_rows/HaloCastle_C2_ornaments.json)", "",
      "| 덩어리 | 한 장에 같이 그리는 것 | 붙는 곳 (골격) | 크기 (칸) | 수 |", "|---|---|---|---|---|",
      "| 날개 | 날개 + 받침 기둥 (좌·우 따로) | HaloCastle_C2_WingL/R (정면 옆 x ±9.8, z 24) | 높이 ~30 | 2 |",
      "| 장미창 | 8잎 무늬 + 금 틀 (유리·테 = 골격) | RoseGlass (z 22.4) | 지름 6.9 | 1 |",
      "| 후광 고리 | 정확한 원 고리 (Blender) | CentreTower_Spire 둘레 (z 46.5) | 지름 14.6 | 1 |",
      "| 별 꼭지 | 첨탑 꼭대기 금 별 | 첨탑 *_Finial 자리 | ~1.0 | 첨탑마다 |",
      "| 문짝 무늬 | 금 문짝 꽃 메달 + 세로 판 (문짝 = 골격 Door_LeafL/R) | Door_LeafL/R 앞면 | 4.6 × 11.1 | 2 |",
      "| 나무·생울타리 | 원뿔 나무 + 낮은 울타리 | 기단 위 (2D 자리) | 높이 2~4 | 2D대로 |", ""]
out = os.path.join(ROOT, "docs", "design", "house_chunk_decor_2026-10-12.md")
open(out, "w", encoding="utf-8", newline="\n").write("\n".join(L) + "\n")
print("[chunks]", len(tot), "houses,", sum(tot.values()), "rows ->", out)
