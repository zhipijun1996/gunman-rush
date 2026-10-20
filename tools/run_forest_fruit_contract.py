"""V14 candidate contract and target eligibility; not Motor or art acceptance."""
import argparse
import json
from pathlib import Path
import re

from run_tests import run_engine

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if not output.is_relative_to(ROOT / 'build') or output.exists():
        parser.error('Fresh output below repository build required')
    output.mkdir(parents=True)
    report = output / 'report.json'
    run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
    text = run_engine(['--headless', '--path', '.', '--script',
                       'tests/forest_fruit_contract_runner.gd', '--',
                       '--output=res://' + report.relative_to(ROOT).as_posix()], 90)
    data = json.loads(report.read_text())
    if (not re.search(r'^FOREST FRUIT CONTRACT: [1-9]\d* checks / 0 failures$', text, re.M)
            or data.get('failures') != 0 or len(data.get('cases', [])) != 20
            or not data.get('checks') or any(row.get('passed') is not True for row in data['checks'])):
        raise RuntimeError('Incomplete or failed v14 candidate contracts')
    print('PASS: v14 candidate contracts; no Motor or visual acceptance claim')


if __name__ == '__main__':
    main()
