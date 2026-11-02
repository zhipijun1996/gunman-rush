"""Retire only exact-rebuilt diagnostic PCKs and official-template engine copies."""
from pathlib import Path
import gzip,hashlib,json,shutil,sys,time,zipfile
OUT=Path('/workspace/refactor-evidence/death-runtime-01/loot-gpu')
ROOT=Path('/workspace/gunman-rush-refactor')
INPUTS=OUT/'retirement-inputs'
BASE=Path('/tmp/gunman-first-use-web-source/build/web/index.9dd3a9a2ecd8.pck')
BASE_SHA='9dd3a9a2ecd845d5728089693282e1642ab1efa2e1868e3925c637fbaa32e0e5'
def sha(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def identity(p):return {'path':str(p),'bytes':p.stat().st_size,'sha256':sha(p)}
assert BASE.is_file() and sha(BASE)==BASE_SHA and BASE.stat().st_size==216394452
INPUTS.mkdir(exist_ok=False)
(INPUTS/'tools').mkdir()
for name,source in [('build_probe.py',ROOT/'tools/mobile_web_perf/build_probe.py'),('check_web_bundle.py',ROOT/'tools/check_web_bundle.py'),('prepare_frame_pair.py',ROOT/'tools/mobile_web_perf/prepare_frame_pair.py')]:
 shutil.copyfile(source,INPUTS/'tools'/name)
sys.path.insert(0,str(INPUTS/'tools'))
from check_web_bundle import Pack
from build_probe import write_pack
pack=Pack(BASE)
before=shutil.disk_usage('/tmp')
receipt={'status':'VERIFYING_BEFORE_DELETION','scope':'Only exact rebuilt diagnostic PCK regular files and exact official ZIP-member JS/WASM copies (including their deterministic gzip) are deleted. All chunks/logs/JSON/source gzip/shaders/scripts/patches/images and original PCK/source cache are preserved. Local sites become incomplete until rebuilt.','base_input':identity(BASE),'before_tmp_free_bytes':before.free,'packs':[],'templates':{},'delete_files':[],'preserved_duplicate_chunks':True,'engine_or_browser_runs':0,'time_epoch':time.time()}
def save(): (OUT/'payload-retirement-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
save()
for attempt in ['01','02']:
 source=OUT/('attempt01-time-not-fixed/pack-receipt.json' if attempt=='01' else 'pack-receipt.json')
 record=json.loads(source.read_text())
 for mode,variant in record['variants'].items():
  directory=Path('/tmp/loot-gpu-'+attempt)/mode
  target=directory/'diagnostic.pck'
  assert not target.is_symlink() and target.stat().st_size==variant['pack_bytes'] and sha(target)==variant['pack_sha256']
  actual=Pack(target);inputs=INPUTS/attempt/mode;inputs.mkdir(parents=True)
  replacements={}
  for name,digest in variant['replaced_sha256'].items():
   data=actual.read(name);assert hashlib.sha256(data).hexdigest()==digest
   path=inputs/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data);replacements[name]=data
  # Demonstrate exact reconstruction, not just theoretical script availability.
  scratch=Path('/tmp/loot-retirement-exact-check.pck')
  assert not scratch.exists()
  try:
   write_pack(pack,replacements,set(variant['removed_remaps']),scratch)
   assert scratch.stat().st_size==variant['pack_bytes'] and sha(scratch)==variant['pack_sha256']
  finally:
   if scratch.exists():scratch.unlink()
  row={'attempt':attempt,'mode':mode,'pack':identity(target),'replacement_order':list(replacements),'replacement_sha256':variant['replaced_sha256'],'removed_remaps':variant['removed_remaps'],'replacement_directory':str(inputs),'exact_reconstruction_verified':True}
  receipt['packs'].append(row);receipt['delete_files'].append(dict(identity(target),kind='exact-rebuilt diagnostic PCK'))
  pair=json.loads((directory/'pair-receipt.json').read_text())
  for variant_engine in pair['variants']:
   archive=Path(variant_engine['template_archive']['path']);expected=variant_engine['template_archive']
   if str(archive) not in receipt['templates']:
    assert archive.is_file() and archive.stat().st_size==expected['bytes'] and sha(archive)==expected['sha256'];receipt['templates'][str(archive)]=identity(archive)
   site=Path(variant_engine['directory'])
   with zipfile.ZipFile(archive) as z:
    for name,engine_file in variant_engine['engine_files'].items():
     path=site/name;data=z.read(engine_file['zip_member'])
     assert not path.is_symlink() and path.read_bytes()==data and sha(path)==engine_file['sha256']
     receipt['delete_files'].append(dict(identity(path),kind='official template ZIP member copy',archive=str(archive),member=engine_file['zip_member']))
     if name.endswith('.wasm'):
      compressed=site/(name+'.gz');assert compressed.read_bytes()==gzip.compress(data,compresslevel=9,mtime=0)
      receipt['delete_files'].append(dict(identity(compressed),kind='deterministic gzip of official template WASM',archive=str(archive),member=engine_file['zip_member'],gzip_compresslevel=9,gzip_mtime=0))
  save()
receipt['status']='ALL_INPUTS_AND_EXACT_REBUILDS_VERIFIED';receipt['planned_bytes']=sum(x['bytes'] for x in receipt['delete_files']);save()
for row in receipt['delete_files']:
 path=Path(row['path'])
 assert path.is_relative_to('/tmp/loot-gpu-01') or path.is_relative_to('/tmp/loot-gpu-02')
 assert not path.is_symlink() and path.stat().st_size==row['bytes'] and sha(path)==row['sha256']
 path.unlink();row['deleted']=True
 save()
assert BASE.exists() and sha(BASE)==BASE_SHA
receipt['status']='RETIRED_EXACT_REBUILDABLE_PAYLOADS'
receipt['after_tmp_free_bytes']=shutil.disk_usage('/tmp').free
receipt['observed_free_increase_bytes']=receipt['after_tmp_free_bytes']-before.free
receipt['deleted_files']=len(receipt['delete_files'])
receipt['preserved_original_pck_verified_after']=True
save();print(json.dumps({k:receipt[k] for k in ['status','deleted_files','planned_bytes','before_tmp_free_bytes','after_tmp_free_bytes','observed_free_increase_bytes']},indent=2))
