"""Archive actual finite shortcut controls and design decision; no native calls."""
from pathlib import Path
import json,hashlib,zipfile,re
R=Path.cwd();O=R/'docs/evidence/forest_grapple02/checkpoint06';B=R/'build/forest_grapple02';S=lambda x:hashlib.sha256(x).hexdigest();data={};ref=[]
for name in ['shortcut_final02','aperture_probe','aperture_noH_analysis','hh_migrant_context01']:
 base=B/name
 for f in sorted(base.rglob('*')):
  if any(p in {'cache','user-data','import-user','import-cache','import-config','.godot'} for p in f.relative_to(base).parts):continue
  if f.is_file() and not f.is_symlink() and f.suffix in {'.gd','.py','.json','.log','.txt'}:data[str(f.relative_to(R))]=f.read_bytes()
for name in ['choices.gd','choices.log','choices_search.gd','choices_search.log']:
 f=B/name;data[str(f.relative_to(R))]=f.read_bytes()
# Preserve predecessor onlyR actual raw as historical analysis context, not new-aperture proof.
f=B/'spiral04/onlyR.json'
if f.is_file():data[str(f.relative_to(R))]=f.read_bytes()
prior=json.loads((B/'migrant_hollow05/receipt.json').read_text())['source_before']
for suffix,runner in [('01','runner.gd'),('02','runner02.gd'),('03','runner03.gd')]:
 p=B/'aperture_probe';a=json.loads((p/('receipt'+suffix+'.json')).read_text());assert S((p/runner).read_bytes())==a['fixture_sha256'];assert S((p/('native'+suffix+'.log')).read_bytes())==a['native_log_sha256'] and a['source_stable'];assert a['source_before']==a['source_after']
 ref.append({'run':'aperture'+suffix,'native_exit_code':a['exit_code'],'fixture_sha256':a['fixture_sha256'],'source_inventory_matches_checkpoint04_05':a['source_before']==prior,'note':'Native exit status is not design acceptance; see original raw and decision.'})
 if a['source_before']!=prior:
  raise ValueError('Different source requires explicit new source custody')
a=json.loads((B/'shortcut_final02/receipt.json').read_text());assert a['status']=='passed' and a['source_before']==a['source_at_execution']==a['source_after'];assert a['source_before']==prior
hh=json.loads((B/'hh_migrant_context01/receipt.json').read_text());assert hh['status']=='passed' and hh['source_stable'] and hh['source_before']==prior
reference={'extra_HH_context_same_inputs':True,'scope':'Identical original source inventory; explicitly hash-bound build runners archived independently','contexts':ref,'shortcut_sources_match_checkpoint04_05':True,'source_archive':'docs/evidence/forest_grapple02/checkpoint04/selected-originals.zip','source_archive_sha256':S((R/'docs/evidence/forest_grapple02/checkpoint04/selected-originals.zip').read_bytes()),'original_code_config_texts':972};data['derived/source-reference.json']=json.dumps(reference,indent=2).encode();(O/'source-reference.json').write_bytes(data['derived/source-reference.json'])
for raw in data.values():assert not re.search(rb'[?&](?:sig|X-Amz-Signature)=|gh[pousr]_[A-Za-z0-9]{20}',raw)
rows=[{'member':n,'sha256':S(raw),'bytes':len(raw)} for n,raw in sorted(data.items())];inner=json.dumps({'scope':'finite actual controls and observed lower-tail alternative; parentREVISE, not designPASS/fullroute proof','members':rows},indent=2).encode();zp=O/'shortcut-alternative-originals.zip'
with zipfile.ZipFile(zp,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for n,raw in sorted(data.items()):z.writestr(n,raw)
 z.writestr('ARCHIVE-INVENTORY.json',inner)
with zipfile.ZipFile(zp) as z:
 assert len(z.namelist())==len(set(z.namelist()))==len(rows)+1
 for row in rows:assert S(z.read(row['member']))==row['sha256']
inv={'scope':'retained actual alternative; no all7 compulsory or exhaustive-proof claim','archive_bytes':zp.stat().st_size,'archive_sha256':S(zp.read_bytes()),'archive_member_count':len(rows)+1,'members':rows,'archive_inventory_sha256':S(inner),'full_readback_verified':True,'source_reference':reference};(O/'inventory.json').write_text(json.dumps(inv,indent=2)+'\n');print(json.dumps({k:v for k,v in inv.items() if k not in ['members','source_reference']}))
