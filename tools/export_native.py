"""Release-mode fixed-world exports using the shared audited dependency closure.

Android CI exports are explicitly unsigned and cannot be published as installable
releases; sign_android_release.py signs and verifies the final distributed APK.
"""
from __future__ import annotations
import argparse, hashlib, json, os, re, shutil, subprocess, sys, tempfile, zipfile
from pathlib import Path
import export_workbench as closure
from check_web_bundle import Pack, check_fixed_world_payload
from godot_identity import verified_engine, verify_templates, engine_directory
ROOT=closure.ROOT
DENIED=('docs/','tests/','tools/','experiments/','resources/mapgen/','resources/levels/mapgen','config/world/','config/workbench/','build/workbench/','game/world/regions/V/','assets/visual_development/','resources/visual_development/')

def version()->str:
 return re.search(r'^config/version="([0-9]+\.[0-9]+\.[0-9]+)"$',(ROOT/'project.godot').read_text(),re.M)[1]

def configured_preset(original:str,plan:dict,platform:str)->str:
 n=0 if platform=='windows' else 1
 start=original.index(f'[preset.{n}]');end=original.index(f'[preset.{n}.options]',start)
 header=original[start:end]
 if 'custom_features="fixed_world_release"' not in header or 'export_filter="resources"' not in header:raise ValueError('Native preset must use the controlled release closure')
 names=['res://'+r['path'] for r in plan['files'] if Path(r['path']).suffix in closure.RESOURCE]
 header=re.sub(r'^export_files=.*$','export_files=PackedStringArray('+', '.join(json.dumps(p) for p in names)+')',header,flags=re.M)
 header=re.sub(r'^exclude_filter=.*$','exclude_filter='+json.dumps(','.join(plan['exclusions'])),header,flags=re.M)
 result=original[:start]+header+original[end:]
 if platform=='android':
  if 'package/signed=false' not in result:raise ValueError('CI must never inject a private signing key into export presets')
 return result

class ApkResources:
 def __init__(self,path):
  self.archive=zipfile.ZipFile(path)
  self.entries={n.removeprefix('assets/'):None for n in self.archive.namelist() if n.startswith('assets/') and not n.endswith('/')}
 def read(self,name):return self.archive.read('assets/'+name)

def verify_resources(pack,plan:dict)->dict:
 for name in pack.entries:
  if name.startswith(DENIED) or re.search(r'assets/underworld_plains/[^/]+/sources/',name):raise ValueError('Development payload leaked into native release: '+name)
 fixed=check_fixed_world_payload(pack,ROOT)
 for name in plan['raw_files']:
  if pack.read(name)!=(ROOT/name).read_bytes():raise ValueError('Changed raw runtime dependency: '+name)
 for row in plan['files']:
  name=row['path']
  if name in pack.entries:continue
  suffix='.remap' if Path(name).suffix in {'.gd','.tscn','.tres'} else '.import'
  mapping=pack.read(name+suffix).decode()
  targets=re.findall(r'^path(?:\.[A-Za-z0-9_]+)?="res://([^"\n]+)"$',mapping,re.M)
  if not any(t in pack.entries for t in targets):raise ValueError('Missing native imported dependency: '+name)
 return {'rooms':len(fixed['rooms']),'files_checked':len(plan['files']),'raw_files_checked':len(plan['raw_files']),'content_version':fixed['content_version']}

def copy_licenses(target:Path)->None:
 # Terms only, never historical candidate audio, reference images or masters.
 for name in ['assets/ui/demo_ui_01/r2/fonts','assets/audio/kenney','assets/player_presentation_01/weapon_audio_v2/sources','assets/audio/windkeeper_pressure_01/_sources']:
  base=ROOT/name
  if not base.exists():continue
  for p in base.rglob('*'):
   if p.is_file() and p.suffix.lower() in {'.txt','.md','.adoc'} and any(x in p.name.upper() for x in ['LICENSE','COPYING','OFL']):
    dest=target/'licenses'/p.relative_to(ROOT);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,dest)
 for name in ['LICENSE','LICENSE.txt','COPYRIGHT.txt']:
  if (ROOT/name).is_file():shutil.copyfile(ROOT/name,target/name)
 for name in ['LICENSE.txt','COPYRIGHT.txt']:
  source=engine_directory()/name
  if source.is_file():
   dest=target/'licenses/godot'/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,dest)


