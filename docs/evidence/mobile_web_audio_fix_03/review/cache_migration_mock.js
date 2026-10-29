/* Independent reviewer mock. Evaluates real cache templates, no browser/Godot. */
const fs = require('fs'), vm = require('vm'), assert = require('assert');
const {webcrypto} = require('crypto');
const startupSource = fs.readFileSync('tools/web/cache_startup.js', 'utf8');
const workerSource = fs.readFileSync('tools/web/cache_worker.js', 'utf8');
const tests = [];
const BUILD = '123456789abc', WORKER = 'new-worker-id';
const flush = async () => { for (let i=0;i<20;i++) await Promise.resolve(); };
function setupStartup(options={}) {
  let now=0, nextID=0, reloads=0, registrations=0, queries=0, ready='pending';
  const timers=new Map(), storage=options.storage||new Map(), listeners=new Map();
  const schedule=(fn,delay)=>{const id=++nextID;timers.set(id,{at:now+delay,fn});return id};
  const respond = options.response || {id:WORKER,packs:['index.'+BUILD+'.pck']};
  const controller = data => ({postMessage(message,ports){queries++;
    if(options.noReply)return;
    schedule(()=>ports[0].deliver(data),options.replyDelay||0);
  }});
  const sw={controller:options.oldController?controller({id:'old-worker-id',packs:['index.000000000000.pck']}):
    options.cold?null:controller(respond),
    register(url,config){registrations++;assert.equal(url,'index.cache-sw.js');assert.equal(config.updateViaCache,'none');
      if(options.registerReject)return Promise.reject(Error('registration denied'));
      if(options.registerNever)return new Promise(()=>{});
      return new Promise(resolve=>schedule(()=>resolve({}),options.registerDelay||0));},
    addEventListener(){}};
  if(options.controlAt!==undefined)schedule(()=>sw.controller=controller(respond),options.controlAt);
  const sandbox={console,Promise,URL,Map,Date:{now:()=>now},
    navigator:options.noSW?{}:{serviceWorker:sw},
    isSecureContext:options.insecure?false:true,crossOriginIsolated:!!options.coi,
    MessageChannel:class {constructor(){let closed=false;
      this.port1={onmessage:null,close(){closed=true}};
      this.port2={deliver:data=>{if(!closed)this.port1.onmessage?.({data})}};}},
    sessionStorage:{getItem:key=>{if(options.storageBlocked)throw Error('storage denied');return storage.get(key)||null},
      setItem:(key,value)=>{if(options.storageBlocked)throw Error('storage denied');storage.set(key,value)}},
    location:{href:'https://example.test/game/',reload:()=>reloads++,replace:()=>{}},
    document:{visibilityState:'visible',body:{appendChild(){}},getElementById:()=>null,
      createElement:()=>({style:{},append(){}}),addEventListener(){}},
    fetch:async()=>({ok:true,json:async()=>({build_id:BUILD})}),
    setTimeout:schedule,clearTimeout:id=>timers.delete(id),setInterval:schedule,
    addEventListener:(name,fn)=>listeners.set(name,fn)};
  sandbox.window=sandbox;vm.createContext(sandbox);
  const code=startupSource.replaceAll('__BUILD_ID__',JSON.stringify(BUILD))
    .replaceAll('__WORKER_ID__',JSON.stringify(WORKER)).replaceAll('__THREADS_ENABLED__',String(options.threaded!==false));
  vm.runInContext(code,sandbox);sandbox.PLAYTEST_CACHE_READY.then(value=>ready=value);
  async function advance(target){await flush();
    while(true){const due=[...timers].filter(([,row])=>row.at<=target).sort((a,b)=>a[1].at-b[1].at||a[0]-b[0]);
      if(!due.length)break;const[id,row]=due[0];timers.delete(id);now=row.at;row.fn();await flush();}
    now=target;await flush();
  }
  return {sandbox,advance,storage,get ready(){return ready},get reloads(){return reloads},
    get registrations(){return registrations},get queries(){return queries}};
}
async function startupTests(){
  const cold=setupStartup({cold:true,controlAt:300});await cold.advance(299);assert.equal(cold.reloads,0);
  await cold.advance(500);assert.equal(cold.reloads,1);assert.equal(cold.storage.get('playtest-isolation-'+WORKER),'reloaded');
  await cold.advance(20000);assert.equal(cold.reloads,1);tests.push('cold_control_then_exact_handshake_one_reload');
  const resumed=setupStartup({coi:true,storage:cold.storage});await resumed.advance(1);
  assert.equal(resumed.ready,true);assert.equal(resumed.reloads,0);tests.push('after_reload_actual_coi_ready_without_second_reload');
  const persistent=setupStartup({storage:cold.storage});await persistent.advance(1);
  assert.equal(persistent.ready,false);assert.equal(persistent.reloads,0);tests.push('persistent_noncoi_fails_without_reload_loop');
  const old=setupStartup({oldController:true,controlAt:600});await old.advance(599);assert.equal(old.reloads,0);
  await old.advance(900);assert.equal(old.reloads,1);tests.push('old_worker_never_authorizes_reload_new_exact_worker_does');
  const wrongPack=setupStartup({response:{id:WORKER,packs:['index.000000000000.pck']}});await wrongPack.advance(5000);
  assert.equal(wrongPack.reloads,0);assert.equal(wrongPack.ready,false);tests.push('right_worker_wrong_pack_cannot_authorize');
  for(const options of [{noSW:true},{insecure:true},{registerReject:true},{registerNever:true},{storageBlocked:true},{noReply:true}]){
    const run=setupStartup(options);await run.advance(5000);assert.equal(run.ready,false);assert.equal(run.reloads,0);}
  tests.push('unsupported_insecure_denied_hung_storageblocked_noreply_bounded_failure');
  const prior=setupStartup({threaded:false});await prior.advance(1);assert.equal(prior.ready,true);assert.equal(prior.reloads,0);
  const isolated=setupStartup({coi:true,storageBlocked:true});await isolated.advance(1);assert.equal(isolated.ready,true);
  tests.push('singlethread_compatibility_and_alreadycoi_without_storage');
  const late=setupStartup({cold:true,registerDelay:5000,controlAt:5000});await late.advance(4001);
  assert.equal(late.ready,false);assert.equal(late.reloads,0);await late.advance(5500);assert.equal(late.reloads,1);
  await late.advance(20000);assert.equal(late.reloads,1);
  tests.push('documented_outer_timeout_does_not_cancel_late_inner_one_reload');
}
function setupWorker(){
  const listeners={},network=[],writes=[],cacheRows=new Map();let networkWait=null;
  const resources={['index.'+BUILD+'.pck']:{bytes:4},'index.abcdef123456.engine.js':{bytes:4}};
  const cache={async match(request){return cacheRows.get(typeof request==='string'?request:request.url)?.clone()},
    async keys(){return[...cacheRows.keys()].map(url=>({url}))},async put(request,response){
      const url=typeof request==='string'?request:request.url;writes.push(url);cacheRows.set(url,response.clone());},
    async delete(request){return cacheRows.delete(typeof request==='string'?request:request.url)}};
  const sandbox={console,URL,Map,Headers,Response,Blob,Uint8Array,Promise,crypto:webcrypto,
    caches:{open:async()=>cache},setTimeout,clearTimeout,AbortController,
    fetch:async request=>{network.push(request);if(networkWait)await networkWait;
      return new Response('body:'+request.url,{status:200,headers:{'Content-Type':request.url.endsWith('.js')?'text/javascript':'text/plain','X-Keep':'yes'}});},
    self:{location:{origin:'https://example.test'},registration:{scope:'https://example.test/game/'},
      skipWaiting:async()=>{},clients:{claim:async()=>{},get:async()=>null},
      addEventListener:(name,fn)=>listeners[name]=fn}};
  vm.createContext(sandbox);vm.runInContext(workerSource.replace('__RESOURCE_MAP__',JSON.stringify(resources))
    .replaceAll('__WORKER_ID__',JSON.stringify(WORKER)),sandbox);
  function request(path,method='GET'){
    const request={url:new URL(path,'https://example.test/game/').href,method};let response;
    listeners.fetch({request,clientId:'client',respondWith:value=>response=value});return {request,response};
  }
  return {sandbox,cacheRows,network,writes,request,
    hold:()=>{let release;networkWait=new Promise(resolve=>release=resolve);return()=>{networkWait=null;release()}}};
}
function assertIsolation(response){assert.equal(response.headers.get('Cross-Origin-Opener-Policy'),'same-origin');
  assert.equal(response.headers.get('Cross-Origin-Embedder-Policy'),'require-corp');}
