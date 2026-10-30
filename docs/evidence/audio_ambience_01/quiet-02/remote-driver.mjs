import {createRequire} from 'node:module';
import readline from 'node:readline';
import fs from 'node:fs';
import crypto from 'node:crypto';
const require=createRequire(import.meta.url),{chromium}=require('playwright');
console.log('Ready for private-site QA credential on hidden stdin.');
const rl=readline.createInterface({input:process.stdin,terminal:false});
const line=await new Promise(resolve=>rl.once('line',resolve));rl.close();process.stdin.pause();
const credential=JSON.parse(line),expected=JSON.parse(fs.readFileSync('build/audio_ambience_01/capture-06/report.json')),url='https://clock-ambience-lab.zhipijun1996.chatgpt.site/';
const folder='build/audio_ambience_01/quiet-02/remote-browser-01';if(fs.existsSync(folder))throw Error('Use fresh remote QA output');fs.mkdirSync(folder,{recursive:true});
const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox']});let context;
try{
 context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:1,extraHTTPHeaders:{'OAI-Sites-Authorization':'Bearer '+credential.token}});
 const page=await context.newPage(),errors=[];page.on('pageerror',e=>errors.push(String(e)));
 await page.goto(url,{waitUntil:'domcontentloaded',timeout:60000});await page.waitForFunction(()=>globalThis.AMBIENCE_STATS?.ready,null,{timeout:30000});
 const remote=await page.evaluate(async()=>{const r=await fetch('ambience.mp4');const b=await r.arrayBuffer();return{status:r.status,bytes:b.byteLength,sha:Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',b))).map(v=>v.toString(16).padStart(2,'0')).join('')}});if(remote.status!==200||remote.sha!==expected.movie_sha256)throw Error('Remote media byte mismatch');const sha=remote.sha,bytes={length:remote.bytes};
 const delivery=await page.evaluate(async()=>await(await fetch('delivery.json')).json());if(delivery.producer_commit!==expected.commit)throw Error('Remote producer mismatch');
 const mix=await page.evaluate(async()=>({candidate:await(await fetch('candidates.json')).json(),report:await(await fetch('report.json')).json(),key:KEY,context:document.getElementById('context').value,notice:document.body.innerText.includes('轻微环境版')}));if(mix.candidate.mix_revision!=='quiet-02'||mix.report.mix_revision!=='quiet-02'||mix.key!=='clock-audio-ambience-v1-quiet-02-choices'||mix.context!=='mix'||!mix.notice)throw Error('Wrong actual quiet mix metadata/default');await page.locator('[data-chapter]').nth(1).click();await page.waitForFunction(()=>!video.paused&&video.currentTime>1&&video.webkitAudioDecodedByteCount>0&&video.webkitDecodedFrameCount>0,null,{timeout:60000});await page.waitForTimeout(350);
 const first=await page.evaluate(()=>({state:AMBIENCE_STATS.state,width:video.videoWidth,height:video.videoHeight,audioBytes:video.webkitAudioDecodedByteCount,videoFrames:video.webkitDecodedFrameCount,muted:video.muted}));if(first.width!==960||first.height!==540||!first.state.active?.includes('plains_A'))throw Error('Remote plainsA actual playback mismatch');
 await page.locator('#context').selectOption('environment');await page.locator('[data-chapter]').nth(5).click();await page.waitForFunction(()=>!video.paused&&AMBIENCE_STATS.state.active==='forest_B_environment');await page.waitForTimeout(400);
 const second=await page.evaluate(()=>({...AMBIENCE_STATS.state,audioBytes:video.webkitAudioDecodedByteCount,videoFrames:video.webkitDecodedFrameCount,muted:video.muted}));await page.locator('#stop').click();await page.waitForFunction(()=>video.paused);
 const stopped=await page.evaluate(()=>AMBIENCE_STATS.state);await page.screenshot({path:folder+'/mobile.png',fullPage:true});
 if(errors.length||await page.evaluate(()=>AMBIENCE_STATS.errors.length))throw Error('Remote browser errors');
 const report={status:'passed',url,media_status:200,media_bytes:bytes.length,media_sha256:sha,producer:delivery.producer_commit,mix_revision:mix.report.mix_revision,selection_key:mix.key,real_pointer_checks:[first,second],stopped,errors,scope:'Owner-private remote390px Chromium; two real pointer chapters/actualAACdecode, Stop and full remoteMP4 bytes. Not physical phone/Safari or subjective listening.'};fs.writeFileSync(folder+'/report.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({status:report.status,media_sha256:sha,checks:2}));
}catch(error){fs.writeFileSync(folder+'/failure.json',JSON.stringify({status:'failed',error:String(error).split('Call log:')[0].replace(/Bearer\s+[^\s]+/g,'Bearer [redacted]')},null,2)+'\n');throw new Error(String(error).split('Call log:')[0].replace(/Bearer\s+[^\s]+/g,'Bearer [redacted]'))}finally{await browser.close()}
