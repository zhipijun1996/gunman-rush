/** Mobile HTML/playback and mock bridge protocol checks. This never certifies Godot actions. */
import { createRequire } from 'node:module';
import fs from 'node:fs';
const require=createRequire(import.meta.url);
const { chromium }=require('playwright');
const url=process.argv[2]||'http://127.0.0.1:8769/';
const output=process.argv[3]||'build/audio_director_v2/web-protocol';
fs.mkdirSync(output,{recursive:true});
const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox','--autoplay-policy=no-user-gesture-required']});
const page=await browser.newPage({viewport:{width:390,height:844},deviceScaleFactor:2,isMobile:true,hasTouch:true});
const errors=[];page.on('pageerror',e=>errors.push(String(e)));
const mock=`<!doctype html><html><body style="background:#173024;color:#fff;font:16px sans-serif">MOCK PROTOCOL FIXTURE — not Godot<script>
let context='ui',profile='original',track='home',paused=false,audio_unlocked=false;window.commands=[];window.pauseDelay=100;
function emit(event,extra={}){parent.postMessage({type:'audio-lab-status',event,context,profile,track,paused,audio_unlocked,...extra},location.origin)}
addEventListener('message',e=>{if(e.origin!==location.origin||e.source!==parent||e.data?.type!=='audio-lab-command')return;const d=e.data;commands.push(d);setTimeout(()=>{if(d.command==='context'){context=d.value;emit('context')}else if(d.command==='profile'){profile=d.value;emit('profile')}else if(d.command==='music'){track=d.value;emit('music')}else if(d.command==='pause_audio'){paused=d.value;emit('audio_paused')}else if(d.command==='demo'){emit('demo_started');emit('accepted_event',{event_id:context==='pickup'?'coin':context==='combat'?'enemy_hit':'confirm',candidate_id:context==='pickup'?'coin_'+profile.toLowerCase():null});setTimeout(()=>emit('demo_finished'),350)}},d.command==='pause_audio'?window.pauseDelay:100)});setTimeout(()=>emit('ready'),80);
<\/script></body></html>`;
try{
 await page.route('**/game/**',route=>route.fulfill({status:200,contentType:'text/html',body:mock}));
 await page.goto(url);await page.waitForFunction(()=>window.AUDIO_LAB_V2?.ready);
 const dimensions=await page.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth,stage:document.getElementById('stage').getBoundingClientRect().top,events:data.events.length,profiles:data.profiles.length}));
 if(dimensions.scroll>dimensions.width||dimensions.stage>400||dimensions.events!==9||dimensions.profiles!==3)throw Error('Mobile layout/data failure '+JSON.stringify(dimensions));
 if(await page.locator('#game-frame').count())throw Error('Game loaded before user intent');
 await page.screenshot({path:output+'/mobile-html-shell.png'});
 await page.locator('[data-profile=A]').click();
 if(await page.locator('[data-profile=A]').getAttribute('aria-pressed')!=='false')throw Error('Unacknowledged profile displayed as applied');
 await page.locator('#load-scene').click();await page.waitForFunction(()=>window.AUDIO_LAB_V2.state.ready&&window.AUDIO_LAB_V2.state.profile==='A'&&!window.AUDIO_LAB_V2.state.inflight);
 if(!(await page.locator('#scene-note').innerText()).includes('请点一下场景内「开启声音」'))throw Error('Missing real-gesture audio unlock instruction');
 if(await page.evaluate(()=>window.AUDIO_LAB_V2.state.audioUnlocked))throw Error('Track/profile ACK incorrectly implied audio unlock');
 await page.frameLocator('#game-frame').locator('body').evaluate(()=>{audio_unlocked=true;emit('audio_unlocked')});
 await page.waitForFunction(()=>window.AUDIO_LAB_V2.state.audioUnlocked===true);
 if(!(await page.locator('#scene-note').innerText()).includes('浏览器声音已开启'))throw Error('Audio unlock ACK not reflected');
 const rejectedBefore=await page.evaluate(()=>window.AUDIO_LAB_V2.bridgeRejected);
 await page.evaluate(()=>{window.postMessage({type:'audio-lab-status',event:'profile',profile:'C'},location.origin);dispatchEvent(new MessageEvent('message',{origin:'https://wrong-origin.example',source:document.querySelector('iframe').contentWindow,data:{type:'audio-lab-status',event:'profile',profile:'C'}}))});
 await page.waitForTimeout(100);
 const spoof=await page.evaluate(()=>({rejected:window.AUDIO_LAB_V2.bridgeRejected,profile:window.AUDIO_LAB_V2.state.profile}));
 if(spoof.rejected<rejectedBefore+2||spoof.profile!=='A')throw Error('Wrong source/origin message accepted');
 await page.locator('[data-context=pickup]').click();
 const pending=await page.evaluate(()=>window.AUDIO_LAB_V2.state);
 if(pending.context!=='ui'||pending.desiredContext!=='pickup')throw Error('Context assumed before ACK');
 await page.locator('[data-profile=C]').click();await page.waitForFunction(()=>window.AUDIO_LAB_V2.state.context==='pickup'&&window.AUDIO_LAB_V2.state.profile==='C'&&!window.AUDIO_LAB_V2.state.inflight);
 let commands=await page.frameLocator('#game-frame').locator('body').evaluate(()=>window.commands);
 if(commands.some(d=>d.command==='demo'))throw Error('Context/profile selection unexpectedly ran demo');
 await page.locator('#demo').click();await page.waitForFunction(()=>window.AUDIO_LAB_V2.acceptedEvents.some(e=>e.event_id==='coin'));await page.waitForFunction(()=>!window.AUDIO_LAB_V2.state.demoRunning);
 commands=await page.frameLocator('#game-frame').locator('body').evaluate(()=>window.commands);if(!commands.some(d=>d.command==='demo'&&d.value===''))throw Error('Whole-context demo must use empty action value');
 await page.locator('#single-room summary').first().click();
 // A delayed engine mute ACK must not resurrect music after Stop or backgrounding.
 await page.selectOption('#single-bgm',{index:1});
 await page.frameLocator('#game-frame').locator('body').evaluate(()=>window.pauseDelay=500);
 await page.locator('#single-music').click();await page.waitForTimeout(50);await page.locator('#stop').click();await page.waitForTimeout(650);
 if(!(await page.evaluate(()=>bgm.paused&&!musicPending)))throw Error('Music started after Stop during delayed mute ACK');
 await page.locator('#resume-scene').click();await page.waitForFunction(()=>window.AUDIO_LAB_V2.state.paused===false&&!window.AUDIO_LAB_V2.state.inflight);
 await page.locator('#single-music').click();await page.waitForTimeout(50);
 await page.evaluate(()=>{Object.defineProperty(document,'hidden',{configurable:true,get:()=>true});document.dispatchEvent(new Event('visibilitychange'))});await page.waitForTimeout(650);
 if(!(await page.evaluate(()=>bgm.paused&&!musicPending)))throw Error('Music started after backgrounding during delayed mute ACK');
 await page.evaluate(()=>{delete document.hidden});
 await page.frameLocator('#game-frame').locator('body').evaluate(()=>window.pauseDelay=100);
 await page.locator('[data-candidate=coin_a]').click();await page.waitForFunction(()=>window.AUDIO_LAB_V2.playCount>0);
 if(!(await page.evaluate(()=>window.AUDIO_LAB_V2.state.paused)))throw Error('Single audio played without acknowledged game mute');
 const decoded=await page.evaluate(async()=>{await unlock();const rows=[];for(const e of data.events){for(const c of [e.original,...e.candidates].filter(Boolean)){for(const p of c.variants?.length?c.variants:[c.path]){if(!p)continue;const b=await buffer(p);let peak=0;for(const x of b.getChannelData(0))peak=Math.max(peak,Math.abs(x));if(!peak||!Number.isFinite(peak))throw Error('Silent or corrupt '+p);rows.push({path:p,duration:b.duration,peak})}}}return rows});
 if(decoded.length!==63)throw Error('Expected 54 new variants plus nine originals; got '+decoded.length);
 await page.locator('[data-loop=coin_a]').click();await page.waitForTimeout(1750);await page.locator('#stop').click();const stopped=await page.evaluate(()=>window.AUDIO_LAB_V2.playCount);await page.waitForTimeout(1750);if(await page.evaluate(()=>window.AUDIO_LAB_V2.playCount)!==stopped)throw Error('Loop continued after stop');
 await page.evaluate(()=>{window.originalBuffer=buffer;buffer=async(path)=>{await new Promise(resolve=>setTimeout(resolve,500));return window.originalBuffer(path)}});
 const beforeRace=await page.evaluate(()=>window.AUDIO_LAB_V2.playCount);await page.locator('[data-candidate=coin_b]').click();await page.locator('#stop').click();await page.waitForTimeout(650);if(await page.evaluate(()=>window.AUDIO_LAB_V2.playCount)!==beforeRace)throw Error('Late buffer decode played after cancellation');await page.evaluate(()=>{buffer=window.originalBuffer;delete window.originalBuffer});
 await page.locator('article[data-event=coin] .clip').nth(1).locator('.row button').nth(2).click();
 await page.locator('article[data-event=coin] textarea').fill('TEST ONLY: raw coin comparison');await page.locator('#choose-context').click();
 const downloadTask=page.waitForEvent('download');await page.locator('#export').click();const download=await downloadTask;await download.saveAs(output+'/selections.json');
 const selection=JSON.parse(fs.readFileSync(output+'/selections.json'));if(selection.choices.coin.candidate_id!=='coin_a'||selection.context_choices.pickup.profile!=='C'||selection.choices.coin.context!=='pickup')throw Error('Selection export lost profile/context');
 await page.reload();await page.waitForFunction(()=>window.AUDIO_LAB_V2?.ready);await page.locator('[data-context=pickup]').click();await page.locator('#single-room summary').first().click();if(await page.locator('article[data-event=coin] textarea').inputValue()!=='TEST ONLY: raw coin comparison')throw Error('Versioned choice storage failed');
 const music=[];for(let i=1;i<=5;i++){await page.selectOption('#single-bgm',{index:i});await page.locator('#single-music').click();await page.waitForFunction(()=>!bgm.paused&&bgm.currentTime>0);music.push(await page.evaluate(()=>({src:bgm.currentSrc,time:bgm.currentTime})));await page.locator('#stop').click()}
 await page.evaluate(()=>{localStorage.removeItem('audio-director-v2:'+data.version);choices={};contextChoices={};renderEvents();renderBridge()});
 await page.setViewportSize({width:1280,height:800});await page.screenshot({path:output+'/desktop-html-shell.png'});
 if(errors.length)throw Error(errors.join('\n'));
 const report={status:'passed',url,dimensions,decoded:decoded.length,music:music.length,checks:['mobile layout and stage visible early','explicit lazy game load','real-gesture audio unlock hint and separate unlock ACK','origin and source validation','context/profile applied only after mock ACK','no automatic demo on profile/context change','mute ACK before single playback','loop stop and late decode cancellation','Stop/background cancels pending music across delayed mute ACK','versioned context/event selection export and persistence','five BGM tracks decoded and played'],scope:'Actual HTML/audio playback with MOCK bridge protocol. This does not execute or validate Godot gameplay, scene actions, audible aesthetics, physical phones or Safari.',errors};
 fs.writeFileSync(output+'/report.json',JSON.stringify(report,null,2));console.log('AUDIO_LAB_V2_WEB_PROTOCOL_OK decoded='+decoded.length+' music='+music.length);
}catch(error){fs.writeFileSync(output+'/failure.json',JSON.stringify({error:String(error),errors},null,2));throw error}finally{await browser.close()}
