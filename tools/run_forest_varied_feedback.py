"""V17 development feedback: preserve old entry and exercise actual added loops.

This proves selected technical paths only. Art, meaningful library size, generated
map identity, FUN and devices remain independent; this is never a release gate.
"""
import argparse
import contextlib
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time

from forest_bible_world_sources import inventory
from run_forest_exploration_contract import archive_sources, changed_sources, git, save
from run_tests import run_engine

ROOT = Path(__file__).resolve().parents[1]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', required=True, type=Path)
    args = parser.parse_args(argv)
    output = args.output_dir.absolute()
    if (not output.is_relative_to(ROOT / 'build') or output.exists() or '..' in output.parts
            or any(p.is_symlink() for p in [output, *output.parents] if p.is_relative_to(ROOT))):
        parser.error('Use a fresh ordinary directory under build/')
    output.mkdir(parents=True)
    started = time.monotonic()
    receipt = {'scope': __doc__, 'import_cap_seconds': 90, 'native_cap_seconds': 240,
               'whole_cap_seconds': 600, 'fixed_fps': 60, 'workers': 1, 'checks': [], 'exit_code': 1}
    before = None
    try:
        receipt['baseline_head'] = git('rev-parse', 'HEAD').decode().strip()
        before = inventory()
        save(output / 'source-before.json', before)
        archived = archive_sources(output / 'source-snapshot-before', before, changed_sources())
        save(output / 'source-bytes-before.json', {'baseline_head': receipt['baseline_head'], 'files': archived})
        jobs = [('import', None, [], '', 90),
                ('world', 'tests/forest_varied_world_runner.gd', [], r'^FOREST VARIED WORLD: [1-9]\d* assertions, 0 failures /', 240),
                ('menu', 'tests/forest_varied_menu_runner.gd', [], r'^FOREST EXPANDED MENU: [1-9]\d* assertions, 0 failures$', 240)]
        for name, route, map_index, fixture, extra in [
                ('old_HH', 'varied_original_entry_trial', 1, False, []),
                ('old_spiral', 'varied_original_skill_trial', 1, False, []),
                ('annex', 'varied_annex_journey', 1, False, []),
                ('L_journey', 'varied_l_journey', 2, False, []),
                ('L_notes_and_far_exit', 'varied_l_onward_trial', 1, True, ['--reward-index=1'])]:
            script = 'tests/forest_varied_fixture_runner.gd' if fixture else 'tests/forest_varied_motor_runner.gd'
            marker = r'^FOREST VARIED FIXTURE: PASS /' if fixture else r'^FOREST VARIED MOTOR: PASS /'
            jobs.append((name, script, [f'--map={map_index}', '--seed=forest-variety-00', '--route='+route, *extra], marker, 240))
        for name, script, extra, marker, cap in jobs:
            remaining = 600 - (time.monotonic() - started)
            if remaining <= 0:
                raise TimeoutError('Original 600 second whole feedback budget exceeded')
            native_report = output / (name + '.json')
            log = output / (name + '.log')
            arguments = ['--headless', '--path', '.']
            if script:
                arguments += ['--fixed-fps', '60', '--script', script]
                if name != 'menu':
                    arguments += ['--', *extra, '--output=res://' + native_report.relative_to(ROOT).as_posix()]
            else:
                arguments += ['--editor', '--quit']
            row = {'id': name, 'argv': ['bash', 'tools/godot.sh', *arguments], 'passed': False,
                   'timeout_seconds': min(cap, remaining), 'log': log.name}
            receipt['checks'].append(row)
            t = time.monotonic()
            try:
                with log.open('w') as stream, contextlib.redirect_stdout(stream), contextlib.redirect_stderr(stream):
                    text = run_engine(arguments, min(cap, remaining))
                if marker and len(re.findall(marker, text, re.M)) != 1:
                    raise RuntimeError('Missing or nonunique native completion marker')
                if script and name != 'menu':
                    data = json.loads(native_report.read_text())
                    if data.get('failures') != []:
                        raise RuntimeError('Native report is missing or contains failures')
                    if name == 'world':
                        if type(data.get('assertions')) is not int or data['assertions'] <= 0 or len(data.get('samples', [])) != 20:
                            raise RuntimeError('Actual 20-world structure/replay corpus missing')
                    elif (data.get('passed') is not True or not data.get('frames')
                          or len(data.get('completed', [])) != len(data.get('itinerary', []))
                          or any(f.get('motor_steps') != 1 for f in data['frames'])
                          or data.get('midroute_injection') is not False or data.get('resource_override') is not False):
                        raise RuntimeError('Actual complete single-Motor path proof missing')
                    row['report'] = native_report.name
                    row['report_sha256'] = hashlib.sha256(native_report.read_bytes()).hexdigest()
                row.update(passed=True, exit_code=0)
            except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
                row.update(exit_code=1, error=repr(error))
                raise
            finally:
                row['seconds'] = round(time.monotonic() - t, 3)
                if log.is_file(): row['log_sha256'] = hashlib.sha256(log.read_bytes()).hexdigest()
                save(output / 'receipt.json', receipt)
        receipt['exit_code'] = 0
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        receipt.update(exit_code=1, error=repr(error))
    finally:
        after = inventory()
        save(output / 'source-after.json', after)
        receipt['source_stable'] = before is not None and before == after and receipt.get('baseline_head') == git('rev-parse', 'HEAD').decode().strip()
        if not receipt['source_stable']: receipt['exit_code'] = 1
        receipt['seconds'] = round(time.monotonic() - started, 3)
        save(output / 'receipt.json', receipt)
    print(('PASS' if receipt['exit_code'] == 0 else 'FAIL') + ': forest varied development feedback')
    return receipt['exit_code']


if __name__ == '__main__':
    sys.exit(main())
