"""Actual CLI-builder unit probe, no engine/worker and no content acceptance."""
from pathlib import Path
import json
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'tools'))
import level_formal as f
request = dict(source_commit='a'*40, root_seed='UNIT-NOT-RUNTIME', strategy='deep', map_index=2, phase_wait_ticks=0, max_ticks=18000, encounter_policy='kill_from_bank_v2')
command = f.command_for(request, f.ROOT / 'build/region_production_v3/kill_bank_v2/never_executed_unit_capture.json')
assert '--encounter-policy=kill_from_bank_v2' in command
rejected = False
try:
    f.command_for(dict(request, encounter_policy='kill_from_bank_v99'), f.ROOT / 'build/region_production_v3/kill_bank_v2/never_executed_unit_capture.json')
except ValueError:
    rejected = True
assert rejected
print(json.dumps({'scope':'Actual pure CLI-builder positive/unknown-policy negative; no Godot invocation', 'v2_explicit_command_accepted':True, 'unknown_policy_rejected':rejected}))
