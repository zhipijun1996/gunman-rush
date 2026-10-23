import sys,os,json,hashlib,subprocess,shutil,copy
from pathlib import Path
ROOT=Path('/workspace/ui-workline');sys.path.insert(0,str(ROOT/'tools'));import harness
old=ROOT/'build/verification/demo-ui-r2/film-v2';folder=ROOT/'build/verification/demo-ui-r3/film';folder.mkdir(exist_ok=False)
sha=lambda p:hashlib.file_digest(p.open('rb'),'sha256').hexdigest()
original=json.loads((old/'report.json').read_text());source=harness.git_metadata();assert source['git_status']==''
old_after=next(r for r in original['captures'] if r['variant']=='after')
assert sha(old/'after.mp4')==old_after['mp4_sha256'] and sha(old/'after.json')==old_after['trace_sha256']
for ext in ('.mp4','.json','.log'):shutil.copyfile(old/('after'+ext),folder/('before'+ext))
before=copy.deepcopy(old_after);before.update(variant='before',source_commit=original['source_metadata']['commit'],reuse_from='build/verification/demo-ui-r2/film-v2/report.json after record',original_driver_sha256=original['conditions']['driver_sha256'])
report={'task':'DEMO-UI-01','status':'running','source_metadata':source,'source_stable':False,'scope':'Actual Godot MovieWriter. R2 UI compared with R3 current time energy. Real native pointer; explicit official damage/heal fixtures and real jump/aim/release costs. Not natural combat/device performance proof.','baseline':'Exact prior R2 after.mp4 and trace reused byte-for-byte with original source/driver attribution; no relabeling.','conditions':{'resolution':[1280,720],'fps':60,'renderer':'gl_compatibility llvmpipe','seed':'level-design-v2-baseline/08','persistence':False,'driver_sha256':sha(ROOT/'tests/demo_ui_01/r3_movie_runner.gd')},'comparison_differences':['R2 and R3 HUD layouts and resource policy differ by explicit user feedback.','R3 holds real airborne aim for60 rather than8 frames to show the actual time-energy ring; both traces end at880 frames. Prior driver and source are separately attributed.'],'captures':[before]}
env={**os.environ,'DISPLAY':':101','LIBGL_ALWAYS_SOFTWARE':'1'}
try:
 movie=folder/'after.avi';trace=folder/'after.json';mp4=folder/'after.mp4'
 argv=['bash','tools/godot.sh','--path','.','--rendering-method','gl_compatibility','--write-movie',str(movie),'--fixed-fps','60','--script','tests/demo_ui_01/r3_movie_runner.gd','--','--trace='+str(trace)]
 execution=harness.run_check({'argv':argv,'timeout_seconds':240,'success_pattern':r'^DEMO UI MOVIE: 880 frames, damage=true heal=true shot=true ring=true$'},folder/'after.log',ROOT,env)
 record={'variant':'after','source_commit':source['commit'],'execution':execution,'command':argv};report['captures'].append(record)
 if execution['status']!='passed':raise RuntimeError('R3 engine recording failed')
 subprocess.run(['ffmpeg','-y','-i',str(movie),'-c:v','libx264','-crf','20','-pix_fmt','yuv420p','-c:a','aac',str(mp4)],check=True,stdout=subprocess.DEVNULL,stderr=(folder/'encode.log').open('w'),timeout=90)
 record.update(mp4_sha256=sha(mp4),trace_sha256=sha(trace),avi_sha256=sha(movie))
 (folder/'pair.txt').write_text("file 'before.mp4'\nfile 'after.mp4'\n")
 subprocess.run(['ffmpeg','-y','-f','concat','-safe','0','-i',str(folder/'pair.txt'),'-c','copy',str(folder/'comparison.mp4')],check=True,stdout=subprocess.DEVNULL,stderr=(folder/'concat.log').open('w'),timeout=30)
 report.update(comparison_sha256=sha(folder/'comparison.mp4'),source_stable=source==harness.git_metadata())
 if not report['source_stable']:raise RuntimeError('source drift')
 report['status']='passed'
except Exception as e:report.update(status='failed',error=str(e));raise
finally:
 (folder/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(report['status'],report.get('error',''))
