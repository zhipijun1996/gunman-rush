import importlib.util,json
from pathlib import Path
r=Path('/workspace/gunman-rush');s=importlib.util.spec_from_file_location('wt',r/'tests/test_web_bundle.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
t=m.BundleTests();t.setUp()
try:
 name=t.background();a=t.texture_targets[name];b='.godot/imported/distinct-format.ctex';t.local(b,b'CTEX second supported-format structural fixture');t.entries[b]=b'CTEX second supported-format structural fixture'
 local=('[remap]\nimporter="texture"\npath.s3tc="res://'+a+'"\npath.etc2="res://'+b+'"\n').encode();t.local(name+'.import',local);t.entries[name+'.import']=local
 good=t.check();wrong=t.entries.copy();wrong[name+'.import']=('[remap]\nimporter="texture"\npath.s3tc="res://'+b+'"\npath.etc2="res://'+a+'"\n').encode()
 try:bad=t.check(wrong);error=None
 except Exception as e:bad=None;error={'type':type(e).__name__,'message':str(e)}
 result={'scope':'Actual synthetic format4 PCK byte fixtures; no engine/export/rendering','valid_mapping_passed':bool(good),'swapped_format_mapping_accepted':bad is not None,'error':error,'source_remap':local.decode(),'pack_remap':wrong[name+'.import'].decode()}
 (r/'build/region_production_v3/independent/runtime_closure_review/import_mapping_counterexample.final.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
finally:t.doCleanups()
