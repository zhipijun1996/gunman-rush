"""Bounded real Windkeeper components and formal App regressions.

All positioning, phase/group and clock fixtures are disclosed by each consumer.
This runner cannot certify a natural full battle, subjective quality or devices.
"""
import json
from datetime import datetime, timezone
from pathlib import Path
import re
from run_tests import run_engine

CASES = (
    ('geometry', 'tests/windkeeper_pressure_01/attack_geometry.gd', r'WINDKEEPER PRESSURE ATTACK GEOMETRY: \d+ checks, 0 failures'),
    ('components', 'tests/windkeeper_pressure_01/component_clock.gd', r'WINDKEEPER PRESSURE COMPONENT CLOCK: \d+ checks, 0 failures'),
    ('formal', 'tests/windkeeper_pressure_01/formal_app.gd', r'WINDKEEPER PRESSURE FORMAL APP: \d+ checks, 0 failures'),
    ('support', 'tests/windkeeper_pressure_01/support_app.gd', r'WINDKEEPER PRESSURE SUPPORT APP: \d+ checks, 0 failures'),
    ('rewards', 'tests/windkeeper_pressure_01/rewards.gd', r'WINDKEEPER PRESSURE REWARDS: \d+ checks, 0 failures'),
    ('audio', 'tests/windkeeper_pressure_01/audio.gd', r'WINDKEEPER_PRESSURE_AUDIO assertions=\d+ failures=0'),
)

def main():
    # Keep prior native failures and receipts; later green runs never replace
    # the raw consumers which exposed an earlier defect.
    folder = Path('build/windkeeper_pressure_01/regression') / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    folder.mkdir(parents=True, exist_ok=True)
    imported = run_engine(['--headless', '--path', '.', '--editor', '--import', '--quit'], 90)
    (folder/'editor.log').write_text(imported)
    if re.search(r'(?m)^ERROR:', imported):
        raise RuntimeError('Native import error')
    rows = []
    for name, script, marker in CASES:
        result = run_engine(['--headless', '--fixed-fps', '60', '--path', '.', '--script', script], 90)
        (folder/(name+'.log')).write_text(result)
        if re.search(r'(?m)^ERROR:|RID allocations.*leaked', result):
            raise RuntimeError('Native error in '+name)
        if not re.search('^'+marker+'$', result, re.MULTILINE):
            raise RuntimeError('Missing complete result for '+name)
        rows.append({'case':name,'script':script,'status':'passed'})
    (folder/'report.json').write_text(json.dumps({'cases':rows,'status':'passed',
        'scope':'Actual components and controlled formal map2 App; not natural fight or subjective/device approval'},indent=2)+'\n')
    print('WINDKEEPER PRESSURE REGRESSION: six native consumers, 0 failures')

if __name__ == '__main__':
    main()
