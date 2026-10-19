"""New foundation behavior checks, including actual sample Motor traversal."""
import re
import subprocess
from run_tests import run_engine

subprocess.run(['python3', 'tools/build_blob47_art.py', '--check'], check=True)
for runner, marker in [('tests/test_blob47_layout.gd', 'BLOB47_LAYOUT'),
                       ('tests/test_blob47_foundation.gd', 'BLOB47_FOUNDATION')]:
    output = run_engine(['--headless', '--fixed-fps', '60', '--path', '.', '--script', runner], 90)
    if not re.search(r'^' + marker + r' checks=[1-9]\d* failures=0', output, re.M):
        raise RuntimeError('Missing successful completion: ' + marker)
print('PASS: blob47 foundation, atlas, semantic modules, decoration and real sample Motor')
