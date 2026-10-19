"""Actual20 producer contracts only; not Motor traversal or experience approval."""
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
    directory = args.output.resolve()
    if not directory.is_relative_to(ROOT / 'build') or directory.exists():
        parser.error('Fresh output below repository build required')
    directory.mkdir(parents=True)
    report_path = directory / 'report.json'
    run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
    output = run_engine(['--headless', '--path', '.', '--script',
                         'tests/forest_interwoven_contract_runner.gd', '--',
                         '--output=res://' + str(report_path.relative_to(ROOT))], 90)
    if not re.search(r'^FOREST INTERWOVEN CONTRACT: [1-9]\d* checks / 0 failures$', output, re.M):
        raise RuntimeError('Missing complete interwoven producer contract result')
    data = json.loads(report_path.read_text())
    if (data.get('scope') != 'real20producer_contracts_not_Motor_or_fun'
            or data.get('failures') != 0 or len(data.get('cases', [])) != 20
            or not data.get('checks') or any(row.get('passed') is not True for row in data['checks'])):
        raise RuntimeError('Incomplete actual20 producer contract output')
    print('PASS: actual20 interwoven producer contracts, not Motor or experience approval')


if __name__ == '__main__':
    main()
