import {createRequire} from 'node:module';import fs from 'node:fs';
const require=createRequire(import.meta.url),{chromium}=require('playwright'),url=process.argv[2],output=process.argv[3];
if(!url||!output||fs.existsSync(output))throw Error('Usage: verify_home.mjs URL FRESH_OUTPUT');fs.mkdirSync(output,{recursive:true});
const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox']}),context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:2,isMobile:true,hasTouch:true,acceptDownloads:true}),page=await context.newPage(),errors=[],played=[];
page.on('pageerror',e=>errors.push(String(e)));
try{
 await page.goto(url);await page.waitForFunction(()=>HOME_AUDIO_STATS.ready);
 const layout=await page.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth,chapters:chapters.length,points:data.point_events.length,videoTop:video.getBoundingClientRect().top,identity:HOME_AUDIO_STATS.identity}));
 if(layout.width!==390||layout.scroll!==390||layout.chapters!==3||layout.points!==8||layout.videoTop>250)throw Error('Invalid actual Home mobile layout '+JSON.stringify(layout));
 if(layout.identity?.task!=='AUDIO-HOME-01'||layout.identity.content_version!=='audio-home-v1'||layout.identity.mix_revision!=='home-quiet-01'||layout.identity.raw_bytes_verified!==true||!/^([0-9a-f]{64})$/.test(layout.identity.manifest_sha256))throw Error('Actual manifest-byte identity was not verified');
 for(let i=0;i<3;i++){
  await page.locator('[data-mode]').nth(i).click();await page.waitForFunction(()=>active&&!video.paused&&!video.seeking&&video.currentTime>=active.start-.03&&video.currentTime<active.end&&video.webkitDecodedFrameCount>0&&video.webkitAudioDecodedByteCount>0,null,{timeout:20000});
  played.push(await page.evaluate(()=>({mode:active.mode,start:active.start,end:active.end,time:video.currentTime,decodedVideo:video.webkitDecodedFrameCount,decodedAudio:video.webkitAudioDecodedByteCount,muted:video.muted,activation:navigator.userActivation.hasBeenActive})));
  await page.locator('#stop').click();if(!await page.evaluate(()=>video.paused&&single.paused))throw Error('Stop left Home audio playing');
 }
 await page.locator('[data-mode=bed]').click();await page.waitForFunction(()=>!video.paused);await page.evaluate(()=>video.playbackRate=16);await page.waitForFunction(()=>video.paused&&HOME_AUDIO_STATS.completed>0,null,{timeout:6000});
 await page.locator('#loop').check();const starts=await page.evaluate(()=>HOME_AUDIO_STATS.starts);await page.locator('[data-mode=life]').click();await page.waitForFunction(()=>!video.paused);await page.waitForFunction(n=>HOME_AUDIO_STATS.starts>=n+2,starts,{timeout:6000});await page.locator('#stop').click();await page.locator('#loop').uncheck();await page.evaluate(()=>video.playbackRate=1);
 await page.locator('summary').filter({hasText:'单独试听'}).click();if(await page.locator('[data-single]').count()!==9)throw Error('Missing borrowed bed/eight life sources');
 for(let i=0;i<9;i++){
  await page.locator('[data-single]').nth(i).click();await page.waitForFunction(()=>!single.paused&&single.readyState>=3&&single.currentTime>0,null,{timeout:5000});if(!await page.evaluate(()=>video.paused))throw Error('Standalone Home source mixed over video');await page.locator('#stop').click();
 }
 await page.evaluate(()=>{const original=single.play.bind(single);let count=0;window.HOME_RELEASE_SINGLE=null;single.play=async()=>{const n=++count;await original();if(n===1)await new Promise(resolve=>window.HOME_RELEASE_SINGLE=resolve)}});
 await page.locator('[data-single=home_cloth_1]').click();await page.waitForFunction(()=>typeof HOME_RELEASE_SINGLE==='function');await page.locator('[data-single=home_cloth_2]').click();await page.waitForFunction(()=>!single.paused&&single.currentSrc.includes('home_cloth_2'));await page.evaluate(()=>HOME_RELEASE_SINGLE());await page.waitForTimeout(120);if(!await page.evaluate(()=>!single.paused&&single.currentSrc.includes('home_cloth_2')))throw Error('Old Home single promise paused new clip');await page.locator('#stop').click();
 await page.locator('#choice').selectOption('life');await page.locator('#notes').fill('Automated browser verification only; not user listening approval');const downloading=page.waitForEvent('download');await page.locator('#export').click();await(await downloading).saveAs(output+'/choices.json');const choice=JSON.parse(fs.readFileSync(output+'/choices.json','utf8'));
 if(choice.task!=='AUDIO-HOME-01'||choice.selected_mode!=='life'||choice.bed_sha256.length!==64||choice.manifest_sha256.length!==64)throw Error('Export does not bind Home content/bed identity');
 await page.reload();await page.waitForFunction(()=>HOME_AUDIO_STATS.ready);if(await page.locator('#choice').inputValue()!=='life')throw Error('Home choice did not persist');
 await page.locator('#play-all').click();await page.waitForFunction(()=>!video.paused);await page.evaluate(()=>{Object.defineProperty(document,'hidden',{value:true,configurable:true});document.dispatchEvent(new Event('visibilitychange'))});await page.waitForFunction(()=>video.paused);await page.evaluate(()=>Object.defineProperty(document,'hidden',{value:false,configurable:true}));
 await page.locator('#play-all').click();await page.waitForFunction(()=>!video.paused);await page.evaluate(()=>video.currentTime=video.duration-.25);await page.waitForFunction(()=>video.paused&&video.ended,null,{timeout:5000});
 await page.locator('[data-mode=life]').click();await page.waitForFunction(()=>!video.paused&&video.currentTime>active.start+.15);await page.evaluate(()=>video.pause());await page.screenshot({path:output+'/mobile.png',fullPage:true});
 const delayed=await context.newPage();let release;await delayed.route('**/home.mp4',async route=>{const response=await route.fetch();await new Promise(resolve=>release=resolve);try{await route.fulfill({response})}catch{}});await delayed.goto(url);await delayed.waitForFunction(()=>HOME_AUDIO_STATS.ready);await delayed.locator('[data-mode=life]').click();await delayed.locator('#stop').click();for(let i=0;!release&&i<100;i++)await delayed.waitForTimeout(30);if(!release)throw Error('Delayed actual Home MP4 fetch absent');release();await delayed.waitForTimeout(700);if(!await delayed.evaluate(()=>video.paused&&!HOME_AUDIO_STATS.mediaReady&&HOME_AUDIO_STATS.state.mode===null))throw Error('Cancelled Home fetch resumed late');await delayed.close();
 const metadataCases=[];
 for(const file of ['candidates.json','report.json'])for(const [field,value] of Object.entries({task:'AUDIO-FOREIGN-01',content_version:'audio-home-v0',mix_revision:'home-quiet-foreign',manifest_sha256:'0'.repeat(64)}))metadataCases.push({id:file+'/'+field,changes:{[file]:{[field]:value}}});
 metadataCases.push({id:'candidates/nonhex-sha',changes:{'candidates.json':{manifest_sha256:'not-a-fingerprint'}}});
 metadataCases.push({id:'matching-forged-report-and-candidates-sha',changes:{'candidates.json':{manifest_sha256:'0'.repeat(64)},'report.json':{manifest_sha256:'0'.repeat(64)}}});
 metadataCases.push({id:'actual-manifest-byte-change',changes:{},mutateManifestBytes:true});
 const metadataRejections=[];
 for(const test of metadataCases){
  const negative=await context.newPage();let videoRequests=0;
  negative.on('request',request=>{if(new URL(request.url()).pathname.endsWith('/home.mp4'))videoRequests++});
  await negative.route('**/*.json',async route=>{
   const filename=new URL(route.request().url()).pathname.split('/').at(-1);
   if(test.mutateManifestBytes&&filename==='manifest.json'){const response=await route.fetch();await route.fulfill({response,body:Buffer.concat([await response.body(),Buffer.from('\n')])});return}
   if(test.changes[filename]){const response=await route.fetch();const body={...await response.json(),...test.changes[filename]};await route.fulfill({response,contentType:'application/json',body:JSON.stringify(body)});return}
   await route.continue();
  });
  await negative.goto(url);await negative.waitForFunction(()=>HOME_AUDIO_STATS.errors.length>0,null,{timeout:10000});
  const result=await negative.evaluate(()=>({ready:HOME_AUDIO_STATS.ready,mediaReady:HOME_AUDIO_STATS.mediaReady,playDisabled:document.getElementById('play-all').disabled,exportDisabled:document.getElementById('export').disabled,message:document.getElementById('status').textContent,paused:video.paused&&single.paused}));
  if(result.ready||result.mediaReady||!result.playDisabled||!result.exportDisabled||!result.paused||videoRequests||!/身份|manifest|指纹/.test(result.message))throw Error('Actual metadata counterexample was not rejected: '+test.id+' '+JSON.stringify(result));
  metadataRejections.push({case:test.id,rejected:true,videoRequests,...result});await negative.close();
 }
 if(errors.length)throw Error(errors.join(';'));fs.writeFileSync(output+'/report.json',JSON.stringify({status:'passed',url,layout,realPointerChapters:played,standaloneAudioPlayed:9,loopAndBoundary:true,stopAndMutualExclusion:true,delayedRealSinglePromiseSafe:true,delayedActualMp4Cancelled:true,choicePersistedAndExported:true,controlledVisibilityPause:true,naturalEndNoLoop:true,metadataRejections,errors,scope:'390px software Chromium, actual native MP4/AAC and nine source files with pointer playback. Raw manifest bytes verified by WebCrypto; eleven real-browser metadata/byte counterexamples reject before media request. Delayed actual audio-play Promise/MP4 fetch and controlled DOM visibility event. Automated exported preference is test data, not user/physical-device/aesthetic approval.'},null,2)+'\n');console.log('AUDIO_HOME_BROWSER_OK chapters=3 sources=9 metadata_rejections='+metadataRejections.length);
}catch(error){fs.writeFileSync(output+'/failure.json',JSON.stringify({status:'failed',error:String(error),played,errors},null,2)+'\n');throw error}finally{await browser.close()}
