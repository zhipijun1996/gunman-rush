"""Exercise material composition through every authored room and reject script errors."""
import re
from run_tests import run_engine

output = run_engine(["--headless", "--path", ".", "--script", "tests/world/terrain_materials.gd"], 240)
if not re.search(r"^TERRAIN MATERIALS: [1-9]\d* assertions, 0 failures$", output, re.MULTILINE):
    raise RuntimeError("Material composition did not complete cleanly")
