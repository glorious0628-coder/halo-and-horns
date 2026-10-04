// Typeset the fresh footer with the real Jua font. Never edits its source PNG.
// node tools/render_faction_footer_preview.cjs [--export]
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {pathToFileURL} = require('node:url');
let chromium;
try { ({chromium} = require('playwright')); }
catch { ({chromium} = require(path.resolve(path.dirname(process.execPath),'../node_modules/playwright'))); }
const ROOT=path.resolve(__dirname,'..');
const DIR=path.join(ROOT,'docs/art/verification_2026-10-04/faction_e');
const SOURCE=path.join(ROOT,'art/out/UI_FactionFooter_Fresh.png');
const HTML=path.join(DIR,'fresh_footer_preview.html');
const FONT=path.join(ROOT,'art/fonts/jua/Jua-Regular.ttf');
// Include the entire connected panel at alpha>0 with 2px native safety margin.
// Only the surrounding margin is cropped. No mask, erasure, or RGB edits.
const CROP={x:12,y:224,width:2148,height:264};
const TARGET_WIDTH=1024;
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const rel=p=>path.relative(ROOT,p).split(path.sep).join('/');

async function measure(page) {
 return page.evaluate(()=>{
  const el=document.querySelector('.copy'),box=el.getBoundingClientRect();
  const range=document.createRange();range.selectNodeContents(el);const text=range.getBoundingClientRect();
  const rect=r=>({x:r.x,y:r.y,width:r.width,height:r.height});
  return {fontLoaded:document.fonts.check('52px Jua','나중에 교차로 마을'),fontPx:parseFloat(getComputedStyle(el).fontSize),
   text:el.textContent.trim(),copyBox:rect(box),textRange:rect(text),
   overflow:text.left<box.left-.5||text.right>box.right+.5||text.top<box.top-.5||text.bottom>box.bottom+.5,
   lineCount:range.getClientRects().length,color:getComputedStyle(el).color};
 });
}

async function alphaInfo(page,bytes) {
 return page.evaluate(async data=>{
  const img=new Image();img.src='data:image/png;base64,'+data;await img.decode();
  const cv=document.createElement('canvas');cv.width=img.width;cv.height=img.height;
  const ctx=cv.getContext('2d',{willReadFrequently:true});ctx.drawImage(img,0,0);
  const rgba=ctx.getImageData(0,0,img.width,img.height).data;const bounds={};
  for(const threshold of [0,16,128]){
   let left=img.width,top=img.height,right=0,bottom=0,count=0;
   for(let y=0;y<img.height;y++)for(let x=0;x<img.width;x++)if(rgba[(y*img.width+x)*4+3]>threshold){
    left=Math.min(left,x);top=Math.min(top,y);right=Math.max(right,x+1);bottom=Math.max(bottom,y+1);count++;
   }
   bounds[threshold]={bounds:[left,top,right,bottom],pixels:count};
  }
  return {size:[img.width,img.height],thresholds:bounds};
 },bytes.toString('base64'));
}

