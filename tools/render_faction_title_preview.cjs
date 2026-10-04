// Headless file render: new GPT title art + actual Jua text. No source-image edits.
// node tools/render_faction_title_preview.cjs [--export]
// Only crop the largest alpha>0 connected body's rectangular bounds + 2 native pixels.
// The source alpha/RGB remain unchanged; detached alpha=1 specks outside that rectangle are omitted by crop.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {pathToFileURL} = require('node:url');
let chromium;
try {({chromium}=require('playwright'));}
catch {({chromium}=require(path.resolve(path.dirname(process.execPath),'../node_modules/playwright')));}
const ROOT=path.resolve(__dirname,'..');
const DIR=path.join(ROOT,'docs/art/verification_2026-10-04/faction_e');
const SOURCE=path.join(ROOT,'art/out/UI_FactionTitle_Fresh.png');
const HTML=path.join(DIR,'fresh_title_preview.html');
const FONT=path.join(ROOT,'art/fonts/jua/Jua-Regular.ttf');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const rel=p=>path.relative(ROOT,p).split(path.sep).join('/');
const EXPORT=process.argv.includes('--export');
if(process.argv.slice(2).some(x=>x!=='--export'))throw Error('Expected only --export');

async function alphaReport(page,dataURL,crop=null){
 return page.evaluate(async({dataURL,crop})=>{
  const img=new Image();img.src=dataURL;await img.decode();
  const w=img.width,h=img.height,n=w*h,cv=document.createElement('canvas');cv.width=w;cv.height=h;
  const ctx=cv.getContext('2d',{willReadFrequently:true});ctx.drawImage(img,0,0);
  const data=ctx.getImageData(0,0,w,h).data;
  function components(threshold){
   const seen=new Uint8Array(n),queue=new Int32Array(n);let all=[];
   for(let i=0;i<n;i++)if(!seen[i]&&data[4*i+3]>threshold){
    let head=0,tail=1,l=w,t=h,r=0,b=0,maxAlpha=0;queue[0]=i;seen[i]=1;
    while(head<tail){
     const p=queue[head++],x=p%w,y=Math.floor(p/w);
     l=Math.min(l,x);r=Math.max(r,x+1);t=Math.min(t,y);b=Math.max(b,y+1);maxAlpha=Math.max(maxAlpha,data[4*p+3]);
     for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){
      if(!dx&&!dy)continue;const xx=x+dx,yy=y+dy;if(xx<0||xx>=w||yy<0||yy>=h)continue;
      const q=yy*w+xx;if(!seen[q]&&data[4*q+3]>threshold){seen[q]=1;queue[tail++]=q;}
     }
    }
    all.push({pixels:tail,bounds:[l,t,r,b],maxAlpha});
   }
   all.sort((a,b)=>b.pixels-a.pixels);
   return {count:all.length,largest:all[0]||null,detachedPixels:all.slice(1).reduce((s,c)=>s+c.pixels,0),
    detachedMaxAlpha:Math.max(0,...all.slice(1).map(c=>c.maxAlpha)),largestDetached:all.slice(1,11)};
  }
  const reports={};for(const t of [0,16,128])reports[t]=components(t);
  let bounds=[w,h,0,0],removedPixels=0,removedAlphaMax=0;
  for(let i=0;i<n;i++){const a=data[4*i+3];if(!a)continue;const x=i%w,y=Math.floor(i/w);
   bounds=[Math.min(bounds[0],x),Math.min(bounds[1],y),Math.max(bounds[2],x+1),Math.max(bounds[3],y+1)];
   if(crop&&(x<crop[0]||y<crop[1]||x>=crop[2]||y>=crop[3])){removedPixels++;removedAlphaMax=Math.max(removedAlphaMax,a);}
  }
  return {size:[w,h],alphaNonzeroBounds:bounds,components:reports,
   cropOutsideNonzeroPixels:crop?removedPixels:null,cropOutsideAlphaMax:crop?removedAlphaMax:null};
 },{dataURL,crop});
}

