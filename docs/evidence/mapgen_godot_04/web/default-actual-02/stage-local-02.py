import hashlib,json,os,sys
from pathlib import Path
root=Path('/tmp/gunman-rush-mapgen-04');sys.path.insert(0,str(root/'tools'))
from cloud_delivery import validate_bundle,inject_entry
bundle=root/'build/web';base=Path('/tmp/mapgen-v4-web');expected_pack='bd23bbc7cf1fc36d471689c80f7108213e8978372f35c2790333f843a468c21b'
rows={}
for label,port in [('default',8819),('gears',8820)]:
 expected=json.loads((Path('/tmp/mapgen-v4-audit/browser-expected-8ms')/(label+'.json')).read_text());scene=expected['scene']
 info,receipt=validate_bundle(bundle,root,scene)
 assert info['source_commit']==expected['source']=='f6b61ee7026bc4c696d15fa26b09de5ff03be903'
 assert receipt['pack_sha256']==expected_pack and receipt['pack_bytes']==218920072
 site=base/'sites-02'/label;site.mkdir(parents=True,exist_ok=False)
 original=(bundle/'index.html').read_text();injected=inject_entry(original,'MAPGEN-GODOT-04',str(expected['actual_generated_output']['seed']),'scene',scene)
 count=0
 for src in bundle.rglob('*'):
  target=site/src.relative_to(bundle)
  assert not src.is_symlink()
  if src.is_dir():target.mkdir(exist_ok=True)
  elif src==bundle/'index.html':target.write_text(injected)
  else:os.link(src,target);count+=1
 assert (site/info['pack']).stat().st_ino==(bundle/info['pack']).stat().st_ino
 rows[label]={'source_commit':info['source_commit'],'build_id':info['build_id'],'pack':info['pack'],'pack_sha256':expected_pack,'pack_bytes':218920072,'scene':scene,'url':'http://127.0.0.1:'+str(port)+'/','site':str(site),'injection':'existing cloud_delivery.inject_entry','original_index_sha256':hashlib.sha256(original.encode()).hexdigest(),'injected_index_sha256':hashlib.sha256(injected.encode()).hexdigest(),'non_HTML_files_hardlinked':count,'large_site_copy':False,'original_bundle_validate_receipt':receipt,'published':False}
 (base/(label+'-site-receipt-02.json')).write_text(json.dumps(rows[label],indent=2)+'\n')
print(json.dumps({label:{k:v[k] for k in ['source_commit','build_id','pack_bytes','scene','url','non_HTML_files_hardlinked','large_site_copy']} for label,v in rows.items()},indent=2))
