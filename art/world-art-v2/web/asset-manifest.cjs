'use strict';
// Keep generated 47-neighbour atlases separate from the source sprite manifest.
const fs=require('fs'),path=require('path');
function hasGrid(data,region){return !!(region.terrainGrid||data.terrainGrid);}
function withTerrain47(manifest,data,root){
  if(manifest.terrain47||!data.regions.some(r=>hasGrid(data,r)))return manifest;
  const file=path.join(root,'assets/terrain47/manifest.json');
  if(!fs.existsSync(file))throw new Error('terrainGrid requires assets/terrain47/manifest.json');
  const atlas=JSON.parse(fs.readFileSync(file,'utf8'));
  const result=JSON.parse(JSON.stringify(manifest));result.terrain47=atlas;
  for(const region of data.regions){
    if(!hasGrid(data,region))continue;
    const spec=atlas.regions[region.id];if(!spec)throw new Error('Missing 47 atlas for '+region.id);
    const asset='terrain47_'+region.id;spec.asset=asset;
    const tile=spec.tile||atlas.tileSize||32,columns=spec.columns||8;
    result.sprites[asset]={file:spec.atlas,w:columns*tile,h:Math.ceil(47/columns)*tile,pivotX:0,pivotY:0,surfaceY:spec.surfaceY||0};
  }
  return result;
}
function terrainSpec(data,manifest,region){
  if(hasGrid(data,region)){
    const spec=manifest.terrain47&&manifest.terrain47.regions[region.id];
    if(!spec)throw new Error('Missing 47 adjacency metadata for '+region.id);
    return spec;
  }
  return manifest.terrains&&manifest.terrains[region.id]||manifest.terrain;
}
module.exports={withTerrain47,terrainSpec,hasGrid};