def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('platform',choices=['windows','android']);parser.add_argument('--unsigned',action='store_true');parser.add_argument('--skip-import',action='store_true');args=parser.parse_args()
 work=ROOT/'build/native';work.mkdir(parents=True,exist_ok=True)
 closure.run([sys.executable,'tools/world/build.py'],work/'world.log')
 plan=closure.manifest(formal_only=True);(work/'export-closure.json').write_text(json.dumps(plan,indent=2)+'\n')
 engine=verified_engine();verify_templates()
 wrapper=['bash','tools/godot.sh','--headless','--path',str(ROOT)]
 if not args.skip_import:closure.run(wrapper+['--editor','--import','--quit'],work/'import.log',600)
 target=ROOT/'build'/args.platform
 if target.exists():shutil.rmtree(target)
 target.mkdir(parents=True)
 name='GunmanRush.exe' if args.platform=='windows' else 'GunmanRush-unsigned.apk'
 artifact=target/name;presets=ROOT/'export_presets.cfg';original=presets.read_text()
 try:
  presets.write_text(configured_preset(original,plan,args.platform))
  closure.run(wrapper+['--export-release','Windows Desktop' if args.platform=='windows' else 'Android',str(artifact)],work/(args.platform+'-export.log'),600)
 finally:presets.write_text(original)
 pack_path=artifact.with_suffix('.pck') if args.platform=='windows' else artifact
 checked=verify_resources(Pack(pack_path) if args.platform=='windows' else ApkResources(artifact),plan)
 probe=None
 if args.platform=='windows':
  with tempfile.TemporaryDirectory(prefix='native-release-probe-') as isolated:
   probe_script=Path(isolated)/'probe.gd';shutil.copyfile(ROOT/'tools/native_pack_probe.gd',probe_script)
   output=closure.run(['bash','tools/godot.sh','--headless','--path',isolated,'--main-pack',str(pack_path),'--script',str(probe_script),'--fixed-fps','60'],work/'native-probe.log',180)
   if not re.search(r'^NATIVE PACK: \d+ rooms; 0 failures$',output,re.M):raise ValueError('Incomplete native release probe')
   probe={'rooms':checked['rooms'],'result':'pass','host':'Linux locked engine against the Windows PCK; actual Windows startup checked separately'}
 info={'version':version(),'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'platform':args.platform,'mode':'release','source_dirty':bool(subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=ROOT,text=True).strip()),'signed':False if args.platform=='android' else None,'toolchain':{k:v for k,v in engine.items() if k!='binary'},'closure':checked,'native_pack_probe':probe,'device_execution':'unverified'}
 if args.platform=='windows':
  copy_licenses(target)
  (target/'README.txt').write_text('失序之钟 '+version()+'\n解压整个目录后运行 GunmanRush.exe；保留同目录的 GunmanRush.pck。\n支持键鼠与手柄，暂停菜单中可查操作指引。\n')
  (target/'build-info.json').write_text(json.dumps(info,ensure_ascii=False,indent=2)+'\n')
  archive=target/('GunmanRush-v'+version()+'-windows-x86_64.zip')
  with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
   for p in sorted(target.rglob('*')):
    if p.is_file() and p!=archive:z.write(p,Path('GunmanRush')/p.relative_to(target))
  info['archive']={'file':archive.name,'bytes':archive.stat().st_size,'sha256':closure.sha(archive)}
 else:
  info['unsigned_artifact']={'file':artifact.name,'bytes':artifact.stat().st_size,'sha256':closure.sha(artifact)}
  (target/'build-report.json').write_text(json.dumps(info,ensure_ascii=False,indent=2)+'\n')
  with zipfile.ZipFile(artifact) as apk:
   if not any(n.startswith('lib/arm64-v8a/') for n in apk.namelist()):raise ValueError('Missing ARM64 engine')
  if not args.unsigned:
   closure.run([sys.executable,'tools/sign_android_release.py',str(artifact)],work/'android-sign.log',120)
   info['signed']=True
 (target/'build-report.json').write_text(json.dumps(info,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps(info,ensure_ascii=False))
if __name__=='__main__':main()
