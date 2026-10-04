"""Prepare approved E sprites; generated cutout supplies only a coarse alpha guide.

All RGB comes from the approved source. No typography or ornament is redrawn.
The source-aligned cutouts are saved before uniform card-size normalization.
"""
from pathlib import Path
import hashlib
import json
import shutil

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'art/ui'
EVIDENCE = ROOT / 'docs/art/verification_2026-10-04/faction_e'
SOURCE = ROOT / 'docs/art/verification_2026-10-04/first_impression/faction_pointed_halo_E.png'
GUIDE = ROOT / 'art/out/UI_Faction_E_Transparent_Guide.png'
# Each rectangle is l,t,r,b. Guides are registered per object, never globally.
SPECS = {
    'FactionCardHaloE': ((238,259,602,886),(198,258,585,895)),
    'FactionCardHornsE': ((610,261,974,883),(589,258,988,893)),
    'FactionCardNeutralE': ((977,264,1340,880),(988,258,1370,893)),
    'FactionTitleRibbonE': ((514,25,1071,136),(483,3,1104,131)),
    'FactionPremisePanelE': ((240,127,1340,264),(225,115,1354,272)),
    'FactionFooterPanelE': ((326,882,1255,966),(300,881,1286,980)),
}

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    source = Image.open(SOURCE).convert('RGB')
    guide = Image.open(GUIDE).convert('RGBA')
    records = {}
    for key, (box, guide_box) in SPECS.items():
        rgb = np.asarray(source.crop(box)).copy()
        h, w = rgb.shape[:2]
        ga = guide.crop(guide_box).getchannel('A').resize((w,h), Image.Resampling.BILINEAR)
        binary = (np.asarray(ga) > 160).astype(np.uint8)
        # A conservative trim removes neighbouring panels from the generated guide.
        if key.startswith('FactionCard'):
            binary[:2,:] = 0
            binary[-2:,:] = 0
        kernel = np.ones((7,7),np.uint8)
        sure = cv2.erode(binary, kernel)
        band = cv2.dilate(binary, np.ones((17,17),np.uint8))
        mask = np.full((h,w), cv2.GC_BGD, np.uint8)
        mask[band > 0] = cv2.GC_PR_BGD
        mask[binary > 0] = cv2.GC_PR_FGD
        mask[sure > 0] = cv2.GC_FGD
        # No unrelated source background can enter from the crop border.
        mask[0,:] = mask[-1,:] = mask[:,0] = mask[:,-1] = cv2.GC_BGD
        cv2.setRNGSeed(0)
        cv2.grabCut(cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR), mask, None,
                    np.zeros((1,65),np.float64),np.zeros((1,65),np.float64),5,cv2.GC_INIT_WITH_MASK)
        fg = np.isin(mask,[cv2.GC_FGD,cv2.GC_PR_FGD]).astype(np.uint8)
        n, labels, stats, _ = cv2.connectedComponentsWithStats(fg,8)
        areas = stats[1:,cv2.CC_STAT_AREA]
        if not len(areas):
            raise RuntimeError(key + ': empty foreground')
        fg = (labels == (1 + int(areas.argmax()))).astype(np.uint8)
        # Source objects overlap by a few rows in the approved composition.
        # Exclude the neighbour's edge; this edits alpha only, never visible RGB.
        if key == 'FactionTitleRibbonE':
            fg[101:,:54] = 0
            fg[101:,90:469] = 0
            fg[101:,511:] = 0
            fg[107:,:] = 0
        elif key == 'FactionPremisePanelE':
            # Measured outer bevel in source pixels. GrabCut confuses its dark/gold
            # bottom edge with the town; a closed mask preserves the entire frame.
            fg[:] = 0
            cv2.fillPoly(fg,[np.array([(6,17),(22,2),(1079,2),(1093,17),
                (1093,117),(1077,134),(24,134),(6,118)],np.int32)],1)
        elif key == 'FactionFooterPanelE':
            fg[:] = 0
            cv2.fillPoly(fg,[np.array([(22,3),(907,3),(925,18),(925,67),
                (907,82),(22,82),(4,66),(4,18)],np.int32)],1)
        if not key.startswith('FactionCard'):
            hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
            # The approved cream/gold panels contain no blue; those pixels are
            # town/sky fringing picked up by the antialiased source boundary.
            fg[(hsv[:,:,0] >= 65) & (hsv[:,:,0] <= 135) & (hsv[:,:,1] > 35)] = 0
            # Recheck after trimming: detached neighbour pixels must not survive.
            n, labels, stats, _ = cv2.connectedComponentsWithStats(fg,8)
            fg = (labels == 1+int(stats[1:,cv2.CC_STAT_AREA].argmax())).astype(np.uint8)
        # Antialias only alpha, leaving every original RGB triplet unchanged.
        alpha = cv2.GaussianBlur(fg.astype(np.float32), (3,3), .45)
        alpha[fg > 0] = 1
        alpha = np.rint(alpha * 255).astype(np.uint8)
        if not key.startswith('FactionCard'):
            alpha[(hsv[:,:,0] >= 65) & (hsv[:,:,0] <= 135) & (hsv[:,:,1] > 35)] = 0
        cut = Image.fromarray(np.dstack([rgb,alpha]), 'RGBA')
        raw_path = EVIDENCE / (key + '_source_cutout.png')
        cut.save(raw_path)
        bounds = cut.getchannel('A').point(lambda x: 255 if x > 16 else 0).getbbox()
        trimmed = cut.crop(bounds)
        if key.startswith('FactionCard'):
            # Equal visible heights, same canvas: preserve original aspect ratio.
            target_h = 620
            factor = target_h / trimmed.height
            resized = trimmed.resize((round(trimmed.width*factor),target_h),Image.Resampling.LANCZOS)
            ready = Image.new('RGBA',(380,636))
            offset = ((380-resized.width)//2,8)
            ready.alpha_composite(resized,offset)
        else:
            factor = min(1,1020/trimmed.width)
            resized = trimmed.resize((round(trimmed.width*factor),round(trimmed.height*factor)),Image.Resampling.LANCZOS)
            ready = Image.new('RGBA',(resized.width+4,resized.height+4))
            offset = (2,2)
            ready.alpha_composite(resized,offset)
        name = 'UIP_' + key
        path = OUT / (name + '.png')
        ready.save(path)
        actual = ready.getchannel('A').point(lambda x:255 if x>16 else 0).getbbox()
        records[key] = {
            'file':path.relative_to(ROOT).as_posix(), 'size':list(ready.size), 'sha256':sha(path),
            'source_rect':list(box), 'guide_rect':list(guide_box), 'source_alpha_bounds':list(bounds),
            'alpha_bounds':list(actual), 'visible_height_px':actual[3]-actual[1],
            'scale':factor, 'paste_offset':list(offset),
            'source_cutout':raw_path.relative_to(ROOT).as_posix(),
            'source_cutout_rgb_max_delta':int(np.abs(np.asarray(cut)[:,:,:3].astype(int)-rgb.astype(int)).max()),
        }
    result = {'source':SOURCE.relative_to(ROOT).as_posix(),'source_sha256':sha(SOURCE),
              'alpha_guide':GUIDE.relative_to(ROOT).as_posix(),'alpha_guide_sha256':sha(GUIDE),
              'method':'GPT cutout alpha guide, per-object registration and edge refinement. Approved source RGB only; uniform final resizing.',
              'sprites':records,'roblox_upload_count':0}
    (EVIDENCE/'sprite_metrics.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(records,ensure_ascii=False,indent=2))

if __name__ == '__main__':
    main()
