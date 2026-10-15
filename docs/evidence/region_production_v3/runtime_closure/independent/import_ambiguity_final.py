import importlib.util,json
from pathlib import Path
r=Path('/workspace/gunman-rush');s=importlib.util.spec_from_file_location('wt',r/'tests/test_web_bundle.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
t=m.BundleTests();t.setUp();results={}
try:
 name=t.background();other=t.texture_targets[t.raw[0]]
 for label,extra in [('second_remap_section','\n[remap]\nimporter="texture"\npath="res://'+other+'"\n'),('spaced_duplicate_key','path = "res://'+other+'"\n')]:
  entries=t.entries.copy();entries[name+'.import']+=extra.encode()
  try:t.check(entries);results[label]={'accepted':True}
  except Exception as e:results[label]={'accepted':False,'type':type(e).__name__,'reason':str(e)}
 (r/'build/region_production_v3/independent/runtime_closure_review/import_ambiguity.final.json').write_text(json.dumps({'scope':'Synthetic actual format4 bytes only; no engine/config parser exercised','cases':results},indent=2)+'\n');print(results)
finally:t.doCleanups()
