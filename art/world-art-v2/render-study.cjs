#!/usr/bin/env node
'use strict';
// Execute the same browser scene in Canvas/Skia. Outputs are not Godot captures.
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert'),crypto=require('crypto');
const {spawn}=require('child_process'),{once}=require('events'),dir=__dirname;
const {withTerrain47}=require('./web/asset-manifest.cjs');
const pkg = require('@napi-rs/canvas');
const {createCanvas,Image:NativeImage,GlobalFonts,loadImage}=pkg;
const font='/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc';if(fs.existsSync(font))GlobalFonts.registerFromPath(font,'Noto Sans CJK SC');
function element(){const listeners={};return {dataset:{},value:'',textContent:'',hidden:false,addEventListener(type,fn){(listeners[type]||(listeners[type]=[])).push(fn);},dispatch(type,event={}){for(const fn of listeners[type]||[])fn(Object.assign({target:this},event));},click(){this.dispatch('click');},setAttribute(key,value){this[key]=value;},getAttribute(key){return this[key];}};}
async function createStudy(options={}){
  const data=options.data||JSON.parse(fs.readFileSync(path.join(dir,'study.json'),'utf8')),manifest=withTerrain47(options.manifest||JSON.parse(fs.readFileSync(path.join(dir,'assets/pixel/manifest.json'),'utf8')),data,dir);
  const template=options.template||fs.readFileSync(path.join(dir,'web/template.html'),'utf8'),elements={};for(const m of template.matchAll(/\bid="([^"]+)"/g))elements[m[1]]=element();
  const screen=createCanvas(data.viewport.width,data.viewport.height);Object.assign(screen,element());elements['region-scene']=screen;
  const lightingButtons=[...template.matchAll(/data-lighting="([^"]+)"/g)].map(m=>Object.assign(element(),{dataset:{lighting:m[1]}}));
  if(!elements['region-lighting-study'])throw new Error('Template root missing.');elements['region-lighting-study'].querySelectorAll=selector=>selector==='[data-lighting]'?lightingButtons:[];
  const document={getElementById:id=>elements[id]||null,createElement:tag=>tag==='canvas'?createCanvas(1,1):element()};
  class LocalImage extends NativeImage{set src(value){super.src=value.startsWith('data:')?value:path.resolve(dir,value);}get src(){return super.src;}}
  const window={STUDY_DATA:data,STUDY_MANIFEST:manifest,matchMedia(){return {matches:false};}};if(options.assets)window.STUDY_ASSETS=options.assets;
  vm.runInNewContext(options.scene||fs.readFileSync(path.join(dir,'web/study.js'),'utf8'),{window,document,Image:LocalImage,performance:{now:()=>0},requestAnimationFrame:()=>0,cancelAnimationFrame(){},Promise,console},{filename:'web/study.js'});
  const demo=window.StudyDemo;if(!demo)throw new Error('Scene failed to initialize.');await demo.ready;demo.pauseLoop();
  const canvases=Object.fromEntries(Object.entries(demo.views).map(([k,v])=>[k,v.canvas]));return {demo,screen,canvases,data,manifest,elements,lightingButtons};
}
function savePNG(canvas,file){const out=path.resolve(dir,file);fs.mkdirSync(path.dirname(out),{recursive:true});fs.writeFileSync(out,canvas.toBuffer('image/png'));return out;}
function composite(study,options={}){
  const regions=options.regionIDs?study.data.regions.filter(r=>options.regionIDs.includes(r.id)):study.data.regions;
  const scale=options.scale||1,w=Math.round(study.data.viewport.width*scale),h=Math.round(study.data.viewport.height*scale),header=options.header===false?0:(options.headerHeight||34),gap=options.gap===undefined?12:options.gap,columns=options.columns||1,rows=Math.ceil(regions.length/columns);
  const result=createCanvas(w*columns,(h+header)*rows+gap*(rows-1)),g=result.getContext('2d');g.imageSmoothingEnabled=false;g.fillStyle='#15232e';g.fillRect(0,0,result.width,result.height);g.fillStyle='#e3e0cd';g.font='500 16px "Noto Sans CJK SC", sans-serif';
  regions.forEach((r,i)=>{const x=(i%columns)*w,y=Math.floor(i/columns)*(h+header+gap);if(header)g.fillText(r.name,x+14,y+23);g.drawImage(study.canvases[r.id],x,y+header,w,h);});return result;
}
function comparison(study,id){
  const w=study.data.viewport.width,h=study.data.viewport.height,result=createCanvas(w*2,h+34),g=result.getContext('2d');g.imageSmoothingEnabled=false;g.fillStyle='#15232e';g.fillRect(0,0,result.width,result.height);g.fillStyle='#e3e0cd';g.font='500 16px "Noto Sans CJK SC", sans-serif';
  study.demo.setRegion(id);study.demo.setLighting(false);g.drawImage(study.canvases[id],0,34);g.fillText('素材原色',14,23);study.demo.setLighting(true);g.drawImage(study.canvases[id],w,34);g.fillText('场景光照',w+14,23);return result;
}
function renderAll(study){
  const outputs=[];study.demo.setPaused(true);study.demo.setCameraOffset(null);study.demo.seek(1200);
  for(const lighting of [false,true]){study.demo.setLighting(lighting);study.demo.renderAll();for(const r of study.data.regions)outputs.push(savePNG(study.canvases[r.id],`previews/${r.id}-${lighting?'lit':'unlit'}.png`));if(lighting)outputs.push(savePNG(composite(study,{columns:Math.min(4,study.data.regions.length),scale:.5,headerHeight:30,gap:10}),'previews/regions-overview.png'));}
  const featured=study.data.regions.find(r=>r.id==='windchime_plains')||study.data.regions[0];outputs.push(savePNG(comparison(study,featured.id),'previews/lighting-comparison.png'));
  for(const id of ['thorn_forest','gear_city','ember_depths'])if(study.data.regions.some(r=>r.id===id))outputs.push(savePNG(comparison(study,id),'previews/'+id+'-lighting-comparison.png'));
  study.demo.setRegion(featured.id);study.demo.setLighting(true);study.demo.renderAll();const snapshot=path.join(dir,'previews/scene-snapshot.json');fs.writeFileSync(snapshot,JSON.stringify(study.demo.getSnapshot(),null,2)+'\n');outputs.push(snapshot);return outputs;
}
async function renderVideo(study,options={}){
  const ids=options.regionIDs||['windchime_plains','thorn_forest'].filter(id=>study.data.regions.some(r=>r.id===id));if(!ids.length)ids.push(...study.data.regions.map(r=>r.id));
  const fps=options.fps||24,segmentSeconds=options.segmentSeconds||6,seconds=ids.length*segmentSeconds,total=Math.round(seconds*fps),out=path.resolve(dir,options.out||'previews/world-art-motion.mp4'),w=study.data.viewport.width,h=study.data.viewport.height+34;
  fs.mkdirSync(path.dirname(out),{recursive:true});study.demo.setCameraOffset(null);study.demo.setPaused(false);study.demo.seek(0);
  const frame=createCanvas(w,h),g=frame.getContext('2d');g.imageSmoothingEnabled=false;
  const proc=spawn('ffmpeg',['-hide_banner','-loglevel','error','-y','-f','rawvideo','-pixel_format','rgba','-video_size',`${w}x${h}`,'-framerate',String(fps),'-i','pipe:0','-an','-c:v','libx264','-preset','medium','-crf','16','-pix_fmt','yuv420p','-movflags','+faststart',out],{stdio:['pipe','ignore','pipe']});
  let errors='';proc.stderr.on('data',b=>{errors=(errors+b.toString()).slice(-5000);});proc.stdin.on('error',()=>{});const closed=once(proc,'close');
  for(let i=0;i<total;i++){
    const t=i/fps,id=ids[Math.min(ids.length-1,Math.floor(t/segmentSeconds))],lit=options.showUnlit===false?true:t%segmentSeconds>=1,current=study.demo.getState();
    if(current.region!==id)study.demo.setRegion(id);if(current.lighting!==lit)study.demo.setLighting(lit);study.demo.render(i*1000/fps);
    g.fillStyle='#15232e';g.fillRect(0,0,w,h);g.drawImage(study.canvases[id],0,34);g.fillStyle='#e3e0cd';g.font='500 15px "Noto Sans CJK SC", sans-serif';g.fillText(study.data.regions.find(r=>r.id===id).name,14,23);g.font='400 13px "Noto Sans CJK SC", sans-serif';g.fillText(options.label||(lit?'光照 · 景深':'素材原色'),w-110,23);
    const rgba=g.getImageData(0,0,w,h).data;if(!proc.stdin.write(Buffer.from(rgba.buffer,rgba.byteOffset,rgba.byteLength)))await once(proc.stdin,'drain');
  }
  proc.stdin.end();const [code]=await closed;if(code!==0)throw new Error('FFmpeg failed: '+errors);study.demo.setPaused(true);study.demo.seek(1200);study.demo.setLighting(true);return {file:out,width:w,height:h,fps,seconds,frames:total,bytes:fs.statSync(out).size};
}
async function renderBeforeAfter(study,options={}){
  const ids=options.regionIDs||['windchime_plains','thorn_forest'];
  const w=study.data.viewport.width,h=study.data.viewport.height,header=34;
  const canvas=createCanvas(w*2,(h+header)*ids.length),g=canvas.getContext('2d');g.imageSmoothingEnabled=false;
  g.fillStyle='#15232e';g.fillRect(0,0,canvas.width,canvas.height);g.font='500 15px "Noto Sans CJK SC", sans-serif';
  study.demo.setPaused(true);study.demo.setCameraOffset(null);study.demo.seek(1200);study.demo.setLighting(true);study.demo.renderAll();
  for(let i=0;i<ids.length;i++){
    const id=ids[i],y=i*(h+header),name=study.data.regions.find(r=>r.id===id).name;
    const before=await loadImage(path.join(dir,'previews/before/'+id+'.png'));
    g.drawImage(before,0,y+header);g.drawImage(study.canvases[id],w,y+header);g.fillStyle='#e3e0cd';g.fillText(name+' · 修改前',14,y+23);g.fillText(name+' · 更新后',w+14,y+23);
  }
  const native=savePNG(canvas,'previews/plains-forest-before-after.png');
  const scale=options.scale||2,zoom=createCanvas(canvas.width*scale,canvas.height*scale),zg=zoom.getContext('2d');zg.imageSmoothingEnabled=false;zg.drawImage(canvas,0,0,zoom.width,zoom.height);
  const image=savePNG(zoom,options.imageOut||'previews/plains-forest-before-after-native-2x.png');
  const oldVideo=path.join(dir,'previews/before/plains-forest.mp4'),newVideo=path.resolve(dir,options.newVideo||'previews/world-art-motion.mp4'),video=path.resolve(dir,options.videoOut||'previews/plains-forest-before-after.mp4');
  let videoResult=null;
  if(fs.existsSync(oldVideo)&&fs.existsSync(newVideo)){
    const proc=spawn('ffmpeg',['-hide_banner','-loglevel','error','-y','-i',oldVideo,'-i',newVideo,'-filter_complex','[0:v][1:v]hstack=inputs=2:shortest=1[v]','-map','[v]','-an','-c:v','libx264','-preset','medium','-crf','16','-pix_fmt','yuv420p','-movflags','+faststart',video],{stdio:['ignore','ignore','pipe']});
    let errors='';proc.stderr.on('data',b=>errors+=b.toString());const [code]=await once(proc,'close');if(code!==0)throw new Error('Before/after FFmpeg failed: '+errors);videoResult={file:video,bytes:fs.statSync(video).size,renderer:'Canvas/Skia, native 640px rooms side by side'};
  }
  return {image,native,video:videoResult};
}
function sha(canvas){return crypto.createHash('sha256').update(canvas.toBuffer('image/png')).digest('hex');}
function parseEmbedded(html){
  // Run the exact bootstrap/decoder used by the browser, without the scene DOM.
  const scripts=[...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)].map(m=>m[1]);
  const at=scripts.findIndex(source=>source.startsWith('window.STUDY_DATA='));if(at<0)throw new Error('Embedded data bootstrap missing.');
  const window={},context={window,Uint8Array,btoa:value=>Buffer.from(value,'binary').toString('base64')};
  vm.runInNewContext(scripts[at],context,{timeout:5000});
  if(window.STUDY_ASSETS_B85)vm.runInNewContext(scripts[at+1],context,{timeout:5000});
  if(!window.STUDY_ASSETS)throw new Error('Embedded assets did not decode.');
  return {data:window.STUDY_DATA,manifest:window.STUDY_MANIFEST,assets:window.STUDY_ASSETS,template:html,scene:scripts[scripts.length-1]};
}
async function verify(study,options={}){
  const checks=[];const check=(name,fn)=>{fn();checks.push(name);};study.demo.setPaused(true);study.demo.seek(1200);
  check('All required native assets loaded',()=>{const used=study.demo.usedAssets();assert.equal(study.demo.getState().loaded,used.sprites.length+used.backgrounds.length);});
  check('Region selector changes the rendered room',()=>{const e=study.elements['region-select'];for(const r of study.data.regions){e.value=r.id;e.dispatch('change');assert.equal(study.demo.getState().region,r.id);assert.equal(sha(study.screen),sha(study.canvases[r.id]));}});
  check('Lighting controls visibly change the same frame',()=>{for(const r of study.data.regions){study.demo.setRegion(r.id);study.lightingButtons.find(b=>b.dataset.lighting==='off').click();const raw=sha(study.screen);study.lightingButtons.find(b=>b.dataset.lighting==='on').click();assert.notEqual(raw,sha(study.screen),r.id+' lighting is unchanged');}});
  check('Depth control shows independent regional sprites',()=>{const regions=study.data.regions.filter(r=>(r.layers||[]).length);for(const r of regions){study.demo.setRegion(r.id);study.demo.setDepth(true);const layered=sha(study.screen);study.elements['region-depth'].click();assert.equal(study.demo.getState().depth,false);assert.notEqual(layered,sha(study.screen),r.id+' depth layers are invisible');study.demo.setDepth(true);}});
  check('Camera and parallax offsets stay on the pixel grid through both ±32 views',()=>{for(const offset of [-32,0,32]){study.demo.setCameraOffset(offset);const snapshot=study.demo.getSnapshot();assert.equal(snapshot.state.cameraOffset,offset);for(const r of snapshot.regions)for(const l of r.layers||[]){assert(Number.isInteger(l.screenOffset));assert(Number.isInteger(l.drawBounds.x)&&Number.isInteger(l.drawBounds.y));}}study.demo.setCameraOffset(null);study.demo.seek(1200);assert.equal(study.demo.getState().cameraOffset,0);});
  check('47-neighbour records use normalized masks with 32px cells',()=>{for(const r of study.demo.getSnapshot().regions)for(const p of r.terrainDraws.filter(p=>p.pass==='terrain47')){assert.equal(study.demo.normalizedMask(p.mask),p.mask);assert(r.terrainSpec.maskToAtlas[String(p.mask)]);assert.deepEqual(p.source.slice(2),[32,32]);}});
  check('Grid collision rectangles preserve occupied cells and empty openings',()=>{for(const r of study.demo.getSnapshot().regions){const source=study.data.regions.find(s=>s.id===r.id),grid=source.terrainGrid||study.data.terrainGrid;if(!grid)continue;const occupied=new Set(grid.cells.map(c=>c.join(','))),tile=grid.tile||32,origin=grid.origin||[0,0],xs=grid.cells.map(c=>c[0]),ys=grid.cells.map(c=>c[1]);for(let cy=Math.min(...ys)-1;cy<=Math.max(...ys)+1;cy++)for(let cx=Math.min(...xs)-1;cx<=Math.max(...xs)+1;cx++){const x=origin[0]+(cx+.5)*tile,y=origin[1]+(cy+.5)*tile,covered=r.bodies.some(b=>x>=b.points[0][0]&&x<b.points[1][0]&&y>=b.points[0][1]&&y<b.points[2][1]);assert.equal(covered,occupied.has(cx+','+cy),r.id+' collision mismatch at '+cx+','+cy);}}});
  check('Foreground mask retains upper silhouettes and protects the hero locally',()=>{for(const r of study.data.regions)for(const layer of r.layers||[]){if(!layer.mask||!layer.mask.heroReveal)continue;study.demo.setProtection(true);const protectedAlpha=study.demo.depthMaskAlpha(r,layer,study.data.hero.x-8,study.data.hero.y-22);study.demo.setProtection(false);const rawAlpha=study.demo.depthMaskAlpha(r,layer,study.data.hero.x-8,study.data.hero.y-22);assert(protectedAlpha<=rawAlpha);assert(protectedAlpha>=0);assert(protectedAlpha>0||rawAlpha===0);study.demo.setProtection(true);}});
  check('Foreground bases leave internal holes and platform gaps empty',()=>{for(const r of study.data.regions){const grid=r.terrainGrid||study.data.terrainGrid;if(!grid)continue;const occupied=new Set(grid.cells.map(c=>c.join(','))),tile=grid.tile||32,origin=grid.origin||[0,0];for(const layer of r.layers||[]){const mask=layer.mask;if(!mask||mask.type!=='platform_band'||mask.surfaceY===undefined)continue;for(let y=mask.surfaceY+16;y<Math.min(study.data.viewport.height,mask.surfaceY+(mask.below||72)-8);y+=16)for(let x=16;x<study.data.viewport.width;x+=16){const cell=Math.floor((x-origin[0])/tile)+','+Math.floor((y-origin[1])/tile);if(!occupied.has(cell))assert.equal(study.demo.depthMaskAlpha(r,layer,x,y),0,r.id+' foreground base covers void '+x+','+y);}}}});
  check('Native terrain uses integer source and destination rectangles',()=>{for(const r of study.demo.getSnapshot().regions)for(const p of r.terrainDraws){assert(Number.isInteger(p.x)&&Number.isInteger(p.y));assert(p.source.every(Number.isInteger));assert(p.source[2]<=32&&p.source[3]<=32);}});
  check('Pause holds the displayed scene and play advances it',()=>{const before=sha(study.screen);study.demo.render(6200);assert.equal(before,sha(study.screen));study.elements['region-motion'].click();study.demo.render(7200);assert.notEqual(before,sha(study.screen));});
  study.demo.setPaused(true);study.demo.seek(1200);study.demo.setLighting(true);study.demo.renderAll();
  const embeddings=[];
  for(const file of options.htmlFiles||[]){const html=fs.readFileSync(file,'utf8'),packed=await createStudy(parseEmbedded(html)),regionHashes={};packed.demo.setPaused(true);packed.demo.seek(1200);packed.demo.setLighting(true);packed.demo.renderAll();for(const r of packed.data.regions){regionHashes[r.id]=sha(packed.canvases[r.id]);assert.equal(regionHashes[r.id],sha(study.canvases[r.id]),'Embedded frame mismatch '+file+':'+r.id);}embeddings.push({file,bytes:Buffer.byteLength(html),regions:packed.data.regions.map(r=>r.id),matchesSource:true,frameHashes:regionHashes});}
  const result={renderer:'web/study.js executed in Canvas/Skia',passed:true,checks,embeddings,sceneHash:crypto.createHash('sha256').update(fs.readFileSync(path.join(dir,'web/study.js'))).digest('hex'),limits:['This report executes the exact scene through Canvas/Skia; browser visual evidence is recorded separately','Godot rendering validated separately; these images are Canvas frames','Lighting is a 2D light-map approximation, not normal-mapped 3D material shading','No full gameplay regression']};
  fs.writeFileSync(path.join(dir,'previews/assembly-checks.json'),JSON.stringify(result,null,2)+'\n');return result;
}
async function main(){const args=process.argv.slice(2);if(args.includes('--help')){console.log('node render-study.cjs [--all] [--video] [--before-after] [--verify]');return;}const study=await createStudy(),result={};if(args.includes('--all')||!args.length)result.images=renderAll(study);if(args.includes('--video'))result.video=await renderVideo(study,{showUnlit:false,label:'更新后'});if(args.includes('--before-after'))result.beforeAfter=await renderBeforeAfter(study);if(args.includes('--verify'))result.validation=await verify(study);console.log(JSON.stringify(result,null,2));}
if(require.main===module)main().catch(error=>{console.error(error);process.exitCode=1;});
module.exports={createStudy,renderAll,renderVideo,renderBeforeAfter,savePNG,composite,comparison,parseEmbedded,verify};
