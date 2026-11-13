"""Exercise real element routing, persistence, lifecycle and room migration."""
import re
import subprocess
import sys
from run_tests import run_engine
subprocess.run([sys.executable, "tools/check_element_registry.py"], check=True)
for script, marker in [("element_registry.gd", "ELEMENT REGISTRY RUNTIME"), ("elements.gd", "WORLD ELEMENTS")]:
    output = run_engine(["--headless", "--path", ".", "--script", "tests/world/" + script], 220)
    if re.search(r"^ERROR:", output, re.MULTILINE) or not re.search(
        rf"^{marker}: [1-9]\d* (?:assertions|checks), 0 failures$", output, re.MULTILINE
    ):
        raise RuntimeError("Element tests did not complete cleanly: " + script)
