"""Exercise real element routing, persistence, lifecycle and room migration."""
import re
from run_tests import run_engine
output = run_engine(["--headless", "--path", ".", "--script", "tests/world/elements.gd"], 220)
if not re.search(r"^WORLD ELEMENTS: [1-9]\d* assertions, 0 failures$", output, re.MULTILINE):
    raise RuntimeError("Element tests did not complete cleanly")
