"""Run unchanged historical forest v1 checks in exact bee850c sources.

Explicit checks only. A pass here is NEVER forest v2 acceptance or full harness
approval. Original native logs/captures remain under OUTPUT/fixture/project/build.
"""
import argparse
import fcntl
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys
import time

from forest_legacy_fixture import BASIS, CHECK_IDS, ROOT, no_symlinks, original_checks, restore, safe_path, verify


def evidence_destination(output, destination, root=None):
    root = no_symlinks(root or ROOT).resolve()
    output = no_symlinks(output).resolve()
    destination = no_symlinks(destination).resolve()
    if not destination.is_relative_to(root / 'build') or destination.exists():
        raise ValueError('Fresh evidence output below repository build/ required')
    if destination == output or destination.is_relative_to(output) or output.is_relative_to(destination):
        raise ValueError('Evidence output must not overlap the full fixture output')
    return destination


def copy_evidence(output, destination, report, root=None):
    """Transfer only authenticated terminal logs/JSON; retain the full fixture."""
    root = no_symlinks(root or ROOT).resolve()
    output = no_symlinks(output).resolve()
    destination = evidence_destination(output, destination, root)
    if not output.is_relative_to(root / 'build') or not output.is_dir():
        raise ValueError('Evidence source must be an existing full output below build/')
    report_path = no_symlinks(output / 'report.json')
    report_bytes = report_path.read_bytes()
    if json.loads(report_bytes) != report or not isinstance(report.get('evidence_files'), dict):
        raise ValueError('Terminal report differs from the supplied evidence ledger')
    selected = {'report.json': hashlib.sha256(report_bytes).hexdigest()}
    for name, expected in report['evidence_files'].items():
        relative = safe_path(name)
        outer_log = len(relative.parts) == 1 and relative.suffix == '.log'
        inner_result = relative.parts[:3] == ('fixture', 'project', 'build') and relative.suffix in ('.log', '.json')
        if not (outer_log or inner_result):
            continue
        if any(part in ('assets', '.godot', 'source') for part in relative.parts):
            raise ValueError('Source/assets/cache cannot be evidence outputs: ' + name)
        if not isinstance(expected, str) or len(expected) != 64 or any(c not in '0123456789abcdef' for c in expected):
            raise ValueError('Invalid evidence fingerprint: ' + name)
        selected[name] = expected
    # Root logs must not disappear from the authenticated terminal ledger.
    if any(p.name not in selected for p in output.glob('*.log')):
        raise ValueError('Outer log missing from terminal evidence ledger')
    for name, expected in selected.items():
        source = no_symlinks(output / name)
        if not source.resolve().is_relative_to(output) or not source.is_file():
            raise ValueError('Evidence source is not a regular file within its output: ' + name)
        if hashlib.sha256(source.read_bytes()).hexdigest() != expected:
            raise ValueError('Evidence fingerprint differs: ' + name)
    destination.mkdir(parents=True)
    receipt = {'schema_version': 1, 'scope': 'historical_v1_evidence_transfer_only_not_v2_or_release',
               'source_output': str(output), 'status': 'running', 'files': {}}
    try:
        for name, expected in selected.items():
            source = no_symlinks(output / name)
            target = no_symlinks(destination / name)
            target.parent.mkdir(parents=True, exist_ok=True)
            with source.open('rb') as incoming, target.open('xb') as outgoing:
                shutil.copyfileobj(incoming, outgoing)
            copied = hashlib.sha256(target.read_bytes()).hexdigest()
            actual = hashlib.sha256(no_symlinks(source).read_bytes()).hexdigest()
            if actual != expected or copied != expected:
                raise ValueError('Evidence changed during transfer: ' + name)
            receipt['files'][name] = {'source_sha256': actual, 'copied_sha256': copied, 'bytes': target.stat().st_size}
        receipt['status'] = 'passed'
    except Exception as error:
        receipt['status'] = 'failed'
        receipt['error'] = type(error).__name__ + ': ' + str(error)
        raise
    finally:
        with no_symlinks(destination / 'evidence-receipt.json').open('x') as handle:
            handle.write(json.dumps(receipt, indent=2) + '\n')
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='append', choices=CHECK_IDS, required=True)
    parser.add_argument('--output', type=Path, required=True, help='fresh directory below repository build/')
    parser.add_argument('--evidence-output', type=Path, help='optional fresh build/ directory for logs/JSON only; full fixture is retained')
    args = parser.parse_args()
    output = no_symlinks(args.output).resolve()
    if not output.is_relative_to(ROOT / 'build') or output.exists():
        parser.error('Fresh output below repository build/ required; old evidence is retained')
    if args.evidence_output is not None:
        args.evidence_output = evidence_destination(output, args.evidence_output)
    output.mkdir(parents=True)
    report = {'schema_version': 1, 'scope': 'historical_forest_v1_only_not_current_v2',
              'source_commit': None, 'current_v2_covered': False, 'full_harness_approval': False,
              'status': 'running', 'checks': {}, 'requested_checks': args.check,
              'started_at_unix': time.time()}
    path = output / 'report.json'
    def save():
        path.write_text(json.dumps(report, indent=2) + '\n')
    save()
    try:
        project, manifest = restore(ROOT, output / 'fixture', BASIS)
        report['source_commit'] = manifest['source_commit']
        report['manifest_sha256'] = hashlib.sha256((BASIS / 'manifest.json').read_bytes()).hexdigest()
        report['inner_evidence_root'] = str(project / 'build')
        # Load the actual original harness implementation, not its current v2
        # replacement. Preserve run_check's caps, markers and process cleanup.
        spec = importlib.util.spec_from_file_location('forest_v1_original_harness', project / 'tools/harness.py')
        harness = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(harness)
        env = dict(os.environ)
        for key in list(env):
            if key.startswith('GIT_'):
                del env[key]
        env['GUNMAN_TOOLCHAIN_ROOT'] = os.environ.get('GUNMAN_TOOLCHAIN_ROOT', str(ROOT.parent / 'toolchains'))
        for key, relative in {'GUNMAN_DATA_HOME': 'user-data', 'XDG_CONFIG_HOME': 'config',
                              'XDG_CACHE_HOME': 'cache'}.items():
            env[key] = str(output / relative)
        env['GUNMAN_ENGINE_LOCK'] = str(project / 'build/verification/engine.lock')
        lock = ROOT / 'build/verification/engine.lock'
        lock.parent.mkdir(parents=True, exist_ok=True)
        with lock.open('a') as handle:
            fcntl.flock(handle, fcntl.LOCK_EX)
            # Same import argv/cap/marker as the archived H-slice import.
            config = {'argv': ['bash', 'tools/godot.sh', '--headless', '--path', '.', '--editor', '--quit'],
                      'timeout_seconds': 90, 'success_pattern': r'Godot Engine v4\.7\.2'}
            report['import_config'] = config
            report['import'] = harness.run_check(config, output / 'import.log', root=project, env=env)
            save()
            if report['import']['status'] != 'passed':
                raise RuntimeError('Exact v1 import failed; original log retained')
            for name in dict.fromkeys(args.check):
                verify(project, manifest)
                config = original_checks(project, manifest)[name]
                result = harness.run_check(config, output / (name + '.log'), root=project, env=env)
                report['checks'][name] = {'config': config, **result}
                verify(project, manifest)
                save()
                if result['status'] != 'passed':
                    raise RuntimeError(name + ' failed; outer/inner original logs retained')
        report['status'] = 'passed'
    except Exception as error:
        report['status'] = 'failed'
        report['error'] = type(error).__name__ + ': ' + str(error)
    finally:
        report['ended_at_unix'] = time.time()
        try:
            report['evidence_files'] = {str(p.relative_to(output)): hashlib.sha256(
                (no_symlinks(p) if args.evidence_output is not None else p).read_bytes()).hexdigest()
                for p in sorted(output.rglob('*')) if p.is_file() and (p.name.endswith(('.log', '.json')))
                and p != path and '/project/.godot/' not in str(p) and
                (not '/project/' in str(p) or '/project/build/' in str(p))}
            save()
            if args.evidence_output is not None:
                copy_evidence(output, args.evidence_output, report)
        except Exception as error:
            if args.evidence_output is None:
                raise
            report['status'] = 'failed'
            report['evidence_bridge_error'] = type(error).__name__ + ': ' + str(error)
            save()
    if report['status'] != 'passed':
        print('FAILED: historical forest v1; see ' + str(path), file=sys.stderr)
        return 1
    print('PASSED: historical forest v1 selected original checks; current forest v2 NOT covered')
    return 0


if __name__ == '__main__':
    sys.exit(main())
