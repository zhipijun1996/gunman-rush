import {createRequire} from 'node:module';
import readline from 'node:readline';
import fs from 'node:fs';
import crypto from 'node:crypto';
const require=createRequire(import.meta.url),{chromium}=require('playwright');
console.log('Ready for private-site QA credential on hidden stdin.');
const rl=readline.createInterface({input:process.stdin,terminal:false});
const line=await new Promise(resolve=>rl.once('line',resolve));rl.close();process.stdin.pause();
const credential=JSON.parse(line),url='https://clock-ambience-lab.zhipijun1996.chatgpt.site/';
const folder='build/audio_ambience_01/remote-browser-03';if(fs.existsSync(folder))throw Error('Use fresh remote QA output');fs.mkdirSync(folder,{recursive:true});
const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox']});let context;
try{
 context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:1,extraHTTPHeaders:{'OAI-Sites-Authorization':'Bearer '+credential.token}});
 const page=await context.newPage(),errors=[];page.on('pageerror',e=>errors.push(String(e)));
 await page.goto(url,{waitUntil:'domcontentloaded',timeout:60000});await page.waitForFunction(()=>globalThis.AMBIENCE_STATS?.ready,null,{timeout:30000});
 const remote=await page.evaluate(async()=>{const r=await fetch('ambience.mp4');const b=await r.arrayBuffer();return{status:r.status,bytes:b.byteLength,sha:Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',b))).map(v=>v.toString(16).padStart(2,'0')).join('')}});if(remote.status!==200||remote.sha!=='69da1d4d924d79010be30468ba3f23a0831c469212f45cc38929a3b09de5fc8e')throw Error('Remote media byte mismatch');const sha=remote.sha,bytes={length:remote.bytes};
 const delivery=await page.evaluate(async()=>await(await fetch('delivery.json')).json());if(delivery.producer_commit!=='de6b36c62f0640d9322973fffb687472755d25b7')throw Error('Remote producer mismatch');
 await page.locator('[data-chapter]').nth(1).click();await page.waitForFunction(()=>!video.paused&&video.currentTime>1,null,{timeout:60000});await page.waitForTimeout(350);
 const first=await page.evaluate(()=>({state:AMBIENCE_STATS.state,width:video.videoWidth,height:video.videoHeight}));if(first.width!==960||first.height!==540||!first.state.active?.includes('plains_A'))throw Error('Remote plainsA actual playback mismatch');
 await page.locator('#context').selectOption('environment');await page.locator('[data-chapter]').nth(5).click();await page.waitForFunction(()=>!video.paused&&AMBIENCE_STATS.state.active==='forest_B_environment');await page.waitForTimeout(400);
 const second=await page.evaluate(()=>AMBIENCE_STATS.state);await page.locator('#stop').click();await page.waitForFunction(()=>video.paused);
 const stopped=await page.evaluate(()=>AMBIENCE_STATS.state);await page.screenshot({path:folder+'/mobile.png',fullPage:true});
 if(errors.length||await page.evaluate(()=>AMBIENCE_STATS.errors.length))throw Error('Remote browser errors');
 const report={status:'passed',url,media_status:200,media_bytes:bytes.length,media_sha256:sha,producer:delivery.producer_commit,real_pointer_checks:[first,second],stopped,errors,scope:'Owner-private remote390px Chromium; two real pointer chapters/actualAACdecode, Stop and full remoteMP4 bytes. Not physical phone/Safari or subjective listening.'};fs.writeFileSync(folder+'/report.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({status:report.status,media_sha256:sha,checks:2}));
}catch(error){fs.writeFileSync(folder+'/failure.json',JSON.stringify({status:'failed',error:String(error).split('Call log:')[0].replace(/Bearer\s+[^\s]+/g,'Bearer [redacted]')},null,2)+'\n');throw new Error(String(error).split('Call log:')[0].replace(/Bearer\s+[^\s]+/g,'Bearer [redacted]'))}finally{await browser.close()}
