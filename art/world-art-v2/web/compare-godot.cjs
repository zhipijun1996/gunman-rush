#!/usr/bin/env node
'use strict';
// Input/coordinate parity only. This never claims that two renderers look equal.
const fs=require('fs'),path=require('path'),assert=require('assert'),crypto=require('crypto');
const root=path.resolve(__dirname,'..'),read=p=>JSON.parse(fs.readFileSync(path.join(root,p),'utf8'));
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(path.join(root,p))).digest('hex');
function compare(){
  const snapshot=read('previews/scene-snapshot.json'),build=read('godot/build-info.json'),terrain=read('godot/terrain-placements.json'),depth=read('godot/depth-placements.json'),lighting=read('godot/lighting-placements.json'),particles=read('godot/particle-samples.json'),native=read('godot/lighting-checks.json');
  assert.equal(build.data_sha256,hash('study.json'),'Godot scene was built from a different scene input');
  assert.equal(build.manifest_sha256,hash('assets/pixel/manifest.json'),'Godot scene was built from a different native sprite manifest');
  assert(native.passed,'Godot behavior checks did not pass');
  let tiles=0,layers=0,particleCount=0,occluders=0;
  for(const r of snapshot.regions){
    const expected=terrain.filter(t=>t.region===r.id).map(({region,...t})=>t);
    assert.deepEqual(r.terrainDraws,expected,r.id+' terrain placements differ');tiles+=expected.length;
    for(const layer of r.layers){
      const candidate=depth.find(d=>d.region===r.id&&d.id===layer.id);assert(candidate,r.id+':'+layer.id+' missing Godot depth sprite');
      assert.equal(layer.drawBounds.x,candidate.x);assert.equal(layer.drawBounds.y,candidate.y);assert.equal(layer.parallax,candidate.parallax);
      assert.deepEqual(layer.mask||null,candidate.mask||null);layers++;
    }
    const godotOccluders=lighting.occluders.filter(o=>o.region===r.id).map(o=>o.points);
    assert.deepEqual(r.occluders,godotOccluders,r.id+' occlusion polygons differ');occluders+=godotOccluders.length;
    const nativeParticles=particles[r.id]['1.2'];assert.equal(r.particles.length,nativeParticles.length);
    for(let i=0;i<r.particles.length;i++){
      const a=r.particles[i],b=nativeParticles[i];for(const key of ['id','x','y','depth','speed','vertical'])assert.equal(a[key],b[key],r.id+' particle '+i+' '+key);
      assert(Math.abs(a.alpha-b.alpha)<1e-5,r.id+' particle alpha '+i);particleCount++;
    }
  }
  const result={passed:true,region_count:snapshot.regions.length,data_sha256:hash('study.json'),manifest_sha256:hash('assets/pixel/manifest.json'),canvas_snapshot_sha256:hash('previews/scene-snapshot.json'),terrain_placements_compared:tiles,independent_depth_instances_compared:layers,occluder_polygons_compared:occluders,particle_states_compared_at_1_2s:particleCount,limits:['Input and coordinate parity, not GPU frame equivalence','Godot uses native PointLight2D; Canvas uses a floating-point 2D light field','Independent near masks use world coordinates; dynamic hero movement is Godot-only','No formal-game integration or gameplay regression']};
  fs.writeFileSync(path.join(root,'godot/canvas-data-comparison.json'),JSON.stringify(result,null,2)+'\n');
  const importLog=fs.readFileSync(path.join(root,'godot/runtime-import-v2.log'),'utf8');
  const errors=importLog.split(/\n/).filter(line=>/SCRIPT ERROR|ERROR:|Parse Error/.test(line));assert.equal(errors.length,0,'Godot import contains errors');
  const report={engine:native.engine,data_sha256:result.data_sha256,manifest_sha256:result.manifest_sha256,scene_sha256:hash('godot/study.tscn'),region_count:result.region_count,independent_depth_layers:layers,terrain47_layers:build.terrain47_layers,import:{log:'runtime-import-v2.log',no_reported_errors:true,errors},runtime:{script:'verify_lighting.gd',checks:native.checks.length,passed:native.passed},parity:result,scope:['Headless resource/node/behavior checks','Native 32px occupied-grid geometry and tile selection','World-space mask resources, hero protection parameters, ±32px snapped camera','Actual assembly frames and video are Canvas/Skia'],limitations:['Godot Dummy driver does not validate rendered lighting or shader appearance','Chromium launch attempted: socket() failed: Operation not permitted','47 tile adjacency resource matrix is validated separately in terrain47/','No full gameplay regression']};
  fs.writeFileSync(path.join(root,'godot/validation-report.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({passed:result.passed,regions:result.region_count,tiles,layers,occluders,particles:particleCount,nativeChecks:native.checks.length}));return result;
}
if(require.main===module)compare();module.exports={compare};
