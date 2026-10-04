"""Measure actual MCP v2 Play captures; only diagnostic crops/comparisons.

Does not read failed white captures, alter sources, or call Studio.
"""
from pathlib import Path
import hashlib
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import label

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs/art/verification_2026-10-04/face_runtime_audit"
OUT = ROOT / "docs/art/verification_2026-10-04/face_sharpness_audit"


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def dark_component(image, box):
    left, top, right, bottom = box
    pixels = np.asarray(image.convert("RGB"), dtype=float)[top:bottom,left:right]
    components, n = label(pixels @ np.array([.2126,.7152,.0722]) < 100)
    sizes = np.bincount(components.ravel())
    sizes[0] = 0
    if not n:
        return None
    y,x = np.nonzero(components == np.argmax(sizes))
    return {"pixels":len(x), "bbox":[int(x.min()+left),int(y.min()+top),int(x.max()+left+1),int(y.max()+top+1)],
            "bbox_size":[int(x.max()-x.min()+1),int(y.max()-y.min()+1)],"luminance_threshold":100,
            "scope":"Largest dark 4-connected component inside manually reviewed eye ROI; not the full anatomical eye."}


def fit(crop, width, height, nearest=False):
    scale = min(width/crop.width,height/crop.height)
    return crop.resize((round(crop.width*scale),round(crop.height*scale)),
                       Image.Resampling.NEAREST if nearest else Image.Resampling.LANCZOS)


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    font_path = Path("C:/Windows/Fonts/malgun.ttf")
    font = ImageFont.truetype(str(font_path),22) if font_path.exists() else ImageFont.load_default()
    small = ImageFont.truetype(str(font_path),16) if font_path.exists() else ImageFont.load_default()
    dpath = ROOT / "art/out/Avatar_HaloArcherM_FullRedraw_D.png"
    dimage = Image.open(dpath).convert("RGB")
    reference_box = [190,0,1070,824]
    boxes = {
        "default":{"head":[744,417,873,553],"face":[768,494,855,546],"eye":[817,499,846,525]},
        "close":{"head":[632,280,1085,752],"face":[702,568,1005,735],"eye":[906,579,990,664]},
    }
    result = {"schema":1,"source":"Actual Play studio_mcp.screen_capture production_*_v2.jpeg only",
        "reference":{"path":str(dpath.relative_to(ROOT)),"sha256":sha(dpath),"head_crop":reference_box},
        "captures":[],"failed_earlier_white_captures_used":False,
        "method_ko":"네 원본 v2 화면을 직접 열어 확인했다. 눈·얼굴 ROI는 수동 범위이며 완전한 해부학적 분할이 아니다. 어두운 연결요소는 같은 밝기100 기준으로 재현한다.",
        "limitations_ko":["캡처 픽셀은 실제 GPU 내부 렌더 해상도나 mip 해상도와 같다는 뜻이 아니다.",
            "viewport 값은1586×950 캡처의 절반인793×475다. 두 좌표계를 구분한다.",
            "Automatic과 Level21은 그림자·밝기도 달라 픽셀 차이를 텍스처 압축 손실로 해석하지 않는다.",
            "기본 거리에서 눈이 작은 것은 샘플 수 자체의 한계다. 선명한 원화도 화면 픽셀 수보다 세밀하게 표시할 수 없다."],
        "studio_calls":0,"uploads":0,"source_mutations":0}
    sheet = Image.new("RGB",(1120,900),"#eeeeee")
    draw = ImageDraw.Draw(sheet)
    for row,distance in enumerate(("default","close")):
        y0 = row*440
        draw.text((18,y0+12),"기본 거리 12.5 stud" if distance=="default" else "가까이 3.5 stud",font=font,fill="black")
        for column,name in enumerate(("approved_D","Automatic","Level21")):
            x0 = 15 + column*370
            draw.text((x0,y0+48),{"approved_D":"승인 D 원본", "Automatic":"게임 · 기본 품질", "Level21":"게임 · 최고 품질"}[name],font=font,fill="black")
            if name == "approved_D":
                crop=dimage.crop(reference_box)
                preview=fit(crop,350,340)
            else:
                path=SOURCE/f"production_{name}_{distance}_v2.jpeg"
                image=Image.open(path).convert("RGB")
                metadata=json.loads(path.with_suffix(".json").read_text(encoding="utf-8"))
                assert sha(path)==metadata["capture"]["sha256"]
                assert list(image.size)==metadata["capture"]["size"]
                viewport=metadata["camera"]["viewport"]
                ratio=[image.width/viewport[0],image.height/viewport[1]]
                region=boxes[distance]
                component=dark_component(image,region["eye"])
                for part in ("head","eye"):
                    image.crop(region[part]).save(OUT/f"production_{name}_{distance}_v2_{part}_exact_pixels.png")
                result["captures"].append({"path":str(path.relative_to(ROOT)),"sha256":sha(path),
                    "capture_size":list(image.size),"engine_viewport":viewport,"capture_to_viewport_ratio":ratio,
                    "distance_stud":metadata["camera"]["distance"],"quality":metadata["render"]["QualityLevel"],
                    "head_roi_capture_px":region["head"],"face_roi_capture_px":region["face"],
                    "eye_roi_capture_px":region["eye"],
                    "eye_roi_capture_size":[region["eye"][2]-region["eye"][0],region["eye"][3]-region["eye"][1]],
                    "dark_eye_component":component,
                    "dark_eye_component_size_in_viewport_coordinates":[component["bbox_size"][i]/ratio[i] for i in (0,1)],
                    "roi_uncertainty_capture_px":3 if distance=="default" else 5,
                    "visual_ko":"하이라이트와 속눈썹이 여전히 흐리다. 최고 품질에서도 승인 D만큼 선명해지지 않았다."})
                preview=fit(image.crop(region["head"]),350,340,nearest=True)
            sheet.paste(preview,(x0+(350-preview.width)//2,y0+90+(340-preview.height)//2))
    draw.text((18,880),"비교용 크기 맞춤: 원본 Lanczos / 게임 픽셀 nearest · 원본 파일 수정 없음",font=small,fill="black")
    sheet.save(OUT/"production_v2_reference_comparison.png")
    result["comparison"]={"path":"docs/art/verification_2026-10-04/face_sharpness_audit/production_v2_reference_comparison.png",
                          "method":"Crop then fit each head to350x340; approved PNG Lanczos; screenshot nearest to show existing capture samples, no sharpening."}
    (OUT/"runtime_v2_image_measurements.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps([{"path":r["path"],"eye_dark_component_capture_px":r["dark_eye_component"]["bbox_size"],
                       "eye_dark_component_viewport_coordinates":r["dark_eye_component_size_in_viewport_coordinates"]} for r in result["captures"]],ensure_ascii=False))


if __name__ == "__main__":
    main()
