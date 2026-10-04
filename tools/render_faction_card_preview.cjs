// Typeset approved fresh GPT card art without modifying its source PNG.
// node tools/render_faction_card_preview.cjs --card halo|horns|neutral [--export]
// Headless browser only. No Studio, upload, paid API, or source-image edits.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {pathToFileURL} = require('node:url');
let chromium;
try { ({chromium} = require('playwright')); }
catch { ({chromium} = require(path.resolve(path.dirname(process.execPath),'../node_modules/playwright'))); }

const ROOT = path.resolve(__dirname,'..');
const DIR = path.join(ROOT,'docs/art/verification_2026-10-04/faction_e');
const CARDS = {halo:'Halo',horns:'Horns',neutral:'Neutral'};
const EXPORT = {width:570,height:954,padding:12,bodyHeight:930,alphaThreshold:16};
const sha = data => crypto.createHash('sha256').update(data).digest('hex');
const relative = file => path.relative(ROOT,file).split(path.sep).join('/');

function argumentsFrom(argv) {
 let card='halo', output=false;
 for(let i=0;i<argv.length;i++) {
  if(argv[i]==='--card') card=argv[++i];
  else if(argv[i]==='--export') output=true;
  else if(argv[i]==='--help') {console.log('node tools/render_faction_card_preview.cjs --card halo|horns|neutral [--export]');process.exit(0);}
  else throw Error(`Unknown argument: ${argv[i]}`);
 }
 if(!CARDS[card]) throw Error('Expected --card halo|horns|neutral');
 return {card,output};
}

async function alphaBounds(page, dataURL, threshold) {
 return page.evaluate(async ({dataURL,threshold}) => {
  const img=new Image();img.src=dataURL;await img.decode();
  const cv=document.createElement('canvas');cv.width=img.width;cv.height=img.height;
  const ctx=cv.getContext('2d',{willReadFrequently:true});ctx.drawImage(img,0,0);
  const rgba=ctx.getImageData(0,0,cv.width,cv.height).data;
  let left=cv.width,top=cv.height,right=0,bottom=0;
  for(let y=0;y<cv.height;y++)for(let x=0;x<cv.width;x++)if(rgba[(y*cv.width+x)*4+3]>threshold){
   left=Math.min(left,x);top=Math.min(top,y);right=Math.max(right,x+1);bottom=Math.max(bottom,y+1);
  }
  if(right<=left||bottom<=top)throw Error('Empty alpha body');
  return {width:cv.width,height:cv.height,bounds:[left,top,right,bottom]};
 },{dataURL,threshold});
}

async function labelMetrics(page) {
 return page.evaluate(() => ({
  fontLoaded:document.fonts.check('52px Jua','경험치 공격력 주머니'),
  labels:[...document.querySelectorAll('.label')].map(el=>{
   const r=el.getBoundingClientRect(), range=document.createRange();range.selectNodeContents(el);
   const ink=range.getBoundingClientRect();
   return {text:el.textContent.trim(),fontPx:parseFloat(getComputedStyle(el).fontSize),
    rect:{x:r.x,y:r.y,w:r.width,h:r.height},textRect:{x:ink.x,y:ink.y,w:ink.width,h:ink.height},
    overflow:ink.left<r.left-.5||ink.right>r.right+.5||ink.top<r.top-.5||ink.bottom>r.bottom+.5};
  })
 }));
}

