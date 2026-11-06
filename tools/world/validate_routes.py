"""Re-run supplied graph/state checks in build/, preserving the imported snapshot."""
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'docs/data/world/import-v04'
OUT = ROOT / 'build/world/validation'


def main():
    shutil.copytree(SOURCE, OUT, dirs_exist_ok=True)
    for script in ['simulation/simulate_world.py', 'simulation/audit_contracts.py',
                   'simulation/analyze_replays.py', 'design/build_room_contracts_v04.py', 'build_handoff.py']:
        subprocess.run([sys.executable, str(OUT / script)], cwd=OUT, check=True)
    for name in ['simulation/contract-audit-v04.json', 'qa/room-contract-audit-v04.json', 'qa/final-data-integrity-v04.json']:
        if json.loads((OUT / name).read_text()).get('passed') is not True:
            raise ValueError('Failed generated audit: ' + name)
    # Rebuilding the transitional contracts must not silently change the supplied interfaces.
    for name in ['design/room-graybox-contracts-v04.json', 'simulation/route-replays-v04.json']:
        if json.loads((OUT / name).read_text()) != json.loads((SOURCE / name).read_text()):
            raise ValueError('Rebuild differs from imported snapshot: ' + name)
    print('PASS: fresh A/B/C/D graph routes, counterfactuals, state receipts and equivalent transitional contracts; NOT Godot playability')


if __name__ == '__main__':
    main()
