/** Verify an actual served reels package. Requires real MP4s with their source audio. */
import { createRequire } from 'node:module';
import fs from 'node:fs';
const require=createRequire(import.meta.url),{chromium}=require('playwright');
const url=process.argv[2]||'http://127.0.0.1:8795/';
const output=process.argv[3]||'build/audio_director_v3/web-reels';fs.mkdirSync(output,{recursive:true});
const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
const page=await browser.newPage({viewport:{width:390,height:844},deviceScaleFactor:2,isMobile:true,hasTouch:true});
let videos=[],currentTest=null;
const errors=[];page.on('pageerror',error=>errors.push(String(error)));
try{
 await page.goto(url);await page.waitForFunction(()=>window.REELS_STATS?.ready);
 const layout=await page.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth,videoTop:document.getElementById('reel-video').getBoundingClientRect().top}));
 if(layout.scroll>layout.width||layout.videoTop>450)throw Error('Mobile layout hides or overflows scene video '+JSON.stringify(layout));
 const manifest=await page.evaluate(()=>data);
 // Establish native media playback through an actual Playwright pointer click,
 // with no browser autoplay exemption. Later exhaustive seeks reuse that gesture.
 await page.locator('[data-candidate]').first().click();
 await page.waitForFunction(()=>!video.paused&&!video.seeking&&video.currentTime>0&&video.muted===false&&video.volume>0,null,{timeout:30000});
 const gesturePlayback=await page.evaluate(()=>({paused:video.paused,muted:video.muted,volume:video.volume,time:video.currentTime,activation:navigator.userActivation?{hasBeenActive:navigator.userActivation.hasBeenActive,isActive:navigator.userActivation.isActive}:null}));
 if(gesturePlayback.activation&&gesturePlayback.activation.hasBeenActive!==true)throw Error('Video start lacked a real browser user gesture');
 await page.locator('#stop').click();
 for(const clip of manifest.clips){
  if(await page.locator('[data-clip='+JSON.stringify(clip.id)+']').count())await page.locator('[data-clip='+JSON.stringify(clip.id)+']').click();
  // A clip in another category is selected through its real category button.
  if(await page.evaluate(()=>window.REELS_STATS.state.clip_id)!==clip.id){
   await page.locator('[data-category='+JSON.stringify(clip.category||'场景')+']').click();
   await page.locator('[data-clip='+JSON.stringify(clip.id)+']').click();
  }
  await page.waitForFunction(id=>window.REELS_STATS.state.clip_id===id,clip.id);
  await page.waitForFunction(()=>video.readyState>=1&&Number.isFinite(video.duration),null,{timeout:30000});
  const metadata=await page.evaluate(()=>({duration:video.duration,width:video.videoWidth,height:video.videoHeight,currentSrc:video.currentSrc}));
  if(metadata.width<=0||metadata.height<=0||clip.candidates.some(c=>c.end>metadata.duration+.08))throw Error('Missing real video or wrong timestamps '+clip.id);
  for(const candidate of clip.candidates){
   currentTest={clip:clip.id,candidate:candidate.id};await page.locator('[data-candidate='+JSON.stringify(candidate.id)+']').click();
   await page.waitForFunction(id=>window.REELS_STATS.state.candidate_id===id&&!video.paused&&!video.seeking,candidate.id);
   await page.waitForTimeout(Math.min(300,Math.max(80,(candidate.end-candidate.start)*150)));
   const played=await page.evaluate(()=>({time:video.currentTime,frames:video.getVideoPlaybackQuality?.().totalVideoFrames??video.webkitDecodedFrameCount??null,audioBytes:video.webkitAudioDecodedByteCount??null,audioTracks:typeof video.captureStream==='function'?video.captureStream().getAudioTracks().length:null}));
   if(played.frames!==null&&played.frames<=0)throw Error('No video frames decoded '+candidate.id);
   if(played.time<candidate.start-.15||played.time>candidate.end+.25)throw Error('Seek escaped candidate segment '+candidate.id+' '+played.time);
   if(played.audioTracks===0&&(played.audioBytes===null||played.audioBytes===0))throw Error('Actual video exposes no decoded audio track '+candidate.id);
   videos.push({clip:clip.id,candidate:candidate.id,...metadata,...played});
   await page.locator('#stop').click();
  }
 }
 // Exercise the first actual clip's candidate boundary and loop using its encoded time.
 const first=manifest.clips[0],candidate=first.candidates[0];
 await page.locator('[data-category='+JSON.stringify(first.category||'场景')+']').click();
 await page.locator('[data-clip='+JSON.stringify(first.id)+']').click();
 await page.locator('[data-candidate='+JSON.stringify(candidate.id)+']').click();
 await page.waitForFunction(()=>!video.paused&&!video.seeking);await page.locator('#loop-segment').check();
 const loopsBefore=await page.evaluate(()=>window.REELS_STATS.loops);
 await page.waitForFunction(before=>window.REELS_STATS.loops>before,loopsBefore,{timeout:Math.max(10000,(candidate.end-candidate.start+3)*1000)});
 await page.locator('#stop').click();const stopState=await page.evaluate(()=>window.REELS_STATS.state);await page.waitForTimeout(400);
 if(!(await page.evaluate(()=>video.paused&&!document.getElementById('loop-segment').checked)))throw Error('Stop failed to cancel segment loop');
 // Native player seek and clip/version switches must also cancel the loop.
 await page.locator('[data-candidate='+JSON.stringify(candidate.id)+']').click();await page.waitForFunction(()=>!video.paused);await page.locator('#loop-segment').check();
 await page.evaluate(()=>{const second=document.createElement('video');second.id='mutual-exclusion-fixture';second.src=video.currentSrc;second.playsInline=true;document.body.append(second);return second.play()});
 await page.waitForFunction(()=>video.paused&&!document.getElementById('loop-segment').checked);
 await page.evaluate(()=>{const second=document.getElementById('mutual-exclusion-fixture');second.pause();second.remove()});
 // Stop while seek/play is pending cannot leave a late autoplay behind.
 await page.locator('[data-candidate='+JSON.stringify(candidate.id)+']').click();await page.locator('#stop').click();await page.waitForTimeout(500);if(!(await page.evaluate(()=>video.paused)))throw Error('Late candidate play survived Stop');
 await page.locator('[data-candidate='+JSON.stringify(candidate.id)+']').click();await page.waitForFunction(()=>!video.paused);await page.locator('#loop-segment').check();await page.evaluate(()=>{Object.defineProperty(document,'hidden',{configurable:true,get:()=>true});document.dispatchEvent(new Event('visibilitychange'))});await page.waitForTimeout(250);
 if(!(await page.evaluate(()=>video.paused&&!document.getElementById('loop-segment').checked)))throw Error('Backgrounding left video/loop active');await page.evaluate(()=>delete document.hidden);
 const eventId=candidate.event_ids[0];await page.locator('[data-choice-event]').evaluateAll((selects,{eventId,id})=>{const s=selects.find(x=>x.dataset.choiceEvent===eventId);s.value=id;s.dispatchEvent(new Event('change',{bubbles:true}))},{eventId,id:candidate.id});
 await page.locator('textarea').first().fill('TEST ONLY: actual scene reel choice');
 const downloadTask=page.waitForEvent('download');await page.locator('#export').click();const download=await downloadTask;await download.saveAs(output+'/selections.json');
 const exported=JSON.parse(fs.readFileSync(output+'/selections.json'));
 if(manifest.clips.some(c=>c.candidates.some(x=>x.event_candidate_ids))){for(const item of exported.choices){const clip=manifest.clips.find(c=>c.id===item.clip_id),segment=clip?.candidates.find(c=>c.id===item.candidate_id);if(segment&&item.sound_candidate_id!==(segment.event_candidate_ids?.[item.event_id]||segment.id))throw Error('Per-event sound candidate ID mismatch')}}if(!exported.choices.some(x=>x.clip_id===first.id&&x.event_id===eventId&&x.candidate_id===candidate.id&&x.sound_candidate_id===(candidate.event_candidate_ids?.[eventId]||candidate.id)&&x.profile===(candidate.profile||null)&&x.note==='TEST ONLY: actual scene reel choice'))throw Error('Export lost segment/event sound candidate or profile choice');
 await page.reload();await page.waitForFunction(()=>window.REELS_STATS?.ready);if(await page.locator('textarea').first().inputValue()!=='TEST ONLY: actual scene reel choice')throw Error('Versioned reel choice not persisted');
 await page.evaluate(()=>{localStorage.removeItem('audio-director-reels:'+data.version);choices={};renderChoices()});
 await page.screenshot({path:output+'/mobile.png'});await page.setViewportSize({width:1280,height:800});await page.screenshot({path:output+'/desktop.png'});
 if(errors.length)throw Error('Browser errors '+errors.join('\n'));
 fs.writeFileSync(output+'/report.json',JSON.stringify({status:'passed',url,layout,gesturePlayback,videoChecks:videos,loopStop:true,mutualExclusion:true,pendingPlayCancellation:true,backgroundStop:true,selectionExport:true,selectionPersistence:true,errors,scope:'Actual pointer-started, unmuted MP4 playback without an autoplay exemption; frame/audio-track decode, seek, timed segment loop, media exclusion and choice UI in software Chromium. Source footage authenticity, subjective listening and physical phone/Safari acceptance require separate evidence.'},null,2));
 console.log('AUDIO_REELS_BROWSER_OK clips='+manifest.clips.length+' candidate_segments='+videos.length);
}catch(error){let state=null;try{state=await page.evaluate(()=>({stats:window.REELS_STATS?.state,status:document.getElementById('status')?.textContent,src:document.getElementById('reel-video')?.currentSrc,ready:document.getElementById('reel-video')?.readyState}));await page.screenshot({path:output+'/failure.png'})}catch{}fs.writeFileSync(output+'/failure.json',JSON.stringify({error:String(error),currentTest,state,videos,errors},null,2));throw error}finally{await browser.close()}
