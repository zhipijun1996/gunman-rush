from pathlib import Path
import sys
root=Path.cwd();sys.path.insert(0,str(root/'tests'))
archive=root/'build/region_production_v3/ci_uid_portability/test_level_design_routing.py.before'
# Exact old routing bytes; real filename supplies unchanged ROOT/import semantics.
# Helper import is now fixed; the old routing assertion independently still fails1001.
__file__=str(root/'tests/test_level_design_routing.py')
exec(compile(archive.read_bytes(),__file__,'exec'),globals())
