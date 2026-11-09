#!/usr/bin/env node
'use strict';
// Offline packing preserves the native raster dimensions. Terrain remains PNG.
const fs=require('fs'),path=require('path'),dir=__dirname;
const {withTerrain47,terrainSpec}=require('./web/asset-manifest.cjs');
const sharp = require('sharp');
const read=name=>fs.readFileSync(path.join(dir,name),'utf8'),json=name=>JSON.parse(read(name)),safeJSON=value=>JSON.stringify(value).replace(/</g,'\\u003c');
const dataURL=(buffer,mime)=>'data:'+mime+';base64,'+buffer.toString('base64');
// Base85 only packs bytes more tightly than base64; raster pixels are unchanged.
const alphabet='0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!#$%()*+,-./:;=?@[]^_|~';
function packedBytes(buffer,mime){let data='';for(let i=0;i<buffer.length;i+=4){let value=0;for(let j=0;j<4;j++)value=value*256+(buffer[i+j]||0);let part='';for(let j=0;j<5;j++){part=alphabet[value%85]+part;value=Math.floor(value/85);}data+=part;}return {mime,bytes:buffer.length,data};}
const decoder="(()=>{const alphabet='"+alphabet+"',lookup={};for(let i=0;i<85;i++)lookup[alphabet[i]]=i;const result={sprites:{},backgrounds:{}};for(const group of ['sprites','backgrounds'])for(const [name,p] of Object.entries(window.STUDY_ASSETS_B85[group])){const bytes=new Uint8Array(Math.ceil(p.data.length/5)*4);let at=0;for(let i=0;i<p.data.length;i+=5){let value=0;for(let j=0;j<5;j++)value=value*85+lookup[p.data[i+j]];bytes[at++]=value>>>24;bytes[at++]=value>>>16;bytes[at++]=value>>>8;bytes[at++]=value;}const chunks=[];for(let i=0;i<p.bytes;i+=16384)chunks.push(String.fromCharCode.apply(null,bytes.subarray(i,Math.min(i+16384,p.bytes))));result[group][name]='data:'+p.mime+';base64,'+btoa(chunks.join(''));}window.STUDY_ASSETS=result;delete window.STUDY_ASSETS_B85;})();";
const escapeHTML=s=>String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/"/g,'&quot;');
function required(data,manifest){const sprites=new Set([data.hero.asset]),backgrounds=new Set();for(const r of data.regions){sprites.add(terrainSpec(data,manifest,r).asset);for(const item of r.instances||[])sprites.add(item.asset);for(const item of r.layers||[])sprites.add(item.asset);backgrounds.add(r.background);}return {sprites:[...sprites],backgrounds:[...backgrounds]};}
async function build(){
  const data=json('study.json'),manifest=withTerrain47(json('assets/pixel/manifest.json'),data,dir),scene=read('web/study.js'),used=required(data,manifest),terrainAssets=new Set(data.regions.map(r=>terrainSpec(data,manifest,r).asset)),encoded={sprites:{},backgrounds:{}};
  for(const group of ['sprites','backgrounds'])for(const name of used[group]){const file=path.join(dir,manifest[group][name].file),png=fs.readFileSync(file),webp=await sharp(file).webp({lossless:true,effort:6}).toBuffer();encoded[group][name]={png:dataURL(png,'image/png'),packedPNG:packedBytes(png,'image/png'),packedWebP:packedBytes(webp,'image/webp')};}
  function packed(regions,inline){
    const subset=Object.assign({},data,{regions}),needed=required(subset,manifest),meta={schema:manifest.schema,worldUnitsPerPixel:manifest.worldUnitsPerPixel,terrains:{},sprites:{},backgrounds:{}},assets={sprites:{},backgrounds:{}};
    for(const r of regions)meta.terrains[r.id]=manifest.terrains&&manifest.terrains[r.id]||manifest.terrain;
    if(manifest.terrain47){meta.terrain47={tileSize:manifest.terrain47.tileSize,bitOrder:manifest.terrain47.bitOrder,regions:{}};for(const r of regions)meta.terrain47.regions[r.id]=manifest.terrain47.regions[r.id];}
    for(const group of ['sprites','backgrounds'])for(const name of needed[group]){const f=manifest[group][name];meta[group][name]={};for(const key of ['file','w','h','pivotX','pivotY','surfaceY'])if(f[key]!==undefined)meta[group][name][key]=f[key];assets[group][name]=encoded[group][name][inline?(terrainAssets.has(name)?'packedPNG':'packedWebP'):'png'];}
    const options=regions.map(r=>'<option value="'+escapeHTML(r.id)+'">'+escapeHTML(r.name)+'</option>').join('\n');
    const bootstrap='<script>window.STUDY_DATA='+safeJSON(subset)+';window.STUDY_MANIFEST='+safeJSON(meta)+';window.'+(inline?'STUDY_ASSETS_B85':'STUDY_ASSETS')+'='+safeJSON(assets)+';</script>\n'+(inline?'<script>'+decoder+'</script>\n':'')+'<script>'+scene.replace(/<\/script/gi,'<\\/script')+'</script>';
    return read(inline?'web/inline-template.html':'web/template.html').replace('<!-- REGION_OPTIONS -->',()=>options).replace('<!-- STUDY_BOOTSTRAP -->',()=>bootstrap);
  }
  const args=process.argv.slice(2),at=args.indexOf('--inline'),outAt=args.indexOf('--out'),selectionAt=args.indexOf('--inline-regions');
  const full=packed(data.regions,false),preferred=selectionAt<0?(data.featuredRegions||['windchime_plains','thorn_forest']):args[selectionAt+1].split(',');
  const selected=preferred.map(id=>data.regions.find(r=>r.id===id)).filter(Boolean);
  const candidates=selectionAt<0?[...selected,...data.regions.filter(r=>!preferred.includes(r.id))]:selected;
  let inlineRegions=[],inline='';
  for(const region of candidates){const next=packed([...inlineRegions,region],true);if(Buffer.byteLength(next)<=1000000){inlineRegions.push(region);inline=next;}if(inlineRegions.length>=4)break;}
  if(!inlineRegions.length)throw new Error('No native region fits the 1 MB inline budget; use standalone.');
  if(selectionAt>=0&&inlineRegions.length!==selected.length)throw new Error('The explicitly requested inline regions exceed 1 MB; split them into separate previews without downsampling the artwork.');
  if(/<html|<body|<!doctype|fetch\(|XMLHttpRequest|WebSocket/i.test(inline))throw new Error('Inline contains an external request or document wrapper.');
  const out=outAt<0?path.join(dir,'world-art-preview.html'):path.resolve(args[outAt+1]),inlineOut=at<0?path.join(dir,'web/world-art-inline.html'):path.resolve(args[at+1]);
  fs.mkdirSync(path.dirname(out),{recursive:true});fs.mkdirSync(path.dirname(inlineOut),{recursive:true});fs.mkdirSync(path.join(dir,'previews'),{recursive:true});fs.writeFileSync(out,full);fs.writeFileSync(inlineOut,inline);
  const result={standalone:{file:out,bytes:Buffer.byteLength(full),regions:data.regions.map(r=>r.id)},inline:{file:inlineOut,bytes:Buffer.byteLength(inline),regions:inlineRegions.map(r=>r.id)},encoding:'Base85-packed native PNG terrain and lossless WebP sprites/backgrounds; decoded to ordinary image data URLs; no art downsampling'};
  fs.writeFileSync(path.join(dir,'previews/preview-build.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));return result;
}
if(require.main===module)build().catch(error=>{console.error(error);process.exitCode=1;});
module.exports={build};
