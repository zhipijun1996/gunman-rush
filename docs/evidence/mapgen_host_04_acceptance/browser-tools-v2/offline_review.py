"""Independent actual image review and strict join. Never modifies automatic evidence."""
import argparse
import gzip
import hashlib
import json
import math
from pathlib import Path
import time

PENDING='AUTOMATED_COMPLETE_VISUAL_PENDING'
FILES=['gears-escape-01-committed.png',*[f'gears-escape-motion-{n}-clock-seconds.png' for n in ['2p5','5p0','7p5','10p0']],'gears-escape-before-escape.png','gears-escape-returned-title.png']
SCHEMA='gunman-rush/gears-independent-visual-review/v2'
ACTUAL_VIEW_METHOD='functions.exec/tools.view_image'

def sha(path):
    with Path(path).open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()
def finite(value):return isinstance(value,(int,float)) and not isinstance(value,bool) and math.isfinite(value) and value>=0
def require(ok,message):
    if not ok:raise ValueError(message)
def read(path):return json.loads(Path(path).read_text())
def fresh_output(path,inputs):
    path=Path(path).resolve()
    require(not path.exists(),'Output already exists; original evidence cannot be overwritten')
    require(path not in {Path(v).resolve() for v in inputs},'Output aliases input')
    return path
def write_new(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    with path.open('x') as stream:stream.write(json.dumps(value,indent=2)+'\n')

def validate_report(path):
    path=Path(path).resolve();r=read(path)
    require(r.get('status')==PENDING,'Automatic report is not fully completed with pending independent review')
    require(finite(r.get('elapsed_seconds')) and r['elapsed_seconds']<=300,'Invalid/original300 budget exceeded')
    require(r.get('source_stable') is True and r.get('producer_helpers_stable') is True,'Normal guards incomplete or unstable')
    require(r.get('source_before_raw_sha256')==r.get('source_after_raw_sha256') and bool(r.get('source_before_raw_sha256')),'Source before/after mismatch')
    vectors=[]
    for phase in ['before','after']:
        file=path.parent/('source-'+phase+'.json.gz')
        require(file.is_file(),'Normal source-vector artifact missing')
        raw=gzip.decompress(file.read_bytes())
        require(hashlib.sha256(raw).hexdigest()==r['source_'+phase+'_raw_sha256'],'Normal source-vector SHA mismatch')
        vectors.append(json.loads(raw))
    require(vectors[0]==vectors[1],'Normal source vectors differ')
    require(r.get('producer_helpers_source_before')==r.get('producer_helpers_source_after') and bool(r.get('producer_helpers_source_before')),'Producer before/after mismatch')
    require(r.get('served_before')==r.get('served_after') and bool(r.get('served_before')),'Served HTTP afterguard missing/mismatched')
    require(r.get('browser_closed') is True and len(r.get('sessions',[]))==1,'Browser/context count incomplete')
    row=r['sessions'][0]
    require(row.get('status')=='AUTOMATED_GEARS_ACTIONS_COMPLETE_VISUAL_PENDING' and row.get('context_closed') is True,'Session incomplete')
    require(not row.get('operator_visual_review'),'Automatic evidence must not pretend operator approval')
    require(all(not row.get(k) for k in ['page_errors','parse_errors','script_errors']),'Page/parse/script errors remain')
    require(row.get('actual_generated_output')==r['expected_native_observation']['actual_generated_output'],'Actual result mismatch')
    require(row.get('first_loaded_observation',{}).get('value',{}).get('player')==r['expected_native_observation']['spawn'],'Actual initial spawn mismatch')
    require(row.get('actual_title_start_pixel_point') and row.get('cleanup_precedes_return_log') is True,'Real Title or cleanup order missing')
    closed=row.get('closed_observation',{}).get('value',{})
    require(closed.get('audio_released') is True and closed.get('lifetime_active') is False and closed.get('stage_detached') is True,'Actual cleanup incomplete')
    commits=[v for v in row.get('runtime_observations',[]) if v.get('value',{}).get('event')=='committed']
    require(len(commits)==1,'Missing/late duplicate commit')
    motion=row.get('mechanism_motion',{})
    require(motion.get('source_clock_end',0)-motion.get('source_clock_start',0)>=10 and motion.get('wall_elapsed_seconds',0)>=10,'Original source-clock/wall motion interval incomplete')
    require([v['file'] for v in row.get('screenshots',[])]==FILES,'All original seven captures are required in order')
    inventory=[]
    for capture in row['screenshots']:
        file=path.parent/capture['file']; require(file.is_file() and sha(file)==capture['sha256'],'Capture missing/SHA mismatch')
        inventory.append(dict(file=capture['file'],sha256=capture['sha256'],epoch_ms=capture['epoch_ms']))
    checkpoints=row.get('deferred_visual_checkpoints',[])
    require(len(checkpoints)==3,'Declared checkpoint routes incomplete')
    for index,(action,count) in enumerate(zip(['observe','escape','confirm-title'],[1,6,7])):
        v=checkpoints[index]
        require(v.get('seq')==index+1 and v.get('expected_action')==action and v.get('capture_files')==FILES[:count] and v.get('disposition')=='DEFERRED_ACTUAL_VISUAL_REVIEW_REQUIRED','Invalid declared checkpoint/capture batch')
    return r,inventory

def validate_binding(report,review):
    r,inventory=validate_report(report);v=read(review)
    require(v.get('schema')==SCHEMA and v.get('report_sha256')==sha(report),'Review schema/report binding mismatch; ACK files are not offline reviews')
    require(v.get('report')==str(Path(report).resolve()) and v.get('captures')==inventory,'Review capture inventory mismatch')
    require(finite(v.get('began_epoch_ms')),'Invalid offline review start')
    require(v.get('reviewer_kind')=='independent_actual_image_reviewer' and isinstance(v.get('reviewer_identity'),str) and v['reviewer_identity'].strip() and v['reviewer_identity']!='/root/browser_verify','Independent reviewer identity required')
    return r,inventory,v

def begin(report,review,reviewer):
    r,inventory=validate_report(report)
    require(isinstance(reviewer,str) and reviewer.strip() and reviewer!='/root/browser_verify','Independent reviewer identity required')
    output=fresh_output(review,[report,*[Path(report).parent/v['file'] for v in inventory]])
    write_new(output,dict(schema=SCHEMA,report=str(Path(report).resolve()),report_sha256=sha(report),captures=inventory,began_epoch_ms=time.time()*1000,reviewer_kind='independent_actual_image_reviewer',reviewer_identity=reviewer,records=[]))

def record(report,review,capture,decision,method,notes,started,finished):
    _,inventory,v=validate_binding(report,review)
    require(capture in FILES and not any(x['file']==capture for x in v['records']),'Unknown or duplicate image review')
    require(decision in ['pass','fail'] and method==ACTUAL_VIEW_METHOD and isinstance(notes,str) and notes.strip(),'Actual view method/notes/decision required')
    item=next(x for x in inventory if x['file']==capture)
    require(finite(started) and finite(finished) and v['began_epoch_ms']<=started<=finished<=time.time()*1000+1000 and started>=item['epoch_ms'],'Invalid actual review times')
    v['records'].append(dict(file=capture,capture_sha256=item['sha256'],decision=decision,method=method,notes=notes,started_epoch_ms=started,finished_epoch_ms=finished))
    Path(review).write_text(json.dumps(v,indent=2)+'\n')

def finish(report,review,output):
    r,inventory,v=validate_binding(report,review)
    output=fresh_output(output,[report,review,*[Path(report).parent/x['file'] for x in inventory]])
    require(len(v.get('records',[]))==7 and {x['file'] for x in v['records']}==set(FILES),'Every actual capture needs an independent review')
    for item in inventory:
        rec=next(x for x in v['records'] if x['file']==item['file'])
        require(rec.get('capture_sha256')==item['sha256'] and rec.get('decision')=='pass' and rec.get('method')==ACTUAL_VIEW_METHOD and str(rec.get('notes','')).strip(),'Empty/failing/wrong-SHA or automatic-method image review')
        start,end=rec.get('started_epoch_ms'),rec.get('finished_epoch_ms')
        require(finite(start) and finite(end) and v['began_epoch_ms']<=start<=end<=time.time()*1000+1000 and start>=item['epoch_ms'],'Invalid actual review timing')
    output_data=dict(status='PASSED_GEARS_AUTOMATION_AND_INDEPENDENT_OFFLINE_VISUAL_REVIEW',automatic_report=str(Path(report).resolve()),automatic_report_sha256=sha(report),independent_review=str(Path(review).resolve()),independent_review_sha256=sha(review),reviewer_identity=v['reviewer_identity'],captures=inventory,automatic_elapsed_seconds=r['elapsed_seconds'],offline_review_elapsed_seconds=(max(x['finished_epoch_ms'] for x in v['records'])-v['began_epoch_ms'])/1000,scope='Original one-fresh300s automatic actions/assertions/guards plus actual independent seven-image review outside runtime; no user/device/full-map/performance certification; does not reclassify original manual300 failure or lost default evidence')
    write_new(output,output_data);return output_data

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('command',choices=['begin','record','finish']);p.add_argument('--report',type=Path,required=True);p.add_argument('--review',type=Path,required=True)
    p.add_argument('--output',type=Path);p.add_argument('--reviewer');p.add_argument('--capture');p.add_argument('--decision',choices=['pass','fail']);p.add_argument('--method');p.add_argument('--notes');p.add_argument('--started-epoch-ms',type=float);p.add_argument('--finished-epoch-ms',type=float);a=p.parse_args()
    if a.command=='begin':begin(a.report,a.review,a.reviewer)
    elif a.command=='record':record(a.report,a.review,a.capture,a.decision,a.method,a.notes,a.started_epoch_ms,a.finished_epoch_ms)
    else:print(json.dumps(finish(a.report,a.review,a.output),indent=2))

if __name__=='__main__':main()
