#!/usr/bin/env python3
"""Archive the separately recorded legacy chain and select original frame/audio excerpts."""
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import sys

repo = Path(sys.argv[1]).resolve()
runtime = sys.argv[2]
module = importlib.util.spec_from_file_location('enemy_v8_package', Path(__file__).with_name('package.py'))
pkg = importlib.util.module_from_spec(module)
module.loader.exec_module(pkg)
raw = repo / 'build/enemy_feedback_01/v8/movie-legacy'
out = repo / 'docs/evidence/enemy_feedback_01/v8/movies'
report = pkg.matching_report(raw/'report.json', raw/'after.mp4', runtime)
if report['chain'] != 'legacy': raise RuntimeError('Not the independently rendered legacy chain')
receipt = {'task':'ENEMY-FEEDBACK-01','chain':'legacy','runtime':runtime,'status':'running','executions':[],
           'scope':'Consecutive real engine frames/audio, original speed; no gameplay redraw or sound replacement.',
           'segments_seconds':[[0,7],[13,20]],'source':{str(p):pkg.inventory(p) for p in [raw/'after.mp4',raw/'after.json',raw/'report.json']}}
for source,dest in [('after.mp4','legacy-raw.mp4'),('report.json','legacy-report.json'),('after.log','legacy-native.log')]:
    shutil.copy2(raw/source,out/dest)
with (raw/'after.json').open('rb') as source, (out/'legacy.json.gz').open('wb') as target:
    with gzip.GzipFile(filename='',fileobj=target,mode='wb',mtime=0) as compressed:shutil.copyfileobj(source,compressed)
with gzip.open(out/'legacy.json.gz','rb') as source:
    if hashlib.file_digest(source,'sha256').hexdigest() != report['trace_sha256']:raise RuntimeError('Trace bytes mismatch')
filters=['[0:v]split=2[v0][v1]','[0:a]asplit=2[a0][a1]']
for i,(start,end) in enumerate([(0,7),(13,20)]):
    filters.extend([f'[v{i}]trim=start={start}:end={end},setpts=PTS-STARTPTS,{pkg.footer("V8 LEGACY",runtime)}[p{i}]',
                    f'[a{i}]atrim=start={start}:end={end},asetpts=PTS-STARTPTS[s{i}]'])
filters.extend(['[p0][s0][p1][s1]concat=n=2:v=1:a=1[joined_v][a]','[joined_v]settb=expr=1/60,setpts=N[v]'])
dest=out/'legacy.mp4'
pkg.invoke(pkg.encode_command([out/'legacy-raw.mp4'],filters,dest),out,receipt)
media=pkg.probe(dest,out,receipt)
pkg.validate_media(media,13.9,14.1,expected_frames=840)
receipt.update(status='passed',file=pkg.inventory(dest),media=media)
pkg.save_json(out/'legacy-recipe.json',receipt)
# The shared helper stores incremental receipts under recipe.json. Restore the
# core receipt from its immutable backup made before this separate invocation.
shutil.copy2(out/'underworld-recipe.json',out/'recipe.json')
print('Legacy: actual14-second clip,840 frames,60/1 stereo; raw bytes archived')
