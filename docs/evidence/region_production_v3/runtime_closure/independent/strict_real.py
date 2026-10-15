import sys,json,time
from pathlib import Path
r=Path('/workspace/gunman-rush');sys.path.insert(0,str(r/'tools'));import run_root_bell_tests as rt
out=r/'build/root_bell/independent_runtime_closure'/str(time.time_ns());out.mkdir(parents=True);rt.OUT=out
result=rt.strict_formal_python_checks();(r/'build/region_production_v3/independent/runtime_closure_review/strict_real.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
