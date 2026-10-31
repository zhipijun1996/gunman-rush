"""Run isolated five-style real TileMap/Motor checks; preserve each native log."""
from __future__ import annotations
import argparse
import contextlib
import datetime
import json
from pathlib import Path
import re
import subprocess
import sys
from run_tests import run_engine

ROOT = Path(__file__).resolve().parent.parent


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path)
    parser.add_argument('--capture', action='store_true', help='Use current DISPLAY for 36 region/seed scenes and nine actual palette atlas catalogs')
    parser.add_argument('--skip-import', action='store_true')
    parser.add_argument('--biomes-only', action='store_true', help='Check presentation-only region switches without repeating unchanged Motor routes')
    args = parser.parse_args()
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    output = (args.output or ROOT / 'build/style_exploration' / stamp).resolve()
    output.mkdir(parents=True, exist_ok=True)
    records = []
    def run(name: str, command_args: list[str], timeout: int = 180, marker: str | None = None) -> None:
        log_path = output / f'{name}.log'
        record = {'name': name, 'command': ['bash', 'tools/godot.sh', *command_args], 'log': str(log_path.relative_to(ROOT)), 'passed': False}
        records.append(record)
        try:
            with log_path.open('w') as log, contextlib.redirect_stdout(log), contextlib.redirect_stderr(log):
                text = run_engine(command_args, timeout)
                if marker and not re.search(marker, text, re.M):
                    raise RuntimeError('Missing successful completion marker: ' + marker)
            record['passed'] = True
            print(f'PASS {name}: {log_path.relative_to(ROOT)}')
        except Exception as exc:
            record['error'] = str(exc)
            (output / 'summary.json').write_text(json.dumps(records, indent=2))
            raise
        (output / 'summary.json').write_text(json.dumps(records, indent=2))
    if not args.skip_import:
        run('import', ['--headless', '--path', '.', '--editor', '--quit'], 240)
    if not args.biomes_only:
        report = output / 'runtime_report.json'
        run('runtime', ['--headless', '--fixed-fps', '60', '--path', '.', '--script', 'tests/style_exploration/test_style_exploration.gd', '--', f'--report={report}'], 180, r'^STYLE_EXPLORATION checks=[1-9]\d* failures=0 routes=20$')
    report = output / 'biome_report.json'
    run('biomes', ['--headless', '--fixed-fps', '60', '--path', '.', '--script', 'tests/style_exploration/test_style_biomes.gd', '--', f'--report={report}'], 120, r'^STYLE_BIOMES checks=[1-9]\d* failures=0 variants=16$')
    for style, requested_biome, admitted_biome in [('underworld', 'gear', 'gear'), ('cavern', 'forest', 'forest'), ('basic', 'forest', 'plains')]:
        run(f'cli_{style}_{requested_biome}', ['--headless', '--path', '.', '--script', 'tests/style_exploration/test_style_biome_cli.gd', '--', f'--style={style}', f'--biome={requested_biome}', f'--expect-style={style}', f'--expect-biome={admitted_biome}'], 45, r'^STYLE_BIOME_CLI .* failures=0$')
    if args.capture:
        for style in ('retro', 'basic', 'scribble', 'underworld', 'cavern'):
            biomes = ('plains', 'forest', 'gear') if style in ('underworld', 'cavern') else ('plains',)
            for biome in biomes:
                for sample in range(4):
                    image = output / f'{style}_{biome}_sample{sample}.png'
                    run(f'capture_{style}_{biome}_{sample}', ['--audio-driver', 'Dummy', '--path', '.', '--resolution', '1280x720', 'res://experiments/terrain/entries/style_lab.tscn', '--', f'--style={style}', f'--biome={biome}', f'--sample={sample}', f'--capture={image}'], 60, r'^STYLE_CAPTURE .* error=0$')
                image = output / f'{style}_{biome}_tileset.png'
                run(f'catalog_{style}_{biome}', ['--audio-driver', 'Dummy', '--path', '.', '--resolution', '1280x720', 'res://experiments/terrain/entries/style_lab.tscn', '--', f'--style={style}', f'--biome={biome}', '--sample=0', '--catalog', f'--capture={image}'], 60, r'^STYLE_CAPTURE .* error=0$')
    print(f'Validated runtime evidence: {output}')


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print(f'Style exploration failed: {exc}', file=sys.stderr)
        sys.exit(1)
