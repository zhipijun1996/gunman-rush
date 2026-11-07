/* Native sprite assembly, regional terrain and an occlusion-aware 2D light field.
 * All artwork is loaded from the asset manifest. Gradients and silhouettes below
 * are scene lighting and particle rendering, never replacement environment art. */
(() => {
  'use strict';
  const root=document.getElementById('region-lighting-study');
  if(!root)return;
  const data=window.STUDY_DATA,manifest=window.STUDY_MANIFEST;
  if(!data||!manifest)throw new Error('Scene data and asset manifest are required.');
  const W=data.viewport.width,H=data.viewport.height,$=id=>document.getElementById(id);
  const clamp=(v,a,b)=>Math.max(a,Math.min(b,v)),mod=(v,n)=>((v%n)+n)%n,clone=v=>JSON.parse(JSON.stringify(v));
  const rgb=(v,a=1)=>`rgba(${v.map(n=>Math.round(clamp(n,0,1)*255)).join(',')},${clamp(a,0,1)})`;
  const images={sprites:{},backgrounds:{}},views={},terrains={},terrainRecords={},geometry={},occluders={},particles={},lightWeights={},depthBuffers=new Map(),tintedSprites=new Map();
  const selectedDefault=data.regions.find(r=>r.id===data.defaultRegion)||data.regions.find(r=>r.id==='mushroom_caverns')||data.regions[0];
  const state={region:selectedDefault.id,lighting:true,depth:true,protection:true,camera:true,cameraManual:null,paused:true,timeMs:1200,offsetMs:0,frozenMs:1200,ready:false,loaded:0,failed:[]};
  let loop=true,raf=0;
  function newCanvas(w=W,h=H){const c=document.createElement('canvas');c.width=w;c.height=h;c.getContext('2d').imageSmoothingEnabled=false;return c;}
  function trace(ctx,points){ctx.beginPath();ctx.moveTo(points[0][0],points[0][1]);for(let i=1;i<points.length;i++)ctx.lineTo(points[i][0],points[i][1]);ctx.closePath();}
  function clear(canvas){const g=canvas.getContext('2d');g.globalCompositeOperation='source-over';g.globalAlpha=1;g.clearRect(0,0,canvas.width,canvas.height);return g;}
  const screen=$('region-scene');if(!screen)throw new Error('Scene canvas is missing.');
  screen.width=W;screen.height=H;const screenCtx=screen.getContext('2d');screenCtx.imageSmoothingEnabled=false;
  const world=newCanvas(),litWorld=newCanvas(),lightLayer=newCanvas(),backgroundLayer=newCanvas(),contactLayer=newCanvas();
  for(const region of data.regions){const canvas=newCanvas();views[region.id]={canvas,ctx:canvas.getContext('2d')};}
  const seconds=()=>Math.max(0,state.paused?state.frozenMs:state.timeMs-state.offsetMs)/1000;
  function regionById(id){const r=data.regions.find(v=>v.id===id);if(!r)throw new Error('Unknown region '+id);return r;}
  function spriteMeta(name){const m=manifest.sprites[name];if(!m)throw new Error('Missing sprite '+name);return m;}
  function spriteBounds(item){const f=spriteMeta(item.asset),px=item.pivotX===undefined?f.pivotX:item.pivotX,py=item.pivotY===undefined?f.pivotY:item.pivotY;return {x:Math.round(item.x-(item.flip?f.w-px:px)),y:Math.round(item.y-py),w:f.w,h:f.h};}
  function tintedImage(item){
    const original=images.sprites[item.asset],tint=item.tint;
    if(!tint||tint.every(v=>v===1))return original;
    const key=item.asset+':'+tint.join(',');if(tintedSprites.has(key))return tintedSprites.get(key);
    const f=spriteMeta(item.asset),canvas=newCanvas(f.w,f.h),g=canvas.getContext('2d');g.drawImage(original,0,0);
    const image=g.getImageData(0,0,f.w,f.h),p=image.data;
    for(let i=0;i<p.length;i+=4){p[i]=Math.min(255,Math.round(p[i]*tint[0]));p[i+1]=Math.min(255,Math.round(p[i+1]*tint[1]));p[i+2]=Math.min(255,Math.round(p[i+2]*tint[2]));}
    g.putImageData(image,0,0);tintedSprites.set(key,canvas);return canvas;
  }
  function drawSprite(ctx,item,t){
    const f=spriteMeta(item.asset),im=tintedImage(item);if(!im)return;
    const b=spriteBounds(item),flip=!!item.flip,tipRows=Math.max(1,Math.floor(f.h*.55));
    const sway=item.sway?Math.sin(t*1.55-item.x*.012+(item.phase||0))*item.sway:0;
    ctx.save();ctx.globalAlpha=item.opacity===undefined?1:item.opacity;ctx.translate(b.x+(flip?f.w:0),b.y);if(flip)ctx.scale(-1,1);
    if(item.sway){for(let row=0;row<tipRows;row++){const dx=Math.round(sway*Math.pow(1-row/tipRows,2))*(flip?-1:1);ctx.drawImage(im,0,row,f.w,1,dx,row,f.w,1);}ctx.drawImage(im,0,tipRows,f.w,f.h-tipRows,0,tipRows,f.w,f.h-tipRows);}
    else ctx.drawImage(im,0,0);
    ctx.restore();
  }
  function terrainGrid(region){return region.terrainGrid||data.terrainGrid;}
  function terrainSpec(region){const spec=terrainGrid(region)?manifest.terrain47&&manifest.terrain47.regions[region.id]:manifest.terrains&&manifest.terrains[region.id]||manifest.terrain;if(!spec)throw new Error('Missing native terrain for '+region.id);return spec;}
  function normalizedMask(mask){
    if(!(mask&1)||!(mask&4))mask&=~2;
    if(!(mask&4)||!(mask&16))mask&=~8;
    if(!(mask&16)||!(mask&64))mask&=~32;
    if(!(mask&64)||!(mask&1))mask&=~128;
    return mask;
  }
  function gridGeometry(region){
    const grid=terrainGrid(region),tile=grid.tile||32,origin=grid.origin||[0,0],cells=grid.cells,occupied=new Set(cells.map(c=>c[0]+','+c[1]));
    const rows=new Map(),tops=new Map();
    for(const [x,y] of cells){if(!rows.has(y))rows.set(y,[]);rows.get(y).push(x);if(!occupied.has(x+','+(y-1))){if(!tops.has(y))tops.set(y,[]);tops.get(y).push(x);}}
    const runs=collection=>{const result=[];for(const [y,xs] of [...collection].sort((a,b)=>a[0]-b[0])){const sorted=[...new Set(xs)].sort((a,b)=>a-b);let start=sorted[0],end=start+1;for(const x of sorted.slice(1)){if(x===end)end++;else{result.push([start,y,end]);start=x;end=x+1;}}if(sorted.length)result.push([start,y,end]);}return result;};
    const merged=[],active=new Map();for(const [x,y,right] of runs(rows)){const key=x+','+right,prior=active.get(key);if(prior&&prior[3]===y)prior[3]++;else{const rect=[x,y,right,y+1];merged.push(rect);active.set(key,rect);}}
    const bodies=merged.map((r,i)=>{const left=origin[0]+r[0]*tile,right=origin[0]+r[2]*tile,top=origin[1]+r[1]*tile,bottom=origin[1]+r[3]*tile;return {id:'grid-'+i,top:[[left,top],[right,top]],points:[[left,top],[right,top],[right,bottom],[left,bottom]]};});
    const surfaces=runs(tops).map(([x,y,right])=>({left:origin[0]+x*tile,right:origin[0]+right*tile,y:origin[1]+y*tile}));
    return {grid:true,tile,origin,occupied,bodies,surfaces};
  }
  function gridTerrainRecords(region){
    const geo=geometry[region.id],spec=terrainSpec(region),tile=geo.tile;
    const neighbors=[[0,-1,1],[1,-1,2],[1,0,4],[1,1,8],[0,1,16],[-1,1,32],[-1,0,64],[-1,-1,128]];
    return terrainGrid(region).cells.map(([cx,cy])=>{let mask=0;for(const [dx,dy,bit] of neighbors)if(geo.occupied.has((cx+dx)+','+(cy+dy)))mask|=bit;mask=normalizedMask(mask);const atlas=spec.maskToAtlas[String(mask)];if(!atlas)throw new Error('Missing 47 mask '+mask+' for '+region.id);return {terrain:'grid',asset:spec.asset,x:geo.origin[0]+cx*tile,y:geo.origin[1]+cy*tile-(spec.surfaceY||0),source:[atlas[0]*tile,atlas[1]*tile,tile,tile],cell:[cx,cy],mask,pass:'terrain47'};});
  }
  function gridOccluders(geo,inset){
    const polygons=[];
    for(const body of geo.bodies){const left=body.points[0][0],right=body.points[1][0],top=body.points[0][1],bottom=body.points[2][1],exposed=geo.surfaces.filter(s=>s.y===top&&s.right>left&&s.left<right),cuts=[...new Set([left,right,...exposed.flatMap(s=>[Math.max(left,s.left),Math.min(right,s.right)])])].sort((a,b)=>a-b);
      for(let i=0;i<cuts.length-1;i++){const x0=cuts[i],x1=cuts[i+1],middle=(x0+x1)/2,open=exposed.some(s=>middle>=s.left&&middle<s.right),y=top+(open?Math.min(inset,bottom-top-1):0);polygons.push([[x0,y],[x1,y],[x1,bottom],[x0,bottom]]);}
    }return polygons;
  }
  function nativeTerrainRecords(terrain,region){
    const spec=terrainSpec(region),tile=spec.tile,bank=region.terrainBank===undefined?spec.bank||0:region.terrainBank;
    const left=Math.round(terrain.top[0][0]),right=Math.round(terrain.top[terrain.top.length-1][0]),surface=Math.round(terrain.top[0][1]);
    if(terrain.top.some(p=>p[1]!==terrain.top[0][1])||right-left<tile*2)throw new Error('This material study supports horizontal platforms at least two tiles wide.');
    const top=surface-spec.surfaceY,bottom=Math.round(Math.max(...terrain.points.map(p=>p[1]))),records=[];
    const add=(kind,x,y,w=tile,h=tile)=>{const c=spec.coords[kind];records.push({terrain:terrain.id,asset:spec.asset,x,y,source:[(c[0]+bank*(spec.bankColumns||8))*tile,c[1]*tile,w,h],pass:'native-tile'});};
    const row=(y,h,l,c,r)=>{add(l,left,y,tile,h);for(let x=left+tile;x<right-tile;x+=tile)add(c,x,y,Math.min(tile,right-tile-x),h);add(r,right-tile,y,tile,h);};
    row(top,tile,'tl','t','tr');for(let y=top+tile;y<bottom;y+=tile)row(y,Math.min(tile,bottom-y),'l','i','r');row(bottom,tile,'bl','b','br');return records;
  }
  function prepareTerrain(region){
    const canvas=newCanvas(),g=canvas.getContext('2d'),records=[];
    geometry[region.id]=terrainGrid(region)?gridGeometry(region):{grid:false,bodies:region.terrain||data.terrain,surfaces:(region.terrain||data.terrain).map(t=>({left:t.top[0][0],right:t.top[t.top.length-1][0],y:t.top[0][1]}))};
    geometry[region.id].maskRows=Array.from({length:H},(_,y)=>{const intervals=geometry[region.id].bodies.filter(b=>y>=b.points[0][1]&&y<b.points[2][1]).map(b=>[b.points[0][0],b.points[1][0]]).sort((a,b)=>a[0]-b[0]),merged=[];for(const s of intervals){const last=merged[merged.length-1];if(last&&s[0]<=last[1])last[1]=Math.max(last[1],s[1]);else merged.push(s.slice());}return merged;});
    const pending=terrainGrid(region)?gridTerrainRecords(region):geometry[region.id].bodies.flatMap(t=>nativeTerrainRecords(t,region));
    for(const item of pending){const [sx,sy,w,h]=item.source;g.drawImage(images.sprites[item.asset],sx,sy,w,h,item.x,item.y,w,h);records.push(item);}
    terrainRecords[region.id]=records;terrains[region.id]=canvas;
    const inset=region.lighting&&region.lighting.shadowInset!==undefined?region.lighting.shadowInset:10,sideInset=region.lighting&&region.lighting.shadowSideInset!==undefined?region.lighting.shadowSideInset:2;
    occluders[region.id]=geometry[region.id].grid?gridOccluders(geometry[region.id],inset):geometry[region.id].bodies.map(t=>{const left=t.top[0][0]+sideInset,right=t.top[t.top.length-1][0]-sideInset,top=t.top[0][1]+inset,bottom=Math.max(H+256,...t.points.map(p=>p[1]));return [[left,top],[right,top],[right,bottom],[left,bottom]];});
    for(const polygon of region.lighting&&region.lighting.occluders||[])occluders[region.id].push(clone(polygon.points||polygon));
  }
  function pointInPolygon(x,y,polygon){let inside=false;for(let i=0,j=polygon.length-1;i<polygon.length;j=i++){const a=polygon[i],b=polygon[j];if(((a[1]>y)!==(b[1]>y))&&(x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]))inside=!inside;}return inside;}
  function castShadows(g,light,region){
    const lx=light.x,ly=light.y,reach=Math.max(W,H)*5;
    g.save();g.globalCompositeOperation='destination-out';g.fillStyle='#000';
    for(const polygon of occluders[region.id]){
      if(pointInPolygon(lx,ly,polygon)){g.clearRect(0,0,W,H);break;}
      trace(g,polygon);g.fill();
      let area=0;for(let i=0;i<polygon.length;i++){const a=polygon[i],b=polygon[(i+1)%polygon.length];area+=a[0]*b[1]-b[0]*a[1];}
      for(let i=0;i<polygon.length;i++){
        const a=polygon[i],b=polygon[(i+1)%polygon.length],cross=(b[0]-a[0])*(ly-a[1])-(b[1]-a[1])*(lx-a[0]);
        if(cross*(area>=0?1:-1)>=0)continue;
        const extend=p=>{const dx=p[0]-lx,dy=p[1]-ly,d=Math.max(1,Math.hypot(dx,dy));return [Math.round(p[0]+dx/d*reach),Math.round(p[1]+dy/d*reach)];};
        trace(g,[a,b,extend(b),extend(a)]);g.fill();
      }
    }
    g.restore();
  }
  function flicker(light,index,t){const amp=light.flicker||0;return (light.energy===undefined?1:light.energy)*(1+amp*(.65*Math.sin(t*3+index)+.35*Math.sin(t*5.7+index*.3)));}
  function drawUnitFalloff(g,light){
    const radius=Math.max(1,light.radius),gradient=g.createRadialGradient(light.x,light.y,0,light.x,light.y,radius);
    gradient.addColorStop(0,'rgba(255,255,255,1)');gradient.addColorStop(.25,'rgba(255,255,255,0.65)');gradient.addColorStop(.6,'rgba(255,255,255,0.18)');gradient.addColorStop(1,'rgba(255,255,255,0)');
    g.fillStyle=gradient;g.fillRect(Math.floor(light.x-radius),Math.floor(light.y-radius),Math.ceil(radius*2),Math.ceil(radius*2));
  }
  function prepareLightWeights(region){
    const spec=region.lighting||{},lights=(spec.lights||[]).map(l=>Object.assign({},l));
    if(spec.heroFill)lights.push({id:'hero-fill',x:data.hero.x-8,y:data.hero.y-22,radius:64,color:[1,.96,.86],energy:typeof spec.heroFill==='number'?spec.heroFill:.15,shadow:false,visible:false});
    lightWeights[region.id]=lights.map((light,index)=>{
      const g=clear(lightLayer);drawUnitFalloff(g,light);if(light.shadow!==false)castShadows(g,light,region);
      const rgba=g.getImageData(0,0,W,H).data,weights=new Uint8Array(W*H);for(let i=0;i<weights.length;i++)weights[i]=rgba[i*4+3];
      return {light,index,weights};
    });
  }
  function shadeWorld(region,t){
    // Keep light coefficients in floating point above 1.0. An 8-bit multiply
    // light-map would cap a bright source at the original material color.
    const image=world.getContext('2d').getImageData(0,0,W,H),pixels=image.data,ambient=region.lighting&&region.lighting.ambient||[1,1,1];
    const lamps=lightWeights[region.id].map(item=>({weights:item.weights,color:item.light.color||[1,.86,.65],energy:flicker(item.light,item.index,t)/255}));
    for(let i=0,p=0;i<pixels.length;i+=4,p++){
      if(pixels[i+3]===0)continue;let red=ambient[0],green=ambient[1],blue=ambient[2];
      for(const lamp of lamps){const energy=lamp.weights[p]*lamp.energy;red+=lamp.color[0]*energy;green+=lamp.color[1]*energy;blue+=lamp.color[2]*energy;}
      pixels[i]=Math.min(255,Math.round(pixels[i]*red));pixels[i+1]=Math.min(255,Math.round(pixels[i+1]*green));pixels[i+2]=Math.min(255,Math.round(pixels[i+2]*blue));
    }
    const g=clear(litWorld);g.putImageData(image,0,0);return litWorld;
  }
  function cameraOffset(t){
    if(!state.camera)return 0;
    if(state.cameraManual!==null)return state.cameraManual;
    const camera=data.camera||{},amplitude=Math.min(32,Math.max(0,camera.amplitude===undefined?32:camera.amplitude));
    return Math.round(amplitude*Math.sin((t-(camera.originSeconds===undefined?1.2:camera.originSeconds))*(camera.frequency===undefined?.45:camera.frequency)));
  }
  function drawCovered(ctx,canvas,offset){
    // Mirror only native edge pixels into the small camera overscan. This keeps
    // the original image at 1:1 and never stretches a column or the whole plate.
    const x=Math.round(offset),pad=64;ctx.drawImage(canvas,x,0);
    if(x>0){ctx.save();ctx.translate(x,0);ctx.scale(-1,1);ctx.drawImage(canvas,0,0,pad,H,0,0,pad,H);ctx.restore();}
    if(x<0){ctx.save();ctx.translate(x+W,0);ctx.scale(-1,1);ctx.drawImage(canvas,W-pad,0,pad,H,-pad,0,pad,H);ctx.restore();}
  }
  function drawDepthLayers(ctx,region,kind,t,camera){
    if(!state.depth)return;
    for(const layer of region.layers||[]){
      if(layer.kind!==kind||layer.visible===false)continue;
      const parallax=layer.parallax===undefined?(kind==='near'?1.10:.45):layer.parallax;
      const tint=layer.tint||[1,1,1],ambient=state.lighting?(layer.ambient||region.lighting&&region.lighting.backgroundAmbient||[1,1,1]):[1,1,1];
      const item=Object.assign({},layer,{x:Math.round(layer.x)-Math.round(camera*parallax),y:Math.round(layer.y),tint:tint.map((c,i)=>c*ambient[i])});
      if(!layer.mask){drawSprite(ctx,item,t);continue;}
      const bufferKey=region.id+':'+layer.id;if(!depthBuffers.has(bufferKey))depthBuffers.set(bufferKey,newCanvas());
      const depthLayer=depthBuffers.get(bufferKey),g=clear(depthLayer);drawSprite(g,item,t);const bounds=spriteBounds(item),x0=Math.max(0,bounds.x-2),y0=Math.max(0,bounds.y),width=Math.min(W,bounds.x+bounds.w+2)-x0,height=Math.min(H,bounds.y+bounds.h)-y0;
      if(width<=0||height<=0)continue;
      const pixels=g.getImageData(x0,y0,width,height),p=pixels.data;
      for(let y=0;y<height;y++)for(let x=0;x<width;x++){const at=(y*width+x)*4+3;if(p[at])p[at]=Math.round(p[at]*depthMaskAlpha(region,layer,x0+x+camera,y0+y));}
      g.putImageData(pixels,x0,y0);ctx.drawImage(depthLayer,0,0);
    }
  }
  function depthMaskAlpha(region,layer,x,y){
    const mask=layer.mask||{},spans=geometry[region.id].surfaces;
    let alpha=1;
    if(mask.type==='platform_band'&&spans.length){
      const under=spans.filter(s=>layer.x>=s.left&&layer.x<=s.right),candidates=under.length?under:spans;
      const nearest=candidates.reduce((best,s)=>Math.abs(s.y-layer.y)<Math.abs(best.y-layer.y)?s:best,candidates[0]),surface=mask.surfaceY===undefined?nearest.y:mask.surfaceY,fade=Math.max(1,mask.edgeFade||8),above=mask.above===undefined?72:mask.above,below=mask.below===undefined?72:mask.below;
      const vertical=clamp((y-(surface-above))/fade,0,1)*clamp((surface+below-y)/fade,0,1);
      let support=0;for(const s of spans){if(Math.abs(s.y-surface)>16)continue;const left=s.left<=0?-64:s.left,right=s.right>=W?W+64:s.right;support=Math.max(support,Math.min(clamp((x-left)/fade,0,1),clamp((right-x)/fade,0,1)));}
      if(y>=surface){let solid=0;for(const interval of geometry[region.id].maskRows[Math.floor(y)]||[]){const left=interval[0]<=0?-64:interval[0],right=interval[1]>=W?W+64:interval[1];solid=Math.max(solid,Math.min(clamp((x-left)/fade,0,1),clamp((right-x)/fade,0,1)));}support=Math.min(support,solid);}
      // Only the base follows the platform cut-out. The upper silhouette may
      // overhang a gap, so no new flat cutoff is painted through the foliage.
      const base=clamp((y-surface+12)/20,0,1);alpha*=vertical*(1-base+base*support);
    }
    if(state.protection&&mask.heroReveal){const reveal=mask.heroReveal,rx=reveal.radiusX||30,ry=reveal.radiusY||48,minimum=reveal.minAlpha===undefined?.15:reveal.minAlpha;const d=Math.hypot((x-(data.hero.x-8))/rx,(y-(data.hero.y-22))/ry),u=clamp((d-.35)/.65,0,1),smooth=u*u*(3-2*u);alpha*=minimum+(1-minimum)*smooth;}
    return alpha;
  }
  function drawBackground(ctx,region,camera){
    const g=clear(backgroundLayer);g.fillStyle=region.palette&&region.palette.sky||'#15222b';g.fillRect(0,0,W,H);const bg=images.backgrounds[region.background];if(bg)g.drawImage(bg,0,0);
    if(state.lighting){g.globalCompositeOperation='multiply';g.fillStyle=rgb(region.lighting&&region.lighting.backgroundAmbient||[1,1,1]);g.fillRect(0,0,W,H);g.globalCompositeOperation='source-over';}
    drawCovered(ctx,backgroundLayer,-Math.round(camera*(region.backgroundParallax===undefined?.12:region.backgroundParallax)));
    if(!state.lighting)return;
    ctx.save();ctx.translate(-camera,0);
    for(const beam of region.lighting&&region.lighting.beams||[]){
      const points=beam.points;if(!points||points.length<3)continue;const minY=Math.min(...points.map(p=>p[1])),maxY=Math.max(...points.map(p=>p[1]));
      const gradient=ctx.createLinearGradient(0,minY,0,maxY);gradient.addColorStop(0,rgb(beam.color||[.7,.8,1],beam.alpha||.07));gradient.addColorStop(1,rgb(beam.color||[.7,.8,1],0));
      ctx.save();ctx.globalCompositeOperation='screen';trace(ctx,points);ctx.fillStyle=gradient;ctx.fill();ctx.restore();
    }
    ctx.restore();
  }
  function drawLightSources(ctx,region,t){
    if(!state.lighting)return;
    (region.lighting&&region.lighting.lights||[]).forEach((light,i)=>{
      if(light.visible===false||light.coreRadius===0)return;
      const x=Math.round(light.x),y=Math.round(light.y),strength=flicker(light,i,t),r=Math.max(1,Math.round(light.coreRadius===undefined?2:light.coreRadius));
      const glow=Math.min(30,light.radius*.22),gradient=ctx.createRadialGradient(x,y,0,x,y,glow);
      gradient.addColorStop(0,rgb(light.color||[1,.86,.65],Math.min(.18,.12*strength)));gradient.addColorStop(1,rgb(light.color||[1,.86,.65],0));
      ctx.save();ctx.globalCompositeOperation='screen';ctx.fillStyle=gradient;ctx.fillRect(x-glow,y-glow,glow*2,glow*2);ctx.fillStyle=rgb((light.color||[1,.86,.65]).map(v=>.7+v*.3),.9);ctx.fillRect(x-r,y-r,2*r,2*r);ctx.restore();
    });
  }
  function createParticles(region){
    const settings=region.particles||{},count=settings.count===undefined?24:settings.count;let seed=((data.motion&&data.motion.seed)||93)>>>0;for(const ch of region.id)seed=(seed*31+ch.charCodeAt(0))>>>0;
    const rand=()=>{seed=(seed*1664525+1013904223)>>>0;return seed/4294967296;};
    const result=[];for(let i=0;i<count;i++)result.push({id:i,startX:-16+rand()*(W+32),startY:38+rand()*(H-80),speedFactor:.65+rand()*.7,phase:rand()*Math.PI*2,amp:2+rand()*4,depth:i%5===0?'near':'mid'});return result;
  }
  function particleState(p,region,t){
    const spec=region.particles||{},speed=spec.speed===undefined?19:spec.speed,vertical=spec.vertical===undefined?-3:spec.vertical;
    const x=Math.round(-16+mod(p.startX+16+t*speed*p.speedFactor,W+32));
    const y=Math.round(28+mod(p.startY-28+t*vertical+Math.sin(t*.85+p.phase)*p.amp,H-56));
    const alpha=clamp(Math.min(x+16,W+16-x)/18,0,1)*(.64+.2*Math.sin(t*1.2+p.phase));
    const b=spriteBounds(data.hero),blocked=geometry[region.id].bodies.some(terrain=>pointInPolygon(x,y,terrain.points))||(x>b.x-4&&x<b.x+b.w+4&&y>b.y-3&&y<b.y+b.h+3);
    return {id:p.id,x,y,alpha:blocked?0:alpha,depth:p.depth,speed,vertical};
  }
  function drawParticles(ctx,region,t){
    const spec=region.particles||{},color=spec.color||[1,.91,.65],kind=spec.kind||'dust';
    for(const p of particles[region.id]){
      const s=particleState(p,region,t);if(s.alpha<=0)continue;
      const len=kind==='embers'?5:kind==='spores'?3:6,dx=Math.sign(s.speed)||1,dy=kind==='embers'?1:Math.sign(-s.vertical);
      ctx.save();ctx.globalCompositeOperation='screen';
      for(let k=len;k>0;k--){ctx.fillStyle=rgb(color,s.alpha*(1-k/(len+1))*.32);ctx.fillRect(s.x-dx*k,s.y+Math.round(dy*k*.25),1,1);}
      ctx.fillStyle=rgb(color.map(v=>.55+v*.45),s.alpha);ctx.fillRect(s.x,s.y,kind==='embers'?1:2,2);
      if(p.depth==='near'){ctx.fillStyle=rgb(color,.12*s.alpha);ctx.fillRect(s.x-1,s.y-1,4,4);}
      ctx.restore();
    }
  }
  function drawInstances(ctx,region,group,t){for(const item of region.instances||[])if(item.group===group)drawSprite(ctx,item,t);}
  function drawContactShadows(ctx,region){
    const g=clear(contactLayer),items=[...(region.instances||[]).filter(p=>p.group==='structure'||p.group==='detail'),data.hero];
    for(const item of items){
      const terrain=geometry[region.id].surfaces.find(p=>item.x>=p.left&&item.x<=p.right&&Math.abs(item.y-p.y)<=16);if(!terrain)continue;
      const f=spriteMeta(item.asset),b=spriteBounds(item),im=images.sprites[item.asset],strip=Math.min(8,f.h),y=terrain.y-1;
      g.save();g.beginPath();g.rect(terrain.left,y,terrain.right-terrain.left,3);g.clip();
      g.translate(b.x+(item.flip?f.w:0),y);if(item.flip)g.scale(-1,1);g.drawImage(im,0,f.h-strip,f.w,strip,0,0,f.w,3);g.restore();
    }
    g.globalCompositeOperation='source-in';g.fillStyle='rgba(4,8,13,0.32)';g.fillRect(0,0,W,H);
    g.globalCompositeOperation='destination-in';g.drawImage(terrains[region.id],0,0);g.globalCompositeOperation='source-over';ctx.drawImage(contactLayer,0,0);
  }
  function renderRegion(region,t){
    const out=views[region.id].ctx,camera=cameraOffset(t);out.clearRect(0,0,W,H);drawBackground(out,region,camera);drawDepthLayers(out,region,'mid',t,camera);
    const wg=clear(world);drawInstances(wg,region,'structure',t);wg.drawImage(terrains[region.id],0,0);if(state.lighting)drawContactShadows(wg,region);drawInstances(wg,region,'detail',t);drawSprite(wg,data.hero,t);drawInstances(wg,region,'attached',t);drawInstances(wg,region,'foreground',t);
    drawCovered(out,state.lighting?shadeWorld(region,t):world,-camera);out.save();out.translate(-camera,0);drawLightSources(out,region,t);drawParticles(out,region,t);out.restore();drawDepthLayers(out,region,'near',t,camera);return views[region.id];
  }
  function render(timeMs=state.timeMs,all=false){
    if(Number.isFinite(timeMs))state.timeMs=timeMs;if(!state.ready)return;
    const t=seconds();if(all)for(const region of data.regions)renderRegion(region,t);else renderRegion(regionById(state.region),t);
    screenCtx.clearRect(0,0,W,H);screenCtx.drawImage(views[state.region].canvas,0,0);return views;
  }
  function syncUI(){
    const region=regionById(state.region),select=$('region-select');if(select)select.value=state.region;
    root.querySelectorAll('[data-lighting]').forEach(button=>button.setAttribute('aria-pressed',String((button.dataset.lighting==='on')===state.lighting)));
    const motion=$('region-motion');if(motion){motion.textContent=state.paused?'播放环境':'暂停环境';motion.setAttribute('aria-pressed',String(!state.paused));}
    const depth=$('region-depth');if(depth){depth.textContent=state.depth?'景深层：开':'景深层：关';depth.setAttribute('aria-pressed',String(state.depth));}
    const protection=$('region-protection');if(protection){protection.textContent=state.protection?'角色避让：开':'角色避让：关';protection.setAttribute('aria-pressed',String(state.protection));}
    const caption=$('region-caption');if(caption)caption.textContent=region.name;
    const status=$('region-status');if(status)status.textContent=(state.lighting?'场景光照':'素材原色')+' · '+(state.depth?'分层景深':'隐藏景深层')+' · '+(region.materialLabel||region.material||'原生像素地形');
    screen.setAttribute('aria-label',region.name+'：'+(state.lighting?'区域光照、遮挡与环境粒子':'原素材颜色对照'));
  }
  function setRegion(id){regionById(id);state.region=id;syncUI();render();}
  function setLighting(value){state.lighting=!!value;syncUI();render();}
  function setDepth(value){state.depth=!!value;syncUI();render();}
  function setCamera(value){state.camera=!!value;render();}
  function setCameraOffset(value){state.cameraManual=value===null?null:Math.round(clamp(Number(value),-32,32));render();}
  function setProtection(value){state.protection=!!value;syncUI();render();}
  function setPaused(value){const paused=!!value;if(paused===state.paused)return;if(paused)state.frozenMs=state.timeMs-state.offsetMs;else state.offsetMs=state.timeMs-state.frozenMs;state.paused=paused;syncUI();render();}
  function seek(ms){state.timeMs=ms;state.offsetMs=0;state.frozenMs=ms;render();}
  function usedAssets(){const sprites=new Set([data.hero.asset]),backgrounds=new Set();for(const r of data.regions){sprites.add(terrainSpec(r).asset);for(const p of r.instances||[])sprites.add(p.asset);for(const p of r.layers||[])sprites.add(p.asset);backgrounds.add(r.background);}return {sprites:[...sprites],backgrounds:[...backgrounds]};}
  function loadImage(group,name){const m=manifest[group][name];if(!m)throw new Error('Missing asset metadata '+name);return new Promise(resolve=>{const image=new Image();image.onload=()=>{images[group][name]=image;state.loaded++;resolve(image);};image.onerror=()=>{state.failed.push(group+':'+name);resolve(null);};const packed=window.STUDY_ASSETS&&window.STUDY_ASSETS[group];image.src=packed&&packed[name]||m.file;});}
  async function load(){
    const needed=usedAssets(),pending=[];for(const group of ['sprites','backgrounds'])for(const name of needed[group])pending.push(loadImage(group,name));await Promise.all(pending);
    if(state.failed.length)throw new Error('Missing assets: '+state.failed.join(', '));
    for(const group of ['sprites','backgrounds'])for(const name of needed[group]){const m=manifest[group][name],im=images[group][name];if(im.width!==m.w||im.height!==m.h)throw new Error('Native dimensions mismatch '+name);}
    for(const region of data.regions){prepareTerrain(region);prepareLightWeights(region);particles[region.id]=createParticles(region);}
    state.ready=true;const loading=$('region-loading');if(loading)loading.hidden=true;syncUI();render(state.timeMs,true);return {loaded:state.loaded,required:needed};
  }
  function getState(){return {region:state.region,lighting:state.lighting,depth:state.depth,protection:state.protection,camera:state.camera,cameraOffset:cameraOffset(seconds()),cameraManual:state.cameraManual,paused:state.paused,ready:state.ready,ambientSeconds:seconds(),loaded:state.loaded,failed:state.failed.slice()};}
  function getSnapshot(){const t=seconds();return {viewport:clone(data.viewport),hero:clone(data.hero),terrain:clone(data.terrain||[]),terrainGrid:clone(data.terrainGrid||null),regions:data.regions.map(r=>({id:r.id,terrainSpec:clone(terrainSpec(r)),terrainDraws:clone(terrainRecords[r.id]||[]),surfaces:clone(geometry[r.id].surfaces),bodies:clone(geometry[r.id].bodies),occluders:clone(occluders[r.id]||[]),lighting:clone(r.lighting||{}),layers:(r.layers||[]).map(p=>Object.assign(clone(p),{screenOffset:-Math.round(cameraOffset(t)*(p.parallax===undefined?(p.kind==='near'?1.10:.45):p.parallax)),drawBounds:spriteBounds(p)})),instances:(r.instances||[]).map(p=>Object.assign(clone(p),{drawBounds:spriteBounds(p)})),particles:(particles[r.id]||[]).map(p=>particleState(p,r,t))})),state:getState()};}
  if($('region-select'))$('region-select').addEventListener('change',event=>setRegion(event.target.value));
  if($('region-depth'))$('region-depth').addEventListener('click',()=>setDepth(!state.depth));
  if($('region-protection'))$('region-protection').addEventListener('click',()=>setProtection(!state.protection));
  if($('region-camera-left'))$('region-camera-left').addEventListener('click',()=>setCameraOffset(-32));
  if($('region-camera-center'))$('region-camera-center').addEventListener('click',()=>setCameraOffset(0));
  if($('region-camera-right'))$('region-camera-right').addEventListener('click',()=>setCameraOffset(32));
  if($('region-motion'))$('region-motion').addEventListener('click',()=>{if(state.paused)state.cameraManual=null;setPaused(!state.paused);});
  root.querySelectorAll('[data-lighting]').forEach(button=>button.addEventListener('click',()=>setLighting(button.dataset.lighting==='on')));
  function tick(ms){if(!loop)return;state.timeMs=ms;if(!state.paused)render(ms);raf=requestAnimationFrame(tick);}
  window.StudyDemo={views,screen,render,renderAll(ms=state.timeMs){return render(ms,true);},setRegion,setLighting,setDepth,setCamera,setCameraOffset,setProtection,setPaused,seek,getState,getSnapshot,usedAssets,nativeTerrainRecords,normalizedMask,depthMaskAlpha,pauseLoop(){loop=false;cancelAnimationFrame(raf);},resumeLoop(){if(!loop){loop=true;raf=requestAnimationFrame(tick);}},ready:null};
  syncUI();window.StudyDemo.ready=load().catch(error=>{const loading=$('region-loading');if(loading){loading.hidden=false;loading.textContent='素材加载失败：'+error.message;}throw error;});raf=requestAnimationFrame(tick);
})();
