"""Fresh native forest actor fixtures; refuses script errors and unclean exit."""
import argparse
import hashlib
import json
from pathlib import Path
import re
from run_tests import run_engine
ROOT = Path(__file__).resolve().parent.parent

def inventory():
    sources = sorted([*ROOT.glob('scripts/enemies/forest_*.gd'), *ROOT.glob('scripts/bosses/thorn_*.gd'), *ROOT.glob('resources/enemies/forest_*.tres'), *ROOT.glob('resources/bosses/thorn_*.tres'), ROOT/'scripts/enemies/enemy_actor.gd', ROOT/'scripts/enemies/enemy_definition.gd', ROOT/'tests/forest_ecology_runner.gd',
                      *(p for p in (ROOT/'game').rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc')])
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output-dir', default='build/forest_playable/ecology/native')
    args = parser.parse_args()
    out = ROOT / args.output_dir
    if not out.resolve().is_relative_to((ROOT/'build/forest_playable/ecology').resolve()):
        parser.error('output must be under build/forest_playable/ecology')
    out.mkdir(parents=True, exist_ok=True)
    if (out/'capture.json').exists():
        parser.error('fresh output required; retain previous capture')
    (out/'sources.json').write_text(json.dumps(inventory(),indent=2))
    output = run_engine(['--headless', '--fixed-fps', '60', '--path', '.', '--script', 'tests/forest_ecology_runner.gd', '--', f'--output-dir=res://{out.relative_to(ROOT)}'], 180)
    (out/'native.log').write_text(output)
    if not re.search(r'^FOREST ECOLOGY: [1-9]\d* assertions, 0 failures$', output,re.M):
        raise RuntimeError('native zero-failure completion missing')
if __name__ == '__main__':
    main()
