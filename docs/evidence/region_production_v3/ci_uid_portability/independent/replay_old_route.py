from pathlib import Path
import sys
r=Path('/workspace/gunman-rush');sys.path.insert(0,str(r/'tests'));__file__=str(r/'tests/test_level_design_routing.py')
exec(compile((r/'build/region_production_v3/ci_uid_portability/test_level_design_routing.py.before').read_bytes(),__file__,'exec'),globals())
