#!/usr/bin/env python3
"""Package a verified new Home reel without republishing regional recordings."""
import argparse
import json
from pathlib import Path
import shutil
import zipfile
from capture_audio_home import ROOT,MANIFEST,read,write,sha,frozen_sources,validate_trace,validate_native_audio,chapters_from_segments,validate_capture_override

def build(capture,output):
    if output.exists():raise ValueError('Use a fresh Home delivery directory')
    report=read(capture/'report.json');trace=read(capture/'trace.json');manifest=read(MANIFEST)
    if report.get('status')!='passed' or report.get('source_stable') is not True or report.get('source_before')!=report.get('source_after'):raise ValueError('Home capture source guard did not pass')
    if report['source_before']!=frozen_sources():raise ValueError('Current Home runtime differs from frozen recording')
    if report.get('manifest_sha256')!=sha(MANIFEST) or report.get('content_version')!=manifest['content_version'] or report.get('mix_revision')!=manifest['mix_revision']:raise ValueError('Home source/recipe version changed')
    validate_capture_override(report,capture)
    for name,key in [('native.avi','native_sha256'),('home.mp4','movie_sha256'),('trace.json','trace_sha256')]:
        if sha(capture/name)!=report[key]:raise ValueError('Home native/media/trace fingerprint changed: '+name)
    segments=validate_trace(trace,report['frame_count'],manifest)
    if validate_native_audio(capture/'native.avi',trace,manifest)!=report['native_audio_validation']:raise ValueError('Home native differential proof changed')
    if sha(capture/'chapters.json')!=report.get('chapters_sha256') or json.dumps(read(capture/'chapters.json'),sort_keys=True)!=json.dumps(chapters_from_segments(segments),sort_keys=True):raise ValueError('Home chapters do not match the actual native modes')
    output.mkdir(parents=True);(output/'audio').mkdir();(output/'licenses').mkdir()
    for name in ['home.mp4','chapters.json']:shutil.copyfile(capture/name,output/name)
    shutil.copyfile(ROOT/'tools/sound_lab/home_index.html',output/'index.html')
    bed=manifest['bed_reference'];bed_path=ROOT/bed['path'].removeprefix('res://')
    if sha(bed_path)!=bed['sha256']:raise ValueError('User-selected quiet-02 bed bytes changed')
    shutil.copyfile(bed_path,output/'audio'/bed_path.name)
    points=[]
    for point in manifest['point_events']:
        path=ROOT/point['path'].removeprefix('res://')
        if sha(path)!=point['sha256']:raise ValueError('Home point candidate bytes changed')
        shutil.copyfile(path,output/'audio'/path.name);points.append({**point,'path':'audio/'+path.name})
    write(output/'candidates.json',{'task':'AUDIO-HOME-01','content_version':manifest['content_version'],'mix_revision':manifest['mix_revision'],'manifest_sha256':sha(MANIFEST),'bed':{**bed,'path':'audio/'+bed_path.name,'gain_db':manifest['regions']['home']['profiles']['A']['gain_db']},'point_events':points})
    write(output/'manifest.json',manifest);write(output/'sources.json',read(ROOT/'config/audio_director/home/sources.json'))
    write(output/'regional-bed-selection.json',read(ROOT/'config/audio_director/ambience/user-selected.json'))
    summary={k:v for k,v in report.items() if k not in ['source_before','source_after','media']};summary['source_snapshot_files']=len(report['source_before']);summary['source_snapshot_sha256']=__import__('hashlib').sha256(json.dumps(report['source_before'],sort_keys=True).encode()).hexdigest()
    write(output/'report.json',summary)
    for source in sorted((ROOT/'assets/audio/ambience_v1/home').rglob('*')):
        if source.is_file() and source.suffix in ['.txt','.md','.html']:shutil.copyfile(source,output/'licenses'/source.name)
    for source in sorted((ROOT/'assets/audio/ambience_v1/_sources').glob('*')):
        if source.is_file() and source.suffix in ['.txt','.md','.html']:shutil.copyfile(source,output/'licenses'/('regional-'+source.name))
    write(output/'licenses'/'original-bgm-provenance.json',read(ROOT/'assets/audio/bgm/provenance.json'))
    (output/'README.txt').write_text('失序之钟 · AUDIO-HOME-01\n直接播放 home.mp4：原版／平静底声／底声与稀疏生活音，三段各26秒，正常速度真实HomeScene与原生音轨。原Home BGM全程保持0.16；未做后期配音或淡出音乐。\n三模式同输入地面行走，经过上层工坊下方，不冒称上楼互动。静态NPC所在地生活拟音不声称挥锤动画同步；正常12–22秒节奏，短片不保证全部8素材出现。\naudio/ 提供8点声与原字节quiet-02 plains_a单听，详细来源/许可见sources.json和licenses。床声在家园另有−2dB运行增益。\n完整工坊需在本目录运行 python3 -m http.server 8000 后打开 http://localhost:8000；双击HTML可能受本地fetch限制。选择仅当前浏览器，导出JSON回传。\n自动检查不是用户听感、商业品质或实体设备认可。原BGM只获本游戏/试听使用授权，不是通用素材。\n')
    with zipfile.ZipFile(output/'home-comparison.zip','w',zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(output.rglob('*')):
            if path.is_file() and path.suffix!='.zip':archive.write(path,path.relative_to(output))
    write(output/'delivery.json',{'task':'AUDIO-HOME-01','producer_commit':report['commit'],'content_version':manifest['content_version'],'mix_revision':manifest['mix_revision'],'subjective_status':'awaiting-user','device_status':'unverified','files':{str(p.relative_to(output)):{'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(output.rglob('*')) if p.is_file()}})
    print('AUDIO_HOME_LAB_OK chapters=3 points=8 output='+str(output))

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();build(a.capture.resolve(),a.output.resolve())
if __name__=='__main__':main()
