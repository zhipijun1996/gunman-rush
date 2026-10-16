import json
from pathlib import Path
reports = sorted(Path('build/verification/harness').glob('*/report.json'))
if reports:
    report = reports[-1]
    for check in json.loads(report.read_text()).get('checks', []):
        if check.get('status') != 'failed':
            continue
        log = (report.parent / check['log']).resolve()
        if log.is_relative_to(report.parent.resolve()) and log.is_file():
            print('Failed check:', check['id'])
            print('\n'.join(log.read_text(errors='replace').splitlines()[-100:]))
