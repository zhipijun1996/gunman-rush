import { createRequire } from 'node:module';
const require=createRequire(import.meta.url);
const { chromium }=require('playwright');
import fs from 'node:fs';
const url=process.argv[2]||'http://127.0.0.1:8765';
const out=process.argv[3]||'build/audio_director/browser-first';fs.mkdirSync(out,{recursive:true});
const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox','--autoplay-policy=no-user-gesture-required']});
const page=await browser.newPage({viewport:{width:390,height:844},isMobile:true,hasTouch:true,deviceScaleFactor:2});
const errors=[];page.on('pageerror',e=>errors.push(String(e)));
try{
 await page.goto(url);await page.waitForFunction(()=>window.LAB_READY);
 const sizes=await page.evaluate(()=>({w:innerWidth,scroll:document.documentElement.scrollWidth,cards:document.querySelectorAll('article').length}));
 if(sizes.scroll>sizes.w||sizes.cards!==16)throw Error('mobile overflow or missing cards '+JSON.stringify(sizes));
 await page.locator('[data-candidate=shot_a]').click();await page.waitForFunction(()=>window.LAB_PLAY_COUNT>=1);
 const sounds=await page.evaluate(async()=>{await unlock();const results=[];for(const e of data.events){for(const c of [...e.candidates,e.original].filter(c=>c?.path)){for(const path of c.variants||[c.path]){const b=await buffer(path);let max=0;for(const x of b.getChannelData(0))max=Math.max(max,Math.abs(x));if(!Number.isFinite(max)||max===0)throw Error('silent/bad '+path);results.push({path,duration:b.duration,max})}}}return results});
 if(sounds.length!==79)throw Error('Expected 64+15 audible comparison variants; got '+sounds.length);
 await page.locator('[data-loop=shot_a]').click();await page.waitForTimeout(1800);
 const before=await page.evaluate(()=>window.LAB_PLAY_COUNT);await page.locator('#stop').click();await page.waitForTimeout(1800);const after=await page.evaluate(()=>window.LAB_PLAY_COUNT);if(after!==before)throw Error('loop continued after stop');
 await page.getByRole('button',{name:'选择 基础枪射击 A · 木芯钟簧',exact:true}).click();
 await page.locator('article[data-event=shot] textarea').fill('测试选择 / test only');
 const downloadPromise=page.waitForEvent('download');await page.locator('#export').click();const download=await downloadPromise;await download.saveAs(out+'/selections.json');
 const selected=JSON.parse(fs.readFileSync(out+'/selections.json'));if(selected.choices.shot.candidate_id!=='shot_a')throw Error('choice export failed');
 await page.reload();await page.waitForFunction(()=>window.LAB_READY);if(await page.locator('article[data-event=shot] textarea').inputValue()!=='测试选择 / test only')throw Error('choice persistence failed');
 const music=[];for(let i=1;i<=5;i++){await page.selectOption('#bgm',{index:i});await page.locator('#music').click();await page.waitForFunction(()=>!bgm.paused&&bgm.currentTime>0);music.push(await page.evaluate(()=>({src:bgm.currentSrc,duration:bgm.duration,time:bgm.currentTime})));await page.locator('#stop').click()}
 await page.evaluate(()=>{localStorage.removeItem('audio-director-choices:'+data.version);choices={};render()});
 await page.screenshot({path:out+'/mobile.png',fullPage:false});
 await page.setViewportSize({width:1280,height:720});await page.screenshot({path:out+'/desktop.png'});
 if(errors.length)throw Error('browser errors '+errors.join('\n'));
 fs.writeFileSync(out+'/report.json',JSON.stringify({status:'passed',url,viewport:sizes,decoded:sounds.length,loopStopped:true,selectionsExport:true,persistence:true,music,errors,limits:'Chromium software browser and decoded sample presence; no listening, hardware or Safari approval.'},null,2));console.log('AUDIO_LAB_BROWSER_OK decoded='+sounds.length+' bgm='+music.length);
}finally{await browser.close()}
