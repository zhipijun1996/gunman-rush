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
import sys
import time

from forest_legacy_fixture import BASIS, CHECK_IDS, ROOT, no_symlinks, original_checks, restore, verify


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='append', choices=CHECK_IDS, required=True)
    parser.add_argument('--output', type=Path, required=True, help='fresh directory below repository build/')
    args = parser.parse_args()
    output = no_symlinks(args.output).resolve()
    if not output.is_relative_to(ROOT / 'build') or output.exists():
        parser.error('Fresh output below repository build/ required; old evidence is retained')
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
        report['evidence_files'] = {str(p.relative_to(output)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(output.rglob('*')) if p.is_file() and (p.name.endswith(('.log', '.json')))
            and p != path and '/project/.godot/' not in str(p) and
            (not '/project/' in str(p) or '/project/build/' in str(p))}
        save()
    if report['status'] != 'passed':
        print('FAILED: historical forest v1; see ' + str(path), file=sys.stderr)
        return 1
    print('PASSED: historical forest v1 selected original checks; current forest v2 NOT covered')
    return 0


if __name__ == '__main__':
    sys.exit(main())
