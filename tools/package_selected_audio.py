#!/usr/bin/env python3
"""Package the selected native recording, without changing its audio or video."""
import argparse,hashlib,json,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--proof',type=Path);a=p.parse_args();src=a.capture.resolve();dst=a.output.resolve();proof=a.proof or src/'report.json';r=json.loads(proof.read_text())
 if dst.exists():raise ValueError('Use fresh output')
 if r.get('status')!='passed' or r['movie_sha256']!=sha(src/'selected.mp4') or r['trace_sha256']!=sha(src/'trace.json'):raise ValueError('No verified unchanged native media')
 dst.mkdir(parents=True)
 for name in ['selected.mp4','chapters.json']:shutil.copy(src/name,dst/name)
 # Keep the several-thousand-input proof in Git once. The listening player
 # needs a bounded summary; duplicating both full source maps here exceeds
 # the existing site's expanded static-archive limit.
 summary={key:r[key] for key in ['status','commit','scope','engine','frame_count','movie_sha256','movie_bytes','trace_sha256','capture_attempt_status','capture_attempt_error','postvalidator_commit','runtime_sources_unchanged'] if key in r}
 summary.update(record_kind='listening-summary',full_validation_sha256=sha(proof),full_validation_url='https://github.com/zhipijun1996/gunman-rush/blob/feature/audio-director-01/docs/evidence/audio_director_04/capture/'+proof.name,raw_capture_report_url='https://github.com/zhipijun1996/gunman-rush/blob/feature/audio-director-01/docs/evidence/audio_director_04/capture/report.json')
 (dst/'report.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
 shutil.copy(ROOT/'tools/sound_lab/selected_index.html',dst/'index.html')
 for source,name in [('config/audio_director/selected/selected.json','selected.json'),('config/audio_director/selected/user-20261028.json','user-choices.json'),('config/audio_director/v3/sources.json','sources.json')]:shutil.copy(ROOT/source,dst/name)
 licenses=ROOT/'build/audio_director_v3/listen-blob-publish/licenses'
 if not licenses.is_dir():licenses=Path('/workspace/sites/clock-audio-director/dist/reels-v3/licenses')
 if not licenses.is_dir():raise ValueError('Retained license bundle unavailable')
 shutil.copytree(licenses,dst/'licenses')
 trace=json.loads((src/'trace.json').read_text());event=next(s for s in trace['segments'] if s['reel']=='coin' and s['profile']=='selected')['events'][0];time=(event['movie_frame']+10)/60
 subprocess.run(['ffmpeg','-v','error','-y','-ss',str(time),'-i',str(src/'selected.mp4'),'-frames:v','1',str(dst/'poster.jpg')],check=True)
 (dst/'credits.txt').write_text('失序之钟 · 用户所选声音组合\n新候选：Kenney / rubberduck / wobbleboxx 的CC0素材加工；逐素材URL/作者/许可见sources.json与保留的licenses/。\n原版武器包含Freedoom派生声音，保留BSD-3-Clause及署名原文（licenses内COPYING.adoc等）。原角色移动与其他CC0原声来源沿同站V3声音清单保留。\n最终mix章节现场播放用户提供Home原BGM：仅限本项目试听/游戏使用，不提供第三方再用授权；不加工或替换原MP3。\nhttps://clock-audio-director-lab.silkyball18.chatgpt.site/reels-v3/\n这是明确开发fixture原生录屏，非自然完整关卡或实体设备/组合审美批准。\n')
 record={'task':'AUDIO-DIRECTOR-04','capture_source_commit':r['commit'],'package_source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'native_media_unchanged':True,'user_export_sha256':sha(dst/'user-choices.json'),'files':{f.relative_to(dst).as_posix():{'sha256':sha(f),'bytes':f.stat().st_size} for f in sorted(dst.rglob('*')) if f.is_file()}}
 (dst/'delivery.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n');print(json.dumps({'output':str(dst),'files':len(record['files']),'movie_sha256':sha(dst/'selected.mp4')}))
if __name__=='__main__':main()
