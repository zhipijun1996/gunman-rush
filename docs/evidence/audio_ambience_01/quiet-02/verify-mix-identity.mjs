import {createRequire} from 'node:module';
import fs from 'node:fs';
const require=createRequire(import.meta.url),{chromium}=require('playwright');
const url=process.argv[2],out=process.argv[3];
if(!url||!out||fs.existsSync(out))throw Error('URL and fresh output required');
fs.mkdirSync(out,{recursive:true});
const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
const checks=[];
try{
 const context=await browser.newContext({viewport:{width:390,height:844}});
 await context.addInitScript(()=>localStorage.setItem('clock-audio-ambience-v1-choices',JSON.stringify({plains:{profile:'A',notes:'Old QA choice'},forest:{profile:'B'}})));
 const page=await context.newPage();await page.goto(url);await page.waitForFunction(()=>AMBIENCE_STATS.ready);
 const isolation=await page.evaluate(()=>({key:KEY,values:[...document.querySelectorAll('[data-choice]')].map(x=>x.value),notes:[...document.querySelectorAll('textarea')].map(x=>x.value),revision:report.mix_revision,defaultContext:document.getElementById('context').value}));
 if(isolation.key!=='clock-audio-ambience-v1-quiet-02-choices'||isolation.values.some(Boolean)||isolation.notes.some(Boolean)||isolation.revision!=='quiet-02'||isolation.defaultContext!=='mix')throw Error('Old choices leaked or wrong mix/default');
 checks.push({name:'old choices do not approve new mix; real BGM context is default',status:'passed',actual:isolation});
 const downloadWait=page.waitForEvent('download');await page.locator('#export').click();const download=await downloadWait;await download.saveAs(out+'/qa-export.json');const exported=JSON.parse(fs.readFileSync(out+'/qa-export.json'));
 if(exported.mix_revision!=='quiet-02'||exported.events.some(x=>x.profile||x.candidate_id))throw Error('Export revision/choice mismatch');
 checks.push({name:'export explicit mix and unselected IDs',status:'passed',scope:'QA-generated unselected export; not user preference'});
 await context.close();
 for(const file of ['candidates.json','report.json']){
  const c=await browser.newContext(),p=await c.newPage();
  await p.route('**/'+file,async route=>{const response=await route.fetch();const value=await response.json();value.mix_revision='initial-01';await route.fulfill({response,json:value})});
  await p.goto(url);await p.waitForFunction(()=>AMBIENCE_STATS.errors.length>0);
  const rejected=await p.evaluate(()=>({ready:AMBIENCE_STATS.ready,error:document.getElementById('status').textContent,disabled:document.getElementById('play-all').disabled}));
  if(rejected.ready||!rejected.disabled||!rejected.error.includes('混音版本不匹配'))throw Error('Mislabeled old '+file+' accepted');
  checks.push({name:'reject old '+file+' before playback',status:'passed',actual:rejected});await c.close();
 }
 fs.writeFileSync(out+'/report.json',JSON.stringify({status:'passed',checks,scope:'Browser mix identity and choice isolation only; no hearing/device approval'},null,2)+'\n');console.log('QUIET_MIX_IDENTITY checks='+checks.length+' failures=0');
}finally{await browser.close()}
