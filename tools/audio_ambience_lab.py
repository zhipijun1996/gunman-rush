#!/usr/bin/env python3
"""Package the validated native ambience reel and exact four loop candidates."""
import argparse
import json
from pathlib import Path
import shutil
import zipfile
from capture_audio_ambience import ROOT, read, sha, write, frozen_sources, validate_trace, chapters_from_segments

def build(capture, output):
    if output.exists(): raise ValueError('Use fresh delivery directory')
    report=read(capture/'report.json'); trace=read(capture/'trace.json'); manifest=read(ROOT/'assets/audio/ambience_v1/manifest.json')
    movie=capture/'ambience.mp4'
    if report.get('status')!='passed' or report.get('source_stable') is not True or report.get('source_before')!=report.get('source_after'): raise ValueError('Capture did not pass original frozen source guard')
    if report['source_before'] != frozen_sources(): raise ValueError('Runtime or capture source changed since recording')
    if report['movie_sha256']!=sha(movie) or report['trace_sha256']!=sha(capture/'trace.json'): raise ValueError('Native media or trace hash differs')
    if len(report.get('native_audio_validation',[])) != 6: raise ValueError('Missing actual native audio proof')
    segments=validate_trace(trace,report['frame_count'],manifest)
    expected_chapters=chapters_from_segments(segments)
    if report.get('chapters_sha256')!=sha(capture/'chapters.json') or json.dumps(read(capture/'chapters.json'),sort_keys=True)!=json.dumps(expected_chapters,sort_keys=True):
        raise ValueError('Chapter identity/timing differs from actual native trace')
    output.mkdir(parents=True); (output/'audio').mkdir(); (output/'licenses').mkdir()
    for name in ['ambience.mp4','chapters.json']:
        shutil.copyfile(capture/name,output/name)
    shutil.copyfile(ROOT/'tools/sound_lab/ambience_index.html',output/'index.html')
    choices=[]
    for event in manifest['events']:
        for candidate in event['candidates']:
            source=ROOT/candidate['path'].removeprefix('res://'); name=source.name
            shutil.copyfile(source,output/'audio'/name)
            choices.append({'id':candidate['id'],'region':event['region'],'profile':candidate['profile'],'title':candidate.get('title',candidate['id']),'path':'audio/'+name,'duration':candidate['duration'],'sha256':sha(source),'sources':candidate.get('source_ids',candidate.get('renders',{}))})
    sources=read(ROOT/'config/audio_director/ambience/sources.json')
    points=[]
    for point in manifest.get('point_events',[]):
        source=ROOT/point['path'].removeprefix('res://')
        if sha(source)!=point['sha256']: raise ValueError('Point-event output fingerprint changed')
        shutil.copyfile(source,output/'audio'/source.name)
        points.append({**point,'path':'audio/'+source.name,'scope':'Standalone library candidate; not automatically deployed throughout formal maps'})
    write(output/'sources.json',sources)
    write(output/'manifest.json',manifest)
    write(output/'candidates.json',{'version':manifest['version'],'candidates':choices,'point_events':points,'manifest_sha256':sha(ROOT/'assets/audio/ambience_v1/manifest.json')})
    # Compact browser metadata; full native trace/source fingerprints remain in Git evidence.
    summary={k:v for k,v in report.items() if k not in ['source_before','source_after','media']}
    summary['source_snapshot_sha256']=__import__('hashlib').sha256(json.dumps(report['source_before'],sort_keys=True).encode()).hexdigest()
    summary['source_snapshot_files']=len(report['source_before'])
    write(output/'report.json',summary)
    for source in sorted((ROOT/'assets/audio/ambience_v1').rglob('*')):
        if source.is_file() and (source.suffix.lower() in ['.html','.txt','.md'] or 'license' in source.name.lower()):
            shutil.copyfile(source,output/'licenses'/source.name)
    # Existing action soundtrack keeps the original BSD-3-Clause attribution.
    freedoom=ROOT/'assets/player_presentation_01/weapon_audio_v2/sources/COPYING.adoc'
    if not freedoom.is_file(): raise ValueError('Missing original Freedoom BSD-3-Clause license')
    shutil.copyfile(freedoom,output/'licenses'/'Freedoom-COPYING.adoc')
    write(output/'licenses'/'original-bgm-provenance.json',read(ROOT/'assets/audio/bgm/provenance.json'))
    (output/'licenses'/'README.txt').write_text('New ambience: exact CC0 source records and original license pages in sources.json/licenses. Existing actions retain Kenney CC0 and Freedoom BSD-3-Clause provenance in game repository. Original five BGM files are user-provided for this game/audition only; no general reuse permission. Source recordings are not BGM.\n')
    with zipfile.ZipFile(output/'ambience-comparison.zip','w',zipfile.ZIP_DEFLATED) as archive:
        for source in sorted(output.rglob('*')):
            if source.is_file() and source.suffix!='.zip': archive.write(source,source.relative_to(output))
    write(output/'delivery.json',{'task':'AUDIO-AMBIENCE-01','producer_commit':report['commit'],'version':manifest['version'],'subjective_status':'awaiting-user','device_status':'unverified','files':{str(p.relative_to(output)):{'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(output.rglob('*')) if p.is_file()}})
    print('AUDIO_AMBIENCE_LAB_OK beds=4 points='+str(len(points))+' chapters=12 output='+str(output))

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();build(a.capture.resolve(),a.output.resolve())
if __name__=='__main__':main()
