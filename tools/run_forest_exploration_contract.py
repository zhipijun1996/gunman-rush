"""Focused v16 contracts; full routes, visual quality and device approval stay separate."""
import argparse
import contextlib
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

from forest_bible_world_sources import SOURCE_ROOTS, inventory
from run_tests import run_engine

ROOT = Path(__file__).resolve().parents[1]
CAP_SECONDS = 90


def save(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')


def git(*arguments):
    return subprocess.check_output(['git', *arguments], cwd=ROOT)


def changed_sources():
    # HEAD comparison also includes staged changes; ls-files adds untracked files.
    roots = ['project.godot', *SOURCE_ROOTS]
    tracked = git('diff', '--name-only', '-z', 'HEAD', '--', *roots)
    working = git('ls-files', '-m', '-o', '--exclude-standard', '-z', '--', *roots)
    return sorted(set(name for name in (tracked + working).decode().split('\0') if name))


def archive_sources(folder, sources, names, previous=None):
    """Copy only changed/untracked bytes; identical after-state reuses the before copy."""
    archived = {}
    for name in sorted(set(names)):
        if name not in sources:
            archived[name] = {'status': 'deleted_or_outside_source_inventory'}
            continue
        prior = (previous or {}).get(name, {})
        if prior.get('sha256') == sources[name]:
            archived[name] = prior
            continue
        source = ROOT / name
        if any(path.is_symlink() for path in [source, *source.parents] if path.is_relative_to(ROOT)):
            raise ValueError('Changed source cannot be archived through a symlink: ' + name)
        target = folder / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        with target.open('rb') as stream:
            actual = hashlib.file_digest(stream, 'sha256').hexdigest()
        if actual != sources[name]:
            raise RuntimeError('Source changed while archiving: ' + name)
        archived[name] = {'path': target.relative_to(folder.parent).as_posix(), 'sha256': actual,
                          'bytes': target.stat().st_size}
    return archived


def execute(output, name, arguments, marker=None, report=None):
    log = output / (name + '.log')
    entry = {'id': name, 'argv': ['bash', 'tools/godot.sh', *arguments],
             'timeout_seconds': CAP_SECONDS, 'passed': False, 'log': log.name}
    started = time.monotonic()
    try:
        # run_engine streams every native chunk before it raises, including timeouts.
        with log.open('w') as stream, contextlib.redirect_stdout(stream), contextlib.redirect_stderr(stream):
            text = run_engine(arguments, CAP_SECONDS)
        if marker and len(re.findall(marker, text, re.M)) != 1:
            raise RuntimeError('Missing or nonunique exact completion marker')
        if report is not None:
            data = json.loads(report.read_text())
            if (not isinstance(data, dict) or type(data.get('assertions')) is not int
                    or data['assertions'] <= 0 or type(data.get('failures')) is not int or data['failures'] != 0):
                raise RuntimeError('Missing or failed nonempty native report')
            if marker and re.search(marker, text, re.M).group(1) != str(data['assertions']):
                raise RuntimeError('Native report and completion assertion counts differ')
            entry['report'] = report.relative_to(output).as_posix()
            entry['report_sha256'] = hashlib.sha256(report.read_bytes()).hexdigest()
        entry.update(passed=True, exit_code=0)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        entry.update(exit_code=1, error_type=type(error).__name__, error=str(error))
        with log.open('a') as stream:
            stream.write('\nWRAPPER FAILURE: ' + repr(error) + '\n')
    finally:
        entry['seconds'] = round(time.monotonic() - started, 3)
        if log.is_file():
            entry['log_sha256'] = hashlib.sha256(log.read_bytes()).hexdigest()
    return entry


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args(argv)
    output = args.output_dir.absolute()
    if (not output.is_relative_to(ROOT / 'build') or output.exists()
            or any(path.is_symlink() for path in [output, *output.parents] if path.is_relative_to(ROOT))):
        parser.error('A fresh ordinary directory below repository build/ is required')
    if '..' in output.parts:
        parser.error('Output path cannot contain parent traversal')
    output.mkdir(parents=True)
    started = time.monotonic()
    receipt = {'schema_version': 1, 'scope': 'focused_modules_world_corridor_borrow_pod_and_actual_menu_contracts',
               'limits': 'Not complete map traversal, formal reward transactions, visual/FUN/device or release acceptance.',
               'fixed_fps': 60, 'timeout_seconds_each': CAP_SECONDS, 'checks': [], 'exit_code': 1}
    before = None
    names = []
    archived = {}
    try:
        receipt['baseline_head'] = git('rev-parse', 'HEAD').decode().strip()
        before = inventory()
        save(output / 'source-before.json', before)
        names = changed_sources()
        archived = archive_sources(output / 'source-snapshot-before', before, names)
        save(output / 'source-bytes-before.json', {'baseline_head': receipt['baseline_head'], 'files': archived})
        receipt['checks'].append(execute(output, 'import', ['--headless', '--path', '.', '--editor', '--quit']))
        jobs = [
            ('modules', 'tests/forest_exploration_modules_runner.gd',
             r'^FOREST EXPLORATION MODULES: ([1-9]\d*) assertions, 0 failures$',
             ['--output=res://' + (output / 'modules/report.json').relative_to(ROOT).as_posix()], output / 'modules/report.json'),
            ('world', 'tests/forest_exploration_world_runner.gd',
             r'^FOREST EXPLORATION WORLD: ([1-9]\d*) assertions, 0 failures$', [], None),
            ('corridor', 'tests/forest_thorn_corridor_modules_runner.gd',
             r'^FOREST THORN CORRIDORS: ([1-9]\d*) assertions, 0 failures$',
             ['--output-dir=res://' + (output / 'corridor').relative_to(ROOT).as_posix()], output / 'corridor/report.json'),
            ('borrow-pod', 'tests/forest_exploration_ecology_runner.gd',
             r'^FOREST EXPLORATION ECOLOGY: ([1-9]\d*) assertions, 0 failures$',
             ['--borrow-pod-only', '--output-dir=res://' + (output / 'borrow-pod').relative_to(ROOT).as_posix()], output / 'borrow-pod/report.json'),
            ('menu', 'tests/forest_exploration_menu_runner.gd',
             r'^FOREST EXPLORATION MENU: ([1-9]\d*) assertions, 0 failures$', [], None),
        ]
        for name, script, marker, extra, report in jobs:
            arguments = ['--headless', '--fixed-fps', '60', '--path', '.', '--script', script]
            if extra:
                arguments += ['--', *extra]
            receipt['checks'].append(execute(output, name, arguments, marker, report))
            save(output / 'receipt.json', receipt)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        receipt['error'] = repr(error)
    finally:
        try:
            after = inventory()
            save(output / 'source-after.json', after)
            receipt['head_after'] = git('rev-parse', 'HEAD').decode().strip()
            receipt['source_stable'] = (before is not None and before == after
                                        and receipt.get('baseline_head') == receipt['head_after'])
            drift = ({name for name in set(before) | set(after) if before.get(name) != after.get(name)}
                     if before is not None else set())
            after_names = set(names) | set(changed_sources()) | drift
            after_archived = archive_sources(output / 'source-snapshot-after', after, after_names, archived)
            save(output / 'source-bytes-after.json', {'baseline_head': receipt.get('baseline_head'), 'files': after_archived})
            receipt['exit_code'] = 0 if (receipt['source_stable'] and 'error' not in receipt
                                                and len(receipt['checks']) == 6
                                                and all(row['passed'] for row in receipt['checks'])) else 1
        except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
            receipt.update(source_stable=False, exit_code=1, finalization_error=repr(error))
        receipt['seconds'] = round(time.monotonic() - started, 3)
        save(output / 'receipt.json', receipt)
    if receipt['exit_code'] == 0:
        print('PASS: forest exploration contracts')
    else:
        print('FAIL: forest exploration contracts; see ' + str(output / 'receipt.json'), file=sys.stderr)
    return receipt['exit_code']


if __name__ == '__main__':
    sys.exit(main())
