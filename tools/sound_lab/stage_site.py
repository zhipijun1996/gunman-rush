#!/usr/bin/env python3
"""Stage verified original Godot chunks and the listening room for static Sites.

Raw PCK/WASM exceed static per-file limits. The existing verified chunk worker
reconstructs exactly those bytes; this isolated adaptation explicitly requires it.
"""
import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from cloud_delivery import validate_bundle, inject_entry
from audio_director import lab

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 if a.output.exists():raise ValueError('Output must be new')
 info,receipt=validate_bundle(a.bundle,ROOT,'res://experiments/audio/entries/audio_director_lab.tscn')
 lab(a.output,'game/')
 game=a.output/'game';shutil.copytree(a.bundle,game)
 html=game/'index.html';page=inject_entry(html.read_text(),'AUDIO-DIRECTOR-01','audio-director-v1/listen-01','scene','res://experiments/audio/entries/audio_director_lab.tscn')
 old='window.PLAYTEST_CACHE_READY.then(() => engine.startGame({'
 new="window.PLAYTEST_CACHE_READY.then(ready => { if (!ready || typeof DecompressionStream === 'undefined') throw new Error('此独立试玩需要支持 Service Worker 与 DecompressionStream 的现代浏览器；请使用手机最新版 Chrome / Safari。音效单声试听不受影响。'); return engine.startGame({"
 if page.count(old)!=1:raise ValueError('Original chunk loader changed')
 page=page.replace(old,new).replace('})).then(() => {','}); }).then(() => {')
 page=page.replace('</body>','<a href="../" style="position:fixed;right:8px;bottom:8px;z-index:120;color:#e9edcf;background:#15261f;padding:10px">返回音效单声工坊</a></body>')
 html.write_text(page)
 removed=[]
 for file in list(game.iterdir()):
  if file.suffix=='.pck' or file.name.endswith('.wasm') or file.name.endswith('.wasm.gz'):
   removed.append({'path':file.name,'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'bytes':file.stat().st_size});file.unlink()
 # Preserve audio-specific licensing outside the PCK as well.
 shutil.copyfile(ROOT/'config/audio_director/sources.json',game/'Audio-Director-sources.json')
 shutil.copyfile(ROOT/'assets/player_presentation_01/weapon_audio_v2/sources/COPYING.adoc',game/'Freedoom-COPYING.adoc')
 (game/'hosting-adaptation.json').write_text(json.dumps({'task':'AUDIO-DIRECTOR-01','source_commit':info['source_commit'],'build_id':info['build_id'],'original_pack_verification':receipt,'mode':'original hash-verified chunks with explicit ServiceWorker/DecompressionStream requirement; no raw fallback','virtual_resources':removed,'original_html_sha256':hashlib.sha256((a.bundle/'index.html').read_bytes()).hexdigest()},ensure_ascii=False,indent=2)+'\n')
 files=[f for f in a.output.rglob('*') if f.is_file()]
 if any(f.stat().st_size>25*1024*1024 for f in files):raise ValueError('Static asset exceeds25MiB')
 (a.output/'site-delivery.json').write_text(json.dumps({'task':'AUDIO-DIRECTOR-01','source_commit':info['source_commit'],'build_id':info['build_id'],'files':{f.relative_to(a.output).as_posix():{'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'bytes':f.stat().st_size} for f in sorted(files)},'aesthetic_status':'awaiting-user'},indent=2)+'\n')
 print('AUDIO_SITE_STAGED',info['source_commit'],info['build_id'],len(files))
if __name__=='__main__':main()
