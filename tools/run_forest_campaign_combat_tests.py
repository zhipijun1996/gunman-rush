"""Fresh formal forest traversal-to-combat; keeps debug entry and GUI limits explicit."""
import argparse
import hashlib
import json
from pathlib import Path
import re
from datetime import datetime, timezone
from run_tests import run_engine
ROOT = Path(__file__).resolve().parent.parent

def inventory():
    sources = sorted({*ROOT.glob('scripts/**/*.gd'), *ROOT.glob('resources/**/*.tres'), *ROOT.glob('scenes/**/*.tscn'), *ROOT.glob('config/*.json'), ROOT / 'tests/forest_campaign_combat_runner.gd', ROOT / 'tests/forest_region_trace.gd', Path(__file__).resolve(),
                      *(p for directory in ('game','experiments') for p in (ROOT/directory).rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc')})
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output-dir')
    parser.add_argument('--map', type=int, choices=[1, 2])
    parser.add_argument('--seed', default='forest-playable-00')
    args = parser.parse_args()
    out = ROOT / (args.output_dir or "build/forest_playable/progression/formal_combat_" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ"))
    if not out.resolve().is_relative_to((ROOT / 'build/forest_playable/progression').resolve()):
        parser.error('output must be under build/forest_playable/progression')
    out.mkdir(parents=True, exist_ok=True)
    if (out / 'capture.json').exists():
        parser.error('fresh output required; retain earlier capture')
    before = inventory()
    (out / 'sources.json').write_text(json.dumps(before, indent=2))
    command = ['--headless', '--fixed-fps', '60', '--path', '.', '--script', 'tests/forest_campaign_combat_runner.gd', '--', f'--output-dir=res://{out.relative_to(ROOT)}', f'--seed={args.seed}']
    if args.map:
        command.append(f'--map={args.map}')
    output = run_engine(command, 240)
    (out / 'native.log').write_text(output)
    if not re.search(r'^FOREST CAMPAIGN COMBAT: [1-9]\d* assertions / 0 failures$', output, re.M):
        raise RuntimeError('formal combat zero-failure completion missing')
    capture = json.loads((out / 'capture.json').read_text())
    if capture.get('failures') != 0 or not capture.get('cases'):
        raise RuntimeError('formal combat actual capture failed or missing')
    after = inventory()
    if after != before:
        raise RuntimeError('formal combat sources changed during actual capture')
    print('PASSED: formal_DemoApp_forest_combat')

if __name__ == '__main__':
    main()