(async()=>{
 const args=process.argv.slice(2);if(args.some(x=>x!=='--export'))throw Error('Usage: node tools/render_faction_footer_preview.cjs [--export]');
 const exportRequested=args.includes('--export');const source=fs.readFileSync(SOURCE);
 const sourceSha=sha(source),sourceData='data:image/png;base64,'+source.toString('base64');
 const config=fs.readFileSync(path.join(ROOT,'src/ReplicatedStorage/Shared/Config.luau'),'utf8');
 const semantic=config.split('SemanticText = {')[1];
 const expected=semantic?.match(/Footer\s*=\s*"([^"\r\n]*)"/)?.[1];
 if(!expected)throw Error('Cannot read Config.UIArt.FactionE.SemanticText.Footer');
 const browser=await chromium.launch({headless:true,channel:'msedge'});
 try{
  const page=await browser.newPage({viewport:{width:2172,height:724},deviceScaleFactor:1});
  await page.goto(pathToFileURL(HTML).href);
  await page.locator('.panel img').evaluate((img,src)=>{img.src=src},sourceData);
  await page.evaluate(async()=>{await document.fonts.ready;await Promise.all([...document.images].map(i=>i.decode()))});
  const selectedSize=await page.evaluate(()=>{
   const el=document.querySelector('.copy');
   for(let font=128;font>=20;font--){
    el.style.fontSize=font+'px';const range=document.createRange();range.selectNodeContents(el);const r=range.getBoundingClientRect();
    if(r.width<=el.clientWidth-12&&r.height<=el.clientHeight-12)return font;
   }
   throw Error('Footer cannot fit one line');
  });
  const native=await measure(page);
  if(!native.fontLoaded||native.overflow||native.lineCount!==1||native.text!==expected)throw Error('Footer font, fit, or semantic check failed');
  await page.screenshot({path:path.join(DIR,'fresh_footer_typed.png'),omitBackground:true});
  const scale=TARGET_WIDTH/CROP.width,height=Math.ceil(CROP.height*scale);
  await page.setViewportSize({width:TARGET_WIDTH,height});
  await page.evaluate(({crop,scale})=>{
   const panel=document.querySelector('.panel');
   Object.assign(panel.style,{transformOrigin:'0 0',transform:`translate(${-crop.x*scale}px,${-crop.y*scale}px) scale(${scale})`});
  },{crop:CROP,scale});
  const fitted=await measure(page);
  const png=await page.screenshot({path:path.join(DIR,'fresh_footer_1024_typed.png'),omitBackground:true});
  const alpha=await alphaInfo(page,png);
  if(fitted.overflow||fitted.lineCount!==1)throw Error('Target-resolution footer fit failed');
  for(const [name,color] of [['light','#ffffff'],['dark','#20242c']]){
   await page.evaluate(c=>document.body.style.background=c,color);
   await page.screenshot({path:path.join(DIR,`fresh_footer_1024_${name}.png`)});
  }
  // Nearest-neighbor 3x enlargement inspects the actual exported glyph pixels,
  // rather than hiding small-size issues by re-rendering larger text.
  const textBox=fitted.textRange;
  const zoom={x:Math.floor(textBox.x)-3,y:Math.floor(textBox.y)-3,
   width:Math.ceil(textBox.width)+6,height:Math.ceil(textBox.height)+6};
  await page.setContent('<html><body style="margin:0"></body></html>');
  await page.setViewportSize({width:zoom.width*3,height:zoom.height*3});
  await page.evaluate(async({data,zoom})=>{
   const img=new Image();img.src='data:image/png;base64,'+data;await img.decode();
   const cv=document.createElement('canvas');cv.width=zoom.width*3;cv.height=zoom.height*3;
   const ctx=cv.getContext('2d');ctx.imageSmoothingEnabled=false;ctx.fillStyle='#20242c';ctx.fillRect(0,0,cv.width,cv.height);
   ctx.drawImage(img,zoom.x,zoom.y,zoom.width,zoom.height,0,0,cv.width,cv.height);document.body.appendChild(cv);
  },{data:png.toString('base64'),zoom});
  await page.screenshot({path:path.join(DIR,'fresh_footer_text_3x.png')});
  if(sha(fs.readFileSync(SOURCE))!==sourceSha)throw Error('Source image changed during rendering');
  let output;
  if(exportRequested){output=path.join(ROOT,'art/ui/UIP_FactionFooter_FreshTyped.png');fs.writeFileSync(output,png);}
  const metrics={source:rel(SOURCE),sourceSha256:sourceSha,html:rel(HTML),htmlSha256:sha(fs.readFileSync(HTML)),
   font:rel(FONT),fontSha256:sha(fs.readFileSync(FONT)),sourceAlpha:await alphaInfo(page,source),
   crop:CROP,cropReason:'Complete alpha>0 main component plus 2 native pixels. Only surrounding margin cropped; no mask/color edits.',
   selectedFontPx:selectedSize,fontPxAt1024:selectedSize*scale,native,target:fitted,canvas:[TARGET_WIDTH,height],
   uniformScale:scale,alpha,semanticMatchesConfig:true,sourceImageModified:false,
   textZoom:{method:'nearest-neighbor actual target PNG glyph crop',crop:zoom,scale:3},
   export:output?{file:rel(output),sha256:sha(png)}:null,uploaded:false,
   sourceEdgeReview:'1024px light/dark QA passed visual inspection before typesetting. See fresh_footer_source_alpha_metrics.json.',
   typesetVisualReview:'pending'};
  fs.writeFileSync(path.join(DIR,'fresh_footer_type_metrics.json'),JSON.stringify(metrics,null,2)+'\n');
  console.log(JSON.stringify({output:metrics.export,canvas:metrics.canvas,selectedFontPx:selectedSize,fontPxAt1024:metrics.fontPxAt1024,textRange:fitted.textRange,overflow:fitted.overflow,alpha:alpha.thresholds}));
 }finally{await browser.close();}
})().catch(error=>{console.error(error.message);process.exit(1)});