(async()=>{
 const {card,output}=argumentsFrom(process.argv.slice(2));
 const title=CARDS[card];
 const html=path.join(DIR,`fresh_${card}_preview.html`);
 const source=path.join(ROOT,'art/out',`UI_FactionCard${title}_Fresh.png`);
 if(!fs.existsSync(html)||!fs.existsSync(source))throw Error(`Missing ${relative(html)} or ${relative(source)}`);
 const original=fs.readFileSync(source), dataURL='data:image/png;base64,'+original.toString('base64');
 const browser=await chromium.launch({headless:true,channel:'msedge'});
 try {
  const page=await browser.newPage({viewport:{width:1100,height:1800},deviceScaleFactor:1});
  await page.goto(pathToFileURL(html).href);
  await page.locator('.card img').evaluate((img,src)=>{img.src=src},dataURL);
  await page.evaluate(async()=>{await document.fonts.ready;await Promise.all([...document.images].map(i=>i.decode()))});
  const sourceInfo=await alphaBounds(page,dataURL,EXPORT.alphaThreshold);
  const chosenPerkFont=await page.evaluate(()=>{
   const labels=[...document.querySelectorAll('.perk')];
   for(let size=52;size>=39;size--){
    for(const label of labels)label.style.fontSize=size+'px';
    const fits=labels.every(label=>{
     const range=document.createRange();range.selectNodeContents(label);
     const r=range.getBoundingClientRect();return r.width<=label.clientWidth-4&&r.height<=label.clientHeight;
    });
    if(fits)return size;
   }
   throw Error('No common 39–52px perk font fits');
  });
  const nativeSize=await page.locator('.page').evaluate(el=>({width:Math.ceil(el.clientWidth),height:Math.ceil(el.clientHeight)}));
  await page.setViewportSize(nativeSize);
  const metrics=await labelMetrics(page);
  if(!metrics.fontLoaded||metrics.labels.some(x=>x.overflow))throw Error('Jua font or actual text Range fit failed');
  metrics.card=card;metrics.source=relative(source);metrics.sourceSha256=sha(original);
  metrics.html=relative(html);metrics.htmlSha256=sha(fs.readFileSync(html));
  metrics.font=relative(path.join(ROOT,'art/fonts/jua/Jua-Regular.ttf'));
  metrics.fontSha256=sha(fs.readFileSync(path.join(ROOT,metrics.font)));
  metrics.native=sourceInfo;metrics.perkFontPx=chosenPerkFont;metrics.uploaded=false;
  metrics.authorization=card==='halo'?'Halo typed preview approved; larger fitted text requested':'User authorized completing Horns and Neutral without intermediate approval';
  await page.screenshot({path:path.join(DIR,`fresh_${card}_typed.png`),omitBackground:true});
  for(const [name,color] of [['light','white'],['dark','#20242c']]){
   await page.evaluate(c=>document.body.style.background=c,color);
   await page.screenshot({path:path.join(DIR,`fresh_${card}_${name}.png`)});
  }
  if(output){
   const [left,top,right,bottom]=sourceInfo.bounds;
   const scale=EXPORT.bodyHeight/(bottom-top);
   const x=(EXPORT.width-(right-left)*scale)/2-left*scale;
   const y=EXPORT.padding-top*scale;
   if((right-left)*scale>EXPORT.width-2)throw Error('Source aspect is too wide for common card canvas');
   await page.evaluate(({canvas,scale,x,y,bounds,native})=>{
    document.body.style.background='transparent';
    const page=document.querySelector('.page'),card=document.querySelector('.card');
    page.style.width=canvas.width+'px';page.style.height=canvas.height+'px';page.style.overflow='hidden';
    card.style.left=x+'px';card.style.top=y+'px';card.style.transformOrigin='0 0';card.style.transform=`scale(${scale})`;
    // This clips only negligible outer alpha outside the measured original body; source pixels stay untouched.
    card.style.clipPath=`inset(${bounds[1]}px ${native.width-bounds[2]}px ${native.height-bounds[3]}px ${bounds[0]}px)`;
   },{canvas:EXPORT,scale,x,y,bounds:sourceInfo.bounds,native:sourceInfo});
   await page.setViewportSize({width:EXPORT.width,height:EXPORT.height});
   const out=path.join(ROOT,'art/ui',`UIP_FactionCard${title}_FreshTyped.png`);
   const png=await page.screenshot({path:out,omitBackground:true});
   const exportMetrics=await labelMetrics(page);
   const button=await page.locator('.button').evaluate(el=>{
    const r=el.getBoundingClientRect();return {x:r.x,y:r.y,w:r.width,h:r.height};
   });
   const alpha=await alphaBounds(page,'data:image/png;base64,'+png.toString('base64'),EXPORT.alphaThreshold);
   if(exportMetrics.labels.some(x=>x.overflow))throw Error('Exported text exceeds its label');
   const buttonRect=[button.x/EXPORT.width,button.y/EXPORT.height,button.w/EXPORT.width,button.h/EXPORT.height];
   metrics.export={file:relative(out),sha256:sha(png),canvas:[EXPORT.width,EXPORT.height],
    alphaBounds:alpha.bounds,visibleHeight:alpha.bounds[3]-alpha.bounds[1],uniformScale:scale,translation:[x,y],
    sourceClipBounds:sourceInfo.bounds,buttonRect,buttonCenter:[button.x+button.w/2,button.y+button.h/2],
    labels:exportMetrics.labels,perkPixelsAt243:chosenPerkFont*scale*243/EXPORT.height,
    sourceImageModified:false,normalization:'CSS uniform scale of original image plus separate Jua text; measured alpha clip; 12px top/bottom padding'};
   for(const [name,color] of [['light','white'],['dark','#20242c']]){
    await page.evaluate(c=>document.body.style.background=c,color);
    await page.screenshot({path:path.join(DIR,`fresh_${card}_export_${name}.png`)});
   }
  }
  if(sha(fs.readFileSync(source))!==metrics.sourceSha256)throw Error('Source PNG changed during render');
  fs.writeFileSync(path.join(DIR,`fresh_${card}_type_metrics.json`),JSON.stringify(metrics,null,2)+'\n');
  console.log(JSON.stringify({card,perkFontPx:chosenPerkFont,fontLoaded:metrics.fontLoaded,
   preview:relative(path.join(DIR,`fresh_${card}_typed.png`)),export:metrics.export},null,2));
 } finally {await browser.close();}
})().catch(e=>{console.error(e.message);process.exit(1)});