async function textMetrics(page){
 return page.evaluate(()=>{
  const el=document.querySelector('.title'),r=el.getBoundingClientRect(),range=document.createRange();range.selectNodeContents(el);
  const ink=range.getBoundingClientRect(),s=getComputedStyle(el);
  return {text:el.textContent,fontLoaded:document.fonts.check('180px Jua',el.textContent),fontFamily:s.fontFamily,
   fontSizeNative:parseFloat(s.fontSize),glyphColor:s.color,textShadow:s.textShadow,textStroke:s.webkitTextStrokeWidth,
   box:[r.x,r.y,r.width,r.height],range:[ink.x,ink.y,ink.width,ink.height],
   overflow:ink.left<r.left-.5||ink.right>r.right+.5||ink.top<r.top-.5||ink.bottom>r.bottom+.5};
 });
}

async function inspectPng(page,png,crop,zoom,bg){
 return page.evaluate(async({dataURL,crop,zoom,bg})=>{
  const img=new Image();img.src=dataURL;await img.decode();const rect=crop||[0,0,img.width,img.height];
  const cv=document.createElement('canvas');cv.width=(rect[2]-rect[0])*zoom;cv.height=(rect[3]-rect[1])*zoom;
  const ctx=cv.getContext('2d');ctx.fillStyle=bg;ctx.fillRect(0,0,cv.width,cv.height);ctx.imageSmoothingEnabled=false;
  ctx.drawImage(img,rect[0],rect[1],rect[2]-rect[0],rect[3]-rect[1],0,0,cv.width,cv.height);
  return cv.toDataURL('image/png').split(',')[1];
 },{dataURL:'data:image/png;base64,'+png.toString('base64'),crop,zoom,bg});
}

