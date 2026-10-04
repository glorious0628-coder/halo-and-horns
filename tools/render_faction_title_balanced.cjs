// Headless file render: new GPT title art + actual Jua text. No source-image edits.
// node tools/render_faction_title_balanced.cjs [--export]
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
const HTML=path.join(DIR,'fresh_title_balanced_preview.html');
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
 const previousFile=path.join(ROOT,'art/ui/UIP_FactionTitle_FreshTyped.png'),previous=fs.readFileSync(previousFile),previousSha=sha(previous);
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
  // Reset baseline explicitly so re-running remains deterministic even after the standalone HTML is updated.
  await page.locator('.title').evaluate(el=>{el.style.left='458px';el.style.top='231px';el.style.fontSize='180px';});
  async function actualInk(){
   await page.locator('.banner img').evaluate(el=>el.style.visibility='hidden');
   const png=await page.screenshot({omitBackground:true});
   await page.locator('.banner img').evaluate(el=>el.style.visibility='visible');
   const report=await alphaReport(page,'data:image/png;base64,'+png.toString('base64'));
   const bounds=report.alphaNonzeroBounds;
   return {bounds,center:[(bounds[0]+bounds[2])/2,(bounds[1]+bounds[3])/2],report,png};
  }
  const beforeInk=await actualInk();
  const blank=await page.evaluate(async dataURL=>{
   const im=new Image();im.src=dataURL;await im.decode();const cv=document.createElement('canvas');cv.width=im.width;cv.height=im.height;
   const ctx=cv.getContext('2d');ctx.drawImage(im,0,0);const a=ctx.getImageData(0,0,cv.width,cv.height).data,columns=[];
   for(let x=500;x<=1650;x+=25){let spans=[],start=null;
    for(let y=175;y<=485;y++){const i=(y*cv.width+x)*4,[r,g,b,alpha]=a.slice(i,i+4),hi=Math.max(r,g,b),lo=Math.min(r,g,b);
     const ivory=y<485&&alpha>240&&r>200&&g>185&&b>160&&(hi-lo)/Math.max(hi,1)<.28;
     if(ivory&&start===null)start=y;if(!ivory&&start!==null){spans.push([start,y]);start=null;}
    }
    spans.sort((a,b)=>(b[1]-b[0])-(a[1]-a[0]));if(spans.length)columns.push({x,top:spans[0][0],bottom:spans[0][1],center:(spans[0][0]+spans[0][1])/2});
   }
   const values=columns.map(c=>c.center).sort((a,b)=>a-b),median=values[Math.floor(values.length/2)];
   return {method:'Longest contiguous opaque ivory run at x500..1650 step25, y175..485: R>200 G>185 B>160 saturation<0.28 alpha>240. Median column center, blank panel symmetry x1086.',columns,center:[1086,median]};
  },dataURL);
  const delta=[blank.center[0]-beforeInk.center[0],blank.center[1]-beforeInk.center[1]];
  const balancedPosition=[458+delta[0],231+delta[1]];
  await page.locator('.title').evaluate((el,pos)=>{el.style.left=pos[0]+'px';el.style.top=pos[1]+'px';},balancedPosition);
  const afterInk=await actualInk();
  fs.writeFileSync(path.join(DIR,'fresh_title_balanced_ink_before.png'),beforeInk.png);
  fs.writeFileSync(path.join(DIR,'fresh_title_balanced_ink_after.png'),afterInk.png);
  const optical={method:'Actual isolated glyph alpha pixel bounding box; DOM Range is not used as ink.',blank,before:{bounds:beforeInk.bounds,center:beforeInk.center},after:{bounds:afterInk.bounds,center:afterInk.center},deltaNative:delta,balancedPosition,fontSizeUnchanged:180,
   beforeCenterError:beforeInk.center.map((v,i)=>v-blank.center[i]),afterCenterError:afterInk.center.map((v,i)=>v-blank.center[i])};
  if(Math.max(...optical.afterCenterError.map(Math.abs))>.6)throw Error('Ink center alignment failed');
  // Keep the new standalone preview correct when opened without this script.
  const htmlText=fs.readFileSync(HTML,'utf8').replace(/left:[\d.]+px;top:[\d.]+px;width:1256px/,`left:${balancedPosition[0]}px;top:${balancedPosition[1]}px;width:1256px`);
  fs.writeFileSync(HTML,htmlText);
  const initial=await alphaReport(page,dataURL),main=initial.components[0].largest;
  if(!main||initial.components[16].count!==1)throw Error('Source has no single visible banner body');
  const [w,h]=initial.size,[l,t,r,b]=main.bounds;
  const crop=[Math.max(0,l-2),Math.max(0,t-2),Math.min(w,r+2),Math.min(h,b+2)];
  const source=await alphaReport(page,dataURL,crop);
  if(source.cropOutsideAlphaMax>1)throw Error('Proposed crop would remove visible source content');
  const native=await textMetrics(page);if(!native.fontLoaded||native.overflow)throw Error('Font or native Range fit failed');
  const preview=path.join(DIR,'fresh_title_balanced_typed.png');await page.screenshot({path:preview,omitBackground:true});
  const metrics={dateKst:'2026-10-04',source:rel(SOURCE),sourceSha256:sourceSha,html:rel(HTML),htmlSha256:sha(fs.readFileSync(HTML)),
   font:rel(FONT),fontSha256:fontSha,configTitle:semantic[1],pickerTitle:uiText[1],semanticMatchesConfig:true,
   configSha256:sha(Buffer.from(config)),pickerSha256:sha(Buffer.from(picker)),source,native,
   originalModified:false,retouch:false,alphaMaskEdited:false,upload:false,studioValidation:false,optical,previousProduction:{file:rel(previousFile),sha256:previousSha},
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
   const out=path.join(ROOT,'art/ui/UIP_FactionTitle_FreshTyped_Balanced.png');
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
     const file=path.join(DIR,`fresh_title_balanced_${label}_${name}.png`),buf=Buffer.from(await inspectPng(page,png,rect,zoom,color),'base64');
     fs.writeFileSync(file,buf);evidence.push({file:rel(file),sha256:sha(buf),nearestNeighborZoom:zoom,background:color,crop:rect});
    }
   }
   const balancedOutputInk=await actualInk();
   await page.locator('.title').evaluate(el=>{el.style.left='458px';el.style.top='231px';});
   const beforeOutputInk=await actualInk();
   await page.locator('.title').evaluate((el,pos)=>{el.style.left=pos[0]+'px';el.style.top=pos[1]+'px';},balancedPosition);
   const blankOutputCenter=[blank.center[0]*scale+tx,blank.center[1]*scale+ty];
   for(const [name,ink] of [['before',beforeOutputInk],['after',balancedOutputInk]])
    fs.writeFileSync(path.join(DIR,`fresh_title_balanced_output_ink_${name}.png`),ink.png);
   metrics.outputInk={blankCenter:blankOutputCenter,
    before:{bounds:beforeOutputInk.bounds,center:beforeOutputInk.center,error:beforeOutputInk.center.map((v,i)=>v-blankOutputCenter[i])},
    after:{bounds:balancedOutputInk.bounds,center:balancedOutputInk.center,error:balancedOutputInk.center.map((v,i)=>v-blankOutputCenter[i])}};
   for(const [name,bg] of [['light','#ffffff'],['dark','#20242c']]){
    for(const [kind,renderWidth] of [['before_after',1024],['runtime_238_8',238.8]]){
     const file=path.join(DIR,`fresh_title_balanced_${kind}_${name}.png`);
     const buf=await page.evaluate(async({before,after,bg,renderWidth})=>{
      const images=await Promise.all([before,after].map(async src=>{const im=new Image();im.src=src;await im.decode();return im;}));
      const rh=images[0].height*renderWidth/images[0].width,pad=12,labelH=26,rowH=Math.ceil(rh)+labelH+pad;
      const cv=document.createElement('canvas');cv.width=Math.ceil(renderWidth)+pad*2;cv.height=rowH*2+pad;
      const ctx=cv.getContext('2d');ctx.fillStyle=bg;ctx.fillRect(0,0,cv.width,cv.height);ctx.font='18px Jua';ctx.fillStyle=bg==='#ffffff'?'#472008':'#ffffff';
      for(let i=0;i<2;i++){const y=pad+i*rowH;ctx.fillText(i===0?'이전':'균형 조정',pad,y+17);ctx.drawImage(images[i],pad,y+labelH,renderWidth,rh);}
      return cv.toDataURL('image/png').split(',')[1];
     },{before:'data:image/png;base64,'+previous.toString('base64'),after:'data:image/png;base64,'+png.toString('base64'),bg,renderWidth});
     const bytes=Buffer.from(buf,'base64');fs.writeFileSync(file,bytes);evidence.push({file:rel(file),sha256:sha(bytes),background:bg,renderWidth,localGameScaleSample:kind==='runtime_238_8',actualStudioCapture:false});
    }
   }
   metrics.evidence=evidence;
  }
  if(sha(fs.readFileSync(SOURCE))!==sourceSha)throw Error('Generated source bytes changed');
  if(sha(fs.readFileSync(previousFile))!==previousSha)throw Error('Previous production output changed');
  fs.writeFileSync(path.join(DIR,'fresh_title_balanced_metrics.json'),JSON.stringify(metrics,null,2)+'\n');
  console.log(JSON.stringify({sourceSha,sourceCrop:crop,sourceRemoved:source.cropOutsideNonzeroPixels,sourceRemovedMaxAlpha:source.cropOutsideAlphaMax,
   nativeFont:native.fontSizeNative,optical,output:metrics.export,sourceImageUnchanged:true,previousProductionUnchanged:true},null,2));
 }finally{await browser.close();}
})().catch(e=>{console.error(e.message);process.exit(1);});
