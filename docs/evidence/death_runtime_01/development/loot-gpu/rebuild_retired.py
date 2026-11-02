"""Rebuild retired loot diagnostics exactly, without Godot or Chromium."""
import argparse,gzip,hashlib,json,sys,zipfile
from pathlib import Path
OUT=Path(__file__).resolve().parent
RECEIPT=json.loads((OUT/'payload-retirement-receipt.json').read_text())
sys.path.insert(0,str(OUT/'retirement-inputs/tools'))
from check_web_bundle import Pack
from build_probe import write_pack
def sha(path):
 with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--attempt',choices=['01','02'],required=True)
parser.add_argument('--variant',choices=['baseline','candidate'],required=True)
parser.add_argument('--restore',action='store_true',help='Without this, print the exact reconstruction plan only.')
args=parser.parse_args()
base=Path(RECEIPT['base_input']['path']);assert sha(base)==RECEIPT['base_input']['sha256']
row=next(x for x in RECEIPT['packs'] if x['attempt']==args.attempt and x['mode']==args.variant)
target=Path(row['pack']['path']);engine_rows=[x for x in RECEIPT['delete_files'] if Path(x['path']).is_relative_to(target.parent/'web')]
if not args.restore:
 print(json.dumps({'pack':row['pack'],'engine_files':len(engine_rows),'command':'Add --restore to reconstruct this diagnostic payload; no engine/browser is launched.'},indent=2));raise SystemExit
assert not target.exists()
replacements={}
for name in row['replacement_order']:
 data=(Path(row['replacement_directory'])/name).read_bytes();assert hashlib.sha256(data).hexdigest()==row['replacement_sha256'][name];replacements[name]=data
write_pack(Pack(base),replacements,set(row['removed_remaps']),target)
assert target.stat().st_size==row['pack']['bytes'] and sha(target)==row['pack']['sha256']
for item in engine_rows:
 path=Path(item['path']);assert not path.exists();archive=Path(item['archive']);assert sha(archive)==RECEIPT['templates'][str(archive)]['sha256']
 with zipfile.ZipFile(archive) as z:data=z.read(item['member'])
 if 'gzip_mtime' in item:data=gzip.compress(data,compresslevel=item['gzip_compresslevel'],mtime=item['gzip_mtime'])
 assert len(data)==item['bytes'] and hashlib.sha256(data).hexdigest()==item['sha256'];path.write_bytes(data)
print(json.dumps({'status':'RESTORED_EXACT_PAYLOAD','pack':str(target),'sha256':sha(target),'engine_files':len(engine_rows)}))
