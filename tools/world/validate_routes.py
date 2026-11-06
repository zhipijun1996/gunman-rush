"""Re-run current graph/state checks in build/; no imported generator dependency."""
import json
from pathlib import Path
import subprocess
import sys
from build import build
from compile_contracts import compile_contracts, write_json
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/world/validation'


def main():
    (OUT/'simulation').mkdir(parents=True, exist_ok=True)
    for name in ['simulate_world.py','audit_contracts.py','analyze_replays.py']:
        subprocess.run([sys.executable,str(ROOT/'tools/world'/name)],cwd=ROOT,check=True)
    contracts, audit = compile_contracts(ROOT/'config/world/world.json',ROOT/'config/world/construction.json',OUT/'simulation/route-replays-v04.json')
    write_json(OUT/'contracts.json',contracts)
    if not audit['passed'] or not json.loads((OUT/'simulation/contract-audit-v04.json').read_text())['passed']:
        raise ValueError('Route/contract audit failed')
    build()
    print('PASS: fresh A/B/C/D graph routes, counterfactuals, state receipts and current construction contracts; NOT Godot playability')

if __name__ == '__main__':main()