async function workerTests(){
  const w=setupWorker();for(const path of ['index.html','build-info.json?check=1','index.cache-sw.js','workers/pthread.js']){
    const req=w.request(path);const response=await req.response;assertIsolation(response);
    assert.equal(response.headers.get('X-Keep'),'yes');assert.equal(await response.text(),'body:'+req.request.url);}
  assert.equal(w.writes.length,0);tests.push('mutable_html_metadata_worker_passthrough_body_and_isolation_not_cached');
  const legacyURL='https://example.test/game/index.000000000000.engine.js';
  w.cacheRows.set(legacyURL,new Response('old-official-js',{headers:{'Content-Type':'text/javascript'}}));
  const count=w.network.length;const old=await w.request(legacyURL).response;
  assertIsolation(old);assert.equal(await old.text(),'old-official-js');assert.equal(w.network.length,count);
  tests.push('old_immutable_cached_engine_bytes_retained_headers_upgraded');
  const release=w.hold();const first=w.request('index.abcdef123456.engine.js'),second=w.request('index.abcdef123456.engine.js');
  await flush();const calls=w.network.filter(x=>x.url.endsWith('index.abcdef123456.engine.js')).length;assert.equal(calls,1);
  release();const one=await first.response,two=await second.response;assert.notEqual(one,two);
  assertIsolation(one);assertIsolation(two);assert.equal(await one.text(),await two.text());
  tests.push('cold_tabs_share_one_immutable_fetch_independent_isolated_responses');
  assert.equal(w.request('save-data','POST').response,undefined);
  assert.equal(w.request('https://other.test/game/index.html').response,undefined);
  assert.equal(w.request('https://example.test/other/index.html').response,undefined);
  tests.push('nonget_crossorigin_outscope_not_intercepted');
  const statusZero={status:0,opaque:true};w.sandbox.sample=statusZero;
  assert.equal(vm.runInContext('isolatedResponse(sample)',w.sandbox),statusZero);
  tests.push('opaque_statuszero_response_identity_preserved');
}
(async()=>{await startupTests();await workerTests();console.log(JSON.stringify({passed:tests.length,failed:0,tests},null,2));})()
 .catch(error=>{console.error(error);process.exitCode=1});
