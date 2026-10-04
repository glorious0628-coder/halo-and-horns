// Local preview renderer only. Does not change production artwork or upload assets.
const fs = require('node:fs');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const {chromium} = require('playwright');

(async () => {
  const dir = path.resolve(__dirname, '../docs/art/verification_2026-10-04/faction_e');
  const browser = await chromium.launch({headless:true, channel:'msedge'});
  try {
    const page = await browser.newPage({viewport:{width:2172,height:724},deviceScaleFactor:1});
    await page.goto(pathToFileURL(path.join(dir,'fresh_premise_preview.html')).href);
    await page.evaluate(async () => { await document.fonts.ready; await Promise.all([...document.images].map(i => i.decode())); });
    const metrics = await page.evaluate(() => {
      const box = document.querySelector('.copy').getBoundingClientRect();
      return {fontLoaded:document.fonts.check('54px Jua'),lines:[...document.querySelectorAll('p')].map(p=>({text:p.textContent,width:p.getBoundingClientRect().width,scrollWidth:p.scrollWidth})),copyBox:{x:box.x,y:box.y,width:box.width,height:box.height},glyphColor:getComputedStyle(document.querySelector('.copy')).color};
    });
    if (!metrics.fontLoaded || metrics.lines.some(x => x.scrollWidth>x.width)) throw Error('Font or fit check failed');
    await page.screenshot({path:path.join(dir,'fresh_premise_typed.png'),omitBackground:true});
    // Approved production export: render the unchanged art + font together at the
    // target resolution. Crop only the transparent margin; do not stretch artwork.
    if (process.argv.includes('--export-approved')) {
      const crop = {x:67,y:184,width:2038,height:345};
      const scale = 1024/crop.width;
      const height = Math.ceil(crop.height*scale);
      await page.setViewportSize({width:1024,height});
      await page.evaluate(({crop,scale}) => {
        const panel = document.querySelector('.panel');
        Object.assign(panel.style,{transformOrigin:'0 0',transform:`translate(${-crop.x*scale}px,${-crop.y*scale}px) scale(${scale})`});
      },{crop,scale});
      const output = path.resolve(__dirname,'../art/ui/UIP_FactionPremise_FreshTyped.png');
      await page.screenshot({path:output,omitBackground:true});
      metrics.export={file:'art/ui/UIP_FactionPremise_FreshTyped.png',size:[1024,height],crop,scale,fontRenderedAtTargetResolution:true};
    }
    metrics.previewOnly=!process.argv.includes('--export-approved');
    metrics.artworkEdited=false;
    metrics.robloxFontAvailability='Jua has no verified native Roblox FontFamily. This is a local font preview, not proof of native Roblox support.';
    metrics.approval=process.argv.includes('--export-approved') ? 'approved' : 'pending';
    metrics.uploaded=false;
    fs.writeFileSync(path.join(dir,'fresh_premise_type_metrics.json'),JSON.stringify(metrics,null,2)+'\n');
    console.log(JSON.stringify(metrics));
  } finally {await browser.close();}
})().catch(e => {console.error(e.message);process.exit(1)});
