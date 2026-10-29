from pathlib import Path
import sys,os,subprocess,json,shutil,selectors,time
sys.path.insert(0,'/workspace/gunman-rush/tools')
import enemy_all_review_02 as original
root=original.ROOT
folder=root/'build/plains_revision_01/comparison-03'
folder.mkdir(parents=True,exist_ok=False)
source=original.harness.git_metadata()
report={'task':'PLAINS-MONSTER-REVISION-01','kind':'staged_scale_comparison','source':source,'status':'running','scope':'Original DemoApp plains terrain, explicitly held comparison samples/player. Not combat or natural traversal.'}
env=os.environ.copy();env['LIBGL_ALWAYS_SOFTWARE']='1'
display=None;started=time.monotonic();code=0
try:
    binary=shutil.which('Xvfb') or str(root.parent/'toolchains/xvfb/usr/bin/Xvfb')
    display_log=(folder/'display.log').open('wb')
    display=subprocess.Popen([binary,'-displayfd','1','-screen','0','1280x720x24','-nolisten','tcp','-ac'],stdout=subprocess.PIPE,stderr=display_log)
    with selectors.DefaultSelector() as selected:
        selected.register(display.stdout,selectors.EVENT_READ)
        if not selected.select(30):raise RuntimeError('Xvfb startup failed')
        number=display.stdout.readline().decode().strip()
    if not number.isdigit():raise RuntimeError('No display id')
    env['DISPLAY']=':'+number
    avi=folder/'capture.avi';movie=folder/'review.mp4';trace_path=folder/'trace.json'
    command=['bash','tools/godot.sh','--path','.','--rendering-method','gl_compatibility','--write-movie',str(avi),'--fixed-fps','60','--script','tools/plains_revision_01_comparison.gd','--','--trace='+str(trace_path)]
    report['command']=command
    result=original.harness.run_check({'argv':command,'timeout_seconds':300,'success_pattern':r'^PLAINS REVISION COMPARISON: complete; pages=6; frames=\d+$'},folder/'capture.log',root,env)
    report['execution']=result
    if result['status']!='passed':raise RuntimeError('Godot strict recording failed: '+str(result))
    trace=json.loads(trace_path.read_text())
    if not trace['complete'] or trace['failures'] or len(trace['pages'])!=6 or not trace['source_stable'] or not trace['original_manifest_unchanged']:raise RuntimeError('Comparison trace incomplete/unstable')
    report['original_engine_audio']=original.original_audio_statistics(avi,folder)
    with (folder/'encode.log').open('wb') as log:
        subprocess.run(['ffmpeg','-y','-i',str(avi),'-c:v','libx264','-crf','20','-pix_fmt','yuv420p','-c:a','aac','-movflags','+faststart',str(movie)],stdout=subprocess.DEVNULL,stderr=log,check=True,timeout=150)
    media=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(movie)]))
    report.update(media=media,mp4_sha256=original.digest(movie),avi_sha256=original.digest(avi),trace_sha256=original.digest(trace_path),source_stable=source==original.harness.git_metadata(),raw_avi_retained=False)
    if not report['source_stable']:raise RuntimeError('Full project source changed during recording')
    report['status']='recorded_staged_scale_comparison';avi.unlink()
    print('Actual comparison recorded:',media['format']['duration'],movie,flush=True)
except BaseException as exc:
    code=1;report.update(status='failed',error=str(exc));print(str(exc),flush=True)
finally:
    report['seconds']=time.monotonic()-started
    (folder/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    if display:
        display.terminate()
        try:display.wait(timeout=5)
        except subprocess.TimeoutExpired:display.kill();display.wait()
        display_log.close()
raise SystemExit(code)