(async()=>{
 const original=fs.readFileSync(SOURCE),sourceSha=sha(original),fontSha=sha(fs.readFileSync(FONT));
 const configFile=path.join(ROOT,'src/ReplicatedStorage/Shared/Config.luau');
 const pickerFile=path.join(ROOT,'src/StarterPlayer/StarterPlayerScripts/FactionPicker.luau');
 const config=fs.readFileSync(configFile,'utf8'),picker=fs.readFileSync(pickerFile,'utf8');
 const semantic=config.match(/SemanticText\s*=\s*\{\s*Title\s*=\s*"([^"]+)"/);
 const uiText=picker.match(/local T\s*=\s*\{\s*Title\s*=\s*"([^"]+)"/);
 if(!semantic||!uiText||semantic[1]!==uiText[1])throw Error('Config/FactionPicker title text mismatch');
 const dataURL='data:image/png;base64,'+original.toString('base64');
 const browser=await chromium.launch({headless:true,channel:'msedge'});
 try{
  const page=await browser.newPage({viewport:{width:2172,height:724},deviceScaleFactor:1});
  await page.goto(pathToFileURL(HTML).href);
  await page.locator('.banner img').evaluate((el,src)=>{el.src=src;},dataURL);
  if(await page.locator('.title').textContent()!==semantic[1])throw Error('HTML differs from exact Config title');
  await page.evaluate(async()=>{await document.fonts.ready;await Promise.all([...document.images].map(x=>x.decode()));});
  await page.evaluate(()=>{
   const el=document.querySelector('.title');
   for(let size=180;size>=120;size--){el.style.fontSize=size+'px';const rr=document.createRange();rr.selectNodeContents(el);
    const b=rr.getBoundingClientRect();if(b.width<=el.clientWidth-20&&b.height<=el.clientHeight-12)return;}
   throw Error('Large title could not fit');
  });
  const initial=await alphaReport(page,dataURL),main=initial.components[0].largest;
  if(!main||initial.components[16].count!==1)throw Error('Source has no single visible banner body');
  const [w,h]=initial.size,[l,t,r,b]=main.bounds;
  const crop=[Math.max(0,l-2),Math.max(0,t-2),Math.min(w,r+2),Math.min(h,b+2)];
  const source=await alphaReport(page,dataURL,crop);
  if(source.cropOutsideAlphaMax>1)throw Error('Proposed crop would remove visible source content');
  const native=await textMetrics(page);if(!native.fontLoaded||native.overflow)throw Error('Font or native Range fit failed');
  const preview=path.join(DIR,'fresh_title_typed.png');await page.screenshot({path:preview,omitBackground:true});
  const metrics={dateKst:'2026-10-04',source:rel(SOURCE),sourceSha256:sourceSha,html:rel(HTML),htmlSha256:sha(fs.readFileSync(HTML)),
   font:rel(FONT),fontSha256:fontSha,configTitle:semantic[1],pickerTitle:uiText[1],semanticMatchesConfig:true,
   configSha256:sha(Buffer.from(config)),pickerSha256:sha(Buffer.from(picker)),source,native,
   originalModified:false,retouch:false,alphaMaskEdited:false,upload:false,studioValidation:false,
   approval:'User requested new title; generated/type candidate not yet a runtime completion',
   cropAuthorization:'Largest alpha>0 connected body +2 native pixels rectangle; no threshold or mask edit. Detached alpha=1 pixels outside are transparent-margin crop only.'};
  if(EXPORT){
   const outputWidth=1024,padding=2,scale=(outputWidth-padding*2)/(crop[2]-crop[0]);
   const outputHeight=Math.ceil((crop[3]-crop[1])*scale)+padding*2;
   const tx=padding-crop[0]*scale,ty=padding-crop[1]*scale;
   await page.evaluate(({width,height,scale,tx,ty})=>{
    const p=document.querySelector('.page'),banner=document.querySelector('.banner');
    p.style.width=width+'px';p.style.height=height+'px';
    banner.style.transform=`translate(${tx}px,${ty}px) scale(${scale})`;
   },{width:outputWidth,height:outputHeight,scale,tx,ty});
   await page.setViewportSize({width:outputWidth,height:outputHeight});
   const out=path.join(ROOT,'art/ui/UIP_FactionTitle_FreshTyped.png');
   const png=await page.screenshot({path:out,omitBackground:true}),text=await textMetrics(page);
   const alpha=await alphaReport(page,'data:image/png;base64,'+png.toString('base64'));
   const bounds=alpha.alphaNonzeroBounds,margins=[bounds[0],bounds[1],outputWidth-bounds[2],outputHeight-bounds[3]];
   if(text.overflow||margins[0]<2||margins[2]<2)throw Error('Export title fit or two-pixel side margin failed');
   metrics.export={file:rel(out),sha256:sha(png),size:[outputWidth,outputHeight],uniformScale:scale,translation:[tx,ty],
    sourceCropBounds:crop,paddingPixels:padding,nonzeroAlphaMargins:margins,alpha,text,
    fontPixelsAtOutput:native.fontSizeNative*scale,fontPixelsAtRuntimeWidth238_8:native.fontSizeNative*scale*238.8/outputWidth,
    nativeFontFaceInRoblox:false,fontRasterizedAtOutputResolution:true};
   const box=text.box.map((x,i)=>i<2?Math.floor(x):Math.ceil(x));
   const textCrop=[Math.max(0,box[0]-4),Math.max(0,box[1]-4),Math.min(outputWidth,box[0]+box[2]+4),Math.min(outputHeight,box[1]+box[3]+4)];
   const evidence=[];
   for(const [name,color] of [['light','#ffffff'],['dark','#20242c']]){
    for(const [label,rect,zoom] of [['export',null,1],['export_4x',null,4],['text_4x',textCrop,4]]){
     const file=path.join(DIR,`fresh_title_${label}_${name}.png`),buf=Buffer.from(await inspectPng(page,png,rect,zoom,color),'base64');
     fs.writeFileSync(file,buf);evidence.push({file:rel(file),sha256:sha(buf),nearestNeighborZoom:zoom,background:color,crop:rect});
    }
   }
   metrics.evidence=evidence;
  }
  if(sha(fs.readFileSync(SOURCE))!==sourceSha)throw Error('Generated source bytes changed');
  fs.writeFileSync(path.join(DIR,'fresh_title_type_metrics.json'),JSON.stringify(metrics,null,2)+'\n');
  console.log(JSON.stringify({sourceSha,sourceCrop:crop,sourceRemoved:source.cropOutsideNonzeroPixels,sourceRemovedMaxAlpha:source.cropOutsideAlphaMax,
   nativeFont:native.fontSizeNative,output:metrics.export,sourceImageUnchanged:true},null,2));
 }finally{await browser.close();}
})().catch(e=>{console.error(e.message);process.exit(1);});
