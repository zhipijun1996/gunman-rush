import {createRequire} from 'node:module';
import fs from 'node:fs';
const require=createRequire(import.meta.url),{chromium}=require('playwright');
const url=process.argv[2],output=process.argv[3];
if(!url||!output)throw Error('Usage: node verify_ambience.mjs URL FRESH_OUTPUT');
if(fs.existsSync(output))throw Error('Use fresh output; preserve earlier failures');
fs.mkdirSync(output,{recursive:true});
const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
const context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:2,isMobile:true,hasTouch:true,acceptDownloads:true});
const page=await context.newPage(),errors=[],rows=[];
page.on('pageerror',e=>errors.push(String(e)));
try{
 await page.goto(url);await page.waitForFunction(()=>AMBIENCE_STATS.ready);
 const layout=await page.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth,videoTop:document.getElementById('video').getBoundingClientRect().top,chapters:chapters.length,candidates:candidates.length}));
 if(layout.width!==390||layout.scroll!==390||layout.videoTop>230||layout.chapters!==12||layout.candidates!==4)throw Error('Incorrect actual mobile layout/data '+JSON.stringify(layout));
 for(const mode of ['mix','environment']){
  await page.locator('#context').selectOption(mode);
  for(let i=0;i<6;i++){
   await page.locator('[data-chapter]').nth(i).click();
   await page.waitForFunction(()=>{const v=document.getElementById('video');return active&&!v.paused&&!v.seeking&&v.currentTime>=active.start-.03&&v.currentTime<active.end&&v.webkitDecodedFrameCount>0&&v.webkitAudioDecodedByteCount>0},null,{timeout:20000});
   rows.push(await page.evaluate(()=>({id:active.id,profile:active.profile,region:active.region,context:active.context,start:active.start,end:active.end,time:video.currentTime,decodedVideo:video.webkitDecodedFrameCount,decodedAudio:video.webkitAudioDecodedByteCount,muted:video.muted,activation:navigator.userActivation.hasBeenActive})));
   await page.locator('#stop').click();
   if(!await page.evaluate(()=>video.paused&&document.getElementById('single-audio').paused))throw Error('Stop left media playing');
  }
 }
 await page.locator('#context').selectOption('environment');
 await page.locator('[data-chapter]').nth(1).click();await page.waitForFunction(()=>!video.paused);
 await page.evaluate(()=>video.playbackRate=8);
 await page.waitForFunction(()=>video.paused&&AMBIENCE_STATS.completed>0,null,{timeout:5000});
 const boundary=await page.evaluate(()=>({time:video.currentTime,loop:video.loop,completed:AMBIENCE_STATS.completed}));
 await page.evaluate(()=>video.playbackRate=1);
 await page.locator('#loop-video').check();
 const starts=await page.evaluate(()=>AMBIENCE_STATS.starts);
 await page.locator('[data-chapter]').nth(1).click();await page.waitForFunction(()=>!video.paused);
 await page.evaluate(()=>video.playbackRate=8);
 await page.waitForFunction(n=>AMBIENCE_STATS.starts>=n+2,starts,{timeout:6000});
 await page.locator('#stop').click();await page.locator('#loop-video').uncheck();await page.evaluate(()=>video.playbackRate=1);
 await page.locator('summary').filter({hasText:'完整 24 秒'}).click();
 await page.locator('[data-single]').nth(0).click();await page.waitForFunction(()=>!document.getElementById('single-audio').paused);
 if(!await page.evaluate(()=>video.paused&&document.getElementById('single-audio').loop))throw Error('Standalone loop mixed over video');
 await page.locator('#stop').click();
 // Delay the resolution of the first real single.play() promise. A later
 // B request owns this same HTMLMediaElement and must remain playing.
 await page.evaluate(()=>{
  const media=document.getElementById('single-audio'),original=media.play.bind(media);let calls=0;
  window.AMBIENCE_RELEASE_SINGLE=null;
  media.play=async()=>{const n=++calls;await original();if(n===1)await new Promise(resolve=>window.AMBIENCE_RELEASE_SINGLE=resolve)};
 });
 await page.locator('[data-single]').nth(0).click();
 await page.waitForFunction(()=>typeof AMBIENCE_RELEASE_SINGLE==='function');
 await page.locator('[data-single]').nth(1).click();
 await page.waitForFunction(()=>!document.getElementById('single-audio').paused&&document.getElementById('single-audio').currentSrc.includes('plains_b'));
 await page.evaluate(()=>AMBIENCE_RELEASE_SINGLE());await page.waitForTimeout(150);
 if(!await page.evaluate(()=>!document.getElementById('single-audio').paused&&document.getElementById('single-audio').currentSrc.includes('plains_b')))throw Error('Old single play promise paused newer candidate');
 if(await page.locator('[data-point]').count()!==4)throw Error('Point-event library candidates missing');
 for(let i=0;i<4;i++){
  await page.locator('[data-point]').nth(i).click();
  await page.waitForFunction(()=>{const a=document.getElementById('single-audio');return !a.paused&&!a.loop&&a.readyState>=3&&a.currentTime>0},null,{timeout:5000});
  await page.locator('#stop').click();
 }
 await page.locator('[data-chapter]').nth(4).click();await page.waitForFunction(()=>!video.paused);
 if(!await page.evaluate(()=>document.getElementById('single-audio').paused))throw Error('Video did not cancel standalone');
 await page.locator('#stop').click();
 await page.locator('[data-choice=plains]').selectOption('A');await page.locator('[data-choice=forest]').selectOption('B');
 await page.locator('#choices textarea').nth(0).fill('Browser verification note; not aesthetic acceptance');
 const downloading=page.waitForEvent('download');await page.locator('#export').click();const download=await downloading;await download.saveAs(output+'/choices.json');
 const choices=JSON.parse(fs.readFileSync(output+'/choices.json','utf8'));
 if(choices.events.length!==2||choices.events[0].candidate_id!=='plains_a'||choices.events[1].candidate_id!=='forest_b'||!choices.events.every(e=>e.candidate_sha256?.length===64))throw Error('Exported candidate identities invalid');
 await page.reload();await page.waitForFunction(()=>AMBIENCE_STATS.ready);
 if(await page.locator('[data-choice=plains]').inputValue()!=='A'||await page.locator('[data-choice=forest]').inputValue()!=='B')throw Error('Local selections did not persist');
 await page.locator('#play-all').click();await page.waitForFunction(()=>!video.paused);
 await page.evaluate(()=>{Object.defineProperty(document,'hidden',{value:true,configurable:true});document.dispatchEvent(new Event('visibilitychange'))});
 await page.waitForFunction(()=>video.paused);
 await page.evaluate(()=>Object.defineProperty(document,'hidden',{value:false,configurable:true}));
 await page.locator('#play-all').click();await page.waitForFunction(()=>!video.paused);
 await page.evaluate(()=>video.currentTime=video.duration-.25);await page.waitForFunction(()=>video.paused&&video.ended,null,{timeout:5000});
 await page.screenshot({path:output+'/mobile.png',fullPage:true});
 // The real video response is held, then cancelled by a real pointer Stop.
 const delayed=await context.newPage();let release;
 await delayed.route('**/ambience.mp4',async route=>{const response=await route.fetch();await new Promise(resolve=>release=resolve);try{await route.fulfill({response})}catch{}});
 await delayed.goto(url);await delayed.waitForFunction(()=>AMBIENCE_STATS.ready);
 await delayed.locator('[data-chapter]').nth(1).click();await delayed.locator('#stop').click();
 for(let i=0;!release&&i<100;i++)await delayed.waitForTimeout(30);
 if(!release)throw Error('Delayed actual media fetch absent');release();await delayed.waitForTimeout(700);
 if(!await delayed.evaluate(()=>video.paused&&!AMBIENCE_STATS.mediaReady&&AMBIENCE_STATS.state.active===null))throw Error('Late download resumed after Stop');
 await delayed.close();
 if(errors.length)throw Error(errors.join(';'));
 const report={status:'passed',url,layout,realPointerChapters:rows,boundary,loopChapter:true,singleLoopAndMutualExclusion:true,standalonePointEventsPlayed:4,delayedRealSinglePlayDoesNotPauseNewerCandidate:true,localChoicesAndExport:true,controlledVisibilityPause:true,naturalEndNoLoop:true,delayedActualFetchCancelled:true,errors,scope:'390px Chromium software browser; real pointer playback and actual decoded native MP4/AAC. Controlled DOM visibility event and delayed actual play Promise. Point events are standalone library auditions, not formal-map placement proof. No physical phone/Safari or subjective listening approval. Exported choices are automated test data only.'};
 fs.writeFileSync(output+'/report.json',JSON.stringify(report,null,2)+'\n');console.log('AUDIO_AMBIENCE_BROWSER_OK chapters=12');
}catch(error){fs.writeFileSync(output+'/failure.json',JSON.stringify({status:'failed',error:String(error),errors,rows},null,2)+'\n');throw error}finally{await browser.close()}
