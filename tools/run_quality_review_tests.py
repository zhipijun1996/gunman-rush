"""Run supplementary actual-engine invariant probes; not player acceptance."""
from run_tests import run_engine
import re
run_engine(['--headless','--path','.','--editor','--quit'],90)
text=run_engine(['--headless','--fixed-fps','60','--path','.','--script','tests/quality_review_runner.gd'],120)
if not re.search(r'^QUALITY REVIEW: [1-9]\d* assertions, 0 failures$',text,re.M):
    raise RuntimeError('Missing quality-review completion')
print('PASS: quality review engine regression')
