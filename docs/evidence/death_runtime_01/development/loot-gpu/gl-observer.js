(() => {
 if(globalThis.COLD_GL) return 'already-installed';
 const origin=performance.timeOrigin, now=()=>origin+performance.now();
 const data={installed_epoch_ms:now(),realm:typeof window==='undefined'?'worker':'window',stage:'startup',prototypes:[],contexts:[],events:[],sources:{},aggregate:{},overflow:false,limits:{events:6000,slow_ms:2}};
 const ctxs=new WeakMap(),shaders=new WeakMap(),programs=new WeakMap(),activePrograms=new WeakMap();let cid=0,sid=0,pid=0;
 const context=c=>{if(!ctxs.has(c)){const row={id:++cid,first_observed_epoch_ms:now(),constructor:c.constructor.name};ctxs.set(c,row);data.contexts.push(row);}return ctxs.get(c).id;};
 const shader=s=>{if(!s)return null;if(!shaders.has(s))shaders.set(s,{id:++sid,tags:[],length:0});return shaders.get(s);};
 const program=p=>{if(!p)return null;if(!programs.has(p))programs.set(p,{id:++pid,shaders:[]});return programs.get(p);};
 function record(row){if(data.events.length<data.limits.events)data.events.push(row);else data.overflow=true;}
 const timed=['shaderSource','compileShader','attachShader','linkProgram','getProgramParameter','texImage2D','texSubImage2D','readPixels'];
 const counted=['drawArrays','drawElements','drawArraysInstanced','drawElementsInstanced','bufferData','bufferSubData','useProgram'];
 for(const type of ['WebGLRenderingContext','WebGL2RenderingContext']){
  const proto=globalThis[type]?.prototype;if(!proto){data.prototypes.push({type,available:false});continue;}
  let wrapped=[];
  for(const name of [...timed,...counted]){
   if(!Object.prototype.hasOwnProperty.call(proto,name)||typeof proto[name]!=='function')continue;
   const orig=proto[name];
   proto[name]=function(...args){
    const context_id=context(this),key=data.stage+'|'+context_id+'|'+name;
    const stat=data.aggregate[key]||(data.aggregate[key]={calls:0,total_cpu_ms:0,max_cpu_ms:0});stat.calls++;
    if(name==='shaderSource') {const s=shader(args[0]),text=String(args[1]);s.length=text.length;data.sources[s.id]=text;s.tags=['edge_width','plant_body','kind_code'].filter(x=>text.includes(x));s.sample=s.tags.length?text.slice(Math.max(0,text.indexOf(s.tags[0])-60),text.indexOf(s.tags[0])+140):null;}
    if(name==='attachShader'){const p=program(args[0]),s=shader(args[1]);if(p&&s&&!p.shaders.includes(s))p.shaders.push(s);}
    if(counted.includes(name)){
     if(name==='useProgram'){const p=program(args[0]);activePrograms.set(this,p);stat.programs=stat.programs||{};const k=p?JSON.stringify({id:p.id,tags:[...new Set(p.shaders.flatMap(s=>s.tags))]}):'null';stat.programs[k]=(stat.programs[k]||0)+1;}
     if(name.startsWith('draw')){const p=activePrograms.get(this);stat.draw_programs=stat.draw_programs||{};const key=p?String(p.id):'null';stat.draw_programs[key]=(stat.draw_programs[key]||0)+1;}
     return Reflect.apply(orig,this,args);
    }
    const begin=now();try{return Reflect.apply(orig,this,args);}finally{
     const dt=now()-begin;stat.total_cpu_ms+=dt;stat.max_cpu_ms=Math.max(stat.max_cpu_ms,dt);
     if(dt>=data.limits.slow_ms||['shaderSource','compileShader','attachShader','linkProgram'].includes(name)){
      const p=['attachShader','linkProgram','getProgramParameter'].includes(name)?program(args[0]):null;
      const s=['shaderSource','compileShader'].includes(name)?shader(args[0]):null;
      record({stage:data.stage,name,context_id,epoch_ms:begin,duration_ms:dt,pname:name==='getProgramParameter'?args[1]:null,shader:s?{...s}:null,program:p?{id:p.id,shaders:p.shaders.map(s=>({...s}))}:null});
     }
    }
   };wrapped.push(name);
  }data.prototypes.push({type,available:true,wrapped});
 }
 globalThis.COLD_GL={data,setStage(s){data.stage=s;return {epoch_ms:now(),stage:s};},snapshot(){return data;}};
 return {realm:data.realm,installed_epoch_ms:data.installed_epoch_ms,prototypes:data.prototypes};
})()
